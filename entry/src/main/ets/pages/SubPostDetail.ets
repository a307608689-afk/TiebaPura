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

import { SubPostDetail as SubPostDetailModel, FloorItem, CommentItem, ContentFragment, ContentFragmentType } from '../model/DataModel';
import { common, Want } from '@kit.AbilityKit';
import { pasteboard, BusinessError } from '@kit.BasicServicesKit';
import { TiebaService } from '../service/TiebaService';
import { Theme, Spacing, Radius, isDarkMode, ImmBlur, ImmMaterial, MaterialManager, fs } from '../common/Theme';
import { LoadingView, EmptyView, ErrorView } from '../components/CommonComponents';
import { EmojiLoader } from '../network/EmojiLoader';
import image from '@ohos.multimedia.image';

enum LoadState {
  Loading, Success, Empty, Error,
}

/**
 * 顶部官方标题栏开关（与 ThreadDetail / HomeTab / ForumsTab 同机制）：
 * true  = 「返回钮 / 吧名胶囊」整行搬进 Navigation 的 title 槽位，玻璃交给官方沉浸材质 systemMaterial
 *         （官方口径：systemMaterial 生效区域仅 Navigation/NavDestination 标题栏、横向 Tabs(barPosition=End)
 *          底部 TabBar；页面 body 内自绘浮层必判 Material inactive: out of scope）；
 *         几何与「帖子详细页」DetailTitleBar 逐项一致（返回 44 圆钮 + 吧名 58% 宽胶囊居中）。
 * false = 回退改造前的页面主体悬浮顶栏（shadow + backgroundEffect(ImmBlur.control()) 真磨砂兜底）。
 * ⚠️ 本页是二级路由页：搬槽位后系统侧滑返回 / 返回键需真机回归（§9.3 注记）。
 */
const SUBPOST_OFFICIAL_TITLE_BAR: boolean = true;
/**
 * 官方标题栏高度：与改造前悬浮顶栏几何逐项一致 —— 44(状态栏让位) + 44(钮/胶囊行高) + 10(底部呼吸) = 98。
 * Scroll 首项占位（98）与之同值，保持原值不变。
 */
const SUBPOST_TITLE_BAR_HEIGHT: number = 98;

/**
 * 内容卡片圆角（vp）：父楼层卡与楼中楼回复卡统一 26（2026-09-11 用户指定）。
 * 改动前分别是 Radius.lg(16) / Radius.md(12)，其余几何（宽高、间距、内边距）一行未改。
 * 链接跳转确认弹窗卡片沿用工程「居中确认卡」统一规范 32vp，不在本常量管辖范围。
 */
const SUBPOST_CARD_RADIUS: number = 26;

/**
 * 滚动区底部留白：维持改造前的原值 Spacing.xl(20)（滚动内容 Column 的 padding.bottom）。
 * 历史：2026-09-11 曾按「与帖子详细页一致」改为 160、再降到 96，用户真机查看后要求回退初始值，
 * 现完全复原（无专属常量，直接用 Spacing.xl）。
 */

@Entry
@Component
struct SubPostDetail {
  @State tid: string = '';
  @State parentPid: string = '';
  @State parentFloor: number = 0;
  @State forumId: string = '';
  @State forumName: string = '';
  @State detail: SubPostDetailModel | null = null;
  @State commentsState: CommentItem[] = [];
  @State loadState: LoadState = LoadState.Loading;
  @State errorMsg: string = '';
  @State isDark: boolean = isDarkMode();
  @State loading: boolean = false;
  // API26+ 真机沉浸光感：materialSupported 为 true 时 build 走官方 Navigation 标题栏槽位
  // （返回钮 / 吧名胶囊吃 systemMaterial）；其余环境走原自绘悬浮顶栏兜底。
  @State materialSupported: boolean = false;
  @StorageLink('fontScale') fontScale: number = 1.0;
  /** 页面可见时自增，强制组件重建使字号实时生效 */
  @State fontSizeTick: number = 0;
  // ===== 消息通知精准定位：目标楼中楼（回复我的人 + 回复内容）=====
  @State notifyReplyerId: string = '';
  @State notifyReplyerName: string = '';
  @State notifyContent: string = '';
  /** 通知消息的评论 pid（replyme post_id），楼中楼评论列表按 commentId 精确匹配定位 */
  @State notifyCommentPid: string = '';
  /** 命中高亮的楼中楼 commentId（高亮短暂闪烁后自动清除） */
  @State highlightCommentId: string = '';
  /** 定位翻页进行中标记，防重入 */
  private locatingNotify: boolean = false;
  private scroller: Scroller = new Scroller();

