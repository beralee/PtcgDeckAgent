# Android 更新安装兼容修复（2026-09-29）

## 结论与边界

玩家截图为 0.6.1 → 0.6.2，包已就绪，提示“本次安装已取消”。没有该手机的型号、系统版本或日志，不能只凭截图确定它的唯一原因。本次已复现并修复更新器中的后台确认页故障，补齐独立的系统安装重试入口，产出本地正式签名 APK。没有上传、发布、修改网站清单或提交代码。

已核对旧 0.6.1 / build 61 与当前 0.6.2 / build 62 的包名均为 `com.example.ptcgdeckagent`，签名证书 SHA-256 均为 `301f30c5221085b11ced3e187d79700be42eeabecc5bb49220d0ba342ab5f37d`。线上清单中的 0.6.2 大小和摘要与本机分发包一致；这不是一次重新下载整个线上 APK 的字节审计。

## 可复现问题

使用修复前的独立更新验证包（复用正式更新组件），点击安装后立即返回桌面。Android 16 / API 36 模拟器记录：

```text
Background activity launch blocked!
CONFIRM_INSTALL ... from uid ... (BAL_BLOCK)
```

此时前台仍为桌面，但更新器的持久状态已经写成 `awaiting_user`。旧代码在 BroadcastReceiver 中调用 `context.startActivity()`，没有异常并不代表确认页真的显示。原始记录：`.tmp/update_install_20260929/background-before.log`。

另外，原生 `STATUS_FAILURE_ABORTED` 被统一映射为 `cancelled`，会把系统中止或撤销会话显示成玩家取消。Android 对该状态的定义并不限于用户点击取消，见 [PackageInstaller 状态说明](https://developer.android.com/reference/android/content/pm/PackageInstaller#STATUS_FAILURE_ABORTED)；前台启动约束见 [Android Activity 安全说明](https://developer.android.com/guide/components/activities/secure-bal)。

## 修复

- `InstallConfirmation` 只保存当前令牌的系统确认意图，由已恢复前台的游戏 Activity 启动。后台阶段为 `awaiting_foreground`，返回前台继续；不再建立独立的多任务安装页。
- 安装权限页返回时增加 `onMainResume` 权限重查，兼容未发送 Activity result 的设置页，并防止重复启动准备任务。
- `InstallOutcome` 区分系统中止、安全校验失败和成功，只记录稳定状态及数值诊断，不输出任意系统错误文本或私有文件路径。
- 会话中止、确认页启动失败或超时后，同一个操作按钮改为“使用系统安装器”。玩家再次点击后，重新校验已有 APK 的大小、摘要、包名、签名和递增构建号，再经系统 APK 安装页确认。
- `VerifiedApkProvider` 不导出，只有本次活动令牌对应的已校验单个 APK 可被读取；拒绝写入与越界路径。URI 只授予读取权限，取消/新尝试使旧令牌失效。不会共享玩家目录，也不会绕过 Android 安装授权或安全校验。
- APK 导出检查增加新类、JNI 方法及 Provider 私有性检查，避免只更新 GDScript 而漏打原生组件。

## 验证

| 层 | 结果 |
| --- | --- |
| 测试先行 | 新增 3 个状态/UI 用例先失败；原有 23 个通过 |
| Godot 更新相关完整组 | AppUpdater 26、AppUpdateManifest 8、UpdateChecker 22、ExportPresets 25，共 81 个通过；最后的 JNI 调用调整后 AppUpdater 26 个再次通过 |
| Java 安装结果分类 | 7 个通过，覆盖系统中止、旧/新安全校验状态及未知失败；纳入原生组件构建门 |
| Python 清单生成 | 5 个通过 |
| 原安装路径实装 | 权限拒绝后重试、系统取消后重试、确认期间杀进程后重试、真实 A→B 保留数据，共 4 个通过 |
| 兼容路径实装 | 后台排队、返回前台确认与中止分类、取消与私有 APK 权限、真实 A→B 保留数据，共 4 个通过 |
| APK 导出 | 35 项更新组件检查通过；24/24 必需策略资源、49 项 2D 资源、原生库及 16 KiB 对齐检查通过 |
| 最终正式 APK | 签名验证通过，与旧版证书一致；在模拟器覆盖安装并进入首页，无脚本错误、解析错误或崩溃 |

实装设备为 Android 16 / API 36 / x86_64 模拟器；独立 A/B 验证包同时包含 ARM64 和 x86_64，正式 APK 为 ARM64。正式包在模拟器使用 ARM 转译启动，不等同品牌 ARM 真机验收。没有新做游戏全量功能/对战回归，也不提升 CABT、策略或 A5 资格声明。

保留了验证中的失败：首次实装发现 JNI singleton 的 `has_method()` 不能用于判断 Java 方法存在，已删除该错误守卫，改由实际 DEX 导出检查；测试驱动随后修复了读取上次终态过早、忽略 stderr，以及设置页打开后游戏渲染暂停导致 UI 记录延迟的问题。最终两条实装流程完整重跑，没有跳过安装或数据保留断言。

原始证据在 `.tmp/update_install_20260929/`：`red/report.json`、`green/report.json`、`final-godot/report.json`、`compat-native-pass.json`、`session-native-retry.json`、`release-signature.txt`、`release-smoke.json`、`release-home.png`。包体/资源检查在 `.tmp/ptcgdap_device_release/android_install_fix_20260929/`。

## 本地交付与旧版恢复

`output/android-install-fix-20260929/PtcgDeckAgent-0.6.2-install-fix.apk`

- 版本仍为 0.6.2 / build 62，是本地手动覆盖修复包，不冒充新的线上版本。
- 大小：287,046,780 字节。
- SHA-256：`b5dae27486bbf83231ea6523999ff6ecb24bf1ed2838054f27aae45b82725961`。
- 旧版反复安装失败时，需手动打开该 APK 并覆盖安装，**不要先卸载**。已经安装在手机中的旧更新器不能通过“下载完成”自行替换安装逻辑。
- 后续若要通过版本检查向已装 0.6.2 的玩家推送，须另行生成递增版本和最终清单；本次没有发布这个动作。

## 回滚

本轮开始前的更新组件快照在 `.tmp/update_install_20260929/before/`。只撤销本轮涉及的局部增量、新 Java 类和导出检查，并按需重建 AAR；不要将整个工作区恢复到 Git HEAD，因为本轮开始时这些文件已有大量未提交改动。保留玩家数据和既有更新缓存。局部代码回退不改变原签名、包名或线上文件。
