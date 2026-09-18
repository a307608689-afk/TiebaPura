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
import { deviceInfo } from '@kit.BasicServicesKit';
import { display, LengthMetrics } from '@kit.ArkUI';
import { AuthManager } from '../service/AuthManager';
import { TiebaService } from '../service/TiebaService';
import { AutoSignManager, AutoSignProgress, AutoSignStage, AutoSignResult } from '../service/AutoSignManager';
import { AutoSignNotifier } from '../service/AutoSignNotifier';
import { CacheManager } from '../cache/CacheManager';
import { CACHE_KEY, CACHE_TTL } from '../common/Constants';
import { FollowItem, PersonalContentItem } from '../model/DataModel';
import { Theme, Spacing, Radius, isDarkMode, setDarkMode, fs, ImmMaterial, isWideBarDevice, isLargeFoldDevice, overlayCardWidth, isWideFormDevice as detectWideFormDevice, readColumnMode, overrideColumns, isLargeScreenForm } from '../common/Theme';
import { Haptic } from '../common/Haptic';
import { UsageHabitsManager } from '../service/UsageHabitsManager';
import { compareByName } from '../common/Pinyin';
import { LoadingView, EmptyView, ErrorView } from '../components/CommonComponents';

/**
 * 进吧主 Tab 页（自洽组件，仿 FavoriteTab / MessagesTab 范式，从 Index.ets 内联 Builder 抽出）：
 * - 数据自含：关注吧列表 follows / forumState / 置顶 pinnedForums / 排序 forumSortMode /
 *   足迹 recentForums / 关注吧长按菜单与排序、足迹删除弹窗 / 吧头像失败集 全部内部自管，每次挂载即拉取。
 *   足迹本地缓存直出（挂载即渲染，不等关注列表网络），并随每次挂载/从其它页面返回（forumsRefreshRequest）自动刷新。
 * - 与宿主（Index.ets）通信：
 *     tabLoginRefresh = 登录/登出/换号通知（宿主登录键变化时递增）→ 重同步登录态并按需重载
 *     darkTick        = 深色模式切换通知 → 重读 isDarkMode()
 *     onFollowsSync   = 关注吧列表变化（加载成功/取关）回传宿主，保证「我的」页关注吧数与宿主快照一致
 * - 文件内自带 TopBar（标题「进吧」+ 一键签到 + 排序 ⇅ + 深色切换）与底部渐隐，沿用本工程各路由页独立 TopBar 惯例。
 * - 一键签到（贴吧 Lite 同款）：顶部一键签到钮 → 拉全量关注吧 →（可选）官方一键签到批量处理 →
 *   未完成的吧逐吧签到兜底；慢速模式/官方一键签到两个开关见「软件设置 → 一键签到」。
 *   浮层支持「后台签到」：收起浮层继续签到（长时任务保活，退后台不冻结），完成后在系统通知栏推送结果。
 * - 顶部三个按钮（一键签到 / 排序 ⇅ / 深色切换）已搬进官方 title 槽位，见 FORUMS_OFFICIAL_TITLE_BAR。
 */

/**
 * 顶部官方标题栏开关（2026-09-10，与 HomeTab 同机制）：
 * true  = 「进吧 + 一键签到 / 排序 / 深色切换」整行搬进 Navigation 的 title 槽位，玻璃交给官方沉浸材质 systemMaterial
 *         （官方口径：systemMaterial 生效区域仅 Navigation/NavDestination 标题栏、横向 Tabs(barPosition=End) 底部 TabBar；
 *          页面 body 内自绘浮层必判 Material inactive: out of scope）；
 * false = 回退改造前的页面主体悬浮 TopBar（manualGlass + backgroundBlurStyle 真磨砂兜底）。
 */
const FORUMS_OFFICIAL_TITLE_BAR: boolean = true;
/**
 * 官方标题栏高度：与改造前悬浮 TopBar 几何逐项一致 —— 44(状态栏让位) + 44(按钮行高) + 10(底部呼吸) = 98。
 * 注意 List 顶部让位占位仍是改造前既有的 90，一行未动。
 */
const FORUMS_TITLE_BAR_HEIGHT: number = 98;

enum LoadState {
  Loading,
  Success,
  Empty,
  Error,
}

enum ForumSortMode {
  NameAsc = 0,
  NameDesc = 1,
  TimeAsc = 2,
  TimeDesc = 3,
}

interface RecentForumItem {
  name: string;
  lastVisit: string;
  avatar?: string;
  forumId?: string;
}

/**
 * 一键签到弹窗（系统 CustomDialog + API 26 沉浸光感）。
 *
 * 为什么从「自绘浮层」改成系统弹窗：官方沉浸光感的 A 档「弹窗类」只覆盖系统 Dialog /
 * 弹窗类接口（CustomDialogControllerOptions、AlertDialogParam、ActionSheetOptions、
 * SheetOptions、PromptAction 等）；页面 body 内的自绘 Stack 浮层不在生效范围内，
 * 挂 systemMaterial 必然判 `Material inactive: out of scope`（工程 §8 已 probe 证实）。
 *
 * 几何与内容对齐（与改造前的自绘浮层逐项一致）：
 * - 宽度 calc(100% - 48vp)、圆角 32vp、内边距 Spacing.lg、遮罩 #06000000、底部锚点（底距 110）；
 * - 文案 / 字号 / 进度条 / 按钮尺寸 44 高 + Radius.full 全部原样保留。
 *
 * 玻璃层由宿主的 options.systemMaterial 承担（材质会接管容器的背景色 / 背景模糊 / 边框 / 阴影），
 * 因此卡内不再自绘 backgroundColor / backgroundBlurStyle / border / shadow 这四项。
 */
@CustomDialog
struct SignAllDialog {
  /** 系统弹窗必须声明 CustomDialogController 类型属性（ArkTS 编译期强校验） */
  controller?: CustomDialogController;
  @Link isDark: boolean;
  @Link fontScale: number;
  /** 是否进行中（false 表示展示结果） */
  @Link running: boolean;
  @Link total: number;
  @Link finished: number;
  @Link signed: number;
  @Link failed: number;
  @Link forumName: string;
  @Link note: string;
  /** 结果态文案 */
  @Link message: string;
  /** 「后台签到」：收起弹窗继续签到（长时任务保活，完成后通知栏提醒） */
  onBackground: () => void = () => {};
  /** 「停止签到」/「知道了」：进行中=中断任务，结束=关闭弹窗 */
  onDismiss: () => void = () => {};

  /** 进度百分比（0~100，总数未知时为 0） */
  private percent(): number {
    if (this.total <= 0) {
      return 0;
    }
    const value: number = Math.round(this.finished * 100 / this.total);
    return Math.max(0, Math.min(100, value));
  }

  /** 进行中的主文案：官方批量阶段用阶段说明，逐吧阶段用「正在签到：吧名（慢速模式）」 */
  private signingLabel(): string {
    if (this.note.length > 0) {
      return this.note;
    }
    if (this.forumName.length === 0) {
      return '准备中…';
    }
    const slowTag: string = AutoSignManager.getInstance().isSlowMode() ? '（慢速模式）' : '';
    return `正在签到：${this.forumName}${slowTag}`;
  }

  build() {
    Column({ space: Spacing.md }) {
      Text('一键签到')
        .fontSize(fs(17, this.fontScale))
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.textPrimary(this.isDark))
        .textAlign(TextAlign.Center)
        .width('100%')

      if (this.running) {
        Column({ space: Spacing.sm }) {
          // 进度条：细轨道 + 品牌色填充
          Row() {
            Row()
              .width(`${this.percent()}%`)
              .height(6)
              .backgroundColor(Theme.brand())
              .borderRadius(3)
          }
          .width('100%')
          .height(6)
          .backgroundColor(Theme.bgCard(this.isDark))
          .borderRadius(3)

          Row({ space: 8 }) {
            LoadingProgress()
              .width(16)
              .height(16)
              .color(Theme.brand())
            Text(this.signingLabel())
              .fontSize(fs(13, this.fontScale))
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.textSecondary(this.isDark))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .width('100%')

          Text(this.total > 0
            ? `进度 ${this.finished}/${this.total} · 成功 ${this.signed} · 失败 ${this.failed}`
            : '正在统计需签到的吧…')
            .fontSize(fs(12, this.fontScale))
            .fontColor(Theme.textSecondary(this.isDark))
            .width('100%')
        }
        .width('100%')

        Row({ space: Spacing.sm }) {
          // 后台签到：收起弹窗继续签到，完成后系统通知栏提醒
          Button() {
            Text('后台签到')
              .fontSize(fs(15, this.fontScale))
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
          }
          .layoutWeight(1)
          .height(44)
          .systemMaterial(ImmMaterial.accent(this.isDark))
          .backgroundColor('#CC3173FF')
          .borderRadius(Radius.full)
          // 主按钮品牌色浮起阴影：与次按钮同向轻投影，保证弹窗内按钮层次一致
          .shadow({ radius: 14, color: this.isDark ? '#663173FF' : '#4D3173FF', offsetY: 4 })
          .accessibilityText('后台签到，完成后通知')
          .onClick(() => { this.onBackground(); })

          Button() {
            Text('停止签到')
              .fontSize(fs(15, this.fontScale))
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.textPrimary(this.isDark))
          }
          .layoutWeight(1)
          .height(44)
          .systemMaterial(ImmMaterial.cardAction())
          .backgroundColor(this.isDark ? '#B31B1E24' : '#B3FFFFFF')
          .borderRadius(Radius.full)
          // 次按钮中性轻投影：抬起于玻璃卡之上，避免与卡片融为一体
          .shadow({ radius: 10, color: this.isDark ? '#4D000000' : '#1F101824', offsetY: 3 })
          .onClick(() => { this.onDismiss(); })
        }
        .width('100%')

        Text('后台签到可收起浮层继续签到，完成后在通知栏提醒')
          .fontSize(fs(11, this.fontScale))
          .fontColor(Theme.textTertiary(this.isDark))
          .textAlign(TextAlign.Center)
          .width('100%')
      } else {
        Text(this.message)
          .fontSize(fs(14, this.fontScale))
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.textSecondary(this.isDark))
          .lineHeight(fs(20, this.fontScale))
          .textAlign(TextAlign.Center)
          .width('100%')

