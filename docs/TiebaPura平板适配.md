# TiebaPura 平板适配

> 交付类型：适配方案文档（本阶段只产出方案，不动代码）
> 版本：v1（草稿）
> 更新：2026-09-12 · §4.3 改动六新增「候选收敛」小节（**方案一 / 方案三**留档待定，本阶段未动代码）
> 说明：本文件按「界面」逐一记录平板适配需求与对应方案，已确认的界面方案沉淀在下方对应小节，未确认的保留在清单中。

## 一、官方适配能力基线（调研结论）

### 1.1 结论速览：是否存在「识别平板自动启用平板布局」

**华为官方没有提供「识别到平板设备就一键自动切换为平板布局」的开关。** 官方在《一次开发，多端部署》体系下提供三层可用机制，其中仅第 3 层属于「配置化、接近自动」：

| 层级 | 官方机制 | 判定依据 | 自动化程度 | 官方是否推荐用于布局 |
|------|----------|----------|------------|----------------------|
| 1 | `deviceInfo.deviceType` 设备类型识别 | 静态设备分类（phone/tablet/2in1…） | 需自行写分支 | 否，仅建议用于能力/形态差异 |
| 2 | 断点 + 响应式布局 | **实时窗口宽度（vp）** | 系统回调触发，需自行写断点分支 | 是，官方主推 |
| 3 | 平行视界 EasyGo（系统级分栏） | 窗口宽度 + 宽高比（不看设备名） | 配置化，系统自动分栏 | 是，官方兜底方案 |

官方核心口径：**按「窗口实际尺寸」判断，而不是按「设备类型」判断**。原因包括折叠屏形态可变、系统分屏/自由多窗可任意缩放、同尺寸不同设备应得到相同布局。

### 1.2 层1：设备类型识别（有 API，但不用于布局）

- 能力：`@ohos.deviceInfo` 的 `deviceInfo.deviceType`，取值含 `'phone'`、`'tablet'`、`'2in1'`、`'tv'`、`'wearable'`、`'car'` 等
- 官方 FAQ：《如何判断当前设备类型为平板或手机，并配置锁定横屏或竖屏》
  <https://developer.huawei.com/consumer/cn/doc/harmonyos-faqs/faq-basics-service-kit-45>
- API 参考：<https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-device-info>
- 限制：属静态设备分类，**不随窗口尺寸变化**；折叠屏展开态、系统分屏、自由多窗、平板窄窗等场景下用它决定布局会失效。官方明确定位为「能力差异化判断」（如是否外接键鼠、是否需要 hover 态）。

### 1.3 层2：断点 + 响应式布局（官方主推）

- 官方文档：《响应式布局》
  <https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/responsive-layout>
- 官方最佳实践：《一多断点开发实践》
  <https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-multi-device-bp-practice>
- 断点定义（以窗口宽度 vp 为基准）：

  | 断点 | 宽度区间 | 典型形态 |
  |------|----------|----------|
  | xs | [0, 320) | 穿戴设备、极小窗口 |
  | sm | [320, 600) | 手机竖屏、折叠屏折叠态 |
  | md | [600, 840) | 平板竖屏、折叠屏展开态、手机横屏 |
  | lg | [840, 1440) | 平板横屏、PC 小窗、分屏半屏 |
  | xl | [1440, +∞) | PC 全屏、大屏、智慧屏 |

  > 注：不同 SDK 版本对 xs / xl 的定义略有差异，落地前按项目实际 SDK 文档复核。关键分界值：320 / 600 / 840 / 1440 vp。

- 三种实现方式：
  1. `mediaquery.matchMediaSync('(600vp <= width < 840vp)')` + `on('change')`（条件驱动，官方推荐）
  2. `window.on('windowSizeChange')`（事件驱动，可同时拿宽高，适合复杂场景）
  3. `GridRow({ breakpoints, columns })` + `onBreakpointChange`（组件级栅格，列数随断点自动切换）
- 组件级自动能力：`Navigation` 支持 `NavigationMode.Auto`，窗口宽度达阈值时自动在单栏（Stack）/ 分栏（Split）间切换。

### 1.4 层3：平行视界 EasyGo（配置化自动分栏，最接近「自动」）

- 官方最佳实践：<https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-easygo-parallel>
- 定位：面向**未适配分栏布局**的应用，通过标准化配置让宽屏/大屏自动左右分栏（左导航 / 右详情），属系统级兜底能力。
- 触发条件（按窗口判定，**不看设备名**）：
  - 宽横屏：窗口宽度 ≥ 600vp 且宽高比 > 1.2
  - 方形宽屏：窗口宽度 ≥ 600vp 且宽高比与高宽比均 ≤ 1.2
  - 窗口宽度不足或过于狭长时不进入分栏，需保留普通单页路径
- 接入方式：
  - `module.json5` 声明 `"easyGo": "$profile:easy_go"`
  - `resources/base/profile/easy_go.json` 定义 `displayModeOptions`（`wideWindowMode` / `squareWindowMode` = `navigationSplit`、`navigationSplitOptions` 中的 `homePage`、`relatedPage`、`wideSplit.ratio`、`squareSplit.ratio` 等）
- HarmonyOS 7（API 26）增强：支持 1:2 / 2:1 分栏比例、购物模式 / 导航模式、分割线颜色、分割线自由拖拽；接入方式为配置文件主动接入。
- 限制与风险：
  - **自由多窗不支持**平行视界；系统分屏需 `enableInSplitScreen: true` 且仍满足窗口条件
  - 配置**不能替代页面自身适配**，页面若写死尺寸仍会出问题
  - `enableReducedContainerSize` / `drawableRectHook` 为**应用级**调整，不会为左右两栏分别返回各自真实宽度，按窗口宽度取值的组件需复核
  - 设备专用节点不会按字段向 `common` 逐项补齐，改配置需注意覆盖面

### 1.5 对本工程的初步判断（待确认）

- 本工程当前为「自绘悬浮底栏 + 各页独立布局」，未采用统一的 `Navigation` / `NavPathStack` 路由栈；平行视界的 `navigationSplit` 基于 `NavPathStack`，**接入不是零成本**，但对「左列表 + 右详情」（如 `ThreadList` ↔ `ThreadDetail`）是强候选方案。
- 层 2 与层 3 互补：可先用层 2 断点完成每页布局自适应；对具备「列表—详情」结构的页面，再评估层 3 平行视界。
- 是否采用层 3，取决于后续逐界面适配的诉求与改造预算，待逐页确认。

### 1.6 工程前置条件（已核实，属整体适配的前提）

- 现状：`entry/src/main/module.json5` 中 `deviceTypes` 当前仅为 `["phone"]`
- 影响：未声明 `tablet` 时，应用在平板上无法进入平板形态（可能以兼容模式 / 手机比例运行），后续所有界面布局适配均无实际意义；平行视界 EasyGo 也不会生效（其 `deviceTypes` 需含 `phone` / `tablet` / `2in1`）
- 待办（本阶段仅记录，**不执行**）：
  1. `deviceTypes` 增加 `"tablet"`；若同时面向 PC，追加 `"2in1"`
  2. 若决定采用平行视界：在 `module.json5` 增加 `"easyGo": "$profile:easy_go"`，并新建 `resources/base/profile/easy_go.json`
  3. 复核 `AppScope/app.json5` 中与屏幕、SDK 相关的声明是否需同步调整
- 备注：该项为整体适配的前置项，建议在所有界面方案落地前先行处理

## 二、总则（待补充）

- 目标设备形态：平板（横屏 / 竖屏 / 可折叠展开态）
- 断点定义（待定）：
- 布局策略（待定）：拉伸铺满 / 居中限宽 / 分栏（列表 + 详情）
- 与手机端的一致性约束（待定）：
- 全局公共能力（待定）：窗口尺寸监听、栅格列数、安全区、沉浸材质槽位

## 三、界面清单与进度

| # | 页面 | 文件 | 类型 | 状态 |
|---|------|------|------|------|
| 1 | 首页 | `pages/HomeTab.ets` | 主 Tab | 已出方案（待确认，见 4.2） |
| 2 | 进吧 | `pages/ForumsTab.ets` | 主 Tab | 已确认（见 4.1） |
| 3 | 收藏 | `pages/Favorite.ets` | 主 Tab | 已出方案（待确认，见 4.3） |
| 4 | 消息 | `pages/MessagesTab.ets` | 主 Tab | 待补充 |
| 5 | 我的 | `pages/MineTab.ets` | 主 Tab | 待补充 |
| 6 | 宿主壳 | `pages/Index.ets` | 宿主 | 待补充 |
| 7 | 搜索 | `pages/Search.ets` | 二级 | 待补充 |
| 8 | 吧内帖子列表 | `pages/ThreadList.ets` | 二级 | 待补充 |
| 9 | 帖子详情 | `pages/ThreadDetail.ets` | 二级 | 待补充 |
| 10 | 楼中楼详情 | `pages/SubPostDetail.ets` | 二级 | 待补充 |
| 11 | 个人内容 | `pages/PersonalContent.ets` | 二级 | 待补充 |
| 12 | 用户主页 | `pages/UserProfile.ets` | 二级 | 待补充 |
| 13 | 关注列表 | `pages/FollowList.ets` | 二级 | 待补充 |
| 14 | 关注 | `pages/Follow.ets` | 二级 | 待补充 |
| 15 | 消息详情 | `pages/Message.ets` | 二级 | 待补充 |
| 16 | 登录 | `pages/Login.ets` | 二级 | 待补充 |
| 17 | 发表主题 | `pages/ComposeThread.ets` | 二级 | 待补充 |
| 18 | 图片预览 | `pages/ImagePreview.ets` | 二级 | 待补充 |
| 19 | 设置 | `pages/Settings.ets` | 二级 | 待补充 |
| 20 | 字号设置 | `pages/FontSizePage.ets` | 二级 | 待补充 |
| 21 | 个性化设置 | `pages/PersonalizedPage.ets` | 二级 | 待补充 |
| 22 | 屏蔽设置 | `pages/ShieldSettings.ets` | 二级 | 待补充 |
| 23 | 黑名单管理 | `pages/BlacklistManager.ets` | 二级 | 待补充 |
| 24 | 使用习惯 | `pages/UsageHabitsPage.ets` | 二级 | 待补充 |
| 25 | 自动签到设置 | `pages/AutoSignSettings.ets` | 二级 | 待补充 |

