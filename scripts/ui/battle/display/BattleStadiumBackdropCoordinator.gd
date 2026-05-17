class_name BattleStadiumBackdropCoordinator
extends RefCounted

const STADIUM_BACKGROUND_MAP_PATH := "res://data/stadium_backgrounds.json"
const PAGE_TURN_SECONDS := 0.36

var _scene: Node = null
var _background_map: Dictionary = {}
var _last_target_path: String = ""
var _last_state_key: String = ""
var _fade_tween: Tween = null
var _fade_overlay: Control = null


func setup(scene: Node) -> void:
	_scene = scene
	if _background_map.is_empty():
		_background_map = _load_background_map()


func sync_stadium_backdrop(gs: GameState, immediate: bool = false) -> void:
	if _scene == null or not is_instance_valid(_scene):
		return
	var base_path := _base_backdrop_path()
	var stadium_card: CardInstance = gs.stadium_card if gs != null else null
	var enabled := bool(GameManager.dynamic_stadium_background_enabled)
	var target_path := base_path
	var stadium_key := "none"
	if enabled and stadium_card != null:
		stadium_key = _stadium_identity_key(stadium_card)
		target_path = resolve_stadium_backdrop_path(stadium_card, base_path)
	var state_key := "%s|%s|%s" % [str(enabled), stadium_key, target_path]
	if state_key == _last_state_key:
		return
	_last_state_key = state_key
	_apply_backdrop_path(target_path, immediate)


func resolve_stadium_backdrop_path(stadium_card: CardInstance, default_path: String) -> String:
	if stadium_card == null or stadium_card.card_data == null:
		return default_path
	if _background_map.is_empty():
		_background_map = _load_background_map()
	var card_data: CardData = stadium_card.card_data
	var candidate := _mapped_path("by_effect_id", str(card_data.effect_id))
	if candidate == "":
		candidate = _mapped_path("by_card_id", _card_id(card_data))
	if candidate == "":
		candidate = _mapped_path("by_name_en", str(card_data.name_en))
	if candidate == "":
		candidate = _mapped_path("by_name", str(card_data.name))
	if candidate == "":
		return default_path
	return candidate if _texture_path_exists(candidate) else default_path


func reset_cache_for_tests() -> void:
	_last_target_path = ""
	_last_state_key = ""
	_background_map = _load_background_map()


func _base_backdrop_path() -> String:
	if _scene != null and _scene.has_method("_resolve_battle_backdrop_path"):
		var resolved: Variant = _scene.call("_resolve_battle_backdrop_path")
		if resolved is String and str(resolved) != "":
			return str(resolved)
	var selected := str(GameManager.selected_battle_background)
	return selected if selected != "" else "res://assets/ui/background.png"


func _apply_backdrop_path(path: String, immediate: bool) -> void:
	var target_path := path if path != "" else _base_backdrop_path()
	if target_path == _last_target_path:
		return
	var backdrop := _backdrop_node()
	if backdrop == null:
		return
	var texture := _load_texture(target_path)
	if texture == null:
		return
	_last_target_path = target_path
	if immediate or not _scene.is_inside_tree() or backdrop.texture == null:
		_clear_fade_overlay()
		backdrop.texture = texture
		return
	_wipe_backdrop(backdrop, texture)


func _wipe_backdrop(backdrop: TextureRect, texture: Texture2D) -> void:
	_clear_fade_overlay()
	var parent := backdrop.get_parent() as Control
	if parent == null:
		backdrop.texture = texture
		return

	var reveal_clip := Control.new()
	reveal_clip.name = "StadiumBackdropPageTurnOverlay"
	reveal_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reveal_clip.clip_contents = true
	reveal_clip.position = backdrop.position
	reveal_clip.size = Vector2(0.0, backdrop.size.y)
	reveal_clip.custom_minimum_size = Vector2.ZERO

	var overlay := TextureRect.new()
	overlay.name = "StadiumBackdropIncomingTexture"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.texture = texture
	overlay.expand_mode = backdrop.expand_mode
	overlay.stretch_mode = backdrop.stretch_mode
	overlay.position = Vector2.ZERO
	overlay.size = backdrop.size
	overlay.modulate.a = 0.98

	var edge_glow := ColorRect.new()
	edge_glow.name = "StadiumBackdropPageTurnEdge"
	edge_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge_glow.color = Color(0.85, 0.95, 1.0, 0.18)
	edge_glow.position = Vector2(0.0, 0.0)
	edge_glow.size = Vector2(18.0, backdrop.size.y)

	reveal_clip.add_child(overlay)
	reveal_clip.add_child(edge_glow)
	parent.add_child(reveal_clip)
	parent.move_child(reveal_clip, backdrop.get_index() + 1)
	_fade_overlay = reveal_clip

	_fade_tween = _scene.create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(reveal_clip, "size:x", backdrop.size.x, PAGE_TURN_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_fade_tween.tween_property(edge_glow, "position:x", max(0.0, backdrop.size.x - edge_glow.size.x), PAGE_TURN_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_fade_tween.tween_property(edge_glow, "color:a", 0.0, PAGE_TURN_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_fade_tween.set_parallel(false)
	_fade_tween.finished.connect(func() -> void:
		if backdrop != null and is_instance_valid(backdrop):
			backdrop.texture = texture
		_clear_fade_overlay()
	)


func _backdrop_node() -> TextureRect:
	if _scene == null or not is_instance_valid(_scene):
		return null
	return _scene.get_node_or_null("BattleBackdrop") as TextureRect


func _clear_fade_overlay() -> void:
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_tween = null
	if _fade_overlay != null and is_instance_valid(_fade_overlay):
		_fade_overlay.queue_free()
	_fade_overlay = null


func _load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		var resource := load(path)
		if resource is Texture2D:
			return resource as Texture2D
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)
	return null


func _texture_path_exists(path: String) -> bool:
	if path == "":
		return false
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


func _mapped_path(section: String, key: String) -> String:
	var normalized_key := key.strip_edges()
	if normalized_key == "":
		return ""
	var section_value: Variant = _background_map.get(section, {})
	if not section_value is Dictionary:
		return ""
	return str((section_value as Dictionary).get(normalized_key, ""))


func _load_background_map() -> Dictionary:
	if not FileAccess.file_exists(STADIUM_BACKGROUND_MAP_PATH):
		return {}
	var file := FileAccess.open(STADIUM_BACKGROUND_MAP_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _stadium_identity_key(stadium_card: CardInstance) -> String:
	if stadium_card == null or stadium_card.card_data == null:
		return "none"
	var card_data: CardData = stadium_card.card_data
	if str(card_data.effect_id) != "":
		return "effect:%s" % str(card_data.effect_id)
	var card_id := _card_id(card_data)
	if card_id != "_":
		return "card:%s" % card_id
	if str(card_data.name_en) != "":
		return "name_en:%s" % str(card_data.name_en)
	return "name:%s" % str(card_data.name)


func _card_id(card_data: CardData) -> String:
	if card_data == null:
		return ""
	return "%s_%s" % [str(card_data.set_code), str(card_data.card_index)]
