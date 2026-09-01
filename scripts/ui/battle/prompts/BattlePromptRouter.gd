class_name BattlePromptRouter
extends RefCounted

const SETUP_PREFIXES := ["setup_active_", "setup_bench_"]
const AuthorLiveSeamScript = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorLiveSeam.gd")

var context: RefCounted = null
var _author_live_seam: Variant = null


func setup(next_context: RefCounted) -> void:
	context = next_context


func configure_author_live_canary(seam: Variant) -> bool:
	if seam == null:
		_author_live_seam = null
		return true
	if (
		seam.get_script() != AuthorLiveSeamScript
		or not seam.validate_integrity()
		or not seam.has_method("is_bound_owner_ready")
		or not seam.is_bound_owner_ready()
	):
		return false
	_author_live_seam = seam
	return true


func can_route_author_setup_active(mode: int, player_index: int) -> bool:
	return (
		mode == GameManager.GameMode.VS_AUTHOR_STRATEGY_AI
		and player_index == 1
		and _author_live_seam != null
		and _author_live_seam.get_script() == AuthorLiveSeamScript
		and _author_live_seam.validate_integrity()
		and _author_live_seam.is_bound_owner_ready()
	)


func pending_choice() -> String:
	var dialog_state := _dialog_state()
	return str(dialog_state.get("pending_choice")) if dialog_state != null else ""


func classify_choice(choice: String) -> String:
	if choice in ["attack", "pokemon_action", "retreat_energy", "retreat_bench"]:
		return "battle_action"
	if choice in ["send_out", "heavy_baton_target", "exp_share_target"]:
		return "replacement"
	if choice == "effect_interaction":
		return "effect"
	if choice == "take_prize":
		return "prize"
	if choice == "game_over":
		return "match_end"
	for prefix: String in SETUP_PREFIXES:
		if choice.begins_with(prefix):
			return "setup"
	return "generic"


func route_choice(selected_indices: PackedInt32Array, legacy_handler: Callable) -> void:
	if legacy_handler.is_valid():
		legacy_handler.call(selected_indices)


func _dialog_state() -> RefCounted:
	if context == null or not context.has_method("state"):
		return null
	return context.call("state", "dialog") as RefCounted
