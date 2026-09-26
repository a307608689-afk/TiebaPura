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

import { hilog } from '@kit.PerformanceAnalysisKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { display } from '@kit.ArkUI';
import { AuthManager } from '../service/AuthManager';
import { TiebaService } from '../service/TiebaService';
import { NotifyMessage } from '../model/DataModel';
import { Theme, Spacing, Radius, fs, isDarkMode, ImmMaterial, isWideBarDevice, isLargeFoldDevice, isWideFormDevice as detectWideFormDevice, readColumnMode, overrideColumns, isLargeScreenForm, isWideBarFullscreen } from '../common/Theme';
import { LoadingView, EmptyView, ErrorView } from '../components/CommonComponents';
import { formatTime } from '../common/Constants';

/**
 * 消息主 Tab 页：分为「回复我的」与「提到我的」两个子列表。
 * UI 参考收藏页卡片风格；点击条目跳转帖子详情并定位到对应楼层。
 */

enum NotifyTab {
  Reply,
  At,
}

enum LoadState {
  Idle,
  Loading,
  Error,
}

class NotifyTabState {
  list: NotifyMessage[] = [];
  page: number = 1;
  hasMore: boolean = true;
  loadState: LoadState = LoadState.Idle;
  errorMsg: string = '';
  everLoaded: boolean = false;
}

/** 模块级消息缓存：Tab 页组件被 Index 卸载/重建后仍保留数据，进页直接先出旧内容再静默刷新 */
const CACHE_TTL_MS = 60 * 1000;

// —— 内容区顶部留空：首卡距屏幕顶 = NOTIFY_TOP_PAD ——
// 实现方式：做成 Scroll 内 Column 的 padding-top（属于内容、随滚动一起上移，帖子才能窜到
// 悬浮胶囊与状态栏之下，保持沉浸）；放到滚动容器外层会形成永久空白带，顶部即不沉浸。
// 注意：不要再额外塞「占位子元素」——Column({ space }) 会在子元素之间再插一份间距，
// 导致首卡被多顶 2×space，留空看起来偏多。
// 胶囊底边 ≈ 48(栏内 top) + 40(胶囊高) ≈ 88 → 98 即留约 10 的呼吸间隙。
const NOTIFY_TOP_PAD = 98;

/** 官方标题栏开关：true = 「回复 / 提到我的」胶囊走 Navigation title 槽位吃官方材质（§6.10 模板，与首页/进吧/收藏同机制）；
 *  false = 一键回退到页面主体悬浮自绘玻璃 TopBar（manualGlass + backgroundBlurStyle 真磨砂），旧 TopBar() 原样保留。 */
const NOTIFY_OFFICIAL_TITLE_BAR: boolean = true;
/** 槽位高度 = 48(原 top) + 40(胶囊行高：fontSize 16 + 上下 padding 9) + 20(原 bottom) = 108，
 *  与原悬浮 TopBar 的 padding 逐项一致；内容让位 NOTIFY_TOP_PAD = 98 一行未改。 */
const NOTIFY_TITLE_BAR_HEIGHT: number = 108;

class MessagesCenterCache {
  accountKey: string = '';
  reply: NotifyTabState = new NotifyTabState();
  at: NotifyTabState = new NotifyTabState();
  loadedAt: number = 0;
}

const messagesCache: MessagesCenterCache = new MessagesCenterCache();

@Component
export struct MessagesTab {
  /**
   * 顶部渐显带收窄（2026-09-13 用户反馈）：平板竖屏下原 15% 渐显覆盖到第一个卡片中部，
   * 要求「只覆盖顶部按钮与标题」→ 平板档覆盖高度 = 顶栏 98vp，手机维持原比例。
   */
  private readonly isWideFormDevice: boolean = detectWideFormDevice();
  // ===== 平板适配（docs/TiebaPura平板适配.md §4.4，2026-09-14 用户拍板：回复/提到我的采用首页同款
  // 瀑布流观感，竖 3 / 横 4；按 floor-vanish 教训以「Scroll + 列内独立堆叠」实现，禁止回归虚拟滚动容器）=====
  /** 窗口宽 / 高（vp）：aboutToAppear 首帧初值 + NotifyContent 根 Column onAreaChange 兜底 */
  @State pageWidth: number = 0;
  @State pageHeight: number = 0;

  /** 横竖屏：宽高比（与 §4.1 / §4.2 同口径） */
  private isLandscape(): boolean {
    return this.pageWidth > this.pageHeight;
  }

  /** 列数：大屏竖 3 / 横 4；窄窗与手机 1 列（形态闸门放首行，防手机横屏误命中） */
  /**
   * 「列数调整」档位变化（个性化页写入 → `columnModeTick` 广播）：
   * 回写本地档位（列数函数随新档返回）→ 重算两个 Tab 的列分桶镜像 → 强制回到列表顶部。
   * 默认档（0）与原自动适配逐像素一致，仅「用户显式选择」后才改变列数。
   */
  private onColumnModeTick(): void {
    this.columnMode = readColumnMode();
    this.syncAll();
    try {
      this.replyScroller.scrollTo({ xOffset: 0, yOffset: 0 });
      this.atScroller.scrollTo({ xOffset: 0, yOffset: 0 });
    } catch (e) {
    }
  }

