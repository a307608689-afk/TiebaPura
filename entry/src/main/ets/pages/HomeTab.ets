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
import { display, LengthMetrics } from '@kit.ArkUI';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { pasteboard, BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { AuthManager } from '../service/AuthManager';
import { TiebaService } from '../service/TiebaService';
import { CacheManager } from '../cache/CacheManager';
import { CACHE_KEY, CACHE_TTL } from '../common/Constants';
import { FollowFeedStore, POOL_HIGH, sortThreadsByTimeDesc } from '../service/FollowFeedStore';
import { FollowItem, PagedResult, ThreadItem, PersonalContentItem } from '../model/DataModel';
import { Theme, Spacing, Radius, Breakpoint, CARD_COLUMNS_KEY, isDarkMode, ImmBlur, ImmMaterial, fs, isWideBarDevice, isLargeFoldDevice, isWideFormDevice as detectWideFormDevice, readColumnMode, overrideColumns, isLargeScreenForm, isWideBarFullscreen } from '../common/Theme';
import { ErrorView, EmptyView, ThreadCard, ThreadItemData, ThreadSharePayload } from '../components/CommonComponents';
import { ThreadListSkeleton } from '../components/Skeleton';

interface FollowSets {
  ids: Set<string>;
  names: Set<string>;
}

/**
 * WaterFlow 数据源（§4.2 决策 12）：包装 @State 数组，通过 @Watch 自动同步。
 * reload() 用于全量替换（下拉刷新 / 切换 feed），notifyAdd() 用于尾部追加（加载更多）。
 */
class ThreadDataSource implements IDataSource {
  private listeners: DataChangeListener[] = [];
  public data: ThreadItem[] = [];

  totalCount(): number {
    return this.data.length;
  }

  getData(index: number): ThreadItem {
    return this.data[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const idx: number = this.listeners.indexOf(listener);
    if (idx >= 0) {
      this.listeners.splice(idx, 1);
    }
  }

  reload(): void {
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataReloaded();
    });
  }

  notifyAdd(start: number): void {
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataAdd(start);
    });
  }
}

enum LoadState {
  Loading,
  Success,
  Empty,
  Error,
}

enum HomeFeed {
  Recommended = 0,
  Following = 1,
}

/** 首页预加载阈值：距底部剩余距离小于该值时提前静默加载下一页（约 2 屏，覆盖快速甩滑的请求耗时） */
const HOME_PREFETCH_DISTANCE: number = 1200;
/** 关注动态页：本地切片分页每页条数（聚合结果一次性拉回，翻页零请求） */
const FOLLOW_FEED_PAGE_SIZE: number = 20;

/**
 * 推荐/关注动态页内容区顶部让位（首卡距屏幕顶）：悬浮胶囊底边 ≈ 48(栏内 top) + 40(胶囊高) ≈ 88，
 * 98 即留约 10 的呼吸间隙；由 Refresh 的 margin-top 承担，随内容滚动（沉浸）。
 * 注意：不要再往 Scroll 内的 Column 里塞「占位子元素」——子元素自身的 margin/space 会在这份让位
 * 之上再叠一份，留空看起来明显偏多。
 */
const HOME_TOP_PAD: number = 98;

/**
 * 顶部官方标题栏试点开关（2026-09-10）：
 * true  = 「推荐 / 关注动态 / 搜索」整行搬进 Navigation 的 title 槽位，玻璃交给官方沉浸材质 systemMaterial
 *         （官方口径：systemMaterial 的生效区域仅 Navigation/NavDestination 标题栏、横向 Tabs(barPosition=End) 底部 TabBar）；
 * false = 回退改造前的页面主体悬浮层（manualGlass + backgroundBlurStyle 真磨砂兜底）。
 */
const HOME_OFFICIAL_TITLE_BAR: boolean = true;
/**
 * 官方标题栏高度：与改造前悬浮层几何逐项一致 —— 44(状态栏让位) + 44(按钮行高) + 20(底部呼吸) = 108。
 * NavigationCustomTitle 设置了 height 时 titleMode 不参与计算。
 */
const HOME_TITLE_BAR_HEIGHT: number = 108;
/** 顶部渐隐带夹取下限：顶栏需求 44 + 38 + 20 ≈ 102，向上留 6vp 余量（§4.2 决策 5） */
const HOME_FADE_MIN: number = 108;
/** 顶部渐隐带夹取上限：保住竖屏观感（§4.2 决策 5） */
const HOME_FADE_MAX: number = 180;

/**
 * 首页自含页组件（Index.ets 拆分的最后一个内联页）：
 * - 数据/方法/UI 全自管：推荐流 + 关注动态双数据源、点赞/分享/进贴/作者主页、首页历史等
 * - 与宿主解耦（仅靠 AppStorage token / 回调）：
 *   · homeBootRequest：宿主 aboutToAppear 初始化完成后通知本页冷启动加载
 *   · tabLoginRefresh：登录/登出/换号时重同步账号数据并失效账号级缓存
 *   · homePageShownTick：宿主 onPageShow 通知，做作者昵称回填刷新
 *   · homeRetapRequest：宿主底栏重复点击首页 Tab 时通知整页刷新
 *   · darkTick / fontScale：深色与字号全局联动
 *   · onOpenFavorite：首页搜索入口联动收藏页本地搜索（宿主负责切 Tab）
 */
@Component
export struct HomeTab {
  /** 首页搜索入口：宿主切换到收藏 Tab（搜索在收藏页本地过滤） */
  onOpenFavorite: () => void = () => {
  };
  @StorageLink('fontScale') fontScale: number = 1.0;
  // 字号全局变更广播（2026-09-13）：从字号设置页返回时宿主自增，@Watch 回写 fontScale
  // 强制本页依赖刷新（离屏期间 @StorageLink 同步不重绘，工程已知问题）
  @StorageLink('fontTick') @Watch('onFontTick') fontTick: number = 0;
  // 「列数调整」档位广播（2026-09-18，个性化 → 列数调整）：@Watch 回写本地档位 → 列数函数按新档返回并强制回到列表顶部
  // （离屏期间 @StorageLink 同步不重绘，故用 tick + 本地 @State 兜底，同 fontTick 范式）
  @StorageLink('columnModeTick') @Watch('onColumnModeTick') columnModeTick: number = 0;
  @State columnMode: number = 0;
  @StorageLink('darkTick') @Watch('onDarkTick') darkTick: number = 0;
  @State isDark: boolean = false;
  // 使用习惯：首页推荐仅显示关注吧的帖子（开关变化时自动刷新推荐流）
  @StorageLink('homeOnlyFollow') @Watch('onHomeOnlyFollowChanged') homeOnlyFollow: boolean = false;
  // 宿主启动完成后通知（约 aboutToAppear 各 Manager init + 登录态就绪后自增一次）
  @StorageLink('homeBootRequest') @Watch('onBootTick') homeBootRequest: number = 0;
  // 登录/登出/换号通用事件（各常驻子页订阅）
  @StorageLink('tabLoginRefresh') @Watch('onLoginTick') tabLoginRefresh: number = 0;
  // 宿主 onPageShow 自增：返回本页时回填作者昵称（不触发网络）
  @StorageLink('homePageShownTick') @Watch('onPageTick') homePageShownTick: number = 0;
  // 宿主底栏重复点击首页 Tab：整页刷新（按当前 feed 重拉第一页）
  @StorageLink('homeRetapRequest') @Watch('onRetapTick') homeRetapRequest: number = 0;
  @State loggedIn: boolean = false;
  @State @Watch('onThreadsChange') threads: ThreadItem[] = [];
  @State loadState: LoadState = LoadState.Loading;
  @State homePage: number = 1;
  @State homeHasMore: boolean = true;
  @State homeStalledPages: number = 0;
  @State homeRefreshing: boolean = false;
  @State homeLoadingMore: boolean = false;
  @State homeFeed: HomeFeed = HomeFeed.Recommended;
  // ===== 关注动态独立数据源（v1.17：与推荐流解耦，切换不销毁、不重拉，左右滑动转场时各自渲染）=====
  @State @Watch('onFolThreadsChange') folThreads: ThreadItem[] = [];
  @State folState: LoadState = LoadState.Loading;
  // ===== WaterFlow 数据源（§4.2 决策 12）：@Watch 自动同步 @State 数组 =====
  @State recDataSource: ThreadDataSource = new ThreadDataSource();
  @State folDataSource: ThreadDataSource = new ThreadDataSource();
  @State columns: number = 3;
  // ===== 平板适配（docs/TiebaPura平板适配.md §4.2）=====
  /** 大屏形态设备（平板 / 2in1 / 折叠屏）：静态判定一次。折叠屏 deviceType 为 'phone'，必须单独用 isFoldable 识别 */
  private readonly isWideFormDevice: boolean = detectWideFormDevice();
  /** 窗口宽 / 高（vp）：aboutToAppear 同步取首帧初值，onAreaChange 实时兜底 */
  @State pageWidth: number = 0;
  @State pageHeight: number = 0;
  /** 顶部渐隐带渐隐停靠点（视口高 × 0.15 夹取到 [108,180] 后折算的百分比） */
  @State fadeStop: number = 0.15;
  @State folPage: number = 1;
  @State folHasMore: boolean = true;
  @State folStalledPages: number = 0;
  @State folRefreshing: boolean = false;
  @State folLoadingMore: boolean = false;
  @State errorMsg: string = '';
  // 聚合拉回的关注用户帖子全量（本地切片分页源）
  private folAll: ThreadItem[] = [];
  // 冷启动首次进入自动加载，后续切换不重新拉取（仅下拉刷新/整页刷新手动刷新）
  private folFeedLoaded: boolean = false;
  // 推荐流已加载标志：首次加载成功后置位；切回时若已加载则不重拉、恢复浏览位置
  // （与关注动态 folFeedLoaded 对称；换号/「仅关注吧」开关变化时置 false 触发重载）
  private recommendLoaded: boolean = false;
  private folScrollY: number = 0;
  private folLoadToken: number = 0;
  private folLastPrefetchY: number = -10000;
  private folContentH: number = 0;
  private folViewportH: number = 0;
  private folScroller: Scroller = new Scroller();
  // 首页列表控制器：重复点击首页 tab 刷新时回到顶部
  private homeScroller: Scroller = new Scroller();
  // 各 feed 浏览位置记忆：推荐流 / 关注动态 分别记录滚动偏移，切回时恢复
  private homeScrollY: number = 0;
  private recommendScrollY: number = 0;
  // 首页 feed 左右滑动转场动画状态：首次挂载豁免（避免与整页 Tab 滑入叠加成双层动画）；切换动画期间锁（防重复触发）
  private firstHomeMount: boolean = true;
  private homeFeedSwitching: boolean = false;
  // 首页预加载测量值：内容高/视口高（普通字段，避免 onAreaChange 高频回调触发 UI 重建）
  private homeContentH: number = 0;
  private homeViewportH: number = 0;
  // 首页预加载节流与竞态：上次触发偏移；请求代际 token（刷新/切feed时递增，旧请求结果直接丢弃）
  private homeLastPrefetchY: number = -10000;
  private homeLoadToken: number = 0;
  // 「仅推荐关注的吧」：关注吧 ID / 吧名集合（会话内缓存，登录/开关变化时失效）。
  // 两套并存：现代 API 推荐流 forumName 取自 fname/forum_name，关注列表取自 forum.name，
  // 吧名格式不同源，优先按 forumId 匹配（稳定），forumName 仅作为 forumId 缺失时的兜底。
  private followForumIds: Set<string> = new Set<string>();
  private followForumNames: Set<string> = new Set<string>();
  private followForumNamesLoaded: boolean = false;
  // 「仅关注吧」聚合时间线引擎（游标式供给 + 本地待展示池 + 已消费记录，三件套持久化）
  private followFeed: FollowFeedStore = new FollowFeedStore();
  // ① 会话级去重：本会话已展示过的 tid（正常模式主用；仅关注模式的跨会话去重由引擎持久化接管）。
  // 换号时清空；刷新/开关切换不再清空（看过的就是看过的，切口径不重置去重）。
  private shownTids: Set<string> = new Set<string>();
  private shownTidsQueue: string[] = [];   // FIFO 淘汰队列，封顶防内存膨胀
  // 首页昵称补校准轮数（仅当仍有占位名作者时最多补 3 轮）
  private homeReEnrichAttempts: number = 0;
  // 首页初始化完成标志：冷启动恢复开关触发的首次 Watch 不强制刷新（由冷启动缓存直出接管）
  private homeInitDone: boolean = false;
  // 冷启动引导只执行一次（homeBootRequest 可能先于本组件 aboutToAppear 置位）
  private bootStarted: boolean = false;

