class_name BattleRuntimeLogController
extends RefCounted

const BATTLE_RUNTIME_LOG_PATH := "user://logs/battle_runtime.log"

func init_battle_runtime_log(scene: Object) -> void:
	var logs_dir := ProjectSettings.globalize_path("user://logs")
	DirAccess.make_dir_recursive_absolute(logs_dir)
	var file := FileAccess.open(BATTLE_RUNTIME_LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("BattleScene runtime log init failed: %s" % BATTLE_RUNTIME_LOG_PATH)
		return
	file.store_line("=== Battle Runtime Log %s ===" % Time.get_datetime_string_from_system())
	file.close()
	runtime_log(scene, "session_start", "scene=%s mode=%s" % [(scene as Node).name, str(GameManager.current_mode)])


func runtime_log(scene: Object, event: String, detail: String = "") -> void:
	var timestamp := Time.get_datetime_string_from_system()
	var line := "[%s] %s" % [timestamp, event]
	if detail != "":
		line += " | %s" % detail
	var file := FileAccess.open(BATTLE_RUNTIME_LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(line)
	file.close()


func runtime_log_ui_state_if_changed(scene: Object) -> void:
	var signature := state_snapshot(scene)
	if signature == str(scene.get("_last_ui_state_signature")):
		return
	scene.set("_last_ui_state_signature", signature)
	runtime_log(scene, "ui_state", signature)


func state_snapshot(scene: Object) -> String:
	var gsm: Variant = scene.get("_gsm")
	if gsm == null:
		return "gsm=null pending=%s overlays=%s" % [str(scene.get("_pending_choice")), overlay_snapshot(scene)]
	var gs: GameState = gsm.game_state
	var view_player: int = int(scene.get("_view_player"))
	return "phase=%d turn=%d current=%d view=%d pending=%s selected=%s hand=%d/%d overlays=%s effect=%s" % [
		gs.phase,
		gs.turn_number,
		gs.current_player_index,
		view_player,
		str(scene.get("_pending_choice")),
		card_instance_label(scene.get("_selected_hand_card")),
		gs.players[view_player].hand.size() if view_player < gs.players.size() else -1,
		gs.players[1 - view_player].hand.size() if gs.players.size() > 1 else -1,
		overlay_snapshot(scene),
		effect_state_snapshot(scene),
	]


func dialog_state_snapshot(scene: Object) -> String:
	var dialog_overlay: Panel = scene.get("_dialog_overlay")
	var dialog_cancel: Button = scene.get("_dialog_cancel")
	return "dialog=%s pending=%s card_mode=%s assignment_mode=%s selected_cards=%s selected_list=%s assignments=%d allow_cancel=%s" % [
		str(dialog_overlay.visible) if dialog_overlay != null else "false",
		str(scene.get("_pending_choice")),
		str(scene.get("_dialog_card_mode")),
		str(scene.get("_dialog_assignment_mode")),
		JSON.stringify(scene.get("_dialog_card_selected_indices")),
		JSON.stringify(scene.get("_dialog_multi_selected_indices")),
		(scene.get("_dialog_assignment_assignments") as Array).size(),
		str(dialog_cancel.visible) if dialog_cancel != null else "false",
	]


func overlay_snapshot(scene: Object) -> String:
	var dialog_overlay: Panel = scene.get("_dialog_overlay")
	var handover_panel: Panel = scene.get("_handover_panel")
	var coin_overlay: Panel = scene.get("_coin_overlay")
	var detail_overlay: Panel = scene.get("_detail_overlay")
	var discard_overlay: Panel = scene.get("_discard_overlay")
	return "dialog=%s handover=%s coin=%s detail=%s discard=%s" % [
		str(dialog_overlay.visible) if dialog_overlay != null else "false",
		str(handover_panel.visible) if handover_panel != null else "false",
		str(coin_overlay.visible) if coin_overlay != null else "false",
		str(detail_overlay.visible) if detail_overlay != null else "false",
		str(discard_overlay.visible) if discard_overlay != null else "false",
	]


func effect_state_snapshot(scene: Object) -> String:
	return "kind=%s player=%d step=%d/%d card=%s ctx_keys=%d" % [
		str(scene.get("_pending_effect_kind")),
		int(scene.get("_pending_effect_player_index")),
		int(scene.get("_pending_effect_step_index")),
		(scene.get("_pending_effect_steps") as Array).size(),
		card_instance_label(scene.get("_pending_effect_card")),
		(scene.get("_pending_effect_context") as Dictionary).size(),
	]


func card_instance_label(card: CardInstance) -> String:
	if card == null:
		return "-"
	if card.card_data == null:
		return "null-data#%d" % card.instance_id
	return "%s#%d" % [card.card_data.name, card.instance_id]
