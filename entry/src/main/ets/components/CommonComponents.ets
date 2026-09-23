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

import { Theme, Spacing, Radius, isDarkMode, ImmBlur, ImmMaterial, fs } from '../common/Theme';
import { ImageCache } from '../cache/ImageCache';
import {
  acquireImagePreloadSlot as acquireImagePreloadSlotInner,
  releaseImagePreloadSlot as releaseImagePreloadSlotInner
} from '../cache/ImageCache';
import { TiebaService } from '../service/TiebaService';
import { display } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const LOG_DOMAIN: number = 0x0A01;
const TAG: string = 'TiebaImgCard';
const MAX_URL_LOG: number = 120;

function shortUrl(url: string): string {
  return url.length > MAX_URL_LOG ? url.substring(0, MAX_URL_LOG) + '...' : url;
}

// 图片预下载全局并发闸门：限制同时下载的图片数，避免首屏大量卡片图片同时请求抢占带宽，
// 让列表正文先渲染、图片逐个到达（下载本身仍在 ImageCache 内以沙箱缓存串起复用）
// §IMGQ（2026-09-19）：由模块私有改为 export，供 ThreadDetail 楼层宫格/头像共用同一口闸门——
// 详情页楼层是全量渲染（Scroll+Column+ForEach），进帖瞬间上百张图同时下载，
// 此前只有列表卡片走闸门、详情页完全裸奔。
// v1.24（2026-09-19）：8 → 16。配合 ThreadDetail 宫格/头像的「进入视口才发起」门控后，
// 排队量本身已被压到「一屏左右」，可以放宽并发让首屏一次到位（8 并发下首屏 9~18 张要排 2~3 批）。
// 接口侧已有独立 Session（§IMGQ）隔离，小体积缩略图并发提高对接口的影响可忽略。
// v1.26（2026-09-19）：实现移至 cache/ImageCache.ets —— 服务层「点击即预热」也要用同一口闸门，
// 并发原语归图片缓存管；此处保留同名转发，既有调用点（本文件卡片预载 / ThreadDetail 宫格与头像）零改动。
export function acquireImagePreloadSlot(priority: number = 0): Promise<void> {
  return acquireImagePreloadSlotInner(priority);
}

export function releaseImagePreloadSlot(): void {
  releaseImagePreloadSlotInner();
}

// v1.26（P2）按下即预取：Touch Down 起计时，Move 超阈值（滚动起手）即取消，不会造成滚动误预取；
// 计时到点 / 快速点按抬起（计时未到且位移很小）立即预取 —— 比 onClick 提前约一拍把详情数据请求发出去。
const CARD_PRESS_PREFETCH_MS: number = 60;
const CARD_PRESS_MOVE_LIMIT: number = 12;   // vp，位移超过视为滚动/拖动

// 用于 @Prop 的帖子卡片数据结构
export interface ThreadItemData {
  tid: string;
  postId?: string;       // 首个楼层ID，用于点赞
  forumId?: string;
  title: string;
  forumName: string;
  forumAvatar?: string;
  author: string;
  authorAvatar?: string;
  authorId?: string;     // 作者用户 ID，用于头像点击跳转用户主页
  replyNum: number;
  likeCount?: number;
  isLiked?: boolean;     // 是否已点赞
  abstract: string;
  firstImage: string;
  images?: string[];
  // 2026-09-20 宫格秒加载：与 images 同序的官方缩略图（首页 feed media.srcPic）。
  // ThreadCard 多图宫格首画直连小图，本地 960 真图落地后自动升级；单图分支不用（大图区会糊）。
  // 缺省/空串回退原 URL，其它页面数据源不携带时行为与改造前一致。
  imageThumbs?: string[];
  createTime: string;
  isTop: boolean;
  isGood?: boolean;
}

// 分享回调传入的帖子 payload，保证ArkTS对象字面量类型安全（禁止未声明类型的内联对象）
export interface ThreadSharePayload {
  tid: string;
  title: string;
  forumName: string;
  author: string;
  abstract: string;
  firstImage: string;
}

/**
 * 通用加载态组件：居中转圈 + 文案
 */
@Component
export struct LoadingView {
  @Prop message: string = '加载中...';
  @StorageLink('fontScale') fontScale: number = 1.0;

  build() {
    Column({ space: Spacing.md }) {
      LoadingProgress()
        .width(36)
        .height(36)
        .color(Theme.brand())
      Text(this.message)
        .fontSize(fs(14, this.fontScale))
        .fontColor(Theme.textSecondary(isDarkMode()))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Theme.bg(isDarkMode()))
  }
}

/**
 * 空态组件
 */
@Component
export struct EmptyView {
  @Prop message: string = '暂无内容';
  @Prop icon: string = '📭';
  @BuilderParam action: () => void = this.emptyBuilder;
  @Prop actionText: string = '';
  @StorageLink('fontScale') fontScale: number = 1.0;

  @Builder
  emptyBuilder() {
  }

  build() {
    Column({ space: Spacing.md }) {
      Text(this.icon)
        .fontSize(fs(48, this.fontScale))
      Text(this.message)
        .fontSize(fs(15, this.fontScale))
        .fontColor(Theme.textSecondary(isDarkMode()))
      if (this.actionText.length > 0) {
        Button(this.actionText)
          .fontSize(fs(14, this.fontScale))
          .fontColor($r('sys.color.font_on_primary'))
          .backgroundColor(Theme.manualGlass(isDarkMode(), true))
          .border({ width: 0.5, color: Theme.manualGlassBorder() })
          .shadow(Theme.glassShadowStyle()).backgroundEffect(ImmBlur.accent())
          .systemMaterial(ImmMaterial.accent(isDarkMode()))
          .borderRadius(Radius.full)
          .padding({ left: 20, right: 20, top: 8, bottom: 8 })
          .onClick(() => {
            this.action();
          })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Theme.bg(isDarkMode()))
  }
}

/**
 * 错误态组件：显示错误信息 + 重试按钮
 */
@Component
export struct ErrorView {
  @Prop message: string = '加载失败';
  onRetry: () => void = () => {};
  @StorageLink('fontScale') fontScale: number = 1.0;