  // 延迟初始化：aboutToAppear生命周期阶段UIContext就绪后赋值，避免类字段初始化期获取null
  private context?: common.UIAbilityContext;

  async aboutToAppear(): Promise<void> {
    this.isDark = isDarkMode();
    this.loggedIn = AuthManager.getInstance().isLogin();
    // 首帧形态初值（§4.6 H-A 同源）：onAreaChange 只在尺寸变化后触发，冷启动平板横屏若不预置
    // 会出现「先 1 列再跳 3 列」的首帧跳变。取不到就保持 0，由 onAreaChange 兜底。
    try {
      const d = display.getDefaultDisplaySync();
      const w: number = this.getUIContext().px2vp(d.width);
      const h: number = this.getUIContext().px2vp(d.height);
      if (w > 0 && h > 0) {
        this.pageWidth = w;
        this.pageHeight = h;
        this.updateFadeStop(h);
      }
    } catch (e) {
      // 忽略：窗口未 attach 时取宽会失败，onAreaChange 会兜底
    }
    // 「列数调整」档位初值（2026-09-18）：冷启动首帧即按已选档渲染
    // （UsageHabitsManager.init 的 columnModeTick 可能早于本页构造，@Watch 不会补触发，故此处直读）
    this.columnMode = readColumnMode();
    // 无条件写列数标记（单列也写 1），避免跨页残留（§6.1 D1 / D6）
    this.syncCardColumns();
    // WaterFlow 竖屏 3 列 / 横屏 4 列（§4.2 决策 12）：首帧初值 + 监听方向变化
    this.updateColumns();
    display.on('change', this.displayChangeCallback);
    // 若宿主已完成启动引导（token 已置位），直接开跑；否则等 onBootTick
    if ((AppStorage.get<number>('homeBootRequest') ?? 0) > 0) {
      this.startBoot();
    }
  }

  aboutToDisappear(): void {
    display.off('change', this.displayChangeCallback);
  }

  /** darkTick 递增（宿主或子 Tab 页切换深色）→ 重读全局深色状态 */
  private onDarkTick(): void {
    this.isDark = isDarkMode();
  }

  /** fontTick 递增（字号设置页写入 / 宿主 onPageShow 返回广播）→ 显式回写 fontScale
   *  触发本页全部 fs(x, fontScale) 依赖刷新（离屏期间 @StorageLink 同步不重绘的兜底） */
  private onFontTick(): void {
    this.fontScale = AppStorage.get<number>('fontScale') ?? 1.0;
  }

  /**
   * 同步 WaterFlow 数据源（全量替换或尾部追加）。
   * 判定「尾部追加」必须**逐项比对前缀**：只比长度会把「刷新后列表变长」误判成追加，
   * 于是 WaterFlow 只重建尾段、前段仍渲染旧内容（真机表现为刷新后列表内容错乱）。
   */
  private syncSource(ds: ThreadDataSource, next: ThreadItem[]): void {
    const old: ThreadItem[] = ds.data;
    let isAppend: boolean = old.length > 0 && next.length > old.length;
    if (isAppend) {
      for (let i: number = 0; i < old.length; i++) {
        if (next[i].tid !== old[i].tid) {
          isAppend = false;
          break;
        }
      }
    }
    ds.data = next;
    if (isAppend) {
      ds.notifyAdd(old.length);
    } else {
      ds.reload();
    }
  }

  /** threads 变化 → 同步到 WaterFlow 数据源（全量替换或尾部追加） */
  private onThreadsChange(): void {
    this.syncSource(this.recDataSource, this.threads);
  }

  /** folThreads 变化 → 同步到 WaterFlow 数据源（全量替换或尾部追加） */
  private onFolThreadsChange(): void {
    this.syncSource(this.folDataSource, this.folThreads);
  }

  /** 大屏竖 3 / 横 4（§4.2 决策 12）；阔直屏竖 1 / 横 3（阔直屏文档 §4.2，2026-09-17 用户改定）：同步 AppStorage 让 ThreadCard 内部图片封顶/摘要行数跟随 */
  private updateColumns(): void {
    try {
      const d: display.Display = display.getDefaultDisplaySync();
      const w: number = this.getUIContext().px2vp(d.width);
      const h: number = this.getUIContext().px2vp(d.height);
      // 阔直屏不依赖宽度阈值（横屏 ~830 < 840 过不了 md 档），列数只看横竖屏，竖屏回落手机单列档；
      // 大折叠竖 2 / 横 3（2026-09-17 用户改定，与平板同口径）；平板竖 2 / 横 3（原竖 3 / 横 4 作废）
      this.columns = isWideBarDevice() ? (w > h ? 3 : 1)
        : (w > h ? 3 : 2);
      // 经 homeColumns() 的窗口闸门下发（小窗 / 分屏窄窗写 1），不能裸写 this.columns 绕过闸门
      this.syncCardColumns();
    } catch (e) {
      // 窗口未 attach 时取宽高失败，保持默认 3 列
    }
  }

  private displayChangeCallback: (displayId: number) => void = () => {
    this.updateColumns();
  };

  /**
   * 列数：大屏竖屏 3 / 大屏横屏 4（§4.2 决策 12）；阔直屏竖 1 / 横 3（2026-09-17 用户改定）；手机（含横屏 / 分屏 / 自由多窗）与窄窗维持现状单列。
   * 形态闸门必须放首行：只按宽度判会让手机横屏（约 780vp ≥ 600）误命中多列（§6.1 D4）。
   */
  /**
   * 「列数调整」档位变化（个性化页写入 → `columnModeTick` 广播）：
   * 回写本地档位（列数函数随新档返回）→ 重发 cardColumns → 强制回到两条 feed 的列表顶部。
   * 默认档（0）与原自动适配逐像素一致，仅"用户显式选择"后才改变列数。
   */
  private onColumnModeTick(): void {
    this.columnMode = readColumnMode();
    this.syncCardColumns();
    try {
      this.homeScroller.scrollTo({ xOffset: 0, yOffset: 0 });
      this.folScroller.scrollTo({ xOffset: 0, yOffset: 0 });
    } catch (e) {
    }
  }

  private homeColumns(): number {
    // 窗口闸门最前（2026-09-17 小窗 / 分屏适配）：窗口宽 <600（自由多窗小窗 / 分屏窄窗）一律回落
    // 手机单列档——必须放在设备恒值分支（阔直屏 / 大折叠直接 return this.columns）之前，
    // 否则设备恒值分支会绕过宽度兜底（小窗里 display 仍是横屏大屏 → 旧逻辑恒 3 列）
    // 阔直屏全屏白名单（2026-09-18）：Pura X View（VOL-AL00）等阔直屏竖屏全屏窗口宽仅 ~440vp，
    // 会被本闸门误判成小窗；白名单放行（小窗 / 分屏仍拦，见 Theme.isWideBarFullscreen）
    if (this.pageWidth > 0 && this.pageWidth < Breakpoint.sm && !isWideBarFullscreen(this.pageWidth)) {
      return 1;
    }
    // 「列数调整」（2026-09-18，个性化 → 列数调整）：仅大屏形态（平板 / 阔直屏 / 大折叠展开）生效，
    // 窄窗与手机档已由上面的窗口闸门返回不受影响；默认档 ov=0 → 原样走下面自动适配分支（逐像素零回归）
    if (isLargeScreenForm(this.isWideFormDevice)) {
      const ov: number = overrideColumns(this.columnMode, this.pageWidth > this.pageHeight);
      if (ov > 0) {
        return ov;
      }
    }
    // 阔直屏分支紧随其后（竖屏窗口宽 ~500 < 600 已被上面的窗口闸门回落 1 列，语义不变）
    // 阔直屏分支紧随其后：全屏竖屏（窗口宽 ~440 < 600）经上面白名单放行后落到本行，
    // 默认档返回 this.columns（updateColumns 按 display 横竖屏写入：竖 1 / 横 3，与改前同值）；
    // 非全屏的自由小窗 / 分屏仍被闸门回落 1 列，到不了这里
    if (isWideBarDevice()) {
      return this.columns;
    }
    // 大折叠展开态（大折叠文档 §4.2）：竖 2 / 横 3（updateColumns 已按横竖屏写 this.columns），
    // 折叠态为 false 落后续宽度闸门回 1 列
    if (isLargeFoldDevice()) {
      return this.columns;
    }
    if (!this.isWideFormDevice) {
      return 1;
    }
    if (this.pageWidth < Breakpoint.sm) {
      return 1;
    }
    // 2026-09-17 三次拍板：平板**竖屏 2 列**（≥840 竖屏 3 列作废）/ 横屏 3 列——updateColumns 已按
    // display 横竖屏把 3/2 写入 this.columns；小窗 <600 已在首行闸门回落 1 列，不会挤爆
    return this.columns;
  }

  /**
   * 列数标记下发：**无条件写**（单列也写 1）。
   * 该标记是 AppStorage 全局单值、被多页 ThreadCard 共享，只在多列档写会让别的页在单列下
   * 按多列几何渲染（§6.1 D1 / D6：折叠屏展开 → 折叠必须回 1）。
   */
  private syncCardColumns(): void {
    AppStorage.setOrCreate(CARD_COLUMNS_KEY, this.homeColumns());
  }

  /**
   * 列模板：**必须与 homeColumns() 单点同源**（2026-09-17 小窗修复）。
   * WaterFlow 的 columnsTemplate 曾直接绑 this.columns（display 推导值，小窗下恒 3）——
   * 分支入口 `homeColumns() > 1` 放行了中间档（600~840 → 2 列），模板却按 this.columns=3 铺 3 列，
   * 造成「中档小窗还是三列」。列数消费方一律走本函数 / homeColumns()，禁止直绑 this.columns。
   */
  private homeColumnsTemplate(): string {
    const n: number = this.homeColumns();
    return n === 4 ? '1fr 1fr 1fr 1fr' : n === 2 ? '1fr 1fr' : '1fr 1fr 1fr';
  }

  /**
   * 形态变化唯一挂点：只回填状态与列数标记，**不包任何过渡动画**
   * （列数模板不可补间，用 animateTo 包赋值只会让同一事务内其它属性出现「卡片已跳完、底栏还在爬」的错位，§4.6 H-G）。
   */
  private onHomeFormAreaChange(oldValue: Area, newValue: Area): void {
    const w: number = Number(newValue.width);
    const h: number = Number(newValue.height);
    if (w <= 0 || h <= 0) {
      return;
    }
    const widthVp: number = this.getUIContext().px2vp(w);
    const heightVp: number = this.getUIContext().px2vp(h);
    if (widthVp === this.pageWidth && heightVp === this.pageHeight) {
      return;
    }
    this.pageWidth = widthVp;
    this.pageHeight = heightVp;
    this.updateFadeStop(heightVp);
    this.syncCardColumns();
  }

  /**
   * 渐隐停靠点：视口高 × 0.15 夹取到 [HOME_FADE_MIN, HOME_FADE_MAX] 后折算百分比。
   * 平板收窄（2026-09-13 用户反馈）：平板竖屏下 15% 渐显覆盖到第一个卡片用户名位置，
   * 要求「只覆盖顶部按钮与标题」→ 平板档 raw 直接取顶栏高度 HOME_TITLE_BAR_HEIGHT(108)；
   * 手机维持原公式（夹取后 108~180 不变）。
   */
  private updateFadeStop(viewportHeightVp: number): void {
    if (viewportHeightVp <= 0) {
      return;
    }
    const raw: number = this.isWideFormDevice ? HOME_TITLE_BAR_HEIGHT : viewportHeightVp * 0.15;
    const clamped: number = Math.min(Math.max(raw, HOME_FADE_MIN), HOME_FADE_MAX);
    this.fadeStop = clamped / viewportHeightVp;
  }

  /** 宿主 aboutToAppear 各 Manager init + 登录态就绪后通知：冷启动加载（缓存直出，不做后台刷新） */
  private onBootTick(): void {
    this.startBoot();
  }

  private startBoot(): void {
    if (this.bootStarted) {
      return;
    }
    this.bootStarted = true;
    this.loggedIn = AuthManager.getInstance().isLogin();
    this.isDark = isDarkMode();
    // 「仅关注吧」聚合时间线引擎：注入单吧拉取器（8 条/页 + 4s 超时）并恢复持久化三件套
    // （游标/池/已消费，跨重启接着上次的供给位置；CacheManager 已在宿主 initApp 初始化）
    this.followFeed.setFetcher((name: string, sortType: number, page: number): Promise<ThreadItem[]> => {
      return this.withFeedTimeout(this.fetchForumFeedOnce(name, 8, sortType, page), 4000);
    });
    this.followFeed.load().catch((_e: Error): void => {});
    // 冷启动不自动刷新：有缓存直接展示（silentOnCache=false），无缓存时兜底走一次网络
    const homeLoad = this.loadHomeThreads(false, false);
    homeLoad.then(() => {
      // 首页加载（缓存直出或网络兜底）完成后标记初始化完成：
      // 此后 homeOnlyFollow 变化（仅用户手动切开关）才触发 onHomeOnlyFollowChanged 强制刷新
      this.homeInitDone = true;
    });
  }

