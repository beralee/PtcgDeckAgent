class_name StarterDeckGenerator
extends RefCounted

const BUNDLED_DECKS_DIR := "res://data/bundled_user/decks"
const GENERATED_SOURCE_PROVIDER := "starter_generator"
const GENERATED_ID_MIN := 1000000000
const GENERATED_ID_SPAN := 900000000

const POKEMON_TYPE_OPTIONS: Array[Dictionary] = [
	{"id": "", "label": "自动推荐"},
	{"id": "R", "label": "火"},
	{"id": "W", "label": "水"},
	{"id": "G", "label": "草"},
	{"id": "L", "label": "雷"},
	{"id": "P", "label": "超"},
	{"id": "F", "label": "斗"},
	{"id": "D", "label": "恶"},
	{"id": "M", "label": "钢"},
	{"id": "N", "label": "龙"},
	{"id": "C", "label": "无色"},
]

const AXIS_OPTIONS: Array[Dictionary] = [
	{"id": "auto", "label": "自动推荐"},
	{"id": "basic", "label": "基础主攻"},
	{"id": "stage1", "label": "一阶进化"},
	{"id": "stage2", "label": "二阶进化"},
]

const PACE_OPTIONS: Array[Dictionary] = [
	{"id": "fast", "label": "快速展开"},
	{"id": "balanced", "label": "均衡"},
	{"id": "control", "label": "稳健控制"},
]


func build_bundled_catalog(card_lookup: Callable) -> Array[Dictionary]:
	return build_catalog(load_bundled_templates(), card_lookup)


func load_bundled_templates() -> Array[DeckData]:
	var templates: Array[DeckData] = []
	var dir := DirAccess.open(BUNDLED_DECKS_DIR)
	if dir == null:
		return templates
	var file_names := PackedStringArray()
	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while entry_name != "":
		if not dir.current_is_dir() and entry_name.ends_with(".json"):
			file_names.append(entry_name)
		entry_name = dir.get_next()
	dir.list_dir_end()
	file_names.sort()

	for file_name: String in file_names:
		var path := BUNDLED_DECKS_DIR.path_join(file_name)
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Dictionary:
			templates.append(DeckData.from_dict(parsed as Dictionary))
	return templates


func build_catalog(templates: Array[DeckData], card_lookup: Callable) -> Array[Dictionary]:
	var catalog: Array[Dictionary] = []
	if not card_lookup.is_valid():
		return catalog
	for deck: DeckData in templates:
		if deck == null:
			continue
		var validation := validate_generated_deck(deck, card_lookup)
		if not validation.is_empty():
			continue
		var analysis := analyze_deck(deck, card_lookup)
		if int(analysis.get("basic_pokemon", 0)) <= 0:
			continue
		catalog.append({
			"deck": deck,
			"analysis": analysis,
		})
	return catalog


func validate_generated_deck(deck: DeckData, card_lookup: Callable) -> PackedStringArray:
	var errors := PackedStringArray()
	if deck == null:
		errors.append("卡组不存在")
		return errors
	for error: String in deck.validate():
		errors.append(error)
	if not card_lookup.is_valid():
		errors.append("卡牌查询不可用")
		return errors

	var actual_total := 0
	var basic_pokemon := 0
	var ace_spec_count := 0
	var radiant_count := 0
	for entry: Dictionary in deck.cards:
		var count := int(entry.get("count", 0))
		if count <= 0:
			errors.append("卡牌数量必须大于 0")
			continue
		actual_total += count
		var card := card_lookup.call(str(entry.get("set_code", "")), str(entry.get("card_index", ""))) as CardData
		if card == null:
			errors.append("缺少卡牌：%s_%s" % [str(entry.get("set_code", "")), str(entry.get("card_index", ""))])
			continue
		if card.card_type == "Pokemon" and card.stage == "Basic":
			basic_pokemon += count
		if _card_has_tag(card, "ACE SPEC"):
			ace_spec_count += count
		if _card_has_tag(card, "Radiant"):
			radiant_count += count

	if actual_total != 60 or actual_total != deck.total_cards:
		errors.append("卡组实际数量为 %d，必须为 60" % actual_total)
	if basic_pokemon <= 0:
		errors.append("卡组至少需要 1 只基础宝可梦")
	if ace_spec_count > 1:
		errors.append("ACE SPEC 最多只能放入 1 张")
	if radiant_count > 1:
		errors.append("光辉宝可梦最多只能放入 1 张")
	return errors


