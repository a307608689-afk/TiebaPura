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

import { curves, display } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { TiebaService } from '../service/TiebaService';
import { CacheManager } from '../cache/CacheManager';
import { CACHE_KEY } from '../common/Constants';
import { ThreadItem, ForumHeaderInfo, PagedResult } from '../model/DataModel';
import { Theme, Spacing, Radius, Breakpoint, CARD_COLUMNS_KEY, isDarkMode, ImmMaterial, MaterialManager, fs,
  isWideBarDevice, isLargeFoldDevice, isWideFormDevice as detectWideFormDevice, readColumnMode, overrideColumns,
  isLargeScreenForm, isWideBarFullscreen } from '../common/Theme';
import { LoadingView, EmptyView, ErrorView, ThreadCard, ThreadItemData, ThreadSharePayload } from '../components/CommonComponents';
import { ShareUtil } from '../common/ShareUtil';

/**
 * 精选二级分类页（2026-09-21，十四轮改定：双常驻槽位角色轮换）：
 * 入口 = 吧主页 ThreadList 底部排序栏「精选」钮长按（350ms + Haptic.light），自下而上转场进入。
 *
 * 顶部：满宽渐显带（背景色→透明）+ 分类胶囊行（空 tabBar 壳官方沉浸光感，低版本真模糊兜底）；
 * 无返回钮 / 无吧名，返回走系统侧滑 / 手势。内容首项 88 占位，滚动时从渐显带下穿过。
 *
 * **切换架构（双常驻槽位，根治「每次切换图片/头像闪一下」）**：
 *   两个内容槽位**永久存活**（translate 停靠屏外，组件状态与已解码图片全程保留），
 *   切换 = 角色轮换：
 *   - 目标分类的内容已在非活跃槽位（切回看过的分类）→ **零重建零闪**，直接对向平移；
 *   - 否则把目标数据写入非活跃槽位（屏外停靠构建），构建/图片解析完成后滑入；
 *   - 动画落定：活跃槽角色互换（无任何数据搬运/重建——重建被常驻槽位的现成内容彻底绕开）。
 *   对比：单槽 + reload 的方案每次切换全量重建 ThreadCard → 图片/头像重新挂载解码
 *   → 必然闪帧（吧主页列表常驻所以没这个问题）；componentSnapshot 对虚拟化容器截图不可靠。
 *
 * 数据链路：
 *   - 首屏一次请求两用：fetchGoodFirstPageCoalesced（长按按下即预取的合流消费）拿「全部」列表，
 *     同响应的 forum.good_classify 落进服务缓存 → getCachedGoodClassify 渲染胶囊；
 *   - 切分类 / 分类翻页 = fetchGoodCategoryThreads（仅 proto，cid=field 5 过滤；modern 兜底不支持
 *     cid，回落会错拿「全部」内容伪装成该分类）；
 *   - 会话快照 LRU cap 8：槽位没 holding 的分类从会话/网络装载；
 *   - 「全部」首屏走 ThreadList 预热的磁盘缓存（FORUM_LIST_kw_2，stale-while-revalidate）。
 *
 * 切换动画：两槽对向平移（ThreadList 排序切换同款 springMotion 320ms / 收口 420ms）。
 * 手势：外层普通 Column 上 parallelGesture(PanGesture Horizontal)，左滑下一个 / 右滑上一个；
 * 滑动锁（起手锁 / 250ms 延迟解锁）防横滑误触卡片点击。
 * 页面转场（RouteType 拆分）：Push 进=自下而上 / Push 出=静止 / Pop 出=向下收回 / Pop 入=静止。
 */

/** 顶让位（胶囊行 + 状态栏）：44 + 42 + 2，内容首项占位同值 */
const GOOD_TITLE_BAR_HEIGHT: number = 88;
/** 多列档顶部额外留白：平板/折叠形态瀑布流首行卡与胶囊行的间距（单列档不加，保持手机观感） */
const GOOD_TOP_EXTRA: number = 12;
/** 满宽渐显带高度：胶囊行之下再延 32vp 渐隐 */
const GOOD_SCRIM_HEIGHT: number = 120;
/** 切换过场：时长与收口（ThreadList SORT_ANIM_* 同值） */
const GOOD_ANIM_DURATION: number = 320;
const GOOD_ANIM_SETTLE: number = 420;
/** 会话快照 LRU 上限（含「全部」） */
const GOOD_SNAPSHOT_CAP: number = 8;
/** 会话快照保鲜期：过期命中仍直出 + 后台静默刷新 */
const GOOD_SESSION_TTL: number = 120000;
/** 滑动锁解锁延迟：盖过抬指时刻的 click 派发 */
const GOOD_SWIPE_UNLOCK_DELAY: number = 250;
/**
 * 多列「列均衡」阈值（vp，方案 B 滞回，与 §4.11 P-B / §4.9 / §4.10 同款）：轮转目标列与最短列的
 * 估算高差超过该值时改投最短列（补位）。ThreadCard 有图区（0~220），长短差比纯文字卡大，240 档同款。
 */
const GOOD_COL_BALANCE_THRESHOLD: number = 240;

enum GoodLoadState {
  Loading, Success, Empty, Error,
}

interface CategoryItem {
  cid: number;
  name: string;
}

/** 会话快照：某分类的数据 + 分页状态（槽位没 holding 的分类从会话装载） */
interface CategorySession {
  threads: ThreadItem[];
  page: number;
  hasMore: boolean;
  ts: number;
}

/** ThreadList 私有接口的同构副本（disk 缓存 value 形态），仅读不写 */
interface ForumListCacheView {
  threads: ThreadItem[];
  forumInfo: ForumHeaderInfo | null;
}

/**
 * 帖子数据源：全量替换 + 尾部追加。
 * 消费方**按形态分叉**（与吧主页 §4.8 同构）：单列档 `Scroll + Column + ForEach(分桶镜像[0])`；
 * 多列档 `Scroll + Row + 最短列分桶`（分桶镜像由 onMutate 触发 syncSlotColumns 重算写入 @State）。
 */
class GoodListDataSource implements IDataSource {
  private listeners: DataChangeListener[] = [];
  public data: ThreadItem[] = [];
  /** 变更回调：页面据此重算该槽列分桶镜像（两档渲染的共同驱动源） */
  public onMutate: () => void = () => {};

  totalCount(): number {
    return this.data.length;
  }

  getData(index: number): ThreadItem {
    return this.data[index];
  }

  reload(list: ThreadItem[]): void {
    this.data = list;
    this.listeners.forEach((l: DataChangeListener) => l.onDataReloaded());
    this.onMutate();
  }

  appendAll(list: ThreadItem[]): void {
    const start: number = this.data.length;
    this.data = this.data.concat(list);
    if (list.length > 0) {
      this.listeners.forEach((l: DataChangeListener) => l.onDataAdd(start));
    }
    this.onMutate();
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (!this.listeners.includes(listener)) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const idx: number = this.listeners.indexOf(listener);
    if (idx >= 0) {
      this.listeners.splice(idx, 1);
    }
  }
}

