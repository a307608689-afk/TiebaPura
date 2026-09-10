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

import { uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';

/**
 * 主题与设计令牌。
 * 通过模块级变量维护全局深色模式（V1 组件兼容方案）。
 */
let _globalIsDark: boolean = false;

// ========== 设备沉浸光感能力检测 ==========

let _materialInitialized: boolean = false;
let _materialSupported: boolean = false;
let _materialApiLevel: number = 0;

/**
 * 初始化设备沉浸光感能力检测。
 * 在应用启动时调用一次，结果缓存。
 */
export function initMaterialSupport(): void {
  if (_materialInitialized) {
    return;
  }
  _materialInitialized = true;
  try {
    _materialApiLevel = deviceInfo.sdkApiVersion;
    // ⚠️ 门限必须是 26，不是 23：
    //   ArkUI `uiMaterial` / 通用属性 `systemMaterial` / `barFloatingStyle` 全部是 @since 26.0.0；
    //   `6.1.0(23)` 是 UI Design Kit `hdsMaterial`（@kit.UIDesignKit）的起始版本，两者不是同一套 API。
    //   门限取 23 会让 API 23~25 误入「材质路径」——那些版本没有 uiMaterial，材质也判 out of scope。
    if (_materialApiLevel < 26) {
      _materialSupported = false;
      return;
    }
    // 命名空间探测：即便系统上报 ≥26，也确认 uiMaterial 真的可构造（低版本/异常会抛，落到 catch）
    const probe: uiMaterial.ImmersiveMaterial = new uiMaterial.ImmersiveMaterial();
    _materialSupported = !!probe;
  } catch (e) {
    _materialSupported = false;
  }
}

/**
 * 当前设备是否支持沉浸光感。
 */
export function isMaterialSupported(): boolean {
  if (!_materialInitialized) {
    initMaterialSupport();
  }
  return _materialSupported;
}

// ========== 沉浸光感材质预设 ==========
// 基于官方 uiMaterial.ImmersiveMaterial（@since 26.0.0），提供统一的材质风格。
// 低版本（API 23~25）没有 uiMaterial：所有实例统一经 createMaterial() 构造，
// 不支持时返回 undefined（`.systemMaterial()` 接受 undefined，等价于官方兼容写法）。

// 材质实例缓存
let _matControl: uiMaterial.Material | undefined = undefined;
let _matBar: uiMaterial.Material | undefined = undefined;
let _matTab: uiMaterial.Material | undefined = undefined;
let _matCardAction: uiMaterial.Material | undefined = undefined;
let _matFab: uiMaterial.Material | undefined = undefined;
let _matRowItem: uiMaterial.Material | undefined = undefined;
let _matTabActiveDark: uiMaterial.Material | undefined = undefined;
let _matTabActiveLight: uiMaterial.Material | undefined = undefined;
let _matAccentDark: uiMaterial.Material | undefined = undefined;
let _matAccentLight: uiMaterial.Material | undefined = undefined;
let _matDangerDark: uiMaterial.Material | undefined = undefined;
let _matDangerLight: uiMaterial.Material | undefined = undefined;
let _matBottomGlowDark: uiMaterial.Material | undefined = undefined;
let _matBottomGlowLight: uiMaterial.Material | undefined = undefined;
let _matFloating: uiMaterial.ImmersiveMaterial | undefined = undefined;
let _matDialog: uiMaterial.ImmersiveMaterial | undefined = undefined;
let _matSegActive: uiMaterial.Material | undefined = undefined;
let _matSegIdle: uiMaterial.Material | undefined = undefined;
let _matSegActiveFlat: uiMaterial.Material | undefined = undefined;
let _matSegIdleFlat: uiMaterial.Material | undefined = undefined;

/**
 * 低版本安全网：材质实例统一构造入口。
 *
 * - `uiMaterial` 全部 API 为 `@since 26.0.0`，API 23~25 上该命名空间不存在，
 *   此时 `new uiMaterial.ImmersiveMaterial(...)` 会抛异常；
 * - 而 `ImmMaterial.*` 在工程内有 100+ 处**无条件**调用（`.systemMaterial(ImmMaterial.X())`），
 *   没有逐点包三元/判断，所以把口袋收在这里；
 * - 不支持 / 构造失败时返回 **运行期 `undefined`**：`common.d.ts` 中
 *   `.systemMaterial(material: SystemUiMaterial | undefined)` 明确接受 `undefined`，
 *   与官方兼容写法 `apiVersion >= 26 ? material : undefined` 完全等价（低版本字段被系统忽略）。
 *
 * 因此本文件材质相关的返回类型统一放宽为 `| undefined`（调用点零改动：
 * `.systemMaterial()` 与各 options 的 `systemMaterial?` 都接受 undefined）。
 */
function createMaterial(options: uiMaterial.ImmersiveOptions): uiMaterial.ImmersiveMaterial | undefined {
  if (!isMaterialSupported()) {
    return undefined;
  }
  try {
    return new uiMaterial.ImmersiveMaterial(options);
  } catch (e) {
    return undefined;
  }
}

function ensureControl(): uiMaterial.Material | undefined {
  if (!_matControl) {
    _matControl = createMaterial({
      style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
      interactive: true,
      lightEffect: { color: undefined },
      applyShadow: true,
    });
  }
  return _matControl;
}

function ensureBar(): uiMaterial.Material | undefined {
  if (!_matBar) {
    _matBar = createMaterial({
      style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
      interactive: false,
      lightEffect: { color: undefined },
      applyShadow: true,
      colorInvert: true,
    });
  }
  return _matBar;
}

function ensureFloatingBar(): uiMaterial.ImmersiveMaterial | undefined {
  if (!_matFloating) {
    _matFloating = createMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      interactive: false,
      // 显式禁用流光：官方语义「传对象=启用、传 null=禁用、不传=跟随组件默认」；
      // 此前 { color: undefined } 属于「传对象启用」，悬浮岛上沿会渲染一条白色光感线（真机可见，用户要求去掉）。
      lightEffect: null,
      applyShadow: true,
      colorInvert: true,
    });
  }
  return _matFloating;
}

