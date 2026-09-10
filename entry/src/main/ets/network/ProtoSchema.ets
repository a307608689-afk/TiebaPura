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

import { ProtoWriter } from './ProtobufCodec';

export class ProtoSchema {
  static commonRequest(fields: Map<string, string | number>): ArrayBuffer {
    const writer = new ProtoWriter();
    const stringFields: Map<string, number> = new Map<string, number>([
      ['_client_version', 2], ['_client_id', 3], ['_phone_imei', 5],
      ['from', 6], ['cuid', 7], ['model', 9], ['BDUSS', 10], ['tbs', 11], ['_phone_newimei', 14],
      ['pversion', 24], ['_os_version', 25], ['brand', 26], ['lego_lib_version', 28], ['stoken', 30],
      ['z_id', 31], ['cuid_galaxy2', 32], ['cuid_gid', 33], ['oaid', 34], ['c3_aid', 35],
      ['sample_id', 36], ['sdk_ver', 42], ['framework_ver', 43], ['swan_game_ver', 44],
      ['event_day', 53], ['android_id', 54], ['start_scheme', 56], ['user_agent', 62], ['device_score', 70],
    ]);
    const numberFields: Map<string, number> = new Map<string, number>([
      ['_client_type', 1], ['_timestamp', 8], ['net_type', 12], ['scr_w', 37], ['scr_h', 38], ['scr_dip', 39],
      ['q_type', 40], ['is_teenager', 41], ['active_timestamp', 49], ['first_install_time', 50],
      ['last_update_time', 51], ['cmode', 55], ['start_type', 57], ['personalized_rec_switch', 63],
    ]);
    for (const entry of stringFields) {
      const value = fields.get(entry[0]);
      if (value !== undefined) writer.writeString(entry[1], `${value}`);
    }
    for (const entry of numberFields) {
      const value = fields.get(entry[0]);
      if (value !== undefined) writer.writeVarint(entry[1], Number(value));
    }
    return writer.toArrayBuffer();
  }

  static frsPageRequest(data: Map<string, string | number>, common: ArrayBuffer): ArrayBuffer {
    const requestData = new ProtoWriter();
    const kw = data.get('kw');
    if (kw !== undefined) requestData.writeString(1, `${kw}`);
    const rn = data.get('rn');
    if (rn !== undefined) requestData.writeVarint(2, Number(rn));
    const rnNeed = data.get('rn_need');
    if (rnNeed !== undefined) requestData.writeVarint(3, Number(rnNeed));
    const isGood = data.get('is_good');
    if (isGood !== undefined) requestData.writeVarint(4, Number(isGood));
    const cid = data.get('cid');
    if (cid !== undefined) requestData.writeVarint(5, Number(cid));
    const pn = data.get('pn');
    if (pn !== undefined) requestData.writeVarint(15, Number(pn));
    const sortType = data.get('sort_type');
    if (sortType !== undefined) requestData.writeVarint(47, Number(sortType));
    requestData.writeMessage(39, common);
    const request = new ProtoWriter();
    request.writeMessage(1, requestData.toArrayBuffer());
    return request.toArrayBuffer();
  }

  static profileRequest(userId: string, page: number, common: ArrayBuffer): ArrayBuffer {
    const dataWriter = new ProtoWriter();
    dataWriter.writeVarint(1, Number(userId) || 0);
    dataWriter.writeVarint(2, 1);
    dataWriter.writeVarint(6, page);
    dataWriter.writeMessage(9, common);
    const request = new ProtoWriter();
    request.writeMessage(1, dataWriter.toArrayBuffer());
    return request.toArrayBuffer();
  }

  static userPostRequest(userId: string, page: number, isThread: boolean, common: ArrayBuffer): ArrayBuffer {
    const dataWriter = new ProtoWriter();
    dataWriter.writeVarint(1, Number(userId) || 0);
    dataWriter.writeVarint(2, 20);
    dataWriter.writeVarint(4, isThread ? 1 : 0);
    dataWriter.writeVarint(5, 1);
    dataWriter.writeVarint(26, page);
    dataWriter.writeMessage(27, common);
    const request = new ProtoWriter();
    request.writeMessage(1, dataWriter.toArrayBuffer());
    return request.toArrayBuffer();
  }

