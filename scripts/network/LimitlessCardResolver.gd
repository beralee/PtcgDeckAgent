class_name LimitlessCardResolver
extends RefCounted

const Parser := preload("res://scripts/network/LimitlessCardParser.gd")
const LimitlessTranslation := preload("res://scripts/network/LimitlessCardTranslation.gd")


static func resolve_card(parsed_card: Dictionary, candidates: Array = []) -> Dictionary:
	var set_code := Parser.normalize_set_code(parsed_card.get("source_set_code", parsed_card.get("set_code_en", "")))
	var card_index := Parser.normalize_card_number(parsed_card.get("source_card_index", parsed_card.get("card_index_en", "")))
	var current_ref := Parser.card_ref_key(set_code, card_index)
	var exact_candidates := _filter_exact_print(candidates, current_ref)
	var exact_errors := _candidate_errors(exact_candidates, parsed_card)
	if not exact_errors.is_empty():
		return _failed(exact_errors)
	var selected := _select_unambiguous_candidate(exact_candidates, parsed_card)
	if selected != null:
		return _resolved(selected, "exact_print", false)

	if _is_basic_energy(parsed_card):
		var energy_candidate := _find_basic_energy_candidate(parsed_card, candidates)
		if energy_candidate != null:
			return _resolved(energy_candidate, "basic_energy", false)

	var same_prints := _source_print_refs(parsed_card, current_ref)
	var same_print_candidates := _filter_same_prints(candidates, same_prints)
	var same_print_errors := _candidate_errors(same_print_candidates, parsed_card)
	if not same_print_errors.is_empty():
		return _failed(same_print_errors)
	selected = _select_unambiguous_candidate(same_print_candidates, parsed_card)
	if selected != null:
		return _resolved(selected, "same_print_group", false)

	var generated := build_generated_card(parsed_card)
	return {
		"card": generated,
		"generated": true,
		"resolved_via": "generated_limitless_card",
		"errors": [],
	}


static func build_generated_card(parsed_card: Dictionary) -> CardData:
	var set_code := Parser.normalize_set_code(parsed_card.get("source_set_code", parsed_card.get("set_code_en", "")))
	var card_index := Parser.normalize_card_number(parsed_card.get("source_card_index", parsed_card.get("card_index_en", "")))
	var card := CardData.new()
	card.source_provider = Parser.SOURCE_PROVIDER
	card.source_url = str(parsed_card.get("source_url", Parser.card_url(set_code, card_index)))
	card.source_set_code = set_code
	card.source_card_index = card_index
	card.source_language = str(parsed_card.get("source_language", "en"))
	card.source_parser_version = int(parsed_card.get("source_parser_version", Parser.PARSER_VERSION))
	card.source_imported_at = int(Time.get_unix_time_from_system() * 1000.0)
	card.source_prints = _packed_string_array(parsed_card.get("source_prints", []))
	card.set_code = "LEN_%s" % set_code
	card.card_index = card_index
	card.set_code_en = set_code
	card.card_index_en = card_index
	card.name = str(parsed_card.get("name", parsed_card.get("name_en", "")))
	card.name_en = str(parsed_card.get("name_en", parsed_card.get("name", "")))
	card.card_type = _local_card_type(str(parsed_card.get("card_type", "")))
	card.mechanic = str(parsed_card.get("mechanic", ""))
	card.label = str(parsed_card.get("label", card.mechanic))
	card.description = str(parsed_card.get("description", ""))
	card.artist = str(parsed_card.get("artist", ""))
	card.rarity = str(parsed_card.get("rarity", ""))
	card.regulation_mark = str(parsed_card.get("regulation_mark", ""))
	card.effect_id = _generated_effect_id(set_code, card_index)
	card.image_url = str(parsed_card.get("image_url", ""))
	card.is_tags = _packed_string_array(parsed_card.get("is_tags", []))
	card.energy_type = str(parsed_card.get("energy_type", ""))
	card.stage = str(parsed_card.get("stage", ""))
	card.hp = int(parsed_card.get("hp", 0))
	card.weakness_energy = str(parsed_card.get("weakness_energy", ""))
	card.weakness_value = str(parsed_card.get("weakness_value", ""))
	card.resistance_energy = str(parsed_card.get("resistance_energy", ""))
	card.resistance_value = str(parsed_card.get("resistance_value", ""))
	card.retreat_cost = int(parsed_card.get("retreat_cost", 0))
	card.evolves_from = str(parsed_card.get("evolves_from", ""))
	card.attacks = _dictionary_array(parsed_card.get("attacks", []))
	card.abilities = _dictionary_array(parsed_card.get("abilities", []))
	card.energy_provides = str(parsed_card.get("energy_provides", ""))
	LimitlessTranslation.apply_to_generated_card(card)
	card.ensure_image_metadata()
	return card


static func _resolved(card: CardData, via: String, generated: bool) -> Dictionary:
	return {
		"card": card,
		"generated": generated,
		"resolved_via": via,
		"errors": [],
	}


