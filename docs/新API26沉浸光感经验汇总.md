# 新 API 26 沉浸光感经验汇总 — TiebaPura

> **定位**：本工程在 HarmonyOS 7 / API 26 上用官方「沉浸光感（Immersive Light Sense）」的**实战经验汇总**。
> 查「官方怎么规定的」→ `immersive-light-sense-api26-official.md`；查「本工程整体怎么搭的」→ `immersive-material-guide.md`；
> **查「我现在要改一个点位，该怎么判、怎么写、怎么验」→ 就是本文。**
>
> 维护约定：只收**真机验证过的判断**、**可直接复制的模板**、**待办清单**。推断/未验证的必须显式标注。
> 最后更新：2026-09-12（新增：① 系统 CustomDialog 吃官方材质；② 弹窗内的 `Button` 也吃材质；
> ③ **顶部「`Navigation` 标题栏」槽位打通** —— 吸顶分段胶囊 / 44 圆钮可从页面主体搬进 `title` 槽位吃真材质，**真机已验生效**，见 §1.5 / §6.10；
> ④ `Search.ets` 顶部（返回钮 / 搜索框 / 搜索钮）搬进 `title` 槽位，**代码已落地待真机验证**，见 §9.3 #7 落地清单；
> ⑤ **自建「空 `Tabs` 壳」做 TabBar 槽位时，壳宽必须收敛到「目标元素实际占位」** —— 开全宽会让系统 TabBar 页签节点
> 吞掉下层列表的滑动，且 `hitTestBehavior` 修不了（挂不到系统节点上），**两方案真机双向验证**；本工程两处壳
> （`ThreadList` FAB 壳 80 / `ThreadDetail` 排序壳 148~172）**均已收窄并真机验收，存量清零**，见 §6.13 / §9.3 #6 / 坑 30）

---

## 1. 一句话结论

**真沉浸材质只在官方白名单槽位渲染；白名单之外的一切点位，只能靠 `backgroundBlurStyle` 真模糊磨砂。**

### 1.1 判定速查表（改任何点位前先查这张表）

| 点位 | 有材质？ | 本工程做法 |
|---|---|---|
| `Navigation` / `NavDestination` **标题栏** | ✅ | `.title()` 槽容器挂 `ImmMaterial.bar()` |
| Tabs **`BarPosition.End` 底部页签**（`barOverlap=true` + `vertical=false` + `barPosition=End` 三条件齐） | ✅ | `barFloatingStyle({ systemMaterial: ImmMaterial.floatingBar() })` |
| **自建「空 `Tabs` 壳」内的元素**（`Tabs{ TabContent().tabBar(...) }`，`barHeight` = 壳高 → 内容区恒 0，壳里只剩 tabBar） | ✅ | 与上一行同一槽位，壳内元素各自挂 `.systemMaterial(...)`；⚠️ **壳宽必须收敛到「目标元素实际占位」，不能开 `'100%'`** —— 否则系统页签节点横跨整行、吞掉下层列表的滑动 ← **本次新增能力**（§6.13 / 坑 30）；⚠️ **空壳上 `barFloatingStyle.systemMaterial` 不生成背板**（上一行的玩法只在「`TabContent` 有内容」的壳上成立）—— 空壳要整条玻璃，就把材质挂到**槽内那一条容器**上（坑 31 / §6.14）；⚠️ 这种「无背板托底」的栏材质要用**无阴影档** `floatingBarFlat()`（坑 32） |
| **系统弹窗**：CustomDialog / AlertDialog / ActionSheet / Sheet / PromptAction / Menu / Toast / Tips / Popup | ✅ | `options.systemMaterial = ImmMaterial.dialog()` ← **本次新增能力**<br>⚠️ `AlertDialog` 名义在列，实则**版式被系统写死**（标题/正文/按钮排布固定），且不显式传 `systemMaterial` 就是纯白底 → 本工程的二次确认统一改用 `CustomDialog`（§6.5） |
| **系统弹窗子树内的 `Button`**（挂在 `CustomDialog` 内的按钮） | ✅ | 按钮自身 `.systemMaterial(ImmMaterial.accent()/cardAction())`，可与半透明 `backgroundColor` + `shadow` 共存 ← **本次新增能力**（§6.2） |
| **Slider / Toggle / Select / Chip / ChipGroup / SegmentButton / SelectionMenu** | ✅ | 组件级字段，工程暂未用 |
| **`Navigation` 标题栏内「自定义 title builder」的子元素**（`Text` 分段胶囊、44 圆钮…） | ✅ **真机已验** | `.title({ builder: this.XxxBar(), height: 108 })` + `barStyle: STACK`，**槽内子元素各自挂** `.systemMaterial(...)` ← **本次新增能力**（§1.5 / §6.10） |
| 页面 body 里的**自绘浮层 / 吸顶叠层**（弹窗、胶囊、44 圆钮、卡片、底栏） | ❌ **out of scope** | 走 `backgroundBlurStyle` 真模糊（guide §6.1 / §6.6 模板）；**顶部吸顶行现在有解** —— 整行搬进 `Navigation` 标题栏槽位（§6.10） |

### 1.2 ★ 本次新增的一条判据

同样是"弹窗"，**自绘浮层 = 无材质；系统 `CustomDialog` = 有材质**。

> 工程 §8 / §10.3 曾记「弹窗挂材质不渲染（定案，勿再试）」——**那条只对"页面 body 内自绘 Stack 浮层"成立**。
> 把弹窗宿主换成系统 `CustomDialog`（官方 A 档「弹窗类」）后材质正常渲染，2026-09-10 已落地验证。

### 1.3 为什么会有这条分界

官方把生效范围分成两档（`immersive-light-sense-api26-official.md` §4）：

- **A 档**：弹窗类组件 / 弹窗类接口 / 按钮与选择类 → **页面内任意区域都生效**
- **B 档**：其他组件（含布局容器）→ **仅限** Navigation/NavDestination 标题栏 与 `BarPosition.End` 底部 TabBar

页面 body 里的自绘浮层属于 B 档且不在两个槽位内 → 越界。**换成 A 档的宿主，点位就合法了** —— 这就是本次改造的全部思路。

### 1.4 ★ 追加判据：A 档宿主的**子树**也吃材质（Button 已验）

**真机结论（2026-09-10）**：把 `Button` 放进系统 `CustomDialog` 的子树里、直接对 Button 挂通用属性
`.systemMaterial(...)`，**材质正常渲染，无 `out of scope`**。

| 判断 | 状态 |
|---|---|
| 系统 `CustomDialog` 内的 `Button` 挂 `systemMaterial` 是否生效 | ✅ **真机已验生效**（观感满意） |
| 成因 | **推断**（未逐条对照官方原文）：Button 所在子树属于 A 档「弹窗类」宿主 `CustomDialog`，不再落在 B 档「页面 body 自绘浮层」禁区 |

> **由此修正一条旧认知**：不要再用「只有弹窗**容器**吃材质、卡内子组件不吃」来判断。
> **A 档宿主的子树是合法的** —— 至少在系统 `CustomDialog` 内、对 `Button` 已实测成立。
> 自绘浮层仍不成立（§1.2）——分界在**宿主是不是官方弹窗**，不在层级深浅。

**附带结论**：按钮上 `systemMaterial` 与**半透明** `backgroundColor` + 自定义 `shadow` **三者可共存**，
叠出「按钮抬起于玻璃卡之上」的层次（§6.2 给了完整写法与前提）。

### 1.5 ★ 追加判据：**B 档「顶部 `Navigation` 标题栏」槽位打通**（2026-09-10 真机已验生效）

**这是页面主体「吸顶行」的第一条出路。** §1.1 长期写着「吸顶分段胶囊 / 44 圆钮 → ❌ 无官方宿主，只能 `backgroundBlurStyle`」，
现在补上：**把整行搬进 `Navigation` 的 `title` 槽位，槽内自定义 builder 的子元素各自挂 `systemMaterial` 即可渲染**。

| 判断 | 状态 |
|---|---|
| `Navigation` 标题栏内**自定义 title builder 的子元素**挂 `systemMaterial` 是否生效 | ✅ **真机已验生效**（首页「推荐 / 关注动态 / 搜索圆钮」三颗，用户确认「已生效」） |
| 与官方「标题栏 `systemMaterial` 生效范围＝返回键 + 非自定义 Menu」是否冲突 | 不冲突：本次用的**不是标题栏自身材质**，而是**槽内子元素的通用属性 `systemMaterial`** —— 官方 B 档原文「生效区域为 Navigation/NavDestination 标题栏」**字面命中** |
| 成因 | **官方字面命中**（无需推断）：自定义 title builder 就渲染在标题栏区域内，故子元素落在生效范围内 |

> **与 §1.4 并列成对**：A 档宿主（系统 `CustomDialog`）的**子树**合法，B 档顶部槽位的**子树**也合法。
> 唯一的禁区仍是「**页面 body 里的自绘浮层**」—— 分界在**宿主槽位**，不在层级深浅。

**代价（必须接受）**：这条路要在页面 `build()` 根**新增一层 `Navigation` 壳**（本工程此前 0 个 `Navigation` 组件）。
形态与几何能做到逐项一致（§6.10 有完整对齐表），但**观感必然从「半透明 + 0.5 描边 + 轻投影」变成系统玻璃**（§7 偏差 ③）。

---

## 2. 越界长什么样

```
Material inactive: out of scope. Use component in navigation title bar or Tabbar.
```

**"能编译 ≠ 能渲染"**：`systemMaterial` 定义在 `CommonMethod` 上（`common.d.ts:23521`），任何组件挂它都能编译通过，渲染层才按白名单裁剪。所以**不要用"编译过了"来判断点位合法**。

---

## 3. 三条硬约束（本次踩到，务必背下来）

### 3.1 `customStyle` 必须为 `false`

官方 `customStyle` 字段说明明文：**`customStyle: true` 时弹窗背景色强制透明、圆角归 0、沉浸光感不生效**。

> 结论：**"几何完全自控 + 官方材质"做不到**。想同时要材质和自定义圆角/背景，只能走 `customStyle: false`，圆角靠 `cornerRadius`、几何靠 options 对齐。
> 代码里请**显式写出** `customStyle: false` 并加注释自证，避免后人"顺手改成 true"。

### 3.2 `options.width` 是 `Dimension`，**不接受 `calc()` 字符串**

直接编译报错：

```
Type '"calc(100% - 48vp)"' is not assignable to type 'Dimension'.
```

官方说明：`width?: Dimension` —— **设为百分比时，参照物是弹窗所在窗口的宽度**；`'100%'` 合法，`calc(...)` 不合法。

**解法**：换算成数值 vp（数值 `Dimension` 的单位就是 vp）。

```ts
/**
 * 弹窗卡片宽度（vp）= 屏幕宽 - 48vp，等价于自绘浮层的 `calc(100% - 48vp)`。
 * 取屏幕宽（display）而非窗口宽：弹窗容器宽度本身还受系统上限（默认 400vp）约束，
 * 分屏 / 折叠态由该上限兜底。
 */
private dialogCardWidth(): number {
  const info: display.Display = display.getDefaultDisplaySync();
  const widthVp: number = info.width / info.densityPixels;
  return Math.max(200, widthVp - 48);
}
```

需要 `import { display } from '@kit.ArkUI';`。

### 3.3 `@CustomDialog` 结构体**必须声明 `CustomDialogController` 类型属性**

否则编译报 `10905211`：

```ts
@CustomDialog
struct SignAllDialog {
  /** 系统弹窗必须声明 CustomDialogController 类型属性（ArkTS 编译期强校验） */
  controller?: CustomDialogController;
  // ... 其余状态
}
```

**声明即可，不用赋值、不用手动调 `open()`** —— 由宿主的 controller 驱动。

---

## 4. 改造模板：自绘浮层 → 系统 CustomDialog（已验证可跑）

### 4.1 什么时候用这个模板

原浮层是**居中 / 贴底的自绘卡片弹窗**（自带遮罩层 + 卡片 + 按钮），且要求**布局尺寸内容不变、只换玻璃**。

若原浮层是**底部抽屉 / 半模态**形态，别硬套本模板 —— 直接看 §5 的宿主选型表。

### 4.2 三步骨架

**① `Theme.ets`：加材质预设**（集中式，调用点零改动）

```ts
let _matDialog: uiMaterial.ImmersiveMaterial | null = null;

/**
 * 弹窗卡片材质（系统 CustomDialog 的 systemMaterial）。
 * REGULAR 档：对齐改造前弹窗玻璃的 BlurStyle.Regular 观感；
 * interactive=false / applyShadow=true：保持与既有弹窗一致的「无按压形变 + 系统阴影」。
 */
function ensureDialog(): uiMaterial.ImmersiveMaterial {
  if (!_matDialog) {
    _matDialog = new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      interactive: false,
      applyShadow: true,
    });
  }
  return _matDialog;
}

// ImmMaterial 里：
static dialog(): uiMaterial.ImmersiveMaterial {
  return ensureDialog();
}
```

**② 顶层加 `@CustomDialog struct`，内容原样搬**

- 放**模块顶层**（`@Component struct` 之前），不要放页面结构体内部；
- 所有需要随宿主变化的状态用 `@Link`（进度、文案、主题、字号）；
- 回调用普通函数字段：`onDismiss: () => void = () => {};`；
- **卡片内容（文案/字号/间距/按钮尺寸）一行不改**。

**③ 宿主：`@State @Watch` 桥接 + controller**

```ts
@State @Watch('onShowSignAllChanged') showSignAll: boolean = false;

private signAllDialogController: CustomDialogController = new CustomDialogController({
  builder: SignAllDialog({
    isDark: $isDark,
    fontScale: $fontScale,
    running: $signAllRunning,
    // ... 其余 @Link
    onDismiss: () => { this.closeSignAll(); }
  }),
  autoCancel: true,
  alignment: DialogAlignment.Bottom,
  offset: { dx: 0, dy: -110 },
  maskColor: '#06000000',
  cornerRadius: 32,
  width: this.dialogCardWidth(),
  customStyle: false,
  systemMaterial: ImmMaterial.dialog(),
  openAnimation: { duration: 220, curve: Curve.EaseOut },
  closeAnimation: { duration: 200, curve: Curve.EaseInOut },
  onWillDismiss: () => { this.closeSignAll(); }
});

/** showSignAll 变化即驱动 open/close（既有 `this.showSignAll = x` 调用点零改动） */
onShowSignAllChanged(): void {
  if (this.showSignAll) {
    this.signAllDialogController.open();
  } else {
    this.signAllDialogController.close();
  }
}
```

> **@Watch 桥接是这套模板最值钱的一招**：宿主里所有 `this.showXxx = true/false` 一行都不用改，只在状态上挂个 `@Watch` 即可。
> 注意：`@Watch` 回调用 **public**（与工程既有 `onDarkTick` / `onLoginTick` 写法一致；`private` 未实测，别当第一个吃螃蟹的）。

### 4.3 逐项几何对齐表（自绘浮层 → 弹窗 options）

| 原自绘浮层写法 | 现系统弹窗写法 | 是否等价 |
|---|---|---|
| 全屏 `Stack` + 遮罩 `Column.backgroundColor('#06000000')` | `maskColor: '#06000000'` | ✅ |
| `.width('calc(100% - 48vp)')` | `width: this.dialogCardWidth()`（数值 vp） | ✅ 手机上等价；见 §7 偏差 ① |
| `.borderRadius(32)` | `cornerRadius: 32` | ✅（恰为 `customStyle=false` 默认值） |
| `.padding(Spacing.lg)` | **卡内保留** `.padding(Spacing.lg)` | ✅ |
| `.margin({ bottom: 110 })` + `.alignContent(Alignment.Bottom)` | `alignment: DialogAlignment.Bottom` + `offset: { dx: 0, dy: -110 }` | ✅ |
| `.zIndex(101)` | 系统弹窗自带层级 | ✅（可删） |
| `.transition(scale 0.92 + translate y24 + opacity, 220ms)` | `openAnimation: 220ms EaseOut` / `closeAnimation: 200ms EaseInOut` | ⚠️ **近似，非等价** |
| 遮罩 `Column.onClick(() => closeXxx())` | `onWillDismiss: () => this.closeXxx()` | ✅（**同时覆盖返回键**） |
| `if (this.showXxx) { this.XxxDialog() }` | `@State @Watch('onShowXxxChanged')` + `open()/close()` | ✅ |
| 卡片：`backgroundColor(sheetGlass)` + `backgroundBlurStyle(Regular, 0.85)` + `border(0.5, manualGlassBorder)` + `shadow({ radius: 48 })` | **`systemMaterial: ImmMaterial.dialog()`** | ✅ 换玻璃（观感不可能像素级一致） |

> ⚠️ **表中 `offset.dy = -110` 不是全局常量，必须按宿主页面「底部实际占位」逐页推算**（2026-09-12 的教训）。
> `-110` 只适用于「底部只有一层悬浮栏」的页面：悬浮栏底距 30 + 高 66 → 占「距底 30~96」，
> `-110` 时卡片底边落在悬浮栏上方 14vp。宿主底部每多叠一层，`dy` 就得相应加大：
>
> | 宿主页面 | 底部占位（距底 vp） | 弹窗 `dy` | 卡片底边落在 |
> |---|---|---|---|
> | 收藏页（置顶确认 §6.4 / 批量删除 §6.5）、进吧页（一键签到 §6.1 / 关注吧长按菜单 §6.3） | 悬浮栏 30~96 | `-110` | 悬浮栏上方 14vp |
> | **帖子详细页**（跳转官方贴吧 §6.15） | 悬浮栏 30~96 **+ 排序胶囊行 96~142**（钮体本体 104~138） | **`-140`** | 排序胶囊钮体上方 2vp（紧贴但不压字） |
>
> 教训来源：帖子详细页初版照搬 `-110`，卡片正好压在「正序 / 只看全部」两枚胶囊上（用户真机反馈）；
> 先取安全值 170（钮体上方 28vp），用户复看后指定收到 **140**（紧凑贴合）。
> 通式：`dy ≈ 宿主底部最上层元素的顶边 + 余量`，余量取 2（用户指定紧凑）~ 28（默认安全）vp。

### 4.4 卡内必须删掉的五项

官方明确 `systemMaterial` **会接管容器的 `backgroundColor` / `backgroundBlurStyle` / `backgroundEffect` / `borderColor` / `borderWidth` / `shadow`**。

所以卡片根节点上这五项**全部删除**：

```diff
- .backgroundColor(Theme.sheetGlass(this.isDark))
- .border({ width: 0.5, color: Theme.manualGlassBorder() })
- .backgroundBlurStyle(BlurStyle.Regular, { scale: 0.85 })
- .shadow({ radius: 48, color: '#3D000000', offsetY: 18 })
```

保留：`.width('100%')`、`.padding(...)`、圆角由 `options.cornerRadius` 管（卡内不用再写）。

> 这也顺带满足了官方功耗约束「同一子树只在最外层设一次材质、不要叠 `backgroundBlurStyle`/自定义 `shadow`」。

### 4.5 点遮罩 / 返回键：靠 `onWillDismiss` 而不是 `autoCancel`

**注册了 `onWillDismiss` 之后，点击遮罩 / 返回键 / 侧滑都不会自动关闭**，由回调决定是否调 `action.dismiss()`。

这正好用来实现「进行中=中断任务且不关闭；结束后=关闭」这类语义：回调里只调自己的业务方法（`closeSignAll()`），**不主动调 `action.dismiss()`**；业务方法内部把 `showSignAll = false` 一置，`@Watch` 就会 `controller.close()`。

---

## 5. 宿主选型表（不是所有浮层都该用 CustomDialog）

| 原浮层形态 | 目标官方宿主 | 材质字段 |
|---|---|---|
| 居中 / 贴底**卡片弹窗** | `CustomDialog` | `CustomDialogControllerOptions.systemMaterial` |
| **底部抽屉 / 半模态** | `bindSheet`（半模态转场，属 A 档） | `SheetOptions.systemMaterial` |
| 轻提示 / 吐司 | `promptAction.showToast` | `ShowToastOptions.systemMaterial` |
| 下拉菜单 / 长按菜单 | `bindMenu` / 菜单控制 | `ContextMenuOptions.systemMaterial` |
| 二次确认框 | `AlertDialog` / `promptAction` | `AlertDialogParam.systemMaterial` |
| **顶部吸顶行**（分段胶囊 / 44 圆钮 / 标题） | ✅ **`Navigation` 标题栏** ← **本次新增** | 整行搬进 `.title({ builder: this.XxxBar(), height })` + 槽内子元素各自 `.systemMaterial(...)`（必配 `barStyle: STACK`）—— §6.10 模板 |
| **页面中部玻璃**（吸顶滚动段 / 卡片 / 浮层，位置在页面中部） | ❌ 无官方宿主 | 只能 `backgroundBlurStyle` 真模糊（`Navigation` 槽位只解决**顶部**那一行） |

---

## 6. 本次实测记录（2026-09-10）

**对象**：`ForumsTab.ets` 一键签到弹窗。

| 项 | 内容 |
|---|---|
| 改造前 | 页面 body 顶层 `Stack` 自绘浮层（`@Builder SignAllDialog()`），玻璃 = `Theme.sheetGlass` + `backgroundBlurStyle(BlurStyle.Regular, 0.85)` + 0.5 `manualGlassBorder` 描边 + `shadow radius 48` |
| 改造后 | 顶层 `@CustomDialog struct SignAllDialog` + `CustomDialogController`，玻璃 = `options.systemMaterial = ImmMaterial.dialog()` |
| 结果 | ✅ 构建通过；材质正常渲染（不再是 out of scope） |
| 几何 | 宽度 / 圆角 / 内边距 / 遮罩 / 底部锚点 / 文案 / 字号 / 按钮尺寸**逐项对齐**（见 §4.3） |
| 调用点 | 零改动（`this.showSignAll = x` 全部保留，靠 `@Watch` 桥接） |

**代码索引**：

| 位置 | 内容 |
|---|---|
| `common/Theme.ets` | `_matDialog` / `ensureDialog()` / `ImmMaterial.dialog()` |
| `pages/ForumsTab.ets` | 顶层 `@CustomDialog struct SignAllDialog`（原 `@Builder` 内容迁入） |
| `pages/ForumsTab.ets` | `@State @Watch('onShowSignAllChanged') showSignAll` |
| `pages/ForumsTab.ets` | `signAllDialogController` + `onShowSignAllChanged()` + `dialogCardWidth()` |

**同时删除的残留**：原 `@Builder SignAllDialog()`、`signAllPercent()`、`signingLabel()`、`build()` 里的浮层调用点。

### 6.2 追加修改：弹窗内按钮挂材质（2026-09-10，真机确认生效）

**对象**：`SignAllDialog` 卡内三个按钮 —— 主按钮「后台签到」、次按钮「停止签到」、结果态「知道了」。

| 项 | 内容 |
|---|---|
| 改动前 | 按钮只有实底 `backgroundColor` + 自定义 `shadow`，**无材质** |
| 改动后 | 按钮追加 `.systemMaterial(...)`：主按钮 `ImmMaterial.accent(isDark)`（THIN + 品牌赋色 + interactive）；次按钮 /「知道了」`ImmMaterial.cardAction()`（THIN + interactive） |
| 结果 | ✅ **真机生效，无 `out of scope`**；观感「很满意」（2026-09-10 用户确认） |
| 关键 | 按钮上 `systemMaterial` 与**半透明** `backgroundColor` + 自定义 `shadow` **三者共存**，叠出「按钮抬起于玻璃卡之上」的层次 |

**写法（可直接复制）**：

```ts
// 主按钮：品牌蓝 + 材质 + 品牌色浮起阴影
Button() { Text('后台签到').fontSize(fs(15, this.fontScale)).fontWeight(FontWeight.Medium).fontColor(Color.White) }
  .layoutWeight(1)
  .height(44)
  .systemMaterial(ImmMaterial.accent(this.isDark))            // THIN + materialColor 品牌蓝 + interactive
  .backgroundColor('#CC3173FF')                               // ⚠️ 必须带透明度（见下「前提」）
  .borderRadius(Radius.full)
  .shadow({ radius: 14, color: this.isDark ? '#663173FF' : '#4D3173FF', offsetY: 4 })

// 次按钮：中性玻璃 + 材质 + 中性轻投影
  .systemMaterial(ImmMaterial.cardAction())                   // THIN + interactive
  .backgroundColor(this.isDark ? '#B31B1E24' : '#B3FFFFFF')   // ⚠️ 必须带透明度
  .shadow({ radius: 10, color: this.isDark ? '#4D000000' : '#1F101824', offsetY: 3 })
```

**前提：底色必须带透明度。** 官方明确「`materialColor` 传不透明色会完全遮挡材质滤镜」——
同一条也适用于 Button 的 `backgroundColor`：`#CC3173FF` / `#B3FFFFFF` / `#B31B1E24` 都是半透明，
所以既透出材质、又保住品牌色与「实底按钮」的观感；换成不透明色会看不到玻璃。

**与 §4.4「材质接管五项」不冲突的解释**：§4.4 那条只对**挂载材质的那一个节点**成立。
本次材质挂在 **Button 自身**，Button 的 `backgroundColor` / `shadow` 是它自己的样式 → **叠加而非互斥**。

**代码索引**：

| 位置 | 内容 |
|---|---|
| `pages/ForumsTab.ets` | 主按钮：`.systemMaterial(ImmMaterial.accent(this.isDark))` + `.backgroundColor('#CC3173FF')` + `.shadow({ radius: 14, ... })` |
| `pages/ForumsTab.ets` | 次按钮 /「知道了」：`.systemMaterial(ImmMaterial.cardAction())` + `.backgroundColor('#B3FFFFFF' / '#B31B1E24')` + `.shadow({ radius: 10, ... })` |

### 6.3 第二处迁移：关注吧长按菜单（2026-09-10）

