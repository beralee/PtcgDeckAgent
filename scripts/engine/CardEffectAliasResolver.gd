class_name CardEffectAliasResolver
extends RefCounted


static func find_duplicate_effect_alias(card: CardData, candidates: Array) -> Dictionary:
	if card == null:
		return {"matched": false, "reason": "missing card"}
	var alias_effect_id := str(card.effect_id).strip_edges()
	if alias_effect_id == "":
		return {"matched": false, "reason": "missing effect id"}
	if _is_card_effect_registered(card):
		return {"matched": false, "reason": "effect already registered"}

	var card_signature := build_effect_signature(card)
	if card_signature.is_empty():
		return {"matched": false, "reason": "empty effect signature"}

	var matches: Array[Dictionary] = []
	var source_effect_ids: Dictionary = {}
	for candidate_variant: Variant in candidates:
		if not (candidate_variant is CardData):
			continue
		var candidate := candidate_variant as CardData
		if candidate == null or candidate == card:
			continue
		if candidate.get_uid() == card.get_uid():
			continue
		var source_effect_id := str(candidate.effect_id).strip_edges()
		if source_effect_id == "" or source_effect_id == alias_effect_id:
			continue
		if not _same_card_name(card, candidate):
			continue
		if build_effect_signature(candidate) != card_signature:
			continue
		if not _is_card_effect_registered(candidate):
			continue
		matches.append({
			"source_card": candidate,
			"source_effect_id": source_effect_id,
		})
		source_effect_ids[source_effect_id] = true

	if matches.is_empty():
		return {"matched": false, "reason": "no implemented same-name same-effect card"}
	if source_effect_ids.size() > 1:
		return {"matched": false, "reason": "ambiguous implemented duplicate effects"}

	var selected := matches[0]
	var source_card: CardData = selected.get("source_card")
	return {
		"matched": true,
		"reason": "same_name_same_effect_signature",
		"alias_effect_id": alias_effect_id,
		"source_effect_id": str(selected.get("source_effect_id", "")),
		"source_set_code": source_card.set_code,
		"source_card_index": source_card.card_index,
		"alias_set_code": card.set_code,
		"alias_card_index": card.card_index,
		"signature": JSON.stringify(card_signature),
	}


static func build_effect_signature(card: CardData) -> Dictionary:
	if card == null:
		return {}
	var signature := {
		"card_type": _normalize_text(card.card_type),
		"mechanic": _normalize_text(card.mechanic),
		"description": "",
	}

	if card.is_pokemon():
		signature["stage"] = _normalize_text(card.stage)
		signature["ancient_trait"] = _normalize_text(card.ancient_trait)
		signature["abilities"] = _normalize_abilities(card.abilities)
		signature["attacks"] = _normalize_attacks(card.attacks)
	else:
		signature["description"] = _normalize_text(card.description)
		signature["energy_provides"] = _normalize_text(card.energy_provides)

	return signature


static func _normalize_abilities(abilities: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ability: Dictionary in abilities:
		result.append({
			"name": _normalize_text(ability.get("name", "")),
			"text": _normalize_text(ability.get("text", "")),
		})
	return result


static func _normalize_attacks(attacks: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for attack: Dictionary in attacks:
		result.append({
			"name": _normalize_text(attack.get("name", "")),
			"text": _normalize_text(attack.get("text", "")),
			"cost": _normalize_text(attack.get("cost", "")),
			"damage": _normalize_text(attack.get("damage", "")),
			"is_vstar_power": bool(attack.get("is_vstar_power", false)),
		})
	return result


static func _same_card_name(left: CardData, right: CardData) -> bool:
	var left_name := _normalize_name(left.name)
	var right_name := _normalize_name(right.name)
	if left_name != "" and right_name != "" and left_name == right_name:
		return true
	var left_en := _normalize_name(left.name_en)
	var right_en := _normalize_name(right.name_en)
	return left_en != "" and left_en == right_en


static func _normalize_name(value: Variant) -> String:
	return _normalize_text(value).to_lower()


static func _normalize_text(value: Variant) -> String:
	var text := str(value).strip_edges().replace("\r\n", "\n").replace("\r", "\n")
	while text.find("\n\n\n") >= 0:
		text = text.replace("\n\n\n", "\n\n")
	while text.find("  ") >= 0:
		text = text.replace("  ", " ")
	return text


static func _is_card_effect_registered(card: CardData) -> bool:
	if card == null:
		return false
	var effect_id := str(card.effect_id).strip_edges()
	if effect_id == "":
		return false
	var processor := EffectProcessor.new()
	if card.is_pokemon():
		processor.register_pokemon_card(card)
	var implemented := processor.has_effect(effect_id) or processor.has_attack_effect(effect_id)
	processor.prepare_for_disposal()
	return implemented
