# 排序功能重构 — 交付说明 v1.11

> **配套文档**：《收藏功能模块 — 给 Craft 的补充交付说明》（`docs/favorite-module-supplement.md`）
> **适用工程**：TiebaPura（HarmonyOS 7 / API 26，ArkTS / ArkUI 原生）
> **版本**：v1.11（排序功能重构：5 项排序菜单 + 默认时间倒序 + 自定义排序；方案已定稿，实施按批次推进）
> **日期**：2026-08-29
>
> **状态**：🟢 **批 B/C/D 代码实施已完成**（2026-08-29，构建 + 模拟器验证通过；详见 §12 实施记录）；批 A 抓包探测已完成（22 字段全清单：threadstore 确认无 `collect_time`/`favor_time`）；BUG 批全部修复完成

---

## 1. 需求来源【用户提出 · 2026-08-29】

收藏页排序功能改进需求：

1. **默认排序**改为「时间倒序（最新收藏的帖子在前）」
2. **排序按钮交互重构**：点击排序按钮 → 按钮下方展开 5 个按钮竖排菜单：
   - 名称正序
   - 名称倒序
   - 时间正序（添加时间）
   - 时间倒序（添加时间）【默认】
   - 自定义排序（自己排序记忆，仅针对自定义分类）

## 2. 澄清决策【用户确认 · 2026-08-29】

| 决策点 | 用户选择 | 落地影响 |
|---|---|---|
| 「添加时间」数据策略 | **先抓包再定** | 前置抓包探测；无云端字段则本地增量记录 + 历史 `lastTime` 兜底 |
| 排序菜单范围 | 两边收纳夹界面 + 帖子列表页都加入（包括自定义排序） | 4 个列表页统一接入 5 项菜单 |
| 自定义排序交互 | 拖拽排序（复刻分类卡片范式） | 分类内帖子列表进入拖拽模式，松手持久化 |
| 默认排序 | 时间倒序（添加时间）为默认 | 菜单默认高亮该项，`SortMode.TimeDesc` |

## 3. 数据现实与排序键定案

**核心数据现实**：threadstore 接口无 `collect_time`（§11 已实测 22 字段清单确认）→ 云端拿不到收藏时间。分类内帖子另有**现成可用**的 `CategoryMapping.addedAt`（移入时间戳，所有写入点已落数据）——分类内帖子时间排序无需兜底。

| 列表页 | 名称键 | 时间键 | 时间数据来源 | 兜底 |
|---|---|---|---|---|
| 吧分类收纳夹 | 吧名 Unicode 码点序 | 吧内帖子最大收藏时间 | 本地增量记录（批 D） | `lastTime` |
| 吧内帖子列表 | 帖子标题 | 本地增量收藏时间 | 本地增量记录（批 D，待抓包确认） | `lastTime` |
| 自定义分类列表 | 分类名 | `createdAt`（创建时间） | 现成 | — |
| 分类内帖子列表 | 帖子标题 | **`addedAt`（移入时间）** | **现成** | — |

> 排序均作用于**本地已加载数据**（分页限制，文档 §3 既有定案），不触发网络请求。
> 「自定义排序」严格限定「仅针对自定义分类」：吧分类收纳夹、吧内帖子列表菜单含该项但**置灰 + Toast 提示**；自定义分类列表（已有第八批拖拽）、分类内帖子列表可用。

## 4. 实施批次

| 批次 | 内容 | 交付物 | 验收口径 |
|---|---|---|---|
| **A · 抓包探测** | 模拟器新收藏 3~5 条 → 抓 threadstore 响应核对字段（`collect_time`/`favor_time` 类）；顺带探测收藏链路有无专用接口返回收藏时间 | §11 探测记录回填；时间策略定案 | 判定「云端直取」或「本地增量」明确，无二义 |
| **B · 排序建模** | `sortDesc:boolean` → `SortMode` 枚举（NameAsc/NameDesc/TimeAsc/TimeDesc/Custom）；排序偏好持久化 `fav_sort_mode_{accountId}`；4 列表排序键接入（`forumThreads`/`categoryThreads`/`toPostCards` + 收纳夹排序） | Favorite.ets 排序逻辑改造；FavoriteStore 排序偏好 API | 各列表按选定模式即时重排，重启记忆；默认 TimeDesc |
| **C · 菜单面板** | 排序按钮点击 → 锚定按钮下方下拉面板（竖排 5 项，选中高亮 + ✓，`ImmMaterial` 材质）；点击应用 + Toast + 收起；吧分类两界面「自定义排序」置灰提示 | 统一菜单组件（4 界面复用） | 面板定位、选中态、置灰提示正确；无动画卡顿 |
| **D · 时间数据 + 自定义拖拽** | 收藏动作成功挂钩写 `fav_collect_ts_{accountId}`（或云端直取）；分类内帖子列表拖拽自定义排序（`List.editMode` + `onItemDragStart/onItemDrop` + 松手 `Haptic.light()`），顺序持久化 `fav_custom_thread_order_{accountId}` | FavoriteStore 新增 2 个持久化 API；分类内拖拽接入 | 新收藏后时间倒序置顶正确；拖拽松手即时生效且重启保持；未自定义分类仍走默认时间倒序 |
| **E · 回归 + 回填** | `assembleHap` 构建 + 模拟器回归（排序切换/拖拽/置顶共存/分页/刷新，无 ANR）；文档回填（§3 排序规则修订、§11 探测记录、本交付说明状态更新） | 全量回归通过；文档 v1.11 完整 | 回归无 appfreeze；排序与既有置顶、编辑、拖拽（分类卡片）互不冲突 |

## 5. 持久化变更【新增】

| Key（Preferences） | 用途 |
|---|---|
| `fav_sort_mode_{accountId}` | 排序偏好（跨会话记忆） |
| `fav_collect_ts_{accountId}` | 收藏时间映射 `{tid: ts}`（吧内帖子时间排序） |
| `fav_custom_thread_order_{accountId}` | 分类内帖子自定义顺序 `{categoryId: [tid...]}` |

## 6. 影响面

