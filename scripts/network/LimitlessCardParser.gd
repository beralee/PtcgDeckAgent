class_name LimitlessCardParser
extends RefCounted

const SOURCE_PROVIDER := "limitless"
const PARSER_VERSION := 1
const DECK_ID_OFFSET := 800000000
const BASE_URL := "https://limitlesstcg.com"
const ACE_SPEC_REFS := {
	"TWM/163": true,
}


static func limitless_deck_local_id(limitless_id: int) -> int:
	return DECK_ID_OFFSET + limitless_id


static func card_url(set_code: String, card_number: String) -> String:
	return "%s/cards/%s/%s" % [BASE_URL, normalize_set_code(set_code), normalize_card_number(card_number)]


static func normalize_set_code(value: Variant) -> String:
	return str(value).strip_edges().to_upper()


static func normalize_card_number(value: Variant) -> String:
	var text := str(value).strip_edges()
	if text.is_valid_int():
		return str(int(text))
	return text.to_upper()


static func card_ref_key(set_code: Variant, card_number: Variant) -> String:
	var normalized_set := normalize_set_code(set_code)
	var normalized_number := normalize_card_number(card_number)
	if normalized_set == "" or normalized_number == "":
		return ""
	return "%s/%s" % [normalized_set, normalized_number]


static func parse_card_ref_from_url(url: String) -> Dictionary:
	var regex := RegEx.new()
	regex.compile("(?i)(?:^|/)cards/([^/?#]+)/([^/?#]+)")
	var result := regex.search(url)
	if result == null:
		return {}
	return {
		"set_code": normalize_set_code(result.get_string(1)),
		"card_index": normalize_card_number(result.get_string(2)),
		"ref": card_ref_key(result.get_string(1), result.get_string(2)),
	}


static func parse_card_html(html: String, source_url: String = "") -> Dictionary:
	var ref := parse_card_ref_from_url(source_url)
	var set_code := str(ref.get("set_code", ""))
	var card_index := str(ref.get("card_index", ""))
	var image_url := _extract_image_url(html)
	if set_code == "" or card_index == "":
		var image_ref := _parse_ref_from_image_url(image_url)
		set_code = str(image_ref.get("set_code", set_code))
		card_index = str(image_ref.get("card_index", card_index))

	var title_line := _strip_tags(_first_match("(?is)<p[^>]+class=[\"'][^\"']*card-text-title[^\"']*[\"'][^>]*>(.*?)</p>", html))
	var name := _normalize_card_name(_strip_tags(_first_match("(?is)<[^>]+class=[\"'][^\"']*card-text-name[^\"']*[\"'][^>]*>(.*?)</[^>]+>", html)))
	if name == "":
		name = _normalize_card_name(title_line)
	if name == "":
		name = _normalize_card_name(_strip_tags(_first_match("(?is)<h1[^>]*>(.*?)</h1>", html)))
	var type_line := _strip_tags(_first_match("(?is)<[^>]+class=[\"'][^\"']*card-text-type[^\"']*[\"'][^>]*>(.*?)</[^>]+>", html))
	var detail_type_line := ("%s - %s" % [title_line, type_line]).strip_edges()
	var local_type := _map_card_type(type_line)
	var mechanic := _infer_mechanic(name, type_line, set_code, card_index)
	var tags := _tags_for_card(local_type, mechanic, type_line)
	var sections := _card_text_sections(html)

	var card := {
		"source_provider": SOURCE_PROVIDER,
		"source_url": source_url,
		"source_set_code": set_code,
		"source_card_index": card_index,
		"source_language": "en",
		"source_prints": _extract_same_print_refs(html, set_code, card_index),
		"source_parser_version": PARSER_VERSION,
		"name": name,
		"name_en": name,
		"card_type": local_type,
		"mechanic": mechanic,
		"label": mechanic,
		"description": "",
		"artist": _extract_artist(html),
		"set_code_en": set_code,
		"card_index_en": card_index,
		"rarity": _strip_tags(_first_match("(?is)<[^>]+class=[\"'][^\"']*prints-current-details[^\"']*[\"'][^>]*>(.*?)</[^>]+>", html)),
		"regulation_mark": _extract_regulation_mark(html),
		"image_url": image_url,
		"is_tags": tags,
		"energy_type": "",
		"stage": "",
		"hp": 0,
		"weakness_energy": "",
		"weakness_value": "",
		"resistance_energy": "",
		"resistance_value": "",
		"retreat_cost": 0,
		"evolves_from": "",
		"attacks": [],
		"abilities": [],
		"energy_provides": "",
	}

	if local_type == "Pokemon":
		_apply_pokemon_type_line(card, detail_type_line)
		_parse_pokemon_blocks(card, html, sections)
		_apply_pokemon_wrr(card, html)
	elif local_type == "Basic Energy":
		card["energy_provides"] = _infer_energy_from_name(name)
		card["description"] = ""
	else:
		card["description"] = _parse_trainer_description(sections, name, type_line)

	return card


