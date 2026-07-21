class_name CardImageOrProxyView
extends PanelContainer

const NonBattleTouchBridgeScript := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")

const STATUS_LABELS := {
	"queued": "等待下载",
	"downloading": "下载中",
	"failed": "下载失败",
	"stale": "图片异常",
}

var _card: CardData = null
var _entry: Dictionary = {}
var _cache_service: Object = null
var _texture_rect: TextureRect = null
var _proxy_box: VBoxContainer = null
var _uid := ""
var _portrait := false
var _show_download_button := false
var _manual_download_pending := false


static func proxy_lines_for_card(card: CardData, status: String = "") -> PackedStringArray:
	if card == null:
		return PackedStringArray(["代卡", "未知卡牌"])
	return proxy_lines_for_entry(_entry_from_card(card), status)


static func proxy_lines_for_entry(entry: Dictionary, status: String = "") -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("代卡")
	var name := CardData.dictionary_display_name(entry)
	if name == "":
		name = str(entry.get("name_en", entry.get("name", "未知卡牌")))
	lines.append(name)
	var meta := PackedStringArray()
	var card_type := str(entry.get("card_type", "")).strip_edges()
	if card_type != "":
		meta.append(card_type)
	var mechanic := str(entry.get("mechanic", "")).strip_edges()
	if mechanic != "":
		meta.append(mechanic)
	var hp := int(entry.get("hp", 0))
	if hp > 0:
		meta.append("HP %d" % hp)
	var energy := str(entry.get("energy_type", "")).strip_edges()
	if energy != "":
		meta.append(energy)
	if not meta.is_empty():
		lines.append(" | ".join(meta))
	var set_code := str(entry.get("set_code", "")).strip_edges()
	var card_index := str(entry.get("card_index", "")).strip_edges()
	if set_code != "" or card_index != "":
		lines.append("%s %s" % [set_code, card_index])
	var summary := _summary_for_entry(entry)
	if summary != "":
		lines.append(summary)
	if status != "" and status != "missing":
		lines.append(str(STATUS_LABELS.get(status, status)))
	var implementation_status := str(entry.get("implementation_status", "")).strip_edges()
	if implementation_status != "" and implementation_status not in ["implemented", "implemented_by_alias", "generic_supported"]:
		lines.append("规则未实现")
	return lines


func setup_from_card(card: CardData, cache_service: Object = null, options: Dictionary = {}) -> void:
	_card = card
	_entry = _entry_from_card(card)
	_cache_service = cache_service
	_portrait = bool(options.get("portrait", false))
	_show_download_button = bool(options.get("show_download_button", false))
	_manual_download_pending = false
	_uid = card.get_uid() if card != null else ""
	_connect_cache_service()
	_render()


func setup_from_entry(entry: Dictionary, cache_service: Object = null, options: Dictionary = {}) -> void:
	_card = null
	_entry = entry.duplicate(true)
	_cache_service = cache_service
	_portrait = bool(options.get("portrait", false))
	_show_download_button = bool(options.get("show_download_button", false))
	_manual_download_pending = false
	_uid = "%s_%s" % [str(_entry.get("set_code", "")).strip_edges(), str(_entry.get("card_index", "")).strip_edges()]
	_connect_cache_service()
	_render()


func _connect_cache_service() -> void:
	if _cache_service == null or not (_cache_service is Object):
		return
	var service := _cache_service as Object
	if service.has_signal("image_ready"):
		var callable := Callable(self, "_on_cache_image_ready")
		if not service.is_connected("image_ready", callable):
			service.connect("image_ready", callable)
	if service.has_signal("image_failed"):
		var failed_callable := Callable(self, "_on_cache_image_failed")
		if not service.is_connected("image_failed", failed_callable):
			service.connect("image_failed", failed_callable)


func _render() -> void:
	for child: Node in get_children():
		child.queue_free()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _panel_style())
	var image_path := _resolved_image_path()
	if image_path != "":
		_add_texture(image_path)
	else:
		_add_proxy()
		if _show_download_button and _cache_service != null:
			_add_download_button()


func _resolved_image_path() -> String:
	var set_code := str(_entry.get("set_code", "")).strip_edges()
	var card_index := str(_entry.get("card_index", "")).strip_edges()
	if set_code == "" or card_index == "":
		return ""
	if _cache_service != null and _cache_service is Object and (_cache_service as Object).has_method("get_local_path_if_ready"):
		var path := str((_cache_service as Object).call("get_local_path_if_ready", set_code, card_index))
		if path != "":
			return path
	var preferred := ""
	if _card != null:
		preferred = _card.image_local_path
	return CardData.resolve_existing_image_path(CardData.get_image_candidate_paths(set_code, card_index, preferred))


func _status() -> String:
	if _manual_download_pending:
		return "downloading"
	var set_code := str(_entry.get("set_code", "")).strip_edges()
	var card_index := str(_entry.get("card_index", "")).strip_edges()
	if _cache_service != null and _cache_service is Object and (_cache_service as Object).has_method("get_status"):
		return str((_cache_service as Object).call("get_status", set_code, card_index))
	return "missing"


func _add_texture(path: String) -> void:
	_texture_rect = TextureRect.new()
	_texture_rect.name = "CardImageTexture"
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var image := _load_image(path)
	if image != null:
		_texture_rect.texture = ImageTexture.create_from_image(image)
	add_child(_texture_rect)