  private notifyColumns(): number {
    // 窗口闸门最前（2026-09-17 小窗 / 分屏适配）：窗口宽 <600（自由多窗小窗 / 分屏窄窗）一律回落
    // 手机单列档——须在设备恒值分支（大折叠恒 3）之前，防小窗误命中
    // 阔直屏全屏白名单（2026-09-18）：Pura X View（VOL-AL00）等阔直屏竖屏全屏窗口宽仅 ~440vp，
    // 会被本闸门误判成小窗；白名单放行（小窗 / 分屏仍拦，见 Theme.isWideBarFullscreen）
    if (this.pageWidth > 0 && this.pageWidth < 600 && !isWideBarFullscreen(this.pageWidth)) {
      return 1;
    }
    // 「列数调整」（2026-09-18，个性化 → 列数调整）：仅大屏形态（平板 / 阔直屏 / 大折叠展开）生效，
    // 窄窗与手机档已由上面的窗口闸门返回不受影响；默认档 ov=0 → 原样走下面自动适配分支（逐像素零回归）
    if (isLargeScreenForm(this.isWideFormDevice)) {
      const ov: number = overrideColumns(this.columnMode, this.isLandscape());
      if (ov > 0) {
        return ov;
      }
    }
    // 大折叠（docs/TiebaPura大折叠适配.md §4.2）：竖 2 / 横 3（2026-09-17 用户改定，与阔直屏同口径）
    if (isLargeFoldDevice()) {
      return this.isLandscape() ? 3 : 2;
    }
    // 阔直屏（docs/TiebaPura阔直屏适配.md §4.2，2026-09-17 用户改定）：不依赖宽度阈值（竖屏宽 <600），
    // 竖 1 / 横 3（竖屏回落手机单列档；初版竖 2 作废）
    if (isWideBarDevice()) {
      return this.isLandscape() ? 3 : 1;
    }
    if (!this.isWideFormDevice) {
      return 1;
    }
    if (this.pageWidth < 600) {
      return 1;
    }
    // 2026-09-17 三次拍板：平板**竖屏 2 列**（≥840 竖屏 3 列作废）/ 横屏 3 列
    return this.isLandscape() ? 3 : 2;
  }
  /** 屏幕长边（vp）：竖屏视口高的稳定来源（旋转取长边，渐显比例不漂移） */
  @State fadeCoverVp: number = 0;
  @State selectedTab: NotifyTab = NotifyTab.Reply;
  @State loggedIn: boolean = false;
  @State isDark: boolean = isDarkMode();
  @StorageLink('fontScale') fontScale: number = 1.0;
  // 字号全局变更广播（2026-09-13）：@Watch 回写 fontScale 强制本页依赖刷新（离屏缓存不重绘兜底）
  @StorageLink('fontTick') @Watch('onFontTick') fontTick: number = 0;
  // 「列数调整」档位广播（2026-09-18，个性化 → 列数调整）：@Watch 回写本地档位 → 列数函数按新档返回并强制回到列表顶部
  // （离屏期间 @StorageLink 同步不重绘，故用 tick + 本地 @State 兜底，同 fontTick 范式）
  @StorageLink('columnModeTick') @Watch('onColumnModeTick') columnModeTick: number = 0;
  @State columnMode: number = 0;
  @StorageLink('darkTick') @Watch('onDarkTick') darkTick: number = 0;
  @StorageLink('tabLoginRefresh') @Watch('onLoginTick') tabLoginRefresh: number = 0;

  private replyState: NotifyTabState = messagesCache.reply;
  private atState: NotifyTabState = messagesCache.at;

  // 两个子 Tab 各持一套 @State 展示镜像（整体替换新对象触发 UI 刷新，plain 对象字段变化不驱动）。
  // 「回复/提到」两页在 Tabs 中并存，各自镜像互不干扰。
  @State shownReply: NotifyTabState = new NotifyTabState();
  @State shownAt: NotifyTabState = new NotifyTabState();
  // 下拉刷新进行中（2026-09-22，docs/下拉刷新.md）：两个子 Tab 各持独立状态；
  // 必须显式走 false→true→false 变化链，Refresh 靠 true→false 变化沿收起指示器
  @State replyPullRefreshing: boolean = false;
  @State atPullRefreshing: boolean = false;
  // §4.4 真机修复：多列分桶结果**主动算好写入 @State**（同步在 syncAll）——原实现 UI 在 @Builder 内
  // 经方法间接读取镜像，Tabs/TabContent 嵌套下 @State 替换未触发重渲染（数据到 175 条而 UI 停在第一页），
  // 直接读 @State 数组绕开依赖收集问题
  @State shownReplyCols: NotifyMessage[][] = [];
  @State shownAtCols: NotifyMessage[][] = [];
  private tabsCtrl: TabsController = new TabsController();

  aboutToAppear(): void {
    this.isDark = isDarkMode();
    this.loggedIn = AuthManager.getInstance().isLogin();
    // 顶部渐显带覆盖基准（平板收窄用）：取屏幕长边（竖屏视口高），窗口未 attach 时忽略
    try {
      const d: display.Display = display.getDefaultDisplaySync();
      this.fadeCoverVp = Math.max(d.width, d.height) / d.densityPixels;
      // §4.4：pageWidth / pageHeight 首帧初值（§6.2 第 6 步：形态判定须首帧就位，防多列闪变）
      this.pageWidth = d.width / d.densityPixels;
      this.pageHeight = d.height / d.densityPixels;
    } catch (e) {
      // 忽略：窗口未 attach，fadeCoverVp 保持 0 → topFadeStop() 回退手机比例；pageWidth=0 → notifyColumns()=1 安全方向
    }
    // 「列数调整」档位初值（2026-09-18）：冷启动首帧即按已选档渲染
    // （UsageHabitsManager.init 的 columnModeTick 可能早于本页构造，@Watch 不会补触发，故此处直读）
    this.columnMode = readColumnMode();
    this.enterPage();
  }

