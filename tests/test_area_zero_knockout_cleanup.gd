class_name TestAreaZeroKnockoutCleanup
extends TestBase

const AreaZeroUnderdepthsScript = preload("res://scripts/effects/stadium_effects/CSV9C207AreaZeroUnderdepths.gd")
const BattleEffectInteractionControllerScript = preload("res://scripts/ui/battle/BattleEffectInteractionController.gd")


class EffectSceneStub extends RefCounted:
	var _gsm: GameStateMachine = null
	var _view_player: int = 0
	var _pending_choice: String = ""
	var _pending_effect_kind: String = ""
	var _pending_effect_player_index: int = -1
	var _pending_effect_card: CardInstance = null
	var _pending_effect_slot: PokemonSlot = null
	var _pending_effect_ability_index: int = -1
	var _pending_effect_attack_data: Dictionary = {}
	var _pending_effect_attack_effects: Array[BaseEffect] = []
	var _pending_effect_steps: Array[Dictionary] = []
	var _pending_effect_step_index: int = -1
	var _pending_effect_context: Dictionary = {}
	var _dialog_data: Dictionary = {}
	var _dialog_items_data: Array = []
	var _dialog_multi_selected_indices: Array[int] = []
	var _dialog_card_selected_indices: Array[int] = []
	var _pending_prize_player_index: int = -1
	var _pending_prize_remaining: int = 0
	var shown_dialog_title: String = ""
	var shown_dialog_items: Array = []
	var shown_dialog_data: Dictionary = {}
	var restore_prize_calls: int = 0
	var refresh_calls: int = 0
	var ai_calls: int = 0
	var logs: Array[String] = []

	func _reset_effect_interaction() -> void:
		_pending_effect_kind = ""
		_pending_effect_player_index = -1
		_pending_effect_card = null
		_pending_effect_slot = null
		_pending_effect_ability_index = -1
		_pending_effect_attack_data.clear()
		_pending_effect_attack_effects.clear()
		_pending_effect_steps.clear()
		_pending_effect_step_index = -1
		_pending_effect_context.clear()
		if _pending_choice == "effect_interaction":
			_pending_choice = ""

	func _runtime_log(event: String, detail: String = "") -> void:
		logs.append("%s:%s" % [event, detail])

	func _bt(key: String, _params: Dictionary = {}) -> String:
		return key

	func _card_instance_label(card: CardInstance) -> String:
		if card == null or card.card_data == null:
			return ""
		return card.card_data.name

	func _has_pending_coin_animation() -> bool:
		return false

	func _delay_effect_step_until_coin_animation_finishes() -> void:
		pass

	func _dialog_item_has_card_visual(item: Variant) -> bool:
		return item is CardInstance or item is CardData or item is PokemonSlot

	func _show_dialog(title: String, items: Array, extra_data: Dictionary = {}) -> void:
		shown_dialog_title = title
		shown_dialog_items = items.duplicate()
		shown_dialog_data = extra_data.duplicate(false)
		_dialog_items_data = items.duplicate()
		_dialog_data = extra_data.duplicate(false)

	func _show_field_slot_choice(_title: String, _items: Array, _data: Dictionary = {}) -> void:
		pass

	func _show_field_assignment_interaction(_step: Dictionary) -> void:
		pass

	func _show_field_counter_distribution(_step: Dictionary) -> void:
		pass

	func _is_field_interaction_active() -> bool:
		return false

	func _hide_field_interaction() -> void:
		pass

	func _finish_modal_input_interaction(_reason: String = "modal", _slot_suppression_mode: String = "arm", _origin_position: Vector2 = Vector2(-1.0, -1.0)) -> void:
		pass

	func _reset_dialog_assignment_state() -> void:
		pass

	func _get_trainer_followup_evolve_slot() -> PokemonSlot:
		return null

	func _mark_ready_vfx_action_source(_player_index: int, _action_kind: String = "") -> void:
		pass

	func _restore_pending_engine_prize_choice_if_needed(_reason: String = "") -> void:
		restore_prize_calls += 1
		if _gsm == null:
			return
		var prize_player := int(_gsm.get("_pending_prize_player_index"))
		var remaining := int(_gsm.get("_pending_prize_remaining"))
		if prize_player >= 0 and remaining > 0:
			_pending_choice = "take_prize"
			_pending_prize_player_index = prize_player
			_pending_prize_remaining = remaining

	func _refresh_ui() -> void:
		refresh_calls += 1

	func _check_two_player_handover() -> void:
		pass

	func _maybe_run_ai() -> void:
		ai_calls += 1

	func _state_snapshot() -> String:
		return ""

	func _effect_state_snapshot() -> String:
		return ""

	func _log(message: String) -> void:
		logs.append(message)


