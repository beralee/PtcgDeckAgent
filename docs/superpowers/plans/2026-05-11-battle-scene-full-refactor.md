# BattleScene 全量重构 TDD 执行计划

**日期:** 2026-05-11

**对应设计:** `docs/superpowers/specs/2026-05-11-battle-scene-full-refactor-design.md`

## 目标

按照全量重构设计，把 `scenes/battle/BattleScene.gd` 从 11211 行中心脚本逐步改造成场景入口和编排层。整个过程必须以测试驱动开发推进，保持现有战斗功能、横竖屏布局、AI、回放、奖赏、结算、特效、记录、复盘等行为正确。

最终交付标准：

- `BattleScene.gd` 降到 1800 行以下。
- 主要 UI 节点引用迁入 `BattleSceneRefs`。
- 主要运行态字段迁入明确的 `Battle*State`。
- 新增或迁移后的 controller 不再通过 `scene.get("_")`、`scene.set("_")`、`scene.call("_")` 反射访问 `BattleScene` 私有状态。
- 横屏、竖屏、AI、回放、奖赏、结算、effect interaction 的 focused 测试通过。
- 关键移动端和桌面手动 smoke 清单通过。

## 执行原则

### TDD 循环

每个迁移单元都按这个循环执行：

1. **RED:** 先写或扩展测试，锁定当前行为或目标接口。测试必须因为缺少新结构而失败，而不是因为场景加载错误失败。
2. **GREEN:** 做最小实现，让测试通过。允许短期保留 wrapper 和兼容 adapter。
3. **REFACTOR:** 移动代码、去掉重复、收紧接口，但不改变用户行为。
4. **REGRESSION:** 跑本阶段 gate 测试和相关 smoke。
5. **CHECKPOINT:** 记录行数、反射访问数、剩余 wrapper，决定是否进入下一阶段。

### 改动边界

- 一个提交只处理一个 phase 的一个子模块。
- 不在结构迁移提交里夹带战斗规则、卡牌效果、UI 设计调整或 AI 策略优化。
- 如果迁移时发现真实 bug，先加 failing regression test，再单独修。
- 旧 `BattleScene` wrapper 可以短期存在，但每个 phase 必须减少 wrapper 或反射访问数量。
- 新文件默认使用显式依赖注入：`context`、`refs`、`state`、必要 service。
- 新 controller 禁止直接持有完整 `BattleScene`。

### 基线纪律

开始 Phase 1 前必须先跑 Phase 0 基线。若存在与本次重构无关的已知失败，记录在计划执行日志中；如果失败会掩盖重构风险，先单独修复并提交。

当前需要特别留意的历史风险：

- `tests/test_game_manager.gd` 可能仍有 macOS 自动最大化的旧预期，需要与最新 macOS 大窗口策略对齐后再跑全量。
- 版本号相关测试可能仍有旧版本预期，重构前不要把这类失败误判为 BattleScene 回归。

## 总体阶段

| Phase | 主题 | 主要结果 |
| --- | --- | --- |
| 0 | 基线和保护网 | 明确当前测试状态，补齐高风险回归测试。 |
| 1 | Context、Refs、State 骨架 | 建立后续迁移落点，不改行为。 |
| 2 | Layout 迁移 | 横竖屏布局从 BattleScene 移出。 |
| 3 | Display 迁移 | 手牌、场地、HUD、pile、详情展示从 BattleScene 移出。 |
| 4 | Dialog and Prompt 迁移 | 拆掉大型弹窗和 `_handle_dialog_choice`。 |
| 5 | Interaction and Effect Flow 迁移 | 场上目标选择和效果交互拥有独立状态。 |
| 6 | Overlay、Prize、Handover、Match End 迁移 | 解决 overlay 混杂和双方同时拿奖流程。 |
| 7 | AI、Advice、Discussion 迁移 | AI 行动、AI 探讨、AI 建议、复盘服务拆分。 |
| 8 | Replay、Recording、Runtime Log 收口 | 回放和记录状态从 scene 解耦。 |
| 9 | 删除兼容层和静态审计 | 去掉反射访问，完成结构收口。 |

## 通用测试命令

