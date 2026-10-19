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
  /**
   * §FLUSHQ（2026-09-29）flush 防抖：put/delete 只写内存，flush 延迟合并到 300ms 窗口统一落盘。
   * 背景：原来每次 put/delete 都 await flush()——FollowFeedStore 池/游标/已消费、详情磁盘缓存等
   * 高频小写每次都触发一次整库落盘，是主线程外最密集的 I/O 尖峰。Preferences 实例内读 always
   * 命中内存副本（同会话读语义不变），只有跨进程/掉电恢复受 300ms 窗口影响——缓存数据可接受。
   */
  private flushTimer: number = -1;
  private flushDirty: boolean = false;
  /** flush 防抖窗口 */
  private static readonly FLUSH_DEBOUNCE_MS: number = 300;

  // ---- §T1（2026-09-30）prune 节流与延迟：把「全表扫描」从滚动帧上挪开 ----
  /** prune 最小执行间隔（ms）：原触发点约 5s 一次（真机 95s 滚动窗口内实测 19 次）→ 最长 60s 一次 */
  private static readonly PRUNE_MIN_INTERVAL_MS: number = 60000;
  /** prune 触发后的延迟窗口（ms）：调用点正是详情落盘的那一帧，推后执行以离开该帧 */
  private static readonly PRUNE_DELAY_MS: number = 1200;
  /** 上次 prune **实际执行**的时刻（0 = 本会话尚未执行过，首次触发即放行） */
  private lastPruneAt: number = 0;
  /** 待执行的 prune 定时器（-1 = 无待办） */
  private pruneTimer: number = -1;
  private pendingPrunePrefix: string = '';
  private pendingPruneMax: number = 0;

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
      // §FLUSHQ：不逐次 flush，挂 300ms 防抖统一落盘（见类头注释）
      this.scheduleFlush();
    } catch (e) {
      hilog.error(0x0000, TAG, 'put error: %{public}s', JSON.stringify(e));
    }
  }

  /** 标记脏并挂防抖 flush：窗口内多次写只落一次盘 */
  private scheduleFlush(): void {
    this.flushDirty = true;
    if (this.flushTimer >= 0) {
      return;
    }
    this.flushTimer = setTimeout((): void => {
      this.flushTimer = -1;
      this.flushNow();
    }, CacheManager.FLUSH_DEBOUNCE_MS);
  }

  /**
   * 立即落盘（清掉未触发的防抖定时器）。
   * 调用点：应用退后台 / 销毁（EntryAbility onBackground/onDestroy），
   * 防止用户切走后 300ms 窗口内的缓存写入丢失。
   */
  async flushNow(): Promise<void> {
    if (this.flushTimer >= 0) {
      clearTimeout(this.flushTimer);
      this.flushTimer = -1;
    }
    if (this.store === null || !this.flushDirty) {
      return;
    }
    this.flushDirty = false;
    try {
      await this.store.flush();
    } catch (e) {
      hilog.error(0x0000, TAG, 'flushNow error: %{public}s', JSON.stringify(e));
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
      // §T1 修复（2026-09-30）：SDK 的 `getAll(): Promise<Object>` 返回的是**普通对象**，
      // 此处原先 `as Map<string, ValueType>` 后调用 `Map.forEach` ⇒ 必然抛 TypeError，被
      // 外层 catch 吞成 `getAllByPrefix error: {}`。也就是说本方法**从未返回过任何条目**，
      // 「一键签到」的「今日已签到」过滤一直在静默失效。改为 Record + Object.keys 迭代。
      const all = await this.store.getAll() as Record<string, preferences.ValueType>;
      const keys: string[] = Object.keys(all);
      for (const key of keys) {
        const value: preferences.ValueType = all[key];
        if (key.startsWith(prefix) && typeof value === 'string') {
          result.set(key, value as string);
        }
      }
    } catch (e) {
      hilog.error(0x0000, TAG, 'getAllByPrefix error: %{public}s', CacheManager.errText(e));
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
   *
   * §T1（2026-09-30）三处修复。背景：真机 95s 滚动窗口内 `pruneByPrefix error: {}` 出现 19 次，
   * 覆盖 32 个长帧（max≥50ms）中的 15 个，是「事件数少但很深」那类单次长阻塞的稳定贡献者。
   *
   * ① **类型 bug：本方法从上线起从未真正清理过任何条目。**
   *    SDK 的 `getAll(): Promise<Object>` 返回的是**普通对象**，原实现 `as Map<...>` 后调用
   *    `Map.forEach` ⇒ 必然抛 TypeError（对象没有 forEach），被外层 catch 吞成 `error: {}`。
   *    净效果是：每次触发都白跑一次 `getAll()`（把整个 Preferences 物化成 JS 对象，含全部
   *    详情缓存，主线程成本随缓存增长且永不回收）然后抛错退出。现改为
   *    `Record<string, ValueType>` + `Object.keys` 迭代（与 TiebaService 既有写法一致）。
   * ② **不再为取 expireAt 而解析整条详情**：`putWithTtl` 用对象字面量序列化 TtlWrapper
   *    （`{data, expireAt}`），字段序恒为 data → expireAt，故 expireAt 必在字符串末尾；
   *    改用 `readExpireAt` 从尾部定位读取，成本从「每条几十 KB 的 JSON.parse × N 条」
   *    降为「读末尾几十字节 × N 条」。
   * ③ **节流 + 延迟执行**：最小间隔 60s（原约 5s 一次），且触发后延迟到下一帧之外执行，
   *    避免「预取回包 → 详情落盘 → 全表扫描」三件事压进同一个滚动帧。
   *    （清理是「防磁盘膨胀」的慢变量，60s 粒度足够；详情 TTL 10 分钟亦兜底。）
   */
  async pruneByPrefix(prefix: string, maxCount: number): Promise<void> {
    if (this.store === null || maxCount <= 0) {
      return;
    }
    // ③-a 节流：距上次实际清理不足最小间隔 → 本次不排（调用点仍可保持「每 N 次写入调一次」）
    if (Date.now() - this.lastPruneAt < CacheManager.PRUNE_MIN_INTERVAL_MS) {
      return;
    }
    if (this.pruneTimer >= 0) {
      return;
    }
    // ③-b 延迟执行：调用点正是详情落盘的那一帧，推后执行让它离开滚动帧
    this.pendingPrunePrefix = prefix;
    this.pendingPruneMax = maxCount;
    this.pruneTimer = setTimeout((): void => {
      this.pruneTimer = -1;
      const p: string = this.pendingPrunePrefix;
      const n: number = this.pendingPruneMax;
      this.runPrune(p, n);
    }, CacheManager.PRUNE_DELAY_MS);
  }

  /** 实际执行一轮清理（只由 pruneByPrefix 的延迟回调调用） */
  private async runPrune(prefix: string, maxCount: number): Promise<void> {
    if (this.store === null) {
      return;
    }
    this.lastPruneAt = Date.now();
    const t0: number = Date.now();
    try {
      const all = await this.store.getAll() as Record<string, preferences.ValueType>;
      const keys: string[] = Object.keys(all);
      const entries: PruneEntry[] = [];
      const now: number = Date.now();
      for (const key of keys) {
        if (!key.startsWith(prefix)) {
          continue;
        }
        const value: preferences.ValueType = all[key];
        if (typeof value !== 'string' || value.length === 0) {
          continue;
        }
        // ② 尾部定位取 expireAt（-1 = 非 TtlWrapper / 已损坏 → 跳过，与旧实现「解析失败即跳过」一致）
        const expireAt: number = CacheManager.readExpireAt(value);
        if (expireAt < 0) {
          continue;
        }
        const entry: PruneEntry = { key: key, expireAt: expireAt };
        entries.push(entry);
      }
      let removed: number = 0;
      if (entries.length <= maxCount) {
        // 未超上限：只清理已过期的条目
        for (const e of entries) {
          if (e.expireAt < now && await this.deleteKey(e.key)) {
            removed++;
          }
        }
      } else {
        entries.sort((a: PruneEntry, b: PruneEntry): number => a.expireAt - b.expireAt);
        const n: number = entries.length - maxCount;
        for (let i = 0; i < n; i++) {
          if (await this.deleteKey(entries[i].key)) {
            removed++;
          }
        }
      }
      if (removed > 0) {
        this.scheduleFlush();
      }
      // 结果自证（每轮一行，最长 60s 一次）：scanned = 全表条目数，kept = 保留的前缀条目数
      hilog.info(0x0000, TAG,
        'prune prefix=%{public}s table=%{public}d matched=%{public}d kept=%{public}d removed=%{public}d cost=%{public}dms',
        prefix, keys.length, entries.length, entries.length - removed, removed, Date.now() - t0);
    } catch (e) {
      hilog.error(0x0000, TAG, 'pruneByPrefix error: %{public}s', CacheManager.errText(e));
    }
  }

  /** 删除单个 key：失败只记日志并返回 false，不中断整轮清理 */
  private async deleteKey(key: string): Promise<boolean> {
    if (this.store === null) {
      return false;
    }
    try {
      await this.store.delete(key);
      return true;
    } catch (e) {
      hilog.error(0x0000, TAG, 'prune delete failed key=%{public}s err=%{public}s', key, CacheManager.errText(e));
      return false;
    }
  }

  /**
   * §T1：只从 TtlWrapper 的 JSON 文本里取 expireAt，不解析整个对象。
   * TtlWrapper 由对象字面量序列化（字段序 data → expireAt），故本字段在末尾；
   * 用 lastIndexOf 兜「data 内部恰好含同名字符串」的情形（取最靠后的那个）。
   * 返回 -1 表示不是合法 TtlWrapper，调用方按「解析失败」跳过。
   */
  private static readExpireAt(raw: string): number {
    const idx: number = raw.lastIndexOf('"expireAt"');
    if (idx < 0) {
      return -1;
    }
    const len: number = raw.length;
    let i: number = idx + 10;
    while (i < len) {
      const c: number = raw.charCodeAt(i);
      if (c === 0x3A || c === 0x20) {   // ':' 或空格
        i++;
        continue;
      }
      break;
    }
    let end: number = i;
    while (end < len) {
      const d: number = raw.charCodeAt(end);
      if (d < 0x30 || d > 0x39) {   // 非数字
        break;
      }
      end++;
    }
    if (end === i) {
      return -1;
    }
    const n: number = Number.parseInt(raw.substring(i, end), 10);
    return Number.isNaN(n) ? -1 : n;
  }

  /** §T1：取真实错误文本（`JSON.stringify(Error)` 恒为 "{}"，会把真因整个吞掉） */
  private static errText(error: Object): string {
    const message: string = (error as Error).message;
    return message !== undefined && message.length > 0 ? message : `${error}`;
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
      // §FLUSHQ：与 put 同口径防抖（同会话读走内存副本，语义不变）
      this.scheduleFlush();
    } catch (e) {
      hilog.error(0x0000, TAG, 'delete error: %{public}s', JSON.stringify(e));
    }
  }
}