  build() {
    Column({ space: Spacing.md }) {
      Text('⚠️')
        .fontSize(fs(44, this.fontScale))
      Text(this.message)
        .fontSize(fs(15, this.fontScale))
        .fontColor(Theme.textSecondary(isDarkMode()))
        .textAlign(TextAlign.Center)
        .padding({ left: 24, right: 24 })
      Button('重试')
        .fontSize(fs(14, this.fontScale))
        .fontColor($r('sys.color.font_on_primary'))
        .backgroundColor(Color.Transparent)
        .shadow(Theme.glassShadowStyle()).backgroundEffect(ImmBlur.accent())
        .systemMaterial(ImmMaterial.accent(isDarkMode()))
        .borderRadius(Radius.full)
        .padding({ left: 24, right: 24, top: 8, bottom: 8 })
        .onClick(() => {
          this.onRetry();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Theme.bg(isDarkMode()))
  }
}

/**
 * 置顶帖子卡片（仅显示标题，带置顶徽章）
 */
@Component
export struct PinnedThreadItem {
  @Prop item: ThreadItemData = {
    tid: '', title: '', forumName: '', author: '',
    replyNum: 0, abstract: '', firstImage: '', createTime: '', isTop: false,
  };
  onTap: (tid: string) => void = () => {};
  @StorageLink('fontScale') fontScale: number = 1.0;

  build() {
    Row({ space: 12 }) {
      Text(this.getItem().isGood === true ? '精品' : '置顶')
        .fontSize(fs(13, this.fontScale))
        .fontColor(Color.White)
        .backgroundColor(this.getItem().isGood === true ? Theme.brand() : Theme.badgePin(isDarkMode()))
        .borderRadius(4)
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })

      Text(this.getItem().title)
        .fontSize(fs(15, this.fontScale))
        .fontColor(Theme.textPrimary(isDarkMode()))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .onClick(() => {
      if (this.getItem().tid.length > 0) {
        this.onTap(this.getItem().tid);
      }
    })
  }

  private getItem(): ThreadItemData {
    return this.item;
  }
}

/**
 * 帖子列表单项（新版样式：头像+昵称+时间+标题+内容+图片+操作栏）
 */
@Component
export struct ThreadCard {
  // 2026-09-20 性能优化：@Prop 深拷贝改普通成员。卡数据只在创建时传入，后续更新全部走
  // 「key 变更 → 整卡重建」（HomeTab/ThreadList 的 key 均含 isLiked/likeCount/replyNum），
  // @Prop 的深拷贝纯属创建期浪费（多列瀑布流一次建 6+ 卡时最明显）。
  item: ThreadItemData = {
    tid: '',
    postId: '',
    forumId: '',
    title: '',
    forumName: '',
    forumAvatar: '',
    author: '',
    authorAvatar: '',
    replyNum: 0,
    likeCount: 0,
    isLiked: false,
    abstract: '',
    firstImage: '',
    images: [],
    imageThumbs: [],
    createTime: '',
    isTop: false,
    isGood: false,
  };
  onTap: (tid: string) => void = () => {};
  onLike: (tid: string, postId: string, liked: boolean) => void = () => {};
  // 分享回调：由父组件(Index/ThreadList)注入实现，拉起鸿蒙系统分享面板
  onShare: (data: ThreadSharePayload) => void = () => {};
  // 评论回调：由父组件(Index/ThreadList)注入实现，跳转帖子详情
  onComment: (tid: string) => void = () => {};
  // 头像点击回调：由父组件(Index/ThreadList)注入实现，跳转用户主页
  onAvatarTap: (authorId: string, author: string) => void = () => {};
  // v1.26（P2）按下即预取：计时器句柄与按下起点（Move 位移判滚动用）
  private pressPrefetchTimer: number = -1;
  private pressX: number = 0;
  private pressY: number = 0;
  // 2026-09-20：本次触摸已判定为滚动手势（Move 超限取消）后置位 —— 后续高频 Move 事件直接早退，
  // 不再逐事件算位移；Down 时复位。
  private pressPrefetchDead: boolean = false;

  private cancelPressPrefetch(): void {
    if (this.pressPrefetchTimer >= 0) {
      clearTimeout(this.pressPrefetchTimer);
      this.pressPrefetchTimer = -1;
    }
  }

  /**
   * v1.26（P2）按下即预取（挂在卡片内容区根节点的 onTouch）：
   * - Down：起 100ms 计时器，到点即预取详情数据；
   * - Move：位移超过 12vp 视为滚动/拖动 → 取消（滚动起手不会误预取）；
   * - Up：计时器还在（快速点按，抬起早于计时器）→ 立即预取；
   * - Cancel：取消。
   * prefetchThreadDetail 自带「内存缓存有效 / 在途」判重，与 onClick 路径的预取天然互斥，不会重复请求。
   */
  private handlePressPrefetch(event: TouchEvent): void {
    const tid: string = this.getItem().tid;
    if (tid.length === 0) {
      return;
    }
    if (event.type === TouchType.Down) {
      this.pressX = event.touches[0].x;
      this.pressY = event.touches[0].y;
      this.pressPrefetchDead = false;
      this.cancelPressPrefetch();
      this.pressPrefetchTimer = setTimeout(() => {
        this.pressPrefetchTimer = -1;
        TiebaService.getInstance().prefetchThreadDetail(tid, this.getItem().forumId ?? '');
      }, CARD_PRESS_PREFETCH_MS);
      return;
    }
    if (event.type === TouchType.Move) {
      if (this.pressPrefetchDead) {
        return;
      }
      const p: TouchObject = event.touches[0];
      if (Math.abs(p.x - this.pressX) + Math.abs(p.y - this.pressY) > CARD_PRESS_MOVE_LIMIT) {
        this.pressPrefetchDead = true;
        this.cancelPressPrefetch();
      }
      return;
    }
    if (event.type === TouchType.Up && this.pressPrefetchTimer >= 0) {
      this.cancelPressPrefetch();
      TiebaService.getInstance().prefetchThreadDetail(tid, this.getItem().forumId ?? '');
      return;
    }
    this.cancelPressPrefetch();
  }

