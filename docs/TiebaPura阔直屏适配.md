# TiebaPura 阔直屏适配

> 状态：**阶段〇/一/二 已落地（2026-09-15 构建通过，待开关验证与真机校准）** ｜ 创建：2026-09-15
> 关联文档：`docs/TiebaPura平板适配.md`（本方案大量复用其已落地的多列范式，本文只写「差异」，不重复平板文档已有结论）
> 纪律：本文同受平板文档 §6.2「文档更新自检流程（强制七步）」约束，每次更新先过七步、末尾留痕。

---

## 一、背景与设备画像

### 1.1 目标设备

| 项 | 值 | 备注 |
|---|---|---|
| 设备 | HUAWEI Pura X View | 阔直屏（直板、**不可折叠**） |
| 型号代码 | VOL-AL00 | `deviceInfo.productModel`，**只做兜底判据，不做主判据**（§二） |
| 屏幕比例 | **16 : 9.5**（≈1.684） | 用户给定规格；竖屏宽:高 = 9.5 : 16 |
| deviceType | `'phone'`（预期） | 需真机日志核实一次 |
| isFoldable() | `false`（预期） | 直板机；需真机核实 |

### 1.2 关键推算：窗口宽（vp，无真机，按规格推）

| 姿态 | 推算窗口宽 | 与现有断点的关系 |
|---|---|---|
| 竖屏 | 约 460 ~ 540 vp | **< 600（Breakpoint.sm）** → 一切 `pageWidth < 600` 回退分支都会把它拦回手机档 |
| 横屏 | 约 800 ~ 840 vp | **< 840（Breakpoint.md）** → 过不了宿主 `isWideScreen` 档 |

**由此得出本方案第一条总则：阔直屏的列数判定一律不依赖宽度阈值，由「形态闸门 + 横竖屏」直接决定。** 这是它与平板方案最本质的差异（平板靠宽度档分列，阔直屏靠定向定列）。

### 1.3 与四种形态的关系（互斥性论证）

| 形态 | deviceType | isFoldable | 长/短比 | 判定路径 |
|---|---|---|---|---|
| 普通手机 | phone | false | ≥ 2.1（19.5:9 / 20:9） | 比例带拦住 → 手机档 |
| **阔直屏** | phone | false | **≈ 1.684** | **命中新档** |
| 折叠屏（Pura X 展开态） | phone | **true** | 展开 16:10≈1.6 | **型号 VDE-AL00/AL10 + 展开态 → 阔直屏档**（2026-09-15 增）；折叠态 → false 回落手机档（宽度闸门 1 列） |
| 折叠屏（其它） | phone | **true** | — | isFoldable 提前捕获 → 平板档（现状不变） |
| 平板 / 2in1 | tablet / 2in1 | — | 1.33 ~ 1.6 | deviceType 捕获 → 平板档（现状） |

普通手机比例 ≥2.1 与比例带上界 1.85 之间有 **0.25 以上余量**，横竖屏不漂移（物理屏幕尺寸旋转不变）。

---

## 二、总则（判定方案）

### 2.1 判定函数（单一来源，落 `common/Theme.ets`）

```text
isWideBarDevice():
  ① display.isFoldable() → 仅 VDE-AL00/AL10 且展开态(FOLD_STATUS_EXPANDED)返回 true，其余折叠 false
  ② deviceInfo.deviceType === 'phone'
  ③ 型号兜底：productModel ∈ {VOL-AL00, VDE-*} → true
  ④ 长边/短边 ∈ (1.4, 1.85)             // display.getDefaultDisplaySync() 物理宽高
  全程 try/catch，异常时返回 false（安全方向 = 手机档）
```

- 主判据 = **能力带（比例 + 直板 + 非折叠）**，型号代码只做兜底，**不做主判据**（同设备有 AL00/TN00/TL00 等市场变体；模拟器/未来同比例新品型号对不上；硬编码每出一款新机都要发版）；
- `productModel` 为公开 API，模拟器返回 'emulator' 不误命中；
- **历史注（2026-09-15）**：无真机期曾附「forceWideBar 调试开关」（设置页 Toggle + 持久化 + 冷启动同步恢复），云调试真机验证通过后**整体移除**（设置页行 / Constants 键 / EntryAbility 恢复块 / 本函数开关段），旋转解锁改挂 `isWideBarDevice()` 自然判定。

### 2.2 形态闸门收口（顺路完成 H-B 遗留项）

现状：`isWideFormDevice = deviceType==='tablet' || '2in1' || display.isFoldable()` 在 **Theme.tabletTopFadeStop + 约 11 个页面**各复制了一份（本次已逐一实锤：UserProfile / ThreadList / ThreadDetail / SubPostDetail / Search / PersonalContent / MineTab / MessagesTab / Message / ForumsTab / HomeTab / Favorite + Theme.ets）。