        Button() {
          Text('知道了')
            .fontSize(fs(15, this.fontScale))
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.textPrimary(this.isDark))
        }
        .width('100%')
        .height(44)
        .systemMaterial(ImmMaterial.cardAction())
        .backgroundColor(this.isDark ? '#B31B1E24' : '#B3FFFFFF')
        .borderRadius(Radius.full)
        // 结果态「知道了」：同次按钮中性轻投影
        .shadow({ radius: 10, color: this.isDark ? '#4D000000' : '#1F101824', offsetY: 3 })
        .onClick(() => { this.onDismiss(); })
      }
    }
    .width('100%')
    .padding(Spacing.lg)
  }
}

/**
 * 关注吧长按菜单弹窗（系统 CustomDialog + API 26 沉浸光感）。
 *
 * 与一键签到弹窗同源改造：原「页面 body 顶层 Stack 自绘浮层」换成系统弹窗，
 * 玻璃层交给 options.systemMaterial，卡内不再自绘 backgroundColor / border /
 * backgroundBlurStyle / shadow 四项（材质会接管它们）。
 *
 * 几何与内容对齐（与改造前的自绘浮层逐项一致）：
 * - 宽度 calc(100% - 48vp) → options.width 数值 vp；圆角 32vp；遮罩 #06000000；
 *   底部锚点（底距 110）；标题 / 菜单行 / 分隔线 / 取消按钮 尺寸与字号全部原样保留。
 */
@CustomDialog
struct ForumMenuDialogCard {
  /** 系统弹窗必须声明 CustomDialogController 类型属性（ArkTS 编译期强校验） */
  controller?: CustomDialogController;
  @Link isDark: boolean;
  @Link fontScale: number;
  /** 目标吧名（宿主在打开前写入快照） */
  @Link forumName: string;
  /** 打开那一刻是否已置顶（决定菜单文案「置顶 / 取消置顶」） */
  @Link pinned: boolean;
  /** 置顶 / 取消置顶 */
  onTogglePin: () => void = () => {};
  /** 取关 */
  onUnfollow: () => void = () => {};
  /** 取消 / 点遮罩 / 返回键 */
  onDismiss: () => void = () => {};

  build() {
    Column({ space: 0 }) {
      Row({ space: 8 }) {
        Text(this.forumName)
          .fontSize(fs(17, this.fontScale))
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.textPrimary(this.isDark))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (this.pinned) {
          Text('已置顶')
            .fontSize(fs(11, this.fontScale))
            .fontColor(Theme.brand())
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .borderRadius(Radius.full)
            .backgroundColor(Theme.brandBg(this.isDark))
        }
      }
      .width('100%')
      .padding({ left: Spacing.lg, right: Spacing.lg, top: Spacing.lg, bottom: Spacing.sm })

      Row({ space: Spacing.md }) {
        SymbolGlyph($r('sys.symbol.pin_fill'))
          .fontSize(fs(19, this.fontScale))
          .fontColor([Theme.textPrimary(this.isDark)])
        Text(this.pinned ? '取消置顶' : '置顶')
          .fontSize(fs(15, this.fontScale))
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.textPrimary(this.isDark))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: Spacing.lg, right: Spacing.lg, top: 12, bottom: 12 })
      .borderRadius(Radius.md)
      .onClick(() => { this.onTogglePin(); })

      Column()
        .width('calc(100% - 32vp)')
        .height(0.5)
        .backgroundColor(this.isDark ? '#26FFFFFF' : '#12000000')

      Row({ space: Spacing.md }) {
        SymbolGlyph($r('sys.symbol.heart'))
          .fontSize(fs(19, this.fontScale))
          .fontColor([Theme.danger()])
        Text('取关')
          .fontSize(fs(15, this.fontScale))
          .fontColor(Theme.danger())
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: Spacing.lg, right: Spacing.lg, top: 12, bottom: 12 })
      .borderRadius(Radius.md)
      .accessibilityText('取关')
      .onClick(() => { this.onUnfollow(); })

      Button() {
        Text('取消')
          .fontSize(fs(15, this.fontScale))
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.textPrimary(this.isDark))
      }
      .width('100%')
      .height(44)
      .margin({ top: Spacing.sm })
      // 与一键签到弹窗的次按钮同源：材质 + 半透明底 + 中性轻投影（底色不透明会盖掉材质）
      .systemMaterial(ImmMaterial.cardAction())
      .backgroundColor(this.isDark ? '#B31B1E24' : '#B3FFFFFF')
      .borderRadius(Radius.full)
      .shadow({ radius: 10, color: this.isDark ? '#4D000000' : '#1F101824', offsetY: 3 })
      .onClick(() => { this.onDismiss(); })
    }
    .width('100%')
    .padding({ left: Spacing.lg, right: Spacing.lg, bottom: Spacing.lg })
  }
}

@Component
export struct ForumsTab {
  onFollowsSync: (list: FollowItem[]) => void = (list: FollowItem[]) => {};
  /**
   * 顶部渐显带收窄（2026-09-13 用户反馈）：平板竖屏下原 15% 渐显覆盖到第一个卡片中部，
   * 要求「只覆盖顶部按钮与标题」→ 平板档覆盖高度 = 顶栏 98vp，手机维持原比例。
   */
  private readonly isWideFormDevice: boolean = detectWideFormDevice();
  @State loggedIn: boolean = false;
  @State forumState: LoadState = LoadState.Loading;
  @State follows: FollowItem[] = [];
  @State recentForums: RecentForumItem[] = [];
  @State failedAvatarNames: string[] = [];
  @State failedFollowAvatars: string[] = [];
  @State forumSortMode: ForumSortMode = ForumSortMode.TimeDesc;
  @State showForumSortDialog: boolean = false;
  /**
   * 关注吧长按菜单显隐（系统 CustomDialog + API 26 沉浸光感）。
   * 宿主已由「页面 body 顶层 Stack 自绘浮层」换成系统 CustomDialog —— 官方沉浸光感 A 档
   * 「弹窗类」只覆盖系统 Dialog / 弹窗类接口，自绘浮层挂 systemMaterial 必然 out of scope。
   * 保留单一布尔状态，真正 open/close 由 @Watch 驱动，既有 `this.showForumMenu = x` 调用点零改动。
   */
  @State @Watch('onShowForumMenuChanged') showForumMenu: boolean = false;
  @State forumMenuTarget: FollowItem | null = null;
  /** 弹窗展示快照：吧名（FollowItem | null 不能直接 @Link 进 @CustomDialog） */
  @State forumMenuName: string = '';
  /** 弹窗展示快照：打开那一刻是否已置顶（决定菜单文案） */
  @State forumMenuPinned: boolean = false;
  @State pinnedForums: string[] = [];
  @State forumBusy: boolean = false;
  @State showRecentDelete: boolean = false;
  @State recentDeleteName: string = '';
  /**
   * 一键签到弹窗显隐（true=已打开；stage：AutoSignStage；running=false 表示展示结果）。
   * 宿主已由「页面 body 内自绘 Stack 浮层」换成系统 CustomDialog —— 官方沉浸光感 A 档
   * 「弹窗类」只覆盖系统 Dialog / 弹窗类接口，自绘浮层挂 systemMaterial 必然 out of scope，
   * 换成系统弹窗材质才生效。这里保留单一布尔状态，真正 open/close 由 @Watch 驱动，
   * 既有 `this.showSignAll = x` 调用点无需改动。
   */
  @State @Watch('onShowSignAllChanged') showSignAll: boolean = false;
  @State signAllRunning: boolean = false;
  @State signAllStage: number = AutoSignStage.Preparing;
  @State signAllTotal: number = 0;
  @State signAllFinished: number = 0;
  @State signAllSigned: number = 0;
  @State signAllFailed: number = 0;
  @State signAllForumName: string = '';
  @State signAllNote: string = '';
  @State signAllMessage: string = '';
  /** 是否已转入「后台签到」：收起浮层继续签到，完成后发系统通知 */
  private signAllBackground: boolean = false;
  /** 完成通知标题（正常为「一键签到完成」，整体失败为「一键签到失败」） */
  private signAllNotifyTitle: string = '一键签到完成';
  @State isDark: boolean = isDarkMode();
  @State isWideScreen: boolean = false;
  // ===== 平板适配（docs/TiebaPura平板适配.md §4.1，2026-09-14 开工：竖 3 / 横 4，手机 2 列不变）=====
  /** 横竖屏：宽高比（不用宽度阈值，13 寸平板竖屏也有 ~960vp） */
  @State isLandscape: boolean = false;
  /** 窗口宽（vp）：列数判定依赖，aboutToAppear 首帧 + 根容器 onAreaChange 兜底 */
  @State pageWidth: number = 0;
  /** 窗口高（vp）：与 pageWidth 配对判横竖屏 */
  @State pageHeight: number = 0;
  /** 关注吧列表 Scroller：「列数调整」切档后强制回到列表顶部用（2026-09-18） */
  private forumsScroller: Scroller = new Scroller();
  @StorageLink('fontScale') fontScale: number = 1.0;
  // 字号全局变更广播（2026-09-13）：@Watch 回写 fontScale 强制本页依赖刷新（离屏缓存不重绘兜底）
  @StorageLink('fontTick') @Watch('onFontTick') fontTick: number = 0;
  // 「列数调整」档位广播（2026-09-18，个性化 → 列数调整）：@Watch 回写本地档位 → 列数函数按新档返回并强制回到列表顶部
  // （离屏期间 @StorageLink 同步不重绘，故用 tick + 本地 @State 兜底，同 fontTick 范式）
  @StorageLink('columnModeTick') @Watch('onColumnModeTick') columnModeTick: number = 0;
  @State columnMode: number = 0;
  @StorageLink('darkTick') @Watch('onDarkTick') darkTick: number = 0;
  @StorageLink('tabLoginRefresh') @Watch('onLoginTick') tabLoginRefresh: number = 0;
  @StorageLink('forumsRefreshRequest') @Watch('onForumsRefresh') forumsRefreshRequest: number = 0;