static func parse_deck_html(html: String, source_url: String = "") -> Dictionary:
	var id := _extract_deck_id(source_url)
	var title := _normalize_deck_title(_strip_tags(_first_match("(?is)<[^>]+class=[\"'][^\"']*decklist-title[^\"']*[\"'][^>]*>(.*?)</[^>]+>", html)))
	if title == "":
		title = _normalize_deck_title(_strip_tags(_first_match("(?is)<h1[^>]*>(.*?)</h1>", html)))
	var current_section := ""
	var cards: Array[Dictionary] = []
	var token_regex := RegEx.new()
	token_regex.compile("(?is)<div[^>]+class=[\"'][^\"']*decklist-card[^\"']*[\"'][^>]*>.*?</div>|<[^>]+class=[\"'][^\"']*(?:decklist-title|decklist-column-title|decklist-section-title|decklist-category)[^\"']*[\"'][^>]*>.*?</[^>]+>")
	for token_match: RegExMatch in token_regex.search_all(html):
		var token := token_match.get_string(0)
		if _class_contains(token, "decklist-card"):
			var entry := _parse_deck_entry(token, current_section)
			if not entry.is_empty():
				cards.append(entry)
			continue
		var heading := _strip_tags(token)
		if _heading_to_section(heading) != "":
			current_section = _heading_to_section(heading)

	var total := 0
	for entry: Dictionary in cards:
		total += int(entry.get("count", 0))
	return {
		"source_provider": SOURCE_PROVIDER,
		"source_url": source_url,
		"source_id": str(id) if id > 0 else "",
		"id": limitless_deck_local_id(id) if id > 0 else 0,
		"deck_name": title,
		"cards": cards,
		"total_cards": total,
	}


static func _extract_deck_id(source_url: String) -> int:
	var regex := RegEx.new()
	regex.compile("(?i)(?:^|/)decks/list/(\\d+)")
	var result := regex.search(source_url)
	return int(result.get_string(1)) if result != null else 0


