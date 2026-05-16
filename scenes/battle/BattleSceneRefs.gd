class_name BattleSceneRefs
extends RefCounted

var root: Control = null

var log_list: RichTextLabel = null
var log_title: Label = null
var phase_label: Label = null
var turn_label: Label = null

var top_bar: Control = null
var end_turn_button: Button = null
var hud_end_turn_button: Button = null
var back_button: Button = null
var ai_advice_button: Button = null
var battle_discuss_ai_button: Button = null
var attack_vfx_preview_button: Button = null
var opponent_hand_button: Button = null
var zeus_help_button: Button = null
var battle_layout_button: Button = null
var battle_more_button: Button = null

var replay_prev_turn_button: Button = null
var replay_next_turn_button: Button = null
var replay_continue_button: Button = null
var replay_back_to_list_button: Button = null

var left_panel: Control = null
var right_panel: Control = null
var opponent_active_slot: Control = null
var player_active_slot: Control = null
var opponent_bench: Control = null
var player_bench: Control = null

var hand_scroll: ScrollContainer = null
var hand_container: Control = null

var dialog_overlay: Control = null
var dialog_panel: Control = null
var dialog_title: Label = null
var dialog_confirm_button: Button = null
var dialog_cancel_button: Button = null

var handover_overlay: Control = null
var detail_overlay: Control = null
var discard_overlay: Control = null
var review_overlay: Control = null
var review_title: Label = null
var review_content: RichTextLabel = null
var review_regenerate_button: Button = null


func bind_from_scene(scene: Node) -> void:
	root = scene as Control

	log_list = _find(scene, "LogList") as RichTextLabel
	log_title = _find(scene, "LogTitle") as Label
	phase_label = _find(scene, "LblPhase") as Label
	turn_label = _find(scene, "LblTurn") as Label

	top_bar = _find(scene, "TopBar") as Control
	end_turn_button = _find(scene, "BtnEndTurn") as Button
	hud_end_turn_button = _find(scene, "HudEndTurnBtn") as Button
	back_button = _find(scene, "BtnBack") as Button
	ai_advice_button = _find(scene, "BtnAiAdvice") as Button
	battle_discuss_ai_button = _find(scene, "BtnBattleDiscussAI") as Button
	attack_vfx_preview_button = _find(scene, "BtnAttackVfxPreview") as Button
	opponent_hand_button = _find(scene, "BtnOpponentHand") as Button
	zeus_help_button = _find(scene, "BtnZeusHelp") as Button
	battle_layout_button = _find(scene, "BtnBattleLayout") as Button
	battle_more_button = _find(scene, "BtnBattleMore") as Button

	bind_replay_buttons(
		_find(scene, "BtnReplayPrevTurn") as Button,
		_find(scene, "BtnReplayNextTurn") as Button,
		_find(scene, "BtnReplayContinue") as Button,
		_find(scene, "BtnReplayBackToList") as Button
	)

	left_panel = _find(scene, "LeftPanel") as Control
	right_panel = _find(scene, "RightPanel") as Control
	opponent_active_slot = _find(scene, "OppActive") as Control
	player_active_slot = _find(scene, "MyActive") as Control
	opponent_bench = _find(scene, "OppBench") as Control
	player_bench = _find(scene, "MyBench") as Control

	hand_scroll = _find(scene, "HandScroll") as ScrollContainer
	hand_container = _find(scene, "HandContainer") as Control

	dialog_overlay = _find(scene, "DialogOverlay") as Control
	dialog_panel = _find(scene, "DialogBox") as Control
	dialog_title = _find(scene, "DialogTitle") as Label
	dialog_confirm_button = _find(scene, "DialogConfirm") as Button
	dialog_cancel_button = _find(scene, "DialogCancel") as Button

	handover_overlay = _find(scene, "HandoverPanel") as Control
	detail_overlay = _find(scene, "DetailOverlay") as Control
	discard_overlay = _find(scene, "DiscardOverlay") as Control
	review_overlay = _find(scene, "ReviewOverlay") as Control
	review_title = _find(scene, "ReviewTitle") as Label
	review_content = _find(scene, "ReviewContent") as RichTextLabel
	review_regenerate_button = _find(scene, "ReviewRegenerateBtn") as Button


func bind_replay_buttons(
	prev_turn_button: Button,
	next_turn_button: Button,
	continue_button: Button,
	back_to_list_button: Button
) -> void:
	replay_prev_turn_button = prev_turn_button
	replay_next_turn_button = next_turn_button
	replay_continue_button = continue_button
	replay_back_to_list_button = back_to_list_button


func replay_buttons() -> Array[Button]:
	return [
		replay_prev_turn_button,
		replay_next_turn_button,
		replay_continue_button,
		replay_back_to_list_button,
	]


func _find(scene: Node, node_name: String) -> Node:
	if scene == null:
		return null
	if scene.name == node_name:
		return scene
	return scene.find_child(node_name, true, false)
