# TiebaPura 大折叠（Mate X 系列）适配方案

> 立项：2026-09-15 · 状态：**已落地，待真机回归**
> 目标设备：华为 Mate X 系列大折叠展开态（首台样本 Mate X7：8 英寸，约 8:7.3，2416 × 2210）
> 铁律继承：①列数只看横竖屏/形态、绝不依赖宽度阈值；②非大折叠设备（手机 / 平板 / 2in1 / 阔直屏 / 折叠态）判定路径与改动前逐字节一致。

## 一、总原则

大折叠是**第三档形态**，与既有平板档（isWideFormDevice）、阔直屏档（isWideBarDevice）、手机档并列：

| 形态 | 判定 | 列数口径 | 底栏 | 弹窗 |
|---|---|---|---|---|
| 手机 | 非 tablet/2in1、非折叠、非阔直屏 | 内容 1 列（部分页 2） | 通栏 calc(100%-48) | 通栏 / 400 封顶 |
| 平板 / 2in1 | deviceType==='tablet'/'2in1' | 竖 3 / 横 4 | ≥840 限宽 480 | CustomDialog 400 封顶 |
| 阔直屏 | Pura X 展开态 / 比例带 (1.4,1.85) | 竖 2 / 横 3 | 480（isWideBar 命中时） | CustomDialog 400 封顶 |
| **大折叠（本档）** | **折叠 + 展开态 + 非 Pura X + 比例带 (1.0,1.25)** | **竖 2 / 横 3（2026-09-17 改定）** | **限宽 400（弹窗同宽）** | **自绘卡 400 封顶不拉伸** |
| 折叠态（外屏） | 非 EXPANDED → false | 回落手机档 1 列 | 手机档 | 手机档 |

## 二、形态判定（common/Theme.ets）

`isLargeFoldDevice()`（2026-09-15 新增，紧跟阔直屏判定段之后）：

1. `display.isFoldable()` 且**非** Pura X 型号（isPuraXFoldModel 排除，避免与阔直屏档重叠）；
2. `display.getFoldStatus() === FOLD_STATUS_EXPANDED`（仅展开态；HALF_FOLDED 不算，折叠态回落手机档）；
3. 主判据 = 物理像素长宽比带 **(1.0, 1.25)**：Mate X7 展开 2416×2210 → ratio ≈ 1.093 居中；
   与阔直屏比例带 (1.4, 1.85)、普通手机 (≥2.1) 均隔出 ≥0.3 余量；
4. 不硬编码型号（同阔直屏教训：AL00/TL00 变体多，硬编码每出新机都要发版）；
   首判打一条 `[LARGEFOLD]` 探针日志（model/type/px/ratio/hit），真机到手核对后可补型号兜底；
5. 异常一律 false（安全方向 = 既有平板档，isWideFormDevice 对折叠屏恒 true 兜底）。

翻档机制：折叠↔展开由 `display.on('change')` / 各页 onAreaChange 触发重渲染，函数实时求值自动切档。

## 三、旋转解锁（entryability/EntryAbility.ets）

窗口就绪后的 `setPreferredOrientation(AUTO_ROTATION)` 条件由 `isWideBarDevice()` 放宽为
`isWideBarDevice() || isLargeFoldDevice()`——大折叠展开态要横 3 列，必须解锁旋转（跟随重力、
不受系统自动旋转开关限制）；折叠态不命中，回归默认 unspecified 行为。

## 四、多列页列数口径（竖 2 / 横 3，2026-09-17 改定）

用户两轮拍板：初版（09-15）竖横均 3；**09-17 改定竖屏 2 列、横屏 3 列（与阔直屏横屏同口径）**，
分支插在各列数函数**阔直屏分支之后、宽度闸门之前**（继承"形态闸门放首行"纪律）：