static func _failed(errors: Array[String]) -> Dictionary:
	return {
		"card": null,
		"generated": false,
		"resolved_via": "failed_closed",
		"errors": errors,
	}


static func _filter_exact_print(candidates: Array, ref: String) -> Array[CardData]:
	var result: Array[CardData] = []
	if ref == "":
		return result
	for raw: Variant in candidates:
		if not (raw is CardData):
			continue
		var card := raw as CardData
		var card_ref := Parser.card_ref_key(card.set_code_en, card.card_index_en)
		if card_ref == ref:
			result.append(card)
	return result


static func _filter_same_prints(candidates: Array, refs: PackedStringArray) -> Array[CardData]:
	var ref_map := {}
	for ref: String in refs:
		ref_map[ref] = true
	var result: Array[CardData] = []
	for raw: Variant in candidates:
		if not (raw is CardData):
			continue
		var card := raw as CardData
		var card_ref := Parser.card_ref_key(card.set_code_en, card.card_index_en)
		if ref_map.has(card_ref):
			result.append(card)
	return result


static func _select_unambiguous_candidate(candidates: Array[CardData], parsed_card: Dictionary) -> CardData:
	var compatible: Array[CardData] = []
	for card: CardData in candidates:
		if _candidate_is_compatible(card, parsed_card):
			compatible.append(card)
	if compatible.is_empty():
		return null
	if compatible.size() == 1:
		return compatible[0]
	var effect_ids := {}
	for card: CardData in compatible:
		var effect_id := str(card.effect_id).strip_edges()
		if effect_id != "":
			effect_ids[effect_id] = true
	if effect_ids.size() > 1:
		return null
	compatible.sort_custom(func(a: CardData, b: CardData) -> bool:
		return a.get_uid() < b.get_uid()
	)
	return compatible[0]


static func _candidate_is_compatible(card: CardData, parsed_card: Dictionary) -> bool:
	if card == null:
		return false
	var parsed_name := str(parsed_card.get("name_en", parsed_card.get("name", "")))
	var candidate_name := card.name_en if card.name_en != "" else card.name
	if _normalize_name(parsed_name) != "" and _normalize_name(candidate_name) != "" and _normalize_name(parsed_name) != _normalize_name(candidate_name):
		return false
	var parsed_type := _local_card_type(str(parsed_card.get("card_type", "")))
	if parsed_type != "" and card.card_type != "" and parsed_type != card.card_type:
		return false
	var parsed_mechanic := str(parsed_card.get("mechanic", "")).strip_edges()
	if parsed_mechanic == "":
		return true
	if parsed_mechanic == "ACE SPEC":
		return card.is_ace_spec()
	return card.mechanic == parsed_mechanic


static func _find_basic_energy_candidate(parsed_card: Dictionary, candidates: Array) -> CardData:
	var parsed_name := _normalize_name(str(parsed_card.get("name_en", parsed_card.get("name", ""))))
	var parsed_energy := str(parsed_card.get("energy_provides", ""))
	for raw: Variant in candidates:
		if not (raw is CardData):
			continue
		var card := raw as CardData
		if card.card_type != "Basic Energy":
			continue
		var card_name := _normalize_name(card.name_en if card.name_en != "" else card.name)
		if parsed_name != "" and parsed_name == card_name:
			return card
		if parsed_energy != "" and parsed_energy == card.energy_provides:
			return card
	return null


static func _source_print_refs(parsed_card: Dictionary, current_ref: String) -> PackedStringArray:
	var refs := _packed_string_array(parsed_card.get("source_prints", []))
	if current_ref != "" and current_ref not in refs:
		refs.append(current_ref)
	return refs


static func _candidate_errors(candidates: Array[CardData], parsed_card: Dictionary) -> Array[String]:
	if candidates.size() <= 1:
		return []
	var effect_ids := {}
	for card: CardData in candidates:
		if _candidate_is_compatible(card, parsed_card):
			effect_ids[str(card.effect_id)] = true
	if effect_ids.size() > 1:
		return ["ambiguous same-print candidates with multiple effect ids"]
	return []


static func _is_basic_energy(parsed_card: Dictionary) -> bool:
	return _local_card_type(str(parsed_card.get("card_type", ""))) == "Basic Energy"


static func _local_card_type(card_type: String) -> String:
	if card_type == "Trainer":
		return ""
	return card_type


static func _normalize_name(value: String) -> String:
	return value.strip_edges().to_lower().replace("'", "").replace(" ", "")


static func _generated_effect_id(set_code: String, card_index: String) -> String:
	return ("limitless:en:%s:%s" % [set_code, card_index]).md5_text()


static func _packed_string_array(value: Variant) -> PackedStringArray:
	var packed := PackedStringArray()
	if value is PackedStringArray:
		return value
	if value is Array:
		for item: Variant in value:
			packed.append(str(item))
	elif str(value) != "":
		packed.append(str(value))
	return packed


static func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item: Variant in value:
			if item is Dictionary:
				result.append((item as Dictionary).duplicate(true))
	return result