func _make_gsm() -> GameStateMachine:
	CardInstance.reset_id_counter()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.POKEMON_CHECK
	gsm.game_state.current_player_index = 1
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 6
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	gsm.game_state.players[0].player_index = 0
	gsm.game_state.players[1].player_index = 1
	return gsm


func _make_pokemon_card(name: String, owner: int, hp: int = 80, mechanic: String = "", tags: PackedStringArray = PackedStringArray()) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	card.energy_type = "C"
	card.mechanic = mechanic
	card.is_tags = tags
	return CardInstance.create(card, owner)


func _make_item_card(name: String, owner: int) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Item"
	return CardInstance.create(card, owner)


func _make_stadium_card(owner: int) -> CardInstance:
	var card := CardData.new()
	card.name = "Area Zero Underdepths"
	card.card_type = "Stadium"
	card.effect_id = AreaZeroUnderdepthsScript.EFFECT_ID
	return CardInstance.create(card, owner)


func _make_slot(card: CardInstance) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	return slot


func _seed_area_zero_unique_tera_knockout(gsm: GameStateMachine) -> Dictionary:
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var ai_player: PlayerState = state.players[1]

	var tera_active := _make_slot(_make_pokemon_card("Only Tera ex", 0, 230, "ex", PackedStringArray(["Tera"])))
	tera_active.damage_counters = 230
	player.active_pokemon = tera_active
	player.bench.clear()
	for i: int in 6:
		player.bench.append(_make_slot(_make_pokemon_card("Bench %d" % i, 0, 90)))
	player.deck.append(_make_item_card("Player Draw", 0))
	player.set_prizes([
		_make_item_card("Player Prize A", 0),
		_make_item_card("Player Prize B", 0),
		_make_item_card("Player Prize C", 0),
	])

	ai_player.active_pokemon = _make_slot(_make_pokemon_card("AI Active", 1, 120))
	ai_player.bench.clear()
	ai_player.deck.append(_make_item_card("AI Draw", 1))
	ai_player.set_prizes([
		_make_item_card("Prize A", 1),
		_make_item_card("Prize B", 1),
		_make_item_card("Prize C", 1),
	])

	state.stadium_card = _make_stadium_card(0)
	state.stadium_owner_index = 0
	return {
		"tera_active": tera_active,
		"discard_candidate": player.bench[0],
		"replacement": player.bench[1],
	}


func test_unique_tera_ko_requests_area_zero_cleanup_before_ai_prizes() -> String:
	var gsm := _make_gsm()
	var fixture := _seed_area_zero_unique_tera_knockout(gsm)
	var prompts: Array[Dictionary] = []
	gsm.player_choice_required.connect(func(choice_type: String, data: Dictionary) -> void:
		prompts.append({"type": choice_type, "data": data.duplicate(false)})
	)

	gsm.call("_check_all_knockouts")
	var first_prompt: Dictionary = prompts[0] if not prompts.is_empty() else {}
	var first_data: Dictionary = first_prompt.get("data", {})
	var cleanup_steps: Array = first_data.get("steps", [])
	var first_step: Dictionary = cleanup_steps[0] if not cleanup_steps.is_empty() else {}
	var selected_slot: PokemonSlot = fixture["discard_candidate"]
	var cleanup_context := {
		str(first_step.get("id", "")): [selected_slot],
	}
	var cleanup_ok := gsm.enforce_current_bench_limits("test_cleanup", 0, "", -1, [cleanup_context])
	var second_prompt: Dictionary = prompts[1] if prompts.size() > 1 else {}

	return run_checks([
		assert_eq(str(first_prompt.get("type", "")), "bench_limit_cleanup", "Unique Tera KO under Area Zero must ask the knocked-out player to trim Bench before prizes"),
		assert_eq(int(first_data.get("player", -1)), 0, "Cleanup should start from the knocked-out player's side in this fixture"),
		assert_eq(cleanup_steps.size(), 1, "Only the player who lost the sole Tera should need Bench cleanup"),
		assert_eq(str(first_step.get("id", "")), "csv9c207_zero_area_discard_p0", "Cleanup step should target player 0's Area Zero discard choice"),
		assert_eq(int(first_step.get("chooser_player_index", -1)), 0, "The discard choice must belong to player 0, not the AI taking prizes"),
		assert_eq(int(first_step.get("min_select", 0)), 1, "Six Bench Pokemon after losing Tera should force exactly one discard"),
		assert_eq(int(first_step.get("max_select", 0)), 1, "Six Bench Pokemon after losing Tera should force exactly one discard"),
		assert_false(bool(first_step.get("allow_cancel", true)), "Area Zero cleanup is mandatory and should not be cancellable"),
		assert_true(cleanup_ok, "Supplying the selected Bench slot should resolve Area Zero cleanup"),
		assert_false(selected_slot in gsm.game_state.players[0].bench, "The selected Bench Pokemon should be discarded"),
		assert_eq(gsm.game_state.players[0].bench.size(), 5, "Bench should be trimmed back to five Pokemon"),
		assert_eq(str(second_prompt.get("type", "")), "take_prize", "After cleanup, flow should resume into the AI prize prompt"),
		assert_eq(int(second_prompt.get("data", {}).get("player", -1)), 1, "The AI should be the prize-taking player"),
		assert_eq(int(second_prompt.get("data", {}).get("count", 0)), 2, "Knocking out a Tera ex should ask for two prizes"),
		assert_eq(int(gsm.get("_pending_prize_player_index")), 1, "Engine should be waiting on AI prize selection after cleanup"),
	])