  onPageShow(): void {
    this.fontSizeTick++;
  }
  @State readyEmojiUrls: string[] = [];
  @State failedEmojiUrls: string[] = [];
  @State pendingLinkUrl: string = '';
  @State showLinkDialog: boolean = false;

  private hasReadyEmoji(url: string): boolean {
    return EmojiLoader.has(url) || (this.readyEmojiUrls.indexOf(url) !== -1);
  }
  private hasFailedEmoji(url: string): boolean {
    return this.failedEmojiUrls.indexOf(url) !== -1;
  }
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

  aboutToAppear(): void {
    MaterialManager.init();
    this.materialSupported = MaterialManager.isSupported() && MaterialManager.getApiLevel() >= 26;
    const params = this.getUIContext().getRouter().getParams() as Record<string, Object>;
    if (params) {
      this.tid = `${params.tid ?? ''}`.trim();
      this.parentPid = `${params.pid ?? ''}`.trim();
      this.parentFloor = Number(params.floor ?? 0);
      this.forumId = `${params.forumId ?? ''}`.trim();
      this.forumName = `${params.forumName ?? ''}`.trim();
      this.notifyReplyerId = `${params.notifyReplyerId ?? ''}`.trim();
      this.notifyReplyerName = `${params.notifyReplyerName ?? ''}`.trim();
      this.notifyContent = `${params.notifyContent ?? ''}`.trim();
      this.notifyCommentPid = `${params.notifyCommentPid ?? ''}`.trim();
    }
    this.isDark = isDarkMode();
    this.loadSubPosts();
  }

  private async loadSubPosts(): Promise<void> {
    if (this.loading) {
      return;
    }
    if (this.tid.length === 0 || this.parentPid.length === 0) {
      this.loadState = LoadState.Error;
      this.errorMsg = '缺少当前楼层信息，无法加载楼中楼';
      return;
    }
    this.loading = true;
    this.loadState = LoadState.Loading;
    try {
      const result = await TiebaService.getInstance().fetchSubPostDetail(
        this.tid,
        this.parentPid,
        this.forumId,
        this.parentFloor
      );
      this.detail = result;
      this.commentsState = [...result.comments];
      this.loadState = result.comments.length > 0 ? LoadState.Success : LoadState.Empty;
    } catch (e) {
      this.detail = null;
      this.loadState = LoadState.Error;
      this.errorMsg = (e as Error).message ?? '楼中楼加载失败，请稍后重试';
    } finally {
      this.loading = false;
    }
    // 消息通知定位：首屏就绪后查找目标楼中楼，找不到且有多页则自动向后翻页
    if (this.notifyCommentPid.length > 0 ||
      (this.notifyReplyerId.length > 0 && this.notifyContent.length > 0)) {
      this.locateNotifyTarget(1);
    }
  }

  /** 判断某条楼中楼是否是消息通知定位的目标（优先按评论 pid 精确匹配，其次回复者 id + 内容完全一致） */
  private isNotifyTarget(comment: CommentItem): boolean {
    if (this.notifyCommentPid.length > 0) {
      return `${comment.commentId ?? ''}`.trim() === this.notifyCommentPid;
    }
    const replyerId: string = `${comment.authorId ?? ''}`.trim();
    const content: string = `${comment.content ?? ''}`.trim();
    return replyerId === this.notifyReplyerId && content === this.notifyContent;
  }