function ensureTab(): uiMaterial.Material | undefined {
  if (!_matTab) {
    _matTab = createMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      interactive: true,
      lightEffect: { color: undefined },
      applyShadow: true,
    });
  }
  return _matTab;
}

function ensureTabActiveDark(): uiMaterial.Material | undefined {
  if (!_matTabActiveDark) {
    _matTabActiveDark = createMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      interactive: true,
      lightEffect: { color: undefined },
      applyShadow: true,
      materialColor: '#553173FF',
    });
  }
  return _matTabActiveDark;
}

function ensureTabActiveLight(): uiMaterial.Material | undefined {
  if (!_matTabActiveLight) {
    _matTabActiveLight = createMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      interactive: true,
      lightEffect: { color: undefined },
      applyShadow: true,
      materialColor: '#383173FF',
    });
  }
  return _matTabActiveLight;
}

/**
 * 标题栏分段胶囊 — 选中档：REGULAR 中性玻璃（不染色，选中感由文字强调色 + 字重承担，
 * 与首页「推荐/关注动态」既有观感一致）+ 按压弹性形变 + 光感反馈。
 */
function ensureSegActive(): uiMaterial.Material | undefined {
  if (!_matSegActive) {
    _matSegActive = createMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      interactive: true,
      lightEffect: { color: undefined },
      applyShadow: true,
    });
  }
  return _matSegActive;
}

/**
 * 标题栏分段胶囊 — 未选中档：THIN，比选中档更薄，形成选中/未选中层次。
 */
function ensureSegIdle(): uiMaterial.Material | undefined {
  if (!_matSegIdle) {
    _matSegIdle = createMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      interactive: true,
      lightEffect: { color: undefined },
      applyShadow: true,
    });
  }
  return _matSegIdle;
}

/**
 * 分段胶囊 — 选中档（无阴影版）：与 ensureSegActive 仅 applyShadow 之差。
 * 用于帖子详情页底部排序胶囊：两枚胶囊浮在白卡上方，材质自带阴影落在卡面上
 * 合并成一层明显的淡阴影（真机反馈要求去除，2026-09-10）；标题栏胶囊仍用带阴影版。
 */
function ensureSegActiveFlat(): uiMaterial.Material | undefined {
  if (!_matSegActiveFlat) {
    _matSegActiveFlat = createMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      interactive: true,
      lightEffect: { color: undefined },
      applyShadow: false,
    });
  }
  return _matSegActiveFlat;
}