  static pbFloorRequest(tid: string, pid: string, page: number, common: ArrayBuffer): ArrayBuffer {
    const dataWriter = new ProtoWriter();
    dataWriter.writeVarint(1, Number(tid) || 0);
    dataWriter.writeVarint(2, Number(pid) || 0);
    dataWriter.writeVarint(4, page);
    dataWriter.writeMessage(9, common);
    const request = new ProtoWriter();
    request.writeMessage(1, dataWriter.toArrayBuffer());
    return request.toArrayBuffer();
  }

  static pbPageRequest(data: Map<string, string | number>, common: ArrayBuffer): ArrayBuffer {
    const dataWriter = new ProtoWriter();
    const fields: Map<string, number> = new Map<string, number>([
      ['pb_rn', 1], ['mark', 2], ['back', 3], ['kz', 4], ['lz', 5], ['r', 6], ['pid', 7],
      ['with_floor', 8], ['floor_rn', 9], ['rn', 13], ['scr_w', 14], ['scr_h', 15], ['scr_dip', 16],
      ['q_type', 17], ['pn', 18], ['st_type', 19], ['thread_type', 20], ['is_comm_reverse', 33],
      ['is_jumpfloor', 34], ['jumpfloor_num', 35], ['forum_id', 56], ['from_smart_frs', 54],
      ['need_repost_recommend_forum', 57], ['ori_ugc_type', 65], ['from_push', 71], ['broadcast_id', 73],
      ['floor_sort_type', 74], ['source_type', 75], ['immersion_video_comment_source', 76],
      ['is_fold_comment_req', 78], ['request_times', 80], ['last_pid', 81], ['similar_from', 82],
    ]);
    for (const entry of fields) {
      const value = data.get(entry[0]);
      if (value === undefined) continue;
      if (entry[0] === 'st_type') {
        dataWriter.writeString(entry[1], `${value}`);
      } else if (entry[0] === 'scr_dip') {
        dataWriter.writeDouble(entry[1], Number(value));
      } else {
        dataWriter.writeVarint(entry[1], Number(value));
      }
    }
    dataWriter.writeMessage(25, common);
    const requestWriter = new ProtoWriter();
    requestWriter.writeMessage(1, dataWriter.toArrayBuffer());
    return requestWriter.toArrayBuffer();
  }

  /**
   * 黑名单列表查询请求（Cmd 303028，POST tiebac.baidu.com/c/u/user/userMuteQuery）。
   * 字段编号（aiotieba/tbclient.protobuf 对照）：
   *   UserMuteQueryReqIdl.data(1) {
   *     common(2),   // CommonReq（ProtoSchema.commonRequest）
   *     pn(4),       // uint32 页码（1 起始）
   *     rn(5)        // uint32 每页条数
   *   }
   */
  static userMuteQueryRequest(pn: number, rn: number, common: ArrayBuffer): ArrayBuffer {
    const dataWriter = new ProtoWriter();
    dataWriter.writeMessage(2, common);
    dataWriter.writeVarint(4, Math.max(1, pn));
    dataWriter.writeVarint(5, Math.max(1, rn));
    const requestWriter = new ProtoWriter();
    requestWriter.writeMessage(1, dataWriter.toArrayBuffer());
    return requestWriter.toArrayBuffer();
  }

  /**
   * 新版设置黑名单请求（SetUserBlack，Cmd 309697）。
   * 结构（tbclient.protobuf proto/SetUserBlack/）：
   *   SetUserBlackReqIdl: data(1){ common(1), black_uid(2), perm_list(3){ follow(1), interact(2), chat(3) } }
   * perm 取值：1=开启屏蔽，2=不屏蔽（服务端约定，见 aiotieba set_blacklist）。
   */
  static setUserBlackRequest(uid: string, follow: number, interact: number, chat: number, common: ArrayBuffer): ArrayBuffer {
    const permWriter = new ProtoWriter();
    permWriter.writeVarint(1, follow);
    permWriter.writeVarint(2, interact);
    permWriter.writeVarint(3, chat);
    const dataWriter = new ProtoWriter();
    dataWriter.writeMessage(1, common);
    dataWriter.writeVarint(2, Number(uid));
    dataWriter.writeMessage(3, permWriter.toArrayBuffer());
    const requestWriter = new ProtoWriter();
    requestWriter.writeMessage(1, dataWriter.toArrayBuffer());
    return requestWriter.toArrayBuffer();
  }
}
