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
 * 字号级别定义（6 档，对照参考图的 6 个圆点）
 */
export enum FontSizeLevel {
  TINY = 0,      // 极小 0.85x
  SMALL = 1,     // 小   0.95x
  NORMAL = 2,    // 标准 1.00x（默认）
  MEDIUM = 3,    // 中   1.10x
  LARGE = 4,     // 大   1.20x
  HUGE = 5,      // 极大 1.35x
}

/**
 * 每个级别对应的缩放倍率
 */
const SCALE_MAP: number[] = [0.85, 0.95, 1.0, 1.10, 1.20, 1.35];

/**
 * 每个级别对应的中文标签
 */
const LABEL_MAP: string[] = ['极小', '小', '标准', '中', '大', '极大'];

/**
 * 全局字号管理器（单例）。
 * - 管理当前字号级别
 * - 持久化到本地缓存
 * - 通过 AppStorage 通知所有页面刷新
 */
export class FontSizeManager {
  private static instance: FontSizeManager | null = null;
  private level: number = FontSizeLevel.NORMAL;
  private inited: boolean = false;
  private context: common.UIAbilityContext | null = null;

  static getInstance(): FontSizeManager {
    if (FontSizeManager.instance === null) {
      FontSizeManager.instance = new FontSizeManager();
    }
    return FontSizeManager.instance;
  }

  /**
   * 初始化：从缓存恢复字号级别
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
      const saved = await cache.get(CACHE_KEY.FONT_SIZE_LEVEL);
      if (saved !== null && saved !== undefined) {
        const lvl = parseInt(saved as string);
        if (lvl >= 0 && lvl < SCALE_MAP.length) {
          this.level = lvl;
        }
      }
    } catch (e) {
      // 忽略缓存错误，使用默认值
    }
    // 写入 AppStorage 供全局响应式使用
    AppStorage.setOrCreate('fontScale', this.getScale());
    AppStorage.setOrCreate('fontLevel', this.level);
  }

  /**
   * 获取当前缩放倍率
   */
  getScale(): number {
    return SCALE_MAP[this.level];
  }

  /**
   * 获取当前级别
   */
  getLevel(): number {
    return this.level;
  }

  /**
   * 设置字号级别（0 ~ 5）
   */
  async setLevel(level: number): Promise<void> {
    if (level < 0 || level >= SCALE_MAP.length) {
      return;
    }
    this.level = level;
    // 立即更新 AppStorage
    AppStorage.setOrCreate('fontScale', this.getScale());
    AppStorage.setOrCreate('fontLevel', this.level);
    // 持久化
    try {
      if (this.context) {
        const cache = CacheManager.getInstance();
        await cache.init(this.context);
        await cache.put(CACHE_KEY.FONT_SIZE_LEVEL, String(level));
      }
    } catch (e) {
      // 忽略持久化错误
    }
  }

  /**
   * 根据基准字号计算实际字号（全局通用入口）
   */
  static fs(baseFontSize: number): number {
    const scale = AppStorage.get<number>('fontScale') ?? 1.0;
    return Math.round(baseFontSize * scale);
  }

  /**
   * 获取指定级别的缩放倍率
   */
  static scaleOf(level: number): number {
    if (level < 0 || level >= SCALE_MAP.length) {
      return 1.0;
    }
    return SCALE_MAP[level];
  }

  /**
   * 获取指定级别的标签
   */
  static labelOf(level: number): string {
    if (level < 0 || level >= LABEL_MAP.length) {
      return '';
    }
    return LABEL_MAP[level];
  }

  /**
   * 级别总数
   */
  static get LevelCount(): number {
    return SCALE_MAP.length;
  }
}