/** 分段胶囊 — 未选中档（无阴影版）：与 ensureSegIdle 仅 applyShadow 之差。 */
function ensureSegIdleFlat(): uiMaterial.Material | undefined {
  if (!_matSegIdleFlat) {
    _matSegIdleFlat = createMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      interactive: true,
      lightEffect: { color: undefined },
      applyShadow: false,
    });
  }
  return _matSegIdleFlat;
}

function ensureCardAction(): uiMaterial.Material | undefined {
  if (!_matCardAction) {
    _matCardAction = createMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      interactive: true,
      applyShadow: true,
    });
  }
  return _matCardAction;
}

function ensureFab(): uiMaterial.Material | undefined {
  if (!_matFab) {
    _matFab = createMaterial({
      style: uiMaterial.ImmersiveStyle.THICK,
      interactive: true,
      lightEffect: { color: undefined },
      applyShadow: true,
    });
  }
  return _matFab;
}

function ensureAccentDark(): uiMaterial.Material | undefined {
  if (!_matAccentDark) {
    _matAccentDark = createMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      interactive: true,
      lightEffect: { color: undefined },
      applyShadow: true,
      materialColor: '#663173FF',
    });
  }
  return _matAccentDark;
}

function ensureAccentLight(): uiMaterial.Material | undefined {
  if (!_matAccentLight) {
    _matAccentLight = createMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      interactive: true,
      lightEffect: { color: undefined },
      applyShadow: true,
      materialColor: '#4C3173FF',
    });
  }
  return _matAccentLight;
}

/**
 * 危险色主按钮（删除 / 清空等不可逆操作）。与 accent 严格同构，仅把品牌蓝赋色换成危险红
 * （Theme.danger() = #F5222D），保证「主按钮 / 危险按钮」两档材质观感一致。
 */
function ensureDangerDark(): uiMaterial.Material | undefined {
  if (!_matDangerDark) {
    _matDangerDark = createMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      interactive: true,
      lightEffect: { color: undefined },
      applyShadow: true,
      materialColor: '#66F5222D',
    });
  }
  return _matDangerDark;
}

function ensureDangerLight(): uiMaterial.Material | undefined {
  if (!_matDangerLight) {
    _matDangerLight = createMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      interactive: true,
      lightEffect: { color: undefined },
      applyShadow: true,
      materialColor: '#4CF5222D',
    });
  }
  return _matDangerLight;
}

function ensureBottomGlowDark(): uiMaterial.Material | undefined {
  if (!_matBottomGlowDark) {
    _matBottomGlowDark = createMaterial({
      style: uiMaterial.ImmersiveStyle.THICK,
      interactive: false,
      applyShadow: true,
      materialColor: '#553173FF',
    });
  }
  return _matBottomGlowDark;
}

function ensureBottomGlowLight(): uiMaterial.Material | undefined {
  if (!_matBottomGlowLight) {
    _matBottomGlowLight = createMaterial({
      style: uiMaterial.ImmersiveStyle.THICK,
      interactive: false,
      applyShadow: true,
      materialColor: '#383173FF',
    });
  }
  return _matBottomGlowLight;
}

function ensureRowItem(): uiMaterial.Material | undefined {
  if (!_matRowItem) {
    _matRowItem = createMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      interactive: true,
      lightEffect: { color: undefined },
      applyShadow: true,
    });
  }
  return _matRowItem;
}

/**
 * 弹窗卡片材质（系统 CustomDialog 的 systemMaterial）。
 * REGULAR 档：对齐改造前弹窗玻璃的 BlurStyle.Regular 观感；
 * interactive=false / applyShadow=true：保持与既有弹窗一致的「无按压形变 + 系统阴影」。
 * 注意：必须挂在不透明弹窗容器的 options.systemMaterial 上（customStyle 需为 false），
 * 挂在页面 body 的自绘浮层上会判 out of scope 而不渲染。
 */
function ensureDialog(): uiMaterial.ImmersiveMaterial | undefined {
  if (!_matDialog) {
    _matDialog = createMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      interactive: false,
      applyShadow: true,
    });
  }
  return _matDialog;
}

