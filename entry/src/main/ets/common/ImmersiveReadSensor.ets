/**
 * 「沉浸式阅读补全」共享滚动判定器（2026-09-29）。
 *
 * 判定规则与帖子详情页 ThreadDetail 的「帖子沉浸式阅读」逐项同源（24 藏 / 12 露不对称阈值 +
 * 置顶 8vp 恒显示 + 跳变 240vp 丢弃）。ThreadDetail / SubPostDetail 各自内联实现保持不动（零回归）；
 * 本类供补全的四处页面复用：首页 HomeTab、收藏页 FavoriteTab（根态 + 收藏夹二级页）、吧主页 ThreadList。
 *
 * 用法（非组件普通类，ArkTS 安全）：
 *   const sensor = new ImmersiveReadSensor();
 *   // 滚动回调里：
 *   const act = sensor.feed(scroller.currentOffset().yOffset);
 *   if (act === 'hide') { ... } else if (act === 'show') { ... } else if (act === 'reset') { ... }
 *   // 形态切换 / 离页时：
 *   sensor.resetBaseline();
 *
 * 注意：本类只做方向判定，不做任何 UI / AppStorage 写入 —— 隐藏态一律由调用方的页面局部 @State 承载
 * （绝不写 AppStorage，防切页残留，文档 §6.1 D1 类风险）。
 */

/** 向下滚累计藏起阈值（vp），与 ThreadDetail.IMMERSIVE_READ_HIDE_DIST 同源 */
export const IMMERSIVE_EXTRA_HIDE_DIST: number = 24;
/** 向上滚恢复阈值（vp），与 ThreadDetail.IMMERSIVE_READ_REVEAL_DIST 同源 */
export const IMMERSIVE_EXTRA_REVEAL_DIST: number = 12;
/** 置顶保护阈值（vp）：滚动位置 ≤ 该值恒显示（含回弹负值），与 ThreadDetail.IMMERSIVE_READ_TOP_KEEP 同源 */
export const IMMERSIVE_EXTRA_TOP_KEEP: number = 8;
/** 跳变保护阈值（vp）：单帧位移超该值视为命令式滚动 / 形态切换，丢弃判定，与 ThreadDetail 同源 */
export const IMMERSIVE_EXTRA_JUMP_LIMIT: number = 240;
/** 藏起动画时长（ms，EaseIn 收回），与 ThreadDetail.IMMERSIVE_HIDE_MS 同源 */
export const IMMERSIVE_EXTRA_HIDE_MS: number = 180;
/** 唤出动画时长（ms），与 ThreadDetail.IMMERSIVE_SHOW_MS 同源 */
export const IMMERSIVE_EXTRA_SHOW_MS: number = 260;
/** 唤出弹簧 response（curves.springMotion），与 ThreadDetail 同源 */
export const IMMERSIVE_EXTRA_SPRING_RESPONSE: number = 0.28;
/** 唤出弹簧 dampingFraction（<1 轻微过冲），与 ThreadDetail 同源 */
export const IMMERSIVE_EXTRA_SPRING_DAMPING: number = 0.86;
/** 沉浸位移比例：0.6 倍自身高「收回」+ 淡出，与 ThreadDetail.IMMERSIVE_FLY_SCALE 同源 */
export const IMMERSIVE_EXTRA_FLY_SCALE: number = 0.6;

export type ImmersiveAction = 'none' | 'hide' | 'show' | 'reset';

export class ImmersiveReadSensor {
  /** 同方向滚动累计量（vp） */
  private accum: number = 0;
  /** 上一次滚动绝对位置（vp） */
  private lastY: number = 0;
  /** 基线是否就绪：复位后第一次滚动只记录基线、不算增量（防误藏） */
  private lastReady: boolean = false;
  /** 当前是否处于隐藏态（由调用方在收到 hide/show 后回写，供累计逻辑复用） */
  private hidden: boolean = false;

  constructor(initialHidden: boolean = false) {
    this.hidden = initialHidden;
  }

  /** 调用方在隐藏态翻转后同步回写（保持判定器与页面 @State 一致） */
  setHidden(hidden: boolean): void {
    this.hidden = hidden;
    this.accum = 0;
  }

  /**
   * 喂入一次滚动绝对位置，返回判定结果：
   * - 'reset'：进入置顶保护区（调用方应恢复显示并复位基线）；
   * - 'hide'：向下累计达阈值，应藏起；
   * - 'show'：向上累计达阈值，应恢复；
   * - 'none'：无需动作。
   */
  feed(pos: number): ImmersiveAction {
    if (!this.lastReady) {
      this.lastY = pos;
      this.lastReady = true;
      return 'none';
    }
    const delta: number = pos - this.lastY;
    this.lastY = pos;
    if (delta === 0) {
      return 'none';
    }
    // 置顶保护：顶部恒显示
    if (pos <= IMMERSIVE_EXTRA_TOP_KEEP) {
      this.accum = 0;
      if (this.hidden) {
        return 'reset';
      }
      return 'none';
    }
    // 跳变保护：命令式滚动 / 形态切换，丢弃本次方向判定
    if (Math.abs(delta) > IMMERSIVE_EXTRA_JUMP_LIMIT) {
      this.accum = 0;
      return 'none';
    }
    if (delta > 0) {
      // 向下滚（看更下方内容）→ 累计 24vp 藏起
      this.accum = this.accum > 0 ? this.accum + delta : delta;
      if (!this.hidden && this.accum >= IMMERSIVE_EXTRA_HIDE_DIST) {
        this.accum = 0;
        this.hidden = true;
        return 'hide';
      }
    } else {
      // 向上滚 → 只要 12vp 就恢复
      this.accum = this.accum < 0 ? this.accum + delta : delta;
      if (this.hidden && this.accum <= -IMMERSIVE_EXTRA_REVEAL_DIST) {
        this.accum = 0;
        this.hidden = false;
        return 'show';
      }
    }
    return 'none';
  }

  /** 复位基线（形态切换 / 离页 / 强制恢复时调用）：下一次滚动只记录位置、不判定 */
  resetBaseline(): void {
    this.accum = 0;
    this.lastReady = false;
  }

  /** 位置是否在置顶保护区（供调用方在触顶 / 回顶路径主动恢复显示） */
  isPastTop(pos: number): boolean {
    return pos > IMMERSIVE_EXTRA_TOP_KEEP;
  }
}
