# BattleScene 全量重构设计文档

**日期:** 2026-05-11

## 结论

`scenes/battle/BattleScene.gd` 目前有 11211 行、702 个函数、41 个 preload、249 个普通状态变量、99 个 `@onready` 节点引用。之前已经抽出了 `BattleI18n`、若干 formatter、layout view 和多个 controller，但这些 controller 大量通过 `scene.get()`、`scene.set()`、`scene.call()` 访问 `BattleScene` 私有字段和私有方法，本质上仍然是一个中心脚本，只是把部分代码搬到了旁边。

这次重构的目标不是继续把代码机械移动到更多文件，而是建立明确的状态所有权、节点引用边界、控制器接口和迁移纪律。最终 `BattleScene.gd` 应该退化为场景入口和事件编排层，战斗 UI 的布局、展示、弹窗、交互、AI 辅助、回放、结算、记录等逻辑分别由可测试的模块负责。

## 当前结构盘点

### BattleScene 当前职责

`BattleScene.gd` 同时承担这些职责：

- 场景生命周期和节点绑定。
- `GameStateMachine` 创建、恢复和推进。
- 横屏、竖屏、自适应画布、HUD、手牌区、备战区、奖赏区、弃牌区、竞技场区布局。
- 手牌、场上宝可梦、场地、弃牌、奖赏、牌库等展示刷新。
- 对话框、卡牌选择、setup、撤退、攻击、特性、道具、支援者、竞技场、派出宝可梦等交互流程。
- 场上目标选择、能量移动、伤害指示物分配等 effect interaction。
- 抽牌展示、攻击特效、洗牌特效、详情弹窗。
- AI 对手构建和 AI 行动循环。
- AI 探讨、AI 建议、对局复盘、结算快速复盘。
- 回放加载、回放导航、从回放继续。
- 对战记录、运行日志、调试日志。
- 双人本地交接、奖赏选择、结算遮罩。

### 已经存在的拆分

当前已有这些 battle UI 模块：

| 文件 | 行数 | 问题 |
| --- | ---: | --- |
| `BattleDialogController.gd` | 2811 | 已经太大，且大量反射访问 scene。 |
| `BattleInteractionController.gd` | 1311 | 混合场上目标选择、分配、计数器分配、面板样式。 |
| `BattleAttackVfxController.gd` | 1015 | 相对独立，可保留，后续减少 scene 访问即可。 |
| `BattleOverlayController.gd` | 1005 | 混合奖赏、对手手牌、交接、复盘、结算。 |
| `BattleDisplayController.gd` | 977 | 混合手牌、场地、HUD、弃牌、奖赏、牌库展示。 |
| `BattleDrawRevealController.gd` | 741 | 方向正确，但状态仍依附 scene 字段。 |
| `BattleEffectInteractionController.gd` | 415 | 交互状态仍在 scene。 |
| `BattleAdviceController.gd` | 344 | 同时管服务、状态、overlay、panel。 |
| `BattleReplayController.gd` | 122 | 相对干净，适合作为后续 controller 目标形态参考。 |
| `BattleSceneRefs.gd` | 23 | 目前只绑定 replay 按钮，未真正承担节点引用边界。 |

### 主要风险点

当前 `scripts/ui/battle` 与 `scripts/ui/battle/layouts` 里总计超过一千处反射式 scene 访问。典型形式包括：

- `scene.get("_gsm")`
- `scene.set("_pending_choice", value)`
- `scene.call("_refresh_ui")`
- layout view 通过 `_call_scene()` 继续调用 `BattleScene` 的私有布局实现

这种结构的维护风险是：

- 状态所有权不清楚。字段在 `BattleScene` 声明，实际可能由任意 controller 修改。
- controller 很难单测。必须构造一个携带大量私有字段和方法的假 scene。
- 改名和删字段没有编译期保护。`scene.get("_xxx")` 在运行时才暴露问题。
- 文件拆分不能降低认知成本。开发者仍然需要同时理解 `BattleScene` 和所有反射调用。

## 重构目标

### 最终目标

- `BattleScene.gd` 控制在 1200 到 1800 行左右。
- 单个 controller 尽量控制在 800 行以内；确实复杂的 controller 需要继续按子领域拆分。
- 除临时兼容层外，新增或迁移后的 battle controller 禁止直接使用 `scene.get()`、`scene.set()`、`scene.call()` 访问私有状态。
- UI 节点引用集中在 `BattleSceneRefs`，业务状态集中在明确的 state 对象。
- 每个 controller 的输入是 `BattleSceneContext`、自己的 state、必要 refs 和明确服务，不再依赖完整 scene。
- 横屏和竖屏布局只能通过 layout surface contract 修改，不能在任意功能代码里临时 clamp。
- visible copy 继续通过 `BattleI18n`，不能重新散落到 BattleScene 或 controller。
- 行为保持一致，重构期间不夹带规则、牌效、视觉风格和交互设计变更。

### 非目标

- 不重写 `GameStateMachine`。
- 不把横屏和竖屏拆成两套 `.tscn`。
- 不在第一阶段改战斗规则、卡牌效果和 AI 策略。
- 不把所有东西做成 Autoload。
- 不追求一次性大爆破式删除旧接口。

