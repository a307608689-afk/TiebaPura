# TiebaPura 上架自检清单

> 适用版本：v1.0.5（versionCode `1000005`）
> 核对基准：2026-09-15
> 用法：每次向应用市场提交前从上到下过一遍。每条都标了「去哪个文件哪一行核对」，不要凭记忆打勾。
> 本清单的核心是查**三处一致性**：App 内弹窗文案 / 在线隐私政策 / 市场后台表单——这三者互相对不上，是审核驳回最常见的理由。

---

## 一、阻断项（不过就别提交）

- [x] **A1 隐私政策里不得出现「默示同意」表述**
  已改：`docs/PRIVACY.md` 引言段，原来那句「一旦您开始使用本应用，即视为您已知悉并同意」已替换为「独立弹窗 + 主动点击同意」的显式授权描述。
  原因：这与 `entry/src/main/ets/pages/Index.ets` 里「不点同意就 `terminateSelf`」的强制弹窗自相矛盾，且违反市场明示同意要求。

- [x] **A2 不得声称「后台完全不发请求」**
  已改：`docs/PRIVACY.md` 3.3 安全措施，改为限定在「您主动发起的一键签到 / 后台签到」期间。
  原因：`entry/src/main/ets/service/AutoSignNotifier.ets` 会调 `backgroundTaskManager.startBackgroundRunning(..., BackgroundMode.DATA_TRANSFER, ...)`，即退到后台仍会发签到请求。

- [x] **A3 第三方服务链接必须指向对应服务**
  已改：原 `ai.baidu.com/ai-doc/PRIVACY/WkQb6lW4d`（百度 **AI 产品线**的隐私政策）→ 换成 `https://www.baidu.com/duty/yinsiquan.html` + `https://tieba.baidu.com/tb/eula.html`（均已实测返回 200）。
  两处：`docs/PRIVACY.md` 4.2 节、附录 B 表格。

- [x] **B1 通知能力必须披露**
  已改：`docs/PRIVACY.md` 1.3 节新增「关于通知」段。
  原因：`AutoSignNotifier.ets` 会调 `notificationManager.requestEnableNotification()` + `publish()`。通知不属于 `requestPermissions`，是最容易漏披露的一项。

- [x] **B2 变更通知方式必须与实现一致**
  已改：`docs/PRIVACY.md` 八、本声明的变更，改为「递增政策版本号 + 重新展示同意弹窗」。
  原因：实现是 `Index.ets` 的 `isPrivacyAgreed()` 比对 `CACHE_KEY.PRIVACY_AGREED` 与 `PRIVACY_POLICY_VERSION`，并没有「应用内通知」这条链路。

- [x] **B3 补充可直达开发者的联系方式**
  已改：`docs/PRIVACY.md` 九、联系我们，已补入开发者邮箱 `a307608689@gmail.com`，并置于 GitHub Issue 之前（审核员或用户可直达，不必注册 GitHub 账号）。

