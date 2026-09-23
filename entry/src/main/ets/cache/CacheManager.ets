/*
 * TiebaPura - HarmonyOS 原生 ArkTS 实现的第三方百度贴吧客户端
 * Copyright (C) 2026 a307608689-afk
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'CacheManager';
export const STORE_NAME: string = 'tieba_cache';

/** 读操作等待 store 就绪的最长时间；超时按未命中放行，绝不卡住 UI */
const READY_WAIT_MS: number = 300;

interface TtlWrapper<T> {
  data: T;
  expireAt: number;
}

/** getWithTtlAllowStale 的返回：data 为缓存数据，expired 标记是否已过期 */
interface StaleCacheEntry<T> {
  data: T;
  expired: boolean;
}

/** pruneByPrefix 内部的待清理条目 */
interface PruneEntry {
  key: string;
  expireAt: number;
}

/**
 * 基于 Preferences 的轻量缓存层，带 TTL 过期。
 */
export class CacheManager {
  private static instance: CacheManager | null = null;
  private store: preferences.Preferences | null = null;
  /** init 已收敛（成功或失败）标记，配合 readyWaiters 唤醒等待中的读操作 */
  private ready: boolean = false;
  /** init 是否已被调用过：没被调用过就没人会唤醒等待者，读操作必须立刻返回，不能白等超时 */
  private initStarted: boolean = false;
  /** 在 init 收敛前发起、正在等待 store 就绪的读操作回调 */
  private readyWaiters: Array<() => void> = [];

  static getInstance(): CacheManager {
    if (CacheManager.instance === null) {
      CacheManager.instance = new CacheManager();
    }
    return CacheManager.instance;
  }

  /**
   * 初始化，需传入 UIAbilityContext
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    this.initStarted = true;
    if (this.store !== null) {
      return;
    }
    try {
      this.store = await preferences.getPreferences(context, STORE_NAME);
    } catch (e) {
      hilog.error(0x0000, TAG, 'init error: %{public}s', JSON.stringify(e));
    } finally {
      // 无论成功失败都要唤醒等待者：失败时等待者按「store 仍为空」的原有语义返回未命中
      this.markReady();
    }
  }

  /** 标记 store 就绪并唤醒全部等待者 */
  private markReady(): void {
    this.ready = true;
    const waiters: Array<() => void> = this.readyWaiters;
    this.readyWaiters = [];
    for (const w of waiters) {
      w();
    }
  }

  /**
   * 等待 store 就绪：init 已发起但未收敛时挂起读操作至其完成（或 READY_WAIT_MS 超时放行）。
   * 冷启动时 onCreate 已 fire-and-forget 调 init，而页面首帧读盘可能抢在其前，
   * 若不等就会全部 miss（详情页首屏退化为纯网络加载）。
   * init 从未被调用时立刻返回（保持改造前语义），绝不白等超时。
   */
  private waitReady(): Promise<void> {
    if (this.ready || !this.initStarted) {
      return Promise.resolve();
    }
    return new Promise<void>((resolve: () => void): void => {
      let settled: boolean = false;
      const done: () => void = (): void => {
        if (settled) {
          return;
        }
        settled = true;
        const idx: number = this.readyWaiters.indexOf(done);
        if (idx >= 0) {
          // 超时先到的情况：从等待队列摘除，避免 init 收敛时重复唤醒
          this.readyWaiters.splice(idx, 1);
        }
        resolve();
      };
      this.readyWaiters.push(done);
      setTimeout(done, READY_WAIT_MS);
    });
  }

  /**
   * 写入字符串
   *
   * 注（2026-09-23）：原 `appendJsonItem`（无脑前插的 JSON 数组追加）已删除——浏览历史是它唯一
   * 的使用方，而「纯前插 + 不去重」正是「同一帖每次进都留一条、50 条上限被重复项吃光」的根因；
   * 历史记录现统一走 `service/HistoryStore`（去重 + 浏览时间 + 串行写）。
   */
  async put(key: string, value: string): Promise<void> {
    if (this.store === null) {
      return;
    }
    try {
      await this.store.put(key, value);
      await this.store.flush();
    } catch (e) {
      hilog.error(0x0000, TAG, 'put error: %{public}s', JSON.stringify(e));
    }
  }

  /**
   * 读取字符串
   */
  async get(key: string): Promise<string | undefined> {
    await this.waitReady();
    if (this.store === null) {
      return undefined;
    }
    try {
      const v = await this.store.get(key, '');
      return v === '' ? undefined : (v as string);
    } catch (e) {
      hilog.error(0x0000, TAG, 'get error: %{public}s', JSON.stringify(e));
      return undefined;
    }
  }

