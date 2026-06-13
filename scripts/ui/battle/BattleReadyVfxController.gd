class_name BattleReadyVfxController
extends RefCounted


const OVERLAY_NAME := "ReadyVfxOverlay"
const SEQUENCE_NAME := "ReadyVfxSequence"
const BURST_NAME := "ReadyVfxBurst"
const FLASH_NAME := "ReadyVfxFlash"
const BattleReadyVfxRegistryScript := preload("res://scripts/ui/battle/BattleReadyVfxRegistry.gd")

var _texture_cache: Dictionary = {}


func ensure_overlay(scene: Object) -> Control:
	var overlay: Control = scene.get("_ready_vfx_overlay") as Control
	if overlay != null and is_instance_valid(overlay):
		return overlay
	overlay = Control.new()
	overlay.name = OVERLAY_NAME
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 205
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var host := _overlay_host(scene)
	if host != null:
		host.add_child(overlay)
	scene.set("_ready_vfx_overlay", overlay)
	return overlay


func play_ready_vfx(scene: Object, trigger: Dictionary) -> void:
	if scene == null or trigger.is_empty():
		return
	var overlay := ensure_overlay(scene)
	if overlay == null:
		return
	var registry: RefCounted = scene.get("_battle_ready_vfx_registry") as RefCounted
	if registry == null:
		registry = BattleReadyVfxRegistryScript.new()
		scene.set("_battle_ready_vfx_registry", registry)
	var profile: RefCounted = registry.call("resolve_profile_for_trigger", trigger)
	if profile == null:
		return
	var target_anchor := _target_slot_anchor(
		scene,
		int(trigger.get("player_index", int(scene.get("_view_player")))),
		str(trigger.get("slot_kind", "active")),
		int(trigger.get("slot_index", 0))
	)
	var target_position := _target_position(scene, target_anchor)
	_play_sequence(scene, overlay, profile, target_position, trigger)


func _play_sequence(scene: Object, overlay: Control, profile: RefCounted, target_position: Vector2, trigger: Dictionary) -> void:
	var sequence := Control.new()
	sequence.name = SEQUENCE_NAME
	sequence.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sequence.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sequence.set_meta("ready_vfx_sequence", true)
	sequence.set_meta("ready_vfx_animation_active", false)
	sequence.set_meta("profile_id", str(profile.get("profile_id")))
	sequence.set_meta("rule_id", str(trigger.get("rule_id", "")))
	sequence.set_meta("ready_key", str(trigger.get("ready_key", "")))
	overlay.visible = true
	overlay.add_child(sequence)

	var local_position := _overlay_local_position(overlay, target_position)
	var asset_specs: Dictionary = profile.get("asset_specs") if profile != null else {}
	var burst_spec: Dictionary = asset_specs.get("burst", {})
	var layout_metrics := _resolve_profile_layout_metrics(profile, _overlay_layout_size(scene, overlay))
	var effect_size: Vector2 = layout_metrics.get("effect_size", Vector2(200.0, 200.0))
	var anchor_offset: Vector2 = layout_metrics.get("anchor_offset", Vector2.ZERO)
	sequence.set_meta("ready_vfx_duration", float(layout_metrics.get("duration", 0.0)))
	sequence.set_meta("ready_vfx_hold_ratio", float(layout_metrics.get("hold_ratio", 0.0)))
	sequence.set_meta("ready_vfx_effect_size", effect_size)
	sequence.set_meta("ready_vfx_anchor_offset", anchor_offset)
	sequence.set_meta("ready_vfx_portrait", bool(layout_metrics.get("is_portrait", false)))
	var burst := _make_grid_flipbook_texture_layer(BURST_NAME, burst_spec, effect_size)
	if burst != null:
		burst.position = local_position + anchor_offset - burst.size * 0.5
		var start_scale := float(layout_metrics.get("start_scale", 0.62))
		burst.scale = Vector2(start_scale, start_scale)
		burst.pivot_offset = burst.size * 0.5
		sequence.add_child(burst)
	if bool(profile.get("flash_enabled")):
		sequence.add_child(_make_flash_node(profile))

	if scene is Node and (scene as Node).is_inside_tree():
		_play_sequence_animation(scene as Node, sequence, profile, layout_metrics)


func _make_grid_flipbook_texture_layer(name: String, spec: Dictionary, size: Vector2) -> TextureRect:
	if spec.is_empty():
		return null
	var resource_path := str(spec.get("path", ""))
	if resource_path == "":
		return null
	var texture := _load_texture(resource_path)
	if texture == null:
		return null
	var rows := maxi(1, int(spec.get("rows", 1)))
	var cols := maxi(1, int(spec.get("cols", int(spec.get("frames", 1)))))
	var frames := maxi(1, int(spec.get("frames", rows * cols)))
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(0.0, 0.0, float(texture.get_width()) / float(cols), float(texture.get_height()) / float(rows))
	var rect := TextureRect.new()
	rect.name = name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture = atlas
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.size = size
	rect.set_meta("flipbook_frame_count", frames)
	rect.set_meta("flipbook_rows", rows)
	rect.set_meta("flipbook_cols", cols)
	return rect