## 四、逐界面适配方案

### 4.1 进吧页（`pages/ForumsTab.ets`）

**适配需求（用户原话）**
- 平板**竖屏**：我关注的吧卡片显示 **3 列**
- 平板**横屏**：我关注的吧卡片显示 **4 列**
- 手机端保持现状不变

**可行性结论：可以实现。** 本页已有「按窗口宽度切列数」的现成骨架，改动集中在 1 个判定条件 + 1 处模板表达式。

**改动前现状**

| 位置 | 内容 |
|------|------|
| `ForumsTab.ets:416` | `@State isWideScreen: boolean = false;` |
| `ForumsTab.ets:1754` | `.columnsTemplate(this.isWideScreen ? '1fr 1fr 1fr' : '1fr 1fr')` |
| `ForumsTab.ets:1805-1808` | 根容器 `.onAreaChange` 内 `this.isWideScreen = width >= 840;` |
| Grid 参数 | `columnsGap(Spacing.md=12)`、`rowsGap(Spacing.md=12)`、左右 `padding(Spacing.lg=16)` |
| 卡片结构 | `GridItem` → `Row`（44vp 头像 + 10vp 间距 + 文字列），卡片 `padding(Spacing.md=12)`、`borderRadius(Radius.lg)` |

即当前规则：**窗口宽 < 840vp → 2 列；≥ 840vp → 3 列**。

**设计方案**

判定拆成三层，避免互相污染：

1. **是否「大屏形态」设备**（静态，组件构造时算一次）
   条件：`deviceInfo.deviceType` 为 `tablet` / `2in1`，**或** `display.isFoldable()` 为 true。
   - 不用「宽度 ≥ 某值」代替——否则手机横屏（约 700~900vp）会被误判，导致手机横屏也变 3/4 列。
   - 折叠屏必须用 `display.isFoldable()` **单独识别**：其 `deviceType` 返回 `'phone'`，靠 `deviceType` 覆盖不到（官方依据：《屏幕属性》`screenproperty-guideline`；FAQ `faqs-mds-arkui-3`、`faqs-purax-11`；相关接口还有 `display.getFoldStatus()`、`display.on('foldStatusChange')`）。

2. **宽度门槛**（动态，窗口宽度）
   窗口宽度 < 600vp 时一律回落 2 列。这一条同时兜住三种「大屏设备但窄窗」：折叠屏**折叠态**（约 360~420vp）、平板系统分屏半屏、自由多窗拖窄。

3. **横屏 / 竖屏**（动态）
   用**窗口宽高比** `width > height`，不用「宽度 ≥ 840vp」——大尺寸平板竖屏宽度本身就可能 ≥ 840vp（如 13.2 寸平板竖屏约 960vp），用宽度阈值会把竖屏误判为横屏。

4. **列数映射**

   | 形态 | 判定 | 列数 |
   |------|------|------|
   | 平板 / 折叠屏 **横屏** | 大屏形态 && width ≥ 600 && width > height | **4** |
   | 平板 / 折叠屏 **竖屏** | 大屏形态 && width ≥ 600 && width <= height | **3** |
   | 折叠屏**折叠态** | width < 600 | 2（自然回落） |
   | 手机（竖屏 / 横屏） | 非大屏形态 | 2（维持现状） |

**具体改动点（4 处，全在本文件内）**

① 新增 import 与状态：

```ts
import { deviceInfo } from '@kit.BasicServicesKit';
import { display } from '@kit.ArkUI';   // 亦可 from '@ohos.display'

@State isWideScreen: boolean = false;   // 既有，保留
@State isLandscape: boolean = false;    // 新增：横竖屏
@State pageWidth: number = 0;           // 新增：窗口宽度（列数判定依赖，必需）

/** 大屏形态设备：平板 / 2in1 / 折叠屏（折叠屏 deviceType 为 'phone'，必须单独识别） */
private readonly isWideFormDevice: boolean =
  deviceInfo.deviceType === 'tablet'
  || deviceInfo.deviceType === '2in1'
  || display.isFoldable();

/** 列数：大屏横 4 / 大屏竖 3；窄窗与手机维持 2 列 */
private forumColumns(): number {
  if (!this.isWideFormDevice) return 2;
  if (this.pageWidth < 600) return 2;     // 折叠态 / 分屏 / 自由多窗窄窗
  return this.isLandscape ? 4 : 3;
}

private columnsTemplateOf(n: number): string {
  if (n >= 4) return '1fr 1fr 1fr 1fr';
  if (n === 3) return '1fr 1fr 1fr';
  return '1fr 1fr';
}
```

② 扩展既有 `onAreaChange`（行 1805-1808）：

```ts
.onAreaChange((oldValue: Area, newValue: Area) => {
  const width = newValue.width as number;
  const height = newValue.height as number;
  this.isWideScreen = width >= 840;   // 既有，保留
  this.isLandscape = width > height;  // 新增
  this.pageWidth = width;             // 新增（可选）
})
```

③ 替换 `columnsTemplate`（行 1754）：

```ts
.columnsTemplate(this.columnsTemplateOf(this.forumColumns()))
```

④ 首帧防抖（可选，避免初始横屏时先渲染 3 列再跳 4 列）：
在 `aboutToAppear`（行 526）内补一次同步初值：

```ts
import { display } from '@kit.ArkUI';
// ...
const d = display.getDefaultDisplaySync();
this.isLandscape = d.width > d.height;   // px 比较，与 vp 同序，结果一致
```

**单列宽度核算（按上述几何常量推算，vp）**

| 形态 | 窗口宽 | 可用宽 | 列数 | 单列宽 | 卡片内容宽 | 文字区宽 |
|------|--------|--------|------|--------|------------|----------|
| 手机竖屏（现状） | 360 | 328 | 2 | 158 | 134 | 80 |
| 手机横屏 | 780 | 748 | 2 | 368 | 344 | 290 |
| 平板竖屏 | 800 | 768 | 3 | 248 | 224 | 170 |
| 平板竖屏（13 寸） | 960 | 928 | 3 | 301 | 277 | 223 |
| 平板横屏（小） | 1024 | 992 | 4 | 239 | 215 | 161 |
| 平板横屏 | 1280 | 1248 | 4 | 303 | 279 | 225 |

- 计算公式：可用宽 = 窗口宽 − 2×16；单列宽 = (可用宽 − (列数−1)×12) ÷ 列数；卡片内容宽 = 单列宽 − 2×12；文字区宽 = 内容宽 − 44 − 10
- 结论：最紧的是 1024vp 横屏 4 列，文字区仍有 161vp（14vp 字号约 7~8 个汉字 + 省略号），可接受。

**可选增强：最小卡片宽保护**（若担心更窄的小平板 / 折叠屏横屏，如 900vp 时文字区仅约 130vp）

```ts
private forumColumns(): number {
  if (!this.isWideFormDevice) return 2;
  if (this.pageWidth < 600) return 2;                   // 与主方案一致的宽度门槛
  const maxCols = this.isLandscape ? 4 : 3;
  const minCard = 200;                                  // 最小单列宽
  const avail = this.pageWidth - Spacing.lg * 2;        // 扣左右 padding
  let n = Math.floor((avail + Spacing.md) / (minCard + Spacing.md));
  n = Math.min(n, maxCols);
  return Math.max(2, n);                                // 下限 2 列
}
```

> 叠加关系：主方案给上限（横 4 / 竖 3），本增强按最小单列宽再压一次，取更严的结果。以 900vp 横屏为例，`minCard = 200` 时算得 `(868+12)/212 = 4.15 → 4` 列，与主方案一致（文字区约 130vp）；若把 `minCard` 提到 240，则同一窗口会降为 3 列。是否启用由你决定。

**单列宽度核算补充（折叠屏，vp）**

| 形态 | 窗口宽 | 列数 | 单列宽 | 文字区宽 |
|------|--------|------|--------|----------|
| 折叠屏折叠态 | 400 | 2 | 178 | 100 |
| 折叠屏展开竖持 | 750 | 3 | 231 | 153 |
| 折叠屏展开横持 | 1600 | 4 | 383 | 305 |

**风险与回归项**

