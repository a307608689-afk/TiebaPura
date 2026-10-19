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
 * 性能上下文追踪（P0-2 归因打点，2026-09-29）：
 *
 * 背景：AGC「TOP 问题页面」只给到 `/ets/pages/Index`（宿主壳，内含首页/进吧/收藏/消息/我的
 * 五个 Tab）这种粒度，无法回答「到底是哪个 Tab、滚动还是切页、哪类事件在掉帧」。
 *
 * 本模块把「页面 / 主 Tab / 是否在滚动 / 窗口内发生了哪些重活」四类上下文，
 * 附加到 FrameRateBoost 已有的 [FSTAT] 每 2s 一行帧统计上，使真机 hilog 能直接按
 * 「页面 × Tab × 滚动状态」切分帧间隔分布，并与事件计数对齐。
 *
 * 设计红线（务必保持）：
 * ① 纯旁路：不改任何既有逻辑分支、不写 @State、不触发任何重建/重排；
 * ② 零分配热路径：noteScroll / mark 只做标量赋值与一次 Map 自增，无对象分配；
 * ③ 零定时器：滚动活跃判定在「读」的时候用时间戳差值算，不引 setTimeout；
 * ④ PERF_TRACE_ENABLED=false 时全部方法首行空转返回，可一行回退。
 *
 * 数据出口两个：
 * ① hilog TAG=FSTAT（实时，滚动中即可观察）；
 * ② context.filesDir/perf_trace.log（环形缓冲 240 行，退后台时整体覆写，
 *    用 `hdc file recv` 回捞，解决「hilog 窗口期太短、滚动日志抓不全」的问题）。
 */

import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'PerfTrace';
const LOG_DOMAIN: number = 0x0000;

/** 总开关：false 时全部方法空转（零开销），一行回退用 */
export const PERF_TRACE_ENABLED: boolean = true;
/** 落盘文件名（位于 context.filesDir 下） */
export const PERF_TRACE_FILE: string = 'perf_trace.log';
/** 环形缓冲行数上限（2s 一行 ≈ 8 分钟） */
const TRACE_MAX_LINES: number = 240;
/** 滚动活跃判定窗口（ms）：距上次 onScroll 超过该值即视为「未在滚动」 */
const SCROLL_ACTIVE_MS: number = 200;

/**
 * 可计数事件。新增事件只改这里 + 调用点，contextSummary 会自动带上。
 * 这类事件都对应「一次可感知的重渲染 / 主线程重活」，是顿帧的首要嫌疑对象。
 */
export type PerfEvent =
  | 'tabSwitch'    // 宿主切换主 Tab（含离屏页首次挂载）
  | 'imgLand'      // 卡片图片落地（setCachedImage 整体换对象触发重渲染）
  | 'listSwap'     // 列表数据源**整表重建**（onDataReloaded，全部可见卡重建）
  | 'listTouch'    // 列表数组重赋值但只逐项 notifyChange（就地更新，成本低一个量级）
  | 'winSlide'     // 窗口化挂载推进（一次页面级重渲染）
  | 'decode'       // protobuf 解码（taskpool 或主线程兜底）
  | 'sortSwitch';  // 吧内排序切换

const PERF_EVENTS: PerfEvent[] =
  ['tabSwitch', 'imgLand', 'listSwap', 'listTouch', 'winSlide', 'decode', 'sortSwitch'];

/** 简短事件名（日志宽度敏感，只在此处维护映射） */
const EVENT_SHORT: Record<string, string> = {
  'tabSwitch': 'tabSw',
  'imgLand': 'img',
  'listSwap': 'swap',
  'listTouch': 'touch',
  'winSlide': 'win',
  'decode': 'dec',
  'sortSwitch': 'sort'
};

class PerfTraceManager {
  private page: string = '-';
  private tab: string = '';
  private lastScrollAt: number = 0;
  private counters: Map<string, number> = new Map<string, number>();
  private lines: string[] = [];
  private hintLogged: boolean = false;

  /** 当前页面（路由名，不带 /ets/pages/ 前缀）。tab 仅宿主壳 Index 有值。 */
  setPage(page: string, tab: string = ''): void {
    if (!PERF_TRACE_ENABLED) {
      return;
    }
    this.page = page;
    this.tab = tab;
  }

