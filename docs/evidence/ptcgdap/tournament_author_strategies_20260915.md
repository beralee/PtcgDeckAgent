# 比赛模式接入开发者策略 — 2026-09-15

## 实现

比赛设置新增 HUD 对手选择：内置、混合、开发者。本机存在可运行的策略时默认混合；混合名单约一半为开发者对手，开发者模式全部使用本机策略。沿用原有赛制：标准赛筛选 18.0 起的内置卡组，开放赛允许全部内置卡组；开发者包不通过包版本推断卡组年代，使用其通过本机执行门禁及卡组物化校验的卡组。界面明确区分这两种筛选规则。

`TournamentAuthorStrategyPool` 复用现有目录、设备执行门禁和卡组物化服务，只接纳当前设备可运行的完整包。SwissTournament 保存每位开发者选手的 package_id、package_version、archive_sha256、install_source 和展示快照，不保存句柄、策略对象或旧选择窗口。卡组分布按完整包身份区分，不再把所有 ID 为 0 的开发者卡组合并。

GameManager 在每轮开局重新校验精确包，选择 VS_AUTHOR_STRATEGY_AI，由现有本机作者策略 owner 执行；切回内置对手清除作者选择，强 AI 固定起手与 LLM 选择维持原流程。混合名单保留已启用 LLM 对手的至少一个名额。

包缺失、损坏、关闭功能或设备不兼容时不切换到别的 AI。预检失败保留配对和存档，在总览/成绩页显示可重试错误。若预检后、场景初始化时再次校验失败，也撤销“对局已开始”标记并返回赛事页，不误记技术负。真正开始后的退出仍沿用技术负规则。

比赛设置增加外层滚动，手机使用已有触控拖动桥；窄屏调整对手按钮列数。总览显示“开发者”类型及带版本的卡组名。

## 验证

Godot 4.6.1，Windows x86_64，本地隔离 APPDATA。所有调用使用 `scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript <下列脚本>`。没有修改玩家实际存档或发布安装包。

45 个独立测试最终通过（日志位于 `.godot_test_user/logs/`）：

| 脚本/范围 | 通过 | 日志 |
| --- | ---: | --- |
| tests/test_swiss_tournament.gd | 7 | focused-20260915-005222.log |
| tests/test_tournament_mode.gd | 18 | focused-20260915-005224.log |
| tests/test_non_battle_portrait_layout.gd，filter=test_tournament | 9 | focused-20260915-005247.log |
| tests/test_tournament_author_runtime.gd，前四项 | 4 | focused-20260915-004834.log |
| 同脚本，filter=test_recovery | 2 | focused-20260915-005032.log |
| tests/test_tournament_author_strategies.gd，filter=test_author_ | 2 | focused-20260915-005539.log |
| 同脚本，test_mixed_field_and_all_rounds_preserve_author_identity | 1 | focused-20260915-005305.log |
| tests/test_tournament_author_layout.gd | 1 | focused-20260915-005637.log |
| tests/ai/ptcgdap/test_platform_player_matches.gd | 1 | focused-20260915-005647.log |

大规模赛程测试覆盖 16、32、64、128、256、512、1024、2048 人，每一轮配对、结算、恢复存档，检查所有选手的结果数和作者身份。005305 的另一项曾因测试直接比较 JSON 数值类型失败；随后改为逐选手比较精确引用和卡组名，005539 已通过。缺失功能的初始红灯见 003959；混合名单遗漏 LLM 的红灯见 005519，修复后 005539 在 64 个种子下通过。

真实比赛验证：当前本机包为玛俐的礼盒 5.21.0，16 人开发者赛事，玩家侧由规则 AI 代打，作者侧使用正式 worker_v1 owner 和 HeadlessMatchBridge。不是仅注入胜负的比赛模拟；四场均由 GameStateMachine 到达终局，再经过 GameManager 结算和磁盘恢复。

| 轮次 | 种子 | 引擎推进步数 | 作者成功决策 | 胜方座位 |
| --- | ---: | ---: | ---: | ---: |
| 1 | 93200 | 61 | 31 | 0 |
| 2 | 93201 | 117 | 67 | 1 |
| 3 | 93202 | 52 | 26 | 0 |
| 4 | 93203 | 111 | 72 | 1 |

四轮共 196 次作者成功决策；策略错误、引擎拒绝、非法输出、同窗口异常回退均为 0。另有规则包与模型包分别在双方座位运行的 4 场真实对局，全部终局且没有上述错误、worker 启动失败或陈旧结果。模型包两局发生 48 和 16 次成功推理；正常的强制选择/无模型适用项旁路保留在原有诊断中。

UI 测试在真实 Godot 场景的 1600×900、900×1800、390×844 视口验证按钮在滚动后可见，且手机 ScreenTouch/ScreenDrag 能实际滚动表单。使用触控测试配置模拟 Android 输入，未声称在 Android 真机或新 APK 上验收。

真实渲染截图保存在本机临时产物：`tmp/tournament-author-1600.png`、`tmp/tournament-author-390-OpponentSourceGroup.png`、`tmp/tournament-author-390-BtnStart.png`，已人工检查 HUD 选中态、中文显示及滚动后开始按钮的可达性。

## 边界与回滚

玩家所在桌真实执行作者策略；其他桌继续沿用原有后台胜负模拟。涉及作者的后台桌在缺少可信实力标定时使用中性 50% 概率，避免把作者策略误当作必败的弱 AI。这不是完整赛事所有桌的策略对战评测，也不代表胜率或 Kaggle 引擎对齐提升。

不改变作者的公开观察、合法 select.option、窗口重绑定、策略权限或本机执行边界；没有引入网络推理和外部 Python 运行时。

运行时可选择“内置”停用新增对手来源。代码回滚仅撤销本次 tournament 文件、GameManager 的赛事接入与错误恢复、BattleSceneSetupEffectAiRuntime 的四个启动失败回调，以及新增 pool 和测试；保留本任务前已存在的其他改动及策略中心工作。已经锁定开发者包的赛事应在当前版本完成或主动结束后再回滚。
