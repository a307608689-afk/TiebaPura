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
import { display } from '@kit.ArkUI';
import { UsageHabitsManager } from '../service/UsageHabitsManager';
import { Theme, Spacing, Radius, isDarkMode, ImmBlur, ImmMaterial, MaterialManager, fs, tabletTopFadeStop, isWideBarFlatDevice } from '../common/Theme';
import { BRAND_BLUE } from '../common/Constants';

/** 「吧主页默认进入界面」档位选项：0 = 热门（默认）/ 1 = 最新。 */
const FORUM_SORT_OPTIONS: number[] = [0, 1];

/**
 * 「吧主页默认进入界面」二选一弹窗（系统 CustomDialog + API 26 沉浸光感）。
 * 玻璃层交给 options.systemMaterial（ImmMaterial.dialog()），卡内不再自绘
 * backgroundColor / border / backgroundBlurStyle / shadow（与工程既有弹窗约定一致）。
 */
@CustomDialog
struct ForumDefaultSortDialog {
  /** 系统弹窗必须声明 CustomDialogController 类型属性（ArkTS 编译期强校验） */
  controller?: CustomDialogController;
  @Link isDark: boolean;
  @Link fontScale: number;
  /** 当前档位（0 = 热门 / 1 = 最新）：选中项高亮用 */
  @Link mode: number;
  /** 选定档位回调（写 AppStorage + 落盘） */
  onPick: (mode: number) => void = () => {};
  onDismiss: () => void = () => {};

  /** 档位说明（选项副文案） */
  private optionNote(m: number): string {
    if (m === 1) {
      return '吧主页打开先显示最新排序';
    }
    return '吧主页打开先显示热门排序';
  }

  /** 档位名称 */
  private optionLabel(m: number): string {
    return m === 1 ? '最新' : '热门';
  }

  build() {
    Column({ space: Spacing.md }) {
      Text('吧主页默认进入界面')
        .fontSize(fs(17, this.fontScale))
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.textPrimary(this.isDark))
        .textAlign(TextAlign.Center)
        .width('100%')

      Text('选择进入任意吧主页时默认显示的排序')
        .fontSize(fs(12, this.fontScale))
        .fontColor(Theme.textTertiary(this.isDark))
        .textAlign(TextAlign.Center)
        .width('100%')

      ForEach(FORUM_SORT_OPTIONS, (m: number) => {
        Row({ space: Spacing.sm }) {
          Column({ space: 2 }) {
            Text(this.optionLabel(m))
              .fontSize(fs(15, this.fontScale))
              .fontWeight(this.mode === m ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(Theme.textPrimary(this.isDark))
            Text(this.optionNote(m))
              .fontSize(fs(11, this.fontScale))
              .fontColor(Theme.textTertiary(this.isDark))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          if (this.mode === m) {
            SymbolGlyph($r('sys.symbol.checkmark_circle'))
              .fontColor([Theme.brand()])
              .fontSize(fs(20, this.fontScale))
          }
        }
        .width('100%')
        .padding({ left: Spacing.md, right: Spacing.md, top: Spacing.md, bottom: Spacing.md })
        .backgroundColor(this.mode === m ? (this.isDark ? '#333173FF' : '#1A3173FF') : Color.Transparent)
        .borderRadius(Radius.md)
        .onClick(() => { this.onPick(m); })
      }, (m: number) => `forum_sort_${m}`)

      Button() {
        Text('取消')
          .fontSize(fs(15, this.fontScale))
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.textPrimary(this.isDark))
      }
      .width('100%')
      .height(44)
      .systemMaterial(ImmMaterial.cardAction())
      .backgroundColor(this.isDark ? '#B31B1E24' : '#B3FFFFFF')
      .borderRadius(Radius.full)
      .shadow({ radius: 10, color: this.isDark ? '#4D000000' : '#1F101824', offsetY: 3 })
      .onClick(() => { this.onDismiss(); })
    }
    .width('100%')
    .padding(Spacing.lg)
  }
}