## 目标架构

### 分层

重构后的 BattleScene 相关代码分为五层：

1. **Scene Shell**
   - 文件：`scenes/battle/BattleScene.gd`
   - 只负责 Godot 生命周期、信号入口、controller 构建、少量顶层编排。

2. **Context and State**
   - 文件：`scenes/battle/BattleSceneRefs.gd`
   - 新增：`scripts/ui/battle/BattleSceneContext.gd`
   - 新增：若干 `Battle*State.gd`
   - 负责节点引用、共享服务、运行态状态所有权。

3. **Flow Controllers**
   - 例如 setup、action、effect interaction、prize、handover、match end、replay、AI。
   - 负责用户意图到 `GameStateMachine` 动作之间的流程。

4. **Presenters and Views**
   - 例如 hand、field、pile、HUD、dialog surface、card detail、layout view。
   - 只处理 UI 展示、尺寸和节点样式，不推进规则状态。

5. **Pure Helpers**
   - `BattleI18n`
   - `BattleAdviceFormatter`
   - `BattleReviewFormatter`
   - 纯输入输出，不依赖 scene 节点。

### 关键对象

#### BattleScene.gd

最终保留职责：

- `_ready()` 中构造 refs、context、states、controllers。
- 接收 `.tscn` 上已有信号，并转发给对应 controller。
- 管理 `GameStateMachine` 的创建、替换、回放恢复入口。
- 管理 controller 生命周期。
- 保留一小段兼容 wrapper，直到所有测试和 controller 都迁完。

禁止新增职责：

- 不新增具体布局细节。
- 不新增具体弹窗构建细节。
- 不新增卡牌展示刷新细节。
- 不新增 AI 建议、复盘、探讨的格式化和 overlay 细节。
- 不新增私有状态给外部 controller 反射访问。

#### BattleSceneRefs.gd

当前只绑定 replay 按钮，需要扩展为 battle 场景节点引用边界。

建议结构：

```gdscript
class_name BattleSceneRefs
extends RefCounted

var root: Control

var top_bar: Control
var more_button: Button
var end_turn_button: Button
var opponent_hand_button: Button
var ai_advice_button: Button

var battlefield: Control
var my_active_slot: Control
var opponent_active_slot: Control
var my_bench_slots: Array[Control]
var opponent_bench_slots: Array[Control]

var hand_panel: Control
var hand_scroll: ScrollContainer
var hand_row: Container

var dialog_overlay: Control
var dialog_panel: PanelContainer
var dialog_title: Label
var dialog_confirm_button: Button
var dialog_cancel_button: Button

var review_overlay: Control
var detail_overlay: Control
var draw_reveal_overlay: Control
var attack_vfx_overlay: Control

func bind_from_scene(scene: Node) -> void:
    # 只做节点查找和类型转换，不做布局、不连信号、不改 visible。
    pass
```

规则：

- refs 可以持有 node，但不持有 `GameStateMachine`。
- refs 只做节点查找和简单 grouped getter。
- refs 不写业务状态，不决定按钮是否可点。
- controller 只能通过 refs 使用节点，不能自己到 scene 上 find_child。
- `BattleScene.gd` 的 99 个 `@onready` 节点引用逐步迁入 refs。迁移期间可以保留旧字段作为 wrapper，但最终删除。

#### BattleSceneContext.gd

新增共享上下文，替代 controller 直接拿完整 scene。

建议字段：

```gdscript
class_name BattleSceneContext
extends RefCounted

var refs: BattleSceneRefs
var i18n: BattleI18n
var gsm: GameStateMachine
var view_player: int = 0
var battle_mode: String = "live"
var selected_deck_names: Array[String] = []

var layout_state: BattleLayoutState
var dialog_state: BattleDialogState
var interaction_state: BattleInteractionState
var replay_state: BattleReplayState
var ai_state: BattleAiState
var advice_state: BattleAdviceState
var recording_state: BattleRecordingState

signal request_refresh_ui()
signal request_handover(target_player: int)
signal request_match_end(winner_index: int, reason: String)
```

规则：

- context 只持有共享对象和跨 controller 事件，不做复杂逻辑。
- controller 可以读写自己拥有的 state；跨域修改必须走方法或 signal。
- `gsm` 替换时由 `BattleScene` 更新 context，然后通知相关 controller。
- context 可以作为测试里的假上下文构造入口。

#### State 对象

需要优先拆这些状态：

| 新 state | 从 BattleScene 迁出的字段 |
| --- | --- |
| `BattleDialogState` | `_pending_choice`、`_dialog_multi_selected_indices`、assignment 相关字段。 |
| `BattleInteractionState` | `_field_interaction_*`、field assignment、counter distribution 相关字段。 |
| `BattleLayoutState` | `_play_card_size`、`_dialog_card_size`、`_detail_card_size`、portrait frame/debug/layout signature。 |
| `BattleReplayState` | `_battle_mode`、`_replay_*` 字段。 |
| `BattleAiState` | `_ai_*`、`_latest_opponent_action_*`。 |
| `BattleAdviceState` | `_battle_advice_*`、`_battle_review_*`、review overlay mode/pin/cached result。 |
| `BattleOverlayState` | prize selection、handover、match-end overlay 临时状态。 |
| `BattleVisualState` | card views、detail view、draw reveal view、shuffle/vfx 临时对象。 |
| `BattleRecordingState` | `_battle_recorder`、recording output、turn snapshot keys。 |

