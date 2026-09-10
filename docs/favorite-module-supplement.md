# 收藏功能模块 — 给 Craft 的补充交付说明 v1.5

> **配套文档**：《鸿蒙贴吧App"收藏"功能模块产品需求文档（PRD）最终定稿版》
> **适用工程**：TiebaPura（HarmonyOS 7 / API 26，ArkTS / ArkUI 原生）
> **版本**：v1.11（v1.10 全量 + 排序功能重构批次：5 项排序菜单 + 默认时间倒序 + 自定义排序，方案定稿见 `docs/sort-rework-delivery.md`，实施按批次推进）；开发进度第十一批回填
> **日期**：2026-08-29
>
> **使用规则**：本文档与 PRD 配套使用。标注【修订】表示对 PRD 原文的修改；【澄清】表示确认/补全 PRD 含义；【新增】表示 PRD 未覆盖、本次补充。**PRD 未覆盖处以本文档为准。**

---

## 1. 存量资产与复用清单【新增 · 最高优先级】

项目 `TiebaPura`（entry/src/main/ets）已存在收藏基础链路，**禁止重写，必须复用**：

| 能力 | 现有实现位置 | 处置 |
|---|---|---|
| 云端收藏列表拉取（threadstore 接口，分页） | `service/TiebaService.ets` → `fetchCollectedThreads(userId, offset, pageSize)` | **复用**，新增聚合/排序封装，不改底层 |
| 收藏（客户端 API + web 端点双方案兜底，STOKEN 缺失时降级） | `TiebaService.addThreadCollection(tid, fid, userId, tbs, pid)` | **复用** |
| 取消收藏（双方案兜底） | `TiebaService.removeThreadCollection(tid, fid, userId, tbs)` | **复用** |
| STOKEN 探测与缓存（v58/v66 已修坑） | `TiebaService.ensureFreshStoken()` | **复用** |
| 收藏列表页（分页 + 本地缓存合并去重） | `pages/PersonalContent.ets`（mode=collections） | **改造**：收藏列表能力迁移到新模块，旧页面仅保留 posts/likes/history 三个模式 |
| 详情页收藏按钮 + 本地缓存状态反推 | `pages/ThreadDetail.ets`（`isCollectedLocally`） | **改造**：收藏状态改由 EventHub 广播驱动（见 §4.6） |
| "我的"页"我的收藏"入口 | `pages/Index.ets` 第 1491 行 | **废弃**：移除旧入口，改为跳转新"收藏"Tab |

**路由/导航现状**：`Index.ets` 底部导航现有 4 Tab（首页/进吧/消息/我的），`enum TabIndex` 定义于 `Index.ets`。新"收藏"Tab 插入"消息"与"我的"之间，共 5 Tab，需同步调整 `TabIndex`、`BottomItem` 图标映射（`symbolFor`）与 `tabTitle()`。

---

## 2. 数据模型契约【新增 · 开工前提】

### 2.1 吧分类聚合模型（收纳夹）

```
FolderItem {
  fid: string            // 吧 ID（threadstore 未解析，有则填，不阻塞聚合，见 §2.6）
  forumName: string      // 吧名 = 聚合主键（threadstore 已解析）
  avatarUrl: string      // 吧头像 URL（1:1），来源见 §2.4
  threadCount: number    // 该吧下收藏帖数量
  pinned: boolean        // 本地置顶标记
  pinnedAt: number       // 置顶时间戳（排序用）
}
```

### 2.2 帖子卡片模型

```
PostCardItem {
  tid: string
  pid: string
  title: string          // 可能为空，UI 层降级显示"楼主暂无标题"/首楼摘要
  abstract: string
  forumId: string
  forumName: string
  author: string
  replyNum: number
  coverUrl: string       // 首楼图 URL（可为空，空则卡片不展示图片位）
  collectTime: number    // 收藏时间戳(ms)，默认排序字段；由 Service 层从 threadstore 解析转换，见 §2.6
  pinned: boolean        // 本地置顶标记
}
```

### 2.3 自定义分类模型（本地存储）

```
CustomFolder {
  id: string                          // uuid
  accountId: string                   // 所属账号（RDB 表列，多账号隔离，防串数据）
  name: string
  cover: string                       // '' = 首字封面（按 name 首字 + 渐变底色）
                                     // 其他 = 本地图片沙箱路径
  createdAt: number
  threadList: Array<{ tid, pid, addedAt }>   // 移入时间 = 本地排序依据之一
}
```

**存储选型**：自定义分类及其关联关系用 **RelationalStore**（RDB），置顶/排序等轻量偏好用 **Preferences**。存储键名需与现有 `CACHE_KEY` 风格统一（见 `common/Constants.ets`）。

### 2.4 吧头像数据来源【修订 · 已定案：走项目吧首页接口】

云端收藏接口（threadstore）返回数据**不含吧头像**，但项目已有成熟的吧首页头像链路，**直接复用，不新造**：
1. 主路径：聚合后按吧名调用 `TiebaService.fetchForumAvatarByName(forumName)`（已实现，三来源兜底：`frs/page` protobuf → 搜索 HTML → 吧页 HTML，见 `service/TiebaService.ets`）；也可直接复用 `fetchForumThreads` 返回的 `ThreadItem.forumAvatar`（frs/page 响应自带吧头像）或 `getCachedForumHeader().avatar`
2. 缓存：按 fid 内存/Preferences 缓存 24h，聚合刷新时命中缓存则跳过网络，避免频繁触发吧接口风控
3. 兜底：全部来源失败显示吧名首字占位（纯色 `Theme.brand()` 底，样板见 `ThreadList.ets` 第 502-513 行首字占位 Stack；页面级"渐变"语言统一用 `BottomFadeOverlay`，见 `ThreadList.ets` 第 727-738 行，勿在首字占位自绘渐变）

> 注意：`fetchForumAvatarByName` 按吧名（kw）查询，与收藏接口的 fid 需建立映射；聚合时以收藏数据中的吧名为准即可。头像缓存 key 规则：`fid` 已解析则用 `fid`，未解析则用 `forumName` 兜底，避免同一吧双轨缓存。

### 2.4.1 吧头像加载的并发控制与持久化【新增 · v1.5 定案：修复收藏页 THREAD_BLOCK_6S ANR】

**现象（2026-08-29 实测）**：最终版本地缓存 760 帖分布在上百个吧，进入收藏页时 `rebuildFolders` 对每个无头像吧**同步并发**发起 `fetchForumAvatarByName`（每次一个完整 `frs/page` protobuf 请求）→ 几十个并发 POST → 服务器 429 限流 + 主线程 RCP 回调（uv_io_cb）堆积 → `THREAD_BLOCK_6S` ANR（appfreeze 定位：主线程阻塞于 `uvLoopTask`/`uv_io_cb`）。

**修复方案（`pages/Favorite.ets` 落地，模拟器回归通过）**：

1. **受限并发队列**：头像加载统一走 `enqueueAvatarLoad` → `drainAvatarQueue`，同一时间最多 `AVATAR_CONCURRENCY = 2` 个 `frs/page` 请求在途；队列排空后空闲才放行后续入队
2. **在途去重**：`avatarPending: Set<string>` 拦截重复入队（`rebuildFolders` 每次刷新/合并都可能重复触发，去重保证每个吧最多 1 个请求在途）
3. **失败标记**：`avatarFailed: Set<string>`，失败（含 429）的吧**本次会话不再重试**，UI 走首字占位兜底（见 §2.4-3），避免限流窗口内反复打服务器
4. **持久化缓存**：成功解析的头像 URL 写入 `CacheManager`（key：`fav_avatar_map`，`FavoriteTab.AVATAR_CACHE_KEY`），进程重启后 `loadAvatarCache` 直接恢复，**不重新请求**——彻底杜绝"每次冷启动重新打一遍几十个吧接口"

**验证结论**：修复前进入收藏页必 ANR（appfreeze 日志稳定复现）；修复后点击收藏 Tab / 滚动列表 / 重启二次进入均无 ANR，无新增 appfreeze；`NETSTACK_RCP` 确认并发收敛为 2 连接交替、大部分 200、偶发 429（限流窗口期内头像暂显占位属预期兜底，限流解除后重启即恢复）。

