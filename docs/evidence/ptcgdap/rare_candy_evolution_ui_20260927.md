# 神奇糖果：复用能量转移的场上交互

2026-09-27，Godot 4.6.1，当前公开工作区。按玩家反馈，用直观交互替代先前文字过多的组合列表。

## 问题与责任层

`EffectRareCandy` 已提供合法的 `{kind: evolve, card, target_slot}` 成组选项。
最早的对话框无法展示该结构的卡图，同名、不同属性的进化卡因此无法区分。
第一版修复把每个合法组合展示成带多行说明的卡片；玩家反馈文字和重复选项过多。
最终方案在 `BattleEffectInteractionController` 和 `BattleInteractionController` 的展示层，
把这一合法列表映射为能量转移使用的“源卡牌 → 场上目标”操作。

## 最终行为

1. 每张实际进化卡只出现一次，显示卡图、清晰的属性标签和简短卡号。属性来自
   宝可梦的 `energy_type`，不从招式费用推断；长按 / 右键打开对应实体的详情。
2. 点选进化卡后收起大面板，只高亮该卡合法的场上目标。直接点战斗场或备战区
   的宝可梦，不再从重复的目标名称列表中判断位置。
3. 选中的目标显示金色边框。确认栏只显示卡名、属性和目标位置；点击“确认进化”
   才消耗糖果。“重选”恢复选牌，“取消”保留手牌和场上状态。
4. 短横屏保留选牌最小尺寸，竖屏的三条短标签随卡片宽度缩放。目标选择阶段
   面板不遮挡己方战斗宝可梦或备战目标。旧版多行卡片、专用详情按钮和弹窗
   高度分支已移除。

## 选择与结算边界

- 仍只有一个原始 EVOLVE 窗口，原始合法选项及其顺序不变。中途选卡、选目标
  仅为 UI 状态，不提前执行卡效，也不新增引擎交互步骤。
- 源卡和目标按实例去重；禁止原列表中不存在的组合，不能把多个进化路线做成
  无条件的笛卡尔积。
- 确认时核对 generation、步骤编号和步骤 ID，然后用卡牌实例与目标实例在
  当前列表中查找选项，再通过原标准选择入口提交一个索引。
- 旧窗口的确认、非法组合均拒绝并重新展示当前选项。卡效、UCIS 编译、作者 Host、
  公共策略输入、AI 和单窗口权威边界未改变。

## 验证

实际卡数据：`CSVH1C/045` 神奇糖果、`CSV2C/028` 呱呱泡蛙、
`CSV7C/123` 斗属性甲贺忍蛙 ex、`30thC/015` 水属性甲贺忍蛙 ex、
`30thC/125` 同属性异画。没有修改卡牌规则或数据。

修改前的新交互回归 0/7，通过旧版 UI 真实复现失败：
`.godot_test_user/rare_candy_field_red/report.json`。
专项覆盖两张进化牌 × 三个目标、源卡不重复、先收起后点场上、确认结算、重选、
手牌重排、三个阶段取消、同属性异画、缺图、非法跨路线组合和过期确认。
真实 `BattleScene` 还验证详情入口、属性标签、横竖屏边界、不遮挡目标、实际
场上鼠标按下/释放入口与确认按钮可见性。

小屏边界检查发现最小手牌尺寸会导致属性标记超出卡片，失败证据：
`.godot_test_user/rare_candy_field_regression_final/report.json`（358/359）。
该问题由进化源卡最小尺寸修正，最终验收见：
`.godot_test_user/rare_candy_field_acceptance/report.json`，**359/359 通过，0 失败、0 跳过**。

| 套件 | 通过 |
| --- | ---: |
| BattleEvolutionChoices | 8 |
| BattleDialogController | 32 |
| BattlePortraitLayout | 107 |
| BattleUIFeaturesPart2 | 92 |
| BattleUIFeaturesPart3 | 84 |
| EffectInteractionFlow | 27 |
| UcisInteractionCompiler | 9 |

Windows OpenGL 实画检查分为选牌、目标高亮、确认三个阶段。最新截图和真实
渲染测试结果保存在 `.godot_test_user/rare_candy_field_visual_acceptance/`，8/8 通过；
日志无脚本错误，选牌与确认截图已逐项查看。
请求布局为 1600×900、900×1600、390×844、844×390；桌面产品窗口策略会调整
原生窗口尺寸，因此截图名表示请求尺寸，不代表对应手机物理设备验收。
本次达成玩家 UI 与现有本地单窗口结算链路的验证；未声明新增 Android 真机、
发布包或官方 CABT 引擎一致性验收。

复现命令：