- [x] **上架包必须使用发布证书签名（链路已实测通过；归档物一度写错，已更正）**
  位置：`build-profile.json5` 的 `signingConfigs` 是空数组 `[]`，属**有意设计**——发布材料由 `hvigorfile.ts` 从 `tools/signing.local.json` 注入；该文件被 `.gitignore` 第 31 行 `/tools/` 排除，仓库内不含任何 p12 / cer / p7b。
  已核：`.cer` 是完整证书链（根 CA → Developer Relations CA → 叶证书 `CN="…\,Release"`，指纹 `6842BD54…`），与 `.p7b` 内嵌的 `distribution-certificate` 指纹**完全一致**；`.p7b` 为 `type: release` + `app-distribution-type: app_gallery`，`bundle-name` 为 `com.tiebapura.app`，有效期至 2029-09-11。
  **两个真踩过的坑（2026-09-11 实测复现，都只能靠验签发现）：**
  1. **IDE 会在后台把产物换掉。** DevEco「自动签名」用的是它自己那套 debug 材料（`~/.ohos/config/` 下的 `default_*.p7b`），而它的产物落在**与命令行完全相同**的 `entry/build/default/outputs/default/`。当天 IDE 反复构建，把 `entry-default-signed.hap` 覆盖成 `profile type is: debug`、证书主体 `\,Development` 的包；而 `build-profile.json5` 全程是干净的 `signingConfigs: []`——**只看工程文件根本发现不了**。
  2. **归档进 `dist/` 的那个 HAP 曾是 unsigned。** 对它验签直接失败：`No Hap Signing Block before ZIP Central Directory`。它是引入本机签名机制之前的旧产物，文件名看不出任何区别，险些被当成可上架包。
  **强制动作：每次打包后必须验签，并且要对 `dist/` 里的归档副本再验一次，不要相信文件名里的 signed。**
  ```powershell
  # 期望看到 profile type is: release，且证书主体为 \,Release
  # 把 $deveco 换成你本机 DevEco Studio 的安装目录
  $deveco = '<DevEco Studio 安装目录>'
  & "$deveco\jbr\bin\java.exe" -jar `
    "$deveco\sdk\default\openharmony\toolchains\lib\hap-sign-tool.jar" `
    verify-app -inFile entry\build\default\outputs\default\entry-default-signed.hap `
    -outCertChain "$env:TEMP\chain.cer" -outProfile "$env:TEMP\profile.p7b"
  ```

- [ ] **不要在 DevEco Studio 里点「自动签名」**
  它会用 debug 证书接管签名链路（见上一条）。统一走 `tools\build.ps1` 打包；若已误点，先 `git checkout -- build-profile.json5` 还原，再重新打包并验签。

- [x] **release 包开了混淆，但工程里没有任何 keep 规则——风险已排除（实测证据）**
  位置：`entry/build-profile.json5` 的 `buildOptionSet`，`release` 分支 `obfuscation.ruleOptions.enable = true`；同时全工程**不存在 `obfuscation-rules.txt`**。
  原担心：本应用大量依赖贴吧接口返回的固定 JSON 字段名，一旦混淆触及**属性名**会**静默失效**（debug 包完全测不出来）。
  实测结论：**默认规则不重命名属性名，不需要补 keep 规则**。两条独立证据：
  1. ArkGuard 的名称缓存 `nameCache.json` 里 **`PropertyCache` 出现 0 次**；只有 47 个非空 `IdentifierCache` 与 45 个非空 `MemberMethodCache`——它记录的是**局部变量 / 参数**（形如 `CacheManager#delete#key → a`）与**成员方法名**，不含任何属性名。
  2. 从最终签名包里取出 `ets/modules.abc`（1960368 字节）直接搜，贴吧协议字段**全部原样存活**：`error_code`、`error_msg`、`user_name`、`forum_name`、`forumName`、`is_like` 均命中。
  仍需做：真机跑一遍 release 核心流程（第五节），但它已从「不知会不会崩」降级为常规回归。

- [ ] **安装验证必须用 release 包，不能用 debug 包**
  `tools/build.ps1` 默认出 release；带 `-Debug` 出的包会携 `debug:true` 与 `sourceMaps`，仅供调试。
  已核：当前 release 包的 `pack.info` 里 `bundleName=com.tiebapura.app`、`version.name=1.0.0`、`version.code=1000000`、`deviceType=["phone"]`、`compatible=23 / target=26`；包内共 8 个条目，**无 sourceMaps / `.map` / `.ts` / debug 残留**。
  已核归档物：`dist\TiebaPura-v1.0.0-hap-2a368c8-20260911-155503.hap`，已对该副本**单独跑过一次 verify-app** 得到 `profile type is: release` + `Verify success`，SHA256 记在同目录 `.sha256` 文件里。

- [x] **政策改动必须推送到 GitHub**
  审核员看的是远端文件。本地改完不推送，等于没改——线上 URL 仍是旧内容。
  已核（2026-09-11）：隐私合规修正已随 `5fc824c` 推送，清单与后续结论修正又推了 `2a368c8` / `d79a782`；`origin/main` 与本地 `HEAD` 一致。

- [ ] **政策版本号是否递增（仅当应用已发布过）**
  位置：`entry/src/main/ets/common/Constants.ets` 的 `PRIVACY_POLICY_VERSION`。
  规则：**首次发布前的修订不用动**（没有存量用户需要重新征得同意）；**已发布后**只要出现 A2/B1 这类实质变更（收集范围、用途、第三方共享变化），必须递增，老用户下次启动会自动重新收到同意弹窗。

---

## 二、三处一致性核对（弹窗 ↔ 政策 ↔ 后台）

| 核对点 | App 内弹窗（`Index.ets` 的 `PrivacyCard`） | 在线政策（`docs/PRIVACY.md`） | 结论 |
| --- | --- | --- | --- |
| 数据存储位置 | 「仅在您的设备本地保存……不上传至我们控制的服务器」 | 3.1 存储位置 | 一致 |
| 数据发往哪里 | 「必要的请求参数会发送至百度贴吧官方接口」 | 4.2 必要的接口调用 | 一致 |
| 权限承诺 | 「不申请通讯录、位置、相册、麦克风等与功能无关的任何权限」 | 1.3 设备权限 | 一致 |
| 无第三方 SDK | 「不含任何第三方广告、统计或推送 SDK」 | 二 / 六 | 一致 |
| 不做用户画像 | 「不进行用户画像与个性化推荐」 | 二 我们不会 | 一致 |
| 后台运行说明 | 弹窗未提 | 3.3（本次已按实现修正） | 见下方备注 |

