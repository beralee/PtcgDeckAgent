class_name AIIntentEvolutionPlanner
extends RefCounted

const Util = preload("res://scripts/ai/intent/AIIntentPlannerUtil.gd")


func build_evolution_intents(
	game_state: GameState,
	player_index: int,
	legal_action_refs: Array,
	profile: Dictionary = {}
) -> Array[Dictionary]:
	var intents: Array[Dictionary] = []
	for raw: Variant in legal_action_refs:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if Util.ref_type(ref) != "evolve":
			continue
		var position := str(ref.get("position", ""))
		var target_slot := Util.slot_by_position(game_state, player_index, position)
		var from_name := str(ref.get("target", ""))
		if from_name == "" and target_slot != null and target_slot.get_card_data() != null:
			from_name = Util.best_card_name(target_slot.get_card_data())
		var to_name := str(ref.get("card", ""))
		var line := _line_for_names(profile, from_name, to_name)
		var role := _line_role(line, to_name, profile)
		var priority := _priority_for_evolution(game_state, player_index, to_name, role, line)
		intents.append({
			"action_id": Util.action_id(ref),
			"from": from_name,
			"to": to_name,
			"target_position": position,
			"line": _line_text(line, from_name, to_name),
			"role": role,
			"board_need": _board_need(game_state, player_index, to_name, role),
			"attack_after_evolve": _attack_after_evolve(ref, target_slot, line),
			"priority": priority,
			"reason": _reason_for_evolution(priority, role, to_name),
		})
	return intents


