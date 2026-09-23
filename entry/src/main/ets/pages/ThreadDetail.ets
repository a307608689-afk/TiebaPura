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
import { hilog } from '@kit.PerformanceAnalysisKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { bundleManager, common, Want } from '@kit.AbilityKit';
import { pasteboard, BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { TiebaService } from '../service/TiebaService';
import { AuthManager } from '../service/AuthManager';
import { CacheManager } from '../cache/CacheManager';
import { CACHE_KEY } from '../common/Constants';
import { FavoriteStore, CATEGORY_DEFAULT_ID } from '../service/FavoriteStore';
import { HistoryStore } from '../service/HistoryStore';
import { ThreadDetail as ThreadDetailModel, FloorItem, CommentItem, SubPostDetail, PersonalContentItem, ContentFragment, ContentFragmentType, FavCategory, CategoryMapping } from '../model/DataModel';
import { ThreadDetailResult } from '../service/TiebaService';
import { Theme, Spacing, Radius, isDarkMode, ImmBlur, ImmMaterial, MaterialManager, fs, Breakpoint, isWideBarDevice, isLargeFoldDevice, isPuraXMaxDevice, overlayCardWidth, isWideFormDevice as detectWideFormDevice } from '../common/Theme';
import { ErrorView, ThreadSharePayload, acquireImagePreloadSlot, releaseImagePreloadSlot } from '../components/CommonComponents';
import { ThreadDetailSkeleton } from '../components/Skeleton';
import { FavCategoryPicker } from '../components/FavCategoryPicker';
import { EmojiLoader } from '../network/EmojiLoader';
import { ImageCache } from '../cache/ImageCache';
import { Haptic } from '../common/Haptic';
import image from '@ohos.multimedia.image';

enum LoadState {
  Loading, Success, Error,
}

/**
 * 顶部满宽渐显带高度（vp）：顶栏「状态栏让位 44」+「吧名胶囊高 44」= 88，
 * 即渐显终点正好落在吧名胶囊下沿——胶囊及以上区域内容逐级隐去，胶囊下方立即完全清晰。
 * 若后续调整顶栏 padding/胶囊高度，此处必须同步。
 */
const TOP_FADE_BAND_HEIGHT: number = 88;

/**
 * 顶部官方标题栏开关（2026-09-10，与 HomeTab / ForumsTab 同机制）：
 * true  = 「返回钮 / 吧名胶囊 / 分享钮」整行搬进 Navigation 的 title 槽位，玻璃交给官方沉浸材质 systemMaterial
 *         （官方口径：systemMaterial 生效区域仅 Navigation/NavDestination 标题栏、横向 Tabs(barPosition=End) 底部 TabBar；
 *          页面 body 内自绘浮层必判 Material inactive: out of scope）；
 *         与下方官方 Tabs 悬浮条（ImmersiveDockShell）合用后，本页即「上下两端官方槽位」齐备（§9.3 #6 目标形态）。
 * false = 回退改造前的页面主体悬浮顶栏（segGlass + backgroundBlurStyle 真磨砂兜底）。
 * ⚠️ 本页是二级路由页：搬槽位后系统侧滑返回 / 返回键需真机回归（§9.3 注记）。
 */
const THREAD_DETAIL_OFFICIAL_TITLE_BAR: boolean = true;
/**
 * 官方标题栏高度：与改造前悬浮顶栏几何逐项一致 —— 44(状态栏让位) + 44(胶囊/钮行高) + 10(底部呼吸) = 98。
 * 顶部渐显带 TOP_FADE_BAND_HEIGHT(88) 与之独立，保持原值不变。
 */
const THREAD_DETAIL_TITLE_BAR_HEIGHT: number = 98;

/** 2026-09-20（A+C 加载过渡打磨）：骨架屏最短停留时长——早到的数据等骨架站稳再交接，避免"骨架一闪而过"的廉价感 */
const SKELETON_MIN_DISPLAY_MS: number = 180;
/** 2026-09-20（A+C）：内容进场初始上浮量（vp），随淡入归零形成"落定"运动感，消除纯透明度开关的"闪现"感 */
const CONTENT_RISE_VP: number = 14;
/** 2026-09-20（分区上屏）：数据落地后楼主卡先独立绘制的等待时长，之后构建楼层区 */
const FLOORS_REVEAL_DELAY_MS: number = 50;
/** 2026-09-20（分区上屏）：楼层区进场淡入时长 */
const FLOORS_FADE_IN_MS: number = 200;
/** 2026-09-20（分区上屏）：楼层区淡入的启动延迟——楼主卡先落定，回复流随后进场 */
const FLOORS_FADE_DELAY_MS: number = 120;

/**
 * 排序胶囊（正序 / 只看全部）官方槽位开关（2026-09-10）：
 * true  = 两枚胶囊放进「真实 Tabs 的空 tabBar 槽位」承载。原因：官方 A 档「按钮与选择类」只有
 *         Slider / Toggle / Select，Button/Chip/SegmentButton 全属 B 档，**仅在 Navigation 标题栏与
 *         `Tabs(barPosition: End)` 底部 TabBar 内生效**（官方文档 §4.1/§4.2）；这两枚胶囊悬浮在页面中部，
 *         原写法必判 `Material inactive: out of scope`。搭壳后位置/大小/间距一行未改，只有玻璃来源
 *         从自绘换成官方沉浸材质。
 * false = 回退改造前的 SortRowOverlay 自绘玻璃浮层（segGlass + backgroundBlurStyle 真磨砂）。
 * ⚠️ 待真机验证：「底部 TabBar 槽位**子树**内挂 systemMaterial 是否生效」。此前只有
 *    Navigation 标题栏子树（§1.5）与 CustomDialog 子树（§1.4）被真机验证过；若 hilog 报
 *    `Material inactive: out of scope`，把本开关置 false 即整行回退到旧浮层。
 */
const THREAD_DETAIL_SORT_OFFICIAL_SLOT: boolean = true;
/**
 * 排序行高度（vp）= padding top 4 + 胶囊 34 + bottom 8 = 46 ——
 * 与改造前 SortRowOverlay 内 ReplyControls 的实际占高逐项一致，用作 Tabs 壳高与 barHeight。
 */
const THREAD_DETAIL_SORT_ROW_HEIGHT: number = 46;

/**
 * 平板适配 §4.9 DT-I：横屏分栏时的**左栏固定宽度**（vp）= 用户说的「帖子本身宽度」。
 * 420 为推荐值（备选 368 = 宫格自然宽 336 + 卡片内边距 32；480 让正文行长更舒适）。
 * 只在 splitMode() 为 true（大屏横屏）时生效，手机与平板竖屏不走该分支。
 */
const DETAIL_MAIN_WIDTH: number = 420;
/**
 * 平板适配 §4.9 DT-J：宫格图宽度上限（vp）= 3 × 108 + 2 × 6，使每格 ≈ 108vp（手机档 94.7vp 的邻近量级）。
 * 宽屏下 Grid 若继续 width('100%')，三列会被均分到 1000+vp（每格 ≈ 320vp）而格高恒 120 → 图片被横向拉伸。
 * 手机档宫格可用宽 ≈ 296vp < 上限 → 不生效（逐像素不变，无需形态闸门）。
 */
const DETAIL_IMAGE_GRID_MAX_WIDTH: number = 336;
/**
 * 底部悬浮栏（评论输入条）平板档宽度（vp）= **400**（2026-09-16 用户拍板「底栏 = 跳转官方弹窗宽度」，
 * 横竖屏同值；原 592「现有基础宽一倍」作废；与首页 / 他人信息页底栏 400 统一口径）。
 * ⚠️ 教训：不可把这个量级的值当成「所有手机的屏宽基线」对手机封顶 —— 393vp 等机型手机档
 * 「屏宽 − 64」= 329，若误用平板档封顶会把手机底栏实实在在收窄（用户真机已驳回一次）；
 * 手机档必须保持原「屏宽 − 64」公式（见 `dockPillWidth()` 分档）。
 * 跳转框（原回复框）在岛内为 `layoutWeight(1)`，随岛宽自动拉伸，无需单独处理。
 * 排序壳左缘公式引用 dockPillWidth() 自动跟随（-40 微调值可能需真机复核）。
 */
const DETAIL_DOCK_TABLET_WIDTH: number = 400;
/**
 * 回复区多列「列均衡」阈值（vp，方案 B 滞回，2026-09-14）：
 * 轮转目标列与最短列的估算高差超过该值时，本卡改投最短列（补位）；否则照常轮转（保序）。
 * 取 240 ≈ 一张短卡高：小波动不乱序（横向看楼层基本递增），只有连续长卡压弯一列才插空。
 */
const DETAIL_COL_BALANCE_THRESHOLD: number = 240;

/**
 * 「帖子沉浸式阅读」（设置 → 个性化，AppStorage `immersiveReading`，2026-09-18）：
 * 向下滑累计 24vp → 藏起顶栏三钮 / 排序胶囊 / 评论底栏；向上滑累计 12vp → 恢复显示。
 * 阈值不对称（24 / 12，用户拍板）：上滑更容易唤出，符合「要操作就先给我 UI」的预期。
 */
const IMMERSIVE_READ_HIDE_DIST: number = 24;
const IMMERSIVE_READ_REVEAL_DIST: number = 12;
/**
 * 置顶保护阈值（vp）：滚动位置 ≤ 该值视为「在顶部」，恒显示不隐藏（用户 2026-09-18 明确要求）。
 * 含回弹负值；没有这条保护，滑到底后再回顶会看不到返回钮（本页唯一返回入口）。
 */
const IMMERSIVE_READ_TOP_KEEP: number = 8;
/**
 * 跳变保护阈值（vp）：单次回调位移超过该值视为命令式滚动（消息楼层定位 scrollTo）或形态切换
 * （旋转 / 分栏切换 / 小窗翻档）造成的跳变，丢弃本次方向判定，避免误藏 / 误露。
 */
const IMMERSIVE_READ_JUMP_LIMIT: number = 240;
/**
 * 沉浸阅读显隐动画（2026-09-18 三轮 / DT-N，用户拍板）：藏起 / 唤出**不对称** ——
 * 向下滚是「把 UI 收起来」，要利落：180ms EaseIn（起步快、收尾缓）；
 * 向上滑是「把 UI 要回来」，可以稍长且带一点过冲：260ms + springMotion 轻回弹。
 */
const IMMERSIVE_HIDE_MS: number = 180;
const IMMERSIVE_SHOW_MS: number = 260;
/** 唤出弹簧（curves.springMotion）：response 越小越快；dampingFraction < 1 才回弹（0.86 ≈ 轻微过冲） */
const IMMERSIVE_SHOW_SPRING_RESPONSE: number = 0.28;
const IMMERSIVE_SHOW_SPRING_DAMPING: number = 0.86;
/**
 * 沉浸位移比例（2026-09-18 三轮）：位移不再「飞出屏」，改为约 **0.6 倍自身高**，
 * 余下部分交给 `opacity(0)` 淡掉 —— 观感从「嗖地飞走」变成「收回去」；
 * 顺带把位移量与各形态档几何解耦（原来一个 +200 余量把所有档都拉到同一个出屏量）。
 */
const IMMERSIVE_FLY_SCALE: number = 0.6;
/**
 * 沉浸阅读「玻璃侧」错帧编排（DT-N，2026-09-18 三轮，2026-09-19 回退 P-B′ 后恢复）：
 * 官方悬浮岛的玻璃由**系统**绘制（`barFloatingStyle.systemMaterial`），改参瞬时生效、应用层插不进动画，
 * 与槽内容（应用节点，180ms / 260ms）**不同步**。故把玻璃侧的「撤 / 给」与内容侧错开：
 * 藏起 = 内容先起步、玻璃晚撤 `IMMERSIVE_GLASS_LAG_MS`（撤玻璃那一刻槽内已不可见 ⇒ 空槽，硬切被藏住）；
 * 唤出 = 玻璃先给、内容延后 `IMMERSIVE_GLASS_LEAD_MS`（顺序不可反：内容先滑回时玻璃会在归位途中凭空出现）。
 */
const IMMERSIVE_GLASS_LAG_MS: number = 180;
const IMMERSIVE_GLASS_LEAD_MS: number = 16;

/**
 * 楼中楼预览点赞补齐（§Z4a，2026-09-19）：
 * 首屏补齐延后起跑，让首屏渲染与下一页预取先占住连接池；补齐锁被占时按重试间隔轮询，
 * 保证被 loadMore 抢先的首页楼层最终仍会被补齐（预览点赞不会永久停在 0）。
 */
const SUBPOST_ENRICH_DELAY_MS: number = 400;
const SUBPOST_ENRICH_RETRY_MS: number = 400;

/**
 * 帖子详情「滚动预取」（2026-09-19，无感翻页）：滚动位置距底部不足该值（vp）时提前消费/触发下一页，
 * 让「触底」这一刻数据已在列表里 —— 用户滑到底看到的是内容直接续上，而不是等加载。
 * 取 1600 > 列表页 1200：详情楼层卡更高、单页请求更重，需要更长的提前量。
 */
const DETAIL_PREFETCH_DISTANCE: number = 1600;
/** 滚动预取节流步长（vp）：偏移变化超过该值才允许再次触发，避免同一轮滚动连续请求（口径同 ThreadList） */
const DETAIL_PREFETCH_THROTTLE: number = 120;
/**
 * 尾部加载提示延迟（ms，折中口径）：后台预取路径先静默（不显形、不转圈），超过该时长仍未返回才浮出
 * loading 文案 —— 绝大多数请求 300~600ms 返回，用户永远看不到"正在加载"。
 */
const DETAIL_LOAD_HINT_DELAY: number = 1200;
/** 尾部哨兵固定高度（vp）：三态（静默占位 / loading / 失败重试）等高，追加内容时视口不位移 */
const DETAIL_FOOTER_SENTINEL_H: number = 56;

// 官方贴吧（鸿蒙版）包名与帖子页 URL 模板：跳转仅携带 tid，不含任何登录态参数
const TIEBA_OFFICIAL_BUNDLE: string = 'com.baidu.tiebaapp';
const TIEBA_MARKET_URL: string = 'https://appgallery.huawei.com/app/detail?id=com.baidu.tiebaapp';

// 贴吧图片缩略图 URL 归一：实现自 v1.26 起移至 ImageCache.toThumbUrl ——
// 服务层「点击即预热」（TiebaService.warmDetailPreviewImages）必须与页面显示侧对同一 URL 形态做缓存，
// 否则预热下载的文件在这里永远命不中。此处保留同名薄壳，本文件调用点零改动。
function resolveThumbUrl(url: string): string {
  return ImageCache.toThumbUrl(url);
}

// 楼层数据源（原 LazyForEach 数据提供器）。楼层现改为 Scroll + ForEach 全量渲染，
// 该实例仅随 floors 冗余同步（setData/append/updateItem），无 UI 监听，保留以最小化改动面。
class FloorDataSource implements IDataSource {
  private data: FloorItem[] = [];
  private listeners: DataChangeListener[] = [];

  setData(items: FloorItem[]): void {
    this.data = items;
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }

  updateItem(index: number, item: FloorItem): void {
    if (index < 0 || index >= this.data.length) {
      return;
    }
    this.data[index] = item;
    for (const l of this.listeners) {
      l.onDataChange(index);
    }
  }

  append(items: FloorItem[]): void {
    if (!items || items.length === 0) {
      return;
    }
    const start: number = this.data.length;
    this.data = [...this.data, ...items];
    for (const l of this.listeners) {
      l.onDataAdd(start);
    }
  }

  totalCount(): number {
    return this.data.length;
  }

  getData(index: number): FloorItem {
    return this.data[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    this.listeners.push(listener);
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const idx: number = this.listeners.indexOf(listener);
    if (idx >= 0) {
      this.listeners.splice(idx, 1);
    }
  }
}

// 楼层/九宫格缩略图组件：网格用 200 宽缩略图。
// 显示优先级：① 本地真图（ImageCache 缓存 / resolve 落地）→ ② 直连缩略图（挂载即发，快速上屏）→ ③ 灰底占位。
// v1.20：新增阶梯延迟重试（2s + 8s）。新帖子 pic/item 路径 CDN 同步延迟可达 10~30s，
// 首次直连被防盗链拦截 + ImageCache 候选镜像全返回 4262 占位时，
// 不立即锁死降级，等镜像同步后再次 resolve 多数能命中。
// v1.25（2026-09-19）：直连结果先过「占位遮罩」（见 build）——保住直连的速度，同时绝不让贴吧 logo 上屏。
// v1.24：resolve（落地缓存 / 自愈）改为**进入视口才发起**；直连不受此门控（见 aboutToAppear）。

/**
 * v1.24（2026-09-19）详情页「按需 resolve」安全网探针：
 * 任一处 onVisibleAreaChange 回调触发即置 true。若挂载 1.5s 后仍为 false —— 说明可见性回调在本页
 * 环境（全量渲染 + expandSafeArea + clip(false)）里没生效 —— 则所有尚未发起 resolve 的图片退回
 * 「挂载即发起」的旧行为，保证缓存不会因为门控失效而永不落地。
 * 回调只要生效就必定由首屏那几张先置位，故正常路径下这个兜底永不触发。
 */
let GRID_VISIBILITY_PROBE_FIRED: boolean = false;
const GRID_VISIBILITY_FALLBACK_MS: number = 1500;

@Component
struct ThreadGridImage {
  @Prop src: string = '';
  @Prop isDark: boolean = false;
  /** 本地真图（file://）—— 显示优先级最高 */
  @State current: string = '';
  /** 直连图已确认为真图（未被贴吧占位模板命中）→ 撤除遮罩 */
  @State directOk: boolean = false;
  /** 直连用的 CDN URL（挂载即取，快速上屏；空表示不走直连） */
  private directUrl: string = '';
  private retryScheduled: boolean = false;
  /** 已落地本地真图：终态，重试链就此收工 */
  private resolvedLocal: boolean = false;
  /** 解析在途：重试链不得重复占闸门槽位（否则同一张图在队列里排两次） */
  private resolving: boolean = false;
  /** v1.24：resolve 是否已发起（视口门控：见 startResolve 与 build 内 onVisibleAreaChange） */
  private started: boolean = false;

  /** 返回是否已拿到本地真图。priority=1（视口内插队）时闸门优先发放槽位（2026-09-20 P2） */
  private async attemptResolve(thumb: string, priority: number = 0): Promise<boolean> {
    if (this.resolvedLocal) {
      return true;
    }
    if (this.resolving) {
      return false;
    }
    this.resolving = true;
    // §IMGQ：楼层宫格是全量渲染出来的（Scroll + ForEach 一次建出上百个本组件），
    // 此前只有列表卡片走全局闸门、详情页完全裸奔 → 进帖瞬间上百个下载同时涌出，
    // 与接口请求抢同一条会话（实测接口 0.9s → 3.5~5.0s）。
    // 现接入列表同款全局闸门（8 并发，FIFO 发放），即楼层从上到下依次到图。
    let local: string = '';
    try {
      await acquireImagePreloadSlot(priority);
      try {
        local = await ImageCache.resolve(thumb);
      } finally {
        releaseImagePreloadSlot();
      }
    } catch (e) {
      local = '';
    } finally {
      this.resolving = false;
    }
    // v1.22 修复（首次进帖宫格图不显示、返回重进才正常）：
    // 这里原先是 `if (this.fallbackTriggered) return;`。直连失败 / 200×200 防盗链占位是在
    // Image 组件侧百毫秒内就置位的，而闸门后的 resolve 要排队数秒才返回 —— 于是解析出来的
    // 本地真图被这行闸刀丢弃，current 停在灰色占位图上；重试链又被同一个标记短路成空转
    // （tick → attemptResolve 首行即 return），首次进帖永不恢复。
    // 返回重进时 aboutToAppear 走 getCachedPath 命中，才「正常」。
    // 现在只认「拿到本地文件」为终态，直连失败不再阻断解析结果落地。
    if (local.length > 0 && local !== thumb) {
      this.resolvedLocal = true;
      this.current = local;
      return true;
    }
    // v1.23（2026-09-19）：解析未拿到本地真图时**不再回退到 CDN 直连原图** ——
    // 直连 URL 交给 Image 的后果是贴吧图床返回 200×200 logo 占位图（HTTP 200、被当作加载成功），
    // 表现为宫格「先显示贴吧 logo、随后才被真图替换」。现统一保持灰底，只等 ImageCache 真图。
    return false;
  }

  /**
   * v1.24：进入视口（或安全网兜底）后发起 resolve；同一实例只发起一次。
   * 2026-09-20（P2）：视口回调路径 priority=1（插队，用户刚滚到的格子最先落地）；
   * 1.5s 安全网兜底路径 priority=0（与后台预取同档）。
   */
  private startResolve(priority: number = 1): void {
    if (this.started || this.resolvedLocal) {
      return;
    }
    this.started = true;
    this.attemptResolve(resolveThumbUrl(this.src), priority).catch(() => { /* 失败由阶梯重试兜底 */ });
  }

  private scheduleStaggeredRetry(url: string): void {
    if (this.retryScheduled || this.resolvedLocal) {
      return;
    }
    this.retryScheduled = true;
    const delays: number[] = [2000, 8000];
    let idx: number = 0;
    const tick = (): void => {
      if (this.resolvedLocal) {
        return;
      }
      this.attemptResolve(url).then((ok: boolean) => {
        // 拿到本地真图即成功（Image 已可加载 file://）
        if (ok || this.resolvedLocal) {
          return;
        }
        idx++;
        if (idx < delays.length) {
          setTimeout(tick, delays[idx] - delays[idx - 1]);
        }
      }).catch(() => { /* 静默失败,占位已被 onError 兜底 */ });
    };
    setTimeout(tick, delays[0]);
  }

  aboutToAppear(): void {
    const thumb: string = resolveThumbUrl(this.src);
    if (!thumb.startsWith('http://') && !thumb.startsWith('https://')) {
      // 非 http（理论上的本地路径）：原样渲染并视为终态
      if (thumb.length > 0) {
        this.resolvedLocal = true;
        this.current = thumb;
      }
      return;
    }
    // Z1 同步命中（比 getCachedPath 多一道「文件大小已达灰阶校验豁免档」判定，语义是 resolve 的子集）
    // → 直接渲染本地真图，零等待
    const cached: string | null = ImageCache.getVerifiedCachedPath(thumb);
    if (cached !== null) {
      this.resolvedLocal = true;
      this.current = cached;
      return;
    }
    // v1.25（2026-09-19）「宫格图秒加载」修复：**直连挂载即发起**，不等可见性回调。
    // 直连（系统 Image 自己抓缩略图）就是原版「进门就出图」的那条路，保留它最快；
    // 直连若拿到贴吧 logo 占位图，会被 build 里的遮罩挡住、不上屏（v1.23 目标不变）。
    // resolve（落地缓存 + 防盗链自愈）仍按视口门控发起 —— 它才是与接口争抢 rcp 会话的那部分，
    // 上百张同时发起会把接口拖慢（§IMGQ 要压的洪峰）；可见性回调失效时由 1.5s 安全网兜底。
    this.directUrl = thumb;
    setTimeout(() => {
      if (!GRID_VISIBILITY_PROBE_FIRED) {
        // 安全网兜底：非视口路径，与后台预取同档（不插队）
        this.startResolve(0);
      }
    }, GRID_VISIBILITY_FALLBACK_MS);
  }

  build() {
    if (this.current.length > 0) {
      // ① 本地真图（缓存命中 / resolve 成功）：优先级最高
      Image(this.current)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        // 图片网格圆角 18：卡片为 26，网格单格仅约屏宽 1/3，26 显得过圆，故单独收一档；
        // 不借用全局 Radius.md（=12）；本组件仅供本文件 ImageGrid 使用（楼主卡、楼层卡、楼中楼三处共用）
        .borderRadius(18)
        .alt(this.isDark ? '#2A2A2E' : '#E9E9EB')
        .onError(() => {
          // 本地文件损坏（读不出）→ 退回「直连 + 遮罩」态并解除终态，交给阶梯重试重新解析；
          // 重试链本身封顶两档（2s/8s），不会因此兜圈。
          this.resolvedLocal = false;
          this.current = '';
          this.directUrl = resolveThumbUrl(this.src);
          this.scheduleStaggeredRetry(this.src);
        })
    } else {
      // ② 直连（快速上屏）+ ③ 灰底遮罩：直连结果只有「确认为真图」才撤遮罩
      Stack() {
        if (this.directUrl.length > 0) {
          Image(this.directUrl)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .borderRadius(18)
            .onComplete((event) => {
              if (!event || event.loadingStatus !== 1) {
                return;
              }
              // 贴吧图床对无 Referer/UA 的直连请求返回 200×200 / 238×238 logo 占位图（HTTP 200，
              // 不是错误码）→ 命中即**保持遮罩**，绝不把 logo 画上屏；真图则撤遮罩（这一帧即见）。
              // 直连因此既保住「秒出图」的速度，又不会闪 logo（v1.23 目标不变）。
              const ph: boolean = (event.width === 200 && event.height === 200)
                || (event.width === 238 && event.height === 238);
              if (!ph) {
                this.directOk = true;
              }
            })
            .onError(() => { /* 直连失败：保持遮罩，等 resolve */ })
        }
        if (!this.directOk) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(this.isDark ? '#2A2A2E' : '#E9E9EB')
            .borderRadius(18)
        }
      }
      .width('100%')
      .height('100%')
      .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, ratio: number) => {
        // v1.24：resolve 的视口门控挂在**始终存在**的 Stack 上 —— 不能挂在遮罩上，
        // 否则「撤遮罩」会把门控节点一并摘掉，导致缓存永不落地
        GRID_VISIBILITY_PROBE_FIRED = true;
        if (isVisible) {
          this.startResolve();
        }
      })
    }
  }
}

// 头像组件：接入 ImageCache，命中本地缓存直接渲染；未命中显示外层首字母占位，等 ImageCache 取回真图
@Component
struct AvatarImage {
  @Prop url: string = '';
  @Prop avatarSize: number = 36;
  @State current: string = '';
  /** v1.23：本地文件损坏后只允许重解析一次，避免与图片刷新互相兜圈 */
  private retried: boolean = false;
  /** v1.24：resolve 是否已发起（视口门控，见 startResolve 与 build 内 onVisibleAreaChange） */
  private started: boolean = false;
  /** v1.25：直连图已确认为真图 → 撤除首字母遮罩 */
  @State directOk: boolean = false;
  /** v1.25：直连用的 CDN URL（挂载即取，快速上屏） */
  private directUrl: string = '';

  aboutToAppear(): void {
    if (this.url.startsWith('http://') || this.url.startsWith('https://')) {
      // Z1 同步命中 → 直接渲染本地真图，零等待
      const cached: string | null = ImageCache.getVerifiedCachedPath(this.url);
      if (cached !== null) {
        this.current = cached;
        return;
      }
      // v1.25：直连**挂载即发起**（原版时序，最快上屏）；直连若拿到贴吧 logo 占位图，
      // 会被 build 里那层「首字母遮罩」挡住、不上屏。
      this.directUrl = this.url;
      // resolve（落地缓存）仍按视口门控发起 —— 头像数量与楼层同级，全量挂载时同样是几十上百个
      // 并发占住闸门槽位、把首屏宫格挤到队尾；可见性回调失效时由 1.5s 安全网兜底。
      setTimeout(() => {
        if (!GRID_VISIBILITY_PROBE_FIRED) {
          this.startResolve();
        }
      }, GRID_VISIBILITY_FALLBACK_MS);
    } else if (this.url.length > 0) {
      // 非 http（理论上的本地路径）：原样渲染
      this.current = this.url;
    }
  }

  /** v1.24：进入视口（或安全网兜底）后发起 resolve；同一实例只发起一次 */
  private startResolve(): void {
    if (this.started || this.current.length > 0) {
      return;
    }
    this.started = true;
    this.resolveGated().catch(() => { /* 失败保持首字母占位 */ });
  }

  /** §IMGQ：头像同样并入全局图片闸门 —— 楼层与楼中楼各有头像，29 楼一次性就是几十个并发 */
  private async resolveGated(): Promise<void> {
    await acquireImagePreloadSlot();
    let local: string = '';
    try {
      local = await ImageCache.resolve(this.url);
    } finally {
      releaseImagePreloadSlot();
    }
    if (local === '') {
      this.current = ''; // 确认占位图：保持空，显示外层首字母
    } else if (local.length > 0 && local !== this.url) {
      this.current = local;
    }
  }

  build() {
    if (this.current.length > 0) {
      Image(this.current)
        .width(this.avatarSize)
        .height(this.avatarSize)
        .borderRadius(Radius.full)
        .objectFit(ImageFit.Cover)
        .onError(() => {
          // 本地文件损坏 → 退回「直连 + 首字母遮罩」态，并允许重解析一次（有界不兜圈）
          this.current = '';
          this.directUrl = this.url;
          if (!this.retried) {
            this.retried = true;
            this.resolveGated().catch(() => { /* 失败保持首字母 */ });
          }
        })
    } else {
      Stack() {
        if (this.directUrl.length > 0) {
          Image(this.directUrl)
            .width(this.avatarSize)
            .height(this.avatarSize)
            .borderRadius(Radius.full)
            .objectFit(ImageFit.Cover)
            .onComplete((event) => {
              if (!event || event.loadingStatus !== 1) {
                return;
              }
              // 贴吧占位模板（200×200 / 238×238）→ 保持首字母遮罩，不上屏
              const ph: boolean = (event.width === 200 && event.height === 200)
                || (event.width === 238 && event.height === 238);
              if (!ph) {
                this.directOk = true;
              }
            })
            .onError(() => { /* 直连失败：保持首字母遮罩，等 resolve */ })
        }
        if (!this.directOk) {
          // 首字母占位层（透明）：外层首字母底可见，同时充当直连占位图的遮罩
          Column().width(this.avatarSize).height(this.avatarSize).borderRadius(Radius.full)
        }
      }
      .width(this.avatarSize)
      .height(this.avatarSize)
      .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, ratio: number) => {
        // v1.24：门控挂在始终存在的 Stack 上（撤遮罩不会摘掉门控节点）
        GRID_VISIBILITY_PROBE_FIRED = true;
        if (isVisible) {
          this.startResolve();
        }
      })
    }
  }
}

