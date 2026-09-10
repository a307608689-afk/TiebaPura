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

export interface UiIdleState {
  kind: 'idle';
}

export interface UiLoadingState {
  kind: 'loading';
}

export interface UiRefreshingState {
  kind: 'refreshing';
}

export interface UiLoadingMoreState {
  kind: 'loadingMore';
}

export interface UiSuccessState<T> {
  kind: 'success';
  data: T;
}

export interface UiEmptyState {
  kind: 'empty';
  message: string;
}

export interface UiErrorState {
  kind: 'error';
  message: string;
  code: number;
}

export type UiState<T> = UiIdleState | UiLoadingState | UiRefreshingState | UiLoadingMoreState | UiSuccessState<T> | UiEmptyState | UiErrorState;

export interface PageState<T> {
  page: number;
  hasMore: boolean;
  loading: boolean;
  refreshing: boolean;
  items: T[];
  errorMessage: string;
}
