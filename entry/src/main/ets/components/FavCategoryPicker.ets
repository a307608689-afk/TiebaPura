/*
 * TiebaPura - HarmonyOS 原生 ArkTS 实现的第三方百度贴吧客户端
 * Copyright (C) 2026 a307608689-afk
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import { CategoryMapping, FavCategory } from '../model/DataModel';
import { FavoriteStore, CATEGORY_DEFAULT_ID } from '../service/FavoriteStore';
import { Theme, Spacing, Radius, ImmBlur, ImmMaterial, fs } from '../common/Theme';
import { ToastUtil, ToastType } from '../common/ToastUtil';
import { Haptic } from '../common/Haptic';

/** 移入面板目标分类条目（未分类恒在首位 + 各自定义分类） */
interface PickerRow {
  id: string;
  icon: string;
  name: string;
  /** 参与操作的帖子中已属于该分类的条数（用于「已含 N/M」） */
  included: number;
}

/**
 * 移入分类选择面板（系统半模态 bindSheet 承载，属官方沉浸光感 A 档槽位）。
 *
 * 单一来源：收藏页编辑态「移入」与帖子详情页「长按收藏钮」共用同一套面板 UI 与勾选逻辑。
 * 职责边界 —— 组件只负责「选分类 + 新建分类」，**不碰持久化**，落库交宿主的 onDone：
 *  · 收藏页：多选帖批量替换式写入（Favorite.applyMove）
 *  · 详情页：未收藏则「收藏 + 归类」一并执行（ThreadDetail.applyPickCategory）
 * 写库全在 onDone 里，故下滑 / 点遮罩关闭面板天然零副作用（误触无痕）。
 */
@Component
export struct FavCategoryPicker {
  /** 面板开合：宿主置 true 打开；下滑 / 点遮罩关闭时系统经 $$ 回写 false */
  @Link show: boolean;
  /** 分类列表（新建分类会整体回写，宿主列表随之刷新） */
  @Link categories: FavCategory[];
  /** 帖↔分类映射（只读，用于算「已含 N/M」） */
  @Link mappings: CategoryMapping[];
  /** 勾选集合（分类 id；CATEGORY_DEFAULT_ID = 未分类，与具体分类互斥） */
  @Link checked: string[];
  /** 面板内新建分类的输入态（宿主据此让返回键先退输入行、不关面板） */
  @Link creating: boolean;
  /** 参与操作的帖子 tid 快照（只读，用于计数与「已含 N/M」） */
  @Prop targets: string[] = [];
  @Prop accountId: string = '';
  @Prop isDark: boolean = false;
  @Prop fontScale: number = 1.0;
  /** 点「完成」：把最终勾选交给宿主落库 */
  onDone: (checked: string[]) => void = () => { };

  /** 面板内新建分类的输入值 */
  @State newName: string = '';

  /** 面板条目：未分类恒在首位，其余按分类列表顺序 */
  private rows(): PickerRow[] {
    const list: PickerRow[] = [];
    const tids: string[] = this.targets;
    const includedOf = (categoryId: string): number => {
      let n: number = 0;
      for (const tid of tids) {
        if (this.mappings.some((m: CategoryMapping): boolean => m.tid === tid && m.categoryId === categoryId)) {
          n++;
        }
      }
      return n;
    };
    list.push({ id: CATEGORY_DEFAULT_ID, icon: '📂', name: '未分类', included: includedOf(CATEGORY_DEFAULT_ID) });
    for (const c of this.categories) {
      list.push({ id: c.id, icon: c.icon, name: c.name, included: includedOf(c.id) });
    }
    return list;
  }

  private isChecked(id: string): boolean {
    return this.checked.indexOf(id) >= 0;
  }

  /** 切换勾选：未分类与具体分类互斥（勾选未分类 = 移出全部自定义分类） */
  private toggleTarget(id: string): void {
    if (id === CATEGORY_DEFAULT_ID) {
      this.checked = this.isChecked(CATEGORY_DEFAULT_ID) ? [] : [CATEGORY_DEFAULT_ID];
      return;
    }
    let next: string[] = this.checked.filter((x: string): boolean => x !== CATEGORY_DEFAULT_ID);
    if (next.indexOf(id) >= 0) {
      next = next.filter((x: string): boolean => x !== id);
    } else {
      next = [...next, id];
    }
    this.checked = next;
    Haptic.light();
  }