/**
 * 跳转官方贴吧确认弹窗（系统 CustomDialog + API 26 沉浸光感）。
 *
 * 原为「页面 body 顶层 Stack 自绘浮层」（宿主 @Builder JumpConfirmDialog）→ 换成系统 CustomDialog。
 * 依据（工程文档 §1.2 / §8）：官方沉浸材质生效范围只有**系统弹窗（CustomDialog）/ 半模态 / Navigation
 * 标题栏 / 底部 Tabs 槽位**，页面 body 内的自绘浮层挂 systemMaterial 必然判
 * `Material inactive: out of scope` —— 改造前卡上那行 `.systemMaterial(ImmMaterial.control())` 一直在空转，
 * 真正起作用的只有自绘 `backgroundEffect` 真模糊（比官方材质低一档的观感）。
 *
 * 几何与内容对齐（§4.3 对齐表，逐项与改造前一致）：
 * - 宽度 `calc(100% - 48vp)` → `options.width` 数值 vp（宿主 dialogCardWidth()）；
 *   圆角 32vp、遮罩 #06000000、居中锚点（改造前本就是屏幕居中卡片）；
 *   标题 / 说明 / 链接预览 / 两枚按钮的字号、尺寸、间距全部原样保留（按钮仍是竖排全宽）。
 * - 卡内不再自绘 backgroundColor / backgroundEffect / border / shadow / systemMaterial 五项（材质会接管）。
 * - 两枚按钮挂材质 + 半透明底 + 轻投影，与收藏页确认弹窗、进吧页一键签到弹窗同源（文档 §6.2）；
 *   底色必须带透明度，不透明底会完全盖掉材质滤镜（坑 11）。
 *
 * 数据传递：链接预览走 @Link 快照 —— `threadWebUrl()` 是宿主方法，弹窗内取不到。
 */
@CustomDialog
struct JumpTiebaDialogCard {
  /** 系统弹窗必须声明 CustomDialogController 类型属性（ArkTS 编译期强校验，§3.3） */
  controller?: CustomDialogController;
  @Link isDark: boolean;
  @Link fontScale: number;
  /** 目标链接预览（宿主在打开前算好并写入） */
  @Link targetUrl: string;
  /** 确定：拉起官方贴吧（业务全在宿主 confirmJump，弹窗只负责回调） */
  onConfirm: () => void = () => {};
  /** 取消 / 点遮罩 / 返回键（同源，宿主 onWillDismiss 与取消钮共用） */
  onDismiss: () => void = () => {};

  build() {
    Column() {
      // 标题 + 说明 + 目标链接预览
      Column({ space: 6 }) {
        Text('跳转到官方贴吧')
          .fontSize(fs(17, this.fontScale))
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.textPrimary(this.isDark))
          .textAlign(TextAlign.Center)
        Text('将在官方贴吧中打开本帖（仅携带帖子 ID，不含登录信息）')
          .fontSize(fs(13, this.fontScale))
          .fontColor(Theme.textSecondary(this.isDark))
          .lineHeight(fs(18, this.fontScale))
          .textAlign(TextAlign.Center)
        Text(this.targetUrl)
          .fontSize(fs(12, this.fontScale))
          .fontColor(Theme.textSecondary(this.isDark))
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ left: Spacing.lg, right: Spacing.lg, top: Spacing.lg, bottom: Spacing.md })

      // 确定 / 取消（竖排全宽，与改造前逐项一致）
      Column({ space: Spacing.sm }) {
        Button() {
          Text('确定')
            .fontSize(fs(15, this.fontScale))
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
        }
        .width('100%')
        .height(44)
        // 品牌蓝主按钮：材质 + 半透明底 + 同色浮起阴影（与收藏页确认弹窗主按钮同源）
        .systemMaterial(ImmMaterial.accent(this.isDark))
        .backgroundColor('#CC3173FF')
        .borderRadius(Radius.full)
        .shadow({
          radius: 14,
          color: this.isDark ? '#663173FF' : '#4D3173FF',
          offsetY: 4
        })
        .accessibilityText('确认跳转官方贴吧')
        .onClick(() => { this.onConfirm(); })

        Button() {
          Text('取消')
            .fontSize(fs(15, this.fontScale))
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.textPrimary(this.isDark))
        }
        .width('100%')
        .height(44)
        // 次按钮：材质 + 半透明底 + 中性轻投影（底色不透明会盖掉材质）
        .systemMaterial(ImmMaterial.cardAction())
        .backgroundColor(this.isDark ? '#B31B1E24' : '#B3FFFFFF')
        .borderRadius(Radius.full)
        .shadow({ radius: 10, color: this.isDark ? '#4D000000' : '#1F101824', offsetY: 3 })
        .accessibilityText('取消跳转')
        .onClick(() => { this.onDismiss(); })
      }
      .width('100%')
      .padding({ left: Spacing.lg, right: Spacing.lg, bottom: Spacing.lg })
    }
    .width('100%')
    .padding({ top: Spacing.md })
  }
}

@Entry
@Component
struct ThreadDetail {
  @State tid: string = '';
  @State detail: ThreadDetailModel | null = null;
  @State floors: FloorItem[] = [];
  // @State floors：楼层数据实体，Scroll + ForEach 全量渲染直接读取，赋值即驱动 UI 刷新
  private floorDataSource: FloorDataSource = new FloorDataSource();
  @State loadState: LoadState = LoadState.Loading;
  @State errorMsg: string = '';
  @State isDark: boolean = isDarkMode();
  @State commentText: string = '';
  @State replyTarget: string = '';   // 回复目标（楼层作者）
  @State sending: boolean = false;
  @State pendingReply: boolean = false;
  @State readyEmojiUrls: string[] = []; // EmojiLoader 下载转 PixelMap 成功的 URL（有这个就有 PixelMap 可 ImageSpan 渲染）
  @State failedEmojiUrls: string[] = []; // EmojiLoader 下载失败的 URL → 兜底显示中文文本
  /**
   * 长按复制（docs/帖子详细页长按复制文字功能补全.md）：各正文 Text 的「复制重建纪元」。
   * 复制完成后自增对应 key → RichTextContent 内单元素 ForEach 的 key 变化 → Text 节点整体重建
   * → 选中态随节点销毁清除。用 per-region key 而非共享 selection(start,end) 绑定：
   * selection 属性绑共享 @State 会把同一段选中范围套到所有绑定 Text 上（跨楼层串扰）；
   * 纪元重建只重建被复制的那一个节点。Record 更新须整体赋新对象触发重渲染（同 gridThumbFallbacks 口径）。
   */
  @State copyEpochs: Record<string, number> = {};

  /** 读取某正文区域的复制重建纪元（缺省 0；ForEach key 生成用） */
  private copyEpochOf(regionKey: string): number {
    return this.copyEpochs[regionKey] ?? 0;
  }

  /** 复制成功回调：toast 提示 + 自增纪元清除该 Text 的选中态 */
  private onTextCopied(regionKey: string): void {
    this.getUIContext().getPromptAction().showToast({ message: '复制成功' });
    // ArkTS 禁止对象展开（arkts-no-spread），Record 拷贝走 Object.keys 逐键赋值；
    // 其余 key 保留原值（纪元不变 → 对应 Text 节点不重建），只有被复制的区域自增
    const next: Record<string, number> = {};
    Object.keys(this.copyEpochs).forEach((k: string) => {
      next[k] = this.copyEpochs[k];
    });
    next[regionKey] = (this.copyEpochs[regionKey] ?? 0) + 1;
    this.copyEpochs = next;
  }

  private hasReadyEmoji(url: string): boolean {
    return EmojiLoader.has(url) || (this.readyEmojiUrls.indexOf(url) !== -1);
  }
  private hasFailedEmoji(url: string): boolean {
    return this.failedEmojiUrls.indexOf(url) !== -1;
  }
  // 通过 EmojiLoader + Referer 预取表情，成功后 readyEmojiUrls 加条目触发重绘
  private prefetchEmojisWithLoader(urls: string[]): void {
    for (const u of urls ?? []) {
      if (!u || u.length === 0) continue;
      if (EmojiLoader.has(u)) {
        if (this.readyEmojiUrls.indexOf(u) === -1) {
          this.readyEmojiUrls = [...this.readyEmojiUrls, u];
        }
        continue;
      }
      if (this.failedEmojiUrls.indexOf(u) !== -1) continue;
      EmojiLoader.ensure(u).then(() => {
        if (this.readyEmojiUrls.indexOf(u) === -1) {
          this.readyEmojiUrls = [...this.readyEmojiUrls, u];
        }
      }).catch(() => {
        if (this.failedEmojiUrls.indexOf(u) === -1) {
          this.failedEmojiUrls = [...this.failedEmojiUrls, u];
        }
      });
    }
  }

  // 兼容：隐藏预取器的 onComplete/onError 回调也会把结果写入 readyEmojiUrls/failedEmojiUrls（双保险）
  private markEmojiLoaded(url: string) {
    if (this.readyEmojiUrls.indexOf(url) === -1) {
      this.readyEmojiUrls = [...this.readyEmojiUrls, url];
    }
  }
  private markEmojiFailed(url: string) {
    if (this.failedEmojiUrls.indexOf(url) === -1) {
      this.failedEmojiUrls = [...this.failedEmojiUrls, url];
    }
  }
  @State pendingLinkUrl: string = '';
  @State showLinkDialog: boolean = false;
  /**
   * 跳转官方贴吧确认弹窗显隐（系统 CustomDialog + API 26 沉浸光感）。
   * 宿主已由「页面 body 内自绘 Stack 浮层」换成系统 CustomDialog —— 官方材质只认系统弹窗类宿主，
   * 自绘浮层挂 systemMaterial 必然判 out of scope（工程文档 §1.2 / §8）。
   * 保留单一布尔状态，真正 open/close 由 @Watch 驱动，既有 `this.showJumpDialog = x` 调用点零改动。
   */
  @State @Watch('onShowJumpChanged') showJumpDialog: boolean = false;
  /** 弹窗内的链接预览快照（`threadWebUrl()` 是宿主方法，不能进 @CustomDialog，§6.3） */
  @State jumpUrlPreview: string = '';
  @State focusInput: boolean = false;
  @State forumName: string = '';
  @State forumId: string = '';
  @State sortType: number = 0;
  @State seeLz: boolean = false;
  @State liked: boolean = false;
  @State collected: boolean = false;
  /**
   * 长按收藏钮 → 分类面板（复用 components/FavCategoryPicker，§6.8 系统半模态）。
   * 副作用边界（用户拍板方案 A）：面板内只做勾选 / 新建分类，**不写库**；只有「完成」回调
   * （applyPickCategory）才执行「收藏 + 归类」——下滑 / 点遮罩关闭 = 零副作用（误触无痕）。
   */
  @State pickerShow: boolean = false;
  /** 面板内分类列表 / 帖↔分类映射：打开面板时按账号现读（组件 @Link 双向绑定，新建分类会整体回写） */
  @State pickerCategories: FavCategory[] = [];
  @State pickerMappings: CategoryMapping[] = [];
  /** 面板勾选集合（分类 id；CATEGORY_DEFAULT_ID = 未分类，与具体分类互斥） */
  @State pickerChecked: string[] = [];
  /** 面板内新建分类输入态（置 true 时输入行展开，收起不关面板） */
  @State pickerCreating: boolean = false;
  /** 面板参与操作的帖子快照（本页恒为当前帖，@Prop 传给组件用于计数） */
  @State pickerTargets: string[] = [];
  /** 面板落库账号（打开面板时取自 AuthManager，@Prop 传给组件供新建分类写入） */
  @State pickerAccountId: string = '';
  @State commentRn: number = 3;
  @State commentLoading: boolean = false;
  @State openingSubPost: boolean = false;
  // 楼中楼预览点赞补齐：本会话已通过 pb/floor 校正过点赞的楼层集合（避免重复请求）
  private subPostLikesFetched: Set<string> = new Set<string>();
  private enrichingSubPostLikes: boolean = false;
  // §Z4a：首屏缺赞补齐的延后调度器（-1 表示空闲）
  private enrichTimer: number = -1;
  // 分页加载楼层：currentPage 追踪当前已加载到第几页，loadingMore 防止重复请求
  @State currentPage: number = 1;
  @State loadingMore: boolean = false;
  @State hasMoreFloors: boolean = true;
  @State totalFloorPage: number = 1;
  // ===== 无感翻页（2026-09-19）：滚动预取 + 尾部哨兵折中 =====
  /** 尾部加载提示是否浮出：后台预取路径超时（DETAIL_LOAD_HINT_DELAY）才置 true，用户显式触发/已触底立即置 true */
  @State loadingHintVisible: boolean = false;
  /** 尾部加载失败态：仅用户显式路径置位（后台预取失败保持静默，由触底兜底重试） */
  @State loadMoreFailed: boolean = false;
  /** 尾部提示延时器句柄（setTimeout 返回值，-1 = 空闲）：退页时必须清理，防回调落到已销毁组件 */
  private loadingHintTimer: number = -1;
  /** 内容高 / 视口高（vp）：滚动预取剩余距离 = 内容高 - 视口高 - 当前偏移，口径同 HomeTab / ThreadList */
  private detailContentH: number = 0;
  private detailViewportH: number = 0;
  /** 上次触发预取的滚动偏移（-1 = 未触发过）：节流用 */
  private lastPrefetchY: number = -1;
  @StorageLink('fontScale') fontScale: number = 1.0;
  /** 页面可见时自增，强制组件重建使字号实时生效 */
  @State fontSizeTick: number = 0;
  // 骨架屏→内容过渡（2026-09-20 A+C 接力式）：内容初始透明 + 上浮，骨架退场后落定进场
  @State contentOpacity: number = 0.0;
  @State skeletonOpacity: number = 1.0;
  /** 内容进场初始上浮量（vp）：随淡入归零形成"落定"运动感；缓存直出路径直接置 0 */
  @State contentTranslateY: number = CONTENT_RISE_VP;
  /** 骨架屏实际可见时刻（C：最短停留计算用） */
  private skeletonShownAt: number = 0;
  /** 接力过渡进行中标记（防重入：fadeInContent 可能被结果路径与缓存回落路径先后触发） */
  private fadeRelayRunning: boolean = false;
  /** 接力动画代次：loadDetail（切排序/只看楼主/刷新）递增作废在途定时器，防止旧过渡打断新一轮 */
  private fadeGeneration: number = 0;
  /** 2026-09-20（分区上屏）：楼层区构建闸门——false 时楼层/回复头/尾哨兵不进组件树，楼主卡先独立绘制 */
  @State floorsReady: boolean = false;
  /** 2026-09-20（分区上屏）：楼层区进场淡入透明度（随楼主卡落定后 120ms 启动） */
  @State floorsOpacity: number = 0;
  private floorsRevealTimer: number = -1;
  /**
   * 骨架屏是否已获准出现（§P0-4 首屏免骨架屏）：
   * 首屏 open 时先按住 120ms —— 这段窗口内命中缓存（预取/内存/磁盘）就直接出内容，
   * 全程不出现骨架屏，也就没有"骨架屏一闪 → 内容"的白等；超时未出内容才放行骨架屏。
   * 已有内容后的重新加载（切排序 / 只看楼主 / 强制刷新）立即置 true，骨架屏表现与改造前一致。
   */
  @State skeletonVisible: boolean = false;
  /**
   * 形态切换平滑化（2026-09-13）：缓存 `splitMode()` 的**结果**，只在真正跨形态（横↔竖）时
   * 写一次 —— 避免旋转过程中 `currentWidth` / `pageHeight` 每帧变化导致布局分支反复求值、
   * 触发多次全量重建（楼层卡全部重建是「切换卡一下」的主要成本）。
   * 分支渲染统一读本状态（不再直接调 splitMode()），保证一次旋转只切一次。
   */
  @State isSplit: boolean = false;
  // API26+ 真机沉浸光感：materialSupported 为 true 时 build 走官方 Tabs 悬浮条壳（底部 Dock 整体入
  // .tabBar() 槽位，材质由 barFloatingStyle.systemMaterial 悬浮条本体渲染）；其余走原手写叠放路径。
  @State materialSupported: boolean = false;
  /**
   * 官方悬浮条首帧重排触发（2026-09-13；P-B′ 期间随 barFloatingStyle 一并移除，2026-09-19 回退恢复）：
   * 官方悬浮条存在首帧时序问题 —— 首次进入时槽内内容不随岛视觉居中（点赞/收藏/跳转/发送整体偏上、
   * 参差），**旋转一下触发系统重排后才正常**（用户真机复现）。修复 = 进页后对 `barBottomMargin`
   * 施加一次 0.5vp 微变（视觉不可察），模拟旋转的「布局参数变化 → 系统重排悬浮条」。
   * 手机同样会 nudge 一次，0.5vp 无感；若 300ms 不够（数据慢）可再调时机。
   */
  @State dockNudge: number = 0;
  // ===== 「帖子沉浸式阅读」（设置 → 个性化，2026-09-18）=====
  /** 设置项真源：AppStorage `immersiveReading`（UsageHabitsManager 冷启动恢复 / 设置页写入），默认关 */
  @StorageLink('immersiveReading') @Watch('onImmersiveReadingChanged') immersiveReading: boolean = false;
  /**
   * 沉浸态：true = 顶栏三钮 / 排序胶囊 / 评论底栏已藏起。
   * **只存页面局部 @State，绝不写 AppStorage** —— 写全局会让切页 / 换帖残留隐藏态（文档 §6.1 D1 类风险）。
   * 由 onDetailScroll 的方向阈值翻转；关闭开关 / 返回本页 / 触底时立即复位。
   */
  @State immersiveHidden: boolean = false;
  /** 同方向滚动累计量（vp，私有，不参与渲染 —— 逐帧写 @State 会在高刷档掉帧） */
  private immersiveAccum: number = 0;
  /** 上一次滚动位置（vp）：本工程 onScroll 第二参按「累计滚动位置」使用，增量须自算 */
  private immersiveLastY: number = 0;
  /** 滚动位置是否已初始化（首帧只记录不判定，避免拿别处残留值算增量） */
  private immersiveLastReady: boolean = false;
  /**
   * 玻璃侧独立状态位（DT-N）：与内容侧 `immersiveHidden` **不同步**，只驱动 `barFloatingStyle` 的
   * `barWidth`（隐藏态收 0 ⇒ 胶囊无面积 ⇒ 系统不渲染玻璃）。错帧时机见 hideImmersive / showImmersive。
   */
  @State immersiveGlassHidden: boolean = false;
  /** 玻璃侧延时器句柄（setTimeout 返回值，-1 = 空闲）：重排前与退页时清理 */
  private immersiveGlassTimer: number = -1;
  /** 唤出幂等位：置顶保护分支每帧都会调 showImmersive，防止把内容无限顺延（回顶后要等弹跳结束才回来） */
  private immersiveShowPending: boolean = false;
  // 壳分支悬浮岛宽度依赖的屏宽（onAreaChange 实时更新）
  @State currentWidth: number = 360;
  // ===== 平板适配（docs/TiebaPura平板适配.md §4.9）=====
  /** 大屏形态设备（平板 / 2in1 / 折叠屏）：静态判定一次。折叠屏 deviceType 为 'phone'，必须单独用 isFoldable 识别 */
  private readonly isWideFormDevice: boolean = detectWideFormDevice();
  /** 窗口高（vp）：与 currentWidth 配对做横竖屏判定；aboutToAppear 取首帧初值，onAreaChange 兜底 */
  @State pageHeight: number = 800;
  // 从消息页带过来的目标楼层 pid，加载后自动滚动并高亮
  @State targetFloorId: string = '';
  @State highlightFloorId: string = '';
  // 消息定位上下文：isFloor=0（楼中楼回复）时，楼层就位后自动拉起楼中楼详情定位
  @State notifyIsFloor: string = '';
  @State notifyReplyerId: string = '';
  @State notifyReplyerName: string = '';
  @State notifyContent: string = '';
  /** 消息携带的引用评论/楼层 pid（quote_pid）：postId 非楼层 pid 时，以它探测父楼层 */
  @State notifyQuotePid: string = '';
  /** 通知消息原始 post_id（多数场景是楼中楼评论 pid），进楼中楼页后按评论 pid 精确高亮 */
  @State notifyMsgPostId: string = '';
  /** 楼中楼自动定位已触发标志（避免返回本页时重复拉起） */
  private notifySubPostHandled: boolean = false;
  /** 浏览历史本页只写一次（applyDetailResult 会被缓存 / 网络 / 身份补齐多次调用） */
  private historyRecorded: boolean = false;
  /** 楼中楼目标解析已尝试标志（一次性，避免重复探测） */
  private notifyResolveHandled: boolean = false;
  /** 楼层自动定位到底未命中的提示是否已弹出（只提示一次） */
  private locateNoticeShown: boolean = false;
  private scroller: Scroller = new Scroller();
  /** 横屏分栏·左栏独立滚动控制器（§4.9 DT-I）：主楼不参与分页与定位，故不挂 onReachEnd / id */
  private scrollerLeft: Scroller = new Scroller();

  aboutToAppear(): void {
    MaterialManager.init();
    // 首帧形态初值（§4.9 DT-A）：onAreaChange 只在尺寸变化后触发，横屏冷启动若不预置会先按竖屏判定再跳分栏；
    // 顺带把 currentWidth 从写死的 360 换成真实窗口宽（口径与 §4.8 T-B 同源）。
    try {
      const d = display.getDefaultDisplaySync();
      const ui = this.getUIContext();
      const w: number = ui.px2vp(d.width);
      const h: number = ui.px2vp(d.height);
      if (w > 0 && h > 0) {
        this.currentWidth = w;
        this.pageHeight = h;
      }
    } catch (e) {
      // 忽略：窗口未 attach 时取宽高会失败，onAreaChange 会兜底
    }
    // 形态切换平滑化：首帧就固化分栏结果（横屏冷启动直接走分栏，不会先竖后跳）
    this.isSplit = this.splitMode();
    this.materialSupported = MaterialManager.isSupported() && MaterialManager.getApiLevel() >= 26;
    // §P0-4 首屏免骨架屏：120ms 内拿到内容（预取合流 / 内存 / 磁盘缓存命中）则本次打开全程不挂骨架屏；
    // 超时仍无内容才放行。已有内容后的重新加载走 loadDetail 内的立即置位，不进这条延时。
    setTimeout(() => {
      if (this.loadState === LoadState.Loading) {
        this.skeletonVisible = true;
        // C：记录骨架可见时刻，供 fadeInContent 计算最短停留
        this.skeletonShownAt = Date.now();
      }
    }, 120);
    // 首帧重排触发（2026-09-13，回退 P-B′ 后恢复）：300ms = 首帧布局已稳定、且早于用户读完内容。
    setTimeout(() => {
      this.dockNudge = 1;
    }, 300);
    const params = this.getUIContext().getRouter().getParams() as Record<string, string>;
    if (params && params.tid) {
      this.tid = `${params.tid}`;
    }
    if (params && params.forum) {
      this.forumName = `${params.forum}`;
    }
    if (params && params.fid) {
      this.forumId = `${params.fid}`;
    }
    if (params && params.postId) {
      this.targetFloorId = `${params.postId}`;
      this.notifyMsgPostId = `${params.postId}`;
    }
    if (params && params.quotePid) {
      this.notifyQuotePid = `${params.quotePid}`;
    }
    if (params && params.notifyIsFloor) {
      this.notifyIsFloor = `${params.notifyIsFloor}`;
    }
    if (params && params.notifyReplyerId) {
      this.notifyReplyerId = `${params.notifyReplyerId}`;
    }
    if (params && params.notifyReplyerName) {
      this.notifyReplyerName = `${params.notifyReplyerName}`;
    }
    if (params && params.notifyContent) {
      this.notifyContent = `${params.notifyContent}`;
    }
    this.isDark = isDarkMode();
    if (this.tid.length === 0) {
      this.loadState = LoadState.Error;
      this.errorMsg = '缺少帖子 ID，无法打开帖子';
      return;
    }
    this.loadDetail();
  }

  // 详情缓存 key：区分排序方式与"只看楼主"，避免串数据
  private threadDetailCacheKey(): string {
    return `${this.tid}_${this.sortType}_${this.seeLz ? 1 : 0}`;
  }

  // 是否有可读正文内容（正文纯文本 / 富文本片段 / 图片 / 楼层任一非空）。
  // 用于识别"空壳结果"：帖子的标题元数据能解析出来，但正文与楼层全部缺失。
  private hasVisibleDetailContent(detail: ThreadDetailModel | null, floors: FloorItem[]): boolean {
    if (!detail) {
      return false;
    }
    return `${detail.contentText ?? ''}`.trim().length > 0
      || (detail.images ?? []).length > 0
      || (detail.fragments ?? []).length > 0
      || floors.length > 0;
  }

  // 将详情结果应用到页面状态（缓存秒开 / 网络刷新 / 身份补齐回调共用，行为一致）
  private applyDetailResult(result: ThreadDetailResult): void {
    // 防劣化：pb/page 偶发返回"有标题但正文/楼层全空"的残缺响应时，
    // 若当前页面已展示可读内容（正文/图片/楼层任一非空），保留现状不被空壳清空，
    // 避免"秒开正常 → 后台刷新被空结果覆盖"的二次变白。
    if (this.hasVisibleDetailContent(this.detail, this.floors) && !this.hasVisibleDetailContent(result.detail, result.floors)) {
      return;
    }
    this.detail = result.detail;
    this.floors = result.floors;
    this.floorDataSource.setData(result.floors);
    this.totalFloorPage = result.detail.totalPage ?? 1;
    this.hasMoreFloors = this.currentPage < this.totalFloorPage;
    this.liked = result.detail.isLiked === true;
    if (result.detail.forumName.length > 0) {
      this.forumName = result.detail.forumName;
    }
    if ((result.detail.forumId ?? '').length > 0) {
      this.forumId = result.detail.forumId ?? '';
    }
    if (this.forumName.trim().length === 0 && result.detail.forumName.trim().length > 0) {
      this.forumName = result.detail.forumName.trim();
    }
    // 若从消息页带入了目标楼层，内容就位后延迟重试滚动高亮（首帧几何信息可能未就绪）
    this.scheduleScrollToTargetFloor();
    // 浏览历史：数据一落地就记录（内存缓存秒开 / 磁盘缓存秒开 / 网络返回三条路径共用）。
    // 旧实现只在网络成功分支里记录 → 命中缓存且网络异常时该帖不进历史、浏览历史列表看不到。
    this.recordHistoryOnce();
  }

  /**
   * 写一次浏览历史（页面实例内只写一次：applyDetailResult 会被内存缓存 / 磁盘缓存 /
   * 网络结果 / 身份补齐回调多次调用，重复写没必要且增加磁盘 IO）。
   */
  private recordHistoryOnce(): void {
    if (this.historyRecorded) {
      return;
    }
    const detail: ThreadDetailModel | null = this.detail;
    if (detail === null) {
      return;
    }
    const tid: string = `${detail.tid ?? ''}`.trim().length > 0 ? `${detail.tid}`.trim() : this.tid.trim();
    if (tid.length === 0) {
      return;
    }
    this.historyRecorded = true;
    this.recordThreadHistory(detail, tid).catch((): void => {
    });
  }

  // v68: 详情接口未解析 isCollected，改用本地收藏缓存判断（缓存与云端同步，收藏/取消时都会更新）
  private async applyCollectedState(result: ThreadDetailResult): Promise<void> {
    this.collected = result.detail.isCollected === true || await this.isCollectedLocally(this.tid);
  }

  /** 目标楼层是否已加载到当前 floors */
  private targetFloorLoaded(): boolean {
    return this.targetFloorId.length > 0
      && this.floors.some((floor: FloorItem): boolean => floor.floorId === this.targetFloorId);
  }