| 页面 | 列数函数 | 说明 |
|---|---|---|
| 首页 HomeTab | `updateColumns()` + `homeColumns()` | `isLargeFoldDevice() ? 3`（columns 模板三元表达式天然含 3 列档 `'1fr 1fr 1fr'`）；cardColumns 同步下发 3（卡宽 ≈(690−32)/3 ≈ 219 < 240，ThreadCard 紧凑胶囊自动生效） |
| 进吧 ForumsTab | `forumColumns()` | 吧列表 Grid |
| 收藏 Favorite | `favColumns()` | 吧分类 / 自定义分类 / 打开列表 / 收藏搜索态共用 |
| 消息 MessagesTab | `notifyColumns()` | |
| 我的帖子/收藏/点赞/浏览历史 PersonalContent | `pcColumns()` | 四个子页共用 |
| 他人信息页 UserProfile | `profileColumns()` | 帖子区 / 点赞区 |
| 吧主页（含吧搜索态）ThreadList | `threadColumns()` | cardColumns 经 syncCardColumns 无条件下发 |
| 首页全局搜索 Search | `searchColumns()` | 搜吧 / 搜贴 / 搜人共用 |

已按用户确认覆盖「帖子列表页」（吧主页 ThreadList，含吧搜索态）。

## 五、帖子详情页 / 楼中楼（ThreadDetail / SubPostDetail）

采平板方案、**回复区恒 1 列**：

- `replyColumns()` 大折叠分支 **横竖屏均 2 列瀑布流**（2026-09-16 用户改定，初版恒 1 留档；平板维持 3 不动）；
- **主楼卡与回复卡等宽**（2026-09-16 用户拍板）：分栏左栏宽由固定 420 改为 `splitMainWidth()` = **屏宽/3**——
  推导：主楼卡宽 = L−24（左 16/右 8 内距），回复每列 = (R−24−12)/2，R = W−L−12，两者相等 ⇔ L = W/3
  （回复列缝 12 恰好凑平）；横竖屏同口径，currentWidth 未就绪回退 420，平板/大屏维持 420；
- **宫格图片不拉伸**（2026-09-16 用户拍板）：分栏后格宽骤降（~50-75vp）而格高恒 120 会把图拉成细条 →
  `gridCellHeight()` 大折叠档格高收至 **72**（宽高比与手机档 94.7/120≈0.79 同档），横竖屏统一；
  主楼/楼层/楼中楼三处 ImageGrid 共用；其它形态 120 不变；
- **横屏分栏保留**：`splitMode()` 大折叠档改为**横竖屏均分栏**（2026-09-16 用户拍板：竖屏也用
  与横屏一样的分栏方式）——展开态近方形、竖屏宽 ≥600 与横屏同级，左栏固定 420
  （DETAIL_MAIN_WIDTH 同款）、右栏回复单列；折叠态外屏窄走原路径单列；
- 竖屏分栏下回复单列（原手机结构逐像素）；
- **底部评论输入岛**：`dockPillWidth()` 大折叠档改为与「跳转到贴吧官方」弹窗同宽
  （`dialogCardWidth()` 口径，400 封顶，2026-09-15 用户拍板），横竖屏同值；
  平板维持 592 档（DETAIL_DOCK_TABLET_WIDTH）、手机「屏宽−64」公式不动；
  SortPillShell 排序壳定位公式与 ReplyControls 宽度均经 `dockPillWidth()` 单点自动跟随。

## 六、底栏限宽与弹窗不拉伸（用户拍板）

### 底栏
- **宿主底栏 Index.ets**：`isWideScreen` 闸门由 `width >= 840` 放宽为
  `width >= 840 || isLargeFoldDevice()`——大折叠展开态（≈690vp 宽，本就 <840）并入平板档：
  官方悬浮槽与 API<26 兜底 BottomBar 大折叠档宽 **400 = 与置顶弹窗（dialogCardWidth 400 封顶）同宽**
  （2026-09-15 用户两次调整定稿：初版 480 → 用户反馈偏宽改 320 → 终版对齐弹窗 400，横竖屏同值；平板维持 480）、
  底栏几何走平板档；折叠态 isLargeFoldDevice 为 false，回落手机档通栏不变。
- **他人信息页 UserProfile**：底部官方悬浮条 `pillWidth()` 同步加 `|| isLargeFoldDevice()` 限宽；
  2026-09-16 用户拍板宽度对齐黑名单弹窗（overlayCardWidth 口径）→ 大折叠档 **400**（横竖屏同值）；平板维持 480。
