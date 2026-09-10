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

/**
 * 全局使用习惯开关管理器（单例）。
 * - 管理「首页推荐仅显示关注吧的帖子」开关
 * - 持久化到本地缓存
 * - 通过 AppStorage 通知所有页面刷新（键：homeOnlyFollow）
 */
export class UsageHabitsManager {
  private static instance: UsageHabitsManager | null = null;
  private inited: boolean = false;
  private context: common.UIAbilityContext | null = null;

  static getInstance(): UsageHabitsManager {
    if (UsageHabitsManager.instance === null) {
      UsageHabitsManager.instance = new UsageHabitsManager();
    }
    return UsageHabitsManager.instance;
  }

  /**
   * 初始化：从缓存恢复开关状态
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.inited) {
      return;
    }
    this.inited = true;
    this.context = context;
    try {
      const cache = CacheManager.getInstance();
      await cache.init(context);
      const saved = await cache.get(CACHE_KEY.HOME_ONLY_FOLLOW);
      AppStorage.setOrCreate('homeOnlyFollow', saved === '1');
    } catch (e) {
      // 忽略缓存错误，使用默认值（关闭）
      AppStorage.setOrCreate('homeOnlyFollow', false);
    }
  }

  /**
   * 当前是否开启「仅推荐关注的吧」
   */
  isOnlyFollow(): boolean {
    return AppStorage.get<boolean>('homeOnlyFollow') ?? false;
  }

  /**
   * 设置开关状态：立即更新 AppStorage，持久化到本地，
   * 并清除首页推荐缓存，避免下次读到旧的未过滤内容。
   */
  async setOnlyFollow(enabled: boolean): Promise<void> {
    AppStorage.setOrCreate('homeOnlyFollow', enabled);
    try {
      if (this.context) {
        const cache = CacheManager.getInstance();
        await cache.init(this.context);
        await cache.put(CACHE_KEY.HOME_ONLY_FOLLOW, enabled ? '1' : '0');
        // 开关状态变化后旧缓存（可能未过滤/已过滤）不再可信，直接清除
        await cache.delete(CACHE_KEY.THREAD_LIST);
      }
    } catch (e) {
      // 忽略持久化错误
    }
  }
}
