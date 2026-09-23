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
 * 图片缓存层：通过 HttpClient（带贴吧 UA/Referer/Cookie）预下载到沙箱，
 * 绕过贴吧图床对 Image 组件的防盗链/限速/UA 拦截（200×200 占位图）。
 *
 * 用法：
 *   const local = await ImageCache.resolve(url);
 *   Image(local) // 本地路径直接渲染，不再触发网络请求
 *
 * 首次 resolve 未命中缓存时，会：
 *   1) 通过 HttpClient 同步下载（带 Referer=贴吧 + 移动端 UA）
 *   2) 写入沙箱缓存目录（按 url 哈希命名，避免特殊字符路径问题）
 *   3) 返回 file:// 路径给 Image 渲染
 *
 * 后续命中：直接返回本地路径，跳过网络请求。
 *
 * 注意：使用同步 await 会阻塞调用方一次（首次下载），通常发生在 aboutToAppear 中，
 * 用户感受为图区短暂空白后渲染真实图。命中缓存后无延迟。
 */

import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { image } from '@kit.ImageKit';
import { HttpClient } from '../network/HttpClient';

const CACHE_DIR_NAME: string = 'img_cache';
const LOG_DOMAIN: number = 0x0A01;
const TAG: string = 'TiebaImgCache';
const MAX_URL_LOG: number = 120;
// 文件日志轮转上限：超过后改名 img_debug.log.bak 再续写，避免长期运行日志无限膨胀
const DEBUG_LOG_MAX_BYTES: number = 1024 * 1024;
// 贴吧 CDN 对非移动端 UA/IP 返回的 200×200 占位 PNG 约 3~4KB（实测 3802 字节）；
// 真实帖子缩略图通常 >5KB。缓存文件小于该阈值视为可疑占位，触发重新下载。
// （不能定太高，会误删 5~10KB 的真实缩略图。）
const MIN_VALID_CACHE_SIZE: number = 4000;
// v1.18 实抓确认的贴吧 CDN 固定占位模板字节数（同 hash 两域 imgsrc/tiebapic 均可能命中）：
//   3802 = 200×200 黑白占位（已被尺寸检测覆盖，这里直接按字节快速判占位，免解码）
//   4262 = 238×238 彩色"贴字图"（紫蓝渐变 + 白色"贴"字，新接口防盗链对失效图统一返回，
//          非 200×200 且非纯灰阶，尺寸/灰阶检测均漏检 —— 本次修复核心）
// v1.21 实抓新增（0902_154709）：贴吧 w= 缩略参数路径（forum/wh%3D960%2C120%3Bq%3D80%3Bg%3D0/...）
//   对失效图返回的非灰阶长条占位图，字节数不恒定但固定三种值（同一模板压缩结果）：
//   4762 / 5562 / 13926（被像素灰阶检测兜底，但字节级快速判能省一次解码）。
// 真实帖子照片几乎不可能恰好等于这些恒定字节数，命中即判占位。
const KNOWN_PLACEHOLDER_BYTES: number[] = [3802, 4262, 4762, 5562, 13926];
// v1.18 贴吧"贴字图"黑白占位：除 200×200 外，CDN 对失效图片还会返回非固定尺寸的
// 纯灰阶占位图（常见高 120 的长条，约 2~8KB，整图 R=G=B 无彩色）。命中缓存时对
// 小于该阈值的文件再做一次像素灰阶校验，命中占位则删除重下。
const PLACEHOLDER_VALIDATE_SIZE: number = 8000;

function shortUrl(url: string): string {
  return url.length > MAX_URL_LOG ? url.substring(0, MAX_URL_LOG) + '...' : url;
}

// ── 全局图片并发闸门（v1.26 自 components/CommonComponents.ets 移入）──────────────────────────
// 图片链路的并发原语归图片缓存管：列表卡片预载、详情页宫格/头像、服务层「点击即预热」共用同一口。
// CommonComponents.ets 保留同名转发函数，既有调用点零改动。
const IMAGE_PRELOAD_CONCURRENCY: number = 16;
let imagePreloadActive: number = 0;

/**
 * 2026-09-20（P2 视口插队）：等待队列支持优先级。
 * priority=0（默认）：后台预取 / 预热 / 非视口解析，FIFO；
 * priority=1：视口内格子的 resolve（ThreadGridImage onVisibleAreaChange 触发），
 * 插到所有 priority=0 等待者之前、同级保持 FIFO——用户刚滚到的格子永远最先落地。
 */
interface ImageGateWaiter {
  resolve: () => void;
  priority: number;
}

const imagePreloadWaiters: ImageGateWaiter[] = [];

export function acquireImagePreloadSlot(priority: number = 0): Promise<void> {
  return new Promise<void>((resolve: () => void) => {
    if (imagePreloadActive < IMAGE_PRELOAD_CONCURRENCY) {
      imagePreloadActive++;
      resolve();
    } else if (priority > 0) {
      // 插到队首段末尾：队首起连续的高优先级者先行，且同级不乱序
      let insertAt: number = 0;
      while (insertAt < imagePreloadWaiters.length && imagePreloadWaiters[insertAt].priority > 0) {
        insertAt++;
      }
      imagePreloadWaiters.splice(insertAt, 0, { resolve: resolve, priority: priority });
    } else {
      imagePreloadWaiters.push({ resolve: resolve, priority: priority });
    }
  });
}

export function releaseImagePreloadSlot(): void {
  const next: ImageGateWaiter | undefined = imagePreloadWaiters.shift();
  if (next !== undefined) {
    next.resolve();
  } else {
    imagePreloadActive--;
  }
}

/** v1.26 预热单批张数上限：只暖首屏（前 3 层），避免一次点按拉起上百张图 */
const IMAGE_WARM_MAX: number = 18;

/** 磁盘缓存清理用：单文件条目（名称/字节数/修改时间戳） */
interface CacheFileEntry {
  name: string;
  size: number;
  mtime: number;
}
const EXT_BY_HOST: Record<string, string> = {
  'imgsrc.baidu.com': 'jpg',
  'tiebapic.baidu.com': 'jpg',
  'static.tieba.baidu.com': 'png',
};

export class ImageCache {
  private static memCache: Map<string, string> = new Map();
  private static cacheDir: string | null = null;
  private static inflight: Map<string, Promise<string>> = new Map();
  /**
   * Z3（2026-09-19）：已完成完整占位校验（已知模板/尺寸/像素灰阶）的 URL 集合。
   * 同一 URL 对应的缓存文件在"校验通过"之后内容不会变（重新下载会先把它移除并重校），
   * 因此无需在每次 resolve 命中时重复 statSync + readSync 整个文件 + 解码做灰阶校验。
   */
  private static verifiedUrls: Set<string> = new Set<string>();