func analyze_deck(deck: DeckData, card_lookup: Callable) -> Dictionary:
	var type_scores: Dictionary = {}
	var basic_energy_counts: Dictionary = {}
	var pokemon_count := 0
	var basic_pokemon := 0
	var stage1_pokemon := 0
	var stage2_pokemon := 0
	var trainer_count := 0
	var energy_count := 0
	var special_energy_count := 0
	var missing_cards := 0
	var best_core_name := ""
	var best_core_score := -1.0
	var deck_name_key := _normalized_name(deck.deck_name)

	for entry: Dictionary in deck.cards:
		var count := int(entry.get("count", 0))
		var card := card_lookup.call(str(entry.get("set_code", "")), str(entry.get("card_index", ""))) as CardData
		if card == null:
			missing_cards += maxi(count, 0)
			continue
		match card.card_type:
			"Pokemon":
				pokemon_count += count
				match card.stage:
					"Basic":
						basic_pokemon += count
					"Stage 1":
						stage1_pokemon += count
					"Stage 2":
						stage2_pokemon += count
				var card_score := _pokemon_core_score(deck_name_key, card, count)
				var energy_type := card.energy_type.strip_edges().to_upper()
				if energy_type != "":
					type_scores[energy_type] = float(type_scores.get(energy_type, 0.0)) + card_score
				if card_score > best_core_score:
					best_core_score = card_score
					best_core_name = card.display_name()
			"Basic Energy":
				energy_count += count
				var provided := card.energy_provides.strip_edges().to_upper()
				if provided != "":
					basic_energy_counts[provided] = int(basic_energy_counts.get(provided, 0)) + count
			"Special Energy":
				energy_count += count
				special_energy_count += count
			_:
				trainer_count += count

	return {
		"pokemon": pokemon_count,
		"basic_pokemon": basic_pokemon,
		"stage1_pokemon": stage1_pokemon,
		"stage2_pokemon": stage2_pokemon,
		"trainer": trainer_count,
		"energy": energy_count,
		"special_energy": special_energy_count,
		"missing_cards": missing_cards,
		"type_scores": type_scores,
		"basic_energy_counts": basic_energy_counts,
		"core_name": best_core_name,
	}


func select_template(catalog: Array[Dictionary], request: Dictionary) -> Dictionary:
	if catalog.is_empty():
		return {"ok": false, "error": "没有可用的内置卡组模板"}
	var energy_type := str(request.get("energy_type", "")).strip_edges().to_upper()
	var axis := str(request.get("axis", "auto")).strip_edges().to_lower()
	var pace := str(request.get("pace", "balanced")).strip_edges().to_lower()
	var candidates := _matching_candidates(catalog, energy_type, axis, true)
	var used_axis_fallback := false
	if candidates.is_empty():
		candidates = _matching_candidates(catalog, energy_type, axis, false)
		used_axis_fallback = true
	if candidates.is_empty():
		return {"ok": false, "error": "当前选项没有匹配的内置卡组"}

	var best_entry: Dictionary = {}
	var best_score := -INF
	var best_id := 0
	for entry: Dictionary in candidates:
		var deck := entry.get("deck") as DeckData
		var analysis: Dictionary = entry.get("analysis", {})
		if deck == null:
			continue
		var score := _template_score(deck, analysis, energy_type, axis, pace)
		if score > best_score or (is_equal_approx(score, best_score) and deck.id > best_id):
			best_score = score
			best_id = deck.id
			best_entry = entry
	if best_entry.is_empty():
		return {"ok": false, "error": "无法选择卡组模板"}

	return {
		"ok": true,
		"deck": best_entry.get("deck"),
		"analysis": (best_entry.get("analysis", {}) as Dictionary).duplicate(true),
		"score": best_score,
		"axis_fallback": used_axis_fallback,
	}