优先使用项目现有测试脚本：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_script_load_regressions.gd
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_portrait_layout.gd
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_ui_features.gd
```

模块测试按需追加：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_layout_controller.gd
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_dialog_controller.gd
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_effect_interaction_controller.gd
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_replay_controller.gd
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_recording_controller.gd
```

若某 suite 尚不存在，先建立 focused 测试文件，再通过现有 runner 运行。

## Phase 0: 基线和保护网

### 目标

在正式移动代码前，先把最容易回退的行为固定住。

### 文件

- 修改或新增：`tests/test_battle_scene_refactor_baseline.gd`
- 修改或新增：`tests/test_battle_scene_architecture_audit.gd`
- 可能修改：`tests/test_game_manager.gd`
- 可能修改：版本号相关测试

### RED

- [ ] 新增 BattleScene 架构盘点测试或脚本，统计：
  - `BattleScene.gd` 行数。
  - 函数数量。
  - `@onready` 数量。
  - `scripts/ui/battle` 里的 `scene.get/set/call` 数量。
- [ ] 新增 macOS 大窗口进入战斗不缩小的回归测试。
- [ ] 新增竖屏 AI 探讨输入区和发送/清空按钮尺寸回归测试。
- [ ] 新增竖屏 draw reveal 抽 7 张不出屏测试。
- [ ] 新增双方同时拿奖流程测试，覆盖黑夜魔灵自爆这类双方奖赏事件。
- [ ] 新增 setup 交接时机测试：玩家 1 完成 setup 前不弹 “请将设备交给玩家2”。

预期：

- 新增测试中，已有行为已经修过的应该直接通过。
- 双方同时拿奖或架构审计测试可能失败，作为后续 phase 的驱动。

### GREEN

- [ ] 只修正会妨碍基线的测试预期错误。
- [ ] 不做 BattleScene 结构迁移。

### Gate

- [ ] `test_script_load_regressions.gd` 通过。
- [ ] `test_battle_portrait_layout.gd` 通过。
- [ ] `test_battle_ui_features.gd` 通过或记录明确无关失败。
- [ ] 新增 baseline 测试可以稳定运行。

### Checkpoint

记录：

- BattleScene 当前行数。
- controller 反射访问数量。
- 已知无关失败。
- 需要先修的真实功能 bug。

## Phase 1: Context、Refs、State 骨架

### 目标

先建立后续迁移的目标结构，让新代码有明确落点，同时不改变现有行为。

### 文件

新增：

- `scripts/ui/battle/BattleSceneContext.gd`
- `scripts/ui/battle/states/BattleLayoutState.gd`
- `scripts/ui/battle/states/BattleDialogState.gd`
- `scripts/ui/battle/states/BattleInteractionState.gd`
- `scripts/ui/battle/states/BattleReplayState.gd`
- `tests/test_battle_scene_context.gd`
- `tests/test_battle_scene_refs.gd`
- `tests/test_battle_state_objects.gd`

修改：

- `scenes/battle/BattleScene.gd`
- `scenes/battle/BattleSceneRefs.gd`

### RED

- [ ] `test_battle_scene_refs_bind_from_scene_exposes_core_regions`
  - 构造或加载 BattleScene。
  - 调用 `BattleSceneRefs.bind_from_scene(scene)`。
  - 断言 top bar、hand、dialog、review、replay、draw reveal、attack vfx 等核心节点引用存在。
- [ ] `test_battle_scene_context_holds_refs_gsm_view_player_and_states`
  - 构造 context。
  - 注入 refs/gsm/view player/state。
  - 断言字段可读、默认值正确。
- [ ] `test_battle_state_objects_reset_to_defaults`
  - 每个 state 有 `reset()`。
  - reset 后无旧 selection、pending choice、replay cursor。

预期：

- 新文件不存在导致测试失败。

### GREEN

- [ ] 扩展 `BattleSceneRefs.gd`，先只做节点查找和 grouped getter。
- [ ] 新增 `BattleSceneContext.gd`，只持有共享引用和 signal，不放复杂逻辑。
- [ ] 新增第一批 state，提供默认字段和 `reset()`。
- [ ] 在 `BattleScene._ready()` 中创建 refs/context/state。
- [ ] 旧字段暂时保留，并与 state 只做必要单向同步。

### REFACTOR

