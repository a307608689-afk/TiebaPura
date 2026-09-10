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

import { util } from '@kit.ArkTS';
import { ProtoReader } from './ProtobufCodec';
import {
  AbstractMessage, AgreeMessage, AntiMessage, CommonRequestMessage, ConcernDataMessage,
  DislikeInfoMessage, DislikeReasonMessage, ErrorMessage, FrsForumMessage,
  FrsPageResponseDataMessage, FrsPageResponseMessage, FrsTabInfoMessage,
  IconMessage, LikeForumInfoMessage, MediaMessage, MemeInfoMessage, PageMessage,
  PbContentMessage, PbPageResponseDataMessage, PbPageResponseMessage, PostDataMessage,
  PostMessage, PrivSetsMessage, SimpleForumMessage, SimpleUserMessage, ThreadInfoMessage,
  UserAgreeInfoMessage, ProfileResponseDataMessage, ProfileResponseMessage,
  PostInfoListMessage, UserPostResponseDataMessage, UserPostResponseMessage,
  PostSubPostMessage, SubPostListMessage, PbFloorResponseMessage, PbFloorResponseDataMessage,
  ThreadPersonalizedMessage, UserLikeResponseDataMessage, UserLikeResponseMessage,
  UserMessage, UserPicsMessage, PersonalizedResponseDataMessage, PersonalizedResponseMessage,
  OriginThreadInfoMessage, VideoInfoMessage, ForumRuleStatusMessage,
  BlacklistMuteUserMessage, BlacklistMuteQueryResultMessage
} from '../model/TiebaProtoSchema';

