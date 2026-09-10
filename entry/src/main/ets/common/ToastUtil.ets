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

import { UIContext } from '@kit.ArkUI';

/**
 * 统一 Toast 工具（第四批 · Toast 统一样式）
 * 统一：图标前缀（信息/成功/失败）、时长（错误 3s，其余 2.2s）、底部偏移、深色适配（系统 Toast 自动适配）
 * 用法：ToastUtil.show(this.getUIContext(), '已保存', ToastType.Success)
 */
export enum ToastType {
  Info = 0,
  Success = 1,
  Error = 2,
}

export class ToastUtil {
  static show(ctx: UIContext, message: string, type: ToastType = ToastType.Info): void {
    if (!ctx || message.length === 0) {
      return;
    }
    let prefix: string = '';
    if (type === ToastType.Success) {
      prefix = '✓ ';
    } else if (type === ToastType.Error) {
      prefix = '✕ ';
    }
    try {
      ctx.getPromptAction().showToast({
        message: `${prefix}${message}`,
        duration: type === ToastType.Error ? 3000 : 2200,
        bottom: 120,
      });
    } catch (e) {
      // Toast 失败不阻断业务（日志由上层业务自行处理）
    }
  }
}