  /**
   * 滚动并高亮目标楼层（消息点击跳转）。
   * 返回是否完成几何定位：目标楼层尚未加载或首帧几何信息未就绪时返回 false，
   * 由 scheduleScrollToTargetFloor 延时重试兜底。
   */
  private scrollToTargetFloor(): boolean {
    if (this.targetFloorId.length === 0 || !this.targetFloorLoaded()) {
      return false;
    }
    if (this.highlightFloorId === this.targetFloorId) {
      // 已定位过；若还需触发楼中楼定位（首次楼层高亮后超时中断的情形），在此兜底补发
      return true;
    }
    const floorId: string = this.targetFloorId;
    const targetId: string = `floor_${floorId}`;
    const scrollId: string = 'thread_scroll_content';
    try {
      const uiUtils = this.getUIContext().getComponentUtils();
      const targetRect = uiUtils.getRectangleById(targetId);
      const scrollRect = uiUtils.getRectangleById(scrollId);
      if (!targetRect || !scrollRect) {
        return false;
      }
      const currentY = this.scroller.currentOffset().yOffset;
      const targetY = targetRect.windowOffset.y - scrollRect.windowOffset.y + currentY;
      this.highlightFloorId = floorId;
      this.scroller.scrollTo({ xOffset: 0, yOffset: Math.max(0, targetY), animation: true });
      setTimeout(() => {
        if (this.highlightFloorId === floorId) {
          this.highlightFloorId = '';
        }
      }, 2200);
      // 楼中楼回复消息：楼层预览只展示少量评论，等滚动稳定后自动进入楼中楼详情精准定位。
      // 例外：消息 post_id 本身就是该楼层 pid（正常楼层回复正文内 @ 我，postId 命中楼层）时，
      // 目标就是楼层本身，只需停在楼层高亮，不应再拉起该楼层的楼中楼。
      const floorDirect: boolean = this.notifyMsgPostId === floorId;
      hilog.info(0x0000, 'LOCDIAG',
        'AUTOOPEN floor=%{public}s notifyMsgPostId=%{public}s isFloor=%{public}s floorDirect=%{public}s',
        floorId, this.notifyMsgPostId, this.notifyIsFloor, floorDirect ? '1' : '0');
      if (this.notifyIsFloor === '0' && !floorDirect && !this.notifySubPostHandled) {
        setTimeout(() => { this.maybeAutoOpenNotifySubPost(); }, 900);
      }
      return true;
    } catch (e) {
      // 部分 SDK 版本缺少 getComponentUtils，静默降级
      return false;
    }
  }

  /**
   * 详情/楼层数据就绪后延时重试楼层定位：
   * 楼层卡片由 Scroll 全量渲染，首个渲染帧内 getRectangleById 往往还拿不到几何信息，
   * 直接同步定位会静默失败（表现为"只打开帖子、不落楼层"）。此处在帧后轮询直至成功。
   */
  private scheduleScrollToTargetFloor(): void {
    if (this.targetFloorId.length === 0 || this.highlightFloorId === this.targetFloorId) {
      return;
    }
    let attempts: number = 0;
    const tick = (): void => {
      if (this.highlightFloorId === this.targetFloorId) {
        return;
      }
      if (this.scrollToTargetFloor()) {
        return;
      }
      attempts++;
      if (attempts < 20) {
        setTimeout(tick, 220);
      }
    };
    setTimeout(tick, 350);
  }

  /**
   * 消息跳转收尾：楼层回复就位后，若是楼中楼回复（isFloor=0），
   * 自动拉起该楼层的楼中楼详情页，把回复者 id/内容作为定位目标传过去精确滚动高亮。
   */
  private maybeAutoOpenNotifySubPost(): void {
    if (this.notifySubPostHandled || this.notifyIsFloor !== '0') {
      return;
    }
    const floor: FloorItem | undefined = this.floors.find((f: FloorItem): boolean => f.floorId === this.targetFloorId);
    if (!floor) {
      return;
    }
    // 定位解析阶段已确认该父楼层存在目标楼中楼评论，
    // 不再依赖楼层预览自带的评论数（可能为 0 / 未展开），直接拉起详情页
    this.pushNotifySubPost(this.targetFloorId.trim(), floor.floor ?? 0);
  }

  /**
   * 2026-09-20（分区上屏）：楼层区延迟构建 + 分区淡入。
   * 数据落地后楼主卡先独立构建/绘制（首帧构建成本从"楼主卡+整页楼层"降为"楼主卡"），
   * 约 50ms 后再构建楼层区并以 120ms 延迟淡入——"楼主帖先落定、回复流随后进场"的阅读层次。
   * 楼层构建闸门 floorsReady 同时是消息/跳楼定位的隐式同步点（定位延迟 250ms > 50ms+一帧构建）。
   * gen 校验：切排序/刷新打断时作废在途 reveal。
   */
  private scheduleFloorsReveal(): void {
    if (this.floorsReady || this.floorsRevealTimer >= 0) {
      return;
    }
    const gen: number = this.fadeGeneration;
    this.floorsRevealTimer = setTimeout(() => {
      this.floorsRevealTimer = -1;
      if (gen !== this.fadeGeneration || this.floorsReady) {
        return;
      }
      this.floorsReady = true;
      animateTo({ duration: FLOORS_FADE_IN_MS, curve: Curve.EaseOut, delay: FLOORS_FADE_DELAY_MS }, () => {
        this.floorsOpacity = 1;
      });
    }, FLOORS_REVEAL_DELAY_MS);
  }