### 2.5 备份文件 schema

```json
{
  "app": "TiebaPura",
  "version": 1,
  "exportedAt": "2026-08-28T10:00:00+08:00",
  "folders": [
    { "id": "uuid", "name": "默认收藏", "cover": "", "createdAt": 1700000000000,
      "threads": [ { "tid": "123", "pid": "456", "addedAt": 1700000000000 } ] }
  ]
}
```

### 2.6 数据源字段缺口与解析补充【P0 已抓包回填（§11），结论定案】

对照现有 `fetchCollectedThreads`（threadstore）映射到 `PersonalContentItem` 的代码，发现**两个字段缺口**，必须在 Service 层补齐后再做聚合：

1. **`forumId`（fid）未解析 · 已确认无**：**2026-08-29 模拟器抓包实测**，threadstore 字段清单无 `forum_id`/`fid`/`fname`，仅有 `forum_name`。聚合与头像缓存 key 一律以 forumName 为准（注意同名校的不同吧，跨吧访问详情页再校正）
2. **收藏时间字段语义 · 已确认降级**：**threadstore 不返回 `collect_time`**（实测字段清单确认）。`createTime` 解析优先级维持 `last_time → create_time`；`last_time` 实测为**最后回复/更新时间**（值≈2026-08-28，与"楼主更新到1688楼"吻合），`create_time` 为**发帖时间**（值≈2022-01-07）
   - **"按收藏时间倒序"降级为"按接口默认顺序倒序"**，正/倒序切换仅做本地反转（风险：跨页时顺序会重排，见 §3）
   - 卡片**不展示收藏时间**（无数据来源），`hasCollectTime = false`（§8.3 已定案）；可考虑展示"最后回复时间"（`last_time`，需产品确认）
3. **`mergeItems` 归一化丢字段**：`PersonalContent.ets` 的合并归一化只保留 9 个字段，`forumId`/`forumAvatar` 被丢弃。聚合改造时重写该归一化，保留全字段

> ✅ P0 阻塞已解除（2026-08-29 模拟器抓包回填 §11）。遗留待办：云端样本仅 1 条，**接口默认顺序是否为倒序/稳定尚未验证**（需多收藏几条后二次抓包，见 §11）。

---

## 3. 排序规则修订【修订 · 解决与分页的矛盾】

| 场景 | PRD 原文 | 修订后 |
|---|---|---|
| 吧分类-吧内帖子列表 | 默认按帖子名称正序 | **默认按收藏时间倒序**；正序/倒序切换作用于收藏时间维度 |
| 自定义分类-帖子列表 | 默认按帖子名称正序 | 同上 |
| 吧分类-收纳夹列表 | 默认按吧名称正序 | 保持吧名排序（Unicode 码点序），置顶项恒在顶部，其余按码点序 |
| 搜索页结果 | 未定义 | 按相关度（标题包含优先）→ 收藏时间倒序 |

**原因**：云端接口按收藏时间分页（20 条/页），"名称正序"需要全量数据，与"严禁全量拉取"冲突。名称排序仅用于搜索场景，不用于分页列表全局排序。

---

## 4. 设计决策澄清【澄清/修订】

### 4.1 吧分类"收纳夹列表"无编辑态【修订】
PRD §4.1 收纳夹列表仅支持：长按置顶、点击进入、右上角排序切换。**不提供编辑按钮**，也不进入编辑态（PRD §17 中"编辑态滑出复选框"仅适用于自定义分类）。编辑/删除/移入只发生在**吧内帖子列表**层级。

### 4.2 "移入"语义 = 打本地标签【澄清】
"移入自定义收藏夹"不移动帖子，帖子仍保留在吧分类中。UI 要求：
- 弹窗标题用"加入收藏夹"或保留"移入"但 Toast 明确：`成功移入 [名称]（帖子仍保留在吧分类）`
- 同一帖子可同时存在于多个自定义分类

### 4.3 吧分类编辑态 FAB 操作集【新增】
编辑态勾选帖子后，FAB 含两个按钮：
- **移入**（主题色）：勾选 ≥1 条时可用 → 弹出选择收藏夹半模态（选择器复用自定义分类页的"移入选择器"组件）→ 确认后逐条打标签
- **删除**（警示红）：勾选 ≥1 条时可用 → AlertDialog 二次确认 → 调用 `removeThreadCollection` 取消云端收藏 → 同时清理所有自定义分类中的关联（级联，§6）

### 4.4 备份与导入入口【新增】
- 自定义分类列表页：左上角"备份"按钮 → 点击弹出 ActionSheet（**导出备份 / 导入备份**）
- 导出：`saveButton`（安全控件）+ `fileIo` 写入沙箱 → 用户选择保存位置
- 导入：`DocumentViewPicker` 选择 JSON → 增量合并（规则见 PRD §5.2）→ Toast `成功导入 X 个新分类，合并 Y 个同名分类`

### 4.5 搜索按钮形态【澄清】
顶栏非编辑态右侧展示**一个搜索图标**（而非多个）。进入搜索页后，搜索范围覆盖"云端收藏帖子 + 本地自定义收纳夹"，结果**分两区展示**：上方"收纳夹"区、下方"帖子"区。按收纳夹搜索 = 匹配收纳夹名称。

> 若产品坚持多按钮（按帖子/按收纳夹分开），需另行确认交互稿，本期按单入口实现。

### 4.6 状态联动与 EventHub【修订 · 二轮评审定案】

**单一事实来源（定案）**：`tieba_personal_collected_{accountId}`（`common/Constants.ets` 中 `CACHE_KEY.PERSONAL_COLLECTED` 运行时拼接，注意完整键名不是字面量 `PERSONAL_COLLECTED_{accountId}`）仍是收藏状态**最终状态源**；`EventHub` 仅作**变更通知**，不携带完整数据（携带 `{ tid }` 或 `'all'`），各模块收到事件后自行重读缓存/聚合。原因：该缓存是历史遗留链路（`ThreadDetail` 收藏按钮 `persistPersonalState`、`PersonalContent` Collections 模式）共同依赖的事实源，直接切换主从会破坏降级一致性。

**接入方案（新增 · 项目现状为 EventHub 零使用，需按此落地）**：
1. 实例：使用 `getUIContext().getEventHub()`（页面级）；不引入 `@ohos.events.emitter`，避免全局进程级广播与页面生命周期强耦合
2. 广播方：收藏/取消收藏/删除/移入/移出/置顶任一变更在**本地缓存更新完成后** `emit('favorite_changed', { tid })`；批量操作（编辑态批量删除、备份导入合并）结束后 `emit('favorite_changed', { tid: 'all' })`
3. 订阅方：吧分类列表页、自定义分类页、`ThreadDetail` 于 `aboutToAppear` 订阅、**`aboutToDisappear` 必须 `off` 取消订阅**（防跨页泄漏）；订阅回调内仅重读本地状态 + 局部刷新 UI，**不触发网络请求**
4. 落地顺序：先改造 `ThreadDetail.ets` 第 595-615 行的 `persistPersonalState`，在云端同步后补发广播；新模块各变更点同步接入
5. 旧缓存维护：所有变更处沿用现有写缓存逻辑（删除帖子时移除缓存项），新模块删除/移出时同样更新 `tieba_personal_collected_{accountId}`，保证降级场景一致

---

## 5. 技术实现注意事项【新增】

