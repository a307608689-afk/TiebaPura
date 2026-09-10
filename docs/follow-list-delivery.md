# 关注列表页 — 交付说明 v1.13

> **配套文档**：《用户主页 + 黑名单管理 — 交付说明 v1.12》（`docs/user-profile-delivery.md`）
> **适用工程**：TiebaPura（HarmonyOS 7 / API 26，ArkTS / ArkUI 原生）
> **版本**：v1.13（关注列表页 FollowList + 统计行交互调整 + 关注接口修复）
> **日期**：2026-08-31
>
> **状态**：📝 **交付文档**（待实施，用户明确"先不开工"）

---

## 1. 需求来源【用户提出 · 2026-08-31】

1. **统计行交互调整**：用户主页 `UserProfile` 头部统计行中，「关注」数字改用接口 `concernNum` 字段，**去掉「获赞」**（仅保留「关注 · 粉丝」两项）。
2. **关注列表入口**：点击「关注」数字跳转**新页面**，展示**我关注的用户**列表。
3. **一键切换**：关注列表页右上角按钮，一键切换「我的关注 / 互相关注」，**无弹窗**，本地按 `is_friend` 字段过滤。
4. **关注接口修复**：`followUser` / `unfollowUser` 请求参数改用 **`portrait + tbs`**（修复关注失败问题）。
5. **设计图**：用户提供关注列表设计图（2026-08-31），作为本页 UI 的视觉基准。

## 2. 澄清决策【用户确认 · 2026-08-31】

| 决策点 | 用户选择 | 落地影响 |
|---|---|---|
| 统计行内容 | **仅「关注 · 粉丝」两项，去掉「获赞」**；关注数字取 `concernNum` | `UserProfile.ets` 统计行删去 `获赞 ${agreeNum}` 段，仅保留关注/粉丝 |
| 统计行点击 | **关注数字可点击** → 跳转关注列表页（展示我关注的用户） | 关注段补 `onClick` → `router.pushUrl` 进 `pages/FollowList` |
| 粉丝数字 | 仍为纯展示（点击无反应） | 不绑 onClick |
| 列表范围 | **我的关注**（本人关注的用户） | 新列表接口（分页），非本人主页也按本人关注展示 |
| 默认列表态 | **进入关注列表页默认展示「全部关注」** | 副标题显示全部关注总数；切「互相关注」才过滤 |
| 切换显示数量 | **切换「互相关注」时副标题显示互相关注的数量** | 副标题数字随当前切换态变化（全部=总数；互相关注=`is_friend` 计数） |
| 右上角切换 | **一键切换「我的关注 / 互相关注」，无弹窗**，本地按 `is_friend` 过滤 | 顶栏按钮文本随态切换（`我的关注 ⇅` / `互相关注 ⇅`）；「互相关注」= 已加载列表内 `is_friend === true` 本地过滤，不发新请求 |
| **排序按钮** | **在切换文本钮左侧再加排序按钮**，参考收藏页，**仅去除自定义排序**（4 项：名称正序/倒序、时间正序/倒序） | 顶栏「⇅ 排序钮」在切换钮左边，样式同收藏页 TopBar（44vp 文本符号钮 + `manualGlass` + `ImmMaterial.control()` + `Radius.full`）；排序菜单本地复刻收藏页 `SortMenuPanel`（4 项，无「自定义排序」）；本地已加载数据排序 + 偏好持久化 |
| **编辑多选取关** | **顶栏加「编辑」按钮** → 编辑态**多选批量取关**（同步云端），编辑态 UI **参考收藏页** | 编辑钮在切换钮右侧；编辑态列表项出现圈选 radio + 底部删除栏（复用收藏页 EditBar 范式）；确认删除 → 逐个调 `unfollowUser` → 移除本地项 + 刷新副标题计数 |
| 列表行信息 | 头像 + 昵称 + 副行（来源「来自贴吧关注」+ 个性签名）+ 右侧「已关注」状态 | 参考设计图：副行 `来自贴吧关注` + 简介（✅ 已确认）；右侧按钮显示已关注态 |
| 空态提示 | 设计图副标题下提示「仅展示登录用户和正常账号」（✅ 保留） | 列表顶部常驻提示行（设计图位置） |
| 关注/取关操作 | 列表内可对用户取关（右侧「已关注」按钮点击 → 取关） | 复用 `unfollowUser`（修复后），乐观更新 + 失败回滚 |
| 关注接口修复 | `followUser`/`unfollowUser` 参数改用 **`portrait + tbs`** | 替换原 `uid` 传参（见 §4 修复说明） |
| 弹窗/UI 统一 | 与既有页面一致（沉浸光感、收藏页弹窗/编辑态范式） | 顶栏/按钮/列表复用 UserProfile/Settings 范式；排序菜单/编辑栏/确认弹窗复用收藏页范式 |

