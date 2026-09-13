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

﻿import { common, ConfigurationConstant, Want } from '@kit.AbilityKit';
import { curves } from '@kit.ArkUI';
import { AuthManager } from '../service/AuthManager';
import { FontSizeManager } from '../service/FontSizeManager';
import { UsageHabitsManager } from '../service/UsageHabitsManager';
import { TiebaService } from '../service/TiebaService';
import { CacheManager } from '../cache/CacheManager';
import { CACHE_KEY, CACHE_TTL, PRIVACY_POLICY_URL, PRIVACY_POLICY_VERSION } from '../common/Constants';
import { FollowItem, UserInfo, UserStats } from '../model/DataModel';
import { Theme, fs, isDarkMode, initDarkMode, ImmBlur, ImmMaterial, MaterialManager } from '../common/Theme';
import { FavoriteTab } from './Favorite';
import { MessagesTab } from './MessagesTab';
import { MineTab } from './MineTab';
import { ForumsTab } from './ForumsTab';
import { HomeTab } from './HomeTab';

enum TabIndex {
  Home = 0,
  Forums = 1,
  Favorite = 2,
  Messages = 3,
  Mine = 4,
}

@Entry
@Component
struct Index {
  @State selectedTab: number = TabIndex.Home;
  // Tab 滑入动画：prevTab 记录正在退场滑出的页面（-1 表示无）；inOffset/outOffset 为进场/退场页横向位移百分比
  @State prevTab: number = -1;
  @State inOffset: number = 0;
  @State outOffset: number = 0;
  private animLock: boolean = false;
  // 收藏页常驻：记录上次登录态 key（登录/登出/换号时变化），用于通知收藏页刷新账号数据
  private favLoginLastKey: string = '';
  // 关注吧快照（进吧页自管渲染）：供「我的」页关注吧统计与宿主回传使用
  @State follows: FollowItem[] = [];
  @StorageLink('darkTick') @Watch('onDarkTick') darkTick: number = 0;
  @State isDark: boolean = false;
  @State loggedIn: boolean = false;
  @State userName: string = '';
  @State userAvatar: string = '';
  @State userStats: UserStats = { postCount: -1, agreeCount: -1 };
  @State statsLoading: boolean = false;
  @State statsError: boolean = false;
  @State followUserCount: number = -1;
  @State followUserLoading: boolean = false;
  /** 当前用户头部昵称是否已用 profile 实时昵称校准（本会话仅校准一次，避免频繁请求） */
  userProfileVerified: boolean = false;
  @State isWideScreen: boolean = false;
  @State currentWidth: number = 360;
  @StorageLink('fontScale') fontScale: number = 1.0;
  @StorageLink('favEditing') favEditing: boolean = false;
  @State materialSupported: boolean = true;
  /**
   * 首启合规闸门阶段：0=正在读本地授权记录（不透明占位底，防闪主界面）1=待用户同意（隐私政策浮层）2=已通过（渲染主界面）
   * 未进入阶段 2 时主界面（Tabs / PagesStack / HomeTab）完全不参与构建，
   * 确保用户同意前不读取任何业务数据、不发起任何网络请求。
   */
  @State privacyPhase: number = 0;

  // 延迟初始化：aboutToAppear生命周期阶段UIContext就绪后赋值，避免类字段初始化期获取null
  private context?: common.UIAbilityContext;

  /**
   * 安全获取 UIAbilityContext：优先使用已缓存this.context；兜底现场获取
   */
  private getUIAbilityContext(): common.UIAbilityContext {
    if (this.context) {
      return this.context;
    }
    const liveCtx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (liveCtx) {
      this.context = liveCtx;
    }
    return liveCtx;
  }