static func _parse_deck_entry(row: String, section: String) -> Dictionary:
	var set_code := normalize_set_code(_attr(row, "data-set"))
	var card_index := normalize_card_number(_attr(row, "data-number"))
	var lang := _attr(row, "data-lang")
	var basic_energy := _attr(row, "data-basic-energy")
	if set_code == "" and basic_energy != "":
		set_code = "SVE"
	if card_index == "" and basic_energy != "":
		card_index = normalize_card_number(basic_energy)
	if set_code == "" or card_index == "":
		return {}
	var count_text := _strip_tags(_first_match("(?is)<[^>]+class=[\"'][^\"']*(?:count|card-count)[^\"']*[\"'][^>]*>(.*?)</[^>]+>", row))
	if count_text == "":
		count_text = _first_match("^\\s*(\\d+)", _strip_tags(row))
	var count := int(count_text) if count_text.is_valid_int() else 1
	var name := _strip_tags(_first_match("(?is)<[^>]+class=[\"'][^\"']*(?:name|card-name)[^\"']*[\"'][^>]*>(.*?)</[^>]+>", row))
	if name == "":
		name = _attr(row, "data-name")
	if name == "":
		var plain := _strip_tags(row)
		name = _cleanup_deck_entry_name(plain, count_text, set_code, card_index)
	var card_type := section
	if basic_energy != "" or section == "Energy":
		card_type = "Basic Energy"
	return {
		"source_provider": SOURCE_PROVIDER,
		"source_set_code": set_code,
		"source_card_index": card_index,
		"source_language": lang if lang != "" else "en",
		"source_url": card_url(set_code, card_index),
		"source_name": name,
		"set_code": "",
		"card_index": "",
		"count": count,
		"card_type": card_type,
		"name": name,
		"name_en": name,
		"effect_id": "",
	}


static func _class_contains(tag: String, wanted_class: String) -> bool:
	return tag.find(wanted_class) >= 0


static func _heading_to_section(text: String) -> String:
	var normalized := text.strip_edges().to_lower()
	if normalized.begins_with("pokemon"):
		return "Pokemon"
	if normalized.begins_with("trainer"):
		return "Trainer"
	if normalized.begins_with("energy"):
		return "Energy"
	return ""


static func _cleanup_deck_entry_name(plain: String, count_text: String, set_code: String, card_index: String) -> String:
	var result := plain.strip_edges()
	if count_text != "" and result.begins_with(count_text):
		result = result.substr(count_text.length()).strip_edges()
	result = result.replace(set_code, "").replace(card_index, "").strip_edges()
	return result


static func _extract_image_url(html: String) -> String:
	var img_tag := _first_match("(?is)<img[^>]+(?:card|image|png|jpg|webp)[^>]*>", html, 0)
	if img_tag == "":
		img_tag = _first_match("(?is)<img[^>]*>", html, 0)
	var url := _attr(img_tag, "data-src")
	if url == "":
		url = _attr(img_tag, "src")
	return url


static func _parse_ref_from_image_url(image_url: String) -> Dictionary:
	var regex := RegEx.new()
	regex.compile("(?i)/([A-Z0-9]+)_0*([A-Z0-9]+)_R_EN\\.(?:png|jpg|webp)")
	var result := regex.search(image_url)
	if result == null:
		return {}
	return {
		"set_code": normalize_set_code(result.get_string(1)),
		"card_index": normalize_card_number(result.get_string(2)),
	}


static func _extract_same_print_refs(html: String, current_set: String, current_number: String) -> PackedStringArray:
	var seen := {}
	var refs := PackedStringArray()
	var current_ref := card_ref_key(current_set, current_number)
	if current_ref != "":
		seen[current_ref] = true
		refs.append(current_ref)
	var regex := RegEx.new()
	regex.compile("(?i)href=[\"']/cards/(?:(jp)/)?([^/\"']+)/([^/?\"'#]+)")
	for result: RegExMatch in regex.search_all(html):
		var ref := card_ref_key(result.get_string(2), result.get_string(3))
		if result.get_string(1).to_lower() == "jp" and ref != "":
			ref = "JP/%s" % ref
		if ref == "" or seen.has(ref):
			continue
		seen[ref] = true
		refs.append(ref)
	return refs


static func _extract_regulation_mark(html: String) -> String:
	var text := _strip_tags(_first_match("(?is)Regulation Mark\\s*</[^>]+>\\s*<[^>]+>(.*?)</[^>]+>", html))
	if text == "":
		text = _first_match("(?is)Regulation Mark\\s*:?\\s*([A-Z])", _strip_tags(html))
	if text == "":
		text = _first_match("(?is)([A-Z])\\s+Regulation Mark", _strip_tags(html))
	return text.strip_edges()


