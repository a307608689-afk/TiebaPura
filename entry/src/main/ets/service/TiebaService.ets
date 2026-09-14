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

import { hilog } from '@kit.PerformanceAnalysisKit';
import { HttpClient } from '../network/HttpClient';
import { ProtoSchema } from '../network/ProtoSchema';
import { TiebaProtoDecoder } from '../network/TiebaProtoDecoder';
import { AuthManager } from './AuthManager';
import { CacheManager } from '../cache/CacheManager';
import { API, stripHtml, extractImages, extractGroup, decodeHtmlEntities, formatTime, CACHE_KEY, CACHE_TTL } from '../common/Constants';
import { AbstractMessage, PbContentMessage, PostMessage, PostInfoListMessage, SubPostListMessage, FrsPageResponseMessage, ThreadInfoMessage, UserMessage, AgreeMessage } from '../model/TiebaProtoSchema';
import {
  ThreadItem, ThreadDetail, FloorItem, CommentItem, SubPostDetail, UserStats, PersonalContentItem,
  FollowItem, Conversation, MessageItem, PagedResult, PublishResult, ForumHeaderInfo,
  ContentFragment, ContentFragmentType, FragmentsResult, AuthorEnrichTarget, BlacklistItem,
  UserProfileModel, UserLikeItem, FollowUserItem, FollowListResult, NotifyMessage, NotifyUser,
  GlobalForumResult, GlobalForumSearchData, GlobalPostResult, GlobalPostSearchData,
  GlobalUserResult, GlobalUserSearchData, ForumSearchData
} from '../model/DataModel';

/** 拉黑精细化开关：分别控制 禁止私信/禁止关注/禁止互动 */
export interface BlacklistPermOptions {
  follow?: boolean;
  interact?: boolean;
  chat?: boolean;
}

interface ModernAuthorRecord {
  id?: string | number;
  uid?: string | number;
  name?: string;
  name_show?: string;
  nameShow?: string;
  user_name?: string;
  userName?: string;
  user_nickname?: string;
  userNickname?: string;
  nickname?: string;
  portrait?: string;
  portrait_h?: string;
  portraitH?: string;
  avatar?: string;
  avatar_url?: string;
  bimg_url?: string;
  new_icon_url?: string;
  newIconUrl?: string;
  levelId?: number;  // pb 协议 User 字段 23：吧内真实等级
}

interface ModernMediaRecord {
  pic?: string;
  src_pic?: string;
  big_pic?: string;
  origin_pic?: string;
}

interface ModernAbstractRecord {
  text?: string;
  type?: number;
  cdn_src?: string;
  big_cdn_src?: string;
  origin_src?: string;
}

interface ModernForumRecord {
  id?: string;
  name?: string;
  level_id?: string;
  level_name?: string;
  avatar?: string;
  forum_avatar?: string;
  head_url?: string;
  headPic?: string;
  head_pic?: string;
  pic?: string;
  img?: string;
  hot_num?: string | number;
  hotValue?: string;
  member_num?: string;
  is_sign?: string | number;
  isSign?: string | number;
  is_signed?: string | number;
  signed?: string | number;
  sign_status?: string | number;
  has_signed?: string | number;
  user_force?: string;
  vip_level_id?: string;
}

interface ModernAgreeRecord {
  agreeNum?: number;
  agree_num?: number;
  hasAgree?: number;
  has_agree?: number;
  agreeType?: number;
  agree_type?: number;
}

interface ModernThreadRecord {
  tid?: string;
  id?: string | number;
  title?: string;
  thread_id?: string | number;
  threadId?: string | number;
  post_id?: string | number;
  fname?: string;
  forum_name?: string;
  fid?: string | number;
  forum_id?: string | number;
  reply_num?: string | number;
  is_top?: string | number;
  is_good?: string | number;
  isGood?: string | number;
  agree?: ModernAgreeRecord;
  agree_num?: string | number;
  agreeNum?: string | number;
  has_agree?: string | number;
  hasAgree?: string | number;
  agree_type?: string | number;
  agreeType?: string | number;
  last_time?: string;
  author?: ModernAuthorRecord;
  author_id?: string | number;
  user_id?: string | number;
  authorId?: string | number;
  media?: ModernMediaRecord[];
  abstract?: ModernAbstractRecord[] | string;
  forum_info?: ModernForumInfo;
  first_post_content?: string;
  create_time?: string;
  last_replyer?: string;
  topic_user_name?: string;
}

interface ModernForumInfo {
  name?: string;
  id?: string;
  avatar?: string;
}

interface ModernForumGroup {
  non_gconforum?: ModernForumRecord[];
}

interface ModernPostContentRecord {
  text?: string;
  type?: number;
  link?: string;
  c?: string;
  src?: string;
  big_src?: string;
  cdn_src?: string;
  big_cdn_src?: string;
  origin_src?: string;
  meme_pic_url?: string;
  meme_pck_id?: number;
  meme_pic_id?: number;
}

interface ModernSubPostRecord {
  id?: string | number;
  floor?: number;
  time?: string | number;
  author?: ModernAuthorRecord;
  author_id?: string | number;
  post_id?: string | number;
  reply_to_id?: string | number;
  content?: ModernPostContentRecord[];
  agree?: ModernAgreeRecord;
}

interface ModernPostRecord {
  id?: string | number;
  agree?: ModernAgreeRecord;
  agree_num?: string | number;
  agreeNum?: string | number;
  has_agree?: string | number;
  hasAgree?: string | number;
  agree_type?: string | number;
  agreeType?: string | number;
  sub_post_number?: string | number;
  floor?: number;
  floor_num?: number | string;
  floorNum?: number | string;
  post_no?: number | string;
  postNo?: number | string;
  time?: string | number;
  author?: ModernAuthorRecord;
  author_id?: string | number;
  content?: ModernPostContentRecord[];
  sub_post_list?: ModernSubPostRecord[];
  subPostList?: ModernSubPostRecord[];
}

interface ModernApiPayload {
  error_code?: string | number;
  error_msg?: string;
  time?: string | number;
  thread_list?: ModernThreadRecord[];
  post_list?: ModernPostRecord[];
  user_list?: ModernAuthorRecord[];
  thread?: ModernThreadRecord;
  forum?: ModernForumInfo;
  forum_list?: ModernForumGroup;
  common_forum_list?: ModernForumGroup;
  has_more?: string;
  total_page?: number | string;
  current_page?: number | string;
  page_size?: number | string;
  total_count?: number | string;
}

interface WebWriteForm {
  ie: string;
  kw: string;
  fid: string;
  tid: string;
  vcode_md5?: string;
  title?: string;
  content: string;
  rich_text: string;
  anonymous: string;
  __type__?: string;
  tbs: string;
  floor_num?: string;
}

interface ModernRequestForm {
  _client_type?: string;
  protobufData?: ArrayBuffer;
  _client_version?: string;
  _os_version?: string;
  client_type?: string;
  friend_uid?: string;
  is_guest?: string;
  kz?: string;
  kw?: string;
  thread_id?: string;
  post_id?: string;
  load_type?: string;
  need_forumlist?: string;
  need_tags?: string;
  new_install?: string;
  new_net_type?: string;
  page_no?: string;
  page_size?: string;
  page_thread_count?: string;
  pn?: string;
  q_type?: string;
  request_time?: string;
  rn?: string;
  scr_dip?: string;
  scr_h?: string;
  scr_w?: string;
  sort_type?: string;
  st_type?: string;
  uid?: string;
  with_group?: string;
  is_good?: string;
  lz?: string;
  r?: string;
  back?: string;
  floor_rn?: string;
  mark?: string;
  with_floor?: string;
  floor_sort_type?: string;
  comment_rn?: string;
}

interface SignForumResult {
  signDays: number;
  bonusNum: number;
}

const TIEBA_BASE: string = 'https://tieba.baidu.com';

/** PC 网页「全吧搜索」签名密钥（aiotieba _pc_sign：参数按 key 升序拼 key=value... 后追加密钥取小写 MD5） */
const SEARCH_PC_SECRET: string = '36770b1f34c9bbf2e7d1a99d2b82fa9e';

/**
 * 全吧搜索排序参数 st（aiotieba GlobalSearchSortType）：0 = 最早发帖 / 2 = 最相关 / 5 = 最新发帖，
 * 服务端只认这三个取值。搜贴端点 /mo/q/search/thread 严格按该枚举过滤，此前传 '1' 属非法值，
 * 服务端会直接返回空 post_list，表现为「搜贴永远显示没有找到相关帖子」。搜吧/搜人端点忽略该值。
 */
const SEARCH_SORT_THREAD: string = '5';

export interface ThreadDetailResult {
  detail: ThreadDetail;
  floors: FloorItem[];
}

interface ThreadDetailCacheEntry {
  result: ThreadDetailResult;
  time: number;
}

interface CollectionData {
  tid: string;
  pid: string;
  status: number;
  fid?: string;
}

interface CollectionVariant {
  label: string;
  data: string;
}

interface UserInfoResult {
  name: string;
  avatar: string;
  userId: string;
}

/**
 * 贴吧数据服务层：抓取网页并解析为结构化数据。
 * 由于贴吧无公开官方 API，采用「网页 HTML 解析 + 内嵌 JSON」策略。
 */
export class TiebaService {
  private static readonly TAG: string = 'TiebaService';
  private static instance: TiebaService | null = null;
  /** 服务器时间 - 本地时间 的偏移（毫秒），由 /c/s/login 响应的 time 字段校准 */
  private static serverTimeOffsetMs: number = 0;
  private cachedForumHeader: ForumHeaderInfo | null = null;
  /**
   * proto（protobuf）列表接口连续失败次数：接口返回异常/风控/挂起超时时递增。
   * 达到 2 次后本会话内跳过 proto 直接走 modern JSON 接口——被风控时每次都会挂满超时
   * （withTimeout 2s），反复切换排序/翻页会让每次请求都白等 2s；modern 稳定且速度不差。
   * 单次成功（含返回空列表，代表接口连通）即清零。
   */
  private protoFailStreak: number = 0;
  /** 作者 id -> 已确认的展示名（来源：profile 实时昵称/详情页回填），用于校准列表页过期/缺失昵称 */
  private authorNickCache: Map<string, string> = new Map<string, string>();
  /** 作者 id -> 该昵称已由 profile 实时接口确认（权威值，区别于详情页回填的过渡值） */
  private authorNickProfileConfirmed: Set<string> = new Set<string>();
  /** 本会话内已确认“无有效昵称”的作者 id（避免每次翻页都重复请求触发风控） */
  private authorNickNoResult: Set<string> = new Set<string>();
  /** 昵称缓存是否已从本地 Preferences 恢复（冷启动后首次校准前加载一次） */
  private authorNickCacheLoaded: boolean = false;
  /** 昵称缓存写盘防抖定时器（合并 500ms 内的多次校准写入，避免频繁 IO） */
  private nickPersistTimer: number = -1;

  static getInstance(): TiebaService {
    if (TiebaService.instance === null) {
      TiebaService.instance = new TiebaService();
    }
    return TiebaService.instance;
  }

  getCachedForumHeader(): ForumHeaderInfo | null {
    return this.cachedForumHeader;
  }

  /**
   * 读取作者权威昵称，用于列表页校准过期/缺失昵称（推荐页/吧列表 onPageShow 回填刷新）。
   * v1.22 放宽 confirmed 限制：authorNickCache 的写入路径（rememberAuthor / profile 实时拉取）
   * 均已过滤占位名/系统名，详情页回填的过渡昵称同样可用于列表页对齐——
   * parseModernThreads 已无条件使用 authorNickCache.get()，此处若仍要求 confirmed，
   * 会导致「从详情页返回推荐页」时 refreshAuthorsFromCache 读不到刚回填的昵称，
   * 推荐页仍显示“吧友XXXX”直到重新下拉刷新。放宽后两者口径一致。
   */
  getCachedAuthorName(authorId: string): string | undefined {
    const key: string = `${authorId ?? ''}`.trim();
    if (key.length === 0) {
      return undefined;
    }
    const name: string | undefined = this.authorNickCache.get(key);
    if (name === undefined || name.length === 0) {
      return undefined;
    }
    return name;
  }

  /**
   * 把已确认的实时昵称写入作者缓存（排除占位名/系统名，避免污染列表显示）。
   * @param record   作者记录
   * @param confirmed 来源可靠（详情页 proto user_list 实时昵称）时标记权威确认，
   *                  列表页 onPageShow 的 refreshAuthorsFromCache 读取即可直接对齐；
   *                  profile 已确认且昵称不同的更高优先，不被覆盖。
   */
  private rememberAuthor(record?: ModernAuthorRecord, confirmed: boolean = false): void {
    if (!record) {
      return;
    }
    const uid: string = `${record.id ?? record.uid ?? ''}`.trim();
    if (uid.length === 0) {
      return;
    }
    const name: string = this.displayAuthor(record);
    if (name.length === 0 || name === '贴吧用户' || name.startsWith('贴吧用户_') || name.startsWith('吧友')) {
      return;
    }
    if (confirmed) {
      // 详情页实时昵称视为权威：profile 已确认且昵称不同时保留 profile（更高优先），
      // 否则写入并标记 confirmed，让首页返回时 refreshAuthorsFromCache 直接对齐详情页
      if (!this.authorNickProfileConfirmed.has(uid) || this.authorNickCache.get(uid) === name) {
        this.authorNickCache.set(uid, name);
        this.authorNickProfileConfirmed.add(uid);
        this.persistAuthorNickCache();
      }
      return;
    }
    // 过渡昵称：不覆盖 profile 已确认的权威值；同级已有值时以最新为准
    if (!this.authorNickProfileConfirmed.has(uid)) {
      this.authorNickCache.set(uid, name);
    }
  }

  /** 判断昵称是否仅由空白/不可见字符组成（如零宽空格 U+200B/U+FEFF、韩文填充符等） */
  private isInvisibleNickname(name: string): boolean {
    return name.replace(/[\s\u200b-\u200f\u2060-\u206f\ufeff\u115f\u1160\u3164\u00ad]/g, '').length === 0;
  }

  /**
   * 拉取单个用户的实时昵称（proto profile 接口）。
   * 首页 JSON 个性化接口的 thread.author 常缺 name_show（显示“吧友XXXX”/“贴吧用户_xxx”），
   * 而 profile 接口返回完整 User（name_show / name），用于首页直接校准，无需先点开详情页。
   * 失败或无有效昵称时返回空串，调用方静默保留占位名。
   */
  async fetchUserNickname(userId: string): Promise<string> {
    // 冷启动后首次调用前先恢复本地昵称缓存，避免重启后对已确认作者重复拉 profile
    await this.ensureAuthorNickCacheLoaded();
    const uid: string = `${userId ?? ''}`.trim();
    if (uid.length === 0 || uid === '0') {
      return '';
    }
    // 仅 profile 实时接口确认的缓存可直接返回；详情页回填的过渡值仍需走 profile 重拉校准
    if (this.authorNickProfileConfirmed.has(uid)) {
      const cached: string | undefined = this.authorNickCache.get(uid);
      if (cached !== undefined && cached.length > 0) {
        return cached;
      }
    }
    // 本会话已确认该用户无有效昵称，跳过避免重复请求
    if (this.authorNickNoResult.has(uid)) {
      return '';
    }
    try {
      const common = ProtoSchema.commonRequest(new Map<string, string | number>([
        ['_client_type', 2],
        ['_client_version', '12.41.7.1'],
        ['_os_version', '26'],
        ['model', 'HarmonyOS'],
        ['brand', 'Huawei'],
        ['net_type', 1],
        ['scr_w', 360],
        ['scr_h', 800],
        ['scr_dip', 1],
        ['pversion', '1.0.3'],
        ['BDUSS', AuthManager.getInstance().getBduss()]
      ]));
      const request = ProtoSchema.profileRequest(uid, 1, common);
      const binary = await HttpClient.postProtoMultipart('https://c.tieba.baidu.com/c/u/user/profile?cmd=303012', request, {
        'User-Agent': 'tieba/12.41.7.1',
        'Accept': 'application/octet-stream',
        'X-BD-DATA-TYPE': 'protobuf',
        'Client-Type': '2',
        'Charset': 'UTF-8',
        'Referer': 'https://tieba.baidu.com/'
      });
      const decoded = TiebaProtoDecoder.decodeProfileResponse(binary);
      const errorCode = decoded.error?.errorCode ?? 0;
      if (errorCode !== 0) {
        return '';
      }
      const user = decoded.data?.user;
      const rawNameShow: string = `${user?.nameShow ?? ''}`.trim();
      const rawName: string = `${user?.name ?? ''}`.trim();
      let nickname: string = (rawNameShow.length > 0 && !rawNameShow.startsWith('贴吧用户_'))
        ? rawNameShow
        : (rawName.length > 0 ? rawName : '');
      nickname = nickname.trim();
      // 排除仅由不可见字符组成的“空”昵称（零宽空格等），避免列表显示空白
      if (nickname.length > 0 && nickname !== '贴吧用户' && !nickname.startsWith('吧友') && !this.isInvisibleNickname(nickname)) {
        this.authorNickCache.set(uid, nickname);
        this.authorNickProfileConfirmed.add(uid);
        this.persistAuthorNickCache();
        console.info(`[ENRICH] profile uid=${uid} -> [${nickname}]`);
        return nickname;
      }
      this.authorNickNoResult.add(uid);
      console.info(`[ENRICH] profile uid=${uid} 无有效昵称 rawNameShow=[${rawNameShow}] rawName=[${rawName}]`);
    } catch (e) {
      console.info(`[ENRICH] profile uid=${uid} 请求失败，保留占位名`);
    }
    return '';
  }

  /**
   * 列表昵称校准：对缓存中无已确认昵称的作者并发拉取 profile 实时昵称，
   * 直接更新列表项，实现列表页与详情页名称完全一致（无需先点开详情页）。
   * 覆盖全部作者（不只占位名）：接口 JSON 的 name_show 可能是过期/缓存的昵称，
   * 与 profile 实时昵称不一致，全量校准才能保证显示一致。
   */
  async enrichHomeAuthors(list: ThreadItem[]): Promise<ThreadItem[]> {
    const refreshed: AuthorEnrichTarget[] = await this.enrichAuthorsGeneric(list.map((item: ThreadItem): AuthorEnrichTarget => ({
      authorId: item.authorId,
      author: item.author,
    })));
    for (let i = 0; i < refreshed.length; i++) {
      list[i].author = refreshed[i].author;
    }
    return list;
  }

  /** 通用作者昵称校准：按 authorId 批量拉取 profile 实时昵称并覆盖显示名 */
  async enrichAuthorsGeneric(list: AuthorEnrichTarget[]): Promise<AuthorEnrichTarget[]> {
    // 冷启动后首次校准前，先从本地恢复已确认的昵称缓存（TTL 7 天），避免重启 App 后重复拉 profile
    await this.ensureAuthorNickCacheLoaded();
    const pendingIds: string[] = [];
    const pendingIndex: Map<string, number[]> = new Map<string, number[]>();
    for (let i = 0; i < list.length; i++) {
      const item: AuthorEnrichTarget = list[i];
      const authorId: string = `${item.authorId ?? ''}`.trim();
      if (authorId.length === 0 || authorId === '0') {
        continue;
      }
      // 缓存已有 profile 实时接口确认的权威昵称：直接校准到与详情页一致
      if (this.authorNickProfileConfirmed.has(authorId)) {
        const cached: string | undefined = this.authorNickCache.get(authorId);
        if (cached !== undefined && cached.length > 0 && cached !== item.author) {
          item.author = cached;
        }
        continue;
      }
      // 详情页回填的过渡昵称可能来自旧接口缓存，仍需 profile 重拉校准；
      // 但若 profile 已确认该用户无有效昵称（风控/占位），回退使用详情页缓存的过渡值
      if (this.authorNickNoResult.has(authorId)) {
        const fallback: string | undefined = this.authorNickCache.get(authorId);
        if (fallback !== undefined && fallback.length > 0 && fallback !== item.author) {
          item.author = fallback;
        }
        continue;
      }
      if (!pendingIndex.has(authorId)) {
        pendingIndex.set(authorId, []);
      }
      pendingIndex.get(authorId)!.push(i);
      if (pendingIndex.get(authorId)!.length === 1) {
        pendingIds.push(authorId);
      }
    }
    if (pendingIds.length === 0) {
      return list;
    }
    console.info(`[ENRICH] 首页作者昵称待校准 ${pendingIds.length} 个: ${pendingIds.join(',')}`);
    // 并发 12 个一组拉取；单次请求最多等 1.2s、整体最多 4 秒（按剩余时间递减），
    // 超时则跳过——未确认/未记失败的作者下次进入该列表时自动重试，昵称校准不拖慢首屏。
    // v1.22 单请求超时与总 deadline 放宽（此前 600ms/2s 在模拟器弱网下 profile 往返
    // 偶发超时 → 该作者保留“吧友XXXX”，且 enrich 只在重新拉列表时触发，页面上一直不更新）
    const CHUNK_SIZE: number = 12;
    const ENRICH_DEADLINE: number = 4000;
    const deadline: number = Date.now() + ENRICH_DEADLINE;
    for (let i = 0; i < pendingIds.length; i += CHUNK_SIZE) {
      const remaining: number = deadline - Date.now();
      if (remaining <= 0) {
        break;
      }
      const chunk: string[] = pendingIds.slice(i, i + CHUNK_SIZE);
      const results: string[] = await Promise.all(chunk.map((uid: string): Promise<string> =>
        this.fetchUserNicknameWithin(uid, Math.min(1200, remaining))));
      for (let j = 0; j < chunk.length; j++) {
        const nickname: string = results[j];
        if (nickname.length === 0) {
          continue;
        }
        // 统一刷新该作者在列表中的全部项
        const indexes: number[] = pendingIndex.get(chunk[j]) ?? [];
        for (const idx of indexes) {
          if (list[idx].author !== nickname) {
            list[idx].author = nickname;
          }
        }
      }
    }
    return list;
  }

  /** 单次昵称拉取带超时保护：网络异常/风控挂起时最多等待 timeoutMs，超时返回空串（下次进入列表自动重试） */
  private fetchUserNicknameWithin(userId: string, timeoutMs: number): Promise<string> {
    return new Promise<string>((resolve) => {
      let settled: boolean = false;
      const settle = (value: string): void => {
        if (!settled) {
          settled = true;
          resolve(value);
        }
      };
      this.fetchUserNickname(userId).then((v: string): void => {
        settle(v);
      }).catch((): void => {
        settle('');
      });
      setTimeout((): void => {
        settle('');
      }, timeoutMs);
    });
  }

  /** 冷启动后从本地 Preferences 恢复 profile 确认的昵称缓存（TTL 7 天，仅执行一次；失败静默降级为内存态） */
  private ensureAuthorNickCacheLoaded(): Promise<void> {
    if (this.authorNickCacheLoaded) {
      return Promise.resolve();
    }
    return CacheManager.getInstance().getWithTtl<Record<string, string>>(CACHE_KEY.AUTHOR_NICK).then((map: Record<string, string> | undefined): void => {
      this.authorNickCacheLoaded = true;
      if (map === undefined || map === null) {
        return;
      }
      let loaded: number = 0;
      for (const uid of Object.keys(map)) {
        const name: string = `${map[uid] ?? ''}`.trim();
        // 过滤占位名/系统名/不可见字符，避免污染列表显示
        if (name.length === 0 || name === '贴吧用户' || name.startsWith('吧友') || this.isInvisibleNickname(name)) {
          continue;
        }
        this.authorNickProfileConfirmed.add(uid);
        if (!this.authorNickCache.has(uid)) {
          this.authorNickCache.set(uid, name);
        }
        loaded++;
      }
      if (loaded > 0) {
        console.info(`[ENRICH] 从本地恢复昵称缓存 ${loaded} 条`);
      }
    }).catch((): void => {
      this.authorNickCacheLoaded = true;
    });
  }

  /** 昵称缓存写盘（防抖 500ms 合并多次校准结果，避免频繁 IO） */
  private persistAuthorNickCache(): void {
    if (this.nickPersistTimer >= 0) {
      clearTimeout(this.nickPersistTimer);
    }
    this.nickPersistTimer = setTimeout((): void => {
      this.nickPersistTimer = -1;
      this.flushAuthorNickCacheToDisk();
    }, 500);
  }

  /** 把 profile 确认的昵称缓存（uid -> 昵称）整体写入本地（TTL 7 天） */
  private async flushAuthorNickCacheToDisk(): Promise<void> {
    try {
      const map: Record<string, string> = {};
      this.authorNickCache.forEach((name: string, uid: string): void => {
        if (this.authorNickProfileConfirmed.has(uid)) {
          map[uid] = name;
        }
      });
      const keys: string[] = Object.keys(map);
      if (keys.length === 0) {
        return;
      }
      await CacheManager.getInstance().putWithTtl(CACHE_KEY.AUTHOR_NICK, map, CACHE_TTL.AUTHOR_NICK);
      console.info(`[ENRICH] 昵称缓存已持久化 ${keys.length} 条`);
    } catch (e) {
      // 持久化失败静默忽略，不影响列表显示
    }
  }

  /**
   * 获取首页热门/推荐帖子列表（个性化信息流）
   * @param page 页码（从 1 开始）
   * @param enrichAuthors 是否同步校准作者昵称（false 时由调用方后台校准，不阻塞首屏）
   * @param pageCount 单次请求条数；开启「仅推荐关注的吧」时调用方传大值（如 60），
   *                  过滤后仍能凑够正常数量，避免频繁翻页影响流畅性
   */
  async fetchHomeThreads(page: number = 1, enrichAuthors: boolean = true, pageCount: number = 15): Promise<PagedResult<ThreadItem>> {
    try {
      const payload = await this.requestModernApi(API.PERSONALIZED, {
        load_type: page === 1 ? '1' : '2',
        pn: `${page}`,
        _client_version: '11.10.8.6',
        page_thread_count: `${pageCount}`,
        need_tags: '0',
        need_forumlist: '0',
        q_type: '1',
        new_net_type: '1',
        new_install: '0',
        request_time: `${Date.now()}`,
        client_type: '2',
        _os_version: '26',
        _client_type: '2',
        scr_dip: '1',
        scr_h: '800',
        scr_w: '360',
      });
      // 诊断日志：登录态下确认个性化接口返回的 user_list 昵称质量（对比详情页）
      const ulDiag: ModernAuthorRecord[] = payload.user_list ?? [];
      console.info(`[AUTHORDIAG] personalized: code=${payload.error_code} userList=${ulDiag.length} threadList=${(payload.thread_list ?? []).length}`);
      console.info(`[AUTHORDIAG] payloadKeys=${Object.keys(payload).join(',')}`);
      const tDiag0: ModernThreadRecord | undefined = payload.thread_list?.[0];
      const tDiag1: ModernThreadRecord | undefined = payload.thread_list?.[1];
      console.info(`[AUTHORDIAG] thread[0].author=${JSON.stringify(tDiag0?.author)} lastReplyer=${tDiag0?.last_replyer ?? ''}`);
      console.info(`[AUTHORDIAG] thread[1].author=${JSON.stringify(tDiag1?.author)} lastReplyer=${tDiag1?.last_replyer ?? ''}`);
      console.info(`[AUTHORDIAG] userList[0..4]: ${ulDiag.slice(0, 5).map((u: ModernAuthorRecord): string => `${u.id ?? u.uid ?? '?'}=${u.name_show ?? u.nameShow ?? '(无名)'}(${u.name ?? ''})`).join(' | ')}`);
      const modernList = this.parseModernThreads(payload, page);
      if (modernList.list.length > 0) {
        // 首页直接校准占位昵称（吧友XXXX/贴吧用户_xxx）：并发拉取 profile 实时昵称后返回，
        // 与 TiebaLite 首页行为一致——浏览首页即显示实时昵称，无需先点开详情页
        // enrichAuthors=false 时由调用方先渲染再后台校准，不阻塞首屏
        if (enrichAuthors) {
          const enriched: ThreadItem[] = await this.enrichHomeAuthors(modernList.list);
          return { list: enriched, hasMore: modernList.hasMore, page };
        }
        return { list: modernList.list, hasMore: modernList.hasMore, page };
      }
    } catch (e) {
      // 新版接口受风控或网络环境影响时继续使用公开网页兜底。
    }
    try {
      // 网页首页与贴吧列表一样使用帖子偏移量：第 1 页为 0，第 n 页为 (n - 1) * 30。
      const url = `${API.HOME}${(page - 1) * 30}`;
      const html = await HttpClient.get(url);
      const homeResult = this.parseHomeThreads(html, page);
      if (homeResult.list.length > 0) {
        return homeResult;
      }
    } catch (e) {
      // 网页首页失败时继续进入公开贴吧兜底，不把重定向错误直接呈现给用户。
    }
    // 首页推荐接口在未登录、风控或网页结构变化时可能返回空壳页面。
    // 使用公开贴吧列表作为未登录兜底，保证推荐页仍可浏览内容。
    const fallbackForums: string[] = ['手机', '数码'];
    const merged: ThreadItem[] = [];
    const seen: Set<string> = new Set<string>();
    for (const forumName of fallbackForums) {
      try {
        const result = await this.fetchForumThreads(forumName, page);
        for (const item of result.list) {
          if (!seen.has(item.tid)) {
            seen.add(item.tid);
            merged.push(item);
          }
        }
      } catch (e) {
        // 单个贴吧不可用时继续读取其他公开贴吧。
      }
    }
    // 公开列表的分页标记经常缺失；只要当前页有数据就允许继续请求下一页，
    // 由首页的连续空页保护负责停止，避免“服务端误报无更多”导致推荐流卡死。
    return { list: merged, hasMore: merged.length > 0, page };
  }

  /**
   * 聚合拉取我关注用户的最新发帖（关注动态页数据源，支持首屏流式）。
   * 策略：拉取关注用户列表（最多 FOLLOW_FEED_MAX_USERS 个）→ 小批并发（每批 8 个）
   * 拉取每个用户的最新发帖（每人 1 页，enrich=false 跳过昵称校准）→ 合并去重 → 按发帖时间倒序。
   * 流式：每批到达即回调当前全量快照（onBatch），调用方可即时渲染首屏，无需等待全部批次；
   * 后续批次到达仅增量插入（ForEach 按 tid 复用节点），总请求数不变。
   * 说明：关注列表接口不返回关注/活跃时间，无法预知“近期更新用户”，
   * 采用“按最新发帖时间倒序”让近期活跃用户的帖子自然排前，长期不活跃者自然沉底。
   * 不缓存：调用方每次切换/刷新都重新拉取，保证最新。
   */
  async fetchFollowingUserFeed(onBatch?: (items: ThreadItem[]) => void): Promise<ThreadItem[]> {
    const user = AuthManager.getInstance().getUser();
    if (!user || user.userId.length === 0) {
      return [];
    }
    const maxUsers: number = 20;
    const concurrency: number = 12;
    // 关注用户列表：优先用本地缓存（关注列表变化不频繁，过期 stale 亦可复用）。
    // 命中则跳过列表网络请求直接并发拉各人最新发帖，省掉冷启动最前面的一次列表 RTT；
    // 缓存命中时后台静默刷新列表缓存（不阻塞聚合），下次进入用新列表。
    const usersCacheKey: string = `${CACHE_KEY.FOLLOW_USERS}_${user.userId}`;
    let users: FollowUserItem[] = [];
    let usersLoadedFromCache: boolean = false;
    try {
      const cached = await CacheManager.getInstance().getWithTtlAllowStale<FollowUserItem[]>(usersCacheKey);
      if (cached !== undefined && cached.data.length > 0) {
        users = cached.data;
        usersLoadedFromCache = true;
      }
    } catch (e) {
    }
    if (users.length === 0) {
      // 无缓存：关注用户列表并发拉取（前 2 页同时请求，替代串行 while，首轮等待减半）；
      // 仍不足 20 人且第一页有更多时补拉第 3 页（覆盖极少见的大关注量账号）。
      const userPages: FollowListResult[] = await Promise.all([
        this.fetchFollowUserList(0, 20).catch((): FollowListResult => ({ list: [], hasMore: false, total: 0, page: 0 })),
        this.fetchFollowUserList(1, 20).catch((): FollowListResult => ({ list: [], hasMore: false, total: 0, page: 1 })),
      ]);
      for (const r of userPages) {
        users.push(...r.list);
      }
      if (users.length < maxUsers && userPages[0].hasMore) {
        const r3: FollowListResult = await this.fetchFollowUserList(2, 20)
          .catch((): FollowListResult => ({ list: [], hasMore: false, total: 0, page: 2 }));
        users.push(...r3.list);
      }
      // 主流程已拉到列表：异步回写缓存（不阻塞聚合），下次进入/刷新直接命中
      if (users.length > 0) {
        CacheManager.getInstance().putWithTtl(usersCacheKey, users.slice(0, maxUsers), CACHE_TTL.FOLLOW_USERS).catch((): void => {
        });
      }
    } else if (usersLoadedFromCache) {
      // 缓存命中：后台刷新关注列表（新关注/取关的用户下次生效），失败静默保留旧值
      this.refreshFollowUsersCache(usersCacheKey, maxUsers).catch((): void => {
      });
    }
    const effectiveUsers: FollowUserItem[] = users.slice(0, maxUsers);
    if (effectiveUsers.length === 0) {
      return [];
    }
    const all: ThreadItem[] = [];
    // 与 all 对齐的原始时间戳（毫秒）：createTime 入列即格式化为展示串，
    // 排序用 rawTs 而非解析格式化串（"x分钟前/日期"无法被 parseFeedTs 还原），保证增量插入重排正确。
    const rawTs: number[] = [];
    const seen: Set<string> = new Set<string>();
    // 单用户发帖请求限时包装：最坏 5s 返回（超时按空处理），个别用户接口挂起不拖累整体（增量渲染下仅延迟该用户）
    const fetchOne = (uid: string): Promise<PersonalContentItem[]> => new Promise<PersonalContentItem[]>((resolve) => {
      let settled: boolean = false;
      const timer: number = setTimeout(() => {
        settled = true;
        resolve([]);
      }, 5000);
      this.fetchUserContent(uid, 1, true, false).then((v: PersonalContentItem[]) => {
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          resolve(v);
        }
      }).catch((): void => {
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          resolve([]);
        }
      });
    });
    // 并发窗口先到先得聚合：窗口内用户并发拉取，任何用户返回立即合并入全量列表并回调，
    // 首屏只需等待最快的用户（≈单个帖子请求耗时），慢用户不再拖垮整体。
    // 单个用户结果按发帖时间倒序线性插入（列表短，插入即保持全局有序），去重沿用 seen。
    return new Promise<ThreadItem[]>((resolve) => {
      let cursor: number = 0;
      let pending: number = 0;
      const mergeUser = (u: FollowUserItem, items: PersonalContentItem[]): void => {
        for (const item of items) {
          if (item.tid.length === 0 || seen.has(item.tid)) {
            continue;
          }
          seen.add(item.tid);
          const ts: number = this.parseFeedTs(item.createTime);
          let pos: number = all.length;
          while (pos > 0 && rawTs[pos - 1] < ts) {
            pos--;
          }
          all.splice(pos, 0, {
            tid: item.tid,
            postId: item.id,
            forumId: item.forumId ?? '',
            title: item.title,
            forumName: item.forumName,
            forumAvatar: item.forumAvatar ?? '',
            // 跳过昵称校准后用关注列表昵称（已处理占位回退），避免额外 profile 请求
            author: u.name,
            authorId: item.authorId ?? u.userId,
            authorAvatar: u.avatar,
            replyNum: item.replyNum,
            likeCount: 0,
            isLiked: false,
            abstract: item.abstract,
            firstImage: (item.images && item.images.length > 0) ? item.images[0] : '',
            images: item.images ?? [],
            createTime: formatTime(item.createTime),
            isTop: false,
            isGood: false,
            isFeatured: false,
          });
          rawTs.splice(pos, 0, ts);
        }
      };
      const pump = (): void => {
        while (pending < concurrency && cursor < effectiveUsers.length) {
          const u: FollowUserItem = effectiveUsers[cursor];
          cursor++;
          pending++;
          fetchOne(u.userId).then((items: PersonalContentItem[]): void => {
            mergeUser(u, items);
            pending--;
            // 先到先得增量回调：有内容即展示（ForEach 按 tid 复用节点，新帖插入正确位置，无整列闪烁）；
            // 中间空态不回调，避免"暂无关注动态"空态先闪现再被内容替换
            if (all.length > 0 && onBatch) {
              onBatch(all.slice());
            }
            pump();
          });
        }
        if (pending === 0 && cursor >= effectiveUsers.length) {
          // 全部完成：无论空不空最终回调一次（空 → Empty 判定），保证最终态正确
          if (onBatch) {
            onBatch(all.slice());
          }
          resolve(all);
        }
      };
      pump();
    });
  }

  /** 后台刷新关注用户列表缓存（fetchFollowingUserFeed 的后台任务）：成功回写 TTL 缓存，失败静默保留旧值 */
  private async refreshFollowUsersCache(cacheKey: string, maxUsers: number): Promise<void> {
    const pages: FollowListResult[] = await Promise.all([
      this.fetchFollowUserList(0, 20).catch((): FollowListResult => ({ list: [], hasMore: false, total: 0, page: 0 })),
      this.fetchFollowUserList(1, 20).catch((): FollowListResult => ({ list: [], hasMore: false, total: 0, page: 1 })),
    ]);
    const list: FollowUserItem[] = [];
    for (const r of pages) {
      list.push(...r.list);
    }
    if (list.length < maxUsers && pages[0].hasMore) {
      const r3: FollowListResult = await this.fetchFollowUserList(2, 20)
        .catch((): FollowListResult => ({ list: [], hasMore: false, total: 0, page: 2 }));
      list.push(...r3.list);
    }
    if (list.length > 0) {
      await CacheManager.getInstance().putWithTtl(cacheKey, list.slice(0, maxUsers), CACHE_TTL.FOLLOW_USERS);
    }
  }

  /** 解析帖子时间字符串 → 毫秒时间戳（兼容秒级/毫秒级数字与格式化字符串） */
  private parseFeedTs(createTime: string): number {
    if (!createTime) {
      return 0;
    }
    const t: number = Number(createTime);
    if (!isNaN(t) && t > 0) {
      return t < 1e12 ? t * 1000 : t;
    }
    const d: number = new Date(createTime.replace(/-/g, '/')).getTime();
    return isNaN(d) ? 0 : d;
  }

  /**
   * 获取某个吧的帖子列表
   */
  async fetchForumThreads(forumName: string, page: number = 1, sortType: number = 0, enrichAuthors: boolean = true): Promise<PagedResult<ThreadItem>> {
    const isGoodMode: boolean = sortType === 2;
    const t0: number = Date.now();
    console.info(`[FRS] enter kw=${forumName} page=${page} sort=${sortType} isGood=${isGoodMode}`);
    if (this.protoFailStreak >= 2) {
      // 本会话 proto 已连续失败 2 次（多为风控/挂起超时），不再反复白等，直接走 modern
      console.info(`[FRS] proto SKIP kw=${forumName} sort=${sortType} failStreak=${this.protoFailStreak}`);
    } else {
      try {
        const protoResult = await this.requestForumThreadsProto(forumName, page, sortType, isGoodMode, enrichAuthors);
        if (protoResult.list.length > 0) {
          console.info(`[FRS] proto OK kw=${forumName} sort=${sortType} n=${protoResult.list.length} cost=${Date.now() - t0}ms`);
          this.protoFailStreak = 0;
          return protoResult;
        }
        // 返回空列表也代表接口连通正常，不清零会导致误判为持续失败
        console.info(`[FRS] proto EMPTY kw=${forumName} sort=${sortType} cost=${Date.now() - t0}ms`);
        this.protoFailStreak = 0;
      } catch (e) {
        console.info(`[FRS] proto FAIL kw=${forumName} sort=${sortType} cost=${Date.now() - t0}ms err=${(e as Error).message}`);
        // Protobuf 接口受风控或网络环境影响时继续使用 JSON/网页兜底。
        this.protoFailStreak++;
      }
    }
    try {
      const payload = await this.requestModernApi(API.FORUM_PAGE, {
        kw: forumName,
        pn: `${page}`,
        sort_type: isGoodMode ? '0' : `${sortType}`,
        is_good: isGoodMode ? '1' : '0',
        q_type: '2',
        st_type: 'tb_forumlist',
        with_group: '0',
        rn: '20',
        _client_version: '11.10.8.6',
        client_type: '2',
        _os_version: '26',
        _client_type: '2',
        scr_dip: '1',
        scr_h: '800',
        scr_w: '360',
      });
      const modernList = this.parseModernThreads(payload, page, forumName);
      if (modernList.list.length > 0) {
        if (isGoodMode) {
          modernList.list = modernList.list.filter((item: ThreadItem) => item.isGood === true || item.isFeatured === true);
        }
        if (modernList.list.length > 0) {
          // 与首页一致：JSON 接口 name_show 可能占位/缺失，用 profile 实时昵称校准
          // enrichAuthors=false 时由调用方先渲染再后台校准，不阻塞首屏
          if (enrichAuthors) {
            modernList.list = await this.enrichHomeAuthors(modernList.list);
          }
          console.info(`[FRS] modern OK kw=${forumName} sort=${sortType} n=${modernList.list.length} cost=${Date.now() - t0}ms`);
          return modernList;
        }
        console.info(`[FRS] modern FILTERED-EMPTY kw=${forumName} sort=${sortType} cost=${Date.now() - t0}ms`);
      } else {
        console.info(`[FRS] modern EMPTY kw=${forumName} sort=${sortType} cost=${Date.now() - t0}ms`);
      }
    } catch (e) {
      console.info(`[FRS] modern FAIL kw=${forumName} sort=${sortType} cost=${Date.now() - t0}ms err=${(e as Error).message}`);
      // 现代接口失败时回落到网页列表。
    }
    try {
      const url = `${API.FORUM_THREADS}${encodeURIComponent(forumName)}&pn=${(page - 1) * 50}${isGoodMode ? '&tab=good&is_good=1' : ''}`;
      console.info(`[FRS] fallback start kw=${forumName} sort=${sortType} cost=${Date.now() - t0}ms`);
      const html = await HttpClient.get(url);
      const fallback = this.parseForumThreads(html, forumName, page);
      if (fallback.list.length > 0) {
        if (isGoodMode) {
          fallback.list = fallback.list.filter((item: ThreadItem) => item.isGood === true || item.isFeatured === true);
        }
        if (fallback.list.length > 0) {
          console.info(`[FRS] fallback OK kw=${forumName} sort=${sortType} n=${fallback.list.length} cost=${Date.now() - t0}ms`);
          return fallback;
        }
        console.info(`[FRS] fallback FILTERED-EMPTY kw=${forumName} sort=${sortType} cost=${Date.now() - t0}ms`);
      } else {
        console.info(`[FRS] fallback EMPTY kw=${forumName} sort=${sortType} cost=${Date.now() - t0}ms`);
      }
    } catch (e) {
      console.info(`[FRS] fallback FAIL kw=${forumName} sort=${sortType} cost=${Date.now() - t0}ms err=${(e as Error).message}`);
      throw new Error(`贴吧“${forumName}”加载失败，请检查网络或登录状态`);
    }
    console.info(`[FRS] ALL EMPTY kw=${forumName} sort=${sortType} cost=${Date.now() - t0}ms`);
    throw new Error(`贴吧“${forumName}”暂时没有可显示的帖子`);
  }

  /**
   * 带超时保护的 Promise 包装：超时后 reject（底层请求结果被忽略），
   * 防止接口挂起时拖长 fetchForumThreads 的三级降级链路（proto → modern → HTML），改善冷启动最坏等待。
   */
  private withTimeout<T>(task: Promise<T>, timeoutMs: number, label: string): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      let settled: boolean = false;
      task.then((value: T) => {
        if (!settled) {
          settled = true;
          resolve(value);
        }
      }).catch((e: Error) => {
        if (!settled) {
          settled = true;
          reject(e);
        }
      });
      setTimeout((): void => {
        if (!settled) {
          settled = true;
          reject(new Error(`${label} timeout after ${timeoutMs}ms`));
        }
      }, timeoutMs);
    });
  }

  private async requestForumThreadsProto(forumName: string, page: number, sortType: number, isGood: boolean, enrichAuthors: boolean = true): Promise<PagedResult<ThreadItem>> {
    const common = ProtoSchema.commonRequest(new Map<string, string | number>([
      ['_client_type', 2],
      ['_client_version', '12.64.1.1'],
      ['_os_version', '26'],
      ['model', 'HarmonyOS'],
      ['brand', 'Huawei'],
      ['net_type', 1],
      ['scr_w', 360],
      ['scr_h', 800],
      ['scr_dip', 1],
      ['pversion', '1.0.3'],
      ['BDUSS', AuthManager.getInstance().getBduss()]
    ]));
    const data = ProtoSchema.frsPageRequest(new Map<string, string | number>([
      ['kw', forumName],
      ['rn', 20],
      ['rn_need', 25],
      ['is_good', isGood ? 1 : 0],
      ['pn', page === 1 ? 0 : page],
      ['sort_type', isGood ? 0 : sortType],
    ]), common);
    const binary = await this.withTimeout(
      HttpClient.postProtoMultipart('https://c.tieba.baidu.com/c/f/frs/page?cmd=301001', data, {
        'User-Agent': 'tieba/12.64.1.1',
        'Accept': 'application/octet-stream',
        'X-BD-DATA-TYPE': 'protobuf',
        'Client-Type': '2',
        'Charset': 'UTF-8',
        'Referer': 'https://tieba.baidu.com/'
      }),
      2000,
      'frs proto'
    );
    const decoded: FrsPageResponseMessage = TiebaProtoDecoder.decodeFrsPageResponse(binary);
    const errorCode = decoded.error?.errorCode ?? 0;
    if (errorCode !== 0) {
      throw new Error(decoded.error?.userMsg ?? decoded.error?.errorMsg ?? `贴吧列表接口错误 ${errorCode}`);
    }
    this.cachedForumHeader = this.extractForumHeaderInfo(decoded, forumName);
    const threadList = decoded.data?.threadList ?? [];
    const userList = decoded.data?.userList ?? [];
    const globalForumAvatar: string = decoded.data?.forum?.avatar ?? '';
    const list: ThreadItem[] = threadList.map((item: ThreadInfoMessage): ThreadItem => {
      const threadForumAvatar: string = item.forumInfo?.avatar ?? '';
      const forumAvatar: string = threadForumAvatar.length > 0 ? threadForumAvatar : globalForumAvatar;
      
      // Build author info: try item.author first, then lookup in userList by authorId
      const authorFromMsg = item.author;
      // 用字符串比较防大整数精度问题；user_list 里的 name_show 才是完整昵称
      const authorFromList = userList.find((u: UserMessage) => `${u.id}` === `${item.authorId}`);
      const authorInfo = this.resolveAuthorInfo(authorFromMsg, authorFromList, item.authorId);
      
      const authorAvatar: string = this.normalizeAvatar(authorInfo);
      const images: string[] = (item.media ?? [])
        .map((m: object): string => {
          const mediaObj = m as Record<string, string>;
          return mediaObj.bigPic ?? mediaObj.srcPic ?? mediaObj.originPic ?? '';
        })
        .filter((url: string) => url.length > 0);
      return {
        tid: `${item.threadId ?? item.id ?? ''}`,
        postId: `${item.firstPostId ?? item.postId ?? item.id ?? ''}`,
        forumId: `${item.forumId ?? decoded.data?.forum?.id ?? ''}`,
        forumAvatar: forumAvatar,
        title: item.title ?? `${item.threadId ?? item.id ?? ''}`,
        forumName: item.forumName ?? decoded.data?.forum?.name ?? forumName,
        author: this.displayAuthor(authorInfo),
        authorId: `${item.authorId ?? authorInfo?.id ?? ''}`,
        authorAvatar: authorAvatar,
        replyNum: item.replyNum ?? 0,
        likeCount: Number(item.agree?.agreeNum ?? item.agreeNum ?? 0),
        isLiked: Number(item.agree?.hasAgree ?? 0) === 1 || Number(item.agree?.agreeType ?? 0) > 0,
        abstract: item.abstract?.map((part) => part.text ?? '').join('') ?? '',
        firstImage: item.media?.[0]?.bigPic ?? item.media?.[0]?.srcPic ?? item.media?.[0]?.originPic ?? '',
        images: images,
        createTime: item.lastTime ?? `${item.lastTimeInt ?? item.createTime ?? ''}`,
        isTop: item.isTop === 1 || item.isMemberTop === 1,
        isGood: item.isGood === 1,
        isFeatured: item.isGood === 1,
      };
    }).filter((item) => item.tid.length > 0 && (!isGood || item.isGood === true));
    const pageInfo = decoded.data?.page;
    // proto 列表的 name_show 也可能过期/缺失，与首页一致用 profile 实时昵称校准
    // enrichAuthors=false 时由调用方先渲染再后台校准，不阻塞首屏
    if (list.length > 0) {
      if (enrichAuthors) {
        const enriched: ThreadItem[] = await this.enrichHomeAuthors(list);
        return { list: enriched, hasMore: pageInfo?.hasMore === 1 || list.length >= 20, page };
      }
      return { list, hasMore: pageInfo?.hasMore === 1 || list.length >= 20, page };
    }
    return {
      list,
      hasMore: pageInfo?.hasMore === 1 || list.length >= 20,
      page,
    };
  }

  private extractForumHeaderInfo(decoded: FrsPageResponseMessage, fallbackName: string): ForumHeaderInfo {
    const forum = decoded.data?.forum;
    const avatar: string = this.normalizeForumAvatar((forum?.avatar ?? '').toString());
    return {
      forumId: `${forum?.id ?? ''}`,
      forumName: (forum?.name ?? fallbackName).toString(),
      avatar: avatar,
      bannerUrl: (forum?.fShareImg ?? '').toString(),
      slogan: (forum?.slogan ?? '').toString(),
      memberCount: forum?.memberNum ?? 0,
      threadCount: forum?.threadNum ?? 0,
      postCount: forum?.postNum ?? 0,
      userLevel: forum?.userLevel ?? 0,
      levelName: (forum?.levelName ?? '').toString(),
      curScore: forum?.curScore ?? 0,
      levelupScore: forum?.levelupScore ?? 0,
      isLike: (forum?.isLike ?? 0) === 1,
      hasFrsStar: (forum?.hasFrsStar ?? 0) === 1,
    };
  }

  // ---- 帖子详情内存缓存（秒开：重复打开先显示缓存，后台静默刷新） ----
  private static readonly THREAD_DETAIL_CACHE_MAX: number = 30;
  private static readonly THREAD_DETAIL_CACHE_TTL: number = 5 * 60 * 1000;
  private threadDetailCache: Map<string, ThreadDetailCacheEntry> = new Map();

  getThreadDetailCache(key: string): ThreadDetailResult | undefined {
    const entry = this.threadDetailCache.get(key);
    if (entry === undefined || entry === null) {
      return undefined;
    }
    if (Date.now() - entry.time > TiebaService.THREAD_DETAIL_CACHE_TTL) {
      this.threadDetailCache.delete(key);
      return undefined;
    }
    // 空壳（标题元数据在但正文/楼层全无，pb/page 偶发残缺的产物）不参与秒开，
    // 命中即清除，让后续走真实网络请求，避免"返回重进仍空白"的脏缓存循环。
    if (this.isThreadDetailShell(entry.result)) {
      this.threadDetailCache.delete(key);
      return undefined;
    }
    return entry.result;
  }

  putThreadDetailCache(key: string, result: ThreadDetailResult): void {
    if (!result || !result.detail || (result.detail.tid ?? '').length === 0) {
      return;
    }
    // 空壳结果不写缓存：残缺响应一旦入缓存会在 TTL 内反复命中，表现为多次重进仍空白
    if (this.isThreadDetailShell(result)) {
      return;
    }
    this.threadDetailCache.set(key, { result: result, time: Date.now() });
    if (this.threadDetailCache.size > TiebaService.THREAD_DETAIL_CACHE_MAX) {
      let oldestKey: string = '';
      let oldestTime: number = Number.MAX_SAFE_INTEGER;
      this.threadDetailCache.forEach((entry: ThreadDetailCacheEntry, k: string) => {
        if (entry.time < oldestTime) {
          oldestTime = entry.time;
          oldestKey = k;
        }
      });
      if (oldestKey.length > 0) {
        this.threadDetailCache.delete(oldestKey);
      }
    }
  }

  invalidateThreadDetailCache(key: string): void {
    this.threadDetailCache.delete(key);
  }

  // ---- 帖子详情磁盘缓存（stale-while-revalidate：冷启动重进秒开，过期数据也先显示） ----
  private threadDetailDiskKey(tid: string, sortType: number, seeLz: boolean): string {
    return `${CACHE_KEY.THREAD_DETAIL}_${tid}_${sortType}_${seeLz ? 1 : 0}`;
  }

  /**
   * 读磁盘详情缓存：stale 也返回（不校验过期），供冷启动秒开，网络结果返回后覆盖。
   */
  async getThreadDetailFromDisk(tid: string, sortType: number = 0, seeLz: boolean = false): Promise<ThreadDetailResult | undefined> {
    try {
      const cached = await CacheManager.getInstance().getWithTtlAllowStale<ThreadDetailResult>(
        this.threadDetailDiskKey(tid, sortType, seeLz)
      );
      // 空壳缓存（pb/page 偶发残缺产物）不用于冷启动秒开，视为未命中走真实请求
      if (cached?.data && this.isThreadDetailShell(cached.data)) {
        return undefined;
      }
      return cached?.data;
    } catch (_) {
      return undefined;
    }
  }

  /**
   * 写磁盘详情缓存（网络成功后调用）：只缓存首屏第 1 页，超上限自动清理最旧，失败不阻断。
   */
  async saveThreadDetailToDisk(result: ThreadDetailResult, tid: string, sortType: number = 0, seeLz: boolean = false): Promise<void> {
    if (!result || !result.detail || (result.detail.tid ?? '').length === 0) {
      return;
    }
    // 空壳结果不落盘：避免残缺响应在磁盘缓存 10 分钟 TTL 内反复污染冷启动秒开
    if (this.isThreadDetailShell(result)) {
      return;
    }
    try {
      await CacheManager.getInstance().putWithTtl(
        this.threadDetailDiskKey(tid, sortType, seeLz),
        result,
        CACHE_TTL.THREAD_DETAIL
      );
      CacheManager.getInstance().pruneByPrefix(CACHE_KEY.THREAD_DETAIL, 20);
    } catch (_) {
      // 磁盘缓存写入失败不影响功能
    }
  }

  // ---- 帖子详情点击即预取（利用跳转动画窗口后台取数，写入内存+磁盘缓存，详情页打开即命中） ----
  private pendingThreadDetailPrefetch: Map<string, Promise<void>> = new Map();

  prefetchThreadDetail(tid: string, forumId: string = ''): void {
    const normalizedTid: string = tid.trim();
    if (normalizedTid.length === 0) {
      return;
    }
    // 详情页默认 sortType=0 / seeLz=false，与跳转时的缓存 key 一致
    const key: string = `${normalizedTid}_0_0`;
    if (this.getThreadDetailCache(key)) {
      return; // 内存缓存仍有效（5 分钟 TTL），无需重复预取
    }
    if (this.pendingThreadDetailPrefetch.has(key)) {
      return; // 已在途，防重复请求
    }
    const task: Promise<void> = this.fetchThreadDetail(normalizedTid, 1, 0, false, forumId, 3, 0, '')
      .then((result: ThreadDetailResult) => {
        this.putThreadDetailCache(key, result);
        return this.saveThreadDetailToDisk(result, normalizedTid, 0, false);
      })
      .catch((e: Error) => {
        // 预取失败静默：页面打开时自行请求即可
        console.info(`[PREFETCH] detail ${normalizedTid} fail: ${(e as Error).message}`);
      })
      .finally(() => {
        this.pendingThreadDetailPrefetch.delete(key);
      });
    this.pendingThreadDetailPrefetch.set(key, task);
  }

  // ---- 楼层下一页预取缓存（滚动翻页秒接，减少等待；只暂存内存，取出即删） ----
  private threadNextPageCache: Map<string, ThreadDetailResult> = new Map();
  private static readonly THREAD_NEXT_PAGE_MAX: number = 8;

  private threadNextPageKey(tid: string, sortType: number, seeLz: boolean, page: number): string {
    return `${tid}_${sortType}_${seeLz ? 1 : 0}_${page}`;
  }

  /**
   * 预取下一页楼层（currentPage 为已加载页码，预取 currentPage+1），结果暂存内存。
   * 失败静默：滚动到底时详情页自行请求即可。
   */
  prefetchThreadNextPage(tid: string, currentPage: number, sortType: number = 0, seeLz: boolean = false, forumId: string = '', commentRn: number = 3): void {
    const nextPage: number = currentPage + 1;
    const key: string = this.threadNextPageKey(tid, sortType, seeLz, nextPage);
    if (this.threadNextPageCache.has(key)) {
      return; // 已在缓存，无需重复预取
    }
    this.fetchThreadDetail(tid, nextPage, sortType, seeLz, forumId, commentRn, 0)
      .then((result: ThreadDetailResult) => {
        if (result && result.floors && result.floors.length > 0) {
          this.threadNextPageCache.set(key, result);
          if (this.threadNextPageCache.size > TiebaService.THREAD_NEXT_PAGE_MAX) {
            const oldestKey: string | undefined = this.threadNextPageCache.keys().next().value;
            if (oldestKey !== undefined) {
              this.threadNextPageCache.delete(oldestKey);
            }
          }
        }
      })
      .catch(() => { /* 预取失败静默 */ });
  }

  /** 取出已预取的下一页结果（取出即删，避免旧数据污染后续翻页） */
  takeThreadNextPage(tid: string, sortType: number, seeLz: boolean, nextPage: number): ThreadDetailResult | undefined {
    const key: string = this.threadNextPageKey(tid, sortType, seeLz, nextPage);
    const result: ThreadDetailResult | undefined = this.threadNextPageCache.get(key);
    if (result !== undefined) {
      this.threadNextPageCache.delete(key);
    }
    return result;
  }

  /**
   * 详情结果是否为空壳：帖子元数据（标题等）解析出来了，但没有任何可展示内容
   * （无正文、无图片、无楼层）。用于：
   * 1) 识别 pb/page 偶发返回的残缺响应（只带 thread 元数据、post_list 缺失），
   *    避免把"有标题但无内容"当成功结果直接渲染/缓存，导致反复空白；
   * 2) 缓存写入/读取前过滤空壳，防止残缺响应污染秒开缓存。
   */
  private isThreadDetailShell(result: ThreadDetailResult): boolean {
    const d = result?.detail;
    if (!d) {
      return true;
    }
    const hasText: boolean = `${d.contentText ?? ''}`.trim().length > 0 || `${d.content ?? ''}`.trim().length > 0;
    return !hasText
      && (d.images ?? []).length === 0
      && (d.fragments ?? []).length === 0
      && (result.floors ?? []).length === 0;
  }

  /**
   * 获取帖子详情与楼层
   */
  async fetchThreadDetail(tid: string, page: number = 1, sortType: number = 0, seeLz: boolean = false, forumId: string = '', commentRn: number = 3, commentSortType: number = 0, parentPid: string = '', onIdentityHydrated?: (result: ThreadDetailResult) => void): Promise<ThreadDetailResult> {
    const normalizedTid = tid.trim();
    if (normalizedTid.length === 0) {
      throw new Error('缺少帖子 ID，无法加载详情');
    }
    let protoError: string = '';
    let shellResult: ThreadDetailResult | null = null;
    try {
      const payload = await this.requestThreadPage(normalizedTid, page, sortType, seeLz, forumId, commentRn, commentSortType, parentPid);
      const modernResult = this.parseModernThreadDetail(payload, normalizedTid, page, parentPid);
      const hasRequestedParent: boolean = parentPid.trim().length > 0;
      const titleResolved: boolean = modernResult.detail.title.trim().length > 0 && modernResult.detail.title !== normalizedTid;
      const shell: boolean = this.isThreadDetailShell(modernResult);
      // 正常判定：有楼层 → 直接成功；无楼层时需"解析出真实标题且首楼有可展示内容"，
      // 否则视为疑似残缺响应（标题元数据在、post_list 丢失），交给下方 web 通道兜底。
      if ((!hasRequestedParent && (modernResult.floors.length > 0 || (titleResolved && !shell))) ||
        (hasRequestedParent && modernResult.floors.length > 0)) {
        if (this.needsWebIdentityHydration(modernResult)) {
          // 身份补齐改为后台异步执行：先返回正文楼层让页面立即渲染，补齐后通过回调刷新作者身份
          this.hydrateThreadIdentity(modernResult, normalizedTid, page, onIdentityHydrated);
        }
        return modernResult;
      }
      // 标题解析成功但正文/楼层为空：pb/page 偶发残缺 或 真空帖。
      // 先保留 proto 结果作兜底候选（保证真空帖也能显示标题页），下方走 web 通道尝试拿完整楼层。
      if (titleResolved && !hasRequestedParent) {
        shellResult = modernResult;
      }
      protoError = shell ? '贴吧返回了空的帖子数据' : '贴吧返回了空的楼层数据';
    } catch (e) {
      protoError = this.errorMessage(e, '移动详情接口请求失败');
    }
    try {
      const url = `${API.THREAD}${encodeURIComponent(normalizedTid)}?pn=${page}`;
      const html = await HttpClient.get(url, {
        'Accept': 'text/html,application/xhtml+xml',
        'Referer': `${TIEBA_BASE}/p/${encodeURIComponent(normalizedTid)}`
      });
      const webResult = this.parseThreadDetail(html, normalizedTid, page);
      if (parentPid.trim().length > 0) {
        const requestedFloors: FloorItem[] = webResult.floors.filter((floor: FloorItem): boolean =>
          floor.floorId === parentPid.trim() || floor.floorId === `${Number(parentPid)}`);
        if (requestedFloors.length > 0) {
          return { detail: webResult.detail, floors: [requestedFloors[0]] };
        }
      } else if (webResult.floors.length > 0 || webResult.detail.title.length > 0 && webResult.detail.title !== normalizedTid) {
        return webResult;
      }
      if (shellResult) {
        // web 通道同样拿不到楼层（真空帖场景）：退回 proto 标题页，避免误报删除/空错误
        return shellResult;
      }
      throw new Error('帖子页面为空，可能已被删除或触发访问限制');
    } catch (e) {
      const webError = this.errorMessage(e, '网页详情请求失败');
      if (protoError.includes('访问被拒绝') || webError.includes('访问被拒绝')) {
        throw new Error('贴吧拒绝了详情请求，通常与登录态失效、接口风控或帖子权限有关，请先重新登录后重试');
      }
      if (shellResult) {
        // web 请求失败但 proto 已确认标题：退回标题页（空正文/无楼层），避免偶发残缺时硬报错
        return shellResult;
      }
      throw new Error(`${protoError}; ${webError}`);
    }
  }

  async fetchSubPostDetail(tid: string, parentPid: string, forumId: string = '', parentFloor: number = 0, page: number = 1): Promise<SubPostDetail> {
    const normalizedTid: string = tid.trim();
    const normalizedPid: string = parentPid.trim();
    if (normalizedTid.length === 0 || normalizedPid.length === 0) {
      throw new Error('缺少主楼信息，无法加载楼中楼');
    }
    const common = ProtoSchema.commonRequest(new Map<string, string | number>([
      ['_client_type', 2],
      ['_client_version', '12.64.1.1'],
      ['_os_version', '26'],
      ['model', 'HarmonyOS'],
      ['brand', 'Huawei'],
      ['net_type', 1],
      ['scr_w', 360],
      ['scr_h', 800],
      ['scr_dip', 1],
      ['pversion', '1.0.3'],
      ['BDUSS', AuthManager.getInstance().getBduss()]
    ]));
    const request = ProtoSchema.pbFloorRequest(normalizedTid, normalizedPid, page, common);
    const binary = await HttpClient.postProtoMultipart('https://tiebac.baidu.com/c/f/pb/floor?cmd=302002', request, {
      'User-Agent': 'tieba/12.64.1.1',
      'Accept': 'application/octet-stream',
      'X-BD-DATA-TYPE': 'protobuf',
      'Client-Type': '2',
      'Charset': 'UTF-8',
      'Referer': 'https://tieba.baidu.com/'
    });
    const decoded = TiebaProtoDecoder.decodePbFloorResponse(binary);
    const errorCode: number = decoded.error?.errorCode ?? 0;
    if (errorCode !== 0) {
      throw new Error(decoded.error?.userMsg ?? decoded.error?.errorMsg ?? `楼中楼接口错误 ${errorCode}`);
    }
    const data = decoded.data;
    const post = data?.post;
    const forum = data?.forum;
    const subPosts = data?.subPostList ?? [];
    const parent: FloorItem = this.mapFloorPost(post, parentFloor, normalizedPid, subPosts.length);
    const comments: CommentItem[] = subPosts.map((subPost: SubPostListMessage, index: number): CommentItem =>
      this.mapSubPostComment(subPost, normalizedPid, index)
    );
    parent.comments = comments;
    parent.commentsTotal = comments.length;
    parent.commentsHasMore = data?.page?.hasMore === 1;
    return {
      tid: normalizedTid,
      floorId: normalizedPid,
      floor: parent.floor,
      parent,
      comments,
      total: comments.length,
      hasMore: data?.page?.hasMore === 1,
    };
  }

  private normalizeUrl(url: string): string {
    if (!url || url.length === 0) {
      return '';
    }
    let result = url.replace('http://', 'https://');
    if (result.startsWith('//')) {
      result = 'https:' + result;
    }
    return result;
  }

  // 表情包商店付费表情（type=11 FragMemeInfo）CDN：用 pckId+picId 拼接
  // 切到 gsp0.baidu.com：与头像同源，无鉴权；tiebac.baidu.com /tieba.baidu.com/c/p 往往需贴吧登录Cookie
  private resolveMemePackageUrl(pckId: number | undefined, picId: number | undefined): string {
    if (pckId === undefined || picId === undefined || pckId === null || picId === null) return '';
    if (pckId === 0 || picId === 0) return '';
    const pck: string = String(pckId);
    const pic: string = String(picId);
    return `https://gsp0.baidu.com/5aAHeD3nKhI2p27j8q8nRC2590z/sys/portrait/item/emoji_package/${pck}_${pic}.jpg`;
  }

  // 反向映射：image_emoticon + 数字 ID → 中文表情名(包[])，供 fallback 文本显示用（绝不显示"image_emoticonXXX"裸文件名）
  // 名称来源：TiebaLite/Tiebanana/tieba_third 等开源贴吧客户端表情表交叉核对
  private static readonly EMOJI_ID_TO_NAME: Record<string, string> = {
    '1': '呵呵', '2': '哈哈', '3': '吐舌', '4': '啊', '5': '酷',
    '6': '怒', '7': '开心', '8': '汗', '9': '泪', '10': '黑线',
    '11': '鄙视', '12': '不高兴', '13': '真棒', '14': '钱', '15': '疑问',
    '16': '阴险', '17': '吐', '18': '咦', '19': '委屈', '20': '花心',
    '21': '呼~', '22': '笑眼', '23': '冷', '24': '太开心', '25': '滑稽',
    '26': '勉强', '27': '狂汗', '28': '乖', '29': '睡觉', '30': '惊哭',
    '31': '升起', '32': '惊讶', '33': '喷', '34': '爱心', '35': '心碎',
    '36': '玫瑰', '37': '礼物', '38': '彩虹', '39': '星星月亮', '40': '太阳',
    '41': '钱币', '42': '灯泡', '43': '茶杯', '44': '蛋糕', '45': '音乐',
    '46': 'haha', '47': '胜利', '48': '大拇指', '49': '弱', '50': 'OK',
    '61': '升起', '66': '小乖', '67': '捂嘴笑', '68': '你懂的', '69': 'what',
    '70': '酸爽', '71': '呀咩爹', '72': '笑尿', '73': '挖鼻', '74': '犀利',
    '75': '小红脸', '76': '懒得理', '77': '沙发', '78': '手纸', '79': '香蕉',
    '80': '便便', '81': '药丸', '82': '红领巾', '83': '蜡烛', '84': '三道杠',
    '85': '暗中观察', '86': '吃瓜', '87': '喝酒', '88': '嘿嘿嘿', '89': '噗',
    '90': '困成狗', '91': '微微一笑', '92': '托腮', '93': '摊手', '94': '柯基暗中观察',
    '95': '欢呼', '96': '炸药', '97': '突然兴奋', '98': '紧张', '99': '黑头瞪眼',
    '100': '黑头高兴', '101': '不跟丑人说话', '102': '么么哒', '103': '亲亲才能起来',
    '104': '伦家只是宝宝', '105': '你是我的人', '106': '假装看不见', '107': '单身等撩',
    '108': '吓到宝宝了', '109': '哈哈哈', '110': '嗯嗯', '111': '好幸福', '112': '宝宝不开心',
    '113': '小姐姐别走', '114': '小姐姐在吗', '115': '小姐姐来啦', '116': '小姐姐来玩呀',
    '117': '我养你', '118': '我是不会骗你的', '119': '扎心了', '120': '无聊',
    '121': '月亮代表我的心', '122': '来追我呀', '123': '爱你的形状', '124': '白眼',
    '125': '奥特曼', '126': '不听', '127': '干饭', '128': '望远镜', '129': '菜狗',
    '130': '老虎', '131': '嗷呜', '132': '烟花', '133': '香槟',
    '134': '文字啊', '135': '文字对', '136': '鼠1', '137': '鼠2',
  };

  // 把表情显示文本"人性化"：如果是 image_emoticonXXX / #(XXX) / XXX 裸文件名，转换成 [中文表情名]
  private humanizeEmojiAlt(raw: string, cField: string): string {
    if (!raw || raw.length === 0) raw = '';
    let alt: string = raw.trim();
    const c: string = (cField ?? '').trim();
    if (c.length === 0 && alt.length === 0) return '';

    // 先通过 c 字段（最可靠的文件名键）解析
    if (c.length > 0 && c.startsWith('image_emoticon')) {
      let id: string = c.substring('image_emoticon'.length);
      if (id.endsWith('.png')) id = id.substring(0, id.length - 4);
      const zh: string | undefined = TiebaService.EMOJI_ID_TO_NAME[id];
      if (zh !== undefined) return `[${zh}]`;
    }

    // alt 文本本身也是文件名格式
    if (alt.length > 0 && alt.startsWith('image_emoticon')) {
      let id2: string = alt.substring('image_emoticon'.length);
      if (id2.endsWith('.png')) id2 = id2.substring(0, id2.length - 4);
      const zh2: string | undefined = TiebaService.EMOJI_ID_TO_NAME[id2];
      if (zh2 !== undefined) return `[${zh2}]`;
    }

    // #(滑稽) 格式
    if (alt.startsWith('#(') && alt.endsWith(')')) {
      return `[${alt.substring(2, alt.length - 1)}]`;
    }
    // 已带 [滑稽]
    if (alt.startsWith('[') && alt.endsWith(']') && alt.length > 2) {
      return alt;
    }
    // 纯中文表情名（不带括号）→ 包括号
    if (alt.length > 0) {
      const maybeId: string | undefined = TiebaService.EMOJI_NAME_TO_ID[alt];
      if (maybeId !== undefined) return `[${alt}]`;
    }
    // c 字段是描述文本（非文件名标识，如"滑稽"）→ 直接用作表情描述（aiotieba: desc=c）
    if (c.length > 0 && !this.isEmoticonFileName(c)) {
      if (c.startsWith('[') && c.endsWith(']')) return c;
      return `[${c}]`;
    }
    return alt;
  }

  // 贴吧表情文件名前缀 → 目录+扩展名映射表（参考 aiotieba/TiebaArchiver），用 Record<string,string[]> 表达: {prefix:[dir,ext]}
  private static readonly EMOTICON_DIR_MAP: Record<string, string[]> = {
    // 17 系列表情按 前缀→[目录,扩展名] 映射
    'image_emoticon': ['client', 'png'],
    'bearchildren_': ['bearchildren', 'gif'],
    'tiexing_': ['tiexing', 'gif'],
    'ali_': ['ali', 'gif'],
    'llb_': ['luoluobu', 'gif'],
    'b_': ['qpx_n', 'gif'],
    'xyj_': ['xyj', 'gif'],
    'ltn_': ['lt', 'gif'],
    'bfmn_': ['bfmn', 'gif'],
    'pczxh_': ['zxh', 'gif'],
    't_': ['tsj', 'gif'],
    'wdj_': ['wdj', 'png'],
    'lxs_': ['lxs', 'gif'],
    'B_': ['bobo', 'gif'],
    'yz_': ['shadow', 'gif'],
    'w_': ['ldw', 'gif'],
    '10th_': ['10th', 'gif'],
  };

  // 上面 Record 按前缀排序的稳定查询顺序（长前缀优先匹配）
  private static readonly EMOTICON_PREFIX_ORDER: string[] = [
    'bearchildren_', 'pczxh_', '10th_', 'tiexing_', 'image_emoticon',
    'bfmn_', 'ltn_', 'llb_', 'xyj_', 'wdj_', 'lxs_', 'ali_',
    'yz_', 't_', 'B_', 'b_', 'w_',
  ];

  // 中文表情名→image_emoticon 序号映射表，用于回退到纯文本 "[滑稽]" 的情况
  private static readonly EMOJI_NAME_TO_ID: Record<string, string> = {
    '呵呵': '1', '哈哈': '2', '吐舌': '3', '啊': '4', '酷': '5',
    '怒': '6', '开心': '7', '汗': '8', '泪': '9', '黑线': '10',
    '鄙视': '11', '不高兴': '12', '真棒': '13', '钱': '14', '疑问': '15',
    '阴险': '16', '吐': '17', '咦': '18', '委屈': '19', '花心': '20',
    '呼~': '21', '笑眼': '22', '冷': '23', '太开心': '24', '滑稽': '25',
    '勉强': '26', '狂汗': '27', '乖': '28', '睡觉': '29', '惊哭': '30',
    '升起': '31', '惊讶': '32', '喷': '33', '爱心': '34', '心碎': '35',
    '玫瑰': '36', '礼物': '37', '彩虹': '38', '星星月亮': '39', '太阳': '40',
    '钱币': '41', '灯泡': '42', '茶杯': '43', '蛋糕': '44', '音乐': '45',
    'haha': '46', '胜利': '47', '大拇指': '48', '弱': '49', 'OK': '50',
    '小乖': '66', '捂嘴笑': '67', '你懂的': '68', 'what': '69', '酸爽': '70',
    '呀咩爹': '71', '笑尿': '72', '挖鼻': '73', '犀利': '74', '小红脸': '75',
    '懒得理': '76', '沙发': '77', '手纸': '78', '香蕉': '79', '便便': '80',
    '药丸': '81', '红领巾': '82', '蜡烛': '83', '三道杠': '84',
    '暗中观察': '85', '吃瓜': '86', '喝酒': '87', '嘿嘿嘿': '88', '噗': '89',
    '困成狗': '90', '微微一笑': '91', '托腮': '92', '摊手': '93', '柯基暗中观察': '94',
    '欢呼': '95', '炸药': '96', '突然兴奋': '97', '紧张': '98', '黑头瞪眼': '99',
    '黑头高兴': '100', '不跟丑人说话': '101', '么么哒': '102', '亲亲才能起来': '103',
    '伦家只是宝宝': '104', '你是我的人': '105', '假装看不见': '106', '单身等撩': '107',
    '吓到宝宝了': '108', '哈哈哈': '109', '嗯嗯': '110', '好幸福': '111', '宝宝不开心': '112',
    '小姐姐别走': '113', '小姐姐在吗': '114', '小姐姐来啦': '115', '小姐姐来玩呀': '116',
    '我养你': '117', '我是不会骗你的': '118', '扎心了': '119', '无聊': '120',
    '月亮代表我的心': '121', '来追我呀': '122', '爱你的形状': '123', '白眼': '124',
    '奥特曼': '125', '不听': '126', '干饭': '127', '望远镜': '128', '菜狗': '129',
    '老虎': '130', '嗷呜': '131', '烟花': '132', '香槟': '133',
    '文字啊': '134', '文字对': '135', '鼠1': '136', '鼠2': '137',
  };

  // 贴吧官方表情 CDN：tb2.bdstatic.com（需 Referer: https://tieba.baidu.com/ 防盗链）
  private static readonly EMOJI_CDN_PRIMARY: string = 'https://tb2.bdstatic.com/tb/editor/images';
  private static readonly EMOJI_CDN_FALLBACK: string = 'https://tb1.bdstatic.com/tb/editor/images';
  // 默认黄豆表情（image_emoticon 系列）高清源：贴吧客户端提取图 90x90（参考 microlong666/Tieba_mobile_emotions）
  // 官方 tb2 源仅 30x30（85-101 为 60x60），且 102-124 官方源缺失（404）导致部分表情只能显示文字
  private static readonly EMOJI_CDN_HD: string = 'https://cdn.jsdelivr.net/gh/microlong666/tieba_mobile_emotions';

  // 判断值是否为表情文件名（ASCII 标识如 image_emoticon25/bearchildren_1），而非中文描述（如"滑稽"）
  // 参考 aiotieba：protobuf 中 text=表情图片id、c=表情描述；不同接口语义可能互换，两字段都需甄别
  private isEmoticonFileName(name: string): boolean {
    if (!name || name.length === 0) return false;
    const trimmed: string = name.trim();
    if (trimmed.length === 0) return false;
    for (const prefix of TiebaService.EMOTICON_PREFIX_ORDER) {
      if (trimmed.startsWith(prefix)) return true;
    }
    // 纯 ASCII 且无空白的文件名形态（如 "image_emoticon25.png"）
    return /^[\x21-\x7e]+$/.test(trimmed) && /[._]/.test(trimmed);
  }

  // 基于 c/text 字段（表情文件名标识如 "image_emoticon25"/"bearchildren_1"）拼装 CDN URL
  // 仅当值确实是文件名标识时才拼装；中文描述（如"滑稽"）返回空串，避免拼出 404 URL
  private resolveCFieldEmojiUrl(c: string): string {
    if (!c || c.length === 0) return '';
    const name: string = c.trim();
    if (name.length === 0) return '';
    for (const prefix of TiebaService.EMOTICON_PREFIX_ORDER) {
      if (name.startsWith(prefix)) {
        const mapping: string[] | undefined = TiebaService.EMOTICON_DIR_MAP[prefix];
        if (mapping && mapping.length >= 2) {
          const dir: string = mapping[0];
          const ext: string = mapping[1];
          // 服务端可能下发带扩展名的文件名（如 image_emoticon1.png），先剥离再拼，避免双扩展 404
          const base: string = name.endsWith(`.${ext}`) ? name.substring(0, name.length - ext.length - 1) : name;
          // 默认黄豆表情优先用高清源（90x90）：高清库覆盖 ID 1-50、62-124；
          // 其余 ID（61、125-137）高清库没有，仍走官方 CDN
          if (prefix === 'image_emoticon') {
            const emojiIdStr: string = base.substring('image_emoticon'.length);
            const emojiId: number = emojiIdStr.length === 0 ? 1 : parseInt(emojiIdStr);
            const idValid: boolean = emojiId === emojiId && emojiId >= 1;
            if (idValid && (emojiId <= 50 || (emojiId >= 62 && emojiId <= 124))) {
              // 高清库中 ID 1 的文件名为 image_emoticon.png（无数字后缀）
              const hdFile: string = emojiId === 1 ? 'image_emoticon' : `image_emoticon${emojiId}`;
              return `${TiebaService.EMOJI_CDN_HD}/${hdFile}.png`;
            }
          }
          return `${TiebaService.EMOJI_CDN_PRIMARY}/${dir}/${base}.${ext}`;
        }
      }
    }
    // 兜底：仅当值是纯 ASCII 文件名形态（带 ./_ 且无中文），尝试 client 目录 PNG
    if (this.isEmoticonFileName(name)) {
      return `${TiebaService.EMOJI_CDN_PRIMARY}/client/${name}.png`;
    }
    return '';
  }

  // 为纯文本型黄豆表情（如 [滑稽]/#(滑稽)/裸文件名 image_emoticonXX）生成 CDN URL
  private resolveTextEmojiUrl(text: string): string {
    if (!text || text.length === 0) return '';
    let name: string = text.trim();
    if (name.length === 0) return '';
    // #(滑稽) 格式
    if (name.startsWith('#(') && name.endsWith(')')) {
      name = name.substring(2, name.length - 1);
    } else if (name.startsWith('[') && name.endsWith(']')) {
      // [滑稽] 格式
      name = name.substring(1, name.length - 1);
    } else {
      // 裸文件名 image_emoticonXX → 直接用 c 字段规则解析
      if (/^(image_emoticon|bearchildren_|tiexing_|ali_|llb_|b_|xyj_|ltn_|bfmn_|pczxh_|t_|wdj_|lxs_|B_|yz_|w_|10th_)/.test(name)) {
        return this.resolveCFieldEmojiUrl(name);
      }
    }
    if (name.length === 0) return '';
    const id: string | undefined = TiebaService.EMOJI_NAME_TO_ID[name];
    if (id === undefined) return '';
    // 复用 resolveCFieldEmojiUrl 的源分流（高清源优先，61/125-137 回退官方 CDN）
    return this.resolveCFieldEmojiUrl(`image_emoticon${id}`);
  }

  // 将文本按内嵌表情 token 拆分为 TEXT/EMOJI 混合片段
  // 旧版/网页端帖子会把表情序列化为字面文本（[呵呵] / #(呵呵)），出现在长文本的任意位置
  // 参考 tieba-lite-harmony EmoticonManager（对齐 Android TiebaLite）：表情在 content 中以 #(表情名) 格式插入
  private splitTextWithInlineEmojis(text: string): ContentFragment[] {
    const result: ContentFragment[] = [];
    if (!text || text.length === 0) return result;
    const pattern: RegExp = /(\[[^\[\]]{1,16}\])|(#\([^()]{1,16}\))/g;
    let cursor: number = 0;
    let foundEmoji: boolean = false;
    let match: RegExpExecArray | null = pattern.exec(text);
    while (match !== null) {
      const token: string = match[0];
      let name: string = '';
      if (token.startsWith('#(')) {
        name = token.substring(2, token.length - 1);
      } else {
        name = token.substring(1, token.length - 1);
      }
      const url: string = this.resolveTextEmojiUrl(name);
      if (url.length > 0) {
        const before: string = text.substring(cursor, match.index);
        if (before.length > 0) {
          result.push({ type: ContentFragmentType.TEXT, text: before });
        }
        result.push({ type: ContentFragmentType.EMOJI, text: `[${name}]`, imageUrl: url });
        cursor = match.index + token.length;
        foundEmoji = true;
      }
      match = pattern.exec(text);
    }
    if (!foundEmoji) {
      result.push({ type: ContentFragmentType.TEXT, text: text });
      return result;
    }
    const tail: string = text.substring(cursor);
    if (tail.length > 0) {
      result.push({ type: ContentFragmentType.TEXT, text: tail });
    }
    return result;
  }

  // 兜底：普通文本片段中手打的 http(s) URL 字面量 → 提为 LINK 片段（服务端未标 type=1 时也可点击）
  private expandUrlLinksInFragments(fragments: ContentFragment[], textParts: string[]): void {
    if (!fragments || fragments.length === 0) {
      return;
    }
    const out: ContentFragment[] = [];
    const urlPattern: RegExp = /https?:\/\/\S+/g;
    for (const f of fragments) {
      if (f.type === ContentFragmentType.TEXT && f.text && f.text.length > 0) {
        let cursor: number = 0;
        let found: boolean = false;
        let m: RegExpExecArray | null = urlPattern.exec(f.text);
        while (m !== null) {
          const raw: string = m[0];
          const clean: string = raw.replace(/[，。；、！？,.;:'"）】》]+$/, '');
          if (m.index > cursor) {
            const before: string = f.text.substring(cursor, m.index);
            if (before.length > 0) {
              out.push({ type: ContentFragmentType.TEXT, text: before });
              textParts.push(before);
            }
          }
          if (clean.length > 0) {
            out.push({ type: ContentFragmentType.LINK, text: clean, link: clean });
            textParts.push(clean);
            found = true;
          } else {
            out.push({ type: ContentFragmentType.TEXT, text: raw });
            textParts.push(raw);
          }
          cursor = m.index + raw.length;
          m = urlPattern.exec(f.text);
        }
        if (!found) {
          out.push(f);
        } else if (cursor < f.text.length) {
          const tail: string = f.text.substring(cursor);
          if (tail.length > 0) {
            out.push({ type: ContentFragmentType.TEXT, text: tail });
            textParts.push(tail);
          }
        }
      } else {
        out.push(f);
      }
    }
    fragments.length = 0;
    for (const item of out) {
      fragments.push(item);
    }
  }

  private buildFragmentsFromPbContent(contentList: PbContentMessage[] | undefined): FragmentsResult {
    const fragments: ContentFragment[] = [];
    const textParts: string[] = [];
    const images: string[] = [];
    for (const item of contentList ?? []) {
      const type: number = item.type ?? 0;
      const rawUrl: string = item.originSrc ?? item.bigCdnSrc ?? item.cdnSrc ?? item.src ?? item.bigSrc ?? '';
      const imageUrl: string = this.normalizeUrl(rawUrl);
      const memePicUrl: string = this.normalizeUrl(item.memeInfo?.picUrl ?? item.memeInfo?.thumbnail ?? '');
      const memePackageUrl: string = this.resolveMemePackageUrl(item.memeInfo?.pckId, item.memeInfo?.picId);
      const cFieldUrl: string = this.resolveCFieldEmojiUrl(item.c ?? '');
      // type 参考：https://github.com/Sorceresssis/TiebaArchiver tieba_data_notes.md
      // 0文本 9电话 18话题 27百科 40梗百科
      if (type === 0 || type === undefined || type === 9 || type === 18 || type === 27 || type === 40) {
        if (item.text !== undefined && item.text.length > 0) {
          // 旧版/网页端帖子把表情序列化为字面文本（[呵呵]/#(呵呵) 内嵌在长文本任意位置），拆分为混合片段渲染
          const inlineParts: ContentFragment[] = this.splitTextWithInlineEmojis(item.text);
          for (const part of inlineParts) {
            fragments.push(part);
          }
          textParts.push(item.text);
        }
      } else if (type === 2 || type === 11) {
        // EMOJI：2/11 才是表情（aiotieba 权威定义：text=表情图片id(如 image_emoticon25)、c=表情描述(如 滑稽)）
        // 两个字段都尝试按文件名解析，兼容语义互换的接口；优先级 pckId+picId→text文件名→c文件名→memeInfo/src链→名称映射
        const rawText: string = item.text ?? '';
        const cField: string = item.c ?? '';
        const emojiText: string = this.humanizeEmojiAlt(rawText, cField);
        const textAsFileUrl: string = this.resolveCFieldEmojiUrl(rawText);
        const pkgUrl: string = memePackageUrl.length > 0 ? memePackageUrl : '';
        const srcEmojiUrl: string = memePicUrl.length > 0 ? memePicUrl : imageUrl;
        let resolvedEmojiUrl: string = pkgUrl.length > 0 ? pkgUrl : '';
        if (resolvedEmojiUrl.length === 0 && textAsFileUrl.length > 0) resolvedEmojiUrl = textAsFileUrl;
        if (resolvedEmojiUrl.length === 0 && cFieldUrl.length > 0) resolvedEmojiUrl = cFieldUrl;
        if (resolvedEmojiUrl.length === 0 && srcEmojiUrl.length > 0) resolvedEmojiUrl = srcEmojiUrl;
        if (resolvedEmojiUrl.length === 0) resolvedEmojiUrl = this.resolveTextEmojiUrl(rawText);
        if (resolvedEmojiUrl.length === 0) resolvedEmojiUrl = this.resolveTextEmojiUrl(cField);
        if (resolvedEmojiUrl.length > 0) {
          fragments.push({ type: ContentFragmentType.EMOJI, text: emojiText, imageUrl: resolvedEmojiUrl });
        } else if (emojiText.length > 0) {
          fragments.push({ type: ContentFragmentType.TEXT, text: emojiText });
        }
        if (emojiText.length > 0) {
          textParts.push(emojiText);
        }
      } else if (type === 3 || type === 20) {
        // IMAGE：3/20 是图片
        if (imageUrl.length > 0) {
          fragments.push({ type: ContentFragmentType.IMAGE, text: item.text ?? '', imageUrl });
          images.push(imageUrl);
        }
        if (item.text !== undefined && item.text.length > 0) {
          textParts.push(item.text);
        }
      } else if (type === 1) {
        // type=1 超链接：text=展示文本（如"网页链接"），link=真实URL
        const rawLink: string = (item.link ?? '').trim();
        if ((rawLink.startsWith('http://') || rawLink.startsWith('https://'))) {
          const display: string = (item.text !== undefined && item.text.length > 0) ? item.text : rawLink;
          fragments.push({ type: ContentFragmentType.LINK, text: display, link: rawLink });
          textParts.push(display);
        } else {
          // 服务端未带 link：按文本原样显示（内部若含 URL 字面量由 return 前 expand 兜底提为 LINK）
          const linkText: string = (item.text !== undefined && item.text.length > 0) ? item.text : rawLink;
          if (linkText.length > 0) {
            fragments.push({ type: ContentFragmentType.TEXT, text: linkText });
            textParts.push(linkText);
          }
        }
      } else if (type === 4 || type === 5 || type === 10 || type === 35 || type === 36 || type === 37 || type === 34) {
        // type=4@ 5视频 10语音 35/36/37贴吧Plus 34旧版贴吧Plus — 只当纯文本追加显示
        if (item.text !== undefined && item.text.length > 0) {
          fragments.push({ type: ContentFragmentType.TEXT, text: item.text });
          textParts.push(item.text);
        }
      } else {
        // 未知 type：若 text/c 是文件名也尝试当表情渲染，否则按文本处理
        const t: string = item.text ?? '';
        const unknownEmojiUrl: string = this.resolveCFieldEmojiUrl(t).length > 0
          ? this.resolveCFieldEmojiUrl(t)
          : (cFieldUrl.length > 0 ? cFieldUrl : '');
        if (unknownEmojiUrl.length > 0) {
          fragments.push({ type: ContentFragmentType.EMOJI, text: this.humanizeEmojiAlt(t, item.c ?? ''), imageUrl: unknownEmojiUrl });
        } else if (t.length > 0) {
          fragments.push({ type: ContentFragmentType.TEXT, text: t });
          textParts.push(t);
        }
        if (imageUrl.length > 0) {
          images.push(imageUrl);
        }
      }
    }
    return { fragments, text: textParts.join(''), images };
  }

  private mapFloorPost(post: PostMessage | undefined, parentFloor: number, pid: string, commentCount: number): FloorItem {
    const contentResult = this.buildFragmentsFromPbContent(post?.content);
    const author = post?.author;
    // 与列表 displayAuthor 保持一致：“贴吧用户_xxx”系统名优先用用户名替代，贴近实时昵称
    const floorNameShow: string | undefined = author?.nameShow;
    const floorUserName: string | undefined = author?.name;
    const authorNameBase: string = (floorNameShow !== undefined && !`${floorNameShow}`.startsWith('贴吧用户_'))
      ? `${floorNameShow}`
      : (floorUserName ?? floorNameShow ?? '贴吧用户');
    const authorIdStr: string = `${post?.authorId ?? author?.id ?? ''}`;
    // 楼层作者昵称：有 profile 校准/详情页确认的权威昵称时优先采用，保证与列表页一致
    const authorName: string = (authorIdStr.length > 0 && this.authorNickProfileConfirmed.has(authorIdStr))
      ? (this.authorNickCache.get(authorIdStr) ?? authorNameBase)
      : authorNameBase;
    return {
      floorId: pid,
      floor: post?.floor ?? parentFloor,
      author: authorName,
      authorAvatar: this.normalizeAvatar({ id: author?.id, name: author?.name, nameShow: author?.nameShow, portrait: `${author?.portrait ?? ''}`, portrait_h: `${author?.portraith ?? ''}`, avatar: `${author?.bimgUrl ?? ''}` }),
      authorId: authorIdStr,
      likeCount: Number(post?.agree?.agreeNum ?? post?.agreeNum ?? 0),
      isLiked: Number(post?.agree?.hasAgree ?? post?.hasAgree ?? 0) === 1 || Number(post?.agree?.agreeType ?? 0) > 0,
      contentText: contentResult.text,
      images: contentResult.images,
      fragments: contentResult.fragments,
      createTime: formatTime(post?.time ?? ''),
      isAuthor: (post?.floor ?? parentFloor) === 1,
      comments: [],
      commentsTotal: commentCount,
      commentsHasMore: false,
      level: this.deriveLevel(authorIdStr, authorName),
      ipLocation: '',
    };
  }

  async togglePostAgree(threadId: string, postId: string, liked: boolean, objType: number = 3): Promise<boolean> {
    const normalizedTid: string = threadId.trim();
    // aiotieba 权威语义：obj_type=3(主帖)时 post_id 必须为 0；obj_type=1(楼层)/2(楼中楼)传对应 pid。
    // 主帖传非零 pid 会触发 obj_type 与 post_id 一致性校验失败（错误码 320022）
    const normalizedPid: string = objType === 3 ? '0' : postId.trim();
    if (normalizedTid.length === 0 || normalizedPid.length === 0) {
      throw new Error('缺少点赞对象信息');
    }
    const bduss = AuthManager.getInstance().getBduss();
    if (bduss.length === 0) {
      throw new Error('请先登录后再进行点赞操作');
    }
    const tbs = await this.getOperationTbs();
    // 接口规范参考 aiotieba / TiebaLite / AioTieba4DotNet：
    // POST /c/c/agree/opAgree，agree_type 固定 2（点赞类型，5 是点踩），
    // 点赞/取消靠 op_type 区分（0=点赞 1=取消），obj_type：3=主帖 1=楼层 2=楼中楼；cuid 设备标识为必传参数
    const form: Record<string, string> = {
      'BDUSS': bduss,
      '_client_type': '2',
      '_client_version': '12.41.7.1',
      'agree_type': '2',
      'cuid': await this.resolveClientCuid(),
      'obj_type': `${objType}`,
      'op_type': liked ? '0' : '1',
      'post_id': normalizedPid,
      'tbs': tbs,
      'thread_id': normalizedTid,
    };
    // 签名
    const sign = await this.signTiebaForm(form);
    form['sign'] = sign;
    const headers: Record<string, string> = {};
    headers['Accept'] = 'application/json, text/plain, */*';
    headers['User-Agent'] = 'tieba/12.41.7.1';
    let responseText: string = '';
    // 域名对齐 aiotieba（APP_BASE_HOST=tiebac.baidu.com，与本项目 protobuf 请求同域）：
    // 楼层/楼中楼点赞（obj_type=1/2）在旧域名上存在更严格的校验，新域名与客户端 12.x 一致
    try {
      responseText = await HttpClient.postForm('https://tiebac.baidu.com/c/c/agree/opAgree', form, headers);
    } catch (e) {
      // 新域名网络失败时回退旧域名
      try {
        responseText = await HttpClient.postForm('https://c.tieba.baidu.com/c/c/agree/opAgree', form, headers);
      } catch (e2) {
        throw new Error(`点赞请求失败: ${(e2 as Error).message}`);
      }
    }
    let payload: Record<string, Object> = {};
    try {
      payload = JSON.parse(responseText) as Record<string, Object>;
    } catch (e) {
      throw new Error(`点赞接口响应异常: ${responseText.substring(0, 100)}`);
    }
    // 同时校验 error_code/no 与 errno 两套错误格式，避免失败响应被静默当成功
    const errorCode: string = `${payload.error_code ?? payload.no ?? payload.errno ?? '0'}`;
    if (errorCode !== '0') {
      // 3280001 = 重复/频繁操作（"你已经点赞过" / "操作太频繁" 同码不同文案）：
      // - 点赞方向：服务端已有点赞记录（此前提交成功过），视为幂等成功，不回滚 UI
      // - 取消方向：服务端拒绝本次取消（限流），保持抛错让调用处回滚到"已点赞"，
      //   与服务端真实状态一致，但用友好提示替代生硬的 API 错误码
      if (errorCode === '3280001') {
        if (liked) {
          return true;
        }
        throw new Error('操作太快啦，请稍后再试');
      }
      const errMsg = `${payload.error_msg ?? payload.errmsg ?? payload.error ?? '点赞操作失败'}`;
      // 带上 tid/pid/obj_type 上下文，便于定位是哪类对象点赞失败
      throw new Error(`API错误[${errorCode}]: ${errMsg} (tid=${normalizedTid}, pid=${normalizedPid}, obj_type=${objType})`);
    }
    return true;
  }

  // 客户端设备标识 cuid（agree 等接口必传）。
  // 对齐 aiotieba 12.x+ 语义：cuid 字段填 cuid_galaxy2 格式（总长42：32位大写HEX + "|V" + 8位base32），
  // 优先取登录 Cookie 中的真实 CUID；否则从 BDUSS 派生稳定值（格式对齐即可，服务端无法回验随机设备的真实性）
  private clientCuidCache: string = '';

  private async resolveClientCuid(): Promise<string> {
    // Cookie 中的 CUID 仅当本身是 cuid_galaxy2 形态（含"|V"分隔）时才直接采用，
    // 网页版 CUID 格式与客户端接口的预期不符
    const cookieCuid: string = this.readCookieValue('CUID');
    if (cookieCuid.includes('|V') && cookieCuid.length >= 40) {
      return cookieCuid;
    }
    if (this.clientCuidCache.length > 0) {
      return this.clientCuidCache;
    }
    const bduss: string = AuthManager.getInstance().getBduss();
    if (bduss.length > 0) {
      // 派生稳定 android_id（16位hex），再按官方算法 md5("com.baidu"+android_id) 生成 32 位大写HEX
      const seed: string = (await HttpClient.md5(`tieba-harmony-${bduss}`)).toLowerCase();
      const androidId: string = seed.substring(0, 16);
      const hexPart: string = (await HttpClient.md5(`com.baidu${androidId}`)).toUpperCase();
      // 尾部 8 位 base32 字符（A-Z2-7）：从 seed 剩余字节映射
      const base32Chars: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
      let tail: string = '';
      for (let i = 16; i < 32 && tail.length < 8; i += 2) {
        const byteVal: number = parseInt(seed.substring(i, i + 2), 16);
        tail += base32Chars.charAt(byteVal % 32);
      }
      while (tail.length < 8) {
        tail += 'A';
      }
      this.clientCuidCache = `${hexPart}|V${tail}`;
      return this.clientCuidCache;
    }
    return '00000000000000000000000000000000|VAAAAAAAA';
  }

  private mapAgree(agree?: AgreeMessage, fallbackNum?: number, fallbackHasAgree?: number): ModernAgreeRecord | undefined {
    if (agree === undefined && fallbackNum === undefined && fallbackHasAgree === undefined) {
      return undefined;
    }
    const mapped: ModernAgreeRecord = {};
    mapped.agreeNum = agree?.agreeNum ?? fallbackNum;
    mapped.hasAgree = agree?.hasAgree ?? fallbackHasAgree;
    mapped.agreeType = agree?.agreeType;
    return mapped;
  }

  private mapSubPostComment(subPost: SubPostListMessage, parentPid: string, index: number): CommentItem {
    const contentResult = this.buildFragmentsFromPbContent(subPost.content);
    const author = subPost.author;
    const authorNameBase: string = author?.nameShow ?? author?.name ?? '贴吧用户';
    const authorIdStr: string = `${subPost.authorId ?? author?.id ?? ''}`;
    // 楼中楼评论作者昵称：有 profile 校准/详情页确认的权威昵称时优先采用
    const authorName: string = (authorIdStr.length > 0 && this.authorNickProfileConfirmed.has(authorIdStr))
      ? (this.authorNickCache.get(authorIdStr) ?? authorNameBase)
      : authorNameBase;
    return {
      commentId: `${subPost.id ?? `${parentPid}-comment-${index}`}`,
      author: authorName,
      authorAvatar: this.normalizeAvatar({ id: author?.id, name: author?.name, nameShow: author?.nameShow, portrait: `${author?.portrait ?? ''}`, portrait_h: `${author?.portraith ?? ''}`, avatar: `${author?.bimgUrl ?? ''}` }),
      authorId: authorIdStr,
      parentPostId: parentPid,
      replyToId: '',
      content: contentResult.text,
      images: contentResult.images,
      fragments: contentResult.fragments,
      floor: subPost.floor,
      createTime: formatTime(subPost.time ?? ''),
      isAuthor: false,
      level: this.deriveLevel(authorIdStr, authorName),
      // 修复点赞数据解析：与主楼层 mapFloorPost 一致，先嵌套 agree 后顶层独立字段双重 fallback
      likeCount: Number(subPost.agree?.agreeNum ?? subPost.agreeNum ?? 0),
      isLiked: Number(subPost.agree?.hasAgree ?? subPost.hasAgree ?? 0) === 1 || Number(subPost.agree?.agreeType ?? 0) > 0,
    };
  }

  private async requestThreadPage(tid: string, page: number, sortType: number = 0, seeLz: boolean = false, forumId: string = '', commentRn: number = 3, commentSortType: number = 0, parentPid: string = ''): Promise<ModernApiPayload> {
    const common = ProtoSchema.commonRequest(new Map<string, string | number>([
      ['_client_type', 2],
      ['_client_version', '12.64.1.1'],
      ['_os_version', '26'],
      ['model', 'HarmonyOS'],
      ['brand', 'Huawei'],
      ['net_type', 1],
      ['scr_w', 360],
      ['scr_h', 800],
      ['scr_dip', 1],
      ['pversion', '1.0.3'],
      ['BDUSS', AuthManager.getInstance().getBduss()]
    ]));
    const data = ProtoSchema.pbPageRequest(new Map<string, string | number>([
      ['kz', Number(tid)],
      ['pid', Number(parentPid) || 0],
      ['pn', page],
      ['lz', seeLz ? 1 : 0],
      ['r', sortType],
      ['st_type', 'tb_frslist'],
      ['back', 0],
      ['floor_rn', Math.max(1, commentRn)],
      ['floor_sort_type', commentSortType],
      ['mark', 0],
      ['rn', 30],
      ['with_floor', 1],
      ['scr_w', 360],
      ['scr_h', 800],
      ['scr_dip', 1],
      ['q_type', 0],
      ['forum_id', Number(forumId) || 0],
      ['request_times', 0]
    ]), common);
    const binary = await this.withTimeout(
      HttpClient.postProtoMultipart('https://tiebac.baidu.com/c/f/pb/page?cmd=302001', data, {
        'User-Agent': 'tieba/12.41.7.1',
        'Accept': 'application/octet-stream',
        'X-BD-DATA-TYPE': 'protobuf',
        'Client-Type': '2',
        'Charset': 'UTF-8',
        'Referer': 'https://tieba.baidu.com/'
      }),
      2000,
      'detail proto'
    );
    const decoded = TiebaProtoDecoder.decodePbPageResponse(binary);
    const errorCode = decoded.error?.errorCode ?? 0;
    if (errorCode !== 0) {
      throw new Error(decoded.error?.userMsg ?? decoded.error?.errorMsg ?? `贴吧详情接口错误 ${errorCode}`);
    }
    const payload: ModernApiPayload = {};
    const decodedForumName: string = decoded.data?.thread?.forumName ?? decoded.data?.forum?.name ?? decoded.data?.displayForum?.name ?? '';
    const decodedForumId: string = `${decoded.data?.thread?.forumId ?? decoded.data?.forum?.id ?? decoded.data?.displayForum?.id ?? forumId}`;
    const decodedForumAvatar: string = (decoded.data?.forum?.avatar ?? decoded.data?.displayForum?.avatar ?? '').toString();
    const firstDecodedPost: PostMessage | undefined = decoded.data?.postList?.[0];
    const decodedThreadAuthor = decoded.data?.thread?.author ?? firstDecodedPost?.author;
    const decodedUsers: ModernAuthorRecord[] = (decoded.data?.userList ?? []).map((user: UserMessage): ModernAuthorRecord => ({
      id: user.id,
      uid: user.id,
      name: user.name,
      name_show: user.nameShow,
      nameShow: user.nameShow,
      user_name: user.name,
      userName: user.name,
      user_nickname: user.nameShow,
      userNickname: user.nameShow,
      nickname: user.nameShow,
      portrait: user.portrait,
      portrait_h: user.portraith,
      portraitH: user.portraith,
      avatar: user.bimgUrl,
      bimg_url: user.bimgUrl,
      new_icon_url: user.newIconUrl?.[0],
      newIconUrl: user.newIconUrl?.[0],
      levelId: user.levelId
    }));
    payload.user_list = decodedUsers;
    const userById: Map<string, ModernAuthorRecord> = new Map<string, ModernAuthorRecord>();
    for (const user of decodedUsers) {
      if (user.id !== undefined && `${user.id}`.length > 0) {
        userById.set(`${user.id}`, user);
      }
    }
    const threadAuthorId: string = `${decoded.data?.thread?.authorId ?? decodedThreadAuthor?.id ?? firstDecodedPost?.authorId ?? ''}`;
    if (decoded.data?.thread !== undefined || decodedThreadAuthor !== undefined || threadAuthorId.length > 0) {
      // 优先合并 thread 级别的 agree 数据（帖子级点赞数在这里）与首楼的 agree 数据
      const threadAgreeData: AgreeMessage | undefined = decoded.data?.thread?.agree;
      const threadAgreeNum: number | undefined = decoded.data?.thread?.agreeNum;
      const threadHasAgree: number | undefined = decoded.data?.thread?.hasAgree;
      const postAgreeData: AgreeMessage | undefined = firstDecodedPost?.agree;
      const postAgreeNum: number | undefined = firstDecodedPost?.agreeNum;
      const postHasAgree: number | undefined = firstDecodedPost?.hasAgree;
      // 合并：thread级优先，缺失则用post级补充
      const mergedAgree: AgreeMessage = {
        agreeNum: threadAgreeData?.agreeNum ?? threadAgreeNum ?? postAgreeData?.agreeNum ?? postAgreeNum,
        hasAgree: threadAgreeData?.hasAgree ?? threadHasAgree ?? postAgreeData?.hasAgree ?? postHasAgree,
        agreeType: threadAgreeData?.agreeType ?? postAgreeData?.agreeType,
        disagreeNum: threadAgreeData?.disagreeNum ?? postAgreeData?.disagreeNum,
        diffAgreeNum: threadAgreeData?.diffAgreeNum ?? postAgreeData?.diffAgreeNum,
      };
      const hasMergedAgree: boolean = mergedAgree.agreeNum !== undefined || mergedAgree.hasAgree !== undefined;
      payload.thread = {
        tid,
        id: `${decoded.data?.thread?.id ?? tid}`,
        title: decoded.data?.thread?.title ?? tid,
        reply_num: decoded.data?.thread?.replyNum,
        forum_info: { name: decodedForumName, id: decodedForumId, avatar: decodedForumAvatar },
        agree: hasMergedAgree ? this.mapAgree(
          mergedAgree.agreeNum !== undefined || mergedAgree.hasAgree !== undefined || mergedAgree.agreeType !== undefined
            ? (mergedAgree as AgreeMessage)
            : undefined,
          mergedAgree.agreeNum,
          mergedAgree.hasAgree
        ) : this.mapAgree(firstDecodedPost?.agree, firstDecodedPost?.agreeNum, firstDecodedPost?.hasAgree),
        agree_num: threadAgreeNum ?? postAgreeNum,
        agreeNum: threadAgreeNum ?? postAgreeNum,
        has_agree: threadHasAgree ?? postHasAgree,
        hasAgree: threadHasAgree ?? postHasAgree,
        // 帖子创建时间：优先 thread.createTime（pb 字段 45），回退 lastTimeInt / 首楼时间
        create_time: decoded.data?.thread?.createTime !== undefined && Number(decoded.data.thread.createTime) > 0
          ? formatTime(decoded.data.thread.createTime)
          : (decoded.data?.thread?.lastTimeInt !== undefined && Number(decoded.data.thread.lastTimeInt) > 0
            ? formatTime(decoded.data.thread.lastTimeInt)
            : formatTime(firstDecodedPost?.time ?? '')),
        last_time: decoded.data?.thread?.lastTime ?? '',
        author: this.mergeAuthor(
          userById.get(threadAuthorId),
          {
            id: decodedThreadAuthor?.id ?? decoded.data?.thread?.authorId,
            uid: decodedThreadAuthor?.id ?? decoded.data?.thread?.authorId,
            name: decodedThreadAuthor?.name,
            name_show: decodedThreadAuthor?.nameShow ?? decodedThreadAuthor?.name,
            nameShow: decodedThreadAuthor?.nameShow,
            user_name: decodedThreadAuthor?.name,
            userName: decodedThreadAuthor?.name,
            user_nickname: decodedThreadAuthor?.nameShow,
            userNickname: decodedThreadAuthor?.nameShow,
            nickname: decodedThreadAuthor?.nameShow,
            portrait: decodedThreadAuthor?.portrait,
            portrait_h: decodedThreadAuthor?.portraith,
            portraitH: decodedThreadAuthor?.portraith,
            avatar: decodedThreadAuthor?.bimgUrl,
            bimg_url: decodedThreadAuthor?.bimgUrl,
            new_icon_url: decodedThreadAuthor?.newIconUrl?.[0],
            newIconUrl: decodedThreadAuthor?.newIconUrl?.[0],
            levelId: decodedThreadAuthor?.levelId
          }
        )
      };
    }
    payload.post_list = (decoded.data?.postList ?? []).map((post: PostMessage): ModernPostRecord => ({
      id: post.id,
      agree: this.mapAgree(post.agree, post.agreeNum, post.hasAgree),
      agree_num: post.agreeNum,
      agreeNum: post.agreeNum,
      has_agree: post.hasAgree,
      hasAgree: post.hasAgree,
      floor: post.floor,
      floor_num: post.floor,
      time: post.time,
      author: this.mergeAuthor(
        userById.get(`${post.authorId ?? post.author?.id ?? ''}`),
        {
          id: post.author?.id ?? post.authorId,
          uid: post.author?.id ?? post.authorId,
          name: post.author?.name,
          name_show: post.author?.nameShow ?? post.author?.name,
          nameShow: post.author?.nameShow,
          user_name: post.author?.name,
          userName: post.author?.name,
          user_nickname: post.author?.nameShow,
          userNickname: post.author?.nameShow,
          nickname: post.author?.nameShow,
          portrait: post.author?.portrait,
          portrait_h: post.author?.portraith,
          portraitH: post.author?.portraith,
          avatar: post.author?.bimgUrl,
          bimg_url: post.author?.bimgUrl,
          new_icon_url: post.author?.newIconUrl?.[0],
          newIconUrl: post.author?.newIconUrl?.[0],
          levelId: post.author?.levelId
        }
      ),
      author_id: post.authorId ?? post.author?.id,
      sub_post_number: post.subPostNumber,
      sub_post_list: (post.subPostList?.subPostList ?? []).map((subPost: SubPostListMessage): ModernSubPostRecord => ({
        id: subPost.id,
        floor: subPost.floor,
        time: subPost.time,
        post_id: post.id,
        reply_to_id: '',
        // 确保 agree 字段完整映射，包括 agreeNum、hasAgree、agreeType；
        // 与主楼层 mapAgree 一致：嵌套 agree 缺失时回退顶层独立 agreeNum/hasAgree，
        // 修复 pb/page 预览接口精简返回时楼中楼回复点赞数丢失显示为 0 的问题
        agree: this.mapAgree(subPost.agree, subPost.agreeNum, subPost.hasAgree),
        author: this.mergeAuthor(
          userById.get(`${subPost.authorId ?? subPost.author?.id ?? ''}`),
          {
            id: subPost.author?.id ?? subPost.authorId,
            uid: subPost.author?.id ?? subPost.authorId,
            name: subPost.author?.name,
            name_show: subPost.author?.nameShow ?? subPost.author?.name,
            nameShow: subPost.author?.nameShow,
            user_name: subPost.author?.name,
            userName: subPost.author?.name,
            user_nickname: subPost.author?.nameShow,
            userNickname: subPost.author?.nameShow,
            nickname: subPost.author?.nameShow,
            portrait: subPost.author?.portrait,
            portrait_h: subPost.author?.portraith,
            portraitH: subPost.author?.portraith,
            avatar: subPost.author?.bimgUrl,
            bimg_url: subPost.author?.bimgUrl,
            new_icon_url: subPost.author?.newIconUrl?.[0],
            newIconUrl: subPost.author?.newIconUrl?.[0]
          }
        ),
        author_id: subPost.authorId ?? subPost.author?.id,
        content: (subPost.content ?? []).map((content: PbContentMessage): ModernPostContentRecord => ({
          text: content.text,
          type: content.type,
          c: content.c,
          src: content.src,
          big_src: content.bigSrc,
          cdn_src: content.cdnSrc,
          big_cdn_src: content.bigCdnSrc,
          origin_src: content.originSrc,
          meme_pic_url: content.memeInfo?.picUrl ?? content.memeInfo?.thumbnail ?? '',
          meme_pck_id: content.memeInfo?.pckId,
          meme_pic_id: content.memeInfo?.picId
        }))
      })),
      content: (post.content ?? []).map((content: PbContentMessage): ModernPostContentRecord => ({
        text: content.text,
        type: content.type,
        link: content.link,
        c: content.c,
        src: content.src,
        big_src: content.bigSrc,
        cdn_src: content.cdnSrc,
        big_cdn_src: content.bigCdnSrc,
        origin_src: content.originSrc,
        meme_pic_url: content.memeInfo?.picUrl ?? content.memeInfo?.thumbnail ?? '',
        meme_pck_id: content.memeInfo?.pckId,
        meme_pic_id: content.memeInfo?.picId
      }))
    }));
    payload.forum = { name: decodedForumName, id: decodedForumId, avatar: decodedForumAvatar };
    payload.has_more = decoded.data?.page?.hasMore === 1 ? '1' : '0';
    payload.total_page = decoded.data?.page?.totalPage;
    payload.current_page = decoded.data?.page?.currentPage;
    payload.page_size = decoded.data?.page?.pageSize;
    payload.total_count = decoded.data?.page?.totalCount;
    return payload;
  }

  private errorMessage(error: Object, fallback: string): string {
    const message = (error as Error).message;
    return message !== undefined && message.length > 0 ? message : fallback;
  }

  private needsWebIdentityHydration(result: ThreadDetailResult): boolean {
    if (result.detail.author.trim().length === 0 || result.detail.author === '贴吧用户') {
      return true;
    }
    if ((result.detail.authorAvatar ?? '').trim().length === 0) {
      return true;
    }
    for (const floor of result.floors) {
      if (floor.author === '贴吧用户' || (floor.authorAvatar ?? '').trim().length === 0) {
        return true;
      }
    }
    return false;
  }

  private mergeThreadIdentity(mobile: ThreadDetailResult, web: ThreadDetailResult): ThreadDetailResult {
    const detailAuthor: string = mobile.detail.author !== '贴吧用户' ? mobile.detail.author : web.detail.author;
    const detailAvatar: string = (mobile.detail.authorAvatar ?? '').length > 0 ? mobile.detail.authorAvatar ?? '' : web.detail.authorAvatar ?? '';
    const webByFloor: Map<number, FloorItem> = new Map<number, FloorItem>();
    for (const floor of web.floors) {
      webByFloor.set(floor.floor, floor);
    }
    const floors: FloorItem[] = mobile.floors.map((floor: FloorItem): FloorItem => {
      const webFloor = webByFloor.get(floor.floor);
      return {
        floorId: floor.floorId,
        floor: floor.floor,
        author: floor.author !== '贴吧用户' ? floor.author : (webFloor?.author ?? floor.author),
        authorAvatar: (floor.authorAvatar ?? '').length > 0 ? floor.authorAvatar : webFloor?.authorAvatar,
        authorId: floor.authorId,
        contentText: floor.contentText,
        images: floor.images,
        fragments: floor.fragments,
        createTime: floor.createTime,
        isAuthor: floor.isAuthor,
        comments: floor.comments,
        commentsTotal: floor.commentsTotal,
        commentsHasMore: floor.commentsHasMore,
        likeCount: floor.likeCount ?? webFloor?.likeCount ?? 0,
        isLiked: floor.isLiked ?? webFloor?.isLiked ?? false,
        level: floor.level ?? webFloor?.level,
        ipLocation: floor.ipLocation ?? webFloor?.ipLocation ?? '',
      };
    });
    const resolvedForumAvatar: string = (mobile.detail.forumAvatar ?? '').length > 0 ? (mobile.detail.forumAvatar ?? '') : (web.detail.forumAvatar ?? '');
    return {
      detail: {
        tid: mobile.detail.tid,
        forumId: mobile.detail.forumId,
        forumAvatar: resolvedForumAvatar,
        title: mobile.detail.title,
        forumName: mobile.detail.forumName,
        author: detailAuthor,
        authorAvatar: detailAvatar,
        authorId: mobile.detail.authorId,
        content: mobile.detail.content,
        contentText: mobile.detail.contentText,
        images: mobile.detail.images,
        fragments: mobile.detail.fragments ?? [],
        likeCount: mobile.detail.likeCount ?? web.detail.likeCount ?? 0,
        isLiked: mobile.detail.isLiked ?? web.detail.isLiked ?? false,
        replyNum: mobile.detail.replyNum,
        createTime: mobile.detail.createTime,
        page: mobile.detail.page,
        totalPage: mobile.detail.totalPage,
        postId: mobile.detail.postId ?? web.detail.postId,
      },
      floors,
    };
  }

  // 后台异步补齐作者身份（昵称/头像/等级等）：不阻塞详情首屏渲染，补齐后通过回调合并结果
  private async hydrateThreadIdentity(mobile: ThreadDetailResult, tid: string, page: number, onDone?: (result: ThreadDetailResult) => void): Promise<void> {
    try {
      const identityHtml = await HttpClient.get(`${API.THREAD}${encodeURIComponent(tid)}?pn=${page}`, {
        'Accept': 'text/html,application/xhtml+xml',
        'Referer': `${TIEBA_BASE}/p/${encodeURIComponent(tid)}`
      });
      const webIdentity = this.parseThreadDetail(identityHtml, tid, page);
      const merged = this.mergeThreadIdentity(mobile, webIdentity);
      if (onDone !== undefined && onDone !== null) {
        onDone(merged);
      }
    } catch (e) {
      // 身份补齐失败：保留移动接口正文数据，静默忽略
    }
  }

  private parseModernThreadDetail(payload: ModernApiPayload, tid: string, page: number, parentPid: string = ''): ThreadDetailResult {
    const thread: ModernThreadRecord | undefined = payload.thread;
    const forumName: string = thread?.forum_info?.name ?? payload.forum?.name ?? '';
    const title: string = thread?.title ?? tid;
    // 详情页楼主昵称：仅 profile 实时接口确认的权威昵称优先采用，
    // 未确认时用接口 name_show（与列表页 enrich 判定一致，避免显示不一致窗口）
    const rawThreadAuthorId: string = `${thread?.author?.id ?? thread?.author?.uid ?? ''}`.trim();
    const cachedAuthorName: string | undefined = (rawThreadAuthorId.length > 0 && this.authorNickProfileConfirmed.has(rawThreadAuthorId))
      ? this.authorNickCache.get(rawThreadAuthorId)
      : undefined;
    const author: string = (cachedAuthorName !== undefined && cachedAuthorName.length > 0)
      ? cachedAuthorName
      : this.displayAuthor(thread?.author);
    const authorAvatar: string = this.normalizeAvatar(thread?.author);
    const records: ModernPostRecord[] = payload.post_list ?? [];
    const parsed: FloorItem[] = [];
    // ================================================================
    // 范围过滤器：避免 time/authorId/id 等大数字被误当作点赞数/楼中楼数
    // 合理点赞范围：0 ~ 99999999（1亿以内）
    // 合理楼中楼数范围：0 ~ 10000（1万以内，贴吧单楼层回复数上限约几千）
    // ================================================================
    const clampLike = (n: number): number => {
      const v = Math.trunc(Number(n));
      return (isNaN(v) || v < 0 || v > 99999999) ? 0 : v;
    };
    const clampSub = (n: number): number => {
      const v = Math.trunc(Number(n));
      return (isNaN(v) || v < 0 || v > 10000) ? 0 : v;
    };
    for (let index = 0; index < records.length; index++) {
      const record = records[index];
      const floorContent = this.buildFragmentsFromContent(record.content);
      const textParts: string = floorContent.text;
      const images: string[] = floorContent.images;
      const fragments: ContentFragment[] = floorContent.fragments;
      const rawFloor: number = Number(record.floor ?? record.floor_num ?? record.floorNum ?? record.post_no ?? record.postNo ?? 0);
      const floor: number = rawFloor > 0 ? rawFloor : index + 1;
      // 楼层作者昵称：仅 profile 实时接口确认的权威昵称优先采用，保证与列表页一致
      const rawFloorAuthorId: string = `${record.author_id ?? record.author?.id ?? ''}`.trim();
      const cachedFloorName: string | undefined = (rawFloorAuthorId.length > 0 && this.authorNickProfileConfirmed.has(rawFloorAuthorId))
        ? this.authorNickCache.get(rawFloorAuthorId)
        : undefined;
      const floorAuthor: string = (cachedFloorName !== undefined && cachedFloorName.length > 0)
        ? cachedFloorName
        : this.displayAuthor(record.author);
      const rawComments: ModernSubPostRecord[] = record.sub_post_list ?? record.subPostList ?? [];
      const comments: CommentItem[] = rawComments.map((comment: ModernSubPostRecord, commentIndex: number): CommentItem => {
        const commentContent = this.buildFragmentsFromContent(comment.content);
        const commentAuthorId: string = `${comment.author_id ?? comment.author?.id ?? ''}`;
        const cachedCommentName: string | undefined = (commentAuthorId.length > 0 && this.authorNickProfileConfirmed.has(commentAuthorId))
          ? this.authorNickCache.get(commentAuthorId)
          : undefined;
        const commentAuthor: string = (cachedCommentName !== undefined && cachedCommentName.length > 0)
          ? cachedCommentName
          : this.displayAuthor(comment.author);
        return {
          commentId: `${comment.id ?? `${record.id ?? floor}-comment-${commentIndex}`}`,
          author: commentAuthor,
          authorAvatar: this.normalizeAvatar(comment.author),
          authorId: commentAuthorId,
          parentPostId: `${comment.post_id ?? record.id ?? ''}`,
          replyToId: `${comment.reply_to_id ?? ''}`,
          content: commentContent.text,
          images: commentContent.images,
          fragments: commentContent.fragments,
          floor: comment.floor,
          createTime: formatTime(comment.time ?? ''),
          isAuthor: commentAuthor !== '贴吧用户' && commentAuthor === author,
          level: this.deriveLevel(commentAuthorId, commentAuthor),
          likeCount: clampLike(Number(comment.agree?.agreeNum ?? comment.agree?.agree_num ?? 0)),
          isLiked: Number(comment.agree?.hasAgree ?? comment.agree?.has_agree ?? comment.agree?.agreeType ?? 0) > 0,
        };
      });
      parsed.push({
        floorId: `${record.id ?? floor}`,
        floor,
        author: floorAuthor,
        authorAvatar: this.normalizeAvatar(record.author),
        authorId: `${record.author_id ?? record.author?.id ?? ''}`,
        // 全兼容likeCount：仅取嵌套agree.agreeNum / 顶层agreeNum / 顶层agree_num，
        // 并通过clampLike范围过滤，杜绝time/id/authorId大数字污染
        likeCount: Math.max(
          clampLike(Number(record.agree?.agreeNum ?? 0)),
          clampLike(Number(record.agree?.agree_num ?? 0)),
          clampLike(Number(record.agreeNum ?? 0)),
          clampLike(Number(record.agree_num ?? 0)),
          0
        ),
        // 全兼容isLiked：嵌套hasAgree===1 / 顶层hasAgree===1 / agreeType>0 → OR逻辑任一命中即已点赞
        isLiked: Number(record.agree?.hasAgree ?? record.agree?.has_agree ?? 0) === 1
          || Number(record.hasAgree ?? record.has_agree ?? 0) === 1
          || Number(record.agree?.agreeType ?? record.agree?.agree_type ?? record.agreeType ?? record.agree_type ?? 0) > 0,
        contentText: textParts,
        images,
        fragments,
        createTime: formatTime(record.time ?? ''),
        isAuthor: floor === 1 || floorAuthor === author,
        comments,
        // 楼中楼数：sub_post_number先做范围过滤，若过滤后为0则用实际comments数组长度兜底
        commentsTotal: clampSub(Number(record.sub_post_number ?? 0)) || comments.length,
        // 若sub_post_number > 实际已加载 comments 长度，则还有更多
        commentsHasMore: clampSub(Number(record.sub_post_number ?? 0)) > comments.length,
        level: Number(record.author?.levelId ?? 0) || this.deriveLevel(`${record.author_id ?? record.author?.id ?? ''}`, floorAuthor),
        ipLocation: '',
      });
    }

    // PbPage 的 post_list 包含首楼；普通详情回复区只保留第 2 楼及以后。
    // 楼中楼详情带 parentPid 时，即使接口只返回当前主楼，也必须保留它作为父楼展示。
    const firstFloor: FloorItem | undefined = parsed.find((floor: FloorItem) => floor.floor === 1) ?? parsed[0];
    const normalizedParentPid: string = parentPid.trim();
    const floors: FloorItem[] = normalizedParentPid.length > 0
      ? parsed.filter((floor: FloorItem): boolean => floor.floorId === normalizedParentPid || floor.floorId === `${Number(normalizedParentPid)}`)
      : parsed.filter((floor: FloorItem) => floor !== firstFloor && floor.floor > 1);
    // 某些 pb/page 响应只在首个 post 中携带作者资料，不能只依赖 ThreadInfo.author。
    const resolvedAuthor: string = author !== '贴吧用户' && author.length > 0
      ? author
      : (firstFloor?.author ?? '贴吧用户');
    const resolvedAvatar: string = authorAvatar.length > 0
      ? authorAvatar
      : (firstFloor?.authorAvatar ?? '');
    // 详情页昵称回填：把已确认的实时昵称写入缓存（user_list 全部作者 + 楼主），
    // 供推荐页/列表页校准过期/缺失的 JSON 昵称，保证详情页与列表页名称一致。
    // v1.22 详情页 proto user_list 昵称与个人信息页一致（用户已确认），标 confirmed=true，
    // 使推荐页 onPageShow 的 refreshAuthorsFromCache 直接读取生效——修复
    // “推荐页显示吧友XXX、详情页正确、返回推荐页仍不刷新”的根因。
    const resolvedAuthorId: string = `${thread?.author?.id ?? firstFloor?.authorId ?? ''}`.trim();
    for (const detailUser of (payload.user_list ?? [])) {
      this.rememberAuthor(detailUser, true);
    }
    this.rememberAuthor(thread?.author, true);
    this.rememberAuthor({ id: resolvedAuthorId, name: resolvedAuthor, name_show: resolvedAuthor }, true);
    console.info(`[AUTHORDIAG] detail: tid=${tid} author=[${resolvedAuthor}] authorId=${resolvedAuthorId || '(空)'} threadAuthor=${JSON.stringify({ name: thread?.author?.name, name_show: thread?.author?.name_show, id: thread?.author?.id })} userList0..4=${(payload.user_list ?? []).slice(0, 5).map((u: ModernAuthorRecord): string => `${u.id ?? u.uid ?? '?'}=${u.name_show ?? u.nameShow ?? '(无名)'}(${u.name ?? ''})`).join('|')} firstFloorAuthor=[${firstFloor?.author ?? ''}]`);
    const detail: ThreadDetail = {
      tid,
      postId: `${firstFloor?.floorId ?? ''}`,
      title,
      forumName,
      forumId: thread?.forum_info?.id ?? payload.forum?.id ?? '',
      forumAvatar: this.extractForumAvatar(payload.forum),
      author: resolvedAuthor,
      authorAvatar: resolvedAvatar,
      authorId: `${thread?.author?.id ?? firstFloor?.authorId ?? ''}`,
      // 全兼容likeCount：首楼兜底 / thread嵌套agree / thread顶层独立字段 → 先做范围过滤再取非零最大值
      likeCount: Math.max(
        clampLike(firstFloor?.likeCount ?? 0),
        clampLike(Number(thread?.agree?.agreeNum ?? 0)),
        clampLike(Number(thread?.agree?.agree_num ?? 0)),
        clampLike(Number(thread?.agreeNum ?? 0)),
        clampLike(Number(thread?.agree_num ?? 0)),
        0
      ),
      // 全兼容isLiked：首楼兜底 / thread嵌套 / thread顶层独立 / agreeType → OR逻辑
      isLiked: (firstFloor?.isLiked ?? false)
        || Number(thread?.agree?.hasAgree ?? thread?.agree?.has_agree ?? 0) === 1
        || Number(thread?.hasAgree ?? thread?.has_agree ?? 0) === 1
        || Number(thread?.agree?.agreeType ?? thread?.agree?.agree_type ?? thread?.agreeType ?? thread?.agree_type ?? 0) > 0,
      content: firstFloor?.contentText ?? thread?.first_post_content ?? '',
      contentText: firstFloor?.contentText ?? thread?.first_post_content ?? '',
      images: firstFloor?.images ?? [],
      fragments: firstFloor?.fragments ?? [],
      replyNum: thread?.reply_num !== undefined ? Number(thread.reply_num) : parsed.length,
      createTime: thread?.create_time ?? thread?.last_time ?? '',
      level: Number(thread?.author?.levelId ?? firstFloor?.level ?? 0) || 0,
      page,
      totalPage: Number(payload.total_page ?? 0) > 0 ? Number(payload.total_page) : (payload.has_more === '1' ? page + 1 : page),
    };
    return { detail, floors };
  }

  private mergeAuthor(primary?: ModernAuthorRecord, fallback?: ModernAuthorRecord): ModernAuthorRecord {
    const firstText = (first?: string, second?: string): string | undefined => {
      if (first !== undefined && first.trim().length > 0) {
        return first.trim();
      }
      if (second !== undefined && second.trim().length > 0) {
        return second.trim();
      }
      return undefined;
    };
    return {
      id: primary?.id ?? primary?.uid ?? fallback?.id ?? fallback?.uid,
      uid: primary?.uid ?? primary?.id ?? fallback?.uid ?? fallback?.id,
      name: firstText(primary?.name, fallback?.name),
      name_show: firstText(primary?.name_show, fallback?.name_show),
      nameShow: firstText(primary?.nameShow, fallback?.nameShow),
      user_name: firstText(primary?.user_name, fallback?.user_name),
      userName: firstText(primary?.userName, fallback?.userName),
      user_nickname: firstText(primary?.user_nickname, fallback?.user_nickname),
      userNickname: firstText(primary?.userNickname, fallback?.userNickname),
      nickname: firstText(primary?.nickname, fallback?.nickname),
      portrait: firstText(primary?.portrait, fallback?.portrait),
      portrait_h: firstText(primary?.portrait_h, fallback?.portrait_h),
      portraitH: firstText(primary?.portraitH, fallback?.portraitH),
      avatar: firstText(primary?.avatar, fallback?.avatar),
      avatar_url: firstText(primary?.avatar_url, fallback?.avatar_url),
      bimg_url: firstText(primary?.bimg_url, fallback?.bimg_url),
      new_icon_url: firstText(primary?.new_icon_url, fallback?.new_icon_url),
      newIconUrl: firstText(primary?.newIconUrl, fallback?.newIconUrl)
    };
  }

  private buildFragmentsFromContent(contentList: ModernPostContentRecord[] | undefined): FragmentsResult {
    const fragments: ContentFragment[] = [];
    const textParts: string[] = [];
    const images: string[] = [];
    for (const item of contentList ?? []) {
      const type: number = item.type ?? 0;
      const rawUrl2: string = item.origin_src ?? item.big_cdn_src ?? item.cdn_src ?? item.src ?? item.big_src ?? '';
      const imageUrl: string = this.normalizeUrl(rawUrl2);
      const memePicUrl: string = this.normalizeUrl(item.meme_pic_url ?? '');
      const memePackageUrl: string = this.resolveMemePackageUrl(item.meme_pck_id, item.meme_pic_id);
      const cFieldUrl: string = this.resolveCFieldEmojiUrl(item.c ?? '');
      // 同 buildFragmentsFromPbContent：0/9/18/27/40 文本，2/11 表情，3/20 图片，1/4/5/10/35/36/37 特殊文本，未知按表情+c字段兜底
      if (type === 0 || type === undefined || type === 9 || type === 18 || type === 27 || type === 40) {
        if (item.text !== undefined && item.text.length > 0) {
          // 旧版/网页端帖子把表情序列化为字面文本（[呵呵]/#(呵呵) 内嵌在长文本任意位置），拆分为混合片段渲染
          const inlineParts: ContentFragment[] = this.splitTextWithInlineEmojis(item.text);
          for (const part of inlineParts) {
            fragments.push(part);
          }
          textParts.push(item.text);
        }
      } else if (type === 2 || type === 11) {
        // EMOJI：2/11 才是表情（aiotieba 权威定义：text=表情图片id、c=表情描述）
        // 两个字段都尝试按文件名解析，兼容语义互换的接口；优先级 pckId+picId→text文件名→c文件名→memeInfo/src链→名称映射
        const rawText: string = item.text ?? '';
        const cField: string = item.c ?? '';
        const emojiText: string = this.humanizeEmojiAlt(rawText, cField);
        const textAsFileUrl: string = this.resolveCFieldEmojiUrl(rawText);
        const pkgUrl: string = memePackageUrl.length > 0 ? memePackageUrl : '';
        const srcEmojiUrl: string = memePicUrl.length > 0 ? memePicUrl : imageUrl;
        let resolvedEmojiUrl: string = pkgUrl.length > 0 ? pkgUrl : '';
        if (resolvedEmojiUrl.length === 0 && textAsFileUrl.length > 0) resolvedEmojiUrl = textAsFileUrl;
        if (resolvedEmojiUrl.length === 0 && cFieldUrl.length > 0) resolvedEmojiUrl = cFieldUrl;
        if (resolvedEmojiUrl.length === 0 && srcEmojiUrl.length > 0) resolvedEmojiUrl = srcEmojiUrl;
        if (resolvedEmojiUrl.length === 0) resolvedEmojiUrl = this.resolveTextEmojiUrl(rawText);
        if (resolvedEmojiUrl.length === 0) resolvedEmojiUrl = this.resolveTextEmojiUrl(cField);
        if (resolvedEmojiUrl.length > 0) {
          fragments.push({ type: ContentFragmentType.EMOJI, text: emojiText, imageUrl: resolvedEmojiUrl });
        } else if (emojiText.length > 0) {
          fragments.push({ type: ContentFragmentType.TEXT, text: emojiText });
        }
        if (emojiText.length > 0) {
          textParts.push(emojiText);
        }
      } else if (type === 3 || type === 20) {
        if (imageUrl.length > 0) {
          fragments.push({ type: ContentFragmentType.IMAGE, text: item.text ?? '', imageUrl });
          images.push(imageUrl);
        }
        if (item.text !== undefined && item.text.length > 0) {
          textParts.push(item.text);
        }
      } else if (type === 1) {
        // type=1 超链接：text=展示文本（如"网页链接"），link=真实URL
        const rawLink: string = (item.link ?? '').trim();
        if ((rawLink.startsWith('http://') || rawLink.startsWith('https://'))) {
          const display: string = (item.text !== undefined && item.text.length > 0) ? item.text : rawLink;
          fragments.push({ type: ContentFragmentType.LINK, text: display, link: rawLink });
          textParts.push(display);
        } else {
          // 服务端未带 link：按文本原样显示（内部若含 URL 字面量由 return 前 expand 兜底提为 LINK）
          const linkText: string = (item.text !== undefined && item.text.length > 0) ? item.text : rawLink;
          if (linkText.length > 0) {
            fragments.push({ type: ContentFragmentType.TEXT, text: linkText });
            textParts.push(linkText);
          }
        }
      } else if (type === 4 || type === 5 || type === 10 || type === 35 || type === 36 || type === 37 || type === 34) {
        // 4@ / 5视频 / 10语音 / 35/36/37贴吧Plus 34旧版贴吧Plus → 仅显示文本
        if (item.text !== undefined && item.text.length > 0) {
          fragments.push({ type: ContentFragmentType.TEXT, text: item.text });
          textParts.push(item.text);
        }
      } else {
        // 未知 type：若 text/c 是文件名也尝试当表情渲染，否则按文本处理
        const t: string = item.text ?? '';
        const unknownEmojiUrl: string = this.resolveCFieldEmojiUrl(t).length > 0
          ? this.resolveCFieldEmojiUrl(t)
          : (cFieldUrl.length > 0 ? cFieldUrl : '');
        if (unknownEmojiUrl.length > 0) {
          fragments.push({ type: ContentFragmentType.EMOJI, text: this.humanizeEmojiAlt(t, item.c ?? ''), imageUrl: unknownEmojiUrl });
        } else if (t.length > 0) {
          fragments.push({ type: ContentFragmentType.TEXT, text: t });
          textParts.push(t);
        }
        if (imageUrl.length > 0) {
          images.push(imageUrl);
        }
      }
    }
    this.expandUrlLinksInFragments(fragments, textParts);
    return { fragments, text: textParts.join(''), images };
  }

  private displayAuthor(author?: ModernAuthorRecord): string {
    const rawNameShow: string | undefined = author?.name_show
      ?? author?.nameShow
      ?? author?.user_nickname
      ?? author?.userNickname;
    const rawUserName: string | undefined = author?.user_name
      ?? author?.userName
      ?? author?.name
      ?? author?.nickname;
    // “贴吧用户_xxx”是系统生成的占位名（JSON 旧接口缓存），不是真实昵称；
    // 此时优先显示用户名，与详情页 proto 实时昵称（或用户名）更接近
    const value: string = (rawNameShow !== undefined && !`${rawNameShow}`.startsWith('贴吧用户_'))
      ? `${rawNameShow}`
      : (rawUserName ?? rawNameShow ?? '');
    const cleaned: string = decodeHtmlEntities(value).replace(/\s+/g, ' ').trim();
    // 昵称仅由不可见字符组成时（零宽空格等）视为无有效昵称：优先回退用户名
    if (cleaned.length > 0 && !this.isInvisibleNickname(cleaned)) {
      return cleaned;
    }
    const cleanedUser: string = rawUserName !== undefined
      ? decodeHtmlEntities(`${rawUserName}`).replace(/\s+/g, ' ').trim()
      : '';
    if (cleanedUser.length > 0 && !this.isInvisibleNickname(cleanedUser)) {
      return cleanedUser;
    }
    // Fallback: try user_id
    const uidStr = `${author?.id ?? ''}`.trim();
    if (uidStr.length > 0 && uidStr !== '0') {
      return `吧友${uidStr.slice(-4)}`;
    }
    return '贴吧用户';
  }

  /**
   * Resolve author info from multiple sources
   */
  private resolveAuthorInfo(primary?: UserMessage, secondary?: UserMessage, fallbackId?: number): ModernAuthorRecord {
    // Helper to check if a UserMessage has useful name data
    const hasName = (u?: UserMessage): boolean => {
      if (!u) return false;
      const n = (u.name ?? u.nameShow ?? '').toString().trim();
      return n.length > 0;
    };
    const hasAvatar = (u?: UserMessage): boolean => {
      if (!u) return false;
      const p = (u.portrait ?? u.portraith ?? u.bimgUrl ?? u.newIconUrl?.[0] ?? '').toString().trim();
      return p.length > 0;
    };
    
    // 对齐官方客户端策略：user_list（含 name_show 昵称）匹配到作者时优先使用，
    // 因为 frs/page 的 user_list 比 thread 内嵌 author 信息更完整；
    // 仅当 user_list 未匹配或全空时才回退到内嵌 author。
    const best = secondary && (hasName(secondary) || hasAvatar(secondary)) ? secondary : (primary ?? secondary);
    
    if (!best) {
      // No user data at all, use fallback
      return { id: fallbackId };
    }
    
    return {
      id: best.id ?? fallbackId,
      name: `${best.name ?? ''}`,
      name_show: `${best.nameShow ?? ''}`,
      portrait: `${best.portrait ?? ''}`,
      portrait_h: `${best.portraith ?? ''}`,
      avatar: `${best.bimgUrl ?? ''}`,
      new_icon_url: best.newIconUrl?.[0],
    };
  }

  /**
   * 根据用户ID/名称推导一个稳定的等级值 (1-20)
   * 贴吧API不直接返回楼层作者等级，用hash生成伪随机但稳定的等级
   */
  private deriveLevel(userId: string, userName: string): number {
    const seed = (userId.length > 0 ? userId : userName).toString();
    let hash = 0;
    for (let i = 0; i < seed.length; i++) {
      hash = ((hash << 5) - hash + seed.charCodeAt(i)) | 0;
    }
    return Math.abs(hash) % 20 + 1;
  }

  private normalizeAvatar(author?: ModernAuthorRecord): string {
    // Try all possible avatar sources in priority order
    const sources: string[] = [
      author?.new_icon_url ?? '',
      author?.newIconUrl ?? '',
      author?.avatar_url ?? '',
      author?.bimg_url ?? '',
      author?.avatar ?? '',
      author?.portrait_h ?? '',
      author?.portraitH ?? '',
      author?.portrait ?? '',
    ];
    for (const rawVal of sources) {
      const raw: string = decodeHtmlEntities(`${rawVal ?? ''}`).trim().replace(/^['\"]|['\"]$/g, '');
      if (raw.length === 0 || raw === 'null' || raw === 'undefined' || raw === '0') {
        continue;
      }
      // Full URL
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        return raw.replace(/^http:\/\//, 'https://');
      }
      // Protocol-relative
      if (raw.startsWith('//')) {
        return `https:${raw}`;
      }
      // Absolute path
      if (raw.startsWith('/')) {
        return `${TIEBA_BASE}${raw}`;
      }
      // portrait hash (e.g. "tb.xxx" or "xxx") - try portraith endpoint
      if (raw.includes('portraith') || raw.startsWith('tb.') || (raw.includes('.') && raw.length > 15)) {
        return `https://himg.bdimg.com/sys/portraith/item/${raw}`;
      }
      // Numeric user ID -> Baidu portrait by ID
      if (/^\d+$/.test(raw)) {
        return `https://tb.himg.baidu.com/sys/portrait/item/${raw}`;
      }
      // Long hash without tb. prefix - likely portrait hash
      if (raw.length >= 16) {
        return `https://himg.bdimg.com/sys/portraith/item/${raw}`;
      }
      // Other non-empty string
      if (raw.length >= 6) {
        return `https://tb.himg.baidu.com/sys/portrait/item/${raw}`;
      }
    }
    // Ultimate fallback: construct from user ID
    const idStr = `${author?.id ?? ''}`.trim();
    if (idStr.length > 0 && idStr !== '0' && /^\d+$/.test(idStr)) {
      return `https://tb.himg.baidu.com/sys/portrait/item/${idStr}`;
    }
    return '';
  }

  private extractForumAvatar(forum?: ModernForumRecord | ModernForumInfo): string {
    if (!forum) {
      return '';
    }
    // Directly access known fields via type assertion
    const f = forum as Record<string, string | number | undefined>;
    const raw: string = (f['avatar']
      ?? f['forum_avatar']
      ?? f['head_url']
      ?? f['headPic']
      ?? f['head_pic']
      ?? f['pic']
      ?? f['img']
      ?? '') as string;
    const normalized = this.normalizeForumAvatar(raw);
    if (normalized.length > 0) {
      return normalized;
    }
    const fid: string = `${f['id'] ?? ''}`.trim();
    if (fid.length > 0) {
      return `https://gsp0.baidu.com/5aAHeD3nKhI2p27jWwn0b8cqw1ZYqQ/uploads/forum/avatar/${encodeURIComponent(fid)}_small.jpg`;
    }
    return '';
  }

  /**
   * 获取贴吧头像（通过多种来源获取）
   */
  async fetchForumAvatarByName(forumName: string): Promise<string> {
    // Priority 1: Try protobuf API (most reliable, used by thread list loading)
    try {
      const common = ProtoSchema.commonRequest(new Map<string, string | number>([
        ['_client_type', 2],
        ['_client_version', '12.41.7.1'],
        ['_os_version', '26'],
        ['model', 'HarmonyOS'],
        ['brand', 'Huawei'],
        ['net_type', 1],
        ['scr_w', 360],
        ['scr_h', 800],
        ['scr_dip', 1],
        ['pversion', '1.0.3'],
        ['BDUSS', AuthManager.getInstance().getBduss()]
      ]));
      const data = ProtoSchema.frsPageRequest(new Map<string, string | number>([
        ['kw', forumName],
        ['rn', 1],
        ['rn_need', 1],
        ['is_good', 0],
        ['pn', 0],
        ['sort_type', 0],
      ]), common);
      const binary = await HttpClient.postProtoMultipart('https://c.tieba.baidu.com/c/f/frs/page?cmd=301001', data, {
        'User-Agent': 'tieba/12.41.7.1',
        'Accept': 'application/octet-stream',
        'X-BD-DATA-TYPE': 'protobuf',
        'Client-Type': '2',
        'Charset': 'UTF-8',
        'Referer': 'https://tieba.baidu.com/'
      });
      const decoded: FrsPageResponseMessage = TiebaProtoDecoder.decodeFrsPageResponse(binary);
      // Check global forum avatar (FrsForumMessage field 24)
      let avatar: string = (decoded.data?.forum?.avatar ?? '').toString();
      // Fallback: check first thread's forumInfo avatar (ThreadInfoMessage.forumInfo, SimpleForumMessage field 4)
      if (avatar.length === 0) {
        const threads = decoded.data?.threadList ?? [];
        if (threads.length > 0) {
          const threadAvatar = (threads[0].forumInfo?.avatar ?? '').toString();
          if (threadAvatar.length > 0) {
            avatar = threadAvatar;
          }
        }
      }
      if (avatar.length > 0) {
        return this.normalizeForumAvatar(avatar);
      }
    } catch (e) {
      // Protobuf failed, try next
    }

    // Priority 2: Try search results HTML (works for any forum, followed or not)
    try {
      const searchUrl = `${API.SEARCH_FORUM}${encodeURIComponent(forumName)}`;
      const html = await HttpClient.get(searchUrl, {
        'Accept': 'text/html',
        'Referer': `${TIEBA_BASE}/`,
      });
      const avatar = this.extractAvatarFromSearchHtml(html, forumName);
      if (avatar.length > 0) {
        return avatar;
      }
    } catch (e) {
      // Search failed
    }

    // Priority 3: Try forum page HTML scraping
    try {
      const forumUrl = `${API.FORUM_THREADS}${encodeURIComponent(forumName)}`;
      const html = await HttpClient.get(forumUrl, {
        'Accept': 'text/html',
        'Referer': `${TIEBA_BASE}/`,
      });
      const avatar = this.extractWebAvatar(html);
      if (avatar.length > 0) {
        return avatar;
      }
    } catch (e) {
      // Forum page failed
    }

    return '';
  }

  /**
   * 从搜索结果HTML中提取指定贴吧的头像URL
   */
  private extractAvatarFromSearchHtml(html: string, forumName: string): string {
    // Escape special regex chars in forum name
    const escapedName = forumName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    // Find the forum link: <a href="/f?kw=forumName" ...> ... <img ... /> ... </a>
    const linkRegex = new RegExp(`<a[^>]*href="/f\\?kw=${escapedName}[^"]*"[^>]*>([\\s\\S]*?)</a>`, 'i');
    const linkMatch = linkRegex.exec(html);
    if (!linkMatch) {
      return '';
    }
    const innerHtml = linkMatch[1];
    // Extract img src from inside the link
    const imgRegex = /<img[^>]+(?:src|data-src|data-original)=["']([^"']+)["']/i;
    const imgMatch = imgRegex.exec(innerHtml);
    if (imgMatch) {
      return this.normalizeForumAvatar(imgMatch[1]);
    }
    return '';
  }

  /**
   * 获取我的关注吧列表
   */
  async fetchFollowList(page: number = 1): Promise<PagedResult<FollowItem>> {
    let modernList: PagedResult<FollowItem> | null = null;
    try {
      const user = AuthManager.getInstance().getUser();
      const payload = await this.requestModernApi(API.USER_LIKE_FORUM, {
        page_no: `${page}`,
        page_size: '50',
        uid: user?.userId ?? '',
        friend_uid: '',
        is_guest: user ? '0' : '1',
        _client_version: '11.10.8.6',
        client_type: '2',
        _os_version: '26',
        _client_type: '2',
      });
      modernList = this.parseModernFollowList(payload, page);
    } catch (e) {
      // Modern API failed, will try HTML below
    }

    // Always try HTML endpoint for avatars (it returns proper img URLs)
    let htmlList: PagedResult<FollowItem> | null = null;
    if (this.hasLoginCookie()) {
      try {
        const url = `${API.FOLLOW_LIST}${page}`;
        const html = await HttpClient.get(url);
        htmlList = this.parseFollowList(html, page);
      } catch (e) {
        // HTML fetch failed
      }
    }

    // Merge: use modern API as base (has structured data), fill avatars from HTML
    if (modernList && modernList.list.length > 0) {
      if (htmlList && htmlList.list.length > 0) {
        // Build avatar map from HTML results
        const avatarMap = new Map<string, string>();
        for (const h of htmlList.list) {
          if (h.avatar && h.avatar.length > 0) {
            avatarMap.set(h.forumName, h.avatar);
          }
        }
        // Fill avatars into modern results where missing
        for (const item of modernList.list) {
          if (!item.avatar || item.avatar.length === 0) {
            const htmlAvatar = avatarMap.get(item.forumName);
            if (htmlAvatar && htmlAvatar.length > 0) {
              item.avatar = htmlAvatar;
            }
          }
        }
      }
      return modernList;
    }

    // Modern API failed/empty, use HTML results directly
    if (htmlList) {
      return htmlList;
    }

    // Both failed or empty
    return { list: [], hasMore: false, page };
  }

  private hasLoginCookie(): boolean {
    return AuthManager.getInstance().isLogin();
  }

  private async requestModernApi(url: string, formData: ModernRequestForm): Promise<ModernApiPayload> {
    let raw: string = '';
    const addRaw = (key: string, value: string | undefined): void => {
      if (value !== undefined) {
        raw += `${key}=${value}`;
      }
    };
    addRaw('_client_type', formData._client_type);
    addRaw('_client_version', formData._client_version);
    addRaw('_os_version', formData._os_version);
    addRaw('client_type', formData.client_type);
    addRaw('friend_uid', formData.friend_uid);
    addRaw('is_guest', formData.is_guest);
    addRaw('kw', formData.kw);
    addRaw('thread_id', formData.thread_id);
    addRaw('post_id', formData.post_id);
    addRaw('kz', formData.kz);
    addRaw('load_type', formData.load_type);
    addRaw('need_forumlist', formData.need_forumlist);
    addRaw('need_tags', formData.need_tags);
    addRaw('new_install', formData.new_install);
    addRaw('new_net_type', formData.new_net_type);
    addRaw('page_no', formData.page_no);
    addRaw('page_size', formData.page_size);
    addRaw('page_thread_count', formData.page_thread_count);
    addRaw('pn', formData.pn);
    addRaw('q_type', formData.q_type);
    addRaw('request_time', formData.request_time);
    addRaw('rn', formData.rn);
    addRaw('scr_dip', formData.scr_dip);
    addRaw('scr_h', formData.scr_h);
    addRaw('scr_w', formData.scr_w);
    addRaw('sort_type', formData.sort_type);
    addRaw('st_type', formData.st_type);
    addRaw('uid', formData.uid);
    addRaw('with_group', formData.with_group);
    addRaw('is_good', formData.is_good);
    addRaw('lz', formData.lz);
    addRaw('r', formData.r);
    addRaw('back', formData.back);
    addRaw('floor_rn', formData.floor_rn);
    addRaw('floor_sort_type', formData.floor_sort_type);
    addRaw('comment_rn', formData.comment_rn);
    addRaw('mark', formData.mark);
    addRaw('with_floor', formData.with_floor);
    if (formData.protobufData !== undefined) {
      const response = await HttpClient.postBinary(url, formData.protobufData, {
        'User-Agent': 'tieba/12.0.0',
        'Accept': 'application/json',
        'Origin': 'https://tieba.baidu.com',
        'Referer': 'https://tieba.baidu.com/',
      });
      return JSON.parse(response) as ModernApiPayload;
    }
    const requestForm: Record<string, string> = {};
    const keys: string[] = [
      '_client_type', '_client_version', '_os_version', 'client_type', 'friend_uid', 'is_guest', 'kw', 'thread_id', 'post_id', 'kz',
      'load_type', 'need_forumlist', 'need_tags', 'new_install', 'new_net_type', 'page_no', 'page_size', 'page_thread_count',
      'pn', 'q_type', 'request_time', 'rn', 'scr_dip', 'scr_h', 'scr_w', 'sort_type', 'st_type', 'uid', 'with_group', 'is_good',
      'lz', 'r', 'back', 'floor_rn', 'floor_sort_type', 'comment_rn', 'mark', 'with_floor'
    ];
    for (const key of keys) {
      const value: string | undefined = this.readRequestValue(formData, key);
      if (value !== undefined) {
        requestForm[key] = value;
      }
    }
    const signKeys: string[] = Object.keys(requestForm).sort();
    let signInput: string = '';
    for (const key of signKeys) {
      signInput += `${key}=${requestForm[key]}`;
    }
    requestForm.sign = await HttpClient.md5(`${signInput}tiebaclient!!!`);
    const encodedPairs: string[] = [];
    for (const key of Object.keys(requestForm).sort()) {
      encodedPairs.push(`${encodeURIComponent(key)}=${encodeURIComponent(requestForm[key])}`);
    }
    const response = await HttpClient.postEncoded(url, encodedPairs.join('&'), {
      'User-Agent': 'bdtb for Android 11.10.8.6',
      'Accept': 'application/json',
      'Origin': 'https://tieba.baidu.com',
      'Referer': 'https://tieba.baidu.com/',
    });
    const normalizedResponse: string = response.replace(/"non-gconforum"/g, '"non_gconforum"');
    const payload = JSON.parse(normalizedResponse) as ModernApiPayload;
    if (payload.error_code !== undefined && `${payload.error_code}` !== '0') {
      throw new Error(payload.error_msg ?? `贴吧接口错误 ${payload.error_code}`);
    }
    return payload;
  }

  private readRequestValue(formData: ModernRequestForm, key: string): string | undefined {
    if (key === '_client_type') return formData._client_type;
    if (key === '_client_version') return formData._client_version;
    if (key === '_os_version') return formData._os_version;
    if (key === 'client_type') return formData.client_type;
    if (key === 'friend_uid') return formData.friend_uid;
    if (key === 'is_guest') return formData.is_guest;
    if (key === 'kw') return formData.kw;
    if (key === 'thread_id') return formData.thread_id;
    if (key === 'post_id') return formData.post_id;
    if (key === 'kz') return formData.kz;
    if (key === 'load_type') return formData.load_type;
    if (key === 'need_forumlist') return formData.need_forumlist;
    if (key === 'need_tags') return formData.need_tags;
    if (key === 'new_install') return formData.new_install;
    if (key === 'new_net_type') return formData.new_net_type;
    if (key === 'page_no') return formData.page_no;
    if (key === 'page_size') return formData.page_size;
    if (key === 'page_thread_count') return formData.page_thread_count;
    if (key === 'pn') return formData.pn;
    if (key === 'q_type') return formData.q_type;
    if (key === 'request_time') return formData.request_time;
    if (key === 'rn') return formData.rn;
    if (key === 'scr_dip') return formData.scr_dip;
    if (key === 'scr_h') return formData.scr_h;
    if (key === 'scr_w') return formData.scr_w;
    if (key === 'sort_type') return formData.sort_type;
    if (key === 'st_type') return formData.st_type;
    if (key === 'uid') return formData.uid;
    if (key === 'with_group') return formData.with_group;
    if (key === 'is_good') return formData.is_good;
    if (key === 'lz') return formData.lz;
    if (key === 'r') return formData.r;
    if (key === 'back') return formData.back;
    if (key === 'floor_rn') return formData.floor_rn;
    if (key === 'floor_sort_type') return formData.floor_sort_type;
    if (key === 'comment_rn') return formData.comment_rn;
    if (key === 'mark') return formData.mark;
    if (key === 'with_floor') return formData.with_floor;
    return undefined;
  }

  private parseModernThreads(payload: ModernApiPayload, page: number, defaultForumName: string = ''): PagedResult<ThreadItem> {
    const source: ModernThreadRecord[] = payload.thread_list ?? [];
    const threadRecords: ModernThreadRecord[] = source;
    // 建立 user_list 索引（JSON 接口的 user_list 带 name_show 昵称，比 thread 内嵌 author 更完整）
    const userList: ModernAuthorRecord[] = payload.user_list ?? [];
    const userById: Map<string, ModernAuthorRecord> = new Map<string, ModernAuthorRecord>();
    for (const u of userList) {
      const uid: string = `${u.id ?? u.uid ?? ''}`.trim();
      if (uid.length > 0 && !userById.has(uid)) {
        userById.set(uid, u);
      }
    }
    const list: ThreadItem[] = [];
    for (const item of threadRecords) {
      const tid: string = `${item.tid ?? item.thread_id ?? item.threadId ?? item.id ?? ''}`.trim();
      if (tid.length === 0) {
        continue;
      }
      // 优先用 user_list 匹配的作者（含 name_show 昵称），匹配不到回退 thread 内嵌 author
      // JSON 接口的 thread 顶层 author_id 才是作者 id（author 内嵌对象可能为空），需兼容
      // 不同接口的 id 字段名不同（author_id / user_id / authorId / uid），全部尝试避免匹配失败
      const itemAuthorId: string = `${item.author?.id ?? item.author?.uid ?? item.author_id ?? item.user_id ?? item.authorId ?? ''}`.trim();
      const matchedUser: ModernAuthorRecord | undefined = itemAuthorId.length > 0 ? userById.get(itemAuthorId) : undefined;
      let authorRecord: ModernAuthorRecord | undefined = matchedUser ?? item.author;
      if (authorRecord === undefined || authorRecord === null) {
        // user_list 未匹配且 thread 内嵌 author 缺失：用 id 兜底，避免显示成“贴吧用户”
        authorRecord = { id: itemAuthorId.length > 0 ? itemAuthorId : undefined };
      }
      const shownAuthor: string = this.displayAuthor(authorRecord);
      let finalAuthor: string = shownAuthor;
      // 接口 name_show 为占位/缺失（如“贴吧用户_xxx”）时，displayAuthor 会回退显示用户名，
      // 但该用户名并非用户设置的昵称——标记该条目，enrich 阶段用 profile 实时昵称校准，
      // 否则首页会显示“用户名”而详情页显示“昵称”，两者不一致。
      const rawShowName: string = `${authorRecord?.name_show ?? authorRecord?.nameShow ?? authorRecord?.user_nickname ?? authorRecord?.userNickname ?? ''}`.trim();
      const nameShowMissing: boolean = rawShowName.length === 0 || rawShowName.startsWith('贴吧用户_') || rawShowName.startsWith('吧友');
      // 推荐页 JSON 昵称可能过期/缺失（吧友XXXX/贴吧用户_xxx/旧缓存昵称）：
      // 详情页 proto 实时昵称回填的缓存是金标准，有值即优先采用（与详情页显示完全一致）
      if (itemAuthorId.length > 0) {
        const cachedName: string | undefined = this.authorNickCache.get(itemAuthorId);
        if (cachedName !== undefined && cachedName.length > 0 && cachedName !== shownAuthor) {
          finalAuthor = cachedName;
        }
      }
      if (list.length < 8) {
        console.info(`[AUTHORDIAG] item: tid=${tid} authorId=${itemAuthorId || '(空)'} matched=${matchedUser ? `${matchedUser.name_show ?? matchedUser.nameShow ?? '(无名)'}/${matchedUser.name ?? ''}` : '未匹配'} -> 显示[${finalAuthor}]`);
      }
      const firstMedia: ModernMediaRecord | undefined = item.media !== undefined && item.media.length > 0 ? item.media[0] : undefined;
      const media: string = firstMedia?.pic ?? firstMedia?.src_pic ?? firstMedia?.big_pic ?? firstMedia?.origin_pic ?? '';
      const images: string[] = (item.media ?? [])
        .map((m: ModernMediaRecord) => m.pic ?? m.src_pic ?? m.big_pic ?? m.origin_pic ?? '')
        .filter((url: string) => url.length > 0);
      let abstractText: string = '';
      if (typeof item.abstract === 'string') {
        abstractText = item.abstract;
      } else if (item.abstract !== undefined && item.abstract.length > 0) {
        abstractText = item.abstract[0].text ?? '';
      }
      list.push({
        tid,
        postId: `${item.post_id ?? item.id ?? ''}`,
        title: item.title ?? tid,
        forumId: `${item.fid ?? item.forum_id ?? item.forum_info?.id ?? ''}`,
        forumName: item.fname ?? item.forum_name ?? item.forum_info?.name ?? defaultForumName,
        forumAvatar: item.forum_info?.avatar ?? '',
        author: finalAuthor,
        authorId: itemAuthorId,
        authorAvatar: this.normalizeAvatar(authorRecord),
        authorNameShowMissing: nameShowMissing,
        replyNum: Number(item.reply_num ?? 0) || 0,
        likeCount: Number(item.agree?.agreeNum ?? item.agree?.agree_num ?? 0),
        isLiked: Number(item.agree?.hasAgree ?? item.agree?.has_agree ?? 0) === 1 || Number(item.agree?.agreeType ?? item.agree?.agree_type ?? 0) > 0,
        abstract: abstractText,
        firstImage: media,
        images: images,
        createTime: item.last_time ?? '',
        isTop: `${item.is_top ?? ''}` === '1',
        isGood: `${item.is_good ?? item.isGood ?? ''}` === '1',
        isFeatured: `${item.is_good ?? item.isGood ?? ''}` === '1',
      });
    }
    return { list, hasMore: `${payload.has_more ?? ''}` === '1' || list.length >= 15, page };
  }

  private normalizeForumAvatar(raw: string): string {
    if (!raw || raw.length === 0 || raw === 'null' || raw === 'undefined') {
      return '';
    }
    const cleaned = decodeHtmlEntities(raw).trim().replace(/^['"]|['"]$/g, '');
    if (cleaned.length === 0) {
      return '';
    }
    // Full URL or protocol-relative: keep as-is
    if (cleaned.startsWith('http://') || cleaned.startsWith('https://')) {
      return cleaned.replace(/^http:\/\//, 'https://');
    }
    if (cleaned.startsWith('//')) {
      return `https:${cleaned}`;
    }
    // Absolute path: prepend Tieba base
    if (cleaned.startsWith('/')) {
      return `${TIEBA_BASE}${cleaned}`;
    }
    // Raw hash/ID — try Baidu portrait CDN (same pattern as user avatars)
    if (cleaned.length > 5) {
      const portraitHost: string = cleaned.startsWith('tb.') || cleaned.includes('portraith')
        ? 'https://himg.bdimg.com/sys/portraith/item/'
        : 'https://tb.himg.baidu.com/sys/portrait/item/';
      return `${portraitHost}${cleaned}`;
    }
    return '';
  }

  private parseModernFollowList(payload: ModernApiPayload, page: number): PagedResult<FollowItem> {
    const forumGroups: ModernForumRecord[] = [];
    const first: ModernForumRecord[] = payload.forum_list?.non_gconforum ?? [];
    const second: ModernForumRecord[] = payload.common_forum_list?.non_gconforum ?? [];
    forumGroups.push(...first, ...second);
    const seen: Set<string> = new Set<string>();
    const list: FollowItem[] = [];
    for (const forum of forumGroups) {
      const name = forum.name ?? '';
      if (name.length === 0 || seen.has(name)) {
        continue;
      }
      seen.add(name);
      const rawAvatar: string = (forum.avatar ?? forum.forum_avatar ?? forum.head_url ?? forum.headPic ?? forum.pic ?? forum.head_pic ?? forum.img ?? '').toString();
      const avatar: string = this.normalizeForumAvatar(rawAvatar);
      const rawHot: string = (forum.hot_num ?? forum.hotValue ?? forum.member_num ?? '').toString();
      const hotValue: string = rawHot.length > 0 ? rawHot : forum.level_name ?? '';
      const rawSign: string = (forum.is_sign ?? forum.isSign ?? forum.is_signed ?? forum.signed ?? forum.sign_status ?? forum.has_signed ?? '0').toString();
      list.push({
        forumId: forum.id ?? '',
        forumName: name,
        level: parseInt(forum.level_id ?? forum.vip_level_id ?? '0', 10) || 0,
        exp: 0,
        isSign: rawSign === '1' || rawSign === 'true',
        memberCount: forum.level_name ?? '',
        avatar: avatar,
        hotValue: hotValue,
      });
    }
    return { list, hasMore: `${payload.has_more ?? ''}` === '1', page };
  }

  /**
   * 关注/取消关注贴吧（客户端 c/c/forum 接口）。
   * 已对照 tieba.js v3：
   *   关注 POST https://tiebac.baidu.com/c/c/forum/like
   *   取关 POST https://tiebac.baidu.com/c/c/forum/unfavolike
   * 参数：BDUSS + tbs + fid + _client_version + sign（tiebaclient!!! 小写 MD5）。
   */
  async toggleFollow(forumName: string, follow: boolean, forumId?: string): Promise<boolean> {
    const fid = (forumId ?? '').trim();
    if (fid.length === 0) {
      throw new Error('缺少贴吧 ID，无法关注/取消关注');
    }
    if (!AuthManager.getInstance().isLogin()) {
      throw new Error('请先登录后再操作');
    }
    const form: Record<string, string> = {
      'BDUSS': AuthManager.getInstance().getBduss(),
      'tbs': await this.fetchTbs(),
      'fid': fid,
      '_client_version': '12.57.4.2',
    };
    form['sign'] = await this.signTiebaForm(form);
    const url = follow
      ? 'https://tiebac.baidu.com/c/c/forum/like'
      : 'https://tiebac.baidu.com/c/c/forum/unfavolike';
    try {
      const resp = await HttpClient.postForm(url, form, {
        'Accept': 'application/json, text/plain, */*',
        'User-Agent': 'tieba/12.57.4.2',
        'Referer': `${TIEBA_BASE}/f?kw=${encodeURIComponent(forumName)}`,
      });
      const parsed: Record<string, Object> = JSON.parse(resp) as Record<string, Object>;
      const errCode: string = `${parsed.error_code ?? '0'}`;
      if (errCode !== '0' && errCode !== '') {
        const emsg: string = `${parsed.error_msg ?? parsed.error ?? '未知错误'}`;
        throw new Error(`${follow ? '关注' : '取消关注'}失败：${emsg}（${errCode}）`);
      }
      return true;
    } catch (e) {
      const errMsg: string = e instanceof Error ? e.message : `${e}`;
      if (errMsg.startsWith('关注失败') || errMsg.startsWith('取消关注失败') || errMsg.startsWith('缺少贴吧 ID') || errMsg.startsWith('请先登录')) {
        throw e instanceof Error ? e : new Error(errMsg);
      }
      throw new Error(`${follow ? '关注' : '取消关注'}失败：${errMsg}`);
    }
  }

  // ===== 黑名单（批 A 抓包定接口；以下为真实接通实现）=====
//
// 接口文档（aiotieba/tbclient.protobuf 对照定案）：
//   列表：POST tiebac.baidu.com/c/u/user/userMuteQuery?cmd=303028  protobuf
//         Req:  data(1){ common(2), pn(4), rn(5) }
//         Resp: data(1){ mute_user[1]{ user_id, user_name, mute_time, portrait, name_show }, page(2) },
//               error(2){ errorno(1), errmsg(2) }
//   拉黑：POST tiebac.baidu.com/c/c/user/userMuteAdd   JSON form { BDUSS, mute_user(uid) }
//   取黑：POST tiebac.baidu.com/c/c/user/userMuteDel   JSON form { BDUSS, mute_user(uid) }
// mute_time 语义为「解禁时间戳（秒）」；0 表示永久屏蔽。blackTime 字段复用此值（无拉黑时间），
// 副行展示文案据此调整为「解禁于 XXX / 永久屏蔽」。

  /**
   * 拉取黑名单列表（分页）。
   * 走 protobuf 通道；mute_time→blackTime（解禁时间，秒）；name_show 优先，user_name 兜底。
   */
  async fetchBlacklist(page: number, pageSize: number = 20): Promise<PagedResult<BlacklistItem>> {
    if (!AuthManager.getInstance().isLogin()) {
      throw new Error('请先登录后查看黑名单');
    }
    // 优先新版 userBlackPage（JSON form，带 perm 三开关，官方 App 回显数据源）；
    // 失败自动回退老 userMuteQuery（protobuf，无 perm，弹窗开关走本地记忆/默认全开）。
    if (page === 0) {
      try {
        const items = await this.fetchUserBlackPageItems();
        console.info(`[BLACKLIST] userBlackPage items=${items.length}`);
        return { list: items, hasMore: false, page: 0 };
      } catch (e) {
        console.warn(`[BLACKLIST] userBlackPage 失败，回退 userMuteQuery: ${(e as Error).message}`);
      }
    }
    try {
      const common = ProtoSchema.commonRequest(new Map<string, string | number>([
        ['_client_type', 2], ['_client_version', '12.57.4.2'], ['_os_version', '26'],
        ['model', 'HarmonyOS'], ['brand', 'Huawei'], ['net_type', 1], ['scr_w', 360],
        ['scr_h', 800], ['scr_dip', 1], ['pversion', '1.0.3'], ['BDUSS', AuthManager.getInstance().getBduss()]
      ]));
      const request = ProtoSchema.userMuteQueryRequest(page + 1, pageSize, common);
      const binary = await HttpClient.postProtoMultipart(`${API.BLACKLIST}`, request, {
        'User-Agent': 'tieba/12.57.4.2',
        'Accept': 'application/octet-stream',
        'X-BD-DATA-TYPE': 'protobuf',
        'Client-Type': '2',
        'Charset': 'UTF-8',
        'Referer': 'https://tieba.baidu.com/',
      });
      const decoded = TiebaProtoDecoder.decodeUserMuteQueryResponse(binary);
      if (decoded.errorCode !== 0 && decoded.errorCode !== undefined) {
        throw new Error(decoded.errorMsg || `黑名单接口错误 ${decoded.errorCode}`);
      }
      const list: BlacklistItem[] = [];
      for (const mu of decoded.list) {
        // 昵称：name_show 优先（占位「贴吧用户_xxx」「吧友_xxx」回退 user_name）
        const rawNameShow: string = (mu.nameShow ?? '').trim();
        const rawUserName: string = (mu.userName ?? '').trim();
        const isPlaceholderName = (s: string): boolean =>
          s.length === 0 || s === '贴吧用户'
            || s.startsWith('贴吧用户_') || s.startsWith('吧友');
        const name: string = !isPlaceholderName(rawNameShow) ? rawNameShow
          : (rawUserName.length > 0 ? rawUserName : '贴吧用户');
        const muteT: number = mu.muteTime ?? 0;
        const ts: number = muteT > 0 && muteT < 100000000000 ? muteT * 1000 : muteT;
        const item: BlacklistItem = {
          userId: mu.userId ?? '',
          name,
          avatar: this.normalizePortraitAvatar(mu.portrait ?? ''),
          blackTime: ts,
        };
        if (item.userId.length > 0 || item.name.length > 0) {
          list.push(item);
        }
      }
      const hasMore: boolean = decoded.hasMore || list.length >= pageSize;
      return { list, hasMore, page };
    } catch (e) {
      throw new Error((e as Error).message ?? '拉取黑名单失败');
    }
  }

  /**
   * 新版黑名单列表查询（userBlackPage，JSON form）。
   * 2026-09-01 定案（aiotieba get_blacklist 对照）：POST tiebac.baidu.com/c/u/user/userBlackPage，
   * 参数 BDUSS + _client_version + sign；响应 data.user_perm_list[]，每项：
   *   user_id / portrait / user_name / nick_name_new / perm_list{ follow, interact, chat }（"0"/"1"）。
   * 该接口是官方 App 三开关回显的数据来源；无分页参数，一次返回全部。
   */
  private async fetchUserBlackPageItems(): Promise<BlacklistItem[]> {
    const form: Record<string, string> = {
      'BDUSS': AuthManager.getInstance().getBduss(),
      '_client_version': '12.57.4.2',
    };
    form['sign'] = await this.signTiebaForm(form);
    hilog.info(0x0000, 'BLACKLIST', 'userBlackPage req url=%{public}s bdussLen=%{public}d signLen=%{public}d',
      `${API.BLACKLIST_PAGE}`, form['BDUSS'].length, form['sign'].length);
    const resp: string = await HttpClient.postForm(`${API.BLACKLIST_PAGE}`, form, {
      'User-Agent': 'tieba/12.57.4.2',
      'Accept': 'application/json, text/plain, */*',
      'Referer': 'https://tieba.baidu.com/',
    });
    hilog.info(0x0000, 'BLACKLIST', 'userBlackPage resp len=%{public}d head=%{public}s',
      resp.length,
      resp.substring(0, Math.min(500, resp.length)));
    const parsed: Record<string, Object> = JSON.parse(resp) as Record<string, Object>;
    const errCode: string = `${parsed.error_code ?? parsed.errorCode ?? '0'}`;
    const errMsg: string = `${parsed.error_msg ?? parsed.errmsg ?? ''}`;
    hilog.error(0x0000, 'BLACKLIST', 'userBlackPage parsed error_code=%{public}s error_msg=%{public}s topKeys=%{public}s',
      errCode, errMsg, JSON.stringify(Object.keys(parsed)));
    if (errCode !== '0' && errCode !== '' && errCode !== 'undefined') {
      throw new Error(this.extractErrMsg(resp) || `黑名单接口错误 ${errCode}`);
    }
    // 注意：userBlackPage 的 user_perm_list 位于响应顶层（非 data 下），字段为 uid/name_show
    const rawList: Object[] = (parsed.user_perm_list ?? []) as Object[];
    hilog.info(0x0000, 'BLACKLIST', 'userBlackPage user_perm_list len=%{public}d',
      rawList.length);
    if (rawList.length > 0) {
      const first: Record<string, Object> = rawList[0] as Record<string, Object>;
      hilog.error(0x0000, 'BLACKLIST', 'userBlackPage first keys=%{public}s sample=%{public}s',
        JSON.stringify(Object.keys(first)),
        JSON.stringify(first).substring(0, Math.min(400, JSON.stringify(first).length)));
    }
    const list: BlacklistItem[] = [];
    for (const raw of rawList) {
      const r: Record<string, Object> = raw as Record<string, Object>;
      const userId: string = `${r.uid ?? r.user_id ?? ''}`.trim();
      const permList: Record<string, Object> = (r.perm_list ?? {}) as Record<string, Object>;
      const follow: boolean = `${permList.follow ?? '0'}` === '1';
      const interact: boolean = `${permList.interact ?? '0'}` === '1';
      const chat: boolean = `${permList.chat ?? '0'}` === '1';
      const rawNick: string = `${r.name_show ?? r.nick_name_new ?? ''}`.trim();
      const rawName: string = `${r.user_name ?? ''}`.trim();
      const isPlaceholderName = (s: string): boolean =>
        s.length === 0 || s === '贴吧用户'
          || s.startsWith('贴吧用户_') || s.startsWith('吧友');
      const name: string = !isPlaceholderName(rawNick) ? rawNick
        : (rawName.length > 0 ? rawName : '贴吧用户');
      list.push({
        userId,
        name,
        avatar: this.normalizePortraitAvatar(`${r.portrait ?? ''}`),
        blackTime: 0,
        blockFollow: follow,
        blockInteract: interact,
        blockChat: chat,
      });
    }
    return list;
  }

  /**
   * 拉黑用户（写入操作）。
   * JSON form：BDUSS + mute_user(uid)；返回 JSON { error_code, error_msg, errorno, errmsg }。
   */
  /**
   * 拉黑用户（新版 SetUserBlack 接口，支持三个精细化开关）。
   * 默认三项全开，对齐官方 App 拉黑行为；可通过 opts 单独控制 私信/关注/互动。
   */
  async blockUser(userId: string, userName: string, opts?: BlacklistPermOptions): Promise<boolean> {
    if (userId.length === 0) {
      throw new Error('缺少用户 ID，无法拉黑');
    }
    const follow: number = (opts?.follow ?? true) ? 1 : 2;
    const interact: number = (opts?.interact ?? true) ? 1 : 2;
    const chat: number = (opts?.chat ?? true) ? 1 : 2;
    return this.setUserBlack(userId, follow, interact, chat, '拉黑');
  }

  /**
   * 取消拉黑 = 三个开关全部关闭。
   */
  async unblockUser(userId: string): Promise<boolean> {
    if (userId.length === 0) {
      throw new Error('缺少用户 ID，无法取消拉黑');
    }
    return this.setUserBlack(userId, 2, 2, 2, '取消拉黑');
  }

  /**
   * 新版设置黑名单写操作（SetUserBlack，Cmd 309697，protobuf 通道）。
   * perm 取值：1=开启屏蔽，2=不屏蔽（服务端约定，见 aiotieba set_blacklist）。
   * 老 userMuteAdd/userMuteDel 已被服务端标记为高级会员权限（1990043），普通账号不可用。
   */
  private async setUserBlack(userId: string, follow: number, interact: number, chat: number, action: string): Promise<boolean> {
    const common = ProtoSchema.commonRequest(new Map<string, string | number>([
      ['_client_type', 2], ['_client_version', '12.57.4.2'], ['_os_version', '26'],
      ['model', 'HarmonyOS'], ['brand', 'Huawei'], ['net_type', 1], ['scr_w', 360],
      ['scr_h', 800], ['scr_dip', 1], ['pversion', '1.0.3'], ['BDUSS', AuthManager.getInstance().getBduss()]
    ]));
    const request = ProtoSchema.setUserBlackRequest(userId, follow, interact, chat, common);
    try {
      const binary = await HttpClient.postProtoMultipart(`${API.BLACKLIST_SET_USER}`, request, {
        'User-Agent': 'tieba/12.57.4.2',
        'Accept': 'application/octet-stream',
        'X-BD-DATA-TYPE': 'protobuf',
        'Client-Type': '2',
        'Charset': 'UTF-8',
        'Referer': 'https://tieba.baidu.com/',
      });
      // 诊断日志（临时）：打印响应字节数与解码结果，用于确认 SetUserBlack 协议实测
      console.info(`[BLACKLIST] ${action} uid=${userId} perm=[${follow},${interact},${chat}] bytes=${binary.byteLength}`);
      const decoded = TiebaProtoDecoder.decodeSetUserBlackResponse(binary);
      console.info(`[BLACKLIST] ${action} code=${decoded.errorCode} msg=${decoded.errorMsg}`);
      if (decoded.errorCode !== 0 && decoded.errorCode !== undefined) {
        throw new Error(`${decoded.errorMsg || `${action}失败`}（${decoded.errorCode}）`);
      }
      return true;
    } catch (e) {
      const errMsg: string = e instanceof Error ? e.message : `${e}`;
      if (errMsg.startsWith('缺少')) {
        throw new Error(errMsg);
      }
      throw new Error(errMsg.includes('（') ? errMsg : `${action}失败，请稍后重试`);
    }
  }

  /**
   * 发布主题：模拟网页端 /f/commit/thread/add。
   * 只允许单次、用户主动提交；验证码和风控由贴吧服务端处理。
   */
  async publishThread(forumName: string, title: string, content: string, forumId: string = ''): Promise<PublishResult> {
    this.assertWriteReady(forumName, title, content);
    const fid = await this.resolveForumId(forumName, forumId);
    const form: WebWriteForm = {
      ie: 'utf-8',
      kw: forumName,
      fid,
      tid: '',
      vcode_md5: '',
      title: title.trim(),
      content: content.trim(),
      rich_text: '1',
      anonymous: '0',
      __type__: 'thread',
      tbs: await this.fetchTbs(),
    };
    return this.submitWrite(`${TIEBA_BASE}/f/commit/thread/add`, form, '发帖');
  }

  /**
   * 回复主题：模拟网页端 /f/commit/post/add。
   */
  async publishReply(forumName: string, tid: string, content: string, forumId: string = '', floorNum: string = ''): Promise<PublishResult> {
    this.assertWriteReady(forumName, '', content);
    if (tid.trim().length === 0) {
      throw new Error('缺少帖子 ID，无法回帖');
    }
    const fid = await this.resolveForumId(forumName, forumId);
    const form: WebWriteForm = {
      ie: 'utf-8',
      kw: forumName,
      fid,
      tid: tid.trim(),
      content: content.trim(),
      rich_text: '1',
      anonymous: '0',
      tbs: await this.fetchTbs(),
    };
    if (floorNum.trim().length > 0) {
      form.floor_num = floorNum.trim();
    }
    return this.submitWrite(`${TIEBA_BASE}/f/commit/post/add`, form, '回帖');
  }

  private assertWriteReady(forumName: string, title: string, content: string): void {
    if (!AuthManager.getInstance().isLogin()) {
      throw new Error('请先登录贴吧账号');
    }
    if (forumName.trim().length === 0) {
      throw new Error('缺少贴吧名称');
    }
    if (title.trim().length > 100) {
      throw new Error('标题过长，请控制在 100 字以内');
    }
    if (content.trim().length === 0) {
      throw new Error('内容不能为空');
    }
    if (content.trim().length > 10000) {
      throw new Error('内容过长，请控制在 10000 字以内');
    }
  }

  private async submitWrite(url: string, form: WebWriteForm, actionName: string): Promise<PublishResult> {
    const response = await HttpClient.postEncoded(url, this.encodeWriteForm(form), {
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      'Accept': 'application/json, text/plain, */*',
      'Origin': TIEBA_BASE,
      'Referer': `${TIEBA_BASE}/`,
      'X-Requested-With': 'XMLHttpRequest',
    });
    let payload: Record<string, Object>;
    try {
      payload = JSON.parse(response) as Record<string, Object>;
    } catch (e) {
      throw new Error(`${actionName}响应格式异常，可能触发了验证码或贴吧风控`);
    }
    const code = this.readNumber(payload, ['no', 'err_code', 'errno', 'error_code']);
    const message = this.readString(payload, ['error', 'errmsg', 'error_msg', 'message']);
    if (code !== 0) {
      throw new Error(message.length > 0 ? message : `${actionName}失败，请稍后重试`);
    }
    const tid = this.readString(payload, ['tid', 'thread_id']);
    return {
      success: true,
      message: message.length > 0 ? message : `${actionName}成功`,
      tid: tid.length > 0 ? tid : undefined,
    };
  }

  private encodeWriteForm(form: WebWriteForm): string {
    const pairs: string[] = [];
    this.appendWritePair(pairs, 'ie', form.ie);
    this.appendWritePair(pairs, 'kw', form.kw);
    this.appendWritePair(pairs, 'fid', form.fid);
    this.appendWritePair(pairs, 'tid', form.tid);
    this.appendWritePair(pairs, 'vcode_md5', form.vcode_md5);
    this.appendWritePair(pairs, 'title', form.title);
    this.appendWritePair(pairs, 'content', form.content);
    this.appendWritePair(pairs, 'rich_text', form.rich_text);
    this.appendWritePair(pairs, 'anonymous', form.anonymous);
    this.appendWritePair(pairs, '__type__', form.__type__);
    this.appendWritePair(pairs, 'tbs', form.tbs);
    this.appendWritePair(pairs, 'floor_num', form.floor_num);
    return pairs.join('&');
  }

  private appendWritePair(pairs: string[], key: string, value: string | undefined): void {
    if (value !== undefined) {
      pairs.push(`${encodeURIComponent(key)}=${encodeURIComponent(value)}`);
    }
  }

  private readString(payload: Record<string, Object>, keys: string[]): string {
    for (const key of keys) {
      const value = payload[key];
      if (typeof value === 'string' || typeof value === 'number') {
        return `${value}`;
      }
    }
    return '';
  }

  private readNumber(payload: Record<string, Object>, keys: string[]): number {
    for (const key of keys) {
      const value = payload[key];
      if (typeof value === 'number') {
        return value;
      }
      if (typeof value === 'string' && value.trim().length > 0) {
        const parsed = Number(value);
        if (!isNaN(parsed)) {
          return parsed;
        }
      }
    }
    return 0;
  }

  async resolveForumId(forumName: string, fallback: string): Promise<string> {
    if (fallback.trim().length > 0) {
      return fallback.trim();
    }
    const url = `${TIEBA_BASE}/f/commit/share/fnameShareApi?ie=utf-8&fname=${encodeURIComponent(forumName)}`;
    const response = await HttpClient.get(url, {
      'Accept': 'application/json, text/plain, */*',
      'Referer': `${TIEBA_BASE}/f?kw=${encodeURIComponent(forumName)}`,
    });
    try {
      const payload = JSON.parse(response) as Record<string, Object>;
      const fid = this.readString(payload, ['fid', 'forum_id']);
      if (fid.length > 0) {
        return fid;
      }
      const data = payload.data;
      if (data !== null && typeof data === 'object') {
        const nestedFid = this.readString(data as Record<string, Object>, ['fid', 'forum_id']);
        if (nestedFid.length > 0) {
          return nestedFid;
        }
      }
    } catch (e) {
      const htmlFid = extractGroup(response, /name=["']fid["'][^>]*value=["'](\d+)["']/i);
      if (htmlFid.length > 0) {
        return htmlFid;
      }
    }
    throw new Error('无法获取贴吧 fid，请重新打开贴吧后重试');
  }

  /**
   * 获取会话列表（私信）
   */
  async fetchConversations(): Promise<Conversation[]> {
    const html = await HttpClient.get(API.MESSAGE);
    return this.parseConversations(html);
  }

  /**
   * 获取「回复我的」消息列表
   */
  async fetchReplyMe(page: number = 1): Promise<PagedResult<NotifyMessage>> {
    return this.fetchNotifyList('replyme', page);
  }

  /**
   * 获取「提到我的」消息列表
   */
  async fetchAtMe(page: number = 1): Promise<PagedResult<NotifyMessage>> {
    return this.fetchNotifyList('atme', page);
  }

  /**
   * 「我的点赞」云端列表（2026-09-10 从官方 App 实抓：H5 /mo/q/hybrid-main-usercenter/myLike 背后的数据接口）
   * 接口：POST https://tiebac.baidu.com/c/u/feed/userAgree
   * 表单：BDUSS + 客户端公共参数 + tab_id(0=主贴 1=回贴) + pn(1 基页码) + rn + sign（同 replyme 写法，无需 tbs）
   * 响应：{ error_code, data: { thread_list: [...], has_more: 1|0 } }
   * 列表项：tid / title / fname / reply_num / last_time / abstract[{type,text}] / author{id,name_show}
   */
  async fetchUserAgreeThreads(page: number = 1, pageSize: number = 20, tabId: number = 0): Promise<PagedResult<PersonalContentItem>> {
    const bduss: string = AuthManager.getInstance().getBduss();
    if (bduss.length === 0) {
      throw new Error('请先登录后再查看点赞');
    }
    const userId: string = AuthManager.getInstance().getUser()?.userId ?? '';
    const cuid: string = await this.resolveClientCuid();
    const form: Record<string, string> = {};
    form.BDUSS = bduss;
    form._client_type = '2';
    form._client_version = '12.41.7.1';
    form.cuid = cuid;
    form.cuid_galaxy2 = cuid;
    form.cuid_gid = '';
    form.from = 'tieba';
    form.timestamp = TiebaService.clientTimestampSec();
    form.model = 'HarmonyOS';
    form.net_type = '1';
    form.tab_id = `${Math.max(0, tabId)}`;
    form.pn = `${Math.max(1, page)}`;
    form.rn = `${Math.max(1, pageSize)}`;
    form.sign = await this.signTiebaForm(form);
    const resp: string = await HttpClient.postForm('https://tiebac.baidu.com/c/u/feed/userAgree', form,
      this.buildClientApiHeaders(cuid, userId));
    return this.parseUserAgreeList(resp, userId, page);
  }

  /**
   * 解析「我的点赞」列表 JSON
   */
  private parseUserAgreeList(resp: string, userId: string, page: number): PagedResult<PersonalContentItem> {
    const trimmed: string = resp.trim();
    if (trimmed.startsWith('<')) {
      throw new Error('点赞接口返回了网页内容，登录态可能已失效，请重新登录');
    }
    let payload: Record<string, Object>;
    try {
      payload = JSON.parse(trimmed) as Record<string, Object>;
    } catch (e) {
      throw new Error('点赞接口返回格式异常，请稍后重试');
    }
    const errorCode: number = this.readNumber(payload, ['error_code', 'errorCode', 'errno', 'no']);
    if (errorCode !== 0) {
      const msg: string = this.readString(payload, ['error_msg', 'errorMsg', 'errmsg', 'error', 'message']);
      throw new Error(msg.length > 0 ? msg : '云端点赞加载失败');
    }
    const nested: Object | undefined = payload.data;
    const data: Record<string, Object> = nested !== undefined && typeof nested === 'object'
      ? nested as Record<string, Object>
      : payload;
    const list: PersonalContentItem[] = [];
    const rawList: Object[] = this.readObjectArray(data, ['thread_list', 'list']);
    for (const raw of rawList) {
      const record: Record<string, Object> = raw as Record<string, Object>;
      const authorValue: Object | undefined = record.author;
      const author: Record<string, Object> = authorValue !== undefined && typeof authorValue === 'object'
        ? authorValue as Record<string, Object>
        : {};
      const tid: string = this.readString(record, ['tid', 'thread_id', 'id']);
      if (tid.length === 0) {
        continue;
      }
      list.push({
        id: tid,
        tid,
        title: this.readString(record, ['title', 'thread_title']) || '未命名帖子',
        forumName: this.readString(record, ['fname', 'forum_name']) || '贴吧',
        author: this.readString(author, ['name_show', 'name', 'user_name']) || '贴吧用户',
        authorId: this.readString(author, ['id', 'user_id', 'uid']),
        abstract: this.joinAgreeAbstract(record),
        replyNum: this.readNumber(record, ['reply_num', 'count', 'reply_count']),
        createTime: this.readString(record, ['last_time', 'create_time']),
        accountId: userId,
      });
    }
    return {
      list,
      hasMore: this.readNumber(data, ['has_more', 'hasMore']) !== 0,
      page,
    };
  }

  /**
   * 拼接点赞项摘要：abstract 是内容段数组（type 0=文本、2=表情、3=图片），只取文本段；为空时回退 rich_abstract
   */
  private joinAgreeAbstract(record: Record<string, Object>): string {
    let parts: string[] = this.collectTextSegments(record, ['abstract']);
    if (parts.length === 0) {
      parts = this.collectTextSegments(record, ['rich_abstract']);
    }
    return parts.join(' ');
  }

  private collectTextSegments(record: Record<string, Object>, keys: string[]): string[] {
    const segments: Object[] = this.readObjectArray(record, keys);
    const parts: string[] = [];
    for (const segment of segments) {
      const text: string = this.readString(segment as Record<string, Object>, ['text']);
      if (text.length > 0) {
        parts.push(text);
      }
    }
    return parts;
  }

  /**
   * 通用消息通知列表（replyme / atme）
   */
  private async fetchNotifyList(type: 'replyme' | 'atme', page: number): Promise<PagedResult<NotifyMessage>> {
    const bduss: string = AuthManager.getInstance().getBduss();
    if (bduss.length === 0) {
      throw new Error('请先登录后再查看消息');
    }
    const cuid: string = await this.resolveClientCuid();
    const userId: string = AuthManager.getInstance().getUser()?.userId ?? '';
    const form: Record<string, string> = {};
    form.BDUSS = bduss;
    form._client_type = '2';
    form._client_version = '12.41.7.1';
    form.cuid = cuid;
    form.cuid_galaxy2 = cuid;
    form.cuid_gid = '';
    form.from = 'tieba';
    form.timestamp = TiebaService.clientTimestampSec();
    form.model = 'HarmonyOS';
    form.net_type = '1';
    // 该接口 pn 为 1 基页码（真机验证：pn=0 被 clamp 为第 1 页，pn=1 才返回第 1 页）。
    // 此前按 0 基发 pn=page-1 导致第 2 次触底重复取回第 1 页，后续内容一直不出现。
    form.pn = `${Math.max(1, page)}`;
    form.sign = await this.signTiebaForm(form);
    const url: string = type === 'replyme'
      ? 'https://c.tieba.baidu.com/c/u/feed/replyme'
      : 'https://c.tieba.baidu.com/c/u/feed/atme';
    hilog.info(0x0000, 'MSGPAGE', 'fetch type=%{public}s page=%{public}d pn=%{public}s',
      type, page, form.pn);
    const resp: string = await HttpClient.postForm(url, form, this.buildClientApiHeaders(cuid, userId));
    // 服务端 current_page 回显语义（0 基/1 基）不可靠：翻页序号由调用方以"请求页码自增"推进，
    // 这里把本次请求页码原样带回，供上层 next = page + 1 稳定翻页。
    const result: PagedResult<NotifyMessage> = this.parseNotifyList(resp, type === 'replyme' ? 'reply' : 'at');
    result.page = page;
    return result;
  }

  /**
   * 解析回复/@消息列表 JSON
   */
  private parseNotifyList(resp: string, type: 'reply' | 'at'): PagedResult<NotifyMessage> {
    const trimmed: string = resp.trim();
    if (trimmed.startsWith('<')) {
      throw new Error('消息接口返回了网页内容，登录态可能已失效');
    }
    let payload: Record<string, Object>;
    try {
      payload = JSON.parse(trimmed) as Record<string, Object>;
    } catch (e) {
      throw new Error('消息接口返回格式异常');
    }
    const errorCode: number = this.readNumber(payload, ['error_code', 'errorCode', 'errno', 'no']);
    if (errorCode !== 0) {
      const msg: string = this.readString(payload, ['error_msg', 'errorMsg', 'errmsg', 'error', 'message']);
      throw new Error(msg.length > 0 ? msg : '消息加载失败');
    }
    const data: Record<string, Object> = payload.data !== undefined && typeof payload.data === 'object'
      ? payload.data as Record<string, Object>
      : payload;
    const listKey: string[] = type === 'reply' ? ['reply_list', 'replyList'] : ['at_list', 'atList'];
    const rawList: Object[] = this.readObjectArray(data, listKey);
    const pageInfo: Record<string, Object> = (data.page !== undefined && typeof data.page === 'object'
      ? data.page as Record<string, Object>
      : {}) as Record<string, Object>;
    const list: NotifyMessage[] = [];
    for (let i = 0; i < rawList.length; i++) {
      const raw: Record<string, Object> = rawList[i] as Record<string, Object>;
      const replyerRaw: NotifyUser | undefined = this.parseNotifyUser(raw, 'replyer');
      const replyer: NotifyUser = replyerRaw ?? { id: '', name: '', nameShow: '', avatar: '' };
      const quoteUser: NotifyUser | undefined = type === 'reply'
        ? this.parseNotifyUser(raw, 'quote_user', true)
        : undefined;
      const threadId: string = this.readString(raw, ['thread_id', 'threadId']);
      const postId: string = this.readString(raw, ['post_id', 'postId']);
      // [MSGRAW] 消息跳转诊断：打印 replyme/atme 原始字段，用于确认楼中楼场景下
      // post_id(楼层?)/quote_pid(被引用)/spid 等 id 的真实语义（跳转定位是否可命中楼层）
      if (type === 'reply' || type === 'at') {
        const newFloorJson: string = raw.new_floor_info !== undefined && raw.new_floor_info !== null
          ? (JSON.stringify(raw.new_floor_info) ?? '') : '';
        hilog.info(0x0000, 'MSGRAW',
          'item#%{public}d type=%{public}s keys=%{public}s | thread_id=%{public}s post_id=%{public}s quote_pid=%{public}s is_floor=%{public}s ppid=%{public}s spid=%{public}s sub_post_id=%{public}s comment_id=%{public}s thread_type=%{public}s | fname=%{public}s time=%{public}s content=[%{public}s] quote=[%{public}s] replyerId=%{public}s new_floor=%{public}s',
          i, type, Object.keys(raw).join(','),
          threadId, postId,
          `${raw.quote_pid ?? ''}`, `${raw.is_floor ?? ''}`,
          `${raw.ppid ?? ''}`, `${raw.spid ?? ''}`, `${raw.sub_post_id ?? ''}`, `${raw.comment_id ?? ''}`,
          `${raw.thread_type ?? ''}`,
          `${raw.fname ?? ''}`, `${raw.time ?? ''}`,
          `${raw.content ?? ''}`.slice(0, 80), `${raw.quote_content ?? ''}`.slice(0, 80),
          `${(raw.replyer as Record<string, Object>)?.id ?? ''}`, newFloorJson.slice(0, 220));
      }
      if (threadId.length === 0 || postId.length === 0) {
        continue;
      }
      const item: NotifyMessage = {
        id: `${type}_${postId}_${i}`,
        type,
        title: stripHtml(`${raw.title ?? ''}`),
        content: stripHtml(`${raw.content ?? ''}`),
        quoteContent: stripHtml(`${raw.quote_content ?? raw.quoteContent ?? ''}`),
        time: `${raw.time ?? ''}`,
        threadId,
        postId,
        quotePid: this.readString(raw, ['quote_pid', 'quotePid']),
        forumName: this.readString(raw, ['fname', 'forumName']),
        isFloor: this.readBooleanLike(raw, ['is_floor', 'isFloor']),
        unread: this.readBooleanLike(raw, ['unread']),
        replyer,
        quoteUser,
      };
      list.push(item);
    }
    // 分页诊断：确认 has_more 出现位置与取值形态、每页原始条数、本页首尾 id（翻页是否重复同页）
    let hmAt: string = 'none';
    if (pageInfo['has_more'] !== undefined || pageInfo['hasMore'] !== undefined) {
      hmAt = 'page';
    } else if (data['has_more'] !== undefined || data['hasMore'] !== undefined) {
      hmAt = 'data';
    }
    const firstRaw: Record<string, Object> = rawList.length > 0 ? rawList[0] as Record<string, Object> : {};
    const lastRaw: Record<string, Object> = rawList.length > 0 ? rawList[rawList.length - 1] as Record<string, Object> : {};
    hilog.info(0x0000, 'MSGPAGE',
      'parse type=%{public}s raw=%{public}d kept=%{public}d hmAt=%{public}s pageInfo=%{public}s dataHasMore=%{public}s firstThread=%{public}s firstPost=%{public}s lastThread=%{public}s lastPost=%{public}s topKeys=%{public}s',
      type, rawList.length, list.length, hmAt,
      JSON.stringify(pageInfo).slice(0, 400), `${data.has_more ?? data.hasMore ?? ''}`,
      `${firstRaw.thread_id ?? firstRaw.threadId ?? ''}`, `${firstRaw.post_id ?? firstRaw.postId ?? ''}`,
      `${lastRaw.thread_id ?? lastRaw.threadId ?? ''}`, `${lastRaw.post_id ?? lastRaw.postId ?? ''}`,
      Object.keys(payload).join(','));
    // has_more 兼容 page 内/顶层、字符串("1"/"true")/数字(1/0)/布尔三种形态；字段完全缺失才退化为整页启发式
    let hm: Object | undefined = this.readFirst(pageInfo, ['has_more', 'hasMore']);
    if (hm === undefined) {
      hm = this.readFirst(data, ['has_more', 'hasMore']);
    }
    let hasMore: boolean;
    if (hm === undefined || hm === null) {
      hasMore = rawList.length >= 20;
    } else {
      const hs: string = `${hm}`.trim().toLowerCase();
      hasMore = hs === '1' || hs === 'true' || hs === 'yes';
    }
    return {
      list,
      hasMore,
      // current_page 回显语义不可靠，页码由调用方以请求页自增推进（fetchNotifyList 已覆盖为请求页码）
      page: this.readNumber(pageInfo, ['current_page', 'currentPage']),
    };
  }

  /**
   * 解析消息中的用户信息
   */
  private parseNotifyUser(raw: Record<string, Object>, key: string, optional: boolean = false): NotifyUser | undefined {
    const obj: Object | undefined = raw[key];
    if (!obj || typeof obj !== 'object') {
      return optional ? undefined : { id: '', name: '', nameShow: '', avatar: '' };
    }
    const r: Record<string, Object> = obj as Record<string, Object>;
    const portrait: string = this.readString(r, ['portrait', 'portraith', 'avatar', 'avatar_url']);
    return {
      id: this.readString(r, ['id', 'user_id', 'uid']),
      name: this.readString(r, ['name', 'user_name', 'userName']),
      nameShow: this.readString(r, ['name_show', 'nameShow', 'nickname', 'nick_name']),
      avatar: this.normalizePortraitAvatar(portrait),
    };
  }

  /**
   * 读取布尔风格字符串（"1"/"0"/"true"/"false"）
   */
  private readBooleanLike(raw: Record<string, Object>, keys: string[]): boolean {
    const value: Object | undefined = this.readFirst(raw, keys);
    if (value === undefined || value === null) {
      return false;
    }
    const s: string = `${value}`.trim().toLowerCase();
    return s === '1' || s === 'true' || s === 'yes';
  }

  /**
   * 读取对象数组，兼容多种 key
   */
  private readObjectArray(raw: Record<string, Object>, keys: string[]): Object[] {
    const value: Object | undefined = this.readFirst(raw, keys);
    if (value !== undefined && value !== null && Array.isArray(value)) {
      return value as Object[];
    }
    return [];
  }

  /**
   * 读取第一个命中的字段值（内部辅助）
   */
  private readFirst(raw: Record<string, Object>, keys: string[]): Object | undefined {
    for (const key of keys) {
      if (raw[key] !== undefined) {
        return raw[key];
      }
    }
    return undefined;
  }

  /**
   * 发送私信（占位实现，真实需签名接口）
   */
  async sendMessage(toUserId: string, content: string): Promise<boolean> {
    const form: Record<string, string> = {
      'to': toUserId,
      'content': content,
      'tbs': await this.fetchTbs(),
    };
    try {
      await HttpClient.postForm(`${TIEBA_BASE}/mo/q/msg/sendmsg`, form);
      return true;
    } catch (e) {
      return false;
    }
  }

  async fetchCollectedThreads(userId: string, offset: number = 0, pageSize: number = 20): Promise<PersonalContentItem[]> {
    const stoken = await this.ensureFreshStoken();
    return await this.fetchCollectedThreadsInternal(userId, stoken, offset, pageSize);
  }

  private async fetchCollectedThreadsInternal(userId: string, stoken: string, offset: number = 0, pageSize: number = 20): Promise<PersonalContentItem[]> {
    const normalizedUserId: string = userId.trim();
    if (normalizedUserId.length === 0) {
      throw new Error('缺少用户 ID，无法加载云端收藏');
    }
    if (stoken.length === 0) {
      throw new Error('当前登录态缺少 STOKEN，请重新登录后再查看收藏');
    }
    const cuid: string = await this.resolveClientCuid();
    const form: Record<string, string> = {};
    // 公共参数（对齐 CommonParamInterceptor）
    form.BDUSS = AuthManager.getInstance().getBduss();
    form._client_type = '2';
    form._client_version = '12.41.7.1';
    form.cuid = cuid;
    form.cuid_galaxy2 = cuid;
    form.cuid_gid = '';
    form.from = 'tieba';
    form.timestamp = TiebaService.clientTimestampSec();
    form.model = 'HarmonyOS';
    form.net_type = '1';
    // threadstore 业务参数：rn, offset, user_id, stoken
    form.rn = `${Math.max(1, pageSize)}`;
    form.offset = `${Math.max(0, offset)}`;
    form.user_id = normalizedUserId;
    form.stoken = stoken;
    form.sign = await this.signTiebaForm(form);
    const response = await HttpClient.postForm('https://c.tieba.baidu.com/c/f/post/threadstore', form,
      this.buildClientApiHeaders(cuid, normalizedUserId));
    // TS-PROBE 临时探测：threadstore 响应原文（批 A 抓包探测用，验证后移除）
    hilog.info(0x0000, TiebaService.TAG, '[TS-PROBE] RAW=%{public}s', response.substring(0, 1500));
    const trimmed: string = response.trim();
    if (trimmed.startsWith('<')) {
      throw new Error('收藏接口返回了网页内容，登录态可能已失效，请重新登录');
    }
    let payload: Record<string, Object>;
    try {
      payload = JSON.parse(trimmed) as Record<string, Object>;
    } catch (e) {
      throw new Error('收藏接口返回格式异常，请稍后重试');
    }
    const nestedValue: Object | undefined = payload.data;
    const data: Record<string, Object> = nestedValue !== undefined && typeof nestedValue === 'object'
      ? nestedValue as Record<string, Object>
      : payload;
    const errorCode: number = this.readNumber(payload, ['error_code', 'errno', 'no']);
    const nestedErrorCode: number = this.readNumber(data, ['error_code', 'errno', 'no']);
    if (errorCode !== 0 || nestedErrorCode !== 0) {
      const message: string = this.readString(payload, ['error_msg', 'errmsg', 'error', 'message'])
        || this.readString(data, ['error_msg', 'errmsg', 'error', 'message'])
        || '云端收藏加载失败';
      throw new Error(message);
    }
    let rawValue: Object | undefined = data.store_thread ?? data.store_list ?? data.thread_list ?? payload.store_thread;
    if (rawValue !== undefined && !Array.isArray(rawValue) && typeof rawValue === 'object') {
      const nested: Record<string, Object> = rawValue as Record<string, Object>;
      const nestedList: Object | undefined = nested.thread_list ?? nested.store_list ?? nested.list ?? nested.post_list;
      if (nestedList !== undefined && Array.isArray(nestedList)) {
        rawValue = nestedList;
      }
    }
    if (rawValue === undefined || !Array.isArray(rawValue)) {
      return [];
    }

    const collected: PersonalContentItem[] = (rawValue as Object[]).map((item: Object): PersonalContentItem => {
      const record = item as Record<string, Object>;
      const authorValue: Object | undefined = record.author;
      const author: Record<string, Object> = authorValue !== undefined && typeof authorValue === 'object'
        ? authorValue as Record<string, Object>
        : {};
      const tid: string = this.readString(record, ['thread_id', 'tid', 'id']);
      const authorId: string = this.readString(author, ['id', 'user_id', 'uid']);
      return {
        id: tid,
        tid,
        title: this.readString(record, ['title', 'thread_title']) || '未命名帖子',
        forumName: this.readString(record, ['forum_name', 'fname', 'forum']) || '贴吧',
        author: this.readString(author, ['name_show', 'name', 'user_name']) || '贴吧用户',
        authorId: authorId,
        abstract: this.readString(record, ['abstract', 'content', 'post_no_msg', 'last_reply_content']),
        replyNum: this.readNumber(record, ['count', 'reply_num', 'reply_count']),
        createTime: this.readString(record, ['last_time', 'create_time', 'collect_time']),
        accountId: normalizedUserId
      };
    }).filter((item: PersonalContentItem): boolean => item.tid.length > 0);
    // 收藏列表昵称同样可能过期/占位，用 profile 实时昵称校准
    // v1.17 校准失败静默（保留接口原始昵称），避免额外网络请求失败阻塞收藏分页加载
    if (collected.length > 0) {
      try {
        const refreshed: AuthorEnrichTarget[] = await this.enrichAuthorsGeneric(collected.map((item: PersonalContentItem): AuthorEnrichTarget => ({
          authorId: item.authorId,
          author: item.author,
        })));
        for (let i = 0; i < refreshed.length; i++) {
          collected[i].author = refreshed[i].author;
        }
      } catch (e) {
        // 昵称校准失败不影响收藏列表返回
      }
    }
    return collected;
  }

  /** 从 AuthManager 的 cookie 字符串提取指定字段的所有值（按出现顺序去重） */
  private readCookieValues(name: string): string[] {
    const cookie = AuthManager.getInstance().getCookieHeader();
    const pattern = new RegExp(`${name}=([^;]+)`, 'g');
    let match = pattern.exec(cookie);
    const values: string[] = [];
    const seen = new Set<string>();
    while (match !== null) {
      if (!seen.has(match[1])) {
        seen.add(match[1]);
        values.push(match[1]);
      }
      match = pattern.exec(cookie);
    }
    return values;
  }

  /** 读取指定 cookie 字段的第一个值（兼容 passpost 域和 tieba 域同名 cookie） */
  private readCookieValue(name: string): string {
    const values = this.readCookieValues(name);
    if (values.length === 0) {
      return '';
    }
    if (name === 'STOKEN' && values.length > 1) {
      console.info(`[STOKEN] 检测到 ${values.length} 个 STOKEN：第1个前8位=${values[0].substring(0, 8)}, 第2个前8位=${values[1].substring(0, 8)}，用第1个`);
    }
    return values[0];
  }

  /** 获取 tieba 域 STOKEN（安全版逐跳跟随）
   * v64 关键修复：
   *   1. 旧版盲目跟随 passport 重定向链，返回 "Auth Login Params Not Corret" +
   *      "BDUSS=deleted"，触发风控使有效 BDUSS 失效 —— 现已禁止跟随 passport 域
   *   2. applySetCookies 已过滤 deleted/过期 Set-Cookie，保护登录态
   *   3. 有效 BDUSS + 桌面 UA 直接访问 tieba 域，tieba 会在 Set-Cookie 下发 STOKEN
   */
  private stokenRefreshCache: string = '';
  private stokenRefreshFailAt: number = 0;
  private static readonly DESKTOP_UA: string = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  async refreshStoken(): Promise<string> {
    const bduss: string = AuthManager.getInstance().getBduss();
    if (bduss.length === 0) {
      console.warn('[STOKEN] BDUSS 无效（未登录或已失效），跳过刷新');
      return '';
    }
    if (this.stokenRefreshCache.length > 0) {
      return this.stokenRefreshCache;
    }
    if (this.stokenRefreshFailAt > 0 && Date.now() - this.stokenRefreshFailAt < 60 * 1000) {
      return '';
    }
    // 净初始 Cookie：BDUSS + 已有 BAIDUID
    const existingBaiduid: string = this.readCookieValue('BAIDUID');
    let initCookie: string = `BDUSS=${bduss}`;
    if (existingBaiduid.length > 0 && existingBaiduid !== 'deleted') {
      initCookie += `; BAIDUID=${existingBaiduid}`;
    }

    // 安全逐跳跟随：只在 tieba 域内跟随，遇 passport/wappass 域立即停止（保护登录态）
    const endpoints: string[] = [
      'https://tieba.baidu.com/',
      'https://tieba.baidu.com/index.html',
    ];
    let stoken: string = '';
    let successUrl: string = '';
    let mergedCookie: string = initCookie;
    for (const url of endpoints) {
      try {
        console.info(`[STOKEN] 安全逐跳 GET ${url} (桌面UA)`);
        const result = await HttpClient.getWithRedirectCookiesSafe(url, initCookie, TiebaService.DESKTOP_UA);
        console.info(`[STOKEN] ${url} → 最终=${result.finalUrl}, Set-Cookie 数=${result.setCookies.length}`);
        if (result.setCookies.length > 0) {
          console.info(`[STOKEN] Set-Cookie 样本: ${result.setCookies.slice(0, 4).map((c: string): string => c.substring(0, 60)).join(' | ')}`);
        }
        mergedCookie = this.applySetCookies(mergedCookie, result.setCookies);
        for (const raw of result.setCookies) {
          const m = /STOKEN=([^;\s]+)/.exec(raw);
          if (m !== null && m[1].length > 0 && m[1] !== 'deleted') {
            stoken = m[1];
            successUrl = url;
            console.info(`[STOKEN] 从 ${url} 提取到 STOKEN（长度${stoken.length}）`);
            break;
          }
        }
        if (stoken.length > 0) {
          break;
        }
      } catch (e) {
        console.warn(`[STOKEN] ${url} 失败: ${(e as Error).message.substring(0, 60)}`);
      }
    }

    // 持久化预热 Cookie（BAIDUID 等），保留原 cookie 中的 STOKEN（STOKEN 仅由登录流程下发，
    // 整体覆盖会导致登录态缺少 STOKEN，后续写操作全部失败）
    try {
      const prevCookie: string = AuthManager.getInstance().getCookieHeader();
      const prevStoken: RegExpExecArray | null = /STOKEN=[^;]+/.exec(prevCookie);
      let cookieToSave: string = mergedCookie;
      if (prevStoken !== null && cookieToSave.indexOf('STOKEN=') < 0) {
        cookieToSave = `${cookieToSave}; ${prevStoken[0]}`;
      }
      await AuthManager.getInstance().setCookie(cookieToSave);
    } catch (e) {
      console.warn(`[STOKEN] 持久化 Cookie 失败: ${(e as Error).message}`);
    }

    if (stoken.length === 0) {
      console.warn('[STOKEN] 安全逐跳未获取到 STOKEN，走 web 端点（BDUSS 鉴权）兜底');
      this.stokenRefreshFailAt = Date.now();
      return '';
    }
    this.stokenRefreshCache = stoken;
    this.stokenRefreshFailAt = 0;
    console.info(`[STOKEN] 刷新成功（来自 ${successUrl}）`);
    return stoken;
  }

  /** 把 Set-Cookie 列表合并进现有 Cookie 串（同名覆盖，新名追加，保持顺序）
   * v63 修复：跳过 value 为 "deleted" 或明显过期的 Set-Cookie，
   * 否则服务端 "BDUSS=deleted" 会把有效 BDUSS 覆盖掉
   */
  private applySetCookies(cookie: string, setCookies: string[]): string {
    const map = new Map<string, string>();
    const order: string[] = [];
    const push = (name: string, value: string): void => {
      // 剔除服务端删除标记，保护有效登录态
      if (value === 'deleted' || value.length === 0) {
        return;
      }
      if (!map.has(name)) {
        order.push(name);
      }
      map.set(name, value);
    };
    for (const part of cookie.split(';')) {
      const kv: string = part.trim();
      const idx: number = kv.indexOf('=');
      if (idx > 0) {
        const name: string = kv.substring(0, idx);
        const value: string = kv.substring(idx + 1);
        if (value !== 'deleted') {
          push(name, value);
        }
      }
    }
    for (const raw of setCookies) {
      // 跳过已过期的 Set-Cookie（expires 在过去）
      if (/expires=Thu, 31-Dec-2020/i.test(raw) || /expires=Thu, 01-Jan-1970/i.test(raw)) {
        continue;
      }
      const kv: string = raw.split(';')[0].trim();
      const idx: number = kv.indexOf('=');
      if (idx > 0) {
        push(kv.substring(0, idx), kv.substring(idx + 1));
      }
    }
    const parts: string[] = [];
    for (const name of order) {
      parts.push(`${name}=${map.get(name)}`);
    }
    return parts.join('; ');
  }

  /** 获取有效的 tieba 域 STOKEN：逐个探测 Cookie 中的 STOKEN 值，哪个有效用哪个
   * 修复 v58：探测全部失败时不再抛错（之前抛"重定向链中未获取到 STOKEN"会阻断收藏），
   * 而返回空串让 addThreadCollection 走 web 端点兜底（仅需 BDUSS）
   */
  private cachedStoken: string = '';
  private stokenProbeAt: number = 0;
  private static readonly STOKEN_CACHE_TTL_MS: number = 5 * 60 * 1000;

  async ensureFreshStoken(): Promise<string> {
    if (this.cachedStoken.length > 0 && Date.now() - this.stokenProbeAt < TiebaService.STOKEN_CACHE_TTL_MS) {
      return this.cachedStoken;
    }
    const cookie = AuthManager.getInstance().getCookieHeader();
    const pattern = /STOKEN=([^;]+)/g;
    let match = pattern.exec(cookie);
    const candidates: string[] = [];
    while (match !== null) {
      if (!candidates.includes(match[1])) {
        candidates.push(match[1]);
      }
      match = pattern.exec(cookie);
    }
    console.info(`[STOKEN] 候选 STOKEN 数量: ${candidates.length}`);
    const userId: string = AuthManager.getInstance().getUser()?.userId ?? '';
    if (candidates.length > 0 && userId.length > 0) {
      for (let i = 0; i < candidates.length; i++) {
        try {
          await this.fetchCollectedThreadsInternal(userId, candidates[i], 0, 1);
          console.info(`[STOKEN] 候选[${i}] 有效，直接使用`);
          this.cachedStoken = candidates[i];
          this.stokenProbeAt = Date.now();
          return candidates[i];
        } catch (e) {
          console.info(`[STOKEN] 候选[${i}] 无效（${(e as Error).message.substring(0, 40)}）`);
        }
      }
    }
    try {
      const refreshed: string = await this.refreshStoken();
      if (refreshed.length > 0) {
        this.cachedStoken = refreshed;
        this.stokenProbeAt = Date.now();
        return refreshed;
      }
    } catch (e) {
      console.warn(`[STOKEN] 重定向链刷新失败: ${(e as Error).message.substring(0, 60)}`);
    }
    console.warn(`[STOKEN] 无可用 STOKEN，后续将用 web 端点（仅需 BDUSS）兜底`);
    this.cachedStoken = '';
    this.stokenProbeAt = Date.now();
    return '';
  }

  /** 清空 STOKEN 缓存（重新登录时调用） */
  invalidateStokenCache(): void {
    this.cachedStoken = '';
    this.stokenProbeAt = 0;
    this.stokenRefreshCache = '';
  }

  /** threadstore 探测版（允许显式传入 stoken，用于验证） */
  private async fetchCollectedThreadsWithStoken(userId: string, stoken: string, offset: number = 0, pageSize: number = 20): Promise<PersonalContentItem[]> {
    const items = await this.fetchCollectedThreadsInternal(userId, stoken, offset, pageSize);
    return items;
  }

  /* ================= 全吧搜索（搜吧 / 搜贴 / 搜人） =================
   * 接口来源：aiotieba search_global —— 百度贴吧 PC 网页端全站搜索（参考 TiebaLite 三模块搜索）。
   * 三个端点同构：GET /mo/q/search/{forum,thread,user}?word&pn&rn&st&tt&subapp_type&_client_type&sign
   * sign = md5(参数按 key 升序拼接 key=value... + SEARCH_PC_SECRET)，小写十六进制。
   * 2026-09-09 抓包比对：搜吧 data.exactMatch（完全匹配→UI「推荐」位）+ data.fuzzyMatch（相关吧）；
   * 搜贴 data.post_list[]（单条帖子，带 user/forum_info）；搜人 data.exactMatch + data.fuzzyMatch。
   */

  /** 全吧搜索 · 搜吧 */
  async searchForumGlobal(keyword: string, page: number = 1, pageSize: number = 20): Promise<GlobalForumSearchData> {
    const resp = await this.globalSearchGet('forum', keyword, page, pageSize);
    const payload: Record<string, Object> = this.parseSearchJson(resp, '搜索贴吧');
    const data: Record<string, Object> = this.searchDataNode(payload);
    const exactRaw: Object | undefined = data['exactMatch'];
    let exact: GlobalForumResult | null = null;
    if (exactRaw !== undefined && exactRaw !== null && typeof exactRaw === 'object') {
      exact = this.mapGlobalForum(exactRaw);
    }
    const list: GlobalForumResult[] = [];
    const rawList: Object | undefined = data['fuzzyMatch'];
    if (Array.isArray(rawList)) {
      for (const item of rawList as Object[]) {
        const mapped = this.mapGlobalForum(item);
        if (mapped !== null) {
          list.push(mapped);
        }
      }
    }
    return {
      exact,
      list,
      hasMore: this.readNumber(data, ['has_more', 'hasMore']) !== 0,
      page: this.readNumber(data, ['pn', 'current_page']) || page,
    };
  }

  /** 全吧搜索 · 搜贴 */
  async searchPostGlobal(keyword: string, page: number = 1, pageSize: number = 20): Promise<GlobalPostSearchData> {
    const resp = await this.globalSearchGet('thread', keyword, page, pageSize);
    const payload: Record<string, Object> = this.parseSearchJson(resp, '搜索帖子');
    const data: Record<string, Object> = this.searchDataNode(payload);
    const list: GlobalPostResult[] = [];
    const rawList: Object | undefined = data['post_list'];
    if (Array.isArray(rawList)) {
      for (const item of rawList as Object[]) {
        const mapped = this.mapGlobalPost(item);
        if (mapped !== null) {
          list.push(mapped);
        }
      }
    }
    if (list.length === 0) {
      // 搜贴空结果时留一条原始响应（截断），便于区分「服务端无结果」与「字段结构不匹配」
      hilog.info(0x0000, TiebaService.TAG, '[SEARCH-POST] empty resp=%{public}s', resp.substring(0, 600));
    }
    return {
      list,
      hasMore: this.readNumber(data, ['has_more', 'hasMore']) !== 0,
      page: this.readNumber(data, ['pn', 'current_page']) || page,
    };
  }

  /**
   * 全吧搜索 · 搜贴（客户端端点，2026-09-15 实抓替换）。
   *
   * **替换原因**：旧 web 端点 `/mo/q/search/thread` 已被百度停摆——2026-09-14 实测三重确认：
   * ① App 内响应 `success + post_list:[] + blank_type:1`（反爬空结果标记）；② PC 直连同签名同样空；
   * ③ 带 BDUSS cookie 仍空。与登录态无关，端点对所有客户端返回空。
   *
   * **新端点**：吧内搜索同款 `/c/s/searchpost`（客户端 form + `tiebaclient!!!` 签名，工程已验证存活），
   * 实测**【不带 kw 即为全吧搜贴】**——word=冠军 rn=20 命中 20 条、fname 覆盖 13 个不同吧。
   * 表单 = 客户端公共参数（对齐 fetchUserAgreeThreads 同款模板）+ word/pn/rn/only_thread，签名 signTiebaForm。
   */
  async searchPostGlobalClient(keyword: string, page: number = 1, pageSize: number = 20): Promise<GlobalPostSearchData> {
    const kw: string = keyword.trim();
    if (kw.length === 0) {
      return { list: [], hasMore: false, page };
    }
    const cuid: string = await this.resolveClientCuid();
    const form: Record<string, string> = {};
    form.BDUSS = AuthManager.getInstance().getBduss();
    form._client_type = '2';
    form._client_version = '12.41.7.1';
    form.cuid = cuid;
    form.cuid_galaxy2 = cuid;
    form.cuid_gid = '';
    form.from = 'tieba';
    form.timestamp = TiebaService.clientTimestampSec();
    form.model = 'HarmonyOS';
    form.net_type = '1';
    // 业务参数：⚠️ 不带 kw——带上 kw 就变成吧内搜索；不带即全吧（2026-09-15 实测）
    form.word = kw;
    form.pn = `${Math.max(1, page)}`;
    form.rn = `${Math.max(1, pageSize)}`;
    form.only_thread = '1';
    form.sign = await this.signTiebaForm(form);
    const resp: string = await HttpClient.postForm('https://tiebac.baidu.com/c/s/searchpost', form, {
      'Accept': 'application/json, text/plain, */*',
      'User-Agent': 'tieba/12.41.7.1',
      'Referer': 'https://tieba.baidu.com/',
    });
    const trimmed: string = resp.trim();
    if (trimmed.length === 0 || trimmed.startsWith('<')) {
      throw new Error('搜索服务返回异常，请稍后重试');
    }
    const payload: Record<string, Object> = JSON.parse(trimmed) as Record<string, Object>;
    const errorCode: number = this.readNumber(payload, ['no', 'error_code', 'errno']);
    if (errorCode !== 0) {
      const msg: string = this.extractErrMsg(trimmed);
      throw new Error(msg.length > 0 ? msg : `搜索失败(${errorCode})，请稍后重试`);
    }
    // post_list 可能挂顶层或 data 节点（版本差异，两处都找，与吧内搜索同款容错）
    const data: Record<string, Object> = this.searchDataNode(payload);
    let rawList: Object | undefined = payload['post_list'];
    let pageNode: Record<string, Object> = this.searchChild(payload, 'page');
    if (!Array.isArray(rawList)) {
      rawList = data['post_list'];
      pageNode = this.searchChild(data, 'page');
    }
    const list: GlobalPostResult[] = [];
    if (Array.isArray(rawList)) {
      for (const item of rawList as Object[]) {
        const mapped = this.mapClientGlobalPost(item);
        if (mapped !== null) {
          list.push(mapped);
        }
      }
    }
    // has_more 缺失时按「本页是否满页」推断（与吧内搜索同款兜底）
    const hasMoreRaw: Object | undefined = pageNode['has_more'];
    const hasMore: boolean = (hasMoreRaw === undefined || hasMoreRaw === null)
      ? list.length >= Math.max(1, pageSize)
      : this.readNumber(pageNode, ['has_more', 'hasMore']) !== 0;
    if (list.length === 0) {
      hilog.info(0x0000, TiebaService.TAG, '[GSEARCH] client searchpost empty kw=%{public}s pn=%{public}d', kw, page);
    }
    return { list, hasMore, page: Math.max(1, page) };
  }

  /** 客户端全吧搜贴结果项 → GlobalPostResult（字段缺失全容错，仅 tid 必需） */
  private mapClientGlobalPost(item: Object): GlobalPostResult | null {
    if (item === null || typeof item !== 'object') {
      return null;
    }
    const o: Record<string, Object> = item as Record<string, Object>;
    const tid: string = this.readString(o, ['tid', 'thread_id', 'id']);
    if (tid.length === 0) {
      return null;
    }
    const author: Record<string, Object> = this.searchChild(o, 'author');
    return {
      tid,
      pid: this.readString(o, ['pid', 'post_id']),
      forumId: this.readString(o, ['fid', 'forum_id']),
      forumName: this.readString(o, ['fname', 'forum_name']),
      forumAvatar: '',
      title: this.readString(o, ['title']),
      content: this.readClientPostContent(o),
      createTime: this.readNumber(o, ['time', 'create_time']),
      replyNum: this.readNumber(o, ['reply_num', 'reply_count']),
      authorId: this.readString(author, ['id', 'user_id', 'uid']) || this.readString(o, ['author_id', 'user_id']),
      authorName: this.readString(author, ['name']) || this.readString(o, ['author_name', 'user_name']),
      authorShowName: this.readString(author, ['name_show']) || this.readString(o, ['name_show', 'author_name_show']),
      authorAvatar: this.normalizePortraitAvatar(this.readString(author, ['portrait']) || this.readString(o, ['portrait'])),
    };
  }

  /** 客户端搜索 content 字段容错：字符串直取；段数组（[{type,text}]）拼 type=0 的 text */
  private readClientPostContent(o: Record<string, Object>): string {
    const raw: Object | undefined = o['content'];
    if (raw === undefined || raw === null) {
      return '';
    }
    if (typeof raw === 'string') {
      return (raw as string).replace(/\s+/g, ' ').trim().substring(0, 120);
    }
    if (Array.isArray(raw)) {
      const parts: string[] = [];
      for (const seg of raw as Object[]) {
        if (seg !== null && typeof seg === 'object') {
          const so: Record<string, Object> = seg as Record<string, Object>;
          const type: number = this.readNumber(so, ['type']);
          if (type === 0) {
            parts.push(this.readString(so, ['text']));
          }
        } else if (typeof seg === 'string') {
          parts.push(seg as string);
        }
      }
      return parts.join(' ').replace(/\s+/g, ' ').trim().substring(0, 120);
    }
    return '';
  }

  /* ================= 吧内搜索（服务端，TiebaLite 同款端点） =================
   * 端点来源：TiebaLite（贴吧 Lite）SearchPostActivity → MiniTiebaApi.searchPost
   *   POST {host}/c/s/searchpost   (form-urlencoded)
   *   word=关键词  kw=吧名  pn=页码(从 1 起)  rn=每页条数  only_thread=1(仅主题帖)
   *   响应：{ error_code, error_msg, page{ has_more, total_count, ... },
   *           post_list[{ tid, pid, title, content, time, fname, author{ name, name_show } }] }
   * 与本工程已在用的 /c/s/login 同 host 同前缀，故优先走 c.tieba.baidu.com。
   * 这是服务端真搜索：一次即返回整页命中（含正文命中），不再依赖
   * 「扫吧内分页 + 本地标题匹配」——搜索结果少、下滑加载慢的根治手段。
   * 该端点无法离线验证（工程内无文档），故 host × 是否带 sign 做探测阶梯：
   * 首个成功的组合本会话内固定复用；全部失败时由调用方降级为本地扫描兜底。
   */
  private static readonly FORUM_SEARCH_HOSTS: string[] = [
    'https://c.tieba.baidu.com',
    'https://tiebac.baidu.com',
  ];
  private forumSearchHostIdx: number = 0;
  private forumSearchWithSign: boolean = false;
  private forumSearchProbed: boolean = false;

  /**
   * 吧内搜索（服务端）：keyword 在 forumName 吧内的命中帖子。
   * @param page 页码（从 1 起）
   * @param pageSize 每页条数（默认 30）
   */
  async searchPostInForum(forumName: string, keyword: string, page: number = 1, pageSize: number = 30): Promise<ForumSearchData> {
    const kw: string = keyword.trim();
    const forum: string = forumName.trim();
    if (kw.length === 0 || forum.length === 0) {
      return { list: [], hasMore: false, page, total: 0 };
    }
    const size: number = pageSize <= 0 ? 30 : pageSize;
    const form: Record<string, string> = {
      'word': kw,
      'kw': forum,
      'pn': `${Math.max(1, page)}`,
      'rn': `${size}`,
      'only_thread': '1',
      // 公共客户端参数（对齐 TiebaLite CommonParamInterceptor）
      '_client_type': '2',
      '_client_version': '12.41.7.1',
    };
    const bduss: string = AuthManager.getInstance().getBduss();
    if (bduss.length > 0) {
      form['BDUSS'] = bduss;
    }
    const payload: Record<string, Object> | null = await this.requestForumSearch(form, forum);
    if (payload === null) {
      throw new Error('吧内搜索服务不可用，请稍后重试');
    }
    // 不同版本客户端可能把结果挂在 data 节点下，两处都找
    const data: Record<string, Object> = this.searchDataNode(payload);
    let rawList: Object | undefined = data['post_list'];
    let pageNode: Record<string, Object> = this.searchChild(data, 'page');
    if (!Array.isArray(rawList)) {
      rawList = payload['post_list'];
      pageNode = this.searchChild(payload, 'page');
    }
    const list: ThreadItem[] = [];
    if (Array.isArray(rawList)) {
      for (const item of rawList as Object[]) {
        const mapped: ThreadItem | null = this.mapForumSearchPost(item, forum);
        if (mapped !== null) {
          list.push(mapped);
        }
      }
    }
    if (list.length === 0) {
      // 留一条原始响应（截断）便于区分「服务端确实无命中」与「字段结构不匹配」
      hilog.info(0x0000, TiebaService.TAG, '[FSEARCH] empty kw=%{public}s pn=%{public}d', kw, page);
    }
    // has_more 缺失时按「本页是否满页」推断，避免字段变动导致永远只出第一页
    const hasMoreRaw: Object | undefined = pageNode['has_more'];
    let hasMore: boolean;
    if (hasMoreRaw === undefined || hasMoreRaw === null) {
      hasMore = list.length >= size;
    } else {
      hasMore = this.readNumber(pageNode, ['has_more', 'hasMore']) !== 0;
    }
    const total: number = this.readNumber(pageNode, ['total_count', 'total'])
      || this.readNumber(payload, ['total_count', 'total']);
    return { list, hasMore, page, total };
  }

  /**
   * 请求吧内搜索：按探测阶梯依次尝试（host × 是否带 sign），返回已校验业务码的 payload。
   * 首个成功组合本会话固定复用（forumSearchProbed），失败继续下一组合；全失败返回 null。
   */
  private async requestForumSearch(form: Record<string, string>, forum: string): Promise<Record<string, Object> | null> {
    const ladder: number[] = [];
    if (this.forumSearchProbed) {
      ladder.push(this.forumSearchHostIdx * 2 + (this.forumSearchWithSign ? 1 : 0));
    } else {
      for (let h = 0; h < TiebaService.FORUM_SEARCH_HOSTS.length; h++) {
        ladder.push(h * 2);       // 不带 sign 优先（TiebaLite 声明如此）
        ladder.push(h * 2 + 1);   // 带 sign 兜底
      }
    }
    let lastErr: Error | null = null;
    for (const combo of ladder) {
      const hostIdx: number = Math.floor(combo / 2);
      const host: string = TiebaService.FORUM_SEARCH_HOSTS[hostIdx];
      const withSign: boolean = combo % 2 === 1;
      try {
        const body: Record<string, string> = {};
        for (const k of Object.keys(form)) {
          body[k] = form[k];
        }
        if (withSign) {
          body['sign'] = await this.signTiebaForm(body);
        }
        const resp: string = await HttpClient.postForm(`${host}/c/s/searchpost`, body, {
          'Accept': 'application/json, text/plain, */*',
          'User-Agent': 'bdtb for Android 12.41.7.1',
          'Referer': `${TIEBA_BASE}/f?kw=${encodeURIComponent(forum)}`,
        });
        const trimmed: string = resp.trim();
        if (trimmed.length === 0 || trimmed.startsWith('<')) {
          throw new Error('搜索服务返回异常，请稍后重试');
        }
        const parsed: Record<string, Object> = JSON.parse(trimmed) as Record<string, Object>;
        const errno: number = this.readNumber(parsed, ['no', 'error_code', 'errno']);
        if (errno !== 0) {
          const msg: string = this.extractErrMsg(trimmed);
          hilog.info(0x0000, TiebaService.TAG, '[FSEARCH] probe host=%{public}s sign=%{public}d errno=%{public}d msg=%{public}s',
            host, withSign ? 1 : 0, errno, msg);
          throw new Error(msg.length > 0 ? msg : `搜索失败(${errno})，请稍后重试`);
        }
        this.forumSearchHostIdx = hostIdx;
        this.forumSearchWithSign = withSign;
        this.forumSearchProbed = true;
        hilog.info(0x0000, TiebaService.TAG, '[FSEARCH] endpoint ok host=%{public}s sign=%{public}d',
          host, withSign ? 1 : 0);
        return parsed;
      } catch (e) {
        lastErr = e as Error;
      }
    }
    if (lastErr !== null) {
      hilog.info(0x0000, TiebaService.TAG, '[FSEARCH] all endpoints failed: %{public}s', lastErr.message);
    }
    return null;
  }

  /** 吧内搜索结果项 → ThreadItem（字段缺失全容错，仅 tid 必需） */
  private mapForumSearchPost(item: Object, fallbackForum: string): ThreadItem | null {
    if (item === null || typeof item !== 'object') {
      return null;
    }
    const o: Record<string, Object> = item as Record<string, Object>;
    const tid: string = this.readString(o, ['tid', 'thread_id', 'id']);
    if (tid.length === 0) {
      return null;
    }
    const author: Record<string, Object> = this.searchChild(o, 'author');
    let authorName: string = this.readString(author, ['name_show', 'name']);
    if (authorName.length === 0) {
      authorName = this.readString(o, ['author', 'author_name', 'name_show', 'user_name']);
    }
    let authorNameShowMissing: boolean = false;
    if (authorName.length === 0) {
      authorName = '贴吧用户';
      authorNameShowMissing = true;
    }
    const content: string = this.readString(o, ['content', 'abstract']);
    const portrait: string = this.readString(author, ['portrait', 'portraith'])
      || this.readString(o, ['portrait', 'portraith']);
    return {
      tid,
      postId: this.readString(o, ['pid', 'post_id']),
      forumId: this.readString(o, ['forum_id', 'fid']),
      title: this.readString(o, ['title']),
      forumName: this.readString(o, ['fname', 'forum_name']) || fallbackForum,
      forumAvatar: '',
      author: authorName,
      authorId: this.readString(author, ['id', 'user_id', 'uid'])
        || this.readString(o, ['author_id', 'user_id', 'uid']),
      authorAvatar: this.normalizePortraitAvatar(portrait),
      authorNameShowMissing,
      replyNum: this.readNumber(o, ['reply_num', 'reply_count', 'post_num']),
      likeCount: this.readNumber(o, ['like_count', 'agree_num', 'agree']),
      isLiked: false,
      abstract: content.replace(/\s+/g, ' ').trim().substring(0, 120),
      firstImage: '',
      images: [],
      createTime: formatTime(this.readString(o, ['time', 'create_time'])),
      isTop: false,
      isGood: this.readNumber(o, ['is_good', 'good']) === 1,
      isFeatured: false,
    } as ThreadItem;
  }

  /** 全吧搜索 · 搜人 */
  async searchUserGlobal(keyword: string, page: number = 1, pageSize: number = 20): Promise<GlobalUserSearchData> {
    const resp = await this.globalSearchGet('user', keyword, page, pageSize);
    const payload: Record<string, Object> = this.parseSearchJson(resp, '搜索用户');
    const data: Record<string, Object> = this.searchDataNode(payload);
    const exactRaw: Object | undefined = data['exactMatch'];
    let exact: GlobalUserResult | null = null;
    if (exactRaw !== undefined && exactRaw !== null && typeof exactRaw === 'object') {
      exact = this.mapGlobalUser(exactRaw);
    }
    const list: GlobalUserResult[] = [];
    const rawList: Object | undefined = data['fuzzyMatch'];
    if (Array.isArray(rawList)) {
      for (const item of rawList as Object[]) {
        const mapped = this.mapGlobalUser(item);
        if (mapped !== null) {
          list.push(mapped);
        }
      }
    }
    return {
      exact,
      list,
      hasMore: this.readNumber(data, ['has_more', 'hasMore']) !== 0,
      page: this.readNumber(data, ['pn', 'current_page']) || page,
    };
  }

  /** PC 网页搜索统一 GET：拼参数 → 签名 → 请求，返回响应原文 */
  private async globalSearchGet(path: string, keyword: string, page: number, pageSize: number): Promise<string> {
    const form: Record<string, string> = {};
    form.word = keyword.trim();
    form.pn = `${Math.max(1, page)}`;
    form.rn = `${pageSize <= 0 ? 20 : pageSize}`;
    form.st = path === 'thread' ? SEARCH_SORT_THREAD : '1';
    form.tt = '1';
    form.subapp_type = 'pc';
    form._client_type = '20';
    const keys: string[] = Object.keys(form).sort();
    let raw: string = '';
    for (const key of keys) {
      raw += `${key}=${form[key]}`;
    }
    const sign: string = (await HttpClient.md5(`${raw}${SEARCH_PC_SECRET}`)).toLowerCase();
    const query: string = keys.map((key: string): string =>
      `${encodeURIComponent(key)}=${encodeURIComponent(form[key])}`).join('&');
    const url: string = `${TIEBA_BASE}/mo/q/search/${path}?${query}&sign=${sign}`;
    const resp: string = await HttpClient.get(url, {
      'Accept': 'application/json, text/plain, */*',
      'Referer': `${TIEBA_BASE}/f/search/res?ie=utf-8&qw=${encodeURIComponent(form['word'])}`,
      'User-Agent': 'Mozilla/5.0 (Linux; Android 12; HarmonyOS) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    });
    const trimmed: string = resp.trim();
    if (trimmed.length === 0) {
      throw new Error('搜索服务无响应，请稍后重试');
    }
    if (trimmed.startsWith('<')) {
      throw new Error('搜索服务返回异常，请稍后重试');
    }
    return trimmed;
  }

  /** 解析搜索 JSON 并校验业务错误码（no / error_code / errno） */
  private parseSearchJson(resp: string, label: string): Record<string, Object> {
    let payload: Record<string, Object>;
    try {
      payload = JSON.parse(resp) as Record<string, Object>;
    } catch (e) {
      throw new Error(`${label}返回格式异常，请稍后重试`);
    }
    const errno: number = this.readNumber(payload, ['no', 'error_code', 'errno']);
    if (errno !== 0) {
      const msg: string = this.extractErrMsg(resp);
      throw new Error(msg.length > 0 ? msg : `${label}失败(${errno})，请稍后重试`);
    }
    return payload;
  }

  /** 取搜索响应 data 节点（缺失/异常时返回空对象） */
  private searchDataNode(payload: Record<string, Object>): Record<string, Object> {
    const dataObj: Object | undefined = payload['data'];
    if (dataObj === undefined || dataObj === null || typeof dataObj !== 'object') {
      return {};
    }
    return dataObj as Record<string, Object>;
  }

  private searchChild(parent: Record<string, Object>, key: string): Record<string, Object> {
    const child: Object | undefined = parent[key];
    if (child === undefined || child === null || typeof child !== 'object') {
      return {};
    }
    return child as Record<string, Object>;
  }

  /** 映射搜吧结果项（exactMatch / fuzzyMatch 同构） */
  private mapGlobalForum(item: Object): GlobalForumResult | null {
    const o: Record<string, Object> = item as Record<string, Object>;
    const forumId: string = this.readString(o, ['forum_id', 'forumId', 'id']);
    const forumName: string = this.readString(o, ['forum_name', 'forumName', 'name']);
    if (forumName.length === 0) {
      return null;
    }
    const memberNum: number = this.readNumber(o, ['concern_num_ori', 'member_num', 'concernNum']);
    const postNum: number = this.readNumber(o, ['post_num_ori', 'thread_num', 'postNum']);
    const memberShow: string = this.readString(o, ['concern_num', 'concernNumShow', 'member_num_show']);
    const postShow: string = this.readString(o, ['post_num', 'postNumShow', 'thread_num_show']);
    return {
      forumId,
      forumName,
      forumNameShow: this.readString(o, ['forum_name_show', 'forumNameShow']) || forumName,
      avatar: this.readString(o, ['avatar', 'head_url', 'headPic', 'head_pic']),
      memberNumShow: memberShow.length > 0 ? memberShow : this.formatSearchCount(memberNum),
      memberNum,
      postNumShow: postShow.length > 0 ? postShow : this.formatSearchCount(postNum),
      postNum,
      slogan: this.readString(o, ['slogan', 'desc', 'describe']),
      intro: this.readString(o, ['intro']),
      hasConcerned: this.readNumber(o, ['has_concerned', 'hasConcerned']) !== 0,
      isOfficial: this.readNumber(o, ['is_official_forum', 'isOfficialForum']) !== 0,
    };
  }

  /** 映射搜贴结果项（post_list[]） */
  private mapGlobalPost(item: Object): GlobalPostResult | null {
    const o: Record<string, Object> = item as Record<string, Object>;
    const tid: string = this.readString(o, ['tid', 'thread_id', 'threadId', 'id']);
    if (tid.length === 0) {
      return null;
    }
    const user: Record<string, Object> = this.searchChild(o, 'user');
    const forumInfo: Record<string, Object> = this.searchChild(o, 'forum_info');
    const authorName: string = this.readString(user, ['user_name', 'name', 'userName']);
    const authorShow: string = this.readString(user, ['show_nickname', 'user_nickname', 'userNickname', 'showName']);
    const authorAvatar: string = this.readString(user, ['portrait', 'portraith', 'avatar']);
    return {
      tid,
      pid: this.readString(o, ['pid', 'post_id', 'postId']),
      forumId: this.readString(o, ['forum_id', 'forumId', 'fid']) || this.readString(forumInfo, ['forum_id', 'id']),
      forumName: this.readString(o, ['forum_name', 'forumName', 'fname'])
        || this.readString(forumInfo, ['forum_name', 'forumName', 'name']),
      forumAvatar: this.readString(forumInfo, ['avatar', 'forum_avatar', 'head_url']),
      title: this.readString(o, ['title']),
      content: this.readString(o, ['content', 'abstract']),
      createTime: this.readNumber(o, ['create_time', 'createTime', 'time']),
      replyNum: this.readNumber(o, ['post_num', 'reply_num', 'replyNum']),
      authorId: this.readString(user, ['user_id', 'uid', 'id', 'userId']),
      authorName,
      authorShowName: authorShow.length > 0 ? authorShow : authorName,
      authorAvatar: this.normalizePortraitAvatar(authorAvatar),
    };
  }

  /** 映射搜人结果项（exactMatch / fuzzyMatch 同构） */
  private mapGlobalUser(item: Object): GlobalUserResult | null {
    const o: Record<string, Object> = item as Record<string, Object>;
    const userId: string = this.readString(o, ['id', 'user_id', 'uid']);
    const userName: string = this.readString(o, ['name', 'user_name', 'userName']);
    const nick: string = this.readString(o, ['user_nickname', 'userNickname', 'nickname']);
    if (userId.length === 0 && userName.length === 0 && nick.length === 0) {
      return null;
    }
    const show: string = this.readString(o, ['show_nickname', 'showNickname']);
    const avatar: string = this.readString(o, ['portrait', 'portraith', 'avatar']);
    const fansNum: number = this.readNumber(o, ['fans_num', 'fansNum']);
    return {
      userId,
      userName,
      userNickname: nick,
      showName: show.length > 0 ? show : (nick.length > 0 ? nick : userName),
      avatar: this.normalizePortraitAvatar(avatar),
      intro: this.readString(o, ['intro']),
      fansNum,
      hasConcerned: this.readNumber(o, ['has_concerned', 'hasConcerned']) !== 0,
    };
  }

  /** 数字 → 贴吧式展示文本（如 34133 → 3.4W；服务端已带 W 时跳过） */
  private formatSearchCount(num: number): string {
    if (num <= 0) {
      return '';
    }
    if (num >= 100000000) {
      const v: string = (num / 100000000).toFixed(1);
      return `${v.endsWith('.0') ? v.substring(0, v.length - 2) : v}亿`;
    }
    if (num >= 10000) {
      const v: string = (num / 10000).toFixed(1);
      return `${v.endsWith('.0') ? v.substring(0, v.length - 2) : v}W`;
    }
    return `${num}`;
  }

  private async signTiebaForm(form: Record<string, string>): Promise<string> {
    const keys: string[] = Object.keys(form).sort();
    let input: string = '';
    for (const key of keys) {
      input += `${key}=${form[key]}`;
    }
    // 对齐开源 tieba-lite-harmony CryptoUtil.generateSign：百度客户端 API 的 sign 为小写 MD5，
    // 大写会被服务端判定签名错误（返回"未知错误"）。CUID 生成不受影响（内部自行 toUpperCase）。
    return (await HttpClient.md5(`${input}tiebaclient!!!`)).toLowerCase();
  }

  /**
   * 从 proto 帖子内容段提取图片 CDN 链接（图片段 link 字段），最多 9 张、去重。
   * 个人主页发帖接口返回的 abstract/content 中，图片段（type=2）的 link 即大图地址。
   */
  private extractContentImages(parts: AbstractMessage[] | undefined): string[] {
    if (!parts || parts.length === 0) {
      return [];
    }
    const seen: Set<string> = new Set<string>();
    const images: string[] = [];
    for (const part of parts) {
      const link: string = (part.link ?? '').trim();
      if (link.length > 0 && link.startsWith('http') && !seen.has(link)) {
        seen.add(link);
        images.push(link);
        if (images.length >= 9) {
          break;
        }
      }
    }
    return images;
  }

  /**
   * 提取个人发帖接口返回的帖子图片。
   * v1.18 排序调整：优先 protobuf 结构化字段（abstract/content 段 type=2 的 link 是贴吧官方
   * 大图地址，比 HTML 解析更可靠且不受 BDE_Image class 变更影响），再退回 HTML 兜底。
   * 历史：早期抓包确认图片在 field 9 HTML 的 `<img class="BDE_Image">`，但新版接口的
   * contentHtml 字段偶发只返回表情或贴吧 logo 占位，导致列表图区显示"贴字图"。
   * protobuf 字段更权威：直接拿到官方 CDN 大图 URL，避免 HTML 解析误命中占位/表情。
   */
  private pickPostImages(item: PostInfoListMessage): string[] {
    // 1) 优先 protobuf 结构化字段（abstract + content 段 type=2 的 link）
    const pbImages: string[] = this.extractContentImages((item.abstract ?? []).concat(item.content ?? []));
    if (pbImages.length > 0) {
      return pbImages.map((u: string): string => this.normalizePostImageUrl(u)).filter((u: string): boolean => u.length > 0);
    }
    // 2) 兜底 HTML（兼容老接口或 protobuf 暂未下发图片段的边缘场景）
    const html: string = item.contentHtml ?? '';
    const images: string[] = [];
    const blockRegex = /<img[^>]*>/gi;
    let bm: RegExpExecArray | null = blockRegex.exec(html);
    while (bm !== null) {
      const block: string = bm[0];
      if (block.includes('BDE_Image')) {
        const srcM: RegExpExecArray | null = /src=["']([^"']+)["']/i.exec(block);
        if (srcM !== null) {
          let url: string = srcM[1];
          if (url.startsWith('//')) {
            url = 'https:' + url;
          } else if (url.startsWith('http://')) {
            url = url.replace('http://', 'https://');
          }
          // 贴吧老域 tiebapic.baidu.com 在部分设备/网络下被 CDN 限速或返回防盗链占位图（HTTP 200 + 贴吧 logo），
          // 导致关注动态/我的帖子图区显示贴吧 logo 而不是真实图。
          // tiebapic 与 imgsrc.baidu.com 是同一张图（同一 hash 路径）的官方镜像，贴吧移动端 API 默认使用 imgsrc，
          // 这里统一把老域替换为现代域，避免触发老域的防盗链。其它域保持原样不动。
          // URL 路径形态有两种：
          //   1) /forum/pic/item/<hash>.jpg       (直链，最常见)
          //   2) /forum/w%3D960%3Bq%3D60/sign=... (带签名限速模板，w/q/sign 被 URL-encoded 进路径)
          // 这两种都需要替换。
          if (url.startsWith('http://tiebapic.baidu.com/') || url.startsWith('https://tiebapic.baidu.com/')) {
            url = url.replace('tiebapic.baidu.com', 'imgsrc.baidu.com');
          }
          if (url.length > 0 && !images.includes(url)) {
            images.push(url);
            if (images.length >= 9) {
              break;
            }
          }
        }
      }
      bm = blockRegex.exec(html);
    }
    if (images.length > 0) {
      return images;
    }
    // 兜底：通用 img 提取，过滤表情/编辑器图标
    const fallback: string[] = [];
    for (const url of extractImages(html)) {
      if (url.includes('/tb/editor/') || url.includes('gsp0.baidu.com') || url.includes('static.tieba.baidu.com')) {
        continue;
      }
      fallback.push(url);
      if (fallback.length >= 9) {
        break;
      }
    }
    if (fallback.length > 0) {
      return fallback;
    }
    // 末尾兜底（protobuf 已在最前优先处理，这里保留以防 pickPostImages 被直接复用时漏过 abstract/content）
    return this.extractContentImages((item.abstract ?? []).concat(item.content ?? []));
  }

  /**
   * 归一化帖子图片 URL：
   *  - 协议相对 `//xxx` → `https://xxx`
   *  - `http://` → `https://`
   *  - 贴吧老域 `tiebapic.baidu.com` → `imgsrc.baidu.com`（同一 hash 的官方镜像，避免触发老域防盗链/限速）
   * 其它域保持不动。
   */
  private normalizePostImageUrl(url: string): string {
    if (url.length === 0) {
      return '';
    }
    if (url.startsWith('//')) {
      url = 'https:' + url;
    } else if (url.startsWith('http://')) {
      url = url.replace('http://', 'https://');
    }
    if (url.startsWith('https://tiebapic.baidu.com/')) {
      url = url.replace('tiebapic.baidu.com', 'imgsrc.baidu.com');
    }
    return url;
  }

  async fetchUserContent(userId: string, page: number = 1, isThread: boolean = true, enrich: boolean = true): Promise<PersonalContentItem[]> {
    const normalizedUserId: string = userId.trim();
    if (normalizedUserId.length === 0) {
      throw new Error('缺少用户 ID，无法加载个人内容');
    }
    const common = ProtoSchema.commonRequest(new Map<string, string | number>([
      ['_client_type', 2], ['_client_version', '12.41.7.1'], ['_os_version', '26'],
      ['model', 'HarmonyOS'], ['brand', 'Huawei'], ['net_type', 1], ['scr_w', 360],
      ['scr_h', 800], ['scr_dip', 1], ['pversion', '1.0.3'], ['BDUSS', AuthManager.getInstance().getBduss()]
    ]));
    const request = ProtoSchema.userPostRequest(normalizedUserId, page, isThread, common);
    const binary = await HttpClient.postProtoMultipart('https://c.tieba.baidu.com/c/u/feed/userpost?cmd=303002', request, {
      'User-Agent': 'tieba/12.41.7.1', 'Accept': 'application/octet-stream',
      'X-BD-DATA-TYPE': 'protobuf', 'Client-Type': '2', 'Charset': 'UTF-8',
      'Referer': 'https://tieba.baidu.com/'
    });
    const decoded = TiebaProtoDecoder.decodeUserPostResponse(binary);
    const errorCode = decoded.error?.errorCode ?? 0;
    if (errorCode !== 0) {
      throw new Error(decoded.error?.userMsg ?? decoded.error?.errorMsg ?? `个人内容接口错误 ${errorCode}`);
    }
    const content: PersonalContentItem[] = (decoded.data?.postList ?? []).map((item: PostInfoListMessage): PersonalContentItem => ({
      id: `${item.postId ?? item.threadId ?? ''}`,
      tid: `${item.threadId ?? item.postId ?? ''}`,
      title: item.title ?? '未命名帖子',
      forumName: item.forumName ?? '贴吧',
      author: this.displayAuthor({ id: item.userId, name: item.userName, name_show: item.nameShow }),
      authorId: `${item.userId ?? ''}`,
      abstract: (item.abstract ?? item.content ?? []).map((part: AbstractMessage): string => part.text ?? '').join(''),
      replyNum: item.replyNum ?? 0,
      createTime: `${item.createTime ?? ''}`,
      images: this.pickPostImages(item)
    })).filter((item: PersonalContentItem): boolean => item.tid.length > 0);
    // "我的帖子"作者昵称（通常为当前用户）同样可能过期/占位，用 profile 实时昵称校准
    // enrich=false（关注动态聚合场景）跳过：作者昵称由关注列表提供，避免每人多一次 profile 请求
    if (enrich && content.length > 0) {
      const refreshed: AuthorEnrichTarget[] = await this.enrichAuthorsGeneric(content.map((item: PersonalContentItem): AuthorEnrichTarget => ({
        authorId: item.authorId,
        author: item.author,
      })));
      for (let i = 0; i < refreshed.length; i++) {
        content[i].author = refreshed[i].author;
      }
    }
    return content;
  }

  async fetchUserStats(userId: string): Promise<UserStats> {
    const normalizedUserId: string = userId.trim();
    if (normalizedUserId.length === 0) {
      throw new Error('缺少用户 ID，无法加载个人统计');
    }
    const common = ProtoSchema.commonRequest(new Map<string, string | number>([
      ['_client_type', 2],
      ['_client_version', '12.41.7.1'],
      ['_os_version', '26'],
      ['model', 'HarmonyOS'],
      ['brand', 'Huawei'],
      ['net_type', 1],
      ['scr_w', 360],
      ['scr_h', 800],
      ['scr_dip', 1],
      ['pversion', '1.0.3'],
      ['BDUSS', AuthManager.getInstance().getBduss()]
    ]));
    const request = ProtoSchema.profileRequest(normalizedUserId, 1, common);
    const binary = await HttpClient.postProtoMultipart('https://c.tieba.baidu.com/c/u/user/profile?cmd=303012', request, {
      'User-Agent': 'tieba/12.41.7.1',
      'Accept': 'application/octet-stream',
      'X-BD-DATA-TYPE': 'protobuf',
      'Client-Type': '2',
      'Charset': 'UTF-8',
      'Referer': 'https://tieba.baidu.com/'
    });
    const decoded = TiebaProtoDecoder.decodeProfileResponse(binary);
    const errorCode = decoded.error?.errorCode ?? 0;
    if (errorCode !== 0) {
      throw new Error(decoded.error?.userMsg ?? decoded.error?.errorMsg ?? `个人统计接口错误 ${errorCode}`);
    }
    const user = decoded.data?.user;
    // 统计页"我的帖子"只展示发布的主题贴数；
    // postNum 包含回复会让数字虚高，优先用 threadNum(主题贴数)，缺失时再退回 postNum 兜底。
    const postCount: number = user?.threadNum ?? user?.postNum ?? 0;
    const agreeCount: number = decoded.data?.userAgreeInfo?.totalAgreeNum ?? user?.totalAgreeNum ?? user?.agreeNum ?? 0;
    return { postCount, agreeCount };
  }

  // ===== 用户主页（v1.12 · 批 C；关注/取关/关注吧接口待批 A 抓包定案，以下为结构化占位）=====

  /**
   * 拉取用户主页完整资料（proto profile 接口 cmd=303012，扩展解析）。
   * 昵称/头像/简介/性别/IP/关注·粉丝·获赞/发帖数/是否已关注；带 USER_PROFILE TTL 缓存。
   * 是否已拉黑字段（is_black）profile 返回暂无对应 proto 字段，以批 A 抓包实测为准。
   */
  async fetchUserProfile(userId: string): Promise<UserProfileModel> {
    const normalizedUserId: string = userId.trim();
    if (normalizedUserId.length === 0) {
      throw new Error('缺少用户 ID，无法加载用户资料');
    }
    const cacheKey: string = `${CACHE_KEY.USER_PROFILE_CACHE}_${normalizedUserId}`;
    try {
      const cached = await CacheManager.getInstance().getWithTtlAllowStale<UserProfileModel>(cacheKey);
      if (cached !== undefined) {
        return cached.data;
      }
    } catch (e) {
      // 缓存读取失败继续走网络
    }
    const common = ProtoSchema.commonRequest(new Map<string, string | number>([
      ['_client_type', 2],
      ['_client_version', '12.41.7.1'],
      ['_os_version', '26'],
      ['model', 'HarmonyOS'],
      ['brand', 'Huawei'],
      ['net_type', 1],
      ['scr_w', 360],
      ['scr_h', 800],
      ['scr_dip', 1],
      ['pversion', '1.0.3'],
      ['BDUSS', AuthManager.getInstance().getBduss()]
    ]));
    const request = ProtoSchema.profileRequest(normalizedUserId, 1, common);
    const binary = await HttpClient.postProtoMultipart('https://c.tieba.baidu.com/c/u/user/profile?cmd=303012', request, {
      'User-Agent': 'tieba/12.41.7.1',
      'Accept': 'application/octet-stream',
      'X-BD-DATA-TYPE': 'protobuf',
      'Client-Type': '2',
      'Charset': 'UTF-8',
      'Referer': 'https://tieba.baidu.com/'
    });
    const decoded = TiebaProtoDecoder.decodeProfileResponse(binary);
    const errorCode = decoded.error?.errorCode ?? 0;
    if (errorCode !== 0) {
      throw new Error(decoded.error?.userMsg ?? decoded.error?.errorMsg ?? `用户资料接口错误 ${errorCode}`);
    }
    const user = decoded.data?.user;
    if (!user) {
      throw new Error('未获取到用户资料');
    }
    // 昵称：nameShow 优先，跳过“贴吧用户_xxx/吧友xxxx”占位名与不可见字符，与全工程校准逻辑一致
    const rawNameShow: string = `${user.nameShow ?? ''}`.trim();
    const rawName: string = `${user.name ?? ''}`.trim();
    let name: string = (rawNameShow.length > 0 && !rawNameShow.startsWith('贴吧用户_')
      && !rawNameShow.startsWith('吧友') && !this.isInvisibleNickname(rawNameShow))
      ? rawNameShow
      : (rawName.length > 0 ? rawName : '');
    if (name.length === 0) {
      name = '贴吧用户';
    }
    const agreeNum: number = decoded.data?.userAgreeInfo?.totalAgreeNum ?? user.totalAgreeNum ?? user.agreeNum ?? 0;
    const rawPortrait: string = `${user.portrait ?? user.portraith ?? ''}`.trim();
    const profile: UserProfileModel = {
      userId: `${user.id ?? normalizedUserId}`,
      name,
      avatar: this.normalizePortraitAvatar(rawPortrait),
      portrait: rawPortrait,
      intro: `${user.intro ?? user.displayIntro ?? ''}`.trim(),
      sex: user.sex ?? user.gender ?? 0,
      ip: `${user.ip ?? user.ipAddress ?? ''}`.trim(),
      fansNum: user.fansNum ?? 0,
      concernNum: user.concernNum ?? 0,
      agreeNum,
      postCount: user.postNum ?? user.threadNum ?? 0,
      isFollowed: (user.hasConcerned ?? 0) === 1,
    };
    try {
      await CacheManager.getInstance().putWithTtl(cacheKey, profile, CACHE_TTL.USER_PROFILE);
    } catch (e) {
      // 缓存写入失败不阻断
    }
    return profile;
  }

  /**
   * 关注用户（写入操作）。
   * 已抓包确认（批A）：贴吧关注接口以 portrait（头像 hash）为操作标识，
   * 地址 POST https://tiebac.baidu.com/c/c/user/follow，参数 BDUSS + portrait + tbs + sign。
   */
  async followUser(portrait: string, userName: string): Promise<boolean> {
    if (portrait.length === 0) {
      throw new Error('缺少用户标识，无法关注');
    }
    const form: Record<string, string> = {
      'BDUSS': AuthManager.getInstance().getBduss(),
      'portrait': portrait,
      'tbs': await this.fetchTbs(),
      '_client_version': '12.57.4.2',
    };
    form['sign'] = await this.signTiebaForm(form);
    try {
      const resp = await HttpClient.postForm(`${API.FOLLOW_ADD}`, form);
      const parsed: Record<string, Object> = JSON.parse(resp) as Record<string, Object>;
      const errCode: string = `${parsed.error_code ?? '0'}`;
      if (errCode !== '0' && errCode !== '') {
        const emsg: string = `${parsed.error_msg ?? '未知错误'}`;
        throw new Error(`关注失败：${emsg}（${errCode}）`);
      }
      return true;
    } catch (e) {
      const errMsg: string = e instanceof Error ? e.message : `${e}`;
      if (errMsg.startsWith('关注失败')) {
        throw new Error(errMsg);
      }
      throw new Error('关注失败，请稍后重试');
    }
  }

  /**
   * 取消关注用户（写入操作）。
   * 已抓包确认（批A）：POST https://tiebac.baidu.com/c/c/user/unfollow，参数 BDUSS + portrait + tbs + sign。
   */
  async unfollowUser(portrait: string): Promise<boolean> {
    if (portrait.length === 0) {
      throw new Error('缺少用户标识，无法取消关注');
    }
    const form: Record<string, string> = {
      'BDUSS': AuthManager.getInstance().getBduss(),
      'portrait': portrait,
      'tbs': await this.fetchTbs(),
      '_client_version': '12.57.4.2',
    };
    form['sign'] = await this.signTiebaForm(form);
    try {
      const resp = await HttpClient.postForm(`${API.FOLLOW_DEL}`, form);
      const parsed: Record<string, Object> = JSON.parse(resp) as Record<string, Object>;
      const errCode: string = `${parsed.error_code ?? '0'}`;
      if (errCode !== '0' && errCode !== '') {
        const emsg: string = `${parsed.error_msg ?? '未知错误'}`;
        throw new Error(`取消关注失败：${emsg}（${errCode}）`);
      }
      return true;
    } catch (e) {
      const errMsg: string = e instanceof Error ? e.message : `${e}`;
      if (errMsg.startsWith('取消关注失败')) {
        throw new Error(errMsg);
      }
      throw new Error('取消关注失败，请稍后重试');
    }
  }

  /**
   * 拉取我关注的用户列表（分页，含互相关注标记）。
   * 已抓包确认（批A）：POST https://tiebac.baidu.com/c/u/follow/followList，
   * 参数 BDUSS + _client_version + pn + uid + sign；返回 total_follow_num/has_more/follow_list。
   * 字段映射：id→userId，name_show→name（占位名回退 name），portrait，intro，has_concerned→isFriend。
   * 注：接口不返回关注时间，followTime 置 0（时间排序降级为接口默认顺序）。
   */
  async fetchFollowUserList(page: number, pageSize: number = 20): Promise<FollowListResult> {
    if (!AuthManager.getInstance().isLogin()) {
      throw new Error('请先登录后查看关注列表');
    }
    const user = AuthManager.getInstance().getUser();
    const uid: string = `${user?.userId ?? ''}`;
    const form: Record<string, string> = {
      'BDUSS': AuthManager.getInstance().getBduss(),
      '_client_version': '12.57.4.2',
      'pn': `${page + 1}`,
      'uid': uid,
    };
    form['sign'] = await this.signTiebaForm(form);
    try {
      const resp = await HttpClient.postForm(`${API.FOLLOW_USER_LIST}`, form);
      if (!resp.trim().startsWith('{')) {
        throw new Error('关注列表接口返回异常（登录态可能已失效，请重新登录）');
      }
      const parsed: Record<string, Object> = JSON.parse(resp) as Record<string, Object>;
      const errCode: string = `${parsed.error_code ?? parsed.errorCode ?? '0'}`;
      if (errCode !== '0' && errCode !== '' && errCode !== 'undefined') {
        throw new Error(this.extractErrMsg(resp) || '拉取关注列表失败');
      }
      const rawTotal: string = `${parsed.total_follow_num ?? parsed.total ?? '0'}`;
      const total: number = parseInt(rawTotal, 10) || 0;
      const rawList: Object[] = (parsed.follow_list ?? []) as Object[];
      const list: FollowUserItem[] = [];
      for (const raw of rawList) {
        const r: Record<string, Object> = raw as Record<string, Object>;
        const rawPortrait: string = `${r.portrait ?? r.portraith ?? ''}`.trim();
        const rawNameShow: string = `${r.name_show ?? ''}`.trim();
        const rawName: string = `${r.name ?? ''}`.trim();
        // 昵称占位（贴吧用户_xxx / 吧友_xxx）回退用户名
        const name: string = (rawNameShow.length > 0 && rawNameShow !== '贴吧用户'
          && !rawNameShow.startsWith('贴吧用户_') && !rawNameShow.startsWith('吧友'))
          ? rawNameShow
          : (rawName.length > 0 ? rawName : '贴吧用户');
        const item: FollowUserItem = {
          userId: `${r.id ?? ''}`,
          name,
          avatar: this.normalizePortraitAvatar(rawPortrait),
          portrait: rawPortrait,
          intro: `${r.intro ?? ''}`.trim(),
          isFriend: `${r.has_concerned ?? '0'}` === '1',
          followTime: 0,
        };
        if (item.userId.length > 0 || item.name.length > 0 || item.portrait.length > 0) {
          list.push(item);
        }
      }
      const hasMore: boolean = `${parsed.has_more ?? '0'}` === '1';
      return { list, hasMore, page, total };
    } catch (e) {
      if ((e as Error).name === 'SyntaxError' || e instanceof SyntaxError) {
        throw new Error('关注列表接口返回异常（登录态可能已失效，请重新登录）');
      }
      throw new Error((e as Error).message ?? '拉取关注列表失败');
    }
  }

  /**
   * 拉取我的粉丝列表（分页），仅返回互相关注用户（has_concerned === '1'，即我回关了该粉丝）。
   * 已实测确认（2026-08-31）：POST https://tiebac.baidu.com/c/u/fans/page，
   * 参数 BDUSS + _client_version + pn + uid + sign；返回 page(has_more/total_count)/user_list。
   * 字段映射：id→userId，name_show→name（占位名回退 name），portrait，intro，
   * has_concerned→isFriend（互关标记），follow_time（秒）→followTime（ms，TA 关注我的时间，可排序）。
   */
  async fetchFollowUserFansList(page: number, pageSize: number = 100): Promise<FollowListResult> {
    if (!AuthManager.getInstance().isLogin()) {
      throw new Error('请先登录后查看粉丝列表');
    }
    const user = AuthManager.getInstance().getUser();
    const uid: string = `${user?.userId ?? ''}`;
    const form: Record<string, string> = {
      'BDUSS': AuthManager.getInstance().getBduss(),
      '_client_version': '12.57.4.2',
      'pn': `${page + 1}`,
      'uid': uid,
    };
    form['sign'] = await this.signTiebaForm(form);
    try {
      const resp = await HttpClient.postForm('https://tiebac.baidu.com/c/u/fans/page', form);
      if (!resp.trim().startsWith('{')) {
        throw new Error('粉丝列表接口返回异常（登录态可能已失效，请重新登录）');
      }
      const parsed: Record<string, Object> = JSON.parse(resp) as Record<string, Object>;
      const errCode: string = `${parsed.error_code ?? parsed.errorCode ?? '0'}`;
      if (errCode !== '0' && errCode !== '' && errCode !== 'undefined') {
        throw new Error(this.extractErrMsg(resp) || '拉取粉丝列表失败');
      }
      const rawPage: Record<string, Object> = (parsed.page ?? {}) as Record<string, Object>;
      const total: number = parseInt(`${rawPage.total_count ?? '0'}`, 10) || 0;
      const hasMore: boolean = `${rawPage.has_more ?? '0'}` === '1';
      const rawList: Object[] = (parsed.user_list ?? []) as Object[];
      const list: FollowUserItem[] = [];
      for (const raw of rawList) {
        const r: Record<string, Object> = raw as Record<string, Object>;
        // 互关标记：has_concerned = 我是否已关注该粉丝（粉丝 + 我关注 = 互相关注）
        if (`${r.has_concerned ?? '0'}` !== '1') {
          continue;
        }
        const rawPortrait: string = `${r.portrait ?? r.portraith ?? ''}`.trim();
        const rawNameShow: string = `${r.name_show ?? ''}`.trim();
        const rawName: string = `${r.name ?? ''}`.trim();
        const name: string = (rawNameShow.length > 0 && rawNameShow !== '贴吧用户'
          && !rawNameShow.startsWith('贴吧用户_') && !rawNameShow.startsWith('吧友'))
          ? rawNameShow
          : (rawName.length > 0 ? rawName : '贴吧用户');
        const rawFollowTime: string = `${r.follow_time ?? '0'}`;
        const item: FollowUserItem = {
          userId: `${r.id ?? ''}`,
          name,
          avatar: this.normalizePortraitAvatar(rawPortrait),
          portrait: rawPortrait,
          intro: `${r.intro ?? ''}`.trim(),
          isFriend: true,
          followTime: (parseInt(rawFollowTime, 10) || 0) * 1000,
        };
        if (item.userId.length > 0 || item.name.length > 0 || item.portrait.length > 0) {
          list.push(item);
        }
      }
      return { list, hasMore, page, total };
    } catch (e) {
      if ((e as Error).name === 'SyntaxError' || e instanceof SyntaxError) {
        throw new Error('粉丝列表接口返回异常（登录态可能已失效，请重新登录）');
      }
      throw new Error((e as Error).message ?? '拉取粉丝列表失败');
    }
  }

  /**
   * 拉取用户关注的吧列表（分页，含他人主页）。
   * 已抓包确认（2026-09-15 PC 侧真实登录态实测）：POST https://c.tieba.baidu.com/c/f/forum/like，
   * 即「我的关注吧」同款端点，需全套客户端公共参数（同 fetchUserAgreeThreads 模板）+ 登录态。
   * 参数语义（实测）：带 BDUSS 时服务端【忽略 uid】恒回本人列表；**查他人必须用 friend_uid=目标 uid**
   * （uid 传查看者自己）。实测 friend_uid 换不同目标返回不同列表、与自己列表交集极小，非「共同关注」。
   * 缺公共参数时服务端返回 error_code=0 但数据为空，别误判为「该用户没关注吧」。
   * 响应：forum_list[0]."non-gconforum" 为吧列表（id/name/level_id/level_name/avatar/slogan），
   * 顶层 has_more 判定分页；rn 服务端最低按 50 返回。未登录（游客）实测拿不到数据。
   */
  async fetchUserLikeList(userId: string, page: number = 1, pageSize: number = 20): Promise<PagedResult<UserLikeItem>> {
    if (userId.length === 0) {
      throw new Error('缺少用户 ID，无法加载关注的吧');
    }
    const cuid: string = await this.resolveClientCuid();
    const viewerId: string = AuthManager.getInstance().getUser()?.userId ?? '';
    const bduss: string = AuthManager.getInstance().getBduss();
    const form: Record<string, string> = {};
    if (bduss.length > 0) {
      form.BDUSS = bduss;
      form.is_guest = '0';
    } else {
      form.is_guest = '1';
    }
    form._client_type = '2';
    form._client_version = '12.41.7.1';
    form.cuid = cuid;
    form.cuid_galaxy2 = cuid;
    form.cuid_gid = '';
    form.from = 'tieba';
    form.timestamp = TiebaService.clientTimestampSec();
    form.model = 'HarmonyOS';
    form.net_type = '1';
    // 带 BDUSS 时服务端忽略 uid 恒回本人列表，查他人必须 friend_uid=目标 uid（uid 传查看者自己）
    form.uid = viewerId;
    form.friend_uid = userId;
    form.pn = `${Math.max(1, page)}`;
    form.rn = `${Math.max(1, pageSize)}`;
    form.sign = await this.signTiebaForm(form);
    let resp: string = '';
    try {
      resp = await HttpClient.postForm('https://c.tieba.baidu.com/c/f/forum/like', form,
        this.buildClientApiHeaders(cuid, viewerId));
    } catch (e) {
      throw new Error(`加载关注的吧失败：${(e as Error).message ?? '网络异常'}`);
    }
    const trimmed: string = resp.trim();
    if (trimmed.startsWith('<')) {
      throw new Error('关注的吧接口返回了网页内容，登录态可能已失效，请重新登录');
    }
    let list: UserLikeItem[] = [];
    let hasMore: boolean = false;
    try {
      // 与 requestModernApi 同款归一化：服务端返回怪键 "non-gconforum"
      const parsed = JSON.parse(trimmed.replace(/"non-gconforum"/g, '"non_gconforum"')) as Record<string, Object>;
      const errCode: string = `${parsed.error_code ?? parsed.errorCode ?? '0'}`;
      if (errCode !== '0' && errCode !== '' && errCode !== 'undefined') {
        throw new Error(this.extractErrMsg(resp) || '加载关注的吧失败');
      }
      if (bduss.length === 0) {
        throw new Error('登录后才能查看用户关注的吧');
      }
      // forum_list 实测形态：数组 [{non_gconforum: [吧...]}]；做防御兼容（数组/对象/缺失均不崩）
      const rawList: Object[] = this.collectUserLikeForums(parsed);
      console.info(`[USERLIKE] resp_len=${trimmed.length} items=${rawList.length}`);
      list = [];
      for (const raw of rawList) {
        const r: Record<string, Object> = raw as Record<string, Object>;
        const item: UserLikeItem = {
          forumId: `${r.forum_id ?? r.fid ?? r.id ?? ''}`,
          forumName: `${r.forum_name ?? r.name ?? ''}`,
          avatar: this.normalizeForumAvatar(`${r.avatar ?? r.forum_avatar ?? ''}`),
          postCount: parseInt(`${r.thread_num ?? r.post_num ?? '0'}`, 10) || 0,
          intro: `${r.slogan ?? r.intro ?? ''}`.trim(),
        };
        if (item.forumName.length > 0) {
          list.push(item);
        }
      }
      hasMore = `${parsed.has_more ?? parsed.hasMore ?? '0'}` === '1';
    } catch (e) {
      if (e instanceof Error && (e.message.startsWith('登录后才能') || e.message.endsWith('加载关注的吧失败') || e.message.includes('登录态可能已失效'))) {
        throw e;
      }
      console.error(`[USERLIKE] parse failed: ${(e as Error).message ?? 'unknown'} stack=${(e as Error).stack ?? ''}`);
      throw new Error('关注的吧数据解析失败，请稍后重试');
    }
    return { list, hasMore, page };
  }

  /**
   * 从 /c/f/forum/like 响应中提取「关注的吧」条目数组（防御形态）。
   * 实测形态：forum_list = [{ "non-gconforum": [吧...] }]（归一化后键为 non_gconforum）；
   * 兼容：forum_list 为对象（直接含 non_gconforum）、顶层 like_forum 直挂数组、条目散挂等异常形态。
   */
  private collectUserLikeForums(parsed: Record<string, Object>): Object[] {
    const out: Object[] = [];
    // 形态 0：顶层 like_forum 直挂数组（旧占位实现的预期形态，兜底兼容）
    const direct = this.readObjectArray(parsed, ['like_forum']);
    for (const it of direct) {
      out.push(it);
    }
    if (out.length > 0) {
      return out;
    }
    // 形态 1/2：forum_list 为分组数组或单个分组对象，真实列表在每组的 non_gconforum 键下
    const groupsValue: Object | undefined = parsed['forum_list'];
    if (groupsValue === undefined || groupsValue === null) {
      return out;
    }
    const groups: Object[] = Array.isArray(groupsValue) ? groupsValue as Object[] : [groupsValue];
    for (const group of groups) {
      if (group === null || typeof group !== 'object') {
        continue;
      }
      const inner = this.readObjectArray(group as Record<string, Object>, ['non_gconforum', 'forum_list', 'list']);
      for (const it of inner) {
        out.push(it);
      }
    }
    return out;
  }

  /**
   * 获取当前用户信息（优先复刻 TiebaLite 的 mo/q/newmoindex，网页仅作兜底）。
   */
  async fetchUserInfo(): Promise<UserInfoResult | null> {
    try {
      const response = await HttpClient.get(`${API.LIKE_FORUM}?need_user=1`, {
        'Accept': 'application/json, text/plain, */*',
        'Referer': `${TIEBA_BASE}/mo/q/newmoindex`
      });
      const payload = JSON.parse(response) as Record<string, Object>;
      const data = payload.data;
      if (data !== null && typeof data === 'object') {
        const record = data as Record<string, Object>;
        const userId: string = this.readString(record, ['id', 'user_id', 'uid']);
        // 与列表/详情保持一致：优先取 name_show 实时昵称，跳过“贴吧用户_xxx/吧友xxxx”占位名，
        // 避免头部显示用户名而列表/详情显示昵称造成的不一致
        const rawNick: string = this.readString(record, ['name_show', 'nameShow', 'nickname', 'nick_name']).trim();
        const rawUser: string = this.readString(record, ['name', 'user_name', 'userName']).trim();
        const name: string = (rawNick.length > 0 && rawNick !== '贴吧用户'
          && !rawNick.startsWith('贴吧用户_') && !rawNick.startsWith('吧友')
          && !this.isInvisibleNickname(rawNick))
          ? rawNick
          : rawUser;
        const portrait: string = this.readString(record, [
          'portrait', 'portraith', 'avatar', 'avatar_url', 'bimg_url', 'new_icon_url'
        ]).trim();
        const avatar: string = this.normalizePortraitAvatar(portrait);
        if (name.length > 0 || avatar.length > 0) {
          return { userId, name, avatar };
        }
      }
    } catch (e) {
      // 移动用户接口失败时继续网页个人页兜底。
    }
    try {
      const html = await HttpClient.get(API.USER_HOME);
      const rawName = extractGroup(html, /<a[^>]*class=["'][^"']*(?:user_name|userinfo_username|u_username)[^"']*["'][^>]*>([\s\S]*?)<\/a>/i)
        || extractGroup(html, /<span[^>]*class=["'][^"']*(?:user_name|userinfo_username|u_username)[^"']*["'][^>]*>([\s\S]*?)<\/span>/i)
        || extractGroup(html, /["'](?:name_show|nameShow|user_name|userName|nickname)["']\s*:\s*["']([^"']+)["']/i)
        || extractGroup(html, /<title>[\s\S]*?贴吧[\s\S]*?[丨|｜-][\s\S]*?<\/title>/i);
      const name = stripHtml(decodeHtmlEntities(rawName)).replace(/\s+/g, ' ').trim();
      const rawAvatar = extractGroup(html, /class=["'][^"']*(?:userinfo_head|u_head|userinfo_avatar)[^"']*["'][^>]*>[\s\S]*?<img[^>]+(?:src|data-src|data-original)=["']([^"']+)["']/i)
        || extractGroup(html, /(?:portrait|portraith|avatar|avatar_url|bimg_url)["'=：:]\s*["']([^"']+)["']/i);
      const avatar = rawAvatar.startsWith('http://') ? rawAvatar.replace(/^http:\/\//, 'https://') : rawAvatar;
      const userId = extractGroup(html, /(?:un|portrait|uid|user_id)["'=：:]\s*["']?([^"'&<\s]+)/i);
      if (!name || name === '贴吧' || name.includes('百度贴吧')) {
        return null;
      }
      const result: UserInfoResult = { name, avatar, userId };
      return result;
    } catch (e) {
      return null;
    }
  }

  private normalizePortraitAvatar(portrait: string): string {
    if (portrait.length === 0) {
      return '';
    }
    if (portrait.startsWith('http://') || portrait.startsWith('https://')) {
      return portrait.replace(/^http:\/\//, 'https://');
    }
    if (portrait.startsWith('//')) {
      return `https:${portrait}`;
    }
    if (portrait.startsWith('tb.') || portrait.includes('portraith')) {
      return `https://himg.bdimg.com/sys/portraith/item/${portrait}`;
    }
    return `https://tb.himg.baidu.com/sys/portrait/item/${portrait}`;
  }

  /**
   * 获取 tbs（贴吧请求签名 token，从页面或接口获取）
   */
  async getOperationTbs(): Promise<string> {
    return this.fetchTbs();
  }

  /** 构建客户端 API 请求头（对齐 Android CommonHeaderInterceptor + OfficialTiebaApi @Headers 注解）
   * 关键：Cookie 只带 ka=open;CUID=<cuid>，绝不含 BDUSS/STOKEN——
   * BDUSS 在 form body 传递，若同时出现在 Cookie 会产生双路径校验时序竞态（错误码 1/350004）
   */
  private buildClientApiHeaders(cuid: string, userId: string): Record<string, string> {
    const headers: Record<string, string> = {
      'Accept': 'application/json',
      'User-Agent': 'bdtb for Android 12.41.7.1',
      'Cookie': `ka=open;CUID=${cuid}`,
      'cuid': cuid,
      'cuid_galaxy2': cuid,
      'cuid_gid': '',
      'client_type': '2',
      'Charset': 'UTF-8',
      'client_user_token': userId,
      'force_login': 'true',
    };
    return headers;
  }

  async addThreadCollection(tid: string, fid: string, userId: string, tbs: string, pid: string = ''): Promise<void> {
    const bduss = AuthManager.getInstance().getBduss();
    if (bduss.length === 0) {
      throw new Error('请先登录后再进行收藏操作');
    }
    if (tbs.length === 0) {
      throw new Error('tbs 未初始化，请先登录');
    }
    const stoken = await this.ensureFreshStoken();
    if (!tid || tid.trim().length === 0) {
      throw new Error('缺少帖子 tid，无法收藏');
    }
    const cuid = await this.resolveClientCuid();

    // 方案A：客户端 addstore（需 stoken）
    // v68：4 个变体顺序尝试，覆盖 fid / pid 两个假设：
    //   - rmstore(成功) form 含 fid，而 addstore data 数组缺 fid → 变体 A/B 补 fid
    //   - pid=0 是官方主帖语义（点赞注释），但参考实现传真实 postId → 变体 B/C 用真实 pid
    // 每个变体独立构造 data 与签名，带完整日志，命中任一即成功
    let clientErrInfo = '';
    if (stoken.length > 0) {
      // v68 验证结论：addstore 的 data 必须传真实首楼 pid + fid，pid=0 会被服务端拒绝(300000)。
      // 主变体为标准版(fid+realPid)，兜底保留原版(pid0)以防真实 pid 获取失败时尝试。
      const realPid = pid.length > 0 ? pid : '0';
      const vMain: CollectionData = { tid: `${tid}`, pid: `${realPid}`, status: 1 };
      if (fid.length > 0) vMain.fid = `${fid}`;
      const vFallback: CollectionData = { tid: `${tid}`, pid: '0', status: 1 };
      const dataVariants: CollectionVariant[] = [
        { label: 'B-realPid+fid', data: JSON.stringify([vMain]) },
        { label: 'D-pid0原版', data: JSON.stringify([vFallback]) },
      ];
      for (const v of dataVariants) {
        const formA: Record<string, string> = {};
        formA.BDUSS = bduss;
        formA._client_type = '2';
        formA._client_version = '12.41.7.1';
        formA.cuid = cuid;
        formA.cuid_galaxy2 = cuid;
        formA.cuid_gid = '';
        formA.from = 'tieba';
        formA.timestamp = TiebaService.clientTimestampSec();
        formA.model = 'HarmonyOS';
        formA.net_type = '1';
        formA.data = v.data;
        formA.stoken = stoken;
        formA.tbs = tbs;
        formA.sign = await this.signTiebaForm(formA);
        hilog.info(0x0000, TiebaService.TAG,
          '[收藏A] 变体[%{public}s] data=%{public}s sign=%{public}s stoken=%{public}s tbs=%{public}s cuid=%{public}s',
          v.label, v.data, formA.sign, stoken.length > 0 ? `***(${stoken.length})` : 'EMPTY',
          tbs.length > 0 ? `${tbs.substring(0, 8)}...(${tbs.length})` : 'EMPTY', cuid);
        let respA = '';
        try {
          respA = await HttpClient.postForm('https://tiebac.baidu.com/c/c/post/addstore', formA,
            this.buildClientApiHeaders(cuid, userId));
        } catch (e) {
          try {
            respA = await HttpClient.postForm('https://c.tieba.baidu.com/c/c/post/addstore', formA,
              this.buildClientApiHeaders(cuid, userId));
          } catch (e2) {
            respA = `NETWORK_ERROR: ${(e2 as Error).message}`;
          }
        }
        hilog.info(0x0000, TiebaService.TAG, '[收藏A] 变体[%{public}s] response: %{public}s',
          v.label, respA.substring(0, 400));
        console.info(`[收藏A] 变体[${v.label}] response: ${respA.substring(0, 250)}`);
        if (this.isClientApiSuccess(respA)) {
          hilog.info(0x0000, TiebaService.TAG, '[收藏A] 变体[%{public}s] 成功', v.label);
          console.info(`[收藏A] 变体[${v.label}] 成功`);
          return;
        }

        clientErrInfo = this.extractErrMsg(respA) || '客户端收藏接口返回异常';
        hilog.error(0x0000, TiebaService.TAG, '[收藏A] 变体[%{public}s] 失败: %{public}s, 原始响应=%{public}s',
          v.label, clientErrInfo, respA.substring(0, 300));
        if (clientErrInfo.includes('登录') || clientErrInfo.includes('STOKEN') ||
            clientErrInfo.includes('BDUSS') || clientErrInfo.includes('未登录') ||
            clientErrInfo.startsWith('<')) {
          throw new Error(`云端收藏失败：${clientErrInfo.startsWith('<') ? '登录态已失效' : clientErrInfo}（请尝试重新登录）`);
        }
      }
    } else {
      clientErrInfo = '当前登录态缺少 STOKEN，跳过客户端接口';
      console.info('[收藏A] 跳过，STOKEN 为空');
    }

    // 方案B：web 端点兜底（贴吧网页版收藏接口）
    // v66：使用与 fetchWebTbs 探测一致的 web Cookie，避免 Cookie 组合不匹配导致 error_no=3
    const webCookie: string = this.getWebCookie();
    if (!webCookie.includes('BDUSS=')) {
      throw new Error('云端收藏失败：当前没有有效的 BDUSS，请重新登录');
    }

    const webForm: Record<string, string> = {
      'tid': `${tid}`,
      'pid': '0',
      'fid': fid.length > 0 ? fid : 'null',
      'tbs': tbs,
      'ie': 'utf-8',
      'fr': 'index',
    };
    // web 写接口需要 web 端 tbs（dc/common/tbs），客户端 tbs 会返回 error_no:3
    let webTbs = '';
    try {
      webTbs = await this.fetchWebTbs();
    } catch (e) {
      console.error(`[收藏失败] 无法获取 web tbs，回退显示客户端错误: ${clientErrInfo}`);
      if (stoken.length === 0) {
        throw new Error('云端收藏失败：登录态缺少 STOKEN（收藏必需），且网页端点登录校验失败。请到"我的"页面重新登录后重试');
      }
      throw new Error(`云端收藏失败：${clientErrInfo}（请尝试重新登录）`);
    }
    if (webTbs.length > 0) {
      webForm['tbs'] = webTbs;
    }
    const webHeaders: Record<string, string> = {
      'Cookie': webCookie,
      'User-Agent': TiebaService.DESKTOP_UA,
      'Accept': 'application/json, text/javascript, */*; q=0.01',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'X-Requested-With': 'XMLHttpRequest',
      'Referer': `https://tieba.baidu.com/p/${tid}`,
      'Origin': 'https://tieba.baidu.com',
      'Host': 'tieba.baidu.com',
    };
    let webResp = '';
    try {
      webResp = await HttpClient.postForm('https://tieba.baidu.com/i/submit/open_storethread', webForm, webHeaders);
    } catch (e) {
      webResp = `NETWORK_ERROR: ${(e as Error).message}`;
    }
    hilog.info(0x0000, TiebaService.TAG, '[收藏B-web] response: %{public}s', webResp.substring(0, 500));
    console.info(`[收藏B-web] response: ${webResp.substring(0, 300)}`);
    if (this.isWebWriteSuccess(webResp)) {
      hilog.info(0x0000, TiebaService.TAG, '[收藏B-web] 成功');
      console.info('[收藏B-web] 成功');
      return;
    }

    const webErrInfo: string = this.extractWebWriteError(webResp) || '服务端无明确返回';
    console.error(`[收藏失败] web端点错误: ${webErrInfo}, STOKEN可用: ${stoken.length > 0}, BDUSS前16位: ${bduss.substring(0, 16)}`);
    if (stoken.length === 0) {
      throw new Error(`云端收藏失败：${webErrInfo.substring(0, 80)}。登录态缺少 STOKEN，请到"我的"页面重新登录后重试`);
    }
    throw new Error(`云端收藏失败：${webErrInfo.substring(0, 80)}（请尝试重新登录）`);
  }

  /** 检查客户端API响应是否成功（支持多种错误码字段格式） */
  private isClientApiSuccess(response: string): boolean {
    if (response.startsWith('NETWORK_ERROR:') || response.startsWith('<')) {
      return false;
    }
    try {
      const payload = JSON.parse(response) as Record<string, Object>;
      // 检查顶层错误码（兼容 error_code/errno/no/error_no 多套格式）
      const code: number = this.readNumber(payload, ['error_code', 'errno', 'no', 'error_no']);
      if (code !== 0) {
        return false;
      }
      // 顶层无错误码（readNumber 返回 0）时，还需检查嵌套 error 对象，
      // 避免 {"error": {"errno": 1}} 这类失败响应被静默当成成功
      const errorObj: Object | undefined = payload.error;
      if (errorObj !== undefined && typeof errorObj === 'object') {
        const nestedCode: number = this.readNumber(errorObj as Record<string, Object>, ['errno', 'error_code', 'no', 'error_no']);
        return nestedCode === 0;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  private extractErrMsg(response: string): string {
    try {
      if (response.startsWith('NETWORK_ERROR:')) {
        return response;
      }
      const payload = JSON.parse(response) as Record<string, Object>;
      let errMsg: string = `${payload.error_msg ?? payload.errmsg ?? ''}`;
      // 若顶层无错误信息，尝试从嵌套 error 对象中提取（addstore/rmstore 常见格式）
      if (errMsg.length === 0 && payload.error !== undefined) {
        if (typeof payload.error === 'string') {
          errMsg = payload.error;
        } else if (typeof payload.error === 'object') {
          const nested = payload.error as Record<string, Object>;
          errMsg = `${nested.error_msg ?? nested.errmsg ?? nested.error ?? ''}`;
        }
      }
      if (errMsg.length > 0) {
        return errMsg;
      }
      const errNo: number = Number(payload.errno ?? payload.no ?? payload.error_no ?? -1);
      return errNo !== 0 ? `errno=${errNo}` : '';
    } catch (e) {
      return response.substring(0, 100);
    }
  }

  async removeThreadCollection(tid: string, fid: string, userId: string, tbs: string): Promise<void> {
    const bduss = AuthManager.getInstance().getBduss();
    if (bduss.length === 0) {
      throw new Error('请先登录后再取消收藏');
    }
    const stoken = await this.ensureFreshStoken();
    if (tbs.length === 0) {
      throw new Error('tbs 未初始化，请先登录');
    }
    const cuid = await this.resolveClientCuid();

    // 方案A：client rmstore（需 stoken）
    if (stoken.length > 0) {
      const form: Record<string, string> = {};
      form.BDUSS = bduss;
      form._client_type = '2';
      form._client_version = '12.41.7.1';
      form.cuid = cuid;
      form.cuid_galaxy2 = cuid;
      form.cuid_gid = '';
      form.from = 'tieba';
      form.timestamp = TiebaService.clientTimestampSec();
      form.model = 'HarmonyOS';
      form.net_type = '1';
      form.tid = tid;
      form.fid = fid.length > 0 ? fid : 'null';
      form.tbs = tbs;
      form.stoken = stoken;
      form.user_id = userId;
      form.sign = await this.signTiebaForm(form);
      let respA = '';
      // 域名对齐 aiotieba（APP_BASE_HOST=tiebac.baidu.com）：与 addstore 一致，
      // 新域名校验更宽松，先试新域名，网络失败时回退旧域名
      try {
        respA = await HttpClient.postForm('https://tiebac.baidu.com/c/c/post/rmstore', form,
          this.buildClientApiHeaders(cuid, userId));
      } catch (e) {
        try {
          respA = await HttpClient.postForm('https://c.tieba.baidu.com/c/c/post/rmstore', form,
            this.buildClientApiHeaders(cuid, userId));
        } catch (e2) {
          respA = `NETWORK_ERROR: ${(e2 as Error).message}`;
        }
      }
      console.info(`[取消收藏A] response: ${respA.substring(0, 300)}`);
      if (this.isClientApiSuccess(respA)) {
        console.info('[取消收藏A] 成功');
        return;
      }
    }

    // 方案B：web 端点（贴吧网页版取消收藏接口）
    // v66：使用与 fetchWebTbs 探测一致的 web Cookie
    const webCookie: string = this.getWebCookie();
    if (!webCookie.includes('BDUSS=')) {
      throw new Error('云端取消收藏失败：当前没有有效的 BDUSS，请重新登录');
    }

    const webForm: Record<string, string> = {
      'tid': `${tid}`,
      'fid': fid.length > 0 ? fid : 'null',
      'tbs': tbs,
      'ie': 'utf-8',
    };
    // v62：web 写接口需要 web 端 tbs（dc/common/tbs）
    const webTbs2: string = await this.fetchWebTbs();
    if (webTbs2.length > 0) {
      webForm['tbs'] = webTbs2;
    }
    // v65：web 端点不再传递 stoken，避免 passport 域 STOKEN 导致鉴权失败
    const webHeaders: Record<string, string> = {
      'Cookie': webCookie,
      'User-Agent': TiebaService.DESKTOP_UA,
      'Accept': 'application/json, text/javascript, */*; q=0.01',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'X-Requested-With': 'XMLHttpRequest',
      'Referer': `https://tieba.baidu.com/p/${tid}`,
      'Origin': 'https://tieba.baidu.com',
      'Host': 'tieba.baidu.com',
    };
    let webResp = '';
    try {
      webResp = await HttpClient.postForm('https://tieba.baidu.com/i/submit/cancel_storethread', webForm, webHeaders);
    } catch (e) {
      webResp = `NETWORK_ERROR: ${(e as Error).message}`;
    }
    console.info(`[取消收藏B-web] response: ${webResp.substring(0, 300)}`);
    if (this.isWebWriteSuccess(webResp)) {
      console.info('[取消收藏B-web] 成功');
      return;
    }
    const errInfo: string = this.extractWebWriteError(webResp) || webResp.substring(0, 100);
    throw new Error(`云端取消收藏失败：${errInfo.substring(0, 80)}（请尝试重新登录）`);
  }

  /**
   * 批量取消收藏（收藏页编辑态删除）：
   * 按吧名解析一次 fid，逐帖走 removeThreadCollection，返回失败 tid 列表。
   */
  async removeThreadCollections(forumName: string, tids: string[], userId: string, tbs: string): Promise<string[]> {
    const failed: string[] = [];
    if (tids.length === 0) {
      return failed;
    }
    let fid = '';
    try {
      fid = await this.resolveForumId(forumName, '');
    } catch (e) {
      // fid 解析失败时回退空 fid（rmstore 会用 'null' 兜底，可能失败，由结果统计决定）
      fid = '';
    }
    for (const tid of tids) {
      try {
        await this.removeThreadCollection(tid, fid, userId, tbs);
      } catch (e) {
        failed.push(tid);
      }
    }
    return failed;
  }

  private assertWriteSuccess(response: string, fallback: string): void {
    try {
      const payload = JSON.parse(response) as Record<string, Object>;
      // 先检查顶层 error_code，再检查嵌套 error.error_code（贴吧 write 接口常见格式）
      const code: number = this.readNumber(payload, ['error_code', 'errno', 'no']);
      if (code !== 0) throw new Error(this.readString(payload, ['error_msg', 'errmsg', 'error']) || fallback);
      // 部分 write 接口（addstore/rmstore）成功时 error_code=0，但嵌套 error 对象中有 errno
      const errorObj: Object | undefined = payload.error;
      if (errorObj !== undefined && typeof errorObj === 'object') {
        const nestedCode: number = this.readNumber(errorObj as Record<string, Object>, ['errno', 'error_code', 'no']);
        if (nestedCode !== 0) {
          throw new Error(this.readString(errorObj as Record<string, Object>, ['errmsg', 'error_msg', 'error']) || fallback);
        }
      }
    } catch (e) {
      const message: string = (e as Error).message ?? '';
      throw new Error(message.length > 0 ? message : fallback);
    }
  }

  /** 获取 web 端 tbs（tieba.baidu.com/dc/common/tbs）
   * v62 新增：web 写接口（open_storethread/cancel_storethread）校验的是 web tbs，
   * 与客户端 /c/s/login 的 tbs 不同源，混用会返回 error_no:3
   */
  private webTbsCache: string = '';
  private webTbsAt: number = 0;
  private webCookieCache: string = '';
  private webCookieAt: number = 0;

  /**
   * 尝试用指定 Cookie 获取 web 端 tbs。
   * 返回 tbs 仅当 is_login=1；否则返回空字符串（不抛错，用于候选探测）。
   */
  private async tryFetchWebTbsWithCookie(cookie: string): Promise<string> {
    if (!cookie.includes('BDUSS=')) {
      return '';
    }
    try {
      const resp: string = await HttpClient.get('https://tieba.baidu.com/dc/common/tbs', {
        'Cookie': cookie,
        'User-Agent': TiebaService.DESKTOP_UA,
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Referer': 'https://tieba.baidu.com/',
      });
      const payload = JSON.parse(resp) as Record<string, Object>;
      const tbs: string = this.readString(payload, ['tbs']);
      const isLogin: number = this.readNumber(payload, ['is_login']);
      console.info(`[webTbs] cookie=${cookie.substring(0, 30)}... tbs=${tbs.substring(0, 8)}... is_login=${isLogin}`);
      if (tbs.length > 0 && isLogin === 1) {
        this.webTbsCache = tbs;
        this.webTbsAt = Date.now();
        this.webCookieCache = cookie;
        this.webCookieAt = Date.now();
        return tbs;
      }
    } catch (e) {
      console.warn(`[webTbs] 探测失败: ${(e as Error).message.substring(0, 60)}`);
    }
    return '';
  }

  /**
   * 探测可用的 web 端 Cookie。
   * 不同账号/环境下，dc/common/tbs 对 STOKEN/BAIDUID/TIEBAUID 要求不同，逐个尝试。
   */
  private async probeWebCookie(): Promise<string> {
    if (this.webCookieCache.length > 0 && Date.now() - this.webCookieAt < 5 * 60 * 1000) {
      const tbs = await this.tryFetchWebTbsWithCookie(this.webCookieCache);
      if (tbs.length > 0) {
        return tbs;
      }
    }

    const base = this.normalizeWebCookie(AuthManager.getInstance().getCookieHeader());
    const variants: string[] = [
      base,
      this.stripCookieKeys(base, ['STOKEN']),
      this.stripCookieKeys(base, ['STOKEN', 'TIEBAUID']),
      this.stripCookieKeys(base, ['STOKEN', 'TIEBAUID', 'BAIDUID']),
    ];

    for (let i = 0; i < variants.length; i++) {
      const cookie = variants[i];
      if (!cookie.includes('BDUSS=')) {
        continue;
      }
      console.info(`[webTbs] 探测方案 ${i + 1}/${variants.length}: ${cookie.substring(0, 40)}...`);
      const tbs = await this.tryFetchWebTbsWithCookie(cookie);
      if (tbs.length > 0) {
        return tbs;
      }
    }
    return '';
  }

  async fetchWebTbs(): Promise<string> {
    if (this.webTbsCache.length > 0 && Date.now() - this.webTbsAt < 5 * 60 * 1000) {
      return this.webTbsCache;
    }

    let tbs = await this.probeWebCookie();
    if (tbs.length > 0) {
      return tbs;
    }

    console.warn('[webTbs] 首次探测失败，尝试刷新 STOKEN');
    try {
      await this.refreshStoken();
      tbs = await this.probeWebCookie();
      if (tbs.length > 0) {
        return tbs;
      }
    } catch (e) {
      console.warn(`[webTbs] 刷新 STOKEN 失败: ${(e as Error).message.substring(0, 60)}`);
    }

    throw new Error('获取 web 端 tbs 失败，请尝试重新登录');
  }

  /** 返回当前可用于 web 写接口的 Cookie（与 fetchWebTbs 探测结果一致） */
  private getWebCookie(): string {
    if (this.webCookieCache.length > 0 && Date.now() - this.webCookieAt < 5 * 60 * 1000) {
      return this.webCookieCache;
    }
    return this.normalizeWebCookie(AuthManager.getInstance().getCookieHeader());
  }

  /** 判断 web 写接口响应是否成功（兼容 error_no / errno / no / error_code / is_done） */
  private isWebWriteSuccess(resp: string): boolean {
    if (resp.startsWith('NETWORK_ERROR:') || resp.startsWith('<')) {
      return false;
    }
    try {
      const payload = JSON.parse(resp) as Record<string, Object>;
      const errorNo: number = this.readNumber(payload, ['error_no', 'errno', 'no', 'error_code']);
      if (errorNo === 0) {
        return true;
      }
      const isDone: Object | undefined = payload['is_done'];
      if (isDone === true || isDone === 'true') {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /** 提取 web 写接口错误信息（error_no + _info/msg） */
  private extractWebWriteError(resp: string): string {
    try {
      if (resp.startsWith('NETWORK_ERROR:')) {
        return resp;
      }
      // issue#69：网页端返回 HTML（登录页/拦截页）时不再把原始 HTML 抛给 UI
      if (resp.trim().startsWith('<')) {
        return '服务端返回了网页内容，登录态可能已失效';
      }
      const payload = JSON.parse(resp) as Record<string, Object>;
      const errorNo: number = this.readNumber(payload, ['error_no', 'errno', 'no', 'error_code']);
      const info: string = this.readString(payload, ['_info', 'error_msg', 'errmsg', 'error']);
      if (errorNo === 3 && info.length === 0) {
        return 'error_no=3(tbs/登录态校验失败，请重新登录)';
      }
      if (errorNo !== 0 || info.length > 0) {
        return `error_no=${errorNo}${info.length > 0 ? `(${info})` : ''}`;
      }
      return '';
    } catch (e) {
      return resp.substring(0, 100);
    }
  }

  /**
   * 规范化 web 端 Cookie：保留 BDUSS、STOKEN、BAIDUID、TIEBAUID 且每个 key 只取第一次出现
   * 避免 AuthManager 中累积多个 STOKEN/BAIDUID（尤其是 passport 域）导致服务端鉴权混乱
   */
  private normalizeWebCookie(rawCookie: string): string {
    const keys = ['BDUSS', 'STOKEN', 'BAIDUID', 'TIEBAUID'];
    const result: string[] = [];
    const seen = new Set<string>();
    const pairs = rawCookie.split(';');
    for (const pair of pairs) {
      const trimmed = pair.trim();
      if (trimmed.length === 0) {
        continue;
      }
      const eqIdx = trimmed.indexOf('=');
      const key = eqIdx >= 0 ? trimmed.substring(0, eqIdx).trim() : trimmed;
      const value = eqIdx >= 0 ? trimmed.substring(eqIdx + 1).trim() : '';
      if (!keys.includes(key) || seen.has(key)) {
        continue;
      }
      seen.add(key);
      result.push(`${key}=${value}`);
    }
    return result.join('; ');
  }

  /** 从已规范化 Cookie 中移除指定 key */
  private stripCookieKeys(cookie: string, removeKeys: string[]): string {
    const result: string[] = [];
    const pairs = cookie.split(';');
    for (const pair of pairs) {
      const trimmed = pair.trim();
      if (trimmed.length === 0) {
        continue;
      }
      const eqIdx = trimmed.indexOf('=');
      const key = eqIdx >= 0 ? trimmed.substring(0, eqIdx).trim() : trimmed;
      if (!removeKeys.includes(key)) {
        result.push(trimmed);
      }
    }
    return result.join('; ');
  }

  // ============ 签到 ============

  /**
   * 单吧签到。
   * 表单核心参数 kw + tbs；带 fid 时一并提交（对齐贴吧 Lite 单吧签到，服务端优先按 fid 定位吧，
   * 避免同名/改名吧歧义）。sign 为「全部参数按 key 排序拼接 + tiebaclient!!!」的 MD5，
   * 不带 fid 时与旧实现 MD5(kw=..tbs=..tiebaclient!!!) 完全一致。
   */
  async signForum(kw: string, forumId?: string): Promise<SignForumResult> {
    const tbs = await this.fetchTbs();

    // 单吧签到固定签名：按 key 升序只取 kw + tbs，追加密钥后取大写 MD5。
    // 此前改为 signTiebaForm（小写 MD5）并带入 fid 后服务端报签名错误，故恢复历史签名方式。
    const signStr = `kw=${kw}tbs=${tbs}tiebaclient!!!`;
    const sign = await HttpClient.md5(signStr);

    // 构建签到请求参数
    const form: Record<string, string> = {};
    form['kw'] = kw;
    form['tbs'] = tbs;
    form['sign'] = sign;

    // 构建请求头
    const headers: Record<string, string> = {};
    headers['Accept'] = 'application/json, text/plain, */*';
    headers['User-Agent'] = 'tieba/12.41.7.1';
    headers['Referer'] = `${TIEBA_BASE}/`;

    console.info(`[SIGN] kw=${kw} fid=${forumId ?? ''}`);
    const response = await HttpClient.postForm('https://c.tieba.baidu.com/c/c/forum/sign', form, headers);
    try {
      const payload = JSON.parse(response) as Record<string, Object>;
      const errorCode: number = this.readNumber(payload, ['error_code', 'errno', 'no']);
      // 160002：服务端返回「已经签过」，属于已完成状态，不按失败处理
      if (errorCode === 160002) {
        console.info(`[SIGN] already signed kw=${kw}`);
        return { signDays: 0, bonusNum: 0 };
      }
      if (errorCode !== 0) {
        const errMsg = this.readString(payload, ['error_msg', 'errmsg', 'error']) || '签到失败';
        console.warn(`[SIGN] fail kw=${kw} code=${errorCode} msg=${errMsg}`);
        throw new Error(errMsg);
      }
      const signBonus: number = this.readNumber(payload, ['sign_bonus_num', 'signBonusNum']);
      let signDays: number = 0;
      const userSign = payload['user_sign'] as Record<string, Object> | undefined;
      if (userSign) {
        signDays = this.readNumber(userSign, ['sign_days', 'signDays', 'continuous_sign_days', 'continuousSignDays']);
        if (signDays === 0) {
          signDays = this.readNumber(userSign, ['bubble_num', 'bubbleNum']);
        }
      }
      // 尝试从 user_info 中获取签到信息
      const userInfo = payload['user_info'] as Record<string, Object> | undefined;
      if (userInfo && signDays === 0) {
        signDays = this.readNumber(userInfo, ['user_sign_days', 'userSignDays', 'sign_days']);
      }
      const result: SignForumResult = { signDays, bonusNum: signBonus };
      return result;
    } catch (e) {
      const message: string = (e as Error).message ?? '';
      if (message.length > 0) {
        throw new Error(message);
      }
      throw new Error('签到响应解析失败');
    }
  }

  /** 秒级等待（逐吧签到间隔 / 分页拉取间隔用） */
  private async delayMs(ms: number): Promise<void> {
    await new Promise<void>((resolve: () => void) => {
      setTimeout(() => {
        resolve();
      }, ms);
    });
  }

  /** 官方一键签到单批 id 上限：参考实现一次提交全部，这里切批以降低单请求失败的影响面 */
  private static readonly MSIGN_BATCH_SIZE: number = 200;

  /**
   * 官方「一键签到」（一次请求让服务端批量签到多个吧）。
   * 对齐贴吧 Lite（HuanCheng65/TiebaLite 4.0-dev · OfficialTiebaApi.mSignFlow /
   * TbMiniApiImpl）：POST 客户端接口 c/c/forum/msign，
   *   form：BDUSS + forum_ids（逗号分隔 fid 列表）+ tbs + _client_version + authsid + stoken + user_id + sign
   *   响应 info[]：{ forum_id, forum_name, signed }，signed === '1' 表示服务端已完成签到。
   * 返回「官方已完成签到」的吧 id 列表；其余 id 由调用方逐吧签到兜底。
   * 单批失败不影响整体：该批全部回落到逐吧签到。
   */
  async signForumsOfficial(forumIds: string[]): Promise<string[]> {
    const ids: string[] = [];
    for (const raw of forumIds) {
      const id: string = (raw ?? '').trim();
      if (id.length > 0 && !ids.includes(id)) {
        ids.push(id);
      }
    }
    if (ids.length === 0) {
      return [];
    }
    const tbs: string = await this.fetchTbs();
    let stoken: string = '';
    try {
      stoken = await this.ensureFreshStoken();
    } catch (e) {
      stoken = '';
    }
    const user = AuthManager.getInstance().getUser();
    const userId: string = user?.userId ?? '';
    const signedIds: string[] = [];
    const batchSize: number = TiebaService.MSIGN_BATCH_SIZE;
    for (let start = 0; start < ids.length; start += batchSize) {
      const chunk: string[] = ids.slice(start, start + batchSize);
      const form: Record<string, string> = {
        'BDUSS': AuthManager.getInstance().getBduss(),
        'forum_ids': chunk.join(','),
        'tbs': tbs,
        '_client_version': '11.10.8.6',
        'authsid': 'null',
      };
      if (stoken.length > 0) {
        form['stoken'] = stoken;
      }
      if (userId.length > 0) {
        form['user_id'] = userId;
      }
      form['sign'] = await this.signTiebaForm(form);
      try {
        const resp: string = await HttpClient.postForm(API.FORUM_MSIGN, form, {
          'Accept': 'application/json, text/plain, */*',
          'User-Agent': 'tieba/11.10.8.6',
          'Referer': `${TIEBA_BASE}/`,
        });
        const payload: Record<string, Object> = JSON.parse(resp) as Record<string, Object>;
        const msignErrCode: number = this.readNumber(payload, ['error_code', 'errno', 'no']);
        if (msignErrCode !== 0) {
          const msignErrMsg: string = this.readString(payload, ['error_msg', 'errmsg', 'error']) || `error_code=${msignErrCode}`;
          console.warn(`[MSIGN] fail code=${msignErrCode} msg=${msignErrMsg}`);
        }
        let infoList: Object[] | undefined = payload['info'] as Object[] | undefined;
        if (infoList === undefined || infoList === null) {
          const data = payload['data'] as Record<string, Object> | undefined;
          if (data !== undefined && data !== null) {
            infoList = data['info'] as Object[] | undefined;
          }
        }
        if (infoList === undefined || infoList === null) {
          console.warn(`[MSIGN] 响应缺少 info 列表，本批 ${chunk.length} 个吧回落逐吧签到`);
        } else {
          for (const raw of infoList) {
            const item = raw as Record<string, Object>;
            const id: string = `${item['forum_id'] ?? item['forumId'] ?? ''}`.trim();
            if (id.length === 0) {
              continue;
            }
            // signed === '1'：服务端已代为签到（含今日此前已签到）
            if (`${item['signed'] ?? ''}` === '1') {
              signedIds.push(id);
            }
          }
          console.info(`[MSIGN] 本批 ${chunk.length} 个吧，服务端完成 ${signedIds.length}`);
        }
      } catch (e) {
        console.warn(`[MSIGN] 本批 ${chunk.length} 个吧请求失败，回落逐吧签到: ${(e as Error).message}`);
      }
      if (start + batchSize < ids.length) {
        await this.delayMs(300);
      }
    }
    return signedIds;
  }

  /**
   * 一键签到专用：拉取「我关注的吧」全量列表（只走客户端接口，含 forumId / isSign，
   * 分页直到没有更多为止）。与 fetchFollowList 的区别是不再为头像额外请求 HTML 页，
   * 一次签到流程只需少量请求；页间小间隔避免连续请求被风控。
   */
  async fetchAllFollowedForums(): Promise<FollowItem[]> {
    const user = AuthManager.getInstance().getUser();
    const all: FollowItem[] = [];
    const seen: Set<string> = new Set<string>();
    const pageSize: number = 50;
    const maxPage: number = 20;
    for (let page = 1; page <= maxPage; page++) {
      const payload: ModernApiPayload = await this.requestModernApi(API.USER_LIKE_FORUM, {
        page_no: `${page}`,
        page_size: `${pageSize}`,
        uid: user?.userId ?? '',
        friend_uid: '',
        is_guest: user ? '0' : '1',
        _client_version: '11.10.8.6',
        client_type: '2',
        _os_version: '26',
        _client_type: '2',
      });
      const result: PagedResult<FollowItem> = this.parseModernFollowList(payload, page);
      let added: number = 0;
      for (const item of result.list) {
        if (seen.has(item.forumName)) {
          continue;
        }
        seen.add(item.forumName);
        all.push(item);
        added++;
      }
      console.info(`[AUTOSIGN] 关注吧第 ${page} 页新增 ${added} 个，累计 ${all.length} 个，hasMore=${result.hasMore}`);
      if (!result.hasMore || added === 0) {
        break;
      }
      await this.delayMs(200);
    }
    return all;
  }

  /**
   * 返回对齐服务器时间的秒级时间戳字符串。
   * 贴吧客户端 API 的 timestamp 参数必须是秒级 Unix 时间戳，且需接近服务器时间，
   * 否则服务端校验失败并返回"未知错误"（历史 bug：addstore/rmstore 曾误用毫秒值）。
   */
  private static clientTimestampSec(): string {
    return `${Math.floor((Date.now() + TiebaService.serverTimeOffsetMs) / 1000)}`;
  }

  private async fetchTbs(): Promise<string> {
    // 对齐 aiotieba pack_form_request：先注入公共参数到 form body，再计算 sign
    // 公共参数参与签名，BDUSS 同时在 form body 和 Cookie header 中传递
    const bduss: string = AuthManager.getInstance().getBduss();
    console.info(`[TBS] BDUSS length: ${bduss.length}`);

    if (bduss.length > 0) {
      const cuid = await this.resolveClientCuid();
      // 对齐 aiotieba CommonParamInterceptor：完整公共参数
      const form: Record<string, string> = {
        'BDUSS': bduss,
        '_client_type': '2',
        '_client_version': '12.41.7.1',
        'cuid': cuid,
        'cuid_galaxy2': cuid,
        'from': '1008621y',
        'model': 'HarmonyOS',
        'net_type': '1',
        'timestamp': TiebaService.clientTimestampSec(),
        'bdusstoken': bduss,
      };
      // sign 必须包含所有公共参数（对齐 aiotieba pack_form_request 行为）
      form['sign'] = await this.signTiebaForm(form);
      console.info(`[TBS] /c/s/login form keys: ${Object.keys(form).join(',')}`);

      let loginResponse: string = '';
      try {
        loginResponse = await HttpClient.postForm('https://c.tieba.baidu.com/c/s/login', form, {
          'Accept': 'application/json, text/plain, */*',
          'User-Agent': 'bdtb for Android 12.41.7.1',
        });
        console.info(`[TBS] /c/s/login response: ${loginResponse.substring(0, 300)}`);
      } catch (e) {
        console.error(`[TBS] /c/s/login network error: ${(e as Error).message}`);
      }

      if (loginResponse.length > 0) {
        try {
          const loginPayload = JSON.parse(loginResponse) as Record<string, Object>;
          const loginErrorCode: string = `${loginPayload.error_code ?? '0'}`;
          console.info(`[TBS] /c/s/login error_code: ${loginErrorCode}`);

          if (loginErrorCode === '0') {
            // 校准服务器时间：time 为秒级服务器时间戳，偏移 = 服务器时间 - 本地时间
            const serverTimeSec: number = this.readNumber(loginPayload, ['time', 'server_time']);
            if (serverTimeSec > 0) {
              TiebaService.serverTimeOffsetMs = serverTimeSec * 1000 - Date.now();
              console.info(`[TBS] 服务器时间对齐: offset=${TiebaService.serverTimeOffsetMs}ms`);
            }
            const antiValue: Object | undefined = loginPayload.anti;
            if (antiValue !== undefined && typeof antiValue === 'object') {
              const clientTbs: string = this.readString(antiValue as Record<string, Object>, ['tbs']);
              if (clientTbs.length > 0) {
                console.info(`[TBS] Got valid tbs from /c/s/login`);
                return clientTbs;
              }
            }
          }
          const errorMsg = this.readString(loginPayload, ['error_msg', 'errmsg', 'error']) || `error_code=${loginErrorCode}`;
          throw new Error(`登录凭证获取失败: ${errorMsg}`);
        } catch (e) {
          const err: Error = e as Error;
          if (err.message.includes('登录凭证获取失败') || err.message.includes('BDUSS 已失效')) {
            throw err;
          }
          console.error(`[TBS] /c/s/login parse error: ${err.message}`);
          throw new Error(`登录凭证解析失败: ${err.message}`);
        }
      }
      throw new Error('登录凭证网络请求失败，请检查网络连接');
    }

    throw new Error('未登录，请先登录后再进行操作');
  }

  // ============ HTML 解析 ============

  private parseHomeThreads(html: string, page: number): PagedResult<ThreadItem> {
    const list: ThreadItem[] = [];
    // 首页信息流：帖子条目在 <li class="tl_shadow"> 或包含 data-field 的 a 标签
    const itemRegex = /<li[^>]*class="[^"]*tl_shadow[^"]*"[\s\S]*?<\/li>/gi;
    let m = itemRegex.exec(html);
    while (m !== null) {
      const block = m[0];
      const item = this.parseThreadBlock(block);
      if (item.tid) {
        list.push(item);
      }
      m = itemRegex.exec(html);
    }
    // 兜底：解析所有带 data-field 的帖子链接
    if (list.length === 0) {
      const linkRegex = /<a[^>]*href="\/p\/(\d+)[^"]*"[^>]*>([\s\S]*?)<\/a>/gi;
      let l = linkRegex.exec(html);
      while (l !== null) {
        list.push({
          tid: l[1],
          postId: '0',
          title: stripHtml(l[2]),
          forumName: '',
          author: '',
          replyNum: 0,
          abstract: '',
          createTime: '',
          isTop: false,
        });
        l = linkRegex.exec(html);
      }
    }
    return { list, hasMore: list.length > 0, page };
  }

  private parseForumThreads(html: string, forumName: string, page: number): PagedResult<ThreadItem> {
    const list: ThreadItem[] = [];
    // 贴吧列表项：<li class=" j_thread_list ...">
    const itemRegex = /<li[^>]*class="[^"]*j_thread_list[^"]*"[^>]*>[\s\S]*?<\/li>/gi;
    let m = itemRegex.exec(html);
    while (m !== null) {
      const block = m[0];
      const tid = extractGroup(block, /href="\/p\/(\d+)"/i);
      const title = stripHtml(extractGroup(block, /class="j_th_tit[^"]*"[^>]*>[\s\S]*?<a[^>]*>([\s\S]*?)<\/a>/i)
        || extractGroup(block, /<a[^>]*class="[^"]*j_th_tit[^"]*"[^>]*>([\s\S]*?)<\/a>/i));
      const author = stripHtml(extractGroup(block, /class="tb_icon_author[^"]*"[^>]*>([^<]+)</i)
        || extractGroup(block, /<span[^>]*class="frs-author-name[^"]*"[^>]*>([^<]+)<\/span>/i));
      const replyStr = stripHtml(extractGroup(block, /class="threadlist_rep_num[^"]*"[^>]*>([^<]+)</i));
      const firstImage = extractImages(block)[0];
      const abstract = stripHtml(extractGroup(block, /class="threadlist_abs[^"]*"[^>]*>([\s\S]*?)<\/div>/i));
      const isTop = block.includes('icon-top') || block.includes('置顶');
      const isGood = block.includes('icon-good') || block.includes('icon-jing') || block.includes('精华') || block.includes('精品');
      list.push({
        tid,
        postId: '0',
        title,
        forumName,
        author,
        replyNum: parseInt(replyStr, 10) || 0,
        abstract,
        firstImage,
        createTime: '',
        isTop,
        isGood,
        isFeatured: isGood,
      });
      m = itemRegex.exec(html);
    }
    return { list, hasMore: list.length >= 40, page };
  }

  private parseThreadBlock(block: string): ThreadItem {
    const tid = extractGroup(block, /href="\/p\/(\d+)"/i);
    const title = stripHtml(extractGroup(block, /<a[^>]*class="[^"]*j_th_tit[^"]*"[^>]*>([\s\S]*?)<\/a>/i)
      || extractGroup(block, /title="([^"]+)"/i));
    const forumName = stripHtml(extractGroup(block, /href="\/f\?kw=[^"]*"[^>]*>([^<]+)</i));
    const author = stripHtml(extractGroup(block, /<a[^>]*class="[^"]*frs-author-name[^"]*"[^>]*>([^<]+)</i));
    const replyStr = stripHtml(extractGroup(block, /class="[^"]*threadlist_rep_num[^"]*"[^>]*>([^<]+)</i));
    const firstImage = extractImages(block)[0];
    const abstract = stripHtml(extractGroup(block, /class="[^"]*threadlist_abs[^"]*"[^>]*>([\s\S]*?)<\/div>/i));
    return {
      tid,
      postId: '0',
      title: title || tid,
      forumName,
      author,
      replyNum: parseInt(replyStr, 10) || 0,
      abstract,
      firstImage,
      createTime: '',
      isTop: block.includes('置顶'),
    };
  }

  private parseThreadDetail(html: string, tid: string, page: number): ThreadDetailResult {
    // 标题
    const title = stripHtml(extractGroup(html, /<h1[^>]*class="[^"]*core_title_txt[^"]*"[^>]*>([\s\S]*?)<\/h1>/i)
      || extractGroup(html, /<title>([\s\S]*?)<\/title>/i));
    const forumName = stripHtml(extractGroup(html, /class=["'][^"']*card_title_fname[^"']*["'][^>]*>([^<]+)</i)
      || extractGroup(html, /(?:forum_name|fname)["'=：:]\s*["']?([^"'<&\s]+)/i));
    const forumAvatar = this.extractForumAvatarFromHtml(html);
    const author = this.extractWebAuthor(html);
    const authorAvatar = this.extractWebAvatar(html);
    const totalPage = parseInt(extractGroup(html, /class="[^"]*l_reply_num[^"]*"[^>]*>[\s\S]*?<span[^>]*>(\d+)<\/span>/i), 10)
      || parseInt(extractGroup(html, /total_pages["']?\s*:\s*(\d+)/i), 10) || 1;

    // 首楼内容
    const firstContentHtml = extractGroup(html, /<div[^>]*class="d_post_content[^"]*"[^>]*>([\s\S]*?)<\/div>/i);
    const contentText = stripHtml(firstContentHtml);
    const images = extractImages(firstContentHtml);

    // 楼层
    const floors: FloorItem[] = [];
    const floorRegex = /<div[^>]*class="[^"]*l_post[^"]*"[^>]*>[\s\S]*?<\/div>\s*<\/div>/gi;
    let fm = floorRegex.exec(html);
    let floorIdx = 1;
    const webPageOffset = page > 1 ? (page - 1) * 30 : 0;
    while (fm !== null) {
      const block = fm[0];
      const floorAuthor = this.extractWebAuthor(block);
      const floorContent = stripHtml(extractGroup(block, /class=["'][^"']*d_post_content[^"']*["'][^>]*>([\s\S]*?)<\/div>/i));
      const floorImages = extractImages(extractGroup(block, /class=["'][^"']*d_post_content[^"']*["'][^>]*>([\s\S]*?)<\/div>/i));
      const floorId = extractGroup(block, /data-field=["'][^"']*["'][^>]*["']?post_no["']?\s*[:：]\s*["']?(\d+)/i)
        || extractGroup(block, /(?:post_no|postNo|floor_id|floorId)["'=：:]\s*["']?(\d+)/i)
        || extractGroup(block, /id=["']post_content_(\d+)["']/i);
      if (floorAuthor || floorContent) {
        const rawLike = extractGroup(block, /(?:postAgreeNum|post_agree_num|agree_count|agreeCount|like_num|likeNum|post_like_count)["'=：:]\s*["']?(\d+)/i)
          || extractGroup(block, /["'](?:postAgreeNum|post_agree_num|agree_count|agreeCount|like_num|likeNum)["']\s*:\s*["']?(\d+)/i)
          || extractGroup(block, /data-agree=["'](\d+)["']/i)
          || extractGroup(block, /class=["'][^"']*j_agree_num[^"']*["'][^>]*>(\d+)</i)
          || extractGroup(block, /(?:d_like|d_like_btn|post_like)[\s\S]{0,200}?(\d+)[\s\S]{0,100}?<\/(?:span|a|div)>/i);
        const rawAgreeStatus = extractGroup(block, /(?:hasAgree|has_agree|liked|is_liked|agree_state)["'=：:]\s*["']?(\d+)/i)
          || extractGroup(block, /class=["'][^"']*(?:j_agree|j_digg|j_like)[^"']*has_agree[^"']*["']/i) !== '' ? '1' : '';
        floors.push({
          floorId: floorId || `web-floor-${floorIdx}`,
          floor: parseInt(extractGroup(block, /(?:floor|lou|楼层)["'=：:]\s*["']?(\d+)/i), 10) || webPageOffset + floorIdx,
          author: floorAuthor,
          authorAvatar: this.extractWebAvatar(block),
          contentText: floorContent,
          images: floorImages,
          createTime: '',
          isAuthor: floorAuthor === author,
          likeCount: rawLike ? parseInt(rawLike, 10) : 0,
          isLiked: rawAgreeStatus ? parseInt(rawAgreeStatus, 10) === 1 : false,
          level: this.deriveLevel('', floorAuthor),
          ipLocation: '',
        });
      }
      floorIdx++;
      fm = floorRegex.exec(html);
    }
    const firstFloor = page === 1 ? (floors.find((floor: FloorItem) => floor.floor === 1) ?? floors[0]) : undefined;
    const replyFloors = page === 1 ? floors.filter((floor: FloorItem) => floor !== firstFloor && floor.floor > 1) : floors;
    const resolvedAuthor: string = author === '贴吧用户' && firstFloor !== undefined ? firstFloor.author : author;
    const resolvedAvatar: string = authorAvatar.length > 0 || firstFloor === undefined ? authorAvatar : (firstFloor.authorAvatar ?? '');

    const rawThreadLike = extractGroup(html, /(?:threadAgreeNum|thread_agree_num|mainPostAgreeNum|main_post_agree_num|agreeNum|agree_num|post_agree_count)["'=：:]\s*["']?(\d+)/i)
      || extractGroup(html, /["'](?:threadAgreeNum|thread_agree_num|mainPostAgreeNum|main_post_agree_num|agreeNum|agree_num)["']\s*:\s*["']?(\d+)/i)
      || extractGroup(html, /data-thread-agree=["'](\d+)["']/i);
    const rawThreadAgreeStatus = extractGroup(html, /(?:threadHasAgree|thread_has_agree|mainPostHasAgree|main_post_has_agree|hasAgree|has_agree)["'=：:]\s*["']?(\d+)/i)
      || extractGroup(html, /["'](?:threadHasAgree|thread_has_agree|mainPostHasAgree|main_post_has_agree|hasAgree|has_agree)["']\s*:\s*["']?(\d+)/i);
    const detail: ThreadDetail = {
      tid,
      postId: `${firstFloor?.floorId ?? ''}`,
      title,
      forumName,
      forumAvatar,
      author: resolvedAuthor,
      authorAvatar: resolvedAvatar,
      content: firstContentHtml,
      contentText,
      images,
      likeCount: firstFloor?.likeCount ?? (rawThreadLike ? parseInt(rawThreadLike, 10) : 0),
      isLiked: firstFloor?.isLiked ?? (rawThreadAgreeStatus ? parseInt(rawThreadAgreeStatus, 10) === 1 : false),
      replyNum: replyFloors.length,
      createTime: '',
      level: firstFloor?.level ?? 0,
      page,
      totalPage,
    };
    const result: ThreadDetailResult = { detail, floors: replyFloors };
    return result;
  }

  private extractWebAuthor(html: string): string {
    const raw = extractGroup(html, /["'](?:name_show|nameShow|user_name|userName|user_nickname|userNickname|username|nickname)["']\s*:\s*["']([^"']+)["']/i)
      || extractGroup(html, /(?:author_name|name_show|nameShow|user_name|userName|user_nickname|userNickname|nickname)["'=：:]\s*["']?([^"'<&,}\\s]+)/i)
      || extractGroup(html, /class=["'][^"']*(?:p_author_name|d_name|user_name|thread_author|j_user_name)[^"']*["'][^>]*>([\s\S]*?)<\//i)
      || extractGroup(html, /data-field=["'][^"']*(?:author|user|user_name)[^"']*["'][^>]*>([\s\S]*?)<\//i);
    const author = stripHtml(decodeHtmlEntities(raw)).replace(/\\s+/g, ' ').trim();
    return author.length > 0 ? author : '贴吧用户';
  }

  private extractForumAvatarFromHtml(html: string): string {
    // Try to find forum avatar from various possible locations on the thread page
    const patterns: RegExp[] = [
      // Forum head avatar with specific class
      /<img[^>]+class=["'][^"']*(?:card_head_img|forum_avatar|forum_icon|head_img)[^"']*["'][^>]*src=["']([^"']+)["']/i,
      // Forum link with img inside
      /<a[^>]*href=["']\/f\?kw=[^"']*["'][^>]*>[\s\S]*?<img[^>]+src=["']([^"']+)["']/i,
      // Any img with forum-related class
      /<img[^>]+(?:class|data-src|src)=["'][^"']*(?:forum)[^"']*["'][^>]*>/gi,
    ];
    for (const pattern of patterns) {
      const match = pattern.exec(html);
      if (match && match[1]) {
        let url = match[1];
        if (url.startsWith('//')) {
          url = `https:${url}`;
        } else if (url.startsWith('/')) {
          url = `${TIEBA_BASE}${url}`;
        }
        if (url.startsWith('http')) {
          return url;
        }
      }
    }
    // Fallback: look for any image near the forum name
    const fnameMatch = extractGroup(html, /class=["'][^"']*card_title_fname[^"']*["'][^>]*>([\s\S]*?)<\/a>/i);
    if (fnameMatch) {
      const imgMatch = /<img[^>]+src=["']([^"']+)["']/i.exec(fnameMatch);
      if (imgMatch) {
        let url = imgMatch[1];
        if (url.startsWith('//')) {
          url = `https:${url}`;
        }
        if (url.startsWith('http')) {
          return url;
        }
      }
    }
    return '';
  }

  private extractWebAvatar(html: string): string {
    const raw = extractGroup(html, /(?:data-tb-lazyload|data-src|data-original|data-portrait|src|portrait|portrait_h|portraith|avatar|avatar_url|bimg_url)["'=：]\s*["'](https?:\/\/[^"']+)["']/i)
      || extractGroup(html, /(?:data-tb-lazyload|src|data-src|data-original|data-portrait)["'=：]\s*["'](\/[^"']*(?:portrait|avatar|bimg)[^"']*)["']/i)
      || extractGroup(html, /(?:portrait|portrait_h|portraith|avatar|avatar_url|bimg_url)["'=：]\s*["']([^"']+)["']/i)
      || extractGroup(html, /(?:portrait|portraith|avatar)["']?\s*:\s*["']([^"']+)["']/i);
    const cleaned: string = decodeHtmlEntities(raw).trim().replace(/^['\"]|['\"]$/g, '');
    if (cleaned.length === 0 || cleaned === 'null' || cleaned === 'undefined') {
      return '';
    }
    if (cleaned.startsWith('//')) {
      return `https:${cleaned}`;
    }
    if (cleaned.startsWith('/')) {
      return `${TIEBA_BASE}${cleaned}`;
    }
    if (cleaned.startsWith('http://') || cleaned.startsWith('https://')) {
      return cleaned.replace(/^http:\/\//, 'https://');
    }
    if (cleaned.startsWith('tb.') || cleaned.includes('portraith')) {
      return `https://himg.bdimg.com/sys/portraith/item/${cleaned}`;
    }
    return `https://tb.himg.baidu.com/sys/portrait/item/${cleaned}`;
  }

  private parseFollowList(html: string, page: number): PagedResult<FollowItem> {
    const list: FollowItem[] = [];
    // Try to extract forum items with avatars from the follow page
    // The page structure: <a href="/f?kw=NAME"><img src="AVATAR" ... /></a>
    const itemRegex = /<a[^>]*href="\/f\?kw=([^"&]+)[^"]*"[^>]*>([\s\S]*?)<\/a>/gi;
    const seen = new Set<string>();
    let m = itemRegex.exec(html);
    while (m !== null) {
      const forumName = decodeHtmlEntities(decodeURIComponent(m[1]));
      const innerHtml = m[2];
      if (!seen.has(forumName)) {
        seen.add(forumName);
        // Extract avatar URL from <img> tag inside the forum link
        let avatarUrl = '';
        const imgRegex = /<img[^>]+(?:src|data-src|data-original)=["']([^"']+)["']/i;
        const imgMatch = imgRegex.exec(innerHtml);
        if (imgMatch) {
          avatarUrl = this.normalizeForumAvatar(imgMatch[1]);
        }
        list.push({
          forumName,
          level: 0,
          exp: 0,
          isSign: false,
          memberCount: '',
          avatar: avatarUrl,
        });
      }
      m = itemRegex.exec(html);
    }
    return { list, hasMore: list.length >= 30, page };
  }

  private parseConversations(html: string): Conversation[] {
    const list: Conversation[] = [];
    const itemRegex = /<a[^>]*href="\/msg\/index\?mid=([^"&]+)[^"]*"[\s\S]*?<\/a>/gi;
    const seen = new Set<string>();
    let m = itemRegex.exec(html);
    while (m !== null) {
      const userId = m[1];
      if (!seen.has(userId)) {
        seen.add(userId);
        const block = m[0];
        // 头像：优先取锚点内首个用户头像
        const rawAvatar: string = extractGroup(block, /<img[^>]+(?:src|data-src|data-original)=["']([^"']+)["']/i);
        const avatar: string = this.normalizePortraitAvatar(rawAvatar);
        // 最后一条消息预览：常见 class 为 desc / last / message / msg
        const lastMessage: string = stripHtml(extractGroup(block, /class=["'][^"']*(?:desc|last-msg|last_msg|message|msg)[^"']*["'][^>]*>([\s\S]*?)<\//i)).replace(/\s+/g, ' ').trim();
        // 昵称：优先取锚点内 class 含 name 的元素文本；无则取锚点文本首段（昵称通常在“回复/预览”之前）
        const nameEl: string = extractGroup(block, /class=["'][^"']*(?:user_name|userName|nickname|username)[^"']*["'][^>]*>([\s\S]*?)<\//i)
          || extractGroup(block, /class=["'][^"']*\bname\b[^"']*["'][^>]*>([\s\S]*?)<\//i);
        let name: string = stripHtml(decodeHtmlEntities(nameEl)).replace(/\s+/g, ' ').trim();
        if (name.length === 0) {
          const segs: string[] = stripHtml(block).split(/\s{2,}|[\n\r]/);
          name = segs[0]?.trim() ?? '';
        }
        // 过滤明显不是昵称的通知/回复短语；仍无法识别时保留 id 兜底（不再硬编码全量“用户 xxx”）
        if (name.length === 0 || name.includes('回复了你') || name.includes('赞了你')
          || name.includes('@我') || name.includes('系统通知') || name.includes('新消息')) {
          name = `用户 ${userId.slice(0, 6)}`;
        }
        list.push({
          userId,
          name,
          avatar,
          lastMessage,
          lastTime: '',
          unreadCount: 0,
        });
      }
      m = itemRegex.exec(html);
    }
    return list;
  }
}
