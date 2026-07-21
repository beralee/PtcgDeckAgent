class_name BattleStateFeedbackAnimator
extends RefCounted

const AnchorResolverScript := preload("res://scripts/ui/battle/visuals/BattleVisualAnchorResolver.gd")
const OverlayGeometry := preload("res://scripts/ui/battle/BattleOverlayGeometry.gd")
const EVENT_HARD_LIMIT_SECONDS := 1.5
const PORTRAIT_VISUAL_SCALE := 2.0

var _active_tweens: Array[Tween] = []
var _active_nodes: Array[Control] = []


func handles(event: Dictionary) -> bool:
	return str(event.get("kind", "")) in [
		"damage_delta", "heal_delta", "status_delta", "trigger_pulse",
		"shuffle", "phase_banner", "match_result",
	]


func build_feedback_plan(event: Dictionary) -> Dictionary:
	var kind := str(event.get("kind", ""))
	var style := ""
	var duration := 0.48
	var color := Color.WHITE
	var text := ""
	match kind:
		"damage_delta":
			style = "damage"
			color = Color("ff655f")
			text = "-%d" % int(event.get("amount", 0))
			duration = 0.58
		"heal_delta":
			style = "heal"
			color = Color("60df91")
			text = "+%d" % int(event.get("amount", 0))
			duration = 0.58
		"status_delta":
			style = "status"
			color = _status_color(str(event.get("status", "")))
			text = _status_label(str(event.get("status", "")), bool(event.get("active", true)))
			duration = 0.62
		"trigger_pulse":
			style = "trigger"
			color = _trigger_color(str(event.get("semantic", "")))
			text = str(event.get("label", ""))
			if text == "":
				text = _semantic_label(str(event.get("semantic", "")))
			duration = 0.68
		"shuffle":
			style = "shuffle"
			color = Color("8dd7ff")
			text = "洗牌"
			duration = 0.72
		"phase_banner":
			style = "phase"
			color = Color("f4d47b")
			text = _phase_label(event)
			duration = 0.62
		"match_result":
			style = "result"
			color = Color("ffd66b")
			text = _result_label(event)
			duration = 1.10
	return {
		"style": style,
		"duration": minf(duration, EVENT_HARD_LIMIT_SECONDS),
		"color": color,
		"text": text,
	}


func play_event(scene: Object, event: Dictionary, completed: Callable) -> void:
	if scene == null or not scene is Control or not (scene as Node).is_inside_tree():
		_complete(completed)
		return
	var plan := build_feedback_plan(event)
	if str(plan.get("style", "")) == "":
		_complete(completed)
		return
	match str(plan.get("style", "")):
		"damage", "heal", "status":
			_play_floating_feedback(scene, event, plan, completed)
		"trigger":
			_play_trigger_feedback(scene, event, plan, completed)
		"shuffle":
			_play_shuffle_feedback(scene, event, plan, completed)
		"phase":
			_play_banner(scene, event, plan, completed, false)
		"result":
			_play_banner(scene, event, plan, completed, true)
		_:
			_complete(completed)


func cancel_all() -> void:
	for tween: Tween in _active_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_active_tweens.clear()
	for node: Control in _active_nodes:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_active_nodes.clear()


func visual_metric_scale(scene: Object) -> float:
	if scene != null and scene.has_method("_is_portrait_battle_layout_active"):
		return PORTRAIT_VISUAL_SCALE if bool(scene.call("_is_portrait_battle_layout_active")) else 1.0
	if scene is Control:
		var control := scene as Control
		if control.size.y > control.size.x:
			return PORTRAIT_VISUAL_SCALE
	return 1.0


func _play_floating_feedback(scene: Object, event: Dictionary, plan: Dictionary, completed: Callable) -> void:
	var host := scene as Control
	var metric_scale := visual_metric_scale(scene)
	var anchor := AnchorResolverScript.resolve_rect_in_overlay(scene, host, str(event.get("slot_key", "")))
	if anchor.size == Vector2.ZERO:
		anchor = AnchorResolverScript.scene_rect_in_overlay(scene, host)
	var label := _make_label(str(plan.get("text", "")), plan.get("color", Color.WHITE), roundi(28.0 * metric_scale), metric_scale)
	(scene as Control).add_child(label)
	_active_nodes.append(label)
	label.position = anchor.get_center() - label.size * 0.5
	label.scale = Vector2(0.55, 0.55)
	label.pivot_offset = label.size * 0.5
	var tween := (scene as Node).create_tween()
	_active_tweens.append(tween)
	tween.tween_property(label, "scale", Vector2(1.18, 1.18), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - 46.0 * metric_scale, float(plan.get("duration", 0.58)) - 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.24).set_delay(maxf(0.0, float(plan.get("duration", 0.58)) - 0.40))
	tween.finished.connect(Callable(self, "_finish_node").bind(label, completed))