- [ ] 把新建对象初始化集中到 `_setup_battle_context()`。
- [ ] 不把旧 controller 改成直接依赖 context，除非是极小无风险切换。
- [ ] 不新增 `scene.get/set/call`。

### Gate

- [ ] Phase 0 baseline 通过。
- [ ] `test_battle_scene_context.gd` 通过。
- [ ] `test_battle_scene_refs.gd` 通过。
- [ ] `test_battle_state_objects.gd` 通过。

### Checkpoint

- `BattleScene.gd` 行数允许小幅增加。
- 新架构入口存在。
- 没有行为变更。

## Phase 2: Layout 迁移

### 目标

把横屏/竖屏布局细节从 `BattleScene.gd` 移入 layout view 和 layout presenter。

### 文件

新增：

- `scripts/ui/battle/layouts/BattleLayoutState.gd`，如果 Phase 1 未放在 layouts 下。
- `scripts/ui/battle/layouts/BattleHudLayoutPresenter.gd`
- `scripts/ui/battle/layouts/BattlePileHudLayoutPresenter.gd`
- `scripts/ui/battle/layouts/BattleStadiumLayoutPresenter.gd`
- `tests/test_battle_layout_extraction_contract.gd`

修改：

- `scenes/battle/BattleScene.gd`
- `scripts/ui/battle/layouts/BattleLayoutCoordinator.gd`
- `scripts/ui/battle/layouts/BattleLandscapeLayoutView.gd`
- `scripts/ui/battle/layouts/BattlePortraitLayoutView.gd`
- `scripts/ui/battle/BattleLayoutController.gd`
- `tests/test_battle_portrait_layout.gd`
- `tests/test_battle_layout_controller.gd`

### RED

- [ ] `test_layout_views_do_not_call_scene_layout_impl`
  - 扫描 layout view。
  - 禁止 `_call_scene("_apply_landscape_layout_impl")` 和 `_call_scene("_apply_portrait_layout_impl")`。
- [ ] `test_battle_scene_layout_wrappers_are_thin`
  - 允许 `_apply_landscape_layout`、`_apply_portrait_layout` 作为 wrapper。
  - wrapper 行数上限 10 行。
- [ ] `test_portrait_every_major_region_fits_content_rect`
  - 保持竖屏 surface contract。
- [ ] `test_landscape_layout_keeps_hand_and_background_inside_viewport`
  - 覆盖 macOS 横屏全屏/大窗口历史问题。

预期：

- layout view 仍调用 scene impl，contract 测试失败。

### GREEN

- [ ] 先迁 `_apply_landscape_layout_impl` 到 `BattleLandscapeLayoutView`。
- [ ] 再迁 `_apply_portrait_layout_impl` 到 `BattlePortraitLayoutView`。
- [ ] 把 HUD、pile、stadium 尺寸函数迁入 presenter。
- [ ] `BattleScene._apply_responsive_layout()` 只调用 `BattleLayoutCoordinator.apply()`。
- [ ] 保留旧 `_apply_landscape_layout()`、`_apply_portrait_layout()` wrapper，测试稳定后再删。

### REFACTOR

- [ ] 删除 layout view 中用于回调 scene impl 的临时 `_call_scene`。
- [ ] 所有竖屏布局尺寸从 `content_rect` 和 `BattleLayoutState` 派生。
- [ ] 横屏和竖屏 presenter 不互相读写状态。

### Gate

- [ ] `test_battle_layout_controller.gd` 通过。
- [ ] `test_battle_portrait_layout.gd` 通过。
- [ ] `test_battle_layout_extraction_contract.gd` 通过。
- [ ] `test_script_load_regressions.gd` 通过。

### Manual Smoke

- [ ] Windows 横屏，手牌不出屏，背景不露空块。
- [ ] macOS 大窗口进入战斗后不缩小。
- [ ] Android/竖屏，顶部按钮、手牌、HUD、VSTAR、竞技场都在屏内。

## Phase 3: Display 迁移

### 目标

把状态到 UI 的展示刷新从 `BattleScene` 移出。

### 文件

新增：