/**
 * 沉浸光感材质预设 — 对外导出接口。
 * 所有方法返回 uiMaterial.Material 实例，可安全复用。
 * 沉浸光感恒开启（默认即此路径），系统材质始终启用，不再受运行时开关控制。
 */
export class ImmMaterial {
  /** 圆形控制按钮（顶栏返回/搜索/更多等 44x44 圆形按钮）。ULTRA_THIN + 按压弹性形变 + 光感反馈。 */
  static control(): uiMaterial.Material | undefined {
    return ensureControl();
  }
  /** 底部/顶部容器栏。THIN + 系统阴影，无交互形变。 */
  static bar(): uiMaterial.Material | undefined {
    return ensureBar();
  }
  /** 底部悬浮玻璃胶囊（挂真实 Tabs.tabBar 槽位，供原生 barFloatingStyle 的 systemMaterial 使用）。 */
  static floatingBar(): uiMaterial.ImmersiveMaterial | undefined {
    return ensureFloatingBar();
  }
  /** 胶囊 Tab 按钮。REGULAR + 按压弹性形变 + 光感反馈。 */
  static tab(): uiMaterial.Material | undefined {
    return ensureTab();
  }
  /**
   * 标题栏 / 吸顶分段胶囊（选中 REGULAR、未选中 THIN，两档均中性无色）。
   * 仅用于官方槽位（Navigation/NavDestination 标题栏、Tabs(barPosition=End) 底部 TabBar）内的分段钮：
   * 页面主体元素挂 systemMaterial 判 out of scope 不渲染，且官方建议 systemMaterial 不要与
   * backgroundColor / backgroundBlurStyle / border / shadow 同用（会互相覆盖）。
   */
  static seg(active: boolean): uiMaterial.Material | undefined {
    return active ? ensureSegActive() : ensureSegIdle();
  }
  /** 同 seg，但 applyShadow: false（无材质投影）。用于浮在白卡上方的排序胶囊（详见 ensureSegActiveFlat 注释）。 */
  static segFlat(active: boolean): uiMaterial.Material | undefined {
    return active ? ensureSegActiveFlat() : ensureSegIdleFlat();
  }
  /** 选中态胶囊 Tab。REGULAR + 品牌色赋色 + 光感反馈。 */
  static tabActive(isDark: boolean): uiMaterial.Material | undefined {
    return isDark ? ensureTabActiveDark() : ensureTabActiveLight();
  }
  /** 卡片内操作按钮。THIN + 按压弹性形变。 */
  static cardAction(): uiMaterial.Material | undefined {
    return ensureCardAction();
  }
  /** FAB 悬浮操作按钮。THICK + 按压弹性形变 + 光感反馈。 */
  static fab(): uiMaterial.Material | undefined {
    return ensureFab();
  }
  /** 品牌主按钮。THIN + 品牌色赋色 + 光感反馈。 */
  static accent(isDark: boolean): uiMaterial.Material | undefined {
    return isDark ? ensureAccentDark() : ensureAccentLight();
  }
  /** 危险色主按钮（删除 / 清空等不可逆操作）。THIN + 危险红赋色 + 光感反馈，与 accent 同构。 */
  static danger(isDark: boolean): uiMaterial.Material | undefined {
    return isDark ? ensureDangerDark() : ensureDangerLight();
  }
  /** 底栏选中项高亮。THICK + 品牌色赋色，最强光晕。 */
  static bottomGlow(isDark: boolean): uiMaterial.Material | undefined {
    return isDark ? ensureBottomGlowDark() : ensureBottomGlowLight();
  }
  /** 条目按钮。REGULAR + 按压弹性形变。 */
  static rowItem(): uiMaterial.Material | undefined {
    return ensureRowItem();
  }
  /**
   * 系统弹窗卡片（CustomDialog 的 options.systemMaterial）。
   * REGULAR + 系统阴影，无按压形变 —— 对齐改造前弹窗玻璃的 BlurStyle.Regular 观感。
   * 只能用于系统弹窗（customStyle=false），挂在页面 body 自绘浮层上不渲染。
   */
  static dialog(): uiMaterial.ImmersiveMaterial | undefined {
    return ensureDialog();
  }
  /**
   * 半模态抽屉（bindSheet 的 options.systemMaterial）。
   * 与 dialog 同为「REGULAR 卡片档」且共用同一实例（材质按 style 分档缓存，参数相同不必再建一个）。
   * 同样只能用于系统槽位（半模态 / 弹窗），页面 body 内的自绘浮层上不渲染。
   */
  static sheet(): uiMaterial.ImmersiveMaterial | undefined {
    return ensureDialog();
  }
  /**
   * 下拉菜单（bindMenu 的 options.systemMaterial）。
   * 同为「REGULAR 卡片档」，沿用同一实例 —— 对齐改造前自绘下拉面板的 `BlurStyle.Regular, scale 0.85` 观感。
   * 只能用于系统槽位（bindMenu / bindContextMenu 的 options），页面 body 内的自绘浮层上不渲染。
   */
  static menu(): uiMaterial.ImmersiveMaterial | undefined {
    return ensureDialog();
  }
}

