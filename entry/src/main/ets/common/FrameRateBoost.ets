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

/**
 * 高刷拉档器（FrameRateBoost）：
 *
 * 现象背景：折叠屏展开 / 平板多列瀑布流下，卡内 blur + 大屏像素量使单帧耗时超过 8.3ms，
 * RenderService 自适应刷新率机制会把窗口降档锁 60Hz（手机单列负载小不受影响）。
 *
 * 机制：HarmonyOS 无「窗口级 setFrameRate」公开 API；expectedFrameRateRange 只作用于
 * 属性动画，覆盖不了列表滚动。唯一公开入口是 @kit.ArkGraphics2D 的 displaySync——
 * 创建实例后把 ExpectedFrameRateRange 锁 { min=expected=max=120 } 并 start()，
 * RenderService 汇总窗口内所有帧率请求选面板档位，该常驻请求会把整个窗口的 vsync
 * 拉到 120Hz 档：滚动、blur、动画全部按 120 vsync 出帧，沉浸光感零改动。
 * 60Hz 屏受硬件上限自动封顶，设置值无效但不报错。
 *
 * 代价（官方口径）：常驻锁 120 会干扰系统可变帧率调度、增加功耗；若 GPU 实际跑不满
 * 120，观感可能从「顺滑的 60」变成「带掉帧的 120」。经 BOOST_ENABLED 总开关一键回退。
 *
 * 用法：FrameRateBoost.acquire('Index') / FrameRateBoost.release('Index')（引用计数，
 * 多页可叠加申请，计数归零才真正 stop）。
 */

import { displaySync } from '@kit.ArkGraphics2D';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'FrameRateBoost';
const LOG_DOMAIN = 0x0000;

/** 总开关：false 时 acquire/release 变为空操作，一行回退到系统自适应帧率 */
const BOOST_ENABLED: boolean = true;
/** 拉档目标帧率：min/expected/max 三值同锁（expected 是系统优先满足的字段） */
const TARGET_FPS: number = 120;

class FrameRateBoostManager {
  private ds: displaySync.DisplaySync | undefined = undefined;
  private refCount: number = 0;

  /**
   * 申请拉档（引用计数 +1）。首笔申请时创建 displaySync 实例并启动；
   * 失败（API 缺失 / 设备异常）静默降级为系统自适应帧率，不影响业务。
   */
  acquire(tag: string): void {
    if (!BOOST_ENABLED) {
      return;
    }
    this.refCount++;
    if (this.refCount > 1) {
      return;
    }
    try {
      if (!this.ds) {
        this.ds = displaySync.create();
        this.ds.setExpectedFrameRateRange({
          min: TARGET_FPS,
          expected: TARGET_FPS,
          max: TARGET_FPS,
        });
        // 必须注册 frame 回调实例才有实际拉档意义；回调体保持空实现（120 次/秒的空转可忽略）
        this.ds.on('frame', () => {
        });
      }
      this.ds.start();
      hilog.info(LOG_DOMAIN, TAG, 'acquire tag=%{public}s -> started (ref=%{public}d)', tag, this.refCount);
    } catch (e) {
      hilog.error(LOG_DOMAIN, TAG, 'acquire FAILED tag=%{public}s err=%{public}s', tag, JSON.stringify(e));
    }
  }

  /**
   * 释放拉档（引用计数 -1）。计数归零才真正 stop，避免多页叠加申请时互相掐断。
   */
  release(tag: string): void {
    if (!BOOST_ENABLED) {
      return;
    }
    if (this.refCount > 0) {
      this.refCount--;
    }
    if (this.refCount === 0 && this.ds) {
      try {
        this.ds.stop();
        hilog.info(LOG_DOMAIN, TAG, 'release tag=%{public}s -> stopped', tag);
      } catch (e) {
        hilog.error(LOG_DOMAIN, TAG, 'release stop FAILED tag=%{public}s err=%{public}s', tag, JSON.stringify(e));
      }
    }
  }
}

/** 全局单例 */
export const FrameRateBoost: FrameRateBoostManager = new FrameRateBoostManager();
