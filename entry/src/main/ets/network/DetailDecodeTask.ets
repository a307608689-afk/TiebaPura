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

import { TiebaProtoDecoder } from './TiebaProtoDecoder';
import { PbPageResponseMessage } from '../model/TiebaProtoSchema';

/**
 * 详情页解码下沉任务（2026-09-20 性能优化）：
 * pb/page 首页回包可达数百 KB，decodePbPageResponse 的逐字段解析在主线程占 30~100ms，
 * 且恰与详情页路由转场动画同期（等待 + 转场掉帧双重代价）。本 @Concurrent 包装把整段
 * 解析搬进 taskpool worker 线程，主线程只收结构化克隆回的纯数据结果。
 *
 * 可行性依据：
 * - 解码产物全部是对象字面量（PbPageResponseMessage 等 interface 纯数据），可安全跨线程序列化；
 * - 本任务模块只 import 纯解析代码（TiebaProtoDecoder / ProtoReader），无副作用，worker 可安全加载。
 * - ArkTS 语法约束：@Concurrent 函数体内只能引用「导入变量或局部变量」，同文件类引用非法
 *   （首版写在 TiebaProtoDecoder.ets 内直接引用同类即触发 10705000），故独立成模块经 import 引用。
 *
 * 调用侧（TiebaService.decodePbPageOffMain）带主线程同步解码兜底，taskpool 异常时行为与改造前一致。
 */
@Concurrent
function decodePbPageTask(binary: ArrayBuffer): PbPageResponseMessage {
  return TiebaProtoDecoder.decodePbPageResponse(binary);
}

export { decodePbPageTask };