@Entry
@Component
struct GoodCategoryPage {
  @StorageLink('fontScale') fontScale: number = 1.0;
  @State isDark: boolean = false;
  // ===== 路由参数 =====
  private kw: string = '';
  private forumId: string = '';
  // ===== 分类 =====
  @State categories: CategoryItem[] = [{ cid: 0, name: '全部' }];
  @State selectedCid: number = 0;
  // ===== 双常驻槽位（角色轮换；组件永久存活，图片/滚动位置跨切换保留）=====
  @State ds0: GoodListDataSource = new GoodListDataSource();
  @State ds1: GoodListDataSource = new GoodListDataSource();
  // 多列档列分桶镜像（§4.11 P-B 同款，2026-09-22 定稿）：**主动算好写入 @State**（同步在 syncSlotColumns，
  // ds.onMutate / 列数变化双触发点）——@State 观察不到类内 data 重赋值，直读 ds.data 的 ForEach 不会随
  // 数据更新；原 WaterFlow + sections 方案的虚拟容器测量在双常驻槽位 + 沉浸布局下不可靠
  // （真机：卡片拉超长 / 图区大块空白 / 内容跨卡错位），与消息页 / 个人内容页同法收敛为全量渲染。
  @State slotCols0: ThreadItem[][] = [[]];
  @State slotCols1: ThreadItem[][] = [[]];
  private scroller0: Scroller = new Scroller();
  private scroller1: Scroller = new Scroller();
  @State activeSlot: number = 0;      // 当前交互槽（displayedCid 的内容在此）
  @State inSlot: number = -1;         // 动画中：进场槽（新内容）
  @State outSlot: number = -1;        // 动画中：退场槽（旧内容）
  private slotCid: number[] = [-1, -1];       // 各槽当前持有的分类（-1 = 空）
  // ===== 活跃分类的逻辑状态（翻页/点赞/刷新都作用于活跃槽）=====
  @State loadState: GoodLoadState = GoodLoadState.Loading;
  @State errorMsg: string = '';
  @State hasMore: boolean = true;
  @State page: number = 1;
  private displayedCid: number = 0;
  private stalledPages: number = 0;
  private loadingMore: boolean = false;
  private loadToken: number = 0;
  // ===== 会话快照（LRU）=====
  private sessions: Map<number, CategorySession> = new Map<number, CategorySession>();
  // ===== 切换过场（★ 必须 @State：普通字段上 animateTo 不驱动 UI，动画不会运行）=====
  @State inOffset: number = 0;   // 百分比语义（±100）：进场槽位移
  @State outOffset: number = 0;  // 百分比语义（±100）：退场槽位移
  private enterDir: number = 0;  // 本次切换方向（1=目标在右）
  private pendingSwitchDir: number = 0;  // 未命中快照：数据到手后再起滑的方向
  private pendingInSlot: number = -1;    // 未命中快照：数据写哪个槽
  private switchFromCid: number = -1;    // 未命中快照：起滑时旧内容归属的分类（落快照用）
  @State switching: boolean = false;     // 未命中快照的取数中（旧内容保持在场，仅挂轻量提示）
  private settleTimer: number = -1;
  private animUntil: number = 0;
  // 动画落定时的主列表落地包（与进场槽内容 identical，落定零重建零闪）
  private pendingCid: number = -1;
  private pendingList: ThreadItem[] = [];
  private pendingPageN: number = 1;
  private pendingMore: boolean = true;
  // ===== 滑动锁 =====
  private swipeLock: boolean = false;
  private swipeLockTimer: number = -1;
  // ===== 形态 =====
  @State pageWidth: number = 0;
  @State pageHeight: number = 0;
  @State currentWidth: number = 0;
  @State isLandscape: boolean = false;
  private isWideFormDevice: boolean = false;
  @State columnMode: number = 0;
  @StorageLink('columnModeTick') @Watch('onColumnModeTick') columnModeTick: number = 0;
  private colCacheKey: string = '';
  private colCacheValue: number = 1;
  // ===== 材质 =====
  private materialSupported: boolean = false;
  // ===== 下拉刷新 =====
  @State refreshing: boolean = false;

  aboutToAppear(): void {
    this.isDark = isDarkMode();
    // 首帧形态初值（§4.6 H-A 同源）：onAreaChange 只在尺寸变化后触发，先按当前 display 预置
    try {
      const d = display.getDefaultDisplaySync();
      const w: number = this.getUIContext().px2vp(d.width);
      const h: number = this.getUIContext().px2vp(d.height);
      this.pageWidth = w;
      this.pageHeight = h;
      this.currentWidth = w;
      this.isLandscape = w > h;
    } catch (e) {
      // 窗口未 attach：onAreaChange 兜底
    }
    this.isWideFormDevice = detectWideFormDevice();
    this.columnMode = readColumnMode();
    // 数据源变更 → 重算该槽列分桶镜像（多列档 Row 分桶 / 单列档 ForEach 的渲染驱动源）
    this.ds0.onMutate = (): void => { this.syncSlotColumns(0); };
    this.ds1.onMutate = (): void => { this.syncSlotColumns(1); };
    this.syncCardColumns();
    MaterialManager.init();
    this.materialSupported = MaterialManager.isSupported() && MaterialManager.getApiLevel() >= 26;
    const params = this.getUIContext().getRouter().getParams() as Record<string, string>;
    if (params) {
      if (params.kw) {
        this.kw = `${params.kw}`;
      } else if (params.forumName) {
        this.kw = `${params.forumName}`;
      }
      if (params.fid) {
        this.forumId = `${params.fid}`;
      }
    }
    if (this.kw.length === 0) {
      this.loadState = GoodLoadState.Error;
      this.errorMsg = '缺少贴吧名称，无法打开精选分类';
      return;
    }
    this.loadInitial();
  }

  aboutToDisappear(): void {
    if (this.settleTimer !== -1) {
      clearTimeout(this.settleTimer);
      this.settleTimer = -1;
    }
    if (this.swipeLockTimer !== -1) {
      clearTimeout(this.swipeLockTimer);
      this.swipeLockTimer = -1;
    }
    this.sessions.clear();
  }

  private getUIAbilityContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  // ===== 槽位访问 =====

  private slotDs(slot: number): GoodListDataSource {
    return slot === 0 ? this.ds0 : this.ds1;
  }

  private slotScroller(slot: number): Scroller {
    return slot === 0 ? this.scroller0 : this.scroller1;
  }

  private activeDs(): GoodListDataSource {
    return this.slotDs(this.activeSlot);
  }

  private activeScroller(): Scroller {
    return this.slotScroller(this.activeSlot);
  }

  // ===== 数据 =====

  /** 「全部」磁盘缓存 key：复用 ThreadList 预热的 FORUM_LIST_kw_2（sort=2 即精选） */
  private goodDiskCacheKey(): string {
    return `${CACHE_KEY.FORUM_LIST}_${this.kw}_2`;
  }

  /** 按分类取第 1 页：全部走合流（消费长按按下即预取），分类走仅-proto 专用请求（杜绝兜底错拿「全部」） */
  private fetchFirstPage(cid: number): Promise<PagedResult<ThreadItem>> {
    if (cid === 0) {
      return TiebaService.getInstance().fetchGoodFirstPageCoalesced(this.kw);
    }
    return TiebaService.getInstance().fetchGoodCategoryThreads(this.kw, 1, cid);
  }

  private fetchPage(cid: number, pageN: number): Promise<PagedResult<ThreadItem>> {
    if (cid === 0) {
      return TiebaService.getInstance().fetchForumThreads(this.kw, pageN, 2, false);
    }
    return TiebaService.getInstance().fetchGoodCategoryThreads(this.kw, pageN, cid);
  }