- `scripts/ui/battle/display/BattleDisplayCoordinator.gd`
- `scripts/ui/battle/display/BattleFieldPresenter.gd`
- `scripts/ui/battle/display/BattleHandPresenter.gd`
- `scripts/ui/battle/display/BattlePilePresenter.gd`
- `scripts/ui/battle/display/BattlePrizePresenter.gd`
- `scripts/ui/battle/display/BattleStatusHudPresenter.gd`
- `scripts/ui/battle/display/BattleCardDetailController.gd`
- `tests/test_battle_display_coordinator.gd`
- `tests/test_battle_hand_presenter.gd`
- `tests/test_battle_card_detail_controller.gd`

修改：

- `scenes/battle/BattleScene.gd`
- `scripts/ui/battle/BattleDisplayController.gd`
- 相关 display 测试

### RED

- [ ] `test_display_coordinator_refresh_all_calls_presenters_in_order`
- [ ] `test_hand_presenter_builds_cards_without_scene_private_state`
- [ ] `test_card_detail_controller_opens_and_closes_detail_overlay`
- [ ] `test_battle_scene_no_longer_instantiates_battle_card_view_for_hand`

预期：

- 新 coordinator/presenter 不存在，测试失败。

### GREEN

- [ ] 建立 display 目录和 coordinator。
- [ ] 先让 coordinator 包装旧 `BattleDisplayController`，保持行为。
- [ ] 逐步迁移手牌、场地、pile、HUD、card detail。
- [ ] `BattleScene._refresh_ui()` 改为 `display.refresh_all()`。
- [ ] 每迁一个 presenter，就把对应旧 helper 改成 wrapper 或删除。

### REFACTOR

- [ ] presenter 只处理 UI，不调用 `GameStateMachine.apply_action()`。
- [ ] 卡牌 view 创建集中在 presenter。
- [ ] 详情弹窗状态迁入 `BattleVisualState` 或 detail controller state。

### Gate

- [ ] `test_battle_display_controller.gd` 通过。
- [ ] 新 display presenter 测试通过。
- [ ] `test_battle_portrait_layout.gd` 通过。
- [ ] `test_battle_ui_features.gd` 通过。

### Manual Smoke

- [ ] 手牌、备战区、出战区刷新正常。
- [ ] 弃牌、lost、奖赏、牌库查看正常。
- [ ] 卡牌详情打开、使用、取消正常。

## Phase 4: Dialog and Prompt 迁移

### 目标

拆掉 `BattleDialogController.gd` 和 `_handle_dialog_choice` 的大型分发，把弹窗 surface、prompt request、prompt route 分开。

### 文件

新增：

- `scripts/ui/battle/prompts/BattlePromptRequest.gd`
- `scripts/ui/battle/prompts/BattlePromptSelection.gd`
- `scripts/ui/battle/prompts/BattlePromptRouter.gd`
- `scripts/ui/battle/prompts/BattleDialogSurfaceController.gd`
- `scripts/ui/battle/prompts/BattleSetupPromptController.gd`
- `scripts/ui/battle/prompts/BattleCardChoicePromptController.gd`
- `scripts/ui/battle/prompts/BattlePokemonActionPromptController.gd`
- `scripts/ui/battle/prompts/BattleSendOutPromptController.gd`
- `scripts/ui/battle/prompts/BattleEnergyTransferPromptController.gd`
- `scripts/ui/battle/prompts/BattleMatchEndDialogController.gd`
- `tests/test_battle_prompt_router.gd`
- `tests/test_battle_dialog_surface_controller.gd`
- `tests/test_battle_setup_prompt_controller.gd`
- `tests/test_battle_energy_transfer_prompt_controller.gd`

修改：

- `scenes/battle/BattleScene.gd`
- `scripts/ui/battle/BattleDialogController.gd`
- `tests/test_battle_dialog_controller.gd`

### RED

- [ ] `test_prompt_router_routes_setup_active`
- [ ] `test_prompt_router_routes_setup_bench`
- [ ] `test_prompt_router_routes_send_out`
- [ ] `test_prompt_router_routes_retreat`
- [ ] `test_prompt_router_routes_heavy_baton`
- [ ] `test_prompt_router_rejects_unknown_prompt_id_with_clear_error`
- [ ] `test_dialog_surface_portrait_buttons_are_readable_and_not_stacked_wrong`
- [ ] `test_battle_scene_handle_dialog_choice_is_thin_or_absent`

预期：