每个 state 的规则：

- 只放数据，不放 node。
- 字段命名去掉 scene 私有前缀，例如 `pending_choice` 而不是 `_pending_choice`。
- 提供 `reset()`，便于回放切换、开始新对局、测试清理。
- 有复杂不变量的 state 提供小方法，例如 `is_active()`、`clear_selection()`。

## 模块拆分方案

### Layout 模块

现状：

- `BattleLayoutCoordinator`、`BattleLayoutView`、`BattleLandscapeLayoutView`、`BattlePortraitLayoutView` 已存在。
- 但横屏 view 仍调用 `BattleScene._apply_landscape_layout_impl()`。
- 竖屏 view 仍调用 `BattleScene._apply_portrait_layout_impl()` 和若干 scene 私有方法。

目标文件：

- `scripts/ui/battle/layouts/BattleLayoutCoordinator.gd`
- `scripts/ui/battle/layouts/BattleLandscapeLayoutView.gd`
- `scripts/ui/battle/layouts/BattlePortraitLayoutView.gd`
- 新增 `scripts/ui/battle/layouts/BattleLayoutState.gd`
- 新增 `scripts/ui/battle/layouts/BattleHudLayoutPresenter.gd`
- 新增 `scripts/ui/battle/layouts/BattlePileHudLayoutPresenter.gd`
- 新增 `scripts/ui/battle/layouts/BattleStadiumLayoutPresenter.gd`

迁移方法：

- `_apply_landscape_layout_impl`
- `_apply_battle_surface_styles`
- `_apply_landscape_pile_hud_metrics`
- `_apply_landscape_status_huds_beside_active`
- `_move_landscape_status_stack_to_active_row`
- `_apply_portrait_layout_impl`
- `_apply_portrait_field_hud_metrics`
- `_apply_portrait_stadium_hud_metrics`
- `_move_portrait_hud_pair_to_field_edges`
- `_set_portrait_huds_on_field_edges`
- `_sync_portrait_top_action_visibility`
- `_sync_portrait_prize_hud_visibility`
- `_position_portrait_edge_hud_overlay`
- `_set_portrait_turn_action_in_stadium`
- `_enforce_portrait_field_axis_width`
- `_refresh_portrait_layout_debug_overlay`
- `_refresh_stadium_hud_debug_overlay`

目标接口：

```gdscript
func setup(context: BattleSceneContext) -> void
func apply(viewport_size: Vector2, preferred_mode: String, is_mobile: bool) -> Dictionary
func apply_after_state_refresh() -> void
func current_content_rect() -> Rect2
```

验收标准：

- `BattleScene.gd` 中 `_apply_landscape_layout_impl()` 和 `_apply_portrait_layout_impl()` 删除，或只剩 1 到 3 行兼容转发。
- layout view 不再通过 `_call_scene()` 调用 scene 私有布局方法。
- 竖屏所有控件继续遵守 `docs/superpowers/specs/2026-05-10-battle-portrait-layout-surface-contract.md`。
- 横屏 macOS 大窗口、Windows 横屏、Android 竖屏布局测试都通过。

### Display 模块

现状：

- `BattleDisplayController.gd` 已抽出，但仍通过 `scene.get/call` 获取状态、节点和 helper。
- 手动刷新入口 `_refresh_ui()` 仍在 `BattleScene.gd` 包装。

目标文件：

- `scripts/ui/battle/display/BattleDisplayCoordinator.gd`
- `scripts/ui/battle/display/BattleFieldPresenter.gd`
- `scripts/ui/battle/display/BattleHandPresenter.gd`
- `scripts/ui/battle/display/BattlePilePresenter.gd`
- `scripts/ui/battle/display/BattlePrizePresenter.gd`
- `scripts/ui/battle/display/BattleStatusHudPresenter.gd`
- 保留或迁移 `BattleDisplayController.gd` 为 coordinator。

迁移方法：

- `_refresh_ui`
- `_refresh_field_card_views`
- `_refresh_slot_card_view`
- `_refresh_hand`
- `_build_hand_card`
- `_refresh_stadium_area`
- `_update_side_previews`
- `_refresh_info_hud`
- `_update_prize_slots`
- `_update_pile_preview`
- `_show_discard_pile`
- `_show_lost_zone`
- `_show_prize_cards`
- `_show_deck_cards`
- `_show_card_detail`
- `_setup_detail_preview`

目标接口：

```gdscript
func refresh_all() -> void
func refresh_hand(player_index: int = context.view_player) -> void
func refresh_field() -> void
func refresh_piles() -> void
func refresh_status_hud() -> void
func show_card_detail(card: CardData, mode: String = "readonly") -> void
```

