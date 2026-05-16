class_name AIIntentEnergyPlanner
extends RefCounted

const Util = preload("res://scripts/ai/intent/AIIntentPlannerUtil.gd")
const EvolutionPlannerScript = preload("res://scripts/ai/intent/AIIntentEvolutionPlanner.gd")

var _evolution_planner: RefCounted = EvolutionPlannerScript.new()


func build_energy_intents(
	game_state: GameState,
	player_index: int,
	legal_action_refs: Array,
	_attack_intents: Array = [],
	evolution_intents: Array = [],
	profile: Dictionary = {}
) -> Array[Dictionary]:
	var intents: Array[Dictionary] = []
	for raw: Variant in legal_action_refs:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if Util.ref_type(ref) != "attach_energy":
			continue
		var intent := _intent_for_attach(game_state, player_index, ref, evolution_intents, profile)
		if not intent.is_empty():
			intents.append(intent)
	return intents


func _intent_for_attach(
	game_state: GameState,
	player_index: int,
	ref: Dictionary,
	evolution_intents: Array,
	profile: Dictionary
) -> Dictionary:
	var position := str(ref.get("position", ""))
	var target_slot := Util.slot_by_position(game_state, player_index, position)
	if target_slot == null or target_slot.get_card_data() == null:
		return {}
	var target_name := Util.best_card_name(target_slot.get_card_data())
	var energy_symbol := _energy_symbol_for_ref(ref)
	var attached := Util.attached_energy_counts(target_slot)
	var desired: Dictionary = _desired_energy_for_target(target_slot, evolution_intents, profile)
	var missing_before := Util.missing_cost(desired, attached)
	var attached_after := attached.duplicate(true)
	if energy_symbol != "":
		attached_after[energy_symbol] = int(attached_after.get(energy_symbol, 0)) + 1
	var missing_after := Util.missing_cost(desired, attached_after)
	var target_role := _target_role(target_name, profile)
	var is_bank := _is_energy_bank(target_name, profile)
	var is_scaling := Util.profile_has_name(profile, "scaling_attackers", target_name)
	var support_padding := _is_support_padding(target_slot, game_state, player_index, target_name, target_role, profile)
	var wrong_attribute := _is_wrong_attribute(energy_symbol, desired, missing_before, is_bank, is_scaling)
	var overfill := _is_overfill(energy_symbol, desired, attached, is_bank, is_scaling)
	var marginal := _marginal_value(energy_symbol, missing_before, missing_after, support_padding, wrong_attribute, overfill, is_bank, is_scaling)
	var reason := _reason(target_name, energy_symbol, desired, missing_before, support_padding, wrong_attribute, overfill, is_bank, marginal)
	return {
		"action_id": Util.action_id(ref),
		"source": "manual_attach",
		"energy_name": str(ref.get("card", Util.energy_word(energy_symbol))),
		"energy_symbol": energy_symbol,
		"target_position": position,
		"target_name": target_name,
		"target_role": target_role,
		"serves_attack": _served_attack_text(target_name, desired),
		"serves_stage": _served_stage_text(target_name, evolution_intents),
		"current_attached": _symbols_dict_to_words(attached),
		"desired_energy": _symbols_dict_to_words(desired),
		"missing_before": _symbols_to_words(missing_before),
		"missing_after": _symbols_to_words(missing_after),
		"is_overfill": overfill,
		"is_wrong_attribute": wrong_attribute,
		"is_support_padding": support_padding,
		"marginal_value": marginal,
		"reason": reason,
	}


func _energy_symbol_for_ref(ref: Dictionary) -> String:
	var symbol := Util.energy_symbol(ref.get("energy_type", ""))
	if symbol != "":
		return symbol
	var card_rules: Dictionary = ref.get("card_rules", {}) if ref.get("card_rules", {}) is Dictionary else {}
	symbol = Util.energy_symbol(card_rules.get("energy_provides", ""))
	if symbol != "":
		return symbol
	return Util.energy_symbol(ref.get("card", ""))


func _desired_energy_for_target(slot: PokemonSlot, evolution_intents: Array, profile: Dictionary) -> Dictionary:
	var desired: Dictionary = _evolution_planner.call("desired_energy_for_slot", slot, profile)
	if not desired.is_empty():
		return desired
	if slot != null and slot.get_card_data() != null:
		return _best_attack_cost_for_card(slot.get_card_data())
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


