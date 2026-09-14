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

import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { Theme, Spacing, Radius, isDarkMode, setDarkMode as applyAppDarkMode, syncDarkFromConfig, resetConfigurationToFollowSystem, ImmBlur, ImmMaterial, MaterialManager, fs, tabletTopFadeStop } from '../common/Theme';
import { UsageHabitsManager } from '../service/UsageHabitsManager';
import { BRAND_BLUE } from '../common/Constants';

@Entry
@Component
struct PersonalizedPage {
  @StorageLink('fontScale') fontScale: number = 1.0;
  /** 页面可见时自增，强制组件重建使字号实时生效 */
  @State fontSizeTick: number = 0;
  /** 「深色模式」手动开关（仅当 followSystem=false 时生效；持久化） */
  @StorageLink('appDarkMode') darkMode: boolean = false;
  /** 「跟随系统深色模式」开关（默认 true；持久化） */
  @StorageLink('appFollowSystemDark') followSystem: boolean = true;
  /** darkTick 自增：本页或其它入口（含系统 onConfigurationUpdate）触发后翻 this.isDark，与首页/MineTab 同链路 */
  @StorageLink('darkTick') @Watch('onDarkTick') darkTick: number = 0;

  onPageShow(): void {
    this.fontSizeTick++;
  }
  @State isDark: boolean = isDarkMode();

  aboutToAppear(): void {
    MaterialManager.init();
    this.isDark = isDarkMode();
    // 兜底：若冷启动 Index.aboutToAppear 异常未初始化，这里也能补上（正常路径下已初始化）
    UsageHabitsManager.getInstance().init(this.getUIContext().getHostContext() as common.UIAbilityContext);
  }