| 事项 | 要求 | 风险与对策 |
|---|---|---|
| 一镜到底 `geometryTransition` | `pushUrl` 第二参 `false` 禁用默认转场；共享元素绑定 `geometryTransition('folder_${id}')`；源页加 `TransitionEffect.opacity(0.99)` | List 复用/滚动重建会丢动画 ID：跳转前确保目标项在视口内；动画失败 catch 后降级系统转场（PRD §10 已要求） |
| 拖拽排序（自定义分类） | `List.onItemDragStart/onItemDrop` 实现 | **"长按 300ms + 移动 10px 才触发拖拽"无内置参数**，需自实现手势判定；拖起卡片 scale 1.05 + 阴影，放置震动 `HapticEffect.LIGHT` |
| 封面更换 + 裁切 | `PhotoViewPicker` 选图 | **鸿蒙无系统级通用裁切组件**：一期实现"等比缩放封面"（`ImageFit.Cover`），自研裁切 UI 放入 P2，需产品确认可降级 |
| 分享 | `systemShare.ShareData` + 链接 `https://tieba.baidu.com/p/{tid}` | 跨设备流转需分布式能力与额外配置，**本期仅做链接分享**，流转降级为 P2 |
| 备份导入 | `saveButton` + `fileIo` / `DocumentViewPicker` | schema 见 §2.5；导入须做 JSON 校验与容错 |
| 骨架屏 | 自绘 shimmer（无原生组件） | 仅首屏/切换 Tab 未就绪时展示 |
| 弹窗材质 | `systemMaterial`：长按菜单 THICK / 半模态 ULTRA_THICK / 输入框 THIN，`ADAPTIVE` 模式 | 需真机验证（模拟器可能不生效）；应用材质后收敛自定义背景/阴影 |
| 列表性能 | 全程 `List` + 懒加载，禁止 `Scroll+Column`；图片 `ImageFit.Cover` + placeholder + alt | 收藏列表卡片用 `ListItem` + key（tid），复用现有 `ThreadList` 卡片样式 |

---

## 6. 核心业务规则确认【澄清 · 二轮评审修订】

- **级联删除**：吧分类批量删除（取消云端收藏）→ 删除所有自定义分类中该 tid 的关联（防幽灵帖子）；自定义分类删除帖子 → 仅解绑本地标签，云端收藏保留
- **置顶纯本地**：所有置顶（吧收纳夹/帖子）仅存本地，不下发云端；缓存键 `favorite_pin_folder_{accountId}` / `favorite_pin_thread_{accountId}`（Preferences）；下拉刷新后与云端数据合并时，置顶项按置顶时间插到最前
- **置顶清理口径（修订）**：判定"已不在云端"**必须基于"历史累计已拉取集合 ∪ 本次刷新结果"**，禁止仅用刷新返回的第一页（20 条）比对——置顶帖收藏较早、位于云端第 30+ 条时，仅比对第一页会误删置顶项。实现：内存维护 `knownTids: Set<string>`（每次分页结果取并集），刷新后置顶项不在 `knownTids` 才清理；清理时同步移除置顶缓存与自定义分类关联
- **聚合为增量式**：吧分类收纳夹 = 已拉取到的云端收藏分页按 forumName 增量聚合（滚动触底继续拉下一页并合并），**严禁一次性全量拉取**；吧内帖子列表 = 聚合内存中该吧的帖子，本地过滤分页（不做服务端分页）
- **收纳夹计数口径（新增）**：`threadCount` 表示"当前已加载的该吧收藏数"，加载更多后递增属预期；UI 数字后不加"全部"等限定词。下拉刷新到底（无更多）后即等于全量
- **备份导入兼容（新增）**：导入时 `version` ≠ 1 → 整体拒绝并 Toast `备份文件版本不支持`；`folders[].threads[]` 缺 `tid`/`pid` 或类型非法 → 跳过该条并计数，最终 Toast 汇总 `成功导入 X 个新分类，合并 Y 个同名分类，跳过 Z 条无效记录`
- **移入幂等**：目标分类已含该帖子 → 拦截 + Toast `该帖子已在此收藏夹中`
- **编辑态互斥**：编辑态屏蔽所有长按弹窗；点击勾选与长按拖拽用 300ms/10px 阈值区分

---

## 7. 分期交付计划【新增】

| 阶段 | 内容 | 验收口径 |
|---|---|---|
| **P0 核心闭环** | 5-Tab 导航改造 + 旧入口处理；吧分类聚合/列表/吧内帖子列表；时间倒序+正反切换；编辑态删除（云端同步+级联清理）；自定义分类 CRUD + RelationalStore；移入/移出+去重；置顶（本地）；Toast/AlertDialog；EventHub 联动；分页+下拉刷新+空态/错误态+骨架屏 | 收藏-查看-分类-删除-移入-取消收藏全链路可用，云端与本地一致 |

### 7.1 开发进度（2026-08-29 起）

| 批次 | 状态 | 内容 |
|---|---|---|
| **第一批（已交付 · 模拟器验证通过）** | ✅ | 5-Tab 导航（`Index.ets` TabIndex=Favorite）；旧「我的收藏」入口改跳新 Tab；`Favorite.ets` 收藏主页面：吧分类收纳夹聚合（forumName 分组 + 吧名码点序 + 置顶恒顶 + 真实头像/首字占位兜底）；吧内帖子列表（本地过滤 + 排序降级倒序/正序反转 + 置顶恒顶）；`FavoriteStore.ets` 置顶持久化（Preferences，按 accountId 隔离）；下拉刷新 + 触底分页 + 空/错/加载态；自定义分类页空态框架 |
| 第二批（已交付） | ✅ | 编辑态删除闭环：长按/「编辑」入口 → 多选 → AlertDialog 确认 → 云端 rmstore 逐帖删除（按吧解析 fid）+ 本地级联清理（列表/置顶/缓存/聚合）+ 失败项兜底；编辑态自动隐藏底部 TabBar（AppStorage 联动）。模拟器实测：5→3→2→1 逐次删除与重进拉取结果一致（云端同步验证通过） |
| 第三批（已交付） | ✅ | 自定义分类 CRUD + 移入/移出 + 去重；**移入面板按 §4.2 落地为一帖多分类多选勾选**（替换式幂等写入，取消勾选即移出，未分类与自定义分类互斥）；`FavoriteStore` 新增 `setThreadCategories`；未分类计数与列表改为"无映射推导"（一帖多分类下不虚增/不重复）；分类内帖子列表按 §8.2 展示吧标签行（吧头像 + 吧名 + 同属分类 `+N`）；Preferences 持久化（RelationalStore 暂缓，记录于 §7.2） |
| 第四批（已交付） | ✅ | **骨架屏首屏 shimmer**：新增 `components/Skeleton.ets`（帖子卡/列表行骨架 + 扫光动画），首页（推荐/关注）、吧内列表、收藏页首屏 Loading 接入；**Toast 统一样式**：新增 `common/ToastUtil.ets`（信息/成功/失败分级：✓/✕ 前缀 + 时长 2.2s/3s + 底部偏移 120），收藏页全部 Toast 接入；**搜索入口（P1）**：收藏页放大镜接入真实 `Search.ets`（原为"全局搜索开发中"占位），搜索页增强——输入防抖 300ms 自动搜索、会话状态保持（AppStorage，离开重进不丢关键词/结果）、搜索历史（本地缓存最近 10 条 + 清空）、结果分区（"相关贴吧 · N"标题） |
| 第五批（已交付 · ANR 修复） | ✅ | 收藏页 `THREAD_BLOCK_6S` ANR 修复（吧头像请求风暴）：`Favorite.ets` 头像加载改为受限并发队列（≤2 在途）+ 在途去重 + 失败标记（会话内不重试）+ 持久化缓存（`fav_avatar_map`，重启恢复不重打接口）；`Index.ets` 移除启动自检调试钩子（`runCollectSelfCheck`）。模拟器实测：进入收藏 Tab / 滚动 / 重启二次进入均无 ANR，详情见 §2.4.1 |
| **第六批（已交付 · P1 体验增强）** | ✅ | ① **弹窗材质分级**（§10 A5）：移入半模态 `bindSheet` 背景改 `Color.Transparent` 透出系统材质，不再用自定义 `Theme.bgElevated` 盖住；长按菜单为系统 AlertDialog 自带材质。② **Haptic 反馈**：新增 `common/Haptic.ets`（`@kit.SensorServiceKit` vibrator + `ohos.permission.VIBRATE` 权限），置顶/勾选/移入/保存接 `light()`、删除确认接 `strong()`，无权限/能力静默降级。③ **无障碍**：收藏页关键控件（收纳夹卡/帖子卡/分类卡/新建卡/编辑操作栏三键/移入面板行与完成/分段切换）补 `accessibilityText` + `accessibilityDescription`。④ **编辑态 FAB 动画**：操作栏根节点加 `TransitionEffect.OPACITY + move(BOTTOM)`（220ms EaseOut）显隐过渡。⑤ **乐观更新+回滚**：批量删除改为"先本地移除刷新 UI → 再云端同步 → 失败自动回滚"（`rollbackDelete` 恢复列表/置顶/映射/缓存/聚合），新增 Haptic.strong + 分级 Toast。⑥ **搜索空态插画**（§9-1 闭环）：`Search.ets` 空态改 `SymbolGlyph` 放大镜 + 文案（`SearchEmpty` Builder），不依赖外部素材 |