**对象**：`ForumsTab.ets` 的 `ForumMenuDialog`（进吧页长按关注吧卡片弹出：标题 + 已置顶标签 + 置顶/取消置顶 + 取关 + 取消按钮）。

| 项 | 内容 |
|---|---|
| 改造前 | 页面 body 顶层 `Stack` 自绘浮层（`@Builder ForumMenuDialog()`），玻璃 = `sheetGlass` + `backgroundBlurStyle(Regular, 0.85)` + 0.5 描边 + `shadow radius 48` |
| 改造后 | 顶层 `@CustomDialog struct ForumMenuDialogCard` + `forumMenuController`，玻璃 = `options.systemMaterial = ImmMaterial.dialog()` |
| 结果 | ✅ 构建通过（`BUILD SUCCESSFUL`）；待真机确认材质渲染 |
| 几何 | 宽度 `dialogCardWidth()` / 圆角 32 / 底距 110 / 遮罩 `#06000000` 全部对齐；卡内文案、字号、菜单行内边距、分隔线、按钮尺寸**一行未改** |
| 调用点 | 长按回调里仍是 `this.showForumMenu = true`，靠 `@Watch('onShowForumMenuChanged')` 驱动 `open()` |

**这次新踩到、值得记的一点：`FollowItem | null` 不能直接 `@Link` 进 `@CustomDialog`。**

原浮层直接读 `this.forumMenuTarget?.forumName` 与 `this.isForumPinned(...)`；
弹窗结构体只能收「值」，所以宿主侧加了两个**展示快照**：

```ts
@State forumMenuName: string = '';        // 吧名
@State forumMenuPinned: boolean = false;  // 打开那一刻是否已置顶

// 长按回调：先写快照，再置显隐（@Watch 立即 open，避免首帧读到旧吧名）
this.forumMenuTarget = forum;
this.forumMenuName = forum.forumName;
this.forumMenuPinned = this.isForumPinned(forum.forumName);
this.showForumMenu = true;
```

> **规则**：宿主用 `Xxx | null` 做「当前操作对象」是常见写法，但 `@Link` 不接受可空对象。
> 解法统一是「拆成基本类型快照 + 在打开前写入」，不要试图把整个对象传进去。

**卡内「取消」按钮**：按 §6.2 给了材质（`ImmMaterial.cardAction()` + `#B3FFFFFF`/`#B31B1E24` + 轻投影），
与一键签到弹窗的次按钮同源 —— 原 `Theme.bgCard()` 是**不透明**色，会盖掉材质，故必须换半透明底。

**代码索引**：

| 位置 | 内容 |
|---|---|
| `pages/ForumsTab.ets` | 顶层 `@CustomDialog struct ForumMenuDialogCard` |
| `pages/ForumsTab.ets` | `@State @Watch('onShowForumMenuChanged') showForumMenu` + `forumMenuName` / `forumMenuPinned` 快照 |
| `pages/ForumsTab.ets` | `forumMenuController` + `onShowForumMenuChanged()` |
| `pages/ForumsTab.ets` | `build()` 里原 `if (this.showForumMenu) { this.ForumMenuDialog() }` 已删除 |

### 6.4 第三处迁移：收藏页置顶确认弹窗（2026-09-10）

**对象**：`Favorite.ets` 的 `PinConfirmDialog`（收藏页长按收纳夹 / 帖子 → 「置顶收纳夹」/「取消置顶」二次确认）。

| 项 | 内容 |
|---|---|
| 改造前 | 页面 body 顶层 `Stack` 自绘浮层（`@Builder PinConfirmDialog()`），玻璃 = `sheetGlass` + `backgroundBlurStyle(Regular, 0.85)` + 0.5 描边 + `shadow radius 48` |
| 改造后 | 顶层 `@CustomDialog struct PinConfirmDialogCard` + `pinConfirmController`，玻璃 = `options.systemMaterial = ImmMaterial.dialog()` |
| 结果 | ✅ 构建通过（`BUILD SUCCESSFUL`）；待真机确认材质渲染 |
| 几何 | 宽度 `dialogCardWidth()` / 圆角 32 / 底距 110 / 遮罩 `#06000000` 全部对齐；标题、正文、按钮尺寸字号**一行未改** |
| 调用点 | `requestPinFolder()` 里仍是 `this.showPinConfirm = true`，靠 `@Watch('onShowPinConfirmChanged')` 驱动 `open()` |
| 按钮 | 按 §6.2 挂材质：取消 `ImmMaterial.cardAction()` + `#B3FFFFFF`/`#B31B1E24`；确认 `ImmMaterial.accent(isDark)` + `#CC3173FF` + 品牌色投影 |

**这次新踩到、必须记住的一点：一个 `@Watch` 只能挂一个 —— 桥接会顶掉原有 `@Watch`。**

`showPinConfirm` 原本是 `@State @Watch('syncBackState')`（BUG-01 回退链要靠它同步 `favCanGoBack`）。
要加 `open()/close()` 桥接就得**替换**而不是追加（ArkTS 不允许同一状态变量挂两个 `@Watch`）：

```ts
// ❌ 编译不过 / 只有一个生效
@State @Watch('syncBackState') @Watch('onShowPinConfirmChanged') showPinConfirm: boolean = false;

// ✅ 替换掉，在桥接回调里「代劳」原回调
@State @Watch('onShowPinConfirmChanged') showPinConfirm: boolean = false;

onShowPinConfirmChanged(): void {
  this.syncBackState();          // ← 原来挂在 showPinConfirm 上的 @Watch，这里补回来
  if (this.showPinConfirm) {
    this.pinConfirmController.open();
  } else {
    this.pinConfirmController.close();
  }
}
```

> **迁移前先扫一遍目标状态变量上有没有别的 `@Watch`**。有的话桥接回调必须把它「代调」一遍，否则静默丢功能（本例丢的是系统返回键回退判定，极难发现）。

**第二个差异：文案全部走快照，弹窗内零三元判断。**

§6.3 只快照了「吧名 + 是否置顶」；这里把**三段文案**都在宿主算好：

```ts
const targetPin: boolean = !folder.pinned;
this.pinConfirmTarget = { forumName: folder.forumName, targetPin };
this.pinConfirmTitle = targetPin ? '置顶收纳夹' : '取消置顶';
this.pinConfirmMessage = `确定${targetPin ? '置顶' : '取消置顶'}「${folder.forumName}」吗？`
  + (targetPin ? '置顶后将优先展示在列表最前。' : '');
this.pinConfirmConfirmLabel = targetPin ? '置顶' : '取消置顶';
this.showPinConfirm = true;
```

好处：弹窗结构体里连 `this.pinConfirmTarget?.xxx` 都不出现，**关闭瞬间清空 `pinConfirmTarget` 也不会让关闭动画期间文案变空**。

**第三个顺手收拾：关闭入口收敛。** 原自绘浮层里「遮罩点击」和「取消按钮」各写了一遍
`showPinConfirm = false; pinConfirmTarget = null;`；现在统一成 `closePinConfirm()`，
`onCancel` / `onWillDismiss` / `onBackRequest` / `confirmPin` 四处共用。

**`dialogCardWidth()` 是本文件新增的**（`Favorite.ets` 原先没有）：用 `display.getDefaultDisplaySync()`
换算 vp，需补 `import { display } from '@kit.ArkUI';`。抄自 `ForumsTab.ets`。

**代码索引**：

| 位置 | 内容 |
|---|---|
| `pages/Favorite.ets` | 顶层 `@CustomDialog struct ConfirmDialogCard`（原 `PinConfirmDialogCard`，§6.5 泛化为两弹窗共用） |
| `pages/Favorite.ets` | `@State @Watch('onShowPinConfirmChanged') showPinConfirm` + `pinConfirmTitle` / `pinConfirmMessage` / `pinConfirmConfirmLabel` 快照 |
| `pages/Favorite.ets` | `pinConfirmController` + `dialogCardWidth()` + `onShowPinConfirmChanged()` |
| `pages/Favorite.ets` | `requestPinFolder()` 写快照 / `closePinConfirm()` 统一关闭 / `confirmPin()` |
| `pages/Favorite.ets` | `build()` 里原 `if (this.showPinConfirm) { this.PinConfirmDialog() }` 已删除 |

### 6.5 第四处迁移：收藏页批量删除收藏确认（2026-09-10）

**对象**：`Favorite.ets` 编辑态底栏「删除 (n)」→ 二次确认弹窗。

| 项 | 内容 |
|---|---|
| 改造前 | `AlertDialog.show({ title:'删除收藏', message, alignment: DialogAlignment.Center, primaryButton:'取消', secondaryButton:{ value:'删除', fontColor: Color.Red } })` —— 系统居中弹窗 |
| 改造后 | 复用 §6.4 的 `ConfirmDialogCard` + 新增 `deleteConfirmController`，`danger: true` |
| 位置 | **与置顶弹窗逐项一致**（宽度 `dialogCardWidth()` / 圆角 32vp / 底部锚点 `dy -110` / 遮罩 `#06000000` / 同一 `ImmMaterial.dialog()`）—— 用户要求的「移到与置顶弹窗一样的位置」即由此实现 |
| 结果 | ✅ 构建通过（`BUILD SUCCESSFUL`）；待真机确认 |

**为什么 `AlertDialog` 不算「已经有沉浸光感」**：`AlertDialogParam` 确实有 `systemMaterial` 字段（§5 选型表也这么写），但

1. **不显式传就完全没有材质** —— 本工程改造前那处就是系统默认白底（用户截图可见，玻璃分界明显）；
2. 更关键的是 **AlertDialog 版式被系统写死** —— 标题居中、正文居中、两枚按钮左右平分且带系统分割线，
   既保不住置顶弹窗那种「两枚等分胶囊按钮 + 半透明玻璃底」的观感，也无法做到「与置顶弹窗同一位置、同一几何」；
3. 所以**本工程的二次确认统一走 `CustomDialog` + `ConfirmDialogCard`**，不再使用 `AlertDialog`。

**结构体泛化（本次的复用做法）**：把 §6.4 的 `PinConfirmDialogCard` 抽成通用 `ConfirmDialogCard`：

```ts
@CustomDialog
struct ConfirmDialogCard {
  controller?: CustomDialogController;
  @Link isDark: boolean;
  @Link fontScale: number;
  @Link dialogTitle: string;      // 标题
  @Link dialogMessage: string;    // 正文
  @Link confirmLabel: string;     // 主按钮文案
  /**
   * 主按钮是否走危险色。常量语义（同一弹窗实例内不会变化），故用**普通成员**而非 @Link：
   * 由 controller builder 直接传字面量 `danger: true`。
   */
  danger: boolean = false;
  onCancel: () => void = () => {};
  onConfirm: () => void = () => {};
  // 主按钮：this.danger ? ImmMaterial.danger(isDark) + #CCF5222D
  //                     : ImmMaterial.accent(isDark) + #CC3173FF
}
```

> **判断「该共用还是该新建」**：几何与交互完全同构、只有文案 / 配色 / 数据源不同 → **共用一个 struct**，
> 差异做成参数（**文案走 `@Link` 快照，配色走普通成员常量**）。宿主侧各自持有**独立的 controller**
> （一个 controller 只能驱动一个弹窗实例），两个弹窗互不干扰、可同时存在。
> 若几何不同（例如要换成 `bindSheet` 抽屉形态），则应新建 struct，**不要往模板里塞布局分支**。

**新增主题槽位 `ImmMaterial.danger(isDark)`**（`common/Theme.ets`）：与 `accent` **严格同构**，
只把 `materialColor` 从品牌蓝换成危险红 `Theme.danger()` = `#F5222D`：

| 方法 | style | materialColor（light / dark） | 用途 |
|---|---|---|---|
| `accent(isDark)` | THIN + interactive | `#4C3173FF` / `#663173FF` | 品牌主按钮 |
| **`danger(isDark)`** | THIN + interactive | `#4CF5222D` / `#66F5222D` | **危险主按钮（删除 / 清空等）** |

配合同步的底色与阴影：`backgroundColor('#CCF5222D')`、`shadow(#4DF5222D / #66F5222D)`。

> ⚠️ **不要把红底直接挂到 `accent()` 上** —— accent 的 `materialColor` 会赋品牌蓝，与红底叠成脏色。
> 危险色必须有自己的材质实例（材质按 `materialColor` 分档缓存，不能复用 accent 的）。

**回退链同步（最容易漏的一步）**：删除确认弹窗是「编辑态」的子层，`showDeleteConfirm` 必须三处都补齐：

1. 加进 `syncBackState()` 的 `canBack` 表达式；
2. 在 `onShowDeleteConfirmChanged()` 里调 `this.syncBackState()`（否则开关弹窗时 `favCanGoBack` 不刷新）；
3. 在 `onBackRequest()` 的优先级链里排位（放在 `showPinConfirm` 之后、`showBackupDialog` 之前）。

漏掉任何一条，系统返回键在弹窗打开时就会直接退页面（而不是先关弹窗）。

**代码索引**：

| 位置 | 内容 |
|---|---|
| `pages/Favorite.ets` | 顶层 `@CustomDialog struct ConfirmDialogCard`（原 `PinConfirmDialogCard` 泛化，两弹窗共用） |
| `pages/Favorite.ets` | `@State @Watch('onShowDeleteConfirmChanged') showDeleteConfirm` + `deleteConfirmTitle` / `deleteConfirmMessage` / `deleteConfirmConfirmLabel` 快照 |
| `pages/Favorite.ets` | `deleteConfirmController`（`danger: true`）+ `onShowDeleteConfirmChanged()` |
| `pages/Favorite.ets` | `requestDeleteSelected()` 写快照 / `closeDeleteConfirm()` / `confirmDeleteSelectedDialog()` |
| `pages/Favorite.ets` | `syncBackState()` 补 `\|\| this.showDeleteConfirm`；`onBackRequest()` 补分支 |
| `common/Theme.ets` | `ImmMaterial.danger(isDark)` + `ensureDangerDark/Light()` + `_matDangerDark/Light` 缓存 |

### 6.6 第五处迁移：收藏页分类管理菜单（2026-09-10）

**对象**：`Favorite.ets` 自定义分类卡片右上角菜单（信息行「分类名 + N 个收藏」+「重命名分类」+「删除分类」+「取消」）。

| 项 | 内容 |
|---|---|
| 改造前 | 页面 body 顶层 `Stack` 自绘浮层（`@Builder CategoryManageSheet()`），玻璃 = `sheetGlass` + `backgroundBlurStyle(Regular, 0.85)` + 0.5 描边 + `shadow radius 48` |
| 改造后 | 新建顶层 `@CustomDialog struct CategoryManageDialog` + `categoryManageController`，玻璃 = `options.systemMaterial = ImmMaterial.dialog()` |
| 位置 | 几何与置顶/删除确认弹窗逐项一致（宽度 `dialogCardWidth()` / 圆角 32vp / 底部锚点 `dy -110` / 遮罩 `#06000000`）→ 三个弹窗出现在屏幕同一处 |
| 结果 | ✅ 构建通过（`BUILD SUCCESSFUL`）；待真机确认 |

**这是目前内容最复杂的一处迁移**（信息行 + 条件渲染的原地编辑态 + 两行菜单 + 取消按钮），踩到 3 个新坑：

#### 坑 1：`@Builder` 不能跨 struct 调用

原浮层内容用到宿主的 `CategoryCover` / `ActionRow` / `CardDivider` 三个 `@Builder`。搬进新 struct 后 **`this.xxx()` 直接编译不过**（`Property 'CategoryCover' does not exist on type 'CategoryManageDialog'`）。

两条出路：

| 方案 | 做法 | 结论 |
|---|---|---|
| **复制**（本次采用） | 在新 struct 内定义同名 `@Builder` 方法，宿主那份继续供分类卡片使用 | 内容自包含、状态走 `@Link`，与 §6.4 / §6.5 同构，**零风险**；代价是 3 个小 builder 重复约 60 行 |
| `@BuilderParam` 注入 | struct 声明 `@BuilderParam content: () => void`，宿主传 `content: this.CategoryManageSheetContent` | ⚠️ **不推荐**：`builder:` 是**属性传参**（不是尾随闭包），`@BuilderParam` 内部执行时 `this` 指向**子组件**，宿主状态全取不到；`bind(this)` 未见官方支持 |

> **判据**：卡内元素只被这一个弹窗用 → 复制进 struct；被多个弹窗用 → 抽**全局 `@Builder function`**（参数化 `isDark` / `fontScale`）。
> 本页历史情况：宿主 `CardDivider` 曾被 `BackupDialog` / `ExportDialog` 共用，故两边都留了一份；
> 2026-09-10 两弹窗先后迁成 `@CustomDialog`（§6.11 / §6.12）后，卡内分隔线各自复制为 `CardDividerLine`，
> 宿主那份已无调用点，**已删除**（收尾时记得回查这类"只被已删浮层使用"的残留 `@Builder`）。

#### 坑 2：可空对象不能 `@Link`，但「对象换新后弹窗内要实时刷新」

`manageTargetCat: FavCategory | null` 不能 `@Link`（§6.3）。而「原地重命名」成功后宿主会**重指向新对象**（`this.manageTargetCat = updated`），弹窗信息行的名称必须跟着变。

解法 = **基本类型快照 + `@Watch` 桥接**：

```ts
// 宿主：对象挂 @Watch，回调里把对象拆成快照
@State @Watch('onManageCatChanged') manageTargetCat: FavCategory | null = null;
@State manageCatName: string = '';
@State manageCatCover: string = '';
@State manageCatIcon: string = '';
@State manageCatCount: number = 0;

onManageCatChanged(): void {
  const cat = this.manageTargetCat;
  if (!cat) { return; }   // ← 见坑 3
  this.manageCatName = cat.name;
  this.manageCatCover = cat.cover;
  this.manageCatIcon = cat.icon;
  this.manageCatCount = this.categoryCountOf(cat.id);
}
```

弹窗侧全部 `@Link` 这些快照即可 —— 宿主换对象 → 快照更新 → 弹窗刷新，链路全自动。

#### 坑 3：关闭瞬间清空对象，会让关闭动画期间卡内内容变空

`closeCategoryManage()` 会 `manageTargetCat = null`（触发快照清空）。而弹窗关闭动画还有 200ms，这期间卡片仍在渲染 —— 信息行名称/数量会先消失再飞走，很跳。

**解法**：`@Watch` 回调里 `cat` 为 null 时**直接 return**，保留上一次快照（`@Link` 值不变 → 动画期间内容稳定）。
这条是 §6.4「文案走快照」的延伸：**快照不只要在打开前写好，还要在关闭时不被清掉**。

#### 其他要点

- **编辑态直接 `@Link` 宿主状态**：`renameMode: $categoryRenameMode`、`inputValue: $categoryInputValue`（布尔 / 字符串可 `@Link`）。这样宿主 `commitCategoryRename()` / `cancelCategoryRename()` **一行都不用改**（读写的是同一份数据）。
- **`@Watch` 顶替**（第三次遇到）：`showCategoryManage` 原挂 `@Watch('syncBackState')`，换成 `@Watch('onShowCategoryManageChanged')` 后须在回调里代调 `syncBackState()`。
- **`@Watch` 回调须 public**（与工程既有写法一致，见 §4.2 注）。
- **卡内按钮**按 §6.2 挂材质：取消 / 取消重命名 = `ImmMaterial.cardAction()` + `#B3FFFFFF` / `#B31B1E24`；保存 = `ImmMaterial.accent()` + `#CC3173FF`。原来的 `Theme.bgCard()`（不透明）与 `Theme.brand()` 会**完全盖掉材质**（§8 坑位 11）。
- **`TextInput` 原地切换**：`defaultFocus(true)` 在系统弹窗内正常；键盘弹起由系统避让（弹窗整体上移），无需手写。
- **两级弹窗时序**：「删除分类」→ 关本弹窗 → `setTimeout(300)` 再弹确认框。系统弹窗可叠加，300ms 足够覆盖 200ms 关闭动画。

**代码索引**：

| 位置 | 内容 |
|---|---|
| `pages/Favorite.ets` | 顶层 `@CustomDialog struct CategoryManageDialog`（信息行 / 菜单行 / 取消按钮 + 3 个内联 `@Builder`） |
| `pages/Favorite.ets` | `@State @Watch('onShowCategoryManageChanged') showCategoryManage` + `manageCatName` / `manageCatCover` / `manageCatIcon` / `manageCatCount` 快照 |
| `pages/Favorite.ets` | `@State @Watch('onManageCatChanged') manageTargetCat`（唯一真源 → 快照桥接） |
| `pages/Favorite.ets` | `categoryManageController` + `onShowCategoryManageChanged()` + `onManageCatChanged()` |
| `pages/Favorite.ets` | `manageCategory()` 写快照 / `closeCategoryManage()` 统一关闭 / `removeCategoryFromDialog()` |
| `pages/Favorite.ets` | `build()` 里原 `if (this.manageTargetCat) { this.CategoryManageSheet() }` 与整个 `@Builder CategoryManageSheet()` 已删除 |

### 6.7 第六处迁移：收藏页「删除分类」确认（2026-09-10）

**对象**：分类管理菜单里点「删除分类」后的二次确认。

| 项 | 内容 |
|---|---|
| 改造前 | `AlertDialog.show()`（系统**白底**居中弹窗，无材质、版式写死）—— 与刚关掉的玻璃菜单卡观感割裂 |
| 改造后 | 复用 §6.5 的 `ConfirmDialogCard` + `danger: true`，新增一组文案快照 + `removeCatConfirmController` |
| 位置 | 与前三个弹窗逐项一致（同一 `dialogCardWidth()` / 圆角 32 / 底部锚点 dy -110 / `ImmMaterial.dialog()` / 危险红主按钮） |
| 结果 | ✅ 构建通过；至此**全工程再无 `AlertDialog` 调用**（`ForumsTab.ets` 仅剩注释里提到 `AlertDialogParam`） |

**这次是纯套模板**（§6.5 的迁移清单直接复用，无新坑），但有三点值得记：

1. **`ConfirmDialogCard` 现为三处共用**：置顶（accent 蓝）/ 批量删除收藏（danger 红）/ 删除分类（danger 红）。加新点位只需「一组文案快照 + 一个 controller + `syncBackState` / `onBackRequest` 各补一行」，**不要**再复制模板。
2. **文案快照不需要 `@Watch` 桥接**：目标对象（`removeCatTarget`）只用于确认时取 `id`，弹窗本身只渲染字符串快照 —— 在 `requestRemoveCategory()` 里一次算好即可（对比 §6.6 坑 2「对象换新需实时刷新」的场景才需要 `@Watch`）。
3. **两级弹窗的 300ms 延时保留**：`removeCategoryFromDialog()` 先关菜单卡（200ms 关闭动画）再延时弹确认卡，避免两张卡在同一位置重叠。系统弹窗虽支持叠加，但同位置叠卡观感很差。

**代码索引**：

| 位置 | 内容 |
|---|---|
| `pages/Favorite.ets` | `@State @Watch('onShowRemoveCatConfirmChanged') showRemoveCatConfirm` + `removeCatConfirmTitle` / `removeCatMessage` / `removeCatConfirmLabel` 快照 + `removeCatTarget` |
| `pages/Favorite.ets` | `removeCatConfirmController`（`danger: true`）+ `onShowRemoveCatConfirmChanged()` |
| `pages/Favorite.ets` | `requestRemoveCategory()` 写快照 / `closeRemoveCatConfirm()` / `confirmRemoveCategoryDialog()` |
| `pages/Favorite.ets` | `syncBackState()` 补 `\|\| this.showRemoveCatConfirm`；`onBackRequest()` 补分支 |

### 6.8 第七处迁移：收藏页「移入分类」抽屉（2026-09-10）

**对象**：编辑态底栏「移入分类」→ 底部抽屉（标题行 + 分类勾选列表 + 完成按钮）。

| 项 | 内容 |
|---|---|
| 改造前 | 页面 body 顶层自绘浮层（`@Builder MovePanel()`）：全屏遮罩 + 62% 高底部面板，玻璃 = `Theme.sheetGlass` + `backgroundBlurStyle(Regular, 0.85)` + 0.5 描边 + `shadow radius 24` |
| 改造后 | **系统半模态 `bindSheet`**（本工程**首次**引入该 API），玻璃 = `SheetOptions.systemMaterial = ImmMaterial.sheet()` |
| 与前六处的差别 | 前六处（含同页的置顶 / 删除 / 分类管理）全是「居中或贴底**卡片**」→ `CustomDialog`；只有本处是「**底部抽屉**」（满宽贴边、62% 高、只圆顶部、可下滑关闭）→ 按 §5 选型表走 `bindSheet` |
| 结果 | ✅ 构建通过（`BUILD SUCCESSFUL`，无新增 WARN）；待真机确认 |

**关键：形态决定宿主，不是「统一都换 `CustomDialog`」**。§6.6（分类管理菜单）与本处（移入抽屉）在同一页面、同样是底部浮层，却刻意选了两种宿主：

| | 分类管理菜单（§6.6） | 移入分类抽屉（本节） |
|---|---|---|
| 原形态 | 贴底**卡片**（宽 `calc(100%-48vp)` / 四角 32 / 底部锚点 dy -110） | **抽屉**（满宽贴边 / 高 62% / 只圆顶部 24 / 可下滑关闭） |
| 宿主 | `CustomDialog` | `bindSheet` |
| 理由 | `bindSheet` 会把它变成抽屉，破坏原几何 | 原形态本就是抽屉，`bindSheet` 天然吻合；反之 `CustomDialog` **做不到**「满宽贴边 + 只圆顶部两角」（`cornerRadius` 是四角统一值，而 `customStyle: true` 又会让材质失效） |

**几何对齐表（自绘抽屉 → `SheetOptions`）**：