/**
 * 背景效果预设 — 与 ImmMaterial 方法同名一一对应（无参版本）。
 * 沉浸光感恒开启：统一返回空背景效果（radius 0 + 全透明色，不渲染模糊），
 * 玻璃外观完全由 ImmersiveMaterial（systemMaterial）承担，避免双模糊叠加。
 * 使用方法：在每个 `.systemMaterial(ImmMaterial.X(...))` 前追加一行
 * `.backgroundEffect(ImmBlur.X())`，背景效果常驻但为空，保持与既有调用点结构一致。
 */
export interface ImmEffectOptions {
  radius: number;
  saturation?: number;
  brightness?: number;
  color?: string;
}

/** 玻璃浮起阴影（结构对齐 ArkUI ShadowOptions） */
export interface GlassShadowOptions {
  radius: number;
  color?: string;
  offsetX?: number;
  offsetY?: number;
}

/** 空背景效果：模糊半径 0 + 全透明，避免与系统材质叠加 */
const IMM_EMPTY_EFFECT: ImmEffectOptions = { radius: 0, color: '#00000000' };

/** 空阴影：零半径 + 全透明，避免与系统材质自带阴影叠成双影 */
const IMM_EMPTY_SHADOW: GlassShadowOptions = { radius: 0, color: '#00000000' };

export class ImmBlur {
  /** control 同源档（空背景效果） */
  static control(): ImmEffectOptions { return IMM_EMPTY_EFFECT; }
  /** bar 同源档（空背景效果） */
  static bar(): ImmEffectOptions { return IMM_EMPTY_EFFECT; }
  /** cardAction 同源档（空背景效果） */
  static cardAction(): ImmEffectOptions { return IMM_EMPTY_EFFECT; }
  /** accent 强调档（空背景效果，品牌色由材质赋色承担） */
  static accent(): ImmEffectOptions { return IMM_EMPTY_EFFECT; }
  /** tab/rowItem 同源档（空背景效果） */
  static tab(): ImmEffectOptions { return IMM_EMPTY_EFFECT; }
  /** tabActive 强调档（空背景效果，蓝色由材质赋色承担） */
  static tabActive(): ImmEffectOptions { return IMM_EMPTY_EFFECT; }
  /** rowItem 同源档（空背景效果） */
  static rowItem(): ImmEffectOptions { return IMM_EMPTY_EFFECT; }
  /** fab 同源档（空背景效果） */
  static fab(): ImmEffectOptions { return IMM_EMPTY_EFFECT; }
  /** bottomGlow 强调档（空背景效果） */
  static bottomGlow(): ImmEffectOptions { return IMM_EMPTY_EFFECT; }
}

/**
 * 设备沉浸光感能力管理器（兼容 API）。
 */
export class MaterialManager {
  static init(): void { initMaterialSupport(); }
  static isSupported(): boolean { return isMaterialSupported(); }
  static getApiLevel(): number { return _materialApiLevel; }
}

// ========== 降级方案颜色 ==========
// 设备不支持 systemMaterial 时的手动玻璃效果颜色

