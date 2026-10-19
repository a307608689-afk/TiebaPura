# API 26 沉浸光感（Immersive Light Sense）官方能力全解

> **定位**：本文是**官方能力的权威底稿**（what the platform actually provides），不掺工程实现建议。
> 工程侧怎么用、有哪些历史坑 → 见 `docs/immersive-material-guide.md`；两篇配合看。
> **取证日期**：2026-09-10
> **取证方式**：华为文档中心是 Angular SPA，静态抓取拿不到正文——**在文档 URL 后加 `.md` 可直出 Markdown 正文**（例：`.../arkts-immersive-light-sense-component-adaptation.md`）。本文的官方结论同时用**本机 SDK 的 `.d.ts` 声明**做交叉验证，两者不一致处已单独标注。
> **SDK 环境**：DevEco Studio 安装目录下的 `sdk/default`（即环境变量 `$DEVECO_SDK_HOME/default`；openharmony = ArkUI 侧，hms = HDS 侧）
>
> **证据等级标注**：【官方文档】【SDK d.ts】【官方 API 参考】【本工程实测】【推断】

---

## 0. TL;DR（十句话）

1. 沉浸光感是 **API 26.0.0（HarmonyOS 7）** 才有的新能力，ArkUI 侧入口是 `uiMaterial` 命名空间 + 通用属性 `systemMaterial`，**全部成员 `@since 26.0.0`**。【SDK d.ts】
2. 它由两部分组成：**沉浸式系统材质**（本文主角）+ **沉浸式空间动效**（弹窗/菜单的形变、流光、粒子，开发者零适配）。【官方文档】
3. 生效前提三条：`targetSDKVersion ≥ 26.0.0`、`module.json5` 配 metadata 开关（**仅 entry 模块**）、设备算力档位支持。
4. 开启分**应用级**（`MaterialState`）与**组件级**（`systemMaterial`）两种；**组件级优先级更高**，但应用级 `disable` 时全局禁死。
5. **★ 生效范围是两档**：弹窗类组件/接口 + `Slider`/`Toggle`/`Select` → **页面内任意区域**都生效；**其他所有组件**（包括通用属性 `systemMaterial`）→ **只在 Navigation/NavDestination 标题栏 或 `barPosition = BarPosition.End` 的横向 Tabs 底部 TabBar** 生效。
   （B 档的"标题栏"包含**标题栏内自定义 `title` builder 的子元素** —— 2026-09-10 本工程真机实测确认，见 §14.6。）
6. **API 26 并没有放开页面主体。** 页面 body 里的吸顶胶囊、圆钮、自绘浮层挂 `systemMaterial` 依然是 `Material inactive: out of scope`。【官方文档 + 本工程实测】
   → 但**「顶部吸顶行」有解**：把整行搬进 `Navigation` 的 `title` 槽位（自定义 builder），**槽内子元素各自挂 `systemMaterial` 即可渲染**（B 档字面命中，`Material inactive` 消失）—— 2026-09-10 本工程真机已验（§14.6）。
   **页面中部玻璃**（搬不进顶部槽位的位置）仍无解，只能走 `backgroundBlurStyle` 真模糊。
7. 材质层级在 `backgroundColor` / `backgroundBlurStyle` **之下**——想看到材质必须把这些清成透明/移除。
8. **关闭**用 `uiMaterial.Material.empty`，**恢复默认**用 `undefined`，两者语义不同，别混。
9. 材质效果**随设备算力档位分叉**：高/中算力走 `materialFilter + shadow`（`style`/`colorInvert`/`lightEffect` 才有效），低算力退化到 `backgroundColor/border/shadow`。
10. 官方把沉浸光感定义成**"稀缺视觉资源"**：控面积、禁嵌套、不叠模糊/阴影、不覆盖动态内容。

---

## 1. 文档地图与两套材质体系

### 1.1 官方章节树

```
沉浸光感（arkts-immersive-light-sense）
├── 沉浸光感简介          arktss-immersive-light-sense-overview        ← 设计理念 / 两大能力 / 五档样式 / 选型
├── 沉浸光感开发指导      arktss-immersive-light-sense-development
│   ├── 开启沉浸光感        arktss-immersive-light-sense-enable          ← 开关 / 生效范围 / 关闭方式
│   ├── 组件适配沉浸光感    arktss-immersive-light-sense-component-adaptation ← 逐组件清单（本文 §6 主体）
│   ├── 沉浸式系统材质视效  arktss-immersive-light-sense-common-capability ← colorInvert/materialColor/interactive/lightEffect/applyShadow
│   └── 沉浸光感兼容性适配  arktss-immersive-light-sense-compatibility   ← ⚠️ 2026-09-10 抓取 404，疑已下线或改名
├── 沉浸光感功耗优化      arktss-immersive-light-sense-constraints      ← 七条性能约束
├── 沉浸光感常见问题      arktss-immersive-light-sense-faq              ← out of scope 等排查
└── 沉浸光感典型场景      arktss-immersive-light-sample                 ← 两个落地范式（搜索标题栏 / 多级标题上浮）
```

API 参考：`harmonyos-references/arkts-apis-uimaterial`（`@ohos.arkui.uiMaterial`）。

> **注意**：`arkts-immersive-light-sense-compatibility`（《沉浸光感兼容性适配》）目前返回 404。搜索索引里仍能看到它的摘要——"应用在接入沉浸光感时，如果需要兼容低版本，需要处理好两方面问题。一是应用级开启时，避免沉浸式系统材质属性冲突。二是组件级……"。低版本兼容的正确依据请以《开启沉浸光感》的 `targetSDKVersion ≥ 26.0.0` +《ArkTS API 兼容性保护》为准，不要依赖该页。【官方文档】

### 1.2 ArkUI `uiMaterial` vs UI Design Kit `hdsMaterial`（关键选型）