static func _extract_artist(html: String) -> String:
	var block := _strip_tags(_first_match("(?is)<div[^>]+class=[\"'][^\"']*card-text-artist[^\"']*[\"'][^>]*>(.*?)</div>", html))
	if block == "":
		return ""
	return block.replace("Illustrated by", "").strip_edges()


static func _card_text_sections(html: String) -> Array[String]:
	var sections: Array[String] = []
	var regex := RegEx.new()
	regex.compile("(?is)<div[^>]+class=[\"'][^\"']*card-text-section[^\"']*[\"'][^>]*>")
	var matches := regex.search_all(html)
	for result: RegExMatch in matches:
		var end := _find_matching_div_content_end(html, result.get_start())
		if end <= result.get_end():
			continue
		var section := _strip_tags(html.substr(result.get_end(), end - result.get_end()))
		if section != "":
			sections.append(section)
	return sections


static func _find_matching_div_content_end(html: String, open_start: int) -> int:
	var tag_regex := RegEx.new()
	tag_regex.compile("(?is)<(/?)div\\b[^>]*>")
	var depth := 0
	var tail := html.substr(open_start)
	for result: RegExMatch in tag_regex.search_all(tail):
		var is_close := result.get_string(1) == "/"
		if is_close:
			depth -= 1
			if depth == 0:
				return open_start + result.get_start()
		else:
			depth += 1
	return html.length()


static func _parse_trainer_description(sections: Array[String], name: String, type_line: String) -> String:
	var parts: Array[String] = []
	for section: String in sections:
		if section == "" or section == name or section == type_line:
			continue
		if name != "" and type_line != "" and section.contains(name) and section.contains(type_line):
			continue
		if section.begins_with("Regulation"):
			continue
		if section.begins_with("Illustrated by"):
			continue
		parts.append(section)
	return "\n".join(parts).strip_edges()


static func _parse_pokemon_blocks(card: Dictionary, html: String, sections: Array[String]) -> void:
	var attacks: Array[Dictionary] = []
	var abilities: Array[Dictionary] = []
	var ability_regex := RegEx.new()
	ability_regex.compile("(?is)<div[^>]+class=[\"'][^\"']*card-text-ability[^\"']*[\"'][^>]*>(.*?)</div>")
	for result: RegExMatch in ability_regex.search_all(html):
		var ability := _parse_ability_block(result.get_string(1))
		if not ability.is_empty():
			abilities.append(ability)
	var attack_regex := RegEx.new()
	attack_regex.compile("(?is)<div[^>]+class=[\"'][^\"']*card-text-attack[^\"']*[\"'][^>]*>(.*?)</div>")
	for result: RegExMatch in attack_regex.search_all(html):
		var attack := _parse_attack_block(result.get_string(1))
		if not attack.is_empty():
			attacks.append(attack)
	if not abilities.is_empty() or not attacks.is_empty():
		card["attacks"] = attacks
		card["abilities"] = abilities
		return
	for section: String in sections:
		var text := section.strip_edges()
		if text == "" or text == str(card.get("name", "")) or text == str(card.get("card_type", "")):
			continue
		var ability := _parse_ability_text(text)
		if not ability.is_empty():
			abilities.append(ability)
			continue
		var attack := _parse_attack_text(text)
		if not attack.is_empty():
			attacks.append(attack)
	card["attacks"] = attacks
	card["abilities"] = abilities


static func _parse_ability_block(block: String) -> Dictionary:
	var info := _strip_tags(_first_match("(?is)<p[^>]+class=[\"'][^\"']*card-text-ability-info[^\"']*[\"'][^>]*>(.*?)</p>", block))
	var effect := _strip_tags(_first_match("(?is)<p[^>]+class=[\"'][^\"']*card-text-ability-effect[^\"']*[\"'][^>]*>(.*?)</p>", block))
	var name := info.replace("Ability:", "").strip_edges()
	if name == "":
		return {}
	return {
		"name": name,
		"text": effect,
	}


