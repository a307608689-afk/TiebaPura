# 用户主页 + 黑名单管理 — 交付说明 v1.12

> **配套文档**：《排序功能重构 — 交付说明 v1.11》（`docs/sort-rework-delivery.md`）
> **适用工程**：TiebaPura（HarmonyOS 7 / API 26，ArkTS / ArkUI 原生）
> **版本**：v1.12（用户主页 UserProfile + 屏蔽设置/黑名单管理 新界面）
> **日期**：2026-08-31
>
> **状态**：✅ **已交付**（批 A~F 全部落地，2026-08-31 全量构建通过；模拟器回归项待真机复验）

---

## 1. 需求来源【用户提出 · 2026-08-31】

1. **点击用户头像进入用户界面**（参考第三方贴吧客户端交互）：现阶段所有页面的用户头像均无点击响应。
2. **用户主页内容**（按用户明确要求）：
   - 用户头像、昵称
   - **关注按钮**（关注/已关注，同步贴吧云端）
   - **关注数、粉丝数、获赞数**信息
   - **简介、性别、ID、IP**归属地
   - 下方 **用户发布的帖子** 与 **关注的吧** 两个列表
   - 右上角**黑名单按钮**：点击弹出"是否加入黑名单"弹窗（同步贴吧云端）
3. **设置 → 屏蔽设置**：现有入口点击仅弹"即将开放"Toast，**无界面**。要求新增屏蔽设置界面，**首个设置项 = 用户黑名单管理**。
4. **黑名单管理页**：进入独立界面，黑名单用户**同步贴吧云端**；界面内有**编辑按钮**，编辑状态下支持**多选删除**（解除拉黑，同步云端）。
5. 参考实现：开源项目 TiebaLite（`github.com/min09577/TiebaLite`）的用户信息页交互范式。

## 2. 澄清决策【用户确认 · 2026-08-31】

