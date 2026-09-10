# 沉浸光感（系统材质毛玻璃）实现指南 — TiebaPura

> **适用工程**：TiebaPura（HarmonyOS 7 / API 26，ArkTS / ArkUI 原生 + `@kit.ArkUI` 的 `uiMaterial`）
> **文档版本**：v1.3（2026-09-10）
> **用途**：整套沉浸光感的原理、代码结构、调用模板与迁移步骤；**顶部吸顶行 → 官方槽位模板见 §6.7**；另含**备选方案「真模糊磨砂」**（§6.1 页面中部玻璃 / 顶部行的回退路径、§6.6 弹窗）——沉浸光感实在无法实现 / 用户明确要求真模糊时的降级路径，**使用前必须询问用户**。后续给新页面 / 新工程复刻玻璃效果时照本操作即可。

---

## 1. 这套机制在解决什么

| 现象 | 原因 | 解法 |
|---|---|---|
| `systemMaterial(...)` 在真机不渲染，日志刷 `Material inactive: out of scope. Use component in navigation title bar or Tabbar.` | 官方沉浸材质**只在其认可的范围内生效**：Navigation 标题栏 / Tabs 的 `tabBar` 槽位；页面 body 里普通叠放的组件一律判"范围外" | 底栏用**真实 Tabs 的 `.tabBar()` 槽位**承载；范围外元素保留「手动玻璃兜底色」，材质生效即盖过兜底 |
| 材质 + 自绘模糊/阴影同时存在 | 双模糊叠成糊、双影叠成黑边 | 材质自带 `applyShadow`，故项目内 `ImmBlur.*` 全部返回**空效果**、`Theme.glassShadowStyle()` 返回**全零阴影** |
| 低版本 / 非官方系统不支持材质 | `uiMaterial.ImmersiveMaterial`（连同通用属性 `systemMaterial`、`barFloatingStyle`）都是 **ArkUI `@since 26.0.0`**；渲染需 HOS 真机（模拟器不渲染） | 启动时能力检测 `sdkApiVersion >= 26` + `uiMaterial` 命名空间探测；不支持时 `createMaterial()` 返回 `undefined`（官方语义＝无材质），各调用点零改动、宿主按能力分路径渲染 |

> 补充事实（真机定案）：
> - **模拟器不渲染系统材质**，抓包/调材质只能在真机上看，判断标准为 hilog 是否有 `Material inactive: out of scope`。
> - 项目 `module.json5` 已声明 `ohos.arkui.UIMaterial.state = enable`（见 §3），这是材质接口可用的前置条件。

---

## 2. 架构总览

沉浸光感分三层，全部集中在少量文件里：

| 层 | 文件 | 职责 |
|---|---|---|
| 能力检测 | `entry/src/main/ets/common/Theme.ets`（§4.1） | `MaterialManager`：启动时探测 `sdkApiVersion`，缓存结果 |
| 材质预设 | 同文件（§4.2 / §4.3） | `ImmMaterial.*`：11 档单例 `uiMaterial.ImmersiveMaterial` 预设；`ImmBlur.*` 空效果防双模糊 |
| 兜底色板 | 同文件（§4.4） | `Theme.manualGlass / manualGlassBorder / glassShadowStyle`：材质范围外/失效时的手动玻璃视觉；`segGlass / segGlassShadow`：备选真模糊路径专用（§6.1） |
| 宿主双路径 | `entry/src/main/ets/pages/Index.ets`（§5） | API26+ 走**原生 Tabs 悬浮槽位**；低版本走**手写叠放 + 手写玻璃底栏** |
| 页面调用模板 | 各页面 / `components/CommonComponents.ets`（§6） | 先按 §6 决策：材质生效范围内用「兜底色 + 描边 + 空阴影/空效果 + `systemMaterial`」四段式；**沉浸光感无法实现**的点位经询问后走 §6.1 备选（`backgroundBlurStyle` 真模糊磨砂） |

要点：**渲染顺序**为 `backgroundColor(manualGlass) → systemMaterial(材质) → border(描边) → 内容`。材质有效时完全盖住兜底色；材质失效/范围外时兜底色直接可见。因此所有玻璃点位都**同时保留两层**，一套代码两个系统通吃。

---

## 3. 前置配置（抄到新工程时必做）

### 3.1 `entry/src/main/module.json5`

`abilities[]` 之前需声明（ArkUI 侧启用 UI Material 能力）：

```json5
"metadata": [{
  "name": "ohos.arkui.UIMaterial.state",
  "value": "enable"
}],
```

### 3.2 沉浸窗口（`entryability/EntryAbility.ets`）

`loadContent` 后设置全屏 + 透明系统栏，让内容铺满、玻璃效果透出状态栏：

```ts
await mainWindow.setWindowLayoutFullScreen(true);
await mainWindow.setWindowSystemBarProperties({
  statusBarColor: '#00000000',
  navigationBarColor: '#00000000',
  statusBarContentColor: '#1A1A1A',      // 亮色主题
  navigationBarContentColor: '#1A1A1A',
});
```

### 3.3 页面根部

页面/宿主根 Stack 需向系统安全区扩展，玻璃底栏才会延伸到导航条区域之下：

```ts
.expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
```

---

## 4. `Theme.ets` — 材质中枢

文件：`entry/src/main/ets/common/Theme.ets`。新工程可直接整文件搬运，依赖仅 `@kit.ArkUI`（`uiMaterial`）与 `@kit.BasicServicesKit`（`deviceInfo`）。

### 4.1 能力检测

```ts
export function initMaterialSupport(): void   // 启动调一次；内部用 _materialInitialized 缓存
export function isMaterialSupported(): boolean // sdkApiVersion >= 26 且 uiMaterial 命名空间可构造（2026-09-10 收紧）

export class MaterialManager {
  static init(): void
  static isSupported(): boolean
  static getApiLevel(): number
}
```

调用点：宿主 `Index.aboutToAppear` 及各页面 `aboutToAppear`（幂等，重复调用无副作用）。

### 4.2 `ImmMaterial` — 材质预设速查表

全部为模块级**单例缓存**（`ensureXxx()` 惰性创建），跨组件复用同一 `Material` 实例。

| 方法 | `style` | `interactive` | 备注 / 用途 |
|---|---|---|---|
| `control()` | ULTRA_THIN | true | 顶栏 44×44 圆形控制钮（返回/搜索/更多） |
| `bar()` | ULTRA_THIN | false | 容器栏；`colorInvert: true`（底色反相适配亮/暗） |
| `floatingBar()` | THIN | false | **悬浮玻璃胶囊专用**：原生 `barFloatingStyle` 的 `systemMaterial` |
| `tab()` | REGULAR | true | 胶囊分段 Tab（未选中） |
| `tabActive(isDark)` | REGULAR | true | 选中 Tab：深色 `#553173FF` / 亮色 `#383173FF` 品牌赋色 |
| `cardAction()` | THIN | true | 卡片内操作钮 |
| `fab()` | THICK | true | FAB 悬浮操作钮，最强模糊 |
| `accent(isDark)` | THIN | true | 品牌主按钮：深色 `#663173FF` / 亮色 `#4C3173FF` |
| `bottomGlow(isDark)` | THICK | false | 底栏选中项高光：`#553173FF` / `#383173FF` |
| `rowItem()` | REGULAR | true | 列表条目钮 |