  /** 首屏：磁盘缓存直出（仅「全部」）+ 静默刷新；无缓存走合流请求。两条路都补分类清单。 */
  private async loadInitial(): Promise<void> {
    const myToken: number = ++this.loadToken;
    try {
      const cached = await CacheManager.getInstance().getWithTtlAllowStale<ForumListCacheView>(this.goodDiskCacheKey());
      if (myToken !== this.loadToken) {
        return;
      }
      if (cached && cached.data.threads.length > 0) {
        this.applyList(cached.data.threads, 1);
        this.refreshCategories();
        // stale-while-revalidate：后台静默刷新（同时刷新分类清单），失败保留旧内容
        this.refreshCurrentSilently();
        return;
      }
    } catch (_) {
      // 缓存读失败照常走网络
    }
    try {
      const result = await this.fetchFirstPage(0);
      if (myToken !== this.loadToken) {
        return;
      }
      if (result.list.length === 0) {
        this.loadState = GoodLoadState.Empty;
        this.hasMore = false;
        this.refreshCategories();
        return;
      }
      this.applyList(result.list, 1);
      this.hasMore = result.hasMore;
      this.saveSession(0, { threads: result.list, page: 1, hasMore: result.hasMore, ts: Date.now() });
      this.refreshCategories();
    } catch (e) {
      if (myToken !== this.loadToken) {
        return;
      }
      const msg: string = (e as Error).message ?? '精选分类加载失败，请检查网络';
      if (msg.includes('没有可显示的帖子')) {
        this.loadState = GoodLoadState.Empty;
        this.hasMore = false;
      } else {
        this.loadState = GoodLoadState.Error;
        this.errorMsg = msg;
      }
    }
  }

  /** 从服务缓存补分类清单（is_good 请求自然落地）；无分类 → 仅「全部」，不报错 */
  private refreshCategories(): void {
    const raw = TiebaService.getInstance().getCachedGoodClassify(this.kw);
    if (raw.length === 0) {
      return; // 无数据保持现状（至少有「全部」）
    }
    const next: CategoryItem[] = [{ cid: 0, name: '全部' }];
    for (const c of raw) {
      const cid: number = c.classId ?? 0;
      const name: string = (c.className ?? '').trim();
      if (cid <= 0 || name.length === 0) {
        continue; // 服务端的「全部」项用自己的
      }
      if (!next.some((x: CategoryItem) => x.cid === cid)) {
        next.push({ cid: cid, name: name });
      }
    }
    if (next.length > 1) {
      this.categories = next;
    }
  }

  private applyList(list: ThreadItem[], pageN: number): void {
    this.page = pageN;
    this.hasMore = true;
    this.stalledPages = 0;
    this.activeDs().reload(list);
    this.slotCid[this.activeSlot] = this.selectedCid;
    this.loadState = GoodLoadState.Success;
    this.scrollListTop();
  }

  private threadsReset(): void {
    this.activeDs().reload([]);
  }

  private scrollListTop(): void {
    try {
      this.activeScroller().scrollTo({ xOffset: 0, yOffset: 0 });
    } catch (e) {
    }
  }

  // ===== 会话快照（LRU，cap 8）=====

  private saveSession(cid: number, s: CategorySession): void {
    this.sessions.delete(cid); // delete+set 移到队尾 = touch
    this.sessions.set(cid, s);
    while (this.sessions.size > GOOD_SNAPSHOT_CAP) {
      // Map 插入序 = LRU 序：forEach 最先访问即最久未使用
      let oldest: number = -1;
      this.sessions.forEach((_s: CategorySession, k: number): void => {
        if (oldest === -1) {
          oldest = k;
        }
      });
      if (oldest === -1) {
        break;
      }
      this.sessions.delete(oldest);
    }
  }

  private takeSession(cid: number): CategorySession | undefined {
    const s = this.sessions.get(cid);
    if (s !== undefined) {
      this.sessions.delete(cid);
      this.sessions.set(cid, s); // touch 到队尾
    }
    return s;
  }

  /** 把当前活跃槽的列表落为指定分类的会话快照（切换起滑前保存旧内容） */
  private snapshotCurrentToSession(cid: number): void {
    if (cid < 0) {
      return;
    }
    const cur: ThreadItem[] = this.activeDs().data.slice();
    if (cur.length > 0 && this.loadState === GoodLoadState.Success) {
      this.saveSession(cid, { threads: cur, page: this.page, hasMore: this.hasMore, ts: Date.now() });
    }
  }

  // ===== 分类切换（双槽角色轮换 + 两页对向平移）=====

  /**
   * 切换分类入口：同 cid = 回顶。
   * 三条路径，全部**不重建交互中的活跃槽**：
   *   ① 非活跃槽已 holding 目标分类（切回看过的）→ 槽内容现成，直接对向平移（零重建零闪）；
   *   ② 会话快照命中 → 数据写入非活跃槽（隐藏离屏构建）→ 平移；
   *   ③ 未命中 → 旧内容原地不动 + 轻量提示，数据到手写入非活跃槽 → 平移。
   */
  private selectCategory(item: CategoryItem): void {
    if (item.cid === this.selectedCid) {
      this.scrollListTop();
      return;
    }
    const dir: number = this.categoryIndex(item.cid) >= this.categoryIndex(this.selectedCid) ? 1 : -1;
    this.clearSwitchSettle();
    const inSlot: number = 1 - this.activeSlot;
    const session = this.takeSession(item.cid);
    this.selectedCid = item.cid; // 胶囊即时反馈
    if (this.slotCid[inSlot] === item.cid) {
      // ① 槽内现成：组件与图片全部就位，零重建直接对向平移
      this.snapshotCurrentToSession(this.displayedCid);
      this.enterDir = dir;
      const pageN: number = session ? session.page : 1;
      const more: boolean = session ? session.hasMore : true;
      this.applySwitchDisplay(item.cid, this.slotDs(inSlot).data.slice(), pageN, more);
      if (session && Date.now() - session.ts > GOOD_SESSION_TTL) {
        this.refreshCurrentSilently();
      }
    } else if (session && session.threads.length > 0) {
      // ② 会话快照：数据写入非活跃槽（隐藏离屏构建），图片在该槽解析完成后滑入
      this.snapshotCurrentToSession(this.displayedCid);
      this.slotDs(inSlot).reload(session.threads);
      this.slotCid[inSlot] = item.cid;
      this.enterDir = dir;
      this.applySwitchDisplay(item.cid, session.threads, session.page, session.hasMore);
      if (Date.now() - session.ts > GOOD_SESSION_TTL) {
        this.refreshCurrentSilently();
      }
    } else {
      // ③ 未命中：旧内容原地不动 + 轻量提示，数据到手写入非活跃槽 → 平移
      this.pendingSwitchDir = dir;
      this.pendingInSlot = inSlot;
      this.switchFromCid = this.displayedCid;
      this.switching = true;
      this.fetchForSwitch(item.cid);
    }
  }

  private categoryIndex(cid: number): number {
    const idx = this.categories.findIndex((c: CategoryItem) => c.cid === cid);
    return idx >= 0 ? idx : 0;
  }