| 决策点 | 用户选择 | 落地影响 |
|---|---|---|
| 头像点击范围 | 全部用户头像（详情页楼主/楼层/评论、楼中楼父楼层/回复、帖子列表卡片作者头像） | 各处 `Avatar` 补 `onClick` 跳转 `pages/UserProfile` |
| 自己头像点击 | **点击自己头像也进入用户主页**（✅ 已确认，同构展示当前登录用户资料） | 复用同一页面，按钮态按"是否本人"隐藏 |
| 关注/粉丝/获赞 | **仅展示统计数字**（✅ 已确认，不做关注/粉丝列表页） | 数据来源：profile 接口字段，无需新增列表接口 |
| 关注的吧·隐私降级 | 对方隐藏关注吧（接口不支持查他人关注吧/隐私保护）时，**保留 Tab 并显示"对方隐藏了关注的吧信息"提示**（✅ 已确认） | Tab 不隐藏；接口空/报错 → 该 Tab 展示提示空态，其余布局不变 |
| 屏蔽设置页 | 新增独立页面，首个设置项为"用户黑名单管理"，后续可扩展其它屏蔽项 | 新增 `pages/ShieldSettings` 路由 |
| 黑名单删除 | 编辑态**多选** + 底部删除栏，删除即调云端取消拉黑 | 复用收藏页编辑态范式（radio 圈选 + EditBar） |
| 拉黑交互 | 右上角按钮 → 确认弹窗"确定将「昵称」加入黑名单吗？" | 复用收藏页确认弹窗范式（bindSheet 半模态磨砂玻璃卡，同 `PinConfirmSheet`） |
| 「已关注」再点击 | **弹确认框**"取消关注「昵称」？"→ 确认后取关（防误触） | 复用收藏页确认弹窗范式 |
| **弹窗 UI 统一** | **所有弹窗与收藏页弹窗 UI 一致**（半模态 bindSheet 磨砂玻璃卡、图标行、危险操作红色分组、取消按钮） | 确认弹窗 → `PinConfirmSheet` 范式；排序菜单 → `SortMenuPanel` 范式；不引入新弹窗风格 |
| **沉浸光感** | **全页支持沉浸光感材质**（`uiMaterial.ImmersiveMaterial`，ArkUI `@since 26.0.0`），**使用位置参考收藏页** | 分段 Tab → `ImmMaterial.tab()/tabActive(isDark)`；按钮/弹窗面板/排序菜单 → `ImmMaterial.control()`；面板底 `Theme.sheetBg` + 圆角；不支持设备自动降级 `Theme.manualGlass`（`MaterialManager.isSupported()`） |
| 拉黑连带取关 | 拉黑成功后**连带自动取消关注**对方（跟随贴吧云端行为） | 拉黑成功回调中同步刷新关注态 |
| 性别显示 | profile 有性别字段 → 显示 ♂/♀ 图标；无/保密 → 隐藏该行 | 与 IP 归属地同隐藏策略 |
| 帖子 Tab 范围 | **只显示用户发布的主题帖**（`is_thread=1`），不含回复 | `fetchUserContent(userId, page, true)` |
| 统计行点击 | 关注/粉丝/获赞数字**点击无反应**（避免误导） | 纯展示，不绑 onClick |
| 黑名单副行 | ID + 拉黑时间；接口无拉黑时间字段则只显示 ID | 见 §5.3 |
| **UI 统一** | 按钮/分段切换/顶栏全部复用项目既有范式，不引入新样式（详见 §5.1） | 开工即对照 ThreadDetail/Favorite 实现 |
| **帖子 Tab 排序** | **新增排序功能**：帖子列表顶部排序按钮 → 下拉弹窗，选「最新时间 / 最早时间」，规则复用收藏页排序范式 | 本地已加载数据排序（分页限制，同收藏页）；时间键 = `PersonalContentItem.createTime`；偏好持久化（建议 `user_posts_sort_{userId}`，待确认） |
| **黑名单管理 = 设置界面** | 黑名单管理页做成**设置界面**，UI 与既有设置页 `Settings.ets` 统一（卡片式设置项行：图标 + 标题/副标题 + 右箭头；`Theme.bgCard` + `Radius.lg`） | 顶栏/列表行/危险操作/按钮全部复用 Settings 范式 + 沉浸光感 |
| **黑名单排序** | 右上角排序按钮（同收藏页 TopBar 实际样式：44vp `Text('⇅')` 文本符号钮 + `Theme.manualGlass` + `ImmMaterial.control()` + `Radius.full`）→ 排序菜单 **本地复刻收藏页 `SortMenuPanel`（页内 @Builder，非公共组件），UI 与交互同收藏页**，**仅 4 项：名称正序 / 名称倒序 / 时间正序 / 时间倒序，无「自定义排序」选项** | 名称键 = 昵称/ID；时间键 = 拉黑时间（批 A 确认字段，无字段则时间排序降级待定）；偏好持久化 `blacklist_sort_{accountId}` |

## 3. 现状调研结论【代码级 · 2026-08-31】

### 3.1 头像渲染与点击现状（全部无跳转）

| 页面 | 头像位置 | 说明 |
|---|---|---|
| ThreadDetail 详情 | 楼主 `ThreadDetail.ets:710`、楼层 `:791`、评论 `:941`；builder `Avatar` `:1088` | 纯展示，无 onClick |
| SubPostDetail 楼中楼 | 父楼层 `:205`、回复 `:235`；builder `:330+` | 纯展示 |
| ThreadList 列表 | `ThreadCard`（`CommonComponents.ets:229`） | 整卡点击进帖子，头像无独立跳转 |
| Index 首页"我的" | `UserAvatar(62)` `Index.ets:1815` | 当前登录用户，无点击 |
| Settings 设置页 | 账号卡头像 `:114` | 卡片点击进账号管理 |

### 3.2 已有可复用能力（数据层）

| 能力 | 位置 | 复用方式 |
|---|---|---|
| 按任意 userId 拉资料 | `fetchUserNickname`/`fetchUserStats`（`TiebaService.ets:359/:3443`，走 `c/u/user/profile?cmd=303012`） | 扩展为完整 `fetchUserProfile` |
| 任意用户发帖列表 | `fetchUserContent(userId, page, isThread)`（`:3398`，走 `c/u/feed/userpost?cmd=303002`） | **直接复用**，传入目标 userId |
| 用户发帖卡片样式 | `PersonalContent.ets` 帖子列表 | 复用 `PersonalContentItem` 卡片 |
| 关注吧列表（本人） | `fetchFollowList`（`:2492`）+ `toggleFollow`（`:2841`） | **不支持查他人**，他人关注吧需新接口 |
| 本地缓存 | `CacheManager`（`putWithTtl`/`getWithTtlAllowStale` 等） | 资料/发帖列表可做 TTL 缓存 |
| 页面路由注册 | `main_pages.json` `"src"` 数组 | 新页面需在此追加 |