  /** 目标楼中楼定位：已加载页未命中且 hasMore 时继续翻页，最多额外翻 6 页防失控 */
  private async locateNotifyTarget(page: number): Promise<void> {
    if (this.locatingNotify) {
      return;
    }
    this.locatingNotify = true;
    try {
      let hasMore: boolean = true;
      let guard: number = 0;
      while (hasMore && guard < 6) {
        guard++;
        let found: CommentItem | null = null;
        for (const comment of this.commentsState) {
          if (this.isNotifyTarget(comment)) {
            found = comment;
            break;
          }
        }
        if (found) {
          this.flashHighlightComment(found.commentId);
          return;
        }
        const cur: SubPostDetailModel | null = this.detail;
        if (!cur || !cur.hasMore) {
          return;
        }
        const nextPage: number = page + guard;
        const more = await TiebaService.getInstance().fetchSubPostDetail(
          this.tid, this.parentPid, this.forumId, this.parentFloor, nextPage
        );
        if (more.comments.length === 0) {
          return;
        }
        // 追加并同步 detail（确保后续 hasMore 状态正确）
        this.detail = {
          tid: cur.tid,
          floorId: cur.floorId,
          floor: cur.floor,
          parent: cur.parent,
          comments: [...cur.comments, ...more.comments],
          total: more.total,
          hasMore: more.hasMore
        };
        this.commentsState = [...this.commentsState, ...more.comments];
        hasMore = more.hasMore;
      }
    } catch (e) {
      // 定位翻页失败（风控/网络）：静默，用户仍停留在正确的楼中楼列表，可手动翻找
    } finally {
      this.locatingNotify = false;
    }
  }

  /** 高亮目标楼中楼并滚动到可视位置，短暂闪烁后清除 */
  private flashHighlightComment(commentId: string): void {
    this.highlightCommentId = commentId;
    setTimeout(() => {
      try {
        const uiUtils = this.getUIContext().getComponentUtils();
        const targetRect = uiUtils.getRectangleById('spc_' + commentId);
        const scrollRect = uiUtils.getRectangleById('subpost_scroll_content');
        if (!targetRect || !scrollRect) {
          return;
        }
        const currentY = this.scroller.currentOffset().yOffset;
        const targetY = targetRect.windowOffset.y - scrollRect.windowOffset.y + currentY;
        // 上移一段让卡片出现在悬浮顶栏下方
        this.scroller.scrollTo({ xOffset: 0, yOffset: Math.max(0, targetY - 120), animation: true });
      } catch (e) {
        // 部分 SDK 版本缺少 getComponentUtils，静默降级
      }
    }, 260);
    setTimeout(() => {
      if (this.highlightCommentId === commentId) {
        this.highlightCommentId = '';
      }
    }, 2600);
  }

  build() {
    if (SUBPOST_OFFICIAL_TITLE_BAR && this.materialSupported) {
      // 官方槽位路径：Navigation + 自定义 title（height 固定 98，与改造前悬浮顶栏几何一致）
      // barStyle STACK：内容区延伸到标题栏之下（官方建议，标题栏材质获得最佳沉浸体验的前提）
      // backgroundColor 显式透明：避免标题栏自带底色压住滚动经过的内容
      Navigation() {
        this.SubPostContent()
      }
      .title({ builder: this.SubPostTitleBar(), height: SUBPOST_TITLE_BAR_HEIGHT },
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
      // 兜底路径：改造前原样（页面主体悬浮 LegacyTopBar + backgroundEffect 真磨砂）
      this.SubPostContent()
    }
  }

  /** 页面主体（改造前 build() 根 Stack 原样搬入；悬浮顶栏仅在官方槽位不可用时挂载） */
  @Builder
  SubPostContent() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.loadState === LoadState.Loading) {
        LoadingView({ message: '正在加载楼中楼...' }).layoutWeight(1)
      } else if (this.loadState === LoadState.Error) {
        ErrorView({ message: this.errorMsg, onRetry: () => { this.loadSubPosts(); } }).layoutWeight(1)
      } else if (this.loadState === LoadState.Empty) {
        EmptyView({ message: '当前楼层暂无楼中楼回复', icon: '○' }).layoutWeight(1)
      } else if (this.detail) {
        Scroll(this.scroller) {
          Column({ space: Spacing.md }) {
            // 预留顶栏高度作为初始间距
            Column().width('100%').height(98)
            this.ParentFloor(this.detail!.parent)
            Text(`${this.detail!.total} 条楼中楼回复`)
              .fontSize(fs(15, this.fontScale))
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.textPrimary(this.isDark))
              .width('100%')
              .padding({ left: 4, right: 4, top: 4, bottom: 0 })
            this.CommentItems()
          }
          .width('100%')
          .id('subpost_scroll_content')
          .padding({ left: Spacing.lg, right: Spacing.lg, top: 0, bottom: Spacing.xl })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .clip(false)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .overlay(this.BottomFadeOverlay())
        .blendMode(BlendMode.SRC_OVER, BlendApplyType.OFFSCREEN)
      }

