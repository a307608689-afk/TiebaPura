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
 * TiebaLite 4.0-dev response schema translated from the original .proto files.
 * Field numbers are preserved for binary decoding compatibility.
 */

export enum ProtoWireType {
  Varint = 0,
  Fixed64 = 1,
  LengthDelimited = 2,
  Fixed32 = 5,
}

export interface ProtoFieldValue {
  field: number;
  wireType: number;
  value: number | string | ArrayBuffer;
}

export interface AbstractMessage {
  type?: number;
  text?: string;
  link?: string;
  src?: string;
  un?: string;
  duringTime?: string;
  voiceMD5?: string;
}

export interface MediaMessage {
  type?: number;
  bigPic?: string;
  srcPic?: string;
  width?: number;
  height?: number;
  originPic?: string;
  originSize?: number;
  postId?: number;
  dynamicPic?: string;
  isLongPic?: number;
  showOriginalBtn?: number;
}

export interface MemeInfoMessage {
  pckId?: number;
  picId?: number;
  picUrl?: string;
  thumbnail?: string;
  width?: number;
  height?: number;
  detailLink?: string;
}

export interface PbContentMessage {
  type?: number;
  text?: string;
  link?: string;
  src?: string;
  bsize?: string;
  bigSrc?: string;
  bigSize?: string;
  cdnSrc?: string;
  bigCdnSrc?: string;
  imgType?: string;
  c?: string;
  voiceMD5?: string;
  duringTime?: number;
  uid?: number;
  dynamic?: string;
  staticValue?: string;
  width?: number;
  height?: number;
  originSrc?: string;
  originSize?: number;
  mediaSubtitle?: string;
  urlType?: number;
  memeInfo?: MemeInfoMessage;
  isLongPic?: number;
  showOriginalBtn?: number;
  cdnSrcActive?: string;
}

export interface AgreeMessage {
  agreeNum?: number;
  hasAgree?: number;
  agreeType?: number;
  disagreeNum?: number;
  diffAgreeNum?: number;
}

export interface IconMessage {
  name?: string;
  weight?: number;
  url?: string;
  icon?: string;
  value?: number;
  terminal?: TerminalMessage;
  position?: PositionMessage;
  spriteInfo?: string[];
}

export interface TerminalMessage {
  pc?: number;
  wap?: number;
  client?: number;
}

export interface PositionMessage {
  frs?: number;
  pb?: number;
  home?: number;
  card?: number;
}

export interface UserPicsMessage {
  big?: string;
  small?: string;
}

export interface PrivSetsMessage {
  like?: number;
  group?: number;
  post?: number;
  live?: number;
}

export interface LikeForumInfoMessage {
  forumName?: string;
  forumId?: number;
}

export interface SimpleUserMessage {
  userId?: number;
  userStatus?: number;
  secureemail?: string;
  securemobil?: string;
  userName?: string;
  userNickname?: string;
  incompleteUser?: number;
  portrait?: string;
  agreeType?: number;
  aheadUrl?: string;
  blockMsg?: string;
  showOnlyme?: number;
}

export interface GodInfoMessage {
  level?: number;
  name?: string;
  desc?: string;
}

export interface NewGodInfoMessage {
  level?: number;
  name?: string;
  icon?: string;
}

export interface BawuThronesMessage {
  throne?: string;
  level?: number;
}

export interface BazhuSignMessage {
  sign?: string;
  time?: number;
}

export interface BirthdayInfoMessage {
  birthday?: string;
  isOpen?: number;
}

export interface SimpleForumMessage {
  id?: number;
  name?: string;
  avatar?: string;
  memberNum?: number;
  postNum?: number;
}