- **无需改动**（既有上限已覆盖）：Search 模块底栏 `pillWidth()` 已对大屏档封顶 480；
  ThreadList 底部排序栏 `sortBarWidth()` 已锁 244（§4.8 T-F）。

### 弹窗
- **CustomDialog 类**（吧更多面板 / 跳转确认 / 一键签到 / 长按菜单 / 收藏六弹窗）：既有
  `dialogCardWidth()` 已 400 封顶，零改动 ✔。
- **页面主体自绘确认卡**（原 `calc(100% - 48vp)` 通栏，共 6 处 7 个）：改走 Theme 新增
  `overlayCardWidth()`——大折叠档收 **400vp 封顶**（屏宽不足 448 时按 屏宽−48、下限 200），
  其它形态原样返回 calc 字符串逐像素不变：
  ThreadDetail 链接确认卡 / SubPostDetail 链接确认卡 / ForumsTab 删除足迹卡 /
  FollowList 取关确认卡 / BlacklistManager 两处（解除拉黑、屏蔽设置）。
- **bindSheet 半模态**（Favorite 排序面板、移入分类）：SheetOptions **无 width 字段**，
  宽度由系统按设备规格决定，代码无法直接限宽——真机若观感通栏，备选方案为
  ①改 `preferType: SheetType.CENTER` 居中卡形态，②回退自绘浮层（可走 overlayCardWidth 限宽）。
  挂真机门 L-F1。

## 七、改动清单

| 文件 | 改动 |
|---|---|
| common/Theme.ets | +`isLargeFoldDevice()`、+`logLargeFoldProbe()`、+`overlayCardWidth()` |
| entryability/EntryAbility.ets | 旋转解锁条件放宽 |
| pages/Index.ets | isWideScreen 闸门并入大折叠（底栏限宽 480） |
| pages/HomeTab.ets | updateColumns / homeColumns 大折叠 3 列 |
| pages/ForumsTab.ets | forumColumns 3 列 + 删除足迹卡限宽 |
| pages/Favorite.ets | favColumns 3 列 |
| pages/MessagesTab.ets | notifyColumns 3 列 |
| pages/PersonalContent.ets | pcColumns 3 列 |
| pages/UserProfile.ets | profileColumns 3 列 + pillWidth 限宽 480 |
| pages/ThreadList.ets | threadColumns 3 列 |
| pages/Search.ets | searchColumns 3 列 |
| pages/ThreadDetail.ets | replyColumns 1 列 + 链接确认卡限宽 |
| pages/SubPostDetail.ets | replyColumns 1 列 + 链接确认卡限宽 |
| pages/FollowList.ets | 取关确认卡限宽 |
| pages/BlacklistManager.ets | 两处确认卡限宽 |

## 八、强制七步自检（§6.2 纪律，本次留痕）

1. **列宽来源**：✔ 全部列宽走既有 Grid columnsTemplate `1fr×n` / lanes，零像素列宽；新增分支只改列数不改容器。
2. **左右外边距单一来源**：✔ 未新增任何局部留白；overlayCardWidth 只改宽度不改边距。
3. **通栏项不入网格**：✔ 无新增网格项。
4. **末行补空位**：✔ 大折叠沿用各页既有 colIndexes/补空位机制，列数恒 3 在 2/3/4 档能力内。
5. **定高容器文本截断**：✔ 零新文本容器。
6. **形态判定单一函数+单一挂点**：✔ 判定单一来源 isLargeFoldDevice；各页列数函数单挂点插入；底栏唯一挂点 Index onAreaChange（H-A 首帧初值问题为既有全局项，不在本档新增范围）。
7. **手机 / 其它形态回归**：见下表 D 类。

### 风险表（A 错位 / B 出屏 / C 重叠 / D 手机回归）