  /** darkTick 递增（任意入口切换深色，包括系统 onConfigurationUpdate）→ 重读 isDarkMode() 翻本组件渲染色 */
  private onDarkTick(): void {
    this.isDark = isDarkMode();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 内容层：全屏沉浸滚动（参数同 Settings.ets /「我的」页范式）
      Scroll() {
        Column({ space: Spacing.sm }) {
          // 预留顶栏高度的初始间距
          Column()
            .width('100%')
            .height(90)
          // 字体大小条目
          Row({ space: Spacing.md }) {
            Stack() {
              Text('A')
                .fontSize(fs(15, this.fontScale))
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.textPrimary(this.isDark))
            }
            .width(24)
            .height(24)
            .border({ width: 2, color: Theme.textPrimary(this.isDark), radius: 4 })
            .alignContent(Alignment.Center)

            Column({ space: 2 }) {
              Text('字体大小')
                .fontSize(fs(18, this.fontScale))
                .fontWeight(FontWeight.Medium)
                .fontColor(Theme.textPrimary(this.isDark))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            .margin({ left: Spacing.xs })

            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontColor([$r('sys.color.icon_secondary')])
              .fontSize(fs(18, this.fontScale))
          }
          .width('100%')
          .padding({ left: Spacing.lg, right: Spacing.lg, top: Spacing.xl, bottom: Spacing.xl })
          .backgroundColor(Theme.bgCard(this.isDark))
          .borderRadius(Radius.lg)
          .margin({ top: Spacing.sm })
          .onClick(() => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/FontSizePage' }).catch(() => {});
          })

          // 深色模式（手动开关）：触动本开关即自动关闭「跟随系统」，使生效行为 = 本开关值
          Row({ space: Spacing.md }) {
            SymbolGlyph($r('sys.symbol.moon_fill'))
              .fontColor([Theme.textPrimary(this.isDark)])
              .fontSize(fs(22, this.fontScale))

            Column({ space: 2 }) {
              Text('深色模式')
                .fontSize(fs(18, this.fontScale))
                .fontWeight(FontWeight.Medium)
                .fontColor(Theme.textPrimary(this.isDark))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            .margin({ left: Spacing.xs })

            Toggle({ type: ToggleType.Switch, isOn: this.darkMode })
              .selectedColor(BRAND_BLUE)
              .onChange((isOn: boolean) => {
                // 与首页右上角完全等价的切换流程：
                // 1. 立即翻本组件 this.isDark（不依赖 setColorMode 重建，避免视觉卡顿）
                // 2. 写 manual + 关跟随系统
                // 3. Theme.setDarkMode 同步 _globalIsDark + 系统 Configuration + 状态栏
                // 4. darkTick++ 触发其它监听 darkTick 的页面（FavoriteTab/MineTab 等）翻 @State isDark
                this.isDark = isOn;
                UsageHabitsManager.getInstance().setFollowSystemDark(false);
                UsageHabitsManager.getInstance().setDarkModeManual(isOn);
                applyAppDarkMode(isOn);
                AppStorage.setOrCreate<number>('darkTick', (AppStorage.get<number>('darkTick') ?? 0) + 1);
              })
          }
          .width('100%')
          .padding({ left: Spacing.lg, right: Spacing.lg, top: Spacing.xl, bottom: Spacing.xl })
          .backgroundColor(Theme.bgCard(this.isDark))
          .borderRadius(Radius.lg)
          .margin({ top: Spacing.sm })

          // 跟随系统深色模式：开启时立即按系统当前态落地；关闭时不切色，由「深色模式」toggle 接管
          Row({ space: Spacing.md }) {
            SymbolGlyph($r('sys.symbol.brightness'))
              .fontColor([Theme.textPrimary(this.isDark)])
              .fontSize(fs(22, this.fontScale))

            Column({ space: 2 }) {
              Text('跟随系统深色模式')
                .fontSize(fs(18, this.fontScale))
                .fontWeight(FontWeight.Medium)
                .fontColor(Theme.textPrimary(this.isDark))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            .margin({ left: Spacing.xs })

            Toggle({ type: ToggleType.Switch, isOn: this.followSystem })
              .selectedColor(BRAND_BLUE)
              .onChange((isOn: boolean) => {
                UsageHabitsManager.getInstance().setFollowSystemDark(isOn);
                if (isOn) {
                  // 开启跟随系统：写 manual = 当前系统档 + 调 resetConfigurationToFollowSystem 把
                  // Configuration 重置为 NOT_SET（系统档驱动） + 调 syncDarkFromConfig 同步 _globalIsDark。
                  //
                  // 关键：这里**不调 setColorMode(DARK/LIGHT)**，让 Application Configuration 保持
                  // COLOR_MODE_NOT_SET（跟系统档），永不锁死。这样后续系统切深色/切浅色时，
                  // Configuration 自动跟档，ForumsTitleBar / HomeTitleBar 的 systemMaterial 与
                  // $r('sys.color.font_primary') 自动翻档。
                  // 手动档（用户切色 / PersonalizedPage 深色模式 toggle）才会调 setColorMode 锁死。
                  const ctx: common.UIAbilityContext =
                    this.getUIContext().getHostContext() as common.UIAbilityContext;
                  const sysDark: boolean =
                    ctx.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
                  UsageHabitsManager.getInstance().setDarkModeManual(sysDark);
                  resetConfigurationToFollowSystem();
                  syncDarkFromConfig(sysDark);
                  this.isDark = sysDark;
                  AppStorage.setOrCreate<number>('darkTick', (AppStorage.get<number>('darkTick') ?? 0) + 1);
                } else {
                  // 关闭：不切色——保持当前 dark 值，「深色模式」toggle 后续接管
                  // 仍递增 darkTick 让其它页面同步（即便本组件未切色，也保证链路上各页 @State isDark 与开关一致）
                  AppStorage.setOrCreate<number>('darkTick', (AppStorage.get<number>('darkTick') ?? 0) + 1);
                }
              })
          }
          .width('100%')
          .padding({ left: Spacing.lg, right: Spacing.lg, top: Spacing.xl, bottom: Spacing.xl })
          .backgroundColor(Theme.bgCard(this.isDark))
          .borderRadius(Radius.lg)
          .margin({ top: Spacing.sm })
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

      // 悬浮沉浸顶栏（透明底，内容可穿过；参数同 Settings.ets）
      this.TopBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg(this.isDark))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  /** 悬浮沉浸顶栏（透明底，内容可穿过；参数同 Settings.ets） */
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

      Text('个性化')
        .fontSize(fs(18, this.fontScale))
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.textPrimary(this.isDark))
    }
    .width('100%')
    .padding({ left: Spacing.lg, right: Spacing.lg, top: 44, bottom: 10 })
    .backgroundColor(Color.Transparent)
    .zIndex(14)
  }

  /** 渐变沉浸遮罩：顶部渐显（同 Settings.ets / Index「我的」范式） */
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