| # | 风险 | 说明 / 处理 |
|---|------|-------------|
| 1 | 首帧跳变 | `isLandscape` 初值 false，初始横屏时会先 3 列再跳 4 列；用改动点④消除 |
| 2 | 折叠屏覆盖 | 已按需求覆盖：折叠屏用 `display.isFoldable()` 识别（其 `deviceType` 为 `phone`，靠它判定不到）。折叠态因 width < 600 自然回落 2 列，展开态按横竖给 4 / 3 列 |
| 3 | 前置依赖 | `module.json5` 的 `deviceTypes` 必须先加 `"tablet"`（见 1.6），否则真机上应用不会以平板形态运行，列数切换看不到效果 |
| 4 | 行高对齐 | 同一行卡片高度由最高项决定，列数变化不影响该行为，与现状一致 |
| 5 | 「创建吧」卡片 | 同处一个 Grid，会随列数一起变为 3/4 列；如需让它独占或固定宽度需额外处理（默认随流） |
| 6 | 不影响项 | 顶部 TopBar（官方 title 槽位，高 98）、上方「最近访问吧」横向列表、底部 150 占位、`isWideScreen` 的其它用途（本页仅此一处使用）均不改 |

**涉及文件**：仅 `entry/src/main/ets/pages/ForumsTab.ets`（若后续统一改为全局断点方案，则另涉 `EntryAbility.ets` 与 `common/` 下的断点工具）

**状态**：已确认（平板 + 折叠屏均纳入 3/4 列范围）

### 4.2 首页（`pages/HomeTab.ets`）

**适配需求（用户原话）**
- 竖屏：卡片显示 **2 列**
- 横屏：卡片显示 **3 列**

> **已确认（2026-09-11）**：「竖屏 / 横屏」指**平板与折叠屏**形态；**手机端不需要 2 列**，维持现状单列不变。

**现状**

| 项目 | 内容 |
|------|------|
| 双数据源 | 推荐流（`threads` / `loadState` / `homeScroller`）与关注动态（`folThreads` / `folState` / `folScroller`），两套结构完全对称 |
| 容器链 | `Refresh` → `Scroll(scroller)` → `Column(左右 padding)` → `ForEach(ThreadCard)` → 加载中尾卡 → 底部 150 占位 |
| 排列方式 | **单列**纵向；卡片间距用 `margin({ bottom: Spacing.md })` |
| 卡片组件 | `components/CommonComponents.ets` 的 `ThreadCard` |
| 卡片高度 | **不固定**：摘要条件渲染（`maxLines(4)`）；单图固定 `height(220)`；多图 2/4 张走 2 列（格高 140），其余走 3 列（格高 100）；无图则无图片区；图片失败另有降级分支 |
| 骨架屏 | `ThreadCardSkeleton` 高度按 index 在 240 / 300 / 200 间变化，注释明确写着「模拟真实帖子有图/无图的高度差」 |

**选型结论**

卡片高度天生不齐 → **不宜用 `Grid`**（同一行行高被最高卡片撑开，矮卡片下方留大片空白）。
→ **推荐 `WaterFlow` 瀑布流**，与「有图 / 无图、摘要长短不一」的内容特性天然匹配。

**方案 A（推荐）：`WaterFlow` 瀑布流**

1. 滚动容器替换（推荐流约 1385 行、关注动态约 1499 行，两处对称）：

   `Scroll(this.homeScroller) { Column() { ... } }`
   →
   `WaterFlow(this.homeScroller) { ForEach → FlowItem { ThreadCard } }`

   并挂上列数与间距：

   ```ts
   .columnsTemplate(this.homeColumnsTemplate())
   .columnsGap(Spacing.md)
   .rowsGap(Spacing.md)
   ```

2. 列数配置（与进吧页共用同一套「形态判定」，仅映射表不同）：

   | 形态 | 列数 |
   |------|------|
   | 平板 / 折叠屏 **横屏** | **3** |
   | 平板 / 折叠屏 **竖屏** | **2** |
   | 手机 / 窄窗（< 600vp） | 1（**已确认不需要 2 列**，维持现状） |

   ```ts
   private homeColumnsTemplate(): string {
     if (!this.isWideFormDevice) return '1fr';        // 手机：现状单列
     if (this.pageWidth < 600) return '1fr';          // 折叠态 / 分屏 / 自由多窗窄窗
     return this.isLandscape ? '1fr 1fr 1fr' : '1fr 1fr';
   }
   ```

   > `isWideFormDevice` / `isLandscape` / `pageWidth` 定义见 4.1；建议后续抽为公共形态判定能力（见 §5）。

3. 卡片外包 `FlowItem`；`ThreadCard` 上的 `margin({ bottom: Spacing.md })` 改由 `rowsGap` 承担，避免双重间距。

4. 加载中尾卡与「底部 150 占位」需改为 `FlowItem`。
   - 注意：瀑布流中单个占位 `FlowItem` 只占**一列**宽度，底部留白会左右不均。更稳的做法是用 `WaterFlow` 外层容器统一给底部内边距，或把留白并入尾卡高度。

5. **预加载逻辑必须重构（本方案最大风险点）**

   现状依赖三项测量：
   - `onHomeContentAreaChange`（挂在内容 `Column` 上）量**内容高** → 记 `homeContentH` / `folContentH`，并承担「不满一屏时直接预取下一页」分支
   - `onHomeViewportAreaChange`（挂在 `Scroll` 上）量**视口高**
   - `onScroll` 用「剩余 = 内容高 − 视口高 − 偏移 < `HOME_PREFETCH_DISTANCE`(1200)」判定提前加载

   换成 `WaterFlow` 后，`onAreaChange` 只能量到**视口高**，内容高取不到 → 上述判据全部失效，若不动会退化成「滑到底才开始加载」。

   替代做法：
   - 用 `WaterFlow.onScrollIndex((first, last) => ...)`，以 `last` 与 `total - 1` 的差值作预加载判据（等价于「还剩不足 N 条时提前加载」）
   - 「不满一屏」分支可用 `first === 0 && last === total - 1` 判定
   - 保留 `onReachEnd` 作为兜底
   - 可配合 `.cachedCount(n)` 提升滑动流畅度

6. 兼容性确认：`WaterFlow` 接受同一个 `Scroller`；`scrollEdge(Edge.Top)`（重复点 Tab 回顶）与位置记忆（`homeScrollY` / `recommendScrollY` / `folScrollY`）逻辑可继续沿用。

7. 骨架屏需同步：`ThreadListSkeleton`（`Skeleton.ets`）目前是单列 `Column` 堆叠。若不改会出现「Loading 单列 → 加载完跳多列」的视觉跳变，建议同样按列数铺放。

**方案 B（改动最小）：`Scroll` + `Column` 内按行分组**

- 不换滚动容器，仅把 `ForEach` 改为「外层按列数切行、每行 `Row({ space })` 内放 N 个卡片、卡片 `layoutWeight(1)`」
- 优点：滚动容器、预加载测量、回顶、位置记忆**零改动**
- 缺点：**行内卡片高度不等**，`Row` 高度由最高卡片决定，矮卡片下方留白（与 `Grid` 同类问题）
- 若选此方案，建议同时收敛卡片高度（摘要 `maxLines` 降到 2、单图高度比例化），否则空白明显

**方案 C：`Grid` 等高网格**

视觉最整齐，但需给卡片定高或裁剪内容，信息流内容损失大，**不推荐**。

**卡片内部几何的连带影响（无论选哪个方案）**

| 位置 | 现状 | 多列下的问题 | 建议 |
|------|------|--------------|------|
| 单图 | `height(220)` 固定 | 列宽 240vp 时接近方形；列宽 400vp 时明显变扁 | 改 `aspectRatio`（如 16:10）或按列宽比例计算 |
| 多图格子 | 2/4 张 → 格高 140；其余 → 格高 100 | 格宽随列宽变化，比例失真 | 同样比例化 |
| 摘要 | `maxLines(4)` | 多列下卡片偏高，一屏放不下几张 | 大屏下建议降到 2 行 |
| 标题 | `maxLines(2)` | 无 | 可保持 |
| 卡片圆角 | `borderRadius(26)` | 无 | 不动 |

**顶部悬浮按钮的左右对齐约束（结论：会继续对齐，但有硬约束）**

现状几何（取自代码，单位 vp）：

| 元素 | 定位（`HomeTab.ets`） | 左边缘 | 右边缘 |
|------|----------------------|--------|--------|
| 卡片区 | `Scroll` → `Column.padding({ left: Spacing.lg, right: Spacing.lg })`（1385/1440、1499/1554） | 16 | 宽 − 16 |
| 悬浮按钮层（兜底路径） | `HomeHeaderOverlay` → `Row.width('100%').padding({ left: Spacing.lg, right: Spacing.lg })`（1659-1660） | 16 | 宽 − 16 |
| 官方 title 槽位 | `HomeTitleBar`（注释 1667：几何与悬浮层逐项一致） | 16 | 宽 − 16 |

三者共用 `Spacing.lg`（= 16），且该留白是**相对屏幕**而非相对卡片容器，所以「推荐 / 关注动态」胶囊继续与**首列**卡片左边缘咬合，搜索圆钮继续与**末列**卡片右边缘咬合——**多列化本身不会破坏对齐**。

维持对齐的 4 条硬约束：

