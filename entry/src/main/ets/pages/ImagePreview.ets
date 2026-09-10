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

import { common, abilityAccessCtrl } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { HttpClient } from '../network/HttpClient';
import { Theme, Spacing, Radius, isDarkMode, MaterialManager, fs } from '../common/Theme';

@Entry
@Component
struct ImagePreview {
  @State urls: string[] = [];
  @State currentIndex: number = 0;
  @State isDark: boolean = isDarkMode();
  @StorageLink('fontScale') fontScale: number = 1.0;
  /** 页面可见时自增，强制组件重建使字号实时生效 */
  @State fontSizeTick: number = 0;

  onPageShow(): void {
    this.fontSizeTick++;
  }
  @State saving: boolean = false;
  @State showControls: boolean = true;
  @State viewportWidth: number = 360;
  @State viewportHeight: number = 800;
  @State zoomScale: number = 1;
  @State panX: number = 0;
  @State panY: number = 0;

  private pinchBaseScale: number = 1;
  private pinchBasePanX: number = 0;
  private pinchBasePanY: number = 0;
  private pinchCenterX: number = 180;
  private pinchCenterY: number = 400;
  private panStartX: number = 0;
  private panStartY: number = 0;
  private panBaseX: number = 0;
  private panBaseY: number = 0;
  private dragReady: boolean = false;
  private context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;

  aboutToAppear(): void {
    MaterialManager.init();
    this.hideStatusBar();
    const params = this.getUIContext().getRouter().getParams() as Record<string, Object>;
    const routeUrls: Object | undefined = params ? params.urls : undefined;
    if (Array.isArray(routeUrls)) {
      this.urls = (routeUrls as Object[])
        .map((item: Object) => `${item}`)
        .filter((item: string) => item.length > 0);
    } else if (typeof routeUrls === 'string') {
      this.urls = routeUrls.split(',')
        .filter((item: string) => item.length > 0)
        .map((item: string) => decodeURIComponent(item));
    } else if (params && typeof params.url === 'string') {
      this.urls = [decodeURIComponent(`${params.url}`)];
    }
    if (params && params.index !== undefined) {
      this.currentIndex = Number(params.index) || 0;
    }
    this.isDark = isDarkMode();
  }

  aboutToDisappear(): void {
    this.restoreStatusBar();
  }

  private async hideStatusBar(): Promise<void> {
    try {
      const win = await window.getLastWindow(this.context);
      await win.setWindowSystemBarEnable(['navigation']);
    } catch (e) {
    }
  }

  private async restoreStatusBar(): Promise<void> {
    try {
      const win = await window.getLastWindow(this.context);
      await win.setWindowSystemBarEnable(['status', 'navigation']);
    } catch (e) {
    }
  }

