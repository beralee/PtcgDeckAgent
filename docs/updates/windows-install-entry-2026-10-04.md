# Windows 更新入口、安装清理与重复启动修复

## 当前行为（2026-10-05）

本记录取代 2026-10-04 的“双入口均可安装”和“按场景隐藏底部浮层”方案。用户复测发现仍有两个按钮、重启后提示持续存在，最终改为移除全局更新 UI，并修复 Windows 待更新记录清理。

- 首页同时只显示一个更新入口。有待更新任务时显示顶部按钮，否则保留检查更新图标；没有底部常驻按钮。
- 更新详情是首页子节点，离开首页时销毁。后台任务由 AppUpdater 继续管理，对战场景没有更新浮层，也不能由残留点击打开更新弹窗。
- 顶部按钮在 ready 状态直接提交安装，然后显示进度；弹窗安装按钮走同一状态机。安装前仍重新校验文件、确认首页与平台可用性、等待助手准备，再退出旧游戏、替换并启动新版。
- 已安装版本的待更新记录在启动时清理，状态恢复 idle。updated 状态也关闭首页提醒，不再把成功显示成待安装。
- 工程开发版不自动检查、下载、写入或恢复发行包任务。手动检查仍可去网页下载，并明确说明重启工程不会安装发行包。工程与导出游戏共用 user://，因此开发版保留已有包及记录，供真正的导出游戏使用。
- 更新弹窗继续常驻提示：“如果游戏内安装不成功，请点击‘去网页下载’，下载并手动安装最新版。”

## 已确认的原因

1. 顶部 MainMenu 与 AppUpdater 全局 CanvasLayer 分别拥有按钮；只修点击处理或增加隐藏条件，仍然留下两套 UI。现在 AppUpdateProgress 只提供进度格式化，不再创建节点。
2. 本机实际运行的是 Godot 工程开发版 0.6.3，用户目录保存了发行版 0.6.4 的下载记录。这种进程不能覆盖 Godot 编辑器 EXE，普通重启也不会安装 ZIP；过去却仍恢复“已就绪”提示。
3. `_restore_pending()` 在 FileAccess 仍打开 pending.json 时删除同一文件。Windows 拒绝删除，真实导出程序升级成功后仍留有待更新记录。现在读取后立即关闭句柄，再判断版本和清理；即使旧 artifact 已缺失或不再有效，也先清理已安装版本的记录。
4. 首页将 updated 也作为常驻更新状态。现在成功和空闲都清空提醒，并恢复手动检查入口。

## 验证证据

Windows / Godot 4.6.1，隔离用户目录；未用真实玩家目录执行覆盖安装测试。

- 入口与生命周期新增用例先失败，再修复通过。初始失败报告：`.tmp/update-single-entry-20261004/red/report.json`。
- `AppUpdateEntry,AppUpdateManifest,AppUpdater` 合计 **46/46** 通过。覆盖单一入口、第一次点击、重复点击、安装前重新校验及篡改拒绝、实际场景切换与弹窗释放、成功后隐藏、开发版重复启动、已安装版本记录清理等。报告：`.tmp/update-single-entry-20261004/final/report.json`。
- `UpdateChecker` 的首页回归 **7/7** 通过。报告：`.tmp/update-single-entry-20261004/menu-regression/report.json`。本次没有宣称运行完整 UpdateChecker 套件。
- 真实 Windows A→B 导出测试曾复现成功后 `pending:true`，报告：`.tmp/windows-update-export-47e7c9674b2740e58383a02bee3fff7b/`。修复文件句柄后，首页入口和详情安装两条路径 **2/2** 通过：旧进程正常退出、新 EXE/版本与健康回执匹配、待更新记录清除、玩家数据保留；再关闭新版并普通启动，均为 idle、无待更新记录及残留更新信息。使用含中文和空格的安装与用户目录。最终报告：`.tmp/windows-update-export-af532a1fe6244b7dad8d28cd5861e5de/results.json`。
- 用本机 pending 与检查缓存的副本启动真实 MainMenu 两次；未复制 316 MB 安装包，也未改真实缓存。两次均验证 idle、不自动检查、无全局 Control、只有一个入口、旧缓存不被工程修改。正常首页与模拟待更新截图在 `.tmp/update-single-entry-20261004/real-home/final-boot-{1,2}-*.png`，结构化结果在对应 JSON。测试等待场景预加载完成后退出，两次无错误日志。
- 经用户明确同意关闭当前对局，已关闭两份旧工程游戏并重新打开一份修复后的游戏。进程响应正常，启动日志无错误：`.tmp/update-single-entry-20261004/local-restart.log`。该操作不覆盖玩家安装包，不证明用户已经安装线上 0.6.4。
- 前一轮未变更的 Windows 助手还通过了成功、启动失败回退、路径穿越、摘要错误、取消准备、意外退出六种场景，历史报告：`.tmp/app-updater-windows-de39ba2c96994dedbc9856264de8d8d2/results.json`。本轮没有修改助手。

复现入口：

```powershell
python scripts/tools/run_test_matrix.py --suite AppUpdateEntry,AppUpdateManifest,AppUpdater
python scripts/tools/run_test_matrix.py --suite UpdateChecker --test-filter=main_menu
powershell -NoProfile -ExecutionPolicy Bypass -File tests/test_app_update_windows_export.ps1
```

导出测试使用最小首页与真实更新组件；真实主菜单另行验证。本次没有对完整正式游戏打包发行，没有上传、修改版本号或线上服务，也不涉及 Android 真机验收及 CABT/策略对齐等级变更。已有发行客户端需随后续正常导出安装才能获得这些代码修复。

## 回退

按本次差异逐项撤销，不整体重置文件或工作树：AppUpdater 的全局 UI 移除、开发版任务隔离、文件句柄释放与过期记录清理、首页所属弹窗；MainMenu 的单入口互斥、开发版自动检查限制、成功状态清理及先 offer 再同步缓存通知；AppUpdateInstaller 的开发版说明；对应测试。AppUpdateProgress 只保留格式化方法与上述 UI 移除是同一组改动，回退时一并处理。

保留先前已有的下载、Android 安装、Windows 助手及其他并行工作。网页失败提示可独立回退 AppUpdateDialog.refresh() 的文案追加。真实下载包、玩家数据和生产服务均未改动；不要通过删除玩家数据来回退或掩盖提示问题。
