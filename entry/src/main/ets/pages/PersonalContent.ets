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

import { CacheManager } from '../cache/CacheManager';
import { CACHE_KEY, formatTime } from '../common/Constants';
import { PrefetchGate } from '../common/PrefetchGate';
import { PersonalContentItem, PagedResult } from '../model/DataModel';
import { TiebaService } from '../service/TiebaService';
import { AuthManager } from '../service/AuthManager';
import { HistoryStore } from '../service/HistoryStore';
import { deviceInfo } from '@kit.BasicServicesKit';
import { display } from '@kit.ArkUI';
import { Theme, Spacing, Radius, Breakpoint, isDarkMode, ImmBlur, ImmMaterial, MaterialManager, fs, isWideBarDevice, isLargeFoldDevice, isWideFormDevice as detectWideFormDevice, readColumnMode, overrideColumns, isLargeScreenForm, isWideBarFullscreen } from '../common/Theme';
import { LoadingView, EmptyView, ErrorView } from '../components/CommonComponents';

enum PersonalMode {
  Posts = 'posts',
  Likes = 'likes',
  Collections = 'collections',
  History = 'history',
}

enum LoadState {
  Loading, Success, Empty, Error,
}

/** 官方标题栏开关（§6.10 模板）：true 且设备支持材质时，「返回 + 标题」搬进 Navigation title 槽位吃官方材质；
 *  false 或低版本自动回退到页面主体悬浮自绘玻璃 TopBar（原样保留）。 */
const PERSONAL_CONTENT_OFFICIAL_TITLE_BAR: boolean = true;
/** 槽位高度 = 44(状态栏让位) + 44(按钮行高) + 10(底部呼吸)，与原悬浮 TopBar 的 padding 逐项一致；
 *  内容让位（List 首项占位 98）一行未改。 */
const PERSONAL_CONTENT_TITLE_BAR_HEIGHT: number = 98;
/**
 * 「我的帖子 / 我的点赞 / 浏览历史（/ 我的收藏）」多列「列均衡」阈值（vp，方案 B 滞回，2026-09-14，
 * 与 §4.9 / §4.10 / §4.8 T-D 同款）：轮转目标列与最短列的估算高差超过该值时改投最短列（补位）。
 * ContentCard 无图片区（仅标题/摘要 ≤2 行 + 信息行），高度差 ≤80vp，滞回 240 下几乎恒为纯轮转（保序），
 * 只有极端长短交错才补位。
 */
const PERSONAL_COL_BALANCE_THRESHOLD: number = 240;

/**
 * 列表预加载阈值（vp，2026-09-19，同 docs/帖子预加载.md §2）：滚动到「距内容底部剩余距离 < 该值」时
 * 提前静默加载下一页，让追加落在视口下方、在用户滑到底部边界之前完成，避免「边界回弹瞬间插入新内容」造成抽搐。
 * List 无内容总高接口 → 内容高按 ContentCard 估算高（estimateContentCardHeight）折算，与列均衡分桶同式。
 */
const PERSONAL_PREFETCH_DISTANCE: number = 1000;
/** 预加载触发的最小滚动增量（vp）：同一屏内只触发一次，防逐帧回调反复穿透状态锁（节流） */
const PERSONAL_PREFETCH_THROTTLE: number = 120;

@Entry
@Component
struct PersonalContent {
  @State mode: string = PersonalMode.Posts;
  @State title: string = '我的帖子';
  @State items: PersonalContentItem[] = [];
  @State state: LoadState = LoadState.Loading;
  @State errorMsg: string = '';
  @State isDark: boolean = isDarkMode();
  @State loading: boolean = false;
  @State loadingMore: boolean = false;
  @State hasMore: boolean = true;
  @State accountId: string = '';
  @StorageLink('fontScale') fontScale: number = 1.0;

  // ===== 平板适配（docs/TiebaPura平板适配.md §4.11，2026-09-14）=====
  /** 大屏形态设备（平板 / 2in1 / 折叠屏）：静态判定一次。折叠屏 deviceType 为 'phone'，必须单独用 isFoldable 识别（§4.8 T-B 同款） */
  private readonly isWideFormDevice: boolean = detectWideFormDevice();
  /** 窗口宽 / 高（vp）：aboutToAppear 同步取首帧初值，onAreaChange 实时兜底 */
  @State pageWidth: number = 0;
  @State pageHeight: number = 0;
  private isLandscape: boolean = false;
  /** 内容区实宽（vp）：分桶估算列宽用，根 Stack onAreaChange 维护 */
  @State currentWidth: number = 0;
  /** 页面可见时自增，强制组件重建使字号实时生效 */
  @State fontSizeTick: number = 0;
  // 「列数调整」档位广播（2026-09-18，个性化 → 列数调整）：@Watch 回写本地档位 → 列数函数按新档返回并强制回到列表顶部
  // （离屏期间 @StorageLink 同步不重绘，故用 tick + 本地 @State 兜底，同 fontTick 范式）
  @StorageLink('columnModeTick') @Watch('onColumnModeTick') columnModeTick: number = 0;
  @State columnMode: number = 0;
  /** 内容列表 Scroller：「列数调整」切档后强制回到列表顶部用（2026-09-18） */
  private listScroller: Scroller = new Scroller();
  /** 下拉刷新进行中（2026-09-22，docs/下拉刷新.md）：显式 true→false 变化链 + 看门狗 */
  @State pullRefreshing: boolean = false;
  /** API26+ 沉浸光感能力：true 时顶栏走官方 title 槽位，否则回退自绘玻璃 TopBar（与 ThreadDetail 同判据） */
  @State materialSupported: boolean = false;