export interface UserMessage {
  isLogin?: number;
  id?: number;
  name?: string;
  nameShow?: string;
  portrait?: string;
  noUn?: number;
  type?: number;
  userhide?: number;
  isManager?: number;
  rank?: string;
  bimgUrl?: string;
  meizhiLevel?: number;
  isVerify?: number;
  isInterestman?: number;
  iconinfo?: IconMessage[];
  userType?: number;
  isCoreuser?: number;
  isHuinibuke?: number;
  iosBimgFormat?: string;
  levelId?: number;
  isLike?: number;
  isBawu?: number;
  bawuType?: string;
  portraith?: string;
  ip?: string;
  BDUSS?: string;
  fansNum?: number;
  concernNum?: number;
  sex?: number;
  myLikeNum?: number;
  intro?: string;
  hasConcerned?: number;
  passwd?: string;
  postNum?: number;
  tbAge?: string;
  isMem?: number;
  bimgEndTime?: number;
  gender?: number;
  isMask?: number;
  userPics?: UserPicsMessage[];
  privSets?: PrivSetsMessage;
  isFriend?: number;
  likeForum?: LikeForumInfoMessage[];
  giftNum?: number;
  isSelectTail?: number;
  isGuanfang?: number;
  bookmarkCount?: number;
  bookmarkNewCount?: number;
  muteUser?: SimpleUserMessage[];
  friendNum?: number;
  fansNickname?: string;
  bgPic?: string;
  godData?: GodInfoMessage;
  heavyUser?: number;
  visitorNum?: number;
  totalVisitorNum?: number;
  nicknameUpdateTime?: number;
  threadNum?: number;
  agreeNum?: number;
  leftCallNum?: number;
  isInvited?: number;
  isFans?: number;
  privThread?: number;
  isVideobiggie?: number;
  isShowRedpacket?: number;
  birthdayInfo?: BirthdayInfoMessage;
  canModifyAvatar?: number;
  modifyAvatarDesc?: string;
  influence?: number;
  levelInfluence?: string;
  newGodData?: NewGodInfoMessage;
  bawuThrones?: BawuThronesMessage;
  bazhuGrade?: BazhuSignMessage;
  isDefaultAvatar?: number;
  favoriteNum?: number;
  totalAgreeNum?: number;
  tiebaUid?: string;
  levelName?: string;
  ipAddress?: string;
  isNicknameEditing?: number;
  editingNickname?: string;
  displayIntro?: string;
  newIconUrl?: string[];
  dynamicUrl?: string;
}

export interface DislikeInfoMessage {
  dislikeReason?: string;
  dislikeId?: number;
  extra?: string;
}

export interface OriginThreadInfoMessage {
  title?: string;
  media?: MediaMessage[];
  abstract?: AbstractMessage[];
  fname?: string;
  tid?: string;
  fid?: number;
  threadType?: number;
  isDeleted?: number;
  isUgc?: number;
  content?: PbContentMessage[];
  replyNum?: number;
  author?: UserMessage;
  agree?: AgreeMessage;
  sharedNum?: number;
  pid?: number;
  goodTypes?: number;
  topTypes?: number;
  isFrsMask?: number;
}

export interface ThreadInfoMessage {
  id?: number;
  threadId?: number;
  title?: string;
  replyNum?: number;
  viewNum?: number;
  lastTime?: string;
  lastTimeInt?: number;
  threadTypes?: number;
  isTop?: number;
  isGood?: number;
  author?: UserMessage;
  lastReplyer?: UserMessage;
  commentNum?: number;
  abstract?: AbstractMessage[];
  media?: MediaMessage[];
  forumId?: number;
  forumName?: string;
  isNoTitle?: number;
  firstPostId?: number;
  createTime?: number;
  collectStatus?: number;
  collectMarkPid?: string;
  postId?: number;
  isMemberTop?: number;
  authorId?: number;
  pids?: string;
  videoInfo?: VideoInfoMessage;
  richTitle?: PbContentMessage[];
  richAbstract?: PbContentMessage[];
  dislikeInfo?: DislikeInfoMessage[];
  agreeNum?: number;
  hasAgree?: number;
  agree?: AgreeMessage;
  shareNum?: number;
  originThreadInfo?: OriginThreadInfoMessage;
  firstPostContent?: PbContentMessage[];
  isShareThread?: number;
  isTopic?: number;
  topicUserName?: string;
  topicH5Url?: string;
  forumInfo?: SimpleForumMessage;
  tShareImg?: string;
  nid?: string;
  tabId?: number;
  tabName?: string;
  isDeleted?: number;
  hotNum?: number;
}

export interface VideoInfoMessage {
  videoMD5?: string;
  videoUrl?: string;
  videoDuration?: number;
  videoWidth?: number;
  videoHeight?: number;
  thumbnailUrl?: string;
  thumbnailWidth?: number;
  thumbnailHeight?: number;
  mediaSubtitle?: string;
}

export interface PageMessage {
  pageSize?: number;
  offset?: number;
  currentPage?: number;
  totalCount?: number;
  totalPage?: number;
  hasMore?: number;
  hasPrev?: number;
  curGoodId?: number;
  reqNum?: number;
  pnum?: number;
  tnum?: number;
  totalNum?: number;
  lzTotalFloor?: number;
  newTotalPage?: number;
}