| 维度 | ArkUI `uiMaterial` | UI Design Kit `hdsMaterial` |
|---|---|---|
| 起始版本 | **26.0.0** | **6.1.0(23)** |
| 系统能力 | `SystemCapability.ArkUI.ArkUI.Full` | `SystemCapability.UIDesign.HDSComponent.Core` |
| 支持范围 | 见 §4（弹窗类 + Slider/Toggle/Select + Navigation 标题栏 / 底部 TabBar） | **仅 HDS 导航、HDS 底部页签两个组件** |
| 开启方式 | 通用属性 / options 字段 / 组件专属接口 | `TitleBarStyleOptions` 或 `HdsTabsFloatingStyle` 的 `systemMaterialEffect` |
| `MaterialType` | `IMMERSIVE = 2`（仅类型标识，不映射底层） | `NONE=0` / `ADAPTIVE=100` / `IMMERSIVE=101` |
| `MaterialLevel` | 枚举**不可设**，只能读（见 §9） | **可设**：`EXQUISITE=0`/`GENTLE=1`/`SMOOTH=2`/**`ADAPTIVE=10`** |
| 额外接口 | `getMaterialInfo()` | `getSystemMaterialTypes(): Array<MaterialType>` |

**官方选型结论**【官方文档】：
- 应用用的是 **HDS 导航 / HDS 底部页签** → 直接用 **UI Design Kit** 开启，最省事；
- 需要**更多组件或弹窗类** → 用 **ArkUI 沉浸光感**。
- HDS 的 `materialLevel` 官方**推荐 `ADAPTIVE`**（在低算力设备上强行指定 `EXQUISITE`/`GENTLE` 可能卡顿发热）。

> 这也解释了本工程 `Theme.ets` 里 `apiLevel >= 23` 这个门限的**来历**：**23 是 HDS `hdsMaterial` 的起始版本，不是 ArkUI `uiMaterial` 的**（后者是 26.0.0）。详见 §14。
> ⚠️ 该门限已于 **2026-09-10 收紧为 `>= 26`**（并加 `uiMaterial` 命名空间探测），详见 §14.3 —— 原门限会让 API 23~25 误入材质路径。

---

## 2. 生效前提（三件事，缺一不可）

| # | 前提 | 细节 | 证据 |
|---|---|---|---|
| 1 | `targetSDKVersion ≥ 26.0.0` | 低于 26.0.0 需按《ArkTS API 兼容性保护》做兼容处理 | 【官方文档】 |
| 2 | `module.json5` metadata 开关 | `name = "ohos.arkui.UIMaterial.state"`，`value ∈ {default, enable, disable}`；**该配置仅在 entry 类型的 module 中生效** | 【官方文档】【官方 API 参考】 |
| 3 | 设备能力 | 设备需支持沉浸式材质（不支持时可设但无效果）；且分高/中/低算力档位 | 【官方 API 参考】 |

```json5
// entry/src/main/module.json5 —— abilities[] 之前
"metadata": [{
  "name": "ohos.arkui.UIMaterial.state",
  "value": "enable"
}],
```

**默认开启规则**【官方文档】：
> `module.json5` **未配置**该字段时即为 `default` 模式。应用从 API 26.0.0 之前升级到 26.0.0 及以上、且未主动设置沉浸光感时，**组件默认开启沉浸光感，无需任何配置**。

---

## 3. 应用级开关 `MaterialState`

### 3.1 三态语义

| 枚举 | 值 | 语义 | 默认开启的组件 |
|---|---|---|---|
| `MaterialState.DEFAULT` | 0 | 默认模式 | Dialog、Toast、AlphabetIndexer（**仅当组件自身未设 backgroundColor / backgroundBlurStyle / shadow 时**）；Text 设 `copyOption` 后长按/双击的文本菜单。**其他组件由应用主动设置** |
| `MaterialState.ENABLE` | 1 | 使能模式 | 在 DEFAULT 基础上追加：ChipGroup、Chip、Select、菜单控制、Toggle、SegmentButton、SegmentButtonV2、Slider、SelectionMenu、Navigation、NavDestination；Tabs 在 `barFloatingStyle` 悬浮样式生效时页签栏默认开。**且材质样式优先级高于组件自身背景色/模糊/阴影/边框** |
| `MaterialState.DISABLE` | 2 | 禁用模式 | 无。即使主动设置材质参数也不生效 |

> `ENABLE` 模式下"材质优先级高于组件自身背景/模糊/阴影/边框"这一条**很关键**：它是 §12 里"为什么 DEFAULT 下 Dialog 没材质、切 ENABLE 就有了"的答案。【官方 API 参考】

### 3.2 读取当前状态

```ts
import { uiMaterial } from '@kit.ArkUI';

const info: uiMaterial.MaterialInfo = uiMaterial.getMaterialInfo();
// info.state: MaterialState（来自 module.json5 的 metadata）
// info.type : MaterialType（默认 MaterialType.IMMERSIVE）
```

`MaterialInfo.type` 官方明确：**仅用于类型标识，不映射底层功能**，实际效果由 `ImmersiveMaterial` 实现。

### 3.3 优先级规则

- 应用级设 **`disable`** → **全局禁用**，应用级/组件级开启都不生效；
- **组件级开启优先级高于应用级开启**：组件可直接覆盖应用级对该组件的效果，反之不成立。

---

## 4. ★ 生效范围（本能力最重要的一条）

### 4.1 A 档 —— 页面内**任意区域**都生效

| 类别 | 清单 |
|---|---|
| **弹窗类组件** | AlertDialog、ActionSheet、CustomDialog、CalendarPickerDialog、DatePickerDialog、TimePickerDialog、TextPickerDialog、SelectionMenu、AlphabetIndexer 弹窗、Text 设 `copyOption` 后长按/双击触发的文本菜单 |
| **弹窗类接口** | PromptAction、ArkUI_NativeDialog、`@ohos.promptAction`、Popup 控制、Tips 控制、菜单控制、半模态转场 |
| **按钮与选择类** | **Slider、Toggle、Select** |

### 4.2 B 档 —— **仅限两个槽位**

> 其他组件**仅在以下区域生效**：
> - `Navigation` / `NavDestination` 的**标题栏**
> - 横向 Tab 中 `barPosition` 为 `BarPosition.End` 的**底部 TabBar**
>
> **在其他区域设置沉浸光感效果不生效。**

**★ 2026-09-10 本工程实测补充（把 B 档用满的关键）**：B 档的「标题栏」**包含标题栏内「自定义 `title` builder」的子树** ——
把元素整行搬进 `Navigation` 的 `.title({ builder: ... })` 槽位后，**槽内任一子元素挂通用属性 `systemMaterial` 都会渲染**（不再报 `out of scope`）。
**因此「页面主体元素一律无解」不成立**：**位置在顶部 → 搬进标题栏 `title` 槽位即合法；位置在页面中部 → 仍然无解**（只能走 `backgroundBlurStyle` 真模糊）。
这不是推断，是真机验证结论（无 `Material inactive` 日志），实测与上线记录见 §14.6。【本工程实测】
> 注：这与 §6 表中 `NavigationTitleOptions.systemMaterial`「生效范围仅返回键 + 非自定义 Menu」是**两条不同路径**（槽位自身材质 vs 槽内子元素的通用属性），不矛盾。

### 4.3 越界的表现

```
Material inactive: out of scope. Use component in navigation title bar or Tabbar.
```

官方给出的两条解决措施【官方文档】：
1. 把需要材质的组件放进 Navigation/NavDestination 标题栏，或 `BarPosition.End` 的底部 TabBar；
2. 满足不了就**改用 `backgroundColor` 等通用属性**替代材质效果。

> **结论（划重点）**：通用属性 `systemMaterial` 定义在 `CommonMethod` 上（`common.d.ts:23521`），**任何组件都能编译通过**，但**渲染层按 §4.1/§4.2 裁剪**。这是"能编译 ≠ 能渲染"的典型陷阱，也是本工程 `docs/immersive-material-guide.md` §10.1 旧表述需要更正的地方（见 §14.3）。

---

## 5. ArkTS API 全量（`uiMaterial`）

> 全部成员 `@since 26.0.0`；`@stagemodelonly`；`@crossplatform`；`@atomicservice`；`Material` 基类额外支持 ArkTS 卡片（`@form`）。
> 源文件：`sdk/default/openharmony/ets/api/@ohos.arkui.uiMaterial.d.ts`；导入：`import { uiMaterial } from '@kit.ArkUI';`

### 5.1 成员总览

| 成员 | 类型 | 说明 |
|---|---|---|
| `MaterialType` | enum | 材质类型；`IMMERSIVE = 2` |
| `MaterialState` | enum | 使能状态；`DEFAULT=0` / `ENABLE=1` / `DISABLE=2` |
| `MaterialInfo` | interface | `{ state: MaterialState; type: MaterialType }` |
| `getMaterialInfo()` | function | 读应用级材质配置（来自 `module.json5`） |
| `ImmersiveStyle` | enum | 五档厚度 |
| `ImmersiveOptions` | interface | 材质参数（6 项） |
| `LightEffectOptions` | interface | `{ color?: ResourceColor }`，默认 `Color.White` |
| `Material` | class | 基类；静态 getter `Material.empty` |
| `ImmersiveMaterial` | class | `extends Material`；`constructor(options?: ImmersiveOptions)` |

### 5.2 `ImmersiveStyle` 五档

| 枚举 | 值 | 观感 | 官方建议场景 |
|---|---|---|---|
| `ULTRA_THIN` | 0 | 超薄，透明很强 | 高度透明背景，如**浮动工具栏** |
| `THIN` | 1 | 薄，透明较强 | 较强透明度，如**搜索框** |
| `REGULAR` | 2 | 常规厚度 | **通用场景** |
| `THICK` | 3 | 厚，模糊强 | 较强模糊，如**菜单** |
| `ULTRA_THICK` | 4 | 超厚，模糊很强 | 完全模糊，如**弹窗** |

### 5.3 `ImmersiveOptions` 六参数

| 参数 | 类型 | 默认值 | 生效档位 | 要点 |
|---|---|---|---|---|
| `style` | `ImmersiveStyle` | `REGULAR` | **仅高/中算力** | 低算力设备只有一种样式，枚举不生效 |
| `materialColor` | `ResourceColor` | `Color.Transparent` | **全部档位** | 高/中：在材质滤镜上再混一层纯色；**低算力：直接当 `backgroundColor` 用**。传**不透明色会完全遮挡材质滤镜** |
| `colorInvert` | `boolean` | `false` | **仅高/中算力** | 子树文字/图标颜色随材质背景反色，见 §8 |
| `applyShadow` | `boolean` | `true` | 全部档位 | `true` 时材质自带阴影**优先于**通用 `shadow`；`false` 时通用 `shadow` 生效、材质阴影失效 |
| `interactive` | `boolean` | `false` | 全部档位 | 交互形变（按压弹性形变、松手恢复） |
| `lightEffect` | `LightEffectOptions \| null` | `undefined` | 仅高/中算力 | 传对象启用流光；**传 `null` 显式禁用**；不传则跟随组件默认行为 |

构造默认值（官方 API 参考明确）：
```ts
new uiMaterial.ImmersiveMaterial()
// ≡ { style: REGULAR, materialColor: Color.Transparent, colorInvert: false,
//      applyShadow: true, interactive: false, lightEffect: undefined }
```

### 5.4 `Material.empty` vs `undefined`（易错点）

| 写法 | 语义 |
|---|---|
| `systemMaterial(uiMaterial.Material.empty)` | **关闭**该组件的沉浸光感 |
| `systemMaterial(undefined)` | **恢复组件默认**的沉浸光感效果（不是关闭！） |

> 官方原文：要关闭一个**默认为开启**沉浸光感的组件，必须用 `Material.empty`。
> 另注：**组件不支持组件级材质 API 时，`Material.empty` 也关不掉**。【SDK d.ts】
>
> **类型细节**：`SystemUiMaterial = uiMaterial.Material`（`common.d.ts:17831`）。因此 `Tabs.barFloatingStyle.systemMaterial`（类型是 `UIMaterial.ImmersiveMaterial`，`tabs.d.ts:895`）**不接受 `Material.empty`**，只能传 `ImmersiveMaterial` 实例或 `undefined`。而 `Navigation` 标题的 `systemMaterial?: Material`（`navigation.d.ts:1891`）可以收 `Material.empty`。

### 5.5 ⚠️ 本机 SDK 与官方 API 参考的**不一致**

官方 API 参考（`arkts-apis-uimaterial`）里列了三个成员：`MaterialLevel` 枚举、`getGlobalMaterialLevel()`、`isImmersiveMaterialSupported()`。
**但本机 SDK 的 `@ohos.arkui.uiMaterial.d.ts` 里没有这三个**（已逐行确认，全文 460 行，止于 `ImmersiveMaterial`）。

影响：
- 用 `uiMaterial.getGlobalMaterialLevel()` / `isImmersiveMaterialSupported()` 会**编译不过**（当前 SDK）；
- 但**原生 C API 侧有等价接口**（`OH_ArkUI_NativeModule_GetGlobalMaterialLevel` / `GetSystemMaterialSupported`，见 §13）；
- `MaterialLevel` 枚举值（`EXQUISITE=0`/`GENTLE=1`/`SMOOTH=2`）可从 `hdsMaterial.MaterialLevel`（HDS 侧，6.1.0(23)）与原生头文件印证。

> **行动建议**：若要在 ArkTS 侧做算力档位降级，先确认目标 DevEco/SDK 版本是否已补齐这三个接口；当前环境请走 `deviceInfo.sdkApiVersion` + 真机验收。**【待 SDK 升级后复核】**

---

## 6. 逐组件适配细则

### 6.1 导航类

| 组件 | 应用级(ENABLE)默认 | 默认样式 | 组件级配置项 | 限制 |
|---|---|---|---|---|
| **Navigation 标题栏** | ✅ 开 | `ULTRA_THIN` | `NavigationTitleOptions.systemMaterial`（`navigation.d.ts:1891`，`@since 26.0.0`） | 生效范围**仅限返回键 + 非自定义 Menu**；建议 `barStyle = STACK` 让内容延伸到标题栏下；建议只在顶部标题栏等局部区域用 |
| **底部页签 Tabs** | ❌ **不开**（需 `barFloatingStyle` 且悬浮样式生效才默认开） | `THIN` | `FloatingTabBarStyle.systemMaterial`（`tabs.d.ts:895`，类型 `ImmersiveMaterial`） | 悬浮样式需**三条件同时满足**：`barOverlap = true`、`vertical = false`、`barPosition = BarPosition.End`，否则 `systemMaterial` 不生效；设了悬浮材质后**不建议**再设 `barBackgroundColor` / `barBackgroundBlurStyle`；**`TabContent` 不支持**设置沉浸光感 |
| **AlphabetIndexer** | ✅ 开 | `THICK` | 无独立字段：`popupBackground` 与 `popupBackgroundBlurStyle` **均未主动设置**（或传 `undefined`）时提示弹窗默认开；也可用通用属性 `systemMaterial` | **低算力设备不显示（白色背景）**；`popupBackground` / `popupBackgroundBlurStyle` 与沉浸光感**互斥** |

### 6.2 弹窗类

| 组件/接口 | 应用级(ENABLE)默认 | 默认样式 | 组件级配置项 | 限制 |
|---|---|---|---|---|
| **Toast** | ✅ 开 | `THICK` | `ShowToastOptions.systemMaterial`（`@ohos.promptAction.d.ts:327`） | 主动设了 `backgroundBlurStyle` / `backgroundColor` → **不生效** |
| **Popup / Tips** | ❌ 不开 | — | `PopupOptions.systemMaterial` / `TipsOptions.systemMaterial`（`common.d.ts:13830 / 14031 / 14688 / 15270`） | 需组件级主动设置 |
| **Menu（菜单控制）** | ✅ 开 | `THICK` | `ContextMenuOptions.systemMaterial` | — |
| **Dialog 系列** | ✅ 开 | `ULTRA_THICK` | `CustomDialogControllerOptions`（`custom_dialog_controller.d.ts:681`）、`AlertDialogParam`（`alert_dialog.d.ts:894`）、`ActionSheetOptions`（`action_sheet.d.ts:834`）、`SheetOptions`（`common.d.ts:13019`） | 主动设了背景色/模糊 → 不生效；**大面积弹窗不建议开**；**CalendarPicker 拉起的弹窗暂不支持**（通用属性设的材质会落在 CalendarPicker 组件本身）；`CalendarPickerDialog`/`DatePickerDialog`/`TextPickerDialog`/`TimePickerDialog` 效果**同 CustomDialog** |

> `DatePickerDialog` / `TimePickerDialog` / `TextPickerDialog` / `CalendarPickerDialog` 的 options 里同样有 `systemMaterial?: SystemUiMaterial`（`date_picker.d.ts:1075`、`time_picker.d.ts:1005`、`text_picker.d.ts:1747`、`calendar_picker.d.ts:590`）。

### 6.3 按钮与选择类

> 这类组件的 `interactive`（交互形变）与 `lightEffect`（点光源）会**替代组件默认的按压态/悬浮态**。

| 组件 | 应用级(ENABLE)默认 | 默认样式 | 组件级配置项 | 限制 |
|---|---|---|---|---|
| **Button** | ❌ 不开 | — | 通用属性 `systemMaterial` | `style` 为 `THIN`/`ULTRA_THIN` 时，`fontColor` 用系统预定义可反色资源才会自动反色；启用 `lightEffect` 后**默认点击态/悬浮态不再展示**；未设 `buttonStyle`/`backgroundColor` 且未设材质颜色时，**默认生效 Button 主题色的材质样式** |
| **Select** | ✅ 开（按钮 + 菜单**均**开） | 按钮 `ULTRA_THIN`（默认开 `interactive` + `lightEffect`）；菜单 `THICK` | 按钮：通用属性 `systemMaterial`；菜单：`menuSystemMaterial`（`select.d.ts:1131`） | 按钮与菜单**相互独立**；**单独关闭要用 `uiMaterial.Material.empty`，不能设 `undefined`**；按钮启用 `lightEffect` 后默认按压/悬浮态不再展示 |
| **Toggle** | ✅ 开 | — | 通用属性 `systemMaterial` | **`ToggleType.Checkbox` 未适配**（设了无效）；`ToggleType.Switch` 传参**仅作开关标记**，实际用组件内部预设参数（影响滑块大小/样式/阴影），效果**随算力档位变化**；`ToggleType.Button` 效果同 Button |
| **Slider** | ✅ 开 | — | 通用属性 `systemMaterial` | 传参**仅作开关标记**；传 `undefined` 恢复原 Slider 样式；交互反馈**仅**在 `SliderBlockType.DEFAULT` 且 `SliderStyle ≠ NONE` 时生效 |
| **ChipGroup** | ✅ 开 | `ULTRA_THIN` | `backgroundSystemMaterial` / `selectedBackgroundSystemMaterial` / `iconBackgroundSystemMaterial`（`@ohos.arkui.advanced.ChipGroup.d.ets`，均 `@since 26.0.0`） | 需自动反色时必须用系统预定义可反色资源，**硬编码颜色不触发** |
| **Chip / ChipV2** | ✅ 开 | — | `backgroundSystemMaterial` / `activatedBackgroundSystemMaterial`（`@ohos.arkui.advanced.Chip.d.ets` / `ChipV2.d.ets`） | 同上 |
| **SegmentButton / V2** | ✅ 开 | `THIN` | `SegmentButtonOptions.backgroundSystemMaterial`（`@ohos.arkui.advanced.SegmentButton.d.ets`）；V2 各类 options 同名字段 | **胶囊类多选分段按钮（`type="capsule"` 且 `multiply=true`）不支持**，设了不生效；V2 开启后选中项背景支持**跟随手指拖拽**；`colorInvert = true` 时 `fontColor`/`selectedFontColor` 等用支持反色的系统资源才会自动适配 |
| **SelectionMenu** | ✅ 开 | — | `backgroundSystemMaterial`（`@ohos.arkui.advanced.SelectionMenu.d.ets`） | — |

### 6.4 其余组件

均支持通过**通用属性 `systemMaterial`** 设置，但**生效区域受 §4.2 限定**（Navigation/NavDestination 标题栏 或 `BarPosition.End` 的底部 TabBar）。例如布局容器、滚动容器。

> **`systemMaterial` 方法签名**（`common.d.ts:23521`，`@since 26.0.0`）：
> ```ts
> systemMaterial(material: SystemUiMaterial | undefined): T;
> ```
> 官方注释明确：该属性**影响 `backgroundColor` / `borderColor` / `borderWidth` / `shadow`**，**不建议**与这些 API 同用。

---

## 7. 开启 / 关闭：完整决策表

### 7.1 组件级开启的三种方式【官方文档】

| # | 方式 | 示例 |
|---|---|---|
| 1 | 通用属性 `systemMaterial` | `Column().systemMaterial(new uiMaterial.ImmersiveMaterial({...}))` |
| 2 | 弹窗类 options 字段 | `ShowToastOptions.systemMaterial`、`CustomDialogControllerOptions.systemMaterial` |
| 3 | 组件专属接口 | Select 下拉菜单 `menuSystemMaterial`、Navigation 标题栏 `systemMaterial` |

> 方式 2 走 options 传参，**不受"属性设置顺序"影响**；方式 1 需要把 `systemMaterial` 写在其他样式属性**之后**（见 §12）。

### 7.2 关闭决策

| 目标 | 写法 |
|---|---|
| 关掉某个组件的材质（应用级/组件级开启的都适用） | `systemMaterial(uiMaterial.Material.empty)` |
| 关掉应用级开启的组件（不动组件代码） | 应用级开关改 `disable` |
| 恢复组件**默认**沉浸光感行为 | `systemMaterial(undefined)` |
| Select 下拉菜单单独关 | `menuSystemMaterial(uiMaterial.Material.empty)`（**不是** `undefined`） |

---

## 8. `colorInvert` 自动反色详解

### 8.1 四个必须同时满足的条件【官方文档】

1. **算力档位**：高算力或中算力设备（低算力设备**无视觉差异**）；
2. **材质样式**：必须是 `THIN` 或 `ULTRA_THIN`（`REGULAR` / `THICK` / `ULTRA_THICK` **不生效**）；
3. **系统配置**：系统设置里"沉浸光感"强弱影响反色触发阈值——**材质越薄、系统光感越强，越容易触发**；
4. **颜色来源**：**仅对通过资源接口设置的颜色值生效**（如 `$r('sys.color.xxx')`）；硬编码 `Color.White`、`'#FFFFFFFF'` **不触发**。

### 8.2 已明确支持反色的属性【官方 API 参考】

`Text.fontColor`、`Button.fontColor`、`SymbolGlyph.fontColor`、`Image.fillColor`、
`Search` 的 `placeholderColor` / `fontColor` / `searchIcon` 图标色 / `cancelButton` 图标色 / `caretStyle` 光标色 / `searchButton` 按钮色、
`TabContent.tabBar`（`BottomTabBarStyle` 样式下）、
`Chip` 的 `prefixIcon`/`suffixIcon` 的 `fillColor` 与 `label` 的 `fontColor`、
`ChipGroup.itemStyle.fontColor`、`TextArea.fontColor`/`placeholderColor`、`TextInput.fontColor`/`placeholderColor`、
`SegmentButton.fontColor`、`Swiper.fontColor`。

### 8.3 触发反色的系统资源值（摘录，官方表 1）

| 资源值 | 浅色 | 深色 |
|---|---|---|
| `$r('sys.color.brand')` | `#FF0A59F7` | `#FF317AF7` |
| `$r('sys.color.brand_font')` | `#FF0A59F7` | `#FF5291FF` |
| `$r('sys.color.warning')` | `#FFE84026` | `#FFD94838` |
| `$r('sys.color.font_on_primary')` | `#FFFFFFFF` | `#FFFFFFFF` |
| `$r('sys.color.font_primary')` | `#E5000000` | `#E5FFFFFF` |
| `$r('sys.color.font_secondary')` | `#99000000` | `#99FFFFFF` |
| `$r('sys.color.font_tertiary')` | `#66000000` | `#66FFFFFF` |
| `$r('sys.color.font_fourth')` | `#33000000` | `#33FFFFFF` |
| `$r('sys.color.font_emphasize')` | `#FF0A59F7` | `#FF5291FF` |
| `$r('sys.color.icon_primary')` | `#E5000000` | `#E5FFFFFF` |
| `$r('sys.color.icon_secondary')` | `#99000000` | `#99FFFFFF` |
| `$r('sys.color.icon_tertiary')` | `#66000000` | `#66FFFFFF` |
| `$r('sys.color.icon_fourth')` | `#33000000` | `#33FFFFFF` |
| `$r('sys.color.icon_emphasize')` | `#FF0A59F7` | `#FF5291FF` |
| `$r('sys.color.icon_sub_emphasize')` | `#660A59F7` | `#665291FF` |
| `$r('sys.color.comp_background_primary_contrary')` | `#FFFFFFFF` | `#FFE5E5E5` |
| `$r('sys.color.comp_background_primary_contrary_secondary')` | `#FFFFFFFF` | `#FF666666` |
| `$r('sys.color.comp_background_secondary')` | `#19000000` | `#19FFFFFF` |
| `$r('sys.color.comp_background_tertiary')` | `#0C000000` | `#19FFFFFF` |
| `$r('sys.color.comp_background_emphasize')` | `#FF0A59F7` | `#FF317AF7` |
| `$r('sys.color.comp_emphasize_secondary')` | `#330A59F7` | `#33317AF7` |
| `$r('sys.color.comp_emphasize_tertiary')` | `#190A59F7` | `#19317AF7` |
| `$r('sys.color.comp_divider')` | `#33000000` | `#33FFFFFF` |
| `$r('sys.color.interactive_hover')` | `#0C000000` | `#19FFFFFF` |
| `$r('sys.color.interactive_focus')` | `#FF0A59F7` | `#FF317AF7` |
| `$r('sys.color.interactive_pressed')` | `#19000000` | `#26FFFFFF` |

> **功耗提示**：反色会对材质子树里"通过资源接口设置的颜色"**逐个计算**，子树越大开销越高——避免在大范围文本/图标区整体开 `colorInvert`。

---

## 9. 设备算力档位（`MaterialLevel`）

| 枚举 | 值 | 含义 | 效果实现方式 | `style` | `colorInvert` | `lightEffect` | `materialColor` | `applyShadow` / `interactive` |
|---|---|---|---|---|---|---|---|---|
| `EXQUISITE` | 0 | 高算力 | `materialFilter` + `shadow` | ✅ | ✅ | ✅ | ✅（滤镜叠加纯色） | ✅ |
| `GENTLE` | 1 | 中算力 | `materialFilter` + `shadow` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `SMOOTH` | 2 | 低算力 | `backgroundColor` / `borderColor` / `borderWidth` / `shadow` | ❌ | 无视觉差异 | ❌ | 作为背景色值生效 | ✅ |
| （不支持材质的设备） | — | — | 可设置但**无效果** | ❌ | ❌ | ❌ | ❌ | ❌ |

**要点**：
- 档位由**设备定义、不可修改**；
- 同一材质效果还受**系统设置里"沉浸光感"强弱配置**影响，不同强弱下材质参数与效果有差异；
- **沉浸式系统材质会随系统深浅色模式自动切换效果**；
- 官方适配建议：用能力/档位查询接口判断后，用**同一套代码**在不同设备上自动降级为普通样式。

> 查询接口：ArkTS 侧见 §5.5（本机 SDK 暂缺）；HDS 侧 `hdsMaterial.getSystemMaterialTypes()`；原生侧见 §13。

---

## 10. 功耗优化（官方七条 + 验收清单）

### 10.1 七条约束

| # | 约束 | 原因 |
|---|---|---|
| 1 | **控制材质使用面积** | 受影响区域越大 → 处理像素越多 → 功耗越高。避免单个超大区域、避免大量小区域重复使用。推荐只在 Navigation 标题栏 / 底部 Tabs 中**少量使用**，限定在需凸显的局部区域 |
| 2 | **避免材质嵌套** | 嵌套会重复计算，功耗↑ 且视觉相互干扰。**同一子树只在最外层设一次** |
| 3 | **避免与模糊叠加** | `materialFilter` 自带背景模糊，再叠 `backgroundBlurStyle` / `backgroundEffect` 是重复处理 |
| 4 | **避免重复叠加阴影** | 材质默认已通过 `applyShadow` 提供阴影；要自定义阴影须先 `applyShadow: false` |
| 5 | **控制 `colorInvert` 作用范围** | 反色逐色计算，子树越大开销越高 |
| 6 | **保持材质参数与区域稳定** | 频繁改 `style`/`materialColor`，或材质区域内频繁增删子节点 → 触发材质重算（反例：定时器每 100ms 改材质颜色） |
| 7 | **避免在动态内容上方使用** | 材质折射/模糊需**实时采样背后内容**；背景是视频/动图时需持续重采样，功耗显著上升 |

### 10.2 弹窗尺寸

> 高算力设备上，沉浸光感强度设为**强**或**均衡**时，Dialog、Menu 默认附带**形变、流光等沉浸式空间动效** → 面积越大动效绘制开销越高，**避免接近全屏的超大面积 Dialog/Menu**（官方正例 328×216）。

### 10.3 落地验收 Checklist【推断：由官方约束提炼，非原文】

| # | 检查项 | 判定依据 |
|---|---|---|
| 1 | 材质区域是否限定在 §4 白名单内 | 越界即不生效 |
| 2 | 同一子树是否只在最外层设一次 `systemMaterial` | 内层设置即嵌套 |
| 3 | 是否同时设了 `systemMaterial` 与 `backgroundBlurStyle`/`backgroundEffect` | 叠加即重复处理 |
| 4 | 是否同时存在 `systemMaterial`（`applyShadow` 默认 true）与自定义 `shadow` | 重复且冲突 |
| 5 | `colorInvert` 是否限制在小范围 | 大范围增加计算量 |
| 6 | `style`/`materialColor` 是否被高频修改 | 定时器/动画中修改需整改 |
| 7 | 材质区域内子树是否频繁增删 | 触发重算 |
| 8 | 材质层是否覆盖在视频/动图之上 | 实时重采样 |
| 9 | 弹窗尺寸是否接近全屏 | 强/均衡强度下动效开销高 |

> 官方**未**提供正式的性能基线数值（帧率/GPU 阈值）与测试方法，也未提及系统"低功耗模式"与沉浸光感的联动。

---

## 11. 官方典型场景（两个落地范式）

> 来源：`arkts-immersive-light-sample`

### 11.1 场景 1：搜索框标题栏（滚动收缩）

骨架：`ExpandSafeArea([SafeAreaType.SYSTEM])` 打通安全区 → `Tabs(barPosition: End)` + `barOverlap(true)` + `barFloatingStyle({ barBottomMargin: 8, systemMaterial: new uiMaterial.ImmersiveMaterial({}) })` → 每个 Tab 内的 `Navigation` 用 `hideTitleBar(true)` → 目标页用 `NavigationTitleOptions` 开标题栏材质（`Search` 加 `.systemMaterial(...)`，`ChipGroup` 用 `backgroundSystemMaterial: new uiMaterial.ImmersiveMaterial({ colorInvert: true, interactive: true })`）。

滚动联动：
```
this.scrollOffset += yOffset
if (scrollOffset <= 50) {
  titleOffset   = scrollOffset
  titleHeight   = totalTitleHeight - titleOffset   // totalTitleHeight = 110
  searchOpacity = 1 - titleOffset / 50
}
```
- 标题栏 `.position({ x: 0, y: -this.titleOffset })`；
- 滚动容器 `.contentStartOffset(this.totalTitleHeight)` 避让；
- 标题栏模糊：`scrollEffectOptions: { scrollEffectType: ScrollEffectType.GRADUAL_BLUR }`（`navigation.d.ts:1879`，`@since 26.0.0`）。

### 11.2 场景 2：内容区小标题"上浮合并"进标题栏

- 把内容区小标题抽成独立组件（`ChipGroup` + `backgroundSystemMaterial: ImmersiveMaterial({ colorInvert: true, interactive: true })`）；
- 用 `getUIContext().getComponentUtils().getRectangleById()` 在 `onShown` 里测 `titleStart`/`titleEnd`/`contentOffset`（`px2vp` 换算）；
- `onDidScroll` 里按 `curOffset` 与 `titleEnd` 的关系**三态切换**：`> titleEnd` 隐藏标题、`< titleEnd` 显示、居中区间做 `titleHeight` 过渡；
- 标题栏 builder 按 `showTitle` 在「文字」与 `ClassifyComponent` 之间切换；右侧 AI 按钮用 `systemMaterial(new uiMaterial.ImmersiveMaterial({ lightEffect: { color: Color.White }, materialColor: '#d3d3d3' }))`；
- 同样 `barStyle: BarStyle.STACK` + `GRADUAL_BLUR` + `hideBackButton(true)` + `expandSafeArea`。

### 11.3 两场景共用技术骨架

```
ExpandSafeArea(SYSTEM)  →  ImmersiveMaterial  →  BarStyle.STACK + GRADUAL_BLUR  →  onDidScroll 驱动联动
```

---

## 12. FAQ 速查（官方 + 本工程实测）

| 现象 | 根因 | 解法 |
|---|---|---|
| 日志 `Material inactive: out of scope` | 组件不在 §4 白名单区域 | 挪进 Navigation 标题栏 / `BarPosition.End` 底部 TabBar；否则改 `backgroundColor` |
| 设了材质但看不到玻璃 | ① 不在生效范围；② `backgroundColor` 不透明或 `backgroundBlurStyle` 遮挡（材质层级在它们**之下**）；③ 自绘组件背景色作用在**内容层**、材质在**背板层**，被内容层盖住；④ **属性顺序**问题——`systemMaterial` 写在其他样式属性**之前** | 背景设 `Color.Transparent` 或移除；移除模糊；把 `systemMaterial` 放到其他样式属性**之后**（走 options 传参不受顺序影响） |
| DEFAULT 模式下 Dialog/Toast 没材质 | DEFAULT 下这些组件**仅在未设 `backgroundColor`/`backgroundBlurStyle`/`shadow` 时才默认开** | 移除冲突属性；或切 **ENABLE** 模式（材质优先级更高、更多组件默认开）；或主动 `systemMaterial` |
| 开了 `colorInvert` 但文字颜色不变 | 见 §8.1 四个条件（档位/样式/系统配置/颜色来源） | 换 `THIN`/`ULTRA_THIN`；颜色改用 `$r('sys.color.*')`；调高系统光感 |
| 材质边框呈现周围背景颜色 | 材质的**正常光学折射**，薄材质（`ULTRA_THIN`/`THIN`）更明显 | 换厚材质（`REGULAR`/`THICK`/`ULTRA_THICK`）；或用 `materialColor` 赋色降低折射可见度 |
| `materialColor` 传不透明色后材质消失 | 它是在 `materialFilter` 上再混一层纯色，不透明色会遮挡滤镜 | 传带透明度的颜色（如 `'#80FF0000'`） |
| `shadow` 不生效 | `applyShadow` 默认 `true`，材质自带阴影优先 | 自定义阴影须先 `applyShadow: false` |
| 低算力设备效果差异大 | 系统级自适应：低算力只走 `backgroundColor`/`border`/`shadow`，`style` 与 `colorInvert` 无效 | 无需写差异化代码；如需降级用档位查询接口 |
| 材质渲染区域和可视区域不一致 | 材质渲染区由**组件布局区域**决定 | 用 `width`/`height`/`borderRadius` 对齐；**Text 无法只给文本本身加材质** |
| 卸载重装后才生效 / 改动"没反应" | 签名/旧缓存干扰 | 先卸载重装再验证【本工程实测】 |
| 模拟器完全看不到材质 | 模拟器不渲染系统材质 | 必须**真机**验收【本工程实测】 |

---

## 13. 原生 C API（`native_material.h`，`@since 26.0.0`）

> 头文件：`sdk/default/openharmony/native/sysroot/usr/include/arkui/native_material.h`
> 库：`libace_ndk.z.so`；对应属性：`NODE_SYSTEM_MATERIAL`。

| 类别 | 接口 |
|---|---|
| 枚举 | `ArkUI_ImmersiveStyle`（`ARKUI_IMMERSIVE_STYLE_ULTRA_THIN/THIN/REGULAR/THICK/ULTRA_THICK`）<br>`ArkUI_MaterialLevel`（`ARKUI_MATERIAL_LEVEL_EXQUISITE/GENTLE/SMOOTH`） |
| 能力查询 | `OH_ArkUI_NativeModule_GetSystemMaterialSupported()`<br>`OH_ArkUI_NativeModule_GetGlobalMaterialLevel()` |
| 材质对象 | `OH_ArkUI_NativeModule_ImmersiveMaterial_Create(style)` / `_Destroy(handle)` |
| 属性读写 | `_SetStyle` / `_GetStyle`、`_SetMaterialColor`（`0xAARRGGBB`）/ `_GetMaterialColor`、`_SetApplyShadow` / `_GetApplyShadow`、`_SetInteractive` / `_GetInteractive` |
| 光效 | `OH_ArkUI_NativeModule_LightEffectOptions_Create()` / `_Destroy()` / `_SetColor()`、`_ImmersiveMaterial_SetLightEffect()` / `_GetLightEffectColor()` |

**语义补充（原生头文件比 ArkTS 文档更细）**：
- `GetSystemMaterialSupported() == false` 时，设 `NODE_SYSTEM_MATERIAL` **无效**；
- `SetStyle` 官方注明"**仅对 exquisite / gentle 材质有效**"（即低算力无效）；
- `SetMaterialColor` 未设时：exquisite/gentle 为**透明**，smooth 用**该档默认背景色**；`GetMaterialColor` 在**从未设置**时返回 `ARKUI_ERROR_CODE_PARAM_ERROR`；
- `SetInteractive` 未设时**跟随组件行为**（与 ArkTS 默认 `false` 表述不同，注意）；
- `SetLightEffect` 传 **NULL 即禁用**；`GetLightEffectColor` 在从未设置或已禁用时返回 `ARKUI_ERROR_CODE_PARAM_ERROR`。

---

## 14. 与本工程（TiebaPura）的对照

### 14.1 已满足的前提

| 前提 | 工程现状 | 结论 |
|---|---|---|
| `targetSDKVersion ≥ 26.0.0` | `build-profile.json5` → `"targetSdkVersion": "26.0.0"` | ✅ |
| 应用级开关 | `entry/src/main/module.json5` → `metadata: { ohos.arkui.UIMaterial.state: enable }` | ✅ |
| 入口模块类型 | `entry` | ✅ |

### 14.2 点位合法性体检（按 §4 判定）

| 工程点位 | 落点 | 判定 |
|---|---|---|
| 底栏悬浮胶囊（`ImmMaterial.floatingBar()`） | `Tabs.barFloatingStyle.systemMaterial`（`barPosition: End` + `barOverlap(true)` + `vertical(false)`） | ✅ **B 档合法** |
| 各主 Tab 页 / 二级页顶栏（Navigation `title` 槽位 `systemMaterial`） | Navigation 标题栏 | ✅ **B 档合法** |
| 帖子详情底部 dock（`ThreadDetail` ImmersiveDockShell） | 真实 Tabs 悬浮槽位 | ✅ **B 档合法** |
| Search 页模块选择器（`ImmersiveShell`） | 真实 Tabs `barFloatingStyle` | ✅ **B 档合法** |
| 首页顶栏「推荐 / 关注动态」胶囊、搜索圆钮（`HomeTab`） | **已搬进 `Navigation` 标题栏的 `title` 槽位**（自定义 builder），槽内子元素各自挂 `systemMaterial` | ✅ **B 档合法**（2026-09-10 真机已验生效，§14.6）—— 原判定「页面 body 吸顶叠放 → B 档外 → 只能真模糊兜底」已被推翻 |
| ThreadList 吧内排序段（`SortTabsBuilder`）、吧头签到胶囊 | 页面 body 吸顶叠放 | ❌ **B 档外** → 现走 `backgroundBlurStyle` 真模糊兜底；**可迁移**（同属"顶部吸顶行"，模板见 §14.6 / 指南 §6.7） |
| 自绘弹窗浮层（ForumsTab / Favorite 各弹窗卡） | 页面 body 顶层 Stack 叠放，**非系统 Dialog** | ❌ **B 档外**（官方 A 档只覆盖系统 Dialog/弹窗类组件与接口，不含自绘浮层）→ 已走 `sheetGlass` 真模糊 |

> 结论（2026-09-10 修订）：**"官方槽位走材质、范围外走真模糊兜底"的架构仍成立**，但**"页面主体一律无解"不再成立** ——
> **顶部吸顶行**可以靠「搬进 `Navigation` 的 `title` 槽位」取得官方材质（§14.6，真机已验）。判据细化为：
> **① 能搬进顶部 `title` 槽位 → 用官方材质；② 位置在页面中部 / 搬不进去 → `backgroundBlurStyle` 真模糊兜底。**

### 14.3 ⚠️ 需要更正的两处旧口径

**（1）✅ 已处理（2026-09-10）：`Theme.ets` 的能力门限偏松 → 已收紧为 `>= 26`**

```
entry/src/main/ets/common/Theme.ets:25-40（现状）
  _materialApiLevel = deviceInfo.sdkApiVersion;
  // ⚠️ 门限必须是 26，不是 23：uiMaterial / systemMaterial / barFloatingStyle 均为 @since 26.0.0；
  //    6.1.0(23) 是 UI Design Kit hdsMaterial 的起始版本，两者不是同一套 API。
  if (_materialApiLevel < 26) { _materialSupported = false; return; }
  // 命名空间探测：即便系统上报 ≥26，也确认 uiMaterial 真的可构造（低版本/异常会抛，落到 catch）
  const probe: uiMaterial.ImmersiveMaterial = new uiMaterial.ImmersiveMaterial();
  _materialSupported = !!probe;
```

- ArkUI `uiMaterial` / 通用属性 `systemMaterial` / `barFloatingStyle` **全部是 `@since 26.0.0`**；
- `23` 是 **HDS `hdsMaterial`**（`@kit.UIDesignKit`）的起始版本，两者不是一回事；
- 因此 `>= 23` 会让 API 23~25 的设备走进"材质路径"，而该版本根本没有 `uiMaterial` → **潜在运行时风险**（取决于是否有其它保护）。

> ✅ **已于 2026-09-10 落地（用户拍板后执行）**：门限收紧为 `>= 26` ＋ `uiMaterial` 命名空间探测。
> **复核结论 —— 低版本确实会被调用**：`ImmMaterial.*` 在本工程有 100+ 处**无条件**调用（`.systemMaterial(ImmMaterial.X())`，24 个文件），没有任何逐点判断。故新增 `createMaterial()` 统一构造：不支持 / 构造失败一律返回 `undefined` ——`common.d.ts:23511` 官方注释原文 *Setting it to **undefined** will make the component return to the no-material effect*，即「无材质」正是官方语义。`ImmMaterial.*` 与各 `ensureXxx()` 返回类型随之放宽为 `| undefined`，**所有调用点零改动**（`systemMaterial(material: SystemUiMaterial | undefined)` 与各 options 的 `systemMaterial?` 都接受 undefined）。
> 顺带修复：`Index.ets` 底栏 `MaterialManager.isSupported() ? Color.Transparent : Theme.manualGlass(...)` 在 API 23~25 上原本会丢兜底色（门限一收紧即自动归位）。构建 `BUILD SUCCESSFUL`。

**（2）`docs/immersive-material-guide.md` §10.1 表格中"组件通用属性：页面主体任意元素直接挂载即渲染"表述有误**

- 官方 §4 明确：**其他组件（含通用属性）只在 Navigation/NavDestination 标题栏 或 `BarPosition.End` 底部 TabBar 生效**；
- 该文件 §10.3 已用真机 probe 得出正确结论（自绘弹窗挂材质仍不渲染），但 §10.1 的表格没同步，两处自相矛盾；
- 已在 §10.1 该行加更正指向本文。

### 14.4 可选优化点（按官方 §10）

- 同屏材质层数控制在 ≤ 2；长列表内不要逐项挂厚材质；
- 检查是否存在 `systemMaterial` 与 `backgroundBlurStyle` / `backgroundEffect` 叠加的点位（工程内 `ImmBlur.*` 已统一返回空效果，风险较低，但仍建议全量扫一遍）；
- 检查是否存在 `systemMaterial`（`applyShadow` 默认 true）与自定义 `.shadow` 并存（工程内 `Theme.glassShadowStyle()` 已统一返回全零阴影，风险较低）；
- `ImmMaterial.*` 各预设建议核对 `style` 与官方建议场景是否匹配（如 `fab()` 用 `THICK`、`control()` 用 `ULTRA_THIN`，方向一致）。

### 14.5 ★ 2026-09-10 落地：一键签到弹窗改系统 CustomDialog 吃官方材质

**背景**：工程内弹窗长期是「页面 body 自绘 Stack 浮层 + `Theme.sheetGlass` + `backgroundBlurStyle` 真模糊」，因为 §14.2 已确认自绘浮层挂材质必判 out of scope。本次换思路——**把弹窗宿主换成系统 `CustomDialog`**，让弹窗进入官方 A 档，材质即可生效。

**改动**：`ForumsTab.ets` 的 `@Builder SignAllDialog()`（自绘浮层）→ 顶层 `@CustomDialog struct SignAllDialog` + `CustomDialogController`；`Theme.ImmMaterial` 新增 `dialog()` 预设（`REGULAR` + `interactive: false` + `applyShadow: true`，对齐原 `BlurStyle.Regular` 观感）。

**几何 / 内容对齐（逐项一致）**：

| 项 | 原自绘浮层 | 现系统弹窗 |
|---|---|---|
| 宽度 | `.width('calc(100% - 48vp)')` | `options.width = 屏幕宽 - 48vp`（数值 vp） |
| 圆角 | `.borderRadius(32)` | `options.cornerRadius = 32`（恰为 `customStyle=false` 默认值） |
| 内边距 / 文案 / 字号 / 按钮 44 高 + `Radius.full` | — | 原样保留 |
| 底部锚点 | `.margin({ bottom: 110 })` + `alignContent(Bottom)` | `alignment: DialogAlignment.Bottom` + `offset: { dy: -110 }` |
| 遮罩 | `#06000000` 自绘 Column | `options.maskColor = '#06000000'` |
| 入场动画 | `.transition(scale .92 + translate y24 + opacity, 220ms)` | `openAnimation 220ms EaseOut` / `closeAnimation 200ms EaseInOut`（曲线近似，非等价） |
| 玻璃 | `sheetGlass` + `backgroundBlurStyle(Regular, 0.85)` + 0.5 描边 + `shadow radius48` | **`options.systemMaterial`**（材质接管背景色 / 背景模糊 / 边框 / 阴影，故卡内这五项全部移除） |
| 显隐驱动 | `if (this.showSignAll) { this.SignAllDialog() }` | `@State @Watch('onShowSignAllChanged') showSignAll` → `controller.open()/close()`，既有赋值点零改动 |
| 点遮罩 | 自绘 Column `.onClick(closeSignAll)` | `onWillDismiss` → `closeSignAll()`（进行中=中断任务且不关闭；结束=关闭） |

**踩到的两个硬约束（都是编译期/官方明文，必须记住）**：

1. **`customStyle` 必须为 `false`** —— 官方字段说明：`customStyle = true` 时弹窗背景色强制透明、**圆角归 0**、且**沉浸光感效果不生效**。想「几何完全自控 + 材质」是做不到的。
2. **`width` 不接受 `calc` 字符串** —— `width?: Dimension`，`'calc(100% - 48vp)'` 直接编译报错 `Type '"calc(100% - 48vp)"' is not assignable to type 'Dimension'`；`'100%'` 的参照物是**窗口宽**。故改成按屏幕宽换算的数值 vp（`display.getDefaultDisplaySync().width / densityPixels - 48`）。
3. `@CustomDialog` 结构体**必须声明一个 `CustomDialogController` 类型属性**，否则编译报 `10905211`。

**遗留偏差（已知，需真机确认）**：
- 弹窗容器宽度受系统上限约束（默认最大 **400vp**）→ 宽屏 / 平板（窗口 > 448vp）上卡片会比原 `100% - 48vp` 窄，这是硬限制，无法绕过；
- 容器是否自带默认内边距未在官方文档中说明，需真机上量一次；若有多余内缩，用内容 `padding` 反向补偿；
- 材质渲染管线与 `backgroundBlurStyle` 不同，玻璃观感**不可能像素级一致**（本次目标即为「换成官方材质」）。

**低版本行为**：`compatibleSdkVersion` 仍是 `6.1.0(23)`，API 23~25 设备上 `systemMaterial` 字段会被忽略 → 弹窗退化为系统默认样式（不崩），与工程其它 `systemMaterial` 点位的既有降级口径一致。
（2026-09-10 加固后更稳：低版本上 `ImmMaterial.dialog()` 经 `createMaterial()` 直接返回 `undefined`，**不会去构造低版本不存在的 `uiMaterial` 实例**，门限与安全网见 §14.3。）

### 14.6 ★ 2026-09-10 落地：**顶部吸顶行搬进 `Navigation` 的 `title` 槽位**（B 档「顶部槽位」打通）

**背景**：§14.2 原判「首页顶栏胶囊 / 搜索圆钮 = 页面 body 吸顶叠放 → B 档外 → 只能真模糊兜底」。本次换落点——
**把这一整行搬进 `Navigation` 的 `title` 槽位**，玻璃交给**槽内子元素各自的通用属性 `systemMaterial`**，**真机渲染成功**。

| 项 | 结论 |
|---|---|
| 官方依据 | **B 档字面命中**：官方「其他组件（含通用属性 `systemMaterial`）只在 Navigation/NavDestination 标题栏 或 `barPosition = BarPosition.End` 的横向 Tabs 底部 TabBar 生效」。自定义 `title` builder 就渲染在**标题栏区域内**，故其子元素落在生效范围内。 |
| 与 `NavigationTitleOptions.systemMaterial` 的关系 | 后者官方注明生效范围**仅返回键 + 非自定义 Menu**；本次用的是**槽内子元素自身的通用属性**，是另一条路径，两者不冲突。「槽内子元素合法」由本工程实测确认。 |
| 与 §14.5 的关系 | 并列成对：**A 档宿主（系统 `CustomDialog`）的子树合法**（§14.5）、**B 档顶部槽位的子树合法**（本节）。唯一禁区剩下「**页面 body 里的自绘浮层**」—— 分界在**宿主槽位**，不在层级深浅。 |
| 代价 | 页面 `build()` 根多一层 `Navigation` 壳（工程此前 `Navigation` 组件数为 0）；几何可逐项对齐，但观感由「半透明 + 0.5 描边 + 轻投影」变为系统玻璃。 |

**必配写法（漏一个即失效或失去沉浸）**：

```ts
Navigation() {
  this.HomeFeedContent()
}
.title({ builder: this.HomeTitleBar(), height: 108 },
  { barStyle: BarStyle.STACK, backgroundColor: Color.Transparent })   // ★ 两处都不许漏
.mode(NavigationMode.Stack)          // 强制单栏，宽屏不拆双栏
.hideTitleBar(false)                 // title 槽位要显示（不设 title/subTitle 时标题栏整体不显示）
.hideBackButton(true)
.backgroundColor(Color.Transparent)
.clip(false)                         // 不裁内容：滚动内容要能从标题栏下穿过
.expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
```

**三条硬约束**：
① `barStyle: BarStyle.STACK` 是沉浸的前提（官方原文：延伸至非安全区的前提是「标题栏/工具栏隐藏或置为 STACK」），漏了内容就不再延伸到标题栏下；
② `title` options 的 `backgroundColor: Color.Transparent` **必须显式写**，否则标题栏自带底色会压住从下方穿过的内容；
③ 槽内子元素**不许再挂** `backgroundColor` / `border` / `backgroundBlurStyle` / `shadow`（材质自带背景 / 边框 / 阴影，同 §4 口径），只留几何与文字/图标色。

**低版本行为**：API 23~25 上只是**没有玻璃**（`systemMaterial` 被忽略），`Navigation` 结构照常渲染、几何不变 —— 与「走 `backgroundBlurStyle` 的兜底路径」**不等价**（后者低版本仍有磨砂）。
（2026-09-10 加固：低版本上槽内 `ImmMaterial.*` 经 `createMaterial()` 返回 `undefined`（官方语义＝无材质），不去构造低版本不存在的 `uiMaterial` 实例，门限见 §14.3。）

**判据更新（重要）**：**「页面主体一律无解」不再成立**。现行为 **① 顶部吸顶行 → 搬进 `title` 槽位吃官方材质；② 页面中部玻璃 / 搬不进去 → 真模糊兜底**。

**工程侧完整记录**：`docs/新API26沉浸光感经验汇总.md` §1.5（判据）、§6.10（模板 + 几何对齐表 + 回归清单）、§9.3（待迁移页面清单）；工程指南模板 `docs/immersive-material-guide.md` §6.7。

---

## 15. 参考链接

**官方文档（加 `.md` 可直出正文）**
- 沉浸光感总览：`https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-immersive-light-sense`
- 简介：`.../arkts-immersive-light-sense-overview`
- 开启沉浸光感：`.../arkts-immersive-light-sense-enable`
- 组件适配沉浸光感：`.../arkts-immersive-light-sense-component-adaptation`
- 沉浸式系统材质视效：`.../arkts-immersive-light-sense-common-capability`
- 沉浸光感功耗优化：`.../arkts-immersive-light-sense-constraints`
- 沉浸光感常见问题：`.../arkts-immersive-light-sense-faq`
- 沉浸光感典型场景：`.../arkts-immersive-light-sample`
- ⚠️ 沉浸光感兼容性适配：`.../arkts-immersive-light-sense-compatibility`（2026-09-10 抓取 404）

**API 参考**
- `@ohos.arkui.uiMaterial`：`https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-uimaterial`

**本机 SDK 权威声明（可直接查证）**
- `sdk/default/openharmony/ets/api/@ohos.arkui.uiMaterial.d.ts`（全文 460 行）
- `sdk/default/openharmony/ets/component/common.d.ts`（`SystemUiMaterial` @17831、`systemMaterial` 方法 @23521）
- `sdk/default/openharmony/ets/component/tabs.d.ts`（`FloatingTabBarStyle` @824、`barFloatingStyle` @1683）
- `sdk/default/openharmony/ets/component/navigation.d.ts`（`systemMaterial` @1891、`scrollEffectOptions` @1879）
- `sdk/default/openharmony/ets/api/@ohos.promptAction.d.ts`（Toast/Dialog `systemMaterial`）
- `sdk/default/openharmony/ets/api/@ohos.arkui.advanced.{Chip,ChipV2,ChipGroup,ChipGroupV2,SegmentButton,SegmentButtonV2,SelectionMenu}.d.ets`
- `sdk/default/openharmony/native/sysroot/usr/include/arkui/native_material.h`（原生 C API）
- `sdk/default/hms/ets/api/@hms.hds.hdsMaterial.d.ets`（HDS 侧 `hdsMaterial`，`@since 6.1.0(23)`）

**工程内关联文档**
- `docs/immersive-material-guide.md`：工程实现指南（怎么用、历史坑、备选真模糊方案）
- 本文：官方能力底稿（平台到底给什么、边界在哪）
