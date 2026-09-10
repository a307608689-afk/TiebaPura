# @tangs/components「沉浸光感」实现机制分析与调用手册

> 分析版本：`@tangs/components 1.5.3`（2026-07-10 发布）
> 分析来源：OHPM 下载 HAR 解包（含 `Index.d.ets`、各组件 `.d.ets` 声明、`README.md`、`CHANGELOG.md`；本地解包目录已在仓库清理时删除）
> 结论一句话：**它没有第三条材质渲染路径**——所有"沉浸"效果都来自官方 `@hms.hds.hdsBaseComponent`（华为 HDS 组件体系）的 `systemMaterialEffect`，@tangs 只是负责把它透传 + 补一套"缩小 / 滚动偏移 / 遮罩"的自绘辅助几何。**官方材质的槽位边界它一条都突破不了。**

---

## 1. 库定位与元数据

| 项 | 值 |
|---|---|
| 包名 | `@tangs/components` |
| 版本 | 1.5.3（README 徽章滞后仍标 1.5.2） |
| 作者 | `tangs_2003`（`gitcode.com/tangs_2003`），**个人开发者，非华为官方** |
| 许可 | Apache-2.0 |
| 仓库 | https://gitcode.com/tangs_2003/components.git |
| compatibleSdk | HarmonyOS `6.1.0(API 23)` |
| 声明入口 | `types: Index.d.ets` |
| 发布形式 | `byteCodeHar: true`（HAR 内为 `.abc` 字节码 + `.d.ets` 声明，实现不可读、做了基础防护） |
| 依赖 | 声明 `dependencies: {}`；metadata 记 `@tangs/apputils@1.1.4`（loose）→ 实际安装可能连带拉取同作者工具包 |
| 真实底层 | `@hms.hds.hdsBaseComponent`（声明里所有组件都 import 它的 `SystemMaterialParams` / `HdsTabsAttribute` / `HdsNavigationAttribute` 等），`@syscap SystemCapability.UIDesign.HDSComponent.Core` |

README 自述特性：「沉浸式设计（光感材质、模糊背景、自适应偏移）」「所有组件支持自定义 `SystemMaterialParams` 沉浸光感材质效果」「兼容 HarmonyOS 6.1.0（API 23+）」。

---

## 2. "真沉浸光感"的实现机制剖析

### 2.1 机制拆到底 = 官方 HDS 组件 + 一层薄壳

把每个"沉浸组件"的 `.d.ets` 声明摊开看，全部是同一个套路：

1. `@ComponentV2 struct Xxx` 内部包一个官方组件（`HdsTabs` / `HdsNavigation` / `HdsNavDestination` / `Search` / `Button` / `Tabs` / `bindSheet`）；
2. 统一暴露 `@Param systemMaterialEffect?: SystemMaterialParams | undefined`，原样透传给底层官方组件的材质参数；
3. 在官方组件身上补辅助几何：悬浮条圆角、遮罩、距离底部 padding、滚动偏移、缩小浮标等。

**结论：材质渲染引擎是官方的（HDS systemMaterialEffect / HDS 悬浮页签），@tangs 薄壳不参与"渲染"，只参与"摆姿势"。**

### 2.2 组件 ↔ 底层映射表

| @tangs 组件 | 底层官方载体 | 作者原文说法（README/CHANGELOG） | 槽位性质 |
|---|---|---|---|
| `EnhancedImmersionTabs` | HdsTabs / Tabs 悬浮 Bar | 增强版沉浸标签页，Bar 可缩小 | 底部/侧边**悬浮页签槽** |
| `ImmersionTabs` | HdsTabs | 基于 HdsTabs 的轻量标签页 | 底部悬浮页签槽 |
| `ImmersionNavigation` | HdsNavigation | 内置光感材质**标题栏** | 标题栏槽 |
| `ImmersionNavDestination` | HdsNavDestination | 自动处理标题栏沉浸光感 | 标题栏槽（子页） |
| `ImmersionButton` | HdsTabs 底浮 + Button | 「支持沉浸材质 HdsTabs 实现**底部悬浮效果**」 | 需位于悬浮槽的按钮 |
| `ImmersionSearch` | Search + 底浮 | 「支持 HdsTabs 沉浸材质实现**底部悬浮搜索框**」 | 需位于悬浮槽的搜索框 |
| `PillScrollerTabBar` | 自绘 List（药丸横向滚动） | 可开沉浸光感（`immersion: boolean`） | **自绘控件**，材质需随宿主槽位才有效 |
| `ImmersionSheet` / `ImmersionSheetSpace` | `bindSheet` 半模态 | HdsEffect 点光材质 | 弹窗类 |
| `TabContentTabBar` | 原生 `BottomTabBarStyle` | tabBar 构建器 | 仅生成样式，非材质 |