  /**
   * 图片调试落盘日志总开关（2026-09-19 性能优化）：默认 **关**。
   * 原因：debugLog 每次都做同步文件 IO（statSync + openSync + writeSync + closeSync），
   * 而调用点遍布图片加载全链路（本文件 17 处 + ThreadCard 12 处）。快速滑动时每屏会触发
   * 数十次主线程同步写盘 → 直接吃掉帧预算、造成周期性掉帧。
   * 排查图片问题（模拟器上 hilog 被 SELinux 屏蔽时的唯一通道）时把它临时置 true 即可恢复原日志。
   */
  static DEBUG_LOG_ENABLED: boolean = false;

  /**
   * 调试文件日志：写入 <cache>/img_cache/img_debug.log。
   * 模拟器上 unsigned HAP 以 debug_hap 模式运行，hilog 输出被 SELinux 屏蔽，
   * 改用应用自有 cache 目录落盘，hdc 直接拉取分析，不受日志系统限制。
   */
  static debugLog(msg: string): void {
    // 总开关关闭时直接返回：不取目录、不做任何文件 IO（见 DEBUG_LOG_ENABLED 注释）
    if (!ImageCache.DEBUG_LOG_ENABLED) {
      return;
    }
    try {
      const dir: string = ImageCache.getCacheDir();
      const logPath: string = `${dir}/img_debug.log`;
      // 日志轮转：超过上限时把旧日志改名保留一份
      try {
        const st: fileIo.Stat = fileIo.statSync(logPath);
        if (st.size > DEBUG_LOG_MAX_BYTES) {
          const bakPath: string = `${dir}/img_debug.log.bak`;
          try {
            fileIo.unlinkSync(bakPath);
          } catch (e) { /* 无旧备份 */ }
          fileIo.renameSync(logPath, bakPath);
        }
      } catch (e) { /* 日志文件尚不存在 */ }
      const f: fileIo.File = fileIo.openSync(logPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.APPEND);
      try {
        fileIo.writeSync(f.fd, `${Date.now()} ${msg}\n`);
      } finally {
        fileIo.closeSync(f);
      }
    } catch (e) { /* 日志失败不影响主流程 */ }
  }

  /** 取沙箱缓存目录路径（懒初始化） */
  private static getCacheDir(): string {
    if (ImageCache.cacheDir !== null) {
      return ImageCache.cacheDir;
    }
    try {
      const context: common.UIAbilityContext = (getContext() as common.UIAbilityContext);
      const dir: string = `${context.cacheDir}/${CACHE_DIR_NAME}`;
      try {
        fileIo.mkdirSync(dir);
      } catch (e) {
        // 已存在或权限异常；后续 openSync 失败时再处理
      }
      ImageCache.cacheDir = dir;
      return dir;
    } catch (e) {
      ImageCache.debugLog(`getCacheDir EXCEPTION err=${JSON.stringify(e)}`);
      // 返回一个兜底目录，避免上层直接崩溃；后续写入失败也会被捕获
      const fallback: string = '/data/storage/el2/base/cache/img_cache';
      ImageCache.cacheDir = fallback;
      return fallback;
    }
  }

  /**
   * URL → 缓存文件名：优先用图片 HASH（同图跨 URL 形态共享缓存），提取不到再退回整 URL hash。
   * ns：命名空间前缀（如 'pv_'）——同一张图的不同"用途档位"（宫格缩略 vs 预览高清）需要
   * 各存一份文件（内容是不同宽度的变体），靠前缀隔离；默认空串与既有行为完全一致。
   */
  private static urlToFileName(url: string, ns: string = ''): string {
    // v1.27（2026-09-20）：列表卡（wh%3D960…/sign=HASH.jpg 等）与详情宫格（w%3D580… / pic/item/HASH.jpg）
    // 对同一张图的 URL 形态不同，整 URL 做 key 时互不命中 → 「列表页刚看过的图」进帖还要重新下载。
    // 改为提取图片 HASH 做文件名：同图所有形态落在同一个文件上，列表看过的图进帖直接本地秒出（跨重启有效）。
    const hashMatch: RegExpMatchArray | null =
      url.match(/\/(?:sign=[^/]+\/|forum\/pic\/item\/|album\/pic\/item\/)(\w{16,})\.(jpg|jpeg|png|webp|gif)(?:\?|$)/i);
    if (hashMatch !== null) {
      return `${ns}img_${hashMatch[1].toLowerCase()}.${hashMatch[2].toLowerCase()}`;
    }
    // 提取不到 HASH（头像 himg、表情等）→ 回退整 URL hash，行为与改前一致
    let h: number = 5381;
    for (let i = 0; i < url.length; i++) {
      h = ((h << 5) + h + url.charCodeAt(i)) | 0;
    }
    const hex: string = (h >>> 0).toString(16);
    // 推断扩展名（默认 jpg）
    let ext: string = 'jpg';
    try {
      const u: string = url.split('?')[0];
      const lastDot: number = u.lastIndexOf('.');
      if (lastDot > 0 && lastDot > u.length - 6) {
        const candidate: string = u.substring(lastDot + 1).toLowerCase();
        if (candidate === 'jpg' || candidate === 'jpeg' || candidate === 'png' || candidate === 'webp' || candidate === 'gif') {
          ext = candidate;
        }
      }
    } catch (e) { /* 忽略 */ }
    return `${ns}img_${hex}.${ext}`;
  }

  /** 是否已经缓存（命中磁盘 + 内存；含占位图大小校验） */
  static has(url: string): boolean {
    if (ImageCache.memCache.has(url)) {
      return true;
    }
    const fileName: string = ImageCache.urlToFileName(url);
    const filePath: string = `${ImageCache.getCacheDir()}/${fileName}`;
    try {
      if (!fileIo.accessSync(filePath)) {
        return false;
      }
      const stat: fileIo.Stat = fileIo.statSync(filePath);
      if (ImageCache.isKnownPlaceholderSize(stat.size)) {
        // 已知占位模板（3802/4262 等恒定字节）的旧脏缓存：删除并视为未命中，触发重新下载
        ImageCache.debugLog(`cache KNOWN-PLACEHOLDER remove url=${shortUrl(url)} size=${stat.size}`);
        try {
          fileIo.unlinkSync(filePath);
        } catch (e) { /* 删除失败也不影响 */ }
        ImageCache.memCache.delete(url);
        return false;
      }
      return stat.size >= MIN_VALID_CACHE_SIZE;
    } catch (e) {
      return false;
    }
  }

