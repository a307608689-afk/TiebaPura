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

export interface ProtoCommonRequest {
  BDUSS: string;
  _client_id: string;
  _client_type: number;
  _client_version: string;
  _os_version: string;
  _timestamp: number;
  brand: string;
  model: string;
  net_type: number;
  stoken: string;
  scr_dip: number;
  scr_h: number;
  scr_w: number;
}

export interface UserLikeRequestData {
  common: ProtoCommonRequest;
  pageTag: string;
  lastRequestUnix: number;
  followType: number;
  loadType: number;
}

export interface PbPageRequestData {
  common: ProtoCommonRequest;
  kz: string;
  pid: number;
  pn: number;
  r: number;
  lz: number;
  forum_id: number;
  mark: number;
  last_pid: number;
  back: number;
  floor_rn: number;
  floor_sort_type: number;
  is_jumpfloor: number;
  jumpfloor_num: number;
  q_type: number;
  rn: number;
  scr_dip: number;
  scr_h: number;
  scr_w: number;
  st_type: string;
  with_floor: number;
}

export interface PersonalizedRequestData {
  common: ProtoCommonRequest;
  load_type: number;
  pn: number;
  page_thread_count: number;
  need_tags: number;
  need_forumlist: number;
  q_type: number;
  new_net_type: number;
  new_install: number;
  request_times: number;
  scr_dip: number;
  scr_h: number;
  scr_w: number;
}