  /**
   * 操作栏收紧判定（docs/TiebaPura阔直屏适配.md，2026-09-15 用户云调试反馈：阔直屏竖 2 列
   * 窄卡下分享/评论/点赞三胶囊「文字图标比按钮大」溢出）。
   * 根因：胶囊 layoutWeight(1) 均分、内容（图标 18 + 内距 6 + 文字 13 号）恒占 ~50vp，
   * 卡宽 < 240 时胶囊被压到 ~55vp 以下内容必溢出（Row 不裁剪、直接画出界）。
   * 触发档位 = 阔直屏竖 2 列（卡 ~210）；平板竖 2 列卡 ~370 / 平板横 3 列 ~408 /
   * 阔直屏横 3 列 ~258 / 手机单列均 > 240 不收紧，平板与手机观感零变化。
   * 卡宽按「屏宽 − 页面左右边距(Spacing.lg×2) − 列间距((列数−1)×Spacing.md)」÷ 列数估算
   * （不求像素准只求相对准，同 PersonalContent 分桶估算口径）。
   */
  /** actionCompact() 记忆化缓存：key = 上次求值时的列数（-1 表示尚未求值） */
  private actionCompactCachedKey: number = -1;
  private actionCompactCachedValue: boolean = false;

  private actionCompact(): boolean {
    if (this.cardColumns <= 1) {
      return false;
    }
    // 记忆化（2026-09-19 性能优化）：本方法在 build 里被调用 10+ 次/卡（每处
    // height/borderRadius/fontSize/space 三元都要算一次），每次都 display.getDefaultDisplaySync()
    // 跨进程取屏参 + px2vp，纯属浪费。判定只取决于「列数」：display 取的是**物理屏宽**，
    // 仅随旋转/折叠变化，而这两种情况各页列数必然同步变化，故按列数记忆等价。
    if (this.cardColumns === this.actionCompactCachedKey) {
      return this.actionCompactCachedValue;
    }
    let compact: boolean = false;
    try {
      const d: display.Display = display.getDefaultDisplaySync();
      const screenW: number = this.getUIContext().px2vp(d.width);
      const cardW: number =
        (screenW - Spacing.lg * 2 - Spacing.md * (this.cardColumns - 1)) / this.cardColumns;
      compact = cardW < 240;
    } catch (e) {
      compact = false;
    }
    this.actionCompactCachedKey = this.cardColumns;
    this.actionCompactCachedValue = compact;
    return compact;
  }
  /**
   * 图片加载失败标记：任一图加载失败时降级为作者头像缩略 + 失败提示，
   * 避免大图区域显示占位（看起来像"图片没出来"）。
   */
  /**
   * 全局只读列数标记（平板适配文档 §4.2 决策 6）：
   * 仅在多列档（> 1）才比例化卡内几何；单列（手机 / 窄窗）逐像素保持改造前取值。
   * 由各多列页**无条件**写入（单列也写 1），避免跨页残留（§6.1 D1 / D6）。
   */
  @StorageProp('cardColumns') cardColumns: number = 1;
  @State imageFailed: boolean = false;
  /** 正在阶梯重试的图片 URL 集合：防 preload/onError/onComplete 多路径对同一 URL 重复启动重试阶梯 */
  private retryingUrls: Set<string> = new Set<string>();
  /**
   * 已下载到沙箱缓存的图片本地路径（file://...）。首次渲染走原 URL（可能命中贴吧防盗链
   * 200×200 占位），后台异步下载到沙箱缓存后写入本表并触发重新渲染，Image 切换到本地路径，
   * 彻底绕开贴吧图床对 Image 组件的防盗链 / UA 拦截。
   */
  @State cachedImageMap: Record<string, string> = {};
  /**
   * 缓存命中后检查自愈：单图渲染失败(imageFailed=true)进入降级占位后,后台异步预下载若终于命中本地缓存,
   * 由 setCachedImage 写入并主动调用本方法。命中所有图后清除 imageFailed,组件切回 Image 分支走本地路径,
   * 实现"图片加载失败"短暂闪烁后自动恢复,而不是永久占位。
   * （替代 @Watch：避免 ArkTS 严格模式下 @Watch 在嵌套 Component 中的解析问题）
   */
  private tryRecoverFromCache(): void {
    if (!this.imageFailed) {
      return;
    }
    const imgs: string[] | undefined = this.item.images;
    if (!imgs || imgs.length === 0) {
      return;
    }
    for (const u of imgs) {
      if (!this.cachedImageMap[u]) {
        return;
      }
    }
    this.imageFailed = false;
  }
  @StorageLink('fontScale') fontScale: number = 1.0;