  async aboutToAppear(): Promise<void> {
    // 生命周期阶段UIContext已就绪，安全初始化context缓存
    this.context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    // 闸门前置项：仅为「确定占位底配色 + 探测材质能力」的纯本地读取，不涉及个人信息、不发起网络请求。
    // 深色态必须先算：否则系统深色下占位底会先闪一帧浅色再切黑。
    MaterialManager.init();
    this.materialSupported = MaterialManager.isSupported();
    // 先初始化 UsageHabitsManager：恢复「跟随系统深色 / 手动深色」持久化值。
    // 必须在读 config.colorMode 之前完成，否则冷启动会按 v1.x 「永远跟随系统」语义兜底，
    // 旧用户启过深色模式再重启仍会被打回浅色。
    await UsageHabitsManager.getInstance().init(this.getUIAbilityContext());
    const followSys: boolean = UsageHabitsManager.getInstance().isFollowSystemDark();
    const sysDark: boolean = this.getUIAbilityContext().config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    // 跟随系统：取系统当前态；否则按用户手动设置（首次启动默认 false=浅色）
    const resolvedDark: boolean = followSys ? sysDark : UsageHabitsManager.getInstance().isDarkModeManual();
    this.isDark = resolvedDark;
    // 冷启动只同步应用内状态：此时必然与「用户最终选择态」一致，下发 setColorMode 是多余的重建
    initDarkMode(resolvedDark);
    // 合规闸门：用户同意当前版本隐私政策前，不初始化登录态、不读业务缓存、不发任何请求
    // （应用市场强制要求：征得同意前不得收集任何信息。未同意时直接 return，initApp 整体不执行）
    if (!await this.isPrivacyAgreed()) {
      this.privacyPhase = 1;
      return;
    }
    this.privacyPhase = 2;
    await this.initApp();
  }

  /**
   * 是否已同意当前版本隐私政策。
   * 落盘的是「已同意的政策版本号」而非布尔值：政策实质变更时递增 PRIVACY_POLICY_VERSION，
   * 老用户无需清数据即可重新收到同意弹窗。读取异常一律按「未同意」处理（宁可多弹一次，不可漏弹）。
   */
  private async isPrivacyAgreed(): Promise<boolean> {
    try {
      const cache = CacheManager.getInstance();
      await cache.init(this.getUIAbilityContext());
      return (await cache.get(CACHE_KEY.PRIVACY_AGREED)) === PRIVACY_POLICY_VERSION;
    } catch (e) {
      return false;
    }
  }

  /** 用户同意：落盘版本号后放行全部业务初始化（写盘失败也放行，不因存储异常把用户卡在弹窗上） */
  private async onPrivacyAgree(): Promise<void> {
    try {
      const cache = CacheManager.getInstance();
      await cache.init(this.getUIAbilityContext());
      await cache.put(CACHE_KEY.PRIVACY_AGREED, PRIVACY_POLICY_VERSION);
    } catch (e) {
      // 写盘失败不阻断：本次会话正常放行，下次启动会再弹一次
    }
    this.privacyPhase = 2;
    await this.initApp();
  }

  /** 用户拒绝：直接退出应用（不进入任何功能） */
  private onPrivacyReject(): void {
    this.getUIAbilityContext().terminateSelf().catch(() => {});
  }

  /** 打开完整隐私政策（与仓库 docs/PRIVACY.md 同源的 GitHub 渲染页） */
  private openPrivacyPolicy(): void {
    const want: Want = { uri: PRIVACY_POLICY_URL, action: 'ohos.want.action.viewData', type: 'text/plain' };
    this.getUIAbilityContext().startAbility(want).catch(() => {
      this.getUIContext().getPromptAction().showToast({ message: '打开失败，请稍后重试' });
    });
  }

  /** 业务初始化（登录态 / 字号 / 使用习惯 / 关注吧快照 / 首页冷启动）：仅在同意隐私政策后执行 */
  private async initApp(): Promise<void> {
    // 本地初始化并行执行
    await Promise.all([
      AuthManager.getInstance().init(this.getUIAbilityContext()),
      FontSizeManager.getInstance().init(this.getUIAbilityContext()),
      UsageHabitsManager.getInstance().init(this.getUIAbilityContext()),
    ]);
    this.refreshLoginState();
    // 进吧页已抽为自含组件（挂载即加载）：这里仅同步关注吧快照，供「我的」页关注吧统计使用
    this.loadFollowsForMine();
    if (this.loggedIn) {
      this.loadUserStats();
      this.loadFollowUserCount();
    }
    // 头部昵称校准：onPageShow 可能早于登录态初始化完成而跳过，
    // 这里在 init 完成后兜底执行一次（userProfileVerified 保证本会话只校准一次）
    if (this.loggedIn && (!this.userProfileVerified || this.userName === '' || this.userName === '贴吧用户' || this.userAvatar === '')) {
      this.refreshUserProfile();
    }
    // 首页已抽为自含组件 HomeTab（约 AppStorage 初始化 + UsageHabits 开关恢复完成后）：
    // 自增 homeBootRequest 通知其冷启动加载（缓存直出，不做后台刷新；加载时机晚于 UsageHabits 恢复开关，
    // 使「仅推荐关注的吧」首次 Watch 不再被初始化阶段的开关恢复误触发）
    AppStorage.setOrCreate<number>('homeBootRequest', (AppStorage.get<number>('homeBootRequest') ?? 0) + 1);
  }