- `pages/Favorite.ets`：SortMode 状态、菜单面板 UI、排序函数 ×3、收纳夹排序、分类内拖拽、置灰逻辑
- `service/FavoriteStore.ets`：新增 `loadSortMode/saveSortMode`、`recordCollectTime/loadCollectTimes`、`loadThreadOrder/saveThreadOrder`
- 收藏动作挂钩（`addThreadCollection` 成功后记录收藏时间）
- 文档：`favorite-module-supplement.md` §3 排序规则修订、§11 探测回填、版本 v1.11

## 7. 验证口径

- 默认进入收藏页各列表 = 时间倒序（最新收藏在前）
- 5 项菜单展开/收起、选中态、Toast 反馈正确
- 名称正/倒、时间正/倒在各列表生效且即时重排；重启后排序偏好保持
- 分类内帖子拖拽自定义排序：松手即时生效、重启保持；吧分类两界面「自定义排序」置灰 + 提示
- 与既有能力共存：置顶恒顶、编辑态、分类卡片拖拽、分页加载、下拉刷新均无回归
- 全程无 ANR / appfreeze

## 8. 遗留 / 待办

- **用户 BUG 反馈（2026-08-29 · 实施暂停期间）**：用户反馈的 BUG 清单 → 评估后统一处理，处理结论回填本文档 §9（问题记录）与主交付文档
- 批 A 抓包结果（云端收藏时间字段有无）——✅ **已完成（2026-08-29 实机探测）**，详见 §11
- 历史已收藏数据无本地收藏时间 → 按批 A 定案兜底（`lastTime` 近似）
- 真机复验项（既有）：软键盘输入、`searchForums` 接口——不阻塞本批次

## 9. 问题记录（BUG 反馈 · 2026-08-29）

> 用户反馈 BUG 逐条评估记录。状态：🔶 待处理（已评估，实施遵循"开工需确认"规则）→ ✅ 已修复。

### BUG-01 · 收纳夹进入子列表后系统侧边返回无效

| 项 | 内容 |
|---|---|
| 现象 | 收藏 Tab → 点击吧分类收纳夹卡进入吧内帖子列表（或点击自定义分类卡进入分类内帖子列表）后，**系统侧边返回手势 / 返回键无法回到上一级列表**（TopBar 显式返回按钮可用，属正常） |
| 复现路径 | 收藏 Tab → 吧分类 Tab → 点击任意吧分类卡 → 系统侧边返回 → 无响应（不回到收纳夹列表） |
| 根因 | 收藏 Tab 内子列表为 `FavoriteTab` **组件内状态切换**（`selectedForum`/`selectedCategoryId`，第九批已记录：非路由跳转），不在页面路由栈；系统返回事件仅派发给 @Entry 页面 `Index.ets`，而 `Index.ets` **未实现 `onBackPress()`** → 无拦截、无状态回退 |
| 影响面 | ① 收藏 Tab 两级子视图（吧分类→吧内列表、自定义分类→分类内列表）均受影响；② 编辑态、移入面板、备份对话框、分类输入框等弹层同理，系统返回无法关闭/退出 |
| 修复方案（已评估） | `Index.ets` 实现 `onBackPress(): boolean`：当 `selectedTab===TabIndex.Favorite` 且 AppStorage `favCanGoBack===true` 时，自增 `favBackRequest` 并返回 `true` 拦截；`FavoriteTab` 以 `@StorageLink('favBackRequest')` + `@Watch` 消费，按优先级回退：弹层关闭 → 编辑态退出 → 分类内列表 → 吧内列表 → 根视图（放行系统默认，退出 App）；`favCanGoBack` 由 `FavoriteTab` 在各状态变更处维护（子视图/编辑态/弹层= true，根视图= false）——复用项目既有 `favEditing` AppStorage 联动范式 |
| 修复 | **2026-08-29 已实施**：`Index.ets` 新增 `onBackPress()`（选中收藏 Tab 且 `favCanGoBack=true` 时自增 `favBackRequest` 返回 true 拦截，否则返回 false 放行）；`Favorite.ets` 新增 `@StorageLink('favCanGoBack')` / `@StorageLink('favBackRequest')`（均挂 `@Watch`）；**`favCanGoBack` 采用 `@Watch('syncBackState')` 自动维护**——给 `categoryTab/selectedForum/selectedCategoryId/editMode/categoryInputVisible/showMovePanel/showExportDialog` 7 个状态统一挂 @Watch，任一变更自动重算可回退标记（零侵入赋值点），`aboutToAppear` 初始化时同步一次；`onBackRequest()` 消费请求按优先级逐级回退（分类输入 → 移入面板 → 备份弹窗 → 编辑态 → 分类内 → 吧内 → 根视图放行）；`read_lints` 零错误 |
| 验证口径 | 各子视图/编辑态/弹层下侧边返回逐级回退且顺序正确；根视图返回放行系统默认；与 TopBar 返回按钮、第九批视图切换过渡无冲突；无 ANR |

### BUG-02 · 收藏页顶栏渐变未延伸到"吧分类/自定义分类"分段切换区

