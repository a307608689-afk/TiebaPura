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

import { common, wantAgent, WantAgent, Want } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';

/**
 * 一键签到「后台签到」配套能力（单例）：
 * - 长时任务（dataTransfer）：把逐吧签到的等待搬到后台也不被系统冻结。
 *   否则应用退到后台后 JS 定时器停摆，慢速模式的长间隔等待会一直卡住，直到用户回到前台。
 * - 完成通知：签到结束时发一条系统通知（点击回到应用），固定 id 覆写式发布，不刷屏。
 * 所有能力均为「尽力而为」：长时任务或通知失败都不影响签到本身。
 */
const AUTO_SIGN_NOTIFICATION_ID: number = 1001;
const AUTO_SIGN_WANT_AGENT_REQUEST_CODE: number = 1001;

export class AutoSignNotifier {
  private static instance: AutoSignNotifier | null = null;
  private taskRunning: boolean = false;

  static getInstance(): AutoSignNotifier {
    if (AutoSignNotifier.instance === null) {
      AutoSignNotifier.instance = new AutoSignNotifier();
    }
    return AutoSignNotifier.instance;
  }

  /**
   * 确保通知可用：未授权时弹一次系统授权框。
   * 必须在用户点按手势（后台签到按钮）中调用，否则系统不会弹框。
   */
  async ensureNotificationEnabled(context: common.UIAbilityContext): Promise<boolean> {
    try {
      if (await notificationManager.isNotificationEnabled()) {
        return true;
      }
      await notificationManager.requestEnableNotification(context);
      return await notificationManager.isNotificationEnabled();
    } catch (e) {
      const message: string = e instanceof Error ? e.message : `${e}`;
      console.warn(`[AUTOSIGN] 通知授权失败: ${message}`);
      return false;
    }
  }

  /** 启动长时任务：后台签到期间进程不被冻结（重复调用幂等） */
  async startBackgroundTask(context: common.UIAbilityContext): Promise<boolean> {
    if (this.taskRunning) {
      return true;
    }
    try {
      const agent: WantAgent = await this.buildWantAgent(context);
      await backgroundTaskManager.startBackgroundRunning(context,
        backgroundTaskManager.BackgroundMode.DATA_TRANSFER, agent);
      this.taskRunning = true;
      console.info('[AUTOSIGN] 长时任务已启动（后台签到保活）');
      return true;
    } catch (e) {
      // 常见：KEEP_BACKGROUND_RUNNING 未授权 / 已有长时任务在跑 —— 都继续正常签到
      const message: string = e instanceof Error ? e.message : `${e}`;
      console.warn(`[AUTOSIGN] 长时任务启动失败，仍继续签到: ${message}`);
      return false;
    }
  }

  /** 结束长时任务（幂等；签到收尾时统一调用） */
  async stopBackgroundTask(context: common.UIAbilityContext): Promise<void> {
    if (!this.taskRunning) {
      return;
    }
    this.taskRunning = false;
    try {
      await backgroundTaskManager.stopBackgroundRunning(context);
      console.info('[AUTOSIGN] 长时任务已停止');
    } catch (e) {
      const message: string = e instanceof Error ? e.message : `${e}`;
      console.warn(`[AUTOSIGN] 长时任务停止失败: ${message}`);
    }
  }

  /** 发布签到完成通知（点击通知回到应用）；返回是否发布成功 */
  async publishComplete(context: common.UIAbilityContext, title: string, text: string): Promise<boolean> {
    try {
      const request: notificationManager.NotificationRequest = {
        id: AUTO_SIGN_NOTIFICATION_ID,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: title,
            text: text
          }
        }
      };
      try {
        request.wantAgent = await this.buildWantAgent(context);
      } catch (e) {
        // 无 wantAgent 也能正常发布，仅失去「点击通知回到应用」
      }
      await notificationManager.publish(request);
      console.info(`[AUTOSIGN] 完成通知已发布: ${text}`);
      return true;
    } catch (e) {
      const message: string = e instanceof Error ? e.message : `${e}`;
      console.warn(`[AUTOSIGN] 完成通知发布失败: ${message}`);
      return false;
    }
  }

  /** 点击通知回到应用（wantAgent 指向本应用 EntryAbility） */
  private async buildWantAgent(context: common.UIAbilityContext): Promise<WantAgent> {
    const want: Want = {
      bundleName: context.abilityInfo.bundleName,
      abilityName: context.abilityInfo.name
    };
    const info: wantAgent.WantAgentInfo = {
      wants: [want],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: AUTO_SIGN_WANT_AGENT_REQUEST_CODE,
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    return await wantAgent.getWantAgent(info);
  }
}
