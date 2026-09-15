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

import { deviceInfo } from '@kit.BasicServicesKit';
import { display } from '@kit.ArkUI';
import { AuthManager } from '../service/AuthManager';
import { UserStats, FollowItem } from '../model/DataModel';
import { Theme, Spacing, Radius, fs, isDarkMode, setDarkMode, ImmBlur, ImmMaterial, isWideFormDevice as detectWideFormDevice } from '../common/Theme';
import { UsageHabitsManager } from '../service/UsageHabitsManager';

/** 官方标题栏开关：true = 「我的」标题行（含右上角深色切换圆钮）走 Navigation title 槽位吃官方材质（§6.10 模板，与首页/进吧/收藏同机制）；
 *  false = 一键回退到页面主体悬浮自绘玻璃 TopBar（manualGlass + backgroundBlurStyle 真磨砂），旧 TopBar() 原样保留。 */
const MINE_OFFICIAL_TITLE_BAR: boolean = true;
/** 槽位高度 = 44(状态栏让位) + 44(按钮行高) + 10(底部呼吸)，与原悬浮 TopBar 的 padding 逐项一致；
 *  内容让位（List 首项占位 90）一行未改。 */
const MINE_TITLE_BAR_HEIGHT: number = 98;

/**
 * 「我的」主 Tab 页组件（从 Index.ets 内联 Builder MineContent 抽出）：
 * - 形态说明：本页展示的账号资料/统计/关注数与宿主生命周期强耦合——
 *   宿主在 aboutToAppear / onPageShow / 登录登出 / profile 昵称校准各时点统一刷新，
 *   子组件收不到 onPageShow（非 @Entry），因此采用「宿主为数据脑、本页经 @Link 显式注入」，
 *   保证返回子页/登录后数据仍即时刷新，行为与拆分前完全一致。
 * - 仅两类动作回宿主：切到收藏 Tab（openFavorite）、退出登录全局重置（onLogout）。
 * - 页面自身导航（我的主页/个人内容/关注列表/登录/设置）与文案换算逻辑内置。
 * - 深色模式经 AppStorage darkTick 事件同步（isDark 订阅模块全局，可自切）。
 */

@Component
export struct MineTab {
  /**
   * 顶部渐显带收窄（2026-09-13 用户反馈）：平板竖屏下原 15% 渐显覆盖到第一个卡片中部，
   * 要求「只覆盖顶部按钮与标题」→ 平板档覆盖高度 = 顶栏 98vp，手机维持原比例。
   */
  private readonly isWideFormDevice: boolean = detectWideFormDevice();
  /** 屏幕长边（vp）：竖屏视口高的稳定来源（旋转取长边，渐显比例不漂移） */
  @State fadeCoverVp: number = 0;
  @Link loggedIn: boolean;
  @Link userName: string;
  @Link userAvatar: string;
  @Link userStats: UserStats;
  @Link statsLoading: boolean;
  @Link statsError: boolean;
  @Link followUserCount: number;
  @Link followUserLoading: boolean;
  @Link follows: FollowItem[];
  openFavorite: () => void = () => {};
  onLogout: () => void = () => {};
  @State isDark: boolean = isDarkMode();
  @StorageLink('fontScale') fontScale: number = 1.0;
  // 字号全局变更广播（2026-09-13）：@Watch 回写 fontScale 强制本页依赖刷新（离屏缓存不重绘兜底）
  @StorageLink('fontTick') @Watch('onFontTick') fontTick: number = 0;
  @StorageLink('darkTick') @Watch('onDarkTick') darkTick: number = 0;

  aboutToAppear(): void {
    this.isDark = isDarkMode();
    // 顶部渐显带覆盖基准（平板收窄用）：取屏幕长边（竖屏视口高），窗口未 attach 时忽略
    try {
      const d: display.Display = display.getDefaultDisplaySync();
      this.fadeCoverVp = Math.max(d.width, d.height) / d.densityPixels;
    } catch (e) {
      // 忽略：窗口未 attach，fadeCoverVp 保持 0 → topFadeStop() 回退手机比例
    }
  }

  /** 深色切换（来自本页或宿主）后重读全局状态 */
  onDarkTick(): void {
    this.isDark = isDarkMode();
  }

  /** fontTick 递增（字号设置写入 / 宿主返回广播）→ 显式回写 fontScale 强制本页字号依赖刷新 */
  onFontTick(): void {
    this.fontScale = AppStorage.get<number>('fontScale') ?? 1.0;
  }

  private statText(value: number): string {
    if (this.statsLoading) {
      return '…';
    }
    if (value < 0 || this.statsError) {
      return '--';
    }
    return `${value}`;
  }

