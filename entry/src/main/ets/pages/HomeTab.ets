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
import { curves, display, LengthMetrics } from '@kit.ArkUI';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { pasteboard, BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AuthManager } from '../service/AuthManager';
import { TiebaService } from '../service/TiebaService';
import { CacheManager } from '../cache/CacheManager';
import { CACHE_KEY, CACHE_TTL } from '../common/Constants';
import { PrefetchGate } from '../common/PrefetchGate';
import {
  ImmersiveReadSensor, IMMERSIVE_EXTRA_FLY_SCALE, IMMERSIVE_EXTRA_HIDE_MS, IMMERSIVE_EXTRA_SHOW_MS,
  IMMERSIVE_EXTRA_SPRING_RESPONSE, IMMERSIVE_EXTRA_SPRING_DAMPING
} from '../common/ImmersiveReadSensor';
import { FollowFeedStore, POOL_HIGH, sortThreadsByTimeDesc } from '../service/FollowFeedStore';
import { HistoryStore } from '../service/HistoryStore';
import { FollowItem, PagedResult, ThreadItem, PersonalContentItem } from '../model/DataModel';
import { Theme, Spacing, Radius, Breakpoint, CARD_COLUMNS_KEY, isDarkMode, ImmBlur, ImmMaterial, fs, isWideBarDevice, isLargeFoldDevice, isWideFormDevice as detectWideFormDevice, readColumnMode, overrideColumns, isLargeScreenForm, isWideBarFullscreen } from '../common/Theme';
import { ErrorView, EmptyView, ThreadCard, ThreadItemData, ThreadSharePayload } from '../components/CommonComponents';
import { ThreadListSkeleton } from '../components/Skeleton';
import { PerfTrace } from '../common/PerfTrace';

interface FollowSets {
  ids: Set<string>;
  names: Set<string>;
}

/**
 * WaterFlow 数据源（§4.2 决策 12）：包装 @State 数组，通过 @Watch 自动同步。
 * reload() 用于全量替换（下拉刷新 / 切换 feed），notifyAdd() 用于尾部追加（加载更多）。
 */