> 注意 `ImmersionButton` / `ImmersionSearch` 的"底部悬浮"形态依赖 HdsTabs 式的悬浮条载体——也就是说它们**设计出来就是放进底部悬浮页签里用的按钮/搜索**，不是给内容区用的普通钮。这与本工程此前验证的官方材质边界完全一致。

### 2.3 各沉浸组件的辅助机制要点

- **EnhancedImmersionTabs**（功能最重，1.4.0 引入，1.5.x 迭代）：
  - `TabBar` 可在**底部 / 侧边**两位置（`barPosition: "Bottom" | "Side"`）；
  - 侧边 `Auto` 模式需申请权限 `ohos.permission.DETECT_GESTURE`（握持感知），组件声明处 `@SuppressWarnings(PERMISSION)`；
  - `barShrinkStyle`：**Bar 缩小成一个小图标浮钮**，触发方式 `Click`（点最小化）/ `Scroll`（滚离判定距离 `scrollDistance`，默认 45vp）/ `Touch`；
  - `bindScroller`：绑定外部垂直 `Scroller`（单个全局，或 `Scroller[]` 按 TabIndex 一一对应）判缩小/放大，或完全不绑改用手势距离判；
  - 顶部**遮罩** `barMaskHeight`/`barMaskColor`（内容滚入 Bar 区域的渐变盖）；
  - `EnhancedImmersionTabsController`：`index`/`setIndex`/`trySetIndex`（触发 `onBeforeChange` 拦截，返回 false 阻止）/`setShrink`/`onChange`/`onShrinkChange`/`onBeforeChange`；
  - 最外层可 `modifier: AttributeModifier<CommonAttribute>`（注意声明注释：默认样式含 onTouch，用于缩小判定，不可自定义该部分）。
- **ImmersionNavigation / ImmersionNavDestination**：Hds 标题栏槽位包装；声明注释特别警告 **`titleBar`/`titleMode` 不支持 Modifier 自定义，会有问题**。
- **ImmersionTabs**：HdsTabs 轻量壳，`modifier: AttributeModifier<HdsTabsAttribute>`；声明警告 **`barFloatingStyle`、`onChange` 不支持 Modifier 自定义**。
- **ImmersionButton**：
  - 底部悬浮几何；内容区渲染为**跟随滚动高度自适应离底偏移**，README 给出指数衰减模型：
    `offset = amplitude × exp(-(h / decayConstant)^curvature) + asymptote`
    （声明里暴露 `offsetY` 计算属性 + `getBottomOffset(height)` 返回 `-xx%`，实际参数字段以包内 `.d.ets` 为准，README 中的 amplitude/decayConstant 等旧参数名在 1.5.3 声明中未列，见 §4 差异警告）。
- **ImmersionSearch**：悬浮搜索框，声明暴露 `_height`、`modifier: AttributeModifier<SearchAttribute>`；警告 `width/height/offset` 设置无效。
- **PillScrollerTabBar**：药丸式**横向可滚动**标签条（`List`），选中态背景/文字色自绘，`immersion: boolean` 决定是否走材质。**注意：它是自绘内容区控件——是否真的"出光感"取决于它最终被放进哪个宿主槽位**，单独丢内容区不会凭空获得真材质（工程此前实测即如此）。
- **ImmersionSheet / ImmersionSheetSpace / ImmersionSheetController**：半模态 + 标题 + 拖拽条（`dragBar`，默认 true）+ 关闭钮联动；`ImmersionSheetSpace` 提供**绝对定位 0,0 不占位容器**，可用 `bindSheet` 自配 `SheetOptions`（`SheetOptionsBuild` 会锁死生命周期回调防覆盖，生命周期交给 Controller：`show/hide/on/off/clear`，事件 `willAppear/appear/willDisappear/disappear`）；圆角默认 35vp「用于光感效果圆角不出错」。