| 项 | 内容 |
|---|---|
| 现象 | 收藏页顶部渐变（列表内容在顶部的渐显过渡）只覆盖顶栏（TopBar）范围，**未延伸到"吧分类/自定义分类"分段切换按钮所在区域**——列表内容滚动穿过分段切换区时直接显示、缺少渐变过渡，顶栏渐变视觉断裂 |
| 复现路径 | 收藏 Tab → 吧分类/自定义分类根视图 → 向下滚动列表，观察卡片进入分段切换按钮区域时的过渡 |
| 根因 | 顶栏渐变由 `BottomFadeOverlay` 提供（各列表 `.overlay()` + `BlendMode.DST_IN`，渐变自上而下，关键帧 `0.0→透明 / 0.15→不透明`），削淡区 = 列表可视高度 0~15%（如 800vp 屏 ≈ 120vp），仅覆盖 TopBar（≈0~98vp）；收藏页根视图额外悬浮"吧分类/自定义分类"分段切换区（`CategoryTabs`，`top:100`，≈100~132vp），**渐变未覆盖该区域 → 过渡断裂**。4 个列表视图（`FolderListView` / `ForumThreadsView` / `CategoryListView` / `CategoryThreadsView`）共用同一渐变 |
| 影响面 | 收藏 Tab 根视图（吧分类/自定义分类列表）顶栏与分段切换区渐变不连续；子视图无分段切换，影响较小 |
| 修复方案（已评估） | 收藏页渐变过渡区加长至覆盖分段切换按钮底部（约 150~160vp）：将 `BottomFadeOverlay` 关键帧 `0.15` 上调（按列表可视高度折算，如 `0.18~0.22`）；或单独为收藏页根视图增加覆盖"TopBar + 分段切换区"的顶部渐变遮罩层。注意与占位高度（根视图 146 / 子视图 98）配合，避免真实卡片被削淡；子视图可保持原比例。视觉细节（渐变长度/深浅）以真机确认为准 |
| 修复 | **2026-08-29 已实施**（与 BUG-09 融合）：`Favorite.ets` `BottomFadeOverlay()` 由 BUG-09 修复的"底部 80vp alpha 渐隐"改回 **ThreadList 同款全屏 `DST_IN` 顶部渐显**——`linearGradient` colors `[['#00FFFFFF',0.0],['#FFFFFFFF',0.20],['#FFFFFFFF',1.0]]`（顶部 20% 渐显，800vp 屏 ≈160vp，覆盖 TopBar 0~98 + 分段切换区 100~132vp）；**20% 以下全实色**（src_alpha=1）→ 无梯形挖洞、不回归 BUG-09；4 视图统一（子视图无分段区，20% 渐显无害）；`read_lints` 零错误 |
| 验证口径 | 根视图列表内容滚动穿过分段切换区时有连续渐变过渡；卡片不被误削淡；子视图与其余页面渐变行为不变；无 ANR |

### BUG-03 · 收藏搜索 100% 失败（「搜索失败，请稍后重试」）

| 项 | 内容 |
|---|---|
| 现象 | 收藏 Tab 顶栏搜索 → 搜索页 → 输入任意关键词（防抖 300ms 自动触发 / 点历史词）→ **100% Toast「搜索失败，请稍后重试」**，无任何结果 |
| 复现路径 | 收藏 Tab → 搜索按钮 → 输入关键词 → 等待防抖触发（或点搜索历史）→ 必现失败 Toast |
| 根因 | ① 链路：`Search.ets doSearch` → `TiebaService.searchForums()` → `HttpClient.get('https://tieba.baidu.com/f/search/res?ie=utf-8&qw=' + kw)`。② **实测（2026-08-29，curl）**：该 PC 搜索页已改 **SPA 壳**——仅 4KB，`<div id="app">` + JS 异步渲染，**无服务端渲染的 `/f?kw=` 链接** → `parseSearchResults` 正则必为空；③ App 内 rcp 请求带登录态 Cookie + 非真实浏览器 UA 指纹，实测无 Cookie 时该 URL 返回 200，**带 Cookie 场景极可能触发贴吧风控 403**（`HttpClient.request` 403 分支抛 BizError）→ `doSearch` catch 吞掉具体错误、统一 Toast「搜索失败」；④ 该接口在主文档第十批已标记**「待真机复验」**（`searchForums` 交付后从未真机验证过） |
| 影响面 | 收藏 Tab 搜索入口完全不可用；首页/进吧等跳转同一 `Search.ets` 的入口同样受影响（同一接口）；主文档 §4.5 原始设计为**「收藏范围内搜索」**（云端收藏帖子 + 本地自定义收纳夹），实际实现为全站搜吧，语义不一致 |
| 修复方案（已评估） | 方向一：换移动端搜索接口 `c.tieba.baidu.com/c/s/searchforum`（JSON 返回 `forum_list`；本次实测当前参数返回空 result，**需验证公共参数/签名后落地**）；方向二：搜索改走**本地收藏数据过滤**（匹配收藏帖子标题/收纳夹名，符合 §4.5 原始设计，不依赖网络，最稳）；方向三：抓包解析 SPA 异步数据接口（较脆弱）。落地优先级待用户确认；另建议 `doSearch` catch 透出具体错误信息便于后续排障 |
| 修复 | **2026-08-29 已实施（方向二 · 本地收藏过滤）**：TopBar 搜索按钮不再跳转 `pages/Search`，改为收藏页内本地搜索态（`@State searchMode` / `searchKeyword`；搜索框 `defaultFocus` 自动聚焦）；`searchResults()` 本地过滤——匹配帖子**标题 / 吧名 / 分类名**（分类名命中 → 基于 `categories`+`mappings` 将该分类下帖子纳入）；结果视图 `SearchResultView()` 复用 `PostCard(card, true)` + 顶部占位 + `BottomFadeOverlay` 渐变语言；空关键词 / 无结果显示提示态；系统返回优先退出搜索（`onBackRequest` 首分支），`syncBackState` 已纳入可回退标记；`read_lints` 零错误 |
| 修复（收口） | **2026-08-29 追加收口（首页/进吧入口）**：① 首页原本**无任何搜索入口**（`TopBar` 仅在关注/消息/我的页渲染，首页顶栏为 `HomeHeaderOverlay`，右上无按钮）——在 `HomeHeaderOverlay` 右侧新增搜索按钮 → `openSearchFromHome()` 自增 `favOpenSearchRequest` + 切收藏 Tab → `Favorite.ets` 消费（`@StorageLink('favOpenSearchRequest') @Watch` + `aboutToAppear` 补消费）自动打开本地搜索态；② 进吧页（`ThreadList.ets`）搜索按钮不再跳 `pages/Search`，改为**本吧本地搜索**（`@State searchMode`/`searchKeyword`；顶栏变搜索框 `defaultFocus`，吧头/排序 Tab 隐藏；`searchThreads()` 过滤已加载帖子标题；结果复用 `ThreadCard`；空关键词/无结果提示态）；③ 删除死代码 `pages/Search.ets` + 移除 `main_pages.json` 注册。模拟器实测：首页点搜索 → 自动切收藏 Tab + 打开搜索态；进吧页输入「26」命中【邦吧办事中心26.06.05】、输入「12」显示"未找到相关帖子"；lint 零错误 |
| 验证口径 | 收藏搜索页输入关键词返回结果（贴吧列表/收藏匹配，按选定方案）；空关键词不请求；失败时提示具体原因而非笼统文案；回归首页/进吧搜索入口；无 ANR |