  private followUserCountText(): string {
    if (this.followUserLoading) {
      return '…';
    }
    if (this.followUserCount < 0) {
      return '--';
    }
    return `${this.followUserCount}`;
  }

  private openLogin(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Login' });
  }

  /** 头像点击：跳转本人用户主页（本人主页隐藏关注/拉黑按钮） */
  private openMyProfile(): void {
    if (!AuthManager.getInstance().isLogin()) {
      this.openLogin();
      return;
    }
    const id: string = `${AuthManager.getInstance().getUser()?.userId ?? ''}`.trim();
    if (id.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '用户信息暂不可用' });
      return;
    }
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/UserProfile',
      params: { userId: id, userName: this.userName }
    }).catch(() => {
      this.getUIContext().getPromptAction().showToast({ message: '用户主页打开失败，请稍后重试' });
    });
  }

  private openPersonalContent(mode: string): void {
    if (!this.loggedIn && mode !== 'history') {
      this.openLogin();
      return;
    }
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/PersonalContent',
      params: { mode }
    }).catch(() => {
      this.getUIContext().getPromptAction().showToast({ message: '页面打开失败，请稍后重试' });
    });
  }

  private openFollowList(): void {
    if (!this.loggedIn) {
      this.getUIContext().getPromptAction().showToast({ message: '请先登录后查看关注列表' });
      return;
    }
    this.getUIContext().getRouter().pushUrl({ url: 'pages/FollowList' }).catch(() => {
    });
  }

  /** 兜底路径专用（MINE_OFFICIAL_TITLE_BAR = false 时才挂载）：页面主体悬浮自绘玻璃 TopBar */
  @Builder
  TopBar() {
    Row() {
      Column({ space: 3 }) {
        Text('我的')
          .fontSize(fs(22, this.fontScale))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Button() {
        SymbolGlyph(this.isDark
          ? $r('sys.symbol.sun_max_fill')
          : $r('sys.symbol.moon_fill'))
          .fontColor([$r('sys.color.icon_primary')])
          .fontSize(fs(20, this.fontScale))
      }
      .width(44)
      .height(44)
      .backgroundColor(Theme.segGlass(this.isDark, false))
      .border({ width: 0.5, color: Theme.manualGlassBorder() })
      .backgroundBlurStyle(BlurStyle.Thin, { scale: 0.85 })
      .shadow(Theme.segGlassShadow(this.isDark, false))
      .borderRadius(Radius.full)
      .margin({ left: 12 })
      .accessibilityText('切换深色模式')
      .onClick(() => {
        this.isDark = !this.isDark;
        // 用户主动切换：写 manual + 关跟随系统（避免 onConfigurationUpdate 在 setColorMode 异步窗口内
        // 拿到旧 Configuration 反向拉回档位）。与 PersonalizedPage 「深色模式」开关完全等价。
        UsageHabitsManager.getInstance().setFollowSystemDark(false);
        UsageHabitsManager.getInstance().setDarkModeManual(this.isDark);
        setDarkMode(this.isDark);
        AppStorage.setOrCreate<number>('darkTick', (AppStorage.get<number>('darkTick') ?? 0) + 1);
      })
    }
    .width('100%')
    .padding({ left: Spacing.lg, right: Spacing.lg, top: 44, bottom: 10 })
    .backgroundColor(Color.Transparent)
    .zIndex(14)
  }

  /**
   * 官方槽位标题栏（§6.10 同机制，与进吧 ForumsTitleBar 同构）：「我的」标题 + 右上角深色切换 44 圆钮。
   * 圆钮玻璃换成 `ImmMaterial.seg(false)`（THIN 中性档），四项自绘玻璃（segGlass / border /
   * backgroundBlurStyle / segGlassShadow）按坑 24 全删；`Button` 显式 backgroundColor(Color.Transparent)
   * 清默认品牌蓝填充。几何（top 44 / bottom 10 / 左右 Spacing.lg / 圆钮 44 / margin left 12）逐项一致；
   * zIndex(14) 槽内无叠层序需求，去掉。
   */
  @Builder
  MineTitleBar() {
    Row() {
      Column({ space: 3 }) {
        Text('我的')
          .fontSize(fs(22, this.fontScale))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Button() {
        SymbolGlyph(this.isDark
          ? $r('sys.symbol.sun_max_fill')
          : $r('sys.symbol.moon_fill'))
          .fontColor([$r('sys.color.icon_primary')])
          .fontSize(fs(20, this.fontScale))
      }
      .width(44)
      .height(44)
      .backgroundColor(Color.Transparent)
      .systemMaterial(ImmMaterial.seg(false))
      .borderRadius(Radius.full)
      .margin({ left: 12 })
      .accessibilityText('切换深色模式')
      .onClick(() => {
        this.isDark = !this.isDark;
        // 用户主动切换：写 manual + 关跟随系统（避免 onConfigurationUpdate 在 setColorMode 异步窗口内
        // 拿到旧 Configuration 反向拉回档位）。与 PersonalizedPage 「深色模式」开关完全等价。
        UsageHabitsManager.getInstance().setFollowSystemDark(false);
        UsageHabitsManager.getInstance().setDarkModeManual(this.isDark);
        setDarkMode(this.isDark);
        AppStorage.setOrCreate<number>('darkTick', (AppStorage.get<number>('darkTick') ?? 0) + 1);
      })
    }
    .width('100%')
    .padding({ left: Spacing.lg, right: Spacing.lg, top: 44, bottom: 10 })
  }

  /** 顶部渐显覆盖比例（2026-09-13）：平板只覆盖顶部按钮与标题（98vp 折算），手机维持 15% */
  private topFadeStop(): number {
    if (!this.isWideFormDevice || this.fadeCoverVp <= 0) {
      return 0.15;
    }
    return Math.min(0.15, 98 / this.fadeCoverVp);
  }

  @Builder
  BottomFadeOverlay() {
    Stack()
      .height('100%')
      .width('100%')
      .linearGradient({
        direction: GradientDirection.Bottom,
        colors: [['#00FFFFFF', 0.0], ['#FFFFFFFF', this.topFadeStop()], ['#FFFFFFFF', 1.0]]
      })
      .blendMode(BlendMode.DST_IN, BlendApplyType.OFFSCREEN)
      .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  UserAvatar(size: number) {
    Stack() {
      Text(this.userName.length > 0 ? this.userName.charAt(0).toUpperCase() : '我')
        .fontSize(Math.max(16, Math.floor(size * 0.38)))
        .fontColor(Color.White)
        .width(size)
        .height(size)
        .textAlign(TextAlign.Center)
        .borderRadius(size / 2)
        .backgroundColor(Theme.brand())
      if (this.userAvatar.trim().length > 0) {
        Image(this.userAvatar.trim())
          .width(size)
          .height(size)
          .borderRadius(size / 2)
          .objectFit(ImageFit.Cover)
      }
    }
    .width(size)
    .height(size)
    .onClick(() => {
      this.openMyProfile();
    })
  }

  @Builder
  StatItem(value: string, label: string, onTap?: () => void) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(fs(18, this.fontScale))
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.textPrimary(this.isDark))
      Text(label)
        .fontSize(fs(11, this.fontScale))
        .fontColor(Theme.textSecondary(this.isDark))
    }
    .layoutWeight(1)
    .onClick(() => { onTap?.(); })
  }

  @Builder
  MineEntry(icon: Resource, title: string, subtitle: string, onTap: () => void) {
    Row({ space: Spacing.md }) {
      SymbolGlyph(icon)
        .fontSize(fs(20, this.fontScale))
        .fontColor([$r('sys.color.icon_primary')])
        .width(28)
      Column({ space: 4 }) {
        Text(title)
          .fontSize(fs(15, this.fontScale))
          .fontColor($r('sys.color.font_primary'))
        Text(subtitle)
          .fontSize(fs(11, this.fontScale))
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(fs(18, this.fontScale))
        .fontColor([$r('sys.color.icon_tertiary')])
    }
    .width('100%')
    .padding({ left: Spacing.lg, right: Spacing.lg, top: 13, bottom: 13 })
    .backgroundColor(Theme.bgCard(this.isDark))
    .borderRadius(Radius.lg)
    .onClick(() => onTap())
  }

  /** 页面内容层（原 build() 根 Stack 的 List，槽位 / 兜底两条路径共用） */
  @Builder
  MineContent() {
    List() {
        // 预留TopBar高度作为初始间距
        ListItem() {
          Column()
            .width('100%')
            .height(90)
        }
        .backgroundColor(Color.Transparent)

        ListItem() {
        Column({ space: Spacing.md }) {
          if (this.loggedIn) {
            Row({ space: Spacing.md }) {
              this.UserAvatar(62)
              Column({ space: 5 }) {
                Text(this.userName || '贴吧用户')
                  .fontSize(fs(19, this.fontScale))
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Theme.textPrimary(this.isDark))
                Text('已登录 · 个人主页')
                  .fontSize(fs(12, this.fontScale))
                  .fontColor(Theme.textSecondary(this.isDark))
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Text('›')
                .fontSize(fs(24, this.fontScale))
                .fontColor(Theme.textTertiary(this.isDark))
            }
            .width('100%')
            .onClick(() => { this.openMyProfile(); })
            .padding(Spacing.lg)
            .backgroundColor(Theme.bgCard(this.isDark))
            .borderRadius(Radius.lg)
          } else {
            Row() {
              Column({ space: 5 }) {
                Text('登录贴吧')
                  .fontSize(fs(18, this.fontScale))
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Theme.textPrimary(this.isDark))
                Text('登录后同步你的关注、收藏与历史')
                  .fontSize(fs(12, this.fontScale))
                  .fontColor(Theme.textSecondary(this.isDark))
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Button('登录')
                .fontSize(fs(13, this.fontScale))
                .fontColor($r('sys.color.font_on_primary'))
                .backgroundColor(Theme.manualGlass(this.isDark, true))
                .border({ width: 0.5, color: Theme.manualGlassBorder() })
                .shadow(Theme.glassShadowStyle()).backgroundEffect(ImmBlur.accent())
                .systemMaterial(ImmMaterial.accent(this.isDark))
                .borderRadius(Radius.full)
                .onClick(() => this.openLogin())
            }
            .width('100%')
            .padding(Spacing.lg)
            .backgroundColor(Theme.bgCard(this.isDark))
            .borderRadius(Radius.lg)
            .onClick(() => this.openLogin())
          }

          Row() {
            this.StatItem(`${this.follows.length}`, '关注的吧')
            Divider().vertical(true).height(28).color(Theme.divider(this.isDark))
            this.StatItem(this.followUserCountText(), '关注用户', () => this.openFollowList())
            Divider().vertical(true).height(28).color(Theme.divider(this.isDark))
            this.StatItem(this.statText(this.userStats.postCount), '我的贴子')
          }
          .width('100%')
          .padding({ top: Spacing.lg, bottom: Spacing.lg })
          .backgroundColor(Theme.bgCard(this.isDark))
          .borderRadius(Radius.lg)

          this.MineEntry($r('sys.symbol.doc'), '我的帖子', '查看发布过的主题', () => this.openPersonalContent('posts'))
          this.MineEntry($r('sys.symbol.star'), '我的收藏', '收藏的帖子与内容', () => {
            if (!this.loggedIn) {
              this.openLogin();
              return;
            }
            this.openFavorite();
          })
          this.MineEntry($r('sys.symbol.heart'), '我的点赞', '点赞过的内容', () => this.openPersonalContent('likes'))
          this.MineEntry($r('sys.symbol.clock'), '浏览历史', '最近看过的帖子和吧', () => this.openPersonalContent('history'))
          this.MineEntry($r('sys.symbol.plus'), '创建吧', '创建并管理贴吧', () => this.getUIContext().getPromptAction().showToast({ message: '创建吧需要贴吧官方接口支持' }))
          this.MineEntry($r('sys.symbol.gearshape'), '软件设置', '通知、缓存、隐私与关于', () => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/Settings' }).catch(() => {
            this.getUIContext().getPromptAction().showToast({ message: '页面打开失败，请稍后重试' });
          });
        })

          if (this.loggedIn) {
            Button('退出登录')
              .width('100%')
              .height(44)
              .fontSize(fs(14, this.fontScale))
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.danger())
              .backgroundColor(Theme.segGlass(this.isDark, false))
              .border({ width: 0.5, color: Theme.manualGlassBorder() })
              .backgroundBlurStyle(BlurStyle.Thin, { scale: 0.85 })
              .shadow(Theme.segGlassShadow(this.isDark, false))
              .borderRadius(Radius.lg)
              .onClick(() => {
                this.onLogout();
              })
          }
        }
        .width('100%')
        .padding({ left: Spacing.lg, right: Spacing.lg, top: Spacing.md, bottom: 150 })
      }
      }
    .width('100%')
    .layoutWeight(1)
    .padding({ bottom: 150 })
    .scrollBar(BarState.Off)
    .clip(false)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .overlay(this.BottomFadeOverlay())
    .blendMode(BlendMode.SRC_OVER, BlendApplyType.OFFSCREEN)
  }

  build() {
    if (MINE_OFFICIAL_TITLE_BAR) {
      // 官方槽位路径（§6.10）：标题行整行搬进 Navigation title 槽位吃真材质
      Navigation() {
        this.MineContent()
      }
      .title({ builder: this.MineTitleBar(), height: MINE_TITLE_BAR_HEIGHT },
        { barStyle: BarStyle.STACK, backgroundColor: Color.Transparent })
      .mode(NavigationMode.Stack)
      .hideTitleBar(false)
      .hideBackButton(true)
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .clip(false)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    } else {
      // 兜底路径：页面主体悬浮自绘玻璃（改造前原样）
      Stack({ alignContent: Alignment.TopStart }) {
        this.MineContent()

        // 悬浮TopBar层（内容可穿过TopBar区域）
        this.TopBar()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
    }
  }
}
