# TiebaPura 上架自检清单

> 适用版本：v1.0.0（versionCode `1000000`）
> 核对基准：2026-09-11
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

- [ ] **上架包必须使用发布证书签名**
  位置：`build-profile.json5` 的 `signingConfigs`，当前为空数组 `[]`（签名材料由本地注入）。
  待办：确认 release 包用的是发布证书（.p12 / .cer / .p7b），且证书指纹与市场后台登记的一致；不要打调试证书。

- [ ] **政策改动必须推送到 GitHub**
  审核员看的是远端文件。本地改完不推送，等于没改——线上 URL 仍是旧内容。

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
- [ ] 市场后台需为每个敏感权限填写「使用理由」，理由文案必须与政策 1.3 表格的「用途」列一致。
  - `VIBRATE` → 交互触觉反馈（点赞 / 签到 / 收藏）
  - `KEEP_BACKGROUND_RUNNING` → 一键签到 / 后台签到期间保持任务完成

---

## 四、工程配置 ↔ 市场后台表单

| 后台字段 | 应填值 | 出处 |
| --- | --- | --- |
| 包名 | `com.tiebapura.app` | `AppScope/app.json5` 的 `bundleName` |
| 开发者主体 | `a307608689-afk` | `AppScope/app.json5` 的 `vendor`（须与实名主体一致） |
| 应用名称 | `TiebaPura` | `AppScope/resources/base/element/string.json` 的 `app_name` |
| 版本号 | `1.0.0` | `AppScope/app.json5` 的 `versionName` |
| 版本代码 | `1000000` | `AppScope/app.json5` 的 `versionCode` |
| 支持的最低系统版本 | `6.1.0(23)` | `build-profile.json5` 的 `compatibleSdkVersion`——**别填成 26** |
| 目标 API | `26.0.0` | `build-profile.json5` 的 `targetSdkVersion` |
| 设备类型 | 仅手机 | `module.json5` 的 `deviceTypes`（仅 `phone`），后台勾选须一致 |
| 隐私政策网址 | `https://github.com/a307608689-afk/TiebaPura/blob/main/docs/PRIVACY.md` | `common/Constants.ets` 的 `PRIVACY_POLICY_URL` |
| 隐私权利（可选） | `https://github.com/a307608689-afk/TiebaPura/issues` | — |

- [ ] 后台填的隐私政策网址与 `Constants.ets` 的 `PRIVACY_POLICY_URL` 逐字符一致（填 `blob` 渲染页，不要填 `raw` 源码页）。
- [ ] 应用图标已定稿：`AppScope/resources/base/media/app_icon.png` 存在；如市场另有尺寸要求需单独出图。
- [ ] 三方依赖为空，与政策「不嵌入任何第三方 SDK」一致。
  位置：根 `oh-package.json5` 与 `entry/oh-package.json5` 的 `dependencies` 均为 `{}`。

---

## 五、真机验证（读代码读不出来，必须上机）

- [ ] **首启只有弹窗**：卸载重装 → 启动瞬间不能闪出一帧主界面（验 `Index.ets` 的 `privacyPhase` 从 0 到 1 的过渡）。
- [ ] **同意后不再弹**：点「同意并继续」→ 杀进程重开 → 直接进主页。
- [ ] **拒绝即退出**：点「不同意」→ 应用直接关闭，且不进入任何功能。
- [ ] **返回键被拦住**：弹窗期间按返回键无效（验 `Index.ets` 的 `onBackPress` 中 `privacyPhase < 2` 分支）。
- [ ] **政策链接可打开**：首启点「查看完整《隐私政策》」→ 能拉起浏览器；「我的 → 设置 → 隐私政策」同样能打开。
- [ ] **大字号不截断**：系统字号调到最大（1.35x）+ 深色模式 → 弹窗卡片里的正文滚动区与底部两个按钮都不被挤出屏幕（关注 `PrivacyCard` 的 `constraintSize({ maxHeight: ... })`）。
- [ ] **通知授权时机正确**：通知授权框只在点「一键签到 / 后台签到」时弹出，**首启绝对不弹**（`AutoSignNotifier.ets` 的注释明确要求必须在手势中调用）。
- [ ] **同意前零请求**：首启停留在弹窗时不应有任何网络请求（可用设备抓包或开发者工具确认）。
- [ ] **权限拒绝后不崩**：系统设置里关掉震动/通知 → 应用各功能仍能正常使用（仅失去对应反馈）。

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
