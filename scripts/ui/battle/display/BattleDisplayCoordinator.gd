class_name BattleDisplayCoordinator
extends RefCounted

var context: RefCounted = null
var legacy_display_controller: RefCounted = null
var legacy_scene: Node = null


func setup(next_context: RefCounted, next_legacy_controller: RefCounted, next_legacy_scene: Node) -> void:
	context = next_context
	legacy_display_controller = next_legacy_controller
	legacy_scene = next_legacy_scene


func is_configured() -> bool:
	return legacy_display_controller != null and legacy_scene != null


func refresh_all() -> void:
	if not is_configured():
		return
	legacy_display_controller.call("refresh_ui", legacy_scene)


func refresh_hand() -> void:
	if not is_configured():
		return
	legacy_display_controller.call("refresh_hand", legacy_scene)


func refresh_field() -> void:
	if not is_configured():
		return
	if context == null:
		return
	var gsm: Variant = context.get("gsm")
	if gsm == null or gsm.game_state == null:
		return
	legacy_display_controller.call("refresh_field_card_views", legacy_scene, gsm.game_state)


func show_discard_pile(player_index: int, title: String) -> void:
	if not is_configured():
		return
	legacy_display_controller.call("show_discard_pile", legacy_scene, player_index, title)


func show_lost_zone(player_index: int, title: String) -> void:
	if not is_configured():
		return
	legacy_display_controller.call("show_lost_zone", legacy_scene, player_index, title)