### 2.4 槽位边界（必须记住的硬边界）

把官方文档结论与本库实现对齐后，**任何包装库都无法改变以下边界**：

| 元素落点 | 真材质（systemMaterial / HdsEffect） | 可用降级 |
|---|---|---|
| 底部悬浮页签（Tabs/ HdsTabs `barFloatingStyle`） | ✅ 渲染 | — |
| Navigation / NavDestination 标题栏 | ✅ 渲染 | — |
| 半模态 / 弹窗 / 系统控件（Slider/Toggle/Select/Search 等） | ✅ 渲染 | — |
| **页面主体任意自绘元素**（吸顶排序胶囊、内容区按钮、卡片、自绘 List/Pill） | ❌ 不渲染 | `backgroundBlurStyle` 真模糊 + 手动半透明底色 + 描边阴影 |

> 直白版：**TiebaPura 里的"吸顶分段胶囊（ThreadList 排序 / Favorite 分类 / HomeTab 推荐·关注）、44 圆钮"放不进官方槽，换成 @tangs 的 PillScrollerTabBar / ImmersionButton 也一样无效**——因为它俩本质就是自绘控件。

---

## 3. API 调用手册（以 1.5.3 包内 `Index.d.ets` / 组件声明为准）

### 3.1 导出清单（`Index.d.ets` 原文）

```
PillScrollerTabItem / PillScrollerTabBarController / PillScrollerTabBar / PillScrollerTabBarBuilder
SymbolIconInfo / IconType
ImmersionNavDestination / ImmersionNavigation / TabContentTabBar
ImmersionTabs / ImmersionSearch / ImmersionButton
EnhancedImmersionTabs / EnhancedImmersionTabsController
TabIconItemInfo / EnhancedImmersionTabsItem / EnhancedImmersionTabsOption / BarShrinkStyle
EnhancedAnimateParam
ImmersionSheet / ImmersionSheetController / ImmersionSheetSpace / SheetOptionsBuild
```

### 3.2 常用组件参数速查（声明级）

**EnhancedImmersionTabs**（沉浸标签页，支持缩小）

| @Param | 类型 | 必填 | 说明 |
|---|---|---|---|
| items | `EnhancedImmersionTabsItem[]` | ✅ | `{ icon, label?, fontWeight?, iconSize?, labelSize?, selectedColor?, unselectedColor?, iconLabelGap?, padding?, content: WrappedBuilder, args }` |
| index | `number` | – | 初始索引 |
| controller | `EnhancedImmersionTabsController` | – | 控制器 |
| option | `EnhancedImmersionTabsOption` | – | `barMaskHeight`/`barMaskColor`/`barBottomPadding`/`barLftRitPadding`/`barPosition`("Bottom"\|"Side")/`barSidePosition`("Start"\|"End"\|"Auto")/`barShrinkStyle`/`barBackgroundColor`/`constraintSize` |
| bindScroller | `Scroller \| Scroller[] \| undefined` | – | 滚动缩小判定；不绑则用触摸距离 |
| modifier | `AttributeModifier<CommonAttribute>` | – | 最外层样式（含 onTouch 前提） |
| systemMaterialEffect | `SystemMaterialParams \| undefined` | – | 自定义光感材质 |

**ImmersionNavigation**（沉浸导航容器）

| @Param | 类型 | 必填 | 说明 |
|---|---|---|---|
| pathStack | `NavPathStack` | ✅ | 页面栈 |
| title | `string \| undefined` | – | 主标题 |
| subTittle | `string` | – | 副标题（作者拼写即 `subTittle`） |
| bottomBuilder | `BottomBuilderParams` | – | 标题栏底部自定义区 |
| menu | `HdsNavigationMenuContentOptions` | – | 菜单 |
| tittleBgColor | `ResourceColor` | – | 标题栏背景 |
| avoidLayoutSafeArea / enableComponentSafeArea | `boolean` | – | 安全区 |
| titleMode / mode | `HdsNavigationTitleMode` / `NavigationMode` | – | 标题/导航模式 |
| modifier | `AttributeModifier<HdsNavigationAttribute>` | – | 属性修饰器 |
| systemMaterialEffect | `SystemMaterialParams` | – | 光感材质 |
| （子内容） | Builder | | |

