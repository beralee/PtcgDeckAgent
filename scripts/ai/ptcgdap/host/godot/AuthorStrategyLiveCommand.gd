class_name AuthorStrategyLiveCommand
extends RefCounted

const GameStateMachineScript = preload("res://scripts/engine/GameStateMachine.gd")
const GameStateScript = preload("res://scripts/data/GameState.gd")
const CardInstanceScript = preload("res://scripts/data/CardInstance.gd")
const SerialRegistryScript = preload("res://scripts/ai/ptcgdap/host/godot/GodotSerialRegistry.gd")
static var _FACTORY_TOKEN: RefCounted = RefCounted.new()

var _gsm: Variant = null
var _registry: Variant = null
var _match_generation := 0
var _chooser_player_index := -1
var _card: Variant = null
var _expected_hand_index := -1
var _expected_card_serial := 0
var _state := "invalid"
var _factory_token: Variant = null


static func create_setup_active(
	gsm: Variant,
	registry: Variant,
	chooser_player_index: Variant,
	card: Variant,
	expected_hand_index: Variant
) -> Dictionary:
	if not _exact_script(gsm, GameStateMachineScript) or not _exact_script(registry, SerialRegistryScript):
		return _error("invalid_live_owner")
	if typeof(chooser_player_index) != TYPE_INT or int(chooser_player_index) not in [0, 1]:
		return _error("invalid_engine_prompt")
	if not _exact_script(card, CardInstanceScript) or typeof(expected_hand_index) != TYPE_INT or int(expected_hand_index) < 0:
		return _error("invalid_engine_prompt")
	var generation: int = registry.get_match_generation()
	var serial: Dictionary = registry.lookup_card(card, generation, chooser_player_index)
	if not bool(serial.get("ok", false)):
		return _error("invalid_engine_prompt")
	var script: GDScript = load("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyLiveCommand.gd")
	var command: Variant = script.new(
		gsm, registry, generation, int(chooser_player_index), card,
		int(expected_hand_index), int(serial.get("serial", 0)), _FACTORY_TOKEN
	)
	if not command.validate_current():
		return _error("invalid_engine_prompt")
	return {"ok": true, "error_code": "", "command": command}


func _init(
	gsm: Variant = null,
	registry: Variant = null,
	generation: int = 0,
	chooser: int = -1,
	card: Variant = null,
	hand_index: int = -1,
	card_serial: int = 0,
	token: Variant = null
) -> void:
	if token != _FACTORY_TOKEN:
		return
	_gsm = gsm
	_registry = registry
	_match_generation = generation
	_chooser_player_index = chooser
	_card = card
	_expected_hand_index = hand_index
	_expected_card_serial = card_serial
	_state = "ready"
	_factory_token = token


func validate_current() -> bool:
	if _factory_token != _FACTORY_TOKEN or _state != "ready":
		return false
	if not _exact_script(_gsm, GameStateMachineScript) or not _exact_script(_registry, SerialRegistryScript):
		return false
	if not _registry.is_open() or _registry.get_match_generation() != _match_generation:
		return false
	if not _exact_script(_card, CardInstanceScript) or _card.card_data == null or not _card.card_data.is_basic_pokemon():
		return false
	var state: Variant = _gsm.game_state
	if not _exact_script(state, GameStateScript) or state.phase not in [GameState.GamePhase.SETUP, GameState.GamePhase.SETUP_PLACE]:
		return false
	if state.players.size() != 2 or _chooser_player_index not in [0, 1]:
		return false
	var player: Variant = state.players[_chooser_player_index]
	if player == null or player.active_pokemon != null:
		return false
	if _expected_hand_index < 0 or _expected_hand_index >= player.hand.size() or player.hand[_expected_hand_index] != _card:
		return false
	var serial: Dictionary = _registry.lookup_card(_card, _match_generation, _chooser_player_index)
	return bool(serial.get("ok", false)) and int(serial.get("serial", 0)) == _expected_card_serial


func execute_once() -> bool:
	if not validate_current():
		return false
	_state = "executing"
	if not bool(_gsm.setup_place_active_pokemon(_chooser_player_index, _card)):
		_state = "rejected"
		return false
	var player: Variant = _gsm.game_state.players[_chooser_player_index]
	if player.active_pokemon == null or player.active_pokemon.get_top_card() != _card or _card in player.hand:
		_state = "rejected"
		return false
	var entity: Dictionary = _registry.begin_pokemon_entity(player.active_pokemon, _chooser_player_index)
	if not bool(entity.get("ok", false)):
		_state = "rejected"
		return false
	_state = "executed"
	return true


func was_executed() -> bool:
	return _state == "executed"


static func _exact_script(value: Variant, expected: GDScript) -> bool:
	return value != null and typeof(value) == TYPE_OBJECT and value.get_script() == expected


static func _error(code: String) -> Dictionary:
	return {"ok": false, "error_code": code, "command": null}
