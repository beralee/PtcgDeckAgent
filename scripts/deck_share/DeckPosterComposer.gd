class_name DeckPosterComposer
extends RefCounted

const DeckSharePayloadCodecScript := preload("res://scripts/deck_share/DeckSharePayloadCodec.gd")
const DeckShareDataStripScript := preload("res://scripts/deck_share/DeckShareDataStrip.gd")
const CARD_IMAGE_PROXY_VIEW_PATH := "res://scripts/ui/cards/CardImageOrProxyView.gd"

const SHARE_BACKGROUND_DEFAULT_ID := "auto"
const TITLE_FONT_PATH := "res://assets/fonts/NotoSansSC-VF.ttf"
const OUTPUT_WIDTH := 1080
const LEGACY_OUTPUT_SIZE := Vector2i(1080, 1920)
const VARIANT_MOBILE_SHARE := "mobile_share"
const VARIANT_DESKTOP_OVERVIEW := "desktop_overview"
const DESKTOP_OVERVIEW_OUTPUT_SIZE := Vector2i(1600, 1200)
const DESKTOP_OVERVIEW_HEADER_HEIGHT := 238
const DESKTOP_OVERVIEW_HERO_SIZE := Vector2i(660, DESKTOP_OVERVIEW_HEADER_HEIGHT)
const DESKTOP_OVERVIEW_GRID_RECT := Rect2i(48, 268, 1504, 876)
const DESKTOP_OVERVIEW_MAX_COLUMNS := 7
const DESKTOP_OVERVIEW_DENSE_COLUMNS := 8
const DESKTOP_OVERVIEW_COLUMN_GAP := 12
const DESKTOP_OVERVIEW_ROW_GAP := 10
const DESKTOP_OVERVIEW_AUTHOR_TEXT_RECT := Rect2i(734, 132, 470, 32)
const DESKTOP_OVERVIEW_SITE_URL_TEXT_RECT := Rect2i(734, 166, 430, 26)
const SAFE_MARGIN := 20
const GRID_COLUMNS := 5
const CARD_ASPECT := 0.715
const CARD_COLUMN_GAP := 4
const CARD_ROW_GAP := 2
const COUNT_BADGE_SIZE := Vector2i(54, 30)
const BANNER_HEIGHT := 470
const CARD_GRID_ORIGIN := Vector2i(20, BANNER_HEIGHT + 24)
const GENERIC_TITLE_TEXT_RECT := Rect2i(54, 348, 760, 62)
const GENERIC_TITLE_MAX_FONT_SIZE := 44
const GENERIC_TITLE_MIN_FONT_SIZE := 28
const AUTHOR_TEXT_RECT := Rect2i(57, 408, 620, 34)
const SITE_URL_TEXT := "ptcg.skillserver.cn"
const SITE_URL_TEXT_RECT := Rect2i(680, 408, 343, 34)
const HERO_ART_CROP := Rect2(0.035, 0.105, 0.93, 0.49)
const GARDEVOIR_TITLE_TEXT_RECT := GENERIC_TITLE_TEXT_RECT
const GARDEVOIR_TITLE_MAX_FONT_SIZE := GENERIC_TITLE_MAX_FONT_SIZE
const GARDEVOIR_TITLE_MIN_FONT_SIZE := GENERIC_TITLE_MIN_FONT_SIZE
const ART_TITLE_SCALE_X := 1.0
const DATA_STRIP_HEIGHT := int(DeckShareDataStripScript.STRIP_SIZE.y / 2)
const CARD_GRID_TO_CODE_GAP := 24
const DATA_STRIP_BOTTOM_QUIET_ZONE := 34
const BOTTOM_PADDING := 8
const FOOTER_HEIGHT := DATA_STRIP_HEIGHT + DATA_STRIP_BOTTOM_QUIET_ZONE + BOTTOM_PADDING


static func compose_image(
	deck: DeckData,
	author: String,
	note: String,
	app_version: String,
	card_db_version: String,
	card_database: Object = null,
	background_id: String = ""
) -> Dictionary:
	var errors := PackedStringArray()
	var normalized_background_id := normalize_background_id(background_id)
	var built := DeckSharePayloadCodecScript.build_payload(deck, author, note, app_version, card_db_version)
	if not bool(built.get("ok", false)):
		return _result(false, null, "", {}, built.get("errors", PackedStringArray()), 0)
	var encoded := DeckSharePayloadCodecScript.encode_payload(built.get("payload", {}))
	if not bool(encoded.get("ok", false)):
		return _result(false, null, "", encoded.get("payload", {}), encoded.get("errors", PackedStringArray()), 0)
	var encoded_text := str(encoded.get("text", ""))
	var strip_result := DeckShareDataStripScript.encode_text_to_image(encoded_text)
	if not bool(strip_result.get("ok", false)):
		return _result(false, null, encoded_text, encoded.get("payload", {}), strip_result.get("errors", PackedStringArray()), 0)

	var db := card_database if card_database != null else _default_card_database()
	var layout := _poster_layout_for_deck(deck)
	if DisplayServer.get_name() == "headless":
		var fallback := _compose_raster_image(deck, strip_result.get("image", null), db, layout, author, normalized_background_id)
		return _result(
			bool(fallback.get("ok", false)),
			fallback.get("image", null),
			encoded_text,
			encoded.get("payload", {}),
			fallback.get("errors", PackedStringArray()),
			int(fallback.get("missing_image_count", 0)),
			layout.get("code_rect", Rect2i())
		)

	var viewport := SubViewport.new()
	var output_size: Vector2i = layout.get("output_size", LEGACY_OUTPUT_SIZE)
	viewport.size = output_size
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var root := Control.new()
	root.size = output_size
	viewport.add_child(root)
	_build_template(root, deck, author, strip_result.get("image", null), db, layout, normalized_background_id)

	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		errors.append("scene tree is unavailable")
		return _result(false, null, encoded_text, encoded.get("payload", {}), errors, 0, layout.get("code_rect", Rect2i()))
	scene_tree.root.add_child(viewport)
	await scene_tree.process_frame
	await scene_tree.process_frame
	var viewport_texture := viewport.get_texture()
	var image := viewport_texture.get_image() if viewport_texture != null else null
	scene_tree.root.remove_child(viewport)
	viewport.queue_free()

	var missing_image_count := int(root.get_meta("missing_image_count", 0))
	if image == null:
		var fallback := _compose_raster_image(deck, strip_result.get("image", null), db, layout, author, normalized_background_id)
		return _result(
			bool(fallback.get("ok", false)),
			fallback.get("image", null),
			encoded_text,
			encoded.get("payload", {}),
			fallback.get("errors", PackedStringArray()),
			int(fallback.get("missing_image_count", 0)),
			layout.get("code_rect", Rect2i())
		)
	return _result(image != null and image.get_size() == output_size, image, encoded_text, encoded.get("payload", {}), errors, missing_image_count, layout.get("code_rect", Rect2i()))


static func compose_desktop_overview_image(
	deck: DeckData,
	author: String,
	card_database: Object = null
) -> Dictionary:
	var errors := PackedStringArray()
	if deck == null:
		errors.append("deck is unavailable")
		return _result(false, null, "", {}, errors, 0)
	var db := card_database if card_database != null else _default_card_database()
	var layout := _desktop_overview_layout(_poster_card_entries(deck).size())
	if DisplayServer.get_name() == "headless":
		var fallback := _compose_desktop_overview_raster_image(deck, author, db, layout)
		return _result(
			bool(fallback.get("ok", false)),
			fallback.get("image", null),
			"",
			{},
			fallback.get("errors", PackedStringArray()),
			int(fallback.get("missing_image_count", 0))
		)

	var viewport := SubViewport.new()
	viewport.size = DESKTOP_OVERVIEW_OUTPUT_SIZE
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var root := Control.new()
	root.size = DESKTOP_OVERVIEW_OUTPUT_SIZE
	viewport.add_child(root)
	_build_desktop_overview_template(root, deck, author, db, layout)

	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		errors.append("scene tree is unavailable")
		return _result(false, null, "", {}, errors, 0)
	scene_tree.root.add_child(viewport)
	await scene_tree.process_frame
	await scene_tree.process_frame
	var viewport_texture := viewport.get_texture()
	var image := viewport_texture.get_image() if viewport_texture != null else null
	var missing_image_count := int(root.get_meta("missing_image_count", 0))
	scene_tree.root.remove_child(viewport)
	viewport.queue_free()
	if image == null:
		var fallback := _compose_desktop_overview_raster_image(deck, author, db, layout)
		return _result(
			bool(fallback.get("ok", false)),
			fallback.get("image", null),
			"",
			{},
			fallback.get("errors", PackedStringArray()),
			int(fallback.get("missing_image_count", 0))
		)
	return _result(image.get_size() == DESKTOP_OVERVIEW_OUTPUT_SIZE, image, "", {}, errors, missing_image_count)