验收标准：

- 展示刷新不直接推进规则动作。
- `BattleScene` 不再创建具体 `BattleCardView`，只调用 presenter。
- 手牌区、场地区、弃牌区、奖赏区、牌库查看都有聚焦测试。
- 竖屏手牌文字、抽牌 reveal、卡牌详情弹窗等近期修复点不回退。

### Dialog and Prompt 模块

现状：

- `BattleDialogController.gd` 2811 行，是新的大文件。
- `_handle_dialog_choice` 仍在 `BattleScene.gd`，长 201 行，承担大量 pending choice 分发。

目标拆分：

| 新模块 | 职责 |
| --- | --- |
| `BattleDialogSurfaceController` | 通用弹窗壳、滚动区、按钮、移动端尺寸、样式。 |
| `BattlePromptRouter` | 把 `pending_choice` 分发到明确 handler。 |
| `BattleSetupPromptController` | setup active、setup bench、交接。 |
| `BattleCardChoicePromptController` | 文本/卡牌/多选/assignment 通用选择。 |
| `BattlePokemonActionPromptController` | 宝可梦行动、攻击、特性、撤退、竞技场行动。 |
| `BattleSendOutPromptController` | 气绝后派出宝可梦。 |
| `BattleEnergyTransferPromptController` | Heavy Baton、Exp Share、能量移动类弹窗。 |
| `BattleMatchEndDialogController` | 结算弹窗、复盘按钮、学习池按钮。 |

迁移方法：

- `_setup_dialog_gallery`
- `_show_dialog`
- `_show_text_dialog`
- `_show_card_dialog`
- `_show_assignment_dialog`
- `_handle_dialog_choice`
- `_show_setup_active_dialog`
- `_show_setup_bench_dialog`
- `_show_send_out_dialog`
- `_prompt_heavy_baton_dialog`
- `_prompt_exp_share_dialog`
- `_show_pokemon_action_dialog`
- `_show_stadium_action_dialog`
- `_show_retreat_dialog`
- `_show_match_end_dialog`

目标接口：

```gdscript
func show_prompt(request: BattlePromptRequest) -> void
func confirm(selection: BattlePromptSelection) -> void
func cancel() -> void
func is_open() -> bool
```

关键新对象：

```gdscript
class_name BattlePromptRequest
extends RefCounted

var id: String
var title_key: String
var items: Array
var mode: String
var min_selected: int = 1
var max_selected: int = 1
var payload: Dictionary = {}
```

迁移规则：

- 不再用自由字符串 `_pending_choice` 到处判断。先集中到 `BattlePromptRouter`，再逐步改成 `BattlePromptRequest.id`。
- 每个 prompt handler 必须只有一个规则出口，例如调用 action controller 或 gsm wrapper。
- 弹窗 surface 和 prompt 行为分离。移动端按钮大小、输入框布局只在 surface 层。

验收标准：

- `_handle_dialog_choice` 从 `BattleScene.gd` 删除或只剩转发。
- setup、撤退、攻击、特性、竞技场、派出、Heavy Baton、Exp Share 都有回归测试。
- 竖屏 AI 探讨弹窗、普通选择弹窗、奖赏弹窗不会互相影响。

### Field Interaction and Effect Interaction 模块

现状：

- `BattleInteractionController.gd` 和 `BattleEffectInteractionController.gd` 分担场上选择和效果步骤，但状态仍放在 scene。

目标文件：

- `scripts/ui/battle/interactions/BattleInteractionState.gd`
- `scripts/ui/battle/interactions/BattleFieldChoiceController.gd`
- `scripts/ui/battle/interactions/BattleFieldAssignmentController.gd`
- `scripts/ui/battle/interactions/BattleCounterDistributionController.gd`
- `scripts/ui/battle/interactions/BattleEffectInteractionFlow.gd`

迁移方法：

- `_setup_field_interaction_panel`
- `_show_field_slot_choice`
- `_show_field_assignment_interaction`
- `_show_field_counter_distribution`
- `_handle_effect_interaction_choice`
- `_show_next_effect_interaction_step`
- `_reset_effect_interaction`
- `_effect_step_uses_field_slot_ui`
- `_effect_step_uses_field_assignment_ui`
- `_effect_step_uses_counter_distribution_ui`

目标接口：

```gdscript
func start(step: Dictionary, context_data: Dictionary) -> void
func choose_slot(slot_id: String) -> void
func choose_assignment(source_index: int, target_index: int) -> void
func choose_counter_amount(amount: int) -> void
func confirm() -> void
func cancel() -> void
```

验收标准：

- effect interaction 不再写 `_pending_effect_*` 到 scene。
- AI 持有的 effect step 可以静默执行或隐藏 UI，逻辑由 flow 判断。
- 手动选择和 AI 自动选择共用同一个 state 清理路径。

### Overlay 模块

现状：

- `BattleOverlayController.gd` 负责太多：奖赏选择、对手手牌、交接、复盘 overlay、结算 screen。

目标拆分：

