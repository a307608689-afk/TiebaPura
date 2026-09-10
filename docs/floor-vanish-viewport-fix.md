# 楼层整层消失（List 虚拟滚动视口剔除）排查与修复 — 维护文档

> **适用工程**：TiebaPura（HarmonyOS，ArkTS / ArkUI 原生，兼容 SDK 5.0.0 / API 12）
> **方案版本**：v1.0（落地日期：2026-09-03）
>
> **用途**：记录"沉浸页面 + 虚拟滚动列表 + 悬浮底栏"场景下，列表项滚到屏幕中部某条横线后**整层消失、滚不回来**类问题的定位思路与已验证结论，供后续出现类似现象时直接套用排查。**结论基于实证，未包含对系统内部机制的臆测。**

---

## 1. 现象特征（如何识别同类问题）

复现场景为「帖子详情页」：楼层用 `List` 平铺在页面内，页面底部还有**悬浮回复栏**（覆盖在列表之上，列表需沉浸到屏幕底）。

典型症状：

- 楼层内容向下滚动时，滚过屏幕中部"正序栏 / 回复栏顶部"那条横线后**整层不渲染**（屏幕上是背景，不是空白卡片占位）；
- 内容其实还在 UI 树里（滚动位置正确、高度占位正常），只是不画出来；
- 上滑回滚、再次下滑，**反复消失**，没有稳定恢复规律；
- 楼层消失与"数据是否加载成功"无关（数据在，渲染不出来）。

**识别关键词**：`List` + `clip(false)` + `expandSafeArea`（底部沉浸）+ 页面底部另有悬浮控件压在列表上方 → 疑似同源问题。

## 2. 涉及文件与改动点

| 文件 | 位置 | 说明 |
|---|---|---|
| `entry/src/main/ets/pages/ThreadDetail.ets` | `build()` 楼层容器（约 589–659 行） | `List` 改 `Scroll` + `Column` + 全量 `ForEach` |
| `entry/src/main/ets/pages/ThreadDetail.ets` | `loadMoreFloors()`、哨兵 UI | 加载下一页触发改为 `Scroll.onReachEnd` |

## 3. 排查过程（排除法，结论可复用）

> 每条改动都必须**保留沉浸外观**（底栏在、`clip(false)`+`expandSafeArea` 在），否则页面"退出沉浸"后现象失去复现价值（会得到"不消失但也不沉浸"的假阴性）。

| # | 假设 | 做法 | 结果 |
|---|---|---|---|
| 1 | 悬浮底栏遮挡 / 把楼层顶出可视区 | 移除底部悬浮回复栏 Column | **仍消失** → 排除遮挡 |
| 2 | `LazyForEach` 可视区回收判定有误 | 楼层循环 `LazyForEach` → `ForEach`（全量构建，无懒回收） | **仍消失** → 关键结论：**剔除与懒加载无关**。`ForEach` 在 `List` 容器内时，`List` 仍会按自身视口把窗口外的项剔除，`ForEach` 只是"把节点造出来"，不代表"会画出来" |
| 3 | `List` 高度计算有歧义（父级是 `Stack`，`layoutWeight` 在 Stack 布局中不可靠） | `.layoutWeight(1)` → `.height('100%')` | **仍消失** → 显式高度不能修复，问题不在高度设置方式 |
| 4 | **`List` 容器的视口（cull）本身出错** | 整个滚动容器换成 `Scroll` + `Column`，楼层 100% 全量真实布局，**没有任何视口剔除机制存在** | **不再消失** → 根因收敛到 `List` 虚拟滚动容器的视口剔除 |

### 核心教训

1. **`ForEach` 只解决"构建"，不解决"绘制"**。只要还在 `List` 里，列表项可视与否由 `List` 自身的视口窗口决定。
2. 触发条件高度疑似与"**沉浸绘制扩展与滚动视口错位**"有关（`clip(false)` + `expandSafeArea(SYSTEM, TOP/BOTTOM)` 让列表画到安全区外，而 `List` 内部判"是否在视口内"仍基于某个未同步扩展的窗口；底部再叠一层悬浮控件时，错位线正好落在悬浮栏上方）。
3. 未深挖系统内部实现（无系统源码），上述"错位"是**与全部实证一致的推断**；真正可操作的事实是：**换 `Scroll` 全量渲染必然绕过该问题**。

## 4. 修复方案（当前落地代码）

楼层列表区域核心结构（`ThreadDetail.ets`）：