  /** 加载当前账号关注吧快照：缓存直出 + 网络覆盖写缓存，供 MineTab 关注吧统计与宿主快照使用 */
  private async loadFollowsForMine(): Promise<void> {
    if (!this.loggedIn) {
      this.follows = [];
      return;
    }
    try {
      const cached = await CacheManager.getInstance().getWithTtl<FollowItem[]>(CACHE_KEY.FOLLOW_LIST);
      if (cached && cached.length > 0) {
        this.follows = cached;
      }
      const result = await TiebaService.getInstance().fetchFollowList(1);
      if (result.list.length > 0) {
        this.follows = result.list;
        await CacheManager.getInstance().putWithTtl(CACHE_KEY.FOLLOW_LIST, result.list, CACHE_TTL.FOLLOW_LIST);
      }
    } catch (e) {
      // 快照加载失败不阻断启动
    }
  }

  onPageShow(): void {
    // 合规闸门未通过（首启同意弹窗仍在展示）时，不做任何登录态读取与刷新动作
    if (this.privacyPhase < 2) {
      return;
    }
    this.refreshLoginState();
    if (this.loggedIn) {
      this.loadUserStats();
      this.loadFollowUserCount();
    } else {
      this.userStats = { postCount: -1, agreeCount: -1 };
      this.followUserCount = -1;
      this.statsError = false;
    }
    // 头部昵称与列表/详情保持一致：首次进入（或本地仍是占位名/旧用户名）时
    // 用 profile 实时昵称校准一次；成功后本会话不再重复请求
    if (this.loggedIn && (!this.userProfileVerified || this.userName === '' || this.userName === '贴吧用户' || this.userAvatar === '')) {
      this.refreshUserProfile();
    }
    // 从详情页返回时：自增 homePageShownTick 通知自含组件 HomeTab 用详情页实时昵称回填列表（不触发网络）
    AppStorage.setOrCreate<number>('homePageShownTick', (AppStorage.get<number>('homePageShownTick') ?? 0) + 1);
    // 从其它页面返回（如 ThreadList/ThreadDetail 浏览后回退）时：自增 forumsRefreshRequest 通知进吧 Tab
    // 静默刷新「我的足迹」（本地缓存直出，不发关注列表网络，避免切换回来足迹空白后闪现）
    AppStorage.setOrCreate<number>('forumsRefreshRequest', (AppStorage.get<number>('forumsRefreshRequest') ?? 0) + 1);
  }

  private async loadUserStats(): Promise<void> {
    if (this.statsLoading || !this.loggedIn) {
      return;
    }
    const user = AuthManager.getInstance().getUser();
    const userId: string = user?.userId ?? '';
    if (userId.trim().length === 0) {
      this.userStats = { postCount: -1, agreeCount: -1 };
      this.statsError = true;
      return;
    }
    this.statsLoading = true;
    this.statsError = false;
    try {
      this.userStats = await TiebaService.getInstance().fetchUserStats(userId);
    } catch (e) {
      this.statsError = true;
      this.userStats = { postCount: -1, agreeCount: -1 };
    } finally {
      this.statsLoading = false;
    }
  }

  /** 加载当前登录用户的关注用户总数（follow_list 接口 total 字段；失败降级 '--'） */
  private async loadFollowUserCount(): Promise<void> {
    if (this.followUserLoading || !this.loggedIn) {
      return;
    }
    this.followUserLoading = true;
    try {
      const result = await TiebaService.getInstance().fetchFollowUserList(0, 1);
      this.followUserCount = result.total > 0 ? result.total : result.list.length;
    } catch (e) {
      this.followUserCount = -1;
    } finally {
      this.followUserLoading = false;
    }
  }