export class Theme {
  // 背景
  static bg(isDark: boolean): string { return isDark ? '#101114' : '#F2F4F7'; }
  static bgCard(isDark: boolean): string { return isDark ? '#1B1E24' : '#FFFFFF'; }
  static bgElevated(isDark: boolean): string { return isDark ? '#252A33' : '#FFFFFF'; }
  // v1.15.9 弹窗卡片背景：高不透明度纯色（替代磨砂玻璃 systemMaterial，避免暗蒙层+模糊叠加泛白；配合弱蒙层+强阴影产生浮起层次）
  // v1.18 降低沉浸光感透出：alpha F2(95%) → F8(97.6%) → FA(98%)，弹窗更实、材质光感更收敛
  // v1.19 方案B(层次光感)：深色底提亮为墨蓝 #232832，配合顶部高光边+双层阴影+降透蒙层营造浮起光感，文字对比度同步提升
  static sheetBg(isDark: boolean): string { return isDark ? '#FC232832' : '#FAFFFFFF'; }
  /** v1.19 弹窗卡片顶部高光边(1.5vp border，模拟玻璃上缘受光；深色明显、浅色白卡上近乎不可见) */
  static sheetTopGlow(isDark: boolean): string { return isDark ? '#40FFFFFF' : '#80FFFFFF'; }
  /** 弹窗/浮层真模糊磨砂底（配合 .backgroundBlurStyle(BlurStyle.Regular, {scale}) 使用）：
   *  与 segGlass 同思路「不铺白夹层」：亮色完全透明、深色仅 18% 微暗底，
   *  让 Regular 自带的白 tint 直接呈现磨砂、背后内容（吧卡/头像/文字）透出轮廓——
   *  任何半透明白底叠在 blur 上都会形成「白夹层」盖掉模糊与透出，观感退回纯白底。 */
  static sheetGlass(isDark: boolean): string { return isDark ? '#2E1A1A1E' : '#00000000'; }
  static bgSurface(isDark: boolean): string { return isDark ? '#262B34' : '#F5F6F8'; }
  static glass(isDark: boolean): string { return isDark ? '#B81B1E24' : '#CCFFFFFF'; }
  static glassHighlight(isDark: boolean): string { return isDark ? '#36FFFFFF' : '#DFFFFFFF'; }
  // 骨架屏（第四批；v1.16：亮色占位块加深一档突出层次，高亮透明度调低避免刺眼，深色高亮稍提亮保证可见）
  static skeletonBase(isDark: boolean): string { return isDark ? '#252A33' : '#E3E7EF'; }
  static skeletonHighlight(isDark: boolean): string { return isDark ? '#30FFFFFF' : '#26FFFFFF'; }
  // 骨架屏方案G："未上墨的纸"——整块占位底色，比页面底色略深一档，接近背景避免块状突兀
  static skeletonSheet(isDark: boolean): string { return isDark ? '#171A20' : '#EDF0F4'; }
  static glassSheen(isDark: boolean): string { return isDark ? '#48FFFFFF' : '#F0FFFFFF'; }
  static glassAccent(): string { return '#3173FF'; }
  static glassGlow(isDark: boolean): string { return isDark ? '#663173FF' : '#453173FF'; }
  static glassGlowStrong(isDark: boolean): string { return isDark ? '#A03173FF' : '#703173FF'; }
  static glassShadow(isDark: boolean): string { return isDark ? '#99000000' : '#3D102018'; }
  static glassControl(isDark: boolean): string { return isDark ? '#7A252A33' : '#B8FFFFFF'; }
  static glassControlLine(isDark: boolean): string { return isDark ? '#58FFFFFF' : '#E6FFFFFF'; }
  static glassControlShadow(isDark: boolean): string { return isDark ? '#70000000' : '#30101824'; }
  static glassBrand(isDark: boolean): string { return isDark ? '#7A3173FF' : '#4C3173FF'; }
  static topBarGlass(isDark: boolean): string { return isDark ? '#991B1E24' : '#B8FFFFFF'; }
  static topBarLine(isDark: boolean): string { return isDark ? '#42FFFFFF' : '#D6FFFFFF'; }
  static topBarShadow(isDark: boolean): string { return isDark ? '#66000000' : '#24101824'; }
  static bottomGlass(isDark: boolean): string { return isDark ? '#661B1E24' : '#66FFFFFF'; }
  static bottomGlassLine(isDark: boolean): string { return isDark ? '#55FFFFFF' : '#B8FFFFFF'; }
  static bottomGlassShadow(isDark: boolean): string { return isDark ? '#88000000' : '#30101824'; }
  static homeTopStart(isDark: boolean): string { return isDark ? '#E61B2530' : '#EAF1F8'; }
  static homeTopMid(isDark: boolean): string { return isDark ? '#D61B1F29' : '#F6F9FC'; }
  static homeTopEnd(isDark: boolean): string { return isDark ? '#001B1F29' : '#00F6F9FC'; }
  static homeTopLine(isDark: boolean): string { return isDark ? '#36FFFFFF' : '#B8FFFFFF'; }
  static homeTopShadow(isDark: boolean): string { return isDark ? '#33000000' : '#14101824'; }
  // 文字
  static textPrimary(isDark: boolean): string { return isDark ? '#F0F2F5' : '#1A1A1A'; }
  static textSecondary(isDark: boolean): string { return isDark ? '#A8AEB8' : '#4E545C'; }
  static textTertiary(isDark: boolean): string { return isDark ? '#6E7480' : '#9AA0A6'; }
  // 分割线
  static divider(isDark: boolean): string { return isDark ? '#2E2E33' : '#EBEDF0'; }
  // 主题蓝
  static brand(): string { return '#3173FF'; }
  /**
   * 分段胶囊选中文字色（沉浸光感恒开启）：
   * 选中为浅蓝官方材质胶囊 → 亮色深字 / 深色白字
   */
  static segActiveText(isDark: boolean): string {
    return isDark ? '#FFFFFF' : '#000000';
  }
  // 强调背景
  static brandBg(isDark: boolean): string { return isDark ? '#1A2B4A' : '#EAF1FE'; }
  // 置顶徽章（柔红底白字，深色降一档明度避免刺眼；与精品蓝 badge 语义区分）
  static badgePin(isDark: boolean): string { return isDark ? '#E06161' : '#FF8A8A'; }
  static glassLine(isDark: boolean): string { return isDark ? '#4AFFFFFF' : '#80FFFFFF'; }
  // 危险色
  static danger(): string { return '#F5222D'; }
  // 成功色
  static success(): string { return '#52C41A'; }

