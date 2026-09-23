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
 * 剩余距离预取闸门（PrefetchGate）—— 帖子流「触底无缝续流」的统一判据与节流。
 *
 * 为什么要有这个类：同一段「remaining = contentH − viewportH − y；remaining ≤ 阈值就预取；
 * 偏移变化 ≥ 120vp 才允许再次触发」的判断，此前在 6 个页面（HomeTab 双 feed / ThreadList /
 * FollowList / Favorite / PersonalContent / UserProfile）各抄了一份，抄的时候带进同一个隐患：
 * **直接用 `onScroll` 回调入参当绝对偏移**。
 *
 * `onScroll` 的入参语义在工具链 / 组件类型之间存在差异（`Scroll` 上曾观测到帧增量语义），
 * 一旦它不是绝对偏移，「剩余距离」就会算成恒小于阈值的错值 —— 表现为预取要么每次滚动都触发
 * （疯狂翻页），要么永不触发（滑到底空一段才加载）。正解是**只信 `Scroller.currentOffset()`**，
 * 这正是帖子详情页（ThreadDetail.onDetailScrollPrefetch）已经在用的口径，本类把它收口为单点。
 *
 * 用法（三件事）：
 * 1. 构造：`private gate: PrefetchGate = new PrefetchGate(1200, 'ThreadList');`
 * 2. 滚动：`if (this.gate.should(PrefetchGate.absoluteY(this.scroller), contentH, viewportH)) { loadMore(true); }`
 * 3. 复位：刷新 / 切排序 / 切 feed / 换列表时 `this.gate.reset();`
 *
 * 注意（§ 帖子预加载文档 §8）：`contentH` / `viewportH` 一律用**普通字段**承接
 * （`onAreaChange` / `onScroll` 是高频回调，写 `@State` 会触发无谓整树重建），
 * 本类自身也只存普通字段，页面调用它不会产生状态变更。
 */

/** 默认节流步长（vp）：同一轮滚动内偏移变化不足该值不再触发，避免连续请求 */
export const PREFETCH_THROTTLE: number = 120;

export class PrefetchGate {
  /** 阈值（vp）：剩余距离 ≤ 该值即视为「快到底」，应提前静默取下一页 */
  readonly distance: number;
  private readonly throttle: number;
  /** 探针标签：日志以 `[PREFETCH] <tag>` 输出，便于真机按页面过滤自证 */
  private readonly tag: string;
  /** 上次触发时的绝对偏移（vp）：-1 = 尚未触发过（首轮必放行，等价旧实现的 -10000 初值但语义明确） */
  private lastY: number = -1;

  constructor(distance: number, tag: string, throttle: number = PREFETCH_THROTTLE) {
    this.distance = distance;
    this.tag = tag;
    this.throttle = throttle;
  }

  /**
   * 取滚动绝对偏移真值（vp）。**不要用 `onScroll` 回调入参**（语义在工具链间有差异，见类注释）。
   * 取不到（Scroller 尚未绑定 / 组件已销毁）时返回 0：宁可本轮不触发，也不要用错值误触发。
   */
  static absoluteY(scroller: Scroller): number {
    try {
      return scroller.currentOffset().yOffset;
    } catch (e) {
      return 0;
    }
  }

  /**
   * 判定本次滚动是否应触发预取（内部已更新节流基线，返回 true 即可直接发起静默加载）。
   *
   * @param y 绝对滚动偏移（vp）——必须来自 `PrefetchGate.absoluteY(scroller)`
   * @param contentH 内容总高（vp）：单列 `Scroll + Column` 由 `onAreaChange` 实测；
   *                 虚拟容器（`WaterFlow` / `List`）无内容总高接口，由调用方折算后传入
   * @param viewportH 视口高（vp）：由滚动容器 `onAreaChange` 实测
   */
  should(y: number, contentH: number, viewportH: number): boolean {
    // 几何未测到（首帧 / 刚从 Loading 切换 / 虚拟容器尚未量出）：本轮不判定，等 onAreaChange 回填
    if (contentH <= 0 || viewportH <= 0) {
      return false;
    }
    const remaining: number = contentH - viewportH - y;
    if (remaining > this.distance) {
      return false;
    }
    // 节流：偏移变化超过 throttle 才允许再次触发（首轮 lastY = -1 直接放行）
    if (this.lastY >= 0 && Math.abs(y - this.lastY) < this.throttle) {
      return false;
    }
    this.lastY = y;
    console.info(`[PREFETCH] ${this.tag} FIRE y=${y.toFixed(0)}`
      + ` contentH=${contentH.toFixed(0)} viewportH=${viewportH.toFixed(0)}`
      + ` remaining=${remaining.toFixed(0)} threshold=${this.distance}`);
    return true;
  }

  /** 复位节流基线：刷新 / 切换排序 / 切换 feed / 换列表时调用（内容与偏移整体换新，旧基线无意义） */
  reset(): void {
    this.lastY = -1;
  }

  /**
   * 几何来源诊断（低频）：仅在内容高「测到」或「折算」完成后调用一次，用于真机自证
   * 「为什么没触发预取」—— 有 FIRE 日志说明判定生效；只有 geometry 没有 FIRE 说明几何在但还没滑到阈值。
   */
  noteGeometry(source: string, contentH: number, viewportH: number): void {
    console.info(`[PREFETCH] ${this.tag} geometry src=${source}`
      + ` contentH=${contentH.toFixed(0)} viewportH=${viewportH.toFixed(0)}`);
  }

  /**
   * 瀑布流卡片高度估算（vp）：文本区固定 ≈ 200（标题 ≤2 行 + 摘要 ≤2 行 + 作者/操作栏），
   * 首图按 16:9 折算 cardW × 0.5625，再按「约半数帖子带图」打 0.5 权重 —— 混合估、偏小口径。
   */
  static estimateCardHeight(cardW: number): number {
    return Math.round(200 + cardW * 0.5625 * 0.5);
  }

  /**
   * 虚拟容器（WaterFlow / List）内容总高折算（vp）：只算「每列条数 ×(卡高 + 行距)」，
   * **刻意不计顶部/底部让位** —— 折算偏小 → 剩余距离偏小 → 触发更早，宁可早取不漏取
   *（见 docs/帖子预加载.md §8 维护须知）。
   */
  static estimateWaterfallContentH(count: number, cols: number, contentW: number, rowGap: number): number {
    const safeCols: number = Math.max(1, cols);
    const rows: number = Math.ceil(count / safeCols);
    return rows * (PrefetchGate.estimateCardHeight(contentW / safeCols) + rowGap);
  }
}