@Entry
@Component
struct UsageHabitsPage {
  @StorageLink('homeOnlyFollow') onlyFollow: boolean = false;
  /** 「关闭自动旋转」开关（仅阔直屏直板显示；true = 已关闭自动旋转、固定竖屏） */
  @StorageLink('autoRotateOff') autoRotateOff: boolean = false;
  /** 「吧主页默认进入界面」档位（0 = 热门 / 1 = 最新；持久化，弹窗点选即写） */
  @StorageLink('forumDefaultSort') forumDefaultSort: number = 0;
  @State isDark: boolean = isDarkMode();
  @StorageLink('fontScale') fontScale: number = 1.0;
  /** 页面可见时自增，强制组件重建使字号实时生效 */
  @State fontSizeTick: number = 0;
  /** 「吧主页默认进入界面」二选一弹窗控制器（几何与工程既有 CustomDialog 同源：宽 dialogCardWidth、圆角 32、底部锚点 dy -110） */
  private forumSortController: CustomDialogController = new CustomDialogController({
    builder: ForumDefaultSortDialog({
      isDark: $isDark,
      fontScale: $fontScale,
      mode: $forumDefaultSort,
      onPick: (m: number) => { this.pickForumDefaultSort(m); },
      onDismiss: () => { this.closeForumSortDialog(); }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Bottom,
    offset: { dx: 0, dy: -110 },
    maskColor: '#06000000',
    cornerRadius: 32,
    width: this.dialogCardWidth(),
    customStyle: false,
    systemMaterial: ImmMaterial.dialog(),
    openAnimation: { duration: 220, curve: Curve.EaseOut },
    closeAnimation: { duration: 200, curve: Curve.EaseInOut },
    onWillDismiss: () => { }
  });

  onPageShow(): void {
    this.fontSizeTick++;
  }

  aboutToAppear(): void {
    MaterialManager.init();
    this.isDark = isDarkMode();
    UsageHabitsManager.getInstance().init(this.getUIContext().getHostContext() as common.UIAbilityContext);
  }

  /** 「吧主页默认进入界面」选定档位：走 manager 写 AppStorage + 落盘，随后关闭弹窗（显示值经 @StorageLink 自动同步） */
  private pickForumDefaultSort(mode: number): void {
    UsageHabitsManager.getInstance().setForumDefaultSort(mode).catch(() => {
    });
    this.closeForumSortDialog();
  }

  /** 关闭「吧主页默认进入界面」弹窗 */
  private closeForumSortDialog(): void {
    this.forumSortController.close();
  }

  /**
   * 「吧主页默认进入界面」弹窗宽度（vp 数值）—— 与个性化页 / 收藏页同款：`max(200, min(400, 屏宽 − 48))`。
   * 必须给数值：`CustomDialogControllerOptions.width` 类型是 `Dimension`，不接受 `calc(100% - 48vp)` 字符串。
   */
  private dialogCardWidth(): number {
    try {
      const info: display.Display = display.getDefaultDisplaySync();
      const widthVp: number = info.width / info.densityPixels;
      return Math.max(200, Math.min(400, widthVp - 48));
    } catch (e) {
      return 312;
    }
  }

  /** 当前档位显示文案（设置行右侧） */
  private forumSortLabel(): string {
    return this.forumDefaultSort === 1 ? '最新' : '热门';
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
          // 仅推荐关注的吧
          Row({ space: Spacing.md }) {
            SymbolGlyph($r('sys.symbol.hand'))
              .fontColor([Theme.brand()])
              .fontSize(fs(22, this.fontScale))

            Column({ space: 2 }) {
              Text('仅推荐关注的吧')
                .fontSize(fs(16, this.fontScale))
                .fontWeight(FontWeight.Medium)
                .fontColor(Theme.textPrimary(this.isDark))
              Text('首页推荐仅显示关注吧的帖子')
                .fontSize(fs(13, this.fontScale))
                .fontColor(Theme.textSecondary(this.isDark))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Toggle({ type: ToggleType.Switch, isOn: this.onlyFollow })
              .selectedColor(BRAND_BLUE)
              .onChange((isOn: boolean) => {
                UsageHabitsManager.getInstance().setOnlyFollow(isOn);
              })
          }
          .width('100%')
          .padding({ left: Spacing.lg, right: Spacing.lg, top: Spacing.md, bottom: Spacing.md })
          .backgroundColor(Theme.bgCard(this.isDark))
          .borderRadius(Radius.lg)
          .margin({ top: Spacing.sm })

          // 吧主页默认进入界面：点开二选一弹窗（热门 / 最新）
          Row({ space: Spacing.md }) {
            Text('⇅')
              .fontSize(fs(20, this.fontScale))
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.brand())

            Column({ space: 2 }) {
              Text('吧主页默认进入界面')
                .fontSize(fs(16, this.fontScale))
                .fontWeight(FontWeight.Medium)
                .fontColor(Theme.textPrimary(this.isDark))
              Text('选择进入吧主页时默认显示的排序')
                .fontSize(fs(13, this.fontScale))
                .fontColor(Theme.textSecondary(this.isDark))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Text(this.forumSortLabel())
              .fontSize(fs(14, this.fontScale))
              .fontColor(Theme.textSecondary(this.isDark))

            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontColor([Theme.textTertiary(this.isDark)])
              .fontSize(fs(16, this.fontScale))
          }
          .width('100%')
          .padding({ left: Spacing.lg, right: Spacing.lg, top: Spacing.md, bottom: Spacing.md })
          .backgroundColor(Theme.bgCard(this.isDark))
          .borderRadius(Radius.lg)
          .onClick(() => { this.forumSortController.open(); })

          // 关闭自动旋转（仅阔直屏直板显示：只有该形态由本应用主动解锁了自动旋转）
          if (isWideBarFlatDevice()) {
            Row({ space: Spacing.md }) {
              SymbolGlyph($r('sys.symbol.arrow_clockwise'))
                .fontColor([Theme.brand()])
                .fontSize(fs(22, this.fontScale))

              Column({ space: 2 }) {
                Text('关闭自动旋转')
                  .fontSize(fs(16, this.fontScale))
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Theme.textPrimary(this.isDark))
                Text('开启后固定竖屏，不再自动转为横屏')
                  .fontSize(fs(13, this.fontScale))
                  .fontColor(Theme.textSecondary(this.isDark))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Toggle({ type: ToggleType.Switch, isOn: this.autoRotateOff })
                .selectedColor(BRAND_BLUE)
                .onChange((isOn: boolean) => {
                  UsageHabitsManager.getInstance().setAutoRotateOff(isOn);
                })
            }
            .width('100%')
            .padding({ left: Spacing.lg, right: Spacing.lg, top: Spacing.md, bottom: Spacing.md })
            .backgroundColor(Theme.bgCard(this.isDark))
            .borderRadius(Radius.lg)
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

      Text('使用习惯')
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