  /**
   * 骨架屏→内容过渡（2026-09-20 A+C 接力式打磨）：
   * 旧版交叉淡入淡出（内容 0→1 与骨架 1→0 同时 250ms）中段两层各半透明、底色透出，
   * 观感为"内容中间闪出来"。现改为接力：骨架先完全退场（180ms EaseIn，呼吸动画干净收束），
   * 内容再带 14vp 上浮进场（240ms EaseOut，"落定"运动感）——每一步都无半透明交叉。
   * C：骨架屏最短停留 180ms——早到的数据等骨架站稳再交接，避免"骨架一闪而过"。
   * 已淡入完成（缓存秒开/后台合并）时直接跳过；进行中重入由 fadeRelayRunning 拦截；
   * 途中 reload（切排序/刷新）递增 fadeGeneration 作废在途定时器。
   */
  private fadeInContent(): void {
    if (this.loadState === LoadState.Error) {
      return;
    }
    // §防永久骨架：contentOpacity 可能被其他路径（如动画回调重入）先行置 1，
    // 此时若直接 return，下方定时器链永不注册，loadState 会永久停在 Loading，
    // 骨架屏（loadState===Loading && skeletonVisible）随之永久挂起。
    // 故此处补一条状态机收敛路径：已淡入完成就只负责把状态推进到 Success。
    if (this.contentOpacity >= 1) {
      if (this.loadState === LoadState.Loading) {
        this.loadState = LoadState.Success;
      }
      return;
    }
    if (this.fadeRelayRunning) {
      return;
    }
    this.fadeRelayRunning = true;
    const gen: number = this.fadeGeneration;
    const stale = (): boolean => gen !== this.fadeGeneration;
    // C：骨架最短停留
    const shownElapsed: number = this.skeletonShownAt > 0 ? Date.now() - this.skeletonShownAt : 0;
    const skeletonHold: number = Math.max(0, SKELETON_MIN_DISPLAY_MS - shownElapsed);
    setTimeout(() => {
      if (stale()) {
        this.fadeRelayRunning = false;
        return;
      }
      // A 第一步：骨架完全退场
      animateTo({ duration: 180, curve: Curve.EaseIn }, () => {
        this.skeletonOpacity = 0;
      });
      // A 第二步：骨架退场后内容上浮进场
      setTimeout(() => {
        if (stale()) {
          this.fadeRelayRunning = false;
          return;
        }
        animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
          this.contentOpacity = 1;
          this.contentTranslateY = 0;
        });
        setTimeout(() => {
          this.fadeRelayRunning = false;
          if (!stale() && this.loadState === LoadState.Loading) {
            this.loadState = LoadState.Success;
          }
        }, 250);
      }, 185);
    }, skeletonHold);
  }

  /**
   * 缓存命中直出（§P0-2）：命中内存/磁盘缓存时不再走 250ms 交叉淡入 + 260ms 后置切态，
   * 直接在当帧把内容推到不透明并切 Success，打开即内容、且底栏（排序胶囊/评论岛）同步就位。
   * 网络首帧路径仍走 fadeInContent()，观感一字未改。
   * 已出现骨架屏（>120ms 才拿到缓存，如冷启动首次读盘较慢）时回落淡入，避免骨架屏"硬消失"。
   */
  private showCachedContent(): void {
    if (this.loadState === LoadState.Loading && this.skeletonVisible) {
      this.fadeInContent();
      return;
    }
    this.contentOpacity = 1;
    this.skeletonOpacity = 0;
    this.contentTranslateY = 0;
    this.loadState = LoadState.Success;
    // 分区上屏：缓存直出同样楼主卡先行，楼层区下一帧补齐
    this.scheduleFloorsReveal();
  }

  /**
   * 发起首屏详情请求（合流版）：单独成方法以便与磁盘缓存读并行发出（§Z1）。
   * §P0-1：点击时起的预取若仍在途，合流版直接等它，不另发一次同参请求。
   */
  private startDetailRequest(): Promise<ThreadDetailResult> {
    return TiebaService.getInstance().fetchThreadDetailCoalesced(
      this.tid, 1, this.sortType, this.seeLz, this.forumId, this.commentRn, 0, '',
      // 身份补齐完成后回调：只刷新身份相关字段，不打断用户浏览
      (merged: ThreadDetailResult) => { this.applyDetailResult(merged); }
    );
  }

  async loadDetail(force: boolean = false): Promise<void> {
    // §TD 首屏耗时打点（纯日志，零行为影响）：__td0 为本轮加载起点，
    // 用于核算「缓存段 + 合流 await 段」各自耗时与骨架屏悬挂时长。
    const __td0: number = Date.now();
    this.loadState = LoadState.Loading;
    // 每次加载重置过渡透明度：骨架屏覆盖、内容透明，等待淡入
    this.contentOpacity = 0.0;
    this.skeletonOpacity = 1.0;
    // A+C：内容回到上浮起点；作废在途接力动画（切排序/只看楼主/刷新打断上一轮过渡时，
    // 旧定时器不得把新骨架提前收掉或把旧内容推上场）
    this.contentTranslateY = CONTENT_RISE_VP;
    this.fadeGeneration++;
    this.fadeRelayRunning = false;
    // 分区上屏：楼层区回到未构建态（数据落地后楼主卡先绘制，楼层区由 scheduleFloorsReveal 补齐）
    this.floorsReady = false;
    this.floorsOpacity = 0;
    // §P0-4：首屏（本页尚无内容）不立即挂骨架屏，交 aboutToAppear 的 120ms 延时放行；
    // 已有内容的重新加载（切排序 / 只看楼主 / 强制刷新）立即放行，骨架屏表现与改造前一致。
    if (this.detail !== null) {
      this.skeletonVisible = true;
      // C：重载路径骨架立即放行，同样记录可见时刻
      this.skeletonShownAt = Date.now();
    }
    // 重置分页状态
    this.currentPage = 1;
    this.hasMoreFloors = true;
    // 无感翻页：复位滚动预取节流基线（换帖 / 切排序 / 只看楼主 / 刷新后重新起算，
    // 避免拿上一份内容的偏移做节流判断），并收回可能残留的尾部提示/失败态
    this.lastPrefetchY = -1;
    this.endLoadMoreHint();
    this.loadMoreFailed = false;
    const cacheKey = this.threadDetailCacheKey();
    // 1. 秒开：非强制刷新时优先内存缓存，其次磁盘缓存（stale 也先显示），网络结果返回后再覆盖
    //    §P0-2：缓存命中直接直出（不淡入、不等 260ms 后置切态），打开即内容
    let __tdCache: string = force ? 'force' : 'miss';
    // §Z1（2026-09-19）：磁盘读（10~150ms）不再阻塞网络请求发出 —— 内存未命中即先起请求再读盘，
    // 两者并行；磁盘结果仍先落地做秒开、网络结果到达后覆盖，落地顺序与改造前逐帧一致，只是省掉串行等待。
    let netPromise: Promise<ThreadDetailResult> | null = null;
    let __ta0: number = 0;
    if (!force) {
      const cached = TiebaService.getInstance().getThreadDetailCache(cacheKey);
      if (cached) {
        __tdCache = 'mem';
        this.applyDetailResult(cached);
        this.applyCollectedState(cached);
        this.showCachedContent();
      } else {
        netPromise = this.startDetailRequest();
        __ta0 = Date.now();
        // 并行窗口内先挂一次拒绝兜底：请求若在「发出→await」之间快速失败（断网等）
        // 不会产生未处理拒绝告警；真实错误仍由下方 try/await 捕获处理。
        netPromise.catch((): void => {
        });
        // 冷启动秒开：磁盘缓存（过期数据也先显示），后台网络刷新校正
        const disk = await TiebaService.getInstance().getThreadDetailFromDisk(this.tid, this.sortType, this.seeLz);
        if (disk) {
          __tdCache = 'disk';
          this.applyDetailResult(disk);
          this.applyCollectedState(disk);
          this.showCachedContent();
        }
      }
    }
    console.info(`[TD] page enter tid=${this.tid} force=${force ? '1' : '0'} cache=${__tdCache} elapsed=${Date.now() - __td0}ms`);
    try {
      // §Z1：上面已随磁盘读并行发出的直接复用；__ta0 记的是请求发出时刻，
      // 故 page await cost 仍是整段请求耗时（与改造前同口径，便于 A/B 对比）。
      if (netPromise === null) {
        __ta0 = Date.now();
        netPromise = this.startDetailRequest();
      }
      const result = await netPromise;
      const __ta1: number = Date.now();
      // 残缺空壳刷新判定：接口偶发返回"有标题但正文/楼层全空"的响应，
      // 且页面当前已展示可读内容（通常是缓存秒开成功后的后台刷新）。
      // 此时保留页面现状：不写缓存（service 缓存层同样过滤空壳）、不覆写浏览历史、不预取，
      // 避免好内容被空壳结果二次清空。
      const refreshShell: boolean = !this.hasVisibleDetailContent(result.detail, result.floors)
        && this.hasVisibleDetailContent(this.detail, this.floors);
      // 读法（2026-09-19 补）：cache=mem/disk 时下面的 cost 是「后台兜底刷新」耗时——
      // 内容在上一条 page enter 时已直出可见，这不是首屏可交互耗时；
      // 只有 cache=miss/force 才是用户真正在等的那一段。
      console.info(`[TD] page await tid=${this.tid} cache=${__tdCache} cost=${__ta1 - __ta0}ms floors=${result.floors.length} refreshShell=${refreshShell ? '1' : '0'} elapsed=${__ta1 - __td0}ms`);
      if (!refreshShell) {
        TiebaService.getInstance().putThreadDetailCache(cacheKey, result);
        // 写磁盘缓存：冷启动重进该帖也能秒开
        TiebaService.getInstance().saveThreadDetailToDisk(result, this.tid, this.sortType, this.seeLz);
        this.applyDetailResult(result);
        this.applyCollectedState(result);
        // 2026-09-20 快路径免淡入：数据在 120ms 骨架屏窗口内到达（快网络 / 按下预取及时），
        // 骨架屏从未出现 → 内容无需 0→1 淡入，直接不透明上屏，省 250ms 感知延迟。
        // 已有内容后的重载（切排序 / 只看楼主 / 刷新）骨架屏立即放行，仍走交叉淡入，表现与改造前一致；
        // 数据慢于 120ms 时骨架屏已出现，也回落淡出骨架屏路径，避免硬切。
        if (this.loadState === LoadState.Loading && !this.skeletonVisible) {
          this.showCachedContent();
        } else {
          this.fadeInContent();
        }
        // 分区上屏：楼主卡先绘制，楼层区延迟构建 + 分区淡入
        this.scheduleFloorsReveal();
        // 楼中楼预览点赞补齐：pb/page 详情接口的楼中楼不含点赞字段，
        // 对含楼中楼的楼层静默调用 pb/floor 校正预览点赞数/已赞状态
        // §Z4a：延后起跑（见 scheduleSubPostPreviewEnrich），不与首屏渲染/下一页预取抢连接
        this.scheduleSubPostPreviewEnrich();
        // 浏览历史已在 applyDetailResult 里记录（覆盖缓存秒开 / 网络两条路径，且每页只写一次）
        // 预取下一页楼层：滚动翻页时直接命中缓存，减少等待
        if (this.hasMoreFloors) {
          TiebaService.getInstance().prefetchThreadNextPage(this.tid, this.currentPage, this.sortType, this.seeLz, this.forumId, this.commentRn);
        }
      } else {
        // 空壳刷新：保留当前已展示内容与收藏态，仅完成淡入收尾，不打断浏览
        this.fadeInContent();
      }
      // 消息页定位：post_id 多数是楼中楼评论 pid（楼层列表里永远不存在），
      // 首页未命中时不盲目翻遍全帖，先探测其父楼层与评论归属再决定定位路径
      if (this.targetFloorId.length > 0) {
        const hitNow: boolean = this.targetFloorLoaded();
        hilog.info(0x0000, 'LOCDIAG',
          'detailReady target=%{public}s isFloor=%{public}s page1Pids=[%{public}s] hitOnPage1=%{public}s hasMore=%{public}s totalFloorPage=%{public}d',
          this.targetFloorId, this.notifyIsFloor,
          this.floors.slice(0, 5).map((f: FloorItem): string => `${f.floorId}`).join(','),
          hitNow ? '1' : '0', this.hasMoreFloors ? '1' : '0', this.totalFloorPage);
        if (hitNow) {
          // post_id 恰好是楼层 pid（楼层直回）：原地滚动高亮
          this.scheduleScrollToTargetFloor();
        } else {
          setTimeout(() => { this.resolveNotifyTarget(); }, 250);
        }
      }
    } catch (e) {
      if (this.detail) {
        // 已有缓存内容可显示（秒开），后台刷新失败时保留缓存内容，不打断浏览
        this.fadeInContent();
      } else {
        this.loadState = LoadState.Error;
        this.errorMsg = (e as Error).message ?? '加载失败';
      }
    }
  }

  /**
   * 消息跳转目标解析：post_id 在已加载楼层中未命中时调用。
   * 通知里 post_id 多数是"楼中楼评论 pid"而非楼层 pid（楼层列表里永远不存在），
   * 而 pb/floor 接口对 quote_pid / post_id 都宽容——任选其一都能解析到所属父楼层。
   * 这里先调一次楼中楼接口探测：
   * - 若 post_id 出现在该楼层的评论列表中 → 消息是楼中楼回复：
   *   父楼层已在帖内则滚动过去再拉楼中楼精准定位；
   *   父楼层尚未加载（深楼层 / 服务端只回单页的帖）则直接进楼中楼页按评论 pid 高亮；
   * - 若 post_id 不在评论列表（疑似真实楼层 pid）或请求失败 → 退回按楼层页翻找。
   */
  private async resolveNotifyTarget(): Promise<void> {
    if (this.notifyResolveHandled || this.targetFloorId.length === 0 || this.notifyMsgPostId.length === 0) {
      return;
    }
    this.notifyResolveHandled = true;
    const post: string = this.notifyMsgPostId;
    const probePid: string = this.notifyQuotePid.length > 0 ? this.notifyQuotePid : post;
    let commentResolved: boolean = false;
    try {
      const sub: SubPostDetail = await TiebaService.getInstance().fetchSubPostDetail(
        this.tid, probePid, this.forumId, 0, 1);
      const commentIds: string[] = sub.comments.map((c: CommentItem): string => `${c.commentId}`);
      const parentFloorNum: number = sub.parent?.floor ?? 0;
      hilog.info(0x0000, 'LOCDIAG',
        'NOTIFYRESOLVE tid=%{public}s post=%{public}s probe=%{public}s OK parentFloor=%{public}d comments=%{public}d postInComments=%{public}s commentIds=[%{public}s]',
        this.tid, post, probePid, parentFloorNum, sub.comments.length,
        commentIds.indexOf(post) >= 0 ? '1' : '0', commentIds.slice(0, 8).join(','));
      if (commentIds.indexOf(post) >= 0) {
        commentResolved = true;
        const parentFloor: FloorItem | undefined = this.floors.find((f: FloorItem): boolean =>
          parentFloorNum > 0 ? f.floor === parentFloorNum : f.floorId === probePid);
        if (parentFloor) {
          // 父楼层已在帖内：滚动过去后由楼中楼自动定位通道拉起详情页
          this.targetFloorId = parentFloor.floorId;
          this.notifyIsFloor = '0';
          this.notifySubPostHandled = false;
          this.scheduleScrollToTargetFloor();
        } else {
          // 父楼层未加载：直接进楼中楼详情页按评论 pid 精确高亮
          this.pushNotifySubPost(probePid, parentFloorNum);
        }
      }
    } catch (e) {
      hilog.info(0x0000, 'LOCDIAG',
        'NOTIFYRESOLVE tid=%{public}s probe=%{public}s FAIL msg=%{public}s',
        this.tid, probePid, `${(e as Error).message ?? '?'}`.slice(0, 120));
    }
    if (!commentResolved) {
      // 探测失败或 post_id 不在评论列表：post_id 疑似真实楼层 pid，退回按楼层翻页
      if (this.hasMoreFloors) {
        this.loadMoreFloors();
      } else if (!this.locateNoticeShown) {
        this.locateNoticeShown = true;
        this.getUIContext().getPromptAction().showToast({ message: '未能在本帖定位到该楼层，可能已被删除' });
      }
    }
  }

  /** 直接打开楼中楼详情页并按通知消息的评论 pid 精确定位高亮 */
  private pushNotifySubPost(pid: string, floorNum: number): void {
    if (this.notifySubPostHandled) {
      return;
    }
    this.notifySubPostHandled = true;
    this.openingSubPost = true;
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/SubPostDetail',
      params: {
        tid: this.tid,
        pid: pid,
        floor: `${floorNum ?? 0}`,
        forumId: this.forumId,
        forumName: this.forumName,
        notifyReplyerId: this.notifyReplyerId,
        notifyReplyerName: this.notifyReplyerName,
        notifyContent: this.notifyContent,
        notifyCommentPid: this.notifyMsgPostId
      }
    }).then(() => {
      this.openingSubPost = false;
    }).catch(() => {
      this.openingSubPost = false;
      this.getUIContext().getPromptAction().showToast({ message: '楼中楼定位打开失败，请稍后重试' });
    });
  }

  private async recordThreadHistory(detail: ThreadDetailModel, tid: string): Promise<void> {
    const item: PersonalContentItem = {
      id: tid,
      tid: tid,
      title: detail.title,
      forumName: detail.forumName,
      forumId: detail.forumId ?? '',
      forumAvatar: detail.forumAvatar ?? '',
      author: detail.author,
      abstract: detail.contentText,
      replyNum: detail.replyNum,
      createTime: detail.createTime
    };
    // 账号 ID / 浏览时间戳 / 同帖去重置顶 / 上限截断统一由 HistoryStore 处理
    await HistoryStore.getInstance().record(item);
  }

  async loadMoreComments(): Promise<void> {
    if (this.commentLoading) {
      return;
    }
    this.commentLoading = true;
    try {
      this.commentRn = Math.min(this.commentRn + 5, 30);
      await this.loadDetail();
      this.getUIContext().getPromptAction().showToast({ message: '已尝试加载更多楼中楼' });
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({ message: '楼中楼加载失败，请稍后重试' });
    } finally {
      this.commentLoading = false;
    }
  }

  // 加载更多楼层（下一页）
  /**
   * @param silent 后台预取路径（滚动预取）传 true：尾部先静默、超时才浮出 loading，失败也不打扰用户
   *               （由触底/滚动兜底重试）；用户显式路径（触底 onReachEnd、点击重试、消息楼层定位）
   *               保持默认 false：立即浮出 loading，失败给出可点重试。
   */
  async loadMoreFloors(silent: boolean = false): Promise<void> {
    // 防重复请求
    if (this.loadingMore || !this.hasMoreFloors) {
      return;
    }
    this.loadingMore = true;
    this.beginLoadMoreHint(silent);
    try {
      const nextPage = this.currentPage + 1;
      // 优先使用已预取的下一页（秒接），未命中再发网络请求
      const cached = TiebaService.getInstance().takeThreadNextPage(this.tid, this.sortType, this.seeLz, nextPage);
      const result: ThreadDetailResult = cached !== undefined
        ? cached
        : await TiebaService.getInstance().fetchThreadDetail(
          this.tid, nextPage, this.sortType, this.seeLz, this.forumId, this.commentRn, 0
        );
      // 追加新楼层到现有列表
      this.floors = [...this.floors, ...result.floors];
      this.floorDataSource.append(result.floors);
      // 新追加楼层同样存在 pb/page 楼中楼无点赞的问题，静默补齐
      this.enrichSubPostPreviewLikes(result.floors);
      this.currentPage = nextPage;
      this.totalFloorPage = result.detail.totalPage ?? this.totalFloorPage;
      this.hasMoreFloors = this.currentPage < this.totalFloorPage;
      // 消息页定位：追加楼层后若目标已就位则延时滚动（首帧几何可能未就绪）；
      // 若目标仍不在当前列表，继续向后加载直到命中或到底
      if (this.targetFloorId.length > 0) {
        if (this.targetFloorLoaded()) {
          hilog.info(0x0000, 'LOCDIAG',
            'locateHIT page=%{public}d floorsLoaded=%{public}d totalFloorPage=%{public}d target=%{public}s',
            this.currentPage, this.floors.length, this.totalFloorPage, this.targetFloorId);
          this.scheduleScrollToTargetFloor();
        } else if (this.hasMoreFloors) {
          hilog.info(0x0000, 'LOCDIAG',
            'locateMORE page=%{public}d floorsLoaded=%{public}d totalFloorPage=%{public}d target=%{public}s notHit tailPids=[%{public}s]',
            this.currentPage, this.floors.length, this.totalFloorPage, this.targetFloorId,
            this.floors.slice(-3).map((f: FloorItem): string => `${f.floorId}`).join(','));
          this.loadMoreFloors();
        } else if (!this.locateNoticeShown) {
          // 翻到帖子末页仍未命中：给出一次明确提示（可能楼层已被删除/折叠），避免静默落空
          this.locateNoticeShown = true;
          hilog.info(0x0000, 'LOCDIAG',
            'locateFAIL tid=%{public}s targetFloorId=%{public}s notifyIsFloor=%{public}s replyer=%{public}s(%{public}s) content=[%{public}s] floorsLoaded=%{public}d currentPage=%{public}d totalFloorPage=%{public}d headPids=[%{public}s] tailPids=[%{public}s]',
            this.tid, this.targetFloorId, this.notifyIsFloor,
            this.notifyReplyerName, this.notifyReplyerId, this.notifyContent.slice(0, 80),
            this.floors.length, this.currentPage, this.totalFloorPage,
            this.floors.slice(0, 5).map((f: FloorItem): string => `${f.floorId}`).join(','),
            this.floors.slice(-5).map((f: FloorItem): string => `${f.floorId}`).join(','));
          this.getUIContext().getPromptAction().showToast({ message: '未能在本帖定位到该楼层，可能已被删除' });
        }
      }
      // 预取再下一页：保持滚动到底时总有缓存可用
      if (this.hasMoreFloors) {
        TiebaService.getInstance().prefetchThreadNextPage(this.tid, this.currentPage, this.sortType, this.seeLz, this.forumId, this.commentRn);
      }
    } catch (e) {
      // 加载失败时不更新页码，允许重试；后台预取失败保持静默（由触底/滚动兜底重试）
      this.loadMoreFailed = !silent;
      console.error('加载更多楼层失败:', (e as Error).message);
    } finally {
      this.endLoadMoreHint();
      this.loadingMore = false;
    }
  }

  /** 尾部加载提示起手：显式路径立即浮出；后台预取路径先静默，超时 DETAIL_LOAD_HINT_DELAY 才浮出 */
  private beginLoadMoreHint(silent: boolean): void {
    this.clearLoadingHintTimer();
    this.loadMoreFailed = false;
    if (!silent) {
      this.loadingHintVisible = true;
      return;
    }
    this.loadingHintVisible = false;
    this.loadingHintTimer = setTimeout(() => {
      this.loadingHintTimer = -1;
      this.loadingHintVisible = true;
    }, DETAIL_LOAD_HINT_DELAY);
  }

  /** 尾部加载提示收尾：清延时器 + 收回提示（无论成败提示都归于静默，失败态另行置位） */
  private endLoadMoreHint(): void {
    this.clearLoadingHintTimer();
    this.loadingHintVisible = false;
  }

  /** 清理尾部提示延时器（beginLoadMoreHint 重排前 + aboutToDisappear 退页时调用） */
  private clearLoadingHintTimer(): void {
    if (this.loadingHintTimer !== -1) {
      clearTimeout(this.loadingHintTimer);
      this.loadingHintTimer = -1;
    }
  }

  /**
   * 用户已触底：若后台预取仍在途，立即浮出提示 —— 用户已经滑到边界在等，不宜再保持静默，
   * 否则尾部是一片空白占位（比转圈更糟）。
   */
  private revealLoadHintOnReachEnd(): void {
    if (this.loadingMore && !this.loadMoreFailed) {
      this.clearLoadingHintTimer();
      this.loadingHintVisible = true;
    }
  }

  /**
   * 帖子详情滚动预取（无感翻页核心）：与沉浸阅读（onDetailScroll）**共用同一个 onScroll 挂点** ——
   * ArkUI 的 .onScroll 一个组件只能挂一个回调，重复挂会覆盖（新挂一个会让沉浸显隐直接失效），
   * 故在挂点处串联调用，本方法不碰沉浸任何状态。
   *
   * 判定：剩余距离（内容高 - 视口高 - 当前偏移）不足 DETAIL_PREFETCH_DISTANCE 时触发下一页，
   * 走 loadMoreFloors(true) 静默路径 —— 命中「下一页预取缓存」时同步追加（零等待），
   * 未命中才发网络请求，请求期间对用户完全不可见。
   */
  private onDetailScrollPrefetch(): void {
    if (this.loadState !== LoadState.Success || this.loadingMore || !this.hasMoreFloors) {
      return;
    }
    if (this.detailContentH <= 0 || this.detailViewportH <= 0) {
      return;
    }
    // 绝对位置取 Scroller 真值（onScroll 入参语义在工具链间有差异，口径同 onDetailScroll）
    let y: number = 0;
    try {
      y = this.scroller.currentOffset().yOffset;
    } catch (e) {
      return;
    }
    const remaining: number = this.detailContentH - this.detailViewportH - y;
    if (remaining > DETAIL_PREFETCH_DISTANCE) {
      return;
    }
    // 节流：偏移变化超过 DETAIL_PREFETCH_THROTTLE 才允许再次触发，避免同一轮滚动连续请求
    if (this.lastPrefetchY >= 0 && Math.abs(y - this.lastPrefetchY) < DETAIL_PREFETCH_THROTTLE) {
      return;
    }
    this.lastPrefetchY = y;
    this.loadMoreFloors(true);
  }

  async doComment(): Promise<void> {
    const content = this.commentText.trim();
    if (content.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '请输入评论内容' });
      return;
    }
    if (!AuthManager.getInstance().isLogin()) {
      this.getUIContext().getPromptAction().showToast({ message: '请先登录' });
      return;
    }
    if (!this.pendingReply) {
      this.pendingReply = true;
      this.getUIContext().getPromptAction().showToast({ message: '再次点击发送，确认发布这条回帖' });
      return;
    }
    this.sending = true;
    try {
      const targetForum = this.detail?.forumName ?? this.forumName;
      const result = await TiebaService.getInstance().publishReply(targetForum, this.tid, content, this.forumId);
      this.getUIContext().getPromptAction().showToast({ message: result.message });
      this.commentText = '';
      this.replyTarget = '';
      this.pendingReply = false;
      // 回帖后强制网络刷新，避免缓存旧内容
      await this.loadDetail(true);
    } catch (e) {
      this.pendingReply = false;
      this.getUIContext().getPromptAction().showToast({ message: (e as Error).message ?? '回帖失败' });
    } finally {
      this.sending = false;
    }
  }

  /**
   * 页面主体层：官方壳（底部 Tabs 悬浮条）/ 兜底 Dock + 弹窗浮层；顶栏两条路径共用同一份内容。
   * 内容让位常量未动：Scroll 首项仍是 height(98) 占位，正好等于官方 title bar 高度。
   */
  @Builder
  DetailRoot() {
    Stack({ alignContent: Alignment.Bottom }) {
      // API26+ 真机沉浸光感：官方 Tabs 悬浮条壳 —— 底部 Dock 整体放入 .tabBar() 槽位，
      // 悬浮条本体挂 barFloatingStyle.systemMaterial 才渲染官方材质（与 Index 首页同一机制）。
      // 其余环境/设备走原手写叠放路径（布局与定稿完全一致），留作稳定兜底。
      // （2026-09-13 回退记录：「平板横屏岛与帖子卡左对齐」的岛壳解耦方案（内容层移出 Tabs +
      // FloatingIslandOnly 纯岛壳）已按用户要求回退 —— 底栏保持居中；官方沉浸材质不变。）
      if (this.materialSupported) {
        this.ImmersiveDockShell()
        if (this.loadState === LoadState.Success && this.detail) {
          if (THREAD_DETAIL_SORT_OFFICIAL_SLOT) {
            this.SortPillShell()
          } else {
            this.SortRowOverlay()
          }
        }
      } else {
        this.ContentLayer()
        this.BottomDock()
      }
      /**
       * 长按收藏钮 → 分类面板（共用组件 FavCategoryPicker，§6.8 系统半模态）。
       * 组件自身 0×0 不参与本页布局，`bindSheet` 挂在组件内部；本页只驱动开合（pickerShow），
       * 「完成」回调 applyPickCategory 才落库 → 下滑 / 点遮罩关闭 = 零副作用。
       */
      FavCategoryPicker({
        show: $pickerShow,
        categories: $pickerCategories,
        mappings: $pickerMappings,
        checked: $pickerChecked,
        creating: $pickerCreating,
        targets: this.pickerTargets,
        accountId: this.pickerAccountId,
        isDark: this.isDark,
        fontScale: this.fontScale,
        onDone: (checked: string[]) => { this.applyPickCategory(checked); }
      })
      // 链接跳转确认浮层（沉浸光感卡片，风格与收藏页确认弹窗一致）
      if (this.showLinkDialog) {
        this.LinkConfirmDialog()
      }
      // 跳转官方贴吧确认弹窗已迁到系统 CustomDialog（见宿主 jumpDialogController / JumpTiebaDialogCard）：
      // 原自绘浮层挂在页面 body 内，systemMaterial 必然判 out of scope，只有系统弹窗宿主才吃官方沉浸材质
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg(this.isDark))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      const width = newValue.width as number;
      const height = newValue.height as number;
      // 尺寸同值短路（2026-09-18 旋转丝滑）：旋转期逐帧回调，同尺寸时写 @State 与重算 splitMode()
      // 都是白做（下方 applySplitSwitch 另有「split 结果未变不切」守卫，这里再省掉每帧的判定开销）。
      // 注意判据用 currentWidth（下方 width>0 才回填，故 0 = 未初始化时不会误早退）。
      if (width === this.currentWidth && height === this.pageHeight) {
        return;
      }
      if (width > 0) {
        this.currentWidth = width;
      }
      // §4.9 DT-A：同点回填窗口高，供 isLandscape() / splitMode() 判定
      if (height > 0) {
        this.pageHeight = height;
      }
      // 形态切换平滑化：只在「是否分栏」的结果真正变化时才切（一次旋转只切一次）
      const nextSplit: boolean = this.splitMode();
      if (nextSplit !== this.isSplit) {
        this.applySplitSwitch(nextSplit);
      }
    })
  }

  build() {
    if (THREAD_DETAIL_OFFICIAL_TITLE_BAR && this.materialSupported) {
      // 官方槽位路径：Navigation + 自定义 title（height 固定 98，与改造前悬浮顶栏几何一致）
      // barStyle STACK：内容区延伸到标题栏之下（官方建议，标题栏材质获得最佳沉浸体验的前提）
      // backgroundColor 显式透明：避免标题栏自带底色压住滚动经过的内容
      // 与下方 ImmersiveDockShell 的 Tabs 悬浮条合起来 =「顶部 titleBar + 底部 Tabs」两端官方槽位齐备
      Navigation() {
        this.DetailRoot()
      }
      .title({ builder: this.DetailTitleBar(), height: THREAD_DETAIL_TITLE_BAR_HEIGHT },
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
      // 兜底路径：改造前原样（页面主体悬浮 LegacyTopBar + manualGlass/backgroundBlurStyle 真磨砂）
      this.DetailRoot()
    }
  }

  // ===== 平板适配判据（§4.9 DT-A）=====

  /** 横竖屏：用宽高比（同 §4.7 S-B / §4.8 T-B），不用宽度阈值 */
  private isLandscape(): boolean {
    return this.currentWidth > this.pageHeight;
  }

  /**
   * 回复区列数（§4.9 DT-G）：手机（含横屏 / 分屏 / 窄窗）恒 1；大屏（平板）**横竖屏均 2 列**
   * （2026-09-16 用户拍板「竖屏和横屏回复区域都改成两列」，原恒 3 作废）。
   * 形态闸门必须放首行：只按宽度判会让手机横屏（约 780vp ≥ 600）误命中多列。
   */
  private replyColumns(): number {
    // 窗口闸门最前（2026-09-17 小窗 / 分屏适配）：窗口宽 <600（自由多窗小窗 / 分屏窄窗）一律单列
    // ——须在设备恒值分支（Pura X Max / 大折叠恒 2）之前，防小窗误命中
    if (this.currentWidth > 0 && this.currentWidth < Breakpoint.sm) {
      return 1;
    }
    // Pura X Max（阔折叠展开 7.7"，2026-09-17 立项）：右栏回复 2 列瀑布流——屏幅与大折叠
    // （Mate X 8"）同量级，恒 1 列（阔直屏 Pura X 6.3" 口径）会拉出 ~560vp 超长行，按大折叠 2 列
    if (isPuraXMaxDevice()) {
      return 2;
    }
    // 阔直屏（docs/TiebaPura阔直屏适配.md §4.4，2026-09-15 用户二次改定）：回复区恒 1 列
    // （竖屏单列；横屏分栏保留、右栏回复单列）
    if (isWideBarDevice()) {
      return 1;
    }
    // 大折叠（docs/TiebaPura大折叠适配.md §5，2026-09-16 用户改定）：横竖屏回复区均 2 列瀑布流
    // （分栏左右两侧 2 列）——与本轮平板拍板同值，分支保留（判据独立）
    if (isLargeFoldDevice()) {
      return 2;
    }
    if (!this.isWideFormDevice) {
      return 1;
    }
    if (this.currentWidth < Breakpoint.sm) {
      return 1;
    }
    // 2026-09-17 用户二次拍板：平板横竖屏均 2 列（横 3 只活了半天即回调；与 09-16 首拍同值）
    return 2;
  }

  /**
   * 是否左右分栏（§4.9 DT-I，大屏横屏）：主楼独占左栏、回复独占右栏。
   * 大折叠（2026-09-16 用户拍板）：横竖屏**均**分栏——展开态近方形、竖屏宽 ≥600 与横屏同级，
   * 左栏固定 420（DETAIL_MAIN_WIDTH 与横屏同款）、右栏回复单列；折叠态外屏窄走原路径单列。
   */
  /**
   * 分栏左栏宽度（vp）= **屏宽 / 3**（2026-09-17 用户拍板「帖子卡片跟回复卡片等宽」推广到平板，
   * 大折叠 2026-09-16 同款先例）——推导：主楼卡宽 = L − 24（左 16/右 8 内距）；
   * 回复每列 = (R − 24 − 12)/2，R = W − L − 12（分栏缝 12），两者相等 ⇔ L = W/3（列缝 12 恰好凑平）。
   * currentWidth 未就绪时回退 420。
   */
  private splitMainWidth(): number {
    if (this.currentWidth > 0) {
      return Math.round(this.currentWidth / 3);
    }
    return DETAIL_MAIN_WIDTH;
  }

  private splitMode(): boolean {
    if (isLargeFoldDevice()) {
      return this.currentWidth >= Breakpoint.sm;
    }
    return this.isWideFormDevice && this.currentWidth >= Breakpoint.sm && this.isLandscape();
  }

  /**
   * 形态切换平滑化（2026-09-13 二次优化 —— 消除「闪一下」）。
   *
   * 上一版把 `contentOpacity` **瞬间归零**再淡入，那一帧「内容啪地消失」正是用户看到的闪烁；
   * 且重建本身是同步的，并不需要提前隐藏。现改为**三段全动画、无瞬间跳变**：
   *   ① 淡出 100ms（`animateTo`，渐变而非瞬变）；
   *   ② 在内容不可见时才写 `isSplit` → 结构切换与全量重建发生在透明期，用户看不见；
   *   ③ 淡入 160ms。
   * 全程都有过渡，没有「空白帧」，故不闪。未就绪（首屏 / 无数据）时直接切，不参与动画，
   * 避免与首屏 fadeIn 打架。
   */
  private applySplitSwitch(next: boolean): void {
    if (this.loadState !== LoadState.Success || !this.detail) {
      this.isSplit = next;
      return;
    }
    animateTo({
      duration: 100,
      curve: Curve.EaseIn,
      onFinish: () => {
        this.isSplit = next;
        setTimeout(() => {
          animateTo({ duration: 160, curve: Curve.EaseOut }, () => {
            this.contentOpacity = 1;
          });
        }, 16);
      }
    }, () => {
      this.contentOpacity = 0;
    });
  }

  /**
   * 官方悬浮岛 Dock 宽度（vp，形态分档）：
   * - **手机（含横屏 / 分屏 / 窄窗）**：保持原「屏宽 − 64」（下限 240）**逐像素不变** ——
   *   ⚠️ 不可对手机封顶：手机屏宽并非都是 360（393vp 等主流机型，「屏宽 − 64」= 329），
   *   任何平板档封顶值作用于手机都会实实在在收窄手机底栏（用户真机已驳回一次）。
   * - **平板 / 大屏形态**：封顶到 `DETAIL_DOCK_TABLET_WIDTH`(592 = 现有基础 296 宽一倍，
   *   2026-09-14 用户要求「底栏在现有基础宽一倍，跳转框跟着拉伸」)，防「屏宽 − 64」在
   *   1024 下拉成 960vp 通栏，同时比 296 观感更舒展。
   * 消费方（官方岛 barWidth / SortPillShell 定位公式）全部经此单点 → 排序壳左缘
   * = (currentWidth − 592) / 2 − 16，自动跟随新宽度与岛保持左对齐（-16 为真机微调项，
   * 宽度变化后如仍偏差只调该值）。
   */
  private dockPillWidth(): number {
    const w: number = this.currentWidth > 0 ? this.currentWidth - 64 : 296;
    if (!this.isWideFormDevice) {
      return w > 240 ? w : 240;
    }
    // 大折叠（docs/TiebaPura大折叠适配.md §5，2026-09-15 用户拍板）：底栏与「跳转到贴吧官方」
    // 弹窗同宽（dialogCardWidth 口径，400 封顶），横竖屏同值；平板维持 592 档；
    // SortPillShell 定位公式与 ReplyControls 宽度均经本单点，自动跟随。
    if (isLargeFoldDevice()) {
      return this.dialogCardWidth();
    }
    const capped: number = w > DETAIL_DOCK_TABLET_WIDTH ? DETAIL_DOCK_TABLET_WIDTH : w;
    return capped > 240 ? capped : 240;
  }

  /** 官方悬浮岛底距（vp）：岛底留白 30，与旧评论胶囊 margin bottom 一致 */
  private dockBottomMargin(): number {
    return 30;
  }

  /**
   * 官方悬浮岛总高（vp）：仅包裹评论条；排序切换行已移出为独立悬浮胶囊层。
   * 大折叠（2026-09-15 用户反馈横竖屏均「岛内部偏高、图标文字上下留空偏多」）收一档 66 → 62，
   * CommentBar 岛内 height/padding 联动收 4（内容区不变、整体更紧凑）；平板 / 手机维持 66。
   */
  private dockPillHeight(): number {
    return isLargeFoldDevice() ? 62 : 66;
  }

  // ===== 「帖子沉浸式阅读」交互（2026-09-18，设置 → 个性化 / AppStorage `immersiveReading`）=====

  /**
   * 底部浮层（岛内评论条 / 排序胶囊 / 排序兜底 / 兜底底栏）隐藏位移（vp，向下）。
   * 2026-09-18 三轮改「收回」口径：= (底距 + 岛高) × 0.6 ≈ −58 —— 只下沉约 0.6 倍自身堆叠高，
   * 余下部分由 `opacity(0)` 淡掉；触区仍由 `enabled(false)` 保证（与位移量无关）。
   * 四个底部挂点共用本函数 → 同节奏；位移不再含 +200 出屏余量，各形态档（手机 / 平板 / 大折叠 /
   * 阔直屏）自动按自身几何等比收敛。
   */
  private immersiveBottomSink(): number {
    return -((this.dockBottomMargin() + this.dockPillHeight()) * IMMERSIVE_FLY_SCALE);
  }

  /** 顶栏隐藏位移（vp，向上）：= 官方标题栏高 98 × 0.6 ≈ −59（同「收回」口径，其余交给 opacity 淡出） */
  private immersiveTopSink(): number {
    return -(THREAD_DETAIL_TITLE_BAR_HEIGHT * IMMERSIVE_FLY_SCALE);
  }

  /**
   * 帖子详情滚动 → 沉浸显隐判定。挂点 = 内容主滚动区（竖屏 Scroll / 横屏分栏右栏，共用 `this.scroller`）。
   * 规则（用户拍板）：
   * ① **阈值不对称** —— 向下累计 24vp 藏起、向上累计 12vp 恢复（上滑更容易唤出 UI）；
   * ② **置顶保护** —— 滚动位置 ≤ 8vp（含顶部回弹负值）恒显示，滑到底再回顶一定看得到返回钮；
   * ③ **跳变保护** —— 单次位移 > 240vp 视为命令式 scrollTo 定位 / 旋转分栏切换，丢弃本次方向判定；
   * ④ 触底（onReachEnd）/ 返回本页 / 关闭开关三处立即复位。
   * 分栏左栏（主楼）不挂：主楼通常不满一屏，且与右栏共用一个累计器会互相污染基线。
   */
  private onDetailScroll(_x: number, _y: number): void {
    if (!this.immersiveReading) {
      return;
    }
    // 绝对位置取 Scroller 真值（onScroll 入参语义在工具链间有差异，不作累计位置依赖）
    let pos: number = this.immersiveLastY;
    try {
      pos = this.scroller.currentOffset().yOffset;
    } catch (e) {
      return;
    }
    if (!this.immersiveLastReady) {
      this.immersiveLastY = pos;
      this.immersiveLastReady = true;
      return;
    }
    const delta: number = pos - this.immersiveLastY;
    this.immersiveLastY = pos;
    if (delta === 0) {
      return;
    }
    // ② 置顶保护：顶部恒显示
    if (pos <= IMMERSIVE_READ_TOP_KEEP) {
      this.immersiveAccum = 0;
      if (this.immersiveHidden) {
        this.showImmersive();
      }
      return;
    }
    // ③ 跳变保护
    if (Math.abs(delta) > IMMERSIVE_READ_JUMP_LIMIT) {
      this.immersiveAccum = 0;
      return;
    }
    if (delta > 0) {
      // 向下滚（看更下方内容）→ 累计 24vp 藏起
      this.immersiveAccum = this.immersiveAccum > 0 ? this.immersiveAccum + delta : delta;
      if (!this.immersiveHidden && this.immersiveAccum >= IMMERSIVE_READ_HIDE_DIST) {
        this.hideImmersive();
        this.immersiveAccum = 0;
      }
    } else {
      // 向上滚 → 只要 12vp 就恢复
      this.immersiveAccum = this.immersiveAccum < 0 ? this.immersiveAccum + delta : delta;
      if (this.immersiveHidden && this.immersiveAccum <= -IMMERSIVE_READ_REVEAL_DIST) {
        this.showImmersive();
        this.immersiveAccum = 0;
      }
    }
  }

  /**
   * 复位沉浸态（展开顶栏 / 底栏）。触底、返回本页、关闭开关三处调用。
   * `immersiveLastReady` 一并清掉：下一次滚动只记录基线，不拿旧位置算增量（防误藏）。
   * 复位走 `showImmersive()`：命令式跳转 / 返回是「瞬间到位」的场景，与上滑唤出同一入口。
   */
  private resetImmersive(): void {
    this.immersiveAccum = 0;
    this.immersiveLastReady = false;
    if (this.immersiveHidden) {
      this.showImmersive();
    }
  }

  /** 设置开关变化（@Watch）：关掉开关立即复位，避免页面停留在隐藏态 */
  onImmersiveReadingChanged(): void {
    if (!this.immersiveReading) {
      this.resetImmersive();
    }
  }

  /**
   * 藏起（DT-N 错帧编排，2026-09-19 回退 P-B′ 后恢复）：内容**立即**起步（180ms EaseIn 收回），
   * 玻璃**晚撤** `IMMERSIVE_GLASS_LAG_MS`(180ms) —— 撤玻璃那一刻槽内已 `opacity(0)` + 位移到位 =
   * 空槽，系统那一记「无过渡硬切」被藏到不可见之后（P-B′ 之前的同帧撤玻璃 = 玻璃抢跑，硬切格外显眼）。
   */
  private hideImmersive(): void {
    this.clearImmersiveGlassTimer();
    this.immersiveShowPending = false;
    this.immersiveHidden = true;
    this.immersiveGlassTimer = setTimeout(() => {
      this.immersiveGlassTimer = -1;
      this.immersiveGlassHidden = true;
    }, IMMERSIVE_GLASS_LAG_MS);
  }

  /**
   * 唤出（隐藏过程的反向）：**先给玻璃**，下一帧（`IMMERSIVE_GLASS_LEAD_MS` = 16）再放内容滑回
   * （260ms + springMotion 轻回弹）。顺序不可反：内容先滑回时玻璃会在归位途中凭空出现，那一帧的
   * 「内容悬空」更扎眼。幂等：已是可见态直接返回；`immersiveShowPending` 防置顶保护分支每帧调用
   * 把内容无限顺延（症状：回顶后要等弹跳结束才滑回来）。
   */
  private showImmersive(): void {
    if (!this.immersiveHidden) {
      return;
    }
    this.immersiveGlassHidden = false;
    if (this.immersiveShowPending) {
      return;
    }
    this.immersiveShowPending = true;
    this.clearImmersiveGlassTimer();
    this.immersiveGlassTimer = setTimeout(() => {
      this.immersiveGlassTimer = -1;
      this.immersiveShowPending = false;
      this.immersiveHidden = false;
    }, IMMERSIVE_GLASS_LEAD_MS);
  }

  /** 清理玻璃侧延时器（hideImmersive / showImmersive 重排前 + aboutToDisappear 退页时调用） */
  private clearImmersiveGlassTimer(): void {
    if (this.immersiveGlassTimer !== -1) {
      clearTimeout(this.immersiveGlassTimer);
      this.immersiveGlassTimer = -1;
    }
  }

  /** 退页清理：藏起 180ms / 唤出 16ms 窗口内退出本页时，延时回调不再落到已销毁的组件上 */
  aboutToDisappear(): void {
    this.clearImmersiveGlassTimer();
    // 尾部提示延时器同理：预取在途时退页，1.2s 后的浮出回调不能落到已销毁的组件上
    this.clearLoadingHintTimer();
    // §Z4a 延后补齐调度器同理：延后/重试窗口内退页，回调不能再落到已销毁的组件上
    this.clearEnrichTimer();
  }

  /**
   * 显隐动画参数（藏 / 唤不对称）：取值以**目标态**为准 —— `immersiveHidden` 在本帧渲染前
   * 已由 hideImmersive / showImmersive 写入，故藏起拿到 180ms EaseIn、唤出拿到 springMotion 轻回弹。
   * 注：springMotion 自带时长（由 response 决定），duration 仅对非弹簧曲线生效（保留为可读的标称值）。
   */
  private immersiveAnim(): AnimateParam {
    if (this.immersiveHidden) {
      return { duration: IMMERSIVE_HIDE_MS, curve: Curve.EaseIn };
    }
    return {
      duration: IMMERSIVE_SHOW_MS,
      curve: curves.springMotion(IMMERSIVE_SHOW_SPRING_RESPONSE, IMMERSIVE_SHOW_SPRING_DAMPING)
    };
  }

  /**
   * 排序壳宽（vp，A 方案）：壳只占「两枚胶囊这一列」，不再开全宽。
   * 依据：TabBar 页签节点的命中区恒等于自身矩形，壳全宽时该节点横跨整行，空区照样吞走竖向滑动手势
   * （该节点是系统内部节点，`hitTestBehavior` 挂不到它身上，B 方案已实测无效）；与 ThreadList 的
   * `THREAD_LIST_FAB_SHELL_WIDTH`(84) 同一套做法，区别只在那边是两枚定宽 56 圆钮（28+56），
   * 这边两枚胶囊宽度随字号自适应，故按字号实时推算。
   * 推导（胶囊几何一字未动，只累加它们实际占宽）：
   *   64 = 两枚胶囊左右 padding 4×14 + 钮间 space 8；
   *   6 × fs(12, fontScale) = 文字宽（正序/倒序 2 字 + 只看楼主/只看全部 4 字，汉字宽 ≈ 字号）；
   *   +12 为字重切换（Medium/Regular）与字体度量的余量 —— 宁宽不挤：壳偏宽只多几 vp 死区，
   *   偏窄会让 Tabs 压缩/裁掉胶囊文字。
   * 结果：标准字号 148、极大字号(1.35) 172，仍远小于全宽，该行两侧余下大片可滑动区。
   */
  private sortPillShellWidth(): number {
    return 64 + 6 * fs(12, this.fontScale) + 12;
  }

  /** API26+ 悬浮玻璃路径：真实 Tabs 单内容承载页叠层，底部 Dock 放入 .tabBar() 槽位
   *  （引擎认可 tabBar 槽位属于 TabBar 生效范围，悬浮条本体挂官方材质） */
  @Builder
  ImmersiveDockShell() {
    Tabs({ barPosition: BarPosition.End }) {
      TabContent() {
        this.ContentLayer()
      }
      .tabBar(this.FloatingDock())
    }
    .width('100%')
    .height('100%')
    .vertical(false)
    .scrollable(false)
    .barOverlap(true)
    .barHeight(this.dockPillHeight())
    .barBackgroundColor(Color.Transparent)
    // 去掉底栏默认模糊背板：barBackgroundBlurStyle 默认值是 BlurStyle.COMPONENT_REGULAR，
    // 不关它会在悬浮岛后方渲染一条全宽磨砂带，上边缘看起来像一条细光感线（坑 26 同源）。
    // 悬浮岛的玻璃由 barFloatingStyle.systemMaterial 承担，与该属性无关，关掉不影响官方材质。
    .barBackgroundBlurStyle(BlurStyle.NONE)
    // 沉浸阅读（DT-M 杠杆① / DT-N 玻璃侧状态位）：隐藏态把胶囊宽度收 0 ⇒ 零面积 ⇒ 系统玻璃无从渲染；
    // barWidth 与 barBottomMargin 同层同源，响应式生效已由既有 dockNudge 机制验证。
    // ⚠️ 已知遗留（根因未解）：系统侧胶囊有最小宽地板（A1 实测宽 56），隐藏态会残留一枚小胶囊（文档 §4.9「遗留」）。
    .barFloatingStyle({
      barWidth: {
        smallBarWidth: this.immersiveGlassHidden ? 0 : this.dockPillWidth(),
        mediumBarWidth: this.immersiveGlassHidden ? 0 : this.dockPillWidth(),
        largeBarWidth: this.immersiveGlassHidden ? 0 : this.dockPillWidth()
      },
      // 首帧重排触发（2026-09-13）：见 dockNudge 声明处的说明，0.5vp 微变触发系统重排悬浮条。
      barBottomMargin: this.dockBottomMargin() + this.dockNudge * 0.5,
      // 沉浸阅读隐藏态（DT-P / 实验 L1，2026-09-19）：换官方「空材质」⇒ 悬浮条的材质层不再渲染。
      // 与 P-B 的「撤材质（不传 / 传 undefined）」是两条路 —— 后者是「不设置」，系统回落自己的
      // 默认材质（真机实测 = 一层白背板）；本档是显式「关材质」，官方语义即「无材质效果」。
      // 隐藏态 barWidth 收 0 仍被系统最小宽地板钳住（约 56px）留一枚空壳，但空壳此刻无材质可画。
      // 判读：胶囊彻底消失 = L1 成立；若反而出现更大白板 = 白底是悬浮条自身默认背景 → 转 L2。
      systemMaterial: this.immersiveGlassHidden ? ImmMaterial.empty() : ImmMaterial.floatingBar()
    })
    .backgroundColor(Color.Transparent)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .clip(false)
  }

  /**
   * 官方悬浮岛（tabBar 槽位）= 评论条内容层。**玻璃由系统侧渲染**（`barFloatingStyle.systemMaterial`），
   * 槽宽也由系统按 `barWidth`（= `dockPillWidth()`）约束 —— 平板等宽屏下岛内元素照样收在岛宽内。
   * 2026-09-19：P-B′「自绘玻璃岛」按用户要求回退（平板出问题），恢复系统侧玻璃 + DT-N 错帧编排。
   * 回退主因记录：P-B′ 期间槽内容变成「全宽铺开、靠 CommentBar 自身居中」，宽屏下与岛宽脱钩 →
   * 平板岛内元素铺到屏宽两侧；且玻璃改由应用层绘制后，沉浸隐藏的错帧编排一并失效。
   */
  @Builder
  FloatingDock() {
    Column() {
      this.CommentBar(true)
    }
    .width('100%')
    .height('100%')
    // 首帧垂直居中兜底（2026-09-13）：官方悬浮条槽位的首帧高度可能被系统临时算大（含安全区等），
    // 而 Column 默认主轴 Start（顶对齐）→ 槽内内容整体顶在槽顶、偏上，且点赞/收藏/发送（42 高）
    // 与跳转胶囊（46 高）偏移量随高度略异 → 真机表现「首帧各元素不齐，旋转一下重排后才正常」。
    // 改为 justifyContent(Center)：**无论槽首帧多高，内容 Row(66) 始终居中于槽**，首帧即正确；
    // 槽高正常（=66）时与顶对齐等价，手机零变化。
    .justifyContent(FlexAlign.Center)
    .padding({ left: 8, right: 8 })
    // 沉浸阅读（DT-N）：内容侧下沉 + 淡出 + 禁用命中（玻璃侧错帧由 hideImmersive / showImmersive 编排）
    .translate({ y: this.immersiveHidden ? this.immersiveBottomSink() : 0 })
    .opacity(this.immersiveHidden ? 0 : 1)
    // opacity 0 的组件仍参与命中测试，必须显式禁用，避免「看不见但能点到点赞/收藏/发送」
    .enabled(!this.immersiveHidden)
    .animation(this.immersiveAnim())
  }

  /** 排序切换胶囊独立悬浮层（官方壳路径）：正序/只看全部两枚钮不进入悬浮岛，
   *  各自完整玻璃胶囊悬浮于评论岛上方，几何复刻旧 Dock：钮底距岛顶 8vp。
   *  外层 Column 底部 margin = 岛底余量(30) + 岛高(66)，使钮底恰好悬于岛顶上方 8vp。 */
  @Builder
  SortRowOverlay() {
    Column() {
      this.ReplyControls()
    }
    .width('100%')
    .margin({ bottom: this.dockBottomMargin() + this.dockPillHeight() })
    // 沉浸阅读（2026-09-18）：兜底路径排序行走同一套下沉显隐
    .translate({ y: this.immersiveHidden ? this.immersiveBottomSink() : 0 })
    .opacity(this.immersiveHidden ? 0 : 1)
    .enabled(!this.immersiveHidden)
    .animation(this.immersiveAnim())
  }

  /**
   * 排序胶囊官方槽位壳（官方壳路径专用）：搭一个「只有 tabBar 的真实 Tabs」把排序行送进官方槽位。
   * 依据：官方 A 档「按钮与选择类」只有 Slider / Toggle / Select，Button / Chip / SegmentButton 全属 B 档，
   * 仅在 Navigation 标题栏与 Tabs(barPosition: End) 底部 TabBar 内生效（官方文档 §4.1/§4.2）；
   * 而这两枚胶囊悬浮在页面中部，原写法必判 Material inactive: out of scope。
   * 关键三点：
   * ① TabContent 留空（内容区高度 = 壳高 46 - barHeight 46 = 0），壳里实际只有 tabBar 一行；
   * ② 不传 .barFloatingStyle(...) —— 官方悬浮背板整体不生成，不会凭空多出一条玻璃底
   *    （Index.ets 收藏编辑态已验证「不传 floating style 即彻底移除官方背板」）；
   * ③ **壳宽收窄成「两枚胶囊这一列」**（A 方案，宽度见 sortPillShellWidth）：页签节点的命中区
   *    恒等于壳矩形，壳开全宽时该节点横跨整行、空区照样吞掉竖向滑动（该节点是系统内部节点，
   *    hitTestBehavior 挂不到它身上，B 方案已在 ThreadList 实测无效）；收窄后死区与两枚胶囊重合，
   *    该行两侧恢复可滑动。
   * 几何：壳高 = barHeight = 46；底距 = 岛底余量(30) + 岛高(66) —— 与改造前 SortRowOverlay 的
   * margin-bottom 逐项相同；壳宽收窄后由外层全宽 Row 用 padding-left 32 钉回改造前的左缘，
   * 故两枚胶囊的位置/大小/间距一行未改，只是玻璃来源换成官方材质、壳不再横跨整行。
   */
  @Builder
  SortPillShell() {
    // 水平定位（2026-09-13）：公式定位 + 横屏实测左移修正 ——
    // 基准 = (currentWidth − 底栏宽) / 2（底栏由系统居中，壳左缘对齐底栏左缘）；
    // 手机档 (393 − 329) / 2 = 32 逐像素不变。
    // 横屏分栏（splitMode）下真机实测排序壳偏右（官方岛视觉左缘与公式值存在系统级偏差）；
    // 修正量经真机二轮校准：28（偏左）→ 38（更偏左）→ 定 16（28 偏左说明左移过量，回撤 12）。
    // 真机微调项：偏差变化时只调这一个值；竖屏 / 手机不修正。
    // Row 与壳都挂 hitTestBehavior(None)：自身不参与触摸测试，子节点（两枚胶囊）与兄弟节点照常
    // （与 ThreadList FabSlotShell 的同名处理一致）。
    Row() {
      Tabs({ barPosition: BarPosition.End }) {
        TabContent()
          .tabBar(this.SortRowInSlot())
      }
      .width(this.sortPillShellWidth())
      .height(THREAD_DETAIL_SORT_ROW_HEIGHT)
      .vertical(false)
      .scrollable(false)
      // 不挂 barOverlap：官方说明 barOverlap(true) 会把底栏默认模糊触发为 BlurStyle.COMPONENT_THICK，
      // 残留的模糊背板/阴影会投在胶囊下方（真机可见一条全宽渐变带 + 细线）；本壳 TabContent 为空、
      // 内容区高度恒 0，barOverlap 无任何布局作用，纯负资产。底栏岛壳 ImmersiveDockShell 内容要延伸
      // 到悬浮岛之下才需要 barOverlap，且有 barFloatingStyle 重构整条 bar，故不受影响。
      .barHeight(THREAD_DETAIL_SORT_ROW_HEIGHT)
      .barBackgroundColor(Color.Transparent)
      // 去掉底栏默认模糊背板：barBackgroundBlurStyle 默认值是 BlurStyle.COMPONENT_REGULAR，
      // 不显式关掉时即使 barBackgroundColor 透明，槽内仍会渲染一条磨砂板遮挡内容。
      .barBackgroundBlurStyle(BlurStyle.NONE)
      .backgroundColor(Color.Transparent)
      .clip(false)
      .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height(THREAD_DETAIL_SORT_ROW_HEIGHT)
    .justifyContent(FlexAlign.Start)
    // 水平定位（2026-09-13）：基准 = (currentWidth − 底栏宽) / 2（底栏居中、壳左缘对齐底栏左缘）；
    // 横屏分栏真机微调：底栏加宽到 592 后实测胶囊仍偏右 → 左移量 16 → 28 → 40（2026-09-14 两轮校准，偏差变化时只调这一个值）；
    // 竖屏 / 手机维持公式（手机 (393 − 329) / 2 = 32 逐像素不变）。
    .padding({
      // 大折叠（2026-09-15 真机反馈）：不套用 −40 平板分栏修正——那是平板 592 底栏的系统偏差校准值，
      // 大折叠底栏 400（dialogCardWidth 口径），纯公式定位已对齐底栏左缘，再减 40 会把排序壳推出底栏外。
      // 阔直屏（2026-09-17 用户云调试反馈横屏排序钮偏左 + 离底栏远）同理排除：纯公式即与底栏左缘对齐
      left: Math.max(0, (this.currentWidth - this.dockPillWidth()) / 2
        - (this.splitMode() && !isLargeFoldDevice() && !isPuraXMaxDevice() && !isWideBarDevice() ? 40 : 0))
    })
    .hitTestBehavior(HitTestMode.None)
    // 底距沿用原壳上的 margin（岛底余量 30 + 岛高 66），margin 已移交外层 Row，壳自身不再设；
    // 横屏分栏追加 14vp 呼吸（真机反馈横屏下排序行与底栏贴住）——大折叠不套用（2026-09-15
    // 真机反馈大折叠横屏排序胶囊离底栏太远，其底栏 400 较矮，与竖屏同距即可）；阔直屏同理不套用
    // （2026-09-17 用户反馈横屏排序钮离底栏远，回落与竖屏同距）
    .margin({ bottom: this.dockBottomMargin() + this.dockPillHeight()
      + (this.splitMode() && !isLargeFoldDevice() && !isPuraXMaxDevice() && !isWideBarDevice() ? 14 : 0) })
    // 沉浸阅读（2026-09-18 三轮；2026-09-19 回退 P-B′ 后不变）：约 0.6 倍高下沉 + 淡出。
    // 本行是应用节点（排序壳兜底叠加层），与底栏岛内容层同帧起步；玻璃侧错帧不改本行。
    .translate({ y: this.immersiveHidden ? this.immersiveBottomSink() : 0 })
    .opacity(this.immersiveHidden ? 0 : 1)
    .enabled(!this.immersiveHidden)
    .animation(this.immersiveAnim())
  }

  /** 排序行（官方槽位版）：外层 Column 撑满壳宽，内层 Row 塞满 Column，几何与 SortRowOverlay 内
   *  ReplyControls 逐项一致（space 8、padding top4/bottom8、两钮靠左排列）。
   *  行宽跟随壳宽（'100%'）而非写死「屏宽 - 64vp」：A 方案把壳宽收窄成两枚胶囊这一列后，
   *  若行仍按屏宽算宽度会溢出壳，且 100% 的参照物已从「屏宽」变成「壳宽」，必须同步改。
   *  左缘 32 由 SortPillShell 外层 Row 的 padding-left 承担，本行不再负责定位。 */
  @Builder
  SortRowInSlot() {
    Column() {
      Row({ space: 8 }) {
        this.SortPillInSlot(this.sortType === 0 ? '正序' : '倒序', this.sortType === 0, (): void => {
          this.sortType = this.sortType === 0 ? 1 : 0;
          this.loadDetail();
        })
        this.SortPillInSlot(this.seeLz ? '只看楼主' : '只看全部', this.seeLz, (): void => {
          this.seeLz = !this.seeLz;
          this.loadDetail();
        })
      }
      .width('100%')
      .padding({ top: 4, bottom: 8 })
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  /**
   * 排序胶囊（官方槽位版）：几何与旧 SortPill 逐项一致（高 34 / 左右 padding 14 / 字号 12 /
   * Radius.full / 选中与未选中两态），只把玻璃换成官方沉浸材质，并按官方口径删掉
   * backgroundColor / border / backgroundBlurStyle / shadow 四项（材质自带底、描边与阴影，不要与材质叠用）：
   * - Button 必须显式 backgroundColor(Color.Transparent)：Button 自带品牌蓝默认填充，不清底会透出蓝底；
   * - seg(false) 为 THIN 中性档、seg(true) 为 REGULAR 档，与顶栏 DetailTitleBar 同款（上下两端观感统一）。
   */
  @Builder
  SortPillInSlot(label: string, active: boolean, onTap: () => void) {
    Button(label)
      .fontSize(fs(12, this.fontScale))
      .fontColor(active ? Theme.segActiveText(this.isDark) : $r('sys.color.font_secondary'))
      .fontWeight(active ? FontWeight.Medium : FontWeight.Regular)
      .backgroundColor(Color.Transparent)
      // 无阴影档：两枚胶囊浮在白卡上方，材质自带阴影落在卡面合并成一层淡阴影（真机反馈要求去除）；
      // 顶栏 DetailTitleBar 胶囊仍用 seg（带阴影）。
      .systemMaterial(ImmMaterial.segFlat(active))
      .borderRadius(Radius.full)
      .height(34)
      .padding({ left: 14, right: 14 })
      .onClick(onTap)
  }

  /**
   * 顶部满宽渐显带（DST_IN 遮罩，同 Search.TopFadeOverlay / ThreadList.BottomFadeOverlay 模板）：
   * 纵向渐变（顶端全透明 → 带底全不透明）作为 alpha 源，内容滚入顶栏区域时自上而下「渐显」，
   * 而非被顶栏硬切一刀。高度固定 = 吧名胶囊下沿（TOP_FADE_BAND_HEIGHT = 44 状态栏让位 + 44 胶囊高），
   * 带外内容不受影响、不参与命中测试。因为只挂在楼层内容层上，悬浮顶栏（返回/分享/吧名胶囊）保持全实。
   */
  @Builder
  TopFadeBand() {
    Stack()
      .width('100%')
      .height(TOP_FADE_BAND_HEIGHT)
      .linearGradient({
        direction: GradientDirection.Bottom,
        colors: [['#00FFFFFF', 0.0], ['#FFFFFFFF', 1.0]]
      })
      .blendMode(BlendMode.DST_IN, BlendApplyType.OFFSCREEN)
      .hitTestBehavior(HitTestMode.None)
  }

  /**
   * 官方槽位标题栏：整行搬进 Navigation 的 title 槽位。
   * 几何与旧悬浮顶栏逐项一致（外层 high 98 / padding top 44 + bottom 10 + 左右 Spacing.lg、Row high 44、
   * 吧名胶囊 58% 宽 + 左右 padding 16 + 居中），只把玻璃从 segGlass + backgroundBlurStyle 自绘换成官方沉浸材质：
   * - 返回钮 / 分享钮 / 吧名胶囊 → ImmMaterial.seg(false)（THIN 中性档，与首页、进吧顶栏同一套材质语言）；
   * - 三处都是 Button，必须显式 backgroundColor(Color.Transparent)：Button 自带品牌蓝默认填充，不清底会透出蓝底；
   * - 不挂 border / backgroundBlurStyle / shadow：官方明确不建议与 systemMaterial 同用（会互相覆盖）；
   * - 旧外壳 Stack 的「透明 border / shadow 清底」与 zIndex(10) 一并去掉（槽内不再需要叠层序）。
   * 图标/文字色沿用系统可反色资源（icon_primary / font_primary），满足官方自动反色前提。
   */
  @Builder
  DetailTitleBar() {
    Stack() {
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.chevron_left')).fontColor([$r('sys.color.icon_primary')]).fontSize(fs(24, this.fontScale))
        }
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .systemMaterial(ImmMaterial.seg(false))
        .borderRadius(Radius.full)
        .onClick(() => { this.goBack(); })
        Blank()
        // 分享按钮（右上角）：与返回钮同档玻璃，点按分享当前帖子
        //（与首页 ThreadCard 分享同机制：Share Kit 系统分享面板，失败兜底剪贴板）
        Button() {
          SymbolGlyph($r('sys.symbol.share')).fontColor([$r('sys.color.icon_primary')]).fontSize(fs(24, this.fontScale))
        }
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .systemMaterial(ImmMaterial.seg(false))
        .borderRadius(Radius.full)
        .accessibilityText('分享帖子')
        .onClick(() => { this.shareThread(this.buildSharePayload()); })
      }
      .width('100%')
      .height(44)
      .align(Alignment.Start)
      Button() {
        Text(this.detail ? `${this.detail.forumName || this.forumName || '贴吧'}吧` : `${this.forumName || '贴吧'}吧`)
          .fontSize(fs(16, this.fontScale))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: '85%' })
      }
      .backgroundColor(Color.Transparent)
      .systemMaterial(ImmMaterial.seg(false))
      .borderRadius(Radius.full)
      .height(44)
      .width('58%')
      .padding({ left: 16, right: 16 })
      .align(Alignment.Center)
      .accessibilityText('进入贴吧主页')
      .onClick(() => { this.openForumHome(); })
    }
    .width('100%')
    .height(98)
    .padding({ left: Spacing.lg, right: Spacing.lg, top: 44, bottom: 10 })
    .backgroundColor(Color.Transparent)
    // 沉浸阅读（2026-09-18 三轮）：整行上移约 0.6 倍高（−59）+ 淡出，藏起 180ms EaseIn / 唤出 260ms 轻回弹。
    // 槽位高度固定 98 不参与内容布局（Scroll 首项自带 98 占位），故位移不影响正文排布。
    .translate({ y: this.immersiveHidden ? this.immersiveTopSink() : 0 })
    .opacity(this.immersiveHidden ? 0 : 1)
    // opacity 0 的组件仍参与命中测试，必须显式禁用，避免"看不见但能点到返回/分享"
    .enabled(!this.immersiveHidden)
    .animation(this.immersiveAnim())
  }

  /**
   * 兜底路径顶栏（改造前原样）：页面主体悬浮层（内容可穿过）+ segGlass 极淡底 + backgroundBlurStyle 真模糊磨砂。
   * 仅在官方 title 槽位不可用时挂载（见 ContentLayer 的条件挂载）。
   */
  @Builder
  LegacyTopBar() {
    Stack() {
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.chevron_left')).fontColor([$r('sys.color.icon_primary')]).fontSize(fs(24, this.fontScale))
        }
        .width(44)
        .height(44)
        .backgroundColor(Theme.segGlass(this.isDark, false))
        .border({ width: 0.5, color: Theme.manualGlassBorder() })
        .backgroundBlurStyle(BlurStyle.Thin, { scale: 0.85 })
        .shadow(Theme.segGlassShadow(this.isDark, false))
        .borderRadius(Radius.full)
        .onClick(() => { this.goBack(); })
        Blank()
        // 分享按钮（右上角）：UI 与返回按钮一致（44 圆钮 + segGlass 极淡底 + backgroundBlurStyle 真模糊磨砂），
        // 点按分享当前帖子（与首页 ThreadCard 分享同机制：Share Kit 系统分享面板，失败兜底剪贴板）
        Button() {
          SymbolGlyph($r('sys.symbol.share')).fontColor([$r('sys.color.icon_primary')]).fontSize(fs(24, this.fontScale))
        }
        .width(44)
        .height(44)
        .backgroundColor(Theme.segGlass(this.isDark, false))
        .border({ width: 0.5, color: Theme.manualGlassBorder() })
        .backgroundBlurStyle(BlurStyle.Thin, { scale: 0.85 })
        .shadow(Theme.segGlassShadow(this.isDark, false))
        .borderRadius(Radius.full)
        .accessibilityText('分享帖子')
        .onClick(() => { this.shareThread(this.buildSharePayload()); })
      }
      .width('100%')
      .height(44)
      .align(Alignment.Start)
      Button() {
        Text(this.detail ? `${this.detail.forumName || this.forumName || '贴吧'}吧` : `${this.forumName || '贴吧'}吧`)
          .fontSize(fs(16, this.fontScale))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: '85%' })
      }
      .backgroundColor(Theme.segGlass(this.isDark, false))
      .border({ width: 0.5, color: Theme.manualGlassBorder() })
      .backgroundBlurStyle(BlurStyle.Thin, { scale: 0.85 })
      .shadow(Theme.segGlassShadow(this.isDark, false))
      .borderRadius(Radius.full)
      .height(44)
      .width('58%')
      .padding({ left: 16, right: 16 })
      .align(Alignment.Center)
      .accessibilityText('进入贴吧主页')
      .onClick(() => { this.openForumHome(); })
    }
    .width('100%')
    .height(98)
    .padding({ left: Spacing.lg, right: Spacing.lg, top: 44, bottom: 10 })
    .backgroundColor(Color.Transparent)
    .border({ width: 0, color: Color.Transparent })
    .shadow({ radius: 0, color: Color.Transparent, offsetY: 0 })
    .zIndex(10)
    // 沉浸阅读（2026-09-18 三轮）：与官方槽位路径 DetailTitleBar 同款（0.6 倍上移 + 淡出 + 禁用命中）
    .translate({ y: this.immersiveHidden ? this.immersiveTopSink() : 0 })
    .opacity(this.immersiveHidden ? 0 : 1)
    .enabled(!this.immersiveHidden)
    .animation(this.immersiveAnim())
  }

  /** 内容层（主楼/楼层 Scroll 全量渲染 + 骨架屏/错误态 + 悬浮顶栏），借壳与兜底分支共用 */
  @Builder
  ContentLayer() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 内容层：detail 就绪即挂载，透明度由 fadeInContent 控制淡入（0→1）
        if (this.detail) {
          // 楼层容器修复（2026-09）：原 List(虚拟滚动) 的可视窗口与沉浸绘制区错位，
          // 楼层一旦滚过"正序栏/底栏"那条横线就被当作视口外整层剔除（消失）。
          // 该剔除与懒加载无关：底栏移除、全量 ForEach(仍在 List 内)均复现。
          // 改用 Scroll + Column 全量渲染后不再消失，故固定此方案。
          if (this.isSplit) {
            // ===== 横屏分栏（§4.9 DT-I）：左栏固定宽 =「帖子本身宽度」，右栏回复三列瀑布流 =====
            // 沉浸四项（overlay / blendMode / backgroundColor / opacity）必须**整体**挂在这一层：
            // 只挂右栏会让顶部渐隐只盖右栏、blendMode 作用域错位（DT-E 红线）。
            Column() {
              Column().width('100%').height(98)
              Row({ space: Spacing.md }) {
                // 左栏：主楼（独立滚动；不挂 onReachEnd / id —— 主楼不参与分页与楼层定位）
                // 首项放「幽灵表头占位」（2026-09-13）：右栏第一排卡片上方有「回复 N 条」表头 +
                // 12 间距，左栏主楼卡若直接顶格会比右栏卡片高出一截（真机反馈错位）。
                // 占位与 ReplySectionHeader 同几何（随字号缩放同步），Column space 12 与右栏同构
                // → 主楼卡顶 ≡ 右栏第一排卡片顶。
                Scroll(this.scrollerLeft) {
                  Column({ space: Spacing.md }) {
                    this.ReplyHeaderGhost()
                    this.PostHeader()
                  }
                  .width('100%')
                  // 主楼短于视口时顶对齐（Scroll 对小内容默认垂直居中）
                  .constraintSize({ minHeight: '100%' })
                }
                .width(this.splitMainWidth())
                .scrollBar(BarState.Off)
                .clip(false)
                .edgeEffect(EdgeEffect.Spring)
                .padding({ left: Spacing.lg, right: 8, bottom: 160 })

                // 右栏：回复区（保留 id / onReachEnd / 底部让位 → 楼层定位与分页公式零改动）
                // 弃用 WaterFlow + sections（错位修复二，同竖屏分支）：回归 Scroll + 列内独立堆叠
                Scroll(this.scroller) {
                  Column({ space: Spacing.md }) {
                    if (this.floorsReady) {
                      Column({ space: Spacing.md }) {
                        this.ReplySectionHeader()
                        this.FloorColumnsBlock()
                        this.FooterSentinel()
                      }
                      .width('100%')
                      .opacity(this.floorsOpacity)
                    }
                  }
                  .width('100%')
                  // 回复少时顶对齐（Scroll 对小内容默认垂直居中）
                  .constraintSize({ minHeight: '100%' })
                  // 无感翻页：内容高采集（滚动预取剩余距离 = 内容高 - 视口高 - 偏移）
                  .onAreaChange((_oldValue: Area, newValue: Area) => {
                    this.detailContentH = newValue.height as number;
                  })
                }
                .layoutWeight(1)
                .width('100%')
                .padding({ left: 8, right: Spacing.lg, bottom: 160 })
                .id('thread_scroll_content')
                .scrollBar(BarState.Off)
                .clip(false)
                .edgeEffect(EdgeEffect.Spring)
                // 无感翻页：视口高采集
                .onAreaChange((_oldValue: Area, newValue: Area) => {
                  this.detailViewportH = newValue.height as number;
                })
                .onReachEnd(() => {
                  // 沉浸阅读：触底即复位（用户到这里多半要用评论栏）
                  this.resetImmersive();
                  // 无感翻页：已到边界，后台预取若仍在途则立即浮出提示（不再静默）
                  this.revealLoadHintOnReachEnd();
                  if (!this.loadingMore && this.hasMoreFloors) {
                    this.loadMoreFloors();
                  }
                })
                // 沉浸阅读（2026-09-18）：方向阈值驱动顶栏 / 底栏显隐（左栏主楼不挂，见 onDetailScroll 注释）
                // 无感翻页（2026-09-19）：同一挂点串联滚动预取（.onScroll 只能挂一个，不能另起挂点）
                .onScroll((xOffset: number, yOffset: number) => {
                  this.onDetailScroll(xOffset, yOffset);
                  this.onDetailScrollPrefetch();
                })
              }
              .width('100%')
              .layoutWeight(1)
              .alignItems(VerticalAlign.Top)
            }
            .width('100%')
            .height('100%')
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
            .overlay(this.TopFadeBand(), { align: Alignment.Top })
            .blendMode(BlendMode.SRC_OVER, BlendApplyType.OFFSCREEN)
            .backgroundColor(Theme.bg(this.isDark))
            .opacity(this.contentOpacity)
            .translate({ y: this.contentTranslateY })
          } else {
          // ===== 竖屏 / 手机：Scroll + Column，楼层「列内独立堆叠」多列（2026-09-13 错位修复二）=====
          // 弃用 WaterFlow + sections：真机两轮复现「FlowItem 内容按全宽测量却被按三列摆放」的
          // 引擎级段计数竞态（卡片重叠 / 内容跨列溢出），无法可靠修复；改用与 Scroll 兼容的
          // 「列内独立堆叠」三列 Row（瀑布流观感本质 = 无行内对齐留白），通栏项 / 定位 / 分页 /
          // 沉浸属性全部回到改造前已验证的 Scroll 挂点。楼层仍全量渲染（规避历史 List 视口剔除 bug）。
          Scroll(this.scroller) {
            Column({ space: Spacing.md }) {
              // 预留顶栏高度作为初始间距
              Column().width('100%').height(98)
              // 主楼通栏满宽（2026-09-17 二次拍板：等宽仅横屏分栏生效，竖屏不用）
              this.PostHeader()
              if (this.floorsReady) {
                Column({ space: Spacing.md }) {
                  this.ReplySectionHeader()
                  this.FloorColumnsBlock()
                  this.FooterSentinel()
                }
                .width('100%')
                .opacity(this.floorsOpacity)
              }
            }
            .width('100%')
            // 内容少时必须顶对齐：Scroll 对「小于视口的内容」默认垂直居中（真机表现为主楼悬在
            // 页面中部、上方大片空白）。Scroll 无 alignment 属性 → 用 minHeight 让列恒占满视口，
            // Column 默认主轴 Start → 内容自上而下；内容多时 minHeight 不生效，滚动照常。
            .constraintSize({ minHeight: '100%' })
            // 无感翻页：内容高采集（滚动预取剩余距离 = 内容高 - 视口高 - 偏移）
            .onAreaChange((_oldValue: Area, newValue: Area) => {
              this.detailContentH = newValue.height as number;
            })
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off)
          // 为底部悬浮回复栏留出滚动空间，最后一项可完整滚入屏幕
          .padding({ left: Spacing.lg, right: Spacing.lg, top: 0, bottom: 160 })
          .edgeEffect(EdgeEffect.Spring)
          // 无感翻页：视口高采集
          .onAreaChange((_oldValue: Area, newValue: Area) => {
            this.detailViewportH = newValue.height as number;
          })
          // 滚动触底：自动加载下一页楼层（loadingMore/hasMore 双防重）
          .onReachEnd(() => {
            // 沉浸阅读：触底即复位（用户到这里多半要用评论栏）
            this.resetImmersive();
            // 无感翻页：已到边界，后台预取若仍在途则立即浮出提示（不再静默）
            this.revealLoadHintOnReachEnd();
            if (!this.loadingMore && this.hasMoreFloors) {
              this.loadMoreFloors();
            }
          })
          .id('thread_scroll_content')
          // 沉浸阅读（2026-09-18）：方向阈值驱动顶栏 / 底栏显隐
          // 无感翻页（2026-09-19）：同一挂点串联滚动预取（.onScroll 只能挂一个，不能另起挂点）
          .onScroll((xOffset: number, yOffset: number) => {
            this.onDetailScroll(xOffset, yOffset);
            this.onDetailScrollPrefetch();
          })
          // 沉浸：绘制扩展到状态栏与底部安全区，滚动可视区 = 整屏，无独立裁剪层
          .clip(false)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          // 顶部满宽渐显带：只挂在楼层内容层上（悬浮顶栏是同级兄弟节点，不受此遮罩影响，胶囊钮保持全实）
          .overlay(this.TopFadeBand(), { align: Alignment.Top })
          .blendMode(BlendMode.SRC_OVER, BlendApplyType.OFFSCREEN)
          .backgroundColor(Theme.bg(this.isDark))
          .opacity(this.contentOpacity)
          .translate({ y: this.contentTranslateY })
          }
        }
        // 骨架屏覆盖层：Loading 期间盖在内容上方，透明度由 fadeInContent 控制淡出（1→0）
        // §P0-4：skeletonVisible 未放行（首屏 120ms 窗口内命中缓存）时不挂载，全程无骨架屏
        if (this.loadState === LoadState.Loading && this.skeletonVisible) {
          ThreadDetailSkeleton()
            .layoutWeight(1)
            .opacity(this.skeletonOpacity)
        }
        if (this.loadState === LoadState.Error) {
          ErrorView({ message: this.errorMsg, onRetry: () => { this.loadDetail(); } }).layoutWeight(1)
        }

        // 悬浮顶栏（内容可穿过）；官方 title 槽位路径下三元素已在槽位里（DetailTitleBar），这里不再叠一层
        if (!(THREAD_DETAIL_OFFICIAL_TITLE_BAR && this.materialSupported)) {
          this.LegacyTopBar()
        }
    }
    .width('100%')
    .height('100%')
    // 不再在此处限制底部高度/背景：楼层内容自带 backgroundColor 与底部留白，
    // 保证内容层透明，让底部沉浸悬浮栏背后的内容可透出。
  }

  /** 底部悬浮栏（排序栏 + 评论栏）叠放：root Stack(Bottom) 内贴底悬浮，两栏分体、楼层内容可穿行其后 */
  @Builder
  BottomDock() {
    Column() {
      if (this.loadState === LoadState.Success && this.detail) {
        this.ReplyControls()
      }
      this.CommentBar(false)
    }
    .width('100%')
    .align(Alignment.Bottom)
    // 沉浸阅读（2026-09-18 三轮）：兜底底栏（排序行 + 评论条）约 0.6 倍高下沉 + 淡出（该路径无官方玻璃，无时序问题）
    .translate({ y: this.immersiveHidden ? this.immersiveBottomSink() : 0 })
    .opacity(this.immersiveHidden ? 0 : 1)
    .enabled(!this.immersiveHidden)
    .animation(this.immersiveAnim())
  }

  /** 排序切换行：正序 / 只看全部两枚独立玻璃小胶囊。旧叠放路径贴于评论条上方，
   *  官方壳路径经 SortRowOverlay 悬浮于评论岛上方。
   *  宽度与评论条同源（`dockPillWidth()`，手机基线 296）→ 排序行左缘 = 底栏左缘
   *  （父 `BottomDock` 的 `align(Alignment.Bottom)` 水平居中，两行左缘天然对齐）。 */
  @Builder
  ReplyControls() {
    Row({ space: 8 }) {
      this.SortPill(this.sortType === 0 ? '正序' : '倒序', this.sortType === 0, (): void => {
        this.sortType = this.sortType === 0 ? 1 : 0;
        this.loadDetail();
      })
      this.SortPill(this.seeLz ? '只看楼主' : '只看全部', this.seeLz, (): void => {
        this.seeLz = !this.seeLz;
        this.loadDetail();
      })
    }
    .width(this.dockPillWidth())
    .padding({ top: 4, bottom: 8 })
    .justifyContent(FlexAlign.Start)
    .backgroundColor(Color.Transparent)
    .zIndex(9)
  }

  /** 排序切换胶囊：正序/只看全部各自独立的真磨砂玻璃小胶囊。
   *  不挂 systemMaterial：钮悬浮于楼层内容上方，属页面主体元素，官方材质槽位
   *  （Navigation 标题栏 / Tabs 底部栏 / 弹窗）之外，systemMaterial 挂此不渲染
   *  （Material inactive: out of scope，ThreadList 排序段同受此限）。
   *  内容区玻璃唯一可靠途径 = backgroundBlurStyle 真磨砂 + segGlass 极淡底色
   *  （亮色近透明，让楼层文字滑过钮后仍可透出）+ 白高光描边 + 浮起阴影。
   *  两路径（官方壳悬浮层 / 旧叠放）均使用同一完整样式，不再随 materialSupported 简化 */
  @Builder
  SortPill(label: string, active: boolean, onTap: () => void) {
    Button(label)
      .fontSize(fs(12, this.fontScale))
      .fontColor(active ? Theme.segActiveText(this.isDark) : $r('sys.color.font_secondary'))
      .fontWeight(active ? FontWeight.Medium : FontWeight.Regular)
      .backgroundColor(Theme.segGlass(this.isDark, active))
      .border({ width: 0.5, color: Theme.manualGlassBorder() })
      .backgroundBlurStyle(active ? BlurStyle.Regular : BlurStyle.Thin,
        { scale: active ? 0.8 : 0.85 })
      .shadow(Theme.segGlassShadow(this.isDark, active))
      .borderRadius(Radius.full)
      .height(34)
      .padding({ left: 14, right: 14 })
      .onClick(onTap)
  }

  // 点赞请求进行中标志：防止连点产生"点赞→立即取消"连环请求（贴吧对该模式限流，报 3280001）
  private likeInFlight: boolean = false;

  private async toggleLike(): Promise<void> {
    if (this.likeInFlight) {
      return;
    }
    this.likeInFlight = true;
    try {
      await this.doToggleLike();
    } finally {
      this.likeInFlight = false;
    }
  }

  private async doToggleLike(): Promise<void> {
    const previous: boolean = this.liked;
    const next: boolean = !previous;
    this.liked = next;
    // Optimistically update like count
    if (this.detail) {
      const d = this.detail;
      const currentCount = d.likeCount ?? 0;
      this.detail = {
        tid: d.tid, postId: d.postId, forumId: d.forumId,
        forumAvatar: d.forumAvatar, title: d.title, forumName: d.forumName,
        author: d.author, authorAvatar: d.authorAvatar, authorId: d.authorId,
        content: d.content, contentText: d.contentText,
        images: d.images, replyNum: d.replyNum,
        likeCount: currentCount + (next ? 1 : -1),
        isLiked: next,
        isCollected: d.isCollected,
        createTime: d.createTime, page: d.page, totalPage: d.totalPage,
      };
    }
    try {
      await TiebaService.getInstance().togglePostAgree(this.tid, this.detail?.postId ?? '', next);
      TiebaService.getInstance().invalidateThreadDetailCache(this.threadDetailCacheKey());
      await this.persistPersonalState(CACHE_KEY.PERSONAL_LIKED, next);
    } catch (e) {
      this.liked = previous;
      // Revert count on failure
      if (this.detail) {
        const d = this.detail;
        const currentCount = d.likeCount ?? 0;
        this.detail = {
          tid: d.tid, postId: d.postId, forumId: d.forumId,
          forumAvatar: d.forumAvatar, title: d.title, forumName: d.forumName,
          author: d.author, authorAvatar: d.authorAvatar, authorId: d.authorId,
          content: d.content, contentText: d.contentText,
          images: d.images, replyNum: d.replyNum,
          likeCount: currentCount + (next ? -1 : 1),
          isLiked: previous,
          isCollected: d.isCollected,
          createTime: d.createTime, page: d.page, totalPage: d.totalPage,
        };
      }
      this.getUIContext().getPromptAction().showToast({ message: '点赞失败，已恢复原状态' });
    }
  }

  /**
   * 楼层点赞/取消点赞
   */
  private async toggleFloorLike(floor: FloorItem): Promise<void> {
    if (this.likeInFlight) {
      return;
    }
    this.likeInFlight = true;
    try {
      await this.doToggleFloorLike(floor);
    } finally {
      this.likeInFlight = false;
    }
  }

  private async doToggleFloorLike(floor: FloorItem): Promise<void> {
    const previous: boolean = floor.isLiked ?? false;
    const next: boolean = !previous;
    const floorId = floor.floorId;

    // 乐观更新
    const nextFloors: FloorItem[] = this.floors.map((f: FloorItem): FloorItem => {
      if (f.floorId === floorId) {
        const currentCount = f.likeCount ?? 0;
        return {
          floorId: f.floorId, floor: f.floor, author: f.author,
          authorAvatar: f.authorAvatar, authorId: f.authorId,
          contentText: f.contentText, images: f.images,
          fragments: f.fragments,
          createTime: f.createTime, isAuthor: f.isAuthor,
          comments: f.comments, commentsTotal: f.commentsTotal,
          commentsHasMore: f.commentsHasMore,
          likeCount: currentCount + (next ? 1 : -1),
          isLiked: next,
          level: f.level, ipLocation: f.ipLocation,
        };
      }
      return f;
    });
    this.floors = nextFloors;
    this.updateFloorDataSourceItem(floorId, nextFloors);

    try {
      await TiebaService.getInstance().togglePostAgree(this.tid, floorId, next, 1);
      TiebaService.getInstance().invalidateThreadDetailCache(this.threadDetailCacheKey());
    } catch (e) {
      // 回滚
      const rollbackFloors: FloorItem[] = this.floors.map((f: FloorItem): FloorItem => {
        if (f.floorId === floorId) {
          const currentCount = f.likeCount ?? 0;
          return {
            floorId: f.floorId, floor: f.floor, author: f.author,
            authorAvatar: f.authorAvatar, authorId: f.authorId,
            contentText: f.contentText, images: f.images,
            fragments: f.fragments,
            createTime: f.createTime, isAuthor: f.isAuthor,
            comments: f.comments, commentsTotal: f.commentsTotal,
            commentsHasMore: f.commentsHasMore,
            likeCount: currentCount + (next ? -1 : 1),
            isLiked: previous,
            level: f.level, ipLocation: f.ipLocation,
          };
        }
        return f;
      });
      this.floors = rollbackFloors;
      this.updateFloorDataSourceItem(floorId, rollbackFloors);
      const msg = (e as Error).message ?? '操作失败';
      this.getUIContext().getPromptAction().showToast({ message: msg });
    }
  }

  /**
   * 楼中楼（楼层内嵌预览）点赞/取消点赞
   */
  private async toggleCommentLike(parentFloorId: string, comment: CommentItem): Promise<void> {
    if (this.likeInFlight) {
      return;
    }
    this.likeInFlight = true;
    try {
      await this.doToggleCommentLike(parentFloorId, comment);
    } finally {
      this.likeInFlight = false;
    }
  }

  private async doToggleCommentLike(parentFloorId: string, comment: CommentItem): Promise<void> {
    const previous: boolean = comment.isLiked ?? false;
    const next: boolean = !previous;
    const commentId: string = comment.commentId;
    const floorId: string = parentFloorId;
    // 防御：预览数据若缺失真实 id（commentId 形如 "xxx-comment-y" 的合成值），
    // 该 ID 无法被服务端识别，直接提示并引导进详情页操作
    if (!/^\d+$/.test(commentId)) {
      this.getUIContext().getPromptAction().showToast({ message: '请进入楼中楼详情页点赞' });
      return;
    }

    this.updateCommentLikeState(floorId, commentId, next, next ? 1 : -1);
    try {
      await TiebaService.getInstance().togglePostAgree(this.tid, commentId, next, 2);
    } catch (e) {
      this.updateCommentLikeState(floorId, commentId, previous, next ? -1 : 1);
      const msg = (e as Error).message ?? '操作失败';
      this.getUIContext().getPromptAction().showToast({ message: msg });
    }
  }

  // 更新指定楼层下某条楼中楼的点赞状态（乐观更新/回滚共用）
  private updateCommentLikeState(floorId: string, commentId: string, likedState: boolean, delta: number): void {
    const nextFloors: FloorItem[] = this.floors.map((f: FloorItem): FloorItem => {
      if (f.floorId !== floorId) {
        return f;
      }
      const updatedComments: CommentItem[] = (f.comments ?? []).map((c: CommentItem): CommentItem => {
        if (c.commentId !== commentId) {
          return c;
        }
        return {
          commentId: c.commentId,
          author: c.author,
          authorAvatar: c.authorAvatar,
          authorId: c.authorId,
          parentPostId: c.parentPostId,
          replyToId: c.replyToId,
          content: c.content,
          images: c.images,
          fragments: c.fragments,
          floor: c.floor,
          createTime: c.createTime,
          isAuthor: c.isAuthor,
          level: c.level,
          isLiked: likedState,
          likeCount: (c.likeCount ?? 0) + delta,
        };
      });
      return {
        floorId: f.floorId, floor: f.floor, author: f.author,
        authorAvatar: f.authorAvatar, authorId: f.authorId,
        contentText: f.contentText, images: f.images,
        fragments: f.fragments,
        createTime: f.createTime, isAuthor: f.isAuthor,
        comments: updatedComments, commentsTotal: f.commentsTotal,
        commentsHasMore: f.commentsHasMore,
        likeCount: f.likeCount, isLiked: f.isLiked,
        level: f.level, ipLocation: f.ipLocation,
      };
    });
    this.floors = nextFloors;
    this.updateFloorDataSourceItem(floorId, nextFloors);
  }

  // 同步楼层数据源（冗余，无 UI 监听）：点赞状态变化后 @State floors 已驱动 ForEach 整楼重绘
  private updateFloorDataSourceItem(floorId: string, items: FloorItem[]): void {
    const idx: number = items.findIndex((f: FloorItem): boolean => f.floorId === floorId);
    if (idx >= 0) {
      this.floorDataSource.updateItem(idx, items[idx]);
    }
  }

  /**
   * 楼中楼预览点赞补齐。
   * pb/page 详情接口返回的楼中楼预览（sub_post）只有内容、不含点赞字段，
   * 因此 ThreadDetail 楼中楼预览点赞数恒为 0。这里对"含楼中楼"的楼层逐个调用
   * pb/floor 接口（与 SubPostDetail 同源，含真实点赞数/已赞状态），按 commentId
   * 将点赞信息合并回预览条目，使预览与楼中楼详情页数据一致。
   * 全程后台静默：失败忽略、串行 + 间隔请求，不打断用户浏览。
   */
  /**
   * §Z4a（2026-09-19）：首屏缺赞补齐的延后调度。
   * 原来紧跟 fadeInContent 立刻开跑，与首屏渲染 / 下一页预取同抢连接池；延后 400ms 起跑，
   * 预览点赞是次要信息，晚几百毫秒无感。
   * 延后窗口内 loadMore 若已用即时补齐拿走 enrichingSubPostLikes 锁（行为与改造前一致，未改），
   * 本次回调不放弃而是按重试间隔轮询：subPostLikesFetched 让每层只补一次，
   * 故轮询只会挑出「尚未补齐」的楼层（含被抢先的首页楼层），不会重复请求、也不会永久停在 0。
   */
  /** §Z4a：清理延后补齐调度器（重排前 + 退页时调用） */
  private clearEnrichTimer(): void {
    if (this.enrichTimer !== -1) {
      clearTimeout(this.enrichTimer);
      this.enrichTimer = -1;
    }
  }

  private scheduleSubPostPreviewEnrich(delayMs: number = SUBPOST_ENRICH_DELAY_MS): void {
    if (this.enrichTimer !== -1) {
      return;
    }
    this.enrichTimer = setTimeout((): void => {
      this.enrichTimer = -1;
      if (this.enrichingSubPostLikes) {
        this.scheduleSubPostPreviewEnrich(SUBPOST_ENRICH_RETRY_MS);
        return;
      }
      this.enrichSubPostPreviewLikes(this.floors);
    }, delayMs);
  }

  private enrichSubPostPreviewLikes(floors: FloorItem[]): void {
    if (this.enrichingSubPostLikes) {
      return;
    }
    const targets: FloorItem[] = (floors ?? []).filter((f: FloorItem): boolean =>
      /^\d+$/.test(f.floorId) && (f.comments ?? []).length > 0 && !this.subPostLikesFetched.has(f.floorId))
      .slice(0, 12); // 每批最多补 12 个含楼中楼的楼层（用户可见区），避免请求过多触发风控
    if (targets.length === 0) {
      return;
    }
    this.enrichingSubPostLikes = true;
    targets.forEach((f: FloorItem): void => { this.subPostLikesFetched.add(f.floorId); });
    const runNext = (idx: number): void => {
      if (idx >= targets.length) {
        this.enrichingSubPostLikes = false;
        return;
      }
      const floor: FloorItem = targets[idx];
      TiebaService.getInstance().fetchSubPostDetail(this.tid, floor.floorId, this.forumId, floor.floor)
        .then((res: SubPostDetail): void => { this.mergeSubPostLikeCounts(floor.floorId, res.comments); })
        .catch(() => { /* 单楼层补齐失败静默，预览保持原值 */ })
        .finally((): void => {
          setTimeout((): void => { runNext(idx + 1); }, 120);
        });
    };
    runNext(0);
  }

  // 将 pb/floor 返回的完整楼中楼数据中的点赞信息，按 commentId 合并回预览条目（不改变预览条数/顺序）
  private mergeSubPostLikeCounts(floorId: string, fetched: CommentItem[]): void {
    if (!fetched || fetched.length === 0) {
      return;
    }
    const likeById: Map<string, CommentItem> = new Map<string, CommentItem>();
    fetched.forEach((fc: CommentItem): void => {
      if (fc.commentId.length > 0) {
        likeById.set(fc.commentId, fc);
      }
    });
    let changed: boolean = false;
    const nextFloors: FloorItem[] = this.floors.map((f: FloorItem): FloorItem => {
      if (f.floorId !== floorId) {
        return f;
      }
      const comments: CommentItem[] = (f.comments ?? []).map((c: CommentItem): CommentItem => {
        const fc: CommentItem | undefined = likeById.get(c.commentId);
        if (!fc) {
          return c;
        }
        const likeCount: number = Number(fc.likeCount ?? 0);
        const isLiked: boolean = fc.isLiked === true;
        if ((c.likeCount ?? 0) === likeCount && (c.isLiked ?? false) === isLiked) {
          return c;
        }
        changed = true;
        return {
          commentId: c.commentId,
          author: c.author,
          authorAvatar: c.authorAvatar,
          authorId: c.authorId,
          parentPostId: c.parentPostId,
          replyToId: c.replyToId,
          content: c.content,
          images: c.images,
          fragments: c.fragments,
          floor: c.floor,
          createTime: c.createTime,
          isAuthor: c.isAuthor,
          level: c.level,
          isLiked: isLiked,
          likeCount: likeCount,
        };
      });
      return {
        floorId: f.floorId, floor: f.floor, author: f.author,
        authorAvatar: f.authorAvatar, authorId: f.authorId,
        contentText: f.contentText, images: f.images,
        fragments: f.fragments,
        createTime: f.createTime, isAuthor: f.isAuthor,
        comments: comments, commentsTotal: f.commentsTotal,
        commentsHasMore: f.commentsHasMore,
        likeCount: f.likeCount, isLiked: f.isLiked,
        level: f.level, ipLocation: f.ipLocation,
      };
    });
    if (!changed) {
      return;
    }
    this.floors = nextFloors;
    this.updateFloorDataSourceItem(floorId, nextFloors);
  }

  /**
   * 格式化楼层时间显示
   */
  private formatFloorTime(time: string): string {
    if (!time || time.length === 0) return '';
    // 如果已经是 MM-DD HH:mm 格式就直接返回
    if (/^\d{1,2}-\d{1,2}\s+\d{1,2}:\d{2}$/.test(time)) return time;
    // 如果是 YYYY-MM-DD HH:mm:ss 格式，截取 MM-DD HH:mm
    const match = time.match(/(\d{1,2}-\d{1,2})[ T](\d{1,2}:\d{2})/);
    if (match) return `${match[1]} ${match[2]}`;
    // 否则返回原始时间
    return time;
  }

  private async persistPersonalState(key: string, enabled: boolean): Promise<void> {
    if (this.detail === null) return;
    const accountId: string = AuthManager.getInstance().getUser()?.userId ?? '';
    if (accountId.length === 0) return;
    const cacheKey: string = `${key}_${accountId}`;
    const item: PersonalContentItem = {
      id: this.detail.tid, tid: this.detail.tid, title: this.detail.title,
      forumName: this.detail.forumName, author: this.detail.author,
      abstract: this.detail.contentText, replyNum: this.detail.replyNum,
      createTime: this.detail.createTime, accountId
    };
    const raw = await CacheManager.getInstance().get(cacheKey);
    const current: PersonalContentItem[] = raw ? JSON.parse(raw) as PersonalContentItem[] : [];
    const next: PersonalContentItem[] = current.filter((entry: PersonalContentItem): boolean => entry.tid !== item.tid);
    if (enabled) next.unshift(item);
    // v1.18 不再 slice(0,100) 截断：该缓存承载收藏页全量收藏（秒开/计数/排序数据源），截断会造成未分类数量缺失、分类内帖子丢失
    await CacheManager.getInstance().put(cacheKey, JSON.stringify(next));
    if (key === CACHE_KEY.PERSONAL_COLLECTED) {
      const userId: string = accountId;
      try {
        const tbs: string = await TiebaService.getInstance().getOperationTbs();
        if (enabled) {
          await TiebaService.getInstance().addThreadCollection(item.tid, this.forumId, userId, tbs,
            this.detail?.postId ?? '');
          // v1.11：收藏成功记录本地收藏时间（threadstore 无 collect_time，「添加时间」排序数据源）
          await FavoriteStore.getInstance().recordCollectTime(accountId, item.tid);
        } else {
          await TiebaService.getInstance().removeThreadCollection(item.tid, this.forumId, userId, tbs);
          await FavoriteStore.getInstance().removeCollectTime(accountId, item.tid);
        }
      } catch (e) {
        const errMsg: string = (e as Error).message ?? '未知错误';
        console.error(`[收藏] 云端同步失败: enabled=${enabled}, tid=${item.tid}, fid=${this.forumId}, userId=${userId}, error=${errMsg}`);
        this.getUIContext().getPromptAction().showToast({ message: `${enabled ? '已记录收藏' : '已取消收藏'}，云端同步失败: ${errMsg}` });
      }
    }
  }

  // v68: 详情接口未解析 isCollected，改用本地收藏缓存判断收藏状态
  private async isCollectedLocally(tid: string): Promise<boolean> {
    const accountId: string = AuthManager.getInstance().getUser()?.userId ?? '';
    if (accountId.length === 0) {
      return false;
    }
    try {
      const raw = await CacheManager.getInstance().get(`${CACHE_KEY.PERSONAL_COLLECTED}_${accountId}`);
      if (!raw || raw.length === 0) {
        return false;
      }
      const list = JSON.parse(raw) as PersonalContentItem[];
      return list.some((entry: PersonalContentItem): boolean => entry.tid === tid);
    } catch (e) {
      return false;
    }
  }

  // ===== 长按收藏钮 → 收藏并归类（共用面板 FavCategoryPicker，方案 A：关闭零副作用）=====

  /**
   * 长按收藏钮打开分类面板：面板内只勾选 / 新建分类，**不落库**。
   * 打开时按账号现读分类与映射；默认勾选口径：
   *  · 帖子已在某（些）自定义分类 → 勾其现有分类（否则「完成」的替换式写入会把已有归类抹掉）；
   *  · 其余情况（未收藏 / 已在未分类）→ 勾「未分类」。
   */
  private async openCategoryPicker(): Promise<void> {
    const accountId: string = AuthManager.getInstance().getUser()?.userId ?? '';
    if (accountId.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '请先登录后再收藏归类' });
      return;
    }
    if (this.detail === null) {
      return;
    }
    const store = FavoriteStore.getInstance();
    this.pickerAccountId = accountId;
    this.pickerCategories = await store.loadCategories(accountId);
    this.pickerMappings = await store.loadMappings(accountId);
    this.pickerTargets = [this.tid];
    const owned: string[] = this.pickerMappings
      .filter((m: CategoryMapping): boolean => m.tid === this.tid && m.categoryId !== CATEGORY_DEFAULT_ID)
      .map((m: CategoryMapping): string => m.categoryId);
    this.pickerChecked = owned.length > 0 ? owned : [CATEGORY_DEFAULT_ID];
    // 每次打开都回收起态：上次遗留的输入行不出现（组件内草稿由 beginCreate 自行清空）
    this.pickerCreating = false;
    this.pickerShow = true;
    Haptic.light();
  }

  /**
   * 面板「完成」：先补收藏（未收藏时），再按勾选替换式归类 —— 两步都只在这里发生，
   * 下滑 / 点遮罩关闭面板不经过本方法，故天然零副作用。
   * 只勾「未分类」= 移出全部自定义分类（与收藏页移入面板同语义）。
   */
  private async applyPickCategory(checked: string[]): Promise<void> {
    const accountId: string = this.pickerAccountId;
    const detail = this.detail;
    if (accountId.length === 0 || detail === null) {
      this.pickerShow = false;
      return;
    }
    const wasCollected: boolean = this.collected;
    if (!wasCollected) {
      // 先按短按收藏的同一条链路落库（本地缓存 + 云端 + 收藏时间），保证两种入口状态一致
      this.collected = true;
      await this.persistPersonalState(CACHE_KEY.PERSONAL_COLLECTED, true);
    }
    const targets: string[] = checked.filter((id: string): boolean => id !== CATEGORY_DEFAULT_ID);
    await FavoriteStore.getInstance().setThreadCategories(accountId, this.tid, detail.forumName, targets);
    // 广播分类/映射变更：收藏页是常驻组件（切 Tab 不重建、onPageShow 不回调），除非它自己打开面板（@Link 回写），
    // 否则这里落库的结果不会回流 —— 面板内新建的分类、本次归类都要靠这条广播才能即时显示（2026-09-17）
    AppStorage.setOrCreate<number>('favCatChanged', (AppStorage.get<number>('favCatChanged') ?? 0) + 1);
    this.pickerShow = false;
    Haptic.light();
    const names: string[] = targets
      .map((id: string): string => this.pickerCategories.find((c: FavCategory): boolean => c.id === id)?.name ?? '')
      .filter((n: string): boolean => n.length > 0);
    const label: string = names.length > 0 ? `「${names.join('、')}」` : '未分类';
    this.getUIContext().getPromptAction().showToast({
      message: wasCollected ? `已归类到${label}` : `已收藏并归类到${label}`
    });
  }

  private openForumHome(): void {
    const name = (this.detail?.forumName ?? this.forumName).trim();
    const fid = (this.detail?.forumId ?? this.forumId ?? '').trim();
    if (name.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '贴吧信息暂不可用' });
      return;
    }
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/ThreadList',
      params: { kw: name, forumName: name, fid: fid }
    }).catch(() => {
      this.getUIContext().getPromptAction().showToast({ message: '贴吧主页打开失败，请稍后重试' });
    });
  }

  private goBack(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({ message: '返回失败，请稍后重试' });
    }
  }

  /** 详情页分享 payload：从当前详情/入参汇总分享所需字段（与首页 ThreadCard 同构） */
  private buildSharePayload(): ThreadSharePayload {
    const d = this.detail;
    const forum = d ? (d.forumName.length > 0 ? d.forumName : this.forumName) : this.forumName;
    return {
      tid: d ? d.tid : this.tid,
      title: d ? d.title : '贴吧帖子',
      forumName: forum,
      author: d ? d.author : '',
      abstract: d ? d.contentText : '',
      firstImage: ''
    };
  }

  /**
   * 详情页分享：与首页同一机制 —— 鸿蒙官方 Share Kit 系统分享面板。
   * 主路径：@kit.ShareKit → systemShare.SharedData(general.link) + ShareController.show()
   * 兜底：ShareKit 不可用/拉起失败自动降级写入系统剪贴板，提示用户手动粘贴
   * 排障：最外层 try/catch 捕获所有异常→Toast 显式反馈，避免"点了没反应"
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
      // 取 UIAbilityContext（hostContext 强转，与页内打开链接/官方贴吧同款写法）
      let abilityCtx: common.UIAbilityContext | null = null;
      try {
        const hostCtx = this.getUIContext().getHostContext();
        abilityCtx = hostCtx as common.UIAbilityContext;
      } catch (ctxErr) {
        abilityCtx = null;
      }
      if (!abilityCtx) {
        // Context 拿不到：直接兜底剪贴板
        this.getUIContext().getPromptAction().showToast({ message: '系统分享不可用，正在复制链接' });
        this.copyShareToClipboard(fullText, titleLine, threadUrl);
        return;
      }

      // ========== 主路径：Share Kit 系统分享面板 ==========
      try {
        // ★ 纯链接分享：utd.UniformDataType.HYPERLINK + content 字段（图片才用 uri + fileUri）
        const sharedData: systemShare.SharedData = new systemShare.SharedData({
          utd: utd.UniformDataType.HYPERLINK,
          content: threadUrl,
          title: titleLine,
          description: descriptionText
        });
        const controller: systemShare.ShareController = new systemShare.ShareController(sharedData);
        // ★ controller.show() 返回 Promise，必须单独 .catch() 才能捕获异步错误
        controller.show(abilityCtx, {
          previewMode: systemShare.SharePreviewMode.DETAIL,
          selectionMode: systemShare.SelectionMode.SINGLE
        }).then(() => {
          // Promise.resolve = 系统分享面板已成功拉起（用户可能取消/成功，都算面板弹了）
          this.getUIContext().getPromptAction().showToast({ message: '系统分享面板已弹出' });
        }).catch((showErr: BusinessError) => {
          // Promise 异步 reject：面板拉起失败（权限/UTD 不支持/其他），code+msg 全量 Toast 便于定位
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
      // 全局兜底：任何异常都弹 Toast，避免用户感觉点了没反应
      const errMsg: string = outerErr instanceof Error ? outerErr.message : String(outerErr);
      this.getUIContext().getPromptAction().showToast({ message: `分享异常：${errMsg}` });
    }
  }

  /** 分享兜底：写入系统剪贴板（pasteboard @kit.BasicServicesKit），失败亦有 Toast 反馈 */
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

  @Builder
  PostHeader() {
    Column({ space: Spacing.md }) {
      Row({ space: Spacing.sm }) {
        this.Avatar(this.detail!.authorAvatar ?? '', this.detail!.author, 38, this.detail!.authorId ?? '')
        Column({ space: 2 }) {
          Row({ space: 6 }) {
            Text(this.detail!.author || '贴吧用户')
              .fontSize(fs(14, this.fontScale))
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.textPrimary(this.isDark))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .onClick(() => {
                this.openUserProfile(this.detail!.authorId ?? '', this.detail!.author);
              })
            if ((this.detail?.level ?? 0) > 0) {
              Text(`${this.detail!.level}`)
                .fontSize(fs(10, this.fontScale))
                .fontColor(Color.White)
                .fontWeight(FontWeight.Bold)
                .backgroundColor(Theme.levelColor(this.detail!.level ?? 0))
                .borderRadius(Radius.sm)
                .padding({ left: 5, right: 5, top: 1, bottom: 1 })
            }
          }
          Row({ space: 6 }) {
            Text('楼主')
              .fontSize(fs(11, this.fontScale))
              .fontColor(Theme.brand())
            if ((this.detail?.createTime ?? '').length > 0) {
              Text(`· ${this.formatFloorTime(this.detail!.createTime)}`)
                .fontSize(fs(11, this.fontScale))
                .fontColor(Theme.textSecondary(this.isDark))
            }
          }
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      // 帖子标题同样支持长按选中复制（无 onClick 无手势冲突，独立可选区域）；
      // 纪元重建清选中（复制成功 → toast + title 纪元自增 → 节点重建）
      ForEach([this.copyEpochOf('title')], (titleCopyEpoch: number) => {
        Text(this.detail!.title)
          .fontSize(fs(20, this.fontScale))
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.textPrimary(this.isDark))
          .copyOption(CopyOptions.LocalDevice)
          .draggable(false)
          .width('100%')
          .onCopy(() => { this.onTextCopied('title'); })
      }, (titleCopyEpoch: number) => `title_${titleCopyEpoch}`)

      this.RichTextContent(this.detail!.fragments ?? [], this.detail!.contentText || '（楼主未提供正文）', fs(17), Theme.textPrimary(this.isDark), 28, 'main')

      if (this.detail!.images.length > 0) {
        // 通栏主楼：capMaxWidth=true（336 封顶防拉伸）
        this.ImageGrid(this.detail!.images, true, false)
      }

    }
    .width('100%')
    .padding(Spacing.lg)
    .backgroundColor(Theme.bgCard(this.isDark))
    // 卡片圆角 26：比全局 Radius.lg（=16）更圆、比 32 收敛（32 观感过大，真机反馈收一档）。
    // 不走全局令牌（改 Radius.lg 会波及全工程），此处按详情页卡片单独写死。
    .borderRadius(26)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ReplySectionHeader() {
    Row({ space: Spacing.sm }) {
      Text('回复')
        .fontSize(fs(16, this.fontScale))
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.textPrimary(this.isDark))
      Text(`${this.detail?.replyNum ?? 0} 条`)
        .fontSize(fs(12, this.fontScale))
        .fontColor(Theme.textTertiary(this.isDark))
    }
    .width('100%')
    .padding({ left: 4, right: 4, top: 2, bottom: 2 })
  }

  /**
   * 幽灵回复表头（横屏分栏·左栏专用，2026-09-13）：与 `ReplySectionHeader` **同几何**的透明占位行
   * —— 右栏第一排卡片上方有「回复 N 条」表头 + space 12，左栏主楼卡顶需与之对齐。
   * 结构 / 字号 / padding 与真表头逐项一致（字号缩放自动同步），仅文字为空格 → 撑高等高、不显示。
   */
  @Builder
  ReplyHeaderGhost() {
    Row({ space: Spacing.sm }) {
      Text(' ')
        .fontSize(fs(16, this.fontScale))
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .padding({ left: 4, right: 4, top: 2, bottom: 2 })
    }
    .width('100%')
  }

  // ===== 平板适配 §4.9（2026-09-13 错位修复二：弃 WaterFlow+sections，改列内独立堆叠）=====

  /**
   * 楼层区（多列 / 单列统一入口）：
   * - 多列档：三列「列内独立堆叠」Row（`i % 3` 交替分桶）—— 瀑布流的观感本质（无行内对齐留白），
   *   但不依赖 `WaterFlowSections`（真机两轮复现段计数与 ForEach 展开的竞态：FlowItem 内容按全宽
   *   测量却被按三列摆放 → 卡片重叠 / 内容跨列溢出，无法可靠修复，故弃用）。
   * - 单列档（手机 / 窄窗）：原 `ForEach` 逐像素回归。
   * `.id('floor_' + floorId)` 与高亮底必须**随卡进列** —— 楼层定位靠它取几何（列内 `width('100%')`
   * 引用列宽，约束链完整，不存在 WaterFlow 段排放的宽度歧义）。
   */
  @Builder
  FloorColumnsBlock() {
    if (this.replyColumns() > 1) {
      Row({ space: Spacing.md }) {
        ForEach(this.floorColumnsData(), (col: FloorItem[], colIdx: number) => {
          Column({ space: Spacing.md }) {
            ForEach(col, (floor: FloorItem) => {
              this.FloorCardItem(floor)
            }, (floor: FloorItem) => `${floor.floorId}_${floor.floor}`)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }, (col: FloorItem[], colIdx: number) => `col_${colIdx}_${col.length}_${col[0]?.floorId ?? 'e'}`)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    } else {
      // 单列档：卡片间距收紧到 Spacing.sm(8)。外层通栏 Column 的 space=md(12) 本是给主楼 / 表头 /
      // 哨兵之间用的，单列时 ForEach 直接展开会被它一并套用 → 楼层卡之间偏松（2026-09-18 真机反馈）。
      // 此处独立容器给 sm，只影响单列卡间距；表头 / 哨兵与外层的间距（12）不变，多列档列内间距（md）不变。
      Column({ space: Spacing.sm }) {
        ForEach(this.floors, (floor: FloorItem) => {
          this.FloorCardItem(floor)
        }, (floor: FloorItem) => `${floor.floorId}_${floor.floor}`)
      }
      .width('100%')
    }
  }

  /**
   * 楼层分桶（方案 B「带滞回的最短列」，2026-09-14）：默认按 `i % 列数` 轮转（保序观感），
   * 仅当轮转目标列与最短列的估算高差 > `DETAIL_COL_BALANCE_THRESHOLD`（≈一张短卡高）时
   * 改投最短列补位 —— 连续一列短卡 / 一列长卡时列尾差被钳回一卡以内，且穿插次数最少。
   * 高度为**确定性估算**（正文行数 + 图片宫格行 + 楼中楼条 + 固定件），同步可算、无测量循环；
   * 分桶是前缀稳定贪心：翻页追加时从头重算，旧卡落列不变（不跳位），定位 / 高亮 id 随卡走零改动。
   */
  private floorColumnsData(): FloorItem[][] {
    const cols: number = this.replyColumns();
    const buckets: FloorItem[][] = [];
    const heights: number[] = [];
    for (let c = 0; c < cols; c++) {
      buckets.push([]);
      heights.push(0);
    }
    // 列宽（估算正文换行用）：屏宽 − 横向 padding(lg×2) − 列间 gap(md×(cols−1))
    const colWidth: number = (this.currentWidth - Spacing.lg * 2 - Spacing.md * (cols - 1)) / cols;
    for (let i = 0; i < this.floors.length; i++) {
      let target: number = i % cols;
      let shortest: number = 0;
      for (let c = 1; c < cols; c++) {
        if (heights[c] < heights[shortest]) {
          shortest = c;
        }
      }
      if (heights[target] - heights[shortest] > DETAIL_COL_BALANCE_THRESHOLD) {
        target = shortest;
      }
      buckets[target].push(this.floors[i]);
      heights[target] += this.estimateFloorCardHeight(this.floors[i], colWidth) + Spacing.md;
    }
    return buckets;
  }

  /**
   * 楼层卡估算高（vp，仅供列均衡分桶，不求像素准只求相对准）：
   * 头部 / 底部 / 卡内留白取常数 128；正文 = 行数 × 26（行高）+ 8（每行字数 ≈ 列宽 / 16 字号）；
   * 图片宫格 = 显式总高（行 × 格高〔gridCellHeight()〕+ 间隙，与渲染同式）；楼中楼预览条 40。
   * 各卡共享同一底数，常数误差在「列高差」里互相抵消。
   */
  private estimateFloorCardHeight(floor: FloorItem, colWidth: number): number {
    let h: number = 128;
    const text: string = floor.contentText ?? '';
    if (text.length > 0) {
      const charsPerLine: number = Math.max(8, Math.floor(colWidth / 16));
      h += Math.min(Math.ceil(text.length / charsPerLine), 20) * 26 + 8;
    }
    const imgRows: number = Math.ceil((floor.images ?? []).length / 3);
    if (imgRows > 0) {
      h += imgRows * this.gridCellHeight() + (imgRows - 1) * 6 + 12;
    }
    if ((floor.comments ?? []).length > 0 || (floor.commentsTotal ?? 0) > 0) {
      // 楼中楼区估算高度：链接态 40→22、无链接态 40→22（容器 bottom 0 + 末条评论 bottom 0），同步校准跳楼定位预估
      h += 22;
    }
    return h;
  }

  /** 单张楼层卡（含定位锚点 id 与高亮底，竖屏 / 横屏 / 单列 / 多列共用同一份包装） */
  @Builder
  FloorCardItem(floor: FloorItem) {
    Column() {
      this.FloorCard(floor)
    }
    .id('floor_' + floor.floorId)
    .width('100%')
    .backgroundColor(this.highlightFloorId === floor.floorId ? (this.isDark ? '#1A3173FF' : '#1A3173FF') : Color.Transparent)
    // 高亮底色层：圆角必须与楼层卡（26）一致，否则高亮时外角会露出直角/小圆角
    .borderRadius(this.highlightFloorId === floor.floorId ? 26 : 0)
    .clip(true)
  }

  /**
   * 触底哨兵（通栏普通节点）：四态条件渲染（2026-09-19 无感翻页改造）。
   * 已回归 Scroll + Column 结构，无 WaterFlow 段计数约束，可自由条件渲染。
   *
   * 折中口径：后台预取路径（滚动预取）**先静默** —— 不转圈、不显字，只保留固定高度占位，
   * 超过 DETAIL_LOAD_HINT_DELAY 仍未返回才浮出 loading；用户显式路径（触底 / 点重试）立即浮出。
   * 三态统一 DETAIL_FOOTER_SENTINEL_H 等高：内容追加时视口不发生位移，滚动不抽搐。
   */
  @Builder
  FooterSentinel() {
    Column() {
      if (this.hasMoreFloors) {
          Column() {
            if (this.loadingHintVisible) {
              Row({ space: 8 }) {
                LoadingProgress()
                  .width(20)
                  .height(20)
                  .color(Theme.textSecondary(this.isDark))
                Text('正在加载更多回复...')
                  .fontSize(fs(13, this.fontScale))
                  .fontColor(Theme.textSecondary(this.isDark))
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
            } else if (this.loadMoreFailed) {
              Button('加载失败，点击重试')
                .fontSize(fs(13, this.fontScale))
                .fontColor(Theme.brand())
                .backgroundColor(Color.Transparent)
                .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                .onClick(() => { this.loadMoreFloors(); })
            }
            // 静默态（后台预取在途且未超时）：不显形、不转圈，仅留等高占位
          }
          .width('100%')
          .height(DETAIL_FOOTER_SENTINEL_H)
          .justifyContent(FlexAlign.Center)
        } else if (this.floors.length > 0) {
          // 与加载态统一等高：最后一批追加完成时哨兵高度不变，视口零位移
          Text('— 已经到底啦 —')
            .fontSize(fs(12, this.fontScale))
            .fontColor(Theme.textTertiary(this.isDark))
            .width('100%')
            .height(DETAIL_FOOTER_SENTINEL_H)
            .textAlign(TextAlign.Center)
        }
      }
      .width('100%')
  }

  // 单个楼层卡片：楼层头部 + 正文 + 图片九宫格 + 楼中楼预览
  // ForEach key = floorId_floor，稳定复用节点；楼层数据变化由 @State floors 驱动整楼重绘。
  @Builder
  FloorCard(floor: FloorItem) {
    Column({ space: Spacing.sm }) {
      // 楼层头部
      Row({ space: Spacing.sm }) {
        this.Avatar(floor.authorAvatar ?? '', floor.author, 36, floor.authorId ?? '')
        Column({ space: 4 }) {
          Row({ space: 6 }) {
            Text(floor.author || '贴吧用户')
              .fontSize(fs(14, this.fontScale))
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.textPrimary(this.isDark))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .onClick(() => {
                this.openUserProfile(floor.authorId ?? '', floor.author);
              })
            // 等级徽章
            if (floor.level !== undefined) {
              Text(`${floor.level}`)
                .fontSize(fs(10, this.fontScale))
                .fontColor(Color.White)
                .fontWeight(FontWeight.Bold)
                .backgroundColor(Theme.levelColor(floor.level ?? 0))
                .borderRadius(Radius.sm)
                .padding({ left: 5, right: 5, top: 1, bottom: 1 })
            }
            // 楼主标签
            if (floor.isAuthor) {
              Text('楼主')
                .fontSize(fs(10, this.fontScale))
                .fontColor(Color.White)
                .backgroundColor(Theme.brand())
                .borderRadius(Radius.sm)
                .padding({ left: 6, right: 6, top: 1, bottom: 1 })
            }
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
          // 时间 · 楼层 · IP —— 左对齐与用户名对齐
          Row({ space: 0 }) {
            Text(this.formatFloorTime(floor.createTime))
              .fontSize(fs(11, this.fontScale))
              .fontColor(Theme.textSecondary(this.isDark))
            if (floor.floor > 0) {
              Text(` · 第${floor.floor}楼`)
                .fontSize(fs(11, this.fontScale))
                .fontColor(Theme.textSecondary(this.isDark))
            }
            if (floor.ipLocation && floor.ipLocation.length > 0) {
              Text(` · 来自${floor.ipLocation}`)
                .fontSize(fs(11, this.fontScale))
                .fontColor(Theme.textTertiary(this.isDark))
            }
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
        }
        .layoutWeight(1)
        Blank()
        // 楼层点赞按钮 — 使用 Button 组件确保点击可靠
        Button({ type: ButtonType.Circle }) {
          Row({ space: 3 }) {
            SymbolGlyph($r('sys.symbol.heart'))
              .fontSize(fs(18, this.fontScale))
              .fontColor([(floor.isLiked ?? false) ? $r('sys.color.icon_emphasize') : $r('sys.color.icon_secondary')])
              .renderingStrategy(SymbolRenderingStrategy.SINGLE)
              .hitTestBehavior(HitTestMode.None)
            Text(`${floor.likeCount ?? 0}`)
              .fontSize(fs(12, this.fontScale))
              .fontWeight(FontWeight.Medium)
              .fontColor((floor.isLiked ?? false) ? $r('sys.color.icon_emphasize') : $r('sys.color.font_secondary'))
              .hitTestBehavior(HitTestMode.None)
          }
          .hitTestBehavior(HitTestMode.None)
        }
        .width(56)
        .height(36)
        .backgroundColor(Color.Transparent)
        .onClick(() => { this.toggleFloorLike(floor); })
      }
      .width('100%')
      .hitTestBehavior(HitTestMode.Transparent)

      // 正文
      this.RichTextContent(floor.fragments ?? [], floor.contentText, fs(16), Theme.textPrimary(this.isDark), 26, `floor_${floor.floorId}`)

      if (floor.images.length > 0) {
        // 列内楼层卡：capMaxWidth=true（2026-09-16 拍板「宫格图片不要拉伸」——平板 2 列后列宽 ≈494 > 336，
        // 跟随列宽会把宫格拉宽、格宽 164 vs 格高 120 横向拉伸；封顶 336 后格宽 108/格高 120 ≈ 手机档比例。
        // 3 列 / 单列档列宽 ≤ 336 封顶不生效逐像素不变；楼层卡根 Column 已 alignItems Start → 限宽后靠左）
        this.ImageGrid(floor.images, true, false)
      }
      if ((floor.comments ?? []).length > 0 || (floor.commentsTotal ?? 0) > 0) {
        this.CommentList(floor.comments ?? [], floor.commentsTotal ?? (floor.comments ?? []).length, floor.commentsHasMore === true, floor.floorId, floor.floor)
      }
    }
    .width('100%')
    .padding(Spacing.lg)
    .backgroundColor(Theme.bgCard(this.isDark))
    // 卡片圆角 26：与楼主卡、首页 ThreadCard 统一（不借用全局令牌 Radius.lg）
    .borderRadius(26)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  CommentList(comments: CommentItem[], total: number = comments.length, hasMore: boolean = false, parentPid: string = '', parentFloor: number = 0) {
    Column({ space: 8 }) {
      Text(`${total} 条楼中楼回复`)
        .fontSize(fs(13, this.fontScale))
        .fontColor(Theme.textTertiary(this.isDark))
        // 标题文字水平居中显示
        .width('100%')
        .textAlign(TextAlign.Center)
      ForEach(comments, (comment: CommentItem, commentIndex: number) => {
        Column() {
          Stack({ alignContent: Alignment.TopEnd }) {
            Row({ space: Spacing.sm }) {
              // 头像使用与主楼层一致的 36vp，保证左右绝对对齐
              this.Avatar(comment.authorAvatar ?? '', comment.author, 36, comment.authorId ?? '')
              Column({ space: 4 }) {
                // 作者行：名称 + 等级徽章 + 楼主标签（与主楼层样式完全对齐）
                Row({ space: 6 }) {
                  Text(comment.author || '贴吧用户')
                    .fontSize(fs(14, this.fontScale))
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Theme.textPrimary(this.isDark))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .onClick(() => {
                      this.openUserProfile(comment.authorId ?? '', comment.author);
                    })
                  if ((comment.level ?? 0) > 0) {
                    Text(`${comment.level}`)
                      .fontSize(fs(10, this.fontScale))
                      .fontColor(Color.White)
                      .fontWeight(FontWeight.Bold)
                      .backgroundColor(Theme.levelColor(comment.level ?? 0))
                      .borderRadius(Radius.sm)
                      .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                  }
                  if (comment.isAuthor) {
                    Text('楼主')
                      .fontSize(fs(10, this.fontScale))
                      .fontColor(Color.White)
                      .backgroundColor(Theme.brand())
                      .borderRadius(Radius.sm)
                      .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                  }
                }
                .width('100%')
                .justifyContent(FlexAlign.Start)
                // 时间 · 楼中楼号
                Row({ space: 0 }) {
                  Text(this.formatFloorTime(comment.createTime))
                    .fontSize(fs(11, this.fontScale))
                    .fontColor(Theme.textSecondary(this.isDark))
                  if ((comment.floor ?? 0) > 0) {
                    Text(` · 楼${comment.floor}`)
                      .fontSize(fs(11, this.fontScale))
                      .fontColor(Theme.textSecondary(this.isDark))
                  }
                }
                .width('100%')
                .justifyContent(FlexAlign.Start)
                // 正文（纯图回复去冒号头后无文本片段，整体跳过避免「（无文字内容）」兜底）
                if ((comment.fragments ?? []).length > 0 || (comment.content ?? '').length > 0) {
                  this.RichTextContent(comment.fragments ?? [], comment.content || '（无文字内容）', fs(16), Theme.textPrimary(this.isDark), 26, `cmt_${parentPid}_${comment.commentId}`)
                }
                if ((comment.images ?? []).length > 0) {
                  // 同楼层卡：宫格 336 封顶防平板 2 列列宽拉伸（容器已 alignItems Start）
                  // singlePreview=true：楼中楼图点开单张预览，不进主图流（2026-09-20 预览解耦）
                  this.ImageGrid(comment.images ?? [], true, true)
                }
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
            // 楼中楼点赞按钮：浮在右上角、不占行内宽度，使正文右边缘与主楼层正文右边缘对齐。
            Button({ type: ButtonType.Circle }) {
              Row({ space: 3 }) {
                SymbolGlyph($r('sys.symbol.heart'))
                  .fontSize(fs(18, this.fontScale))
                  .fontColor([(comment.isLiked ?? false) ? $r('sys.color.icon_emphasize') : $r('sys.color.icon_secondary')])
                  .renderingStrategy(SymbolRenderingStrategy.SINGLE)
                  .hitTestBehavior(HitTestMode.None)
                // 始终显示点赞数，即使为 0，与主楼层保持一致
                Text(`${comment.likeCount ?? 0}`)
                  .fontSize(fs(12, this.fontScale))
                  .fontWeight(FontWeight.Medium)
                  .fontColor((comment.isLiked ?? false) ? $r('sys.color.icon_emphasize') : $r('sys.color.font_secondary'))
                  .hitTestBehavior(HitTestMode.None)
              }
              .hitTestBehavior(HitTestMode.None)
            }
            .width(56)
            .height(36)
            .backgroundColor(Color.Transparent)
            .onClick(() => { this.toggleCommentLike(parentPid, comment); })
          }
          .width('100%')
          // 左右 padding 清零，实现内部Row元素与主楼层Row元素左右绝对对齐
          // 无链接卡（total<=3）的最后一条评论 padding-bottom 收 0：卡底留空 = 楼层卡 padding(16)，与顶部一致；
          // 非最后一条或链接卡（total>3，间距由容器 space 8 提供）保持 8 不变
          .padding({ left: 0, right: 0, top: 8, bottom: (total > 3 || (commentIndex ?? 0) < comments.length - 1) ? 8 : 0 })
          // 评论分隔线：非最后一条时显示，左边距=头像36+space8=44vp，与正文左边缘对齐
          if ((commentIndex ?? 0) < comments.length - 1) {
            Divider()
              .vertical(false)
              .strokeWidth(0.5)
              .color(Theme.divider(this.isDark))
              .opacity(0.5)
              .margin({ left: 44, right: 8 })
          }
        }
        .width('100%')
      }, (comment: CommentItem, commentIndex: number) => `${comment.commentId}_${comment.isLiked ? 1 : 0}_${comment.likeCount ?? 0}_${commentIndex ?? 0}`)
      if (total > 3) {
        Row() {
          Blank()
          Button(this.openingSubPost ? '正在打开楼中楼' : '查看更多楼中楼')
            .fontSize(fs(12, this.fontScale))
            .fontColor(Theme.brand())
            .backgroundColor(Color.Transparent)
            .enabled(!this.openingSubPost)
            // 链接下沿到卡底由楼层卡 padding(Spacing.lg) 单层承担，与顶部用户名行上方留空(16)一致
            .padding({ left: 0, right: 0, top: 2, bottom: 0 })
            .onClick(() => { this.openSubPostDetail(parentPid, parentFloor, total); })
          Blank()
        }
        .width('100%')
        // 链接下移 6vp：卡底视觉留空 16→10（translate 不改布局占位，下方无后续内容，安全）
        .translate({ y: 6 })
      }
    }
    .width('100%')
    // 外层左右padding清零，避免挤压内部Row的水平可用宽度导致元素错位
    // 底部 padding 收 0：链接态由楼层卡 padding(16)+链接下移6 承担（视觉 10）；
    // 无链接态由最后一条评论自身 padding-bottom(8)+楼层卡 padding(16) 承担（视觉 24），不再额外叠 10
    .padding({ left: 0, right: 0, top: 10, bottom: 0 })
    // 楼中楼预览容器底色与楼层卡同源（Theme.bgCard）：浅深档都与楼层卡同色，避免深色下出现"框中框"视觉冗余
    .backgroundColor(Theme.bgCard(this.isDark))
    .borderRadius(Radius.md)
  }

  private openSubPostDetail(parentPid: string, parentFloor: number, total: number): void {
    if (this.openingSubPost || parentPid.trim().length === 0 || total <= 3) {
      return;
    }
    const normalizedPid: string = parentPid.trim();
    if (normalizedPid.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '当前楼层信息暂不可用，请稍后重试' });
      return;
    }
    this.openingSubPost = true;
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/SubPostDetail',
      params: {
        tid: this.tid,
        pid: normalizedPid,
        floor: `${parentFloor}`,
        forumId: this.forumId,
        forumName: this.forumName,
        parentAuthor: this.floors.find((floor: FloorItem): boolean => floor.floorId === normalizedPid)?.author ?? ''
      }
    }).then(() => {
      this.openingSubPost = false;
    }).catch(() => {
      this.openingSubPost = false;
      this.getUIContext().getPromptAction().showToast({ message: '楼中楼详情打开失败，请稍后重试' });
    });
  }

  onPageShow(): void {
    this.fontSizeTick++;
    this.openingSubPost = false;
    this.isDark = isDarkMode();
    // 沉浸阅读：返回本页（含从楼中楼返回）复位为「顶栏 / 底栏可见」，且丢弃旧滚动基线
    // （子页返回后滚动位置可能被楼层定位改过，拿旧基线算增量会误藏）
    this.resetImmersive();
  }

  @Builder
  Avatar(url: string, author: string, size: number, authorId: string) {
    Stack() {
      Text((author.trim().length > 0 ? author : '吧').substring(0, 1))
        .width(size)
        .height(size)
        .fontSize(Math.max(11, Math.floor(size * 0.44)))
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)
        .backgroundColor(Theme.brand())
        .borderRadius(Radius.full)
      if (url.trim().length > 0) {
        AvatarImage({ url: url.trim(), avatarSize: size })
      }
    }
    .width(size)
    .height(size)
    .onClick(() => {
      this.openUserProfile(authorId, author);
    })
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

  /**
   * 主图预览列表（2026-09-20 预览解耦）：只含主楼 + 楼层图片，**不再收集楼中楼（comments）图片**。
   * 楼中楼图片预览独立：宫格点击走单张预览（见 ImageGrid 的 singlePreview 分支），
   * 左右滑动不会再切进楼中楼图片。ImagePreview 流式补页的 extractStreamImages 同步只收楼层图。
   */
  private collectAllImages(): string[] {
    const all: string[] = [];
    if (this.detail && this.detail.images && this.detail.images.length > 0) {
      all.push(...this.detail.images);
    }
    for (const floor of this.floors) {
      if (floor.images && floor.images.length > 0) {
        all.push(...floor.images);
      }
    }
    return all;
  }

  private getImageGlobalOffset(localImages: string[]): number {
    const all = this.collectAllImages();
    if (localImages.length === 0) return 0;
    const firstUrl = localImages[0];
    const idx = all.indexOf(firstUrl);
    return idx >= 0 ? idx : 0;
  }

  /**
   * 图片宫格（真机错位修复 2026-09-13）：`Grid` 是**可滚动容器**，嵌在 `WaterFlow.FlowItem` 内时
   * 「自测量高度」与「实际渲染高度」可能不一致（格高恒 120 但总高靠 Grid 自算），布局期用错高度
   * 会把后续 FlowItem 摆错位置 → 卡片重叠（竖屏）/ 列溢出（横屏），真机已复现。
   * 故**显式给出总高** = 行数 × 格高〔`gridCellHeight()`：手机/平板 120、大折叠与 Pura X Max 72〕
   * + (行数 − 1) × 6，测量期即终值，与首页 ThreadCard
   * 「图片尺寸测量期确定」的成品口径对齐。
   * `capMaxWidth`：仅**通栏卡**（主楼）传 true（336 封顶防通栏拉伸）；列内卡（楼层 / 楼中楼）传 false
   * —— 窄列下列宽本就 < 336，写死 336 上限没有意义，跟随列宽（'100%'）杜绝交叉轴测量歧义。
   * `singlePreview`（2026-09-20 预览解耦）：true = 楼中楼宫格，点开**单张预览**
   * （urls 只传当前这张、不带流式补页上下文，左右滑不切图）；false = 主图/楼层宫格，
   * 走全局列表 + 流式补页（原行为）。
   */
  /**
   * 宫格单格高（vp）：大折叠（2026-09-16 用户反馈竖横屏宫格图片拉伸）分栏后格宽骤降——
   * 三分屏下主楼/楼层卡内容宽 ~150-240，3 列每格仅 ~50-75vp，格高恒 120 会把图拉成细条；
   * 收至 72（竖屏 55/72≈0.76、横屏 75/72≈1.04，与手机档 94.7/120≈0.79 比例同档）。
   * 其它形态维持 120 逐像素不变。微调点唯一（此常量）。
   */
  private gridCellHeight(): number {
    // Pura X Max（阔折叠展开）与大折叠同口径：分栏 W/3 + 回复 2 列后格宽骤降，72 防拉伸
    return (isLargeFoldDevice() || isPuraXMaxDevice()) ? 72 : 120;
  }

  @Builder
  ImageGrid(images: string[], capMaxWidth: boolean = true, singlePreview: boolean = false) {
    Grid() {
      ForEach(images, (img: string, idx: number) => {
        GridItem() {
          Stack() {
            ThreadGridImage({ src: img, isDark: this.isDark })
              .width('100%')
              .height(this.gridCellHeight())
          }
          .width('100%')
          .height(this.gridCellHeight())
          .onClick(() => {
            // 预览提速 P3（2026-09-23）：点击即拉——pushUrl 之前先把点击图的基础档
            // 灌进 ImageCache（闸门 priority=1 插队），路由转场动画期间下载已在并行进行；
            // 预览页首图同步直出/高清升级都吃这条在途链。已在缓存则 warmImages 自动跳过。
            ImageCache.warmImages([img], 1, 1);
            // 楼中楼宫格（singlePreview=true）：单张预览——urls 只含当前这张（单元素 Swiper 不可滑），
            // 不带流式补页上下文；主图/楼层宫格保持原「全局列表 + 流式补页」行为（2026-09-20 预览解耦）。
            if (singlePreview) {
              this.getUIContext().getRouter().pushUrl({
                url: 'pages/ImagePreview',
                params: { urls: [img] }
              }).catch(() => {
                this.getUIContext().getPromptAction().showToast({ message: '图片预览打开失败，请稍后重试' });
              });
              return;
            }
            const allImages = this.collectAllImages();
            const offset = this.getImageGlobalOffset(images);
            // 图片流式补页（2026-09-17）：浏览页滑到已加载图片末尾时，会按同一组分页参数
            // （tid/sortType/seeLz/forumId/commentRn）继续拉取后续楼层页并追加图片，
            // 使「未加载楼层的图片」也能直接滑到，无需先滚回列表加载楼层。
            // loadedPage/totalPage 用于给出补页游标与上限（详见 ImagePreview.ets 的流式补页说明）。
            this.getUIContext().getRouter().pushUrl({
              url: 'pages/ImagePreview',
              params: {
                urls: allImages,
                index: offset + idx,
                tid: this.tid,
                sortType: this.sortType,
                seeLz: this.seeLz,
                forumId: this.forumId,
                commentRn: this.commentRn,
                loadedPage: this.currentPage,
                totalPage: this.totalFloorPage
              }
            }).catch(() => {
              this.getUIContext().getPromptAction().showToast({ message: '图片预览打开失败，请稍后重试' });
            });
          })
        }
      }, (img: string, idx: number) => img)
    }
    .columnsTemplate('1fr 1fr 1fr')
    .columnsGap(6)
    .rowsGap(6)
    .width('100%')
    // 显式总高（错位修复）：行数 × 格高 + 行间隙，消除 FlowItem 内 Grid 自测量的不确定性
    .height(Math.ceil(images.length / 3) * this.gridCellHeight() + (Math.ceil(images.length / 3) - 1) * 6)
    // §4.9 DT-J：通栏卡限宽 336 防三列被均分到 1000+vp（每格 ≈ 320vp）而格高恒 120 → 图片横向拉伸。
    // 列内卡（capMaxWidth=false）跟随列宽 '100%'；手机档通栏可用宽 ≈ 296vp < 336 → 封顶不生效（逐像素不变）。
    .constraintSize({ maxWidth: capMaxWidth ? DETAIL_IMAGE_GRID_MAX_WIDTH : '100%' })
  }

  // 提取唯一表情URL集合（给隐藏预取Image跑onComplete/onError用）
  private uniqueEmojiUrls(fragments: ContentFragment[]): string[] {
    const out: string[] = [];
    const seen: Record<string, boolean> = {};
    for (const f of fragments ?? []) {
      if (f.type === ContentFragmentType.EMOJI && f.imageUrl && f.imageUrl.length > 0) {
        if (!seen[f.imageUrl]) {
          seen[f.imageUrl] = true;
          out.push(f.imageUrl);
        }
      }
    }
    return out;
  }

  @Builder
  RichTextContent(fragments: ContentFragment[], fallbackText: string, fontSize: number, fontColor: ResourceColor, lineHeightVal: number, regionKey: string) {
    Column() {
      if (fragments && fragments.length > 0) {
        // 启动 EmojiLoader HTTP 预取（带 Referer/UA 防盗链头，下载字节→PixelMap），完成后 readyEmojiUrls 触发重绘
        ForEach(this.uniqueEmojiUrls(fragments), (emojiUrl: string) => {
          Blank()
            .width(0)
            .height(0)
            .onAppear(() => this.prefetchEmojisWithLoader([emojiUrl]))
        }, (u: string) => u)
        // 真正的富文本显示：
        // - EmojiLoader 已拿到 PixelMap → ImageSpan(PixelMap) 直接渲染（彻底绕开防盗链）
        // - 尚未下载完成 → 显示 "[中文]" 占位，下载完成后自动切到图
        // - 已被判定下载失败 → 显示 "[中文]" 兜底文本
        // 单元素 ForEach 包裹（key 含复制重建纪元）：复制完成后自增纪元 → key 变化 → Text 节点整体重建
        // → 选中态随节点销毁清除。纪元未变时 key 相同、节点复用，零额外开销。
        ForEach([this.copyEpochOf(regionKey)], (copyEpoch: number) => {
          Text() {
            ForEach(fragments, (fragment: ContentFragment, idx: number) => {
              if (fragment.type === ContentFragmentType.EMOJI) {
                if ((fragment.imageUrl && fragment.imageUrl.length > 0) && this.hasReadyEmoji(fragment.imageUrl) && EmojiLoader.has(fragment.imageUrl)) {
                  ImageSpan(EmojiLoader.get(fragment.imageUrl) as image.PixelMap)
                    .width(fontSize * 1.2)
                    .height(fontSize * 1.2)
                    .verticalAlign(ImageSpanAlignment.CENTER)
                    .objectFit(ImageFit.Contain)
                    .borderRadius(fontSize * 0.18)
                } else if ((fragment.imageUrl && fragment.imageUrl.length > 0) && this.hasFailedEmoji(fragment.imageUrl) && fragment.text && fragment.text.length > 0) {
                  // EmojiLoader 下载失败（URL 无效）且有描述文本 → 文本兜底，避免空白
                  Span(fragment.text)
                    .fontSize(fontSize)
                    .fontColor(fontColor)
                } else if (fragment.imageUrl && fragment.imageUrl.length > 0) {
                  // 下载中 / 无文本的失败 → 直接 ImageSpan(url) 尝试（CDN 无防盗链，可直连渲染）
                  ImageSpan(fragment.imageUrl)
                    .width(fontSize * 1.2)
                    .height(fontSize * 1.2)
                    .verticalAlign(ImageSpanAlignment.CENTER)
                    .objectFit(ImageFit.Contain)
                    .borderRadius(fontSize * 0.18)
                } else if (fragment.text && fragment.text.length > 0) {
                  Span(fragment.text)
                    .fontSize(fontSize)
                    .fontColor(fontColor)
                }
              } else if (fragment.type === ContentFragmentType.IMAGE) {
                // Skip IMAGE fragments here — they are rendered separately by ImageGrid
              } else if (fragment.type === ContentFragmentType.LINK) {
                // 可点击超链接：主题色高亮 + 下划线，点击弹"是否跳转链接"确认卡片
                Span(fragment.text)
                  .fontSize(fontSize)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.isDark ? '#7FB8FF' : '#2F6BE8')
                  .decoration({
                    type: TextDecorationType.Underline,
                    color: this.isDark ? '#7FB8FF' : '#2F6BE8'
                  })
                  .onClick(() => {
                    this.openPendingLink((fragment.link !== undefined && fragment.link.length > 0) ? fragment.link : fragment.text);
                  })
              } else {
                Span(fragment.text)
                  .fontSize(fontSize)
                  .fontColor(fontColor)
              }
            }, (fragment: ContentFragment, idx: number) => this.hasReadyEmoji(fragment.imageUrl ?? '')
              ? `${idx}_${fragment.type}_${fragment.text}_${fragment.imageUrl ?? ''}_r`
              : this.hasFailedEmoji(fragment.imageUrl ?? '')
                ? `${idx}_${fragment.type}_${fragment.text}_${fragment.imageUrl ?? ''}_f`
                : `${idx}_${fragment.type}_${fragment.text}_${fragment.imageUrl ?? ''}_w`)
          }
          .fontSize(fontSize)
          .fontColor(fontColor)
          .lineHeight(lineHeightVal)
          .width('100%')
          // 长按选中复制（docs/帖子详细页长按复制文字功能补全.md 方案 A）：
          // LocalDevice 允许跨应用粘贴；draggable(false) 关闭选中拖拽防与滚动抢手势；
          // 选中色按系统默认；onCopy 弹「复制成功」并自增纪元清除选中态
          .copyOption(CopyOptions.LocalDevice)
          .draggable(false)
          .onCopy(() => { this.onTextCopied(regionKey); })
        }, (copyEpoch: number) => `${regionKey}_${copyEpoch}`)
      } else {
        // 与 Span 分支同款纪元重建：复制完成后清选中态
        ForEach([this.copyEpochOf(regionKey)], (copyEpoch: number) => {
          Text(fallbackText)
            .fontSize(fontSize)
            .fontColor(fontColor)
            .lineHeight(lineHeightVal)
            .width('100%')
            .copyOption(CopyOptions.LocalDevice)
            .draggable(false)
            .onCopy(() => { this.onTextCopied(regionKey); })
        }, (copyEpoch: number) => `${regionKey}_${copyEpoch}`)
      }
    }
    .width('100%')
  }

  // ===== 跳转官方贴吧（底部胶囊行「跳转」钮 → 确认弹窗 → 拉起官方 App 对应帖子）=====

  /** 帖子网页版链接（浏览器兜底 / 复制 / 弹窗预览用；只带 tid，不带任何登录态参数） */
  private threadWebUrl(): string {
    return `https://tieba.baidu.com/p/${this.tid}`;
  }

  /**
   * 拉起官方贴吧用的链接：贴吧 EntryAbility 的 skills 只声明了
   * scheme=https + host=wapp.baidu.com（另有 tiebaapp://router/portal、com.baidu.tieba://unidispatch），
   * 并不匹配 tieba.baidu.com，所以必须用 wapp 域名才能落到 App 内的帖子页。
   */
  private threadAppUrl(): string {
    return `https://wapp.baidu.com/p/${this.tid}`;
  }

  /**
   * 弹窗卡片宽度（vp）= min(屏幕宽 − 48vp, 400)，T-H 同款封顶——**弹窗不拉伸**（2026-09-15 用户拍板）。
   * 原实现只有下限 200 无封顶：平板屏宽 vp 下弹窗拉成通栏（系统默认 400 上限未兜住）。
   * ArkTS 的 Dimension 只接受数值 / 百分比 / 资源，不接受 calc 字符串，故换算成数值。
   * 手机档「屏宽 − 48」= 312 < 400，逐像素不变；窗口实宽优先（小窗 display ≠ 窗口），未就绪退 display。
   */
  private dialogCardWidth(): number {
    // 窗口实宽优先（2026-09-17 小窗 / 分屏适配）：小窗下 display ≠ 窗口，按 display 算会溢出窗口；
    // 全屏下两者等价。currentWidth 未就绪再退 display。
    let widthVp: number = 0;
    if (this.currentWidth > 0) {
      widthVp = this.currentWidth;
    } else {
      try {
        const info: display.Display = display.getDefaultDisplaySync();
        widthVp = info.width / info.densityPixels;
      } catch (e) {
        widthVp = 0;
      }
    }
    const w: number = widthVp - 48;
    const capped: number = w > 400 ? 400 : w;
    return Math.max(200, capped);
  }

  /**
   * 跳转官方贴吧确认弹窗（系统 CustomDialog + API 26 沉浸光感）。
   * 取自工程内同款确认卡片的口径（§4.3 / §6.4）：宽度 dialogCardWidth()、圆角 32、
   * 遮罩 #06000000、底部锚点、开合动画 220/200ms；玻璃层交给 options.systemMaterial
   * （ImmMaterial.dialog()）。
   * **上移量不是收藏 / 进吧页的 110 而是 140** —— 本页底部比它们多叠了一层「排序胶囊行」，
   * 110 会正好压在「正序 / 只看全部」两枚胶囊上（推导见下方 offset 注释）。
   * onWillDismiss 承接「点遮罩 / 返回键 / 侧滑」→ 与取消钮共用 closeJumpDialog（§4.5）。
   */
  private jumpDialogController: CustomDialogController = new CustomDialogController({
    builder: JumpTiebaDialogCard({
      isDark: $isDark,
      fontScale: $fontScale,
      targetUrl: $jumpUrlPreview,
      onConfirm: () => { this.confirmJump(); },
      onDismiss: () => { this.closeJumpDialog(); }
    }),
    autoCancel: true,
    // 底部锚点 + 上移 140vp（用户指定值）。本页底部比收藏页多叠一层，不能套收藏页的 -110：
    //   评论悬浮岛：底距 30 + 高 66 → 占「距底 30~96」；
    //   排序胶囊行：底距 96 + 高 46 → 占「距底 96~142」，行内 padding top4/bottom8 托着
    //   高 34 的钮体 → 钮体本体占「距底 104~138」。
    // 140 时弹窗底边落在钮体顶边(138)之上 2vp —— 刚好擦过胶囊行上沿、不盖住两枚胶囊文字。
    // ⚠️ 无特殊要求勿改回 -110（会实压在排序胶囊上），勿改回居中。
    alignment: DialogAlignment.Bottom,
    offset: { dx: 0, dy: -140 },
    maskColor: '#06000000',
    cornerRadius: 32,
    width: this.dialogCardWidth(),
    customStyle: false,
    systemMaterial: ImmMaterial.dialog(),
    openAnimation: { duration: 220, curve: Curve.EaseOut },
    closeAnimation: { duration: 200, curve: Curve.EaseInOut },
    // 点遮罩 / 返回键统一走 closeJumpDialog（与自绘浮层时期「点蒙层关闭」语义一致）
    onWillDismiss: () => { this.closeJumpDialog(); }
  });

  /** showJumpDialog 变化即驱动系统弹窗 open/close（既有 `this.showJumpDialog = x` 调用点零改动） */
  onShowJumpChanged(): void {
    if (this.showJumpDialog) {
      this.jumpDialogController.open();
    } else {
      this.jumpDialogController.close();
    }
  }

  private openJumpDialog(): void {
    if (this.tid.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '帖子信息暂不可用' });
      return;
    }
    // 打开前算好链接预览快照（弹窗内取不到宿主方法 threadWebUrl）
    this.jumpUrlPreview = this.threadWebUrl();
    this.showJumpDialog = true;
  }

  private closeJumpDialog(): void {
    this.showJumpDialog = false;
  }

  /** 官方贴吧是否已安装（只判断包是否存在，不读取内部结构字段） */
  private isTiebaInstalled(): boolean {
    try {
      const info: bundleManager.BundleInfo =
        bundleManager.getBundleInfoSync(TIEBA_OFFICIAL_BUNDLE, bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      return info !== undefined && info !== null;
    } catch (e) {
      return false;
    }
  }

  /** 隐式拉起（浏览器 / 应用市场网页） */
  private startViewUrl(url: string): void {
    const hostCtx = this.getUIContext().getHostContext();
    if (!hostCtx) {
      return;
    }
    try {
      const ctx: common.UIAbilityContext = hostCtx as common.UIAbilityContext;
      const want: Want = { uri: url, action: 'ohos.want.action.viewData', type: 'text/plain' };
      ctx.startAbility(want).catch(() => {
        this.getUIContext().getPromptAction().showToast({ message: '打开失败，请稍后重试' });
      });
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({ message: '打开失败，请稍后重试' });
    }
  }

  /**
   * 确认跳转：① 限定官方贴吧 + 帖子 uri（贴吧声明了 host skills 时直达帖子页，贴吧 LITE 同思路）
   * ② 显式拉起官方贴吧入口（进 App 首页）③ 回落浏览器网页版 ④ 复制链接
   */
  private async confirmJump(): Promise<void> {
    const url: string = this.threadWebUrl();
    const appUrl: string = this.threadAppUrl();
    this.showJumpDialog = false;
    const hostCtx = this.getUIContext().getHostContext();
    if (!hostCtx) {
      this.copyJumpLink(url);
      return;
    }
    const ctx: common.UIAbilityContext = hostCtx as common.UIAbilityContext;
    // ① 限定官方贴吧 + wapp 帖子链接：命中贴吧声明的 skills，直达 App 内帖子页
    try {
      await ctx.startAbility({
        bundleName: TIEBA_OFFICIAL_BUNDLE,
        uri: appUrl,
        action: 'ohos.want.action.viewData'
      });
      return;
    } catch (e) {
      this.logJumpFail('wapp直达', e);
    }
    // ② 显式指定 EntryAbility 并带 uri：App 在 onNewWant 里解析链接也能落到帖子页
    try {
      await ctx.startAbility({
        bundleName: TIEBA_OFFICIAL_BUNDLE,
        abilityName: 'EntryAbility',
        uri: appUrl,
        action: 'ohos.want.action.viewData'
      });
      return;
    } catch (e) {
      this.logJumpFail('EntryAbility+uri', e);
    }
    // ③ 系统提供的官方入口 Want（打开 App 首页）
    try {
      const launchWant: Want = bundleManager.getLaunchWantForBundleSync(TIEBA_OFFICIAL_BUNDLE);
      await ctx.startAbility(launchWant);
      return;
    } catch (e) {
      this.logJumpFail('launchWant', e);
    }
    // ③ 显式指定常见入口 ability 名兜底（查询三方包信息受权限限制，不能只依赖检测结果）
    const abilityCandidates: string[] = ['EntryAbility', 'MainAbility'];
    for (const abilityName of abilityCandidates) {
      try {
        await ctx.startAbility({ bundleName: TIEBA_OFFICIAL_BUNDLE, abilityName: abilityName });
        return;
      } catch (e) {
        this.logJumpFail(abilityName, e);
      }
    }
    // ④ 全部拉起失败：确认已安装则回落浏览器网页版，否则引导去应用市场
    if (this.isTiebaInstalled()) {
      try {
        await ctx.startAbility({ uri: url, action: 'ohos.want.action.viewData', type: 'text/plain' });
        return;
      } catch (e) {
        this.logJumpFail('浏览器', e);
      }
      this.copyJumpLink(url);
      return;
    }
    this.getUIContext().getPromptAction().showToast({ message: '未安装官方贴吧，正在前往应用市场' });
    this.startViewUrl(TIEBA_MARKET_URL);
  }

  /** 记录跳转失败原因，便于真机 hilog 定位（不会打扰用户） */
  private logJumpFail(step: string, e: Object): void {
    const err = e as BusinessError;
    console.info(`[跳转贴吧] ${step}失败 code=${err?.code ?? ''} msg=${err?.message ?? String(e)}`);
  }

  private copyJumpLink(url: string): void {
    try {
      const sysPasteboard = pasteboard.getSystemPasteboard();
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, url);
      sysPasteboard.setData(pasteData, (err: BusinessError | undefined) => {
        const msg: string = err ? '复制失败，请手动复制' : '无法打开官方贴吧，链接已复制';
        this.getUIContext().getPromptAction().showToast({ message: msg });
      });
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({ message: '无法打开官方贴吧，请手动复制链接' });
    }
  }

  // ===== 链接跳转确认（点击正文/楼层/楼中楼中的链接）=====
  private openPendingLink(url: string): void {
    if (!url || url.length === 0) return;
    this.pendingLinkUrl = url;
    this.showLinkDialog = true;
  }

  private closeLinkDialog(): void {
    this.showLinkDialog = false;
  }

  private copyPendingLink(): void {
    const url: string = this.pendingLinkUrl;
    if (url.length === 0) return;
    try {
      const sysPasteboard = pasteboard.getSystemPasteboard();
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, url);
      sysPasteboard.setData(pasteData, (err: BusinessError | undefined) => {
        this.showLinkDialog = false;
        if (err) {
          this.getUIContext().getPromptAction().showToast({ message: `复制失败：${err.message ?? String(err)}` });
        } else {
          this.getUIContext().getPromptAction().showToast({ message: '链接已复制' });
        }
      });
    } catch (e) {
      this.showLinkDialog = false;
      this.getUIContext().getPromptAction().showToast({ message: '复制失败，请重试' });
    }
  }

  private confirmOpenLink(): void {
    const url: string = this.pendingLinkUrl;
    if (url.length === 0) return;
    const hostCtx = this.getUIContext().getHostContext();
    if (hostCtx === undefined || hostCtx === null) {
      this.copyLinkFallback(url);
      return;
    }
    try {
      const ctx: common.UIAbilityContext = hostCtx as common.UIAbilityContext;
      const want: Want = {
        uri: url,
        action: 'ohos.want.action.viewData',
        type: 'text/plain'
      };
      ctx.startAbility(want).then(() => {
        this.showLinkDialog = false;
      }).catch((err: BusinessError) => {
        // 拉起失败（无可用浏览器等）：复制兜底，避免用户感觉"点了没反应"
        this.showLinkDialog = false;
        this.copyLinkFallback(url);
      });
    } catch (e) {
      this.showLinkDialog = false;
      this.copyLinkFallback(url);
    }
  }

  // 无法拉起系统浏览器时的兜底：复制链接并提示
  private copyLinkFallback(url: string): void {
    try {
      const sysPasteboard = pasteboard.getSystemPasteboard();
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, url);
      sysPasteboard.setData(pasteData, (err: BusinessError | undefined) => {
        const tip: string = err
          ? '无法打开浏览器，且复制失败，请手动复制'
          : '无法打开浏览器，链接已复制到剪贴板';
        this.getUIContext().getPromptAction().showToast({ message: tip });
      });
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({ message: '无法打开浏览器，请手动复制链接' });
    }
  }

  // 链接跳转确认：暗蒙层 + 沉浸光感磨砂玻璃居中卡片 + 竖排操作按钮（风格与收藏页确认弹窗一致）
  @Builder
  LinkConfirmDialog() {
    Stack() {
      // 暗色蒙层，点击外部关闭
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#06000000')
        .onClick(() => { this.closeLinkDialog(); })
        .transition(TransitionEffect.opacity(0).animation({ duration: 180, curve: Curve.EaseOut }))

      Column() {
        // 标题 + URL 预览
        Column({ space: 6 }) {
          Text('是否跳转链接')
            .fontSize(fs(17, this.fontScale))
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.textPrimary(this.isDark))
            .textAlign(TextAlign.Center)
          Text(this.pendingLinkUrl)
            .fontSize(fs(13, this.fontScale))
            .fontColor(Theme.textSecondary(this.isDark))
            .lineHeight(fs(18, this.fontScale))
            .textAlign(TextAlign.Center)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ left: Spacing.lg, right: Spacing.lg, top: Spacing.lg, bottom: Spacing.md })

        // 竖向操作按钮：复制链接 / 确认 / 取消
        Column({ space: Spacing.sm }) {
          Button() {
            Text('复制链接')
              .fontSize(fs(15, this.fontScale))
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.textPrimary(this.isDark))
          }
          .width('100%')
          .height(44)
          .backgroundColor(Theme.bgCard(this.isDark))
          .borderRadius(Radius.full)
          .accessibilityText('复制链接')
          .onClick(() => { this.copyPendingLink(); })

          Button() {
            Text('确认')
              .fontSize(fs(15, this.fontScale))
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
          }
          .width('100%')
          .height(44)
          .backgroundColor(Theme.brand())
          .borderRadius(Radius.full)
          .accessibilityText('确认跳转')
          .onClick(() => { this.confirmOpenLink(); })

          Button() {
            Text('取消')
              .fontSize(fs(15, this.fontScale))
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.textPrimary(this.isDark))
          }
          .width('100%')
          .height(44)
          .backgroundColor(Theme.bgCard(this.isDark))
          .borderRadius(Radius.full)
          .accessibilityText('取消')
          .onClick(() => { this.closeLinkDialog(); })
        }
        .width('100%')
        .padding({ left: Spacing.lg, right: Spacing.lg, bottom: Spacing.lg })
      }
      .width(overlayCardWidth())
      .padding({ top: Spacing.md })
      .backgroundColor(Theme.sheetBg(this.isDark))
      .shadow(Theme.glassShadowStyle()).backgroundEffect(ImmBlur.control())
      .systemMaterial(ImmMaterial.control())
      .borderRadius(32)
      .border({ width: { top: 1.5 }, color: Theme.sheetTopGlow(this.isDark) })
      .shadow({ radius: 48, color: '#3D000000', offsetY: 18 })
      // 弹出动画与项目其它居中确认卡一致：缩放 + 上移 + 淡入
      .transition(TransitionEffect.scale({ x: 0.92, y: 0.92 }).combine(TransitionEffect.translate({ y: 24 })).combine(TransitionEffect.opacity(0)).animation({ duration: 220, curve: Curve.EaseOut }))
    }
    .width('100%')
    .height('100%')
    .zIndex(100)
    // 消失动画：整树淡出（根级 transition，否则 if 移除时子级退场不播）
    .transition(TransitionEffect.asymmetric(
      TransitionEffect.IDENTITY,
      TransitionEffect.opacity(0).animation({ duration: 200, curve: Curve.EaseInOut })
    ))
  }


  /** 底部评论输入条外壳：inIsland=true（官方悬浮岛路径）外壳透明，胶囊与官方材质由悬浮条本体承担；
   *  inIsland=false（旧叠放路径）保留整条玻璃大胶囊兜底。内部内容两路径共用 CommentBarBody。 */
  @Builder
  CommentBar(inIsland: boolean) {
    if (inIsland) {
      Row({ space: 8 }) {
        this.CommentBarBody()
      }
      // 岛内内容宽度（2026-09-13 回退）：曾改为 `dockPillWidth() − 16` 试图解决平板裁切，但 `dockPillWidth()`
      // 在手机档 = 296 → 减 16 后手机底栏内容宽从「全屏 100%」变成 280，**破坏了手机零回归**（用户已驳回，回退）。
      .width('100%')
      // 岛内高度跟随岛总高（单点 dockPillHeight：大折叠 62 / 平板手机 66），避免双 66 漂移
      .height(this.dockPillHeight())
      // 底栏内部居中（2026-09-13）：点赞 / 收藏 / 发送钮固定宽，「跳转」胶囊 layoutWeight(1)
      // 撑满剩余 → 内容填满岛宽；显式声明居中对齐作为意图表达。
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      // 垂直居中补偿（2026-09-13 二次确认·两端统一）：官方悬浮岛的系统留白**上多下少**（与形态无关，
      // 同一系统组件），无补偿时内容整体偏上 —— 平板档曾按「仅平板移除补偿」归零，真机随即复现
      // 「点赞 / 收藏 / 跳转 / 发送整体偏上、看似不齐」（各元素高 42/46/42，偏移量随高度略异）。
      // 故补偿恢复**两端统一** bottom 8（内容区上移 4vp 贴合官方岛视觉中心）；手机档本就是 8，零变化。
      // 大折叠（2026-09-15 真机反馈横竖屏均「上面留空多于下面」）：官方岛留白差在该形态更大，
      // 补偿加大到 16（再上移 4vp）拉平上下留空；同日随后岛高收 4（66→62），补偿同步 16→12
      // 使内容区 62−12=50 与改前 66−16=50 完全一致（元素相对位置零变化，仅岛更紧凑）；
      // 手机 / 平板维持 8 不变。微调点唯一（此常量）。
      .padding({ left: 0, right: 0, top: 0, bottom: isLargeFoldDevice() ? 12 : 8 })
    } else {
      Row({ space: 8 }) {
        this.CommentBarBody()
      }
      // 底栏不拉伸（2026-09-13）：原 `calc(100% - 64vp)` 在平板下同样会被拉成通栏，
      // 改固定宽（手机基线 296，与官方悬浮岛同宽）；父 `BottomDock` 的 Column 是
      // `align(Alignment.Bottom)` → 固定宽子项天然水平居中。
      .width(this.dockPillWidth())
      .height(66)
      .padding({ left: 6, right: 6, top: 4, bottom: 4 })
      // 外层整体玻璃胶囊：真磨砂（Regular）+ 极淡底/描边/轻影，点赞/收藏直接放在上面，不再套“框中框”。
      .backgroundColor(Theme.segGlass(this.isDark, false))
      .border({ width: 0.5, color: Theme.manualGlassBorder() })
      .backgroundBlurStyle(BlurStyle.Regular, { scale: 0.85 })
      .shadow(Theme.segGlassShadow(this.isDark, false))
      .borderRadius(33)
      .margin({ bottom: 30 })
    }
  }

  /**
   * 岛内跳转胶囊 / 发送钮垂直微调（vp）：仅大折叠生效，平板 / 手机 / 其它形态恒 0 逐像素不变。
   * 历史：66 岛时代两元素偏上 → 拨 +4；岛高收 62（2026-09-15）后官方系统留白同步收、
   * 两元素转为偏下 → 拨正量归 0 回归纯公式居中。微调点唯一（此常量），观感偏差变化时只调该值。
   */
  private islandNudge(): number {
    // 当前 = 0（62 岛下两元素纯公式即居中）；如真机再报偏差，按方向改此值（偏上为正、偏下为负）
    return 0;
  }

  /** 评论条内容（点赞/收藏 + 输入区 + 发送钮）：由 CommentBar 的两种外壳共用 */
  @Builder
  CommentBarBody() {
    // 点赞按钮（含计数）：直接放在底栏大胶囊背景上，不再套独立小玻璃框
    Row({ space: 3 }) {
      SymbolGlyph($r('sys.symbol.hand_thumbsup'))
        .fontSize(fs(22, this.fontScale))
        .fontColor([this.liked ? $r('sys.color.icon_emphasize') : $r('sys.color.icon_secondary')])
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        .hitTestBehavior(HitTestMode.Transparent)
      Text(`${this.detail?.likeCount ?? 0}`)
        .fontSize(fs(12, this.fontScale))
        .fontColor(this.liked ? $r('sys.color.icon_emphasize') : $r('sys.color.font_secondary'))
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .constraintSize({ minWidth: 18 })
        .hitTestBehavior(HitTestMode.Transparent)
    }
    .height(42)
    .padding({ left: 8, right: 6 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => { this.toggleLike(); })

    // 收藏按钮：同样去掉独立小玻璃框。
    // 短按 = 收藏 / 取消收藏（行为不变）；长按 350ms = 弹分类面板「收藏并归类」（方案 A：下滑/点遮罩关闭零副作用）。
    // 长按与点击同挂一个组件时，长按识别成功后点击事件不再触发（与收藏页收纳夹长按置顶同机制），故短按不会被长按入口抢走。
    Row() {
      SymbolGlyph($r('sys.symbol.bookmark'))
        .fontSize(fs(22, this.fontScale))
        .fontColor([this.collected ? $r('sys.color.icon_emphasize') : $r('sys.color.icon_secondary')])
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        .hitTestBehavior(HitTestMode.Transparent)
    }
    .height(42)
    .padding({ left: 6, right: 6 })
    .alignItems(VerticalAlign.Center)
    .accessibilityText(this.collected ? '取消收藏，长按收藏并归类' : '收藏，长按收藏并归类')
    .onClick(() => { this.collected = !this.collected; this.persistPersonalState(CACHE_KEY.PERSONAL_COLLECTED, this.collected); })
    .gesture(LongPressGesture({ fingers: 1, repeat: false, duration: 350 })
      .onAction(() => { this.openCategoryPicker(); }))

    // 回复框改为跳转入口：本客户端不提供发回帖能力（第三方协议有封号风险），
    // 点击后弹确认框并跳转官方贴吧对应帖子。外观沿用原输入胶囊（玻璃底 + 真磨砂 + 全圆胶囊）。
    Row({ space: 10 }) {
      Row() {
        Text('跳转到官方贴吧')
          .fontSize(fs(14, this.fontScale))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(fs(16, this.fontScale))
          .fontColor([$r('sys.color.icon_secondary')])
          .renderingStrategy(SymbolRenderingStrategy.SINGLE)
          .hitTestBehavior(HitTestMode.Transparent)
      }
      .layoutWeight(1)
      .height(46)
      .padding({ left: 16, right: 12 })
      .backgroundColor(Theme.manualGlass(this.isDark))
      .border({ width: 0.5, color: Theme.manualGlassBorder() })
      .backgroundBlurStyle(BlurStyle.Thin, { scale: 0.9 })
      .borderRadius(33)
      .alignItems(VerticalAlign.Center)
      .offset({ y: this.islandNudge() })
      .accessibilityText('跳转到官方贴吧')
      .onClick(() => { this.openJumpDialog(); })

      // 发送按钮保留（维持底栏视觉平衡）：同样触发跳转官方贴吧
      Button() {
        SymbolGlyph($r('sys.symbol.paperplane'))
          .fontSize(fs(20, this.fontScale))
          .fontColor([$r('sys.color.font_on_primary')])
          .renderingStrategy(SymbolRenderingStrategy.SINGLE)
      }
      .width(42)
      .height(42)
      .margin({ right: 4 })
      .offset({ y: this.islandNudge() })
      .backgroundColor(Theme.glassAccent())
      .shadow({ radius: 10, color: this.isDark ? '#733173FF' : '#403173FF', offsetY: 2 })
      .borderRadius(Radius.full)
      .accessibilityText('跳转到官方贴吧')
      .onClick(() => { this.openJumpDialog(); })
    }
    .layoutWeight(1)
    .alignItems(VerticalAlign.Center)
  }
}