```powershell
python scripts/tools/run_test_matrix.py --suite-script res://tests/test_battle_evolution_choices.gd
.\scripts\tools\run_godot_tests.ps1 -Runner all -Suite 'BattleEvolutionChoices,BattleDialogController,BattlePortraitLayout,BattleUIFeaturesPart2,BattleUIFeaturesPart3,EffectInteractionFlow,UcisInteractionCompiler'
```

## 回滚

移除 `BattleEvolutionChoicePresenter.gd`，并移除 `BattleEffectInteractionController`
中的 EVOLVE 展示路由与配对提交方法、`BattleInteractionController` 中本次增加
的进化展示分支；同步回退新专项套件和 Part3 的 UI 模式断言。
先前版本对通用对话框、文字缩放器和场景弹窗尺寸的改动已清理，不需要保留。
工作区存在其他任务改动，不应整文件回退。没有修改外部 oracle、私有服务、
牌组或种子版本；未提交、推送或发布。

## 3D 鼠标点击跟进修复

用户反馈进化选择框中的卡牌在 3D 模式下鼠标点击无反应。之前的 2D 测试直接
触发源卡选择信号，没有覆盖完整鼠标输入分发，因此不能用于证明 3D 可操作。

新增回归在真实 3D 场景中留下一个未收到释放事件的手牌滚动手势，再打开
神奇糖果选择框。旧实现会把新鼠标点击继续交给手牌滚动区域，源卡选择索引
保持 `-1`，弹窗不收起。失败证据为
`.godot_test_user/rare_candy_3d_scroll_red/0001-BattleEvolutionChoices/result.json`
中的 `test_3d_evolution_releases_previous_hand_gesture`。
这是可复现的输入交接缺陷；没有宣称从历史日志确定用户每一次卡住的完整手势。

第一处修复在 `BattleInteractionController.show_field_assignment_interaction` 打开
新选择框时释放旧手牌拖动及点击抑制状态，与既有卡牌对话框的处理一致。
只调整输入交接，不修改卡效、合法选项、实例配对、确认要求或 AI 策略。

快速确认回归继续发现第二处缺陷：旧 2D `_try_handle_portrait_bench_play_input`
在检查模式和棋盘范围之前消费防误触事件。3D 选完目标后，新的确认按钮点击
会被它错误吞掉，日志明确记录 `modal_slot_input_consumed`、
`source=portrait_bench_grid`。失败证据为
`.godot_test_user/rare_candy_3d_guard_trace/0001-BattleEvolutionChoices/console.log`。
`BattleScene` 现在只在 2D 模式调用这条旧棋盘输入路径；3D 使用现有 Arena 拾取。

新测试通过实际鼠标事件覆盖两条路径：

- 正常手牌点击 → 详情中的使用按钮 → 水属性进化卡 → 3D 备战目标 → 确认。
- 未收尾的手牌滚动 → 打开新选择框 → 首次点击斗属性进化卡 → 3D 目标 → 确认。

两条路径都核对目标的实际顶层卡、神奇糖果弃置和未选进化卡保留。
最终鼠标帮助函数使用 `Input.parse_input_event`；确认前显式保持旧棋盘保护期
有效，避免慢速渲染恰好等到保护期结束而掩盖问题。初期实画测试在保护期过后
可以通过，不能单凭该结果宣称快速连续点击已正确。

最终进化专项 headless 验证见 `.godot_test_user/rare_candy_3d_both_fixed/report.json`，
10/10 通过。Windows OpenGL 实画验证见
`.godot_test_user/rare_candy_3d_final_visual/result.json`，10/10 通过；截图覆盖两种
属性的源卡、目标高亮和确认三个阶段，实画日志没有脚本错误。

最终输入与展示集成回归为
`.godot_test_user/rare_candy_3d_input_acceptance/report.json`，**53/53 通过，0 失败、0 跳过**：

| 套件 | 通过 |
| --- | ---: |
| ArenaPresentationIntegration | 5 |
| BattleDragScrollCoordinator | 12 |
| BattleEvolutionChoices | 10 |
| BattleModalEndTurnInputIsolation | 6 |
| BattlePresentationIsolation | 20 |

旧 2D 及效果链路六个套件另有 349 项通过，见
`.godot_test_user/rare_candy_3d_acceptance/report.json`；该中间报告的两项 3D
快速确认失败由上述最终专项和集成结果替代，不把中间报告标作全通过。
headless 退出时仍可见 DummyTexture/ObjectDB 资源释放警告；实画验证未出现，
本次不将功能测试通过扩称为整个引擎资源生命周期零告警。

回滚本次 3D 修复时，只移除打开分配选择框时新增的
`_clear_hand_drag_click_suppression` 调用、`BattleScene` 的 2D 棋盘输入隔离覆盖
和对应两项 3D 回归；保留此前进化 UI。
已有游戏进程缓存脚本，需重启游戏后使用工作区修复。未发布新安装包。
