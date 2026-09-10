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
import { CategoryMapping, FavCategory, PinRecord } from '../model/DataModel';

/** 内置「未分类」分类 ID */
export const CATEGORY_DEFAULT_ID: string = 'default';

/** 删除分类的返回结果 */
export interface CategoryRemovalResult {
  categories: FavCategory[];
  mappings: CategoryMapping[];
}

/** 备份文件 folder 条目（schema §2.5：threads[].pid 可空字符串，导入侧容错） */
export interface BackupFolder {
  id: string;
  name: string;
  cover: string;
  createdAt: number;
  threads: BackupThread[];
}

/** 备份文件帖子条目 */
export interface BackupThread {
  tid: string;
  pid: string;
  addedAt: number;
}

/** 备份文件顶层结构（schema §2.5） */
export interface BackupPayload {
  app: string;
  version: number;
  exportedAt: string;
  folders: BackupFolder[];
}

/** 备份导入增量合并汇总（§6 口径：X 新分类 + Y 同名合并 + Z 无效记录） */
export interface BackupImportSummary {
  added: number;
  merged: number;
  skipped: number;
}

/**
 * 收藏模块本地存储（置顶数据，Preferences 承载）。
 * 缓存键规则：{key}_{accountId}，多账号隔离，与 CACHE_KEY 风格统一。
 */
export class FavoriteStore {
  private static instance: FavoriteStore | null = null;

  static getInstance(): FavoriteStore {
    if (FavoriteStore.instance === null) {
      FavoriteStore.instance = new FavoriteStore();
    }
    return FavoriteStore.instance;
  }

  /** 读取置顶记录列表（按置顶时间倒序） */
  async loadPins(accountId: string, key: string): Promise<PinRecord[]> {
    if (accountId.length === 0) {
      return [];
    }
    const raw = await CacheManager.getInstance().get(`${key}_${accountId}`);
    if (!raw) {
      return [];
    }
    try {
      const parsed = JSON.parse(raw) as PinRecord[];
      return Array.isArray(parsed) ? parsed : [];
    } catch (e) {
      return [];
    }
  }

  async loadPinnedFolders(accountId: string): Promise<PinRecord[]> {
    return await this.loadPins(accountId, CACHE_KEY.FAVORITE_PIN_FOLDER);
  }

  async loadPinnedThreads(accountId: string): Promise<PinRecord[]> {
    return await this.loadPins(accountId, CACHE_KEY.FAVORITE_PIN_THREAD);
  }

  async savePins(accountId: string, key: string, list: PinRecord[]): Promise<void> {
    if (accountId.length === 0) {
      return;
    }
    await CacheManager.getInstance().put(`${key}_${accountId}`, JSON.stringify(list));
  }

  async savePinnedFolders(accountId: string, list: PinRecord[]): Promise<void> {
    await this.savePins(accountId, CACHE_KEY.FAVORITE_PIN_FOLDER, list);
  }

  async savePinnedThreads(accountId: string, list: PinRecord[]): Promise<void> {
    await this.savePins(accountId, CACHE_KEY.FAVORITE_PIN_THREAD, list);
  }

  /** 置顶/取消置顶收纳夹，返回更新后的列表 */
  async setFolderPinned(accountId: string, forumName: string, pinned: boolean): Promise<PinRecord[]> {
    const list = await this.togglePin(accountId, CACHE_KEY.FAVORITE_PIN_FOLDER, forumName, pinned);
    await this.savePinnedFolders(accountId, list);
    return list;
  }

  /** 置顶/取消置顶帖子，返回更新后的列表 */
  async setThreadPinned(accountId: string, tid: string, pinned: boolean): Promise<PinRecord[]> {
    const list = await this.togglePin(accountId, CACHE_KEY.FAVORITE_PIN_THREAD, tid, pinned);
    await this.savePinnedThreads(accountId, list);
    return list;
  }

