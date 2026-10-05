# 主工程更新方案接入 · 2026-09-19

用户确认采用已经验收的升级方案。主工程默认启用这套更新组件，后续从正常导出配置构建的游戏直接包含它，不需要安装验证应用或开启测试选项。

- Android：系统下载管理器、通知栏进度、游戏进程退出后继续、重开接回任务、完成后校验和用户确认安装。游戏内常驻进度入口和重新下载安装兜底保留。
- Windows：游戏内下载、校验、安装重启及启动失败回退；更新助手随正式包打包。
- macOS：继续前往官网下载，不打包或执行旧的 macOS 自动安装脚本。

`project.godot` 的正式 `AppUpdater` autoload、主菜单检查更新、Android Gradle 构建与插件注册已接通。APK 中不包含实验页面、故障服务或内置的第二个测试 APK；局域网 HTTP 特例只对独立调试验证包生效。

## 完整游戏构建验收

在本工作树导出完整游戏，沿用既有包名、版本 `0.6.0 / 60` 及已配置的签名。没有发布、上传或修改线上版本清单。

| 检查 | 结果 |
| --- | --- |
| 正常导出配置回归 | 24/24，通过 |
| Android release 完整 APK | 导出成功；非 debuggable；APK v2 签名校验通过 |
| Android 包内组件 | autoload、进度 UI、原生下载/安装方法、权限、系统通知接收器完整；实验资源排除 |
| Windows release 完整游戏 | EXE、ONNX Runtime 和原生扩展 DLL 导出成功；更新 UI 和安装助手入包 |
| Windows 首页启动 | 实际导出 EXE 进入首页并写入更新健康回执；错误输出为空 |
| 防止误打包 | 旧 Android、旧 Windows、独立实验 APK 均被新的包内检查拒绝 |

证据：[Android 包内检查](evidence/game-integration/android.json)、[Windows 包内检查](evidence/game-integration/windows.json)、[APK 签名](evidence/game-integration/android-signature.txt)、[Windows 启动](evidence/game-integration/windows-home-health.txt)、[导出配置](evidence/game-integration/export-config-tests.txt)。后台、断网、错误包和实际覆盖升级的组件验收见 [Android 系统下载验收](android-background.md)。本次完整正式工程包未进行额外真机覆盖安装，不将实验包验收扩大为所有厂商手机验收。

## 后续构建和发布

`scripts/tools/export_ptcgdap_device_release.ps1` 现在会调用 `tools/inspect_app_update_export.py`，在 Android 和 Windows 导出后检查包内更新组件，缺项会中断构建。Android release 额外拒绝 debuggable 包；检查只读取产物，不安装、签名或发布。Windows 检查读取 EXE 内嵌 PCK，不会回落到源码目录来冒充打包成功。

下一次正式发版仍按 [更新说明](README.md) 生成 v2 清单，提供实际 APK/Windows ZIP 的大小和 SHA-256；Android `build` 必须递增并保持原包名与签名。Windows ZIP 根目录包含 EXE 与对应 DLL。macOS 仍只提供版本和官网下载入口。

本地完整包在 `.tmp/update-game-integration-20260919/android/` 与 `windows/`。这次接入没有为发布修改版本号。若回退，只撤销对应更新组件和导出检查，保留原版本检查与官网入口，不重置用户数据或其他工作树修改。

本次只完成应用更新与打包接入，不涉及策略决策接口、跨运行时一致性或引擎对齐等级变化。
