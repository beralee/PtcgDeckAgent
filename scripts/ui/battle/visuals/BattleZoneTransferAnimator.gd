class_name BattleZoneTransferAnimator
extends RefCounted

const BattleCardViewScript := preload("res://scenes/battle/BattleCardView.gd")
const AnchorResolverScript := preload("res://scripts/ui/battle/visuals/BattleVisualAnchorResolver.gd")

const OVERLAY_NAME := "BattleVisualTransferOverlay"
const MAX_VISIBLE_CARDS := 5
const EVENT_HARD_LIMIT_SECONDS := 1.5

var _active_tweens: Array[Tween] = []
var _active_overlays: Array[Control] = []


func handles(event: Dictionary) -> bool:
	return str(event.get("kind", "")) in ["zone_transfer", "stack_change", "field_move"]


func build_motion_plan(event: Dictionary, viewport_size: Vector2, portrait: bool) -> Dictionary:
	var semantic := str(event.get("semantic", "zone_transfer"))
	var count := maxi(1, int(event.get("count", (event.get("card_instance_ids", []) as Array).size())))
	var visible_count := mini(3 if portrait else MAX_VISIBLE_CARDS, count)
	var phases: Array[Dictionary] = []
	match semantic:
		"trainer_play":
			phases = [_phase("present", 0.30), _phase("resolve", 0.20), _phase("travel", 0.34), _phase("settle", 0.12)]
		"evolve":
			phases = [_phase("present", 0.20), _phase("compress_base", 0.14), _phase("land", 0.30), _phase("pulse", 0.16)]
		"rare_candy":
			phases = [_phase("trainer_present", 0.20), _phase("skip_stage", 0.18), _phase("land", 0.30), _phase("pulse", 0.16)]
		"attach_energy", "move_energy":
			phases = [_phase("lift", 0.12), _phase("arc", 0.30), _phase("attribute_pulse", 0.16)]
		"discard_energy":
			phases = [_phase("detach", 0.12), _phase("arc", 0.28), _phase("settle", 0.10)]
		"knockout":
			phases = [_phase("ko_sweep", 0.20), _phase("group_lift", 0.12), _phase("arc", 0.34), _phase("settle", 0.10)]
		"take_prize":
			phases = [_phase("lift", 0.14), _phase("flip_if_allowed", 0.16), _phase("arc", 0.30), _phase("settle", 0.10)]
		"search":
			phases = [_phase("fan", 0.22), _phase("select", 0.20), _phase("arc", 0.30), _phase("collect", 0.16)]
		"mill":
			phases = [_phase("peel", 0.12), _phase("staggered_arc", 0.34), _phase("settle", 0.10)]
		"lost_zone":
			phases = [_phase("lift", 0.12), _phase("purple_arc", 0.32), _phase("dissolve", 0.16)]
		"hand_reset":
			phases = [_phase("collect_backs", 0.20), _phase("arc", 0.30), _phase("deck_absorb", 0.14)]
		"draw", "redraw":
			phases = [_phase("peel", 0.10), _phase("staggered_arc", 0.30), _phase("fan_settle", 0.14)]
		"play_pokemon":
			phases = [_phase("lift", 0.12), _phase("arc", 0.30), _phase("bench_pulse", 0.16)]
		"attach_tool":
			phases = [_phase("lift", 0.12), _phase("arc", 0.28), _phase("tool_pulse", 0.14)]
		_:
			phases = [_phase("lift", 0.12), _phase("arc", 0.30), _phase("settle", 0.12)]
	var total := 0.0
	for phase: Dictionary in phases:
		total += float(phase.get("duration", 0.0))
	return {
		"semantic": semantic,
		"phases": phases,
		"visible_card_count": visible_count,
		"hidden_count": maxi(0, count - visible_count),
		"portrait": portrait,
		"fan_axis": "vertical" if portrait else "horizontal",
		"card_scale": clampf(minf(viewport_size.x / 1600.0, viewport_size.y / 900.0), 0.72, 1.15),
		"total_duration": minf(total, EVENT_HARD_LIMIT_SECONDS),
	}