  /** 登录/登出/换号（tabLoginRefresh 递增）：失效账号级缓存并重同步登录态。
   *  注意与旧内联实现一致：只置失效标志/清账号隔离数据，不主动重拉——由后续进入/切 feed 触发 */
  private onLoginTick(): void {
    this.loggedIn = AuthManager.getInstance().isLogin();
    // 登录账号变化：关注吧集合失效（仅推荐关注的吧 需按新账号重新拉取）
    this.followForumNamesLoaded = false;
    // 换号：引擎三件套（游标/池/已消费）全清落盘，下个账号从零供给
    this.followFeed.resetAll().catch((_e: Error): void => {});
    // 会话级去重（正常模式）一并清空
    this.clearSessionDedup();
    // 关注动态按账号隔离：换号/登出后失效，下次进入重新拉取，避免展示上一账号的关注帖
    this.folFeedLoaded = false;
    this.folThreads = [];
    this.folAll = [];
    this.folScrollY = 0;
    // 推荐流「仅关注吧」过滤依赖账号关注集合：同样失效，切回推荐页时按新账号重新加载
    this.recommendLoaded = false;
  }

  /** 宿主 onPageShow：从详情页返回时用实时昵称回填当前列表（不重新请求网络） */
  private onPageTick(): void {
    this.refreshAuthorsFromCache();
  }

  /** 宿主底栏重复点击首页 Tab：整页刷新（按当前 feed 重拉第一页，与下拉刷新同一路径） */
  private onRetapTick(): void {
    this.reloadHomeFromTab();
  }

  /**
   * 安全获取 UIAbilityContext：优先使用已缓存this.context；兜底现场获取
   */
  private getUIAbilityContext(): common.UIAbilityContext {
    if (this.context) {
      return this.context;
    }
    const liveCtx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (liveCtx) {
      this.context = liveCtx;
    }
    return liveCtx;
  }

  /**
   * 首页帖子分享：鸿蒙官方Share Kit系统分享面板（参考CSDN Share Kit宿主应用发起分享）
   * 主路径：@kit.ShareKit → systemShare.SharedData(general.link) + ShareController.show()
   * 兜底：若ShareKit不可用/分享面板拉起失败，自动降级为写入系统剪贴板，提示用户手动粘贴
   * 排障：最外层try/catch捕获所有异常→Toast显式反馈，避免用户感觉"点了没反应"
   */
  private shareThread(data: ThreadSharePayload): void {
    try {
      if (!data || data.tid.length === 0) {
        this.getUIContext().getPromptAction().showToast({ message: '帖子信息缺失，无法分享' });
        return;
      }
      const threadUrl: string = `https://tieba.baidu.com/p/${data.tid}`;
      const titleLine: string =
        data.forumName.length > 0 ? `[${data.forumName}] ${data.title}` : data.title;
      const rawAbstract: string = data.abstract ?? '';
      const descriptionText: string =
        rawAbstract.length > 0
          ? (rawAbstract.length > 140 ? `${rawAbstract.substring(0, 140)}…` : rawAbstract)
          : '';
      const fullText: string =
        descriptionText.length > 0
          ? `${titleLine}\n${descriptionText}\n${threadUrl}`
          : `${titleLine}\n${threadUrl}`;
      const abilityCtx: common.UIAbilityContext = this.getUIAbilityContext();
      if (!abilityCtx) {
        // Context拿不到：直接兜底剪贴板
        this.getUIContext().getPromptAction().showToast({ message: '系统分享不可用，正在复制链接' });
        this.copyShareToClipboard(fullText, titleLine, threadUrl);
        return;
      }

      // ========== 主路径：Share Kit 系统分享面板 ==========
      try {
        // ★ 官方Codelabs L426-438 纯链接分享：utd.UniformDataType.HYPERLINK + content字段（图片才用uri+fileUri）
        const sharedData: systemShare.SharedData = new systemShare.SharedData({
          utd: utd.UniformDataType.HYPERLINK,
          content: threadUrl,
          title: titleLine,
          description: descriptionText
        });
        const controller: systemShare.ShareController = new systemShare.ShareController(sharedData);
        // ★ 官方Codelabs关键修正：controller.show()返回Promise，必须单独.catch()才能捕获异步错误
        controller.show(abilityCtx, {
          previewMode: systemShare.SharePreviewMode.DETAIL,
          selectionMode: systemShare.SelectionMode.SINGLE
        }).then(() => {
          // Promise.resolve = 系统分享面板已成功拉起（用户可能取消/成功，都算面板弹了）
          this.getUIContext().getPromptAction().showToast({ message: '系统分享面板已弹出' });
        }).catch((showErr: BusinessError) => {
          // Promise异步reject：这里是面板拉起失败（权限/UTD不支持/其他），把code+msg全量Toast便于定位
          const code = showErr?.code ?? 'unknown';
          const msg = showErr?.message ?? String(showErr);
          this.getUIContext().getPromptAction().showToast({
            message: `分享面板失败[${code}]：${msg}`
          });
          this.copyShareToClipboard(fullText, titleLine, threadUrl);
        });
        return;
      } catch (shareErr) {
        this.getUIContext().getPromptAction().showToast({ message: '系统分享不可用，正在复制链接' });
        this.copyShareToClipboard(fullText, titleLine, threadUrl);
      }
    } catch (outerErr) {
      // 全局兜底：任何异常都弹Toast，避免用户感觉点了没反应
      const errMsg: string = outerErr instanceof Error ? outerErr.message : String(outerErr);
      this.getUIContext().getPromptAction().showToast({ message: `分享异常：${errMsg}` });
    }
  }