  private async togglePin(accountId: string, key: string, id: string, pinned: boolean): Promise<PinRecord[]> {
    const list = await this.loadPins(accountId, key);
    const idx = list.findIndex((p: PinRecord): boolean => p.id === id);
    if (pinned) {
      if (idx < 0) {
        list.push({ id, pinnedAt: Date.now() });
      } else {
        list[idx] = { id, pinnedAt: Date.now() };
      }
    } else {
      if (idx >= 0) {
        list.splice(idx, 1);
      }
    }
    return list;
  }

  // ===== 自定义分类（Preferences，数据量小不引入 RelationalStore）=====

  /** 读取自定义分类列表（不含内置 default，由 UI 组装）；v1.8 起兼容旧数据缺 cover 字段 */
  async loadCategories(accountId: string): Promise<FavCategory[]> {
    if (accountId.length === 0) {
      return [];
    }
    const raw = await CacheManager.getInstance().get(`${CACHE_KEY.FAVORITE_CUSTOM_FOLDER}_${accountId}`);
    if (!raw) {
      return [];
    }
    try {
      const parsed = JSON.parse(raw) as FavCategory[];
      if (!Array.isArray(parsed)) {
        return [];
      }
      return parsed.map((c: FavCategory): FavCategory => ({
        id: c.id,
        name: c.name,
        icon: c.icon,
        sortOrder: c.sortOrder,
        createdAt: c.createdAt,
        cover: typeof c.cover === 'string' ? c.cover : '',
      }));
    } catch (e) {
      return [];
    }
  }

  async saveCategories(accountId: string, list: FavCategory[]): Promise<void> {
    if (accountId.length === 0) {
      return;
    }
    await CacheManager.getInstance().put(`${CACHE_KEY.FAVORITE_CUSTOM_FOLDER}_${accountId}`, JSON.stringify(list));
  }