1. 多列容器的左右外边距**必须保持 16**，列间距一律交给 `columnsGap` / `rowsGap`（属容器**内部**间隙，不改变外边界）。
2. **禁止**为大屏「呼吸感」单独放大卡片区左右留白（如 24 / 32）。一旦放大，首列卡片左边缘跑到 24 而顶部胶囊仍在 16，就是**一个 8vp 的错位台阶**，肉眼可见。
3. 若未来要让大屏内容**居中收窄**（限制最大内容宽后居中），顶部按钮必须套进同一个居中容器，否则同样错位。本方案不含此项，实施时别顺手加。
4. 两处顶栏（`HomeHeaderOverlay` 兜底路径 / `HomeTitleBar` 官方槽位）几何需同步。建议把 16 抽成单一常量（如 `HOME_SIDE_GUTTER = Spacing.lg`），卡片容器与顶栏共用一个源，杜绝以后只改一边。

补充：多列时单列宽常为小数（可用宽 717 → 两列各 350.5vp），框架会把余量分配干净，末列右边缘仍严格贴容器右边界，右侧搜索圆钮的对齐不受影响，无需手工取整。

**顶部满宽渐显带（`BottomFadeOverlay`）的自适应情况**

现状（`HomeTab.ets` 1590-1601；推荐流 / 关注流各挂一次，见 1473 / 1586）：

```ts
Stack()
  .height('100%').width('100%')
  .linearGradient({ direction: GradientDirection.Bottom,
                    colors: [['#00FFFFFF', 0.0], ['#FFFFFFFF', 0.15], ['#FFFFFFFF', 1.0]] })
  .blendMode(BlendMode.DST_IN, BlendApplyType.OFFSCREEN)
  .hitTestBehavior(HitTestMode.None)
```

> 命名虽叫 `Bottom`，功能实为**顶部渐隐带**：停靠点 0.0 在顶部且全透明，0.15 起不透明，配合 `DST_IN` 把顶部内容 alpha 逐级抠掉。

| 维度 | 表现 | 是否需适配 |
|------|------|-----------|
| **宽度** | `width('100%')`，跟随 Feed 容器（即屏幕宽） | **天然自适应，零改动**。纵向渐变与列数无关，多列下整条依然均匀，不会出现半宽、左右错位或"只遮住某一列" |
| **高度** | `height('100%')`，且渐变停靠点是**百分比**（0.15 = 容器高的 15%） | 会随窗口高度自动缩放，但**横屏视口矮时渐隐带被压浅** |

高度核算（停靠点 0.15 ≈ 渐隐带实际高度，vp）：

| 形态 | 视口高（估） | 渐隐带高 |
|------|--------------|----------|
| 手机竖屏（现状） | ~800 | ~120 |
| 平板竖屏 | ~1200 | ~180 |
| 平板横屏（1280×800） | ~640 | **~96** |

- 顶部按钮区所需高度 ≈ `44(top) + 38(胶囊) + 20(bottom)` ≈ **102vp**。平板横屏的 ~96vp 已略小于该值，可能出现「卡片滚到按钮下缘时渐隐已结束」的观感差。
- 处理建议（二选一，属观感微调、非必须）：
  1. 按视口高夹取：`min(max(视口高 × 0.15, 100), 180)`，横屏不浅、竖屏不深；
  2. 直接改固定值（如 110vp），与顶部按钮区高度对齐。
- 另一处提示：`BlendApplyType.OFFSCREEN` 会为大屏建立更大的离屏缓冲（像素数随宽高增长），若平板高分辨率下滚动出现掉帧，可优先怀疑此处（可先用固定高度裁小缓冲验证）。

**涉及文件**

- `entry/src/main/ets/pages/HomeTab.ets`（主体：两处 feed 容器 + 预加载逻辑）
- `entry/src/main/ets/components/Skeleton.ets`（骨架屏跟随列数）
- `entry/src/main/ets/components/CommonComponents.ets`（卡片内部几何，可选）

**风险与回归项**

| # | 风险 | 说明 |
|---|------|------|
| 1 | 预加载失效 | 见上文第 5 点；不重写判据会出现「滑到底才加载」的停顿感 |
| 2 | 底部留白不均 | 瀑布流占位 `FlowItem` 只占一列 |
| 3 | 骨架屏不同步 | Loading 单列 → 完成多列，视觉跳变 |
| 4 | 滚动位置记忆 | `scrollEdge(Edge.Top)` 与偏移记录需实测复核 |
| 5 | 首帧列数跳变 | 与 4.1 同源，`isLandscape` 初值需在 `aboutToAppear` 同步一次 |
| 6 | 前置依赖 | `module.json5` 的 `deviceTypes` 需先加 `"tablet"`（见 1.6） |

**已确认决策**（2026-09-11 用户确认）

1. **手机不需要 2 列** → 本方案仅适用于平板（含折叠屏），手机端维持现状单列。
2. **折叠屏纳入适配范围** → 与进吧页口径一致，统一按「大屏形态」判定，平板与折叠屏不做区分处理。

**已确认决策（续）**

3. `ForEach` → `LazyForEach` 升级：**不做**（2026-09-11 用户确认）。说明见下方附注，仅留档备查。

**附：`LazyForEach` 是什么、有什么用（回应第 3 点提问）**

| | `ForEach`（现状） | `LazyForEach` |
|---|---|---|
| 构建方式 | 一次性构建**全部**数据项 | 只构建**可见区 + `cachedCount` 缓存区**，划出屏幕即回收 |
| 首帧开销 | 80 条 → 一次性创建 80 张 `ThreadCard`（含卡内全部 Image/Text 节点） | 首帧只建十几张，滚动过程中按需创建 |
| 内存 | 整列表常驻 | 只保活可视区附近 |
| 长列表表现 | 条目越多越慢（创建耗时与内存双增） | 基本恒定，与总条数无关 |

**代价 / 前提（为什么不能无脑替换）**

1. 数据源必须实现 `IDataSource` 接口（`totalCount()` / `getData(index)` / `registerDataChangeListener()` / `unregisterDataChangeListener()`）。当前 `threads: ThreadItem[]`、`folThreads: ThreadItem[]` 是普通 `@State` 数组，需要再包一层 `ThreadDataSource` 类。
2. 数据变更必须主动发通知（`notifyDataAdd` / `notifyDataChange` / `notifyDataDelete`）才会刷新 UI，而现状大量依赖 `@State` 数组的**整体赋值**与**原地修改**：
   - 刷新 / 追加：`this.threads = ...`、`this.folThreads = this.folThreads.concat(...)`
   - 点赞回填：直接改某一项的 `isLiked` / `likeCount`
   - 关注流快照应用：`applyFolSnapshot()` 的切片替换
   这些点全部要改成走数据源通知，**漏一处就是「点了赞数字不变」这类静默 bug**——这是升级的主要回归风险来源。

**结论建议：本期不做。** 首页列表量级在几十到一二百条（关注流每页 20 条本地切片、推荐流按页加载），`ForEach` 的实际开销尚可接受；升级会牵动整条数据回填链路，与平板适配目标无关。若后续要做，建议与本次 `WaterFlow` 改造**放在同一个版本**一并实施（两者都要动容器与数据源，分两次改等于返工），或单独开性能专项版本。

**状态**：方案已定稿（平板 / 折叠屏：竖 2 横 3；手机单列；不引入 `LazyForEach`），可进入实施

### 4.3 收藏页（`pages/Favorite.ets`）

**适配需求（用户原话）**

1. 「吧分类 / 自定义分类」两个胶囊，识别平板后**两个胶囊一起左对齐**（手机不变）
2. **竖屏**：收藏夹显示 **2 列**，收藏夹里面帖子显示 **2 列**
3. **横屏**：收藏夹显示 **3 列**，收藏夹里面帖子显示 **3 列**

**现状（代码事实）**

| 位置 | 内容 |
|------|------|
| `FavTitleBar()` 4538-4575 | **官方槽位路径**（`FAV_OFFICIAL_TITLE_BAR = true`）第二行胶囊：`Row({ space: Spacing.sm })` + 两枚 `Button`，各 `.layoutWeight(1)` / `.height(40)` / `.borderRadius(Radius.full)` / `.systemMaterial(ImmMaterial.seg(active))`，行 `.padding({ left: 16, right: 16, top: 2, bottom: Spacing.sm })` |
| `CategoryTabs()` 4633-4670 | **兜底路径**（开关 false）同款胶囊行（自绘磨砂版 `segGlass + backgroundBlurStyle`），同样 `layoutWeight(1)`，行 `.padding({ left: 16, right: 16, top: 100, bottom: Spacing.sm })` |
| `FolderListView()` 3171-3208 | 收藏夹列表：`Refresh > List({ space: Spacing.md, scroller: folderScroller })` → 占位 `ListItem`（`placeholderHeight()`，根态 148）→ 同步提示 `ListItem` → `ForEach(folders)` → `ListItem { FolderCard }` → 底部 90 占位 `ListItem` |
| `FolderCard()` 3210-3285 | 48 头像 + 名称/收藏数 + 右箭头；`.width('100%')`、`.padding(Spacing.lg)`、圆角 26 → **等高**（固定 80vp） |
| `ForumThreadsView()` 3287-3337 | 收藏夹内帖子：`List({ space: Spacing.md })`（**无 scroller**）→ 98 占位 → `ForEach(forumThreads())` → `ListItem { PostCard(card, false) }` → 空态 `ListItem` → 底部 90 占位 |
| `PostCard()` 3350-3495 | 标题 `maxLines(2)` + 摘要（条件渲染，`maxLines(3)`）+ 作者/回复/分享行；`.width('100%')`、`.padding(Spacing.lg)`、圆角 26 → **高度可变** |
| 全局 | 本页**没有** `deviceInfo` / `isFoldable` / `pageWidth` / `isLandscape`，根 Stack（`FavContent()` 2869-2873）也**未挂** `onAreaChange` → 平板形态判定能力需新增 |