  // 用户等级徽章色：贴吧官方 18 级（1-3 绿 / 4-9 蓝 / 10-14 红 / 15-18 黄）
  static levelColor(level: number): string {
    if (level >= 15) return '#FFC107';
    if (level >= 10) return '#F44336';
    if (level >= 4) return '#2196F3';
    return '#4CAF50';
  }

  // ========== 手动玻璃兜底（低版本 API 23~25 / 材质范围外 / 材质渲染失败时）==========
  // ========== 手动玻璃降级（页面主体元素无真材质，须视觉兜底）==========
  // 官方范围约束：沉浸光感（systemMaterial/ImmersiveMaterial）仅弹窗类组件、
  // Slider/Toggle/Select，及 Navigation 标题栏 / Tabs(BarPosition.End) 底部 TabBar 内生效。
  // 页面主体元素（顶部分段胶囊、圆形按钮等）挂材质不渲染（Material inactive: out of scope），
  // 只能用半透明 manualGlass 背景 + 白描边模拟玻璃观感。
  // 调用方式：.backgroundColor(Theme.manualGlass(isDark)).border({...})
  //          .backgroundEffect(ImmBlur.X()).systemMaterial(ImmMaterial.X())
  /**
   * 手动玻璃降级总开关。
   * 若某日官方材质在页面主体所有区域稳定渲染，可将此改为 false，
   * 所有降级背景/描边立即变为全透明，还原纯净官方材质效果。
   */
  static readonly GLASS_FALLBACK_ENABLED: boolean = true;