  /** 未命中快照的切换取数：仅-proto（杜绝兜底错拿「全部」）；数据到手写入非活跃槽 → 平移 */
  private async fetchForSwitch(cid: number): Promise<void> {
    const myToken: number = ++this.loadToken;
    try {
      const result = await TiebaService.getInstance().fetchGoodCategoryThreads(this.kw, 1, cid);
      if (myToken !== this.loadToken || cid !== this.selectedCid) {
        return; // 竞态：期间用户已切走
      }
      this.switching = false;
      this.refreshCategories();
      if (result.list.length === 0) {
        this.threadsReset();
        this.loadState = GoodLoadState.Empty;
        this.hasMore = false;
        this.page = 1;
        this.stalledPages = 0;
        this.displayedCid = cid;
        this.slotCid[this.activeSlot] = cid;
        return;
      }
      const inSlot: number = this.pendingInSlot !== -1 ? this.pendingInSlot : 1 - this.activeSlot;
      this.snapshotCurrentToSession(this.switchFromCid);
      this.switchFromCid = -1;
      this.slotDs(inSlot).reload(result.list);
      this.slotCid[inSlot] = cid;
      this.enterDir = this.pendingSwitchDir !== 0 ? this.pendingSwitchDir : 1;
      this.pendingSwitchDir = 0;
      this.applySwitchDisplay(cid, result.list, 1, result.hasMore);
    } catch (e) {
      if (myToken !== this.loadToken || cid !== this.selectedCid) {
        return;
      }
      this.switching = false;
      const msg: string = (e as Error).message ?? '该分类加载失败，请稍后重试';
      if (msg.includes('没有可显示的帖子')) {
        this.threadsReset();
        this.loadState = GoodLoadState.Empty;
        this.hasMore = false;
        this.page = 1;
        this.displayedCid = cid;
        this.slotCid[this.activeSlot] = cid;
      } else {
        // 失败保留旧内容（未被抽走），轻提示
        this.getUIContext().getPromptAction().showToast({ message: msg });
      }
    }
  }

  /**
   * 切换上屏（唯一入口）：新数据已写入非活跃槽 → 双槽对向平移 →
   * 落定时**只换角色（activeSlot 互换），零数据搬运零重建** —— 旧槽保留内容与滚动位置待复用，
   * 图片闪帧（全量重建 → 图片重新挂载解码）在架构上不存在。
   */
  private applySwitchDisplay(cid: number, list: ThreadItem[], pageN: number, more: boolean): void {
    if (cid !== this.selectedCid) {
      return; // 竞态：快速连切，丢弃迟到数据
    }
    this.pendingCid = cid;
    this.pendingList = list;
    this.pendingPageN = pageN;
    this.pendingMore = more;
    // ★ 槽位角色必须在此指定：漏掉会导致落定时 activeSlot 被赋成 -1 → 双槽全部隐藏 → 内容全空
    this.inSlot = 1 - this.activeSlot;
    this.outSlot = this.activeSlot;
    const dir: number = this.enterDir !== 0 ? this.enterDir : 1;
    this.enterDir = 0;
    // 起点态（无动画赋值）：进场槽在对侧整屏外、主槽（旧内容）留原位待退场
    this.inOffset = dir * 100;
    this.outOffset = 0;
    this.animUntil = Date.now() + GOOD_ANIM_SETTLE;
    this.getUIContext().animateTo({ duration: GOOD_ANIM_DURATION, curve: curves.springMotion(0.72, 0.86) }, () => {
      this.inOffset = 0;
      this.outOffset = -dir * 100;
    });
    this.scheduleSwitchSettle();
  }

  private clearSwitchSettle(): void {
    if (this.settleTimer !== -1) {
      clearTimeout(this.settleTimer);
      this.settleTimer = -1;
    }
    this.inOffset = 0;
    this.outOffset = 0;
    this.inSlot = -1;
    this.outSlot = -1;
    this.enterDir = 0;
    this.pendingCid = -1;
    this.pendingList = [];
  }

  private scheduleSwitchSettle(): void {
    if (this.settleTimer !== -1) {
      clearTimeout(this.settleTimer);
    }
    this.settleTimer = setTimeout(() => {
      this.settleTimer = -1;
      if (this.pendingCid >= 0) {
        // 角色互换：进场槽升为活跃槽（内容/滚动位置/组件原封不动），退场槽转入待用
        this.activeSlot = this.inSlot;
        this.displayedCid = this.pendingCid;
        this.page = this.pendingPageN;
        this.hasMore = this.pendingMore;
        this.stalledPages = 0;
        this.loadState = GoodLoadState.Success;
        this.saveSession(this.pendingCid, {
          threads: this.pendingList, page: this.pendingPageN, hasMore: this.pendingMore, ts: Date.now()
        });
      }
      this.pendingCid = -1;
      this.pendingList = [];
      this.inSlot = -1;
      this.outSlot = -1;
      this.inOffset = 0;
      this.outOffset = 0;
    }, GOOD_ANIM_SETTLE);
  }

  // ===== 静默刷新 / 加载更多 =====

  /** 静默刷新当前分类（缓存过期命中 / 全部首屏后）：失败保留旧内容，动画中不整块替换 */
  private refreshCurrentSilently(): void {
    const cid: number = this.selectedCid;
    const myToken: number = ++this.loadToken;
    this.fetchFirstPage(cid).then((result: PagedResult<ThreadItem>): void => {
      if (myToken !== this.loadToken || cid !== this.selectedCid) {
        return;
      }
      this.refreshCategories();
      if (result.list.length === 0) {
        return;
      }
      this.saveSession(cid, { threads: result.list, page: 1, hasMore: result.hasMore, ts: Date.now() });
      this.hasMore = result.hasMore;
      this.page = 1;
      this.stalledPages = 0;
      if (Date.now() < this.animUntil || this.loadState !== GoodLoadState.Success) {
        return;
      }
      // 内容未变（前 3 条 tid 一致）→ 只更新缓存与分页，不重建列表（避免落定后闪帧）
      const cur: ThreadItem[] = this.activeDs().data;
      const sameHead: boolean = cur.length > 0 && result.list.length > 0
        && cur[0].tid === result.list[0].tid
        && (cur.length < 2 || result.list.length < 2 || cur[1].tid === result.list[1].tid)
        && (cur.length < 3 || result.list.length < 3 || cur[2].tid === result.list[2].tid);
      if (!sameHead) {
        this.activeDs().reload(result.list);
      }
    }).catch((_e: Error): void => {
      // 静默刷新失败保留旧内容
    });
  }

  private async loadMore(): Promise<void> {
    if (this.loadingMore || !this.hasMore || this.loadState !== GoodLoadState.Success) {
      return;
    }
    if (this.inSlot !== -1) {
      return; // 切换过场中：等角色互换完成后再翻页
    }
    this.loadingMore = true;
    const myToken: number = this.loadToken;
    const cid: number = this.selectedCid;
    try {
      const result = await this.fetchPage(cid, this.page + 1);
      if (myToken !== this.loadToken || cid !== this.selectedCid) {
        return; // 期间切了分类 / 刷新
      }
      if (result.list.length === 0) {
        this.stalledPages++;
        if (this.stalledPages >= 3) {
          this.hasMore = false; // 空轮保护：连续 3 空轮判到底
        }
        return;
      }
      this.stalledPages = 0;
      this.page = this.page + 1;
      this.hasMore = result.hasMore;
      const merged: ThreadItem[] = this.activeDs().data.concat(result.list);
      this.activeDs().appendAll(result.list);
      this.saveSession(cid, { threads: merged, page: this.page, hasMore: this.hasMore, ts: Date.now() });
    } catch (e) {
      console.info(`[GOOD] loadMore fail cid=${cid}: ${(e as Error).message}`);
      // 失败保留 hasMore，下次触底重试
    } finally {
      this.loadingMore = false;
    }
  }

