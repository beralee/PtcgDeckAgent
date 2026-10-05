# Android 卡牌更新入口与正式导出验收

## 问题与修复

玩家提供的 v0.6.2 首页没有「卡牌更新」。拆检本地分发目录 `../ptcgdojopage/downloads/ptcgdeckagent-android.apk`：CardContentBootstrap / CardContentUpdater 均未注册，`scripts/card_content/` 资源也不存在。该正式包为 2026-09-29 的构建，先前安卓增量测试使用独立 lab APK，因此不能以 lab 通过证明正式包已有入口，也不能仅由相同版本号或桌面进程年龄判断手机安装内容。

本轮补齐三处：

- 正式 APK / EXE 检查器 `tools/inspect_app_update_export.py` 检查内容更新的两个 autoload、六个脚本、公钥、冻结类清单及运行时类索引闭合。既有正式导出脚本已调用该检查器，缺模块的包会被拒绝。
- `MainMenu.gd` 的入口采用现有手机布局字号、触摸尺寸与主题，并在竖屏状态栏下方靠右放置；不再使用缩放后很小的桌面默认按钮。没有新内容时仍显示入口。内容面板使用统一模态层级，避免首页 NEW 徽标盖到弹窗上。
- 为 `artifacts/` 增加 `.gdignore` 并允许 Git 跟踪；完整运行时验收脚本在任何源码复制前先写输出目录的 `.gdignore`。Git ignore 和导出 exclude 都不能替代 Godot 扫描隔离。

## 实装发现的类索引污染

第一次重新导出的完整包文件检查通过，但实装启动失败：Godot 全局类缓存中 623 条记录被重定向到 `artifacts/card_content/full-runtime-workflows-20261001/source/` 下的测试副本；这些路径又被排除在 APK 外，导致真实 CardDatabase / GameManager 解析失败。

该失败包保留在 `.tmp/ptcgdap_device_release/card-content-entry-20261001/`，不作为交付包。失败日志、污染前类缓存和新增门禁拒绝结果位于 `artifacts/card_content/android-entry-20261001/`。修复隔离后重新导入，污染引用归零；重新导出的完整包能够启动。检查器允许 Godot 保留被排除的 test-only 类声明，但生产运行时声明必须能在产物中解析，且禁止指向 artifacts/output/tmp 测试目录。

## 测试

- Python 导出门禁：9 项、19 子项通过，覆盖旧包缺模块、缺文件/注册、无效元数据、被排除的运行时副本以及 Godot test-only 类缓存行为。
- Godot 入口、更新、首页状态栏：14/14 通过。手机按钮尺寸及模态遮挡分别先失败、再修复通过。最终报告 `.godot_test_user/matrix/20261001-222708-954d55/report.json`。
- 隔离后的完整游戏增量验证：新卡、共享效果修复三阶段通过，报告 `artifacts/card_content/full-runtime-isolated-20261001/report.json`，输出目录已有隔离标记，父项目类缓存无 artifacts 引用。
- 扩展非战斗布局套件为 66/67；失败项 `test_battle_setup_landscape_ai_mode_stays_inside_screen_after_switch`，断言对战设置内容列高度超过 900。该测试只实例化 BattleSetup，本轮没有修改该页面，不把这项未解决失败写成全量通过。报告 `.godot_test_user/matrix/20261001-222039-2ed7a0/report.json`。

复跑入口：

```powershell
python -m pytest tests/test_card_content_export.py -q
.\scripts\tools\run_godot_tests.ps1 -Runner all -Suite 'CardContentEntry,CardContent,MainMenuStatusHeader' -UserDataRoot .godot_test_user/card_content_entry_check
python tools/inspect_app_update_export.py <正式APK> --require-release --output <报告JSON>
```

## 本地交付与边界

交付包：`output/card-content-entry-20261001/PtcgDeckAgent-0.6.2-card-content-fixed.apk`。版本仍为 0.6.2 / build 62，用于本地手动覆盖安装，不冒充新的线上版本；包名仍为 `com.example.ptcgdeckagent`，签名证书 SHA-256 为 `301f30c5221085b11ced3e187d79700be42eeabecc5bb49220d0ba342ab5f37d`，与旧正式包一致。

最终包的摘要、产物检查和安卓点击证据统一记录在 `artifacts/card_content/android-entry-20261001/report.json`。安卓环境为 Android 16 / x86_64 模拟器，通过 ARM64 转译运行正式 ARM64 APK；不能替代品牌 ARM 真机验收。完整 APK 在保留应用数据的覆盖安装路径上启动，首页入口与面板通过实际触摸检查；未卸载或清空应用数据。

本轮没有提交、推送、更新下载站、发布线上 APK、修改更新清单或部署 Control。内容服务尚未发布新卡包时面板显示“暂无新的卡牌内容”；入口可用不等于线上已有内容可下载。

## 回退

源码仅撤销本轮入口样式/尺寸、模态层级及导出检查的局部增量，不回滚整个脏工作区。保留测试目录的 `.gdignore` 隔离，避免恢复类污染。若需恢复既有安装，可用同签名旧正式 APK 手动覆盖，保留玩家数据；旧包没有内容更新功能。此次本地包没有改变线上渠道或内容版本指针。