  /** 新增分类，返回更新后的自定义列表 */
  async addCategory(accountId: string, name: string, icon: string): Promise<FavCategory[]> {
    const list = await this.loadCategories(accountId);
    const id: string = `cat_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
    list.push({
      id,
      name: name.trim(),
      icon: icon.length > 0 ? icon : '📁',
      sortOrder: list.length + 1,
      createdAt: Date.now(),
      cover: '',
    });
    await this.saveCategories(accountId, list);
    return list;
  }

  async renameCategory(accountId: string, id: string, name: string): Promise<FavCategory[]> {
    const list = await this.loadCategories(accountId);
    const idx = list.findIndex((c: FavCategory): boolean => c.id === id);
    if (idx >= 0) {
      const cur: FavCategory = list[idx];
      list[idx] = {
        id: cur.id,
        name: name.trim(),
        icon: cur.icon,
        sortOrder: cur.sortOrder,
        createdAt: cur.createdAt,
        cover: cur.cover,
      };
      await this.saveCategories(accountId, list);
    }
    return list;
  }

  /** v1.8：拖拽排序持久化（ordered 为 UI 上的完整顺序，重写 sortOrder 1..n） */
  async reorderCategories(accountId: string, ordered: FavCategory[]): Promise<FavCategory[]> {
    if (accountId.length === 0) {
      return ordered;
    }
    const next: FavCategory[] = ordered.map((c: FavCategory, i: number): FavCategory => ({
      id: c.id,
      name: c.name,
      icon: c.icon,
      sortOrder: i + 1,
      createdAt: c.createdAt,
      cover: c.cover,
    }));
    await this.saveCategories(accountId, next);
    return next;
  }

  /** v1.8：更新分类封面（cover = 沙箱图片路径，空串移除），返回更新后的列表 */
  async updateCategoryCover(accountId: string, id: string, cover: string): Promise<FavCategory[]> {
    const list = await this.loadCategories(accountId);
    const idx = list.findIndex((c: FavCategory): boolean => c.id === id);
    if (idx >= 0) {
      list[idx] = {
        id: list[idx].id,
        name: list[idx].name,
        icon: list[idx].icon,
        sortOrder: list[idx].sortOrder,
        createdAt: list[idx].createdAt,
        cover: cover,
      };
      await this.saveCategories(accountId, list);
    }
    return list;
  }

  /** 删除分类（级联删除其下映射），返回 { 分类, 映射 } */
  async removeCategory(accountId: string, id: string): Promise<CategoryRemovalResult> {
    const categories = (await this.loadCategories(accountId)).filter((c: FavCategory): boolean => c.id !== id);
    await this.saveCategories(accountId, categories);
    const mappings = (await this.loadMappings(accountId)).filter((m: CategoryMapping): boolean => m.categoryId !== id);
    await this.saveMappings(accountId, mappings);
    return { categories: categories, mappings: mappings };
  }

  // ===== 帖↔分类映射 =====

  async loadMappings(accountId: string): Promise<CategoryMapping[]> {
    if (accountId.length === 0) {
      return [];
    }
    const raw = await CacheManager.getInstance().get(`${CACHE_KEY.FAVORITE_CUSTOM_MAPPING}_${accountId}`);
    if (!raw) {
      return [];
    }
    try {
      const parsed = JSON.parse(raw) as CategoryMapping[];
      return Array.isArray(parsed) ? parsed : [];
    } catch (e) {
      return [];
    }
  }

  async saveMappings(accountId: string, list: CategoryMapping[]): Promise<void> {
    if (accountId.length === 0) {
      return;
    }
    await CacheManager.getInstance().put(`${CACHE_KEY.FAVORITE_CUSTOM_MAPPING}_${accountId}`, JSON.stringify(list));
  }

  /** 将帖子移入/移出分类（categoryId='default' 即移出到未分类），返回更新后的映射 */
  async setThreadCategory(accountId: string, tid: string, forumName: string, categoryId: string): Promise<CategoryMapping[]> {
    return await this.setThreadCategories(accountId, tid, forumName, categoryId === CATEGORY_DEFAULT_ID ? [] : [categoryId]);
  }

  /**
   * 幂等设置帖子所属分类集合（一帖可同时在多个自定义分类，§4.2）。
   * categoryIds 为空或含 CATEGORY_DEFAULT_ID → 移出全部自定义分类（未分类）。
   * 替换式语义：最终映射 = 仅含 categoryIds 中的分类（未勾选的分类即移出）。
   */
  async setThreadCategories(accountId: string, tid: string, forumName: string, categoryIds: string[]): Promise<CategoryMapping[]> {
    const list = await this.loadMappings(accountId);
    const next = list.filter((m: CategoryMapping): boolean => m.tid !== tid);
    const seen: Set<string> = new Set<string>();
    for (const id of categoryIds) {
      if (id.length === 0 || id === CATEGORY_DEFAULT_ID || seen.has(id)) {
        continue;
      }
      seen.add(id);
      next.push({ tid, categoryId: id, forumName, addedAt: Date.now() });
    }
    await this.saveMappings(accountId, next);
    return next;
  }

  /** 批量移除帖子映射（删除收藏时级联清理），返回更新后的映射 */
  async removeMappingsByTids(accountId: string, tids: string[]): Promise<CategoryMapping[]> {
    const tidSet: Set<string> = new Set<string>(tids);
    const next = (await this.loadMappings(accountId)).filter((m: CategoryMapping): boolean => !tidSet.has(m.tid));
    await this.saveMappings(accountId, next);
    return next;
  }

  // ===== v1.11 排序偏好 + 收藏时间 + 分类内帖子自定义顺序 =====

  /** 读取排序偏好（0..4 对应 SortMode；默认 3 = TimeDesc） */
  async loadSortMode(accountId: string): Promise<number> {
    if (accountId.length === 0) {
      return 3;
    }
    const raw = await CacheManager.getInstance().get(`${CACHE_KEY.FAVORITE_SORT_MODE}_${accountId}`);
    if (!raw) {
      return 3;
    }
    const n: number = parseInt(raw, 10);
    return (n >= 0 && n <= 4) ? n : 3;
  }

  async saveSortMode(accountId: string, mode: number): Promise<void> {
    if (accountId.length === 0) {
      return;
    }
    await CacheManager.getInstance().put(`${CACHE_KEY.FAVORITE_SORT_MODE}_${accountId}`, String(mode));
  }

  /** 读取收藏时间映射 {tid: ms}（v1.11「添加时间」本地增量记录，threadstore 无 collect_time，见交付说明 §11） */
  async loadCollectTimes(accountId: string): Promise<Record<string, number>> {
    if (accountId.length === 0) {
      return {};
    }
    const raw = await CacheManager.getInstance().get(`${CACHE_KEY.FAVORITE_COLLECT_TS}_${accountId}`);
    if (!raw) {
      return {};
    }
    try {
      const parsed = JSON.parse(raw) as Record<string, number>;
      return (typeof parsed === 'object' && parsed !== null) ? parsed : {};
    } catch (e) {
      return {};
    }
  }

  /** 收藏动作成功挂钩：记录/刷新该帖收藏时间（ms） */
  async recordCollectTime(accountId: string, tid: string): Promise<void> {
    if (accountId.length === 0 || tid.length === 0) {
      return;
    }
    const map = await this.loadCollectTimes(accountId);
    map[tid] = Date.now();
    await CacheManager.getInstance().put(`${CACHE_KEY.FAVORITE_COLLECT_TS}_${accountId}`, JSON.stringify(map));
  }

  /** 取消收藏：移除该帖收藏时间记录 */
  async removeCollectTime(accountId: string, tid: string): Promise<void> {
    if (accountId.length === 0 || tid.length === 0) {
      return;
    }
    const map = await this.loadCollectTimes(accountId);
    const next: Record<string, number> = {};
    for (const k of Object.keys(map)) {
      if (k !== tid) {
        next[k] = map[k];
      }
    }
    await CacheManager.getInstance().put(`${CACHE_KEY.FAVORITE_COLLECT_TS}_${accountId}`, JSON.stringify(next));
  }

  /** 读取分类内帖子自定义顺序映射 {categoryId: [tid...]} */
  async loadThreadOrders(accountId: string): Promise<Record<string, string[]>> {
    if (accountId.length === 0) {
      return {};
    }
    const raw = await CacheManager.getInstance().get(`${CACHE_KEY.FAVORITE_CUSTOM_THREAD_ORDER}_${accountId}`);
    if (!raw) {
      return {};
    }
    try {
      const parsed = JSON.parse(raw) as Record<string, string[]>;
      return (typeof parsed === 'object' && parsed !== null) ? parsed : {};
    } catch (e) {
      return {};
    }
  }

  /** 持久化分类内帖子自定义顺序（tids 为完整顺序） */
  async saveThreadOrder(accountId: string, categoryId: string, tids: string[]): Promise<void> {
    if (accountId.length === 0 || categoryId.length === 0) {
      return;
    }
    const map = await this.loadThreadOrders(accountId);
    map[categoryId] = tids;
    await CacheManager.getInstance().put(`${CACHE_KEY.FAVORITE_CUSTOM_THREAD_ORDER}_${accountId}`, JSON.stringify(map));
  }

  // ===== 备份导出 / 导入（第七批 · P2-a，schema §2.5）=====

  /**
   * 构建导出 folders（自定义分类 + 分类内帖子映射）。
   * 「未分类」不导出：其收藏本体在云端（tieba_personal_collected），备份聚焦分类结构。
   * pidOf：由调用方注入（从本地缓存查 pid，查不到返回 ''）。
   */
  async buildBackupFolders(accountId: string, pidOf: (tid: string) => string): Promise<BackupFolder[]> {
    const categories = await this.loadCategories(accountId);
    const mappings = await this.loadMappings(accountId);
    const folders: BackupFolder[] = [];
    for (const c of categories) {
      const threads: BackupThread[] = [];
      for (const m of mappings) {
        if (m.categoryId === c.id) {
          threads.push({ tid: m.tid, pid: pidOf(m.tid), addedAt: m.addedAt });
        }
      }
      folders.push({ id: c.id, name: c.name, cover: '', createdAt: c.createdAt, threads });
    }
    return folders;
  }

  /**
   * 增量合并导入（§6 口径）：
   * - 同名分类（name trim 相等）→ 合并：其 threads 幂等并入该分类映射
   * - 新分类 → 新增（id 重新生成防冲突，icon 默认 📁，createdAt 取备份值）
   * - 无效记录：tid 缺失/非 string → 跳过；pid 存在但非 string → 跳过（pid 缺失/空串放行，导出侧保证字段恒为 string）
   * - folder.name 非法 → 整体跳过，其 threads 条数计入 skipped
   * forumNameOf：由调用方注入（从云端收藏缓存查 forumName，查不到用现有映射同名帖的值，再空则留 ''）
   */
  async importBackup(
    accountId: string,
    folders: BackupFolder[],
    forumNameOf: (tid: string) => string
  ): Promise<BackupImportSummary> {
    const summary: BackupImportSummary = { added: 0, merged: 0, skipped: 0 };
    if (accountId.length === 0 || !Array.isArray(folders)) {
      return summary;
    }
    const categories = await this.loadCategories(accountId);
    const mappings = await this.loadMappings(accountId);
    const existingIds: Set<string> = new Set<string>(categories.map((c: FavCategory): string => c.id));
    const catByName: Map<string, FavCategory> = new Map<string, FavCategory>();
    for (const c of categories) {
      catByName.set(c.name, c);
    }
    // 现有映射中的 tid → forumName（同名合并/新增分类补全吧名用）
    const forumOfTid: Map<string, string> = new Map<string, string>();
    for (const m of mappings) {
      if (!forumOfTid.has(m.tid)) {
        forumOfTid.set(m.tid, m.forumName);
      }
    }
    const nextCategories: FavCategory[] = [...categories];
    const nextMappings: CategoryMapping[] = [...mappings];
    let sortOrder: number = nextCategories.length + 1;
    for (const folder of folders) {
      if (!folder || typeof folder.name !== 'string' || folder.name.trim().length === 0) {
        summary.skipped += (Array.isArray(folder?.threads)) ? folder.threads.length : 1;
        continue;
      }
      const targetName: string = folder.name.trim();
      const existing: FavCategory | undefined = catByName.get(targetName);
      let categoryId: string;
      if (existing !== undefined) {
        categoryId = existing.id;
        summary.merged++;
      } else {
        let newId: string = `cat_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
        while (existingIds.has(newId)) {
          newId = `cat_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
        }
        existingIds.add(newId);
        categoryId = newId;
        const createdAt: number =
          (typeof folder.createdAt === 'number' && folder.createdAt > 0) ? folder.createdAt : Date.now();
        nextCategories.push({
          id: newId,
          name: targetName,
          icon: '📁',
          sortOrder: sortOrder,
          createdAt: createdAt,
          cover: ''
        });
        catByName.set(targetName, { id: newId, name: targetName, icon: '📁', sortOrder: sortOrder, createdAt: createdAt, cover: '' });
        sortOrder++;
        summary.added++;
      }
      if (Array.isArray(folder.threads)) {
        for (const t of folder.threads) {
          if (!t || typeof t.tid !== 'string' || t.tid.trim().length === 0) {
            summary.skipped++;
            continue;
          }
          if (t.pid !== undefined && typeof t.pid !== 'string') {
            summary.skipped++;
            continue;
          }
          // 幂等：该分类已含此帖则跳过（不重复写入，也不计入跳过）
          const dup: boolean = nextMappings.some((m: CategoryMapping): boolean => m.tid === t.tid && m.categoryId === categoryId);
          if (dup) {
            continue;
          }
          let forumName: string = forumNameOf(t.tid);
          if (forumName.length === 0) {
            forumName = forumOfTid.get(t.tid) ?? '';
          }
          nextMappings.push({
            tid: t.tid,
            categoryId: categoryId,
            forumName: forumName,
            addedAt: (typeof t.addedAt === 'number' && t.addedAt > 0) ? t.addedAt : Date.now()
          });
        }
      }
    }
    await this.saveCategories(accountId, nextCategories);
    await this.saveMappings(accountId, nextMappings);
    return summary;
  }
}