创建参数模板（以 `bar` 为例）：

```ts
new uiMaterial.ImmersiveMaterial({
  style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
  interactive: false,
  lightEffect: { color: undefined },   // 不额外上色，保留玻璃本色
  applyShadow: true,                    // 官方阴影，避免再叠 .shadow
  colorInvert: true,                    // 仅 bar/floatingBar 用
});
```

### 4.3 `ImmBlur` / `Theme.glassShadowStyle` — 防叠影双件套

```ts
ImmBlur.control() / bar() / tab() / tabActive() / cardAction() / accent() / fab() / rowItem() / bottomGlow()
// 全部返回 { radius: 0, color: '#00000000' }（空背景效果）
```

```ts
Theme.glassShadowStyle(): GlassShadowOptions  // 恒返回全零阴影 { radius: 0, color: '#00000000' }
```

> 与 `ImmMaterial` 同名一一对应。所有调用点固定写法 `.shadow(Theme.glassShadowStyle()).backgroundEffect(ImmBlur.X())`，玻璃模糊与阴影**全部交给材质本身**（`applyShadow`），杜绝双模糊/双影。

### 4.4 `Theme` 手动玻璃兜底（范围外元素的生命线）

| 成员 | 返回值 | 说明 |
|---|---|---|
| `GLASS_FALLBACK_ENABLED` | `true` | 总开关；若某日材质在所有设备稳定渲染可置 `false`，所有兜底色/描边变全透明 |
| `manualGlass(isDark, active?)` | 普通：亮 `#E6F0F4F8` / 深 `#3DFFFFFF`；active：亮 `#803173FF` / 深 `#993173FF` | 半透明玻璃底 |
| `bottomSegGlass(isDark, active)` | alpha 压到 ~5-15% | 底部悬浮排序胶囊专用：内容从胶囊后滑过仍能透出 |
| `manualGlassBorder()` | `#22FFFFFF` | 0.5vp 白描边，增强玻璃边缘 |
| `glassShadowStyle()` | 全零（见 §4.3） | — |
| `segGlass(isDark, active)` / `segGlassShadow(isDark, active)` | 亮色底色全透明 / 中性两档浮起影（详见 §6.1） | **吸顶分段钮/圆钮共用**：HomeTab 顶栏胶囊与搜索圆钮、ThreadList 贴吧排序段（热门/最新/精选）与签到胶囊。真模糊磨砂备选路径的底色 + 阴影，勿与材质路径的全零阴影混用 |
| `sheetGlass(isDark)` | 亮 `#00000000`（全透明）/ 深 `#2E1A1A1E`（18%） | **弹窗/浮层真模糊专用**（§6.6，2026-09-07 ForumsTab 三弹窗在用）。与 `segGlass` 同思路不留白夹层，让 Regular blur 自带 tint 主导、背后内容透出轮廓；配 0.5vp 白描边 + **真实浮起阴影**，勿配 `glassShadowStyle` 全零阴影 |

另注意：弹窗卡片现有两套方案——默认走纯色 `Theme.sheetBg`（高不透明白/墨蓝 + 顶部高光边 + 双层阴影，不叠材质，避免"暗蒙层 + 磨砂 + 模糊"叠加泛白）；**2026-09-07 起用户要求弹窗真模糊时**（ForumsTab 长按菜单/排序下拉/删除确认三弹窗定案）改走 `sheetGlass` + `backgroundBlurStyle` 真模糊（§6.6），两套不要混叠。

---

## 5. `Index.ets` — 底栏「Tabs 槽位」双路径（核心）

文件：`entry/src/main/ets/pages/Index.ets`。要点：**真机材质只在 Navigation 标题栏 / Tabs `tabBar` 槽位渲染**，所以底栏必须挂到真实 `Tabs` 上；同时把 5 个 Tab 页面保持为项目原有的手写叠层（保留滑入动画/懒挂载/常驻状态），Tabs 本身只有一个 `TabContent`，**只借槽位、不参与切换**（选中态由手写 `@State selectedTab` + `switchTab()` 驱动）。

### 5.1 build 分路径

```ts
build() {
  Stack({ alignContent: Alignment.Bottom }) {
    if (this.materialSupported && MaterialManager.getApiLevel() >= 26) {
      this.FloatingTabsShell()          // API26+：材质能进 Tabs tabBar 槽位的悬浮路径
    } else {
      this.PagesStack()                 // 低版本：原手写叠放
      if (!this.favEditing) {
        this.BottomBar()                //  + 手写玻璃底栏（manualGlass 视觉）
      }
    }
  }
  .width('100%').height('100%')
  .backgroundColor(Theme.bg(this.isDark))
  .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
}
```

### 5.2 API26+ 悬浮路径 `FloatingTabsShell`

```ts
@Builder
FloatingTabsShell() {
  Tabs({ barPosition: BarPosition.End }) {
    TabContent() {
      this.PagesStack()                 // 五 Tab 手写叠层整体作为唯一内容
    }
    .tabBar(this.FloatingBarSlot())     // 底栏胶囊挂进真实 TabBar 槽位（材质生效关键）
  }
  .vertical(false)
  .scrollable(false)                    // 不做原生左右滑切页（切换由手写 switchTab 管）
  .barOverlap(true)                     // 栏悬浮叠在内容上（@since 10）
  .barHeight(74)
  .barBackgroundColor(Color.Transparent)
  .barFloatingStyle({                   // 悬浮胶囊样式（@since 26，compileSdk=26 可用）
    barWidth: {
      smallBarWidth: this.pillWidth(),
      mediumBarWidth: this.pillWidth(),
      largeBarWidth: this.pillWidth()
    },
    barBottomMargin: 30,
    systemMaterial: ImmMaterial.floatingBar()   // 真玻璃：胶囊材质
  })
  .backgroundColor(Color.Transparent)
  .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  .clip(false)
}
```

胶囊几何（与手写定稿完全一致）：

```ts
private pillWidth(): number {
  if (this.isWideScreen) return 480;                 // 宽屏(≥840vp)定宽
  const w: number = this.currentWidth - 48;          // 窄屏 = 屏宽 - 48vp
  return w > 240 ? w : 240;                          // 下限 240vp 防极端
}
// 底栏: 胶囊高度由 barHeight 74 承担；barBottomMargin: 30；宽度 = pillWidth()
```

### 5.3 `FloatingBarSlot`（tabBar 槽位内容）

```ts
@Builder
FloatingBarSlot() {
  if (!this.favEditing) {
    Stack() {
      Row() { /* BottomGlow 选中高光占位列：与图标行同权重等分，保持胶囊内等分布局 */ }
        .padding({ left:8, right:8, top:6, bottom:6 })
      Row() {                                         // 图标 + 文字行
        this.BottomItem('⌂','首页',TabIndex.Home)     // 5 个 BottomItem，layoutWeight(1) 等分
        ...
      }.padding({ left:8, right:8, top:6, bottom:6 })
    }.width('100%').height('100%')                    // 玻璃由 Tabs barFloatingStyle.systemMaterial 提供
  }
}
```