func _play_trigger_feedback(scene: Object, event: Dictionary, plan: Dictionary, completed: Callable) -> void:
	var anchor_key := str(event.get("source_slot_key", ""))
	var host := scene as Control
	var metric_scale := visual_metric_scale(scene)
	var anchor := AnchorResolverScript.resolve_rect_in_overlay(scene, host, anchor_key)
	if anchor.size == Vector2.ZERO:
		anchor = AnchorResolverScript.scene_rect_in_overlay(scene, host)
	var pulse := Panel.new()
	pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pulse.z_index = 280
	pulse.position = anchor.position - Vector2(8, 8) * metric_scale
	pulse.size = anchor.size + Vector2(16, 16) * metric_scale
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.08)
	style.border_color = plan.get("color", Color.WHITE)
	style.set_border_width_all(roundi(4.0 * metric_scale))
	style.set_corner_radius_all(roundi(14.0 * metric_scale))
	pulse.add_theme_stylebox_override("panel", style)
	(scene as Control).add_child(pulse)
	_active_nodes.append(pulse)
	var label := _make_label(str(plan.get("text", "")), plan.get("color", Color.WHITE), roundi(22.0 * metric_scale), metric_scale)
	(scene as Control).add_child(label)
	_active_nodes.append(label)
	label.position = Vector2(anchor.get_center().x - label.size.x * 0.5, anchor.position.y - label.size.y - 10.0 * metric_scale)
	pulse.scale = Vector2(0.84, 0.84)
	pulse.pivot_offset = pulse.size * 0.5
	var tween := (scene as Node).create_tween()
	_active_tweens.append(tween)
	tween.set_parallel(true)
	tween.tween_property(pulse, "scale", Vector2(1.08, 1.08), 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(pulse, "modulate:a", 0.0, float(plan.get("duration", 0.68))).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "position:y", label.position.y - 18.0 * metric_scale, float(plan.get("duration", 0.68)))
	tween.tween_property(label, "modulate:a", 0.0, 0.26).set_delay(maxf(0.0, float(plan.get("duration", 0.68)) - 0.26))
	tween.finished.connect(Callable(self, "_finish_nodes").bind([pulse, label], completed))


func _play_shuffle_feedback(scene: Object, event: Dictionary, plan: Dictionary, completed: Callable) -> void:
	var anchor_key := str(event.get("zone", "p%d.deck" % int(event.get("player_index", 0))))
	var host := scene as Control
	var control: Control = _control_near_rect(scene, host, AnchorResolverScript.resolve_rect_in_overlay(scene, host, anchor_key))
	if control == null:
		_play_trigger_feedback(scene, {"source_slot_key": anchor_key, "semantic": "shuffle", "label": "洗牌"}, plan, completed)
		return
	var original_rotation := control.rotation_degrees
	var original_scale := control.scale
	control.pivot_offset = control.size * 0.5
	var tween := (scene as Node).create_tween()
	_active_tweens.append(tween)
	for angle: float in [6.0, -6.0, 4.0, -4.0, 0.0]:
		tween.tween_property(control, "rotation_degrees", angle, 0.09)
		tween.parallel().tween_property(control, "scale", Vector2(1.05, 1.05) if angle != 0.0 else original_scale, 0.09)
	tween.finished.connect(func() -> void:
		if control != null and is_instance_valid(control):
			control.rotation_degrees = original_rotation
			control.scale = original_scale
		_prune()
		_complete(completed)
	)