  /**
   * onError 后重试 ImageCache.resolve（带贴吧 UA/Referer/Cookie + 镜像域候选）。
   * 命中本地缓存时由 setCachedImage 写入并触发 tryRecoverFromCache 自愈检查。
   * v1.21 实抓(0902_154709 / 0902_155150):
   *   - 新发布帖子图片 CDN 异步同步延迟可达 30s+(imgsrc/tiebapic 初次均返回占位);
   *   - v1.20 retryOrFail 中 tryLoad 遇到占位 local==='' 立即 imageFailed=true + return true,
   *     提前退出阶梯重试链 —— 这导致"图片加载失败"在第一次 resolve 失败后就显示,
   *     阶梯重试从未真正执行(0902_155150 日志验证:无 retry HEALED 也无 FINAL FAIL)。
   *   - 修正:占位时返回 false 让阶梯继续,只在所有重试都失败后才 imageFailed。
   *     阶梯序列 [0, 2s, 8s, 30s] 覆盖 0~40s 的 CDN 同步窗口。
   */
  private async retryOrFail(u: string | undefined): Promise<void> {
    if (!u) {
      this.imageFailed = true;
      return;
    }
    // 防重入：同一 URL 只允许一条阶梯(preload / onError / onComplete 可能并发触发)
    if (this.retryingUrls.has(u)) {
      return;
    }
    this.retryingUrls.add(u);
    try {
      const tryLoad = async (): Promise<boolean> => {
        try {
          const local: string = await ImageCache.resolve(u);
          // 占位(local===''):不立即 imageFailed,留给阶梯结束再判定,
          // 给 CDN 异步同步延迟(可达 30s+)留窗口。重复重试仍然有意义。
          if (local === '') {
            ImageCache.debugLog(`card retry PLACEHOLDER continue url=${shortUrl(u)}`);
            return false;
          }
          if (local !== u && !local.startsWith('http')) {
            hilog.info(LOG_DOMAIN, TAG, 'retry healed url=%{public}s', shortUrl(u));
            ImageCache.debugLog(`card retry HEALED url=${shortUrl(u)}`);
            this.setCachedImage(u, local);
            return true;
          }
        } catch (e) {
          /* 重试仍失败,继续阶梯 */
        }
        return false;
      };
      // 阶梯重试序列:立即 + 2s + 8s + 30s,覆盖 ~40s CDN 同步窗口。
      // 第一次延迟 0 不阻塞,直接进入 tryLoad(命中本地缓存场景);后续每次延迟再试。
      // Z5（2026-09-19 掉帧治理,零视觉影响）:后三档加 ±20% 随机抖动。
      // 新兴帖子的图在 CDN 未同步时会集中失败;若延迟严格为定值,同一批卡会在 30s 档
      // 同一时刻集体唤醒 → 单帧内 N 次 resolve + 解码,锁 120Hz(8.3ms)下必然掉帧。
      // 抖动只打散唤醒时刻,重试次数/判定逻辑/总窗口(~40s,最坏 36s)均不变。
      const delays: number[] = [
        0,
        Math.round(2000 * (0.8 + Math.random() * 0.4)),
        Math.round(8000 * (0.8 + Math.random() * 0.4)),
        Math.round(30000 * (0.8 + Math.random() * 0.4))
      ];
      for (const d of delays) {
        if (d > 0) {
          await new Promise<void>((resolve) => setTimeout(resolve, d));
        }
        // v1.22: 仅缓存命中时提前结束。不再以 imageFailed 中断阶梯——
        // 旧 onComplete 会先把占位误判为失败并置位，反过来把重试链提前掐断。
        if (this.cachedImageMap[u]) {
          return; // 已被其它路径自愈
        }
        if (await tryLoad()) {
          return; // 已自愈
        }
      }
      // 阶梯全失败,无论最终是网络失败还是持续占位,统一标记 imageFailed。
      if (!this.cachedImageMap[u]) {
        hilog.error(LOG_DOMAIN, TAG, 'retry final fail url=%{public}s', shortUrl(u));
        ImageCache.debugLog(`card retry FINAL FAIL url=${shortUrl(u)}`);
        this.imageFailed = true;
      }
    } finally {
      this.retryingUrls.delete(u);
    }
  }

  /** 写入本地缓存路径（触发重渲染）+ 检查自愈（替代 @Watch） */
  private setCachedImage(u: string, local: string): void {
    const next: Record<string, string> = {};
    const keys: string[] = Object.keys(this.cachedImageMap);
    for (const k of keys) {
      next[k] = this.cachedImageMap[k];
    }
    next[u] = local;
    this.cachedImageMap = next;
    this.tryRecoverFromCache();
  }

  aboutToAppear(): void {
    // Z1（2026-09-19）：先把「已在磁盘且已确认安全」的图同步填进 cachedImageMap，
    // 使首帧 Image 直接拿到 file:// 真图，省掉「先请求 CDN 拿回 238×238 占位图 →
    // onComplete 判占位 → 阶梯重试 → 才切本地路径」的整条往返。
    this.seedCachedImages();
    this.preloadImages();
  }

  /**
   * Z1：同步预填已确认安全的本地缓存路径（组件创建时执行一次，整表一次性赋值）。
   * 判定走 ImageCache.getVerifiedCachedPath（命中缓存且文件大小已达灰阶校验豁免档），
   * 未命中或过小的图不填，仍由 preloadImages 的异步路径处理（含像素灰阶兜底），
   * 行为与改动前完全一致。
   */
  private seedCachedImages(): void {
    const imgs: string[] | undefined = this.item.images;
    if (!imgs || imgs.length === 0) {
      return;
    }
    const next: Record<string, string> = {};
    let hits: number = 0;
    for (const u of imgs) {
      if (!u) continue;
      const local: string | null = ImageCache.getVerifiedCachedPath(u);
      if (local !== null) {
        next[u] = local;
        hits++;
      }
    }
    if (hits > 0) {
      this.cachedImageMap = next;
    }
  }