单个 `BottomItem`（`SymbolGlyph` 系统符号 + 文字；选中 1.05 放大 + 加粗 + `sys.color` 强调色）：

```ts
@Builder
BottomItem(icon: string, label: string, index: number) {
  Column({ space: 3 }) {
    SymbolGlyph(this.symbolFor(index))
      .fontSize(fs(22, this.fontScale))
      .fontWeight(this.selectedTab === index ? FontWeight.Bold : FontWeight.Medium)
      .fontColor([this.selectedTab === index ? $r('sys.color.icon_emphasize') : $r('sys.color.icon_primary')])
      .renderingStrategy(SymbolRenderingStrategy.SINGLE)
    Text(label).fontSize(fs(11, this.fontScale))
      .fontWeight(this.selectedTab === index ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(this.selectedTab === index ? $r('sys.color.font_emphasize') : $r('sys.color.font_primary'))
  }
  .layoutWeight(1).height(58)
  .borderRadius(29)
  .scale({ x: this.selectedTab === index ? 1.05 : 1, y: this.selectedTab === index ? 1.05 : 1 })
  .animation({ duration: 360, curve: curves.springMotion(0.72, 0.86) })
  .onClick(() => { this.switchTab(index); })
}
```

符号映射走系统 symbol：`house_fill / grid / star / envelope / person`（`sys.symbol.*`）。

### 5.4 低版本兜底 `BottomBar`

结构同 `FloatingBarSlot` 的图标行，区别是**材质自己挂**、颜色走 `manualGlass`，且宽度公式与手写定稿一致：

```ts
.width(this.isWideScreen ? 480 : 'calc(100% - 48vp)')
.height(74)
.backgroundColor(MaterialManager.isSupported() ? Color.Transparent : Theme.manualGlass(this.isDark))
.border({ width: 0.5, color: Theme.manualGlassBorder() })
.shadow(Theme.glassShadowStyle()).backgroundEffect(ImmBlur.bar())
.systemMaterial(ImmMaterial.bar())      // 低版本即使不渲染也无害
.borderRadius(37)
.margin({ bottom: 30 })
.zIndex(20)
```

### 5.5 切换逻辑提醒

`Tabs` 不参与切换：`selectedTab` 由手写 `switchTab(index)` 驱动（方向感知滑入动画，320ms springMotion；重按当前首页 tab 会发 `homeRetapRequest` 整页刷新）。改结构时**不要**把选中态交给 Tabs 原生 `index`，否则 5 页手写叠层与动画逻辑会脱节。

---

## 6. 页面玻璃点位调用模板

页面主体里的玻璃元素按「沉浸光感能否实现」分路，先决策再动手：

| 情形 | 处理 |
|---|---|
| **顶部吸顶行**（分段胶囊 / 圆钮 / 标题），且该页 `build()` 根能容纳一层 `Navigation` | **首选 §6.7 官方槽位模板**：整行搬进 `Navigation` 的 `title` 槽位，槽内子元素各自挂 `systemMaterial`（2026-09-10 首页顶栏已按此改造，**真机已验生效**） |
| 元素能落到 Navigation 标题栏 / Tabs `tabBar` 槽位，材质可渲染 | §6.2~6.4 官方材质四段式（兜底色 + 描边 + 空阴影/空效果 + `systemMaterial`） |
| **沉浸光感实在无法实现**（**非顶部**的页面 body 玻璃，如页面中部吸顶段/浮层；或暂不加 `Navigation` 壳的顶部行），但仍需「模糊穿透内容」的玻璃视觉 | §6.1 **备选方案：`backgroundBlurStyle` 真模糊磨砂**。**用前必须询问用户**，说明这是降级路径，不得直接默认启用 |
| 弹窗/浮层卡片 | 默认 §6.5 `sheetBg` 纯色；**用户主动要求弹窗真模糊磨砂** → §6.6 `sheetGlass` 真模糊模板（2026-09-07 已与用户定案，可直接复用，无需再问） |
| 只求简单兜底观感、不需真模糊 | §4.4 `manualGlass` 系列 |

### 6.1 备选方案：`backgroundBlurStyle` 真模糊磨砂（**2026-09-10 适用范围已收窄**：现用于 ThreadList 排序段/签到胶囊、页面中部玻璃，以及首页顶栏的**回退路径**）

> **2026-09-10 重要更新（读本节前必看）**：**首页顶栏「推荐 / 关注动态」胶囊 + 搜索圆钮已整行搬进 `Navigation` 的 `title` 槽位，改吃官方材质**（模板见 §6.7，真机已验生效）。
> 因此本节从「首页顶栏的解法」降级为：**① 顶部行的降级 / 回退路径**（`HomeTab.HOME_OFFICIAL_TITLE_BAR = false` 时回到本写法，旧 builder 原样保留）；**② 页面中部玻璃**（搬不进 `title` 槽位的位置）**仍必须用本方案**。
> **判据更新：顶部吸顶行 → 先考虑 §6.7 官方槽位；搬不进去或要回退 → 才用本方案。**
>
> **为什么走备选**：本节写法服务于「悬浮在页面 body 顶层叠放、不属于 Navigation 标题栏 / Tabs `tabBar` 槽位」的玻璃元素——例如贴吧页「热门 / 最新 / 精选」吸顶排序段与签到胶囊（ThreadList `SortTabsBuilder` / 吧头）、以及页面中部的吸顶段。按本项目实测，`systemMaterial` 在此类页面主体叠层点位**渲染不稳定 / 判 `out of scope`**（API 26 前明确范围外，见 §1；API 26 新体系的覆盖关系见 §10），无法稳定获得沉浸光感；而顶部又要透出从下方滑过的帖子内容，纯 `manualGlass` 半透明底不够。**2026-09-05 与用户确认后定案**：上述元素走下方真模糊磨砂写法。
>
> **用前必问（流程规则）**：本方案属备选。凡新建点位要接入、或对既有吸顶玻璃点位的处理方式有分歧时，**先向用户询问确认**，说明「沉浸光感在此位不可实现 / 备选方案为准」，用户同意后再动手。不要未询问就套用本模板。

当前代码（`HomeTab.ets` `HomeHeaderOverlay`，推荐 / 关注 / 搜索三元素同构；**该 builder 现已作为"官方槽位关掉时的回退路径"保留**，官方槽位版是 `HomeTitleBar()`，见 §6.7）：

```ts
Text('推荐')
  .fontColor(active ? $r('sys.color.font_emphasize') : $r('sys.color.font_primary'))  // 状态靠系统强调色文字
  .fontWeight(active ? FontWeight.Bold : FontWeight.Medium)
  .backgroundColor(Theme.segGlass(this.isDark, active))          // 底色（亮色全透明，见下「坑1」）
  .border({ width: 0.5, color: Theme.manualGlassBorder() })       // 0.5vp 白描边保玻璃边缘
  .backgroundBlurStyle(active ? BlurStyle.Regular : BlurStyle.Thin,  // 真模糊本体（分档）
    { scale: active ? 0.8 : 0.85 })                               // scale：磨砂厚度微调
  .shadow(Theme.segGlassShadow(this.isDark, active))             // 中性浮起阴影（两档随选中态）
  .borderRadius(Radius.full)
  .padding({ left: 22, right: 22, top: 9, bottom: 9 })
```