  /**
   * 按 key 前缀读取全部字符串条目（如签到状态这类「前缀 + 账号/吧名」隔离的批量读取，
   * 一次 getAll 避免逐 key 读盘）。返回 key → value 的映射。
   */
  async getAllByPrefix(prefix: string): Promise<Map<string, string>> {
    const result: Map<string, string> = new Map<string, string>();
    await this.waitReady();
    if (this.store === null) {
      return result;
    }
    try {
      const all = await this.store.getAll() as Map<string, preferences.ValueType>;
      all.forEach((value: preferences.ValueType, key: string) => {
        if (key.startsWith(prefix) && typeof value === 'string') {
          result.set(key, value as string);
        }
      });
    } catch (e) {
      hilog.error(0x0000, TAG, 'getAllByPrefix error: %{public}s', JSON.stringify(e));
    }
    return result;
  }

  /**
   * 带 TTL 的对象缓存
   */
  async putWithTtl<T>(key: string, value: T, ttlMs: number): Promise<void> {
    const wrapper: TtlWrapper<T> = {
      data: value,
      expireAt: Date.now() + ttlMs,
    };
    await this.put(key, JSON.stringify(wrapper));
  }

  /**
   * 按 key 前缀清理缓存条目：超上限时按 expireAt 删除最旧（含过期清理），
   * 防止详情等高频写入的磁盘缓存无限膨胀。失败不抛错。
   */
  async pruneByPrefix(prefix: string, maxCount: number): Promise<void> {
    if (this.store === null || maxCount <= 0) {
      return;
    }
    try {
      const all = await this.store.getAll() as Map<string, preferences.ValueType>;
      const entries: PruneEntry[] = [];
      all.forEach((value: preferences.ValueType, key: string) => {
        if (key.startsWith(prefix) && typeof value === 'string' && value.length > 0) {
          try {
            const wrapper = JSON.parse(value) as TtlWrapper<object>;
            const entry: PruneEntry = { key: key, expireAt: wrapper.expireAt };
            entries.push(entry);
          } catch (_) {
          }
        }
      });
      if (entries.length <= maxCount) {
        // 未超上限：只清理已过期的条目
        const now = Date.now();
        const expired = entries.filter((e) => e.expireAt < now);
        for (const e of expired) {
          this.store.delete(e.key);
        }
        if (expired.length > 0) {
          await this.store.flush();
        }
        return;
      }
      entries.sort((a, b) => a.expireAt - b.expireAt);
      const toRemove = entries.slice(0, entries.length - maxCount);
      for (const e of toRemove) {
        this.store.delete(e.key);
      }
      await this.store.flush();
    } catch (e) {
      hilog.error(0x0000, TAG, 'pruneByPrefix error: %{public}s', JSON.stringify(e));
    }
  }

  /**
   * 读取带 TTL 的对象缓存，过期返回 undefined
   */
  async getWithTtl<T>(key: string): Promise<T | undefined> {
    const raw = await this.get(key);
    if (raw === undefined) {
      return undefined;
    }
    try {
      const wrapper = JSON.parse(raw) as TtlWrapper<T>;
      if (wrapper.expireAt < Date.now()) {
        return undefined;
      }
      return wrapper.data;
    } catch (e) {
      return undefined;
    }
  }

  /**
   * 读取带 TTL 的对象缓存：过期数据也返回（stale-while-revalidate），
   * expired 标记是否已过期，调用方据此决定是否后台刷新，保证冷启动秒开。
   */
  async getWithTtlAllowStale<T>(key: string): Promise<StaleCacheEntry<T> | undefined> {
    const raw = await this.get(key);
    if (raw === undefined) {
      return undefined;
    }
    try {
      const wrapper = JSON.parse(raw) as TtlWrapper<T>;
      const entry: StaleCacheEntry<T> = { data: wrapper.data, expired: wrapper.expireAt < Date.now() };
      return entry;
    } catch (e) {
      return undefined;
    }
  }

  /**
   * 删除键
   */
  async delete(key: string): Promise<void> {
    if (this.store === null) {
      return;
    }
    try {
      await this.store.delete(key);
      await this.store.flush();
    } catch (e) {
      hilog.error(0x0000, TAG, 'delete error: %{public}s', JSON.stringify(e));
    }
  }
}