改法：
1. Theme.ets 落 `isWideFormDevice()`（函数化，内部 = 平板/2in1/折叠 **∪** `isWideBarDevice()`）；
2. 各页 `private readonly isWideFormDevice` 改调共享函数；
3. **此后形态相关改动永远只改 Theme 一处**（平板文档 §4.6 H-B 的收口初衷，阔直屏是顺路完成的最佳时机）。

注意：阔直屏是纯静态设备属性（不折叠、不变形），函数内不引入任何运行时状态，各页以静态方式调用即可，无 D6（折叠态残留）风险面。

### 2.3 三条红线

1. **不依赖宽度阈值**：各列数函数的阔直屏分支必须插在 `pageWidth < 600` 检查**之前**（竖屏宽 <600 必被拦回手机档）；
2. **不碰平板 / 折叠 / 手机路径**：平板档列数、折叠屏行为、手机单列全部逐像素不变（§六 D 类核对）；
3. **零新容器**：所有多列复用现成结构——瀑布流页走既有「Scroll + 列内独立堆叠 / WaterFlow / lanes」分支，**禁止新引入 WaterFlow**（floor-vanish 红线，平板文档 §4.3/§4.8 教训）。

### 2.4 验证方案

1. **判定日志**：`isWideBarDevice()` 首次求值时 `console.info` 输出 `[WIDEBAR] model/type/foldable/px/ratio/hit`——实机核对一次即可校准阈值（hilog 过滤 WIDEBAR）；
2. **旋转解锁**：EntryAbility 窗口就绪后 `isWideBarDevice()` 命中 → `setPreferredOrientation(AUTO_ROTATION)`（跟随重力、不受系统自动旋转开关限制）；非阔直屏设备不进此分支；
3. 实机核对清单：deviceType 实际值、竖屏窗口宽实测值（校准 §1.2 推算）、`isWideScreen(≥840)` 实际不命中确认；
4. **调试开关已移除（2026-09-15）**：无真机期的「强制阔直屏形态」开关完成使命后拆除，验证一律走云调试 / 实机自然判定。

### 2.5 明确不做的

- **宿主底栏零改动**（H-C 决策照旧）：底栏跟手不跟屏，阔直屏是直板机、握持逻辑同手机；竖屏宽 ~500 时 `calc(100%-48)` ≈ 450 < 480 封顶自然成立，横屏 ~830 仍被 480 封顶压住——**均为有意行为**；
- **宿主 `isWideScreen(≥840)` 档不动**：阔直屏横屏 ~830 过不了 840 档，底栏维持窄档几何，正确；
- **官方槽位（Navigation titleBar / Tabs barFloatingStyle）零改动**；
- **不启用平行视界 EasyGo**（平板文档 §1.4 既定结论，同理由适用：系统分栏会与自有多列叠成双层分栏）；
- **不改二级页路由与叠放关系**。

---

## 三、界面清单与进度

| # | 界面 | 文件 | 现状列数函数 | 平板档 | 阔直屏目标（竖/横） | 状态 |
|---|---|---|---|---|---|---|
| 0 | 判定收口 + 调试开关 | Theme.ets + ~12 文件 | — | — | — | 已落地（2026-09-15） |
| 1 | 首页 | HomeTab.ets | `homeColumns()` | 竖2 / 横3 | **竖1 / 横3**（09-17 改定） | 已落地（09-17 同步） |
| 2 | 进吧 | ForumsTab.ets | `forumColumns()` | 竖3 / 横4（手机2） | **竖1 / 横3**（09-17 改定，竖屏不再沿用手机 2 列） | 已落地（09-17 同步） |
| 3 | 收藏页（吧分类 / 自定义分类 / 打开列表 / 收藏搜索页） | Favorite.ets | `favColumns()` | 竖3 / 横4（手机1） | **竖1 / 横3**（09-17 改定） | 已落地（09-17 同步） |
| 4 | 消息页 | MessagesTab.ets | `notifyColumns()` | 竖3 / 横4 | **竖1 / 横3**（09-17 改定） | 已落地（09-17 同步） |
| 5 | 我的帖子 / 我的收藏 / 我的点赞 / 浏览历史 | PersonalContent.ets | `pcColumns()` | 竖3 / 横4 | **竖1 / 横3**（09-17 改定） | 已落地（09-17 同步） |
| 6 | 他人信息页 | UserProfile.ets | §4.11 列数函数 | 竖3 / 横4 | **竖1 / 横3**（09-17 改定） | 已落地（09-17 同步） |
| 7 | 吧主页（含吧内搜索） | ThreadList.ets | `threadColumns()` | 竖3 / 横4 | **竖1 / 横3**（09-17 改定） | 已落地（09-17 同步） |
| 8 | 全局搜索页 | Search.ets | `searchColumns()` | 竖3 / 横4 | **竖1 / 横3**（09-17 改定） | 已落地（09-17 同步） |
| 9 | 帖子详情页 | ThreadDetail.ets | `splitMode()` + `replyColumns()` | 竖3回复 / 横屏分栏 | **竖屏：内容单列 + 回复2列；横屏：内容分栏** | 已落地（2026-09-15，§4.4） |
| 10 | 楼中楼详情页 | SubPostDetail.ets | 同上（SP 系） | 同上 | 同上 | 已落地（2026-09-15，§4.5） |
| 11 | 宿主壳 / 底栏 | Index.ets | — | — | **零改动**（§2.5） | 无需改动 |
| 12 | 我的页 / 设置类二级页 | MineTab 等 | — | 单列 | **单列**（天然满足，无需分支） | 无需改动 |