  private async refreshUserProfile(): Promise<void> {
    try {
      const profile = await TiebaService.getInstance().fetchUserInfo();
      const current = AuthManager.getInstance().getUser();
      const uid: string = profile?.userId || current?.userId || '';
      let name: string = profile?.name || current?.name || '贴吧用户';
      if (uid.length > 0) {
        // 用 profile 实时昵称校准头部显示名（与列表页/详情页完全一致），失败时保留接口名
        const nick: string = await TiebaService.getInstance().fetchUserNickname(uid);
        if (nick.length > 0) {
          name = nick;
        }
      }
      await AuthManager.getInstance().setUserInfo({
        userId: uid,
        name,
        avatar: profile?.avatar || current?.avatar || '',
        isLogin: true,
      });
      this.userProfileVerified = true;
      this.refreshLoginState();
      await this.loadUserStats();
      await this.loadFollowUserCount();
    } catch (e) {
      // 保留本地登录态和首字母头像兜底。
    }
  }

  private refreshLoginState(): void {
    this.loggedIn = AuthManager.getInstance().isLogin();
    const user: UserInfo | null = AuthManager.getInstance().getUser();
    this.userName = user?.name ?? '';
    this.userAvatar = user?.avatar ?? '';
    if (!this.loggedIn) {
      this.userStats = { postCount: -1, agreeCount: -1 };
      this.followUserCount = -1;
      this.statsError = false;
    }
    // 收藏页常驻（不随 Tab 切换重建）：登录/登出/换号时递增 favLoginRefresh，通知收藏页重载账号数据
    const loginKey: string = `${this.loggedIn ? '1' : '0'}|${user?.userId ?? ''}`;
    if (loginKey !== this.favLoginLastKey) {
      this.favLoginLastKey = loginKey;
      AppStorage.setOrCreate<number>('favLoginRefresh', (AppStorage.get<number>('favLoginRefresh') ?? 0) + 1);
      // 通用登录事件（各子 Tab 页常驻组件订阅：登录/登出/换号时重同步账号数据并失效账号级缓存）
      AppStorage.setOrCreate<number>('tabLoginRefresh', (AppStorage.get<number>('tabLoginRefresh') ?? 0) + 1);
    }
  }

  /** darkTick 递增（本页或子 Tab 页切换深色）→ 重读全局深色状态，保证各常驻页面/组件同步 */
  private onDarkTick(): void {
    this.isDark = isDarkMode();
  }

  /** 我的页退出登录（由 MineTab 回调触发）：登出→全局登录态刷新→清统计；进吧页已自管，无需再清 forumState */
  private handleMineLogout(): void {
    AuthManager.getInstance().logout().then(() => {
      this.refreshLoginState();
      this.userStats = { postCount: -1, agreeCount: -1 };
      this.followUserCount = -1;
      this.statsError = false;
    }).catch(() => {
    });
  }

  /**
   * 统一 Tab 切换入口：方向感知滑入动画。
   * 目标页在当前页右侧（index 更大）→ 新页从右侧滑入、旧页向左滑出；
   * 目标页在当前页左侧（index 更小）→ 新页从左侧滑入、旧页向右滑出。
   * 动画期间锁定（animLock），快速连点直接忽略，避免动画错乱。
   */
  private switchTab(index: number): void {
    // 重复点击当前已激活的 tab：首页 tab 触发整页刷新（按当前所在 feed），其余 tab 保持原行为
    if (index === this.selectedTab && !this.animLock && index === TabIndex.Home) {
      // 首页已抽为自含组件：自增 homeRetapRequest 通知 HomeTab 回顶并整页刷新（按当前 feed）
      AppStorage.setOrCreate<number>('homeRetapRequest', (AppStorage.get<number>('homeRetapRequest') ?? 0) + 1);
      return;
    }
    if (index === this.selectedTab || this.animLock) {
      return;
    }
    const dir: number = index > this.selectedTab ? 1 : -1;
    this.animLock = true;
    this.prevTab = this.selectedTab;
    this.selectedTab = index;
    // 初始位置（无动画赋值）：新页从 dir 方向侧外进入，旧页原位准备退场
    this.inOffset = dir * 100;
    this.outOffset = 0;
    this.getUIContext().animateTo(
      { duration: 320, curve: curves.springMotion(0.72, 0.86) },
      () => {
        this.outOffset = -dir * 100;
        this.inOffset = 0;
      }
    );
    // 复位：SDK 的 animateTo 无 onFinish 回调，用定时器在动画结束后卸载退场页并释放切换锁
    // 时长取动画时长的约 1.3 倍，确保退场页不提前卸载（弹簧曲线可能略有回弹超时）
    setTimeout(() => {
      this.prevTab = -1;
      this.outOffset = 0;
      this.animLock = false;
    }, 420);
  }