| 新模块 | 职责 |
| --- | --- |
| `BattlePrizeFlowController` | 奖赏选择，包括双方同时拿奖的队列。 |
| `BattleHandoverController` | 本地双人交接遮罩和时机。 |
| `BattleOpponentHandOverlay` | 查看对手手牌。 |
| `BattleReviewOverlayController` | AI 建议/复盘 overlay 的通用外壳。 |
| `BattleMatchEndController` | 结算状态、结算 screen、结束后动作。 |

重点要求：

- 奖赏选择必须支持双方同时需要拿奖。不要只用单个 `_pending_prize_player_index` 表示全局唯一拿奖方。
- 交接提示必须由动作完成后的流程触发，不能阻塞当前玩家尚未完成的 setup 或奖赏处理。
- overlay z-index、modal input suppress、手牌点击 suppress 由统一 overlay state 管理。

奖赏队列建议：

```gdscript
class_name BattlePrizeQueueState
extends RefCounted

var queue: Array[Dictionary] = []
var active: Dictionary = {}

func enqueue(player_index: int, count: int, reason: String = "") -> void:
    queue.append({"player_index": player_index, "count": count, "reason": reason})

func pop_next() -> Dictionary:
    active = queue.pop_front() if not queue.is_empty() else {}
    return active
```

验收标准：

- 双方同时气绝、黑夜魔灵自爆等场景不会卡住。
- 竖屏和横屏奖赏弹窗都能连续处理多个拿奖请求。
- 结算只在所有必需奖赏选择、派出选择和状态清理完成后触发。

### AI and Advice 模块

现状：

- AI 对手构建、AI 行动循环、LLM 等待 HUD、AI 探讨、AI 建议、复盘进度混在 scene 和 `BattleAdviceController`。

目标拆分：

| 新模块 | 职责 |
| --- | --- |
| `BattleAiOpponentFactory` | 根据 deck、版本、固定牌序构建 AI 对手。 |
| `BattleAiTurnController` | AI 行动循环、action pause、max action guard。 |
| `BattleLlmWaitHudController` | LLM 思考中 HUD。 |
| `BattleAdviceServiceController` | AI 建议服务调用和状态。 |
| `BattleDiscussionController` | “AI 探讨”弹窗和上下文构造。 |
| `BattleReviewGenerationController` | 结算复盘生成流程。 |

迁移方法：

- `_build_default_ai_opponent`
- `_build_selected_ai_opponent`
- `_setup_ai_for_tests`
- `_maybe_run_ai_turn`
- `_run_ai_turn_step`
- `_start_ai_action_pause`
- `_show_ai_llm_wait`
- `_hide_ai_llm_wait`
- `_on_ai_advice_pressed`
- `_on_battle_discuss_ai_pressed`
- `_build_battle_discussion_context`
- `_on_battle_review_*`

目标接口：

```gdscript
func configure_opponent(config: Dictionary) -> void
func maybe_run_turn() -> void
func stop() -> void
func build_discussion_context() -> Dictionary
func request_advice() -> void
func request_match_review() -> void
```

验收标准：

- AI 行动循环不直接操作 overlay 或弹窗节点，只发出状态变化。
- AI 探讨 UI 的横屏/竖屏尺寸只由 dialog surface 或 discussion controller 管理。
- `BattleAdviceFormatter`、`BattleReviewFormatter` 保持纯 helper。

### Replay and Recording 模块

现状：

- `BattleReplayController.gd` 相对干净，可以继续增强。
- 但 replay state 字段仍在 scene；recording controller 仍反射 scene。

目标：

- `BattleReplayState` 完整拥有 `_replay_*` 字段。
- `BattleReplayController` 负责 prepare、load、prev、next、continue、back。
- `BattleRecordingController` 只依赖 context、gsm、recording state。

迁移方法：

- `_apply_launch_payload`
- `_prepare_replay_launch`
- `_load_replay_turn`
- `_on_replay_prev_turn_pressed`
- `_on_replay_next_turn_pressed`
- `_on_replay_continue_pressed`
- `_on_replay_back_to_list_pressed`
- `_build_battle_record_meta`
- `_build_battle_state_snapshot`
- `_record_battle_state_snapshot`

验收标准：

- 回放模式下 live action guard 仍然生效。
- 从回放继续后能够正确进入 live battle，并刷新 context.gsm。
- 对战记录和复盘路径不变。

## 迁移顺序

### Phase 0: 基线和保护网

目标：重构前先固定现状，避免后续不知道是重构坏了还是旧问题。

任务：

- 新增或更新一份 BattleScene 结构盘点脚本或文档段落，记录行数、函数数、反射访问数。
- 跑一次 focused battle 测试，记录当前失败项，不在重构中顺手修无关问题。
- 补齐近期高风险回归测试：
  - macOS 大窗口进入战斗不缩小。
  - Android/竖屏 AI 探讨输入区按钮尺寸。
  - 竖屏 draw reveal 7 张牌不出屏。
  - 双方同时拿奖不会卡住。