  /** 展开输入行：入口行本身在可视区内，展开为就地替换，无需滚动 */
  private beginCreate(): void {
    if (this.creating) {
      return;
    }
    this.newName = '';
    this.creating = true;
  }

  /** 收起输入行（取消）：不改变已勾选集合 */
  private cancelCreate(): void {
    this.creating = false;
    this.newName = '';
  }

  /** 关闭面板时回收输入态（下滑 / 点遮罩 / 宿主返回键共用同一收尾） */
  private resetCreateState(): void {
    this.creating = false;
    this.newName = '';
  }

  /**
   * 提交面板内新建：校验口径与收藏页分类管理逐项一致（trim 空 / 最多 12 字 / 同名拦截）；
   * 新建后自动勾选新分类并留在面板 —— 用户新建意图即「归类到它」，免得新建完还要再找一次。
   */
  private async commitCreate(): Promise<void> {
    const name: string = this.newName.trim();
    if (name.length === 0) {
      this.toast('请输入分类名称');
      return;
    }
    if (name.length > 12) {
      this.toast('分类名称最多 12 个字');
      return;
    }
    if (this.categories.some((c: FavCategory): boolean => c.name === name)) {
      this.toast('该分类已存在');
      return;
    }
    const created: FavCategory[] = await FavoriteStore.getInstance().addCategory(this.accountId, name, '📁');
    this.categories = created;
    // 广播分类集合变更：宿主是收藏页时 @Link 已同步（重读一次幂等），宿主是详情页时靠这条让常驻收藏页重读
    AppStorage.setOrCreate<number>('favCatChanged', (AppStorage.get<number>('favCatChanged') ?? 0) + 1);
    const newCat: FavCategory = created[created.length - 1];
    // 新建即勾选：并入已勾选集合时按 toggleTarget 的互斥口径剔除「未分类」
    const next: string[] = this.checked.filter((x: string): boolean => x !== CATEGORY_DEFAULT_ID);
    if (newCat && next.indexOf(newCat.id) < 0) {
      next.push(newCat.id);
    }
    this.checked = next;
    this.creating = false;
    this.newName = '';
    Haptic.light();
    this.toast('已新建并选中', ToastType.Success);
  }

  /** 统一 Toast（与收藏页同款，省略 context 与类型默认 Info） */
  private toast(message: string, type: ToastType = ToastType.Info): void {
    ToastUtil.show(this.getUIContext(), message, type);
  }

  build() {
    // 本组件不渲染可见内容：面板由自身根节点的 .bindSheet 挂载（0×0，不参与宿主布局）
    Column() {
    }
    .width(0)
    .height(0)
    /**
     * 材质走 options.systemMaterial（页面 body 内的自绘浮层拿不到官方材质）。
     * 几何逐项对齐收藏页改造前：高度 62% / 遮罩 #66000000 / 顶部圆角 24 / 无拖拽条 / 无系统关闭按钮。
     * `$$` 双向绑定：用户下滑手势关闭时系统会回写 show = false。
     */
    .bindSheet($$this.show, this.PickerContent(), {
      height: '62%',
      preferType: SheetType.BOTTOM,
      showClose: false,
      dragBar: false,
      maskColor: '#66000000',
      radius: { topLeft: 24, topRight: 24 },
      systemMaterial: ImmMaterial.sheet(),
      onDisappear: () => {
        this.show = false;
        // 下滑 / 点遮罩关闭：一并回收输入态，避免下次打开残留输入行（宿主返回键走同一收尾）
        this.resetCreateState();
      }
    })
  }