static func compose_for_variant(
	variant: String,
	deck: DeckData,
	author: String,
	note: String,
	app_version: String,
	card_db_version: String,
	card_database: Object = null,
	background_id: String = ""
) -> Dictionary:
	if variant == VARIANT_DESKTOP_OVERVIEW:
		return await compose_desktop_overview_image(deck, author, card_database)
	return await compose_image(deck, author, note, app_version, card_db_version, card_database, background_id)


static func _build_desktop_overview_template(
	root: Control,
	deck: DeckData,
	author: String,
	card_database: Object,
	layout: Dictionary = {}
) -> void:
	if layout.is_empty():
		layout = _desktop_overview_layout(_poster_card_entries(deck).size())
	var visual_profile := _poster_visual_profile(deck, card_database)
	var body_color: Color = visual_profile.get("body_color", Color(0.035, 0.045, 0.052, 1.0))
	var accent: Color = visual_profile.get("accent", Color("4db7a8"))

	var background := ColorRect.new()
	background.size = DESKTOP_OVERVIEW_OUTPUT_SIZE
	background.color = body_color.darkened(0.12)
	root.add_child(background)

	var header_background := ColorRect.new()
	header_background.size = Vector2(DESKTOP_OVERVIEW_OUTPUT_SIZE.x, DESKTOP_OVERVIEW_HEADER_HEIGHT)
	header_background.color = Color(0.018, 0.026, 0.032, 1.0)
	root.add_child(header_background)
	var hero_panel := _create_adaptive_banner(visual_profile, card_database, DESKTOP_OVERVIEW_HERO_SIZE)
	_add_image_layer(root, hero_panel, Rect2i(Vector2i.ZERO, DESKTOP_OVERVIEW_HERO_SIZE))

	var hero_matte := ColorRect.new()
	hero_matte.size = DESKTOP_OVERVIEW_HERO_SIZE
	hero_matte.color = Color(0.01, 0.015, 0.02, 0.18)
	root.add_child(hero_matte)

	var accent_bar := ColorRect.new()
	accent_bar.position = Vector2(692, 42)
	accent_bar.size = Vector2(6, 154)
	accent_bar.color = accent
	root.add_child(accent_bar)

	var title_font := ResourceLoader.load(TITLE_FONT_PATH, "FontFile", ResourceLoader.CACHE_MODE_REUSE) as Font
	var clean_title := deck.deck_name.strip_edges()
	if clean_title == "":
		clean_title = "卡组总览"
	var title_size := _fit_title_font_size(clean_title, title_font, 46, 30, 760.0)
	var title := _add_label(root, clean_title, Vector2(732, 60), Vector2(784, 66), title_size, Color(0.96, 0.98, 0.98, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	title.set_meta("deck_share_text_role", "desktop_overview_title")
	_style_clean_title_label(title, title_font)

	var clean_author := author.strip_edges()
	if clean_author == "":
		clean_author = DeckSharePayloadCodecScript.DEFAULT_AUTHOR
	var author_label := _add_label(root, "作者 / %s" % clean_author, DESKTOP_OVERVIEW_AUTHOR_TEXT_RECT.position, DESKTOP_OVERVIEW_AUTHOR_TEXT_RECT.size, 20, Color(0.72, 0.80, 0.83, 0.92), HORIZONTAL_ALIGNMENT_LEFT)
	if title_font != null:
		author_label.add_theme_font_override("font", title_font)
	var site_url_label := _add_label(root, SITE_URL_TEXT, DESKTOP_OVERVIEW_SITE_URL_TEXT_RECT.position, DESKTOP_OVERVIEW_SITE_URL_TEXT_RECT.size, 16, Color(0.62, 0.75, 0.78, 0.88), HORIZONTAL_ALIGNMENT_LEFT)
	site_url_label.set_meta("deck_share_text_role", "desktop_overview_site_url")
	if title_font != null:
		site_url_label.add_theme_font_override("font", title_font)

	var unique_count := _poster_card_entries(deck).size()
	var overview_label := _add_label(root, "卡组总览", Vector2(1280, 34), Vector2(236, 28), 18, accent.lightened(0.18), HORIZONTAL_ALIGNMENT_RIGHT)
	var count_label := _add_label(root, "%d 张  /  %d 种" % [maxi(0, deck.total_cards), unique_count], Vector2(1230, 168), Vector2(286, 34), 21, Color(0.80, 0.86, 0.88, 0.94), HORIZONTAL_ALIGNMENT_RIGHT)
	if title_font != null:
		overview_label.add_theme_font_override("font", title_font)
		count_label.add_theme_font_override("font", title_font)

	var divider := ColorRect.new()
	divider.position = Vector2(0, DESKTOP_OVERVIEW_HEADER_HEIGHT)
	divider.size = Vector2(DESKTOP_OVERVIEW_OUTPUT_SIZE.x, 4)
	divider.color = accent
	root.add_child(divider)

	var missing_image_count := _add_desktop_overview_card_grid(root, deck, card_database, layout)
	root.set_meta("missing_image_count", missing_image_count)
	var footer := _add_label(root, "PTCG DECK AGENT", Vector2(48, 1158), Vector2(300, 24), 15, Color(0.54, 0.62, 0.64, 0.78), HORIZONTAL_ALIGNMENT_LEFT)
	if title_font != null:
		footer.add_theme_font_override("font", title_font)


static func _build_template(
	root: Control,
	deck: DeckData,
	author: String,
	strip_image: Image,
	card_database: Object,
	layout: Dictionary = {},
	background_id: String = ""
) -> void:
	if layout.is_empty():
		layout = _poster_layout_for_deck(deck)
	var output_size: Vector2i = layout.get("output_size", LEGACY_OUTPUT_SIZE)
	var code_rect: Rect2i = layout.get("code_rect", Rect2i(0, output_size.y - FOOTER_HEIGHT, output_size.x, DATA_STRIP_HEIGHT))

	var clean_author := author.strip_edges()
	if clean_author == "":
		clean_author = DeckSharePayloadCodecScript.DEFAULT_AUTHOR
	var deck_name := deck.deck_name if deck != null else ""
	var visual_profile := _poster_visual_profile(deck, card_database)
	_add_background_layers(root, output_size, visual_profile, card_database)
	_add_banner_title(root, deck_name, clean_author, visual_profile)

	var missing_image_count := _add_card_grid(root, deck, card_database, layout)
	root.set_meta("missing_image_count", missing_image_count)

	var display_strip := _prepare_display_strip_image(strip_image, code_rect.size)
	var strip_texture := ImageTexture.create_from_image(display_strip)
	var strip_rect := TextureRect.new()
	strip_rect.texture = strip_texture
	strip_rect.position = code_rect.position
	strip_rect.size = code_rect.size
	strip_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	strip_rect.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(strip_rect)


static func _add_card_grid(root: Control, deck: DeckData, card_database: Object, layout: Dictionary = {}) -> int:
	if layout.is_empty():
		layout = _poster_layout_for_deck(deck)
	var entries := _poster_card_entries(deck)
	var metrics: Dictionary = layout.get("metrics", _card_grid_metrics(entries.size()))
	var cell_size: Vector2i = metrics.get("cell_size", Vector2i(180, 280))
	var image_size: Vector2i = metrics.get("image_size", Vector2i(180, 252))
	var missing_image_count := 0
	for i: int in entries.size():
		var col := i % GRID_COLUMNS
		var row := int(i / GRID_COLUMNS)
		var pos := Vector2(
			CARD_GRID_ORIGIN.x + col * (cell_size.x + CARD_COLUMN_GAP) + int((cell_size.x - image_size.x) / 2),
			CARD_GRID_ORIGIN.y + row * (cell_size.y + CARD_ROW_GAP)
		)
		var entry: Dictionary = entries[i]
		var image := _load_card_image_for_entry(entry, card_database)
		if image == null:
			missing_image_count += 1
			_add_card_placeholder(root, pos, image_size, _entry_with_card_details(entry, card_database))
		else:
			image.resize(image_size.x, image_size.y, Image.INTERPOLATE_LANCZOS)
			var texture := ImageTexture.create_from_image(image)
			var slot := TextureRect.new()
			slot.texture = texture
			slot.position = pos
			slot.size = image_size
			slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			slot.stretch_mode = TextureRect.STRETCH_SCALE
			root.add_child(slot)
		_add_card_count_label(root, pos, image_size, int(entry.get("count", 1)))
	return missing_image_count


static func _unique_card_entries(deck: DeckData) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if deck == null:
		return entries
	var index_by_key := {}
	for source: Dictionary in deck.cards:
		var count := int(source.get("count", 0))
		if count <= 0:
			continue
		var key := "%s/%s" % [str(source.get("set_code", "")), str(source.get("card_index", ""))]
		if index_by_key.has(key):
			var existing: Dictionary = entries[int(index_by_key[key])]
			existing["count"] = int(existing.get("count", 0)) + count
		else:
			var copied := source.duplicate(true)
			copied["count"] = count
			index_by_key[key] = entries.size()
			entries.append(copied)
	return entries


static func _poster_card_entries(deck: DeckData) -> Array[Dictionary]:
	var entries := _unique_card_entries(deck)
	var hero_rank_by_key := {}
	var visual_profile := _poster_visual_profile(deck, null)
	var hero_entries: Array = visual_profile.get("hero_entries", [])
	for i: int in hero_entries.size():
		var hero: Dictionary = hero_entries[i]
		hero_rank_by_key[_poster_entry_key(hero)] = i
	var archetype := _infer_poster_archetype(deck, entries)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_hero_rank := int(hero_rank_by_key.get(_poster_entry_key(a), 999))
		var b_hero_rank := int(hero_rank_by_key.get(_poster_entry_key(b), 999))
		if a_hero_rank != b_hero_rank:
			return a_hero_rank < b_hero_rank
		return _compare_poster_entries(a, b, archetype)
	)
	return entries


static func _unique_card_entries_for_tests(deck: DeckData) -> Array[Dictionary]:
	return _unique_card_entries(deck)


static func _poster_card_entries_for_tests(deck: DeckData) -> Array[Dictionary]:
	return _poster_card_entries(deck)


static func _poster_visual_profile(deck: DeckData, card_database: Object) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var deck_key := _normalize_identity_text(deck.deck_name if deck != null else "")
	for raw_entry: Dictionary in _unique_card_entries(deck):
		var entry := _entry_with_card_details(raw_entry, card_database)
		if str(entry.get("card_type", "")) != "Pokemon":
			continue
		var score_data := _poster_hero_score(entry, deck_key)
		entry["_poster_hero_score"] = int(score_data.get("score", 0))
		entry["_poster_name_match"] = bool(score_data.get("name_match", false))
		entry["_poster_name_position"] = int(score_data.get("name_position", 999999))
		candidates.append(entry)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_match := bool(a.get("_poster_name_match", false))
		var b_match := bool(b.get("_poster_name_match", false))
		if a_match and b_match:
			var a_position := int(a.get("_poster_name_position", 999999))
			var b_position := int(b.get("_poster_name_position", 999999))
			if a_position != b_position:
				return a_position < b_position
		var a_score := int(a.get("_poster_hero_score", 0))
		var b_score := int(b.get("_poster_hero_score", 0))
		if a_score != b_score:
			return a_score > b_score
		return int(a.get("count", 0)) > int(b.get("count", 0))
	)

	var heroes: Array[Dictionary] = []
	if not candidates.is_empty():
		heroes.append(candidates[0])
	for candidate: Dictionary in candidates.slice(1):
		if heroes.size() >= 2:
			break
		if not bool(candidate.get("_poster_name_match", false)):
			continue
		if _same_poster_identity(heroes[0], candidate):
			continue
		heroes.append(candidate)

	var accent := _fallback_accent_for_entry(heroes[0] if not heroes.is_empty() else {})
	var secondary_accent := _fallback_accent_for_entry(heroes[1] if heroes.size() > 1 else {})
	for hero: Dictionary in heroes:
		var hero_image := _load_card_image_for_entry(hero, card_database)
		if hero_image == null:
			continue
		var sampled := _sample_art_accent(_extract_card_art(hero_image))
		if hero == heroes[0]:
			accent = sampled
		else:
			secondary_accent = sampled
	var body_color := Color(
		0.025 + accent.r * 0.055,
		0.027 + accent.g * 0.055,
		0.034 + accent.b * 0.060,
		1.0
	)
	return {
		"hero_entries": heroes,
		"composition": "dual" if heroes.size() > 1 else "single",
		"accent": accent,
		"secondary_accent": secondary_accent,
		"body_color": body_color,
	}