      // 悬浮顶栏（内容可穿过）；官方 title 槽位路径下两元素已在槽位里（SubPostTitleBar），这里不再叠一层
      if (!(SUBPOST_OFFICIAL_TITLE_BAR && this.materialSupported)) {
        this.LegacyTopBar()
      }

      // 链接跳转确认浮层（沉浸光感卡片，风格与收藏页确认弹窗一致）
      if (this.showLinkDialog) {
        this.LinkConfirmDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg(this.isDark))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  /**
   * 官方槽位标题栏：整行搬进 Navigation 的 title 槽位，几何与「帖子详细页」DetailTitleBar 逐项一致
   * （外层高 98 / padding top 44 + bottom 10 + 左右 Spacing.lg、Row 高 44、吧名胶囊 58% 宽 + 44 高 +
   * 左右 padding 16 + 居中），只把玻璃从自绘换成官方沉浸材质：
   * - 返回钮 / 吧名胶囊 → ImmMaterial.seg(false)（THIN 中性档，与帖子详细页顶栏同一套材质语言）；
   * - 两处都显式 backgroundColor(Color.Transparent)：Button 自带品牌蓝默认填充，不清底会透出蓝底；
   * - 不挂 border / backgroundBlurStyle / shadow：官方明确不建议与 systemMaterial 同用（会互相覆盖）；
   * - 图标/文字色沿用系统可反色资源（icon_primary / font_primary），满足官方自动反色前提。
   */
  @Builder
  SubPostTitleBar() {
    Stack() {
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontColor([$r('sys.color.icon_primary')])
            .fontSize(fs(24, this.fontScale))
        }
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .systemMaterial(ImmMaterial.seg(false))
        .borderRadius(Radius.full)
        .onClick(() => { this.goBack(); })
        Blank()
      }
      .width('100%')
      .height(44)
      .align(Alignment.Start)
      Button() {
        Text(`${this.forumName || '楼中楼'}${this.forumName.length > 0 ? '吧' : ''}`)
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
      .accessibilityText('楼中楼所在吧')
    }
    .width('100%')
    .height(SUBPOST_TITLE_BAR_HEIGHT)
    .padding({ left: Spacing.lg, right: Spacing.lg, top: 44, bottom: 10 })
    .backgroundColor(Color.Transparent)
  }

  /**
   * 兜底路径顶栏（改造前原样）：页面主体悬浮层（内容可穿过）+ 透明底 + backgroundEffect 真模糊磨砂。
   * 仅在官方 title 槽位不可用时挂载（见 SubPostContent 的条件挂载）。
   */
  @Builder
  LegacyTopBar() {
    Row() {
      Button() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontColor([$r('sys.color.icon_primary')])
          .fontSize(fs(24, this.fontScale))
      }
      .width(44)
      .height(44)
      .backgroundColor(Color.Transparent)
      .shadow(Theme.glassShadowStyle()).backgroundEffect(ImmBlur.control())
      .systemMaterial(ImmMaterial.control())
      .borderRadius(Radius.full)
      .onClick(() => { this.goBack(); })

      Text(`${this.forumName || '楼中楼'}${this.forumName.length > 0 ? '吧' : ''}`)
        .fontSize(fs(16, this.fontScale))
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.textPrimary(this.isDark))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .layoutWeight(1)

      Blank()
        .width(44)
        .height(44)
    }
    .width('100%')
    .height(98)
    .padding({ left: Spacing.lg, right: Spacing.lg, top: 44, bottom: 10 })
    .backgroundColor(Color.Transparent)
  }

  @Builder
  ParentFloor(floor: FloorItem) {
    Column({ space: Spacing.sm }) {
      Row({ space: Spacing.sm }) {
        this.Avatar(floor.authorAvatar ?? '', floor.author, 38, floor.authorId ?? '')
        Column({ space: 2 }) {
          Text(floor.author || '贴吧用户')
            .fontSize(fs(14, this.fontScale))
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.textPrimary(this.isDark))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .onClick(() => {
              this.openUserProfile(floor.authorId ?? '', floor.author);
            })
          Text(`第 ${floor.floor} 楼`)
            .fontSize(fs(12, this.fontScale))
            .fontColor(Theme.brand())
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      this.RichTextContent(floor.fragments ?? [], floor.contentText || '（该楼层无文字内容）', fs(16), Theme.textPrimary(this.isDark), 26)
      if (floor.images.length > 0) {
        this.ImageGrid(floor.images)
      }
    }
    .width('100%')
    .padding(Spacing.lg)
    .backgroundColor(Theme.bgCard(this.isDark))
    .borderRadius(SUBPOST_CARD_RADIUS)
  }

  @Builder
  CommentItems() {
    Column({ space: 8 }) {
      ForEach(this.commentsState, (comment: CommentItem, commentIndex: number) => {
        Column() {
          Stack({ alignContent: Alignment.TopEnd }) {
            Row({ space: Spacing.sm }) {
              this.Avatar(comment.authorAvatar ?? '', comment.author, 32, comment.authorId ?? '')
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
                // 正文
                this.RichTextContent(comment.fragments ?? [], comment.content || '（无文字内容）', fs(16), Theme.textPrimary(this.isDark), 26)
                if ((comment.images ?? []).length > 0) {
                  this.ImageGrid(comment.images ?? [])
                }
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
            // 楼中楼点赞按钮：浮在右上角、不占行内宽度，使正文右边缘延伸到卡片右 padding 内缘
            // （与 ThreadDetail 楼中楼预览一致的悬浮方式，确保回复内容行右边界与上方爱心行右边界对齐到同一长度）
            Button({ type: ButtonType.Circle }) {
              Row({ space: 3 }) {
                SymbolGlyph($r('sys.symbol.heart'))
                  .fontSize(fs(18, this.fontScale))
                  .fontColor([(comment.isLiked ?? false) ? $r('sys.color.icon_emphasize') : $r('sys.color.icon_secondary')])
                  .renderingStrategy(SymbolRenderingStrategy.SINGLE)
                  .hitTestBehavior(HitTestMode.None)
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
            .onClick(() => {
              this.toggleCommentLike(comment);
            })
          }
          .width('100%')
          // 右 padding 与父楼层内容右边缘对齐，左 padding 保持不变
          .padding({ left: Spacing.md, right: Spacing.lg, top: Spacing.md, bottom: Spacing.md })
          .backgroundColor(this.highlightCommentId === comment.commentId
            ? (this.isDark ? '#3C3C3C' : '#E4E4E4')
            : Theme.bgCard(this.isDark))
          .borderRadius(SUBPOST_CARD_RADIUS)
          // 评论间距：非最后一条时追加 Spacing.sm 视觉区分
          if ((commentIndex ?? 0) < this.commentsState.length - 1) {
            Column() { }
              .width('100%')
              .height(Spacing.sm)
          }
        }
        .id('spc_' + comment.commentId)
        .width('100%')
      }, (comment: CommentItem, commentIndex: number) => `${comment.commentId}_${comment.isLiked ? 1 : 0}_${comment.likeCount ?? 0}_${commentIndex ?? 0}`)
    }
    .width('100%')
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
        Image(url.trim())
          .width(size)
          .height(size)
          .borderRadius(Radius.full)
          .objectFit(ImageFit.Cover)
          .alt((author.trim().length > 0 ? author : '吧').substring(0, 1))
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

  private collectAllImages(): string[] {
    const all: string[] = [];
    if (this.detail && this.detail.parent && this.detail.parent.images && this.detail.parent.images.length > 0) {
      all.push(...this.detail.parent.images);
    }
    if (this.detail && this.detail.comments) {
      for (const comment of this.detail.comments) {
        if (comment.images && comment.images.length > 0) {
          all.push(...comment.images);
        }
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

  @Builder
  ImageGrid(images: string[]) {
    Grid() {
      ForEach(images, (img: string, idx: number) => {
        GridItem() {
          Stack() {
            Image(img)
              .width('100%')
              .height(120)
              .borderRadius(Radius.md)
              .objectFit(ImageFit.Cover)
          }
          .width('100%')
          .height(120)
          .onClick(() => {
            const allImages = this.collectAllImages();
            const offset = this.getImageGlobalOffset(images);
            this.getUIContext().getRouter().pushUrl({
              url: 'pages/ImagePreview',
              params: { urls: allImages, index: offset + idx }
            }).catch(() => {
              this.getUIContext().getPromptAction().showToast({ message: '图片预览打开失败，请稍后重试' });
            });
          })
        }
      }, (img: string, idx: number) => `${img}_${idx}`)
    }
    .columnsTemplate('1fr 1fr 1fr')
    .columnsGap(6)
    .rowsGap(6)
    .width('100%')
  }

  @Builder
  RichTextContent(fragments: ContentFragment[], fallbackText: string, fontSize: number, fontColor: ResourceColor, lineHeightVal: number) {
    Column() {
      if (fragments && fragments.length > 0) {
        // 通过 EmojiLoader HTTP + Referer/UA 防盗链下载→PixelMap，完成后 readyEmojiUrls 触发重绘
        ForEach(this.uniqueEmojiUrls(fragments), (emojiUrl: string) => {
          Blank()
            .width(0)
            .height(0)
            .onAppear(() => this.prefetchEmojisWithLoader([emojiUrl]))
        }, (u: string) => u)
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
      } else {
        Text(fallbackText)
          .fontSize(fontSize)
          .fontColor(fontColor)
          .lineHeight(lineHeightVal)
          .width('100%')
      }
    }
    .width('100%')
  }

  // ===== 链接跳转确认（点击楼中楼内容中的链接）=====
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
      .width('calc(100% - 48vp)')
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

  // 点赞请求进行中标志：防止连点产生"点赞→立即取消"连环请求（贴吧对该模式限流，报 3280001）
  private likeInFlight: boolean = false;

  private async toggleCommentLike(comment: CommentItem): Promise<void> {
    if (this.likeInFlight) {
      return;
    }
    this.likeInFlight = true;
    try {
      await this.doToggleCommentLike(comment);
    } finally {
      this.likeInFlight = false;
    }
  }

  private async doToggleCommentLike(comment: CommentItem): Promise<void> {
    const previous: boolean = comment.isLiked ?? false;
    const next: boolean = !previous;
    const commentId = comment.commentId;
    // 防御：数据缺失真实 id（commentId 形如 "xxx-comment-y" 的合成值）时无法点赞
    if (!/^\d+$/.test(commentId)) {
      this.getUIContext().getPromptAction().showToast({ message: '该回复暂时无法点赞' });
      return;
    }

    this.commentsState = this.commentsState.map((c: CommentItem): CommentItem => {
      if (c.commentId === commentId) {
        const currentCount = c.likeCount ?? 0;
        return {
          commentId: c.commentId,
          author: c.author,
          authorAvatar: c.authorAvatar,
          authorId: c.authorId,
          parentPostId: c.parentPostId,
          content: c.content,
          images: c.images,
          fragments: c.fragments,
          createTime: c.createTime,
          isLiked: next,
          likeCount: currentCount + (next ? 1 : -1),
          level: c.level,
          isAuthor: c.isAuthor,
        };
      }
      return c;
    });

    try {
      await TiebaService.getInstance().togglePostAgree(this.tid, commentId, next, 2);
    } catch (e) {
      this.commentsState = this.commentsState.map((c: CommentItem): CommentItem => {
        if (c.commentId === commentId) {
          const currentCount = c.likeCount ?? 0;
          return {
          commentId: c.commentId,
          author: c.author,
          authorAvatar: c.authorAvatar,
          authorId: c.authorId,
          parentPostId: c.parentPostId,
          content: c.content,
          images: c.images,
          fragments: c.fragments,
          createTime: c.createTime,
          isLiked: previous,
          likeCount: currentCount + (next ? -1 : 1),
          level: c.level,
          isAuthor: c.isAuthor,
        };
        }
        return c;
      });
      const msg = (e as Error).message ?? '操作失败';
      this.getUIContext().getPromptAction().showToast({ message: msg });
    }
  }

  private formatFloorTime(time: string): string {
    if (!time || time.length === 0) return '';
    if (/^\d{1,2}-\d{1,2}\s+\d{1,2}:\d{2}$/.test(time)) return time;
    const match = time.match(/(\d{1,2}-\d{1,2})[ T](\d{1,2}:\d{2})/);
    if (match) return `${match[1]} ${match[2]}`;
    return time;
  }

  private goBack(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({ message: '返回失败，请稍后重试' });
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
