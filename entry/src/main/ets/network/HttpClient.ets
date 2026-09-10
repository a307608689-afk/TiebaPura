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

import { rcp } from '@kit.RemoteCommunicationKit';
import { http } from '@kit.NetworkKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AuthManager } from '../service/AuthManager';

const TAG: string = 'HttpClient';

/** 重定向探测结果 */
export interface RedirectResult {
  finalUrl: string;
  setCookies: string[];
}

/**
 * 统一网络请求封装：固定重定向上限、超时和业务错误映射。
 */
export class HttpClient {
  private static session: rcp.Session | null = null;

  private static getSession(): rcp.Session {
    if (HttpClient.session === null) {
      HttpClient.session = rcp.createSession({
        requestConfiguration: {
          transfer: {
            autoRedirect: true,
            maxAutoRedirects: 10,
            timeout: {
              connectMs: 15000,
              transferMs: 30000,
            },
          },
        },
      });
    }
    return HttpClient.session;
  }

  private static buildHeaders(extra?: Record<string, string>): Record<string, string> {
    // 先放入调用方传入的 headers（如 User-Agent、Content-Type），
    // 再用默认值填充缺失项，确保调用方自定义值不被覆盖
    const headers: Record<string, string> = {};
    if (extra) {
      Object.keys(extra).forEach((key: string) => {
        headers[key] = extra[key];
      });
    }
    // 仅在调用方未设置时才填充默认值
    if (!headers['User-Agent']) {
      headers['User-Agent'] = 'Mozilla/5.0 (Linux; HarmonyOS) AppleWebKit/537.36 Chrome/120 Safari/537.36';
    }
    if (!headers['Accept']) {
      headers['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8';
    }
    if (!headers['Accept-Language']) {
      headers['Accept-Language'] = 'zh-CN,zh;q=0.9';
    }
    if (!headers['Referer']) {
      headers['Referer'] = 'https://tieba.baidu.com/';
    }
    // 注入 Cookie（含 BDUSS），确保写接口携带登录态
    const cookie = AuthManager.getInstance().getCookieHeader();
    if (cookie.length > 0 && !headers['Cookie']) {
      headers['Cookie'] = cookie;
    }
    return headers;
  }

  static async get(url: string, extraHeaders?: Record<string, string>): Promise<string> {
    return HttpClient.request(url, 'GET', undefined, extraHeaders);
  }

  static async getBinary(url: string, extraHeaders?: Record<string, string>): Promise<ArrayBuffer> {
    return HttpClient.requestBinaryGet(url, extraHeaders);
  }

  static async postForm(url: string, formData: Record<string, string>, extraHeaders?: Record<string, string>): Promise<string> {
    const pairs: string[] = [];
    Object.keys(formData).forEach((key: string) => {
      pairs.push(`${encodeURIComponent(key)}=${encodeURIComponent(formData[key])}`);
    });
    const headers: Record<string, string> = {
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
    };
    if (extraHeaders) {
      Object.keys(extraHeaders).forEach((key: string) => {
        headers[key] = extraHeaders[key];
      });
    }
    // 注入 Cookie（含 BDUSS）等默认 headers，确保写接口携带登录态
    const mergedHeaders = HttpClient.buildHeaders(headers);
    return HttpClient.request(url, 'POST', pairs.join('&'), mergedHeaders);
  }

  static async postBinary(url: string, body: ArrayBuffer, extraHeaders?: Record<string, string>): Promise<string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/octet-stream',
    };
    if (extraHeaders) {
      Object.keys(extraHeaders).forEach((key: string) => {
        headers[key] = extraHeaders[key];
      });
    }
    return HttpClient.request(url, 'POST', body, headers);
  }

  static async postProtoMultipart(url: string, body: ArrayBuffer, extraHeaders?: Record<string, string>): Promise<ArrayBuffer> {
    const boundary = '--------7da3d81520810*';
    const prefix = `--${boundary}\r\nContent-Disposition: form-data; name="data"; filename="file"\r\nContent-Type: application/octet-stream\r\n\r\n`;
    const suffix = `\r\n--${boundary}--\r\n`;
    const encoder = new util.TextEncoder();
    const prefixBytes = encoder.encode(prefix);
    const suffixBytes = encoder.encode(suffix);
    const merged = new Uint8Array(prefixBytes.length + body.byteLength + suffixBytes.length);
    merged.set(prefixBytes, 0);
    merged.set(new Uint8Array(body), prefixBytes.length);
    merged.set(suffixBytes, prefixBytes.length + body.byteLength);
    const headers: Record<string, string> = {
      'Content-Type': `multipart/form-data; boundary=${boundary}`,
      'Accept': 'application/octet-stream',
    };
    if (extraHeaders) {
      Object.keys(extraHeaders).forEach((key: string) => {
        headers[key] = extraHeaders[key];
      });
    }
    return HttpClient.requestBinary(url, merged.buffer as ArrayBuffer, headers);
  }

  static async postEncoded(url: string, body: string, extraHeaders?: Record<string, string>): Promise<string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
    };
    if (extraHeaders) {
      Object.keys(extraHeaders).forEach((key: string) => {
        headers[key] = extraHeaders[key];
      });
    }
    return HttpClient.request(url, 'POST', body, headers);
  }

  static async md5(value: string): Promise<string> {
    const md = cryptoFramework.createMd('MD5');
    const encoder = new util.TextEncoder();
    await md.update({ data: encoder.encode(value) });
    const digest = await md.digest();
    let result = '';
    for (const byte of digest.data) {
      result += byte.toString(16).padStart(2, '0');
    }
    return result.toUpperCase();
  }

  private static async requestBinaryGet(url: string, headers?: Record<string, string>): Promise<ArrayBuffer> {
    try {
      const request = new rcp.Request(url, 'GET');
      request.headers = HttpClient.buildHeaders(headers);
      const response = await HttpClient.getSession().fetch(request);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.body ?? new ArrayBuffer(0);
      }
      throw new BizError(response.statusCode, `图片下载失败，状态码 ${response.statusCode}`);
    } catch (error) {
      const businessError = error as BusinessError;
      if (error instanceof BizError) {
        throw error;
      }
      throw new BizError(businessError.code ?? -1, businessError.message ?? '图片下载失败');
    }
  }

  private static async requestBinary(url: string, body: ArrayBuffer, headers?: Record<string, string>): Promise<ArrayBuffer> {
    try {
      const request = new rcp.Request(url, 'POST');
      request.headers = HttpClient.buildHeaders(headers);
      request.content = body;
      const response = await HttpClient.getSession().fetch(request);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.body ?? new ArrayBuffer(0);
      }
      throw new BizError(response.statusCode, `二进制请求失败，状态码 ${response.statusCode}`);
    } catch (error) {
      const businessError = error as BusinessError;
      if (error instanceof BizError) {
        throw error;
      }
      throw new BizError(businessError.code ?? -1, businessError.message ?? '二进制请求失败');
    }
  }

  /** 手动跟随重定向的 GET，返回最终 URL + 从每个跳转响应头收集的 Set-Cookie
   * 用途：BDUSS → tieba 域 STOKEN 换取（贴吧首页 302 链最后一跳写入 STOKEN）
   * v63：支持自定义 UA；跨跳 Cookie 用 Map 累积（只取 name=value，剔除 Path/Domain 属性）
   */
  static async getWithRedirectCookies(url: string, cookieHeader: string, userAgent?: string): Promise<RedirectResult> {
    const collected: string[] = [];
    let currentUrl = url;
    const ua: string = userAgent ?? 'Mozilla/5.0 (Linux; HarmonyOS) AppleWebKit/537.36 Chrome/120 Safari/537.36';
    // Map 累积 Cookie（同名覆盖）
    const cookieMap = new Map<string, string>();
    const cookieOrder: string[] = [];
    const putCookie = (name: string, value: string): void => {
      // 跳过服务端删除标记（BDUSS=deleted 等），保护有效登录态
      if (value === 'deleted' || value.length === 0) {
        return;
      }
      if (!cookieMap.has(name)) {
        cookieOrder.push(name);
      }
      cookieMap.set(name, value);
    };
    for (const part of cookieHeader.split(';')) {
      const kv: string = part.trim();
      const idx: number = kv.indexOf('=');
      if (idx > 0) {
        putCookie(kv.substring(0, idx), kv.substring(idx + 1));
      }
    }
    const serialize = (): string => {
      const parts: string[] = [];
      for (const name of cookieOrder) {
        parts.push(`${name}=${cookieMap.get(name)}`);
      }
      return parts.join('; ');
    };
    // 最多跟随 8 跳，防止死循环
    for (let hop = 0; hop < 8; hop++) {
      const session = rcp.createSession({
        requestConfiguration: {
          transfer: {
            autoRedirect: false,
            timeout: { connectMs: 15000, transferMs: 30000 },
          },
        },
      });
      try {
        const request = new rcp.Request(currentUrl, 'GET');
        request.headers = {
          'User-Agent': ua,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Referer': 'https://tieba.baidu.com/',
        };
        const cookieStr: string = serialize();
        if (cookieStr.length > 0) {
          request.headers['Cookie'] = cookieStr;
        }
        const response = await session.fetch(request);
        const status = response.statusCode;
        // 收集本跳的 Set-Cookie（可能数组或字符串）
        const respHeaders = response.headers ?? {};
        const rawSetCookie = (respHeaders as Record<string, Object>)['set-cookie']
          ?? (respHeaders as Record<string, Object>)['Set-Cookie'];
        if (rawSetCookie !== undefined && rawSetCookie !== null) {
          const list: string[] = Array.isArray(rawSetCookie)
            ? (rawSetCookie as Object[]).map((c: Object) => `${c}`)
            : [`${rawSetCookie}`];
          for (const raw of list) {
            collected.push(raw);
            const kv: string = raw.split(';')[0].trim();
            const idx: number = kv.indexOf('=');
            if (idx > 0) {
              putCookie(kv.substring(0, idx), kv.substring(idx + 1));
            }
          }
        }
        console.info(`[rcp] hop=${hop} url=${currentUrl} status=${status}`);
        // 非重定向 → 到达终点
        if (status < 300 || status >= 400) {
          await session.close();
          return { finalUrl: currentUrl, setCookies: collected };
        }
        // 30x：取 Location 继续跳
        const location = `${(respHeaders as Record<string, Object>)['location'] ?? (respHeaders as Record<string, Object>)['Location'] ?? ''}`;
        if (location.length === 0) {
          await session.close();
          return { finalUrl: currentUrl, setCookies: collected };
        }
        currentUrl = location.startsWith('http') ? location : HttpClient.resolveRelativeUrl(location, currentUrl);
        await session.close();
      } catch (e) {
        try {
          await session.close();
        } catch (closeErr) {
        }
        throw new BizError(-1, `重定向请求失败: ${(e as Error).message}`);
      }
    }
    return { finalUrl: currentUrl, setCookies: collected };
  }

  /** 安全版手动跟随重定向 GET（v64 新增）
   * 与 getWithRedirectCookies 相同，但遇到 passport/wappass 域的 Location 立即停止，
   * 避免触发百度 passport 风控（"Auth Login Params Not Corret" + BDUSS=deleted）
   */
  static async getWithRedirectCookiesSafe(url: string, cookieHeader: string, userAgent?: string): Promise<RedirectResult> {
    const collected: string[] = [];
    let currentUrl = url;
    const ua: string = userAgent ?? 'Mozilla/5.0 (Linux; HarmonyOS) AppleWebKit/537.36 Chrome/120 Safari/537.36';
    const cookieMap = new Map<string, string>();
    const cookieOrder: string[] = [];
    const putCookie = (name: string, value: string): void => {
      if (value === 'deleted' || value.length === 0) {
        return;
      }
      if (!cookieMap.has(name)) {
        cookieOrder.push(name);
      }
      cookieMap.set(name, value);
    };
    for (const part of cookieHeader.split(';')) {
      const kv: string = part.trim();
      const idx: number = kv.indexOf('=');
      if (idx > 0) {
        putCookie(kv.substring(0, idx), kv.substring(idx + 1));
      }
    }
    const serialize = (): string => {
      const parts: string[] = [];
      for (const name of cookieOrder) {
        parts.push(`${name}=${cookieMap.get(name)}`);
      }
      return parts.join('; ');
    };
    for (let hop = 0; hop < 8; hop++) {
      const session = rcp.createSession({
        requestConfiguration: {
          transfer: {
            autoRedirect: false,
            timeout: { connectMs: 15000, transferMs: 30000 },
          },
        },
      });
      try {
        const request = new rcp.Request(currentUrl, 'GET');
        request.headers = {
          'User-Agent': ua,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Referer': 'https://tieba.baidu.com/',
        };
        const cookieStr: string = serialize();
        if (cookieStr.length > 0) {
          request.headers['Cookie'] = cookieStr;
        }
        const response = await session.fetch(request);
        const status = response.statusCode;
        const respHeaders = response.headers ?? {};
        const rawSetCookie = (respHeaders as Record<string, Object>)['set-cookie']
          ?? (respHeaders as Record<string, Object>)['Set-Cookie'];
        if (rawSetCookie !== undefined && rawSetCookie !== null) {
          const list: string[] = Array.isArray(rawSetCookie)
            ? (rawSetCookie as Object[]).map((c: Object) => `${c}`)
            : [`${rawSetCookie}`];
          for (const raw of list) {
            collected.push(raw);
            const kv: string = raw.split(';')[0].trim();
            const idx: number = kv.indexOf('=');
            if (idx > 0) {
              putCookie(kv.substring(0, idx), kv.substring(idx + 1));
            }
          }
        }
        console.info(`[rcp-safe] hop=${hop} url=${currentUrl} status=${status}`);
        if (status < 300 || status >= 400) {
          await session.close();
          return { finalUrl: currentUrl, setCookies: collected };
        }
        const location = `${(respHeaders as Record<string, Object>)['location'] ?? (respHeaders as Record<string, Object>)['Location'] ?? ''}`;
        // 安全停止：下一跳是 passport/wappass 域则不跟随（保护登录态）
        if (location.includes('passport.baidu.com') || location.includes('wappass.baidu.com')) {
          console.info(`[rcp-safe] 下一跳为 passport 域，停止跟随: ${location.substring(0, 80)}`);
          await session.close();
          return { finalUrl: currentUrl, setCookies: collected };
        }
        if (location.length === 0) {
          await session.close();
          return { finalUrl: currentUrl, setCookies: collected };
        }
        currentUrl = location.startsWith('http') ? location : HttpClient.resolveRelativeUrl(location, currentUrl);
        await session.close();
      } catch (e) {
        try {
          await session.close();
        } catch (closeErr) {
        }
        throw new BizError(-1, `重定向请求失败: ${(e as Error).message}`);
      }
    }
    return { finalUrl: currentUrl, setCookies: collected };
  }

  /** 相对 URL 解析（ArkTS 无 URL 构造器，手动拼接） */
  private static resolveRelativeUrl(relative: string, baseUrl: string): string {
    try {
      // 从 baseUrl 提取 scheme://host[:port]
      const schemeMatch = /^[a-zA-Z]+:\/\/[^/]+/.exec(baseUrl);
      const origin = schemeMatch !== null ? schemeMatch[0] : '';
      if (origin.length === 0) {
        return relative;
      }
      if (relative.startsWith('/')) {
        return `${origin}${relative}`;
      }
      // 相对当前路径：取 baseUrl 目录
      const dirMatch = /^(.*\/)/.exec(baseUrl);
      const dir = dirMatch !== null ? dirMatch[1] : `${origin}/`;
      return `${dir}${relative}`;
    } catch (e) {
      return relative;
    }
  }

  /** 用 NetworkKit http 模块手动跟随重定向并收集每跳 Set-Cookie
   * v60 新增：rcp session 读不到 Set-Cookie 响应头（导致 STOKEN 永远换不到），
   * http.createHttp 可以完整读取响应头，用于 BDUSS → tieba 域 STOKEN 换取
   * v61：支持自定义 UA（桌面 UA 才能触发 STOKEN 下发）
   * v62：Cookie 跨跳用 Map 累积（同名覆盖），修复桌面站 BAIDUID 重定向循环
   */
  static async fetchRedirectSetCookies(url: string, cookieHeader: string, userAgent?: string): Promise<RedirectResult> {
    const collected: string[] = [];
    let currentUrl: string = url;
    const ua: string = userAgent ?? 'Mozilla/5.0 (Linux; HarmonyOS) AppleWebKit/537.36 Chrome/120 Safari/537.36';
    // 用 Map 累积 Cookie（同名覆盖，保持插入顺序）
    const cookieMap = new Map<string, string>();
    const cookieOrder: string[] = [];
    const putCookie = (name: string, value: string): void => {
      // 跳过服务端删除标记（BDUSS=deleted 等），保护有效登录态
      if (value === 'deleted' || value.length === 0) {
        return;
      }
      if (!cookieMap.has(name)) {
        cookieOrder.push(name);
      }
      cookieMap.set(name, value);
    };
    for (const part of cookieHeader.split(';')) {
      const kv: string = part.trim();
      const idx: number = kv.indexOf('=');
      if (idx > 0) {
        putCookie(kv.substring(0, idx), kv.substring(idx + 1));
      }
    }
    const serialize = (): string => {
      const parts: string[] = [];
      for (const name of cookieOrder) {
        parts.push(`${name}=${cookieMap.get(name)}`);
      }
      return parts.join('; ');
    };
    for (let hop = 0; hop < 8; hop++) {
      const httpRequest = http.createHttp();
      try {
        const headers: Record<string, string> = {
          'User-Agent': ua,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Referer': 'https://tieba.baidu.com/',
        };
        const cookieStr: string = serialize();
        if (cookieStr.length > 0) {
          headers['Cookie'] = cookieStr;
        }
        const response = await httpRequest.request(currentUrl, {
          method: http.RequestMethod.GET,
          header: headers,
          connectTimeout: 15000,
          readTimeout: 30000,
        });
        const status: number = response.responseCode;
        const respHeaders = response.header as Record<string, Object>;
        const rawSetCookie: Object | undefined = respHeaders['set-cookie'] ?? respHeaders['Set-Cookie'];
        if (rawSetCookie !== undefined && rawSetCookie !== null) {
          const list: string[] = Array.isArray(rawSetCookie)
            ? (rawSetCookie as Object[]).map((c: Object) => `${c}`)
            : [`${rawSetCookie}`];
          for (const raw of list) {
            collected.push(raw);
            const kv: string = raw.split(';')[0].trim();
            const idx: number = kv.indexOf('=');
            if (idx > 0) {
              putCookie(kv.substring(0, idx), kv.substring(idx + 1));
            }
          }
        }
        console.info(`[http] hop=${hop} url=${currentUrl} status=${status}`);
        if (status < 300 || status >= 400) {
          return { finalUrl: currentUrl, setCookies: collected };
        }
        const location: string = `${respHeaders['location'] ?? respHeaders['Location'] ?? ''}`;
        if (location.length === 0) {
          return { finalUrl: currentUrl, setCookies: collected };
        }
        currentUrl = location.startsWith('http') ? location : HttpClient.resolveRelativeUrl(location, currentUrl);
      } finally {
        httpRequest.destroy();
      }
    }
    return { finalUrl: currentUrl, setCookies: collected };
  }

  /** 单次 GET（不跟随重定向链合并），返回 Set-Cookie 列表，用于 STOKEN 两跳预热
   * v61 新增：第一跳拿 BAIDUID，第二跳带 BAIDUID+BDUSS 才下发 STOKEN
   */
  static async fetchSetCookiesOnce(url: string, cookieHeader: string, userAgent: string): Promise<string[]> {
    const httpRequest = http.createHttp();
    try {
      const headers: Record<string, string> = {
        'User-Agent': userAgent,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'Referer': 'https://tieba.baidu.com/',
      };
      if (cookieHeader.length > 0) {
        headers['Cookie'] = cookieHeader;
      }
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: 15000,
        readTimeout: 30000,
      });
      const respHeaders = response.header as Record<string, Object>;
      const rawSetCookie: Object | undefined = respHeaders['set-cookie'] ?? respHeaders['Set-Cookie'];
      const collected: string[] = [];
      if (rawSetCookie !== undefined && rawSetCookie !== null) {
        if (Array.isArray(rawSetCookie)) {
          for (const c of rawSetCookie as Object[]) {
            collected.push(`${c}`);
          }
        } else {
          collected.push(`${rawSetCookie}`);
        }
      }
      console.info(`[http-once] url=${url} status=${response.responseCode} setCookies=${collected.length}`);
      return collected;
    } finally {
      httpRequest.destroy();
    }
  }

  private static async request(url: string, method: string, body: string | ArrayBuffer | undefined, headers?: Record<string, string>): Promise<string> {
    try {
      const request = new rcp.Request(url, method);
      request.headers = HttpClient.buildHeaders(headers);
      if (body !== undefined && method === 'POST') {
        request.content = body;
      }
      const response = await HttpClient.getSession().fetch(request);
      const status = response.statusCode;
      if (status >= 200 && status < 300) {
        return await response.toString() ?? '';
      }
      if (status >= 300 && status < 400) {
        throw new BizError(status, '网络重定向过多，请稍后重试');
      }
      if (status === 403) {
        throw new BizError(403, '访问被拒绝，可能触发贴吧风控');
      }
      if (status === 404) {
        throw new BizError(404, '内容不存在');
      }
      throw new BizError(status, `请求失败，状态码 ${status}`);
    } catch (error) {
      const businessError = error as BusinessError;
      if (error instanceof BizError) {
        throw error;
      }
      const message: string = businessError.message ?? '网络请求失败，请检查网络连接';
      hilog.error(0x0000, TAG, 'request error: %{public}s', message);
      if (businessError.code === 1007900047 || message.toLowerCase().includes('redirect')) {
        throw new BizError(31001, '网络重定向过多，请稍后重试');
      }
      if (message.toLowerCase().includes('timeout')) {
        throw new BizError(31002, '网络请求超时，请检查网络连接');
      }
      throw new BizError(businessError.code ?? -1, message);
    }
  }
}

export class BizError extends Error {
  code: number;

  constructor(code: number, message: string) {
    super(message);
    this.code = code;
    this.name = 'BizError';
  }
}
