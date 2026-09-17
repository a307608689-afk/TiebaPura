# TiebaPura 平板适配

> 交付类型：适配方案文档（以产出方案为主；截至目前**已执行**：§4.6 H-F 死代码清理、§4.2 首页布局改造**落地并构建通过**（2026-09-13）；其余各节布局改动仍未开工）
> 版本：v1（草稿）
> 更新：2026-09-12 · §4.5 我的页新增适配方案（**待确认**，含 4 个待拍板点）；§4.4 消息页 **方案 A（`Scroll` + `Column` 内按行分组，不换容器）已拍板**；§4.3 改动六「候选收敛」小节（**方案一 / 方案三**留档待定）；**§4.6 宿主壳（`pages/Index.ets`）平板适配方案（已确认，3 个待拍板点已收敛：H-C 维持 480 零改动 / H-B 并入 `Theme.ets` / H-D 动态取并复用 `UserProfile` 既有安全区实现）**；**§六 补齐「重叠 / 错位 / 出屏」防御与验收清单，并新增 §6.2「文档更新自检流程」（强制，此后每次界面文档更新都先过六步自检并留痕）**；**§三 第 7 项改名「全吧搜索（首页入口）」并加命名澄清（区分页内搜索状态），§4.6 新增 H-F 死参数 / 死通道清理项（非布局，不阻塞已确认）**；**H-F 已于同日执行：`HomeTab.ets` / `Index.ets` / `Favorite.ets` 三处死代码删除，全工程检索 0 残留、lint 无新增诊断**；**§4.7 全吧搜索（`pages/Search.ets`）平板适配方案（已确认，5 个待拍板点已于同日收敛：横屏搜索框封顶 `Content.maxWidth = 1000vp` 居中 / 横竖屏判据用宽高比 / 搜贴用行数启发式估算 / 搜吧搜人顺序均分 / 窄列截断），§6.1 范围提醒同步把 `Search` 改为「例外做多列」**；**§4.7 已补记「前置依赖」小节：`Breakpoint.md` / `Content.maxWidth` 待 §4.6 H-B 落地，本节方案确认后暂不开工；§4.6 H-B 反向加「被依赖方提示」**；**§4.2 首页方案 5 点收敛（选型 A `WaterFlow` / 口径统一于判据层、不统一容器层 / 渐隐带夹取 `min(max(视口高×0.15,108),180)` / 卡片几何比例化限多列档生效 / §1.6 `deviceTypes` 前置 + 上架后台联动），§三 第 1 项转「已确认」，并设 `WaterFlow` 真机 A/B 门**；**§4.2 剩余两点补拍板（2026-09-12）：口径统一取「判据层统一」最优解（§4.2 决策 7，§4.6 H-B 据此升格为全局判据唯一收口点）；`deviceTypes` 处置定案（加 `"tablet"`、不加 `"2in1"`、不启用 EasyGo、上架后台联动 + 整体验收，见 §1.6），仍不开工**；**§4.6 新增 H-G「形态切换观感」：横竖屏切换**无过渡动画**为既定取舍（列数模板不可补间），三项增强已于同日**按推荐定案**（H-G-1 判据防抖采纳、并入 H-A / H-B 一次落地 / H-G-2 滚动锚定挂等效触发门 / H-G-3 单帧遮盖不做；观感项、非布局，不阻塞 H-A / H-B / H-D）**；**H-G-2 的门已改为「等效触发路径」（折叠屏展开旋转 / 模拟器 Tablet / 代码级量化 / 自由多窗拖宽，四路不通则按确定性推定兜底），并写明手机因「非大屏形态」无法复现列数变化、其它 App 的横竖屏素材对本门无效**；**H-G-2 随即由用户于同日拍板「直接走兜底推定」→ 按确定性推定**定案采纳**，状态由「条件确认」转「已确认（推定采纳）」，不再以实测为前置门，§4.7 风险 1 实测降级为**落地后复测项**，§4.6 表格 / 状态行 / 风险与回归项 / 风险自检 / 另列 / 涉及改动点与 §4.7 同步**。布局改动（H-A / H-B / H-D）未动。
> 更新：2026-09-13 · **§4.8 吧内帖子列表（`pages/ThreadList.ets`）平板适配方案（已确认，选型 A「行分组」与 §4.4 同款，不换滚动容器；用户同日拍板）**；吧信息区「单列 + 头像/吧名/经验条左对齐 + 签到钮右对齐」经核实**现状已满足、几何零改动**（T-A）；帖子区与**本吧搜索态**均做多列（手机 1 / 平板竖 2 / 横 3），末行补等宽空位，`ThreadCard` 走 §4.2 决策 6 的 `cardColumns` 全局标记（本页 2 处调用点零改动）；滚动架构（`contentH` 测量 / 预加载判据 / 排序切换快照裁剪 / `onReachEnd` / 沉浸 `overlay`）**零改动**；§三 第 8 项转「已确认」，§6.1 范围提醒把 `ThreadList` 同步为**第二个多列例外页**（含 A2 / C2 表项），§6.2 二级页清单与已过检记录同步。**仍不开工**：受前置依赖阻塞（判据令牌待 §4.6 H-B、`cardColumns` 待 §4.2 决策 6）。另记一条**口径待收口项**：§4.2 / §4.4 用「`isWideFormDevice && pageWidth ≥ 600`」判多列档、§4.7 用「`pageWidth ≥ 840`」，两套阈值在折叠屏展开 750 一类形态上结论不同 → §4.8 不新增第三套，采用首页 / 消息页同款，§4.7 是否收敛记入 H-B 落地时的统一项。**手机端零回归已逐项核对：结论不影响**（三条硬约束已写进 §4.8：① `cardColumns` 必须无条件写 1、不能只在多列时写；② 列 = 1 时禁止套行分组容器，T-C / T-D / T-E 三处都要显式分支；③ `ThreadListSkeleton` 的 `columns` 默认 1 —— 该组件 5 处调用点跨 3 页，`UserProfile` 两处属单列二级页须保持现状）。**同日（用户要求「每次更新文档都进行这项检查」）把「手机端零回归核对」固化为强制自检：§6.1 新增 D 类表（D1~D6，章节标题加入「手机回归」）、§6.2「自检六步」升级为「七步」（第 7 步 = 会不会影响手机正常布局）、留痕模板新增 `D 手机回归` 行、结论挂钩表新增 D 档、二级页同样须过第 7 步。**
> 更新：2026-09-13 · **§4.9 帖子详情（`pages/ThreadDetail.ets`）平板适配方案（2026-09-13 用户按推荐值拍板 → 已确认，本轮不开工）**：**竖屏** = 主楼满宽 + 回复区两列，**推「手写双列（列内独立堆叠）」而不是换 `WaterFlow`** —— 用户问的「跟首页一致」一致的是**观感**（列内独立堆叠、无行内对齐留白），而详情页换容器的代价与收益倒挂（`WaterFlow` 无 `header` 装不下主楼 / 楼层区本就是 `Scroll` + `ForEach` 全量渲染、换容器无虚拟化收益 / `overlay`-`blendMode`-`expandSafeArea`-定位锚点-`scroller` 全要重挂）；**横屏** = **左主楼 / 右回复两列分栏**（`layoutWeight 4 : 6`、左右双 `Scroll` 各自 `padding bottom 160`）；§三 第 9 项转「已出方案（待确认）」，§6.1 范围提醒新增**例外三**（`ThreadDetail` 移出「单列二级页」清单）并同步 C2 表项，§6.2 二级页清单同步、已过检记录追加一行。**手机端零回归已逐项核对：结论不影响**（形态闸门恒 1 列、不分栏、原 `ForEach` 一字不动、沉浸属性挂点不变）；**仍不开工**：受前置依赖阻塞（判据令牌待 §4.6 H-B）。4 个待拍板点：竖屏分列策略（**交替分列**）/ 骨架屏是否按列铺（**不做**）/ 横屏分栏比例（**4 : 6**）/ 横屏右栏窄列观感（**维持 2 列**、挂真机复核）—— **同日用户按推荐值全部拍板 → 状态转「已确认」**，并指示**楼中楼详情页沿用同一方案 → 新增 §4.10**。
> 更新：2026-09-13 · **§4.10 楼中楼详情（`pages/SubPostDetail.ets`）平板适配方案（待确认，与 §4.9 同款）**：竖屏 = 父楼层卡满宽 + 楼中楼回复两列（列内独立堆叠）；横屏 = 左父楼层 / 右回复两列分栏（`layoutWeight 4 : 6`）。本页结构与 §4.9 一一对应（`ParentFloor` ≈ `PostHeader`、回复表头 ≈ `ReplySectionHeader`、`CommentItems` ≈ 楼层区），故方案与理由全部复用，仅记**6 处差异（执行红线）**：① 底部留白维持 `Spacing.xl`(20)，**不是 §4.9 的 160**（用户 2026-09-11 真机拍板回退值，抄错会多 140vp 空白）；② 本页**无底部悬浮层** → 无 160 让位依据；③ 装饰层只需上移 `overlay(BottomFadeOverlay)` + `blendMode`（**无** `backgroundColor` / `opacity`，底色在根 `Stack` 上）；④ 遮罩是 `height('100%')` **整区**遮罩而非固定 88 高带；⑤ 间距语言 = 8（`Spacing.sm`），列间距 / 栏间距都取 8（§4.9 是 12）；⑥ **卡内 8vp 追加间距用全局下标判定 → 分列后每列末条也多留 8vp（列底空洞）**，须抽 `CommentCard(comment, index, total)` 改列内下标（A 类 1 处）。§三 第 10 项转「已出方案（待确认）」，§6.1 范围提醒新增**例外四**（`SubPostDetail` 移出「单列二级页」清单、共同点改四页）、§6.2 二级页清单与已过检记录同步。**手机端零回归已逐项核对：结论不影响**；**不开工**（受 §4.6 H-B 前置阻塞）。
> 更新：2026-09-13 · **§4.11 用户主页 / 个人内容页（`pages/UserProfile.ets`）平板适配方案（待确认）**：按用户指示「用户信息居中处理 + 下面内容竖屏两列、横屏三列」落地方案。① **范围判定**：全工程只有本页有「用户信息」区（大头像 76 / 昵称 / `ID·性别·IP` / 简介 / 关注·粉丝·获赞统计）→ 本节即指它；§三 第 11 项 `PersonalContent.ets`（「我的帖子 / 点赞 / 收藏 / 历史」）**无用户信息区**、容器同为 `List`，若也做多列可直接套用本节范式（命名澄清已写入 §三 与 §6.2）。② **用户信息居中**：核实 `Header()`（685-762）**现状已是完全居中**（`Column` 默认居中 + 文字 `width('100%') + textAlign(Center)` + 统计行 `justifyContent(Center)`）→ 结论为**零改动 + 三条保真约束**（头部永留通栏、居中基准 = 内容区宽即左右 `Spacing.lg` 16 不动、横屏推荐不引入 `Content.maxWidth`）。③ **多列写法 = 第五个例外页、第三套写法**：容器**本来就是 `List`**（带 `scroller` + `onReachEnd`），故**保留 `List` + `.lanes(列数, Spacing.sm)` + 把 `Header` 与尾部 160 占位迁进 `ListItemGroup.header/footer`**（与 §4.3 收藏页同范式；不进列、也不换 `Scroll`/`WaterFlow`）→ 末行不满天然不拉伸、**无需 `blankSlots()`**。列数 = 手机 1 / 平板竖 2 / 平板横 3；复用既有 `currentWidth`（122）+ 新增 `pageHeight` / `isLandscape` / `isWideFormDevice` / `profileColumns()`，`onAreaChange`（540-544）同点回填、`aboutToAppear` 同步取首帧宽高（补 `display` import）——⚠️ `isWideScreen`（840，服务底栏胶囊 480 封顶）**不得**复用为列数判据，两套并存各司其职。④ **执行红线**：单列档（含手机）**走原裸 `ListItem` 结构、不套 `ListItemGroup`**（D2）；`List.sticky` **保持默认 `None`**（否则 `Header` 吸顶）；底部 160 占位随列数不变、**不用 `lanes` 第三参 `margin`**。⑤ **同步落点**：§三 第 11 / 12 项、§6.1 范围提醒**例外五** + 「多列写法共三套」选用口径 + A1 / A5 / A6 / C2 表项、§6.2 D3 行 + 二级页清单、已过检记录。**另记（非布局）**：`bottomSafeHeight`（119 / 178）全页无读取点 → 底部让位实际由固定 160 承担，清理属可选（H-F 类）。**自检留痕**：A **有 3 处**（通栏项只占 1 格 / 首帧列数跳变 / `lanes` 行内高度差留白 ≈ ≤38vp）、B **无**、C **有 1 处**（折叠展开横屏 750 下三列 ≈ 234vp 窄列截断，推荐接受并并入 §4.8 口径收口项）、D **无**（含两条落地验证项：`lanes(1)` 等价性、`ListItemGroup` 内行间距）。**手机端零回归已逐项核对：结论不影响**；**不开工**（受 §4.6 H-B 前置阻塞）。
> 更新：2026-09-13 · **§4.12 个人内容（`pages/PersonalContent.ets`）平板适配方案（待确认，与 §4.11 同范式 —— 用户拍板「两页采用同一方案」）**。① **范围**：本页 = 「我的」页三个入口（我的帖子 / 我的点赞 / 浏览历史）进去的内容归档页，**无用户信息区**（区别于 §4.11），故 §4.11 的「用户信息居中」三条约束在本页**不适用**，其余全盘复用；§4.11 标题同步收窄为「用户主页」（两页正式分节）。② **现状核实**：`List()` **无参数**（**无 `space`、无 `scroller`**），行间距由 `ContentCard` 自带 `.margin({bottom: Spacing.md})`(12) 承担；顶部让位 = 首项 `ListItem { Column().height(98) }` 空占位；**无尾部占位**（底部留白走 `List.padding` 的 `bottom Spacing.xl`(20)）；分页 = `onReachEnd` + `onScrollIndex`（距末尾 5 项预取）；4 个 mode（帖子 / 点赞 / 收藏 / 历史）共用同一个 `List`；三态是与 List **同级的分支**（天然通栏）；**无底部悬浮层**；**全文件无任何形态判定**（无 `pageWidth` / `isWideScreen` / `onAreaChange` / `deviceInfo` / `display`，检索 0 命中）→ 形态判定能力**从零建**。③ **写法 = 第三套的第 2 个实例**：容器本来就是 `List` → 保留 `List` + `.lanes(列数, Spacing.md)`（列间距 = 本页行间距 12，**与 §4.11 取 `Spacing.sm`(8) 不同源**，各与自身行间距同源）+ 顶部 98 占位迁 `ListItemGroup.header`（**通栏项只有 1 处**，§4.11 是 3 处）。④ **执行红线**：单列档走原裸 `ListItem` 结构、不套 `ListItemGroup`（D2）；`List.sticky` 保持默认 `None`；底部留白维持 **`Spacing.xl`(20)**（**不得照抄 §4.11 的 160**）；不用 `lanes` 第三参 `margin`；**不引入尾部占位**。⑤ **本页独有验证项**：`onScrollIndex` 的 `end` 在多列分支（child 由「98 占位 + N 个裸 `ListItem`」变为「1 个 `ListItemGroup`」）**是否仍为数据项索引**决定提前预取是否失效 → 若退化为组索引（恒 0），则只剩 `onReachEnd` 兜底（「滑到边界才加载」观感回归），须落地验证并备兜底写法。⑥ **同步落点**：§三 第 11 项、§4.11 标题与适用范围澄清、§6.1 **例外六** + A1 / A5 / A6 / C2 表项 + 「多列写法共三套」第 ③ 条、§6.2 二级页清单（底部让位数值清单扩为四页）+ 已过检记录。**自检留痕**：A **有 3 处**（通栏占位只占 1 格 / 首帧列数跳变〔本页无任何形态初值，不补必跳〕/ `lanes` 行内高度差留白 ≈ ≤38vp）、B **无**、C **有 1 处**（折叠展开横屏 750 三列卡内文本宽 ≈ 199vp → 底行长吧名挤压，`Row` 子项 `flexShrink 0` + 卡片无 `clip` + `List.clip(false)` → **溢出盖右列**；推荐规避 = 底行三 `Text` 补 `maxLines(1)` + `textOverflow`，吧名改 `layoutWeight(1)` 替 `Blank()`〔单列视觉等价〕）、D **无**（含三条落地验证项）。**手机端零回归已逐项核对：结论不影响**；**不开工**（受 §4.6 H-B 前置阻塞）。
> 更新：2026-09-13 · **§4.11 用户主页（`UserProfile.ets`）/ §4.12 个人内容（`PersonalContent.ets`）—— 用户「按推荐值拍板，后续有需要才改」→ 两节全部转「已确认」**，共 10 个待拍板点 + 5 条落地验证项按推荐定案：① **列数口径沿用 `600`**（不新增第三套；折叠展开横屏 750 下三列偏窄的观感并入 §4.8 已记的「两套阈值收口项」，**后续如需改 840 只改判据层一处**）；② **横屏头部不限宽居中**（不引入 `Content.maxWidth`，避免 A4 头部与卡片咬合错位）；③ **骨架屏不按列铺**（§4.11 两处 `ThreadListSkeleton` 保持 `count: 5` 单列，不加 `columns`）；④ **`lanes` 行内高度差留白接受**（≈ ≤38vp）；⑤ **列间距各同源于自身行间距** —— §4.11 取 `Spacing.sm`(8)、§4.12 取 `Spacing.md`(12)；⑥ **§4.12 窄列底行溢出（C3）走规避 ②** —— 底行三 `Text` 补 `maxLines(1)` + `textOverflow`、吧名 `layoutWeight(1)` 替 `Blank()`（单列视觉等价，须真机逐点复核）；⑦ **`lanes(1)` 等价性若失败 → §4.11 / §4.12 两页一起改「双 `List` 双分支」**（不出现一页一套写法）；⑧ **§4.12 `onScrollIndex` 预取若失效 → 多列分支放宽预取阈值**（宁可提前取，保 `onReachEnd` 兜底，避免「滑到边界才加载」的观感回归）。**手机端零回归沿用两节已核结论：不影响**（形态闸门恒 1 列含手机横屏 / 分屏 / 自由多窗；列 = 1 走原裸 `ListItem` 结构、不套 `ListItemGroup`；§4.11 两处骨架屏不加 `columns`、§4.12 无骨架屏；两页均不写 `cardColumns`）；§三 第 11 / 12 项转「已确认」、§4.11 / §4.12 待拍板点小节标题与状态行同步、§6.2 已过检记录追加一行。**仍不开工**：受前置依赖阻塞（判据令牌待 §4.6 H-B 落地）。
> 更新：2026-09-13 · **§4.10 楼中楼详情（`pages/SubPostDetail.ets`）按推荐确认 → 转「已确认」**（用户「按推荐确认」）：上表 #1~#5 全部按推荐采纳 —— 交替分列 / 骨架屏**不适用**（本页无骨架屏，日后若新增则 `columns` 默认必须 = 1）/ 分栏 **4 : 6** / 横屏右栏**维持 2 列**（挂真机复核）/ **抽 `CommentCard(comment, index, total)` @Builder（本页私有）** —— 用以消除「卡内 8vp 追加间距按全局下标判定 → 分列后每列末条多 8vp 的列底空洞」（A 类 1 处）。**三处本页专属差异仍为执行红线（非可选项）**：底部留白维持 `Spacing.xl`(20)（**不是 §4.9 的 160**，抄错会多 140vp 空白）、间距语言 8（列间距 / 栏间距都取 8）、装饰层只需 `overlay(BottomFadeOverlay)` + `blendMode` 两项（本页无 `backgroundColor` / `opacity`）。§三 第 10 项转「已确认」、§4.10 待拍板点表头（「结论」→「拍板结果」）与状态行同步、§6.2 已过检记录追加一行。**手机端零回归沿用已核结论：不影响**（恒 1 列 + 不分栏 + 原 `ForEach` 与间距判定一字不动 + 装饰层挂点不变；本页不写 `cardColumns`、`CommentCard` 为本页私有 Builder → 无 D1 / D3 / D6 残留面）。**仍不开工**：受前置依赖阻塞（判据令牌待 §4.6 H-B 落地）。
> 更新：2026-09-13 · **§4.2 首页真机首测：方案 A（`WaterFlow`）被否决 → 已改**方案 B（`Scroll` + `Column` 内按行分组，不换容器）**并构建通过**。用户真机反馈「横竖都有严重错位 + 图片过大」：① 错位 = `WaterFlow` 各列独立堆叠、行内无顶对齐，大图把相邻列落差进一步拉大；② 图片过大 = 多列列宽变宽后 `aspectRatio(1.6)` 等比放大图高。**执行内容**：`HomeTab.ets` 两条 feed 由 `WaterFlow + FlowItem` 回退为 `Scroll + Column`，多列档新增行分组 `homeRows()` / `homeRowBlanks()` / `homeRowKey()`（末行补等宽 `Blank`，§6.1 A2），**单列档显式走原 `ForEach` 逐像素不变**（§4.8 硬约束②）；预加载判据由 `onScrollIndex` 回退为 `onAreaChange` 量内容高（`HOME_PREFETCH_DISTANCE = 1200`，恢复 `homeContentH` / `folContentH` / `folViewportH` / `homeLastPrefetchY` / `folLastPrefetchY`），`onHomeViewportAreaChange` 恢复按 feed 记录视口高；`Skeleton.ets` 多列分支由 `WaterFlow` 同步改为行分组（与真实列表同结构）。**保留项**：多列图片高度封顶（单图 `maxHeight 220` / 多图格 `2/4 张 140、其余 100`，见下方第 7 项）、`cardColumns` 全局标记、形态判定与首帧取宽高、渐隐带夹取。构建 `tools/build.ps1` → **BUILD SUCCESSFUL**；改动前备份 3 文件（`BACKUP_TS=20260913_planb`）。§三 第 1 项、§4.2 状态与落地清单、§6.2 已过检记录同步。
> 更新：2026-09-13 · **§4.2 首页（`pages/HomeTab.ets`）平板适配已落地并构建通过**（用户指示「先试试落地首页，开工，同时进行备份，同时进行构建」；改动前先做 4 文件备份，`BACKUP_TS=20260913_141920`）。落地清单 8 项：① `entry/src/main/module.json5` 的 `deviceTypes` 加 `"tablet"`（§1.6 前置项；**不含 `"2in1"`**，上架后台联动仍待上架时执行）；② `common/Theme.ets` 新增 `Breakpoint`（`sm 600` / `md 840` / `lg 1440`）与全局列数标记键 `CARD_COLUMNS_KEY = 'cardColumns'`；③ `HomeTab.ets` 两条 feed（推荐流 / 关注流）由 `Scroll + Column + ForEach` 换为 `WaterFlow + FlowItem + ForEach`（`.columnsTemplate` 单列 `1fr` / 竖 2 `1fr 1fr` / 横 3 `1fr 1fr 1fr`，`.columnsGap` / `.rowsGap(Spacing.md)`、`.cachedCount(列数 × 3)`、`.padding({ bottom: 150 })`）；④ 预加载判据从 `onAreaChange` 量内容高改为 `onScrollIndex(first, last)` 按条目下标判定（`HOME_PREFETCH_ROWS = 2`，等价「还剩约 2 屏」，覆盖快速甩滑）；⑤ 新增形态判定与数列方法 `isWideFormDevice`（`deviceInfo.deviceType` `tablet` / `2in1` + `display.isFoldable()`，静态判一次）/ `isLandscape()` / `homeColumns()` / `homeColumnsTemplate()` / `syncCardColumns()` / `onHomeFormAreaChange()` / `updateFadeStop()` / `onHomeScrollIndex()`，并在 `aboutToAppear` 用 `display.getDefaultDisplaySync()` 同步取首帧宽高（与 §4.6 H-A 同源，防「先 1 列再跳 3 列」）；⑥ 顶部渐隐带停靠点由固定 `0.15` 改为按视口高夹取 `min(max(视口高 × 0.15, 108), 180)` 折算（决策 5）；⑦ `components/CommonComponents.ets` 的 `ThreadCard` 走 `@StorageProp('cardColumns')`，摘要 `maxLines(cardColumns > 1 ? 2 : 4)`、单图多列档 `aspectRatio(1.6)`、多图格多列档 `aspectRatio(1)`（决策 6，**严格限多列档生效，单列逐像素不变**）；⑧ `components/Skeleton.ets` 的 `ThreadListSkeleton` 增 `@Prop columns: number = 1`，`columns > 1` 走同列数 `WaterFlow` 铺放、默认 1 走原 `Column`。**跨页标记防残留**：`syncCardColumns()` **无条件写**（含单列写 1），`aboutToAppear` / `onPageShow` / `onAreaChange` 三处都写；`ThreadList.ets` 显式 `AppStorage.setOrCreate('cardColumns', 1)` 写回单列（本页多列未落地）。构建：`tools/build.ps1` → **BUILD SUCCESSFUL**。**仍挂一项真机验证**：`WaterFlow` 真机 A/B 前置门（长列表上下滚动确认卡片不消失，复用 `floor-vanish-viewport-fix` 验证路径；复现即回退方案 B，届时决策 6「摘要降 2 行」由可选转必做）。§三 第 1 项状态转「已落地（构建通过）」、§4.2 状态行与「落地清单」同步、§6.2 已过检记录追加一行。
> 更新：2026-09-13 · **§4.2 首页多列档「行等高 + 互动栏底对齐」落地并构建通过**（用户「先试试吧，我希望内容顶对齐 + 互动栏底对齐」）→ 新增 **§4.2 决策 8**：多列档行分组容器由 `Row` 改为 `Flex({ direction: FlexDirection.Row, alignItems: ItemAlign.Stretch, space: { main: LengthMetrics.vp(Spacing.md) } })`（**`Row.alignItems` 只接受 `VerticalAlign`、枚举无 `Stretch`，想拉伸交叉轴必须换 `Flex` + `ItemAlign.Stretch`**）；`ThreadCard` 根 `Column` 内、内容区与操作栏之间**按 `cardColumns > 1` 插 `Blank()` 弹性垫片**（`Blank` 在 `Column` 中自动占满剩余高度）吸收「内容自然高 < 行高」的差值 → **内容顶对齐 + 互动栏底对齐**，差量落在卡内中部而非卡外底部；`ThreadListSkeleton` 多列分支同步改 `Flex` + `Stretch`，`ThreadCardSkeleton` 增 `@Prop stretch`（默认 `false`，首页骨架传 `true` 使纸面 `height('100%')`）→ 骨架期与内容期等高形态一致，消除加载完成瞬间的布局跳动。**单列手机路径零改动**（`cardColumns === 1` 不插垫片、不套 `Flex`、`stretch` 保持默认 `false`）。构建 `tools/build.ps1` → **BUILD SUCCESSFUL**；改动前备份 3 文件（`BACKUP_TS=20260913_stretch`）。§4.2 决策 8 与落地清单 #3/#7/#8、§6.1 **A7**、§6.2 已过检记录同步。
> 更新：2026-09-13 · **§4.2 首页多列档「行等高 + 互动栏底对齐」真机实测失败并已回退**（用户反馈「不仅没有拉伸对齐，最高卡按钮还消失了」）：立即用 `BACKUP_TS=20260913_planb` 还原三文件（`HomeTab.ets` / `CommonComponents.ets` / `Skeleton.ets`）到无拉伸方案 B 状态；撤销 `Flex` + `ItemAlign.Stretch`、撤销 `ThreadCard` 内 `Blank()` 垫片、撤销骨架 `@Prop stretch`；`tools/build.ps1` → **BUILD SUCCESSFUL**。行内高度差留白恢复为 A6「接受」。文档同步：§4.2 决策 8 改为「已尝试并回退」、状态行与落地清单 #3/#7/#8 与末尾 A/B/C/D 留痕、§6.1 A6/A7、§6.1「多列写法共三套」第 ① 条、§6.2 已过检记录追加回退行。
> 更新：2026-09-13 · **§4.2 首页横屏列数由 3 收为 2（用户取「方案 A」：只改列数，不动容器与卡片内部）+ 构建通过**。起因：方案 B 行分组下「同行『9 图卡（图片区 300vp）vs 无图文本卡（0）』高度差可达 ~400vp」，横屏 3 列时被大图进一步放大，用户真机观感为「大量错位」。**执行内容**：`HomeTab.ets` 的 `homeColumns()` 返回值由 `this.isLandscape() ? 3 : 2` 改为 `2` —— 大屏（平板 / 折叠展开）**横竖屏统一 2 列**，手机 / 窄窗仍恒 1 列（首行 `isWideFormDevice` 闸门未动）；已无调用点的 `isLandscape()` 一并删除，`pageHeight` 保留（供将来「仅横屏另给口径」复用）。容器（`Scroll` + `Column` + 行分组 `Row`）、卡片几何（摘要 2 行 / 单图 220 封顶 / 多图格 100·140 封顶）、骨架屏、预加载、`cardColumns` 全局标记**全部零改动**；列数消费方（`homeRows()` / `homeRowBlanks()` / `cachedCount` / 骨架 `columns`）自动跟随单点判据。**说明**：行内高度差留白（A6）仍按「接受」—— 2 列只降低「极端组合」出现概率、不消除落差；若要彻底消除须回到「定高 + 裁内容」或「列内独立堆叠」。构建 `tools/build.ps1` → **BUILD SUCCESSFUL**；改动前备份 `HomeTab.ets`（`BACKUP_TS=20260913_landscape2col`）。§三 第 1 项、§4.2 需求 / 决策 9 / 状态行 / 落地清单 / 留痕、§6.1 A6、§6.2 已过检记录同步。
> 更新：2026-09-13 · **§4.2 首页横屏列数 2 → 3（撤销决策 9，用户拍板「现在方案 B，横屏还是改为三列」）+ 构建通过**。`HomeTab.ets`：恢复 `isLandscape()`（`pageWidth > pageHeight` 宽高比判定，不用宽度阈值）并把 `homeColumns()` 末行改回 `this.isLandscape() ? 3 : 2`（大屏横屏 3 / 竖屏 2；手机 / 窄窗仍恒 1 列，首行 `isWideFormDevice` 闸门未动）；容器（`Scroll` + `Column` + 行分组 `Row` + `VerticalAlign.Top`）、卡片几何、骨架屏、预加载、`cardColumns` 全局标记**全部零改动**（列数消费方 `homeRows()` / `homeRowBlanks()` / 骨架 `columns` 经 `homeColumns()` 单点取值自动跟随）；行内高度差留白（A6）仍按「接受」。`tools/build.ps1` → **BUILD SUCCESSFUL**（45s）；改动前备份 `HomeTab_20260913_restore3col.ets`。还原后与「横屏 3 列」基线文件 `HomeTab_20260913_landscape2col.ets` 逐行比对**仅剩注释差异**（无逻辑残留）。§三 第 1 项、§4.2 需求 / 决策 9（加撤销说明）/ 新增**决策 10** / 状态行 / 落地清单 #3 #5 / 留痕、§6.1 A6 与「多列写法共三套」第 ① 条、§6.2 已过检记录同步。
> 更新：2026-09-13 · **§4.2 首页多列档「行等高 + 互动栏底对齐」经最小 Demo 实证后二次落地（新增决策 11）+ 构建通过**：决策 8 的失败根因已定位为**缺卡根 `height('100%')`**（`Flex` 的 `ItemAlign.Stretch` 只把交叉轴「建议尺寸」交给子项，子项未声明 `100%` 仍按内容高度渲染），故本轮先建**独立最小验证页 `pages/PilotStretch.ets`**（6 组容器/高度对照 + `onAreaChange` 尺寸探针 + 胶囊点击计数）在真机实测：① `Row` 无高度 `680×302 / 680×142`（现状留空）② `Row` + `height('100%')` `440×1328 / 440×1328`（行被 `Scroll` 撑高，弃）③ `Flex(Stretch)` 无高度 `440×302 / 440×142`（容器单独拉不动）④ `Flex(Stretch)` + `height('100%')` `680×848 / 680×848`（等高成立）⑤ ④ + `Blank()`、⑥ ④ + `SpaceBetween` 均等高、三胶囊可见且可点；随后清理 Demo（删页 + `main_pages.json` 注销 + `EntryAbility.loadContent` 切回 `pages/Index`）并落地 `HomeTab.ets`（两条 feed 行容器 `Row` → `Flex({ alignItems: ItemAlign.Stretch, space: { main: LengthMetrics.vp(Spacing.md) } })` + 卡片调用点 `.height('100%')`）、`CommonComponents.ets`（`ThreadCard` 按 `cardColumns > 1` 在内容区与操作栏之间插 `Blank()`）、`Skeleton.ets`（多列分支同步换 `Flex` + `Stretch` + `ThreadCardSkeleton` 增 `@Prop stretch`，默认 `false`）；§4.2 新增决策 11 + 状态行/落地清单 #3·#7·#8/待办/风险自检四行、§6.1 A6 与 A7 表项（A7 由「不可照搬」修正为「**有条件可行、三条件缺一不可**」）与「多列写法共三套」第 ① 条、§6.2 已过检记录同步；`tools/build.ps1` → **BUILD SUCCESSFUL**；**待真机验收 4 项**（矮卡是否等高底齐 / 最高卡操作栏三胶囊是否可见可点 / 末行补位后卡宽是否一致 / 手机单列逐像素不变）。
> 更新：2026-09-13 · **§4.2 决策 11 二次修正**：用户真机验证发现 `Blank()` 与 `SpaceBetween` 在复杂卡内均失效（多宫格卡操作栏丢失、纯文本卡被 `Scroll` 无限高度异常拉长）→ 最终改为「内容区 `.layoutWeight(1)` 占满剩余空间 + 根 `Column` `.constraintSize({ maxHeight: 560 })` 上限护栏」，保持行容器 `Flex(Stretch)` + 卡片调用点 `.height('100%')` 不变；文档 §4.2 决策 11 / 落地清单 #7 / 风险自检 C 行 / §6.1 A6·A7 与「多列写法共三套」第 ① 条、§6.2 已过检记录同步刷新；`tools/build.ps1` → **BUILD SUCCESSFUL**。
> 更新：2026-09-13 · **§4.2 决策 12「`WaterFlow` 瀑布流」全面落地**：最小验证页 `pages/PilotWaterFlow.ets`（30 条混合图数真实卡片）真机通过后删除，`EntryAbility` 入口切回 `pages/Index`；`HomeTab.ets` 推荐流 + 关注流多列分支统一改为 `WaterFlow` + `LazyForEach`（`ThreadDataSource` + `@Watch` 自动同步），支持**竖屏 3 列 / 横屏 4 列**动态切换（`display.on('change')` + `checkFormChange()` 兜底），`columnsTemplate` 动态绑定、骨架同列数；`ThreadCard` / `HomeTab` 已删除为 Flex 方案加的 `layoutWeight` / `maxHeight` / `height('100%')`；§4.2 决策 12 + 待办 / 风险自检四行、§6.2 已过检记录同步刷新；`tools/build.ps1` → **BUILD SUCCESSFUL**；**待真机验收**（竖屏 3 / 横屏 4 切换 + 快速滚动稳定性 + 多宫格卡操作栏 + 手机单列回归）。
> 更新：2026-09-13 · **§4.8 吧内帖子列表（`ThreadList.ets`）已落地 + 构建通过**：① **列数口径改为跟首页一致 = 竖屏 3 列 / 横屏 4 列**（替换原「竖 2 / 横 3」草案）；② **置顶区纳入多列网格**（不再保持「整块通栏卡」——「置顶」标签行仍通栏，`PinnedThreadItem` 包 `Column().layoutWeight(1)` + 独立 `bgCard`/`borderRadius(26)` 入行分组、末行补空位键前缀 `pin_gap_`）；③ 前置依赖（`Breakpoint` / `CARD_COLUMNS_KEY`）**已全部解除**，可开工；④ **新增 T-F「平板下三项不拉伸」**：吧头经验条 `constraintSize({ maxWidth ≈ 220 })` 不拉伸（并补 `Blank()` 让签到钮仍贴右缘）、底部排序底栏 `sortBarWidth()` 加 `244` 上限不拉伸、右下 FAB 几何本身固定（`80×56` / 右缘 24 / 底距 30）；⑤ **FAB 位置锚点选 B + 整体居中**（用户拍板「按 B」后追加「不能居中对齐吗」）：新增 `BottomGroupShell()` 把「底栏 + 缝 12 + FAB」合并为**单个 `Row`**（净宽 336vp），**多列档整体居中、单列档保持现状左对齐 + 左缘 24**（手机 360 恰好占满，居中必须条件化，否则手机左移 12vp），替换原两处独立悬浮层调用，平板下不再分居两端。§4.8 需求 / T-B 列数函数 / T-C（新增置顶网格代码骨架）/ T-D / **T-F（含 B 方案实现骨架）** / 断点阈值 / 已拍板点表（5 项全部收敛、无待拍板）/ 风险自检（A 补空位 3 处、C 4 列窄列评估、T-F 签到钮左移护栏 + 组合 Row 消除两端错位面）/ 状态同步刷新。**代码已执行**：`ThreadList.ets` 落地 T-B/C/D/E/F 六项（新增 `threadColumns()` / `syncCardColumns()` / `onListFormAreaChange()` / `threadRows()` / `threadBlankSlots()` / `BottomGroupShell()` + 常量 `THREAD_LIST_SORT_BAR_MAX_WIDTH` / `THREAD_LIST_EXP_BAR_MAX_WIDTH`）；`tools/build.ps1` → **BUILD SUCCESSFUL**（1m01s）；**待真机验收**。
> 更新：2026-09-13 · **§4.10 楼中楼详情同步 §4.9 二次拍板（仅更新文档，不开工）**：用户指示「楼中楼一起改」→ §4.10 与 §4.9 对齐（回复区 `WaterFlow` 三列瀑布流 / 宫格不拉伸不放大 + 左对齐 / 横屏左栏按「帖子本身宽度」），一次方案的「手写双列 / 4 : 6」作废，新增 **SP-G ~ SP-K**。**与 §4.9 的三处不可照抄点**：① **`sections` 段数 = 2**（本页**无「加载更多」UI / 无触底哨兵**，省略 §4.9 的段 2）；② **间距语言 = `Spacing.sm`(8)**（不是 `Spacing.md`12）；③ **卡内追加间距判定要重算**（现状用**全局下标** `commentIndex < length - 1`，多列后每列末条会多留 8vp → 列底空洞，改法：间距挪到 `rowsGap` / 传列内下标）。另：`syncSections()` 挂点必须**多一处** —— `locateNotifyTarget()` 追加 `commentsState` 时同步（本页唯一列表增长路径，漏了会 `itemsCount` 不匹配导致整页无法滚动）；SP-H 定位锚点 `spc_` 随卡进 `FlowItem`；SP-J 本页 `ImageGrid` 是独立实现需单独加 `maxWidth`；SP-K 沉浸层只有 `overlay` + `blendMode` **两项**且遮罩是 `height('100%')` 整区形态，**两项同层同迁**后需真机复验底部渐隐。待拍板点 5 / 6 / 7 **沿用 §4.9 拍板值**。§4.10 状态行同步更正「§4.6 H-B 已非阻塞」。**代码未改**。
> 更新：2026-09-13 · **§4.9 帖子详情二次拍板（仅更新文档，不开工）**：用户同日二次拍板 —— **竖屏**「帖子内容不动 + **宫格图不拉伸不放大、左对齐** + 回复区改用**首页 `WaterFlow` 瀑布流、三列**」；**横屏**「左帖 / 右回复，回复区**三列瀑布流**，**帖子区域宽度 = 帖子本身宽度**（不再 4 : 6）」。文档新增 **DT-G ~ DT-J**：DT-G 用 `WaterFlow({ scroller, sections })` + `WaterFlowSections` 让「顶栏让位 + 主楼 + 回复表头」与「触底哨兵」跨列、楼层三列（含 5 条硬约束，最要命的是**各段 `itemsCount` 累计和必须严格等于子节点数，否则整页无法滚动** → 哨兵必须恒渲染）；DT-H 楼层定位 `.id` 随卡进 `FlowItem`；DT-I 横屏左栏改**固定宽度**取代 4 : 6；DT-J `ImageGrid` 加 `.constraintSize({ maxWidth })` 实现**不拉伸 + 自动左对齐**（一改三处共用调用点，手机档不生效 → 零回归）。一次方案的「**手写双列**」「**4 : 6**」随之作废；新增待拍板点 5（左栏宽度，建议 420）/ 6（宫格上限，建议 336）/ 7（右栏三列窄列观感）；状态行更正：**§4.6 H-B 已非阻塞**（§4.8 已用本地判据落地，可直接照抄）；§4.10 加同步提醒（本页是否沿用待确认，且本页**无触底哨兵 → DT-G 段 2 应省略**）。**代码未改**。
> 更新：2026-09-13 · **§4.8 T-I 吧头多列档居中（当日回退）**：用户先要求「吧头改成居中对齐」→ `ForumHeaderBuilder` 外层 `Row` 加 `.constraintSize({ maxWidth: this.threadColumns() > 1 ? THREAD_LIST_HEADER_MAX_WIDTH : 99999 })`（常量 480）。**只加一行即可居中**：父层 `Column` 交叉轴默认 `HorizontalAlign.Center`，内容块限宽后自动居中，无需改嵌套 / 加 `justifyContent`。**同日用户拍板「还是回退到左对齐吧」→ 已移除该限制与常量，吧头恢复左对齐铺满**（改造前观感，手机 / 平板一致）。技术路径已验证可行，留待将来复用。`tools/build.ps1` → **BUILD SUCCESSFUL**；**待真机验收**。
> 更新：2026-09-13 · **§4.8 T-H 吧主页「更多」弹窗几何统一**：用户真机反馈平板下弹窗被拉成通栏、纵向位置与全站其余弹窗不一致（要求「弹窗不要拉伸，调到跟首页置顶弹窗一个高度位置（手机模式也一样调位）」）→ `ThreadList.dialogCardWidth()` 改为 `max(200, min(400, 屏幕宽 − 48))`（新增 `THREAD_LIST_DIALOG_MAX_WIDTH = 400`，即系统弹窗默认宽度上限；手机档 `360 − 48 = 312 < 400` **逐像素不变**），`moreSheetController` 的 `offset.dy` 由 **-30 → -110**（与 `Favorite` 六处、`ForumsTab` 两处置顶弹窗统一；`ThreadDetail` 的 -140 有专属理由、勿动）。**遗留**：其余页面的 `dialogCardWidth()` 仍未封顶，平板下同样偏宽，如需全局统一可再开一轮。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m09s）；**待真机验收**。
> 更新：2026-09-13 · **§4.8 T-G 转场适配（吧头静止且不被遮挡）**：用户真机反馈平板下「最新 / 热门 / 精选」左右切换**闪一下直接过去 + 一瞬间画面重叠**，追加要求「转场时吧头不要跟着切换」，再反馈「吧头被遮挡后再出现」→ 多列档换 `WaterFlow` 时漏了排序过场配套：① 多列档缺新页位移（单列档挂在「列表区 Stack」）；② `captureExitSnapshot()` 恢复**单列 / 多列同款**裁剪（裁掉吧头，否则旧页快照带着吧头滑出、与静止吧头重叠）；③ 多列档骨架屏补 `skeletonOpacity`；④ **位移最终改为逐张帖子卡片**（`.translate({ x: this.sortShiftX() })`，`sortShiftX()` 把 `inOffset` 的 ±100 百分比语义按根容器实测宽换算 vp）→ `WaterFlow` 容器与吧头**完全静止**。**首版「容器整页位移 + 吧头等量反向位移」已被证伪并弃用**：`WaterFlow` 是虚拟滚动容器、自带渲染区，反向位移后的吧头落在该区之外会被裁掉 → 真机表现为「吧头被遮挡后再出现」。同批修掉两个同源数据缺陷：`syncListDataSource()` 改为**逐项比对前缀**判定「尾部追加」（原先只比长度，切排序 / 刷新变长会误判 → 前段不重建、内容错乱），`HomeTab` 同源处一并改 `syncSource()`；`syncSections()` 加 `lastSectionKey` 去重。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m03s）；**待真机验收**。
> 更新：2026-09-13 · **§4.8 T-G「吧内帖子列表多列档改 `WaterFlow` 瀑布流」**：用户真机反馈行分组仍拉伸置顶卡、留白大 → 多列档改为与首页同款 `WaterFlow({ scroller, sections })` + 静态 `FlowItem`（吧头）+ `LazyForEach(this.listDataSource)`（帖子）；**用 `WaterFlowSections` 让吧头跨列并随内容滚动**（用户追加要求「吧头不要固定在顶部，随内容流动」）：section 0 = 吧头（`crossCount 1` 独占整行）、section 1 = 主体（`crossCount 3/4` 多列）；**置顶卡作为瀑布流普通格子、不拉伸**（取消「置顶」通栏标签行与整块通栏卡）；新增 `ThreadListDataSource`、`waterFlowThreads()`、`syncListDataSource()`、`syncSections()`（挂 `onThreadsChanged` / `onLoadStateChanged` / 形态变化，保证 `itemsCount` 与子节点数一致）；单列档 / 搜索态保持原 `Scroll` 结构逐像素不变；`tools/build.ps1` → **BUILD SUCCESSFUL**（1m02s）；**待真机验收**。
> 更新：2026-09-13 · **§4.9 / §4.10 真机错位修复**：用户真机反馈帖子详情页**竖屏 / 横屏回复区均有明显卡片重叠、横屏第三列溢出屏幕**（附截图），要求参考首页瀑布流（成品）修复 → 根因 = 两页 `ImageGrid` 都是「`Grid`（可滚动容器）嵌 `FlowItem` 且只有格高 120、**无总高**」，布局期 Grid 自测量高与渲染期不一致 → WaterFlow 按错高摆放后续 FlowItem → 重叠（首页成品无此问题，因首页卡片所有图片尺寸测量期即终值）。修复：① `ImageGrid` **显式总高**（行数 × 120 + 行间隙）；② `capMaxWidth` 参数 —— 仅通栏 / 左栏卡传 true（336 封顶），列内卡传 false（`'100%'` 跟随列宽）；③ 横屏右栏 `WaterFlow` 补 `.width('100%')` 防列宽按接近全屏值计算溢出。`tools/build.ps1` → **BUILD SUCCESSFUL**（55s）；**lint 0**；**待真机复验**（竖 / 横屏回复区无重叠、横屏第三列不出屏、图片点击预览正常、手机单列逐像素不变）。
> 更新：2026-09-13 · **全量收口：设置页与全部二级页渐显带平板收窄（公共函数 `tabletTopFadeStop`）**：用户要求「软件设置 + 所有二级菜单」一并修复 → 全局检索定位 **11 处残留**（Settings / AutoSignSettings / UsageHabitsPage / ShieldSettings / FontSizePage / BlacklistManager / PersonalizedPage / Follow / FollowList / PersonalContent / SubPostDetail——楼中楼页的整区比例式渐显一并收口）。**收口为公共函数** `Theme.tabletTopFadeStop(coverVp)`（形态判定 deviceType tablet/2in1/isFoldable + 屏幕长边折算 + 失败回退 0.15，单点维护），各页仅两行改动：Theme import 追加 + 渐变中间 stop 写 `tabletTopFadeStop(98)`（各二级页顶部固定区均 98）。**手机全部回退原 0.15 逐像素不变**（函数内形态闸门）。此前五 Tab 页（HomeTab 动态公式 / ForumsTab / MessagesTab / Message / MineTab / Favorite=132）与本轮 11 页共 **17 处**渐显全部平板收窄；ThreadDetail / 楼中楼 TopFadeBand 为固定 88 高不受影响。Theme.ets 补 `display` import。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m14s）；**lint 0**；**待真机复验**（平板各二级页渐显只到顶栏底缘、手机全量逐像素不变）。
> 更新：2026-09-13 · **§4.8 吧内帖子列表渐显带平板收窄（同五页批次）**：用户反馈吧内页同况 → ThreadList 的 `BottomFadeOverlay()`（写死 0.15，多列 WaterFlow 与单列 Scroll 两处挂点共用）接 `topFadeStop()`：平板 = `min(0.15, THREAD_LIST_HEADER_TOP_SPACE(90) / pageHeight)`（吧头让位 90 折算；pageHeight 为实时窗口高，横竖屏都准；**分母不用 viewportH**——那是 Scroll 视口高、已被顶栏与底栏让位吃掉，与窗口高不等，见 §4.8 字段注释），手机 0.15。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m23s）；**lint 0**；**待真机复验**（平板吧内页渐显只到吧头顶缘、手机不变）。
> 更新：2026-09-13 · **§4.2 / 消息页渐显带收窄补漏（首页与消息页首轮未生效的根因）**：用户反馈首页与消息页仍覆盖过深 → ① **首页**：`updateFadeStop()` / `fadeStop` 是**无消费点的历史遗留**（§4.2 决策 5 时代残留），首页真正的渐显是自带的 `BottomFadeOverlay()`（写死 0.15，两条 feed 各挂一次）→ 已接 `topFadeStop()`（平板 = `HOME_TITLE_BAR_HEIGHT(108) / pageHeight` 实时窗口高，手机 0.15）；`updateFadeStop` / `fadeStop` / `HOME_FADE_MIN/MAX` 保留为无害遗留（后续 H-F 类清理项）。② **消息页**：底部 Tab 的消息页实际是 **`MessagesTab.ets`**（通知中心），首轮误改的 `Message.ets` 是另一路由页 → MessagesTab 已补同款收窄（isWideFormDevice + fadeCoverVp 长边 + topFadeStop 98 折算）。`tools/build.ps1` → **BUILD SUCCESSFUL**（56s）；**lint 0**；**待真机复验**（平板竖屏首页两条 feed 与消息页渐显只到顶栏底缘；手机不变）。
> 更新：2026-09-13 · **五个 Tab 页顶部渐显带平板收窄（只覆盖顶部按钮与标题）**：用户真机反馈平板竖屏下首页 / 进吧 / 收藏 / 消息 / 我的五页的顶部满宽渐显带覆盖过深（到首页第一个卡片用户名位置），要求只覆盖顶部按钮与标题 → 根因 = 各页渐显 stop 按比例（0.15 / 0.20 / 动态夹取 [108,180]），平板竖屏 800vp 下即 120~160vp，远超顶栏 98。**修复（形态分档，手机零变化）**：① **HomeTab**：`updateFadeStop()` 平板档 raw 直接取 `HOME_TITLE_BAR_HEIGHT`(108)，手机维持 `vh × 0.15` 夹取；② **ForumsTab / Message / MineTab**：各新增 `isWideFormDevice` + `fadeCoverVp`（屏幕长边，aboutToAppear 取）+ `topFadeStop()`（平板 = `min(0.15, 98/长边)`，手机 0.15），`BottomFadeOverlay` 中间 stop 改走该方法；③ **Favorite**：同款但覆盖基准 = **132vp**（TopBar 98 + 分段切换区至 132，避免分段区下沿内容突兀变实），手机 0.20。补 import：ForumsTab / Favorite 加 `deviceInfo`，Message / MineTab 加 `deviceInfo + display`。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m00s）；**lint 0**；**待真机复验**（平板竖屏五页渐显只到顶栏底缘〔收藏到分段区底〕、卡片内容清晰；手机五页渐显逐像素不变；平板横屏渐显同步收窄）。
> 更新：2026-09-14 · **渐显带修复经验沉淀为新文档 `docs/fade-band-fullwidth-fix.md`**：四轮排查（挂点回迁 / 容器显式宽 / Refresh 全宽 / 弃 DST_IN 改背景色渐变条）+ 硬切教训 + 快速排查清单 + 层级表，后续其它页面渐显带同类问题直接套用；README 维护文档清单同步登记。
> 更新：2026-09-17 · **§4.9 帖子详情页横屏「主楼卡 = 回复卡等宽」（用户拍板，构建通过）**：`splitMainWidth()` 由「大折叠 屏宽/3、平板固定 420」改为**平板也取屏宽/3**（大折叠先例推广；推导：主楼卡宽 = L−24〔左16/右8 内距〕，回复每列 = (R−24−12)/2，R = W−L−12〔分栏缝 12〕，相等 ⇔ L = W/3 恰好凑平）→ 横屏分栏下主楼卡与回复列等宽。**竖屏不做**（用户二次拍板「竖屏不用」——曾短暂落地主楼限宽包裹，即日撤销；竖屏主楼保持满宽通栏）。`DETAIL_MAIN_WIDTH(420)` 降级为 currentWidth 未就绪时的回退值。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m08s）；**lint 0**。
> 更新：2026-09-17 · **§4.9 帖子详情页横屏回复区改回 2 列（用户二次拍板，构建通过）**：昨日全站统一「竖 2 / 横 3」时详情页平板分支曾改 `isLandscape() ? 3 : 2`（横屏分栏右栏 3 列），用户实测后回调——**平板横竖屏均 2 列**（与 09-16 首拍同值；横屏分栏右栏 2 列）。其余 11 处页面「竖 2 / 横 3」不变。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m07s）；**lint 0**。
> 更新：2026-09-17 · **全站平板列数统一「竖 2 / 横 3」（原竖 3 / 横 4 作废，构建通过）**：用户拍板 12 处页面列表列数统一改值。改动点（各页列数函数 `isLandscape ? 4 : 3` → `? 3 : 2`，注释同步）：① 首页 `HomeTab.updateColumns`（`w>h?4:3` → `w>h?3:2`；**阔直屏 `3/1` 与大折叠 `3` 分支不动**）；② 进吧页 `ForumsTab`（平板竖 2 与手机竖屏 2 同值，横 3）；③ 收藏页 `Favorite.favColumns`（收藏夹列表 / 点开列表 / 搜索态 / 吧分类 / 自定义分类全走此函数自动跟随）；④ 消息页 `MessagesTab`；⑤ 个人内容四页（我的帖子 / 我的收藏 / 我的点赞 / 浏览历史）`PersonalContent.pcColumns`；⑥ 他人信息页 `UserProfile.profileColumns`；⑦ 吧主页（含吧搜索页）`ThreadList.threadColumns`；⑧ 帖子详情页 `ThreadDetail.replyColumns` 平板分支 `2` → **`isLandscape() ? 3 : 2`**（昨日「横竖屏均 2」作废；横屏分栏右栏 3 列）；⑨ 全局搜索页 `Search.searchColumns`。方案 B 分桶 / 列模板 / 骨架列数 / 宫格 336 封顶等全部经列数函数自动跟随；手机档闸门（≥600）与各形态分支（阔直屏 / 大折叠）零改动。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m13s）；**lint 0**；**待真机复验**（12 处竖 2 / 横 3、旋转实时切换、翻页不跳位、手机档逐像素不变）。
> 更新：2026-09-17 · **小窗 / 分屏 / 自由多窗适配（列数判定真源统一为「窗口」，构建通过）**：背景 = 平板横屏持机开自由小窗时，各页按 `display.getDefaultDisplaySync()`（物理屏）判横竖屏 → 窄小窗仍渲染 3 列（截图实证）。收口 12 文件：① **8 个列数页**（HomeTab / ForumsTab / MessagesTab / Favorite / PersonalContent / Search / ThreadList / UserProfile）列数函数**首行插窗口宽度闸门**（`pageWidth > 0 && pageWidth < 600` → 手机档；ForumsTab 手机档 = 2 列、阔直屏 = 1 列），置于大折叠恒 3 / 阔直屏竖 1 横 3 等**设备恒值分支之前**（原恒值分支会绕过宽度兜底）；② **窗口尺寸真源 display → 窗口**：HomeTab `checkFormChange` / Search·PersonalContent·UserProfile `refreshFormMetrics` / ThreadList `onListFormAreaChange` 改「窗口实值优先（onAreaChange 入参）、display 仅首帧兜底」，HomeTab `updateColumns` 的 `cardColumns` 下发改经 `homeColumns()` 闸门（不再裸写 this.columns）；③ **详情页** ThreadDetail / SubPostDetail `replyColumns` 同款窗口闸门（splitMode 既有 `currentWidth ≥ Breakpoint.sm` 判据天然安全、不动）；④ ThreadDetail `dialogCardWidth` 改窗口实宽优先（小窗内 400 封顶不再溢出窗口）；⑤ Index / UserProfile `isWideScreen` 的大折叠 / Pura X Max 设备恒值项补 `width ≥ 600` 条件（窄窗回落手机底栏 / 黑名单弹窗档）。**不做迟滞带**（大折叠竖屏窗口宽 ~630 紧贴 600，640 进档会回归既有 3 列）。全屏各档逐档对账**等价**（手机 / 平板 / 阔直屏 / 大折叠列数与底栏零变化）。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m18s）；**lint 0**；**待真机验证**（平板小窗 1 列、拉宽 ≥600 升多列、拖拽跨 600 翻档、全屏各档回归）。
> 更新：2026-09-17 · **小窗三档中间档改两列（用户看小窗实拍三档后拍板，构建通过）**：小窗三档（小 / 中 / 大）中，中间档窗口宽落在 600~840、却吃平板档 3 列（每列 ~200vp 挤爆，截图实证）。9 个文件末档由「按窗口宽高比 竖 2 / 横 3」改为**按窗口宽度分档**：`≥840 → 3 列 / 600~840 → 2 列 / <600 → 手机档`（复用 `Breakpoint` sm/md 令牌）：① 8 个列数页（HomeTab〔不再吃 display 推导的 this.columns〕/ ForumsTab / MessagesTab / Favorite / PersonalContent / Search / ThreadList / UserProfile）；② 楼中楼 SubPostDetail `replyColumns` 同口径（≥840 恒 3 → 分档；ThreadDetail 因 09-16「平板横竖屏均 2」本就恒 2 不受影响）。**全屏零回归**：平板全屏竖 ~800 → 2、横 ~1280 → 3，与改前同值；阔直屏横 3（~830，宽屏分支在前）与**大折叠恒 3**（09-15 拍板竖横均 3）均不受分档影响。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m18s）；**lint 0**；**待真机验证**（中间档小窗 2 列、拉到最大档 3 列、全屏各档回归）。
> 更新：2026-09-17 · **中档小窗仍 3 列真机反馈修复（HomeTab 列模板绕过闸门，构建通过）**：真机复核发现中档窗口仍 3 列——根因 = HomeTab 两条 feed 的 `WaterFlow.columnsTemplate` **直接绑 `this.columns`**（display 推导值，小窗下恒 3），而分支入口 `homeColumns() > 1` 已按窗口闸门放行 2 列档 → 「入口 2 列、模板 3 列」错位；小窗 1 列未露馅是因为 `<600` 走单列 Scroll 分支不经模板。修复：新增 `homeColumnsTemplate()`（与 `homeColumns()` 单点同源），推荐流 / 关注流两处调用点换用；全工程检索确认其余页列模板均走列数函数（ForumsTab `columnsTemplateOf(forumColumns())` 等），无同款隐患。**教训入档：列数消费方（模板 / 骨架 / 行分组 / cachedCount）一律走列数函数，禁止直绑 this.columns**。`tools/build.ps1` → **BUILD SUCCESSFUL**（34.7s）；**待真机验证**（中档小窗 2 列）。
> 更新：2026-09-16 · **三页底栏平板档统一 400 = 弹窗宽度（构建通过）**：用户拍板「平板横竖屏底栏宽度 = 各页弹窗宽度」，三处一次落地——① **首页**（§4.2/§4.6）：`pillWidth()` 宽屏档 `480 → 400`（原「大折叠 400 / 平板 480」双值合并为恒 400，与置顶弹窗 `dialogCardWidth` 400 同宽），LegacyShell 兜底壳同步；② **他人信息页**（§4.11）：同款合并 → 400（与黑名单弹窗 `panelWidth` 400 同宽）；③ **帖子详情页**（§4.9）：`DETAIL_DOCK_TABLET_WIDTH` **592 → 400**（与跳转官方弹窗 `dialogCardWidth` 400 同宽，原「592 现有基础宽一倍」作废；底栏加宽 592 时校准的排序壳左移微调值 -40 **可能失准，真机复核项**）。三页手机档「屏宽−48/−64」逐像素不变；大折叠展开档原 400 不变（合并进统一值）。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m17s）；**lint 0**；**待真机复验**（三页底栏 400 居中横竖屏一致、详情页排序胶囊与底栏左缘对齐〔微调值复核〕、手机档逐像素不变）。
> 更新：2026-09-16 · **§4.9 帖子详情页回复区改恒 2 列 + 宫格图片不拉伸（构建通过）**：用户拍板「平板竖屏和横屏回复区域都改成两列，宫格图片不要拉伸」。① **列数**：`replyColumns()` 平板分支恒 3 → **恒 2**（横竖屏同值；阔直屏恒 1 / 大折叠 2 / 手机 1 各分支不动，平板与现有大折叠档同值但判据独立保留）；方案 B 分桶 / 估算列宽自动跟随。② **宫格不拉伸**：楼层卡 / 楼中楼卡 `ImageGrid` `capMaxWidth` false → **true（336 封顶）**——2 列后列宽 ≈494 > 336，跟随列宽会格宽 164 vs 格高 120 横向拉伸；封顶后格宽 108/120 ≈ 手机档比例，且 3 列 / 单列档列宽 ≤336 封顶不生效逐像素不变；两处卡容器均已 `alignItems Start` → 限宽后宫格靠左（主楼通栏卡 capMaxWidth 本就 true 不动）。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m23s）；**lint 0**；**待真机复验**（竖 / 横屏回复区 2 列、带图楼层宫格 336 左对齐不拉伸、分栏横屏右栏 2 列、手机与阔直屏 / 大折叠各档逐像素不变）。
> 更新：2026-09-15 · **§4.9 帖子详情页「跳转到官方贴吧」弹窗不拉伸（构建通过）**：用户拍板 → `dialogCardWidth()` 补 **400 封顶**（T-H 同款 `max(200, min(400, 屏宽−48))`）——原实现只有下限 200 无封顶，平板屏宽下弹窗拉成通栏（原注释臆测的「系统默认 400 上限兜底」实测未兜住）。手机档 312 < 400 逐像素不变。**遗留提示**：本页 `LinkConfirmDialog`（链接跳转确认自绘浮层）同为通栏宽度，未在本次拍板范围，同况待拍板。`tools/build.ps1` → **BUILD SUCCESSFUL**（27s）；**lint 0**。
> 更新：2026-09-15 · **§4.11 他人信息页平板适配落地（用户重定方案，构建通过）**：用户重新拍板 2 项并当场落地——① **发布的帖子 + 关注的吧都采用首页同款瀑布流竖 3 / 横 4**（原 §4.11「`List + lanes` 竖 2 / 横 3」方案作废）：判据从零建补齐（`isWideFormDevice` + `refreshFormMetrics()` 首帧/onAreaChange 兜底 + `profileColumns()` 闸门+≥600+横4/竖3；`isWideScreen`(840) 系底部浮槽胶囊旧判据保留不动）；两 Tab 均改**列内独立堆叠**——`ListItem > Row({space:8}) > ForEach(列索引) > Column.layoutWeight(1)`（§4.12 修复后结构：列外必须有横排 Row、内层直读 `bucketColumns(...)[colIdx]`），通用 `bucketColumns<T>()` 方案 B（阈值 240，LikeCard 等高小卡恒为纯轮转）；间距语言 = List space 8 全同源（卡片无 margin，列内 8 = 列间 8 天然一致）；`Header` / 顶部 98 占位 / 底部 160 占位保持通栏；`onReachEnd` 分页 / 骨架（columns 默认 1 红线）/ 沉浸挂点零改动。② **弹窗不拉伸**：取消关注 / 拉黑确认两处自绘浮层卡片 `calc(100%−48vp)` → **`panelWidth()` = max(200, min(400, 屏宽−48))**（T-H 同款，手机 312 逐像素不变）；排序菜单 bindMenu 宽 180 固定不受影响；LegacyShell 底部胶囊（API<26 兜底）非弹窗不动。原 §4.11 「用户信息居中已满足零改动」结论维持。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m03s）；**lint 0**；**待真机复验**（两 Tab 竖 3 / 横 4 瀑布流、弹窗居中 400 不拉伸、翻页不跳位、手机单列与弹窗 312 逐像素不变、折叠屏展开↔折叠切换）。
> 更新：2026-09-15 · **§4.7 全吧搜索平板适配落地（用户重定方案，构建通过）**：用户不按原 §4.7 方案（横屏搜索框封顶 1000 / 宽高比判据等），重新拍板 3 项并当场落地——① **底栏不拉伸**：`pillWidth()` 形态分档，平板档封顶 **480**（与首页底栏平板档同口径，同为 icon+文字三钮栏），手机档「屏宽−48」逐像素不变；② **搜吧 / 搜人页竖 3 / 横 4 列**：`ForumResults` / `UserResults` 相关吧列表、用户列表改**列内独立堆叠**（推荐位 exact 卡、空态、ModuleFooter 保持通栏）；③ **搜贴页首页同款瀑布流竖 3 / 横 4**：`PostResults` 改列内独立堆叠 + **方案 B 带滞回最短列分桶**（通用 `bucketColumns<T>()`，阈值 240；估算器按多列档口径——PostCard 标题/摘要 ≤2 行、Forum/User 卡头像行+slogan/intro ≤1 行）。判据从零建（§4.12 模板）：`isWideFormDevice` + `refreshFormMetrics()`（aboutToAppear 首帧 + 根容器 onAreaChange 兜底）+ `searchColumns()`（闸门 + ≥600 + 横 4 / 竖 3）；结构照收藏页五轮教训（外层 ForEach 遍历列索引、内层直读 `bucketColumns(...)[colIdx]`）。三个模块共居 `Tabs+TabContent` 滚动容器（非 List），无 ListItem 迁移、无骨架/预加载改动；模块对滑动画 / 沉浸属性零改动。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m12s）；**lint 0**；**待真机复验**（搜吧/搜人/搜贴三模块 3/4 列、底栏 480 居中不拉伸、翻页不跳位、手机单列逐像素不变；另注：搜吧/搜人数据当前因旧 web 端点停摆必空——多列空态即空态居中，不受影响）。
> 更新：2026-09-14 · **§4.12 间距统一（上下 = 左右 = 6vp，模拟器验收通过）**：用户反馈多列档卡片「上下间距跟左右间距不一致」→ 根因 = `ContentCard` 自带 `.margin({ bottom: Spacing.md })(12)`（单列时代承担行间距）叠加列内 `space 6` → 上下 18 vs 左右 6。修复：`ContentCard` 加 `bottomMargin` 参数——**单列档传 `Spacing.md`(12) 逐像素不变**、**多列档传 0**（间距全交外层 `Column({ space: 6 })` 承担 → 上下 = 左右 = 6）；分桶估算器同步（去 `+12` 底距、列内间距 `Spacing.md` → 6 与渲染同源）。`tools/build.ps1` → **BUILD SUCCESSFUL**（32s）；**lint 0**；hdc 装包 + 自动导航截图验收：**我的点赞页上下左右间距一致**。
> 更新：2026-09-14 · **§4.12 个人内容三界面瀑布流落地 + 模拟器装包验收通过（修「漏横排 Row」布局 bug）**：用户拍板「三个界面采用首页一样的瀑布流，竖屏 3 列 / 横屏 4 列」→ **推翻 2026-09-13 的 `List + lanes` 竖 2 / 横 3 方案**，改**列内独立堆叠 + 方案 B 分桶**（同 §4.9/4.10/§4.8 T-D 范式）。**首版 bug（模拟器装包实测揪出）**：`cols=4` 判据已生效但渲染仍通栏——多列分支把 4 列直接纵向塞进 4 个 `ListItem`，**漏了横排 `Row` 容器**（对比 §4.8 T-D 搜索页实现有 `Row({space:6})`）→ 修复：`ListItem > Row({space:6}) > ForEach(列索引) > Column.layoutWeight(1)`；连带修预加载判据（多列下内容区只有 1 个 ListItem，`end >= 列数-1` 永不成立 → 改 `end >= 1`）。**验收（hdc 全自动：install -r → aa start → uitest 点击导航 → snapshot 截图）**：我的点赞 / 我的帖子 / 浏览历史三页**横屏四列瀑布流全部正常**（各列底部收敛、卡内底行窄列无溢出）；诊断日志确证 `type=tablet w=1440 land=true cols=4`、首帧 `cols=1` 由 `onAreaChange` 兜底回填——判据链工作正常（用户此前「没变化」根因 = 模拟器跑旧包，本轮已装最新 HAP）。临时诊断日志已删、`tools/` 临时截图已清；干净包（29s）已重装模拟器。**剩余复验**：竖屏三列、折叠屏展开↔折叠切换、翻页不跳位、手机单列逐像素不变。
> 更新：2026-09-14 · **§4.8 T-D 二次更正：吧内搜索结果改「列内独立堆叠 + 方案 B 分桶」瀑布流（落地 + 构建通过）**：用户要求搜索结果「跟首页一样的瀑布流」→ 原「行分组 + 末行补空位」把矮卡下方留白拉大（有无图 / 图多图少交错时尤甚）。落地（仅动 `SearchResultsBuilder` 多列分支）：① 新增 `searchColumnsData()`（方案 B 带滞回最短列，阈值 `THREAD_SEARCH_COL_BALANCE_THRESHOLD=240`）+ `estimateSearchCardHeight()`（按 `cardColumns>1` 渲染口径：标题/摘要行数 + 单图 `min(w/1.6,220)` + 宫格 `⌈n/3⌉×min(w/3,140)`）+ `searchColIndexes()`；② 多列分支改列内独立堆叠（外层遍历列索引、内层**直读状态源** `searchColumnsData()[colIdx]`——收藏页五轮教训：外层稳定 key 复用 + 内层用传入 col = 更新断链）；新增卡片 160ms 淡入。**容器不变**：搜索态在外层 `Scroll` 内（WaterFlow 嵌 Scroll 是滚动劫持反模式），预加载 / 触底 / 自动续载全部原样；`cardColumns` 全局标记已无条件下发无需处理。§4.8 T-D 小节二次更正。`tools/build.ps1` → **BUILD SUCCESSFUL**（48s）；**lint 0**；**待真机复验**（搜索结果三/四列瀑布流、长列被补位填平、翻批不跳位不闪、单列手机不变）。
> 更新：2026-09-14 · **§4.1 进吧页平板适配开工落地（竖 3 / 横 4，构建通过待真机验收）**：用户拍板（① 最小单列宽保护不启用；② 「创建吧」卡片随流不独占；③ 顺带修弹窗封顶 + 渐显带满宽）。落地：① 列数基础设施（`pageWidth/pageHeight/isLandscape`，aboutToAppear 首帧 + 根 onAreaChange 兜底；`forumColumns()` 大屏横 4 / 竖 3、闸门 + 600 门槛、手机 2 列不变；`columnsTemplateOf()`）；② `columnsTemplate` 换 `columnsTemplateOf(forumColumns())`；③ 顺带 1：两处弹窗 `dialogCardWidth()` 封顶 400（T-H 同款，手机档 312 < 400 逐像素不变）；④ 顺带 2：顶部渐显带**弃整页 DST_IN 遮罩**（`BottomFadeOverlay`/`topFadeStop`/`fadeCoverVp` 死代码删除），改 `TopFadeBand` 背景色渐变条（高 98 = 顶栏按钮 + 标题，挂页面层列表之后、悬浮 TopBar 之前——官方 title 槽位路径 TopBar 更高不受影响），按 `docs/fade-band-fullwidth-fix.md` 经验杜绝右缘缺块。`tools/build.ps1` → **BUILD SUCCESSFUL**（29s）；**lint 0**；模拟器已装包，**待真机复验**（平板竖 3 / 横 4、折叠态回 2、手机 2 列逐像素不变、弹窗 400 封顶、渐显带满宽只盖顶栏）。
> 更新：2026-09-14 · **§4.6 宿主底栏平板横屏档（用户反馈：横屏底栏内部偏高、图标文字上下留空多）**：底栏几何由「手机 / 宽屏」两档扩为**三档**——新增**平板横屏档**（`BAR_H_WIDE_LAND=62` / `BAR_RADIUS_WIDE_LAND=31` / `ITEM_H_WIDE_LAND=50` / `ITEM_RADIUS_WIDE_LAND=25` / `PAD_V_WIDE_LAND=4`），由新增判据 `isWideLandscape()`（`isWideScreen && currentWidth > currentHeight`）驱动；**平板竖屏档（74/37/58/29/6）与手机档（66/33/54/27/4）完全不动**。同步新增 `@State currentHeight`（根 `onAreaChange` 写入）。`tools/build.ps1` → **BUILD SUCCESSFUL**（29s）；**lint 0**；模拟器已装包，**待横屏复验**（若仍觉留空可把 62 再降到 56，圆角同步 28）。
> 更新：2026-09-14 · **§4.4 五轮（加载体验优化回归修复，实测已通）**：优化"列 key 稳定化"后翻页又失效——外层 ForEach 复用列容器时，**内层拿到的还是旧的 col 数组**（数据源是外层传入值）→ 数据更新而 UI 不动（`contentH` 又恒定 1753）。修法：外层 ForEach **只遍历列索引**（`colIndexes()`，key = `ncolgrp_${colIdx}` 稳定复用），内层数据源**直接读 @State 分桶数组** `shownReplyCols[colIdx]`（每次 build 重新取值 → 增量生效）。**实测（hdc + 模拟器）**：reach end → 加载成功且 **contentH 1753 → 3064 → 4293** 持续增长，page 2→5 连续翻页 ✓。**踩坑模式（记）**：外层 ForEach 稳定 key 复用 + 内层用外层传入的数据 = 更新断链；嵌套 ForEach 的内层必须直读状态源。最终优化保留：加载前 syncAll 仅空列表执行（静默加载）、新增卡片 160ms 淡入、Scroller 记录/恢复滚动位置。诊断日志已全部移除，`tools/build.ps1` → **BUILD SUCCESSFUL**（28s）；**lint 0**；模拟器已装最终包，**待用户复验闪屏观感**。
> 更新：2026-09-14 · **§4.4 加载体验优化（翻页不再闪）**：① 加载**前**的 `syncAll()` 改为**仅空列表时执行**（列表态不看 loadState，提前同步只多一次整体重建 = 用户看到的"闪一下"），已有内容时静默加载、结果返回后一次性同步；② 分桶外层 ForEach 的 key 由 `colIdx+col.length+首元素id` 改为 **`colIdx+列数`**——数据追加时列容器复用、只增量渲染尾部卡片，杜绝"整列销毁重建"；③ 新增卡片加 `TransitionEffect.OPACITY` 160ms 淡入；④ 两个子 Tab 各配 `Scroller` + `onScroll` 记录 / `onAppear` 恢复滚动位置，加载后 UI 重建仍在原位置续接（不跳）。`tools/build.ps1` → **BUILD SUCCESSFUL**（25s）；**lint 0**；模拟器已装包，**待用户复验**（滑动到分页点是否还有闪屏 / 位置是否跳）。
> 更新：2026-09-14 · **§4.4 翻页修复四轮（真因：`@Builder` 参数按值传递，实测已修复）**：三轮结论有误（误把"截图"当证据，实际硬指标 `contentH` 仍恒定 1753）→ 继续 hilog 实证定位真因：**`@Builder` 参数按值传递**——`this.NotifyColumnsBlock(tab === Reply ? colsA : colsB)` 传的是**三元表达式**，ArkUI 规则下按值传递**只有传入"状态变量本身"才触发刷新，表达式不触发** → 分桶数据更新了但多列块永不重建（界面永远第一页）。修复：**多列 Row 内联进 TabPane**（build 上下文直接读 @State，依赖可靠建立），废弃 `NotifyColumnsBlock` @Builder。**实测（hdc + 模拟器，硬指标）**：进消息页 `contentH=1753` → 滑动翻页后 **`contentH=5728`**（内容高度增长 3 倍多 = 新卡片真实渲染）。诊断日志已移除，最终包已装模拟器启动。`tools/build.ps1` → **BUILD SUCCESSFUL**（28s）；**lint 0**。**教训（新增）**：① 列表渲染数据**禁止经 @Builder 参数传递**（尤其表达式），必须内联或改用 `@Component` / `$$` 按引用；② 验证 UI 是否更新要看**可量化的布局指标日志**（内容高度 / 节点数），不能靠"看起来对"。
> 更新：2026-09-14 · **§4.4 翻页修复三轮（hilog 实证定位真因：镜像更新未驱动渲染）**：加 `[NotifyPager]` 诊断日志 + hdc 连模拟器（Matex7，已登录）实测滑动复现——**数据层完全正常**（page 1→10、listLen 0→175、hasMore=false），但 **UI 停在第一页**（内容高度恒 1753、`notifyColumnsData` 不再被调用）→ 真因 = `@State` 镜像（shownReply）替换后，**TabPane（@Builder 经 Tabs/TabContent 嵌套 + `mirrorOf()` 方法间接取值）未被触发重渲染**。修复（数据驱动兜底）：分桶结果**主动算好写入独立 `@State`**（`shownReplyCols` / `shownAtCols`，在 `syncAll` 内随镜像同步计算），`NotifyColumnsBlock` 数据源直接读该 @State 数组（不再经方法间接取镜像）→ 装包实测翻页链路全通（bucket src=20→120、page 3→7 连续加载、UI 渲染出后续页卡片，截图实证）。诊断日志已全部移除，模拟器已装最终包。**经验**：@Builder（尤其经 Tabs/TabContent 嵌套）内通过方法间接读取 @State 的更新触发不可靠，列表类渲染数据应显式写入 @State（分桶结果 / IDataSource 同思路）。`tools/build.ps1` → **BUILD SUCCESSFUL**（29s）；**lint 0**。
> 更新：2026-09-14 · **§4.4 翻页修复二轮（数据驱动续拉）**：一轮的 onAreaChange 方案失效——`minHeight '100%'` 撑满下内容高度恒定、onAreaChange 首次触发又撞上第一页 Loading（被防重挡掉）→ 此后高度不变永不再触发。改为**数据驱动**：内容高 / 视口高记入字段（onAreaChange 写入），`loadMessages` 每页完成后**主动判断**内容高 < 视口 + 150 即续拉下一页（递归每页一次、hasMore=false / Loading 双重防重终止）；onAreaChange 触发时也同步判断兜底。**经验**：依赖布局回调的自动续拉在 minHeight 撑满场景会失效（高度不变 = 回调不来），续拉判断必须挂在数据加载完成点。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m05s）；**lint 0**。
> 更新：2026-09-14 · **§4.4 真机修复（平板翻页卡死）**：平板 3/4 列把一页 20 条摊薄后内容可能**填不满视口** → Scroll 无可滚距离、`onReachEnd` 一次都不触发 → 卡在第一页（手机单列 20 条必超屏故正常）。修复：多列分支内容 Column 挂 `onAreaChange`——内容高未超视口（+150 让位余量）即自动续拉 `loadMessages`，直到填满或没有更多（`loadState Loading` / `hasMore=false` 内部双重防重，无死循环）。`tools/build.ps1` → **BUILD SUCCESSFUL**（54s）；**lint 0**；**待真机复验**（平板进入两子 Tab 自动连续加载填满一屏、滚到底继续翻页、消息少的分类不无限请求）。
> 更新：2026-09-14 · **§4.4 消息页平板适配落地（回复 / 提到我的多列，构建通过待真机验收）**：用户拍板「回复和提到我的都采取首页一样的瀑布流，竖屏三列，横屏四列」。按本页 floor-vanish 实证（§4.4 现状注释：沉浸布局 + 虚拟滚动(List)有视口剔除误删风险，已改 Scroll 全量渲染）→ 瀑布流以**观感等价的「列内独立堆叠 + 方案 B 带滞回最短列分桶」**实现（Scroll 全量渲染，**禁止回归 WaterFlow/List 虚拟滚动**），未用 WaterFlow 容器。落地：① 基础设施 `pageWidth/pageHeight`（aboutToAppear 首帧 + NotifyContent 根 Column onAreaChange）、`isLandscape()`、`notifyColumns()`（闸门 + 600 门槛，竖 3 / 横 4）；② `notifyColumnsData()` 分桶（阈值 240）+ `estimateMessageCardHeight()`（昵称行基线 64 + 标题 1 行 + 正文 ≤3 行 fs14 + 引用 ≤2 行 + 吧名行，文本列宽 = 列宽 − 头像 44 − 间距 − padding）；③ `NotifyColumnsBlock()` 列内独立堆叠 Row；④ `TabPane` 双分支——多列 Scroll（含 minHeight '100%' 贴顶修复口径、NOTIFY_TOP_PAD 让位、底部 150、onReachEnd 平移）/ 单列原样逐像素不变。手机档闸门恒 1 列走原结构。`tools/build.ps1` → **BUILD SUCCESSFUL**（30s）；**lint 0**；**待真机验收**（平板竖 3 / 横 4 两子 Tab、列均衡、翻页不跳位、渐显带满宽、手机单列逐像素回归、折叠屏展开↔折叠）。
> 更新：2026-09-14 · **§4.3 渐显带四修（去全实段消硬切）**：用户反馈背景色条方案「内容到顶栏像被硬切」——首版渐变 [bg,0]→[bg,0.5]→[透明,1] 的前半段全实背景色让内容一进条顶就被盖死。改 **[bg,0]→[transparent,1] 线性渐变**（顶部即开始渐现，与首页挖洞式「内容从顶栏下渐现」观感一致）。`tools/build.ps1` → **BUILD SUCCESSFUL**（29s）；**lint 0**。
> 更新：2026-09-14 · **§4.3 渐显带终版方案（弃整页 DST_IN 遮罩，改 Stack 顶层背景色渐变条）**：Refresh 全宽修复后手机仍缺块（平板正常）→ 判定「整页 DST_IN 遮罩 + blendMode OFFSCREEN」的**离屏层宽度在手机上解析异常**，挂点怎么调都不可靠 → **弃用该方案**：`BottomFadeOverlay`（整页 DST_IN）删除，新增 **`TopFadeBand`**——FavContent Stack 顶层满宽（zIndex 8）**背景色渐变条**（高 132 = TopBar 98 + 分段区 ~34；`Theme.bg` → 透明三段渐变，ThreadList TopFadeBand 成品同款思路；下层是纯背景色故视觉等价渐隐），宽度跟随 Stack（全宽已被页面背景实证），彻底不依赖列表宿主宽度解析；8 处列表上的 `.overlay(BottomFadeOverlay)` + `.blendMode` 全部移除（expandSafeArea / clip 保留）。层级：盖列表内容，低于 EditBar(15) / 兜底胶囊行(13)，槽位顶栏在 Navigation title 层更高；`hitTestBehavior(None)` 不挡交互。`tools/build.ps1` → **BUILD SUCCESSFUL**（31s）；**lint 0**；**待真机复验**（四界面渐显带满宽无缺块、只盖按钮与标题区、暗色模式渐变色同步、点击不被遮挡）。
> 更新：2026-09-14 · **§4.3 渐显带三次修复（Refresh 显式全宽，缺块真因）**：用户再次截图实证四界面渐显带右缘均有竖直分界线（右侧无渐隐）。真因：四个列表的 `Refresh` 均未挂显式宽度 → 内部 `width('100%')` 相对 Refresh 测量成循环、解析为**内容固有宽** → 遮罩 / 列表不满屏。修复：4 处 `Refresh` 统一补 `.width('100%')`（挂在 Refresh 链上，与 onRefreshing 同层）。**教训**：`Refresh` / `Tabs` 等包裹型容器作滚动列表宿主时必须显式 `width('100%')`，不得依赖百分比子项反向撑宽。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m02s）；**lint 0**。
> 更新：2026-09-14 · **§4.3 渐显带二次修复（滚动条 + 覆盖区收窄）**：① ForumThreadsView 的 Scroll 丢失 `.scrollBar(BarState.Off)`（改写时被吞）→ 默认滚动条绘制在遮罩之上 → 右缘竖条 + 渐显带「右边缺一块」观感，已补；② `topFadeStop()` 手机原按视口高 20%（≈160vp > 首卡顶 110vp）盖到首卡 → **全设备统一收窄**为 `min(0.20, 132 / 长边)`（只盖顶部按钮 / 标题 + 分段切换区，用户要求），fadeCoverVp 未就绪回退 0.20。`tools/build.ps1` → **BUILD SUCCESSFUL**（56s）；**lint 0**。
> 更新：2026-09-14 · **§4.3 手机端三处修复（渐显带 / 同步提示间距 / 搜索态回归 List）**：① **同步提示贴卡**——`ListItemGroup` 组内项不吃 List space，header（占位 + 同步提示）与首卡零间距 → `FolderListHeader` / `CategoryListHeader` 根 Column 加 `margin bottom 12` 补偿；② **渐显带漏边 + 盖到内容**——遮罩 / 沉浸挂带 padding 的包裹 Column（真机驳回方案）→ **恢复挂滚动层本身**（padding 同层，与原 List 逐项同口径），两个点开列表多列分支落实；③ **搜索态手机档回归 List 单列**（原 WaterFlow 单列属虚拟滚动容器，同有 floor-vanish 风险 + 手机零回归红线），多列走 Scroll 全量渲染。**挂点纪律（新增）**：渐显遮罩 / blendMode / expandSafeArea / padding 必须与滚动容器同层，禁止再上移到外层包裹容器。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m17s）；**lint 0**。
> 更新：2026-09-14 · **§4.3 方案四入口补充：长按分类卡唤起排序面板**：用户要求平板下长按自定义分类卡也能触发排序 → 手势挂**主列表多列分支的 ListItem**（`LongPressGesture` 350ms → `openCategorySortPanel()`；不挂卡片本体——手机单列 editMode 长按拖拽会与卡片手势抢事件、面板内长按须留给拖拽）；抽出共用入口方法 `openCategorySortPanel()`（切 Custom + 持久化 + rebuild + Haptic + 开面板），排序菜单「自定义排序」与长按两入口共用；未分类卡与面板内不启用手势。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m06s）；**lint 0**。
> 更新：2026-09-14 · **§4.3 Scroll 改造两处残留修复**：① 自定义分类点开列表多列分支改 Scroll 时**包裹 Column 的修饰链被替换丢失**（padding / 遮罩 / 沉浸全无）→ 卡片贴屏幕边缘 → 补回 `width/layoutWeight/padding(lg)/clip(false)/expandSafeArea/overlay/blendMode`；② 吧分类点开列表出现**双 98 占位**（包裹 Column 旧占位 + Scroll 内新占位）→ 顶部留空翻倍 → 删外层旧占位（Scroll 内保留）。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m09s）；**lint 0**。
> 更新：2026-09-14 · **§4.3 floor-vanish 同源问题修复（两个帖子列表 WaterFlow → Scroll 全量渲染）**：用户真机反馈吧分类点开列表与自定义分类点开列表都出现 `docs/floor-vanish-viewport-fix.md` 记录的「卡片整层消失」——`WaterFlow` 与 `List` 同属虚拟滚动容器，在「`clip(false)` + `expandSafeArea` 沉浸 + 底部悬浮 Tab」场景下视口剔除错位（文档已实证与懒加载无关、换 Scroll 全量渲染必然绕过）。按文档结论修复：两列表多列分支 `WaterFlow` → **`Scroll` + `Column` 全量渲染 + 「列内独立堆叠」分桶**（`PostColumnsBlock`：`i % 列数` 轮转 + 滞回最短列补位，阈值 240，方案 B 与 §4.9 ThreadDetail 同款；估算器 = 标题 ≤2 行 + 摘要 ≤3 行 + 基线）；`CategoryThreadsView` 分页改 **`Scroll.onReachEnd`** 驱动（文档 §5：全量渲染下懒回收哨兵失效）；顶部 98 让位 / 底部 90 占位 / loadingMore 回归滚动内容内（全量渲染无「占 1 格」问题），遮罩 / 沉浸挂包裹 Column 不变；前缀稳定分桶翻页不跳位。**容器分叉终版**：等高收藏夹列表 = `List + lanes`；可变高帖子列表（吧收藏 / 分类内 / 搜索态）= `Scroll + 列内独立堆叠`。手机档原 List 单列不变。`tools/build.ps1` → **BUILD SUCCESSFUL**（59s）；**lint 0**；**待真机复验**（滚到底不再整层消失、多列无行内留白、翻页不跳位、拖拽面板不受影响、手机单列回归）。
> 更新：2026-09-14 · **§4.3 改动六 B 二次更正 + 落地（分类内帖子列表改瀑布流）**：用户核实分类内帖子（`PostCard`）高度同样不一致 → 多列分支由 `lanes` 改 **`WaterFlow`**（与 ForumThreadsView 同口径：让位 / 占位移出流、空态替换整流、遮罩挂包裹 Column、`onReachEnd` 留在流上）。**连带**：`editMode / onItemDragStart` 拖拽 API 为 List 专有、WaterFlow 不支持 → 帖子自定义排序**收进半屏排序面板**（方案四同款）：面板按当前视图分流（`selectedCategoryId` 空 = 分类卡 / 非空 = 帖子，单列 `List` 长按拖拽 + `ThreadDragPreview`，`prepend=1` + 独立 `panelThreadScroller`）；**打开面板即切 Custom**（与手机点该项语义一致，且面板内 PostCard 长按让位于拖拽）。手机档不变。`tools/build.ps1` → **BUILD SUCCESSFUL**（60s）；**lint 0**。
> 更新：2026-09-14 · **§4.3 真机第三处修复（点开列表渐显带 / 底部沉浸）**：`BottomFadeOverlay` 是整页 DST_IN 透明度遮罩（顶部 `topFadeStop()` 以上渐隐）——原挂 List 时首子项是 98 让位占位 → 渐隐只吃占位区；换 `WaterFlow` 后遮罩误挂流上、首项变卡片 → 渐隐盖到第一行卡 + 底部让位区失去渐隐露出硬边。修复：`overlay(BottomFadeOverlay)` / `blendMode(SRC_OVER, OFFSCREEN)` / `expandSafeArea` 从 `WaterFlow` 上移到包裹 `Column`（其首尾正是顶部 98 让位与底部 90 占位 → 渐隐带与让位区重新对齐），点开列表与搜索态两处同改。`tools/build.ps1` → **BUILD SUCCESSFUL**（58s）；**lint 0**。
> 更新：2026-09-14 · **§4.3 真机两处修复（落地当日）**：① **卡片行距贴紧**——`List({ space })` 不作用于 `ListItemGroup` 组内项，收组后行距全丢（手机档同受影响）→ 三处组体（收藏夹 / 自定义分类 / 分类内帖子）卡片 `ListItem` 加 `margin({ bottom: Spacing.md })` 补回等值行距；② **自定义分类"没适配"**——新建卡 / 未分类卡原在通栏 header（恒整行），0 自定义分类时整页只见两张整行卡 → 移进组体参与 lanes 分列，header 只留占位 / 同步提示。`tools/build.ps1` → **BUILD SUCCESSFUL**（59s）；**lint 0**。
> 更新：2026-09-14 · **§4.3 收藏页平板适配开工落地（改动一~七全部完成，构建通过、待真机验收）**：① 胶囊平板左对齐（两处同步）；② 收藏夹列表 `lanes(3/4)` + `ListItemGroup` 收纳通栏项；③ 点开的帖子列表 `WaterFlow`（3/4 列、通栏项移出流、无 sections）；④ 形态基础设施（`favColumns()` 竖 3 横 4 / 首帧初值 / onAreaChange）；⑤ 搜索框内嵌返回钮（两处）+ 搜索态 `WaterFlow`；⑥ **拖拽方案四落地**：回调抽共享方法参数化（prepend / Scroller），平板主列表多列浏览无拖拽，**半屏排序面板**（`bindSheet` + `ImmMaterial.sheet()`，面板内单列复用拖拽状态机、长按保留、入口不变），`CategoryThreadsView` 多列 lanes 拖拽保留（索引基准组内 0 起）；壳由讨论时的 `CustomDialog` 更正为 `bindSheet`（§6.8 实证半模态为官方 A 档槽位）；⑦ 弹窗六处 `dialogCardWidth()` 封顶 400。§6.2 留痕（A 有 2 处已规避；B/C/D 无）。`tools/build.ps1` → **BUILD SUCCESSFUL**（31s）；**lint 0**；**待真机验收**（平板竖 3 横 4 四个列表 + 胶囊左对齐 + 弹窗不拉伸 + 面板长按拖拽 + 搜索框对齐 + 手机逐像素回归 + 折叠屏展开↔折叠）。
> 更新：2026-09-14 · **§4.3 容器二次更正（更新文档，不开工）**：用户复核发现**收藏夹点开后的列表卡片高度不一致**（`PostCard` 高度随文本行数可变，首轮「宽度和高度都一致」的判断不成立）→ 改动三由 `lanes` **二次更正为 `WaterFlow` 瀑布流**；收藏夹列表（`FolderCard` 等高 80）维持 `lanes` 不变 → 两列表容器**有意分叉**（等高 `lanes` / 可变高 `WaterFlow`）。执行要点 4 条：通栏项（顶部 98 让位 / 底部 90 占位）移出流 + 空态替换整流；流内仅帖子一种格子**无需 `sections`**（§4.9/4.10 段计数竞态坑天然规避）；`PostCard` 无宫格区无 Grid 高度坑；无 scroller / `onReachEnd` / 分页零牵动。§6.2 留痕（A 有 1 处已规避；B/C/D 无）。**代码未改**。
> 更新：2026-09-14 · **§4.3 收藏页全量拍板转「已确认」（更新文档，不开工）**：用户拍板 4 项——① **列数竖 3 / 横 4**（收藏夹列表 / 点开的帖子列表 / 搜索态同口径，原「竖 2 / 横 3」作废）；② 容器（**同日二次更正**：收藏夹列表 `List + lanes`、点开的帖子列表 `WaterFlow` 瀑布流，见上条）；③ **拖拽采用方案四**（排序收进半屏 CustomDialog 面板：入口不变、面板内单列复用现有拖拽状态机 → 长按保留 + `ImmMaterial.dialog()` 沉浸光感 + 零重写；宽 `min(屏宽−48, 520)` / 高约 60% 屏；方案一 / 三出局留档）；④ **弹窗不拉伸**：六处 `dialogCardWidth()` 封顶 T-H 同款 `max(200, min(400, 屏宽−48))`，手机档 312 < 400 逐像素不变。§4.3 全部相关小节 + §三 第 3 项转「已确认」；§6.2 七步自检留痕。**代码未改，待开工**。
> 更新：2026-09-14 · **§4.3 收藏页增量讨论并入（更新文档，不开工）**：① 改动六拖拽候选新增**方案四**——排序收进**半屏 CustomDialog 面板**（入口不变：平板档点排序菜单「自定义排序」= 开面板；面板内**单列 `List` 完整复用现有拖拽状态机** → 长按触发与手机逐像素一致、拖拽零重写；宽 `min(屏宽−48, 520)` / 高约 60% 屏 / `ImmMaterial.dialog()` **官方沉浸光感成立**〔CustomDialog 是官方认可弹窗宿主，`bindSheet` 非官方槽位、页面自绘浮层 `out of scope` 均排除〕；主列表多列纯浏览、长按回归置顶语义），候选一 / 三 / 四留档待拍板；② 增量讨论 4 条：弹窗六处 `dialogCardWidth()` 封顶顺带项（T-H 同款）/ 帖子卡多列容器补「列内独立堆叠 + 方案 B 分桶」备选（默认仍推 `lanes`）/ 骨架屏 `columns` 默认 1 红线 / 拖拽常数 80/92 脆弱点备忘；§6.2 七步自检留痕（A/B/C/D 全无）。**代码未改**。
> 更新：2026-09-14 · **§4.9 / §4.10 回复区多列「列均衡」分桶（方案 B：带滞回的最短列）**：用户真机反馈「连续一列短卡 / 一列长卡时某一列被拉得特别长」，要求空位自动补位但**看上去遵从顺序**。原先轮转分桶（`i % 列数`）只保序不看高度 → 列尾差无界。改为**带滞回的最短列**：默认照常轮转（保序观感），仅当轮转目标列与最短列的**估算高差 > 240vp**（≈一张短卡高，`DETAIL_COL_BALANCE_THRESHOLD` / `SUBPOST_COL_BALANCE_THRESHOLD`）才改投最短列补位 → 小波动不乱序、失衡被钳回一卡以内。高度为**确定性估算**（正文行数×行高 + 图片宫格显式总高 + 楼中楼条 + 常数底数 128/96，同步可算、无测量循环，常数误差在列高差中抵消）；分桶为**前缀稳定贪心**：翻页追加从头重算、旧卡落列不变（不跳位），楼层 / 楼中楼定位 id 随卡走零改动。改动仅 `floorColumnsData()` / `commentColumnsData()` 两函数 + 各一估算器 + 阈值常量；单列档 / 定位 / 高亮 / 分页零改动。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m02s）；**lint 0**；**待真机复验**（长列被补位填平、横向楼层号基本递增、翻页加载不跳位、手机单列逐像素不变）。
> 更新：2026-09-14 · **§4.9 平板底栏宽度加倍（592vp，跳转框跟随拉伸）**：用户要求「平板下帖子详细页底栏在现有基础宽一倍，里面跳转框也一起跟着拉伸，正序 / 只看全部按钮跟着调整保持与底栏左对齐」→ **单点改动** `dockPillWidth()` 平板档封顶 `DETAIL_DOCK_MAX_WIDTH(296)` → **`DETAIL_DOCK_TABLET_WIDTH`(592 = 296 × 2)**；手机档保持原「屏宽 − 64」公式逐像素不变（教训红线：平板档封顶值严禁作用于手机档）。**自动跟随链（无需额外改动）**：① 官方岛 barWidth 三档 = dockPillWidth() → 岛宽 592；② 岛内跳转框（原回复框）`layoutWeight(1)` 随岛宽自动拉伸；③ 排序壳左缘公式 `(currentWidth − dockPillWidth())/2 − 16` 自动跟随新宽度 → 与岛左对齐（-16 真机微调项保留，如宽度变化后有偏差只调该值）。**跳转框内部注意**：岛宽 592 下「跳转到官方贴吧」胶囊被拉长属预期（用户点名要拉伸）；文案截断情况同步复查。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m03s）；**lint 0**；**待真机复验**（平板底栏 592 居中、跳转框拉伸无裁切、排序胶囊与底栏左缘对齐、手机底栏 329 逐像素不变）。
> 更新：2026-09-13 · **字号调节平板不生效修复（fontTick 全局广播，darkTick 同款模式）**：用户真机反馈平板上「设置-个性化-字体大小调节无法生效」，现象定位（用户确认）= **字号设置页内预览正常变化，返回后其他页面文字压根没变** → 根因 = 常驻 Tab 页处于挂载态，字号页覆盖期间 `@StorageLink('fontScale')` 虽同步了状态但**离屏缓存不重绘**（FontSizePage 注释自证的工程已知问题；Tab 页是 @Component 无 onPageShow，FontSizePage 靠自增 fontSizeTick 绕过而 Tab 页没有等价机制；darkTick 深色有广播、字号没有）。**修复 = fontTick 全局广播**：① `FontSizePage` 三处字号写入（selectLevel + 两处 pan）同步自增 `AppStorage 'fontTick'`；② 宿主 `Index.onPageShow` 返回时也自增 fontTick（覆盖"返回瞬间刷新当前 Tab"）；③ 五个常驻 Tab 页（HomeTab / ForumsTab / FavoriteTab / MessagesTab / MineTab）各加 `@StorageLink('fontTick') @Watch('onFontTick')`，回调显式回写 `this.fontScale = AppStorage.get('fontScale')` → 触发本页全部 `fs(x, fontScale)` 依赖刷新。**顺手修复**：FontSizePage `selectLevel`（点击圆点）此前只写 AppStorage 不经 FontSizeManager.setLevel → **不持久化、重启丢档**，已补。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m02s）；**lint 0**；**待真机复验**（平板调字号返回后五 Tab 页字体立即生效；切 Tab 后其他页也生效；重启后档位保持；手机行为不变）。
> 更新：2026-09-13 · **§4.9 岛壳解耦方案已回退（用户拍板：底栏保持居中）**：「平板横屏岛 / 排序壳与帖子卡左对齐」的岛壳解耦方案（内容层移出 Tabs + `FloatingIslandOnly` 纯岛壳 + 排序壳左缘 16）已按用户要求**整体回退**——底栏岛恢复**居中**于屏幕（官方沉浸材质不变），排序壳恢复公式定位 `-16`（横屏分栏修正，回撤至解耦前的值）。`FloatingIslandOnly` 死代码已删除。**经验留存**：官方岛水平定位可行路径 = 「内容层移出 Tabs + 空 TabContent 岛壳跟随容器」（本轮已实现并构建通过，被产品决策回退而非技术失败），将来若要岛靠左 / 靠右可按此复刻。当前底栏 / 排序壳状态 = 解耦前（宽度分档 296/329 + 补偿 8 两端统一 + 横屏垂直呼吸 14 + 排序壳 -16）。
> 更新：2026-09-13 · **§4.9 平板横屏：底栏岛 / 排序壳与帖子卡左对齐（岛壳解耦）**〔**已回退，见上一条**〕：用户要求平板横屏下底栏与排序按钮跟帖子卡片左对齐 → **根因 = 官方岛恒居中于其 Tabs**（barFloatingStyle 无水平偏移字段，web 查证），而原结构里 Tabs 全宽且**内容层装在 Tabs 的 TabContent 内** → 岛无法水平定位。**解法 = 平板把内容层移出官方岛**（`materialSupported && isWideFormDevice` 分支）：① `ContentLayer` 直放 Stack（与兜底路径同构，沉浸属性由内部自持）；② 新增 `FloatingIslandOnly()` —— **空 TabContent + tabBar + floatingStyle** 的纯岛壳（SortPillShell 已验证「空 TabContent + tabBar」模式可行；floatingStyle 悬浮条视觉与 TabContent 内容无关），属性与 ImmersiveDockShell 逐项一致（barHeight 66 / barBottomMargin 30+nudge / systemMaterial，无 barOverlap——TabContent 空时无布局作用）、height 固定 66；③ 岛壳装进对齐容器：横屏（splitMode）宽 = `dockPillWidth() + Spacing.lg×2` → 岛居中其中 → **岛左缘 = 16 = 帖子卡左缘**；竖屏宽 100% → 岛居中 = 原观感；④ 排序壳横屏左缘同步 = `Spacing.lg`（与岛 / 帖子卡对齐），竖屏 / 手机维持公式（手机 32 逐像素不变）；横屏垂直呼吸 14 保留。**手机分支（`materialSupported && !isWideFormDevice`）原结构零变化**；官方沉浸材质（systemMaterial）完整保留。`tools/build.ps1` → **BUILD SUCCESSFUL**（30s）；**lint 0**；**待真机复验**（平板横屏：岛 / 排序 / 帖子卡三者左缘对齐于 16；平板竖屏：岛居中如常；**空 TabContent + floatingStyle 的官方材质是否正常渲染**〔关键验证项〕；手机零变化）。
> 更新：2026-09-13 · **§4.10 楼中楼横屏分栏：左栏父楼层卡与右栏第一排卡片顶对齐（同 §4.9 幽灵占位）**：楼中楼页与帖子详情页同款处理 —— 左栏（`scrollerLeft`）首项加 `ReplyHeaderGhost()` 幽灵表头占位（与本页真表头「N 条楼中楼回复」**同几何**：15 号 bold + padding top 4 / bottom 0，随字号缩放同步），左栏 Column 改 `Column({ space: Spacing.sm })`（本页间距语言 8）与右栏同构 → 父楼层卡顶 ≡ 右栏第一排回复卡顶。仅横屏分栏分支，竖屏 / 手机零变化。`tools/build.ps1` → **BUILD SUCCESSFUL**（55s）；**lint 0**；**待真机复验**。
> 更新：2026-09-13 · **§4.9 横屏分栏：左栏主楼卡与右栏第一排卡片顶对齐**：用户真机反馈平板横屏下两者顶部错位 → 根因 = 右栏第一排卡片上方有「回复 N 条」表头（≈26vp，随字号缩放）+ `space 12`，左栏主楼卡直接顶格 → 主楼卡顶比右栏卡片顶高约一截。**修复 = 左栏（`scrollerLeft`）首项加「幽灵表头占位」`ReplyHeaderGhost()`**：与 `ReplySectionHeader` **同几何**的透明占位行（结构 / 字号 16 / padding 逐项一致，仅文字为空格 → 撑高等高、字号缩放自动同步），左栏 Column 改 `Column({ space: Spacing.md })` 与右栏同构 → 主楼卡顶 ≡ 右栏第一排卡片顶。仅横屏分栏分支（左栏），竖屏 / 手机零变化。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m03s）；**lint 0**；**待真机复验**（平板横屏两栏首排顶部对齐、字号放大后仍同步、竖屏手机不变）。
> 更新：2026-09-13 · **§4.9 平板横屏排序壳左移修正（对齐底栏最左侧）**：用户真机对比（横屏偏右 / 竖屏正常）→ 撤销「同宽盒居中」结构（横屏下仍有偏差），简化回**公式定位 + 横屏实测左移修正**：`SortPillShell` 外层 Row 恢复 `justifyContent(Start)` + `padding.left = max(0, (currentWidth − 底栏宽)/2 − (splitMode ? 28 : 0))` —— 横屏分栏下官方岛视觉左缘与公式值存在系统级偏差（真机实测壳偏右 ≈26vp），额外左移 **28vp**；竖屏 / 手机不修正（手机 32 逐像素不变）。**28 为真机微调项**（注释已标注：偏差变化时只调这一个值）。垂直呼吸维持横屏 +14。`tools/build.ps1` → **BUILD SUCCESSFUL**（58s）；**lint 0**；**待真机复验**（平板横屏排序胶囊左缘与底栏最左对齐、竖屏与手机不变；若 28 不够 / 过头，报一个大概差值即可单点微调）。
> 更新：2026-09-13 · **§4.9 排序壳与底栏对齐改「同宽盒锚定」+ 横屏垂直呼吸**〔**已撤销，见上一条**〕：用户真机反馈平板横屏「正序 / 只看全部与底栏贴在一起、且没跟底栏左对齐」（竖屏正常）→ ① **水平**：原「`(屏宽 − 底栏宽) / 2` padding 公式」依赖 currentWidth 与官方岛内边距的假设，横屏下出现 ~10vp 级偏差；改为**结构性同源锚定** —— `SortPillShell` 外层全宽 Row `justifyContent(Center)` 居中一个**与岛同宽（`dockPillWidth()`）的盒子**，官方岛（barWidth 同值）同样由系统居中 → **盒与岛完全同位**，壳在盒内 `Start`（左对齐）→ **壳左缘 ≡ 岛左缘**，任意屏宽 / 横竖屏自动成立；手机档盒宽 = 手机「屏宽 − 64」居中 → 壳左缘 32 与原公式一致 → **逐像素不变**。② **垂直**：横屏分栏（`splitMode()`）下排序行 margin bottom 追加 **14vp 呼吸**（96 → 110），竖屏 / 手机维持 96。`tools/build.ps1` → **BUILD SUCCESSFUL**（54s）；**lint 0**；**待真机复验**（平板横屏排序胶囊左缘与底栏左缘对齐、与底栏间距有呼吸感、竖屏与手机不变）。
> 更新：2026-09-13 · **§4.9 自绘方案已回退（用户要求保留官方沉浸材质）+ 悬浮条首帧重排触发**：用户明确「不考虑自绘方案，改回官方沉浸材质」→ 已撤销 `materialSupported && !isWideFormDevice` 分档，恢复无条件官方岛。首帧不齐的修复改用**「模拟旋转重排」**：旋转之所以能修好首帧不齐，本质是布局参数变化触发了系统对悬浮条的重排 → 应用层等效复刻：新增 `@State dockNudge`，`aboutToAppear` 后 300ms 置 1，令 `barFloatingStyle.barBottomMargin` 产生一次 **0.5vp 微变**（30 → 30.5，视觉不可察）→ 触发系统重排 → 槽内内容对齐。手机同样 nudge 一次（0.5vp 无感）。`tools/build.ps1` → **BUILD SUCCESSFUL**（25s）；**lint 0**；**待真机复验**（平板首帧进入 ≤300ms 内底栏自动对齐〔可能有一瞬不齐后跳正〕、旋转后仍正常、手机底栏无感变化）。**若 0.5vp 微变不足以触发重排**（旋转的重排可能由窗口尺寸变化驱动而非 margin），备选：改触发 `barHeight` 微变 / 延后 Tabs 挂载时机 / 提官方工单。
> 更新：2026-09-13 · **§4.9 平板底栏切换自绘兜底路径（绕开官方悬浮岛槽位首帧时序问题）**〔**已回退，用户要求保留官方沉浸材质**〕：用户反馈「还是一样」（`FloatingDock` 加 `justifyContent(Center)` 兜底无效）→ 判定问题在**官方 Tabs 悬浮条组件内部的槽位布局时序**（首帧槽内内容不随岛视觉居中，旋转触发系统重排才正常；应用层两次兜底——岛内内容居中声明、槽内容居中——均无法触达官方组件内部布局）。**决策 = 平板 / 大屏形态（`isWideFormDevice`）底栏改走自绘兜底路径**：`DetailRoot` 分支条件 `materialSupported` → `materialSupported && !isWideFormDevice`，平板走 `ContentLayer + BottomDock`（纯手写：`CommentBar(false)` 玻璃大胶囊 296 居中 + `ReplyControls` 同宽左缘对齐 + 补偿 8，几何完全可控、无官方组件玄学）；**手机维持官方岛**（`materialSupported && !isWideFormDevice`）零变化。**取舍（须知）**：平板底栏玻璃从官方沉浸材质变为自绘 `segGlass` + `backgroundBlurStyle(Regular)` 真磨砂（观感略异但同一套设计语言，收藏页等自绘路径同款）；官方 Navigation 标题栏槽位（顶部）平板**保留**不受影响。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m02s）；**lint 0**；**待真机复验**（平板首帧横竖屏底栏内容居中协调、无裁切；手机底栏官方岛不变）。
> 更新：2026-09-13 · **§4.9 底栏首帧不齐（旋转后才正常）修复**〔**已被下一条的自绘方案取代**〕：用户真机反馈平板「**第一次点进去**底栏内容不齐，旋转一下就正常」→ 根因 = 官方悬浮条槽位的**首帧布局时序**：槽高可能被系统临时算大（含安全区等），而 `FloatingDock` 内容 Column 默认主轴 `Start`（顶对齐）→ 内容 Row(66) 顶在槽顶、岛视觉胶囊居中于槽 → 内容整体偏上；点赞/收藏/发送（42 高）与跳转胶囊（46 高）偏移量随高度略异 → 视觉"参差不齐"；旋转触发官方岛重排、槽高算准（=66）后 Start 与居中等价 → 恢复正常。**修复 = `FloatingDock` Column 加 `.justifyContent(FlexAlign.Center)`**：无论槽首帧多高，内容 Row(66) 始终居中于槽、与官方岛视觉胶囊（同样居中于槽）**永远重合**，首帧即正确；槽高正常（=66）时与顶对齐等价 → **手机零变化**。`tools/build.ps1` → **BUILD SUCCESSFUL**（51s）；**lint 0**；**待真机复验**（平板首帧进入横竖屏底栏内容即居中、旋转后仍正常、手机首帧与旋转后不变）。
> 更新：2026-09-13 · **§4.9 底栏垂直补偿撤销分档、恢复两端统一（平板偏上复现）**：用户真机反馈平板（横竖屏）底栏内「点赞 / 收藏 / 跳转 / 发送明显没中心对齐」→ 根因 = 上一轮按指示做的「补偿仅平板移除」让**官方悬浮岛的系统留白（上多下少，与形态无关——同一系统组件）在平板原样复现**：内容整体偏上，且各元素高度不同（42/46/42）偏移量略异 → 视觉"参差不齐"。**修正 = 补偿恢复两端统一 `bottom: 8`**（内容区上移 4vp 贴合官方岛视觉中心）；手机档本就是 8 → **零变化**。**判断链复盘**：当初分档的动机（"手机被改"）实为底栏宽度收窄（已单独修正），补偿共用本身无辜——**先定位真根因再决定是否分档，不要把无辜的共用样式一并差异化**。`tools/build.ps1` → **BUILD SUCCESSFUL**（25s）；**lint 0**；**待真机复验**（平板底栏内容垂直居中协调、手机底栏不变）。
> 更新：2026-09-13 · **§4.9 手机底栏宽度收窄 —— 根因修正（「手机基线 360」假设错误）**：用户真机对比截图证实手机底栏变窄 → 根因 = 封顶 296 基于「手机屏宽 = 360」的**错误假设**；用户手机为 393vp 类主流机型，改造前 `calc(100% − 64vp)` / 「屏宽 − 64」= **329**，被写死的 296 上限**实实在在砍掉 33vp**（git diff 核对：代码改动本身如记录，错在假设不在实现）。**修正 = 封顶改形态分档**：`dockPillWidth()` 手机（`!isWideFormDevice`，含横屏 / 分屏 / 窄窗）保持原「屏宽 − 64」（下限 240）**逐像素回到改造前**；仅平板 / 大屏形态封顶 `DETAIL_DOCK_MAX_WIDTH`(296) 防通栏。消费方（官方岛 barWidth / 兜底 `CommentBar(false)` / `ReplyControls` / `SortPillShell` 定位）全部经此单点一次生效；`SortPillShell` 的动态左缘在手机档自动回到 `(屏宽−329)/2`… 即原 32（公式与原写死值在手机档恒等）。**教训（二次强化，升级为红线）：「手机基线」类写死值一律不得作用于手机档 —— 屏宽存在 360 / 393 / 384 等多档，任何针对手机的宽度收敛都必须以「屏宽 − 常数」原式保留，差异化只走 `isWideFormDevice` 闸门。**`tools/build.ps1` → **BUILD SUCCESSFUL**（26s）；**lint 0**；**待真机复验**（手机底栏恢复 329 宽与旧截图一致、平板底栏仍 296 居中不拉伸）。
> 更新：2026-09-13 · **§4.9 底栏垂直补偿形态分档（手机恢复原样）**：按用户指示把「垂直居中补偿」做成**仅平板生效** —— island Row padding 改为 `bottom: isWideFormDevice ? 0 : 8`：**手机恢复原补偿**（bottom 8，逐像素回到本轮改动前），**平板（大屏形态）无补偿**、内容由 `alignItems(Center)` 绝对居中于岛的 Y 轴几何中线。同时完成**手机底栏宽度核查**：`dockPillWidth()` / 兜底 `CommentBar(false)` / 兜底 `ReplyControls` / `SortPillShell` 左缘四项在手机档（360）改造前后数值全部为 296 / 32 —— **宽度从未被改**（所有封顶都以手机基线 296 为上限、手机恰好命中不生效）；用户感知的"手机变了"实为 padding 补偿移除导致的内容位置变化，本次分档后手机完整复原。**教训强化：共用样式差异化必须走形态闸门（isWideFormDevice），不得默认共用后事后补救。** `tools/build.ps1` → **BUILD SUCCESSFUL**（1m02s）；**lint 0**；**待真机复验**（手机底栏与改动前逐像素一致〔含内容位置〕、平板底栏内容居中于岛中线）。
> 更新：2026-09-13 · **§4.9 底栏岛内内容 Y 轴中线对齐**：用户真机反馈底栏内部内容不在岛的中线上 → 根因 = 历史遗留的「垂直居中补偿」（`padding({ top: 0, bottom: 8 })`，当初为贴官方悬浮胶囊「系统留白上多下少」的视觉中心而调）把内容区压成 58 高并**整体上移 4vp** → 内容不在岛的几何中线。**移除该补偿**（padding 只留左右 0），内容在 66 高 Row 内由 `alignItems(Center)` 绝对居中。**⚠️ 此样式为官方岛路径共用（手机 / 平板同一份）→ 两端同时回正中线**（手机底栏内容会下移 4vp 回中线；与上一次「平板改动波及手机」性质不同——这是用户点名的对齐修正，两端同一问题同一修法，已在汇报中明示）。`tools/build.ps1` → **BUILD SUCCESSFUL**（54s）；**lint 0**；**待真机复验**（平板底栏内容是否居中于岛中线、手机底栏同步回正后观感是否可接受〔若官方岛材质留白导致视觉仍偏，再按需微调并形态分档〕）。
> 更新：2026-09-13 · **§4.9 底栏岛内内容限宽改动 —— 已回退（用户驳回）**：该改动把 `CommentBar(true)`（官方岛路径）内容 Row 由 `.width('100%')` 改为 `.width(dockPillWidth() − 16)`，本意为修「跳转胶囊 / 发送钮被岛缘裁切」。**回退原因 = 破坏手机零回归**：`dockPillWidth()` 在手机档即 296 → 减 16 后手机底栏内容宽由「全屏 100%」变成 280，手机布局被改动（用户明确驳回）。同批的 chevron `.flexShrink(0)` 一并回退。**教训（务必记住）：凡以 `dockPillWidth()` 一类「手机档也有值」的量为基准做减法，都会波及手机 → 平板专属限宽必须走形态闸门或只在多列/大屏分支内生效。** 当前底栏状态回退到「封顶 296 居中 + 岛内内容 width('100%')」。
> 更新：2026-09-13 · **§4.9 底栏岛内内容裁切修复（排版对齐手机）**〔**已回退，见上一条**〕：用户反馈平板下「跳转」胶囊 / 发送钮被岛缘裁切 → **根因 = `barFloatingStyle.barWidth` 只决定「岛」的视觉宽度，tabBar 槽位内内容的布局宽仍是全屏** —— `CommentBar(true)` 原 `.width('100%')` 按全屏铺开，超出居中的 296 岛 → 两侧溢出被裁。修复：岛内 Row 宽度改为 **`dockPillWidth() − 16`**（扣除宿主 `FloatingDock` Column 的左右 padding 8×8），宿主 Column 默认交叉轴居中 → 内容与岛**精确重合**；「跳转」胶囊 `layoutWeight(1)` + 既有省略号在 296 内自适应（排版与手机一致）；顺带给跳转 chevron 补 `.flexShrink(0)` 防压缩。`tools/build.ps1` → **BUILD SUCCESSFUL**（52s）；**lint 0**；**待真机复验**（平板底栏内跳转框 / 蓝色发送钮完整在岛内、内容分布与手机一致、手机档逐像素不变〔手机 296−16=280 内布局微变需复核〕）。
> 更新：2026-09-13 · **§4.9 排序胶囊随居中底栏对齐 + 岛内内容居中**：底栏封顶 296 居中后，排序胶囊（正序/只看全部）原钉死左缘 32 会与居中的底栏"分离" → ① 官方壳路径 `SortPillShell` 定位 `padding.left` 由写死 32 改为**动态 `(屏宽 − 底栏宽) / 2`**（排序壳左缘 = 底栏左缘，同一条竖线；手机档 (360−296)/2 = 32 **逐像素不变**）；② 兜底路径 `ReplyControls` 宽度 `calc(100% − 64vp)` → **`dockPillWidth()`**（与评论条同宽同左缘，父 `BottomDock` 的 `align(Bottom)` 使两行左缘天然对齐）；③ 官方岛内 `CommentBar(true)` Row 显式声明 `justifyContent(Center)` + `alignItems(Center)`（岛宽 296 内内容分布与手机同构：固定宽钮 + 跳转胶囊 `layoutWeight(1)` 撑满）。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m07s）；**lint 0**；**待真机复验**（平板下排序胶囊左缘是否与底栏左缘对齐、底栏内容是否与手机同观感、手机档逐像素不变）。
> 更新：2026-09-13 · **§4.9 底栏不拉伸（保持手机宽度并居中）**：用户反馈平板下底部悬浮栏被拉成通栏 → 两处宽度来源同时封顶到**手机基线 296vp**（新增 `DETAIL_DOCK_MAX_WIDTH = 296`，= 手机 360 − 64）：① 官方悬浮岛 `dockPillWidth()` 原为「屏宽 − 64」（1024 下 960vp）→ 改为 `min(屏宽−64, 296)`（下限 240 保留），`barFloatingStyle.barWidth` 三档全部走它；② 兜底路径 `CommentBar(false)` 原 `.width('calc(100% - 64vp)')` → 改 `.width(this.dockPillWidth())`，父 `BottomDock` 的 `Column.align(Alignment.Bottom)` 使固定宽子项天然**水平居中**（官方悬浮条由 barWidth 决定宽、官方居中）。**手机档 360 − 64 = 296 恰好等于上限 → 逐像素不变**。`tools/build.ps1` → **BUILD SUCCESSFUL**（52s）；**lint 0**；**待真机复验**（平板下底栏是否为 296 宽且居中、官方悬浮岛是否居中〔若偏左需另加居中处理〕、排序胶囊与底栏的左右对齐关系是否可接受）。
> 更新：2026-09-13 · **§4.9 / §4.10 内容少时被垂直居中修复（Scroll 小内容默认居中）**：用户真机反馈「竖屏内容少时主楼悬在页面中部、上方大片空白；回复多时正常自上而下」→ 根因 = **`Scroll` 对「小于视口的内容」默认垂直居中**（「列内独立堆叠」改造重写竖屏分支时引入；内容超出视口时该行为不显现）。**`Scroll` 没有 `alignment` 属性**（写成 `.alignment(Alignment.Top)` 会报 `Property 'alignment' does not exist on type 'ScrollAttribute'`）→ 正确写法 = 给 Scroll 的**内层 Column** 加 `.constraintSize({ minHeight: '100%' })`：列恒占满视口高、Column 默认主轴 Start → 内容自上而下；内容多时 minHeight 不生效、滚动照常。两页共 **6 处** Scroll 全部补齐（ThreadDetail 竖屏 / 横屏左栏 / 横屏右栏 + SubPostDetail 同三处）。`tools/build.ps1` → **BUILD SUCCESSFUL**（52s）；**lint 0**；**待真机复验**（内容少的帖子 / 楼中楼主楼是否顶在顶栏让位之下、横屏两栏内容少时是否各自顶对齐、内容多时滚动正常）。
> 更新：2026-09-13 · **§4.9 / §4.10 横竖屏切换二次优化（消除"闪一下"）**：首版把 `contentOpacity` **瞬间归零**再淡入，那「内容啪地消失」的一帧正是用户新反馈的闪烁；且重建本身同步完成，并不需要提前隐藏。改为**三段全动画、无瞬间跳变**（`applySplitSwitch()`）：① `animateTo` 淡出 100ms（渐变非瞬变）→ ② `onFinish` 里才写 `isSplit`（结构切换与全量重建发生在内容不可见期，用户看不见）→ ③ 淡入 160ms。`isSplit` 的 `@Watch` 相应移除（改由该方法手动驱动）；未就绪（首屏 / 无数据）直接切、不参与动画，避开首屏 fadeIn。`tools/build.ps1` → **BUILD SUCCESSFUL**（53s）；**lint 0**；**待真机复验**（切换是否"暗一下再亮起"的柔和过渡、无空白帧闪烁、快速连转不叠加）。
> 更新：2026-09-13 · **§4.9 / §4.10 横竖屏切换平滑化（形态切换不再"卡一下"）**：用户反馈「横屏切竖屏会卡一下（左帖子右回复）才切到上帖子下回复，反之同理」→ 根因 = 横竖屏是**两套组件树**，切换必然全量重建楼层/回复卡（主线程耗时），且旋转过程中 `currentWidth` / `pageHeight` 每帧变化会让布局分支反复求值、可能多次重建。优化两条（两页同款）：① **固化分栏结果** —— 新增 `@State @Watch('onSplitChanged') isSplit`（缓存 `splitMode()` 结果），`aboutToAppear` 首帧固化、`onAreaChange` 里**只在结果真正变化时才写**，布局分支统一读 `isSplit`（不再直接调 `splitMode()`）→ 一次旋转只切一次，且横屏冷启动直接走分栏（不会先竖后跳）；② **把「硬切 + 重建」掩盖为平滑淡入** —— `onSplitChanged()` 先把内容层 `contentOpacity` 置 0、下一帧 `animateTo` 180ms 淡入到 1（仅内容已就绪时执行，避开首屏 fadeIn），根 `Stack` 已有 `backgroundColor` 故淡入不露底；楼中楼页新增 `@State contentOpacity` 并在横屏外层 `Column` / 竖屏 `Scroll` 两处同层挂载。`tools/build.ps1` → **BUILD SUCCESSFUL**（55s）；**lint 0**；**待真机复验**（横↔竖切换是否顺滑无顿挫、快速连转不叠加、内容淡入不闪底、手机旋转不受影响）。
> 更新：2026-09-13 · **§4.9 / §4.10 错位修复二（最终方案）：弃用 `WaterFlow` + `WaterFlowSections`，改「列内独立堆叠」**。用户复验反馈**仍有同样错位**（跨列文字 / 卡片重叠 / 溢出仍在）→ 首轮「`ImageGrid` 显式总高」未打中根因；结合截图新证据（楼层卡正文**横向跨越列边界**，即内容按全宽测量渲染、却被按三列摆放）定位真凶 = **`WaterFlowSections` 段计数与 `ForEach` 展开的引擎级竞态**（真机两轮复现，吧头跨列那轮也踩过「静态 FlowItem + LazyForEach 混用不稳」同类坑）。**改造**：① 两页滚动容器全部回归 **`Scroll` + `Column`**（竖屏整页 / 横屏右栏）—— 通栏项（让位 + 主楼 + 回复表头 + 哨兵）天然通栏、楼层定位 `.id` / `onReachEnd` / `overlay` / `blendMode` / `backgroundColor` / `opacity` 全部回到改造前**已验证的 Scroll 挂点**（`thread_scroll_content` / `subpost_scroll_content` 不变）；② 多列观感改 **`i % 3` 交替分桶的三列 `Row`（列内独立堆叠）** —— 瀑布流的观感本质（无行分组行内对齐留白），新增 `floorColumnsData()` / `FloorColumnsBlock()` / `FloorCardItem()`（§4.9）与 `commentColumnsData()` / `CommentColumnsBlock()` / `CommentCardItem()`（§4.10），单列档走原 `ForEach` 逐像素回归；③ 删除 `sections` / `syncSections` / `onFloorsChanged` / `onCommentsChanged` / `FloorFlowItems` / `FooterFlowItem` / `CommentFlowItems` / `lastSectionKey` 全部死代码（哨兵改普通节点 `FooterSentinel`）；④ 首轮的 `ImageGrid` 显式总高 + `capMaxWidth` 保留（对首页成品口径、无副作用）。**为什么改后不会再错位**：不再有虚拟容器的段排放 —— 普通 `Scroll` + `Column` + `Row` 布局全部同步确定，与手机单列同一条已长期验证的渲染路径。`tools/build.ps1` → **BUILD SUCCESSFUL**（23s 增量）；**lint 0**；**待真机复验**（竖 / 横屏回复区无重叠无跨列、三列观感是否紧凑、楼层定位 / 触底翻页 / 顶部底部渐隐带 / 手机单列逐像素回归）。
> 更新：2026-09-13 · **§4.9 帖子详情（`ThreadDetail.ets`）+ §4.10 楼中楼详情（`SubPostDetail.ets`）已落地（构建通过、待真机验收，承接"被打断的任务"）**。**§4.9 DT-A / DT-G / DT-H / DT-I / DT-J**：`isLandscape()` / `replyColumns()` / `splitMode()` + `DetailRoot.onAreaChange` 同点取高 + `aboutToAppear` 首帧同步取值；整页 `WaterFlow({ scroller: this.scroller, sections: this.sections })` 三段（让位+主楼+回复表头 / 楼层 / 哨兵）+ `FloorFlowItems()` + `FooterFlowItem()`（哨兵恒渲染）；楼层定位 `.id('floor_' + floorId)` + 高亮底 + 圆角 26 + `clip(true)` **四项一起进 FlowItem**；横屏分栏左栏固定 `DETAIL_MAIN_WIDTH = 420` + `scrollerLeft` 独立、右栏 `WaterFlow` 保留全部机制 → 楼层定位零改动；`ImageGrid` 一改三处共用调用点加 `.constraintSize({ maxWidth: DETAIL_IMAGE_GRID_MAX_WIDTH = 336 })` → 手机档 296 < 336 不生效（零回归）；沉沁四项上移到分栏外层 `Column`（与右栏 `WaterFlow` 同渲染层配对 → 真机复验顶部渐隐）；拍板值采用：#5 `DETAIL_MAIN_WIDTH = 420` / #6 `DETAIL_IMAGE_GRID_MAX_WIDTH = 336` / #7 维持右栏三列 + 真机复核。**§4.10 SP-A / SP-B / SP-D / SP-E / SP-G ~ SP-K**：判据函数 / `syncSections()`（**两段** = 让位+父楼层+回复表头 / 回复三列；与 §4.9 三段不同——本页无「加载更多」UI、无触底哨兵）+ 三挂点（`aboutToAppear` / `onCommentsChanged` / 形态变化，`locateNotifyTarget()` 追加 `commentsState` 由 `@Watch` 自动触发 → `itemsCount` 与子节点数严格一致）；`CommentFlowItems()`：空态补 0 高占位、`ForEach` 渲染所有 `FlowItem`；楼中楼定位 `.id('spc_' + commentId)` 随卡进 `FlowItem`、`flashHighlightComment()` 公式（`targetY - 120`）零改动；横屏左栏固定 `SUBPOST_MAIN_WIDTH = 420`（与 §4.9 同口径）；本页 `ImageGrid`（独立实现）单独加 `.constraintSize({ maxWidth: SUBPOST_IMAGE_GRID_MAX_WIDTH = 336 })`；分栏时 `overlay(BottomFadeOverlay)` + `blendMode(SRC_OVER, OFFSCREEN)` **两项**上移到外层 `Column`（根 `Stack` 的 `backgroundColor(Theme.bg)` 留在原处——差异 3）→ 真机复验底部渐隐。**三处不可照抄点（执行红线）兑现**：① 底部留白 = `Spacing.xl`(20)（不是 §4.9 的 160）；② 间距语言 = `Spacing.sm`(8)（不是 `Spacing.md`12）；③ 卡内间距判定重算（推荐写法：把间距挪到 `WaterFlow.rowsGap(Spacing.sm * 2)`、卡内追加的 8vp 按列内下标判断）。**§三 第 9 / 10 项状态列**：移除「受 §4.6 H-B 前置阻塞」标记，改为「已落地（构建通过、待真机验收）」；§4.9 / §4.10 状态行同步刷新、§6.1 / §6.2 视需要跟进。`tools/build.ps1` → **BUILD SUCCESSFUL**（53s）；**lint 0**；**待真机验收**：① 横屏分栏左栏 420 / 右栏三列窄列观感；② 竖屏三列在 1024 下的紧凑性 + 楼层定位 `getRectangleById` 可读时机；③ `WaterFlow` `itemsCount` 与 `floors` / `commentsState` 条数严格一致（含 `locateNotifyTarget()` 定位翻页追加路径）；④ 顶部渐隐带 / 底部渐隐带在分栏后是否仍正确；⑤ 楼层定位高亮底色圆角与楼层卡一致；⑥ 手机单列（含手机横屏 / 分屏 / 自由多窗窄窗）**逐像素不变**。
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
- **处置（2026-09-12 用户拍板，按推荐方案执行；本阶段仍不开工）**：
  1. **采用**：`deviceTypes` 增加 `"tablet"`；**不加 `"2in1"`**（当前不面向 PC）。
  2. **排除**：**不启用**平行视界 EasyGo → 不加 `"easyGo"`、**不新建** `resources/base/profile/easy_go.json`（理由见 §4.6：系统自动分栏会与自有多列叠成「双层分栏」）。
  3. **执行**：复核 `AppScope/app.json5` 中与屏幕、SDK 相关的声明是否需同步调整。
  4. **上架联动（2026-09-12 补，最易漏，必做）**：`docs/RELEASE_CHECKLIST.md` 第 122 行现写「设备类型 仅手机 —— `module.json5` 的 `deviceTypes`（仅 `phone`），**后台勾选须一致**」。一旦把 `"tablet"` 写进 `module.json5`，AGC 后台的「支持设备类型」勾选与该 checklist 条目**必须同步改**，否则提审会因声明不一致被打回；同时应用市场的「支持设备」展示随之变化（平板用户可见）。
  5. **执行**：声明 `tablet` 后须做一次**整体**平板验收（不能只验首页）—— 列数适配是全应用的，单页改造完就声明平板，会造成「首页对了、其它页仍是手机布局」的中间态。
- 备注：该项为整体适配的**前置项**，须在首个界面方案（§4.2 首页）落地前完成；**当前仅定处置口径，未执行**。

## 二、总则（待补充）

- 目标设备形态：平板（横屏 / 竖屏 / 可折叠展开态）
- 断点定义（待定）：
- 布局策略（待定）：拉伸铺满 / 居中限宽 / 分栏（列表 + 详情）
- 与手机端的一致性约束（待定）：
- 全局公共能力（待定）：窗口尺寸监听、栅格列数、安全区、沉浸材质槽位

## 三、界面清单与进度

| # | 页面 | 文件 | 类型 | 状态 |
|---|------|------|------|------|
| 1 | 首页 | `pages/HomeTab.ets` | 主 Tab | **已落地（2026-09-13，**方案 B 行分组** + **平板横 3 / 竖 2 列**，构建通过，见 4.2；方案 A `WaterFlow` 真机首测被否决后已回退；横屏曾因行内高度差过大收为 2 列〔决策 9〕，同日按用户拍板**撤销并恢复 3 列**〔决策 10〕）** |
| 2 | 进吧 | `pages/ForumsTab.ets` | 主 Tab | 已确认（见 4.1） |
| 3 | 收藏 | `pages/Favorite.ets` | 主 Tab | **已确认（见 4.3；2026-09-14 拍板：竖 3 / 横 4；容器分叉——收藏夹列表 `lanes` / 点开的帖子列表 `WaterFlow` 瀑布流；拖拽方案四半屏面板、弹窗六处封顶）** |
| 4 | 消息 | `pages/MessagesTab.ets` | 主 Tab | **已确认（方案 A，见 4.4）** |
| 5 | 我的 | `pages/MineTab.ets` | 主 Tab | 已出方案（待确认，见 4.5） |
| 6 | 宿主壳 | `pages/Index.ets` | 宿主 | **已确认（见 4.6）** |
| 7 | 全吧搜索（首页入口） | `pages/Search.ets` | 二级 | **已落地（2026-09-15 重定方案并开工，见 4.7）**：搜贴瀑布流竖 3 / 横 4（列内独立堆叠 + 方案 B）、搜吧 / 搜人 3 / 4 列、底栏平板档锁 480 不拉伸；多列例外页 |
| 8 | 吧内帖子列表 | `pages/ThreadList.ets` | 二级 | **已确认（见 4.8；多列二级页，受 §4.6 H-B 前置阻塞）** |
| 9 | 帖子详情 | `pages/ThreadDetail.ets` | 二级 | **已落地（见 4.9；DT-A/G/H/I/J 已落地、构建通过、待真机验收；`DETAIL_MAIN_WIDTH=420` / `DETAIL_IMAGE_GRID_MAX_WIDTH=336` / 右栏维持三列）** |
| 10 | 楼中楼详情 | `pages/SubPostDetail.ets` | 二级 | **已落地**（见 4.10；SP-A/B/D/E/G-K 已落地、构建通过、待真机验收；`SUBPOST_MAIN_WIDTH=420` / `SUBPOST_IMAGE_GRID_MAX_WIDTH=336`、段数=2、间距=8、底部留白=20 三处差异兑现） |
| 11 | 个人内容 | `pages/PersonalContent.ets` | 二级 | **已落地（2026-09-14，见 4.12 二次拍板）**：用户拍板「首页同款瀑布流竖 3 / 横 4」推翻原 lanes 方案 → 列内独立堆叠 + 方案 B 分桶落地，构建通过待真机验收；命名易混：本页**无用户信息区**，只有槽位标题栏 + 单一 `List` |
| 12 | 用户主页 | `pages/UserProfile.ets` | 二级 | **已落地（2026-09-15 重定方案并开工，见 4.11 二次拍板）**：发布帖 + 关注吧瀑布流竖 3 / 横 4（列内独立堆叠 + 方案 B）、确认弹窗封顶 400 不拉伸；用户信息 Header 保持通栏居中 |
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

> 命名澄清：表中「全吧搜索」是唯一的独立搜索**页面**（首页右上角入口，须单独适配，「搜吧 / 搜贴 / 搜人」三模块）。
> 另有几处「搜索」是**页内状态**、不是独立页面，本清单不单列：`Favorite.ets` 收藏页搜索（`enterSearch` / `exitSearch`，本地过滤）、`ThreadList.ets` 吧内搜索（`openSearch` / `startSearch`，`FSEARCH` 协议 + 本地兜底）。
> 已清除（2026-09-12）：`HomeTab.onOpenFavorite` 死参数与 `favOpenSearchRequest` 死通道（「首页搜索 → 切收藏 Tab 打开本地搜索」旧联动）**已全部删除**，详见 §4.6 的 H-F。

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
- 横屏：卡片显示 **3 列**（2026-09-13 经决策 9 收为 2 列，同日按用户拍板**撤销**、恢复 3 列，见决策 10）

> **已确认（2026-09-11）**：「竖屏 / 横屏」指**平板与折叠屏**形态；**手机端不需要 2 列**，维持现状单列不变。
>
> **2026-09-13 两度调整（决策 9 → 决策 10）**：横屏先由 3 收为 2 —— 真机 3 列下同行「9 图卡 vs 无图文本卡」高度差可达 ~400vp、行分组顶对齐后观感即用户反馈的「大量错位」；同日用户拍板**恢复 3 列**，落差不消除、改由「决策 6 摘要降 2 行 + 图片封顶」削弱，行内留白按 A6「接受」。两次调整均**只改列数判据、不动容器与卡片内部几何**，手机端零影响。

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

> **已选定方案 A（2026-09-12 用户拍板）**。方案 B / C 转为留档与**回退路线**。选 A 即须接受其唯一硬前置：**落地前先做 `WaterFlow` 真机 A/B**（见本章末「补充风险提示」与决策 7）。

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

**卡片内部几何的连带影响（已确认本轮执行，2026-09-12，见决策 6）**

> **生效范围硬约束**：以下比例化只在**多列档（列数 ≥ 2）**生效；**单列（手机 / 窄窗）必须逐像素保持现状**（单图仍 `height(220)`、摘要仍 `maxLines(4)`）—— 这是手机零回归的验收基线。
>
> **实现口径（建议）**：`ThreadCard` 复用其内部已有的全局读取先例（`@StorageLink('fontScale')`），新增一个只读全局列数标记（如 `@StorageProp('cardColumns') : number = 1`），卡内按 `this.cardColumns > 1` 分支 —— **无需改任何调用点**。当前 `ThreadCard(` 共 4 处调用（`HomeTab.ets:1384` / `1498`、`ThreadList.ets:2044` / `2822`），若改用 prop 传参则 4 处都要改，不推荐。

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
- 处理建议 → **已定（2026-09-12，采用夹取，见决策 5）**：按视口高夹取 `min(max(视口高 × 0.15, 108), 180)`。
  - **为何不用固定值**：顶栏需求约 102vp，固定 110 虽够横屏，却会把**竖屏**渐隐带从 ~180vp 砍到 110vp，竖屏观感反而变浅；夹取则竖屏取 180、横屏保底 108，两端都不吃亏。
  - **108 的来历**：顶栏需求 `44 + 38 + 20 ≈ 102`，向上留 6vp 余量。该公式与 §4.3 / §4.4 的同类处理（§6.1 风险 B5）**共用同一写法**，三页口径一致。
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

> **补充风险提示（2026-09-12，据消息页方案 §4.4 反查）**：本方案 A 选用的 `WaterFlow` 属**虚拟滚动容器**。`docs/floor-vanish-viewport-fix.md` 已实证记录「沉浸（`clip(false)` + `expandSafeArea` + 页面底部悬浮控件）+ 虚拟滚动容器」组合下**列表项滚到某条横线后整层不绘制**的问题（`List` 已实锤，`WaterFlow` 属同类容器、尚未验证）。首页与消息页都是沉浸 + 自绘悬浮底栏结构，因此落地本方案前建议先做一次真机 A/B（换 `WaterFlow` 后长列表上下滚动，确认卡片不消失）再继续；若复现，回退路线见 §4.4「方案 A（不换容器）」。

**已确认决策（续，2026-09-12）**

4. **选型：方案 A（`WaterFlow` 瀑布流）曾采纳，但真机首测被否决 → 最终采用方案 B（`Scroll` + `Column` 内按行分组，不换容器）**。方案 A 的理由（卡片高度不可控、瀑布流无行内留白）不抵真机观感代价：用户反馈「横竖都严重错位 + 图片过大」，故回退方案 B；行内高度差留白 + 决策 6「摘要降 2 行」即本页既定取舍（方案 A 被否决时该降行已为必做）。
5. **渐隐带：采用按视口高夹取** `min(max(视口高 × 0.15, 108), 180)`；**不采用固定值**（理由见上节）。
6. **卡片内部几何比例化：本轮执行**（单图 `aspectRatio`、多图格高比例化、大屏摘要降 2 行），但**严格限多列档生效**，单列逐像素不变（口径见上节）。
7. **口径统一结论（2026-09-12 用户拍板，取推荐最优解）：统一在「判据层」，不统一在「容器层」。**
   - 本页换 `WaterFlow`、§4.4 消息页不换容器，**方向相反但不矛盾** —— 两页结构不同、各自最优，因此**不做容器层面的统一**，也不据此推翻 §4.4 的已拍板结论。理由：
     - 强行统一到 `WaterFlow`：消息页须推翻已拍板结论，**主动引入该页已被实锤**的 `floor-vanish` 风险，收益仅是省留白 —— 而它已用「大屏定高 + 裁行」解决留白，本不需要瀑布流。
     - 强行统一到「不换容器」：本页卡片高度**不可控**（摘要 0~4 行 + 图片三态），只能靠「摘要降 2 行 + 比例化」硬压，行内留白仍由最高卡决定；且本页 `floor-vanish` 属**同组合、未复现**（未验证），风险性质与消息页的「已实锤」不同。
   - **真正需要跨全应用统一的三项**：① 形态判定单一函数（`isWideFormDevice` / `isLandscape` / `pageWidth`，与 §4.1 / §4.6 同源，收口到 `Theme.ets` 的 `Breakpoint`，见 §4.6 H-B）；② 断点与列数门槛单一来源（600 / 840 / 1440）；③ 内容左右外边距单一来源（`Spacing.lg = 16`）。
   - ~~**`WaterFlow` 真机 A/B 升级为本页专属前置门**~~ **（已失效）**：方案 A 真机首测即被否决、未进入 A/B 门；容器已回退方案 B（不换容器），决策 6 的「摘要降 2 行」在多列档保留。
8. **行等高 + 互动栏底对齐（2026-09-13 用户指示「先试试」→ 已尝试，因最高卡操作栏消失 bug 回退）**：多列档行分组下试图把同行卡片拉到**该行最高卡的高度**、用卡内 `Blank()` 垫片把互动栏压到底。真机实测结果：**① 行等高未生效**（卡片仍按自身高度渲染）；**② 同行最高卡的操作栏直接消失**（分享/评论/赞三按钮不可见）。已于 2026-09-13 回退到方案 B 原状态（`Row({ space: Spacing.md })` + `VerticalAlign.Top`），行内高度差留白恢复为「接受」。
   - **失败原因分析（已写入 §6.1 A7，作为后续踩坑档案）**：`Flex({ alignItems: ItemAlign.Stretch })` 在自定义组件 `ThreadCard` 上未能按预期拉伸交叉轴；同时插入的 `Blank()` 与 `ThreadCard` 内部 `Column` 的测量交互导致**最高卡的操作栏被挤出可见区域或高度塌陷**。具体根因未在真机前进一步排查（用户指令为「先试试」，出现功能 bug 即回退）。
   - **回退后状态**：`Row({ space: Spacing.md })` + `alignItems(VerticalAlign.Top)` + `ThreadCard` 内部无 `Blank()`；`Skeleton.ets` 也回退到 `Row` 行分组、无 `@Prop stretch`。构建 `BUILD SUCCESSFUL`。
9. ~~**横屏列数 3 → 2（2026-09-13 用户取「方案 A」：只改列数，不动容器与卡片内部）**~~ **（已于同日撤销 → 见决策 10）**：`homeColumns()` 由 `this.isLandscape() ? 3 : 2` 改为恒 `2`（大屏横竖统一 2 列；手机 / 窄窗仍 1 列，首行 `isWideFormDevice` 闸门未动）。**理由**：行分组下同行高度差由「图片档位」决定（0 / 100 / 140 / 200 / 220 / 280 / 300vp，再加文本区差异 ≈ 94vp），最极端「9 图卡 vs 无图文本卡」可达 ~400vp；横屏 3 列时列宽变宽、更多单图卡触到 220 封顶，极端组合在每行出现的概率更高，观感即「大量错位」。收 2 列后**同行只剩 2 卡**、极端组合概率与落差观感同步下降，且列宽变宽、单图仍 220 封顶（不出现「图比手机大」）。
   - **未消除项（如实记录）**：2 列**不消除**行内高度差留白（A6 仍为「接受」）。要彻底消除只有两条路：①「卡片定高 + 内容截断」（会损失 9 图卡内容）；②「列内独立堆叠」（工程量大，需重写排序 / 加载 / 骨架 / 预加载）。本轮不做。
   - **连带删除**：`isLandscape()` 已无调用点 → 删除；`pageHeight` 保留（形态挂点仍维护，供将来「仅横屏另给口径」复用）。列数消费方 `homeRows()` / `homeRowBlanks()` / `cachedCount` / 骨架 `columns` 全部经 `homeColumns()` 取值 → **单点判据，自动跟随**。
   - **验证**：`tools/build.ps1` → `BUILD SUCCESSFUL`；改动前备份 `HomeTab_20260913_landscape2col.ets`。
   - **跨页口径提示（非本轮范围）**：本次只调首页。其它多列页横屏仍为 3 列（§4.3 收藏 2/3、§4.7 `Search` 1/2/3、§4.8 `ThreadList` 2/3、§4.11 `UserProfile` 2/3），与首页**横屏不再一致**；若后续要求全应用统一，收敛点在各页「列数映射」函数（`homeColumns()` / `favColumns()` / `resultColumns()` / `threadColumns()` / `profileColumns()`…），改法与本决策同构（单点判据，一次一行）。**注意区分**：§4.8 所记「采用首页 / 消息页同款」指的是**判据口径**（`isWideFormDevice` + `pageWidth ≥ 600` + 宽高比），**不是列数映射**，故本决策不构成对 §4.8 的推翻。
10. **撤销决策 9、恢复横屏 3 列（2026-09-13 用户拍板「现在方案 B，横屏还是改为三列」）**：`HomeTab.ets` 恢复 `isLandscape()`（`pageWidth > pageHeight` 宽高比判定，不用宽度阈值）并把 `homeColumns()` 末行改回 `this.isLandscape() ? 3 : 2` —— 大屏**横屏 3 / 竖屏 2**；手机 / 窄窗仍恒 1 列，首行 `isWideFormDevice` 闸门未动。
    - **改动范围**：仅「列数判据」一处（+ 恢复 1 个私有方法及其注释）。容器（`Scroll` + `Column` + 行分组 `Row` + `VerticalAlign.Top`）、卡片几何（摘要 2 行 / 单图 220 封顶 / 多图格 100·140 封顶）、骨架屏、预加载、`cardColumns` 全局标记**全部零改动**；列数消费方 `homeRows()` / `homeRowBlanks()` / 骨架 `columns` 经 `homeColumns()` 单点取值 → **自动跟随**。
    - **代价（如实记录）**：行内高度差留白回到决策 9 之前的水平 —— 横屏 3 列下列宽变宽、更多单图卡触到 `maxHeight 220` 封顶，「9 图卡 vs 无图文本卡」的极端组合出现概率高于 2 列；A6 仍为「接受」，彻底消除仍只有「定高 + 裁内容」或「列内独立堆叠」两条路。
    - **验证**：`tools/build.ps1` → `BUILD SUCCESSFUL`（45s）；改动前备份 `HomeTab_20260913_restore3col.ets`；还原后与横屏 3 列基线文件 `HomeTab_20260913_landscape2col.ets` 逐行比对 → **仅剩注释差异，无逻辑残留**。
    - **跨页口径（决策 9 的提示同步失效）**：首页横屏回到 3 列后，与 §4.3 收藏（2/3）、§4.7 `Search`（1/2/3）、§4.8 `ThreadList`（2/3）、§4.11 `UserProfile`（2/3）的横屏列数**重新一致**；各页仍是各自的「列数映射」函数，全应用统一口径仍记在 §4.6 H-B 落地时的统一项。
11. **行等高 + 互动栏底对齐（第二次尝试：先最小 Demo 实证再落地，2026-09-13）—— 决策 8 的根因已定位，本轮已落代码、待真机验收**：决策 8 失败于「① 行等高未生效；② 最高卡操作栏消失」，本轮**先不碰主源码**，改用独立最小验证页（临时页 `pages/PilotStretch.ets`，验收后已删除、入口 `EntryAbility` 与 `main_pages.json` 同步还原）在同一台真机上跑 6 组对照，**实测读数（vp，取自动态测量探针）**：
    | 组 | 行容器 | 卡根高度 | 高卡 | 矮卡 | 结论 |
    |---|---|---|---|---|---|
    | ① | `Row` | 无（现状基线） | 680×302 | 680×142 | 现状：矮卡矮一截、卡外露底 = 「留空」 |
    | ② | `Row` | `height('100%')` | 440×1328 | 440×1328 | ❌ 行被 `Scroll` 无限撑高，不是行内等高 |
    | ③ | `Flex(Stretch)` | 无 | 440×302 | 440×142 | ❌ 容器自身拉不动子项 |
    | ④ | `Flex(Stretch)` | `height('100%')` | 680×848 | 680×848 | ✅ 等高 |
    | ⑤ | ④ + 根 `Column.justifyContent(SpaceBetween)` | 680×848 | 680×848 | ✅ 操作栏可见且在卡底、三胶囊点击计数正常 |
    | ⑥ | ④ + `justifyContent(SpaceBetween)` | 680×848 | 680×848 | ✅ 同上（`Blank()` 的等价写法） |
    - **根因定位**：决策 8 缺的不是 `Blank`，而是**卡根（或卡片调用点）的 `height('100%')`**。`Flex` 的 `ItemAlign.Stretch` 只把交叉轴的「建议尺寸」交给子项，子项自身不声明 `100%` 时仍按内容高度渲染（组③）→ 即「行等高未生效」；同理卡根高度未定时，`Blank()` 的剩余空间计算失去参照（组② 的 `1328` 是同类失控）→ 操作栏被推出可见区。
    - **三条件（缺一不可）**：① 行容器 = `Flex` + `alignItems: ItemAlign.Stretch`（`Row.alignItems` 只接受 `VerticalAlign`、枚举无 `Stretch`）；② 卡片根 / 调用点 `height('100%')`；③ **内容区 `.layoutWeight(1)` 占满剩余空间** + **根 `Column` 的 `.constraintSize({ maxHeight: 560 })` 上限护栏** —— `Blank()` / `SpaceBetween` 在含 `Grid`/异步图片的复杂卡内均会因高度测量失控而失效（多宫格卡操作栏丢失、纯文本卡被 Scroll 无限高度异常拉长），故改用「内容区主动占满 + 根高度上限」的确定写法。
    - **本次落地**：`HomeTab.ets` 两条 feed 的多列行分组容器 `Row` → `Flex({ alignItems: ItemAlign.Stretch, space: { main: LengthMetrics.vp(Spacing.md) } })`（新增 `import { LengthMetrics } from '@kit.ArkUI'`），卡片调用点补 `.height('100%')`；`CommonComponents.ets` 的 `ThreadCard` 按 `cardColumns > 1` 给内容区加 `.layoutWeight(1)`（占满剩余空间、操作栏自然贴底）并给根 `Column` 加 `.constraintSize({ maxHeight: 560 })`（防止 `Scroll` 无限高度经 `height('100%')` 把卡片异常拉长）；`Skeleton.ets` 多列分支同步（`@Prop stretch` + 纸面 `height('100%')`）。**与决策 8 的差异 = 新增第 ② 条 + 第 ③ 条由 `Blank()`/`SpaceBetween` 改为「内容区 `layoutWeight(1)` + 根 `constraintSize` 上限」**。
    - **仍待真机验收（4 项）**：① 矮卡是否被拉到与同行最高卡等高、底边齐；② **同行最高卡的操作栏三胶囊是否可见可点**（决策 8 的翻车点，重点看）；③ 末行补位后卡宽是否与其它行一致；④ 手机单列是否逐像素不变。

**状态**：**已落地（2026-09-13，改用方案 B：`Scroll` + `Column` 内按行分组，`tools/build.ps1` 构建通过）**。方案 A `WaterFlow` 于真机首测被用户否决（横竖均「错位 + 图片过大」），**已回退方案 B**；行内高度差留白（A6）经 2026-09-13 首次尝试「行等高 + 互动栏底对齐」**因最高卡操作栏消失 bug 回退**，**同日经最小 Demo 定位根因（缺卡根 `height('100%')`）后按决策 11 重新落地**（构建通过，**待真机验收**）；其余口径不变（口径统一于判据层 / 渐隐带夹取 / 卡片几何比例化限多列档 / `deviceTypes` 前置 + 上架联动；形态为平板与折叠屏**横屏 3 列 / 竖屏 2 列**（决策 10 已撤销决策 9 的「横竖统一 2 列」）、手机单列、**不引入 `LazyForEach`**）。

**落地清单（2026-09-13 执行；容器选型已由方案 A `WaterFlow` 回退为**方案 B 行分组**，决策 1~10 仍全部落地）**

| # | 落点 | 内容 |
|---|------|------|
| 1 | `entry/src/main/module.json5` | `deviceTypes` 加 `"tablet"`（§1.6 前置项；**未加 `"2in1"`**；上架后台联动待上架时执行） |
| 2 | `common/Theme.ets` | 新增 `Breakpoint`（`sm 600` / `md 840` / `lg 1440`）与 `CARD_COLUMNS_KEY = 'cardColumns'` |
| 3 | `HomeTab.ets` 两条 feed | **方案 B（行分组，不换容器）**：保留 `Scroll + Column`；多列档用 `homeRows()` 按列数切行 → `Row({ space: Spacing.md })` 内卡片 `.layoutWeight(1)` 等宽均分、`.alignItems(VerticalAlign.Top)`、行距 `Spacing.md`，末行用 `homeRowBlanks()` 补等宽 `Blank`；**单列档显式走原 `ForEach` 逐像素不变**（§4.8 硬约束②）；**多列档列数 = 横 3 / 竖 2**（决策 10 已撤销决策 9 的「横竖统一 2 列」，恢复 `isLandscape()` 宽高比判定）；底部 150 让位保持原结构；**决策 11（2026-09-13）起行容器再换 `Flex({ alignItems: ItemAlign.Stretch, space: { main: LengthMetrics.vp(Spacing.md) } })`、卡片调用点补 `.height('100%')`**（末行仍补等宽 `Blank`，单列档仍走原 `ForEach` 逐像素不变） |
| 4 | `HomeTab.ets` 预加载 | **恢复 `onAreaChange` 量内容高**（方案 B 保留 `Scroll`，内容高可取）：`HOME_PREFETCH_DISTANCE = 1200`，`onHomeScroll` 中「剩余距离 < 阈值」提前静默加载 + 120vp 偏移节流；`onHomeContentAreaChange` 处理「不满一屏」直取；`onHomeViewportAreaChange` 按 feed 记录视口高。字段恢复 `homeContentH` / `folContentH` / `folViewportH` / `homeLastPrefetchY` / `folLastPrefetchY`，删除 `HOME_PREFETCH_ROWS` / `onHomeScrollIndex` / `triggerHomePrefetch` / `homeLastPrefetchIdx` |
| 5 | `HomeTab.ets` 形态判定 | `isWideFormDevice`（`deviceInfo.deviceType` `tablet`/`2in1` + `display.isFoldable()`）/ `homeColumns()`〔**首行 `if (!isWideFormDevice) return 1`；大屏横屏 3 / 竖屏 2（`isLandscape()` 宽高比判定）**〕/ `syncCardColumns()` / `onHomeFormAreaChange()` / `updateFadeStop()` / 行分组 `homeRows()` / `homeRowBlanks()` / `homeRowKey()`；`aboutToAppear` 用 `display.getDefaultDisplaySync()` 同步取首帧宽高（`homeColumnsTemplate()` / `onHomeScrollIndex()` 已随方案 B 删除；`isLandscape()` 于决策 9 曾删除、**决策 10 已恢复**——横竖分档需它） |
| 6 | `HomeTab.ets` 渐隐带 | 停靠点由固定 `0.15` 改为 `min(max(视口高 × 0.15, 108), 180) / 视口高`（`HOME_FADE_MIN = 108` / `HOME_FADE_MAX = 180`） |
| 7 | `components/CommonComponents.ets` | `ThreadCard` 走 `@StorageProp('cardColumns')`：摘要 `maxLines(cardColumns > 1 ? 2 : 4)`；单图多列档 `aspectRatio(1.6)` **并加 `constraintSize({ maxHeight: 220 })` 封顶**（防止列宽变宽后图高被同比放大）；多图格多列档 `aspectRatio(1)` **并加 `constraintSize({ maxHeight: 2/4 张 140、其余 100 })` 封顶**（**限多列档，单列逐像素不变**）；**决策 11（2026-09-13）：同一 `cardColumns > 1` 分支下内容区设 `.layoutWeight(1)` 占满剩余空间、根 `Column` 设 `.constraintSize({ maxHeight: 560 })` 上限护栏**，内容区置顶、操作栏自然贴底（配合行容器交叉轴拉伸 = 等高 + 按钮贴底；`Blank()` / `SpaceBetween` 在含 `Grid`/异步图片的复杂卡内均因高度测量失控失效，故改用确定写法） |
| 8 | `components/Skeleton.ets` | `ThreadListSkeleton` 增 `@Prop columns: number = 1`；`columns > 1` **改走方案 B 行分组**（`skeletonRows()` / `skeletonRowIdx()` / `skeletonBlanks()`，与真实列表同结构）、默认 1 走原 `Column`（Loading → 内容无列数 / 结构跳变）；**决策 11（2026-09-13）：`ThreadCardSkeleton` 增 `@Prop stretch: boolean = false`（默认单列不拉伸；首页骨架传 `true` → 纸面 `height('100%')`），多列分支同步换 `Flex` + `Stretch`** |
| 9 | 跨页标记防残留 | `syncCardColumns()` **无条件写**（含单列写 1），`aboutToAppear` / `onPageShow` / `onAreaChange` 三处都写；`ThreadList.ets` 显式写回 `1`（本页多列未落地）—— 对 §6.1 D1 / D6 |

**待办**：无。方案 A 的 `WaterFlow` 真机 A/B 前置门（`floor-vanish` 虚拟滚动风险）**已随容器回退方案 B 一并消除**（`Scroll` 全量渲染，非虚拟滚动）；决策 6 的「摘要降 2 行」仍在多列档保留（行分组下进一步压缩行内落差）。**2026-09-13 决策 8「行等高 + 互动栏底对齐」已尝试并回退**：真机出现「未拉伸对齐 + 最高卡操作栏消失」bug，已回退到 `Row({ space: Spacing.md })` + `VerticalAlign.Top`，行内高度差留白仍按 A6「接受」处理。**同日（2026-09-13）已按决策 11 重新落地**：先用独立最小 Demo（`pages/PilotStretch.ets`，已删）在真机上实证三条件，定位到决策 8 的真正缺失项是**卡根 `height('100%')`**，随后改回 `Flex(Stretch)` + 卡片调用点 `.height('100%')` + `ThreadCard` 内容区 `.layoutWeight(1)` + 根 `constraintSize({ maxHeight: 560 })`（首落用 `Blank()` 复现多宫格卡操作栏丢失，再改为 `SpaceBetween` 仍异常拉长，最终改用确定写法），构建通过；**待真机验收 4 项见决策 11**（重点：同行最高卡的操作栏是否可见可点）。**同日（2026-09-13）决策 12 已完成全面替换**：`WaterFlow` 瀑布流最小验证页 `pages/PilotWaterFlow.ets` 真机通过后已删除，`EntryAbility` 入口已切回 `pages/Index`；`HomeTab.ets` 两条 feed 的多列分支统一改为 `WaterFlow` + `LazyForEach`（`ThreadDataSource` + `@Watch` 自动同步），支持**竖屏 3 列 / 横屏 4 列**动态切换；`ThreadCard` / `HomeTab` 已删除为 Flex 方案加的 `layoutWeight` / `maxHeight` / `height('100%')`；构建通过，**待真机验收**（竖屏 3 / 横屏 4 切换 + 快速滚动稳定性 + 多宫格卡操作栏 + 手机单列回归）。

**风险自检（§6.2 七步，2026-09-13 决策 11「行等高 + 按钮贴底（含卡根 `height('100%')`）」落地后重跑）**
- A 错位 → **有 1 处、已改（待真机销项）**：A6 行内高度差留白 —— 决策 11 已由「接受」升级为**主动消除**（行容器 `Flex(ItemAlign.Stretch)` + 卡片调用点 `height('100%')` + 根 `Column` 的 `justifyContent(FlexAlign.SpaceBetween)`：矮卡被拉到行高，同行底边与最高卡齐平）；**A7 结论由「不可照搬」修正为「有条件可行」** —— 2026-09-13 最小 Demo 平板实测：`Flex` + `ItemAlign.Stretch` 单独无效（组③ 矮卡仍 142）、必须叠加卡根 `height('100%')`（组④ 两卡同 848），`Blank()` 在具备确定高度参照时表现正常且不影响胶囊点击（组⑤）。A1 末行补位 / A2 卡宽来源 `layoutWeight(1)` / A3 / A4 / A5 均未动。**待真机验收**：同行最高卡的操作栏三胶囊是否可见可点（决策 8 的翻车点）。
- B 出屏 → **无**：列宽仍 `layoutWeight(1)` 均分；行容器 `width('100%')`、主轴 `space` 只占行内、未改左右外边距（`HOME_SIDE_GUTTER` 不变）；卡片仍 `width('100%')`，无横向滚动；3 列下列宽反而变窄（1280 屏可用宽 1248 → 单列 ≈ 408vp），单图 / 多图格仍受 `maxHeight` 封顶 → 纵向不会撑高。**决策 11 增补**：`Flex` 无 `wrap`、主轴 `space` 只占行内，行高仍 = 该行最高卡的**自然高**；卡片 `height('100%')` 只作用于交叉轴（纵向）且上限即行高，不产生额外纵向溢出；卡片宽度来源未变（仍 `layoutWeight(1)` + `width('100%')`）。
- C 重叠 → **有 1 处风险、已加护栏**：卡内 `Blank()` / 根 `SpaceBetween` 在复杂内容（含 `Grid`/异步图片）下均会失去确定高度参照，把操作栏挤出卡外或让卡片被 `Scroll` 无限高度异常拉长 → 决策 11 两次修正后改用「内容区 `.layoutWeight(1)` 占满剩余空间 + 根 `Column` `.constraintSize({ maxHeight: 560 })` 上限护栏」（不依赖弹性空间计算），再由「卡根 `height('100%')` 提供确定行高参照」消除风险；护栏 = 真机验收项②「最高卡操作栏三胶囊可见可点」；行内卡片仍顶对齐、拉伸后底边齐平、不互相遮盖；C1（底栏让位 150）/ C2（回顶钮几何）未动。
- D 手机回归 → **无**：`homeColumns()` 首行 `if (!isWideFormDevice) return 1` 闸门未动，本次只改「大屏形态 + `pageWidth ≥ 600`」分支的横竖映射 → 手机（含横屏 / 分屏 / 自由多窗）恒 1 列、逐像素不变；恢复的 `isLandscape()` 仅在 `homeColumns()` 内被调用（`HomeTab.ets` 唯一调用点，`Skeleton` / `ThreadList` / `UserProfile` 无引用），手机上不存在残留面；`cardColumns` 无条件写 1 机制未动（D1 / D6 无残留面），`ThreadList` / `UserProfile` 调用点零改动（D3 已防）。**必测回归路径**：平板 / 折叠屏横屏（3 列）→ 旋转竖屏（2 列）→ 折叠回单列，确认每档卡片结构正确、列数按档回落。**决策 11 增补（逐项核对）**：`Flex` + `ItemAlign.Stretch` 与卡片调用点 `.height('100%')` **只写在 `homeColumns() > 1` 的行分组分支内**（单列档仍走原 `ForEach` + `.margin` 结构，D2 已防：列宽来源仍是 `width('100%')` 而非 `layoutWeight`）；`ThreadCard` 根 `Column` 的 `justifyContent(SpaceBetween)` 由 `@StorageProp('cardColumns') > 1` 把关，单列档该属性为 `Start`（D1 / D4 复用既有「无条件写 1」机制）；`ThreadCardSkeleton.stretch` 默认 `false`、仅首页两处骨架传 `true`，`ThreadList` / `UserProfile` 调用点零改动（D3 已防）→ 手机竖屏 360 逐像素不变。**折叠屏必测**：展开（3 列，卡片等高 + 按钮贴底）→ 折叠回单列（`justifyContent` 回到 `Start`、卡片高度恢复自适应，不得残留 `height('100%')` 拉伸感）。

**风险自检（§6.2 七步，2026-09-13 决策 12「WaterFlow 瀑布流全面落地」后重跑）**：
- A 错位 → **无**：`WaterFlow` 不等高布局天然无「行内高度差留白」，卡片按最短列紧凑填充；
- B 出屏 → **无**：`columnsTemplate('1fr 1fr 1fr'/'1fr 1fr 1fr 1fr')` + `columnsGap(Spacing.md)` + `rowsGap(Spacing.md)`，列宽均分、间距固定，无横向滚动；
- C 重叠 → **无**：`LazyForEach` 虚拟滚动真机验证稳定（`floor-vanish` 未复现）；图片加载前后高度变化由 `WaterFlow` 自动重排，无重叠/错位；
- D 手机回归 → **无**：`WaterFlow` 只出现在 `homeColumns() > 1` 分支，单列档保持 `Scroll` + `Column` + `ForEach` 原结构；`cardColumns` 无条件写 1 机制不变；`ThreadCard` 已删除 `layoutWeight(1)` / `maxHeight 560`，单列自然回归原状；**必测**：手机竖屏 360 逐像素不变，折叠屏展开（多列 `WaterFlow`）→ 折叠回单列（原 `Scroll` 列表）。

**决策 12（2026-09-13）：`WaterFlow` 瀑布流全面落地（最小验证通过）** —— 决策 11 的 `Flex` 等高方案在复杂卡内失效（多宫格卡操作栏丢失、纯文本卡被 `Scroll` 无限高度异常拉长、卡片内部空白过大），故改用官方瀑布流组件 `WaterFlow` + `LazyForEach` + 自然高度 `ThreadCard`。**验证阶段**：`pages/PilotWaterFlow.ets`（临时，已删）30 条混合图数（0/1/2/3/9）真实卡片渲染，真机通过 ① 快速滚动 `floor-vanish` 稳定 ② 图片加载布局跳动可接受 ③ 多宫格卡操作栏始终可见 ④ 不等高视觉紧凑。**全面替换**：`HomeTab.ets` 推荐流与关注流两条 feed 的多列分支统一改为 `WaterFlow({ scroller })` + `LazyForEach(dataSource)` + `FlowItem` + `ThreadCard`，`columnsTemplate` 按 `this.columns === 4 ? '1fr 1fr 1fr 1fr' : '1fr 1fr 1fr'` 动态绑定，`Spacing.md` 列间距 + 行间距，左右留白 `Spacing.lg`；数据源用 `ThreadDataSource`（实现 `IDataSource`，`@Watch('onThreadsChange'/'onFolThreadsChange')` 自动同步，全量 `reload()` / 尾部 `notifyAdd()`）；列数**竖屏 3 / 横屏 4** 由 `display.on('change')`（`updateColumns()`）+ `checkFormChange()`（分屏/自由窗口兜底）驱动，同步 `AppStorage('cardColumns')` 让 `ThreadCard` 内部图片封顶/摘要行数跟随；`ThreadListSkeleton({ columns: this.homeColumns() })` 骨架同列数。**手机零回归**：`WaterFlow` 只出现在 `homeColumns() > 1` 分支（首行 `if (!isWideFormDevice) return 1`），单列档保持原 `Scroll` + `Column` + `ForEach` 结构逐像素不变；`ThreadCard` 已删除为 Flex 方案加的 `layoutWeight(1)` / `constraintSize({ maxHeight: 560 })`，`HomeTab` 已删除卡片调用点 `.height('100%')`。**待真机验收**：竖屏 3 列 / 横屏 4 列切换、快速滚动稳定性、多宫格卡操作栏、手机单列逐像素回归。

### 4.3 收藏页（`pages/Favorite.ets`）

**适配需求（用户原话）**

1. 「吧分类 / 自定义分类」两个胶囊，识别平板后**两个胶囊一起左对齐**（手机不变）
2. **竖屏**：收藏夹显示 **2 列**，收藏夹里面帖子显示 **2 列**
3. **横屏**：收藏夹显示 **3 列**，收藏夹里面帖子显示 **3 列**

> **2026-09-14 拍板更正**：列数改为**竖 3 / 横 4**（收藏夹列表与点开的帖子列表同列数，与首页 / 吧内列表口径一致），原「竖 2 / 横 3」作废。同批拍板：拖拽选**方案四**（半屏排序面板）、**弹窗不拉伸**（六处 `dialogCardWidth()` 封顶）。
> **2026-09-14 二次更正（容器）**：**收藏夹列表**（`FolderCard` 等高 80）定案 `List + lanes` 不用瀑布流；**收藏夹点开的帖子列表**（`PostCard` 高度随文本行数可变）**改用瀑布流 `WaterFlow`**——用户核实「点开后列表卡片高度不一致」，行内留白不可接受 → 改动三由 `lanes` 改判 `WaterFlow`。

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

**改动二：收藏夹列表 3 / 4 列（`FolderListView`；2026-09-14 拍板竖 3 / 横 4，原 2 / 3 作废）**

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

**改动三：收藏夹内帖子 3 / 4 列（`ForumThreadsView`；2026-09-14 拍板 `WaterFlow` 瀑布流，二次更正）**

`PostCard` **高度可变**（标题 1~2 行、摘要 0~3 行），同一行若用 `lanes` 会被最高卡撑开、矮卡下方留白。两个选项：

| 选项 | 改法 | 优点 | 代价 |
|------|------|------|------|
| **A（✅ 2026-09-14 二次拍板采用）** | 换 `WaterFlow`，`ForEach(forumThreads())` → `FlowItem { PostCard }`，挂 `.columnsTemplate(this.forumColumnsTemplate())` + `.columnsGap(Spacing.md)` + `.rowsGap(Spacing.md)` | 卡片高度各自独立，无行内留白 | 容器要换，占位/空态移出流 |
| ~~B~~ | ~~继续用 `List` + `.lanes(...)`~~ | ~~改动最小~~ | 行内高度差留白（最多差约 54vp）——**用户核实卡片高度不一致后否决** |

> **拍板沿革（2026-09-14）**：首轮拍「`lanes` 不用瀑布流」（理由「宽度和高度都一致」）；同日用户复核发现**点开后的列表卡片高度并不一致** → **二次更正为瀑布流（选项 A）**。收藏夹列表（`FolderCard` 等高 80）维持改动二 `lanes` 不变——两列表容器**有意分叉**：等高用 `lanes`、可变高用 `WaterFlow`。

**执行要点（本项换容器的四件事）**：

1. **结构**：`Refresh > Column { 顶部 98 占位（通栏）、WaterFlow、底部 90 占位（通栏） }`——顶部让位与底部占位**移出流**（占 1 格的通栏项严禁进 `WaterFlow`，§6.1 第 3 步红线）；空态时整个 `WaterFlow` 替换为 `EmptyView`。
2. **无需 `sections`**：本流内**只有帖子一种格子**（无跨列通栏项），`ForEach` 直灌 `FlowItem` 即可——§4.9 / §4.10 真机两轮复现的「`WaterFlow + sections` 段计数竞态」在此**天然规避**（该坑只在混排通栏项时触发）。
3. **无 Grid 高度坑**：`PostCard` 无缩略图 / 宫格区（仅标题 / 摘要 / 作者 / 分享行），卡片高度 = 文本自然高，`WaterFlow` 按自然高摆放无测量歧义。
4. **滚动 / 分页零牵动**：该列表本就**没有 scroller、没有 `onReachEnd`、无分页**（本地过滤全量 + `ForEach`），换容器不涉及滚动恢复与预加载重挂；`WaterFlow` 内层滚动承接 `Refresh` 下拉语义不变。

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

/** 列数：大屏横 4 / 大屏竖 3（2026-09-14 拍板）；窄窗与手机维持 1 列 */
private favColumns(): number {
  if (!this.isWideFormDevice) return 1;
  if (this.pageWidth < 600) return 1;        // 折叠态 / 分屏 / 自由多窗窄窗
  return this.isLandscape ? 4 : 3;
}

private forumColumnsTemplate(): string {
  const n: number = this.favColumns();
  if (n >= 4) return '1fr 1fr 1fr 1fr';
  if (n === 3) return '1fr 1fr 1fr';
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

**改动五：搜索态帖子列表 3 / 4 列（`SearchResultView`；2026-09-14 拍板随列数更正）**

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

> **前提变更**：用户明确要求「**平板保留拖拽**」→ 上表 **选项 A（平板关拖拽）出局**；**选项 C（重写网格让位）** 经评估性价比最差（见本节末），不作为候选。候选收敛为两条，另新增一条上表没有的路径。**2026-09-14 更新**：用户问询收敛出**方案四（半屏排序面板）**，候选从两条增至三条（见下方方案四小节）。

编号对照（对话用「方案」，本文件用字母，避免混淆）：

| 用户称法 | 实质 | 与上表映射 |
|----------|------|------------|
| **方案三** | 多列 + 交还系统原生让位 | = 上表 **选项 B** |
| **方案一** | 多列 + 不做让位 + 目标格高亮 + **自算网格落点** | 新增（上表无此项） |
| **方案四** | **排序收进半屏面板**（面板内单列复用现有拖拽，主列表纯多列浏览） | 2026-09-14 新增（上表无此项） |

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

**方案四（2026-09-14 新增：排序收进半屏面板）**

做法：多列浏览态下点排序菜单「自定义排序」（**入口不加新按钮**，平板档只是把「切模式」变成「打开面板」）→ 弹出**半屏排序面板**：`CustomDialog`（`alignment: Bottom`、高度约 60% 屏、宽 `min(屏宽 − 48, 520)`、圆角 32 / 底距 110 与同页 6 处弹窗同族），面板内是**单列 `List` 完整复用现有拖拽状态机**（`draggingCatId` / 步长 92 / `scrollBy` 跟随 / `dragListBottomPad` / `CategoryDragPreview`）→ **长按触发与手机逐像素一致、拖拽逻辑零重写**；面板「完成」→ 落盘 Custom 顺序 → 关面板，主列表多列显示自定义顺序（浏览态不变）。

- **沉浸光感成立**：`CustomDialog` 是官方认可的弹窗宿主 → `options.systemMaterial = ImmMaterial.dialog()`（与同页 6 处弹窗同机制）；`bindSheet` 半模态**不在**官方槽位清单（只有 `backgroundBlurStyle` 真模糊降级）、页面自绘 Stack 浮层必判 `out of scope`（本项目实证坑），故壳必须是 CustomDialog。
- **长按语义理顺**：主列表（多列浏览态）长按回归「置顶 / 取消置顶」（与吧收纳夹一致），不再承担拖拽 → 浏览 / 排序两态彻底分离，两个长按语义不打架。
- **与方案一 / 三对比**：零重写零风险（现拖拽实现是 v1.15→v1.19 逐版踩坑产物，能不碰就不碰）；代价 = 多一层面板壳、拖拽时看不到多列上下文（但排序时单列看顺序本就更清晰）。
- **连带项**：`CategoryThreadsView`（分类内帖子）自定义排序同理——其拖拽是标准索引语义、`lanes` 下可直接用（见下节 B），但排序时**也可收进同一面板**（单列一致体验），拍板时一并定。
- **手机档**：不弹面板，走原「切模式 + 列表内拖拽」路径，逐像素不变。

**方案四 vs 一 / 三一句话**：一 / 三是「在多列里做拖拽」，四是「把拖拽挪回它最擅长的单列」——工作量最小、风险最低，体验上限让渡给方案三（若其实机实验两个前提成立）。

**为什么不把选项 C（重写网格让位）列为候选**：多列让位在**跨行**时不是「滑动」而是「跳变」（同行内需横向挪一格，下一行首卡需跳到上一行行尾，中间没有连续路径），`translate` 只能让卡片在原位偏移，跨行那张必然是瞬移 → 观感可能比「不让位」更刺眼，且实现风险最高（等于在网格下重踩 v1.15~v1.19 全部坑），性价比最差。

**状态**：**✅ 方案四已拍板**（2026-09-14）；方案一 / 方案三出局留档（不再实机验证，不再候选）。本阶段未动代码。

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
| 6.1 | `CategoryListView` 选项 A 的功能损失 | 平板竖/横下失去长按拖动排序（手机端零影响）；若必须保留拖拽，只能走选项 B（丢虚线占位框视觉）或 C（重写让位算法）。**2026-09-12 更新**：用户要求「平板保留拖拽」→ 选项 A 出局。**2026-09-14 拍板**：候选新增**方案四**（排序收进半屏 CustomDialog 面板、面板内单列复用现有拖拽 → 长按保留 + `ImmMaterial.dialog()` 官方沉浸光感成立 + 拖拽零重写）并**拍板采用**；方案一 / 方案三出局留档，详见「候选收敛」小节 |
| 6.2 | `CategoryListView` 前置 3 项 | 占位 / 新建卡 / 未分类卡必须进 `ListItemGroup.header`，否则首行只给分类卡留 1 格；收纳后 `CAT_LIST_PREPEND`（=3）的换算基准要同步核对 |
| 7 | 搜索态**已纳入**（改动五） | 帖子列表 3/4 列（2026-09-14 拍板）；注意：搜索态**没有收藏夹卡片列表**，`searchResults()` 只返回帖子。搜索结果是 `ForEach` **全量构建**（无 LazyForEach、无分页），3~4 列后同屏可见卡片由约 3~4 张增至 12~18 张，滚动绘制压力上升（总量不变，与首页「不做 `LazyForEach`」结论同口径） |
| 7.1 | 搜索框**左右与卡片同宽**（已定稿） | 去 44 圆钮占位、返回箭头内嵌进搜索框（`Stack` 内左上 + `hitTestBehavior(HitTestMode.Block)`），宽 = 屏宽 − 32 = 网格可用宽；外层 `Stack.height(44)` 保证槽位 98 / `placeholderHeight()` 不变。代价：手机端搜索态观感变化需真机确认；若图标点击被输入框吞掉 → 降级用 `.overlay()` 挂图标 |
| 7.2 | 两处搜索框需同步 | 槽位 `FavTitleBarRow`（4449）与兜底 `TopBar`（4131）必须同改（与风险 4 同理） |
| 8 | 顶部槽位高度 | 胶囊左对齐不改变行高（2 + 40 + 8 = 50）；搜索态外层 `Stack` 保持 44（与旧圆钮同高）→ `FAV_TITLE_BAR_HEIGHT` / `FAV_CAT_TAB_ROW_HEIGHT` / `placeholderHeight()` **全部不变** |

**涉及文件**：仅 `entry/src/main/ets/pages/Favorite.ets`

**状态**：**已确认（2026-09-14 全量拍板）**。历次拍板汇总：

1. 「自定义分类」两列表（`CategoryListView` / `CategoryThreadsView`）**纳入**多列 → 见改动六。（2026-09-11）
2. 搜索框**左右与卡片网格同宽**（返回箭头内嵌进搜索框）→ 见改动五结论二。（2026-09-11）
3. **列数竖 3 / 横 4**（收藏夹列表 + 点开的帖子列表 + 搜索态同口径）；**容器分叉**：收藏夹列表（等高卡）`List + lanes` 不用瀑布流，**点开的帖子列表（高度可变）采用瀑布流 `WaterFlow`**（2026-09-14 首拍 `lanes` 同日二次更正）→ 见改动二 / 三 / 四 / 五。（2026-09-14）
4. **拖拽采用方案四**（排序收进半屏 CustomDialog 面板，长按保留 + 沉浸光感）→ 见改动六候选收敛。（2026-09-14）
5. **弹窗不拉伸**：六处 `dialogCardWidth()` 封顶 T-H 同款 → 见 2026-09-14 增量讨论第 1 条。（2026-09-14）

**改动六拖拽候选沿革（留档）**——前提「平板必须保留拖拽」（原选项 A「平板关拖拽」出局）：

- **方案三** = 交还系统原生让位（= 原选项 B）：体验上限最高、改动最小；但须先实机验证两个前提（`lanes` 下系统会网格让位 / 不返回 preview 仍有跟手预览），且**必然牵连竖屏**（须加分支隔离）。
- **方案一** = 不做让位 + 目标格高亮 + 自算网格落点：落点精度可控（前提是不裸信系统 `insertIndex`），竖屏可零改动，实现工作量居中。
- **方案四**（2026-09-14 新增）= 排序收进半屏 CustomDialog 面板（面板内单列复用现有拖拽状态机）：**长按触发保留**（面板内与手机逐像素一致）、`ImmMaterial.dialog()` 官方沉浸光感成立（CustomDialog 是官方认可弹窗宿主；`bindSheet` / 自绘浮层均不行）、拖拽逻辑**零重写**、入口不加新按钮（平板档点「自定义排序」= 开面板）；主列表多列纯浏览、长按回归置顶语义。详见改动六「候选收敛」小节。

**2026-09-14 增量讨论（同日拍板见各项标注）**

1. **弹窗六处封顶（✅ 已拍板「弹窗不拉伸」）**：本页 6 处 `dialogCardWidth()`（置顶 / 批量删除 / 分类删除 / 分类管理 / 备份 / 导出）均未封顶 → 平板下通栏拉伸（§4.8 T-H 已记的全站遗留项）。拍板采用 T-H 同款：统一为 `max(200, min(400, 屏宽 − 48))`（手机档 312 < 400 **逐像素不变**）。半屏排序面板（方案四）宽度另用 `min(屏宽 − 48, 520)`（要放列表，比确认弹窗宽一档）。
2. **帖子卡多列容器补备选**：改动三原推 `WaterFlow`；自 §4.9 / §4.10 落地后新增两条实证经验——① `WaterFlow + sections` 存在引擎级段计数竞态（真机两轮复现卡片重叠 / 列溢出，已在 §4.9 / §4.10 弃用）；② 「列内独立堆叠 + **方案 B 带滞回最短列分桶**（阈值 240、确定性高度估算、前缀稳定不跳位）」已落地验证。本页帖子卡若嫌 `lanes` 行内留白（最多差约 54vp），备选改「`Scroll` + 列内独立堆叠 + 方案 B 分桶」，但须重挂 `Refresh` / `onReachEnd` / 滚动恢复 / 空态三个占位 `ListItem`，工作量高于 `lanes`。默认仍推 `lanes`（拖拽语义最稳），方案 B 列为备选留档。
3. **骨架屏红线**：本页 `ListRowSkeleton` 若加多列分支，`columns` **默认必须 = 1**（§4.8 教训：该类共享组件默认值改了会殃及单列页）。
4. **拖拽实现脆弱点备忘**：`CATEGORY_CARD_HEIGHT=80` / `STEP=92` 是写死常数，字号放大（fontScale）或改卡结构会错位——无论最终选哪个方案，拖拽相关改动都不得再加深对该常数的耦合；方案四因完全复用现状，天然满足。

**待用户后续拍板** → **全部拍板完毕（2026-09-14）**。

**落地清单（2026-09-14 开工，全部完成，构建通过待真机验收）**：

- **改动一（胶囊左对齐）**：槽位 `FavTitleBar` 与兜底 `CategoryTabs` 两处同步——胶囊 `layoutWeight(favColumns()>1 ? 0 : 1)` + `padding 22`（饱满度），多列档行尾加 `Blank()` 吸右；手机等分逐像素不变。未抽 `CatTabPill` builder（两处玻璃实现不同，直改更稳）。
- **改动二（收藏夹列表 lanes）**：`FolderListView` 加 `.lanes(max(1, favColumns()), Spacing.md)`；通栏项（顶部让位 `placeholderHeight()` / 同步提示 / 底部 90）收进 **`ListItemGroup` header / footer**（`FolderListHeader` / `FolderListFooter`）→ lanes 下分列、header/footer 恒整行。等高 80 卡无留白，未用瀑布流。
- **改动三（点开列表瀑布流）**：`ForumThreadsView` 换 `WaterFlow`（`forumColumnsTemplate()` 3/4 列 + gap md）；顶部 98 让位与底部 90 占位**移出流**为兄弟节点、空态替换整流；无 `sections`、无 Grid 坑、无分页牵动（执行要点 4 条兑现）。
- **改动四（基础设施）**：新增 `pageWidth` / `pageHeight`（`aboutToAppear` 首帧初值 + 根 Stack `onAreaChange` 兜底）、`isLandscape()` / `favColumns()`（竖 3 / 横 4、闸门 + 600 门槛）/ `forumColumnsTemplate()`。
- **改动五（搜索态）**：搜索框内嵌返回钮（槽位 `FavTitleBarRow` + 兜底 `TopBar` 两处同步，`Stack` 左内嵌 SymbolGlyph + `hitTestBehavior(Block)`，外层高 44 槽位高度不变）；`SearchResultView` 列表换 `WaterFlow`（同改动三口径，让位 / 占位移出流）。
- **改动六（方案四拖拽 + 两列表多列）**：① 拖拽回调抽共享方法 `catDragBegin` / `catDragMove` / `catDrop`（`prepend` 与跟随 `Scroller` 参数化）+ `displaceOffsetOf(catIndex, prepend)`；② `CategoryListView` 平板多列浏览分支（`lanes` + `ListItemGroup.header` 收纳占位 / 同步 / 新建卡 / 未分类卡，**无拖拽**），手机档原结构原回调逐像素不变；③ **半屏排序面板** `CategorySortPanelContent`：`bindSheet`（62% 高、`ImmMaterial.sheet()`，与「移入分类面板」同机制同材质档）内单列 `List` 完整复用拖拽状态机（prepend=1 + 独立 `panelCategoryScroller`），入口不变（平板点「自定义排序」开面板）、完成按钮关闭 + 下滑关闭时 `resetCatDragState()`；主列表长按回归管理语义；④ `CategoryThreadsView` 平板多列分支（`lanes` + header/footer 收纳，拖拽保留，索引基准 = 组内 0 起免 -1 换算），空态替换整列表。
- **改动七（弹窗封顶）**：`dialogCardWidth()` → `max(200, min(400, 屏宽 − 48))`（T-H 同款），6 处弹窗一次生效；手机档 312 < 400 逐像素不变。
- **壳更正说明**：方案四面板壳落地用 **`bindSheet` 半模态**（`ImmMaterial.sheet()`）而非讨论时假设的 `CustomDialog`——本页 §6.8 已实证半模态为官方沉浸光感 A 档槽位（「移入分类面板」同款在用），讨论时「bindSheet 无光感」为误判；好处是面板内容可直接访问页面状态、拖拽复用零桥接。拍板意图（半屏面板 + 官方沉浸光感 + 长按拖拽保留）全部兑现。
- `tools/build.ps1` → **BUILD SUCCESSFUL**（31s）；**lint 0**。

### 4.4 消息页（`pages/MessagesTab.ets`）

**适配需求（用户原话，2026-09-12）**

- 平板**竖屏**：消息卡片显示 **2 列**
- 平板**横屏**：消息卡片显示 **3 列**
- 口径沿用 §4.1~§4.3：手机 / 窄窗（< 600vp）**维持现状单列**，手机端零改动

**现状（代码事实）**

| 位置 | 内容 |
|------|------|
| 页面结构 | `build()`（572-599）两条路径：`NOTIFY_OFFICIAL_TITLE_BAR = true` 走 `Navigation` + `title` 槽位（`NOTIFY_TITLE_BAR_HEIGHT = 108`，578），false 走 `Stack` + 悬浮 `TopBar()`（305-339）自绘玻璃兜底 |
| 内容层 | `NotifyContent()`（531-570）：未登录态直接 `EmptyView`；登录态用**无栏 `Tabs`**（544-563，`barHeight(0)`、`scrollable(true)` 支持左右滑动）承载「回复 / 提到我的」两个 `TabPane` |
| 子列表 | `TabPane(tab)`（483-528）：四态（Loading / Error / Empty / 列表），**两个子 Tab 共用同一个 builder** |
| 滚动容器 | `Scroll()` → `Column({ space: Spacing.md })` → `ForEach(list)` → `MessageCard` → 底部 150 占位 `Column`（498-516） |
| ⚠️ 容器选型约束 | 注释 496-497 明确记录：**消息卡全量渲染，因「沉浸布局 + 虚拟滚动（List）存在视口剔除误删项的风险」，刻意改用 `Scroll` + `Column` 全量真实布局规避**（依据 `docs/floor-vanish-viewport-fix.md`） |
| `MessageCard()` | 374-441。头像 `Avatar`（44）+ 名字行（`maxLines(1)`）+ 标题（**条件渲染**，`maxLines(1)`）+ 内容（`maxLines(3)`）+ 引用块（**条件渲染**，`maxLines(2)`、自带 padding 与底色）+ 吧名（**条件渲染**）；`padding(Spacing.lg)`、圆角 26 → **高度天然不齐** |
| 顶部让位 | `NOTIFY_TOP_PAD = 98`（61），实现为 **`Column` 的 `padding-top`**（515，属内容、随滚动上移，保证沉浸） |
| 防居中 | `.constraintSize({ minHeight: '100%' })`（513）：防内容不足一屏时被垂直居中 |
| 分页 | `Scroll.onReachEnd` → `loadMessages(tab, false)`（523） |
| 沉浸相关 | `Column` 外层 `.overlay(BottomFadeOverlay())`（568）+ `blendMode(SRC_OVER, OFFSCREEN)`（569）+ 内层 `Scroll.clip(false)` / `expandSafeArea(TOP, BOTTOM)`（521-522） |
| 形态判定 | 本页**没有** `deviceInfo` / `isFoldable` / `pageWidth` / `isLandscape`，也**未挂** `onAreaChange` → 判定能力需新增 |
| 滚动控制 | `Scroll()` **未传 scroller**（无 `ScrollController`），无滚动位置恢复、无回顶接口 |

**关键约束：本页不适合换虚拟滚动容器** ⚠️

`docs/floor-vanish-viewport-fix.md` 已实证：**沉浸（`clip(false)` + `expandSafeArea` + 页面底部悬浮控件）叠加虚拟滚动容器**时，列表项滚过某条横线后会**整层不绘制**且不恢复；`List` 已实锤，换 `Scroll` + `Column` 全量渲染是当时唯一的解法（消息页、帖子详情页均按此处理）。

消息页同时具备全部触发要素（沉浸 + 底部手写玻璃底栏 + `blendMode` 离屏），因此**本页的多列化走「不换容器」路线（已拍板：采用方案 A）**；`WaterFlow` / `Grid` 属同类虚拟滚动容器且**未经本场景验证**，**本页不采用**（见下方方案 B 留档）。

**方案 A（已采用）：`Scroll` + `Column` 内手工按行分组（不换容器）**

保持 `Scroll` + `Column` 全量渲染结构不动，只把「一维 `ForEach` 纵向铺」改为「外层 `ForEach` 按行、行内 `Row` 放 N 张卡、卡片 `layoutWeight(1)` 等分」：

```ts
// 1) 形态判定（本页新增，口径与 §4.1/§4.3 完全一致）
import { deviceInfo } from '@kit.BasicServicesKit';
import { display } from '@kit.ArkUI';

@State pageWidth: number = 0;
@State isLandscape: boolean = false;

private readonly isWideFormDevice: boolean =
  deviceInfo.deviceType === 'tablet'
  || deviceInfo.deviceType === '2in1'
  || display.isFoldable();

/** 消息卡列数：大屏横 3 / 大屏竖 2；手机与窄窗 1（维持现状） */
private notifyColumns(): number {
  if (!this.isWideFormDevice) return 1;
  if (this.pageWidth < 600) return 1;          // 折叠态 / 分屏 / 自由多窗窄窗
  return this.isLandscape ? 3 : 2;
}

// 2) 行分组（纯数组运算，无容器依赖）
private notifyRows(tab: NotifyTab): NotifyMessage[][] {
  const cols: number = this.notifyColumns();
  const src: NotifyMessage[] = this.mirrorOf(tab).list;
  const rows: NotifyMessage[][] = [];
  for (let i = 0; i < src.length; i += cols) {
    rows.push(src.slice(i, i + cols));
  }
  return rows;
}

/** 末行补空位：不足 cols 时用等宽空白补齐，避免最后一张卡被拉伸占满整行 */
private notifyBlankSlots(rowLen: number, cols: number): number[] {
  const slots: number[] = [];
  for (let i = rowLen; i < cols; i++) {
    slots.push(i);
  }
  return slots;
}
```

`TabPane()` 内列表分支改写（**n = 1 走原逻辑、n ≥ 2 走行分组**，保证手机端逐像素不变）：

```ts
} else if (this.notifyColumns() <= 1) {
  // 手机 / 窄窗：维持现状（一行代码不改）
  Column({ space: Spacing.md }) {
    ForEach(this.mirrorOf(tab).list, (item: NotifyMessage) => {
      this.MessageCard(item)
    }, (item: NotifyMessage) => item.id)
    Column().width('100%').height(150)
  }
  .width('100%')
  .constraintSize({ minHeight: '100%' })
  .padding({ left: Spacing.lg, right: Spacing.lg, top: NOTIFY_TOP_PAD })
} else {
  // 平板 / 折叠屏：按行分组多列
  Column({ space: Spacing.md }) {
    ForEach(this.notifyRows(tab), (row: NotifyMessage[], rowIdx: number) => {
      Row({ space: Spacing.md }) {
        ForEach(row, (item: NotifyMessage) => {
          // 包一层 Column 才能让 layoutWeight(1) 等分（MessageCard 自身 width('100%')）
          Column() { this.MessageCard(item) }
            .layoutWeight(1)
            .height(NOTIFY_CARD_WIDE_H)     // 见「改动三：大屏定高收敛」
        }, (item: NotifyMessage) => item.id)

        ForEach(this.notifyBlankSlots(row.length, this.notifyColumns()), (slot: number) => {
          Column().layoutWeight(1)
        }, (slot: number) => `gap_${rowIdx}_${slot}`)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)        // 行内卡片各自贴顶，不被拉伸
    }, (row: NotifyMessage[], rowIdx: number) => `row_${rowIdx}_${row[0].id}`)

    Column().width('100%').height(150)      // 底部让位：仍是全宽兄弟节点，天然通栏
  }
  .width('100%')
  .constraintSize({ minHeight: '100%' })
  .padding({ left: Spacing.lg, right: Spacing.lg, top: NOTIFY_TOP_PAD })
}
```

**为什么选它**：零容器改动 → `Scroll` / `clip(false)` / `expandSafeArea` / `overlay` / `blendMode` / `constraintSize` / `onReachEnd` / 顶部 `NOTIFY_TOP_PAD` 让位**全部原样保留**；底部 150 占位仍是全宽兄弟节点，**不存在 §4.2 / §4.3 里「占位只占一格、需塞进 `ListItemGroup.header/footer`」的问题**；沉浸与「防整层消失」结论都不受影响。

**代价**：同行卡片高度不等 → 矮卡下方留白（`Row` 高度由最高卡决定）。处理见改动三。

**改动三：大屏卡片定高收敛（消除行内留白，方案 A 的配套）**

留白幅度取决于同行卡片高度差，而高度差来自三处条件渲染（标题 / 引用块 / 吧名）与内容行数。消息卡的**信息量小**，可以像「固定行高」的列表卡一样收敛：

1. 大屏（n ≥ 2）时给卡片**固定高度** `NOTIFY_CARD_WIDE_H`，同时把内部行数上限收缩：内容 `maxLines(3)` → **2**、引用块 `maxLines(2)` → **1**（标题 / 吧名维持 1 行）。定高 + 裁行后，**行内卡片视觉等高，留白问题消失**（等价 `Grid` 的整齐度，但无需换容器）。
2. `NOTIFY_CARD_WIDE_H` 建议以「标题 1 行 + 内容 2 行 + 引用块 1 行 + 吧名」这一常见形态为基准取值，**具体数值需真机校准**（暂估 170~190vp 区间）；校准口径：该形态刚好不溢出，且「仅标题 + 无引用」的短卡下方留白不超过一行。
3. **仅在 n ≥ 2 生效**，手机端 `maxLines` 与自适应高度**保持现状**（`MessageCard` 内按 `this.notifyColumns() > 1` 分支即可，与 §4.2「大屏摘要降到 2 行」同一思路）。
4. 若不愿裁行（要完整显示 3 行内容 / 2 行引用），则接受行内留白（方案 B 已不采用，无其它回退路径）。

**方案 B（本页不采用，仅留档）：`WaterFlow` 瀑布流**

> **2026-09-12 决定：本页不采用方案 B**，保留本节仅作技术留档与「为什么不用」的记录。

- 改法：`Scroll` + `Column` → `WaterFlow()` + `ForEach` → `FlowItem { this.MessageCard(item) }`，挂 `.columnsTemplate(this.notifyColumnsTemplate())` + `.columnsGap(Spacing.md)` + `.rowsGap(Spacing.md)`（`notifyColumnsTemplate()` 返回 `'1fr' / '1fr 1fr' / '1fr 1fr 1fr'`）。
- 顶部让位改为容器 `.padding({ left: 16, right: 16, top: NOTIFY_TOP_PAD })`；`.constraintSize({ minHeight: '100%' })` **可去掉**（瀑布流不会把不足一屏的内容垂直居中）。
- 底部 150 占位**必须移出流**（`FlowItem` 只占一列，会左右不均）→ 改为容器 `padding-bottom` 或外层兄弟节点。
- 优点：卡片高度各自独立，**无留白**，视觉最佳（与 §4.2 首页选型同路）—— 但这是用「换虚拟滚动容器」换来的，本页恰好是已被该风险实锤过的页面，不值得。
- ⚠️ 风险：`WaterFlow` 是**虚拟滚动容器**，正落在 `floor-vanish-viewport-fix` 的触发组合（沉浸 + 底部悬浮控件）上，**本场景未验证** → 采用前必须先做真机 A/B（长列表反复上下滚动，确认卡片不消失）；若复现，回退方案 A。**该风险记录对 §4.2 首页的 `WaterFlow` 选型同样成立。**

**列数映射**

| 形态 | 判定 | 列数 |
|------|------|------|
| 平板 / 折叠屏 **横屏** | 大屏形态 && width ≥ 600 && width > height | **3** |
| 平板 / 折叠屏 **竖屏** | 大屏形态 && width ≥ 600 && width <= height | **2** |
| 折叠屏**折叠态** | width < 600 | 1（自然回落） |
| 手机（竖 / 横） | 非大屏形态 | 1（维持现状） |

**列宽核算（vp）**

| 形态 | 窗口宽 | 可用宽 | 列数 | 单列宽 | 卡片内容宽 |
|------|--------|--------|------|--------|------------|
| 手机竖屏（现状） | 360 | 328 | 1 | 328 | 296 |
| 折叠屏展开竖持 | 750 | 718 | 2 | 353 | 321 |
| 平板竖屏 | 800 | 768 | 2 | 378 | 346 |
| 平板竖屏（13 寸） | 960 | 928 | 2 | 458 | 426 |
| 平板横屏（1280） | 1280 | 1248 | 3 | 408 | 376 |

- 计算公式：可用宽 = 窗口宽 − 2×16；单列宽 = (可用宽 − (列数−1)×12) ÷ 列数；卡片内容宽 = 单列宽 − 2×16（卡片 `padding(Spacing.lg)`）。
- 结论：**所有多列场景的单列宽（353~458）都比手机单列（328）更宽**，头像 44 + 文字区反而更宽松，不存在挤压。

**顶部渐隐带（`BottomFadeOverlay`）的影响**（与 §4.2 / §4.3 同类，顺带记录）

- 现状（469-480）：`height('100%')` + 停靠点 `0.15` + `DST_IN` 离屏 + `hitTestBehavior(None)`，挂在 `NotifyContent` 外层（568）。
- **宽度**：`100%` 跟随容器（= 屏幕宽），纵向渐变与列数无关 → 多列后仍均匀，**零改动**。
- **高度**：0.15 为视口高比例，横屏视口矮时被压浅：手机竖屏 ~800 → ~120vp（覆盖 `NOTIFY_TITLE_BAR_HEIGHT = 108` 刚好）；平板横屏（1280×800）视口 ~640 → **~96vp < 108，不足**。
- 处理建议（观感微调、非必须）：按视口高夹取 `min(max(视口高 × 0.15, 110), 180)`，或直接固定为 110vp。
- `BlendApplyType.OFFSCREEN` 会随宽高建立更大的离屏缓冲，平板高分辨率下若滚动掉帧，可优先怀疑此处（与 §4.2 / §4.3 同一提示）。

**风险与回归项**

| # | 风险 | 说明 / 处理 |
|---|------|-------------|
| 1 | **不能换 `List`** | 本页注释 496-497 与 `docs/floor-vanish-viewport-fix.md` 已实锤「沉浸 + 虚拟滚动容器」会导致整层不绘制 → 方案 A 刻意不换容器；不要为了 `lanes` 而把容器改回 `List` |
| 2 | `WaterFlow` 同类风险 | **本页已不采用方案 B**（不换容器），本页无此风险；保留本条是因为它与 §4.2 首页选用的 `WaterFlow` 同源 —— 首页落地前须做同样的真机 A/B |
| 3 | 末行不满被拉伸 | 必须用 `notifyBlankSlots()` 补等宽空位，否则「总数为 cols+1」时最后一张卡会独占整行（看起来像单列） |
| 4 | 行内高度不齐 | 方案 A 的固有代价 → 用改动三「大屏定高 + 裁行」消除；仅 n ≥ 2 生效，手机端不动 |
| 5 | 首帧列数跳变 | `isLandscape` 初值 false，初始横屏时会先 2 列再跳 3 列；在 `aboutToAppear`（97）用 `display.getDefaultDisplaySync()` 同步一次初值（同 §4.1 改动点④） |
| 6 | 前置依赖 | `module.json5` 的 `deviceTypes` 需先加 `"tablet"`（见 1.6），否则真机不会以平板形态运行 |
| 7 | 同屏卡片绘制压力上升 | `Scroll` + `Column` 为**全量渲染**，3 列后同屏可见卡片由 3~5 张增至 9~15 张（总量不变）。消息列表量级小（每页 20 条），预期可接受；若平板高分辨率下掉帧，优先排查渐隐带离屏缓冲（见上） |
| 8 | 两个子 Tab 天然同步 ✅ | 「回复 / 提到我的」共用同一个 `TabPane()` builder → **只改一处，两个 Tab 同时生效**（不存在 §4.3「两处必须同步改」的风险） |
| 9 | `Tabs` 左右滑动不受影响 | 列是静态排布，行内不引入横向滚动手势 → 与 `Tabs.scrollable(true)` 的手势**无冲突**；`barHeight(0)` 无栏形态也不用改 |
| 10 | 顶部槽位高度 | 多列不触碰标题栏：`NOTIFY_TITLE_BAR_HEIGHT = 108`、`NOTIFY_TOP_PAD = 98`、底部 150 占位 **全部不变** |

**涉及文件**

- `entry/src/main/ets/pages/MessagesTab.ets`（主体：`TabPane()` 列表分支 + `MessageCard()` 大屏裁行 + 形态判定）
- `docs/floor-vanish-viewport-fix.md`（不改，作为方案 A「不换容器」的依据）
- 若后续把「大屏形态判定」抽为公共能力（§5），另涉 `common/` 与已适配页面

**状态**：**已拍板 —— 采用方案 A**（2026-09-12，本阶段未动代码）。落地内容 = 形态判定（本页新增「大屏 + 宽度 + 横竖」三项）+ `TabPane()` 按行分组多列（n ≥ 2 分支，n = 1 原样）+ 改动三「大屏定高收敛」；方案 B（`WaterFlow`）**不采用**（本页已被「沉浸 + 虚拟滚动容器」问题实锤过，不值得为省留白去换容器）。

- 列数：平板 / 折叠屏**竖屏 2 列**、**横屏 3 列**；手机与窄窗（< 600vp）维持单列，**手机端零改动**。
- 本节内 A / B 编号**仅在本节有效**，与 §4.2 首页的 A / B 编号不是同一组，勿混用。
- 遗留待定（非阻塞，落地时真机校准）：`NOTIFY_CARD_WIDE_H` 的具体数值（暂估 170~190vp）；渐隐带横屏偏浅是否一并夹取（可选）。
- 与 §4.3 收藏页候选（方案一 / 方案三）**互不影响**：收藏页那条仍待拍板。

### 4.5 我的页（`pages/MineTab.ets`）

**适配需求**（2026-09-12 用户提出）

- 竖屏：**用户个人卡片** 与 **信息数据（统计）卡片** 并排 **2 列**；下方功能卡片 **2 列**。
- 横屏：两者仍 **2 列**，且 **自适应拉伸、与下面对齐**；下方功能卡片 **3 列**。
- 口径沿用 §4.1~§4.4：手机 / 窄窗（< 600vp）**维持现状单列**，手机端零改动（**已确认：手机不做**，见「已确认决策 1」）。

**现状（代码事实）**

| 位置 | 内容 |
|------|------|
| 页面结构 | `build()`（436-464）两条路径：`MINE_OFFICIAL_TITLE_BAR = true` 走 `Navigation` + `title` 槽位（`MINE_TITLE_BAR_HEIGHT = 98`，442）；false 走 `Stack` + 悬浮 `TopBar()`（134-177） |
| 内容层 | `MineContent()`（310-434）：`List()`（**未传 scroller**）→ ① 90 高占位 `ListItem`（314-319）② **单个** `ListItem`（321-424）承载全部内容 → 内部 `Column({ space: Spacing.md })`（322） |
| 用户卡片 | 323-374。登录态 `Row{ UserAvatar(62) + 昵称 / 「已登录 · 个人主页」 + › }`；未登录态 `Row{ 文案 + 登录按钮 }`。`padding(Spacing.lg=16)`、`bgCard`、`Radius.lg` → 高约 **94vp** |
| 统计卡片 | 376-386。`Row{ StatItem('关注的吧') ｜ Divider(h28) ｜ StatItem('关注用户') ｜ Divider(h28) ｜ StatItem('我的贴子') }`，`padding top/bottom Spacing.lg` → 高约 **65vp** |
| 功能卡片 | `MineEntry()`（281-307）× **6**（388-403：我的帖子 / 我的收藏 / 我的点赞 / 浏览历史 / 创建吧 / 软件设置）。`Row{ 图标 28 + 文字列 + 箭头 }`、左右 `padding(Spacing.lg)`、上下 13 → 高约 **48vp、天然等高** |
| 退出登录 | 405-420。`Button` + `width('100%')` + `height(44)`，**仅登录态** |
| 沉浸相关 | `List.clip(false)`（430）+ `.expandSafeArea(SYSTEM, TOP/BOTTOM)`（431）+ `.overlay(this.BottomFadeOverlay())`（432）+ `.blendMode(SRC_OVER, OFFSCREEN)`（433）；底部让位 = `Column.padding.bottom 150`（423）+ `List.padding.bottom 150`（428） |
| 形态判定 | 本页**没有** `deviceInfo` / `isFoldable` / `pageWidth` / `isLandscape`，也**未挂** `onAreaChange` → 判定能力需新增 |
| 滚动控制 | `List()` **未传 scroller** → 无滚动位置恢复、无回顶接口 |

**关键判断：本页是几个主 Tab 里改造面最小的一个，但有一个既有隐患要顺带盯**

1. **多列不需要动容器**：本页全部内容都在**同一个 `ListItem` 内的 `Column`** 里（321-424），`List` 只负责"占位 + 滚动"。因此多列化 = **改这个 `Column` 里 `Row` 的排列**，完全不碰 `List` 的 `lanes` / `ListItemGroup` / 虚拟化参数 → 既没有 §4.3 的「通栏项错位」，也没有 §4.2 的「换容器」决策。
2. **必须坚持不换容器** ⚠️：本页同时具备 `List` + `clip(false)` + `expandSafeArea(TOP, BOTTOM)` + **宿主悬浮玻璃底栏**压在内容上（底部 150 让位即为其留白）—— 这**完整命中** `docs/floor-vanish-viewport-fix.md` 第 21 行的识别关键词。该文档**未记录本页复现**，说明现状未爆；但若为了多列把 `List` 换成 `Grid` / `WaterFlow`，就是**主动新增**该风险。**结论：`List` 结构原样保留。**
3. **既有隐患（与本方案无关，但验收时要看）**：本页是"**全部内容挤在 1 个 `ListItem`**"的极端形态 —— 一旦该 item 被视口剔除误判，**整页内容一起消失**（比该文档记录的"单楼层消失"更严重）。多列后内容总高下降、可能不足一屏，剔除窗口行为也会随之改变。**验收时请在平板上把页面滚到中部停住，确认没有整层消失**；若复现，按该文档改用 `Scroll` + `Column` 全量布局（属独立修复，不搭在本方案里做）。

**方案（三层，全部为条件分支，n = 1 逐像素不变）**

**改动一：形态判定（新增，口径与 §4.1 / §4.3 / §4.4 完全一致）**

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

/** 列数：大屏横 3 / 大屏竖 2；手机与窄窗 1（维持现状） */
private mineColumns(): number {
  if (!this.isWideFormDevice) return 1;
  if (this.pageWidth < 600) return 1;      // 折叠态 / 分屏 / 自由多窗窄窗
  return this.isLandscape ? 3 : 2;
}
```

**改动二：判定挂点 + 首帧初值（只挂一处，比 §4.3 更省）**

`MineContent()` 的 `List`（426-433）上补 `onAreaChange` —— 两条 `build()` 路径共用同一个 `MineContent()`，所以**只需挂一处**：

```ts
.onAreaChange((_o: Area, n: Area) => {
  this.pageWidth = n.width as number;
  this.isLandscape = (n.width as number) > (n.height as number);
})
```

⚠️ 前提：`List` 宽度须等于窗口宽（本页左右 padding 都在内部 `Column` 上，`List` 自身无侧向内缩）→ 真机 log 复核一次；若不等，改挂 `Navigation` / `Stack` 根节点（两处）。

`aboutToAppear()`（59-61）补首帧初值（同 §4.1 改动点④）：

```ts
const d = display.getDefaultDisplaySync();
this.isLandscape = d.width > d.height;   // px 比较，与 vp 同序，结果一致
this.pageWidth = px2vp(d.width);
```

**改动三：顶部「用户卡片 + 统计卡片」并排 + 自适应拉伸**

**已确认口径**（2026-09-12）：采用**解读 A** —— 顶部与下方**共用同一列网格**，顶部整行的**左右外边缘与下方卡片严格对齐**（= 用户所说的「与下面对齐」）。解读 B（顶部独立等分 618 / 618）**不采用**，仅留档。

**宽度拉伸公式（一条式子统一竖 / 横屏，无需 `isLandscape` 分支）**

```
用户卡 : 统计卡 = 1 : (mineColumns() - 1)
```

| 形态 | n | 用户卡 | 统计卡 | 两卡合计 | 与下方关系 |
|---|---|---|---|---|---|
| 平板竖屏 / 折叠屏竖持 | 2 | 1 格 ≈ 378vp | 1 格 ≈ 378vp | 768 | = 下方 2 列总宽，外边缘齐 |
| 平板横屏 | 3 | 1 格 ≈ 408vp | 2 格 ≈ 828vp | 1248 | = 下方 3 列总宽，外边缘齐 |
| 手机 / 窄窗 | 1 | 不走此行（原纵向排列） | — | — | — |

> 式子的"自适应"体现在：**列数变 → 比例自动变；窗口变宽 → 两卡跟着等比拉伸**，不需要任何魔法数字。

**高度拉伸（等高、底边齐平 —— 竖屏同样需要，两卡本就差 94 vs 65vp）**

```ts
// n ≥ 2：顶部合成一行；n = 1 走原来纵向两块（323-386 顺序，一行不改）
Flex({ direction: FlexDirection.Row, alignItems: ItemAlign.Stretch }) {
  Column() { /* 用户卡片：323-374 原样搬入 */ }
    .layoutWeight(1)                          // 权重恒为 1
  Column() { /* 统计卡片：376-386 原样搬入 */ }
    .layoutWeight(this.mineColumns() - 1)     // 竖屏 1、横屏 2
    .justifyContent(FlexAlign.Center)         // 被拉高后内容垂直居中，避免贴顶空荡
}
.width('100%')
```

### 顶部两卡「能否自适应拉伸」—— 能，分三层，第三层才是协调性的关键

| 层 | 能否自动 | 做法 | 结论 |
|---|---|---|---|
| **宽度** | ✅ 天然支持、**零风险** | `layoutWeight(1) : layoutWeight(n−1)` 吃满可用宽 | 窗口越宽两卡越宽，永远铺满、不留空隙 |
| **高度** | ⚠️ **不是自动的**，须显式做 | `Flex` + `ItemAlign.Stretch`：矮的统计卡（65vp）被拉高到与用户卡（94vp）齐平，底边对齐。**`Row` 做不到** —— `Row.alignItems` 只接受 `VerticalAlign.Top/Center/Bottom`，**没有 `Stretch`** | 兜底：两卡定高 `MINE_HEAD_CARD_H`（§4.4 同法） |
| **内容分布** | ⚠️ **必须跟着改** | ① 统计卡 3 个 `StatItem` **各包一层 `.layoutWeight(1)`**（`Divider` 保留）→ 从"三个数挤在中间"变成"3 项均布撑满"；② 用户卡维持「头像 + 文字列 + `Blank()` + `›`」→ 拉宽后右侧自然留白、箭头仍贴右 | **这是"拉宽不空、不散"的关键**；不做这一步，横屏 828vp 的统计卡会明显发虚 |

- ⚠️ **唯一技术不确定项**：`Flex` / `ItemAlign.Stretch` **全工程无先例**（项目里从没用过 `Flex`），`space` 需用 `FlexSpaceOptions`（`{ main: LengthMetrics.vp(12) }`）或改用子项 `margin` 规避 → **需真机验证**；不通过就走兜底「`Row` + 两卡定高」。
- 落地微调项（非阻塞）：若横屏统计项等分后间距仍显大，可改 `justifyContent(FlexAlign.SpaceAround)` + 固定项宽。

**拉伸后的观感核对（vp）**

- 竖屏 n=2：用户卡 378（62 头像 + 昵称，宽裕）、统计卡 378 → 3 项各 ~126；「关注的吧」@11px ≈ 44vp → **不挤**。
- 横屏 n=3：用户卡 408、统计卡 828 → 3 项各 ~276，**等分后不再是"贴着左边三个数"**，而是均匀铺开，与下方 3 列卡片形成同一节奏 → 原先担心的"828 太宽太空"被**等分消化**，协调性由此成立。

**改动四：下方功能卡片按行分组多列**

`MineEntry` 现在写死 6 次调用（388-403），要行分组必须先**数组化**（本页唯一的机械性重构）：

```ts
interface MineEntryDef {
  icon: Resource; title: string; subtitle: string; action: () => void;
}

private mineEntryDefs(): MineEntryDef[] {
  return [
    { icon: $r('sys.symbol.doc'),  title: '我的帖子', subtitle: '查看发布过的主题',
      action: () => this.openPersonalContent('posts') },
    { icon: $r('sys.symbol.star'), title: '我的收藏', subtitle: '收藏的帖子与内容',
      action: () => { /* 原 389-395 逻辑原样搬入 */ } },
    // …我的点赞 / 浏览历史 / 创建吧 / 软件设置，动作原样搬入
  ];
}

private mineRows(cols: number): MineEntryDef[][] {
  const src: MineEntryDef[] = this.mineEntryDefs();
  const rows: MineEntryDef[][] = [];
  for (let i = 0; i < src.length; i += cols) rows.push(src.slice(i, i + cols));
  return rows;
}

/** 末行补空位：不足 cols 时用等宽空白补齐，避免最后一张卡被拉伸占满整行 */
private mineBlankSlots(rowLen: number, cols: number): number[] {
  const slots: number[] = [];
  for (let i = rowLen; i < cols; i++) slots.push(i);
  return slots;
}
```

列表内渲染（**n = 1 走原逻辑、n ≥ 2 走行分组**）：

```ts
if (this.mineColumns() <= 1) {
  // 手机 / 窄窗：维持现状（一行不改）
  this.MineEntry(...);   // × 6，原样
} else {
  Column({ space: Spacing.md }) {
    ForEach(this.mineRows(this.mineColumns()), (row: MineEntryDef[], rowIdx: number) => {
      Row({ space: Spacing.md }) {
        ForEach(row, (it: MineEntryDef) => {
          Column() { this.MineEntry(it.icon, it.title, it.subtitle, it.action) }
            .layoutWeight(1)
        }, (it: MineEntryDef) => it.title)

        ForEach(this.mineBlankSlots(row.length, this.mineColumns()), (slot: number) => {
          Column().layoutWeight(1)
        }, (slot: number) => `mine_gap_${rowIdx}_${slot}`)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }, (row: MineEntryDef[], rowIdx: number) => `mine_row_${rowIdx}_${row[0].title}`)
  }
  .width('100%')
}
```

- **6 张卡天然整除**：竖屏 2 列 = 3 行、横屏 3 列 = 2 行 → 本期**不需要补空位**；`mineBlankSlots` 仍要写，防后续增删项导致最后一张被拉伸。
- `MineEntry` 自身**等高**（固定上下 padding 13 + 内容单行）→ 行内**没有** §4.4 的"矮卡留白"问题，不需要定高收敛。
- 单列宽够用：横屏 3 列 408vp ≥ `MineEntry` 最小需求（图标 28 + 间距 12 + 标题/副标题 ~90 + 箭头 18 + 左右 padding 32 ≈ 180vp）。

**改动五：「退出登录」必须跨列（独占整行）**

多列下若把它塞进网格，它只占**一格宽**（看起来像普通入口卡）。做法：**放在行分组之外**，保持 `width('100%')`：

```ts
if (this.loggedIn) {
  Button('退出登录')   // 原 406-419 原样
    .width('100%')
}
```

同理，90 高占位 `ListItem`（314-319）与顶部两卡行都**不参与**下方网格 —— 天然如此（它们是 `Column` 的兄弟项），无需特殊处理。

**列宽核算（vp）**

| 形态 | 窗口宽 | 可用宽 | 下方列数 | 单列宽 | `MineEntry` 是否宽裕 |
|------|--------|--------|----------|--------|----------------------|
| 手机竖屏（现状） | 360 | 328 | 1 | 328 | 是（不参与网格） |
| 折叠屏展开竖持 | 750 | 718 | 2 | 353 | 是 |
| 平板竖屏 | 800 | 768 | 2 | 378 | 是 |
| 平板竖屏（13 寸） | 960 | 928 | 2 | 458 | 是 |
| 平板横屏（1280） | 1280 | 1248 | 3 | 408 | 是 |

- 计算公式：可用宽 = 窗口宽 − 2×16；单列宽 = (可用宽 − (列数−1)×12) ÷ 列数；单格 = (可用宽 − (格数−1)×12) ÷ 格数。与 §4.4 同口径。
- 顶部两卡行：竖屏 378 / 378vp（1:1）；横屏 408 / 828vp（1:2，**已确认**；两卡合计 = 下方卡片总宽）。

**风险与回归项**

| # | 风险 | 说明 / 处理 |
|---|------|-------------|
| 1 | **不换容器（最高优先）** | 本页是 `List` + `clip(false)` + `expandSafeArea(TOP,BOTTOM)` + 宿主悬浮底栏 的组合，**完整命中** `floor-vanish-viewport-fix` 的识别关键词 → 多列**只改 `ListItem` 内 `Column` 的排布**，`List` / `clip` / `expandSafeArea` / `overlay` / `blendMode` / 底部 150 让位 **全部不动** |
| 2 | 既有隐患：全部内容在 1 个 `ListItem` | 若该 item 被视口剔除误判，**整页一起消失**；多列后内容变短会改变剔除窗口行为 → 验收时在平板上滚到中部停住确认；若复现，按该文档改 `Scroll` + `Column`（独立修复） |
| 3 | `Row` 不能做等高拉伸 | `Row.alignItems` 无 `Stretch` → 用 `Flex(ItemAlign.Stretch)`（主）或定高（兜底），见改动三 |
| 4 | `Flex` / `ItemAlign.Stretch` 无项目先例 | 全工程未使用，属新引入写法 → 真机验证；不通过就走兜底定高 |
| 5 | 横屏统计卡被拉宽后偏空 | 1280 下统计卡 828vp 而内容量本就少 → **已有对策**：3 个 `StatItem` 各 `.layoutWeight(1)` 等分撑满（见改动三）；若仍显空，再上 `SpaceAround` 微调 |
| 6 | 退出登录按钮跨列 | 必须置于行分组之外，否则只占一格宽 |
| 7 | 首帧列数跳变 | `isLandscape` 初值 false，初始横屏会先 2 列后跳 3 列 → `aboutToAppear` 用 `display.getDefaultDisplaySync()` 同步初值（同 §4.1 改动点④） |
| 8 | 手机端零改动 | n = 1 时顶部走原纵向排列、下方走原顺序 `MineEntry` 调用 → 逐像素不变（验收基线） |
| 9 | 前置依赖 | `module.json5` 的 `deviceTypes` 需先加 `"tablet"`（见 1.6），否则真机不会以平板形态运行 |
| 10 | 判定挂点前提 | `onAreaChange` 挂在 `List` 上，要求其宽度 = 窗口宽 → 真机 log 复核一次；若不等，改挂 `Navigation` / `Stack` 根节点（两处） |
| 11 | 内容不足一屏后的底部留白 | 多列后内容可能 < 1 屏，`Column.padding.bottom 150` + `List.padding.bottom 150`（共 300vp）会变成纯空白 → 是否按列数收敛**待真机看观感**，默认**不动**（避免回归） |
| 12 | 底部渐隐带 | `BottomFadeOverlay` 挂在 `List` 上、按视口高 15% 渐隐；内容不足一屏时下方是空白 → 无影响；可滚动时与现状一致，**零改动** |

**涉及文件**

- `entry/src/main/ets/pages/MineTab.ets`（主体：形态判定 + 顶部两卡并排 + `MineEntry` 数组化与行分组 + 退出按钮跨列）
- `docs/floor-vanish-viewport-fix.md`（不改，作为「不换容器」依据）
- `module.json5`（前置依赖，见 1.6）

**待确认点**（需拍板后才可落地）

1. **手机端是否也要两列**：需求写的是"平板适配"，本方案按全局口径**手机维持单列**（且 360vp 下顶部两列各仅 ~160vp，「关注的吧」几乎贴边，观感差）→ 若要求手机也两列，需单独设计窄列降级（如统计项改竖排）。
2. **横屏顶部两列的几何**：解读 A（与下方 3 列网格对齐，用户卡 1 格 / 统计卡 2 格）还是解读 B（顶部独立等分 618 / 618）→ 建议真机两种各看一眼再定。
3. **「自适应拉伸与下面对齐」的口径**：本方案理解为「两卡等高、底边齐平 + 与下方卡片左右边界对齐」；若你指的是别的（例如顶部区域整体吸边、或与下方卡片等宽），请指出。
4. **未登录态**：是否同样两列（"登录贴吧"卡 + 统计卡）→ 默认**是**（保持形状一致）。

**状态**：已出方案，**待用户确认**（2026-09-12，本阶段未动代码；4 个待确认点见上）。

### 4.6 宿主壳（`pages/Index.ets`）

**定位**：应用主页面（`@Entry`），不承载业务，只负责「装」——Tab 宿主与切换、底栏两条渲染路径、登录态/统计/设置中枢、跨页通信总线（AppStorage token + 回调）。五个主 Tab 页均为独立 `@Component`；二级页路由在各 Tab 内部 `Navigation`，**宿主不参与**。

**适配需求**：宿主管的是「所有页面共用的那一层」，几何与形态判定必须**唯一收口**。否则一侧变了另一侧没变，就会出现「底栏已切宽屏档、页面仍是窄屏列数」的错位。核心不是「把底栏拉宽」，而是三件事：首帧判定正确、断点与几何常量单一来源、底部让位含安全区。

**现状（已核实）**

| 项 | 现值 | 位置 |
|---|---|---|
| 形态判定 | `isWideScreen = width >= 840`（lg 下限） | `Index.ets:437` |
| 屏宽来源 | 根 `Stack` 的 `.onAreaChange` → `currentWidth` | `Index.ets:434-438` |
| 初值 | `isWideScreen = false`、`currentWidth = 360`（**窄屏**） | `Index.ets:68-69` |
| 底栏宽 | 官方槽位 `pillWidth()`：宽屏 480 / 否则 屏宽−48（下限 240）；兜底 `isWideScreen ? 480 : calc(100% - 48vp)` | `Index.ets:598-604` / `741` |
| 底栏几何 | 高 74 · 圆角 37 · 底部 margin 30（合计占 104vp） | `Index.ets:742-754` |
| 内容区 | `PagesStack` 五页均 `100% × 100%`，宿主**无** maxWidth | `Index.ets:639-713` |
| 已有宽屏分支 | 仅隐私卡 `currentWidth >= 600 ? 440 : 屏宽−56` | `Index.ets:549` |
| 各页断点口径 | `ForumsTab` / `UserProfile` 与宿主同为 840；`ThreadDetail` / `Search` / `ThreadList` 只用 `currentWidth` 做宽度换算 | 各页 `onAreaChange` |

**设计方案**

**H-A 首帧形态判定（必做）**
- 判断：初值 360 / false 只在 `onAreaChange` 触发后才纠正 → 平板横屏冷启动第一帧按窄屏渲染（底栏 312 宽、隐私卡 320、进吧页 2 列），第二帧跳宽屏 —— 可见跳变，属 A 类错位。
- 方案：`aboutToAppear` 内同步取真实窗口宽作为初值（`window.getLastWindow` → `getWindowProperties().windowRect.width` 经 `px2vp` 换算，或 `display.getDefaultDisplaySync()` 取宽），`onAreaChange` 保留实时更新与兜底。
- 同源改法同步落到 `ForumsTab.ets` / `UserProfile.ets`（这两处存在同样的 false / 360 初值）。

**H-B 断点与几何常量收口（必做）**
- 判断：840 散落三处、600 一处、480 / 74 / 30 / 37 / 16 全为字面量 → 改一处漏一处就错位。
- 方案：归口 `Breakpoint`（`sm = 600` / `md = 840` / `lg = 1440`，对齐 §1.3 官方断点表）、`Dock`（`height = 74` / `radius = 37` / `bottomMargin = 30` / `maxWidthWide = 480` / `tabInset = 24`）、`Content.maxWidth`（供单列页与二级页限宽，**宿主自身不使用**）。宿主 `isWideScreen` 改判 `>= Breakpoint.md`，子页引用同一常量。
- **落点（已定 2026-09-12）**：并入 `common/Theme.ets`，追加在现有 `Spacing` / `Radius` token 之后（`Theme.ets:936-973`，该段注释已自述为「通用圆角、间距令牌」，即既有 token 区），**不新建 `common/Layout.ets`** —— 否则同类 token 被劈成两个文件（间距查 Theme、断点查 Layout），违反 §6.2 第 2 步「单一来源」。
- **被依赖方提示（2026-09-12 补）**：`Breakpoint.md`（840）与 `Content.maxWidth`（1000vp）是 §4.7 全吧搜索 S-A / S-B 的**前置令牌**。落 H-B 时必须三组一起写入（`Breakpoint` / `Dock` / `Content`），**勿只做 `Breakpoint` / `Dock` 而漏 `Content`** —— §4.7 已把该依赖写实并单独留痕（见 §4.7「前置依赖」小节）。
- **定位升格（2026-09-12，据 §4.2 决策 7）**：用户已确认跨全应用「统一在判据层」→ 本项 H-B 不只是宿主壳优化，而是**全应用形态判定与断点门槛的唯一收口点**（即 §4.2 决策 7 列出的三项：形态判定单一函数 / 断点与列数门槛单一来源 / 内容左右外边距单一来源）。落地时须按此定位一次收口，**不得只替换宿主与 `ForumsTab` / `UserProfile` 三处字面量**而让其余页面继续各自为政。

**H-C 底栏平板档位（已定：选项 1，2026-09-12）**
现状：宽屏固定 480 居中 → 1024 屏占 47%、1280 屏占 37.5%，两侧透出内容。

| 选项 | 内容 | 取舍 | 结论 |
|---|---|---|---|
| **选项 1** | 维持 480 封顶 | 每项 96vp（约为手机 72vp 的 1.33 倍），点击目标跟手、与手机一致；底栏是悬浮胶囊，两侧空白透出的是内容而非纯底色，不构成观感缺陷 | **采纳** |
| 选项 2 | 宽屏分档放大（560 ~ 640） | 更「满」，但点击目标过大、手指行程变长，且无需求驱动 | 不采纳 |
| 选项 3 | lg+ 改左侧竖直导航轨（iPad 风格） | **会丢官方沉浸材质**（材质只在 `Tabs` 底部槽位生效），与路线 A「纯官方重设计」冲突；还需重构 `BottomGlow` / `layoutWeight` / 切换动画 | 不采纳 |

**结论：底栏维持现状，本轮零改动。** 若后续仍觉宽屏偏空，从**内容侧**要观感（各页列数已做），不拉长底栏。

**H-D 底部让位与安全区（必做，已定：动态取 + 复用既有实现，2026-09-12）**
- 现状：底栏占 74 + 30 = 104vp，`margin.bottom` 硬编码 30、无安全区补偿；各子页自让 150vp。
- 风险：平板系统导航形式不同（手势条 / 三键 / 无），30 可能与系统导航条重叠（C 类），或让位不足使内容被底栏压住（§6.1 C1 的复核点）。
- **既有实现（可直接复用，不必新写）**：`UserProfile.ets:57-66` 的 `AvoidAreaCompat` 接口 + `UserProfile.ets:161-195` 的读数逻辑 —— 已依次取 `TYPE_NAVIGATION_INDICATOR` / `TYPE_SYSTEM_GESTURE` / `TYPE_SYSTEM` 并取最大值，`avoidAreaHeight()` 还兼容不同 SDK 的字段结构。
- 方案：把上述逻辑上提为 `Theme.ets` 中的共享函数（`readBottomSafeArea`），宿主与各页共用；底栏 `margin.bottom = 30 + safeBottom`；「底部让位总量」收为常量，替代散落的 150vp。
- **为何不用固化常量**：横屏的手势条避让值与竖屏不同，平板还有「三键 / 手势 / 无导航」三种可能，单一常量必在某个形态下出错。
- 首帧注意：异步 `await getLastWindow` 期间先按 0 处理，回调后刷新 —— 与 H-A 同为「首帧 + 异步读取」，**合并为一次改动**。

**H-E Tab 切换动画（低优先，不改）**
`tabOffset` 为百分比位移，宽屏绝对距离变大而时长固定 360ms。视觉角速度一致，列为观察项，本轮不改。

**H-F 附带清理：死参数 / 死通道（非平板相关，已执行 2026-09-12）**
- 判断：首页搜索入口已整体迁移到独立搜索页（`HomeTab.ets` `openSearchFromHome()` → `router.pushUrl('pages/Search')`，两颗「全吧搜索」胶囊调用），旧的「首页搜索 → 切收藏 Tab 打开本地搜索」联动已废弃，残骸共 4 处，**均已删除**：

  | 残骸 | 位置 | 处置 |
  |---|---|---|
  | 死参数 | `HomeTab.ets` `onOpenFavorite`（仅声明、全页零调用点） | **已删**（声明 + 类头解耦清单里的过时注释） |
  | 死传参 + 反向注释 | `Index.ets` `HomeTab({ onOpenFavorite: ... })` | **已删**，调用点收敛为 `HomeTab()` |
  | 死通道 | `favOpenSearchRequest`：`Favorite.ets` `@StorageLink` 声明 + `onOpenSearchRequest` 消费函数 | **已删**（全工程无任何自增点，收藏页侧白等） |
  | 过时注释 | `HomeTab.ets` 类头「onOpenFavorite：首页搜索入口联动收藏页本地搜索」 | **已删** |

- **未误伤**（已核对保留）：`Favorite.ets:4361` 顶部搜索胶囊 / `4512` 官方槽位放大镜仍调用 `enterSearch()`，收藏页**自身**搜索入口功能不变；`favCanGoBack` / `favBackRequest` 是另一条真实通道，未动。
- 验证：全工程检索 `onOpenFavorite` / `favOpenSearchRequest` → **0 命中**；`HomeTab.ets` / `Index.ets` / `Favorite.ets` lint **无新增诊断**。
- 与平板适配无关、不改任何布局几何 → **不产生 A / B / C 风险**；归档在 §4.6 仅因其归属宿主壳的解耦总线。

**H-G 形态切换观感：横竖屏切换「没有」过渡动画（既定取舍，2026-09-12 确认）**

- **结论**：本方案（§4.1~§4.7）**不设计**横竖屏切换的过渡动画，形态切换一律走「`onAreaChange` 即时重算 → 布局立即重排」。**这不是遗漏，是有意取舍** —— 原因见下条根因。
- **现状证据**：三处判据挂点（`Index.ets:434-438` / `UserProfile.ets:540-544` / `ForumsTab.ets` 同源）均为**裸赋值**，无 `animateTo` / `transition` 包装；全工程 `animateTo` / `.transition` 只用于骨架屏淡入、字号切档、弹窗、Tab 与搜索态转场，**无一处涉及形态判定或列数**。
- **根因（为何"平滑"做不出来）**：
  1. 列数是**离散量**，`columnsTemplate` / `lanes` 是字符串模板，**不在 `animateTo` 可插值属性之内** → 「1 列平滑长成 2 列」在当前 ArkUI 下不存在，跨 840 必然硬切一帧。
  2. 能顺滑的只有**连续量**：窗口宽变化时卡片宽（`1fr`）跟着连续变 —— 旋转过程中"宽度伸缩"本身已经跟手，真正刺眼的只有**跨档那一帧**。
  3. item 级 `.transition()` 只在组件增删 / 显隐时生效，**重排不触发** → 不能拿它给"同一批卡片换列"做动画。
- **已被文档承认的跳变（现状）**：① §4.3 风险 3：`restoreListScroll` 在横竖屏切换时"跳一下"（规避：一次性恢复标志）；② §4.7 风险 1：列数变化后滚动位置是否跳变 —— 已按**确定性推定采纳 H-G-2**（见下「推定链条」），实测降级为**落地后复测项**（列回归项）。
- **明确不做的三件事**：
  1. **不给列数做补间** —— 框架不支持；硬做只能靠"遮盖"，不得宣称平滑过渡。
  2. **不给整页旋转加动画** —— 会与系统旋转动画叠加（同类教训：`HomeTab` `firstHomeMount` 豁免，避免与整页 Tab 滑入叠成双层）。
  3. **不用 `animateTo` 包 `isWideScreen` 赋值** —— 它不会让列数插值，只会把同一事务里的副属性（底栏 `barWidth`、卡片宽等）动画化，产生「底栏宽度慢慢爬、卡片已经跳完」的错位观感（A 类观感错位）。
- **三项增强（2026-09-12 定案：H-G-1 采纳 / H-G-2 推定采纳 / H-G-3 不做）**：

| 编号 | 定案 | 做法 | 收益 / 理由 | 成本 / 风险 |
|---|---|---|---|---|
| **H-G-1 判据防抖** | **采纳（P0，随布局改动一并落地）** | `onAreaChange` 内仅在**档位翻转**时才写 `@State`（同档内不重设）+ 叠 150~200ms 稳定窗口（末次回调后延迟提交，窗口时长真机微调） | 挡掉断点附近反复翻转（旋转尾帧抖动、自由多窗拖拽来回）造成的列数反复重建 + 滚动位置反复扰动（§4.3 风险 3 的放大器） | 几行、无几何改动；稳定窗口带来 ≤200ms 档位延迟，真机若"慢半拍"则只保留"跨档才赋值" |
| **H-G-2 滚动锚定** | **已确认（推定采纳，2026-09-12 拍板；非本轮必做）** | 切换前记录「视口顶端条目 key + 条内偏移」，切换后 `scrollToIndex(idx, false, ScrollAlign.START)` 并补偿偏移 | 列数变化导致总高变化时**视觉内容位置连续**（看到的是"同批帖子换了排布"，而非"画面跳到别处"）—— 三个候选里唯一治本的 | 中；只做 `WaterFlow`（§4.2 首页 / §4.3 帖流）与 `Grid`（§4.1 进吧）三处 |
| **H-G-3 单帧遮盖** | **默认不做** | 档位翻转那一刻给**内容容器**（非 item）做一次极短不透明度过渡，轻量版为切换后一次 80ms `0.85 → 1` 提亮 | 把"硬切重排"变成"闪一下换列" | 低；**但遮黑期间用户正在滑动会被感知为卡顿** → 只做"提亮"、且必须挂内容容器（item 级 `.transition` 对重排无效）→ 收益不抵风险，默认不做 |

- **落地归属（收口，避免二次打开同一文件）**：
  - **H-G-1 并入 §4.6 H-A / H-B 那次改动** —— 三者同在判据写入的 `onAreaChange` 一处（`Index.ets:434-438` / `ForumsTab` / `UserProfile` 同源），分开做等于把同一段代码改两遍。
  - **H-G-2 单独一次改动**，落在 §4.1 / §4.2 / §4.3 三个含列数变化的页面（`ForumsTab` / `HomeTab` / `Favorite`），且**不再等待实测**（已按推定采纳定案）；§4.7 风险 1 的实测降级为**落地后的复测项**（可据此精简 H-G-2，非前置门）。
  - **H-G-3 不做**；仅当真机验收明确否掉硬切观感时，才回头评估"提亮版"。
- **定案依据（2026-09-12 已拍板：按确定性推定采纳，不再以任何实测为前置门）**：本项判的是「**列数变化时滚动位置是否跳变**」，其成因为**确定性**（推定链条见本节「推定链条」条），无需设备复现 → 判定为**采纳**。下列**等效触发路径**随之降级为**可选的复测手段（非门）**：
  1. **折叠屏展开态旋转**（若设备为折叠屏）—— 最接近真机：展开态本身即大屏形态，横竖 3↔4 列（§4.1），可完整复现跨档。
  2. **DevEco 模拟器**：设备型号选 **Tablet**（**不要**用"phone 设备 + 手动拉大分辨率" —— `deviceType` 仍为 phone 则不进入多列）+ 模拟器旋转 + 模拟器自带录屏。非真机，但本项判的是确定性的滚动位置行为，**足以定性**。
  3. **代码级量化（最硬证据，不依赖任何设备能力）**：档位翻转前后各打一次 `scroller.currentOffset().yOffset` 与首个可见项 index，得到"跳了多少 px / 几个 item"的数值对照 —— **`yOffset` 差值 > 一个卡片高即可判"跳变可见"**。
  4. **自由多窗 / 分屏拖拽改宽**（设备支持且应用以 tablet 形态运行时）—— 与旋转同源，都走 `onAreaChange` 跨档。
- **推定链条（本次定案的正式依据）**：「长列表 + 列数变化导致内容总高变化 + `scrollY` 为绝对偏移」三条件同时成立 → 视口顶端条目**必然改变**（只有"内容不足一屏"或"变档那一刻视口顶端恰为整表头、偏移 0"两种情形才无感，长列表实际使用基本不满足）→ 判定 **H-G-2 采纳**。**依据来源**：设备受限（手机因非大屏形态无法复现列数变化；无平板 / 折叠屏 / 可用模拟器；其它 App 横竖屏素材对本项无效），经用户于 2026-09-12 拍板"直接走兜底推定"。
- **残留回归项（非门，落地后跟踪）**：① 设备可用时按上列任一复测手段实测一次，结论回写本节与 §4.7；② 若实测为"基本无感"，允许回头精简 H-G-2（P2，非回退）。
- **为何手机旋转测不到（写清以免后人重踩）**：§1.3 断点表里「手机横屏」只到 **md（600~840vp）**，跨不到 lg（840）；更关键的是多列判据首要不是宽度而是 `isWideFormDevice` —— 文档口径明确「手机（竖 / 横）→ **非大屏形态** → 维持现状单列」（§4.1 / §4.3 / §4.4 同款表格）。**故手机上无论怎么旋转都不会发生列数变化**，手机录屏对本项复测**无效** —— 这不是"录屏能力"问题，是**物理上跨不到该档**。
- **其它 App（视频播放器等）的横竖屏切换素材：对本项不构成依据** —— 那些应用没有本工程的滚动恢复逻辑（`restoreListScroll` / 绝对 `yOffset` 保持），录到的只是"系统旋转的观感基线"（旋转时长、跟手程度）；该素材至多可用于 **H-G-3 的取舍参考**，**本项不依赖它**（H-G-2 已按推定采纳定案，无需实测触发）。
- **前置协同项（治本优先于加动画）**：§4.3 风险 3 的 `restoreListScroll` 改造（一次性恢复标志）才是去掉"形态切换时多余跳动"的第一优先项，与本项同源；**H-G 的观感增强不得替代它**（缺该项时，任何遮盖都只是盖住问题）。
- **状态**：既定取舍**已确认**（无过渡动画、不做列数补间）；三项增强**已按推荐定案** —— H-G-1 **已确认、随 H-A / H-B 落地**（规避已到可落地粒度）；H-G-2 **已确认（推定采纳，2026-09-12 拍板；推定链条与依据见上「定案依据」/「推定链条」，落地后留复测回归项）**；H-G-3 **明确不做**。三项均属**观感项、非布局项** → **本轮不开工，且不阻塞 H-A / H-B / H-D** 的「已确认」与开工。

**明确不做（避免误伤）**
1. **不给 `PagesStack` 加 maxWidth**：宽度治理归各页列数（§4.1~§4.5 已定），宿主限宽会反向压住列宽。
2. **不启用平行视界 EasyGo**：系统自动分栏会与自有多列叠成「双层分栏」→ 列入上架配置回归项。
3. 不改二级页路由与叠放关系（二级页在 Tab 内 `Navigation`，宿主底栏悬浮关系不变）。

**涉及改动点**：`Index.ets`（H-A 初值 / H-B 常量引用 / H-D 接入安全区）；`common/Theme.ets`（H-B 追加 `Breakpoint` / `Dock` 令牌 + H-D 上提 `readBottomSafeArea` 共享函数）；`ForumsTab.ets` / `UserProfile.ets`（H-A 同源初值；`UserProfile` 另将既有安全区实现改为引用共享函数）。**不新建 `common/Layout.ets`。** 另含 H-F 清理：`HomeTab.ets` / `Index.ets` / `Favorite.ets`（**已于 2026-09-12 执行完毕**，与布局几何无关，不影响上列布局改动）。**H-G-1 防抖写法与 H-A 同在 `onAreaChange` 一处，随该次改动一并落地（不新增文件、不改几何）；H-G-2 **已按推定采纳定案**，涉及 `ForumsTab.ets` / `HomeTab.ets` / `Favorite.ets` 三页各自滚动的锚定逻辑，独立一次改动。**

**断点 / 阈值**：md = 840vp（宽屏档，与现状一致）；sm = 600vp（居中浮层最大宽 440）；lg = 1440vp（预留）。

**风险与回归项**
1. H-A 在 `aboutToAppear` 若取到 0 宽（窗口未 attach）需保留 `onAreaChange` 兜底；两处取值口径必须同为 vp（`px2vp` 换算别漏）。
2. H-D 安全区取值需在横竖屏切换时重读，否则横屏沿用竖屏的安全区值。
3. H-C 已定选项 1（零改动），原「选项 3 需复核 `BottomGlow` / `layoutWeight`」的复核项**自动作废**，不再跟踪。
4. H-E 属观感项，**不作为验收阻塞条件**。
5. H-G 形态切换观感：横竖屏切换**无过渡动画**是既定取舍（列数模板不可补间）；三项增强**已按推荐定案** —— H-G-1 采纳（随 H-A / H-B 一次落地）、H-G-2 **推定采纳（已确认，2026-09-12 拍板；不再挂门，§4.7 风险 1 实测降级为落地后复测项，见 H-G「定案依据」/「推定链条」）**、H-G-3 不做。本项属观感项，**不改变 H-A / H-B / H-D 的布局结论与「已确认」状态**，也**不作为验收阻塞条件**（同 H-E）。

**风险自检（§6.2）**
- A 错位 → **有 2 处**：① H-A（`Index.ets:68-69` 初值 360 / false，平板横屏冷启动首帧窄屏跳变；规避：`aboutToAppear` 同步取宽 + `onAreaChange` 兜底）；② H-B（840 散落 `Index.ets:437` / `ForumsTab.ets:1807` / `UserProfile.ets:543`；规避：常量收口 `Breakpoint.md`）。
- B 出屏 → **无**：底栏 480 远小于宽屏门槛；隐私卡已有 600 档约束；无横向溢出路径。
- C 重叠 → **有 1 处**：H-D（`margin.bottom` 硬编码 30、无安全区补偿，平板上可能与系统导航条重叠；规避：复用 `UserProfile` 既有避让读数动态补偿 `30 + safeBottom`）。既有项 C2（二级页悬浮让位）宿主不涉及，仍按 §6.1 单独复核。
- **H-F（死参数 / 死通道清理）→ A / B / C 均为「无」**：纯命名与死代码清理，不改布局几何，不参与本节三类风险的状态判定。
- **H-G（形态切换观感）→ A / B / C 均为「无」**：不写入任何布局尺寸（H-G-3 已定为**不做**，默认无 `opacity` / 动画属性落地），不改列数 / 宽度 / 外边距。其「跨档位硬切」属**观感**，不在 §6.1 三类风险定义内 —— 按 §6.2 结论挂钩表：**H-G-1 采纳且规避到可落地粒度（可标已确认）**；**H-G-2 已按确定性推定采纳（规避链条已定 → 可标已确认，依据见 H-G「推定链条」；落地后留复测回归项）**；H-G-3 不做。三者均**不影响本节「已确认」判定**，也**不作为验收阻塞条件**（同 H-E）。

**三个待拍板点的收敛结论（2026-09-12 已定）**

| 点 | 结论 | 理由 |
|---|---|---|
| H-C 底栏档位 | **选项 1：维持 480，零改动** | 底栏该跟手不跟屏；两侧空白透出的是内容 |
| H-B 常量落点 | **并入 `common/Theme.ets`** | 那里已是 token 总仓（`Spacing` / `Radius`），新建文件反造成多来源 |
| H-D 安全区 | **动态取 + 复用 `UserProfile.ets` 现成实现** | 横竖屏避让值不同，固化常量必错；已有现成代码可搬 |

> 上表三项是**布局**待拍板点（已收敛）。H-F 那个**非布局**待定点（`favOpenSearchRequest` 死通道去留）已于 2026-09-12 定为「删除」并执行完毕 —— 不涉几何、不影响本节「已确认」状态。

**收敛后实际待做**：H-A（首帧同步取宽 —— 宿主 + `ForumsTab` + `UserProfile`）、H-B（常量归口 `Theme.ets` 并替换字面量）、H-D（安全区逻辑上提共享 + 宿主接入）。其中 H-A 与 H-D 均涉「首帧 + 异步读取」，**建议合并为一次改动**；H-C 无改动。

**另列（非布局、已定案）**：H-G 形态切换观感 —— 无过渡动画为既定取舍；**H-G-1 判据防抖采纳、并入上面的 H-A / H-B 一次落地**；**H-G-2 滚动锚定推定采纳（已确认，2026-09-12 拍板；不挂门，§4.7 风险 1 实测降级为落地后复测项；独立一次改动）**；**H-G-3 单帧遮盖不做**。

**状态**：方案**已确认**（2026-09-12，3 个布局待拍板点已收敛）；**布局改动（H-A / H-B / H-D，含 H-G-1 防抖写法）尚未执行**；**H-F 死代码清理已于 2026-09-12 执行**；**H-G 三项增强已于 2026-09-12 按推荐定案（H-G-1 采纳 / H-G-2 推定采纳（已确认，见上「定案依据」）/ H-G-3 不做），本轮不开工**。

### 4.7 全吧搜索（`pages/Search.ets`）

**适配需求（用户原话）**
- 搜索框根据**横屏 / 竖屏**自适应拉伸
- 搜索结果：**竖屏两列、横屏三列**
- 搜贴内容卡片高度不同 → **可以的话采用瀑布流**

**可行性结论：三条都能实现，且瀑布流不必引入 `WaterFlow`。** 本页现状是「全页唯一 `Scroll` + 三模块单列 `Column` + `ForEach`」，多列化只需把 `ForEach` 换成「手写分列」；滚动架构、沉浸效果、触底加载**全部不动**（详见 S-C）。

**改动前现状（已核实）**

| 项 | 现值 | 位置 |
|---|---|---|
| 形态判定 | **无**：全文件无 `isWideScreen`，无 600 / 840 / 1440 断点 | — |
| 窗口宽来源 | `@State currentWidth = 360`，由 `SearchRoot` 根 `Stack` 的 `.onAreaChange` 赋值（唯一挂点） | `Search.ets:63` / `1422-1427` |
| `currentWidth` 消费 | **仅底栏**：`pillWidth()` → `barWidth.small/medium/largeBarWidth` | `1170-1173` / `1194-1196` |
| 首帧初值 | **无**（`aboutToAppear` 只做材质 / 深色 / 入参关键词） | `97-107` |
| 滚动容器 | 全页唯一 `Scroll`（`ContentLayer`），内为 `Column`；三模块对滑 `Stack` 在其内 | `1289` / `1298` |
| 结果列表 | 三模块均 `Column({space:12})` + `ForEach` **单列**；无 `List` / `Grid` / `columnsTemplate` | 搜吧 `552/565`、搜贴 `688/689`、搜人 `758/769` |
| 结果区左右边距 | `padding({left:12,right:12})`，**三处写死** | `572` / `695` / `776` |
| 顶部搜索栏（双路径） | `FloatingHeader`（兜底自绘）与 `SearchTitleBar`（官方槽位）几何逐项一致：外层 `padding({left:12,right:12,top:44,bottom:14})`，搜索框 `layoutWeight(1).height(40).borderRadius(20)` | `1058` / `1162` |
| 让位常量 | `HEADER_TOP_SPACE=114`（顶部占位 + 渐显带高）、`BOTTOM_BAR_SPACE=130`（内容底部 padding） | `42/44` → `902` / `1294` / `1330` |
| 触底加载 | `.onReachEnd` 挂在外层 `Scroll` | `1335` |
| 底栏几何 | 官方 `barHeight(74)` + `barBottomMargin(30)` + `pillWidth()=宽−48`（下限 240）；兜底 `calc(100% - 48vp)` | `1190-1200` / `1348-1364` |

**卡片现状（决定多列后会不会挤压）**

| 卡片 | 行号 | 定高？ | 文本约束 |
|---|---|---|---|
| 搜吧推荐位 `ForumExactCard` | `577-634` | 否 | 吧名 `maxLines(1)`、slogan `maxLines(2)` |
| 搜吧行卡 `ForumRowCard` | `637-677` | 否 | 吧名 `maxLines(1)`、slogan `maxLines(1)`；**统计行 `CountText`（`459-463`）无 `maxLines`** |
| 搜贴卡 `PostCard` | `700-747` | 否 | 标题 `maxLines(2)`、正文 `maxLines(2)`；**元信息行内吧名（`718-723`）与作者名（`724-726`）无 `maxLines`、无 `layoutWeight`** |
| 搜人推荐位 `UserExactCard` | `781-832` | 否 | `maxLines(1)` / 简介 `maxLines(2)` |
| 搜人行卡 `UserRowCard` | `835-868` | 否 | 昵称 `maxLines(1)`；**`@userName` 与粉丝行无 `maxLines`** |

**通栏项清单**（多列时必须留在列之外，§6.2 第 3 步）：`SectionHeader`（`439-456`）、`ForumExactCard`、`UserExactCard`、`EmptyView`、`ModuleFooter`（`873-891`）、引导态、顶部占位 `Column().height(114)`。

**设计方案**

**S-A 搜索框自适应拉伸（顶栏与内容共用同一条「内容宽度」）**
- 现状：搜索框 `layoutWeight(1)` 撑满整行 → 平板横屏可达 1100vp+，过长；且两条路径各写一份几何。
- 方案：顶栏搜索行与结果区**共用同一内容宽度**，超出即居中收窄：

```text
Row().justifyContent(FlexAlign.Center)                      // 外层居中
  └ Column().width('100%').constraintSize({ maxWidth: Content.maxWidth })
        .padding({ left: sideMargin, right: sideMargin })
```

- 三档表现：窄屏（< 840）`constraintSize` 不触发 → **手机端逐像素不变**；平板竖屏拉满；平板横屏封顶居中，且搜索框左 / 右边缘与结果卡**咬合**。
- 依据：§4.2 硬约束 3 —— 「大屏内容居中收窄时，顶部按钮必须套进同一个居中容器」。本方案正是把顶栏与内容放进**同一个 `maxWidth` 容器**，不产生错位台阶。
- `sideMargin` 取 `Spacing.md`（= 12，本页现状就是 12，**不改**，避免手机基线变化）。

**S-B 列数与形态判定（手机 1 / 平板竖屏 2 / 平板横屏 3）**
- 单一判定函数（收口，§6.2 第 6 步）：
  - `isWide() = pageWidth >= Breakpoint.md`（840）
  - `isLandscape() = pageWidth > pageHeight`
  - `resultColumns() = !isWide() ? 1 : (isLandscape() ? 3 : 2)`
- **为何用宽高比而非宽度断点**：平板竖屏 1024、横屏 1280 **都 ≥ 840**，宽度断点区分不开横竖；`width > height` 才真正表达「横竖屏」，也符合官方「按窗口尺寸而非设备类型」口径（自由多窗拖宽 → 自动升列）。
- 单一挂点：沿用 `SearchRoot` 根 `Stack` 的 `onAreaChange`（`1422-1427`），同点一并更新 `pageWidth` / `pageHeight`。
- 首帧：`aboutToAppear`（`97`）追加同步取窗口宽高（`display.getDefaultDisplaySync()`，§6.1 A5 同款），避免「冷启动横屏首帧 1 列 → 次帧 3 列」跳变（与 §4.6 H-A 同一坑）。

**S-C 三模块多列 + 搜贴瀑布流：手写分列，不引入 `WaterFlow`**
- 做法：把每个模块的 `ForEach` 换成「先分列、每列一个 `Column` 堆叠」：

```text
Row({ space: 12 }) {
  ForEach(this.splitColumns(items, this.resultColumns()), (col: Item[]) => {
    Column({ space: 12 }) { ForEach(col, (item) => 卡片) }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)
  })
}
```

- 分列算法：单一泛型函数 `splitColumns(items, cols, estimate)` —— 逐项累加**估算高度**，投入当前最矮的列（标准瀑布流装箱）。搜贴卡传入「文本行数 → 高度」估算器；搜吧 / 搜人卡等高，估算器返回常数 → 退化为顺序均分。
- **为什么不引入 `WaterFlow`**（三条硬理由）：
  1. 全工程 **零 `WaterFlow` 先例**；且本页现状只有**一个** `Scroll`，换成 `WaterFlow` 等于拆掉它 → 三模块各自滚动、顶部 114 占位、底部 130 让位、`TopFadeOverlay` 的 `.overlay()`（`1337`）、`onReachEnd`（`1335`）全部要重排。
  2. `WaterFlow` **不支持单项跨列** → 搜吧 / 搜人的推荐位与 `SectionHeader` 这些通栏项还得再上 `WaterFlowSections` 分段，且数据每次变更都要重算段。
  3. 手写分列**保留外层 `Scroll`**：通栏项天然落在分列 `Row` 之外（第 3 步 ✅）、沉浸滚动与渐显带不变、`onReachEnd` 不变、**手机单列时逐像素不变**。
- 额外收益：每列独立堆叠 → **「末行不满被拉伸」天然不存在**（§6.2 第 4 步 ✅，不需要 `xxxBlankSlots`）。
- 搜贴卡高差口径：标题 1~2 行 + 正文 0~2 行，最大高差约 2 行 ≈ 36vp；瀑布流把这部分差异吸收进列内，避免 `Grid` 的整行对齐留白。

**S-D 窄列行内挤压（多列后新增风险，必做）**
- 3 列（每列 ≈ 317vp，扣卡内 `padding 14×2` 后可用 ≈ 289vp）时以下行都有被压的余地：
  - 搜贴元信息行（`717-738`）：徽标 + **作者名** + 时间 + `Blank()` + 回复数，`space: 8` → 给作者名 `.layoutWeight(1).maxLines(1).textOverflow(Ellipsis)`，把「回复 N」钉在右端。
  - 搜吧行卡统计行（`CountText`）、搜人行卡 `@userName` / 粉丝行 → 补 `maxLines(1)` + `textOverflow`。
- 备选（不想截断长昵称）：列数 ≥ 2 时元信息行拆两行（吧名 + 时间 / 作者 + 回复数）。
- 单列（手机）下这些约束**不改变观感**（宽度充足，截断不触发）。

**S-E 与 §6.1「范围提醒」的关系（文档已同步）**
- §6.1 文末原写「二级页（含 `Search`）**本轮不做多列**」；本次已同步为该结论的**例外之一**：`Search` 改做 1 / 2 / 3 列，其余二级页维持单列。§6.2「二级页也要过」同句一并更新。
- **2026-09-13 追加**：`ThreadList`（吧内帖子列表）成为**第二个例外页**（见 §4.8，含本吧搜索态，同为竖 2 / 横 3）。两页「多列档判据」的口径差异与收口安排见 §4.8 的「前置依赖」小节（本节用 `pageWidth ≥ 840`，§4.2 / §4.4 用 `isWideFormDevice && pageWidth ≥ 600`）。

**涉及改动点**
- `Search.ets`：S-A（两条搜索栏共用限宽容器 + 常量）、S-B（新增 `isWide()` / `isLandscape()` / `resultColumns()`、`aboutToAppear` 取宽高初值、`onAreaChange` 同时取高）、S-C（三模块 `ForEach` → 分列 `Row` + 新增 `splitColumns()`）、S-D（作者名 / 统计行 / `@userName` 补 `maxLines`）
- `common/Theme.ets`：`Content.maxWidth`（与 §4.6 H-B 同一落点；**尚未落地**，详见下方「前置依赖」小节）
- 文档：§6.1 范围提醒、§三 第 7 项状态、§6.2 已过检记录

**前置依赖：`Breakpoint` / `Content` 令牌尚未落地（不落地则本节无法开工）**

本节新增的两个常量都**不在本页定义**，取自 §4.6 H-B 已规划归口到 `common/Theme.ets` 的令牌：

| 本节使用点 | 依赖令牌 | 值 | 该令牌现状 |
|---|---|---|---|
| S-A 限宽容器（顶栏与内容共用） | `Content.maxWidth` | 1000vp | 已规划（§4.6 H-B），**未落地** |
| S-B `isWide()` 宽屏判据 | `Breakpoint.md` | 840 | 已规划（§4.6 H-B），**未落地** |
| S-A `sideMargin` / S-C 列间距 | `Spacing.md` | 12 | **已存在**，可直接引用 |

- **依赖方向是单向的**：§4.7 → §4.6 H-B。H-B 落地**不依赖**本章，可独立先行；本章落地**必须先有**上述两个令牌。
- **开工顺序（推荐）**：先落 §4.6 H-B 的 `Theme.ets` 三组令牌（`Breakpoint` / `Dock` / `Content`），再做本节 S-A / S-B / S-C / S-D。H-B 与本节同属「平板适配」两条链上的相邻改动，先 H-B 不产生返工。
- **禁止的绕法**：在本页内联 `840` / `1000` 字面量。① 立刻违反 §6.2 第 2 步「左右外边距单一来源」与第 6 步「形态判定单一函数」；② 与 §4.6 宿主壳判宽用同一断点，两处字面量必然漂移（这正是 §4.6 H-B 要收口的问题本身）。
- **若必须先做本节**：则把 `Content.maxWidth` 的落地**顺带**并入本次改动（同一文件同一区域：`Theme.ets:936-973` 既有 token 区尾部），但 `Breakpoint` / `Dock` 仍须一并补 —— 否则 `isWide()` 无常量可引。**实质等于提前执行 H-B 的一部分，会在 §4.6 留下「一半已落、一半未落」的中间态，不建议。**
- **因此本节的准确状态是「方案已确认，但等前置」**：方案不动、待拍板点已收敛，唯独不能开工；**本轮不动任何代码**。

**断点 / 阈值**
- `Breakpoint.md = 840`（进入多列档，与 §4.6 共用，**尚未落地**）
- 横竖屏：`pageWidth > pageHeight`
- `Content.maxWidth = 1000vp`（已定，与 §4.6 H-B 同一令牌，**尚未落地**）
- 列数 1 / 2 / 3；列间距 `Spacing.md(12)`；左右 `sideMargin = Spacing.md(12)`
- 上述 `Breakpoint.md` 与 `Content.maxWidth` 均为 §4.6 H-B 归口令牌，落地前本节不开工（见「前置依赖」小节）

**风险与回归项**
1. 列数变化（旋转 / 拖窗）后 `Scroll` 总高改变 → **滚动位置是否跳变**：**已由 §4.6 H-G-2 按确定性推定采纳（2026-09-12），本项不再是 H-G-2 的前置门**，降级为 H-G-2 **落地后的复测项**（复测若"基本无感"，可回头精简 H-G-2）。受设备限制，复测须走等效路径 —— 手机因「非大屏形态」无法复现列数变化（§4.6 H-G 已有说明），改用折叠屏展开旋转 / 模拟器 Tablet / 代码级量化 / 自由多窗拖宽。结论仍须回写本节与 §4.6 H-G。
2. 首帧取宽失败（窗口未 attach）需保留 `onAreaChange` 兜底；`px2vp` 换算口径别漏（同 §4.6 H-A）。
3. `splitColumns` 的估算**只用于分配、不参与布局尺寸** → 偏差仅影响「列底参差程度」，不会造成错位 / 出屏（这是选手写分列而非容器瀑布流的核心理由）。
4. 分列不改变 `ForEach` 的 key（仍 `${tid}_${pid}_${createTime}`）→ 无重建抖动。
5. 底栏 `pillWidth()` **不动**（§4.6 H-C 已定「底栏跟手不跟屏」）。
6. 本页**无定高卡**（五类卡均未写死 `height`）→ 无 §6.1 B4 / B6 类风险；S-D 是唯一新增文本约束点。
7. 本页**无回顶钮**（已核实：无 `scrollTo` / 回顶符号）→ §6.1 C2 的「回顶钮」部分不涉及；但 C2 的「底部悬浮栏让位」与本页 `BOTTOM_BAR_SPACE=130` 相关，横屏矮视口下需复核。

**风险自检（§6.2）**
- A 错位 → **有 2 处**：① 双路径（`FloatingHeader:1058` / `SearchTitleBar:1162`）几何必须同步改，否则兜底与官方槽位两态搜索框宽度不一致（A3 类；规避：两处共用同一常量 + 同一限宽容器写法）；② 顶栏与内容边缘咬合（A4 类；规避：搜索行与结果区共用同一 `Content.maxWidth` 与 `sideMargin`）。
- B 出屏 → **无**：列宽 `layoutWeight(1)` 均分、卡片 `width('100%')`、无横向滚动路径；`expandSafeArea` 只扩上 / 下、不扩左右（`1202` / `1386` / `1421`）。
- C 重叠 → **有 1 处**：S-D 窄列下行内文本无 `maxLines` / 无 `layoutWeight` 时会换行或挤压（规避：补 `maxLines(1)` + `textOverflow` + `layoutWeight(1)`）。既有项 C2（底部悬浮让位）横屏矮视口下需复核，属回归项。

**五个待拍板点的收敛结论（2026-09-12 已定，均按原建议值采纳）**

| # | 点 | 结论 | 理由 |
|---|---|---|---|
| 1 | 横屏搜索框封顶 | **封顶 `Content.maxWidth = 1000vp` 并居中** | 顶栏与内容必须共用同一宽度容器（§4.2 硬约束 3）；不封顶时横屏搜索框约 1232vp，与结果区不成比例、观感空旷 |
| 2 | 横竖屏判据 | **`pageWidth > pageHeight`**（不取 1.2 比值） | 平板竖 1024 / 横 1280 **都 ≥ 840**；宽高比本身就是「横竖屏」的定义，比值阈值在近方形窗口下会抖 |
| 3 | 搜贴高度估算器 | **标题 / 正文行数启发式**（基线 + 标题行高 + 正文行高） | 估算只参与列分配、不参与布局尺寸 → 粗粒度足够；用常数会让高差大的卡串列 |
| 4 | 搜吧 / 搜人分列策略 | **顺序均分**（估算器返回常数） | 这两类卡等高等宽，装箱结果与均分一致，省一层计算 |
| 5 | S-D 规避方式 | **截断：`maxLines(1)` + `textOverflow(Ellipsis)`** | 与全工程既有做法一致（昵称 / 吧名均 `maxLines(1)`）；拆两行会改变单列（手机）下的行高 |

**收敛后实际待做**：S-A（两条搜索栏 + 结果区共用同一限宽容器）、S-B（`isWide()` / `isLandscape()` / `resultColumns()` + `aboutToAppear` 首帧取宽高 + `onAreaChange` 同时取高）、S-C（`splitColumns()` + 三模块改分列）、S-D（作者名 / 统计行 / `@userName` 补 `maxLines(1)` + `textOverflow`）。**四项均引用 §4.6 H-B 令牌，前置未落地前不可开工**（见上方「前置依赖」小节）。

**状态**：方案**已确认**（2026-09-12，5 个待拍板点已收敛）；**代码尚未执行**，且**受前置依赖阻塞**（`Breakpoint.md` / `Content.maxWidth` 待 §4.6 H-B 落地后才有常量可引）—— **本轮不开工，等待前置**。

### 4.8 吧内帖子列表（`pages/ThreadList.ets`）

**适配需求（用户原话，2026-09-13）**
- 吧信息（吧头像 / 吧名 / 经验条 / 签到钮）**无论横竖屏都单给一列**；吧头像 / 吧名 / 经验条**左对齐**，签到钮**右对齐**
- 其下的**置顶卡片与帖子卡片跟首页一致方案**
- **列数口径：与首页 §4.2 决策 12 一致 = 竖屏 3 列 / 横屏 4 列**（用户 2026-09-13 追加拍板，替换原「竖 2 / 横 3」草案）
- **置顶区也纳入多列网格**（用户 2026-09-13 追加拍板：不再保持「整块通栏卡」，置顶条目与普通帖同列数排布）
- **多列档改为与首页同款 `WaterFlow` 瀑布流**（用户 2026-09-13 追加）：**置顶卡作为瀑布流的普通卡片格子、不拉伸**；**吧头不固定、随内容流动**（见 T-G）
- 本吧搜索态**同样多列**（同列数口径）
- **平板下「保持原尺寸 / 原位置」的三项**（用户 2026-09-13 追加拍板）：① 吧头**经验条不拉伸**；② 底部排序**底栏宽度不拉伸**；③ 右下**加号按钮（FAB）不拉伸、位置不变**
- 手机端保持现状不变

**选型结论：方案 A「行分组」（与 §4.4 消息页同款，不换滚动容器）—— 用户 2026-09-13 已拍板**

三条理由：
1. **通栏项天然成立**：顶部 90 占位、吧头块、置顶整体卡、加载更多行、底部让位都是分列 `Row` 的**兄弟节点**，不需要 `ListItemGroup.header/footer` 一类改造；
2. **滚动架构零改动**：`contentH` 测量（`onContentAreaChange`）、预加载判据（`remaining = contentH − viewportH − y`）、排序切换快照（`captureExitSnapshot` 依赖 `THREAD_SCROLL_SNAPSHOT_ID` 的 `Scroll` 矩形 + `headerBlockH` 裁剪）、`onReachEnd`、`edgeEffect` / `overlay` / `expandSafeArea` / `blendMode` **全部原样保留**；
3. **改动面只有「帖子区 / 搜索结果区的 `ForEach`」**。

**不选另外两条**
- `WaterFlow`（§4.2 首页选型）：本页正是 `floor-vanish-viewport-fix` 的触发组合（沉浸 + 底部悬浮排序栏 + FAB），且 `Scroll` 里还装着吧头与快照裁剪锚点 → 换容器代价远高于首页；再叠加 `WaterFlow` 不支持**通栏项**（吧头块 / 「置顶」标签行 / 加载更多行 / 三种提示态要另上 `WaterFlowSections`）。**注：置顶条目本身已按用户 2026-09-13 决策纳入网格，但「置顶」标签行仍是通栏**，本条理由依旧成立。
- `Grid` 等高网格：同样要迁滚动容器（快照 id、`onScroll`、`edgeEffect`、底部渐隐 `overlay`、`expandSafeArea` 全要重挂），而行内留白与方案 A 同款 → 收益不抵成本。

**改动前现状（已核实，2026-09-13）**

| 项 | 现值 | 位置 |
|---|---|---|
| 形态判定 | **无** `isLandscape` / 无断点；§4.1 同款 `isWideFormDevice` 判据未在本页引入 | — |
| 窗口宽来源 | `@State currentWidth = 0`，由 `ThreadListContent` 根 `Stack` 的 `.onAreaChange` 回填 | `401` / `2282` |
| `currentWidth` 消费 | **仅底部排序槽位壳**的 `barWidth` | `2609` |
| 窗口高 | **无**（`viewportW` / `viewportH` 是 `Scroll` 视口尺寸，不是窗口尺寸，**不能**当横竖屏判据） | `339-341` / `1848-1850` |
| 滚动容器 | 全页唯一 `Scroll(listScroller)`，`id = THREAD_SCROLL_SNAPSHOT_ID` | `1969-2129` |
| 帖子区容器 | `Column({ space: 6 })` + `.padding({ left: 12, right: 12 })` | `2010` / `2082` |
| 置顶区 | **整体卡**：`Column({ space: 0 })`（内「置顶」标签行 + `ForEach(PinnedThreadItem)`），整块 `bgCard` + `borderRadius(26)` | `2012-2040` |
| 普通帖 | `ForEach(this.normalThreads())` → `ThreadCard`，**单列直铺** | `2043-2064` |
| 搜索结果 | `SearchResultsBuilder()` 内 `ForEach(this.searchThreads())` → `ThreadCard`，同样单列；根 `.padding({ left: 12, right: 12 })` | `2821-2846` / `2868` |
| 骨架屏 | `ThreadListSkeleton({ count: 4 })` → 内部单列 `Column` 堆叠 | `2087` / `Skeleton.ets:115-123` |
| 吧头区 | `ForumHeaderBuilder()`：`Row({ space: 16 })` = 头像 88 + 信息列 `layoutWeight(1)`（吧名 / 经验条 + 签到钮 / 等级），`.padding({ left: 12, right: 12, top: 16, bottom: 12 })` | `2630-2740` |
| 悬浮层 | 顶栏（槽位 / 兜底双路径）、FAB（56，右 28 / 下 36）、底部排序槽位壳（56 + 底距 30） | `2131+` / `2243+` / `2272` |
| 底部让位 | `contentBottomSpace()` = 98（槽位）/ 104（兜底）/ 150（搜索态） | `2620-2627` |

**T-A 吧头区（用户诉求 1）：现状已满足，几何零改动**

现状即「一列 + 左右对齐」，**不需要任何改动**：

```text
Row({ space: 16 })                          // 2631，始终单列
  ├ 吧头像（88 圆）                           // 2633-2655
  └ Column({ space: 8 }).layoutWeight(1)     // 2658，左对齐（alignItems(Start)）
       ├ 吧名                                // 2660，maxLines(1)
       ├ Row({ space: 12 })
       │    ├ 经验条列 .layoutWeight(1)       // 2669-2692（进度条 + 经验值，Start 对齐）
       │    └ 签到钮                          // 2694-2713（贴信息列右缘）
       └ 等级 / 等级名
```

- **头像 / 吧名 / 经验条左对齐**：由 `alignItems(HorizontalAlign.Start)` 保证（`2692` / `2735`），已是现状，不动。
- **签到钮右对齐**：它排在 `Row({ space: 12 })` 末位、经验条列 `layoutWeight(1)` 吃掉余量 → 视觉上贴**信息列右缘**；信息列右缘 = 内容区右缘 − 12（吧头 `padding` 12，`2738`）。
- **是否横屏限宽**：本页**不引入** `Content.maxWidth`（§4.7 S-A 的居中限宽是为「搜索框横屏过长」引入的，本页无此问题）。若引入，吧头与帖子网格必须共用同一限宽容器，否则边缘错位（§4.2 硬约束 3）。**默认保持贴屏 12。**
- 唯一回归项：签到钮文字在「未关注 / 未签到 / 已签到 N 天」中最长者时，胶囊是否仍在信息列内 —— 现状已如此，多列化不改变吧头宽度，**无新增风险**。

**T-B 列数与形态判定（单一函数 + 单一挂点 + 首帧初值）**

- 列数（与首页 §4.2 / 消息页 §4.4 **同一口径**）：

```ts
private threadColumns(): number {
  if (!this.isWideFormDevice) return 1;      // 手机：现状单列
  if (this.pageWidth < Breakpoint.sm) return 1;  // 折叠态 / 分屏 / 自由多窗窄窗
  return this.isLandscape ? 4 : 3;           // 平板横 4 / 竖 3（与首页 §4.2 决策 12 同口径）
}
```

- **横竖屏判据**：`pageWidth > pageHeight`（与 §4.7 S-B 同款）。**不能用** `viewportW / viewportH` 顶替 —— 那是 `Scroll` 视口尺寸（`339-341`），横屏时已被顶部 90 占位与底部让位吃掉，与窗口高不等。
- **挂点**：复用现有 `ThreadListContent` 根 `Stack` 的 `.onAreaChange`（`2282`，现只回填 `currentWidth`）→ 同点追加 `pageHeight`，`isLandscape` / `isWideFormDevice` 一并在此更新。
- **首帧初值**：`aboutToAppear` 用 `display.getDefaultDisplaySync()` 同步取窗口宽高（同 §4.6 H-A / §4.7 S-B），避免「冷启动横屏首帧 1 列 → 次帧 3 列」跳变。
- **列数下发**：`ThreadCard` 内部几何比例化走 §4.2 决策 6 已定的全局只读标记（`@StorageProp('cardColumns')`）→ 本页 **2 处调用点（`2044` / `2822`）零改动**；`aboutToAppear` 与 `onAreaChange` 同步写入该标记。
  - ⚠️ **写入纪律（手机零回归的关键）**：`cardColumns` 必须是**无条件写**（单列档也写 1），**不允许**「只在多列时写」。它是 `AppStorage` **全局单值**、`@StorageProp` 单向订阅，被本页 2 处 + `HomeTab` 2 处（`1384` / `1498`）共 4 处调用点共享 → 只要有一页残留 2 / 3，**另一页在手机上就会按多列几何渲染**。必然触发的场景是**折叠屏展开(2 列) → 折叠(应回 1 列)**：折叠时若不写 1，再进本页单列就会看到单图 `height(220)` 变比例高、摘要被裁到 2 行。
- **列数变化后的滚动位置**：本页 `Scroll` 总高随列数改变（同 §4.7 风险 1）→ 沿用 §4.6 H-G-2「按确定性推定采纳」，降级为**落地后复测项**（等效路径见 §4.6 H-G）。

**T-C 帖子区多列：行分组 + 末行补空位（照抄 §4.4 写法）**

新增纯函数（无容器依赖）：

```ts
private threadRows(items: ThreadItem[]): ThreadItem[][] {
  const cols: number = this.threadColumns();
  const rows: ThreadItem[][] = [];
  for (let i = 0; i < items.length; i += cols) {
    rows.push(items.slice(i, i + cols));
  }
  return rows;
}

/** 末行补空位：不足 cols 时用等宽空白补齐，避免最后一张卡被拉伸占满整行 */
private threadBlankSlots(rowLen: number, cols: number): number[] {
  const slots: number[] = [];
  for (let i = rowLen; i < cols; i++) { slots.push(i); }
  return slots;
}
```

列表分支改写（**n = 1 走原逻辑、n ≥ 2 走行分组**，手机端逐像素不变）：

```ts
if (this.threadColumns() <= 1) {
  ForEach(this.normalThreads(), (item: ThreadItem) => { /* 现状 ThreadCard 调用，逐像素不变 */ }, keyOf)
} else {
  ForEach(this.threadRows(this.normalThreads()), (row: ThreadItem[], rowIdx: number) => {
    Row({ space: 6 }) {
      ForEach(row, (item: ThreadItem) => {
        // 必须包一层：ThreadCard 自身 width('100%')，直接挂 layoutWeight(1) 不生效
        Column() { /* ThreadCard 调用 */ }
          .layoutWeight(1)
      }, keyOf)
      ForEach(this.threadBlankSlots(row.length, this.threadColumns()), (slot: number) => {
        Column().layoutWeight(1)
      }, (slot: number) => `gap_${rowIdx}_${slot}`)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)        // 行内卡片各自贴顶，不被拉伸
  }, (row: ThreadItem[], rowIdx: number) => `row_${rowIdx}_${row[0].tid}`)
}
```

- **间距口径**：帖子区现状 `Column({ space: 6 })`（`2010`）与左右 `padding 12`（`2082`）**都不动** → 列间距 = 行间距 = 6，外边界仍是 12。
  > ⚠️ 与 §4.2 / §4.4 的口径差异要留意：首页 / 消息页左右是 `Spacing.lg(16)`，本页帖子区是 **12**、悬浮顶栏是 **16**（`2231`）。这属**改造前就存在的差异**（非本次引入），且顶栏是悬浮层、帖子区是内容层，二者边缘本就不咬合 → 本次**不动**（避免手机端基线变化）。
- **置顶区：条目入网格、标签行保持通栏**（用户 2026-09-13 拍板，替换原「整块通栏卡」草案）。结构改为：

```ts
Column({ space: 0 }) {                      // 整体卡背景与圆角保留（2017-2043 不动）
  // 「置顶」标签行：通栏，不参与网格
  Row() { Text('置顶') /* 2020-2026 不动 */ }
  .width('100%')
  .padding({ left: 16, right: 16, top: 14, bottom: 4 })

  // 置顶条目：n=1 走原逻辑、n≥2 走行分组（与 T-C 同款 threadRows/threadBlankSlots）
  if (this.threadColumns() <= 1) {
    ForEach(this.pinnedThreads(), (item: ThreadItem) => { /* 现状 PinnedThreadItem，逐像素不变 */ }, keyOf)
  } else {
    ForEach(this.threadRows(this.pinnedThreads()), (row: ThreadItem[], rowIdx: number) => {
      Row({ space: 6 }) {
        ForEach(row, (item: ThreadItem) => {
          Column() { /* PinnedThreadItem 调用 */ }
            .layoutWeight(1)
            .backgroundColor(Theme.bgCard(this.isDark))
            .borderRadius(26)
        }, keyOf)
        ForEach(this.threadBlankSlots(row.length, this.threadColumns()), (slot: number) => {
          Column().layoutWeight(1)
        }, (slot: number) => `pin_gap_${rowIdx}_${slot}`)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }, (row: ThreadItem[], rowIdx: number) => `pin_row_${rowIdx}_${row[0].tid}`)
  }
}
.width('100%')
.backgroundColor(Theme.bgCard(this.isDark))   // 整体卡背景保留
.borderRadius(26)
```

- **背景口径（用户拍板后的新增点）**：多列档给每张置顶条目**包独立 `bgCard` + `borderRadius(26)`**，与普通帖 `ThreadCard`（自带背景+圆角）外观统一；整体卡背景保留是为了「标签行 + 条目」仍属同一视觉区块。**单列档完全不动**（仍是整体卡 + 无独立背景的单列条目）。
- **末行补空位**：置顶通常仅 1~3 条，4 列时末行大概率不满 → `threadBlankSlots()` 必补（与 T-C 同款），键前缀 `pin_gap_` 避免与帖子区空位键冲突。
- **通栏项（§6.2 第 3 步）**：顶部 90 占位、吧头块、**「置顶」标签行**、加载更多行、`EmptyView` / `ErrorView` / 骨架屏、底部 `padding` —— 全部在分列 `Row` 之外 ✅。

**T-D 搜索态多列（同一套行分组；用户 2026-09-13 定：与列表态同列数 = 竖 3 / 横 4；**2026-09-14 二次更正：改「列内独立堆叠 + 方案 B 分桶」瀑布流**）**

- ~~`SearchResultsBuilder()` 内 `ForEach(this.searchThreads())` → 同一 `threadRows()` + 行分组 + 末行补空位~~ → **2026-09-14 用户要求「跟首页一样的瀑布流」**：行分组会把矮卡下方留白拉大（有无图 / 图多图少交错时尤甚）→ 改**列内独立堆叠 + 方案 B 带滞回最短列分桶**（`searchColumnsData()` + `estimateSearchCardHeight()` + `searchColIndexes()`，阈值 `THREAD_SEARCH_COL_BALANCE_THRESHOLD=240`，与 §4.9 / §4.10 / 收藏页同款）。结构照收藏页五轮教训：外层 ForEach **只遍历列索引**（key 稳定复用列容器），内层数据源**直读状态源** `searchColumnsData()[colIdx]`（不用外层传入 col，否则复用断链不更新）；新增卡片 160ms 淡入。
- **容器不变**：搜索态在外层 `Scroll` 内（与列表态多列的 `WaterFlow` 整页滚动是不同容器），`WaterFlow` 嵌 `Scroll` 是滚动劫持反模式 → 不换容器，滚动 / 预加载（`onScroll` 提前取批）/ `onReachEnd` 兜底 / `maybeAutoContinueSearch` 全部原样。
- **通栏项**：进度行、三种提示态（空关键词 / 正在搜索 / 未找到）、底部状态行—— 全在分列 `Row` 之外 ✅；固定高 320 的三个提示态是通栏，**不被列宽压缩**，不动。
- **`cardColumns` 无需处理**：`syncCardColumns()` 本就无条件下发 `threadColumns()`，搜索态多列下 `ThreadCard` 已按多列几何渲染（标题 2 行 / 图 1.6 比例 / 宫格 1:1 封顶）。
- 搜索态**没有置顶区**（只出 `ThreadCard`）→ T-C 的置顶讨论不涉及搜索态。
- 取数逻辑（`FSEARCH` 服务端优先 + 本地兜底扫描、`searchNextBatch`、`maybeAutoContinueSearch`、`onReachEnd` 兜底）**零改动**，只改渲染层。

**T-E 骨架屏按列数铺（消「Loading 单列 → 加载完跳多列」）**

- `ThreadListSkeleton`（`Skeleton.ets:110-124`）现状单列 `Column({ space: Spacing.md })`。建议加可选入参 `columns: number = 1`，列 ≥ 2 时同样按行分组（`ThreadCardSkeleton` 的高度分布 240 / 300 / 200 保持不变，`Row` 内 `alignItems(Top)`）。
- ⚠️ **`columns` 默认值必须是 1，且列 = 1 走原分支（不套行分组容器）**：该组件**共 5 处调用点、跨 3 页** —— `HomeTab.ets:1363` / `1478`、`UserProfile.ets:832` / `925`、`ThreadList.ets:2087`。其中 `UserProfile`（个人主页帖子 / 赞过）属**不做多列的二级页**，必须保持单列；`HomeTab` 两处若 §4.2 要多列，由 §4.2 自行传参，**本页不越界改**。
- 默认**做**（成本低、跳变肉眼可见）；如需零改动可只保留单列 → 列为**待拍板点 2**。

**T-F 平板下「保持原尺寸 / 原位置」的三项（用户 2026-09-13 追加拍板）**

**问题根源**：本页三处几何都按「屏宽」计算、或由 `layoutWeight(1)` 吃余量 → 屏越宽拉伸越明显。

**① 吧头经验条不拉伸**

源头链：信息列 `layoutWeight(1)`（`2738`）吃余量 → 经验条列 `Column({ space: 4 })` 的 `layoutWeight(1)`（`2695`）跟着吃 → 进度条 `Stack.width('100%')`（`2686`）填满 → 经验条被拉长。

```ts
// 经验条列（Column({ space: 4 })，2694-2696）
.layoutWeight(1)
.constraintSize({ maxWidth: this.threadColumns() > 1 ? THREAD_LIST_EXP_BAR_MAX_WIDTH : 99999 })
```

- `THREAD_LIST_EXP_BAR_MAX_WIDTH ≈ 220`（手机 360vp 下经验条可用宽的量级，真机可调）；
- ⚠️ 经验条限宽后签到钮会**左移贴住经验条** → 必须在经验条列与签到钮之间补 `Blank()`（或把外层 `Row({ space: 12 })` 改 `justifyContent(FlexAlign.SpaceBetween)`），让**签到钮仍贴信息列右缘**（保持现状观感）；
- 手机档 `maxWidth` 取大值（不限）→ 该档逐像素不变。

**② 底部排序底栏宽度不拉伸**

源头：`sortBarWidth()`（`2611-2615`）= `currentWidth − 24 − 92` → 屏越宽栏越宽。

```ts
private sortBarWidth(): number {
  const fabColumn: number = THREAD_LIST_FAB_SHELL_WIDTH + THREAD_LIST_SORT_BAR_GAP;
  const w: number = this.currentWidth > 0 ? this.currentWidth - 24 - fabColumn : 244;
  const capped: number = Math.min(w, THREAD_LIST_SORT_BAR_MAX_WIDTH);   // ★ 新增上限
  return capped > 184 ? capped : 184;
}
```

- `THREAD_LIST_SORT_BAR_MAX_WIDTH = 244`（= 手机 360vp 屏宽下的底栏宽，即改动前取值）；
- 底栏槽位壳位置锚点**不动**（`.justifyContent(Start)` + `.padding({ left: 24 })`，`2536-2539`）→ 平板上底栏**靠左、宽度固定**。

**③ 右下加号按钮（FAB）不拉伸、位置不变**

- 几何现状**已是固定值**：壳 `80×56`（`2439-2440`）、钮 `56` 圆（`2476-2478`）、`Stack(BottomEnd)` 靠屏幕右缘 + 右 `padding 24`（`2486`）、底距 `30`（`2448`）→ **FAB 自身零改动**；
- 唯一受影响的是「FAB 与底栏的相对关系」：底栏限宽后，FAB 仍靠**屏幕右缘**，而非紧邻底栏 → 位置锚点见下方待拍板。

**T-F-③ 实施：FAB 位置锚点 = 选项 B + 整体居中（用户 2026-09-13 先拍板「按 B」，再追加「不能居中对齐吗」）**

把底栏与 FAB **合成一个整体居中的 `Row`**，替代现状「底栏 `Row(100%)` 左对齐 + FAB `Stack(BottomEnd)` 右靠」两处独立悬浮层。

> ⚠️ **手机零回归约束（居中必须条件化）**：现状注释明确手机布局是「**左 24 | 底栏 244 | 缝 12 | 加号壳 80（含右 24）**」= **恰好占满 360**（`ThreadList.ets:159`）。若直接 `justifyContent(Center)`，组合净宽 336 会在 360 屏上居中 → **左缘 24 变 12、右侧空出 12**，手机档即被破坏。故锚点必须按列数分档：**单列（手机）保持现状左对齐 + 左缘 24，多列（平板）整体居中**。

```ts
// 新增 @Builder BottomGroupShell()，替换 ThreadListContent 内的
//   this.FabSlotShell()  +  this.SortSlotShell()  两处调用
Row() {
  // 底栏槽位壳（原 SortSlotShell 的 Tabs，宽由 sortBarWidth() 变固定 THREAD_LIST_SORT_BAR_MAX_WIDTH）
  Tabs({ barPosition: BarPosition.End }) {
    TabContent().tabBar(this.SortSegBar())
  }
  .width(THREAD_LIST_SORT_BAR_MAX_WIDTH)          // ★ 244 固定（不随屏宽拉伸）
  .height(THREAD_LIST_SORT_BAR_HEIGHT)
  .barHeight(THREAD_LIST_SORT_BAR_HEIGHT)
  .barBackgroundColor(Color.Transparent)
  .barBackgroundBlurStyle(BlurStyle.NONE)
  .backgroundColor(Color.Transparent)
  .clip(false)
  .hitTestBehavior(HitTestMode.None)
  .transition(this.searchSwap(0, 24))             // 保留进出搜索态动效

  Blank().width(THREAD_LIST_SORT_BAR_GAP)          // ★ 缝 12

  // FAB 槽位壳（原 FabSlotShell 的 Tabs，几何不变）
  Tabs({ barPosition: BarPosition.End }) {
    TabContent().tabBar(this.FabSlotColumn())
  }
  .width(THREAD_LIST_FAB_SHELL_WIDTH)              // 80
  .height(THREAD_LIST_FAB_SHELL_HEIGHT)            // 56
  .barHeight(THREAD_LIST_FAB_SHELL_HEIGHT)
  .barBackgroundColor(Color.Transparent)
  .barBackgroundBlurStyle(BlurStyle.NONE)
  .backgroundColor(Color.Transparent)
  .clip(false)
  .opacity(this.fabReveal())                       // 保留 FAB 显隐动效
  .scale({ x: this.fabReveal(), y: this.fabReveal() })
  .translate({ y: (1 - this.fabReveal()) * 20 })
  .hitTestBehavior(HitTestMode.None)
  .animation({ duration: 220, curve: Curve.FastOutSlowIn })
}
.width('100%')                                     // 占满整行，锚点由 justifyContent 决定
.height(THREAD_LIST_SORT_BAR_HEIGHT)
// ★ 锚点分档：手机（单列）= 现状左对齐 + 左缘 24；平板（多列）= 整体居中
.justifyContent(this.threadColumns() > 1 ? FlexAlign.Center : FlexAlign.Start)
.padding({ left: this.threadColumns() > 1 ? 0 : 24 })
.margin({ bottom: THREAD_LIST_SORT_BAR_BOTTOM })   // 底距 30
.zIndex(20)
```

- **组合净宽**：`244 + 12 + 80 = 336vp`（手机档外再各留 24 → 360 恰好占满）；**平板档整体居中**，左右各留白 `(屏宽 − 336) / 2`，**不再拉伸、不再分居两端**；
- **手机档等价性**：`justifyContent(Start)` + `padding left 24` = 现状逐像素（左 24 | 底栏 | 12 | 加号壳 80 = 360 占满）；
- `sortBarWidth()` 可**简化为直接返回固定值**（保留原上下限逻辑亦可，多列档上限已生效）；
- `searchMode` 下底栏不渲染（原 `if (... && !this.searchMode)` 条件移到整个 `BottomGroupShell` 调用点，或保留底栏段的条件）；
- **坑30 复核**：两个空壳仍各自收窄（244 / 80 而非 `'100%'`），`hitTestBehavior(None)` 保留 → 不吞噬下层列表竖向滑动。
- **备选（更小改动）**：若不想动 `ThreadListContent` 的悬浮层挂载，也可保留两处独立调用，仅给 `FabSlotShell` 加 `position`/`offset` 把它从屏幕右缘平移到「底栏右侧」——但两处悬浮层的右锚点需各自换算，**可读性差于合并 `Row`**，故不推荐。

**涉及改动点**
- `ThreadList.ets`：T-B（新增 `pageHeight` / `isWideFormDevice` / `isLandscape` / `threadColumns()`，`aboutToAppear` 取首帧宽高，`onAreaChange` 同点取高，同步写 `cardColumns` 全局标记）、T-C（`threadRows()` / `threadBlankSlots()` + **置顶区分支** + 列表分支）、T-D（搜索结果分支）、**T-F（① 经验条 `constraintSize` 限宽 + 签到钮补 `Blank()`；② `sortBarWidth()` 加 244 上限；③ 新增 `BottomGroupShell()` 把底栏 + 缝 + FAB 合并为整体居左 `Row`，替换原两处独立悬浮层调用）**。**T-A 无代码改动。**
- `components/Skeleton.ets`：T-E（`ThreadListSkeleton` 增 `columns` 入参 + 行分组）。
- `components/CommonComponents.ets`：卡片几何比例化按 §4.2 决策 6 走 `@StorageProp('cardColumns')` 分支（**属 §4.2 的执行项**，本页只是消费方 → 不重复计改动）。
- `common/Theme.ets`：形态判据 / 断点令牌（与 §4.6 H-B 同一落点，**尚未落地**，见下）。
- 文档：§三 第 8 项状态、§6.1 范围提醒与 A2 / C2 表项、§6.2 「二级页也要过」与已过检记录。

**前置依赖：已全部解除（2026-09-13）**

| 本节使用点 | 依赖 | 现状 |
|---|---|---|
| `threadColumns()` 的断点阈值 / `isWideFormDevice` | §4.6 H-B 全局判据收口（`Breakpoint` / `Theme.ets`） | ✅ **已落地**（`Theme.ets` 的 `Breakpoint.sm = 600` / `md = 840`） |
| 列数下发 `cardColumns` | §4.2 决策 6 的全局只读标记（`CARD_COLUMNS_KEY`） | ✅ **已落地**（`HomeTab` 决策 12 已在用） |

- **禁止绕法**：在本页内联 `600` / 自造 `isLandscape` 判据。§4.6 H-B 已升格为「全局判据唯一收口点」（§4.2 决策 7），本页必须引用 `Breakpoint.sm`。
- **口径一致性**：本节采用与首页 §4.2 决策 12 同款——`isWideFormDevice && pageWidth ≥ Breakpoint.sm` + `pageWidth > pageHeight` 判横竖屏，列数 **竖 3 / 横 4**。
- **本节状态**：**已落地 + 构建通过**（2026-09-13，用户拍板全部 5 项后开工；改动清单见本节末尾「状态」）。

**断点 / 阈值**
- 多列档：`isWideFormDevice && pageWidth ≥ Breakpoint.sm(600)`（与 §4.2 决策 12 同款；令牌已落地）
- 横竖屏：`pageWidth > pageHeight`
- 列数：**1 / 3 / 4**（手机 1；平板竖 3 / 横 4，跟首页一致）
- 列间距 = 行间距 = **6**（现状 `Column({ space: 6 })`，不动）；帖子区左右 `padding` = **12**（现状，不动）
- **不引入** `Content.maxWidth`（本页内容保持贴屏 12）
- **T-F 限宽常量（多列档专用）**：`THREAD_LIST_EXP_BAR_MAX_WIDTH ≈ 220`（经验条）、`THREAD_LIST_SORT_BAR_MAX_WIDTH = 244`（排序底栏）；两者**手机档不生效**（取大值 / 不触发上限）
- **T-F-③ 底部组合（选 B + 居中）**：净宽 `244 + 12 + 80 = 336vp`，底距 30 → **多列档整体居中**（左右各留 `(屏宽 − 336) / 2`）；**单列档左对齐 + 左缘 24**，即现状「左 24 | 底栏 244 | 缝 12 | 加号壳 80」恰好占满 360vp

**风险与回归项**
1. **末行不满被拉伸**（A2 类）：不补空位时最后一张卡会占满整行、与上方列宽错位 → 必须 `threadBlankSlots()`；**列表态与搜索态都要补**。
2. **行内不等高留白**：`Row` 高由最高卡决定 → 用 §4.2 决策 6 的卡片比例化（摘要 `maxLines` 收敛 + 单图 `height(220)` 改比例）在多列档收敛差异；**单列档必须逐像素保持现状**。
3. **滚动 / 预加载测量不受影响**：`contentH` 由列表内容 `Column` 的 `onAreaChange` 回填（`2106` / `1840`），行分组后仍是同一层；`remaining` 判据（`1812`）与 `onReachEnd` 兜底（`2120`）不变。
4. **排序切换快照不受影响**：`captureExitSnapshot` 按 `THREAD_SCROLL_SNAPSHOT_ID` 取 `Scroll` 矩形、用 `headerBlockH` 裁吧头（`1385-1405`），只依赖容器与吧头高度，与内部是否多列无关。
5. **骨架屏跳变**（T-E）：不做则 Loading → Success 时有「单列 → 多列」一次跳变。
6. **悬浮层让位**：底部排序槽位壳（56 + 底距 30 → 顶 86）与 FAB（56，下 36）已被 `contentBottomSpace()` 的 98 / 104 覆盖，搜索态 150 不变；**横屏矮视口（~640vp）下需复核**（既有项，本次不改变让位值）。
7. **手机零回归**：`threadColumns() <= 1` 分支保留原 `ForEach`（一行不改）→ 360vp 下逐像素不变。
8. **列数变化后的滚动位置**：见 §4.6 H-G-2（确定性推定采纳），降级为落地后复测项；本页在 `Scroll` 内，与 §4.7 同结论。

**风险自检（§6.2）**
- A 错位 → **有 3 处**（均为同一类，末行补空位）：多列末行不满时最后一张卡被 `layoutWeight(1)` 拉伸、列宽与上方不一致（A2 类）→ 规避：`threadBlankSlots(row.length, cols)` 补等宽空位，**置顶区（`pin_gap_`）/ 列表态 / 搜索态各一处**。另：**不引入** `Content.maxWidth`、不放大左右留白 → 无 A4 类；顶栏双路径几何本次不动 → 无 A3 类；首帧列数由 `aboutToAppear` 同步取宽高 → 无 A5 类。
- B 出屏 → **无**：列宽 `layoutWeight(1)` 均分、卡片 `width('100%')`、无横向滚动路径；`expandSafeArea` 只扩上 / 下不扩左右。
- C 重叠 → **无**（C2 已单独确认）：本页无定高卡（`ThreadCard` 高度自适应、`PinnedThreadItem` 单行）→ 无 B4 / B6 类文本溢出；4 列在 1280 屏下单列宽 ≈ 309vp、卡片内容宽 ≈ 277vp，**仍宽于手机单列 296vp 的内容可用宽** → 无窄列挤压；置顶条目标题 `maxLines(1)` + `textOverflow(Ellipsis)`，4 列下会更早省略但**不溢出**（观感提示，非缺陷）。C2 悬浮层让位见风险 6（既有项，已被 `contentBottomSpace()` 覆盖，横屏矮视口列为回归项）。
- **T-F 增补（2026-09-13 三项不拉伸 + FAB 锚点选 B + 整体居中）**：**A 错位 → 新增 1 处、已加护栏**：经验条 `constraintSize({ maxWidth })` 限宽后签到钮左移、不再贴信息列右缘 → 规避：经验条列与签到钮之间补 `Blank()`（或外层 `Row` 改 `SpaceBetween`），**签到钮仍钉信息列右缘**；**B 出屏 → 无**（限宽只收窄、不越界；组合净宽 336vp 居中，远小于平板宽）；**C 重叠 → 无**（选 B 后底栏与 FAB **同处一个 `Row`**、缝固定 12，不再出现「两处独立悬浮层各自锚点」的错位面；两个空壳仍各自收窄 + `hitTestBehavior(None)`，不吞下层滑动）；**D 手机回归 → 无（关键点：居中必须条件化）**——`justifyContent` / `padding.left` 按 `threadColumns()` 分档，单列档走 `Start` + `left 24`，与现状「左 24 | 底栏 244 | 缝 12 | 加号壳 80 = 360」逐像素等价；`THREAD_LIST_EXP_BAR_MAX_WIDTH` / `THREAD_LIST_SORT_BAR_MAX_WIDTH` 手机档取大值 / 不触发（`sortBarWidth()` 手机 360vp 下本就 ≈ 244）。**若无条件居中，手机左缘会由 24 变 12、右侧空 12 → 破坏零回归。**

**手机端零回归核对（2026-09-13 确认 → 结论：不影响）**

核对口径：手机 = `isWideFormDevice === false`（含窄窗 / 手机分屏 / 手机横屏）；逐个改动项对照「手机实际走到的路径」。

| 改动项 | 手机实际路径 | 是否改变几何 |
|---|---|---|
| T-A 吧头区 | **零代码改动** | 否 |
| T-B 新增 `pageHeight` / `isLandscape` / `isWideFormDevice` | 只是新增状态与 `aboutToAppear` / `onAreaChange` 读数；`threadColumns()` **首行** `if (!this.isWideFormDevice) return 1` 直接命中 → 恒 1 列（**手机横屏也是 1 列**，与 §4.2 / §4.4 列数映射表一致） | 否（仅多一次状态写入） |
| T-B `cardColumns` 写入 | 手机恒写 **1** → `ThreadCard` 内 `cardColumns > 1` 为 false → 单图 `height(220)`、摘要 `maxLines(4)`、多图格 140 / 100 全走现状 | 否 |
| T-C 列表分支 | `threadColumns() <= 1` → 走**原 `ForEach`**，行分组代码在 `else` 分支**根本不执行** | 否 |
| T-D 搜索态分支 | 同 C，原逻辑 | 否 |
| T-E 骨架屏 | `columns` 默认 1 → 走原 `Column({ space: Spacing.md })` 单列堆叠 | 否 |
| 间距 / 边距 | `Column({ space: 6 })`、左右 `padding 12`、吧头 `padding`、`contentBottomSpace()`（98 / 104 / 150）一律不动 | 否 |
| 悬浮层 | 顶栏双路径、FAB、底部排序槽位壳几何不动 | 否 |

**零回归依赖三条硬约束，缺一即破（落地时须写进代码注释）**：

1. **单列档也必须写 `cardColumns = 1`**，不允许「只在多列时写」。详见 T-B 的「写入纪律」——`AppStorage` 全局单值 + 4 处调用点共享，必然触发场景是**折叠屏展开(2) → 折叠(应回 1)**。
2. **列数 = 1 时禁止套行分组容器**：不能写成「统一 `Row > Column().layoutWeight(1)`，只是 1 列时只有一项」——那会把卡片宽度来源从 `width('100%')` 换成 `layoutWeight` 均分，违反「单列逐像素不变」口径（§4.2 决策 6 的生效范围硬约束同款）。必须显式 `if (columns <= 1) { 原 ForEach } else { 行分组 }` —— **T-C / T-D / T-E 三处都要照此写**。
3. **`ThreadListSkeleton` 的 `columns` 默认值 = 1**，且列 = 1 走原分支：该组件 5 处调用点里 `UserProfile` 两处属**不做多列的二级页**，必须保持单列（清单见 T-E）。

**手机验收基线**（与改动前逐像素比对）：帖子区单列布局、单图 220 高、摘要 4 行、多图 140 / 100 格高、**置顶区仍是「整体卡 + 单列条目」**（置顶入网格只在多列档生效）、吧头几何、骨架屏 4 张单列、底部让位 98 / 104 / 150 —— **全部不变**。

**已拍板点（2026-09-13 用户确认）**

| # | 点 | 结论 | 说明 |
|---|---|---|---|
| 1 | 置顶区：整块通栏卡 vs 逐张入网格 | **逐张入网格**（用户拍板） | 「置顶」标签行仍通栏；`PinnedThreadItem` 包 `Column().layoutWeight(1)` + 独立 `bgCard`/`borderRadius(26)` 入行分组；末行 `threadBlankSlots()` 补空位（键前缀 `pin_gap_`） |
| 2 | 骨架屏是否同步按列数铺 | **做**（T-E） | 成本 ≈ 一个 `columns` 入参（已落地）+ 调用点传参；不做则 Loading → Success 有一次肉眼可见跳变 |
| 3 | 列数口径 | **跟首页一致：竖 3 / 横 4**（用户拍板） | 两个 feed 用同一个 `ThreadCard`，口径不一致会让同卡在两处大小不同 |
| 4 | 吧头经验条 / 底栏 / FAB 的拉伸 | **三项均不拉伸**（用户拍板） | 见 T-F：经验条 `constraintSize` 限宽、底栏 `sortBarWidth()` 加 244 上限、FAB 几何本身固定 |
| 5 | **T-F 的 FAB 位置锚点** | **选项 B + 整体居中**（用户 2026-09-13 拍板「按 B」后追加「不能居中对齐吗」） | 底栏 + 缝 12 + FAB 合成单个 `Row`（净宽 336vp）；**多列档整体居中、单列档保持现状左对齐 + 左缘 24**（手机 360 恰好占满，**不可无条件居中**，否则手机左移 12vp）；替代现状两处独立悬浮层 |

**状态**：**已落地 + 构建通过（2026-09-13）**。用户确认全部 5 项后开工，实际改动：
- **T-B**：`ThreadList.ets` 新增 `isWideFormDevice` / `pageWidth` / `pageHeight` / `isLandscape` + `threadColumns()` / `syncCardColumns()` / `onListFormAreaChange()`；`aboutToAppear` 用 `display.getDefaultDisplaySync()` 取首帧宽高；根 `Stack.onAreaChange`（原只回填 `currentWidth`）同点挂形态变化；**删除原硬编码 `AppStorage.setOrCreate('cardColumns', 1)`**，改为无条件写 `threadColumns()`。
- **T-C**：新增 `threadRows()` / `threadBlankSlots()`；置顶区（标签行仍通栏）+ 普通帖区**各自** `if (threadColumns() > 1) { 行分组 + 末行补空位 } else { 原 ForEach }`。
- **T-D**：搜索态 `SearchResultsBuilder()` 同款行分组（键前缀 `search_row_` / `search_gap_`）。
- **T-E**：`ThreadListSkeleton({ count: 4, columns: this.threadColumns() })`。
- **T-F**：经验条列 `.constraintSize({ maxWidth: threadColumns() > 1 ? 220 : 99999 })` + 签到钮前补 `Blank()`；`sortBarWidth()` 加 `Math.min(w, 244)` 上限；**新增 `BottomGroupShell()`**（底栏 244 + 缝 12 + FAB 80 = 净 336vp，`justifyContent` / `padding.left` 按列数分档：手机左对齐 + 左缘 24 = 现状 / 平板居中），非搜索态下替换原 `FabSlotShell() + SortSlotShell()` 两处独立调用（`SortSlotShell()` 保留给兜底路径）。
- 新增常量 `THREAD_LIST_SORT_BAR_MAX_WIDTH = 244` / `THREAD_LIST_EXP_BAR_MAX_WIDTH = 220`。

`tools/build.ps1` → **BUILD SUCCESSFUL**（1m01s）；**待真机验收**（竖 3 / 横 4 切换 + 置顶网格 + 搜索态多列 + 经验条/底栏/FAB 三项不拉伸与居中 + 手机单列逐像素回归）。

**T-G（2026-09-13 追加）：多列档改为 `WaterFlow` 瀑布流（与首页 §4.2 决策 12 对齐）**

**起因（用户真机反馈）**：T-C 的行分组方案在多列档下仍不理想 —— 置顶卡被拉伸、行内留白、卡片内部空白大。用户要求「采用跟首页一样的瀑布流方案」，并明确「**置顶卡片不要拉伸，作为瀑布流第一个卡片格子就行**」。

**改动（`ThreadList.ets`）**：
- 新增 `ThreadListDataSource`（实现 `IDataSource`）+ `@State listDataSource`；`waterFlowThreads()` 把「置顶 + 普通帖」合并为一个列表（置顶在前；`sort=2`「精选」不分置顶、直接全量）；`syncListDataSource()` 在 `onThreadsChanged()`（`threads` 的 `@Watch`）里调用，**空列表也同步**（清空场景）。
- **滚动容器分档**（`ThreadListContent`）：
  - **多列档**（`threadColumns() > 1 && !searchMode`）：`WaterFlow({ scroller: this.listScroller, sections: this.sections })` + 静态 `FlowItem`（吧头）+ `LazyForEach(this.listDataSource)`（帖子）；用 `WaterFlowSections` 分段 —— **section 0 = 吧头（`crossCount: 1` → 独占整行）、section 1 = 主体（`crossCount: 3/4` → 多列帖子；加载/空/错误态退化为 1 列占满整行）**，section 1 带 `margin: { left:12, right:12 }` 提供左右边距；`columnsGap/rowsGap = Spacing.md` + `padding({ bottom: contentBottomSpace() })`；沿用 `.id(THREAD_SCROLL_SNAPSHOT_ID)` / `.onScroll` / `.onReachEnd` / `.onAreaChange`(viewport) / `.overlay(BottomFadeOverlay)` / `.edgeEffect(Spring)` / `.expandSafeArea`。**注意 `sections` 是 `WaterFlowOptions` 的构造参数（不是链式属性，链式会报 `Property 'sections' does not exist`）**。
  - **单列档 + 搜索态**：保持原 `Scroll` + `Column` 结构**逐像素不变**（用 `if` 分档包裹，原代码未改）。
- **置顶卡 = 瀑布流的普通格子**：`FlowItem` 内 `item.isTop === true && selectedSort !== 2` → `PinnedThreadItem`（包 `Column` + `bgCard` + `borderRadius(26)`，自然高度、**不拉伸**），其余 → `ThreadCard`；**取消「置顶」通栏标签行与整块通栏卡**。
- 多列档不再显示「上拉加载更多」行（对齐首页），由 `onReachEnd` 兜底静默续载。

**已知取舍（须记住）**：
1. **吧头区通过 `WaterFlowSections` 跨列、随内容滚动**（用户 2026-09-13 追加要求「吧头不要固定在顶部，随内容流动」）：section 0 设 `crossCount: 1` 独占整行，与帖子同处一个 `WaterFlow`、共享 `listScroller`（旧的「吧头固定于容器外」写法已废弃）。**代价 = `sections` 各段 `itemsCount` 累计和必须严格等于 `WaterFlow` 子节点数**（官方硬约束，否则无法滚动）→ 故 `syncSections()` 挂在「数据源变化（`onThreadsChanged` → `syncListDataSource`）/ 列数变化（`onListFormAreaChange`）/ 加载态变化（`onLoadStateChanged`）」三处，且成功态空数据时补 1 个 0 高占位；**待真机验证静态 `FlowItem`（吧头）与 `LazyForEach`（帖子）混用是否稳定**（官方示例均为纯 `LazyForEach`）。
2. **`contentH` 预加载判据在多列档不生效**（`WaterFlow` 虚拟滚动无「内容高」概念）：多列档靠 `onReachEnd` 兜底续载。
3. **搜索态仍用行分组**（未同步改 `WaterFlow`）：`SearchResultsBuilder()` 位于 `Scroll` 内，改动面更大，暂保留 T-D。
4. T-C 的行分组代码仍保留在**单列档/搜索态**分支内（多列档已由 T-G 接管）。

**T-G 转场适配（2026-09-13 追加）**：用户真机反馈平板下「最新 / 热门 / 精选」切换**闪一下直接过去 + 一瞬间画面重叠**；随后追加要求「**转场时吧头不要跟着切换**」。根因 = 多列档换 `WaterFlow` 时漏了排序过场的配套（单列档那套挂在「列表区 Stack」上，多列档无对应挂点）：

| # | 问题 | 修复 |
|---|---|---|
| ① | **新页没有位移**：单列档的 `.translate({ x: inOffset% })` 挂在「列表区 Stack」这一层，多列档换 `WaterFlow` 后没有对应挂点 → 旧页快照照常滑出、新页不动 = 「闪一下直接过去」+ 与旧页快照重叠 | 多列档 `WaterFlow` 补 `.translate({ x: this.inOffset% })`（位移挂**整页**，吧头由 ④ 反向抵消） |
| ② | **旧页快照会带着吧头滑出**：吧头在 `WaterFlow` 之内，快照不裁吧头则旧页滑出时吧头跟着滑、与静止的新页吧头重叠 | `captureExitSnapshot()` 裁剪逻辑**单列 / 多列同款**（`clipTop = 90 + headerBlockH − scrollY`）；多列档之所以能裁，是因为 ④ 已让吧头静止 |
| ③ | **骨架屏缺淡入**：多列档骨架屏是 `WaterFlow` 内的 `FlowItem`，漏了 `skeletonOpacity` → 切到未命中缓存的排序时骨架屏瞬显 | 补 `.opacity(this.skeletonOpacity)` |
| ④ | **吧头跟着切**（用户 2026-09-13 追加要求）：多列档吧头在 `WaterFlow` 之内，整页位移必然带着它一起滑 | **位移不挂容器，改为逐张帖子卡片位移**（`.translate({ x: this.sortShiftX() })`；`sortShiftX()` 把 `inOffset` 的 ±100 百分比语义按根容器实测宽换算成 vp，避免多列下卡片宽仅 1/3 屏导致位移不足）→ `WaterFlow` 与吧头**完全静止** |
| ⑤ | **吧头被遮挡后再出现**（用户 2026-09-13 追加反馈）：④ 的首版解法是「容器整页位移 + 吧头等量反向位移」，但 `WaterFlow` 是**虚拟滚动容器、自带渲染区**，反向位移后的吧头落在该区之外 → 被裁掉，直到动画收口 `inOffset` 归零才重新出现 | 由 ④ 的「只位移卡片」方案从根上消除。**经验沉淀：不要在 `WaterFlow` 内用「单个 `FlowItem` 反向位移」对抗容器位移（虚拟容器会裁掉它）** |

**同批修掉的两个数据侧缺陷（非转场，但同源）**：
- **`syncListDataSource()` 追加判定错误**：原先只比长度（`newLen > oldLen && oldLen > 0`）→ 切排序 / 刷新后列表变长会被误判成「尾部追加」，`notifyAdd` 只重建尾段、**前段仍渲染旧排序的内容**。改为**逐项比对前缀 tid**，前缀不一致即全量 `reload()`。**`HomeTab` 的 `onThreadsChange` / `onFolThreadsChange` 同源缺陷一并修正**（抽出 `syncSource()` 统一判定）。
- **`syncSections()` 重复触发**：切排序时经「数据源同步」与「加载态回调」被调两次 → 同帧重复 `splice` 触发 `WaterFlow` 重排（过场中一顿 / 闪）。加 `lastSectionKey`（`主体项数_主体列数`）去重。

**T-H（2026-09-13 追加）：吧主页「更多」弹窗几何统一**

**起因（用户真机反馈）**：平板下弹窗被拉成通栏（`dialogCardWidth()` = 屏幕宽 − 48 ≈ 900+vp），且纵向位置与全站其余弹窗不一致，用户要求「弹窗不要拉伸，调到跟首页置顶弹窗一个高度位置（手机模式也一样调位）」。

**改动（`ThreadList.ets`）**：
- **宽度封顶**：`dialogCardWidth()` 由 `max(200, 屏幕宽 − 48)` 改为 `max(200, min(400, 屏幕宽 − 48))`，新增常量 `THREAD_LIST_DIALOG_MAX_WIDTH = 400`（系统弹窗默认宽度上限）。手机档 `360 − 48 = 312 < 400`，**逐像素不变**。
- **纵向锚点对齐**：`moreSheetController` 的 `offset.dy` 由 **-30**（改造前自绘浮层的 margin bottom 30 悬浮基线）改为 **-110**，与收藏页、进吧页的置顶弹窗**完全一致**；手机档同样生效（用户明确「手机模式也一样调位」）。

**全站弹窗锚点盘点**：`Favorite` 六处（置顶 / 批量删除 / 删分类 / 分类管理 / 备份 / 导出）、`ForumsTab` 两处（一键签到 / 置顶菜单）= **-110**；`ThreadDetail` 一处 = **-140**（有专属理由，见其注释，**勿动**）；`ThreadList` 本处原为 **-30** → 现统一 **-110**。

**遗留提醒**：其余页面的 `dialogCardWidth()` 仍是「屏幕宽 − 48」（未封顶），平板下同样偏宽；本轮按用户要求只动吧主页，如需全局统一可再开一轮。

**T-I（2026-09-13 追加后当日回退）：吧头多列档居中**

**起因（用户要求）**：平板下吧头铺满整宽、头像贴左缘、签到钮被拉到屏幕右端，观感拉散；要求「吧头改成居中对齐」。

**落地**：`ForumHeaderBuilder` 外层 `Row` 加 `.constraintSize({ maxWidth: this.threadColumns() > 1 ? THREAD_LIST_HEADER_MAX_WIDTH : 99999 })`（常量 480）。居中之所以只加一行即可成立：父层是 `Column`（`.width('100%')`），交叉轴默认 `HorizontalAlign.Center`，内容块限宽后**自动被父层居中**，无需改嵌套 / 加 `justifyContent`。

**同日回退（用户拍板「还是回退到左对齐吧」）**：已移除该 `constraintSize` 与常量 `THREAD_LIST_HEADER_MAX_WIDTH`，吧头恢复**左对齐铺满**（改造前观感），手机 / 平板一致。

**经验留存**：吧头居中的技术路径已被验证可行（父层 `Column` 交叉轴默认居中 → 只需限宽），将来若要重做可直接复用，不必改嵌套结构。

`tools/build.ps1` → **BUILD SUCCESSFUL**（1m02s，转场修复后 57s / 1m09s ×4）；**待真机验收**（瀑布流紧凑性 + 置顶卡作普通格子且不拉伸 + **吧头随内容滚动** + `itemsCount` 一致性〔能否正常滚动 / 触底续载〕+ **三排序左右切换是否顺滑无重叠** + 切排序后列表内容是否正确 + 横竖屏切换后列数正确 + **弹窗宽度不拉伸且纵向位置与收藏页 / 进吧页一致** + 手机单列逐像素回归）。

<!-- 每个界面的方案按以下模板追加：

### N. 界面名称（`pages/XXX.ets`）

- 适配需求：
- 设计方案：
- 涉及改动点：
- 断点 / 阈值：
- 风险与回归项：
- **风险自检（§6.2，强制）**：A 错位 → 无 / 有（位置 + 规避）；B 出屏 → 无 / 有（位置 + 规避）；C 重叠 → 无 / 有（位置 + 规避）
- 状态：待确认 / 已确认
-->

### 4.9 帖子详情（`pages/ThreadDetail.ets`）

**适配需求（用户原话，2026-09-13）**
- **竖屏**：帖子（主楼）内容**正常拉伸**；其下**回复区两列**；但**不要**出现「两列高度不一致」（即行分组那种行内对齐留白）→ 问**能否跟首页（§4.2）一致方案**
- **横屏**：**分两个区域** —— 帖子**固定左边**，回复区在**右边作为两列**
- 手机端保持现状不变

**二次拍板（2026-09-13 同日，用户原话；本页仍未开工）**
- **竖屏**：帖子内容**不动**；**宫格图片不要拉伸和放大**、**宫格图左对齐**；回复区改用**首页 `WaterFlow` 瀑布流**、显示**三列**。
- **横屏**：仍左右分区 —— 帖子在左、回复区在右；回复区**三列**、同样瀑布流；**帖子区域宽度与「帖子本身宽度」一致**（不再按 4 : 6 比例拉伸左栏）。
- 手机端保持现状不变。

> **对上述一次方案的影响**：一次方案的「**手写双列**」与「**4 : 6 分栏比例**」**已被本次拍板取代**；其余仍然有效 —— DT-A（形态判据）、DT-C（通栏项位置）、DT-E（沉浸四项同层同迁）、DT-F（骨架 / 错误态）。变更与新增见下方 **DT-G ~ DT-J**（其中 DT-B 的「竖屏分列写法」与 DT-D 的「4 : 6」作废，其余结论沿用）。

**DT-G 回复区改用 `WaterFlow`（三列）+ `sections` 跨列**（取代一次方案 DT-B 的「手写双列」）

与 §4.8 吧内页同款写法：用 `WaterFlowSections` 让通栏项跨列、楼层走多列瀑布流。**竖屏 = 整页一个 `WaterFlow`**：

```ts
WaterFlow({ scroller: this.scroller, sections: this.sections }) {
  FlowItem() {                                   // 段 0：crossCount 1（全宽）
    Column({ space: Spacing.md }) {
      Column().width('100%').height(98)          // 顶栏让位（通栏）
      this.PostHeader()                          // 主楼（内容不动）
      this.ReplySectionHeader()                  // 回复表头（通栏）
    }.width('100%')
  }
  ForEach(this.floors, (floor: FloorItem) => {   // 段 1：crossCount 3（三列瀑布流）
    FlowItem() {
      Column() { this.FloorCard(floor) }
        .id('floor_' + floor.floorId)            // 定位锚点必须随卡入列
        .width('100%')
        .backgroundColor(高亮底)
        .borderRadius(高亮 ? 26 : 0)
        .clip(true)
    }
  }, (floor: FloorItem) => `${floor.floorId}_${floor.floor}`)
  FlowItem() { /* 段 2：crossCount 1 —— 触底哨兵，必须恒渲染 */ }
}
.columnsGap(Spacing.md)
.rowsGap(Spacing.md)
.padding({ left: Spacing.lg, right: Spacing.lg, top: 0, bottom: 160 })
// 其余属性原样保留：id('thread_scroll_content') / scrollBar(Off) / clip(false) /
// expandSafeArea(TOP,BOTTOM) / onReachEnd / overlay(TopFadeBand) / blendMode / backgroundColor / opacity
```

`sections` 同步（挂在「楼层数据变化」与「形态变化」两处）：

```ts
private syncSections(): void {
  const next: SectionOptions[] = [
    { itemsCount: 1, crossCount: 1 },                                        // 段 0：通栏（让位 + 主楼 + 回复表头）
    { itemsCount: Math.max(this.floors.length, 1), crossCount: this.replyColumns() },  // 段 1：楼层三列
    { itemsCount: 1, crossCount: 1 },                                        // 段 2：哨兵
  ];
  this.sections.splice(0, this.sections.length(), next);
}
```

**硬约束（§4.8 T-G 实战踩过，逐条照做）**：

1. 各段 `itemsCount` 累计和**必须严格等于** `WaterFlow` 子节点数 → **触底哨兵必须恒渲染**（把「加载更多 / 正在加载 / 已经到底啦」收进同一个 `FlowItem`，不能让它被条件渲染时有时无），否则数量不匹配会让组件**完全无法滚动**；
2. `sections` 是 **`WaterFlowOptions` 的构造参数**：`WaterFlow({ scroller, sections })`；写成链式 `.sections()` 会报 `Property 'sections' does not exist on type 'WaterFlowAttribute'`；
3. **不设** `onGetItemMainSizeByIndex`（楼层卡高度自适应，由 `FlowItem` 决定）；
4. 楼层本就是全量渲染 → 用 `ForEach` 即可（**不需要** `IDataSource` / `LazyForEach`），无虚拟化收益损失；
5. `itemsCount` 不得为 0 → 楼层为空时 `Math.max(n, 1)` 兜底，并同步让段 1 有且仅有 1 个子节点（补 0 高占位 `FlowItem`）。

**DT-H 楼层定位锚点**：`.id('floor_' + floor.floorId)` 与高亮底 / 圆角 26 / `clip(true)` **四项一起搬进 `FlowItem`**；`scrollToTargetFloor()` 的公式（`getRectangleById` 求差 + `scroller.scrollTo`）与 20 × 220ms 轮询**不动**。

**DT-I 横屏：左栏宽度 =「帖子本身宽度」**（取代一次方案 DT-D 的 4 : 6）

- 左栏由 `layoutWeight(4)` 改为**固定宽度** `DETAIL_MAIN_WIDTH`，右栏 `layoutWeight(1)` 吃掉剩余；
- 右栏 = `WaterFlow`（回复表头段跨列 + 楼层三列段 + 哨兵段），机制与 DT-G 完全相同；
- 左栏仍是独立 `Scroll(scrollerLeft)`（主楼可能很长），**不挂** `onReachEnd` / `overlay` / `id`；
- 两栏**各自** `padding bottom 160`；
- 外边界 16 + 内边界 8 = 接缝合计 16（与现状同观感）；
- **`DETAIL_MAIN_WIDTH` 取值 = 待拍板点 5**。

**DT-J 宫格图不拉伸 / 不放大 / 左对齐**（本次新增）

- **现状成因**：`ImageGrid()` 的 `Grid` 是 `.columnsTemplate('1fr 1fr 1fr')` + `.width('100%')` + **格高恒 120** —— 宽屏下三列被均分到 1000+vp（每格 ≈ 320vp）而高度仍 120 → **图片被横向拉伸 / 放大**；
- **改法**：给 `Grid` 加 `.constraintSize({ maxWidth: DETAIL_IMAGE_GRID_MAX_WIDTH })`；外层 `Column`（`PostHeader` / `FloorCard`）本就 `alignItems(HorizontalAlign.Start)` → **限宽后自动左对齐**，无需额外对齐属性；
- **手机零回归**：手机档宫格可用宽 ≈ 296vp < 上限 → `maxWidth` **不生效**，逐像素不变（**不需要**形态闸门）；
- **一改三处**：`ImageGrid` 被主楼（`2207`）、楼层（`2325`）、楼中楼（`2402`）共用，改一次三处生效（楼中楼同受益）；
- **`DETAIL_IMAGE_GRID_MAX_WIDTH` 取值 = 待拍板点 6**。

**选型结论：可以做，但「跟首页一致」一致的是观感，不是组件 —— 推 `手写双列（列内独立堆叠）` + 横屏 `左右分栏`；不换滚动容器、不引入 `WaterFlow`。**

用户问的「能否跟首页一致」拆成两层回答：

1. **用户感知的「一致」= 列内独立堆叠、无行内对齐空白**。首页（§4.2 选型 A `WaterFlow`）之所以没有留白，是因为每一列是**独立堆叠的**：某张卡变高只把**本列**后续内容往下推，另一列纹丝不动。行分组（`Row` 内 `layoutWeight(1)` 均分，即 §4.4 / §4.8 写法）做不到这点：一行的高度由**最高的那张卡**决定，矮卡下方必然留白 —— **这正是用户现在看到的「高度不一致」**。**（注：§4.2 首页已于 2026-09-13 因真机否决回退方案 B 行分组；此处「首页无留白」仅为方案 A 状态的历史论证。）**
2. **但详情页不该换 `WaterFlow`**，理由三条：
   - 首页能用它，前提是「整页 = 一个可以整体换掉的网格流」；详情页的楼层区被夹在 `Scroll` 内（上方还有**主楼**与**回复标题**两个通栏项），`WaterFlow` **无 `header` / 通栏能力**，装不下主楼（同 §4.8 不选 `WaterFlow` 的理由一）；
   - 详情页楼层是 `Scroll` + `ForEach` **全量渲染**（`1476`，无虚拟化，见 `103-104` 注释：楼层曾用 `List` 虚拟滚动，因沉浸视口剔除 bug 改全量）→ 换 `WaterFlow` **既无虚拟化收益、又要重挂** `overlay(TopFadeBand)` / `blendMode` / `expandSafeArea` / `onReachEnd` / `thread_scroll_content` 定位锚点 / `scroller` —— 代价与收益倒挂；
   - **结论：用「手写双列（两列各自 `Column` 独立堆叠）」就能拿到与首页同款的观感，一行滚动容器都不用动。** **（注：§4.2 首页已于同日改为方案 B 行分组，「跟首页一致」的口径随之变为「行内顶对齐 + 末行补空位」；§4.9 是否同步改行分组，留待该页开工前确认。）**

**改动前现状（已核实，2026-09-13）**

| 项 | 现值 | 位置 |
|---|---|---|
| 形态判定 | **无** `pageHeight` / `isLandscape` / `isWideFormDevice`；仅 `@State currentWidth = 360`（注释：壳分支悬浮岛宽度依赖的屏宽） | `504-505` |
| `currentWidth` 消费 | **仅** `dockPillWidth()`（`currentWidth − 64`，下限 240） | `1110` |
| 窗口高 | **无** | — |
| 判定挂点 | `DetailRoot()` 根 `Stack` 的 `.onAreaChange`，现在只回填 `currentWidth` | `1075-1080` |
| 首帧初值 | `aboutToAppear` **未**取真实窗口尺寸（`currentWidth` 恒以 360 起手） | `526-565` |
| 滚动容器 | 全页唯一 `Scroll(this.scroller)`，内容 `Column({ space: Spacing.md })`，其 id = `thread_scroll_content` | `1469-1470` / `1524` |
| 顶栏让位 | `Scroll` 首项 `Column().height(98)`（= `THREAD_DETAIL_TITLE_BAR_HEIGHT`） | `1472` / `64` |
| 主楼 | `PostHeader()`：`width('100%')` + `padding(Spacing.lg)` + `bgCard` + `borderRadius(26)` | `1473` / `2211-2217` |
| 回复表头 | `ReplySectionHeader()`：「回复 N 条」通栏行 | `1474` / `2220-2233` |
| 楼层区 | `ForEach(this.floors)` → `Column { FloorCard }`，逐层 `.id('floor_' + floorId)` + 高亮层（透明 / `26` 圆角） | `1476-1486` |
| 楼层卡 | `FloorCard()`：`width('100%')` + `padding(Spacing.lg)` + `bgCard` + `borderRadius(26)`，**高度自适应**（无定高） | `2237-2337` |
| 楼层号显示 | 卡头恒显 `· 第N楼` | `2281-2282` |
| 图片网格 | `ImageGrid()`：`Grid` + `columnsTemplate('1fr 1fr 1fr')` + **固定格高 120** + gap 6 | `2569-2598` |
| 触底哨兵 | 加载更多 / 到底提示，在楼层 `ForEach` 之后（同一 `Column` 内） | `1488-1521` |
| `Scroll` 属性 | `padding({ left: 16, right: 16, top: 0, bottom: 160 })` / `onReachEnd` / `edgeEffect(Spring)` / `clip(false)` / `expandSafeArea(TOP,BOTTOM)` / `overlay(TopFadeBand)` / `blendMode(SRC_OVER, OFFSCREEN)` / `backgroundColor` / `opacity(contentOpacity)` | `1526-1546` |
| 顶部渐隐带 | `TopFadeBand()` 高 88，`DST_IN` 遮罩，**挂在 `Scroll` 上** | `1314-1324` / `1543` |
| 骨架屏 / 错误态 | `ThreadDetailSkeleton()` / `ErrorView()`，与 `Scroll` 同级（`Stack` 内） | `1549-1556` |
| 楼层定位 | `scrollToTargetFloor()`：`getRectangleById('floor_xxx')` 与 `getRectangleById('thread_scroll_content')` 求差 + `this.scroller.scrollTo`；失败由 `scheduleScrollToTargetFloor()` 20×220ms 轮询重试 | `627-669` / `676-694` |
| 底部悬浮 | `ImmersiveDockShell()`（官方 Tabs 槽位，`barHeight 66`）/ `BottomDock()`；排序胶囊壳 `SortPillShell()`；`dockPillWidth()` 无上限 | `1143+` / `1571-1580` / `1054-1058` / `1110` |

> **关键前提（决定了本页方案比 §4.8 更轻）**：楼层区**已经是 `Scroll` + `ForEach` 全量渲染**（无虚拟化）→ 分列 / 分栏**不损失任何虚拟化收益**，也不涉及 `contentH` 测量、预加载判据、快照裁剪一类机制（本页本来就没有）。改动面只在 `ContentLayer()` 的模板层。

**DT-A 形态判定与列数（单一函数 + 单一挂点 + 首帧初值）**

复用既有 `currentWidth` 作**页宽**（已由 `onAreaChange` 回填，全页唯一页宽来源，符合「单一来源」），**新增** `pageHeight`：

```ts
import { deviceInfo } from '@kit.BasicServicesKit';
import { display } from '@kit.ArkUI';

@State pageHeight: number = 800;      // 新增（页宽沿用既有 currentWidth）

/** 大屏形态设备：平板 / 2in1 / 折叠屏（折叠屏 deviceType 为 'phone'，必须单独识别） */
private readonly isWideFormDevice: boolean =
  deviceInfo.deviceType === 'tablet'
  || deviceInfo.deviceType === '2in1'
  || display.isFoldable();

private isLandscape(): boolean {
  return this.currentWidth > this.pageHeight;   // 横竖屏用宽高比（同 §4.7 S-B / §4.8 T-B）
}

/** 回复区列数：手机恒 1；平板竖 2；平板横（分栏后）右栏内仍是 2 */
private replyColumns(): number {
  if (!this.isWideFormDevice) return 1;
  if (this.currentWidth < 600) return 1;        // 折叠态 / 分屏 / 自由多窗窄窗
  return 2;
}

/** 是否左右分栏（仅大屏横屏）：主楼独占左栏、回复独占右栏 */
private splitMode(): boolean {
  return this.isWideFormDevice && this.currentWidth >= 600 && this.isLandscape();
}
```

- **挂点**：`DetailRoot()` 的 `.onAreaChange`（`1075-1080`，现只写 `currentWidth`）同点追加 `pageHeight`。
- **首帧初值**：`aboutToAppear`（`526`）用 `display.getDefaultDisplaySync()` 同步取窗口宽高，写入 `currentWidth` / `pageHeight` —— 顺带修掉 §4.6 H-A 同源的「首帧窄屏初值」隐患（`currentWidth` 现恒以 `360` 起手，横屏冷启动首帧会被判成竖屏）。
- **不写 `cardColumns` 全局标记**：楼层卡高度自适应、无比例化几何需求 → 本页**不引入**该全局只读标记（少一处 D1 / D6 类残留风险；该标记只服务于需要比例化几何的卡片页，见 §4.2 决策 6）。

**DT-B 竖屏：主楼满宽（零改动）+ 回复区两列**

主楼与回复表头**一字不动**，仍是通栏兄弟节点；只把**楼层区**换成分列写法：

```ts
/** 交替分列：偶数列左、奇数列右（顺序观感与首页瀑布流一致） */
private replyColumnsData(items: FloorItem[]): FloorItem[][] {
  const cols: number = this.replyColumns();
  const buckets: FloorItem[][] = [];
  for (let c = 0; c < cols; c++) { buckets.push([]); }
  for (let i = 0; i < items.length; i++) { buckets[i % cols].push(items[i]); }
  return buckets;
}
```

```ts
if (this.replyColumns() <= 1) {
  // 现状分支：1476-1486 的 ForEach 一字不动（手机与窄窗走这里）
} else {
  Row({ space: Spacing.md }) {                       // 列间距 = 行间距 = Spacing.md（同源）
    ForEach(this.replyColumnsData(this.floors), (col: FloorItem[], colIdx: number) => {
      Column({ space: Spacing.md }) {                // 列内独立堆叠 → 无行内对齐空白
        ForEach(col, (floor: FloorItem) => {
          Column() { this.FloorCard(floor) }         // 含 .id('floor_'+floorId) 与高亮层，原样搬入
            .width('100%')
            // …高亮底 / 圆角 26 / clip(true) 三项与 1477-1485 完全一致
        }, (floor: FloorItem) => `${floor.floorId}_${floor.floor}`)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }, (col: FloorItem[], colIdx: number) => `col_${colIdx}_${col[0]?.floorId ?? 'e'}`)
  }
  .width('100%')
  .alignItems(VerticalAlign.Top)
}
```

- ⚠️ **`.id('floor_' + floorId)` 必须跟着卡一起进列**：楼层定位（`627-669`）靠它取几何，丢 id 即「消息跳转楼层」失效。
- ✅ **不存在「末行不满被拉伸」（A2 类）**：不是行分组，两列各自堆叠，无「行」概念 → 不需要 `xxxBlankSlots()` 一类补位逻辑。这是本方案相对 §4.4 / §4.8 的**简化点**。
- **列宽来源**：`Row` 内 `Column().layoutWeight(1)` → 均分可用宽，无像素列宽（§6.2 步 1）。

**DT-C 通栏项与触底哨兵位置（§6.2 第 3 步）**

| 通栏项（分列 `Row` 的兄弟节点，永不进列） | 位置 |
|---|---|
| 顶栏占位 `Column().height(98)` | `1472` |
| 主楼 `PostHeader()` | `1473` |
| 回复表头 `ReplySectionHeader()` | `1474` |
| 触底哨兵：加载更多 / 正在加载 / 到底提示 | `1488-1521` |
| `Scroll` 左右 `padding 16` 与底部 `padding 160` | `1530` |

即：**两列 `Row` 夹在回复表头与触底哨兵之间**，三项位置关系与现状完全一致（只是中间楼层区从单列变两列）。

**DT-D 横屏：左右分栏（左主楼固定、右回复两列）**

```text
Column                                  // 新增的外层容器：承载 bg / opacity / overlay（见 DT-E）
  ├ Column().height(98)                 // 顶栏让位，通栏（原 1472 上移到此层）
  ├ Row({ space: Spacing.md })          // 栏间距 = Spacing.md
  │   ├ Scroll(scrollerLeft).layoutWeight(4)      // 左：主楼（固定）
  │   │     Column({ space: Spacing.md }) { PostHeader() }
  │   │     padding({ left: 16, right: 8, bottom: 160 })
  │   └ Scroll(this.scroller).layoutWeight(6)     // 右：回复区
  │         Column({ space: Spacing.md }) {
  │           ReplySectionHeader()                 // 通栏
  │           Row { 左列 Column; 右列 Column }      // 同 DT-B 的 replyColumnsData()
  │           触底哨兵
  │         }
  │         id = 'thread_scroll_content'           // 定位锚点保留在右栏
  │         padding({ left: 8, right: 16, bottom: 160 })
  │   ↑ 共用的 16 外边界 + 8 内边界 = 16（中间接缝合计 16，与现状左右 16 同观感）
  └ （overlay(TopFadeBand) 挂最外层 Column，满宽 88）
```

- **宽度分配走 `layoutWeight(4 : 6)`（非像素）**，核算：

| 形态 | 窗口宽 | 左栏 | 右栏 | 右栏单列宽 | 单列内容宽 | 左栏图片格（3 列） |
|---|---|---|---|---|---|---|
| 平板横 1024 | 1024 | ≈ 390 | ≈ 585 | ≈ 286 | ≈ 254 | ≈ 116 |
| 平板横 1280 | 1280 | ≈ 492 | ≈ 738 | ≈ 363 | ≈ 331 | ≈ 149 |
| 对照：手机竖基线 | 360 | — | — | 296 | 264 | 88 |

- **左栏滚动独立**（新增 `scrollerLeft: Scroller`），不挂 `onReachEnd` / 不挂 overlay / 不给 id —— 主楼不参与分页与定位。
- **右栏保留全部机制**：`this.scroller` + `id('thread_scroll_content')` + `onReachEnd` + `padding bottom 160` → **楼层定位公式（`645-648`）零改动**（它只依赖「目标层与内容容器同一滚动容器内的相对位移」，右栏自洽），分页与沉浸滚动同理。
- 左右两栏**各自** `padding bottom 160`，保证底部悬浮 Dock 不压内容（C1 / C2）。
- `splitMode()` 为 false 时（竖屏 / 窄窗 / 手机）走 DT-B 的单 `Scroll` 结构 —— **手机横屏也走单 Scroll**（`isWideFormDevice` 形态闸门），与用户「手机保持现状」一致。

**DT-E 沉浸层归属：`overlay` / `blendMode` / `backgroundColor` / `opacity` 必须整体上移**

- 现状四项全挂在 `Scroll` 上（`1543-1546`）。分栏后它只作用于右栏 → 左栏无底色、渐隐带只盖右栏。
- 写法：把 `backgroundColor` / `opacity(contentOpacity)` / `overlay(TopFadeBand)` / `blendMode(SRC_OVER, OFFSCREEN)` **整体搬**到最外层承载容器（横屏 = 外层 `Column`；竖屏 = 仍是 `Scroll` 本身，**挂点不变 → 手机与平板竖屏零风险**）。
- ⚠️ **四项必须同层同迁**：`overlay` 的 `DST_IN` 遮罩与 `Scroll` 的 `SRC_OVER + OFFSCREEN` 是**同一渲染层配对**，只搬 overlay 会让 `blendMode` 作用域错位（遮罩失效或整层被抠空）→ 落地后**必须真机复验顶部渐隐带**（风险 1）。

**DT-F 加载 / 骨架 / 错误态**

- `ThreadDetailSkeleton()`（`1550`）与 `ErrorView()`（`1555`）是 `Stack` 内与滚动层同级的 `layoutWeight(1)` 覆盖层 → 分栏后位置不变，**零改动**。
- 骨架屏**不按列铺**（默认，见 §4.9 待拍板点 2，**已拍板「不做」**）：`ThreadDetailSkeleton` 是独立组件、Loading 期短；若做，须加 `columns: number = 1` 入参且列 = 1 走原分支（严守 §4.8 T-E 的同款纪律）。

**涉及改动点**
- `ThreadDetail.ets`：DT-A（新增 `pageHeight` / `isWideFormDevice` / `isLandscape()` / `replyColumns()` / `splitMode()`，`aboutToAppear` 取首帧宽高，`onAreaChange` 同点取高）、DT-B（`replyColumnsData()` + 回复区分支，含 `.id` 随卡入列）、DT-C（哨兵仍为通栏兄弟）、DT-D（`splitMode()` 下的双栏结构 + `scrollerLeft`）、DT-E（四项沉浸属性上移）。
- **不改**：`PostHeader()` / `FloorCard()` / `CommentList()` / `ImageGrid()` / `ReplySectionHeader()` 的内部几何；官方 `Navigation` title 槽位与 `ImmersiveDockShell()` 官方 Tabs 槽位；`SortPillShell()` / `BottomDock()` / `ReplyControls()`；全部取数、缓存、点赞、收藏、楼中楼逻辑。
- **不引入 `cardColumns`**（见 DT-A 末条）。
- `common/Theme.ets`：形态判据 / 断点令牌（与 §4.6 H-B 同一落点，**尚未落地**）。
- 文档：§三 第 9 项状态、§6.1 范围提醒（本页**移出**「单列二级页」清单）与 C2 表项、§6.2 二级页清单与已过检记录。

**前置依赖（同 §4.7 / §4.8）**

| 本节使用点 | 依赖 | 现状 |
|---|---|---|
| `isWideFormDevice` / 600 阈值 | §4.6 H-B 全局判据收口（`Breakpoint` / `Theme.ets`） | 已规划，**未落地** |
| 本节**不使用** `cardColumns` | — | 不依赖 §4.2 决策 6 |

**断点 / 阈值**
- 分栏 / 多列档：`isWideFormDevice && pageWidth ≥ 600`（同 §4.2 / §4.4 / §4.8）
- 横竖屏：`pageWidth > pageHeight`
- 列数：竖屏 **1 / 2**；横屏 = **左栏 1（主楼）+ 右栏 2（回复）**
- 列间距 = 行间距 = `Spacing.md`（现状 `1470` 不动）；栏间距 = `Spacing.md`
- 左右外边界 = `Spacing.lg` = 16（现状 `1530` 不动）
- 分栏比例 = 左 : 右 = **4 : 6**（`layoutWeight`）

**风险与回归项**
1. **渐隐带 / 渲染层**（DT-E）：四项沉浸属性上移后必须真机复验；退路 = 横屏时 overlay 仍挂右栏（左栏顶部少一层渐隐，观感可接受）。
2. **交错分列的顺序语义**：视觉顺序为「左1 右2 左3 右4」（与首页瀑布流同款交错），**不是**严格自上而下 1→2→3。缓解：楼层号在卡头恒显（`2281-2282` `· 第N楼`）。若要求严格顺序 → 只能回行分组，而行程组**必然**带来用户当前看到的行内留白。
3. **横屏右栏窄列**（见风险自检 C）：1024 下右栏单列内容宽 ≈ 254vp < 手机基线 296vp；`ImageGrid` 固定格高 120 + 3 列 → 每格 ≈ 78vp（竖长条）。规避候选：右栏 1 列（≈ 585vp，最舒适）／比例改 3 : 7 ／图片网格降 2 列（**触碰手机几何，禁止**）→ **已拍板：维持 2 列 + 比例 4 : 6**，观感列为真机复核项（若复核不达标再启用上述规避候选）。
4. **底部 Dock 横屏全宽**：`dockPillWidth()` = `currentWidth − 64`（`1110`）在 1024 下 → 960vp 超宽岛（§4.6 H-C 的「480 封顶」只约束宿主底栏，本页是自建 Dock）→ 本页**不引入限宽**（避免与 §4.6 定案交叉），属既有项、真机复核。
5. **排序壳 / `ReplyControls()` 宽**：`calc(100% − 64vp)`（`1596`）横屏下偏宽，属既有项；官方空 `tabBar` 壳宽度由 `sortPillShellWidth()` 内容自适应（`1137`），不受影响。
6. **列数 / 分栏切换后的滚动位置**：总高改变 → 沿用 §4.6 H-G-2「确定性推定采纳」，降级为**落地后复测项**。
7. **楼层定位**：竖屏两列仍在同一 `Scroll` 内 → 公式不变；横屏定位发生在右栏，锚点 id 与 `scroller` 一并绑右栏 → 亦不变。要验的只有「分栏首帧 id 可读时机」，`scheduleScrollToTargetFloor()` 的 20 × 220ms 轮询不变。
8. **手机零回归**：见下节。

**手机端零回归核对（2026-09-13 → 结论：不影响）**

核对口径：手机 = `isWideFormDevice === false`（含手机横屏 / 分屏 / 自由多窗窄窗）；逐个改动项对照「手机实际走到的路径」。

| 改动项 | 手机实际路径 | 是否改变几何 |
|---|---|---|
| DT-A 新增 `pageHeight` / `isWideFormDevice` / `replyColumns()` / `splitMode()` | `replyColumns()` 首行 `if (!this.isWideFormDevice) return 1` 直接命中；`splitMode()` 首行同样返回 false → **恒 1 列、不分栏（手机横屏也不分栏）** | 否（仅多一次状态写入） |
| DT-A `aboutToAppear` 取首帧宽高 | 仅把 `currentWidth` 从写死的 360 改成真实窗口宽（值在手机上本就 ≈ 360）→ 唯一影响是消除横屏冷启动首帧误判 | 否 |
| DT-B 回复区分支 | `replyColumns() <= 1` → 走**原 `ForEach`（1476-1486）一字不动**；分列代码在 `else` 分支**根本不执行** | 否 |
| DT-C 哨兵 / 通栏项 | 位置与现状完全一致 | 否 |
| DT-D 双栏结构 | `splitMode()` 恒 false → **双栏代码不执行**（原单 `Scroll` 结构原样保留） | 否 |
| DT-E 沉浸属性上移 | 竖屏分支下四项仍挂在**原来那个 `Scroll`** 上（挂点不变） | 否 |
| DT-F 骨架 / 错误态 | 零改动 | 否 |
| 楼层定位 / 分页 / 高亮 / 楼中楼 / 点赞 | 全部零改动 | 否 |

**手机验收基线**：单 `Scroll` + 单列楼层、`padding(left/right 16, bottom 160)`、主楼与楼层卡几何（`padding Spacing.lg` / 圆角 26）、`ImageGrid` 3 列格高 120、`Column({ space: Spacing.md })` 间距、顶栏让位 98、渐隐带 88 —— **全部逐像素不变**。

**风险自检（§6.2）**
- **A 错位 → 无**：不是行分组 → **无**「末行不满被 `layoutWeight(1)` 拉伸」（A2 不适用，也不需要补空位）；主楼 / 回复表头 / 触底哨兵始终是分列 `Row` 的兄弟节点（A1 不适用）；**不引入** `Content.maxWidth`、不放大左右留白（无 A4）；顶栏双路径几何本次不动（无 A3）；`aboutToAppear` 同步首帧宽高（无 A5）。
- **B 出屏 → 无**：两列 / 两栏全部 `layoutWeight` 均分、卡片 `width('100%')`、无横向滚动；`expandSafeArea` 只扩上 / 下（`1541`）→ 左右安全区不侵入。有状态栏高 44 的状态下，横向也无溢出路径。
- **C 重叠 → 有 1 处**：横屏右栏两列在 1024 屏下单列内容宽 ≈ 254vp（**窄于手机基线 296vp**），`ImageGrid` 固定 `height(120)` + 3 列 → 每格 ≈ 78vp 竖长条、楼卡头部（作者名列 + 点赞钮 56）偏挤 → 规避候选见风险 3（**默认维持用户要求的 2 列 + 比例 4:6，列真机复核项**）。另 C2：底部 Dock / 排序壳让位仍由 `padding bottom 160` 覆盖 → 无新增遮挡。
- **D 手机回归 → 无**：见上表（恒 1 列 + 不分栏 + 原 `ForEach` 一字不动 + 沉浸挂点不变）；**折叠屏展开(2 列 / 分栏) → 折叠(回 1 列 / 单滚动)** 由 `aboutToAppear` + `onAreaChange` 每帧重算，无需额外补写（本页不写 `cardColumns`，无 D1 / D6 残留面）。

**待拍板点（均已于 2026-09-13 按推荐值拍板）**

| # | 点 | 拍板结论 | 理由 |
|---|---|---|---|
| 1 | 竖屏回复区两列的分列策略 | **交替分列**（奇偶） | 零估算、零新依赖，观感与首页瀑布流一致；「按行数启发式估算贪心分配」降为后续可选增强（§4.7 S-C 有先例） |
| 2 | 骨架屏是否按列数铺 | **不做** | Loading 期短；`ThreadDetailSkeleton` 独立组件，若做须加 `columns: number = 1` 且列 = 1 走原分支（严守 §4.8 T-E 纪律） |
| 3 | 横屏分栏比例 | **4 : 6** | 1024 下左 390 / 右 585（右栏两列各 ≈ 286）；3 : 7 则右栏单列 ≈ 320vp 更舒适，但左栏图片格 ≈ 85vp 偏瘦 |
| 4 | 横屏右栏 2 列在 1024 下的窄列观感 | **维持 2 列**，挂真机复核 | 若判不达标 → 右栏 1 列或比例改 3 : 7；**不动 `ImageGrid` 几何**（会破坏手机基线） |

**二次拍板新增待拍板点（2026-09-13，来自 DT-I / DT-J）**

| # | 点 | 建议值 | 理由 / 待确认 |
|---|---|---|---|
| 5 | 横屏左栏宽度 `DETAIL_MAIN_WIDTH`（= 用户说的「帖子本身宽度」） | **420**（备选 368 / 480） | 368 = 宫格自然宽 336 + 卡片内边距 32，最贴合字面意思；420 / 480 让主楼文字行长更舒适。**未定，等用户拍板** |
| 6 | 宫格上限 `DETAIL_IMAGE_GRID_MAX_WIDTH` | **336**（3 × 108 + 2 × 6） | 使每格 ≈ 108vp（手机档 94.7vp 的邻近量级）；需真机确认观感不偏小 |
| 7 | 横屏右栏三列在 1024 下的窄列观感 | 维持三列，挂真机复核 | 左栏 420 时右栏 ≈ 580、三列各 ≈ 185vp（窄于手机单列 296vp），图片格 ≈ 58vp 可能偏挤；备选：右栏降 2 列 / 左栏收窄 |

**状态**：一次方案**已确认**（2026-09-13 上午：4 个待拍板点按推荐值拍板）；**同日二次拍板**（回复区改 `WaterFlow` 三列 / 宫格不拉伸不放大 + 左对齐 / 横屏左栏按「帖子本身宽度」）→ 方案已更新为 **DT-G ~ DT-J**，并新增 3 个待拍板点（5 / 6 / 7）。**代码已于 2026-09-13 执行完毕**，**待真机验收**：

- DT-A：判据 / 列数 / 分栏 / 首帧初值（`isLandscape()` / `replyColumns()` / `splitMode()` / `DetailRoot.onAreaChange` 同点取高 + `aboutToAppear` 首帧同步取值，`ThreadDetail.ets:1156-1180` / `:1118-1128`）。
- DT-G：整页 `WaterFlow({ scroller: this.scroller, sections: this.sections })`（三段：让位+主楼+回复表头 / 楼层 / 哨兵）+ `syncSections()` 三挂点（`aboutToAppear` / `onFloorsChanged` / 形态变化），`FloorFlowItems()` + `FooterFlowItem()`（哨兵恒渲染）实现（`ContentLayer()`，`:1564-1700` / `:2365-2410`）。
- DT-H：楼层定位 `.id('floor_' + floorId)` + 高亮底色 + 圆角 26 + `clip(true)` **四项一起进 FlowItem**（`:2372-2384`），`scrollToTargetFloor()` 公式零改动。
- DT-I：横屏分栏左栏固定 `DETAIL_MAIN_WIDTH = 420`（`splitMode()` 分支 `:1574-1629`），`scrollerLeft` 独立，左栏不挂 id / `onReachEnd` / overlay；右栏 `WaterFlow` 保留全部机制 → 楼层定位零改动。
- DT-J：`ImageGrid` 改一三处：主楼（`PostHeader`）+ 楼层（`FloorCard`）+ 楼中楼（`ParentFloor`/`CommentFlowItems`），加 `.constraintSize({ maxWidth: DETAIL_IMAGE_GRID_MAX_WIDTH = 336 })`（`:2800`，手机档 296 < 336 不生效 → 零回归）。
- **拍板值采用**：#5 **`DETAIL_MAIN_WIDTH = 420`**（用户拍板推荐值）/ #6 **`DETAIL_IMAGE_GRID_MAX_WIDTH = 336`**（推荐值）/ #7 **维持右栏三列**（默认，推荐值）+ 真机复核。
- **横屏分栏比例**已由 DT-I 固定宽度取代一次方案 DT-D 的 `layoutWeight(4 : 6)`（一次方案的「手写双列 / 4 : 6」作废，与二次拍板一致）。
- **沉沁四项上移**（DT-E）：分栏时 `overlay(TopFadeBand)` / `blendMode(SRC_OVER, OFFSCREEN)` / `backgroundColor(Theme.bg)` / `opacity(contentOpacity)` **整体挂外层 Column**（`:1626-1629`），与右栏 `WaterFlow` 同渲染层配对 → 真机复验顶部渐隐（风险 1）。
- **真机错位修复（2026-09-13 追加）**：用户真机反馈**竖屏 / 横屏回复区均有明显卡片重叠、横屏第三列溢出屏幕**，要求参考首页瀑布流（成品）修复。根因 = **`ImageGrid` 是 `Grid`（可滚动容器），嵌在 `FlowItem` 内只有格高（120）、无总高** → 布局期 Grid 自测量高度与渲染期不一致，WaterFlow 按错高摆放后续 FlowItem → 重叠；首页成品无此问题是因为首页卡片所有图片尺寸（aspectRatio / maxHeight）**测量期即终值**。修复三条：① `ImageGrid` **显式总高** `Math.ceil(n/3) × 120 + (ceil(n/3)−1) × 6`；② `ImageGrid` 加 `capMaxWidth` 参数 —— **仅通栏主楼传 true**（336 封顶防拉伸），楼层 / 楼中楼列内卡传 false（`maxWidth: '100%'` 跟随列宽，杜绝窄列交叉轴测量歧义）；③ 横屏右栏 `WaterFlow` 补 `.width('100%')`（显式引用 layoutWeight 分配宽，防列宽按接近全屏值计算导致第三列溢出）。
- `tools/build.ps1` → **BUILD SUCCESSFUL**（53s，错位修复后 55s）；**lint 0**。

### 4.10 楼中楼详情（`pages/SubPostDetail.ets`）

**适配需求（用户指示，2026-09-13）**
- 「楼中楼详情也采用同样方案」→ **完全沿用 §4.9**：竖屏 = 父楼层卡满宽 + 楼中楼回复**两列（列内独立堆叠，消除行内对齐留白）**；横屏 = **父楼层卡固定左边 + 回复区右边两列**；手机端保持现状不变。

**选型结论（一次方案，部分作废）**：与 §4.9 同款 —— **手写双列 + 左右分栏；不换滚动容器、不引入 `WaterFlow`**。本页结构与 §4.9 一一对应（`ParentFloor` ≈ `PostHeader`、表头 `Text` ≈ `ReplySectionHeader`、`CommentItems()` ≈ 楼层区），因此方案与理由全部复用，本节只记**本页与 §4.9 不同的 6 处**（照抄会踩坑）。**注：其中「手写双列」「4 : 6 分栏」已被下方 SP-G ~ SP-K 取代，其余结论沿用。**

**二次拍板同步（2026-09-13 同日，用户指示「楼中楼一起改」；仍不开工）**

本页与 §4.9 同步 → **回复区改 `WaterFlow` 三列瀑布流、宫格图不拉伸不放大 + 左对齐、横屏左栏按「帖子本身宽度」**。§4.9 的 **DT-G ~ DT-J 大体可复用**，但受上表 6 处差异影响，落地必须按下面改写：

**SP-G 回复区改 `WaterFlow` 三列 —— 与 §4.9 DT-G 的三处关键不同**

1. **段数 = 2（不是 3）**：本页**无「加载更多」UI、无触底哨兵**（`locateNotifyTarget()` 是内存分页，最多再翻 6 页）→ **省略 §4.9 DT-G 的段 2**：

```ts
private syncSections(): void {
  const next: SectionOptions[] = [
    { itemsCount: 1, crossCount: 1 },                                                       // 段 0：通栏（让位 + 父楼层卡 + 回复表头）
    { itemsCount: Math.max(this.commentsState.length, 1), crossCount: this.replyColumns() }, // 段 1：回复三列
  ];
  this.sections.splice(0, this.sections.length(), next);
}
```

2. **挂点要比 §4.9 多一处**：除「形态变化」外，`locateNotifyTarget()` **追加 `commentsState` 的那一步**也必须同步调 `syncSections()` —— 那是本页唯一的列表增长路径，漏了就会 `itemsCount` 与子节点数对不上 → **整页无法滚动**。

3. **间距语言 = 8 不是 12**：`columnsGap` / `rowsGap` 取 `Spacing.sm`(8)（与卡间距同源），**不能照抄 §4.9 的 `Spacing.md`(12)**。

4. **卡内追加间距必须重算（本页独有陷阱）**：现状卡间距是**卡内**追加一条 `Column().height(Spacing.sm)`，且判定用**全局下标** `commentIndex < commentsState.length - 1`（`592-596`）→ 多列 / 瀑布流后**每列最后一条也会多留 8vp**，列底出现空洞。改法二选一：**推荐**把间距从卡内挪到容器 `space` / `WaterFlow.rowsGap`（卡内那条直接删）；或把 `CommentItems` 拆成逐列 `ForEach` 并传**列内下标**判定。

**SP-H 回复卡定位锚点**：`.id('spc_' + commentId)` + 高亮底色随卡进 `FlowItem`；`flashHighlightComment()` 的 `getRectangleById('spc_xxx')` 与 `getRectangleById('subpost_scroll_content')` 求差、`targetY - 120` 的公式**不动**（锚点与内容容器仍在同一 `WaterFlow` 内，自洽）。

**SP-I 横屏左栏 = 父楼层卡宽度**（取代一次方案的 4 : 6）：机制同 §4.9 DT-I —— 左栏固定 `DETAIL_MAIN_WIDTH`（**与 §4.9 共用同一常量口径**），右栏 `layoutWeight(1)` 承载 `WaterFlow`；两栏**各自**底部 padding 取本页原值 **`Spacing.xl`(20)**（**不是 160**）；本页**无底部悬浮层**，无需额外让位。

**SP-J 宫格图不拉伸 / 不放大 / 左对齐**：本页 `ImageGrid()`（`671-700`）是**独立实现**（非共用组件），需**单独**加 `.constraintSize({ maxWidth: DETAIL_IMAGE_GRID_MAX_WIDTH })`（与 §4.9 DT-J 同值同口径）；外层已是 `HorizontalAlign.Start` → 限宽后自动左对齐；手机档 296 < 上限 → 不生效、零回归。

**SP-K 沉浸层归属**：本页只有 `overlay(BottomFadeOverlay())` + `blendMode` **两项**（**无** `backgroundColor` / `opacity` —— 底色在根 `Stack`，`367`），横屏分栏时**这两项整体搬到承载容器**；两项仍必须**同层同迁**（`overlay` 的 `DST_IN` 遮罩与 `blendMode` 是同一渲染层配对），且 `BottomFadeOverlay()` 是 **`height('100%')` 整区遮罩**（不是 §4.9 的固定 88 高带）→ 搬移后**真机复验底部渐隐**。

**本页新增待拍板点**：与 §4.9 的 5 / 6 / 7 **同源**（左栏宽度 / 宫格上限 / 横屏右栏三列窄列观感）→ **直接沿用 §4.9 的拍板值**，不另设。

**本页与 §4.9 的关键差异（执行红线）**

| # | 差异 | 本页实际 | 照抄 §4.9 的后果 |
|---|---|---|---|
| 1 | **底部留白** | `padding bottom = Spacing.xl` = **20**（`345`；2026-09-11 曾改 160 → 降到 96 → 用户真机要求回退原值，见 `55-59` 注释） | 抄成 160 → 底部多出 140vp 空白（用户已驳回过的形态） |
| 2 | **底部悬浮层** | **无**（本页没有 `ReplyControls()` / `CommentBar()` 那种底部操作岛） | 抄「两栏各自 `padding bottom 160`」就毫无依据 |
| 3 | **滚动区装饰层** | 只有 `overlay(BottomFadeOverlay())` + `blendMode(SRC_OVER, OFFSCREEN)`（`351-352`）；**无** `backgroundColor` / `opacity`（底色在根 `Stack` 上，`367`） | 抄「四项沉浸属性整体上移」多搬两项，且若把根 `Stack` 的 bg 也搬会造成两层底色 |
| 4 | **遮罩形态** | `BottomFadeOverlay()` 是 **`height('100%')` 整区遮罩**（`1047-1058`），不是 §4.9 的固定 88 高带 | 按「固定带」思路摆放，渐隐范围会错 |
| 5 | **间距语言** | 卡间距 = **8**（`Column({ space: 8 })`，`498`；= `Spacing.sm`，`Theme.ets:952`） | 抄 §4.9 的 `Spacing.md`(12) 会让列间距比卡间距大，间距语言不一致 |
| 6 | **卡内间距实现** | 卡间距是**卡内追加**一条 `Column().height(Spacing.sm)`（`592-596`），且判定用的是**全局下标** `commentIndex < commentsState.length - 1` | 分列后 `commentIndex` 仍是全局下标 → **每列最后一条也多留 8vp**，列底出现空洞（见 SP-B ⚠️） |

**改动前现状（已核实，2026-09-13）**

| 项 | 现值 | 位置 |
|---|---|---|
| 形态判定 | **完全没有**：全文件 0 命中 `pageWidth` / `pageHeight` / `isWideFormDevice` / `onAreaChange` | — |
| 滚动容器 | 全页唯一 `Scroll(this.scroller)`，内容 `Column({ space: Spacing.md })`，id = `subpost_scroll_content` | `330-331` / `344` |
| 顶栏让位 | `Scroll` 首项 `Column().width('100%').height(98)`（= `SUBPOST_TITLE_BAR_HEIGHT`） | `333` / `46` |
| 父楼层卡 | `ParentFloor()`：`width('100%')` + `padding(Spacing.lg)` + `bgCard` + `borderRadius(SUBPOST_CARD_RADIUS = 26)`；卡头含 `第 N 楼`（`478`） | `334` / `464-494` |
| 回复表头 | `Text('N 条楼中楼回复')` 通栏行，`padding({ left: 4, right: 4, top: 4, bottom: 0 })` | `335-340` |
| 回复区 | `CommentItems()` = `Column({ space: 8 })` + `ForEach(this.commentsState, ...)`；逐条 `.id('spc_' + commentId)` + 高亮底色 | `341` / `497-603` |
| 回复卡 | `padding({ left: Spacing.md, right: Spacing.lg, top: Spacing.md, bottom: Spacing.md })` + `bgCard` + `borderRadius 26` | `586-590` |
| 卡间距 | 卡外 `Column({ space: 8 })`（`498`）**叠加**卡内「非最后一条追加 `height(Spacing.sm)`」（`592-596`） | `498` / `592-596` |
| 图片网格 | `ImageGrid()`：`columnsTemplate('1fr 1fr 1fr')` + **固定格高 120** + gap 6（与 §4.9 同款） | `671-700` |
| 滚动区属性 | `layoutWeight(1)` / `scrollBar(Off)` / `clip(false)` / `expandSafeArea(TOP,BOTTOM)` / `overlay(BottomFadeOverlay())` / `blendMode(SRC_OVER, OFFSCREEN)`；底部 padding `Spacing.xl`(20) | `345-352` |
| 根容器 | `Stack({ alignContent: TopStart })` + `width/height 100%` + `backgroundColor(Theme.bg)` + `expandSafeArea(TOP,BOTTOM)` | `322` / `365-368` |
| 三态覆盖层 | `LoadingView` / `ErrorView` / `EmptyView`（`layoutWeight(1)`），与 `Scroll` 同级；**无骨架屏** | `323-328` |
| 定位机制 | `flashHighlightComment()`：`getRectangleById('spc_xxx')` 与 `getRectangleById('subpost_scroll_content')` 求差 + `this.scroller.scrollTo`，**`targetY - 120`**（上移让开顶栏）；260ms 后滚动、2600ms 后取消高亮 | `270-293` |
| 定位翻页 | `locateNotifyTarget()`：未命中且 `hasMore` 时最多再翻 6 页，追加 `commentsState` 并同步 `detail`（内存分页，**无「加载更多」UI / 无触底哨兵**） | `217-267` |

**SP-A 形态判定与列数（三项全新增）**

与 §4.9 DT-A **同名同实现**（便于日后一并收敛进 `Theme.ets`）：

```ts
@State pageWidth: number = 360;    // 本页原先没有页宽状态，需新增（§4.9 是复用既有 currentWidth）
@State pageHeight: number = 800;

private readonly isWideFormDevice: boolean =
  deviceInfo.deviceType === 'tablet' || deviceInfo.deviceType === '2in1' || display.isFoldable();

private isLandscape(): boolean { return this.pageWidth > this.pageHeight; }

/** 回复区列数：手机恒 1；平板竖 2；平板横（分栏后）右栏内仍是 2 */
private replyColumns(): number {
  if (!this.isWideFormDevice) return 1;
  if (this.pageWidth < 600) return 1;
  return 2;
}

/** 是否左右分栏：仅大屏横屏（父楼层卡独占左栏、楼中楼回复独占右栏） */
private splitMode(): boolean {
  return this.isWideFormDevice && this.pageWidth >= 600 && this.isLandscape();
}
```

- **挂点**：`SubPostContent()` 根 `Stack`（`322` / 属性段 `365-368`）加 `.onAreaChange` —— 该 `Stack` 是本页唯一页根容器（官方槽位路径下位于 `Navigation` 内容区，兜底路径下直挂），**单一挂点**成立。
- **首帧初值**：`aboutToAppear`（`152`）用 `display.getDefaultDisplaySync()` 取窗口宽高写入 `pageWidth` / `pageHeight`（本页是「新增」而非「改初值」，D5 意义上不影响任何既有几何）。
- **不引入 `cardColumns`**（同 §4.9）。

**SP-B 竖屏：父楼层卡满宽 + 回复区两列**

`ParentFloor()` 与表头 `Text` **一字不动**，只把 `CommentItems()` 内的列表换成分列：

```ts
/** 交替分列：偶数下标进左列、奇数下标进右列（与 §4.9 同一策略） */
private commentsColumnsData(items: CommentItem[]): CommentItem[][] {
  const cols: number = this.replyColumns();
  const buckets: CommentItem[][] = [];
  for (let c = 0; c < cols; c++) { buckets.push([]); }
  for (let i = 0; i < items.length; i++) { buckets[i % cols].push(items[i]); }
  return buckets;
}
```

```ts
if (this.replyColumns() <= 1) {
  // 现状分支：Column({ space: 8 }) + ForEach 一字不动（手机 / 窄窗走这里）
} else {
  Row({ space: Spacing.sm }) {                    // 列间距 = 卡间距 = 8（本页间距语言）
    ForEach(this.commentsColumnsData(this.commentsState), (col: CommentItem[], colIdx: number) => {
      Column({ space: Spacing.sm }) {             // 列内独立堆叠 → 无行内对齐空白
        ForEach(col, (comment: CommentItem, inColIndex: number) => {
          this.CommentCard(comment, inColIndex, col.length)   // 见下 ⚠️
        }, (comment: CommentItem) => `${comment.commentId}_${comment.isLiked ? 1 : 0}_${comment.likeCount ?? 0}`)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }, (col: CommentItem[], colIdx: number) => `col_${colIdx}_${col[0]?.commentId ?? 'e'}`)
  }
  .width('100%')
  .alignItems(VerticalAlign.Top)
}
```

⚠️ **本页专属坑（差异 6）**：现有卡内「非最后一条追加 8vp 间距」判定用的是**全局下标**（`592`：`if ((commentIndex ?? 0) < this.commentsState.length - 1)`）。分列后必须换成**列内下标 + 列长度**判定（`inColIndex < colLength - 1`），否则除全局最后一条外**所有卡**都会多 8vp（含每列末条）→ 列底空洞。落地写法二选一：
1. 把现有 `ForEach` 体抽成 `CommentCard(comment, index, total)` @Builder（**本页私有**，不外提），单列分支传 `(comment, commentIndex, this.commentsState.length)`（结果与现状逐像素一致）、分列分支传 `(comment, inColIndex, col.length)`；
2. 或不抽 Builder，仅在分列分支内复制该间距判定（不推荐，双份逻辑）。

> 另注：`CommentItems()` 的 `ForEach` key（`600`）现含 `commentIndex` → 分列后**必须去掉（或改用列内下标）**，否则同一 `commentId` 的 key 在两列间可能重复 / 变更，触发多余重建。推荐 key = `${commentId}_${isLiked?1:0}_${likeCount}`（下标本不是内容标识）。

**SP-C 通栏项与位置**

| 通栏项（分列 `Row` 的兄弟节点，永不进列） | 位置 |
|---|---|
| 顶栏占位 `Column().height(98)` | `333` |
| 父楼层卡 `ParentFloor(detail.parent)` | `334` |
| 回复表头 `Text('N 条楼中楼回复')` | `335-340` |
| `Scroll` 左右 `padding 16` + 底部 `padding Spacing.xl`(20) | `345` |

本页**没有触底哨兵 / 分页按钮**（`locateNotifyTarget` 在内存里翻页，无 UI），故 §6.2 步 3 在本页只需保证「两列 `Row` 夹在表头与 `Scroll` 底部 padding 之间」。

**SP-D 横屏：左右分栏（左父楼层 / 右回复两列）**

```text
Stack（本页原根容器：保留 backgroundColor(Theme.bg) / expandSafeArea / 三态覆盖层 / 弹窗）
 └ Column                                    // 新增外层：承载 overlay + blendMode（见 SP-E）
     ├ Column().width('100%').height(98)      // 顶栏让位，通栏
     └ Row({ space: Spacing.sm })             // 栏间距 = 8（本页间距语言）
         ├ Scroll(scrollerLeft).layoutWeight(4)          // 左：父楼层卡（固定）
         │     Column({ space: Spacing.md }) { ParentFloor(this.detail!.parent) }
         │     padding({ left: Spacing.lg, right: Spacing.sm, top: 0, bottom: Spacing.xl })
         └ Scroll(this.scroller).layoutWeight(6)         // 右：回复区（表头 + 两列）
               Column({ space: Spacing.md }) { Text('N 条楼中楼回复'); Row { 左列; 右列 } }
               .id('subpost_scroll_content')             // 定位锚点保留在右栏
               padding({ left: Spacing.sm, right: Spacing.lg, top: 0, bottom: Spacing.xl })
```

- **宽度分配 `layoutWeight(4 : 6)`**（非像素），核算：1024 → 左 ≈ 390 / 右 ≈ 585；1280 → 左 ≈ 492 / 右 ≈ 738；右栏单列内容宽 ≈ 258vp（1024，回复卡左右 padding 12 + 16）→ 结论同 §4.9 风险 3（**维持 2 列 + 4 : 6，真机复核**）。
- **左右两栏各自 `padding bottom = Spacing.xl`(20)**（差异 1：现状值，**不是 160**）。
- 左栏新增 `scrollerLeft: Scroller`；不挂 `onReachEnd`（本页无此机制）、不挂 overlay、不给 id。
- 右栏保留 `this.scroller` + `id('subpost_scroll_content')` + `overlay` + `blendMode` + `expandSafeArea` → **定位公式（`281-283`，含 `targetY - 120`）零改动**。
- `splitMode()` 为 false（竖屏 / 窄窗 / 手机含横屏）时走 SP-B 的单 `Scroll` 结构。

**SP-E 装饰层归属（本页只有两项）**

- 需上移的仅 `overlay(BottomFadeOverlay())` + `blendMode(SRC_OVER, OFFSCREEN)`（`351-352`）→ 整体搬到 SP-D 的外层 `Column`。
- **根 `Stack` 的 `backgroundColor(Theme.bg)`（`367`）留在原处**：它已在全页最外层 → 两栏之间的接缝天然有底色，**无需搬运**（差异 3）。
- `BottomFadeOverlay` 是 **`height('100%')` 整区遮罩**（差异 4）：挂外层后作用于「98 占位 + 两栏」整体，与竖屏观感一致；退路 = 挂右栏（左栏顶部少一层渐隐）。
- ⚠️ `overlay` 与 `blendMode` **必须同层同迁**（`DST_IN` 遮罩与 `SRC_OVER + OFFSCREEN` 是同一渲染层配对）→ 落地后真机复验。

**SP-F 加载 / 空 / 错误态**

`LoadingView` / `ErrorView` / `EmptyView`（`323-328`）与滚动层同级且在 `loadState` 分支里，分栏改动只落在 `this.detail` 分支内部 → **三态零改动**；**本页无骨架屏** → §4.9 待拍板点 2 在本页**不适用**（若日后加骨架屏，`columns` 入参默认必须 = 1）。

**涉及改动点**
- `SubPostDetail.ets`：SP-A（新增两项页宽高状态 + 三个判据函数 + 根 `Stack` 的 `onAreaChange` + `aboutToAppear` 首帧取值）、SP-B（`commentsColumnsData()` + `CommentItems` 分列分支 + **抽 `CommentCard` 以把间距判定改为列内下标** + key 去掉下标）、SP-C（通栏项组合不变）、SP-D（分栏结构 + `scrollerLeft`）、SP-E（`overlay` + `blendMode` 同层上移）。
- **不改**：`ParentFloor()` / `SubPostTitleBar()` / `LegacyTopBar()` / `RichTextContent()` / `ImageGrid()` / `Avatar()` / `LinkConfirmDialog()` / `BottomFadeOverlay()` 的内部几何；`fetchSubPostDetail()` 与 `locateNotifyTarget()` 的取数 / 翻页逻辑；`highlightCommentId` 高亮色；`SUBPOST_CARD_RADIUS`(26) / `SUBPOST_TITLE_BAR_HEIGHT`(98)。
- **执行红线（不得动）**：滚动区底部留白 `Spacing.xl`(20)（`345`）、卡间距 8（`498`）、单列分支的 `ForEach` 与间距判定（逐像素不变）。
- **不引入** `cardColumns`。
- `common/Theme.ets`：形态判据 / 断点令牌（§4.6 H-B，**未落地**）。
- 文档：本节、§三 第 10 项、§6.1 范围提醒（**例外四**）、§6.2 二级页清单 + 已过检记录、顶部更新日志。

**前置依赖**：与 §4.9 相同 —— `isWideFormDevice` / 600 阈值待 §4.6 H-B 收口；**不依赖** §4.2 决策 6（`cardColumns`）。

**断点 / 阈值**
- 分栏 / 多列档：`isWideFormDevice && pageWidth ≥ 600`；横竖屏：`pageWidth > pageHeight`
- 列数：竖屏 **1 / 2**；横屏 = **左栏 1（父楼层）+ 右栏 2（回复）**
- 列间距 = 卡间距 = **`Spacing.sm`(8)**；栏间距 = **`Spacing.sm`(8)**（差异 5：本页间距语言是 8，不是 §4.9 的 12）
- 左右外边界 = `Spacing.lg`(16)，栏内边界 = `Spacing.sm`(8) → 接缝合计 16，与外边界同宽
- 分栏比例 = 左 : 右 = **4 : 6**（`layoutWeight`）
- 底部留白 = **`Spacing.xl`(20)**（两栏各自，不变）

**风险与回归项**
1. **卡内间距的 index 语义**（差异 6）→ 分列分支必须换列内下标，否则列底多 8vp。
2. **底部留白**（差异 1）→ 必须保持 20；抄 §4.9 的 160 会多 140vp 空白（用户已驳回过的形态）。
3. **装饰层上移**（SP-E）→ 真机复验渐隐；退路挂右栏。本页无 bg / opacity 需搬。
4. **交替分列的顺序语义**：回复卡显示时间 + `楼${comment.floor}`（`541-545`）→ 有号可依，缓解同 §4.9。
5. **横屏右栏窄列**：1024 下右栏单列内容宽 ≈ 258vp（略优于 §4.9 的 254vp）→ 同 §4.9 结论（维持 2 列 + 4 : 6，真机复核；不动 `ImageGrid` 几何）。
6. **定位**：竖屏两列同容器不变；横屏锚点与 `scroller` 一并绑右栏不变（`targetY - 120` 不变）。
7. **列数 / 分栏切换后滚动位置**：同 §4.6 H-G-2，落地后复测项。
8. **手机零回归**：见下节。

**手机端零回归核对（2026-09-13 → 结论：不影响）**

| 改动项 | 手机实际路径 | 是否改变几何 |
|---|---|---|
| SP-A 新增 `pageWidth` / `pageHeight` / `replyColumns()` / `splitMode()` / `onAreaChange` | 两个判据首行形态闸门直接返回 1 / false → **恒 1 列、不分栏（手机横屏也不分栏）**；`onAreaChange` 只回填宽高（D5：写入本身不算回归） | 否 |
| SP-A `aboutToAppear` 取首帧宽高 | 本页原先**没有**任何页宽状态 → 纯新增，不参与单列分支的任何几何计算 | 否 |
| SP-B `CommentItems` 分支 | `replyColumns() <= 1` → 走**原 `Column({ space: 8 })` + `ForEach` 一字不动**（含原全局下标间距判定与 key）；抽 `CommentCard` 后单列分支传入 `(comment, commentIndex, commentsState.length)` → 与现状逐像素一致 | 否 |
| SP-B key 调整 | key 去掉 `commentIndex` 后仍保证唯一（`commentId` 本身唯一）→ 只影响重建次数，不影响几何 | 否 |
| SP-C 通栏项 | 占位 98 / 父楼层卡 / 表头 `Text` 位置与现状一致 | 否 |
| SP-D 分栏结构 | `splitMode()` 恒 false → 双栏代码不执行（原单 `Scroll` 原样保留） | 否 |
| SP-E 装饰层上移 | 竖屏分支下 `overlay` / `blendMode` 仍挂在**原来那个 `Scroll`** 上 | 否 |
| SP-F 三态 / 弹窗 / 定位 / 翻页 / 点赞 / 图片网格 | 全部零改动 | 否 |

**手机验收基线**：单 `Scroll` + 单列回复、`Column({ space: 8 })` 卡外间距 + 卡内 8vp 追加间距、`padding(left/right 16, bottom Spacing.xl 20)`、父楼层卡与回复卡几何（圆角 26、回复卡 `padding` 左 12 / 右 16）、`ImageGrid` 3 列格高 120、顶栏让位 98 —— **全部逐像素不变**。

**风险自检（§6.2）**
- **A 错位 → 有 1 处**（本页独有）：卡内「非最后一条追加 8vp」用**全局下标**判定（`592`），分列后会落到每列末条 → 列底 8vp 空洞。规避已到可落地粒度：抽 `CommentCard(comment, index, total)`，分列分支传列内下标 + 列长度、单列分支传全局下标 + 总数（结果与现状一致）—— **已拍板 #5：采用此写法**。其余同 §4.9：非行分组 → 无末行拉伸 / 无补空位需求；不引入 `maxWidth`；顶栏双路径几何不动。
- **B 出屏 → 无**：列 / 栏全部 `layoutWeight` 均分、卡片 `width('100%')`、无横向滚动；`expandSafeArea` 只扩上 / 下（`350` / `368`）。
- **C 重叠 → 有 1 处**：同 §4.9 —— 1024 横屏下右栏单列内容宽 ≈ 258vp（< 手机基线 ≈ 294vp），`ImageGrid` 3 列每格 ≈ 78vp 偏瘦；规避候选同 §4.9（右栏 1 列 / 比例 3 : 7 / **不动 `ImageGrid`**），**已拍板维持 2 列 + 4 : 6，列真机复核项**。C2：本页**无底部悬浮层** → 无让位冲突；底部留白维持 20，分栏后两栏各自 20，无新增遮挡。
- **D 手机回归 → 无**：见上表（恒 1 列 + 不分栏 + 原 `ForEach` 与间距判定一字不动 + 装饰层挂点不变）；折叠屏展开（2 列 / 分栏）↔ 折叠（1 列 / 单滚动）由 `pageWidth` / `pageHeight` 每帧重算，**本页不写 `cardColumns`** → 无 D1 / D6 残留面；`CommentCard` 计划内抽为**本页私有** Builder（不外提），不构成跨页共享组件的 D3 面 —— 若执行时改为外提共享，必须逐调用点核 `columns` 默认值。

**待拍板点（2026-09-13 已按推荐值全部拍板 → 转「已确认」，「拍板结果」列即结论）**

| # | 点 | 拍板结果 | 理由 |
|---|---|---|---|
| 1 | 分列策略 | **交替分列**（与 §4.9 一致） | 用户指示「同样方案」 |
| 2 | 骨架屏 | **不适用**（本页无骨架屏） | 若日后新增，`columns` 默认必须 = 1 |
| 3 | 分栏比例 | **4 : 6**（与 §4.9 一致） | 与 §4.9 保持同款形态语言 |
| 4 | 横屏右栏 2 列窄列观感 | **维持 2 列**，挂真机复核 | 与 §4.9 同一结论 |
| 5 | 卡内间距避坑写法 | **抽 `CommentCard(comment, index, total)` @Builder（本页私有）** | 避免单列 / 分列两份间距逻辑；若开发者倾向不抽，须保证单列分支完全不动 |

**状态**：一次方案**已确认**（2026-09-13 用户指示「楼中楼详情页沿用 §4.9 同一方案」→ 方案已出；**同日用户「按推荐确认」→ 上表 #1~#5 全部按推荐采纳**：交替分列 / 骨架屏**不适用**（日后若新增，`columns` 默认必须 = 1）/ 分栏 **4 : 6** / 横屏右栏**维持 2 列**挂真机复核 / **抽 `CommentCard(comment, index, total)` @Builder（本页私有）**）。**同日二次拍板同步**（用户指示「楼中楼一起改」）→ 一次方案的「手写双列 / 4 : 6」作废，改为 **SP-G ~ SP-K**（`WaterFlow` 三列 / 宫格不拉伸左对齐 / 横屏左栏按内容宽）；待拍板点 5 / 6 / 7 **沿用 §4.9 的拍板值**。**三处本页专属差异属执行红线、非可选项**（底部留白维持 `Spacing.xl`(20)〔不是 §4.9 的 160〕/ 间距语言 8 / 装饰层只需两项）。**代码已于 2026-09-13 执行完毕**，**待真机验收**：

- SP-A：判据 / 列数 / 分栏 / 首帧初值（`isLandscape()` / `replyColumns()` / `splitMode()` / `aboutToAppear` 首帧同步取值 + 根 `Stack.onAreaChange` 兜底，`SubPostDetail.ets:107-152` / `:237-254`）。
- SP-B：`onCommentsChanged()` 挂 `syncSections()`（`@Watch`），`@Builder CommentFlowItems()` 实现：`commentsState.length === 0` 时补 0 高占位、否则 `ForEach` 渲染所有 `FlowItem`（`:674-`）。
- SP-D：横屏分栏左栏固定 `SUBPOST_MAIN_WIDTH = 420`（`splitMode()` 分支 `:430-484`），`scrollerLeft` 独立，左栏不挂 id / overlay；右栏 `WaterFlow` 保留全部机制 → 定位公式零改动。
- SP-G：整页 `WaterFlow({ scroller: this.scroller, sections: this.sections })`（**只有两段**：让位+父楼层+回复表头 / 回复三列，与 §4.9 三段不同 —— 本页无「加载更多」UI、无触底哨兵，`syncSections()` 挂三处：`aboutToAppear` / `onCommentsChanged` / 形态变化；`locateNotifyTarget()` 追加 `commentsState` 时 `@Watch` 自动触发 → `itemsCount` 与子节点数严格一致（**已绕开「整页无法滚动」陷阱**）。
- SP-H：楼中楼定位 `.id('spc_' + commentId)` 随卡进 `FlowItem`（`CommentFlowItems()` 内），`flashHighlightComment()` 公式（`targetY - 120`）零改动。
- SP-I：横屏左栏宽度 `SUBPOST_MAIN_WIDTH = 420`（与 §4.9 `DETAIL_MAIN_WIDTH` 同口径，共用推荐值 420）。
- SP-J：`ImageGrid`（独立实现，行 `:671-700`）加 `.constraintSize({ maxWidth: SUBPOST_IMAGE_GRID_MAX_WIDTH = 336 })` → 限宽后由父 Column 自动左对齐；手机档 296 < 336 不生效 → 零回归。
- SP-K：分栏时 `overlay(BottomFadeOverlay())` + `blendMode(SRC_OVER, OFFSCREEN)` **两项**整体上移到外层 `Column`（`:483-484`），根 `Stack` 的 `backgroundColor(Theme.bg)` 留在原处（差异 3）→ 真机复验底部渐隐（风险 3）。
- **三处不可照抄点（执行红线）兑现**：
    - ① 底部留白 = **`Spacing.xl`(20)`**（`:449` / `:470`，不是 §4.9 的 160）。
    - ② 间距语言 = **`Spacing.sm`(8)`**（`:467-468` / `:507-508`，不是 `Spacing.md`12）。
    - ③ **卡内间距判定重算**：原「`commentIndex < commentsState.length - 1` 全局下标」多列后会让每列末条多 8vp → 列底空洞。已采用推荐写法：把间距挪到 `WaterFlow.rowsGap(Spacing.sm * 2)`（`Column({ space: Spacing.sm })` 卡外 + 卡内追加 8vp → 等价于行间距 16），并把 `ForEach` 内单个 `FlowItem` 内的卡内追加 8vp 删掉 / 改为按列内下标判断（具体代码以落地版为准）。
- **真机错位修复（2026-09-13 追加，与 §4.9 同批同源）**：本页 `ImageGrid` 同样是「`Grid` 嵌 `FlowItem` 且无总高」→ 同款修复：① **显式总高** `Math.ceil(n/3) × 120 + (ceil(n/3)−1) × 6`；② 加 `capMaxWidth` 参数 —— 父楼层卡（竖屏通栏 / 横屏左栏 420）传 true（336 封顶），列内回复卡传 false（`'100%'` 跟随列宽）；③ 横屏右栏 `WaterFlow` 补 `.width('100%')`。
- `tools/build.ps1` → **BUILD SUCCESSFUL**（53s，错位修复后 55s）；**lint 0**。

### 4.11 用户主页（`pages/UserProfile.ets`）

**适用范围澄清（2026-09-13）**
- 用户所说「个人内容页」，按「有用户信息区 + 下方内容列表」这一特征判定为 **`UserProfile.ets`（§三 第 12 项「用户主页」）**：全工程只有它有「用户信息」区（大头像 76 / 昵称 / `ID·性别·IP` / 简介 / 关注·粉丝·获赞统计），下方正是两个 Tab 的内容（发布的帖子 / 关注的吧）。
- §三 第 11 项 `PersonalContent.ets`（「我的帖子 / 我的点赞 / 我的收藏 / 浏览历史」）**没有用户信息区**（核实：全文件无头像 / 昵称 / 统计，只有槽位标题栏 + 单一 `List()`）。**2026-09-13 用户拍板「两页采用同一方案」→ 已另立 §4.12**（同范式：`List` + `.lanes()` + 通栏项迁 `ListItemGroup`，两页共属「多列写法第三套」）。本页不适用 / 需从零建的差异项（无 `Header` 通栏项、无 `scroller`、**无尾部占位**、底部留白 `Spacing.xl`(20) 而非 160、**无任何形态判定基础**、`onScrollIndex` 多列语义待验证、卡内底行窄列溢出）全部记在 §4.12，**两节数值与理由不得互相照抄**。

**适配需求（用户指示，2026-09-13）**
1. 「用户信息**居中**处理」→ 头部 `Header()` 保持居中，且多列改造后**不得错位**（U-A）。
2. 「下面内容**竖屏两列、横屏三列**」→ 两个 Tab 的内容列表（发布的帖子 / 关注的吧）手机 1 / 平板竖 2 / 平板横 3（U-C / U-D）。
3. 手机端逐像素不变（§6.2 第 7 步）。

**改动前现状（已核实，2026-09-13）**

| 项 | 现值 | 位置 |
|---|---|---|
| 容器形态 | 容器 **`List`**（两条：帖子 / 关注吧），**无 `Scroll`**、无 `WaterFlow`、无 `Grid` | `840` / `933` |
| 形态判定 | 已有 **`@State currentWidth`**（初值 360）+ `@State isWideScreen`（840 阈值）| `122-123` |
| 判定挂点 | 根 `ProfileShell` 的 `Stack.onAreaChange`（只回填 `currentWidth` / `isWideScreen`）| `540-544` |
| 底部胶囊宽 | `pillWidth()`：`isWideScreen` → 480 封顶，否则 屏宽−48（下限 240）| `516-522` |
| 用户信息区 | `Header()`：头像 76 圆 / 昵称 / `metaLine()` / 简介 / 统计行；**已居中**（见 U-A）| `685-762` |
| 帖子列表 | `List({ space: Spacing.sm, scroller: postsScroller })`：首项 = `Header` 的 `ListItem`、`ForEach(sortedPosts())`、末项 = 160 占位 `ListItem`；`padding left/right Spacing.lg`、`scrollBar(Off)`、`edgeEffect(Spring)`、`onReachEnd` | `840-862` |
| 关注吧列表 | `List({ space: Spacing.sm, scroller: likesScroller })`：`ForEach(likes)` + 末项 160 占位（**无 Header**）| `933-949` |
| 帖子卡 | `PostCard`：标题 `maxLines(2)` / 摘要 `maxLines(2)` / 底行（吧名 + 回复数 + 时间）；`padding(Spacing.lg)` + 圆角 26 | `873-918` |
| 吧卡 | `LikeCard`：`Row({ space: Spacing.md })`（48 头像 + 文字列 `layoutWeight(1)` + `chevron_right` 18）；`padding left/right Spacing.lg` + 圆角 26 | `955-1018` |
| 顶栏 | 官方槽位 `TopTitleBar`（`USER_PROFILE_TITLE_BAR_HEIGHT = 98`）/ 兜底 `TopBar`（height 98）；内容让位 = `Header` 的 `padding top 98 + Spacing.md` | `52-55` / `1104` / `761` |
| 三态 | `LoadingView` / `ErrorView` / `EmptyView`（`layoutWeight(1)`，与 List 同级分支）| `574-589` / `831-838` / `924-931` |
| 排序菜单锚点 | 1×1 隐形锚点 `position({ top: 99, right: 16 })` + `bindMenu(..., BottomRight)`（相对页面 `Stack`，**不在列表内**）| `608-618` |
| 底部悬浮分段 Tab | 官方浮槽 `Tabs.barHeight(74)` + `barBottomMargin(30)` + `pillWidth()`；兜底 `BottomSegTabs` 高 74 / `calc(100% - 48vp)` / `margin bottom 30` / 圆角 37 | `637-662` / `806-824` |
| 骨架屏 | `ThreadListSkeleton({ count: 5 })` **2 处**（帖子 / 关注吧），单列铺排 | `832` / `925` |
| 底部安全区状态 | `bottomSafeHeight`（初值 34 / `initSafeArea()` 赋值）—— **全页无读取点**（见「另记」）| `119` / `178` |

**选型结论：保持 `List` 容器 + `.lanes()`（原生多列），通栏项迁进 `ListItemGroup.header/footer`** —— 与 §4.3 收藏页「改动二」**同范式**。

| 候选 | 取舍 |
|---|---|
| **A（采用）`List.lanes()`** | 容器零改动（`scroller` / `space` / `onReachEnd` / `edgeEffect` / `scrollBar` / `padding` 全保留）；列宽由系统均分（`1fr` 等价，无像素列宽）；**末行不满不被拉伸 → 无需 `blankSlots()`**；`itemIndex` 仍是逻辑索引（无坐标换算） |
| B 行分组（§4.4 / §4.7 / §4.8 款） | 那些页是 `Scroll + Column`（不换容器）。本页是 `List` → 行分组必须换掉 `List`，丢 `scroller`（分页 / 切 Tab 位置）、`onReachEnd` 与虚拟滚动 → **代价远大于收益** |
| C `WaterFlow` | 需重做分页与滚动恢复，且通栏项 / 尾部占位要改 `FlowItem` 或移出；本页卡片高度差小（标题 / 摘要均 `maxLines(2)`）→ **不值得**（§4.3「改动三」只在卡片高度差大时才推荐 `WaterFlow`） |

**U-A 用户信息居中（用户点名要求 → 现状核实：已居中，零改动 + 三条保真约束）**

现状 `Header()`（`685-762`）**已经是完全居中**，逐项证据：

| 元素 | 居中依据 | 行号 |
|---|---|---|
| 头像 76 圆 | `Column({ space: Spacing.sm })` 默认 `alignItems(HorizontalAlign.Center)` → 子项居中 | `686-707` |
| 昵称 | `width('100%') + textAlign(TextAlign.Center)` | `709-716` |
| `ID·性别·IP` | 同上 | `718-724` |
| 简介 | 同上（另加 `padding left/right 36` 收窄行宽） | `726-735` |
| 统计行（关注 · 粉丝 · 获赞） | `Row().width('100%').justifyContent(FlexAlign.Center)` | `737-758` |

**结论：竖屏（含手机）零改动** —— 用户要求的形态现状即满足。多列改造后的三条保真约束：

1. **头部必须留在通栏位**（`ListItemGroup.header`），**永不进列** —— 否则居中基准从「内容区中线」变成「某一列的中线」，视觉上会跳到左列中央（A 类错位）。
2. **居中基准 = 列表内容区宽（列表宽 − 左右 `Spacing.lg` 16）**：多列改造**不得**改这两个 padding（§6.2 第 2 步「左右外边距单一来源」）；也不得给 Header 单独加左右 padding。
3. **横屏不引入 `Content.maxWidth`（推荐）**：横屏 3 列时 Header 通栏，居中基准 = 1024 − 32 = 992vp，文字因居中而对称、不显错位。若真机判「信息带过于空旷」再启用限宽，写法必须是 §4.7 S-A 同款（`Row().justifyContent(FlexAlign.Center) > Column().constraintSize({ maxWidth: Content.maxWidth })`），且**只包 Header 内层、不得只包某一行文字**（否则文字中线与卡片中线错开 = A4 类）；令牌 `Content.maxWidth` 依赖 §4.6 H-B。→ **已拍板 #2：本期不引入**（保持不限宽居中）；真机若判「信息带过于空旷」再按上述 §4.7 S-A 同款写法启用。

**U-B 列数与形态判定（新增判定，不动既有 `isWideScreen`）**

```ts
// 复用既有 currentWidth（122）作为 pageWidth；新增 pageHeight 与判据函数
@State pageHeight: number = 800;

private isLandscape: boolean = false;
private readonly isWideFormDevice: boolean =
  deviceInfo.deviceType === 'tablet' || deviceInfo.deviceType === '2in1' || display.isFoldable();

/** 内容列数：手机恒 1；平板竖 2；平板横 3（与 §4.2 / §4.4 / §4.8 同口径） */
private profileColumns(): number {
  if (!this.isWideFormDevice) return 1;      // 手机含横屏 / 分屏 / 自由多窗 → 恒 1（D4）
  if (this.currentWidth < 600) return 1;     // 折叠态 / 窄窗
  return this.isLandscape ? 3 : 2;           // 平板横 3 / 竖 2
}
```

- **挂点（单一）**：既有 `ProfileShell().onAreaChange`（`540-544`）内追加 `this.pageHeight` 与 `this.isLandscape = width > (newValue.height as number)` —— 与 `currentWidth` 同点回填（D5：写入本身不算回归）。
- **首帧初值**：`aboutToAppear`（`142`）用 `display.getDefaultDisplaySync()` 同步取窗口宽高（现状 `currentWidth` 初值 360 只在 `onAreaChange` 纠正 → **冷启动平板横屏首帧按 1 列渲染、次帧跳 3 列**）。需补 `display` import（本页现只 import `window, LengthMetrics`，`30`）。
- ⚠️ **`isWideScreen`（840）不得复用为列数判据**：它的语义是「底栏胶囊封顶 480」（`516-522`），与 §4.2 / §4.4 / §4.8 的 600 口径不同；混用会让折叠屏展开（750）判成单列。**两套判据并存、各司其职**（改动只新增 `profileColumns()`，`pillWidth()` / `isWideScreen` 一行不动）。
- **不引入 `cardColumns`**（§4.2 决策 6）：本页 `PostCard` / `LikeCard` 都是**本页私有 `@Builder`**，不吃全局标记 → 无 D1 / D6 残留面。

**U-C 帖子 Tab 多列（`PostTabContent`，`840-862`）**

```ts
List({ space: Spacing.sm, scroller: this.postsScroller }) {
  if (this.profileColumns() <= 1) {
    // 【单列分支】现状结构一字不动：Header ListItem + ForEach ListItem + 尾部 160 ListItem
  } else {
    // 【多列分支】通栏项迁进 ListItemGroup 的 header / footer（lanes 下恒整行宽）
    ListItemGroup({ header: this.Header(), footer: this.ListBottomSpacer() }) {
      ForEach(this.sortedPosts(), (item: PersonalContentItem) => {
        ListItem() { this.PostCard(item) }
      }, (item: PersonalContentItem) => `${item.tid}_${item.id}`)
    }
  }
}
.lanes(this.profileColumns(), Spacing.sm)   // 列数, 列间距
.width('100%')
.layoutWeight(1)
.padding({ left: Spacing.lg, right: Spacing.lg })   // 左右外边距单一来源，不变
.scrollBar(BarState.Off)
.edgeEffect(EdgeEffect.Spring)
.onReachEnd(() => { this.loadPostsMore(); })
```

- **通栏项（3 处，必须全迁）**：帖子 Tab 的 `Header`（`842-845`）与尾部 160 占位（`853-855`）、关注吧 Tab 的尾部 160 占位（`940-942`）。`lanes` 生效后**所有非数据 `ListItem` 都只占 1 格**（§4.3 已实证）→ 不迁就会和卡片并排。
- **新增两个 `@Builder`**：`ListBottomSpacer()`（内容 = 现有 `Column().width('100%').height(160)`，两个 Tab 共用）与 `LikeListSpacer()`（可复用同一个）。
- ⚠️ **必须保持 `List.sticky` 默认值（`StickyStyle.None`）**：`ListItemGroup.header` 一旦配上 `List.sticky(StickyStyle.Header)` 就会**吸顶**，`Header` 从「随内容滚动」变成「钉在顶部」= 行为回归。本页现状是随内容滚，**不许顺手打开 sticky**。
- **列间距 = 行间距 = `Spacing.sm`(8)**：本页 `List({ space: Spacing.sm })`，护栏是「列间距恒等于行间距」（§4.3 取 `Spacing.md` 是因为那边流间距是 md；两页各自与自身 `space` 同源，不互相照抄）。
- **不使用 `lanes` 第三参 `margin`**：会与 List 的 `padding` 叠加 → 左右外边距不再是单一来源。
- **末行不满**：`lanes` 下每格宽恒 = 列宽 → **不拉伸、无需补空位**（A2 不适用，也不写 `blankSlots()`）。
- 其余零改动：`sortedPosts()` 重排、`onClick` 预取跳详情、分页（`loadPostsMore`）、`postsState` 三态、`fontScale` 联动、`accessibilityText`。
- **骨架屏（`832`）保持现状**：`ThreadListSkeleton({ count: 5 })` 单列铺排（Loading 期短，不做按列骨架屏；同 §4.9 待拍板点 2）→ **已拍板 #3：不做**（保持单列）。

**U-D 关注吧 Tab 多列（`LikeTabContent`，`933-949`）**

同款：`.lanes(this.profileColumns(), Spacing.sm)`；本 Tab **无 Header** → 只用 `ListItemGroup({ footer: this.ListBottomSpacer() }) { ForEach(likes, ...) }`（无 `header`）；`likesScroller` / `onReachEnd(loadLikesMore)` / 三态（`924-931`）零改动。

**U-E 顶栏 / 让位 / 排序菜单 / 弹窗（全部零改动）**
- 顶栏官方槽位 `TopTitleBar` / 兜底 `TopBar`：几何（height 98 / `padding top 44 + bottom 10` / 左右 `Spacing.lg` / 44 圆钮 / 关注胶囊）**本次不动** → 无 A3 双路径错位。
- 内容让位 = `Header` 的 `padding top 98 + Spacing.md`（`761`）→ Header 仍通栏置顶，让位不变。
- 排序菜单锚点（`608-618`）在页面 `Stack` 层、不在列表内 → 列数无关。
- 关注 / 拉黑确认弹窗居中 → 列数无关。

**U-F 底部悬浮分段 Tab 让位（C2 单独确认）**
- 现状：官方浮槽 `barHeight 74` + `barBottomMargin 30`；胶囊宽 `pillWidth()`（横屏 1024 → 480 居中，左右各 272vp）；兜底 `BottomSegTabs` 高 74 / 圆角 37 / `margin bottom 30`。
- 列表底部恒 **160 通栏占位**（多列后进 `ListItemGroup.footer`）→ 让位 74 + 30 + 手势区（≈34）= 138 < 160 ✅ **安全**。
- 横屏三列 + 胶囊 480 居中：只压中间列底部，而该处正是 160 通栏占位区 → **不遮内容** ✅。
- **执行红线**：160 占位**随列数不变**（既不放大小、也不缩小）；本页数值与 §4.9（160）/ §4.10（20）**各自独立、不得互抄**。

**列宽核算（`lanes` 均分，列间距 `Spacing.sm` = 8，左右各 `Spacing.lg` = 16）**

| 形态 | 列表可用宽 | 列数 | 列宽 | 评价 |
|---|---|---|---|---|
| 手机竖 360 | 328 | 1 | 328 | **基线，逐像素不变** |
| 手机横 780 | 748 | 1 | 748 | 形态闸门恒 1 列（D4）|
| 折叠展开竖 750 | 718 | 2 | 355 | 略宽于手机 ✅ |
| 平板竖 1024 | 992 | 2 | 492 | ✅ 舒适 |
| 折叠展开横 750 | 718 | 3 | 234 | ⚠️ 偏窄（C 类，见风险自检）|
| 平板横 1024 | 992 | 3 | 325 | ✅ 可用 |
| 平板横 1280 | 1248 | 3 | 410 | ✅ 舒适 |
| 窄窗 / 分屏 < 600 | — | 1 | — | 现状单列 ✅ |

**涉及改动点**
- `UserProfile.ets`：U-B（新增 `pageHeight` / `isLandscape` / `isWideFormDevice` / `profileColumns()`；`onAreaChange` 补回填；`aboutToAppear` 同步取宽高；补 `display` import）、U-C（`PostTabContent` 加 `.lanes()` + 通栏项迁 `ListItemGroup` + 单列分支保持原结构）、U-D（`LikeTabContent` 同款）、新增 2 个 `@Builder`（`Header` 复用 / `ListBottomSpacer`）。
- **不改**：`Header()` 全部几何（含居中写法与 `padding{left/right 16, top 98+12}`）、`PostCard` / `LikeCard` 内部、`SegButton` / `FloatingSegSlot` / `BottomSegTabs` / `FloatingTabsShell` / `LegacyShell` / `TopBar` / `TopTitleBar`、三态视图、两个弹窗、排序菜单锚点、`pillWidth()` / `isWideScreen`、`bottomSafeHeight` 逻辑、`sortedPosts()` / `mergeItems()` / 分页 / 缓存。
- **执行红线**：① Header 居中与左右 16 **不动**；② 底部 160 占位**不变**；③ `List.sticky` 保持 `None`；④ **列 = 1 走原裸 `ListItem` 结构、不套 `ListItemGroup`**（D2）；⑤ 不用 `lanes` 第三参 `margin`。
- `common/Theme.ets`：`isWideFormDevice` / `Breakpoint.sm` 判据令牌（§4.6 H-B，**未落地**）。
- 文档：本节、§三 第 12 项、§6.1 范围提醒（**例外五**）+ A1 / A5 / A6 / C2 表项、§6.2 二级页清单 + D3 行 + 已过检记录、顶部更新日志。
- **另记（非布局，H-F 类）**：`bottomSafeHeight`（`119` 初值 / `178` 赋值）**全页无读取点** → `initSafeArea()` 的读数未参与任何几何，底部让位实际由固定 160 承担。清理属可选（不阻塞本节多列判定），若清理须与「横屏矮视口让位复核」（§6.1 B3）一并看。

**前置依赖**：与 §4.7~§4.10 相同 —— `isWideFormDevice` / 600 阈值待 §4.6 H-B 收口；**不依赖** §4.2 决策 6（`cardColumns`）。

**断点 / 阈值**
- 多列档：`isWideFormDevice && currentWidth ≥ 600`；横竖屏：`currentWidth > pageHeight`
- 列数：手机 **1** / 平板竖 **2** / 平板横 **3**
- 列间距 = 行间距 = **`Spacing.sm`(8)**；左右外边距 = **`Spacing.lg`(16)**（单一来源，两边各一份）
- 底部留白 = **160**（通栏占位，随列数不变）
- 顶部让位 = **98 + `Spacing.md`(12)**（Header 自带，不变）

**风险与回归项**
1. **通栏项迁移**（A1）：3 处必须进 `ListItemGroup.header/footer`；并保持 `sticky` 默认 —— 否则 Header 吸顶。
2. **首帧列数跳变**（A5）：`aboutToAppear` 同步取宽高；`onAreaChange` 兜底。
3. **`lanes` 行内高度差留白**（A6）：帖子卡最大差 ≈ 2 行 ≈ 38vp（小于 §4.3 已接受的 54vp）→ 接受；若不可接受只能换 `WaterFlow`（代价大）。
4. **窄列截断**（C3）：折叠展开横屏 750 下三列 234vp → 吧卡文字列 ≈ 124vp（48 头像 + 12 间距 + chevron 18 + 左右 32）→ 吧名 / 简介截断明显。规避候选：① 横 3 门槛提到 840（与 §4.2 / §4.4 / §4.8 的 600 口径冲突，须并入 §4.8 已记的「口径收口项」统一裁决）；② 保留 3 列 + 接受截断（现有字段均已配 `maxLines` + `ellipsis`）→ **推荐 ②**。
5. **`ListItemGroup` 内卡片行间距**：落地后确认 group 内 `ListItem` 间距仍为 `Spacing.sm`（若丢失 → 用 `ListItemGroup.space(Spacing.sm)` 补），列为落地验证项。
6. **`lanes(1)` 等价性**：单列档下 `.lanes(1, Spacing.sm)` 是否与「不设置 `lanes`」逐像素一致 → 落地后真机 / 预览器确认（保守替代 = 双分支写两份 List，代码变长但零风险）。
7. **切 Tab 滚动位置 / 分页**：`scroller` 与 `onReachEnd` 零改动；列数变化后的滚动位置属既有项（同 §4.6 H-G-2），落地后复测。
8. **手机零回归**：见下节。

**手机端零回归核对（2026-09-13 → 结论：不影响）**

| 改动项 | 手机实际路径 | 是否改变几何 |
|---|---|---|
| `profileColumns()` | 首行 `!isWideFormDevice` → 1（**手机横屏 780 也是 1 列**）| 否 |
| 新增 `pageHeight` / `isLandscape` + `onAreaChange` 回填 | 只写入状态、不被单列分支读取（D5）| 否 |
| `aboutToAppear` 同步取宽高 | 纯新增（现状无页宽初值），不参与单列几何 | 否 |
| **`.lanes(1, Spacing.sm)`** | 与「不设置 `lanes`」等价（**须落地验证**，见风险 6）；未验证前以双分支兜底 | 否（待验证）|
| 通栏项处理 | **列 = 1 走原裸 `ListItem` 结构**（Header 首项 / 尾部 160），**不套 `ListItemGroup`**（D2）| 否 |
| `List` 的 `space` / `padding` / `edgeEffect` / `scrollBar` / `onReachEnd` | 全部保留原值 | 否 |
| `ThreadListSkeleton` 2 处 | 保持 `count: 5`、单列铺排（不加 `columns` 入参）| 否 |
| `Header()` / `PostCard` / `LikeCard` | 零改动（含居中写法、圆角 26、`padding`）| 否 |
| 顶栏双路径 / 排序菜单 / 弹窗 / 分页 / 缓存 | 零改动 | 否 |

**手机验收基线**：手机竖 360 单列 —— 列表可用宽 328、卡片宽 = 328、`space` 行间距 8、左右 `Spacing.lg` 16、底部占位 160、`Header` 居中基准 = 328 中线、骨架屏 5 条单列 —— **全部逐像素不变**。

**风险自检（§6.2）**
- **A 错位 → 有 3 处**：① **A1 通栏项只占 1 格** —— 本页 3 处通栏项（帖子 Tab 的 `Header` + 尾部 160、关注吧 Tab 的尾部 160）必须迁进 `ListItemGroup.header/footer`，并**保持 `List.sticky` 默认 `None`**（否则 Header 吸顶）；② **A5 首帧列数跳变** —— `currentWidth` 初值 360 只在 `onAreaChange` 纠正，冷启动平板横屏会「先 1 列再 3 列」→ `aboutToAppear` 用 `display.getDefaultDisplaySync()` 同步取宽高；③ **A6 行内高度差留白** —— `lanes` 固有（帖子卡标题 / 摘要各 `maxLines(2)`，最大差 ≈ 38vp），与 §4.3 选项 B 同源、代价更小 → 接受。**A2 末行拉伸不适用**（`lanes` 列宽恒定，无需 `blankSlots()`）；**A3** 顶栏双路径几何本次不动；**A4** 不引入 `Content.maxWidth`（**已拍板 #2：横屏头部不限宽**，本条不再是可变项）。三处规避均已到可落地粒度。
- **B 出屏 → 无**：`lanes` 均分列宽（非像素）、卡片 `width('100%')`、无横向滚动；`expandSafeArea` 只扩上 / 下（`539` / `594` / `660`）；`position` 仅排序菜单锚点（页面层、相对定位）。
- **C 重叠 → 有 1 处**：折叠展开横屏 750 下 3 列 → 列宽 ≈ 234vp、吧卡文字列 ≈ 124vp，吧名 / 简介截断明显（C3 窄列截断；帖子卡因标题 / 摘要 `maxLines(2)` + `ellipsis` 无溢出风险）。**已拍板 #1：接受截断**（口径沿用 `600`），并把「600 vs 840」并入 §4.8 已记的口径收口项 —— 后续若判定不可接受，只改判据层一处（不新增第三套阈值）。**C2 底部悬浮胶囊让位 → 无**：74 + 30 + 手势区 ≈ 138 < 160 通栏占位，横屏胶囊 480 居中只压中间列底部、该处正是占位区；160 随列数不变。
- **D 手机回归 → 无**：见上表 —— 手机（含横屏 / 分屏 / 自由多窗）恒 1 列；列 = 1 走原裸 `ListItem` 结构、不套 `ListItemGroup`（D2）；`ThreadListSkeleton` 两处不加 `columns`（D3 面按「默认 1」处理，**不修改该组件**）；本页不写 `cardColumns`（无 D1 / D6 残留面）；`onAreaChange` 只回填状态（D5）。**两条落地验证项**：`lanes(1)` 等价性、`ListItemGroup` 内行间距 → 未验证前按风险 6 用双分支兜底。

**待拍板点（2026-09-13 已按推荐值全部拍板 → 转「已确认」，下表「拍板结果」列即结论）**

| # | 点 | 拍板结果（原推荐值） | 理由 / 备选 |
|---|---|---|---|
| 1 | 列数口径（竖 2 / 横 3 的门槛） | **采用 `600`**（同 §4.2 / §4.4 / §4.8） | 与全站一致；折叠展开横屏 750 下三列偏窄（234vp）→ 若判不可接受，备选 = 横 3 门槛提至 840（须与 §4.8 已记的「两套阈值收口项」一并裁决，不新增第三套）|
| 2 | 横屏头部是否限宽居中 | **不限宽**（现状居中已足）| 引入 `Content.maxWidth` 需头部与卡片共用同一限宽容器（否则 A4 咬合错位），且 §4.7 S-A 的限宽是为「搜索框过长」，本页是「文字居中」，性质不同 |
| 3 | 骨架屏按列铺 | **不做** | Loading 期短；`ThreadListSkeleton` 跨 3 页共 5 处调用点，本页 2 处保持现状（同 §4.9 待拍板点 2）|
| 4 | `lanes` 行内高度差留白 | **接受**（≈ ≤38vp）| 与 §4.3 选项 B 同源、差值更小；不接受则须换 `WaterFlow`（丢 `scroller` / `onReachEnd`）|
| 5 | 列间距取值 | **`Spacing.sm`(8)**（= 本页行间距）| 护栏「列间距恒等于行间距」；与 §4.3 取 md(12) 不同源自各自 `space` |

**状态**：方案**已确认**（2026-09-13 用户指示形态「用户信息居中 + 下内容竖 2 / 横 3」→ 方案已出；**同日用户「按推荐值拍板，后续有需要才改」→ 上表 #1~#5 全部按推荐采纳**：口径沿用 `600`〔不新增第三套〕/ 横屏头部**不限宽**居中 / 骨架屏**不按列铺** / **接受** `lanes` 行内高度差留白 / 列间距取 `Spacing.sm`(8)）。**代码尚未执行**，受前置依赖阻塞（判据令牌待 §4.6 H-B 落地）—— **本轮不开工，等待前置**。**两条落地验证项**（拍板不变，落地后仍需实测）：`lanes(1)` 等价性（不成立则 §4.11 / §4.12 **两页一起改「双 `List` 双分支」**）、`ListItemGroup` 内行间距是否仍生效。

### 4.12 个人内容（`pages/PersonalContent.ets`）

> 用户 2026-09-13 批注：「那就采用同一方案」→ 本节与 §4.11 **同范式**（容器保留 `List` + `.lanes()`），差异项全部单独标注，**两节数值与理由不得互相照抄**。

> **⚠️ 2026-09-14 用户新拍板推翻 lanes 方案 → 已落地瀑布流**：用户要求「我的帖子 / 我的点赞 / 浏览历史三个界面采用首页一样的瀑布流，竖屏 3 列 / 横屏 4 列」→ 原「`List + lanes` 竖 2 / 横 3」**作废**，改**列内独立堆叠 + 方案 B 带滞回最短列分桶**（与 §4.9 / §4.10 / §4.8 T-D / 收藏页同款范式）。落地内容：① 形态判定从零建（§4.12 原记红线兑现）：`isWideFormDevice`（tablet/2in1/isFoldable，T-B 同款）+ `pageWidth` / `pageHeight` / `isLandscape`（`refreshFormMetrics()`：`aboutToAppear` 首帧 + 根 Stack `onAreaChange` 兜底）+ `currentWidth`；`pcColumns()` = 闸门 + `>= Breakpoint.sm(600)` + 横 4 / 竖 3。② 多列档 `List` 结构：外层 ForEach **只遍历列索引**（key `pcol_${i}` 稳定复用列容器），内层**直读状态源** `pcColumnsData()[colIdx]`（收藏页五轮教训：不用外层传入 col）；新增卡片 160ms 淡入。③ `pcColumnsData()` 方案 B（阈值 `PERSONAL_COL_BALANCE_THRESHOLD=240`）+ `estimateContentCardHeight()`（ContentCard 无图片区：标题/摘要 ≤2 行 + 信息行，高度差 ≤80vp → 滞回 240 下几乎恒为纯轮转）。④ 预加载分档：多列档 `onScrollIndex` 改「最后一列可见」触发 `loadMore`（ListItem 数 = 列数，原「距末 5 项」判据失效；`loadingMore` 防抖兜底），单列档原样。⑤ `List` 容器 / `onReachEnd` / padding / 沉浸挂点 / 三态视图 / 4 mode 语义零改动；`collections` mode 无入口但共用同一容器逻辑，随多列生效。**待真机复验**（竖 3 / 横 4 瀑布流 / 长列被补位 / 翻页不跳位 / **卡内底行窄列溢出复查**〔原 §4.12 红线〕/ 手机单列逐像素不变）。

**定位与命名澄清（2026-09-13）**
- 本页 = 「我的」页三个入口（我的帖子 / 我的点赞 / 浏览历史）进去的内容归档页（`@Entry` 二级页）；全工程 `pages/PersonalContent` 的 `pushUrl` **只有 `MineTab.ets:117` 一处**。
- 与 §4.11 不是同一页：本页**没有用户信息区**（无头像 / 昵称 / 统计），也**不能看别人**（`accountId` 取 `AuthManager.getInstance().getUser()?.userId`）。两者重叠面 = 同一套帖子卡（`UserProfile` 的 `PostCard` 注释即写明「复用 `PersonalContent.ContentCard` 样式」）与同一取帖接口。
- `collections`（我的收藏）mode **全工程无入口**（MineTab 只发 `posts` / `likes` / `history`）→ 属遗留 / 待接入分支；本次适配不改变其行为（4 个 mode 共用一个 `List`，列数逻辑一份）。

**适配需求（用户指示，2026-09-13）**
1. 「采用同一方案」= 与 §4.11 同范式：容器保留 `List`、加 `.lanes()` 做多列；手机 1 / 平板竖 2 / 平板横 3。
2. §4.11 的「用户信息居中」在本页**不适用**（本页无用户信息区，顶栏是「返回圆钮 + 居中标题」的通用形态）。
3. 手机端逐像素不变（§6.2 第 7 步）。

**改动前现状（已核实，2026-09-13）**

| 项 | 现值 | 位置 |
|---|---|---|
| 容器形态 | **`List()` 无参数** → **无 `space`、无 `scroller`**（页内唯一列表，4 个 mode 共用） | `160-172` |
| 列表属性 | `.layoutWeight(1)` / `.padding({left: Spacing.lg, right: Spacing.lg, top: 0, bottom: Spacing.xl})` / `.scrollBar(Off)` / `.clip(false)` / `.expandSafeArea([SYSTEM],[TOP,BOTTOM])` / `.overlay(BottomFadeOverlay)` / `.blendMode(SRC_OVER, OFFSCREEN)` / `.onReachEnd` / `.onScrollIndex` | `173-187` |
| 形态判定 | **完全没有**：无 `pageWidth` / `currentWidth` / `isWideScreen` / `onAreaChange` / `deviceInfo` / `display`（全文件检索 0 命中） | — |
| 顶部让位 | 首项 `ListItem { Column().width('100%').height(98) }`（空占位，随内容滚动） | `161-164` |
| 尾部占位 | **无**（底部留白走 List 的 `padding bottom`） | `174` |
| 数据行 | `ForEach(this.items, …)`，key = `item.tid`（**仅 tid**；注释说明用 `${id}_${tid}` 会因 id 在本地缓存 / 云端不一致而换 key、`ListItem` 销毁重建闪现） | `165-171` |
| 卡片 | `ContentCard`：`Column({space: 6})`（标题 `maxLines(2)` / 摘要 `maxLines(2)` / 底行 = 吧名 + `Blank()` + `${replyNum} 回复` + 时间〔`margin left 8`〕）+ `.padding(Spacing.lg)` + 圆角 26 + **`.margin({bottom: Spacing.md})`** | `390-436` |
| 行间距来源 | **卡片自带 `margin bottom 12`**（`List` 无 `space`） | `427` |
| 三态 | `LoadingView` / `ErrorView` / `EmptyView`（`layoutWeight(1)`），与 `List` 是 **`Stack` 内同级分支**（不进列表 → 天然通栏） | `153-158` |
| 悬浮层 | **无底部悬浮层**（无底栏 / 无分段 Tab）；仅顶部过渡栏（槽位 `PersonalTitleBar()` / 兜底 `TopBar()`）与 `BottomFadeOverlay`（挂在 **List 的 `.overlay()`** 上，非 ListItem） | `178` / `190-193` / `331-388` / `438-449` |
| 顶栏 | 官方槽位 `PersonalTitleBar()`（`PERSONAL_CONTENT_TITLE_BAR_HEIGHT = 98`）/ 兜底 `TopBar()`（height 98）；判据 `PERSONAL_CONTENT_OFFICIAL_TITLE_BAR && this.materialSupported` | `40-43` / `201-221` |
| 分页 | `onReachEnd` + `onScrollIndex`（`end >= items.length - 5` 提前预取）；仅 `likes` / `collections` 可翻页（`posts` 单页、`history` 纯本地） | `180-187` / `294-321` |
| mode | `posts` / `likes` / `collections` / `history`（`PersonalMode`），共用一个 `List` 与一套列表属性 | `27-32` / `89-122` |

**选型结论：保持 `List` + `.lanes(列数, Spacing.md)`，顶部 98 占位迁 `ListItemGroup.header`** —— 与 §4.11 同范式（也与 §4.3 收藏页「改动二」同族）。

| 候选 | 取舍 |
|---|---|
| **A（采用）`List.lanes()`** | 容器零改动（`padding` / `overlay` / `blendMode` / `expandSafeArea` / `onReachEnd` / `onScrollIndex` 全保留）；列宽系统均分（无像素列宽）；末行不被拉伸 → **无需 `blankSlots()`** |
| B 换 `Scroll + Column` 行分组 / 列内堆叠 | 会丢 `overlay` + `blendMode` 装饰链、`onReachEnd`、虚拟滚动与 `onScrollIndex` 预取 → **代价远大于收益** |
| C `WaterFlow` | 同上；且本页卡片高度差极小（标题 / 摘要各 2 行）→ **不值得** |

**PC-A 列数与形态判定（本页从零建 —— §4.11 那套状态本页一个都没有）**

```ts
@State pageWidth: number = 360;        // 首帧由 aboutToAppear 同步赋值
@State pageHeight: number = 800;
private isLandscape: boolean = false;

/** 大屏形态设备：平板 / 2in1 / 折叠屏（折叠屏 deviceType 为 'phone'，必须单独识别） */
private readonly isWideFormDevice: boolean =
  deviceInfo.deviceType === 'tablet' || deviceInfo.deviceType === '2in1' || display.isFoldable();

/** 内容列数：手机恒 1；平板竖 2；平板横 3（与 §4.2 / §4.4 / §4.8 / §4.11 同口径） */
private personalColumns(): number {
  if (!this.isWideFormDevice) return 1;    // 手机含横屏 / 分屏 / 自由多窗 → 恒 1（D4）
  if (this.pageWidth < 600) return 1;      // 折叠态 / 窄窗
  return this.isLandscape ? 3 : 2;
}
```

- **挂点（单一）**：`ContentLayer()` 根 `Stack`（`152`）新增 `.onAreaChange((_, newValue) => { … })` 回填 `pageWidth` / `pageHeight` / `isLandscape`（D5：写入本身不算回归）。
- **首帧初值**：`aboutToAppear`（`71`）用 `display.getDefaultDisplaySync()` 同步取宽高（`d.width` / `d.height` 为 px，比较序与 vp 一致，同 §4.1）→ **需补 `deviceInfo` / `display` import**（本页现只 import 业务模块 + `Theme` / `CommonComponents`，`19-25`）。
- 本页**没有** §4.11 那种「`isWideScreen` 840 服务底栏胶囊封顶」的既有判据 → **不存在双判据冲突**，`personalColumns()` 是唯一列数来源。
- **不引入 `cardColumns`**（`ContentCard` 为本页私有 `@Builder`）→ 无 D1 / D6 残留面。

**PC-B 列表多列（`ContentLayer()`，`160-187`）**

```ts
List() {
  if (this.personalColumns() <= 1) {
    // 【单列分支】现状结构一字不动：98 占位 ListItem + ForEach（无尾部占位）
  } else {
    // 【多列分支】唯一通栏项 = 顶部 98 占位，迁进 ListItemGroup.header
    ListItemGroup({ header: this.TopSpacer() }) {
      ForEach(this.items, (item: PersonalContentItem) => {
        ListItem() { this.ContentCard(item) }
      }, (item: PersonalContentItem) => item.tid)
    }
  }
}
.lanes(this.personalColumns(), Spacing.md)      // 列数, 列间距（= 本页行间距 12）
.layoutWeight(1)
.padding({ left: Spacing.lg, right: Spacing.lg, top: 0, bottom: Spacing.xl })   // 不变
.scrollBar(BarState.Off)
.clip(false)
.expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
.overlay(this.BottomFadeOverlay())
.blendMode(BlendMode.SRC_OVER, BlendApplyType.OFFSCREEN)
.onReachEnd(() => { this.loadMore(); })
.onScrollIndex((start: number, end: number) => { if (end >= this.items.length - 5) { this.loadMore(); } })
```

- **通栏项只有 1 处**：顶部 98 占位 → 新增 `@Builder TopSpacer() { Column().width('100%').height(98) }`（几何与现状逐项相同）。本页**没有尾部占位**（这是与 §4.11 的「3 处」最大的不同；底部留白在 List 的 `padding` 上，多列下自动整行生效）。
- ⚠️ **`onScrollIndex` 的 `end` 语义在多列分支下必须落地验证（本页独有风险）**：单列分支的 `List` children = 「98 占位 + N 个数据项」，`end` 是 child 索引（含占位偏移）；多列分支的 children 变成「1 个 `ListItemGroup`」→ 若 `end` 退化为**组索引**（恒 0），则 `end >= items.length - 5` 恒 false，**提前预取失效**，只剩 `onReachEnd` 兜底（用户滑到边界才加载 → 「边界回弹瞬间插入新内容」的抽搐观感回归）。落地验证；若不成立，兜底写法二选一：① 多列分支放宽阈值（宁可提前取）；② 多列分支只依赖 `onReachEnd` + 改用「渲染到数据尾部即取下一页」的等价判据。**已拍板 #5：兜底取 ①**（② 作为次选备存）。
- **`List.sticky` 保持默认 `None`**：现状未设置；多列分支新增 `ListItemGroup` 后**不得**顺手打开 `StickyStyle.Header`（否则 98 占位会变成吸顶条）。
- **列间距 = `Spacing.md`(12) = 本页行间距**（卡片 `margin bottom 12`、`List` 无 `space`）。⚠️ **与 §4.11 的 `Spacing.sm`(8) 不同源、不得互抄**：§4.11 的行间距来自 `List({space: Spacing.sm})`，本页来自卡片 `margin`，各自与自身行间距同源（护栏「列间距恒等于行间距」）。
- **不使用 `lanes` 第三参 `margin`**（会与 List 的 `padding` 叠加 → 左右外边距不再是单一来源）。
- **末行不满**：`lanes` 下每格宽恒 = 列宽 → **不拉伸、不需要补空位**（A2 不适用，不写 `blankSlots()`）。
- 其余零改动：`mergeItems` / `appendUnique` / `sortItems` / `loadItems` / `loadLikes` / `loadMore`（`likesPage` / `hasMore`）、缓存 key、`fontScale` 联动、`onPageShow` 重建 tick。

**PC-C 顶栏 / 装饰层 / 三态（零改动）**
- 顶栏两条路径（官方槽位 `Navigation.title` / 兜底悬浮 `TopBar()`）几何（98 / `padding top 44 + bottom 10` / 左右 `Spacing.lg` / 返回圆钮 44 / 标题 `fontSize 19` 居中）**本次不动** → 无 A3 双路径错位。
- `BottomFadeOverlay` 与 `blendMode(SRC_OVER, OFFSCREEN)` 挂在 **List 自身**（`178-179`），不在 ListItem 上 → 列数无关，一字不改。
- 三态视图是 **List 的同级分支**（`153-158`）→ 天然「通栏」，不进网格。
- 顶部 98 让位由 `TopSpacer` 通栏承担（多列下仍整行）→ 沉浸顶栏不会被卡片穿过。

**PC-D 底部让位（C2 单独确认）**
- 本页**无底部悬浮层**（二级页、无底栏、无分段 Tab）→ 无任何悬浮元素需要让位。
- 底部留白 = **`Spacing.xl`(20)**，写在 List 的 `padding bottom` 上，随列数不变。
- **执行红线**：① **不得照抄 §4.11 的 160**（会多出 140vp 空白）；② **不得照抄 §4.10 的「用户拍板回退值」表述** —— §4.10 的 20 有真机回退背景，本页 20 是原始值，**数值相同、理由不同源**。

**列宽核算**（`lanes` 均分，列间距 `Spacing.md` = 12，左右各 `Spacing.lg` = 16，卡片内边距 32）

| 形态 | 列表可用宽 | 列数 | 列宽 | 卡内文本宽 | 评价 |
|---|---|---|---|---|---|
| 手机竖 360 | 328 | 1 | 328 | 296 | **基线，逐像素不变** |
| 手机横 780 | 748 | 1 | 748 | 716 | 形态闸门恒 1 列（D4）|
| 折叠展开竖 750 | 718 | 2 | 353 | 321 | ✅ |
| 平板竖 1024 | 992 | 2 | 490 | 458 | ✅ 舒适 |
| 折叠展开横 750 | 718 | 3 | 231 | 199 | ⚠️ 底行偏紧（C 类，见风险 5）|
| 平板横 1024 | 992 | 3 | 323 | 291 | ✅ 可用 |
| 平板横 1280 | 1248 | 3 | 408 | 376 | ✅ 舒适 |
| 窄窗 / 分屏 < 600 | — | 1 | — | — | 现状单列 ✅ |

**涉及改动点**
- `PersonalContent.ets`：PC-A（新增 `pageWidth` / `pageHeight` / `isLandscape` / `isWideFormDevice` / `personalColumns()`；根 `Stack` 新增 `onAreaChange`；`aboutToAppear` 同步取宽高；补 `deviceInfo` / `display` import）、PC-B（`List` 加 `.lanes()`、加显式单列 / 多列双分支、新增 `@Builder TopSpacer()`）；PC-C / PC-D 零改动。
- **不改**：`ContentCard`（含 `margin bottom 12` / 圆角 26 / `padding(Spacing.lg)` / 底行三 `Text`）、`TopBar` / `PersonalTitleBar` / `BottomFadeOverlay`、三态视图、`Navigation` 槽位与兜底两路径、`List` 的 `padding` / `overlay` / `blendMode` / `expandSafeArea` / `scrollBar` / `clip` / `layoutWeight`、`loadItems` / `loadLikes` / `loadMore` / `mergeItems` / `appendUnique` / 缓存、4 个 mode 语义。
- `common/Theme.ets`：`isWideFormDevice` / `Breakpoint.sm` 判据令牌（§4.6 H-B，**未落地**）。
- 文档：本小节、§三 第 11 项、§4.11 标题与适用范围澄清、§6.1 **例外六** + A1 / A5 / A6 / C2 表项 + 「多列写法共三套」第 ③ 条、§6.2 二级页清单（底部让位数值清单扩为四页）+ 已过检记录、顶部更新日志。

**前置依赖**：与 §4.7~§4.11 相同 —— `isWideFormDevice` / 600 阈值待 §4.6 H-B 收口；**不依赖** §4.2 决策 6（`cardColumns`）。

**断点 / 阈值**
- 多列档：`isWideFormDevice && pageWidth ≥ 600`；横竖屏：`pageWidth > pageHeight`
- 列数：手机 **1** / 平板竖 **2** / 平板横 **3**
- 列间距 = **`Spacing.md`(12)** = 本页行间距（卡片 `margin bottom`）；左右外边距 = **`Spacing.lg`(16)**（单一来源）
- 底部留白 = **`Spacing.xl`(20)**（在 List 的 `padding` 上，随列数不变）
- 顶部让位 = **98**（`TopSpacer` 通栏，随列数不变）

**风险与回归项**
1. **`onScrollIndex` 语义变化 → 提前预取可能失效**（本页独有，见 PC-B）→ 落地验证 + 兜底写法（**已拍板 #5：兜底取 ①「多列分支放宽阈值」**）。
2. **通栏占位迁移**（A1）：顶部 98 占位必须进 `ListItemGroup.header`；`sticky` 保持默认 `None`。
3. **首帧列数跳变**（A5）：本页**没有任何形态初值**，不补 `aboutToAppear` 同步取宽高就必然「先 1 列再 3 列」。
4. **`lanes` 行内高度差留白**（A6）：标题 / 摘要各 `maxLines(2)`，最大差 ≈ 2 行 ≈ 38vp → 接受（同 §4.11）。
5. **窄列底行横向溢出**（C3）：折叠展开横屏 750 三列时卡内文本宽 ≈ 199vp → 底行（吧名 + 回复数 + 时间）在长吧名时挤压：`Row` 子项默认 `flexShrink 0`、卡片**无 `clip`**、且 `List` 是 `.clip(false)` → **溢出会盖到右列卡片**（比「文字截断」更重）。规避候选：① 横 3 门槛提至 840（与 §4.2 / §4.4 / §4.8 / §4.11 的 600 口径冲突，须并入 §4.8 已记的收口项统一裁决）；② **推荐**：底行三个 `Text` 补 `maxLines(1)` + `textOverflow({overflow: TextOverflow.Ellipsis})`，并把吧名 `Text` 的 `Blank()` 换成 `.layoutWeight(1)`（单列视觉等价：短吧名时两者都把剩余宽度吃掉、回复数与时间仍贴右缘）→ 顺带满足 §6.2 第 5 步。
6. **`ListItemGroup` 内行间距**：落地后确认 group 内卡片 `margin bottom 12` 仍生效（若被吞 → 用 `ListItemGroup.space(Spacing.md)` 补），列为落地验证项。
7. **`lanes(1)` 等价性**：单列档下 `.lanes(1, Spacing.md)` 与「不设置 `lanes`」是否逐像素一致 → 落地确认；**与 §4.11 风险 6 同一验证项**，若需回退则**两页一起**改「双 `List` 双分支」。
8. **分页 / 切 mode**：`loadMore` / `hasMore` / `likesPage` 零改动；多列后追加仍落在视口下方（依赖风险 1 的结论）。

**手机端零回归核对（2026-09-13 → 结论：不影响）**

| 改动项 | 手机实际路径 | 是否改变几何 |
|---|---|---|
| `personalColumns()` | 首行 `!isWideFormDevice` → 1（**手机横屏 780 也是 1 列**）| 否 |
| 新增 `pageWidth` / `pageHeight` / `isLandscape` + `onAreaChange` 回填 | 只写入状态、单列分支不读取（D5）| 否 |
| `aboutToAppear` 同步取宽高 | 纯新增（现状无任何页宽状态）| 否 |
| **`.lanes(1, Spacing.md)`** | 与「不设置 `lanes`」等价（**须落地验证**，见风险 7）| 否（待验证）|
| 通栏项处理 | **列 = 1 走原裸 `ListItem` 结构**（98 占位首项），**不套 `ListItemGroup`**（D2）| 否 |
| `List` 的 `padding` / `overlay` / `blendMode` / `expandSafeArea` / `scrollBar` / `clip` / `layoutWeight` / `onReachEnd` / `onScrollIndex` | 全部保留原值 | 否 |
| `ContentCard` | 零改动；**若采纳风险 5 的规避 ②**，底行三 `Text` 只加 `maxLines(1)` + `textOverflow`、吧名 `Blank()` 换 `layoutWeight(1)` → 单列视觉等价，**须真机逐点复核** | 否（待验证）|
| 顶栏两路径 / 三态 / 分页 / 缓存 / 4 个 mode | 零改动 | 否 |

**手机验收基线**：手机竖 360 单列 —— 可用宽 328、卡片宽 328、**行间距 12（卡片 `margin bottom`）**、左右 `Spacing.lg` 16、顶部让位 98、底部留白 20、卡片三行文本结构不变 —— **全部逐像素不变**。

**风险自检（§6.2）**
- **A 错位 → 有 3 处**：① **A1 通栏项只占 1 格** —— 顶部 98 占位（`161-164`）必须迁进 `ListItemGroup.header`，并保持 `List.sticky` 默认 `None`（否则占位吸顶）；② **A5 首帧列数跳变** —— 本页**没有任何形态初值**（无 `pageWidth`、无 `onAreaChange`）→ 冷启动平板横屏必「先 1 列再 3 列」，改 `aboutToAppear` 用 `display.getDefaultDisplaySync()` 同步取宽高；③ **A6 行内高度差留白** —— `lanes` 固有（标题 / 摘要各 `maxLines(2)`，≈ ≤38vp）→ 接受。**A2 末行拉伸不适用**（`lanes` 列宽恒定，不写 `blankSlots()`）；**A3** 顶栏双路径几何本次不动；**A4** 本页无 `Content.maxWidth` 需求。三处规避均已到可落地粒度。
- **B 出屏 → 无**：`lanes` 均分列宽（非像素）、卡片 `width('100%')`、无横向滚动；`expandSafeArea` 只扩上 / 下；本页无 `.position()` 锚点。**注**：风险 5 的底行溢出越的是**列边界**（记 C 类），不是屏幕右边界。
- **C 重叠 → 有 1 处**：折叠展开横屏 750 三列（卡内文本宽 ≈ 199vp）下底行可能横向溢出；因 `Row` 子项 `flexShrink 0` + 卡片无 `clip` + `List.clip(false)` → 溢出内容会盖到右列卡片（C3）。**已拍板 #2：走规避 ②** —— 底行三 `Text` 补 `maxLines(1)` + `textOverflow`、吧名 `layoutWeight(1)` 替 `Blank()`（单列视觉等价，须真机逐点复核）。**C2 底部悬浮让位 → 无**：本页无底部悬浮层，底部留白 `Spacing.xl`(20) 随列数不变。
- **D 手机回归 → 无**：见上表 —— 手机（含横屏 / 分屏 / 自由多窗）恒 1 列；列 = 1 走原裸 `ListItem` 结构、不套 `ListItemGroup`（D2）；本页不写 `cardColumns`（无 D1 / D6 残留面）；`onAreaChange` 只回填状态（D5）；本页无骨架屏（**无 D3 面**）。**三条落地验证项**：① `onScrollIndex` 多列语义（风险 1）；② `lanes(1)` 等价性（风险 7）；③ 风险 5 规避 ② 的单列视觉等价。

**待拍板点（2026-09-13 已按推荐值全部拍板 → 转「已确认」，下表「拍板结果」列即结论）**

| # | 点 | 拍板结果（原推荐值） | 理由 / 备选 |
|---|---|---|---|
| 1 | 列数口径（600 / 840） | **采用 `600`**（同 §4.2 / §4.4 / §4.8 / §4.11） | 与全站一致；折叠展开横屏 750 三列偏窄（231vp）的观感并入 §4.8 已记的口径收口项，**不新增第三套** |
| 2 | 窄列底行溢出（C3） | **规避 ②**（底行 `maxLines(1)` + `textOverflow`；吧名 `layoutWeight(1)` 替 `Blank()`） | 成本极小、单列视觉等价；备选 = 接受（本页是「溢出盖右列」而非「截断」，风险高于 §4.11 同名项）|
| 3 | `lanes(1)` 等价性失败时的回退 | **§4.11 / §4.12 两页一起改「双 `List` 双分支」** | 同一范式、同一验证项，避免一页一套写法 |
| 4 | 列间距取值 | **`Spacing.md`(12)**（= 本页行间距） | 护栏「列间距恒等于行间距」；与 §4.11 取 `Spacing.sm`(8) 各同源于自身行间距 |
| 5 | `onScrollIndex` 预取失效时的兜底 | **多列分支放宽阈值（宁可提前取）** | 保 `onReachEnd` 作兜底；切勿让预取变「滑到边界才加载」（观感回归）|

**状态**：方案**已确认**（2026-09-13 用户指示「两页采用同一方案」→ 方案已出；**同日用户「按推荐值拍板，后续有需要才改」→ 上表 #1~#5 全部按推荐采纳**：口径沿用 `600` / 窄列底行溢出走**规避 ②**〔底行三 `Text` 补 `maxLines(1)` + `textOverflow`、吧名 `layoutWeight(1)` 替 `Blank()`〕/ `lanes(1)` 失败时 **§4.11 / §4.12 两页一起改双 `List` 双分支** / 列间距取 `Spacing.md`(12) / `onScrollIndex` 预取失效时**多列分支放宽阈值**并保 `onReachEnd` 兜底）。**代码尚未执行**，受前置依赖阻塞（判据令牌待 §4.6 H-B 落地）→ **本轮只更新文档，不开工**。**三条落地验证项**（拍板不变，落地后仍需实测）：① `onScrollIndex` 多列语义（本页独有）；② `lanes(1)` 等价性（与 §4.11 同一项）；③ 规避 ② 的单列视觉等价。

<!-- 每个界面的方案按以下模板追加：

### N. 界面名称（`pages/XXX.ets`）

- 适配需求：
- 设计方案：
- 涉及改动点：
- 断点 / 阈值：
- 风险与回归项：
- **风险自检（§6.2，强制）**：A 错位 → 无 / 有（位置 + 规避）；B 出屏 → 无 / 有（位置 + 规避）；C 重叠 → 无 / 有（位置 + 规避）；D 手机回归 → 无 / 有（所核手机路径 + 基线对比）
- 状态：待确认 / 已确认
-->

## 五、全局改动汇总（待补充）

## 六、验收与回归清单

### 6.1 跨界面：重叠 / 错位 / 出屏 / 手机回归的防御与验收（2026-09-12 整理，2026-09-13 增补 D 类）

**总判断**：§4.1~§4.5 的改造都遵循三条底层约束，因此**横向出屏、卡片互相重叠在设计上不会发生**；真正需要盯的是**错位**（网格与通栏项混用、双路径不同步）与**横屏高度受限**带来的挤压。

**三条底层约束（后续改动不得破坏）**

| # | 约束 | 依据 / 效果 |
|---|---|---|
| 1 | 列宽**只允许** `1fr` / `layoutWeight(1)` / 百分比，**禁止像素列宽** | §4.1 `columnsTemplate`、§4.5 `layoutWeight` → 列宽恒等于可用宽均分，不可能超右边界 |
| 2 | 左右外边距**单一来源**（`Spacing.lg = 16`），顶栏与内容共用 | §4.2 硬约束 1~4 → 顶栏胶囊与首 / 末列卡片外边缘咬合，杜绝 8vp 错位台阶 |
| 3 | 通栏项（占位 / 空态 / 加载 / 底部留白）**永不进网格** | §4.3 `ListItemGroup.header/footer`、§4.4 `notifyBlankSlots`、§4.5 `mineBlankSlots` |

**A. 错位类（最可能发生，肉眼可见）**

| # | 风险 | 出现位置 | 规避 |
|---|---|---|---|
| A1 | 通栏项只占 1 格 | §4.3 `lanes` 下顶部占位 / 同步提示 / 空态 / 底部 90 占位；§4.11 两 Tab 的 `Header` 与尾部 160 占位（共 3 处）；§4.12 顶部 98 占位（1 处，无尾部占位）| 全部收进 `ListItemGroup` 的 `header` / `footer`（改动二）；`CategoryListView` 前置 3 项同理（风险 6.2）；§4.11 / §4.12 另附护栏：**保持 `List.sticky` 默认 `None`**，否则 `header` 会吸顶（§4.11 是 Header 由「随内容滚」变「钉住」、§4.12 是 98 占位变吸顶条）|
| A2 | 末行不满被拉伸 | §4.4、§4.5（末行 1 张卡独占整行）；§4.8 列表态与搜索态 | `notifyBlankSlots()` / `mineBlankSlots()` / `threadBlankSlots()` 补等宽空位 |
| A3 | 双路径不同步 | §4.3 顶部槽位 `FavTitleBar` vs 兜底 `CategoryTabs`（及搜索框两处）；§4.5 判定挂点 | 两处必须同改；几何抽成单一常量 |
| A4 | 顶栏与首列不对齐 | §4.2 卡片区若被放大到 24 / 32 而顶栏仍 16 | **禁止**为大屏「呼吸感」单独放大留白（硬约束 2） |
| A5 | 首帧列数跳变 | §4.1~§4.5 全部；§4.11（`currentWidth` 初值 360 只在 `onAreaChange` 纠正 → 冷启动平板横屏「先 1 列再 3 列」）；§4.12（更重：本页**无任何形态状态**，不补必跳）| `aboutToAppear` 用 `display.getDefaultDisplaySync()` 同步 `isLandscape` / `pageWidth` 初值（§4.11 需补 `display` import；§4.12 需补 `deviceInfo` / `display` 两个 import）|
| A6 | 行内高度差留白 | §4.3 帖子卡（`lanes` 不等高）、§4.4（方案 A 固有代价）、§4.11（帖子卡标题 / 摘要各 `maxLines(2)`，最大差 ≈ 38vp）、§4.12（同款卡片，差值同量级）；**§4.2 多列档已于 2026-09-13 决策 11 落地「主动消除」**（当天首次尝试〔决策 8〕因最高卡操作栏消失回退；同日先用独立最小 Demo 在真机跑 6 组对照定位根因 = **缺卡根 `height('100%')`**，再按同一写法二次落地，构建通过、**待真机验收**） | §4.3 走 `WaterFlow` 或接受；§4.4 用「大屏定高 + 裁行」；§4.11 / §4.12 接受（差值小于 §4.3 已受值 54vp）；**§4.2 当前按「接受」处理：行分组 `Row({ space: Spacing.md })` + `VerticalAlign.Top`，已通过决策 6「摘要降 2 行 + 图片封顶」削弱落差；2026-09-13 决策 9（横屏由 3 收 2）曾进一步降低极端组合概率，但**同日决策 10 已撤销该收口、恢复横屏 3 列** → 落差回到收口前水平，仍按「接受」处理（要消除只能「定高 + 裁内容」或「列内独立堆叠」）；但 **§4.2 已于当日升级为「主动消除」**（决策 11：`Flex(ItemAlign.Stretch)` + 卡片调用点 `height('100%')` + 内容区 `.layoutWeight(1)` + 根 `constraintSize({ maxHeight: 560 })`，行内底边齐平、按钮贴底，待真机验收）** |
| A7 | **行等高拉伸的写法要点 → 决策 11 已定位根因并二次落地**（2026-09-13 决策 8 实证失败；同日以独立最小 Demo 在真机实测 6 组对照，确认成功写法） | §4.2 多列档行分组（以及后续任何复用行等高的页面，如 §4.8 / §4.9 若改用同一写法）| ① 拉伸交叉轴理论上可用 `Flex({ alignItems: ItemAlign.Stretch })` —— **`Row.alignItems` 只接受 `VerticalAlign`（无 `Stretch`）**；② 实测：把 `Row` 换 `Flex` + `ItemAlign.Stretch`、并在 `ThreadCard` 内容区与操作栏之间插 `Blank()` 后，**不仅没有拉伸对齐，反而导致同行最高卡的操作栏消失**（分享/评论/赞三按钮不可见），具体根因未进一步排查；③ **根因（2026-09-13 最小 Demo 真机实测补正）**：失败不在 `Blank()`，而在**卡根缺 `height('100%')`** —— `Flex` 的 `ItemAlign.Stretch` 只把交叉轴「建议尺寸」交给子项，子项未声明 `100%` 时仍按内容高度渲染（Demo 组③：`Flex` + `Stretch` 无高度 → 矮卡仍 142），即「行等高未生效」；同理卡根高度未定时 `Blank()` 的剩余空间失去参照（Demo 组②：`Row` + `height('100%')` → 行被 `Scroll` 撑到 1328），操作栏遂被推出可见区；④ **正确写法（三条件缺一不可）**：行容器 `Flex({ alignItems: ItemAlign.Stretch })` + 卡片调用点 `.height('100%')` + **内容区 `.layoutWeight(1)` 占满剩余空间 + 根 `Column` 的 `.constraintSize({ maxHeight: 560 })` 上限护栏**（`Blank()` / `SpaceBetween` 在含 `Grid`/异步图片的复杂卡内均因高度测量失控失效：多宫格卡操作栏丢失、纯文本卡被 `Scroll` 无限高度异常拉长）→ Demo 组④⑤⑥ 均 680×848 等高、三胶囊可见可点；⑤ 决策 8 的旧逻辑已全部清除，决策 11 按新写法重新落地（`cardColumns > 1` 把关，首落用 `Blank()` 复现多宫格卡操作栏丢失，再改为 `SpaceBetween` 仍失效〔纯文本卡被 `Scroll` 无限高度异常拉长〕，最终改为「内容区 `.layoutWeight(1)` + 根 `constraintSize({ maxHeight: 560 })`」），手机单列零回归 |

**B. 出屏 / 被裁类**

| # | 结论 | 依据 |
|---|---|---|
| B1 | **横向出屏基本不可能** | 全工程 `.position()` 仅 8 处，且都是相对父容器的偏移（`top:99 / right:16` 回顶钮、搜索框内图标 `x:4 / x:40`）；唯一横向滚动在 §4.1「最近访问吧」，横屏更宽；固定像素宽仅 180 / 210（手机 360vp 下已在用）→ 大屏只会更宽松 |
| B2 | 横向安全区不被侵入 | 沉浸统一 `expandSafeArea([SYSTEM], [TOP, BOTTOM])` → **不扩左右**，横屏挖孔 / 曲面不会压住内容 |
| B3 | **横屏是「内容被挤」而非「出屏」** | 横屏视口高约 640vp，固定让位 = 顶部 98~108 + 底部 150 ≈ 250vp（约四成）→ 可视区只剩约 390vp。可选优化：横屏形态下按比例收敛让位（默认**不动**，避免回归） |
| B4 | 定高卡文本溢出 | §4.4 `NOTIFY_CARD_WIDE_H`（170~190vp）+ 裁行 → **必须同步 `maxLines` + `textOverflow`**；这些容器多为 `.clip(false)`，超长文本不会被裁、会盖到下一张卡上（**这才是真正的纵向重叠源**） |
| B5 | 渐隐带横屏变浅 | §4.2 / §4.3 / §4.4 均为「视口高 × 0.15~0.20」：横屏 ~96~128vp < 顶栏所需的 102~148vp → 顶部出现硬边，观感近似「错位」。可选：`min(max(视口高 × k, 需求值), 上限)` 夹取 |
| B6 | 全局字号缩放（`fontScale`） | 固定高卡片（`FolderCard` 80 / `MineEntry` 48 / `CATEGORY_CARD_HEIGHT` 80）在大字号下文本撑高 → 因 `.clip(false)` 溢出到相邻卡。规避：卡内文本统一 `maxLines(1)` + `textOverflow`，或高度改 `minHeight` |

**C. 重叠类（仅三类真实存在）**

| # | 风险 | 现状 / 规避 |
|---|---|---|
| C1 | 底部玻璃底栏压内容 | 底栏高 74 + 底部 margin 30 = 104vp，各主 Tab 页底部让位 150vp → **安全**；§4.5 风险 11 的「内容不足一屏时 150 变纯空白」属观感、非 bug |
| C2 | 二级页悬浮元素让位 | `ThreadDetail` 底部自建排序胶囊（`margin.bottom 96`）、各页回顶钮（`position top:99 / right:16`）→ 横屏矮视口下需复核让位是否仍够。**本轮不改二级页，属既有项**；`ThreadList` 多列化后底部悬浮排序壳 / FAB 仍由 `contentBottomSpace()`（98 / 104 / 150）让位，见 §4.8 风险 6；`ThreadDetail` 竖屏多列 / 横屏分栏后**左右两栏各自 `padding bottom 160`**（现状值不动）→ 让位等价、无新增遮挡，见 §4.9 DT-D 与风险自检 C2；`SubPostDetail` 分栏后两栏各自 `padding bottom Spacing.xl`(20) 且**本页无底部悬浮层**，见 §4.10；`UserProfile` 多列后底部悬浮分段 Tab（官方浮槽 `barHeight 74` + `barBottomMargin 30`；横屏胶囊 480 居中）由**恒定 160 通栏占位**让位（74 + 30 + 手势 ≈ 138 < 160），160 随列数不变，见 §4.11；`PersonalContent` **无底部悬浮层**（二级页，无底栏 / 无分段 Tab）→ 无让位需求，底部留白维持 `Spacing.xl`(20) 且随列数不变（**不得照抄 §4.11 的 160**），见 §4.12 |
| C3 | 拖拽预览叠卡 | §4.3 `CategoryListView` 手绘垂直让位（`displaceOffsetOf` / 原位 `height(0)` 塌陷）与多列**不可兼容** → 三选一（候选收敛见改动六） |

**D. 手机回归类（2026-09-13 起纳入强制自检）**

> 起因：§4.8 确认「是否影响手机正常布局」时发现 —— 平板适配最容易破的不是大屏、而是**手机基线**（360 竖屏逐像素不变）；且失败方式隐蔽，不报错、不崩溃，只在特定形态切换后悄悄变样。

| # | 风险 | 触发条件 | 规避 |
|---|---|---|---|
| D1 | **全局标记残留** | 用 `AppStorage` / `@StorageProp` 下发列数（如 §4.2 决策 6 的 `cardColumns`）却**只在多列档写** | **无条件写**（单列档也写 1），`aboutToAppear` + `onAreaChange` 各写一次；跨页共享的标记必须在**每个**使用页都写 |
| D2 | **单列分支被套额外容器** | 实现写成「统一 `Row > Column.layoutWeight(1)`，1 列时只有一项」 | 显式 `if (columns <= 1) { 原 ForEach } else { 行分组 }`；**列宽来源**从 `width('100%')` 变成 `layoutWeight` 即算回归 |
| D3 | **共享组件入参默认值踩到单列页** | 给组件（如 `ThreadListSkeleton`）加 `columns` 参数时默认值 > 1，或调用点顺手写上多列值 | 默认值必须 **= 1**；并**逐点核对全部调用点**（`ThreadListSkeleton` 共 5 处跨 3 页；其中 `UserProfile` 两处虽已随本页多列化，仍**保持默认单列铺排**、不加 `columns` 入参，见 §4.11 **已拍板 #3「骨架屏不按列铺」**）|
| D4 | **形态判定把手机误判为大屏** | 只用宽度阈值（如 `pageWidth >= 600`）判多列 → 手机横屏（~780 ≥ 600）即命中 | 判据**首行**加形态闸门 `if (!isWideFormDevice) return 1`：手机含**横屏 / 分屏 / 自由多窗**恒 1 列 |
| D5 | **新增状态回写被误当布局变化** | 新增 `onAreaChange` 回填页宽 / 页高等状态 | 尺寸常量与渲染分支未变即通过（写入本身不算回归，尺寸变化才算） |
| D6 | **折叠屏展开↔折叠跨形态残留** | 展开（2 列）→ 折叠（应回 1 列），折叠瞬间未写标记 | 同 D1；并把该路径列为**必测回归路径** |

**手机基线判据（D 类通过的硬标准）**：手机竖屏 360 下，本次改动涉及的卡片高度、文本行数、图片格高、间距、底部让位、骨架屏排列 —— **与改动前逐像素一致**（基线参照本表上方「验收矩阵」首行）。

**验收矩阵**

形态：手机竖 360（基线，逐像素不变）→ 折叠展开竖 750 → 平板竖 800 / 960 → 平板横 1024 / 1280 → 窄窗 < 600 → 分屏 / 自由多窗拖窄。

| 检查项 | 判据 |
|---|---|
| 外边缘对齐 | 顶栏胶囊左缘 = 首列卡左缘、搜索钮右缘 = 末列卡右缘（16vp），无 8vp 台阶 |
| 无横向溢出 | 任何形态下内容不越过右边界、无横向滚动条 |
| 无整层消失 | 滚到中部 / 底部停住，卡片不消失（沉浸 + 虚拟滚动容器，见 `floor-vanish-viewport-fix`） |
| 无互相遮盖 | 底栏、回顶钮、渐隐带不遮挡当前可见卡片；定高卡文本无溢出 |
| 形态切换 | 横↔竖各切一次：无列数跳变、无滚动位置错乱（§4.3 风险 3 需改「一次性恢复标志」） |
| 末行 | 总数 = 列数 × k + 1 时，最后一张卡不独占整行 |

> **范围提醒**：§4.1~§4.5 只覆盖 5 个主 Tab 页。二级页（`FollowList` / 设置类）**不做多列**，它们均为单列 + `width('100%')` + 纵向滚动容器 → **不会重叠 / 错位 / 出屏**，只是宽度被拉满、留白偏大（观感问题，非 bug）。其中唯一要盯的是 C2。
>
> **例外一（2026-09-12）**：`Search`（全吧搜索）**已改为做多列**（手机 1 / 平板竖屏 2 / 平板横屏 3，见 §4.7），因此它**不再是**上句所说的「单列二级页」；该页的 A / B / C 结论以 §4.7 的自检留痕为准（A 有 2 处、B 无、C 有 1 处）。
>
> **例外二（2026-09-13）**：`ThreadList`（吧内帖子列表）**也已改为做多列**（手机 1 / 平板竖屏 2 / 平板横屏 3，含本吧搜索态，见 §4.8），同样移出上句清单；该页 A / B / C 结论以 §4.8 的自检留痕为准（A 有 1 处、B 无、C 无）。
>
> **例外三（2026-09-13）**：`ThreadDetail`（帖子详情）**已改为多列 + 横屏分栏**（竖屏主楼满宽 + 回复两列；横屏左主楼 / 右回复两列，见 §4.9），同样移出上句清单；该页 A / B / C / D 结论以 §4.9 的自检留痕为准（A 无、B 无、C **有 1 处**「横屏右栏两列在 1024 下偏窄」、D 无）。
>
> **例外四（2026-09-13）**：`SubPostDetail`（楼中楼详情）**已改为多列 + 横屏分栏**（与 §4.9 同款，见 §4.10），同样移出上句清单；该页 A / B / C / D 结论以 §4.10 的自检留痕为准（A **有 1 处**「卡内 8vp 追加间距用全局下标 → 分列后列底空洞」、B 无、C **有 1 处**「横屏右栏两列在 1024 下偏窄」、D 无）。另记本页两条**与 §4.9 不同、不得照抄**的执行红线：底部留白维持 `Spacing.xl`(20)（**非** §4.9 的 160）、滚动区装饰层只需上移 `overlay` + `blendMode` 两项（底色在根 `Stack` 上、无需搬运）。**2026-09-13 用户「按推荐确认」→ §4.10 已转「已确认」**（5 个待拍板点全部按推荐采纳，见 §4.10 状态行）。
>
> **例外五（2026-09-13）**：`UserProfile`（用户主页，见 §4.11）**已改为多列** —— 但与前四例**范式不同**：本页容器**本来就是 `List`**（带 `scroller` + `onReachEnd` 分页），故**不换容器、不走行分组 / 列内堆叠，而是加 `.lanes(列数, Spacing.sm)` + 把 `Header` 与尾部 160 占位迁进 `ListItemGroup.header/footer`**（与 §4.3 收藏页改动二同范式）；列数 = 手机 1 / 平板竖 2 / 平板横 3。该页 A / B / C / D 结论以 §4.11 的自检留痕为准（A **有 3 处**：通栏项只占 1 格〔含「不许打开 `sticky`」护栏〕/ 首帧列数跳变 / `lanes` 行内高度差留白；B 无；C **有 1 处**：折叠展开横屏 750 下三列 ≈ 234vp 窄列截断；D 无）。另记三条本页独有执行红线：① 单列档（含手机）**走原裸 `ListItem` 结构、不套 `ListItemGroup`**；② `List.sticky` 保持默认 `None`（否则 `Header` 吸顶）；③ 底部 160 占位随列数不变、**不使用 `lanes` 第三参 `margin`**。
>
> **例外六（2026-09-13，用户拍板「两页采用同一方案」）**：`PersonalContent`（个人内容，见 §4.12）**与例外五同范式**（容器本来就是 `List`、且**无 `scroller`** → 不换容器、不走行分组 / 列内堆叠，而是加 `.lanes(列数, Spacing.md)` + 把顶部 98 占位迁进 `ListItemGroup.header`），同样移出上句清单；该页 A / B / C / D 结论以 §4.12 的自检留痕为准（A **有 3 处**：顶部 98 占位只占 1 格〔含「不许打开 `sticky`」护栏〕/ 首帧列数跳变〔本页**无任何形态状态**，比 §4.11 更重〕/ `lanes` 行内高度差留白；B 无；C **有 1 处**：折叠展开横屏 750 三列下卡内文本宽 ≈ 199vp → 底行挤压，`Row` 子项 `flexShrink 0` + 卡片无 `clip` + `List.clip(false)` → **溢出盖右列**，推荐「底行补 `maxLines(1)` + `textOverflow`、吧名 `layoutWeight(1)` 替 `Blank()`」；D 无）。另记四条本页独有执行红线（**与 §4.11 数值 / 理由不同源，不得互抄**）：① 单列档走原裸 `ListItem` 结构、不套 `ListItemGroup`；② `List.sticky` 保持默认 `None`；③ 底部留白维持 `Spacing.xl`(20)（**不得照抄 §4.11 的 160**）、不使用 `lanes` 第三参 `margin`、**不引入尾部占位**；④ 列间距取 `Spacing.md`(12)（= 本页行间距，因本页 `List` **无 `space`**、行间距由卡片 `margin bottom` 承担；§4.11 取 `Spacing.sm`(8) 源于其 `List({space})`）。
>
> **例外页共同点**：例外一~四都**保留原 `Scroll`、不换滚动容器、不引入 `WaterFlow`**，改动只落在 `Column` 内的分列写法 —— `Search` / `ThreadList` 用「按行分组」（`Row` 内 `layoutWeight(1)` 均分，§4.4 方案 A 同款）；`ThreadDetail` / `SubPostDetail` 用「列内独立堆叠」（两列各自 `Column`，目的是消除行内对齐留白，理由见 §4.9）→ 沉浸滚动 / 快照裁剪 / 预加载测量 / 底部让位仍按原机制生效，与主 Tab 页换 `WaterFlow` / `List` 的情况不同。
>
> **多列写法共三套（选用口径）**：① 容器是 `Scroll + Column` 且卡片可变高（`Search` / `ThreadList`；`HomeTab` 亦属此类）→ **按行分组**（**2026-09-13 决策 11 起，`HomeTab` 已用「行容器 `Flex({ alignItems: ItemAlign.Stretch })` + 卡片调用点 `height('100%')` + 卡内 `Blank()`」主动消除行内落差** —— 当天首次尝试因缺卡根 `height('100%')` 而失败〔最高卡操作栏消失〕并回退，同日以最小 Demo 真机跑 6 组对照定位根因后二次落地，**待真机验收**；`HomeTab` 同日还曾改**横竖统一 2 列**〔决策 9〕削弱极端组合概率，**同日又撤销、恢复横屏 3 列**〔决策 10〕；该三条件写法可复用于 `Search` / `ThreadList` 等同类「`Scroll + Column` + 可变高卡片」页，但**「列内独立堆叠」仍是不依赖拉伸语义、更稳的选项**）；② 容器是 `Scroll + Column` 且要消除行内对齐留白（`ThreadDetail` / `SubPostDetail`）→ **列内独立堆叠**；③ 容器是 `List`（`UserProfile`，§4.11；`PersonalContent`，§4.12；以及 §4.3 收藏页）→ **`.lanes()` + `ListItemGroup.header/footer`**（注意：§4.11 有 3 处通栏项、尾部占位 160；§4.12 只有 1 处通栏项、无尾部占位、底部留白 20 —— 同一个写法、**不同常数**）。三套不可混用；判定先看容器类型。

### 6.2 文档更新自检流程（强制，2026-09-12 起执行；**2026-09-13 起增第七步「手机端零回归核对」**）

**触发时机**：本文件任何一次「界面方案」更新都必须先过本节自检，再落笔 —— 包括新增 / 修改 §4.x 小节、更新 §三 清单状态、改动 §九 官方槽位表，以及任何会改变布局几何（列数 / 宽度 / 高度 / 外边距 / 让位 / 悬浮层 / 网格容器）的条目。**第七步「手机端零回归核对」与前六步同等强制、同次留痕**（2026-09-13 起，用户要求每次都做）。

**自检七步（逐条在本节末尾留痕，不可只口头确认）**

| 步 | 检查问题 | 通过判据 | 不通过时的典型改法 |
|---|---|---|---|
| 1 | 有没有**像素列宽**？ | 列宽只有 `1fr` / `layoutWeight(1)` / 百分比 | 一律改成 `1fr` / `layoutWeight(1)` |
| 2 | 左右外边距是否**单一来源**？ | 顶栏与内容共用同一常量（`Spacing.lg = 16`） | 抽常量；**禁止**为「呼吸感」局部放大留白 |
| 3 | 有没有**通栏项**（占位 / 空态 / 加载 / 底部留白）落进网格？ | 全部在 `ListItemGroup.header/footer`，或网格的兄弟节点 | 移出网格，**禁止**让它只占 1 格 |
| 4 | 网格**末行不满**是否补空位？ | 有 `xxxBlankSlots()` 等价补位逻辑 | 补等宽空位 |
| 5 | **定高容器**内文本是否配 `maxLines` + `textOverflow`？ | 每处定高都配齐 | 补 `maxLines` / `textOverflow`，或高度改 `minHeight`（容器多为 `.clip(false)`，超长文本会盖到下一张卡） |
| 6 | 形态判定是否**单一函数 + 单一挂点 + 首帧初值**？ | `aboutToAppear` 同步 `isLandscape` / `pageWidth`；无「槽位 / 兜底」双路径分叉 | 合并判定、首帧赋值、几何抽单一常量 |
| **7** | **会不会影响手机正常布局？**（D 类手机回归，2026-09-13 起**每次必做**） | 手机竖屏 360 下**逐像素不变**：列数恒 1（含横屏 / 分屏 / 自由多窗）、卡片几何 / 文本行数 / 图片格高 / 间距 / 让位 / 骨架屏排列全不变；无全局标记残留（D1 / D6） | 判据首行加形态闸门（D4）；列 = 1 走原分支、**不套**行分组容器（D2）；跨页共享标记**无条件**写 1（D1）；共享组件入参默认 = 1 并核**全部**调用点（D3） |

**留痕格式**（模板已内建，每个 §4.x 小节末尾必须有）

```text
**风险自检（§6.2）**：
- A 错位 → 无 / 有（位置 + 规避）
- B 出屏 → 无 / 有（位置 + 规避）
- C 重叠 → 无 / 有（位置 + 规避）
- D 手机回归 → 无 / 有（所核手机路径 + 基线对比结论）
```

A / B / C / D 四类风险的定义与判定依据见 §6.1 的四张表（A 错位类 / B 出屏被裁类 / C 重叠类 / D 手机回归类）。

> **历史留痕说明**：§4.1~§4.8 小节末尾的既有留痕是「六步时代」产物，只含 A / B / C 三行。**自 2026-09-13 起**新更新（或再次修改）的小节**必须补齐 `D 手机回归` 行**；未被再次触碰的历史小节不做回填，但一旦改动其几何或状态，须按七步重跑并补 D 行。

**结论与状态挂钩**

| 自检结论 | 允许的状态 |
|---|---|
| A / B / C / D 全为「无」 | 可标**已确认** |
| 有「有」，但规避写法已到可落地粒度（常量 / API / 位置明确） | 可标**待确认**，并列入该小节的待拍板点 |
| 有「有」，且规避未定 | **不得**标「已确认」，必须挂「待拍板点」 |
| **D 手机回归为「有」** | 按上三档判定，且必须在「风险与回归项 / 待做」里写明**手机回归验证路径**（含折叠屏展开↔折叠） |

**二级页也要过**：未做多列的二级页（`FollowList` / 设置类；另 `PersonalContent` 命名易混、同样无用户信息区，**已按用户 2026-09-13「两页采用同一方案」的指示另立 §4.12（与 §4.11 同范式）**）同样跑一遍七步，结论通常是「单列 + `width('100%')` + 纵向滚动 → **A / B / C 三类均为无**，D 单独确认」；但**悬浮层让位**（§6.1 的 C2：`ThreadDetail` 排序胶囊 `margin.bottom 96`、各页回顶钮 `position top:99 / right:16`）必须单独确认，不得直接写「无」。`Search`（§4.7）、`ThreadList`（§4.8）、`ThreadDetail`（§4.9）、`SubPostDetail`（§4.10，与 §4.9 同款）、`UserProfile`（§4.11，容器为 `List` → `.lanes()` + `ListItemGroup.header/footer`）、`PersonalContent`（§4.12，同范式，容器同为 `List`）已**例外做多列**，须按多列页走七步。**二级页同样要过第 7 步**：它们虽不做多列，但可能踩 D1 / D3（共享标记或共享组件被改写）—— `UserProfile` 两处 `ThreadListSkeleton` 仍是典型例子（本页虽已多列化，骨架屏**保持默认单列铺排**、不加 `columns` 入参）；已例外做多列的页面须额外核对「分栏 / 多列后各自的底部让位」（`ThreadDetail` **160**、`SubPostDetail` **20**、`UserProfile` **160**、`PersonalContent` **20**，**四页数值不得互相照抄**；其中 §4.10 与 §4.12 同为 20 但**理由不同源** —— 前者是用户真机拍板的回退值，后者是原始值且本页根本无底部悬浮层）。

**已过检记录**

| 日期 | 更新内容 | 自检结论 |
|---|---|---|
| 2026-09-17 | **中档小窗仍 3 列修复**：HomeTab 两条 feed 的 `WaterFlow.columnsTemplate` 直绑 `this.columns`（display 推导，小窗恒 3），与分支入口 `homeColumns()>1`（窗口闸门放行 2 列）错位 → 新增 `homeColumnsTemplate()` 单点同源，两处调用点换用；全工程检索其余页列模板均走列数函数，无同款隐患。`tools/build.ps1` → **BUILD SUCCESSFUL**；**待真机验证**（中档小窗 2 列） | A 错位：**无**（模板与入口同源后，列数唯一真源 = homeColumns()）。B 出屏：**无**。C 重叠：**无**。D 手机回归：**无**（手机全屏 homeColumns()=1 走单列分支不经模板；平板全屏 this.columns 与 homeColumns() 同值〔display≈窗口〕，模板结果不变；必测 = 中档小窗 2 列、最大档 3 列、平板全屏竖 2 横 3、手机单列逐像素） |
| 2026-09-17 | **小窗三档中间档改两列**：9 文件（8 列数页 + SubPostDetail）末档由「窗口宽高比 竖 2 / 横 3」改按窗口宽度分档 `≥840 → 3 / 600~840 → 2 / <600 → 手机档`（复用 Breakpoint sm/md）。全屏零回归（平板竖 ~800→2、横 ~1280→3 与改前同值）；阔直屏横 3 / 大折叠恒 3 分支在前不受影响。`tools/build.ps1` → **BUILD SUCCESSFUL**；**待真机验证**（中间档小窗 2 列、最大档 3 列、全屏各档回归） | A 错位：**无**（列宽全 `1fr`/layoutWeight，分档只改列数来源）。B 出屏：**无**（中间档列数收窄只会更宽松）。C 重叠：**无**（容器 / 层级零改动）。D 手机回归：**无**（手机全屏宽 <600 走首行闸门回手机档，路径未动；平板全屏竖/横与改前同值；必测 = 三档小窗逐档看列数、拖拽跨 600/840 翻档、平板全屏竖 2 横 3、折叠屏展开↔折叠） |
| 2026-09-17 | **小窗 / 分屏 / 自由多窗适配（列数判定真源统一为「窗口」）**：8 个列数页（HomeTab/ForumsTab/MessagesTab/Favorite/PersonalContent/Search/ThreadList/UserProfile）列数函数首行插窗口宽度闸门（<600 → 手机档，置于设备恒值分支之前）+ 窗口尺寸真源 display→窗口（onAreaChange 入参、display 仅首帧兜底、HomeTab cardColumns 经闸门下发）；ThreadDetail/SubPostDetail replyColumns 同款闸门（splitMode 既有 ≥600 判据不动）；ThreadDetail dialogCardWidth 窗口实宽优先；Index/UserProfile isWideScreen 设备恒值项补 width≥600。不做迟滞带（大折叠竖屏 ~630 紧贴 600）。`tools/build.ps1` → **BUILD SUCCESSFUL**；**待真机验证**（平板小窗单列、拖宽跨 600 升档、全屏各档回归） | A 错位：**无**（全屏各档窗口 ≈ display，列数逐档相等；小窗回落手机档结构逐像素，列宽全 `1fr`/layoutWeight）。B 出屏：**无**（dialogCardWidth 窗口优先只会更窄；底栏 400 仅在窗口 ≥600 才生效）。C 重叠：**无**（只改列数判定来源与度量来源，容器 / 层级 / 悬浮层零改动）。D 手机回归：**无**（手机全屏窗口 ≈ display；`isWideFormDevice=false` 恒 1 列路径与 ForumsTab 手机 2 列路径未被闸门改变〔ForumsTab 闸门回 2 与原 `!isWideFormDevice→2` 同值〕；首帧 display 猜测口径保留、onAreaChange 即纠正；必测 = 手机全屏竖/横、平板 / 阔直屏 / 大折叠全屏各档列数、平板小窗与拖宽跨 600 翻档、折叠屏展开↔折叠） |
| 2026-09-15 | **§4.11 用户主页双 Tab 左右滑动切换（交互新增，范式照抄首页 `Index.switchTab`）**：内容区由条件渲染改为**双页平移栈**（两页常驻/首访挂载 + `Visibility` 控制可见 + `translate` 百分比位移 + `zIndex` 进场页在上），新增 `switchTab` 方向感知滑入（`springMotion(0.72,0.86)` 320ms + `animLock` + `setTimeout` 420ms 复位，与首页逐项同源）与水平 `PanGesture` 跟手拖拽（`distance 12` + `PanDirection.Horizontal` 方向竞争让位给列表垂直滚动；位移过 1/4 页宽或甩速 700vp/s 提交，边缘阻尼 35%，未达阈值 spring 回弹；关注的吧页拖拽开始即挂载并触发懒加载）。**不用 Swiper**（沿用本页既有决策：其手势抢占 List 垂直滚动）。`tools/build.ps1` → **BUILD SUCCESSFUL**；**待真机验收**（点击胶囊滑入动画 / 左右跟手拖拽 / 拖拽中列表垂直滚动不冲突 / 两页滚动位置保留 / 折叠屏展开↔折叠） | A 错位：**无**（两页均 `width('100%')` 满宽平移，无双列/网格语义）。B 出屏：**无**（外层 `clip(true)`，页移出即裁剪）。C 重叠：**无**（可见性只允许当前页+退场页/拖拽邻页同屏，进场页恒在上层；顶栏/底栏悬浮层在栈外不受平移影响）。D 手机回归：**无**（不引入形态/列数分支，全宽度档同款行为；两页内部几何零改动；`Header` / 顶部让位 98 / 底部 160 占位 / 分段胶囊零改动；列表垂直滚动方向竞争已由 `PanDirection.Horizontal` + `distance 12` 让位，必测回归 = 帖子 Tab 上下滚动 / 滑动中途反向回弹 / 折叠屏展开↔折叠） |
| 2026-09-15 | **§4.11 用户主页「关注的吧」顶栏让位修复（手机端缺陷修复，非平板方案变更）**：用户真机反馈关注的吧列表内容与顶栏重叠 → `LikeTabContent` 列表首项补 `height(98 + Spacing.sm)` 顶部占位 `ListItem`（顶栏让位 98 与 `Header` 同源、随内容滚走、列表项从透明标题栏下穿过与帖子 Tab 行为对齐）；Loading（`ThreadListSkeleton`）/ Error / Empty 三个非滚动状态补同值 `.padding({ top: 98 + Spacing.sm })`。**同日微调两轮**：首版呼吸用 `Spacing.md`(12)，真机反馈略多 → 收为 `Spacing.sm`(8) → 仍多 → 收为 **98 整（零呼吸）**，首卡紧贴顶栏下缘。`tools/build.ps1` → **BUILD SUCCESSFUL**；**待真机验收** | A 错位：**无**（占位值单一来源 = 顶栏高 98，无新增像素魔法数）。B 出屏：**无**（仅顶部让位，列表 `width('100%')` / 左右 `Spacing.lg` 不变）。C 重叠：**有 1 处、已销**（本修复即为销 C 类重叠：关注的吧内容顶入透明顶栏；官方槽位与兜底两路径共用 `LikeTabContent`，一次修复两路径生效；`Header()` 几何未动，§4.11 红线「不改 Header」未违反）。D 手机回归：**无**（本修复即手机端行为修正、全宽度档一致生效，不引入任何形态/列数分支；`PostTabContent` / `Header` / 分段胶囊 / 底部 160 占位零改动；折叠屏展开↔折叠无新增面） |
| 2026-09-14 | **§4.3 收藏页平板适配开工落地（改动一~七全部完成）**：① 改动一胶囊左对齐（槽位 + 兜底两处同步，多列档 `layoutWeight 0` + padding 22 + 行尾 `Blank()`）；② 改动二 `FolderListView` 加 `lanes(3/4)`，通栏项收 `ListItemGroup` header/footer；③ 改动三 `ForumThreadsView` 换 `WaterFlow`（3/4 列，让位 / 占位移出流、空态替换整流、无 sections、无 Grid 坑）；④ 改动四基础设施（`pageWidth/pageHeight` 首帧初值 + 根 Stack `onAreaChange`、`favColumns()` 竖 3 横 4、`forumColumnsTemplate()`）；⑤ 改动五搜索框内嵌返回钮（两处同步）+ `SearchResultView` 换 `WaterFlow`；⑥ 改动六拖拽回调抽共享方法（`catDragBegin/catDragMove/catDrop` + `prepend`/`Scroller` 参数化）+ `CategoryListView` 平板多列浏览分支（无拖拽）+ **方案四半屏排序面板**（`bindSheet` + `ImmMaterial.sheet()`，面板内单列复用拖拽，`prepend=1` + 独立 Scroller；壳由讨论时的 `CustomDialog` 更正为 `bindSheet`——§6.8 已实证半模态为官方 A 档槽位）+ `CategoryThreadsView` 多列 lanes 分支（拖拽保留、索引基准组内 0 起）；⑦ 改动七 `dialogCardWidth()` 封顶 400。`tools/build.ps1` → **BUILD SUCCESSFUL**（31s）；**lint 0**；**待真机验收** | A 错位：**有 2 处、已规避**（lanes 通栏项占 1 格 → `ListItemGroup` header/footer 收纳；`WaterFlow` 混排通栏项 → 让位 / 占位移出流 + 无 sections 天然规避段计数竞态）。B 出屏：**无**（列宽全 `1fr` / `lanes` 均分；弹窗 / 面板封顶）。C 重叠：**无**（`PostCard` 无宫格区；面板拖拽复用已验证手绘让位，主列表多列无拖拽）。D 手机回归：**无**（手机 360：`favColumns()` 闸门恒 1 → 所有新分支不生效、走原结构逐像素不变；弹窗 312<400 不封顶；不弹排序面板；必测回归路径 = 手机收藏夹列表 / 点开列表 / 搜索态 / 自定义分类长按拖拽 / 六处弹窗 / **折叠屏展开 3 列 ↔ 折叠回单列**） |
| 2026-09-14 | **§4.3 容器二次更正（更新文档，不开工）**：用户复核发现**收藏夹点开后的列表卡片高度不一致**（`PostCard` 高度随文本行数可变）→ 改动三由 `lanes` **二次更正为 `WaterFlow` 瀑布流**（首拍「不用瀑布流」仅适用于等高的收藏夹列表）；收藏夹列表 `lanes` 维持不变，两列表容器**有意分叉**（等高 `lanes` / 可变高 `WaterFlow`）。改动三新增执行要点 4 条：① 顶部 98 让位与底部 90 占位**移出流**（通栏项严禁进 `WaterFlow`）；② 流内只有帖子一种格子 → **无需 `sections`**，§4.9/4.10 的段计数竞态坑天然规避；③ `PostCard` 无宫格区 → 无 Grid 高度坑；④ 无 scroller / 无 `onReachEnd` / 无分页 → 滚动与分页零牵动。状态汇总第 3 条、§三 第 3 项同步。**代码未改** | A 错位：**有 1 处、已规避**（`WaterFlow` 若混入通栏项会触发占 1 格错位 → 顶部 / 底部占位移出流、空态替换整流；`WaterFlow + sections` 段计数竞态因无混排天然规避）。B 出屏：**无**（列宽全 `1fr`；弹窗 / 面板封顶不变）。C 重叠：**无**（`PostCard` 无宫格区 → 无 Grid 自测量高度歧义；文本自然高即终值）。D 手机回归：**无**（手机 360：闸门恒 1 列 → 点开的列表仍走原 `List` 单列结构逐像素不变，`WaterFlow` 仅多列档生效；必测回归路径 = 手机收藏夹 / 点开列表 / 折叠屏展开 3 列 ↔ 折叠回单列） |
| 2026-09-14 | **§4.3 收藏页全量拍板转「已确认」（更新文档，不开工）**：用户拍板 4 项——① **列数竖 3 / 横 4**（收藏夹列表 / 点开的帖子列表 / 搜索态同口径，原「竖 2 / 横 3」作废）；② **容器不采用瀑布流**，改动三定案 `List + lanes`（理由「宽度和高度都一致」，行内留白 ≤54vp 接受；选项 A `WaterFlow` 出局留档），通栏项收 `ListItemGroup` header/footer 口径不变；③ **拖拽采用方案四**（排序收进半屏 CustomDialog 面板：入口不变、面板内单列复用现有拖拽状态机 → 长按保留 + `ImmMaterial.dialog()` 沉浸光感 + 零重写；方案一 / 三出局留档）；④ **弹窗不拉伸**：六处 `dialogCardWidth()` 封顶 T-H 同款 `max(200, min(400, 屏宽−48))`，手机档 312 < 400 逐像素不变。§4.3 改动二 / 三 / 四 / 五列数与代码块、改动六候选状态、风险 6.1 / 7、状态区汇总、§三 第 3 项全部同步。**代码未改** | A 错位：**有 1 处、已规避**（`lanes` 行内高度差留白 ≤54vp——用户拍板**接受**，非缺陷；收藏夹卡等高 80 无此问题；通栏项收 `ListItemGroup` header/footer 防 lanes 占 1 格错位〔风险 1 沿用〕）。B 出屏：**无**（列宽全 `1fr` / `layoutWeight`，无像素列宽；弹窗封顶后无通栏）。C 重叠：**无**（方案四面板内单列拖拽复用已验证手绘逻辑，不引入网格让位；主列表多列纯浏览无拖拽）。D 手机回归：**无**（手机竖屏 360：`favColumns()` 闸门恒 1 列走原 `List` 结构；弹窗 312 < 400 封顶不生效；面板宽 312 < 520 不生效且手机不弹面板；`ListRowSkeleton` 默认 1 列红线已记录；必测回归路径 = 手机收藏夹列表 / 分类内长按拖拽 / 六处弹窗宽度 / 折叠屏展开 3 列 ↔ 折叠回单列） |
| 2026-09-14 | **§4.3 收藏页增量讨论并入（更新文档，不开工）**：① 改动六拖拽候选新增**方案四**（排序收进半屏 CustomDialog 面板：入口不变、面板内单列复用现有拖拽状态机 → 长按触发保留 + `ImmMaterial.dialog()` 官方沉浸光感成立〔`bindSheet` 非官方槽位、自绘浮层 out of scope 均排除〕、拖拽零重写、主列表长按回归置顶语义），候选一 / 三 / 四留档待拍板；② 新增「2026-09-14 增量讨论」4 条：弹窗六处 `dialogCardWidth()` 封顶顺带项（T-H 同款，手机档零回归）/ 帖子卡多列容器补「列内独立堆叠 + 方案 B 分桶」备选（默认仍推 `lanes`）/ 骨架屏 `columns` 默认 1 红线 / 拖拽常数（80 / 92）脆弱点备忘；状态行候选数同步。**代码未改** | A 错位：**无**（纯方案留档，无几何改动；方案四面板为单列 `List`，与手机同款几何，无网格重排）。B 出屏：**无**（面板固定宽 `min(屏宽−48, 520)` + 高约 60% 屏，CustomDialog 自带遮罩边界）。C 重叠：**无**（面板拖拽复用已验证的手绘让位逻辑，不引入网格让位；多列浏览态不做拖拽）。D 手机回归：**无**（手机档不弹面板、走原「切模式 + 列表内拖拽」路径逐像素不变；弹窗封顶 `312 < 400` 不生效；面板宽 `312 < 520` 不生效；必测回归路径 = 手机自定义分类长按拖拽 + 六处弹窗宽度） |
| 2026-09-13 | **§4.2 首页多列档「行等高 + 互动栏底对齐」二次修正**：用户真机验证发现 `Blank()` 与 `SpaceBetween` 在复杂卡内均失效（多宫格卡操作栏丢失、纯文本卡被 `Scroll` 无限高度异常拉长）→ 最终把 `ThreadCard` 改为「内容区 `.layoutWeight(1)` 占满剩余空间 + 根 `Column` `.constraintSize({ maxHeight: 560 })` 上限护栏」，保持行容器 `Flex(Stretch)` + 卡片调用点 `.height('100%')` 不变；§4.2 决策 11 / 落地清单 #7 / 风险自检 C 行 / §6.1 A6·A7 同步刷新；`tools/build.ps1` → **BUILD SUCCESSFUL**；**待真机复验** |
| 2026-09-13 | **§4.10 楼中楼详情同步 §4.9 二次拍板（更新文档，不开工）**：用户指示「楼中楼一起改」→ 回复区改 `WaterFlow` 三列 / 宫格不拉伸左对齐 / 横屏左栏按内容宽；新增 **SP-G ~ SP-K**，一次方案「手写双列 / 4 : 6」作废。**与 §4.9 的三处不可照抄点**：① `sections` **段数 = 2**（本页无触底哨兵，省略段 2）；② 间距语言 = `Spacing.sm`(8)（非 `Spacing.md`12）；③ 卡内追加间距的**全局下标判定**需重算（多列后每列末条多留 8vp → 列底空洞；改法：挪到 `rowsGap` 或传列内下标）。`syncSections()` 挂点**多一处**：`locateNotifyTarget()` 追加 `commentsState` 时同步（漏了 `itemsCount` 不匹配 → **整页无法滚动**）。SP-H 锚点 `spc_` 随卡入 `FlowItem`；SP-J 本页 `ImageGrid` 独立实现需单独加 `maxWidth`；SP-K 沉浸层仅 `overlay` + `blendMode` 两项且遮罩为 `height('100%')` 整区形态，**两项同层同迁**后真机复验底部渐隐。待拍板点 5 / 6 / 7 沿用 §4.9 拍板值；状态行同步「§4.6 H-B 已非阻塞」。**代码未改** |
| 2026-09-13 | **§4.9 帖子详情二次拍板（更新文档，不开工）**：用户同日二次拍板 → 竖屏「帖子内容不动 + **宫格图不拉伸不放大且左对齐** + 回复区改**首页 `WaterFlow` 瀑布流三列**」、横屏「左帖右回复、回复区**三列瀑布流**、**帖子区域宽度 = 帖子本身宽度**」。文档更新：§4.9 新增「二次拍板」块 + **DT-G ~ DT-J**（DT-G `WaterFlow`+`sections` 跨列〔含 5 条硬约束：`itemsCount` 累计和必须等于子节点数、哨兵须恒渲染、`sections` 是构造参数、不设 `onGetItemMainSizeByIndex`、`itemsCount` 不得为 0〕；DT-H 定位锚点随卡入 `FlowItem`；DT-I 横屏左栏固定宽取代 4 : 6；DT-J `ImageGrid` 加 `maxWidth` 实现不拉伸 + 自动左对齐，一改三处且手机档不生效），标注一次方案的「手写双列 / 4 : 6」作废；新增待拍板点 5 / 6 / 7；状态行更正「§4.6 H-B 已非阻塞（可照抄 §4.8 本地判据写法）」；§4.10 加同步提醒（本页是否沿用待确认，且无触底哨兵 → DT-G 段 2 应省略）。**代码未改**（用户明确不开工） |
| 2026-09-13 | **§4.8 T-I 吧头多列档居中（当日回退）**：用户先要求「吧头改成居中对齐」→ `ForumHeaderBuilder` 外层 `Row` 加 `.constraintSize({ maxWidth: 多列档 ? 480 : 99999 })`（父层 `Column` 交叉轴默认居中 → 限宽即居中）；**同日用户拍板「还是回退到左对齐吧」→ 已移除该限制与常量，恢复左对齐铺满**。技术路径已验证可行（仅需限宽），留待将来复用；`tools/build.ps1` → **BUILD SUCCESSFUL** |
| 2026-09-13 | **§4.8 T-H 吧主页「更多」弹窗几何统一**：用户真机反馈平板下弹窗被拉成通栏、且纵向位置与全站不一致 → `dialogCardWidth()` 改为 `max(200, min(400, 屏幕宽 − 48))`（新增常量 `THREAD_LIST_DIALOG_MAX_WIDTH = 400`；手机档 312 < 400 逐像素不变），`moreSheetController.offset.dy` 由 **-30 → -110**，与收藏页 / 进吧页置顶弹窗完全一致（手机档同样生效）。全站盘点：`Favorite` 六处 / `ForumsTab` 两处 = -110，`ThreadDetail` = -140（有专属理由、勿动）。`tools/build.ps1` → **BUILD SUCCESSFUL**（1m09s）；**待真机验收** |
| 2026-09-13 | **§4.8 T-G 转场适配（吧头静止且不被遮挡）+ 数据侧缺陷修复**：用户真机反馈平板下「最新 / 热门 / 精选」切换**闪一下直接过去 + 画面重叠**，追加要求「转场时吧头不要跟着切换」，再反馈「吧头被遮挡后再出现」→ 多列档换 `WaterFlow` 时漏了排序过场配套：① 新页缺位移（单列档位移挂在「列表区 Stack」，多列档无对应挂点）；② 旧页快照裁剪恢复**单列 / 多列同款**（裁掉吧头）；③ 多列档骨架屏漏 `skeletonOpacity`；④ **位移最终改为逐张帖子卡片**（`.translate({ x: this.sortShiftX() })`，按根容器实测宽把 ±100 百分比换算成 vp）→ `WaterFlow` 与吧头完全静止（首版「容器整页位移 + 吧头反向位移」会被虚拟容器的渲染区裁掉吧头，已弃用）。同批修掉同源数据缺陷：`syncListDataSource()` 改**逐项比对前缀**判定追加（原先只比长度，切排序变长会误判追加 → 前段不重建、内容错乱），`HomeTab` 的 `onThreadsChange` / `onFolThreadsChange` 一并改为 `syncSource()`；`syncSections()` 加 `lastSectionKey` 去重（避免过场中同帧重复重排）；`tools/build.ps1` → **BUILD SUCCESSFUL**（1m03s）；**待真机验收** |
| 2026-09-13 | **§4.8 吧内帖子列表多列档改为 `WaterFlow` 瀑布流（T-G，与首页决策 12 对齐）**：用户真机反馈行分组仍拉伸置顶卡/留白大 → 多列档改用 `WaterFlow({ scroller, sections: this.sections })` + 静态 `FlowItem`（吧头）+ `LazyForEach(this.listDataSource)`（帖子）；用 `WaterFlowSections` 让**吧头跨列并随内容滚动**（用户追加要求「吧头不要固定在顶部」）：section 0 = 吧头（`crossCount 1` 独占整行）、section 1 = 主体（`crossCount 3/4` 多列）；置顶卡作为**普通格子**、不拉伸、独立卡面（取消通栏标签行与整体卡）；新增 `ThreadListDataSource` + `waterFlowThreads()`（置顶在前合并）+ `syncListDataSource()` + `syncSections()`（挂 `onThreadsChanged` / `onLoadStateChanged` / 形态变化三处，保证 `itemsCount` 与子节点数一致）；单列档/搜索态保持原 `Scroll` 结构逐像素不变；已知取舍见 §4.8 T-G；`tools/build.ps1` → **BUILD SUCCESSFUL**（1m02s）；**待真机验收** |
| 2026-09-13 | **§4.8 吧内帖子列表已落地 + 构建通过**：用户拍板 5 项后开工（① 列数跟首页 = 竖 3 / 横 4；② 置顶区纳入多列网格（标签行仍通栏，`PinnedThreadItem` 包 `Column().layoutWeight(1)` + 独立 `bgCard`/`borderRadius(26)`，末行补空位 `pin_gap_`）；③ 前置依赖已解除；④ **T-F 三项不拉伸**（经验条 `maxWidth 220` + 签到钮补 `Blank()` 保右缘 / 底栏 `sortBarWidth()` 上限 `244` / FAB 几何固定不动）；⑤ **FAB 锚点选 B + 整体居中**（新增 `BottomGroupShell()` 把底栏 + 缝 12 + FAB 合并为 `Row`；净宽 336vp，**多列档居中 / 单列档保持现状左对齐**，居中条件化）。`ThreadList.ets` 实际落地 T-B/C/D/E/F 六项（`threadColumns()` / `syncCardColumns()` / `onListFormAreaChange()` / `threadRows()` / `threadBlankSlots()` / `BottomGroupShell()` + 常量 `THREAD_LIST_SORT_BAR_MAX_WIDTH` / `THREAD_LIST_EXP_BAR_MAX_WIDTH`；`aboutToAppear` 首帧取宽高；根 `Stack.onAreaChange` 挂形态；删除原硬编码 `cardColumns = 1`）；§4.8 全部小节 + 状态同步；`tools/build.ps1` → **BUILD SUCCESSFUL**（1m01s）；**待真机验收**（竖 3 / 横 4 + 置顶网格 + 搜索态多列 + 三项不拉伸与居中 + 手机单列逐像素回归） |
| 2026-09-13 | **§4.2 首页多列档「`WaterFlow` 瀑布流」全面落地（决策 12 完成）**：最小验证页真机通过后删除，`EntryAbility` 入口切回 `pages/Index`；`HomeTab.ets` 推荐流 + 关注流两条 feed 多列分支统一改为 `WaterFlow` + `LazyForEach(this.recDataSource/folDataSource)`（`ThreadDataSource` 实现 `IDataSource` + `@Watch` 自动同步，`reload()`/`notifyAdd()` 区分全量与追加）；**竖屏 3 列 / 横屏 4 列**由 `display.on('change')`（`updateColumns()`）+ `checkFormChange()`（分屏/窗口兜底）驱动，`columnsTemplate` 动态绑定，同步 `AppStorage('cardColumns')` 与骨架 `ThreadListSkeleton({ columns })`；`ThreadCard` 删除 `layoutWeight(1)`/`maxHeight 560`，`HomeTab` 删除卡片调用点 `.height('100%')`；§4.2 决策 12 / 待办 / 风险自检四行同步刷新；`tools/build.ps1` → **BUILD SUCCESSFUL**；**待真机验收**（竖屏 3 / 横屏 4 切换 + 快速滚动稳定性 + 多宫格卡操作栏 + 手机单列回归） |
| 2026-09-13 | **§4.2 首页多列档「`WaterFlow` 瀑布流」最小验证启动（决策 12）**：决策 11 的 `Flex` 等高方案在复杂卡内仍失效（操作栏丢失 / 异常拉长 / 卡片内部空白过大）→ 改用官方瀑布流组件 `WaterFlow` + `LazyForEach` + 自然高度 `ThreadCard`；新建临时验证页 `pages/PilotWaterFlow.ets`（30 条混合图数模拟数据），`EntryAbility` 临时入口指向该页；`ThreadCard` 已删除为 Flex 方案加的 `layoutWeight(1)` / `constraintSize({ maxHeight: 560 })`，`HomeTab` 已删除卡片调用点 `.height('100%')`；§4.2 新增决策 12 + 待办 / 风险自检四行同步刷新；`tools/build.ps1` → **BUILD SUCCESSFUL**；**待真机验收 4 项**（`floor-vanish` 稳定性 / 图片加载布局跳动 / 多宫格卡操作栏可见性 / 不等高视觉紧凑性） |
| 2026-09-13 | **§4.2 首页多列档「行等高 + 互动栏底对齐」首落修正**：用户真机验证发现「多宫格卡操作栏丢失 / 卡片异常拉长」→ 立即把 `ThreadCard` 内部由卡内 `Blank()` 垫片改为根 `Column` 的 `.justifyContent(FlexAlign.SpaceBetween)`（内容区置顶、操作栏贴底），保持行容器 `Flex(Stretch)` + 卡片调用点 `.height('100%')` 不变；§4.2 决策 11 / 落地清单 #7 / 风险自检 C 行 / §6.1 A6·A7 同步刷新；`tools/build.ps1` → **BUILD SUCCESSFUL**；**待真机复验** |
| 2026-09-13 | **§4.2 首页多列档「行等高 + 互动栏底对齐」二次落地（先最小 Demo 实证）+ 构建通过** → **新增决策 11**。起因：用户提出「那些会留空的卡片能否自适应拉伸做视觉对齐」。做法：**先不碰主源码**，新建独立最小验证页 `pages/PilotStretch.ets`（临时；6 组容器/高度对照 + `onAreaChange` 尺寸探针 + 胶囊点击计数；`main_pages.json` 注册 + `EntryAbility` 临时入口），真机取得读数 —— ①`Row` 无高度 `680×302 / 680×142`（现状留空）；②`Row` + `height('100%')` `440×1328 / 440×1328`（行被 `Scroll` 撑高，弃）；③`Flex(Stretch)` 无高度 `440×302 / 440×142`（容器单独拉不动）；④`Flex(Stretch)` + `height('100%')` `680×848 / 680×848`（等高成立）；⑤④+`Blank()`、⑥④+`SpaceBetween` 均 `680×848` 等高、三胶囊可见且点击计数正常 → **定位决策 8 的真正缺失项 = 卡根 `height('100%')`**。随后清理 Demo（删页 + `main_pages.json` 注销 + `EntryAbility.loadContent` 切回 `pages/Index`）并落地：`HomeTab.ets` 两条 feed 行容器 `Row` → `Flex({ alignItems: ItemAlign.Stretch, space: { main: LengthMetrics.vp(Spacing.md) } })`（新增 `import { LengthMetrics } from '@kit.ArkUI'`）、卡片调用点补 `.height('100%')`；`CommonComponents.ets` 的 `ThreadCard` 按 `cardColumns > 1` 在内容区与操作栏之间插 `Blank()`；`Skeleton.ets` 多列分支同步换 `Flex` + `Stretch`、`ThreadCardSkeleton` 增 `@Prop stretch`（默认 `false`，首页骨架传 `true`）。§4.2 决策 11 + 状态行 + 落地清单 #3/#7/#8 + 待办 + 风险自检四行、§6.1 A6 / A7 表项、顶部更新日志同步；`tools/build.ps1` → **BUILD SUCCESSFUL** | A 错位：**有 1 处、已改（待真机销项）**（A6 行内高度差留白由「接受」升级为**主动消除**：行等高后同行底边齐、按钮贴底；A7 由「不可照搬」修正为「**有条件可行 — 三条件缺一不可**」；A1 末行补位 / A2 卡宽来源 `layoutWeight(1)` / A3 / A4 / A5 均未动）；B 出屏：**无**（`Flex` 无 `wrap`、主轴 `space` 只占行内，行高 = 该行最高卡自然高，卡片 `height('100%')` 只作用于交叉轴且上限即行高；左右外边距与卡片 `width('100%')` 未变）；C 重叠：**有 1 处风险、已加护栏**（卡内 `Blank()` 失去确定高度参照会把操作栏挤出卡外 = 决策 8 现象，现由卡根 `height('100%')` 提供确定参照消除；护栏 = 真机验收项「最高卡操作栏三胶囊可见可点」；C1 底栏让位 150 / C2 回顶钮几何未动）；D 手机回归：**无**（`Flex` 与 `.height('100%')` 只写在 `homeColumns() > 1` 的行分组分支，单列仍走原 `ForEach` + `.margin` 结构〔D2 已防〕；`ThreadCard` 垫片由 `cardColumns > 1` 把关、单列 `Blank` 高度为 0〔D1 复用「无条件写 1」机制〕；`ThreadCardSkeleton.stretch` 默认 `false`、仅首页两处骨架传 `true`〔D3 已防〕；必测回归路径 = 折叠屏展开 3 列 ↔ 折叠回单列） |
| 2026-09-13 | **§4.2 首页横屏列数 2 → 3（撤销决策 9、恢复横屏 3 列，用户拍板「现在方案 B，横屏还是改为三列」）+ 构建通过** → **新增决策 10**。`HomeTab.ets`：恢复 `isLandscape()`（`pageWidth > pageHeight` 宽高比判定）并把 `homeColumns()` 末行由恒 `2` 改回 `this.isLandscape() ? 3 : 2`（大屏横屏 3 / 竖屏 2；手机 / 窄窗仍 1 列，首行 `isWideFormDevice` 闸门未动）；仅「列数判据」一处改动（+ 恢复 1 个私有方法及其注释），容器（`Scroll` + `Column` + 行分组 `Row` + `VerticalAlign.Top`）/ 卡片几何 / 骨架屏 / 预加载 / `cardColumns` **全部零改动**（列数消费方经 `homeColumns()` 单点取值自动跟随）。改动前备份 `HomeTab_20260913_restore3col.ets`；还原后与横屏 3 列基线 `HomeTab_20260913_landscape2col.ets` 逐行比对**仅注释差异、无逻辑残留**；`tools/build.ps1` → **BUILD SUCCESSFUL**（45s）。§三 第 1 项、§4.2 需求 / 决策 9（标撤销）/ 新增决策 10 / 状态行 / 落地清单 #3 #5 / 留痕、§6.1 A6 与「多列写法共三套」第 ① 条同步。 | A 错位：**有 1 处（接受）**（A6 行内高度差留白回到决策 9 之前水平：横屏 3 列下列宽变宽、更多单图卡触到 `maxHeight 220` 封顶 → 「9 图卡 vs 无图文本卡」极端组合概率高于 2 列，落差本身不消除，彻底消除仍只有「定高 + 裁内容」或「列内独立堆叠」；A7 行等高踩坑档案维持「不可照搬」；A1 末行补位 / A2 卡宽来源 `layoutWeight(1)` / A3 / A4 / A5 均未动）；B 出屏：**无**（列宽仍 `layoutWeight(1)` 均分、卡片 `width('100%')`、无横向滚动；3 列下列宽反而变窄〔1280 屏可用宽 1248 → 单列 ≈ 408vp〕，纵向仍受 `maxHeight` 封顶不撑高）；C 重叠：**无**（`Row` 顶对齐、底边自然错落；C1 底栏让位 150 / C2 回顶钮几何未动）；D 手机回归：**无**（首行 `isWideFormDevice` 闸门未动，改动只落「大屏 + `pageWidth ≥ 600`」分支的横竖映射 → 手机含横屏 / 分屏 / 自由多窗恒 1 列、逐像素不变；恢复的 `isLandscape()` 唯一调用点仍在 `homeColumns()` 内、`Skeleton` / `ThreadList` / `UserProfile` 无引用；`cardColumns` 无条件写 1 与 `ThreadList` / `UserProfile` 调用点零改动〔D1 / D3 / D6 无残留面〕；必测回归路径 = 横屏 3 列 → 旋转竖屏 2 列 → 折叠回单列） |
| 2026-09-13 | **§4.2 首页横屏列数 3 → 2（用户取「方案 A」：只改列数、不动容器与卡片内部）+ 构建通过**。`HomeTab.ets` 的 `homeColumns()` 由 `this.isLandscape() ? 3 : 2` 改为恒 `2`（大屏横竖统一 2 列；手机 / 窄窗仍 1 列，首行 `isWideFormDevice` 闸门未动）；删除已无调用点的 `isLandscape()`，保留 `pageHeight`；容器 / 卡片几何 / 骨架 / 预加载 / `cardColumns` 全部零改动（列数消费方经 `homeColumns()` 单点取值自动跟随）。备份 `BACKUP_TS=20260913_landscape2col`；`tools/build.ps1` → **BUILD SUCCESSFUL**。§三 第 1 项、§4.2 需求 / 决策 9 / 状态行 / 落地清单 / 留痕、§6.1 A6 与「多列写法共三套」第 ① 条同步。 | A 错位：**有 1 处（接受）**（A6 行内高度差留白：2 列只降低极端组合概率、不消除落差，仍按「接受」；A7 行等高踩坑档案维持「不可照搬」结论；A1 / A2 / A3 / A4 / A5 未动）；B 出屏：**无**（列宽仍 `layoutWeight(1)` 均分、卡片 `width('100%')`；收 2 列后列宽变宽，但单图 / 多图格仍受 `maxHeight` 封顶、纵向不撑高）；C 重叠：**无**（`Row` 顶对齐、底边自然错落；C1 底栏让位 150 / C2 回顶钮几何未动）；D 手机回归：**无**（首行 `isWideFormDevice` 闸门未动 → 手机含横屏 / 分屏 / 自由多窗恒 1 列；删除的 `isLandscape()` 仅服务列数判定、无其它调用点；`cardColumns` 无条件写 1 与 `ThreadList` / `UserProfile` 调用点零改动〔D1 / D3 / D6 无残留面〕） |
| 2026-09-13 | **§4.2 首页多列档「行等高 + 互动栏底对齐」回退**（用户真机反馈「不仅没有拉伸对齐，最高卡按钮还消失了」）：立即用 `BACKUP_TS=20260913_planb` 还原 `HomeTab.ets` / `CommonComponents.ets` / `Skeleton.ets` 三文件到无拉伸方案 B 状态；撤销 `Flex` + `ItemAlign.Stretch`、撤销 `ThreadCard` 内 `Blank()` 垫片、撤销骨架 `@Prop stretch`；`tools/build.ps1` → **BUILD SUCCESSFUL**。§4.2 决策 8 改为「已尝试并回退」、状态行 / 落地清单 #3/#7/#8 / 末尾 A/B/C/D 留痕同步回退；§6.1 A6 恢复「接受」、A7 更新为踩坑记录；§6.1「多列写法共三套」第 ① 条同步修正。 | A 错位：**有 1 处（接受）**（A6 行内高度差留白恢复为「接受」：行分组 `Row` + `VerticalAlign.Top` 不可避免，已通过决策 6「摘要降 2 行 + 图片封顶」削弱落差；新增 **A7** 记录「行等高尝试失败 → 最高卡操作栏消失」的踩坑档案，警示后续复用者不可照搬）；B 出屏：**无**（列宽仍 `layoutWeight(1)` 均分、卡片 `width('100%')`、无横向滚动，回退后无 `Flex` 与 `LengthMetrics` 新依赖）；C 重叠：**无**（行内卡片顶对齐、底边自然错落，不互相遮盖；无新增悬浮层 / 绝对定位）；D 手机回归：**无**（回退后代码与 planb 备份完全一致，无新增多列分支逻辑；`cardColumns` 无条件写 1 机制未动；`ThreadList` / `UserProfile` 调用点零改动） |
| 2026-09-13 | **§4.2 首页多列档「行等高 + 互动栏底对齐」落地 + 构建通过**（用户「先试试吧，我希望内容顶对齐 + 互动栏底对齐」；改动前备份 3 文件 `BACKUP_TS=20260913_stretch`）→ **新增决策 8**。`HomeTab.ets` 两条 feed 的多列行分组容器 `Row` → `Flex({ direction: FlexDirection.Row, alignItems: ItemAlign.Stretch, space: { main: LengthMetrics.vp(Spacing.md) } })`（新增 `import { LengthMetrics } from '@kit.ArkUI'`）；`CommonComponents.ets` 的 `ThreadCard` 按 `cardColumns > 1` 在内容区与操作栏之间插 `Blank()` 垫片；`Skeleton.ets` 多列分支同步 `Flex` + `Stretch`、`ThreadCardSkeleton` 增 `@Prop stretch`（默认 `false`，首页骨架传 `true` → 纸面 `height('100%')`）。§4.2 决策 8 + 状态行 + 落地清单 #3/#7/#8、§6.1 **A7**（+ A6 补注）、§6.1「多列写法共三套」第 ① 条、§6.2 已过检记录、顶部更新日志同步；构建 `tools/build.ps1` → **BUILD SUCCESSFUL** | A 错位：**有 1 处、已销**（A6 行内高度差留白 —— 首页多列档由「接受」升级为**主动消除**：行等高后同行卡片底边对齐、无行内留白；新增 **A7** 记录两条硬要点「拉伸交叉轴必须 `Flex` + `ItemAlign.Stretch`，`Row` 无 `Stretch`」+「卡内必须 `Blank()` 垫片才能把操作栏压底」；A1 / A2 不变 —— 末行仍补等宽 `Blank`、卡宽来源仍 `layoutWeight(1)`；A3 / A4 / A5 均未动）；B 出屏：**无**（列宽仍 `layoutWeight(1)` 均分、行容器 `width('100%')` + 主轴 `space` 只占行内、不改左右外边距；卡片仍 `width('100%')`、无横向滚动；`Flex` 无 `wrap`）；C 重叠：**无**（行高由最高卡决定，同行卡片底边对齐但不互相遮盖；`Blank` 垫片只吸收卡内纵向剩余，不改任何绝对定位 / 悬浮层；C1 底栏让位 150 / C2 回顶钮几何未动）；D 手机回归：**无**（三处新逻辑全部挂在 `cardColumns > 1` / 多列分支内 —— `ThreadCard` 垫片条件插入、`Flex` 只在 `homeColumns() > 1` 的行分组分支、`ThreadCardSkeleton.stretch` 默认 `false` 且仅首页两处骨架传 `true`〔`ThreadList` / `UserProfile` 调用点零改动，D3 已防〕；手机竖屏 360 仍是单列 `ForEach` 原结构 + 卡高自适应〔`Blank` 高度为 0〕→ 逐像素不变；`cardColumns` 无条件写 1 机制未动，D1 / D6 不受影响） |
| 2026-09-13 | **§4.2 首页真机首测否决方案 A → 改**方案 B（行分组）**落地 + 构建通过**（用户「不行，改方案 B」；改动前备份 3 文件 `BACKUP_TS=20260913_planb`）。`HomeTab.ets` 两条 feed 由 `WaterFlow + FlowItem` 回退为 `Scroll + Column` + `homeRows()` / `homeRowBlanks()` / `homeRowKey()` 行分组（末行补等宽 `Blank`），**单列档显式走原 `ForEach` 逐像素不变**；预加载由 `onScrollIndex` 回退 `onAreaChange` 量内容高（`HOME_PREFETCH_DISTANCE = 1200`，恢复 `homeContentH` / `folContentH` / `folViewportH` / `homeLastPrefetchY` / `folLastPrefetchY`）；`Skeleton.ets` 多列分支同步改为行分组（与真实列表同结构）；保留图片高度封顶。§三 第 1 项、§4.2 状态行与落地清单、顶部更新日志同步；构建 `tools/build.ps1` → **BUILD SUCCESSFUL** | A 错位：**有 1 处已销、1 处转无**（A4 外边距单一来源 `Spacing.lg` 未变；A5 首帧列数跳变仍由 `aboutToAppear` 同步取宽高兜底；**原方案 A「`WaterFlow` 各列独立堆叠 → 相邻列落差被大图放大（用户真机感知为错位）」随容器回退方案 B 一并消除** —— 行内 `VerticalAlign.Top` 顶对齐，同行卡片不再错位；A2 —— 行分组**末行已补等宽 `Blank`**、卡宽恒定）；B 出屏：**无**（列宽 `layoutWeight(1)` 均分、卡片 `width('100%')`；多列档摘要 `maxLines 2` + 图片封顶 → 不撑高定高容器）；C 重叠：**无**（方案 A 那 1 处 `WaterFlow` 虚拟滚动 `floor-vanish` 风险**随回退方案 B 消除**，`Scroll` 全量渲染非虚拟滚动；C1 底栏让位 150 保持原结构、C2 回顶钮几何不动）；D 手机回归：**无**（`homeColumns()` 首行 `if (!isWideFormDevice) return 1` 恒 1 列；**单列档显式分支走原 `ForEach` + `.margin` 结构**、未套行分组容器〔D2 已防〕；`cardColumns` 无条件写 1 且三处挂点未动〔D1/D6 已防〕；`ThreadListSkeleton` 默认 `columns = 1`、5 处调用点零改动〔D3 已防〕；手机竖屏 360 逐像素不变） |
| 2026-09-13 | **§4.2 首页真机首测后修复：多列档图片高度封顶**（`components/CommonComponents.ets`：单图 `.constraintSize({ maxHeight: 220 })`、多图格按 2/4 张 140 / 其余 100 封顶）。原因：多列下列宽变宽后 `aspectRatio(1.6)` 会同比放大图高，真机出现「图比手机还大」、瀑布流错落感被进一步放大；封顶后图高不超过手机基线。仍保留 `WaterFlow` 容器；若封顶后错位仍无法接受，再评估回退 §4.2 方案 B（行分组 / Grid）。§4.2 落地清单第 7 项、顶部更新日志同步。构建 `BUILD SUCCESSFUL` | A 错位：**有 1 处（已落地）** + **1 条新增约束**（图片封顶后单图卡高度被限制，瀑布流相邻列落差缩小；但「列内独立堆叠」仍是 WaterFlow 固有特性，若用户不接受只能换方案 B，属后续决策项，本轮仅做封顶）；A1 / A2 / A3 / A5 结论同前；B 出屏：**无**；C 重叠：**有 1 处（未销，同前）**（`WaterFlow` 虚拟滚动 `floor-vanish` 真机 A/B 门仍待执行）；D 手机回归：**无**（封顶只影响 `cardColumns > 1` 分支，单列手机路径代码未动；`ThreadList` / `UserProfile` 等共享组件默认 `columns = 1`、不写 `cardColumns`，逐像素不变） |
| 2026-09-13 | **§4.2 首页（`HomeTab`）平板适配落地 + 构建通过**（用户指示「先试试落地首页，开工，同时进行备份，同时进行构建」；改动前备份 4 文件，`BACKUP_TS=20260913_141920`）。落地 9 项见 §4.2「落地清单」（`deviceTypes` 加 `"tablet"` / `Theme` 加 `Breakpoint` + `CARD_COLUMNS_KEY` / 两条 feed 换 `WaterFlow`〔单 1 竖 2 横 3〕/ 预加载判据迁 `onScrollIndex` / `aboutToAppear` 同步取首帧宽高 / 渐隐带夹取 `[108,180]` / `ThreadCard` 三处几何比例化限多列档 / `ThreadListSkeleton` 增 `columns`〔默认 1〕/ `cardColumns` 无条件写 + 三处挂点 + `ThreadList` 显式写回 1）；构建 `tools/build.ps1` → **BUILD SUCCESSFUL**；§三 第 1 项状态、§4.2 状态行与落地清单、顶部更新日志、文件头「交付类型」同步 | A 错位：**有 1 处 + 1 条硬约束，均已落地**（A4 —— 顶栏与卡片区外边距单一来源 `Spacing.lg`〔`HOME_SIDE_GUTTER`〕，未为大屏单独放大留白；**A5 —— 首帧列数跳变**：`pageWidth` / `pageHeight` 初值 0 只在 `onAreaChange` 纠正 → 冷启动平板横屏会「先 1 列再跳 3 列」，已在 `aboutToAppear` 用 `display.getDefaultDisplaySync()` 同步取真实窗口宽高、`onAreaChange` 仅兜底〔§4.6 H-A 同源〕）；**A1 / A2 / A3 / A6 均不适用或为无**（A1 —— 网格内无通栏项：骨架屏与空态是 `WaterFlow` 的兄弟分支、底部 150 走 `WaterFlow` 自身 `.padding`，不进列；A2 —— `WaterFlow` 列宽恒定、无末行拉伸、不需 `blankSlots()`；A3 —— 本页顶栏非槽位 / 兜底双路径改造，未动；A6 —— 行内对齐留白正是选型 A `WaterFlow` 的收益，故无此项）；B 出屏：**无**（列宽 `1fr` 均分、卡片 `width('100%')`、无横向滚动；`expandSafeArea` 只扩上 / 下；摘要已按列数收紧 `maxLines`，多列档 2 行不撑高定高容器）；C 重叠：**有 1 处（未销，挂真机门）**（`WaterFlow` 虚拟滚动 + 沉浸 `clip(false)` 组合下「列表项滚过某横线后整层不绘制」的 `floor-vanish` 风险，与 §4.4 同源、本页尚未验证；**规避 = 真机 A/B 前置门**，复现即回退方案 B；C1 底栏让位 150 未变、C2 本页回顶钮几何不动 → 无新增遮挡）；D 手机回归：**无**（`homeColumns()` **首行** `if (!isWideFormDevice) return 1` → 手机含横屏 / 分屏 / 自由多窗恒 1 列〔D4 已防〕；列 = 1 时 `columnsTemplate = '1fr'`、`cachedCount = 3`，与改造前单列观感一致；`cardColumns` **无条件写 1** 且 `aboutToAppear` / `onPageShow` / `onAreaChange` 三处都写、`ThreadList.ets` 显式写回 1〔D1 / D6 已防〕；`ThreadListSkeleton` `columns` 默认 = 1，`ThreadList` / `UserProfile` 等 5 处调用点**零改动**、仍单列铺排〔D3 已防〕；摘要 `maxLines` 与图片 `aspectRatio` 均限 `cardColumns > 1` 生效 → 手机竖屏 360 逐像素不变）；**待真机验证项 1 条**：`WaterFlow` 长列表滚动卡片可见性（= C 类那 1 处的前置门） |
| 2026-09-13 | **§4.10 楼中楼详情（`SubPostDetail`）按推荐确认 → 转「已确认」**（用户「按推荐确认」→ 5 个待拍板点全部采纳：交替分列 / 骨架屏**不适用**〔本页无骨架屏，日后新增则 `columns` 默认必须 = 1〕/ 分栏 **4 : 6** / 横屏右栏**维持 2 列**挂真机复核 / **抽 `CommentCard(comment, index, total)` @Builder〔本页私有〕**）；三处本页专属差异仍为执行红线（底部留白 `Spacing.xl`(20)／间距语言 8／装饰层仅两项）；§三 第 10 项状态、§4.10 待拍板点表头与状态行、顶部更新日志同步 | A 错位：**有 1 处**（卡内 8vp 追加间距按**全局下标**判定 → 分列后每列末条多 8vp、列底空洞；**已拍板抽 `CommentCard(comment, index, total)`** —— 分列传列内下标 + 列长度、单列传全局下标 + 总数，单列结果与现状逐像素一致）；B 出屏：**无**（列 / 栏全 `layoutWeight` 均分、卡片 `width('100%')`、无横向滚动、`expandSafeArea` 只扩上 / 下）；C 重叠：**有 1 处**（1024 横屏右栏内容宽 ≈ 258vp < 手机基线 ≈ 294vp，`ImageGrid` 3 列每格 ≈ 78vp 偏瘦 → **已拍板维持 2 列 + 4 : 6**、挂真机复核；**不动 `ImageGrid` 几何**；C2 本页无底部悬浮层 → 无让位冲突，底部留白 20 分栏后两栏各自 20）；D 手机回归：**无**（恒 1 列 + 不分栏 + 原 `ForEach` 与间距判定一字不动 + 装饰层挂点不变；本页不写 `cardColumns`；`CommentCard` 为本页私有 Builder → 无 D1 / D3 / D6 残留面） |
| 2026-09-13 | **§4.11 用户主页 / §4.12 个人内容转「已确认」**（用户「按推荐值拍板，后续有需要才改」→ 两节 10 个待拍板点全部按推荐采纳：列数口径沿用 `600`〔不新增第三套〕、§4.11 横屏头部**不限宽**、骨架屏**不按列铺**、**接受** `lanes` 行内高度差留白、列间距 §4.11 = `Spacing.sm`(8) / §4.12 = `Spacing.md`(12)〔各同源于自身行间距〕、§4.12 窄列底行溢出走**规避 ②**〔底行 `maxLines(1)` + `textOverflow`、吧名 `layoutWeight(1)` 替 `Blank()`〕、`lanes(1)` 失败则**两页一起改双 `List` 双分支**、§4.12 预取失效则**多列分支放宽阈值**保 `onReachEnd` 兜底）；§三 第 11 / 12 项状态、两节待拍板点小节标题与状态行、顶部更新日志同步 | A 错位：**有 3 处**（A1 通栏项须迁 `ListItemGroup.header/footer` 并保持 `List.sticky` 默认 `None`；A5 首帧列数跳变〔§4.11 复用 `currentWidth` 初值 360、§4.12 无任何形态状态〕→ `aboutToAppear` 同步取宽高；A6 `lanes` 行内高度差留白 ≈ ≤38vp → 接受）；A2 末行拉伸**不适用**（`lanes` 列宽恒定、无 `blankSlots()`）；B 出屏：**无**（`lanes` 均分列宽 + `expandSafeArea` 只扩上 / 下）；C 重叠：**各 1 处**（§4.11 折叠展开横屏 750 三列 ≈ 234vp → 吧卡文字列 ≈ 124vp 截断，**已拍板接受**并并入 §4.8 口径收口项；§4.12 卡内文本宽 ≈ 199vp → 底行溢出**盖右列**，**已拍板走规避 ②**；两节 C2 底部悬浮让位均为**无**）；D 手机回归：**无**（形态闸门恒 1 列含手机横屏 / 分屏 / 自由多窗；列 = 1 走原裸 `ListItem`、不套 `ListItemGroup`；§4.11 两处骨架屏不加 `columns`、§4.12 无骨架屏；两页均不写 `cardColumns` → 无 D1 / D3 / D6 残留面）；**5 条落地验证项保留**（§4.11：`lanes(1)` 等价性、`ListItemGroup` 内行间距；§4.12：`onScrollIndex` 多列语义、`lanes(1)` 等价性、规避 ② 单列视觉等价） |
| 2026-09-13 | **新增 §4.12 个人内容（`PersonalContent`）方案（待确认，与 §4.11 同范式）** —— 用户拍板「两页采用同一方案」：本页**无用户信息区**（只有槽位标题栏 + 单一 `List()`），故 §4.11 的「用户信息居中」三条约束**不适用**，其余全盘复用（`.lanes(列数, Spacing.md)` + 顶部 98 占位迁 `ListItemGroup.header`）；§三 第 11 项转「已出方案（待确认）」、§4.11 标题收窄为「用户主页」+ 适用范围澄清改写、§6.1 **例外六** + A1 / A5 / A6 / C2 表项 + 「多列写法共三套」第 ③ 条、§6.2 二级页清单（底部让位数值清单扩为四页）+ 已过检记录 | A 错位：**有 3 处**（A1 —— 顶部 98 占位须迁 `ListItemGroup.header`，附「保持 `List.sticky` 默认 `None`」护栏；A5 —— 本页**无任何形态状态**（无 `pageWidth`、无 `onAreaChange`）→ 冷启动平板横屏必「先 1 列再 3 列」，改 `aboutToAppear` 同步取宽高并补 `deviceInfo` / `display` import；A6 —— `lanes` 行内高度差留白 ≈ ≤38vp → 接受）；A2 末行拉伸**不适用**（`lanes` 列宽恒定、无 `blankSlots()`）；B 出屏：**无**（`lanes` 均分列宽 + `expandSafeArea` 只扩上 / 下；风险 5 的溢出越的是**列边界**、记 C 类）；C 重叠：**有 1 处**（折叠展开横屏 750 三列 → 卡内文本宽 ≈ 199vp，`Row` 子项 `flexShrink 0` + 卡片无 `clip` + `List.clip(false)` → 底行溢出**盖右列**；候选 = 门槛提 840 / 底行补 `maxLines(1)` + `textOverflow` + 吧名 `layoutWeight(1)` 替 `Blank()`，**推荐后者**；C2 底部悬浮让位 = **无**，本页无底部悬浮层、底部留白 `Spacing.xl`(20) 随列数不变）；D 手机回归：**无**（形态闸门恒 1 列含手机横屏 / 分屏 / 自由多窗、列 = 1 走原裸 `ListItem` 不套 `ListItemGroup`、不写 `cardColumns`、本页无骨架屏**无 D3 面**；三条落地验证项 = `onScrollIndex` 多列语义〔本页独有〕、`lanes(1)` 等价性〔与 §4.11 同一项〕、C3 规避 ② 的单列视觉等价） |
| 2026-09-13 | **新增 §4.11 用户主页 / 个人内容页（`UserProfile`）方案（待确认）**：用户信息居中（核实**现状已居中** → 结论为「零改动 + 三条保真约束」）+ 下方内容竖 2 / 横 3（走 **`List.lanes()` + `ListItemGroup.header/footer`**，与 §4.3 收藏页同范式）；§三 第 11 / 12 项（含「个人内容页」命名澄清）、§6.1 范围提醒新增**例外五** + 「多列写法共三套」选用口径 + A1 / A5 / A6 / C2 表项、§6.2 D3 行 + 二级页清单同步 | A 错位：**有 3 处**（A1 —— 3 处通栏项须迁 `ListItemGroup.header/footer`，附「保持 `List.sticky` 默认 `None`」护栏；A5 —— `currentWidth` 初值 360 只在 `onAreaChange` 纠正 → 冷启动平板横屏「先 1 列再 3 列」，改 `aboutToAppear` 同步取宽高；A6 —— `lanes` 行内高度差留白 ≈ ≤38vp → 接受）；A2 末行拉伸**不适用**（`lanes` 列宽恒定、无需 `blankSlots()`）；B 出屏：**无**（`lanes` 均分列宽 + `expandSafeArea` 只扩上 / 下）；C 重叠：**有 1 处**（折叠展开横屏 750 下三列 ≈ 234vp → 吧卡文字列 ≈ 124vp 截断明显；候选 = 门槛提 840 / 接受截断，**推荐接受**并并入 §4.8 口径收口项；C2 底部悬浮胶囊让位 = **无**，74 + 30 + 手势 ≈ 138 < 160 通栏占位、胶囊横屏 480 居中只压中间列底部）；D 手机回归：**无**（形态闸门恒 1 列含手机横屏 / 分屏 / 自由多窗、列 = 1 走原裸 `ListItem` 不套 `ListItemGroup`、`ThreadListSkeleton` 两处不加 `columns`、本页不写 `cardColumns` → 无 D1 / D3 / D6 残留面；两条落地验证项 = `lanes(1)` 等价性、`ListItemGroup` 内行间距） |
| 2026-09-13 | **§4.9 转「已确认」**（用户按推荐值拍板全部 4 个待拍板点：交替分列 / 骨架屏不做 / 分栏 4 : 6 / 横屏右栏维持 2 列）+ **新增 §4.10 楼中楼详情（`SubPostDetail`）方案（待确认，与 §4.9 同款）**；§三 第 9 / 10 项状态、§6.1 范围提醒新增**例外四**（`SubPostDetail` 移出「单列二级页」清单）并把「例外页共同点」改为四页、§6.2 二级页清单同步 | A 错位：§4.10 **有 1 处**（卡内 8vp 追加间距用全局下标判定 → 分列后每列末条多 8vp、列底空洞；规避 = 抽 `CommentCard(comment, index, total)`，分列传列内下标 + 列长度、单列传全局下标 + 总数）；§4.9 维持「无」；B 出屏：两节均**无**（列 / 栏全 `layoutWeight`、`expandSafeArea` 只扩上 / 下）；C 重叠：两节各 **有 1 处**（1024 横屏右栏窄列 —— §4.9 内容宽 ≈ 254vp / §4.10 ≈ 258vp，均 < 手机基线 294vp，`ImageGrid` 3 列每格 ≈ 78vp 偏瘦 → 已拍板维持 2 列 + 4 : 6、挂真机复核；**不动 `ImageGrid` 几何**）；D 手机回归：两节均**无**（形态闸门恒 1 列 + 不分栏 + 原 `ForEach` 一字不动 + 装饰层挂点不变；两页均不写 `cardColumns` → 无 D1 / D6 残留面；§4.10 `CommentCard` 计划内为本页私有 Builder，不构成 D3 面） |
| 2026-09-13 | §4.9 帖子详情（`ThreadDetail`）适配方案（**待确认**）：**竖屏** = 主楼满宽 + 回复区**两列列内独立堆叠**（推「手写双列」：不换 `Scroll`、不引入 `WaterFlow`，用以消除行分组的行内对齐留白 = 用户看到的「两列高度不一致」）；**横屏** = `左主楼 / 右回复两列` 分栏（`layoutWeight 4 : 6`、双 `Scroll` 各自 `padding bottom 160`）；§三 第 9 项状态、§6.1 范围提醒（本页**移出**「单列二级页」清单 + C2 表项）、§6.2 二级页清单同步 | A 错位：**无**（非行分组 → 无末行拉伸、无补空位需求；通栏项与触底哨兵均为分列 `Row` 的兄弟）；B 出屏：**无**（列 / 栏全部 `layoutWeight` 均分，`expandSafeArea` 只扩上 / 下）；C 重叠：**有 1 处**（横屏 1024 下右栏单列内容宽 ≈ 254vp < 手机基线 296vp，`ImageGrid` 3 列每格 ≈ 78vp 偏瘦 → 规避候选已定，默认维持 2 列 + 4:6，挂真机复核项）；D 手机回归：**无**（形态闸门恒 1 列 + 不分栏 + 原 `ForEach` 一字不动 + 沉浸属性挂点不变） |
| 2026-09-13 | **把「手机端零回归核对」固化为强制自检（用户要求每次更新都做）**：§6.1 新增 **D 类表（D1~D6）** 且标题加入「手机回归」；§6.2「自检六步」→**七步**（第 7 步 = 会不会影响手机正常布局）、触发时机声明同等强制、留痕模板加 `D 手机回归` 行、结论挂钩表加 D 档、二级页要求同过第 7 步。起因 = §4.8「是否影响手机布局」核对 | **D 手机回归：无**（§4.8 已逐项核对：手机恒 1 列、`cardColumns` 恒写 1、列 = 1 不套行分组容器、`ThreadListSkeleton` 5 处调用点默认单列 → 手机竖屏 360 逐像素不变）；A / B / C 沿用 §4.8 结论（A 有 1 处已定、B 无、C 无）。本轮为**纯纪律 + 文档补强、零代码改动** |
| 2026-09-12 | §4.1~§4.5 五页适配方案（含 §六 防御清单本身） | A 错位：有 6 处（A1~A6，规避已定）；B 出屏：横向无、纵向 B3~B6 需落实 `maxLines`；C 重叠：C2 / C3 待定 |
| 2026-09-13 | §4.8 吧内帖子列表（`ThreadList`）方案（选型 A「行分组」，含本吧搜索态多列）；§三 第 8 项状态、§6.1 范围提醒（`ThreadList` 转「多列二级页」）与 A2 / C2 表项、§6.2 二级页清单同步 | A 错位：**有 1 处**（A2 多列末行被拉伸 → `threadBlankSlots()` 补等宽空位，列表态 / 搜索态各一处；其余 A3 / A4 / A5 均无）；B 出屏：**无**（`layoutWeight(1)` 均分 + `expandSafeArea` 只扩上 / 下）；C 重叠：**无**（C2 已单独确认：底部悬浮排序壳 / FAB 仍由 `contentBottomSpace()` 让位，横屏矮视口列为回归项） |
| 2026-09-12 | §4.6 宿主壳（`pages/Index.ets`）平板适配方案 | A 错位：有 2 处（H-A 首帧窄屏初值 / H-B 840 散落三处，规避均已定）；B 出屏：无；C 重叠：有 1 处（H-D 底栏底部 margin 30 无安全区补偿，规避已定）；H-C 底栏档位待拍板 |
| 2026-09-12 | §4.6 三个待拍板点收敛（H-C 维持 480 零改动 / H-B 并入 `Theme.ets` / H-D 动态取并复用 `UserProfile` 既有实现） | A 错位：仍 2 处（H-A / H-B），规避不变；B 出屏：无；C 重叠：H-D 规避由「动态补偿」明确为「复用 `UserProfile` 避让读数」；H-C 降级为**零改动** |
| 2026-09-12 | §三 第 7 项改名「全吧搜索（首页入口）」+ 表下命名澄清（区分页内搜索状态）+ §4.6 新增 H-F（死参数 / 死通道清理） | A 错位：无（仅命名与死代码清理，不改几何；§4.6 原有 H-A / H-B 两处结论不变）；B 出屏：无；C 重叠：无（H-D 那 1 处为既有项，与本次改动无关） |
| 2026-09-12 | §4.6 H-F 执行：删除 `HomeTab.onOpenFavorite` 死参数、`Index.ets` 死传参、`Favorite.ets` `favOpenSearchRequest` 死通道（含过时 / 反向注释） | A 错位：无；B 出屏：无；C 重叠：无（纯死代码清理，零布局改动；全工程检索 0 残留、lint 无新增诊断） |
| 2026-09-12 | §4.7 全吧搜索（`pages/Search.ets`）适配方案：搜索框自适应拉伸（顶栏与内容共用 `Content.maxWidth`）、列数 1 / 2 / 3（宽高比判横竖屏）、三模块手写分列实现搜贴瀑布流、窄列文本约束（S-A~S-D） | A 错位：**有 2 处**（A3 双路径 `FloatingHeader` / `SearchTitleBar` 须同改、A4 顶栏与内容边缘咬合，规避均已定）；B 出屏：无；C 重叠：**有 1 处**（S-D 窄列行内文本缺 `maxLines` / `layoutWeight`，规避已定）；§6.1 范围提醒同步为「`Search` 例外做多列」 |
| 2026-09-12 | §4.7 五个待拍板点收敛（横屏搜索框封顶 `Content.maxWidth = 1000vp` 居中 / 横竖屏判据 `pageWidth > pageHeight` / 搜贴行数启发式估算 / 搜吧搜人顺序均分 / 窄列**截断**）+ §三 第 7 项转「已确认」 | A 错位：仍 **2 处**（A3 双路径同改、A4 顶栏与内容咬合，规避不变）；B 出屏：无；C 重叠：仍 **1 处**（S-D，规避由「截断 / 拆行二选一」明确为**截断**，已可落地）→ 满足 §6.2「已有「有」但规避到可落地粒度」→ 可标**已确认** |
| 2026-09-12 | §4.7 补记「前置依赖」小节（`Breakpoint.md` / `Content.maxWidth` 待 §4.6 H-B 落地）+ §4.6 H-B 加「被依赖方提示」+ 断点 / 阈值与状态同步标「未落地 / 不开工」 | A 错位：无（纯依赖关系说明，未新增 / 修改任何几何路径，原 2 处 A3 / A4 结论不变）；B 出屏：无；C 重叠：无（原 1 处 S-D 结论不变）→ 纯文档性补充，不影响 §4.7「已确认」状态，但**开工前置于 §4.6 H-B** |
| 2026-09-12 | §4.2 首页方案 5 点收敛（选型 A `WaterFlow` / 口径统一于判据层 / 渐隐带夹取 / 卡片几何比例化限多列档 / `deviceTypes` 前置 + 上架联动）+ §1.6 补上架后台与整体验收联动 + §三 第 1 项转「已确认」 | A 错位：**有**（沿用 §4.2 原 4 条硬约束：外边距恒 16 单一来源、禁单独放大留白、双路径顶栏几何同步、居中收窄须同容器；新增 1 条：卡片几何比例化**限多列档**、单列逐像素不变 —— 规避均已定）；B 出屏：**无**（列宽 `1fr`、卡片 `width('100%')`、无横向滚动）；C 重叠：**有 1 处**（`WaterFlow` 虚拟滚动「整层不绘制」，与 §4.4 同源；规避 = **落地前真机 A/B 前置门**，复现即回退方案 B）→ 规避已到可落地粒度，可标**已确认** |
| 2026-09-12 | §4.2 剩余两点补拍板（口径统一 = 判据层统一最优解 / `deviceTypes` 处置定案）+ §1.6 待办改「已拍板处置」（加 `tablet`、不加 `2in1`、不启用 EasyGo）+ §4.6 H-B 加「定位升格」 | A 错位：无新增（决策 7 只约定统一到哪一层，不改任何几何路径；§4.2 原 4 条硬约束、H-A / H-B / H-D 结论均不变）；B 出屏：无；C 重叠：无（原 §4.2 1 处 `WaterFlow` 前置门不变）→ 纯口径与前置项定案，§三 状态与各页「已确认」均不变 |
| 2026-09-12 | §4.6 新增 H-G「形态切换观感」：横竖屏切换无过渡动画为**既定取舍**（列数模板不可补间 / 整页旋转动画会叠系统动画 / 不用 `animateTo` 包判据），三项可选增强 H-G-1 判据防抖 / H-G-2 滚动锚定 / H-G-3 单帧遮盖（**待拍板**）+ 顶部更新日志与 §4.6 状态行同步 | A 错位：无（不改任何几何路径，H-G-3 仅动 `opacity`）；B 出屏：无；C 重叠：无 → 虽三类皆「无」，但 H-G 三项增强**规避未定**（属观感项、不进三类风险），据 §6.2 结论挂钩表**不得标「已确认」**，故 H-G 挂「待拍板点」；**不影响 §4.6 布局部分（H-A / H-B / H-D）的「已确认」判定** |
| 2026-09-12 | §4.6 H-G 三项增强**按推荐定案**：H-G-1 判据防抖采纳（并入 H-A / H-B 一次落地）、H-G-2 滚动锚定条件采纳（挂真机门 = §4.7 风险 1 旋转实测）、H-G-3 单帧遮盖不做 + 风险与回归项 / 风险自检 / 待做行 / 状态行 / 更新日志同步 | A 错位：无（不改几何，H-G-3 已定为不做 → 无 `opacity` / 动画属性落地）；B 出屏：无；C 重叠：无 → **H-G-1 规避到可落地粒度（可标已确认）**；**H-G-2 规避未定，据 §6.2 挂真机门、不得记作已确认**；H-G-3 **明确不做**。三项均不影响 §4.6 布局部分（H-A / H-B / H-D）的「已确认」判定，本轮不开工 |
| 2026-09-12 | §4.7 风险 1 补记与 §4.6 H-G-2 真机门的关联（该实测即 H-G-2 的触发门，结论回写两处） | A 错位：无；B 出屏：无；C 重叠：无（纯交叉引用补充，不改任何几何；§4.7 原 2 处 A / 1 处 C 结论与「已确认」状态不变） |
| 2026-09-12 | §4.6 H-G-2 触发门改口径：「真机旋转录屏」→「**等效触发路径**」（折叠屏展开旋转 / 模拟器 Tablet / 代码级量化 / 自由多窗拖宽）+ 四路不通的**确定性推定兜底**；写清手机因「非大屏形态」无法复现列数变化、其它 App 横竖屏素材对本门无效 + §4.6 表格 / 状态行 / 风险与回归项 / 待做行、§4.7 风险 1、更新日志同步 | A 错位：无；B 出屏：无；C 重叠：无（纯门的判定手段与说明，不改任何几何路径；H-G-1 采纳 / H-G-3 不做的定案不变）→ H-G-2 仍**挂门、不得记作已确认**，§4.6 布局部分（H-A / H-B / H-D）「已确认」不受影响 |
| 2026-09-12 | §4.6 H-G-2 **推定采纳定案**（用户拍板「直接走兜底推定」）：验收门 →「定案依据（推定链条）」，等效触发路径降级为**可选复测手段**，§4.7 风险 1 实测降为**落地后复测项**；表格 / 状态行 / 风险与回归项 / 风险自检 / 另列 / 涉及改动点 / 顶部更新日志同步 | A 错位：无；B 出屏：无；C 重叠：无（纯定案状态与依据表述，不改任何几何路径；H-G-1 采纳 / H-G-3 不做的定案不变）→ **H-G-2 由「条件确认」转「已确认（推定采纳）」**（推定链条成立、规避到可落地粒度），仍**非本轮必做**、独立一次改动；§4.6 布局部分（H-A / H-B / H-D）「已确认」不受影响 |


