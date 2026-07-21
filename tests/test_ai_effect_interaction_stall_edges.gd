class_name TestAIEffectInteractionStallEdges
extends TestBase

const AILegalActionBuilderScript = preload("res://scripts/ai/AILegalActionBuilder.gd")
const AIStepResolverScript = preload("res://scripts/ai/AIStepResolver.gd")
const BattleEffectInteractionControllerScript = preload("res://scripts/ui/battle/BattleEffectInteractionController.gd")
const BattleCardDetailCoordinatorScript = preload("res://scripts/ui/battle/display/BattleCardDetailCoordinator.gd")


class ResolverScene extends Control:
	var _pending_choice: String = "effect_interaction"
	var _pending_effect_steps: Array[Dictionary] = []
	var _pending_effect_step_index: int = 0
	var _pending_effect_context: Dictionary = {}
	var picked_indices := PackedInt32Array()
	var choice_call_count: int = 0
	var chosen_sources: Array[int] = []
	var chosen_targets: Array[int] = []
	var assignment_confirmed: bool = false
	var reset_calls: int = 0
	var refresh_calls: int = 0
	var ai_calls: int = 0
	var logs: Array[String] = []

	func _resolve_effect_step_chooser_player(step: Dictionary) -> int:
		return int(step.get("chooser_player_index", 0))

	func _effect_step_uses_counter_distribution_ui(_step: Dictionary) -> bool:
		return false

	func _effect_step_uses_field_assignment_ui(_step: Dictionary) -> bool:
		return false

	func _effect_step_uses_field_slot_ui(_step: Dictionary) -> bool:
		return false

	func _handle_effect_interaction_choice(indices: PackedInt32Array) -> void:
		choice_call_count += 1
		picked_indices = indices

	func _on_assignment_source_chosen(source_index: int) -> void:
		chosen_sources.append(source_index)

	func _on_assignment_target_chosen(target_index: int) -> void:
		chosen_targets.append(target_index)

	func _confirm_assignment_dialog() -> void:
		assignment_confirmed = true

	func _runtime_log(event: String, detail: String = "") -> void:
		logs.append("%s:%s" % [event, detail])

	func _reset_effect_interaction() -> void:
		reset_calls += 1
		_pending_choice = ""
		_pending_effect_steps.clear()
		_pending_effect_step_index = -1
		_pending_effect_context.clear()

	func _refresh_ui() -> void:
		refresh_calls += 1

	func _maybe_run_ai() -> void:
		ai_calls += 1


class FailingInteractionGSM extends RefCounted:
	var play_trainer_calls: int = 0

	func play_trainer(_player_index: int, _card: CardInstance, _targets: Array) -> bool:
		play_trainer_calls += 1
		return false


class FinishScene extends RefCounted:
	var _gsm: Variant = null
	var _pending_choice: String = "effect_interaction"
	var _pending_effect_kind: String = "trainer"
	var _pending_effect_player_index: int = 0
	var _pending_effect_card: CardInstance = null
	var _pending_effect_slot: PokemonSlot = null
	var _pending_effect_ability_index: int = -1
	var _pending_effect_attack_data: Dictionary = {}
	var _pending_effect_attack_effects: Array[BaseEffect] = []
	var _pending_effect_steps: Array[Dictionary] = []
	var _pending_effect_step_index: int = 0
	var _pending_effect_context: Dictionary = {}
	var _coin_animation_resume_effect_step: bool = false
	var _dialog_data: Dictionary = {}
	var _dialog_items_data: Array = []
	var _dialog_multi_selected_indices: Array[int] = []
	var _dialog_card_selected_indices: Array[int] = []
	var _dialog_overlay: Panel = null
	var refresh_calls: int = 0
	var ai_calls: int = 0
	var modal_finished: int = 0
	var logged_messages: Array[String] = []

	func _runtime_log(_event: String, _detail: String = "") -> void:
		pass

	func _effect_state_snapshot() -> String:
		return ""

	func _state_snapshot() -> String:
		return ""

	func _is_field_interaction_active() -> bool:
		return false

	func _hide_field_interaction() -> void:
		pass

	func _finish_modal_input_interaction(_reason: String = "", _slot_suppression_mode: String = "", _origin_position: Vector2 = Vector2(-1, -1)) -> void:
		modal_finished += 1

	func _reset_dialog_assignment_state() -> void:
		pass

	func _bt(key: String, _params: Dictionary = {}) -> String:
		return key

	func _log(message: String) -> void:
		logged_messages.append(message)

	func _refresh_ui() -> void:
		refresh_calls += 1

	func _get_trainer_followup_evolve_slot() -> PokemonSlot:
		return null

	func _mark_ready_vfx_action_source(_player_index: int, _action_kind: String = "") -> void:
		pass

	func _restore_pending_engine_prize_choice_if_needed(_reason: String = "") -> void:
		pass

	func _check_two_player_handover() -> void:
		pass

	func _maybe_run_ai() -> void:
		ai_calls += 1