同构点位（完全同一套令牌，仅字号/布局按各自页面）：
- **ThreadList 吧内排序段**（`SortTabsBuilder`，热门 / 最新 / 精选）：三枚 `Button` `layoutWeight(1)` 等分、`fontSize(fs(12, scale))`；选中态颜色呈现**与首页顶栏胶囊完全一致**——无色底（`segGlass` 亮色两态全透明）、系统强调色文字 + 加粗，未选中 `font_secondary` + Medium：

```ts
Button('热门')
  .fontSize(fs(12, this.fontScale))
  .fontColor(this.selectedSort === 0 ? $r('sys.color.font_emphasize') : $r('sys.color.font_secondary'))
  .fontWeight(this.selectedSort === 0 ? FontWeight.Bold : FontWeight.Medium)
  .backgroundColor(Theme.segGlass(this.isDark, this.selectedSort === 0))
  .border({ width: 0.5, color: Theme.manualGlassBorder() })
  .backgroundBlurStyle(this.selectedSort === 0 ? BlurStyle.Regular : BlurStyle.Thin,
    { scale: this.selectedSort === 0 ? 0.8 : 0.85 })
  .shadow(Theme.segGlassShadow(this.isDark, this.selectedSort === 0))
  .borderRadius(Radius.full)
  .layoutWeight(1)
```

- **ThreadList 吧头右上角签到胶囊**（`已签N天` / `未签到`）：同套薄磨砂单档（`segGlass(isDark,false)` + `BlurStyle.Thin { scale: 0.85 }` + `segGlassShadow(isDark,false)`），文字恒为 `sys.color.font_secondary`，无选中态切换。

`Theme.ets` 配套令牌（仅本备选路径使用，勿与材质路径的 `manualGlass` / `glassShadowStyle` 混用）：

| 令牌 | 取值 / 说明 |
|---|---|
| `segGlass(isDark, active)` | 亮色两态均 `#00000000`（不留实白底）；深色淡黑 `#4D1A1A1E`（选）/ `#2E1A1A1E`（否） |
| `segGlassShadow(isDark, active)` | 中性黑影：选中 radius 12 / offsetY 3（亮 `#3D000000`、暗 `#66000000`）；未选中 radius 10 / offsetY 2（亮 `#26000000`、暗 `#40000000`） |

本轮经验（真机定案，2026-09-05）：

1. **真模糊本体是 `backgroundBlurStyle`，底色只是叠色调**：`segGlass` 的 alpha 必须低到不遮蔽模糊，否则模糊白做了。
2. **高不透明度白底 = 「实白夹层」吞掉磨砂**：曾给亮色选中态 `#A6FFFFFF`（65% 白），真模糊几乎被整块实白盖住，只剩元素边缘外露一点模糊 → **亮色底色直接归零**，层次交给「模糊 + 描边 + 阴影」。
3. **选中态区分不靠底色**：靠系统强调色文字（`font_emphasize`）+ 字重 Bold + 阴影加重一档；去底色后选中依旧清晰（注意：未选中钮底色也别给高 alpha，否则状态对比失真）。
4. **阴影不能照抄材质路径的全零写法**：材质靠 `applyShadow` 自带投影，本方案**没有材质**，必须给真实 `.shadow` 才有浮起层次（曾删掉阴影后视觉压平、被要求补回）。
5. **阴影用中性色、勿染品牌蓝**：彩影叠浅背景显脏；层次靠「radius + offsetY + alpha」两档拉开即可。
6. **`scale` 可微调磨砂厚度**：当前选中 Regular/0.8、未选中 Thin/0.85，透明度想再透就把 scale 调大或换 ULTRA_THIN。

### 6.2 44×44 圆形控制钮（返回/更多等材质生效位）

```ts
Button() { SymbolGlyph(...) }
  .width(44).height(44)
  .backgroundColor(Theme.manualGlass(this.isDark))             // 兜底
  .border({ width: 0.5, color: Theme.manualGlassBorder() })
  .shadow(Theme.glassShadowStyle()).backgroundEffect(ImmBlur.control())
  .systemMaterial(ImmMaterial.control())
  .borderRadius(Radius.full)
```

### 6.3 卡片操作钮（`components/CommonComponents.ets`）

accent（品牌主按钮）与 cardAction 同构：

```ts
.shadow(Theme.glassShadowStyle()).backgroundEffect(ImmBlur.accent())
.systemMaterial(ImmMaterial.accent(isDarkMode()))
```

### 6.4 顶栏条 / 容器

见 `UserProfile.ets` 中顶栏 `.systemMaterial(ImmMaterial.bar())`；若该页面整体包在 Navigation 下，材质即在生效范围。

### 6.5 弹窗/底部卡

默认走纯色方案：`Theme.sheetBg(isDark)` + `sheetTopGlow` + 双层阴影（见 §4.4 尾注），避免"暗蒙层 + 磨砂 + 模糊"叠加泛白；**若用户明确要求弹窗呈现真模糊磨砂**（2026-09-07 ForumsTab 三弹窗定案），改用 §6.6 的 `sheetGlass` 真模糊模板——同样不叠材质（弹窗浮层在页面主体顶层叠放，`systemMaterial` 不在渲染范围，见 §1）。

### 6.6 弹窗/浮层真模糊磨砂（`sheetGlass`，ForumsTab 三弹窗在用）

> **背景**：2026-09-07 用户要求把弹窗（关注吧长按菜单 `ForumMenuDialog` / 排序下拉 `ForumSortDialog` / 足迹删除确认 `RecentDeleteDialog`）从实底白卡改成能透出背后内容的真模糊磨砂。弹窗浮层与 §6.1 吸顶胶囊同属页面主体顶层叠放，`systemMaterial` 不渲染，故复用 `backgroundBlurStyle` 真模糊路径；但弹窗是大面积静态卡片，直接套 §6.1 胶囊令牌不合适，新增弹窗专用令牌 `Theme.sheetGlass`。

模板（关注吧长按菜单为例；排序下拉为 `Radius.lg` 圆角 + 轻影 `radius 24 / offsetY 8`，删除确认卡同构）：

```ts
.backgroundColor(Theme.sheetGlass(this.isDark))              // 底色：见下「不铺白夹层」经验
.borderRadius(32)
.border({ width: 0.5, color: Theme.manualGlassBorder() })     // 0.5vp 白描边保玻璃边缘
.backgroundBlurStyle(BlurStyle.Regular, { scale: 0.85 })      // 真模糊本体：Regular + scale 0.85
.shadow({ radius: 48, color: '#3D000000', offsetY: 18 })      // 真实浮起阴影（菜单/删除卡；原浮起层次保留）
```