  /**
   * 兜底：写入系统剪贴板，保证分享失败时用户仍可粘贴发送（pasteboard @kit.BasicServicesKit）
   * 任何内部异常都会被外层shareThread捕获弹Toast，避免二次静默失败
   */
  private copyShareToClipboard(fullText: string, title: string, url: string): void {
    try {
      const sysPasteboard = pasteboard.getSystemPasteboard();
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, fullText);
      sysPasteboard.setData(pasteData, (err: BusinessError | undefined) => {
        if (err) {
          this.getUIContext().getPromptAction().showToast({
            message: `复制失败：${err.message || String(err)}`
          });
        } else {
          this.getUIContext().getPromptAction().showToast({
            message: `已复制「${title}」链接，粘贴即可分享`
          });
        }
      });
    } catch (clipboardErr) {
      const errMsg: string = clipboardErr instanceof Error ? clipboardErr.message : String(clipboardErr);
      this.getUIContext().getPromptAction().showToast({
        message: `剪贴板不可用：${errMsg}；帖子链接：${url}`
      });
    }
  }

  /** 用详情页回填的作者昵称缓存刷新列表显示（不重新请求网络） */
  private refreshAuthorsFromCache(): void {
    const service = TiebaService.getInstance();
    let changed = false;
    this.updateCurrentThreads(this.currentFeedThreads().map((t: ThreadItem): ThreadItem => {
      if (t.authorId !== undefined && t.authorId.length > 0) {
        const cachedName: string | undefined = service.getCachedAuthorName(t.authorId);
        if (cachedName !== undefined && cachedName.length > 0 && cachedName !== t.author) {
          changed = true;
          return {
            tid: t.tid, postId: t.postId, forumId: t.forumId, title: t.title, forumName: t.forumName,
            forumAvatar: t.forumAvatar, author: cachedName, authorId: t.authorId, authorAvatar: t.authorAvatar,
            authorNameShowMissing: t.authorNameShowMissing,
            replyNum: t.replyNum, likeCount: t.likeCount, isLiked: t.isLiked, abstract: t.abstract,
            firstImage: t.firstImage, images: t.images, createTime: t.createTime, isTop: t.isTop,
            isGood: t.isGood, isFeatured: t.isFeatured
          } as ThreadItem;
        }
      }
      return t;
    }));
    if (changed) {
      console.info('[AUTHORDIAG] 首页列表已用详情页昵称回填刷新');
    }
  }

  /** 「仅推荐关注的吧」是否生效：已登录且开关开启 */
  private shouldOnlyFollow(): boolean {
    return this.loggedIn && this.homeOnlyFollow;
  }

  /** 单个吧的一次补采请求：显式传 sort_type/页码（双槽采样用）；缺省时随机（0 最近回复 / 1 最新发帖、页码 1/2），失败静默跳过 */
  private async fetchForumFeedOnce(forumName: string, limit: number, sortType?: number, page?: number): Promise<ThreadItem[]> {
    try {
      const st: number = sortType !== undefined ? sortType : (Math.random() < 0.5 ? 0 : 1);
      const pg: number = page !== undefined ? page : (Math.random() < 0.5 ? 1 : 2);
      const r: PagedResult<ThreadItem> = await TiebaService.getInstance().fetchForumThreads(forumName, pg, st, false);
      return r.list.slice(0, limit);
    } catch (e) {
      return [];
    }
  }

  /** ① 会话级去重登记：把已写入列表的 tid 记入 shownTids（FIFO 封顶 1000） */
  private rememberShown(list: ThreadItem[]): void {
    for (const t of list) {
      if (t.tid.length > 0 && !this.shownTids.has(t.tid)) {
        this.shownTids.add(t.tid);
        this.shownTidsQueue.push(t.tid);
      }
    }
    while (this.shownTidsQueue.length > 1000) {
      const oldest: string | undefined = this.shownTidsQueue.shift();
      if (oldest !== undefined) {
        this.shownTids.delete(oldest);
      }
    }
  }

  /** ① 会话级去重清空：仅换号时调用（正常模式 shownTids；仅关注模式的引擎三件套走 resetAll） */
  private clearSessionDedup(): void {
    this.shownTids.clear();
    this.shownTidsQueue = [];
  }

  /** ⑤ 渲染前兜底去重：同 tid 只保留首个出现（防任何上游路径漏去重，成本 O(n)） */
  private dedupeByTid(list: ThreadItem[]): ThreadItem[] {
    const seen: Set<string> = new Set<string>();
    const out: ThreadItem[] = [];
    for (const t of list) {
      if (t.tid.length > 0) {
        if (seen.has(t.tid)) {
          continue;
        }
        seen.add(t.tid);
      }
      out.push(t);
    }
    return out;
  }

  /**
   * 「仅关注吧」聚合时间线引擎就绪：持久化恢复（幂等）+ 关注吧集合注入。
   * 未登录/无关注吧返回 false（调用方退化为推荐流过滤路径）。
   */
  private async ensureFollowEngine(): Promise<boolean> {
    await this.followFeed.load();
    const sets: FollowSets | null = await this.getFollowSets();
    if (sets === null || sets.names.size === 0) {
      return false;
    }
    this.followFeed.setBars(sets.names);
    return true;
  }

  /**
   * 水位线补货：池低于低位线时后台拉到高位线（不阻塞调用方，结果由下次出池消费）。
   * 引擎内部有零进度熔断与并发锁，重复触发安全。
   */
  private kickPoolRefill(): void {
    if (!this.shouldOnlyFollow() || !this.followFeed.poolLow()) {
      return;
    }
    this.ensureFollowEngine().then((ok: boolean): Promise<void> => {
      if (!ok) {
        return Promise.resolve();
      }
      return this.followFeed.refill(POOL_HIGH);
    }).catch((_e: Error): void => {
      // 补货失败静默：下次出池/触底会再触发
    });
  }

  /** 补采限时包装：最坏 ms 毫秒内返回（超时按空处理，避免个别吧挂起拖慢首屏/翻页） */
  private async withFeedTimeout(p: Promise<ThreadItem[]>, ms: number): Promise<ThreadItem[]> {
    let settled: boolean = false;
    return await new Promise<ThreadItem[]>((resolve) => {
      const timer: number = setTimeout(() => {
        if (!settled) {
          settled = true;
          resolve([]);
        }
      }, ms);
      p.then((v: ThreadItem[]) => {
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          resolve(v);
        }
      }).catch(() => {
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          resolve([]);
        }
      });
    });
  }

  /** 单页关注列表请求 + 失败重试一次（避免单页抖动静默丢掉 50 个吧） */
  private async fetchFollowPageOnce(page: number): Promise<PagedResult<FollowItem>> {
    try {
      return await TiebaService.getInstance().fetchFollowList(page);
    } catch (e) {
      try {
        return await TiebaService.getInstance().fetchFollowList(page);
      } catch (e2) {
        return { list: [], hasMore: false, page };
      }
    }
  }

  /**
   * 拉取关注吧 ID / 吧名集合（会话内缓存；失败返回 null 表示"未知"，调用方退化为正常推荐避免空白）。
   * 全量翻页：每轮 4 页并发、翻到 hasMore=false 为止，上限 10 页（500 个吧）防极端账号无限翻；
   * 任一页拿到过数据即算成功，全页皆败返回 null。
   * 注：现代 API 推荐流 forumName 取自 fname/forum_name，关注列表取自 forum.name，字段不同源，
   * 吧名字符串匹配常常全空——必须用 forumId（数字 ID 跨接口稳定）作为主匹配键，吧名仅作 forumId 缺失时的兜底。
   */
  private async getFollowSets(): Promise<FollowSets | null> {
    if (this.followForumNamesLoaded) {
      return { ids: this.followForumIds, names: this.followForumNames };
    }
    const ids: Set<string> = new Set<string>();
    const names: Set<string> = new Set<string>();
    try {
      const maxPage: number = 10;   // 上限 10 页 × 50 = 500 个吧
      const batch: number = 4;      // 每轮并发 4 页
      let pn: number = 1;
      let hasMore: boolean = true;
      let gotAny: boolean = false;
      while (pn <= maxPage && hasMore) {
        const pageNums: number[] = [];
        for (let i: number = 0; i < batch && pn <= maxPage; i++) {
          pageNums.push(pn);
          pn++;
        }
        const results: PagedResult<FollowItem>[] = await Promise.all(pageNums.map((p: number): Promise<PagedResult<FollowItem>> =>
          this.fetchFollowPageOnce(p)));
        for (const r of results) {
          if (r.list.length > 0) {
            gotAny = true;
          }
          for (const f of r.list) {
            if (f.forumId && f.forumId.length > 0) {
              ids.add(f.forumId);
            }
            if (f.forumName && f.forumName.length > 0) {
              names.add(f.forumName);
            }
          }
        }
        if (!gotAny) {
          break;
        }
        // 本轮所有页均未报 hasMore → 到底
        let anyMore: boolean = false;
        for (const r of results) {
          if (r.hasMore) {
            anyMore = true;
          }
        }
        hasMore = anyMore;
      }
      if (!gotAny) {
        // 全页皆败：视为"未知"，调用方退化正常推荐，下次触发重试
        return null;
      }
      this.followForumIds = ids;
      this.followForumNames = names;
      this.followForumNamesLoaded = true;
      return { ids, names };
    } catch (e) {
      // 拉取失败：本次不过滤（保持正常推荐），下次触发时重试
      return null;
    }
  }

  /**
   * 首页推荐页获取统一入口：
   * - 正常模式：单页请求（15 条），保持原有行为
   * - 仅关注吧模式：单次放大条数 + 按关注吧名/ID过滤，不足目标数量时继续翻页补齐；
   *   收集阶段同时排除会话级 shownTids（已看过的不再进列表，刷新出来的全是真新内容），
   *   返回 page 为最后实际请求到的页码（供加载更多续接）。
   */
  private async fetchHomePage(page: number): Promise<PagedResult<ThreadItem>> {
    if (!this.shouldOnlyFollow()) {
      return TiebaService.getInstance().fetchHomeThreads(page, false);
    }
    const sets: FollowSets | null = await this.getFollowSets();
    if (sets === null || (sets.ids.size === 0 && sets.names.size === 0)) {
      // 关注列表不可用：退化为正常推荐，避免首页空白
      return TiebaService.getInstance().fetchHomeThreads(page, false);
    }
    const targetCount: number = 20;   // 目标条数：仅关注吧模式一屏 20 条
    const pageCount: number = 60;     // 单次放大请求条数，减少翻页次数
    const maxPages: number = 5;       // 兜底上限：最多连续请求页数，避免极端情况下长时间加载
    const collected: ThreadItem[] = [];
    const seen: Set<string> = new Set<string>();
    let p: number = page;
    let hasMore: boolean = true;
    let lastReqPage: number = page;
    // 首批 2 页并发（大幅缩短首轮等待；60 条×2 通常已足够过滤出目标条数），不足时后续单页串行补齐
    let batch: number = 2;
    while (p < page + maxPages) {
      const pageNums: number[] = [];
      for (let i: number = 0; i < batch && p < page + maxPages; i++) {
        pageNums.push(p);
        p++;
      }
      const results: PagedResult<ThreadItem>[] = await Promise.all(pageNums.map((pn: number): Promise<PagedResult<ThreadItem>> =>
        TiebaService.getInstance().fetchHomeThreads(pn, false, pageCount)));
      for (let i: number = 0; i < results.length; i++) {
        const result: PagedResult<ThreadItem> = results[i];
        lastReqPage = pageNums[i];
        hasMore = result.hasMore;
        if (result.list.length === 0) {
          return { list: collected, hasMore, page: lastReqPage };
        }
        for (const item of result.list) {
          if (!seen.has(item.tid) && !this.shownTids.has(item.tid)
            && !(this.shouldOnlyFollow() && this.followFeed.hasConsumed(item.tid))) {
            seen.add(item.tid);
            // 优先按 forumId 匹配（跨接口稳定）；仅在 forumId 缺失时回退到吧名匹配
            const hit: boolean = (item.forumId !== undefined && item.forumId.length > 0 && sets.ids.has(item.forumId))
              || ((item.forumId === undefined || item.forumId.length === 0) && sets.names.has(item.forumName));
            if (hit) {
              collected.push(item);
            }
          }
        }
        if (!hasMore || collected.length >= targetCount) {
          return { list: collected, hasMore, page: lastReqPage };
        }
      }
      batch = 1;
    }
    return { list: collected, hasMore, page: lastReqPage };
  }

  /** 开关变化：清关注集合缓存；若停留在推荐页则立即重新加载 */
  private onHomeOnlyFollowChanged(): void {
    // 冷启动阶段由 UsageHabitsManager.init 恢复开关状态触发（首页加载尚未执行）：
    // 跳过强制刷新，首页由 startBoot 的 loadHomeThreads(false,false) 走缓存直出
    if (!this.homeInitDone) {
      return;
    }
    // 推荐流数据源已变化：切回推荐页时需重新加载（正停留在推荐页时下面立即重载）
    this.recommendLoaded = false;
    this.followForumNamesLoaded = false;
    // 切开关只换过滤口径，不清任何去重状态（shownTids/引擎池与已消费均保留）——
    // 看过的就是看过的，切换后不应把刚刷过的帖当"新内容"再推一遍
    if (this.homeFeed === HomeFeed.Recommended) {
      this.homePage = 1;
      this.homeHasMore = true;
      this.homeStalledPages = 0;
      if (this.threads.length === 0) {
        this.loadState = LoadState.Loading;
      }
      this.loadHomeThreads(true);
    }
  }

  /**
   * 首页推荐流加载：
   * - 有缓存（含过期，stale-while-revalidate）→ 立即显示秒开；silentOnCache=true 时后台静默刷新
   * - 无缓存 → 网络请求后立即渲染，昵称校准后台执行，不阻塞首屏
   * forceRefresh=true（下拉刷新）跳过缓存直连网络。
   * silentOnCache=false（冷启动）仅展示缓存，不自动刷新；数据新鲜度由用户主动下拉/切 tab 保证。
   * 「仅推荐关注的吧」开启时同样缓存直出：缓存即上次过滤加载的结果，冷启动直接展示，主动刷新才重新过滤加载。
   */
  async loadHomeThreads(forceRefresh: boolean = false, silentOnCache: boolean = true): Promise<void> {
    if (this.homeRefreshing) {
      return;
    }
    this.homeRefreshing = true;
    // 请求代际递增：使 in-flight 的预加载/加载更多结果作废，避免 concat 到刷新后的新列表
    this.homeLoadToken++;
    this.homePage = 1;
    this.homeHasMore = true;
    this.homeStalledPages = 0;
    // 「仅关注吧」刷新语义：不清任何去重状态（引擎游标/池/已消费跨刷新保留），
    // 刷新只是重新取一批"已消费之外"的内容；全清仅发生在换号（onLoginTick）。
    // 仅在当前列表为空时切骨架屏（首次加载/切换 feed）；已有内容刷新时保留列表原地更新，避免闪屏
    if (this.threads.length === 0) {
      this.loadState = LoadState.Loading;
    }
    try {
      if (!forceRefresh) {
        // 方案B：过期缓存也先显示，冷启动同样秒开；冷启动不再后台刷新，等用户主动操作
        // 仅关注模式同样缓存直出（缓存内容即上次过滤加载的结果），避免冷启动重复网络加载
        const cached = await CacheManager.getInstance().getWithTtlAllowStale<ThreadItem[]>(CACHE_KEY.THREAD_LIST);
        if (cached && cached.data.length > 0) {
          // 缓存直出的内容同样登记进会话级去重（后续翻页不再重复这些 tid）
          this.rememberShown(cached.data);
          this.threads = cached.data;
          this.loadState = LoadState.Success;
          this.recommendLoaded = true;
          this.homeRefreshing = false;
          if (this.shouldOnlyFollow()) {
            this.followFeed.markConsumed(cached.data);
            this.kickPoolRefill();
          }
          if (silentOnCache) {
            this.refreshHomeSilently();
          }
          return;
        }
      }
      // 方案A：请求 + 立即渲染，昵称校准后台执行不阻塞首屏；8s 刷新超时兜底，弱网/接口挂起不无限转圈
      const result = await this.withFeedRefreshTimeout(this.fetchHomePage(1));
      let list: ThreadItem[] = result.list;
      if (this.shouldOnlyFollow()) {
        // 聚合时间线：推荐流过滤做首屏加速，不足一屏从待展示池出补齐（确定性时间降序）；
        // 首屏与池全空时同步等一轮补货（引擎内部零进度熔断，不会长时间挂起）
        const engineReady: boolean = await this.ensureFollowEngine();
        if (engineReady && list.length < 20) {
          if (list.length === 0 && this.followFeed.poolSize() === 0) {
            await this.followFeed.refill(POOL_HIGH);
          }
          const fromPool: ThreadItem[] = this.followFeed.take(20 - list.length);
          if (fromPool.length > 0) {
            for (const it of fromPool) {
              list.push(it);
            }
            list = sortThreadsByTimeDesc(list);
          }
        }
      }
      // ⑤ 渲染前兜底去重 + 去重登记（池补齐已合并进 list，统一在此收口）
      this.threads = this.dedupeByTid(list);
      this.rememberShown(this.threads);
      if (this.shouldOnlyFollow()) {
        this.followFeed.markConsumed(this.threads);
      }
      this.recommendLoaded = true;
      this.homePage = result.page;
      this.homeHasMore = list.length > 0;
      // 不再因"不足一屏"硬性禁止加载更多：交给 homeStalledPages 连续空轮保护，
      // 引擎游标可在补货时继续翻出库存
      this.homeStalledPages = 0;
      this.loadState = list.length > 0 ? LoadState.Success : LoadState.Empty;
      if (list.length > 0) {
        this.enrichHomeInBackground(list);
        await CacheManager.getInstance().putWithTtl(CACHE_KEY.THREAD_LIST, list, CACHE_TTL.THREAD_LIST);
      }
      this.kickPoolRefill();
    } catch (e) {
      if (this.threads.length === 0) {
        this.loadState = LoadState.Error;
        this.errorMsg = (e as Error).message ?? '推荐内容加载失败';
      } else {
        // 刷新超时/失败：保留旧内容，仅提示（下拉刷新/整页刷新场景）
        this.getUIContext().getPromptAction().showToast({ message: '刷新失败，已展示上次内容' });
      }
    } finally {
      this.homeRefreshing = false;
    }
  }

  /** 缓存命中后的后台静默刷新：更新列表并回写缓存，失败保留缓存内容。
   *  仅关注吧模式下收集阶段已排除 shownTids/引擎已消费（缓存内容在列），
   *  不足一屏从待展示池出补齐，池低水位触发后台补货。 */
  private async refreshHomeSilently(): Promise<void> {
    try {
      const result = await this.fetchHomePage(1);
      let list: ThreadItem[] = result.list;
      if (this.shouldOnlyFollow()) {
        const engineReady: boolean = await this.ensureFollowEngine();
        if (engineReady && list.length < 20) {
          const fromPool: ThreadItem[] = this.followFeed.take(20 - list.length);
          if (fromPool.length > 0) {
            for (const it of fromPool) {
              list.push(it);
            }
            list = sortThreadsByTimeDesc(list);
          }
        }
        this.kickPoolRefill();
      }
      if (list.length === 0) {
        return;
      }
      this.homePage = result.page;
      this.threads = this.dedupeByTid(list);
      this.rememberShown(this.threads);
      if (this.shouldOnlyFollow()) {
        this.followFeed.markConsumed(this.threads);
      }
      this.homeHasMore = this.threads.length > 0;
      this.homeStalledPages = 0;
      this.enrichHomeInBackground(this.threads);
      CacheManager.getInstance().putWithTtl(CACHE_KEY.THREAD_LIST, this.threads, CACHE_TTL.THREAD_LIST);
    } catch (e) {
      // 静默刷新失败保留缓存内容展示，仅记录日志
      console.info(`[HomeTab] home silent refresh fail: ${(e as Error).message}`);
    }
  }

  /** 占位名判断：吧友XXXX / 贴吧用户_xxx / 贴吧用户（推荐页 JSON 缺 name_show 时的兜底名） */
  private isPlaceholderAuthorName(name: string | undefined): boolean {
    if (name === undefined || name.length === 0) {
      return false;
    }
    return name === '贴吧用户' || name.startsWith('贴吧用户_') || name.startsWith('吧友');
  }

  /**
   * 首页昵称后台校准：拉取 profile 后按 authorId diff 局部替换，不阻塞首屏。
   * v1.22 首轮校准后若仍有占位名作者（profile 超时/风控/瞬时失败，且 enrich 只在重新
   * 拉列表时触发），延迟补校准，覆盖用户停留在页面期间自动补齐，最终与详情页/个人信息页一致。
   */
  private enrichHomeInBackground(list: ThreadItem[]): void {
    TiebaService.getInstance().enrichHomeAuthors(list).then((enriched: ThreadItem[]) => {
      this.applyEnrichedAuthors(enriched);
      this.scheduleHomeAuthorReEnrich();
    }).catch((_: Error) => {
      // 校准失败保留接口昵称，不影响列表展示
    });
  }

  /** 补校准轮询：仅当当前列表仍有占位名作者时，间隔 4s 再补一轮，最多补 3 轮 */
  private scheduleHomeAuthorReEnrich(): void {
    if (this.homeReEnrichAttempts >= 3) {
      return;
    }
    const hasPlaceholder: boolean = this.currentFeedThreads().some((t: ThreadItem): boolean =>
      (t.authorId !== undefined && t.authorId.length > 0) && this.isPlaceholderAuthorName(t.author));
    if (!hasPlaceholder) {
      return;
    }
    const snapshot: ThreadItem[] = this.currentFeedThreads();
    this.homeReEnrichAttempts += 1;
    setTimeout(() => {
      TiebaService.getInstance().enrichHomeAuthors(snapshot).then((enriched: ThreadItem[]) => {
        this.applyEnrichedAuthors(enriched);
        this.scheduleHomeAuthorReEnrich();
      }).catch((_: Error) => {
        // 补校准失败，等待下一轮 / 用户手动刷新
      });
    }, 4000);
  }

  /** 将校准结果按 authorId diff 更新到当前列表（兼容校准期间已加载更多） */
  private applyEnrichedAuthors(enriched: ThreadItem[]): void {
    const nameMap: Map<string, string> = new Map<string, string>();
    for (const e of enriched) {
      const id: string = `${e.authorId ?? ''}`;
      if (id.length > 0 && e.author.length > 0) {
        nameMap.set(id, e.author);
      }
    }
    if (nameMap.size === 0) {
      return;
    }
    let changed: boolean = false;
    const updated: ThreadItem[] = this.currentFeedThreads().map((t: ThreadItem): ThreadItem => {
      const id: string = `${t.authorId ?? ''}`;
      const nick: string | undefined = nameMap.get(id);
      if (nick !== undefined && nick.length > 0 && nick !== t.author) {
        changed = true;
        return {
          tid: t.tid, postId: t.postId, forumId: t.forumId, title: t.title, forumName: t.forumName,
          forumAvatar: t.forumAvatar, author: nick, authorId: t.authorId, authorAvatar: t.authorAvatar,
          authorNameShowMissing: t.authorNameShowMissing,
          replyNum: t.replyNum, likeCount: t.likeCount, isLiked: t.isLiked, abstract: t.abstract,
          firstImage: t.firstImage, images: t.images, createTime: t.createTime, isTop: t.isTop,
          isGood: t.isGood, isFeatured: t.isFeatured
        } as ThreadItem;
      }
      return t;
    });
    if (changed) {
      this.updateCurrentThreads(updated);
    }
  }

  async loadMoreHomeThreads(silent: boolean = false): Promise<void> {
    if (this.homeLoadingMore || !this.homeHasMore || this.threads.length === 0) {
      return;
    }
    this.homeLoadingMore = true;
    // 记录当前代际：返回时若已刷新/切feed则丢弃结果
    const myToken: number = this.homeLoadToken;
    try {
      // ③ 排除集从"当前屏"扩到"本会话"：shownTids 全量 + 当前列表兜底（防个别写路径漏登记）
      const exclude: Set<string> = new Set<string>();
      for (const t of this.shownTids) {
        exclude.add(t);
      }
      for (const item of this.threads) {
        exclude.add(item.tid);
      }
      let appended: ThreadItem[] = [];
      if (this.shouldOnlyFollow()) {
        // 仅关注吧模式：加载更多 = 从待展示池纯出（池进池出已单点去重）；
        // 池空时同步等一轮补货，仍空则交给空轮保护（stalledPages）停住
        const engineReady: boolean = await this.ensureFollowEngine();
        if (engineReady && this.followFeed.poolSize() === 0) {
          await this.followFeed.refill(POOL_HIGH);
        }
        if (myToken !== this.homeLoadToken) {
          return;
        }
        if (engineReady) {
          appended = this.followFeed.take(20);
        }
      } else {
        const nextPage = this.homePage + 1;
        const result = await this.fetchHomePage(nextPage);
        if (myToken !== this.homeLoadToken) {
          return;
        }
        for (const item of result.list) {
          if (!exclude.has(item.tid)) {
            exclude.add(item.tid);
            appended.push(item);
          }
        }
        // 更新为最后实际请求到的页码（仅关注吧模式不依赖翻页，此处仅正常模式推进）
        this.homePage = result.page;
      }
      if (appended.length > 0) {
        this.rememberShown(appended);
        if (this.shouldOnlyFollow()) {
          // 出池即消费（take 内已登记，此处兜底补登记当前屏可见项）
          this.followFeed.markConsumed(appended);
        }
        this.threads = this.threads.concat(appended);
        this.homeStalledPages = 0;
        // 新增项的昵称后台校准，不阻塞翻页
        this.enrichHomeInBackground(appended);
        await CacheManager.getInstance().putWithTtl(CACHE_KEY.THREAD_LIST, this.threads, CACHE_TTL.THREAD_LIST);
      } else {
        // 补货/翻页均无新内容：只允许少量连续空轮，随后保护性停止，
        // 避免无限请求（正常模式可能返回重复页；仅关注吧模式可能关注吧帖子已枯竭）。
        this.homeStalledPages += 1;
      }
      if (this.shouldOnlyFollow()) {
        this.kickPoolRefill();
      }
      this.homeHasMore = this.homeStalledPages < 3;
    } catch (e) {
      // 预加载失败静默忽略，靠 onReachEnd 兜底重试；仅用户主动触底时提示
      if (!silent) {
        this.getUIContext().getPromptAction().showToast({ message: '加载更多失败，请稍后重试' });
      }
    } finally {
      this.homeLoadingMore = false;
    }
  }

  /** 当前激活 feed 的列表数据源（点赞/昵称回填等就地更新用） */
  private currentFeedThreads(): ThreadItem[] {
    return this.homeFeed === HomeFeed.Following ? this.folThreads : this.threads;
  }

  /** 将更新后的列表写回当前激活 feed 的数据源 */
  private updateCurrentThreads(updated: ThreadItem[]): void {
    if (this.homeFeed === HomeFeed.Following) {
      this.folThreads = updated;
    } else {
      this.threads = updated;
    }
  }

  /** v1.17 首页推荐/关注动态左右滑动转场（同收藏页分类 Tab 范式）：dir=-1 左侧页（推荐），dir=1 右侧页（关注动态）。
   *  进出都从/向本侧平移，切换时旧视图滑出 + 新视图滑入，效果等同底部 Tab 的"推开"。
   *  不加透明度，避免两页交错时透出背景显得生硬；两页互推更贴近原生分段切换。 */
  private feedTabTransition(dir: number): TransitionEffect {
    const x: string = dir < 0 ? '-100%' : '100%';
    return TransitionEffect.asymmetric(
      // 出现：从本侧滑入
      TransitionEffect.translate({ x: x })
        .animation({ duration: 300, curve: Curve.EaseOut }),
      // 消失：向本侧滑出
      TransitionEffect.translate({ x: x })
        .animation({ duration: 280, curve: Curve.EaseInOut })
    );
  }

  private selectHomeFeed(feed: HomeFeed): void {
    // 切走前记录当前 feed 浏览位置（数据各自常驻，无需另存内容）
    if (this.homeFeed === HomeFeed.Following) {
      this.folScrollY = this.homeScrollY;
    } else if (this.homeFeed === HomeFeed.Recommended) {
      this.recommendScrollY = this.homeScrollY;
    }
    const targetState: LoadState = feed === HomeFeed.Following ? this.folState : this.loadState;
    if (this.homeFeed === feed && targetState !== LoadState.Error) {
      return;
    }
    if (feed === HomeFeed.Following && !this.loggedIn) {
      this.openLogin();
      return;
    }
    // 左右滑动转场：置位切换动画状态（旧视图滑出 / 新视图滑入），动画期间锁防重复触发
    this.homeFeedSwitching = true;
    this.firstHomeMount = false;
    this.homeFeed = feed;
    this.errorMsg = '';
    if (feed === HomeFeed.Recommended) {
      if (this.recommendLoaded) {
        // 已加载过：不重新拉取，直接恢复常驻内容与上次浏览位置（与关注动态一致）
        this.restoreHomeScroll();
      } else {
        // 首次进入或数据源已失效（换号/「仅关注吧」开关变化）：加载第一页（缓存秒开）
        this.loadHomeThreads();
      }
    } else if (this.folFeedLoaded) {
      // 已加载过：不重新拉取，直接恢复常驻内容与浏览位置（关注动态内容随会话保留）
      this.restoreHomeScroll();
    } else {
      // 冷启动首次进入：自动加载
      this.loadFollowingThreads();
    }
    // 外层滑动转场结束后复位切换锁（时长取转场 300ms 上限 + 余量）
    setTimeout(() => { this.homeFeedSwitching = false; }, 400);
  }

  /** 切回已加载 feed 时恢复上次浏览位置（内容渲染完成后再定位） */
  private restoreHomeScroll(): void {
    const targetY: number = this.homeFeed === HomeFeed.Following ? this.folScrollY : this.recommendScrollY;
    if (targetY <= 0) {
      return;
    }
    const scroller: Scroller = this.homeFeed === HomeFeed.Following ? this.folScroller : this.homeScroller;
    const feed: HomeFeed = this.homeFeed;
    const feedState: LoadState = feed === HomeFeed.Following ? this.folState : this.loadState;
    setTimeout(() => {
      if (this.homeFeed === feed && feedState === LoadState.Success) {
        scroller.scrollTo({ xOffset: 0, yOffset: targetY, animation: { duration: 0 } });
      }
    }, 80);
  }

  private showFollowingFeed(): void {
    this.selectHomeFeed(HomeFeed.Following);
  }

  /** 首页搜索入口：打开全吧搜索（搜吧 / 搜贴 / 搜人） */
  private openSearchFromHome(): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/Search' })
        .catch((err: Error) => {
          this.getUIContext().getPromptAction().showToast({
            message: `打开搜索失败：${err instanceof Error ? err.message : String(err)}`
          });
        });
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({
        message: `打开搜索失败：${e instanceof Error ? e.message : String(e)}`
      });
    }
  }

  /** 重复点击首页 tab 的整页刷新：按当前 feed 重拉第一页，与下拉刷新走同一路径（推荐强制走网络，不做缓存直出） */
  private reloadHomeFromTab(): void {
    // 先回到列表最顶部，再触发刷新（与主流 App 行为一致）
    if (this.homeFeed === HomeFeed.Following) {
      if (this.folState === LoadState.Success) {
        this.folScroller.scrollEdge(Edge.Top);
      }
      this.loadFollowingThreads();
    } else {
      if (this.loadState === LoadState.Success) {
        this.homeScroller.scrollEdge(Edge.Top);
      }
      this.loadHomeThreads(true);
    }
  }

  private async loadFollowingThreads(): Promise<void> {
    if (this.folRefreshing || this.folLoadingMore) {
      return;
    }
    this.folRefreshing = true;
    // 请求代际递增：使 in-flight 的预加载/加载更多结果作废，避免 concat 到刷新后的新列表
    this.folLoadToken++;
    const myToken: number = this.folLoadToken;
    // 缓存按账号隔离：换号/登出后 key 变化，不会展示上一账号的关注帖
    const cacheKey: string = `${CACHE_KEY.FOLLOW_FEED}_${this.accountId()}`;
    // 仅在当前列表为空时切骨架屏；已有内容刷新时保留列表原地更新，避免闪屏
    if (this.folThreads.length === 0) {
      this.folState = LoadState.Loading;
    }
    // 先尝试缓存直出（stale-while-revalidate）：聚合拉取完成前先渲染上次结果秒开；
    // 缓存命中不阻断网络聚合，完成后原地替换（ForEach 按 tid 复用节点，无闪烁）
    try {
      const cached = await CacheManager.getInstance().getWithTtlAllowStale<ThreadItem[]>(cacheKey);
      if (cached && cached.data.length > 0) {
        this.applyFolSnapshot(cached.data);
      }
    } catch (e) {
    }
    // 流式应用快照：网络聚合的增量中间态回调（并发窗口先到先得）。
    // 关键保护：除首屏空白外的中间态，必须相对当前已展示列表是"纯尾部追加"
    // （前 min(已展示, 新) 项 tid 顺序完全一致）才应用；
    // 否则跳过——避免迟返回用户的更新帖插入顶部、把已展示的顶部内容顶掉，
    // 造成"加载过程中先出现其它顺序帖子、再变正确顺序"的顶部跳变。
    // 最终全量在下方 await 返回后单独强制应用，保证内容最终正确完整。
    // - 首屏空白（folThreads=0）→ 首个非空中间态直接应用（流式秒开）
    // - 已有首屏（缓存直出或首批已应用）→ 走纯追加判定；纯追加则增长、否则跳过
    let initialApplied: boolean = false;
    const applySnapshot = (list: ThreadItem[]): void => {
      if (myToken !== this.folLoadToken) {
        return;
      }
      if (list.length === 0) {
        return;
      }
      if (!initialApplied) {
        initialApplied = true;
        // 首屏空白：直接应用，让最快返回的用户帖子秒出首屏
        if (this.folThreads.length === 0) {
          this.applyFolSnapshot(list);
          return;
        }
        // 已有首屏（缓存直出）：走纯追加判定，不直接覆盖
      }
      // 已应用过首屏：要求纯尾部追加才应用
      if (list.length <= this.folThreads.length) {
        return;
      }
      const n: number = this.folThreads.length;
      let pureAppend: boolean = true;
      for (let i = 0; i < n; i++) {
        if (list[i].tid !== this.folThreads[i].tid) {
          pureAppend = false;
          break;
        }
      }
      if (!pureAppend) {
        return;
      }
      this.applyFolSnapshot(list);
    };
    try {
      // 网络聚合拉取（关注用户列表 + 各人最新发帖），每次进入/刷新都保证最新；
      // 8s 刷新超时兜底：弱网/接口挂起时最坏 8 秒结束，避免刷新转圈无上限
      const list = await this.withFeedRefreshTimeout(
        TiebaService.getInstance().fetchFollowingUserFeed(applySnapshot));
      if (myToken !== this.folLoadToken) {
        return;
      }
      // 最终全量：网络聚合完成即最终态（可能少于缓存直出，属正常），强制应用
      this.applyFolSnapshot(list);
      // 聚合成功回写缓存（异步不阻塞），保证下次进入/刷新秒开
      if (list.length > 0) {
        CacheManager.getInstance().putWithTtl(cacheKey, list, CACHE_TTL.FOLLOW_FEED).catch(() => {
        });
      }
    } catch (e) {
      if (myToken !== this.folLoadToken) {
        return;
      }
      // 超时/失败：作废在途聚合结果（底层 fetchFollowingUserFeed 仍在跑，其 onBatch 到达时 token 已变，直接丢弃）
      this.folLoadToken++;
      // 首批失败才进错误态；已有缓存/内容（超时兜底）时保留现状
      if (this.folAll.length === 0) {
        this.folState = LoadState.Error;
        this.errorMsg = '关注动态加载失败，请稍后重试';
      } else {
        this.getUIContext().getPromptAction().showToast({ message: '刷新超时，已展示上次内容' });
      }
    } finally {
      this.folRefreshing = false;
    }
  }

  /** 首页 feed 刷新超时兜底：弱网/接口挂起时最多转 8 秒，超时按失败处理（调用方保留旧内容） */
  private withFeedRefreshTimeout<T>(promise: Promise<T>): Promise<T> {
    return new Promise<T>((resolve: (v: T) => void, reject: (e: Error) => void) => {
      const timer: number = setTimeout(() => {
        reject(new Error('刷新超时，请检查网络'));
      }, 8000);
      promise.then((value: T) => {
        clearTimeout(timer);
        resolve(value);
      }).catch((e: Error) => {
        clearTimeout(timer);
        reject(e);
      });
    });
  }

  /** 应用关注动态全量快照：切片分页 + 状态更新（缓存直出与网络聚合共用） */
  private applyFolSnapshot(list: ThreadItem[]): void {
    // 保留已展示条数下限：增量回调可能发生在已向下翻页之后（folThreads 超过一页），
    // 新快照只增不减，避免中间态把已加载的下一页"收回"导致列表跳动
    const keep = Math.max(this.folThreads.length, FOLLOW_FEED_PAGE_SIZE);
    this.folAll = list;
    this.folThreads = list.slice(0, keep);
    this.folPage = 1;
    this.folHasMore = list.length > this.folThreads.length;
    this.folStalledPages = 0;
    this.folState = this.folThreads.length > 0 ? LoadState.Success : LoadState.Empty;
    // 加载成功即视为"已加载过"，后续切换不再自动重新拉取
    this.folFeedLoaded = true;
  }

  private async loadMoreFollowingThreads(silent: boolean = false): Promise<void> {
    if (this.folLoadingMore || !this.folHasMore || this.folThreads.length === 0) {
      return;
    }
    this.folLoadingMore = true;
    // 记录当前代际：返回时若已刷新/切feed则丢弃结果
    const myToken: number = this.folLoadToken;
    try {
      const nextStart: number = this.folThreads.length;
      if (nextStart >= this.folAll.length) {
        this.folHasMore = false;
        return;
      }
      // 本地切片分页：聚合结果已在 service 端按时间倒序并去重，直接切片即可，零网络请求
      const appended: ThreadItem[] = this.folAll.slice(nextStart, nextStart + FOLLOW_FEED_PAGE_SIZE);
      if (myToken !== this.folLoadToken) {
        return;
      }
      this.folThreads = this.folThreads.concat(appended);
      this.folPage++;
      this.folHasMore = this.folAll.length > this.folThreads.length;
      this.folStalledPages = 0;
    } catch (e) {
      // 本地切片无网络，异常仅作兜底；预加载失败静默忽略
      if (!silent) {
        this.getUIContext().getPromptAction().showToast({ message: '加载关注动态失败，请稍后重试' });
      }
    } finally {
      this.folLoadingMore = false;
    }
  }

  /**
   * 首页预加载：滚动剩余距离 < 阈值时提前静默加载下一页，实现触底无缝续流。
   * - 剩余距离 = 内容高 − 视口高 − 当前偏移（由 onAreaChange 测量）
   * - homeLoadingMore 锁 + 偏移节流防重；onReachEnd 保留作兜底（锁会挡住重复请求）
   */
  private onHomeScroll(_x: number, y: number): void {
    // 无条件记录当前 feed 浏览位置（切走/切回时恢复）
    this.homeScrollY = y;
    if (this.homeFeed === HomeFeed.Following) {
      this.folScrollY = y;
    } else {
      this.recommendScrollY = y;
    }
    if (this.homeFeed === HomeFeed.Following) {
      // 关注动态预加载：使用关注流独立测量值与状态
      if (this.folState !== LoadState.Success || this.folLoadingMore || !this.folHasMore) {
        return;
      }
      const remaining: number = this.folContentH - this.folViewportH - y;
      if (remaining > HOME_PREFETCH_DISTANCE) {
        return;
      }
      // 节流：偏移变化超过 120vp 才允许再次触发，避免同一轮滚动连续请求
      if (Math.abs(y - this.folLastPrefetchY) < 120) {
        return;
      }
      this.folLastPrefetchY = y;
      this.loadMoreFollowingThreads(true);
    } else {
      if (this.loadState !== LoadState.Success || this.homeLoadingMore || !this.homeHasMore) {
        return;
      }
      const remaining: number = this.homeContentH - this.homeViewportH - y;
      if (remaining > HOME_PREFETCH_DISTANCE) {
        return;
      }
      // 节流：偏移变化超过 120vp 才允许再次触发，避免同一轮滚动连续请求
      if (Math.abs(y - this.homeLastPrefetchY) < 120) {
        return;
      }
      this.homeLastPrefetchY = y;
      this.loadMoreHomeThreads(true);
    }
  }

  /** 内容尺寸变化：记录内容高；不满一屏时直接预取下一页（Scroll 无滚动，onReachEnd/onScroll 均不触发） */
  private onHomeContentAreaChange(oldValue: Area, newValue: Area): void {
    const h: number = newValue.height as number;
    if (this.homeFeed === HomeFeed.Following) {
      this.folContentH = h;
      if (this.folState === LoadState.Success && !this.folLoadingMore && this.folHasMore
        && this.folViewportH > 0 && this.folContentH <= this.folViewportH) {
        this.loadMoreFollowingThreads(true);
      }
    } else {
      this.homeContentH = h;
      if (this.loadState === LoadState.Success && !this.homeLoadingMore && this.homeHasMore
        && this.homeViewportH > 0 && this.homeContentH <= this.homeViewportH) {
        this.loadMoreHomeThreads(true);
      }
    }
  }

  /** 视口尺寸变化：记录视口高（按当前 feed 分别记录）+ 形态变化兜底（分屏/自由窗口） */
  private onHomeViewportAreaChange(oldValue: Area, newValue: Area): void {
    if (this.homeFeed === HomeFeed.Following) {
      this.folViewportH = newValue.height as number;
    } else {
      this.homeViewportH = newValue.height as number;
    }
    // 窗口实宽 / 实高（Area 已是 vp）：小窗 / 分屏 / 自由多窗下 display ≠ 窗口，必须以窗口为准
    this.checkFormChange(Number(newValue.width), Number(newValue.height));
  }

  /** 形态变化兜底：窗口宽高变化（分屏 / 自由窗口 / 折叠展开 / 小窗拖拽）时刷新列数标记；
   *  窗口值拿不到时退回 display 首帧口径（全屏下两者等价）。 */
  private checkFormChange(winW: number, winH: number): void {
    let w: number = winW;
    let h: number = winH;
    if (w <= 0 || h <= 0) {
      try {
        const d: display.Display = display.getDefaultDisplaySync();
        w = this.getUIContext().px2vp(d.width);
        h = this.getUIContext().px2vp(d.height);
      } catch (e) {
        // 忽略：窗口未 attach 时取宽会失败
        return;
      }
    }
    if (w <= 0 || h <= 0) {
      return;
    }
    if (w !== this.pageWidth || h !== this.pageHeight) {
      this.pageWidth = w;
      this.pageHeight = h;
      this.updateFadeStop(h);
      this.updateColumns();
      this.syncCardColumns();
    }
  }

  /** 左右滑动手势切换首页 feed：左滑 → 关注动态，右滑 → 推荐；动画期间锁防连滑错乱
   *  PanGesture.onActionEnd 的 offsetX 为水平总位移：负值=左滑，正值=右滑 */
  private onHomeFeedPanEnd(event: GestureEvent): void {
    if (this.homeFeedSwitching) {
      return;
    }
    const dx: number = event.offsetX;
    if (dx < -80 && this.homeFeed === HomeFeed.Recommended) {
      // 左滑：切到关注动态
      this.showFollowingFeed();
    } else if (dx > 80 && this.homeFeed === HomeFeed.Following) {
      // 右滑：切回推荐
      this.selectHomeFeed(HomeFeed.Recommended);
    }
  }

  private accountId(): string {
    return AuthManager.getInstance().getUser()?.userId ?? '';
  }

  private openLogin(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Login' });
  }

  /** 首页卡片点击作者头像/名称：跳转作者用户主页 */
  private openUserProfile(authorId: string, author: string): void {
    const id: string = `${authorId ?? ''}`.trim();
    if (id.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '该用户信息暂不可用' });
      return;
    }
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/UserProfile',
      params: { userId: id, userName: author }
    }).catch(() => {
      this.getUIContext().getPromptAction().showToast({ message: '用户主页打开失败，请稍后重试' });
    });
  }

  private async recordHistory(item: ThreadItem): Promise<void> {
    const historyItem: PersonalContentItem = {
      id: item.tid,
      tid: item.tid,
      title: item.title,
      forumName: item.forumName,
      forumId: item.forumId ?? '',
      forumAvatar: item.forumAvatar ?? '',
      author: item.author,
      abstract: item.abstract,
      replyNum: item.replyNum,
      createTime: item.createTime
    };
    const accountId: string = AuthManager.getInstance().getUser()?.userId ?? '';
    if (accountId.length > 0) {
      historyItem.accountId = accountId;
      await CacheManager.getInstance().appendJsonItem(`${CACHE_KEY.PERSONAL_HISTORY}_${accountId}`, historyItem);
    }
  }

  private openThread(item: ThreadItem): void {
    const tid = item.tid.trim();
    if (tid.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '帖子信息暂不可用' });
      return;
    }
    this.recordHistory(item);
    // 点击即预取：利用跳转动画窗口后台取详情，详情页打开即命中缓存秒开
    TiebaService.getInstance().prefetchThreadDetail(tid, item.forumId ?? '');
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/ThreadDetail',
      params: { tid: tid, forum: item.forumName, fid: item.forumId ?? '' }
    }).catch(() => {
      this.getUIContext().getPromptAction().showToast({ message: '帖子打开失败，请稍后重试' });
    });
  }

  private async handleLike(tid: string, postId: string, liked: boolean): Promise<void> {
    try {
      const result = await TiebaService.getInstance().togglePostAgree(tid, postId, liked);
      if (result) {
        this.updateCurrentThreads(this.currentFeedThreads().map((t: ThreadItem) => {
          if (t.tid === tid) {
            const updated: ThreadItem = {
              tid: t.tid, postId: t.postId, forumId: t.forumId,
              title: t.title, forumName: t.forumName, forumAvatar: t.forumAvatar,
              author: t.author, authorAvatar: t.authorAvatar,
              replyNum: t.replyNum,
              likeCount: (t.likeCount ?? 0) + (liked ? 1 : -1),
              isLiked: liked,
              abstract: t.abstract, firstImage: t.firstImage,
              images: t.images, createTime: t.createTime,
              isTop: t.isTop, isGood: t.isGood,
            };
            return updated;
          }
          return t;
        }));
      }
    } catch (e) {
      const msg = (e as Error).message ?? '操作失败';
      this.getUIContext().getPromptAction().showToast({ message: msg });
    }
  }

  @Builder
  RecommendedFeed() {
    Column() {
      if (this.loadState === LoadState.Loading) {
        ThreadListSkeleton({ columns: this.homeColumns() })
          .width('100%')
          .layoutWeight(1)
      } else if (this.loadState === LoadState.Error) {
        ErrorView({
          message: this.errorMsg,
          onRetry: () => {
            this.loadHomeThreads();
          }
        }).layoutWeight(1)
      } else if (this.loadState === LoadState.Empty) {
        EmptyView({
          message: '暂时没有推荐内容',
          icon: '○'
        }).layoutWeight(1)
      } else {
        // 刷新区整体下移到"推荐/关注动态"按钮下方：系统默认指示器从按钮下方出现，跟手、松手刷新
        Refresh({ refreshing: this.homeRefreshing, offset: 48, friction: 62 }) {
          if (this.homeColumns() > 1) {
            // ===== WaterFlow 瀑布流（§4.2 决策 12）：LazyForEach 虚拟滚动 + 自然高度卡片 =====
            WaterFlow({ scroller: this.homeScroller }) {
              LazyForEach(this.recDataSource, (item: ThreadItem) => {
                FlowItem() {
                  ThreadCard({
                    item: {
                      tid: item.tid,
                      postId: item.postId ?? '',
                      forumId: item.forumId,
                      title: item.title,
                      forumName: item.forumName,
                      forumAvatar: item.forumAvatar ?? '',
                      author: item.author,
                      authorId: item.authorId,
                      authorAvatar: item.authorAvatar ?? '',
                      replyNum: item.replyNum,
                      likeCount: item.likeCount ?? 0,
                      isLiked: item.isLiked ?? false,
                      abstract: item.abstract,
                      firstImage: item.firstImage ?? '',
                      images: item.images ?? [],
                      createTime: item.createTime,
                      isTop: item.isTop,
                      isGood: item.isGood,
                    } as ThreadItemData,
                    onTap: (_tid: string) => this.openThread(item),
                    onLike: (tid: string, postId: string, liked: boolean) => this.handleLike(tid, postId, liked),
                    onShare: (d: ThreadSharePayload) => this.shareThread(d),
                    onComment: (_tid: string) => this.openThread(item),
                    onAvatarTap: (id: string, name: string) => this.openUserProfile(id, name)
                  })
                }
              }, (item: ThreadItem) => `${item.tid}_${item.author}_${item.isLiked ? 1 : 0}_${item.likeCount ?? 0}`)
            }
            .columnsTemplate(this.homeColumnsTemplate())
            .columnsGap(Spacing.md)
            .rowsGap(Spacing.md)
            .padding({ left: Spacing.lg, right: Spacing.lg })
            .layoutWeight(1)
            .clip(false)
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .onAreaChange((oldValue: Area, newValue: Area) => this.onHomeViewportAreaChange(oldValue, newValue))
            .onScroll((xOffset: number, yOffset: number) => this.onHomeScroll(xOffset, yOffset))
            .onReachEnd(() => {
              if (this.loadState === LoadState.Success && !this.homeLoadingMore) {
                this.loadMoreHomeThreads();
              }
            })
          } else {
          Scroll(this.homeScroller) {
            Column() {
              ForEach(this.threads, (item: ThreadItem) => {
                ThreadCard({
                  item: {
                    tid: item.tid,
                    postId: item.postId ?? '',
                    forumId: item.forumId,
                    title: item.title,
                    forumName: item.forumName,
                    forumAvatar: item.forumAvatar ?? '',
                    author: item.author,
                    authorId: item.authorId,
                    authorAvatar: item.authorAvatar ?? '',
                    replyNum: item.replyNum,
                    likeCount: item.likeCount ?? 0,
                    isLiked: item.isLiked ?? false,
                    abstract: item.abstract,
                    firstImage: item.firstImage ?? '',
                    images: item.images ?? [],
                    createTime: item.createTime,
                    isTop: item.isTop,
                    isGood: item.isGood,
                  } as ThreadItemData,
                  onTap: (_tid: string) => this.openThread(item),
                  onLike: (tid: string, postId: string, liked: boolean) => this.handleLike(tid, postId, liked),
                  onShare: (d: ThreadSharePayload) => this.shareThread(d),
                  onComment: (_tid: string) => this.openThread(item),
                  onAvatarTap: (id: string, name: string) => this.openUserProfile(id, name)
                })
                .margin({ bottom: Spacing.md })
              }, (item: ThreadItem) => `${item.tid}_${item.author}_${item.isLiked ? 1 : 0}_${item.likeCount ?? 0}`)

              // 预加载/触底加载进行中的占位尾卡：触底时也有"正在加载"反馈，避免空等停顿感
              if (this.homeLoadingMore && this.homeHasMore) {
                Row({ space: 8 }) {
                  LoadingProgress()
                    .width(20)
                    .height(20)
                  Text('正在加载更多…')
                    .fontSize(13)
                    .fontColor('#8A8A8A')
                }
                .width('100%')
                .height(56)
                .justifyContent(FlexAlign.Center)
                .margin({ bottom: Spacing.md })
              }

              // 底部空间
              Column()
                .width('100%')
                .height(150)
            }
            .width('100%')
            .padding({ left: Spacing.lg, right: Spacing.lg, top: 0 })
            .onAreaChange((oldValue: Area, newValue: Area) => this.onHomeContentAreaChange(oldValue, newValue))
          }
          .width('100%')
          .layoutWeight(1)
          .clip(false)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .onAreaChange((oldValue: Area, newValue: Area) => this.onHomeViewportAreaChange(oldValue, newValue))
          .onScroll((xOffset: number, yOffset: number) => this.onHomeScroll(xOffset, yOffset))
          .onReachEnd(() => {
            if (this.loadState === LoadState.Success && !this.homeLoadingMore) {
              this.loadMoreHomeThreads();
            }
          })
          }
        }
        .width('100%')
        .margin({ top: HOME_TOP_PAD })
        .layoutWeight(1)
        .backgroundColor(Color.Transparent)
        .clip(false)
        .onRefreshing(() => {
          this.homeRefreshing = false;
          // 下拉刷新强制走网络，不做缓存直出
          this.loadHomeThreads(true);
        })
      }
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor(Color.Transparent)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .overlay(this.BottomFadeOverlay())
    .blendMode(BlendMode.SRC_OVER, BlendApplyType.OFFSCREEN)
  }

  /** 关注动态视图：fol* 独立数据源，常驻不销毁，切换时保留内容与滚动位置 */
  @Builder
  FollowingFeed() {
    Column() {
      if (this.folState === LoadState.Loading) {
        ThreadListSkeleton({ columns: this.homeColumns() })
          .width('100%')
          .layoutWeight(1)
      } else if (this.folState === LoadState.Error) {
        ErrorView({
          message: this.errorMsg,
          onRetry: () => {
            this.loadFollowingThreads();
          }
        }).layoutWeight(1)
      } else if (this.folState === LoadState.Empty) {
        EmptyView({
          message: '暂时没有关注动态',
          icon: '○'
        }).layoutWeight(1)
      } else {
        Refresh({ refreshing: this.folRefreshing, offset: 48, friction: 62 }) {
          if (this.homeColumns() > 1) {
            // ===== WaterFlow 瀑布流（§4.2 决策 12）：与推荐流同款写法 =====
            WaterFlow({ scroller: this.folScroller }) {
              LazyForEach(this.folDataSource, (item: ThreadItem) => {
                FlowItem() {
                  ThreadCard({
                    item: {
                      tid: item.tid,
                      postId: item.postId ?? '',
                      forumId: item.forumId,
                      title: item.title,
                      forumName: item.forumName,
                      forumAvatar: item.forumAvatar ?? '',
                      author: item.author,
                      authorId: item.authorId,
                      authorAvatar: item.authorAvatar ?? '',
                      replyNum: item.replyNum,
                      likeCount: item.likeCount ?? 0,
                      isLiked: item.isLiked ?? false,
                      abstract: item.abstract,
                      firstImage: item.firstImage ?? '',
                      images: item.images ?? [],
                      createTime: item.createTime,
                      isTop: item.isTop,
                      isGood: item.isGood,
                    } as ThreadItemData,
                    onTap: (_tid: string) => this.openThread(item),
                    onLike: (tid: string, postId: string, liked: boolean) => this.handleLike(tid, postId, liked),
                    onShare: (d: ThreadSharePayload) => this.shareThread(d),
                    onComment: (_tid: string) => this.openThread(item),
                    onAvatarTap: (id: string, name: string) => this.openUserProfile(id, name)
                  })
                }
              }, (item: ThreadItem) => `${item.tid}_${item.author}_${item.isLiked ? 1 : 0}_${item.likeCount ?? 0}`)
            }
            .columnsTemplate(this.homeColumnsTemplate())
            .columnsGap(Spacing.md)
            .rowsGap(Spacing.md)
            .padding({ left: Spacing.lg, right: Spacing.lg })
            .layoutWeight(1)
            .clip(false)
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .onAreaChange((oldValue: Area, newValue: Area) => this.onHomeViewportAreaChange(oldValue, newValue))
            .onScroll((xOffset: number, yOffset: number) => this.onHomeScroll(xOffset, yOffset))
            .onReachEnd(() => {
              if (this.folState === LoadState.Success && !this.folLoadingMore) {
                this.loadMoreFollowingThreads();
              }
            })
          } else {
          Scroll(this.folScroller) {
            Column() {
              ForEach(this.folThreads, (item: ThreadItem) => {
                ThreadCard({
                  item: {
                    tid: item.tid,
                    postId: item.postId ?? '',
                    forumId: item.forumId,
                    title: item.title,
                    forumName: item.forumName,
                    forumAvatar: item.forumAvatar ?? '',
                    author: item.author,
                    authorId: item.authorId,
                    authorAvatar: item.authorAvatar ?? '',
                    replyNum: item.replyNum,
                    likeCount: item.likeCount ?? 0,
                    isLiked: item.isLiked ?? false,
                    abstract: item.abstract,
                    firstImage: item.firstImage ?? '',
                    images: item.images ?? [],
                    createTime: item.createTime,
                    isTop: item.isTop,
                    isGood: item.isGood,
                  } as ThreadItemData,
                  onTap: (_tid: string) => this.openThread(item),
                  onLike: (tid: string, postId: string, liked: boolean) => this.handleLike(tid, postId, liked),
                  onShare: (d: ThreadSharePayload) => this.shareThread(d),
                  onComment: (_tid: string) => this.openThread(item),
                  onAvatarTap: (id: string, name: string) => this.openUserProfile(id, name)
                })
                .margin({ bottom: Spacing.md })
              }, (item: ThreadItem) => `${item.tid}_${item.author}_${item.isLiked ? 1 : 0}_${item.likeCount ?? 0}`)

              // 预加载/触底加载进行中的占位尾卡
              if (this.folLoadingMore && this.folHasMore) {
                Row({ space: 8 }) {
                  LoadingProgress()
                    .width(20)
                    .height(20)
                  Text('正在加载动态…')
                    .fontSize(13)
                    .fontColor('#8A8A8A')
                }
                .width('100%')
                .height(56)
                .justifyContent(FlexAlign.Center)
                .margin({ bottom: Spacing.md })
              }

              // 底部空间
              Column()
                .width('100%')
                .height(150)
            }
            .width('100%')
            .padding({ left: Spacing.lg, right: Spacing.lg, top: 0 })
            .onAreaChange((oldValue: Area, newValue: Area) => this.onHomeContentAreaChange(oldValue, newValue))
          }
          .width('100%')
          .layoutWeight(1)
          .clip(false)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .onAreaChange((oldValue: Area, newValue: Area) => this.onHomeViewportAreaChange(oldValue, newValue))
          .onScroll((xOffset: number, yOffset: number) => this.onHomeScroll(xOffset, yOffset))
          .onReachEnd(() => {
            if (this.folState === LoadState.Success && !this.folLoadingMore) {
              this.loadMoreFollowingThreads();
            }
          })
          }
        }
        .width('100%')
        .margin({ top: HOME_TOP_PAD })
        .layoutWeight(1)
        .backgroundColor(Color.Transparent)
        .clip(false)
        .onRefreshing(() => {
          this.folRefreshing = false;
          this.loadFollowingThreads();
        })
      }
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor(Color.Transparent)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .overlay(this.BottomFadeOverlay())
    .blendMode(BlendMode.SRC_OVER, BlendApplyType.OFFSCREEN)
  }

  /** 顶部渐显覆盖比例（2026-09-13）：平板只覆盖顶部按钮与标题（108vp 折算，实时窗口高），手机维持 15% */
  private topFadeStop(): number {
    if (!this.isWideFormDevice || this.pageHeight <= 0) {
      return 0.15;
    }
    return Math.min(0.15, HOME_TITLE_BAR_HEIGHT / this.pageHeight);
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
  HomeHeaderOverlay() {
    // 吸顶标题：按钮始终悬浮在顶部，帖子从下方穿过
    Row({ space: 16 }) {
      Text('推荐')
        .fontSize(fs(16, this.fontScale))
        .fontWeight(this.homeFeed === HomeFeed.Recommended
          ? FontWeight.Bold
          : FontWeight.Medium)
        // 参考底栏切换：去蓝底，状态交给系统强调色文字；中性磨砂玻璃底保留真模糊质感
        .fontColor(this.homeFeed === HomeFeed.Recommended
          ? $r('sys.color.font_emphasize')
          : $r('sys.color.font_primary'))
        .backgroundColor(Theme.segGlass(this.isDark, this.homeFeed === HomeFeed.Recommended))
        .border({ width: 0.5, color: Theme.manualGlassBorder() })
        .backgroundBlurStyle(this.homeFeed === HomeFeed.Recommended ? BlurStyle.Regular : BlurStyle.Thin,
          { scale: this.homeFeed === HomeFeed.Recommended ? 0.8 : 0.85 })
        .shadow(Theme.segGlassShadow(this.isDark, this.homeFeed === HomeFeed.Recommended))
        .borderRadius(Radius.full)
        .padding({ left: 22, right: 22, top: 9, bottom: 9 })
        .onClick(() => this.selectHomeFeed(HomeFeed.Recommended))

      Text('关注动态')
        .fontSize(fs(16, this.fontScale))
        .fontWeight(this.homeFeed === HomeFeed.Following
          ? FontWeight.Bold
          : FontWeight.Medium)
        // 与推荐钮一致：中性磨砂玻璃 + 系统强调色文字切换
        .fontColor(this.homeFeed === HomeFeed.Following
          ? $r('sys.color.font_emphasize')
          : $r('sys.color.font_primary'))
        .backgroundColor(Theme.segGlass(this.isDark, this.homeFeed === HomeFeed.Following))
        .border({ width: 0.5, color: Theme.manualGlassBorder() })
        .backgroundBlurStyle(this.homeFeed === HomeFeed.Following ? BlurStyle.Regular : BlurStyle.Thin,
          { scale: this.homeFeed === HomeFeed.Following ? 0.8 : 0.85 })
        .shadow(Theme.segGlassShadow(this.isDark, this.homeFeed === HomeFeed.Following))
        .borderRadius(Radius.full)
        .padding({ left: 22, right: 22, top: 9, bottom: 9 })
        .onClick(() => this.showFollowingFeed())

      Blank()

      // 首页搜索入口（全站搜吧接口不可用，BUG-03 定案：联动收藏页本地搜索）
      Button() {
        SymbolGlyph($r('sys.symbol.magnifyingglass')).fontColor([$r('sys.color.icon_primary')]).fontSize(fs(20, this.fontScale))
      }
      .width(44).height(44)
      // 与胶囊同风格：中性磨砂玻璃圆钮（无色底），透明不可见仅作热区
      .backgroundColor(Theme.segGlass(this.isDark, false))
      .border({ width: 0.5, color: Theme.manualGlassBorder() })
      .backgroundBlurStyle(BlurStyle.Thin, { scale: 0.85 })
      .shadow(Theme.segGlassShadow(this.isDark, false))
      .borderRadius(Radius.full)
      .accessibilityText('全吧搜索')
      .onClick(() => { this.openSearchFromHome(); })
    }
    .width('100%')
    .padding({ left: Spacing.lg, right: Spacing.lg, top: 44, bottom: 20 }) // 加大按钮与下方首张卡片的视觉空隙（v1.15.9）
    .backgroundColor(Color.Transparent)
    .zIndex(15)
  }

  /**
   * 官方槽位标题栏：整行搬进 Navigation 的 title 槽位。
   * 几何与 HomeHeaderOverlay 逐项一致（top 44 / bottom 20 / 左右 Spacing.lg / space 16 /
   * 胶囊 padding 左右 22 + 上下 9 / fontSize 16 / 圆钮 44），只把玻璃从 backgroundBlurStyle 换成官方沉浸材质。
   * - 未选中 / 选中 → ImmMaterial.seg(false/true)（THIN / REGULAR 中性档，不染色，状态仍由文字色 + 字重表达）
   * - 搜索圆钮 → ImmMaterial.seg(false)（THIN 中性档，与两胶囊同一套材质语言）
   * 文字图标色全部沿用系统可反色资源（font_emphasize / font_primary / icon_primary），满足官方自动反色前提。
   * 不挂 backgroundColor / border / backgroundBlurStyle / shadow：官方明确不建议与 systemMaterial 同用（会互相覆盖）。
   */
  @Builder
  HomeTitleBar() {
    Row({ space: 16 }) {
      Text('推荐')
        .fontSize(fs(16, this.fontScale))
        .fontWeight(this.homeFeed === HomeFeed.Recommended
          ? FontWeight.Bold
          : FontWeight.Medium)
        .fontColor(this.homeFeed === HomeFeed.Recommended
          ? $r('sys.color.font_emphasize')
          : $r('sys.color.font_primary'))
        .systemMaterial(ImmMaterial.seg(this.homeFeed === HomeFeed.Recommended))
        .borderRadius(Radius.full)
        .padding({ left: 22, right: 22, top: 9, bottom: 9 })
        .onClick(() => this.selectHomeFeed(HomeFeed.Recommended))

      Text('关注动态')
        .fontSize(fs(16, this.fontScale))
        .fontWeight(this.homeFeed === HomeFeed.Following
          ? FontWeight.Bold
          : FontWeight.Medium)
        .fontColor(this.homeFeed === HomeFeed.Following
          ? $r('sys.color.font_emphasize')
          : $r('sys.color.font_primary'))
        .systemMaterial(ImmMaterial.seg(this.homeFeed === HomeFeed.Following))
        .borderRadius(Radius.full)
        .padding({ left: 22, right: 22, top: 9, bottom: 9 })
        .onClick(() => this.showFollowingFeed())

      Blank()

      // 首页搜索入口（全站搜吧接口不可用，BUG-03 定案：联动收藏页本地搜索）
      Button() {
        SymbolGlyph($r('sys.symbol.magnifyingglass')).fontColor([$r('sys.color.icon_primary')]).fontSize(fs(20, this.fontScale))
      }
      .width(44)
      .height(44)
      // Button 自带 comp_background_emphasize 品牌蓝默认填充（Text 胶囊无默认背景，故只有圆钮会泛蓝底）：
      // 必须显式清成 Transparent，否则 THIN 玻璃下透出一片蓝底
      .backgroundColor(Color.Transparent)
      // 与两颗胶囊统一材质语言：THIN 中性档（不染色）；此前是 control() 的 ULTRA_THIN，太薄看不见玻璃
      .systemMaterial(ImmMaterial.seg(false))
      .borderRadius(Radius.full)
      .accessibilityText('全吧搜索')
      .onClick(() => { this.openSearchFromHome(); })
    }
    .width('100%')
    .padding({ left: Spacing.lg, right: Spacing.lg, top: 44, bottom: 20 })
    .backgroundColor(Color.Transparent)
  }

  /**
   * 内容层：推荐 / 关注动态两个 feed 视图 + 左右滑动手势。
   * 官方标题栏路径（Navigation title 槽位）与兜底路径（页面主体悬浮层）共用同一份内容。
   */
  @Builder
  HomeFeedContent() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 推荐页 / 关注动态：两个独立视图按 homeFeed 条件渲染，TransitionEffect 驱动左右滑动转场
      // （同收藏页"吧分类/自定义分类"切换范式：旧视图滑出 + 新视图滑入，互推效果）
      if (this.homeFeed === HomeFeed.Recommended) {
        Column() {
          this.RecommendedFeed()
        }
        .width('100%')
        .height('100%')
        .transition(this.firstHomeMount ? TransitionEffect.IDENTITY : this.feedTabTransition(-1))
      } else {
        Column() {
          this.FollowingFeed()
        }
        .width('100%')
        .height('100%')
        .transition(this.firstHomeMount ? TransitionEffect.IDENTITY : this.feedTabTransition(1))
      }

      // 悬浮按钮层（独立于滚动内容，帖子可穿过按钮区域）
      // 官方标题栏路径下按钮已在 Navigation title 槽位里，这里不再叠一层
      if (!HOME_OFFICIAL_TITLE_BAR) {
        this.HomeHeaderOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    // 左右滑动手势：切换推荐/关注动态。
    // 用 parallelGesture 与内部 Scroll 并行识别（Scroll 会优先消费横向滑动手势导致父级 gesture 不触发）；
    // 用 PanGesture 而非 SwipeGesture：识别更宽容，onActionEnd 直接给出总位移判断方向
    .parallelGesture(
      PanGesture({ fingers: 1, direction: PanDirection.Horizontal, distance: 30 })
        .onActionEnd((event: GestureEvent) => {
          this.onHomeFeedPanEnd(event);
        })
    )
  }

  build() {
    if (HOME_OFFICIAL_TITLE_BAR) {
      // 官方槽位路径：Navigation + 自定义 title（height 固定 108，与改造前悬浮层几何一致）
      // barStyle STACK：内容区延伸到标题栏之下（官方建议，标题栏材质获得最佳沉浸体验的前提）
      // backgroundColor 显式透明：避免标题栏自带底色压住滚动经过的内容
      Navigation() {
        this.HomeFeedContent()
      }
      .title({ builder: this.HomeTitleBar(), height: HOME_TITLE_BAR_HEIGHT },
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
      // 兜底路径：改造前原样（页面主体悬浮层 + manualGlass/backgroundBlurStyle 真磨砂）
      this.HomeFeedContent()
    }
  }
}
