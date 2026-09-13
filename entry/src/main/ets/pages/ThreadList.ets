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

import { common, Want } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { pasteboard, BusinessError } from '@kit.BasicServicesKit';
import { display, curves, componentSnapshot } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { TiebaService, ThreadDetailResult } from '../service/TiebaService';
import { ForumSignStore } from '../service/ForumSignStore';
import { ThreadItem, ForumHeaderInfo, ForumSearchData, ThreadDetail } from '../model/DataModel';
import { Theme, Spacing, Radius, isDarkMode, ImmBlur, ImmMaterial, MaterialManager, fs } from '../common/Theme';
import { CacheManager } from '../cache/CacheManager';
import { CACHE_KEY, CACHE_TTL } from '../common/Constants';
import { LoadingView, EmptyView, ErrorView, ThreadCard, ThreadItemData, ThreadSharePayload, PinnedThreadItem } from '../components/CommonComponents';
import { ThreadListSkeleton } from '../components/Skeleton';

enum LoadState {
  Loading, Success, Empty, Error,
}

/** 吧主页预加载阈值：距底部剩余距离小于该值时提前静默加载下一页（约 2 屏，覆盖快速甩滑的请求耗时） */
const THREAD_PREFETCH_DISTANCE: number = 1200;

/**
 * 本吧搜索扫描参数（BUG-03 后续优化）：
 * 无可用服务端吧内搜索接口，故为「本地扫描吧内分页 + 标题/摘要匹配」，结果量取决于扫了多少页。
 * SEARCH_DEBOUNCE_MS   输入防抖，避免逐字各触发一轮扫描；
 * SEARCH_CONCURRENCY   单轮并发页数（并行抓取替代逐页串行——"加载慢"的主因之一）；
 * SEARCH_BATCH_RESULTS 单批目标结果数（凑够约 8 屏再交给滚动，取代"每次触底才多一条"）；
 * SEARCH_BATCH_PAGES   单批最多扫描页数（继续下滑再补下一批，防超大吧单次等待过久）；
 * SEARCH_SCAN_SORT     扫描固定用「热门」序（与当前排序 Tab 无关）：否则在「精选」Tab 下
 *                      只能扫到精品帖，结果必然少得可怜。
 */
const SEARCH_DEBOUNCE_MS: number = 300;
const SEARCH_CONCURRENCY: number = 3;
const SEARCH_BATCH_RESULTS: number = 40;
const SEARCH_BATCH_PAGES: number = 12;
const SEARCH_SCAN_SORT: number = 0;
/** 服务端吧内搜索每页条数（一次请求即整屏，替代逐页扫描） */
const SEARCH_SERVER_PAGE_SIZE: number = 30;
/** 服务端结果自动续载上限（条）：防 has_more 异常时后台无限翻页，超出后仅由用户下滑驱动 */
const SEARCH_SERVER_AUTO_MAX: number = 300;
/**
 * 服务端搜索结果补数据的并发数：/c/s/searchpost 只给 tid/pid/title/content/time/fname/author{name,name_show}，
 * 缺 authorId（点作者不跳转）、头像（降级为字母）、回复数/点赞数（恒为 0），故按 tid 拉详情补齐。
 * 详情接口与点开帖子同源且带缓存，并发 3 兼顾补齐速度与风控。
 */
const SEARCH_ENRICH_CONCURRENCY: number = 3;
/** 本地扫描硬上限（页）：防超大吧在后台无限扫描（约 1600 帖），到顶即停止并如实提示 */
const SEARCH_SCAN_MAX_PAGES: number = 80;
/** 自动续载延迟：给 UI 一帧渲染机会再取下一批 */
const SEARCH_AUTO_CONTINUE_MS: number = 120;

/**
 * 排序 tab 切换（热门 / 最新 / 精选）——**照搬首页 `Index.switchTab` 的「两页连着」过场**：
 * 数据就位的那一帧，新内容自对侧整屏（±100%）进入，**旧内容同时向反侧整屏滑出**，二者在同一个
 * `animateTo`（320ms / `springMotion(0.72, 0.86)`）里对向平移 —— 屏幕上任一瞬间都是"两页相接在移动"，
 * 这正是首页 5 个 Tab 切页那种"仿佛两个界面连在一起"的顺滑感来源。
 *
 * 演进（三次真机反馈，教训都留在这里）：
 *   ① 单侧滑入 120 / 300ms `FastOutSlowIn` → 起点慢、收尾也慢，被判"生硬"；
 *   ② 「退场 + 入场」双拍（130ms 反向退场 + 微缩 + 淡到 0.25 + 140vp 入场）→ 被判**"太过度、中间还会卡一下"**：
 *      过度来自位移幅度与叠在一起的三类变化（位移 / 透明度 / 缩放），卡顿来自两拍之间的等待帧
 *      （退场播完到入场播放之间内容静止约 160ms）与入场前的强制停帧（24ms）；
 *   ③ 收缩为"只有新页滑入"的一段式（100vp）→ 被判"变回生硬"：**旧页不动、被瞬间替换掉**，
 *      本质只是"一块内容换成另一块"，缺少两页相接的连续感；
 *   ④ 现按首页原样复刻：新页 ±100%、旧页反向 ±100%、同一个 `animateTo` —— **关键在旧页不消失**。
 *
 * 「旧页画面」从哪来：首页每页都是常驻组件（`visibility` 隐藏、切页只改位移），所以旧页天然在树上；
 * 本页只有一个列表、数据在切换那一刻被整体替换，旧内容无处可寻，故在**点击那一刻**
 * 用 `componentSnapshot.getSync`（同步）截下列表区（旧内容 + 旧滚动位置，吧头由 region 裁掉）存为 PixelMap，
 * 由一层 `Image` 承载滑出，动画收口后释放。同步截图取的是上一帧已渲染的成品，不阻塞布局、
 * 不引入等待帧、也不改变任何现有几何。
 *
 * 「平移作用域 = 只到列表区，吧头 / 顶栏 / 底栏静止」（2026-09-12 真机反馈后的调整）：
 *   位移原挂在 Scroll 上，而吧头（吧名 / 头像 / 关注签到）是 Scroll 内容里的普通子项，于是**吧头被一起带着滑**；
 *   首页切 Tab 时标题栏与底栏都是静止的，只有内容页对向平移 —— 两者观感不一致。现改为：
 *   ① 新页位移缩到 Scroll 内的「列表区」那一层（内容 / 骨架屏 / 空态 / 错误），吧头与兜底排序栏不参与位移；
 *   ② 旧页快照用 `SnapshotOptions.region`（单位 px，API 15+）裁掉吧头、只留列表区，快照层再按裁剪量下移到
 *      列表区位置 —— 屏幕上于是"吧头原地不动、只有下方列表对向平移"，与首页头部固定、内容平移同构；
 *   ③ 吧头已滚出屏幕上方（或高度尚未测到）时不裁：整屏即列表内容，行为与调整前一致，属自动降级。
 *   注意：只做水平位移、垂直位置不动，故列表区不会与静止的吧头在几何上重叠。
 */
const SORT_ANIM_DURATION: number = 320;     // 对向平移时长（ms）：与首页 Tab 切换同值
const SORT_ANIM_SETTLE: number = 420;       // 动画收口时刻（≈时长的 1.3 倍）：卸载旧页快照 + 复位位移
const SORT_SKELETON_FADE: number = 150;     // 未命中缓存时骨架屏淡入时长（ms，不与滑入叠加）
/** Scroll 首项「顶栏让位」高度 vp：也即吧头块在 Scroll 内容坐标里的顶边。
 *  渲染层首个占位项必须与本值同源；旧页快照的裁剪边界（= 本值 + 吧头块实测高 − 当前滚动偏移）由它推出。 */
const THREAD_LIST_HEADER_TOP_SPACE: number = 90;
/** 内容滚动容器 id：`componentSnapshot` 按它截取旧页（见上方 SORT_ANIM_* 注释） */
const THREAD_SCROLL_SNAPSHOT_ID: string = 'threadListScrollSnapshot';

/**
 * 吧主页官方槽位开关（§6.10 模板）：true 且设备支持材质时，顶栏整行（返回 / 搜索框 / 搜索钮 / 更多钮）
 * 搬进 Navigation title 槽位吃官方沉浸材质；false 或低版本自动回退到页面主体悬浮自绘玻璃（改造前原样）。
 */
const THREAD_LIST_OFFICIAL_TITLE_BAR: boolean = true;
/** 槽位高度 = 44(状态栏让位) + 44(钮行高) + 10(底部呼吸)，与改造前悬浮顶栏 padding 逐项一致；
 *  内容让位（Scroll 首项占位 90）一行未改。 */
const THREAD_LIST_TITLE_BAR_HEIGHT: number = 98;
/**
 * 悬浮 FAB 官方槽位壳（**壳内只剩加号一枚**）：刷新钮已于 2026-09-12 按用户要求移除，
 * 刷新入口改由「重复点击当前排序」承担（见 `refreshByRetap` / SortSegBar 注释），
 * 故壳高由 124（56 + 12 + 56）回到 **56**。
 * 底距 30 = 排序底栏底距 —— **加号钮与底部排序栏同排**（底边一条线，高 56 与栏高 56 顶边也一条线），
 * 故加号钮占 30~86（右缘 24）。
 * （兜底路径的自绘 FAB 不受影响，仍按改造前的 36 贴底：兜底路径没有底部排序栏，
 *   加号贴底本就无同排对象，强行对齐无意义。）
 */
const THREAD_LIST_FAB_SHELL_HEIGHT: number = 56;
const THREAD_LIST_FAB_SHELL_BOTTOM: number = 30;
/** 壳宽 = 右缘 24 + 钮宽 56 = 80（A 方案）：壳与页签只占「按钮这一列」。
 *  依据：TabBar 页签节点的命中区恒等于自身矩形，壳开全宽时该节点横跨整行、空区照样吞走
 *  竖向滑动手势（`hitTestBehavior` 设不到系统页签节点上，B 方案已实测无效）。
 *  收窄后死区与加号钮重合，列表其余区域无遮挡。
 *  右缘由 28 收到 24：同排后与排序底栏左缘 24 左右对称、同一条基准线。 */
const THREAD_LIST_FAB_SHELL_WIDTH: number = 80;

/**
 * 吧主页底部排序栏（热门 / 最新 / 精选）官方槽位开关（§6.10 模板）：
 * true 且设备支持材质时，排序栏从 Scroll 内容区（吧头下方）搬到屏幕底部，做成与首页 / 搜索页
 * 完全同款的官方沉浸光感悬浮底栏；false 或低版本自动回退到内容区自绘真模糊胶囊（改造前原样）。
 *
 * 为什么必须搬家：页面主体（含 Scroll 内元素）挂 `systemMaterial` 必判
 * `Material inactive: out of scope`，官方沉浸材质只在「Navigation 标题栏 / Tabs(barPosition: End)
 * 底部 tabBar」两类槽位生效 —— 故整条排序栏做成「只有 tabBar 的真实 Tabs 壳」。
 * 材质来源：空壳路径**不能**靠 `barFloatingStyle` 生成官方背板（真机已验证不渲染），
 * 必须由**槽内元素自己挂** `.systemMaterial(ImmMaterial.floatingBarFlat())`（§1.1「自建空 Tabs 壳内的元素」）；
 * 用**无阴影档**而非 `floatingBar()`：本栏下方没有官方背板托底，带阴影版会在栏体四周压出突兀暗晕。
 */
const THREAD_LIST_OFFICIAL_SORT_BAR: boolean = true;
/** 排序栏高 56 = 右下加号钮直径（两框同排后**高度对齐**，`Radius.full` 收成 28 与加号同圆）；
 *  栏内只有文字、没有图标，故比首页 / 搜索页底栏（74 = 图标 + 文字）矮 18；
 *  栏内三枚钮高 = 56 − 上下 padding 5×2 = 46（与加号同排改造前逐项一致，只是外框矮 2） */
const THREAD_LIST_SORT_BAR_HEIGHT: number = 56;
/** 排序栏内上下留白：钮高 = 栏高 − 2 × 本值（SortSegBar 的 padding 与 SortSegButton 的高度共用）。
 *  取 5 而非 6：栏高由 58 收成 56 后，靠留白 6 → 5 把钮高 46 保住，栏内文字块几何零变化。 */
const THREAD_LIST_SORT_BAR_PADDING: number = 5;
/** 排序栏底距 30 = 右下加号钮底距（同排对齐的基线，同时与首页底栏 `barBottomMargin` 一致）；
 *  槽位壳收窄后底距由外层全宽 `Row` 的 margin 承担（壳自身不设 margin，见 SortSlotShell） */
const THREAD_LIST_SORT_BAR_BOTTOM: number = 30;
/** 排序栏与加号钮之间的横向缝隙（两框**分离开**、不并成一条）：左 24 | 底栏 | 12 | 加号 | 右 24 */
const THREAD_LIST_SORT_BAR_GAP: number = 12;
/** 列表底部让位（槽位路径）：加号钮顶 86（底距 30 + 56）+ 12 呼吸 = 98
 *  （刷新钮移除后最高点由刷新钮退回加号，故比原值 166 少 68、比更早的 244 少 146，
 *    列表可视区同步变大）。 */
const THREAD_LIST_CONTENT_BOTTOM_SPACE: number = 98;

/** 吧列表本地快照（含吧头信息），命中缓存即秒开再后台静默刷新 */
interface ForumListCache {
  threads: ThreadItem[];
  forumInfo: ForumHeaderInfo | null;
}

/**
 * 页内会话排序快照：本次进吧期间展示过的排序数据 + 分页状态。
 * 切回该排序且未超 SORT_SESSION_TTL 时 0 开销直出（免 Preferences 读盘、免重复网络刷新）。
 */
interface SortSession {
  threads: ThreadItem[];
  page: number;
  hasMore: boolean;
  ts: number;
}

/** 排序会话快照保鲜期：期间内切回已看过的排序直接秒开 */
const SORT_SESSION_TTL: number = 120000;

/**
 * 排序切换「上屏」数据包：`applySortDisplay` 的统一入参 —— 数据来源（页内快照 / 本地缓存 / 网络）
 * 不同，但「替换 + 回顶 + 起滑」这套上屏动作完全一致。
 * `sort` 用于竞态校验：快速连点时丢弃不属于当前排序的迟到数据。
 */
interface SortDisplay {
  sort: number;
  threads: ThreadItem[];
  page: number;
  hasMore: boolean;
  /** Success / Empty = 直接上屏播入场；Loading = 未命中缓存，落骨架屏等网络 */
  state: LoadState;
}

/**
 * 吧主页右上角「更多」操作面板（系统 CustomDialog + API 26 沉浸光感）。
 *
 * 为什么从「自绘浮层」改成系统弹窗：官方沉浸光感的 A 档「弹窗类」只覆盖系统 Dialog /
 * 弹窗类接口（CustomDialogControllerOptions、AlertDialogParam、ActionSheetOptions、
 * SheetOptions、PromptAction 等）；页面 body 内的自绘 Stack 浮层不在生效范围内，
 * 挂 systemMaterial 必然判 `Material inactive: out of scope`（工程文档 §1.2 / §8 已证实）。
 *
 * 几何与内容对齐（与改造前的自绘浮层逐项一致）：
 * - 宽度 calc(100% - 48vp) → options.width 数值 vp；圆角 32vp；遮罩 #06000000；
 *   底部锚点（底距 30，即「小白条」上沿的悬浮基线）；标题行 / 菜单行 / 分隔线 / 取消按钮
 *   尺寸与字号全部原样保留。
 *
 * 玻璃层由宿主的 options.systemMaterial 承担（材质会接管容器的背景色 / 背景模糊 / 边框 / 阴影），
 * 因此卡内不再自绘 backgroundColor / backgroundBlurStyle / border / shadow 这四项；
 * 卡内「取消」按钮是例外 —— 按钮自身挂材质时半透明底色 + 自定义轻投影可与材质共存（文档 §6.2）。
 */
@CustomDialog
struct ForumMoreDialogCard {
  /** 系统弹窗必须声明 CustomDialogController 类型属性（ArkTS 编译期强校验） */
  controller?: CustomDialogController;
  @Link isDark: boolean;
  @Link fontScale: number;
  /** 吧名（宿主 forumName 直接双向绑定） */
  @Link forumName: string;
  /** 打开那一刻是否已关注（决定菜单文案与图标；快照由宿主在打开前同步） */
  @Link liked: boolean;
  /** 分享吧 */
  onShare: () => void = () => {};
  /** 关注 / 取消关注 */
  onToggleFollow: () => void = () => {};
  /** 取消 / 点遮罩 / 返回键 */
  onDismiss: () => void = () => {};

