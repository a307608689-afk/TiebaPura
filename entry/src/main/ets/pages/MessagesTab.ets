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
import { AuthManager } from '../service/AuthManager';
import { TiebaService } from '../service/TiebaService';
import { NotifyMessage } from '../model/DataModel';
import { Theme, Spacing, Radius, fs, isDarkMode, ImmMaterial } from '../common/Theme';
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
  @State selectedTab: NotifyTab = NotifyTab.Reply;
  @State loggedIn: boolean = false;
  @State isDark: boolean = isDarkMode();
  @StorageLink('fontScale') fontScale: number = 1.0;
  @StorageLink('darkTick') @Watch('onDarkTick') darkTick: number = 0;
  @StorageLink('tabLoginRefresh') @Watch('onLoginTick') tabLoginRefresh: number = 0;

  private replyState: NotifyTabState = messagesCache.reply;
  private atState: NotifyTabState = messagesCache.at;

  // 两个子 Tab 各持一套 @State 展示镜像（整体替换新对象触发 UI 刷新，plain 对象字段变化不驱动）。
  // 「回复/提到」两页在 Tabs 中并存，各自镜像互不干扰。
  @State shownReply: NotifyTabState = new NotifyTabState();
  @State shownAt: NotifyTabState = new NotifyTabState();
  private tabsCtrl: TabsController = new TabsController();

  aboutToAppear(): void {
    this.isDark = isDarkMode();
    this.loggedIn = AuthManager.getInstance().isLogin();
    this.enterPage();
  }

  onDarkTick(): void {
    this.isDark = isDarkMode();
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

  /** 把两个 Tab 的缓存态同步成新 @State 镜像，分别驱动「回复/提到」两个列表刷新 */
  private syncAll(): void {
    this.shownReply = this.snapshotOf(this.replyState);
    this.shownAt = this.snapshotOf(this.atState);
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
    if (!silent) {
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

  @Builder
  BottomFadeOverlay() {
    Stack()
      .height('100%')
      .width('100%')
      .linearGradient({
        direction: GradientDirection.Bottom,
        colors: [['#00FFFFFF', 0.0], ['#FFFFFFFF', 0.15], ['#FFFFFFFF', 1.0]]
      })
      .blendMode(BlendMode.DST_IN, BlendApplyType.OFFSCREEN)
      .hitTestBehavior(HitTestMode.None)
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
        Scroll() {
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
          .padding({ left: Spacing.lg, right: Spacing.lg, top: NOTIFY_TOP_PAD })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .clip(false)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onReachEnd(() => { this.loadMessages(tab, false); })
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
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .overlay(this.BottomFadeOverlay())
    .blendMode(BlendMode.SRC_OVER, BlendApplyType.OFFSCREEN)
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