func _play_banner(scene: Object, event: Dictionary, plan: Dictionary, completed: Callable, result: bool) -> void:
	var scene_rect := AnchorResolverScript.scene_rect_in_overlay(scene, scene as Control)
	var metric_scale := visual_metric_scale(scene)
	var veil: ColorRect = null
	if result:
		veil = ColorRect.new()
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		veil.z_index = 285
		veil.color = Color(0.02, 0.03, 0.07, 0.0)
		veil.position = scene_rect.position
		veil.size = scene_rect.size
		(scene as Control).add_child(veil)
		_active_nodes.append(veil)
	var label := _make_label(str(plan.get("text", "")), plan.get("color", Color.WHITE), roundi((34.0 if result else 28.0) * metric_scale), metric_scale)
	label.z_index = 290
	(scene as Control).add_child(label)
	_active_nodes.append(label)
	label.position = Vector2(scene_rect.position.x + scene_rect.size.x * 0.5 - label.size.x * 0.5, scene_rect.position.y + scene_rect.size.y * 0.42)
	var start_x := scene_rect.position.x - label.size.x - 20.0
	var target_x := scene_rect.position.x + scene_rect.size.x * 0.5 - label.size.x * 0.5
	label.position.x = start_x
	var tween := (scene as Node).create_tween()
	_active_tweens.append(tween)
	if veil != null:
		tween.parallel().tween_property(veil, "color:a", 0.58, 0.28)
	tween.tween_property(label, "position:x", target_x, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(maxf(0.08, float(plan.get("duration", 0.62)) - 0.48))
	tween.tween_property(label, "modulate:a", 0.0, 0.22)
	if veil != null:
		tween.parallel().tween_property(veil, "color:a", 0.0, 0.22)
	var nodes: Array = [label]
	if veil != null:
		nodes.append(veil)
	tween.finished.connect(Callable(self, "_finish_nodes").bind(nodes, completed))


func _make_label(text: String, color: Color, font_size: int, metric_scale: float = 1.0) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 282
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 0.94))
	label.add_theme_constant_override("outline_size", roundi(7.0 * metric_scale))
	label.reset_size()
	return label


func _control_near_rect(scene: Object, host: Control, rect: Rect2) -> Control:
	if not scene is Node or rect.size == Vector2.ZERO:
		return null
	for property_name: String in ["_my_deck_preview", "_opp_deck_preview"]:
		var control: Control = scene.get(property_name) as Control
		if control != null and OverlayGeometry.control_rect_in_overlay(host, control).get_center().distance_to(rect.get_center()) < 4.0:
			return control
	return null


func _finish_node(node: Control, completed: Callable) -> void:
	_finish_nodes([node], completed)


func _finish_nodes(nodes: Array, completed: Callable) -> void:
	for node_variant: Variant in nodes:
		var node: Control = node_variant as Control
		if node != null and is_instance_valid(node):
			node.queue_free()
		_active_nodes.erase(node)
	_prune()
	_complete(completed)


func _prune() -> void:
	var alive: Array[Tween] = []
	for tween: Tween in _active_tweens:
		if tween != null and tween.is_valid() and tween.is_running():
			alive.append(tween)
	_active_tweens = alive


func _status_color(status: String) -> Color:
	match status:
		"poisoned": return Color("bd75ff")
		"burned": return Color("ff8a54")
		"asleep": return Color("8fb4ff")
		"paralyzed": return Color("ffe36b")
		"confused": return Color("f18dff")
	return Color("d7e4f3")


func _status_label(status: String, active: bool) -> String:
	var names := {"poisoned": "中毒", "burned": "灼伤", "asleep": "睡眠", "paralyzed": "麻痹", "confused": "混乱"}
	return "%s%s" % [str(names.get(status, status)), "" if active else "解除"]


func _trigger_color(semantic: String) -> Color:
	if semantic == "trainer_play": return Color("f2cb71")
	if semantic.begins_with("stadium"): return Color("79dfa2")
	return Color("7fc9ff")


func _semantic_label(semantic: String) -> String:
	var labels := {"trainer_play": "使用训练家", "ability": "特性发动", "stadium": "竞技场发动", "stadium_play": "竞技场更替", "shuffle": "洗牌"}
	return str(labels.get(semantic, semantic))


func _phase_label(event: Dictionary) -> String:
	match str(event.get("semantic", "")):
		"turn_start": return "我方回合" if int(event.get("player_index", -1)) == int(event.get("view_player", 0)) else "对方回合"
		"turn_end": return "回合结束"
		"pokemon_check": return "宝可梦检查"
	return "阶段变更"


func _result_label(event: Dictionary) -> String:
	var winner := int(event.get("winner_index", -1))
	var reason := str(event.get("reason", ""))
	var reason_labels := {"all_prizes_taken": "拿完奖赏卡", "deck_out": "牌库耗尽", "no_pokemon": "场上无宝可梦"}
	return "%s · %s" % ["胜利" if winner >= 0 else "对局结束", str(reason_labels.get(reason, reason))]


func _complete(completed: Callable) -> void:
	if completed.is_valid():
		completed.call()