- router 和 request 对象不存在，测试失败。
- `_handle_dialog_choice` 仍过大，架构测试失败。

### GREEN

- [ ] 新建 request/selection/router。
- [ ] 保持旧 show dialog 行为，但把 pending choice 分发集中到 router。
- [ ] 先迁 setup prompt，再迁 send out、retreat、pokemon action、stadium action。
- [ ] 最后迁 Heavy Baton 和 Exp Share。
- [ ] `BattleDialogController` 逐步退化为 surface，或拆成 surface + 具体 prompt controller。

### REFACTOR

- [ ] 删除自由字符串 `_pending_choice` 的分散判断。
- [ ] 每个 prompt handler 只有一个明确规则出口。
- [ ] 移动端弹窗尺寸只由 surface 控制。

### Gate

- [ ] `test_battle_dialog_controller.gd` 通过。
- [ ] 新 prompt 测试通过。
- [ ] `test_battle_ui_handover_regression.gd` 通过。
- [ ] `test_battle_portrait_layout.gd` 通过。

### Manual Smoke

- [ ] 开局选择出战和备战正常。
- [ ] 撤退、攻击、特性、竞技场弹窗正常。
- [ ] 气绝后派出宝可梦正常。
- [ ] Heavy Baton、Exp Share 正常。
- [ ] 竖屏弹窗按钮和文字可读。

## Phase 5: Interaction and Effect Flow 迁移

### 目标

场上目标选择、场上分配、伤害指示物分配和 effect step 流程脱离 scene 私有状态。

### 文件

新增：

- `scripts/ui/battle/interactions/BattleEffectInteractionState.gd`
- `scripts/ui/battle/interactions/BattleFieldChoiceController.gd`
- `scripts/ui/battle/interactions/BattleFieldAssignmentController.gd`
- `scripts/ui/battle/interactions/BattleCounterDistributionController.gd`
- `scripts/ui/battle/interactions/BattleEffectInteractionFlow.gd`
- `tests/test_battle_field_choice_controller.gd`
- `tests/test_battle_field_assignment_controller.gd`
- `tests/test_battle_counter_distribution_controller.gd`
- `tests/test_battle_effect_interaction_flow.gd`

修改：

- `scenes/battle/BattleScene.gd`
- `scripts/ui/battle/BattleInteractionController.gd`
- `scripts/ui/battle/BattleEffectInteractionController.gd`
- `tests/test_battle_effect_interaction_controller.gd`

### RED

- [ ] `test_effect_interaction_state_reset_clears_pending_card_steps_and_context`
- [ ] `test_field_choice_confirm_returns_selected_slot_ids`
- [ ] `test_field_assignment_confirm_returns_source_target_pairs`
- [ ] `test_counter_distribution_total_cannot_exceed_required_amount`
- [ ] `test_ai_owned_effect_step_hides_manual_ui_and_advances`
- [ ] `test_effect_interaction_controllers_do_not_write_scene_pending_effect_fields`

预期：

- 新 state/flow 不存在，测试失败。
- 旧 controller 仍写 scene 字段，架构测试失败。

### GREEN

- [ ] 迁 `_field_interaction_*` 到 `BattleInteractionState`。
- [ ] 迁 `_pending_effect_*` 到 `BattleEffectInteractionState`。
- [ ] slot choice、assignment、counter distribution 拆成独立 controller。
- [ ] `BattleEffectInteractionFlow` 统一 start/confirm/cancel/reset。

### REFACTOR

- [ ] 旧 `BattleInteractionController` 只保留过渡 wrapper，随后删除。
- [ ] AI 自动选择和玩家手动选择共用 reset 路径。
- [ ] modal input suppress 与 overlay state 对齐。

### Gate

- [ ] `test_battle_effect_interaction_controller.gd` 通过。
- [ ] 新 interactions 测试通过。
- [ ] `test_specialized_effects.gd` 通过。
- [ ] `test_battle_ui_features.gd` 通过。

### Manual Smoke

- [ ] 需要选择场上目标的道具/特性可用。
- [ ] 能量移动、伤害指示物分配可用。
- [ ] AI 触发相关效果不会弹错手动 UI。

## Phase 6: Overlay、Prize、Handover、Match End 迁移

### 目标

拆分 overlay 职责，修正双方同时拿奖、交接时机、结算流程的状态边界。