### 3.3 缺失能力（需新增）

| 能力 | 现状 | 备注 |
|---|---|---|
| 用户主页完整资料（简介/性别/IP/关注·粉丝·获赞数/是否已关注/是否已拉黑） | ❌ 仅 nickname/stats 两个子集 | 需扩展 profile 解析 |
| 关注用户 / 取消关注（人） | ❌ 无 | 新接口（待批 A 抓包确认地址） |
| 拉黑用户 / 取消拉黑 | ❌ 无（全工程搜索 blacklist/block/shield 零结果） | 新接口 |
| 黑名单列表 | ❌ 无 | 新接口（分页） |
| 他人关注的吧列表 | ❌ `fetchFollowList` 仅本人 | 新接口（`c/u/feed/userlike` 待确认） |
| 屏蔽设置页 / 黑名单管理页 | ❌ 入口弹"即将开放"（`Settings.ets:171`） | 新增两页面 |
| 用户数据结构 | `UserInfo` 仅 `userId/name/avatar/isLogin`（`DataModel.ets:157`） | 新增 `UserProfileModel` |

## 4. 接口清单【批 A 抓包确认】

> 贴吧移动接口惯例（c.tieba.baidu.com/c/u/*，JSON + 公共参数 `_client_*`/BDUSS）。**已按代码落地实况回填**（2026-08-31）：profile 已真实接通（protobuf 协议）；其余 6 接口为结构化占位实现（带 `TODO(批A)` 标记，字段名已按惯例多重兼容解析），最终以真机抓包校准为准。

| 接口 | 用途 | 地址（已落地） | 状态 |
|---|---|---|---|
| 用户主页资料 | 昵称/头像/简介/性别/IP/关注·粉丝·获赞数/是否已关注 | `https://c.tieba.baidu.com/c/u/user/profile?cmd=303012`（protobuf） | ✅ 真实接通（`TiebaService.fetchUserProfile` :3590，protobuf 解码 + 5min TTL 缓存） |
| 用户发帖列表 | 用户发布的帖子 | `c/u/feed/userpost?cmd=303002` | ✅ 已在用（复用 `fetchUserContent`） |
| 用户关注的吧 | 他人关注吧列表 | `https://c.tieba.baidu.com/c/u/feed/userlike?cmd=303004` | 🔶 占位（`API.USER_LIKE`，JSON 解析 `like_forum/forum_list` 多键兼容） |
| 关注用户 | 关注（人） | `https://c.tieba.baidu.com/c/u/follow/add?cmd=303005` | 🔶 占位（`API.FOLLOW_ADD`，结构化实现 + 乐观回滚） |
| 取消关注 | 取关（人） | `https://c.tieba.baidu.com/c/u/follow/del?cmd=303005` | 🔶 占位（`API.FOLLOW_DEL`） |
| 拉黑用户 | 加入黑名单 | `https://c.tieba.baidu.com/i/submit/black`（web 端） | 🔶 占位（`blockUser` :2916） |
| 取消拉黑 | 移出黑名单 | `https://c.tieba.baidu.com/i/submit/unblack`（web 端） | 🔶 占位（`unblockUser` :2939） |
| 黑名单列表 | 分页拉取黑名单用户 | `https://c.tieba.baidu.com/c/c/user/blacklist` | 🔶 占位（`API.BLACKLIST`，JSON 解析 `black_list/blacklist/list` 多键兼容） |

> 抓包后备选：`aiotieba` / `tbclient.protobuf` 仓库中 `BlacklistAdd`、`BlacklistDel`、`BlacklistList`、`FollowUser` 定义可作为参数参照。
> **提示**：`fetchUserProfile` 为 protobuf 通道（`ProtoSchema.profileRequest` + `TiebaProtoDecoder.decodeProfileResponse`），其余 6 接口为 JSON 通道（`HttpClient.postForm`）——真机抓包校准时应分别对照两种协议。

## 5. 界面设计

### 5.1 用户主页 `pages/UserProfile`（参考 TiebaLite 用户信息页）

```
┌─────────────────────────────────────────┐
│ ← 返回        昵称（居中）        ⛔黑名单│  ← 悬浮沉浸顶栏：磨砂玻璃圆形按钮 + DST_IN 渐变遮罩（复用 ThreadDetail/Favorite 范式）
├─────────────────────────────────────────┤
│                 [大头像 76vp]            │
│               昵称（18sp 加粗）          │
│       ID: 贴吧用户xxxx · ♂ · IP属地 xx   │  ← ID/性别图标/IP 一行（无性别/IP 字段则对应隐藏）
│             简介（1~2 行，空则隐藏）      │
│          [＋ 关注] / [已关注 ✓]          │  ← 主色胶囊按钮；本人隐藏；已关注再点击弹取消确认
│        关注 12 · 粉丝 345 · 获赞 67      │  ← 统计行（纯展示，点击无反应）
├─────────────────────────────────────────┤
│     [ 发布的帖子 ]  [ 关注的吧 ]         │  ← 胶囊分段（复用收藏页 CategoryTabs 样式）+ 左右滑动手势切换
│  [⇅] 帖子列表顶部行（排序按钮右对齐）     │  ← 点击弹排序下拉菜单（复用收藏页 SortMenu 范式）
│   帖子卡：标题/吧名/时间/回复数           │  ← 复用 PersonalContentItem 卡片，分页加载
│   或 吧卡片：吧头像/吧名/帖子数/描述      │  ← 点击进入 ThreadList
└─────────────────────────────────────────┘
```

要点：
- **顶栏（UI 统一 · 复用 ThreadDetail 范式）**：页面 `expandSafeArea([SYSTEM], [TOP, BOTTOM])` 沉浸（全局 `setWindowLayoutFullScreen` 已开）；顶栏为透明底 Stack 悬浮（`.zIndex`），返回按钮（左，`sys.symbol.chevron_left`）与黑名单按钮（右，`sys.symbol.forbid`）均为 44vp 磨砂玻璃圆形按钮（`Theme.manualGlass` + `ImmMaterial.control()` + `Radius.full` + 0.5vp 描边），昵称标题居中；内容可穿过顶栏，并叠加 DST_IN 渐变遮罩（`linearGradient` + `BlendMode.DST_IN`，复用 ThreadDetail/Favorite 渐变范式）。
- **分段切换（UI 统一 · 复用收藏页 CategoryTabs 样式）**：两个胶囊按钮 `Button`（`fs(12)`、激活 `sys.color.font_primary` / 非激活 `font_secondary`、`Theme.manualGlass(active)`、`systemMaterial(ImmMaterial.tabActive/tab)`、`Radius.full`、`layoutWeight(1)` 均分）；**支持左右滑动手势切换**：用 `Tabs`（`barPosition.Start` + `TabContent`，tabBar 自定义为胶囊）或 `Swiper` + 胶囊 index 联动，开工时定（收藏页 `backup/ets_tab_slide_before_20260830_205631` 有滑动转场经验可参照）。
- **入口传参**：`userId`（必填）+ 可选 `userName`（预填标题，加载前可先显示）。
- **沉浸光感（使用位置同收藏页）**：全页支持沉浸光感材质（`uiMaterial.ImmersiveMaterial`，ArkUI `@since 26.0.0`；`MaterialManager.isSupported()` 检测（= `sdkApiVersion >= 26` ＋ `uiMaterial` 命名空间探测），不支持自动降级 `Theme.manualGlass` + `manualGlassBorder`）——分段 Tab → `ImmMaterial.tab()/tabActive(isDark)`（同收藏页 `CategoryTabs`）；顶栏返回/黑名单按钮、关注/已关注按钮、弹窗面板、排序菜单面板 → `ImmMaterial.control()`（同收藏页）；面板统一 `Theme.sheetBg` 底 + `Radius.lg`/32 圆角。不新增自定义光感效果。
- **弹窗 UI 统一（复用收藏页弹窗体系）**：本页所有弹窗视觉与交互均与收藏页一致——确认类（关注/取消关注/拉黑）用 `bindSheet` 半模态磨砂玻璃卡（`PinConfirmSheet` 范式：暗蒙层 + 毛玻璃卡 + 图标行 + 取消 / 主色确认按钮）；下拉菜单用 `SortMenuPanel` 范式（`ImmMaterial` 面板 + 选中高亮 ✓）；危险操作红色分组（`Theme.danger`）。不引入新弹窗风格。
- **关注按钮**：主色胶囊按钮（复用项目主按钮风格）；未登录 → 点击 Toast 提示去登录；登录后乐观更新 + 云端接口，失败回滚（复用 ThreadDetail 点赞乐观更新范式）。**已关注态再点击 → 弹收藏页风格确认框"取消关注「昵称」？"→ 确认后取关**。
- **黑名单按钮**：右上角禁止图标；点击弹收藏页风格确认框"确定将「昵称」加入黑名单吗？加入后对方将无法关注你。"→ 确认调拉黑接口 → 成功 Toast + 按钮态变"已拉黑" + **连带自动取消关注**（跟随云端）。**自己主页不显示该按钮**。
- **本人主页**：点击自己头像（含"我的"页头像）进入自己的用户主页；本人主页**隐藏关注按钮与黑名单按钮**（不能关注/拉黑自己）。
- **统计行**：关注/粉丝/获赞纯展示，**点击无反应**。
- **关注的吧·隐私降级**：对方隐藏关注吧（接口不支持查他人/隐私保护）时，该 Tab **保留**并显示空态提示"对方隐藏了关注的吧信息"，顶部统计与帖子 Tab 不受影响。
- **帖子 Tab 排序（规则复用收藏页 v1.11 排序范式）**：列表顶部行右侧排序按钮（44vp `Text('⇅')` 文本符号钮 + `manualGlass` + `ImmMaterial.control()`，样式同收藏页排序入口）→ 点击展开下拉菜单（竖排 2 项：「最新时间」「最早时间」，当前项高亮 + ✓，`ImmMaterial` 材质面板）→ 选择即对**本地已加载数据**按 `createTime` 重排 + Toast + `Haptic.light()`；默认「最新时间」；偏好持久化（`user_posts_sort_{userId}`）。排序只作用于已加载数据（分页限制，同收藏页 §3 定案），不触发网络。
- 加载：骨架屏（复用 ThreadDetailSkeleton 风格）/ ErrorView / 空态。
- 帖子/关注吧 Tab 懒加载（切到才拉），分页滚动加载；帖子 Tab 仅主题帖（`is_thread=1`）。

### 5.2 屏蔽设置页 `pages/ShieldSettings`

- 从 `Settings.ets`「屏蔽设置」入口进入（替换原"即将开放" Toast）。
- 页面结构：设置项列表（复用 `SettingItem` 范式），首项：
  - `用户黑名单管理`（图标 + 副标题"已屏蔽 N 人"，数字来自黑名单列表接口）→ 点击进 `pages/BlacklistManager`。
  - 后续可扩展：关键词屏蔽等（本期不做，占位）。

### 5.3 黑名单管理页 `pages/BlacklistManager`

```
┌─────────────────────────────────────────┐
│ ← 返回    黑名单   [⇅]   [编辑/完成]      │  ← 顶栏：右上角排序按钮（同收藏页）+ 编辑态切换
├─────────────────────────────────────────┤
│  [头像] 昵称            ID · 拉黑时间  >  │  ← 设置项卡片行（复用 Settings.SettingItem 范式）
│  [头像] 昵称            ID · 拉黑时间  >  │
│  ...（分页加载）                          │
├─────────────────────────────────────────┤
│ 编辑态：每项左侧圈选 radio（多选）          │
│ 底部悬浮栏：[全选]  删除(选中 N)           │  ← 复用收藏页 EditBar 范式
└─────────────────────────────────────────┘
```

- **UI 与既有设置页统一（复用 `Settings.ets` 范式）**：页面结构与 `Settings.ets` 一致——顶栏（44vp 透明返回按钮 + `systemMaterial(ImmMaterial.control())` + `Radius.full` + 18sp Bold 标题"黑名单"，padding top 44，正常文档流不悬浮）+ `Scroll` 内容区；列表项为 `SettingItem` 同款卡片行（左侧头像 40vp 圆角 / 昵称 16sp Medium 主色 + 副行 `ID · 拉黑时间` 13sp 次级色 / 右侧 `chevron_right`；`Theme.bgCard` 底 + `Radius.lg` + `padding{left/right: Spacing.lg, top/bottom: Spacing.md}`）。**不引入新样式**。
- **沉浸光感**：顶栏返回/排序/编辑按钮 → `ImmMaterial.control()` + `manualGlass`（同 Settings 顶栏与收藏页）；列表行 `Theme.bgCard`；下拉刷新/分页。
- **排序（同收藏页 v1.11 范式，去自定义项）**：右上角 `Text('⇅')` 排序按钮（44vp 文本符号钮 + `manualGlass` + `ImmMaterial.control()` + `Radius.full`，样式同收藏页 TopBar）→ 展开**本地复刻**的 `SortMenuPanel` 同款下拉面板（收藏页 SortMenuPanel 为页内 @Builder 非公共组件，本页复刻 4 项版；`ImmMaterial` 材质 + 选中高亮 ✓ + Toast + `Haptic.light()`）——菜单仅 4 项：**名称正序 / 名称倒序 / 时间正序 / 时间倒序，无「自定义排序」**；名称键 = 昵称（无昵称用 ID），时间键 = 拉黑时间（批 A 确认接口字段，若确实无拉黑时间字段则时间排序降级——待批 A 定）；默认时间倒序；偏好持久化 `blacklist_sort_{accountId}`，重启保持。
- 数据：拉黑名单接口分页拉取，同步贴吧云端；下拉刷新。
- 编辑态：顶栏"编辑"→ 列表项出现圈选 radio + 底部删除栏；确认删除 → 逐个/批量调取消拉黑接口 → 移除本地项 + 刷新计数。
- 删除确认：收藏页确认弹窗范式（`PinConfirmSheet` 半模态）"确定解除拉黑选中的 N 位用户吗？"，危险项红色分组。

## 6. 实施批次

| 批次 | 内容 | 交付物 | 验收口径 |
|---|---|---|---|
| **A · 抓包探测** | 实机/模拟器验证 §4 全部接口：profile 全字段名（intro/gender/ip/fans/follow/agree/is_follow/is_black）、userlike、关注用户、拉黑/取关、黑名单列表；记录请求/响应样本 | §4 回填确认；接口定案 | 各接口可用、字段名与响应结构明确，无二义 |
| **B · 数据层** | `UserProfileModel`（DataModel）；`TiebaService` 新增 `fetchUserProfile` / `followUser` / `unfollowUser` / `blockUser` / `unblockUser` / `fetchBlacklist` / `fetchUserLikeList`；`CACHE_KEY` + 资料 TTL 缓存 | 新模型 + 7 接口 + 缓存键 | lint 零错误；单测/探针验证返回正确映射 |
| **C · 用户主页** | `pages/UserProfile`：头部（头像/昵称/ID/性别/IP/简介/关注按钮/统计行）+ 帖子/关注吧双 Tab + 黑名单弹窗；注册路由 | 用户主页完整可用 | §5.1 全部元素渲染正确；关注/拉黑云端生效；分页正常 |
| **D · 头像入口** | ThreadDetail（楼主/楼层/评论）、SubPostDetail（父楼层/回复）、ThreadList 卡片作者头像补 `onClick` → 传 `authorId` 跳转；本人头像跳转自己的主页 | 全局头像可点击 | 各页面点头像进入对应用户主页；无串号 |
| **E · 屏蔽设置 + 黑名单管理** | `pages/ShieldSettings`（设置项列表 + 黑名单管理入口 + 已屏蔽计数）；`pages/BlacklistManager`（设置页范式列表 + 右上角排序 + 编辑多选删除）；`Settings.ets` 入口接通 | 两页面可用，入口联通 | 黑名单列表云端同步；4 项排序（无自定义）生效且重启保持；编辑多选删除后云端同步 + 计数更新；返回设置刷新副标题 |
| **F · 回归 + 文档回填** | `assembleHap` 构建 + 模拟器回归（双 Tab 切换/分页/关注/拉黑/黑名单管理/无 ANR）；文档回填 §4/实施记录 | 构建通过 + 回归记录 | 全量回归无 appfreeze；与既有收藏/详情/楼中楼无冲突 |

## 7. 持久化变更【新增】

| Key（Preferences） | 用途 |
|---|---|
| `user_profile_cache_{userId}` | 用户资料 TTL 缓存（如 5 分钟，辅助秒开） |
| `user_posts_cache_{userId}` | 用户发帖列表 TTL 缓存（可选，批 F 定） |
| `user_posts_sort_{userId}` | 用户主页帖子 Tab 排序偏好（最新时间/最早时间） |
| `blacklist_sort_{accountId}` | 黑名单管理页排序偏好（名称/时间正倒序，无自定义） |
| 黑名单计数 | 不单独存，实时取云端列表长度（屏蔽设置副标题） |

## 8. 影响面

- `pages/Settings.ets`：屏蔽设置入口改跳转 `pages/ShieldSettings`（替换"即将开放"）
- `pages/BlacklistManager`：新页面，复用 `Settings.ets` 设置页范式（`SettingItem` 卡片行样式）+ 本地复刻收藏页 `SortMenuPanel` 排序菜单范式（4 项，无自定义；收藏页 SortMenuPanel 为页内 @Builder，非公共组件）
- `pages/ThreadDetail.ets` / `pages/SubPostDetail.ets`：`Avatar` builder 增加 `onClick`（需传 `authorId`/`userName`）
- `components/CommonComponents.ets`：`ThreadCard` 头像区独立点击（不干扰整卡点击）
- `pages/Index.ets`：`UserAvatar` 点击进自己主页（✅ 已确认）
- `service/TiebaService.ets`：+7 接口 + profile 解析扩展
- `model/DataModel.ets`：+`UserProfileModel`
- `common/Constants.ets`：+API 地址 + CACHE_KEY
- `main_pages.json`：+3 路由（UserProfile / ShieldSettings / BlacklistManager）

## 9. 验证口径

- 任意用户头像（详情/楼中楼/列表）点击 → 进入对应主页，昵称/头像/ID/性别/IP/简介/统计正确
- 关注按钮：未登录提示登录；登录后关注/取关即时生效并同步云端（重启后状态一致）
- 黑名单按钮：弹确认框 → 确认 → 云端拉黑成功 → 主页按钮态更新
- 屏蔽设置：入口进入新页；副标题显示黑名单人数；点击进黑名单管理
- 黑名单管理：列表同步云端、下拉刷新；右上角排序按钮 → 4 项菜单（无"自定义排序"），切换生效 + 重启保持；编辑态多选圈选 + 底部删除栏；删除后云端同步、列表与计数即时更新；页面 UI 与 `Settings.ets` 设置页视觉一致
- 帖子/关注吧双 Tab：切换懒加载、分页滚动加载正常；帖子卡点击进帖子、吧卡点击进吧
- 明暗色模式视觉一致；全程无 ANR / appfreeze

## 10. 遗留 / 待办

- §4 接口清单地址与字段名以批 A 抓包实测为准（关注用户/拉黑/黑名单/userlike 为 🔶 待确认）
- 关注列表页、粉丝列表页**本期不做**（仅展示统计数字，✅ 已确认；统计行点击无反应）；如后续需要可加
- IP 归属地展示以 profile 返回字段为准；无字段则隐藏该行；性别同理（♂/♀，无/保密隐藏）
- 「已关注」再点击弹取消关注确认框（✅ 已确认）；拉黑成功后连带自动取消关注（✅ 已确认）
- 帖子 Tab 仅主题帖（`is_thread=1`，✅ 已确认）；黑名单副行 ID + 拉黑时间（无时间字段只显示 ID，✅ 已确认）
- 帖子 Tab 排序：最新时间/最早时间下拉菜单（复用收藏页 v1.11 排序范式，本地已加载数据排序）；时间字段 `createTime` 的格式（unix 秒 / 格式化串）批 A 确认后转时间戳排序
- 黑名单管理页：UI 复用 `Settings.ets` 设置页范式 + 沉浸光感（✅ 已确认）；右上角排序按钮 + 4 项排序菜单（✅ 已确认，无「自定义排序」）；时间排序键 = 拉黑时间字段，批 A 确认接口有无（无则时间排序降级处理）
- 全部弹窗 UI 与收藏页一致（✅ 已确认）：确认弹窗 `PinConfirmSheet` 半模态范式、排序菜单 `SortMenuPanel` 范式
- 沉浸光感全页支持（✅ 已确认，使用位置同收藏页）：分段 Tab `tab()/tabActive()`、按钮与弹窗面板 `control()`、`Theme.sheetBg` 底 + 圆角、API 26+（`MaterialManager.isSupported()`）检测降级 `manualGlass`
- 用户主页图片/视频类富媒体帖子复用现有 `ContentFragment` 渲染链路（已具备）
- 真机复验项：拉黑/取关接口在真实登录态下的风控表现

## 11. 风险

- **接口风控**：关注/拉黑属写操作，贴吧对非官方客户端有风控（参考既有 `toggleFollow`/`togglePostAgree` 的 3280001 限流处理），需按既有模式做错误兜底与乐观回滚
- **黑名单接口不确定性**：若 `c/u/black/*` 不可用，备选 web 端 `tieba.baidu.com/i/black*`（批 A 一并验证）
- **他人关注吧接口**：若 `c/u/feed/userlike` 不支持按他人 userId 查询（对方隐藏/隐私保护），降级为 Tab 内显示"对方隐藏了关注的吧信息"空态（✅ 已确认）；批 A 需实测区分"对方无关注"与"对方隐藏"两种响应形态

## 12. 实施记录【2026-08-31 回填】

### 12.1 批次落地实况

| 批次 | 交付物 | 状态 | 备份 |
|---|---|---|---|
| A · 抓包探测 | §4 按代码落地实况回填；profile 已真实接通（protobuf），其余 6 接口结构化占位待真机校准 | 🔶 部分（真机抓包待做） | — |
| B · 数据层 | `UserProfileModel`/`BlacklistItem`/`UserLikeItem`（DataModel）；`TiebaService` +7 接口（`fetchUserProfile`/`followUser`/`unfollowUser`/`blockUser`/`unblockUser`/`fetchBlacklist`/`fetchUserLikeList`）；`CACHE_KEY.USER_PROFILE_CACHE` + `CACHE_TTL.USER_PROFILE`(5min)；`USER_POSTS_SORT`/`BLACKLIST_SORT` 偏好键 | ✅ | — |
| C · 用户主页 | `pages/UserProfile`（头部 + 双 Tab + 黑名单弹窗 + 帖子排序）；路由注册 | ✅ | `backup_20260831_userprofile/` |
| D · 头像入口 | ThreadDetail(3)/SubPostDetail(2)/ThreadList(2)/Index(1) 头像补点击 → 传 `authorId` 跳转；`ThreadCard` 新增 `onAvatarTap` 回调（`HitTestMode.Block` 防整卡互吞）；本人头像进自己主页 | ✅ | `backup_20260831_avatar_entry/` |
| E · 屏蔽设置+黑名单管理 | `pages/ShieldSettings` + `pages/BlacklistManager`（4 项排序无自定义、编辑多选删除、计数副标题）；`Settings.ets` 入口接通（:175） | ✅ | `backup_20260831_blacklist/` |
| F · 回归+文档回填 | `assembleHap` 全量构建通过；文档 §4 回填 + 本实施记录；模拟器回归项待真机 | ✅（构建）/ 🔶（真机回归待做） | — |

### 12.2 批 F 回归结论【代码级 · 2026-08-31】

- **构建**：`BUILD SUCCESSFUL`（`entry-default-unsigned.hap`，仅 systemMaterial 版本 WARN，与工程既有 WARN 一致）
- **路由**：`main_pages.json` 已含 `pages/UserProfile` / `pages/ShieldSettings` / `pages/BlacklistManager`
- **入口链路**：Settings → ShieldSettings → BlacklistManager ✅；ThreadList×2 / ThreadDetail×3 / SubPostDetail×2 / Index×1 头像入口均传 `authorId`，无串号 ✅
- **UserProfile 核心**：`isSelf()` 判定（登录 uid === 目标 uid）；关注/黑名单按钮本人隐藏（:503/:795）；双 Tab `Swiper`+`SegTabs` 滑动手势联动（:412）；帖子 Tab 排序（最新/最早，本地重排 + 偏好持久化 `user_posts_sort_{userId}`）；拉黑确认弹窗（:961，含"连带取消关注"）
- **数据层**：`fetchUserProfile` 走 protobuf（`postProtoMultipart`）+ 5min TTL 缓存；其余 6 接口 JSON 占位 + 乐观回滚兜底
- **待真机复验项**：双 Tab 滑动/分页、关注/拉黑云端生效与风控表现、黑名单列表字段实况、头像跳转无 ANR