| 原自绘写法 | 现 `SheetOptions` | 说明 |
|---|---|---|
| 全屏 `Stack` + `Column.backgroundColor('#66000000')` 遮罩 | `maskColor: '#66000000'` | ✅ 本处遮罩比弹窗深（弹窗是 `#06000000`），照抄原值 |
| `.height('62%')` | `height: '62%'` | ⚠️ 用 **`Length` 字符串**而非 `SheetSize`：枚举只有 MEDIUM(50%) / LARGE(90%) / FIT_CONTENT，要保住 62% 这个非标准档位只能给百分比 |
| `.borderRadius({ topLeft: 24, topRight: 24 })` | `radius: { topLeft: 24, topRight: 24 }` | ✅ 联合类型 `LengthMetrics \| BorderRadiuses` 接受对象字面量（编译器已确认通过） |
| 自绘描边 / `backgroundBlurStyle` / `shadow` | `systemMaterial: ImmMaterial.sheet()` | 容器四项交给材质（§4.4），不再自绘 |
| 无拖拽条、无系统关闭按钮 | `dragBar: false`、`showClose: false` | 原设计靠「点遮罩 / 下滑 / 返回键」关闭 |
| `.expandSafeArea([SYSTEM], [BOTTOM])` | 无需 | 半模态自带安全区处理 |
| `transition`（遮罩淡入 + 面板上滑 420） | 系统半模态转场 | ⚠️ 近似非等价（同 §7 偏差 ④） |
| `.zIndex(20)` | 系统半模态自带层级 | ✅（可删） |

**`$$` 双向绑定（本次的新招）**：

```ts
.bindSheet($$this.showMovePanel, this.MovePanelContent(), { /* ... */ })
```

- 用户**下滑手势关闭**时，系统会**回写** `showMovePanel = false` —— 这既让 `@Watch('syncBackState')` 自动刷新 `favCanGoBack`，也避免「状态残留 `true` → 下次打不开」。
- 对比 `CustomDialog`：那边没有 `$$`（只能 `controller.open()/close()`），所以靠 `onWillDismiss` + 单一 `closeXxx()` 收敛关闭入口；`bindSheet` 有 `$$` 更省事。
- 另加 `onDisappear: () => { this.showMovePanel = false; }` 作保险（冗余但无害：已是 `false` 时不触发变更）。
- 挂载点是 `build()` 的**根 `Stack`**（页面必然存在），不再需要 `if (this.showMovePanel) { this.MovePanel() }` 这种条件挂载。

**材质槽位复用**：`Theme.ets` 新增 `ImmMaterial.sheet()`，实现直接 `return ensureDialog()` —— 半模态与弹窗卡同为「REGULAR 卡片档」，材质按 `style` 分档缓存，参数相同就没必要再建实例（该方法只是语义别名）。

**卡内元素一并材质化**（§9 注）：条目 `Row` 与「完成」按钮都挂材质 + 半透明底（`#B31B1E24` / `#B3FFFFFF`）。原来的 `Theme.bgCard()` 是**不透明**卡片色，在玻璃面板上会叠出白块（§8 坑 6 的同类问题）。44×44 图标圆底**保留** `bgCard`（作图标承托底，改动收益不成正比）。

**代码索引**：

| 位置 | 内容 |
|---|---|
| `pages/Favorite.ets` | `@Builder MovePanel()` → `MovePanelContent()`（删掉遮罩 / 玻璃 / 圆角 / 动画外壳，只留内容本体） |
| `pages/Favorite.ets` | `build()` 根 `Stack` 挂 `.bindSheet($$this.showMovePanel, this.MovePanelContent(), {...})`；删除原条件挂载 |
| `pages/Favorite.ets` | 条目 `Row` / 「完成」`Button` 挂 `ImmMaterial.cardAction()` / `accent()` + 半透明底 |
| `common/Theme.ets` | `ImmMaterial.sheet()`（复用 `ensureDialog()` 实例） |

### 6.9 第八处迁移：五处「排序下拉」统一改 `bindMenu`（2026-09-10）

**对象**（一次改五处，结构完全同构）。用户点名的是前三处（收藏页 / 进吧页 / 个人信息页）；改完顺带发现后两处是**同款残留**（源码注释里就写着「本地复刻收藏页 `SortMenuPanel`」），一并按同一模板改掉，否则观感会不一致：

| 文件 | 菜单 | 触发钮 | 项数 / 菜单项宽 |
|---|---|---|---|
| `Favorite.ets` | `SortMenuPanel` | TopBar 三种形态共用的 `⇅` 圆钮 | 5 项 / 210 |
| `ForumsTab.ets` | `ForumSortDialog` | TopBar `⇅` 圆钮 | 4 项 / 210 |
| `UserProfile.ets` | `PostSortMenu` | TopBar `⇅` 圆钮（仅帖子 Tab） | 2 项 / 180 |
| `FollowList.ets` | `SortMenuPanel` | TopBar `⇅` 圆钮 | 4 项 / 210 |
| `BlacklistManager.ets` | `SortMenuPanel` | TopBar `⇅` 圆钮 | 4 项 / 210 |

| 项 | 内容 |
|---|---|
| 改造前 | 页面 body 顶层自绘浮层：**全屏透明 Column 遮罩**（点空白关闭）+ `position({ top: 100, right: 16 })` 的玻璃面板（`sheetGlass` + `border` + `backgroundBlurStyle(Regular, 0.85)` + `shadow`），弹出动画 `translate(y:-12) + opacity` |
| 改造后 | 系统 **`bindMenu`**（官方「菜单类」槽位），材质 = `MenuOptions.systemMaterial`（继承自 `ContextMenuOptions.systemMaterial`，since 26.0.0） |
| 结果 | ✅ 构建通过（`BUILD SUCCESSFUL`）；顺带**少三条 `Material inactive: out of scope`** WARN（`UserProfile` / `FollowList` / `BlacklistManager` 三处原自绘面板上那份本就无效的 `systemMaterial` 随改造删除） |

**关键经验 1：`bindMenu` 的锚定基准是「触发组件」，不是「屏幕坐标」**

原设计是「屏幕右上角固定」（`right: 16`），而三处排序钮**都不在 TopBar 最右端**（右侧还有编辑 / 搜索 / 黑名单 / 深色钮）→ 直接把 `bindMenu` 挂按钮 + `Placement.BottomRight` 会让菜单**整体左移约 50vp**，与原位置对不上。

解法：**1×1 隐形锚点** —— 在 `build()` 里原浮层所在的位置放一个不可见组件，把 `bindMenu` 挂在它上面：

```ts
Row()
  .width(1)
  .height(1)
  .position({ top: 99, right: 16 })      // ← 原面板坐标（99 + 1 = 100，见下方 targetSpace）
  .hitTestBehavior(HitTestMode.None)     // 不吃触摸；弹出仍由 TopBar 排序钮发起
  .bindMenu($$this.showSortMenu, this.SortMenuContent(), {
    placement: Placement.BottomRight,    // 菜单右下角对齐锚点右下角 → 右边缘精确落回「屏幕右 16」
    targetSpace: LengthMetrics.vp(0),    // 默认间距会把菜单再往下推 ~8vp，置 0 才等于原 top:100
    systemMaterial: ImmMaterial.menu()
  })
```

- `Placement.BottomRight` = 菜单**右下角**对齐锚点**右下角** → 锚点右边缘 = 屏幕右 16 时，菜单右边缘也正好是 16 ✅
- `targetSpace`（`ContextMenuOptions`，since 26.0.0）是「菜单与目标组件的间距」，默认非 0 → 必须显式 `LengthMetrics.vp(0)`，菜单顶边才 = 锚点底边（`top 99 + height 1`）= 原 `top: 100` ✅
- `LengthMetrics` 从 `@kit.ArkUI` 导入（三个页面本就 import 了该 kit，加个名字即可），三处都已在工程内验证可用
- 锚点 1×1 + `hitTestBehavior(HitTestMode.None)`：不参与视觉、不吃触摸、不影响任何布局

**关键经验 2：菜单外壳全部交给系统，内容只留菜单项**

- **删掉**（自绘外壳）：全屏遮罩 `Column`、`position`、`backgroundColor`、`borderRadius`、`border`、`backgroundBlurStyle`、`shadow`、`zIndex`、`transition`，以及 build 里的 `if (showXxx) { this.XxxMenu() }` 条件挂载。
- **保留**（内容本体）：`Column({ space: 2 })` + 菜单项（宽度 / 内边距 / 选中高亮 `Theme.brand()` / `✓` / 「自定义排序」置灰）—— `@Builder` 改名 `XxxMenuContent()`，`width(210|180)` 与 `padding` **零改动**。

> ⚠️ 系统菜单容器会给内容再套一层自己的内边距 / 圆角 / 阴影，因此菜单**总宽**会比原来的 210 略大（原设计是自绘卡片自带 padding，现在是「内容 + 系统容器」）。这是用系统槽位的固有代价，属 §7 偏差 ④ 一类。

**关键经验 3：`$$` 双向绑定与 `applyXxx` 内置 false 可共存**

- 点菜单项 → `applySortMode()` 内部置 `showSortMenu = false` → `$$` 同步关菜单 ✅
- 点菜单外部 / 按返回键 → 系统关菜单并**回写** `showXxx = false` ✅（与 §6.8 `bindSheet` 同一套路，也是坑 19 的正解）
- 因此**不需要**把这些菜单纳入 `favCanGoBack` 回退链：系统菜单自己消费返回键（原自绘版本同样没纳入，行为一致）

**代码索引**：

| 位置 | 内容 |
|---|---|
| `pages/Favorite.ets` | `build()` 原 `this.SortMenuPanel()` → 隐形锚点 `.bindMenu($$this.showSortMenu, this.SortMenuContent(), {...})` |
| `pages/Favorite.ets` | `@Builder SortMenuPanel()` → `SortMenuContent()`（5 项，只留内容；三种 TopBar 形态共用一个根锚点） |
| `pages/ForumsTab.ets` | `build()` 原 `if (this.showForumSortDialog) { this.ForumSortDialog() }` → 隐形锚点 + `bindMenu`；`@Builder ForumSortDialog()` → `ForumSortMenuContent()`（4 项） |
| `pages/UserProfile.ets` | `build()` 原 `if (this.showPostSortMenu) { this.PostSortMenu() }` → 隐形锚点 + `bindMenu`；`@Builder PostSortMenu()` → `PostSortMenuContent()`（2 项） |
| `pages/FollowList.ets` | `build()` 原 `if (this.showSortMenu) { this.SortMenuPanel() }` → 隐形锚点 + `bindMenu`；`@Builder SortMenuPanel()` → `SortMenuContent()`（4 项）；新增 `import { LengthMetrics } from '@kit.ArkUI'` |
| `pages/BlacklistManager.ets` | 同上（`BlackSortMode` 的 4 项）；新增 `import { LengthMetrics } from '@kit.ArkUI'` |
| `common/Theme.ets` | `ImmMaterial.menu()`（复用 `ensureDialog()` 实例，同 REGULAR 卡片档） |

### 6.10 第九处迁移（**首次「顶部槽位」**）：首页吸顶「推荐 / 关注动态 / 搜索」→ `Navigation` 标题栏（2026-09-10 真机已验）

**对象**：`HomeTab.ets` 顶部吸顶行 —— 「推荐」「关注动态」两颗分段胶囊 + 右侧 44 搜索圆钮
（原 `@Builder HomeHeaderOverlay()`，挂在根 `Stack` 上、`zIndex(15)`，帖子从下方穿过）。

| 项 | 内容 |
|---|---|
| 改造前 | 页面 body 根 `Stack` 里的悬浮层：`Row` + 胶囊 `Theme.segGlass` + `border(0.5, manualGlassBorder)` + `backgroundBlurStyle(Regular/Thin, 0.8/0.85)` + `segGlassShadow` |
| 改造后 | 整行搬进 `Navigation` 的 `.title({ builder: this.HomeTitleBar(), height: 108 })`，玻璃 = **槽内子元素各自** `.systemMaterial(...)` |
| 结果 | ✅ **真机生效**（用户 2026-09-10 确认「已生效」），无 `Material inactive: out of scope` |
| 几何 | 逐项对齐：`top 44 / bottom 20 / 左右 Spacing.lg / space 16 / 胶囊 padding 22+9 / fontSize 16 / 圆钮 44`；**内容让位 `HOME_TOP_PAD = 98` 一行未改** |
| 调用点 | 零改动（胶囊仍是 `selectHomeFeed()` / `showFollowingFeed()`，圆钮仍是 `openSearchFromHome()`） |

**开关式落地（便于一键回退）**：

```ts
// HomeTab.ets 顶部常量
const HOME_OFFICIAL_TITLE_BAR: boolean = true;   // false → 回到改造前的页面主体悬浮层（manualGlass 真模糊）
const HOME_TITLE_BAR_HEIGHT: number = 108;       // 44(状态栏让位) + 44(按钮行高) + 20(底部呼吸)
```

```ts
build() {
  if (HOME_OFFICIAL_TITLE_BAR) {
    Navigation() {
      this.HomeFeedContent()          // 原 build() 根 Stack（两个 feed + 左右滑动手势）抽成 @Builder，两路共用
    }
    .title({ builder: this.HomeTitleBar(), height: HOME_TITLE_BAR_HEIGHT },
      { barStyle: BarStyle.STACK, backgroundColor: Color.Transparent })
    .mode(NavigationMode.Stack)
    .hideTitleBar(false)
    .hideBackButton(true)
    .width('100%').height('100%')
    .backgroundColor(Color.Transparent)
    .clip(false)                       // 不许裁内容：帖子要能从标题栏下穿过
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  } else {
    this.HomeFeedContent()             // 兜底路径：内容层内部仍带 HomeHeaderOverlay()
  }
}
```

```ts
// 槽内子元素：几何、字号、padding 一行未动，只换玻璃
Text('推荐')
  .fontSize(fs(16, this.fontScale))
  .fontWeight(this.homeFeed === HomeFeed.Recommended ? FontWeight.Bold : FontWeight.Medium)
  .fontColor(this.homeFeed === HomeFeed.Recommended
    ? $r('sys.color.font_emphasize') : $r('sys.color.font_primary'))
  .systemMaterial(ImmMaterial.seg(this.homeFeed === HomeFeed.Recommended))   // 选中 REGULAR / 未选中 THIN
  .borderRadius(Radius.full)
  .padding({ left: 22, right: 22, top: 9, bottom: 9 })

Button() { SymbolGlyph($r('sys.symbol.magnifyingglass')).fontColor([$r('sys.color.icon_primary')]) }
  .width(44).height(44)
  .backgroundColor(Color.Transparent)                                        // 清掉 Button 自带品牌蓝填充
  .systemMaterial(ImmMaterial.seg(false))                                    // THIN 中性档（与两胶囊同套材质语言）
  .borderRadius(Radius.full)
```

**三条必须记住的写法**：

1. **七项链式属性一个都不能少**：
   `barStyle: BarStyle.STACK`（**不设就失去沉浸** —— 内容不再延伸到标题栏下；官方原文：延伸至非安全区的前提是「标题栏/工具栏隐藏或置为 STACK」）·
   `hideTitleBar(false)` · `hideBackButton(true)`（本处无返回键；且**不设 `title`/`subTitle` 时标题栏整体不显示**）·
   `mode(NavigationMode.Stack)`（强制单栏，宽屏不被拆成双栏）·
   `.backgroundColor(Color.Transparent)` + `.clip(false)` · `.expandSafeArea([SYSTEM], [TOP, BOTTOM])`。
2. **title options 的 `backgroundColor: Color.Transparent` 必须显式写**：否则标题栏自带底色会压住「从下方穿过的帖子」，失去沉浸观感。
3. **槽内子元素不许再挂** `backgroundColor` / `border` / `backgroundBlurStyle` / `shadow`（同 §4.4 口径）：本处旧写法四项**全部删除**，
   只留 `fontSize / fontWeight / fontColor / borderRadius / padding / onClick`。
   **唯一例外：`Button` 必须补 `.backgroundColor(Color.Transparent)`**（清底 ≠ 着底色，详见下方「圆钮蓝底」注记）。
   文字图标色沿用系统可反色资源（`font_emphasize` / `font_primary` / `icon_primary`）→ 天然满足官方「文字可反色」前提。

**`Theme.ets` 新增材质槽位**（`ImmMaterial.seg(active)` —— **中性不染色**：选中感仍由文字强调色 + 字重承担，与改造前设计一致）：

| 方法 | style | materialColor | interactive | applyShadow | 对齐的旧观感 |
|---|---|---|---|---|---|
| `seg(true)` | REGULAR | 无 | ✅ | ✅ | 旧 `BlurStyle.Regular`（选中） |
| `seg(false)` | THIN | 无 | ✅ | ✅ | 旧 `BlurStyle.Thin`（未选中） |
| `seg(false)`（圆钮复用） | THIN | 无 | ✅ | ✅ | 旧 `BlurStyle.Thin` 圆钮（44） |

> **为什么不用既有的 `tab()` / `tabActive()`**：`tabActive` 自带 `materialColor: '#383173FF' / '#553173FF'`（品牌蓝赋色），
> 会把「去蓝底、选中靠文字强调色 + 字重」的定稿设计改回去。要「只换玻璃、观感不变」就必须用**中性档**。

> **2026-09-10 追加调整（用户要求「槽内三颗材质统一」）**：搜索圆钮由 `control()`（`ULTRA_THIN`，官方最薄档，
> 纯色背景上几乎看不出玻璃层）改用 `seg(false)`（`THIN` 中性档），与两颗胶囊同一套材质语言；
> `interactive` / `applyShadow` / 默认点光源三项与 `control()` 完全一致，几何（44）与 `onClick` 一行未改。
> 另注：`Theme.ets` 中 `ImmMaterial.control()` 的 JSDoc 写「THIN + 按压弹性 + 光感反馈」，实现却是 `ULTRA_THIN`，
> **注释与实现不一致**，以实现口径为准（本条即因该差异导致的「看不见玻璃」观感问题）。

> **圆钮「蓝底」坑（2026-09-10 用户反馈「搜索按钮不要有蓝色底」）**：槽内两颗胶囊是 `Text`，**默认无背景色**；
> 唯独搜索圆钮是 `Button`，而 `Button` 组件**自带品牌蓝默认填充**（`sys.color.comp_background_emphasize`），
> 在 `ULTRA_THIN` 档下几乎被材质压住看不出来，换成 `THIN` 档玻璃变清晰后，蓝底就透出来了。
> 修复 = 显式 `.backgroundColor(Color.Transparent)`——这是**清除组件默认填充**，不是给槽内元素着底色，
> 与第 3 条「不许挂 backgroundColor」不冲突（`Transparent` 即「无填充」语义，与标题栏 options / 外层 Row 同款写法）。
> 通用结论：**凡是搬进官方材质槽位的 `Button`，都要补一句 `backgroundColor(Color.Transparent)`**；
> `Text` / `Row` / `Column` / `Image` 无默认填充，无需处理。

**兼容与降级**：API 23~25 上 `systemMaterial` 被忽略 → 标题栏结构照常渲染（几何不变），只是**没有玻璃**（退化为纯文字 + 图标）。
注意这与 `HOME_OFFICIAL_TITLE_BAR = false` 的兜底路径**不等价**（兜底路径才有 `backgroundBlurStyle` 真模糊），详见 §11。

**回归验证清单（引入 `Navigation` 后新增）**：

- [x] 材质渲染、几何与改造前逐项一致（用户已确认「已生效」）
- [ ] 胶囊点按切换 推荐 ↔ 关注动态（`selectHomeFeed` / `showFollowingFeed`）
- [ ] 内容层 `parallelGesture(PanGesture)` 左右滑动切 feed（**最需要盯**：`Navigation` 会参与手势分发）
- [ ] 帖子从标题栏下穿过时的层次与滚动流畅度（`clip(false)` + `STACK`）
- [ ] 宿主 `Index.ets` 联动：横向切 Tab 的 `translate` 过渡、`onBackPress` 收藏页返回拦截、`homeRetapRequest` 回顶
- [ ] 深色模式 / 字号缩放（`fontScale`）下标题栏不溢出

**代码索引**：

| 位置 | 内容 |
|---|---|
| `pages/HomeTab.ets` | 常量 `HOME_OFFICIAL_TITLE_BAR` / `HOME_TITLE_BAR_HEIGHT` |
| `pages/HomeTab.ets` | `@Builder HomeTitleBar()`（新，槽内整行）；`@Builder HomeHeaderOverlay()`（旧）**原样保留**供回退 |
| `pages/HomeTab.ets` | `@Builder HomeFeedContent()`（由原 `build()` 根 `Stack` 抽出，两路共用） |
| `pages/HomeTab.ets` | `build()` = `if (HOME_OFFICIAL_TITLE_BAR) { Navigation()... } else { this.HomeFeedContent() }` |
| `common/Theme.ets` | `ImmMaterial.seg(active)` + `ensureSegActive()` / `ensureSegIdle()` + `_matSegActive` / `_matSegIdle` 缓存 |

### 6.11 第十三处迁移：收藏页「分类备份」弹窗（2026-09-10）

**对象**：`Favorite.ets` 的 `BackupDialog`（TopBar「备份」按钮 → 分类备份菜单：标题区 + 两条分隔线 + 「导出备份」/「导入备份」两行 + 取消按钮）。

| 项 | 内容 |
|---|---|
| 改造前 | 页面 body 顶层 `Stack` 自绘浮层（`@Builder BackupDialog()`），玻璃 = `sheetGlass` + `backgroundBlurStyle(Regular, 0.85)` + 0.5 描边 + `shadow radius 48` |
| 改造后 | 顶层 `@CustomDialog struct BackupDialogCard` + `backupDialogController`，玻璃 = `options.systemMaterial = ImmMaterial.dialog()` |
| 结果 | ✅ 构建通过（`BUILD SUCCESSFUL`）；待真机确认材质渲染 |
| 位置 / 几何 | 与同页其他弹窗逐项一致（宽度 `dialogCardWidth()` / 圆角 32vp / 底部锚点 `dy -110` / 遮罩 `#06000000` / 同一 `ImmMaterial.dialog()`）；标题区、分隔线、两行入口、取消按钮的尺寸 / 内距 / 字号 / 图标**一行未改** |
| 调用点 | `showBackupSheet()` 里仍是 `this.showBackupDialog = true`，靠 `@Watch('onShowBackupDialogChanged')` 驱动 `open()`（`@Watch` 顶替原 `syncBackState`，桥接回调里代调） |
| 按钮 | 取消按钮按 §6.2 挂 `ImmMaterial.cardAction()` + `#B3FFFFFF` / `#B31B1E24`（原 `Theme.bgCard()` **不透明**会盖掉材质）；新增 `closeBackupDialog()` 收敛关闭入口（取消 / 点遮罩 / 返回键 / `onBackRequest` 四处共用） |

**这次新增的一条判据：卡内「原本透明的行」不要为了"顺手材质化"而挂材质。**

§9.1 的迁移注记写「弹窗卡内的按钮按 §6.2 挂 `systemMaterial`」——本次**只对按钮**执行：
「导出备份 / 导入备份」两行原本就是**无底色的透明行**（平铺在玻璃卡上，靠分隔线分区），
若挂 `ImmMaterial.cardAction()`（THIN）会在卡面多出一块**玻璃瓦片**，与改造前观感不符。
对比 §6.8 的 `bindSheet` 条目 `Row`：那里原本就是 `Theme.bgCard()` 实底行，换成「材质 + 半透明底」才是等价替换。

> **判据**：材质化只针对**原本有底色**的元素（按钮 / 卡片 / 实底行）；
> 原本透明、只靠卡片玻璃承托的行**保持透明** —— 否则等于在弹窗卡上「再加一层玻璃」。

**两级弹窗时序未动**：`导出备份` 仍是「关本弹窗 → 打开导出授权弹窗」、`导入备份` 仍是「关本弹窗 → 拉起系统文件选择器」，
不套 §6.7 的 300ms 延时 —— 因为后两者是**覆盖式**出现（导出授权卡 / 系统选择器），改造前同样是「关闭动画期间目标已出现」，
行为与观感口径保持一致。

**代码索引**：

| 位置 | 内容 |
|---|---|
| `pages/Favorite.ets` | 顶层 `@CustomDialog struct BackupDialogCard`（原 `@Builder BackupDialog()` 内容迁入 + 内联 `CardDividerLine`，@Builder 不能跨 struct，坑 16） |
| `pages/Favorite.ets` | `@State @Watch('onShowBackupDialogChanged') showBackupDialog` + `backupDialogController` + `onShowBackupDialogChanged()` + `closeBackupDialog()` |
| `pages/Favorite.ets` | `build()` 里原 `if (this.showBackupDialog) { this.BackupDialog() }` 与整个 `@Builder BackupDialog()` 已删除 |

**同批一起改的还有同页 `ExportDialog`**（导出授权卡，含 `SaveButton` 安全控件）—— 见 §6.12；两弹窗 UI 已按用户要求统一。

---

### 6.12 第十四处迁移：收藏页「导出备份授权」弹窗（2026-09-10）

**对象**：`Favorite.ets` 的 `ExportDialog`（备份菜单点「导出备份」→ 授权弹窗：说明文案 + 系统 `SaveButton` 安全控件 + 取消）。
用户点名要求「弹窗 UI 跟备份弹窗一致」，故与 §6.11 同批落地。