### 文件

新增：

- `scripts/ui/battle/overlays/BattleOverlayState.gd`
- `scripts/ui/battle/overlays/BattlePrizeQueueState.gd`
- `scripts/ui/battle/overlays/BattlePrizeFlowController.gd`
- `scripts/ui/battle/overlays/BattleHandoverController.gd`
- `scripts/ui/battle/overlays/BattleOpponentHandOverlay.gd`
- `scripts/ui/battle/overlays/BattleReviewOverlayController.gd`
- `scripts/ui/battle/overlays/BattleMatchEndController.gd`
- `tests/test_battle_prize_flow_controller.gd`
- `tests/test_battle_handover_controller.gd`
- `tests/test_battle_match_end_controller.gd`

修改：

- `scenes/battle/BattleScene.gd`
- `scripts/ui/battle/BattleOverlayController.gd`
- `tests/test_battle_ui_handover_regression.gd`
- `tests/test_battle_ui_features.gd`

### RED

- [ ] `test_prize_queue_processes_both_players_when_both_take_prizes`
- [ ] `test_prize_flow_waits_for_first_selection_before_second_prompt`
- [ ] `test_handover_does_not_show_until_current_setup_step_finished`
- [ ] `test_handover_resume_runs_followup_after_confirm`
- [ ] `test_match_end_waits_until_pending_prize_queue_empty`
- [ ] `test_overlay_controller_no_longer_owns_prize_handover_match_end_together`

预期：

- 双方同时拿奖测试可能暴露当前流程缺陷。
- overlay 架构测试失败。

### GREEN

- [ ] 新增 prize queue state。
- [ ] `_start_prize_selection` 改为 enqueue + process next。
- [ ] 完成一次奖赏选择后自动检查 queue，再决定是否结算或继续。
- [ ] 迁交接遮罩到 `BattleHandoverController`。
- [ ] 迁结算状态和按钮到 `BattleMatchEndController`。
- [ ] 迁对手手牌查看和复盘 overlay 外壳到独立模块。

### REFACTOR

- [ ] `BattleOverlayController` 降为 wrapper，或拆空后删除。
- [ ] prize/handover/match end 不共享一组临时 scene 字段。
- [ ] 结算只在奖赏、派出、状态清理完成后触发。

### Gate

- [ ] `test_battle_prize_flow_controller.gd` 通过。
- [ ] `test_battle_handover_controller.gd` 通过。
- [ ] `test_battle_match_end_controller.gd` 通过。
- [ ] `test_battle_ui_handover_regression.gd` 通过。
- [ ] `test_battle_ui_features.gd` 通过。

### Manual Smoke

- [ ] 黑夜魔灵自爆导致双方拿奖时能连续完成。
- [ ] 玩家 1 setup 未完成前不弹玩家 2 交接。
- [ ] 气绝、拿奖、派出、结算顺序正确。

## Phase 7: AI、Advice、Discussion 迁移

### 目标

把 AI 对手构建、AI 行动循环、LLM 等待 HUD、AI 探讨、AI 建议和结算复盘服务从 scene/controller 混合状态中拆开。

### 文件

新增：

- `scripts/ui/battle/ai/BattleAiState.gd`
- `scripts/ui/battle/ai/BattleAdviceState.gd`
- `scripts/ui/battle/ai/BattleAiOpponentFactory.gd`
- `scripts/ui/battle/ai/BattleAiTurnController.gd`
- `scripts/ui/battle/ai/BattleLlmWaitHudController.gd`
- `scripts/ui/battle/ai/BattleAdviceServiceController.gd`
- `scripts/ui/battle/ai/BattleDiscussionController.gd`
- `scripts/ui/battle/ai/BattleReviewGenerationController.gd`
- `tests/test_battle_ai_opponent_factory.gd`
- `tests/test_battle_ai_turn_controller.gd`
- `tests/test_battle_discussion_controller.gd`
- `tests/test_battle_llm_wait_hud_controller.gd`

修改：

- `scenes/battle/BattleScene.gd`
- `scripts/ui/battle/BattleAdviceController.gd`
- `tests/test_battle_advice_*`
- `tests/test_battle_ai_advice_copy.gd`

### RED