  /** 字节数是否命中已知贴吧 CDN 占位模板（3802/4262 等恒定值） */
  private static isKnownPlaceholderSize(size: number): boolean {
    for (const s of KNOWN_PLACEHOLDER_BYTES) {
      if (size === s) {
        return true;
      }
    }
    return false;
  }

  /** 返回缓存的 file:// 路径；如果未命中返回 null。ns：命名空间（见 urlToFileName） */
  static getCachedPath(url: string, ns: string = ''): string | null {
    if (ImageCache.memCache.has(url)) {
      return ImageCache.memCache.get(url) as string;
    }
    const fileName: string = ImageCache.urlToFileName(url, ns);
    const filePath: string = `${ImageCache.getCacheDir()}/${fileName}`;
    try {
      if (fileIo.accessSync(filePath)) {
        // 占位图防护：贴吧 200×200 占位 PNG 约 3~9KB。缓存文件过小说明是
        // 旧版本误存的占位图，删除并返回 null 触发重新下载（带镜像域重试）。
        const stat: fileIo.Stat = fileIo.statSync(filePath);
        // v1.18 新增：4262B 的 238×238 彩色"贴字图"占位（>4KB 逃过 SMALL 检查）
        // 恒等于 CDN 模板字节数，命中即删。
        if (ImageCache.isKnownPlaceholderSize(stat.size) || stat.size < MIN_VALID_CACHE_SIZE) {
          ImageCache.debugLog(`cache ${ImageCache.isKnownPlaceholderSize(stat.size) ? 'KNOWN-PLACEHOLDER' : 'SMALL'} size=${stat.size} remove-and-redownload url=${shortUrl(url)}`);
          try {
            fileIo.unlinkSync(filePath);
          } catch (e) { /* 删除失败也不影响重下 */ }
          ImageCache.memCache.delete(url);
          ImageCache.verifiedUrls.delete(url);
          return null;
        }
        const fileUri: string = `file://${filePath}`;
        ImageCache.memCache.set(url, fileUri);
        return fileUri;
      }
    } catch (e) { /* 不存在 */ }
    return null;
  }

  /**
   * Z1（2026-09-19）：同步取「已确认安全」的本地缓存路径，供卡片首帧直接渲染真图。
   *
   * 与 getCachedPath 的唯一差异：额外要求文件大小 ≥ PLACEHOLDER_VALIDATE_SIZE。
   * 原因是小于该阈值的文件在 resolve 里还要过一次像素灰阶校验（贴吧非固定尺寸的
   * 黑白"贴字图"占位），同步路径无法等待解码，故这一档一律返回 null 交回异步流程。
   * 由此判定范围是 resolve 现有语义的**子集**，不会比改动前更容易显示占位图。
   */
  static getVerifiedCachedPath(url: string, ns: string = ''): string | null {
    if (!url || (!url.startsWith('http://') && !url.startsWith('https://'))) {
      return null;
    }
    // Z4（2026-09-19 掉帧治理，零语义变化）：该 URL 已确认安全且内存缓存仍在 → 直接返回。
    // 与 resolve 的 Z3 短路同源，补掉本函数遗漏的同一处：原本每次调用（卡片首帧逐图 seed）
    // 都要先走 getCachedPath，再额外做一次 fileIo.statSync，即使 memCache 已命中也不例外。
    // 滚动时每帧新建 1~3 张卡、多图卡最多 9 图，这些 statSync 全是纯重复的主线程同步 IO。
    // 返回值与下方 getCachedPath 的内存分支完全同源（同一份 Map 里的同一个 file:// 值）。
    // verifiedUrls 在所有「文件被删 / 判为占位」路径上都与 memCache 同步 delete（240-241 行），
    // 标记不会单独失效；若 memCache 被其它路径单独清空则落到下方原逻辑，行为与改前一致。
    if (ImageCache.verifiedUrls.has(url)) {
      const hit: string | undefined = ImageCache.memCache.get(url);
      if (hit !== undefined) {
        return hit;
      }
    }
    try {
      const cached: string | null = ImageCache.getCachedPath(url, ns);
      if (cached === null) {
        return null;
      }
      const filePath: string = `${ImageCache.getCacheDir()}/${ImageCache.urlToFileName(url, ns)}`;
      const st: fileIo.Stat = fileIo.statSync(filePath);
      if (st.size < PLACEHOLDER_VALIDATE_SIZE) {
        return null;
      }
      ImageCache.verifiedUrls.add(url);
      return cached;
    } catch (e) {
      // 文件在手查后消失（被 prune）或 stat 异常：返回 null 交回异步流程兜底
      return null;
    }
  }

  // ── 吧头像持久层（2026-09-23）────────────────────────────────────────────────────────
  // 问题：收藏页「吧分类」头像此前把 file:// 路径写进 Preferences 持久化，但图片本体放在
  // cacheDir/img_cache —— 该目录会被 prune（300MB / 1500 文件上限）与系统缓存清理逐步删除，
  // 持久化里的路径于是变成死路径：Image 渲染失败 → 调用方清条目并永久标记失败 →
  // 「过一段时间再进来整页都变成吧名首字」。修复分三层：
  //   1) 头像本体固化到 cacheDir/avatar_cache（img_cache 的**兄弟目录**：prune 只扫 img_cache
  //      自身、不递归子目录，故不会被自身清理逻辑删掉），渲染用的 file:// 路径与帖子图完全同款
  //      （已在真机验证可渲染，不引入新渲染形态风险）；
  //   2) 再备份一份到 filesDir/avatar_cache（应用数据目录，系统清缓存也不动）——显示目录被
  //      系统清掉时同步原地恢复，不必重新走网络；
  //   3) 渲染期同步命中（accessSync + 大小校验），进页首帧就是真头像；渲染失败时删掉坏文件
  //      并由调用方重试一次，而不是整页永久首字。
  private static readonly AVATAR_DIR_NAME: string = 'avatar_cache';
  private static avatarDir: string | null = null;
  private static avatarBackupDir: string | null = null;
  /** 头像文件最小有效字节数：拦住 0 字节 / 半截残留（远小于真实头像，不会误判） */
  private static readonly AVATAR_MIN_VALID_SIZE: number = 512;

  /** 头像显示目录（cacheDir 下、img_cache 的兄弟目录，懒初始化） */
  private static getAvatarDir(): string {
    if (ImageCache.avatarDir !== null) {
      return ImageCache.avatarDir;
    }
    let dir: string = '';
    try {
      const context: common.UIAbilityContext = (getContext() as common.UIAbilityContext);
      dir = `${context.cacheDir}/${ImageCache.AVATAR_DIR_NAME}`;
    } catch (e) {
      dir = `${ImageCache.getCacheDir()}/../${ImageCache.AVATAR_DIR_NAME}`;
    }
    try {
      fileIo.mkdirSync(dir);
    } catch (e) { /* 目录已存在 */ }
    ImageCache.avatarDir = dir;
    return dir;
  }