func generate_deck(catalog: Array[Dictionary], request: Dictionary, existing_decks: Array, now_msec: int = -1) -> Dictionary:
	var selected := select_template(catalog, request)
	if not bool(selected.get("ok", false)):
		return selected
	var template := selected.get("deck") as DeckData
	if template == null:
		return {"ok": false, "error": "卡组模板不存在"}
	var timestamp := now_msec
	if timestamp < 0:
		timestamp = int(Time.get_unix_time_from_system() * 1000.0)

	var generated := DeckData.new()
	generated.id = _next_deck_id(existing_decks, timestamp)
	var requested_name := str(request.get("deck_name", "")).strip_edges()
	var base_name := requested_name if requested_name != "" else _default_deck_name(template)
	generated.deck_name = _unique_deck_name(base_name, existing_decks)
	generated.source_url = ""
	generated.source_provider = GENERATED_SOURCE_PROVIDER
	generated.source_id = str(template.id)
	generated.import_date = Time.get_datetime_string_from_system()
	generated.updated_at = timestamp
	generated.variant_name = ""
	generated.deck_code = ""
	generated.strategy = template.strategy
	generated.cards.clear()
	generated.total_cards = 0
	for entry: Dictionary in template.cards:
		var copied_entry := entry.duplicate(true)
		generated.cards.append(copied_entry)
		generated.total_cards += int(copied_entry.get("count", 0))

	var result := selected.duplicate(true)
	result["deck"] = generated
	result["template_deck"] = template
	result["template_name"] = template.deck_name
	result["ok"] = true
	return result


func suggested_deck_name(selection: Dictionary, existing_decks: Array) -> String:
	var template := selection.get("deck") as DeckData
	if template == null:
		return _unique_deck_name("我的新卡组", existing_decks)
	return _unique_deck_name(_default_deck_name(template), existing_decks)