---

## 四、逐界面方案

### 4.1 阶段〇：判定收口 + 调试开关（先做，全局受益）

1. Theme.ets 新增 `isWideBarDevice()`（§2.1 五段式）与 `isWideFormDevice()` 函数化（§2.2），含判定日志（§2.4-2）；
2. 约 12 处 `private readonly isWideFormDevice = ...` 三行重复替换为共享函数调用（机械替换，行为对平板/折叠/手机零变化）；
3. 设置页隐藏调试开关 `forceWideBar`（§2.4-1）；
4. 验收：现有设备全量回归（构建通过 + 手机/模拟器逐像素不变）+ 开关打开后首页/进吧出现多列。

**风险自检（§6.2）**：
- A 错位 → 无（纯判定收口，不改任何几何）
- B 出屏 → 无
- C 重叠 → 无
- D 手机回归 → 无（共享函数对非阔直屏设备返回值与原三行表达式逐一等价；必测 = 手机竖屏 360 逐像素 + 折叠屏展开↔折叠）

### 4.2 列数页统一分支（#1~#8，每处 2~3 行）

各列数函数在形态闸门后、宽度检查前插入：

```text
if (isWideBarDevice()) {
  return isLandscape ? 3 : 1;   // 2026-09-17 用户改定：竖屏回落手机单列档（初版竖 2 作废）
}                               // 各页取自己的横竖屏状态（isLandscape / isLandscape() 同源现状）
```

要点：
- **插入位置红线**：必须在 `pageWidth < 600` 之前（§2.3-1）；
- 进吧页竖屏：`forumColumns()` 手机档为 2，阔直屏竖屏**有意改 1**（2026-09-17 用户指定全部页面竖屏单列）；
- 首页：`homeColumns()` 返回 `this.columns`（`updateColumns()` 按形态写 1/3），闸门放行后天然正确；
- 阔直屏竖屏单列后卡宽与手机一致，`ThreadCard` 几何 / 操作栏收紧（`actionCompact()`）在竖屏不再触发（保留作为横屏 3 列窄卡护栏）；
- 骨架屏：`ThreadListSkeleton({ columns })` 等 `columns` 入参消费同一列数函数，自动跟随；UserProfile 两处骨架屏按平板文档 D3 红线**保持默认单列、不加 columns**（阔直屏同样遵守）。

**风险自检（§6.2）**：
- A 错位 → 无（复用既有分桶 / 行分组 / WaterFlow 分支，分桶逻辑吃列数参数）
- B 出屏 → 无（列宽全 `1fr` / `layoutWeight(1)` / lanes 均分）
- C 重叠 → 无（无新容器、无新悬浮层；各页底部让位随既有分支不变）
- D 手机回归 → 无（阔直屏分支首行有 `isWideBarDevice()` 把关；手机 360 竖屏列数恒 1、走原分支逐像素不变；必测 = 手机竖屏 / 手机横屏〔比例 ≥2.1 不命中〕/ 分屏拖窄 / 折叠屏展开↔折叠）

### 4.3 收藏页专项注意（#3）

- `favColumns()` 一处分支覆盖四个场景：收藏夹列表（`lanes`）/ 打开列表（`PostColumnsBlock` 分桶）/ 自定义分类列表（lanes→Scroll 分桶分支）/ 收藏搜索态（`PostColumnsBlock`）——均消费列数参数，结构零改动；
- 平板文档 §4.3 已拍板「多列档排序收半屏面板、无拖拽」——阔直屏沿用（`favColumns() > 1` 即触发，自动生效）；
- 六处弹窗 `dialogCardWidth()` 封顶 400——竖屏 ~500 宽时 `min(400, 500-48)=400` 生效，横屏同，无需改。

### 4.4 帖子详情页专项（#9，用户明确要求）

目标形态：

