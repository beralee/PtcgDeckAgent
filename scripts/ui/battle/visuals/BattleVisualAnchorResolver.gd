class_name BattleVisualAnchorResolver
extends RefCounted

const OverlayGeometry := preload("res://scripts/ui/battle/BattleOverlayGeometry.gd")


static func resolve_rect_in_overlay(
	scene: Object,
	overlay: Control,
	anchor_key: String,
	view_player_override: int = -1
) -> Rect2:
	if scene == null or overlay == null:
		return Rect2()
	var control := _resolve_control(scene, anchor_key, view_player_override)
	if control != null and is_instance_valid(control) and control.is_visible_in_tree():
		var rect := OverlayGeometry.control_rect_in_overlay(overlay, control)
		if rect.size.x > 1.0 and rect.size.y > 1.0:
			return rect
	return scene_rect_in_overlay(scene, overlay)


static func scene_rect_in_overlay(scene: Object, overlay: Control) -> Rect2:
	if scene is Control and overlay != null:
		return OverlayGeometry.control_rect_in_overlay(overlay, scene as Control)
	return Rect2(Vector2.ZERO, Vector2(1600, 900))


static func _resolve_control(scene: Object, anchor_key: String, view_player_override: int = -1) -> Control:
	if anchor_key == "":
		return scene as Control
	if anchor_key == "stadium":
		var stadium: Control = scene.get("_stadium_card_view") as Control
		return stadium if stadium != null else _find(scene, "StadiumCenter")
	var parsed := _parse_player_zone(anchor_key)
	if parsed.is_empty():
		return _find(scene, anchor_key)
	var player_index := int(parsed.get("player_index", -1))
	var rest := str(parsed.get("rest", ""))
	var view_player := view_player_override if view_player_override >= 0 else int(scene.get("_view_player"))
	var mine := player_index == view_player
	if rest == "deck":
		return scene.get("_my_deck_preview" if mine else "_opp_deck_preview") as Control
	if rest == "discard":
		return scene.get("_my_discard_preview" if mine else "_opp_discard_preview") as Control
	if rest == "hand":
		if mine:
			return scene.get("_hand_container") as Control
		var opponent_hand_bar := scene.get("_opp_hand_bar") as Control
		if opponent_hand_bar != null and opponent_hand_bar.is_visible_in_tree():
			return opponent_hand_bar
		return scene.get("_opp_hand_lbl") as Control
	if rest == "lost":
		return scene.get("_my_lost_value" if mine else "_enemy_lost_value") as Control
	if rest.begins_with("prize."):
		var prize_index := int(rest.get_slice(".", 1))
		if scene.has_method("_get_prize_slot_view"):
			var prize_slot := scene.call("_get_prize_slot_view", player_index, prize_index) as Control
			if prize_slot != null and prize_slot.is_visible_in_tree():
				return prize_slot
		return scene.get("_my_prize_hud_count" if mine else "_opp_prize_hud_count") as Control
	if rest == "active" or rest.begins_with("active."):
		return _slot_control(scene, "my_active" if mine else "opp_active")
	if rest.begins_with("bench."):
		var bench_index := int(rest.get_slice(".", 1))
		return _slot_control(scene, "%s_bench_%d" % ["my" if mine else "opp", bench_index])
	return scene as Control


static func _slot_control(scene: Object, slot_id: String) -> Control:
	var views_variant: Variant = scene.get("_slot_card_views")
	if views_variant is Dictionary:
		var view: Control = (views_variant as Dictionary).get(slot_id, null) as Control
		if view != null:
			return view
	var node_name := ""
	if slot_id == "my_active":
		node_name = "MyActive"
	elif slot_id == "opp_active":
		node_name = "OppActive"
	elif slot_id.begins_with("my_bench_"):
		node_name = "MyBench%d" % int(slot_id.get_slice("_", 2))
	elif slot_id.begins_with("opp_bench_"):
		node_name = "OppBench%d" % int(slot_id.get_slice("_", 2))
	return _find(scene, node_name)


static func _parse_player_zone(anchor_key: String) -> Dictionary:
	if anchor_key.length() < 4 or not anchor_key.begins_with("p"):
		return {}
	var dot := anchor_key.find(".")
	if dot <= 1:
		return {}
	var player_token := anchor_key.substr(1, dot - 1)
	if not player_token.is_valid_int():
		return {}
	var rest := anchor_key.substr(dot + 1)
	if rest.ends_with(".stack") or rest.ends_with(".energy") or rest.ends_with(".tool"):
		rest = rest.get_slice(".", 0) if rest.begins_with("active") else "%s.%s" % [rest.get_slice(".", 0), rest.get_slice(".", 1)]
	return {"player_index": int(player_token), "rest": rest}


static func _find(scene: Object, node_name: String) -> Control:
	if node_name == "" or not scene is Node:
		return null
	return (scene as Node).find_child(node_name, true, false) as Control