  onDarkTick(): void {
    this.isDark = isDarkMode();
  }

  /** fontTick 递增（字号设置写入 / 宿主返回广播）→ 显式回写 fontScale 强制本页字号依赖刷新 */
  onFontTick(): void {
    this.fontScale = AppStorage.get<number>('fontScale') ?? 1.0;
  }

  onLoginTick(): void {
    this.loggedIn = AuthManager.getInstance().isLogin();
    this.enterPage();
  }

  private currentUid(): string {
    return AuthManager.getInstance().getUser()?.userId ?? '';
  }

  /** 让模块缓存归属当前账号；换了账号则重置（返回 true 表示原本就是当前账号的缓存） */
  private adoptCache(): boolean {
    const uid: string = this.currentUid();
    if (messagesCache.accountKey === uid) {
      this.replyState = messagesCache.reply;
      this.atState = messagesCache.at;
      return true;
    }
    messagesCache.accountKey = uid;
    messagesCache.reply = new NotifyTabState();
    messagesCache.at = new NotifyTabState();
    messagesCache.loadedAt = 0;
    this.replyState = messagesCache.reply;
    this.atState = messagesCache.at;
    return false;
  }

  /** 进入页面/登录态变化：优先直出缓存，数据过期则后台静默刷新；从没加载过才显示整屏 Loading */
  private enterPage(): void {
    if (!this.loggedIn) {
      this.adoptCache();
      this.syncAll();
      return;
    }
    const sameCache: boolean = this.adoptCache();
    const state: NotifyTabState = this.currentState();
    this.syncAll();
    if (state.everLoaded) {
      // 有旧内容：直接显示；超时再静默刷新（不换 Loading）
      if (Date.now() - messagesCache.loadedAt > CACHE_TTL_MS) {
        this.loadMessages(this.selectedTab, true, true);
      }
    } else if (sameCache && state.loadState === LoadState.Error) {
      // 上次加载失败保留错误视图，让用户手动重试
    } else {
      this.loadMessages(this.selectedTab, true, false);
    }
  }

  private currentState(): NotifyTabState {
    return this.selectedTab === NotifyTab.Reply ? this.replyState : this.atState;
  }

  /** 镜像拷贝：整体替换 @State 对象才触发 UI 刷新 */
  private snapshotOf(s: NotifyTabState): NotifyTabState {
    const copy = new NotifyTabState();
    copy.list = s.list;
    copy.page = s.page;
    copy.hasMore = s.hasMore;
    copy.loadState = s.loadState;
    copy.errorMsg = s.errorMsg;
    copy.everLoaded = s.everLoaded;
    return copy;
  }

  /** 把两个 Tab 的缓存态同步成新 @State 镜像，分别驱动「回复/提到」两个列表刷新；
   *  §4.4：分桶结果同步主动计算写入 @State（loadMessages 数据到达后的渲染驱动源） */
  private syncAll(): void {
    this.shownReply = this.snapshotOf(this.replyState);
    this.shownAt = this.snapshotOf(this.atState);
    this.shownReplyCols = this.notifyColumnsData(this.replyState.list);
    this.shownAtCols = this.notifyColumnsData(this.atState.list);
  }

  /** 读取指定 Tab 的展示镜像（TabContent 内各态判断/渲染共用） */
  private mirrorOf(tab: NotifyTab): NotifyTabState {
    return tab === NotifyTab.Reply ? this.shownReply : this.shownAt;
  }

  private async loadMessages(tab: NotifyTab, refresh: boolean = false, silent: boolean = false): Promise<void> {
    if (!this.loggedIn) {
      return;
    }
    const state = tab === NotifyTab.Reply ? this.replyState : this.atState;
    if (state.loadState === LoadState.Loading) {
      return;
    }
    const prevPage: number = state.page;
    const prevHasMore: boolean = state.hasMore;
    if (refresh) {
      state.page = 1;
      state.hasMore = true;
      if (!silent) {
        state.list = [];
      }
    }
    if (!state.hasMore) {
      return;
    }
    state.loadState = LoadState.Loading;
    state.errorMsg = '';
    // silent 刷新不清列表也不中途切 Loading：有旧内容不打断浏览，真·无消息时保持空态，结果返回后一次性更新
    // §4.4 加载体验优化（2026-09-14）：**仅首屏 / 空列表**在加载前同步一次（需要 Loading / 空态切换）；
    // 已有内容时跳过这一步——列表态不看 loadState，提前 syncAll 只会多一次整体重建（用户看到的"闪一下"），
    // 改为结果返回后一次性 syncAll（静默加载，无中间态闪烁）
    if (!silent && state.list.length === 0) {
      this.syncAll();
    }
    try {
      const result = tab === NotifyTab.Reply
        ? await TiebaService.getInstance().fetchReplyMe(state.page)
        : await TiebaService.getInstance().fetchAtMe(state.page);
      state.list = refresh ? result.list : [...state.list, ...result.list];
      state.hasMore = result.hasMore;
      state.page = result.page + 1;
      state.loadState = LoadState.Idle;
      state.everLoaded = true;
      messagesCache.loadedAt = Date.now();
    } catch (e) {
      state.errorMsg = (e as Error).message ?? '加载失败';
      if (state.list.length > 0) {
        // 已有旧内容：静默/分页失败不打断浏览，恢复分页位置便于下次续传
        state.loadState = LoadState.Idle;
        if (refresh) {
          state.page = prevPage;
          state.hasMore = prevHasMore;
        }
      } else {
        state.loadState = LoadState.Error;
      }
    }
    this.syncAll();
    // §4.4 真机修复（平板翻页卡死）：多列下内容可能填不满视口 → onReachEnd 永不触发。
    // 每页加载完成后主动检查：内容高仍不足视口（+150 让位余量）就续拉下一页，
    // 直到填满或 hasMore=false（本方法开头双重防重，递归每页一次、有限终止）
    if (this.notifyColumns() > 1 && this.notifyContentH > 0 && this.notifyViewportH > 0
      && this.notifyContentH < this.notifyViewportH + 150) {
      this.loadMessages(tab, false);
    }
  }