export interface DelThreadTextMessage {
  text?: string;
  pid?: number;
}

export interface AntiMessage {
  tbs?: string;
  ifpost?: number;
  ifposta?: number;
  forbidFlag?: number;
  forbidInfo?: string;
  blockStat?: number;
  hideStat?: number;
  vcodeStat?: number;
  daysTofree?: number;
  hasChance?: number;
  ifvoice?: number;
  delThreadText?: DelThreadTextMessage[];
}

export interface ForumInfoMessage {
  forumId?: number;
  forumName?: string;
  avatar?: string;
  postNum?: string;
  concernNum?: string;
  hasConcerned?: number;
}

export interface AppPosInfoMessage {
  addrTimestamp?: number;
  apConnected?: boolean;
  apMac?: string;
  aspShownInfo?: string;
  coordinateType?: string;
}

export interface ErrorMessage {
  errorMsg?: string;
  errorCode?: number;
  userMsg?: string;
}

export interface FrsTabInfoMessage {
  tabId?: number;
  tabType?: number;
  tabName?: string;
  tabUrl?: string;
  tabGid?: string;
  tabTitle?: string;
  isGeneralTab?: number;
  tabCode?: string;
  tabVersion?: number;
  isDefault?: number;
}

export interface FrsForumMessage {
  id?: number;
  name?: string;
  firstClass?: string;
  secondClass?: string;
  isExists?: number;
  isLike?: number;
  userLevel?: number;
  levelName?: string;
  memberNum?: number;
  threadNum?: number;
  postNum?: number;
  hasFrsStar?: number;
  curScore?: number;
  levelupScore?: number;
  avatar?: string;
  slogan?: string;
  fShareImg?: string;
  forumShareLink?: string;
  /** 精选二级分类（ForumInfo.good_classify，field 21；2026-09-20 精选分类页探针实测） */
  goodClassify?: GoodClassifyMessage[];
}

/** 精选二级分类项（实测响应只带 class_id(3)/class_name(4)；name(1)/id(2) 兼容保留） */
export interface GoodClassifyMessage {
  name?: string;
  id?: number;
  classId?: number;
  className?: string;
}

export interface FrsGroupMessage {
  hideRecommendGroup?: number;
  groupCount?: number;
}

export interface FrsNavTabInfoMessage {
  tab?: FrsTabInfoMessage[];
  menu?: FrsTabInfoMessage[];
  head?: FrsTabInfoMessage[];
}

export interface FrsPageResponseDataMessage {
  user?: UserMessage;
  forum?: FrsForumMessage;
  page?: PageMessage;
  anti?: AntiMessage;
  group?: FrsGroupMessage;
  threadList?: ThreadInfoMessage[];
  threadIdList?: number[];
  isNewUrl?: number;
  time?: number;
  ctime?: number;
  logid?: number;
  serverTime?: number;
  userList?: UserMessage[];
  frsTabInfo?: FrsTabInfoMessage[];
  navTabInfo?: FrsNavTabInfoMessage;
  forumRule?: ForumRuleStatusMessage;
}

export interface FrsPageResponseMessage {
  error?: ErrorMessage;
  data?: FrsPageResponseDataMessage;
}

export interface PostDataMessage {
  id?: number;
  content?: PbContentMessage[];
  postTitle?: string;
  author?: UserMessage;
  time?: number;
}

export interface ConcernDataMessage {
  threadList?: ThreadInfoMessage;
  postData?: PostDataMessage;
  recommendType?: number;
  source?: number;
  recommendUserList?: UserMessage[];
}

export interface UserLikeResponseDataMessage {
  threadInfo?: ConcernDataMessage[];
  pageTag?: string;
  hasMore?: number;
  requestUnix?: number;
}

export interface UserLikeResponseMessage {
  error?: ErrorMessage;
  data?: UserLikeResponseDataMessage;
}

export interface DislikeReasonMessage {
  dislikeReason?: string;
  dislikeId?: number;
  extra?: string;
}

export interface ThreadPersonalizedMessage {
  tid?: number;
  weight?: string;
  source?: string;
  dislikeResource?: DislikeReasonMessage[];
  extra?: string;
}

export interface PersonalizedResponseDataMessage {
  threadList?: ThreadInfoMessage[];
  threadPersonalized?: ThreadPersonalizedMessage[];
}

