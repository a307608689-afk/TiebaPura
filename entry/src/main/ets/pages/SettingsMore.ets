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
import { UsageHabitsManager } from '../service/UsageHabitsManager';
import { Theme, Spacing, Radius, isDarkMode, ImmBlur, ImmMaterial, MaterialManager, fs, tabletTopFadeStop } from '../common/Theme';
import { BRAND_BLUE } from '../common/Constants';

/**
 * 设置 - 更多（2026-09-20 新建，此前"更多"为"即将开放"占位）：
 * 「帖子极速开启」开关——feed 首屏前 3 卡详情+图片预取，点开首屏卡即内存缓存直出真秒开。
 * 默认关闭（用户拍板）；真源 AppStorage 'threadFastOpen'，manager 负责冷启动恢复与落盘。
 * Toggle 按 97056668 纪律用「纯显示 + 外层 Row onClick」：isOn 绑定的 AppStorage 会被
 * manager 写入（init 恢复），编程性变化不得触发开关副作用。
 */
@Entry
@Component
struct SettingsMorePage {
  @StorageLink('threadFastOpen') threadFastOpen: boolean = true;
  @StorageLink('threadFastWifi') threadFastWifi: boolean = true;
  @State isDark: boolean = isDarkMode();
  @StorageLink('fontScale') fontScale: number = 1.0;
  /** 页面可见时自增，强制组件重建使字号实时生效 */
  @State fontSizeTick: number = 0;

  onPageShow(): void {
    this.fontSizeTick++;
  }

  aboutToAppear(): void {
    MaterialManager.init();
    this.isDark = isDarkMode();
    UsageHabitsManager.getInstance().init(this.getUIContext().getHostContext() as common.UIAbilityContext);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 内容层：全屏沉浸滚动（参数同 UsageHabitsPage / Settings 范式）
      Scroll() {
        Column({ space: Spacing.sm }) {
          // 预留顶栏高度的初始间距
          Column()
            .width('100%')
            .height(90)

          // 帖子极速开启（纯显示 Toggle + 外层 Row onClick，见 97056668 纪律）
          Row({ space: Spacing.md }) {
            SymbolGlyph($r('sys.symbol.bolt'))
              .fontColor([Theme.brand()])
              .fontSize(fs(22, this.fontScale))

            Column({ space: 2 }) {
              Text('帖子极速开启')
                .fontSize(fs(16, this.fontScale))
                .fontWeight(FontWeight.Medium)
                .fontColor(Theme.textPrimary(this.isDark))
              Text('主动预加载部分内容，实现更快加载，但流量消耗会上升')
                .fontSize(fs(13, this.fontScale))
                .fontColor(Theme.textSecondary(this.isDark))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Toggle({ type: ToggleType.Switch, isOn: this.threadFastOpen })
              .selectedColor(BRAND_BLUE)
              .hitTestBehavior(HitTestMode.None)
          }
          .width('100%')
          .padding({ left: Spacing.lg, right: Spacing.lg, top: Spacing.md, bottom: Spacing.md })
          .backgroundColor(Theme.bgCard(this.isDark))
          .borderRadius(Radius.lg)
          .margin({ top: Spacing.sm })
          .onClick(() => {
            UsageHabitsManager.getInstance().setThreadFastOpen(!this.threadFastOpen);
          })

          // 仅 WiFi 启用（仅主开关开启时显示；默认开启）：非 WiFi 环境不执行预加载
          if (this.threadFastOpen) {
            Row({ space: Spacing.md }) {
              SymbolGlyph($r('sys.symbol.wifi'))
                .fontColor([Theme.brand()])
                .fontSize(fs(20, this.fontScale))

              Column({ space: 2 }) {
                Text('仅 WiFi 启用')
                  .fontSize(fs(15, this.fontScale))
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Theme.textPrimary(this.isDark))
                Text('移动数据环境下不执行预加载')
                  .fontSize(fs(13, this.fontScale))
                  .fontColor(Theme.textSecondary(this.isDark))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Toggle({ type: ToggleType.Switch, isOn: this.threadFastWifi })
                .selectedColor(BRAND_BLUE)
                .hitTestBehavior(HitTestMode.None)
            }
            .width('100%')
            .padding({ left: Spacing.lg, right: Spacing.lg, top: Spacing.md, bottom: Spacing.md })
            .backgroundColor(Theme.bgCard(this.isDark))
            .borderRadius(Radius.lg)
            .onClick(() => {
              UsageHabitsManager.getInstance().setThreadFastWifi(!this.threadFastWifi);
            })
          }
        }
        .width('100%')
        .padding({ left: Spacing.lg, right: Spacing.lg, bottom: Spacing.xl })
      }
      .scrollBar(BarState.Off)
      .scrollable(ScrollDirection.Vertical)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
      .layoutWeight(1)
      .clip(false)
      .align(Alignment.TopStart)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .overlay(this.BottomFadeOverlay())
      .blendMode(BlendMode.SRC_OVER, BlendApplyType.OFFSCREEN)

      // 悬浮沉浸顶栏（透明底，内容可穿过；参数同 UsageHabitsPage）
      this.TopBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg(this.isDark))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  /** 悬浮沉浸顶栏（透明底，内容可穿过；参数同 UsageHabitsPage / Settings） */
  @Builder
  TopBar() {
    Row({ space: Spacing.sm }) {
      Button() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontColor([$r('sys.color.icon_primary')])
          .fontSize(fs(22, this.fontScale))
      }
      .width(44)
      .height(44)
      .backgroundColor(Theme.manualGlass(this.isDark))
      .border({ width: 0.5, color: Theme.manualGlassBorder() })
      .shadow(Theme.glassShadowStyle()).backgroundEffect(ImmBlur.control())
      .systemMaterial(ImmMaterial.control())
      .borderRadius(Radius.full)
      .accessibilityText('返回')
      .onClick(() => { this.getUIContext().getRouter().back(); })

      Text('更多')
        .fontSize(fs(18, this.fontScale))
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.textPrimary(this.isDark))
    }
    .width('100%')
    .padding({ left: Spacing.lg, right: Spacing.lg, top: 44, bottom: 10 })
    .backgroundColor(Color.Transparent)
    .zIndex(14)
  }

  /** 渐变沉浸遮罩：顶部渐显（同 UsageHabitsPage / Settings 范式） */
  @Builder
  BottomFadeOverlay() {
    Stack()
      .height('100%')
      .width('100%')
      .linearGradient({
        direction: GradientDirection.Bottom,
        colors: [['#00FFFFFF', 0.0], ['#FFFFFFFF', tabletTopFadeStop(98)], ['#FFFFFFFF', 1.0]]
      })
      .blendMode(BlendMode.DST_IN, BlendApplyType.OFFSCREEN)
      .hitTestBehavior(HitTestMode.None)
  }
}