  /** 既有 onScroll 回调首行调用一次（不改任何滚动逻辑） */
  noteScroll(): void {
    if (!PERF_TRACE_ENABLED) {
      return;
    }
    this.lastScrollAt = Date.now();
  }

  /** 重活事件计数（窗口内累计，由 contextSummary 消费并清零） */
  mark(event: PerfEvent): void {
    if (!PERF_TRACE_ENABLED) {
      return;
    }
    const cur: number = this.counters.get(event) ?? 0;
    this.counters.set(event, cur + 1);
  }

  /** 「MM-dd HH:mm:ss」时间戳（每 2s 一次，格式化开销可忽略） */
  stamp(): string {
    return this.stampOf(Date.now());
  }

  /**
   * 任意时刻的「HH:mm:ss.SSS」时间戳（与 hilog 行首时间格式对齐，便于离线把
   * FSTAT 记录的最差帧时刻直接拿去原始日志里检索「那一瞬间应用在跑什么」）。
   */
  stampOf(ms: number): string {
    const d: Date = new Date(ms);
    const pad = (n: number, w: number = 2): string => {
      let s: string = `${n}`;
      while (s.length < w) {
        s = `0${s}`;
      }
      return s;
    };
    return `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}.${pad(d.getMilliseconds(), 3)}`;
  }

  /**
   * 供 FSTAT 每个统计窗口调用一次：返回上下文段并清空窗口计数。
   * 形如：`page=Index/home scroll=1 ev=img4,swap0,win6,dec2,tabSw1,sort0`
   */
  contextSummary(): string {
    if (!PERF_TRACE_ENABLED) {
      return '';
    }
    const scrolling: number = Date.now() - this.lastScrollAt <= SCROLL_ACTIVE_MS ? 1 : 0;
    let ev: string = '';
    for (let i = 0; i < PERF_EVENTS.length; i++) {
      const name: PerfEvent = PERF_EVENTS[i];
      const short: string = EVENT_SHORT[name] ?? name;
      const count: number = this.counters.get(name) ?? 0;
      ev += (i === 0 ? '' : ',') + `${short}${count}`;
      this.counters.set(name, 0);
    }
    const pageTag: string = this.tab.length > 0 ? `${this.page}/${this.tab}` : this.page;
    return `page=${pageTag} scroll=${scrolling} ev=${ev}`;
  }

  /** 追加一行到环形缓冲（供退后台落盘） */
  appendLine(line: string): void {
    if (!PERF_TRACE_ENABLED) {
      return;
    }
    this.lines.push(line);
    if (this.lines.length > TRACE_MAX_LINES) {
      this.lines.shift();
    }
  }

  /**
   * 退后台落盘：把环形缓冲整体覆写到 filesDir/perf_trace.log。
   * 同步写一次极小文本（≤240 行），只在切后台时发生，不参与滚动路径。
   */
  flush(context: common.Context): void {
    if (!PERF_TRACE_ENABLED || this.lines.length === 0) {
      return;
    }
    try {
      const path: string = `${context.filesDir}/${PERF_TRACE_FILE}`;
      // 本 SDK 的 fileIo.openSync 返回 File 对象（不是 fd 数字），写/关都要经 file.fd
      const file: fileIo.File = fileIo.openSync(path,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, this.lines.join('\n') + '\n');
      } finally {
        fileIo.closeSync(file);
      }
      hilog.info(LOG_DOMAIN, TAG,
        'trace dumped lines=%{public}d filesDir=%{public}s', this.lines.length, path);
    } catch (e) {
      hilog.error(LOG_DOMAIN, TAG, 'trace dump FAILED err=%{public}s', JSON.stringify(e));
    }
  }

  /** 首次落盘前打印一次回捞命令，省去用户猜路径 */
  logPullHint(context: common.Context): void {
    if (!PERF_TRACE_ENABLED || this.hintLogged) {
      return;
    }
    this.hintLogged = true;
    try {
      hilog.info(LOG_DOMAIN, TAG,
        'pull: hdc file recv %{public}s/%{public}s .', context.filesDir, PERF_TRACE_FILE);
    } catch (e) {
      // 提示失败不影响打点
    }
  }
}

/** 全局单例 */
export const PerfTrace: PerfTraceManager = new PerfTraceManager();