| 类 | 编号 | 风险 | 规避 | 状态 |
|---|---|---|---|---|
| A | L-A1 | 大折叠 3 列下卡片内元素错位 | 复用 ThreadCard cardColumns 紧凑档（卡宽 ≈219<240 自动收紧）；无新容器 | 低，挂真机 |
| B | L-B1 | 3 列列宽 1fr 无出屏可能 | 列宽全 1fr/lanes | 已规避 |
| C | L-C1 | ThreadDetail 横屏分栏 + 右栏单列（阔直屏同组合）是否复现跳楼落点偏移 | 与阔直屏终版同口径，真机核一次 | 挂真机门 |
| C | L-F1 | bindSheet 半模态大折叠宽度不可控（系统决定） | 无 width 字段；备选 CENTER / 自绘浮层 | 挂真机门 |
| C | L-F2 | `[LARGEFOLD]` 探针校准：真机实测展开态 ratio 与折叠态回落路径 | 真机到手先看日志再收比例带/补型号兜底 | 挂真机门 |
| D | L-D1 | 手机 / 平板 / 2in1：isLargeFoldDevice 对非折叠设备首行 `!isFoldable()` 即 false，所有新分支不进，路径逐字节不变 | 判定首行闸门 | 已规避 |
| D | L-D2 | 阔直屏（Pura X）：isPuraXFoldModel 排除 + isWideBarDevice 折叠分支先行 return，不受影响 | 判定互斥 | 已规避 |
| D | L-D3 | 大折叠折叠态：非 EXPANDED → false，落既有宽度闸门回 1 列（与 Pura X 折叠态同路径） | 既有闸门 | 已规避 |
| D | L-D4 | Index isWideScreen 并入大折叠后，其它引用点（pillWidth/几何/兜底 BottomBar 宽）在手机/平板上取值不变（840 判定先行） | 短路或表达式不变 | 已规避 |

必测路径：手机竖屏/横屏回归、平板竖 3 横 4 回归、Pura X 竖 2 横 3 回归、
大折叠展开（竖 3 横 3 + 底栏 480 + 弹窗 400 + 横屏分栏回复 1 列）、
大折叠展开↔折叠翻档（3 列↔1 列、底栏 480↔通栏）。

## 九、留痕记录

