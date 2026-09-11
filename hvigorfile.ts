import { appTasks } from '@ohos/hvigor-ohos-plugin';

/*
 * 本机签名材料注入（不随工程分发）
 * ---------------------------------------------------------------------------
 * 真实签名材料（p12 密钥库 + 口令 + 证书 + profile）放在 tools/signing.local.json。
 * 该文件被 .gitignore 与 tools/pack.ps1 双重排除：既不进 git 仓库，也不进发布包。
 *
 * 机制（hvigor 官方支持的本地覆盖）：
 *   hvigor 读取 hvigorfile 默认导出的 config，再由 projectOhosConfigManager.getOverrides()
 *   取 config.ohos.overrides.signingConfig，与 build-profile.json5 里的签名配置合并（覆盖优先）。
 * 于是：
 *   - tools/signing.local.json 存在          -> 注入 override，构建产出 entry-default-signed.hap
 *   - 不存在（他人 clone / CI / 无签名环境） -> 不注入任何配置，构建照常，产物为 unsigned
 * 这样 build-profile.json5 可以长期保持干净（signingConfigs: []），不含任何本机路径与口令。
 *
 * 注意：若在 DevEco Studio 里点了「自动签名」，它会直接往 build-profile.json5 写入
 * 本机绝对路径与口令。此时用 git checkout -- build-profile.json5 还原，并把材料搬到
 * tools/signing.local.json。
 */

declare const require: (id: string) => any;

function loadLocalSigning(): object | undefined {
  try {
    return require('./tools/signing.local.json');
  } catch (e) {
    return undefined;
  }
}

const localSigning = loadLocalSigning();

export default {
  system: appTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: [],      /* Custom plugin to extend the functionality of Hvigor. */
  /* 仅在找到本机签名材料时才注入；否则保持与改动前完全一致（不签名、不报错） */
  config: localSigning ? { ohos: { overrides: { signingConfig: localSigning } } } : undefined
}