class CoinWaitScene extends RefCounted:
	var _pending_choice: String = ""
	var _pending_effect_kind: String = "trainer"
	var _pending_effect_card: CardInstance = null
	var _pending_effect_steps: Array[Dictionary] = []
	var _pending_effect_step_index: int = 0
	var _pending_effect_context: Dictionary = {}
	var delay_calls: int = 0
	var dialog_calls: int = 0

	func _runtime_log(_event: String, _detail: String = "") -> void:
		pass

	func _state_snapshot() -> String:
		return ""

	func _has_pending_coin_animation() -> bool:
		return true

	func _delay_effect_step_until_coin_animation_finishes() -> void:
		delay_calls += 1
		_pending_choice = "effect_interaction"

	func _resolve_effect_step_chooser_player(step: Dictionary) -> int:
		return int(step.get("chooser_player_index", 0))

	func _effect_step_uses_counter_distribution_ui(_step: Dictionary) -> bool:
		return false

	func _effect_step_uses_field_assignment_ui(_step: Dictionary) -> bool:
		return false

	func _effect_step_uses_field_slot_ui(_step: Dictionary) -> bool:
		return false

	func _dialog_item_has_card_visual(_item: Variant) -> bool:
		return false

	func _show_dialog(_title: String, _items: Array, _extra_data: Dictionary = {}) -> void:
		dialog_calls += 1

	func _show_field_counter_distribution(_step: Dictionary) -> void:
		dialog_calls += 1

	func _show_field_assignment_interaction(_step: Dictionary) -> void:
		dialog_calls += 1

	func _show_field_slot_choice(_title: String, _items: Array, _data: Dictionary = {}) -> void:
		dialog_calls += 1


class DetailResumeScene extends Node:
	var _detail_overlay: Control = null
	var _detail_action_bar: HBoxContainer = null
	var _detail_use_btn: Button = null
	var _detail_cancel_btn: Button = null
	var _detail_hand_action_card: CardInstance = null
	var _detail_mode: String = "readonly"
	var _detail_reveal_tween: Tween = null
	var ai_calls: int = 0

	func _maybe_run_ai() -> void:
		ai_calls += 1


func _make_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	return gsm


func _make_card_data(name: String, card_type: String = "Item") -> CardData:
	var card_data := CardData.new()
	card_data.name = name
	card_data.card_type = card_type
	return card_data


func test_headless_builder_rejects_required_dialog_step_with_too_few_items() -> String:
	var builder = AILegalActionBuilderScript.new()
	var resolved: Variant = builder.call("_resolve_headless_step", _make_gsm(), 0, 0, {
		"id": "discard_cards",
		"items": ["only_card"],
		"min_select": 2,
		"max_select": 2,
	})
	return assert_null(resolved,
		"Headless builder should not auto-resolve a mandatory dialog step when fewer legal items exist than min_select")


func test_step_resolver_does_not_treat_required_empty_dialog_as_resolved() -> String:
	var resolver = AIStepResolverScript.new()
	var scene := ResolverScene.new()
	scene._pending_effect_steps = [{
		"id": "mandatory_empty",
		"items": [],
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
		"chooser_player_index": 0,
	}]
	var resolved: bool = resolver.resolve_pending_step(scene, _make_gsm(), 0, [])
	return run_checks([
		assert_true(resolved, "AI resolver should handle an impossible mandatory prompt by clearing it"),
		assert_eq(scene.choice_call_count, 0, "AI resolver should not call the effect interaction handler with an empty choice for min_select=1"),
		assert_eq(str(scene._pending_choice), "", "The stale impossible prompt should be cleared so AI can continue"),
		assert_eq(scene.reset_calls, 1, "Impossible mandatory prompts should reset the effect interaction state"),
		assert_eq(scene.refresh_calls, 1, "Impossible mandatory prompts should refresh the visible state after reset"),
		assert_eq(scene.ai_calls, 1, "Impossible mandatory prompts should schedule the next AI step"),
	])