func _target_role(target_name: String, profile: Dictionary) -> String:
	if Util.profile_has_name(profile, "energy_banks", target_name):
		return "energy_bank"
	if Util.profile_has_name(profile, "primary_attackers", target_name):
		return "primary_attacker"
	if Util.profile_has_name(profile, "secondary_attackers", target_name):
		return "secondary_attacker"
	if Util.profile_has_name(profile, "scaling_attackers", target_name):
		return "scaling_attacker"
	if Util.profile_has_name(profile, "support_only", target_name):
		return "support"
	for raw_line: Variant in profile.get("evolution_lines", []):
		if not (raw_line is Dictionary):
			continue
		var line: Dictionary = raw_line
		var names := _line_names(line)
		for name: String in names:
			if Util.name_matches(target_name, name):
				return str(line.get("role", "future_primary_attacker"))
	return "attacker_or_future_stage"


func _is_energy_bank(target_name: String, profile: Dictionary) -> bool:
	return Util.profile_has_name(profile, "energy_banks", target_name)


func _is_support_padding(
	slot: PokemonSlot,
	game_state: GameState,
	player_index: int,
	target_name: String,
	target_role: String,
	profile: Dictionary
) -> bool:
	if target_role in ["primary_attacker", "secondary_attacker", "scaling_attacker", "energy_bank"] or target_role.find("attacker") >= 0:
		return false
	if Util.profile_has_name(profile, "support_only", target_name):
		return Util.slot_position(slot, game_state, player_index) != "active"
	var lower := target_name.to_lower()
	if lower.find("manaphy") >= 0 or lower.find("lumineon") >= 0 or lower.find("fezandipiti") >= 0 or lower.find("rotom") >= 0:
		return Util.slot_position(slot, game_state, player_index) != "active"
	return false


func _is_wrong_attribute(energy_symbol: String, desired: Dictionary, missing_before: Array[String], is_bank: bool, is_scaling: bool) -> bool:
	if energy_symbol == "" or is_bank or is_scaling or desired.is_empty():
		return false
	if missing_before.has(energy_symbol) or missing_before.has("C"):
		return false
	for symbol: String in missing_before:
		if symbol != "C":
			return true
	return false


func _is_overfill(energy_symbol: String, desired: Dictionary, attached: Dictionary, is_bank: bool, is_scaling: bool) -> bool:
	if energy_symbol == "" or is_bank or is_scaling or desired.is_empty():
		return false
	if desired.has("C"):
		return Util.total_energy_count(attached) >= int(desired.get("C", 0))
	if not desired.has(energy_symbol):
		return false
	return int(attached.get(energy_symbol, 0)) >= int(desired.get(energy_symbol, 0))


func _marginal_value(
	energy_symbol: String,
	missing_before: Array[String],
	missing_after: Array[String],
	support_padding: bool,
	wrong_attribute: bool,
	overfill: bool,
	is_bank: bool,
	is_scaling: bool
) -> String:
	if support_padding or wrong_attribute or overfill:
		return "low"
	if is_bank or is_scaling:
		return "medium"
	if missing_after.size() < missing_before.size():
		return "high"
	if energy_symbol != "":
		return "medium"
	return "low"


func _reason(
	target_name: String,
	energy_symbol: String,
	desired: Dictionary,
	missing_before: Array[String],
	support_padding: bool,
	wrong_attribute: bool,
	overfill: bool,
	is_bank: bool,
	marginal: String
) -> String:
	if support_padding:
		return "%s is a support target; bench padding energy is low value unless retreat is required" % target_name
	if wrong_attribute:
		return "%s needs %s before %s" % [target_name, ", ".join(_symbols_to_words(missing_before)), Util.energy_word(energy_symbol)]
	if overfill:
		return "%s already satisfies the relevant %s energy requirement" % [target_name, Util.energy_word(energy_symbol)]
	if is_bank:
		return "%s is configured as an energy bank or ammunition target" % target_name
	if marginal == "high":
		return "fills a missing attack or future evolution cost for %s" % target_name
	if desired.is_empty():
		return "no explicit desired energy is known for %s" % target_name
	return "supports %s desired energy %s" % [target_name, str(_symbols_dict_to_words(desired))]


func _served_attack_text(target_name: String, desired: Dictionary) -> String:
	if desired.is_empty():
		return ""
	return "%s desired attack cost" % target_name


func _served_stage_text(target_name: String, evolution_intents: Array) -> String:
	for raw: Variant in evolution_intents:
		if not (raw is Dictionary):
			continue
		var intent: Dictionary = raw
		if Util.name_matches(target_name, intent.get("from", "")):
			return str(intent.get("to", ""))
	return target_name


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