  /** 通过 ImageCache（带贴吧 UA + Referer + Cookie）预下载图片到沙箱缓存 */
  private async preloadImages(): Promise<void> {
    const imgs: string[] | undefined = this.item.images;
    if (!imgs || imgs.length === 0) {
      ImageCache.debugLog(`card preload SKIP imgs-empty tid=${this.item.tid}`);
      return;
    }
    ImageCache.debugLog(`card preload START tid=${this.item.tid} n=${imgs.length} u0=${shortUrl(imgs[0])}`);
    // 单图走 resolve（命中即同步返回，未命中阻塞到下载完成），多图经并发闸门预下载
    const tasks: Promise<void>[] = [];
    for (const u of imgs) {
      if (!u || this.cachedImageMap[u]) continue;
      tasks.push((async () => {
        await acquireImagePreloadSlot();
        try {
          const local: string = await ImageCache.resolve(u);
          // v1.21.1 修复：占位(local==='')不再立即 imageFailed,
          // 改为启动阶梯重试 [0, 2s, 8s, 30s],见 retryOrFail。
          // 真图(本地缓存命中或网络成功)走 setCachedImage 自愈。
          if (local !== u && !local.startsWith('http') && local !== '') {
            this.setCachedImage(u, local);
            return;
          }
          if (local === '') {
            ImageCache.debugLog(`card preload PLACEHOLDER schedule-retry url=${shortUrl(u)}`);
            // 启动阶梯重试(不阻塞当前批次其它图片预下载)
            this.retryOrFail(u);
            return;
          }
          ImageCache.debugLog(`card preload resolve-NOCACHE url=${shortUrl(u)}`);
        } catch (e) {
          ImageCache.debugLog(`card preload EXCEPTION url=${shortUrl(u)} err=${JSON.stringify(e)}`);
        } finally {
          releaseImagePreloadSlot();
        }
      })());
    }
    await Promise.all(tasks);
  }

  /** 把原 URL 解析为本地缓存路径（命中）或原 URL（未命中） */
  private resolveImgUrl(u: string | undefined): string {
    if (!u) return '';
    return this.cachedImageMap[u] ?? u;
  }

  /**
   * 2026-09-20 宫格秒加载：srcPic 缩略图直连失败标记（键=原图 URL）。
   * 置位后 gridDisplayUrl 对该格回退原图 bigPic 直连，行为与改造前一致。
   */
  @State gridThumbFallbacks: Record<string, boolean> = {};

  /**
   * 2026-09-20 宫格秒加载：多图宫格显示 URL 三级解析（单图分支不用，保持 bigPic 直连）。
   * ① 本地缓存 file://（HASH 归一真图，全尺寸解码——autoResize 真机实测对百分比尺寸本地图解码失败已回退）；
   * ② 官方 srcPic 缩略图（首页 feed media.srcPic，几十 KB 级直连秒出，原版贴吧 App 同源）；
   * ③ 原图 bigPic（960 宽变体）——srcPic 缺失 / 已标记加载失败时回退。
   * 闸门下载落地后 cachedImageMap 命中即自动升级高清本地图；布局/尺寸/占位检测零改动。
   */
  private gridDisplayUrl(img: string, idx: number): string {
    const cached: string | undefined = this.cachedImageMap[img];
    if (cached !== undefined) {
      return cached;
    }
    if (this.gridThumbFallbacks[img] !== true) {
      const thumbs: string[] | undefined = this.getItem().imageThumbs;
      if (thumbs !== undefined && idx >= 0 && idx < thumbs.length) {
        const t: string = thumbs[idx];
        if (t.length > 0) {
          return t;
        }
      }
    }
    return img;
  }

  private getItem(): ThreadItemData {
    return this.item;
  }

  private getImageCount(): number {
    const imgs = this.getItem().images;
    if (imgs && imgs.length > 0) {
      return Math.min(imgs.length, 9);
    }
    return 0;
  }