| 项 | 内容 |
|---|---|
| 改造前 | 页面 body 顶层 `Stack` 自绘浮层；卡片宽度 `calc(100% - 64vp)`、圆角 `Radius.lg`(16)、`margin.bottom 110`、自绘 `sheetGlass` 玻璃 + `zIndex 20` |
| 改造后 | 顶层 `@CustomDialog struct ExportDialogCard` + `exportDialogController`（系统弹窗宿主，吃 `ImmMaterial.dialog()`） |
| UI 对齐（用户要求） | 卡片宽度 `dialogCardWidth()`（48vp 边距，原 64vp）／圆角 32vp／底部锚点 `dy -110`／遮罩 `#06000000`／`ImmMaterial.dialog()`；标题区换成 §6.11 同款（标题 17 Medium 居中 + 说明 13 次级居中、lineHeight 18、内距 lg·lg·lg·md）＋同一条分隔线；按钮语言统一为「16vp 内缩、44 高、`Radius.full`」：取消按钮改为与备份弹窗逐项同款（`ImmMaterial.cardAction()` + `#B3FFFFFF`/`#B31B1E24` + 15 Medium；原为 40 高 / 14 次级字 / `bgElevated`）；`SaveButton` 从 200 固定宽改为**卡片内全宽**，与取消按钮同形 |
| 状态 / 桥接 | `showExportDialog` 的 `@Watch('syncBackState')` → `@Watch('onShowExportDialogChanged')`（回调内代调 `syncBackState`）；新增 `@State exportDialogMessage` **文案快照**，宿主在「备份弹窗 → 导出」回调里**先写文案再置显隐**（同 §6.1 快照套路）；新增 `closeExportDialog()` 收敛关闭入口（取消 / 遮罩 / 返回键 / `onBackRequest` / `confirmExport` 的 `finally` 五处共用） |
| 结果 | ✅ 构建通过（`BUILD SUCCESSFUL`）；待真机确认材质与安全控件授权 |

**这次踩实的坑：`SaveButton`（安全控件）进系统弹窗该怎么写。**

官方文档明确：`SaveButton`「**不支持通用属性，仅继承安全控件通用属性**」。据此改了三处：

1. **宽度用数值 vp，不用百分比 / `calc()`** —— 安全控件通用属性里 `width/height` 是 `Length`，官方对百分比既未声明支持也未禁止；
   而安全控件**文本被截断 / 显示不全时点击不授权**（静默失败，最难查）。故宽度取宿主算好的
   `actionWidth = dialogCardWidth() - 32`（与「取消」按钮的 `calc(100% - 32vp)` 等值），由外层 `Row().justifyContent(FlexAlign.Center)` 居中。
2. **不在安全控件上挂 `margin`** —— 安全控件通用属性清单里**没有 `margin`**（尽管示例代码出现过 `.margin()`），外边距一律交给外层 `Row` 的 `padding`。
3. **保持 `buttonType: ButtonType.Capsule` + 足尺寸** —— 授权失败错误码 2 包含「按钮整体尺寸过大」「文本超出背托范围」「按钮被其他组件或窗口遮挡 / 超出窗口或屏幕」；
   本处 `dialogCardWidth() - 32` × 44（400vp 宽屏 ≈ 320×44vp）属正常按钮尺寸，弹窗内也不存在遮挡。

> **判据**：安全控件（`SaveButton` / `PasteButton`）放进系统弹窗 = **可以放**，但只能用「安全控件通用属性」那一小撮：
> `width/height/size/padding/borderRadius/fontSize/fontColor/fontWeight/backgroundColor/iconSize/align/...`；
> 外层布局（margin / 居中 / 等分）全部交给普通父容器。样式一旦"不合法"，表现是**授权失败而不是报错** —— 这也是本次宁可用数值宽也不用百分比的理由。

---

### 6.13 第十六处迁移：吧列表页悬浮 FAB（刷新 / 加号两钮）→ 自建「空 tabBar 壳」槽位（2026-09-12，真机已验）

**对象**：`ThreadList.ets` 右下角两枚悬浮圆钮（56 圆钮 / 两钮间距 12 / 右缘 28 / 加号底距 36、刷新底距 104）。
机制与 `ThreadDetail.SortPillShell()` 同构（§9.3 #6），新坑一个：**空壳自身会挡住下层列表滚动**。
> 本页落地后，`ThreadDetail.SortPillShell()` 也按同法收窄（该页排序行**靠左**排列，额外垫了一层全宽 `Row` 复位左缘，见 §9.3 #6 落地清单 2026-09-12 段 / §12 第十七处迁移）。

| 项 | 内容 |
|---|---|
| 改造前 | 页面 body 内两枚独立 `Stack`：`Theme.segGlass` + `manualGlassBorder` + `backgroundBlurStyle` + `segGlassShadow` 四项自绘玻璃 + `zIndex(20)`（属 B 档越界，从不渲染材质） |
| 改造后 | 新增 `FabSlotShell()`（「只有 tabBar 的真实 Tabs」壳）+ 槽内列 `FabSlotColumn()`；两钮换 `ImmMaterial.segFlat(false)`（无阴影档，理由同 §6.10 修复⑥） |
| 壳几何 | `height` = `barHeight` = `THREAD_LIST_FAB_SHELL_HEIGHT`(124 = 56 + 12 + 56)；`margin.bottom` = 36；**`width` = `THREAD_LIST_FAB_SHELL_WIDTH`(84)，不是 `'100%'`** |
| 显隐动效 | `fabReveal` 淡出 + 缩小 + 下沉（220ms `FastOutSlowIn`）整体作用在壳上；搜索态两钮各自 `hitTestBehavior(this.searchMode ? None : Default)` |
| 结果 | ✅ 构建 `BUILD SUCCESSFUL`；真机确认「已正常」（该行左右两侧可滑动 + 两钮可点 + 几何与改造前逐项一致） |
| 后续变更（2026-09-12） | ① **刷新钮按用户要求移除** → 壳内只剩加号：`THREAD_LIST_FAB_SHELL_HEIGHT` `124 → 56`、列表让位 `166 → 98`（兜底路径 `150 → 104`），刷新入口改由「重复点击当前排序」承担；② **加号材质由 `segFlat(false)` 换 `fabFlat()`**（THIN + `applyShadow: false` + **`colorInvert: true`**），图标色由 `Theme.textPrimary(this.isDark)` 换 **`$r('sys.color.font_primary')`** —— 用户反馈「底栏和底栏内文字随背景变色、加号不会」：材质缺 `colorInvert`、图标又是自绘 hex 时，两者都不参与官方材质的背景反色（底栏 `floatingBarFlat` 自带 `colorInvert` + 用 `$r('sys.color.font_*')` 故正常） |

**壳的写法（与 `SortPillShell` 同构，可直接复制）**：

```ts
@Builder
FabSlotShell() {
  Tabs({ barPosition: BarPosition.End }) {
    TabContent()
      .tabBar(this.FabSlotColumn())              // ← 目标元素全部放进 tabBar
  }
  .width(THREAD_LIST_FAB_SHELL_WIDTH)            // ← ★ 84，见下方核心经验
  .height(THREAD_LIST_FAB_SHELL_HEIGHT)          // 124
  .vertical(false)
  .scrollable(false)
  .barHeight(THREAD_LIST_FAB_SHELL_HEIGHT)       // barHeight = 壳高 → 内容区恒 0，壳里只有 tabBar
  .barBackgroundColor(Color.Transparent)
  .barBackgroundBlurStyle(BlurStyle.NONE)        // 坑 26：必写，否则渲染默认磨砂背板
  .backgroundColor(Color.Transparent)
  .clip(false)
  .margin({ bottom: THREAD_LIST_FAB_SHELL_BOTTOM })
  .zIndex(20)
  .opacity(this.fabReveal())
  .scale({ x: this.fabReveal(), y: this.fabReveal() })
  .translate({ y: (1 - this.fabReveal()) * 20 })
  .hitTestBehavior(HitTestMode.None)
  .animation({ duration: 220, curve: Curve.FastOutSlowIn })
}
```

**★ 核心经验：空壳**必须**收窄到「目标元素那一列」，不能开全宽。**

| 判断 | 状态 |
|---|---|
| 壳上挂 `hitTestBehavior(HitTestMode.None)`，下层列表能否恢复滚动 | ❌ **真机实测无效**（`None` 语义「自身不参与触摸测试、子节点照常」确实生效了 —— 两钮照点、壳自身不受测，但滚动仍被挡） |
| 把壳宽从 `'100%'` 收成 `84`，能否恢复滚动 | ✅ **真机实测有效**（用户确认「已正常」） |
| 成因 | **推断 + 实测锁定的节点**：拦路的是 `Tabs` 内部**系统 TabBar 页签节点**，不是我们写的 `TabContent` / `@Builder` 容器。它的命中区恒等于自身矩形，而 `hitTestBehavior` 只能挂在我们自己创建的节点上 → 「空区不吃触摸」在它身上做不到，**只能靠收窄几何把死区限制在目标元素范围内**（方案 A 生效、方案 B 无效，已双向验证） |

**收窄宽度的算式**：壳宽 = **右缘 28 + 元素宽 56 = 84**。壳内目标元素照旧写
`.width('100%')` + `.alignItems(HorizontalAlign.End)` + `.padding({ right: 28 })` —— `100%` 自动跟随壳宽
（84 − 28 = 56 = 钮宽），**故元素尺寸 / 右缘 / 底距逐项不变**。壳的宿主是
`Stack({ alignContent: Alignment.BottomEnd })`，壳变窄后自动靠右停靠，位置无需另调。

**附带收益**：壳开全宽时 `scale` 的缩放原点是「屏幕横向中点」→ 淡入时两钮像从屏幕左侧滑进来；
收窄后原点落到**两钮自身中心**，`fabReveal` 更贴形（终态 `scale(1)` / `translate(0)` 未变，纯收益）。

> **通用口径**：自建空 `Tabs` 壳的宽度 = **目标元素的实际占位**，不要把「壳」当成悬浮层去开全宽。
> ✅ **2026-09-12 已按本条经验落地并真机验收**：`ThreadDetail.SortPillShell()`（§9.3 #6）原为 `.width('100%')` 且未挂
> `hitTestBehavior`，那 46 高横带内同样吞掉下层帖子列表的竖滑（此前从未在该页反馈，属坑 30 的同类存量）。
> 现改为 `.width(this.sortPillShellWidth())` —— 两枚胶囊宽度随字号自适应，故按字号实时推算：
> `64 + 6 × fs(12, fontScale) + 12`（= 两钮左右 `padding` 4×14 + 钮间 `space` 8 + 文字宽 + 度量余量），
> **标准字号 148 / 极大字号(1.35) 172**，宁宽不挤（偏宽只多几 vp 死区，偏窄会被 `Tabs` 压缩/裁掉胶囊文字）。
> 壳外包一层**全宽 `Row`** 用 `padding({ left: 32 })` 把壳钉回改造前左缘 —— 排序行是**靠左排列**，
> 而 `Stack(alignContent: Bottom)` 会把收窄后的壳水平居中（且靠 `margin` 拉不回，居中是按含 margin 的外框算的），
> 故必须垫这层全宽 `Row`；`Row` 与壳都挂 `hitTestBehavior(HitTestMode.None)`（与 `ThreadList` FAB 壳同款）。
> 壳内 `SortRowInSlot()` 的行宽同步由写死的「屏宽 − 64vp」改为 `'100%'`（参照物已从屏宽变成壳宽，写死会溢出）。
> 结果：**两枚胶囊的位置 / 大小 / 间距与改造前逐项一致，46 高横带内目标元素左右两侧恢复可竖向滑动，真机确认正常**。

---

### 6.14 第十八处迁移（**首次把「整条栏」做成空壳槽位内的玻璃**）：吧主页排序栏 → 屏幕底部官方底栏（2026-09-12）

**对象**：`ThreadList.ets` 吧主页排序栏（热门 / 最新 / 精选）。用户要求「改成跟首页一样的沉浸光感底栏样式」，并把右下角两枚 FAB（刷新 / 加号）上挪避让。

| 项 | 内容 |
|---|---|
| 改造前 | 三枚胶囊在 `Scroll` 内容区、吧头下方（属 B 档越界，从不渲染材质，玻璃靠 `Theme.segGlass` + `backgroundBlurStyle` 真模糊自绘） |
| 改造后 | 搬到**屏幕底部**，做成与首页 / 搜索页底栏同构的官方玻璃悬浮栏：`SortSlotShell()`（空壳槽位）+ 槽内 `SortSegBar()` / `SortSegButton()`（纯文字三等分） |
| 壳几何 | 壳宽 = `sortBarWidth()`（**屏宽 − 116**，下限 184）；壳高 = `barHeight` = `THREAD_LIST_SORT_BAR_HEIGHT`（**56**，栏内纯文字无图标，比首页 / 搜索页底栏的 74 矮 18，圆角 `Radius.full` 收成 28）；底距 30 由**外层全宽 `Row` 的 margin** 承担；**左缘定位**由该 `Row` 的 `justifyContent(Start)` + `padding({ left: 24 })` 承担（栏宽不再左右对称，用 `Center` 会被推到左边距 60；坑 30：壳收窄后仍要垫全宽定位容器，`Stack` 的居中会按含 `margin` 的外框算） |
| 同排布局（2026-09-12 追加） | 底栏收窄后**加号钮与底栏同排**（底边一条线），两框**分离**不并成一条：`左 24 | 底栏 | 缝 12 | 加号 56 | 右 24` → 栏宽 = 屏宽 − 116，底栏右缘距屏右 92 = 24 + 56 + 12；加号右缘由 28 收到 **24**（与底栏左缘对称）；栏高 **56 = 加号直径**、圆角 **28 = 加号圆角**（高度对齐的落点），栏内钮高靠 padding `6 → 5` 保住 **46（几何零变化）**；加号底距 `108 → 30`（同排），刷新钮底距 `30 + 56 + 12 = 98` → **孤悬在加号正上方**（右侧仅 56 宽放不下两钮横排，塞两个等于合框，用户已确认接受）；壳宽 `84 → 80`、壳高 124 未变 |
| 材质来源 | **槽内那条 `Row`** 挂 `ImmMaterial.floatingBarFlat()` + `Radius.full`（与首页底栏同档同形，仅 `applyShadow: false` —— 本栏下方没有官方背板托底，带阴影版会在栏体四周压出突兀暗晕，真机反馈要求去除，2026-09-12；见坑 32），栏内三枚钮保持透明 |
| 开关与兜底 | `THREAD_LIST_OFFICIAL_SORT_BAR = true`；低版本 / 无材质 / 开关关闭 → 排序栏回到吧头下方原位（`SortTabsBuilder()` 原样保留）。**兜底路径的自绘 FAB 不动**（仍贴底 36 / 104）：兜底路径没有底部排序栏，加号贴底本就无同排对象，强行对齐无意义 |
| FAB 让位 | 槽位壳底距 `36 → 124`（底栏上沿 104 + 20 呼吸）→ 随底栏变矮同步 `108`（上沿 88 + 20 呼吸）→ **同排后定为 `30`**（= 底栏底距）；列表底部让位 `150 → 260 → 244` → **`166`**（= 刷新钮顶 154 + 12 呼吸；最高点由加号换成刷新钮，列表可视区同步白赚 78）。**2026-09-12 二次调整：右下角刷新钮按用户要求移除** —— 壳高 `124 → 56`（`THREAD_LIST_FAB_SHELL_HEIGHT`，壳内只剩加号、`FabSlotColumn` 的 `Column({space:12})` 去掉 space）、槽位路径列表让位 `166 → 98`（加号顶 86 = 底距 30 + 56，+ 12 呼吸）、兜底路径让位 `150 → 104`（自绘加号底距 36 → 顶 92，+ 12 呼吸；原 150 是给「贴底 104 的刷新钮 + 加号」两钮留的余量）；刷新入口改由「重复点击当前排序」承担（`refreshByRetap` → `handleRefresh`） |
| 下限调整 | 旧下限 240 必须废除：同排后 W = 320 时可用宽仅 200，下限 240 会把底栏推到加号身上（重叠 28vp）。新下限 **184 = 3 × 56 + 16**（每钮至少 56 宽、与加号同宽），屏宽 ≥ 300 时公式自然 ≥ 184 |
| 交互（2026-09-12 追加） | 点**未选中**的钮 = 切换排序（**双拍转场**：旧内容反向轻推淡出 → 新内容自对侧阻尼推入，见下方「转场」行；命中 `sortSession` 快照秒开，原逻辑不变）；点**已选中**的钮（当前在热门再点热门，最新 / 精选同理）= **回顶 + 刷新该排序**：`selectSort` 的同值分支由原来的 `return` 改为调 `refreshByRetap(sort)` —— 先立即 `listScroller.scrollTo(0,0)`（300ms `EaseOut`，不等网络），再复用 FAB 刷新钮的 `handleRefresh()`（同一条链路：网络刷新第 1 页、8s 超时兜底、「刷新成功 / 失败」toast、转圈反馈、后台昵称校准与缓存回写；busy 时只回顶不重复发请求）。两处路径共用 `selectSort`，**兜底路径的 `SortTabsBuilder` 自动同行为**，无需额外改动 |
| 转场（2026-09-12 定稿·第三次） | 排序切换 = **照搬首页 `switchTab` 的「两页连着」过场**：新页自对侧整屏（±100%）进入，**旧页同时向反侧整屏滑出**，二者在同一个 `animateTo`（320ms `springMotion(0.72, 0.86)`）里对向平移。首页每个 Tab 都是常驻组件（`visibility` 隐藏、切页只改位移），旧页天然在树上；本页只有一个列表、数据被整体替换，故在**点击那一刻**用 `componentSnapshot.getSync` **同步**截下当前屏幕（旧内容 + 旧滚动位置）作旧页，由一层 `Image` 承载滑出，`SORT_ANIM_SETTLE=420ms` 收口后释放。★ 关键认知：前两版「单侧滑入」「退场+入场双拍」都错在**旧页不在场 / 被瞬间替换** —— 首页那种"顺滑、不过度"的本质是**两页相接同时移动**，与单页的位移曲线、时长关系不大。未命中缓存时收口过场 + 骨架屏轻淡入（150ms），网络返回再对向平移；`refreshSilently` 在过场窗口（`sortAnimUntil` = 起滑 + 420ms）内只回写缓存不上屏。**2026-09-12 追加·位移作用域收窄到「列表区」**（用户反馈「吧主页切换动画顶部吧信息能否不跟着切换」）：位移原挂在 `Scroll` 上，而吧头是 `Scroll` 内容里的普通子项 → 吧头被一起带着滑（首页切 Tab 时标题栏 / 底栏是静止的，两者不一致）。现改为：新页位移下移到 `Scroll` 内的**列表区**那一层（内容 / 骨架屏 / 空态 / 错误），吧头与兜底排序栏不参与位移；旧页快照用 `SnapshotOptions.region`（**px**，API 15+）裁掉吧头，旧页层再按 `exitClipTop` 下移并收窄高度，与只含列表区的新页严格对齐 —— 屏幕上"吧头原地不动、只有下方列表对向平移"，与首页头部固定、内容平移同构；吧头已滚出屏 / 吧头高未测到时不裁（整屏即列表内容，自动降级） |
| 结果 | 构建 `BUILD SUCCESSFUL`（25s）；材质来源修正 + 转场手感待真机复核 |

**壳的写法（可直接复制）**：

```ts
@Builder
SortSlotShell() {
  Row() {                                        // ← 全宽定位容器：左缘 + 底距（坑 30 要求）
    Tabs({ barPosition: BarPosition.End }) {
      TabContent()
        .tabBar(this.SortSegBar())               // ← 槽内元素自己挂材质（坑 31）
    }
    .width(this.sortBarWidth())                  // ← ★ 收窄到目标元素占位（屏宽 − 116 / 下限 184），不是 '100%'
    .height(THREAD_LIST_SORT_BAR_HEIGHT)         // 56 = 右下加号钮直径（同排高度对齐）
    .vertical(false)
    .scrollable(false)
    .barHeight(THREAD_LIST_SORT_BAR_HEIGHT)      // barHeight = 壳高 → 内容区恒 0
    .barBackgroundColor(Color.Transparent)
    .barBackgroundBlurStyle(BlurStyle.NONE)      // 坑 26：必写
    .backgroundColor(Color.Transparent)
    .clip(false)
    .hitTestBehavior(HitTestMode.None)
    // ★ 不传 barFloatingStyle —— 空壳上它不生成官方背板（坑 31）
  }
  .width('100%')
  .height(THREAD_LIST_SORT_BAR_HEIGHT)
  // ★ 栏宽不再左右对称（左 24 / 右 92，右侧留给同排的加号 + 12 缝）：
  //   用 Center 会被推到左边距 60，必须 Start + padding-left 钉回左缘
  .justifyContent(FlexAlign.Start)
  .padding({ left: 24 })
  .margin({ bottom: THREAD_LIST_SORT_BAR_BOTTOM })
  .zIndex(19)
  .hitTestBehavior(HitTestMode.None)
}
```

**★ 本次唯一的坑（坑 31）：空壳上没有官方背板可拿。**

> 首版按「§1.1 第 26 行 = `barFloatingStyle.systemMaterial`」直接给空壳配上 `barFloatingStyle`，**编译通过、运行期一条材质都没有**
> （真机反馈「底栏没沉浸光感材质」，且无 `out of scope` 日志可查）。对照已落地三处空壳（`ThreadDetail.SortPillShell` /
> `ThreadList.FabSlotShell`）发现：它们**从不传 `barFloatingStyle`**，材质一律由**槽内元素自己挂**。
> 结论：`barFloatingStyle` 只重构「`TabContent` 有内容」的壳的 bar；**空壳要「整条玻璃」，就把材质挂到槽内那一条容器上**
> （本例是 `Radius.full` 的整栏 `Row` + 材质；2026-09-12 起该材质用**无阴影档** `ImmMaterial.floatingBarFlat()`
> —— 空壳路径下这条栏下方没有官方背板托底，带阴影版的投影会摊成一圈突兀暗晕，见坑 32）。

### 6.15 第十九处迁移：帖子详细页「跳转官方贴吧」确认浮层 → 系统 `CustomDialog`（2026-09-12）

**对象**：`ThreadDetail.ets` 底部胶囊行「跳转」钮 → 确认弹窗（原 `@Builder JumpConfirmDialog()`）。

| 项 | 内容 |
|---|---|
| 改造前 | 页面 body 顶层 `Stack` 自绘浮层（暗蒙层 + 居中卡片 + 确定 / 取消竖排按钮），卡上写了 `.systemMaterial(ImmMaterial.control())` |
| 关键发现 | 那行 `systemMaterial` **一直在空转**：body 内自绘浮层不在官方材质生效范围内（§1.2），真正起作用的是同层自绘的 `.backgroundEffect(ImmBlur.control())` —— 典型"能编译不生效"残留（与 §9.2 第 3 条同源） |
| 改造后 | 换成系统 `CustomDialog`：顶层新增 `@CustomDialog struct JumpTiebaDialogCard`，宿主新增 `jumpDialogController`，玻璃交给 `options.systemMaterial: ImmMaterial.dialog()` |
| 几何对齐 | 宽度 `calc(100% - 48vp)` → `width: this.dialogCardWidth()`（屏宽 − 48，与 `ThreadList` / `Favorite` 同源实现）；圆角 32；遮罩 `#06000000`；标题 / 说明 / 链接预览 / 两枚按钮的字号、尺寸、间距**逐项未动**（按钮仍是竖排全宽） |
| 落点（同日三次调整，已定型） | 初版按"原地就是居中卡片"取 `DialogAlignment.Center` → 用户要求「与置顶弹窗一致」改用 **`DialogAlignment.Bottom` + `offset.dy = -110`** → 用户反馈 -110 与「正序」胶囊贴在一起，先取安全值 `-170` → **用户复看后指定 `offset: { dx: 0, dy: -140 }`（最终值）**。依据：本页底部比收藏 / 进吧页多叠一层 —— 评论悬浮岛占「距底 30~96」（底距 30 + 高 66），排序胶囊行（底距 `30+66 = 96` + 高 46）占「距底 96~142」，行内 padding top4/bottom8 托着高 34 的钮体（本体距底 104~138）；`-140` 时弹窗底边落在钮体顶边 138 之上 2vp —— 紧贴但不压胶囊文字。⚠️ 勿改回 `Center`，也勿改回 `-110` |
| 状态桥接 | `showJumpDialog` 由普通 `@State` 改 `@State @Watch('onShowJumpChanged')`，既有 `this.showJumpDialog = true/false` 调用点零改动（§4.2 第 ③ 步）；`openJumpDialog()` 打开前写 `jumpUrlPreview` 快照（`threadWebUrl()` 是宿主方法，弹窗内取不到） |
| 关闭语义 | `onWillDismiss` → `closeJumpDialog()`，一并覆盖「点遮罩 / 返回键 / 侧滑」（与自绘时期点蒙层关闭一致，§4.5）；确定钮走 `confirmJump()`（内部仍先置 false 再拉起贴吧，业务零改动） |
| 卡内删除 | `backgroundColor` / `backgroundEffect` / `border` / `shadow` ×2 / `systemMaterial` 全删（材质接管，§4.4）；按钮例外 —— 主钮 `ImmMaterial.accent()` + `#CC3173FF` + 同色浮起阴影，次钮 `ImmMaterial.cardAction()` + 半透明底 + 中性轻投影（§6.2 / 坑 11） |
| 附带 | 本页此前**没有任何系统弹窗**，故一并补齐 `import { display }`（卡片宽度用）与 `dialogCardWidth()`；删除 `DetailRoot` 内的浮层挂载与旧 builder（−86 行） |
| 结果 | 构建 `BUILD SUCCESSFUL`（24s）；真机观感待复核 |

---

## 7. 已知偏差与遗留问题