**改动一：两枚胶囊在平板下左对齐**

现状是两枚 `layoutWeight(1)` 等分铺满（可用宽 = 屏宽 − 32），手机与平板同款。平板下要改成**内容自适应宽度 + 靠左排列**，手机保持等分。

推荐做法：两处各抽一个带 `stretch` 参数的胶囊 builder，避免双份代码：

```ts
@Builder
CatTabPill(label: string, tab: number, stretch: boolean) {
  Button(label)
    .fontSize(fs(12, this.fontScale))
    .fontWeight(this.categoryTab === tab ? FontWeight.Bold : FontWeight.Medium)
    .fontColor(this.categoryTab === tab ? $r('sys.color.font_emphasize') : $r('sys.color.font_secondary'))
    .backgroundColor(Color.Transparent)                       // 槽位路径：清品牌蓝默认填充
    .systemMaterial(ImmMaterial.seg(this.categoryTab === tab)) // 槽位路径；兜底路径换 segGlass + backgroundBlurStyle
    .borderRadius(Radius.full)
    .height(40)
    .padding({ left: 22, right: 22 })                          // 自适应宽度时保证胶囊饱满（与首页胶囊同口径）
    .layoutWeight(stretch ? 1 : 0)                             // 手机 1 等分；平板 0 按内容宽度
    .accessibilityText(label)
    .onClick(() => { this.switchCategoryTab(tab); })
}
```

调用处：

```ts
Row({ space: Spacing.sm }) {
  this.CatTabPill('吧分类', FavCategoryTab.Forums, !this.isWideFormDevice)
  this.CatTabPill('自定义分类', FavCategoryTab.Custom, !this.isWideFormDevice)
  if (this.isWideFormDevice) {
    Blank()   // 平板：剩余宽度全部吸到右侧，两胶囊自然贴左
  }
}
.width('100%')
```

- **需要实测的点**：`layoutWeight(0)` 是否等价于「不设置」（即不参与主轴剩余空间分配）。若真机上出现宽度塌陷 / 异常，回退方案是 `if/else` 双分支显式写两套 Button（代码变长但零风险）。
- **两处必须同步改**：槽位路径 `FavTitleBar`（4544-4568）与兜底路径 `CategoryTabs`（4635-4663）。只改一处会导致开关 `FAV_OFFICIAL_TITLE_BAR` 切换后行为不一致。
- **行高不变**：仍为 2 + 40 + 8 = 50 → `FAV_CAT_TAB_ROW_HEIGHT`(50)、`favTitleBarHeight()`、`placeholderHeight()`(148) **全部无需调整**。

**改动二：收藏夹列表 2 / 3 列（`FolderListView`）**

`FolderCard` **等高**（头像 48 + 上下 padding 16 → 固定 80vp），因此可直接用 `List` 自带的 `lanes`，无需换瀑布流：

```ts
List({ space: Spacing.md, scroller: this.folderScroller }) { ... }
  .lanes(this.favColumns(), Spacing.md)   // 列数, 列间距（与 space 的行间距互不冲突）
```

但有一个**必须同时处理的坑**：`lanes` 生效后，List 内**所有非数据 `ListItem` 都只占 1 格**，于是

- 顶部占位（148）→ 会和第 1 个收藏夹并排
- 同步提示 `SyncHintRow` → 会和第 1 个收藏夹并排
- 底部 90 占位 → 会和最后一个收藏夹并排

处理办法：把数据项收进 `ListItemGroup`，用它的 `header` / `footer` 承载通栏内容（`ListItemGroup` 的 header/footer 恒为整行宽，不受 `lanes` 影响）：

```ts
List({ space: Spacing.md, scroller: this.folderScroller }) {
  ListItemGroup({ header: this.FolderListHeader(), footer: this.FolderListFooter() }) {
    ForEach(this.folders, (folder: FolderItem) => {
      ListItem() { this.FolderCard(folder) }
    }, (folder: FolderItem) => `folder_${folder.forumName}_${folder.pinned}`)
  }
}
.lanes(this.favColumns(), Spacing.md)
```

其中 `FolderListHeader()` = 现有「占位 + 同步提示」两项，`FolderListFooter()` = 现有底部 90 占位。

**改动三：收藏夹内帖子 2 / 3 列（`ForumThreadsView`）**

`PostCard` **高度可变**（标题 1~2 行、摘要 0~3 行），同一行若用 `lanes` 会被最高卡撑开、矮卡下方留白。两个选项：

| 选项 | 改法 | 优点 | 代价 |
|------|------|------|------|
| **A（推荐）** | 换 `WaterFlow`，`ForEach(forumThreads())` → `FlowItem { PostCard }`，挂 `.columnsTemplate(this.forumColumnsTemplate())` + `.columnsGap(Spacing.md)` + `.rowsGap(Spacing.md)` | 卡片高度各自独立，无留白 | 容器要换，占位/空态改为 `FlowItem` 或移出 |
| B | 继续用 `List` + `.lanes(...)`（与改动二同款） | 改动最小、与收藏夹同范式 | 行内高度差留白（最多差约 3 行 ≈ 54vp） |

- 该列表**没有 scroller**（`List({ space: Spacing.md })`，3290），也**没有 `onReachEnd`** → 换 `WaterFlow` 不牵动滚动恢复与分页逻辑，成本比首页低得多。
- 空态（3301-3320）与底部 90 占位同理：走 `WaterFlow` 时改为独立于流的兄弟节点，或保留为 `FlowItem`（占 1 格，会左右不均，不推荐）。

**改动四：补平板形态判定基础设施（本页新增）**

```ts
import { deviceInfo } from '@kit.BasicServicesKit';
import { display } from '@kit.ArkUI';

@State pageWidth: number = 0;
@State isLandscape: boolean = false;

/** 大屏形态设备：平板 / 2in1 / 折叠屏（折叠屏 deviceType 为 'phone'，必须单独识别） */
private readonly isWideFormDevice: boolean =
  deviceInfo.deviceType === 'tablet'
  || deviceInfo.deviceType === '2in1'
  || display.isFoldable();

/** 列数：大屏横 3 / 大屏竖 2；窄窗与手机维持 1 列 */
private favColumns(): number {
  if (!this.isWideFormDevice) return 1;
  if (this.pageWidth < 600) return 1;        // 折叠态 / 分屏 / 自由多窗窄窗
  return this.isLandscape ? 3 : 2;
}

private forumColumnsTemplate(): string {
  const n: number = this.favColumns();
  if (n >= 3) return '1fr 1fr 1fr';
  if (n === 2) return '1fr 1fr';
  return '1fr';
}
```

在 `FavContent()` 根 Stack（2870-2873 处）补上：

```ts
.onAreaChange((_o: Area, n: Area) => {
  const w = n.width as number;
  const h = n.height as number;
  this.pageWidth = w;
  this.isLandscape = w > h;
})
```

判定口径与 4.1 / 4.2 完全一致（大屏形态 + 宽度门槛 600 + 宽高比），仅列数映射不同。

**改动五：搜索态帖子列表 2 / 3 列（`SearchResultView`）**

**搜索态现状**

| 位置 | 内容 |
|------|------|
| `FavTitleBarRow()` 4448-4460 | **槽位路径**搜索态首行：`Row()` → `FavSlotCircleBtn(chevron_left, 44)`（`.margin({ right: Spacing.sm })`）+ `TextInput`（`.layoutWeight(1)` / `.height(40)` / `.padding({ left: 14, right: 14 })` / `.borderRadius(Radius.full)` / `.systemMaterial(ImmMaterial.control())`）；行 `.padding({ left: 16, right: 16, top: 44, bottom: 10 })` |
| `TopBar()` 4131-4158 | **兜底路径**同款（44 圆钮 + `TextInput.layoutWeight(1)`，玻璃为 `backgroundEffect(ImmBlur.control())`） |
| `SearchResultView()` 4069-4126 | 三态：空关键词提示 / 无结果提示 / `List({ space: Spacing.md })`（98 占位 `ListItem` + `ForEach(searchResults())` → `ListItem { PostCard(card, true) }` + 底部 90 占位） |
| `searchResults()` 2581-… | **本地过滤**：标题 / 吧名 / 分类名命中（分类名命中 → 该分类下帖子纳入），返回 `PostCardItem[]`；**无分页、无 `onReachEnd`、无 scroller** |

**结论一：现状宽度（同行摆返回钮 → 左边缘被挤到 68）**

`TextInput.layoutWeight(1)` 会吃掉 `Row` 中「除 44 圆钮 + 8 间距」以外的全部宽度：

> 现状搜索框宽 = 屏宽 − 2×16 − 44 − 8 = 屏宽 − 84