  build() {
    Column() {
      // ========== 跳转详情区域：作者→标题→摘要→图片→吧标签（点击跳帖子详情）==========
      Column() {
        // 作者信息行
        Row({ space: 10 }) {
          // 作者头像（独立点击进用户主页；stopPropagation 避免触发整卡跳详情）
          if (this.getItem().authorAvatar && this.getItem().authorAvatar!.length > 0) {
            Image(this.getItem().authorAvatar!)
              .width(40)
              .height(40)
              .borderRadius(20)
              .objectFit(ImageFit.Cover)
              .clip(true)
              .hitTestBehavior(HitTestMode.Block)
              .onClick(() => {
                this.onAvatarTap(this.getItem().authorId ?? '', this.getItem().author);
              })
          } else {
            Stack() {
              Text(this.getItem().author.charAt(0))
                .fontSize(fs(18, this.fontScale))
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
            }
            .width(40)
            .height(40)
            .borderRadius(20)
            .backgroundColor(Theme.brand())
            .alignContent(Alignment.Center)
            .hitTestBehavior(HitTestMode.Block)
            .onClick(() => {
              this.onAvatarTap(this.getItem().authorId ?? '', this.getItem().author);
            })
          }

          // 作者名和时间
          Column({ space: 2 }) {
            Text(this.getItem().author)
              .fontSize(fs(15, this.fontScale))
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.textPrimary(isDarkMode()))
              .hitTestBehavior(HitTestMode.Block)
              .onClick(() => {
                // 点击作者名跳用户主页（Block 阻断冒泡，避免触发整卡跳详情）
                this.onAvatarTap(this.getItem().authorId ?? '', this.getItem().author);
              })
            Text(this.getItem().createTime)
              .fontSize(fs(12, this.fontScale))
              .fontColor(Theme.textTertiary(isDarkMode()))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16 })

        // 标题
        Text(this.getItem().title)
          .fontSize(fs(17, this.fontScale))
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.textPrimary(isDarkMode()))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding({ left: 16, right: 16, top: 8 })

        // 正文摘要：多列档降为 2 行（列窄、一屏要放下更多卡），单列逐像素维持现状 4 行
        if (this.getItem().abstract.length > 0) {
          Text(this.getItem().abstract)
            .fontSize(fs(14, this.fontScale))
            .fontColor(Theme.textSecondary(isDarkMode()))
            .maxLines(this.cardColumns > 1 ? 2 : 4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .padding({ left: 16, right: 16, top: 6 })
        }

        // 图片区域
        if (this.getImageCount() > 0) {
          Column() {
            this.ImageGallery()
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10 })
        }

        // 吧标签
        Row() {
          if (this.getItem().forumName.length > 0) {
            Row({ space: 4 }) {
              // 吧头像
              if (this.getItem().forumAvatar && this.getItem().forumAvatar!.length > 0) {
                Image(this.getItem().forumAvatar!)
                  .width(20)
                  .height(20)
                  .borderRadius(10)
                  .objectFit(ImageFit.Cover)
                  .clip(true)
              }
              Text(this.getItem().forumName)
                .fontSize(fs(13, this.fontScale))
                .fontColor(Theme.textSecondary(isDarkMode()))
            }
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 10 })
      }
      .width('100%')
      .hitTestBehavior(HitTestMode.Default)
      .onClick(() => {
        // 点击卡片上半部分（内容区）跳帖子详情；底部三胶囊不在此区域，避免事件互吞
        const tid = this.getItem().tid;
        if (tid.length > 0) {
          this.onTap(tid);
        }
      })
      // v1.26（P2）按下即预取：手指按下（且非滚动）就把详情数据请求发出去，吃掉"按下到抬起"这一拍
      .onTouch((event: TouchEvent) => {
        this.handlePressPrefetch(event);
      })

      // ========== 操作栏（独立区域）：分享/评论/点赞三胶囊，完全不在跳转详情的点击区域内 ==========
      // 窄卡收紧模式（actionCompact）：图标 15/文字 11/内距 4/高 30/圆角 15/外距 8——
      // 阔直屏竖 2 列卡 ~210vp 时胶囊 ~50vp，原尺寸内容 ~50vp 必溢出（Row 不裁剪直接画出界）
      Row({ space: this.actionCompact() ? 8 : 12 }) {
        // 分享按钮 - 圆角胶囊（玻璃光感背景不变）+ 简约黑色分享图标（与帖子详情页右上角同款 sys.symbol.share）
        Row({ space: this.actionCompact() ? 4 : 6 }) {
          SymbolGlyph($r('sys.symbol.share'))
            .fontSize(fs(this.actionCompact() ? 15 : 18, this.fontScale))
            .fontColor([Theme.textPrimary(isDarkMode())])
          Text('分享')
            .fontSize(fs(this.actionCompact() ? 11 : 13, this.fontScale))
            .fontColor(Theme.textPrimary(isDarkMode()))
        }
        .layoutWeight(1)
        .height(this.actionCompact() ? 30 : 36)
        .justifyContent(FlexAlign.Center)
        .borderRadius(this.actionCompact() ? 15 : 18)
        .backgroundColor(Theme.sheetGlass(isDarkMode()))
        .backgroundBlurStyle(BlurStyle.Regular, { scale: 0.85 })
        .border({ width: 0.5, color: Theme.manualGlassBorder() })
        // 2026-09-19 性能优化：删除 .shadow(Theme.glassShadowStyle()) —— 该函数恒返回全零阴影
        // { radius: 0, color: '#00000000' }，渲染无痕迹，只是每卡白付一次阴影属性；
        // 删除 .systemMaterial(ImmMaterial.cardAction()) —— 页面主体内材质判 out of scope 不渲染
        // （见 docs/immersive-material-guide.md），胶囊玻璃观感由上方 backgroundColor(sheetGlass)
        // + backgroundBlurStyle(Regular) 独立提供，故两处删除对画面零差异、每卡省 3 次材质挂载。
        // 若后续真机实拍发现差异，把这两行原样加回即可（其余属性无需变动）。
        .onClick(() => {
          const payload: ThreadSharePayload = {
            tid: this.getItem().tid,
            title: this.getItem().title,
            forumName: this.getItem().forumName,
            author: this.getItem().author,
            abstract: this.getItem().abstract,
            firstImage: this.getItem().firstImage
          };
          this.onShare(payload);
        })
        
        // 评论按钮 - 玻璃胶囊背景不变 + 实心气泡三点图标 ellipsis_message_fill（与分享 sys.symbol.share 同为填充风格，避免描边图标过细）
        Row({ space: this.actionCompact() ? 4 : 6 }) {
          SymbolGlyph($r('sys.symbol.ellipsis_message_fill'))
            .fontSize(fs(this.actionCompact() ? 15 : 18, this.fontScale))
            .fontColor([Theme.textPrimary(isDarkMode())])
          Text(`${this.getItem().replyNum}`)
            .fontSize(fs(this.actionCompact() ? 11 : 13, this.fontScale))
            .fontColor(Theme.textPrimary(isDarkMode()))
        }
        .layoutWeight(1)
        .height(this.actionCompact() ? 30 : 36)
        .justifyContent(FlexAlign.Center)
        .borderRadius(this.actionCompact() ? 15 : 18)
        .backgroundColor(Theme.sheetGlass(isDarkMode()))
        .backgroundBlurStyle(BlurStyle.Regular, { scale: 0.85 })
        .border({ width: 0.5, color: Theme.manualGlassBorder() })
        // 同分享钮：删除恒空阴影与页面主体内不生效的 cardAction 材质（理由见上）
        .onClick(() => {
          const tid = this.getItem().tid;
          if (tid.length > 0) {
            this.onComment(tid);
          }
        })
        
        // 点赞按钮 - 玻璃胶囊背景不变 + 简约心形轮廓/实心SymbolGlyph（匹配参考图一）
        Row({ space: this.actionCompact() ? 4 : 6 }) {
          if (this.getItem().isLiked) {
            SymbolGlyph($r('sys.symbol.heart_fill'))
              .fontSize(fs(this.actionCompact() ? 16 : 19, this.fontScale))
              .fontColor([Theme.textPrimary(isDarkMode())])
          } else {
            SymbolGlyph($r('sys.symbol.heart'))
              .fontSize(fs(this.actionCompact() ? 16 : 19, this.fontScale))
              .fontColor([Theme.textPrimary(isDarkMode())])
          }
          Text(`${this.getItem().likeCount ?? 0}`)
            .fontSize(fs(this.actionCompact() ? 11 : 13, this.fontScale))
            .fontColor(Theme.textPrimary(isDarkMode()))
        }
        .layoutWeight(1)
        .height(this.actionCompact() ? 30 : 36)
        .justifyContent(FlexAlign.Center)
        .borderRadius(this.actionCompact() ? 15 : 18)
        .backgroundColor(Theme.sheetGlass(isDarkMode()))
        .backgroundBlurStyle(BlurStyle.Regular, { scale: 0.85 })
        .border({ width: 0.5, color: Theme.manualGlassBorder() })
        // 同分享钮：删除恒空阴影与页面主体内不生效的 cardAction 材质（理由见上）
        .onClick(() => {
          const tid = this.getItem().tid;
          const postId = this.getItem().postId ?? '';
          const targetPid = postId.length > 0 ? postId : '0';
          const liked = !this.getItem().isLiked;
          if (tid.length > 0) {
            this.onLike(tid, targetPid, liked);
          }
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 14 })
    }
    .width('100%')
    .backgroundColor(Theme.bgCard(isDarkMode()))
    // 卡片圆角 26：与帖子详情页卡片（楼主卡 / 楼层卡）统一口径，不借用全局 Radius.lg（=16）。
    // 注：卡内「分享/评论/点赞」胶囊圆角 18、距卡片底 14，严格同心应为 18 + 14 = 32；
    // 26 是按统一视觉口径取的值（比 32 略收敛，胶囊与外角不再严格同心，观感更克制）。
    // 操作栏内边距与三枚胶囊尺寸一律不动。
    .borderRadius(26)
  }