  /** 头像备份目录（filesDir 下，懒初始化）：显示目录被清时用于原地恢复 */
  private static getAvatarBackupDir(): string {
    if (ImageCache.avatarBackupDir !== null) {
      return ImageCache.avatarBackupDir;
    }
    let dir: string = '';
    try {
      const context: common.UIAbilityContext = (getContext() as common.UIAbilityContext);
      dir = `${context.filesDir}/${ImageCache.AVATAR_DIR_NAME}`;
    } catch (e) {
      dir = `${ImageCache.getAvatarDir()}/bak`;
    }
    try {
      fileIo.mkdirSync(dir);
    } catch (e) { /* 目录已存在 */ }
    ImageCache.avatarBackupDir = dir;
    return dir;
  }

  /** 吧名 → 头像文件名（djb2 哈希命名，规避吧名中的特殊字符 / 路径分隔符） */
  private static avatarFileName(forumName: string): string {
    let h: number = 5381;
    for (let i = 0; i < forumName.length; i++) {
      h = ((h << 5) + h + forumName.charCodeAt(i)) | 0;
    }
    return `av_${(h >>> 0).toString(16)}.jpg`;
  }

  /** 头像文件是否可用（存在且大小有效） */
  private static isUsableAvatarFile(filePath: string): boolean {
    try {
      if (!fileIo.accessSync(filePath)) {
        return false;
      }
      return fileIo.statSync(filePath).size >= ImageCache.AVATAR_MIN_VALID_SIZE;
    } catch (e) {
      return false;
    }
  }

  /**
   * 同步取已固化的吧头像：显示目录优先；缺失则从 filesDir 备份原地恢复（头像文件很小，
   * 一次同步复制即可）——仍缺失返回 null。渲染首帧零等待、零网络。
   */
  static getPersistedAvatarPath(forumName: string): string | null {
    if (forumName.length === 0) {
      return null;
    }
    const fileName: string = ImageCache.avatarFileName(forumName);
    const filePath: string = `${ImageCache.getAvatarDir()}/${fileName}`;
    if (ImageCache.isUsableAvatarFile(filePath)) {
      return `file://${filePath}`;
    }
    try {
      const backup: string = `${ImageCache.getAvatarBackupDir()}/${fileName}`;
      if (ImageCache.isUsableAvatarFile(backup)) {
        fileIo.copyFileSync(backup, filePath);
        return `file://${filePath}`;
      }
    } catch (e) { /* 恢复失败：交回下载流程 */ }
    return null;
  }

  /**
   * 把已下载校验过的头像文件（img_cache 里的 file://）固化到头像目录，并备份一份到 filesDir。
   * 返回固化后的 file://；源文件不存在返回 ''；复制失败退回源路径（本次仍可显示，只是不持久）。
   */
  static persistAvatar(forumName: string, srcUri: string): string {
    if (!srcUri.startsWith('file://')) {
      return srcUri;
    }
    const src: string = srcUri.substring('file://'.length);
    const fileName: string = ImageCache.avatarFileName(forumName);
    const dest: string = `${ImageCache.getAvatarDir()}/${fileName}`;
    try {
      if (!fileIo.accessSync(src)) {
        return '';
      }
      try {
        fileIo.unlinkSync(dest);
      } catch (e) { /* 目标尚不存在 */ }
      fileIo.copyFileSync(src, dest);
      // 备份到 filesDir（系统清缓存后仍可用于原地恢复）；备份失败不影响本次显示
      try {
        const backup: string = `${ImageCache.getAvatarBackupDir()}/${fileName}`;
        try {
          fileIo.unlinkSync(backup);
        } catch (e2) { /* 备份尚不存在 */ }
        fileIo.copyFileSync(dest, backup);
      } catch (e3) {
        ImageCache.debugLog(`avatar backup FAIL err=${JSON.stringify(e3)}`);
      }
      return `file://${dest}`;
    } catch (e) {
      ImageCache.debugLog(`avatar persist FAIL err=${JSON.stringify(e)}`);
      return srcUri;
    }
  }

  /** 删除某吧的持久头像（显示目录 + filesDir 备份；渲染期发现文件损坏时调用，避免下次继续命中坏文件） */
  static discardPersistedAvatar(forumName: string): void {
    if (forumName.length === 0) {
      return;
    }
    const fileName: string = ImageCache.avatarFileName(forumName);
    try {
      fileIo.unlinkSync(`${ImageCache.getAvatarDir()}/${fileName}`);
    } catch (e) { /* 文件不存在 */ }
    try {
      fileIo.unlinkSync(`${ImageCache.getAvatarBackupDir()}/${fileName}`);
    } catch (e) { /* 文件不存在 */ }
  }

  /**
   * 确保某吧头像已固化到持久目录：命中直接返回 file://（零网络）；未命中才走 resolve
   * （带移动端 UA 下载 + 占位校验 + 镜像域重试）后固化。占位图 / 网络失败返回 ''，调用方走首字占位。
   */
  static async ensureAvatar(forumName: string, url: string): Promise<string> {
    const persisted: string | null = ImageCache.getPersistedAvatarPath(forumName);
    if (persisted !== null) {
      return persisted;
    }
    if (!url || url.length === 0) {
      return '';
    }
    const resolved: string = await ImageCache.resolve(url, true);
    if (!resolved.startsWith('file://')) {
      return ''; // 占位确认（''）或网络失败（原 URL）
    }
    return ImageCache.persistAvatar(forumName, resolved);
  }