### BUG-04 · 自定义分类长按编辑弹窗排版粗糙

| 项 | 内容 |
|---|---|
| 现象 | 自定义分类 Tab 下长按任意自定义分类卡 → 弹出"分类名 / 选择操作 / 重命名·更换封面·删除分类"操作弹窗，**排版视觉粗糙、缺乏精致感**（截图 2026-08-29）：① 标题用分类名（如"11"）字号粗重居中（系统默认 32~36sp black），占据视觉中心，与下方"选择操作"副标题字重对比失衡、缺少呼吸感；② 三个操作项以纯文字**纵向密排**——无图标（视觉锚点缺失）、无分割/分组（中性操作与"删除分类"危险操作混在同一区）、无间距与排版节奏、危险项未用 `sys.color.warning` 红色提示；③ 整体缺少现代 App 弹窗的"封面/分类元信息 + 操作列表"叙事层级，与首页/进吧/我的页面已有半模态 `bindSheet` 的精致度不匹配 |
| 复现路径 | 收藏 Tab → 自定义分类 Tab → 长按任意自定义分类卡（如"11"）→ 弹出操作弹窗 |
| 根因 | 代码使用 HarmonyOS 系统内置 `ActionSheet.show({ title, message, sheets })`（`Favorite.ets manageCategory`，第 695~733 行）。系统 `ActionSheet` 的 title/sheet 项样式**完全由系统主题决定、不可定制**——title 字号大粗黑、sheet 项固定纯文字无 icon/无分组/无颜色差异化；项目无自定义 `ActionSheet` 封装（`components/`、`common/` 无 `ActionSheet*` 文件），也无法在不替换组件的情况下调整这些视觉细节 |
| 影响面 | 自定义分类 Tab 长按编辑流程；与第六批已交付的"弹窗材质分级（半模态 `bindSheet` 背景透出 systemMaterial）"设计语言不一致；同样的"备份" ActionSheet（`Favorite.ets showBackupSheet`，第 327~335 行）若视觉相同亦受影响（待复核） |
| 改进方案（已评估，未实施） | 方向一（推荐 · 高质高效）：**改用 `bindSheet` 半模态自建弹窗** `CategoryActionSheet.ets`（@Component，自定义 `@Builder` 内容），UI 设计要点：① 顶部拖拽手柄（4×32 圆条） + 分类图标/封面缩略图（40vp 圆角） + 分类名（18sp medium 居中）+ 副标题"选择操作"（12sp secondary 居中）；② 中段 List 操作项（每行 56vp，左侧 `SymbolGlyph` 锚点图标 / 右侧标题 + 描述），含 ripple 反馈；③ 中性操作"重命名 / 更换封面 [ / 移除封面 ]"一区，**删除**用 `sys.color.warning` 文字色 + 分割线单独隔开；④ 底部取消按钮（56vp）；⑤ 暗色模式用 `Theme` token 适配；方向二（最小改动）：保留 `ActionSheet.show`，但通过 `sheets[i].isEnabled`/`description`/`SheetInfo` 扩展字段（视系统 API 可用性）做有限调整——通常仍无法解决 title 字号与无图标问题，提升有限；方向三：完全自定义 `customDialog` / `bindContentCover`——灵活度等同方向一但更重。落地推荐方向一（与项目既有的"半模态 + systemMaterial"语言一致），需用户确认设计风格（图标源：SymbolGlyph / 字体图标 / 业务图标）后实施 |
| 修复 | **2026-08-29 已实施（方向一 · bindSheet 半模态）**：`manageCategory` 由系统 `ActionSheet.show` 改为 `bindSheet` 半模态 `CategoryManageSheet()`（`.bindSheet($$this.showCategoryManage, ..., { height: 400, dragBar, showClose, title:'分类管理' })`）：头部复用 `CategoryCover` 封面缩略图 + 分类名 + 帖子数；操作行 `ActionRow`（**自绘简约线条图标 `StrokeIcon`**——`Shape+Path` stroke 风格、24×24 视口、亮色黑/暗色白、危险行 `Theme.danger()` + 标题 + 描述 + `chevron_right` + 卡片底 + ripple 点击反馈）：重命名（复用 `categoryInputVisible` 弹层）/ 更换封面（`PhotoViewPicker`）/ 移除封面（仅已有封面时显示）/ 删除分类（**红色分组**，关半模态后 `setTimeout 300ms` 再弹系统确认框避免双框竞争）+ 底部取消；`manageCategory` 原 ActionSheet 逻辑删除；`read_lints` 零错误 |
| 验证口径 | 长按自定义分类卡弹出新弹窗：标题层级清晰（克制的副标题 + 分类名）、操作项有图标+描述+点击反馈、删除项为警告色并有分组分割、暗色模式视觉一致；点击外部/手柄下拉可关闭；原"重命名/更换封面/移除封面（已有封面时显示）/删除分类"四项功能均正常；与首页/进吧的半模态视觉风格一致；无 ANR |

### BUG-05 · 吧分类长按置顶无确认弹窗 + 置顶后收纳夹无醒目置顶标识