export interface PersonalizedResponseMessage {
  error?: ErrorMessage;
  data?: PersonalizedResponseDataMessage;
}

export interface PbPageResponseDataMessage {
  user?: UserMessage;
  forum?: SimpleForumMessage;
  page?: PageMessage;
  anti?: AntiMessage;
  postList?: PostMessage[];
  hasFloor?: number;
  isNewUrl?: number;
  thread?: ThreadInfoMessage;
  userList?: UserMessage[];
  serverTime?: number;
  feedThreadList?: ThreadInfoMessage[];
  isFollowCurrentChannel?: number;
  switchReadOpen?: number;
  sortType?: number;
  forumRule?: ForumRuleStatusMessage;
  displayForum?: SimpleForumMessage;
  newAgreeUser?: SimpleUserMessage[];
  hasFoldComment?: number;
  foldCommentNum?: number;
}

export interface SubPostListMessage {
  id?: number;
  content?: PbContentMessage[];
  time?: number;
  authorId?: number;
  title?: string;
  floor?: number;
  author?: UserMessage;
  agree?: AgreeMessage;
  agreeNum?: number;
  hasAgree?: number;
}

export interface PostSubPostMessage {
  subPostList?: SubPostListMessage[];
}

export interface PostMessage {
  id?: number;
  author?: UserMessage;
  floor?: number;
  time?: number;
  content?: PbContentMessage[];
  authorId?: number;
  subPostNumber?: number;
  subPostList?: PostSubPostMessage;
  agree?: AgreeMessage;
  agreeNum?: number;
  hasAgree?: number;
}

export interface PbFloorResponseMessage {
  error?: ErrorMessage;
  data?: PbFloorResponseDataMessage;
}

export interface PbFloorResponseDataMessage {
  page?: PageMessage;
  post?: PostMessage;
  subPostList?: SubPostListMessage[];
  thread?: ThreadInfoMessage;
  forum?: SimpleForumMessage;
}

export interface PbPageResponseMessage {
  error?: ErrorMessage;
  data?: PbPageResponseDataMessage;
}

export interface UserAgreeInfoMessage {
  totalAgreeNum?: number;
}

export interface ProfileResponseDataMessage {
  user?: UserMessage;
  userAgreeInfo?: UserAgreeInfoMessage;
}

export interface ProfileResponseMessage {
  error?: ErrorMessage;
  data?: ProfileResponseDataMessage;
}

export interface PostInfoListMessage {
  forumId?: number;
  threadId?: number;
  postId?: number;
  isThread?: number;
  createTime?: number;
  forumName?: string;
  title?: string;
  userName?: string;
  abstract?: AbstractMessage[];
  content?: AbstractMessage[];
  /** field 9：正文 HTML（含 <img class="BDE_Image"> 图片标签，与网页版一致，可复用 extractImages 提取） */
  contentHtml?: string;
  replyNum?: number;
  userId?: number;
  nameShow?: string;
  agreeNum?: number;
}

export interface UserPostResponseDataMessage {
  postList?: PostInfoListMessage[];
}

export interface UserPostResponseMessage {
  error?: ErrorMessage;
  data?: UserPostResponseDataMessage;
}

export interface ForumRuleStatusMessage {
  title?: string;
  auditStatus?: number;
  hasForumRule?: number;
}

/** 黑名单（Cmd 303028 userMuteQuery）单条 */
export interface BlacklistMuteUserMessage {
  userId?: string;
  userName?: string;
  nameShow?: string;
  portrait?: string;
  muteTime?: number;
}

/** 黑名单（Cmd 303028 userMuteQuery）整体解码结果 */
export interface BlacklistMuteQueryResultMessage {
  list: BlacklistMuteUserMessage[];
  hasMore: boolean;
  totalCount: number;
  errorCode: number;
  errorMsg: string;
}

export interface CommonRequestMessage {
  clientType?: number;
  clientVersion?: string;
  clientId?: string;
  phoneImei?: string;
  from?: string;
  cuid?: string;
  timestamp?: number;
  model?: string;
  BDUSS?: string;
  tbs?: string;
  netType?: number;
  phoneNewimei?: string;
  sign?: string;
  pversion?: string;
  osVersion?: string;
  brand?: string;
  stoken?: string;
  scrW?: number;
  scrH?: number;
  scrDip?: number;
  qType?: number;
  sdkVer?: string;
  frameworkVer?: string;
  userAgent?: string;
}