  /**
   * v1.26：贴吧图片缩略图 URL 归一（自 pages/ThreadDetail.ets 的 resolveThumbUrl 移入）。
   * 页面显示与「点击即预热」必须对**同一个 URL 形态**做缓存，否则预热下载的文件在显示侧永远命不中。
   * 仅对自带宽度参数的 CDN 图做缩小替换，避免触发防盗链：
   * 不再向 /forum/pic/item/ 原图路径注入 w%3D200 —— 贴吧 CDN 对注入后的非标准路径可能返回
   * 防盗链占位图（HTTP 200 + logo 图片），Image 会当作正常图片直接显示，导致九宫格整片变成贴吧 logo。
   * 因此原图（无 w 参数）原样返回，bigCdnSrc 类的 580 宽图替换为 200 宽。
   */
  static toThumbUrl(url: string): string {
    if (url.length === 0) {
      return url;
    }
    // 2026-09-20（P3）：缩略档 200 → 360。详情宫格格宽 ~110vp（3x 屏 330+ 物理像素），
    // 200 宽首画明显上采样发糊；360 与 580/200 同属 w%3D 模板类（替换已被长期验证可达），
    // 字节仍小（几十 KB 级），首画清晰度上档。显示侧（ThreadGridImage 直连）与预热侧
    //（warmImages / warmDetailPreviewImages）同走本函数，URL 形态一致、缓存互相命中。
    const encoded: string = url.replace(/w%3D\d+/g, 'w%3D360');
    if (encoded !== url) {
      return encoded;
    }
    const plain: string = url.replace(/w=\d+/g, 'w=360');
    if (plain !== url) {
      return plain;
    }
    return url;
  }

  /**
   * 预览高清档 URL（2026-09-23 预览提速 P4）：把详情页映射给的 w%3D400 档重写为 w%3D720。
   * - 同属 w%3D 模板类（服务端按宽度参数即时缩放，w=720 档在 22.x 楼层 cdnSrc 中原生存在，可达性已被长期验证）；
   * - 无宽度参数的 URL 本身即原图，原样返回（此时高清档与基础档是同一份文件，不重复下载）；
   * - 预览页全屏 Contain + 双击 2x/捏合 4x 放大场景，720 档明显优于 400 档。
   */
  static toPreviewUrl(url: string): string {
    if (url.length === 0) {
      return url;
    }
    const encoded: string = url.replace(/w%3D\d+/g, 'w%3D720');
    if (encoded !== url) {
      return encoded;
    }
    return url.replace(/w=\d+/g, 'w=720');
  }

  /**
   * 预览高清档解析（P4）：与基础档（宫格缩略）共用下载/校验/镜像重试全链路，
   * 但缓存文件落在独立命名空间（pv_ 前缀）——同一 HASH 的 720 档与 360/400 档
   * 是不同内容，必须各存一份。返回 file:// 本地路径；失败返回原 previewUrl（不更差）。
   */
  static async resolvePreview(url: string): Promise<string> {
    if (!url || (!url.startsWith('http://') && !url.startsWith('https://'))) {
      return url;
    }
    const purl: string = ImageCache.toPreviewUrl(url);
    if (purl === url) {
      // 无宽度参数：URL 本身即原图，与基础缓存同文件（同 HASH key），无需独立命名空间
      return ImageCache.resolve(url);
    }
    return ImageCache.resolve(purl, false, 'pv_');
  }

  /**
   * 同步取已落地的预览高清档文件（供「保存到图库」零网络直取）；未命中返回 null。
   */
  static getPreviewCachedPath(url: string): string | null {
    if (!url || (!url.startsWith('http://') && !url.startsWith('https://'))) {
      return null;
    }
    const purl: string = ImageCache.toPreviewUrl(url);
    if (purl === url) {
      return ImageCache.getVerifiedCachedPath(url);
    }
    return ImageCache.getCachedPath(purl, 'pv_');
  }

  /**
   * v1.26：图片预热 —— 批量把 URL 灌进 resolve（走全局并发闸门），只提前下载、不改任何显示逻辑。
   * 用途：列表页「点击即预取」拿到详情数据后立刻预热首屏宫格图，让图片下载与路由转场动画**并行**；
   * 页面渲染时 getVerifiedCachedPath 已命中 → 图片从本地 file:// 秒出（不再等网络）。
   * 已在缓存的跳过；失败静默（resolve 内部自会处理占位识别与镜像候选）。
   * priority：并发闸门优先级（P3 点击即拉传 1 插队；后台预热默认 0）。调用点零改动兼容。
   */
  static warmImages(urls: string[], cap: number = IMAGE_WARM_MAX, priority: number = 0): void {
    let warmed: number = 0;
    for (const u of urls) {
      if (warmed >= cap) {
        break;
      }
      if (!u || u.length === 0) {
        continue;
      }
      if (ImageCache.getCachedPath(u) !== null) {
        continue; // 已在缓存，无需预热
      }
      warmed++;
      (async (): Promise<void> => {
        await acquireImagePreloadSlot(priority);
        try {
          await ImageCache.resolve(u);
        } catch (e) {
          /* 静默：预热失败不影响任何显示路径 */
        } finally {
          releaseImagePreloadSlot();
        }
      })();
    }
  }