static func _poster_visual_profile_for_tests(deck: DeckData, card_database: Object) -> Dictionary:
	return _poster_visual_profile(deck, card_database)


static func _poster_hero_score(entry: Dictionary, deck_key: String) -> Dictionary:
	var names := PackedStringArray()
	for key: String in ["name", "name_zh", "name_en", "display_name"]:
		var value := _normalize_identity_text(str(entry.get(key, "")))
		if value != "" and value not in names:
			names.append(value)
	var name_match := false
	var name_position := 999999
	for name: String in names:
		var identity := _strip_poster_mechanic_suffix(name)
		if identity.length() >= 2 and deck_key.contains(identity):
			name_match = true
			name_position = mini(name_position, deck_key.find(identity))
	var score := int(entry.get("count", 0)) * 12
	if name_match:
		score += 600
	var mechanic_text := _normalize_poster_text("%s %s %s" % [
		str(entry.get("mechanic", "")),
		str(entry.get("name_en", "")),
		str(entry.get("name", "")),
	])
	if mechanic_text.contains("ex") or mechanic_text.contains("vstar") or mechanic_text.contains("vmax"):
		score += 140
	elif mechanic_text.contains("radiant") or mechanic_text.contains("光辉"):
		score += 45
	match str(entry.get("stage", "")):
		"Stage 2":
			score += 120
		"Stage 1":
			score += 55
	if int(entry.get("hp", 0)) > 0:
		score += mini(80, int(entry.get("hp", 0)) / 5)
	return {"score": score, "name_match": name_match, "name_position": name_position}


static func _poster_entry_key(entry: Dictionary) -> String:
	return "%s/%s" % [str(entry.get("set_code", "")), str(entry.get("card_index", ""))]


static func _same_poster_identity(a: Dictionary, b: Dictionary) -> bool:
	var a_name := _strip_poster_mechanic_suffix(_normalize_identity_text(CardData.dictionary_display_name(a)))
	var b_name := _strip_poster_mechanic_suffix(_normalize_identity_text(CardData.dictionary_display_name(b)))
	return a_name != "" and b_name != "" and (a_name.contains(b_name) or b_name.contains(a_name))


static func _normalize_identity_text(text: String) -> String:
	var normalized := text.strip_edges().to_lower()
	for token: String in [" ", "\t", "\n", "-", "_", "·", "'", "’", ".", ":", "/", "（", "）", "(", ")"]:
		normalized = normalized.replace(token, "")
	return normalized


static func _strip_poster_mechanic_suffix(text: String) -> String:
	var normalized := text
	for suffix: String in ["vstar", "vmax", "radiant", "光辉", "ex", "gx"]:
		normalized = normalized.replace(suffix, "")
	return normalized


static func _fallback_accent_for_entry(entry: Dictionary) -> Color:
	match str(entry.get("energy_type", entry.get("energy_provides", ""))).to_upper():
		"R": return Color("e75b3a")
		"W": return Color("4c9bd8")
		"G": return Color("62a95b")
		"L": return Color("e1b936")
		"P": return Color("ba70b5")
		"F": return Color("c77a4e")
		"D": return Color("655e8d")
		"M": return Color("8ca3ac")
		"N": return Color("8f74bb")
		_: return Color("4db7a8")