> 备注：弹窗文案是「精简版」，只需与政策的结论不冲突；但弹窗里若承诺得比政策「更绝对」（例如 A2 那句被删掉的表述），一旦实现做不到就是硬伤。**弹窗宁可比政策保守，不可比政策激进。**

---

## 三、权限一致性

- [x] 声明权限共 3 项，无多余
  位置：`entry/src/main/module.json5` 的 `requestPermissions`（`INTERNET` / `VIBRATE` / `KEEP_BACKGROUND_RUNNING`）。
- [x] 三项权限与政策 1.3 表格逐条对应，**一个不多一个不少**。
- [x] 不存在「申请了但没用到」的权限。
  `KEEP_BACKGROUND_RUNNING` 的真实调用点：`AutoSignNotifier.ets` 的 `startBackgroundTask()`。
- [x] 没有缺少必要权限。
  全工程未调用 `@ohos.net.connection`（无网络状态判断），因此**不需要** `GET_NETWORK_INFO`。
- [x] 保存图片未申请写相册权限，走 `SaveButton` 安全控件。
  位置：`pages/Favorite.ets`、`pages/ImagePreview.ets`；与政策 1.3「特别说明」一致。
- [ ] 市场后台需为每个敏感权限填写「使用理由」，文案必须与 `docs/PRIVACY.md` 1.3 表格的「用途」列口径一致。可直接粘贴：
  - `ohos.permission.INTERNET` —— 用于访问百度贴吧官方接口、加载帖子正文与用户头像，是浏览功能所必需。本应用不使用该权限上传您的本地文件，也不会将数据发送至百度以外的任何服务器。
  - `ohos.permission.VIBRATE` —— 用于点赞、签到成功、收藏成功等操作的触觉反馈，仅在您主动触发对应操作时短暂震动，不用于提醒或营销。
  - `ohos.permission.KEEP_BACKGROUND_RUNNING` —— 仅在您主动发起「一键签到 / 后台签到」后启动长时任务（dataTransfer），用于避免应用退到后台时签到流程被系统中断；任务结束即停止，不用于任何其他后台行为。

---

## 四、工程配置 ↔ 市场后台表单

| 后台字段 | 应填值 | 出处 |
| --- | --- | --- |
| 包名 | `com.tiebapura.app` | `AppScope/app.json5` 的 `bundleName` |
| 开发者主体 | `a307608689-afk` | `AppScope/app.json5` 的 `vendor`（须与实名主体一致） |
| 应用名称 | `TiebaPura` | `AppScope/resources/base/element/string.json` 的 `app_name` |
| 版本号 | `1.0.5` | `AppScope/app.json5` 的 `versionName` |
| 版本代码 | `1000005` | `AppScope/app.json5` 的 `versionCode` |
| 支持的最低系统版本 | `26.0.0` | `build-profile.json5` 的 `compatibleSdkVersion`（已与 `targetSdkVersion` 同为 `26.0.0`） |
| 目标 API | `26.0.0` | `build-profile.json5` 的 `targetSdkVersion` |
| 设备类型 | 仅手机 | `module.json5` 的 `deviceTypes`（仅 `phone`），后台勾选须一致 |
| 隐私政策网址 | `https://github.com/a307608689-afk/TiebaPura/blob/main/docs/PRIVACY.md` | `common/Constants.ets` 的 `PRIVACY_POLICY_URL` |
| 隐私权利（可选） | `https://github.com/a307608689-afk/TiebaPura/issues` | — |

- [x] 后台填的隐私政策网址与 `Constants.ets` 的 `PRIVACY_POLICY_URL` 逐字符一致（填 `blob` 渲染页，不要填 `raw` 源码页）。
  已核：`Constants.ets` 的值就是 `https://github.com/a307608689-afk/TiebaPura/blob/main/docs/PRIVACY.md`，与上表一字不差——提交时原样粘贴即可。
- [x] 应用图标已定稿：`AppScope/resources/base/media/app_icon.png` 存在（804106 字节）；如市场另有尺寸要求需单独出图。
- [x] 三方依赖为空，与政策「不嵌入任何第三方 SDK」一致。
  已核：根 `oh-package.json5` 与 `entry/oh-package.json5` 的 `dependencies` 均为 `{}`，`devDependencies` / `dynamicDependencies` 亦为空。