| 形态 | 屏宽 | 现状搜索框宽 |
|------|------|--------------|
| 手机竖屏（现状） | 360 | 276 |
| 折叠屏展开竖持 | 750 | 666 |
| 平板竖屏 | 800 | 716 |
| 平板横屏（1280） | 1280 | 1196 |

- **右边缘** = 屏宽 − 16 → 与末列卡片右边缘**严格对齐** ✅
- **左边缘** = 16 + 44 + 8 = **68** → 比首列卡片左边缘（16）右移 52 → **左右不对称**，这正是要修的。

**结论二（用户已定稿）：搜索框左右边缘与卡片网格对齐**

> **用户决定（2026-09-11）**：搜索框按「左右卡片对齐」做自适应宽度调整 —— 不再收窄、也不接受左边缘停在 68，要求与卡片网格容器**同宽等边界**。

**做法：把返回圆钮从「行内独立占位」改为「内嵌到搜索框内部左侧」**，让 `TextInput` 独占整行宽度：

```ts
// 槽位路径 FavTitleBarRow() 搜索态分支（TopBar() 4148 兜底路径同改）
Stack({ alignContent: Alignment.Start }) {
  TextInput({ placeholder: '搜索收藏帖子、吧或分类', text: this.searchKeyword })
    .width('100%')                    // 铺满行内可用宽（= 卡片网格可用宽）
    .height(40)
    .padding({ left: 46, right: 14 })  // 左 46 给内嵌返回图标让位，避免文字/placeholder 压图标
    .backgroundColor(Color.Transparent)
    .systemMaterial(ImmMaterial.control())
    .borderRadius(Radius.full)
    .defaultFocus(true)
    .onChange((v: string) => { this.searchKeyword = v; })

  SymbolGlyph($r('sys.symbol.chevron_left'))   // 后添加 = 在上层，命中优先于 TextInput
    .fontColor([$r('sys.color.icon_primary')])
    .fontSize(fs(22, this.fontScale))
    .margin({ left: 12 })
    .hitTestBehavior(HitTestMode.Block)         // 确保图标区域点击只走返回，不被输入框吃掉
    .accessibilityText('退出搜索')
    .onClick((): void => { this.exitSearch(); })
}
.width('100%')
.height(44)     // 关键：外层保持 44，与旧 44 圆钮同高 → 行高/槽位高度 98 完全不变
```

几何结果：

> 新搜索框宽 = 屏宽 − 2×16 = **屏宽 − 32**

| 形态 | 屏宽 | 新搜索框宽 | 左边缘 | 右边缘 | 与卡片网格 |
|------|------|------------|--------|--------|-----------|
| 手机竖屏 | 360 | 328 | 16 | 344 | 完全等边界（原 276 / 左 68） |
| 折叠屏展开竖持 | 750 | 718 | 16 | 734 | 完全等边界 |
| 平板竖屏 | 800 | 768 | 16 | 784 | 完全等边界 |
| 平板横屏（1280） | 1280 | 1248 | 16 | 1264 | 完全等边界 |

- **宽度 = 「列宽核算」表里的「可用宽」**，与 `lanes` / `WaterFlow` 的网格容器逐像素同宽 → 多列后仍严格对齐，无需任何 `maxWidth` / `Blank()`。
- **零几何回归**：外层 `Stack` 保持 `height(44)`（内层 `TextInput` 仍 40 居中）→ 行内容高与旧 44 圆钮一致 → 槽位 `FAV_TITLE_BAR_HEIGHT = 98`（44 + 44 + 10）与 `placeholderHeight()` / `THREAD_TOP_PLACEHOLDER`(98) **全部不变**。
- **两处必须同步**：槽位 `FavTitleBarRow`（4449-4460）与兜底 `TopBar`（4131-4158）。
- **附带影响**：手机端搜索态视觉变化（返回箭头由「框外圆钮」变「框内图标」），需真机确认观感；功能与命中区不变。
- 若真机出现「图标点击被输入框吞掉」，降级方案：去掉 `hitTestBehavior`，把 `SymbolGlyph` 挪进 `Stack` 更外层（或改用 `.overlay()` 挂图标），命中层级同理。

**结论三：搜索态不存在「收藏夹卡片列表」**

`searchResults()` 返回的是 `PostCardItem[]`（帖子）。**吧名命中 = 把该吧下的帖子纳入结果**，不是渲染一张收藏夹卡片；结果里也没有分组标题。所以：

> 搜索态**没有「收藏夹 2/3 列」这一项**，只有帖子列表需要 2/3 列。（用户原话中的「收藏夹显示两列」在搜索态自然落空，仅在根态 / 吧内层级成立。）

**改动五的做法**（与改动三同构，且代价更低）

- `SearchResultView` 的 List **无 scroller** → 不牵动滚动恢复
- **无 `onReachEnd`**（本地过滤全量）→ 不牵动分页
- **无拖拽排序** → 无索引语义风险

| 选项 | 改法 |
|------|------|
| **A（推荐）** | 换 `WaterFlow`：`ForEach(searchResults())` → `FlowItem { PostCard(card, true) }`，`.columnsTemplate(this.forumColumnsTemplate())` + `.columnsGap(Spacing.md)` + `.rowsGap(Spacing.md)`；98 占位 / 底部 90 占位移出流式容器（作为兄弟节点或外层 padding） |
| B | 继续用 `List` + `.lanes(this.favColumns(), Spacing.md)`；98 占位与底部 90 占位按改动二用 `ListItemGroup` 的 `header` / `footer` 收纳 |

- 列数口径与 §4.3 完全共用 `favColumns()`（平板 / 折叠屏：竖 2 横 3；手机 / 窄窗 1）。
- 顶部让位不变：搜索态 title 高 98（`favTitleBarHeight()` 在 `searchMode` 下返回 `FAV_TITLE_BAR_HEIGHT`），与 `THREAD_TOP_PLACEHOLDER`(98) 一致 ✅。
- 空关键词 / 无结果两个提示态都是 `layoutWeight(1)` 居中 `Column`，**与列数无关，不用改**。

**改动六：自定义分类两列表纳入多列（用户已定稿「1 纳入」）**

> **用户决定（2026-09-11）**：`CategoryListView`（分类列表）与 `CategoryThreadsView`（分类内帖子）**纳入** 2/3 列。

两个列表的拖拽机制**完全不同**，必须分开处置。

**A. `CategoryListView`（分类列表，3528）——手绘垂直让位，与多列硬冲突**

| 机制 | 位置 | 多列下的后果 |
|------|------|--------------|
| 前置固定项 3 个（占位 / 新建卡 / 未分类卡） | `CAT_LIST_PREPEND = 3`（1107） | 各占 1 格 → 首行只剩 1 格给分类卡，网格被撑乱 → 必须 `header` 收纳 |
| 卡高 80 / 步长 92 | `CATEGORY_CARD_HEIGHT` / `CATEGORY_CARD_STEP`（1109-1110） | 卡片等高 ✅ 可用 `lanes`；但步长常量只对单列成立 |
| 拖动卡原位塌陷 | `.height(this.draggingCatId === c.id ? 0 : 80)`（3565） | 多列下某格高度塌到 0 → 同行与后续行错位 |
| 智能让位 | `displaceOffsetOf()`（3687-…）+ `.translate({ y })`（3567） | 纯垂直平移；多列要让位需按「行 / 列」换算 `translate({ x, y })`，**现有公式全部失效** |
| 目标位高亮 + 底部让位 | `dragTargetIndex`（3561）/ `dragListBottomPad`（3613） | 底部 padding 只补纵向高度，多列下腾不出目标格 |
| 拖动跟手自动滚动 | `scrollBy(0, ±40)`（3627-3629） | 纵向滚动，多列下仍可用 ✅ |

**结论**：该拖拽是「单列专用手绘算法」，多列与现有让位实现**不可兼容**，必须选一条路：

| 选项 | 做法 | 代价 | 效果 |
|------|------|------|------|
| A（原推荐，**2026-09-12 已出局**） | 多列 + **平板下关闭拖拽**：`.editMode(true)` 改为「1 列时才开」，即 `.editMode(this.favColumns() === 1)`；拖拽/让位代码原样保留 | 小 | 手机端与单列行为**零变化**；平板竖/横下分类卡不能长按拖动排序（与「平板保留拖拽」冲突） |
| B | 多列 + **交还系统原生让位**：`onItemDragStart` 不再返回 `CategoryDragPreview`，并删掉 `displaceOffsetOf` 平移 / 原位塌陷 / `dragListBottomPad` | 中 | 系统在 `lanes` 下按网格让位是正确的；但丢掉虚线占位框视觉，且 v1.15~v1.19 的「防闪退 / 防抽搐」经验作废，需真机回归 |
| C | 多列 + **重写网格让位**：`displaceOffsetOf` 改按 `行 = i / cols`、`列 = i % cols` 算 `translate({ x, y })`；原位塌陷改为**保留格位的不可见占位框**（不塌陷） | 大 | 视觉与单列一致，是四项里唯一要重写算法的 |
| D | 分类列表**保持单列**（仅帖子类列表多列） | 零 | 与「1 纳入」冲突，不采用 |

**候选收敛（2026-09-12 更新，留档待拍板）**

> **前提变更**：用户明确要求「**平板保留拖拽**」→ 上表 **选项 A（平板关拖拽）出局**；**选项 C（重写网格让位）** 经评估性价比最差（见本节末），不作为候选。候选收敛为两条，另新增一条上表没有的路径。

