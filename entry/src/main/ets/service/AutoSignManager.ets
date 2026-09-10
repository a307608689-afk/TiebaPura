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

import { common } from '@kit.AbilityKit';
import { CacheManager } from '../cache/CacheManager';
import { CACHE_KEY } from '../common/Constants';
import { FollowItem } from '../model/DataModel';
import { TiebaService } from './TiebaService';
import { ForumSignStore } from './ForumSignStore';

/**
 * 一键签到管理器（单例）：功能与设置项对齐贴吧 Lite（HuanCheng65/TiebaLite 4.0-dev）。
 * - 设置项持久化到本地缓存，并通过 AppStorage 通知所有页面（键：autoSignSlowMode / autoSignUseOfficial），
 *   默认均为「开启」（与贴吧 Lite 默认值一致）。
 * - 一键签到流程：拉全量关注吧 →（可选）官方一键签到批量处理 →「未完成」的吧逐吧签到兜底。
 *   · 慢速模式：逐吧签到间隔随机 3.5~8 秒（普通模式固定 2 秒），降低被风控概率。
 *   · 使用官方一键签到：先用官方 msign 批量签到，减少后续需要逐吧签到的数量，从而加快整体速度。
 * - 支持取消（翻页/间隔期间可中断），取消后已签成功的结果照常返回。
 */
export enum AutoSignStage {
  /** 拉取关注吧列表 */
  Preparing = 0,
  /** 官方一键签到（批量） */
  Official = 1,
  /** 逐吧签到 */
  Signing = 2,
}

/** 签到过程中的进度快照（UI 每步回调刷新） */
export interface AutoSignProgress {
  stage: AutoSignStage;
  /** 需要签到的吧总数（已排除今日已签到的吧） */
  total: number;
  /** 已处理数量（官方一键签到完成数 + 逐吧已处理数） */
  finished: number;
  signed: number;
  failed: number;
  /** 当前正在签到的吧名（官方批量阶段为空串） */
  forumName: string;
  /** 阶段说明文案（官方一键签到提示等） */
  note: string;
}

/** 一键签到结果 */
export interface AutoSignResult {
  total: number;
  signed: number;
  failed: number;
  /** 今日已签到、无需处理的吧数 */
  alreadySigned: number;
  /** 本次签到成功的吧名（供列表就地打勾，免一次整表刷新） */
  signedForumNames: string[];
  cancelled: boolean;
  officialUsed: boolean;
  message: string;
}

export class AutoSignManager {
  private static instance: AutoSignManager | null = null;
  private inited: boolean = false;
  private context: common.UIAbilityContext | null = null;
  private running: boolean = false;
  private cancelled: boolean = false;

  static getInstance(): AutoSignManager {
    if (AutoSignManager.instance === null) {
      AutoSignManager.instance = new AutoSignManager();
    }
    return AutoSignManager.instance;
  }