func test_step_resolver_reports_required_assignment_without_targets_as_unresolved() -> String:
	var resolver = AIStepResolverScript.new()
	var scene := ResolverScene.new()
	scene._pending_effect_steps = [{
		"id": "energy_assignments",
		"ui_mode": "card_assignment",
		"source_items": ["energy"],
		"target_items": [],
		"min_select": 1,
		"max_select": 1,
		"chooser_player_index": 0,
	}]
	var resolved: bool = resolver.resolve_pending_step(scene, _make_gsm(), 0, [])
	return run_checks([
		assert_true(resolved, "Required assignment prompts with no legal targets should be cleared as unresolvable"),
		assert_eq(scene.chosen_sources.size(), 0, "Resolver should not choose a source when no target can accept it"),
		assert_eq(scene.chosen_targets.size(), 0, "Resolver should not synthesize an invalid target assignment"),
		assert_false(scene.assignment_confirmed, "Resolver should not confirm an impossible required assignment"),
		assert_eq(str(scene._pending_choice), "", "Unresolvable assignment prompts should not remain pending forever"),
		assert_eq(scene.reset_calls, 1, "Unresolvable assignment prompts should reset the effect interaction state"),
		assert_eq(scene.ai_calls, 1, "Unresolvable assignment prompts should schedule the next AI step"),
	])


func test_coin_animation_gate_defers_effect_step_until_animation_finishes() -> String:
	var scene := CoinWaitScene.new()
	scene._pending_effect_card = CardInstance.create(_make_card_data("Coin Card"), 0)
	scene._pending_effect_steps = [{
		"id": "coin_target",
		"items": ["target"],
		"min_select": 1,
		"max_select": 1,
		"wait_for_coin_animation": true,
		"chooser_player_index": 0,
	}]
	var controller := BattleEffectInteractionControllerScript.new()
	controller.call("show_next_effect_interaction_step", scene)
	return run_checks([
		assert_eq(scene.delay_calls, 1, "Coin-gated effect steps should defer while a coin animation is pending"),
		assert_eq(scene.dialog_calls, 0, "Coin-gated effect steps should not render the choice dialog before the animation is cleared"),
		assert_eq(str(scene._pending_choice), "effect_interaction", "Coin-gated deferral should keep the effect prompt pending"),
		assert_eq(scene._pending_effect_step_index, 0, "Coin-gated deferral should not advance the step index"),
	])


func test_failed_effect_interaction_reschedules_ai_after_reset() -> String:
	var controller := BattleEffectInteractionControllerScript.new()
	var scene := FinishScene.new()
	var gsm := FailingInteractionGSM.new()
	scene._gsm = gsm
	scene._pending_effect_card = CardInstance.create(_make_card_data("Broken Search"), 0)
	scene._pending_effect_steps = [{
		"id": "mandatory_empty",
		"items": [],
		"min_select": 1,
		"max_select": 1,
	}]
	scene._pending_effect_context = {"mandatory_empty": []}
	controller.call("_finish_effect_interaction", scene)
	return run_checks([
		assert_eq(gsm.play_trainer_calls, 1, "The fixture should attempt to execute the pending trainer interaction"),
		assert_eq(scene.refresh_calls, 1, "Failed effect interactions should still refresh the battle UI"),
		assert_eq(str(scene._pending_choice), "", "Failed effect interactions should clear the stale effect prompt"),
		assert_eq(scene.ai_calls, 1, "After clearing a failed AI-owned effect interaction, the scene should schedule the next AI step instead of idling"),
	])


func test_closing_card_detail_resumes_ai_after_mamoswine_ability_pause_race() -> String:
	var coordinator := BattleCardDetailCoordinatorScript.new()
	var scene := DetailResumeScene.new()
	var detail_overlay := Panel.new()
	detail_overlay.visible = true
	scene._detail_overlay = detail_overlay
	scene.add_child(detail_overlay)
	coordinator.setup(scene)

	coordinator.hide_card_detail()
	var result := run_checks([
		assert_false(detail_overlay.visible, "Closing the inspected card should remove the UI blocker"),
		assert_eq(scene.ai_calls, 1, "Closing card detail after the AI pause expires must re-check AI scheduling"),
	])
	scene.free()
	return result