编号对照（对话用「方案」，本文件用字母，避免混淆）：

| 用户称法 | 实质 | 与上表映射 |
|----------|------|------------|
| **方案三** | 多列 + 交还系统原生让位 | = 上表 **选项 B** |
| **方案一** | 多列 + 不做让位 + 目标格高亮 + **自算网格落点** | 新增（上表无此项） |

**方案三（交还系统原生让位）**

做法：`onItemDragStart`（3584-3602）不再返回 `CategoryDragPreview`；删掉 `displaceOffsetOf()` 平移（3567 / 3687-…）、原位 `height(0)` 塌陷（3565）、`dragListBottomPad`（3613）与拖动中 `scrollBy` 跟随（3627-3629）；让系统在 `lanes` 下接管网格让位与落位。

**体验上限最高**：让位动画、边缘自动滚动、跨行落位全部由框架按网格处理，是三条里唯一可能做到「像桌面拖图标一样顺」的路。

**但有两个未验证前提**（均成立方案三才可用，任一不成立即出局）：

1. `List + lanes` 下系统是否真的做**网格让位**；
2. 不返回自定义 preview 时拖动卡是否仍有跟手预览——现有代码注释 3589-3590 明确记录过：不返回 preview → 系统不生成预览 → 原位又塌陷 → 视觉上「拖动卡消失」。

**实机验证实验（低成本，验证完即撤）**：

1. 分类 List（3530）加 `.lanes(2)`；
2. `onItemDragStart` 去掉 `return this.CategoryDragPreview(...)`；
3. 去掉 `.height(draggingCatId === c.id ? 0 : ...)`、`.translate({ y: ... })`、`dragListBottomPad`。

长按拖动观察三件事：**① 有无跟手预览 → ② 其它卡是否网格让位 → ③ 松手后顺序是否正确**。
- 有预览 + 会网格让位 → **方案三成立**（改动量最小、体验最好）。
- 无预览 或 不让位 → **方案三出局**。

**竖屏牵连（关键代价）**：`CategoryListView`（3528）当前**没有任何列数 / 宽度分支**——无 `lanes`、无 `isWideFormDevice` / `pageWidth`，竖屏与平板跑的是**同一个 `List` 与同一套拖拽回调**。方案三的动作全部落在这个唯一 List 上，**默认会连带改掉竖屏手感**；而竖屏现有手绘让位是 v1.15 → v1.19 逐版踩坑（拖动卡消失 / `clip` 透明 / 归位双布局抽搐 / 拖拽激活帧闪退，见 3585-3587 注释）才稳定下来的，交还系统等于把这些修复作废，回归也只能在竖屏上做（竖屏才是日常主力场景）。

若要「只改平板、竖屏零改动」，必须显式分支：

| 分支做法 | 说明 | 代价 |
|----------|------|------|
| 结构分支（两个 List） | n=1 走现手绘、n≥2 走系统原生 | ForEach / 滚动位置 / 刷新 / `categoryScroller` / `categoryScrollOffset` 全部要双份 |
| 回调内分支（一个 List） | `.lanes(n)` + 三个拖拽回调内按 n 判断 | 可行，但须守住「n≥2 时 `draggingCatId` 那套状态完全不参与」，一个 List 内并存两套拖拽协议 |

**方案一（多列 + 不让位 + 目标格高亮 + 自算落点）**

做法：保留 `.editMode(true)`、保留自定义预览（跟手虚影）、保留现有竖向自动滚动；**放弃位移让位**（不塌陷、不 `translate`、不动底部 padding）；改为「拖动中手指所在格高亮」+ 松手按高亮格落位。**n=1（竖屏）时走原逻辑（含原手绘让位），n≥2 时才切换本方案** → 竖屏可做到零改动。

「能不能精准挪位」取决于落点怎么算，必须分两层：

1. **落点数据精度**
   - 现有代码直接采信系统 `insertIndex`（3647-3657，`to = insertIndex - CAT_LIST_PREPEND`）。单列可靠，**多列语义官方未作保证**：系统很可能按「最近 item / 落在第几行」粗算 → 同一行 n 个格子只映射到 1~2 个 `insertIndex`，手指在左半格 / 右半格得到同一插入位，即「没法精准挪位」。
   - 因此方案一**不能裸信系统 `insertIndex`**，需自算网格落点：拖拽开始时缓存所有格子 Rect，拖动中按 `row = ⌊(py − gridTop) / rowH⌋`、`col = ⌊(px − gridLeft) / colW⌋`，再按「点在该格左半 / 右半」决定 `row × n + col` 还是 `+1`（末行不满时 clamp）。
   - **方案一的白送优势**：不让位 → 拖动期间所有静态格矩形**完全不变** → Rect 只需缓存一次，之后纯数学判断，精度可到格级甚至左右半级；而重写让位（选项 C）因矩形持续变化反而更难做准。

2. **视觉反馈精度**：卡不挪，用户看不到落点 → **必须做目标格高亮**，否则主观感受就是「瞎挪」。因为格位固定，方案一的高亮比让位方案更稳（不会跟错）。

**待实测项**：`ItemDragInfo` 的 `x / y` 坐标系（相对窗口还是相对 List）——需 log 一次确认；确认后减 List `padding`、加滚动 offset 即可映射到格子。

**两条方案对比**

| 维度 | 方案三（交还系统） | 方案一（不让位 + 自算落点） |
|------|--------------------|------------------------------|
| 让位动画 | 原生平滑，跨行由框架管 | 无（仅有目标格高亮） |
| 边缘自动滚动 | 原生跟手 | 沿用现有 `scrollBy` 节流 120ms |
| 预览视觉一致性 | 不可控（可能是系统默认快照），且有「卡消失」风险 | 可控（复用 `CategoryDragPreview`） |
| 落点精度 | 依赖系统（多列语义未验证） | 自算，可保证格级 |
| 竖屏牵连 | **必然牵连**，须加分支隔离 | 天然可隔离（n=1 走原逻辑） |
| 实现工作量 | 最小（删代码 + 一个验证实验） | 中（新增网格几何 + 高亮） |
| 主要风险 | 两个前提任一不成立即出局；竖屏回归 | 网格落点算法与坐标映射需实测校准 |

**当前建议（待拍板）**：先用上面的实机实验验证方案三的两个前提——成立则选**方案三**（体验上限最高、改动最小）；不成立则选**方案一**（精度可控、竖屏零牵连）。

**为什么不把选项 C（重写网格让位）列为候选**：多列让位在**跨行**时不是「滑动」而是「跳变」（同行内需横向挪一格，下一行首卡需跳到上一行行尾，中间没有连续路径），`translate` 只能让卡片在原位偏移，跨行那张必然是瞬移 → 观感可能比「不让位」更刺眼，且实现风险最高（等于在网格下重踩 v1.15~v1.19 全部坑），性价比最差。

**状态**：方案一 / 方案三**均留档待定**（2026-09-12），本阶段未动代码，等用户后续拍板。

**B. `CategoryThreadsView`（分类内帖子，3968）——标准 `onItemDrop` + splice，可直接多列**

- 拖拽用的是标准索引语义（`itemIndex - 1` → `insertIndex - 1` → `list.splice(to, 0, moved)`，4045-4062）。`lanes` 多列下 `itemIndex` / `insertIndex` 仍是 **item 逻辑索引（不是格子坐标）** → **换算逻辑一行都不用改** ✅
- 该列表**本来就没有**手绘让位（无 `displaceOffsetOf`）→ 现状是「拖动无让位反馈、松手重排」，多列下行为完全一致 → **不回退** ✅
- 需处理的部分：前置占位 `ListItem`（3971，`THREAD_TOP_PLACEHOLDER = 98`）、空态、`loadingMore`、底部 90 占位在多列下都只占 1 格 → 按改动二用 `ListItemGroup` 的 `header` / `footer` 收纳。
  - **收纳后索引基准要同步改**：组内 `itemIndex` 从 0 起 → `onItemDragStart` 的 `if (itemIndex < 1) return;` 守卫删掉、`threadIndex = itemIndex - 1` 改为 `= itemIndex`；`onItemDrop` 的 `to = insertIndex - 1` 改为 `= insertIndex`。（这是本项**唯一**的隐蔽坑）
- 容器选择：**建议保留 `List + .lanes(this.favColumns(), Spacing.md)`**，保拖拽语义最稳；`WaterFlow` 虽也支持 `onItemDrop`，但「换容器 + 拖拽」叠加风险高，不值得。
- 代价：`PostCard` 不等高 → `lanes` 行内留白（被同行最高卡撑开，最多差约 54vp）。若不能接受留白又不愿失去拖拽 → 要么走选项 A（拖拽态回落 1 列，但列数随排序模式跳变、观感突兀），要么接受留白。

**其它补充**

- `CategoryCard` 高固定 80（封面 48 + 上下 padding 16×2）→ 多列后**变宽不变高**（横向拉伸），需真机看封面 + 文字的横向留白是否协调。
- `CategoryListView` 挂着 `refresh + scroller`（`categoryScroller`）与 `.onAreaChange → restoreListScroll`（3582）→ 多列后与风险 3 同源（滚动偏移在形态切换时重复恢复），处理方式一致。
- 两个列表都挂 `BottomFadeOverlay` → 见后文「顶部渐隐带」小节，与列数无耦合。