  build() {
    Column({ space: 0 }) {
      // 标题行：吧名 + 已关注标签
      Row({ space: 8 }) {
        Text(this.forumName)
          .fontSize(fs(17, this.fontScale))
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.textPrimary(this.isDark))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (this.liked) {
          Text('已关注')
            .fontSize(fs(11, this.fontScale))
            .fontColor(Theme.brand())
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .borderRadius(Radius.full)
            .backgroundColor(Theme.brandBg(this.isDark))
        }
      }
      .width('100%')
      .padding({ left: Spacing.lg, right: Spacing.lg, top: Spacing.lg, bottom: Spacing.sm })

      // 分享吧
      Row({ space: Spacing.md }) {
        SymbolGlyph($r('sys.symbol.arrow_up'))
          .fontSize(fs(19, this.fontScale))
          .fontColor([Theme.textPrimary(this.isDark)])
        Text('分享吧')
          .fontSize(fs(15, this.fontScale))
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.textPrimary(this.isDark))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: Spacing.lg, right: Spacing.lg, top: 12, bottom: 12 })
      // 圆角 26：与全局卡片统一口径（本行无填充底，圆角当前不可见，仅保持令牌一致）
      .borderRadius(26)
      .accessibilityText('分享吧')
      .onClick(() => { this.onShare(); })

      Column()
        .width('calc(100% - 32vp)')
        .height(0.5)
        .backgroundColor(this.isDark ? '#26FFFFFF' : '#12000000')

      // 关注 / 取消关注（状态跟随打开时的快照，取消关注为危险操作）
      Row({ space: Spacing.md }) {
        SymbolGlyph($r(this.liked ? 'sys.symbol.heart_fill' : 'sys.symbol.heart'))
          .fontSize(fs(19, this.fontScale))
          .fontColor([this.liked ? Theme.danger() : Theme.textPrimary(this.isDark)])
        Text(this.liked ? '取消关注' : '关注')
          .fontSize(fs(15, this.fontScale))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.liked ? Theme.danger() : Theme.textPrimary(this.isDark))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: Spacing.lg, right: Spacing.lg, top: 12, bottom: 12 })
      // 圆角 26：与全局卡片统一口径（本行无填充底，圆角当前不可见，仅保持令牌一致）
      .borderRadius(26)
      .accessibilityText(this.liked ? '取消关注' : '关注')
      .onClick(() => { this.onToggleFollow(); })

      Button() {
        Text('取消')
          .fontSize(fs(15, this.fontScale))
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.textPrimary(this.isDark))
      }
      .width('100%')
      .height(44)
      .margin({ top: Spacing.sm })
      // 与一键签到 / 吧菜单弹窗的次按钮同源：材质 + 半透明底 + 中性轻投影
      // （底色不透明会完全盖掉材质滤镜，故必须带透明度，见文档 §6.2 / 坑 11）
      .systemMaterial(ImmMaterial.cardAction())
      .backgroundColor(this.isDark ? '#B31B1E24' : '#B3FFFFFF')
      .borderRadius(Radius.full)
      .shadow({ radius: 10, color: this.isDark ? '#4D000000' : '#1F101824', offsetY: 3 })
      .accessibilityText('取消')
      .onClick(() => { this.onDismiss(); })
    }
    .width('100%')
    .padding({ left: Spacing.lg, right: Spacing.lg, bottom: Spacing.lg })
  }
}

@Entry
@Component
struct ThreadList {
  @State forumName: string = '';
  @State forumId: string = '';
  @State @Watch('onThreadsChanged') threads: ThreadItem[] = [];
  // 页内会话排序快照：切走再切回同一排序时 0 开销秒开（免 Preferences 读盘 + 免重复网络刷新）
  private sortSession: Map<number, SortSession> = new Map<number, SortSession>();
  // 排序预热标记：首次成功展示后后台把其它两个排序的冷缓存拉好，使首次切换即命中
  private warmupStarted: boolean = false;
  @State loadState: LoadState = LoadState.Loading;
  @State errorMsg: string = '';
  @State page: number = 1;
  @State hasMore: boolean = true;
  @State loadingMore: boolean = false;
  @State stalledPages: number = 0;
  // 吧主页预加载：测量值 + 节流/竞态（普通字段，避免高频回调触发 UI 重建）
  private contentH: number = 0;
  private viewportH: number = 0;
  /** 视口宽（vp）：仅旧页快照的 region 需要（region 四边单位是 px，见 captureExitSnapshot） */
  private viewportW: number = 0;
  /** 吧头块实测高（vp）= 吧头（+ 兜底排序栏）那一层，由渲染层 onAreaChange 回填。
   *  旧页快照的裁剪边界由它推出；未测到（≤ 0）时不裁、自动降级回调整前的整屏裁剪行为 */
  private headerBlockH: number = 0;
  private lastPrefetchY: number = -10000;
  private loadToken: number = 0;
  @State selectedSort: number = 0;
  @State isDark: boolean = isDarkMode();
  @State forumInfo: ForumHeaderInfo | null = null;
  @State failedAvatar: boolean = false;
  @State signDays: number = 0;
  /**
   * 吧主页右上角「更多」操作面板显隐（系统 CustomDialog + API 26 沉浸光感）。
   * 宿主已由「页面 body 内自绘 Stack 浮层」换成系统 CustomDialog —— 官方 A 档「弹窗类」
   * 只覆盖系统 Dialog / 弹窗类接口，自绘浮层挂 systemMaterial 必然 out of scope。
   * 保留单一布尔状态，真正 open/close 由 @Watch 驱动，既有 `this.showMoreSheet = x` 调用点零改动。
   */
  @State @Watch('onShowMoreChanged') showMoreSheet: boolean = false;
  /** 弹窗展示快照：打开那一刻是否已关注（可空对象 forumInfo 不能直接 @Link 进 @CustomDialog） */
  @State moreSheetLiked: boolean = false;
  // 吧主页关注/取消关注进行中，防止重复点击
  @State forumFollowBusy: boolean = false;
  @State refreshing: boolean = false;
  // 列表滚动控制器：刷新成功后回到顶部，立即看到最新内容
  private listScroller: Scroller = new Scroller();
  // 本吧搜索：服务端搜索优先（/c/s/searchpost，TiebaLite 同款端点），失败降级为本地扫描吧内分页
  @State searchMode: boolean = false;
  @State searchKeyword: string = '';
  // 结果池：服务端模式 = 服务端命中列表；本地模式 = 扫过的吧内帖子池（再按标题/摘要过滤）
  @State searchPool: ThreadItem[] = [];
  // searchFetching = 正在取数（结果区显示"正在搜索"）；searchExhausted = 已到末尾
  @State searchFetching: boolean = false;
  @State searchExhausted: boolean = false;
  // —— 服务端搜索态（searchServerMode=false 表示已降级为本地扫描，本会话不再重试）——
  private searchServerMode: boolean = true;
  private searchServerPage: number = 0;
  private searchServerHasMore: boolean = true;
  // —— 本地扫描态：池已扫到的吧内页码 / 连续无新增批次数 / 是否还有更多分页 / 已扫页数 ——
  private searchPage: number = 0;
  private searchStalled: number = 0;
  private searchHasMore: boolean = true;
  private searchScannedPages: number = 0;
  // 搜索结果缓存（键 = 关键词 + 池版本）：避免大池在滚动渲染中被反复全量过滤
  private searchPoolVersion: number = 0;
  private searchCacheKey: string = '';
  private searchCacheResult: ThreadItem[] = [];
  // 搜索会话代际：换关键词/退出搜索即自增，使在途结果作废；searchTimer = 输入防抖定时器
  private searchToken: number = 0;
  private searchTimer: number = -1;
  // 自动续载定时器 + 最近滚动偏移：结果不满一屏时无法滚动，必须主动补下一批（否则"加载不出来"）
  private searchAutoTimer: number = -1;
  private lastScrollY: number = 0;
  @StorageLink('fontScale') fontScale: number = 1.0;
  /** 页面可见时自增，强制组件重建使字号实时生效 */
  @State fontSizeTick: number = 0;
  /** API26+ 沉浸光感能力：true 时顶栏走官方 title 槽位、FAB 走「空 tabBar 壳」槽位，
   *  否则回退页面主体自绘玻璃（与 ThreadDetail 同判据） */
  @State materialSupported: boolean = false;
  /** 根容器实宽（vp）：底部排序栏槽位壳的 `barWidth` 只接受数值（Dimension 不收 'calc(100% - 48vp)'，
   *  同 Search.ets / 本页 dialogCardWidth 的换算口径），由 ThreadListContent 根 Stack 的 onAreaChange 维护 */
  @State currentWidth: number = 0;

  onPageShow(): void {
    this.fontSizeTick++;
  }