  /** 收起指定子 Tab 的下拉刷新指示器 */
  private clearPullRefreshing(tab: NotifyTab): void {
    if (tab === NotifyTab.Reply) {
      this.replyPullRefreshing = false;
    } else {
      this.atPullRefreshing = false;
    }
  }

  /**
   * 下拉刷新（2026-09-22，docs/下拉刷新.md）：复用 loadMessages 的 silent 语义——
   * 保列表在场、不切 Loading、第 1 页整体替换。进入即显式置 true（制造 false→true→false
   * 变化沿，否则指示器永久转圈），15s 看门狗兜底强制收起。
   */
  private async pullRefreshNotify(tab: NotifyTab): Promise<void> {
    if (tab === NotifyTab.Reply) {
      this.replyPullRefreshing = true;
    } else {
      this.atPullRefreshing = true;
    }
    const watchdog: number = setTimeout(() => {
      this.clearPullRefreshing(tab);
    }, 15000);
    try {
      if (this.loggedIn) {
        await this.loadMessages(tab, true, true);
      }
    } finally {
      clearTimeout(watchdog);
      this.clearPullRefreshing(tab);
    }
  }

  /** 进入某 Tab 时按缓存/过期策略装载数据（点击与滑动共用入口） */
  private ensureTabLoaded(tab: NotifyTab): void {
    if (!this.loggedIn) {
      return;
    }
    const state = tab === NotifyTab.Reply ? this.replyState : this.atState;
    if (state.everLoaded) {
      // 已加载过：直出缓存，过期则后台静默刷新
      if (Date.now() - messagesCache.loadedAt > CACHE_TTL_MS) {
        this.loadMessages(tab, true, true);
      }
    } else if (state.loadState !== LoadState.Loading) {
      this.loadMessages(tab, true, false);
    }
  }

  /** 点击顶部胶囊切换：同步高亮，并驱动 Tabs 左右滑动动画切到目标页 */
  private switchTab(tab: NotifyTab): void {
    if (this.selectedTab === tab) {
      return;
    }
    this.selectedTab = tab;
    this.syncAll();
    // changeIndex 切换即带左右滑动动画（该 SDK 版本仅支持单参）
    this.tabsCtrl.changeIndex(this.tabIndexOf(tab));
    this.ensureTabLoaded(tab);
  }

  /** 手势左右滑动结束（Tabs onChange）：页已切到目标，回写胶囊高亮与数据装载 */
  private onSwipeTo(tab: NotifyTab): void {
    if (this.selectedTab === tab) {
      return;
    }
    this.selectedTab = tab;
    this.syncAll();
    this.ensureTabLoaded(tab);
  }

  private tabIndexOf(tab: NotifyTab): number {
    return tab === NotifyTab.At ? 1 : 0;
  }

  private openThread(item: NotifyMessage): void {
    const params: Record<string, string> = {};
    params.tid = item.threadId;
    params.postId = item.postId;
    if (item.quotePid.length > 0) {
      params.quotePid = item.quotePid;
    }
    // 消息定位上下文：isFloor=0 的楼中楼回复需要带回复者/内容到楼中楼详情里精确定位；
    // 楼层回复（isFloor=1）仅靠 postId 定位楼层即可。
    params.notifyIsFloor = item.isFloor ? '1' : '0';
    params.notifyReplyerId = item.replyer.id ?? '';
    params.notifyReplyerName = item.replyer.nameShow || item.replyer.name || '';
    params.notifyContent = item.content;
    hilog.info(0x0000, 'MSGJUMP',
      'openThread type=%{public}s tid=%{public}s postId=%{public}s quotePid=%{public}s isFloor=%{public}s replyer=%{public}s(%{public}s) content=[%{public}s] quote=[%{public}s]',
      item.type, item.threadId, item.postId, item.quotePid, item.isFloor ? '1' : '0',
      item.replyer.nameShow || item.replyer.name || '?', item.replyer.id || '',
      item.content.slice(0, 80), item.quoteContent.slice(0, 80));
    if (item.forumName.length > 0) {
      params.forum = item.forumName;
    }
    // 点击即预取：消息跳转也要走楼层/楼中楼定位，早 300ms 拿到数据即早 300ms 开始定位（§P0-3）
    TiebaService.getInstance().prefetchThreadDetail(`${item.threadId}`, '');
    this.getUIContext().getRouter().pushUrl({ url: 'pages/ThreadDetail', params });
  }

  private openLogin(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Login' });
  }