建议测试命令：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_portrait_layout.gd
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_ui_features.gd
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_dialog_controller.gd
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_effect_interaction_controller.gd
```

完成标准：

- 当前测试基线清楚。
- 文档里标出已知非本次重构问题。
- 不改业务行为。

### Phase 1: Context、Refs、State 骨架

目标：先建立新架构入口，不迁大逻辑。

任务：

- 扩展 `BattleSceneRefs.gd`，按区域绑定节点。
- 新增 `BattleSceneContext.gd`。
- 新增第一批 state：`BattleLayoutState`、`BattleDialogState`、`BattleInteractionState`、`BattleReplayState`。
- `BattleScene._ready()` 构造 refs/context/state，并传给新 controller。
- 保留旧字段，同步写入新 state，暂不删除旧字段。

完成标准：

- 所有 controller 仍可按旧方式工作。
- 新增 controller 可从 context 获取 refs/state。
- 不新增新的 `scene.get/set/call` 依赖。

### Phase 2: Layout 迁移

目标：先拿掉 BattleScene 最大的 UI 布局负担，尤其横竖屏差异代码。

任务：

- 把 `_apply_landscape_layout_impl` 的实际布局逻辑迁入 `BattleLandscapeLayoutView`。
- 把 `_apply_portrait_layout_impl` 的实际布局逻辑迁入 `BattlePortraitLayoutView`。
- 把 HUD、pile、stadium 尺寸函数迁入 layout presenter。
- `BattleScene` 只保留 `_apply_responsive_layout()` 调用 coordinator。
- 删除 layout view 对 `_call_scene("_apply_*_impl")` 的依赖。

完成标准：

- 横屏和竖屏布局函数不再在 `BattleScene` 承担细节。
- 竖屏 surface contract 测试通过。
- macOS 横屏大窗口、Windows 横屏、Android 竖屏都通过手动 smoke。

### Phase 3: Display 迁移

目标：把 “状态转 UI” 从 BattleScene 剥离。

任务：

- 新建 display 目录和 presenters。
- 迁移手牌刷新、场上卡刷新、pile/zone/gallery/card detail。
- `BattleDisplayController` 改为 coordinator，或逐步废弃为 wrapper。
- `BattleScene._refresh_ui()` 只调用 `display.refresh_all()`。

完成标准：

- BattleScene 不直接 new `BattleCardView`。
- 展示模块不调用 `gsm.apply_action` 或推进规则。
- card detail、hand area、discard/lost/deck/prize viewers 都有测试覆盖。

### Phase 4: Dialog and Prompt 迁移

目标：拆掉 `BattleDialogController.gd` 和 `_handle_dialog_choice` 两个最大交互结点。

任务：

- 建立 `BattlePromptRequest`、`BattlePromptSelection`、`BattlePromptRouter`。
- 把 `_pending_choice` 的字符串分发集中迁入 router。
- 先让旧 show_dialog 生成 request，再逐个替换调用点。
- 拆出 setup、pokemon action、send out、energy transfer、match end prompt。

完成标准：

- `_handle_dialog_choice` 不再有大型 if/elif 分发。
- `BattleDialogController.gd` 降到 800 行以下，或明确继续拆分。
- 所有弹窗按钮、文字、移动端尺寸由 dialog surface 控制。

### Phase 5: Interaction and Effect Flow 迁移

目标：让场上目标选择和卡牌效果步骤拥有自己的状态和生命周期。

任务：

- 迁移 `_field_interaction_*` 到 `BattleInteractionState`。
- 迁移 `_pending_effect_*` 到 `BattleEffectInteractionState`。
- 将 slot select、assignment、counter distribution 拆成独立 controller。
- 统一 `confirm/cancel/reset` 清理路径。

完成标准：

- AI 自动效果和玩家手动效果共用 flow。
- 取消、确认、换视角、modal suppress 后状态不会残留。
- effect interaction 测试不再需要构造完整 BattleScene。

### Phase 6: Overlay、Prize、Handover、Match End 迁移

目标：解决 overlay 混杂和双方同时拿奖这类流程问题。

任务：

- 拆出 `BattlePrizeFlowController`，引入 prize queue。
- 拆出 `BattleHandoverController`，把交接触发时机放到动作完成后。
- 拆出 `BattleMatchEndController`，负责结算状态和结束后按钮。
- 拆出 `BattleReviewOverlayController`，复用 AI 建议和结算复盘 overlay 外壳。

完成标准：

- 双方同时拿奖不会卡住。
- 本地双人交接不会在当前玩家操作未完成时弹出。
- match end 显示不依赖 dialog controller 的私有字段。

### Phase 7: AI、Advice、Discussion 迁移

目标：把 AI 对手、AI 行动循环和 AI UI 分开。

任务：

- 新建 `BattleAiOpponentFactory`。
- 新建 `BattleAiTurnController`。
- 新建 `BattleDiscussionController`，迁移 `_build_battle_discussion_context`。
- 拆分 `BattleAdviceController` 中的 service state 和 overlay state。
- LLM 等待 HUD 独立为 controller。

完成标准：

- AI turn controller 可以在测试中使用 fake gsm/fake ai opponent。
- AI 探讨 UI 修改不需要读 BattleScene 主文件。
- advice/review formatter 继续纯函数化。

### Phase 8: Replay、Recording、Runtime Log 收口

目标：把 replay/recording 的状态和 scene 生命周期解绑。

任务：

- 迁移 `_replay_*` 到 `BattleReplayState`。
- 让 `BattleReplayController` 持有 context 和 state。
- 让 `BattleRecordingController` 不再反射 scene。
- `BattleRuntimeLogController` 只读取 context/state 快照，不读 scene 私有字段。

完成标准：

- replay 相关 button signal 只转发到 replay controller。
- continue-from-replay 替换 gsm 后所有 controller 都拿到新 context.gsm。
- recording snapshot 测试通过。

### Phase 9: 删除兼容层和反射访问

目标：完成真正意义的重构。

任务：

- 删除 `BattleScene.gd` 中已无调用的旧字段、wrapper 和 private helper。
- 删除 controller 中的 `scene.get/set/call`，或只允许保留在 `BattleSceneCompatAdapter.gd`。
- 新增静态审计测试，限制 battle controller 反射访问。
- 更新旧设计文档索引，标注本文件为新的总设计。

完成标准：

- `BattleScene.gd` 1200 到 1800 行。
- `BattleDialogController.gd`、`BattleInteractionController.gd` 不再是新的大泥球。
- 除兼容 adapter 外，`scripts/ui/battle` 不再直接反射 BattleScene 私有字段。

## 兼容迁移模式

每迁一个函数，统一按下面步骤做：

1. 在目标 controller/state 里创建新方法和测试。
2. 把旧函数体移动到新方法，先保留行为不变。
3. 新方法参数从 `scene` 改为 `context`、`refs`、`state`。
4. 对仍缺的依赖，先在 `BattleSceneCompatAdapter` 暂存，不要继续在 controller 里新增 `scene.get`。
5. `BattleScene` 旧方法改成 1 到 5 行转发 wrapper。
6. 跑 focused 测试。
7. 搜索旧方法和旧字段引用，确认只剩 wrapper 或测试。
8. 下一阶段再删除 wrapper。

示例：

```gdscript
# 迁移前
func _refresh_hand() -> void:
    _battle_display_controller.call("refresh_hand", self)

