class_name BattleOverlayCoordinator
extends RefCounted

var context: RefCounted = null
var legacy_overlay_controller: RefCounted = null
var legacy_scene: Node = null


func setup(next_context: RefCounted, next_legacy_controller: RefCounted, next_legacy_scene: Node) -> void:
	context = next_context
	legacy_overlay_controller = next_legacy_controller
	legacy_scene = next_legacy_scene


func is_configured() -> bool:
	return legacy_overlay_controller != null and legacy_scene != null


func start_prize_selection(player_index: int, count: int) -> void:
	var state := _overlay_state()
	if state != null:
		state.call("start_prize_selection", player_index, count)
	if not is_configured():
		return
	legacy_overlay_controller.call("start_prize_selection", legacy_scene, player_index, count)


func clear_prize_selection() -> void:
	var state := _overlay_state()
	if state != null:
		state.call("clear_prize_selection")
	if not is_configured():
		return
	legacy_overlay_controller.call("clear_prize_selection", legacy_scene)


func refresh_prize_titles() -> void:
	if not is_configured():
		return
	legacy_overlay_controller.call("refresh_prize_titles", legacy_scene)


func update_prize_title(label: Label, player_index: int, default_text: String, is_hud: bool) -> void:
	if not is_configured():
		return
	legacy_overlay_controller.call("update_prize_title", legacy_scene, label, player_index, default_text, is_hud)


func focus_prize_panel(player_index: int) -> void:
	if not is_configured():
		return
	legacy_overlay_controller.call("focus_prize_panel", legacy_scene, player_index)


func show_handover_prompt(target_player: int, follow_up: Callable = Callable()) -> void:
	var state := _overlay_state()
	if state != null:
		state.call("set_handover", target_player, true)
	if not is_configured():
		return
	legacy_overlay_controller.call("show_handover_prompt", legacy_scene, target_player, follow_up)


func check_two_player_handover() -> void:
	if not is_configured():
		return
	legacy_overlay_controller.call("check_two_player_handover", legacy_scene)


func on_handover_confirmed() -> void:
	var state := _overlay_state()
	if state != null:
		state.call("set_handover", -1, false)
	if not is_configured():
		return
	legacy_overlay_controller.call("on_handover_confirmed", legacy_scene)


func show_match_end_screen(winner_index: int, reason: String) -> void:
	var state := _overlay_state()
	if state != null:
		state.call("set_match_end", winner_index, reason)
	if not is_configured():
		return
	legacy_overlay_controller.call("show_match_end_screen", legacy_scene, winner_index, reason)


func build_match_end_stats(winner_index: int, reason: String) -> Dictionary:
	if not is_configured():
		return {}
	var stats_variant: Variant = legacy_overlay_controller.call("build_match_end_stats", legacy_scene, winner_index, reason)
	return stats_variant if stats_variant is Dictionary else {}


func refresh_match_end_screen() -> void:
	if not is_configured():
		return
	legacy_overlay_controller.call("refresh_match_end_screen", legacy_scene)


func refresh_match_end_dialog_if_visible() -> void:
	if not is_configured():
		return
	legacy_overlay_controller.call("refresh_match_end_dialog_if_visible", legacy_scene)


func _overlay_state() -> RefCounted:
	if context == null or not context.has_method("state"):
		return null
	return context.call("state", "overlay") as RefCounted
