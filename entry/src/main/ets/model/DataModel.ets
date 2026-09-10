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

/**
 * 贴吧核心数据模型
 */

// 富文本碎片类型
export enum ContentFragmentType {
  TEXT = 0,
  EMOJI = 1,
  IMAGE = 2,
  LINK = 3,
}

// 富文本碎片（用于内联表情包渲染）
export interface ContentFragment {
  type: ContentFragmentType;
  text: string;
  imageUrl?: string;
  link?: string;   // LINK 类型：真实跳转 URL
}

// buildFragments 返回结果
export interface FragmentsResult {
  fragments: ContentFragment[];
  text: string;
  images: string[];
}

// 帖子列表项
export interface ThreadItem {
  tid: string;          // 帖子 ID
  postId?: string;      // 首个楼层ID，用于点赞
  forumId?: string;     // 所属吧 ID
  title: string;        // 标题
  forumName: string;    // 所属吧名
  forumAvatar?: string; // 所属吧头像 URL
  author: string;       // 楼主昵称
  authorId?: string;    // 楼主用户 ID（用于详情页昵称回填校准）
  authorAvatar?: string; // 楼主头像 URL
  authorNameShowMissing?: boolean; // 接口 name_show 为占位/缺失（显示名可能只是用户名回退），需 profile 昵称校准
  replyNum: number;     // 回复数
  likeCount?: number;   // 点赞数
  isLiked?: boolean;    // 是否已点赞
  abstract: string;     // 摘要/首楼内容
  firstImage?: string;  // 首图
  images?: string[];    // 帖子图片列表
  createTime: string;   // 发布时间
  isTop: boolean;       // 是否置顶
  isGood?: boolean;     // 是否精选/精品
  isFeatured?: boolean; // 精选兼容字段
}

// 帖子详情
export interface ThreadDetail {
  tid: string;
  postId?: string;
  forumId?: string;
  forumAvatar?: string;
  title: string;
  forumName: string;
  author: string;
  authorAvatar?: string;
  authorId?: string;
  content: string;          // 楼主正文（HTML）
  contentText: string;      // 纯文本
  images: string[];         // 正文图片
  fragments?: ContentFragment[];
  replyNum: number;
  likeCount?: number;
  isLiked?: boolean;
  isCollected?: boolean;
  createTime: string;
  level?: number;        // 楼主吧内等级（pb 协议真实值）
  page: number;
  totalPage: number;
}

// 楼层（回帖）
export interface FloorItem {
  floorId: string;
  floor: number;        // 楼层号
  author: string;
  authorAvatar?: string;
  authorId?: string;
  contentText: string;
  images: string[];
  fragments?: ContentFragment[];
  createTime: string;
  isAuthor: boolean;    // 是否楼主
  comments?: CommentItem[];
  likeCount?: number;
  isLiked?: boolean;
  commentsTotal?: number;
  commentsHasMore?: boolean;
  level?: number;       // 用户等级
  ipLocation?: string;  // IP属地
}

// 评论（楼层下的回复）
export interface CommentItem {
  commentId: string;
  author: string;
  authorAvatar?: string;
  authorId?: string;
  parentPostId?: string;
  replyToId?: string;
  content: string;
  images?: string[];
  fragments?: ContentFragment[];
  floor?: number;
  createTime: string;
  isAuthor?: boolean;
  level?: number;
  likeCount?: number;
  isLiked?: boolean;
}

// 单个主楼的楼中楼详情
export interface SubPostDetail {
  tid: string;
  floorId: string;
  floor: number;
  parent: FloorItem;
  comments: CommentItem[];
  total: number;
  hasMore: boolean;
}

// 关注列表项
export interface FollowItem {
  forumId?: string;
  forumName: string;
  level: number;        // 等级
  exp: number;
  isSign: boolean;      // 是否已签到
  memberCount: string;
  avatar?: string;      // 吧头像 URL
  hotValue?: string;    // 热度值（如 "7.3W"）
}

// 私信会话
export interface Conversation {
  userId: string;
  name: string;
  avatar?: string;
  lastMessage: string;
  lastTime: string;
  unreadCount: number;
}

// 私信消息
export interface MessageItem {
  id: string;
  fromMe: boolean;
  content: string;
  time: string;
}

// 消息通知（回复我的 / 提到我的）
export interface NotifyUser {
  id: string;
  name: string;
  nameShow: string;
  avatar: string; // 完整头像 URL
}

export interface NotifyMessage {
  id: string;        // 唯一标识（postId）
  type: 'reply' | 'at';
  title: string;     // 帖子标题
  content: string;   // 回复 / @ 内容
  quoteContent: string; // 引用的原楼层内容
  time: string;      // 时间字符串
  threadId: string;  // tid
  postId: string;    // 楼层 pid
  quotePid: string;  // 被引用楼层 pid
  forumName: string; // 吧名
  isFloor: boolean;  // 是否楼层
  unread: boolean;   // 是否未读
  replyer: NotifyUser;
  quoteUser?: NotifyUser;
}