  /**
   * 系统返回手势拦截（同 Index BUG-01 方案）：本吧搜索是页内状态（searchMode，不在路由栈里），
   * 搜索态下系统返回应先退出搜索、回到吧主页帖子列表，而不是把整个吧主页弹出（此前会直接退到进吧页）。
   */
  onBackPress(): boolean {
    if (this.searchMode) {
      this.exitSearch();
      return true;
    }
    return false;
  }
  // 骨架屏→内容交叉淡入淡出（同帖详情方案A）：内容初始透明淡入，骨架屏淡出后由 loadState 切换移除
  @State contentOpacity: number = 0.0;
  @State skeletonOpacity: number = 1.0;
  // 排序切换过场：新页位移 / 旧页快照位移（百分比，相对各自宽度 = 屏宽），与首页 switchTab 同款
  @State inOffset: number = 0;
  @State outOffset: number = 0;
  // 旧页快照（点击那一刻同步截下的**列表区**内容，吧头已被 region 裁掉）：切换期间由一层 Image 承载滑出，收口后释放
  @State exitSnapshot: image.PixelMap | null = null;
  // 旧页快照的顶部裁剪量（vp，点击那一刻算好）：= 吧头块底边在 Scroll 视口里的 y，≥ 0；
  // 0 = 整屏都是列表内容（吧头已滚出屏 / 吧头高未测到）；> 0 时旧页层下移该距离、高度相应收窄，落在列表区上
  @State exitClipTop: number = 0;
  // 本次切换方向（±1；0 = 非排序切换）：位移方向，同时是"是否走排序切换动画"的判据
  private enterDir: number = 0;
  // 动画窗口的结束时刻（ms 时间戳）：窗口内静默刷新只回写缓存不上屏，避免"滑到一半内容变了"
  private sortAnimUntil: number = 0;
  // 过场收口定时器：动画结束后卸载旧页快照并复位位移（快速连切时先清掉上一个）
  private sortSettleTimer: number = -1;
  // tab 按压回弹：点击瞬间缩一下再弹回，增强切换按键手感
  @State pressedTab: number = -1;
  private pulseTimer: number = -1;
  // 延迟初始化：aboutToAppear生命周期阶段UIContext就绪后赋值，避免类字段初始化期获取null
  private context?: common.UIAbilityContext;

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
   * 吧主页帖子分享：Share Kit 系统分享面板（参考CSDN宿主应用发起分享）；主路径失败→剪贴板兜底复制链接
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
        this.getUIContext().getPromptAction().showToast({ message: '系统分享不可用，正在复制链接' });
        this.copyShareToClipboard(fullText, titleLine, threadUrl);
        return;
      }

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
          this.getUIContext().getPromptAction().showToast({ message: '系统分享面板已弹出' });
        }).catch((showErr: BusinessError) => {
          const code = showErr?.code ?? 'unknown';
          const msg = showErr?.message ?? String(showErr);
          this.getUIContext().getPromptAction().showToast({
            message: `分享面板失败[${code}]：${msg}`
          });
          this.copyShareToClipboard(fullText, titleLine, threadUrl);
        });
        return;
      } catch (_) {
        this.getUIContext().getPromptAction().showToast({ message: '系统分享不可用，正在复制链接' });
        this.copyShareToClipboard(fullText, titleLine, threadUrl);
      }
    } catch (outerErr) {
      const errMsg: string = outerErr instanceof Error ? outerErr.message : String(outerErr);
      this.getUIContext().getPromptAction().showToast({ message: `分享异常：${errMsg}` });
    }
  }

  /**
   * 兜底写入系统剪贴板：分享面板不可用时用户仍可粘贴发送
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

  /**
   * 吧主页右上角「分享吧」：通过系统分享面板分享吧链接。
   * 主路径失败 → 剪贴板兜底复制链接。
   */
  private shareForum(): void {
    try {
      const forumUrl: string = `https://tieba.baidu.com/f?kw=${encodeURIComponent(this.forumName)}`;
      const titleLine: string = `「${this.forumInfo?.forumName ?? this.forumName}」吧`;
      const descriptionText: string = (this.forumInfo?.slogan ?? '').length > 0
        ? (this.forumInfo!.slogan.length > 140 ? `${this.forumInfo!.slogan.substring(0, 140)}…` : this.forumInfo!.slogan)
        : '';
      const fullText: string = descriptionText.length > 0
        ? `${titleLine}\n${descriptionText}\n${forumUrl}`
        : `${titleLine}\n${forumUrl}`;
      const abilityCtx: common.UIAbilityContext = this.getUIAbilityContext();
      if (!abilityCtx) {
        this.getUIContext().getPromptAction().showToast({ message: '系统分享不可用，正在复制链接' });
        this.copyShareToClipboard(fullText, titleLine, forumUrl);
        return;
      }
      try {
        const sharedData: systemShare.SharedData = new systemShare.SharedData({
          utd: utd.UniformDataType.HYPERLINK,
          content: forumUrl,
          title: titleLine,
          description: descriptionText
        });
        const controller: systemShare.ShareController = new systemShare.ShareController(sharedData);
        controller.show(abilityCtx, {
          previewMode: systemShare.SharePreviewMode.DETAIL,
          selectionMode: systemShare.SelectionMode.SINGLE
        }).then(() => {
          this.getUIContext().getPromptAction().showToast({ message: '系统分享面板已弹出' });
        }).catch((showErr: BusinessError) => {
          const code = showErr?.code ?? 'unknown';
          const msg = showErr?.message ?? String(showErr);
          this.getUIContext().getPromptAction().showToast({
            message: `分享面板失败[${code}]：${msg}`
          });
          this.copyShareToClipboard(fullText, titleLine, forumUrl);
        });
      } catch (_) {
        this.getUIContext().getPromptAction().showToast({ message: '系统分享不可用，正在复制链接' });
        this.copyShareToClipboard(fullText, titleLine, forumUrl);
      }
    } catch (outerErr) {
      const errMsg: string = outerErr instanceof Error ? outerErr.message : String(outerErr);
      this.getUIContext().getPromptAction().showToast({ message: `分享异常：${errMsg}` });
    }
  }

  /** 克隆吧头信息并覆写关注态（ArkTS 禁用对象展开，只能逐字段构造） */
  private withFollowState(info: ForumHeaderInfo, isLike: boolean): ForumHeaderInfo {
    return {
      forumId: info.forumId,
      forumName: info.forumName,
      avatar: info.avatar,
      bannerUrl: info.bannerUrl,
      slogan: info.slogan,
      memberCount: info.memberCount,
      threadCount: info.threadCount,
      postCount: info.postCount,
      userLevel: info.userLevel,
      levelName: info.levelName,
      curScore: info.curScore,
      levelupScore: info.levelupScore,
      isLike: isLike,
      hasFrsStar: info.hasFrsStar
    };
  }

  /**
   * 吧主页「关注 / 取消关注」：根据当前 forumInfo.isLike 反向操作。
   * 乐观更新吧头状态，失败时回滚并提示。
   * 不可变更新（整体替换）而非就地改属性：保证签到钮「未关注 / 未签到」文案
   * 与「吧操作」面板的「已关注」标签都能可靠刷新。
   */
  private async handleForumFollow(): Promise<void> {
    if (this.forumFollowBusy) {
      return;
    }
    if (!this.forumInfo) {
      this.getUIContext().getPromptAction().showToast({ message: '吧信息尚未加载，请稍后再试' });
      return;
    }
    const fid: string = this.forumInfo.forumId;
    if (fid.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '贴吧 ID 缺失，无法操作' });
      return;
    }
    this.forumFollowBusy = true;
    const previous: ForumHeaderInfo = this.forumInfo;
    const wasLiked: boolean = previous.isLike;
    this.forumInfo = this.withFollowState(previous, !wasLiked);
    try {
      await TiebaService.getInstance().toggleFollow(this.forumName, !wasLiked, fid);
      this.getUIContext().getPromptAction().showToast({ message: wasLiked ? '已取消关注' : '已关注' });
    } catch (e) {
      // 失败回滚状态
      this.forumInfo = previous;
      this.getUIContext().getPromptAction().showToast({
        message: (e instanceof Error ? e.message : String(e)) || '操作失败，请稍后重试'
      });
    } finally {
      this.forumFollowBusy = false;
    }
  }

  /**
   * 排序切换入口（热门 / 最新 / 精选）——首页 `switchTab` 同款的「两页对向平移」，见文件头 SORT_ANIM_* 注释。
   *
   * ① 收口上一次未播完的过场（快速连切，避免两条动画互相覆盖）→ ② **同步截下当前列表区**作为旧页
   * （此刻旧内容还完整在场、滚动位置正确，早于此或晚于此都截不到；吧头由 region 裁掉，见
   * `captureExitSnapshot`）→ ③ 记方向、换排序与分页状态
   * → ④ 数据侧加载（loadThreads）。数据就位后由 `applySortDisplay` 在同一帧内完成
   * 「替换 + 回顶 + 摆起点 + 双页对向起滑」，中途不插等待帧、没有第二段动画 ——
   * 页内快照是同步命中，所以最常走的路径就是"点下去那一帧两页就开始对向平移"。
   *
   * 注意：此处**不清空** `this.threads` —— 数据到达前保持旧列表可见，避免闪空；
   * 若本次未命中缓存，则由 `applySortDisplay` 落骨架屏等网络返回（网络回来才走过场）。
   */
  private selectSort(sort: number): void {
    if (this.selectedSort === sort) {
      // 重复点击当前排序 = 刷新该排序（先回顶、再拉第 1 页，见 refreshByRetap）。
      // 与切排序不同：不动选中态、不播过场动画，只做「回顶 + 刷新」。
      this.refreshByRetap(sort);
      return;
    }
    // ① 收口上一次过场（同时释放上一次的旧页快照）
    this.clearSortSettle();
    // ② 旧页快照：同步截取当前屏幕（必须在数据被替换之前）
    this.captureExitSnapshot();
    // ③ 方向：目标 tab 在右侧（索引增大）→ 新页自右侧进入、旧页向左滑出，反向则相反
    this.enterDir = sort > this.selectedSort ? 1 : -1;
    this.selectedSort = sort;
    this.page = 1;
    this.hasMore = true;
    this.stalledPages = 0;
    // ④ 数据侧：页内快照 / 本地缓存 / 网络在 loadThreads 内依次尝试（命中快照时同步上屏，见其注释）
    this.loadThreads();
  }

  /**
   * 重复点击当前排序（当前已是「热门」再点热门，最新 / 精选同理）：**回到列表顶部 + 重新拉取第 1 页**。
   * 本页刷新入口自 2026-09-12 起**只此一处**（右下角刷新钮已按用户要求移除），链路即 `handleRefresh()`：
   * 网络刷新第 1 页、8s 超时兜底、「刷新成功 / 失败」toast、后台昵称校准与缓存回写；
   * 多出的一步是**先立即回顶**（不等网络返回），让等待期间用户已经看到顶部内容
   * （handleRefresh 成功后还会再回顶一次，幂等）。
   * busy（已有刷新在跑）时只回顶、不重复发请求 —— 与 handleRefresh 的 busy 短路口径一致。
   * 数据侧的附带收益：新列表经 `threads` 的 @Watch（onThreadsChanged）自动回写 `sortSession` 快照，
   * 切走再切回该排序拿到的已是刷新后的数据。
   */
  private refreshByRetap(sort: number): void {
    console.info(`[SORT] retap cur=${sort} -> scroll top + refresh`);
    // ① 立即回顶：动画与刷新成功后的回顶保持一致（不阻塞、不等待网络）
    this.listScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: { duration: 300, curve: Curve.EaseOut } });
    // ② 复用既有刷新链路（内部自带 busy 短路、超时兜底与 toast 反馈）
    this.handleRefresh();
  }

  /** tab 点击按压脉冲：缩小一下再弹回，提升切换按键手感 */
  private pulseTab(sort: number): void {
    if (this.pulseTimer !== -1) {
      clearTimeout(this.pulseTimer);
    }
    this.pressedTab = sort;
    this.pulseTimer = setTimeout(() => {
      this.pressedTab = -1;
      this.pulseTimer = -1;
    }, 90);
  }

  aboutToAppear(): void {
    // 生命周期阶段UIContext已就绪，安全初始化context缓存
    this.context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    // 本页多列改造尚未落地：显式写回单列，避免吃到首页（已多列）留下的 cardColumns 残留，
    // 让 ThreadCard 在手机上仍是改造前的单列几何（§6.1 D1「跨页共享标记必须在每个使用页都写」）。
    // 本页落地多列（T-B）后，此处改为按本页列数无条件写入。
    AppStorage.setOrCreate('cardColumns', 1);
    MaterialManager.init();
    this.materialSupported = MaterialManager.isSupported() && MaterialManager.getApiLevel() >= 26;
    const params = this.getUIContext().getRouter().getParams() as Record<string, string>;
    if (params) {
      if (params.kw) {
        this.forumName = `${params.kw}`;
      } else if (params.forumName) {
        this.forumName = `${params.forumName}`;
      }
      if (params.fid) {
        this.forumId = `${params.fid}`;
      }
    }
    this.isDark = isDarkMode();
    if (this.forumName.length === 0) {
      this.loadState = LoadState.Error;
      this.errorMsg = '缺少贴吧名称，无法进入吧主页';
      return;
    }
    // 恢复本吧今日签到状态：吧头接口不返回签到态，签到结果由本地记录持久化回显
    this.restoreSignState();
    this.loadThreads();
  }

  private openThread(tid: string): void {
    if (tid.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '帖子信息暂不可用' });
      return;
    }
    // 点击即预取：利用跳转动画窗口后台取详情，详情页打开即命中缓存秒开
    TiebaService.getInstance().prefetchThreadDetail(tid, this.forumId);
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/ThreadDetail',
      params: { tid: tid, forum: this.forumName, fid: this.forumId }
    }).catch(() => {
      this.getUIContext().getPromptAction().showToast({ message: '帖子打开失败，请稍后重试' });
    });
  }

  /** 头像点击：跳转作者用户主页 */
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

  private openCompose(): void {
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/ComposeThread',
      params: { kw: this.forumName, fid: this.forumId }
    }).catch(() => {
      this.getUIContext().getPromptAction().showToast({ message: '发帖页面打开失败，请稍后重试' });
    });
  }

  /** 本吧搜索：进入搜索态（服务端搜索优先，失败降级本地扫描；退出返回帖子列表） */
  private openSearch(): void {
    this.searchMode = true;
    this.searchKeyword = '';
    this.resetSearchSession();
  }

  private exitSearch(): void {
    this.searchMode = false;
    this.searchKeyword = '';
    this.resetSearchSession();
    // 退出即释放搜索池，避免大数组常驻
    this.searchPool = [];
    this.searchPoolVersion++;
  }

  /**
   * 重开搜索会话：作废在途结果（代际自增）、取消定时器、复位双模式进度，
   * 并重试服务端搜索（上次失败可能只是瞬时风控）。
   * 本地模式的初始池取当前列表已有帖子——同排序时列表已覆盖 1..page 页，
   * 扫描直接从下一页起，不重复请求，输入首个字符就能先看到池内已有匹配。
   */
  private resetSearchSession(): void {
    this.searchToken++;
    this.cancelSearchTimers();
    this.searchFetching = false;
    this.searchExhausted = false;
    this.searchServerMode = true;
    this.searchServerPage = 0;
    this.searchServerHasMore = true;
    this.searchPool = this.threads.slice();
    this.searchPoolVersion++;
    this.searchPage = this.selectedSort === SEARCH_SCAN_SORT ? this.page : 0;
    this.searchStalled = 0;
    this.searchHasMore = true;
    this.searchScannedPages = 0;
  }

  /** 取消搜索相关的两个定时器（输入防抖 + 自动续载） */
  private cancelSearchTimers(): void {
    if (this.searchTimer !== -1) {
      clearTimeout(this.searchTimer);
      this.searchTimer = -1;
    }
    if (this.searchAutoTimer !== -1) {
      clearTimeout(this.searchAutoTimer);
      this.searchAutoTimer = -1;
    }
  }

  /**
   * 关键词输入（防抖 SEARCH_DEBOUNCE_MS）：重启本关键词的取数。
   * 服务端模式换词必须清空重取（结果与关键词强相关）；
   * 本地模式池跨关键词保留——改词只重算匹配、不重扫，因此越搜越快。
   */
  private onSearchKeywordChange(v: string): void {
    this.searchKeyword = v;
    this.searchToken++;
    this.searchExhausted = false;
    this.searchFetching = false;
    this.cancelSearchTimers();
    if (v.trim().length === 0) {
      return;
    }
    const myToken: number = this.searchToken;
    this.searchTimer = setTimeout(() => {
      this.searchTimer = -1;
      if (myToken !== this.searchToken || !this.searchMode) {
        return;
      }
      this.startSearch();
    }, SEARCH_DEBOUNCE_MS);
  }

  /** 开搜：按当前模式取第一批（服务端优先；已降级则本地扫描） */
  private startSearch(): void {
    this.cancelSearchTimers();
    if (this.searchServerMode) {
      this.searchServerPage = 0;
      this.searchServerHasMore = true;
      this.searchPool = [];
      this.searchPoolVersion++;
      this.searchServerFetch(true);
    } else {
      this.searchStalled = 0;
      this.searchScan(SEARCH_BATCH_RESULTS);
    }
  }

  /**
   * 服务端吧内搜索取页（TiebaLite 同款 /c/s/searchpost）：一页 SEARCH_SERVER_PAGE_SIZE 条，
   * 一次请求即整屏命中——这是"结果少 + 下滑加载慢"的根治手段。
   * 首屏失败（风控/未登录/结构变动）→ 本会话降级为本地扫描，保证搜索始终可用。
   */
  private async searchServerFetch(reset: boolean): Promise<void> {
    if (this.searchFetching || !this.searchMode || this.searchKeyword.trim().length === 0) {
      return;
    }
    if (!reset && !this.searchServerHasMore) {
      this.searchExhausted = true;
      return;
    }
    this.searchFetching = true;
    const myToken: number = this.searchToken;
    const nextPage: number = reset ? 1 : this.searchServerPage + 1;
    let fellBack: boolean = false;
    try {
      const result: ForumSearchData = await TiebaService.getInstance()
        .searchPostInForum(this.forumName, this.searchKeyword, nextPage, SEARCH_SERVER_PAGE_SIZE);
      if (myToken !== this.searchToken || !this.searchMode) {
        return;
      }
      this.searchServerPage = nextPage;
      this.searchServerHasMore = result.hasMore;
      const appended: ThreadItem[] = [];
      if (reset) {
        this.searchPool = result.list;
        this.searchPoolVersion++;
        appended.push(...result.list);
      } else {
        appended.push(...this.mergeSearchPage(result.list));
      }
      this.searchExhausted = !this.searchServerHasMore;
      if (appended.length > 0) {
        this.enrichInBackground(appended);
        this.enrichSearchDetails(appended);
      }
    } catch (e) {
      if (myToken !== this.searchToken) {
        return;
      }
      if (reset) {
        // 首屏就失败 → 降级本地扫描（保留关键词，立即起扫）
        console.info(`[FSEARCH] server search failed, fallback to local scan: ${(e as Error).message}`);
        this.searchServerMode = false;
        this.searchServerPage = 0;
        this.searchServerHasMore = true;
        this.searchStalled = 0;
        this.searchScannedPages = 0;
        this.searchHasMore = true;
        this.searchPool = this.threads.slice();
        this.searchPoolVersion++;
        this.searchPage = this.selectedSort === SEARCH_SCAN_SORT ? this.page : 0;
        fellBack = true;
      } else {
        // 翻页失败：保留已有结果，停在当前页，用户继续下滑即重试
        console.warn(`[FSEARCH] server page ${nextPage} failed: ${(e as Error).message}`);
      }
    } finally {
      if (myToken === this.searchToken) {
        this.searchFetching = false;
        if (fellBack) {
          this.searchScan(SEARCH_BATCH_RESULTS);
        } else {
          this.maybeAutoContinueSearch();
        }
      }
    }
  }

  /** 单页扫描：失败/无数据返回 null（由调用方按批计停滞，不打断整批） */
  private async fetchSearchPage(pn: number): Promise<ThreadItem[] | null> {
    try {
      const result = await TiebaService.getInstance().fetchForumThreads(this.forumName, pn, SEARCH_SCAN_SORT, false);
      return result.list;
    } catch (e) {
      return null;
    }
  }

  /**
   * 本地扫描（降级路径）：按 SEARCH_CONCURRENCY 并发抓取后续吧内分页，直到匹配数达到 target、
   * 连续 3 批无新增（触底或持续失败）或达到单批/总量页数上限；结果按轮合并、逐轮上屏。
   * 池固定用「热门」序，与当前排序 Tab 无关，也不写列表缓存（避免与 Tab 列表串源）。
   */
  private async searchScan(target: number): Promise<void> {
    if (this.searchFetching || !this.searchMode || this.searchKeyword.trim().length === 0) {
      return;
    }
    if (!this.searchHasMore || this.searchScannedPages >= SEARCH_SCAN_MAX_PAGES) {
      this.searchExhausted = true;
      return;
    }
    this.searchFetching = true;
    const myToken: number = this.searchToken;
    let scanned: number = 0;
    try {
      while (scanned < SEARCH_BATCH_PAGES && this.searchHasMore
        && this.searchScannedPages + scanned < SEARCH_SCAN_MAX_PAGES
        && this.searchThreads().length < target) {
        if (myToken !== this.searchToken || !this.searchMode) {
          return;
        }
        // 本批页码：池尾之后并发 K 页（并行抓取，避免逐页串行白等）
        const pages: number[] = [];
        for (let i = 0; i < SEARCH_CONCURRENCY && scanned < SEARCH_BATCH_PAGES; i++) {
          pages.push(this.searchPage + i + 1);
          scanned++;
        }
        const lists: (ThreadItem[] | null)[] = await Promise.all(
          pages.map((pn: number): Promise<ThreadItem[] | null> => this.fetchSearchPage(pn)));
        if (myToken !== this.searchToken || !this.searchMode) {
          return;
        }
        const appended: ThreadItem[] = [];
        for (const list of lists) {
          if (list !== null && list.length > 0) {
            appended.push(...this.mergeSearchPage(list));
          }
        }
        this.searchPage += pages.length;
        this.searchScannedPages += pages.length;
        // 连续 3 批无新增即认为本吧已扫到底（触底时接口抛"暂无帖子"，与异常同样表现为无新增）
        this.searchStalled = appended.length > 0 ? 0 : this.searchStalled + 1;
        if (this.searchStalled >= 3) {
          this.searchHasMore = false;
        }
        // 新扫描项的昵称后台校准：按批一次，避免逐页堆叠请求
        if (appended.length > 0) {
          this.enrichInBackground(appended);
        }
      }
    } finally {
      if (myToken === this.searchToken) {
        this.searchFetching = false;
        this.searchExhausted = !this.searchHasMore || this.searchScannedPages >= SEARCH_SCAN_MAX_PAGES;
        this.maybeAutoContinueSearch();
      }
    }
  }

  /** 取下一批（按模式分派）：滚动预加载 / 触底兜底 / 自动续载的统一入口 */
  private searchNextBatch(): void {
    if (!this.searchMode || this.searchExhausted || this.searchFetching) {
      return;
    }
    if (this.searchKeyword.trim().length === 0) {
      return;
    }
    if (this.searchServerMode) {
      this.searchServerFetch(false);
    } else {
      this.searchScan(this.searchThreads().length + SEARCH_BATCH_RESULTS);
    }
  }

  /**
   * 自动续载（修复"下滑加载不出来"）：
   * 结果不满一屏时用户根本无法滚动 → onScroll / onReachEnd 都不会触发 → 永远等不到下一批。
   * 故只要「视口没被填满」或「用户就停在结果底部」，就主动补下一批，不必等用户再滑；
   * 用户上滑离开底部后自然停止，因此不会无谓地持续拉取。
   */
  private maybeAutoContinueSearch(): void {
    if (!this.searchMode || this.searchExhausted || this.searchFetching || this.searchAutoTimer !== -1) {
      return;
    }
    if (this.searchKeyword.trim().length === 0 || this.viewportH <= 0) {
      return;
    }
    if (this.searchServerMode && this.searchPool.length >= SEARCH_SERVER_AUTO_MAX) {
      return;   // 已达自动续载上限，后续仅由用户下滑驱动
    }
    const notFilled: boolean = this.contentH <= this.viewportH + 40;
    const remaining: number = this.contentH - this.viewportH - this.lastScrollY;
    const atBottom: boolean = remaining <= THREAD_PREFETCH_DISTANCE;
    if (!notFilled && !atBottom) {
      return;
    }
    const myToken: number = this.searchToken;
    this.searchAutoTimer = setTimeout(() => {
      this.searchAutoTimer = -1;
      if (myToken !== this.searchToken || !this.searchMode) {
        return;
      }
      this.searchNextBatch();
    }, SEARCH_AUTO_CONTINUE_MS);
  }

  /** 把一页吧内结果去重合并进列表并推进分页状态，返回新增条数（吧主页列表翻页专用） */
  private mergePage(nextPage: number, list: ThreadItem[]): number {
    const existing: Set<string> = new Set<string>();
    for (const item of this.threads) {
      existing.add(item.tid);
    }
    const appended: ThreadItem[] = [];
    for (const item of list) {
      if (!existing.has(item.tid)) {
        existing.add(item.tid);
        appended.push(item);
      }
    }
    this.page = nextPage;
    this.threads = this.threads.concat(appended);
    this.stalledPages = appended.length > 0 ? 0 : this.stalledPages + 1;
    this.hasMore = list.length > 0 && this.stalledPages < 3;
    if (appended.length > 0) {
      this.enrichInBackground(appended);
      this.saveForumCache(this.threads);
    }
    return appended.length;
  }

  /** 服务端搜索结果补数据：按 tid 拉详情补齐 authorId/头像/回复数/点赞数 */
  private enrichSearchDetails(list: ThreadItem[]): void {
    if (!this.searchServerMode || list.length === 0) {
      return;
    }
    const myToken: number = this.searchToken;
    const targets: ThreadItem[] = list.filter((t: ThreadItem): boolean =>
      (t.authorId ?? '').length === 0 || (t.authorAvatar ?? '').length === 0);
    if (targets.length === 0) {
      return;
    }
    let cursor: number = 0;
    const worker = async (): Promise<void> => {
      while (cursor < targets.length) {
        const item: ThreadItem = targets[cursor];
        cursor++;
        if (myToken !== this.searchToken || !this.searchMode) {
          return;
        }
        await this.enrichOneSearchItem(item);
      }
    };
    const workers: Promise<void>[] = [];
    const n: number = Math.min(SEARCH_ENRICH_CONCURRENCY, targets.length);
    for (let i = 0; i < n; i++) {
      workers.push(worker());
    }
    Promise.all(workers).catch((): void => {});
  }

  /** 补齐单条：拉详情 → 合并进池；失败保留原样 */
  private async enrichOneSearchItem(item: ThreadItem): Promise<void> {
    try {
      const result: ThreadDetailResult = await TiebaService.getInstance()
        .fetchThreadDetail(item.tid, 1, 0, false, `${item.forumId ?? ''}`, 0);
      const d: ThreadDetail | undefined = result?.detail;
      if (d !== undefined && d !== null) {
        this.applySearchDetail(item.tid, d);
      }
    } catch (e) {
      // 单条失败不影响其它条目
    }
  }

  /** 详情结果合并进搜索池（只补空缺、不降级已有值），以新数组引用触发刷新 */
  private applySearchDetail(tid: string, d: ThreadDetail): void {
    let hit: boolean = false;
    for (const t of this.searchPool) {
      if (t.tid !== tid) {
        continue;
      }
      hit = true;
      if ((t.authorId ?? '').length === 0 && (d.authorId ?? '').length > 0) {
        t.authorId = d.authorId;
      }
      if ((t.authorAvatar ?? '').length === 0 && (d.authorAvatar ?? '').length > 0) {
        t.authorAvatar = d.authorAvatar;
      }
      if (d.author.length > 0 && (t.author.length === 0 || t.author === '贴吧用户')) {
        t.author = d.author;
      }
      if ((t.forumId ?? '').length === 0) {
        t.forumId = d.forumId;
      }
      if ((t.forumAvatar ?? '').length === 0 && (d.forumAvatar ?? '').length > 0) {
        t.forumAvatar = d.forumAvatar;
      }
      t.replyNum = d.replyNum;
      t.likeCount = d.likeCount ?? 0;
      t.isLiked = d.isLiked ?? false;
      if ((t.postId ?? '').length === 0 && (d.postId ?? '').length > 0) {
        t.postId = d.postId;
      }
      if ((t.images ?? []).length === 0 && (d.images ?? []).length > 0) {
        t.images = d.images;
        t.firstImage = d.images[0];
      }
      if ((t.abstract ?? '').length === 0 && d.contentText.length > 0) {
        t.abstract = d.contentText.replace(/\s+/g, ' ').trim().substring(0, 120);
      }
      break;
    }
    if (hit) {
      this.searchPool = this.searchPool.slice();
      this.searchPoolVersion++;
    }
  }

  /** 把一页扫描结果去重并入搜索池，返回新增项 */
  private mergeSearchPage(list: ThreadItem[]): ThreadItem[] {
    const seen: Set<string> = new Set<string>();
  for (const t of this.searchPool) {
      seen.add(t.tid);
    }
    const appended: ThreadItem[] = [];
    for (const t of list) {
      if (!seen.has(t.tid)) {
        seen.add(t.tid);
        appended.push(t);
      }
    }
    if (appended.length === 0) {
      return appended;
    }
    this.searchPool = this.searchPool.concat(appended);
    this.searchPoolVersion++;
    return appended;
  }

  /**
   * 搜索结果：服务端模式直接返回服务端命中（含正文命中，本地再过滤会误删命中）；
   * 本地模式按「标题命中优先、其次摘要（内容）命中」过滤池，带缓存（键 = 关键词 + 池版本）。
   */
  private searchThreads(): ThreadItem[] {
    const kw: string = this.searchKeyword.trim().toLowerCase();
    if (kw.length === 0) {
      return [];
    }
    if (this.searchServerMode) {
      return this.searchPool;
    }
    const key: string = `${kw}|${this.searchPoolVersion}`;
    if (key === this.searchCacheKey) {
      return this.searchCacheResult;
    }
    const titleHit: ThreadItem[] = [];
    const contentHit: ThreadItem[] = [];
    for (const t of this.searchPool) {
      if (t.title.toLowerCase().includes(kw)) {
        titleHit.push(t);
      } else if ((t.abstract ?? '').toLowerCase().includes(kw)) {
        contentHit.push(t);
      }
    }
    const result: ThreadItem[] = titleHit.concat(contentHit);
    this.searchCacheKey = key;
    this.searchCacheResult = result;
    return result;
  }

  /** 搜索进度文案：让"找到多少、扫了多少"可见，避免被误认为卡住 */
  private searchStatusText(): string {
    const found: number = this.searchThreads().length;
    if (this.searchServerMode) {
      if (this.searchFetching) {
        return `正在搜索本吧… 已找到 ${found} 条`;
      }
      if (this.searchExhausted) {
        return `已找到 ${found} 条 · 已到结果末尾`;
      }
      return `已找到 ${found} 条 · 下滑加载更多`;
    }
    const scanned: number = this.searchPool.length;
    if (this.searchFetching) {
      return `正在扫描本吧… 已找到 ${found} 条 · 已扫描 ${scanned} 帖`;
    }
    if (this.searchExhausted) {
      return this.searchScannedPages >= SEARCH_SCAN_MAX_PAGES
        ? `已找到 ${found} 条 · 已扫描 ${scanned} 帖（本吧帖量过大，已停止扫描）`
        : `已找到 ${found} 条 · 已搜索本吧全部 ${scanned} 帖`;
    }
    return `已找到 ${found} 条 · 下滑继续搜索`;
  }

  /** 无结果时的补充说明（区分服务端无命中 / 本地扫到底 / 扫到上限） */
  private searchEmptyHint(): string {
    if (this.searchServerMode) {
      return '本吧没有匹配的帖子';
    }
    if (this.searchScannedPages >= SEARCH_SCAN_MAX_PAGES) {
      return `已扫描 ${this.searchPool.length} 帖仍未找到匹配`;
    }
    return `已搜索本吧全部 ${this.searchPool.length} 帖`;
  }

  /** 结果列表底部文案（有结果但已取完，与服务端"无命中"区分开） */
  private searchFooterEndText(): string {
    if (this.searchServerMode) {
      return '已到结果末尾';
    }
    return this.searchScannedPages >= SEARCH_SCAN_MAX_PAGES
      ? `已扫描 ${this.searchPool.length} 帖（本吧帖量过大，已停止扫描）`
      : `已搜索本吧全部 ${this.searchPool.length} 帖`;
  }

  private openForum(forumName: string, forumId: string = ''): void {
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/ThreadList',
      params: { kw: forumName, forumName: forumName, fid: forumId }
    }).catch(() => {
      this.getUIContext().getPromptAction().showToast({ message: '贴吧打开失败，请稍后重试' });
    });
  }

  private formatNumber(num: number): string {
    if (num >= 10000) {
      return (num / 10000).toFixed(1).replace('.0', '') + 'W';
    }
    if (num >= 1000) {
      return (num / 1000).toFixed(1).replace('.0', '') + 'K';
    }
    return `${num}`;
  }

  /** 指定排序的列表缓存 key（省略 sort 时取当前选中排序；预热其它排序时显式传入） */
  private forumCacheKey(sort?: number): string {
    const s: number = sort === undefined ? this.selectedSort : sort;
    return `${CACHE_KEY.FORUM_LIST}_${this.forumName}_${s}`;
  }

  /**
   * threads 更新时同步页内会话快照（@Watch）：空数组/骨架屏期不覆盖，
   * 保留最近一份完整数据，使切回该排序可 0 开销直出。
   */
  private onThreadsChanged(): void {
    if (this.threads.length === 0) {
      return;
    }
    this.sortSession.set(this.selectedSort, {
      threads: this.threads,
      page: this.page,
      hasMore: this.hasMore,
      ts: Date.now(),
    });
  }

  /**
   * 骨架屏→内容交叉淡入淡出（方案A）：
   * animateTo 内同时让内容 0→1、骨架屏 1→0；动画结束后再把 loadState 落定到 target，
   * 使骨架屏分支移除时已完全透明，消除"骨架屏瞬间消失+内容瞬间整体出现"的生硬感。
   * target 用于区分 Success / Empty（空吧）。
   * 已淡入完成（缓存秒开/静默刷新/排序切换）时直接落定目标态，避免重复动画。
   */
  private fadeInContent(target: LoadState = LoadState.Success): void {
    if (this.contentOpacity >= 1) {
      if (this.loadState === LoadState.Loading) {
        this.loadState = target;
      }
      return;
    }
    animateTo({ duration: 250, curve: Curve.EaseInOut }, () => {
      this.contentOpacity = 1;
      this.skeletonOpacity = 0;
    });
    setTimeout(() => {
      if (this.loadState === LoadState.Loading) {
        this.loadState = target;
      }
    }, 260);
  }

  /**
   * 收口排序过场：清掉收口定时器 → 位移归零 → 释放旧页快照。
   * 快速连切时先调用（上一次动画可能正跑到一半），复位后再由 `applySortDisplay` 摆新起点。
   */
  private clearSortSettle(): void {
    if (this.sortSettleTimer !== -1) {
      clearTimeout(this.sortSettleTimer);
      this.sortSettleTimer = -1;
    }
    this.inOffset = 0;
    this.outOffset = 0;
    this.exitSnapshot = null;
    this.exitClipTop = 0;
  }

  /**
   * 注册过场收口：动画播完后卸载旧页快照并复位位移。
   * （`animateTo` 无结束回调，与首页 `switchTab` 一样用定时器兜底；时长取动画的约 1.3 倍，
   *   让弹簧末段的回弹也播完再收，避免旧页被提前抽走。）
   */
  private scheduleSortSettle(): void {
    if (this.sortSettleTimer !== -1) {
      clearTimeout(this.sortSettleTimer);
    }
    this.sortSettleTimer = setTimeout(() => {
      this.sortSettleTimer = -1;
      this.inOffset = 0;
      this.outOffset = 0;
      this.exitSnapshot = null;
      this.exitClipTop = 0;
    }, SORT_ANIM_SETTLE);
  }

  /**
   * 截取旧页：把当前屏幕上的**列表区**（旧排序的内容 + 它的滚动位置）同步截成 PixelMap，供过场里滑出的那一层使用。
   *
   * 用 `getSync` 是刻意的：异步版要等回调，而页内快照是**同步命中**的 —— 异步截图赶不上同一帧起滑，
   * 旧页会在动画中途才冒出来（闪一下，比不做更糟）。同步截图取的是上一帧已渲染的成品，
   * 不触发重新布局、不改动任何几何，耗时在点击这一帧内消化。
   *
   * 裁剪（2026-09-12）：位移只作用于列表区、吧头是静止的，若旧页快照仍带着吧头，旧页滑出时吧头会跟着滑。
   * 故按 `SnapshotOptions.region` 把吧头顶部裁掉 —— 边界 y = 「顶栏让位 + 吧头块高 − 当前滚动偏移」，
   * 即吧头块底边在 Scroll 视口里的位置；快照层再按同一个值下移，正好落在列表区上（见旧页 Image 层）。
   * 该值 ≤ 0（吧头已滚出屏幕上方）或吧头高尚未测到 → 不裁，整屏即列表内容，与调整前行为一致。
   * region 的四个值单位是 **px**（vp2px），且取值必须落在组件矩形内，故对宽高做了保护。
   *
   * 失败（组件未就绪 / 平台不支持）时静默降级为 null —— 过场退化成"只有新页滑入"，功能不受影响。
   */
  private captureExitSnapshot(): void {
    // 裁剪边界：吧头块底边在 Scroll 视口里的 y（vp）。吧头高未测到时不裁，避免旧页内容整体错位
    const listTop: number = THREAD_LIST_HEADER_TOP_SPACE + this.headerBlockH
      - this.listScroller.currentOffset().yOffset;
    const clipTop: number = (this.headerBlockH > 0 && this.viewportH > 0)
      ? Math.max(0, Math.min(listTop, this.viewportH)) : 0;
    this.exitClipTop = clipTop;
    try {
      if (clipTop > 0 && this.viewportW > 0) {
        const ui = this.getUIContext();
        // region 四边均为 px，且必须落在 [0, 组件宽/高] 区间内（否则截图报错）
        const region: componentSnapshot.SnapshotRegion = {
          left: 0,
          top: ui.vp2px(clipTop),
          right: ui.vp2px(this.viewportW),
          bottom: ui.vp2px(this.viewportH)
        };
        const options: componentSnapshot.SnapshotOptions = { region: region };
        this.exitSnapshot = componentSnapshot.getSync(THREAD_SCROLL_SNAPSHOT_ID, options);
        console.info(`[SORT] exit snapshot captured clipTop=${clipTop} headerH=${this.headerBlockH}`);
      } else {
        // 吧头不在屏内（或尚未测到）：整屏都是列表内容，无需裁剪
        this.exitSnapshot = componentSnapshot.getSync(THREAD_SCROLL_SNAPSHOT_ID);
        console.info(`[SORT] exit snapshot captured (full) clipTop=${clipTop} headerH=${this.headerBlockH}`);
      }
    } catch (e) {
      // 截图不可用（组件未就绪 / 平台限制）：降级为"只有新页滑入"，并在日志里留下线索
      this.exitSnapshot = null;
      console.warn(`[SORT] exit snapshot failed: ${(e as BusinessError).message ?? e}`);
    }
  }

  /**
   * 排序数据上屏（唯一入口）：**同一帧**完成「替换数据 + 回顶 + 双页对向起滑」。
   *
   * 与首页 `switchTab` 逐项同款：新页先无动画摆到对侧（`inOffset = dir * 100`）、旧页快照摆在
   * 原位（`outOffset = 0`），紧接着在同一个调用栈里 `animateTo` —— 新页归零、旧页跑到反侧，
   * 两页在同一段时间里对向平移、屏幕上始终相接，这就是"两个界面仿佛连着"的观感来源。
   * 位移只作用在「列表区」这一层（吧头、顶栏、底栏静止），旧页来自 `captureExitSnapshot`
   * （点击那一刻的列表区），所以它的内容与滚动位置天然正确。
   *
   * 未命中缓存（`state = Loading`）时改落骨架屏：不走双页过场（半透明骨架块与旧页叠映反而脏），
   * 直接收口过场 + 骨架屏轻淡入，等网络返回再走双页过场。
   * 换排序 = 换内容集，列表同步无动画回顶（保留旧偏移对新排序没有意义）。
   */
  private applySortDisplay(d: SortDisplay): void {
    // 竞态：数据归属的排序已不是当前排序（快速连点），丢弃
    if (d.sort !== this.selectedSort) {
      return;
    }
    this.page = d.page;
    this.hasMore = d.hasMore;
    if (d.state === LoadState.Loading) {
      // 未命中缓存：收口过场（旧页不再需要）+ 骨架屏轻淡入，等网络返回再对向平移
      this.clearSortSettle();
      this.threads = [];
      this.loadState = LoadState.Loading;
      this.contentOpacity = 0;
      this.getUIContext().animateTo({ duration: SORT_SKELETON_FADE, curve: Curve.EaseOut }, () => {
        this.skeletonOpacity = 1;
      });
      return;
    }
    const dir: number = this.enterDir !== 0 ? this.enterDir : 1;
    this.enterDir = 0;
    this.threads = d.threads;
    this.loadState = d.state;
    this.listScroller.scrollTo({ xOffset: 0, yOffset: 0 });
    // 起点态（无动画赋值）：新页在对侧整屏外、旧页快照留原位待退场 —— 与首页 switchTab 写法一致
    this.inOffset = dir * 100;
    this.outOffset = 0;
    this.contentOpacity = 1;
    this.sortAnimUntil = Date.now() + SORT_ANIM_SETTLE;
    this.getUIContext().animateTo({ duration: SORT_ANIM_DURATION, curve: curves.springMotion(0.72, 0.86) }, () => {
      this.inOffset = 0;
      this.outOffset = -dir * 100;
      this.skeletonOpacity = 0;
    });
    // 动画收口：卸载旧页快照 + 复位位移（快速连切时会被下一次切换先行清掉）
    this.scheduleSortSettle();
  }

  /**
   * 吧列表加载：stale-while-revalidate 秒开——本地快照（5 分钟新鲜度）无论是否过期都先显示，
   * 后台静默刷新保持数据新鲜；无缓存时网络请求后立即渲染，昵称校准全部后台不阻塞首屏。
   */
  async loadThreads(forceRefresh: boolean = false): Promise<void> {
    // 请求代际递增：使 in-flight 的加载更多结果作废，避免 concat 到重置后的新列表（刷新/排序切换）
    const myToken: number = ++this.loadToken;
    // 快照本次请求的排序：期间用户切换排序会再次触发 loadThreads（代际已变），返回时据此丢弃过期结果
    const mySort: number = this.selectedSort;
    if (!forceRefresh && this.page === 1) {
      // 页内会话快照命中（本次进吧期间刚看过该排序）：0 开销秒开，数据足够新不做后台刷新
      const session = this.sortSession.get(this.selectedSort);
      if (session && session.threads.length > 0 && Date.now() - session.ts < SORT_SESSION_TTL) {
        this.stalledPages = 0;
        if (this.enterDir !== 0) {
          // 排序切换命中页内快照（快照命中在本 async 函数的第一段、同步执行）：同帧替换 + 起滑
          this.applySortDisplay({
            sort: this.selectedSort, threads: session.threads,
            page: session.page, hasMore: session.hasMore, state: LoadState.Success,
          });
        } else {
          this.threads = session.threads;
          this.page = session.page;
          this.hasMore = session.hasMore;
          this.loadState = LoadState.Success;
          // 首次进入/重试且透明度尚未就绪时平滑淡入（已就绪则 fadeInContent 直接落定，无副作用）
          this.fadeInContent(LoadState.Success);
        }
        return;
      }
      try {
        // 与首页推荐流同构：过期缓存也返回（stale-while-revalidate），保证任何时刻重进该吧都秒开
        const cached = await CacheManager.getInstance().getWithTtlAllowStale<ForumListCache>(this.forumCacheKey());
        if (cached && cached.data.threads.length > 0) {
          if (cached.data.forumInfo) {
            this.forumInfo = cached.data.forumInfo;
          }
          this.hasMore = true;
          this.stalledPages = 0;
          // 命中缓存（含过期 TTL）：秒开显示，后台静默刷新保持数据新鲜；刷新失败保留旧内容
          this.refreshSilently();
          if (this.enterDir !== 0) {
            // 排序切换命中本地缓存：同帧替换 + 起滑（与首页 Tab 切换同一形态）
            this.applySortDisplay({
              sort: this.selectedSort, threads: cached.data.threads,
              page: this.page, hasMore: true, state: LoadState.Success,
            });
          } else {
            this.threads = cached.data.threads;
            this.loadState = LoadState.Success;
            // 内容淡入（首次进入时 contentOpacity=0 → 平滑淡入）
            this.fadeInContent(LoadState.Success);
          }
          // 首次成功展示后后台预热其它两个排序，使后续切换首次即命中缓存（一次性，失败静默）
          this.warmupSortCaches();
          return;
        }
      } catch (_) {
        // 缓存读取失败则走正常网络加载
      }
    }
    if (this.enterDir !== 0) {
      // 排序切换未命中缓存：落骨架屏（轻淡入）等网络返回，返回后由 applySortDisplay 滑入
      this.applySortDisplay({
        sort: this.selectedSort, threads: [], page: this.page, hasMore: true, state: LoadState.Loading,
      });
    } else {
      this.loadState = LoadState.Loading;
      // 首次进入/重试：复位可能残留的过场位移与旧页快照，骨架屏从正确位置出现
      this.inOffset = 0;
      this.outOffset = 0;
      this.exitSnapshot = null;
      // 每次加载重置过渡透明度：骨架屏覆盖、内容透明，等待淡入
      this.contentOpacity = 0.0;
      this.skeletonOpacity = 1.0;
    }
    try {
      const result = await TiebaService.getInstance().fetchForumThreads(this.forumName, this.page, this.selectedSort, false);
      // 竞态防护：请求期间用户已切换排序/刷新，丢弃晚归结果，避免旧排序内容覆盖当前列表
      if (myToken !== this.loadToken || mySort !== this.selectedSort) {
        return;
      }
      this.stalledPages = 0;
      if (this.enterDir !== 0) {
        // 排序切换（未命中缓存）：网络返回后同帧替换 + 起滑
        this.applySortDisplay({
          sort: this.selectedSort, threads: result.list, page: this.page,
          hasMore: result.list.length > 0,
          state: result.list.length > 0 ? LoadState.Success : LoadState.Empty,
        });
      } else {
        this.threads = result.list;
        this.hasMore = result.list.length > 0;
        // 不直接切走 Loading：先让骨架屏淡出，动画结束后由 fadeInContent 落定目标态
        this.fadeInContent(result.list.length > 0 ? LoadState.Success : LoadState.Empty);
      }
      // 首次成功展示后后台预热其它两个排序，使后续切换首次即命中缓存（一次性，失败静默）
      this.warmupSortCaches();
      const header = TiebaService.getInstance().getCachedForumHeader();
      if (header) {
        this.forumInfo = header;
      }
      // 昵称后台校准，不阻塞首屏渲染
      if (result.list.length > 0) {
        this.enrichInBackground(result.list);
      }
      if (this.page === 1 && result.list.length > 0) {
        this.saveForumCache(result.list);
      }
      // Auto-load more if content is too short to fill the screen
      if (this.hasMore && result.list.length > 0 && result.list.length < 8) {
        this.autoLoadMore();
      }
    } catch (e) {
      // 失败也要收口过场：否则新页会停在侧偏位置，错误页跟着歪在一边
      this.enterDir = 0;
      this.clearSortSettle();
      this.contentOpacity = 1;
      this.loadState = LoadState.Error;
      this.errorMsg = (e as Error).message ?? '加载失败';
    }
  }

  /** 缓存命中后的后台静默刷新：更新列表与吧头，成功后回写缓存 */
  private refreshSilently(): void {
    // 竞态防护：静默刷新期间用户可能已切换排序/刷新（代际/排序变化），返回后丢弃过期结果
    const myToken: number = this.loadToken;
    const mySort: number = this.selectedSort;
    TiebaService.getInstance().fetchForumThreads(this.forumName, 1, this.selectedSort, false).then((result) => {
      if (myToken !== this.loadToken || mySort !== this.selectedSort || result.list.length === 0) {
        return;
      }
      // 排序切换的过场窗口内（`SORT_ANIM_SETTLE` ≈ 420ms）：只回写缓存、不上屏 ——
      // 否则两页对向平移的途中列表内容会被静默刷新整块替换，出现"滑到一半内容变了"的跳变。
      // 丢弃的这次上屏由下一次切换 / 下拉刷新补上，缓存不受影响。
      if (this.enterDir !== 0 || Date.now() < this.sortAnimUntil) {
        this.saveForumCache(result.list);
        return;
      }
      this.page = 1;
      this.threads = result.list;
      this.hasMore = result.list.length > 0;
      this.stalledPages = 0;
      const header = TiebaService.getInstance().getCachedForumHeader();
      if (header) {
        this.forumInfo = header;
      }
      this.enrichInBackground(result.list);
      this.saveForumCache(result.list);
    }).catch((e: Error) => {
      // 静默刷新失败保留缓存内容展示，仅记录日志
      console.info(`[ThreadList] silent refresh fail: ${e.message}`);
    });
  }

  /** 后台昵称校准：拉取 profile 确认昵称后按 authorId 局部替换，不阻塞首屏 */
  private enrichInBackground(list: ThreadItem[]): void {
    // 竞态防护：昵称校准返回后若已切换排序/刷新，跳过 diff，避免昵称 map 串台到其它排序列表
    const myToken: number = this.loadToken;
    const mySort: number = this.selectedSort;
    TiebaService.getInstance().enrichHomeAuthors(list).then((enriched: ThreadItem[]) => {
      if (myToken === this.loadToken && mySort === this.selectedSort) {
        this.applyEnrichedAuthors(enriched);
      }
    }).catch((_: Error) => {
      // 校准失败保留接口昵称，不影响列表展示
    });
  }

  /** 将校准结果按 authorId diff 更新到当前列表与搜索池（兼容校准期间已加载更多） */
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
    const updatedThreads: ThreadItem[] = this.remapAuthorNames(this.threads, nameMap);
    if (updatedThreads !== this.threads) {
      this.threads = updatedThreads;
    }
    // 搜索池内的条目同样需要校准（池独立于列表，否则搜索结果会保留占位昵称）
    if (this.searchMode) {
      const updatedPool: ThreadItem[] = this.remapAuthorNames(this.searchPool, nameMap);
      if (updatedPool !== this.searchPool) {
        this.searchPool = updatedPool;
        this.searchPoolVersion++;
      }
    }
  }

  /** 按 authorId → 昵称 映射重写一组帖子的昵称；无变化时原样返回（列表与搜索池共用） */
  private remapAuthorNames(list: ThreadItem[], nameMap: Map<string, string>): ThreadItem[] {
    let changed: boolean = false;
    const updated: ThreadItem[] = list.map((t: ThreadItem): ThreadItem => {
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
    return changed ? updated : list;
  }

  /** 写入吧列表快照缓存（含吧头信息），失败不影响功能 */
  private async saveForumCache(list: ThreadItem[]): Promise<void> {
    try {
      await CacheManager.getInstance().putWithTtl<ForumListCache>(
        this.forumCacheKey(),
        { threads: list, forumInfo: this.forumInfo },
        CACHE_TTL.FORUM_LIST
      );
    } catch (_) {
      // 缓存写入失败可忽略
    }
  }

  /**
   * 排序冷缓存预热：首次成功展示后，把其它两个排序（最新/精选）提前拉好写入本地缓存，
   * 使后续首次切换直接命中缓存秒开。已有新鲜缓存（5 分钟内）则跳过，不重复消耗流量。
   * 纯后台执行，失败静默；warmupStarted 保证每次进吧只跑一轮。
   */
  private async warmupSortCaches(): Promise<void> {
    if (this.warmupStarted) {
      return;
    }
    this.warmupStarted = true;
    for (const sort of [0, 1, 2]) {
      if (sort === this.selectedSort) {
        continue;
      }
      try {
        const cached = await CacheManager.getInstance().getWithTtlAllowStale<ForumListCache>(this.forumCacheKey(sort));
        if (cached && !cached.expired && cached.data.threads.length > 0) {
          continue;
        }
      } catch (_) {
        // 缓存检查失败照常尝试预热
      }
      this.warmupSort(sort);
    }
  }

  /** 单个排序的预热请求：拉取首屏并写本地缓存，失败不影响主流程 */
  private async warmupSort(sort: number): Promise<void> {
    try {
      const result = await TiebaService.getInstance().fetchForumThreads(this.forumName, 1, sort, false);
      if (result.list.length === 0) {
        return;
      }
      await CacheManager.getInstance().putWithTtl<ForumListCache>(
        this.forumCacheKey(sort),
        { threads: result.list, forumInfo: this.forumInfo },
        CACHE_TTL.FORUM_LIST
      );
      console.info(`[ThreadList] warmup sort=${sort} n=${result.list.length}`);
    } catch (e) {
      console.info(`[ThreadList] warmup sort=${sort} fail: ${(e as Error).message}`);
    }
  }

  async loadMore(silent: boolean = false): Promise<void> {
    if (this.loadingMore || !this.hasMore) {
      return;
    }
    this.loadingMore = true;
    // 记录当前代际：返回时若已刷新/切换排序则丢弃结果
    const myToken: number = this.loadToken;
    try {
      const nextPage = this.page + 1;
      const result = await TiebaService.getInstance().fetchForumThreads(this.forumName, nextPage, this.selectedSort, false);
      if (myToken !== this.loadToken) {
        return;
      }
      // 去重合并 + 推进分页状态
      this.mergePage(nextPage, result.list);
    } catch (e) {
      // 预加载失败静默忽略，靠 onReachEnd 兜底重试；仅用户主动触底时提示
      if (!silent) {
        this.getUIContext().getPromptAction().showToast({ message: '加载更多失败，请稍后重试' });
      }
    } finally {
      this.loadingMore = false;
    }
  }

  // Auto-load without the loadingMore guard for pre-fetching short content
  private async autoLoadMore(): Promise<void> {
    // 竞态防护：自动补页期间用户可能已切换排序/刷新，快照代际+排序，每轮返回校验，不符即停
    const myToken: number = this.loadToken;
    const mySort: number = this.selectedSort;
    // Loop to fetch multiple pages until we have enough content or no more data
    while (this.hasMore && this.threads.length < 8) {
      this.loadingMore = true;
      try {
        const nextPage = this.page + 1;
        const result = await TiebaService.getInstance().fetchForumThreads(this.forumName, nextPage, this.selectedSort, false);
        if (myToken !== this.loadToken || mySort !== this.selectedSort) {
          return;
        }
        const existing: Set<string> = new Set<string>();
        for (const item of this.threads) {
          existing.add(item.tid);
        }
        const appended: ThreadItem[] = [];
        for (const item of result.list) {
          if (!existing.has(item.tid)) {
            existing.add(item.tid);
            appended.push(item);
          }
        }
        this.page = nextPage;
        this.threads = this.threads.concat(appended);
        this.stalledPages = appended.length > 0 ? 0 : this.stalledPages + 1;
        this.hasMore = result.list.length > 0 && this.stalledPages < 3;
        // 自动补页追加项的昵称后台校准
        if (appended.length > 0) {
          this.enrichInBackground(appended);
        }
      } catch (e) {
        break; // Stop auto-loading on error
      } finally {
        this.loadingMore = false;
      }
    }
  }

  /**
   * 吧主页预加载：滚动剩余距离 < 阈值时提前静默加载下一页，实现触底无缝续流。
   * 搜索态下改为"接近结果末尾即续扫下一批吧内分页"（批量补扫，不再等触底才挤出一条）。
   * loadingMore / searchFetching 锁 + 偏移节流防重；onReachEnd 保留作兜底。
   */
  private onListScroll(_x: number, y: number): void {
    this.lastScrollY = y;
    const remaining: number = this.contentH - this.viewportH - y;
    if (this.searchMode) {
      // 搜索态与列表态解耦：不依赖吧内列表的 loadState（列表可能尚未加载完就进了搜索），
      // 且按模式分派（服务端翻页 / 本地续扫），接近结果末尾即提前取下一批
      if (remaining <= THREAD_PREFETCH_DISTANCE && Math.abs(y - this.lastPrefetchY) >= 120) {
        this.lastPrefetchY = y;
        this.searchNextBatch();
      }
      return;
    }
    if (this.loadState !== LoadState.Success) {
      return;
    }
    if (this.loadingMore || !this.hasMore) {
      return;
    }
    if (remaining > THREAD_PREFETCH_DISTANCE) {
      return;
    }
    // 节流：偏移变化超过 120vp 才允许再次触发，避免同一轮滚动连续请求
    if (Math.abs(y - this.lastPrefetchY) < 120) {
      return;
    }
    this.lastPrefetchY = y;
    this.loadMore(true);
  }

  /** 内容尺寸变化：记录内容高；搜索态下内容变化即重判自动续载（结果不满一屏时无法滚动） */
  private onContentAreaChange(_old: Area, n: Area): void {
    this.contentH = n.height as number;
    if (this.searchMode) {
      this.maybeAutoContinueSearch();
    }
  }

  /** 视口尺寸变化：记录视口高 / 宽（宽供旧页快照 region 裁剪用）；搜索态下同时补一次自动续载判定 */
  private onViewportAreaChange(_old: Area, n: Area): void {
    this.viewportH = n.height as number;
    this.viewportW = n.width as number;
    if (this.searchMode) {
      this.maybeAutoContinueSearch();
    }
  }

  /**
   * 右下角悬浮按钮（只剩「发帖」加号）显隐系数：搜索态整体隐去，退出搜索回到吧主页时复原。
   * 用系数而非条件渲染，配合 .animation 做淡出 + 下沉 + 缩小过渡；
   * 隐藏时命中模式设为 None，避免不可见按钮仍拦截搜索结果的滑动/点击。
   */
  private fabReveal(): number {
    return this.searchMode ? 0 : 1;
  }

  /**
   * 本吧搜索态进出转场（吧头区 / 列表区 / 结果区 / 顶栏共用）：
   * 出现时自 (offsetX, offsetY) 处滑入 + 淡入，消失时反向滑出 + 淡出。
   * 用不对称时长——出现 240ms FastOutSlowIn（收尾稳），消失 180ms EaseIn（起步快）——
   * 避免两态直切造成的生硬割裂；offsetY 取负表现为「向上轻收/自上方落下」，取正为「自下方浮起/下沉」。
   */
  private searchSwap(offsetX: number, offsetY: number): TransitionEffect {
    const off: TranslateOptions = { x: offsetX, y: offsetY };
    const appear: TransitionEffect = TransitionEffect.opacity(0)
      .combine(TransitionEffect.translate(off))
      .animation({ duration: 240, curve: Curve.FastOutSlowIn });
    const disappear: TransitionEffect = TransitionEffect.opacity(0)
      .combine(TransitionEffect.translate(off))
      .animation({ duration: 180, curve: Curve.EaseIn });
    return TransitionEffect.asymmetric(appear, disappear);
  }

  /**
   * 「更多」操作面板控制器（系统 CustomDialog + API 26 沉浸光感）。
   * 几何对齐改造前的自绘浮层：宽度 dialogCardWidth()、圆角 32vp、底部锚点（Bottom + dy -30，
   * 对应原卡片 margin bottom 30 的悬浮基线）、遮罩 #06000000；卡内文案 / 字号 / 按钮尺寸全部原样保留。
   * 玻璃层交给 options.systemMaterial（ImmMaterial.dialog()）—— 材质会接管容器的背景色 /
   * 背景模糊 / 边框 / 阴影，故卡内不再自绘那四项。
   * ⚠️ customStyle 必须为 false —— customStyle=true 时弹窗背景强制透明、圆角归 0 且材质不生效。
   */
  private moreSheetController: CustomDialogController = new CustomDialogController({
    builder: ForumMoreDialogCard({
      isDark: $isDark,
      fontScale: $fontScale,
      forumName: $forumName,
      liked: $moreSheetLiked,
      onShare: () => { this.closeMoreSheet(); this.shareForum(); },
      onToggleFollow: () => { this.closeMoreSheet(); this.handleForumFollow(); },
      onDismiss: () => { this.closeMoreSheet(); }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Bottom,
    offset: { dx: 0, dy: -30 },
    maskColor: '#06000000',
    cornerRadius: 32,
    // 弹窗宽度：Dimension 不接受 'calc(100% - 48vp)' 字符串，故按屏幕宽换算成数值 vp
    width: this.dialogCardWidth(),
    customStyle: false,
    systemMaterial: ImmMaterial.dialog(),
    openAnimation: { duration: 220, curve: Curve.EaseOut },
    closeAnimation: { duration: 200, curve: Curve.EaseInOut },
    // 点遮罩 / 返回键统一走 closeMoreSheet（与自绘浮层时期「点蒙层关闭」语义一致）
    onWillDismiss: () => { this.closeMoreSheet(); }
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
    return Math.max(200, widthVp - 48);
  }

  /** showMoreSheet 变化即驱动系统弹窗 open/close（既有 `this.showMoreSheet = x` 调用点零改动） */
  onShowMoreChanged(): void {
    if (this.showMoreSheet) {
      // 打开瞬间同步展示快照（可空对象 forumInfo 不能直接 @Link 进 @CustomDialog）
      this.moreSheetLiked = this.forumInfo?.isLike === true;
      this.moreSheetController.open();
    } else {
      this.moreSheetController.close();
    }
  }

  /** 关闭「更多」操作面板（唯一出口：卡片内回调 / 点遮罩 / 返回键） */
  private closeMoreSheet(): void {
    this.showMoreSheet = false;
  }

  /**
   * 页面主体层（原 build() 根 Stack）：官方槽位路径 / 兜底路径共用。
   * 内层 = 列表 + 悬浮顶栏（槽位路径下改挂 ThreadTitleBar），外层 BottomEnd Stack = 悬浮 FAB
   * （槽位路径下改挂 FabSlotShell）与「更多」面板。
   */
  @Builder
  ThreadListContent() {
    Stack({ alignContent: Alignment.BottomEnd }) {
    Stack({ alignContent: Alignment.TopStart }) {
      // 排序切换过场·旧页层（对应首页 switchTab 的"退场页"）：点击那一刻同步截下的**列表区**内容，
      // 在新页滑入的同时向反侧整屏滑出 —— 两页相接移动，即"两个界面仿佛连着"的来源。
      // 快照已按吧头底边裁过（见 captureExitSnapshot），故这里下移 exitClipTop、高度收到列表区，
      // 与同样只含列表区的新页严格对齐；吧头在这层上方静止不动。
      // 收口（SORT_ANIM_SETTLE）后卸载；首次加载、未命中缓存、搜索态或截图失败时该层不存在（自动降级）。
      if (this.exitSnapshot !== null) {
        Image(this.exitSnapshot)
          .width('100%')
          // 高 = 视口高 − 裁剪量（未裁时即整屏高），与快照像素 1:1
          .height(Math.max(0, this.viewportH - this.exitClipTop))
          // 截图与展示区同尺寸，Cover 在此等价 1:1 铺满，不会变形
          .objectFit(ImageFit.Cover)
          // y 落到列表区顶边（水平位移才是过场：百分比相对自身宽 = 屏宽）
          .translate({ x: `${this.outOffset}%`, y: this.exitClipTop })
          .hitTestBehavior(HitTestMode.None)
      }
      // 新页（当前内容）：位移与旧页层对向，见 Scroll 链上的 translate
      Scroll(this.listScroller) {
        Column() {
          // 预留顶栏高度作为初始间距（与旧页快照的裁剪边界同源，见 THREAD_LIST_HEADER_TOP_SPACE）
          Column().width('100%').height(THREAD_LIST_HEADER_TOP_SPACE)

          // 本吧本地搜索态：隐藏吧头/排序 Tab，仅显示搜索结果
          // 转场：进入搜索向上轻收淡出、退出搜索自上方落下淡入（与下方结果区反向，形成"换场"层次）
          if (!this.searchMode) {
            Column() {
              this.ForumHeaderBuilder()

              // 排序栏在槽位路径下已搬到屏幕底部（SortSlotShell），内容区不再重复一份；
              // 仅兜底路径（低版本 / 无材质 / 开关关闭）沿用改造前的自绘真模糊胶囊
              if (!(THREAD_LIST_OFFICIAL_SORT_BAR && this.materialSupported)) {
                this.SortTabsBuilder()
              }
            }
            .width('100%')
            // 回填吧头块实测高（吧头 + 兜底排序栏）：旧页快照的裁剪边界由它推出（见 captureExitSnapshot）。
            // 只在布局变化时回调；用普通字段而非 @State，避免测量本身触发重建
            .onAreaChange((_old: Area, n: Area) => { this.headerBlockH = n.height as number; })
            .transition(this.searchSwap(0, -16))
          }

          // 帖子列表 / 本吧搜索结果：两态交叉转场（结果区自下方浮起，列表区向上轻收）
          if (this.searchMode) {
            Column() {
              this.SearchResultsBuilder()
            }
            .width('100%')
            .transition(this.searchSwap(0, 24))
          } else {
            // 列表区 Stack：内容层与骨架屏层共存，实现交叉淡入淡出
            Stack({ alignContent: Alignment.TopStart }) {
              // 内容层：Success/Empty 挂载，由 fadeInContent 控制淡入（0→1）
              if (this.loadState === LoadState.Empty) {
                EmptyView({ message: '该吧暂无帖子', icon: '📭' })
                  .height(200)
                  .opacity(this.contentOpacity)
              } else if (this.loadState === LoadState.Success) {
            // 统一容器：所有卡片共享同一水平边距，保证完美对齐
            Column({ space: 6 }) {
              // 置顶/精品帖子区域
              if (this.pinnedThreads().length > 0) {
                Column({ space: 0 }) {
                  // 置顶标签
                  Row() {
                    Text('置顶')
                      .fontSize(fs(13, this.fontScale))
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Theme.textPrimary(this.isDark))
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 14, bottom: 4 })

                  ForEach(this.pinnedThreads(), (item: ThreadItem) => {
                    PinnedThreadItem({
                      item: {
                        tid: item.tid, title: item.title, forumName: item.forumName,
                        author: item.author, replyNum: item.replyNum, abstract: item.abstract,
                        firstImage: item.firstImage ?? '', createTime: item.createTime,
                        isTop: item.isTop, isGood: item.isGood,
                      } as ThreadItemData,
                      onTap: (tid: string) => this.openThread(tid)
                    })
                  }, (item: ThreadItem) => `${item.tid}_${item.author}_${item.isLiked ? 1 : 0}_${item.likeCount ?? 0}`)
                }
                .width('100%')
                .backgroundColor(Theme.bgCard(this.isDark))
                // 卡片圆角 26：与首页 ThreadCard、详情页卡片、其余列表页卡片统一口径
                .borderRadius(26)
              }

              // 普通帖子区域（ThreadCard自带背景和圆角）
              ForEach(this.normalThreads(), (item: ThreadItem) => {
                ThreadCard({
                  item: {
                    tid: item.tid, postId: item.postId ?? '',
                    title: item.title, forumName: item.forumName,
                    forumAvatar: item.forumAvatar ?? '',
                    author: item.author,
                    authorAvatar: item.authorAvatar ?? '',
                    authorId: item.authorId ?? '',
                    replyNum: item.replyNum, likeCount: item.likeCount ?? 0,
                    isLiked: item.isLiked ?? false,
                    abstract: item.abstract,
                    firstImage: item.firstImage ?? '', images: item.images ?? [],
                    createTime: item.createTime, isTop: item.isTop, isGood: item.isGood,
                  } as ThreadItemData,
                  onTap: (tid: string) => this.openThread(tid),
                  onLike: (tid: string, postId: string, liked: boolean) => this.handleLike(tid, postId, liked),
                  onShare: (d: ThreadSharePayload) => this.shareThread(d),
                  onComment: (tid: string) => this.openThread(tid),
                  onAvatarTap: (id: string, name: string) => this.openUserProfile(id, name)
                })
              }, (item: ThreadItem) => `${item.tid}_${item.author}_${item.isLiked ? 1 : 0}_${item.likeCount ?? 0}`)

              if (this.hasMore) {
                Row() {
                  if (this.loadingMore) {
                    LoadingView({ message: '加载中...' }).height(40)
                  } else {
                    Text('上拉加载更多')
                      .fontSize(fs(13, this.fontScale))
                      .fontColor(Theme.textTertiary(this.isDark))
                  }
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
                .padding({ top: Spacing.md, bottom: Spacing.md })
              }
            }
            .width('100%')
            .padding({ left: 12, right: 12 })
            .opacity(this.contentOpacity)
              }
              // 骨架屏覆盖层：Loading 期间显示，由 fadeInContent 控制淡出（1→0）
              if (this.loadState === LoadState.Loading) {
                ThreadListSkeleton({ count: 4 })
                  .width('100%')
                  .opacity(this.skeletonOpacity)
              }
              // 错误层
              if (this.loadState === LoadState.Error) {
                ErrorView({ message: this.errorMsg, onRetry: () => { this.loadThreads(); } }).height(200)
              }
            }
            .width('100%')
            // 排序切换过场·新页位移：只作用于列表区（对应首页 switchTab 的"进场页"：自对侧整屏进入、归位）。
            // 位移挂在这一层而不是 Scroll 上 —— Scroll 里还装着吧头与兜底排序栏，挂在 Scroll 上会让它们一起滑
            // （首页切 Tab 时标题栏与底栏是静止的，故必须把作用域收窄到列表内容）。只做水平位移，垂直位置不变。
            .translate({ x: `${this.inOffset}%` })
            .transition(this.searchSwap(0, -16))
          }
        }
        .width('100%')
        .padding({ bottom: this.contentBottomSpace() })
        .onAreaChange((oldValue: Area, newValue: Area) => this.onContentAreaChange(oldValue, newValue))
      }
      // 旧页快照锚点（`componentSnapshot.getSync` 取 Scroll 矩形，再按 region 裁掉吧头，见 captureExitSnapshot）；
      // 新页位移已下移到「列表区」那一层，故这里不再挂 translate —— 吧头/兜底排序栏由此保持静止
      .id(THREAD_SCROLL_SNAPSHOT_ID)
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .clip(false)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .overlay(this.BottomFadeOverlay())
      .blendMode(BlendMode.SRC_OVER, BlendApplyType.OFFSCREEN)
      .edgeEffect(EdgeEffect.Spring)
      .onAreaChange((oldValue: Area, newValue: Area) => this.onViewportAreaChange(oldValue, newValue))
      .onScroll((xOffset: number, yOffset: number) => this.onListScroll(xOffset, yOffset))
      .onReachEnd(() => {
        // 搜索态：触底兜底再取一批（正常滚动已在接近末尾时提前取）
        if (this.searchMode) {
          this.searchNextBatch();
          return;
        }
        if (this.hasMore && !this.loadingMore) {
          this.loadMore();
        }
      })

      // 悬浮顶栏（内容可穿过）；
      // 官方 title 槽位路径下整行已在槽位里（ThreadTitleBar），这里不再叠一层
      if (!(THREAD_LIST_OFFICIAL_TITLE_BAR && this.materialSupported)) {
      Row() {
        // 返回键两态共用同一节点（位置/图标一致）：进出搜索时保持静止，避免同款图标交叉重影
        Button() {
          SymbolGlyph($r('sys.symbol.chevron_left')).fontColor([$r('sys.color.icon_primary')]).fontSize(fs(22, this.fontScale))
        }
        .width(44).height(44)
        .backgroundColor(Theme.segGlass(this.isDark, false))
        .border({ width: 0.5, color: Theme.manualGlassBorder() })
        .backgroundBlurStyle(BlurStyle.Thin, { scale: 0.85 })
        .shadow(Theme.segGlassShadow(this.isDark, false))
        .borderRadius(Radius.full)
        .accessibilityText(this.searchMode ? '退出搜索' : '返回')
        .onClick(() => {
          if (this.searchMode) {
            this.exitSearch();
          } else {
            this.getUIContext().getRouter().back();
          }
        })

        if (this.searchMode) {
          // 真模糊磨砂搜索框：blur 挂在铺满圆角的内层 Row 上、TextInput 自身透明
          // （在 TextInput 上直接 backgroundBlurStyle 会画成固定矩形，不跟随胶囊圆角，同 Search.ets）
          Row() {
            TextInput({
              placeholder: `搜索「${this.forumName}」吧帖子`,
              text: this.searchKeyword,
            })
              .layoutWeight(1)
              .height('100%')
              // 高度与返回键（44）严格对齐，胶囊与圆形同高同心
              .fontSize(fs(15, this.fontScale))
              .fontColor(Theme.textPrimary(this.isDark))
              .placeholderColor(Theme.textTertiary(this.isDark))
              .backgroundColor(Color.Transparent)
              .padding({ left: 14, right: 14 })
              .defaultFocus(true)
              .onChange((v: string) => { this.onSearchKeywordChange(v); })
          }
          // layoutWeight(1) 自动吃掉剩余宽度：左右边距对称，任何字号下都不会越过屏幕右缘
          .layoutWeight(1)
          .height(44)
          // 与返回键拉开一档间距，避免两个玻璃控件视觉粘连
          .margin({ left: Spacing.md })
          .borderRadius(Radius.full)
          // 底色近全透明（亮色归零）：不留白夹层盖住模糊，让 blur 自带 tint 呈现磨砂
          .backgroundColor(Theme.segGlass(this.isDark, false))
          .border({ width: 0.5, color: Theme.manualGlassBorder() })
          // 真模糊本体：Regular + scale 0.85（与同排返回键、Search.ets 搜索框同族）
          .backgroundBlurStyle(BlurStyle.Regular, { scale: 0.85 })
          // 真模糊路径无材质自带投影，须给真实浮起影（勿用 glassShadowStyle 全零）
          .shadow(Theme.segGlassShadow(this.isDark, false))
          // 转场：自右侧轻移入位 / 向右侧收起（返回键不参与，避免图标重影）
          .transition(this.searchSwap(16, 0))
        } else {
          Blank()

          Row({ space: Spacing.md }) {
            Button() {
              SymbolGlyph($r('sys.symbol.magnifyingglass')).fontColor([$r('sys.color.icon_primary')]).fontSize(fs(20, this.fontScale))
            }
            .width(44).height(44)
            .backgroundColor(Theme.segGlass(this.isDark, false))
            .border({ width: 0.5, color: Theme.manualGlassBorder() })
            .backgroundBlurStyle(BlurStyle.Thin, { scale: 0.85 })
            .shadow(Theme.segGlassShadow(this.isDark, false))
            .borderRadius(Radius.full)
            .accessibilityText('搜索本吧帖子')
            .onClick(() => { this.openSearch(); })

            Button() {
              // 自绘「更多」图标：横向三点（原 sys.symbol.ellipsis_message_1 是带省略号的对话气泡，形似消息/私信图标，易误解）
              Row({ space: 4 }) {
                Column().width(5).height(5).borderRadius(2.5).backgroundColor($r('sys.color.icon_primary'))
                Column().width(5).height(5).borderRadius(2.5).backgroundColor($r('sys.color.icon_primary'))
                Column().width(5).height(5).borderRadius(2.5).backgroundColor($r('sys.color.icon_primary'))
              }
              .height(22)
              .alignItems(VerticalAlign.Center)
              .justifyContent(FlexAlign.Center)
            }
            .width(44).height(44)
            .backgroundColor(Theme.segGlass(this.isDark, false))
            .border({ width: 0.5, color: Theme.manualGlassBorder() })
            .backgroundBlurStyle(BlurStyle.Thin, { scale: 0.85 })
            .shadow(Theme.segGlassShadow(this.isDark, false))
            .borderRadius(Radius.full)
            .accessibilityText('更多操作')
            .onClick(() => {
              this.showMoreSheet = true;
            })
          }
          // 已贴屏幕右缘、无余量：只做纯淡入淡出，避免位移越出右缘
          .transition(this.searchSwap(0, 0))
        }
      }
      .width('100%')
      .padding({ left: Spacing.lg, right: Spacing.lg, top: 44, bottom: 10 })
      .backgroundColor(Color.Transparent)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg(this.isDark))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

    // 悬浮 FAB（**只剩「发主题」加号一枚**）两条路径：官方槽位壳（FabSlotShell）/
    // 改造前页面主体自绘玻璃（刷新钮已于 2026-09-12 按用户要求移除，刷新入口改由排序栏
    // 「重复点击当前排序」承担，见 refreshByRetap）
    if (THREAD_LIST_OFFICIAL_TITLE_BAR && this.materialSupported) {
      this.FabSlotShell()
    } else {
    // 发主题 FAB - 沉浸光感圆形加号
    Stack() {
      SymbolGlyph($r('sys.symbol.plus'))
        .fontSize(fs(26, this.fontScale))
        .fontColor([Theme.textPrimary(this.isDark)])
    }
    .width(56)
    .height(56)
    .borderRadius(28)
    .backgroundColor(Theme.segGlass(this.isDark, false))
    .border({ width: 0.5, color: Theme.manualGlassBorder() })
    .backgroundBlurStyle(BlurStyle.Regular, { scale: 0.85 })
    .shadow(Theme.segGlassShadow(this.isDark, false))
    .margin({ right: 28, bottom: 36 })
    .zIndex(20)
    // 搜索态隐去：淡出 + 缩小 + 下沉，隐藏时彻底不接收触摸
    .opacity(this.fabReveal())
    .scale({ x: this.fabReveal(), y: this.fabReveal() })
    .translate({ y: (1 - this.fabReveal()) * 20 })
    .hitTestBehavior(this.searchMode ? HitTestMode.None : HitTestMode.Default)
    .animation({ duration: 220, curve: Curve.FastOutSlowIn })
    .onClick(() => this.openCompose())
    }

    // 底部排序底栏（官方槽位壳，§6.10 同机制）：热门 / 最新 / 精选 三枚等分钮，整条背板走
    // 官方沉浸光感（与首页 / 搜索页底栏同源）。搜索态不渲染（页内搜索不切排序，且需腾出底部空间）。
    if (THREAD_LIST_OFFICIAL_SORT_BAR && this.materialSupported && !this.searchMode) {
      this.SortSlotShell()
    }

    // 吧主页右上角「更多」操作面板已改为系统 CustomDialog（systemMaterial 沉浸光感），
    // 由 moreSheetController + @Watch 驱动，页面 body 内不再自绘浮层
    }
    .width('100%')
    .height('100%')
    // 根容器实宽 → currentWidth：排序栏槽位壳的 barWidth 只接受数值（Dimension 不收 calc 字符串）
    .onAreaChange((_old: Area, n: Area) => { this.currentWidth = n.width as number; })
  }

  build() {
    if (THREAD_LIST_OFFICIAL_TITLE_BAR && this.materialSupported) {
      // 官方槽位路径（§6.10）：顶栏整行（返回 / 搜索框 / 搜索 / 更多）搬进 Navigation title 槽位吃真材质；
      // 底部 FAB（加号）由 ThreadListContent 内的 FabSlotShell 送进「空 tabBar 壳」槽位
      Navigation() {
        this.ThreadListContent()
      }
      .title({ builder: this.ThreadTitleBar(), height: THREAD_LIST_TITLE_BAR_HEIGHT },
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
      this.ThreadListContent()
    }
  }

  /**
   * 官方槽位标题栏（§6.10 同机制）：返回 44 圆钮 +（搜索态：搜索框 / 常态：搜索 44 圆钮 + 更多 44 圆钮）。
   * 玻璃全部换成官方材质：三枚钮 → `ImmMaterial.seg(false)`（THIN 中性档，与首页/进吧/详情页顶栏同套语言）；
   * 搜索框原为 `BlurStyle.Regular`（比同排圆钮厚一档），故取 `seg(true)`（REGULAR 中性档，无品牌赋色）
   * 保持原有厚薄层次。按坑 24 删掉 `segGlass` / `manualGlassBorder` / `backgroundBlurStyle` /
   * `segGlassShadow` 四项自绘玻璃：`Button` 补 `backgroundColor(Color.Transparent)` 清默认品牌蓝填充，
   * 搜索框外壳是 `Row` 无默认填充、`TextInput` 保持透明。
   * 几何（top 44 / bottom 10 / 左右 Spacing.lg / 圆钮 44 / 搜索框 height 44 + margin-left Spacing.md /
   * 常态 Row space Spacing.md）与改造前逐项一致；两态转场 `searchSwap` 与 onClick 调用点零改动。
   */
  @Builder
  ThreadTitleBar() {
    Row() {
      // 返回键两态共用同一节点（位置/图标一致）：进出搜索时保持静止，避免同款图标交叉重影
      Button() {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontColor([$r('sys.color.icon_primary')]).fontSize(fs(22, this.fontScale))
      }
      .width(44).height(44)
      .backgroundColor(Color.Transparent)
      .systemMaterial(ImmMaterial.seg(false))
      .borderRadius(Radius.full)
      .accessibilityText(this.searchMode ? '退出搜索' : '返回')
      .onClick(() => {
        if (this.searchMode) {
          this.exitSearch();
        } else {
          this.getUIContext().getRouter().back();
        }
      })

      if (this.searchMode) {
        // 官方槽内搜索框：材质挂在外层 Row（TextInput 自身透明），槽内不再需要 blur 兜底
        Row() {
          TextInput({
            placeholder: `搜索「${this.forumName}」吧帖子`,
            text: this.searchKeyword,
          })
            .layoutWeight(1)
            .height('100%')
            // 高度与返回键（44）严格对齐，胶囊与圆形同高同心
            .fontSize(fs(15, this.fontScale))
            .fontColor(Theme.textPrimary(this.isDark))
            .placeholderColor(Theme.textTertiary(this.isDark))
            .backgroundColor(Color.Transparent)
            .padding({ left: 14, right: 14 })
            .defaultFocus(true)
            .onChange((v: string) => { this.onSearchKeywordChange(v); })
        }
        // layoutWeight(1) 自动吃掉剩余宽度：左右边距对称，任何字号下都不会越过屏幕右缘
        .layoutWeight(1)
        .height(44)
        // 与返回键拉开一档间距，避免两个玻璃控件视觉粘连
        .margin({ left: Spacing.md })
        .borderRadius(Radius.full)
        .systemMaterial(ImmMaterial.seg(true))
        // 转场：自右侧轻移入位 / 向右侧收起（返回键不参与，避免图标重影）
        .transition(this.searchSwap(16, 0))
      } else {
        Blank()

        Row({ space: Spacing.md }) {
          Button() {
            SymbolGlyph($r('sys.symbol.magnifyingglass')).fontColor([$r('sys.color.icon_primary')]).fontSize(fs(20, this.fontScale))
          }
          .width(44).height(44)
          .backgroundColor(Color.Transparent)
          .systemMaterial(ImmMaterial.seg(false))
          .borderRadius(Radius.full)
          .accessibilityText('搜索本吧帖子')
          .onClick(() => { this.openSearch(); })

          Button() {
            // 自绘「更多」图标：横向三点（原 sys.symbol.ellipsis_message_1 是带省略号的对话气泡，形似消息/私信图标，易误解）
            Row({ space: 4 }) {
              Column().width(5).height(5).borderRadius(2.5).backgroundColor($r('sys.color.icon_primary'))
              Column().width(5).height(5).borderRadius(2.5).backgroundColor($r('sys.color.icon_primary'))
              Column().width(5).height(5).borderRadius(2.5).backgroundColor($r('sys.color.icon_primary'))
            }
            .height(22)
            .alignItems(VerticalAlign.Center)
            .justifyContent(FlexAlign.Center)
          }
          .width(44).height(44)
          .backgroundColor(Color.Transparent)
          .systemMaterial(ImmMaterial.seg(false))
          .borderRadius(Radius.full)
          .accessibilityText('更多操作')
          .onClick(() => {
            this.showMoreSheet = true;
          })
        }
        // 已贴屏幕右缘、无余量：只做纯淡入淡出，避免位移越出右缘
        .transition(this.searchSwap(0, 0))
      }
    }
    .width('100%')
    .padding({ left: Spacing.lg, right: Spacing.lg, top: 44, bottom: 10 })
  }

  /**
   * 悬浮 FAB 官方槽位壳（官方壳路径专用）：搭一个「只有 tabBar 的真实 Tabs」把**加号一枚**送进官方槽位
   * （机制与 ThreadDetail `SortPillShell` 相同；刷新钮已于 2026-09-12 按用户要求移除）。
   * 依据：`Button` 属 B 档，仅在 Navigation 标题栏与
   * `Tabs(barPosition: End)` 底部 TabBar 内生效，挂在页面主体必判 Material inactive: out of scope。
   * 五点关键：
   * ① `TabContent` 留空（内容区高度 = 壳高 56 - barHeight 56 = 0），壳里实际只有 tabBar 一列；
   * ② 不传 `.barFloatingStyle(...)`：官方悬浮背板整体不生成，不会凭空多出一条玻璃底；
   * ③ 不挂 `barOverlap(true)`（坑 26：空壳挂它会触发底栏默认浓模糊背板），且显式
   *    `.barBackgroundBlurStyle(BlurStyle.NONE)` 关掉底栏默认 `COMPONENT_REGULAR` 磨砂板；
   * ④ `hitTestBehavior(None)`：壳自身不参与触摸测试，子节点（加号）与兄弟节点照常；
   * ⑤ **壳宽 80 而非全宽**：TabBar 页签节点的命中区恒等于自身矩形，全宽时该节点横跨整行，
   *    空区照样吞掉竖向滑动，列表在该行拖不动（该节点是系统内部节点，`hitTestBehavior`
   *    挂不到它身上，实测无效）。收窄成「右缘 24 + 钮宽 56」后死区与加号钮重合，列表其余
   *    区域畅通；外层 Stack 为 BottomEnd，故壳自动靠右停靠；右缘由 28 收到 24，与排序栏左缘对称。
   * 几何：壳高 **56**（原 124 = 56 + 12 + 56，随刷新钮一并回收），底距 30
   * （= 排序底栏底距，见 THREAD_LIST_FAB_SHELL_BOTTOM）—— 加号钮底距 30 与底部排序栏**同排**
   * （底边一条线、高 56 与栏高 56 顶边也一条线），占 30~86；右缘 24。
   * 显隐动效（fabReveal 淡出 + 缩小 + 下沉，220ms FastOutSlowIn）整体作用在壳上；壳收窄后
   * 缩放原点随之落到加号自身中心，比原先「以屏宽中点缩放」更贴形。搜索态隐藏时加号
   * `hitTestBehavior(None)`（见 FabSlotColumn），与改造前「不可见即不拦截」同效。
   */
  @Builder
  FabSlotShell() {
    Tabs({ barPosition: BarPosition.End }) {
      TabContent()
        .tabBar(this.FabSlotColumn())
    }
    .width(THREAD_LIST_FAB_SHELL_WIDTH)
    .height(THREAD_LIST_FAB_SHELL_HEIGHT)
    .vertical(false)
    .scrollable(false)
    .barHeight(THREAD_LIST_FAB_SHELL_HEIGHT)
    .barBackgroundColor(Color.Transparent)
    .barBackgroundBlurStyle(BlurStyle.NONE)
    .backgroundColor(Color.Transparent)
    .clip(false)
    .margin({ bottom: THREAD_LIST_FAB_SHELL_BOTTOM })
    .zIndex(20)
    .opacity(this.fabReveal())
    .scale({ x: this.fabReveal(), y: this.fabReveal() })
    .translate({ y: (1 - this.fabReveal()) * 20 })
    .hitTestBehavior(HitTestMode.None)
    .animation({ duration: 220, curve: Curve.FastOutSlowIn })
  }

  /** FAB 槽内列（官方槽位版）：右对齐 + 右缘 24（与排序栏左缘对称），**只剩加号一枚**
   *  （刷新钮已移除，原「上刷新 / 下加号、间距 12」随之取消，`Column` 的 `space` 也不再需要）。
   *  几何与改造前加号逐项一致（56 圆钮 / Radius 28 / 图标 fontSize 26）。
   *  玻璃走 `ImmMaterial.fabFlat()`（THIN 中性档 + `applyShadow: false` + **`colorInvert: true`**）：
   *  ① 无阴影 —— 钮直接浮在列表内容上，带阴影版的材质投影会在钮下方拖出一圈淡影
   *     （真机反馈要求消除，2026-09-11，处理方式与 ThreadDetail 底部排序胶囊同款）；
   *  ② 带 `colorInvert` —— 与同排底栏（`floatingBarFlat`）同档，材质随背景明暗自动翻转
   *     （用户反馈「底栏和底栏内文字会随背景变色、加号不会」，2026-09-12）。
   *  图标色因此必须用**系统语义色** `$r('sys.color.font_primary')`（与底栏三钮文字同源）：
   *  自绘 hex 不受 colorInvert 影响，改回 `Theme.textPrimary` 会立刻退回「加号不翻色」。 */
  @Builder
  FabSlotColumn() {
    Column() {
      // 发主题 FAB - 沉浸光感圆形加号（图标取系统语义色，才能随材质一起反色）
      Stack() {
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(fs(26, this.fontScale))
          .fontColor([$r('sys.color.font_primary')])
      }
      .width(56)
      .height(56)
      .borderRadius(28)
      .systemMaterial(ImmMaterial.fabFlat())
      .hitTestBehavior(this.searchMode ? HitTestMode.None : HitTestMode.Default)
      .onClick(() => this.openCompose())
    }
    .width('100%')
    .height(THREAD_LIST_FAB_SHELL_HEIGHT)
    .alignItems(HorizontalAlign.End)
    .padding({ right: 24 })
  }

  /**
   * 底部排序栏槽位壳（官方沉浸光感，§6.10 / §6.13 同机制）：
   * 搭一个「只有 tabBar 的真实 Tabs」把三枚排序钮送进官方槽位 —— 页面主体（含 Scroll 内元素）挂
   * `systemMaterial` 必判 `out of scope`，只有 `Tabs(barPosition: End)` 的 tabBar 才是官方认可范围。
   *
   * ★ 材质来源（本次修复「底栏没材质」）：**空壳路径下 `barFloatingStyle.systemMaterial` 不生成官方背板**。
   *   对照 §6.13 `FabSlotShell` 与 §9.3 #6 `ThreadDetail.SortPillShell`：两处空壳**都不传** `barFloatingStyle`
   *   （§9.3 原文「本壳不传 floating style，官方悬浮背板整体不生成」），材质一律由**槽内元素自己挂**
   *   `systemMaterial`（§1.1「自建空 Tabs 壳内的元素」那一行）。故整条背板改由槽内 `SortSegBar()` 的
   *   Row 承担：`ImmMaterial.floatingBarFlat()` + `Radius.full`（与首页底栏同材质档，仅关掉材质投影）→
   *   得到「一条官方玻璃栏 + 三枚透明文字钮」，与首页底栏同构。
   *
   * 其余四点关键（沿用已验证写法）：
   * ① TabContent 留空（内容区高度 = 壳高 − barHeight = 0），壳里实际只有 tabBar 一行；
   * ② `.barBackgroundBlurStyle(BlurStyle.NONE)` 必写（坑 26：否则渲染底栏默认 COMPONENT_REGULAR 磨砂板）；
   * ③ **不传 `barOverlap(true)`**（坑 26 追加：空壳挂它会触发 COMPONENT_THICK 默认模糊，残留一层背板）；
   * ④ 槽内元素只留几何 + 文字色，玻璃四项（backgroundColor / border / backgroundBlurStyle / shadow）
   *    一律不挂（坑 24：与材质叠用会互相覆盖或发脏）。
   *
   * ★ 壳宽 = 「目标元素实际占位」= 排序栏宽度（屏宽 − 116 = 左 24 + 栏 + 缝 12 + 加号 56 + 右 24，
   *   下限 184，见 sortBarWidth），**不是 `'100%'`**（坑 30：空壳开全宽时系统 TabBar 页签节点横跨
   *   整行、吞掉下层列表的竖向滑动，且 `hitTestBehavior` 挂不到该节点上，只能靠收窄几何把死区限制
   *   在底栏范围内）。收窄后 `Stack(alignContent: BottomEnd)` 会让壳靠右停靠，故垫一层**全宽 `Row`**；
   *   栏宽不再左右对称（左 24 / 右 92），若用 `Center` 会被推到左边距 60，故改用
   *   `justifyContent(Start)` + `padding({ left: 24 })` 钉回左缘
   *   （同 `ThreadDetail.SortPillShell` 用全宽 Row + padding-left 钉回左缘的思路）。
   * 几何：栏高 56（= 槽内三钮 height 46 + 上下 padding 5×2，与右下加号钮同高同排；栏内纯文字无
   * 图标，故比首页 / 搜索页底栏的 74 矮 18，圆角 `Radius.full` 收成 28 与加号同圆）、底距 30。
   */
  @Builder
  SortSlotShell() {
    Row() {
      Tabs({ barPosition: BarPosition.End }) {
        TabContent()
          .tabBar(this.SortSegBar())
      }
      .width(this.sortBarWidth())
      .height(THREAD_LIST_SORT_BAR_HEIGHT)
      .vertical(false)
      .scrollable(false)
      .barHeight(THREAD_LIST_SORT_BAR_HEIGHT)
      .barBackgroundColor(Color.Transparent)
      .barBackgroundBlurStyle(BlurStyle.NONE)
      .backgroundColor(Color.Transparent)
      .clip(false)
      .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height(THREAD_LIST_SORT_BAR_HEIGHT)
    .justifyContent(FlexAlign.Start)
    .padding({ left: 24 })
    .margin({ bottom: THREAD_LIST_SORT_BAR_BOTTOM })
    .zIndex(19)
    .hitTestBehavior(HitTestMode.None)
    // 搜索态不渲染（外层条件）；进出搜索与「列表区换场」同向：自下方浮起 / 向下方收起
    .transition(this.searchSwap(0, 24))
  }

  /**
   * 排序栏槽位内的三枚等分钮（热门 / 最新 / 精选）：纯文字三等分（`layoutWeight(1)`），
   * 选中态只靠系统强调色 + 加粗表达，钮自身不挂任何背景 / 材质（与首页底栏 BottomItem、
   * 搜索页 ModuleSegButton 同写法）。
   *
   * ★ 整条背板的官方沉浸材质挂在本行（Row）上，不在钮上：
   *   - 空壳路径没有 `barFloatingStyle` 背板可用（见 SortSlotShell 注释），材质必须由槽内元素承担；
   *   - 材质 = `ImmMaterial.floatingBarFlat()`（THIN / 无流光 / `applyShadow: false`，与首页底栏同档
   *     但**去掉了材质自带投影**：本栏悬浮在列表内容之上、下方没有官方背板托底，带阴影版
   *     `floatingBar()` 会在栏体四周压出一圈突兀暗晕（真机反馈要求去除，2026-09-12），
   *     处理方式与 `segFlat`（详情页排序胶囊）/ `fabFlat`（右下加号）同款）；
   *   - `Radius.full` 把栏高（56）收成全圆角（28），与右下加号钮同圆（首页底栏 74 → 37 同族）；
   *   - 行内不挂 backgroundColor / border / backgroundBlurStyle / shadow（坑 24）。
   *
   * ★ 交互（三枚钮共用 `selectSort`，故槽位路径与兜底路径行为一致）：
   *   点**未选中**的钮 = 切换排序（滑入动画 + 命中快照秒开）；
   *   点**已选中**的钮 = **回顶 + 刷新该排序**（`refreshByRetap` → `handleRefresh`，用户 2026-09-12 要求）。
   */
  @Builder
  SortSegBar() {
    Row() {
      this.SortSegButton('热门', 0)
      this.SortSegButton('最新', 1)
      this.SortSegButton('精选', 2)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 8, right: 8, top: THREAD_LIST_SORT_BAR_PADDING, bottom: THREAD_LIST_SORT_BAR_PADDING })
    .systemMaterial(ImmMaterial.floatingBarFlat())
    .borderRadius(Radius.full)
  }

  @Builder
  SortSegButton(label: string, index: number) {
    Column() {
      Text(label)
        .fontSize(fs(13, this.fontScale))
        .fontWeight(this.selectedSort === index ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.selectedSort === index
          ? $r('sys.color.font_emphasize')
          : $r('sys.color.font_primary'))
    }
    .layoutWeight(1)
    // 钮高 = 栏高 − 上下留白（56 − 5×2 = 46）：与 SortSegBar 的 padding 同源，改栏高即整体联动
    .height(THREAD_LIST_SORT_BAR_HEIGHT - THREAD_LIST_SORT_BAR_PADDING * 2)
    .justifyContent(FlexAlign.Center)
    // 与内容区自绘胶囊同款按压回弹（pressedTab 由 pulseTab 驱动），保持切换手感一致
    .scale({ x: this.pressedTab === index ? 0.93 : 1, y: this.pressedTab === index ? 0.93 : 1 })
    .animation({ duration: 100, curve: Curve.EaseOut })
    .accessibilityText(label)
    .onClick(() => {
      this.pulseTab(index);
      this.selectSort(index);
    })
  }

  /** 排序栏宽度（vp）= 屏宽 − 116（左 24 + 栏 + 缝 12 + 加号 56 + 右 24），下限 184。
   *  116 的来路：加号与底栏**同排**，底栏右端必须停在加号左侧留 12 缝；加号右缘 24（与底栏左缘
   *  对称）→ 底栏右缘距屏右 92 = 24 + 56 + 12，故栏宽 = 屏宽 − 24 − 92。
   *  用 THREAD_LIST_SORT_BAR_GAP 而非写死 12，缝隙调整时与 FAB 壳宽（80 = 24 + 56）自动联动。
   *  下限 184 = 3 × 56（钮）+ 16（栏内左右 padding 8×2）：保证每枚钮至少 56 宽、与加号同宽；
   *  屏宽 ≥ 300 时公式自然 ≥ 184（旧下限 240 会把底栏推到加号身上 —— 320 屏即重叠 28vp，故废除）。
   *  Dimension 不收 calc 字符串，只能按屏宽算数值；同时用作槽位壳宽（坑 30：空壳必须收窄到
   *  「目标元素实际占位」，不能开 `'100%'`） */
  private sortBarWidth(): number {
    const fabColumn: number = THREAD_LIST_FAB_SHELL_WIDTH + THREAD_LIST_SORT_BAR_GAP;
    const w: number = this.currentWidth > 0 ? this.currentWidth - 24 - fabColumn : 244;
    return w > 184 ? w : 184;
  }

  /**
   * 列表底部让位高度：槽位路径 = 98（加号钮顶 86 = 底距 30 + 56，+ 12 呼吸；刷新钮移除后最高点
   * 退回加号，比原值 166 少 68）；
   * 兜底路径 = 104（自绘加号底距 36 → 顶 92，+ 12 呼吸；原 150 是给「贴底 104 的刷新钮 + 加号」
   * 两钮留的余量，刷新钮移除后同步收小）；
   * 搜索态保持改造前的 150（搜索态既无底栏也无 FAB，预留的是搜索 UI 空间）。
   */
  private contentBottomSpace(): number {
    if (this.searchMode) {
      return 150;
    }
    return (THREAD_LIST_OFFICIAL_SORT_BAR && this.materialSupported)
      ? THREAD_LIST_CONTENT_BOTTOM_SPACE
      : 104;
  }

  @Builder
  ForumHeaderBuilder() {
    Row({ space: 16 }) {
      // 吧头像
      Column() {
        if (this.forumInfo && this.forumInfo.avatar.length > 0 && !this.failedAvatar) {
          Image(this.forumInfo.avatar)
            .width(88)
            .height(88)
            .borderRadius(44)
            .objectFit(ImageFit.Cover)
            .clip(true)
            .onError(() => { this.failedAvatar = true; })
        } else {
          Stack() {
            Text((this.forumInfo?.forumName ?? this.forumName).charAt(0))
              .fontSize(fs(32, this.fontScale))
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
          .width(88)
          .height(88)
          .borderRadius(44)
          .backgroundColor(Theme.brand())
          .alignContent(Alignment.Center)
        }
      }

      // 吧信息
      Column({ space: 8 }) {
        // 吧名
        Text((this.forumInfo?.forumName ?? this.forumName) + '吧')
          .fontSize(fs(28, this.fontScale))
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.textPrimary(this.isDark))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 进度条 + 关注/签到按钮（未关注的吧先显「未关注」，点击关注后回落「未签到」）
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Stack({ alignContent: Alignment.Start }) {
              Row()
                .width('100%')
                .height(6)
                .backgroundColor(Theme.bgElevated(this.isDark))
                .borderRadius(3)
              Row()
                .width(this.progressPercent() + '%')
                .height(6)
                .backgroundColor(Theme.textPrimary(this.isDark))
                .borderRadius(3)
            }
            .width('100%')

            // 经验值显示
            if (this.forumInfo && this.forumInfo.curScore > 0) {
              Text(`${this.forumInfo.curScore}/${this.forumInfo.levelupScore > 0 ? this.forumInfo.levelupScore : '---'} 经验`)
                .fontSize(fs(11, this.fontScale))
                .fontColor(Theme.textTertiary(this.isDark))
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Row() {
            Text(this.signButtonLabel())
              .fontSize(fs(13, this.fontScale))
              .fontColor(this.signButtonColor())
          }
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .backgroundColor(Theme.segGlass(this.isDark, false))
          .border({ width: 0.5, color: Theme.manualGlassBorder() })
          .backgroundBlurStyle(BlurStyle.Thin, { scale: 0.85 })
          .shadow(Theme.segGlassShadow(this.isDark, false))
          .borderRadius(Radius.full)
          .accessibilityText(this.signButtonLabel())
          .onClick(() => {
            // 未关注：首点只做关注（关注成功即显示「未签到」），不直接签到
            if (this.forumUnfollowed()) {
              this.handleForumFollow();
              return;
            }
            this.handleSignIn();
          })
        }
        .width('100%')

        // 等级信息
        if (this.forumInfo && this.forumInfo.levelName.length > 0) {
          Row({ space: 6 }) {
            Text(`LV${this.forumInfo.userLevel + 1}`)
              .fontSize(fs(14, this.fontScale))
              .fontColor(Theme.textTertiary(this.isDark))
              .fontWeight(FontWeight.Medium)
            Text(this.forumInfo.levelName)
              .fontSize(fs(14, this.fontScale))
              .fontColor(Theme.textTertiary(this.isDark))
          }
        } else {
          Text('LV' + (this.forumInfo?.userLevel ?? 0))
            .fontSize(fs(14, this.fontScale))
            .fontColor(Theme.textTertiary(this.isDark))
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 16, bottom: 12 })
    .backgroundColor(Theme.bg(this.isDark))
  }

  private progressPercent(): number {
    if (!this.forumInfo || this.forumInfo.levelupScore <= 0) {
      return 0;
    }
    return Math.min(100, Math.round((this.forumInfo.curScore / this.forumInfo.levelupScore) * 100));
  }

  private pinnedThreads(): ThreadItem[] {
    // On "精选" tab (sort=2), don't separate - show everything as ThreadCard for easy browsing
    if (this.selectedSort === 2) {
      return [];
    }
    return this.threads.filter((t: ThreadItem) => t.isTop === true);
  }

  private normalThreads(): ThreadItem[] {
    // On "精选" tab (sort=2), show ALL threads as normal cards
    if (this.selectedSort === 2) {
      return this.threads;
    }
    // On other tabs: show non-置顶 threads as normal cards (精品 threads included)
    return this.threads.filter((t: ThreadItem) => t.isTop !== true);
  }

  /**
   * 本吧搜索结果（空关键词 / 取数中 / 无结果 / 结果列表 + 进度，复用 ThreadCard）。
   * 服务端模式一次出整页命中；本地模式逐轮扫描增长。无结果且仍在取数时显示"正在搜索"，
   * 而不是瞬时"未找到"；结果不满一屏时由 maybeAutoContinueSearch 自动续取，无需用户滑动。
   */
  @Builder
  SearchResultsBuilder() {
    Column({ space: 6 }) {
      if (this.searchKeyword.trim().length === 0) {
        Column({ space: Spacing.md }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontColor([$r('sys.color.icon_tertiary')])
            .fontSize(fs(40, this.fontScale))
          Text('输入关键词搜索本吧帖子')
            .fontSize(fs(14, this.fontScale))
            .fontColor(Theme.textSecondary(this.isDark))
        }
        .width('100%')
        .height(320)
        .justifyContent(FlexAlign.Center)
      } else if (this.searchThreads().length === 0 && this.searchFetching) {
        // 首轮扫描中：先给"正在搜索"，避免瞬时"未找到相关帖子"误导
        Column({ space: Spacing.md }) {
          LoadingView({ message: '正在搜索本吧帖子...' }).height(120)
        }
        .width('100%')
        .height(320)
        .justifyContent(FlexAlign.Center)
      } else if (this.searchThreads().length === 0) {
        Column({ space: Spacing.md }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontColor([$r('sys.color.icon_tertiary')])
            .fontSize(fs(40, this.fontScale))
          Text('未找到相关帖子')
            .fontSize(fs(14, this.fontScale))
            .fontColor(Theme.textSecondary(this.isDark))
          if (this.searchExhausted) {
            Text(this.searchEmptyHint())
              .fontSize(fs(12, this.fontScale))
              .fontColor(Theme.textTertiary(this.isDark))
          }
        }
        .width('100%')
        .height(320)
        .justifyContent(FlexAlign.Center)
      } else {
        // 进度行：让"找到多少、扫了多少"可见，避免长时间扫描被误认为卡住
        Row() {
          Text(this.searchStatusText())
            .fontSize(fs(12, this.fontScale))
            .fontColor(Theme.textTertiary(this.isDark))
        }
        .width('100%')
        .padding({ left: 4, top: 8, bottom: 2 })

        ForEach(this.searchThreads(), (item: ThreadItem) => {
          ThreadCard({
            item: {
              tid: item.tid, postId: item.postId ?? '',
              title: item.title, forumName: item.forumName,
              forumAvatar: item.forumAvatar ?? '',
              author: item.author,
              authorAvatar: item.authorAvatar ?? '',
              authorId: item.authorId ?? '',
              replyNum: item.replyNum, likeCount: item.likeCount ?? 0,
              isLiked: item.isLiked ?? false,
              abstract: item.abstract,
              firstImage: item.firstImage ?? '', images: item.images ?? [],
              createTime: item.createTime, isTop: item.isTop, isGood: item.isGood,
            } as ThreadItemData,
            onTap: (tid: string) => this.openThread(tid),
            onLike: (tid: string, postId: string, liked: boolean) => this.handleLike(tid, postId, liked),
            onShare: (d: ThreadSharePayload) => this.shareThread(d),
            onComment: (tid: string) => this.openThread(tid),
            onAvatarTap: (id: string, name: string) => this.openUserProfile(id, name)
          })
        },
          // 键必须覆盖后台补数据的字段：ForEach 仅在键变化时重建子组件，
          // 若只用 tid（固定键），详情补齐回来的 authorId/头像/点赞数会被复用旧组件吞掉，
          // 表现为"头像仍是字母占位、点赞恒 0、点作者不跳转"。
          (item: ThreadItem) => `search_${item.tid}_${item.authorId ?? ''}_${item.authorAvatar ?? ''}_${item.author}_${item.isLiked ? 1 : 0}_${item.likeCount ?? 0}_${item.replyNum}`)

        // 结果底部状态：扫描进度 / 继续搜索 / 已扫到底（与列表翻页底部同构）
        Row() {
          if (this.searchFetching) {
            LoadingView({ message: '正在搜索更多...' }).height(40)
          } else if (this.searchExhausted) {
            Text(this.searchFooterEndText())
              .fontSize(fs(13, this.fontScale))
              .fontColor(Theme.textTertiary(this.isDark))
          } else {
            Text('下滑加载更多匹配结果')
              .fontSize(fs(13, this.fontScale))
              .fontColor(Theme.textTertiary(this.isDark))
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: Spacing.md, bottom: Spacing.md })
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12 })
  }

  /**
   * 吧内排序分段（热门 / 最新 / 精选）：三枚 layoutWeight(1) 等宽胶囊，选中态由系统强调色文字 +
   * 字重 + 更实的真模糊表达，几何与改动前一致。
   * 注：三枚胶囊均**不挂 .shadow** —— 自绘投影已按要求去掉，只保留半透明底 + backgroundBlurStyle
   * 真模糊 + 0.5 描边（旧写法各挂 Theme.segGlassShadow(isDark, selected)）。
   * 使用范围：**仅兜底路径**（低版本 / 无材质 / 开关关闭）保留在内容区吧头下方；
   * 槽位路径下这段已搬到屏幕底部做官方沉浸光感悬浮底栏（见 SortSlotShell / SortSegBar）。
   * 交互与槽位路径同源（三处 onClick 都调 `selectSort`）：选中项重复点击 = 回顶 + 刷新该排序。
   */
  @Builder
  SortTabsBuilder() {
    Row({ space: Spacing.sm }) {
      Button('热门')
        .fontSize(fs(12, this.fontScale))
        // 与首页顶栏胶囊同款选中呈现：无色底靠真模糊，状态由系统强调色文字 + 字重表达
        .fontColor(this.selectedSort === 0 ? $r('sys.color.font_emphasize') : $r('sys.color.font_secondary'))
        .fontWeight(this.selectedSort === 0 ? FontWeight.Bold : FontWeight.Medium)
        .backgroundColor(Theme.segGlass(this.isDark, this.selectedSort === 0))
        .border({ width: 0.5, color: Theme.manualGlassBorder() })
        .backgroundBlurStyle(this.selectedSort === 0 ? BlurStyle.Regular : BlurStyle.Thin,
          { scale: this.selectedSort === 0 ? 0.8 : 0.85 })
        .borderRadius(Radius.full)
        .layoutWeight(1)
        .scale({ x: this.pressedTab === 0 ? 0.93 : 1, y: this.pressedTab === 0 ? 0.93 : 1 })
        .animation({ duration: 100, curve: Curve.EaseOut })
        .onClick(() => {
          this.pulseTab(0);
          this.selectSort(0);
        })
      Button('最新')
        .fontSize(fs(12, this.fontScale))
        .fontColor(this.selectedSort === 1 ? $r('sys.color.font_emphasize') : $r('sys.color.font_secondary'))
        .fontWeight(this.selectedSort === 1 ? FontWeight.Bold : FontWeight.Medium)
        .backgroundColor(Theme.segGlass(this.isDark, this.selectedSort === 1))
        .border({ width: 0.5, color: Theme.manualGlassBorder() })
        .backgroundBlurStyle(this.selectedSort === 1 ? BlurStyle.Regular : BlurStyle.Thin,
          { scale: this.selectedSort === 1 ? 0.8 : 0.85 })
        .borderRadius(Radius.full)
        .layoutWeight(1)
        .scale({ x: this.pressedTab === 1 ? 0.93 : 1, y: this.pressedTab === 1 ? 0.93 : 1 })
        .animation({ duration: 100, curve: Curve.EaseOut })
        .onClick(() => {
          this.pulseTab(1);
          this.selectSort(1);
        })
      Button('精选')
        .fontSize(fs(12, this.fontScale))
        .fontColor(this.selectedSort === 2 ? $r('sys.color.font_emphasize') : $r('sys.color.font_secondary'))
        .fontWeight(this.selectedSort === 2 ? FontWeight.Bold : FontWeight.Medium)
        .backgroundColor(Theme.segGlass(this.isDark, this.selectedSort === 2))
        .border({ width: 0.5, color: Theme.manualGlassBorder() })
        .backgroundBlurStyle(this.selectedSort === 2 ? BlurStyle.Regular : BlurStyle.Thin,
          { scale: this.selectedSort === 2 ? 0.8 : 0.85 })
        .borderRadius(Radius.full)
        .layoutWeight(1)
        .scale({ x: this.pressedTab === 2 ? 0.93 : 1, y: this.pressedTab === 2 ? 0.93 : 1 })
        .animation({ duration: 100, curve: Curve.EaseOut })
        .onClick(() => {
          this.pulseTab(2);
          this.selectSort(2);
        })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 4, bottom: 8 })
  }

  private async handleRefresh(): Promise<void> {
    if (this.refreshing) {
      console.info(`[REFRESH] skip (busy) sort=${this.selectedSort}`);
      return;
    }
    this.refreshing = true;
    const t0: number = Date.now();
    console.info(`[REFRESH] start sort=${this.selectedSort}`);
    try {
      const result = await this.withRefreshTimeout(
        TiebaService.getInstance().fetchForumThreads(this.forumName, 1, this.selectedSort, false)
      );
      this.page = 1;
      this.threads = result.list;
      this.hasMore = result.list.length > 0;
      this.stalledPages = 0;
      // Only update loadState if it was previously Loading or Error (first load / error recovery)
      if (this.loadState === LoadState.Loading || this.loadState === LoadState.Error) {
        this.loadState = result.list.length > 0 ? LoadState.Success : LoadState.Empty;
      }
      const header = TiebaService.getInstance().getCachedForumHeader();
      if (header) {
        this.forumInfo = header;
      }
      // 刷新后回到顶部，立即看到最新内容
      this.listScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: { duration: 300, curve: Curve.EaseOut } });
      // 刷新同样走后台昵称校准 + 回写缓存
      if (result.list.length > 0) {
        this.enrichInBackground(result.list);
        this.saveForumCache(result.list);
      }
      console.info(`[REFRESH] ok sort=${this.selectedSort} n=${result.list.length} cost=${Date.now() - t0}ms`);
      this.getUIContext().getPromptAction().showToast({ message: '刷新成功' });
    } catch (e) {
      const msg = (e as Error).message ?? '刷新失败';
      console.info(`[REFRESH] fail sort=${this.selectedSort} cost=${Date.now() - t0}ms err=${msg}`);
      this.getUIContext().getPromptAction().showToast({ message: msg });
    } finally {
      this.refreshing = false;
    }
  }

  /** 刷新总超时兜底：弱网/接口挂起时最多等 8 秒。
   *  刷新钮移除后界面已无转圈图标，兜底的目的变成「别让 busy 门被挂起的请求长期占住、
   *  导致后续重复点击排序（回顶刷新）持续被短路」。 */
  private withRefreshTimeout<T>(promise: Promise<T>): Promise<T> {
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

  /**
   * 当前吧是否处于「未关注」态（吧信息未加载时视为未知，按已关注展示原逻辑）。
   * 未关注时签到钮改显「未关注」，点击先引导关注；关注成功后 isLike 变化触发刷新，
   * 文案自动回落「未签到」，此时再点才真正走签到接口。
   */
  private forumUnfollowed(): boolean {
    return this.forumInfo !== null && !this.forumInfo.isLike;
  }

  /** 签到钮文案：未关注 → 「未关注」；已关注 → 已签N天 / 未签到 */
  private signButtonLabel(): string {
    if (this.forumUnfollowed()) {
      return '未关注';
    }
    return this.signDays > 0 ? `已签${this.signDays}天` : '未签到';
  }

  /** 未关注态用品牌色提示这是「可点的关注动作」，已关注态维持次要文字色 */
  private signButtonColor(): ResourceColor {
    return this.forumUnfollowed() ? Theme.brand() : $r('sys.color.font_secondary');
  }

  private async handleSignIn(): Promise<void> {
    // 本地已记录今日签到：直接回显，避免重复请求导致连续天数被错误 +1
    const localDays: number = await ForumSignStore.loadSignDays(this.forumName);
    if (localDays > 0) {
      this.signDays = localDays;
      this.getUIContext().getPromptAction().showToast({ message: `今日已签到，已连续签到${localDays}天` });
      return;
    }
    try {
      this.getUIContext().getPromptAction().showToast({ message: '签到中...' });
      const result = await TiebaService.getInstance().signForum(this.forumName);
      this.signDays = result.signDays > 0 ? result.signDays : this.signDays + 1;
      // 持久化签到结果：页面退出重进后据此回显「已签N天」（服务端吧头接口不返回签到态）
      await ForumSignStore.saveSignDays(this.forumName, this.signDays);
      const bonusMsg = result.bonusNum > 0 ? `，获得${result.bonusNum}经验` : '';
      this.getUIContext().getPromptAction().showToast({
        message: `签到成功！已连续签到${this.signDays}天${bonusMsg}`
      });
      // Refresh forum header to get updated score
      const header = TiebaService.getInstance().getCachedForumHeader();
      if (header) {
        this.forumInfo = header;
      }
    } catch (e) {
      const msg = (e as Error).message ?? '签到失败，请稍后重试';
      this.getUIContext().getPromptAction().showToast({ message: msg });
    }
  }

  /** 进入页面时恢复签到状态（异步，不阻塞列表加载；签到记录由 ForumSignStore 统一落盘） */
  private restoreSignState(): void {
    ForumSignStore.loadSignDays(this.forumName).then((days: number) => {
      if (days > 0) {
        this.signDays = days;
      }
    }).catch((): void => {
    });
  }

  /**
   * 点赞状态局部更新（不可变）：列表与搜索池共用。
   * 必须保留 authorId / authorNameShowMissing —— 旧实现重建对象时漏掉 authorId，
   * 会导致点赞后该卡片的作者头像/昵称点击因 authorId 丢失而无法跳转用户主页。
   */
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

  private async handleLike(tid: string, postId: string, liked: boolean): Promise<void> {
    try {
      const result = await TiebaService.getInstance().togglePostAgree(tid, postId, liked);
      if (result) {
        // 更新帖子列表中的点赞状态（不可变更新）
        this.threads = this.threads.map((t: ThreadItem): ThreadItem => this.withLikeState(t, tid, liked));
        // 搜索态结果池同样需要更新，否则吧内搜索页点赞后数字/心形不变化
        if (this.searchMode) {
          this.searchPool = this.searchPool.map((t: ThreadItem): ThreadItem => this.withLikeState(t, tid, liked));
          this.searchPoolVersion++;
        }
      }
    } catch (e) {
      const msg = (e as Error).message ?? '操作失败，请稍后重试';
      this.getUIContext().getPromptAction().showToast({ message: msg });
    }
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
}