- [ ] `test_ai_opponent_factory_builds_selected_version_with_fixed_deck_order`
- [ ] `test_ai_turn_controller_stops_after_max_actions`
- [ ] `test_ai_turn_controller_schedules_followup_after_action_pause`
- [ ] `test_discussion_controller_builds_visible_context_without_scene_private_access`
- [ ] `test_llm_wait_hud_uses_portrait_hand_info_metrics`
- [ ] `test_ai_controllers_do_not_directly_mutate_review_overlay_nodes`

预期：

- 新 AI 模块不存在，测试失败。

### GREEN

- [ ] 迁 AI 对手构建到 factory。
- [ ] 迁 AI turn loop 到 `BattleAiTurnController`。
- [ ] 迁 LLM 等待 HUD 到独立 controller。
- [ ] 迁 AI 探讨上下文构造到 `BattleDiscussionController`。
- [ ] 拆 `BattleAdviceController`：service state 与 overlay state 分离。
- [ ] 保持 `BattleAdviceFormatter`、`BattleReviewFormatter` 纯 helper。

### REFACTOR

- [ ] AI turn controller 只发请求，不直接操作 prompt surface。
- [ ] advice service controller 不直接改 review overlay 节点。
- [ ] discussion UI 尺寸遵守 dialog surface 的横竖屏规则。

### Gate

- [ ] `test_battle_advice_*` 通过。
- [ ] `test_battle_ai_advice_copy.gd` 通过。
- [ ] 新 AI 模块测试通过。
- [ ] `test_battle_ui_features.gd` 通过。

### Manual Smoke

- [ ] AI 对手能完整行动。
- [ ] AI LLM 等待 HUD 显示和隐藏正常。
- [ ] 竖屏 AI 探讨输入区和按钮正常。
- [ ] 结算复盘生成、重新生成、pin 正常。

## Phase 8: Replay、Recording、Runtime Log 收口

### 目标

把回放、记录和运行日志从 scene 私有字段中解耦。

### 文件

新增：

- `scripts/ui/battle/replay/BattleReplayState.gd`
- `scripts/ui/battle/recording/BattleRecordingState.gd`
- `tests/test_battle_replay_state.gd`
- `tests/test_battle_recording_state.gd`
- `tests/test_battle_runtime_log_context_snapshot.gd`

可能移动：

- `scripts/ui/battle/BattleReplayController.gd` 到 `scripts/ui/battle/replay/BattleReplayController.gd`
- `scripts/ui/battle/BattleRecordingController.gd` 到 `scripts/ui/battle/recording/BattleRecordingController.gd`
- `scripts/ui/battle/BattleRuntimeLogController.gd` 到 `scripts/ui/battle/recording/BattleRuntimeLogController.gd`

修改：

- `scenes/battle/BattleScene.gd`
- replay/recording tests

### RED

- [ ] `test_replay_state_reset_clears_loaded_snapshot_and_turn_cursor`
- [ ] `test_replay_controller_continue_replaces_context_gsm`
- [ ] `test_replay_controller_prev_next_use_replay_state`
- [ ] `test_recording_controller_builds_snapshot_from_context_not_scene_private_fields`
- [ ] `test_runtime_log_controller_reads_context_snapshot`

预期：

- 新 state 不存在，测试失败。
- recording/runtime log 仍依赖 scene 私有字段。

### GREEN

- [ ] 迁 `_replay_*` 到 `BattleReplayState`。
- [ ] `BattleReplayController` 改为 context + state。
- [ ] 迁 `_battle_recorder` 和 recording fields 到 `BattleRecordingState`。
- [ ] `BattleRuntimeLogController` 从 context/state 读快照。
- [ ] 回放 continue 后更新 context.gsm，并通知 display/layout/overlay。

### REFACTOR

- [ ] replay 按钮 signal 只转发到 replay controller。
- [ ] recording snapshot helper 不再散落在 BattleScene。

### Gate

- [ ] `test_battle_replay_controller.gd` 通过。
- [ ] `test_battle_replay_state_restorer.gd` 通过。
- [ ] `test_battle_recording_controller.gd` 通过。
- [ ] `test_battle_recorder.gd` 通过。
- [ ] 新 replay/recording state 测试通过。

### Manual Smoke