> 不要沿用的旧写法：材质路径的 `Theme.glassShadowStyle()` 全零阴影与 `backgroundEffect`/`systemMaterial`（本路径无材质自带投影，删掉真实阴影会压平，见 §6.1 坑4）；弹窗原 `sheetBg` 方案的顶部高光边 `sheetTopGlow` 也不再需要，统一改 0.5vp 全描边。

本轮经验（真机定案，2026-09-07）：

1. **弹窗"看起来还是纯白底"的根因是「白夹层」，不是 blur 没开**：先后试 80% 白（`Theme.glass`）与 48% 白（`sheetGlass` 前身）都无效——`BlurStyle.Regular` 亮色自带白色 tint，任何高不透明度白底叠在 blur 上都会把模糊结果和背后透出内容整个盖掉，观感退回纯白实底，与改造前无差别。这是 §6.1 坑2 的复刻，且弹窗面积大、整块自涂白，表现更彻底。
2. **弹窗真模糊的正确配方 = 不铺自涂白底**：亮色底色归零（`#00000000`），层次交给「Regular blur 自带 tint + 背后内容轮廓 + 0.5 描边 + 真实浮起阴影」；深色只需 ~18% 墨暗底（`#2E1A1A1E`）承托白字可读性（同 `segGlass` 未选中档）。
3. **磨砂"看不看得见"取决于背后内容的信息量**：弹窗背后若恰好是大片纯白卡片区，模糊后仍偏白属预期；应把弹窗对准有头像色块 / 图片 / 彩色内容的区域验证透出轮廓。
4. **scale 可微调**：当前 Regular + `{ scale: 0.85 }`；想更透/更雾就加大 scale 或换 `BlurStyle.Thin`。

---

### 6.7 ★ 顶部吸顶行 → `Navigation` 的 `title` 槽位（官方材质，2026-09-10 首页顶栏已落地）

> **适用**：页面**顶部**的吸顶行（分段胶囊 / 44 圆钮 / 标题），且该页 `build()` 根能容纳一层 `Navigation` 壳。
> **收益**：槽内子元素挂 `systemMaterial` **会真正渲染**（官方 B 档「其他组件仅在 Navigation/NavDestination 标题栏生效」字面命中）——**真机已验，不再是降级路径**。
> **完整记录**（几何对齐表、`ImmMaterial.seg()` 中性档、回归清单）见 `docs/新API26沉浸光感经验汇总.md` §6.10；官方依据见 `docs/immersive-light-sense-api26-official.md` §14.6。此处只给可抄模板。

```ts
// 开关式落地：false → 回到 §6.1 真模糊的页面主体悬浮层（一键回退，旧 builder 保留）
const HOME_OFFICIAL_TITLE_BAR: boolean = true;
const HOME_TITLE_BAR_HEIGHT: number = 108;   // top44 + 行高44 + bottom20

Navigation() {
  this.HomeFeedContent()          // 内容层（原 build 根 Stack）
}
.title({ builder: this.HomeTitleBar(), height: HOME_TITLE_BAR_HEIGHT },
  { barStyle: BarStyle.STACK, backgroundColor: Color.Transparent })   // ★ 两处都不许漏
.mode(NavigationMode.Stack).hideTitleBar(false).hideBackButton(true)
.width('100%').height('100%').backgroundColor(Color.Transparent)
.clip(false)                      // 允许滚动内容从标题栏下穿过
.expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

// 槽内子元素：几何 / 字号 / padding 全部照旧，只把玻璃换成材质
Text('推荐')
  .fontColor(active ? $r('sys.color.font_emphasize') : $r('sys.color.font_primary'))
  .fontWeight(active ? FontWeight.Bold : FontWeight.Medium)
  .systemMaterial(ImmMaterial.seg(active))     // 选中 REGULAR / 未选中 THIN（中性档，不染色）
  .borderRadius(Radius.full)
  .padding({ left: 22, right: 22, top: 9, bottom: 9 })
// ⚠️ 槽内不要再挂 backgroundColor / border / backgroundBlurStyle / shadow —— 材质自带，叠了会互相覆盖
```

**四条必记**：

1. `barStyle: BarStyle.STACK` **必设** —— 不设内容就不再延伸到标题栏下，**直接失去沉浸**；`title` options 的 `backgroundColor: Color.Transparent` 同理必写（否则标题栏底色压住穿过的内容）。
2. 槽内元素**删掉** `backgroundColor / border / backgroundBlurStyle / shadow` 四项，只留几何 + 文字/图标色（文字用系统可反色资源，天然满足官方「文字可反色」前提）。
3. 选中态要「只换玻璃、观感不变」→ 用**中性档**（本项目 `ImmMaterial.seg(active)`：REGULAR / THIN，无 `materialColor` + `interactive`）。**别用 `tabActive()`** —— 它自带品牌蓝赋色，会改掉「去蓝底、状态靠文字强调色 + 字重」的定稿。
4. 新增一层 `Navigation` 会参与**手势分发与返回键**：页面内 `parallelGesture` / 横滑切页 / 返回链都要回归；二级页（已带导航语义）加壳前先确认不与宿主 `Index.ets` 的返回逻辑打架。

**低版本（API 23~25）**：只是**没有玻璃**（`systemMaterial` 被忽略），`Navigation` 结构照常、几何不变 —— 与 §6.1 兜底路径**不等价**（后者低版本仍有磨砂）。

**待迁移清单**（同属顶部吸顶行）：ThreadList 排序段 + 签到胶囊、Favorite 三种形态 TopBar、ForumsTab / UserProfile / FollowList / BlacklistManager TopBar、ThreadDetail 沉浸顶栏；Search 页含 `TextInput`，聚焦与键盘避让需单独评估。详见 `docs/新API26沉浸光感经验汇总.md` §9.3。

---

## 7. 新工程 / 新页面落地 Checklist

1. **拷文件**：`common/Theme.ets`（含 `ImmMaterial / ImmBlur / MaterialManager / Theme` 全部）→ 工程 `common/`。
2. **配元数据**：`module.json5` 加 `ohos.arkui.UIMaterial.state: enable`。
3. **沉浸窗口**：`EntryAbility` 设全屏 + 透明系统栏（§3.2）。
4. **初始化**：宿主 `aboutToAppear` 里 `MaterialManager.init()`，并把 `materialSupported` 存入状态供分路径。
5. **玻璃底栏**（要"真玻璃"）：
   - 页面内容放 `Tabs`（单 `TabContent`）+ `.tabBar(自定义底栏 Builder)`；
   - `barOverlap(true)` + `barHeight(74)` + `barBackgroundColor(Transparent)` + `barFloatingStyle({ systemMaterial: ImmMaterial.floatingBar(), ... })`；
   - 内容根部 `.expandSafeArea(SYSTEM, TOP|BOTTOM)` + `.clip(false)`；
   - 低版本分支保留手写 `BottomBar` 兜底。