static func _sample_art_accent(art: Image) -> Color:
	if art == null or art.is_empty():
		return Color("4db7a8")
	var hue_weights: Array[float] = []
	var hue_colors: Array[Color] = []
	for _i: int in 12:
		hue_weights.append(0.0)
		hue_colors.append(Color(0, 0, 0, 1))
	for y: int in range(0, art.get_height(), 6):
		for x: int in range(0, art.get_width(), 6):
			var color := art.get_pixel(x, y)
			if color.s < 0.22 or color.v < 0.18 or color.v > 0.96:
				continue
			var bucket := clampi(int(floor(color.h * 12.0)), 0, 11)
			var weight := color.s * (0.35 + color.v)
			hue_weights[bucket] += weight
			hue_colors[bucket] += color * weight
	var best_bucket := 0
	for i: int in range(1, hue_weights.size()):
		if hue_weights[i] > hue_weights[best_bucket]:
			best_bucket = i
	if hue_weights[best_bucket] <= 0.0:
		return Color("4db7a8")
	var sampled := hue_colors[best_bucket] / hue_weights[best_bucket]
	return Color.from_hsv(sampled.h, clampf(sampled.s, 0.42, 0.78), clampf(sampled.v, 0.58, 0.88), 1.0)


static func _infer_poster_archetype(deck: DeckData, entries: Array[Dictionary]) -> String:
	var deck_name := _normalize_poster_text(deck.deck_name if deck != null else "")
	if deck_name.contains("gardevoir") or deck_name.contains("沙奈朵"):
		return "gardevoir"
	for entry: Dictionary in entries:
		var name := _poster_entry_name(entry)
		if name.contains("gardevoir ex") or name.contains("kirlia"):
			return "gardevoir"
	return ""


static func _compare_poster_entries(a: Dictionary, b: Dictionary, archetype: String) -> bool:
	var a_key := _poster_sort_key(a, archetype)
	var b_key := _poster_sort_key(b, archetype)
	for i: int in mini(a_key.size(), b_key.size()):
		if a_key[i] == b_key[i]:
			continue
		return a_key[i] < b_key[i]
	return a_key.size() < b_key.size()


static func _poster_sort_key(entry: Dictionary, archetype: String) -> Array:
	var card_type := str(entry.get("card_type", "")).strip_edges()
	var name := _poster_entry_name(entry)
	var archetype_rank := _poster_archetype_rank(archetype, name)
	var count := int(entry.get("count", 0))
	if archetype_rank < 900:
		return [0, archetype_rank, -count, name, str(entry.get("set_code", "")), str(entry.get("card_index", ""))]
	var type_rank := _poster_card_type_rank(card_type)
	var role_rank := _poster_role_rank(card_type, name)
	return [type_rank + 1, role_rank, -count, name, str(entry.get("set_code", "")), str(entry.get("card_index", ""))]


static func _poster_archetype_rank(archetype: String, name: String) -> int:
	if archetype != "gardevoir":
		return 999
	if name.contains("gardevoir ex"):
		return 0
	if name.contains("kirlia"):
		return 1
	if name.contains("ralts"):
		return 2
	if name.contains("scream tail"):
		return 3
	if name.contains("drifloon") or name.contains("cresselia"):
		return 4
	if name.contains("munkidori"):
		return 5
	if name.contains("radiant gardevoir"):
		return 6
	if name.contains("gardevoir"):
		return 7
	return 999


static func _poster_card_type_rank(card_type: String) -> int:
	match card_type:
		"Pokemon":
			return 0
		"Item", "Tool", "Stadium", "Supporter":
			return 1
		"Special Energy":
			return 2
		"Basic Energy":
			return 3
		_:
			return 2


static func _poster_role_rank(card_type: String, name: String) -> int:
	if card_type == "Pokemon":
		if name.contains(" ex") or name.ends_with("ex") or name.contains("vstar") or name.contains("vmax"):
			return 0
		return 1
	if card_type == "Item":
		return 0
	if card_type == "Tool":
		return 1
	if card_type == "Stadium":
		return 2
	if card_type == "Supporter":
		return 3
	if card_type == "Special Energy":
		return 4
	if card_type == "Basic Energy":
		return 5
	return 6


static func _poster_entry_name(entry: Dictionary) -> String:
	var parts := PackedStringArray()
	for key: String in ["name_en", "name_zh", "name"]:
		var value := str(entry.get(key, "")).strip_edges()
		if value != "":
			parts.append(value)
	return _normalize_poster_text(" ".join(parts))


static func _normalize_poster_text(text: String) -> String:
	return text.strip_edges().to_lower()


static func _card_grid_metrics(unique_count: int) -> Dictionary:
	var rows := maxi(1, int(ceil(float(maxi(unique_count, 1)) / float(GRID_COLUMNS))))
	var available_width := OUTPUT_WIDTH - SAFE_MARGIN * 2
	var cell_width := int((available_width - CARD_COLUMN_GAP * (GRID_COLUMNS - 1)) / GRID_COLUMNS)
	var width_filling_height := int(round(float(cell_width) / CARD_ASPECT))
	return {
		"rows": rows,
		"cell_size": Vector2i(cell_width, width_filling_height),
		"image_size": Vector2i(cell_width, width_filling_height),
	}


static func _card_grid_metrics_for_tests(unique_count: int) -> Dictionary:
	return _card_grid_metrics(unique_count)


static func _poster_layout_for_deck(deck: DeckData) -> Dictionary:
	return _poster_layout(_poster_card_entries(deck).size())


static func _poster_layout(unique_count: int) -> Dictionary:
	var metrics := _card_grid_metrics(unique_count)
	var rows := int(metrics.get("rows", 1))
	var image_size: Vector2i = metrics.get("image_size", Vector2i(204, 285))
	var grid_height := rows * image_size.y + maxi(0, rows - 1) * CARD_ROW_GAP
	var code_y := CARD_GRID_ORIGIN.y + grid_height + CARD_GRID_TO_CODE_GAP
	var code_rect := Rect2i(0, code_y, OUTPUT_WIDTH, DATA_STRIP_HEIGHT)
	var output_size := Vector2i(OUTPUT_WIDTH, code_rect.end.y + DATA_STRIP_BOTTOM_QUIET_ZONE + BOTTOM_PADDING)
	return {
		"metrics": metrics,
		"output_size": output_size,
		"code_rect": code_rect,
	}


static func _poster_layout_for_tests(unique_count: int) -> Dictionary:
	return _poster_layout(unique_count)


static func _desktop_overview_layout(unique_count: int) -> Dictionary:
	var safe_count := maxi(1, unique_count)
	var max_columns := DESKTOP_OVERVIEW_DENSE_COLUMNS if safe_count > DESKTOP_OVERVIEW_MAX_COLUMNS * 4 else DESKTOP_OVERVIEW_MAX_COLUMNS
	var columns := mini(max_columns, safe_count)
	var rows := maxi(1, int(ceil(float(safe_count) / float(columns))))
	var available_width := DESKTOP_OVERVIEW_GRID_RECT.size.x - DESKTOP_OVERVIEW_COLUMN_GAP * maxi(0, columns - 1)
	var available_height := DESKTOP_OVERVIEW_GRID_RECT.size.y - DESKTOP_OVERVIEW_ROW_GAP * maxi(0, rows - 1)
	var width_from_columns := int(floor(float(available_width) / float(columns)))
	var height_from_rows := int(floor(float(available_height) / float(rows)))
	var image_width := mini(width_from_columns, int(floor(float(height_from_rows) * CARD_ASPECT)))
	var image_height := int(round(float(image_width) / CARD_ASPECT))
	if image_height > height_from_rows:
		image_height = height_from_rows
		image_width = int(floor(float(image_height) * CARD_ASPECT))
	var total_width := columns * image_width + maxi(0, columns - 1) * DESKTOP_OVERVIEW_COLUMN_GAP
	var total_height := rows * image_height + maxi(0, rows - 1) * DESKTOP_OVERVIEW_ROW_GAP
	var origin := DESKTOP_OVERVIEW_GRID_RECT.position + Vector2i(
		int((DESKTOP_OVERVIEW_GRID_RECT.size.x - total_width) * 0.5),
		int((DESKTOP_OVERVIEW_GRID_RECT.size.y - total_height) * 0.5)
	)
	return {
		"output_size": DESKTOP_OVERVIEW_OUTPUT_SIZE,
		"grid_rect": DESKTOP_OVERVIEW_GRID_RECT,
		"metrics": {
			"columns": columns,
			"rows": rows,
			"image_size": Vector2i(image_width, image_height),
			"cell_size": Vector2i(image_width, image_height),
			"origin": origin,
			"column_gap": DESKTOP_OVERVIEW_COLUMN_GAP,
			"row_gap": DESKTOP_OVERVIEW_ROW_GAP,
		},
		"code_rect": Rect2i(),
	}