| 姿态 | 帖子内容 | 回复区 |
|---|---|---|
| 竖屏 | **单列**（原手机结构） | **1 列**（2026-09-15 用户改定，原手机结构逐像素；初版 2 列作废） |
| 横屏 | 左栏分栏（`splitMode()`，左主楼右回复） | **右栏 1 列**（2026-09-15 用户二次改定；平板为 3 列；初版 2 列作废） |

改法（3 处）：
1. `splitMode()`：`isWideFormDevice` 收口后已含阔直屏，条件 `currentWidth >= Breakpoint.sm && isLandscape()` 在横屏 ~830 下自然成立——**竖屏不分栏天然成立（宽 <600），预期零改动，落地时核实一次即可**；
2. `replyColumns()`：加阔直屏分支返 **1**（插在 `< Breakpoint.sm` 检查之前，同 §4.2 位置红线；平板维持 3 不动。2026-09-15 用户二次改定：竖横屏均 1 列，横屏分栏保留、右栏单列；初版恒 2 / 二版竖 1 横 2 均作废）；
3. 楼层定位/高亮：`.id('floor_' + floorId)` 已随卡进列，`targetFloorId` 跳楼基于几何取 rect，两列下预期可用——**挂真机验证项**：消息跳楼落点、高亮卡可见性、两列下分页加载接续。

横屏分栏相关几何（`DETAIL_MAIN_WIDTH=420` 左栏、排序胶囊居中修正量 40、幽灵表头对齐）均按「右栏回复列数 = replyColumns()」自动适应，左栏 420 不变。

**风险自检（§6.2）**：
- A 错位 → 无（`FloorColumnsBlock` 分桶吃列数参数；主楼通栏卡不受列数影响）
- B 出屏 → 无（列宽 `layoutWeight(1)`；`ImageGrid maxWidth` 封顶已有）
- C 重叠 → 有 1 处、挂验证（两列回复卡宽 ~240vp 比平板 3 列 ~300vp 更宽，图片宫格 / 长楼中楼引用条排版预期更好而非更差，但**跳楼定位落点**须真机核）
- D 手机回归 → 无（手机：`replyColumns()=1` + `splitMode()=false` 走原单列 ForEach 逐像素不变；折叠屏：`replyColumns()` 平板分支 3 不变；必测 = 手机帖子页上下滚动 / 跳楼 / 横屏旋转）

### 4.5 楼中楼详情页专项（#10）

与 §4.4 同款三处（`splitMode()` / `replyColumns()` / 定位验证；**2026-09-15 随 §4.4 用户二次改定同步：竖横屏均 1 列**），差异照平板文档 §4.10「不可照抄点」执行：间距语言 `Spacing.sm`(8)、列宽估算式用本页自己的 padding 口径（8 + lg）、`locateNotifyTarget()` 消息定位偏移 `targetY-120` 在两列下重新核实落点。

**风险自检（§6.2）**：
- A 错位 → 无（同 §4.4）
- B 出屏 → 无
- C 重叠 → 有 1 处、挂验证（两列下消息定位落点 / `CommentCard` 卡内 8vp 列末间距已由列内下标方案消化）
- D 手机回归 → 无（同 §4.4 论证）

### 4.6 宿主壳与底栏（#11，零改动留档）

竖屏 ~500 宽：底栏 `calc(100%-48)` ≈ 450 < 480 封顶、5 Tab layoutWeight 均分正常；横屏 ~830：仍窄档（<840），底栏 480 封顶居中。官方 titleBar / barFloatingStyle 槽位与形态无关（materialSupported 判据是 API 级）。全部零改动，本文留档仅为防后续误改。

---

## 五、实施阶段与验收

| 阶段 | 内容 | 验收门 |
|---|---|---|
| 〇 | 判定收口 + `forceWideBar` 开关 + 判定日志（§4.1） | 构建通过；现网设备逐像素回归；开开关后首页/进吧多列出现 |
| 一 | 8 个列数页统一分支（§4.2 / §4.3） | 构建通过；开关态下逐页竖 2 / 横 3 旋转切换；手机档回归 |
| 二 | ThreadDetail / SubPostDetail 专项（§4.4 / §4.5） | 构建通过；竖屏内容单列+回复 2 列；横屏分栏；跳楼/高亮/消息定位 |
| 三 | 文档状态收口 + 真机日志校准（拿到 VOL-AL00 后） | §2.4-3 核对清单全过；阈值定稿 |

全程每阶段独立跑 `tools/build.ps1` 并汇报。

---

## 六、风险与回归

### 6.1 风险表（本文独立成篇，口径同平板文档 §6.1）