- [ ] **开发者身份一致性**：用第一节的 verify-app 命令打印证书主体，确认它与你提交所用的市场后台账号一致。
  证书主体形如 `CN="<实名>(<开发者账号ID>)\,Release"`——**实名与账号 ID 直接从证书里读，本文档不留档**；文档只记指纹：叶证书 `6842BD54…`。
  另：`AppScope/app.json5` 的 `vendor` 目前是 `a307608689-afk`（GitHub 昵称）；若要在「关于本应用」展示真实开发者名称可一并调整，不改也不影响审核。

---

## 五、真机验证（读代码读不出来，必须上机）

> 前置条件：`hdc list targets` 非空（hdc 在 DevEco SDK 的 `toolchains\` 下）。**列表为空时本节一条都做不了**——此时不要靠「代码看得没问题」打勾，也不要拿构建目录里同名但来路不明的产物冒充已验证。

- [ ] **首启只有弹窗**：卸载重装 → 启动瞬间不能闪出一帧主界面（验 `Index.ets` 的 `privacyPhase` 从 0 到 1 的过渡）。
- [ ] **同意后不再弹**：点「同意并继续」→ 杀进程重开 → 直接进主页。
- [ ] **拒绝即退出**：点「不同意」→ 应用直接关闭，且不进入任何功能。
- [ ] **返回键被拦住**：弹窗期间按返回键无效（验 `Index.ets` 的 `onBackPress` 中 `privacyPhase < 2` 分支）。
- [ ] **政策链接可打开**：首启点「查看完整《隐私政策》」→ 能拉起浏览器；「我的 → 设置 → 隐私政策」同样能打开。
- [ ] **大字号不截断**：系统字号调到最大（1.35x）+ 深色模式 → 弹窗卡片里的正文滚动区与底部两个按钮都不被挤出屏幕（关注 `PrivacyCard` 的 `constraintSize({ maxHeight: ... })`）。
- [ ] **通知授权时机正确**：通知授权框只在点「一键签到 / 后台签到」时弹出，**首启绝对不弹**（`AutoSignNotifier.ets` 的注释明确要求必须在手势中调用）。
- [ ] **同意前零请求**：首启停留在弹窗时不应有任何网络请求（可用设备抓包或开发者工具确认）。
- [ ] **权限拒绝后不崩**：系统设置里关掉震动/通知 → 应用各功能仍能正常使用（仅失去对应反馈）。
- [ ] **release 包核心流程回归**（混淆与发布签名都只在 release 生效，debug 通过≠release 通过）：装 `entry-default-signed.hap`（验签为 release 的那个）→ 登录态读取、帖子正文与楼层渲染、图片加载、签到、收藏、发帖各走一遍，确认无字段读不到、无空白页。
- [ ] **确认装上去的确实是 release 包**：别只认文件名，以「打包后验签输出 `profile type is: release`」为准。

---

## 六、每次版本迭代需重跑

- [ ] **新增了权限？** 同步四处：`module.json5` 声明 → `docs/PRIVACY.md` 1.3 表格 → 弹窗文案（若有绝对化承诺需放宽）→ 后台权限使用理由。
- [ ] **新增了第三方依赖？** 检查是否需要在 `docs/PRIVACY.md` 附录 B 的第三方服务清单披露；同时核对政策里「不嵌入任何第三方 SDK」这句是否还成立。
- [ ] **改了数据处理行为？** 递增 `Constants.ets` 的 `PRIVACY_POLICY_VERSION`，并同步 `docs/PRIVACY.md` 首部的「最后更新」日期。
- [ ] **改了应用版本？** 同步 `AppScope/app.json5` 的 `versionCode` / `versionName`、两个 `oh-package.json5`、以及政策首部的「适用版本」。
- [ ] **政策文档改动后已推送到 GitHub**（否则线上 URL 仍是旧版）。

---

## 七、本清单覆盖不到的风险（不属于「填表」能解决的问题）

- **应用名称**：`TiebaPura` 含 `Tieba`（百度贴吧英文名），存在名称/商标层面的风险，市场可能要求改名。
- **内容合规**：应用展示的是贴吧的用户生成内容（UGC），可能被要求提供内容审核与举报机制。
- **接口合规**：抓取非公开接口的合规性由业务模式本身决定，与表单填写无关。
- 以上三条需在提交前自行评估，若有疑问建议先走市场工单咨询，避免提交后被驳回。