static func _desktop_overview_layout_for_tests(unique_count: int) -> Dictionary:
	return _desktop_overview_layout(unique_count)


static func _add_desktop_overview_card_grid(root: Control, deck: DeckData, card_database: Object, layout: Dictionary = {}) -> int:
	if layout.is_empty():
		layout = _desktop_overview_layout(_poster_card_entries(deck).size())
	var entries := _poster_card_entries(deck)
	var metrics: Dictionary = layout.get("metrics", {})
	var columns := int(metrics.get("columns", DESKTOP_OVERVIEW_MAX_COLUMNS))
	var origin: Vector2i = metrics.get("origin", DESKTOP_OVERVIEW_GRID_RECT.position)
	var image_size: Vector2i = metrics.get("image_size", Vector2i(180, 252))
	var column_gap := int(metrics.get("column_gap", DESKTOP_OVERVIEW_COLUMN_GAP))
	var row_gap := int(metrics.get("row_gap", DESKTOP_OVERVIEW_ROW_GAP))
	var missing_image_count := 0
	for i: int in entries.size():
		var col := i % columns
		var row := int(i / columns)
		var pos := Vector2(origin + Vector2i(col * (image_size.x + column_gap), row * (image_size.y + row_gap)))
		var shadow := ColorRect.new()
		shadow.position = pos + Vector2(4, 5)
		shadow.size = image_size
		shadow.color = Color(0, 0, 0, 0.42)
		root.add_child(shadow)
		var entry: Dictionary = entries[i]
		var card_image := _load_card_image_for_entry(entry, card_database)
		if card_image == null:
			missing_image_count += 1
			_add_card_placeholder(root, pos, image_size, _entry_with_card_details(entry, card_database))
		else:
			card_image.resize(image_size.x, image_size.y, Image.INTERPOLATE_LANCZOS)
			var texture := ImageTexture.create_from_image(card_image)
			var slot := TextureRect.new()
			slot.texture = texture
			slot.position = pos
			slot.size = image_size
			slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			slot.stretch_mode = TextureRect.STRETCH_SCALE
			root.add_child(slot)
		_add_card_count_label(root, pos, image_size, int(entry.get("count", 1)))
	return missing_image_count


static func _load_card_image_for_entry(entry: Dictionary, card_database: Object) -> Image:
	var set_code := str(entry.get("set_code", "")).strip_edges()
	var card_index := str(entry.get("card_index", "")).strip_edges()
	if set_code == "" or card_index == "":
		return null
	var preferred := ""
	if card_database != null and card_database.has_method("get_card"):
		var card: CardData = card_database.call("get_card", set_code, card_index)
		if card != null:
			preferred = card.image_local_path
	var image_path := CardData.resolve_existing_image_path(CardData.get_image_candidate_paths(set_code, card_index, preferred))
	if image_path == "":
		return null
	return _load_image_file(image_path)


static func _entry_with_card_details(entry: Dictionary, card_database: Object) -> Dictionary:
	var set_code := str(entry.get("set_code", "")).strip_edges()
	var card_index := str(entry.get("card_index", "")).strip_edges()
	if set_code == "" or card_index == "":
		return entry
	if card_database != null and card_database.has_method("get_card"):
		var card: CardData = card_database.call("get_card", set_code, card_index)
		if card != null:
			var detailed := card.to_dict()
			for key: Variant in entry.keys():
				detailed[key] = entry[key]
			detailed["display_name"] = card.display_name()
			return detailed
	return entry


static func _default_card_database() -> Object:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("CardDatabase")


static func _load_image_file(path: String) -> Image:
	if FileAccess.file_exists(path):
		var bytes := FileAccess.get_file_as_bytes(path)
		if not bytes.is_empty() and CardData.has_supported_image_signature(bytes):
			var image := Image.new()
			var err := ERR_FILE_UNRECOGNIZED
			if CardData.has_png_signature(bytes):
				err = image.load_png_from_buffer(bytes)
			elif CardData.has_jpg_signature(bytes):
				err = image.load_jpg_from_buffer(bytes)
			elif CardData.has_webp_signature(bytes):
				err = image.load_webp_from_buffer(bytes)
			if err == OK:
				return image
	if path.begins_with("res://"):
		var texture := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
		if texture != null:
			return texture.get_image()
	return null


static func share_background_options() -> Array[Dictionary]:
	return []


static func default_background_id() -> String:
	return SHARE_BACKGROUND_DEFAULT_ID


static func normalize_background_id(background_id: String) -> String:
	return SHARE_BACKGROUND_DEFAULT_ID


static func _background_option_by_id(background_id: String) -> Dictionary:
	return {"id": SHARE_BACKGROUND_DEFAULT_ID, "label": "自动适配", "banner_path": ""}


static func _background_banner_path(background_id: String) -> String:
	return ""


static func _add_background_layers(root: Control, output_size: Vector2i, visual_profile: Dictionary, card_database: Object) -> void:
	var fallback := ColorRect.new()
	fallback.color = visual_profile.get("body_color", Color(0.035, 0.045, 0.052, 1.0))
	fallback.size = output_size
	root.add_child(fallback)
	var banner := _create_adaptive_banner(visual_profile, card_database)
	_add_image_layer(root, banner, Rect2i(0, 0, output_size.x, BANNER_HEIGHT))
	var divider := ColorRect.new()
	divider.position = Vector2(0, BANNER_HEIGHT - 5)
	divider.size = Vector2(output_size.x, 5)
	divider.color = visual_profile.get("accent", Color("4db7a8"))
	root.add_child(divider)


static func _add_image_layer(root: Control, image: Image, rect: Rect2i) -> void:
	var texture := ImageTexture.create_from_image(image)
	var layer := TextureRect.new()
	layer.texture = texture
	layer.position = rect.position
	layer.size = rect.size
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(layer)


static func _draw_background_layers(image: Image, output_size: Vector2i, visual_profile: Dictionary, card_database: Object) -> void:
	image.fill(visual_profile.get("body_color", Color(0.035, 0.045, 0.052, 1.0)))
	var banner := _create_adaptive_banner(visual_profile, card_database)
	image.blit_rect(banner, Rect2i(Vector2i.ZERO, banner.get_size()), Vector2i.ZERO)
	image.fill_rect(Rect2i(0, BANNER_HEIGHT - 5, output_size.x, 5), visual_profile.get("accent", Color("4db7a8")))


static func _banner_path_for_deck(deck_name: String, author: String, background_id: String = "") -> String:
	return ""


static func _uses_precomposed_banner(deck_name: String, author: String, background_id: String = "") -> bool:
	return false


static func _create_adaptive_banner(visual_profile: Dictionary, card_database: Object, target_size: Vector2i = Vector2i(OUTPUT_WIDTH, BANNER_HEIGHT)) -> Image:
	var heroes: Array = visual_profile.get("hero_entries", [])
	var layers: Array[Image] = []
	for raw: Variant in heroes:
		var entry: Dictionary = raw
		var card_image := _load_card_image_for_entry(entry, card_database)
		if card_image != null:
			layers.append(_cover_image(_extract_card_art(card_image), target_size))
	var accent: Color = visual_profile.get("accent", Color("4db7a8"))
	var secondary: Color = visual_profile.get("secondary_accent", accent)
	var banner := Image.create(target_size.x, target_size.y, false, Image.FORMAT_RGBA8)
	if layers.is_empty():
		for y: int in target_size.y:
			var t := float(y) / float(maxi(1, target_size.y - 1))
			var row_color := accent.darkened(0.40 + t * 0.34).lerp(secondary.darkened(0.58), t * 0.26)
			banner.fill_rect(Rect2i(0, y, target_size.x, 1), row_color)
	else:
		banner.blit_rect(layers[0], Rect2i(Vector2i.ZERO, target_size), Vector2i.ZERO)
		if layers.size() > 1:
			var second: Image = layers[1]
			var blend_start := int(round(target_size.x * 0.40))
			var blend_end := float(target_size.x) * 0.72
			for y: int in target_size.y:
				for x: int in range(blend_start, target_size.x):
					var blend := smoothstep(float(blend_start), blend_end, float(x))
					banner.set_pixel(x, y, banner.get_pixel(x, y).lerp(second.get_pixel(x, y), blend))
	_apply_banner_grade(banner, accent)
	return banner