  build() {
    Stack() {
      if (this.urls.length > 0) {
        Swiper() {
          ForEach(this.urls, (url: string, idx: number) => {
            Stack() {
              // 图片节点常驻：缩放/平移只改属性，节点永不销毁重建，
              // 双击放大/缩回瞬间不再重新解码位图，消除"闪一下"
              Image(url)
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Contain)
                .scale({ x: this.getScale(idx), y: this.getScale(idx) })
                .translate({ x: this.getPanX(idx), y: this.getPanY(idx) })

              // 透明手势层：只切换手势集合，不触碰图片节点生命周期
              if (idx === this.currentIndex && this.getScale(idx) > 1.05) {
                // 放大态：双击缩小 + 捏合缩放 + 拖动平移 + 单击控制条
                Stack()
                  .width('100%')
                  .height('100%')
                  .gesture(
                    GestureGroup(
                      GestureMode.Exclusive,
                      TapGesture({ count: 2 }).onAction(() => { this.toggleZoom(); }),
                      PinchGesture({ fingers: 2, distance: 5 })
                        .onActionStart((event: GestureEvent) => { this.startPinch(event); })
                        .onActionUpdate((event: GestureEvent) => { this.updatePinch(event); })
                        .onActionEnd(() => { this.finishZoom(); }),
                      PanGesture({ fingers: 1, direction: PanDirection.All, distance: 3 })
                        .onActionStart((event: GestureEvent) => { this.startPan(event); })
                        .onActionUpdate((event: GestureEvent) => { this.updatePan(event); })
                        .onActionEnd((event: GestureEvent) => { this.finishPan(event); }),
                      TapGesture({ count: 1 }).onAction(() => { this.showControls = !this.showControls; })
                    )
                  )
              } else {
                // 未放大态：不挂 Pan，水平滑动让给 Swiper 翻页
                Stack()
                  .width('100%')
                  .height('100%')
                  .gesture(
                    GestureGroup(
                      GestureMode.Exclusive,
                      TapGesture({ count: 2 }).onAction(() => {
                        if (idx === this.currentIndex) this.toggleZoom();
                      }),
                      PinchGesture({ fingers: 2, distance: 5 })
                        .onActionStart((event: GestureEvent) => { if (idx === this.currentIndex) this.startPinch(event); })
                        .onActionUpdate((event: GestureEvent) => { if (idx === this.currentIndex) this.updatePinch(event); })
                        .onActionEnd(() => { if (idx === this.currentIndex) this.finishZoom(); }),
                      TapGesture({ count: 1 }).onAction(() => {
                        this.showControls = !this.showControls;
                      })
                    )
                  )
              }
            }
            .width('100%')
            .height('100%')
            .onAreaChange((_oldArea: Area, newArea: Area) => {
              if (idx === this.currentIndex) {
                const w = Math.max(1, Number(newArea.width));
                const h = Math.max(1, Number(newArea.height));
                this.viewportWidth = w;
                this.viewportHeight = h;
                this.panX = this.clampPanX(this.panX, this.zoomScale);
                this.panY = this.clampPanY(this.panY, this.zoomScale);
              }
            })
          }, (url: string, idx: number) => `${idx}_${url}`)
        }
        .index(this.currentIndex)
        .vertical(false)
        .autoPlay(false)
        .indicator(false)
        .itemSpace(0)
        .curve(Curve.EaseOut)
        .duration(220)
        .onChange((index: number) => {
          this.currentIndex = index;
          this.resetZoom();
        })
        .width('100%')
        .height('100%')
      }

      if (this.showControls) {
        Column() {
          Row() {
            Stack() {
              Text(`${this.currentIndex + 1} / ${this.urls.length}`)
                .fontSize(fs(14, this.fontScale))
                .fontColor(Color.White)
            }
            .backgroundColor(Theme.glassControl(true))
            .border({ width: 0.5, color: Theme.glassControlLine(true) })
            .shadow({ radius: 8, color: '#33000000', offsetY: 1 })
            // 圆角 26：与全局卡片统一口径（本胶囊高约 28vp，圆角已被裁为全圆，视觉不变）
            .borderRadius(26)
            .padding({ left: 12, right: 12, top: 4, bottom: 4 })

            Blank()
          }
          .width('100%')
          .padding({ left: Spacing.lg, right: Spacing.lg, top: 12, bottom: 10 })

          Blank().layoutWeight(1)

          Row({ space: 12 }) {
            Blank().layoutWeight(1)
            Stack() {
              SymbolGlyph($r('sys.symbol.xmark'))
                .fontColor([Color.White])
                .fontSize(fs(20, this.fontScale))
            }
            .width(48)
            .height(48)
            .borderRadius(24)
            .backgroundColor(Theme.glassControl(true))
            .border({ width: 0.5, color: Theme.glassControlLine(true) })
            .shadow({ radius: 12, color: '#40000000', offsetY: 2 })
            .onClick(() => { this.getUIContext().getRouter().back(); })

            Stack() {
              if (this.saving) {
                LoadingProgress()
                  .width(20)
                  .height(20)
                  .color(Color.White)
              } else {
                SymbolGlyph($r('sys.symbol.arrow_down'))
                  .fontColor([Color.White])
                  .fontSize(fs(24, this.fontScale))
              }
            }
            .width(48)
            .height(48)
            .borderRadius(24)
            .backgroundColor(Theme.glassControl(true))
            .border({ width: 0.5, color: Theme.glassControlLine(true) })
            .shadow({ radius: 12, color: '#40000000', offsetY: 2 })
            .enabled(!this.saving && this.urls.length > 0)
            .onClick(() => { this.saveCurrentImage(); })
          }
          .width('100%')
          .padding({ left: Spacing.lg, right: Spacing.lg, bottom: 28 })
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.Start)
        .hitTestBehavior(HitTestMode.Transparent)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }

  private getScale(idx: number): number {
    return idx === this.currentIndex ? this.zoomScale : 1;
  }

  private getPanX(idx: number): number {
    return idx === this.currentIndex ? this.panX : 0;
  }

  private getPanY(idx: number): number {
    return idx === this.currentIndex ? this.panY : 0;
  }

  private toggleZoom(): void {
    if (this.zoomScale > 1.05) {
      // 缩回原位：动画平滑回正
      this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.zoomScale = 1;
        this.panX = 0;
        this.panY = 0;
      });
      this.dragReady = false;
    } else {
      // 双击放大：动画平滑放大到 2x
      this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.zoomScale = 2;
        this.panX = this.clampPanX(this.panX, this.zoomScale);
        this.panY = this.clampPanY(this.panY, this.zoomScale);
      });
    }
  }

  private startPinch(event: GestureEvent): void {
    this.pinchBaseScale = this.zoomScale;
    this.pinchBasePanX = this.panX;
    this.pinchBasePanY = this.panY;
    this.pinchCenterX = Number(event.pinchCenterX);
    this.pinchCenterY = Number(event.pinchCenterY);
  }

  private updatePinch(event: GestureEvent): void {
    const rawScale: number = this.pinchBaseScale * Number(event.scale);
    const nextScale: number = Math.max(1, Math.min(4, rawScale));
    const centerX: number = Number(event.pinchCenterX);
    const centerY: number = Number(event.pinchCenterY);
    const baseScale: number = Math.max(0.01, this.pinchBaseScale);
    const scaleRatio: number = nextScale / baseScale;
    const baseCenterX: number = this.viewportWidth / 2;
    const baseCenterY: number = this.viewportHeight / 2;
    const contentX: number = (this.pinchBasePanX + this.pinchCenterX - baseCenterX) / baseScale;
    const contentY: number = (this.pinchBasePanY + this.pinchCenterY - baseCenterY) / baseScale;
    const nextPanX: number = (centerX - baseCenterX) - contentX * nextScale;
    const nextPanY: number = (centerY - baseCenterY) - contentY * nextScale;
    this.zoomScale = nextScale;
    this.panX = this.clampPanX(nextPanX, nextScale);
    this.panY = this.clampPanY(nextPanY, nextScale);
  }

  private finishZoom(): void {
    if (this.zoomScale < 1.05) {
      this.zoomScale = 1;
    }
    if (this.zoomScale === 1) {
      this.panX = 0;
      this.panY = 0;
    } else {
      this.panX = this.clampPanX(this.panX, this.zoomScale);
      this.panY = this.clampPanY(this.panY, this.zoomScale);
    }
  }

  private startPan(event: GestureEvent): void {
    this.panStartX = event.offsetX;
    this.panStartY = event.offsetY;
    this.panBaseX = this.panX;
    this.panBaseY = this.panY;
    this.dragReady = this.zoomScale > 1.05;
  }

  private updatePan(event: GestureEvent): void {
    if (this.dragReady && this.zoomScale > 1.05) {
      this.panX = this.clampPanX(this.panBaseX + event.offsetX - this.panStartX, this.zoomScale);
      this.panY = this.clampPanY(this.panBaseY + event.offsetY - this.panStartY, this.zoomScale);
    }
  }

  private finishPan(event: GestureEvent): void {
    if (this.dragReady && this.zoomScale > 1.05) {
      this.panX = this.clampPanX(this.panX, this.zoomScale);
      this.panY = this.clampPanY(this.panY, this.zoomScale);
      this.dragReady = false;
    }
  }

  private clampPanX(value: number, scale: number): number {
    const limit: number = Math.max(0, (this.viewportWidth * Math.max(1, scale - 1)) / 2);
    return Math.max(-limit, Math.min(limit, value));
  }

  private clampPanY(value: number, scale: number): number {
    const limit: number = Math.max(0, (this.viewportHeight * Math.max(1, scale - 1)) / 2);
    return Math.max(-limit, Math.min(limit, value));
  }

  private resetZoom(): void {
    this.zoomScale = 1;
    this.panX = 0;
    this.panY = 0;
    this.dragReady = false;
  }

  private async requestSavePermission(): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const result = await atManager.requestPermissionsFromUser(
        this.context,
        ['ohos.permission.WRITE_IMAGEVIDEO', 'ohos.permission.READ_IMAGEVIDEO']
      );
      return result.authResults.every((auth: number) => auth === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED);
    } catch (e) {
      return false;
    }
  }

  private async saveCurrentImage(): Promise<void> {
    if (this.urls.length === 0 || this.saving) {
      return;
    }
    this.saving = true;
    try {
      const hasPermission = await this.requestSavePermission();
      if (!hasPermission) {
        this.getUIContext().getPromptAction().showToast({ message: '需要存储权限才能保存图片' });
        return;
      }
      const imageUrl: string = this.urls[this.currentIndex];
      const bytes: ArrayBuffer = await HttpClient.getBinary(imageUrl, {
        'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
        'Referer': 'https://tieba.baidu.com/'
      });
      if (bytes.byteLength === 0) {
        throw new Error('图片内容为空');
      }
      const helper = photoAccessHelper.getPhotoAccessHelper(this.context);
      const request = photoAccessHelper.MediaAssetChangeRequest.createAssetRequest(
        this.context,
        photoAccessHelper.PhotoType.IMAGE,
        'jpg',
        { title: `tieba_${Date.now()}` }
      );
      request.addResource(photoAccessHelper.ResourceType.IMAGE_RESOURCE, bytes);
      await helper.applyChanges(request);
      this.getUIContext().getPromptAction().showToast({ message: '已保存到图库' });
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({ message: '保存失败，请重试' });
    } finally {
      this.saving = false;
    }
  }
}