  /**
   * 单图加载失败：onError 后重试一次 ImageCache.resolve（带贴吧 UA/Referer/Cookie 的下载），
   * 多数偶发失败(网络抖动/原 URL 被防盗链)能命中本地缓存自愈，不立即锁死降级。
   */
  private handleSingleImageError(): void {
    const u: string = this.getItem().images![0];
    hilog.warn(LOG_DOMAIN, TAG, 'onError single url=%{public}s', shortUrl(u));
    ImageCache.debugLog(`card onError single url=${shortUrl(u)}`);
    this.retryOrFail(u);
  }

  /**
   * 单图加载完成：贴吧 CDN 对非移动端 UA/IP 的图床请求会返回占位图（HTTP 200 + 200/238 方图），
   * onError 不会触发（因为"加载成功"），必须靠尺寸识别。
   * v1.22: 识别到占位不立即 imageFailed（避免新帖图"先失败后恢复"的闪烁），改为确保 retryOrFail
   * 阶梯在跑：命中本地缓存(带 UA 下载成功)后自愈切真图，仅当整条阶梯(0~40s CDN 同步窗口)
   * 全部失败后才降级。命中本地真实图时走 file:// 不受影响。
   */
  private handleSingleImageComplete(loadingStatus: number, w: number, h: number): void {
    if (loadingStatus === 1 && ((w === 200 && h === 200) || (w === 238 && h === 238))) {
      ImageCache.debugLog(`card onComplete PLACEHOLDER ${w}x${h} url=${shortUrl(this.getItem().images![0])}`);
      if (!this.cachedImageMap[this.getItem().images![0]]) {
        this.retryOrFail(this.getItem().images![0]);
      }
    }
  }

  /** 多图格加载失败：重试沙箱缓存，命中后自愈（与单图同口径，各自重试、不整卡降级） */
  private handleGridImageError(img: string): void {
    hilog.warn(LOG_DOMAIN, TAG, 'onError grid url=%{public}s', shortUrl(img));
    ImageCache.debugLog(`card onError grid url=${shortUrl(img)}`);
    // 2026-09-20 宫格秒加载：若当前显示的是 srcPic 缩略图且加载失败，标记回退原图 bigPic 直连
    //（重试逻辑不变，仍按原 URL 解析本地缓存）。整体赋新对象触发重渲染，与 setCachedImage 同口径。
    if (this.gridThumbFallbacks[img] !== true) {
      const next: Record<string, boolean> = {};
      const keys: string[] = Object.keys(this.gridThumbFallbacks);
      for (const k of keys) {
        next[k] = this.gridThumbFallbacks[k];
      }
      next[img] = true;
      this.gridThumbFallbacks = next;
    }
    this.retryOrFail(img);
  }

  /** 多图格占位图识别：同单图口径，各自走 retryOrFail 等 CDN 同步，命中缓存后自愈 */
  private handleGridImageComplete(img: string, loadingStatus: number, w: number, h: number): void {
    if (loadingStatus === 1 && ((w === 200 && h === 200) || (w === 238 && h === 238))) {
      ImageCache.debugLog(`card onComplete PLACEHOLDER ${w}x${h} grid url=${shortUrl(img)}`);
      if (!this.cachedImageMap[img]) {
        this.retryOrFail(img);
      }
    }
  }