| 项 | 内容 |
|---|---|
| 现象 | 收藏 Tab → 吧分类（收纳夹）列表 → 长按任意吧分类卡：① **无任何确认弹窗**，立即执行置顶/取消置顶（误触风险高，长按是最易误触的手势之一）；② 置顶成功后，收纳夹卡片上**没有醒目置顶标识**——现有实现仅标题右侧一枚 10sp `#8E8E93` 灰底白字小徽章"置顶"，字号小、颜色浅，与 16sp 卡片标题对比弱，视觉辨识度极低（用户反馈"没有置顶标识"） |
| 复现路径 | 收藏 Tab → 吧分类列表 → 长按任意吧分类卡（置顶/取消置顶）→ 观察卡片置顶标识 |
| 根因 | ① `FolderCard` 的 `LongPressGesture.onAction` **直接调用 `togglePinFolder`**（`Favorite.ets` 第 1430~1431 行），无二次确认；与帖子卡片长按进入编辑（第 1599~1606 行）不同，置顶是"立即生效 + 持久化（Preferences）+ 重排"的强操作，缺少确认防线。② 置顶标识：`FolderCard` 第 1399~1406 行存在 `Text('置顶')` 徽章，但 10sp 小字 + 灰色 `#8E8E93` 与白/暗卡片背景对比较弱，且无图标/色块等强视觉锚点；`PostCard` 第 1490~1497 行同样为 10sp 灰徽章。持久化链路（`togglePinFolder` → `FavoriteStore.setFolderPinned` → `rebuildFolders` 第 183 行 `pinned: pinMap.has(name)`）经核查**逻辑正确、无状态丢失**，问题在交互与视觉层 |
| 影响面 | 长按误触即置顶，打乱"置顶恒顶"排序（第 187~196 行：置顶按时间倒序恒顶），需再长按才能恢复；置顶后无法快速辨识哪些吧已置顶，"置顶恒顶"能力存在感被削弱；`PostCard` 帖子置顶徽章同样弱，需一并评估 |
| 改进方案（已评估） | **确认弹窗**（二选一）：方案 A（推荐，与 BUG-04 弹窗体系统一）：沿用 `bindSheet` 半模态自建确认弹窗——顶部副标题"置顶 / 取消置顶「xx」"，中段操作项（置顶 = 主色 + 图钉图标；取消置顶 = 次要色）+ 取消；方案 B（轻量）：`AlertDialog.show` 系统确认框"确定置顶「xx」吗？将优先展示在列表最前"，主按钮确认/取消。**置顶标识强化**（可叠加）：① 徽章升级——`SymbolGlyph($r('sys.symbol.pin_fill'))` 图钉图标 + 品牌色/主色底、11sp 白字"置顶"，与吧名同行（`FolderCard` 与 `PostCard` 同步升级）；② 卡片级标识——置顶卡片加品牌色 2px 左侧边框或顶部 3px 高亮条 + 左上角图钉角标。文案与 `accessibilityText`（第 1425 行"已置顶"）保持一致 |
| 修复 | **2026-08-29 已实施（含确认弹窗，与 BUG-04 同一弹窗体系）**：① **置顶标识强化**：`FolderCard` 与 `PostCard` 置顶徽章升级为 `Row`（`SymbolGlyph($r('sys.symbol.pin_fill'))` 10sp + `Text('置顶')` 11sp 白字）+ `Theme.brand()` 主色底 + `borderRadius(4)`；② **确认弹窗**：`FolderCard` 长按改调 `requestPinFolder(folder)` → 打开 `PinConfirmSheet()`（`bindSheet` 半模态：自绘图钉图标 `ICON_PIN` + "置顶收纳夹 / 取消置顶"标题 + 明确文案"确定置顶「xx」吗？置顶后将优先展示在列表最前" + 取消 / 主色确认按钮），确认后执行 `confirmPin()` → `togglePinFolder`；取消/遮罩关闭不改变状态 |
| 验证口径 | 长按未置顶吧 → 弹确认框 → 确认后置顶 → toast"已置顶「xx」" → 卡片置顶到最前 + 徽章/卡片标识醒目可见（亮色 + 图钉图标）；长按已置顶吧 → 弹确认框（取消置顶）→ 确认后恢复原序；取消/点遮罩关闭不改变状态；帖子置顶徽章同步升级且暗色模式可见；与 BUG-04 弹窗体系（若落地）风格统一；无 ANR |

### BUG-06 · 编辑态圈选按钮居中不美观 + 标题未对齐

| 项 | 内容 |
|---|---|
| 现象 | 收藏页进入编辑态（多选模式）后，每张帖子卡片（`PostCard`）顶部**居中位置**出现 20×20 圆形 radio 圈选按钮，与下方标题、副标题、底部"X 回复"均无视觉对齐锚点，孤儿元素，版式不精致（截图 2026-08-29） |
| 复现路径 | 收藏 Tab → 任意视图（吧分类/分类）→ 长按一张帖子卡进入编辑模式 → 观察每张卡片的圈选按钮位置 |
| 根因 | `Favorite.ets` `PostCard` 第 1473~1499 行的顶部 `Row({ space: 8 })` **未设置 `.width('100%')` 且无 `justifyContent`**，导致内部 `Stack` radio 在水平方向无左/右锚点；`Row` 的子项仅在垂直方向有 `alignItems(VerticalAlign.Center)`，水平方向由父 `Column` 默认行为居中放置——结果 radio 渲染到卡片水平居中，与卡片其他内容（左对齐的标题/副标题/作者 + 右对齐的回复数）形成错位。`pinned` 徽章（10sp 灰小字）同样在该 Row 内受同一影响 |
| 影响面 | 全部使用 `PostCard` 的视图：`FolderListView`（不直接用，吧分类是 `FolderCard`）、`ForumThreadsView`（第 1434 行 `PostCard(card, false)`）、`CategoryThreadsView`（第 1614 行同）；编辑态全量受影响；与"圈选右对齐 + 标题左对齐"的现代列表编辑态范式（飞书/微信收藏）不一致 |
| 改进方案（已评估） | **方案 A（推荐 · 改动最小）**：将第 1474~1499 行 Row 改为 `.width('100%')` + 子项 `Blank()` 撑开 + `justifyContent` 推右——`Row` 内左：[置顶徽章]（如有 pinned）、右：[圈选 radio]（仅编辑态），让 radio **右对齐到卡片右上角**（与底部"X 回复"右对齐位置呼应），置顶徽章仍在左上。标题行 `Text(card.title).width('100%')` 保持左对齐不变，自然在 radio 下方左对齐——"右：按钮 / 左：标题"形成明确对齐锚点。**方案 B**：将 radio 与标题合并到同一 Row（radio 在最右、标题 `layoutWeight(1)` 占满剩余空间），进一步节省垂直空间，但会改变原版"置顶徽章在标题上方独立行"的结构，破坏置顶徽章与标题的相对关系，不推荐。**方案 C**：保留 radio 独立 Row，但 `Stack` radio 增加 `alignSelf(ItemAlign.End)`——同样能右对齐，但写法不如方案 A 直观 |
| 修复 | **2026-08-29 已实施**（方案 A）：`PostCard` 顶部 Row 改 `.width('100%')`，子项重排为「置顶徽章（左）+ `Blank()` 撑开 + 圈选 radio（右，仅编辑态）」——radio 右对齐到卡片右上角、与底部"X 回复"右缘垂直对齐；置顶徽章保留左上；标题 `width('100%')` 左对齐不变；非编辑态且非置顶时 Row 内仅 `Blank()`（高度 0，视觉零回归）；`read_lints` 零错误 |
| 验证口径 | 编辑态下：圈选按钮**右对齐到卡片右上角**，与底部"X 回复"右缘垂直对齐；标题/副标题/作者/底部行**保持左对齐**不变；置顶徽章仍在卡片顶部靠左；非编辑态下卡片排版与改动前完全一致（视觉零回归）；长按取消编辑后 radio 消失、无残留；暗色模式下 radio 边框/选中态对比度足够；与已选"X 项"工具栏视觉协调；无 ANR |