static func _parse_attack_block(block: String) -> Dictionary:
	var info_html := _first_match("(?is)<p[^>]+class=[\"'][^\"']*card-text-attack-info[^\"']*[\"'][^>]*>(.*?)</p>", block)
	var effect := _strip_tags(_first_match("(?is)<p[^>]+class=[\"'][^\"']*card-text-attack-effect[^\"']*[\"'][^>]*>(.*?)</p>", block))
	var cost_text := _strip_tags(_first_match("(?is)<span[^>]+class=[\"'][^\"']*ptcg-symbol[^\"']*[\"'][^>]*>(.*?)</span>", info_html))
	var info := _strip_tags(info_html).strip_edges()
	if cost_text != "" and info.begins_with(cost_text):
		info = info.substr(cost_text.length()).strip_edges()
	var cost := _normalize_limitless_symbol_cost(cost_text)
	var damage := _first_match("(\\d+\\+?|\\d+x|\\d+×)$", info)
	var attack_name := info
	if damage != "":
		attack_name = info.trim_suffix(damage).strip_edges()
	if attack_name == "":
		return {}
	return {
		"name": attack_name,
		"text": effect,
		"cost": cost,
		"damage": damage.replace("×", "x"),
		"is_vstar_power": false,
	}


static func _parse_ability_text(text: String) -> Dictionary:
	var normalized := text.strip_edges()
	var regex := RegEx.new()
	regex.compile("(?is)^Ability\\s*:?\\s*([^\\n]+)\\n?(.*)$")
	var result := regex.search(normalized)
	if result == null:
		return {}
	return {
		"name": result.get_string(1).strip_edges(),
		"text": result.get_string(2).strip_edges(),
	}


static func _parse_attack_text(text: String) -> Dictionary:
	var normalized := text.strip_edges()
	var cost := PackedStringArray()
	var cost_regex := RegEx.new()
	cost_regex.compile("\\[([A-Z])\\]")
	for result: RegExMatch in cost_regex.search_all(normalized):
		cost.append(_map_energy_symbol(result.get_string(1)))
	var without_cost := cost_regex.sub(normalized, "", true).strip_edges()
	if without_cost == "":
		return {}
	var lines := without_cost.split("\n", false)
	if lines.is_empty():
		return {}
	var first_line := str(lines[0]).strip_edges()
	var damage := _first_match("(\\d+\\+?|\\d+x)$", first_line)
	var attack_name := first_line
	if damage != "":
		attack_name = first_line.trim_suffix(damage).strip_edges()
	var text_parts: Array[String] = []
	for i in range(1, lines.size()):
		text_parts.append(str(lines[i]).strip_edges())
	return {
		"name": attack_name,
		"text": "\n".join(text_parts).strip_edges(),
		"cost": "".join(cost),
		"damage": damage,
		"is_vstar_power": false,
	}


static func _apply_pokemon_type_line(card: Dictionary, type_line: String) -> void:
	var normalized_line := _normalize_pokemon_word(type_line).replace("\n", " ")
	var hp_text := _first_match("(\\d+)\\s*HP", normalized_line)
	if hp_text != "":
		card["hp"] = int(hp_text)
	var evolves_from := _first_match("(?i)Evolves\\s+from\\s+(.+)$", normalized_line)
	if evolves_from != "":
		card["evolves_from"] = evolves_from.strip_edges()
	for energy_name: String in ["Grass", "Fire", "Water", "Lightning", "Psychic", "Fighting", "Darkness", "Dragon", "Metal", "Colorless"]:
		if energy_name in normalized_line:
			card["energy_type"] = _map_energy_name(energy_name)
			break
	for stage_name: String in ["Stage 2", "Stage 1", "Basic"]:
		if stage_name in normalized_line:
			card["stage"] = stage_name
			break
	var parts := normalized_line.split(" - ", false)
	for part_variant: Variant in parts:
		var part := str(part_variant).strip_edges()
		if part in ["Basic", "Stage 1", "Stage 2"]:
			card["stage"] = part
		elif part.ends_with(" HP"):
			card["hp"] = int(part.trim_suffix(" HP").strip_edges())
		else:
			var energy := _map_energy_name(part)
			if energy != "":
				card["energy_type"] = energy
	if str(card.get("stage", "")) == "":
		card["stage"] = "Basic"