**ImmersionNavDestination**（沉浸子页）：`title`/`subTitle`/`menu`/`titleBgColor`/`bottomBuilder`/`stackBuilder`/`enableComponentSafeArea`/`avoidLayoutSafeArea`/`enableScrollEffect`(默认true)/`hideBackButton`/`blurEffectiveOffset`/`systemMaterialEffect`/`modifier: AttributeModifier<HdsNavDestinationAttribute>` + 内容 Builder。

**PillScrollerTabBar**（药丸滚动标签）

| 参数 | 类型 | 说明 |
|---|---|---|
| controller | `PillScrollerTabBarController` | `{ tabItems, index, scroller }`，`setIndex(i, notifyChange?)` / `onIndexChange(fn)` |
| style | `PillScrollerTabBarStyle` | `selectedBgColor`/`selectedFontColor`/`unselectedBgColor`/`unselectedFontColor`/`itemSpace`/`itemFontSize`/`itemPadding`/`height` |
| modifier | `AttributeModifier<ListAttribute>` | 最外层 List 样式 |
| immersion | `boolean` | 是否开光感 |
| systemMaterialEffect | `SystemMaterialParams` | 光感材质 |
| 标签项 | `PillScrollerTabItem` | `{ label, leftIcon?, rightIcon? }`（icon 走 `IconType`：`{type:'symbol', icon:$r('sys.symbol.xx')}` 或 `{type:'icon', icon:...}`） |

**ImmersionTabs**：`index`/`barMaskHeight`/`barMaskColor`/`barBottomPadding`/`modifier(HdsTabsAttribute)`/`systemMaterialEffect`/`onChange` + 内容 Builder。
**ImmersionButton**：`text`/`options(ButtonOptions)`/`buttonModify(ButtonModifier)`/`modifier(CommonModifier)`/`systemMaterialEffect`/`click(ClickEvent)` + `content` 插槽。
**ImmersionSearch**：`_height`/`systemMaterialEffect`/`modifier(SearchAttribute)`（width/height/offset 设置无效）。
**ImmersionSheet(直接嵌入)**：`title`/`subTitle`/`dragBar`/`radius`(默认35vp)/`closeButtonClick`(返回 true 阻止关)/`content`。
**ImmersionSheetSpace(bindSheet 占位)**：`controller`/`title`/`subTitle`/`dragBar`/`options(SheetOptions)`/`closeButtonClick`/`content`。
**TabContentTabBar**：`new TabContentTabBar(label, icon).fontWeight(w).themeColor(c).tabBar()` → `BottomTabBarStyle`。
**EnhancedAnimateParam**：`Spring_1000ms_v0_m1_s120_d14` 弹簧参数常量。

### 3.3 ⚠️ README 与 1.5.3 声明不一致（避免踩坑）

- README 徽章与接口滞后于 1.5.3：`ImmersionButton` 的 `amplitude/decayConstant/asymptote/curvature/placeholder`、`ImmersionSearch` 的 `placeholder/onChange`、`PillScrollerTabBar` 的 `selectedBgColor/height_/clip_` 等旧名在 1.5.3 `.d.ets` 中已不在（1.5.2 CHANGELOG 提到"重构沉浸式搜索组件的属性和接口"）。**一切以包内 `.d.ets` 为准**。
- README 示例用 `tittle`，声明一致（`ImmersionNavigation.title` 声明存在但 README 用 tittle）；NavDestination 则用 `titleBgColor`。参数名不统一是作者自身笔误，注意逐个对照。

### 3.4 最小可跑示例（与 1.5.3 声明对齐）

```typescript
import {
  EnhancedImmersionTabs, EnhancedImmersionTabsController,
  EnhancedImmersionTabsItem, EnhancedImmersionTabsOption
} from '@tangs/components';

@Entry
@ComponentV2
struct TabDemo {
  controller: EnhancedImmersionTabsController = new EnhancedImmersionTabsController(0)
  items: EnhancedImmersionTabsItem[] = [
    { icon: $r('sys.symbol.house_fill'), label: '推荐', content: wrapBuilder(TabA), args: [] },
    { icon: $r('sys.symbol.heart_fill'), label: '关注', content: wrapBuilder(TabB), args: [] }
  ]
  option: EnhancedImmersionTabsOption = {
    barPosition: 'Bottom',
    barBottomPadding: 30,
    barShrinkStyle: {
      icon: $r('sys.symbol.chevron_down'), iconType: 'SYMBOL',
      shrinkMode: 'Touch'
    }
  }

  build() {
    EnhancedImmersionTabs({
      items: this.items, option: this.option,
      controller: this.controller, index: 0
    })
    .width('100%').height('100%')
  }
}
@Builder function TabA() { Text('推荐').width('100%').height('100%').textAlign(TextAlign.Center) }
@Builder function TabB() { Text('关注').width('100%').height('100%').textAlign(TextAlign.Center) }
```

