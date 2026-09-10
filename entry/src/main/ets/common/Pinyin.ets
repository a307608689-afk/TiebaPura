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
 * 名称排序键工具：英文取首字母、中文取拼音首字母，实现中英文按 A-Z 全局混排。
 * 零依赖：中文拼音段判断基于 zh-CN localeCompare（ICU collation），无需内置汉字表。
 */

/** 拼音段代表字（GB2312 一级汉字按拼音分段的段首字，23 段：无 I/U/V） */
const PY_SEGMENT_LEAD: string[] = [
  '阿', '芭', '擦', '搭', '蛾', '发', '噶', '哈', '击', '喀', '垃', '妈',
  '拿', '哦', '啪', '期', '然', '撒', '塌', '挖', '昔', '压', '匝',
];

/** 与 PY_SEGMENT_LEAD 对应的首字母 */
const PY_SEGMENT_LETTER: string[] = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M',
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'W', 'X', 'Y', 'Z',
];

/** 无法取首字母的统一兜底键（恒排最后） */
const FALLBACK_KEY: string = '#';

/** 单个汉字 → 拼音首字母（A-Z），按 zh-CN collation 二分定位拼音段 */
function pinyinFirstLetterOf(hanzi: string): string {
  if (hanzi.localeCompare(PY_SEGMENT_LEAD[0], 'zh-CN') < 0) {
    return 'A';
  }
  if (hanzi.localeCompare(PY_SEGMENT_LEAD[PY_SEGMENT_LEAD.length - 1], 'zh-CN') >= 0) {
    return 'Z';
  }
  let lo: number = 0;
  let hi: number = PY_SEGMENT_LEAD.length - 1;
  while (lo < hi) {
    const mid: number = (lo + hi) >> 1;
    if (hanzi.localeCompare(PY_SEGMENT_LEAD[mid], 'zh-CN') >= 0) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return PY_SEGMENT_LETTER[lo - 1];
}

/**
 * 名称 → 排序首字母键：
 * - 英文开头 → 首字母大写（NBA吧 → N）
 * - 中文开头 → 拼音首字母（鬼灭之刃吧 → G）
 * - 数字/符号开头 → 跳过，取第一个字母/汉字的首字母
 * - 无法取到 → '#'
 */
export function nameSortKey(name: string): string {
  for (let i = 0; i < name.length; i++) {
    const code: number = name.charCodeAt(i);
    if (code >= 48 && code <= 57) {
      continue;
    }
    if (code >= 65 && code <= 90) {
      return name.charAt(i);
    }
    if (code >= 97 && code <= 122) {
      return String.fromCharCode(code - 32);
    }
    if (code >= 0x4E00 && code <= 0x9FA5) {
      return pinyinFirstLetterOf(name.charAt(i));
    }
  }
  return FALLBACK_KEY;
}

/**
 * 名称比较：主键=首字母（A-Z 全局混排），次键=完整名称 zh-CN 拼音序。
 * desc=true 倒序（主次键一起反转）。
 */
export function compareByName(a: string, b: string, desc: boolean): number {
  const ka: string = nameSortKey(a);
  const kb: string = nameSortKey(b);
  let cmp: number = 0;
  if (ka === kb) {
    cmp = a.localeCompare(b, 'zh-CN');
  } else if (ka === FALLBACK_KEY) {
    cmp = 1;
  } else if (kb === FALLBACK_KEY) {
    cmp = -1;
  } else {
    cmp = ka < kb ? -1 : 1;
  }
  return desc ? -cmp : cmp;
}