| **第七批（已交付 · P2-a 分享 + 备份导入）** | ✅ | **分享（链接）统一工具**：新增 `common/ShareUtil.ets`（自 `Index.shareThread`/`ThreadList.ets` 提炼：systemShare + HYPERLINK + 剪贴板兜底 + Toast 反馈 + 全局异常兜底），收藏页帖子卡元信息行接入显式"分享"标签（`https://tieba.baidu.com/p/{tid}`）；**备份导出**：自定义分类 Tab 顶栏"备份"按钮 → ActionSheet（导出/导入）→ 导出对话框（`SaveButton` 安全控件授权）→ `DocumentViewPicker.save` 系统保存面板写入 JSON（schema §2.5），面板不可用降级写沙箱 filesDir 并 Toast 提示路径；**备份导入**：`DocumentViewPicker.select` 选 JSON → `fileIo` 读取 → 校验（app/version/folders，失败整体拒绝 `备份文件版本不支持`）→ `FavoriteStore.importBackup` 增量合并（新分类新增 / 同名合并幂等去重 / 无效记录跳过计数）→ Toast 汇总（§6 口径 `成功导入 X 个新分类，合并 Y 个同名分类，跳过 Z 条无效记录`）+ Haptic.light | 新增 `ShareUtil.ets`；`FavoriteStore` 增 `buildBackupFolders` / `importBackup`；`Favorite.ets` 顶栏/ActionSheet/导出对话框/导入流程接入 | 分享入口因不破坏"长按=编辑"既有交互，改用显式"分享"标签（见 §7.3 口径）；导出降级路径保证无 picker 环境也有文件产出 |**第三批实测（2026-08-29）**：新建分类 → 重启恢复 ✅；重命名持久化 ✅；移入/移出 ✅；一帖多分类（同时入 2 个分类，吧标签行 `+1 个收藏夹`）✅；重复移入幂等（无重复映射）✅；删除分类级联清理映射（帖子移回未分类）✅；未分类计数 856→855 正确；全程无 appfreeze。**第三批遗留**：模拟器无软键盘，重命名/新建的输入验证依赖 `uinput` 注入，真机软键盘输入场景建议复验一次。**第四批实测（2026-08-29）**：收藏页冷启动首屏 Loading 为骨架屏（内容区无旧 `LoadingView` 文本）✅；搜索页经收藏页放大镜进入 ✅，输入 `bangdream` 后 300ms 防抖自动搜索 ✅，空态文案带关键词 ✅，统一 Toast 生效（`✕ 搜索失败，请稍后重试`，底部偏移样式）✅，返回重进状态保持（关键词与结果恢复）✅；构建通过无 lint。**第四批遗留/说明**：① `searchForums` 接口在模拟器返回空/异常（既有外部因素，非本次改动引入），搜索页结果分区标题与搜索历史交互需真机/接口可用时复验；② 骨架屏扫光动画为定时器驱动，页面上不承载骨架时实例不创建、不耗资源；③ Toast 统一工具已就绪，当前接入收藏页全量 + 搜索页，其余页面逐步接入（见 P1 后续）。**第六批实测（2026-08-29 · P1 五件套回归）**：assembleHap 构建通过（无 lint）；部署模拟器回归——收藏 Tab 收纳夹列表正常（7 吧）✅；进入 bangdream 吧内列表 ✅；编辑态操作栏（全选/移入/删除）随 FAB 动画过渡出现 ✅；勾选（已选 1 项，轻震动接入无异常）✅；删除确认 AlertDialog ✅；确认删除触发乐观更新：本地即时移除 + 退出编辑态 + 云端同步成功持久化（bangdream 计数 26→25，重进一致）✅，回滚分支代码齐备（`rollbackDelete` 恢复列表/置顶/映射/缓存/聚合）；移入半模态（材质透明化后）正常弹出/完成/退出 ✅；搜索页空态插画（输入 `zzznotexist` → "未找到与「zzznotexist」相关的贴吧" + SymbolGlyph 放大镜）✅；全程无 ANR/appfreeze。**第七批实测（2026-08-29 · P2-a 分享 + 备份导入）**：assembleHap 构建通过（无 lint）；部署模拟器回归——自定义分类 Tab 顶栏"备份"按钮渲染 ✅；点击弹 ActionSheet（导出备份/导入备份 + 说明文案）✅；点"导出备份"弹授权对话框（标题/分类计数文案/SaveButton 安全控件/取消按钮）✅；点 SaveButton 授权回调触发、对话框正常关闭无白屏 ✅；收藏帖卡元信息行"分享"标签渲染（bangdream 吧内列表全卡可见）✅；全程无 appfreeze。**第七批遗留/说明**：① 系统保存/选择面板（`DocumentViewPicker.save`/`select`）与系统分享面板在模拟器上不展示（模拟器缺文件管理服务 UI，`save()` 走"用户取消/异常"路径），降级写沙箱逻辑已就位（无 picker 环境也有文件产出）；② 导入/导出全链路（含真实面板选文件、合并计数、重启恢复）需真机复验；③ `getUIAbilityContext()` 在 `@Builder` 上下文不可用，统一改用 `getUIContext().getHostContext()`。**第八批实测（2026-08-29 · P2-b 拖拽排序 + 封面更换）**：assembleHap 构建通过（无 lint）；部署模拟器回归——自定义分类列表渲染正常（新建分类/未分类/123 卡 + 顶部 备份/搜索）✅；自定义分类卡右侧 ≡ 管理图标渲染（`sys.symbol.line_3_horizontal`）✅；点击 ≡ 弹出 ActionSheet（标题 `123` + `选择操作` + 重命名/更换封面/删除分类 三项）✅；点 ActionSheet 外部空白关闭、列表无残留 ✅；未分类卡（非 editable）仍为 chevron 图标 ✅；未分类卡点击进入分类内帖子列表 ✅；全程无 appfreeze。**第八批遗留/说明**：① 拖拽排序改用系统 `List.editMode(true)` + `onItemDragStart/onItemDrop`（原排期"长按 300ms + 移动 10px 自实现手势"改为系统拖拽，规避与"长按=管理"手势冲突，兼容性与稳定性更优）；系统拖拽在模拟器上无法用 uinput 精确模拟（需长按后拖动的复合时序），拖起/落点/持久化链路需真机复验；② editMode 下卡片自身 `LongPressGesture` 被系统拖拽识别接管，故长按管理入口改为卡片右侧 ≡ 图标点按（不破坏拖拽）；③ 封面更换（PhotoViewPicker 选图 → 拷贝沙箱 → 持久化）代码齐备，模拟器无图库图片无法实测选图流程，需真机复验；④ `loadCategories` 对旧数据缺 `cover` 字段做了容错（补空串）。**第九批实测（2026-08-29 · P2-c 一镜到底同页适配）**：assembleHap 构建通过（无 lint）；部署模拟器回归——进入收藏 Tab 吧分类列表正常；点击 bangdream 吧分类卡进入吧内帖子列表（视图切换过渡生效，渲染正常无崩溃）✅；TopBar 返回按钮回列表正常 ✅；切自定义分类 Tab → 点击 123 分类卡进入分类内帖子列表 ✅；全程无 appfreeze。**第九批说明**：① 内容过渡动画为 260ms 瞬态，模拟器静态截图无法捕捉中间帧，功能/稳定性已回归，动画流畅度建议真机感受；② `geometryTransition` 官方限制（滚动容器内不支持）已在 §7.3 口径记录。**第十批核查（2026-08-29 · 收尾）**：③ Toast 统一接入核查——`Favorite.ets` 31 处 Toast 全量走 `this.toast()`（`ToastUtil.show` 封装，含 Success/Error/Info 类型），无 `getPromptAction().showToast` 残留；`ShareUtil.ets` 经 `ToastUtil` 封装 ✅ 闭环。① ② 真机复验项（软键盘重命名/新建输入、`searchForums` 接口与搜索历史交互）记录遗留，待真机环境执行。
| **第十一批（方案定稿 · 实施暂停）** | 🔶 | **排序功能重构**（排序按钮 → 按钮下方展开竖排 5 项菜单：名称正序 / 名称倒序 / 时间正序（添加时间）/ 时间倒序（添加时间）【默认】/ 自定义排序（仅自定义分类）；两边收纳夹界面 + 帖子列表页均接入）：方案已定稿，见 `docs/sort-rework-delivery.md`（含 4 项澄清决策、数据现实与排序键定案、实施批次 A~E、持久化变更）；批 A 抓包探测（判定「添加时间」数据策略）为实施前置；**2026-08-29 用户要求先反馈 BUG，实施暂停**，待 BUG 清单与本文档 / 交付说明同步后统一处理 |

