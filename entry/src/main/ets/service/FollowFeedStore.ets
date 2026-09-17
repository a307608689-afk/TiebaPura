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
 * 「仅推荐关注的吧」聚合时间线引擎（游标式供给 + 本地待展示池 + 已消费记录）。
 *
 * 设计（替代旧「推荐流过滤 + 随机双槽补采」方案）：
 * - PerBarCursor：每个关注吧独立翻页游标（page 1→MAX_PAGE 深挖 + sort_type 随机起点），
 *   轮转按「最久未拉优先」确定性取样，全部翻尽后回卷到第 1 页并翻转 sort_type；
 * - PendingPool：本地待展示池（时间降序，容量封顶），进池时单点去重
 *   （已消费记录 + 池内 + 排除集 + 年龄下限一次滤完），渲染消费即出池；
 * - Consumed：已展示 tid 记录（FIFO 封顶 + TTL 过期），跨重启持久化，
 *   重启/隔天后看过的帖不再回推——治「一段时间内刷出重复贴」的根。
 *
 * 三件套全部经 CacheManager 落盘；换号 resetAll 全清，切开关不清任何去重状态。
 */

import { CacheManager } from '../cache/CacheManager';
import { ThreadItem } from '../model/DataModel';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'FollowFeedStore';

// ===== 可调参数 =====
/** 待展示池容量封顶 */
export const POOL_CAP: number = 200;
/** 水位线低位：低于此值触发补货 */
export const POOL_LOW: number = 30;
/** 水位线高位：单次补货目标 */
export const POOL_HIGH: number = 60;
/** 每轮补货拉取的吧数（小步高频，控风控压力） */
export const BARS_PER_ROUND: number = 5;
/** 单吧单页拉取条数 */
export const BAR_RN: number = 8;
/** 单吧翻页深度上限（过深多为极旧库存） */
export const MAX_PAGE: number = 10;
/** 已消费记录条数上限 */
export const CONSUMED_CAP: number = 2000;
/** 已消费记录 TTL：7 天（覆盖贴吧热帖复推周期） */
export const CONSUMED_TTL_MS: number = 7 * 24 * 3600 * 1000;
/** 进池年龄下限：超过 7 天的旧帖不进池（防「挖坟感」） */
export const THREAD_MAX_AGE_MS: number = 7 * 24 * 3600 * 1000;

const KEY_CURSORS: string = 'followfeed_cursors_v1';
const KEY_CONSUMED: string = 'followfeed_consumed_v1';
const KEY_POOL: string = 'followfeed_pool_v1';

