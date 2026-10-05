extends RefCounted
static var _scope: Dictionary = {}

static func inputs(frame: Dictionary, cards: Dictionary) -> Array:
	if _scope.is_empty():
		_scope = JSON.parse_string(FileAccess.get_file_as_string("res://contracts/ptcgdap/public_gust_scope_v1.json"))
	var public: Dictionary = frame.get("public_state", {})
	var own: Dictionary = public.get("self", {})
	var opponent: Dictionary = public.get("opponent", {})
	var stadium: Variant = public.get("decision", {}).get("stadium", {}).get("card_uid")
	if stadium != null and (not _scope.stadiums.has(stadium) or _scope.stadiums[stadium] != cards.get(stadium, {}).get("effect_id")): return [[], {}, false]
	for player: Dictionary in [own, opponent]:
		for zone: String in ["active", "bench"]:
			for slot: Dictionary in player.get(zone, []):
				var uid: String = slot.get("local_card_uid", "")
				var card: Dictionary = cards.get(uid, {})
				if card.is_empty() or slot.get("attached_tool_uid") != null: return [[], {}, false]
				if card.get("has_ability", false) and _scope.board_abilities.get(uid) != card.get("effect_id"):
					return [[], {}, false]
	var targets := {}
	for slot: Dictionary in opponent.get("bench", []):
		if slot.get("remaining_hp", 0) > 0 and slot.get("local_card_uid") not in _scope.decline_targets:
			targets[slot.entity_serial] = true
	var attacks := []; var typed := false
	for option: Dictionary in frame.get("options", []):
		if option.get("kind") in ["attack", "granted_attack"]: attacks.append(option)
		if frame.get("prompt_kind") == "effect_target" and option.get("source_uid") in ["30thDC_039", "CSV6C_114"]:
			typed = true
	if typed and own.get("active", []).size() == 1:
		var active: Dictionary = own.active[0]
		for entity: Dictionary in public.get("decision", {}).get("entities", []):
			if entity.get("entity_serial") != active.entity_serial: continue
			if active.get("local_card_uid") != "CSV8C_159" or entity.get("conditions") != []: continue
			for attack: Dictionary in entity.get("attacks", []):
				if attack.get("source_uid") == "CSV8C_159" and attack.get("attack_index") == 1 and attack.get("energy_ready") == true and attack.get("energy_debt") == 0:
					attacks = [{"kind":"attack", "source_entity_serial":active.entity_serial, "source_serial":active.serial,
						"source_uid":"CSV8C_159", "attack_index":1, "projected_damage":null}]
	return [attacks, targets, typed]