// 登录用户信息
export interface UserInfo {
  userId: string;
  name: string;
  avatar?: string;
  isLogin: boolean;
}

// 当前用户个人页统计
export interface UserStats {
  postCount: number;
  agreeCount: number;
}

export interface PersonalContentItem {
  id: string;
  tid: string;
  title: string;
  forumName: string;
  forumId?: string;
  forumAvatar?: string;
  author: string;
  authorId?: string;
  abstract: string;
  replyNum: number;
  createTime: string;
  accountId?: string;
  /** 帖子图片（CDN 链接，从 proto 内容段提取，用于关注动态宫格展示） */
  images?: string[];
}

/** 作者昵称校准的目标结构（authorId + 当前显示名） */
export interface AuthorEnrichTarget {
  authorId?: string;
  author: string;
}

// 收藏模块 - 置顶记录（Preferences 存储，id = forumName 或 tid）
export interface PinRecord {
  id: string;
  pinnedAt: number;   // 置顶时间戳（ms）
}

// 收藏模块 - 吧分类收纳夹（聚合主键 forumName，threadstore 未返回 fid）
export interface FolderItem {
  forumName: string;
  avatarUrl: string;    // 吧头像（1:1），空串走首字占位
  threadCount: number;  // 该吧下已加载的收藏帖数量
  pinned: boolean;      // 本地置顶标记
  pinnedAt: number;     // 置顶时间戳（ms）
}

// 收藏模块 - 帖子卡片（骨架阶段字段；threadstore 无 collect_time/forum_id/图片字段）
export interface PostCardItem {
  tid: string;
  pid: string;
  title: string;
  abstract: string;
  forumName: string;
  author: string;
  replyNum: number;
  coverUrl: string;     // 首楼图 URL（当前数据源无图字段，恒空 → 不渲染图片位）
  lastTime: number;     // last_time（秒级时间戳），排序/时间展示用
  pinned: boolean;      // 本地置顶标记
  pinnedAt: number;     // 置顶时间戳（ms）
  orderIndex: number;   // 接口原始顺序下标（排序降级：倒序=接口序，正序=反转）
}

// 收藏模块 - 自定义分类（Preferences 存储，id='default' 为内置「未分类」）
export interface FavCategory {
  id: string;
  name: string;
  icon: string;        // 表情图标（Text 渲染，无封面时兜底展示）
  sortOrder: number;   // 排序（内置 default 恒为 0）
  createdAt: number;   // 创建时间戳（ms）
  cover: string;       // 封面图沙箱路径（空串 = 无封面，走 icon/首字兜底；v1.8 新增）
}

// 收藏模块 - 帖↔分类映射（一帖可同时在多个自定义分类，§4.2；"未分类"无映射记录，由 UI 推导）
export interface CategoryMapping {
  tid: string;
  categoryId: string;
  forumName: string;
  addedAt: number;     // 移入时间戳（ms）
}

// 黑名单模块 - 拉黑用户条目（接口字段待批 A 抓包确认；blackTime 无字段时为 0）
export interface BlacklistItem {
  userId: string;      // 对方 uid
  name: string;        // 昵称（无昵称用 ID）
  avatar: string;      // 头像 URL（空串走首字占位）
  blackTime: number;   // 拉黑时间戳（ms；接口无该字段时为 0，时间排序降级）
  // 精细化屏蔽开关（新版 userBlackPage 接口返回；老 userMuteQuery 无此字段，undefined 走默认全开）
  blockFollow?: boolean;   // 禁止关注
  blockInteract?: boolean; // 禁止互动
  blockChat?: boolean;     // 禁止私信
}

// 用户主页模块 - 用户完整资料（v1.12 · 批 C；字段以批 A 抓包实测为准）
export interface UserProfileModel {
  userId: string;        // 对方 uid
  name: string;          // 昵称（无有效昵称用用户名/占位名）
  avatar: string;        // 头像 URL（空串走首字占位）
  portrait: string;      // 原始 portrait hash（关注/取关接口用，空串时降级 uid）
  intro: string;         // 简介（空则隐藏该行）
  sex: number;           // 性别：0 未知/保密、1 男、2 女（无字段隐藏该行）
  ip: string;            // IP 归属地（空则隐藏该行）
  fansNum: number;       // 粉丝数
  concernNum: number;    // 关注数
  agreeNum: number;      // 获赞数
  postCount: number;     // 发帖数（主题帖）
  isFollowed: boolean;   // 我是否已关注对方（本人主页恒 false）
}

// 用户主页模块 - 用户关注的吧（v1.12 · 批 C；接口地址与字段待批 A 抓包确认）
export interface UserLikeItem {
  forumId: string;       // 吧 ID
  forumName: string;     // 吧名
  avatar: string;        // 吧头像（空串走首字占位）
  postCount: number;     // 主题帖数
  intro: string;         // 吧简介/描述（空则隐藏）
}

