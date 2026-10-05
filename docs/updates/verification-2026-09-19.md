# 游戏内更新验证记录 — 2026-09-19

> 第一阶段历史记录。随后按用户要求撤回了 macOS 自动安装，并加入 Android 独立验证包和实际模拟器验收。当前能力以 [Android 验证说明](android-validation.md) 和 [更新说明](README.md) 为准，下面的 macOS 脚本命令不再适用于当前代码。

验证主机为 Windows，Godot 4.6.1。范围是公共客户端与安装组件；不涉及私有云、正式签名密钥、发布操作或 `ptcgabc`。

## 已完成

| 验证 | 结果 | 覆盖内容 |
| --- | --- | --- |
| `test_app_update_manifest.gd` | 5/5 | 平台版本/架构、旧清单兼容、不安全元数据、真实 JSON 数字类型 |
| `test_app_updater.gd` | 9/9 | 完整性门槛、损坏包重试、取消/迟到回调、防重复请求、对局中禁止安装、落盘后重开恢复、超时撤销、进度版本一致 |
| `test_update_checker.gd` | 21/21 | 原有缓存/手动检查/忽略回归；相同版本从 v1 缓存升级到新安装元数据而不重复提醒 |
| `test_export_presets.gd` | 24/24 | 原有多平台版本、导出过滤和 Web 发布配置回归 |
| Python 清单生成测试 | 4/4 | 最终文件摘要、归档越界/重名、来源/架构拒绝、独立 Web 版本 |
| Windows 实际进程安装测试 | 6/6 | 替换并启动、启动失败恢复、越界包拒绝、错误哈希拒绝、取消准备、无授权异常退出；所有场景保留玩家数据哨兵 |
| UI 实际渲染 | 8/8 | 1280×720 与 390×844 的可下载/下载中/待安装/失败状态；按钮无越界，人工看图检查 |
| Windows 完整导出 | 通过 | 更新脚本随 EXE/PCK 打包；真实导出游戏进入首页后写入版本 `0.6.0` 健康回执 |
| Android 组件及完整 APK | 通过 | Java 插件编译、Godot Gradle 导出；APK v2 签名校验；更新权限、插件注册、非导出接收器、arm64 ABI 入包 |
| macOS 安装脚本 | 语法检查通过 | Git Bash `bash -n`；尚未在 macOS 执行 |

总计 59 项 Godot 检查、4 项清单生成测试、6 项 Windows 安装场景通过。UI 验证另列，不把截图检查当作系统安装测试。

开发先得到缺失 manifest owner 的失败测试；之后又通过测试复现并修复准备超时未撤销安装权限、新提示版本覆盖正在下载版本，以及 JSON 中 `schema_version` 被解析为 float 导致 v2 清单被误拒的问题。原更新检查测试的 Web 版本断言从过时的 `0.6.0/600` 同步为当前代码已有的 `0.6.0.2/602`，没有借此修改实际应用版本。

## 复现

```powershell
./scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_app_update_manifest.gd
./scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_app_updater.gd
./scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_update_checker.gd
./scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_export_presets.gd
python -m unittest tests.test_app_update_manifest_builder -v
./tests/test_app_update_windows.ps1
./tests/test_app_update_export_health.ps1 -Executable C:/test-export/game.exe -ExpectedVersion 0.6.0
godot --path . --script res://tests/run_app_update_ui_capture.gd
bash -n scripts/update/install_macos.sh
```

Windows 安装测试只启动并修改 `.tmp/app-updater-windows-<随机值>` 中的微型测试程序，使用 Windows PowerShell 5.1 运行真正的帮助程序；启动健康回执另用完整导出游戏验证。测试没有更换开发者正在使用的游戏文件。

构建 APK 为调试签名，版本仍为 `0.6.0 / 60`，不是提供给现有正式用户的升级包。首次 Gradle wrapper 下载超时后，从官方分发地址取得并按官方 SHA-256 校验 Gradle 8.11.1，随后完成完整构建。早期 console wrapper 在完成导出后未自动结束，只终止了本任务已完成的 wrapper；最终使用直接 Godot 进程的退出码与包内容作为构建证据。

完整导出文件和开发过程日志保留在本地 `.tmp/game-updater-20260919/`；可审阅的最终测试日志、截图和摘要保存在 [`evidence/`](evidence/)。二进制测试包不纳入源码交付。

## 尚未完成的门槛

- Android 没有连接真机：尚无正式同签名包覆盖升级、系统权限和确认页、取消/恢复、数据保留的实机证据。
- 无 macOS 主机：没有签名/公证应用的真实替换、重启和回退证据；当前 ad-hoc 导出不满足实现要求的签名门槛。
- Windows 安装器测试已验证文件事务和重启；仍需发布包在普通用户目录、中文/空格路径、权限/低空间等发行环境验证。启动回执只证明进入首页，不证明新版全部功能正常。
- 无线上发布：公开 feed 仍为 v1，不含本次所需 artifacts。更新引导版本、三平台正式包和 schema v2 清单需要按发布流程推广后才对玩家生效。

这些未通过的发布门槛不能用单元测试、APK 编译或脚本语法检查替代。保留重新下载安装入口、桌面备份与安装日志用于失败恢复；详细发布及回退流程见 [`README.md`](README.md)。