### 7.2 RelationalStore 暂缓记录【新增 · 落地口径】

**结论**：自定义分类数据（分类表 + 帖↔分类映射表）**未引入 RelationalStore**，采用 **Preferences 双键持久化**（`favorite_custom_folder_{accountId}` / `favorite_custom_mapping_{accountId}`），原因与定案：

1. **数据量级**：PRD 预留的自定义分类为个人文件夹场景，分类数预期个位数~两位数、映射数 ≤ 收藏总数（千级），Preferences（内存全量 + 落盘）完全覆盖，无需 SQL 查询能力（无跨表 join、无聚合条件查询）
2. **一致性简单**：映射为整表替换式写入（`setThreadCategories` 每次写全量），Preferences 单键原子写天然满足，避免 RelationalStore 事务管理复杂度
3. **模型落地方案**：PRD §2.3 的 `CustomFolder.threadList` 表结构拆分为两张扁平 JSON（`FavCategory[]` + `CategoryMapping[]`），映射以"帖↔分类"为粒度，天然支持 §4.2 一帖多分类；"未分类"不落映射记录，由 UI 侧"无映射推导"（`Favorite.ets categoryCountOf` / `categoryThreads`）
4. **迁移预案**：若未来引入全局搜索（第四批 P1）或需要按字段查询/排序，再按 §7 P0 原计划迁移 RelationalStore，`FavoriteStore` 接口层不变（对 `Favorite.ets` 透明）

| **P1 体验增强** | 全局搜索（防抖 300ms、状态保持、空态插画、结果分区）；编辑态 FAB 动画；乐观更新+回滚；Haptic 反馈；弹窗材质分级；无障碍（accessibilityDescription） | 搜索、动效、无障碍达标 |
| **P2 锦上添花** | 一镜到底；分享（链接）；备份导入（增量合并）；拖拽排序；封面更换；流转 | 见 §7.3 排期 |

### 7.3 后续排期（P2 及收尾 · 2026-08-29 定案）

> 排期原则：**复用优先**——分享基建（`Index.ets shareThread()` / `ThreadList.ets` 同款 systemShare + HYPERLINK + 剪贴板兜底）已上线，直接抽取复用，不重写；其余新能力按依赖与价值排序。每批交付后跑 `assembleHap` + 模拟器回归（无 ANR/appfreeze）再进下一批。

| 批次 | 内容 | 复用/新增点 | 预估 | 验收口径 |
|---|---|---|---|---|
| **第七批 · P2-a 分享 + 备份导入** | ① **分享（链接）**：`common/ShareUtil.ets`（自 `Index.shareThread` 提炼：systemShare + HYPERLINK + 剪贴板兜底 + 全局异常兜底），收藏页帖子卡元信息行接入"分享"标签 ② **备份导入（增量合并）**：自定义分类 Tab 顶栏"备份"按钮 → ActionSheet（导出/导入）；导出 = `SaveButton` 安全控件授权 + `DocumentViewPicker.save` 系统保存面板写 JSON（schema §2.5），面板异常降级写沙箱 `filesDir` + Toast 提示路径；导入 = `DocumentViewPicker.select` 选 JSON → 校验（app/version/folders 整体拒绝）→ 增量合并（新分类新增 / 同名合并幂等去重 / 无效记录跳过计数）→ Toast 汇总（§6 口径） | 复用 systemShare 链路（`@kit.ShareKit` + `@kit.ArkData` utd）；新增 `ShareUtil.ets`；备份导入全新增（`SaveButton` + `fileIo` + `picker.DocumentViewPicker`） | 约 2 人日 · ✅ 已交付 | 分享弹出系统面板/剪贴板兜底；导出 JSON 可读且 schema 合法；导入"X 新 + Y 合并 + Z 跳过"计数正确；导入后重启数据一致 |

> **第七批实现口径（与排期原文的差异说明）**：
> - **分享入口**：原计划"帖子卡长按菜单接入分享"，落地改为**元信息行显式"分享"标签**——因"长按=进入编辑"是既有交互（第二批定案），长按弹分享菜单会破坏批量操作路径。显式标签不冲突、零回归，且可点面积更大（accessibilityText `分享帖子`）。
> - **备份按钮位置**：原计划"自定义分类列表页左上角"，落地为**自定义分类 Tab 下顶栏标题右侧**（与"编辑"按钮同款胶囊样式，位于搜索按钮左侧）——左侧为页面标题无空闲位，右侧与顶部操作聚合更符合单手操作。
> - **导出**：系统保存面板走 `DocumentViewPicker.save()`（API 10+，免权限，支持任意文件类型）；`showAssetsCreationDialog` 实测仅支持媒体文件，不适用 JSON。save() 异常时**降级写沙箱 `filesDir`** 并 Toast 提示文件名（保证任何环境有文件产出）。
> - **导入校验容错**：§6 原文"缺 pid 跳过"，落地为**tid 非空 string 必须；pid 缺失/空串放行（记 ''），pid 存在但非 string 跳过**——导出侧无 pid 数据（threadstore 无该字段）时写 `''`，避免导出即弃。
| **第八批 · P2-b 拖拽排序 + 封面更换** | ① **拖拽排序（自定义分类列表）**：`List.editMode(true)` + `onItemDragStart/onItemDrop`（系统拖拽，替代原"自实现 PanGesture"）；拖起卡片 scale 1.05 + 阴影；放置 `Haptic.light()`；`FavoriteStore.reorderCategories` 顺序持久化（Preferences）② **封面更换**：`PhotoViewPicker` 选图 → 拷贝沙箱 → `cover` 存本地路径 + `ImageFit.Cover` 等比缩放；空/无权限降级 icon/首字封面兜底（§2.3 约定） | 全新增（含拖拽、排序持久化、图片选器）；Haptic/Toast/材质复用现有工具 | 约 2 人日 · ✅ 已交付 | 拖拽松手后顺序即时生效且重启保持；拖起有 scale+阴影、放置有轻震动；封面更换后卡片/列表即时刷新且重启恢复；无封面仍走 icon/首字兜底 |
| **第九批 · P2-c 一镜到底（同页适配）+ 流转（砍/降级）** | ① **一镜到底**：收藏 Tab 视图切换（吧分类 ↔ 吧内列表 / 自定义分类 ↔ 分类内列表）加 `TransitionEffect` 内容过渡（OPACITY + translate 24 + 260ms EaseOut）；`viewSwitchTransition()` 统一过渡配置 | 排期原文 geometryTransition（List 内官方不支持，见 §7.3 口径）；流转默认不做 | 约 1 人日（流转 0）· ✅ 已交付 | 视图切换无崩溃、有连续过渡；无 ANR |
| **第十批 · 真机联调 + 收尾** | ① 真机复验第三批遗留：重命名/新建输入（软键盘场景）② 真机复验第四批遗留：`searchForums` 接口（结果分区标题 + 搜索历史交互）③ 第四批遗留③：收藏页其余页面 Toast 统一工具接入（核查闭环）④ 全量回归 + 文档回填（排期结果更新 §7.1） | 复验/接入为主；Toast 核查无改动 | 约 1 人日 · 🔶 部分交付（代码项完成，① ② 真机项待真机） | ③ 已闭环：收藏模块无 `showToast` 残留（全量走 `this.toast()`/`ToastUtil`）；④ 全量回归通过（第九批构建 + 部署视图切换回归）；① ② 记录遗留待真机 |