  /** 页面横向位移（百分比）：进场页用 inOffset，退场页用 outOffset */
  private tabOffset(index: number): string {
    if (index === this.selectedTab) {
      return `${this.inOffset}%`;
    }
    return `${this.outOffset}%`;
  }

  /** 层级：进场页盖在退场页之上 */
  private tabLayer(index: number): number {
    return index === this.selectedTab ? 1 : 0;
  }

  /**
   * 系统返回拦截（BUG-01）：收藏 Tab 子视图为 FavoriteTab 组件内状态切换（非路由栈），系统返回事件默认无法回退。
   * 收藏页处于可回退层级（favCanGoBack=true）时自增 favBackRequest 通知 FavoriteTab 逐级回退并拦截；
   * 根视图（favCanGoBack=false）放行系统默认（退出 App）。
   */
  onBackPress(): boolean {
    // 合规闸门未通过：返回键不生效，不允许绕过隐私政策弹窗进入应用（必须显式选择同意或不同意）
    if (this.privacyPhase < 2) {
      return true;
    }
    if (this.selectedTab === TabIndex.Favorite && AppStorage.get<boolean>('favCanGoBack') === true) {
      const req: number = (AppStorage.get<number>('favBackRequest') ?? 0) + 1;
      AppStorage.setOrCreate<number>('favBackRequest', req);
      return true;
    }
    return false;
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.privacyPhase >= 2) {
        // API26+ 沉浸材质生效范围仅限 Navigation 标题栏 / Tabs TabBar 槽位：
        // 支持时走真实 Tabs（底栏挂 tabBar，官方沉浸材质才渲染），其余走原手写叠放路径（与定稿一致，BottomBar 贴底悬浮）。
        if (this.materialSupported && MaterialManager.getApiLevel() >= 26) {
          this.FloatingTabsShell()
        } else {
          this.PagesStack()
          if (!this.favEditing) {
            this.BottomBar()
          }
        }
      } else {
        // 合规闸门未通过：主界面（含各 Tab 自含组件）不参与构建，只渲染占位/同意浮层
        this.PrivacyGate()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg(this.isDark))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .onAreaChange((oldValue: Area, newValue: Area) => {
      const width = newValue.width as number;
      this.currentWidth = width;
      this.isWideScreen = width >= 840;
    })
  }

  /**
   * 合规闸门浮层（不透明全屏，覆盖启动首帧）：
   * phase=0 读本地授权记录期间显示品牌占位（毫秒级，避免「先闪主界面再弹窗」）；
   * phase=1 显示隐私政策同意卡片。
   * 拒绝 → terminateSelf 退出应用；同意 → 落盘版本号并放行 initApp。
   */
  @Builder
  PrivacyGate() {
    Column() {
      if (this.privacyPhase === 1) {
        this.PrivacyCard()
      } else {
        Text('TiebaPura')
          .fontSize(fs(26, this.fontScale))
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.textPrimary(this.isDark))
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(Theme.bg(this.isDark))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  /** 隐私政策同意卡片：必须显式表态（不同意即退出），无倒计时自动同意、无默认勾选、点遮罩不消失 */
  @Builder
  PrivacyCard() {
    Column() {
      Text('隐私政策')
        .fontSize(fs(19, this.fontScale))
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.textPrimary(this.isDark))
        .width('100%')
        .textAlign(TextAlign.Start)

      Scroll() {
        Column({ space: 10 }) {
          Text('欢迎使用 TiebaPura。本应用是第三方非官方百度贴吧客户端，由个人开发者 a307608689-afk 独立开发，与百度公司无任何关联。')
            .fontSize(fs(14, this.fontScale))
            .fontColor(Theme.textSecondary(this.isDark))
            .lineHeight(fs(21, this.fontScale))
            .width('100%')
            .textAlign(TextAlign.Start)

          Text('为向您提供服务，我们会：')
            .fontSize(fs(14, this.fontScale))
            .fontColor(Theme.textSecondary(this.isDark))
            .lineHeight(fs(21, this.fontScale))
            .width('100%')
            .textAlign(TextAlign.Start)

          Text('· 仅在您的设备本地保存登录态、收藏、浏览历史等数据，不上传至我们控制的服务器；\n'
            + '· 为实现贴吧内容的浏览与检索，必要的请求参数会发送至百度贴吧官方接口；\n'
            + '· 不申请通讯录、位置、相册、麦克风等与功能无关的任何权限；\n'
            + '· 不含任何第三方广告、统计或推送 SDK；\n'
            + '· 不进行用户画像与个性化推荐。')
            .fontSize(fs(14, this.fontScale))
            .fontColor(Theme.textSecondary(this.isDark))
            .lineHeight(fs(21, this.fontScale))
            .width('100%')
            .textAlign(TextAlign.Start)
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ maxHeight: fs(236, this.fontScale) })
      .scrollBar(BarState.Off)
      .margin({ top: 12 })

      Text('查看完整《隐私政策》')
        .fontSize(fs(14, this.fontScale))
        .fontColor(Theme.brand())
        .decoration({ type: TextDecorationType.Underline, color: Theme.brand() })
        .margin({ top: 14 })
        .onClick(() => { this.openPrivacyPolicy(); })

      Text('点击「同意并继续」表示您已阅读并同意上述政策；若不同意，您将无法使用本应用。')
        .fontSize(fs(12, this.fontScale))
        .fontColor(Theme.textTertiary(this.isDark))
        .lineHeight(fs(18, this.fontScale))
        .width('100%')
        .textAlign(TextAlign.Start)
        .margin({ top: 14 })

      Row({ space: 12 }) {
        Button('不同意')
          .fontSize(fs(15, this.fontScale))
          .fontColor(Theme.textSecondary(this.isDark))
          .backgroundColor(Theme.bgElevated(this.isDark))
          .layoutWeight(1)
          .height(44)
          .borderRadius(22)
          .onClick(() => { this.onPrivacyReject(); })

        Button('同意并继续')
          .fontSize(fs(15, this.fontScale))
          .fontColor(Color.White)
          .backgroundColor(Theme.brand())
          .layoutWeight(1)
          .height(44)
          .borderRadius(22)
          .onClick(() => { this.onPrivacyAgree(); })
      }
      .width('100%')
      .margin({ top: 18 })
    }
    .width(this.currentWidth >= 600 ? 440 : Math.max(this.currentWidth - 56, 260))
    .padding({ left: 20, right: 20, top: 22, bottom: 20 })
    .borderRadius(20)
    .backgroundColor(Theme.bgCard(this.isDark))
    .border({ width: 0.5, color: Theme.divider(this.isDark) })
    .shadow({ radius: 24, color: '#40000000', offsetY: 8 })
  }

  /** API26+ 悬浮玻璃路径：真实 Tabs 单内容承载页叠层，底栏胶囊放入 .tabBar() 槽位（引擎认可其属于 TabBar 生效范围） */
  @Builder
  FloatingTabsShell() {
    Tabs({ barPosition: BarPosition.End }) {
      TabContent() {
        this.PagesStack()
      }
      .tabBar(this.FloatingBarSlot())
    }
    .width('100%')
    .height('100%')
    .vertical(false)
    .scrollable(false)
    .barOverlap(true)
    // favEditing（收藏编辑态）时把栏高收为 0：真实 Tabs 槽位即便 tabBar 内容为空，悬浮磨砂背板
    // （barFloatingStyle + systemMaterial）仍会按 74vp 渲染，压住收藏页底部编辑操作栏；
    // 收为 0 后整条背板随栏一起消失（barOverlap 下内容区尺寸不变，PagesStack 不重建、页面状态不丢）
    .barHeight(this.favEditing ? 0 : 74)
    .barBackgroundColor(Color.Transparent)
    // 收藏编辑态：barHeight 收 0 后官方悬浮背板（barFloatingStyle + systemMaterial）仍会残留一条磨砂，
    // 压住收藏页底部编辑按钮；故编辑态整体不传 floating style（Optional 传 undefined）彻底移除残留底栏
    .barFloatingStyle(this.favEditing ? undefined : this.floatingBarStyle())
    .backgroundColor(Color.Transparent)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .clip(false)
  }

  /** 悬浮胶囊宽度：与手写定稿一致（宽屏 480，窄屏 屏宽-48，下限 240 防极端异常） */
  /** 官方悬浮底栏样式（非编辑态）：编辑态不传此样式，避免 barHeight=0 时仍残留一条磨砂背板 */
  private floatingBarStyle(): FloatingTabBarStyle {
    return {
      barWidth: {
        smallBarWidth: this.pillWidth(),
        mediumBarWidth: this.pillWidth(),
        largeBarWidth: this.pillWidth()
      },
      barBottomMargin: 30,
      systemMaterial: ImmMaterial.floatingBar()
    };
  }

  private pillWidth(): number {
    if (this.isWideScreen) {
      return 480;
    }
    const w: number = this.currentWidth > 0 ? this.currentWidth - 48 : 312;
    return w > 240 ? w : 240;
  }

  @Builder
  FloatingBarSlot() {
    if (!this.favEditing) {
      Stack() {
        Row() {
          this.BottomGlow(TabIndex.Home)
          this.BottomGlow(TabIndex.Forums)
          this.BottomGlow(TabIndex.Favorite)
          this.BottomGlow(TabIndex.Messages)
          this.BottomGlow(TabIndex.Mine)
        }
        .width('100%')
        .height('100%')
        .padding({ left: 8, right: 8, top: 6, bottom: 6 })

        Row() {
          this.BottomItem('⌂', '首页', TabIndex.Home)
          this.BottomItem('▦', '进吧', TabIndex.Forums)
          this.BottomItem('★', '收藏', TabIndex.Favorite)
          this.BottomItem('✉', '消息', TabIndex.Messages)
          this.BottomItem('♙', '我的', TabIndex.Mine)
        }
        .width('100%')
        .height('100%')
        .padding({ left: 8, right: 8, top: 6, bottom: 6 })
      }
      .width('100%')
      .height('100%')
    }
  }

  @Builder
  PagesStack() {
    Stack() {
      // 每页外层包一层全屏容器：组件调用点不能链式挂属性（编译器按 void 处理），translate/zIndex 挂在容器上
      // 首页常驻组件树：避免切走后组件销毁导致滚动位置丢失（滚动偏移/feed 状态在 HomeTab 内部保留）。
      // 非当前页/非动画期间用 visibility 隐藏（Hidden 不绘制、不重建）。
      Stack() {
        HomeTab()
      }
      .width('100%')
      .height('100%')
      .translate({ x: this.tabOffset(TabIndex.Home) })
      .zIndex(this.tabLayer(TabIndex.Home))
      .visibility(this.selectedTab === TabIndex.Home || this.prevTab === TabIndex.Home
        ? Visibility.Visible : Visibility.Hidden)
      if (this.prevTab === TabIndex.Forums || this.selectedTab === TabIndex.Forums) {
        Stack() {
          ForumsTab({
            onFollowsSync: (list: FollowItem[]): void => { this.follows = list; }
          })
        }
        .width('100%')
        .height('100%')
        .translate({ x: this.tabOffset(TabIndex.Forums) })
        .zIndex(this.tabLayer(TabIndex.Forums))
      }
      // 收藏页常驻组件树：避免切走后组件销毁导致数据重载（重进收藏页重现加载态）。
      // 非当前页/非动画期间用 visibility 隐藏（Hidden 不绘制、不重建，状态与滚动位置保留）。
      Stack() {
        FavoriteTab()
      }
      .width('100%')
      .height('100%')
      .translate({ x: this.tabOffset(TabIndex.Favorite) })
      .zIndex(this.tabLayer(TabIndex.Favorite))
      .visibility(this.selectedTab === TabIndex.Favorite || this.prevTab === TabIndex.Favorite
        ? Visibility.Visible : Visibility.Hidden)
      if (this.prevTab === TabIndex.Messages || this.selectedTab === TabIndex.Messages) {
        Stack() {
          MessagesTab()
        }
        .width('100%')
        .height('100%')
        .translate({ x: this.tabOffset(TabIndex.Messages) })
        .zIndex(this.tabLayer(TabIndex.Messages))
      }
      if (this.prevTab === TabIndex.Mine || this.selectedTab === TabIndex.Mine) {
        Stack() {
          MineTab({
            loggedIn: $loggedIn,
            userName: $userName,
            userAvatar: $userAvatar,
            userStats: $userStats,
            statsLoading: $statsLoading,
            statsError: $statsError,
            followUserCount: $followUserCount,
            followUserLoading: $followUserLoading,
            follows: $follows,
            openFavorite: (): void => { this.switchTab(TabIndex.Favorite); },
            onLogout: (): void => { this.handleMineLogout(); }
          })
        }
        .width('100%')
        .height('100%')
        .translate({ x: this.tabOffset(TabIndex.Mine) })
        .zIndex(this.tabLayer(TabIndex.Mine))
      }
    }
    .width('100%')
    .height('100%')
    .zIndex(0)
    .backgroundColor(Color.Transparent)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .clip(false)
  }

  @Builder
  BottomBar() {
    Stack() {
      Row() {
        this.BottomGlow(TabIndex.Home)
        this.BottomGlow(TabIndex.Forums)
        this.BottomGlow(TabIndex.Favorite)
        this.BottomGlow(TabIndex.Messages)
        this.BottomGlow(TabIndex.Mine)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 8, right: 8, top: 6, bottom: 6 })

      Row() {
        this.BottomItem('⌂', '首页', TabIndex.Home)
        this.BottomItem('▦', '进吧', TabIndex.Forums)
        this.BottomItem('★', '收藏', TabIndex.Favorite)
        this.BottomItem('✉', '消息', TabIndex.Messages)
        this.BottomItem('♙', '我的', TabIndex.Mine)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 8, right: 8, top: 6, bottom: 6 })
    }
    .width(this.isWideScreen ? 480 : 'calc(100% - 48vp)')
    .height(74)
    // 本分支仅 API<26 执行（26+ 走 FloatingTabsShell 槽位材质），此时 manualGlass 即兜底视觉
    .backgroundColor(MaterialManager.isSupported() ? Color.Transparent : Theme.manualGlass(this.isDark))
    .border({ width: 0.5, color: Theme.manualGlassBorder() })
    .shadow(Theme.glassShadowStyle()).backgroundEffect(ImmBlur.bar())
    .systemMaterial(ImmMaterial.bar())
    .borderRadius(37)
    .shadow({
      radius: 24,
      color: this.isDark ? '#55000000' : '#30101824',
      offsetY: 8
    })
    .margin({ bottom: 30 })
    .zIndex(20)
  }

  @Builder
  BottomGlow(index: number) {
    if (this.selectedTab === index) {
      Blank()
        .layoutWeight(1)
        .height(58)
        .margin({ left: 2, right: 2 })
    } else {
      Blank().layoutWeight(1)
    }
  }

  @Builder
  BottomItem(icon: string, label: string, index: number) {
    Column({ space: 3 }) {
      SymbolGlyph(this.symbolFor(index))
        .fontSize(fs(22, this.fontScale))
        .fontWeight(this.selectedTab === index ? FontWeight.Bold : FontWeight.Medium)
        .fontColor([this.selectedTab === index
          ? $r('sys.color.icon_emphasize')
          : $r('sys.color.icon_primary')])
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
      Text(label)
        .fontSize(fs(11, this.fontScale))
        .fontWeight(this.selectedTab === index ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.selectedTab === index
          ? $r('sys.color.font_emphasize')
          : $r('sys.color.font_primary'))
    }
    .layoutWeight(1)
    .height(58)
    .justifyContent(FlexAlign.Center)
    .borderRadius(29)
    .backgroundColor(Color.Transparent)
    .scale({ x: this.selectedTab === index ? 1.05 : 1, y: this.selectedTab === index ? 1.05 : 1 })
    .animation({ duration: 360, curve: curves.springMotion(0.72, 0.86) })
    .accessibilityText(label)
    .onClick(() => {
      this.switchTab(index);
    })
  }

  private symbolFor(index: number): Resource {
    if (index === TabIndex.Forums) {
      return $r('sys.symbol.grid');
    }
    if (index === TabIndex.Favorite) {
      return $r('sys.symbol.star');
    }
    if (index === TabIndex.Messages) {
      return $r('sys.symbol.envelope');
    }
    if (index === TabIndex.Mine) {
      return $r('sys.symbol.person');
    }
    return $r('sys.symbol.house_fill');
  }
}