  /**
   * 面板内容（系统半模态 `bindSheet` 的内容 builder）。
   * 遮罩 / 玻璃 / 高度 / 圆角 / 拖拽条全在 options 里，此处只保留内容本体：
   * 标题行 + 分类列表（含新建分类入口）+ 完成按钮 —— 尺寸、间距、文案与收藏页原实现零改动
   * （多帖场景逐字不变；单帖场景把「N 条已选」改述为「当前帖子」，语义更自然）。
   */
  @Builder
  PickerContent() {
    Column() {
      Row() {
        Text('移入分类')
          .fontSize(fs(16, this.fontScale))
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.textPrimary(this.isDark))
        Blank()
        Text(this.targets.length === 1 ? '当前帖子' : `${this.targets.length} 条已选`)
          .fontSize(fs(12, this.fontScale))
          .fontColor(Theme.textTertiary(this.isDark))
      }
      .width('100%')
      .padding({ left: Spacing.lg, right: Spacing.lg, top: Spacing.md, bottom: Spacing.sm })

      List({ space: Spacing.md }) {
        ForEach(this.rows(), (t: PickerRow) => {
          ListItem() {
            Row({ space: Spacing.md }) {
              Stack() {
                if (this.isChecked(t.id)) {
                  // 自绘对勾（与编辑态勾选圆同源），20 圆内按比例缩收
                  Path()
                    // 同上：commands 单位为 px，vp2px 换算（20 圆内等比缩收坐标）
                    .commands(`M${vp2px(5.4)} ${vp2px(10.4)} L${vp2px(8.9)} ${vp2px(13.9)} L${vp2px(14.8)} ${vp2px(6.6)}`)
                    .width(20)
                    .height(20)
                    .stroke(Color.White)
                    .strokeWidth(2.2)
                    .fillOpacity(0)
                    .strokeLineCap(LineCapStyle.Round)
                    .strokeLineJoin(LineJoinStyle.Round)
                    .transition(
                      TransitionEffect.OPACITY
                        .combine(TransitionEffect.scale({ x: 0.6, y: 0.6 }))
                        .animation({ duration: 220, curve: Curve.Friction })
                    )
                }
              }
              .width(20)
              .height(20)
              .borderRadius(10)
              .backgroundColor(this.isChecked(t.id) ? Theme.brand() : Color.Transparent)
              .border({ width: 2, color: this.isChecked(t.id) ? Color.Transparent : Theme.textTertiary(this.isDark) })

              Stack({ alignContent: Alignment.Center }) {
                SymbolGlyph($r(t.id === CATEGORY_DEFAULT_ID ? 'sys.symbol.folder' : 'sys.symbol.folder_fill'))
                  .fontSize(fs(22, this.fontScale))
                  .fontColor([Theme.brand()])
              }
              .width(44)
              .height(44)
              .backgroundColor(Theme.bgCard(this.isDark))
              .borderRadius(22)

              Text(t.name)
                .fontSize(fs(15, this.fontScale))
                .fontWeight(FontWeight.Medium)
                .fontColor(Theme.textPrimary(this.isDark))
                .layoutWeight(1)
              if (t.included > 0) {
                Text(`已含 ${t.included}/${this.targets.length}`)
                  .fontSize(fs(11, this.fontScale))
                  .fontColor(Theme.textTertiary(this.isDark))
              }
            }
            .width('100%')
            .padding(Spacing.lg)
            // §9 注：卡内条目也吃官方材质 + 半透明底（原来的不透明卡片会在玻璃面板上叠出白块，§8 坑 6）
            .systemMaterial(ImmMaterial.cardAction())
            .backgroundColor(this.isDark ? '#B31B1E24' : '#B3FFFFFF')
            .borderRadius(Radius.lg)
            .accessibilityText(`${t.name}${t.included > 0 ? `，已含 ${t.included} 条` : ''}`)
            .onClick(() => { this.toggleTarget(t.id); })
          }
        }, (t: PickerRow) => `mv_${t.id}`)

        /**
         * 新建分类入口（常驻面板列表末项）：
         * 收起态 = 「＋ 新建分类」行：加号落在第一列、与上方勾选圆同列对齐（文字随之左移一列），材质与上方条目同源；
         * 展开态 = 输入行 + 取消 / 保存，按钮样式与收藏页 NewCategoryCard 同款。
         * 全在面板内完成，故「新建 + 完成」是一条流，中途无需退出面板。
         */
        ListItem() {
          if (this.creating) {
            Row({ space: 8 }) {
              TextInput({ placeholder: '分类名称', text: this.newName })
                .layoutWeight(1)
                .fontSize(fs(14, this.fontScale))
                .fontColor(Theme.textPrimary(this.isDark))
                .backgroundColor(Theme.bgElevated(this.isDark))
                .borderRadius(Radius.full)
                .height(40)
                .defaultFocus(true)
                .onChange((v: string) => { this.newName = v; })
                .onSubmit(() => { this.commitCreate(); })

              Button() {
                Text('取消')
                  .fontSize(fs(13, this.fontScale))
                  .fontColor(Theme.textSecondary(this.isDark))
              }
              .height(40)
              .padding({ left: 12, right: 12 })
              .backgroundColor(Theme.manualGlass(this.isDark))
              .border({ width: 0.5, color: Theme.manualGlassBorder() })
              .shadow(Theme.glassShadowStyle()).backgroundEffect(ImmBlur.control())
              .systemMaterial(ImmMaterial.control())
              .borderRadius(Radius.full)
              .onClick(() => { this.cancelCreate(); })

              Button() {
                Text('保存')
                  .fontSize(fs(13, this.fontScale))
                  .fontColor(Color.White)
              }
              .height(40)
              .padding({ left: 14, right: 14 })
              .backgroundColor(Theme.brand())
              .borderRadius(Radius.full)
              .onClick(() => { this.commitCreate(); })
            }
            .width('100%')
            .padding(Spacing.lg)
            // 与上方分类条目同款玻璃底（不透明底会在面板玻璃上叠出白块，§8 坑 6）
            .systemMaterial(ImmMaterial.cardAction())
            .backgroundColor(this.isDark ? '#B31B1E24' : '#B3FFFFFF')
            .borderRadius(Radius.lg)
          } else {
            Row({ space: Spacing.md }) {
              /**
               * 加号与上方分类条目的 20 勾选圆**同列**（第一列，20 宽内居中 → 视觉中心对齐），
               * 不再占用第二列的 44 图标圆位；「新建分类」文字随之左移一列。
               * 高度取 44 与分类行的图标圆等高 → 行高（padding 16×2 + 44）不变，不会比上方条目矮一截。
               * 不设品牌色底圆：与「已勾选」的实心勾选圆区分，避免被误读成已选中。
               */
              Stack({ alignContent: Alignment.Center }) {
                SymbolGlyph($r('sys.symbol.plus'))
                  .fontSize(fs(18, this.fontScale))
                  .fontColor([Theme.brand()])
              }
              .width(20)
              .height(44)

              Text('新建分类')
                .fontSize(fs(15, this.fontScale))
                .fontWeight(FontWeight.Medium)
                .fontColor(Theme.textPrimary(this.isDark))
                .layoutWeight(1)
            }
            .width('100%')
            .padding(Spacing.lg)
            .systemMaterial(ImmMaterial.cardAction())
            .backgroundColor(this.isDark ? '#B31B1E24' : '#B3FFFFFF')
            .borderRadius(Radius.lg)
            .accessibilityText('新建分类')
            .onClick(() => { this.beginCreate(); })
          }
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: Spacing.lg, right: Spacing.lg, top: 8 })
      .scrollBar(BarState.Off)

      Button() {
        Text('完成')
          .fontSize(fs(15, this.fontScale))
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
      }
      .width('calc(100% - 32vp)')
      .height(44)
      // §9 注：卡内主按钮挂品牌色材质 + 半透明底 + 同色浮起阴影（不透明底会盖掉材质）
      .systemMaterial(ImmMaterial.accent(this.isDark))
      .backgroundColor('#CC3173FF')
      .borderRadius(Radius.full)
      .shadow({ radius: 14, color: this.isDark ? '#663173FF' : '#4D3173FF', offsetY: 4 })
      .margin({ left: Spacing.lg, right: Spacing.lg, top: Spacing.md, bottom: 24 })
      .accessibilityText('完成移入')
      // 落库交给宿主：收藏页批量写入、详情页「收藏 + 归类」，组件自身不碰持久化
      .onClick(() => { this.onDone(this.checked); })
    }
    .width('100%')
    .height('100%')
    .padding({ top: 8 })
    // 容器节点不设 backgroundColor / border / shadow / backgroundBlurStyle：四项由 options.systemMaterial 接管（§4.4）
  }
}
