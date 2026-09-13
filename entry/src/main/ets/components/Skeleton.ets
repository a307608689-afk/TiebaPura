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

import { LengthMetrics } from '@kit.ArkUI';
import { Theme, Spacing, Radius, isDarkMode } from '../common/Theme';

/**
 * 骨架屏组件（第四批 · 首屏加载态）
 * - ThreadCardSkeleton：帖子卡占位（方案G：整块"未上墨的纸"，无内部灰色块）
 * - ThreadListSkeleton：N 张帖子卡占位列表
 * - ListRowSkeleton：列表行骨架（圆头像 + 两行文字，用于收藏吧分类聚合/进吧列表等）
 * - ThreadDetailSkeleton：帖子详情页骨架（楼主帖 + 回复楼层，整页同节奏呼吸）
 *
 * v1.16 方案G（整页"未上墨"呼吸）：
 * - 不做任何内部块状占位，每张占位卡只是一整块接近页面底色的浅色圆角矩形
 *   （比页面底色略深一档，像一张还没上墨的纸，与背景/主题天然协调）
 * - 整块纸覆盖一层极轻的半透明白，缓慢呼吸起伏（900ms 往返），无扫光无条纹
 * - 卡片高度按 index 分布（240/300/200），模拟真实帖子有图/无图的高度差
 * - 挂载时整体淡入，避免瞬间硬切
 */
@Component
export struct ThreadCardSkeleton {
  @Prop index: number = 0;
  /**
   * 拉伸模式（平板适配文档 §4.2 决策 11）：多列行分组下由 Flex(Stretch) 拉伸到行高，
   * 骨架随之等高，避免「骨架有高度差 → 内容等高」的跳变。单列档恒 false（手机零回归）。
   */
  @Prop stretch: boolean = false;
  @State pulseOpacity: number = 0;
  @State pulseUp: boolean = true;
  @State cardOpacity: number = 0;
  private timer: number = -1;
  @StorageLink('fontScale') fontScale: number = 1.0;

  aboutToAppear(): void {
    // 挂载淡入，避免骨架屏瞬间硬切
    animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.cardOpacity = 1;
    });
    this.startPulse();
  }

  aboutToDisappear(): void {
    if (this.timer !== -1) {
      clearTimeout(this.timer);
      this.timer = -1;
    }
  }

  /**
   * 缓慢呼吸：纸面高亮层 opacity 在 0 与峰值之间往返。
   * 两端都走 animateTo 平滑过渡，无瞬间跳变，不会产生条纹。
   */
  private startPulse(): void {
    animateTo({ duration: 900, curve: Curve.EaseInOut }, () => {
      this.pulseOpacity = this.pulseUp ? 1 : 0;
    });
    this.pulseUp = !this.pulseUp;
    this.timer = setTimeout(() => {
      this.startPulse();
    }, 900);
  }

  /** 卡片高度：按 index 分布模拟真实帖子卡片（无图/单图/大图）的高度差 */
  private cardHeight(): number {
    switch (this.index % 3) {
      case 1: return 300;
      case 2: return 200;
      default: return 240;
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // ===== 未上墨的"纸" =====
      Column()
        .width('100%')
        .height(this.stretch ? '100%' : this.cardHeight())
        .borderRadius(Radius.lg)
        .backgroundColor(Theme.skeletonSheet(isDarkMode()))
        .opacity(this.cardOpacity)

      // ===== 呼吸高亮层：极轻的白色叠加，整张纸缓慢起伏 =====
      Column()
        .width('100%')
        .height(this.stretch ? '100%' : this.cardHeight())
        .borderRadius(Radius.lg)
        .backgroundColor(Color.White)
        .opacity(this.pulseOpacity * (isDarkMode() ? 0.10 : 0.35))
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .clip(true)
    .borderRadius(Radius.lg)
  }
}

/**
 * N 张帖子卡占位列表（用于首页/吧内列表首屏 Loading）
 * - columns 默认 1：单列档（手机 / 单列二级页）与改造前逐像素一致（列 = 1 走原 Column）
 * - columns > 1：与真实列表**同列数**铺放，避免「单列骨架 → 多列内容」的视觉跳变
 * 注意（平板适配文档 §6.1 D3）：默认值必须为 1，且单列页禁止传入多列值。
 */
@Component
export struct ThreadListSkeleton {
  @Prop count: number = 4;
  /** 列数（默认 1；多列页按当前列数传入） */
  @Prop columns: number = 1;
  @StorageLink('fontScale') fontScale: number = 1.0;

  /** 方案 B 行分组：行下标数组（总行数 = ceil(count / columns)） */
  private skeletonRows(): number[] {
    const n: number = Math.ceil(this.count / this.columns);
    const arr: number[] = [];
    for (let i: number = 0; i < n; i++) {
      arr.push(i);
    }
    return arr;
  }

  /** 第 rowIdx 行的骨架卡下标（不超过总数） */
  private skeletonRowIdx(rowIdx: number): number[] {
    const arr: number[] = [];
    const start: number = rowIdx * this.columns;
    const end: number = Math.min(start + this.columns, this.count);
    for (let i: number = start; i < end; i++) {
      arr.push(i);
    }
    return arr;
  }

  /** 第 rowIdx 行末尾补空位下标（保证末行卡片宽度与其它行一致，§6.1 A2） */
  private skeletonBlanks(rowIdx: number): number[] {
    const arr: number[] = [];
    const filled: number = Math.min(this.count - rowIdx * this.columns, this.columns);
    for (let i: number = filled; i < this.columns; i++) {
      arr.push(i);
    }
    return arr;
  }