static func _apply_pokemon_wrr(card: Dictionary, html: String) -> void:
	var wrr := _strip_tags(_first_match("(?is)<p[^>]+class=[\"'][^\"']*card-text-wrr[^\"']*[\"'][^>]*>(.*?)</p>", html))
	if wrr == "":
		return
	_apply_weakness_line(card, _wrr_field(wrr, "Weakness"))
	_apply_resistance_line(card, _wrr_field(wrr, "Resistance"))
	var retreat := _first_match("(?i)Retreat:\\s*(\\d+)", wrr)
	if retreat != "":
		card["retreat_cost"] = int(retreat)


static func _wrr_field(text: String, field_name: String) -> String:
	var pattern := "(?is)%s:\\s*(.*?)(?:\\n|Weakness:|Resistance:|Retreat:|$)" % field_name
	return _first_match(pattern, text).strip_edges()


static func _apply_weakness_line(card: Dictionary, value: String) -> void:
	var parsed := _parse_energy_modifier(value, true)
	if parsed.is_empty():
		return
	card["weakness_energy"] = str(parsed.get("energy", ""))
	card["weakness_value"] = str(parsed.get("value", ""))


static func _apply_resistance_line(card: Dictionary, value: String) -> void:
	var parsed := _parse_energy_modifier(value, false)
	if parsed.is_empty():
		return
	card["resistance_energy"] = str(parsed.get("energy", ""))
	card["resistance_value"] = str(parsed.get("value", ""))


static func _parse_energy_modifier(value: String, is_weakness: bool) -> Dictionary:
	var text := value.strip_edges()
	if text == "" or text.to_lower().begins_with("none"):
		return {}
	var parts := text.split(" ", false)
	if parts.is_empty():
		return {}
	var energy := _map_energy_name(str(parts[0]))
	if energy == "":
		return {}
	var modifier := ""
	if parts.size() > 1:
		modifier = str(parts[1]).replace(char(0x00D7), "x").strip_edges()
	if modifier == "" and is_weakness:
		modifier = "x2"
	return {
		"energy": energy,
		"value": modifier,
	}


static func _map_card_type(type_line: String) -> String:
	var text := _normalize_pokemon_word(type_line).strip_edges()
	if text.begins_with("Pokemon"):
		return "Pokemon"
	if text.begins_with("Energy"):
		return "Basic Energy" if "Basic" in text else "Special Energy"
	if text.begins_with("Trainer"):
		for trainer_type: String in ["Supporter", "Item", "Tool", "Stadium"]:
			if trainer_type in text:
				return trainer_type
	return text


static func _normalize_pokemon_word(value: String) -> String:
	var text := value
	text = text.replace("Pok" + char(0x00E9) + "mon", "Pokemon")
	text = text.replace("Pok" + char(0x8305) + "mon", "Pokemon")
	return text


static func _infer_mechanic(name: String, type_line: String, set_code: String, card_index: String) -> String:
	var ref := card_ref_key(set_code, card_index)
	if ACE_SPEC_REFS.has(ref) or "ACE SPEC" in type_line:
		return "ACE SPEC"
	if name.ends_with(" ex"):
		return "ex"
	if name.ends_with(" VSTAR"):
		return "VSTAR"
	if name.ends_with(" VMAX"):
		return "VMAX"
	if name.ends_with(" V"):
		return "V"
	if name.begins_with("Radiant "):
		return "Radiant"
	return ""