  /**
   * 一键签到弹窗控制器（系统 CustomDialog + API 26 沉浸光感）。
   *
   * 几何对齐改造前的自绘浮层：宽度 calc(100% - 48vp)、圆角 32vp（恰为 customStyle=false
   * 的默认圆角）、底部锚点（Bottom + dy -110，对应原 margin bottom 110）、遮罩 #06000000；
   * 卡内文案/字号/按钮尺寸与圆角全部原样保留。
   *
   * 玻璃层交给 options.systemMaterial（ImmMaterial.dialog()）：官方明确 systemMaterial
   * 会接管容器的 backgroundColor / backgroundBlurStyle / backgroundEffect / borderColor /
   * borderWidth / shadow，故卡内不再自绘这五项（也与项目「不叠双模糊、不叠双影」的约定一致）。
   *
   * ⚠️ customStyle 必须为 false —— 官方明确 customStyle=true 时弹窗背景强制透明、圆角归 0
   * 且沉浸光感不生效；此处显式写出以自证。
   */
  private signAllDialogController: CustomDialogController = new CustomDialogController({
    builder: SignAllDialog({
      isDark: $isDark,
      fontScale: $fontScale,
      running: $signAllRunning,
      total: $signAllTotal,
      finished: $signAllFinished,
      signed: $signAllSigned,
      failed: $signAllFailed,
      forumName: $signAllForumName,
      note: $signAllNote,
      message: $signAllMessage,
      onBackground: () => { this.handleSignAllBackground(); },
      onDismiss: () => { this.closeSignAll(); }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Bottom,
    offset: { dx: 0, dy: -110 },
    maskColor: '#06000000',
    cornerRadius: 32,
    // 弹窗宽度：Dimension 不接受 'calc(100% - 48vp)' 字符串，故按窗口宽换算成数值 vp
    width: this.dialogCardWidth(),
    customStyle: false,
    systemMaterial: ImmMaterial.dialog(),
    openAnimation: { duration: 220, curve: Curve.EaseOut },
    closeAnimation: { duration: 200, curve: Curve.EaseInOut },
    // 点遮罩/返回键统一交给 closeSignAll：进行中=中断任务且不关闭；结束后=关闭
    onWillDismiss: () => { this.closeSignAll(); }
  });

  /**
   * 弹窗卡片宽度（vp）= 屏幕宽 - 48vp，等价于改造前自绘浮层的 `calc(100% - 48vp)`。
   * ArkTS 的 Dimension 只接受数值 / 百分比 / 资源，不接受 calc 字符串，故换算成数值。
   * 取屏幕宽（display）而非窗口宽：弹窗容器宽度本身还受系统上限（默认 400vp）约束，
   * 分屏 / 折叠态由该上限兜底。
   */
  private dialogCardWidth(): number {
    const info: display.Display = display.getDefaultDisplaySync();
    const widthVp: number = info.width / info.densityPixels;
    // §4.1 顺带（2026-09-14）：平板封顶 400（系统弹窗默认宽度上限），与 ThreadList §4.8 T-H /
    // 收藏页同款；手机档 312 < 400 逐像素不变
    return Math.max(200, Math.min(400, widthVp - 48));
  }

  /** showSignAll 变化即驱动系统弹窗 open/close（保留既有 `this.showSignAll = x` 调用点） */
  onShowSignAllChanged(): void {
    if (this.showSignAll) {
      this.signAllDialogController.open();
    } else {
      this.signAllDialogController.close();
    }
  }

  /**
   * 关注吧长按菜单控制器（系统 CustomDialog + API 26 沉浸光感）。
   * 几何与一键签到弹窗同源：宽度 dialogCardWidth()、圆角 32vp、底部锚点 dy -110、遮罩 #06000000。
   * 玻璃层交给 options.systemMaterial（ImmMaterial.dialog()），卡内不再自绘那五项。
   * ⚠️ customStyle 必须为 false —— customStyle=true 时弹窗背景强制透明、圆角归 0 且材质不生效。
   */
  private forumMenuController: CustomDialogController = new CustomDialogController({
    builder: ForumMenuDialogCard({
      isDark: $isDark,
      fontScale: $fontScale,
      forumName: $forumMenuName,
      pinned: $forumMenuPinned,
      onTogglePin: () => { this.togglePinForum(); },
      onUnfollow: () => { this.unfollowForum(); },
      onDismiss: () => { this.closeForumMenu(); }
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
    // 点遮罩/返回键统一交给 closeForumMenu（与自绘浮层时期语义一致）
    onWillDismiss: () => { this.closeForumMenu(); }
  });

  /** showForumMenu 变化即驱动系统弹窗 open/close（保留既有 `this.showForumMenu = x` 调用点） */
  onShowForumMenuChanged(): void {
    if (this.showForumMenu) {
      this.forumMenuController.open();
    } else {
      this.forumMenuController.close();
    }
  }

  aboutToAppear(): void {
    this.isDark = isDarkMode();
    this.loggedIn = AuthManager.getInstance().isLogin();
    // 顶部渐显带覆盖基准（平板收窄用）：取屏幕长边（竖屏视口高），窗口未 attach 时忽略
    try {
      const d: display.Display = display.getDefaultDisplaySync();
      // §4.1：列数首帧初值（防横屏先 3 列再跳 4 列）
      this.pageWidth = d.width / d.densityPixels;
      this.pageHeight = d.height / d.densityPixels;
      this.isLandscape = d.width > d.height;
    } catch (e) {
      // 忽略：窗口未 attach，pageWidth 保持 0 → 列数回落手机档（安全方向）
    }
    // 「列数调整」档位初值（2026-09-18）：冷启动首帧即按已选档渲染
    // （UsageHabitsManager.init 的 columnModeTick 可能早于本页构造，@Watch 不会补触发，故此处直读）
    this.columnMode = readColumnMode();
    // 一键签到开关（慢速模式 / 官方一键签到）恢复：未初始化过才真正读缓存
    AutoSignManager.getInstance().init(this.getUIContext().getHostContext() as common.UIAbilityContext);
    if (this.loggedIn) {
      // 足迹先行：切回本页立即按本地缓存渲染（与关注列表网络请求解耦），
      // 避免「先空白、等关注列表网络返回后足迹才突然闪现」
      this.loadRecentForums();
      this.loadForums();
    } else {
      this.forumState = LoadState.Empty;
    }
  }

  /**
   * 「列数调整」档位变化（个性化页写入 → `columnModeTick` 广播）：
   * 回写本地档位（列数函数随新档返回）→ 强制回到列表顶部。
   * 默认档（0）与原自动适配逐像素一致，仅「用户显式选择」后才改变列数。
   */
  private onColumnModeTick(): void {
    this.columnMode = readColumnMode();
    try {
      this.forumsScroller.scrollTo({ xOffset: 0, yOffset: 0 });
    } catch (e) {
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

  /** 从其它页面返回本页（Index.onPageShow 递增 forumsRefreshRequest）：静默刷新足迹（本地缓存直出，不发网络） */
  onForumsRefresh(): void {
    if (this.loggedIn) {
      this.loadRecentForums();
    }
  }

  /** 登录/登出/换号通知（Index.refreshLoginState 登录键变化时递增）：重同步并重载账号数据 */
  onLoginTick(): void {
    this.loggedIn = AuthManager.getInstance().isLogin();
    if (!this.loggedIn) {
      this.follows = [];
      this.recentForums = [];
      this.forumState = LoadState.Empty;
      this.showForumMenu = false;
      this.showForumSortDialog = false;
      this.showRecentDelete = false;
      return;
    }
    this.loadRecentForums();
    this.loadForums();
  }

  /** 关注吧列表变化回传宿主（维护「我的」页统计与宿主快照） */
  private syncFollows(): void {
    this.onFollowsSync(this.follows.slice());
  }

  async loadForums(): Promise<void> {
    if (!this.loggedIn) {
      this.forumState = LoadState.Empty;
      return;
    }
    this.forumState = LoadState.Loading;
    this.loadForumPrefs();
    try {
      const cached = await CacheManager.getInstance().getWithTtl<FollowItem[]>(CACHE_KEY.FOLLOW_LIST);
      if (cached && cached.length > 0) {
        this.follows = cached;
        this.syncFollows();
        this.forumState = LoadState.Success;
      }
      const result = await TiebaService.getInstance().fetchFollowList(1);
      this.follows = result.list;
      this.syncFollows();
      this.forumState = result.list.length > 0 ? LoadState.Success : LoadState.Empty;
      if (result.list.length > 0) {
        await CacheManager.getInstance().putWithTtl(CACHE_KEY.FOLLOW_LIST, result.list, CACHE_TTL.FOLLOW_LIST);
      }
      // 关注列表已就绪：补齐足迹头像（先查关注吧，仍缺的再按吧名拉取并回写历史缓存）
      this.enrichRecentAvatars();
    } catch (e) {
      if (this.follows.length === 0) {
        this.forumState = LoadState.Error;
      }
    }
  }

  // ===== 进吧：关注吧排序 / 置顶 / 长按菜单 / 足迹删除 =====

  private toast(msg: string): void {
    this.getUIContext().getPromptAction().showToast({ message: msg });
  }

  private accountId(): string {
    return AuthManager.getInstance().getUser()?.userId ?? '';
  }

  /** 加载置顶关注吧列表 + 排序偏好（异步，不阻塞首屏） */
  private async loadForumPrefs(): Promise<void> {
    const accountId: string = this.accountId();
    if (accountId.length === 0) {
      return;
    }
    try {
      const raw = await CacheManager.getInstance().get(`${CACHE_KEY.PIN_FOLLOW_FORUM}_${accountId}`);
      if (raw) {
        const arr = JSON.parse(raw) as string[];
        if (Array.isArray(arr)) {
          this.pinnedForums = arr;
        }
      }
    } catch (e) {
    }
    try {
      const raw = await CacheManager.getInstance().get(`${CACHE_KEY.FOLLOW_FORUM_SORT}_${accountId}`);
      if (raw) {
        const n: number = parseInt(raw, 10);
        if (n >= 0 && n <= 3) {
          this.forumSortMode = n as ForumSortMode;
        }
      }
    } catch (e) {
    }
  }

  private saveForumSort(): void {
    const accountId: string = this.accountId();
    if (accountId.length === 0) {
      return;
    }
    CacheManager.getInstance().put(`${CACHE_KEY.FOLLOW_FORUM_SORT}_${accountId}`, String(this.forumSortMode)).catch(() => {
    });
  }

  private savePinnedForums(): void {
    const accountId: string = this.accountId();
    if (accountId.length === 0) {
      return;
    }
    CacheManager.getInstance().put(`${CACHE_KEY.PIN_FOLLOW_FORUM}_${accountId}`, JSON.stringify(this.pinnedForums)).catch(() => {
    });
  }

  private isForumPinned(name: string): boolean {
    return this.pinnedForums.indexOf(name) >= 0;
  }

  /** 渲染用关注吧列表：置顶恒顶（按置顶先后），其余按排序模式 */
  private sortedFollows(): FollowItem[] {
    const list: FollowItem[] = this.follows.slice();
    const pinned: FollowItem[] = [];
    const rest: FollowItem[] = [];
    // 置顶项按置顶先后排列（pinnedForums 数组序：最新置顶在最前）
    for (const n of this.pinnedForums) {
      const f = list.find((item: FollowItem) => item.forumName === n);
      if (f) {
        pinned.push(f);
      }
    }
    for (const f of list) {
      if (!this.isForumPinned(f.forumName)) {
        rest.push(f);
      }
    }
    if (this.forumSortMode === ForumSortMode.NameAsc || this.forumSortMode === ForumSortMode.NameDesc) {
      const desc: boolean = this.forumSortMode === ForumSortMode.NameDesc;
      rest.sort((a: FollowItem, b: FollowItem): number => compareByName(a.forumName, b.forumName, desc));
    } else if (this.forumSortMode === ForumSortMode.TimeAsc) {
      // 关注吧无关注时间字段：接口序即最新关注在前，反转=最早关注在前
      rest.reverse();
    }
    return pinned.concat(rest);
  }

  private forumSortLabel(mode: ForumSortMode): string {
    switch (mode) {
      case ForumSortMode.NameAsc:
        return '名称正序';
      case ForumSortMode.NameDesc:
        return '名称倒序';
      case ForumSortMode.TimeAsc:
        return '最早关注';
      default:
        return '最新关注';
    }
  }

  private applyForumSort(mode: ForumSortMode): void {
    if (this.forumSortMode === mode) {
      this.showForumSortDialog = false;
      return;
    }
    this.forumSortMode = mode;
    this.saveForumSort();
    this.showForumSortDialog = false;
    Haptic.light();
    this.toast(`已切换为${this.forumSortLabel(mode)}`);
  }

  private closeForumMenu(): void {
    this.showForumMenu = false;
    this.forumMenuTarget = null;
  }

  /** 置顶/取消置顶（本地持久化，不涉及网络） */
  private togglePinForum(): void {
    const target: FollowItem | null = this.forumMenuTarget;
    if (!target) {
      return;
    }
    const name: string = target.forumName;
    if (this.isForumPinned(name)) {
      this.pinnedForums = this.pinnedForums.filter((n: string) => n !== name);
    } else {
      this.pinnedForums = [name, ...this.pinnedForums];
    }
    this.savePinnedForums();
    Haptic.light();
    const pinned: boolean = this.isForumPinned(name);
    this.toast(pinned ? `已置顶「${name}」，排在列表最前` : `已取消置顶「${name}」`);
    this.closeForumMenu();
  }

  /** 取关：乐观移除 + 失败回滚（同 ThreadDetail 点赞范式） */
  private async unfollowForum(): Promise<void> {
    const target: FollowItem | null = this.forumMenuTarget;
    if (!target || this.forumBusy) {
      return;
    }
    this.forumBusy = true;
    const prev: FollowItem[] = this.follows.slice();
    this.follows = this.follows.filter((f: FollowItem) => f.forumName !== target.forumName);
    this.syncFollows();
    this.closeForumMenu();
    try {
      const ok: boolean = await TiebaService.getInstance().toggleFollow(target.forumName, false, target.forumId ?? '');
      if (ok) {
        this.pinnedForums = this.pinnedForums.filter((n: string) => n !== target.forumName);
        this.savePinnedForums();
        await CacheManager.getInstance().putWithTtl(CACHE_KEY.FOLLOW_LIST, this.follows, CACHE_TTL.FOLLOW_LIST);
        Haptic.light();
        this.toast(`已取关「${target.forumName}」`);
      } else {
        this.follows = prev;
        this.syncFollows();
        this.toast('取关失败，请稍后重试');
      }
    } catch (e) {
      this.follows = prev;
      this.syncFollows();
      this.toast('取关失败，请稍后重试');
    } finally {
      this.forumBusy = false;
    }
  }

  /** 删除单个吧的足迹：仅过滤 PERSONAL_HISTORY 缓存，不影响关注/收藏 */
  private async deleteRecentForum(): Promise<void> {
    const name: string = this.recentDeleteName;
    if (name.length === 0) {
      return;
    }
    const accountId: string = this.accountId();
    if (accountId.length > 0) {
      try {
        const cacheKey: string = `${CACHE_KEY.PERSONAL_HISTORY}_${accountId}`;
        const raw = await CacheManager.getInstance().get(cacheKey);
        if (raw) {
          const items = JSON.parse(raw) as PersonalContentItem[];
          if (Array.isArray(items)) {
            const filtered = items.filter((i: PersonalContentItem) => (i.forumName ?? '') !== name);
            await CacheManager.getInstance().put(cacheKey, JSON.stringify(filtered));
          }
        }
      } catch (e) {
        // 缓存清理失败不阻断 UI
      }
    }
    this.recentForums = this.recentForums.filter((r: RecentForumItem) => r.name !== name);
    this.recentDeleteName = '';
    this.showRecentDelete = false;
    Haptic.light();
    this.toast(`已删除「${name}」的足迹`);
  }

  private async loadRecentForums(): Promise<void> {
    if (!this.loggedIn) {
      return;
    }
    try {
      const accountId: string = AuthManager.getInstance().getUser()?.userId ?? '';
      if (accountId.length === 0) {
        return;
      }
      const raw = await CacheManager.getInstance().get(`${CACHE_KEY.PERSONAL_HISTORY}_${accountId}`);
      if (!raw) {
        return;
      }
      const items: PersonalContentItem[] = JSON.parse(raw) as PersonalContentItem[];
      if (!items || items.length === 0) {
        return;
      }
      const seen = new Set<string>();
      const recents: RecentForumItem[] = [];
      for (const item of items) {
        const fname = item.forumName ?? '';
        if (fname.length === 0 || seen.has(fname)) {
          continue;
        }
        seen.add(fname);
        // Priority 1: use avatar saved with history item
        let avatar: string = (item.forumAvatar ?? '').length > 0 && this.isValidAvatarUrl(item.forumAvatar!)
          ? item.forumAvatar!
          : '';
        // Priority 2: look up from follows list
        if (avatar.length === 0) {
          avatar = this.findFollowAvatar(fname);
        }
        recents.push({
          name: fname,
          lastVisit: this.formatRecentTime(item.createTime),
          forumId: item.forumId ?? '',
          avatar: avatar,
        });
        if (recents.length >= 12) {
          break;
        }
      }
      if (recents.length > 0) {
        this.recentForums = recents;
      }
    } catch (e) {
      // 保留默认数据
    }
  }

  /** 关注列表就绪后的足迹头像补全：先用关注吧头像补齐仍缺头像的项，
   *  其余再走按吧名网络拉取并回写历史缓存（由 loadForums 收尾调用，避免挂载期重复发头像请求） */
  private async enrichRecentAvatars(): Promise<void> {
    let changed: boolean = false;
    const base: RecentForumItem[] = this.recentForums.map((r: RecentForumItem): RecentForumItem => {
      if (!r.avatar || !this.isValidAvatarUrl(r.avatar!)) {
        const fav: string = this.findFollowAvatar(r.name);
        if (fav.length > 0) {
          changed = true;
          return { name: r.name, lastVisit: r.lastVisit, forumId: r.forumId, avatar: fav };
        }
      }
      return r;
    });
    if (changed) {
      this.recentForums = base;
    }
    const missing: RecentForumItem[] = base.filter((r: RecentForumItem) => !r.avatar || !this.isValidAvatarUrl(r.avatar!));
    if (missing.length > 0) {
      this.fetchMissingForumAvatars(missing).catch(() => {});
    }
  }

  private async fetchMissingForumAvatars(missing: RecentForumItem[]): Promise<void> {
    const updated: RecentForumItem[] = [];
    for (const item of this.recentForums) {
      updated.push({ name: item.name, lastVisit: item.lastVisit, forumId: item.forumId, avatar: item.avatar });
    }
    const accountId: string = AuthManager.getInstance().getUser()?.userId ?? '';
    for (const item of missing) {
      try {
        const avatar = await TiebaService.getInstance().fetchForumAvatarByName(item.name);
        if (avatar.length > 0) {
          const idx = updated.findIndex((r: RecentForumItem) => r.name === item.name);
          if (idx >= 0) {
            updated[idx] = { name: updated[idx].name, lastVisit: updated[idx].lastVisit, forumId: updated[idx].forumId, avatar: avatar };
          }
          // Also update the history cache so the avatar persists
          if (accountId.length > 0) {
            try {
              const cacheKey = `${CACHE_KEY.PERSONAL_HISTORY}_${accountId}`;
              const raw = await CacheManager.getInstance().get(cacheKey);
              if (raw) {
                const items: PersonalContentItem[] = JSON.parse(raw) as PersonalContentItem[];
                let changed = false;
                for (const histItem of items) {
                  if (histItem.forumName === item.name && (!histItem.forumAvatar || histItem.forumAvatar!.length === 0)) {
                    histItem.forumAvatar = avatar;
                    changed = true;
                  }
                }
                if (changed) {
                  await CacheManager.getInstance().put(cacheKey, JSON.stringify(items));
                }
              }
            } catch (_) {
              // Cache update failed, non-critical
            }
          }
        }
      } catch (e) {
        // Continue with next
      }
    }
    this.recentForums = updated;
  }

  private findFollowAvatar(forumName: string): string {
    for (const f of this.follows) {
      if (f.forumName === forumName && f.avatar && f.avatar!.length > 0) {
        const url = f.avatar!;
        if (this.isValidAvatarUrl(url)) {
          return url;
        }
      }
    }
    return '';
  }

  private isAvatarFailed(name: string, isFollow: boolean = false): boolean {
    const list: string[] = isFollow ? this.failedFollowAvatars : this.failedAvatarNames;
    return list.indexOf(name) >= 0;
  }

  private markAvatarFailed(name: string, isFollow: boolean = false): void {
    if (isFollow) {
      if (this.failedFollowAvatars.indexOf(name) < 0) {
        this.failedFollowAvatars = [...this.failedFollowAvatars, name];
      }
    } else {
      if (this.failedAvatarNames.indexOf(name) < 0) {
        this.failedAvatarNames = [...this.failedAvatarNames, name];
      }
    }
  }

  private isValidAvatarUrl(url: string): boolean {
    if (!url || url.length === 0) {
      return false;
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return true;
    }
    // Protocol-relative URLs
    if (url.startsWith('//')) {
      return true;
    }
    return false;
  }

  private normalizeAvatarForDisplay(url: string): string {
    if (!url || url.length === 0) {
      return '';
    }
    if (url.startsWith('//')) {
      return `https:${url}`;
    }
    return url;
  }

  private formatRecentTime(time: string): string {
    if (!time || time.length === 0) {
      return '';
    }
    if (time.length <= 10) {
      return time;
    }
    return time.slice(5, 10);
  }

  // ===== 一键签到（贴吧 Lite 同款流程：官方批量优先 + 逐吧兜底 + 慢速模式间隔） =====

  /** 当前 UIAbilityContext（通知授权 / 长时任务 / 发布通知共用） */
  private uiContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  /** 一键签到入口：登录校验 → 弹进度浮层 → 签到全部关注吧 → 就地打勾 */
  private async handleSignAll(): Promise<void> {
    if (this.signAllRunning || AutoSignManager.getInstance().isRunning()) {
      // 已在签到（含后台签到）：再点一次即重新打开进度浮层查看
      this.signAllBackground = false;
      this.showSignAll = true;
      return;
    }
    if (!AuthManager.getInstance().isLogin()) {
      this.getUIContext().getPromptAction().showToast({ message: '请先登录后再签到' });
      return;
    }
    Haptic.light();
    this.resetSignAllState();
    this.showSignAll = true;
    this.signAllRunning = true;
    try {
      const result: AutoSignResult = await AutoSignManager.getInstance().signAll((progress: AutoSignProgress) => {
        this.applySignProgress(progress);
      }, this.follows.slice());
      this.signAllMessage = result.message;
      this.signAllSigned = result.signed;
      this.signAllFailed = result.failed;
      this.markSignedForums(result.signedForumNames);
      if (result.signed > 0) {
        Haptic.strong();
      }
    } catch (e) {
      this.signAllNotifyTitle = '一键签到失败';
      this.signAllMessage = (e as Error).message ?? '签到失败，请稍后重试';
    } finally {
      this.signAllRunning = false;
      this.onSignAllFinished();
    }
  }

  /**
   * 签到收尾：结束长时任务；若本次是「后台签到」模式，再发一条系统完成通知
   * （浮层未展示时用户看不到结果，故用通知兜底；通知发布失败则退回 Toast）
   */
  private async onSignAllFinished(): Promise<void> {
    try {
      const context: common.UIAbilityContext = this.uiContext();
      await AutoSignNotifier.getInstance().stopBackgroundTask(context);
      if (!this.signAllBackground) {
        return;
      }
      this.signAllBackground = false;
      const message: string = this.signAllMessage.length > 0 ? this.signAllMessage : '签到已结束';
      const delivered: boolean = await AutoSignNotifier.getInstance()
        .publishComplete(context, this.signAllNotifyTitle, message);
      if (!delivered) {
        this.getUIContext().getPromptAction().showToast({ message: `${this.signAllNotifyTitle}：${message}` });
      }
    } catch (e) {
      // 收尾（停长时任务 / 发通知）失败不影响签到结果本身，仅记录
      console.warn(`[AUTOSIGN] 签到收尾异常: ${e instanceof Error ? e.message : e}`);
    }
  }

  /** 后台签到：收起浮层继续签到（长时任务保活），完成后在通知栏提醒 */
  private async handleSignAllBackground(): Promise<void> {
    if (!this.signAllRunning) {
      this.showSignAll = false;
      return;
    }
    Haptic.light();
    const context: common.UIAbilityContext = this.uiContext();
    this.signAllBackground = true;
    this.showSignAll = false;
    // ① 先申请长时任务：立刻转入后台运行，退到后台也不被冻结
    await AutoSignNotifier.getInstance().startBackgroundTask(context);
    // ② 用户手势内申请通知授权（未授权时系统才弹框；拒绝也不影响签到）
    const enabled: boolean = await AutoSignNotifier.getInstance().ensureNotificationEnabled(context);
    this.getUIContext().getPromptAction().showToast({
      message: enabled
        ? '已转入后台签到，完成后会在通知栏提醒'
        : '已转入后台签到（通知未授权，可点顶部按钮查看结果）'
    });
  }

  private resetSignAllState(): void {
    this.signAllStage = AutoSignStage.Preparing;
    this.signAllTotal = 0;
    this.signAllFinished = 0;
    this.signAllSigned = 0;
    this.signAllFailed = 0;
    this.signAllForumName = '';
    this.signAllNote = '正在获取关注的吧…';
    this.signAllMessage = '';
    this.signAllBackground = false;
    this.signAllNotifyTitle = '一键签到完成';
  }

  /** 进度回调：三个阶段（准备 / 官方一键签到 / 逐吧签到）共用一份进度快照 */
  private applySignProgress(progress: AutoSignProgress): void {
    this.signAllStage = progress.stage;
    this.signAllTotal = progress.total;
    this.signAllFinished = progress.finished;
    this.signAllSigned = progress.signed;
    this.signAllFailed = progress.failed;
    this.signAllForumName = progress.forumName;
    this.signAllNote = progress.note;
  }

  /** 签到成功的吧就地打勾（不可变更新：整份列表替换，保证卡片刷新） */
  private markSignedForums(names: string[]): void {
    if (names.length === 0) {
      return;
    }
    const done: Set<string> = new Set<string>();
    for (const name of names) {
      done.add(name);
    }
    const next: FollowItem[] = [];
    for (const item of this.follows) {
      if (item.isSign || !done.has(item.forumName)) {
        next.push(item);
        continue;
      }
      next.push({
        forumName: item.forumName,
        forumId: item.forumId,
        level: item.level,
        exp: item.exp,
        isSign: true,
        memberCount: item.memberCount,
        avatar: item.avatar,
        hotValue: item.hotValue
      });
    }
    this.follows = next;
    this.syncFollows();
  }

  /** 浮层按钮：签到中 → 停止（当前请求结束后中断）；结束后 → 关闭 */
  private closeSignAll(): void {
    if (this.signAllRunning) {
      AutoSignManager.getInstance().cancel();
      this.signAllNote = '正在停止…';
      return;
    }
    this.showSignAll = false;
  }

  private openLogin(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Login' });
  }

  private openForum(forumName: string, forumId: string): void {
    if (forumName.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '贴吧信息暂不可用' });
      return;
    }
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/ThreadList',
      params: { kw: forumName, fid: forumId }
    }).catch(() => {
      this.getUIContext().getPromptAction().showToast({ message: '贴吧打开失败，请稍后重试' });
    });
  }

  @Builder
  TopBar() {
    Row() {
      Column({ space: 3 }) {
        Text('进吧')
          .fontSize(fs(22, this.fontScale))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      // 一键签到：一次给全部关注的吧签到（进度浮层见 SignAllDialog；开关见「软件设置 → 一键签到」）
      Button() {
        if (this.signAllRunning) {
          LoadingProgress()
            .width(22)
            .height(22)
            .color(Theme.brand())
        } else {
          SymbolGlyph($r('sys.symbol.checkmark_circle'))
            .fontColor([$r('sys.color.icon_primary')])
            .fontSize(fs(22, this.fontScale))
        }
      }
      .width(44)
      .height(44)
      .backgroundColor(Theme.segGlass(this.isDark, false))
      .border({ width: 0.5, color: Theme.manualGlassBorder() })
      .backgroundBlurStyle(BlurStyle.Thin, { scale: 0.85 })
      .shadow(Theme.segGlassShadow(this.isDark, false))
      .borderRadius(Radius.full)
      .margin({ left: 12 })
      .accessibilityText('一键签到')
      .onClick(() => { this.handleSignAll(); })

      Button() {
        Text('⇅')
          .fontSize(fs(22, this.fontScale))
          .fontColor($r('sys.color.icon_primary'))
      }
      .width(44)
      .height(44)
      .backgroundColor(Theme.segGlass(this.isDark, false))
      .border({ width: 0.5, color: Theme.manualGlassBorder() })
      .backgroundBlurStyle(BlurStyle.Thin, { scale: 0.85 })
      .shadow(Theme.segGlassShadow(this.isDark, false))
      .borderRadius(Radius.full)
      .margin({ left: 12 })
      .accessibilityText('关注吧排序')
      .accessibilityDescription(this.forumSortLabel(this.forumSortMode))
      .onClick(() => {
        this.showForumSortDialog = true;
        Haptic.light();
      })

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
   * 官方槽位标题栏：整行搬进 Navigation 的 title 槽位。
   * 几何与 TopBar 逐项一致（top 44 / bottom 10 / 左右 Spacing.lg / 三枚 44 圆钮 / margin-left 12），
   * 只把玻璃从 backgroundBlurStyle 自绘换成官方沉浸材质：
   * - 三枚圆钮 → ImmMaterial.seg(false)（THIN 中性档，与首页顶栏同一套材质语言）；
   * - Button 必须显式 backgroundColor(Color.Transparent)：Button 自带品牌蓝默认填充，不清底会透出蓝底；
   * - 不挂 border / backgroundBlurStyle / shadow：官方明确不建议与 systemMaterial 同用（会互相覆盖）。
   * 图标色沿用系统可反色资源（icon_primary），满足官方自动反色前提。
   */
  @Builder
  ForumsTitleBar() {
    Row() {
      Column({ space: 3 }) {
        Text('进吧')
          .fontSize(fs(22, this.fontScale))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      // 一键签到：一次给全部关注的吧签到（进度浮层见 SignAllDialog；开关见「软件设置 → 一键签到」）
      Button() {
        if (this.signAllRunning) {
          LoadingProgress()
            .width(22)
            .height(22)
            .color(Theme.brand())
        } else {
          SymbolGlyph($r('sys.symbol.checkmark_circle'))
            .fontColor([$r('sys.color.icon_primary')])
            .fontSize(fs(22, this.fontScale))
        }
      }
      .width(44)
      .height(44)
      .backgroundColor(Color.Transparent)
      .systemMaterial(ImmMaterial.seg(false))
      .borderRadius(Radius.full)
      .margin({ left: 12 })
      .accessibilityText('一键签到')
      .onClick(() => { this.handleSignAll(); })

      Button() {
        Text('⇅')
          .fontSize(fs(22, this.fontScale))
          .fontColor($r('sys.color.icon_primary'))
      }
      .width(44)
      .height(44)
      .backgroundColor(Color.Transparent)
      .systemMaterial(ImmMaterial.seg(false))
      .borderRadius(Radius.full)
      .margin({ left: 12 })
      .accessibilityText('关注吧排序')
      .accessibilityDescription(this.forumSortLabel(this.forumSortMode))
      .onClick(() => {
        this.showForumSortDialog = true;
        Haptic.light();
      })

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
    .backgroundColor(Color.Transparent)
  }

  /**
   * §4.1 平板列数（2026-09-14 开工）：大屏横 4 / 竖 3；窄窗与手机维持 2 列。
   * 判据三层：① 大屏形态闸门（deviceType tablet/2in1 或 isFoldable——折叠屏 deviceType 为 'phone'）；
   * ② 宽度门槛 600（兜住折叠态 / 分屏 / 自由多窗窄窗）；③ 宽高比判横竖屏。
   * 「最小单列宽保护」按用户拍板**不启用**（先用主方案看真机）；「创建吧」卡片随流、不独占。
   */
  private forumColumns(): number {
    // 窗口闸门最前（2026-09-17 小窗 / 分屏适配）：窗口宽 <600（自由多窗小窗 / 分屏窄窗）一律回落
    // 手机档——本页手机档 2 列、阔直屏手机档 1 列；须在设备恒值分支（大折叠恒 3）之前，防小窗误命中
    if (this.pageWidth > 0 && this.pageWidth < 600) {
      return isWideBarDevice() ? 1 : 2;
    }
    // 「列数调整」（2026-09-18，个性化 → 列数调整）：仅大屏形态（平板 / 阔直屏 / 大折叠展开）生效，
    // 窄窗与手机档已由上面的窗口闸门返回不受影响；默认档 ov=0 → 原样走下面自动适配分支（逐像素零回归）
    if (isLargeScreenForm(this.isWideFormDevice)) {
      const ov: number = overrideColumns(this.columnMode, this.isLandscape);
      if (ov > 0) {
        return ov;
      }
    }
    // 大折叠（docs/TiebaPura大折叠适配.md §4.2）：竖 2 / 横 3（2026-09-17 用户改定，与阔直屏同口径）
    if (isLargeFoldDevice()) {
      return this.isLandscape ? 3 : 2;
    }
    // 阔直屏（docs/TiebaPura阔直屏适配.md §4.2，2026-09-17 用户改定）：不依赖宽度阈值（竖屏宽 <600），
    // 竖 1 / 横 3（竖屏回落手机单列档；初版竖 2 作废）
    if (isWideBarDevice()) {
      return this.isLandscape ? 3 : 1;
    }
    if (!this.isWideFormDevice) {
      return 2;
    }
    if (this.pageWidth < 600) {
      return 2;
    }
    // 2026-09-17 三次拍板：平板**竖屏 2 列**（≥840 竖屏 3 列作废）/ 横屏 3 列
    return this.isLandscape ? 3 : 2;
  }

  /** 列数 → Grid 列模板（手机 2 / 平板竖 2 / 平板横 3） */
  private columnsTemplateOf(n: number): string {
    if (n >= 4) {
      return '1fr 1fr 1fr 1fr';
    }
    if (n === 3) {
      return '1fr 1fr 1fr';
    }
    return '1fr 1fr';
  }

  /**
   * 顶部满宽渐显带（2026-09-14 顺带修复，同 `docs/fade-band-fullwidth-fix.md`）：原整页 DST_IN
   * 遮罩（挂滚动层）离屏层宽度解析异常 → 渐显带右缘缺一条竖带。改 **背景色渐变条** 挂在页面顶层：
   * 下层是纯背景色，背景色渐变条叠加 = 视觉等价渐隐，宽度不依赖滚动容器 / 离屏层解析。
   * 高 98 = 顶栏（按钮 + 标题）；渐变自顶部线性、无全实段（否则内容到顶栏会被"硬切"）。
   */
  @Builder
  TopFadeBand() {
    Column()
      .width('100%')
      .height(98)
      .linearGradient({
        direction: GradientDirection.Bottom,
        colors: [
          [Theme.bg(this.isDark), 0.0],
          [this.isDark ? '#00101114' : '#00F2F4F7', 1.0]
        ]
      })
      .hitTestBehavior(HitTestMode.None)
  }

  /**
   * 关注吧排序菜单内容（系统 `bindMenu` 的 CustomBuilder）。
   * 原自绘浮层的外壳（全屏遮罩 / `position` / 玻璃自绘 / 弹出动画）已全部交给 `bindMenu`：
   * 定位 → 隐形锚点 + `Placement.BottomRight`；背景 / 圆角 / 描边 / 阴影 → `options.systemMaterial`。
   * 此处只保留菜单项本体（宽度 210、内边距、选中高亮 + ✓ 全部零改动）。
   */
  @Builder
  ForumSortMenuContent() {
    Column({ space: 2 }) {
      this.ForumSortItem(ForumSortMode.NameAsc, '名称正序')
      this.ForumSortItem(ForumSortMode.NameDesc, '名称倒序')
      this.ForumSortItem(ForumSortMode.TimeAsc, '最早关注')
      this.ForumSortItem(ForumSortMode.TimeDesc, '最新关注')
    }
    .padding({ top: 6, bottom: 6 })
  }

  @Builder
  ForumSortItem(mode: ForumSortMode, label: string) {
    Row({ space: 10 }) {
      Text(label)
        .fontSize(fs(14, this.fontScale))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.forumSortMode === mode ? Theme.brand() : Theme.textPrimary(this.isDark))
        .layoutWeight(1)
      if (this.forumSortMode === mode) {
        Text('✓')
          .fontSize(fs(13, this.fontScale))
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.brand())
      }
    }
    .width(210)
    .padding({ left: 16, right: 16, top: 13, bottom: 13 })
    .borderRadius(Radius.md)
    .onClick(() => { this.applyForumSort(mode); })
  }

  /** 足迹删除确认：居中卡片（仅删除本地足迹记录，不影响关注/收藏） */
  @Builder
  RecentDeleteDialog() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#06000000')
        .onClick(() => { this.showRecentDelete = false; })
        .transition(TransitionEffect.opacity(0).animation({ duration: 180, curve: Curve.EaseOut }))

      Column() {
        Column({ space: 6 }) {
          Text('删除足迹')
            .fontSize(fs(17, this.fontScale))
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.textPrimary(this.isDark))
            .textAlign(TextAlign.Center)
          Text(`确定删除「${this.recentDeleteName}」的足迹吗？\n仅删除本地浏览记录，不影响关注与收藏。`)
            .fontSize(fs(13, this.fontScale))
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.textSecondary(this.isDark))
            .lineHeight(fs(18, this.fontScale))
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ left: Spacing.lg, right: Spacing.lg, top: Spacing.lg, bottom: Spacing.md })

        Row({ space: Spacing.md }) {
          Button() {
            Text('取消')
              .fontSize(fs(15, this.fontScale))
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.textPrimary(this.isDark))
          }
          .layoutWeight(1)
          .height(44)
          .backgroundColor(Theme.bgCard(this.isDark))
          .borderRadius(Radius.full)
          .onClick(() => { this.showRecentDelete = false; })

          Button() {
            Text('删除')
              .fontSize(fs(15, this.fontScale))
              .fontColor(Color.White)
              .fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1)
          .height(44)
          .backgroundColor(Theme.danger())
          .borderRadius(Radius.full)
          .onClick(() => { this.deleteRecentForum(); })
        }
        .width('100%')
        .padding({ left: Spacing.lg, right: Spacing.lg, bottom: Spacing.lg })
      }
      .width(overlayCardWidth())
      .margin({ bottom: 110 })
      .padding({ top: Spacing.md })
      // 真模糊磨砂：低不透明发透底 + 0.5 白描边 + backgroundBlurStyle（页面主体 systemMaterial 不在槽位，渲染无效；2026-09-07 probe 实证 API26 自绘弹窗浮层挂材质亦 out of scope，见指南 §10.3）
      .backgroundColor(Theme.sheetGlass(this.isDark))
      .borderRadius(32)
      .border({ width: 0.5, color: Theme.manualGlassBorder() })
      .backgroundBlurStyle(BlurStyle.Regular, { scale: 0.85 })
      .shadow({ radius: 48, color: '#3D000000', offsetY: 18 })
      .transition(TransitionEffect.scale({ x: 0.92, y: 0.92 }).combine(TransitionEffect.translate({ y: 24 })).combine(TransitionEffect.opacity(0)).animation({ duration: 220, curve: Curve.EaseOut }))
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Bottom)
    .zIndex(100)
    .transition(TransitionEffect.asymmetric(
      TransitionEffect.IDENTITY,
      TransitionEffect.opacity(0).animation({ duration: 200, curve: Curve.EaseInOut })
    ))
  }

  /**
   * 内容层：我的足迹 + 关注吧网格 + 底部渐隐（官方标题栏路径与兜底路径共用同一份内容）。
   */
  @Builder
  ForumsContent() {
    Stack({ alignContent: Alignment.TopStart }) {
      List({ scroller: this.forumsScroller }) {
        // 预留TopBar高度作为初始间距
        ListItem() {
          Column()
            .width('100%')
            .height(90)
        }
        .backgroundColor(Color.Transparent)

        if (!this.loggedIn) {
          ListItem() {
            EmptyView({ message: '登录后查看你关注的吧', icon: '＋', actionText: '登录', action: () => this.openLogin() })
          }
          .layoutWeight(1)
        } else if (this.forumState === LoadState.Loading) {
          ListItem() {
            LoadingView({ message: '正在加载关注的吧...' })
          }
          .layoutWeight(1)
        } else if (this.forumState === LoadState.Error) {
          ListItem() {
            ErrorView({ message: '关注列表加载失败', onRetry: () => this.loadForums() })
          }
          .layoutWeight(1)
        } else if (this.forumState === LoadState.Empty) {
          ListItem() {
            EmptyView({ message: '还没有关注的吧', icon: '＋' })
          }
          .layoutWeight(1)
        } else {
        ListItem() {
          Column({ space: 0 }) {
            // 我的足迹
            if (this.recentForums.length > 0) {
              Column({ space: 12 }) {
                Row() {
                  Row({ space: 8 }) {
                    SymbolGlyph($r('sys.symbol.clock'))
                      .fontSize(fs(18, this.fontScale))
                      .fontColor([$r('sys.color.icon_primary')])
                    Text('我的足迹')
                      .fontSize(fs(18, this.fontScale))
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Theme.textPrimary(this.isDark))
                  }
                  .alignItems(VerticalAlign.Center)
                  Blank()
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)
                .padding({ left: Spacing.lg, right: Spacing.lg })

                Scroll() {
                  Row({ space: 14 }) {
                    ForEach(this.recentForums, (recent: RecentForumItem) => {
                      Column({ space: 8 }) {
                        if (recent.avatar && this.isValidAvatarUrl(recent.avatar!) && !this.isAvatarFailed(recent.name)) {
                          Image(this.normalizeAvatarForDisplay(recent.avatar!))
                            .width(54)
                            .height(54)
                            .borderRadius(27)
                            .objectFit(ImageFit.Cover)
                            .clip(true)
                            .onError(() => {
                              this.markAvatarFailed(recent.name);
                            })
                        } else {
                          Stack() {
                            Text(recent.name.charAt(0))
                              .fontSize(fs(22, this.fontScale))
                              .fontWeight(FontWeight.Bold)
                              .fontColor(Theme.brand())
                              .width('100%')
                              .height('100%')
                              .textAlign(TextAlign.Center)
                          }
                          .width(54)
                          .height(54)
                          .borderRadius(27)
                          .backgroundColor(Theme.brandBg(this.isDark))
                          .alignContent(Alignment.Center)
                          .clip(true)
                        }
                        Text(recent.name)
                          .fontSize(fs(12, this.fontScale))
                          .fontColor(Theme.textPrimary(this.isDark))
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .width(72)
                          .textAlign(TextAlign.Center)
                      }
                      .onClick(() => {
                        this.openForum(recent.name, recent.forumId ?? '');
                      })
                      .gesture(LongPressGesture({ fingers: 1, repeat: false, duration: 350 })
                        .onAction(() => {
                          this.recentDeleteName = recent.name;
                          this.showRecentDelete = true;
                          Haptic.light();
                        }))
                    }, (recent: RecentForumItem) => recent.name)
                  }
                  .constraintSize({ minWidth: '100%' })
                  .justifyContent(FlexAlign.Start)
                  .padding({ left: Spacing.lg, right: Spacing.lg })
                }
                .scrollable(ScrollDirection.Horizontal)
                .scrollBar(BarState.Off)
                .edgeEffect(EdgeEffect.Spring)
              }
              .width('100%')
              .padding({ top: Spacing.lg, bottom: Spacing.lg })
            }

            // 我关注的吧
            Column({ space: 12 }) {
              Row() {
                Row({ space: 8 }) {
                  SymbolGlyph($r('sys.symbol.line_3_horizontal'))
                    .fontSize(fs(18, this.fontScale))
                    .fontColor([$r('sys.color.icon_primary')])
                  Text('我关注的吧')
                    .fontSize(fs(18, this.fontScale))
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.textPrimary(this.isDark))
                }
                .alignItems(VerticalAlign.Center)

                Blank()

                Row({ space: 4 }) {
                  Text('全部')
                    .fontSize(fs(13, this.fontScale))
                    .fontColor(Theme.textSecondary(this.isDark))
                  Text('›')
                    .fontSize(fs(16, this.fontScale))
                    .fontColor(Theme.textTertiary(this.isDark))
                }
                .onClick(() => {
                  this.getUIContext().getPromptAction().showToast({ message: '全部关注列表即将开放' });
                })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
              .padding({ left: Spacing.lg, right: Spacing.lg })

              Grid() {
                // 创建吧 入口
                GridItem() {
                  Column({ space: 8 }) {
                    Row({ space: 10 }) {
                      Stack() {
                        Text('＋')
                          .fontSize(fs(22, this.fontScale))
                          .fontColor(Color.White)
                      }
                      .width(44)
                      .height(44)
                      .borderRadius(22)
                      .backgroundColor(Theme.brand())

                      Column({ space: 3 }) {
                        Text('创建吧')
                          .fontSize(fs(14, this.fontScale))
                          .fontWeight(FontWeight.Medium)
                          .fontColor(Theme.textPrimary(this.isDark))
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                        Text('新建吧，做吧主')
                          .fontSize(fs(11, this.fontScale))
                          .fontColor(Theme.textSecondary(this.isDark))
                      }
                      .layoutWeight(1)
                      .alignItems(HorizontalAlign.Start)
                    }
                    .width('100%')
                    .padding(Spacing.md)
                    .backgroundColor(Theme.bgCard(this.isDark))
                    .borderRadius(Radius.lg)
                    .onClick(() => {
                      this.getUIContext().getPromptAction().showToast({ message: '创建吧需要贴吧官方接口支持' });
                    })
                  }
                  .width('100%')
                }

                ForEach(this.sortedFollows(), (forum: FollowItem) => {
                  GridItem() {
                    Stack({ alignContent: Alignment.TopEnd }) {
                    Column({ space: 8 }) {
                      Row({ space: 10 }) {
                        Stack() {
                          if (forum.avatar && this.isValidAvatarUrl(forum.avatar!) && !this.isAvatarFailed(forum.forumName, true)) {
                            Image(this.normalizeAvatarForDisplay(forum.avatar!))
                              .width(44)
                              .height(44)
                              .borderRadius(22)
                              .objectFit(ImageFit.Cover)
                              .clip(true)
                              .onError(() => {
                                this.markAvatarFailed(forum.forumName, true);
                              })
                          } else {
                            Stack() {
                              Text(forum.forumName.charAt(0))
                                .fontSize(fs(20, this.fontScale))
                                .fontWeight(FontWeight.Bold)
                                .fontColor(Theme.brand())
                                .width('100%')
                                .height('100%')
                                .textAlign(TextAlign.Center)
                            }
                            .width(44)
                            .height(44)
                            .borderRadius(22)
                            .backgroundColor(Theme.brandBg(this.isDark))
                            .alignContent(Alignment.Center)
                            .clip(true)
                          }
                        }
                        .width(44)
                        .height(44)

                        Column({ space: 3 }) {
                          Row({ space: 3 }) {
                            Text(forum.forumName)
                              .fontSize(fs(14, this.fontScale))
                              .fontWeight(FontWeight.Medium)
                              .fontColor(Theme.textPrimary(this.isDark))
                              .maxLines(1)
                              .textOverflow({ overflow: TextOverflow.Ellipsis })
                          }
                          .width('100%')
                          Row({ space: 4 }) {
                            if (forum.level > 0) {
                              Text(`${forum.level}`)
                                .fontSize(fs(10, this.fontScale))
                                .fontColor(Color.White)
                                .backgroundColor(Theme.levelColor(forum.level ?? 0))
                                .borderRadius(8)
                                .minFontScale(1)
                                .maxFontScale(1)
                                .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                            }
                            if (forum.hotValue && forum.hotValue!.length > 0) {
                              Text(`${forum.hotValue}`)
                                .fontSize(fs(11, this.fontScale))
                                .fontColor(Theme.textSecondary(this.isDark))
                            }
                            if (forum.isSign) {
                              Text('☑')
                                .fontSize(fs(11, this.fontScale))
                                .fontColor(Theme.brand())
                            }
                          }
                        }
                        .layoutWeight(1)
                        .alignItems(HorizontalAlign.Start)
                      }
                      .width('100%')
                      .padding(Spacing.md)
                      .backgroundColor(Theme.bgCard(this.isDark))
                      .borderRadius(Radius.lg)
                      .onClick(() => this.openForum(forum.forumName, forum.forumId ?? ''))
                      .gesture(LongPressGesture({ fingers: 1, repeat: false, duration: 350 })
                        .onAction(() => {
                          // 先写弹窗展示快照，再置显隐（@Watch 立即 open，避免首帧读到旧吧名）
                          this.forumMenuTarget = forum;
                          this.forumMenuName = forum.forumName;
                          this.forumMenuPinned = this.isForumPinned(forum.forumName);
                          this.showForumMenu = true;
                          Haptic.light();
                        }))
                    }
                    .width('100%')

                    if (this.isForumPinned(forum.forumName)) {
                      SymbolGlyph($r('sys.symbol.pin_fill'))
                        .fontSize(fs(12, this.fontScale))
                        .fontColor([Theme.brand()])
                        .margin({ top: Spacing.sm, right: Spacing.sm })
                        .accessibilityText('已置顶')
                    }
                    }
                  }
                }, (forum: FollowItem) => forum.forumName)
              }
              .columnsTemplate(this.columnsTemplateOf(this.forumColumns()))
              .columnsGap(Spacing.md)
              .rowsGap(Spacing.md)
              .width('100%')
              .padding({ left: Spacing.lg, right: Spacing.lg })
            }
            .width('100%')
          }
          .width('100%')
          .padding({ bottom: 150 })
        }
      }
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ bottom: 150 })
    .scrollBar(BarState.Off)
    .clip(false)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

    // §4.1 顺带（2026-09-14）：顶部渐显带改挂页面层（盖列表内容）；位置在悬浮 TopBar **之前**，
    // 故不会盖住顶栏按钮——官方 title 槽位路径 TopBar 在 Navigation title 层，更不受影响
    this.TopFadeBand()

    // 悬浮TopBar层（内容可穿过TopBar区域）；官方 title 槽位路径下三钮已在槽位里，这里不再叠一层
    if (!FORUMS_OFFICIAL_TITLE_BAR) {
      this.TopBar()
    }
    // 进吧：关注吧长按菜单已换成系统 CustomDialog（由 controller 驱动，无需在此挂载）
    /**
     * 关注吧排序菜单锚点（§6.9：自绘下拉浮层 → 系统 bindMenu）。
     * 原自绘面板是 `position({ top: 100, right: 16 })`；这里用 1×1 隐形锚点 + `Placement.BottomRight`
     * 把菜单右下角精确落回同一坐标（排序钮右侧还有深色切换钮，直接挂按钮会让菜单整体左移）。
     * 锚点不参与视觉与交互：1×1 + 全透明 + hitTestBehavior(None)，弹出仍由 TopBar 排序钮发起。
     */
    Row()
      .width(1)
      .height(1)
      .position({ top: 99, right: 16 })
      .hitTestBehavior(HitTestMode.None)
      .bindMenu(this.showForumSortDialog, this.ForumSortMenuContent(), {
        placement: Placement.BottomRight,
        targetSpace: LengthMetrics.vp(0),
        systemMaterial: ImmMaterial.menu(),
        onDisappear: () => { this.showForumSortDialog = false; }
      })
    if (this.showRecentDelete) {
      this.RecentDeleteDialog()
    }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .onAreaChange((oldValue: Area, newValue: Area) => {
      const width = newValue.width as number;
      const height = newValue.height as number;
      this.isWideScreen = width >= 840;
      // §4.1：窗口宽 / 高 → 列数判定
      this.pageWidth = width;
      this.pageHeight = height;
      this.isLandscape = width > height;
    })
  }

  build() {
    if (FORUMS_OFFICIAL_TITLE_BAR) {
      // 官方槽位路径：Navigation + 自定义 title（height 固定 98，与改造前悬浮 TopBar 几何一致）
      // barStyle STACK：内容区延伸到标题栏之下（官方建议，标题栏材质获得最佳沉浸体验的前提）
      // backgroundColor 显式透明：避免标题栏自带底色压住滚动经过的内容
      Navigation() {
        this.ForumsContent()
      }
      .title({ builder: this.ForumsTitleBar(), height: FORUMS_TITLE_BAR_HEIGHT },
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
      // 兜底路径：改造前原样（页面主体悬浮 TopBar + manualGlass/backgroundBlurStyle 真磨砂）
      this.ForumsContent()
    }
  }
}