| # | 偏差 | 说明 | 处置 |
|---|---|---|---|
| ① | **弹窗容器宽度受系统上限约束（默认最大 400vp）** | 窗口 > 448vp 的设备（宽屏 / 平板）上，卡片会比原 `calc(100% - 48vp)` 窄 | 硬限制，绕不过；宽屏如需保持观感需换方案 |
| ② | **容器是否自带默认内边距未知** | 官方文档未写明 | 真机量一次；若有多余内缩，用卡内 `padding` 反向补偿 |
| ③ | **材质渲染管线 ≠ `backgroundBlurStyle`** | 玻璃观感不可能像素级一致 | 本次目标即为"换成官方材质"，接受 |
| ④ | **进出场动画曲线近似** | `transition` 的 scale/translate 组合无法 1:1 映射到 `openAnimation` | 接受；如需更强动效可评估 `transition` 相关 options |
| ⑤ | **顶部槽位要多一层 `Navigation` 壳** | 页面 `build()` 根多一个导航容器，会参与手势分发与返回键处理（本工程此前 `Navigation` 组件数为 0） | 用开关常量隔离 + §6.10 回归清单；几何可对齐，观感按偏差 ③ 接受 |
| ⑥ | **标题栏高度与内容让位是「成对手工常量」** | `HOME_TITLE_BAR_HEIGHT = 108` 与内容让位 `HOME_TOP_PAD = 98` 必须同时改，改一个忘一个就会「胶囊压到首卡」或「顶部多一截空白」 | 两个常量都放 `HomeTab.ets` 顶部并互相注释引用（§6.10） |
| ⑦ | **API 23~25 上顶部槽位“有结构、无玻璃”** | 关闭量化的兜底路径（`backgroundBlurStyle`）与槽位路径**不自动等价**：低版本走槽位只有纯文字 | 若要低版本也磨砂，加一层 `MaterialManager.getApiLevel()` 分支（§11） |

---

## 8. 坑位清单（累积，改一个记一个）

| # | 坑 | 表现 | 解法 |
|---|---|---|---|
| 1 | 自绘浮层挂 `systemMaterial` | 无玻璃 + hilog `Material inactive: out of scope` | 自绘浮层一律走 `backgroundBlurStyle`；想用材质就换系统宿主 |
| 2 | `customStyle: true` + 材质 | 材质不生效、圆角归 0、背景透明 | 必须 `customStyle: false` |
| 3 | `width: 'calc(100% - 48vp)'` | 编译报错 `not assignable to type 'Dimension'` | 换算数值 vp（§3.2） |
| 4 | `@CustomDialog` 缺 controller 属性 | 编译报 `10905211` | 声明 `controller?: CustomDialogController;` |
| 5 | `@Watch` 回调写成 `private` | 与工程既有写法不一致 | 用 public（工程惯例） |
| 6 | 高不透明白底叠真模糊 | 形成"实白夹层"，观感退回纯白底 | 底色归零后再挂模糊（guide §6.6） |
| 7 | **容器节点**上「材质 + 自定义 `shadow`」并存 | 重复且冲突 | 材质接管该节点的阴影，删掉自定义 `shadow`（**注意：仅限容器节点；Button 自身是例外，见 #12**） |
| 8 | `Button` 上挂 `backgroundBlurStyle` | 模糊层忽略 `borderRadius`，渲染成直角方块 | 模糊放到 Button 内层铺满的 Row 上（见 memories） |
| 9 | 材质区域越界 | 大面积弹窗动效开销高 | 避免接近全屏的 Dialog（官方建议 ≤ 328×216 量级） |
| 10 | 误以为「弹窗内子组件不吃材质」 | 把「只有弹窗容器吃材质」当结论，卡内按钮不敢挂 | 系统 `CustomDialog` **子树内**的 `Button` 挂 `systemMaterial` **真机生效**（§1.4 / §6.2）；分界在宿主是不是官方弹窗，不在层级深浅 |
| 11 | 按钮材质 + **不透明**底色 | 材质滤镜被完全遮挡，看不到玻璃 | 底色必须带透明度（`#CC3173FF` / `#B3FFFFFF` / `#B31B1E24`）；不透明色只在低算力档位才等价于 `backgroundColor` |
| 12 | 把 §4.4「材质接管五项」套到**弹窗内的 Button** 上，误删按钮的 `backgroundColor` / `shadow` | 按钮失去品牌底色与浮起层次，与玻璃卡糊成一片 | **Button 是例外**：材质挂 Button 自身时，半透明 `backgroundColor` + 自定义 `shadow` 与材质**可共存**（§6.2）；§4.4 只适用于**容器节点** |
| 13 | 用 `AlertDialog.show()` 做二次确认，以为它「在官方白名单里所以自动有光感」 | 运行时是纯白底系统弹窗（无 `out of scope` 日志、构建也不报错，容易漏检）；且版式固定，与同页其他 `CustomDialog` 观感割裂 | `AlertDialogParam.systemMaterial` 需**显式传**才生效，但版式仍不可控 → 统一改用 `CustomDialog` + `ConfirmDialogCard`（§6.5） |
| 14 | 危险色按钮直接把红底挂到 `ImmMaterial.accent()` 上 | accent 的 `materialColor` 赋品牌蓝，与红底叠成脏色 | 危险色要有独立材质槽位 `ImmMaterial.danger()`（材质按 `materialColor` 分档缓存，不能复用 accent） |
| 15 | 迁完弹窗只加了 `@State showXxx` 和 controller，忘了接回退链 | 弹窗打开时按系统返回键**直接退页面**（弹窗被连带销毁），而非先关弹窗 | `showXxx` 三处都要补：`syncBackState()` 的 `canBack` 表达式、`@Watch` 回调里调 `syncBackState()`、`onBackRequest()` 的优先级链（§6.5） |
| 16 | 把宿主 `@Builder`（`CategoryCover` 等）直接搬进 `@CustomDialog struct` 里用 `this.xxx()` 调 | 编译不过：`Property 'xxx' does not exist on type 'YyyDialog'` —— `@Builder` 是组件实例方法，**不能跨 struct** | 内容少的：在 struct 内**复制一份**同名 `@Builder`；被多个弹窗共用的：抽**全局 `@Builder function`** 并参数化 `isDark` / `fontScale`。别用 `@BuilderParam`（`builder:` 是属性传参，内部 `this` 指向子组件，宿主状态取不到，§6.6 坑 1） |
| 17 | 关闭弹窗时顺手把目标对象置 null（快照跟着清空） | 关闭动画还有 200ms，卡内信息行名称/数量**先变空再飞走**，很跳 | 对象 → 快照的 `@Watch` 回调里判 `if (!obj) { return; }`，**保留上一次快照**；真值清空只影响业务，不影响动画期间的渲染（§6.6 坑 3） |
| 18 | `bindSheet` 的 `height` 用 `SheetSize` 枚举去套原设计的自定义高度 | 枚举只有 MEDIUM(50%) / LARGE(90%) / FIT_CONTENT，62% 这类档位**对不上**，面板高度失真 | `height?: SheetSize \| Length` 支持 `Length`，直接给百分比字符串 `height: '62%'`（§6.8） |
| 19 | `bindSheet` 只用单向 `this.showXxx` 传入 `isShow` | 用户**手势下滑关闭**后系统不会回写状态 → `showXxx` 残留 `true`，下次置 `true` 无变化（**打不开**），`favCanGoBack` 也一直为真 | 用 `$$` 双向绑定：`.bindSheet($$this.showMovePanel, ...)`，系统关闭时自动回写并触发 `@Watch`（§6.8） |
| 20 | `bindMenu` 直接挂「触发按钮」+ `Placement.BottomRight`，想靠它复刻原 `position({ right: 16 })` | `bindMenu` 的锚定基准是**触发组件**而非屏幕：排序钮右侧还有编辑 / 搜索 / 黑名单钮 → 菜单整体左移约 50vp，与原位置对不上 | 用 **1×1 隐形锚点**把菜单锚回原坐标：`Row().width(1).height(1).position({ top: 99, right: 16 }).hitTestBehavior(HitTestMode.None).bindMenu(...)` + `Placement.BottomRight`（菜单右下角对齐锚点右下角）→ 右边缘精确落回「屏幕右 16」（§6.9） |
| 21 | `bindMenu` 不设 `targetSpace`，用系统默认间距 | 菜单被系统再往下推约 8vp，与原 `position({ top: 100 })` 差一截（连带上一行，两层偏差叠加后很容易被当成「位置全变了」） | `targetSpace: LengthMetrics.vp(0)`（`ContextMenuOptions`，since 26.0.0）→ 菜单顶边 = 锚点底边 = `99 + 1 = 100` ✅（§6.9） |
| 22 | 把「吸顶胶囊 / 44 圆钮在页面 body 里没有官方宿主」当成死局 | 顶部长期只能 `backgroundBlurStyle`，与「底栏有真材质」形成上下割裂 | **B 档的生效区域就是 `Navigation` 标题栏**：整行搬进 `.title({ builder, height })`，**槽内子元素各自挂 `systemMaterial` 即可渲染**（§1.5 / §6.10，真机已验） |
| 23 | `Navigation` 设了 `.title()` 但漏了 `barStyle: STACK` | 内容不再延伸到标题栏之下 → **丧失沉浸**（帖子从标题栏下沿才开始，顶上一条硬分界） | `.title({ builder, height }, { barStyle: BarStyle.STACK, backgroundColor: Color.Transparent })`；官方原文：延伸至非安全区的前提是「标题栏隐藏或 STACK 模式」（§6.10） |
| 24 | 槽内子元素保留了旧写法的 `backgroundColor` / `border` / `backgroundBlurStyle` / `shadow` | 与 `systemMaterial` 互相覆盖 —— 要么看不到真材质，要么「真模糊 + 材质」双叠发脏 | 槽内元素只留几何与文字/图标色属性，玻璃四项**全部删除**（同 §4.4 口径；§6.10） |
| 25 | 想沿用「选中态品牌蓝底」的设计，却给槽内胶囊用了 `ImmMaterial.tabActive()` | `tabActive` 自带 `materialColor` 品牌蓝赋色 → 「去蓝底、状态靠文字色」的定稿设计被改回去 | 顶部槽位用**中性档** `ImmMaterial.seg(true/false)`（REGULAR / THIN，无 `materialColor` + `interactive`）；染色档要独立槽位（同坑 14） |
| 26 | **任何 `Tabs` 壳**（空 tabBar 壳 / 悬浮岛壳）只设 `barBackgroundColor(Transparent)`，以为背板已彻底移除 | 仍渲染**默认模糊背板** —— `barBackgroundBlurStyle` 默认值是 `BlurStyle.COMPONENT_REGULAR`，与颜色层无关。空 tabBar 壳上是「胶囊后一条磨砂板」；悬浮岛壳上是「岛后全宽磨砂带，上边缘像一条细光感线」 | 每个 `Tabs` 壳都必须**显式** `.barBackgroundBlurStyle(BlurStyle.NONE)`；官方玻璃由 `barFloatingStyle.systemMaterial` 承担，与该属性无关，关掉不影响材质（2026-09-10 真机两次发现并修复）。⚠️ `Index` / `Search` / `UserProfile` 的悬浮壳暂未加，若目视出现同款磨砂带照此处理。**追加**：空 tabBar 壳**不要挂 `barOverlap(true)`** —— 它的官方语义附带「底栏默认模糊设为 `COMPONENT_THICK`」，空壳里它零布局作用却触发一层模糊背板/阴影；只有「内容要延伸到底栏之下」的壳（岛壳）才需要 `barOverlap`，且岛壳有 `barFloatingStyle` 重构 bar 不受此影响 |
| 27 | 材质参数写 `lightEffect: { color: undefined }`，以为"颜色未设=不启用" | **等于显式启用白色流光**：官方语义是「传**对象**=启用、`{color}` 缺省默认 `Color.White`；传 `null`=显式禁用；不传(`undefined`)=跟随组件默认」。悬浮玻璃岛上沿会出现一条白色光感线（左侧圆角处向外探出，极易误认成布局多出来的描边） | 想去掉光感线：该材质槽位改 `lightEffect: null`。`ImmMaterial.floatingBar()` 已改（2026-09-10 真机反馈）；其余槽位（`bar/control/seg/tab/accent/...`）目前仍显式启用，若哪处也嫌光感线明显，同法处理 |
| 28 | 迁移弹窗时把卡内**原本透明的行**（无底色、只靠卡片玻璃承托）也"顺手"挂上 `systemMaterial` | 玻璃卡面多出一块 THIN 材质瓦片，行区与卡面出现突兀分界，与改造前观感不符 | 材质化只针对**原本有底色**的元素：按钮 / 卡片 / 实底行 → 换「材质 + **半透明**底」（坑 11）；原本透明的行**保持透明**（§6.11） |
| 29 | 安全控件（`SaveButton` / `PasteButton`）按普通组件写法迁移：`.width('100%')` / `calc()` 百分比宽、直接在控件上挂 `margin` | `SaveButton` **不支持通用属性**（只继承安全控件通用属性）：百分比/calc 行为未定义、`margin` 根本不在属性清单里；更麻烦的是样式"不合法"时表现是**授权失败（错误码 2）而不是报错**，通常还伴随「文本被截断即点击不授权」的静默失败 | 安全控件只用其白名单属性（`width/height/size/padding/borderRadius/fontSize/fontColor/...`），且 `width` 传**数值 vp**（怕百分比失效就用宿主算好的 vp 常量）；margin / 居中 / 等分交给外层普通容器（`Row().padding().justifyContent()`）；务必保留 `ButtonType.Capsule` + 正常尺寸、避免被遮挡或超出屏幕（§6.12） |
| 30 | 自建「空 `Tabs` 壳」开**全宽**（`'100%'`）把目标元素送进 TabBar 槽位 | 壳本身看不出问题，但**下层列表在那一条横带里滑不动**（该行整段竖滑被吞）；且给壳挂 `hitTestBehavior(HitTestMode.None)` **修不了** —— 拦路的是系统 TabBar **页签节点**，命中区恒等于自身矩形，该属性挂不到它身上 | 把壳宽收成「**目标元素实际占位**」（`ThreadList` FAB 壳 = 右缘 **24** + 钮宽 56 = **80**，右缘由 28 收成 24 以与排序栏左缘对称；`ThreadDetail` 排序壳 = 按字号推算 `64 + 6 × fs(12) + 12` → 148 / 172），死区随之缩小到目标元素那一列；壳内元素照旧 `width('100%')` 跟随壳宽，**尺寸 / 底距零改动**（§6.13）。⚠️ 若目标元素**靠左/居中**排列（非贴右），壳收窄后还需垫一层全宽定位容器（`Row` + `padding-left`）把壳钉回原位 —— `Stack` 的居中会按含 `margin` 的外框计算，仅调 `margin` 拉不回来（`ThreadDetail` 实例）。⚠️ 若目标元素**左右不对称**（如 `ThreadList` 排序栏收窄让位给同排加号后为「左 24 / 右 92」），全宽容器**必须用 `Start` + `padding-left`**，`Center` 会把它按左右均分的 60 推进去（§6.14 实例） |
| 31 | 在**空 `Tabs` 壳**上写 `barFloatingStyle({ systemMaterial: ImmMaterial.floatingBar() })`，以为能拿到「整条官方玻璃背板」 | 编译通过、**运行期完全不渲染材质**，且无 `out of scope` 日志可查（`ThreadList` 底部排序栏首次落地即由此翻车：真机反馈「底栏没沉浸光感材质」） | 空壳路径**没有**官方背板可拿：`barFloatingStyle` 重构的是「`TabContent` 有内容」的壳的 bar（`Index.FloatingTabsShell` / `Search.ImmersiveShell` / `ThreadDetail.ImmersiveDockShell` 的 `TabContent` 都装了页面），空壳里它不生成背板。空壳要整条玻璃，就把材质**挂到槽内那一条容器**上（§6.14：整栏 `Row` 挂 `ImmMaterial.floatingBarFlat()` + `Radius.full`，栏内元素保持透明）—— 这正是 §1.1 第 27 行「壳内元素各自挂」的同一条路（`ThreadDetail.SortPillShell` / `ThreadList.FabSlotShell` 一直是这么做的，故从未遇到此坑） |
| 32 | 给**页面元素自己挂材质**的悬浮栏用带阴影版 `ImmMaterial.floatingBar()`（`applyShadow: true`） | 栏体四周被压出**一圈突兀暗晕**（真机截图反馈「吧主页底栏有层突兀阴影」）—— 该栏浮在列表内容之上、下方没有官方背板托底，材质自带投影无处可落，只能摊在内容与页底上 | 这类「**无背板托底**」的悬浮栏换**无阴影档** `ImmMaterial.floatingBarFlat()`（`applyShadow: false`，其余 THIN / 无流光 / `colorInvert` 逐项一致）；走 `barFloatingStyle` 的官方悬浮岛（首页 / 搜索页 / `ThreadDetail` 底栏）**仍用带阴影版** —— 那里的阴影是悬浮岛观感的一部分。同族先例：`segFlat`（详情页排序胶囊 2026-09-10）、FAB 的 `segFlat(false)`（2026-09-11）。⚠️ **判据**：材质挂在「自己就是最终形状、下方无背板」的元素上时，一律优先无阴影档 |

---

## 9. 待迁移清单（用户逐个改）

### 9.1 卡片弹窗（套 §4 模板）

| # | 位置 | 弹窗 | 现状 | 目标 | 状态 |
|---|---|---|---|---|---|
| 1 | `ForumsTab.ets` | 一键签到 `SignAllDialog` | 自绘浮层 + `sheetGlass` | `CustomDialog` + `ImmMaterial.dialog()` | ✅ **已完成** |
| 2 | `ForumsTab.ets` | 足迹删除确认 `RecentDeleteDialog` | 自绘浮层 + `sheetGlass` | 同上 | ⬜ 待办 |
| 3 | `ForumsTab.ets` | 关注吧长按菜单 `ForumMenuDialog` | 自绘浮层 + `sheetGlass` | `CustomDialog` + `ImmMaterial.dialog()`（**不用 `bindMenu`**：原形态是「标题 + 已置顶标签 + 菜单行 + 分隔线 + 取消按钮」的贴底卡片，改菜单会动设计） | ✅ **已完成**（§6.3） |
| 4 | `ForumsTab.ets` | 排序下拉 `ForumSortDialog` | 自绘浮层 + `sheetGlass` | **`bindMenu`** + `MenuOptions.systemMaterial`（原「屏幕右上角固定」的浮层改由系统菜单承载；用 1×1 隐形锚点 + `targetSpace: 0` 保住原坐标） | ✅ **已完成**（§6.9） |
| 5 | `Favorite.ets` | 备份 `BackupDialog` | 自绘浮层 + `sheetGlass` | `CustomDialog` + `ImmMaterial.dialog()`（**两行入口原本是透明行，故不挂材质**：挂了会在卡面多出一块玻璃瓦片，见 §6.11） | ✅ **已完成**（§6.11） |
| 6 | `Favorite.ets` | 导出 `ExportDialog` | 自绘浮层 + `sheetGlass` | `CustomDialog` + `ImmMaterial.dialog()`，**UI 与 §6.11 备份弹窗统一**；卡内 `SaveButton` 安全控件只能用「安全控件通用属性」→ 宽度传数值 vp、margin 交给外层 Row（见 §6.12） | ✅ **已完成**（§6.12） |
| 7 | `Favorite.ets` | 置顶确认 `PinConfirmDialog` | 自绘浮层 + `sheetGlass` | `CustomDialog` + `ImmMaterial.dialog()`（**不用 `AlertDialog`**：系统 AlertDialog 的标题/正文/按钮排布是固定样式，保不住「居中标题 + 说明 + 两枚等分胶囊按钮」的原设计） | ✅ **已完成**（§6.4） |
| 8 | `Favorite.ets` | 排序下拉 `SortMenuPanel` | 自绘浮层 + `sheetGlass` | **`bindMenu`** + `MenuOptions.systemMaterial`（三种 TopBar 形态共用一个根锚点） | ✅ **已完成**（§6.9） |
| 9 | `Favorite.ets` | 分类管理 `CategoryManageSheet` | 自绘浮层 + `sheetGlass` | `CustomDialog` + `ImmMaterial.dialog()`（**不用 `bindSheet`**：`bindSheet` 会把「底部 110 的居中卡片」变成「底部抽屉」，违反「布局与改动前一致」这一硬要求；封面 / 菜单行 / 分隔线三个 `@Builder` 已随内容复制进 `CategoryManageDialog`） | ✅ **已完成**（§6.6） |
| 10 | `Favorite.ets` | 移入抽屉 `MovePanel` | 自绘浮层 + `sheetGlass` | **`bindSheet`** + `SheetOptions.systemMaterial`（本处是全清单唯一的「抽屉」形态，故**不用** `CustomDialog`；`$$` 双向绑定处理手势下滑关闭时的状态回写） | ✅ **已完成**（§6.8） |
| 11 | `Favorite.ets` | 批量删除收藏确认 `DeleteConfirmDialog` | **`AlertDialog.show()`**（系统居中弹窗，无材质） | 复用 `ConfirmDialogCard`（`CustomDialog` + `ImmMaterial.dialog()` + `danger: true`），位置对齐置顶弹窗 | ✅ **已完成**（§6.5） |
| 12 | `UserProfile.ets` | 帖子排序下拉 `PostSortMenu` | 自绘浮层（**不透明** `bgElevated` + 无效 `systemMaterial`） | **`bindMenu`** + `MenuOptions.systemMaterial`（原浮层用不透明底且材质 out of scope，改后真材质生效，WARN 一并消失） | ✅ **已完成**（§6.9） |
| 13 | `FollowList.ets` | 排序下拉 `SortMenuPanel` | 自绘浮层（**不透明** `bgElevated` + 无效 `systemMaterial`） | **`bindMenu`** + `MenuOptions.systemMaterial`（与第 8 项同款残留，随 §6.9 一并改） | ✅ **已完成**（§6.9） |
| 14 | `BlacklistManager.ets` | 排序下拉 `SortMenuPanel` | 自绘浮层（**不透明** `bgElevated` + 无效 `systemMaterial`） | **`bindMenu`** + `MenuOptions.systemMaterial`（与第 8 项同款残留，随 §6.9 一并改） | ✅ **已完成**（§6.9） |
| 15 | `ThreadDetail.ets` | 跳转官方贴吧确认 `JumpConfirmDialog` | 自绘浮层 + **空转的 `systemMaterial(ImmMaterial.control())`** | `CustomDialog` + `ImmMaterial.dialog()`（同页 `LinkConfirmDialog` 形态同款、同样空转，本次未在范围内） | ✅ **已完成**（§6.15） |

> **迁移时顺手做**：弹窗卡内的按钮按 §6.2 挂 `systemMaterial`（主按钮 `ImmMaterial.accent()`、危险主按钮 `ImmMaterial.danger()`、次按钮 `ImmMaterial.cardAction()`），底色保持半透明 + 保留自定义轻投影。
> **新点位优先复用 `ConfirmDialogCard`**（`pages/Favorite.ets` 顶层）：凡是「标题 + 正文 + 取消/确认」形态的二次确认，直接加一组快照状态 + 一个 controller 即可，不要重复铺模板。

### 9.2 其他待排查

- **`AlertDialog` 已全工程清零** ✅：最后一处（分类管理菜单里的「删除分类」）已换成 `ConfirmDialogCard` + `danger: true`（§6.7）。现源码中已无任何 `AlertDialog.show()` 调用，`ForumsTab.ets` 仅剩文档注释里提到 `AlertDialogParam`。
- 二级页（`ThreadList` / `ThreadDetail` / `Search` / `FollowList` / `PersonalContent` / `UsageHabitsPage` / `Login` / `Compose`）里的自绘弹窗是否还有遗漏，需逐页排查。
  - ✅ `ThreadDetail` 已排查（2026-09-12）：「跳转官方贴吧」确认已迁系统弹窗（§6.15）；同页 `LinkConfirmDialog`（链接跳转确认，复制链接 / 确认 / 取消三枚竖排钮）**形态同款、卡上同样挂着空转的 `systemMaterial(ImmMaterial.control())`**，可直接复用同一套模板迁走 —— ⬜ 待办。
- **页面主体仍在挂 `systemMaterial` 的遗留点位**（`FollowList` 等）→ 构建 WARN 持续出现，属"能编译不生效"，应清理或改走 `backgroundBlurStyle`。

---

### 9.3 顶部槽位（`Navigation` 标题栏）迁移清单

> 判据：**顶部吸顶行**（分段胶囊 / 44 圆钮 / 标题）想从 `backgroundBlurStyle` 升级为真材质，就把整行搬进 `Navigation` 的 `title` 槽位（模板见 §6.10）。
> 前提：该页 `build()` 根要能容纳一层 `Navigation` 壳；几何对齐 = 「旧悬浮层的 `top + 行高 + bottom` 拼成 title bar 的 `height`」，并同步核对内容让位常量。

| # | 页面 | 顶部行现状 | 目标 | 状态 |
|---|---|---|---|---|
| 1 | `HomeTab.ets` | 吸顶「推荐 / 关注动态 / 搜索」（`HomeHeaderOverlay()`） | `Navigation` title 槽位 + `ImmMaterial.seg(active)`（三颗同档） | ✅ **已完成**（§6.10，真机已验生效） |
| 2 | `ThreadList.ets` | TopBar（返回 / 标题 / 排序 / 搜索） | 同上 | ⬜ 待办 |
| 3 | `Favorite.ets` | TopBar 五种形态（根态 / 编辑态 / 搜索态 / 分类内 / 吧内） | 同上：五形态塞进同一个 title builder 条件渲染 | ✅ **已完成**（见下方落地清单） |
| 4 | `ForumsTab.ets` | TopBar（标题「进吧」+ 一键签到 / 排序 ⇅ / 深色切换） | `Navigation` title 槽位 + `ImmMaterial.seg(false)`（三钮同档） | ✅ **已完成**（见下方落地清单） |
| 5 | `UserProfile.ets` / `FollowList.ets` / `BlacklistManager.ets` | TopBar + 排序钮（三页同构） | 同上，可一次改完 | ⬜ 待办 |
| 6 | `ThreadDetail.ets` | 沉浸顶栏（返回钮 / 吧名胶囊 / 分享钮）+ 排序胶囊（正序 / 只看全部）+ **底部已是官方 `Tabs` 悬浮条** | 顶栏走 `Navigation` title 槽位；排序胶囊走自建「空 tabBar 壳」槽位 —— 均 `ImmMaterial.seg(...)` | ✅ **已完成 + 真机已验**（见下方落地清单；该页为「上下两端官方槽位」样板；排序胶囊的「TabBar 槽位子树挂材质生效」与「壳宽收窄消滚动死区」两项判据均已真机确认） |
| 7 | `Search.ets` | 顶部返回 + 搜索框（`TextInput`）+ **底部已是官方 `Tabs` 悬浮条** | `Navigation` title 槽位 + `ImmMaterial.seg(false)`（返回钮 / 搜索框 / 搜索钮三元素同档）；⚠️ 搜索框搬进标题栏后**聚焦 / 键盘避让 / 输入态**行为待真机验证 | ⏳ **代码已落地**（见下方落地清单） |
| 8 | `SubPostDetail.ets`（楼中楼页） | TopBar（返回 44 圆钮 / 吧名居中文字） | `Navigation` title 槽位，**几何对齐 `ThreadDetail` 顶栏**（返回 44 圆钮 + 吧名 58% 宽胶囊居中），两元素同挂 `ImmMaterial.seg(false)` | ✅ **代码已落地**（见下方落地清单） |