func _make_flash_node(profile: RefCounted) -> ColorRect:
	var flash := ColorRect.new()
	flash.name = FLASH_NAME
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = profile.get("flash_color") if profile != null else Color(1.0, 1.0, 1.0, 0.18)
	flash.modulate.a = 0.0
	return flash


func _play_sequence_animation(scene: Node, sequence: Control, profile: RefCounted, layout_metrics: Dictionary = {}) -> void:
	sequence.set_meta("ready_vfx_animation_active", true)
	var duration := maxf(0.12, float(layout_metrics.get("duration", float(profile.get("duration")) if profile != null else 0.7)))
	var peak_scale := float(layout_metrics.get("peak_scale", float(profile.get("peak_scale")) if profile != null else 1.16))
	var hold_scale := float(layout_metrics.get("hold_scale", float(profile.get("hold_scale")) if profile != null else 1.06))
	var end_scale := float(layout_metrics.get("end_scale", float(profile.get("end_scale")) if profile != null else 1.02))
	var hold_ratio := clampf(float(layout_metrics.get("hold_ratio", float(profile.get("hold_ratio")) if profile != null else 0.0)), 0.0, 0.45)
	var flipbook_ratio := clampf(float(layout_metrics.get("flipbook_ratio", float(profile.get("flipbook_ratio")) if profile != null else 0.82)), 0.1, 1.2)
	var burst: TextureRect = sequence.get_node_or_null(BURST_NAME) as TextureRect
	var flash: ColorRect = sequence.get_node_or_null(FLASH_NAME) as ColorRect
	if burst != null:
		_animate_grid_flipbook(scene, burst, duration * flipbook_ratio)
		var burst_tween := scene.create_tween()
		if hold_ratio > 0.0:
			burst_tween.tween_property(burst, "scale", Vector2(peak_scale, peak_scale), duration * 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			burst_tween.parallel().tween_property(burst, "modulate:a", 1.0, duration * 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			burst_tween.tween_property(burst, "scale", Vector2(hold_scale, hold_scale), duration * 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			burst_tween.tween_interval(duration * hold_ratio)
			burst_tween.tween_property(burst, "scale", Vector2(end_scale, end_scale), duration * 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			burst_tween.parallel().tween_property(burst, "modulate:a", 0.0, duration * 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		else:
			burst_tween.tween_property(burst, "scale", Vector2(peak_scale, peak_scale), duration * 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			burst_tween.parallel().tween_property(burst, "modulate:a", 1.0, duration * 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			burst_tween.tween_property(burst, "scale", Vector2(end_scale, end_scale), duration * 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			burst_tween.tween_property(burst, "modulate:a", 0.0, duration * 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if flash != null:
		var flash_tween := scene.create_tween()
		if hold_ratio > 0.0:
			flash_tween.tween_property(flash, "modulate:a", 1.0, duration * 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			flash_tween.tween_property(flash, "modulate:a", 0.16, duration * 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			flash_tween.tween_interval(duration * (0.16 + hold_ratio))
			flash_tween.tween_property(flash, "modulate:a", 0.0, duration * 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		else:
			flash_tween.tween_property(flash, "modulate:a", 1.0, duration * 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			flash_tween.tween_property(flash, "modulate:a", 0.0, duration * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var cleanup_tween := scene.create_tween()
	cleanup_tween.tween_interval(duration + 0.08)
	cleanup_tween.finished.connect(func() -> void:
		if is_instance_valid(sequence):
			sequence.set_meta("ready_vfx_animation_active", false)
			sequence.queue_free()
	)


func _resolve_profile_layout_metrics(profile: RefCounted, viewport_size: Vector2) -> Dictionary:
	var effect_size: Vector2 = profile.get("effect_size") if profile != null else Vector2(200.0, 200.0)
	var anchor_offset: Vector2 = profile.get("anchor_offset") if profile != null else Vector2.ZERO
	var duration := float(profile.get("duration")) if profile != null else 0.7
	var is_portrait := viewport_size.y > viewport_size.x and viewport_size.x > 0.0
	if is_portrait and profile != null:
		var portrait_ratio := float(profile.get("portrait_effect_width_ratio"))
		if portrait_ratio > 0.0:
			var side := viewport_size.x * portrait_ratio
			var min_size := float(profile.get("portrait_effect_min_size"))
			var max_size := float(profile.get("portrait_effect_max_size"))
			if min_size > 0.0:
				side = maxf(side, min_size)
			if max_size > 0.0:
				side = minf(side, max_size)
			effect_size = Vector2(side, side)
		var portrait_duration := float(profile.get("portrait_duration"))
		if portrait_duration > 0.0:
			duration = portrait_duration
		var offset_ratio: Vector2 = profile.get("portrait_anchor_offset_ratio")
		if offset_ratio != Vector2.ZERO:
			anchor_offset += Vector2(effect_size.x * offset_ratio.x, effect_size.y * offset_ratio.y)
	return {
		"effect_size": effect_size,
		"anchor_offset": anchor_offset,
		"duration": duration,
		"start_scale": float(profile.get("start_scale")) if profile != null else 0.62,
		"peak_scale": float(profile.get("peak_scale")) if profile != null else 1.16,
		"hold_scale": float(profile.get("hold_scale")) if profile != null else 1.06,
		"end_scale": float(profile.get("end_scale")) if profile != null else 1.02,
		"hold_ratio": float(profile.get("hold_ratio")) if profile != null else 0.0,
		"flipbook_ratio": float(profile.get("flipbook_ratio")) if profile != null else 0.82,
		"is_portrait": is_portrait,
	}


func _overlay_layout_size(scene: Object, overlay: Control) -> Vector2:
	if overlay != null and overlay.size.x > 1.0 and overlay.size.y > 1.0:
		return overlay.size
	if scene is Control:
		var scene_control := scene as Control
		if scene_control.size.x > 1.0 and scene_control.size.y > 1.0:
			return scene_control.size
	var center_field := _center_field(scene)
	if center_field != null and center_field.size.x > 1.0 and center_field.size.y > 1.0:
		return center_field.size
	return Vector2(1280.0, 720.0)


func _animate_grid_flipbook(scene: Node, texture_rect: TextureRect, duration: float) -> void:
	if texture_rect == null:
		return
	var atlas: AtlasTexture = texture_rect.texture as AtlasTexture
	if atlas == null or atlas.atlas == null:
		return
	var frames := maxi(1, int(texture_rect.get_meta("flipbook_frame_count", 1)))
	var rows := maxi(1, int(texture_rect.get_meta("flipbook_rows", 1)))
	var cols := maxi(1, int(texture_rect.get_meta("flipbook_cols", frames)))
	if frames <= 1:
		return
	var frame_width := float(atlas.atlas.get_width()) / float(cols)
	var frame_height := float(atlas.atlas.get_height()) / float(rows)
	var tween := scene.create_tween()
	for frame_index: int in frames:
		tween.tween_callback(func() -> void:
			if is_instance_valid(texture_rect):
				var current: AtlasTexture = texture_rect.texture as AtlasTexture
				if current != null:
					var col := frame_index % cols
					var row := int(frame_index / cols)
					current.region = Rect2(frame_width * col, frame_height * row, frame_width, frame_height)
		)
		if frame_index < frames - 1:
			tween.tween_interval(duration / float(frames))


func _load_texture(resource_path: String) -> Texture2D:
	if _texture_cache.has(resource_path):
		var cached: Variant = _texture_cache[resource_path]
		if cached is Texture2D:
			return cached as Texture2D
	var texture: Texture2D = load(resource_path) as Texture2D
	if texture != null:
		_texture_cache[resource_path] = texture
	return texture


func _target_position(scene: Object, anchor: Control) -> Vector2:
	if anchor != null:
		return anchor.global_position + anchor.size * 0.5
	var center_field := _center_field(scene)
	if center_field != null:
		return center_field.global_position + center_field.size * 0.5
	return Vector2(640.0, 360.0)


func _target_slot_anchor(scene: Object, player_index: int, slot_kind: String, slot_index: int) -> Control:
	if slot_kind == "active":
		return _target_anchor(scene, player_index)
	if slot_kind == "bench":
		var view_player := int(scene.get("_view_player"))
		var key := "%s_bench_%d" % ["my" if player_index == view_player else "opp", slot_index]
		var slot_views_variant: Variant = scene.get("_slot_card_views")
		var slot_views: Dictionary = slot_views_variant if slot_views_variant is Dictionary else {}
		var slot_view: Variant = slot_views.get(key, null)
		if slot_view is Control:
			return slot_view as Control
	return null


func _target_anchor(scene: Object, player_index: int) -> Control:
	var view_player := int(scene.get("_view_player"))
	if player_index == view_player:
		return scene.get("_my_active") as Control
	return scene.get("_opp_active") as Control


func _overlay_local_position(overlay: Control, global_position: Vector2) -> Vector2:
	return global_position - overlay.global_position


func _overlay_host(scene: Object) -> Node:
	if scene is Node:
		return scene as Node
	return null


func _center_field(scene: Object) -> Control:
	if scene is Node:
		return (scene as Node).get_node_or_null("MainArea/CenterField") as Control
	return null