// 关注列表模块 - 我关注的用户（v1.13 · 批 C；接口地址与字段待批 A 抓包确认）
export interface FollowUserItem {
  userId: string;        // 对方 uid
  name: string;          // 昵称（无昵称用用户名/占位名）
  avatar: string;        // 头像 URL（空串走首字占位）
  portrait: string;      // 原始 portrait hash（关注/取关接口用）
  intro: string;         // 个性签名（空则副行仅显示来源）
  isFriend: boolean;     // 是否互相关注（is_friend === 1）
  followTime: number;    // 关注时间戳（ms；接口无该字段时为 0，时间排序降级）
}

// 通用分页响应
export interface PagedResult<T> {
  list: T[];
  hasMore: boolean;
  page: number;
}

// 关注列表分页响应（v1.13：含关注总数，供副标题「共关注 N 个吧友」）
export interface FollowListResult extends PagedResult<FollowUserItem> {
  total: number;
}

// ================= 全吧搜索（搜吧/搜贴/搜人 · PC 网页接口） =================

// 全吧搜索 - 搜吧：单个吧结果（推荐位 exactMatch 与相关吧 fuzzyMatch 共用）
export interface GlobalForumResult {
  forumId: string;        // 吧 ID
  forumName: string;      // 吧名
  forumNameShow: string;  // 显示名（一般同吧名）
  avatar: string;         // 吧头像 URL（空串走首字占位）
  memberNumShow: string;  // 展示成员数（如 3.1W，服务端已格式化；空则 UI 按 memberNum 兜底）
  memberNum: number;      // 原始成员数
  postNumShow: string;    // 展示帖子数（如 21.1W）
  postNum: number;        // 原始帖子数
  slogan: string;         // 吧标语（推荐位才有，相关吧为空）
  intro: string;          // 吧简介（推荐位才有）
  hasConcerned: boolean;  // 当前账号是否已关注
  isOfficial: boolean;    // 是否官方吧
}

export interface GlobalForumSearchData {
  exact: GlobalForumResult | null; // 推荐位（完全匹配的吧），可能为空
  list: GlobalForumResult[];       // 相关吧列表
  hasMore: boolean;
  page: number;
}

// 全吧搜索 - 搜贴：单条帖子结果
export interface GlobalPostResult {
  tid: string;            // 帖子 ID
  pid: string;            // 楼层 ID
  forumId: string;        // 所属吧 ID
  forumName: string;      // 所属吧名
  forumAvatar: string;    // 所属吧头像
  title: string;          // 标题
  content: string;        // 内容片段
  createTime: number;     // 秒级时间戳
  replyNum: number;       // 该帖回复数
  authorId: string;       // 楼主用户 ID
  authorName: string;     // 楼主用户名
  authorShowName: string; // 楼主显示昵称
  authorAvatar: string;   // 楼主头像
}

export interface GlobalPostSearchData {
  list: GlobalPostResult[];
  hasMore: boolean;
  page: number;
}

// 吧内搜索（服务端 /c/s/searchpost，TiebaLite 同款端点）：服务端直接返回命中帖子
export interface ForumSearchData {
  list: ThreadItem[];   // 命中帖子（服务端已按关键词匹配，含正文命中，本地不再过滤）
  hasMore: boolean;     // 是否还有下一页
  page: number;         // 当前页码（从 1 起）
  total: number;        // 命中总数（服务端未返回时为 0，表示未知）
}

// 全吧搜索 - 搜人：单个用户结果（推荐位 exactMatch 与相关吧 fuzzyMatch 共用）
export interface GlobalUserResult {
  userId: string;         // 用户 ID
  userName: string;       // 用户名
  userNickname: string;   // 昵称字段
  showName: string;       // 显示名（UI 主展示）
  avatar: string;         // 头像 URL（空串走首字占位）
  intro: string;          // 个性签名
  fansNum: number;        // 粉丝数
  hasConcerned: boolean;  // 是否已关注
}

export interface GlobalUserSearchData {
  exact: GlobalUserResult | null; // 推荐位（完全匹配的用户）
  list: GlobalUserResult[];       // 其他用户
  hasMore: boolean;
  page: number;
}

// 网页端写操作结果
export interface PublishResult {
  success: boolean;
  message: string;
  tid?: string;
}

// 吧主页头部信息
export interface ForumHeaderInfo {
  forumId: string;
  forumName: string;
  avatar: string;
  bannerUrl?: string;
  slogan: string;
  memberCount: number;
  threadCount: number;
  postCount: number;
  userLevel: number;
  levelName: string;
  curScore: number;
  levelupScore: number;
  isLike: boolean;
  hasFrsStar: boolean;
}