  onPageShow(): void {
    this.fontSizeTick++;
    // 浏览历史「实时更新」（2026-09-23）：本页被别的页面盖住后重新显示（例如从历史里点开帖子再返回）时
    // 重读本地记录，让刚浏览的帖立刻回到列表顶部。仅历史模式重读——点赞 / 收藏是云端分页，
    // 每次回页都重拉会打断浏览（点赞翻页重排曾出现抽搐）。首次 onPageShow 与 aboutToAppear 的
    // 首次加载重合，用 pageShownOnce 跳过以免重复读盘。
    if (this.mode === PersonalMode.History) {
      if (this.pageShownOnce) {
        this.loadItems(true);
      } else {
        this.pageShownOnce = true;
      }
    }
  }
  /** onPageShow 是否已出现过一次（跳过与 aboutToAppear 重合的首帧） */
  private pageShownOnce: boolean = false;
  private pageSize: number = 20;
  /** 「我的点赞」云端已加载到的页码（1 基，与服务端 pn 语义一致） */
  private likesPage: number = 0;
  // ===== 列表预加载（2026-09-19，docs/帖子预加载.md §2）=====
  /** List 视口高（vp，onAreaChange 实测）；普通字段（非 @State）避免高频回调触发整树重建 */
  private viewportH: number = 0;
  /**
   * 剩余距离预取闸门（2026-09-19 口径修正）：偏移只取 `Scroller.currentOffset()` 真值，
   * 不再用 `onScroll` 回调入参（其语义在工具链间有差异，会让剩余距离恒小 → 预取乱触发或永不触发）。
   */
  private prefetchGate: PrefetchGate = new PrefetchGate(PERSONAL_PREFETCH_DISTANCE, 'PersonalContent');
  /** 请求代际：首屏 / 重新加载自增，作废在途的「加载更多」结果 */
  private loadToken: number = 0;

  aboutToAppear(): void {
    MaterialManager.init();
    this.materialSupported = MaterialManager.isSupported() && MaterialManager.getApiLevel() >= 26;
    const params = this.getUIContext().getRouter().getParams() as Record<string, Object>;
    this.mode = `${params?.mode ?? PersonalMode.Posts}`;
    this.title = this.modeTitle(this.mode);
    this.isDark = isDarkMode();
    this.accountId = AuthManager.getInstance().getUser()?.userId ?? '';
    // 首帧形态初值（§4.6 H-A / §4.8 T-B 同源）：onAreaChange 只在尺寸变化后触发，冷启动平板横屏
    // 若不预置会出现「先 1 列再跳 3/4 列」的首帧跳变。取不到就保持 0，由 onAreaChange 兜底。
    this.refreshFormMetrics();
    // 「列数调整」档位初值（2026-09-18）：冷启动首帧即按已选档渲染
    // （UsageHabitsManager.init 的 columnModeTick 可能早于本页构造，@Watch 不会补触发，故此处直读）
    this.columnMode = readColumnMode();
    this.loadItems();
  }

  /**
   * 「列数调整」档位变化（个性化页写入 → `columnModeTick` 广播）：
   * 回写本地档位（列数函数随新档返回）→ 强制回到列表顶部。
   * 默认档（0）与原自动适配逐像素一致，仅「用户显式选择」后才改变列数。
   */
  private onColumnModeTick(): void {
    this.columnMode = readColumnMode();
    try {
      this.listScroller.scrollTo({ xOffset: 0, yOffset: 0 });
    } catch (e) {
    }
  }