## 3. 现状调研结论【代码级 · 2026-08-31】

### 3.1 统计行现状（`pages/UserProfile.ets:565-581`）

- 当前为 `关注 {concernNum} · 粉丝 {fansNum} · 获赞 {agreeNum}` 三行，纯展示，无点击。
- 需改为：仅「关注 · 粉丝」两项；「关注」段可点击跳转；删「获赞」。

### 3.2 关注/取关接口现状（`TiebaService.ets:3671/:3694`）

- `followUser(userId, userName)`：form 传 `uid`/`user_name`/`tbs`/`ie` → `API.FOLLOW_ADD`，**占位实现（TODO 批A）**。
- `unfollowUser(userId)`：form 传 `uid`/`tbs`/`ie` → `API.FOLLOW_DEL`，**占位实现**。
- 返回判定 `resp.includes('"no"') === false`，无结构化解析。
- 修复方向：参照贴吧接口惯例，改用 **`portrait`（用户头像 hash）+ `tbs`** 传参（`portrait` 从 `normalizeAvatar` 链路/`fetchUserProfile` 已可取得）。

### 3.3 关注列表数据能力

| 能力 | 现状 | 备注 |
|---|---|---|
| 关注列表（我关注的用户） | ❌ 无（`fetchFollowList` :2492 是**关注的吧**，非用户） | 需新增接口 |
| `is_friend` 字段 | ❌ 无 | 新列表项模型需含 `isFriend` |
| 用户头像/昵称渲染 | ✅ `Avatar` + `normalizeAvatar`（`TiebaService.ets:2296`） | 直接复用 |
| 用户主页跳转 | ✅ `pages/UserProfile`（收 `userId`/`userName`） | 列表行点击跳转复用 |
| 路由注册 | `main_pages.json` `"src"` 数组 | 新页面需追加 |

### 3.4 可复用资源

- `UserProfile.ets` 顶栏（悬浮沉浸磨砂玻璃按钮）、统计行样式、乐观更新范式。
- `Settings.ets` 列表行卡片范式（头像 + 昵称 + 副行 + 右侧元素）。
- 收藏页确认弹窗范式（取关确认，如需）。
- `AuthManager` 登录态判断。

## 4. 接口清单【已抓包定案 · 2026-08-31】

> **抓包方式**：DevEco 模拟器（hdc）+ 应用内探测代码（`probeFollowUserApis`，hilog 输出响应）+ 对照 tieba.js / aiotieba 开源实现，确定后移除探测代码。

| 接口 | 用途 | 地址（落地） | 状态 |
|---|---|---|---|
| 关注列表 | 我关注的用户（分页，含 `is_friend`） | `POST https://tiebac.baidu.com/c/u/follow/followList` | ✅ 已实测 |
| 关注用户 | 关注（写） | `POST https://tiebac.baidu.com/c/c/user/follow` | ✅ 已定案（aiotieba 对照） |
| 取消关注 | 取关（写） | `POST https://tiebac.baidu.com/c/c/user/unfollow` | ✅ 已定案（aiotieba 对照） |

### 4.1 关注列表接口实测