static func _tags_for_card(card_type: String, mechanic: String, type_line: String) -> PackedStringArray:
	var tags := PackedStringArray()
	if card_type == "Pokemon":
		for stage_tag: String in ["Basic", "Stage 1", "Stage 2"]:
			if stage_tag in type_line:
				tags.append(stage_tag)
	if mechanic != "":
		tags.append(mechanic)
	return tags


static func _infer_energy_from_name(name: String) -> String:
	for key: String in {
		"Grass": "G",
		"Fire": "R",
		"Water": "W",
		"Lightning": "L",
		"Psychic": "P",
		"Fighting": "F",
		"Darkness": "D",
		"Dark": "D",
		"Metal": "M",
	}.keys():
		if key in name:
			return {
				"Grass": "G",
				"Fire": "R",
				"Water": "W",
				"Lightning": "L",
				"Psychic": "P",
				"Fighting": "F",
				"Darkness": "D",
				"Dark": "D",
				"Metal": "M",
			}[key]
	return "C"


static func _map_energy_name(name: String) -> String:
	if name == "Dragon":
		return "N"
	return _infer_energy_from_name(name) if name in ["Grass", "Fire", "Water", "Lightning", "Psychic", "Fighting", "Darkness", "Dark", "Metal", "Colorless"] else ""


static func _map_energy_symbol(symbol: String) -> String:
	var mapping := {
		"G": "G",
		"R": "R",
		"W": "W",
		"L": "L",
		"P": "P",
		"F": "F",
		"D": "D",
		"M": "M",
		"C": "C",
	}
	return str(mapping.get(symbol.to_upper(), symbol.to_upper()))


static func _normalize_limitless_symbol_cost(symbols: String) -> String:
	var result := ""
	for i in range(symbols.length()):
		var symbol := symbols.substr(i, 1)
		if symbol.strip_edges() == "":
			continue
		result += _map_energy_symbol(symbol)
	return result


static func _normalize_card_name(value: String) -> String:
	var text := value.strip_edges()
	var dash_index := text.find(" - ")
	if dash_index > 0:
		text = text.substr(0, dash_index).strip_edges()
	return text


static func _normalize_deck_title(value: String) -> String:
	var lines := value.replace("\r", "\n").split("\n", false)
	var price_regex := RegEx.new()
	price_regex.compile("(?is)^(.*?)\\s+\\d+(?:\\.\\d+)?\\$.*$")
	for raw_line: Variant in lines:
		var line := str(raw_line).strip_edges()
		if line == "":
			continue
		var price_match := price_regex.search(line)
		if price_match != null and price_match.get_string(1).strip_edges() != "":
			line = price_match.get_string(1).strip_edges()
		if line != "":
			return line
	return value.strip_edges()


static func _attr(tag: String, attr_name: String) -> String:
	if tag == "":
		return ""
	var regex := RegEx.new()
	regex.compile("(?is)\\b%s\\s*=\\s*[\"']([^\"']*)[\"']" % attr_name)
	var result := regex.search(tag)
	return _html_decode(result.get_string(1)) if result != null else ""


static func _first_match(pattern: String, text: String, group: int = 1) -> String:
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		return ""
	var result := regex.search(text)
	if result == null:
		return ""
	return result.get_string(group)


static func _strip_tags(value: String) -> String:
	var text := value.replace("<br>", "\n").replace("<br/>", "\n").replace("<br />", "\n")
	var regex := RegEx.new()
	regex.compile("(?is)<[^>]+>")
	text = regex.sub(text, "", true)
	return _html_decode(text).strip_edges()


static func _html_decode(value: String) -> String:
	var text := value.replace("&nbsp;", " ")
	text = text.replace("&amp;", "&")
	text = text.replace("&quot;", "\"")
	text = text.replace("&#039;", "'")
	text = text.replace("&#39;", "'")
	text = text.replace("&apos;", "'")
	text = text.replace("&lt;", "<")
	text = text.replace("&gt;", ">")
	return text