---

## 4. 在 TiebaPura 中的接入评估（先读这里再决定用不用）

### 4.1 工程前置条件

| 条件 | 本工程现状 | 结论 |
|---|---|---|
| API 23+（库 compatibleSdk 23） | compatible SDK 6.1.0(23) | ✅ 满足 |
| compile SDK（HDS 类型来自 SDK） | `modelVersion 26.0.0` | ✅ 满足 |
| 真光感真机渲染 | 需 API 26 真机（与本工程 ImmMaterial 结论一致） | ✅ 同机制 |
| 官方 HDS 组件能力 | `SystemCapability.UIDesign.HDSComponent.Core` | 首次 install 需实测编译是否直接解析（HDS 为系统 SDK 组件库，通常随 DevEco SDK 提供） |
| 安装 | 在 `TiebaPura/` 根执行 `ohpm install @tangs/components`，可能连带拉 `@tangs/apputils` | ⏳ 待实测 |

### 4.2 与本工程原生实现的关系（结论：不建议替换）

TiebaPura 已有自研等价方案（原生 `Tabs + barFloatingStyle + uiMaterial.ImmersiveMaterial`、`systemMaterial`、内容区 `backgroundBlurStyle` 真磨砂降级）。@tangs 与本方案**渲染来源相同**（都是官方槽位），差异只在几何形制：

| 页面需求 | 官方槽候选 | tangs 组件 | 判断 |
|---|---|---|---|
| Index 五 Tab 等宽胶囊底栏 | 原生 Tabs `barFloatingStyle`（已落地） | `EnhancedImmersionTabs`/`ImmersionTabs` | **不换**：tangs 是 icon+label 自形制、不等分、可缩小浮标，与定稿 5 等宽胶囊几何冲突 |
| ThreadDetail 评论悬浮岛 | 原生 Tabs 槽（已落地） | 无对应"条内自定义 Dock"形态 | **不换**：`ImmersionTabs` 只包普通 tab 内容切换 |
| 吧主页 ThreadList 吸顶排序 / FAB | **无槽位** | `PillScrollerTabBar` 等 | **无效**：主体元素无真材质，官方槽规则不被库改变；要继续磨砂只能用 backgroundBlurStyle |
| 全新导航式页面（Nav 架构重构） | HdsNavigation 标题栏 | `ImmersionNavigation`/`ImmersionNavDestination` | 可选：仅当页面改 Navigation 路由架构时作"标题栏即真材质"捷径 |

### 4.3 风险清单

1. **个人维护**：单作者、版本迭代快（6/27→7/10 共 10 个小版本），接口漂移大（README/声明不一致即证据）；
2. **字节码发布**：`byteCodeHar: true`，实现不可审阅、不可热修；拉 `@tangs/apputils` 未在声明 dependencies 中体现（loose），装包需验证传递依赖；
3. **不突破材质边界**：内容区自绘元素仍然无效，避免再次误判；
4. **声明缺陷需自行规避**：参数拼写混乱（`tittle`/`subTittle`/`titleBgColor`）、部分 @Param 命名（`_height` 下划线）等；
5. 若接入后出现与官方材质升级冲突，无官方支持渠道。

---

## 5. 附录：分析材料位置

- 解包 HAR：`components.har`（62.6 KB，OHPM 下载所得；本地副本已在仓库清理时删除）
- 解包源码（声明/README/CHANGELOG/oh-package）：OHPM 包内 `package/` 目录（本地副本已删除）
- 在线页：https://ohpm.openharmony.cn/#/cn/detail/@tangs%2Fcomponents
- 官方 HDS 材质文档（华为开发者）：`developer.huawei.com` → HarmonyOS → UI → 沉浸光感/材质（systemMaterial、barFloatingStyle、Navigation 标题栏槽位）