| 类 | 编号 | 风险 | 规避 | 状态 |
|---|---|---|---|---|
| A | W-A1 | 阔直屏分支插错位置（落在 `<600` 检查之后）→ 竖屏被拦回手机档 | 位置红线写进 §2.3-1 与 §4.2；code review 检查项 | 已规避 |
| A | W-A2 | 首页 `this.columns` 更新链路依赖形态闸门，收口后未自动生效 | §4.2 要点第 4 条，落地时核实 | 待核实 |
| A | W-A3 | 两列下骨架屏 / 末行补位逻辑与真实列表列数不一致 | 骨架消费同一列数函数；UserProfile 骨架按 D3 保持单列 | 已规避 |
| B | W-B1 | 无真机，宽高推算（460~540 / 800~840）可能偏差 | 判定不依赖宽度阈值（列数仅看横竖屏）；型号兜底；真机日志校准（阶段三） | 已规避 |
| C | W-C1 | ThreadDetail 两列回复下跳楼 / 高亮 / 消息定位落点偏差 | 挂真机验证项（§4.4-C） | 挂门 |
| C | W-C2 | SubPostDetail 消息定位 `targetY-120` 两列下失准 | 挂真机验证项（§4.5-C） | 挂门 |
| D | W-D1 | 普通手机误入阔直屏档 | 比例带 (1.4, 1.85) vs 手机 ≥2.1，余量 >0.25；`isWideBarDevice()` 首行把关 | 已规避 |
| D | W-D2 | 平板 / 折叠被新闸门误改 | 收口函数对非 phone 设备短路（`deviceType!=='phone'` 直接走原三条件） | 已规避 |
| D | W-D3 | 阔直屏分支影响手机横屏 / 分屏 / 自由多窗 | 分支前置 `isWideBarDevice()`（含 deviceType==='phone' 且比例带命中）；分屏拖宽不改变物理屏幕比例 | 已规避 |

### 6.2 自检七步（本次创建文档执行留痕）

| 步 | 结论 |
|---|---|
| 1 像素列宽 | 无——全部复用既有 `1fr` / `layoutWeight(1)` / lanes 结构，本文零新增像素列宽 |
| 2 外边距单一来源 | 无新增——各页沿用 `Spacing.lg` 既有口径 |
| 3 通栏项进网格 | 无——零新容器，既有分支的通栏处理原样复用 |
| 4 末行补空位 | 无新增面——既有 `xxxBlankSlots` / 分桶逻辑吃列数参数自动跟随 |
| 5 定高容器文本 | 无新增——ThreadCard 等卡片多列档 maxLines/封顶已由平板适配落地 |
| 6 形态判定单一函数 + 首帧 | **本文核心改进即此项**：判定收口 Theme 单点 + `forceWideBar` 单挂点；各页首帧初值机制（§4.6 H-A 已定方案）不变 |
| 7 手机回归 | 无——见 §6.1 D 类三条（W-D1~D3）；手机竖屏 360 逐像素不变；必测路径 = 手机竖屏 / 手机横屏 / 分屏拖窄 / 折叠屏展开↔折叠 |

**已过检记录**