  /** 初始化：从缓存恢复两个开关（默认开启） */
  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.inited) {
      return;
    }
    this.inited = true;
    this.context = context;
    const cache = CacheManager.getInstance();
    try {
      await cache.init(context);
      const slow = await cache.get(CACHE_KEY.AUTO_SIGN_SLOW_MODE);
      const official = await cache.get(CACHE_KEY.AUTO_SIGN_USE_OFFICIAL);
      AppStorage.setOrCreate('autoSignSlowMode', slow === undefined ? true : slow === '1');
      AppStorage.setOrCreate('autoSignUseOfficial', official === undefined ? true : official === '1');
    } catch (e) {
      // 缓存不可用时保持默认值（均开启）
      if (AppStorage.get<boolean>('autoSignSlowMode') === undefined) {
        AppStorage.setOrCreate('autoSignSlowMode', true);
      }
      if (AppStorage.get<boolean>('autoSignUseOfficial') === undefined) {
        AppStorage.setOrCreate('autoSignUseOfficial', true);
      }
    }
  }

  /** 是否开启慢速模式（签到每个吧的时间间隔更长） */
  isSlowMode(): boolean {
    return AppStorage.get<boolean>('autoSignSlowMode') ?? true;
  }

  /** 是否优先使用官方一键签到 */
  isUseOfficial(): boolean {
    return AppStorage.get<boolean>('autoSignUseOfficial') ?? true;
  }

  async setSlowMode(enabled: boolean): Promise<void> {
    AppStorage.setOrCreate('autoSignSlowMode', enabled);
    await this.persist(CACHE_KEY.AUTO_SIGN_SLOW_MODE, enabled);
  }

  async setUseOfficial(enabled: boolean): Promise<void> {
    AppStorage.setOrCreate('autoSignUseOfficial', enabled);
    await this.persist(CACHE_KEY.AUTO_SIGN_USE_OFFICIAL, enabled);
  }

  private async persist(key: string, enabled: boolean): Promise<void> {
    try {
      if (this.context !== null) {
        const cache = CacheManager.getInstance();
        await cache.init(this.context);
        await cache.put(key, enabled ? '1' : '0');
      }
    } catch (e) {
      // 持久化失败不阻断开关交互（内存态已生效）
    }
  }

  /** 是否正在签到（用于禁用入口按钮 / 禁止重复启动） */
  isRunning(): boolean {
    return this.running;
  }

  /** 取消签到：当前请求返回后停止后续吧，已签成功的结果照常返回 */
  cancel(): void {
    this.cancelled = true;
  }

  /**
   * 逐吧签到间隔：慢速模式随机 3.5~8 秒，普通模式固定 2 秒
   * （对齐贴吧 Lite：3500 + Random().nextInt(4500) / 2000）
   */
  private signIntervalMs(): number {
    if (this.isSlowMode()) {
      return 3500 + Math.floor(Math.random() * 4500);
    }
    return 2000;
  }

  private async delay(ms: number): Promise<void> {
    await new Promise<void>((resolve: () => void) => {
      setTimeout(() => {
        resolve();
      }, ms);
    });
  }

  /**
   * 一键签到所有关注的吧。
   * @param onProgress 进度回调（准备 / 官方批量 / 逐吧签到三个阶段）
   * @param cachedForums 全量列表拉取失败时的兜底（页面已加载的关注吧快照，避免整次签到直接失败）
   */
  async signAll(onProgress: (progress: AutoSignProgress) => void,
    cachedForums: FollowItem[] = []): Promise<AutoSignResult> {
    if (this.running) {
      throw new Error('正在签到中，请稍候');
    }
    this.running = true;
    this.cancelled = false;
    const service = TiebaService.getInstance();
    const signedForumNames: string[] = [];
    /** 官方批量签到成功的吧名（服务端不返回连续天数，统一按 1 天落盘） */
    const officialSigned: string[] = [];
    let alreadySigned: number = 0;
    let officialUsed: boolean = false;
    let signed: number = 0;
    let failed: number = 0;
    let total: number = 0;
    try {
      onProgress({
        stage: AutoSignStage.Preparing, total: 0, finished: 0, signed: 0, failed: 0,
        forumName: '', note: '正在获取关注的吧…'
      });
      let forums: FollowItem[] = [];
      try {
        forums = await service.fetchAllFollowedForums();
      } catch (e) {
        const message: string = e instanceof Error ? e.message : `${e}`;
        if (cachedForums.length === 0) {
          throw new Error(message.length > 0 ? message : '获取关注的吧失败');
        }
        // 拉取失败但有本地已加载列表：按其继续签到（今日已签到的吧本就会被跳过）
        console.warn(`[AUTOSIGN] 关注吧列表拉取失败，改用本地列表（${cachedForums.length} 个）: ${message}`);
        forums = cachedForums;
      }
      // 今日已签到的吧：服务端 isSign 之外再用本地签到记录兜底过滤。
      // 关注列表接口的 is_sign 可能滞后（刚签完立即拉取仍为未签），
      // 本地记录是「本次/今日签到结果」的权威来源，避免重复签到被风控。
      const signedToday: Set<string> = await ForumSignStore.loadSignedTodaySet();
      const pending: FollowItem[] = [];
      for (const forum of forums) {
        if (forum.isSign || signedToday.has(forum.forumName)) {
          alreadySigned++;
          continue;
        }
        if (forum.forumName.length === 0) {
          continue;
        }
        pending.push(forum);
      }
      total = pending.length;
      if (total === 0) {
        return {
          total: 0, signed: 0, failed: 0, alreadySigned, signedForumNames: [], cancelled: false,
          officialUsed: false,
          message: forums.length === 0 ? '还没有关注的吧' : '关注的吧今天都已签到'
        };
      }

      let remaining: FollowItem[] = pending;

      // 1) 官方一键签到：先让服务端批量处理，减少后续逐吧签到的数量
      if (this.isUseOfficial()) {
        officialUsed = true;
        onProgress({
          stage: AutoSignStage.Official, total, finished: 0, signed: 0, failed: 0,
          forumName: '', note: '官方一键签到中…'
        });
        const ids: string[] = [];
        for (const forum of pending) {
          const id: string = forum.forumId ?? '';
          if (id.length > 0) {
            ids.push(id);
          }
        }
        let doneIds: string[] = [];
        try {
          doneIds = await service.signForumsOfficial(ids);
        } catch (e) {
          doneIds = [];
        }
        const doneSet: Set<string> = new Set<string>();
        for (const id of doneIds) {
          doneSet.add(id);
        }
        remaining = [];
        for (const forum of pending) {
          if (doneSet.has(forum.forumId ?? '')) {
            signed++;
            signedForumNames.push(forum.forumName);
            officialSigned.push(forum.forumName);
          } else {
            remaining.push(forum);
          }
        }
        // 落盘官方批量签到结果：吧主页重进时据此回显已签到（服务端不返回连续天数，按 1 天记）
        await ForumSignStore.saveSignDaysBatch(officialSigned, 1);
        onProgress({
          stage: AutoSignStage.Signing, total, finished: signed, signed, failed: 0, forumName: '',
          note: signed > 0 ? `官方一键签到完成 ${signed} 个吧` : '官方一键签到未生效，改为逐吧签到'
        });
      }

      // 2) 逐吧签到兜底（官方批量未覆盖/失败/关闭官方签到时的全部吧）
      for (let i = 0; i < remaining.length; i++) {
        if (this.cancelled) {
          break;
        }
        const forum: FollowItem = remaining[i];
        onProgress({
          stage: AutoSignStage.Signing, total, finished: signed + failed, signed, failed,
          forumName: forum.forumName, note: ''
        });
        try {
          const signResult = await service.signForum(forum.forumName, forum.forumId ?? '');
          signed++;
          signedForumNames.push(forum.forumName);
          // 落盘逐吧签到结果（含真实连续天数）：吧主页重进时据此回显已签到
          await ForumSignStore.saveSignDays(forum.forumName, signResult.signDays);
        } catch (e) {
          failed++;
        }
        // 每个吧签到完成后等待固定/随机间隔（慢速模式更久）；最后一个无需再等
        if (i < remaining.length - 1 && !this.cancelled) {
          await this.delay(this.signIntervalMs());
        }
      }

      let message: string = `已签到 ${signed} 个吧`;
      if (failed > 0) {
        message += `，${failed} 个失败`;
      }
      if (alreadySigned > 0) {
        message += `（另有 ${alreadySigned} 个今日已签到）`;
      }
      if (this.cancelled) {
        message = `已停止：${message}`;
      }
      return {
        total, signed, failed, alreadySigned, signedForumNames, cancelled: this.cancelled,
        officialUsed, message
      };
    } finally {
      this.running = false;
    }
  }
}