| 日期 | 内容 | 自检结论 |
|---|---|---|
| 2026-09-15 | **大折叠适配首轮落地**（Theme 判定 + 旋转解锁 + 8 列数页竖横均 3 + 详情页/楼中楼回复恒 1 + 横屏分栏保留 + Index/UserProfile 底栏限宽 480 + 6 处自绘弹窗卡 400 封顶 + overlayCardWidth 助手；bindSheet 无 width 字段挂真机门 L-F1）。`tools/build.ps1` → **BUILD SUCCESSFUL** | A 错位：无（零新容器，复用既有 3 列档与 ThreadCard 紧凑胶囊）。B 出屏：无（列宽全 1fr/lanes）。C 重叠：2 处挂真机门（L-C1 横屏分栏组合、L-F1 半模态宽度）+ L-F2 探针校准。D 手机回归：无（非折叠设备判定首行即 false，平板/阔直屏/手机路径逐字节不变；必测 = 四形态回归 + 展开↔折叠翻档） |
| 2026-09-15 | **大折叠展开底栏收窄**（用户真机反馈「底栏有点宽」）：首页宿主底栏大折叠档 480 → 320（缩小三分之一，横竖屏同值），官方悬浮槽 `pillWidth()` 与 API<26 兜底 BottomBar `.width()` 两处同步；平板 480、UserProfile 悬浮条 480 不动。`tools/build.ps1` → **BUILD SUCCESSFUL** | A 错位：无（仅宽度数值收窄，5 项均分 layoutWeight(1) 自适应，无新容器）。B 出屏：无。C 重叠：无（320/5=64 每项，图标+文字仍容得下，真机复核字号观感）。D 手机回归：无（平板/手机判定路径零变化，isLargeFoldDevice 对非折叠恒 false；必测 = 大折叠横竖屏底栏观感 + 手机平板底栏不变） |
| 2026-09-15 | **大折叠底栏宽度终版对齐弹窗**（用户拍板）：首页底栏大折叠档 320 → **400 = 置顶弹窗同宽**（dialogCardWidth 400 封顶口径），横竖屏同值，官方悬浮槽 + API<26 兜底两处同步；平板 480、UserProfile 悬浮条 480 不动。§6 口径同步（320 为中间版留档）。`tools/build.ps1` → **BUILD SUCCESSFUL** | A 错位：无（仅宽度数值，5 项均分自适应）。B 出屏：无。C 重叠：无（400/5=80 每项，余量充足）。D 手机回归：无（非折叠设备 isLargeFoldDevice 恒 false，判定路径不变；必测 = 大折叠横竖屏底栏观感） |
| 2026-09-15 | **详情页底部评论岛对齐弹窗**（用户拍板）：ThreadDetail `dockPillWidth()` 大折叠档改为与「跳转到贴吧官方」弹窗同宽（dialogCardWidth 口径，400 封顶），横竖屏同值；平板 592 档、手机「屏宽−64」公式不动；SortPillShell 排序壳定位与 ReplyControls 宽度经 dockPillWidth 单点自动跟随。SubPostDetail 无底栏岛，不涉及。`tools/build.ps1` → **BUILD SUCCESSFUL** | A 错位：无（仅宽度数值，岛内跳转框 layoutWeight(1) 自动拉伸）。B 出屏：无。C 重叠：无（排序壳 padding-left = (屏宽−400)/2−横屏修正 自动重算，真机复核左对齐观感）。D 手机回归：无（isLargeFoldDevice 对非折叠恒 false，手机/平板路径逐字节不变；必测 = 大折叠横竖屏底栏 + 排序壳左对齐） |
| 2026-09-15 | **大折叠横屏排序壳左对齐修正**（用户真机反馈「正序/只看全部按钮太靠左、超出底栏」）：SortPillShell 定位公式的 −40 横屏分栏修正（平板 592 底栏的系统偏差校准值）对大折叠不适用——大折叠底栏 400 下纯公式定位已精确对齐底栏左缘，再减 40 会把排序壳推出底栏外；改为 `splitMode() && !isLargeFoldDevice()` 才套用修正。竖屏不受影响（本就无修正）。`tools/build.ps1` → **BUILD SUCCESSFUL** | A 错位：无（仅定位公式条件收窄，壳/胶囊几何零改动）。B 出屏：修正（大折叠横屏排序壳回到底栏左缘内，即本次修复项）。C 重叠：无（padding-left ≥0 兜底不变）。D 手机回归：无（手机竖屏无修正、平板路径 splitMode && !isLargeFold 条件下与改动前等价；必测 = 平板横屏分栏排序壳位置不变 + 大折叠横屏左对齐） |
| 2026-09-15 | **大折叠横屏排序壳下移贴底栏**（用户真机反馈「离底栏太远」）：SortPillShell 底距在横屏分栏下追加的 14vp 呼吸（平板真机校准值）对大折叠不适用——其底栏 400 较矮，与竖屏同距即可；改为 `splitMode() && !isLargeFoldDevice()` 才套用，大折叠横屏排序胶囊下移 14vp 与竖屏间距一致。`tools/build.ps1` → **BUILD SUCCESSFUL** | A 错位：无（仅底距条件收窄，壳/胶囊几何零改动）。B 出屏：无。C 重叠：修复（排序胶囊与底栏间距回到竖屏口径；若仍嫌远可再减 dockBottomMargin 分量，微调点唯一）。D 手机回归：无（平板路径条件下与改动前等价、竖屏无该项；必测 = 平板横屏分栏排序壳底距不变 + 大折叠横屏间距观感） |
| 2026-09-15 | **大折叠底栏岛内垂直留空拉平**（用户真机反馈「横竖屏均上面留空多于下面」）：CommentBar 岛内路径的垂直补偿（抵消官方悬浮岛「上多下少」系统留白）原两端统一 bottom 8 为平板/手机校准值，大折叠上系统留白差更大、8 不够 → 大折叠档补偿加大到 **16**（内容再上移 4vp 拉平上下留空），手机 / 平板维持 8 不变；微调点唯一（该常量）。`tools/build.ps1` → **BUILD SUCCESSFUL** | A 错位：无（仅岛内 padding 数值，内容元素几何零改动）。B 出屏：无。C 重叠：无（内容行高 42/46 < 66−16 容器，无裁切）。D 手机回归：无（isLargeFoldDevice 对非折叠恒 false，手机/平板取值 8 与改动前逐字节等价；必测 = 大折叠横竖屏底栏内部上下留空观感） |
| 2026-09-15 | **大折叠岛内跳转/发送元素垂直拨正**（用户真机反馈「点赞/收藏已中线，发送钮与跳转官方胶囊仍偏上」）：CommentBarBody 中跳转胶囊（46 高 Row）与发送钮（42 高 Button）加 `.offset(y: islandNudge())`，大折叠档 = **4**（往下拨，用户确认两元素同向偏上）、其它形态恒 0 逐像素不变；offset 不参与布局不影响点按区，微调点唯一（islandNudge 常量）。`tools/build.ps1` → **BUILD SUCCESSFUL** | A 错位：无（仅视觉偏移，布局/点按区不变）。B 出屏：无。C 重叠：无（下移 4 仍在 66−16 容器内，无裁切）。D 手机回归：无（非折叠 islandNudge 恒 0，offset 0 无渲染差异；必测 = 大折叠横竖屏四元素中线观感） |
| 2026-09-15 | **大折叠竖屏首页底栏收一档**（用户真机反馈「底栏内部偏高、图标文字上下留空偏多」；横屏正常不调）：Index 几何取值族（barHeight/barRadius/itemHeight/itemRadius/padV）新增大折叠竖屏档——`isLargeFoldPortrait() = isLargeFoldDevice() && !isWideLandscape()` 命中，取值 66/33/54/27/4（= 手机档与平板横屏档同款，上下留白 14→10）；平板竖屏 74/37/58/29/6、大折叠横屏 62/31/50/25/4、手机 66/33/54/27/4 全部不动。`tools/build.ps1` → **BUILD SUCCESSFUL** | A 错位：无（仅数值档位，五值成套联动，条目圆角=条目高/2 口诀保持）。B 出屏：无。C 重叠：无（Glow 高度自动跟随条目高）。D 手机回归：无（平板/手机/大折叠横屏判定路径与取值逐字节不变；必测 = 大折叠竖屏底栏观感 + 大折叠横屏与平板竖屏不变） |
| 2026-09-15 | **大折叠详情页评论岛收一档**（用户真机反馈横竖屏均「岛内部偏高、图标文字上下留空偏多」）：`dockPillHeight()` 大折叠 66 → **62**（平板/手机维持 66）；CommentBar 岛内 `.height(66)` 改引 `dockPillHeight()` 单点（消双 66 漂移），垂直补偿 16 → **12**——内容区 62−12=50 与改前 66−16=50 完全一致，元素相对内容区位置零变化、仅岛更紧凑（下沿空 20→16）；SortPillShell 底距经 dockPillHeight 自动跟随 62。`tools/build.ps1` → **BUILD SUCCESSFUL** | A 错位：无（岛高与补偿成套联动，内容区不变）。B 出屏：无。C 重叠：无（内容最高 46 < 50 内容区）。D 手机回归：无（非折叠 dockPillHeight 恒 66、padding 恒 8，逐字节等价；必测 = 大折叠横竖屏岛观感 + 排序壳底距 + 平板手机岛不变） |
| 2026-09-15 | **岛内跳转/发送拨正量归零**（用户真机反馈岛高收档后两元素转为偏下）：62 岛下官方系统留白同步收，原 +4 拨正过调 → `islandNudge()` 归 **0** 回归纯公式居中；offset 机制与两处调用点保留（偏上为正/偏下为负，微调点唯一）。`tools/build.ps1` → **BUILD SUCCESSFUL** | A 错位：无（offset 0 无渲染差异）。B 出屏：无。C 重叠：无。D 手机回归：无（非折叠恒 0 与改前等价；必测 = 大折叠横竖屏四元素中线观感） |
| 2026-09-16 | **他人信息页底栏对齐黑名单弹窗**（用户拍板）：UserProfile `pillWidth()` 大折叠档 480 → **400**（= 黑名单弹窗 overlayCardWidth 口径），横竖屏同值；平板 480、手机通栏、折叠态手机档均不变。`tools/build.ps1` → **BUILD SUCCESSFUL** | A 错位：无（仅宽度数值，内部条目均分自适应）。B 出屏：无。C 重叠：无。D 手机回归：无（非折叠 isLargeFoldDevice 恒 false 取值不变；必测 = 大折叠横竖屏底栏观感） |
| 2026-09-16 | **吧主页吧头签到钮右对齐**（用户拍板「仅动签到钮」）：根因 = 吧头行 `layoutWeight(1)+maxWidth 220` 组合下进度条被钳宽后剩余空间**不回流**给弹性 Blank，签到钮只能贴进度条右缘；大折叠档（`isLargeFoldHeaderRow()` = isLargeFoldDevice && threadColumns>1）进度条改定宽 220（minWidth=maxWidth）+ weight 0，既有 Blank 真正吃掉剩余空间把签到钮推到信息列右缘。经验条视觉宽 220 不变、单列手机无 Blank 行为不变、平板/阔直屏多列档维持 weight 分配逐像素不变。`tools/build.ps1` → **BUILD SUCCESSFUL** | A 错位：无（仅进度条宽度实现方式变化，视觉宽一致）。B 出屏：无。C 重叠：无。D 手机回归：无（isLargeFoldHeaderRow 对非折叠恒 false，单列/平板/阔直屏路径逐字节等价；必测 = 大折叠横竖屏签到钮贴右 + 平板吧头不变） |
| 2026-09-16 | **吧头经验条锁宽不拉伸**（用户真机反馈）：进度条 Stack 原 `.width('100%')` 引用父列宽，在 Column 的 weight/约束组合下 100% 可能跟随可用宽 → 大折叠档改显式定宽 `width(220)`（isLargeFoldHeaderRow 三元），灰底条与前景填充一并锁死；其它形态维持 100% 逐像素不变。`tools/build.ps1` → **BUILD SUCCESSFUL** | A 错位：无（仅宽度数值来源变化）。B 出屏：无。C 重叠：无。D 手机回归：无（非折叠走 100% 原路径逐字节等价；必测 = 大折叠横竖屏经验条 220 观感 + 手机平板不变） |
| 2026-09-16 | **详情页竖屏启用左右分栏**（用户拍板「竖屏也改用跟横屏一样的分栏方式」）：ThreadDetail `splitMode()` 大折叠档 = `currentWidth >= Breakpoint.sm`（不再要求 isLandscape），竖屏展开宽 ~630 ≥600 命中——左栏固定 420（DETAIL_MAIN_WIDTH 与横屏同款）、右栏回复单列（replyColumns 恒 1）；isSplit 缓存 + applySplitSwitch 三段动画自动适配（竖屏冷启动首帧直接分栏）；SortPillShell 的 −40/−14 平板横屏校准对大折叠本就排除，定位公式自动适配竖屏分栏；折叠态外屏窄走原路径单列。楼中楼 SubPostDetail 不涉及（用户未点名）。`tools/build.ps1` → **BUILD SUCCESSFUL** | A 错位：无（复用既有分栏结构，零新容器）。B 出屏：无（左栏 420 + 右栏 ~210，1fr 布局）。C 重叠：1 处挂真机门——竖屏分栏右栏较窄（~210vp）回复单列卡观感，以及分栏下跳楼落点/消息定位；D 手机回归：无（isLargeFoldDevice 对非折叠/折叠态恒 false，原 isLandscape 路径逐字节等价；必测 = 大折叠竖屏分栏观感 + 手机/平板/横屏不变） |
| 2026-09-16 | **详情页回复区改 2 列瀑布流**（用户拍板「竖屏和横屏的回复区域都改成两列瀑布流」）：ThreadDetail `replyColumns()` 大折叠分支由恒 1 改为恒 **2**（横竖屏同值；平板维持 3 不动；阔直屏恒 1 不变）；复用既有 FloorColumnsBlock 列均衡瀑布流（DETAIL_COL_BALANCE_THRESHOLD 机制通用），无新容器。`tools/build.ps1` → **BUILD SUCCESSFUL** | A 错位：无（既有 2 列能力档，列均衡阈值 240 通用）。B 出屏：无（列宽 1fr）。C 重叠：挂真机门——竖屏分栏右栏 ~210vp 下 2 列每列 ~95vp 偏窄、跳楼落点/消息定位在 2 列瀑布流下的落点精度；D 手机回归：无（isLargeFoldDevice 对非折叠/折叠态恒 false，手机 1 列/平板 3 列路径逐字节等价；必测 = 大折叠横竖屏回复 2 列观感 + 手机平板不变） |
| 2026-09-16 | **详情页主楼卡与回复卡等宽**（用户拍板「帖子区域的卡片宽度要跟回复区域卡片一致」）：新增 `splitMainWidth()`——大折叠档分栏左栏宽 = **屏宽/3**（数学推导：主楼卡宽 = L−24，回复每列 = (R−24−12)/2，R = W−L−12，相等 ⇔ L = W/3，左右内距 16+8/8+16 与分栏缝 12、回复列缝 12 恰好对称抵消），横竖屏同口径、currentWidth 未就绪回退 420；平板/大屏维持 420。左栏 Scroll `.width(DETAIL_MAIN_WIDTH)` 改调 `splitMainWidth()` 单点。`tools/build.ps1` → **BUILD SUCCESSFUL** | A 错位：无（仅左栏宽度数值，三等分下主楼/回复卡同宽对齐）。B 出屏：无。C 重叠：无（右栏 2 列自动均分剩余）。D 手机回归：无（非折叠 splitMainWidth 恒 420 与改前等价；必测 = 大折叠横竖屏主楼/回复卡等宽观感 + 平板 420 不变） |
| 2026-09-16 | **详情页宫格图片不拉伸**（用户拍板「帖子区域和回复区域的宫格图片都不要拉伸」）：根因 = ImageGrid 格高恒 120，分栏三分屏后格宽骤降（主楼/楼层/楼中楼卡内容宽 ~150-240 → 每格 ~50-75vp），图片被拉成细条；新增 `gridCellHeight()` 大折叠档格高收至 **72**（宽高比 0.76~1.04，与手机档 94.7/120≈0.79 同档），横竖屏统一；主楼/楼层/楼中楼三处 ImageGrid 共用单点。`tools/build.ps1` → **BUILD SUCCESSFUL** | A 错位：无（Grid 显式总高公式同步分档，无测量歧义）。B 出屏：无。C 重叠：无。D 手机回归：无（非折叠 gridCellHeight 恒 120 逐字节等价；必测 = 大折叠横竖屏宫格观感 + 手机平板不变） |
| 2026-09-17 | **大折叠竖屏多列页改 2 列**（用户拍板「竖屏状态改成两列」，横屏维持 3 列）：8 个列数页大折叠分支由恒 3 改为 `isLandscape ? 3 : 2`（HomeTab 经 updateColumns 按 w>h 写 this.columns，与平板同口径合并为 `(w>h?3:2)`；ForumsTab / PersonalContent / UserProfile / ThreadList / Search 走 isLandscape 字段，Favorite / MessagesTab 走 isLandscape() 方法）——首页、进吧、收藏页（含吧分类/自定义分类/打开列表/收藏搜索态）、消息页、我的帖子/收藏/点赞/浏览历史、他人信息页、吧主页（含吧搜索态）、全局搜索全覆盖。cardColumns=2 下卡宽 ~329 > 240 ThreadCard 紧凑胶囊自动不触发；HomeTab 列模板三元天然含 2 列档；小窗/分屏窄窗闸门（<600 回 1）在大折叠分支之前不受影响。`tools/build.ps1` → **BUILD SUCCESSFUL** | A 错位：无（复用既有 2 列档）。B 出屏：无。C 重叠：无。D 手机回归：无（isLargeFoldDevice 对非折叠/折叠态恒 false，各页原路径逐字节等价；必测 = 大折叠竖屏 2 列/横屏 3 列 + 展开↔折叠翻档 + 手机平板阔直屏不变） |