  build() {
    if (this.columns > 1) {
      // 多列档（方案 B 行分组）：与真实列表同结构，避免「Loading 单列 → 内容多列」的视觉跳变
      Column() {
        ForEach(this.skeletonRows(), (rowIdx: number) => {
          // 行内等高对齐（§4.2 决策 11）：与真实列表同款容器 + 骨架同步拉伸
          Flex({
            alignItems: ItemAlign.Stretch,
            space: { main: LengthMetrics.vp(Spacing.md) }
          }) {
            ForEach(this.skeletonRowIdx(rowIdx), (i: number) => {
              ThreadCardSkeleton({ index: i, stretch: true })
                .layoutWeight(1)
                .height('100%')
            }, (i: number) => `skeleton_paper_${i}`)
            ForEach(this.skeletonBlanks(rowIdx), (b: number) => {
              Blank()
                .layoutWeight(1)
            }, (b: number) => `skeleton_blank_${rowIdx}_${b}`)
          }
          .width('100%')
          .margin({ bottom: Spacing.md })
        }, (rowIdx: number) => `skeleton_row_${rowIdx}`)
      }
      .width('100%')
      .padding({ left: Spacing.lg, right: Spacing.lg, top: 0 })
    } else {
      Column({ space: Spacing.md }) {
        ForEach(Array.from({ length: this.count }, (_: number, i: number) => i), (i: number) => {
          ThreadCardSkeleton({ index: i })
        }, (i: number) => `skeleton_paper_${i}`)
      }
      .width('100%')
      .padding({ left: Spacing.lg, right: Spacing.lg, top: 0 })
    }
  }
}

/**
 * 列表行骨架（圆头像 + 两行文字，用于收藏吧分类聚合/进吧列表首屏）
 */
@Component
export struct ListRowSkeleton {
  @Prop count: number = 8;
  @StorageLink('fontScale') fontScale: number = 1.0;

  build() {
    Column({ space: Spacing.sm }) {
      ForEach(Array.from({ length: this.count }, (_: number, i: number) => i), (i: number) => {
        Row({ space: 12 }) {
          Row()
            .width(48)
            .height(48)
            .borderRadius(24)
            .backgroundColor(Theme.skeletonBase(isDarkMode()))
          Column({ space: 8 }) {
            Row()
              .width('40%')
              .height(16)
              .borderRadius(8)
              .backgroundColor(Theme.skeletonBase(isDarkMode()))
            Row()
              .width('25%')
              .height(12)
              .borderRadius(6)
              .backgroundColor(Theme.skeletonBase(isDarkMode()))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: Spacing.lg, right: Spacing.lg, top: 10, bottom: 10 })
        .backgroundColor(Theme.bgCard(isDarkMode()))
        .borderRadius(Radius.lg)
      }, (i: number) => `skeleton_row_${i}`)
    }
    .width('100%')
    .padding({ left: Spacing.lg, right: Spacing.lg, top: 0 })
  }
}

/**
 * 帖子详情页骨架屏（方案G：整块"未上墨的纸"呼吸，与吧主页 ThreadListSkeleton 同一方案）
 * - 楼主帖区域：一块较高的纸
 * - "全部回复"分隔头：短细条
 * - 回复楼层区域：错落高度的纸块
 * - 整页共用同一呼吸节奏，挂载时整体淡入
 */
@Component
export struct ThreadDetailSkeleton {
  @State pulseOpacity: number = 0;
  @State pulseUp: boolean = true;
  @State cardOpacity: number = 0;
  private timer: number = -1;

  aboutToAppear(): void {
    // 挂载淡入，避免骨架屏瞬间硬切
    animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.cardOpacity = 1;
    });
    this.startPulse();
  }

  aboutToDisappear(): void {
    if (this.timer !== -1) {
      clearTimeout(this.timer);
      this.timer = -1;
    }
  }

  /**
   * 缓慢呼吸：整页纸面高亮层 opacity 在 0 与峰值之间往返。
   * 两端都走 animateTo 平滑过渡，无瞬间跳变，不会产生条纹。
   */
  private startPulse(): void {
    animateTo({ duration: 900, curve: Curve.EaseInOut }, () => {
      this.pulseOpacity = this.pulseUp ? 1 : 0;
    });
    this.pulseUp = !this.pulseUp;
    this.timer = setTimeout(() => {
      this.startPulse();
    }, 900);
  }

  /** 一整块"未上墨的纸"+ 呼吸高亮层 */
  @Builder
  Sheet(height: number) {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height(height)
        .borderRadius(Radius.lg)
        .backgroundColor(Theme.skeletonSheet(isDarkMode()))

      Column()
        .width('100%')
        .height(height)
        .borderRadius(Radius.lg)
        .backgroundColor(Color.White)
        .opacity(this.pulseOpacity * (isDarkMode() ? 0.10 : 0.35))
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .clip(true)
    .borderRadius(Radius.lg)
  }

  build() {
    Column({ space: Spacing.md }) {
      // 楼主帖区域：较高的一块纸
      this.Sheet(380)
      // "全部回复"分隔头：短细条
      Row()
        .width(96)
        .height(16)
        .borderRadius(8)
        .backgroundColor(Theme.skeletonSheet(isDarkMode()))
        .margin({ top: 6, bottom: 2 })
      // 回复楼层区域：错落高度的纸块
      this.Sheet(220)
      this.Sheet(150)
      this.Sheet(260)
      this.Sheet(180)
    }
    .width('100%')
    .opacity(this.cardOpacity)
    .padding({ left: Spacing.lg, right: Spacing.lg, top: 0 })
  }
}