static func _extract_card_art(card_image: Image) -> Image:
	if card_image == null or card_image.is_empty():
		return null
	var rect := Rect2i(
		int(round(card_image.get_width() * HERO_ART_CROP.position.x)),
		int(round(card_image.get_height() * HERO_ART_CROP.position.y)),
		int(round(card_image.get_width() * HERO_ART_CROP.size.x)),
		int(round(card_image.get_height() * HERO_ART_CROP.size.y))
	)
	rect = rect.intersection(Rect2i(Vector2i.ZERO, card_image.get_size()))
	return card_image.get_region(rect)


static func _cover_image(source: Image, target_size: Vector2i) -> Image:
	if source == null or source.is_empty():
		var empty := Image.create(target_size.x, target_size.y, false, Image.FORMAT_RGBA8)
		empty.fill(Color(0.08, 0.10, 0.12, 1.0))
		return empty
	var source_aspect := float(source.get_width()) / float(maxi(1, source.get_height()))
	var target_aspect := float(target_size.x) / float(maxi(1, target_size.y))
	var crop := Rect2i(Vector2i.ZERO, source.get_size())
	if source_aspect > target_aspect:
		var crop_width := int(round(source.get_height() * target_aspect))
		crop.position.x = maxi(0, int((source.get_width() - crop_width) * 0.5))
		crop.size.x = mini(crop_width, source.get_width())
	else:
		var crop_height := int(round(source.get_width() / target_aspect))
		crop.position.y = maxi(0, int((source.get_height() - crop_height) * 0.42))
		crop.size.y = mini(crop_height, source.get_height())
	var fitted := source.get_region(crop)
	fitted.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
	return fitted


static func _apply_banner_grade(image: Image, accent: Color) -> void:
	for y: int in image.get_height():
		var vertical := float(y) / float(maxi(1, image.get_height() - 1))
		var bottom_matte := smoothstep(0.48, 1.0, vertical) * 0.72
		for x: int in image.get_width():
			var edge := absf(float(x) / float(maxi(1, image.get_width() - 1)) - 0.5) * 2.0
			var vignette := pow(edge, 2.4) * 0.24
			var source := image.get_pixel(x, y).lerp(accent, 0.055)
			var darkness := clampf(0.12 + bottom_matte + vignette, 0.0, 0.84)
			image.set_pixel(x, y, source.darkened(darkness))


static func _fit_image_to_size(source: Image, target_size: Vector2i) -> Image:
	var fitted := source.duplicate()
	if fitted.get_format() != Image.FORMAT_RGBA8:
		fitted.convert(Image.FORMAT_RGBA8)
	fitted.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
	return fitted


static func _extend_image_to_size(source: Image, target_size: Vector2i) -> Image:
	var extended := Image.create(target_size.x, target_size.y, false, Image.FORMAT_RGBA8)
	extended.fill(Color(0.04, 0.05, 0.10, 1.0))
	var tile := source.duplicate()
	if tile.get_format() != Image.FORMAT_RGBA8:
		tile.convert(Image.FORMAT_RGBA8)
	tile.resize(target_size.x, maxi(1, int(round(float(source.get_height()) * float(target_size.x) / float(maxi(1, source.get_width()))))), Image.INTERPOLATE_LANCZOS)
	var y := 0
	while y < target_size.y:
		var segment_height := mini(tile.get_height(), target_size.y - y)
		extended.blit_rect(tile, Rect2i(0, 0, target_size.x, segment_height), Vector2i(0, y))
		y += segment_height
	return extended


static func _compose_raster_image(deck: DeckData, strip_image: Image, card_database: Object, layout: Dictionary = {}, author: String = "", background_id: String = "") -> Dictionary:
	var errors := PackedStringArray()
	if strip_image == null:
		errors.append("missing code image")
		return {"ok": false, "image": null, "errors": errors, "missing_image_count": 0}
	if layout.is_empty():
		layout = _poster_layout_for_deck(deck)
	var output_size: Vector2i = layout.get("output_size", LEGACY_OUTPUT_SIZE)
	var code_rect: Rect2i = layout.get("code_rect", Rect2i(0, output_size.y - FOOTER_HEIGHT, output_size.x, DATA_STRIP_HEIGHT))
	var image := Image.create(output_size.x, output_size.y, false, Image.FORMAT_RGBA8)
	var clean_author := author.strip_edges()
	if clean_author == "":
		clean_author = DeckSharePayloadCodecScript.DEFAULT_AUTHOR
	var visual_profile := _poster_visual_profile(deck, card_database)
	_draw_background_layers(image, output_size, visual_profile, card_database)
	var entries := _poster_card_entries(deck)
	var metrics: Dictionary = layout.get("metrics", _card_grid_metrics(entries.size()))
	var cell_size: Vector2i = metrics.get("cell_size", Vector2i(180, 280))
	var image_size: Vector2i = metrics.get("image_size", Vector2i(180, 252))
	var missing_image_count := 0
	for i: int in entries.size():
		var col := i % GRID_COLUMNS
		var row := int(i / GRID_COLUMNS)
		var pos := Vector2i(
			CARD_GRID_ORIGIN.x + col * (cell_size.x + CARD_COLUMN_GAP) + int((cell_size.x - image_size.x) / 2),
			CARD_GRID_ORIGIN.y + row * (cell_size.y + CARD_ROW_GAP)
		)
		var entry: Dictionary = entries[i]
		var card_image := _load_card_image_for_entry(entry, card_database)
		if card_image == null:
			missing_image_count += 1
			image.fill_rect(Rect2i(pos, image_size), Color(0.16, 0.18, 0.2, 1.0))
			image.fill_rect(Rect2i(pos + Vector2i(2, 2), image_size - Vector2i(4, 4)), Color(0.22, 0.24, 0.27, 1.0))
			_add_count_badge_to_raster(image, pos, image_size, int(entry.get("count", 1)))
			continue
		card_image.resize(image_size.x, image_size.y, Image.INTERPOLATE_LANCZOS)
		image.blit_rect(card_image, Rect2i(Vector2i.ZERO, image_size), pos)
		_add_count_badge_to_raster(image, pos, image_size, int(entry.get("count", 1)))
	var display_strip := _prepare_display_strip_image(strip_image, code_rect.size)
	image.blit_rect(display_strip, Rect2i(Vector2i.ZERO, display_strip.get_size()), code_rect.position)
	return {"ok": true, "image": image, "errors": errors, "missing_image_count": missing_image_count}