/** 解析帖子时间字符串 → 毫秒时间戳（兼容秒级/毫秒级数字与格式化字符串），失败返回 0 */
export function threadTs(createTime: string): number {
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

/** 帖子按发布时间降序（聚合时间线的统一展示顺序，确定性、无随机） */
export function sortThreadsByTimeDesc(list: ThreadItem[]): ThreadItem[] {
  list.sort((a: ThreadItem, b: ThreadItem): number => threadTs(b.createTime) - threadTs(a.createTime));
  return list;
}

/** 单吧游标 */
export class BarCursor {
  page: number = 1;
  sortType: number = 0;
  lastFetchedAt: number = 0;
  exhausted: boolean = false;
}

/** 单吧拉取请求（游标取用后的任务描述） */
class PickedBar {
  name: string = '';
  sortType: number = 0;
  page: number = 1;
}

/** 游标持久化条目 */
interface CursorEntry {
  name: string;
  page: number;
  sortType: number;
  lastFetchedAt: number;
  exhausted: boolean;
}

/** 已消费持久化条目 */
interface ConsumedEntry {
  tid: string;
  ts: number;
}

/** 池持久化载荷 */
interface PoolPayload {
  data: ThreadItem[];
  savedAt: number;
}

/** 单吧拉取器：由宿主页注入（内含请求条数与超时包装） */
export type BarFetcher = (name: string, sortType: number, page: number) => Promise<ThreadItem[]>;

export class FollowFeedStore {
  private cursors: Map<string, BarCursor> = new Map<string, BarCursor>();
  private pool: ThreadItem[] = [];
  private poolTids: Set<string> = new Set<string>();
  private consumed: Map<string, number> = new Map<string, number>();
  private consumedQueue: string[] = [];
  private bars: string[] = [];
  private fetcher: BarFetcher | null = null;
  private loaded: boolean = false;
  private refilling: boolean = false;
  /** 补货连续零进度轮数（>=2 视为枯竭，熔断停止） */
  private zeroRounds: number = 0;
  private saveScheduled: boolean = false;

  /** 注入单吧拉取器（宿主页组装：fetchForumFeedOnce + 超时包装） */
  setFetcher(f: BarFetcher): void {
    this.fetcher = f;
  }

  /** 注入关注吧名集合（每次进入仅关注模式/换号后调用） */
  setBars(names: Set<string>): void {
    const arr: string[] = [];
    names.forEach((n: string): void => {
      if (n.length > 0) {
        arr.push(n);
      }
    });
    this.bars = arr;
  }

  /** 持久化恢复（幂等，仅首次生效） */
  async load(): Promise<void> {
    if (this.loaded) {
      return;
    }
    this.loaded = true;
    try {
      const cm: CacheManager = CacheManager.getInstance();
      const now: number = Date.now();
      const cursorsRaw: string | undefined = await cm.get(KEY_CURSORS);
      if (cursorsRaw !== undefined && cursorsRaw.length > 0) {
        const entries: CursorEntry[] = JSON.parse(cursorsRaw) as CursorEntry[];
        for (const e of entries) {
          if (!e || typeof e.name !== 'string' || e.name.length === 0) {
            continue;
          }
          const c: BarCursor = new BarCursor();
          c.page = typeof e.page === 'number' && e.page >= 1 ? e.page : 1;
          c.sortType = e.sortType === 1 ? 1 : 0;
          c.lastFetchedAt = typeof e.lastFetchedAt === 'number' ? e.lastFetchedAt : 0;
          c.exhausted = e.exhausted === true;
          this.cursors.set(e.name, c);
        }
      }
      const consumedRaw: string | undefined = await cm.get(KEY_CONSUMED);
      if (consumedRaw !== undefined && consumedRaw.length > 0) {
        const entries: ConsumedEntry[] = JSON.parse(consumedRaw) as ConsumedEntry[];
        for (const e of entries) {
          if (!e || typeof e.tid !== 'string' || e.tid.length === 0) {
            continue;
          }
          // TTL 过滤：过期记录视为未消费（老帖可自然回归）
          if (typeof e.ts !== 'number' || now - e.ts > CONSUMED_TTL_MS) {
            continue;
          }
          this.consumed.set(e.tid, e.ts);
          this.consumedQueue.push(e.tid);
        }
      }
      const poolRaw: string | undefined = await cm.get(KEY_POOL);
      if (poolRaw !== undefined && poolRaw.length > 0) {
        const payload: PoolPayload = JSON.parse(poolRaw) as PoolPayload;
        if (payload && Array.isArray(payload.data)) {
          const fresh: ThreadItem[] = [];
          for (const it of payload.data) {
            if (!it || typeof it.tid !== 'string' || it.tid.length === 0) {
              continue;
            }
            if (this.consumed.has(it.tid)) {
              continue;
            }
            // 保存期间跨过年龄线的旧帖出池
            const ts: number = threadTs(it.createTime);
            if (ts > 0 && now - ts > THREAD_MAX_AGE_MS) {
              continue;
            }
            fresh.push(it);
          }
          sortThreadsByTimeDesc(fresh);
          this.pool = fresh.slice(0, POOL_CAP);
          for (const it of this.pool) {
            this.poolTids.add(it.tid);
          }
        }
      }
      hilog.info(0x0000, TAG, 'load: cursors=%{public}d consumed=%{public}d pool=%{public}d',
        this.cursors.size, this.consumed.size, this.pool.length);
    } catch (e) {
      // 恢复失败按空引擎运行，不影响可用性
      hilog.error(0x0000, TAG, 'load error: %{public}s', JSON.stringify(e));
    }
  }

  /** 该 tid 是否在已消费记录中（TTL 内） */
  hasConsumed(tid: string): boolean {
    return this.consumed.has(tid);
  }

  /** 批量登记已展示 tid（FIFO 封顶；含节流落盘） */
  markConsumed(list: ThreadItem[]): void {
    const now: number = Date.now();
    let changed: boolean = false;
    for (const t of list) {
      if (!t || t.tid.length === 0 || this.consumed.has(t.tid)) {
        continue;
      }
      this.consumed.set(t.tid, now);
      this.consumedQueue.push(t.tid);
      changed = true;
    }
    while (this.consumedQueue.length > CONSUMED_CAP) {
      const oldest: string | undefined = this.consumedQueue.shift();
      if (oldest !== undefined) {
        this.consumed.delete(oldest);
      }
    }
    if (changed) {
      this.persistSoon();
    }
  }

  poolSize(): number {
    return this.pool.length;
  }

  /** 池是否低于水位线低位（需补货） */
  poolLow(): boolean {
    return this.pool.length < POOL_LOW;
  }

  /** 是否枯竭：池空且补货连续零进度（宿主据此走空态/空轮保护） */
  isStarved(): boolean {
    return this.pool.length === 0 && this.zeroRounds >= 2;
  }

  /** 从池头出 n 条（时间降序的池头即最新），出池即登记已消费 */
  take(n: number): ThreadItem[] {
    const out: ThreadItem[] = [];
    while (out.length < n && this.pool.length > 0) {
      const item: ThreadItem | undefined = this.pool.shift();
      if (item === undefined) {
        break;
      }
      this.poolTids.delete(item.tid);
      out.push(item);
    }
    if (out.length > 0) {
      this.markConsumed(out);
    }
    return out;
  }

  /**
   * 批量入池：单点去重（已消费 + 池内 + 排除集）+ 年龄下限过滤，
   * 入池后按时间降序重排并封顶。返回实际入池条数。
   */
  mergeIntoPool(list: ThreadItem[], exclude?: Set<string>): number {
    const now: number = Date.now();
    let added: number = 0;
    for (const item of list) {
      if (!item || item.tid.length === 0) {
        continue;
      }
      if (this.consumed.has(item.tid) || this.poolTids.has(item.tid)) {
        continue;
      }
      if (exclude !== undefined && exclude.has(item.tid)) {
        continue;
      }
      const ts: number = threadTs(item.createTime);
      if (ts > 0 && now - ts > THREAD_MAX_AGE_MS) {
        continue;
      }
      this.pool.push(item);
      this.poolTids.add(item.tid);
      added++;
    }
    if (added > 0) {
      sortThreadsByTimeDesc(this.pool);
      while (this.pool.length > POOL_CAP) {
        const tail: ThreadItem | undefined = this.pool.pop();
        if (tail !== undefined) {
          this.poolTids.delete(tail.tid);
        }
      }
      this.persistSoon();
    }
    return added;
  }

  /**
   * 补货：轮转拉取直到池达目标水位或枯竭熔断。
   * 每轮取 BARS_PER_ROUND 个「最久未拉且未翻尽」的吧并发拉取；
   * 全部翻尽时回卷（页码归 1 + sort_type 翻转）再试；连续 2 轮零进度熔断。
   */
  async refill(minTarget: number): Promise<void> {
    if (this.refilling || this.fetcher === null || this.bars.length === 0) {
      return;
    }
    this.refilling = true;
    try {
      let guard: number = 0;
      while (this.pool.length < minTarget && guard < 20) {
        guard++;
        const picked: PickedBar[] = this.pickRound();
        if (picked.length === 0) {
          break;
        }
        const tasks: Promise<ThreadItem[]>[] = [];
        for (const pk of picked) {
          tasks.push(this.fetcher(pk.name, pk.sortType, pk.page));
        }
        const chunks: ThreadItem[][] = await Promise.all(tasks);
        let added: number = 0;
        for (let i: number = 0; i < chunks.length; i++) {
          added += this.mergeIntoPool(chunks[i]);
          this.advanceCursor(picked[i].name);
        }
        await this.persist();
        if (added === 0) {
          this.zeroRounds++;
        } else {
          this.zeroRounds = 0;
        }
        if (this.zeroRounds >= 2) {
          break;
        }
      }
      hilog.info(0x0000, TAG, 'refill done: pool=%{public}d zeroRounds=%{public}d', this.pool.length, this.zeroRounds);
    } catch (e) {
      hilog.error(0x0000, TAG, 'refill error: %{public}s', JSON.stringify(e));
    } finally {
      this.refilling = false;
    }
  }

  /** 换号全清：内存三件套 + 落盘键一并删除 */
  async resetAll(): Promise<void> {
    this.cursors.clear();
    this.pool = [];
    this.poolTids.clear();
    this.consumed.clear();
    this.consumedQueue = [];
    this.zeroRounds = 0;
    try {
      const cm: CacheManager = CacheManager.getInstance();
      await cm.delete(KEY_CURSORS);
      await cm.delete(KEY_CONSUMED);
      await cm.delete(KEY_POOL);
    } catch (e) {
      hilog.error(0x0000, TAG, 'resetAll error: %{public}s', JSON.stringify(e));
    }
  }

  /** 选一轮拉取目标：未翻尽的吧按最久未拉优先；全翻尽时回卷后重选 */
  private pickRound(): PickedBar[] {
    let candidates: PickedBar[] = this.pickFromCursor(false);
    if (candidates.length === 0) {
      // 全部翻尽：回卷（页码归 1、sort_type 翻转、清翻尽标记），换一段内容池再试
      this.cursors.forEach((c: BarCursor): void => {
        c.page = 1;
        c.sortType = c.sortType === 0 ? 1 : 0;
        c.exhausted = false;
      });
      candidates = this.pickFromCursor(true);
    }
    return candidates;
  }

  /** 从游标表挑未翻尽、最久未拉的前 BARS_PER_ROUND 个吧 */
  private pickFromCursor(allowAny: boolean): PickedBar[] {
    const refs: CursorEntry[] = [];
    this.cursors.forEach((c: BarCursor, name: string): void => {
      if (!this.bars.includes(name)) {
        return;
      }
      if (c.exhausted && !allowAny) {
        return;
      }
      const e: CursorEntry = {
        name: name, page: c.page, sortType: c.sortType,
        lastFetchedAt: c.lastFetchedAt, exhausted: c.exhausted
      };
      refs.push(e);
    });
    // 新吧（无游标）lastFetchedAt=0 天然排前，优先建立游标
    refs.sort((a: CursorEntry, b: CursorEntry): number => a.lastFetchedAt - b.lastFetchedAt);
    const picked: PickedBar[] = [];
    for (const r of refs) {
      if (picked.length >= BARS_PER_ROUND) {
        break;
      }
      const pk: PickedBar = new PickedBar();
      pk.name = r.name;
      pk.sortType = r.sortType;
      pk.page = r.page;
      picked.push(pk);
    }
    return picked;
  }

  /** 拉取后推进游标：页码 +1，翻尽标记 exhausted；lastFetchedAt 恒更新 */
  private advanceCursor(name: string): void {
    const c: BarCursor | undefined = this.ensureCursor(name);
    c.lastFetchedAt = Date.now();
    if (c.page >= MAX_PAGE) {
      c.exhausted = true;
    } else {
      c.page++;
    }
  }

  private ensureCursor(name: string): BarCursor {
    let c: BarCursor | undefined = this.cursors.get(name);
    if (c === undefined) {
      c = new BarCursor();
      c.sortType = Math.random() < 0.5 ? 0 : 1;
      this.cursors.set(name, c);
    }
    return c;
  }

  /** 节流落盘：1.5s 内合并多次写 */
  private persistSoon(): void {
    if (this.saveScheduled) {
      return;
    }
    this.saveScheduled = true;
    setTimeout(() => {
      this.saveScheduled = false;
      this.persist();
    }, 1500);
  }

  private async persist(): Promise<void> {
    try {
      const cm: CacheManager = CacheManager.getInstance();
      const cursorEntries: CursorEntry[] = [];
      this.cursors.forEach((c: BarCursor, name: string): void => {
        const e: CursorEntry = {
          name: name, page: c.page, sortType: c.sortType,
          lastFetchedAt: c.lastFetchedAt, exhausted: c.exhausted
        };
        cursorEntries.push(e);
      });
      await cm.put(KEY_CURSORS, JSON.stringify(cursorEntries));
      const consumedEntries: ConsumedEntry[] = [];
      this.consumedQueue.forEach((tid: string): void => {
        const ts: number | undefined = this.consumed.get(tid);
        if (ts !== undefined) {
          const e: ConsumedEntry = { tid: tid, ts: ts };
          consumedEntries.push(e);
        }
      });
      await cm.put(KEY_CONSUMED, JSON.stringify(consumedEntries));
      const payload: PoolPayload = { data: this.pool, savedAt: Date.now() };
      await cm.put(KEY_POOL, JSON.stringify(payload));
    } catch (e) {
      hilog.error(0x0000, TAG, 'persist error: %{public}s', JSON.stringify(e));
    }
  }
}
