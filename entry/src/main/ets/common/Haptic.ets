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

import { vibrator } from '@kit.SensorServiceKit';

/**
 * 触感反馈工具（P1 · Haptic 反馈）
 * 关键操作（置顶/勾选/删除确认等）轻震动；无权限/无能力/失败均静默降级，不阻断业务。
 * 用法：Haptic.light()（轻反馈）/ Haptic.strong()（重反馈）
 */
export class Haptic {
  private static readonly LIGHT_MS: number = 10;
  private static readonly STRONG_MS: number = 20;

  static light(): void {
    Haptic.vibrate(Haptic.LIGHT_MS);
  }

  static strong(): void {
    Haptic.vibrate(Haptic.STRONG_MS);
  }

  private static vibrate(duration: number): void {
    try {
      vibrator.startVibration({ type: 'time', duration }, { usage: 'unknown' }).catch(() => {
      });
    } catch (e) {
      // 无震动能力/未授权时静默降级
    }
  }
}