6. **页面玻璃元素**：先按 §6 决策表分流——**顶部吸顶行优先 §6.7 官方 `title` 槽位**（能搬就搬，材质真渲染）；**搬不进槽位的页面中部玻璃 / 要回退的顶部行** → 走 §6.1 `backgroundBlurStyle` 备选，**接入前必须询问用户**；材质生效范围内用四段式模板（§6.2~6.4），`backgroundColor(manualGlass)` 那行**不要删**（范围外/低版本的生命线）；**用户要求弹窗真模糊** → 直接复用 §6.6 `sheetGlass` 模板（已定案）。
7. **深色模式**：色板 `manualGlass` 两套；页面 `@StorageLink('darkTick')` 触发时 `this.isDark = isDarkMode()` 后刷新；文字用 `$r('sys.color.*')` 或 `Theme.*(isDark)`。
8. **真机验收**：hilog 不应再出现 `Material inactive: out of scope`；截屏确认模糊与高光。模拟器无材质属正常，以真机为准。

## 8. 已知坑速查

| 现象 | 原因 / 解法 |
|---|---|
| 日志大量 `Material inactive: out of scope` | 组件不在 Navigation 标题栏 / Tabs `tabBar` 槽位 → 要么挪进槽位，要么依赖 `manualGlass` 兜底视觉（两不误的写法见 §6） |
| 玻璃发糊 / 边缘双影 | 自己在元素上又加了 `.shadow(...)` 或 `.backgroundEffect` 有实际模糊 → 用 `Theme.glassShadowStyle()` + `ImmBlur.X()`（空值） |
| 模拟器看不到任何玻璃 | 正常，模拟器不渲染系统材质；必须真机验收 |
| 卸载重装后才生效 / 改动"没反应" | 签名/旧缓存干扰，先卸载重装再验证（本项目实证：卸载重装后新材质路径生效） |
| 低版本也想有玻璃观感 | 走 `BottomBar()` 手写路径：`manualGlass` + `manualGlassBorder`，观感接近 |
| 弹窗默认纯色 | 默认 `Theme.sheetBg` + 顶部高光边方案（§6.5），不叠材质 |
| **顶部**吸顶行（胶囊/圆钮）想要官方玻璃 | 别急着上真模糊：**先按 §6.7 把它整行搬进 `Navigation` 的 `title` 槽位**，槽内子元素挂 `systemMaterial` 即渲染（2026-09-10 首页顶栏真机已验）—— 这是 **B 档顶部槽位**，不是降级路径 |
| 槽内元素挂了 `systemMaterial` 却看不到玻璃 | 检查三件事：① 槽内是否还留着 `backgroundColor` / `border` / `backgroundBlurStyle` / `shadow`（把材质盖住或双叠发脏）；② 是否漏了 `barStyle: BarStyle.STACK`（失去沉浸）；③ title options 的 `backgroundColor` 是否显式设了 `Color.Transparent`（标题栏自带底色压内容）→ §6.7 四条必记 |
| body 内**非顶部**吸顶元素想要真模糊 / 顶部行要回退 | `systemMaterial` 在该位 out of scope → 走 §6.1 `backgroundBlurStyle` 备选；**这是降级路径，接入前询问用户** |
| API 26 **自绘**弹窗浮层挂 `systemMaterial` 仍不渲染 | probe 实测：§10.1"组件级通用"不含自绘浮层/吸顶叠放位（无玻璃、hilog 判范围外）。⚠️ **2026-09-10 更正**：该结论只对「页面 body 自绘浮层」成立——**把弹窗改成系统 `CustomDialog` 后官方材质正常生效**（官方 A 档「弹窗类」覆盖 `CustomDialogControllerOptions.systemMaterial`）。参见 §9 历史 2026-09-10 条目与 `docs/immersive-light-sense-api26-official.md` §4 |
| 真模糊上叠了「实白块」，磨砂感消失 | `backgroundBlurStyle` 之上又叠高不透明度白底（如亮色选中 `#A6FFFFFF`）形成实白夹层 → 底色 alpha 归零，层次交给文字强调色 + 阴影（§6.1 坑2） |
| 弹窗改真模糊后仍"纯白底、跟之前没区别" | 高 alpha 白底（80% `glass`、48% `sheetGlass` 前身）形成白夹层，把模糊结果与背后透出盖光 → 换无夹层 `sheetGlass`（亮色透明 / 深色 18%）+ 0.5 描边 + 真实浮起阴影（§6.6 坑1/2）；背后恰为大片纯白卡片区时透出有限属预期（坑3） |
| 吸顶胶囊换备选后「平了、没层次」 | 该路径无材质 `applyShadow`，删了 `.shadow` 就会压平 → 必须保留真实阴影；用中性 `segGlassShadow` 两档（§6.1 坑4/5） |

## 9. 相关文档与历史