func test_battle_effect_controller_can_select_area_zero_cleanup_without_source_card() -> String:
	var gsm := _make_gsm()
	var fixture := _seed_area_zero_unique_tera_knockout(gsm)
	var prompts: Array[Dictionary] = []
	gsm.player_choice_required.connect(func(choice_type: String, data: Dictionary) -> void:
		prompts.append({"type": choice_type, "data": data.duplicate(false)})
	)

	gsm.call("_check_all_knockouts")
	var first_prompt: Dictionary = prompts[0] if not prompts.is_empty() else {}
	var cleanup_steps: Array[Dictionary] = []
	for step_variant: Variant in first_prompt.get("data", {}).get("steps", []):
		if step_variant is Dictionary:
			cleanup_steps.append(step_variant as Dictionary)

	var scene := EffectSceneStub.new()
	scene._gsm = gsm
	var controller := BattleEffectInteractionControllerScript.new()
	controller.call("start_effect_interaction", scene, "bench_limit_cleanup", 0, cleanup_steps, null)
	var pending_after_start := scene._pending_choice
	var dialog_card_items: Array = scene.shown_dialog_data.get("card_items", [])
	var dialog_first_item: Variant = dialog_card_items[0] if not dialog_card_items.is_empty() else null

	controller.call("handle_effect_interaction_choice", scene, PackedInt32Array([0]))
	var pending_after_cleanup := scene._pending_choice
	var prize_player_after_cleanup := scene._pending_prize_player_index
	var prize_remaining_after_cleanup := scene._pending_prize_remaining
	var first_prize_ok := gsm.resolve_take_prize(1, 0)
	var second_prize_ok := gsm.resolve_take_prize(1, 1)
	var send_out_ok := gsm.send_out_pokemon(0, fixture["replacement"])

	return run_checks([
		assert_eq(pending_after_start, "effect_interaction", "Starting Area Zero cleanup with a null source card should still open an effect interaction"),
		assert_eq(str(scene.shown_dialog_data.get("presentation", "")), "cards", "Area Zero cleanup should render Bench Pokemon as selectable cards"),
		assert_true(dialog_first_item is PokemonSlot, "The cleanup dialog should expose PokemonSlot items for selection"),
		assert_eq(int(scene.shown_dialog_data.get("min_select", 0)), 1, "The dialog should require the excess Bench count"),
		assert_false(bool(scene.shown_dialog_data.get("allow_cancel", true)), "The dialog should preserve mandatory cleanup semantics"),
		assert_eq(pending_after_cleanup, "take_prize", "Completing cleanup should restore the pending engine prize prompt instead of losing UI state"),
		assert_eq(prize_player_after_cleanup, 1, "Restored prize prompt should belong to the AI prize taker"),
		assert_eq(prize_remaining_after_cleanup, 2, "Restored prize prompt should keep the two-prize count"),
		assert_eq(scene.restore_prize_calls, 1, "Effect completion should explicitly bridge back to the engine prize prompt"),
		assert_false(fixture["discard_candidate"] in gsm.game_state.players[0].bench, "The clicked Bench Pokemon should be the one discarded"),
		assert_true(first_prize_ok, "AI should be able to take the first prize after cleanup"),
		assert_true(second_prize_ok, "AI should be able to take the second prize after cleanup"),
		assert_true(send_out_ok, "Player 0 should be able to send out a replacement after AI prizes"),
		assert_eq(gsm.game_state.players[0].active_pokemon, fixture["replacement"], "The replacement should become active after the full chain resolves"),
		assert_eq(gsm.game_state.phase, GameState.GamePhase.MAIN, "After cleanup, prizes, and send-out, the battle should return to MAIN"),
	])