- **请求**：`POST https://tiebac.baidu.com/c/u/follow/followList`
- **参数**（需签名）：`BDUSS`（登录 Cookie）、`_client_version`（如 `12.57.4.2`）、`pn`（页码，1 起始）、`uid`（当前用户 id）、`sign`
- **签名**：`sign = MD5(参数按 key 字典序拼接为 "k=v" 无分隔符 + salt "tiebaclient!!!")`，**小写**（对齐项目 `signTiebaForm` 既有实现；大写会被服务端判错）
- **响应**：
```json
{
  "error_msg": "", "pn": 1, "has_more": 0, "total_follow_num": 14,
  "follow_list": [
    {
      "id": 2008657725,
      "name": "daygoldboy",
      "name_show": "daygoldboy",
      "portrait": "tb.1.b08733eb.EDFCzYqhdulwaijm9tDpvA?t=...",
      "intro": "系统乱封号，畜生",
      "has_concerned": 1,
      "follow_from": "来自贴吧关注"
    }
  ]
}
```
- **字段映射**：`id`→`userId`；`name_show`→昵称（`贴吧用户_xxx`/`吧友` 等占位名回退 `name`）；`portrait`→头像/`portrait`；`intro`→个性签名；`has_concerned`===1→`isFriend`（互相关注）；顶层 `total_follow_num`→总数、`has_more`→分页。
- **⚠️ 无关注时间字段**：接口返回不含 `follow_time` 等时间戳，`FollowUserItem.followTime` 置 0，排序菜单「时间正序/倒序」降级为接口默认顺序（`Array.sort` 稳定排序保持原序）。

### 4.2 关注/取关接口（aiotieba 对照定案，未在模拟器实测写操作）

- **关注**：`POST https://tiebac.baidu.com/c/c/user/follow`，参数 `BDUSS` + `portrait`（用户头像 hash，非 uid）+ `tbs` + `_client_version` + `sign`
- **取关**：`POST https://tiebac.baidu.com/c/c/user/unfollow`，同参
- 返回 `error_code`（0 成功）；已按此实现 `followUser(portrait, userName)` / `unfollowUser(portrait)`

## 5. 界面设计

### 5.1 关注列表页 `pages/FollowList`（依据用户设计图）

```
┌─────────────────────────────────────────┐
│ ← 返回        关注    [⇅][我的关注⇅][编辑]│  ← 顶栏：悬浮沉浸；排序钮 + 一键切换钮 + 编辑钮
├─────────────────────────────────────────┤
│  共关注 14 个吧友                         │  ← 副标题（默认=总数；切互相关注=互相关注计数）
│  仅展示登录用户和正常账号                  │  ← 常驻提示行（设计图位置）
├─────────────────────────────────────────┤
│  [头像] 昵称                  [已关注 ✓] │  ← 行：头像40vp / 昵称 / 右侧已关注态
│         来自贴吧关注 · 个性签名           │     副行：「来自贴吧关注」+ 简介
│  [头像] 昵称                  [已关注 ✓] │
│  ...（分页加载，下拉刷新）                │
├─────────────────────────────────────────┤
│ 编辑态：每项左侧圈选 radio（多选）          │
│ 底部悬浮栏：[全选]  取关(选中 N)           │  ← 复用收藏页 EditBar 范式
└─────────────────────────────────────────┘
```