| 日期 | 更新内容 | 自检结论 |
|---|---|---|
| 2026-09-15 | 创建本文档（方案稿，未开工）：设备画像与 vp 推算（§一）、五段式判定方案 + 形态收口 + 调试开关（§二）、12 项界面清单（§三）、逐界面方案（§四）、四阶段实施（§五）、风险表 W-A1~W-D3 + 七步留痕（§六）。**代码未改** | A 错位：有 1 处待核实（W-A2 首页 columns 链路，落地时核实）。B 出屏：无（W-B1 已由「判定不依赖宽度阈值」规避）。C 重叠：有 2 处挂真机门（W-C1 跳楼落点 / W-C2 消息定位，均为真机到手后核）。D 手机回归：无（W-D1~D3 已规避；因无真机，验收全程以 `forceWideBar` 开关 + 现有手机/模拟器代验，真机到手后按阶段三清单补核） |
| 2026-09-15 | **阶段〇/一/二全量落地**：① Theme.ets 新增 `FORCE_WIDE_BAR_KEY` / `WIDE_BAR_MODEL('VOL-AL00')` / `isWideBarDevice()`（调试开关→直板非折叠闸门→型号兜底→比例带 (1.4,1.85)，首判打一条 `[WIDEBAR]` 探针日志）/ `isWideFormDevice()`，`tabletTopFadeStop` 改调共享函数；② 12 文件（UserProfile/Favorite/PersonalContent/ThreadList/Search/ThreadDetail/SubPostDetail/MessagesTab/HomeTab/ForumsTab/MineTab/Message）形态闸门字段统一改 `detectWideFormDevice()`；③ 8 列数页加阔直屏分支（竖2/横3，均插在宽度检查之前；ForumsTab 竖屏与手机档同值仅补横 3），HomeTab 另改 `updateColumns()`（阔直屏 2/3）与两处 `columnsTemplate`（补 2 列模板）；④ ThreadDetail/SubPostDetail `replyColumns()` 阔直屏恒 2（splitMode 随收口自动含阔直屏，横屏 ~830≥600 放行分栏）；⑤ Settings 加「强制阔直屏形态（调试）」Toggle 行（重启生效）。`tools/build.ps1` → **BUILD SUCCESSFUL**（2m03s，WARN 均既有） | A 错位：**无**（零新容器，全部复用既有分桶/lanes/WaterFlow 分支；骨架屏经 `homeColumns()` 自动跟随；W-A2 首页 columns 链路已核实——`updateColumns` 独立于宽度阈值、按 isWideBarDevice 分流，天然生效）。B 出屏：**无**（列宽全 `1fr`/`layoutWeight`/lanes）。C 重叠：**有 2 处挂真机门**（W-C1 帖子页两列跳楼落点 / W-C2 楼中楼消息定位 `targetY-120`，真机到手后核）。D 手机回归：**无**（共享函数对非 phone 设备与原三行表达式逐一等价；普通手机比例 ≥2.1 进不了带、`isWideBarDevice()` 首行把关；手机竖屏 360 恒单列逐像素不变；必测路径 = 手机竖屏/横屏/分屏拖窄/折叠屏展开↔折叠；**无真机期验证手段 = 设置→软件设置→「强制阔直屏形态」开关 + 重启**） |
| 2026-09-15 | **帖子详情页 / 楼中楼详情页阔直屏竖屏回复区 2 列 → 1 列（用户改定，横屏不动）**：ThreadDetail / SubPostDetail 两处 `replyColumns()` 阔直屏分支由恒 `return 2` 改为 `return this.isLandscape() ? 2 : 1`——竖屏回复区回归原手机单列结构逐像素（竖 2 列时挂真机门的跳楼落点 / 消息定位两项在竖屏自动消解，仅横屏分栏右栏 2 列仍需真机核）；横屏分栏右栏维持 2 列；平板 3 列不动；§4.4 目标形态表 / 改法 2、§4.5 同步。`tools/build.ps1` → **BUILD SUCCESSFUL** | A 错位：**无**（竖屏回归单列 ForEach 原结构，无新增几何；横屏 2 列沿用既有列内独立堆叠）。B 出屏：**无**。C 重叠：**由 2 处收窄为 1 处挂真机门**（W-C1/W-C2 竖屏项随单列消解，横屏分栏右栏 2 列下跳楼/定位仍挂核）。D 手机回归：**无**（改动全在 `isWideBarDevice()` 分支内，手机 / 平板 / 折叠路径零变化；必测 = 开关态下帖子页竖屏单列滚动 / 横屏旋转分栏） |
| 2026-09-15 | **调试开关失效修复（用户真机反馈「这个开关没作用」）**：根因 = 开关值只写 AppStorage（内存态，重启即丢），而各页形态闸门字段在组件构造时固化、必须重启才生效 → 「开了→重启→值没了」永远不生效。修复 = 持久化 + 冷启动同步恢复四件套：① Constants `CACHE_KEY.FORCE_WIDE_BAR('tieba_force_wide_bar')`；② CacheManager 导出 `STORE_NAME('tieba_cache')`；③ EntryAbility.onCreate 用 `preferences.getPreferencesSync/getSync` **同步**恢复到 AppStorage（必须同步——UsageHabitsManager.init 那条异步链会与首帧构建竞态、慢一步整轮失效；读盘失败按关闭处理=安全方向）；④ Settings 开关 onChange 落 `CacheManager.put`（init 幂等兜底防 store 为 null 静默丢写）。使用方式不变：开开关 → 重启应用。`tools/build.ps1` → **BUILD SUCCESSFUL**（57s） | A 错位：**无**（纯判定数据通道修复，零几何改动）。B 出屏：**无**。C 重叠：**无**。D 手机回归：**无**（开关默认关闭时 EntryAbility 恢复逻辑写 false 与原行为等价，正常用户路径零变化；必测 = 关闭态冷启动逐像素不变 / 开启态冷启动全 App 竖 2 横 3） |
| 2026-09-15 | **阔直屏无法自动旋转修复（用户反馈「无法自动旋转到横屏」）**：根因 = `module.json5` 未写 orientation（默认 unspecified 跟随系统「自动旋转」开关），用户系统开关关闭 → 强制形态下永远竖屏、横 3 列不可达。修复 = 窗口偏好方向两处：① EntryAbility.onWindowStageCreate（loadContent 回调内、mainWindow 就绪后）`forceWideBar` 开启时 `setPreferredOrientation(AUTO_ROTATION)`——跟随重力、**不受系统自动旋转开关限制**；② Settings 开关 onChange 即时设置（开启 AUTO_ROTATION / 关闭恢复 UNSPECIFIED），旋转解锁当次会话立即生效（多列布局仍需重启）。关闭开关重启后不进该分支、回归默认行为。`tools/build.ps1` → **BUILD SUCCESSFUL**（26s） | A 错位：**无**（窗口方向偏好非布局几何；各页 isLandscape 均由 onAreaChange / display.on('change') 驱动，旋转后自动重判列数）。B 出屏：**无**。C 重叠：**无**。D 手机回归：**无**（非阔直屏且开关关闭时不进任何分支、窗口方向维持默认 unspecified 原行为；必测 = 关闭态旋转行为与改动前一致 / 开启态旋转后竖 2 ↔ 横 3 自动切换） |
| 2026-09-15 | **Pura X 展开态接入阔直屏档（用户指定）**：设备 VDE-AL00 / VDE-AL10，展开 6.3" 16:10（2120×1320）。Theme.ets 判定重排：`isFoldable()` 分支**前置**——折叠屏中仅 `WIDE_BAR_FOLD_MODELS(['VDE-AL00','VDE-AL10']) && getFoldStatus()===FOLD_STATUS_EXPANDED` 按阔直屏档，其余折叠设备维持平板档不变；折叠态返回 false 回落手机档（`isWideFormDevice` 对折叠屏恒 true → 各页宽度闸门把折叠态拦回 1 列，与既有路径一致；HALF_FOLDED 不算，仅展开态）。展开态列数口径与阔直屏完全一致（竖 2 / 横 3；详情页竖屏回复 1 列、横屏分栏右栏 2 列），无任何页面级新改动。运行时翻档：折叠↔展开由 display 变化触发各页 onAreaChange / display.on('change') 重渲染，`isWideBarDevice()` 实时求值自动切档。附带核实：HomeTab `syncCardColumns()` 写 `homeColumns()`（折叠态落 1），无多列标记泄漏。`tools/build.ps1` → **BUILD SUCCESSFUL**（49s） | A 错位：**无**（纯判定函数分支重排，零几何改动；展开态列数 2/3 均落在既有容器能力内）。B 出屏：**无**。C 重叠：**无**。D 手机回归：**无**（非折叠设备走原路径逐字节等价——isFoldable 分支对它们原本就 false；其它折叠设备（非 VDE 型号）行为与改动前完全一致；必测路径 = Pura X 展开↔折叠翻档（展开竖 2 / 横 3，折叠单列）/ 普通手机与平板回归） |
| 2026-09-15 | **首页卡片操作栏三胶囊溢出修复（用户云调试阔直屏反馈：分享/评论/点赞「文字图标比按钮大」画出胶囊外）**：根因 = 胶囊 `layoutWeight(1)` 均分、内容（图标 18 + 内距 6 + 文字 13 号 ≈50vp）恒定，阔直屏竖 2 列卡宽 ~210vp 时胶囊被压到 ~50vp 内容必溢出（Row 不裁剪直接画出界）；平板竖 2 列卡 ~370 / 横 3 列 ~408、阔直屏横 3 列 ~258 均无此问题（平板文档「操作栏尺寸一律不动」红线不受影响）。修复 = ThreadCard 新增 `actionCompact()` 收紧判定：多列且估算卡宽（屏宽 − 页边距 lg×2 − 列间距 (列数−1)×md，÷列数，同分桶估算口径）< 240 时进入收紧模式——图标 15（心形 16）/ 文字 11 / 内距 4 / 外距 8 / 高 30 / 圆角 15；单列手机与所有宽卡走原尺寸逐像素不变。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m09s） | A 错位：**无**（收紧只缩胶囊自身尺寸，容器结构 / layoutWeight 均分不变）。B 出屏：**无**（收紧后内容 ~42vp < 胶囊 ~50vp，溢出消除即销本项）。C 重叠：**无**。D 手机回归：**无**（手机单列 `cardColumns<=1` 直接 return false、三胶囊原尺寸逐像素不变；平板 / 阔直屏横屏卡宽 > 240 不触发收紧；必测 = 手机首页卡片操作栏逐像素 / 阔直屏竖 2 列胶囊内容不再溢出 / 平板竖 2 列观感不变） |
| 2026-09-15 | **移除「强制阔直屏形态（调试）」开关（用户确认可去）**：无真机期验证设施完成使命，云调试真机（VOL-AL00）自然判定已验证可用。拆除五处：① Settings「强制阔直屏形态」行 + Builder + @State + aboutToAppear 初始化 + 四项导入；② EntryAbility onCreate `getPreferencesSync/getSync` 冷启动恢复块 + preferences/STORE_NAME/FORCE_WIDE_BAR_KEY 导入；③ Constants `CACHE_KEY.FORCE_WIDE_BAR`；④ CacheManager `STORE_NAME` 恢复私有；⑤ Theme `FORCE_WIDE_BAR_KEY` 常量 + `isWideBarDevice()` 开关段（判定序列回归四段式）。**旋转解锁改挂 `isWideBarDevice()` 自然判定**（原挂 forceWideBar 标志，不改动则真机会失去自动旋转）。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m09s） | A 错位：**无**（纯设施拆除，零几何改动；判定结果对目标设备与开关时代完全一致——VOL-AL00 由型号兜底命中）。B 出屏：**无**。C 重叠：**无**。D 手机回归：**无**（普通手机 / 平板 / 折叠（非 VDE）判定路径与开关时代逐字节等价；必测 = 阔直屏云调试/实机竖 2 横 3 与旋转 / 普通手机回归） |
| 2026-09-17 | **阔直屏竖屏列数 2 → 1（用户改定，横屏 3 列不动）**：8 个列数页（HomeTab / ForumsTab / Favorite / MessagesTab / PersonalContent / UserProfile / ThreadList / Search）阔直屏分支由 `isLandscape ? 3 : 2` 改为 `isLandscape ? 3 : 1`——竖屏全部回落手机单列结构逐像素（含进吧页，不再沿用手机档 2 列）；横屏维持 3 列；详情页回复区已恒单列无需改。附带发现：工作区已并入「大折叠」适配会话（HomeTab `isLargeFoldDevice()` 分支等），本次只动阔直屏分支、未触碰大折叠路径。竖屏单列后 `cardColumns=1` → `ThreadCard.actionCompact()` 竖屏不再触发（保留作为横屏 3 列护栏）；骨架屏 / 分桶 / lanes 全部经列数函数自动跟随。§三 清单 / §4.2 模板与要点同步（初版竖 2 作废留档）。`tools/build.ps1` → **BUILD SUCCESSFUL** | A 错位：**无**（竖屏回归原手机单列结构，无新增几何）。B 出屏：**无**。C 重叠：**无**。D 手机回归：**无**（改动全在 `isWideBarDevice()` 分支内，手机 / 平板 / 大折叠 / Pura X 折叠态路径零变化；必测 = 阔直屏竖屏各页单列 / 旋转横屏 3 列 / 手机平板回归） |
| 2026-09-17 | **帖子详情页横屏排序壳定位修正（用户云调试反馈：只看全部 / 正序钮偏左、离底栏远；竖屏正常不动）**：根因 = `SortPillShell` 定位公式中的平板横屏专属微调（左移 40 + 底距 +14，2026-09-14 按平板 592 底栏系统偏差两轮校准）被阔直屏横屏误命中（`splitMode()` 为 true）。修法与 2026-09-15 大折叠、Pura X Max 同款：两处条件补 `&& !isWideBarDevice()` 排除——阔直屏横屏回落**纯公式定位**（左缘 = `(currentWidth − dockPillWidth())/2` = 底栏左缘天然对齐；底距 = 30 + 岛高 66 与竖屏同距）。竖屏 `splitMode()=false` 本就不吃微调，零变化；平板 / 大折叠 / Pura X Max 路径不变。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m42s） | A 错位：**无**（纯定位微调排除，无新增几何；若真机仍有系统级横向偏差，仿平板做法加阔直屏专属微调值即可，微调点唯一）。B 出屏：**无**。C 重叠：**无**。D 手机回归：**无**（竖屏与手机档条件不含本次改动；平板 / 大折叠 / Pura X Max 分支逐字节不变；必测 = 阔直屏横屏排序钮与底栏左对齐 / 底距贴近 / 竖屏逐像素不变） |
| 2026-09-15 | **帖子详情页 / 楼中楼详情页阔直屏回复区横屏 2 列 → 1 列（用户二次改定）**：ThreadDetail / SubPostDetail 两处 `replyColumns()` 阔直屏分支由 `isLandscape() ? 2 : 1` 改为恒 `return 1`——竖横屏回复区均单列（原手机结构逐像素）；**横屏分栏（splitMode）保留**、右栏回复单列（右栏宽 ~500vp，单列卡更宽舒展）；平板 3 列不动；§4.4 目标形态表 / 改法 2、§4.5 同步（初版恒 2 / 二版竖 1 横 2 均作废留档）。`tools/build.ps1` → **BUILD SUCCESSFUL** | A 错位：**无**（单列回归原 ForEach 结构，分桶不入列）。B 出屏：**无**。C 重叠：**无**（W-C1/W-C2 挂门项随单列全面消解——竖横屏均为已验证的单列跳楼/定位路径，仅横屏分栏左右滚动的形态组合需真机核一次）。D 手机回归：**无**（改动全在 `isWideBarDevice()` 分支内，手机 / 平板 / 折叠路径零变化；必测 = 开关态下帖子页竖屏 / 横屏旋转） |