func _matching_candidates(catalog: Array[Dictionary], energy_type: String, axis: String, enforce_axis: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in catalog:
		var analysis: Dictionary = entry.get("analysis", {})
		var type_scores: Dictionary = analysis.get("type_scores", {})
		if energy_type != "" and float(type_scores.get(energy_type, 0.0)) <= 0.0:
			continue
		if enforce_axis and not _analysis_matches_axis(analysis, axis):
			continue
		result.append(entry)
	return result


func _analysis_matches_axis(analysis: Dictionary, axis: String) -> bool:
	match axis:
		"basic":
			return int(analysis.get("basic_pokemon", 0)) > 0 and int(analysis.get("stage2_pokemon", 0)) == 0
		"stage1":
			return int(analysis.get("stage1_pokemon", 0)) > 0 and int(analysis.get("stage2_pokemon", 0)) == 0
		"stage2":
			return int(analysis.get("stage2_pokemon", 0)) > 0
		_:
			return true


func _template_score(deck: DeckData, analysis: Dictionary, energy_type: String, axis: String, pace: String) -> float:
	var score := _release_score(deck.deck_name)
	var type_scores: Dictionary = analysis.get("type_scores", {})
	if energy_type != "":
		var selected_type_score := float(type_scores.get(energy_type, 0.0))
		var max_type_score := 0.0
		for value: Variant in type_scores.values():
			max_type_score = maxf(max_type_score, float(value))
		if max_type_score > 0.0:
			score += selected_type_score / max_type_score * 280.0
		if is_equal_approx(selected_type_score, max_type_score):
			score += 120.0

	var basic := float(analysis.get("basic_pokemon", 0))
	var stage1 := float(analysis.get("stage1_pokemon", 0))
	var stage2 := float(analysis.get("stage2_pokemon", 0))
	match axis:
		"basic":
			score += basic * 6.0 - stage1 * 3.0 - stage2 * 16.0 + (90.0 if stage2 <= 0.0 else 0.0)
		"stage1":
			score += stage1 * 13.0 - stage2 * 18.0 + (90.0 if stage1 > 0.0 and stage2 <= 0.0 else 0.0)
		"stage2":
			score += stage2 * 18.0 + stage1 * 5.0 + (110.0 if stage2 > 0.0 else 0.0)

	var pokemon := float(analysis.get("pokemon", 0))
	var trainer := float(analysis.get("trainer", 0))
	var energy := float(analysis.get("energy", 0))
	match pace:
		"fast":
			score += basic * 4.5 - stage2 * 4.0 + maxf(0.0, 18.0 - pokemon) * 2.0
		"control":
			score += (trainer - 30.0) * 6.0 + maxf(0.0, 16.0 - pokemon) * 3.0
			if deck.deck_name.contains("控制") or deck.deck_name.contains("卡比兽"):
				score += 120.0
		_:
			score += 130.0 - absf(pokemon - 18.0) * 5.0 - absf(trainer - 33.0) * 2.5 - absf(energy - 9.0) * 2.0
	return score


func _release_score(deck_name: String) -> float:
	var normalized := deck_name.strip_edges()
	if normalized.begins_with("18.0"):
		return 120.0
	if normalized.begins_with("17.5"):
		return 80.0
	if normalized.begins_with("17.0"):
		return 55.0
	return 20.0


func _pokemon_core_score(deck_name_key: String, card: CardData, count: int) -> float:
	var score := float(count)
	if not card.attacks.is_empty():
		score += float(count) * 2.0
	if card.mechanic.strip_edges() != "":
		score += float(count) * 2.5
	var card_name_key := _normalized_name(card.display_name())
	var identity_key := _pokemon_identity_key(card_name_key)
	if identity_key.length() >= 2 and (deck_name_key.contains(identity_key) or identity_key.contains(deck_name_key)):
		score += 24.0
	return score


func _pokemon_identity_key(value: String) -> String:
	var result := value
	for suffix: String in ["ex", "vstar", "vmax", "v"]:
		if result.ends_with(suffix):
			result = result.left(result.length() - suffix.length())
			break
	return result


func _normalized_name(value: String) -> String:
	return value.strip_edges().to_lower().replace(" ", "").replace("　", "")


func _card_has_tag(card: CardData, expected_tag: String) -> bool:
	var normalized_expected := expected_tag.strip_edges().to_upper()
	if card.mechanic.strip_edges().to_upper() == normalized_expected:
		return true
	for tag: String in card.is_tags:
		if tag.strip_edges().to_upper() == normalized_expected:
			return true
	return false


func _default_deck_name(template: DeckData) -> String:
	var base_name := template.deck_name.strip_edges()
	var first_space := base_name.find(" ")
	if first_space > 0:
		var prefix := base_name.left(first_space)
		if prefix.is_valid_float():
			base_name = base_name.substr(first_space + 1).strip_edges()
	if base_name == "":
		base_name = "我的"
	return "%s 新卡组" % base_name


func _unique_deck_name(base_name: String, existing_decks: Array) -> String:
	var normalized_base := base_name.strip_edges()
	if normalized_base == "":
		normalized_base = "我的新卡组"
	var existing_names: Dictionary = {}
	for deck_raw: Variant in existing_decks:
		var deck := deck_raw as DeckData
		if deck != null:
			existing_names[deck.deck_name.strip_edges()] = true
	if not existing_names.has(normalized_base):
		return normalized_base
	var suffix := 2
	while existing_names.has("%s %d" % [normalized_base, suffix]):
		suffix += 1
	return "%s %d" % [normalized_base, suffix]


func _next_deck_id(existing_decks: Array, now_msec: int) -> int:
	var used_ids: Dictionary = {}
	for deck_raw: Variant in existing_decks:
		var deck := deck_raw as DeckData
		if deck != null:
			used_ids[deck.id] = true
	var candidate := GENERATED_ID_MIN + int(absi(now_msec) % GENERATED_ID_SPAN)
	while used_ids.has(candidate):
		candidate += 1
		if candidate >= GENERATED_ID_MIN + GENERATED_ID_SPAN:
			candidate = GENERATED_ID_MIN
	return candidate