- `docs/glass-material-fallback.md`：早期（v68）纯手写降级方案说明。现 `manualGlass` 系列降级为"材质兜底层"保留在四段式模板中，其"总开关/恢复官方材质"逻辑仍由 `GLASS_FALLBACK_ENABLED` 承担。
- 关键演进：手写 Stack 叠放底栏（范围外，材质不渲染）→ IndexHds 试点（HDS `HdsTabs` + `barOverlap` + `barFloatingStyle` 真玻璃）→ 定稿：**原生 ArkUI Tabs**（`barOverlap` @since10 / `barFloatingStyle` @since26）复刻悬浮胶囊，无第三方依赖 → **API26 新材质体系**（§10，兜底透明化、材质全权接管）。
- **2026-09-05 备选方案定型（§6.1）**：首页顶栏推荐/关注胶囊与搜索圆钮因处于页面 body 顶层叠层，`systemMaterial` 渲染不稳定、沉浸光感无法实现 → 与用户确认后改走 `backgroundBlurStyle` 真模糊磨砂，新增 `segGlass` / `segGlassShadow` 令牌；期间验证两条经验并写入 §6.1 坑位——「高不透明度白底叠真模糊会形成实白夹层」「备选路径必须保留中性真实阴影、不可抄材质全零阴影」。
- **2026-09-07 弹窗真模糊定案（§6.6）**：ForumsTab 三个弹窗（关注吧长按菜单 `ForumMenuDialog` / 排序下拉 `ForumSortDialog` / 足迹删除确认 `RecentDeleteDialog`）按用户要求由实底白卡 / `sheetBg` 改走 `backgroundBlurStyle` 真模糊，新增弹窗专用令牌 `Theme.sheetGlass`（亮色透明 `#00000000` / 深色 18% `#2E1A1A1E`）；期间再次实证「高不透明白底 = 白夹层盖真模糊」：`Theme.glass` 80% 白与 `sheetGlass` 前身 48% 白均观感退回纯白底、与改造前无差别，底色归零后磨砂才透出，坑位已回写 §6.6 与 §8；同时清理该文件已无引用的 `ImmBlur` / `ImmMaterial` import。
- **2026-09-07 API 26 弹窗材质 probe（结论写 §10.3 / §8）**：为验证 §10.1「组件级通用」能否让自绘弹窗吃到官方材质，临时把 `RecentDeleteDialog` 卡切成「API26 透明底 + `systemMaterial(ImmMaterial.rowItem())`」真机验证——不渲染，与 §6.1 吸顶叠层结论一致 → 弹窗维持 §6.6 真模糊，代码已还原且无残留 import。
- **2026-09-07 收藏页弹窗真模糊落地（Favorite.ets）**：收藏页 6 个自绘弹窗/浮层按用户要求复用 §6.6 模板，由「高不透明 `sheetBg`/`bg`/`bgElevated` 纯色 + 材质接口链（`glassShadowStyle` + `backgroundEffect` + `systemMaterial(ImmMaterial.control())`）」整链替换为 `sheetGlass` + `backgroundBlurStyle(Regular, 0.85)` + 0.5 `manualGlassBorder` 全描边 + 保留各自真实阴影/圆角/转场/遮罩：备份 `BackupDialog`、导出 `ExportDialog`、分类管理 `CategoryManageSheet`、置顶确认 `PinConfirmDialog`、排序下拉 `SortMenuPanel`、移入抽屉 `MovePanel`；移除这 6 处无效材质挂载（EditBar 胶囊、行内取消钮、搜索框等页面级元素上的 `ImmMaterial.control()` 保留，import 不清理）。
- **2026-09-07 自定义分类长按拖拽闪退修复（Favorite.ets `CategoryListView` 拖拽链）**：根因——`onItemDragStart` 在系统激活拖拽手势的同帧里同步把 `draggingCatId` 置上（让被拖 ListItem 自身高度从 80 突变为 0）+ `animateTo` 改 List 底部 padding，对**被拖源 ListItem 在拖拽会话激活期做几何突变**是 ArkUI 拖拽排序已知崩溃模式（旁证：同文件 `ThreadListView` 帖子拖拽同款 preview builder 永不崩，差别仅在它不在这俩回调里改源几何）。修复方案——①`onItemDragStart` 移除 `draggingCatId` / `dragListBottomPad` / `animateTo`，仅记录索引 + 触觉 + 返回 preview；②`onItemDragMove` 入口加**首帧守卫**：`draggingCatId === ''` 时再补 `draggingCatId = sorted[i].id` + `dragListBottomPad = STEP`（直接赋值，不用 animateTo）；③`onItemDragMove` 内目标位高亮原本的 `animateTo` 改为直接赋值（让位不带平滑动画，先求稳定）；④`scrollBy` 节流块挪到首帧守卫（`draggingCatId.length > 0`）之后执行，避开拖拽会话初期的滚动 API 风险；⑤顺手把 onItemDragStart 内的 `this.categories[catIndex]` 改为 `this.sortedCategories()[catIndex]`（单一真理源，避免非 Custom 排序下顺序错位）。视觉上的"原位塌陷 + 智能让位"机制保留——仅延后到首帧触发，手指未动时预览与源卡短暂重叠（约 1 帧），肉眼无感。
- **2026-09-10 一键签到弹窗改系统 CustomDialog 吃官方材质（ForumsTab）**：用户要求「保持布局尺寸内容一致、把玻璃换成官方材质」。自绘浮层挂材质无解（§8 / §10.3 已 probe），故换宿主：`@Builder SignAllDialog()` 自绘 Stack 浮层 → 顶层 `@CustomDialog struct SignAllDialog` + `CustomDialogController`，玻璃改由 `options.systemMaterial = ImmMaterial.dialog()`（Theme 新增预设，`REGULAR` + `interactive:false` + `applyShadow:true`）承担；几何逐项对齐（宽度=屏宽-48vp、`cornerRadius:32`、`padding: Spacing.lg`、`alignment:Bottom`+`offset.dy:-110`、`maskColor:'#06000000'`），内容/字号/按钮原样搬；显隐用 `@State @Watch('onShowSignAllChanged') showSignAll` 驱动 `open()/close()`，既有 `this.showSignAll = x` 调用点零改动；点遮罩/返回走 `onWillDismiss → closeSignAll()` 保持「进行中=中断任务且不关闭」。三条硬约束（务必记住）：① **`customStyle` 必须 `false`**，官方明文 `true` 时背景强制透明 + 圆角归 0 + **沉浸光感不生效**；② `options.width` 是 `Dimension`，**不接受 `calc(100% - 48vp)` 字符串**（编译报错），改按 `display` 屏宽换算数值 vp；③ `@CustomDialog` 必须声明 `controller?: CustomDialogController` 属性。遗留偏差：容器宽度受系统默认上限 400vp 约束，宽屏/平板会比原 `100% - 48vp` 窄；容器是否自带默认内边距待真机量。
- **2026-09-10 顶部吸顶行搬进官方槽位（HomeTab，B 档「顶部槽位」打通）**：首页顶栏「推荐 / 关注动态」胶囊 + 搜索圆钮由 §6.1 真模糊浮层**整行搬进 `Navigation` 的 `title` 槽位**（自定义 builder），玻璃改由**槽内子元素 `systemMaterial`** 承担 —— **真机已验生效**（无 `Material inactive`）。要点：`barStyle: BarStyle.STACK` + title options `backgroundColor: Color.Transparent` 必写（否则失去沉浸 / 标题栏底色压住穿过的内容）；槽内删掉 `backgroundColor / border / backgroundBlurStyle / shadow` 四项；`Theme.ets` 新增**中性档** `ImmMaterial.seg(active)`（REGULAR / THIN，无 `materialColor`）——**不用 `tabActive()`** 是因为它自带品牌蓝赋色，会改掉「去蓝底、状态靠文字强调色 + 字重」的定稿；几何与内容让位 `HOME_TOP_PAD = 98` 一行未改；落地写成开关 `HOME_OFFICIAL_TITLE_BAR`（置 false 即回退到旧 `HomeHeaderOverlay()`，旧 builder 原样保留）。**判据更新：「页面主体一律无解」不成立 —— 顶部行搬进标题栏 `title` 槽位即合法；页面中部玻璃仍只能真模糊。** 新增 §6.7 模板；完整记录见 `docs/新API26沉浸光感经验汇总.md` §1.5 / §6.10，官方侧见 `docs/immersive-light-sense-api26-official.md` §14.6。
- **2026-09-10 材质门限收紧 + 低版本安全网（`Theme.ets`）**：官方文档复核确认 `uiMaterial` / 通用属性 `systemMaterial` / `barFloatingStyle` **全部是 ArkUI `@since 26.0.0`**（`6.1.0(23)` 是 HDS `hdsMaterial` 的起始版本），原 `_materialSupported = _materialApiLevel >= 23` 门限偏松 → 收紧为 **`>= 26`**，并新增 `uiMaterial` 命名空间探测（`new uiMaterial.ImmersiveMaterial()` 放 try/catch 内，构造失败即判不支持）。同时把 `Theme.ets` 内 **18 处** `new uiMaterial.ImmersiveMaterial(...)` 收口到新增的 `createMaterial()`：不支持 / 构造失败一律返回 **`undefined`**（官方语义：`common.d.ts` 注明 `systemMaterial(undefined)` 会让组件回到「无材质效果」），为此 `ImmMaterial.*` 与各 `ensureXxx()` 的返回类型统一放宽为 `| undefined`，**100+ 调用点零改动**。顺带修掉 `Index.ets` 底栏 `isSupported() ? Color.Transparent : Theme.manualGlass(...)` 在 API 23~25 上会丢兜底色的隐患。构建 `BUILD SUCCESSFUL`。官方侧口径见 `docs/immersive-light-sense-api26-official.md` §1.2 / §14.3。