func _add_proxy() -> void:
	var margin := MarginContainer.new()
	margin.name = "CardProxyMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var pad := 6 if not _portrait else 9
	margin.add_theme_constant_override("margin_left", pad)
	margin.add_theme_constant_override("margin_top", pad)
	margin.add_theme_constant_override("margin_right", pad)
	margin.add_theme_constant_override("margin_bottom", pad)
	add_child(margin)

	_proxy_box = VBoxContainer.new()
	_proxy_box.name = "CardProxyBox"
	_proxy_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_proxy_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_proxy_box.add_theme_constant_override("separation", 3 if not _portrait else 6)
	margin.add_child(_proxy_box)

	var lines := proxy_lines_for_entry(_entry, _status())
	for i: int in lines.size():
		var label := Label.new()
		label.name = "CardProxyLine%d" % i
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = lines[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0, 1.0) if i != 0 else Color(1.0, 0.84, 0.36, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.06, 0.92))
		label.add_theme_constant_override("outline_size", 1)
		label.add_theme_font_size_override("font_size", _font_size_for_line(i))
		_proxy_box.add_child(label)


func _add_download_button() -> void:
	var overlay := Control.new()
	overlay.name = "CardDownloadOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var button := Button.new()
	button.name = "DeckViewCardImageDownloadButton"
	button.tooltip_text = "单独下载这张卡图"
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.anchor_left = 0.06
	button.anchor_top = 1.0
	button.anchor_right = 0.94
	button.anchor_bottom = 1.0
	var button_height := 34.0 if _portrait else 24.0
	button.offset_top = -button_height - 4.0
	button.offset_bottom = -4.0
	button.add_theme_font_size_override("font_size", 15 if _portrait else 10)
	var status := _status()
	button.text = _download_button_text(status)
	button.disabled = status in ["queued", "downloading"]
	button.pressed.connect(_on_download_button_pressed.bind(button))
	NonBattleTouchBridgeScript.bind_button_touch(button)
	overlay.add_child(button)


func _download_button_text(status: String) -> String:
	match status:
		"queued", "downloading":
			return "下载中"
		"failed", "stale":
			return "重试卡图"
		_:
			return "下载卡图"


func _on_download_button_pressed(button: Button) -> void:
	var card := _card
	if card == null:
		var set_code := str(_entry.get("set_code", "")).strip_edges()
		var card_index := str(_entry.get("card_index", "")).strip_edges()
		card = CardDatabase.get_card(set_code, card_index)
	if card == null or _cache_service == null:
		return
	_manual_download_pending = true
	if button != null and is_instance_valid(button):
		button.text = "下载中"
		button.disabled = true
	var options := {
		"priority": 10,
		"reason": "manual_card",
		"allow_remote": true,
	}
	if (_cache_service as Object).has_method("ensure_image_with_options"):
		(_cache_service as Object).call("ensure_image_with_options", card, options)
	else:
		(_cache_service as Object).call("ensure_image", card, 10, "manual_card")


func _font_size_for_line(index: int) -> int:
	if _portrait:
		return [20, 24, 18, 17, 16, 15][mini(index, 5)]
	return [11, 13, 10, 10, 9, 9][mini(index, 5)]


func _on_cache_image_ready(uid: String, _local_path: String) -> void:
	if uid == _uid:
		_manual_download_pending = false
		_render()


func _on_cache_image_failed(uid: String, _reason: String) -> void:
	if uid == _uid:
		_manual_download_pending = false
		_render()


static func _entry_from_card(card: CardData) -> Dictionary:
	if card == null:
		return {}
	var entry := card.to_dict()
	entry["display_name"] = card.display_name()
	entry["uid"] = card.get_uid()
	var status: Dictionary = CardImplementationStatus.get_status(card)
	entry["implementation_status"] = "text_only" if bool(status.get("unimplemented", false)) else "implemented"
	entry["implementation_reason"] = str(status.get("reason", ""))
	return entry


static func _summary_for_entry(entry: Dictionary) -> String:
	var abilities: Array = entry.get("abilities", []) if entry.get("abilities", []) is Array else []
	for raw: Variant in abilities:
		if raw is Dictionary:
			var ability := raw as Dictionary
			var name := CardData.dictionary_display_name(ability)
			var text := CardData.dictionary_display_text(ability)
			return _trim_summary("特性 %s %s" % [name, text])
	var attacks: Array = entry.get("attacks", []) if entry.get("attacks", []) is Array else []
	for raw: Variant in attacks:
		if raw is Dictionary:
			var attack := raw as Dictionary
			var parts := PackedStringArray()
			var name := CardData.dictionary_display_name(attack)
			if name != "":
				parts.append(name)
			var damage := str(attack.get("damage", "")).strip_edges()
			if damage != "":
				parts.append(damage)
			var text := CardData.dictionary_display_text(attack)
			if text != "":
				parts.append(text)
			return _trim_summary(" ".join(parts))
	var description := str(entry.get("description", "")).strip_edges()
	return _trim_summary(description)


static func _trim_summary(text: String, max_chars: int = 62) -> String:
	var cleaned := text.strip_edges().replace("\n", " ")
	if cleaned.length() <= max_chars:
		return cleaned
	return "%s..." % cleaned.substr(0, maxi(0, max_chars - 3))


func _load_image(path: String) -> Image:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var image := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if CardData.has_png_signature(bytes):
		err = image.load_png_from_buffer(bytes)
	elif CardData.has_jpg_signature(bytes):
		err = image.load_jpg_from_buffer(bytes)
	elif CardData.has_webp_signature(bytes):
		err = image.load_webp_from_buffer(bytes)
	if err != OK:
		return null
	return image


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.10, 0.14, 0.96)
	style.border_color = Color(0.42, 0.72, 0.92, 0.88)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style
