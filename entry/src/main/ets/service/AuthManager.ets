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

import { common } from '@kit.AbilityKit';
import { CacheManager } from '../cache/CacheManager';
import { CACHE_KEY, COOKIE_BDUSS } from '../common/Constants';
import { UserInfo } from '../model/DataModel';

/**
 * 登录态管理。
 * 贴吧网页端依赖 Cookie 中的 BDUSS 标识登录态。
 * 提供 Cookie 的设置/读取/清除，以及当前用户信息的缓存。
 */
export class AuthManager {
  private static instance: AuthManager | null = null;
  private cookieStr: string = '';
  private userInfo: UserInfo | null = null;
  private inited: boolean = false;

  static getInstance(): AuthManager {
    if (AuthManager.instance === null) {
      AuthManager.instance = new AuthManager();
    }
    return AuthManager.instance;
  }

  /**
   * 初始化：从缓存恢复 Cookie 与用户信息
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.inited) {
      return;
    }
    this.inited = true;
    const cache = CacheManager.getInstance();
    await cache.init(context);
    this.cookieStr = (await cache.get(CACHE_KEY.LOGIN_COOKIE)) ?? '';
    const userJson = await cache.get(CACHE_KEY.LOGIN_USER);
    if (userJson) {
      try {
        this.userInfo = JSON.parse(userJson) as UserInfo;
      } catch (e) {
        this.userInfo = null;
      }
    }
  }

  /**
   * 是否已登录
   */
  isLogin(): boolean {
    return this.cookieStr.includes(COOKIE_BDUSS) || (this.userInfo?.isLogin ?? false);
  }

  /**
   * 获取当前用户
   */
  getUser(): UserInfo | null {
    return this.userInfo;
  }

  /**
   * 获取完整 Cookie 头
   */
  getCookieHeader(): string {
    return this.cookieStr;
  }

  /**
   * 提取 BDUSS
   * v64 防护：若 BDUSS 值为 "deleted" 或过短（<20），视为无效返回空串，
   * 避免把服务端删除标记当登录态使用
   */
  getBduss(): string {
    const m = /BDUSS=([^;]+)/.exec(this.cookieStr);
    if (!m) {
      return '';
    }
    const v = m[1];
    if (v === 'deleted' || v.length < 20) {
      return '';
    }
    return v;
  }

  /**
   * 设置 Cookie（用户粘贴的完整 Cookie 字符串，或仅 BDUSS）
   */
  async setCookie(raw: string): Promise<void> {
    let cookie = raw.trim();
    // 若只传了 BDUSS 值本身（不含 BDUSS=），自动补全
    if (cookie.length > 0 && !cookie.includes('=')) {
      cookie = `${COOKIE_BDUSS}=${cookie}`;
    }
    this.cookieStr = cookie;
    await CacheManager.getInstance().put(CACHE_KEY.LOGIN_COOKIE, cookie);
  }

  /**
   * 保存用户信息
   */
  async setUserInfo(info: UserInfo): Promise<void> {
    this.userInfo = info;
    await CacheManager.getInstance().put(CACHE_KEY.LOGIN_USER, JSON.stringify(info));
  }

  /**
   * 退出登录
   */
  async logout(): Promise<void> {
    this.cookieStr = '';
    this.userInfo = null;
    const cache = CacheManager.getInstance();
    await cache.delete(CACHE_KEY.LOGIN_COOKIE);
    await cache.delete(CACHE_KEY.LOGIN_USER);
  }
}