```
Scroll() {
  Column({ space: Spacing.md }) {
    Column().width('100%').height(98)        // 顶栏占位
    this.PostHeader()
    this.ReplySectionHeader()
    ForEach(this.floors, (floor) => {        // 全量渲染，不做任何可视区回收
      this.FloorCard(floor)
    }, (floor) => `${floor.floorId}_${floor.floor}`)
    // 触底哨兵：仅展示状态/手动重试，自动加载由 onReachEnd 驱动
    if (this.hasMoreFloors) { /* loading spinner / 手动按钮 */ }
    else { Text('— 已经到底啦 —') }
  }
  .width('100%')
}
.width('100%')
.height('100%')
.scrollBar(BarState.Off)
.padding({ left: Spacing.lg, right: Spacing.lg, top: 0, bottom: 160 })  // 为悬浮栏留滚动空间
.align(Alignment.TopStart)
.edgeEffect(EdgeEffect.Spring)
.onReachEnd(() => {                        // ★ 触底自动加载下一页
  if (!this.loadingMore && this.hasMoreFloors) {
    this.loadMoreFloors();
  }
})
.clip(false)
.expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])  // 保持沉浸
.backgroundColor(Theme.bg(this.isDark))
.opacity(this.contentOpacity)
```

数据与刷新：楼层数据在 `@State floors` 中，`loadMoreFloors` / 点赞乐观更新 / 回滚均通过整体赋值 `this.floors = nextFloors` 驱动 `ForEach` 重渲染。原 `FloorDataSource`（LazyForEach 数据提供器）保留但已无 UI 监听，仅随 `floors` 冗余同步，避免大范围删改。

## 5. 修复后必须注意的连带变化

1. **哨兵 `onAppear` 自动加载失效**：原实现里"滚到底自动加载下一页"依赖 `List` 懒回收——哨兵滚出视口被销毁、再滚回重新 `onAppear`。`Scroll` + `Column` 全量渲染下哨兵常驻，`onAppear` 只触发一次，**多页数据会卡住不加载**。必须改用 `Scroll.onReachEnd` 触发（`loadingMore`/`hasMoreFloors` 双防重），保留手动按钮兜底。
2. **点赞等局部刷新成本上升**：`this.floors` 整体赋值会让 `ForEach` 对全部楼层做 diff。楼层为高频小对象时可按 key 复用，但 itemBuilder 仍会整体重执行。点赞属于低频操作，可接受。
3. **失去懒加载性能**：详见 §6。

## 6. 取舍与后续优化方向

| 维度 | 原 `List` 方案 | 现 `Scroll` + `Column` 方案 |
|---|---|---|
| 楼层消失 bug | 触发 | 不存在（无视口剔除） |
| 长帖（数百楼以上）首帧构建 | 快（只建可视项） | 慢（全量构建已加载楼层） |
| 滚动内存 | 低 | 高 |
| 自动加载下一页 | 哨兵 + 懒回收联动 | `onReachEnd` |

后续若长帖卡顿，可按需优化（均保留 Scroll 结构）：

- **分段渲染窗口**：只渲染 `[start, start + window)` 区间楼层，滚动到窗口边界平移窗口；
- 楼层卡片 `@Builder` 拆独立 `@Component` + `@Prop`/`@ObjectLink`，把 itemBuilder 重建范围缩小到单楼；
- 图片九宫格维持现有懒加载，避免离屏图片全量下载。

## 7. 类似问题的快速排查清单（下次直接用）

若再次出现"内容滚到某条线后整层消失 / 不绘制"：

1. **先确认是否在 `List`（或其它虚拟滚动容器）内**；若是，直接把该区域改用 `Scroll` + `Column` 全量渲染做 A/B——消失即消失，不消失即实锤容器视口问题（可在 5 分钟内完成验证，别先猜其它原因）。
2. 若必须保留 `List` 懒加载，**先试移除容器上的 `clip(false)` + `expandSafeArea`**（代价是失去沉浸，需用外层容器承担背景），观察是否规避。
3. 若移除后仍消失，再排查遮挡层（悬浮控件 `zIndex`/布局是否压在列表视口上）。
4. 修复容器类型后，**检查原依赖懒回收的隐式机制是否失效**（哨兵 `onAppear` 触发、`onVisibleAreaChange` 可见性回调等），改用滚动容器自身的触底回调（`onReachEnd`）或显式坐标判断。

## 8. 版本记录

| 版本 | 变更 |
|---|---|
| v1.0 | 首次落地：`ThreadDetail` 楼层容器 `List` → `Scroll`+`Column` 全量渲染；加载下一页改 `onReachEnd` 驱动；实测楼层不再消失、多页可连续加载。副作用：长帖失去懒加载性能，待 §6 优化 |
