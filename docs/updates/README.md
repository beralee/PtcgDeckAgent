# 游戏内更新

2026-10-05：首页只保留一个更新入口，移除全局浮层；修复 Windows 升级成功后待更新记录未清理、再次启动仍恢复提示的问题，并验证安装后的普通重开。工程开发版不再自动恢复发行版更新任务；见 [修复与回归记录](windows-install-entry-2026-10-04.md)。

各平台更新弹窗统一保留“去网页下载”和“游戏内更新”两个操作按钮，右上角可关闭弹窗。Windows、Android 支持游戏内下载、校验和安装；macOS 保留网页安装方式，其“游戏内更新”按钮不可用并显示原因，不启动替换脚本。

应用更新独立于策略运行时，不修改 CABT 公共观察或 `agent(raw_observation) -> list[int]`，不增加玩家端 Python 依赖。

2026-09-19 用户确认采用本方案，已作为主工程默认更新机制接入。正式游戏使用 `AppUpdater` autoload、首页检查更新入口及 Android 原生插件；“升级验证”只是独立验收工具，不是运行依赖。完整游戏导出验收见 [主工程接入记录](game-integration.md)。

## 玩家体验与异常恢复

- 正式导出游戏保留首页自动检查、手动检查与缓存提示。不再提供“忽略此版本”，旧的忽略记录也不会屏蔽更新提醒。从 Godot 工程启动的开发版不自动检查、下载或恢复发行版安装任务，手动检查仅提供网页下载，并说明重启工程不能安装发行包。
- Android arm64 遇到旧版 v1 公告时，直接从既有固定地址 `https://ptcg.skillserver.cn/dist/downloads/ptcgdeckagent-android.apk` 下载，无需修改服务端清单。下载大小取自系统下载进度；后台导入时检查实际 APK 包名、签名证书与公告版本，要求构建号递增，再生成本地 SHA-256 与真实构建号。游戏重新校验文件后才允许安装；Android 系统负责最终 APK 签名完整性验证与安装确认。下载任务标识与文件摘要分开，不能把任务标识当成服务端校验值。
- “游戏内更新”按钮在下载时复用为“取消下载”，校验完成后为“安装更新”，Android 等待系统安装时为“取消安装”；不增加第三个操作按钮。不支持的平台或缺少有效更新包时保留该按钮并禁用，玩家仍可去网页下载。
- 下载弹窗显示大小、进度、速度和预计时间。首页同时只显示一个入口：有更新时显示顶部更新/进度按钮，否则显示检查更新图标。没有全局底部浮层；详情弹窗归首页所有，离开首页时随场景销毁。后台下载继续，回到首页恢复入口，不覆盖对战手牌。
- Android 由系统 DownloadManager 下载，通知栏显示进度；切后台或游戏进程退出后继续，再打开接回同一任务。完成/失败通知返回游戏，不直接打开 APK。通知关闭时仍可在游戏内查看进度。
- v2 清单的包大小和 SHA-256 匹配才允许安装；固定 Android 地址模式使用已检查 APK 的本地大小与摘要防止后续文件变化。安装前再次校验。Android 的系统半包由系统恢复，完整包导入应用私有目录后重新校验；Windows 未完成的半包重开后清理并提示重新下载。
- Android 断网后由系统等待、重试，服务器支持 Range/ETag 时可续传；不可恢复的任务允许重新下载。Windows 使用 60 秒无进展超时和完整重下。404、写入失败、空间不足及半包均不能获得安装资格。
- Android 包无法解析、包名/签名/版本不匹配、设备不兼容时，取消安装资格并提供重新下载/官网入口；权限拒绝、系统取消、空间不足允许保留完整包后重试。
- Android 的系统确认由已恢复前台的游戏 Activity 打开；下载/安装准备期间切到后台时只排队，返回游戏后再打开，不从 BroadcastReceiver 强行拉起页面。系统 `STATUS_FAILURE_ABORTED` 不再等同玩家主动取消；安全校验失败单独说明。
- 会话被系统中止、确认页打不开或安装准备超时后，原“安装更新”按钮变为“使用系统安装器”。玩家再次点击才改走 APK URI 安装，复用已下载文件并重新核对摘要、大小、包名、签名和递增构建号。仅向安装器授予本次随机令牌对应的单个 APK 的只读权限；私有目录不对外共享，取消或重试会撤销旧令牌。系统权限、签名检查和安装确认保持生效。
- Android 安装准备超过两分钟会撤销会话；安装确认/权限页面可返回游戏，也可明确取消本次安装。取消、进程重建后的旧回调不能继续推动新任务。
- Windows 帮助程序先准备，得到首页的最后授权并等待游戏退出后替换；进入新版首页才确认成功，否则尝试恢复旧版。启动读取待更新记录后先关闭文件句柄，再清理已安装版本的记录与包，避免 Windows 占用导致删除失败；成功状态不再保留待安装入口。
- 始终保留“去网页下载”，并在更新弹窗按钮上方常驻提示：如果游戏内安装不成功，请点击“去网页下载”，下载并手动安装最新版。覆盖安装不清空本地数据，不引导玩家卸载正式 Android 游戏。