### BUG-07 · 编辑态存在两个"全选"按钮（右上角冗余）【已修复】

| 项 | 内容 |
|---|---|
| 现象 | 进入编辑态后出现**两个**"全选/取消全选"入口：① 顶部工具栏右上角（`TopBar`）；② 底部悬浮编辑栏左侧（`EditBar`）。同一屏内功能重复、信息冗余（截图 2026-08-29），用户要求去掉右上角那个 |
| 复现路径 | 收藏 Tab → 长按一张帖子卡进入编辑模式 → 顶部右上角 + 底部左侧各见一个"全选" |
| 根因 | `Favorite.ets` `TopBar()` editMode 分支（原第 1936~1947 行）与 `EditBar()`（第 1235 行）各自独立渲染"全选"按钮，均调用 `toggleSelectAll()`，功能重复；两者视觉样式（`fs(14)/fs(15)`、`height(40)/44`）还不一致 |
| 修复 | **2026-08-29 已实施**：删除 `TopBar()` editMode 分支中的右上角"全选/取消全选"按钮（13 行），保留底部 `EditBar` 的"全选"；"已选 X 项"标题的 `.layoutWeight(1)` 自动撑满整行，顶部变为「返回箭头 + 已选 X 项」，与分类详情非编辑态「返回 + 分类名 + 编辑」视觉范式一致；`toggleSelectAll/allSelected` 仍由 `EditBar` 使用，无死代码；`read_lints` 零错误 |
| 影响面 | 编辑态顶部工具栏（收藏 Tab 全部视图通用）；仅删 UI 冗余入口，`toggleSelectAll` 逻辑与 `EditBar` 不受影响 |
| 验证口径 | 编辑态顶部仅「返回 + 已选 X 项」、无右上角"全选"；底部悬浮栏"全选/取消全选/移入/删除(X)"完整可用；"已选 X 项"标题撑满整行不截断；退出编辑恢复正常 TopBar；无 ANR |

### BUG-08 · 自定义分类内帖子列表顶部预留空间过多【已修复】

| 项 | 内容 |
|---|---|
| 现象 | 自定义分类 Tab → 点击某个收纳夹（分类）进入分类内帖子列表（`CategoryThreadsView`），第一张帖子卡上方有**大片空白**（截图 2026-08-29），约 146vp 透明区，约占两张帖子卡高度，视觉失衡 |
| 复现路径 | 收藏 Tab → 自定义分类 Tab → 点击任意分类 → 帖子列表顶部空白过大 |
| 根因 | `Favorite.ets` 帖子列表顶部有一个透明占位 `ListItem { Column().height(this.placeholderHeight()) }`（沉浸式列表：`clip(false)` + `expandSafeArea TOP`，首项初始位置需让出顶栏高度以免被遮挡）。`placeholderHeight()`（第 1063~1065 行）按 `selectedForum` 返回 98 / 146——**吧内帖子视图 98，其余 146**。而分类内帖子视图 `selectedForum` 为空串 → 拿到 146vp，明显过大（吧内帖子 98 即可，顶栏高度相同） |
| 修复 | **2026-08-29 已实施**：新增静态常量 `FavoriteTab.THREAD_TOP_PLACEHOLDER = 98`，`CategoryThreadsView`（原第 1880 行）与 `ForumThreadsView`（原第 1439 行）统一改用该常量——分类内帖子顶部占位由 146→98，与吧内帖子一致；`placeholderHeight()` 保留（仍服务吧分类列表 / 分类列表视图，146 不改，用户未反馈该处）；`read_lints` 零错误 |
| 影响面 | 自定义分类内帖子列表（顶部空白减少 48vp）；吧内帖子视图用同一常量、行为不变（原即 98）；吧分类列表 / 分类列表视图不受影响 |
| 验证口径 | 自定义分类内第一张帖子卡距顶栏约 98vp 呼吸空间、无大片空白；下拉刷新正常；帖子列表滚动后首卡可穿透到顶栏毛玻璃下方（沉浸式行为保留）；吧内帖子、吧分类列表、分类列表视图排版与改动前一致；空分类"暂无内容"提示位置正常；无 ANR |

### BUG-09 · 列表底部"黑色 mask 覆盖卡片"导致 UI 不协调【已修复】