# 过渡期
func _refresh_hand() -> void:
    _display_coordinator.refresh_hand()

# 完成后
# 删除 _refresh_hand，信号和调用点直接进入 display coordinator。
```

## 依赖规则

### 允许的依赖方向

- `BattleScene` 可以依赖所有 controller。
- controller 可以依赖 context、refs、自己的 state、纯 helper、明确注入的服务。
- presenter 可以依赖 refs、layout state、展示数据。
- pure helper 不依赖 node、不依赖 context。

### 禁止的依赖

- 新 controller 不允许直接依赖完整 `BattleScene`。
- 新 controller 不允许读写其他 controller 的私有 state。
- presenter 不允许调用 `GameStateMachine.apply_action()`。
- layout view 不允许决定行动是否合法。
- AI controller 不允许直接操作 dialog surface 节点。
- state 对象不允许持有 Node。

### 临时例外

只允许一个临时例外：

- `BattleSceneCompatAdapter.gd`

用途：

- 旧 controller 迁移过程中，需要访问尚未迁出的 helper 时，可以集中写在 adapter。
- adapter 文件顶部必须列出待删除清单。
- 每个 phase 结束要减少 adapter 调用数量，不能增长。

## 测试策略

### 每阶段必跑

```powershell
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_script_load_regressions.gd
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_portrait_layout.gd
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_ui_features.gd
```

### 按模块补跑

| 修改范围 | 测试 |
| --- | --- |
| layout | `test_battle_layout_controller.gd`、`test_battle_portrait_layout.gd` |
| dialog | `test_battle_dialog_controller.gd`、`test_battle_ui_handover_regression.gd` |
| effect interaction | `test_battle_effect_interaction_controller.gd`、`test_specialized_effects.gd` |
| AI advice | `test_battle_advice_*`、`test_battle_ai_advice_copy.gd` |
| replay | `test_battle_replay_*` |
| recording | `test_battle_recording_controller.gd`、`test_battle_recorder.gd` |
| copy/i18n | `test_battle_i18n.gd`、`test_battle_scene_visible_copy_audit.gd` |

### 手动 smoke 清单

每个大 phase 完成后至少手动检查：

- Windows 横屏进入对局，手牌不出屏。
- macOS 大窗口进入对局，窗口不缩小，横屏布局不露背景空块。
- Android 或竖屏预览进入对局，顶部按钮、手牌、奖赏、弃牌、VSTAR、竞技场 HUD 都在 content rect 内。
- 竖屏 AI 探讨输入框和发送/清空按钮可读可点。
- 开局 setup 玩家 1 完成前不弹交接。
- 抽 7 张牌 reveal 不出屏。
- 双方同时拿奖可以连续弹出并完成。
- AI 对手可以完整跑一个回合。
- 回放上一回合、下一回合、从这里继续都可用。
- 结算后复盘、学习池、返回按钮可用。

## 静态审计建议

Phase 9 前新增或增强审计：

```gdscript
func test_battle_controllers_do_not_reflect_scene_private_state() -> void:
    # 扫描 scripts/ui/battle，允许 BattleSceneCompatAdapter.gd 例外。
    # 禁止 scene.get("_")、scene.set("_")、scene.call("_")。
    pass