要点：
- **顶栏（复用 UserProfile 范式 · 渐变沉浸）**：页面 `expandSafeArea([SYSTEM], [TOP, BOTTOM])` **沉浸**（全局 `setWindowLayoutFullScreen` 已开），内容可穿过顶栏；顶栏为**透明底 Stack 悬浮**（`.zIndex`）+ **渐变顶栏**：顶部叠加 `linearGradient`（从背景色/黑色渐变至透明）**DST_IN 渐变遮罩**，与 ThreadDetail/Favorite/UserProfile 顶栏渐变范式完全一致；返回按钮（左）44vp 磨砂玻璃圆形按钮（`Theme.manualGlass` + `ImmMaterial.control()` + `Radius.full` + 0.5vp 描边）；标题「关注」居中（18sp Bold）；**右上角三个按钮（右→左：排序钮 / 切换钮 / 编辑钮）**：
  - **排序钮（最右外侧）**：`Text('⇅')` 44vp 文本符号钮 + `manualGlass` + `ImmMaterial.control()` + `Radius.full`（**样式同收藏页 TopBar**）→ 点击展开**本地复刻**收藏页 `SortMenuPanel` 同款下拉面板，**仅 4 项：名称正序 / 名称倒序 / 时间正序 / 时间倒序，无「自定义排序」**；名称键 = 昵称，时间键 = 关注时间（接口字段批 A 确认，无字段则降级待定）；本地已加载数据排序，不触发网络；默认名称正序；偏好持久化 `follow_list_sort_{accountId}`
  - **切换钮（排序钮左侧）**：文本钮（`我的关注 ⇅` / `互相关注 ⇅`）→ 点击直接切换（**无弹窗**），当前态高亮；切换「互相关注」时**副标题数字同步变为互相关注计数**；进入页面**默认「我的关注」全量**
  - **编辑钮（最左内侧）**：`编辑` / `完成` 文本钮 → 进入/退出编辑态（见下）
- **副标题行**：`共关注 {N} 个吧友`；默认态 N = 全部关注总数；切「互相关注」后 N = 互相关注计数（`is_friend === true` 数量）；其下常驻提示 `仅展示登录用户和正常账号`（设计图位置，次要色小字）。
- **编辑态（参考收藏页 EditBar 范式）**：点「编辑」→ 列表项左侧出现圈选 radio（多选）、行点击行为变为圈选、右侧「已关注」隐藏；底部悬浮栏 `[全选] 取关(选中 N)`（复用收藏页 EditBar）；确认 → 弹收藏页确认弹窗范式 → 逐个调 `unfollowUser`（`portrait + tbs`）→ 成功移除本地项 + 刷新副标题计数 + 退出编辑态；失败项回滚选中态并 Toast。
- **列表项（复用 Settings 列表行范式 + 沉浸光感）**：左侧头像 40vp 圆角（`normalizeAvatar` 渲染，空走首字占位）；主行昵称 16sp Medium；副行 `来自贴吧关注 · {intro}` 13sp 次级色（无简介则仅「来自贴吧关注」）；右侧「已关注 ✓」状态文本（已关注态显示，点击 → 取关，参照收藏页确认弹窗范式）。
- **点击行**（非编辑态）→ 跳转 `pages/UserProfile`（传 `userId`/`userName`）。
- **「互相关注」态**：顶栏切换后列表仅显示 `isFriend === true` 的行；副标题显示互相关注计数；再次点击切回「我的关注」全量。
- 加载：骨架屏（复用 ThreadDetailSkeleton 风格）/ ErrorView / 空态（空关注列表提示）。
- 分页滚动加载 + 下拉刷新；列表数据 TTL 缓存（可参考收藏页缓存策略）。

### 5.2 统计行调整（`pages/UserProfile`）

- 原 `关注 {concernNum} · 粉丝 {fansNum} · 获赞 {agreeNum}`（`:565-581`）→ 改为 `关注 {concernNum} · 粉丝 {fansNum}`，删「获赞」段。
- 「关注」段 `Text` 补 `onClick` → `router.pushUrl({ url: 'pages/FollowList' })`（未登录提示去登录；登录后进入）。
- 「粉丝」段仍纯展示。

## 6. 实施批次