func build_line_status(game_state: GameState, player_index: int, profile: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw_lines: Variant = profile.get("evolution_lines", [])
	if not (raw_lines is Array):
		return result
	for raw_line: Variant in raw_lines:
		if not (raw_line is Dictionary):
			continue
		var line: Dictionary = raw_line
		var names := _line_names(line)
		if names.is_empty():
			continue
		var counts := {}
		for name: String in names:
			counts[name] = _count_board_name(game_state, player_index, name)
		var desired_count := int(line.get("desired_count", 2 if str(line.get("role", "")).find("primary") >= 0 else 1))
		var total_line_count := 0
		for key: Variant in counts.keys():
			total_line_count += int(counts.get(key, 0))
		var final_name := names[names.size() - 1]
		result.append({
			"line": " -> ".join(names),
			"role": str(line.get("role", "")),
			"counts": counts,
			"desired_count": desired_count,
			"needs_backup_seed": total_line_count < desired_count,
			"final_stage_online": int(counts.get(final_name, 0)) > 0,
		})
	return result


func desired_energy_for_slot(slot: PokemonSlot, profile: Dictionary = {}) -> Dictionary:
	if slot == null or slot.get_card_data() == null:
		return {}
	var name := Util.best_card_name(slot.get_card_data())
	var direct := _energy_need_for_name(profile, name)
	if not direct.is_empty():
		return direct
	for raw_line: Variant in profile.get("evolution_lines", []):
		if not (raw_line is Dictionary):
			continue
		var line: Dictionary = raw_line
		for line_name: String in _line_names(line):
			if Util.name_matches(name, line_name):
				var line_energy := _dict_energy_symbols(line.get("energy", line.get("desired_energy", {})))
				if not line_energy.is_empty():
					return line_energy
	return _best_attack_cost_for_card(slot.get_card_data())


func _line_for_names(profile: Dictionary, from_name: String, to_name: String) -> Dictionary:
	for raw_line: Variant in profile.get("evolution_lines", []):
		if not (raw_line is Dictionary):
			continue
		var line: Dictionary = raw_line
		var names := _line_names(line)
		for line_name: String in names:
			if Util.name_matches(from_name, line_name) or Util.name_matches(to_name, line_name):
				return line
	return {}


func _line_names(line: Dictionary) -> Array[String]:
	var names: Array[String] = []
	var basic := str(line.get("basic", ""))
	if basic != "":
		names.append(basic)
	var raw_stages: Variant = line.get("stages", [])
	if raw_stages is Array:
		for raw_stage: Variant in raw_stages:
			names.append(str(raw_stage))
	return names


func _line_text(line: Dictionary, from_name: String, to_name: String) -> String:
	var names := _line_names(line)
	if not names.is_empty():
		return " -> ".join(names)
	return "%s -> %s" % [from_name, to_name]


func _line_role(line: Dictionary, to_name: String, profile: Dictionary) -> String:
	var role := str(line.get("role", ""))
	if role != "":
		return role
	if Util.profile_has_name(profile, "primary_attackers", to_name):
		return "primary_attacker"
	if Util.profile_has_name(profile, "support_only", to_name):
		return "support"
	return "evolution"


func _priority_for_evolution(game_state: GameState, player_index: int, to_name: String, role: String, line: Dictionary) -> String:
	if role.find("primary") >= 0 and _count_board_name(game_state, player_index, to_name) == 0:
		return "high"
	if str(line.get("role", "")).find("engine") >= 0:
		return "high"
	if role.find("support") >= 0:
		return "medium"
	return "medium"


func _board_need(game_state: GameState, player_index: int, to_name: String, role: String) -> String:
	if _count_board_name(game_state, player_index, to_name) == 0:
		if role.find("primary") >= 0:
			return "first_primary_attacker"
		if role.find("engine") >= 0:
			return "first_engine_piece"
		return "first_copy"
	return "backup_or_continuity"


func _attack_after_evolve(ref: Dictionary, target_slot: PokemonSlot, line: Dictionary) -> Dictionary:
	var desired := _dict_energy_symbols(line.get("energy", line.get("desired_energy", {})))
	var attached := Util.attached_energy_counts(target_slot)
	var missing := Util.missing_cost(desired, attached)
	var card_rules: Dictionary = ref.get("card_rules", {}) if ref.get("card_rules", {}) is Dictionary else {}
	return {
		"desired_energy": _symbols_dict_to_words(desired),
		"missing_cost": _symbols_to_words(missing),
		"ready_after_known_attach": missing.size() <= 1,
		"card_type": str(card_rules.get("card_type", "")),
	}


func _reason_for_evolution(priority: String, role: String, to_name: String) -> String:
	if priority == "high":
		return "%s advances the %s line" % [to_name, role]
	return "%s improves board continuity" % to_name


func _count_board_name(game_state: GameState, player_index: int, name: String) -> int:
	var count := 0
	for slot: PokemonSlot in Util.own_slots(game_state, player_index):
		if slot.get_card_data() != null and Util.name_matches(Util.best_card_name(slot.get_card_data()), name):
			count += 1
	return count


func _energy_need_for_name(profile: Dictionary, name: String) -> Dictionary:
	var raw: Variant = profile.get("energy_needs", {})
	if raw is Dictionary:
		for key: Variant in (raw as Dictionary).keys():
			if Util.name_matches(name, key):
				return _dict_energy_symbols((raw as Dictionary).get(key, {}))
	return {}


func _best_attack_cost_for_card(cd: CardData) -> Dictionary:
	if cd == null:
		return {}
	var best_damage := -1
	var best_cost := {}
	for raw: Variant in cd.attacks:
		if not (raw is Dictionary):
			continue
		var attack: Dictionary = raw
		var damage := Util.parse_damage(attack.get("damage", ""))
		if Util.damage_is_scaling(attack.get("damage", ""), attack.get("text", "")):
			damage += 90
		if damage > best_damage:
			best_damage = damage
			best_cost = Util.cost_counts(attack.get("cost", ""))
	return best_cost


func _dict_energy_symbols(raw: Variant) -> Dictionary:
	var result := {}
	if raw is Dictionary:
		for key: Variant in (raw as Dictionary).keys():
			var symbol := Util.energy_symbol(key)
			if symbol != "":
				result[symbol] = int((raw as Dictionary).get(key, 0))
	elif raw is Array:
		for value: Variant in raw:
			var symbol := Util.energy_symbol(value)
			if symbol != "":
				result[symbol] = int(result.get(symbol, 0)) + 1
	return result


func _symbols_to_words(symbols: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for symbol: String in symbols:
		result.append(Util.energy_word(symbol))
	return result


func _symbols_dict_to_words(counts: Dictionary) -> Dictionary:
	var result := {}
	for key: Variant in counts.keys():
		result[Util.energy_word(key)] = int(counts.get(key, 0))
	return result