| 项 | 内容 |
|---|---|
| 现象 | 已加载完成的列表（特别在编辑态下）底部最后一张卡（截图 "MOONRISE 交流中心"）上方有**梯形黑色遮罩覆盖**，作者/回复数等文字被黑色半蒙版盖住，视觉极不协调；用户反馈"加载过程 UI 不协调" |
| 复现路径 | 收藏 Tab → 任意视图（吧分类/分类/分类内帖子）→ 编辑态或常规态 → 滚到底部或首屏较短的列表 → 观察底部卡片与 EditBar 之间的"黑色 mask" |
| 根因 | `Favorite.ets` `BottomFadeOverlay()`（第 2118~2129 行）实现存在两个问题：① `.height('100%')` 渐变覆盖整个 List 高度而非仅底部；② `BlendMode.DST_IN, BlendApplyType.OFFSCREEN` 离屏蒙版 + 硬编码白色（`#00FFFFFF/#FFFFFFFF`）——DST_IN 公式 `output = dst * src_alpha` 使 `src_alpha=0` 区域 List 内容**完全挖洞透明**，露出 List 下方的页面背景。List 撑满全屏（含 EditBar 容器上半部），EditBar 是 zIndex 15 的全屏透明容器仅底部 74vp 有毛玻璃背景，**其上方 List 完全透明区域看到的是页面背景 `Theme.bg(isDark)`**——暗色 `#101114` / 亮色 `#F2F4F7`。在暗色/对比度强时呈"梯形黑色遮罩"覆盖底部卡片。亮色模式同样会露出浅灰底色，视觉突兀 |
| 修复 | **2026-08-29 已实施**：① `.height('100%')` → `.height(80)`，仅覆盖 List 底部 80vp 区域；② 删除 `BlendMode.DST_IN` 离屏蒙版，改为普通 alpha 合成的渐变 Column；③ 渐变颜色感知 `this.isDark`——暗色 `#E6101114→#00101114`（底 90% 背景色 → 顶透明），亮色 `#E6F2F4F7→#00F2F4F7`，与 `Theme.bg(isDark)` 视觉一致；④ `direction: GradientDirection.Bottom` + 底实/顶透 = 列表底部 80vp 内容**淡出到背景色**（而非完全挖洞），顶部完全显示；⑤ 保留 `hitTestBehavior(HitTestMode.None)` 不拦截点击；⑥ `EditBar` zIndex 15 在 overlay 之上不受影响。`read_lints` 零错误 |
| 影响面 | 所有使用 `BottomFadeOverlay` 的视图：`FolderListView`（第 1360 行）、`ForumThreadsView`（第 1455 行）、`CategoryListView`（第 1667 行）、`CategoryThreadsView`（第 1904 行）；仅改 overlay 视觉，List `blendMode(SRC_OVER, OFFSCREEN)` 沉浸式行为保留 |
| 验证口径 | 亮色 + 暗色模式下：列表底部 80vp 内容平滑淡出到页面背景色（无突兀梯形 mask）；底部卡片文字（作者/回复数）清晰可读；编辑态下 EditBar 仍正常显示在最前（zIndex 15）；沉浸式滚动（首卡可穿透顶栏毛玻璃）保留；点击淡出区域不拦截事件（穿透到 List 卡片）；下拉刷新/上拉加载指示器位置正常；与全局 `Theme.bg/Theme.bottomGlass` 视觉一致 |

### BUG-10 · 切走再切回收藏页，收纳夹内浏览位置丢失（退回分类列表）【已修复】

| 项 | 内容 |
|---|---|
| 现象 | 点击自定义分类（收纳夹）进入分类内帖子列表后，切到其它底部 Tab（如首页），再切回收藏页，内容**自动退回收纳夹列表页**（分类内帖子视图丢失）；吧内帖子视图（`selectedForum`）同病，分类 Tab（吧分类/自定义分类）也会重置回"吧分类" |
| 复现路径 | 收藏 Tab → 自定义分类 → 点任意收纳夹进入帖子列表 → 切到首页 → 切回收藏 Tab → 显示分类列表而非帖子列表 |
| 根因 | `Index.ets`（第 731~741 行）用 `if (this.selectedTab === TabIndex.X)` **条件渲染**各 Tab——切 Tab 时 `FavoriteTab()` 组件被销毁，所有 `@State`（含 `selectedCategoryId`、`selectedForum`、`categoryTab`）**重置为初始默认值**；切回时组件重建、状态全丢，视图按默认值渲染回分类列表页。数据本身（`FavoriteStore`/缓存）无丢失，纯 UI 导航状态丢失 |
| 修复 | **2026-08-29 已实施**（方案：模块级内存导航状态，同步恢复、无闪烁）：`Favorite.ets` 新增模块级变量 `lastCategoryTab / lastSelectedForum / lastSelectedCategoryId`；① 三个 `@State` 初始化改为引用模块变量（组件重建时自动恢复上次浏览位置，同步赋值、无 Loading 闪烁）；② 全部 9 处赋值点（点击分类/点吧/返回/删空退回/分类 Tab 切换）同步写入模块变量；③ 进程重启模块变量自然重置为默认（会话内记忆，符合预期）；④ 编辑态 `editMode/selectedTids` 不做跨组件恢复（安全，切 Tab 退出编辑合理）；`read_lints` 零错误 |
| 影响面 | 收藏 Tab 全部视图（吧分类列表/吧内帖子/分类列表/分类内帖子）；仅状态恢复逻辑，数据链路不动；其它 Tab（首页/吧/消息/我的）不受影响 |
| 验证口径 | 收纳夹内帖子列表 → 切首页 → 切回收藏 = **仍停留在该收纳夹帖子列表**；吧内帖子同理；自定义分类 Tab 切走切回保持所选子 Tab；正常"返回"仍退回分类列表；主动点"吧分类/自定义分类"仍正常切换；下拉刷新/置顶/编辑态功能无回归；进程重启后回默认视图（符合预期） |

---

## 11. 批 A 抓包探测记录【✅ 已完成 · 2026-08-29】

> 方法：DevEco 命令行构建（`hvigorw assembleHap`）→ 模拟器（127.0.0.1:5555）安装运行 → 在 `TiebaService.ets` 的 threadstore 响应解析处临时注入 `hilog` 探测日志（`[TS-PROBE]`）→ 进入收藏 → 进收纳夹 → 下拉刷新触发 threadstore → `hdc shell hilog` 抓取。验证完毕已移除临时日志。

### 探测结果（实机响应）

**threadstore 响应帖子项 22 字段全清单**：

```
thread_id, title, forum_name, author, media, god, is_follow, is_deleted,
post_no, post_no_msg, last_time, type, status, max_pid, min_pid, count,
mark_pid, mark_status, reply_num, floor_num, create_time, thread_type
```