| 批次 | 内容 | 交付物 | 验收口径 |
|---|---|---|---|
| **A · 抓包探测** | 确认关注列表接口地址/分页/字段（`is_friend`/`portrait`/简介/intro）、`followUser/unfollowUser` 的 `portrait + tbs` 参数实况 | §4 回填确认；接口定案 | 关注列表可取到含 `is_friend` 的用户数据；关注/取关真实生效 |
| **B · 数据层** | `FollowUserItem` 模型（`userId/name/avatar/intro/isFriend`）；`TiebaService` 新增 `fetchFollowUserList` + 修复 `followUser/unfollowUser`（`portrait + tbs`）；`CACHE_KEY` | 新模型 + 新接口 + 修复 | lint 零错误；关注/取关修复后真实生效 |
| **C · 关注列表页** | `pages/FollowList`：顶栏（返回 + 排序钮 + 一键切换钮 + 编辑钮）+ 副标题/提示行 + 列表（分页/刷新/取关）+ 编辑态多选批量取关（收藏页 EditBar 范式）+ 排序菜单（收藏页范式 4 项）+ 行点击跳转主页；`main_pages.json` 注册路由；`UserProfile` 统计行调整（删获赞 + 关注可点） | 新页面可用 + 统计行调整 | §5 全部元素渲染正确；切换（副标题计数联动）/排序/编辑批量取关/跳转正常；统计行仅两项且关注可点 |
| **D · 回归 + 文档回填** | `assembleHap` 构建 + 模拟器回归；文档 §4 回填 | 构建通过 + 回归记录 | 全量回归无 appfreeze；与既有用户主页/收藏/详情无冲突 |

## 7. 持久化变更【新增】

| Key（Preferences） | 用途 |
|---|---|
| `follow_user_list_cache_{accountId}` | 关注列表 TTL 缓存（如 5 分钟，辅助秒开，可选） |
| `follow_list_mode_{accountId}` | 顶栏切换态记忆（我的关注/互相关注，可选，重启保持） |
| `follow_list_sort_{accountId}` | 关注列表排序偏好（名称/时间正倒序，无自定义） |

## 8. 影响面

- `pages/UserProfile.ets`：统计行删「获赞」+「关注」补点击跳转
- `pages/FollowList`：新页面（复用 UserProfile 顶栏/统计行/乐观更新范式、Settings 列表行范式、收藏页 EditBar 编辑态 + 排序菜单 + 确认弹窗范式）
- `service/TiebaService.ets`：`followUser`/`unfollowUser` 改 `portrait + tbs` 传参；新增 `fetchFollowUserList`
- `model/DataModel.ets`：新增 `FollowUserItem`
- `common/Constants.ets`：新增关注列表 API 地址 + CACHE_KEY
- `main_pages.json`：新增 `pages/FollowList` 路由

## 9. 验证口径

- 统计行仅「关注 · 粉丝」两项（无「获赞」）；「关注」数字点击进入关注列表页
- 进入关注列表页**默认展示全部关注**，副标题 = 总数
- 右上角一键切换「我的关注/互相关注」：无弹窗、即时过滤（`is_friend`）、**副标题计数联动**、来回切换正常
- 排序按钮（切换钮左侧）：样式同收藏页 TopBar；菜单仅 4 项（无「自定义排序」）；切换生效 + 重启保持
- 编辑态：多选圈选 + 底部取关栏；确认后逐个调云端接口，成功移除 + 计数刷新 + 退出编辑态；失败项回滚
- 列表内单行取关：确认后云端生效 + 本地移除 + 计数刷新；关注/取关接口 `portrait + tbs` 修复后真实生效（真机复验）
- 行点击进入对应用户主页；明暗色模式视觉一致；无 ANR / appfreeze

## 10. 遗留 / 待办

- ✅ 关注列表接口已抓包定案（§4）；`followUser/unfollowUser` 已按 aiotieba 对照的 `portrait + tbs` 实现（写操作建议后续真机复验风控表现）
- ⚠️ **关注时间字段缺失**：接口无 `follow_time`，时间排序降级为接口默认顺序（已在 §4.1 与 §5.1 注明）
- 「互相关注」本地过滤仅作用于已加载数据（分页限制，同收藏页排序定案）；副标题互相关注计数为已加载数据的 `is_friend` 计数；实测该账号 14 个关注对象 `has_concerned` 全为 1（互相关注），真实含非互关用户的账号待复验
- 关注列表是否展示对方在线/等级等信息：以接口字段为准，设计图未含则不做

## 11. 风险