## 无需改服务器的 Android 验证版

见 [Android 验证说明](android-validation.md)。它是单独包名的“升级验证”，复用当前正式下载、校验、弹窗和 Android 安装插件，内置 B 版完整 APK、真实本机 HTTP 故障服务和测试入口。无需上传安装包或修改线上清单。另附局域网服务，支持用手机实际断 Wi-Fi 验证。

这验证的是更新组件，不是完整游戏的正式发行包。正式签名升级仍须在实际分发渠道和设备验收。

## 版本清单与发布

读取 `https://ptcg.skillserver.cn/dist/updates/latest.json`，兼容 v1。schema v2 支持：

| 平台 | 清单与安装方式 |
| --- | --- |
| windows | `version` + `artifacts`，格式 `windows_zip`；ZIP 根目录 EXE，包含需要的 DLL/PCK；安装目录可写 |
| android | `version` + `artifacts`，格式 `android_apk`；同包名/同签名、递增 `versionCode` 的完整 APK；`build` 必须对应真实 APK |
| macos | 仅 `version`，游戏按钮打开官网，不下发自动安装 artifacts |
| web | 仅独立 `version`，保留网页渠道 |

artifact 包含 `arch`、`format`、`entry`、`url`、`size`、`sha256`，Android 额外包含 `build`。初始下载 URL 固定官方 HTTPS 源；Windows 不跟随跳转，Android 的跳转与网络重试遵循系统下载管理器，最终仍须通过大小、SHA-256、包名、签名和 build 校验。SHA-256 从签名后的最终文件计算。包最大 2 GiB；Windows 解压最多 4 GiB / 20,000 条目，拒绝越界、链接、重名等。

当前正式 Android 包名 `com.example.ptcgdeckagent`，导出架构 arm64，不能更改已有签名或包名来实现覆盖升级。验证包名 `cn.skillserver.ptcg.updatelab`，单独安装，禁止把它作为正式升级包发布。

```powershell
# 重建 Java 插件，开发工具路径可通过参数指定。
./native/app_updater/build.ps1 -JavaHome 'C:/path/to/jdk-17'
# 使用 Godot 编辑器“安装 Android 构建模板”后导出正常游戏。
godot --headless --path . --export-release Android 'C:/release/game-arm64.apk' --quit
# 从真实的最终文件生成清单，不上传；输出文件必须不存在。
python tools/build_app_update_manifest.py --spec C:/release/release-spec.json --output C:/release/latest.json
# 独立构建验证 A/B 包，输出到本地 output/android-update-lab。
python tools/build_android_update_lab.py
```

配置示例：[release-spec.example.json](release-spec.example.json)。发布负责人先上传不可变版本包，再替换清单；未接入更新组件的旧版本需要先安装一次引导版本。此任务没有上传、发布或改动线上服务。

SHA-256 是完整性校验，清单真实性依赖固定 HTTPS 和系统 TLS；Android 另验证原生签名。Windows 当前未配置 Authenticode，清单也未实现独立数字签名，不能宣称独立发布者认证。

Android 安装使用系统 [PackageInstaller](https://developer.android.com/reference/android/content/pm/PackageInstaller)，不是绕过用户确认的静默安装。官网 APK 渠道与 Google Play In-App Updates 分开，本实现面向官网分发。

已经装在手机上的旧更新器不能靠下载新 APK 自动替换自身的安装逻辑。若旧版反复中止，先从官网或受信的修复包入口下载 APK，在文件管理器中打开并覆盖安装；保留原应用和数据，不先卸载。修复代码要随下一次 APK 安装后才生效。

## 验证、证据与回退

此前验证记录：[第一阶段记录](verification-2026-09-19.md)；后续范围变化和 Android 实际验证：[Android 验证说明](android-validation.md)。第一阶段的 macOS 安装方案已经撤回，历史记录不代表当前能力。

Windows 保留 `user://app_updates/<token>/backup` 和 `journal.json` 供恢复；本版不自动删除历史备份。启动健康检查只证明进入首页，不证明全部功能正常；断电或磁盘损坏仍可能需要手动恢复。

发布回退可以撤回清单中的故障包，但不等于立即撤销离线已下载的包。代码回退只撤掉本更新组件、autoload、插件及首页接入，保留原检查更新和官网入口，不重置整个工作树。正常 Android 安装失败由系统保留原版，勿为恢复而卸载正式游戏。