  /**
   * 通过 HttpClient（带贴吧移动端 UA + Referer + Cookie）下载图片到沙箱缓存。
   * 命中缓存立即返回；未命中时阻塞到下载完成。
   * 任何异常都返回原 URL，让 Image 自行尝试（不会更差）。
   *
   * v1.29 isAvatar：头像模式。贴吧吧头像大量是「恰好 200×200」或「黑白漫画风（整图
   * R=G=B）」的合法图片，而占位校验里的精确尺寸与灰阶启发式是为帖子照片设计的
   * （真机实证：刃牙吧黑白头像被灰阶规则误杀、遐蝶吧 200×200 头像被尺寸规则误杀，
   * 表现为吧分类头像永远走首字占位）。头像模式下跳过这两类启发式，仅保留字节模板
   * （3802/4262 等恒定占位文件，实测足以覆盖真占位图）、<100B 近空响应、解码失败
   * 三类硬校验。默认 false，帖子图片链路行为零变化。
   */
  static async resolve(url: string, isAvatar: boolean = false, ns: string = ''): Promise<string> {
    if (!url || url.length === 0) return url;
    // 非 http(s):// 直接返回（file://, data:, internal: 等）
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return url;
    }
    try {
      const cached: string | null = ImageCache.getCachedPath(url, ns);
      if (cached !== null) {
        // Z3（2026-09-19）：该 URL 已通过完整占位校验 → 直接返回。
        // 同 URL 对应的缓存文件在校验通过后内容不会变（重下会先删文件并清除标记），
        // 故无需每次命中都重新 statSync + readSync 整个文件 + 解码做灰阶校验。
        if (ImageCache.verifiedUrls.has(url)) {
          return cached;
        }
        // v1.18 命中缓存的小文件可能是旧版本误存的贴吧"贴字图"黑白占位（非 200×200，
        // 旧逻辑漏检）。做一次像素灰阶校验：命中占位则删除并落到下方下载流程重下。
        try {
          const fileName: string = ImageCache.urlToFileName(url, ns);
          const filePath: string = `${ImageCache.getCacheDir()}/${fileName}`;
          const st: fileIo.Stat = fileIo.statSync(filePath);
          // 头像模式跳过灰阶复检（黑白头像合法，见 resolve 注释），字节级占位已由
          // getCachedPath 的 KNOWN_PLACEHOLDER_BYTES 检查兜住
          if (st.size < PLACEHOLDER_VALIDATE_SIZE && !isAvatar) {
            const fd: fileIo.File = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY);
            try {
              const fileBuf: ArrayBuffer = new ArrayBuffer(st.size);
              fileIo.readSync(fd.fd, fileBuf);
              if (await ImageCache.isPlaceholderImage(fileBuf)) {
                ImageCache.debugLog(`cache PLACEHOLDER-by-decoder remove url=${shortUrl(url)} size=${st.size}`);
                try {
                  fileIo.unlinkSync(filePath);
                } catch (e) { /* 删除失败不影响 */ }
                ImageCache.memCache.delete(url);
                ImageCache.verifiedUrls.delete(url);
                // 落到下方下载流程
              } else {
                ImageCache.memCache.set(url, cached);
                ImageCache.verifiedUrls.add(url);
                return cached;
              }
            } finally {
              fileIo.closeSync(fd);
            }
          } else {
            ImageCache.verifiedUrls.add(url);
            return cached;
          }
        } catch (e) {
          return cached;
        }
      }
    } catch (e) {
      ImageCache.debugLog(`resolve getCachedPath EXCEPTION url=${shortUrl(url)} err=${JSON.stringify(e)}`);
    }
    // 同一个 URL 同时多次 resolve 时，复用同一个 Promise
    // v1.27：key 改为缓存文件名 —— 同图不同 URL 形态（HASH 归一后写同一个文件）必须共用任务，
    // 否则两个变体并发下载会同时 TRUNC 写同一文件，有写坏风险
    const inflightKey: string = ImageCache.urlToFileName(url, ns);
    const existing: Promise<string> | undefined = ImageCache.inflight.get(inflightKey);
    if (existing !== undefined) {
      return existing;
    }
    const task: Promise<string> = ImageCache.downloadAndCache(url, isAvatar, ns);
    ImageCache.inflight.set(inflightKey, task);
    try {
      const result: string = await task;
      return result;
    } catch (e) {
      ImageCache.debugLog(`resolve task EXCEPTION url=${shortUrl(url)} err=${JSON.stringify(e)}`);
      return url;
    } finally {
      ImageCache.inflight.delete(inflightKey);
    }
  }

  /**
   * 生成候选下载 URL：原 URL + 贴吧图床镜像域。
   * imgsrc.baidu.com 与 tiebapic.baidu.com 是同一张图（同一 hash 路径）的官方镜像，
   * 新发布的帖子图片 URL 可能只在某个域/某个 CDN 节点被防盗链拦截或返回占位图，
   * 换镜像域再试一次能显著提高命中率。其它域不生成候选，保持原 URL 单次尝试。
   * v1.21 实抓(0902_154709)贴吧部分 hash 在 imgsrc/tiebapic 两域镜像同步延迟，
   * 老域 hiphotos.baidu.com 反而先返回真图(贴吧旧 CDN 节点，部分老帖同步慢但同步完成)，
   * 加入第三镜像候选，提一次命中率。
   */
  private static mirrorCandidates(url: string): string[] {
    const candidates: string[] = [url];
    if (url.includes('imgsrc.baidu.com')) {
      candidates.push(url.replace('imgsrc.baidu.com', 'tiebapic.baidu.com'));
    } else if (url.includes('tiebapic.baidu.com')) {
      candidates.push(url.replace('tiebapic.baidu.com', 'imgsrc.baidu.com'));
    }
    // hiphotos.baidu.com(贴吧旧图床)作为第三镜像,跳过已是 hiphotos 的 URL 避免冗余。
    // 部分老帖/新帖在 hiphotos 上反而比 imgsrc/tiebapic 更早完成 CDN 同步,命中可走通。
    if (!url.includes('hiphotos.baidu.com')) {
      let hiphotosUrl: string = '';
      if (url.includes('imgsrc.baidu.com')) {
        hiphotosUrl = url.replace('imgsrc.baidu.com', 'hiphotos.baidu.com');
      } else if (url.includes('tiebapic.baidu.com')) {
        hiphotosUrl = url.replace('tiebapic.baidu.com', 'hiphotos.baidu.com');
      } else {
        // 兜底：若原 URL 不在已知两镜像域中,通用构造 hiphotos 占位串(失败则落入外层 null)
        hiphotosUrl = url.replace(/^https?:\/\/[^/]+/, 'https://hiphotos.baidu.com');
      }
      if (hiphotosUrl.length > 0 && hiphotosUrl !== url) {
        candidates.push(hiphotosUrl);
      }
    }
    // v1.22 实抓(0902_1825x)终极兜底：贴吧 /forum/w%3D... / wh%3D... 缩略路径(贴吧新版
    // 接口给关注用户帖子的图床 URL)对模拟器 UA / 未登录态会返回 1~9 字节近空响应,
    // imgsrc/tiebapic/hiphotos 三镜像一律失败,卡片走"图片加载失败"降级。
    // 但同 HASH 的 /forum/pic/item/HASH.{ext} 直链原图不受此防盗链影响(同 hilog 实抓
    // 大量 cached OK: 363585 / 440304 / 605032 bytes 等真实图)。从 w/wh URL 抽出 HASH
    // 拼直链作为第四候选,旧逻辑全失败时仍能命中真实图。
    const hashMatch: RegExpMatchArray | null = url.match(/\/sign=[^/]+\/(\w+)\.(jpg|jpeg|png|webp|gif)(?:\?|$)/i);
    if (hashMatch) {
      const hash: string = hashMatch[1];
      const ext: string = hashMatch[2].toLowerCase();
      const directUrls: string[] = [
        `https://imgsrc.baidu.com/forum/pic/item/${hash}.${ext}`,
        `https://tiebapic.baidu.com/forum/pic/item/${hash}.${ext}`,
      ];
      for (const u of directUrls) {
        if (!candidates.includes(u)) {
          candidates.push(u);
        }
      }
    }
    return candidates;
  }

  private static async downloadAndCache(url: string, isAvatar: boolean = false, ns: string = ''): Promise<string> {
    // 磁盘缓存统一以「原 URL」为 key 命名；镜像候选下载成功同样写入该文件，
    // 后续 getCachedPath(原 URL) 可直接命中，无需二次下载。
    const filePath: string = `${ImageCache.getCacheDir()}/${ImageCache.urlToFileName(url, ns)}`;
    ImageCache.debugLog(`resolve start url=${shortUrl(url)} candidates=${ImageCache.mirrorCandidates(url).length}`);
    // v1.18 区分「网络失败」与「确认占位图」：所有候选都返回占位（贴吧 200×200 / 纯灰阶"贴字图"）
    // 时返回 '' 通知调用方不要直连原 URL（否则 Image 仍会拉到同一张占位图并显示）。
    let sawPlaceholder: boolean = false;
    for (const candidate of ImageCache.mirrorCandidates(url)) {
      try {
        const buf: ArrayBuffer | null = await ImageCache.downloadBuf(candidate);
        if (buf === null) {
          hilog.warn(LOG_DOMAIN, TAG, 'candidate fail url=%{public}s', shortUrl(candidate));
          ImageCache.debugLog(`candidate FAIL url=${shortUrl(candidate)}`);
          continue; // 网络失败，尝试下一个镜像
        }
        // 占位图识别（含像素灰阶校验）：命中则丢弃该候选，试下一个镜像
        if (await ImageCache.isPlaceholderImage(buf, isAvatar)) {
          sawPlaceholder = true;
          ImageCache.debugLog(`candidate PLACEHOLDER url=${shortUrl(candidate)} bytes=${buf.byteLength}`);
          continue;
        }
        const file: fileIo.File = fileIo.openSync(filePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
        try {
          // Z2（2026-09-19）：写盘改异步。原 writeSync 在滑动中新卡进入时把整张图
          // （缩略图常 100KB~1MB）同步写入沙箱，直接占用主线程帧预算。字节内容与
          // 缓存文件名不变，仅把等待方式换成 Promise。
          await fileIo.write(file.fd, buf);
        } finally {
          fileIo.closeSync(file);
        }
        const fileUri: string = `file://${filePath}`;
        ImageCache.memCache.set(url, fileUri);
        // Z3：写盘的字节刚通过 isPlaceholderImage 完整校验（模板字节/尺寸/像素灰阶），
        // 直接标记为已校验，后续 resolve 命中时无需再解一次码。
        ImageCache.verifiedUrls.add(url);
        hilog.info(LOG_DOMAIN, TAG, 'cached ok url=%{public}s bytes=%{public}d', shortUrl(url), buf.byteLength);
        ImageCache.debugLog(`cached OK url=${shortUrl(url)} bytes=${buf.byteLength} cand=${shortUrl(candidate)}`);
        ImageCache.pruneIfNeeded();
        return fileUri;
      } catch (e) {
        hilog.error(LOG_DOMAIN, TAG, 'candidate exception url=%{public}s err=%{public}s', shortUrl(candidate), JSON.stringify(e));
        ImageCache.debugLog(`candidate EXCEPTION url=${shortUrl(candidate)} err=${JSON.stringify(e)}`);
        // 单个候选异常继续下一个
      }
    }
    hilog.error(LOG_DOMAIN, TAG, 'ALL candidates failed url=%{public}s', shortUrl(url));
    ImageCache.debugLog(`ALL candidates FAILED url=${shortUrl(url)} placeholder=${sawPlaceholder}`);
    if (sawPlaceholder) {
      return ''; // 确认占位：不返回原 URL，避免 Image 直连再次拉到同一张"贴字图"
    }
    return url;
  }

  /**
   * 解码图片字节并判断是否为贴吧占位图（含"贴字图"黑白/彩色占位）。
   * 判定规则（v1.18 增强）：
   *  1) 字节数精确命中 CDN 已知占位模板（3802/4262 等恒定值，免解码直接判占位）；
   *  2) 精确尺寸 200×200（贴吧经典黑白占位 PNG）；
   *  3) 精确尺寸 238×238（v1.18 实抓：彩色"贴字图"占位，紫蓝渐变+白色"贴"字，
   *     imgsrc/tiebapic 镜像对失效/防盗链图统一返回 4262B 固定文件，非灰阶曾漏检）；
   *  4) 纯灰阶图：整图 R=G=B 的像素占比 ≥98%（非固定尺寸的其它黑白占位变体）。
   * 解码失败（非图片/损坏）也按占位处理返回 true，避免把坏文件写入缓存。
   * 说明：贴吧帖子配图几乎均为彩色照片，恰好 238×238 正方形或整图灰阶的概率极低；
   * 即使个别图片被误判，也只是少显示一张图（走降级），不会显示错误占位，可接受。
   *
   * v1.29 isAvatar：头像模式下跳过规则 2)~4)（尺寸与灰阶启发式）——吧头像合法地大量
   * 出现 200×200 与黑白图（真机/PC 双实证：刃牙吧头像 150×150 灰阶 100%、遐蝶吧头像
   * 恰好 200×200，均被旧规则误杀）。已知占位图文件字节数恰好命中模板 1)（200×200
   * 占位=3802B、238×238 彩贴=4262B），字节模板在头像模式下仍能拦住全部已知占位。
   */
  private static async isPlaceholderImage(buf: ArrayBuffer, isAvatar: boolean = false): Promise<boolean> {
    // 字节数命中已知占位模板 → 直接判占位，省解码
    if (ImageCache.isKnownPlaceholderSize(buf.byteLength)) {
      ImageCache.debugLog(`PLACEHOLDER by-bytes size=${buf.byteLength}`);
      return true;
    }
    // v1.22 实抓(0902_1825x)：贴吧 /forum/w%3D... / wh%3D... 缩略路径在模拟器 UA/未登录态下
    // 被服务器直接截断返回 1~9 字节的近空响应（不是任何已知占位模板,不解码也走不到
    // "解码失败判占位"分支而被忽略）。任一真实图片格式头部 ≥67B(PNG) / ≥100B(JPEG/WebP/GIF)；
    // 小于 100B 必然不是合法图片,直接判占位,避免后续误认为"真实小图"放行。
    if (buf.byteLength < 100) {
      ImageCache.debugLog(`PLACEHOLDER by-tiny-size size=${buf.byteLength}`);
      return true;
    }
    try {
      const src: image.ImageSource = image.createImageSource(buf);
      try {
        const info: image.ImageInfo = await src.getImageInfo();
        if (!isAvatar) {
          if (info.size.width === 200 && info.size.height === 200) {
            return true;
          }
          if (info.size.width === 238 && info.size.height === 238) {
            return true;
          }
        }
        const w: number = info.size.width;
        const h: number = info.size.height;
        const total: number = w * h;
        // 仅对中等尺寸图做像素检测，避免超大图解码耗时（贴吧占位图都很小）
        if (total <= 0 || total > 600 * 600) {
          return false;
        }
        // 头像模式跳过灰阶启发式（黑白漫画头像合法，见方法头注释）
        if (isAvatar) {
          return false;
        }
        // Z4（2026-09-19）：按缩略尺寸解码。本方法只判"整图是否灰阶"，结论取自
        // 采样占比（上限 512 点），与解码到原始尺寸无关；而原来按原尺寸解码后还要把
        // total*4 字节（600×600 时约 1.4MB）整块拷进 ArrayBuffer，纯属浪费。
        // 期望尺寸取 min(原尺寸, 96) 保证只缩不放，随后按解码后的真实尺寸读像素。
        const tw: number = Math.min(w, 96);
        const th: number = Math.min(h, 96);
        const pixmap: image.PixelMap = await src.createPixelMap({ desiredSize: { width: tw, height: th } });
        try {
          const pinfo: image.ImageInfo = await pixmap.getImageInfo();
          const ptotal: number = pinfo.size.width * pinfo.size.height;
          if (ptotal <= 0) {
            return false;
          }
          const buf4: ArrayBuffer = new ArrayBuffer(ptotal * 4);
          await pixmap.readPixelsToBuffer(buf4);
          const arr: Uint8Array = new Uint8Array(buf4);
          // 采样上限 512 点（步长自适应），避免全量遍历
          const step: number = Math.max(1, Math.floor(ptotal / 512));
          let gray: number = 0;
          let samples: number = 0;
          for (let i = 0; i < ptotal * 4; i += 4 * step) {
            if (arr[i] === arr[i + 1] && arr[i + 1] === arr[i + 2]) {
              gray++;
            }
            samples++;
          }
          return samples > 0 && gray / samples >= 0.98;
        } finally {
          pixmap.release();
        }
      } finally {
        src.release();
      }
    } catch (e) {
      ImageCache.debugLog(`decoder EXCEPTION err=${JSON.stringify(e)}`);
      return true;
    }
  }

  /** 下载单个候选 URL：成功返回图片字节；失败返回 null
   * v1.18+ 统一走 HttpClient.getBinary（rcp 单例 Session，跨请求复用连接/HTTP2），
   * 避免每张图都新建 http 连接；UA/Referer 显式传入，Cookie 由 buildHeaders 自动注入。
   */
  private static async downloadBuf(url: string): Promise<ArrayBuffer | null> {
    try {
      const buf: ArrayBuffer = await HttpClient.getBinary(url, {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13; HarmonyOS 5.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 tieba/12.5.0',
        'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9',
        'Referer': 'https://tieba.baidu.com/',
      });
      // v1.18 占位图判定统一上移到 downloadAndCache（isPlaceholderImage 含尺寸 + 纯灰阶
      // 像素检测），downloadBuf 只负责网络层：HTTP 2xx 即返回字节，由外层决定是否缓存。
      return buf;
    } catch (e) {
      hilog.error(LOG_DOMAIN, TAG, 'request exception url=%{public}s err=%{public}s', shortUrl(url), JSON.stringify(e));
      ImageCache.debugLog(`REQUEST EXCEPTION url=${shortUrl(url)} err=${JSON.stringify(e)}`);
      return null;
    }
  }

  // ---- 磁盘缓存清理：总大小/文件数超限时按 mtime 删除最旧文件，防止 img_cache 无限膨胀 ----
  private static cacheWriteCounter: number = 0;
  private static readonly PRUNE_INTERVAL: number = 20;      // 每写 N 个文件检查一次
  private static readonly PRUNE_MIN_GAP_MS: number = 5 * 60 * 1000; // 两次真实扫描最小间隔（5 分钟）
  private static readonly MAX_CACHE_BYTES: number = 300 * 1024 * 1024; // 300MB
  private static readonly MAX_CACHE_FILES: number = 1500;
  /** 上次真实扫描时间戳（进程内），用于时间节流 */
  private static lastPruneAt: number = 0;
  /** 是否有一次异步清理正在跑，避免并发重复扫描 */
  private static pruneRunning: boolean = false;

  /**
   * 清理触发点（图片写盘成功后同步调用）：本方法只做 O(1) 判定。
   * 2026-09-19 性能优化：原实现每次触发都 listFileSync + 逐文件 statSync 同步扫全目录
   * （上限 1500 文件），且就发生在写盘后的调用栈里 → 滑动中周期性数十~数百 ms 主线程阻塞。
   */
  private static pruneIfNeeded(): void {
    ImageCache.cacheWriteCounter++;
    if (ImageCache.cacheWriteCounter % ImageCache.PRUNE_INTERVAL !== 0) {
      return;
    }
    if (ImageCache.pruneRunning) {
      return;
    }
    const now: number = Date.now();
    if (now - ImageCache.lastPruneAt < ImageCache.PRUNE_MIN_GAP_MS) {
      return;
    }
    ImageCache.lastPruneAt = now;
    ImageCache.pruneRunning = true;
    // 不 await：异步跑完即可，绝不阻塞当前（很可能是滑动中的）帧
    ImageCache.pruneAsync();
  }

  /** 异步清理磁盘缓存：超过阈值删除最旧的图片文件（仅清理磁盘，不影响 memCache）。
   *  阈值与删除策略（mtime 最旧优先）与改前完全一致，只是 IO 全部换成 Promise 接口。 */
  private static async pruneAsync(): Promise<void> {
    try {
      const dir: string = ImageCache.getCacheDir();
      const names: string[] = await fileIo.listFile(dir);
      if (names.length === 0) {
        return;
      }
      let total: number = 0;
      const entries: CacheFileEntry[] = [];
      for (const name of names) {
        try {
          const st: fileIo.Stat = await fileIo.stat(`${dir}/${name}`);
          entries.push({ name: name, size: st.size, mtime: st.mtime });
          total += st.size;
        } catch (e) { /* 单个文件 stat 失败忽略 */ }
      }
      if (entries.length <= ImageCache.MAX_CACHE_FILES && total <= ImageCache.MAX_CACHE_BYTES) {
        return;
      }
      // 最旧在前逐个删除，直到两项指标都低于阈值
      entries.sort((a, b) => a.mtime - b.mtime);
      for (const entry of entries) {
        if (entries.length <= ImageCache.MAX_CACHE_FILES && total <= ImageCache.MAX_CACHE_BYTES) {
          break;
        }
        try {
          await fileIo.unlink(`${dir}/${entry.name}`);
          total -= entry.size;
          entries.length--;
        } catch (e) { /* 删除失败忽略 */ }
      }
      ImageCache.debugLog(`prune done files=${entries.length} total=${total}`);
    } catch (e) { /* 清理失败不影响主流程 */ } finally {
      ImageCache.pruneRunning = false;
    }
  }
}