> ⚠️ **不要无脑推广**：每页都要过 §6.10 的回归清单，尤其**手势冲突**（页面内 `parallelGesture` / 横滑切页）与**返回键**。
> 二级页（`ThreadList` / `ThreadDetail`）本身已有导航语义，加 `Navigation` 壳前先确认不与宿主 `Index.ets` 的返回链打架。

**`ForumsTab.ets` 落地清单（2026-09-10，与 `HomeTab` 同机制）**：

- 开关 `FORUMS_OFFICIAL_TITLE_BAR = true`（置 `false` 一键回退），`FORUMS_TITLE_BAR_HEIGHT = 98`
  = 44(状态栏让位) + 44(按钮行高) + 10(底部呼吸)，与原悬浮 `TopBar()` 的 `padding` 逐项对齐。
- 原 `build()` 根 `Stack` 抽成 `ForumsContent()`（`onAreaChange` 宽屏判定一并搬入），`TopBar()` 改为 `if (!FORUMS_OFFICIAL_TITLE_BAR)` 才挂；
  新增 `ForumsTitleBar()` 作槽内版本，`build()` 走
  `Navigation(){ ForumsContent() }.title({builder, height: 98}, {barStyle: BarStyle.STACK, backgroundColor: Color.Transparent}).mode(Stack).hideTitleBar(false).hideBackButton(true).width/height('100%').backgroundColor(Transparent).clip(false).expandSafeArea([SYSTEM],[TOP,BOTTOM])`。
- 三枚 44 圆钮：`backgroundColor(Color.Transparent)`（清 `Button` 默认品牌蓝填充）+ `systemMaterial(ImmMaterial.seg(false))` + `borderRadius(Radius.full)`；
  **删掉**槽内版本的 `Theme.segGlass` / `manualGlassBorder` / `backgroundBlurStyle(BlurStyle.Thin, {scale:0.85})` / `segGlassShadow` 四项自绘玻璃。
- 几何零改动：`List` 顶部让位占位仍是改造前既有的 **90**、排序菜单隐形锚点仍是 `position({ top: 99, right: 16 })` ——
  `barStyle: STACK` 下内容依旧延伸到标题栏之下，与改造前悬浮层行为等价；`zIndex(14)` 仅在兜底路径需要，故槽内版本不写。
- 旧 `TopBar()` 原样保留（兜底路径），开关置 `false` 即回到 `backgroundBlurStyle` 真磨砂自绘。

**`ThreadDetail.ets` 落地清单（2026-09-10，与 `HomeTab` / `ForumsTab` 同机制）**：

- 开关 `THREAD_DETAIL_OFFICIAL_TITLE_BAR = true`（置 `false` 一键回退）、`THREAD_DETAIL_TITLE_BAR_HEIGHT = 98`
  = 44(状态栏让位) + 44(胶囊行高) + 10(底部呼吸)，与原悬浮顶栏几何逐项一致。
- 本页是**二级路由页**，故槽位路径的运行时判据取 `THREAD_DETAIL_OFFICIAL_TITLE_BAR && this.materialSupported`
  （与底部 `ImmersiveDockShell` 同一判据）：低版本 / 关闭沉浸光感时自动回到自绘 `LegacyTopBar` 兜底，不会出现「槽位里没有玻璃」。
- 结构：原 `build()` 根 `Stack` 抽成 `DetailRoot()`（屏宽维护 `onAreaChange` 一并搬入）；原内联悬浮顶栏抽成 `LegacyTopBar()`，
  `ContentLayer()` 内改为 `if (!(THREAD_DETAIL_OFFICIAL_TITLE_BAR && this.materialSupported)) { this.LegacyTopBar() }`；
  新增 `DetailTitleBar()` 作槽内版本，`build()` 走 `Navigation(){ DetailRoot() }.title({builder, height: 98}, {barStyle: BarStyle.STACK, backgroundColor: Color.Transparent})...`。
- 三元素（返回 44 钮 / 分享 44 钮 / 吧名胶囊 58% 宽）统一：`backgroundColor(Color.Transparent)`（清 `Button` 默认品牌蓝填充）
  + `systemMaterial(ImmMaterial.seg(false))` + `borderRadius(Radius.full)`；**删掉** `Theme.segGlass` / `manualGlassBorder` /
  `backgroundBlurStyle(BlurStyle.Thin, {scale:0.85})` / `segGlassShadow` 四项自绘玻璃；旧外壳 `Stack` 的透明 `border` / `shadow`
  清底与 `zIndex(10)` 一并去掉（槽内无叠层序需求）。
- 几何零改动：`Scroll` 首项占位仍是 `height(98)`（正好等于 title bar 高度），`TOP_FADE_BAND_HEIGHT = 88` 保持原值。
- **与底部官方槽位合体**：`Navigation` titleBar（顶）+ `ImmersiveDockShell` 的 `Tabs(barPosition: End)` `barFloatingStyle`（底），
  本页即「上下两端官方槽位」的样板页（§9.3 #6 的目标形态）。
- ⚠️ **真机必测**：二级路由页的**系统侧滑返回 / 返回键**是否仍正常（`Navigation` 壳不接管路由时应无副作用；若被吞掉手势，
  把 `THREAD_DETAIL_OFFICIAL_TITLE_BAR` 置 `false` 即整行回退到原悬浮顶栏，零风险）。

**`Favorite.ets` 落地清单（2026-09-10，与 `HomeTab` / `ForumsTab` 同机制）**：

- 开关 `FAV_OFFICIAL_TITLE_BAR = true`（置 `false` 一键回退），`FAV_TITLE_BAR_HEIGHT = 98`
  = 44(状态栏让位) + 44(按钮行高) + 10(底部呼吸)，与原 `TopBar()` 的 `padding` 逐项一致；
  内容让位常量（98 + Tab 36 + 间隙 14 = 148）**一行未改**。
- 原 `build()` 根 `Stack` 抽成 `FavContent()`（分类视图 / 搜索态 / 浮层 / 排序菜单隐形锚点 / `bindSheet` 全部留在其中），
  `TopBar()` 改为 `if (!FAV_OFFICIAL_TITLE_BAR)` 才挂；新增 `FavTitleBar()` 作槽内版本，
  `build()` 走 `Navigation(){ FavContent() }.title({builder, height: 98}, {barStyle: BarStyle.STACK, backgroundColor: Color.Transparent}).mode(Stack).hideTitleBar(false).hideBackButton(true).width/height('100%').backgroundColor(Transparent).clip(false).expandSafeArea([SYSTEM],[TOP,BOTTOM])`。
- **五种形态塞进同一个 title builder 条件渲染**（根态 / 编辑态 / 搜索态 / 分类内 / 吧内）；三颗共享小组件收口：
  `FavSlotCircleBtn`（44 圆钮：返回 / 搜索）、`FavSlotSortBtn`（⇅ 排序）、`FavSlotTextBtn`（文字胶囊：编辑 / 备份），
  统一 `systemMaterial(ImmMaterial.seg(false))`（THIN 中性档）+ `borderRadius(Radius.full)`；
  `Button` 一律 `backgroundColor(Color.Transparent)` 清默认品牌蓝填充；**删掉** `segGlass` / `manualGlassBorder` /
  `backgroundBlurStyle(BlurStyle.Thin, {scale:0.85})` / `segGlassShadow` 四项自绘玻璃；`zIndex(14)` 槽内不需要，去掉。
- 几何零改动：排序菜单隐形锚点仍是 `position({ top: 99, right: 16 })`（§6.9 的 bindMenu 机制不变，与 TopBar 宿主无关）。
- **附带收益**：搜索态 `TextInput` 原挂的 `ImmMaterial.control()` 在页面 body 属 out of scope 从不渲染
  （一直是 `backgroundEffect` 在撑观感），进槽位后**首次真正生效**；按坑 24 口径删掉与其双叠的
  `shadow` + `backgroundEffect`。⚠️ 真机必测：搜索态的**聚焦 / 键盘避让 / 退出态**（同 §9.3 #7 的关注点）。
- ⚠️ **真机必测**：分类 Tab 滑动转场（`catTabTransition`）、宿主 `Index.ets` 横滑切 Tab / `onBackPress` 拦截、
  各形态切换（进分类 / 进吧 / 编辑 / 搜索）、排序菜单弹出位置、深色模式。
- **追加（同日）：「吧分类 / 自定义分类」胶囊行并入槽位第二行**。`FavTitleBar()` 改为 `Column`：
  第一行 = `FavTitleBarRow()`（五形态按钮行），第二行 = 分类胶囊行（仅根态显示，条件与让位常量同源）；
  title 高度从固定 98 改为 `favTitleBarHeight()` 动态（根态 98+42 / 其余 98），新增常量
  `FAV_CAT_TAB_ROW_HEIGHT = 42`（= 2(原 top:100 - 98) + 32(胶囊高，显式 `height(32)` 对齐实测带 100~132vp) + 8(底部 `Spacing.sm`)）。
  胶囊挂 `ImmMaterial.seg(active)`（选中 REGULAR / 未选中 THIN，与旧 Regular/Thin 双档模糊同构），
  `Button` 清默认品牌蓝填充，四项自绘玻璃全删；`FavContent` 内 `CategoryTabs()` 改为 `!FAV_OFFICIAL_TITLE_BAR` 才挂。
  ⚠️ 观感偏差（已接受）：旧 `CategoryTabs` 的 `listBaseTransition` 左让位动画不再适用 —— 进退收藏夹时
  胶囊行改为随 title 高度直接出现/消失，不再随内容区滑动。

**`ThreadDetail.ets` 排序胶囊（正序 / 只看全部）官方槽位落地清单（2026-09-10）**：

- 先复核官方边界（本点位起初按 §5 被判「页面中部玻璃无官方宿主」）：官方 A 档「按钮与选择类」**只有 Slider / Toggle / Select**
  （官方文档 §4.1）。`Button` / `Chip` / `SegmentButton` 虽在 §6.3 有组件级材质字段（`Chip` 的 `backgroundSystemMaterial` /
  `activatedBackgroundSystemMaterial`），但**生效区域仍受 §4.2 限定** —— 只有 `Navigation` 标题栏与 `Tabs(barPosition: End)`
  底部 TabBar。故「就地给页面中部两枚胶囊挂 `systemMaterial`」这条路不存在（必判 out of scope），只能把胶囊**送进槽位**。
- 落地方式：给排序行单独搭一个**「只有 tabBar 的真实 Tabs」壳** `SortPillShell()`，把排序行放进 `.tabBar()`：
  `Tabs({ barPosition: BarPosition.End }) { TabContent().tabBar(this.SortRowInSlot()) }`；
  壳高 = `barHeight` = `THREAD_DETAIL_SORT_ROW_HEIGHT`(46)，配 `barOverlap(true)` / `vertical(false)` / `scrollable(false)` /
  `barBackgroundColor(Transparent)` / `backgroundColor(Transparent)` / `clip(false)`；
  **底距 = `dockBottomMargin() + dockPillHeight()`**（30 + 66 = 96）—— 与改造前 `SortRowOverlay` 的 `margin-bottom` 逐项相同。
- **背板处理是关键**：本壳**不传** `.barFloatingStyle(...)`，官方悬浮背板（`barFloatingStyle` + `systemMaterial`）整体不生成，
  因此不会凭空多出一条 46 高玻璃底。依据：`Index.ets` 收藏编辑态注释「编辑态整体不传 floating style（Optional 传 undefined）
  彻底移除残留底栏」→ 传 `undefined` / 不传 是已验证的移除手段。`TabContent` 留空（内容区 = 46 - 46 = 0），壳里实际只有 tabBar 一行。
  **但「不传 floating style」只管官方玻璃背板，`Tabs` 底栏还有一层默认模糊背板**（`barBackgroundBlurStyle` 默认值
  `BlurStyle.COMPONENT_REGULAR`）—— 真机发现它在胶囊后渲染成一条遮挡内容的磨砂板，已补 `.barBackgroundBlurStyle(BlurStyle.NONE)`（坑 26）。
- 槽内胶囊 `SortPillInSlot()`：几何与旧 `SortPill` 逐项一致（高 34 / 左右 `padding` 14 / 字号 12 / `Radius.full` / 选中与未选中两态），
  只把玻璃换成官方材质 —— `backgroundColor(Color.Transparent)`（清 `Button` 品牌蓝默认填充）+
  `systemMaterial(ImmMaterial.seg(active))` + `Radius.full`，**删掉** `segGlass` / `manualGlassBorder` / `backgroundBlurStyle` /
  `segGlassShadow` 四项自绘玻璃；文字色沿用系统可反色资源（`font_secondary` / `segActiveText`）。观感与顶栏 `DetailTitleBar` 同款
  （`seg(false)` THIN / `seg(true)` REGULAR），上下两端一致。
- 开关 `THREAD_DETAIL_SORT_OFFICIAL_SLOT = true`（置 `false` 即回到旧 `SortRowOverlay` 自绘玻璃浮层；`ReplyControls()` / `SortPill()`
  原样保留，两条路径的几何常量同源）。
- ⚠️ **真机必测（本次新增判据）**：**「底部 TabBar 槽位**子树**内挂 `systemMaterial` 是否生效」**。此前真机验证过的「槽位子树」只有
  `Navigation` 标题栏子树（§1.5）与 `CustomDialog` 子树（§1.4）；`Tabs` 这一侧目前只有「`barFloatingStyle.systemMaterial` 作用于
  bar 本体」这一条（§1.1 第 22 行），**子树内元素挂材质尚无真机验证**。若 hilog 报 `Material inactive: out of scope`，两枚胶囊会
  退化成「透明底」（自绘玻璃已按官方口径删除）→ 把 `THREAD_DETAIL_SORT_OFFICIAL_SLOT` 置 `false` 即整行回退。
  同时需确认：① 新壳没有引入多余背板 / 阴影；② 排序行位置与改造前像素级一致（钮底距岛顶 8vp、宽 = 屏宽 - 64vp、靠左排列）；
  ③ 该 46 高区域的点击与滚动穿透行为与改造前一致（~~壳宽 100%，与旧 `Column` 同款覆盖范围~~ → 该推断已被推翻，见下方 2026-09-12 更正）。

> **2026-09-12 更正并已落地（真机验收）**：上面第 ③ 条是按**错误前提**写的（当时以为「覆盖范围与旧 `Column` 相同」就等于「行为一致」）。
> 经 `ThreadList` 同类空壳实测（§6.13 / 坑 30）：**空 `Tabs` 壳开全宽时，系统 TabBar 页签节点会吞掉该横带内下层列表的竖滑**，
> 且 `hitTestBehavior` 挂不到系统节点上、修不了（已双向验证）→ 本壳 `.width('100%')` 时那 46 高区域内确实吃掉了滚动。
> 修复（A 方案，与 `ThreadList` FAB 壳同一套做法）：
> ① 壳宽 `.width('100%')` → `.width(this.sortPillShellWidth())` = `64 + 6 × fs(12, fontScale) + 12`
> （两枚胶囊宽度随字号自适应，标准 148 / 极大 172，宁宽不挤）；
> ② 因排序行**靠左**排列，壳外垫一层**全宽 `Row`**（`justifyContent(Start)` + `padding({ left: 32 })`）把壳钉回改造前左缘
> —— `Stack(alignContent: Bottom)` 会把收窄后的壳**水平居中**，且 `margin` 拉不回来（居中是按含 margin 的外框算的）；
> ③ `Row` 与壳都挂 `hitTestBehavior(HitTestMode.None)`；
> ④ 壳内 `SortRowInSlot()` 行宽由写死的「屏宽 − 64vp」改 `'100%'`（参照物从屏宽变壳宽，写死会溢出）。
> 结果：**两枚胶囊位置 / 大小 / 间距与改造前逐项一致（左缘 32 = 悬浮岛内评论条同一条竖线），46 高横带内两侧恢复可竖向滑动，
> 真机确认正常**。32 的来路：改造前行宽 = 屏宽 − 64vp 由撑满壳宽的 `Column` 居中 → 左缘 = (屏宽 − (屏宽 − 64)) / 2 = 32。

**`Search.ets` 落地清单（2026-09-10，与 `HomeTab` / `ThreadDetail` 同机制；⏳ 待真机验证）**：

- 开关 `SEARCH_OFFICIAL_TITLE_BAR = true`（置 `false` 一键回退），`SEARCH_TITLE_BAR_HEIGHT = 98`
  = 44(状态栏让位) + 40(搜索行高) + 14(底部呼吸)，与旧 `FloatingHeader()` 的 `padding` 逐项对齐。
- 结构：原 `build()` 根 `Stack` 抽成 `SearchRoot()`（背景 + `ImmersiveShell`/`LegacyModuleBar` + `onAreaChange` 屏宽维护一并搬入），
  `FloatingHeader()` 改为 `if (!(SEARCH_OFFICIAL_TITLE_BAR && this.materialSupported))` 才挂；
  新增 `SearchTitleBar()` 作槽内版本，`build()` 走
  `Navigation(){ SearchRoot() }.title({builder, height: 98}, {barStyle: BarStyle.STACK, backgroundColor: Color.Transparent}).mode(Stack).hideTitleBar(false).hideBackButton(true).width/height('100%').backgroundColor(Transparent).clip(false).expandSafeArea([SYSTEM],[TOP,BOTTOM])`。
- 本页是**二级路由页**，故槽位路径判据取 `SEARCH_OFFICIAL_TITLE_BAR && this.materialSupported`（与 `ThreadDetail` 同判据），
  低版本 / 关闭沉浸光感自动回到 `backgroundBlurStyle` 真模糊兜底。
- 三元素统一 `ImmMaterial.seg(false)`（THIN 中性档）：返回钮 36 / 搜索钮 36（`Button` 一律 `backgroundColor(Color.Transparent)` 清默认品牌蓝填充）
  / 搜索框外层 `Row`（`borderRadius(20)` 保持原几何，`TextInput` 自身 `backgroundColor(Color.Transparent)` 透出材质）；
  **删掉**槽内版本的 `segGlass` / `manualGlassBorder` / `backgroundBlurStyle(Thin/Regular, {scale:0.85})` / `segGlassShadow` 四项自绘玻璃，
  以及旧外壳 `Column` 的 `zIndex(2)`。
- 槽内文字色改用系统可反色资源（`font_primary` / `font_secondary` / `icon_primary`），满足官方自动反色前提；
  「xmark 清除钮」是实心小圆底（非玻璃元素）保留原样，未挂材质故无叠用冲突。
- 几何零改动：`HEADER_TOP_SPACE`(114) / `BOTTOM_BAR_SPACE`(130) / `TopFadeOverlay` 高度 / 底部 `barFloatingStyle` 参数一律未动。
- ⚠️ **真机必测（本页专属关注点）**：① `TextInput` 在 title builder 内的**聚焦与键盘避让**（`keyword` 每次变更会触发
  `if (this.keyword.length > 0)` 分支更新，需确认不会重建 `TextInput` 导致失焦）；② 清除钮 / 回车提交 / 搜索钮提交三条路径；
  ③ 底部官方 `Tabs` 悬浮条与顶部 `Navigation` 槽位共存（本页即第二处「上下两端官方槽位」）；④ 低版本兜底路径观感；
  ⑤ 全部 `systemMaterial` 生效、无 `Material inactive: out of scope`。异常时把 `SEARCH_OFFICIAL_TITLE_BAR` 置 `false` 即整行回退。

**`SubPostDetail.ets`（帖子详细页 → 「查看更多楼中楼」）落地清单（2026-09-11，几何对齐 `ThreadDetail` 顶栏）**：

- 开关 `SUBPOST_OFFICIAL_TITLE_BAR = true`（置 `false` 一键回退），`SUBPOST_TITLE_BAR_HEIGHT = 98`
  = 44(状态栏让位) + 44(钮/胶囊行高) + 10(底部呼吸)，与原悬浮顶栏 `padding` 逐项对齐。
- 本页是**二级路由页**（`ThreadDetail` / 消息定位 `pushUrl` 进入），槽位路径判据取
  `SUBPOST_OFFICIAL_TITLE_BAR && this.materialSupported`（与 `ThreadDetail` / `Search` 同判据），
  低版本 / 关闭沉浸光感时自动回到自绘悬浮顶栏兜底，不会出现「槽位里没有玻璃」。
- 结构：原 `build()` 根 `Stack` 抽成 `SubPostContent()`（Loading/Error/Empty/Success 四态、`Scroll` 四态、
  `showLinkDialog` 浮层全部留在其中，一行未动）；原 `TopBar()` 改名 `LegacyTopBar()` **原样保留**，
  `SubPostContent()` 内改为 `if (!(SUBPOST_OFFICIAL_TITLE_BAR && this.materialSupported)) { this.LegacyTopBar() }`；
  新增 `SubPostTitleBar()` 作槽内版本。
- 槽内版本几何 = 视觉参照物 `ThreadDetail.DetailTitleBar()`：`Stack` + `Row(返回钮 44 + Blank)`（`align(Start)`）
  + 居中吧名胶囊（`Button`，宽 `58%` / 高 44 / 左右 `padding` 16 / `Radius.full` / `fontSize` 16 / Medium）；
  外层 `height(SUBPOST_TITLE_BAR_HEIGHT)` + `padding{left/right: Spacing.lg, top: 44, bottom: 10}`。
  差异仅一处：`ThreadDetail` 右侧是分享钮 44，本页无分享功能，故只留 `Blank()` 撑开（返回钮落点不变）。
- 两元素（返回钮 / 吧名胶囊）统一：`backgroundColor(Color.Transparent)`（清 `Button` 默认品牌蓝填充）
  + `systemMaterial(ImmMaterial.seg(false))`（THIN 中性档，与帖子详细页顶栏同一套材质语言）+ `borderRadius(Radius.full)`；
  图标/文字色用系统可反色资源（`icon_primary` / `font_primary`），满足官方自动反色前提；
  槽内**不挂** `border` / `backgroundBlurStyle` / `shadow`（§4.4 口径）。
- 几何零改动：`Scroll` 首项占位仍是 `height(98)`（正好等于 title bar 高度）；`subpost_scroll_content` 的
  `padding` 与滚动定位偏移（`targetY - 120`）保持原值；`BottomFadeOverlay` / 链接确认浮层一律未动。
- 兜底路径（开关 false / 低版本）与改造前**逐字节一致**：`LegacyTopBar()` 仍是「透明底 + `shadow(glassShadowStyle)`
  + `backgroundEffect(ImmBlur.control())` + `systemMaterial(ImmMaterial.control())`」的自绘真磨砂自绘浮层。
- ⚠️ **真机必测**：① 二级路由页的系统**侧滑返回 / 返回键**（`Navigation` 壳不应吞手势，异常时置 `false` 整行回退）；
  ② 消息通知定位链路（`notifyCommentPid` 高亮 + `scrollTo` 偏移，顶栏高度未变故偏差为零）；
  ③ 吧名超长时的 `Ellipsis`（胶囊 `constraintSize maxWidth: '85%'`）；④ 深色模式与字号缩放（`fontScale`）；
  ⑤ 全部 `systemMaterial` 生效、无 `Material inactive: out of scope`。
- 卡片圆角（2026-09-11 用户指定）：父楼层卡与楼中楼回复卡统一常量 `SUBPOST_CARD_RADIUS = 26`
  （改动前分别是 `Radius.lg(16)` / `Radius.md(12)`），宽高 / 间距 / 内边距一行未改；
  同页「链接跳转确认」弹窗卡片沿用工程「居中确认卡」统一规范 32vp，不在该常量管辖范围。
- 滚动区底部留白：**维持改造前原值 `Spacing.xl(20)`**（滚动内容 `Column` 的 `padding.bottom`）。
  历史与结论（2026-09-11，勿重复踩坑）：曾按「与帖子详细页一致」改为 `160`、再降到 `96`，用户真机
  查看后要求**回退初始值**，现已完全复原、无专属常量。经验：`ThreadDetail` 的 `padding.bottom = 160`
  里含底部悬浮回复岛让位 96（岛底距 30 + 岛高 66），**没有底部悬浮栏的页面照抄 160 会明显偏空**，
  即便折中取 96 也仍偏离本页原有观感——跨页对齐「留白」时先确认对方数值里是否掺了浮层让位。

---

## 10. 每改一个点位都要跑的自测清单