示例（真实响应节选）：
```json
{"store_thread":[
  {"thread_id":"10979588080","title":"求姬恋直/掰弯小说作品推荐","forum_name":"新百合",
   "author":{"lz_uid":"...","name":"...","name_show":"...","user_portrait":"..."},
   "media":[{"type":"pic","size":"338496","width":"560","height":"391",
     "water_pic":"https://tiebapic.baidu.com/forum/w%3D580%3B/...",
     "small_pic":"...","big_pic":"..."}],
   "post_no":"4","post_no_msg":"楼主更新到4楼","last_time":"1787972706",
   "count":"1","reply_num":"7","create_time":"1787927862","thread_type":"0"}]
}
```

### 定案结论

| 项 | 结论 | 对 v1.11 的影响 |
|---|---|---|
| **`collect_time` / `favor_time`** | ❌ **确认不存在**（22 字段全清单无收藏时间） | 「添加时间」**无法云端直取** → 采用**本地增量记录**（批 D `fav_collect_ts_{accountId}`）+ 历史 `lastTime`/`create_time` 兜底，与 §3 定案一致 |
| `last_time`（最后回复时间） | ✅ 存在（unix 秒） | 时间倒序兜底键可用 |
| `create_time`（帖子创建时间） | ✅ 存在（unix 秒） | 兜底键候选 |
| `media` 数组（`water_pic`/`small_pic`/`big_pic`） | ✅ **意外收获：存在封面图 URL** | 文档此前判断"threadstore 无图片字段"不成立；**帖子封面能力候选**（非本次范围，记入后续候选） |
| `author.user_portrait` | ✅ 存在 | 作者头像候选 |
| 接口行为 | 一次返回**全部收藏帖子**（不按收纳夹分页），App 本地按 `forum_name` 聚合 | 收纳夹聚合逻辑正确，无需改动 |

### 抓包顺带验证（BUG 批回归）

- ✅ App 构建部署（debug 未签名 HAP → 模拟器安装启动正常，无崩溃）
- ✅ **BUG-03 本地搜索**：点搜索 → TopBar 变搜索框（"搜索收藏帖子、吧或分类"）+ 初始空态提示，不再跳转 `pages/Search`
- ✅ **BUG-01 系统返回**：搜索态按 Back → 正常退出搜索回收藏列表（`onBackRequest` 首分支生效）

---

## 12. 批 B/C/D 实施记录【✅ 已完成 · 2026-08-29】

> 实施方式：DevEco 命令行 `hvigorw assembleHap` 构建 → 模拟器安装 → `hdc shell uitest` 驱动 UI 截图验证（点击/菜单/切换/重启）。lint 零错误。

### 12.1 代码变更清单

| 文件 | 变更 |
|---|---|
| `common/Constants.ets` | +3 缓存键：`FAVORITE_SORT_MODE` / `FAVORITE_COLLECT_TS` / `FAVORITE_CUSTOM_THREAD_ORDER` |
| `service/FavoriteStore.ets` | +6 API：`loadSortMode`/`saveSortMode`、`loadCollectTimes`/`recordCollectTime`/`removeCollectTime`、`loadThreadOrders`/`saveThreadOrder`（键按 `{accountId}` 隔离） |
| `pages/ThreadDetail.ets` | 收藏动作挂钩：云端成功 `recordCollectTime(accountId, tid)`；取消收藏 `removeCollectTime` |
| `pages/Favorite.ets` | SortMode 枚举；排序状态组；`initSortState` 加载；`rebuildFolders`/`forumThreads`/`categoryThreads`/`sortedCategories` 排序键；`SortMenuPanel`+`SortMenuItem` 菜单；4 视图排序按钮；分类内帖子拖拽（`onItemDragStart`/`onItemDrop`/`ThreadDragPreview`/`persistThreadOrder`）；批量删除清理收藏时间 |

### 12.2 排序键实现（对应 §3 方案）

| 视图 | 名称键 | 时间键（ms） | 自定义 |
|---|---|---|---|
| 吧分类收纳夹 | `forumName.localeCompare` | 吧内帖子最大 `collectTimes[tid]`，兜底 `lastTime*1000` | 置灰（Toast 提示） |
| 吧内帖子列表 | 标题 | 同上逐帖 | 置灰 |
| 自定义分类列表 | `name.localeCompare` | `createdAt` | `sortOrder`（拖拽序） |
| 分类内帖子列表 | 标题 | 本地 `collectTimes`，兜底 `lastTime*1000` | `threadOrders[categoryId]` 拖拽 |

### 12.3 模拟器实机验证（截图确认）

- ✅ 排序按钮：4 视图 TopBar 均出现（`arrow_clockwise` 图标 + 无障碍标签）
- ✅ 排序菜单：5 项竖排下拉面板（名称正/倒序、时间正/倒序（添加时间）、自定义排序），当前项蓝色高亮 + ✓，Material 卡片样式
- ✅ 置灰逻辑：吧分类 Tab 下「自定义排序」置灰；自定义分类 Tab 下可用
- ✅ 切换生效：点「名称正序」→ 收纳夹列表按名称重排（新百合→七龙珠→孤独摇滚→魔法少女小圆→bangdream→咒术回战）
- ✅ 持久化：force-stop 重启 App → 排序偏好保持「名称正序」（`fav_sort_mode_{accountId}`）
- ✅ 默认值：首次进入菜单默认高亮「时间倒序（添加时间）」

### 12.4 已知边界

- **中英混排名称序**：`localeCompare` 依赖系统 locale（中文环境下英文通常排前/穿插），无拼音库不做拼音序（非本批范围）
- **拖拽/持久化**：分类内帖子拖拽与 v1.8 分类卡拖拽同 API（`List.editMode` + `onItemDragStart/Drop`），Custom 模式下 PostCard 长按让位于拖拽（编辑仍可经顶栏「编辑」进入）；模拟器未做长按手势自动化，交互逻辑经编译 + 范式复用保证
- **历史收藏时间**：老数据无本地收藏时间，时间排序兜底用 `lastTime`（帖子最后回复时间）近似；新收藏走 `fav_collect_ts` 增量记录（详见 §11 定案）
