class_name BattleSceneContext
extends RefCounted

signal request_refresh_ui
signal request_handover(target_player: int)
signal request_match_end(winner_index: int, reason: String)

var refs: BattleSceneRefs = null
var i18n: RefCounted = null
var gsm: GameStateMachine = null
var view_player: int = 0
var battle_mode: String = "live"
var selected_deck_names: Array[String] = []

var _states: Dictionary = {}


func configure(
	next_refs: BattleSceneRefs,
	next_i18n: RefCounted,
	next_gsm: GameStateMachine,
	next_view_player: int = 0,
	next_battle_mode: String = "live"
) -> void:
	refs = next_refs
	i18n = next_i18n
	gsm = next_gsm
	view_player = next_view_player
	battle_mode = next_battle_mode


func set_game_state_machine(next_gsm: GameStateMachine) -> void:
	gsm = next_gsm


func set_view_player(next_view_player: int) -> void:
	view_player = next_view_player


func set_battle_mode(next_battle_mode: String) -> void:
	battle_mode = next_battle_mode


func set_state(key: String, state_value: RefCounted) -> void:
	if key.strip_edges() == "":
		return
	if state_value == null:
		_states.erase(key)
		return
	_states[key] = state_value


func state(key: String) -> RefCounted:
	return _states.get(key, null) as RefCounted


func has_state(key: String) -> bool:
	return _states.has(key)
