class_name CardImplementationStatus
extends RefCounted

static var _status_cache: Dictionary = {}


static func clear_cache() -> void:
	_status_cache.clear()


static func is_unimplemented(card: CardData) -> bool:
	return bool(get_status(card).get("unimplemented", false))


static func get_reason(card: CardData) -> String:
	return str(get_status(card).get("reason", ""))


static func get_status(card: CardData) -> Dictionary:
	if card == null:
		return {"unimplemented": false, "reason": ""}

	var key := _cache_key(card)
	if _status_cache.has(key):
		return (_status_cache[key] as Dictionary).duplicate(true)

	var status := _compute_status(card)
	_status_cache[key] = status
	return status.duplicate(true)


static func _compute_status(card: CardData) -> Dictionary:
	if card == null or card.card_type == "Basic Energy":
		return _implemented()

	var effect_id := str(card.effect_id).strip_edges()
	if card.is_pokemon():
		return _compute_pokemon_status(card, effect_id)

	if card.card_type in ["Item", "Supporter", "Tool", "Stadium", "Special Energy"]:
		if not _card_has_rules_text(card):
			return _implemented()
		if effect_id == "":
			return _unimplemented("missing effect id")
		var processor := EffectProcessor.new()
		var implemented := processor.has_effect(effect_id)
		processor.prepare_for_disposal()
		return _implemented() if implemented else _unimplemented("effect is not registered")

	return _implemented()


static func _compute_pokemon_status(card: CardData, effect_id: String) -> Dictionary:
	var needs_ability_effect := _pokemon_has_ability_text(card)
	var needs_attack_effect := _pokemon_has_attack_requiring_effect(card)
	if not needs_ability_effect and not needs_attack_effect:
		return _implemented()
	if effect_id == "":
		return _unimplemented("missing effect id")

	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var has_card_effect := processor.has_effect(effect_id)
	var has_attack_effect := processor.has_attack_effect(effect_id)
	var card_effect := processor.get_effect(effect_id)
	var card_effect_handles_attack := _effect_overrides_method(card_effect, "execute_attack")
	processor.prepare_for_disposal()

	if needs_ability_effect and not has_card_effect:
		return _unimplemented("ability effect is not registered")
	if needs_attack_effect and not has_attack_effect and not card_effect_handles_attack:
		return _unimplemented("attack effect is not registered")
	return _implemented()


static func _card_has_rules_text(card: CardData) -> bool:
	if str(card.description).strip_edges() != "":
		return true
	if card.is_pokemon():
		return _pokemon_has_ability_text(card) or _pokemon_has_attack_requiring_effect(card)
	return false


static func _pokemon_has_ability_text(card: CardData) -> bool:
	for ability_variant: Variant in card.abilities:
		if not (ability_variant is Dictionary):
			continue
		var ability := ability_variant as Dictionary
		if str(ability.get("name", "")).strip_edges() != "":
			return true
		if str(ability.get("text", "")).strip_edges() != "":
			return true
	return false


static func _pokemon_has_attack_requiring_effect(card: CardData) -> bool:
	for attack_variant: Variant in card.attacks:
		if not (attack_variant is Dictionary):
			continue
		if _attack_needs_effect(attack_variant as Dictionary):
			return true
	return false


static func _attack_needs_effect(attack: Dictionary) -> bool:
	if str(attack.get("text", "")).strip_edges() != "":
		return true
	var damage := str(attack.get("damage", "")).strip_edges()
	if damage == "":
		return false
	return not damage.is_valid_int()


static func _effect_overrides_method(effect: BaseEffect, method_name: String) -> bool:
	if effect == null:
		return false
	var script: Script = effect.get_script()
	if script == null:
		return false
	for method_info: Dictionary in script.get_script_method_list():
		if str(method_info.get("name", "")) == method_name:
			return true
	return false


static func _implemented() -> Dictionary:
	return {"unimplemented": false, "reason": ""}


static func _unimplemented(reason: String) -> Dictionary:
	return {"unimplemented": true, "reason": reason}


static func _cache_key(card: CardData) -> String:
	return "%s|%s|%s|%s|%s|%s|%s" % [
		card.set_code,
		card.card_index,
		card.name,
		card.card_type,
		card.effect_id,
		JSON.stringify(card.abilities),
		JSON.stringify(card.attacks),
	]
