# macOS 源码启动空白战场：2026-09-19

## 用户现象与根因

用户进入普通对战后，窗口只剩灰色场地占位框，无手牌和操作日志。实际进程为 `/Applications/Godot.app/Contents/MacOS/Godot --path /Users/bera/ai/code/ptcgdeckagent`，版本 `4.6.2.stable.official.71f334935`，是当前工作区的源码调试运行。

日志同时报告以下资源的 `.godot/imported` 缓存不存在：中文字体 `NotoSansSC-VF.ttf`、标题图、吉祥物贴图、`vstar2.png`。其中战斗代码预加载的资源缺失导致 `BattleSceneRuntime.gd` 无法解析，最终 `BattleScene.gd` 未挂载，Godot 仍显示 tscn 原始占位控件。

前一轮只在隔离快照中执行导入、导出和完整策略对局验收，没有修复共享源码工作区的导入状态。独立导出包验收不能证明 `Godot --path` 直接启动未导入的工作区也可用。此处补上该遗漏。

## 修复

- 新增 `scripts/tools/run_macos_game.py`，先对实际工作区完成 Godot 资源导入，再启动游戏；导入失败或日志存在引擎错误时停止，不启动残缺界面。
- 本机缺少两份可选 Mac 模型库时，在扩展目录生成 Git 忽略的 `.gdignore`，并从 `.godot/extension_list.cfg` 中只移除该扩展的旧缓存引用。否则旧缓存会在目录扫描前尝试加载缺失 dylib。
- 不修改跨平台扩展描述，不删除其他扩展缓存，不清空玩家数据。两份库都存在时，仅删除本工具生成的标记，保留用户自建的忽略文件。模型能力准入仍由原项目配置决定。
- 已对用户当前工作区重新导入，导入日志无错误。Python 只用于源码开发启动，导出的玩家 App 不依赖 Python。

从源码运行的固定入口：

```bash
python3 scripts/tools/run_macos_game.py
```

默认使用 `/Applications/Godot.app`；支持 `--godot` 指定其他官方 4.6.x 编辑器，`--import-only` 仅准备工作区。安装包导出仍固定使用 4.6.1 和已有导出工具。

## 回归方法

```bash
python3 -m unittest tests.test_macos_source_launcher tests.test_macos_export_tool -v
python3 scripts/tools/run_macos_battle_startup_acceptance.py \
  --output-root .tmp/macos-source-startup-new
```

自动回归重新导入实际工作区，并在单独的 project 设置中链接同一份源码和同一份 `.godot` 缓存；只有 `user://` 定向到隔离目录。这样既检查用户实际使用的导入结果，又不修改玩家卡组、偏好或对局记录。

两个场景均从真实主菜单进入普通对战准备：自己练牌、内置 AI。保持动画特效开启，通过控件信号与控件 `gui_input` 事件完成开局选择，等待动画/弹层退出后验证背景、手牌图片、操作日志及可用的结束回合按钮；AI 场景还等待真实内置 AI 完成其回合。没有注入自动玩家 owner，也没有直接修改 GameStateMachine 来推进游戏。

这些属于应用内 UI 自动回归，不声称是操作系统真实鼠标验收。此前策略下载/断网完整对局的验证继续由 `run_macos_rules_acceptance.py` 负责。

本轮普通对战的界面与回合检查通过，进程退出时仍观察到 ObjectDB/CanvasItem 保留以及内置 AI 的 `resources still in use at exit` 诊断。启动检查将这条明确发生在引擎退出时的资源诊断单列为 `teardown_errors`，保留完整日志并标记 `log_clean=false`；任何其他引擎错误、脚本错误和交互失败仍阻断。不能将本次结果称作整个引擎生命周期无错误；退出资源释放问题未在此补丁解决。

## 本机证据

根目录：`/Users/bera/ai/code/ptcgdeckagent/.tmp/macos-source-startup-20260919/`。

- `user-broken-game.log`：用户报错时保存的原始运行日志。
- `battle-parse-before.log`：修复前可复现缺失贴图、扩展库和 BattleScene 解析错误；退出码为 0 不能代替错误日志检查。
- `prepare.log`：本机重新导入的日志位置。
- `verified/`：普通练牌/AI 对战的最新验收报告、进程日志和渲染截图。
- 五项 Python 断言通过：缺库与旧缓存同时处理、仅移除自建标记、导入失败中止、导出快照隔离、引擎错误检测。

本次没有变更战斗规则或正式 App 内容；修复对象是当前源码工作区的资源准备流程。回滚代码时仅处理本次启动工具、测试及说明；本机生成的忽略标记可单独移除，不要删除整个玩家数据目录。