  /** 兜底路径专用（NOTIFY_OFFICIAL_TITLE_BAR = false 时才挂载）：页面主体悬浮自绘玻璃胶囊 */
  @Builder
  TopBar() {
    // 与首页「推荐/关注动态」一致：文字磨砂玻璃胶囊，去掉标题，贴左自适应
    Row({ space: 16 }) {
      Text('回复')
        .fontSize(fs(16, this.fontScale))
        .fontWeight(this.selectedTab === NotifyTab.Reply ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.selectedTab === NotifyTab.Reply ? $r('sys.color.font_emphasize') : $r('sys.color.font_primary'))
        .backgroundColor(Theme.segGlass(this.isDark, this.selectedTab === NotifyTab.Reply))
        .border({ width: 0.5, color: Theme.manualGlassBorder() })
        .backgroundBlurStyle(this.selectedTab === NotifyTab.Reply ? BlurStyle.Regular : BlurStyle.Thin,
          { scale: this.selectedTab === NotifyTab.Reply ? 0.8 : 0.85 })
        .shadow(Theme.segGlassShadow(this.isDark, this.selectedTab === NotifyTab.Reply))
        .borderRadius(Radius.full)
        .padding({ left: 22, right: 22, top: 9, bottom: 9 })
        .onClick(() => { this.switchTab(NotifyTab.Reply); })

      Text('提到我的')
        .fontSize(fs(16, this.fontScale))
        .fontWeight(this.selectedTab === NotifyTab.At ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.selectedTab === NotifyTab.At ? $r('sys.color.font_emphasize') : $r('sys.color.font_primary'))
        .backgroundColor(Theme.segGlass(this.isDark, this.selectedTab === NotifyTab.At))
        .border({ width: 0.5, color: Theme.manualGlassBorder() })
        .backgroundBlurStyle(this.selectedTab === NotifyTab.At ? BlurStyle.Regular : BlurStyle.Thin,
          { scale: this.selectedTab === NotifyTab.At ? 0.8 : 0.85 })
        .shadow(Theme.segGlassShadow(this.isDark, this.selectedTab === NotifyTab.At))
        .borderRadius(Radius.full)
        .padding({ left: 22, right: 22, top: 9, bottom: 9 })
        .onClick(() => { this.switchTab(NotifyTab.At); })
    }
    .width('100%')
    .padding({ left: Spacing.lg, right: Spacing.lg, top: 48, bottom: 20 })
    .backgroundColor(Color.Transparent)
    .zIndex(14)
  }

  /**
   * 官方槽位标题栏（§6.10 同机制，与首页 HomeTitleBar 同构）：「回复 / 提到我的」两枚胶囊。
   * 玻璃换成 `ImmMaterial.seg(active)`（选中 REGULAR / 未选中 THIN —— 与旧 Regular/Thin 双档模糊同构，
   * 选中感仍由文字强调色 + 字重承担），四项自绘玻璃（segGlass / border / backgroundBlurStyle / segGlassShadow）
   * 按坑 24 全删；Text 无默认填充，无需 backgroundColor。
   * 几何（space 16 / 左右 Spacing.lg / top 48 / bottom 20 / padding 22+9 / fontSize 16）与旧 TopBar 逐项一致；
   * zIndex(14) 槽内无叠层序需求，去掉。
   */
  @Builder
  NotifyTitleBar() {
    Row({ space: 16 }) {
      Text('回复')
        .fontSize(fs(16, this.fontScale))
        .fontWeight(this.selectedTab === NotifyTab.Reply ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.selectedTab === NotifyTab.Reply ? $r('sys.color.font_emphasize') : $r('sys.color.font_primary'))
        .systemMaterial(ImmMaterial.seg(this.selectedTab === NotifyTab.Reply))
        .borderRadius(Radius.full)
        .padding({ left: 22, right: 22, top: 9, bottom: 9 })
        .onClick(() => { this.switchTab(NotifyTab.Reply); })

      Text('提到我的')
        .fontSize(fs(16, this.fontScale))
        .fontWeight(this.selectedTab === NotifyTab.At ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.selectedTab === NotifyTab.At ? $r('sys.color.font_emphasize') : $r('sys.color.font_primary'))
        .systemMaterial(ImmMaterial.seg(this.selectedTab === NotifyTab.At))
        .borderRadius(Radius.full)
        .padding({ left: 22, right: 22, top: 9, bottom: 9 })
        .onClick(() => { this.switchTab(NotifyTab.At); })
    }
    .width('100%')
    .padding({ left: Spacing.lg, right: Spacing.lg, top: 48, bottom: 20 })
  }