  /**
   * 下拉刷新。★ 勿加「if (this.refreshing) return」守卫：$$ 双向绑定下 onRefreshing 触发时
   * refreshing 已被框架置 true，守卫会永不执行刷新也永不复位（= 二轮「一直转圈不刷新」真因）。
   */
  private async handleRefresh(): Promise<void> {
    if (this.inSlot !== -1) {
      this.refreshing = false;
      return; // 切换过场中不接下拉刷新
    }
    const myToken: number = ++this.loadToken;
    const cid: number = this.selectedCid;
    try {
      const result = await this.fetchPage(cid, 1);
      if (myToken === this.loadToken && cid === this.selectedCid && result.list.length > 0) {
        this.activeDs().reload(result.list);
        this.slotCid[this.activeSlot] = cid;
        this.page = 1;
        this.hasMore = result.hasMore;
        this.stalledPages = 0;
        this.loadState = GoodLoadState.Success;
        this.saveSession(cid, { threads: result.list, page: 1, hasMore: result.hasMore, ts: Date.now() });
        this.refreshCategories();
      }
    } catch (_) {
      // 下拉刷新失败保留旧内容
    } finally {
      this.refreshing = false;
    }
  }

  // ===== 交互 =====

  private openThread(tid: string): void {
    if (tid.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '帖子信息暂不可用' });
      return;
    }
    // 点击即预取：利用跳转动画窗口后台取详情，详情页打开即命中缓存秒开
    TiebaService.getInstance().prefetchThreadDetail(tid, this.forumId);
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/ThreadDetail',
      params: { tid: tid, forum: this.kw, fid: this.forumId }
    }).catch(() => {
      this.getUIContext().getPromptAction().showToast({ message: '帖子打开失败，请稍后重试' });
    });
  }

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

  private async handleLike(tid: string, postId: string, liked: boolean): Promise<void> {
    try {
      const result = await TiebaService.getInstance().togglePostAgree(tid, postId, liked);
      if (result) {
        const next: ThreadItem[] = this.activeDs().data.map((t: ThreadItem): ThreadItem => this.withLikeState(t, tid, liked));
        this.activeDs().reload(next);
        this.slotCid[this.activeSlot] = this.displayedCid;
        const s = this.sessions.get(this.displayedCid);
        if (s !== undefined) {
          this.saveSession(this.displayedCid, {
            threads: s.threads.map((t: ThreadItem): ThreadItem => this.withLikeState(t, tid, liked)),
            page: s.page, hasMore: s.hasMore, ts: s.ts,
          });
        }
      }
    } catch (e) {
      const msg = (e as Error).message ?? '操作失败，请稍后重试';
      this.getUIContext().getPromptAction().showToast({ message: msg });
    }
  }

  private withLikeState(t: ThreadItem, tid: string, liked: boolean): ThreadItem {
    if (t.tid !== tid) {
      return t;
    }
    return {
      tid: t.tid, postId: t.postId, forumId: t.forumId,
      title: t.title, forumName: t.forumName, forumAvatar: t.forumAvatar,
      author: t.author, authorId: t.authorId, authorAvatar: t.authorAvatar,
      authorNameShowMissing: t.authorNameShowMissing,
      replyNum: t.replyNum,
      likeCount: (t.likeCount ?? 0) + (liked ? 1 : -1),
      isLiked: liked,
      abstract: t.abstract, firstImage: t.firstImage,
      images: t.images, createTime: t.createTime,
      isTop: t.isTop, isGood: t.isGood,
      isFeatured: t.isFeatured,
    } as ThreadItem;
  }

  private shareThread(data: ThreadSharePayload): void {
    ShareUtil.shareThread(this.getUIContext(), this.getUIAbilityContext(), data);
  }

  // ===== 形态 / 列数（ThreadList.threadColumns 同口径单点同源）=====

  private onColumnModeTick(): void {
    this.columnMode = readColumnMode();
    this.syncCardColumns();
    this.scrollListTop();
  }

  private onContentAreaChange(_old: Area, n: Area): void {
    // ★ Area.width/height 已是 **vp**，禁止再 px2vp（ThreadList.onListFormAreaChange 同口径：
    //   直接取用）。曾误做 px2vp → 平板竖屏 800vp 变 400vp → 命中「窗口宽<600 回落手机单列」闸门
    //   → 竖屏错误显示 1 列（横屏 1280→640 恰好越闸门所以看着正常）。2026-09-22 定位。
    const w: number = Number(n.width);
    const h: number = Number(n.height);
    if (w <= 0 || h <= 0) {
      return;
    }
    this.pageWidth = w;
    this.pageHeight = h;
    this.currentWidth = this.pageWidth;
    this.isLandscape = this.pageWidth > this.pageHeight;
    this.syncCardColumns();
  }

  /** 列数标记下发（无条件写、同值短路）：cardColumns 是 AppStorage 全局单值，跨页残留防护 §6.1 D1/D6 */
  private syncCardColumns(): void {
    const next: number = this.goodColumns();
    if (AppStorage.get<number>(CARD_COLUMNS_KEY) !== next) {
      AppStorage.setOrCreate(CARD_COLUMNS_KEY, next);
    }
    // 多列档分桶 / 单列档镜像必须随列数同步（横竖屏切换 / 列数调整档变化）
    this.syncSlotColumns(0);
    this.syncSlotColumns(1);
  }

  /** 某槽列分桶镜像读取（渲染层统一走此入口，不直读 ds.data） */
  private slotCols(slot: number): ThreadItem[][] {
    return slot === 0 ? this.slotCols0 : this.slotCols1;
  }

  /** 列索引表（外层 ForEach 只遍历列索引，key 稳定 → 列容器复用；MessagesTab/PersonalContent 同款） */
  private goodColIndexes(): number[] {
    const n: number = Math.max(1, this.goodColumns());
    const arr: number[] = [];
    for (let i = 0; i < n; i++) {
      arr.push(i);
    }
    return arr;
  }

  /**
   * 重算某槽列分桶镜像（方案 B「带滞回的最短列」，与 §4.9 / §4.10 / §4.11 P-B 同款）：
   * 默认按 `i % 列数` 轮转（保序观感），仅当轮转目标列与最短列的估算高差
   * > GOOD_COL_BALANCE_THRESHOLD 时改投最短列补位。前缀稳定贪心：数据追加只影响尾部，
   * 旧卡落列不变（不跳位）。**主动写入 @State**（MessagesTab §4.4 教训：直读 ds.data 不随更新）。
   */
  private syncSlotColumns(slot: number): void {
    const items: ThreadItem[] = this.slotDs(slot).data;
    const cols: number = Math.max(1, this.goodColumns());
    const buckets: ThreadItem[][] = [];
    for (let i = 0; i < cols; i++) {
      buckets.push([]);
    }
    // 列实宽（估算用）：内容区宽 - 左右边距 lg×2 - 列间 md×(cols-1)；取不到正数按 360 兜底
    let colW: number = (this.pageWidth - Spacing.lg * 2 - Spacing.md * (cols - 1)) / cols;
    if (!(colW > 0)) {
      colW = 360;
    }
    const heights: number[] = [];
    for (let i = 0; i < cols; i++) {
      heights.push(0);
    }
    for (let i = 0; i < items.length; i++) {
      let target: number = i % cols;
      let shortest: number = 0;
      for (let c = 1; c < cols; c++) {
        if (heights[c] < heights[shortest]) {
          shortest = c;
        }
      }
      if (heights[target] - heights[shortest] > GOOD_COL_BALANCE_THRESHOLD) {
        target = shortest;
      }
      buckets[target].push(items[i]);
      heights[target] += this.estimateGoodCardHeight(items[i], colW);
    }
    if (slot === 0) {
      this.slotCols0 = buckets;
    } else {
      this.slotCols1 = buckets;
    }
  }

  /**
   * ThreadCard 估算高（vp，仅供列均衡分桶，不求像素准只求相对准，与渲染同式）：
   * 常数底数（作者行 56 + 吧行 30 + 操作栏 44 + 卡内纵向间距）≈ 118；
   * 标题 ≤2 行（fs17→行高 24）、摘要多列档 ≤2 行（fs14→行高 20）；
   * 图区与 ImageGallery 渲染同式：单图 aspectRatio(1.6) 封顶 220；宫格 2/4 张两列格高 ≤140、
   * 其余三列格高 ≤100（格宽按 aspectRatio(1) 与封顶取小）。
   */
  private estimateGoodCardHeight(item: ThreadItem, colWidth: number): number {
    let h: number = 118;
    const title: string = item.title ?? '';
    if (title.length > 0) {
      const cpl: number = Math.max(8, Math.floor(colWidth / 17));
      h += Math.min(Math.ceil(title.length / cpl), 2) * 24 + 8;
    }
    const abs: string = item.abstract ?? '';
    if (abs.length > 0) {
      const cpl2: number = Math.max(10, Math.floor(colWidth / 14));
      h += Math.min(Math.ceil(abs.length / cpl2), 2) * 20 + 6;
    }
    const imgs: string[] = item.images ?? [];
    const n: number = Math.min(imgs.length, 9);
    if (n === 1) {
      h += Math.min(colWidth / 1.6, 220) + 10;
    } else if (n >= 2) {
      const perRow: number = (n === 2 || n === 4) ? 2 : 3;
      const cap: number = (n === 2 || n === 4) ? 140 : 100;
      const cellW: number = (colWidth - 8 * (perRow - 1)) / perRow;
      const cellH: number = Math.min(cellW, cap);
      const rows: number = Math.ceil(n / perRow);
      h += rows * cellH + 8 * (rows - 1) + 10;
    }
    return h;
  }

  /** 列数（派生缓存）：键 = 宽|高|档位，折叠展开必变键不漏翻档（ThreadList.threadColumns 同款） */
  private goodColumns(): number {
    const key: string = `${this.pageWidth}|${this.pageHeight}|${this.columnMode}`;
    if (key === this.colCacheKey) {
      return this.colCacheValue;
    }
    const cols: number = this.computeGoodColumns();
    this.colCacheKey = key;
    this.colCacheValue = cols;
    return cols;
  }

  private computeGoodColumns(): number {
    // 窗口闸门最前：小窗/分屏窄窗回落手机单列；阔直屏全屏白名单放行
    if (this.pageWidth > 0 && this.pageWidth < Breakpoint.sm && !isWideBarFullscreen(this.pageWidth)) {
      return 1;
    }
    // 「列数调整」用户显式档：仅大屏形态生效
    if (isLargeScreenForm(this.isWideFormDevice)) {
      const ov: number = overrideColumns(this.columnMode, this.isLandscape);
      if (ov > 0) {
        return ov;
      }
    }
    if (isLargeFoldDevice()) {
      return this.isLandscape ? 3 : 2;
    }
    if (isWideBarDevice()) {
      return this.isLandscape ? 3 : 1;
    }
    if (!this.isWideFormDevice) {
      return 1;
    }
    if (this.pageWidth < Breakpoint.sm) {
      return 1;
    }
    return this.isLandscape ? 3 : 2;
  }

  // ===== UI =====

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 内容层（双常驻槽位 + 状态覆盖层 + 左右滑手势）
      this.ContentLayer()
      // 满宽渐显带（背景色→透明），滚动内容从其下穿过自然淡出
      this.TopGradientScrim()
      // 分类胶囊行：官方材质（空 tabBar 壳槽位，文档 §6.13/6.14 同机制）/ 真模糊兜底
      if (this.materialSupported) {
        this.CategoryPillBarSlot()
      } else {
        this.CategoryPillBarLegacy()
      }
      // 未命中快照的取数提示：旧内容保持在场，仅在胶囊行下方居中挂一枚轻量玻璃小胶囊
      if (this.switching) {
        Column() {
          Row({ space: 8 }) {
            LoadingProgress()
              .width(16)
              .height(16)
              .color(Theme.brand())
            Text('加载中...')
              .fontSize(fs(12, this.fontScale))
              .fontColor(Theme.textSecondary(this.isDark))
          }
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .backgroundColor(Theme.manualGlass(this.isDark))
          .border({ width: 0.5, color: Theme.manualGlassBorder() })
          .backgroundBlurStyle(BlurStyle.Thin, { scale: 0.85 })
          .borderRadius(Radius.full)
          .shadow(Theme.segGlassShadow(this.isDark, false))
        }
        .width('100%')
        .margin({ top: GOOD_TITLE_BAR_HEIGHT + 4 })
        .hitTestBehavior(HitTestMode.None)
        .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.EaseOut }))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg(this.isDark))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  /** 满宽渐显带：背景实色 → 透明（用户拍板，替代带阴影的栏） */
  @Builder
  TopGradientScrim() {
    Column()
      .width('100%')
      .height(GOOD_SCRIM_HEIGHT)
      .linearGradient({
        angle: 180,
        colors: [[this.scrimSolidColor(), 0.0], [this.scrimTransparentColor(), 1.0]]
      })
      .hitTestBehavior(HitTestMode.None)
  }

  private scrimSolidColor(): string {
    return this.isDark ? '#101114' : '#F2F4F7';
  }

  private scrimTransparentColor(): string {
    return this.isDark ? '#00101114' : '#00F2F4F7';
  }

  /** 分类胶囊行·官方沉浸光感版（空 tabBar 壳，文档 §6.13/6.14 同机制） */
  @Builder
  CategoryPillBarSlot() {
    Column() {
      Tabs({ barPosition: BarPosition.End }) {
        TabContent()
          .tabBar(this.PillRowInSlot())
      }
      .width('100%')
      .height(42)
      .vertical(false)
      .scrollable(false)
      .barHeight(42)
      .barBackgroundColor(Color.Transparent)
      .barBackgroundBlurStyle(BlurStyle.NONE)
      .backgroundColor(Color.Transparent)
      .clip(false)
      .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .padding({ top: 44, bottom: 2 })
  }

  /** 槽内胶囊行：横向滑动，逐枚挂官方材质 segFlat(选中态)（无阴影档，空壳下方无官方背板托底） */
  @Builder
  PillRowInSlot() {
    Scroll() {
      Row({ space: 10 }) {
        ForEach(this.categories, (item: CategoryItem) => {
          Text(item.name)
            .fontSize(fs(13, this.fontScale))
            .fontWeight(this.selectedCid === item.cid ? FontWeight.Bold : FontWeight.Medium)
            .fontColor(this.selectedCid === item.cid
              ? $r('sys.color.font_emphasize')
              : $r('sys.color.font_primary'))
            .systemMaterial(ImmMaterial.segFlat(this.selectedCid === item.cid))
            .borderRadius(Radius.full)
            .padding({ left: 16, right: 16, top: 7, bottom: 7 })
            .maxLines(1)
            .onClick(() => { this.selectCategory(item); })
        }, (item: CategoryItem) => `${item.cid}_${item.name}`)
      }
      .constraintSize({ minWidth: '100%' })
      .justifyContent(FlexAlign.Start)
      .padding({ left: Spacing.lg, right: Spacing.lg })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .width('100%')
    .height(42)
    .align(Alignment.Start)
  }

  /** 分类胶囊行·兜底（低版本 / 无材质）：真模糊玻璃，几何与槽位版一致 */
  @Builder
  CategoryPillBarLegacy() {
    Column() {
      Scroll() {
        Row({ space: 10 }) {
          ForEach(this.categories, (item: CategoryItem) => {
            Text(item.name)
              .fontSize(fs(13, this.fontScale))
              .fontWeight(this.selectedCid === item.cid ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.selectedCid === item.cid
                ? $r('sys.color.font_emphasize')
                : $r('sys.color.font_primary'))
              .backgroundColor(Theme.segGlass(this.isDark, this.selectedCid === item.cid))
              .border({ width: 0.5, color: Theme.manualGlassBorder() })
              .backgroundBlurStyle(this.selectedCid === item.cid ? BlurStyle.Regular : BlurStyle.Thin,
                { scale: this.selectedCid === item.cid ? 0.8 : 0.85 })
              .shadow(Theme.segGlassShadow(this.isDark, this.selectedCid === item.cid))
              .borderRadius(Radius.full)
              .padding({ left: 16, right: 16, top: 7, bottom: 7 })
              .maxLines(1)
              .onClick(() => { this.selectCategory(item); })
          }, (item: CategoryItem) => `${item.cid}_${item.name}`)
        }
        .constraintSize({ minWidth: '100%' })
        .justifyContent(FlexAlign.Start)
        .padding({ left: Spacing.lg, right: Spacing.lg })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
      .height(42)
    }
    .width('100%')
    .padding({ top: 44, bottom: 2 })
  }

  @Builder
  ContentLayer() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 双常驻槽位（角色轮换）：组件永久存活，切回看过的分类零重建零闪
      this.SlotLayer(0)
      this.SlotLayer(1)
      // 状态覆盖层（加载/空/错误）：不透明，盖住槽位旧内容
      if (this.loadState !== GoodLoadState.Success) {
        Column() {
          if (this.loadState === GoodLoadState.Loading) {
            LoadingView({ message: '加载精选中...' })
          } else if (this.loadState === GoodLoadState.Empty) {
            EmptyView({ message: '该分类下暂时没有帖子' })
          } else {
            ErrorView({ message: this.errorMsg, onRetry: () => { this.retryCurrent(); } })
          }
        }
        .width('100%')
        .height('100%')
        .backgroundColor(Theme.bg(this.isDark))
        .padding({ top: GOOD_TITLE_BAR_HEIGHT + 80, bottom: 120 })
      }
    }
    .width('100%')
    .height('100%')
    // 左右滑切换分类（HomeTab 推荐流同款）：必须挂在外层普通容器上——
    // 挂 Refresh 上 parallelGesture 不触发（十二轮真机结论）；与内部滚动并行识别
    .parallelGesture(
      PanGesture({ fingers: 1, direction: PanDirection.Horizontal, distance: 30 })
        .onActionStart(() => {
          // 起手即锁卡点按：横向滑动手势期间抬指仍可能给卡片派发 click
          this.lockSwipe();
        })
        .onActionEnd((event: GestureEvent) => {
          this.onCategorySwipeEnd(event);
          this.unlockSwipeDelayed();
        })
        .onActionCancel(() => {
          this.unlockSwipeDelayed();
        })
    )
    .onAreaChange((_old: Area, n: Area) => this.onContentAreaChange(_old, n))
  }

  /**
   * 单个常驻槽位：Scroll（多列=列分桶 Row / 单列=Column）+ 下拉刷新 + 平移位移。
   * 非活跃槽**不用 visibility 隐藏**（隐藏态测量不可靠，曾致卡片错乱），改 translate 停靠屏外。
   * 双槽对向平移由**外层普通容器**的 translate 承担（挂 Refresh 上不生效）。
   */
  @Builder
  SlotLayer(slot: number) {
    // ★ 外层普通容器承载 visibility + translate：`Refresh` 上挂 translate 不生效（历史实测结论，
    //   位移一律上移外层普通容器）。曾把 translate 挂在 Refresh 上 → 切分类时退场槽位移没生效，
    //   两槽**原位叠画**（新列表在下、旧列表在上），旧列表卡片未加载的白色图区透出新列表的
    //   图片/操作栏 → 真机表现为「图片压到别的卡上 / 图片跑到别的列 / 大片空白」（2026-09-22 定位）。
    Column() {
      // 下拉刷新（2026-09-22，docs/下拉刷新.md）：与首页推荐页同款——Refresh 容器 margin 下移到胶囊行之下
      // （系统默认指示器随之出现在胶囊行下方），定高扣除下移量防底部溢出；内容里的 88vp 让位由该 margin 接管
      Refresh({ refreshing: $$this.refreshing, offset: 48, friction: 62 }) {
        if (this.goodColumns() > 1) {
          // ===== 多列档：`Scroll` + 列分桶 Row（§4.11 P-B / §4.4 同款全量渲染，2026-09-22 定稿）=====
          // 原 WaterFlow + WaterFlowSections 方案在本页「双常驻槽位 + 沉浸布局」下虚拟容器测量不可靠
          //（真机：卡片拉超长 / 图区大块空白 / 内容跨卡错位，21 轮未根治），与消息页 / 个人内容页同法收敛：
          // 全量渲染 + 最短列分桶——外层 ForEach 只遍历列索引（key 稳定 → 列容器复用），
          // 内层数据源直读 @State 分桶镜像 `slotCols(slot)[colIdx]`（不用外层传入，复用断链不更新）。
          Scroll(this.slotScroller(slot)) {
            Column() {
              // 多列档顶部留白在顶让位之上再加 GOOD_TOP_EXTRA：宽屏瀑布流首行卡离胶囊行太贴（用户反馈）
              Column().width('100%').height(GOOD_TOP_EXTRA)
              Row({ space: Spacing.md }) {
                ForEach(this.goodColIndexes(), (colIdx: number) => {
                  Column({ space: Spacing.md }) {
                    ForEach(this.slotCols(slot)[colIdx], (item: ThreadItem) => {
                      Column() {
                        this.ThreadCardItem(item)
                      }
                    }, (item: ThreadItem) => `s${slot}_${item.tid}_${item.author}_${item.isLiked ? 1 : 0}_${item.likeCount ?? 0}`)
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                }, (colIdx: number) => `gcol_${slot}_${colIdx}`)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
              // 左右边距单一来源 Spacing.lg（§6.1 第 2 步）；底部 md 与列内间距同值
              .padding({ left: Spacing.lg, right: Spacing.lg, bottom: Spacing.md })
            }
            .width('100%')
          }
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .width('100%')
          .height('100%')
          .clip(false)
          .onReachEnd(() => { this.loadMore(); })
        } else {
          // ===== 单列档：`Scroll` + `Column`（全量渲染，吧主页 / 首页单列档同款容器）=====
          // 与多列档是**两个容器**：手机单列走这里，绝不套多列档的 Row 分桶（容器分叉，§4.8 同构）。
          // 数据源读分桶镜像 [0]（单桶 = 全量列表，由 syncSlotColumns 统一驱动更新）。
          Scroll(this.slotScroller(slot)) {
            Column() {
              ForEach(this.slotCols(slot)[0], (item: ThreadItem) => {
                Column() {
                  this.ThreadCardItem(item)
                }
                .width('100%')
                .margin({ bottom: Spacing.md })
              }, (item: ThreadItem) => `s${slot}_${item.tid}_${item.author}_${item.isLiked ? 1 : 0}_${item.likeCount ?? 0}`)
            }
            .width('100%')
            .padding({ left: Spacing.lg, right: Spacing.lg })
          }
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .width('100%')
          .height('100%')
          .clip(false)
          .onReachEnd(() => { this.loadMore(); })
        }
      }
      .onRefreshing(() => { this.handleRefresh(); })
      .width('100%')
      .height('calc(100% - 88vp)')
      .margin({ top: GOOD_TITLE_BAR_HEIGHT })
      .clip(false)
    }
    .width('100%')
    .height('100%')
    .clip(false)
    // ★ 槽位**不使用 visibility 隐藏**：`None` 不参与布局、`Hidden` 的离屏测量也不可靠 ——
    //   本页是虚拟容器（WaterFlow + Grid + aspectRatio），隐藏态测出来的 item 尺寸会退化并被缓存，
    //   滑入后沿用坏尺寸 → 真机表现为「卡片互相压住 / 图区大块空白 / 内容跑到别的列」（2026-09-22 定位）。
    //   改为「常驻布局 + 停靠屏外」：translate 只做几何变换、**不参与测量**，所以非活跃槽的测量约束
    //   与可见态完全一致（临时渲染出来的尺寸即真实尺寸），且停靠屏外天然不可见、不接收触摸。
    .translate({ x: `${this.slotOffset(slot)}%` })
  }

  /**
   * 槽位位移：活跃槽 0；动画中的进出槽走 in/outOffset；其余**停靠屏外 -100%**。
   * 停靠态不用 visibility 隐藏（见 SlotLayer 注释）：隐藏态测量不可靠是本页错乱的根因，
   * 而 translate 不参与测量 —— 停靠槽与活跃槽的测量约束完全一致。
   * 停靠点固定在左侧屏外，与过场方向无关，落定时直接跳过去（此时该槽已在屏外，无可见跳变）。
   */
  private slotOffset(slot: number): number {
    if (slot === this.inSlot) {
      return this.inOffset;
    }
    if (slot === this.outSlot) {
      return this.outOffset;
    }
    if (slot === this.activeSlot) {
      return 0;
    }
    return -100;
  }


  /** 单张帖子卡（两槽共用同一份渲染） */
  @Builder
  ThreadCardItem(item: ThreadItem) {
    ThreadCard({
      item: {
        tid: item.tid, postId: item.postId ?? '',
        forumId: item.forumId ?? '',
        title: item.title, forumName: item.forumName,
        forumAvatar: item.forumAvatar ?? '',
        author: item.author,
        authorAvatar: item.authorAvatar ?? '',
        authorId: item.authorId ?? '',
        replyNum: item.replyNum, likeCount: item.likeCount ?? 0,
        isLiked: item.isLiked ?? false,
        abstract: item.abstract,
        firstImage: item.firstImage ?? '', images: item.images ?? [],
        // ★ 刻意不传 imageThumbs：本页数据与吧主页同源（frs/page proto），吧主页的 ThreadCard
        //   调用点同样不传（宫格走 bigPic 原图 + ImageCache 带 UA/Cookie 解析，真机可正常出图）；
        //   传 srcPic 缩略图反而出现「图区大块空白 / 加载失败降级灰条」（2026-09-22 对照排查）。
        createTime: item.createTime, isTop: item.isTop, isGood: item.isGood,
      } as ThreadItemData,
      // 滑动锁：左右滑切换分类的起手段内吞掉卡片 click（真机会在滑动手势期间误开帖子）
      onTap: (tid: string) => {
        if (!this.swipeLock) {
          this.openThread(tid);
        }
      },
      onLike: (tid: string, postId: string, liked: boolean) => this.handleLike(tid, postId, liked),
      onShare: (d: ThreadSharePayload) => this.shareThread(d),
      onComment: (tid: string) => {
        if (!this.swipeLock) {
          this.openThread(tid);
        }
      },
      onAvatarTap: (id: string, name: string) => this.openUserProfile(id, name)
    })
  }

  /** 错误态重试：重拉当前分类第 1 页（与切换取数同通道，成功后照样两页平移上屏） */
  private retryCurrent(): void {
    const cid: number = this.selectedCid;
    this.clearSwitchSettle();
    this.threadsReset();
    this.loadState = GoodLoadState.Loading;
    this.switching = true;
    this.switchFromCid = this.displayedCid;
    this.pendingSwitchDir = 1;
    this.pendingInSlot = this.activeSlot;
    this.fetchForSwitch(cid);
  }

  private listScrollerForTest(): Scroller {
    return this.activeScroller();
  }

  /**
   * 左右滑切换分类（HomeTab 推荐流同款 PanGesture 并行识别）：左滑=下一个分类、右滑=上一个，
   * 走 selectCategory 统一链路（槽位现成零闪 / 会话秒开 / 轻量提示全部复用）；
   * 已到两端（最前/最后分类）时忽略不动。
   */
  private onCategorySwipeEnd(event: GestureEvent): void {
    const dx: number = event.offsetX;
    if (dx > -80 && dx < 80) {
      return; // 位移不足（HomeTab 同阈值）：竖滑误带横向分量不触发
    }
    const idx: number = this.categoryIndex(this.selectedCid);
    const next: number = dx < 0 ? idx + 1 : idx - 1;
    if (next < 0 || next >= this.categories.length) {
      return;
    }
    this.selectCategory(this.categories[next]);
  }

  // ===== 滑动锁 =====

  private lockSwipe(): void {
    this.swipeLock = true;
    if (this.swipeLockTimer !== -1) {
      clearTimeout(this.swipeLockTimer);
      this.swipeLockTimer = -1;
    }
  }

  private unlockSwipeDelayed(): void {
    if (this.swipeLockTimer !== -1) {
      clearTimeout(this.swipeLockTimer);
    }
    this.swipeLockTimer = setTimeout(() => {
      this.swipeLockTimer = -1;
      this.swipeLock = false;
    }, GOOD_SWIPE_UNLOCK_DELAY);
  }

  // ===== 形态杂项 =====

  /**
   * 页面转场（RouteType 拆分）：
   * - Push 进页（从吧主页）：自下而上滑入 280ms；
   * - Push 出页（进帖子详情）：本页静止（1ms 收场），被详情页覆盖；
   * - Pop 出页（返回吧主页）：向下收回 240ms；
   * - Pop 入页（从详情返回本页）：静止揭出（不重播上滑）。
   */
  pageTransition() {
    PageTransitionEnter({ type: RouteType.Push, duration: 280, curve: Curve.FastOutSlowIn })
      .slide(SlideEffect.Bottom);
    PageTransitionEnter({ type: RouteType.Pop, duration: 1 });
    PageTransitionExit({ type: RouteType.Pop, duration: 240, curve: Curve.FastOutSlowIn })
      .slide(SlideEffect.Bottom);
    PageTransitionExit({ type: RouteType.Push, duration: 1 });
  }
}