/** 「帖子极速开启」滑动停歇预取的候选（按几何距离排序用） */
interface ScoredThread {
  it: ThreadItem;
  d: number;
}

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

  /** 单点内容变更（长度与顺序不变的就地更新：点赞 / 昵称回填）——仅重建该项，避免整表 reload */
  notifyChange(index: number): void {
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataChange(index);
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
 * 单列档窗口化挂载诊断打点（2026-09-30「滑动抽搐 / 回滑露空白」定位期使用，问题已修复）。
 * 结论存档：抽搐 = 一次窗口推进的一帧耗时（15~20ms 整列重排固定代价 + ~4.5ms/张组件构建，
 * 与模糊/图片无关），故单列档已改走 WaterFlow（见 HOME_SINGLE_USE_WATERFLOW）；
 * 空白 = 等高占位估算偏差（errAvg 80~120vp）导致视口上方内容被推走，已由内容特征桶估算修复。
 * 打点只在「窗口化挂载」回退路径（HOME_SINGLE_USE_WATERFLOW=false）下才会触发。
 * 出口三个：SLIDE=窗口推进、GAP=可见区越出窗口（视口内有占位）、HEST=估算与实测卡高偏差。
 */
const HSLOT_DIAG: boolean = false;
const HSLOT_TAG: string = 'HSLOT';

/**
 * 单列档（手机）滚动容器：Scroll + Column 全量布局 + 窗口化挂载 → WaterFlow('1fr') + LazyForEach。
 * 依据（2026-09-30 真机 A/B 归因）：窗口化挂载每次推进要付 ~15~20ms 的固定代价（整列重排）
 * 外加 ~4.5ms/张的组件树构建，且与模糊/图片均无关（去模糊、去图片耗时不变）——120Hz 下必然掉帧；
 * 而多列档的 WaterFlow + LazyForEach 是虚拟化 + 节点复用，同一页面长期无卡顿反馈。
 * 置 false 即一行回退到原窗口化挂载路径（两条路径都保留在 build 内）。
 */
const HOME_SINGLE_USE_WATERFLOW: boolean = true;

/** 缓存落盘合并窗口：列表变化后合并多次落盘为一次（600ms ≈ 一次翻页 + 一屏停留） */
const HOME_CACHE_WRITE_DELAY: number = 600;
/** 滚动空闲判定阈值：距上次 onScroll 不足该值视为仍在滑行，落盘与昵称回填一律顺延 */
const HOME_SCROLL_IDLE_MS: number = 300;

/** 首页 feed 左右滑动的最小位移阈值（vp）：与 ThreadList 吧主页「左右滑切排序」同档 */
const HOME_FEED_SWIPE_THRESHOLD: number = 80;
/**
 * 首页 feed 左右滑切后的卡点按解锁延时（ms）：横向 Pan 识别后抬指，手势仲裁仍可能给卡片
 * 派发 click（吧主页左右滑切排序真机结论），故滑动期间锁住卡片点按、抬指后延时解锁。
 */
const HOME_FEED_SWIPE_UNLOCK_DELAY: number = 250;

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
  // ===== 「沉浸式阅读补全」（2026-09-29，设置 → 个性化）=====
  /** 设置项真源：AppStorage `immersiveReadExtra`（独立开关，默认关） */
  @StorageLink('immersiveReadExtra') @Watch('onImmersiveExtraChanged') immersiveReadExtra: boolean = false;
  /** 当前主 Tab 真源（Index.switchTab / aboutToAppear 维护）：仅自己为当前 Tab 时才允许驱动宿主底栏 */
  @StorageLink('currentMainTab') @Watch('onCurrentMainTabChanged') currentMainTab: number = 0;
  /**
   * 沉浸态：true = 顶部胶囊与宿主底栏已藏起。
   * **只存页面局部 @State，绝不写 AppStorage**（宿主底栏的驱动键 mainBarImmersiveHidden 除外，
   * 且仅当前 Tab 才写）—— 切 Tab 残留由 Index.switchTab 复位兜底。
   */
  @State immersiveHidden: boolean = false;
  /** 推荐流 / 关注流各持一份滚动判定器（基线独立，防切 feed 互污）；初始隐藏态与 @State 同步 */
  private recImmersiveSensor: ImmersiveReadSensor = new ImmersiveReadSensor(false);
  private folImmersiveSensor: ImmersiveReadSensor = new ImmersiveReadSensor(false);
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
  /**
   * 关注动态剩余距离预取闸门（2026-09-19 口径修正）：偏移只取 `Scroller.currentOffset()` 真值，
   * 不再用 `onScroll` 回调入参（其语义在工具链间有差异，会让剩余距离恒小 → 预取乱触发或永不触发）。
   */
  private folPrefetchGate: PrefetchGate = new PrefetchGate(HOME_PREFETCH_DISTANCE, 'HomeTab.following');
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
  // 首页 feed 左右滑切的滑动锁：横向 PanGesture 起手即上锁、抬指延时解锁；锁住期间卡片各点按入口
  // 一律短路 —— 滑动手势收尾时手势仲裁仍可能给卡片派发 click，否则会出现「滑动切 feed 的同时打开帖子」
  private feedSwipeLock: boolean = false;
  private feedSwipeLockTimer: number = -1;
  // 首页预加载测量值：视口高（普通字段，避免 onAreaChange 高频回调触发 UI 重建）。
  // 内容高自 2026-09-19 单列档 List 化后无实测来源（List 是虚拟容器，onAreaChange 报视口高），
  // 单列与多列统一改走 feedContentH() 折算，故不再保留内容高字段。
  private homeViewportH: number = 0;
  // 滚动活动时间戳 + 缓存落盘合并（2026-09-19 流畅度优化）：
  // putWithTtl 内部 JSON.stringify 是全表同步序列化（数百条约 1–3ms）外加一次 flush 落盘，
  // 挂在翻页帧上会吃掉 120Hz 单帧预算的大半（用户感知为「顿一下」）。故改为：
  // 只记待写引用 + 单一定时器合并多次写入，并等滚动停止后再落盘。
  // 缓存只存展示快照（不含页码/游标），延后写入不影响冷启动恢复语义。
  private lastScrollAt: number = 0;
  private pendingCacheList: ThreadItem[] | null = null;
  private pendingCacheKey: string = '';
  private pendingCacheTtl: number = 0;
  private cacheWriteTimer: number = -1;
  /** 昵称回填滚动期顺延定时器（-1 = 无在途顺延） */
  private enrichApplyTimer: number = -1;
  // 首页预加载竞态：请求代际 token（刷新/切feed时递增，旧请求结果直接丢弃）
  private homePrefetchGate: PrefetchGate = new PrefetchGate(HOME_PREFETCH_DISTANCE, 'HomeTab.recommend');
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
    // §MEMLEVEL：向 AppStorage 注册关注流引擎实例，EntryAbility.onMemoryLevel 据此分发内存压力收缩
    AppStorage.setOrCreate<FollowFeedStore>('followFeedStore', this.followFeed);
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
    // 左右滑切 feed 的解锁延时器一并清理，避免回调落到已销毁组件
    if (this.feedSwipeLockTimer !== -1) {
      clearTimeout(this.feedSwipeLockTimer);
      this.feedSwipeLockTimer = -1;
    }
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
    if (!isAppend && old.length === next.length) {
      // 长度不变：若 tid 序列也一致，则属「就地内容更新」（点赞 / 昵称回填）——
      // 只对引用真正变化的项 notifyChange，避免整表 onDataReloaded 重建全部可见卡。
      // 单列档改 List 之前由 ForEach 按 key 精确 diff，此分支保持同等（甚至更细）的精度。
      let sameOrder: boolean = true;
      for (let i: number = 0; i < next.length; i++) {
        if (next[i].tid !== old[i].tid) {
          sameOrder = false;
          break;
        }
      }
      if (sameOrder) {
        ds.data = next;
        let touched: number = 0;
        for (let i: number = 0; i < next.length; i++) {
          if (next[i] !== old[i]) {
            ds.notifyChange(i);
            touched++;
          }
        }
        // P1 打点口径：等长同序 = 就地更新，只重建引用变化的项（成本比整表 reload 低一个量级）；
        // 与下面的整表 onDataReloaded 分开计数，真机才能区分两种成本
        if (touched > 0) {
          PerfTrace.mark('listTouch');
        }
        return;
      }
    }
    ds.data = next;
    if (isAppend) {
      ds.notifyAdd(old.length);
    } else {
      PerfTrace.mark('listSwap');
      ds.reload();
    }
  }

  /** threads 变化 → 同步到数据源（全量替换或尾部追加）+ 内容变化后补一次不满一屏判定 */
  private onThreadsChange(): void {
    this.syncSource(this.recDataSource, this.threads);
    this.slotSyncAfterDataChange(false);
    this.checkUnderfillPrefetch();
  }

  /** folThreads 变化 → 同步到数据源（全量替换或尾部追加）+ 内容变化后补一次不满一屏判定 */
  private onFolThreadsChange(): void {
    this.syncSource(this.folDataSource, this.folThreads);
    this.slotSyncAfterDataChange(true);
    this.checkUnderfillPrefetch();
  }

  /** 大屏竖 3 / 横 4（§4.2 决策 12）；阔直屏竖 1 / 横 3（阔直屏文档 §4.2，2026-09-17 用户改定）：同步 AppStorage 让 ThreadCard 内部图片封顶/摘要行数跟随 */
  private updateColumns(): void {
    try {
      const d: display.Display = display.getDefaultDisplaySync();
      const w: number = this.getUIContext().px2vp(d.width);
      const h: number = this.getUIContext().px2vp(d.height);
      // 阔直屏不依赖宽度阈值（横屏 ~830 < 840 过不了 md 档），列数只看横竖屏，竖屏回落手机单列档；
      // 大折叠竖 2 / 横 3（2026-09-17 用户改定，与平板同口径）；平板竖 2 / 横 3（原竖 3 / 横 4 作废）
      const next: number = isWideBarDevice() ? (w > h ? 3 : 1)
        : (w > h ? 3 : 2);
      // 同值不写 @State（2026-09-18 旋转丝滑）：本函数在旋转期经 display.on('change') 与
      // onAreaChange 两条路径都被调用，同值重写会让 this.columns 的消费方白重算一遍
      if (next !== this.columns) {
        this.columns = next;
      }
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
    // 列数档切换会换容器（WaterFlow ↔ Scroll），单列窗口一律回首屏
    this.slotReset(false);
    this.slotReset(true);
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
  /**
   * 同值短路（2026-09-18 旋转丝滑）：`cardColumns` 是全局单值、被所有 ThreadCard 的 `@StorageProp`
   * 订阅，**同值重写会白触发一遍全屏卡片重排**——而旋转期 `onAreaChange` / `display.on('change')`
   * 逐帧回调，这里每帧一次全局写正是掉帧主因。值未变则不写。
   * 与上面「无条件写」不矛盾：那说的是「单列也要写 1」（3→1 时值不同照写），不是「同值也写」。
   */
  private syncCardColumns(): void {
    const next: number = this.homeColumns();
    if (AppStorage.get<number>(CARD_COLUMNS_KEY) !== next) {
      AppStorage.setOrCreate(CARD_COLUMNS_KEY, next);
    }
  }

  /**
   * 列模板：**必须与 homeColumns() 单点同源**（2026-09-17 小窗修复）。
   * WaterFlow 的 columnsTemplate 曾直接绑 this.columns（display 推导值，小窗下恒 3）——
   * 分支入口 `homeColumns() > 1` 放行了中间档（600~840 → 2 列），模板却按 this.columns=3 铺 3 列，
   * 造成「中档小窗还是三列」。列数消费方一律走本函数 / homeColumns()，禁止直绑 this.columns。
   */
  private homeColumnsTemplate(): string {
    const n: number = this.homeColumns();
    // 单列档必须同为 1 列：模板与列数单点同源（历史上「模板直绑 this.columns」曾让中档小窗铺成 3 列）
    return n <= 1 ? '1fr' : n === 4 ? '1fr 1fr 1fr 1fr' : n === 2 ? '1fr 1fr' : '1fr 1fr 1fr';
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
   * 渐隐停靠点：所有形态统一只盖顶栏（2026-09-29 用户反馈：手机 15% 覆盖过多），
   * raw 直接取顶栏高度 HOME_TITLE_BAR_HEIGHT(108)（= 状态栏让位 + 按钮行 + 呼吸，即顶部胶囊底部）。
   */
  private updateFadeStop(viewportHeightVp: number): void {
    if (viewportHeightVp <= 0) {
      return;
    }
    const raw: number = HOME_TITLE_BAR_HEIGHT;
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
    // 换号：两条 feed 的预取节流基线一并清空（列表与偏移全部换新）
    this.folPrefetchGate.reset();
    this.homePrefetchGate.reset();
    // 推荐流「仅关注吧」过滤依赖账号关注集合：同样失效，切回推荐页时按新账号重新加载
    this.recommendLoaded = false;
  }

  /** 宿主 onPageShow：从详情页返回时用实时昵称回填当前列表（不重新请求网络） */
  private onPageTick(): void {
    this.refreshAuthorsFromCache();
  }

  /** 宿主底栏重复点击首页 Tab：整页刷新（按当前 feed 重拉第一页，与下拉刷新同一路径） */
  private onRetapTick(): void {
    // 回顶整页刷新：沉浸态一并复位（回顶后置顶保护也会兜底恢复显示）
    this.resetImmersive();
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

  /** 用详情页回填的作者昵称缓存刷新列表显示（不重新请求网络）。
   *  §P1-1（2026-09-29 丢帧治理）：`changed` 由「只打日志」升级为**短路条件** ——
   *  没有任何昵称需要回填时（返回宿主的大多数场景）直接 return、不写 @State。
   *  原先无条件 `updateCurrentThreads(map(...))` 会产出新数组引用 → 本组件 build 整树重跑
   *  → @Watch onThreadsChange → syncSource 全量比对，真机实测「详情页返回首页」窗口
   *  fps 74 / d33=2（全流程最稳定的掉帧点之一）。
   *  map 仍要跑完才知道有没有变化（纯内存遍历，微秒级），只是不再把结果写回状态。 */
  private refreshAuthorsFromCache(): void {
    const service = TiebaService.getInstance();
    let changed = false;
    const updated: ThreadItem[] = this.currentFeedThreads().map((t: ThreadItem): ThreadItem => {
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
    });
    if (!changed) {
      return;
    }
    this.updateCurrentThreads(updated);
    console.info('[AUTHORDIAG] 首页列表已用详情页昵称回填刷新');
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
      // isPrefetch=true：feed 补货语义同预取（后台供给），走短超时 Session 弱网快失败
      const r: PagedResult<ThreadItem> = await TiebaService.getInstance().fetchForumThreads(forumName, pg, st, false, 0, true);
      return r.list.slice(0, limit);
    } catch (e) {
      return [];
    }
  }

  /**
   * 缓存落盘调度（2026-09-19 流畅度优化）：合并多次写入 + 滚动空闲后再落盘。
   * 落盘内容与页码无关（缓存仅存展示快照），延后写入对冷启动恢复语义零影响；
   * 收益是把 JSON.stringify + flush 从翻页帧（120Hz 下每帧仅 8.3ms）挪到静止期。
   */
  private scheduleCacheWrite(key: string, list: ThreadItem[], ttlMs: number): void {
    this.pendingCacheKey = key;
    this.pendingCacheTtl = ttlMs;
    this.pendingCacheList = list;
    if (this.cacheWriteTimer !== -1) {
      clearTimeout(this.cacheWriteTimer);
    }
    this.cacheWriteTimer = setTimeout(() => {
      this.cacheWriteTimer = -1;
      this.flushCacheWrite();
    }, HOME_CACHE_WRITE_DELAY);
  }

  /** 空闲落盘：仍在滑行则顺延一轮，静止后再真正写入（最多多等一个 HOME_SCROLL_IDLE_MS） */
  private flushCacheWrite(): void {
    const list: ThreadItem[] | null = this.pendingCacheList;
    if (list === null) {
      return;
    }
    if (Date.now() - this.lastScrollAt < HOME_SCROLL_IDLE_MS) {
      this.cacheWriteTimer = setTimeout(() => {
        this.cacheWriteTimer = -1;
        this.flushCacheWrite();
      }, HOME_SCROLL_IDLE_MS);
      return;
    }
    const key: string = this.pendingCacheKey;
    const ttl: number = this.pendingCacheTtl;
    this.pendingCacheList = null;
    CacheManager.getInstance().putWithTtl(key, list, ttl).catch(() => {
    });
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
    // 注（2026-09-29 留痕）：曾在此加「滚动静默门闸」（推迟到停手后发起），真机实测
    // FRS 请求 -53% 但 `dec` 仅 -20%、长帧占比无改善，且门闸在连续滚动下会把任务全部
    // 丢弃（defer=10/run=0/drop=10）导致供给被饿死 → 已回退。
    // 教训：只推迟「请求发起」无效——回包仍在滚动中到达；要治必须推迟「回包处理」。
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
  /** 「帖子极速开启」feed 首屏预取调度：800ms 防抖（避开 feed 请求与首屏渲染），前 3 卡去重预取（开关关闭时服务层短路） */
  private feedPrefetchTimer: number = -1;
  private scheduleFeedPrefetch(): void {
    if (this.feedPrefetchTimer >= 0) {
      clearTimeout(this.feedPrefetchTimer);
    }
    this.feedPrefetchTimer = setTimeout(() => {
      this.feedPrefetchTimer = -1;
      TiebaService.getInstance().prefetchFeedTopThreads(this.currentFeedThreads());
    }, 800);
  }

  /** 「帖子极速开启」滑动停歇预取：最近可见区间（onScrollIndex）与手指按下 y（onTouch Down） */
  private lastVisStart: number = 0;
  private lastVisEnd: number = 0;
  private lastPausePressY: number = -1;
  private lastVisFollow: boolean = false;
  private swipePrefetchTimer: number = -1;

  /** 记录可见 item 区间（WaterFlow 的 onScrollIndex 回调通用；单列 Scroll 档由 slotUpdateWindow 写入） */
  private onFeedVisibleRange(useFollow: boolean, start: number, end: number): void {
    this.lastVisFollow = useFollow;
    this.lastVisStart = start;
    this.lastVisEnd = end;
  }

  // ===== 单列档窗口化挂载 v2（2026-09-29「首页顶部卡片整层消失」根治）=====
  // 与 docs/floor-vanish-viewport-fix.md 同源问题：List 虚拟容器的视口剔除窗口与
  // clip(false)+expandSafeArea(TOP) 的沉浸绘制区错位，卡片滚入顶栏区被整层剔除不绘制
  // （ThreadDetail 当年在底部 / 首页在顶部，两例互为镜像；探针 A/B 均无法消除 → 容器根治）。
  // 单列档 List → Scroll + Column 全量布局 + 窗口化挂载（ThreadList 2026-09-28 v2 同款）：
  // ForEach 遍历全量列表（key 稳定不移位），窗口内真卡 / 窗外等高轻量占位，
  // 等价 LazyForEach 的边缘增量挂载，但 Scroll 无任何视口剔除机制。
  /**
   * 挂载缓冲：可见区上下各「必须挂载」的张数。视口距窗口边界小于该值即视为贴边，必须推进。
   * 取 4（约 1500vp）：甩滑一帧最多移动百来 vp，足够安全，同时把单次推进量压到最小。
   */
  private readonly SLOT_BUFFER: number = 4;
  /**
   * 扩展目标：贴边后一次性把窗口扩到「可见区 ± SLOT_EXTEND」（而非紧贴挂载边界）。
   * 真机第二轮实测证明：若扩展只跟随挂载边界（=SLOT_BUFFER），会变成**每帧推进一次**
   * （win 25 次/2s，每秒十余次整列 diff + 重布局），持续掉帧比大步长推进更难忍。
   * 单次新建张数 = SLOT_EXTEND − SLOT_BUFFER，推进间隔张数亦同 —— 这一对常量决定
   * 「单帧创建量 ⇄ 推进频率」的取舍（5 张 ≈ 35ms / 每滑 5 张一次）。
   */
  private readonly SLOT_EXTEND: number = 9;
  /**
   * 卸载滞后：可见区上下各「允许保留」的真卡张数，超出才降级回等高占位。
   * 与 SLOT_EXTEND 的差值（6 张）= 一次收缩最多卸载的张数；同时让反向回滑
   * （用户刚滑过的卡仍在保留带内）直接命中已挂载真卡，零重建。
   */
  private readonly SLOT_KEEP: number = 15;
  /** 首屏初始挂载数 */
  private readonly SLOT_INITIAL: number = 12;
  /** 实测卡高表容量上限（提高到 1200：长距离下滑后回滑仍能命中实测值，避免退化到估算） */
  private readonly SLOT_HEIGHT_CAP: number = 1200;
  /** 实测卡高表（vp，键=tid；推荐/关注两 feed 共享，同帖高度一致） */
  private slotHeightMap: Map<string, number> = new Map<string, number>();
  /** 未实测卡的估算高（vp）：以实测值 EMA 收敛（初值取图文/纯文字卡中间偏保守） */
  private slotAvgH: number = 340;
  /** 高度表版本号：任何卡高变化即递增，用于前缀和缓存失效 */
  private slotHeightVer: number = 0;
  /** 每 feed 独立窗口（两 feed 常驻同树，不能共用一份窗口态） */
  @State private recSlotStart: number = 0;
  @State private recSlotEnd: number = 11;
  @State private folSlotStart: number = 0;
  @State private folSlotEnd: number = 11;
  /** 前缀和缓存（每 feed 一份）：pre[i] = 第 i 张卡的顶部 y（pre[0]=0） */
  private recPreCache: number[] = [0];
  private recPreSrc: ThreadItem[] | undefined = undefined;
  private recPreVer: number = -1;
  private folPreCache: number[] = [0];
  private folPreSrc: ThreadItem[] | undefined = undefined;
  private folPreVer: number = -1;
  /** 诊断（HSLOT_DIAG）：首次实测卡高与当时估算值的偏差累计，随窗口推进一并输出并清零 */
  private diagErrSum: number = 0;
  private diagErrN: number = 0;
  private diagErrMax: number = 0;
  /** 诊断：GAP 打点限流时间戳（越界可能连续多帧成立） */
  private diagGapAt: number = 0;
  /**
   * 内容特征桶均值（滚动中自校准）：键 = 图片数_标题行数_摘要行数。
   * 未实测卡优先取「同特征卡」的实测均值，比单一 EMA 均值准一个量级 ——
   * 真机 FSTAT 证明「占位高 ≠ 真卡高」引发的布局重排与内容位移，才是滚动抽搐、
   * 回滑露白的直接来源（errN 高的窗口其最差帧是 errN≈0 窗口的 4 倍）。
   */
  private slotBucketH: Map<string, number> = new Map<string, number>();

  private slotList(useFollow: boolean): ThreadItem[] {
    return useFollow ? this.folThreads : this.threads;
  }

  private slotHeightOf(item: ThreadItem): number {
    const h: number | undefined = this.slotHeightMap.get(item.tid);
    return h !== undefined ? h : this.estimateCardHeight(item);
  }

  /** 未实测卡估算：优先同特征桶实测均值，缺样本时用结构公式打底（自校准，无需人工调参） */
  private estimateCardHeight(item: ThreadItem): number {
    const learned: number | undefined = this.slotBucketH.get(this.slotBucketKey(item));
    if (learned !== undefined) {
      return learned;
    }
    return this.slotFormulaHeight(item);
  }

  /** 特征键：图片数_标题行数_摘要行数（同键卡的实际高度高度一致，故桶均值可用作占位高） */
  private slotBucketKey(item: ThreadItem): string {
    const ic: number = item.images !== undefined ? Math.min(item.images.length, 9) : 0;
    const scale: number = this.fontScale > 0 ? this.fontScale : 1.0;
    const lineW: number = this.slotLineWidth();
    const tl: number = this.slotTextLines(item.title, 17 * scale, lineW, 2);
    const al: number = item.abstract.length > 0 ? this.slotTextLines(item.abstract, 14 * scale, lineW, 4) : 0;
    return `${ic}_${tl}_${al}`;
  }

  /** 文本可用宽 = 屏宽 − 列表左右留白(Spacing.lg×2) − 卡内左右内距(16×2) */
  private slotLineWidth(): number {
    const w: number = this.pageWidth > 0 ? this.pageWidth : 360;
    return Math.max(120, w - Spacing.lg * 2 - 32);
  }

  /** 文本行数估算：CJK 按 1 字宽、其余约 0.55 字宽；clamp 到 maxLines（误差 1 行内可接受） */
  private slotTextLines(text: string, fontSize: number, availW: number, maxLines: number): number {
    if (text.length === 0) {
      return 1;
    }
    let units: number = 0;
    for (let i: number = 0; i < text.length; i++) {
      units += text.charCodeAt(i) > 0x2E80 ? 1 : 0.55;
    }
    const lines: number = Math.ceil((units * fontSize) / Math.max(1, availW));
    return Math.max(1, Math.min(maxLines, lines));
  }

  /** 图片区高度（单列档，含 top 10）：1 张 220；2/4 张两列 140；其余三列 100（行间 8vp） */
  private slotGalleryHeight(count: number): number {
    if (count <= 0) {
      return 0;
    }
    if (count === 1) {
      return 10 + 220;
    }
    const twoCol: boolean = count === 2 || count === 4;
    const cell: number = twoCol ? 140 : 100;
    const rows: number = Math.ceil(count / (twoCol ? 2 : 3));
    return 10 + rows * cell + (rows - 1) * 8;
  }

  /** 结构公式（桶无样本时的兜底）：逐项复刻 ThreadCard 的真实组成 */
  private slotFormulaHeight(item: ThreadItem): number {
    const scale: number = this.fontScale > 0 ? this.fontScale : 1.0;
    const lineW: number = this.slotLineWidth();
    let h: number = 16 + 40;
    const tl: number = this.slotTextLines(item.title, 17 * scale, lineW, 2);
    h += 8 + tl * 17 * scale * 1.45;
    if (item.abstract.length > 0) {
      const al: number = this.slotTextLines(item.abstract, 14 * scale, lineW, 4);
      h += 6 + al * 14 * scale * 1.5;
    }
    const ic: number = item.images !== undefined ? Math.min(item.images.length, 9) : 0;
    h += this.slotGalleryHeight(ic);
    if (item.forumName.length > 0) {
      h += 10 + 20;
    }
    h += 12 + 36 + 14;
    return h;
  }

  /** 窗口外占位块高度 = 区间 [from, to) 内卡高之和（卡间 space 由 Column 的 space 承担） */
  private slotRangeHeight(useFollow: boolean, from: number, to: number): number {
    const pre: number[] = this.slotPrefixSums(useFollow);
    const last: number = pre.length - 1;
    const a: number = from >= 0 && from <= last ? pre[from] : 0;
    const b: number = to >= 0 && to <= last ? pre[to] : pre[last];
    return Math.max(0, b - a);
  }

  /** 卡高采集（持续更新）。仅窗口内真卡挂回调 → 观察者 O(窗口)。
   *  不锁首测：图片失败降级 ↔ 自愈会改变卡高，占位必须跟上，否则回滑时错位。
   *  同时把实测值回灌「同特征桶」（EMA），供未实测卡做占位高。 */
  private slotRecordHeight(item: ThreadItem, h: number): void {
    if (h <= 0 || h > 2000) {
      return;
    }
    const tid: string = item.tid;
    const prev: number | undefined = this.slotHeightMap.get(tid);
    if (prev !== h) {
      if (HSLOT_DIAG && prev === undefined) {
        // 首次实测：与「占位实际使用的估算值」（桶均值/结构公式）比对，量化占位高 ≠ 真卡高
        const est: number = this.estimateCardHeight(item);
        const d: number = h - est;
        this.diagErrSum += Math.abs(d);
        this.diagErrN++;
        if (Math.abs(d) > this.diagErrMax) {
          this.diagErrMax = Math.abs(d);
        }
        if (Math.abs(d) > 60) {
          hilog.info(0x0000, HSLOT_TAG,
            'HEST tid=%{public}s est=%{public}d real=%{public}d d=%{public}d map=%{public}d',
            tid, Math.round(est), Math.round(h), Math.round(d), this.slotHeightMap.size);
        }
      }
      this.slotHeightMap.set(tid, h);
      this.slotHeightVer++;
      this.slotAvgH = this.slotAvgH * 0.9 + h * 0.1;
      const key: string = this.slotBucketKey(item);
      const bk: number | undefined = this.slotBucketH.get(key);
      this.slotBucketH.set(key, bk === undefined ? h : bk * 0.7 + h * 0.3);
    }
    if (this.slotHeightMap.size > this.SLOT_HEIGHT_CAP) {
      let oldest: string | undefined = undefined;
      for (const k of this.slotHeightMap.keys()) {
        oldest = k;
        break;
      }
      if (oldest !== undefined) {
        this.slotHeightMap.delete(oldest);
      }
    }
  }

  /** 前缀和：pre[i] = 第 i 张卡的顶部 y。带缓存：仅在列表引用或高度表变化时重算 */
  private slotPrefixSums(useFollow: boolean): number[] {
    const list: ThreadItem[] = this.slotList(useFollow);
    const src: ThreadItem[] | undefined = useFollow ? this.folPreSrc : this.recPreSrc;
    const ver: number = useFollow ? this.folPreVer : this.recPreVer;
    if (src === list && ver === this.slotHeightVer) {
      return useFollow ? this.folPreCache : this.recPreCache;
    }
    const pre: number[] = new Array<number>(list.length + 1);
    pre[0] = 0;
    for (let i = 0; i < list.length; i++) {
      pre[i + 1] = pre[i] + this.slotHeightOf(list[i]);
    }
    if (useFollow) {
      this.folPreCache = pre;
      this.folPreSrc = list;
      this.folPreVer = this.slotHeightVer;
    } else {
      this.recPreCache = pre;
      this.recPreSrc = list;
      this.recPreVer = this.slotHeightVer;
    }
    return pre;
  }

  /** 滚动中推进窗口（onScroll 每帧调用）：①双向滞回——只有可见区贴住「必须挂载边界」才扩展、
   *  越过「保留边界」才收缩（卸载滞后），单次推进量上限 = 2×(SLOT_KEEP − SLOT_BUFFER)，
   *  把原本一次 50~75ms 的冻结帧拆成几帧小重建（真机 FSTAT 实测归因，2026-09-30）；
   *  ②前缀和走缓存，滚动帧零 O(N) 计算。同时把可见区间写入 lastVis*（停歇预取沿用，
   *  替代 List.onScrollIndex 的可见区间来源）。 */
  private slotUpdateWindow(useFollow: boolean, atY: number): void {
    const list: ThreadItem[] = this.slotList(useFollow);
    const n: number = list.length;
    const vh: number = useFollow ? this.folViewportH : this.homeViewportH;
    if (n === 0 || vh <= 0) {
      return;
    }
    const t0: number = HSLOT_DIAG ? Date.now() : 0;
    const pre: number[] = this.slotPrefixSums(useFollow);
    const preMs: number = HSLOT_DIAG ? Date.now() - t0 : 0;
    const bottom: number = atY + vh;
    let vs: number = 0;
    while (vs < n - 1 && pre[vs + 1] <= atY) {
      vs++;
    }
    let ve: number = vs;
    while (ve < n - 1 && pre[ve + 1] <= bottom) {
      ve++;
    }
    this.lastVisFollow = useFollow;
    this.lastVisStart = vs;
    this.lastVisEnd = ve;
    const s: number = useFollow ? this.folSlotStart : this.recSlotStart;
    const e: number = useFollow ? this.folSlotEnd : this.recSlotEnd;
    // 必须挂载边界（可见区 ± SLOT_BUFFER）：视口内不得出现占位
    const mountS: number = Math.max(0, vs - this.SLOT_BUFFER);
    const mountE: number = Math.min(n - 1, ve + this.SLOT_BUFFER);
    // 扩展目标（可见区 ± SLOT_EXTEND）：贴边时一次性扩到这里，给足余量避免每帧跟随式推进
    const extS: number = Math.max(0, vs - this.SLOT_EXTEND);
    const extE: number = Math.min(n - 1, ve + this.SLOT_EXTEND);
    // 保留边界（可见区 ± SLOT_KEEP）：越过才收缩（卸载滞后，回滑路径上刚看过的卡不重建）
    const keepS: number = Math.max(0, vs - this.SLOT_KEEP);
    const keepE: number = Math.min(n - 1, ve + this.SLOT_KEEP);
    let ns: number = s;
    let ne: number = e;
    // ① 贴住挂载边界 → 扩展到目标（单帧创建量 = SLOT_EXTEND − SLOT_BUFFER）
    if (s > mountS) {
      ns = extS;
    }
    if (e < mountE) {
      ne = extE;
    }
    // ② 卸载滞后：越过保留带才收缩，且一次收到扩展目标（避免小步反复收）
    if (ns < keepS) {
      ns = extS;
    }
    if (ne > keepE) {
      ne = extE;
    }
    // ③ 覆盖兜底：任何情况下视口都不得落到占位区
    if (ns > mountS) {
      ns = mountS;
    }
    if (ne < mountE) {
      ne = mountE;
    }
    if (HSLOT_DIAG && (vs < ns || ve > ne)) {
      // 可见区越出新窗口 = 视口内存在「等高占位」而非真卡 → 用户看到的空白/内容缺失
      const now: number = Date.now();
      if (now - this.diagGapAt > 200) {
        this.diagGapAt = now;
        hilog.info(0x0000, HSLOT_TAG,
          'GAP vis=%{public}d..%{public}d win=%{public}d..%{public}d atY=%{public}d vh=%{public}d n=%{public}d',
          vs, ve, ns, ne, atY, vh, n);
      }
    }
    if (ns !== s || ne !== e) {
      // P0-2 归因打点：窗口真正推进 = 一次页面级重渲染（只在实际推进分支计数，静止帧零开销）
      PerfTrace.mark('winSlide');
      if (useFollow) {
        this.folSlotStart = ns;
        this.folSlotEnd = ne;
      } else {
        this.recSlotStart = ns;
        this.recSlotEnd = ne;
      }
      if (HSLOT_DIAG) {
        const errAvg: number = this.diagErrN > 0 ? Math.round(this.diagErrSum / this.diagErrN) : 0;
        // mount = 本次推进新挂载（占位→真卡）张数，直接反映这一帧的重建负荷
        const mount: number = (ns < s ? s - ns : 0) + (ne > e ? ne - e : 0);
        // imgs = 新挂载卡携带的图片总数（宫格 Image 组件数），用于区分「组件创建」与「图片加载/解码」谁在吃帧
        let imgs: number = 0;
        for (let i: number = ns; i <= ne && i < n; i++) {
          if (i >= s && i <= e) {
            continue;
          }
          const it: ThreadItem | undefined = list[i];
          if (it !== undefined && it.images !== undefined) {
            imgs += it.images.length;
          }
        }
        hilog.info(0x0000, HSLOT_TAG,
          'SLIDE vis=%{public}d..%{public}d win=%{public}d..%{public}d->%{public}d..%{public}d mount=%{public}d imgs=%{public}d out=%{public}d preMs=%{public}d atY=%{public}d vh=%{public}d n=%{public}d errN=%{public}d errAvg=%{public}d errMax=%{public}d avg=%{public}d',
          vs, ve, s, e, ns, ne, mount, imgs, (vs < ns || ve > ne) ? 1 : 0, preMs,
          atY, vh, n, this.diagErrN, errAvg, Math.round(this.diagErrMax), Math.round(this.slotAvgH));
        this.diagErrSum = 0;
        this.diagErrN = 0;
        this.diagErrMax = 0;
      }
    }
  }

  /** 窗口复位（回顶刷新 / 数据换血 / 列数档切换）：回首屏挂载量；卡高表保留（同帖高度可复用） */
  private slotReset(useFollow: boolean): void {
    if (useFollow) {
      this.folSlotStart = 0;
      this.folSlotEnd = this.SLOT_INITIAL - 1;
    } else {
      this.recSlotStart = 0;
      this.recSlotEnd = this.SLOT_INITIAL - 1;
    }
  }

  /** 数据变化后窗口自纠：列表缩短（刷新换血 / 数据失效重拉）时窗口可能越界 → 复位并按当前偏移重定位 */
  private slotSyncAfterDataChange(useFollow: boolean): void {
    const n: number = this.slotList(useFollow).length;
    const e: number = useFollow ? this.folSlotEnd : this.recSlotEnd;
    if (n === 0 || e >= n) {
      this.slotReset(useFollow);
      const scroller: Scroller = useFollow ? this.folScroller : this.homeScroller;
      this.slotUpdateWindow(useFollow, PrefetchGate.absoluteY(scroller));
    }
  }

  /** 记录手指按下 y（按下让滑动暂停时，预取"最接近按下位置"的卡） */
  private onFeedTouchRecord(event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.lastPausePressY = event.touches[0].y;
    }
  }

  /** 滚动重新开始时取消待发的停歇预取（用户继续滑就不该预取旧停点），并上报服务层「滚动活跃」 */
  private onFeedScrollStart(): void {
    if (this.swipePrefetchTimer >= 0) {
      clearTimeout(this.swipePrefetchTimer);
      this.swipePrefetchTimer = -1;
    }
    TiebaService.getInstance().notifyFeedScrolling(true);
  }

  /**
   * 滑动停歇（onScrollStop：按下暂停滑动 / 惯性结束 / 松手无惯性）后 600ms 防抖，
   * 取可见区间内「最接近手指按下位置」的 3 卡预取（开关关闭时服务层 prefetchFeedTopThreads
   * 入口直接短路；getItemRect 不支持该容器时回退为"可见区中段优先"的兜底距离）。
   * 2026-09-20 滑动让路：停止即上报服务层，600ms 防抖 ≥ 服务层 500ms 静默阈值 ——
   * 预取真正启动时必然已过滚动余波窗口；滚动恢复由 onScrollStart 取消并置活跃标记。
   */
  private onFeedScrollStop(useFollow: boolean): void {
    TiebaService.getInstance().notifyFeedScrolling(false);
    if (this.swipePrefetchTimer >= 0) {
      clearTimeout(this.swipePrefetchTimer);
    }
    this.swipePrefetchTimer = setTimeout(() => {
      this.swipePrefetchTimer = -1;
      const list: ThreadItem[] = useFollow ? this.folThreads : this.threads;
      if (list.length === 0) {
        return;
      }
      const start: number = Math.max(0, this.lastVisStart);
      const end: number = Math.min(list.length - 1, this.lastVisEnd);
      if (end < start) {
        return;
      }
      const pressY: number = this.lastPausePressY;
      const scroller: Scroller = useFollow ? this.folScroller : this.homeScroller;
      const cands: ThreadItem[] = [];
      for (let i: number = start; i <= end && i < list.length && cands.length < 3; i++) {
        cands.push(list[i]);
      }
      if (pressY >= 0) {
        // 单列档（Scroll+窗口化挂载）：getItemRect 对 Scroll 不可靠，用前缀和精确算卡中心视口 y
        // （pressY 为视口本地 y，卡中心视口 y = pre[i] + h/2 − atY）
        // 单列档现在也走 WaterFlow（getItemRect 可用），只有回退路径才用前缀和几何
        const single: boolean = !HOME_SINGLE_USE_WATERFLOW && this.homeColumns() === 1;
        const pre: number[] = single ? this.slotPrefixSums(useFollow) : [];
        const atY: number = this.homeScrollY;
        const scored: ScoredThread[] = [];
        for (let i: number = start; i <= end && i < list.length; i++) {
          let d: number = Math.abs(i - (start + end) / 2) * 1000;
          if (single) {
            d = Math.abs((pre[i] + this.slotHeightOf(list[i]) / 2) - (atY + pressY));
          } else {
            try {
              const rect: RectResult = scroller.getItemRect(i);
              d = Math.abs((rect.y + rect.height / 2) - pressY);
            } catch (e) {
              // getItemRect 不支持该容器时用"可见区中段优先"兜底距离
            }
          }
          scored.push({ it: list[i], d: d });
        }
        scored.sort((a: ScoredThread, b: ScoredThread): number => a.d - b.d);
        TiebaService.getInstance().prefetchFeedTopThreads(scored.map((s: ScoredThread): ThreadItem => s.it));
        return;
      }
      TiebaService.getInstance().prefetchFeedTopThreads(cands);
    }, 600);
  }

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
    // 预取节流基线同步复位：列表整体换新，沿用旧偏移基线会漏触发
    this.homePrefetchGate.reset();
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
          this.scheduleFeedPrefetch();
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
      this.scheduleFeedPrefetch();
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
        // 落盘改走合并 + 滚动空闲调度：不再 await，避免首屏渲染帧上做全表序列化 + flush
        this.scheduleCacheWrite(CACHE_KEY.THREAD_LIST, list, CACHE_TTL.THREAD_LIST);
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
      this.scheduleFeedPrefetch();
      if (this.shouldOnlyFollow()) {
        this.followFeed.markConsumed(this.threads);
      }
      this.homeHasMore = this.threads.length > 0;
      this.homeStalledPages = 0;
      this.enrichHomeInBackground(this.threads);
      this.scheduleCacheWrite(CACHE_KEY.THREAD_LIST, this.threads, CACHE_TTL.THREAD_LIST);
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
    // 注（2026-09-29 留痕）：曾在此加「滚动静默门闸」推迟网络发起，真机实测 ENRICH -70%
    // 但长帧无改善 → 已回退（理由同 kickPoolRefill；回包处理才是代价所在）。
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
      // 复用富化入口（apply + 递归调度语义与原内联实现逐项一致）
      this.enrichHomeInBackground(snapshot);
    }, 4000);
  }

  /** 将校准结果按 authorId diff 更新到当前列表（兼容校准期间已加载更多）。 */
  private applyEnrichedAuthors(enriched: ThreadItem[]): void {
    // 回填会走 syncSource → reload()（长度不变不判为追加）→ 可见卡整体重建，
    // 滑行中重建正是「滑动顿挫」的来源之一；故滚动期内顺延到静止后再应用（内容不会丢）。
    if (Date.now() - this.lastScrollAt < HOME_SCROLL_IDLE_MS) {
      if (this.enrichApplyTimer !== -1) {
        clearTimeout(this.enrichApplyTimer);
      }
      this.enrichApplyTimer = setTimeout(() => {
        this.enrichApplyTimer = -1;
        this.applyEnrichedAuthors(enriched);
      }, HOME_SCROLL_IDLE_MS);
      return;
    }
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
        // 去 await：落盘不再占住翻页帧，homeLoadingMore 锁也能更早释放（触底反馈更跟手）
        this.scheduleCacheWrite(CACHE_KEY.THREAD_LIST, this.threads, CACHE_TTL.THREAD_LIST);
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
    // 切 feed：沉浸判定基线随目标 feed 重置（恢复滚动位置的 scrollTo 由跳变保护兜底，不会误判方向）
    this.recImmersiveSensor.resetBaseline();
    this.folImmersiveSensor.resetBaseline();
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
        // 单列档回退路径：恢复偏移后立刻把可见窗口推到目标位置（防恢复位全是占位）；
        // WaterFlow 路径由 LazyForEach 自管，无需外部推进
        if (!HOME_SINGLE_USE_WATERFLOW && this.homeColumns() === 1) {
          this.slotUpdateWindow(feed === HomeFeed.Following, targetY);
        }
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
        // 单列档：回顶即窗口回首屏（刷新换血后由 slotSyncAfterDataChange 兜底）
        this.slotReset(true);
      }
      this.loadFollowingThreads();
    } else {
      if (this.loadState === LoadState.Success) {
        this.homeScroller.scrollEdge(Edge.Top);
        this.slotReset(false);
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
    // 预取节流基线同步复位：列表整体换新，沿用旧偏移基线会漏触发
    this.folPrefetchGate.reset();
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
  private onHomeScroll(_x: number, _y: number): void {
    // P0-2 归因打点：只记一个时间戳（普通字段，零分配零重建），供 FSTAT 判定「本窗口是否在滚动」
    PerfTrace.noteScroll();
    // 滚动活动时间戳：缓存落盘与昵称回填都以「距上次滚动时长」判空闲（写普通字段，不触发 UI 重建）
    this.lastScrollAt = Date.now();
    // 偏移取 Scroller 真值（onScroll 回调入参语义在工具链间有差异，非绝对偏移会让剩余距离恒小）
    const atY: number = PrefetchGate.absoluteY(
      this.homeFeed === HomeFeed.Following ? this.folScroller : this.homeScroller);
    // 无条件记录当前 feed 浏览位置（切走/切回时恢复）：存绝对偏移，恢复时 scrollTo 才准
    this.homeScrollY = atY;
    // 沉浸式阅读补全：方向判定（先于预取的 early-return，保证任何滚动都参与判定）
    this.feedImmersiveScroll(atY);
    // 单列档窗口化挂载（仅在 HOME_SINGLE_USE_WATERFLOW=false 的回退路径下存在）：
    // WaterFlow 走 LazyForEach 自管可见区，不需要也不允许外部推进窗口
    if (!HOME_SINGLE_USE_WATERFLOW && this.homeColumns() === 1) {
      this.slotUpdateWindow(this.homeFeed === HomeFeed.Following, atY);
    }
    if (this.homeFeed === HomeFeed.Following) {
      this.folScrollY = atY;
    } else {
      this.recommendScrollY = atY;
    }
    if (this.homeFeed === HomeFeed.Following) {
      // 关注动态预加载：使用关注流独立测量值与状态
      if (this.folState !== LoadState.Success || this.folLoadingMore || !this.folHasMore) {
        return;
      }
      if (this.folPrefetchGate.should(atY, this.feedContentH(true), this.folViewportH)) {
        this.loadMoreFollowingThreads(true);
      }
    } else {
      if (this.loadState !== LoadState.Success || this.homeLoadingMore || !this.homeHasMore) {
        return;
      }
      if (this.homePrefetchGate.should(atY, this.feedContentH(false), this.homeViewportH)) {
        this.loadMoreHomeThreads(true);
      }
    }
  }

  // ===== 「沉浸式阅读补全」交互（2026-09-29，设置 → 个性化 / AppStorage `immersiveReadExtra`）=====

  /**
   * 当前 feed 的滚动 → 沉浸显隐判定。挂点 = 4 个 feed 容器共用的 onHomeScroll（位置真源已取 Scroller）。
   * 规则与 ThreadDetail 逐项同源（24 藏 / 12 露不对称 + 置顶 8 恒显示 + 跳变 240 丢弃），
   * 判定器按 feed 各持一份（基线独立，防切 feed 互污）。
   */
  private feedImmersiveScroll(atY: number): void {
    if (!this.immersiveReadExtra) {
      // 开关关闭：确保处于显示态（设置页关闭开关路径由 @Watch 兜底，此处防漏网）
      if (this.immersiveHidden) {
        this.setImmersiveHidden(false);
      }
      return;
    }
    const sensor: ImmersiveReadSensor =
      this.homeFeed === HomeFeed.Following ? this.folImmersiveSensor : this.recImmersiveSensor;
    const act = sensor.feed(atY);
    if (act === 'hide') {
      this.setImmersiveHidden(true);
    } else if (act === 'show' || act === 'reset') {
      this.setImmersiveHidden(false);
    }
  }

  /**
   * 翻转沉浸态：顶部胶囊（本地 @State）+ 宿主底栏（AppStorage 驱动键，仅当前 Tab 才写）。
   * 值变化才写，滚动回调高频触发不会逐帧打 AppStorage。
   */
  private setImmersiveHidden(hidden: boolean): void {
    if (this.immersiveHidden === hidden) {
      return;
    }
    this.immersiveHidden = hidden;
    this.recImmersiveSensor.setHidden(hidden);
    this.folImmersiveSensor.setHidden(hidden);
    // TabIndex.Home = 0（Index.ets 私有枚举，此处以数值对齐）
    if (this.currentMainTab === 0) {
      AppStorage.setOrCreate<boolean>('mainBarImmersiveHidden', hidden);
    }
  }

  /** 复位沉浸判定（切 feed / 回顶整页刷新 / 切 Tab 回来）：清基线 + 恢复显示（静默，不带动画判定） */
  private resetImmersive(): void {
    this.recImmersiveSensor.resetBaseline();
    this.folImmersiveSensor.resetBaseline();
    if (this.immersiveHidden) {
      this.immersiveHidden = false;
      this.recImmersiveSensor.setHidden(false);
      this.folImmersiveSensor.setHidden(false);
      if (this.currentMainTab === 0) {
        AppStorage.setOrCreate<boolean>('mainBarImmersiveHidden', false);
      }
    }
  }

  /** 设置开关变化（@Watch）：关掉开关立即恢复显示 */
  private onImmersiveExtraChanged(): void {
    if (!this.immersiveReadExtra) {
      this.resetImmersive();
    }
  }

  /** 当前主 Tab 变化（@Watch）：切走时本地态复位（底栏由 Index.switchTab 复位兜底）；切回时重建基线 */
  private onCurrentMainTabChanged(): void {
    if (this.currentMainTab === 0) {
      this.resetImmersive();
    } else {
      // 离开首页：只清基线，隐藏态交由 Index.switchTab 统一复位（此处不写宿主键，防覆盖其它 Tab 判定）
      this.recImmersiveSensor.resetBaseline();
      this.folImmersiveSensor.resetBaseline();
    }
  }

  /** 顶部胶囊隐藏位移（vp，向上）：= 官方标题栏高 108 × 0.6 ≈ −65（同「收回」口径，其余交给 opacity） */
  private homeTopSink(): number {
    return -(HOME_TITLE_BAR_HEIGHT * IMMERSIVE_EXTRA_FLY_SCALE);
  }

  /** 显隐动画参数（藏 / 唤不对称）：取值以目标态为准（immersiveHidden 本帧渲染前已写入） */
  private homeImmersiveAnim(): AnimateParam {
    if (this.immersiveHidden) {
      return { duration: IMMERSIVE_EXTRA_HIDE_MS, curve: Curve.EaseIn };
    }
    return {
      duration: IMMERSIVE_EXTRA_SHOW_MS,
      curve: curves.springMotion(IMMERSIVE_EXTRA_SPRING_RESPONSE, IMMERSIVE_EXTRA_SPRING_DAMPING)
    };
  }

  /**
   * feed 内容总高（供预取判定，vp）：单列与多列**统一折算**。
   * 2026-09-19 单列档 List 化后不再有「内容层 Column」可测内容总高（List 是虚拟容器，
   * 其 onAreaChange 报的是视口高），故单列档也改用估算（本工程 Favorite 单列档同款算法）。
   */
  private feedContentH(following: boolean): number {
    const cols: number = Math.max(1, this.homeColumns());
    const count: number = following ? this.folThreads.length : this.threads.length;
    const availW: number = Math.max(160, this.pageWidth - Spacing.lg * 2 - Spacing.md * (cols - 1));
    return PrefetchGate.estimateWaterfallContentH(count, cols, availW, Spacing.md);
  }

  /**
   * 内容不足一屏时直接预取下一页：无滚动 → onScroll / onReachEnd 都不会触发，
   * 因此改由「数据更新（@Watch）」与「视口变化」两个时机主动补判（接替原内容层 onAreaChange 挂点）。
   * 并发由 homeLoadingMore / folLoadingMore 锁挡住，内容枯竭由空轮保护收尾。
   */
  private checkUnderfillPrefetch(): void {
    if (this.homeFeed === HomeFeed.Following) {
      if (this.folThreads.length > 0 && !this.folLoadingMore && this.folHasMore
        && this.folViewportH > 0 && this.feedContentH(true) <= this.folViewportH) {
        this.loadMoreFollowingThreads(true);
      }
      return;
    }
    if (this.threads.length > 0 && !this.homeLoadingMore && this.homeHasMore
      && this.homeViewportH > 0 && this.feedContentH(false) <= this.homeViewportH) {
      this.loadMoreHomeThreads(true);
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
    // 视口变化后补一次「不满一屏」判定（首屏 / 旋转 / 切 feed 后可能既不滚动也无触底事件）
    this.checkUnderfillPrefetch();
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

  /** 左右滑切 feed · 起手锁：横向 Pan 一识别就先锁住卡片点按（覆盖滑动收尾仍派发 click 的窗口） */
  private lockFeedSwipe(): void {
    this.feedSwipeLock = true;
    if (this.feedSwipeLockTimer !== -1) {
      clearTimeout(this.feedSwipeLockTimer);
      this.feedSwipeLockTimer = -1;
    }
  }

  /** 左右滑切 feed · 延时解锁：抬指/取消后等 click 派发窗口过去，再放开卡片点按 */
  private unlockFeedSwipeDelayed(): void {
    if (this.feedSwipeLockTimer !== -1) {
      clearTimeout(this.feedSwipeLockTimer);
    }
    this.feedSwipeLockTimer = setTimeout(() => {
      this.feedSwipeLockTimer = -1;
      this.feedSwipeLock = false;
    }, HOME_FEED_SWIPE_UNLOCK_DELAY);
  }

  /** 左右滑动手势切换首页 feed：左滑 → 关注动态，右滑 → 推荐；动画期间锁防连滑错乱
   *  PanGesture.onActionEnd 的 offsetX 为水平总位移：负值=左滑，正值=右滑 */
  private onHomeFeedPanEnd(event: GestureEvent): void {
    if (this.homeFeedSwitching) {
      return;
    }
    const dx: number = event.offsetX;
    if (dx < -HOME_FEED_SWIPE_THRESHOLD && this.homeFeed === HomeFeed.Recommended) {
      // 左滑：切到关注动态
      this.showFollowingFeed();
    } else if (dx > HOME_FEED_SWIPE_THRESHOLD && this.homeFeed === HomeFeed.Following) {
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
    // 账号 ID / 浏览时间戳 / 同帖去重置顶 / 上限截断统一由 HistoryStore 处理
    await HistoryStore.getInstance().record(historyItem);
  }

  /**
   * 卡片点击统一入口（2026-09-29 防串帖收口）：按卡片实传的 tid 回查 feed 数据再开帖，
   * 不再信任点击闭包捕获的 item —— 闭包与卡片显示内容可能因任何复用/重建机制脱钩，
   * 而显示内容与 tid 永远同源（卡片渲染与点击同读 item.tid），按 tid 回查必与所见一致。
   * 回查失败（数据已被刷新换血）宁可不跳转，也不能开成别的帖子。
   */
  private openThreadByTid(tid: string): void {
    const t: string = tid.trim();
    if (t.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '帖子信息暂不可用' });
      return;
    }
    let hit: ThreadItem | undefined = this.threads.find((x: ThreadItem): boolean => x.tid === t);
    if (hit === undefined) {
      hit = this.folThreads.find((x: ThreadItem): boolean => x.tid === t);
    }
    if (hit === undefined) {
      this.getUIContext().getPromptAction().showToast({ message: '帖子信息暂不可用' });
      return;
    }
    this.openThread(hit);
  }

  private openThread(item: ThreadItem): void {
    // 左右滑切 feed 期间锁点按：滑动抬指时手势仲裁仍可能给卡片派发 click（评论钮同样走本入口），
    // 这里直接短路，避免「滑动切 feed 的同时把帖子点开」
    if (this.feedSwipeLock) {
      return;
    }
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
          if (this.homeColumns() > 1 || HOME_SINGLE_USE_WATERFLOW) {
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
                      imageThumbs: item.imageThumbs ?? [],
                      createTime: item.createTime,
                      isTop: item.isTop,
                      isGood: item.isGood,
                    } as ThreadItemData,
                    onTap: (tid: string) => this.openThreadByTid(tid),
                    onLike: (tid: string, postId: string, liked: boolean) => this.handleLike(tid, postId, liked),
                    onShare: (d: ThreadSharePayload) => this.shareThread(d),
                    onComment: (tid: string) => this.openThreadByTid(tid),
                    onAvatarTap: (id: string, name: string) => this.openUserProfile(id, name)
                  })
                }
              }, (item: ThreadItem) => `${item.tid}_${item.author}_${item.isLiked ? 1 : 0}_${item.likeCount ?? 0}`)
            }
            .columnsTemplate(this.homeColumnsTemplate())
            // 预加载窗口（2026-09-19）：默认 1 个 FlowItem 太少，快速甩滑时新格子出屏后才开始
            // 构建 → 空白/卡顿。按「列数×2」预建（2 列=4、3 列=6），只改离屏构建窗口。
            // 单列档下限抬到 5（约 2 屏）：单列时 1 个 FlowItem 就是一整屏，太小会在甩滑时补不上卡
            .cachedCount(Math.max(5, this.homeColumns() * 2))
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
            .onScrollIndex((start: number, end: number) => this.onFeedVisibleRange(false, start, end))
            .onTouch((event: TouchEvent) => this.onFeedTouchRecord(event))
            .onScrollStart(() => this.onFeedScrollStart())
            .onScrollStop(() => this.onFeedScrollStop(false))
            .onReachEnd(() => {
              if (this.loadState === LoadState.Success && !this.homeLoadingMore) {
                this.loadMoreHomeThreads();
              }
            })
          } else {
          // 单列档：Scroll + Column 全量布局 + 窗口化挂载 v2（机制详见 slotUpdateWindow 处注释）。
          // 根治 List 视口剔除与沉浸绘制区错位导致的「卡片滚入顶栏区整层消失」，且保住懒挂载性能与图片按需下载。
          Scroll(this.homeScroller) {
            Column({ space: Spacing.md }) {
              // 窗口外上方：单个等高占位块（高度 = 前缀和区间和），不再为每张未挂载卡建节点
              if (this.recSlotStart > 0) {
                Column()
                  .width('100%')
                  .height(this.slotRangeHeight(false, 0, this.recSlotStart))
              }
              ForEach(this.threads.slice(this.recSlotStart, this.recSlotEnd + 1), (item: ThreadItem) => {
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
                      imageThumbs: item.imageThumbs ?? [],
                      createTime: item.createTime,
                      isTop: item.isTop,
                      isGood: item.isGood,
                    } as ThreadItemData,
                    onTap: (tid: string) => this.openThreadByTid(tid),
                    onLike: (tid: string, postId: string, liked: boolean) => this.handleLike(tid, postId, liked),
                    onShare: (d: ThreadSharePayload) => this.shareThread(d),
                    onComment: (tid: string) => this.openThreadByTid(tid),
                    onAvatarTap: (id: string, name: string) => this.openUserProfile(id, name)
                  })
                    // 卡高采集（持续更新）：出窗后占位复用实测值，避免滚动跳动
                    .onAreaChange((_oldA: Area, newA: Area) => {
                      this.slotRecordHeight(item, newA.height as number);
                    })
              }, (item: ThreadItem) => `${item.tid}_${item.author}_${item.isLiked ? 1 : 0}_${item.likeCount ?? 0}`)

              // 窗口外下方：单个等高占位块（高度 = 前缀和区间和）
              if (this.recSlotEnd < this.threads.length - 1) {
                Column()
                  .width('100%')
                  .height(this.slotRangeHeight(false, this.recSlotEnd + 1, this.threads.length))
              }

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
              }

              // 底部空间
              Column()
                .width('100%')
                .height(150)
            }
            .width('100%')
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: Spacing.lg, right: Spacing.lg })
          .clip(false)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .onAreaChange((oldValue: Area, newValue: Area) => this.onHomeViewportAreaChange(oldValue, newValue))
          .onScroll((xOffset: number, yOffset: number) => this.onHomeScroll(xOffset, yOffset))
          .onTouch((event: TouchEvent) => this.onFeedTouchRecord(event))
          .onScrollStart(() => this.onFeedScrollStart())
          .onScrollStop(() => this.onFeedScrollStop(false))
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
          if (this.homeColumns() > 1 || HOME_SINGLE_USE_WATERFLOW) {
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
                      imageThumbs: item.imageThumbs ?? [],
                      createTime: item.createTime,
                      isTop: item.isTop,
                      isGood: item.isGood,
                    } as ThreadItemData,
                    onTap: (tid: string) => this.openThreadByTid(tid),
                    onLike: (tid: string, postId: string, liked: boolean) => this.handleLike(tid, postId, liked),
                    onShare: (d: ThreadSharePayload) => this.shareThread(d),
                    onComment: (tid: string) => this.openThreadByTid(tid),
                    onAvatarTap: (id: string, name: string) => this.openUserProfile(id, name)
                  })
                }
              }, (item: ThreadItem) => `${item.tid}_${item.author}_${item.isLiked ? 1 : 0}_${item.likeCount ?? 0}`)
            }
            .columnsTemplate(this.homeColumnsTemplate())
            // 预加载窗口（2026-09-19）：默认 1 个 FlowItem 太少，快速甩滑时新格子出屏后才开始
            // 构建 → 空白/卡顿。按「列数×2」预建（2 列=4、3 列=6），只改离屏构建窗口。
            // 单列档下限抬到 5（约 2 屏）：单列时 1 个 FlowItem 就是一整屏，太小会在甩滑时补不上卡
            .cachedCount(Math.max(5, this.homeColumns() * 2))
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
            .onScrollIndex((start: number, end: number) => this.onFeedVisibleRange(true, start, end))
            .onTouch((event: TouchEvent) => this.onFeedTouchRecord(event))
            .onScrollStart(() => this.onFeedScrollStart())
            .onScrollStop(() => this.onFeedScrollStop(true))
            .onReachEnd(() => {
              if (this.folState === LoadState.Success && !this.folLoadingMore) {
                this.loadMoreFollowingThreads();
              }
            })
          } else {
          // 单列档：Scroll + Column 全量布局 + 窗口化挂载 v2（与推荐流同款，机制详见 slotUpdateWindow 处注释）
          Scroll(this.folScroller) {
            Column({ space: Spacing.md }) {
              // 窗口外上方：单个等高占位块（高度 = 前缀和区间和）
              if (this.folSlotStart > 0) {
                Column()
                  .width('100%')
                  .height(this.slotRangeHeight(true, 0, this.folSlotStart))
              }
              ForEach(this.folThreads.slice(this.folSlotStart, this.folSlotEnd + 1), (item: ThreadItem) => {
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
                      imageThumbs: item.imageThumbs ?? [],
                      createTime: item.createTime,
                      isTop: item.isTop,
                      isGood: item.isGood,
                    } as ThreadItemData,
                    onTap: (tid: string) => this.openThreadByTid(tid),
                    onLike: (tid: string, postId: string, liked: boolean) => this.handleLike(tid, postId, liked),
                    onShare: (d: ThreadSharePayload) => this.shareThread(d),
                    onComment: (tid: string) => this.openThreadByTid(tid),
                    onAvatarTap: (id: string, name: string) => this.openUserProfile(id, name)
                  })
                    // 卡高采集（持续更新）：出窗后占位复用实测值，避免滚动跳动
                    .onAreaChange((_oldA: Area, newA: Area) => {
                      this.slotRecordHeight(item, newA.height as number);
                    })
              }, (item: ThreadItem) => `${item.tid}_${item.author}_${item.isLiked ? 1 : 0}_${item.likeCount ?? 0}`)

              // 窗口外下方：单个等高占位块（高度 = 前缀和区间和）
              if (this.folSlotEnd < this.folThreads.length - 1) {
                Column()
                  .width('100%')
                  .height(this.slotRangeHeight(true, this.folSlotEnd + 1, this.folThreads.length))
              }

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
              }

              // 底部空间
              Column()
                .width('100%')
                .height(150)
            }
            .width('100%')
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: Spacing.lg, right: Spacing.lg })
          .clip(false)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .onAreaChange((oldValue: Area, newValue: Area) => this.onHomeViewportAreaChange(oldValue, newValue))
          .onScroll((xOffset: number, yOffset: number) => this.onHomeScroll(xOffset, yOffset))
          .onTouch((event: TouchEvent) => this.onFeedTouchRecord(event))
          .onScrollStart(() => this.onFeedScrollStart())
          .onScrollStop(() => this.onFeedScrollStop(true))
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
  }

  /**
   * 顶部满宽渐显带（2026-09-29 定稿：进吧页 ForumsTab.TopFadeBand 逐项照搬）：
   * 背景色渐变条挂页面层（盖列表内容），高 108 = 顶栏（状态栏让位 + 按钮行 + 呼吸）；
   * 渐变自顶部线性、无全实段（否则内容到顶栏会被"硬切"）；不与标题栏沉浸隐藏联动——
   * 标题自动隐藏时照常保留（用户指定），行为与进吧页完全一致。
   */
  @Builder
  TopFadeBand() {
    Column()
      .width('100%')
      .height(HOME_TITLE_BAR_HEIGHT)
      .linearGradient({
        direction: GradientDirection.Bottom,
        colors: [
          [Theme.bg(this.isDark), 0.0],
          [this.isDark ? '#00101114' : '#00F2F4F7', 1.0]
        ]
      })
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
    // 沉浸阅读补全（2026-09-29）：整行上移约 0.6 倍高 + 淡出 + 禁用命中（与宿主底栏同节奏）
    .translate({ y: this.immersiveHidden ? this.homeTopSink() : 0 })
    .opacity(this.immersiveHidden ? 0 : 1)
    .enabled(!this.immersiveHidden)
    .animation(this.homeImmersiveAnim())
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
    // 沉浸阅读补全（2026-09-29）：槽高固定 108 不参与内容布局（Scroll 首项自带让位），整行上移 + 淡出
    .translate({ y: this.immersiveHidden ? this.homeTopSink() : 0 })
    .opacity(this.immersiveHidden ? 0 : 1)
    .enabled(!this.immersiveHidden)
    .animation(this.homeImmersiveAnim())
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

      // 顶部满宽渐显带（进吧页 ForumsTab.TopFadeBand 同款照搬，2026-09-29）：
      // 挂页面层盖列表内容；位置在悬浮 TopBar 之前，故不会盖住顶栏按钮——
      // 官方 title 槽位路径 TopBar 在 Navigation title 层，更不受影响
      this.TopFadeBand()

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
    // 用 PanGesture 而非 SwipeGesture：识别更宽容，onActionEnd 直接给出总位移判断方向。
    // onActionStart 起手即锁卡片点按：滑动收尾时手势仲裁仍可能给卡片派发 click（openThread 内
    // feedSwipeLock 短路），抬指/取消后延时解锁（与 ThreadList 左右滑切排序同款机制）。
    .parallelGesture(
      PanGesture({ fingers: 1, direction: PanDirection.Horizontal, distance: 30 })
        .onActionStart(() => {
          this.lockFeedSwipe();
        })
        .onActionEnd((event: GestureEvent) => {
          this.onHomeFeedPanEnd(event);
          this.unlockFeedSwipeDelayed();
        })
        .onActionCancel(() => {
          this.unlockFeedSwipeDelayed();
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