/** Binary response decoder for the TiebaLite 4.0-dev protobuf messages. */
export class TiebaProtoDecoder {
  static decodeError(data: ArrayBuffer): ErrorMessage {
    const result: ErrorMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.fieldNumber === 1 && tag.wireType === 0) result.errorCode = reader.readVarint();
      else if (tag.fieldNumber === 2 && tag.wireType === 2) result.errorMsg = reader.readString();
      else if (tag.fieldNumber === 3 && tag.wireType === 2) result.userMsg = reader.readString();
      else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodePage(data: ArrayBuffer): PageMessage {
    const result: PageMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType !== 0) { reader.skip(tag.wireType); continue; }
      const value = reader.readVarint();
      if (tag.fieldNumber === 1) result.pageSize = value;
      else if (tag.fieldNumber === 2) result.offset = value;
      else if (tag.fieldNumber === 3) result.currentPage = value;
      else if (tag.fieldNumber === 4) result.totalCount = value;
      else if (tag.fieldNumber === 5) result.totalPage = value;
      else if (tag.fieldNumber === 6) result.hasMore = value;
      else if (tag.fieldNumber === 7) result.hasPrev = value;
      else if (tag.fieldNumber === 8) result.curGoodId = value;
      else if (tag.fieldNumber === 9) result.reqNum = value;
      else if (tag.fieldNumber === 10) result.pnum = value;
      else if (tag.fieldNumber === 11) result.tnum = value;
      else if (tag.fieldNumber === 12) result.totalNum = value;
      else if (tag.fieldNumber === 13) result.lzTotalFloor = value;
      else if (tag.fieldNumber === 14) result.newTotalPage = value;
    }
    return result;
  }

  static decodeCommonRequest(data: ArrayBuffer): CommonRequestMessage {
    const result: CommonRequestMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const value = reader.readString();
        if (tag.fieldNumber === 2) result.clientVersion = value;
        else if (tag.fieldNumber === 3) result.clientId = value;
        else if (tag.fieldNumber === 6) result.from = value;
        else if (tag.fieldNumber === 7) result.cuid = value;
        else if (tag.fieldNumber === 9) result.model = value;
        else if (tag.fieldNumber === 10) result.BDUSS = value;
        else if (tag.fieldNumber === 11) result.tbs = value;
        else if (tag.fieldNumber === 14) result.phoneNewimei = value;
        else if (tag.fieldNumber === 24) result.pversion = value;
        else if (tag.fieldNumber === 25) result.osVersion = value;
        else if (tag.fieldNumber === 26) result.brand = value;
        else if (tag.fieldNumber === 30) result.stoken = value;
        else if (tag.fieldNumber === 42) result.sdkVer = value;
        else if (tag.fieldNumber === 43) result.frameworkVer = value;
        else if (tag.fieldNumber === 62) result.userAgent = value;
      } else if (tag.wireType === 0) {
        const value = reader.readVarint();
        if (tag.fieldNumber === 1) result.clientType = value;
        else if (tag.fieldNumber === 8) result.timestamp = value;
        else if (tag.fieldNumber === 12) result.netType = value;
        else if (tag.fieldNumber === 37) result.scrW = value;
        else if (tag.fieldNumber === 38) result.scrH = value;
        else if (tag.fieldNumber === 40) result.qType = value;
      } else {
        reader.skip(tag.wireType);
      }
    }
    return result;
  }

  static decodeMedia(data: ArrayBuffer): MediaMessage {
    const result: MediaMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const value = reader.readString();
        if (tag.fieldNumber === 3) result.bigPic = value;
        else if (tag.fieldNumber === 8) result.srcPic = value;
        else if (tag.fieldNumber === 15) result.originPic = value;
        else if (tag.fieldNumber === 18) result.dynamicPic = value;
      } else if (tag.wireType === 0) {
        const value = reader.readVarint();
        if (tag.fieldNumber === 1) result.type = value;
        else if (tag.fieldNumber === 10) result.width = value;
        else if (tag.fieldNumber === 11) result.height = value;
        else if (tag.fieldNumber === 16) result.originSize = value;
        else if (tag.fieldNumber === 17) result.postId = value;
        else if (tag.fieldNumber === 19) result.isLongPic = value;
        else if (tag.fieldNumber === 20) result.showOriginalBtn = value;
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodeAbstract(data: ArrayBuffer): AbstractMessage {
    const result: AbstractMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const value = reader.readString();
        if (tag.fieldNumber === 2) result.text = value;
        else if (tag.fieldNumber === 3) result.link = value;
        else if (tag.fieldNumber === 4) result.src = value;
        else if (tag.fieldNumber === 5) result.un = value;
        else if (tag.fieldNumber === 6) result.duringTime = value;
        else if (tag.fieldNumber === 7) result.voiceMD5 = value;
      } else if (tag.wireType === 0 && tag.fieldNumber === 1) result.type = reader.readVarint();
      else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodePbContent(data: ArrayBuffer): PbContentMessage {
    const result: PbContentMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        if (tag.fieldNumber === 33) {
          result.memeInfo = TiebaProtoDecoder.decodeMemeInfo(reader.readBytes());
        } else {
          const value = reader.readString();
          if (tag.fieldNumber === 2) result.text = value;
          else if (tag.fieldNumber === 3) result.link = value;
          else if (tag.fieldNumber === 4) result.src = value;
          else if (tag.fieldNumber === 5) result.bsize = value;
          else if (tag.fieldNumber === 6) result.bigSrc = value;
          else if (tag.fieldNumber === 7) result.bigSize = value;
          else if (tag.fieldNumber === 8) result.cdnSrc = value;
          else if (tag.fieldNumber === 9) result.bigCdnSrc = value;
          else if (tag.fieldNumber === 10) result.imgType = value;
          else if (tag.fieldNumber === 11) result.c = value;
          else if (tag.fieldNumber === 12) result.voiceMD5 = value;
          else if (tag.fieldNumber === 16) result.dynamic = value;
          else if (tag.fieldNumber === 17) result.staticValue = value;
          else if (tag.fieldNumber === 25) result.originSrc = value;
          else if (tag.fieldNumber === 31) result.mediaSubtitle = value;
          else if (tag.fieldNumber === 36) result.cdnSrcActive = value;
        }
      } else if (tag.wireType === 0) {
        const value = reader.readVarint();
        if (tag.fieldNumber === 1) result.type = value;
        else if (tag.fieldNumber === 13) result.duringTime = value;
        else if (tag.fieldNumber === 15) result.uid = value;
        else if (tag.fieldNumber === 18) result.width = value;
        else if (tag.fieldNumber === 19) result.height = value;
        else if (tag.fieldNumber === 27) result.originSize = value;
        else if (tag.fieldNumber === 32) result.urlType = value;
        else if (tag.fieldNumber === 34) result.isLongPic = value;
        else if (tag.fieldNumber === 35) result.showOriginalBtn = value;
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodeMemeInfo(data: ArrayBuffer): MemeInfoMessage {
    const result: MemeInfoMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const value = reader.readString();
        if (tag.fieldNumber === 3) result.picUrl = value;
        else if (tag.fieldNumber === 4) result.thumbnail = value;
        else if (tag.fieldNumber === 7) result.detailLink = value;
      } else if (tag.wireType === 0) {
        const value = reader.readVarint();
        if (tag.fieldNumber === 1) result.pckId = value;
        else if (tag.fieldNumber === 2) result.picId = value;
        else if (tag.fieldNumber === 5) result.width = value;
        else if (tag.fieldNumber === 6) result.height = value;
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodeUser(data: ArrayBuffer): UserMessage {
    const result: UserMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        if (tag.fieldNumber === 17) result.iconinfo = TiebaProtoDecoder.append(result.iconinfo, TiebaProtoDecoder.decodeIcon(reader.readBytes()));
        else if (tag.fieldNumber === 44) result.userPics = TiebaProtoDecoder.append(result.userPics, TiebaProtoDecoder.decodeUserPics(reader.readBytes()));
        else if (tag.fieldNumber === 45) result.privSets = TiebaProtoDecoder.decodePrivSets(reader.readBytes());
        else if (tag.fieldNumber === 47) result.likeForum = TiebaProtoDecoder.append(result.likeForum, TiebaProtoDecoder.decodeLikeForumInfo(reader.readBytes()));
        else if (tag.fieldNumber === 55) result.muteUser = TiebaProtoDecoder.append(result.muteUser, TiebaProtoDecoder.decodeSimpleUser(reader.readBytes()));
        else {
          const value = reader.readString();
          if (tag.fieldNumber === 3) result.name = value;
          else if (tag.fieldNumber === 4) result.nameShow = value;
          else if (tag.fieldNumber === 5) result.portrait = value;
          else if (tag.fieldNumber === 12) result.rank = value;
          else if (tag.fieldNumber === 13) result.bimgUrl = value;
          else if (tag.fieldNumber === 22) result.iosBimgFormat = value;
          else if (tag.fieldNumber === 26) result.bawuType = value;
          else if (tag.fieldNumber === 27) result.portraith = value;
          else if (tag.fieldNumber === 28) result.ip = value;
          else if (tag.fieldNumber === 29) result.BDUSS = value;
          else if (tag.fieldNumber === 34) result.intro = value;
          else if (tag.fieldNumber === 36) result.passwd = value;
          else if (tag.fieldNumber === 38) result.tbAge = value;
          else if (tag.fieldNumber === 57) result.fansNickname = value;
          else if (tag.fieldNumber === 58) result.bgPic = value;
          else if (tag.fieldNumber === 98) result.modifyAvatarDesc = value;
          else if (tag.fieldNumber === 100) result.levelInfluence = value;
          else if (tag.fieldNumber === 120) result.tiebaUid = value;
          else if (tag.fieldNumber === 125) result.levelName = value;
          else if (tag.fieldNumber === 127) result.ipAddress = value;
          else if (tag.fieldNumber === 129) result.editingNickname = value;
          else if (tag.fieldNumber === 138) result.displayIntro = value;
          else if (tag.fieldNumber === 139) result.newIconUrl = TiebaProtoDecoder.appendString(result.newIconUrl, value);
          else if (tag.fieldNumber === 140) result.dynamicUrl = value;
        }
      } else if (tag.wireType === 0) {
        const value = reader.readVarint();
        if (tag.fieldNumber === 1) result.isLogin = value;
        else if (tag.fieldNumber === 2) result.id = value;
        else if (tag.fieldNumber === 6) result.noUn = value;
        else if (tag.fieldNumber === 7) result.type = value;
        else if (tag.fieldNumber === 9) result.userhide = value;
        else if (tag.fieldNumber === 11) result.isManager = value;
        else if (tag.fieldNumber === 14) result.meizhiLevel = value;
        else if (tag.fieldNumber === 15) result.isVerify = value;
        else if (tag.fieldNumber === 16) result.isInterestman = value;
        else if (tag.fieldNumber === 19) result.userType = value;
        else if (tag.fieldNumber === 20) result.isCoreuser = value;
        else if (tag.fieldNumber === 21) result.isHuinibuke = value;
        else if (tag.fieldNumber === 23) result.levelId = value;
        else if (tag.fieldNumber === 24) result.isLike = value;
        else if (tag.fieldNumber === 25) result.isBawu = value;
        else if (tag.fieldNumber === 30) result.fansNum = value;
        else if (tag.fieldNumber === 31) result.concernNum = value;
        else if (tag.fieldNumber === 32) result.sex = value;
        else if (tag.fieldNumber === 33) result.myLikeNum = value;
        else if (tag.fieldNumber === 35) result.hasConcerned = value;
        else if (tag.fieldNumber === 37) result.postNum = value;
        else if (tag.fieldNumber === 39) result.isMem = value;
        else if (tag.fieldNumber === 40) result.bimgEndTime = value;
        else if (tag.fieldNumber === 42) result.gender = value;
        else if (tag.fieldNumber === 43) result.isMask = value;
        else if (tag.fieldNumber === 46) result.isFriend = value;
        else if (tag.fieldNumber === 49) result.giftNum = value;
        else if (tag.fieldNumber === 51) result.isSelectTail = value;
        else if (tag.fieldNumber === 52) result.isGuanfang = value;
        else if (tag.fieldNumber === 53) result.bookmarkCount = value;
        else if (tag.fieldNumber === 54) result.bookmarkNewCount = value;
        else if (tag.fieldNumber === 56) result.friendNum = value;
        else if (tag.fieldNumber === 63) result.heavyUser = value;
        else if (tag.fieldNumber === 75) result.visitorNum = value;
        else if (tag.fieldNumber === 76) result.totalVisitorNum = value;
        else if (tag.fieldNumber === 86) result.nicknameUpdateTime = value;
        else if (tag.fieldNumber === 87) result.threadNum = value;
        else if (tag.fieldNumber === 88) result.agreeNum = value;
        else if (tag.fieldNumber === 89) result.leftCallNum = value;
        else if (tag.fieldNumber === 90) result.isInvited = value;
        else if (tag.fieldNumber === 91) result.isFans = value;
        else if (tag.fieldNumber === 92) result.privThread = value;
        else if (tag.fieldNumber === 93) result.isVideobiggie = value;
        else if (tag.fieldNumber === 94) result.isShowRedpacket = value;
        else if (tag.fieldNumber === 97) result.canModifyAvatar = value;
        else if (tag.fieldNumber === 99) result.influence = value;
        else if (tag.fieldNumber === 106) result.isDefaultAvatar = value;
        else if (tag.fieldNumber === 109) result.favoriteNum = value;
        else if (tag.fieldNumber === 118) result.totalAgreeNum = value;
        else if (tag.fieldNumber === 128) result.isNicknameEditing = value;
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodeIcon(data: ArrayBuffer): IconMessage {
    const result: IconMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const value = reader.readString();
        if (tag.fieldNumber === 1) result.name = value;
        else if (tag.fieldNumber === 3) result.url = value;
        else if (tag.fieldNumber === 4) result.icon = value;
        else if (tag.fieldNumber === 8) result.spriteInfo = TiebaProtoDecoder.appendString(result.spriteInfo, value);
      } else if (tag.wireType === 0) {
        const value = reader.readVarint();
        if (tag.fieldNumber === 2) result.weight = value;
        else if (tag.fieldNumber === 5) result.value = value;
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodeUserPics(data: ArrayBuffer): UserPicsMessage {
    const result: UserPicsMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const value = reader.readString();
        if (tag.fieldNumber === 1) result.big = value;
        else if (tag.fieldNumber === 2) result.small = value;
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodePrivSets(data: ArrayBuffer): PrivSetsMessage {
    const result: PrivSetsMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 0) {
        const value = reader.readVarint();
        if (tag.fieldNumber === 2) result.like = value;
        else if (tag.fieldNumber === 3) result.group = value;
        else if (tag.fieldNumber === 4) result.post = value;
        else if (tag.fieldNumber === 6) result.live = value;
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodeLikeForumInfo(data: ArrayBuffer): LikeForumInfoMessage {
    const result: LikeForumInfoMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) result.forumName = reader.readString();
      else if (tag.wireType === 0) result.forumId = reader.readVarint();
      else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodeSimpleUser(data: ArrayBuffer): SimpleUserMessage {
    const result: SimpleUserMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const value = reader.readString();
        if (tag.fieldNumber === 3) result.secureemail = value;
        else if (tag.fieldNumber === 4) result.securemobil = value;
        else if (tag.fieldNumber === 5) result.userName = value;
        else if (tag.fieldNumber === 6) result.userNickname = value;
        else if (tag.fieldNumber === 8) result.portrait = value;
        else if (tag.fieldNumber === 10) result.aheadUrl = value;
        else if (tag.fieldNumber === 11) result.blockMsg = value;
      } else if (tag.wireType === 0) {
        const value = reader.readVarint();
        if (tag.fieldNumber === 1) result.userId = value;
        else if (tag.fieldNumber === 2) result.userStatus = value;
        else if (tag.fieldNumber === 7) result.incompleteUser = value;
        else if (tag.fieldNumber === 9) result.agreeType = value;
        else if (tag.fieldNumber === 12) result.showOnlyme = value;
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodeAgree(data: ArrayBuffer): AgreeMessage {
    const result: AgreeMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType !== 0) { reader.skip(tag.wireType); continue; }
      const value = reader.readVarint();
      if (tag.fieldNumber === 1) result.agreeNum = value;
      // 兼容双协议：aiotieba官方proto中field2=disagree_num；tieba-lite-harmony中field2=hasAgree
      // 两者并存：field2值同时影响两个字段。Service层判断点赞状态时优先嵌套值、其次独立字段OR。
      else if (tag.fieldNumber === 2) {
        result.hasAgree = result.hasAgree ?? value;
        result.disagreeNum = result.disagreeNum ?? value;
      }
      else if (tag.fieldNumber === 3) result.agreeType = value;
      else if (tag.fieldNumber === 4) {
        // field4如果出现disagree_num，覆盖field2写入的disagreeNum（但不影响hasAgree）
        result.disagreeNum = value;
      }
      else if (tag.fieldNumber === 5) result.diffAgreeNum = value;
      // 兼容扩展：如果field>=6出现0/1值（可能是贴吧新版本hasAgree扩展），fallback给hasAgree
      else if (tag.fieldNumber >= 6 && (value === 0 || value === 1)) {
        if (result.hasAgree === undefined || value === 1) result.hasAgree = value;
      }
    }
    return result;
  }

  static decodeThreadInfo(data: ArrayBuffer): ThreadInfoMessage {
    const result: ThreadInfoMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const bytes = reader.readBytes();
        // author：不同 proto 版本字段号不同（17 为旧版，18 为标准版），兼容两者
        if (tag.fieldNumber === 17 || tag.fieldNumber === 18) result.author = TiebaProtoDecoder.decodeUser(bytes);
        else if (tag.fieldNumber === 19) result.lastReplyer = TiebaProtoDecoder.decodeUser(bytes);
        else if (tag.fieldNumber === 21) result.abstract = TiebaProtoDecoder.append(result.abstract, TiebaProtoDecoder.decodeAbstract(bytes));
        else if (tag.fieldNumber === 22) result.media = TiebaProtoDecoder.append(result.media, TiebaProtoDecoder.decodeMedia(bytes));
        else if (tag.fieldNumber === 111) result.richTitle = TiebaProtoDecoder.append(result.richTitle, TiebaProtoDecoder.decodePbContent(bytes));
        else if (tag.fieldNumber === 112) result.richAbstract = TiebaProtoDecoder.append(result.richAbstract, TiebaProtoDecoder.decodePbContent(bytes));
        else if (tag.fieldNumber === 120) result.dislikeInfo = TiebaProtoDecoder.append(result.dislikeInfo, TiebaProtoDecoder.decodeDislikeInfo(bytes));
        else if (tag.fieldNumber === 126) result.agree = TiebaProtoDecoder.decodeAgree(bytes);
        else if (tag.fieldNumber === 141) result.originThreadInfo = TiebaProtoDecoder.decodeOriginThreadInfo(bytes);
        else if (tag.fieldNumber === 142) result.firstPostContent = TiebaProtoDecoder.append(result.firstPostContent, TiebaProtoDecoder.decodePbContent(bytes));
        else if (tag.fieldNumber === 155) result.forumInfo = TiebaProtoDecoder.decodeSimpleForum(bytes);
        else {
          const value = new util.TextDecoder().decode(new Uint8Array(bytes));
          if (tag.fieldNumber === 3) result.title = value;
          else if (tag.fieldNumber === 6) result.lastTime = value;
          else if (tag.fieldNumber === 28) result.forumName = value;
          else if (tag.fieldNumber === 51) result.collectMarkPid = value;
          else if (tag.fieldNumber === 61) result.pids = value;
          else if (tag.fieldNumber === 149) result.topicUserName = value;
          else if (tag.fieldNumber === 150) result.topicH5Url = value;
          else if (tag.fieldNumber === 159) result.tShareImg = value;
          else if (tag.fieldNumber === 164) result.nid = value;
          else if (tag.fieldNumber === 176) result.tabName = value;
        }
      } else if (tag.wireType === 0) {
        const value = reader.readVarint();
        if (tag.fieldNumber === 1) result.id = value;
        else if (tag.fieldNumber === 2) result.threadId = value;
        else if (tag.fieldNumber === 4) result.replyNum = value;
        else if (tag.fieldNumber === 5) result.viewNum = value;
        else if (tag.fieldNumber === 7) result.lastTimeInt = value;
        else if (tag.fieldNumber === 8) result.threadTypes = value;
        else if (tag.fieldNumber === 9) result.isTop = value;
        else if (tag.fieldNumber === 10) result.isGood = value;
        else if (tag.fieldNumber === 20) result.commentNum = value;
        else if (tag.fieldNumber === 27) result.forumId = value;
        else if (tag.fieldNumber === 38) result.isNoTitle = value;
        else if (tag.fieldNumber === 40) result.firstPostId = value;
        else if (tag.fieldNumber === 45) result.createTime = value;
        else if (tag.fieldNumber === 50) result.collectStatus = value;
        else if (tag.fieldNumber === 52) result.postId = value;
        else if (tag.fieldNumber === 54) result.isMemberTop = value;
        else if (tag.fieldNumber === 56) result.authorId = value;
        else if (tag.fieldNumber === 124) result.agreeNum = value;
        else if (tag.fieldNumber === 125) result.hasAgree = value;
        else if (tag.fieldNumber === 135) result.shareNum = value;
        else if (tag.fieldNumber === 143) result.isShareThread = value;
        else if (tag.fieldNumber === 148) result.isTopic = value;
        else if (tag.fieldNumber === 175) result.tabId = value;
        else if (tag.fieldNumber === 181) result.isDeleted = value;
        else if (tag.fieldNumber === 182) result.hotNum = value;
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodeSimpleForum(data: ArrayBuffer): SimpleForumMessage {
    const result: SimpleForumMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const value = reader.readString();
        if (tag.fieldNumber === 2) result.name = value;
        else if (tag.fieldNumber === 4) result.avatar = value;
      } else if (tag.wireType === 0) {
        const value = reader.readVarint();
        if (tag.fieldNumber === 1) result.id = value;
        else if (tag.fieldNumber === 12) result.memberNum = value;
        else if (tag.fieldNumber === 13) result.postNum = value;
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodeDislikeInfo(data: ArrayBuffer): DislikeInfoMessage {
    const result: DislikeInfoMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const value = reader.readString();
        if (tag.fieldNumber === 1) result.dislikeReason = value;
        else if (tag.fieldNumber === 3) result.extra = value;
      } else if (tag.wireType === 0 && tag.fieldNumber === 2) result.dislikeId = reader.readVarint();
      else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodeAnti(data: ArrayBuffer): AntiMessage {
    const result: AntiMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const bytes = reader.readBytes();
        if (tag.fieldNumber === 1) result.tbs = new util.TextDecoder().decode(new Uint8Array(bytes));
        else if (tag.fieldNumber === 5) result.forbidInfo = new util.TextDecoder().decode(new Uint8Array(bytes));
        else if (tag.fieldNumber === 24) result.delThreadText = TiebaProtoDecoder.append(result.delThreadText, {});
      } else if (tag.wireType === 0) {
        const value = reader.readVarint();
        if (tag.fieldNumber === 2) result.ifpost = value;
        else if (tag.fieldNumber === 3) result.ifposta = value;
        else if (tag.fieldNumber === 4) result.forbidFlag = value;
        else if (tag.fieldNumber === 6) result.blockStat = value;
        else if (tag.fieldNumber === 7) result.hideStat = value;
        else if (tag.fieldNumber === 8) result.vcodeStat = value;
        else if (tag.fieldNumber === 9) result.daysTofree = value;
        else if (tag.fieldNumber === 10) result.hasChance = value;
        else if (tag.fieldNumber === 11) result.ifvoice = value;
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodeOriginThreadInfo(data: ArrayBuffer): OriginThreadInfoMessage {
    const result: OriginThreadInfoMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const value = reader.readBytes();
        if (tag.fieldNumber === 1) result.title = new util.TextDecoder().decode(new Uint8Array(value));
        else if (tag.fieldNumber === 4) result.fname = new util.TextDecoder().decode(new Uint8Array(value));
        else if (tag.fieldNumber === 5) result.tid = new util.TextDecoder().decode(new Uint8Array(value));
        else if (tag.fieldNumber === 2) result.media = TiebaProtoDecoder.append(result.media, TiebaProtoDecoder.decodeMedia(value));
        else if (tag.fieldNumber === 3) result.abstract = TiebaProtoDecoder.append(result.abstract, TiebaProtoDecoder.decodeAbstract(value));
        else if (tag.fieldNumber === 14) result.content = TiebaProtoDecoder.append(result.content, TiebaProtoDecoder.decodePbContent(value));
        else if (tag.fieldNumber === 18) result.author = TiebaProtoDecoder.decodeUser(value);
        else if (tag.fieldNumber === 19) result.agree = TiebaProtoDecoder.decodeAgree(value);
        else {
          const text = new util.TextDecoder().decode(new Uint8Array(value));
          if (tag.fieldNumber === 1) result.title = text;
          else if (tag.fieldNumber === 4) result.fname = text;
          else if (tag.fieldNumber === 5) result.tid = text;
        }
      } else if (tag.wireType === 0) {
        const value = reader.readVarint();
        if (tag.fieldNumber === 7) result.fid = value;
        else if (tag.fieldNumber === 8) result.threadType = value;
        else if (tag.fieldNumber === 9) result.isDeleted = value;
        else if (tag.fieldNumber === 10) result.isUgc = value;
        else if (tag.fieldNumber === 16) result.replyNum = value;
        else if (tag.fieldNumber === 20) result.sharedNum = value;
        else if (tag.fieldNumber === 25) result.pid = value;
        else if (tag.fieldNumber === 26) result.goodTypes = value;
        else if (tag.fieldNumber === 27) result.topTypes = value;
        else if (tag.fieldNumber === 28) result.isFrsMask = value;
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodeFrsPageResponse(data: ArrayBuffer): FrsPageResponseMessage {
    const result: FrsPageResponseMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType !== 2) { reader.skip(tag.wireType); continue; }
      const value = reader.readBytes();
      if (tag.fieldNumber === 1) result.error = TiebaProtoDecoder.decodeError(value);
      else if (tag.fieldNumber === 2) result.data = TiebaProtoDecoder.decodeFrsPageData(value);
    }
    return result;
  }

  static decodeFrsPageData(data: ArrayBuffer): FrsPageResponseDataMessage {
    const result: FrsPageResponseDataMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const value = reader.readBytes();
        if (tag.fieldNumber === 1) result.user = TiebaProtoDecoder.decodeUser(value);
        else if (tag.fieldNumber === 2) result.forum = TiebaProtoDecoder.decodeFrsForum(value);
        else if (tag.fieldNumber === 3) result.page = TiebaProtoDecoder.decodePage(value);
        else if (tag.fieldNumber === 5) result.anti = TiebaProtoDecoder.decodeAnti(value);
        else if (tag.fieldNumber === 7) result.threadList = TiebaProtoDecoder.append(result.threadList, TiebaProtoDecoder.decodeThreadInfo(value));
        else if (tag.fieldNumber === 17) result.userList = TiebaProtoDecoder.append(result.userList, TiebaProtoDecoder.decodeUser(value));
        else if (tag.fieldNumber === 22) result.frsTabInfo = TiebaProtoDecoder.append(result.frsTabInfo, TiebaProtoDecoder.decodeFrsTab(value));
      } else if (tag.wireType === 0) {
        const value = reader.readVarint();
        if (tag.fieldNumber === 8) result.threadIdList = TiebaProtoDecoder.appendNumber(result.threadIdList, value);
        else if (tag.fieldNumber === 9) result.isNewUrl = value;
        else if (tag.fieldNumber === 11) result.time = value;
        else if (tag.fieldNumber === 12) result.ctime = value;
        else if (tag.fieldNumber === 13) result.logid = value;
        else if (tag.fieldNumber === 14) result.serverTime = value;
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodeFrsForum(data: ArrayBuffer): FrsForumMessage {
    const result: FrsForumMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const value = reader.readString();
        if (tag.fieldNumber === 2) result.name = value;
        else if (tag.fieldNumber === 3) result.firstClass = value;
        else if (tag.fieldNumber === 4) result.secondClass = value;
        else if (tag.fieldNumber === 8) result.levelName = value;
        else if (tag.fieldNumber === 24) result.avatar = value;
        else if (tag.fieldNumber === 25) result.slogan = value;
        else if (tag.fieldNumber === 78) result.fShareImg = value;
        else if (tag.fieldNumber === 79) result.forumShareLink = value;
      } else if (tag.wireType === 0) {
        const value = reader.readVarint();
        if (tag.fieldNumber === 1) result.id = value;
        else if (tag.fieldNumber === 5) result.isExists = value;
        else if (tag.fieldNumber === 6) result.isLike = value;
        else if (tag.fieldNumber === 7) result.userLevel = value;
        else if (tag.fieldNumber === 9) result.memberNum = value;
        else if (tag.fieldNumber === 10) result.threadNum = value;
        else if (tag.fieldNumber === 11) result.postNum = value;
        else if (tag.fieldNumber === 12) result.hasFrsStar = value;
        else if (tag.fieldNumber === 13) result.curScore = value;
        else if (tag.fieldNumber === 14) result.levelupScore = value;
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodeFrsTab(data: ArrayBuffer): FrsTabInfoMessage {
    const result: FrsTabInfoMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const value = reader.readString();
        if (tag.fieldNumber === 3) result.tabName = value;
        else if (tag.fieldNumber === 4) result.tabUrl = value;
        else if (tag.fieldNumber === 5) result.tabGid = value;
        else if (tag.fieldNumber === 6) result.tabTitle = value;
        else if (tag.fieldNumber === 8) result.tabCode = value;
      } else if (tag.wireType === 0) {
        const value = reader.readVarint();
        if (tag.fieldNumber === 1) result.tabId = value;
        else if (tag.fieldNumber === 2) result.tabType = value;
        else if (tag.fieldNumber === 7) result.isGeneralTab = value;
        else if (tag.fieldNumber === 9) result.tabVersion = value;
        else if (tag.fieldNumber === 10) result.isDefault = value;
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodeProfileResponse(data: ArrayBuffer): ProfileResponseMessage {
    const result: ProfileResponseMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const value = reader.readBytes();
        if (tag.fieldNumber === 1) result.error = TiebaProtoDecoder.decodeError(value);
        else if (tag.fieldNumber === 2) result.data = TiebaProtoDecoder.decodeProfileData(value);
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodeProfileData(data: ArrayBuffer): ProfileResponseDataMessage {
    const result: ProfileResponseDataMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const value = reader.readBytes();
        if (tag.fieldNumber === 1) result.user = TiebaProtoDecoder.decodeUser(value);
        else if (tag.fieldNumber === 14) result.userAgreeInfo = TiebaProtoDecoder.decodeUserAgreeInfo(value);
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodeUserAgreeInfo(data: ArrayBuffer): UserAgreeInfoMessage {
    const result: UserAgreeInfoMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 0) {
        const value = reader.readVarint();
        if (tag.fieldNumber === 1) result.totalAgreeNum = value;
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodeUserPostResponse(data: ArrayBuffer): UserPostResponseMessage {
    const result: UserPostResponseMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const value = reader.readBytes();
        if (tag.fieldNumber === 1) result.error = TiebaProtoDecoder.decodeError(value);
        else if (tag.fieldNumber === 2) result.data = TiebaProtoDecoder.decodeUserPostData(value);
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodeUserPostData(data: ArrayBuffer): UserPostResponseDataMessage {
    const result: UserPostResponseDataMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2 && tag.fieldNumber === 1) {
        result.postList = TiebaProtoDecoder.append(result.postList, TiebaProtoDecoder.decodePostInfoList(reader.readBytes()));
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodePostInfoList(data: ArrayBuffer): PostInfoListMessage {
    const result: PostInfoListMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const value = reader.readBytes();
        if (tag.fieldNumber === 6) result.forumName = new util.TextDecoder().decode(new Uint8Array(value));
        else if (tag.fieldNumber === 7) result.title = new util.TextDecoder().decode(new Uint8Array(value));
        else if (tag.fieldNumber === 8) result.content = TiebaProtoDecoder.mergeMessages(result.content, TiebaProtoDecoder.decodePostInfoContent(value));
        else if (tag.fieldNumber === 9) result.contentHtml = new util.TextDecoder().decode(new Uint8Array(value));
        else if (tag.fieldNumber === 10) result.userName = new util.TextDecoder().decode(new Uint8Array(value));
        else if (tag.fieldNumber === 14) result.abstract = TiebaProtoDecoder.append(result.abstract, { text: new util.TextDecoder().decode(new Uint8Array(value)) });
        else if (tag.fieldNumber === 15) result.abstract = TiebaProtoDecoder.append(result.abstract, TiebaProtoDecoder.decodeAbstract(value));
        else if (tag.fieldNumber === 35) result.nameShow = new util.TextDecoder().decode(new Uint8Array(value));
      } else if (tag.wireType === 0) {
        const value = reader.readVarint();
        if (tag.fieldNumber === 1) result.forumId = value;
        else if (tag.fieldNumber === 2) result.threadId = value;
        else if (tag.fieldNumber === 3) result.postId = value;
        else if (tag.fieldNumber === 4) result.isThread = value;
        else if (tag.fieldNumber === 5) result.createTime = value;
        else if (tag.fieldNumber === 17) result.replyNum = value;
        else if (tag.fieldNumber === 18) result.userId = value;
        else if (tag.fieldNumber === 37) result.agreeNum = value;
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodePostInfoContent(data: ArrayBuffer): AbstractMessage[] {
    const result: AbstractMessage[] = [];
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        // content(field 8) 内每个 length-delimited 子项本身即为完整的 AbstractMessage
        // （图片段 type=2 时 link 即 CDN 大图地址）。兼容 "repeated Abstract" 平铺
        // 结构与 field 1 嵌套容器两种形态：一律按 Abstract 解析，不再按 fieldNumber 丢弃。
        result.push(TiebaProtoDecoder.decodeAbstract(reader.readBytes()));
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodePbFloorResponse(data: ArrayBuffer): PbFloorResponseMessage {
    const result: PbFloorResponseMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType !== 2) { reader.skip(tag.wireType); continue; }
      const value = reader.readBytes();
      if (tag.fieldNumber === 1) result.error = TiebaProtoDecoder.decodeError(value);
      else if (tag.fieldNumber === 2) result.data = TiebaProtoDecoder.decodePbFloorData(value);
    }
    return result;
  }

  static decodePbFloorData(data: ArrayBuffer): PbFloorResponseDataMessage {
    const result: PbFloorResponseDataMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType !== 2) { reader.skip(tag.wireType); continue; }
      const value = reader.readBytes();
      if (tag.fieldNumber === 1) result.page = TiebaProtoDecoder.decodePage(value);
      else if (tag.fieldNumber === 3) result.post = TiebaProtoDecoder.decodePost(value);
      else if (tag.fieldNumber === 4) result.subPostList = TiebaProtoDecoder.append(result.subPostList, TiebaProtoDecoder.decodeSubPostList(value));
      else if (tag.fieldNumber === 5) result.thread = TiebaProtoDecoder.decodeThreadInfo(value);
      else if (tag.fieldNumber === 6) result.forum = TiebaProtoDecoder.decodeSimpleForum(value);
    }
    return result;
  }

  static decodePbPageResponse(data: ArrayBuffer): PbPageResponseMessage {
    const result: PbPageResponseMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType !== 2) { reader.skip(tag.wireType); continue; }
      const value = reader.readBytes();
      if (tag.fieldNumber === 1) result.error = TiebaProtoDecoder.decodeError(value);
      else if (tag.fieldNumber === 2) result.data = TiebaProtoDecoder.decodePbPageData(value);
    }
    return result;
  }

  static decodePbPageData(data: ArrayBuffer): PbPageResponseDataMessage {
    const result: PbPageResponseDataMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const value = reader.readBytes();
        if (tag.fieldNumber === 1) result.user = TiebaProtoDecoder.decodeUser(value);
        else if (tag.fieldNumber === 2) result.forum = TiebaProtoDecoder.decodeSimpleForum(value);
        else if (tag.fieldNumber === 3) result.page = TiebaProtoDecoder.decodePage(value);
        else if (tag.fieldNumber === 4) result.anti = TiebaProtoDecoder.decodeAnti(value);
        else if (tag.fieldNumber === 6) result.postList = TiebaProtoDecoder.append(result.postList, TiebaProtoDecoder.decodePost(value));
        else if (tag.fieldNumber === 8) result.thread = TiebaProtoDecoder.decodeThreadInfo(value);
        else if (tag.fieldNumber === 13) result.userList = TiebaProtoDecoder.append(result.userList, TiebaProtoDecoder.decodeUser(value));
        else if (tag.fieldNumber === 30) result.feedThreadList = TiebaProtoDecoder.append(result.feedThreadList, TiebaProtoDecoder.decodeThreadInfo(value));
        else if (tag.fieldNumber === 39) result.displayForum = TiebaProtoDecoder.decodeSimpleForum(value);
        else if (tag.fieldNumber === 40) result.newAgreeUser = TiebaProtoDecoder.append(result.newAgreeUser, TiebaProtoDecoder.decodeSimpleUser(value));
      } else if (tag.wireType === 0) {
        const value = reader.readVarint();
        if (tag.fieldNumber === 7) result.hasFloor = value;
        else if (tag.fieldNumber === 10) result.isNewUrl = value;
        else if (tag.fieldNumber === 14) result.serverTime = value;
        else if (tag.fieldNumber === 31) result.isFollowCurrentChannel = value;
        else if (tag.fieldNumber === 32) result.switchReadOpen = value;
        else if (tag.fieldNumber === 50) result.sortType = value;
        else if (tag.fieldNumber === 68) result.hasFoldComment = value;
        else if (tag.fieldNumber === 70) result.foldCommentNum = value;
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodeUserLikeResponse(data: ArrayBuffer): UserLikeResponseMessage {
    const result: UserLikeResponseMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType !== 2) { reader.skip(tag.wireType); continue; }
      const value = reader.readBytes();
      if (tag.fieldNumber === 1) result.error = TiebaProtoDecoder.decodeError(value);
      else if (tag.fieldNumber === 2) result.data = TiebaProtoDecoder.decodeUserLikeData(value);
    }
    return result;
  }

  /**
   * 黑名单列表响应解码（Cmd 303028 / userMuteQuery）。
   * 字段编号（aiotieba/tbclient.protobuf 对照）：
   *   UserMuteQueryResIdl {
   *     data(1) { mute_user[1] { user_id(1, int64), user_name(2), mute_time(3, int32 秒级),
   *                         portrait(4), name_show(5) }, page(2) },
   *     error(2) { errorno(1, varint), errmsg(2) }
   *   }
   * mute_time 语义为「解禁时间戳（秒）」；0 表示永久屏蔽。
   * 返回 BlacklistMuteQueryResultMessage，list 每项为 BlacklistMuteUserMessage。
   */
  static decodeUserMuteQueryResponse(data: ArrayBuffer): BlacklistMuteQueryResultMessage {
    const result: BlacklistMuteQueryResultMessage = {
      list: [], hasMore: false, totalCount: 0, errorCode: 0, errorMsg: '',
    };
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType !== 2) { reader.skip(tag.wireType); continue; }
      const value = reader.readBytes();
      if (tag.fieldNumber === 1) {
        // data: DataRes
        const dataReader = new ProtoReader(value);
        while (dataReader.hasNext()) {
          const dataTag = dataReader.readTag(); if (dataTag === null) break;
          if (dataTag.wireType === 2 && dataTag.fieldNumber === 1) {
            // mute_user: repeated MuteUser
            const muBuf = dataReader.readBytes();
            const muReader = new ProtoReader(muBuf);
            const item: BlacklistMuteUserMessage = {
              userId: '', userName: '', nameShow: '', portrait: '', muteTime: 0,
            };
            while (muReader.hasNext()) {
              const muTag = muReader.readTag(); if (muTag === null) break;
              if (muTag.wireType === 0 && muTag.fieldNumber === 1) item.userId = `${muReader.readVarint()}`;
              else if (muTag.wireType === 2 && muTag.fieldNumber === 2) item.userName = muReader.readString();
              else if (muTag.wireType === 0 && muTag.fieldNumber === 3) item.muteTime = muReader.readVarint();
              else if (muTag.wireType === 2 && muTag.fieldNumber === 4) item.portrait = muReader.readString();
              else if (muTag.wireType === 2 && muTag.fieldNumber === 5) item.nameShow = muReader.readString();
              else muReader.skip(muTag.wireType);
            }
            result.list.push(item);
          } else if (dataTag.wireType === 2 && dataTag.fieldNumber === 2) {
            // page: Page（复用既有 decodePage）
            const page: PageMessage = TiebaProtoDecoder.decodePage(value);
            result.hasMore = page.hasMore === 1;
            result.totalCount = page.totalCount ?? 0;
          } else {
            dataReader.skip(dataTag.wireType);
          }
        }
      } else if (tag.fieldNumber === 2) {
        // error: Error（复用既有 decodeError）
        const err: ErrorMessage = TiebaProtoDecoder.decodeError(value);
        result.errorCode = err.errorCode ?? 0;
        result.errorMsg = err.errorMsg ?? '';
      } else {
        reader.skip(tag.wireType);
      }
    }
    return result;
  }

  /**
   * 新版设置黑名单响应解码（SetUserBlack，Cmd 309697）。
   * 结构：SetUserBlackResIdl: error(1){ errorno(1), errmsg(2) }, data(2)（空 message）。
   * 成功时 errorno=0；失败时 errorno 为非零错误码。
   */
  static decodeSetUserBlackResponse(data: ArrayBuffer): ErrorMessage {
    const result: ErrorMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.fieldNumber === 1 && tag.wireType === 2) {
        // error: Error
        const err: ErrorMessage = TiebaProtoDecoder.decodeError(reader.readBytes());
        result.errorCode = err.errorCode ?? 0;
        result.errorMsg = err.errorMsg ?? '';
      } else {
        reader.skip(tag.wireType);
      }
    }
    return result;
  }

  static decodeUserLikeData(data: ArrayBuffer): UserLikeResponseDataMessage {
    const result: UserLikeResponseDataMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const value = reader.readBytes();
        if (tag.fieldNumber === 1) result.threadInfo = TiebaProtoDecoder.append(result.threadInfo, TiebaProtoDecoder.decodeConcernData(value));
        else if (tag.fieldNumber === 2) result.pageTag = new util.TextDecoder().decode(new Uint8Array(value));
      } else if (tag.wireType === 0) {
        const value = reader.readVarint();
        if (tag.fieldNumber === 4) result.hasMore = value;
        else if (tag.fieldNumber === 10) result.requestUnix = value;
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodeConcernData(data: ArrayBuffer): ConcernDataMessage {
    const result: ConcernDataMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const value = reader.readBytes();
        if (tag.fieldNumber === 1) result.threadList = TiebaProtoDecoder.decodeThreadInfo(value);
        else if (tag.fieldNumber === 2) result.postData = TiebaProtoDecoder.decodePostData(value);
        else if (tag.fieldNumber === 5) result.recommendUserList = TiebaProtoDecoder.append(result.recommendUserList, TiebaProtoDecoder.decodeUser(value));
      } else if (tag.wireType === 0) {
        const value = reader.readVarint();
        if (tag.fieldNumber === 3) result.recommendType = value;
        else if (tag.fieldNumber === 4) result.source = value;
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodePostData(data: ArrayBuffer): PostDataMessage {
    const result: PostDataMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const value = reader.readBytes();
        if (tag.fieldNumber === 2) result.content = TiebaProtoDecoder.append(result.content, TiebaProtoDecoder.decodePbContent(value));
        else if (tag.fieldNumber === 3) result.postTitle = new util.TextDecoder().decode(new Uint8Array(value));
        else if (tag.fieldNumber === 4) result.author = TiebaProtoDecoder.decodeUser(value);
      } else if (tag.wireType === 0) {
        const value = reader.readVarint();
        if (tag.fieldNumber === 1) result.id = value;
        else if (tag.fieldNumber === 5) result.time = value;
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodePersonalizedResponse(data: ArrayBuffer): PersonalizedResponseMessage {
    const result: PersonalizedResponseMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType !== 2) { reader.skip(tag.wireType); continue; }
      const value = reader.readBytes();
      if (tag.fieldNumber === 1) result.error = TiebaProtoDecoder.decodeError(value);
      else if (tag.fieldNumber === 2) result.data = TiebaProtoDecoder.decodePersonalizedData(value);
    }
    return result;
  }

  static decodePersonalizedData(data: ArrayBuffer): PersonalizedResponseDataMessage {
    const result: PersonalizedResponseDataMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType !== 2) { reader.skip(tag.wireType); continue; }
      const value = reader.readBytes();
      if (tag.fieldNumber === 2) result.threadList = TiebaProtoDecoder.append(result.threadList, TiebaProtoDecoder.decodeThreadInfo(value));
      else if (tag.fieldNumber === 7) result.threadPersonalized = TiebaProtoDecoder.append(result.threadPersonalized, TiebaProtoDecoder.decodeThreadPersonalized(value));
    }
    return result;
  }

  static decodeThreadPersonalized(data: ArrayBuffer): ThreadPersonalizedMessage {
    const result: ThreadPersonalizedMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const value = new util.TextDecoder().decode(new Uint8Array(reader.readBytes()));
        if (tag.fieldNumber === 2) result.weight = value;
        else if (tag.fieldNumber === 3) result.source = value;
        else if (tag.fieldNumber === 6) result.extra = value;
      } else if (tag.wireType === 0) {
        const value = reader.readVarint();
        if (tag.fieldNumber === 1) result.tid = value;
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodePost(data: ArrayBuffer): PostMessage {
    const result: PostMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const value = reader.readBytes();
        if (tag.fieldNumber === 23) {
          result.author = TiebaProtoDecoder.decodeUser(value);
        } else if (tag.fieldNumber === 5) {
          result.content = TiebaProtoDecoder.append(result.content, TiebaProtoDecoder.decodePbContent(value));
        } else if (tag.fieldNumber === 15) {
          result.subPostList = TiebaProtoDecoder.decodePostSubPost(value);
        } else if (tag.fieldNumber === 37) {
          // Post 的 agree 在 field 37（n0099/tbclient.protobuf Post.proto；实测 f1=点赞数 f2=has_agree）。
          // 注意：field 126 是 ThreadInfo 的 agree 字段号，此前误用导致楼层点赞状态永远读不到
          result.agree = TiebaProtoDecoder.decodeAgree(value);
        }
      } else if (tag.wireType === 0) {
        const value = reader.readVarint();
        // ================================================================
        // 严格按语义分类：语义明确字段优先独立赋值，仅 aiotieba vs tieba-lite
        // 有明确冲突的 13/14/124/125 允许双写，其他未知字段一概不写
        // 避免 time/authorId/id 等大数字混入点赞/楼中楼候选
        // ================================================================
        if (tag.fieldNumber === 1) result.id = value;
        else if (tag.fieldNumber === 3) result.floor = value;
        else if (tag.fieldNumber === 4) result.time = value;
        else if (tag.fieldNumber === 6) result.authorId = value;
        else if (tag.fieldNumber === 19) result.authorId = value;  // 必须加回！authorId的另一种写法
        // ---------- 字段 13：sub_post_number（楼中楼数） ----------
        // n0099/tbclient.protobuf 与实测数据均确认 field 13 = sub_post_number，
        // 点赞数在 field 37 的 Agree 消息内，不再双写避免楼中楼数污染点赞数
        else if (tag.fieldNumber === 13) {
          result.subPostNumber = value;
        }
        // ---------- 字段 14：tieba-lite-harmony 中 Post 的 hasAgree（仅 0/1）----------
        else if (tag.fieldNumber === 14) {
          if (value === 0 || value === 1) {
            result.hasAgree = (result.hasAgree === 1) ? 1 : value;
          }
        }
        // ---------- 字段 124：原实现的 Post 顶层独立 agreeNum（兼容旧协议）----------
        else if (tag.fieldNumber === 124) {
          if (value >= 0 && value <= 99999999) {
            // 与 field13 的 agreeNum 候选取 max（若两者同时写入）
            result.agreeNum = Math.max(result.agreeNum ?? 0, value);
          }
        }
        // ---------- 字段 125：原实现的 Post 顶层独立 hasAgree（兼容旧协议）----------
        else if (tag.fieldNumber === 125) {
          if (value === 0 || value === 1) {
            // OR 逻辑：任一候选为 1，则 hasAgree=1
            result.hasAgree = (result.hasAgree === 1) ? 1 : value;
          }
        }
        // 其他 field（7/8/9/10/11/12/16/17/18/20 等）语义未知，一律不写入，避免污染！
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodePostSubPost(data: ArrayBuffer): PostSubPostMessage {
    const result: PostSubPostMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2 && tag.fieldNumber === 2) {
        result.subPostList = TiebaProtoDecoder.append(result.subPostList, TiebaProtoDecoder.decodeSubPostList(reader.readBytes()));
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  static decodeSubPostList(data: ArrayBuffer): SubPostListMessage {
    const result: SubPostListMessage = {};
    const reader = new ProtoReader(data);
    while (reader.hasNext()) {
      const tag = reader.readTag(); if (tag === null) break;
      if (tag.wireType === 2) {
        const value = reader.readBytes();
        if (tag.fieldNumber === 2) result.content = TiebaProtoDecoder.append(result.content, TiebaProtoDecoder.decodePbContent(value));
        else if (tag.fieldNumber === 7) result.author = TiebaProtoDecoder.decodeUser(value);
        else if (tag.fieldNumber === 5) result.title = new util.TextDecoder().decode(new Uint8Array(value));
        else if (tag.fieldNumber === 9) result.agree = TiebaProtoDecoder.decodeAgree(value);
      } else if (tag.wireType === 0) {
        const value = reader.readVarint();
        if (tag.fieldNumber === 1) result.id = value;
        else if (tag.fieldNumber === 3) result.time = value;
        else if (tag.fieldNumber === 4) result.authorId = value;
        else if (tag.fieldNumber === 6) result.floor = value;
        // ---------- 点赞相关顶层字段（与主楼层 Post 处理一致）----------
        // 历史启发式：field 124 = agreeNum / 125 = hasAgree（兼容旧协议 / pb/page 精简返回）；
        // field 14 = hasAgree（tieba-lite-harmony 协议）；field 8/10-12/16-18 = 未知字段兜底。
        // pb/page 预览接口字段号不稳定，真实点赞可能落在任意未知 varint 字段号。
        // SubPostListMessage 除已知 id(1)/time(3)/authorId(4)/floor(6) 之外的 varint 字段几乎
        // 都承载点赞相关数据，因此对所有未分配 varint 字段统一启发式归类：
        //   - 值 0/1 → hasAgree 候选（与已有候选取 OR）
        //   - 值 2 ~ 99999999 → agreeNum 候选（取 max 避免重复字段覆盖）
        // 这样无论接口字段号如何变化，都能正确捕获点赞数与已点赞状态，
        // 彻底修复 ThreadDetail 楼中楼预览点赞数恒为 0 的问题。
        else {
          if (value === 0 || value === 1) {
            if (result.hasAgree !== 1) result.hasAgree = value;
          } else if (value >= 2 && value <= 99999999) {
            result.agreeNum = Math.max(result.agreeNum ?? 0, value);
          }
        }
      } else reader.skip(tag.wireType);
    }
    return result;
  }

  private static append<T>(items: T[] | undefined, value: T): T[] {
    const next: T[] = items === undefined ? [] : items.slice();
    next.push(value);
    return next;
  }

  private static mergeMessages<T>(items: T[] | undefined, values: T[]): T[] {
    const next: T[] = items === undefined ? [] : items.slice();
    for (const value of values) {
      next.push(value);
    }
    return next;
  }

  private static appendString(items: string[] | undefined, value: string): string[] {
    const next: string[] = items === undefined ? [] : items.slice();
    next.push(value);
    return next;
  }

  private static appendNumber(items: number[] | undefined, value: number): number[] {
    const next: number[] = items === undefined ? [] : items.slice();
    next.push(value);
    return next;
  }
}