- **接口风控**：关注/取关为写操作，贴吧对非官方客户端有风控（参考既有 3280001 限流处理），需按既有模式做错误兜底与乐观回滚
- **关注列表接口不确定**：若 `c/u/follow/list` 不可用，备选 `c/u/feed/followlist` / `c/u/friend/getfriendlist`（批 A 一并验证）；`is_friend` 字段缺失时「互相关注」降级为空态提示
- **portrait 传参正确性**：若 `portrait` 与 `uid` 需并存（部分接口版本），以批 A 抓包实测为准

## 12. 实施记录

- **2026-08-31 · 批 B/C 完成**：
  - 数据层：`FollowUserItem` / `FollowListResult` 模型；`TiebaService.fetchFollowUserList`（分页，解析 `is_friend`/`portrait`/`intro`/`total`，接口地址 `API.FOLLOW_USER_LIST` 待批 A 确认）；`followUser`/`unfollowUser` 已修复为 **`portrait + tbs`** 传参
  - `Index.ets`「我的」页统计卡片：改为「关注的吧 / 关注用户 / 我的贴子」；「关注用户」显示当前登录用户关注总数（`fetchFollowUserList` total）并点击跳转 `pages/FollowList`
  - `UserProfile.ets`：统计行恢复为「关注 · 粉丝 · 获赞」纯展示；移除 `openFollowList`；follow/unfollow 调用仍传 `profile.portrait`
  - 新页 `pages/FollowList`：渐变沉浸顶栏（DST_IN `BottomFadeOverlay` + 磨砂玻璃钮）+ 副标题（`共关注 N 个吧友`/`互相关注 N 个吧友` 联动）+ 常驻提示行 + 排序钮/切换钮/编辑钮 + 4 项排序菜单（无自定义）+ 一键切换（本地 `is_friend` 过滤）+ 编辑态多选取关（EditBar 范式）+ 单行取关确认 + 确认居中卡片；路由 `main_pages.json` 已注册
  - 构建：`assembleHap` **BUILD SUCCESSFUL**（仅既有 systemMaterial 兼容性 WARN，无 ERROR）
- **2026-08-31 · 批 A 抓包定案 + 回填**：
  - 模拟器（hdc）实机探测：`c/u/follow/list`（c.tieba 域，无签名）→ `error_code 110001`；其余 `c/u/*` → 405。对照 tieba.js / aiotieba 源码确认真实接口为 **`https://tiebac.baidu.com/c/u/follow/followList`**（POST + sign，MD5 小写 + salt `tiebaclient!!!`），实测返回 14 人完整数据
  - `TiebaService.fetchFollowUserList` 回填真实接口：`BDUSS + _client_version + pn + uid + sign`；解析 `total_follow_num`/`has_more`/`follow_list[]`，映射 `id`→userId、`name_show`→昵称（占位名回退 `name`）、`portrait`、`intro`、`has_concerned`→isFriend；**接口无关注时间，followTime 置 0**
  - `followUser`/`unfollowUser` 按 aiotieba 对照改 `POST /c/c/user/follow`、`/c/c/user/unfollow`（`BDUSS + portrait + tbs + sign`），结构化解析 `error_code`
  - `Constants.ets`：`FOLLOW_ADD`/`FOLLOW_DEL`/`FOLLOW_USER_LIST` 更新为 tiebac 真实地址；移除探测代码（`probeFollowUserApis`/`buildProbeForm`/Index 触发）
  - 模拟器回归：构建 → `hdc install` → 启动 → UI dump 验证——「我的」页统计行「关注用户 **14**」取到真实总数；点击进入关注列表页：`共关注 14 个吧友` + 真实用户列表（昵称/来自贴吧关注·签名/已关注 ✓）+ 排序钮/切换钮/编辑钮渲染正常
  - 构建：`assembleHap` **BUILD SUCCESSFUL**，零错误

> **下一步**：真机复验关注/取关写操作（当前账号关注对象均互相关注，建议找非互关用户验证「互相关注」过滤与副标题计数）；时间排序依赖接口默认顺序。