static func _compose_desktop_overview_raster_image(deck: DeckData, _author: String, card_database: Object, layout: Dictionary = {}) -> Dictionary:
	var errors := PackedStringArray()
	if deck == null:
		errors.append("deck is unavailable")
		return {"ok": false, "image": null, "errors": errors, "missing_image_count": 0}
	if layout.is_empty():
		layout = _desktop_overview_layout(_poster_card_entries(deck).size())
	var visual_profile := _poster_visual_profile(deck, card_database)
	var body_color: Color = visual_profile.get("body_color", Color(0.035, 0.045, 0.052, 1.0))
	var accent: Color = visual_profile.get("accent", Color("4db7a8"))
	var image := Image.create(DESKTOP_OVERVIEW_OUTPUT_SIZE.x, DESKTOP_OVERVIEW_OUTPUT_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(body_color.darkened(0.12))
	image.fill_rect(Rect2i(0, 0, DESKTOP_OVERVIEW_OUTPUT_SIZE.x, DESKTOP_OVERVIEW_HEADER_HEIGHT), Color(0.018, 0.026, 0.032, 1.0))
	var hero_panel := _create_adaptive_banner(visual_profile, card_database, DESKTOP_OVERVIEW_HERO_SIZE)
	image.blit_rect(hero_panel, Rect2i(Vector2i.ZERO, hero_panel.get_size()), Vector2i.ZERO)
	image.fill_rect(Rect2i(692, 42, 6, 154), accent)
	image.fill_rect(Rect2i(0, DESKTOP_OVERVIEW_HEADER_HEIGHT, DESKTOP_OVERVIEW_OUTPUT_SIZE.x, 4), accent)

	var entries := _poster_card_entries(deck)
	var metrics: Dictionary = layout.get("metrics", {})
	var columns := int(metrics.get("columns", DESKTOP_OVERVIEW_MAX_COLUMNS))
	var origin: Vector2i = metrics.get("origin", DESKTOP_OVERVIEW_GRID_RECT.position)
	var image_size: Vector2i = metrics.get("image_size", Vector2i(180, 252))
	var column_gap := int(metrics.get("column_gap", DESKTOP_OVERVIEW_COLUMN_GAP))
	var row_gap := int(metrics.get("row_gap", DESKTOP_OVERVIEW_ROW_GAP))
	var missing_image_count := 0
	for i: int in entries.size():
		var col := i % columns
		var row := int(i / columns)
		var pos := origin + Vector2i(col * (image_size.x + column_gap), row * (image_size.y + row_gap))
		image.fill_rect(Rect2i(pos + Vector2i(4, 5), image_size), Color(0, 0, 0, 0.42))
		var entry: Dictionary = entries[i]
		var card_image := _load_card_image_for_entry(entry, card_database)
		if card_image == null:
			missing_image_count += 1
			image.fill_rect(Rect2i(pos, image_size), Color(0.15, 0.17, 0.18, 1.0))
			image.fill_rect(Rect2i(pos + Vector2i(2, 2), image_size - Vector2i(4, 4)), Color(0.22, 0.24, 0.25, 1.0))
		else:
			card_image.resize(image_size.x, image_size.y, Image.INTERPOLATE_LANCZOS)
			image.blit_rect(card_image, Rect2i(Vector2i.ZERO, image_size), pos)
		_add_count_badge_to_raster(image, pos, image_size, int(entry.get("count", 1)))
	return {"ok": true, "image": image, "errors": errors, "missing_image_count": missing_image_count}


static func _prepare_display_strip_image(strip_image: Image, target_size: Vector2i) -> Image:
	var display := strip_image.duplicate()
	display.resize(target_size.x, target_size.y, Image.INTERPOLATE_NEAREST)
	return display


static func _add_card_placeholder(root: Control, pos: Vector2, size: Vector2i, entry: Dictionary) -> void:
	var proxy_script := load(CARD_IMAGE_PROXY_VIEW_PATH) as GDScript
	if proxy_script == null:
		return
	var proxy := proxy_script.new() as Control
	if proxy == null:
		return
	proxy.position = pos
	proxy.size = size
	proxy.setup_from_entry(entry, null, {"portrait": true})
	root.add_child(proxy)


static func _add_card_count_label(root: Control, pos: Vector2, image_size: Vector2i, count: int) -> void:
	if count <= 1:
		return
	var badge_pos := pos + Vector2(image_size.x - COUNT_BADGE_SIZE.x - 6, image_size.y - COUNT_BADGE_SIZE.y - 6)
	var badge := Panel.new()
	badge.position = badge_pos
	badge.size = COUNT_BADGE_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.86)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	badge.add_theme_stylebox_override("panel", style)
	root.add_child(badge)

	var label := Label.new()
	label.text = "X%d" % count
	label.position = Vector2.ZERO
	label.size = COUNT_BADGE_SIZE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color.WHITE)
	badge.add_child(label)


static func _add_count_badge_to_raster(image: Image, pos: Vector2i, image_size: Vector2i, count: int) -> void:
	if count <= 1:
		return
	var badge_pos := pos + Vector2i(image_size.x - COUNT_BADGE_SIZE.x - 6, image_size.y - COUNT_BADGE_SIZE.y - 6)
	image.fill_rect(Rect2i(badge_pos, COUNT_BADGE_SIZE), Color(0, 0, 0, 0.86))


static func _add_label(parent: Control, text: String, position: Vector2, size: Vector2, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.clip_text = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


static func _add_banner_title(parent: Control, deck_name: String, author: String, visual_profile: Dictionary = {}) -> void:
	var title_font := ResourceLoader.load(TITLE_FONT_PATH, "FontFile", ResourceLoader.CACHE_MODE_REUSE) as Font
	var accent: Color = visual_profile.get("accent", Color("4db7a8"))
	var accent_bar := ColorRect.new()
	accent_bar.position = Vector2(GENERIC_TITLE_TEXT_RECT.position.x - 18, GENERIC_TITLE_TEXT_RECT.position.y + 11)
	accent_bar.size = Vector2(5, 40)
	accent_bar.color = accent
	parent.add_child(accent_bar)

	var title := deck_name.strip_edges()
	if title == "":
		title = "卡组图"
	var title_size := _fit_title_font_size(title, title_font, GENERIC_TITLE_MAX_FONT_SIZE, GENERIC_TITLE_MIN_FONT_SIZE, GENERIC_TITLE_TEXT_RECT.size.x)
	var title_label := _add_label(parent, title, GENERIC_TITLE_TEXT_RECT.position, GENERIC_TITLE_TEXT_RECT.size, title_size, Color(0.97, 0.98, 0.98, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	title_label.set_meta("deck_share_text_role", "generic_title")
	_style_clean_title_label(title_label, title_font)

	var author_label := _add_label(parent, "作者 / %s" % author, AUTHOR_TEXT_RECT.position, AUTHOR_TEXT_RECT.size, 18, Color(0.82, 0.86, 0.87, 0.88), HORIZONTAL_ALIGNMENT_LEFT)
	if title_font != null:
		author_label.add_theme_font_override("font", title_font)
	author_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	author_label.add_theme_constant_override("shadow_offset_y", 2)

	var site_url_label := _add_label(parent, SITE_URL_TEXT, SITE_URL_TEXT_RECT.position, SITE_URL_TEXT_RECT.size, 18, Color(0.86, 0.94, 1.0, 0.96), HORIZONTAL_ALIGNMENT_RIGHT)
	site_url_label.set_meta("deck_share_text_role", "site_url")
	if title_font != null:
		site_url_label.add_theme_font_override("font", title_font)
	site_url_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.06, 0.96))
	site_url_label.add_theme_constant_override("outline_size", 3)


static func _style_clean_title_label(label: Label, font: Font) -> void:
	label.clip_text = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.pivot_offset = label.size * 0.5
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.018, 0.88))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
	label.add_theme_constant_override("shadow_offset_y", 3)


static func _banner_title_parts(deck_name: String) -> Dictionary:
	var clean_name := deck_name.strip_edges()
	for series_prefix: String in ["18.0", "NAIC2025"]:
		if clean_name.begins_with(series_prefix):
			return {
				"prefix": series_prefix,
				"title": clean_name.substr(series_prefix.length()).strip_edges(),
			}
	return {"prefix": "", "title": clean_name}