```

允许例外：

- `BattleScene.gd`
- `BattleSceneCompatAdapter.gd`
- 专门测试兼容层的测试文件

## 目录建议

最终目录可以演进为：

```text
scenes/battle/
  BattleScene.tscn
  BattleScene.gd
  BattleSceneRefs.gd
  BattleCardView.gd
  HandArea.gd
  PokemonSlotUI.gd

scripts/ui/battle/
  BattleSceneContext.gd
  BattleI18n.gd
  BattleSceneCompatAdapter.gd

scripts/ui/battle/layouts/
  BattleLayoutCoordinator.gd
  BattleLandscapeLayoutView.gd
  BattlePortraitLayoutView.gd
  BattleLayoutState.gd
  BattleHudLayoutPresenter.gd

scripts/ui/battle/display/
  BattleDisplayCoordinator.gd
  BattleFieldPresenter.gd
  BattleHandPresenter.gd
  BattlePilePresenter.gd
  BattlePrizePresenter.gd
  BattleCardDetailController.gd

scripts/ui/battle/prompts/
  BattlePromptRequest.gd
  BattlePromptSelection.gd
  BattlePromptRouter.gd
  BattleDialogSurfaceController.gd
  BattleSetupPromptController.gd
  BattlePokemonActionPromptController.gd
  BattleSendOutPromptController.gd
  BattleEnergyTransferPromptController.gd

scripts/ui/battle/interactions/
  BattleInteractionState.gd
  BattleFieldChoiceController.gd
  BattleFieldAssignmentController.gd
  BattleCounterDistributionController.gd
  BattleEffectInteractionFlow.gd

scripts/ui/battle/overlays/
  BattlePrizeFlowController.gd
  BattleHandoverController.gd
  BattleOpponentHandOverlay.gd
  BattleReviewOverlayController.gd
  BattleMatchEndController.gd

scripts/ui/battle/ai/
  BattleAiOpponentFactory.gd
  BattleAiTurnController.gd
  BattleLlmWaitHudController.gd
  BattleAdviceServiceController.gd
  BattleDiscussionController.gd
  BattleReviewGenerationController.gd

scripts/ui/battle/replay/
  BattleReplayState.gd
  BattleReplayController.gd

scripts/ui/battle/recording/
  BattleRecordingState.gd
  BattleRecordingController.gd
  BattleRuntimeLogController.gd
```

迁移时不要求一次性搬目录。可以先保留原文件路径，等模块稳定后再移动目录并更新 preload。

## 风险和控制

### 风险：测试过度依赖私有方法

控制：

- Phase 1 保留 wrapper。
- 每迁移一个私有方法，先改测试调用新 controller，再删 wrapper。

### 风险：Godot signal 绑定和 `.tscn` 节点路径被破坏

控制：

- 第一轮不改 `.tscn` 节点树。
- refs 的 `bind_from_scene()` 只查找节点，不移动节点、不改 parent。
- 涉及 reparent 的布局逻辑在 layout phase 单独处理。

### 风险：横竖屏布局互相回退

控制：

- 所有竖屏尺寸从 `content_rect` 派生。
- 横屏 layout presenter 不读竖屏 state。
- 每次 layout 改动同时跑 portrait 和 landscape smoke。

### 风险：迁移时夹带行为修复导致难定位

控制：

- 每个 phase 的提交只做结构迁移。
- 行为 bug 单独提交，且要有明确回归测试。

### 风险：controller 继续膨胀

控制：

- 超过 800 行必须写拆分计划。
- 一个 controller 只能有一个业务名词，例如 hand、field、prize、prompt、ai turn。
- 同时包含 service、state、overlay、layout 的 controller 必须拆。

## 完成定义

整体重构完成时需要满足：

- `BattleScene.gd` 降到 1800 行以下。
- `BattleScene.gd` 中剩余函数以生命周期、信号转发、controller 初始化为主。
- `BattleSceneRefs` 持有主要 UI 节点引用，`BattleScene.gd` 不再有大段 `@onready`。
- 所有主要运行态字段迁入 state 对象。
- `scripts/ui/battle` 中除兼容 adapter 外，不再有 `scene.get("_")`、`scene.set("_")`、`scene.call("_")`。
- 横屏、竖屏、回放、AI、奖赏、结算、effect interaction 测试通过。
- 手动 smoke 清单通过。

## 推荐第一步

不要直接从 11211 行里搬最大函数。第一步应该做 Phase 1：

1. 扩展 `BattleSceneRefs`，把节点引用边界建立起来。
2. 新增 `BattleSceneContext` 和第一批 state。
3. `BattleScene._ready()` 只负责组装这些对象。
4. 旧 controller 继续跑，新的迁移从 context 开始。

这样可以先把后续所有迁移的“落点”搭好，避免继续制造更多依赖完整 scene 的 controller。