**列数映射**

| 形态 | 判定 | 收藏夹 / 吧内帖子 / 分类列表 / 分类内帖子 / 搜索结果 |
|------|------|----------------------------------------------------|
| 平板 / 折叠屏 **横屏** | 大屏 && width ≥ 600 && width > height | **3 / 3 / 3 / 3 / 3** |
| 平板 / 折叠屏 **竖屏** | 大屏 && width ≥ 600 && width <= height | **2 / 2 / 2 / 2 / 2** |
| 折叠屏**折叠态** | width < 600 | 1 / 1 / 1 / 1 / 1（自然回落） |
| 手机（竖 / 横） | 非大屏形态 | 1 / 1 / 1 / 1 / 1（维持现状） |

> 搜索态不存在「收藏夹卡片列表」（见改动五结论三），倒数第一列仅为口径完整性列出。

**列宽核算（vp）**

| 形态 | 窗口宽 | 可用宽 | 列数 | 单列宽 |
|------|--------|--------|------|--------|
| 手机竖屏（现状） | 360 | 328 | 1 | 328 |
| 折叠屏展开竖持 | 750 | 718 | 2 | 353 |
| 平板竖屏 | 800 | 768 | 2 | 378 |
| 平板竖屏（13 寸） | 960 | 928 | 2 | 458 |
| 平板横屏（1280） | 1280 | 1248 | 3 | 408 |

- 计算公式：可用宽 = 窗口宽 − 2×16；单列宽 = (可用宽 − (列数−1)×12) ÷ 列数。
- 结论：**所有多列场景的单列宽（353~458）都比手机单列（328）更宽**，卡片内部（`PostCard` 底部「作者 / 回复 / 分享」三元素行、`FolderCard` 头像 + 文字 + 箭头）反而更宽松，不存在挤压问题。

**顶部渐隐带（`BottomFadeOverlay`）的影响**（与 §4.2 同类问题，顺带记录）

现状（`Favorite.ets` 4694-4708，四个列表各挂一次：收藏夹 3200 / 吧内帖子 3332 / 分类内帖子 4022 / 搜索结果 4120）：

```ts
Stack()
  .width('100%').height('100%')
  .linearGradient({ direction: GradientDirection.Bottom,
                    colors: [['#00FFFFFF', 0.0], ['#FFFFFFFF', 0.20], ['#FFFFFFFF', 1.0]] })
  .blendMode(BlendMode.DST_IN, BlendApplyType.OFFSCREEN)
```

- **宽度**：`100%` → 跟随列表容器（= 屏幕宽），纵向渐变与列数无关，多列后仍均匀 → **零改动**。
- **高度**：`100%` + 停靠点 **0.20**（= 视口高的 20%），横屏视口矮时会被压浅：

| 形态 | 视口高（估） | 渐隐带高 | 根态所需（148 = TopBar 98 + 胶囊行 50） |
|------|--------------|----------|------------------------------------------|
| 手机竖屏（现状） | ~800 | ~160 | 刚好覆盖 |
| 平板竖屏 | ~1200 | ~240 | 充足 |
| 平板横屏（1280×800） | ~640 | **~128** | **不足**（帖流 / 搜索态所需 98 尚可） |

- 处理建议（观感微调、非必须）：按视口高夹取 `min(max(视口高 × 0.20, 148), 240)`，或直接固定为 148vp。
- 该层与列数**无耦合**：多列只改变卡片排布，渐隐带仍在列表顶层通栏铺满。
- `BlendApplyType.OFFSCREEN` 会随宽高建立更大的离屏缓冲，平板高分辨率下若滚动掉帧，可优先怀疑此处（与 §4.2 同一提示）。

**风险与回归项**

| # | 风险 | 说明 / 处理 |
|---|------|-------------|
| 1 | `lanes` 下通栏项错位 | 顶部占位 / 同步提示 / 空态 / 底部 90 占位都会只占 1 格 → 必须按改动二用 `ListItemGroup` 的 `header` / `footer` 收纳 |
| 2 | 帖子卡不等高 | 收藏夹卡等高可用 `lanes`；帖子卡建议走 `WaterFlow`（改动三选项 A） |
| 3 | 滚动位置恢复的副作用被放大 | `FolderListView` 上挂着 `.onAreaChange → restoreListScroll(folderScroller, folderScrollOffset)`（3204）。多列后内容总高变小，该回调在**横竖屏切换**时也会触发，会出现「跳一下」；`scrollTo` 超出范围会被系统 clamp（不报错）。建议改为**一次性恢复标志**（仅在「从收藏夹返回」时恢复），避免形态切换时重复滚动 |
| 4 | 两处胶囊需同步 | 槽位 `FavTitleBar`（4538）与兜底 `CategoryTabs`（4633）必须同时改 |
| 5 | `layoutWeight(0)` 行为待实测 | 若宽度异常则回退 `if/else` 双分支写法 |
| 6 | 自定义分类**已纳入**（改动六），风险不对称 | `CategoryThreadsView` 的 `insertIndex` 是 item 逻辑索引（`lanes` 下**无需换算**）→ 只需改「组内索引基准」（删 `itemIndex < 1` 守卫、`-1` 换算去掉）；`CategoryListView` 的手绘垂直让位（`displaceOffsetOf` / 原位塌陷 / `dragListBottomPad`）与多列**不可兼容** → 必须在「平板关拖拽（推荐）/ 交还系统让位 / 重写网格让位」三选一 |
| 6.1 | `CategoryListView` 选项 A 的功能损失 | 平板竖/横下失去长按拖动排序（手机端零影响）；若必须保留拖拽，只能走选项 B（丢虚线占位框视觉）或 C（重写让位算法）。**2026-09-12 更新**：用户要求「平板保留拖拽」→ 选项 A 出局；候选收敛为**方案三**（= 原 B，交还系统原生让位）与**方案一**（新增，不做让位 + 目标格高亮 + 自算网格落点），留档待拍板，详见改动六「候选收敛」小节 |
| 6.2 | `CategoryListView` 前置 3 项 | 占位 / 新建卡 / 未分类卡必须进 `ListItemGroup.header`，否则首行只给分类卡留 1 格；收纳后 `CAT_LIST_PREPEND`（=3）的换算基准要同步核对 |
| 7 | 搜索态**已纳入**（改动五） | 帖子列表 2/3 列；注意：搜索态**没有收藏夹卡片列表**，`searchResults()` 只返回帖子。搜索结果是 `ForEach` **全量构建**（无 LazyForEach、无分页），3 列后同屏可见卡片由约 3~4 张增至 12~18 张，滚动绘制压力上升（总量不变，与首页「不做 `LazyForEach`」结论同口径） |
| 7.1 | 搜索框**左右与卡片同宽**（已定稿） | 去 44 圆钮占位、返回箭头内嵌进搜索框（`Stack` 内左上 + `hitTestBehavior(HitTestMode.Block)`），宽 = 屏宽 − 32 = 网格可用宽；外层 `Stack.height(44)` 保证槽位 98 / `placeholderHeight()` 不变。代价：手机端搜索态观感变化需真机确认；若图标点击被输入框吞掉 → 降级用 `.overlay()` 挂图标 |
| 7.2 | 两处搜索框需同步 | 槽位 `FavTitleBarRow`（4449）与兜底 `TopBar`（4131）必须同改（与风险 4 同理） |
| 8 | 顶部槽位高度 | 胶囊左对齐不改变行高（2 + 40 + 8 = 50）；搜索态外层 `Stack` 保持 44（与旧圆钮同高）→ `FAV_TITLE_BAR_HEIGHT` / `FAV_CAT_TAB_ROW_HEIGHT` / `placeholderHeight()` **全部不变** |

**涉及文件**：仅 `entry/src/main/ets/pages/Favorite.ets`

**状态**：已出方案，**两项已拍板**（2026-09-11）：

1. 「自定义分类」两列表（`CategoryListView` / `CategoryThreadsView`）**纳入**多列 → 见改动六。
2. 搜索框**左右与卡片网格同宽**（返回箭头内嵌进搜索框）→ 见改动五结论二。

**剩余待定 1 项（2026-09-12 更新）**：改动六里 `CategoryListView` 的「多列 + 拖拽」——前提已变更为「**平板必须保留拖拽**」（原选项 A「平板关拖拽」出局），候选收敛为两条，均已在改动六「候选收敛」小节留档：

- **方案三** = 交还系统原生让位（= 原选项 B）：体验上限最高、改动最小；但须先实机验证两个前提（`lanes` 下系统会网格让位 / 不返回 preview 仍有跟手预览），且**必然牵连竖屏**（须加分支隔离）。
- **方案一** = 不做让位 + 目标格高亮 + 自算网格落点：落点精度可控（前提是不裸信系统 `insertIndex`），竖屏可零改动，实现工作量居中。

**待用户后续拍板**（本阶段仅留档，未动代码）。

<!-- 每个界面的方案按以下模板追加：

### N. 界面名称（`pages/XXX.ets`）

- 适配需求：
- 设计方案：
- 涉及改动点：
- 断点 / 阈值：
- 风险与回归项：
- 状态：待确认 / 已确认
-->

## 五、全局改动汇总（待补充）

## 六、验收与回归清单（待补充）