---

## 10. API 26 新约束适配（HarmonyOS 7，2026-09 定案）

### 10.1 新材质体系与旧版差异（务必区分）

| 维度 | 旧世界观（API 18~25） | API 26+（HarmonyOS 7 官方新体系） |
|---|---|---|
| `systemMaterial` 可用性 | 老接口，仅 Navigation 标题栏 / Tabs `tabBar` 槽位内渲染，页面主体判 `Material inactive: out of scope` | 写法变成**组件通用属性**（`CommonMethod.systemMaterial`，任何组件都能编译），但**生效区域并未放开**：官方明确"其他组件仅在 Navigation/NavDestination 标题栏 或 `barPosition = BarPosition.End` 的横向 Tabs 底部 TabBar 生效"，页面主体依旧判范围外。**⚠️ 本行原表述"页面主体任意元素直接挂载即渲染"有误，已于 2026-09-10 更正**——详见 `docs/immersive-light-sense-api26-official.md` §4 / §14.3 |
| `uiMaterial.ImmersiveMaterial` / `ImmersiveStyle` | 无（API 23~25 无此类） | 自 **26.0.0** 起提供（构造参数含 `style/materialColor/colorInvert/applyShadow/interactive/lightEffect`） |
| 与自身背景/阴影/模糊的关系 | 兜底色是"材质失效时的命"，叠着写 | **材质开启时必须清空** backgroundColor（尤其高不透明/纯色），否则背景把材质盖住 → 只见实色块、无玻璃光感 |

> 官方出处：《沉浸光感兼容性适配》（arkts-immersive-light-sense-compatibility）——**该页 2026-09-10 抓取已 404，疑下线/改名**，低版本兼容请以《开启沉浸光感》的 `targetSDKVersion ≥ 26.0.0` 为准（详见 `docs/immersive-light-sense-api26-official.md` §1.1 / §2）。组件级兼容写法：
> `systemMaterial(apiVersion >= 26 ? new uiMaterial.ImmersiveMaterial({ style: uiMaterial.ImmersiveStyle.THIN }) : undefined)`——低版本置 `undefined` 保持组件原样式。

### 10.2 本工程落地（`Theme.ets` 集中处理，调用点零改动、布局尺寸不变）

- **能力检测（2026-09-10 收紧）**：`initMaterialSupport()` = `deviceInfo.sdkApiVersion >= 26` **且** `uiMaterial` 命名空间可构造（try/catch 探测）。原门限 `>= 23` 是 HDS `hdsMaterial` 的起始版本，会让 API 23~25 误入材质路径（详见 `docs/immersive-light-sense-api26-official.md` §14.3）。
- **材质构造收口**：`Theme.ets` 内 18 处 `new uiMaterial.ImmersiveMaterial(...)` 统一走 `createMaterial()` —— `isMaterialSupported() == false` 或构造抛异常时返回 **`undefined`**。这正是官方语义的「无材质」：`common.d.ts` 对 `systemMaterial` 注明 *Setting it to **undefined** will make the component return to the no-material effect*。为此 `ImmMaterial.*` 与各 `ensureXxx()` 的返回类型统一放宽为 `| undefined`，**调用点零改动**（`.systemMaterial()` 与各 options 的 `systemMaterial?` 都接受 undefined）。
- 因此全工程「四段式」调用点（100+ 处，24 个文件）在 API 26 上照旧生效；在 API 23~25 上 `.systemMaterial(undefined)` 被系统忽略，只剩各点位的 `backgroundColor / backgroundEffect / shadow` 兜底（真模糊 / 半透明玻璃），**行为与旧版一致，且不再触碰低版本不存在的 `uiMaterial` 命名空间**。
- `Theme.manualGlass / manualGlassBorder / segGlass / segGlassShadow / bottomSegGlass`：**不分版本**，只要 `GLASS_FALLBACK_ENABLED = true` 就返回半透明兜底色 / 兜底投影 —— 槽位内的材质调用点各自传 `Color.Transparent`（材质生效，盖过兜底），页面主体与低版本则由这些兜底色 + `backgroundBlurStyle` 承担玻璃观感。
- 回退开关仍为 `Theme.GLASS_FALLBACK_ENABLED`：置 `false` 时兜底色 / 兜底投影全部变透明（只留真模糊与材质）。
- 移除死代码：`manualGlassHighlight`（顶部高光线，已在 v1.0 前从所有调用点删除）。

### 10.3 验证与后续注意

- **（2026-09-10 更正）** 原表述「页面主体元素在 API 26 上应呈现材质玻璃」**不成立** —— 页面 body 里的叠放元素一律判 `out of scope`。现状分流：**顶部吸顶行**（首页「推荐 / 关注动态」胶囊 + 搜索圆钮）已搬进 `Navigation` 的 `title` 槽位改走官方材质（§6.7，真机已验）；**页面中部玻璃 / 未搬进槽位的元素**走 §6.1 真模糊兜底。排查残留问题时——若仍见"实心蓝 / 实心白"，查该组件是否绕过 Theme 另自绘了不透明背景（如写死 `backgroundColor('#FFFFFF')`），改为透明或复用 `manualGlass`。
- 官方性能建议：同屏材质层数 ≤ 2；长列表内不要逐项挂厚材质（用 `cardAction`/`rowItem` 的轻量材质或普通背景）。
- 弹窗/底部卡默认仍走 `Theme.sheetBg` 纯色方案（§6.5）；用户要求弹窗真模糊时走 §6.6 `sheetGlass` 真模糊模板（2026-09-07 ForumsTab 三弹窗在用）。
- **2026-09-07 弹窗 probe**：把自绘弹窗浮层卡（ForumsTab `RecentDeleteDialog`，页面 body 顶层 Stack 叠放）按 §10.2 兼容写法挂 `systemMaterial(ImmMaterial.rowItem())`、底色已清为全透明，API 26 真机**仍不渲染**（无玻璃、hilog 判范围外）——新体系"组件级通用"并未覆盖**自绘浮层 / 吸顶叠层**类点位（与 §6.1 吸顶胶囊实测一致）。
- **2026-09-10 更正：自绘浮层无材质，但系统弹窗有**。上述 probe 结论只对**页面 body 自绘浮层**成立。把弹窗宿主换成系统 `CustomDialog`（官方 A 档「弹窗类」，`CustomDialogControllerOptions.systemMaterial`）后材质正常渲染——ForumsTab 一键签到弹窗已按此改造，新增 `ImmMaterial.dialog()` 预设。**判据：自绘浮层 = 无材质；系统 CustomDialog（A 档）= 有材质；顶部吸顶行搬进 `Navigation` 的 `title` 槽位（B 档顶部槽位）= 有材质**（后者 2026-09-10 首页顶栏真机已验，模板见 §6.7）。详见 §9 历史 2026-09-10 两条条目与 `docs/immersive-light-sense-api26-official.md` §14.5 / §14.6。