  /**
   * 手动玻璃背景色（页面主体元素的玻璃兜底）。
   * - 普通：亮色用浅蓝灰（白卡上明显色差），深色用半透明白。
   * - active=true：选中态用半透明品牌蓝玻璃。
   */
  static manualGlass(isDark: boolean, active: boolean = false): string {
    if (!Theme.GLASS_FALLBACK_ENABLED) {
      return '#00000000';
    }
    if (active) {
      return isDark ? '#993173FF' : '#803173FF';
    }
    return isDark ? '#3DFFFFFF' : '#E6F0F4F8';
  }
  /**
   * 吸顶切换钮玻璃底（HomeTab 顶栏推荐/关注/搜索共用）。
   * 参考底栏形态：无任何彩色胶囊底，仅一层低不透明度中性玻璃（黑/白），
   * 让 backgroundBlurStyle 真磨砂透过内容可见；选中/未选中完全由文字强调色 + 字重表达。
   */
  static segGlass(isDark: boolean, active: boolean): string {
    if (!Theme.GLASS_FALLBACK_ENABLED) {
      return '#00000000';
    }
    // 亮色不留实白底，避免白夹层盖住真模糊；状态由强调色文字 + 阴影强度承担
    return active
      ? (isDark ? '#4D1A1A1E' : '#00000000')
      : (isDark ? '#2E1A1A1E' : '#00000000');
  }
  /**
   * 吸顶切换钮玻璃浮起阴影：中性色（不染蓝），选中态略重抬起，未选中/圆钮轻投影，
   * 与描边一起保住胶囊层次感。仅真模糊路径使用。
   */
  static segGlassShadow(isDark: boolean, active: boolean): GlassShadowOptions {
    if (!Theme.GLASS_FALLBACK_ENABLED) {
      return IMM_EMPTY_SHADOW;
    }
    return active
      ? (isDark
        ? { radius: 12, color: '#66000000', offsetY: 3 }
        : { radius: 12, color: '#3D000000', offsetY: 3 })
      : (isDark
        ? { radius: 10, color: '#40000000', offsetY: 2 }
        : { radius: 10, color: '#26000000', offsetY: 2 });
  }
  /**
   * 底部悬浮排序胶囊（正序/倒序、只看全部）底色。
   * 与 manualGlass 的区别：不透明度刻意压到极低（普通约 5~8%、选中约 10~15%），
   * 只留极淡的底色提示状态，让楼层/回复文字整条滑过胶囊后方时仍能透出，不会整块消失。
   * active 状态主要靠文字颜色和字重区分，不再依赖高不透明蓝底。
   */
  static bottomSegGlass(isDark: boolean, active: boolean): string {
    if (!Theme.GLASS_FALLBACK_ENABLED) {
      return '#00000000';
    }
    return active ? (isDark ? '#263173FF' : '#1A3173FF') : (isDark ? '#0DFFFFFF' : '#0DF0F4F8');
  }
  /**
   * 玻璃描边（页面主体元素玻璃兜底）。
   * 白高光边（叠在官方材质上，做玻璃上缘）。
   */
  static manualGlassBorder(): string {
    if (!Theme.GLASS_FALLBACK_ENABLED) {
      return '#00000000';
    }
    return '#22FFFFFF';
  }

  /**
   * 玻璃浮起阴影（沉浸光感恒开启路径）。
   * 恒返回全零阴影 —— ImmersiveMaterial 已带 applyShadow，再叠会成双影。
   */
  static glassShadowStyle(): GlassShadowOptions {
    return IMM_EMPTY_SHADOW;
  }
  /** 手动玻璃顶部高光线（1.5vp 用 linearGradient 模拟） */
  static manualGlassHighlight(isDark: boolean): string {
    return isDark ? '#3DFFFFFF' : '#80FFFFFF';
  }
}

/**
 * 获取当前全局深色模式
 */
export function isDarkMode(): boolean {
  return _globalIsDark;
}

/**
 * 全局字号缩放：根据当前字号级别计算实际字号。
 * 所有页面应使用 Theme.fs(baseSize) 代替硬编码 .fontSize()。
 */
export function fs(baseFontSize: number, scale: number = AppStorage.get<number>('fontScale') ?? 1.0): number {
  return Math.round(baseFontSize * scale);
}

/**
 * 设置全局深色模式
 */
export function setDarkMode(isDark: boolean): void {
  _globalIsDark = isDark;
}

/**
 * 间距令牌接口
 */
export interface SpacingToken {
  xs: number;
  sm: number;
  md: number;
  lg: number;
  xl: number;
}

/**
 * 通用圆角、间距令牌（vp）
 */
export const Spacing: SpacingToken = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
};

/**
 * 圆角令牌接口
 */
export interface RadiusToken {
  sm: number;
  md: number;
  lg: number;
  full: number;
}

export const Radius: RadiusToken = {
  sm: 8,
  md: 12,
  lg: 16,
  full: 999,
};