- [ ] 构建通过（`tools/build.ps1` → 含 `BUILD SUCCESSFUL`）
- [ ] 打开/关闭正常，**关闭后能再次打开**（`@Watch` 状态同步，最易出问题）
- [ ] 点遮罩 / 返回键：语义与原实现一致（该不关的不关、该关的关）
- [ ] 内容随状态实时刷新（`@Link` 是否生效）
- [ ] 卡片宽度 / 圆角 / 内边距 / 底部锚点与原实现目视一致
- [ ] 卡内无多余内缩（§7 偏差 ②）
- [ ] 深色模式正常
- [ ] 材质观感确认（无 out of scope 日志）
- [ ] **弹窗内按钮**：材质生效（无 out of scope）、底色为半透明（未盖成实底）
- [ ] 低版本设备（API 23~25）不崩、退化为系统默认样式
- [ ] **顶部槽位点位**（§6.10）：标题栏内材质生效 + 四边几何与改造前逐项一致 + 内容让位常量未被改坏
- [ ] **引入 `Navigation` 壳的页面**：页面内手势（`parallelGesture` / 横滑）/ 系统返回键 / 宿主切 Tab 全部回归
- [ ] 滚动内容从标题栏下穿过时的层次与流畅度（`clip(false)` + `barStyle: STACK`）
- [ ] **自建空 `Tabs` 壳（TabBar 槽位）**：壳宽已收敛到「目标元素实际占位」（非 `'100%'`）+ 显式 `.barBackgroundBlurStyle(BlurStyle.NONE)` + **在壳所在的那一条横带上、目标元素左右两侧拖动，下层列表仍能正常滚动**（§6.13 / 坑 30）

---

## 11. 兼容与降级

- 工程 `compatibleSdkVersion` 仍是 `6.1.0(23)`；**API 23~25 设备上 `systemMaterial` 字段会被忽略** → 弹窗退化为系统默认样式（不崩），与工程其他 `systemMaterial` 点位的既有降级口径一致。
- **（2026-09-10 加固）材质门限 `>= 23` → `>= 26` ＋ 低版本安全网**：`Theme.initMaterialSupport()` 改为 `sdkApiVersion >= 26` **且** `uiMaterial` 命名空间可构造（try/catch 探测）；`Theme.ets` 内 18 处 `new uiMaterial.ImmersiveMaterial(...)` 统一收口到 `createMaterial()`，不支持 / 构造失败时返回 `undefined`（官方语义＝无材质），`ImmMaterial.*` 与 `ensureXxx()` 返回类型随之放宽为 `| undefined`、**调用点零改动**。原门限 `>= 23` 会让 API 23~25 误入材质路径（`23` 是 HDS `hdsMaterial` 的起始版本），且 `Index.ets` 底栏有一处 `isSupported() ? Color.Transparent : Theme.manualGlass(...)` 在低版本会丢掉兜底色 —— 收紧后两处一并归位。构建已验证 `BUILD SUCCESSFUL`。
- **顶部槽位（§6.10）在 API 23~25 上同样只降「材质」不降「结构」**：`Navigation` / `barStyle` / `expandSafeArea` 都是 API 12~14 的老能力，标题栏照常渲染、几何不变，只是槽内**没有玻璃**（退化为纯文字 + 图标）。
  ⚠️ 这与 `HOME_OFFICIAL_TITLE_BAR = false` 的兜底路径**不自动等价**（兜底路径才有 `backgroundBlurStyle` 真模糊）—— 若要求低版本也有磨砂，需再加一层按 `MaterialManager.getApiLevel()` 判定的分支。
- 构建期 `'systemMaterial' ... since SDK version 26.0.0 ... compatible SDK version is 6.1.0(23)` 的 WARN 是**已知噪音**，不阻塞。
- `barFloatingStyle` 的对象字面量传 `systemMaterial` **不会**触发该 WARN；页面直接 `.systemMaterial()` 会。

---

## 12. 变更记录