  @Builder
  MessageCard(item: NotifyMessage) {
    Row({ space: Spacing.md }) {
      // 头像
      this.Avatar(item)

      Column({ space: 6 }) {
        Row() {
          Text(item.replyer.nameShow || item.replyer.name || '贴吧用户')
            .fontSize(fs(15, this.fontScale))
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.textPrimary(this.isDark))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Blank()
          Text(formatTime(item.time))
            .fontSize(fs(11, this.fontScale))
            .fontColor(Theme.textTertiary(this.isDark))
        }
        .width('100%')

        if (item.title.length > 0) {
          Text(item.title)
            .fontSize(fs(14, this.fontScale))
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.textPrimary(this.isDark))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }

        Text(item.content)
          .fontSize(fs(14, this.fontScale))
          .fontColor(Theme.textPrimary(this.isDark))
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (item.quoteContent.length > 0) {
          Text(`回复：${item.quoteContent}`)
            .fontSize(fs(12, this.fontScale))
            .fontColor(Theme.textSecondary(this.isDark))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(Theme.bgSurface(this.isDark))
            .border({ width: 0.5, color: Theme.divider(this.isDark) })
            .borderRadius(Radius.md)
        }

        if (item.forumName.length > 0) {
          Text(item.forumName)
            .fontSize(fs(11, this.fontScale))
            .fontColor(Theme.textTertiary(this.isDark))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding(Spacing.lg)
    .backgroundColor(Theme.bgCard(this.isDark))
    // 卡片圆角 26：与首页 ThreadCard、详情页卡片、其余列表页卡片统一（不借用全局 Radius.lg）
    .borderRadius(26)
    .onClick(() => { this.openThread(item); })
  }

  @Builder
  Avatar(item: NotifyMessage) {
    Stack() {
      if (item.replyer.avatar.length > 0) {
        Image(item.replyer.avatar)
          .width(44)
          .height(44)
          .borderRadius(22)
          .objectFit(ImageFit.Cover)
          .clip(true)
      }
      if (item.replyer.avatar.length === 0) {
        Text((item.replyer.nameShow || item.replyer.name || '用').charAt(0))
          .fontSize(fs(16, this.fontScale))
          .fontColor(Color.White)
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .borderRadius(22)
          .backgroundColor(Theme.brand())
      }
    }
    .width(44)
    .height(44)
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
        // 丢帧治理 P2（2026-09-26）：原 DST_IN 蒙版要求内容层整体 blendMode(OFFSCREEN)，
        // 滚动时每帧全屏离屏合成；改为「顶栏底色 → 透明」渐变条直接盖在内容上（视觉近似，零离屏）。
        colors: [
          [Theme.bg(this.isDark), 0.0],
          [this.isDark ? '#00101114' : '#00F2F4F7', this.topFadeStop()]
        ]
      })
      .hitTestBehavior(HitTestMode.None)
  }

  /** §4.4 消息多列「列均衡」阈值（vp，方案 B 滞回，与 §4.9 / 收藏页同款） */
  private static readonly NOTIFY_COL_BALANCE_THRESHOLD: number = 240;
  // §4.4 真机修复（平板翻页卡死）：内容高 / 视口高记录（onAreaChange 写入）——平板多列把一页摊薄后
  // 内容可能填不满视口 → onReachEnd 永不触发；且 minHeight 撑满下内容高度恒定、onAreaChange 也不再触发，
  // 故 loadMessages 完成后须主动用这两个值判断「是否仍不足一屏」并续拉
  private notifyContentH: number = 0;
  private notifyViewportH: number = 0;
  // §4.4 加载体验优化：两个子 Tab 各自的滚动位置与控制器——加载后 UI 重建时恢复到原位置，
  // 避免滚动位置丢失造成的"跳一下"
  private replyScroller: Scroller = new Scroller();
  private atScroller: Scroller = new Scroller();
  private replyScrollY: number = 0;
  private atScrollY: number = 0;

  /**
   * 消息分桶（方案 B 带滞回最短列，2026-09-14）：默认 `i % 列数` 轮转（保序），
   * 轮转列与最短列估算高差 > 阈值才补位；前缀稳定贪心 → 数据刷新从头重算、旧卡落列不变（不跳位）。
   * 本页 floor-vanish 已实证虚拟滚动剔除风险 → 多列用「列内独立堆叠」+ Scroll 全量渲染，禁止 WaterFlow/List。
   */
  private notifyColumnsData(items: NotifyMessage[]): NotifyMessage[][] {
    const cols: number = this.notifyColumns();
    const buckets: NotifyMessage[][] = [];
    const heights: number[] = [];
    for (let c = 0; c < cols; c++) {
      buckets.push([]);
      heights.push(0);
    }
    const colWidth: number = (this.pageWidth - Spacing.lg * 2 - Spacing.md * (cols - 1)) / cols;
    for (let i = 0; i < items.length; i++) {
      let target: number = i % cols;
      let shortest: number = 0;
      for (let c = 1; c < cols; c++) {
        if (heights[c] < heights[shortest]) {
          shortest = c;
        }
      }
      if (heights[target] - heights[shortest] > MessagesTab.NOTIFY_COL_BALANCE_THRESHOLD) {
        target = shortest;
      }
      buckets[target].push(items[i]);
      heights[target] += this.estimateMessageCardHeight(items[i], colWidth) + Spacing.md;
    }
    return buckets;
  }

  /** §4.4：列索引数组 [0..列数-1]——外层 ForEach 只遍历索引，保证列容器 key 稳定可复用 */
  private colIndexes(): number[] {
    const n: number = this.notifyColumns();
    const arr: number[] = [];
    for (let i = 0; i < n; i++) {
      arr.push(i);
    }
    return arr;
  }

  /** MessageCard 估算高（vp，仅供列均衡）：昵称行基线 + 标题 1 行 + 正文 ≤3 行 + 引用 ≤2 行 + 吧名行 */
  private estimateMessageCardHeight(item: NotifyMessage, colWidth: number): number {
    let h: number = 64; // 昵称/时间行 ~20 + 卡片上下 padding 32 + 首个 space
    const textColWidth: number = Math.max(60, colWidth - 44 - Spacing.md - Spacing.lg * 2);
    if (item.title.length > 0) {
      h += 20 + 6;
    }
    if (item.content.length > 0) {
      const cpl: number = Math.max(8, Math.floor(textColWidth / 14));
      h += Math.min(Math.ceil(item.content.length / cpl), 3) * 20 + 6;
    }
    if (item.quoteContent.length > 0) {
      const cpl2: number = Math.max(8, Math.floor(textColWidth / 12));
      h += Math.min(Math.ceil(item.quoteContent.length / cpl2), 2) * 17 + 12 + 6;
    }
    if (item.forumName.length > 0) {
      h += 16 + 6;
    }
    return h;
  }

  /** 单个子 Tab 页：Loading/Error/Empty/消息列表四态，数据取自对应展示镜像 */
  @Builder
  TabPane(tab: NotifyTab) {
    Column() {
      if (this.mirrorOf(tab).loadState === LoadState.Loading && this.mirrorOf(tab).list.length === 0) {
        LoadingView({ message: '正在加载消息...' })
          .layoutWeight(1)
      } else if (this.mirrorOf(tab).loadState === LoadState.Error && this.mirrorOf(tab).list.length === 0) {
        ErrorView({ message: this.mirrorOf(tab).errorMsg, onRetry: () => this.loadMessages(tab, true) })
          .layoutWeight(1)
      } else if (this.mirrorOf(tab).list.length === 0) {
        EmptyView({ message: '暂时没有新消息', icon: '✉' })
          .layoutWeight(1)
      } else {
        // 消息卡全量渲染：沉浸布局 + 虚拟滚动(List)存在视口剔除误删项的风险，
        // 改用 Scroll + Column 全量真实布局规避（见 docs/floor-vanish-viewport-fix.md）
        if (this.notifyColumns() > 1) {
          // §4.4 平板多列（2026-09-14 用户拍板：回复/提到我的采用首页同款瀑布流观感，竖 3 / 横 4）：
          // 「列内独立堆叠」Scroll 全量渲染——本页 floor-vanish 已实证虚拟滚动剔除风险，禁止回归 WaterFlow/List
          // 下拉刷新（2026-09-22，docs/下拉刷新.md）：Refresh 铺满全区保顶部沉浸，自定义 builder 指示器
          // 落在标题栏下方；offset 130 保证触发前转圈完整露出
          Refresh({
            refreshing: tab === NotifyTab.Reply ? this.replyPullRefreshing : this.atPullRefreshing,
            offset: 48,
            friction: 62
          }) {
          Scroll(tab === NotifyTab.Reply ? this.replyScroller : this.atScroller) {
            Column({ space: Spacing.md }) {
              // §4.4 真机修复（2026-09-14 四轮）：多列块**内联**在此，不能再经 @Builder 传参——
              // @Builder 参数按值传递时只有传入「状态变量本身」才触发刷新，传三元表达式（原写法）不触发
              // → 数据加载了而界面永远停在第一页。内联后由 build 上下文直接读 @State，依赖可靠建立。
              // §4.4 加载体验优化（2026-09-14 五轮）：外层 ForEach **只遍历列索引**（key 稳定 → 列容器复用、
              // 不整列重建闪屏），内层数据源**直接读 @State 分桶数组** `shownReplyCols[colIdx]`——
              // 若内层仍用外层传入的 col（上一版写法），列容器被复用时新数组传不进去 → 数据更新而 UI 不动
              Row({ space: Spacing.md }) {
                ForEach(this.colIndexes(), (colIdx: number) => {
                  Column({ space: Spacing.md }) {
                    ForEach(tab === NotifyTab.Reply ? this.shownReplyCols[colIdx] : this.shownAtCols[colIdx],
                      (item: NotifyMessage) => {
                        Column() {
                          this.MessageCard(item)
                        }
                        // 新增卡片淡入（已有卡片按 key 复用，不闪）
                        .transition(TransitionEffect.OPACITY.animation({ duration: 160, curve: Curve.EaseOut }))
                      }, (item: NotifyMessage) => `ncol_${item.id}`)
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                }, (colIdx: number) => `ncolgrp_${colIdx}`)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)

              // 底部让位：保证内容可滚出底部渐隐/悬浮区
              Column()
                .width('100%')
                .height(150)
            }
            .width('100%')
            // 修复"首卡上方大片空白"：内容不足一屏时 Scroll 会垂直居中 → 最小撑满视口贴顶（同单列口径）
            .constraintSize({ minHeight: '100%' })
            .padding({ left: Spacing.lg, right: Spacing.lg, top: 0 })
            // 真机修复（2026-09-14）：平板 3/4 列把一页 20 条摊薄后内容可能填不满视口 → Scroll 无可滚
            // 距离、onReachEnd 一次都不触发。内容高 / 视口高记录进字段（供 loadMessages 完成后主动判断续拉；
            // minHeight 撑满下高度恒定、本回调未必再触发，故主动判断在 loadMessages 末尾兜底）
            .onAreaChange((_o: Area, n: Area) => {
              this.notifyContentH = n.height as number;
              if (this.notifyContentH > 0 && this.notifyViewportH > 0
                && this.notifyContentH < this.notifyViewportH + 150) {
                this.loadMessages(tab, false);
              }
            })
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .clip(false)
          .align(Alignment.TopStart)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .onAreaChange((_o: Area, n: Area) => {
            this.notifyViewportH = n.height as number;
          })
          .onScroll(() => {
            // §4.4：实时记录滚动位置，供重建后恢复
            if (tab === NotifyTab.Reply) {
              this.replyScrollY = this.replyScroller.currentOffset().yOffset;
            } else {
              this.atScrollY = this.atScroller.currentOffset().yOffset;
            }
          })
          .onAppear(() => {
            // §4.4：加载后 UI 重建 → 立即恢复到重建前的滚动位置（用户感知"原地续接"，不跳）
            if (tab === NotifyTab.Reply) {
              this.replyScroller.scrollTo({ xOffset: 0, yOffset: this.replyScrollY });
            } else {
              this.atScroller.scrollTo({ xOffset: 0, yOffset: this.atScrollY });
            }
          })
          .onReachEnd(() => { this.loadMessages(tab, false); })
          }
          .width('100%')
          .height('calc(100% - 98vp)')
          .margin({ top: NOTIFY_TOP_PAD })
          // 与首页同款：Refresh 自身不裁切 → 列表内容可溢出到材质顶栏之下渲染（顶部沉浸的关键）
          .clip(false)
          .onRefreshing(() => { this.pullRefreshNotify(tab); })
        } else {
          // 下拉刷新（2026-09-22，docs/下拉刷新.md）：与多列分支同款
          Refresh({
            refreshing: tab === NotifyTab.Reply ? this.replyPullRefreshing : this.atPullRefreshing,
            offset: 48,
            friction: 62
          }) {
          Scroll(tab === NotifyTab.Reply ? this.replyScroller : this.atScroller) {
            Column({ space: Spacing.md }) {
              ForEach(this.mirrorOf(tab).list, (item: NotifyMessage) => {
                this.MessageCard(item)
              }, (item: NotifyMessage) => item.id)

              // 底部让位：保证内容可滚出底部渐隐/悬浮区
              Column()
                .width('100%')
                .height(150)
            }
            .width('100%')
            // 修复“首卡上方大片空白”：Scroll 内容高度不足一屏时会被整体垂直居中（实测
            // 内容 2079 < 视口 2544 时 Column 起点 = 视口顶 + (2544-2079)/2）。
            // 让内容列最小撑满视口即可贴顶显示，内容超出视口时不受影响。
            .constraintSize({ minHeight: '100%' })
            // 顶部让位：padding-top 计入内容、随滚动一起上移（沉浸），且不会被 Column space 再叠加一份
            .padding({ left: Spacing.lg, right: Spacing.lg, top: 0 })
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .clip(false)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .onReachEnd(() => { this.loadMessages(tab, false); })
          }
          .width('100%')
          .height('calc(100% - 98vp)')
          .margin({ top: NOTIFY_TOP_PAD })
          // 与首页同款：Refresh 自身不裁切 → 列表内容可溢出到材质顶栏之下渲染（顶部沉浸的关键）
          .clip(false)
          .onRefreshing(() => { this.pullRefreshNotify(tab); })
        }
      }
    }
    .width('100%')
    .height('100%')
  }

  /** 页面内容层（原 build() 根 Stack 的内容列，槽位 / 兜底两条路径共用） */
  @Builder
  NotifyContent() {
    Column() {
        if (!this.loggedIn) {
          // 未登录无滚动内容：占位固定，避免空态钻到胶囊/状态栏下
          Column().width('100%').height(NOTIFY_TOP_PAD)
          EmptyView({ message: '登录后查看消息中心', icon: '✉', actionText: '登录', action: () => this.openLogin() })
            .layoutWeight(1)
        } else {
          // 回复/提到：无栏 Tabs 承载两个独立子列表页，支持手势左右滑动切换，
          // 顶部胶囊通过 TabsController.changeIndex 联动出同样的滑动动画。
          // 注意：Tabs 不要再叠加固定顶部让位占位（那会形成不可滚空白、顶部不沉浸）；
          // 让位占位下沉到各 TabPane 的 Scroll 内容里（与首页/进吧/我的/收藏一致）。
          Tabs({ barPosition: BarPosition.Start, controller: this.tabsCtrl }) {
            TabContent() {
              this.TabPane(NotifyTab.Reply)
            }

            TabContent() {
              this.TabPane(NotifyTab.At)
            }
          }
          .width('100%')
          .layoutWeight(1)
          .vertical(false)
          .scrollable(true)
          .barHeight(0)
          .barBackgroundColor(Color.Transparent)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .onChange((index: number) => {
            this.onSwipeTo(index === 0 ? NotifyTab.Reply : NotifyTab.At);
          })
        }
      }
    .width('100%')
    .height('100%')
    // §4.4：根容器实宽 / 实高 → 形态判定与列数（首帧由 aboutToAppear 兜底）
    .onAreaChange((_old: Area, n: Area) => {
      const w: number = n.width as number;
      const h: number = n.height as number;
      // 尺寸同值短路（2026-09-18 旋转丝滑）：旋转期逐帧回调，同值重写 @State 会白触发整树重渲染
      if (w === this.pageWidth && h === this.pageHeight) {
        return;
      }
      this.pageWidth = w;
      this.pageHeight = h;
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .overlay(this.BottomFadeOverlay())
  }

  build() {
    if (NOTIFY_OFFICIAL_TITLE_BAR) {
      // 官方槽位路径（§6.10）：整行胶囊搬进 Navigation title 槽位吃真材质
      Navigation() {
        this.NotifyContent()
      }
      .title({ builder: this.NotifyTitleBar(), height: NOTIFY_TITLE_BAR_HEIGHT },
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
        this.NotifyContent()

        this.TopBar()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
    }
  }
}