  /** 形态度量回填：aboutToAppear 首帧（display 兜底猜测）+ 根 Stack onAreaChange（窗口实值）共用。
   *  2026-09-17 小窗 / 分屏适配：传入窗口宽高时以窗口为准（自由多窗下 display ≠ 窗口）。 */
  private refreshFormMetrics(winW?: number, winH?: number): void {
    let w: number = winW ?? 0;
    let h: number = winH ?? 0;
    if (w <= 0 || h <= 0) {
      try {
        const d = display.getDefaultDisplaySync();
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
    // 尺寸同值短路（2026-09-18 旋转丝滑）：旋转期 onAreaChange 逐帧回调，同值重写 @State 会白触发
    // 页面整树重渲染；本函数只有下面三个赋值、无别的副作用，值未变直接返回。
    if (w === this.pageWidth && h === this.pageHeight) {
      return;
    }
    this.pageWidth = w;
    this.pageHeight = h;
    this.isLandscape = w > h;
  }

  private modeTitle(mode: string): string {
    if (mode === PersonalMode.Likes) return '我的点赞';
    if (mode === PersonalMode.Collections) return '我的收藏';
    if (mode === PersonalMode.History) return '浏览历史';
    return '我的帖子';
  }

  private async loadItems(silent: boolean = false): Promise<void> {
    if (this.loading) return;
    this.loading = true;
    // 首屏 / 重新加载：递增代际作废在途的「加载更多」，并复位预加载节流基线
    this.loadToken++;
    this.prefetchGate.reset();
    // silent（下拉刷新）：不切 Loading 态，保持当前列表在场，结果返回后一次性替换
    if (!silent) {
      this.state = LoadState.Loading;
    }
    try {
      if (this.mode === PersonalMode.Posts) {
        const list = await TiebaService.getInstance().fetchUserContent(this.accountId, 1, true);
        this.items = this.mergeItems([], list);
        this.hasMore = list.length >= this.pageSize;
      } else if (this.mode === PersonalMode.Collections) {
        const cloud = await TiebaService.getInstance().fetchCollectedThreads(this.accountId, 0, this.pageSize);
        const cachedRaw = await CacheManager.getInstance().get(`${CACHE_KEY.PERSONAL_COLLECTED}_${this.accountId}`);
        const cached = cachedRaw ? JSON.parse(cachedRaw) as PersonalContentItem[] : [];
        this.items = this.mergeItems(cached, cloud);
        await CacheManager.getInstance().put(`${CACHE_KEY.PERSONAL_COLLECTED}_${this.accountId}`, JSON.stringify(this.items));
        this.hasMore = cloud.length >= this.pageSize;
      } else if (this.mode === PersonalMode.Likes) {
        await this.loadLikes();
      } else {
        // 浏览历史（2026-09-23 修复）：读 HistoryStore —— 同帖去重 + 按**浏览时间**倒序。
        // 旧实现直接读原始数组再按 createTime（帖子**发布时间**的展示串，如「54 分钟前」「09-21 19:34」）
        // 排序，而 Date.parse 对这两类串的结果分别是 0 与 2001 年 → 排序与浏览先后无关，
        // 刚浏览的帖（相对时间串）被压到列表最底部，表现为「刚浏览过的帖在历史里看不到」。
        this.items = await HistoryStore.getInstance().load(this.accountId);
        this.hasMore = false;
      }
      this.state = this.items.length > 0 ? LoadState.Success : LoadState.Empty;
    } catch (e) {
      const message: string = e instanceof Error ? e.message : `${e}`;
      if (silent && this.items.length > 0) {
        // 静默刷新失败且已有内容：保留旧列表只提示，不清空、不落错误页
        this.getUIContext().getPromptAction().showToast({
          message: `刷新失败：${message.trim().length > 0 ? message : '请稍后重试'}`
        });
      } else {
        this.items = [];
        this.state = LoadState.Error;
        this.errorMsg = message.trim().length > 0 ? message : `${this.title}加载失败，请稍后重试`;
      }
    } finally {
      this.loading = false;
    }
  }

  /**
   * 下拉刷新（2026-09-22，docs/下拉刷新.md）：走 loadItems(silent=true)——
   * 保列表在场、不切 Loading；进入即显式置 true（false→true→false 变化链，否则指示器永久转圈），
   * 15s 看门狗兜底强制收起。
   */
  private async pullRefresh(): Promise<void> {
    this.pullRefreshing = true;
    const watchdog: number = setTimeout(() => {
      this.pullRefreshing = false;
    }, 15000);
    try {
      await this.loadItems(true);
    } finally {
      clearTimeout(watchdog);
      this.pullRefreshing = false;
    }
  }

  /**
   * 「我的点赞」：云端列表（官方 H5 myLike 背后的 /c/u/feed/userAgree）与本地点赞记录合并。
   * 先出本地缓存保证秒开；云端失败时若本地有记录则保留展示（离线 / 未登录不空页）。
   */
  private async loadLikes(): Promise<void> {
    const cacheKey: string = `${CACHE_KEY.PERSONAL_LIKED}_${this.accountId}`;
    const cachedRaw = await CacheManager.getInstance().get(cacheKey);
    const cached: PersonalContentItem[] = cachedRaw ? JSON.parse(cachedRaw) as PersonalContentItem[] : [];
    this.items = this.sortItems(cached);
    this.hasMore = false;
    try {
      const result: PagedResult<PersonalContentItem> = await TiebaService.getInstance().fetchUserAgreeThreads(1, this.pageSize);
      this.likesPage = 1;
      this.items = this.appendUnique(cached, result.list);
      this.hasMore = result.hasMore;
      await CacheManager.getInstance().put(cacheKey, JSON.stringify(this.items));
    } catch (e) {
      const message: string = e instanceof Error ? e.message : `${e}`;
      if (this.items.length === 0) {
        throw new Error(message);
      }
      this.getUIContext().getPromptAction().showToast({ message: `云端点赞加载失败：${message}` });
    }
  }

  /** 页面内容层（原 build() 根 Stack，槽位 / 兜底两条路径共用） */
  @Builder
  ContentLayer() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.state === LoadState.Loading) {
        LoadingView({ message: `正在加载${this.title}...` }).layoutWeight(1)
      } else if (this.state === LoadState.Error) {
        ErrorView({ message: this.errorMsg, onRetry: () => { this.loadItems(); } }).layoutWeight(1)
      } else if (this.state === LoadState.Empty) {
        EmptyView({ message: this.emptyMessage(), icon: '○' }).layoutWeight(1)
      } else {
        // 下拉刷新（2026-09-22，docs/下拉刷新.md）：与首页/消息页/进吧页同款——Refresh 容器
        // margin 下移到顶栏之下（默认指示器随之出现在顶栏下方），定高扣除下移量防底部溢出；
        // 内容里原 98vp 顶栏让位与顶部渐显带（容器高度比例，会随容器下移压到首卡上）一并交接/移除
        Refresh({ refreshing: this.pullRefreshing, offset: 48, friction: 62 }) {
        List({ scroller: this.listScroller }) {
          if (this.pcColumns() > 1) {
            // 多列档（§4.11 P-B，2026-09-14）：列内独立堆叠瀑布流（与首页 / 收藏页 / 搜索页同款观感）。
            // 结构照收藏页五轮教训：外层 ForEach **只遍历列索引**（key 稳定 → 列容器复用），
            // 内层数据源**直读状态源** `pcColumnsData()[colIdx]`（不用外层传入 col，否则复用断链不更新）；
            // ⚠️ 列外必须有**横排 Row**（首个版本漏了 → 4 个 ListItem 纵排通栏，视觉与单列无异）；
            // List 容器不变 → onReachEnd / onScrollIndex / 滚动架构零改动。
            ListItem() {
              Row({ space: 6 }) {
                ForEach(this.pcColIndexes(), (colIdx: number) => {
                  Column({ space: 6 }) {
                    ForEach(this.pcColumnsData()[colIdx], (item: PersonalContentItem) => {
                      Column() {
                        this.ContentCard(item, 0)
                      }
                      .transition(TransitionEffect.OPACITY.animation({ duration: 160, curve: Curve.EaseOut }))
                    }, (item: PersonalContentItem) => item.tid)
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                }, (colIdx: number) => `pcol_${colIdx}`)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
            }
          } else {
            // 单列档：逐像素保持改造前结构
            // key 只用 tid：tid 是合并去重的主键，用 `${id}_${tid}` 时同一条帖的 id 若在
            // 本地缓存 / 云端之间不一致会换 key，导致 ListItem 被销毁重建（闪现）。
            ForEach(this.items, (item: PersonalContentItem) => {
              ListItem() {
                this.ContentCard(item, Spacing.md)
              }
            }, (item: PersonalContentItem) => item.tid)
          }
        }
        .height('100%')
        .padding({ left: Spacing.lg, right: Spacing.lg, top: 0, bottom: Spacing.xl })
        .scrollBar(BarState.Off)
        .clip(false)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        // 剩余距离预加载（docs/帖子预加载.md §2/§4.4）：距底 < PERSONAL_PREFETCH_DISTANCE 提前静默取下一页；
        // 与 onScrollIndex 预取位互补（本阈值支持多列档按剩余距离提前量触发）；onReachEnd 保留作兜底
        .onScroll((_x: number, y: number) => { this.onListScroll(_x, y); })
        .onAreaChange((_old: Area, n: Area) => { this.onListAreaChange(_old, n); })
        .onReachEnd(() => { this.loadMore(); })
        // 距末尾还有 5 项就提前取下一页：让追加落在视口下方、在用户滑到底部边界之前完成，
        // 避免「边界回弹的瞬间插入新内容」造成抽搐；onReachEnd 保留作兜底（列表不满一屏等）。
        // 多列档整个内容区只有 1 个 ListItem（内含横排 Row）→ end >= 1 即「内容行可见」时提前取
        // （loadMore 有 loadingMore 防抖，重复触发无副作用；内容超过一屏后 end 恒为 1 → 相当于持续预取位）。
        .onScrollIndex((start: number, end: number) => {
          if (this.pcColumns() > 1) {
            if (end >= 1) {
              this.loadMore();
            }
            return;
          }
          if (end >= this.items.length - 5) {
            this.loadMore();
          }
        })
        }
        .width('100%')
        .height('calc(100% - 98vp)')
        .margin({ top: 98 })
        .onRefreshing(() => { this.pullRefresh(); })
      }

      // 悬浮顶栏（内容可穿过）；官方 title 槽位路径下已在槽位里（PersonalTitleBar），不再叠一层
      if (!(PERSONAL_CONTENT_OFFICIAL_TITLE_BAR && this.materialSupported)) {
        this.TopBar()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg(this.isDark))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    // 内容区实宽（分桶估算列宽用）+ 形态变化兜底（横竖屏 / 分屏拖宽：§4.11 P-B，与 §4.8 T-B 同款同点追加）
    .onAreaChange((_old: Area, n: Area) => {
      this.currentWidth = n.width as number;
      // 窗口实值优先（2026-09-17 小窗 / 分屏适配：自由多窗下 display ≠ 窗口）
      this.refreshFormMetrics(n.width as number, n.height as number);
    })
  }

  build() {
    if (PERSONAL_CONTENT_OFFICIAL_TITLE_BAR && this.materialSupported) {
      // 官方槽位路径（§6.10）：返回钮 + 标题搬进 Navigation title 槽位吃真材质
      Navigation() {
        this.ContentLayer()
      }
      .title({ builder: this.PersonalTitleBar(), height: PERSONAL_CONTENT_TITLE_BAR_HEIGHT },
        { barStyle: BarStyle.STACK, backgroundColor: Color.Transparent })
      .mode(NavigationMode.Stack)
      .hideTitleBar(false)
      .hideBackButton(true)
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.bg(this.isDark))
      .clip(false)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    } else {
      // 兜底路径：页面主体悬浮自绘玻璃（改造前原样）
      this.ContentLayer()
    }
  }

  private mergeItems(local: PersonalContentItem[], remote: PersonalContentItem[]): PersonalContentItem[] {
    const map: Map<string, PersonalContentItem> = new Map<string, PersonalContentItem>();
    for (const item of local.concat(remote)) {
      if (item.accountId !== undefined && item.accountId !== this.accountId) continue;
      const key: string = item.tid.trim();
      if (key.length > 0) {
        const normalized: PersonalContentItem = {
          id: item.id,
          tid: item.tid,
          title: item.title,
          forumName: item.forumName,
          author: item.author,
          abstract: item.abstract,
          replyNum: item.replyNum,
          createTime: item.createTime,
          accountId: this.accountId
        };
        map.set(key, normalized);
      }
    }
    return this.sortItems(Array.from(map.values()));
  }

  private sortItems(items: PersonalContentItem[]): PersonalContentItem[] {
    return items.slice().sort((a: PersonalContentItem, b: PersonalContentItem): number => {
      const left: number = Date.parse(a.createTime) || Number(a.createTime) || 0;
      const right: number = Date.parse(b.createTime) || Number(b.createTime) || 0;
      return right - left;
    });
  }

  /**
   * 「我的点赞」合并专用：按 tid 去重后**原序追加**，不做任何排序。
   *
   * 为什么不复用 mergeItems：mergeItems 末尾会 sortItems 全量重排，而点赞项的 createTime 映射的是
   * `last_time`（最后回复时间，形如 "9-10"）**不是点赞时间**，与服务端的点赞序不一致。翻页时整体重排
   * 会把新一页的项插进列表中部，使 ForEach 已渲染项集体移位、List 在滚动中重新布局，表现为
   * 「滑到底加载更多时明显抽搐」。
   *
   * 服务端 thread_list 本身已是权威顺序（最近点赞优先），因此首页 local→remote、翻页 existing→新页
   * 都只需去重追加：已有项保持原对象引用（ForEach key 不变、不重建），新项稳定落在末尾。
   */
  private appendUnique(existing: PersonalContentItem[], incoming: PersonalContentItem[]): PersonalContentItem[] {
    const merged: PersonalContentItem[] = existing.slice();
    const seen: Set<string> = new Set<string>();
    for (const item of merged) {
      const key: string = item.tid.trim();
      if (key.length > 0) {
        seen.add(key);
      }
    }
    for (const item of incoming) {
      if (item.accountId !== undefined && item.accountId !== this.accountId) continue;
      const key: string = item.tid.trim();
      if (key.length === 0 || seen.has(key)) continue;
      seen.add(key);
      merged.push({
        id: item.id,
        tid: item.tid,
        title: item.title,
        forumName: item.forumName,
        author: item.author,
        abstract: item.abstract,
        replyNum: item.replyNum,
        createTime: item.createTime,
        accountId: this.accountId
      });
    }
    return merged;
  }

  /**
   * 列数：大屏竖屏 3 / 横屏 4（与首页 §4.2 决策 12 同口径，§4.11 P-B）。
   * 形态闸门必须放首行：只按宽度判会让手机横屏（约 780vp ≥ 600）误命中多列（§6.1 D4）。
   */
  private pcColumns(): number {
    // 窗口闸门最前（2026-09-17 小窗 / 分屏适配）：窗口宽 <600（自由多窗小窗 / 分屏窄窗）一律回落
    // 手机单列档——须在设备恒值分支（大折叠恒 3）之前，防小窗误命中
    // 阔直屏全屏白名单（2026-09-18）：Pura X View（VOL-AL00）等阔直屏竖屏全屏窗口宽仅 ~440vp，
    // 会被本闸门误判成小窗；白名单放行（小窗 / 分屏仍拦，见 Theme.isWideBarFullscreen）
    if (this.pageWidth > 0 && this.pageWidth < Breakpoint.sm && !isWideBarFullscreen(this.pageWidth)) {
      return 1;
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
      return 1;
    }
    if (this.pageWidth < Breakpoint.sm) {
      return 1;
    }
    // 2026-09-17 三次拍板：平板**竖屏 2 列**（≥840 竖屏 3 列作废）/ 横屏 3 列（四 mode 共用）
    return this.isLandscape ? 3 : 2;
  }

  /** 列索引数组 [0..列数-1]：外层 ForEach 只遍历索引（key 稳定 → 列容器复用，收藏页五轮教训） */
  private pcColIndexes(): number[] {
    const n: number = this.pcColumns();
    const arr: number[] = [];
    for (let i = 0; i < n; i++) {
      arr.push(i);
    }
    return arr;
  }

  /**
   * 内容分桶（方案 B「带滞回的最短列」，2026-09-14，与 §4.9 / §4.10 / §4.8 T-D 同款）：
   * 默认按 `i % 列数` 轮转（保序观感），仅当轮转目标列与最短列的估算高差
   * > `PERSONAL_COL_BALANCE_THRESHOLD` 时改投最短列补位。
   * ContentCard 无图片区、高度差 ≤80vp → 滞回 240 下几乎恒为纯轮转；确定性估算、无测量循环；
   * 前缀稳定贪心：翻页追加从头重算，旧卡落列不变（不跳位）。
   */
  private pcColumnsData(): PersonalContentItem[][] {
    const cols: number = this.pcColumns();
    const buckets: PersonalContentItem[][] = [];
    const heights: number[] = [];
    for (let c = 0; c < cols; c++) {
      buckets.push([]);
      heights.push(0);
    }
    // 列宽（估算换行用）：内容区宽 − List 左右 padding(lg×2) − 列间 gap(6×(cols−1))
    const colWidth: number = (this.currentWidth - Spacing.lg * 2 - 6 * (cols - 1)) / cols;
    for (let i = 0; i < this.items.length; i++) {
      let target: number = i % cols;
      let shortest: number = 0;
      for (let c = 1; c < cols; c++) {
        if (heights[c] < heights[shortest]) {
          shortest = c;
        }
      }
      if (heights[target] - heights[shortest] > PERSONAL_COL_BALANCE_THRESHOLD) {
        target = shortest;
      }
      buckets[target].push(this.items[i]);
      // 列内间距 6 = 渲染层 `Column({ space: 6 })`（卡片 margin 已参数化为 0，2026-09-14）
      heights[target] += this.estimateContentCardHeight(this.items[i], colWidth) + 6;
    }
    return buckets;
  }

  /**
   * ContentCard 估算高（vp，仅供列均衡分桶，不求像素准只求相对准，与渲染同式）：
   * padding(lg×2=32) + 信息行 ~16 + 间距 = 常数底数 62；
   * 标题 ≤2 行（fs16→行高 22）、摘要 ≤2 行（fs13→行高 18），每行字数按列宽折算。
   * 多列档卡片无底部外距（margin 参数化为 0），列间距由分桶循环的 +6 承担。
   */
  private estimateContentCardHeight(item: PersonalContentItem, colWidth: number): number {
    let h: number = 62;
    const title: string = item.title ?? '';
    if (title.length > 0) {
      const cpl: number = Math.max(8, Math.floor(colWidth / 16));
      h += Math.min(Math.ceil(title.length / cpl), 2) * 22 + 6;
    }
    const abs: string = item.abstract ?? '';
    if (abs.length > 0) {
      const cpl2: number = Math.max(10, Math.floor(colWidth / 13));
      h += Math.min(Math.ceil(abs.length / cpl2), 2) * 18 + 6;
    }
    return h;
  }

  /**
   * 触底翻页：收藏走 offset，点赞走 1 基页码 pn（服务端 data.has_more 判定）。
   * silent=true 为预加载触发：失败静默丢弃（不打断浏览），手动触底仍提示。
   */
  private async loadMore(silent: boolean = false): Promise<void> {
    if (this.loading || this.loadingMore || !this.hasMore) return;
    const isLikes: boolean = this.mode === PersonalMode.Likes;
    if (!isLikes && this.mode !== PersonalMode.Collections) return;
    this.loadingMore = true;
    const myToken: number = this.loadToken;
    try {
      if (isLikes) {
        const result: PagedResult<PersonalContentItem> =
          await TiebaService.getInstance().fetchUserAgreeThreads(this.likesPage + 1, this.pageSize);
        // 代际校验：首屏 / 重载期间返回的旧页直接丢弃（防重复与错序）
        if (myToken !== this.loadToken) return;
        this.likesPage += 1;
        this.items = this.appendUnique(this.items, result.list);
        await CacheManager.getInstance().put(`${CACHE_KEY.PERSONAL_LIKED}_${this.accountId}`, JSON.stringify(this.items));
        this.hasMore = result.hasMore;
      } else {
        const remote = await TiebaService.getInstance().fetchCollectedThreads(this.accountId, this.items.length, this.pageSize);
        if (myToken !== this.loadToken) return;
        this.items = this.mergeItems(this.items, remote);
        await CacheManager.getInstance().put(`${CACHE_KEY.PERSONAL_COLLECTED}_${this.accountId}`, JSON.stringify(this.items));
        this.hasMore = remote.length >= this.pageSize;
      }
      this.state = this.items.length > 0 ? LoadState.Success : LoadState.Empty;
    } catch (e) {
      if (!silent && myToken === this.loadToken) {
        const tip: string = isLikes ? '更多点赞加载失败，请稍后重试' : '更多收藏加载失败，请稍后重试';
        this.getUIContext().getPromptAction().showToast({ message: tip });
      }
    } finally {
      this.loadingMore = false;
    }
  }

  /**
   * 列表预加载（2026-09-19，docs/帖子预加载.md §2/§4.4）：滚动到「距内容底部剩余距离 < PERSONAL_PREFETCH_DISTANCE」
   * 时提前静默加载下一页，让追加落在视口下方、在用户滑到底部边界之前完成（避免边界回弹瞬间插入新内容造成抽搐）。
   * onReachEnd 保留作兜底（列表不满一屏等）。仅在点赞 / 收藏（有云端分页）模式下生效；
   * 「我的帖子 / 浏览历史」为本地一次全量读取（hasMore=false）→ 本函数自然不触发。
   * 双重防重：loadingMore 状态锁 + 偏移 PERSONAL_PREFETCH_THROTTLE 节流；loadMore 内另做请求代际校验。
   */
  private onListScroll(_x: number, _y: number): void {
    if (this.loadingMore || !this.hasMore || this.state !== LoadState.Success) {
      return;
    }
    if (this.mode !== PersonalMode.Likes && this.mode !== PersonalMode.Collections) {
      return;
    }
    // 偏移取 Scroller 真值（onScroll 回调入参语义在工具链间有差异，非绝对偏移会让剩余距离恒小）
    if (this.prefetchGate.should(PrefetchGate.absoluteY(this.listScroller), this.estimatedContentH(), this.viewportH)) {
      this.loadMore(true);
    }
  }

  /** 视口尺寸变化：记录 List 视口高（供剩余距离估算；普通字段，避免写入 @State 触发整树重建） */
  private onListAreaChange(_old: Area, n: Area): void {
    this.viewportH = n.height as number;
  }

  /** 单列卡宽（vp）：与 pcColumnsData 同式（内容区宽 − List 左右 padding(lg×2) − 列间 gap(6×(cols−1))） */
  private pcColWidth(): number {
    const cols: number = this.pcColumns();
    return (this.currentWidth - Spacing.lg * 2 - 6 * (cols - 1)) / cols;
  }

  /**
   * 内容总高估算（vp）：List 无内容总高接口 → 首项顶栏占位 98 + 列高（卡片估算高之和 / 列数）+ 底部 padding(Spacing.xl)。
   * 与列均衡分桶（estimateContentCardHeight）同源同式，只求相对准以定位阈值，不求像素级吻合。
   */
  private estimatedContentH(): number {
    const cols: number = this.pcColumns();
    let sum: number = 0;
    for (let i = 0; i < this.items.length; i++) {
      sum += this.estimateContentCardHeight(this.items[i], this.pcColWidth()) + 6;
    }
    return 98 + sum / cols + Spacing.xl;
  }

  private emptyMessage(): string {
    if (this.mode === PersonalMode.Posts) return '暂时没有发布过主题帖';
    if (this.mode === PersonalMode.Likes) return '暂时没有点赞记录';
    if (this.mode === PersonalMode.Collections) return '暂时没有收藏记录';
    return '暂时没有浏览历史';
  }

  /** 兜底路径专用（开关关闭 / 低版本时才挂载）：页面主体悬浮自绘玻璃顶栏 */
  @Builder
  TopBar() {
    Row() {
      Button() {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontColor([$r('sys.color.icon_primary')]).fontSize(fs(24, this.fontScale))
      }
      .width(44)
      .height(44)
      .backgroundColor(Color.Transparent)
      .shadow(Theme.glassShadowStyle()).backgroundEffect(ImmBlur.control())
      .systemMaterial(ImmMaterial.control())
      .borderRadius(Radius.full)
      .onClick(() => { this.getUIContext().getRouter().back(); })
      Text(this.title)
        .fontSize(fs(19, this.fontScale))
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.textPrimary(this.isDark))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Blank().width(44).height(44)
    }
    .width('100%')
    .height(98)
    .padding({ left: Spacing.lg, right: Spacing.lg, top: 44, bottom: 10 })
    .backgroundColor(Color.Transparent)
  }

