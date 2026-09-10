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
import { CACHE_KEY } from '../common/Constants';
import { PersonalContentItem, PagedResult } from '../model/DataModel';
import { TiebaService } from '../service/TiebaService';
import { AuthManager } from '../service/AuthManager';
import { Theme, Spacing, Radius, isDarkMode, ImmBlur, ImmMaterial, MaterialManager, fs } from '../common/Theme';
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
  /** 页面可见时自增，强制组件重建使字号实时生效 */
  @State fontSizeTick: number = 0;
  /** API26+ 沉浸光感能力：true 时顶栏走官方 title 槽位，否则回退自绘玻璃 TopBar（与 ThreadDetail 同判据） */
  @State materialSupported: boolean = false;

  onPageShow(): void {
    this.fontSizeTick++;
  }
  private pageSize: number = 20;
  /** 「我的点赞」云端已加载到的页码（1 基，与服务端 pn 语义一致） */
  private likesPage: number = 0;

  aboutToAppear(): void {
    MaterialManager.init();
    this.materialSupported = MaterialManager.isSupported() && MaterialManager.getApiLevel() >= 26;
    const params = this.getUIContext().getRouter().getParams() as Record<string, Object>;
    this.mode = `${params?.mode ?? PersonalMode.Posts}`;
    this.title = this.modeTitle(this.mode);
    this.isDark = isDarkMode();
    this.accountId = AuthManager.getInstance().getUser()?.userId ?? '';
    this.loadItems();
  }

  private modeTitle(mode: string): string {
    if (mode === PersonalMode.Likes) return '我的点赞';
    if (mode === PersonalMode.Collections) return '我的收藏';
    if (mode === PersonalMode.History) return '浏览历史';
    return '我的帖子';
  }

  private async loadItems(): Promise<void> {
    if (this.loading) return;
    this.loading = true;
    this.state = LoadState.Loading;
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
        const baseKey: string = CACHE_KEY.PERSONAL_HISTORY;
        const cached = await CacheManager.getInstance().get(`${baseKey}_${this.accountId}`);
        this.items = cached ? this.sortItems(JSON.parse(cached) as PersonalContentItem[]) : [];
        this.hasMore = false;
      }
      this.state = this.items.length > 0 ? LoadState.Success : LoadState.Empty;
    } catch (e) {
      this.items = [];
      this.state = LoadState.Error;
      const message: string = e instanceof Error ? e.message : `${e}`;
      this.errorMsg = message.trim().length > 0 ? message : `${this.title}加载失败，请稍后重试`;
    } finally {
      this.loading = false;
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
        List() {
          // 预留顶栏高度作为初始间距
          ListItem() {
            Column().width('100%').height(98)
          }
          // key 只用 tid：tid 是合并去重的主键，用 `${id}_${tid}` 时同一条帖的 id 若在
          // 本地缓存 / 云端之间不一致会换 key，导致 ListItem 被销毁重建（闪现）。
          ForEach(this.items, (item: PersonalContentItem) => {
            ListItem() {
              this.ContentCard(item)
            }
          }, (item: PersonalContentItem) => item.tid)
        }
        .layoutWeight(1)
        .padding({ left: Spacing.lg, right: Spacing.lg, top: 0, bottom: Spacing.xl })
        .scrollBar(BarState.Off)
        .clip(false)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .overlay(this.BottomFadeOverlay())
        .blendMode(BlendMode.SRC_OVER, BlendApplyType.OFFSCREEN)
        .onReachEnd(() => { this.loadMore(); })
        // 距末尾还有 5 项就提前取下一页：让追加落在视口下方、在用户滑到底部边界之前完成，
        // 避免「边界回弹的瞬间插入新内容」造成抽搐；onReachEnd 保留作兜底（列表不满一屏等）。
        .onScrollIndex((start: number, end: number) => {
          if (end >= this.items.length - 5) {
            this.loadMore();
          }
        })
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

  /** 触底翻页：收藏走 offset，点赞走 1 基页码 pn（服务端 data.has_more 判定） */
  private async loadMore(): Promise<void> {
    if (this.loading || this.loadingMore || !this.hasMore) return;
    const isLikes: boolean = this.mode === PersonalMode.Likes;
    if (!isLikes && this.mode !== PersonalMode.Collections) return;
    this.loadingMore = true;
    try {
      if (isLikes) {
        const result: PagedResult<PersonalContentItem> =
          await TiebaService.getInstance().fetchUserAgreeThreads(this.likesPage + 1, this.pageSize);
        this.likesPage += 1;
        this.items = this.appendUnique(this.items, result.list);
        await CacheManager.getInstance().put(`${CACHE_KEY.PERSONAL_LIKED}_${this.accountId}`, JSON.stringify(this.items));
        this.hasMore = result.hasMore;
      } else {
        const remote = await TiebaService.getInstance().fetchCollectedThreads(this.accountId, this.items.length, this.pageSize);
        this.items = this.mergeItems(this.items, remote);
        await CacheManager.getInstance().put(`${CACHE_KEY.PERSONAL_COLLECTED}_${this.accountId}`, JSON.stringify(this.items));
        this.hasMore = remote.length >= this.pageSize;
      }
      this.state = this.items.length > 0 ? LoadState.Success : LoadState.Empty;
    } catch (e) {
      const tip: string = isLikes ? '更多点赞加载失败，请稍后重试' : '更多收藏加载失败，请稍后重试';
      this.getUIContext().getPromptAction().showToast({ message: tip });
    } finally {
      this.loadingMore = false;
    }
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

  @Builder
  ContentCard(item: PersonalContentItem) {
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
        Text(item.createTime)
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
    .margin({ bottom: Spacing.md })
    .onClick(() => {
      // 点击即预取：利用跳转动画窗口后台取详情，详情页打开即命中缓存秒开
      TiebaService.getInstance().prefetchThreadDetail(`${item.tid}`, '');
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/ThreadDetail',
        params: { tid: item.tid, forum: item.forumName }
      });
    })
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