> **第八批实现口径（与排期原文的差异说明）**：
> - **拖拽手势**：原计划"长按 300ms + 移动 10px 阈值自实现手势判定"，落地改为**系统 `List.editMode(true)` + `onItemDragStart/onItemDrop`**——自实现 PanGesture 与 List 竖向滚动、既有"长按=管理"手势均冲突；系统拖拽为 API 12+ 官方能力，拖起/落点/动画稳定。
> - **管理入口**：editMode 下长按被系统拖拽识别接管，卡片自身 `LongPressGesture`（350ms 弹管理菜单）失效 → 管理入口改为**卡片右侧 ≡ 图标点按**弹 ActionSheet（重命名/更换封面/删除分类，有封面时多"移除封面"），未分类卡保持 chevron。
> - **封面展示**：列表卡片封面位 48px 圆形 `ImageFit.Cover` 裁剪；无 cover 时 `Text(icon)`（icon 空再取 `name.charAt(0)` 首字）兜底，符合 §2.3 约定。
> - **旧数据兼容**：`FavCategory` 新增必填 `cover`，`loadCategories` 对旧 JSON 缺失字段补空串。
| **第九批 · P2-c 一镜到底（同页适配）+ 流转（砍/降级）** | ① **一镜到底**：收藏 Tab 视图切换（吧分类 ↔ 吧内列表 / 自定义分类 ↔ 分类内列表）`TransitionEffect` 内容过渡（OPACITY + translate 24 + 260ms EaseOut，`viewSwitchTransition()` 统一配置）② **流转**：跨设备流转需分布式能力与额外配置，本期链接分享已覆盖主要诉求 → **降级为可选，默认不做** | 排期原文 `geometryTransition` + `pushUrl` 禁转场不适用（收藏 Tab 为组件内状态切换非路由；geometryTransition 官方不支持 List/Grid/Scroll 内使用）→ 改为内容过渡 | 约 1 人日（流转 0）· ✅ 已交付 | 视图切换有连续过渡且无崩溃；无 ANR |

> **第九批实现口径（与排期原文的差异说明）**：
> - **转场机制**：原计划"`pushUrl` 第二参 `false` 禁默认转场 + 共享元素 `geometryTransition('folder_${id}')`"。实际**收藏 Tab → 吧内列表/分类内列表为组件内状态切换**（`selectedForum`/`selectedCategoryId`，非路由跳转，无 pushUrl 转场可禁）；且 **`geometryTransition` 官方明确不支持在 List/Grid/Scroll 等滚动容器内使用**（源卡片在 List 中）→ 落地为**视图切换内容过渡**（`TransitionEffect.OPACITY + translate({ y: 24 })`，260ms EaseOut），实现"列表 → 帖子列表"的连续过渡体验。
> - **流转**：与排期一致砍/降级，默认不做（链接分享已覆盖主要诉求）。
| **第十批 · 真机联调 + 收尾** | ① 真机复验第三批遗留：重命名/新建输入（软键盘场景）② 真机复验第四批遗留：`searchForums` 接口（结果分区标题 + 搜索历史交互）③ 第四批遗留③：收藏页其余页面 Toast 统一工具接入（当前仅收藏页全量 + 搜索页）④ 全量回归 + 文档回填（排期结果更新 §7.1） | 复验/接入为主 | 约 1 人日 · 🔶 部分交付（代码项完成，① ② 真机项待真机） | ③ 已闭环：收藏模块无 `showToast` 残留（全量走 `this.toast()`/`ToastUtil`）；④ 全量回归通过（第九批构建 + 部署视图切换回归）；① ② 记录遗留待真机 |

**外部依赖（产品/需求侧，不阻塞 craft 排期，状态同步）**：
- **PRD 入库（§9-3）**：待产品将 PRD 定稿放入 `docs/`——各批次按本文档落地不受阻塞，仅影响逐条核对
- **中文排序确认（§9-2）**：默认接受 Unicode 码点序；若产品要求拼音序，需评估引入排序库（排入 P2 收尾）
- **空态插画（§9-1）**：已闭环（第六批 SymbolGlyph 自绘），品牌化素材可后续替换

**里程碑建议**：第七批结束 = P2 主链路可用（分享+备份完成数据可迁移性闭环）；第八批结束 = 收藏模块交互能力全量齐备；第九/十批按资源弹性安排。

---

## 8. PRD §18 截断内容补充：收藏帖卡片信息层级定义【新增 · 补全 PRD】

> 原 PRD §18"信息层级（自上而下）："之后内容缺失，本补充基于 PRD §4.1（现代媒体卡片排版）、§17（收纳夹视觉规范）与现有 `ThreadCard` 结构（`components/CommonComponents.ets`）推导补齐，作为 craft 落地唯一依据；若产品提供交互稿，以交互稿为准。

### 8.1 帖子卡片信息层级（自上而下）

1. **置顶角标（可选）**：仅本地置顶帖展示，卡片右上角"置顶"小标签；置顶帖不参与正/倒序排序，恒在列表顶部，置顶内部按置顶时间倒序
2. **标题行**：主标题 ≤2 行省略，`fs(17)`/Bold/`sys.color.font_primary`；标题为空降级显示"楼主暂无标题"（`font_secondary`）
3. **摘要行**：首楼正文 ≤3 行省略，`fs(14)`/`font_secondary`；无摘要不渲染该行
4. **媒体区（可选）**：单图/三图/九宫格（≤9 图，复用 `ThreadCard.ImageGallery` 与 `ImageFit.Cover` + placeholder）；无图不占位
5. **元信息行**：作者（20vp 圆形头像，无图首字占位）· 回复数 · 收藏时间（相对时间"x天前"；降级口径见 §8.3，threadstore 无 `collect_time` 时不渲染该字段）
6. **吧标签行（仅自定义分类列表展示）**：吧头像（20vp 圆形）+ 吧名；帖子同属多个自定义分类时展示 "+N" 计数
7. **编辑态覆盖层**：左侧勾选圆环 + 点击卡片切换勾选；编辑态下屏蔽长按弹窗（见 §4.3）

### 8.2 两类列表的差异

| 场景 | 吧分类-吧内帖子列表 | 自定义分类-帖子列表 |
|---|---|---|
| 吧标签行 | 不展示（吧名已由分组表达） | 展示 |
| 元信息行 | 作者 · 回复数 · 收藏时间 | 作者 · 回复数 · 收藏时间 |
| 空标题降级 | "楼主暂无标题" | 同左 |

### 8.3 排序口径（与 §3 对齐）

- **收藏时间不可得**（threadstore 无 `collect_time`，§11 已实测确认），默认顺序以接口为准：**`last_time`（最后回复/更新时间）倒序**，正/倒序切换作用于该维度
- 置顶项恒在顶部，置顶内部按置顶时间倒序
- 下拉刷新后重新执行排序，置顶项清理口径见 §6（累计已拉取集合判定，非仅比对刷新首页）
- **收藏时间显示降级（已定案 · 2026-08-29 模拟器抓包确认 threadstore 无 `collect_time`）**：
  - 元信息行**不展示**"收藏时间"字段，仅展示 作者 · 回复数（不伪造数据）
  - 排序降级为"接口默认顺序倒序"（正/倒序切换仅本地反转，跨页重排风险见 §3）
  - Service 层暴露常量 `hasCollectTime = false`（已定死），UI 依据它决定是否渲染时间字段，禁止 UI 层自行猜测
  - 可选增强：卡片元信息展示 `last_time`（最后回复时间，字段存在且语义确认），需产品确认后启用