  /**
   * 官方槽位标题栏（§6.10 同机制）：返回 44 圆钮 + 居中标题 + 右侧 44 占位（保证标题精确居中）。
   * 玻璃换成 `ImmMaterial.seg(false)`（THIN 中性档），按坑 24 删除 `glassShadowStyle` +
   * `backgroundEffect(ImmBlur.control())` + `control()` 三项自绘玻璃（`backgroundColor(Transparent)`
   * 是 Button 清默认填充，保留）；几何（top 44 / bottom 10 / 左右 Spacing.lg / 圆钮 44 / 标题 fontSize 19
   * 居中 / Blank 44）逐项一致，槽位高度由 options 的 98 承担。
   */
  @Builder
  PersonalTitleBar() {
    Row() {
      Button() {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontColor([$r('sys.color.icon_primary')]).fontSize(fs(24, this.fontScale))
      }
      .width(44)
      .height(44)
      .backgroundColor(Color.Transparent)
      .systemMaterial(ImmMaterial.seg(false))
      .borderRadius(Radius.full)
      .accessibilityText('返回')
      .onClick(() => { this.getUIContext().getRouter().back(); })
      Text(this.title)
        .fontSize(fs(19, this.fontScale))
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.textPrimary(this.isDark))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Blank().width(44).height(44)
    }
    .width('100%')
    .padding({ left: Spacing.lg, right: Spacing.lg, top: 44, bottom: 10 })
  }

  /**
   * 卡片右下角时间文案（2026-09-23）：「浏览历史」显示**浏览时间**（列表已按浏览时间倒序，
   * 配浏览时间才自洽——刚看完的帖显示「刚刚」，从而直观体现"实时更新"）；其余模式维持
   * 帖子发布/最后回复时间（`createTime`，原样）。老记录无 visitTime 时回落 createTime。
   */
  private cardTimeText(item: PersonalContentItem): string {
    if (this.mode === PersonalMode.History) {
      const visitTime: number = item.visitTime ?? 0;
      if (visitTime > 0) {
        const text: string = formatTime(visitTime);
        if (text.length > 0) {
          return text;
        }
      }
    }
    return item.createTime;
  }

  /**
   * 内容卡。`bottomMargin` = 卡片底部外距：**单列档传 `Spacing.md`(12)**（原样承担手机行间距，
   * 逐像素不变）；**多列档传 0**（列内间距由外层 `Column({ space: 6 })` 承担 → 上下 6 = 左右列间 6，
   * 2026-09-14 用户要求「上下间距跟左右间距一致」；原样叠加会造成上下 18 vs 左右 6）。
   */
  @Builder
  ContentCard(item: PersonalContentItem, bottomMargin: number) {
    Column({ space: 6 }) {
      Text(item.title)
        .fontSize(fs(16, this.fontScale))
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.textPrimary(this.isDark))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Text(item.abstract || '暂无摘要')
        .fontSize(fs(13, this.fontScale))
        .fontColor(Theme.textSecondary(this.isDark))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Row() {
        Text(item.forumName)
          .fontSize(fs(11, this.fontScale))
          .fontColor(Theme.brand())
        Blank()
        Text(`${item.replyNum} 回复`)
          .fontSize(fs(11, this.fontScale))
          .fontColor(Theme.textTertiary(this.isDark))
        Text(this.cardTimeText(item))
          .fontSize(fs(11, this.fontScale))
          .fontColor(Theme.textTertiary(this.isDark))
          .margin({ left: 8 })
      }
      .width('100%')
    }
    .width('100%')
    .padding(Spacing.lg)
    .backgroundColor(Theme.bgCard(this.isDark))
    // 卡片圆角 26：我的帖子 / 我的点赞 / 浏览历史 / 我的收藏四页共用本卡片，与首页 ThreadCard、
    // 详情页卡片统一口径（不借用全局 Radius.lg）
    .borderRadius(26)
    .margin({ bottom: bottomMargin })
    .onClick(() => {
      // 点击即预取：利用跳转动画窗口后台取详情，详情页打开即命中缓存秒开
      TiebaService.getInstance().prefetchThreadDetail(`${item.tid}`, '');
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/ThreadDetail',
        params: { tid: item.tid, forum: item.forumName }
      });
    })
  }

}
