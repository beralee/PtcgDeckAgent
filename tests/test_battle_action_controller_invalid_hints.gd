class_name TestBattleActionControllerInvalidHints
extends TestBase

const BattleActionControllerScript := preload("res://scripts/ui/battle/BattleActionController.gd")


class ActionSceneStub:
	extends Node

	var _gsm: GameStateMachine = null
	var _selected_hand_card: CardInstance = null
	var _view_player := 0
	var invalid_hints: Array[Dictionary] = []
	var logs: Array[String] = []
	var refreshed_hand := false

	func _runtime_log(_event: String, _detail: String = "") -> void:
		pass

	func _card_instance_label(card: CardInstance) -> String:
		return card.card_data.name if card != null and card.card_data != null else "<null>"

	func _state_snapshot() -> String:
		return ""

	func _can_accept_live_action() -> bool:
		return true

	func _is_field_interaction_active() -> bool:
		return false

	func _refresh_hand() -> void:
		refreshed_hand = true

	func _log(message: String) -> void:
		logs.append(message)

	func _bt(key: String, params: Dictionary = {}) -> String:
		return BattleI18n.t(key, params)

	func _show_invalid_action_hint(payload: Variant) -> void:
		if payload is Dictionary:
			invalid_hints.append((payload as Dictionary).duplicate(true))
		else:
			invalid_hints.append({"reason": str(payload)})

	func _refresh_ui_after_successful_action(_ability_action: bool = false, _action_player_index: int = -1, _action_kind: String = "") -> void:
		pass

	func _start_effect_interaction(
		_kind: String,
		_player_index: int,
		_steps: Array,
		_card: CardInstance,
		_slot: PokemonSlot = null,
		_ability_index: int = -1
	) -> void:
		pass

	func _maybe_run_ai() -> void:
		pass


func _make_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 2
	state.first_player_index = 0
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		state.players.append(player)
	return state


func _make_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	return gsm


func _make_card(name: String, card_type: String, owner: int = 0) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = card_type
	return CardInstance.create(data, owner)


func test_blocked_supporter_click_shows_invalid_hint() -> String:
	var controller := BattleActionControllerScript.new()
	var scene := ActionSceneStub.new()
	scene._gsm = _make_gsm()
	scene._gsm.game_state.supporter_used_this_turn = true
	var card := _make_card("博士的研究", "Supporter")
	scene._gsm.game_state.players[0].hand = [card]

	controller.on_hand_card_clicked(scene, card, null)

	return run_checks([
		assert_eq(scene.invalid_hints.size(), 1, "Blocked Supporter should show invalid action HUD"),
		assert_str_contains(str(scene.invalid_hints[0].get("reason", "")), "支援者", "Supporter hint should explain Supporter rule"),
		assert_eq(scene._selected_hand_card, null, "Blocked Supporter should not become selected"),
	])


func test_blocked_item_click_shows_invalid_hint() -> String:
	var controller := BattleActionControllerScript.new()
	var scene := ActionSceneStub.new()
	scene._gsm = _make_gsm()
	scene._gsm.game_state.shared_turn_flags["item_lock_0"] = scene._gsm.game_state.turn_number
	var card := _make_card("巢穴球", "Item")
	scene._gsm.game_state.players[0].hand = [card]

	controller.on_hand_card_clicked(scene, card, null)

	return run_checks([
		assert_eq(scene.invalid_hints.size(), 1, "Blocked Item should show invalid action HUD"),
		assert_str_contains(str(scene.invalid_hints[0].get("reason", "")), "物品", "Item hint should mention Item lock"),
	])


func test_blocked_stadium_click_shows_invalid_hint() -> String:
	var controller := BattleActionControllerScript.new()
	var scene := ActionSceneStub.new()
	scene._gsm = _make_gsm()
	var active_stadium := _make_card("零之大空洞", "Stadium")
	var incoming_stadium := _make_card("零之大空洞", "Stadium")
	scene._gsm.game_state.stadium_card = active_stadium
	scene._gsm.game_state.players[0].hand = [incoming_stadium]

	controller.on_hand_card_clicked(scene, incoming_stadium, null)

	return run_checks([
		assert_eq(scene.invalid_hints.size(), 1, "Blocked Stadium should show invalid action HUD"),
		assert_str_contains(str(scene.invalid_hints[0].get("reason", "")), "竞技场", "Stadium hint should mention Stadium"),
	])