---

## 9. 待产品/需求方补齐（阻塞 P0 之外的事项）

1. **空态插画资源（已闭环 · 2026-08-29）**：搜索空态已由 craft 用 `SymbolGlyph` 自绘放大镜插画（`Search.ets` `SearchEmpty`，第六批），不再依赖外部素材；如需品牌化定制插画可后续替换
2. **中文排序规则确认**：吧名排序接受 Unicode 码点序，或要求拼音序（需引入排序库）
3. **PRD 入库（新增）**：配套 PRD 全文未在仓库（docs/ 仅本文档），落地时无法核对 §4.1/§5.2/§6/§9/§10/§14/§17/§18 等引用。请产品将 PRD 定稿放入 docs/，或授权以本文档为唯一依据
4. **RDB 技术验证（新增 · P0 前置）**：项目当前零 RelationalStore 使用（全链路 Preferences + CacheManager）。开工前需真机验证建库/读写/多账号隔离；若验证不过，降级方案 = 自定义分类及关联序列化为 JSON 存 Preferences（单键 `favorite_custom_folder_{accountId}`），模型与接口不变，仅换存储实现

---

## 10. 增补 A：收藏模块沉浸式 UI 规范（与现有界面统一）

> 替换 PRD §3 的通用描述，作为收藏模块 UI 实现的**唯一口径**。核心原则：**收藏模块所有视觉实现必须复用现有 `ImmMaterial` / `Theme` / 悬浮顶栏模式，禁止自绘模糊、阴影、渐变来模拟材质。**

### A1. 顶栏（收藏主 Tab 页）— 参照 `Index.ets` 的 `TopBar`

收藏作为底部主 Tab，顶栏形态**与首页/进吧/消息/我的完全一致**，不采用二级页面的返回式顶栏：

- 透明悬浮 `Row`，不设背景色、不加渐变层：`padding({ left: Spacing.lg, right: Spacing.lg, top: 44, bottom: 10 })`（top 44 = 状态栏避让，与现有页面一致）
- 左侧：标题 `Text('收藏')`，`fs(22)` + `FontWeight.Bold` + `$r('sys.color.font_primary')`
- 右侧：44vp 圆形按钮，`backgroundColor(Color.Transparent)` + `.systemMaterial(ImmMaterial.control())` + `borderRadius(Radius.full)`，依次放：搜索、排序切换
- 顶栏右侧按钮统一 `margin({ left: 12 })`，保持与 `Index.ets` 相同的对齐节奏

现有实现样板（`pages/Index.ets` 第 803-818 行）：

```ts
      if (this.selectedTab === TabIndex.Home) {
        Button() {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontColor([$r('sys.color.icon_primary')])
            .fontSize(fs(20))
        }
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .systemMaterial(ImmMaterial.control())
        .borderRadius(Radius.full)
        .margin({ left: 4 })
        .accessibilityText('搜索')
```

### A2. 内容避让与滑动沉浸

- 内容区 `List` 首项**预留 98vp 顶栏高度**（现有惯例：`Column().width('100%').height(98)` 占位 ListItem），保证首屏内容不被顶栏遮挡
- 整页 `expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])`
- **滑动时顶栏保持透明悬浮**：圆形按钮自带 `ImmMaterial.control()` 毛玻璃，天然可读，**不需要滚动监听做文字颜色切换**——这与首页等主 Tab 一致。标题用 `$r('sys.color.font_primary')` 已随深浅色自适应
- 列表底部沿用现有 `BottomFadeOverlay` 底部渐隐（linearGradient `#00FFFFFF → #FFFFFFFF` + `blendMode(DST_IN)`），这就是现有页面的"渐变"语言，收藏页保持一致

### A3. 吧分类 / 自定义分类 — 按钮状切换（胶囊分段控件）

两个 Tab 的切换**不用顶部文字 Tab，用胶囊分段按钮**，直接复用现有切换器实现（`ThreadList.ets` 的 `SortTabsBuilder` / `ThreadDetail.ets` 的排序切换）：

- 每个按钮：`padding({ left: 14, right: 14, top: 6, bottom: 6 })` + `borderRadius(Radius.full)` + `backgroundColor(Color.Transparent)`
- 选中态：`.systemMaterial(ImmMaterial.tabActive(isDark))` + `fontColor($r('sys.color.font_primary'))`
- 未选中：`.systemMaterial(ImmMaterial.tab())` + `fontColor($r('sys.color.font_secondary'))`
- 位置：顶栏下方居中一行，下方留 `Spacing` 间距；**编辑态下分段控件与顶栏右侧图标一起隐藏**（见 §4.3 / PRD §14）

样板（`pages/ThreadList.ets` 第 617-647 行）：

```ts
      .fontColor(this.selectedSort === 0 ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
        .backgroundColor(Color.Transparent)
        .systemMaterial(this.selectedSort === 0 ? ImmMaterial.tabActive(this.isDark) : ImmMaterial.tab())
        .borderRadius(Radius.full)
        .layoutWeight(1)
```

### A4. 小白条沉浸

- 窗口级已配置：`EntryAbility.ets` 全局 `navigationBarColor: '#00000000'` + 深色 `navigationBarContentColor`，收藏页**无需重复设置**窗口属性
- 页面侧：底部内容区 `expandSafeArea(BOTTOM)`，底部悬浮操作栏 / FAB 通过 `margin({ bottom })` 避让小白条（现有参照：`ThreadDetail.ets` 输入栏 `bottom: 30`、`ThreadList.ets` FAB `bottom: 36`）
- 编辑态 FAB 悬浮于底部导航栏（TabBar）之上，与小白条保持 ≥12vp 间距（PRD §6 已要求，这里明确参照 ThreadList FAB 的 zIndex 与 margin 做法）

### A5. 华为官方沉浸光感（统一材质口径）

| 元素 | 必须使用 | 禁用 |
|---|---|---|
| 顶栏/操作按钮（44vp 圆形） | `ImmMaterial.control()` | 自绘模糊/阴影/渐变 |
| 胶囊分段切换 | `ImmMaterial.tab()` / `ImmMaterial.tabActive(isDark)` | 自定义背景色模拟 |
| 底部悬浮操作栏（编辑态） | `ImmMaterial.bar()`（容器）或 `fab()`（按钮） | — |
| 长按菜单/半模态/输入弹窗 | `systemMaterial`：THICK / ULTRA_THICK / THIN（PRD §9） | 自定义背景盖住系统材质 |
| 能力检测与降级 | `MaterialManager.init()` + `MaterialManager.isSupported()`（注意：`isMaterialSupported()` 是 `Theme.ets` 顶层导出函数，`MaterialManager` 类方法名为 `isSupported()`） | 无条件堆材质 |

> 全局已封装于 `common/Theme.ets` 的 `ImmMaterial`（control/bar/tab/tabActive/fab/cardAction 等）与 `MaterialManager`，全部方法返回 `uiMaterial.Material`，可安全复用；低端机走 ADAPTIVE 自适应（现有封装已兼容，勿自行造轮子）。

### A6. 一致性自检清单（craft 做完逐条勾）

- [x] 顶栏 = 透明悬浮 + 44vp 圆形 control 按钮，无实色背景
- [x] 列表首项 98vp 预留，首屏不被顶栏遮挡
- [x] 吧分类/自定义分类 = 胶囊分段控件（tab/tabActive）
- [x] 小白条区域内容避让 + FAB/操作栏 margin 悬浮
- [x] 底部渐隐 BottomFadeOverlay 与现有页面一致
- [x] 全部材质来自 `ImmMaterial`，无自绘模糊/阴影

---