  @Builder
  ImageGallery() {
    if (this.imageFailed) {
      // 降级：图加载失败时不渲染大图区，避免占位看起来像"没图"；改为作者头像缩略 + 提示
      Row({ space: 10 }) {
        if (this.getItem().authorAvatar && this.getItem().authorAvatar!.length > 0) {
          Image(this.getItem().authorAvatar!)
            .width(48)
            .height(48)
            .borderRadius(24)
            .objectFit(ImageFit.Cover)
            .clip(true)
            .backgroundColor(Theme.bgCard(isDarkMode()))
        }
        Text(this.getItem().authorAvatar ? '图片加载失败，点击查看' : '图片加载失败，点击查看')
          .fontSize(fs(13, this.fontScale))
          .fontColor(Theme.textSecondary(isDarkMode()))
          .layoutWeight(1)
      }
      .width('100%')
      .padding(12)
      .backgroundColor(Theme.bgCard(isDarkMode()))
      .borderRadius(Radius.md)
      .hitTestBehavior(HitTestMode.Block)
      .onClick(() => {
        this.onTap(this.getItem().tid);
      })
    } else if (this.getImageCount() === 1) {
          // 单图：单列档逐像素保持 height(220)；多列档列宽变窄，改 16:10 比例，
          // 避免"列宽 240 时接近方形 / 列宽 400 时明显变扁"（§4.2 决策 6）。
          // 封顶 220：列宽变宽时 aspectRatio(1.6) 会等比放大高度，真机上出现"图比手机还大"，
          // 锁死手机基线高度后只横向扩展、纵向不再无限放大。
          if (this.cardColumns > 1) {
            Image(this.resolveImgUrl(this.getItem().images![0]))
              .width('100%')
              .aspectRatio(1.6)
              .constraintSize({ maxHeight: 220 })
              .borderRadius(Radius.md)
              .objectFit(ImageFit.Cover)
              .onError(() => {
                this.handleSingleImageError();
              })
              .onComplete((event) => {
                if (!event) return;
                this.handleSingleImageComplete(event.loadingStatus, event.width, event.height);
              })
          } else {
            Image(this.resolveImgUrl(this.getItem().images![0]))
              .width('100%')
              .height(220)
              .borderRadius(Radius.md)
              .objectFit(ImageFit.Cover)
              .onError(() => {
                this.handleSingleImageError();
              })
              .onComplete((event) => {
                if (!event) return;
                this.handleSingleImageComplete(event.loadingStatus, event.width, event.height);
              })
          }
        } else {
          // 多图网格（2-9张），使用 Grid 实现均匀间距
          Grid() {
            ForEach(this.getItem().images!.slice(0, this.getImageCount()), (img: string, idx: number) => {
              GridItem() {
                // 多图格几何：单列档保持现状格高（2/4 张 140、其余 100）；多列档列宽随列数变，
                // 改 1:1 比例，避免比例失真（§4.2 决策 6）。两种写法互斥（height 与 aspectRatio 同设会冲突）。
                // 封顶同单列档：防止列宽变宽后多图格也变得比手机大。
                if (this.cardColumns > 1) {
                  // 2026-09-20 宫格秒加载：显示 URL 三级解析（本地缓存 → srcPic 缩略图 → bigPic 原图）
                  Image(this.gridDisplayUrl(img, idx))
                    .width('100%')
                    .aspectRatio(1)
                    .constraintSize({
                      maxHeight: (this.getImageCount() === 2 || this.getImageCount() === 4) ? 140 : 100
                    })
                    .borderRadius(Radius.md)
                    .objectFit(ImageFit.Cover)
                    .onError(() => {
                      this.handleGridImageError(img);
                    })
                    .onComplete((event) => {
                      if (!event) return;
                      this.handleGridImageComplete(img, event.loadingStatus, event.width, event.height);
                    })
                } else {
                  Image(this.gridDisplayUrl(img, idx))
                    .width('100%')
                    .height((this.getImageCount() === 2 || this.getImageCount() === 4) ? 140 : 100)
                    .borderRadius(Radius.md)
                    .objectFit(ImageFit.Cover)
                    .onError(() => {
                      this.handleGridImageError(img);
                    })
                    .onComplete((event) => {
                      if (!event) return;
                      this.handleGridImageComplete(img, event.loadingStatus, event.width, event.height);
                    })
                }
              }
            }, (img: string, idx: number) => `${idx}`)
          }
          .columnsTemplate((this.getImageCount() === 2 || this.getImageCount() === 4) ? '1fr 1fr' : '1fr 1fr 1fr')
          .columnsGap(8)
          .rowsGap(8)
          .width('100%')
          // 关键：Grid 是可滚动容器，嵌在页面 Scroll 内会抢先接管 pan 手势判定，
          // 内容不超高时它自己滚不动、外层 Scroll 又拿不到拖动 → 多图区域"断触/滑不动"。
          // 关闭其自身滚动交互，手势全部交还外层 Scroll（纯手势开关，不影响布局与视觉）。
          .enableScrollInteraction(false)
          // 嵌套滚动策略：父容器（页面 Scroll）优先。
          // 与上面的 enableScrollInteraction(false) 是同向的防御性双保险——若该开关将来被改回
          // true，仍由 PARENT_FIRST 保证拖动优先交给外层 Scroll，不会回到"内层 Grid 抢手势"的老问题。
          .nestedScroll({
            scrollForward: NestedScrollMode.PARENT_FIRST,
            scrollBackward: NestedScrollMode.PARENT_FIRST
          })
        }
  }
}

