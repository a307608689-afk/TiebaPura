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
import { AuthManager } from './AuthManager';

/** 单吧签到本地记录（date 为 YYYY-MM-DD，days 为连续签到天数） */
interface ForumSignRecord {
  date: string;
  days: number;
}

/**
 * 单吧签到状态本地存储（纯静态工具）：
 * 吧头接口 frs/page 不返回签到态，故签到结果统一在此落盘 ——
 * · 吧主页据此在重进时回显「已签N天」；
 * · 一键签到据此过滤「当天已经签到过的吧」，避免重复请求。
 * key 按「账号 uid + 吧名」隔离，避免多账号切换时串状态。
 */
export class ForumSignStore {
  /** 本地日期戳（YYYY-MM-DD），用于判断签到记录是否属于「今天」 */
  static todayStamp(): string {
    const d: Date = new Date();
    const m: number = d.getMonth() + 1;
    const day: number = d.getDate();
    return `${d.getFullYear()}-${m < 10 ? '0' + m : m}-${day < 10 ? '0' + day : day}`;
  }

  /** 当前账号下签到记录的 key 前缀（批量读取用） */
  private static prefix(): string {
    const user = AuthManager.getInstance().getUser();
    const uid: string = user?.userId ?? '';
    return `${CACHE_KEY.FORUM_SIGN_STATE}_${uid}_`;
  }

  private static keyOf(forumName: string): string {
    return `${ForumSignStore.prefix()}${forumName}`;
  }

  /**
   * 解析单条记录：仅当记录日期为今天时返回连续天数（天数缺失按 1 兜底，
   * 如服务端返回「已经签过」拿不到天数），否则返回 0（视为今日未签到）。
   */
  private static parse(raw: string | undefined): number {
    if (raw === undefined) {
      return 0;
    }
    try {
      const rec = JSON.parse(raw) as ForumSignRecord;
      if (`${rec.date ?? ''}` !== ForumSignStore.todayStamp()) {
        return 0;
      }
      const days: number = parseInt(`${rec.days ?? 0}`, 10) || 0;
      return days > 0 ? days : 1;
    } catch (_) {
      return 0;
    }
  }

  /** 读取某吧今日签到连续天数（0 = 今日未签到） */
  static async loadSignDays(forumName: string): Promise<number> {
    if (forumName.length === 0) {
      return 0;
    }
    const raw: string | undefined = await CacheManager.getInstance().get(ForumSignStore.keyOf(forumName));
    return ForumSignStore.parse(raw);
  }

  /** 一次性读取当前账号下「今日已签到」的吧名集合（一键签到过滤用，避免逐吧读盘） */
  static async loadSignedTodaySet(): Promise<Set<string>> {
    const prefix: string = ForumSignStore.prefix();
    const map: Map<string, string> = await CacheManager.getInstance().getAllByPrefix(prefix);
    const set: Set<string> = new Set<string>();
    map.forEach((value: string, key: string) => {
      if (ForumSignStore.parse(value) > 0) {
        set.add(key.slice(prefix.length));
      }
    });
    return set;
  }

  /** 写入某吧今日签到记录（date + 连续天数，天数非法时按 1 兜底） */
  static async saveSignDays(forumName: string, days: number): Promise<void> {
    if (forumName.length === 0) {
      return;
    }
    try {
      const rec: ForumSignRecord = { date: ForumSignStore.todayStamp(), days: days > 0 ? days : 1 };
      await CacheManager.getInstance().put(ForumSignStore.keyOf(forumName), JSON.stringify(rec));
    } catch (_) {
      // 持久化失败不影响签到交互（内存态已生效）
    }
  }

  /** 批量写入今日签到记录（天数未知时按 1 兜底，如官方批量签到结果） */
  static async saveSignDaysBatch(forumNames: string[], days: number): Promise<void> {
    for (const name of forumNames) {
      await ForumSignStore.saveSignDays(name, days);
    }
  }
}