## 11. 附录：P0 抓包记录表（开工第一件事，回填后 §2.6 阻塞解除）

> 抓包对象：`https://c.tieba.baidu.com/c/f/post/threadstore`（即 `fetchCollectedThreads` 调用的端点）。抓包结果必须回填下表，且**先回填再实现**排序与卡片收藏时间。

| 项 | 实测结果 | 记录人/日期 |
|---|---|---|
| 响应是否含 `collect_time` 字段 | **否**（字段清单确认无此字段） | 2026-08-29 · 模拟器（Eive火） |
| 响应是否含 `forum_id` / `fid` 字段 | **否**（无 `forum_id`/`fid`/`fname`，仅有 `forum_name`） | 同上 |
| 返回记录顺序是否为收藏时间倒序 | **否**（接口无收藏时间字段；实测按 `last_time` **倒序**返回：20 条全程非升，`排序判定: last_time 全程非升=true`。即默认展示 = last_time 降序 ≈"最后活跃在前"，正序 = 本地反转） | 2026-08-29 · 模拟器（Eive火，20 条样本） |
| 返回记录顺序是否稳定（两次请求对比） | **顺序稳定**（两次均按 last_time 降序；但条数有 20/1 差异，疑似接口频控或服务端缓存，不影响顺序判定） | 同上 |
| `last_time` 实际语义（最后回复 vs 收藏时间） | **最后回复/更新时间**（值=1787932152≈2026-08-28，与"楼主更新到1688楼"吻合；`create_time`=1641587663≈2022-01-07 为发帖时间） | 同上 |
| 实测响应片段（脱敏，仅字段名与值类型） | `thread_id,title,forum_name,author,media,god,is_follow,is_deleted,post_no,post_no_msg,last_time,type,status,max_pid,min_pid,count,mark_pid,mark_status,reply_num,floor_num,create_time,thread_type`（22 个字段，无 collect_time/forum_id/fid） | 同上 |

**判定规则**：
- `collect_time` = 是 → §3 按收藏时间倒序成立，卡片正常展示收藏时间
- `collect_time` = 否 → 触发 §8.3 降级（隐藏收藏时间字段 + 接口默认序倒序 + `hasCollectTime = false`）
- `forum_id` = 是 → 按 §2.6-1 解析 fid，头像缓存 key 用 fid；= 否 → 头像缓存 key 用 forumName 兜底（§2.4）

---

## 12. 问题记录（BUG 反馈 · 2026-08-29）

> 用户反馈 BUG 汇总。详情（现象/根因/修复方案/验证口径）见 `docs/sort-rework-delivery.md` §9；修复实施遵循「开工需确认」规则，待用户确认后统一处理。

| ID | 现象 | 根因 | 状态 |
|---|---|---|---|
| BUG-01 | 收纳夹进入子列表后，系统侧边返回/返回键无法回到上一级列表 | 子列表为 `FavoriteTab` 组件内状态切换（非路由栈），@Entry 页 `Index.ets` 无 `onBackPress` 拦截 | ✅ **已修复**（2026-08-29：`Index.ets onBackPress()` 拦截转发 + `@StorageLink('favCanGoBack')`/`favBackRequest` + `@Watch` 自动维护可回退标记 + `onBackRequest` 逐级回退：弹层→编辑态→分类内→吧内→根视图放行） |
| BUG-02 | 收藏页顶栏渐变未延伸到"吧分类/自定义分类"分段切换区 | 渐变削淡区（0~15% 列表高）仅覆盖 TopBar（≈0~98vp），未覆盖分段切换悬浮区（`CategoryTabs` top:100，≈100~132vp） | ✅ **已修复**（2026-08-29：`BottomFadeOverlay` 改回 ThreadList 同款全屏 `DST_IN`，顶部 20% 渐显覆盖 TopBar+分段区，20% 以下全实色不回归 BUG-09） |
| BUG-03 | 收藏搜索 100% 失败（「搜索失败，请稍后重试」） | 桌面站搜索页已改 SPA 壳（正则解析必空）+ 带登录态请求疑似触发风控 403；该接口第十批起即"待真机复验" | ✅ **已修复**（2026-08-29：改为收藏页内**本地搜索**——`searchMode` 搜索态 + `searchResults()` 匹配帖子标题/吧名/分类名，结果复用 `PostCard`，不再跳转 `pages/Search`） |
| BUG-04 | 自定义分类长按编辑弹窗排版粗糙 | 使用系统 `ActionSheet`（`manageCategory` 第 695~733 行）样式不可控：title 粗大、sheet 项无图标/无分组/无危险色，视觉不精致 | ✅ **已修复**（2026-08-29：`manageCategory` 改 `bindSheet` 半模态 `CategoryManageSheet`——封面缩略图 + 分类名 + 操作行（自绘 `StrokeIcon` 简约线条图标 + 标题 + 描述 + 危险删除红色分组 + 取消）；原 ActionSheet 逻辑删除） |
| BUG-05 | 吧分类长按置顶无确认弹窗 + 置顶后无醒目置顶标识 | `FolderCard` 长按直接 `togglePinFolder`（第 1430~1431 行）无确认；置顶徽章仅 10sp 灰色小字（第 1399~1406 行）辨识度极低 | ✅ **已修复**（2026-08-29：置顶标识升级为 `pin_fill` 图钉 + `Theme.brand()` 主色底 + 11sp 白字；长按改弹 `PinConfirmSheet` 半模态确认（图钉图标 + 明确文案 + 取消/确认），确认后才执行置顶） |
| BUG-06 | 编辑态圈选按钮水平居中，与标题/回复数无对齐锚点 | `PostCard` 第 1474~1499 行 `Row({ space: 8 })` 未设 `.width('100%')` 且无 `justifyContent`，radio 渲染到卡片水平居中 | ✅ **已修复**（2026-08-29：Row 改 `width('100%')`，子项「置顶徽章左 + Blank 撑开 + radio 右」，radio 右对齐卡片右上角、与"X 回复"右缘对齐；非编辑态零回归） |
| BUG-07 | 编辑态出现两个"全选"按钮 | `TopBar`（右上角，第 1936~1947 行）与 `EditBar`（底部悬浮栏，第 1235 行）重复 | ✅ **已修复**（2026-08-29：删除 `TopBar` 右上角"全选"，保留底部 `EditBar`；"已选 X 项"标题 `layoutWeight(1)` 撑满整行，视觉与"分类名+编辑"非编辑态一致） |
| BUG-08 | 自定义分类内帖子列表顶部预留空间过多 | `CategoryThreadsView` 占位用 `placeholderHeight()`，`selectedForum` 为空 → 返回 146vp 透明区 | ✅ **已修复**（2026-08-29：新增 `THREAD_TOP_PLACEHOLDER=98`，分类内帖子与吧内帖子统一 98vp；`placeholderHeight` 保留供吧分类/分类列表） |
| BUG-09 | 列表底部"黑色 mask 覆盖卡片"导致 UI 不协调 | `BottomFadeOverlay`（第 2118~2129 行）`.height('100%')` 渐变全屏覆盖 + `BlendMode.DST_IN` 离屏蒙版硬编码白色 → 底部 List 内容完全挖洞透明，露出页面背景（暗色 `#101114`）形成梯形黑遮罩 | ✅ **已修复**（2026-08-29：高度 80vp + 删 DST_IN 改 alpha 合成 + 感知 `isDark` 用 `Theme.bg` 色，底部内容淡出到背景色而非挖洞；EditBar zIndex 15 不受影响） |
| BUG-10 | 切走再切回收藏页，收纳夹内浏览位置丢失 | `Index.ets` 第 731~741 行 `if (selectedTab === ...)` 条件渲染，切 Tab 销毁 `FavoriteTab`，`@State`（`selectedCategoryId/selectedForum/categoryTab`）全部重置 | ✅ **已修复**（2026-08-29：模块级 `lastCategoryTab/lastSelectedForum/lastSelectedCategoryId` + `@State` 初始化引用 + 9 处赋值点同步，组件重建同步恢复无闪烁；进程重启自然重置） |