func play_event(scene: Object, event: Dictionary, completed: Callable) -> void:
	if scene == null or not scene is Node or not (scene as Node).is_inside_tree():
		_complete(completed)
		return
	var overlay := _ensure_overlay(scene)
	if overlay == null:
		_complete(completed)
		return
	var scene_rect: Rect2 = AnchorResolverScript.scene_rect_in_overlay(scene, overlay)
	var portrait := scene_rect.size.y > scene_rect.size.x
	var plan := build_motion_plan(event, scene_rect.size, portrait)
	_active_overlays.append(overlay)
	var anchor_keys := resolve_anchor_keys(event)
	var source_key := str(anchor_keys.get("source", ""))
	var target_key := str(anchor_keys.get("target", ""))
	var event_view_player := int(event.get("view_player", scene.get("_view_player")))
	var source_rect := AnchorResolverScript.resolve_rect_in_overlay(scene, overlay, source_key, event_view_player)
	var target_rect := AnchorResolverScript.resolve_rect_in_overlay(scene, overlay, target_key, event_view_player)
	var fallback_rect := AnchorResolverScript.scene_rect_in_overlay(scene, overlay)
	if source_rect.size == Vector2.ZERO:
		source_rect = Rect2(fallback_rect.get_center() - Vector2(42, 59), Vector2(84, 118))
	if target_rect.size == Vector2.ZERO:
		target_rect = Rect2(fallback_rect.get_center() - Vector2(42, 59), Vector2(84, 118))
	var cards_variant: Variant = event.get("cards", [])
	var cards: Array = cards_variant if cards_variant is Array else []
	var visible_count := int(plan.get("visible_card_count", 1))
	visible_count = maxi(1, mini(visible_count, MAX_VISIBLE_CARDS))
	var motion_card_size := resolve_motion_card_size(
		scene,
		source_rect,
		target_rect,
		portrait,
		str(event.get("semantic", "")),
		visible_count
	)
	var moving_views: Array[BattleCardView] = []
	for index: int in range(visible_count):
		var card: CardInstance = cards[index] as CardInstance if index < cards.size() else null
		var view := _create_card_view(scene, event, card, motion_card_size)
		overlay.add_child(view)
		var start := _fanned_position(source_rect, view.size, index, visible_count, portrait)
		view.position = start
		moving_views.append(view)
	if moving_views.is_empty():
		_cleanup_overlay(overlay)
		_complete(completed)
		return
	_add_batch_badge(overlay, moving_views.back(), int(plan.get("hidden_count", 0)), portrait)
	var shared := {"remaining": moving_views.size(), "completed": false}
	var travel_duration := minf(0.78, maxf(0.36, float(plan.get("total_duration", 0.60)) - 0.12))
	var semantic := str(event.get("semantic", ""))
	_add_semantic_accent(scene, overlay, source_rect, target_rect, semantic)
	for index: int in range(moving_views.size()):
		var view: BattleCardView = moving_views[index]
		var local_start := view.position
		var local_end := _fanned_position(target_rect, view.size, index, moving_views.size(), portrait)
		if str(event.get("semantic", "")) == "trainer_play":
			local_end = target_rect.get_center() - view.size * 0.5
		var lift := minf(120.0, maxf(44.0, local_start.distance_to(local_end) * 0.20))
		var control := (local_start + local_end) * 0.5 + Vector2(0.0, -lift if local_end.y >= local_start.y else lift)
		var tween := (scene as Node).create_tween()
		_active_tweens.append(tween)
		if index > 0:
			tween.tween_interval(float(index) * 0.035)
		view.pivot_offset = view.size * 0.5
		view.scale = Vector2(0.92, 0.92)
		if semantic == "trainer_play":
			var center := fallback_rect.get_center() - view.size * 0.5
			var first_control := (local_start + center) * 0.5 + Vector2(0, -70)
			var first_motion := tween.tween_method(
				Callable(self, "_apply_bezier").bind(view, local_start, first_control, center),
				0.0,
				1.0,
				0.26
			)
			first_motion.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(view, "scale", Vector2(1.22, 1.22), 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_interval(0.24)
			var second_control := (center + local_end) * 0.5 + Vector2(0, -54)
			var second_motion := tween.tween_method(
				Callable(self, "_apply_bezier").bind(view, center, second_control, local_end),
				0.0,
				1.0,
				0.28
			)
			second_motion.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		else:
			var motion := tween.tween_method(
				Callable(self, "_apply_bezier").bind(view, local_start, control, local_end),
				0.0,
				1.0,
				travel_duration
			)
			motion.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			tween.parallel().tween_property(view, "scale", Vector2(1.08, 1.08), travel_duration * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if semantic == "lost_zone":
			tween.parallel().tween_property(view, "modulate", Color(0.70, 0.42, 1.0, 0.55), 0.26)
		tween.tween_property(view, "scale", Vector2(0.82, 0.82), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(view, "modulate:a", 0.15, 0.16)
		tween.finished.connect(Callable(self, "_on_card_finished").bind(overlay, shared, completed))


func resolve_anchor_keys(event: Dictionary) -> Dictionary:
	var source_key := str(event.get("source_zone", ""))
	if source_key == "":
		source_key = str(event.get("source_slot_key", ""))
	var target_key := str(event.get("target_zone", ""))
	if target_key == "":
		target_key = str(event.get("target_slot_key", ""))
	if str(event.get("kind", "")) == "stack_change":
		# A stack event owns one exact Pokemon slot. Prefer it over a generic
		# zone string so delayed Evolution feedback cannot land elsewhere.
		var exact_target_key := str(event.get("target_slot_key", event.get("slot_key", "")))
		if exact_target_key != "":
			target_key = exact_target_key
	return {"source": source_key, "target": target_key}


func resolve_motion_card_size(
	scene: Object,
	source_rect: Rect2,
	target_rect: Rect2,
	portrait: bool,
	semantic: String = "",
	visible_count: int = 1
) -> Vector2:
	if portrait:
		var field_size_variant: Variant = scene.get("_field_active_card_size") if scene != null else null
		if field_size_variant is Vector2:
			var field_size := field_size_variant as Vector2
			if field_size.x > 1.0 and field_size.y > 1.0:
				if semantic == "":
					return field_size
				var target_height := field_size.y
				if semantic in ["attach_energy", "move_energy", "discard_energy", "attach_tool"]:
					target_height = minf(target_height * 0.58, 168.0)
				elif semantic in ["draw", "redraw", "search", "mill", "hand_reset", "take_prize", "discard"]:
					target_height = minf(target_height * (0.58 if visible_count >= 3 else 0.68), 180.0 if visible_count >= 3 else 210.0)
				else:
					target_height = minf(target_height * 0.82, 240.0)
				target_height = maxf(target_height, 126.0)
				return Vector2(roundf(target_height * 0.716), roundf(target_height))
		var portrait_height := maxf(source_rect.size.y, target_rect.size.y)
		portrait_height = clampf(portrait_height, 170.0, 300.0)
		return Vector2(roundf(portrait_height * 0.716), roundf(portrait_height))
	var target_height := clampf(source_rect.size.y, 96.0, 170.0)
	return Vector2(target_height * 0.716, target_height)


func cancel_all() -> void:
	for tween: Tween in _active_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_active_tweens.clear()
	for overlay: Control in _active_overlays:
		_cleanup_overlay(overlay)
	_active_overlays.clear()


func _create_card_view(scene: Object, event: Dictionary, card: CardInstance, target_size: Vector2) -> BattleCardView:
	var view: BattleCardView = BattleCardViewScript.new()
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.setup_from_instance(card, BattleCardView.MODE_SLOT_BENCH)
	view.set_field_slot_layout_size(target_size)
	view.set_info("", "")
	view.set_compact_preview(true)
	view.custom_minimum_size = target_size
	view.size = target_size
	view.set_clickable(false)
	if str(event.get("visibility", "face")) != "face":
		view.set_face_down(true)
		var owner_index := int(event.get("owner_index", event.get("player_index", -1)))
		var texture: Texture2D = _card_back_texture_for_owner(scene, owner_index)
		if texture != null:
			view.set_back_texture(texture)
	return view


func _card_back_texture_for_owner(scene: Object, owner_index: int) -> Texture2D:
	if scene == null:
		return null
	return scene.get("_player_card_back_texture" if owner_index == 0 else "_opponent_card_back_texture") as Texture2D


func _ensure_overlay(scene: Object) -> Control:
	if not scene is Control:
		return null
	var overlay := Control.new()
	overlay.name = OVERLAY_NAME
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 275
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	(scene as Control).add_child(overlay)
	return overlay


func _fanned_position(rect: Rect2, card_size: Vector2, index: int, count: int, portrait: bool) -> Vector2:
	var center := rect.get_center() - card_size * 0.5
	var offset := (float(index) - float(count - 1) * 0.5) * minf(34.0, (card_size.y if portrait else card_size.x) * 0.34)
	return center + (Vector2(0.0, offset) if portrait else Vector2(offset, 0.0))


func _apply_bezier(value: float, view: Control, start: Vector2, control: Vector2, end: Vector2) -> void:
	if view == null or not is_instance_valid(view):
		return
	var inverse := 1.0 - value
	var local_point := inverse * inverse * start + 2.0 * inverse * value * control + value * value * end
	view.position = local_point
	view.rotation_degrees = sin(value * PI) * (5.0 if end.x >= start.x else -5.0)


func _on_card_finished(overlay: Control, shared: Dictionary, completed: Callable) -> void:
	shared["remaining"] = maxi(0, int(shared.get("remaining", 1)) - 1)
	if int(shared.get("remaining", 0)) > 0 or bool(shared.get("completed", false)):
		return
	shared["completed"] = true
	_cleanup_overlay(overlay)
	_active_overlays.erase(overlay)
	_prune_tweens()
	_complete(completed)


func _add_batch_badge(overlay: Control, card_view: Control, hidden_count: int, portrait: bool) -> void:
	if hidden_count <= 0:
		return
	var badge := Label.new()
	badge.text = "+%d" % hidden_count
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_font_size_override("font_size", 32 if portrait else 18)
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.position = card_view.position + Vector2(card_view.size.x - 18.0, -8.0)
	overlay.add_child(badge)


func _add_semantic_accent(scene: Object, overlay: Control, source_rect: Rect2, target_rect: Rect2, semantic: String) -> void:
	if semantic == "knockout":
		var sweep := ColorRect.new()
		sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sweep.color = Color(1.0, 0.18, 0.16, 0.72)
		sweep.position = source_rect.position + Vector2(-source_rect.size.x * 0.35, source_rect.size.y * 0.44)
		sweep.size = Vector2(source_rect.size.x * 0.45, maxf(5.0, source_rect.size.y * 0.08))
		sweep.rotation_degrees = -12.0
		overlay.add_child(sweep)
		var sweep_tween := (scene as Node).create_tween()
		_active_tweens.append(sweep_tween)
		sweep_tween.tween_property(sweep, "position:x", sweep.position.x + source_rect.size.x * 1.55, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		sweep_tween.parallel().tween_property(sweep, "modulate:a", 0.0, 0.24)
		return
	if semantic not in ["attach_energy", "move_energy", "evolve", "rare_candy", "play_pokemon", "attach_tool", "lost_zone"]:
		return
	var pulse := Panel.new()
	pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pulse.position = target_rect.position - Vector2(7, 7)
	pulse.size = target_rect.size + Vector2(14, 14)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color("9ad7ff")
	if semantic in ["evolve", "rare_candy"]:
		style.border_color = Color("ffe28a")
	elif semantic == "lost_zone":
		style.border_color = Color("b675ff")
	elif semantic == "attach_tool":
		style.border_color = Color("d8e1eb")
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	pulse.add_theme_stylebox_override("panel", style)
	overlay.add_child(pulse)
	pulse.scale = Vector2(0.82, 0.82)
	pulse.pivot_offset = pulse.size * 0.5
	var pulse_tween := (scene as Node).create_tween()
	_active_tweens.append(pulse_tween)
	pulse_tween.tween_property(pulse, "scale", Vector2(1.12, 1.12), 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse_tween.parallel().tween_property(pulse, "modulate:a", 0.0, 0.52).set_delay(0.12)


func _cleanup_overlay(overlay: Control) -> void:
	if overlay == null or not is_instance_valid(overlay):
		return
	overlay.queue_free()


func _prune_tweens() -> void:
	var alive: Array[Tween] = []
	for tween: Tween in _active_tweens:
		if tween != null and tween.is_valid() and tween.is_running():
			alive.append(tween)
	_active_tweens = alive


func _phase(id: String, duration: float) -> Dictionary:
	return {"id": id, "duration": duration}


func _complete(completed: Callable) -> void:
	if completed.is_valid():
		completed.call()
