# TiebaPura

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform](https://img.shields.io/badge/Platform-HarmonyOS%207%20%2F%20API%2026-000000.svg)](#)
[![Language](https://img.shields.io/badge/Language-ArkTS%20%2F%20ArkUI-3178C6.svg)](#)

**当前版本：`v1.0.0`** · 首个公开版本 · 2026-09-10

> **⚠️ 非官方声明**
>
> 本项目是**第三方非官方开源项目**，**与百度公司及其关联企业无任何关系**，未获得百度在授权、
> 认可、赞助或支持等任何形式上的背书。「百度」「百度贴吧」及相关标识、商标、数据、接口与
> 服务的全部权利均归百度所有。
>
> 本项目**仅供学习与 HarmonyOS 技术研究**，请勿用于商业用途或任何违反服务条款的用途。
> 使用者需自行承担接口风控、账号安全与合规风险。详见 [免责声明](#免责声明)。

HarmonyOS 7 / API 26 手机端的百度贴吧功能等价客户端原型，使用**原生 ArkTS / ArkUI** 实现，
不是 Android APK 二进制转换，也未使用任何第三方跨平台框架（`dependencies` 为空）。

## 目录

- [功能等价范围](#功能等价范围)
- [技术要点](#技术要点)
- [仓库结构](#仓库结构)
- [维护文档](#维护文档)
- [接口参考](#接口参考)
- [构建](#构建)
- [开源协议](#开源协议)
- [参考与致谢](#参考与致谢)
- [免责声明](#免责声明)
- [贡献](#贡献)

## 功能等价范围

- 应用内百度网页登录与 Cookie 登录态持久化
- 首页推荐流：下拉刷新、触底分页、缓存、去重、错误重试
- 关注动态：独立信息流入口，不与“进吧”关注贴吧列表混用
- 进吧：已关注贴吧、最近浏览、一键签到、吧主页帖子列表
- 吧主页：热门 / 最新 / 精选排序、帖子分页、本吧本地搜索
- 帖子详情：楼层、图片、正序 / 倒序、只看楼主、楼层跳转、点赞与收藏状态入口、楼中楼
- 发帖
- 收藏：吧分类 / 自定义分类 / 本地搜索 / 排序 / 编辑 / 云端收藏
- 搜索：搜吧 / 搜贴 / 搜人，底部悬浮模块切换栏
- 用户主页、关注与粉丝列表、黑名单管理
- 消息与我的页面
- 设置：屏蔽设置、一键签到、使用习惯、字号
- HarmonyOS 官方沉浸光感材质（`Navigation` 标题栏 / 底部悬浮 `Tabs` 槽位）与真模糊磨砂降级
- HarmonyOS `SymbolGlyph` 图标、悬浮玻璃底栏、沉浸式窗口和手机安全区
- 统一 `UiState` / `PageState` 模型
- 基础 Protobuf Writer/Reader 与贴吧 Proto 请求模型定义

## 技术要点

| 主题 | 说明 |
| --- | --- |
| 语言与框架 | ArkTS / ArkUI 声明式 UI，Stage 模型 |
| 目标环境 | DevEco Studio 26.0，HarmonyOS 7，API 26，手机设备 |
| 网络层 | 移动端公共参数 + 签名 + JSON 兼容解析；Protobuf wire-format 编解码 |
| 状态管理 | `AppStorage` 全局 token（登录态、字号、暗色、光感开关）+ 组件级 `UiState` / `PageState` |
| 界面架构 | `pages/Index.ets` 仅作宿主壳（Tab 切换 / 底栏 / 登录态），五个主 Tab 各自独立 `@Component` |
| 光感材质 | 仅走官方槽位（导航标题栏、底部悬浮 Tabs）；页面主体玻璃使用 `backgroundBlurStyle` 真模糊磨砂降级 |
| 缓存 | 内存 + 持久化缓存层，账号级缓存随登录态失效 |

## 仓库结构

```text
TiebaPura/
├── AppScope/                     # 应用级配置与资源
├── entry/                        # 主模块
│   └── src/main/
│       ├── ets/                  # 源码（见下）
│       ├── resources/            # 资源（图片 / 字符串 / 颜色）
│       └── module.json5          # 模块声明与权限
├── docs/                         # 专项方案与排障记录
├── tools/                        # 本地构建/调试辅助脚本（不入库、不入发布包，说明见 tools/README.md）
├── backup/                       # 历史版本备份（已被 .gitignore 排除，不入库）
└── oh-package.json5              # 工程依赖声明（当前无三方依赖）
```

```text
entry/src/main/ets/
├── cache/                        # 本地缓存层
│   ├── CacheManager.ets
│   └── ImageCache.ets
├── common/                       # 通用工具
│   ├── Constants.ets             # 常量 / API / 缓存键
│   ├── Haptic.ets                # 震动反馈（HapticFeedback）
│   ├── Pinyin.ets                # 拼音检索
│   ├── ShareUtil.ets             # 分享（链接）统一工具
│   ├── Theme.ets                 # 主题 token / 暗色适配 / 沉浸材质
│   └── ToastUtil.ets             # Toast 统一封装
├── components/
│   ├── CommonComponents.ets      # 通用 UI 组件
│   └── Skeleton.ets              # 骨架屏
├── entryability/
│   └── EntryAbility.ets
├── model/
│   ├── DataModel.ets
│   ├── ProtoModels.ets
│   ├── TiebaProtoSchema.ets      # 贴吧 Proto 消息模型
│   └── UiState.ets
├── network/
│   ├── EmojiLoader.ets
│   ├── HttpClient.ets
│   ├── ProtobufCodec.ets
│   ├── ProtoSchema.ets
│   └── TiebaProtoDecoder.ets
├── pages/
│   ├── Index.ets                 # 宿主壳（Tab 切换 / 悬浮玻璃底栏 / 登录态）
│   ├── HomeTab.ets               # 首页（推荐 / 关注动态 / 搜索入口）
│   ├── ForumsTab.ets             # 进吧（关注贴吧 / 一键签到 / 排序）
│   ├── Favorite.ets              # 收藏 Tab（吧分类 / 自定义分类 / 本地搜索 / 排序 / 编辑）
│   ├── MessagesTab.ets           # 消息 Tab
│   ├── MineTab.ets               # 我的 Tab
│   ├── ThreadList.ets            # 吧主页帖子列表（含本吧本地搜索）
│   ├── ThreadDetail.ets          # 帖子详情（正序 / 只看楼主 / 楼层跳转）
│   ├── SubPostDetail.ets         # 楼中楼详情
│   ├── ComposeThread.ets         # 发帖
│   ├── Search.ets                # 全站搜吧 / 搜贴 / 搜人
│   ├── UserProfile.ets           # 用户主页
│   ├── FollowList.ets            # 关注 / 粉丝列表
│   ├── BlacklistManager.ets      # 黑名单管理
│   ├── PersonalContent.ets       # 个人内容（云端收藏）
│   ├── PersonalizedPage.ets      # 首页推荐流
│   ├── Login.ets
│   ├── Follow.ets
│   ├── Message.ets
│   ├── Settings.ets
│   ├── ShieldSettings.ets        # 屏蔽设置
│   ├── AutoSignSettings.ets      # 一键签到设置
│   ├── UsageHabitsPage.ets       # 使用习惯
│   ├── FontSizePage.ets          # 字号设置
│   └── ImagePreview.ets          # 图片预览
└── service/
    ├── AuthManager.ets           # 登录态 / Cookie 管理
    ├── AutoSignManager.ets       # 一键签到调度
    ├── AutoSignNotifier.ets      # 签到结果通知
    ├── FavoriteStore.ets         # 收藏模块持久化（分类 / 置顶 / 映射 / 排序偏好 / 备份）
    ├── FontSizeManager.ets
    ├── ForumSignStore.ets        # 贴吧签到状态持久化
    ├── TiebaService.ets          # 业务接口聚合
    └── UsageHabitsManager.ets
```

## 维护文档

专项方案与 BUG 应对记录统一存放于 `docs/` 目录：

- `docs/floor-vanish-viewport-fix.md` — 沉浸场景下 `List` 虚拟滚动列表项整层消失问题的实证排查与修复（含可复用的快速排查清单）
- `docs/immersive-light-sense-api26-official.md` — API 26 官方沉浸光感能力的适用槽位与实证结论
- `docs/新API26沉浸光感经验汇总.md` — 沉浸光感落地经验汇总（各页面清单与判据）
- `docs/immersive-material-guide.md` — 沉浸材质总览指南
- `docs/tangs-components-immersion-analysis.md` — 三方沉浸组件能力边界分析（结论：不突破官方槽位范围）
- `docs/favorite-module-supplement.md` — 收藏模块补充说明
- `docs/sort-rework-delivery.md` — 排序交互重构交付记录
- `docs/follow-list-delivery.md` — 关注 / 粉丝列表交付记录
- `docs/user-profile-delivery.md` — 用户主页交付记录

以上为 `docs/` 当前全部专项文档，各自配套对应模块使用。新增排障 / 方案记录时请沿用该目录与既有命名风格。

## 接口参考

实现参考 TiebaLite GPLv3 项目的公开接口与模型设计：

- `POST /c/f/excellent/personalized`
- `POST /c/f/frs/page`
- `POST /c/f/forum/like`
- `POST /c/f/concern/userlike?cmd=309474`
- `POST /c/f/pb/page?cmd=302001&format=json`

请求层使用移动端公共参数、签名和 JSON 兼容解析。Protobuf 目录记录了 `CommonRequest`、`PbPageRequest`、`UserLikeRequest`、`PersonalizedRequest` 的字段模型，并提供基础 Wire-format 编解码器。完整 Protobuf 响应还需要继续补齐 TiebaLite 的全部 `.proto` 依赖（ThreadInfo、User、PbContent、Page、Anti 等）。

## 构建

### 环境要求

- DevEco Studio 26.0 及以上
- HarmonyOS 7 / API 26 SDK
- 手机设备或模拟器（本工程按手机布局设计，未适配平板）

### 步骤

1. 使用 DevEco Studio 打开 `TiebaPura/` 目录；
2. 安装依赖：

```text
ohpm install --all
```

3. 构建目标：

```text
assembleHap
```

4. 产物默认位于：

```text
entry/build/default/outputs/default/entry-default-unsigned.hap
```

### 已知限制

- 当前工程**未配置真实签名材料**，产物为 unsigned HAP。安装真机前需在
  DevEco Studio 的 **Signing Configs** 中启用自动签名（或手动配置证书与 Profile）。
- 命令行构建可使用 DevEco Studio 自带的 `hvigorw`：
  `hvigorw --mode module -p product=default assembleHap --no-daemon`。
  仓库内 `tools/` 目录（含本机专用的 `build.ps1`、`pack.ps1`）**已被 `.gitignore` 与
  `pack.ps1` 双重排除、不随之分发**，其中硬编码了作者的 DevEco SDK / Node / JBR 安装路径；
  本机使用说明见 `tools/README.md`（同样不分发）。
- 发布打包：`tools/pack.ps1` 一键产出干净发布包——排除 `.idea/`、`.hvigor/`、`backup/`、
  `entry/build/`、`oh_modules/`、`*.hap` 等约 38 MB 无关内容，并自带越界自检与本机指纹扫描。
  详见 `tools/README.md`。
- 贴吧接口属于第三方服务且非公开文档，接口可用性、签名算法与风控策略随时可能变化，
  功能可用性不做保证。

## 开源协议

本工程以 **GNU General Public License v3.0** 发布，协议全文见 [LICENSE](./LICENSE)。

```text
TiebaPura — HarmonyOS 原生 ArkTS 实现的第三方百度贴吧客户端
Copyright (C) 2026  a307608689-afk

本程序是自由软件：你可以依据自由软件基金会发布的 GNU 通用公共许可证
（第 3 版，或你选择的任何更新版本）重新分发和/或修改它。

本程序的分发是希望它有用，但不提供任何担保，甚至不提供适销性或
特定用途适用性的默示担保。详见 GNU 通用公共许可证。

你应当已随本程序收到一份 GNU 通用公共许可证副本；若没有，
请见 <https://www.gnu.org/licenses/>。
```

> 版权署名使用 GitHub 账号 `a307608689-afk`。GPLv3 未强制要求署名包含邮箱，
> 本项目因此不公开作者邮箱；如需联系请通过 GitHub Issue。

选择 GPLv3 而非宽松协议的原因：本工程在设计上参考了同样以 GPLv3 发布的 TiebaLite，
采用相同协议可确保下游分发时的授权链条完整、无歧义。

## 参考与致谢

本项目为**独立重写实现**，仅参考以下公开项目的**接口路径、协议字段模型与交互设计**，
未复制其源代码、字节码、UI 资源或签名材料。感谢原作者与社区的公开工作：

| 项目 | 协议 | 参考内容 |
| --- | --- | --- |
| [TiebaLite](https://github.com/min09577/TiebaLite) | GPL-3.0 | 贴吧接口路径、Protobuf 字段模型、用户信息页交互范式 |
| [aiotieba](https://github.com/lumina37/aiotieba) | Unlicense | 接口公共参数、签名算法、请求 / 响应结构对照 |
| [tbclient.protobuf](https://github.com/n0099/tbclient.protobuf) | 未声明 | Protobuf 消息定义的结构性参照（仅供比对，未复制文件） |

同时感谢华为官方能力：ArkUI / HDS 的沉浸光感材质（`systemMaterial`）、
`SymbolGlyph` 系统符号、悬浮玻璃底栏与安全区适配均基于官方接口实现。

### 与 TiebaLite 的 GPLv3 合规关系

TiebaLite 是 GPLv3 项目。本工程只参考其公开源码、接口路径、字段模型和交互行为，
并以 ArkTS 重新实现，不复制 APK 的 DEX 字节码、Android Compose UI、签名材料或二进制资源。

如果后续直接移植或分发 TiebaLite 的 GPLv3 源码 / 生成代码，需要：

1. 保留原作者版权和 GPLv3 文本；
2. 标注修改内容与日期；
3. 发布衍生作品时继续提供 GPLv3 授权；
4. 提供对应源代码和构建信息；
5. 不把直接衍生部分作为闭源专有组件发布。

## 免责声明

1. **非官方**：本项目为第三方非官方开源作品，与百度公司及百度贴吧**无任何关联**，
   未获其授权、认可或赞助。
2. **权利归属**：所有贴吧数据、接口、商标、标识及服务条款的著作权与解释权归百度所有。
3. **用途限定**：本项目仅供个人学习与 HarmonyOS 技术研究，**禁止商业用途**，
   禁止用于批量抓取、爬虫、刷量、账号批量操控或任何违反服务条款的行为。
4. **风险自担**：使用者需自行承担因使用本项目产生的接口风控、账号封禁、
   数据丢失及合规责任，作者不承担任何直接或间接损失。
5. **无担保**：本程序按 GPLv3 第 15、16 条以「现状」提供，不提供任何明示或默示担保。
6. **第三方服务**：贴吧接口属于第三方服务，接口可用性、登录、风控、频率限制
   和服务条款**以百度贴吧实际规则为准**；接口变更导致的功能失效属正常现象。
7. **侵权处理**：若权利人认为本项目存在侵权内容，请通过 GitHub Issue 联系，
   作者将在核实后及时调整或移除相关内容。

## 贡献

本项目为个人技术验证性质的原型工程，欢迎通过 GitHub Issue 反馈问题与建议。
提交 PR 前请确保：

- 不引入任何第三方跨平台 UI 框架替换现有原生实现；
- 不提交任何账号凭据、Cookie、签名材料与设备日志；
- 改动涉及界面时，保持与既有布局几何一致；
- 新增排障记录请放入 `docs/` 并沿用既有命名风格。

---

Copyright (C) 2026 a307608689-afk · 以 [GNU GPL v3.0](./LICENSE) 发布 · 本项目与百度公司无关