| 日期 | 变更 |
|---|---|
| 2026-09-10 | 创建本文档。收录「系统 CustomDialog 吃官方材质」的完整经验：判定速查表（§1）、三条硬约束（§3）、可复制模板（§4）、宿主选型表（§5）、实测记录（§6）、偏差与坑位（§7/§8）、待迁移清单（§9）。同步更正 `immersive-material-guide.md` §8/§9/§10.3 与 `immersive-light-sense-api26-official.md` §14.5 的旧口径 |
| 2026-09-10 | 追加「弹窗内 `Button` 也吃材质」：`SignAllDialog` 三个按钮挂 `ImmMaterial.accent()` / `cardAction()`，**真机确认生效且观感满意**。同步更新：§1.1 速查表新增行、§1.4 新判据（A 档宿主**子树**合法）、§6.2 效果记录与可复制写法、§8 坑位 10~12、§10 自测清单 |
| 2026-09-10 | **材质门限加固**：`Theme.ets` 能力门限 `>= 23` → `>= 26`（＋ `uiMaterial` 命名空间探测），18 处 `ImmersiveMaterial` 构造收口到 `createMaterial()`（低版本 / 构造失败返回 `undefined`），`ImmMaterial.*` 返回类型放宽为 `| undefined`（调用点零改动）；§11 同步。并更正三处旧口径：`immersive-material-guide.md` §1/§4.1/§10.2、`immersive-light-sense-api26-official.md` §1.2/§14.3/§14.5/§14.6、`user-profile-delivery.md` 的「API 23+」表述。构建 `BUILD SUCCESSFUL` |
| 2026-09-10 | 第二处迁移：进吧页关注吧长按菜单 `ForumMenuDialog` → 系统 `CustomDialog`（§6.3）。新增经验「可空对象（`Xxx \| null`）不能直接 `@Link` 进弹窗，改用基本类型快照」；§9.1 第 3 项标记完成并记录「此处不用 `bindMenu` 的理由」 |
| 2026-09-10 | 第三处迁移：收藏页置顶确认 `PinConfirmDialog` → 系统 `CustomDialog`（§6.4）。新增关键经验「**一个状态变量只能挂一个 `@Watch`**，桥接会顶掉原有 `@Watch`（本例 `syncBackState`），须在桥接回调里代调」；另记「文案全部走快照，关闭瞬间清空目标对象不会让关闭动画文案变空」「关闭入口收敛成单一方法」；§9.1 第 7 项标记完成并记录「此处不用 `AlertDialog` 的理由」 |
| 2026-09-10 | 第四处迁移：收藏页批量删除收藏确认 `AlertDialog.show()` → `CustomDialog`，位置/几何对齐置顶弹窗（§6.5）。`PinConfirmDialogCard` 泛化为通用 `ConfirmDialogCard`（文案走 `@Link` 快照、配色走普通成员 `danger`）。`Theme.ets` 新增与 `accent` 同构的 `ImmMaterial.danger(isDark)` 危险色材质槽位。新增经验「AlertDialog 版式写死且不显式传材质就是白底，本工程二次确认统一走 CustomDialog」「新弹窗须三处补回退链（`syncBackState` / `@Watch` 回调 / `onBackRequest`）」。§8 补坑位 13~15，§9.1 补第 11 项，§9.2 记录剩余 1 处 AlertDialog（删除分类） |
| 2026-09-10 | 第五处迁移：收藏页分类管理菜单 `CategoryManageSheet` 自绘浮层 → `CustomDialog`（§6.6），位置/几何与前两个弹窗一致（底部 110 居中卡片）。这是内容最复杂的一处（信息行 + 原地重命名编辑态 + 菜单行 + 取消按钮），新增三条关键经验：「**`@Builder` 不能跨 struct 调用** —— 卡内元素少的复制进 struct、多弹窗共用的抽全局 `@Builder function`，`@BuilderParam` 在 `builder:` 属性传参下 `this` 指向子组件故不可用」「可空对象用『基本类型快照 + 对象 `@Watch` 桥接』，对象换新时弹窗内可实时刷新」「快照在关闭时不要清空，否则关闭动画期间卡内内容会变空」。§8 补坑位 16~17，§9.1 第 9 项标记完成（记录「不用 `bindSheet` 的理由」），§9.2 更新剩余 AlertDialog |
| 2026-09-10 | 第六处迁移：收藏页「删除分类」确认 `AlertDialog.show()` → `ConfirmDialogCard` + `danger: true`（§6.7），位置/几何与前三个弹窗一致。纯套 §6.5 模板（无新坑），但明确三条：「`ConfirmDialogCard` 已三处共用，加新点位只需一组文案快照 + 一个 controller + `syncBackState` / `onBackRequest` 各补一行，别再复制模板」「只用于取 `id` 的目标对象无需 `@Watch` 桥接（对比 §6.6 坑 2）」「两级弹窗间的 300ms 延时保留，避免同位置叠卡」。**至此全工程 `AlertDialog` 清零**；§9.2 相应更新 |
| 2026-09-10 | 第七处迁移（**首次引入 `bindSheet`**）：收藏页「移入分类」抽屉自绘浮层 → 系统半模态（§6.8）。核心经验「**形态决定宿主**」—— 同页同是底部浮层，§6.6 的分类管理菜单是「贴底卡片」故走 `CustomDialog`，本处是「抽屉」故走 `bindSheet`（`CustomDialog` 做不到满宽贴边 + 只圆顶部两角）。几何对齐：`height: '62%'`（用 `Length` 而非 `SheetSize`，否则套不上非标准档位）/ `maskColor` / `radius: {topLeft,topRight}` / `dragBar: false` / `showClose: false` / `preferType: SheetType.BOTTOM`；容器四项交 `systemMaterial`。新招「**`$$` 双向绑定**」：`.bindSheet($$this.showXxx, ...)` 让手势下滑关闭自动回写状态并触发 `@Watch`（单向绑定会残留下次打不开，§8 坑 19）。`Theme.ets` 新增 `ImmMaterial.sheet()`（复用 `ensureDialog()` 实例）。卡内条目 Row / 完成按钮一并材质化。§8 补坑位 18~19，§9.1 第 10 项标记完成 |
| 2026-09-10 | 第八处迁移（**首次引入 `bindMenu`**，五处一次改完）：`Favorite.SortMenuPanel` / `ForumsTab.ForumSortDialog` / `UserProfile.PostSortMenu`（用户点名的三处）**+ 顺带发现的同款残留** `FollowList.SortMenuPanel` / `BlacklistManager.SortMenuPanel` 自绘下拉浮层 → 系统 `bindMenu`（§6.9）。核心经验：`bindMenu` 的锚定基准是**触发组件**而非屏幕，而各页排序钮都不在 TopBar 最右端（右侧还有编辑/搜索/黑名单/深色钮）→ 用 **1×1 隐形锚点**（`position({ top: 99, right: 16 })` + `hitTestBehavior(HitTestMode.None)`）挂 `bindMenu`，配 `Placement.BottomRight` 把菜单右下角精确落回原坐标；再用 `targetSpace: LengthMetrics.vp(0)`（since 26.0.0）抵消系统默认间距，菜单顶边才等于原 `top: 100`。菜单外壳（全屏遮罩 / `position` / 玻璃或 `bgElevated` 自绘底 / 弹出动画）全删，只留菜单项内容（宽 210 / 180、内边距、选中高亮 + ✓ 零改动）。`$$` 双向绑定与 `applyXxx` 内置置 false 可共存；不需要纳入 `favCanGoBack`（系统菜单自己消费返回键）。`Theme.ets` 新增 `ImmMaterial.menu()`。顺带清掉 3 条无效 `systemMaterial` 的 out of scope WARN（`UserProfile` / `FollowList` / `BlacklistManager`）。§8 补坑位 20~21，§9.1 第 4 / 8 项标记完成并新增第 12~14 项 |
| 2026-09-10 | 第九处迁移（**首次「顶部槽位」**，也是 B 档的第一条出路）：首页吸顶「推荐 / 关注动态 / 搜索圆钮」从页面 body 自绘浮层 → **`Navigation` 标题栏**（`HomeTab.ets`，§6.10）。核心经验：**B 档组件的生效区域就是「Navigation 标题栏」，自定义 title builder 的子树同样合法**（§1.5）—— 与 §1.4「A 档宿主子树合法」并列成对，禁区收敛为「页面 body 里的自绘浮层」一条。落地写成**开关式**（`HOME_OFFICIAL_TITLE_BAR` / `HOME_TITLE_BAR_HEIGHT = 108`），旧 `HomeHeaderOverlay()` **原样保留**，常量置 false 即一键回退。写法要点：`barStyle: BarStyle.STACK`（不设即失去沉浸）+ `hideTitleBar(false)` + `hideBackButton(true)` + `mode(NavigationMode.Stack)` + `backgroundColor(Transparent)` + `clip(false)` + `expandSafeArea(TOP,BOTTOM)`；title options 的 `backgroundColor` 必须显式透明；槽内元素**删掉** `backgroundColor / border / backgroundBlurStyle / shadow` 四项（§4.4 口径）；几何（top44 / bottom20 / Spacing.lg / space16 / padding22+9 / fontSize16 / 圆钮44）与内容让位 `HOME_TOP_PAD = 98` **一行未改**，真机已验「已生效」。`Theme.ets` 新增**中性档** `ImmMaterial.seg(active)`（REGULAR / THIN，无 `materialColor`）—— 不用 `tabActive` 是因为它自带品牌蓝赋色，会改掉「去蓝底、状态靠文字色」的定稿。§8 补坑位 22~25，§7 补偏差 ⑤~⑦，§9 新增 **§9.3 顶部槽位迁移清单**（7 个页面待办），§10 补顶部槽位自测项，§11 记录「API 23~25 上槽位路径只降材质不降结构，与兜底路径不等价」 |
| 2026-09-10 | 第十处迁移：进吧页 `ForumsTab` 顶部 TopBar → `Navigation` title 槽位（与首页同机制，开关 `FORUMS_OFFICIAL_TITLE_BAR`）；第十一处迁移：`ThreadDetail` 沉浸顶栏 → `Navigation` title 槽位 + 排序胶囊（正序/只看全部）→ 自建「空 tabBar 壳」Tabs 槽位（开关 `THREAD_DETAIL_OFFICIAL_TITLE_BAR` / `THREAD_DETAIL_SORT_OFFICIAL_SLOT`）。§9.3 第 4 / 6 项标记完成并附落地清单；`ThreadDetail` 成为「上下两端官方槽位」样板页 |
| 2026-09-10 | **真机反馈修复**：`ThreadDetail` 排序胶囊后多出一条遮挡内容的背板 —— 原因是 `Tabs` 底栏默认模糊背板（`barBackgroundBlurStyle` 默认 `BlurStyle.COMPONENT_REGULAR`），`barBackgroundColor(Transparent)` 与不传 `barFloatingStyle` 都管不到它；已在 `SortPillShell()` 显式 `.barBackgroundBlurStyle(BlurStyle.NONE)` 修复，构建 `BUILD SUCCESSFUL`。§8 补坑位 26，§9.3 `ThreadDetail` 落地清单同步 |
| 2026-09-10 | **真机反馈修复②**：底栏悬浮岛上方出现一条全宽「细光感线」—— 与坑 26 同源，是 `ImmersiveDockShell()` 的 `Tabs` 默认模糊背板在岛后渲染成全宽磨砂带、上边缘显线；`ImmersiveDockShell()` 同样补 `.barBackgroundBlurStyle(BlurStyle.NONE)`（岛的官方玻璃由 `barFloatingStyle.systemMaterial` 承担，不受影响），构建 `BUILD SUCCESSFUL`。坑 26 升级为「任何 `Tabs` 壳都要显式关默认模糊背板」 |
| 2026-09-10 | **真机反馈修复③**：悬浮岛上沿的「细光感线」—— 非背板（背板已随坑 26 关净），是材质**流光**：`ImmMaterial.floatingBar()` 原来传 `lightEffect: { color: undefined }`，按官方语义等于显式启用白色流光；已改 `lightEffect: null` 显式禁用，构建 `BUILD SUCCESSFUL`。§8 补坑位 27（`lightEffect` 三态语义：对象=启用 / `null`=禁用 / 不传=跟随默认） |
| 2026-09-10 | **真机反馈修复④**：悬浮岛上沿仍有一条「亮线」—— 逐像素采样全屏截图定位（页底色 `(241,245,248)`、岛体 `(254,254,254)`、左右边缘列全程页底色）：非背板（坑 26 已关净）、非流光（坑 27 已禁用），是 **THIN 材质渲染成近不透明白玻璃后与灰蓝页底的固有明暗交界**。三方案对比后用户选择**材质降档**：`ImmMaterial.floatingBar()` `THIN` → `ULTRA_THIN`（玻璃更透、边缘对比变软，保留官方材质；备选「回退自绘玻璃可彻底消线但放弃官方材质」未采用）。构建 `BUILD SUCCESSFUL`。经验：**排查"多出来的线/板"先看屏幕边缘列像素 —— 边缘列是页底色即不存在全宽元素，剩下的就是材质本体边缘** |
| 2026-09-10 | **真机反馈修复⑤（线的真凶）**：用户指出线在**排序胶囊下方**，是排序壳背板残留阴影 —— 复查 `tabs.d.ts` 发现 `barOverlap(true)` 的官方语义「底栏叠在内容之上**并带模糊背景**，默认模糊档被设为 `BlurStyle.COMPONENT_THICK`」：排序壳 `TabContent` 为空（内容区恒 0），`barOverlap` 毫无布局作用，却触发了 COMPONENT_THICK 默认模糊，残留成胶囊下的全宽渐变带 + 细线；底栏岛壳有 `barFloatingStyle` 重构整条 bar 故不受影响。已**删除 `SortPillShell()` 的 `.barOverlap(true)`**（几何零影响），构建 `BUILD SUCCESSFUL`。坑 26 同步补充：**空 tabBar 壳永远不要挂 `barOverlap`**；只有「内容需延伸到底栏之下」的壳（如岛壳）才需要它 |
| 2026-09-10 | **真机反馈修复⑥**：① `floatingBar` 从 ULTRA_THIN **调回 THIN**（修复④的降档是在"线是岛边缘"误判下选的，真凶查明后用户要求调回；`lightEffect: null` 保留）。② 排序胶囊下那层淡阴影：壳上 bar 装饰（颜色/模糊/`barOverlap`）已全关净，残留阴影实为**胶囊材质自带投影**（`seg` 的 `applyShadow: true`，两枚胶囊的阴影落在下方白卡上合并成一层）。`Theme.ets` 新增**无阴影档** `ImmMaterial.segFlat(active)`（`segActive/segIdle` 各复制一份仅 `applyShadow: false` 之差），仅 `SortPillInSlot` 换用；顶栏胶囊仍用 `seg` 带阴影版。构建 `BUILD SUCCESSFUL`。经验：**材质胶囊浮在浅色卡面上时，材质自带阴影会被卡面放大成"一层淡阴影"——不是背板，是 `applyShadow`** |
| 2026-09-10 | 第十二处迁移（顶部槽位）：收藏页 `Favorite.ets` TopBar → `Navigation` title 槽位（用户点名：排序 / 搜索 / 备份按钮改沉浸光感）。五形态（根态 / 编辑态 / 搜索态 / 分类内 / 吧内）塞进同一 title builder；三颗共享小组件 `FavSlotCircleBtn` / `FavSlotSortBtn` / `FavSlotTextBtn` 统一 `ImmMaterial.seg(false)`；开关 `FAV_OFFICIAL_TITLE_BAR` / `FAV_TITLE_BAR_HEIGHT = 98`；附带收益「搜索态 `TextInput` 的 `control()` 材质出坑（页面 body out of scope → 槽位合法），双叠的 shadow + backgroundEffect 按坑 24 删除」。构建 `BUILD SUCCESSFUL`；§9.3 第 3 项标记完成并附落地清单（含搜索态聚焦/键盘避让、Tab 转场、宿主联动三项真机必测） |
| 2026-09-10 | 第十二处迁移·追加：收藏页「吧分类 / 自定义分类」胶囊行 → title 槽位**第二行**（用户点名）。`FavTitleBar()` 改 `Column`（第一行 = `FavTitleBarRow` 五形态按钮行，第二行 = 分类胶囊行，仅根态显示）；title 高度改动态 `favTitleBarHeight()`（98 / 98+42 随形态切换），新增 `FAV_CAT_TAB_ROW_HEIGHT = 42`；胶囊 `ImmMaterial.seg(active)`（与旧 Regular/Thin 双档同构），显式 `height(32)` 对齐实测带。经验：**同一 title 槽位可以叠多行（Column），配合动态 height 即可把「吸顶多行」整体搬进槽位**；代价是行级转场动画（`listBaseTransition` 左让位）不再适用。构建 `BUILD SUCCESSFUL` |
| 2026-09-10 | 第十三处迁移：收藏页「分类备份」弹窗 `BackupDialog` 自绘浮层 → 系统 `CustomDialog`（§6.11），位置/几何与同页前四个弹窗逐项一致。纯套 §4 模板（新的 `@Watch` 顶替原 `syncBackState`，桥接回调代调；新增 `closeBackupDialog()` 收敛四处关闭入口；内联 `CardDividerLine` 规避坑 16「@Builder 不能跨 struct」）。新增一条判据：**卡内「原本无底色的透明行」不要材质化** —— 挂 THIN 材质会在玻璃卡面多出一块玻璃瓦片；只有原本有底色的元素（按钮 / 卡片 / `bindSheet` 的实底行）换成「材质 + 半透明底」才是等价替换（§6.11）。§9.1 第 5 项标记完成。构建 `BUILD SUCCESSFUL` |
| 2026-09-10 | 第十四处迁移（与上一处同批）：收藏页「导出备份授权」弹窗 `ExportDialog` → 系统 `CustomDialog`（§6.12），并按用户要求把两弹窗 UI 统一（同宽度 / 圆角 32vp / 底部锚点 / 遮罩 / `ImmMaterial.dialog()` / 同款标题区与分隔线 / 同款全宽 44 按钮，`SaveButton` 也从 200 固定宽改为卡片内全宽）。新增坑 29：**安全控件不支持通用属性**（只继承安全控件通用属性）—— 宽度必须传数值 vp、`margin` 不在白名单里要交给外层 `Row`，且样式不合法时报的是「授权失败（错误码 2）」+「文本截断即不授权」的静默失败。§9.1 第 6 项标记完成；该页五处弹窗已全部统一为系统弹窗。构建 `BUILD SUCCESSFUL`，HAP 已产出（`entry-default-unsigned.hap` 4.97MB） |
| 2026-09-11 | 第十五处迁移（顶部槽位）：帖子详细页「查看更多楼中楼」`SubPostDetail.ets` 顶栏 → `Navigation` title 槽位（用户要求：返回按钮与吧标题要「帖子详细页一样几何」的沉浸光感）。开关 `SUBPOST_OFFICIAL_TITLE_BAR` / `SUBPOST_TITLE_BAR_HEIGHT = 98`，判据与 `ThreadDetail` 同（`&& this.materialSupported`）；`build()` 根 `Stack` 抽成 `SubPostContent()`、原 `TopBar()` 保留为 `LegacyTopBar()` 兜底；槽内 `SubPostTitleBar()` 几何逐项复刻 `DetailTitleBar` —— 返回 44 圆钮 + 吧名 58% 宽胶囊居中（差异仅「本页无分享钮，右侧只留 `Blank`」），两元素均 `backgroundColor(Transparent)` + `ImmMaterial.seg(false)` + `Radius.full`，不挂 border / backgroundBlurStyle / shadow。`Scroll` 首项占位仍为 98、消息定位偏移未变。构建 `BUILD SUCCESSFUL`（24s）；§9.3 表新增第 8 项并附落地清单 |
| 2026-09-11 | 追加：`SubPostDetail.ets` 卡片圆角统一为 `SUBPOST_CARD_RADIUS = 26`（父楼层卡原 `Radius.lg(16)`、楼中楼回复卡原 `Radius.md(12)`），宽高 / 间距 / 内边距零改动；同页链接确认弹窗卡片仍是工程统一的 32vp。构建 `BUILD SUCCESSFUL`（22s） |
| 2026-09-11 | 追加：`SubPostDetail.ets` 滚动区底部留白试改（`Spacing.xl(20)` → 160 → 96）后按用户要求**回退初始值 `Spacing.xl(20)`**，代码（去掉 `SUBPOST_SCROLL_BOTTOM_SPACE` 常量）与文档均复原。失败经验：`ThreadDetail` 该处 160 含底部悬浮回复岛让位 96，无悬浮栏的页面照抄会明显偏空 |
| 2026-09-12 | 第十六处迁移（**首次把「空 tabBar 壳」用在可滚动列表之上**）：吧列表页 `ThreadList.ets` 右下角悬浮 FAB 两钮（刷新 / 加号）→ 自建「只有 tabBar 的 `Tabs`」壳槽位（§6.13），两钮换 `ImmMaterial.segFlat(false)`（无阴影档）。新增**坑 30 —— 本次唯一的坑，且两个方案双向验证**：空壳开全宽时**下层列表在壳所在那条横带内滑不动**，而给壳挂 `hitTestBehavior(HitTestMode.None)` **实测无效**（拦路的是 `Tabs` 内部**系统 TabBar 页签节点**，命中区恒等于自身矩形，该属性挂不到它身上）；唯一解是把**壳宽收窄成「目标元素实际占位」**：`width('100%')` → `THREAD_LIST_FAB_SHELL_WIDTH = 84`（右缘 28 + 钮宽 56），壳内元素照旧 `width('100%')` 跟随壳宽，故**两钮尺寸 / 右缘 / 底距逐项不变**，真机确认「已正常」。附带收益：`scale` 缩放原点随壳收窄落到两钮自身中心，`fabReveal` 淡入更贴形。同步更新：§1.1 速查表新增「自建空 `Tabs` 壳内的元素」一行、§8 补坑 30、§10 补自测项；另标注 ⚠️ `ThreadDetail.SortPillShell()` 仍是全宽壳、待复核（**下一条已销项**）。构建 `BUILD SUCCESSFUL` |
| 2026-09-12 | 第十七处迁移（**收口坑 30 在本工程的最后一处存量，A 方案正式版**）：帖子详细页 `ThreadDetail.ets` 排序胶囊壳 `SortPillShell()` 由**全宽壳**收窄为「两枚胶囊那一列」，消除该 46 高横带内吞掉下层帖子列表竖滑的死区（与 `ThreadList` FAB 壳同一套做法，双向验证过的唯一解）。三处改动全在 `ThreadDetail.ets`：① 新增 `sortPillShellWidth()` —— 两枚胶囊宽度随字号自适应，故按字号实时推算 `64 + 6 × fs(12, fontScale) + 12`（两钮左右 `padding` 4×14 + 钮间 `space` 8 + 文字宽 ≈ 6×字号 + 度量余量），标准字号 **148** / 极大字号(1.35) **172**，宁宽不挤；② `SortPillShell()` 的 `.width('100%')` → `.width(this.sortPillShellWidth())`，并**外包一层全宽 `Row`**（`justifyContent(Start)` + `padding({ left: 32 })` + `hitTestBehavior(None)`）把壳钉回改造前左缘、壳自身也挂 `hitTestBehavior(None)`、底距 `margin` 从壳移交外层 `Row`；③ `SortRowInSlot()` 行宽由写死的「屏宽 − 64vp」改 `'100%'` 跟随壳宽（参照物从屏宽变壳宽）。新增关键经验：**目标元素非贴右排列（靠左/居中）时，壳收窄后必须垫一层全宽定位容器复位** —— `Stack` 的居中是按**含 `margin` 的外框**计算的，仅调 `margin` 拉不回原位；32 的来路 = 旧行宽「屏宽 − 64vp」居中后的左缘 `(屏宽 − (屏宽 − 64)) / 2`，与悬浮岛内评论条左缘同一条竖线。两枚胶囊位置 / 大小 / 间距逐项未变，真机确认「正常」。同步更新：§6.13 通用口径（⚠️ 待复核 → ✅ 已落地并附算式与定位容器写法）、§8 坑 30（补「靠左/居中需垫全宽定位容器」）、§9.3 #6 状态改为「已完成 + 真机已验」、`ThreadDetail` 排序胶囊落地清单的 2026-09-12 更正段改为已落地。构建 `BUILD SUCCESSFUL` |
| 2026-09-12 | 第十八处迁移（**首次把「整条栏」做成空壳槽位内的玻璃**）：吧主页 `ThreadList.ets` 排序栏（热门 / 最新 / 精选）从「Scroll 内容区、吧头下方的三枚自绘真模糊胶囊」搬到**屏幕底部**，做成与首页 / 搜索页底栏同构的官方沉浸光感悬浮底栏（用户要求「跟首页一样的底栏样式」，同时右下角两枚 FAB 上挪避让）。落地四步：① 新增 `SortSlotShell()` —— 外层全宽 `Row`（`justifyContent(Center)` + `hitTestBehavior(None)`）负责居中定位与底距 `margin`，内层空壳 `Tabs` 壳宽 = `sortBarWidth()`（屏宽 − 48，下限 240，同时满足坑 30 的收窄要求）、壳高 = `barHeight` = 74、不传 `barOverlap`、显式 `barBackgroundBlurStyle(BlurStyle.NONE)`；② 新增 `SortSegBar()` / `SortSegButton()`：纯文字三等分（`layoutWeight(1)` / 高 58），选中态只用系统强调色 + 加粗，**整条背板材质由槽内那一条 `Row` 自己承担**（`ImmMaterial.floatingBar()` + `Radius.full`）；③ 开关 `THREAD_LIST_OFFICIAL_SORT_BAR` + 低版本 / 无材质回退（原 `SortTabsBuilder` 原位保留）；④ FAB 槽位壳底距 `36 → 124`（= 底栏上沿 104 + 20 呼吸），列表底部让位 `150 → 260`。**新增坑 31**：空壳上写 `barFloatingStyle` **不生成官方背板**（首次落地正是这么写的 → 真机反馈「底栏没有沉浸光感材质」），改回「材质挂槽内元素」即解决 —— 与 `FabSlotShell` / `SortPillShell` 一直是同一路数。同步更新：§1.1 速查表第 27 行补「空壳没有 `barFloatingStyle` 背板」、新增 §6.14、§8 补坑 31。构建 `BUILD SUCCESSFUL` |
| 2026-09-12 | 追加（用户反馈「底栏里没有图标、内部高度空余太多，把内部高度调低些」）：`ThreadList.ets` 底部排序栏栏高 `74 → 58`（`THREAD_LIST_SORT_BAR_HEIGHT`）、栏内三钮高 `58 → 46`，并新增 `THREAD_LIST_SORT_BAR_PADDING = 6` 让「钮高 = 栏高 − 2 × 6」自动联动（`SortSegBar` 的 `padding` 与 `SortSegButton` 的 `height` 共用这一处常量），`Radius.full` 圆角随之由 37 收成 29；栏宽（屏宽 − 48）、底距 30、三钮等分均未动。联动清理三处：① FAB 槽位壳底距 `124 → 108`（= 新底栏上沿 88 + 20 呼吸，两钮 56+12+56 与右缘 28 未变）；② 列表底部让位 `260 → 244`（= FAB 顶 232 + 12 呼吸）；③ `THREAD_LIST_FAB_SHELL_HEIGHT`(124) 与兜底路径自绘 FAB（贴底 104）未动。文档同步 §6.14 表格与代码块。构建 `BUILD SUCCESSFUL`（26s） |
| 2026-09-12 | 追加·**同排重构**（用户要求「底栏宽度调窄，把加号挪到与底栏同一排（两个框要分离开），底栏内高度与加号按钮对齐」）：`ThreadList.ets` 底部排序栏与右下加号钮改为**同排两框**。几何定稿：`左 24 | 底栏 | 缝 12 | 加号 56 | 右 24` → 栏宽 **屏宽 − 116**（旧 屏宽 − 48）、下限 **184**（旧 240，W = 320 时旧下限会把底栏推到加号身上重叠 28vp）；栏高 **56 = 加号直径**（旧 58），`THREAD_LIST_SORT_BAR_PADDING` `6 → 5` 把栏内钮高**保住 46**（文字块几何零变化），`Radius.full` 圆角 29 → **28 = 加号圆角**；加号底距 `108 → 30`（= 底栏底距，底边一条线）、刷新钮底距 `30 + 56 + 12 = 98` **孤悬在加号正上方**（已与用户确认接受：右侧仅 56 宽放不下两钮横排，塞两个等于合框）；FAB 壳宽 `84 → 80`（右缘由 28 收到 **24**，与底栏左缘对称）、壳高 124 不变；列表底部让位 `244 → 166`（最高点由加号换成刷新钮 154 + 12 呼吸，可视区白赚 78）。**新增关键经验（已回写坑 30）**：目标元素**左右不对称**时全宽定位容器**必须 `Start` + `padding-left`**，`Center` 会把它按左右均分的 60 推进去 —— 本处栏宽左 24 / 右 92 不对称，`SortSlotShell()` 的 `justifyContent(Center)` 已改 `Start` + `padding({ left: 24 })`。新增常量 `THREAD_LIST_SORT_BAR_GAP = 12`，`sortBarWidth()` 由写死减法改为 `24 + THREAD_LIST_FAB_SHELL_WIDTH + GAP`（缝隙与壳宽联动）。兜底路径（低版本 / 无材质 / 开关关闭）**不动**：它没有底部排序栏，加号贴底本就无同排对象。文档同步：§6.14 表格新增「同排布局」「下限调整」两行并重写壳几何行、代码块（56 / Start + padding-left）、§1.1 表头 84 → 80、坑 30 补「左右不对称须 Start」与 80 的来历。构建 `BUILD SUCCESSFUL`（26s） |
| 2026-09-12 | 追加·**去阴影**（真机截图反馈「吧主页底栏有层突兀阴影」）：定位为**材质自带投影**（`ImmMaterial.floatingBar()` 的 `applyShadow: true`）—— 空壳槽位路径下这条栏由槽内 `Row` 自己挂材质、下方没有官方背板托底，投影无处可落便摊在内容与页底上成一圈暗晕（与 2026-09-10 详情页排序胶囊的「一层淡阴影」同源，即修复⑥）。`Theme.ets` 新增**无阴影档** `ImmMaterial.floatingBarFlat()`（`_matFloatingFlat` 单例 + `ensureFloatingBarFlat()`，与 `floatingBar` 仅 `applyShadow: false` 之差：THIN / `interactive: false` / `lightEffect: null` / `colorInvert: true` 逐项一致），`ThreadList.SortSegBar()` 的 `.systemMaterial(...)` 换用该档；走 `barFloatingStyle` 的官方悬浮岛（首页 / 搜索页 / 帖子详情页底栏）**不动**（那里阴影属悬浮岛观感）。新增**坑 32**（判据：材质挂在「自己就是最终形状、下方无背板」的元素上时一律优先无阴影档；同族先例 `segFlat` / FAB 的 `segFlat(false)`）。同步更新：§6.14「材质来源」行与坑 31 正文、§8 补坑 32、`immersive-material-guide.md` 材质速查表补 `floatingBarFlat()` 一行。构建 `BUILD SUCCESSFUL`（36s） |
| 2026-09-12 | 追加·**重复点击排序 = 回顶刷新**（用户要求「当前在热门，再点热门就刷新内容并回到最顶上，最新 / 精选同理」）：`ThreadList.ets` 的 `selectSort` 同值分支由 `return` 改为 `this.refreshByRetap(sort)` —— 新增 `refreshByRetap()`：① 立即 `listScroller.scrollTo({0,0})`（300ms `EaseOut`，不等网络，等待期间用户已看到顶部）；② 复用 FAB 刷新钮的 `handleRefresh()`（同一条链路：网络拉第 1 页、8s 超时兜底、「刷新成功 / 失败」toast、转圈反馈、后台昵称校准 + 缓存回写；busy 时只回顶不重复发请求，与 `handleRefresh` 的 busy 短路口径一致）。数据侧附带收益：新列表经 `threads` 的 `@Watch`（`onThreadsChanged`）自动回写 `sortSession`，切走再切回拿到的已是刷新后数据。**零新增分支成本**：槽位路径（`SortSegButton`）与兜底路径（`SortTabsBuilder`）三处 onClick 都调 `selectSort`，故两条路径自动同行为。§6.14 表格补「交互」行；`SortSegBar` / `SortTabsBuilder` / `selectSort` 注释同步。构建 `BUILD SUCCESSFUL`（26s） |
| 2026-09-12 | 追加·**移除右下角刷新钮**（用户要求「去掉吧主页右下角的刷新按钮」）：`ThreadList.ets` 两处一起删 —— ① 官方槽位路径 `FabSlotColumn` 里的刷新钮 `Stack`（`arrow_clockwise` + `refreshSpin` 自转 + `systemMaterial(segFlat(false))` + `onClick → handleRefresh`），`Column({space:12})` → `Column()`、壳高常量 `THREAD_LIST_FAB_SHELL_HEIGHT` `124 → 56`（壳内只剩加号，仍与底部排序栏同排：底距 30、高 56、占 30~86）；② 兜底路径（`ThreadListContent` 的 else 分支）同款自绘刷新钮（`segGlass` / `manualBorder` / `backgroundBlurStyle` / `segShadow`），加号保持改造前的底距 36。连带回收：转圈机制整体删除（`@State refreshSpin`、`private refreshTimer`、`startRefreshSpin()` / `stopRefreshSpin()`、`handleRefresh` 内两处调用、`aboutToDisappear` 里唯一用途的 clearInterval —— 方法随之整体移除）；列表底部让位 `contentBottomSpace()` 槽位路径 `166 → 98`（加号顶 86 + 12 呼吸）/ 兜底路径 `150 → 104`（自绘加号顶 92 + 12 呼吸）；`withRefreshTimeout` 注释改写（界面已无转圈图标，兜底改为保护 busy 门不被挂起请求长期占住）。刷新入口现在只有「重复点击当前排序」（`refreshByRetap`）。§6.14 表格「FAB 让位」行与 `FabSlotShell` / `FabSlotColumn` / `fabReveal` / 常量注释同步。构建 `BUILD SUCCESSFUL`（26s） |
| 2026-09-12 | 追加·**加号材质随背景反色**（用户反馈「底栏和底栏内文字会随背景变色、加号不会，看着有些别扭」）：`Theme.ets` 新增材质档 **`ImmMaterial.fabFlat()`**（`ensureFabFlat` + `_matFabFlat` 缓存）= THIN / `interactive: true` / `lightEffect: { color: undefined }` / `applyShadow: false` / **`colorInvert: true`** —— 与底栏 `floatingBarFlat()` 同档，仅 `interactive`（保留圆钮按压形变）之差。`ThreadList.FabSlotColumn` 加号：`.systemMaterial(ImmMaterial.segFlat(false))` → `.systemMaterial(ImmMaterial.fabFlat())`，图标色 `Theme.textPrimary(this.isDark)` → **`$r('sys.color.font_primary')`**（系统语义色，与底栏三钮文字同源）。**判据**：`colorInvert` 是「材质随背景明暗自动翻转」的开关，且只作用于材质内的**系统语义色内容** —— 自绘 hex（`Theme.textPrimary` / `iconPrimary`）一律不参与反色；无材质的兜底自绘路径（`ThreadListContent` else 分支）仍保持 `Theme.textPrimary` 不动。文档同步：`immersive-material-guide.md` §4.2 材质表新增 `fabFlat()` 行 + `createMaterial` 模板 `colorInvert` 注释、§6.13 追加「后续变更」行、`ensureFloatingBarFlat` / `SortSegBar` 注释里的旧提法。构建 `BUILD SUCCESSFUL`（34s） |
| 2026-09-12 | 追加·**排序切换转场丝滑化**（用户反馈「热门 / 最新 / 精选的左右滑动动画有些生硬，要非常丝滑」）：旧实现是**单侧滑入**（`SORT_SWITCH_SLIDE=120` / 300ms `FastOutSlowIn` / 起点 opacity 0.6，见本次删除的常量），旧内容被瞬时整块替换、只有新内容孤零零平移归位。重构为**方向感知的双拍接力**（参数以 `ThreadList.ets` 文件头 `SORT_OUT_*` / `SORT_IN_*` 常量注释为准）：① **退场** = 当前内容反向轻推 40vp + 淡到 0.25 + 微缩 0.985，130ms `Curve.EaseIn`（起步快、收得利落，点击即有反馈、不等网络）；② **入场** = 新内容自对侧 140vp、以**与退场终点同档**的透明度 / 缩放起步（衔接处不见明暗跳变），320ms `curves.springMotion(0.72, 0.86)` 阻尼吸附归位 —— 与首页 5 Tab `switchTab`、底栏选中缩放同一套弹簧参数，全站手感统一。数据替换发生在两拍之间（屏幕外偏移 + 低透明度处，替换本身不可见）。**新增转场管线**：`SortDisplay` 数据包（sort / threads / page / hasMore / state，`sort` 做连点竞态校验）+ `stageSortEnter`（退场未收口则入队 `pendingEnter`，收口后落位）/ `applySortDisplay`（起点态先渲染一帧 → 下一帧播动画，`SORT_FRAME_GAP=24` 防起点被吞）/ `playSortExit` / `finishSwitchImmediately`（快速连点立即收口并落位已到数据），取代旧的 `pendingShift` + 零散 `enterTimer` 复位；`loadThreads` 的**五处上屏点**（页内快照命中 / 缓存命中 / 未命中转 Loading / 网络返回 / catch）全部改经转场入口，`catch` 同时复位转场态（否则错误页会歪在退场偏移上）。**未命中缓存**（首次切过去且无缓存）改「退场 → 骨架屏淡入（`SORT_SKELETON_DURATION=220`）→ 网络返回入场」，旧内容停在退场终点等网络、不回弹不闪空，取代原先的硬切。另两处配套：① **换排序同步无动画回顶**（旧滚动偏移对新内容集没有意义）；② `refreshSilently` 增加「转场中只回写缓存、不上屏」守卫，消除"滑入途中列表被静默刷新整块替换"的跳变。渲染层新增 `.scale(this.contentScale)`（与 `.translate` 同挂内容层）。构建 `BUILD SUCCESSFUL`（25s） |
| 2026-09-12 | 追加·**排序切换转场二次收敛**（真机反馈「动画太过度，还会卡一下，我只想要类似首页界面切换那种效果，首页和收藏页的切换就顺滑、也不过度」）：上一版的双拍接力被判过度 —— **过度**来自位移幅度与叠在一起的三类变化（140vp 位移 + 透明度 0.25→1 + 缩放 0.985→1），**卡顿**来自两拍之间的等待（退场播完到入场播放之间内容静止约 160ms）以及入场前强制停一帧（24ms）才能摆起点。现**收敛为 `Index.switchTab` 完全同款的一段式**：`SORT_SLIDE=100`（同首页 `inOffset`/`outOffset`）/ `SORT_DURATION=320` / `curves.springMotion(0.72, 0.86)`，渲染层只挂 `.translate`（删 `.scale`，透明度不再参与动画）。写法同样取首页口径：`applySortDisplay` 在**同一调用栈**内先无动画摆起点（`contentShift = dir * 100`）再 `animateTo` 归位 —— 渲染出的首帧即"新内容位于对侧"，不闪叠、无等待帧（首页生产代码已验证「同帧赋值 + animateTo」起点生效）。删除整套过渡态机制：常量 `SORT_OUT_*` / `SORT_IN_*` / `SORT_FRAME_GAP` / `SORT_SKELETON_DURATION`，方法 `playSortExit` / `stageSortEnter` / `finishSwitchImmediately`，字段 `contentScale` / `sortExitBusy` / `sortExitTimer` / `pendingEnter` / `enterTimer`（**排序切换路径已无任何定时器**；快速连点由新的 `animateTo` 自然接管，Spring 从当前值续播，不再需要"收口"逻辑）。未命中缓存仍走「骨架屏轻淡入（`SORT_SKELETON_FADE=150`）→ 网络返回滑入」；`refreshSilently` 的转场窗口守卫改用时间戳 `sortAnimUntil`（= 起滑时刻 + 320ms）。构建 `BUILD SUCCESSFUL`（26s） |
| 2026-09-12 | 追加·**排序切换转场三次定稿 = 复刻首页「两页连着」**（真机反馈「现在变回之前那种生硬感，我希望左右滑动切换动画，有种两个界面仿佛连着的感觉，那种顺滑感」）：第 ③ 版"只有新页滑入"被判生硬，根因是**旧页不在场**（被瞬间替换）—— 屏幕上只是"一块内容换成另一块"，没有两页相接的连续移动。回读首页生产代码 `Index.switchTab`（348-379 行）确认其本质：`prevTab` 让旧页继续留在树上渲染，**同一个 `animateTo` 里新页 `inOffset` +100%→0、旧页 `outOffset` 0→-100%**，两页对向平移整屏、320ms `springMotion(0.72,0.86)`，420ms 定时器收口卸载旧页（`tabOffset()` 按 `selectedTab` 取 in/out，`tabLayer()` 令进场页盖在退场页之上）。本页只有一个列表、数据在切换时被整体替换，旧内容无处可寻，故新增「旧页快照」机制：常量 `SORT_ANIM_DURATION=320` / `SORT_ANIM_SETTLE=420` / `THREAD_SCROLL_SNAPSHOT_ID`；字段 `@State inOffset` / `@State outOffset` / `@State exitSnapshot: image.PixelMap \| null` / `sortSettleTimer`；方法 `captureExitSnapshot()`（`componentSnapshot.getSync` **同步**截图 —— 异步版赶不上"页内快照同步命中"的同一帧，旧页中途冒出比不做更糟；失败 catch 降级 null = 只有新页滑入）/ `clearSortSettle()` / `scheduleSortSettle()`。`selectSort` 顺序：收口上一次 → **同步截图**（必须在数据替换前）→ 记方向 → 加载；`applySortDisplay` 起点态 `inOffset = dir*100 / outOffset = 0` 后同帧 `animateTo`（`inOffset = 0 / outOffset = -dir*100`）。渲染层：`.id()` + `.translate({x: inOffset%})` 挂到 **Scroll**（新页整层），其前插一层 `Image(exitSnapshot).translate({x: outOffset%})`（旧页，`hitTestBehavior(None)`）；顶栏 / 底栏槽位不参与位移（同首页）。未命中缓存时收口 + 骨架屏淡入，网络返回再对向平移。构建 `BUILD SUCCESSFUL`（26s） |
| 2026-09-12 | 追加·**过场作用域收窄到列表区 —— 吧头 / 顶栏 / 底栏静止**（用户反馈「吧主页切换动画顶部吧信息能否不跟着切换」，确认按方案 A 实施）：位移原挂在 `Scroll` 上，而吧头（吧名 / 头像 / 关注签到）是 `Scroll` 内容里的普通子项 → 吧头被一起带着滑；首页切 Tab 时标题栏与底栏静止，两者观感不一致。改动五处：① 新页 `.translate` 从 `Scroll` 下移到 `Scroll` 内的**列表区**那一层（内容 / 骨架屏 / 空态 / 错误那个 `Stack`），吧头与兜底路径 `SortTabsBuilder` 不参与位移（槽位路径底部排序栏本就在 `Scroll` 之外）；② 旧页快照改用 `SnapshotOptions.region`（**单位 px**，API 15+，本机 SDK `componentSnapshot.d.ts` 已确认 `SnapshotRegion{left,right,top,bottom}` 均为 px）裁掉吧头，边界 y = `THREAD_LIST_HEADER_TOP_SPACE(90) + headerBlockH − listScroller.currentOffset().yOffset`（即吧头块底边在 `Scroll` 视口里的位置），存入新 `@State exitClipTop`，旧页 `Image` 再 `.translate({ y: exitClipTop })` 下移 + `.height(Math.max(0, viewportH − exitClipTop))` 收窄，与只含列表区的新页严格对齐；③ 新增测量：吧头块 `Column`（吧头 + 兜底排序栏）挂 `onAreaChange` 回填 `headerBlockH`（普通字段，避免测量触发重建）、`onViewportAreaChange` 增记 `viewportW`（region 需要）；④ 顶栏占位 `Column().height(90)` 改用新常量 `THREAD_LIST_HEADER_TOP_SPACE = 90`，与裁剪公式同源；⑤ `clearSortSettle` / `scheduleSortSettle` 收口时一并复位 `exitClipTop = 0`。**两档降级**：吧头已滚出屏幕上方（`clipTop ≤ 0`）或吧头高 / 视口宽高未测到 → 不裁，整屏即列表内容，行为与调整前一致。只做水平位移、垂直位置不动，故列表区不会与静止的吧头几何重叠。构建 `BUILD SUCCESSFUL`（25s，release 签名版）；真机观感待复核 |
| 2026-09-12 | 第十九处迁移·**帖子详细页「跳转官方贴吧」确认浮层 → 系统 `CustomDialog`**（用户要求「帖子详细页的跳转官方帖子改沉浸光感」）：`ThreadDetail.ets` 原 `@Builder JumpConfirmDialog()` 是页面 body 顶层自绘浮层、卡上挂着 `.systemMaterial(ImmMaterial.control())` —— 按 §1.2 该位置材质**必然 out of scope**，实际只有自绘 `backgroundEffect` 真模糊生效，属"能编译不生效"残留。照 §4 模板三步改：① 顶层新增 `@CustomDialog struct JumpTiebaDialogCard`（标题 / 说明 / 链接预览 / 确定 + 取消竖排全宽钮，卡内文案与几何逐项照搬；删掉卡上 `backgroundColor` / `backgroundEffect` / `border` / `shadow`×2 / `systemMaterial` 五项，改由材质接管）；② 宿主新增 `jumpDialogController`（`width: this.dialogCardWidth()` = 屏宽 − 48、`cornerRadius: 32`、`maskColor: '#06000000'`、`alignment: DialogAlignment.Center`、开合动画 220/200ms、`systemMaterial: ImmMaterial.dialog()`、`onWillDismiss → closeJumpDialog()` 一并覆盖点遮罩 / 返回键 / 侧滑、`customStyle: false`），`showJumpDialog` 改 `@State @Watch('onShowJumpChanged')` 桥接（既有 `this.showJumpDialog = x` 调用点零改动）；③ `openJumpDialog()` 打开前写 `jumpUrlPreview` 链接快照（`threadWebUrl()` 是宿主方法，不能进弹窗），删掉 `DetailRoot` 里的浮层挂载与旧 builder（−86 行）。按钮按 §6.2 挂材质：主钮 `ImmMaterial.accent()` + `#CC3173FF` + 同色浮起阴影，次钮 `ImmMaterial.cardAction()` + 半透明底 + 中性轻投影（底色必须带透明度，坑 11）。本页此前无任何系统弹窗，故一并补 `import { display }`（`@kit.ArkUI`）与 `dialogCardWidth()`（与 `ThreadList` / `Favorite` 同源实现）。文档同步：新增 §6.15、§9.1 清单加第 15 行、§9.2 补 `ThreadDetail` 排查结论（同页 `LinkConfirmDialog` 同款待办）。构建 `BUILD SUCCESSFUL`（24s） |
| 2026-09-12 | 落点二次 + 三次调整·**帖子详细页「跳转官方贴吧」弹窗位置**：初版按"改造前就是屏幕居中卡片"取 `alignment: DialogAlignment.Center`；用户要求「位置与首页置顶弹窗一致」→ 改为工程同款确认卡片统一口径 **`DialogAlignment.Bottom` + `offset.dy = -110`**（与 `Favorite.pinConfirmController` 置顶确认 §6.4 / `deleteConfirmController` 批量删除 §6.5、`ForumsTab` 一键签到 §6.1 / 关注吧长按菜单 §6.3 同一落点）；用户随后反馈 **-110 时弹窗与「正序」胶囊贴在一起** → 先抬到安全值 `-170`（钮体上方 28vp），**用户复看后指定收到 `offset: { dx: 0, dy: -140 }`（最终值，钮体上方 2vp，紧贴不压字）**（本页底部两层：评论悬浮岛距底 30~96、排序胶囊行距底 96~142、钮体本体 104~138）。**该页从此不再与收藏 / 进吧页同落点**，其余参数（`width: dialogCardWidth()` / 圆角 32 / 遮罩 #06000000 / 220、200ms 开合动画 / `systemMaterial: ImmMaterial.dialog()`）不变。结论已回写 §4.3 落点口径：**同款卡片的 `dy` 不是全局常量，须按宿主底部实际占位（悬浮栏 / 排序行 / 输入条）逐页推算**。构建 `BUILD SUCCESSFUL`（24s） |