- [ ] 回放上一回合、下一回合正常。
- [ ] 从这里继续后进入 live battle。
- [ ] 对战记录、复盘 artifact 输出路径不变。

## Phase 9: 删除兼容层和静态审计

### 目标

完成真正收口：删除旧 wrapper、私有字段和反射访问，防止架构回退。

### 文件

新增或修改：

- `tests/test_battle_scene_architecture_audit.gd`
- 可能新增：`scripts/ui/battle/BattleSceneCompatAdapter.gd`
- 修改全部迁移过的 battle controller

### RED

- [ ] `test_battle_controllers_do_not_reflect_scene_private_state`
  - 扫描 `scripts/ui/battle`。
  - 禁止 `scene.get("_")`、`scene.set("_")`、`scene.call("_")`。
  - 允许 `BattleSceneCompatAdapter.gd` 临时例外；Phase 9 完成时例外为空。
- [ ] `test_battle_scene_line_count_under_target`
  - 阶段目标先设 3000 行。
  - 最终目标改为 1800 行。
- [ ] `test_no_layout_impl_wrappers_remain_in_battle_scene`
- [ ] `test_no_pending_choice_string_router_remains_in_battle_scene`

预期：

- 初始 audit 失败，驱动删除兼容层。

### GREEN

- [ ] 删除 BattleScene 中已无调用的 wrapper。
- [ ] 删除已迁移旧字段。
- [ ] 删除 controller 中剩余反射访问。
- [ ] 如果必须保留少量 scene 桥接，集中到 `BattleSceneCompatAdapter` 并写 TODO 删除清单。
- [ ] 修改信号连接，让入口直接进新 controller。

### REFACTOR

- [ ] 清理 preload。
- [ ] 清理死代码和未使用测试 fixture。
- [ ] 更新旧 4 月 plan/spec，标注本 plan 为全量重构主计划。

### Gate

- [ ] Phase 0 全部 baseline 通过。
- [ ] 所有新增 architecture audit 通过。
- [ ] 所有 battle focused tests 通过。
- [ ] 脚本加载回归通过。

### Manual Smoke

- [ ] 横屏完整对局。
- [ ] 竖屏完整对局。
- [ ] AI 对局。
- [ ] 回放继续。
- [ ] 结算复盘。

## 每阶段交付模板

每个 phase 完成时，在提交信息或阶段记录里写：

```text
Phase N: <name>

Changed:
- <主要结构变化>
- <迁出的 BattleScene 方法/字段>

Tests:
- <运行的 focused tests>
- <已知失败，如果有>

Metrics:
- BattleScene.gd lines: <number>
- controller private reflection count: <number>
- remaining compat wrappers: <number>

Manual:
- <smoke 项目和结果>
```

## 行数和反射访问阶段目标

这些是进度门槛，不是单次提交硬要求：

| 阶段 | BattleScene 行数目标 | 私有反射访问目标 |
| --- | ---: | ---: |
| Phase 0 | 记录基线 | 记录基线 |
| Phase 1 | 可小幅增加 | 不增加 |
| Phase 2 | 9000 以下 | 减少 layout view 反射 |
| Phase 3 | 7500 以下 | display 反射减少 50% |
| Phase 4 | 6000 以下 | dialog prompt 反射减少 40% |
| Phase 5 | 5000 以下 | interaction/effect 私有字段反射大幅减少 |
| Phase 6 | 4000 以下 | overlay/prize/handover 反射大幅减少 |
| Phase 7 | 3200 以下 | AI/advice 反射大幅减少 |
| Phase 8 | 2600 以下 | replay/recording 反射大幅减少 |
| Phase 9 | 1800 以下 | 除 adapter 外为 0 |

## 计划执行顺序建议

第一轮只做到 Phase 1 和 Phase 2。原因：

- Phase 1 搭结构，不碰行为，风险低。
- Phase 2 先移 layout，能最快降低 BattleScene 的 UI 维护压力，也能保护近期大量竖屏修复。
- Phase 2 完成前不要同时拆 dialog、overlay、AI，否则回归定位成本会过高。

Phase 2 稳定后，再按 Display、Dialog、Interaction、Overlay、AI、Replay 的顺序推进。这个顺序从“纯展示”逐步走向“规则流程”，比先拆交互状态更容易保持功能正确。
