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
import { PerfTrace } from './PerfTrace';

const TAG = 'FrameRateBoost';
const LOG_DOMAIN = 0x0000;

/** 总开关：false 时 acquire/release 变为空操作，一行回退到系统自适应帧率 */
const BOOST_ENABLED: boolean = true;
/** 拉档目标帧率：min/expected/max 三值同锁（expected 是系统优先满足的字段） */
const TARGET_FPS: number = 120;

/** 帧统计采样开关（2026-09-28 量化定位「越滑越卡」）：false 时零开销。
 *  统计的是 displaySync 帧回调在主线程的送达间隔 —— 主线程（ArkTS 构建/布局/GC）卡顿
 *  会直接体现为间隔拉长；GPU 侧丢帧由系统合成器吸收，不在此口径内。 */
const FSTAT_ENABLED: boolean = true;
const FSTAT_LOG_DOMAIN = 0x0000;
const FSTAT_TAG = 'FSTAT';

class FrameRateBoostManager {
  private ds: displaySync.DisplaySync | undefined = undefined;
  private refCount: number = 0;

  // ===== FSTAT 滚动窗口统计（2s 一条日志）=====
  private statLastTs: number = 0;
  private statWindowStart: number = 0;
  private statFrames: number = 0;
  private statMaxGap: number = 0;
  /** 本窗口最差帧的**起始时刻**（epoch ms）：用于离线把这一帧拿去原始 hilog 里
   *  检索「那一瞬间应用在跑什么」（解码/映射/GC/图片落地/系统抖动），
   *  使长帧归因从「相关性推测」升级为「时刻级证据」。 */
  private statMaxGapAt: number = 0;
  /** 帧间隔超预算计数（2026-09-29 P0-2）：阈值按刷新率档的帧预算取，用于区分
   *  「轻微超预算」与「真卡死」——d8 >8.3ms 即 120Hz 单帧超预算，d17 掉到 60Hz 档，
   *  d33 掉到 30Hz 档，d50 / d100 沿用旧 jank50 / jank100 口径（保持与历史日志可对照）。 */
  private statD8: number = 0;
  private statD17: number = 0;
  private statD33: number = 0;
  private statD50: number = 0;
  private statD100: number = 0;

  private onFrameTick(): void {
    const now: number = Date.now();
    if (this.statLastTs > 0) {
      const gap: number = now - this.statLastTs;
      if (gap > this.statMaxGap) {
        this.statMaxGap = gap;
        // 记「顿帧起点」而非终点：起点是主线程开始忙的时刻，正是要去日志里对齐的那一瞬
        this.statMaxGapAt = now - gap;
      }
      if (gap > 8.3) {
        this.statD8++;
      }
      if (gap > 16.7) {
        this.statD17++;
      }
      if (gap > 33.3) {
        this.statD33++;
      }
      if (gap > 50) {
        this.statD50++;
      }
      if (gap > 100) {
        this.statD100++;
      }
    } else {
      this.statWindowStart = now;
    }
    this.statLastTs = now;
    this.statFrames++;
    const win: number = now - this.statWindowStart;
    if (win >= 2000) {
      const fps: number = win > 0 ? Math.round(this.statFrames * 1000 / win) : 0;
      // 上下文段（页面/主 Tab/是否在滚动/窗口内重活事件计数）由 PerfTrace 提供并清零，
      // 使同一条日志即可归因「哪个页面 × 哪个 Tab × 滚动还是静止 × 哪类事件」。
      const ctx: string = PerfTrace.contextSummary();
      const at: string = this.statMaxGapAt > 0 ? PerfTrace.stampOf(this.statMaxGapAt) : '-';
      const line: string =
        `fps=${fps} max=${this.statMaxGap} at=${at} d8=${this.statD8} d17=${this.statD17} `
          + `d33=${this.statD33} d50=${this.statD50} d100=${this.statD100} ${ctx} win=${win}`;
      hilog.info(FSTAT_LOG_DOMAIN, FSTAT_TAG, '%{public}s', line);
      PerfTrace.appendLine(`${PerfTrace.stamp()} ${line}`);
      this.statFrames = 0;
      this.statMaxGap = 0;
      this.statMaxGapAt = 0;
      this.statD8 = 0;
      this.statD17 = 0;
      this.statD33 = 0;
      this.statD50 = 0;
      this.statD100 = 0;
      this.statWindowStart = now;
    }
  }

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
        // 必须注册 frame 回调实例才有实际拉档意义；回调体做帧间隔统计（FSTAT 开关控制，空转开销可忽略）
        this.ds.on('frame', () => {
          if (FSTAT_ENABLED) {
            this.onFrameTick();
          }
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
