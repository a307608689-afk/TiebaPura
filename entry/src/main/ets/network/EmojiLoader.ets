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

import image from '@ohos.multimedia.image';
import { HttpClient } from './HttpClient';

const TAG: string = 'EmojiLoader';

// 默认黄豆表情高清库（贴吧客户端提取 90x90，参考 microlong666/Tieba_mobile_emotions）
const EMOJI_HD_BASE: string = 'https://cdn.jsdelivr.net/gh/microlong666/tieba_mobile_emotions/';
// 官方表情 CDN（30x30，102-124 缺失；需 Referer 防盗链）
const EMOJI_TB2_BASE: string = 'https://tb2.bdstatic.com/tb/editor/images/client/';

// 表情包下载→PixelMap 工具：彻底绕开 tb2.bdstatic.com/gsp0.baidu.com 的防盗链（Image 组件无法自定义 Referer，HttpClient 可以）
export class EmojiLoader {
  private static readonly CACHE_MAX: number = 400;
  // ArkTS 下通过 namespace-qualified 类型 image.PixelMap 引用
  private static pixelCache: Record<string, image.PixelMap | undefined> = {};
  private static inflightSet: string[] = [];
  private static cacheKeys: string[] = [];

  private static hasInFlight(url: string): boolean {
    return EmojiLoader.inflightSet.indexOf(url) !== -1;
  }
  private static addInFlight(url: string): void {
    if (!EmojiLoader.hasInFlight(url)) {
      EmojiLoader.inflightSet = [...EmojiLoader.inflightSet, url];
    }
  }
  private static removeInFlight(url: string): void {
    const i: number = EmojiLoader.inflightSet.indexOf(url);
    if (i !== -1) {
      EmojiLoader.inflightSet = EmojiLoader.inflightSet.slice(0, i).concat(EmojiLoader.inflightSet.slice(i + 1));
    }
  }

  private static trimCache(): void {
    while (EmojiLoader.cacheKeys.length > EmojiLoader.CACHE_MAX) {
      const oldest: string | undefined = EmojiLoader.cacheKeys.shift();
      if (oldest !== undefined) {
        const pm: image.PixelMap | undefined = EmojiLoader.pixelCache[oldest];
        if (pm !== undefined) {
          try { pm.release(); } catch (_) { /* ignore */ }
        }
        EmojiLoader.pixelCache[oldest] = undefined;
      }
    }
  }

  private static putCache(url: string, pm: image.PixelMap): void {
    if (EmojiLoader.pixelCache[url] !== undefined) return;
    EmojiLoader.pixelCache[url] = pm;
    EmojiLoader.cacheKeys.push(url);
    EmojiLoader.trimCache();
  }

  // 注意：ImageSpan 接受 PixelMap | ResourceStr 类型，但在页面层 import image 不可行时，这里用局部类型转换。
  // 通过 getAsResource() 返回值交给 ImageSpan，无需在调用点显式声明 PixelMap 类型。
  static get(url: string): Object | undefined {
    const v: image.PixelMap | undefined = EmojiLoader.pixelCache[url];
    if (v === undefined || v === null) return undefined;
    return v as Object;
  }

  static has(url: string): boolean {
    const v: image.PixelMap | undefined = EmojiLoader.pixelCache[url];
    return (v !== undefined && v !== null);
  }

  static async ensure(url: string): Promise<Object> {
    if (!url || url.length === 0) {
      throw new Error('empty emoji url');
    }
    const cached: image.PixelMap | undefined = EmojiLoader.pixelCache[url];
    if (cached !== undefined && cached !== null) return cached as Object;
    if (EmojiLoader.hasInFlight(url)) {
      return Promise.reject<Object>(new Error('inflight'));
    }
    EmojiLoader.addInFlight(url);
    try {
      const pm: image.PixelMap = await EmojiLoader.download(url);
      EmojiLoader.putCache(url, pm);
      return pm as Object;
    } finally {
      EmojiLoader.removeInFlight(url);
    }
  }

  // 为 image_emoticon 默认表情生成候选 URL 列表：主源失败时回退另一 CDN
  // （高清库 jsDelivr ↔ 官方 tb2 互备；其余表情仅原 URL）
  private static emojiUrlCandidates(url: string): string[] {
    const list: string[] = [url];
    let fileName: string = '';
    if (url.startsWith(EMOJI_HD_BASE) && url.endsWith('.png')) {
      fileName = url.substring(EMOJI_HD_BASE.length, url.length - 4);
    } else if (url.startsWith(EMOJI_TB2_BASE) && url.endsWith('.png')) {
      fileName = url.substring(EMOJI_TB2_BASE.length, url.length - 4);
    } else {
      return list;
    }
    if (!fileName.startsWith('image_emoticon')) {
      return list;
    }
    const idStr: string = fileName.substring('image_emoticon'.length);
    const emojiId: number = idStr.length === 0 ? 1 : parseInt(idStr);
    if (emojiId !== emojiId || emojiId < 1) {
      return list;
    }
    // 高清库 ID 1 文件名无数字后缀；官方库统一带数字后缀
    const hdFile: string = emojiId === 1 ? 'image_emoticon' : `image_emoticon${emojiId}`;
    const hdUrl: string = `${EMOJI_HD_BASE}${hdFile}.png`;
    const tb2Url: string = `${EMOJI_TB2_BASE}image_emoticon${emojiId}.png`;
    if (url === hdUrl) {
      list.push(tb2Url);
    } else if (url === tb2Url) {
      list.push(hdUrl);
    }
    return list;
  }

  private static async download(url: string): Promise<image.PixelMap> {
    const headers: Record<string, string> = {
      'Referer': 'https://tieba.baidu.com/',
      'User-Agent': 'Mozilla/5.0 (Linux; Android 14) BaiduTiebaClient/12.50.1.1',
      'Accept': 'image/avif,image/webp,image/apng,image/png,image/jpeg,image/gif,image/*,*/*;q=0.8'
    };
    // 逐个候选源尝试下载（高清源失败 → 官方源兜底；官方源 102-124 缺失 → 高清源兜底）
    const candidates: string[] = EmojiLoader.emojiUrlCandidates(url);
    let lastError: Error = new Error('emoji download failed');
    for (const candidate of candidates) {
      try {
        const buf: ArrayBuffer = await HttpClient.getBinary(candidate, headers);
        if (!buf || buf.byteLength === 0) {
          lastError = new Error('emoji bytes empty');
          continue;
        }
        // 正确解码流程：图像文件字节 → ImageSource → PixelMap
        // 注意 createPixelMap(colors, opts) 的首参是原始像素数据，不能直接喂 PNG/GIF 文件字节
        const imageSource: image.ImageSource = image.createImageSource(buf);
        try {
          const pixelMap: image.PixelMap = await imageSource.createPixelMap();
          return pixelMap;
        } finally {
          imageSource.release();
        }
      } catch (err) {
        lastError = err instanceof Error ? err : new Error(String(err));
      }
    }
    throw lastError;
  }

  static prefetch(urls: string[]): void {
    for (const u of urls ?? []) {
      if (!u || u.length === 0) continue;
      if (EmojiLoader.has(u)) continue;
      if (EmojiLoader.hasInFlight(u)) continue;
      EmojiLoader.ensure(u).catch(() => { /* ignore */ });
    }
  }
}