static func _add_competitive_banner_title(parent: Control, font: Font, title_parts: Dictionary, author: String, background_id: String = "") -> void:
	var prefix := str(title_parts.get("prefix", ""))
	var title := str(title_parts.get("title", "")).strip_edges()
	if title == "":
		title = prefix
		prefix = ""
	if title == "":
		title = "卡组图"
	if prefix == "":
		var title_layout := _title_layout_for_background(background_id)
		var title_rect: Rect2i = title_layout.get("rect", GENERIC_TITLE_TEXT_RECT)
		var max_font_size := int(title_layout.get("max_font_size", GENERIC_TITLE_MAX_FONT_SIZE))
		var min_font_size := int(title_layout.get("min_font_size", GENERIC_TITLE_MIN_FONT_SIZE))
		var single_font_size := _fit_title_font_size(title, font, max_font_size, min_font_size, float(title_rect.size.x) / ART_TITLE_SCALE_X)
		var title_label := _add_art_text_stack(parent, title, Vector2(title_rect.position), Vector2(title_rect.size), single_font_size, font, Color(0.98, 0.98, 1.0, 1.0), Color(0.11, 0.96, 1.0, 0.78), Color(0.82, 0.10, 0.94, 0.78), HORIZONTAL_ALIGNMENT_CENTER)
		if title_label != null:
			title_label.set_meta("deck_share_text_role", "generic_title")
		_add_author_plate(parent, font, author, background_id)
		return
	var top_pos := Vector2(142, 246)
	var top_size := Vector2(760, 92)
	var main_pos := Vector2(95, 324)
	var main_size := Vector2(890, 128)

	_add_art_text_stack(parent, prefix, top_pos, top_size, 104, font, Color(0.97, 0.98, 1.0, 1.0), Color(0.08, 0.94, 1.0, 0.80), Color(0.88, 0.12, 0.96, 0.72), HORIZONTAL_ALIGNMENT_CENTER)
	if title.begins_with("N"):
		_add_art_text_stack(parent, title.substr(1), Vector2(236, 324), Vector2(735, 128), 110, font, Color(0.98, 0.98, 1.0, 1.0), Color(0.11, 0.96, 1.0, 0.78), Color(0.82, 0.10, 0.94, 0.78), HORIZONTAL_ALIGNMENT_LEFT)
		var n_overlay := _add_label(parent, "N", Vector2(112, 316), Vector2(174, 138), 124, Color(0.73, 1.0, 0.19, 0.96), HORIZONTAL_ALIGNMENT_CENTER)
		_style_art_title_label(n_overlay, font, Color(0.05, 0.12, 0.02, 0.98), 12, Color(0.55, 1.0, 0.10, 0.70), -2, 7)
		n_overlay.scale = Vector2(1.08, 1.0)
	else:
		_add_art_text_stack(parent, title, main_pos, main_size, 110, font, Color(0.98, 0.98, 1.0, 1.0), Color(0.11, 0.96, 1.0, 0.78), Color(0.82, 0.10, 0.94, 0.78), HORIZONTAL_ALIGNMENT_CENTER)

	_add_author_plate(parent, font, author, background_id)


static func _title_layout_for_background(background_id: String) -> Dictionary:
	if normalize_background_id(background_id) == "gardevoir":
		return {
			"rect": GARDEVOIR_TITLE_TEXT_RECT,
			"max_font_size": GARDEVOIR_TITLE_MAX_FONT_SIZE,
			"min_font_size": GARDEVOIR_TITLE_MIN_FONT_SIZE,
		}
	return {
		"rect": GENERIC_TITLE_TEXT_RECT,
		"max_font_size": GENERIC_TITLE_MAX_FONT_SIZE,
		"min_font_size": GENERIC_TITLE_MIN_FONT_SIZE,
	}


static func _add_art_text_stack(parent: Control, text: String, position: Vector2, size: Vector2, font_size: int, font: Font, fill: Color, cyan: Color, magenta: Color, alignment: HorizontalAlignment) -> Label:
	if text == "":
		return null
	var shadow := _add_label(parent, text, position + Vector2(9, 13), size, font_size, Color(0.03, 0.01, 0.06, 0.96), alignment)
	_style_art_title_label(shadow, font, Color(0.02, 0.00, 0.05, 1.0), 18, Color(0, 0, 0, 0.0), 0, 0)
	shadow.scale = Vector2(ART_TITLE_SCALE_X, 1.0)
	var magenta_layer := _add_label(parent, text, position + Vector2(6, 3), size, font_size, magenta, alignment)
	_style_art_title_label(magenta_layer, font, Color(0.06, 0.00, 0.13, 0.96), 14, Color(0.90, 0.10, 1.0, 0.70), 0, 6)
	magenta_layer.scale = Vector2(ART_TITLE_SCALE_X, 1.0)
	var cyan_layer := _add_label(parent, text, position + Vector2(-5, -2), size, font_size, cyan, alignment)
	_style_art_title_label(cyan_layer, font, Color(0.01, 0.08, 0.12, 0.92), 10, Color(0.05, 0.92, 1.0, 0.72), 0, 5)
	cyan_layer.scale = Vector2(ART_TITLE_SCALE_X, 1.0)
	var face := _add_label(parent, text, position, size, font_size, fill, alignment)
	_style_art_title_label(face, font, Color(0.03, 0.00, 0.08, 1.0), 8, Color(0.02, 0.78, 1.0, 0.58), 0, 5)
	face.scale = Vector2(ART_TITLE_SCALE_X, 1.0)
	return face


static func _add_author_plate(parent: Control, font: Font, author: String, background_id: String = "") -> void:
	if normalize_background_id(background_id) == "gardevoir":
		_add_gardevoir_author_plate(parent, font, author)
		return
	var plate := Polygon2D.new()
	plate.position = Vector2(0, 0)
	plate.polygon = PackedVector2Array([
		Vector2(390, 463),
		Vector2(690, 463),
		Vector2(724, 492),
		Vector2(690, 522),
		Vector2(390, 522),
		Vector2(356, 492),
	])
	plate.color = Color(0.04, 0.08, 0.14, 0.92)
	parent.add_child(plate)

	var plate_border := Line2D.new()
	plate_border.position = Vector2(0, 0)
	plate_border.points = PackedVector2Array([
		Vector2(390, 456),
		Vector2(692, 456),
		Vector2(734, 492),
		Vector2(692, 529),
		Vector2(390, 529),
		Vector2(346, 492),
		Vector2(390, 456),
	])
	plate_border.width = 5.0
	plate_border.default_color = Color(0.03, 0.95, 0.86, 0.80)
	plate_border.joint_mode = Line2D.LINE_JOINT_SHARP
	parent.add_child(plate_border)

	var author_label := _add_label(parent, "作者：%s" % author, Vector2(382, 463), Vector2(316, 58), 34, Color(0.93, 0.97, 1.0, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_style_art_title_label(author_label, font, Color(0.03, 0.00, 0.08, 0.98), 5, Color(0.07, 0.95, 0.92, 0.62), 0, 3)


static func _add_gardevoir_author_plate(parent: Control, font: Font, author: String) -> void:
	var plate := Polygon2D.new()
	plate.position = Vector2(0, 0)
	plate.polygon = PackedVector2Array([
		Vector2(424, 514),
		Vector2(656, 514),
		Vector2(684, 539),
		Vector2(656, 564),
		Vector2(424, 564),
		Vector2(396, 539),
	])
	plate.color = Color(0.035, 0.07, 0.12, 0.88)
	parent.add_child(plate)

	var plate_border := Line2D.new()
	plate_border.position = Vector2(0, 0)
	plate_border.points = PackedVector2Array([
		Vector2(424, 509),
		Vector2(658, 509),
		Vector2(692, 539),
		Vector2(658, 569),
		Vector2(424, 569),
		Vector2(388, 539),
		Vector2(424, 509),
	])
	plate_border.width = 4.0
	plate_border.default_color = Color(0.03, 0.95, 0.86, 0.74)
	plate_border.joint_mode = Line2D.LINE_JOINT_SHARP
	parent.add_child(plate_border)

	var author_label := _add_label(parent, "作者：%s" % author, Vector2(410, 515), Vector2(260, 48), 26, Color(0.93, 0.97, 1.0, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_style_art_title_label(author_label, font, Color(0.03, 0.00, 0.08, 0.98), 4, Color(0.07, 0.95, 0.92, 0.54), 0, 2)


static func _style_art_title_label(label: Label, font: Font, outline_color: Color, outline_size: int, shadow_color: Color, shadow_x: int, shadow_y: int) -> void:
	label.clip_text = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.pivot_offset = label.size * 0.5
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_color_override("font_shadow_color", shadow_color)
	label.add_theme_constant_override("shadow_offset_x", shadow_x)
	label.add_theme_constant_override("shadow_offset_y", shadow_y)


static func _fit_title_font_size(text: String, font: Font, max_size: int, min_size: int, max_width: float) -> int:
	for font_size: int in range(max_size, min_size - 1, -2):
		if _measure_title_width(text, font, font_size) <= max_width:
			return font_size
	return min_size


static func _measure_title_width(text: String, font: Font, font_size: int) -> float:
	if font != null:
		return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var weighted_width := 0.0
	for i: int in text.length():
		var codepoint := text.unicode_at(i)
		weighted_width += 1.0 if codepoint > 127 else 0.56
	return weighted_width * float(font_size)


static func _result(ok: bool, image: Image, encoded_text: String, payload: Dictionary, errors: PackedStringArray, missing_image_count: int, code_rect: Rect2i = Rect2i()) -> Dictionary:
	return {
		"ok": ok and errors.is_empty(),
		"image": image,
		"encoded_text": encoded_text,
		"payload": payload,
		"errors": errors,
		"missing_image_count": missing_image_count,
		"code_rect": code_rect,
	}
