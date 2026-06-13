extends "res://scripts/ai/DeckStrategyLugiaArcheopsLLM.gd"

const Lugia175RulesScript = preload("res://scripts/ai/DeckStrategy175LugiaArcheops.gd")

const V175_LUGIA_LLM_ID := "v175_lugia_archeops_llm"
const NEST_BALL := "Nest Ball"
const MESAGOZA := "Mesagoza"
const WYRDEER_V := "Wyrdeer V"
const REGIGIGAS := "Regigigas"
const REGIGIGAS_ATTACK := "Jewel Break"


func _init() -> void:
	_rules = Lugia175RulesScript.new()


func get_strategy_id() -> String:
	return V175_LUGIA_LLM_ID


func get_signature_names() -> Array[String]:
	var names := super.get_signature_names()
	for name: String in [NEST_BALL, MESAGOZA, WYRDEER_V, REGIGIGAS]:
		if not names.has(name):
			names.append(name)
	return names


func get_intent_planner_profile() -> Dictionary:
	var profile := super.get_intent_planner_profile()
	var secondary: Array = profile.get("secondary_attackers", []) if profile.get("secondary_attackers", []) is Array else []
	for name: String in [WYRDEER_V, REGIGIGAS]:
		if not secondary.has(name):
			secondary.append(name)
	profile["secondary_attackers"] = secondary
	var energy_needs: Dictionary = profile.get("energy_needs", {}) if profile.get("energy_needs", {}) is Dictionary else {}
	energy_needs[WYRDEER_V] = {"C": 3}
	energy_needs[REGIGIGAS] = {"C": 4}
	profile["energy_needs"] = energy_needs
	return profile


func get_llm_setup_role_hint(cd: CardData) -> String:
	if cd == null:
		return super.get_llm_setup_role_hint(cd)
	var name := _best_card_name(cd)
	if _name_contains(name, WYRDEER_V):
		return "late side attacker and energy-concentration finisher; avoid early benching before Lugia VSTAR and Archeops are established"
	if _is_regigigas_card_data(cd):
		return "late Basic side attacker, especially valuable into Tera Pokemon; avoid taking opening priority from Lugia V or Minccino"
	if _name_contains(name, NEST_BALL):
		return "17.5 setup search card; prioritize Lugia V first, then Minccino or late side attackers after the engine is online"
	if _name_contains(name, MESAGOZA):
		return "stadium search support; use early to find Lugia shell pieces and avoid low-value late churn"
	return super.get_llm_setup_role_hint(cd)


func get_llm_deck_strategy_prompt(game_state: GameState, player_index: int) -> PackedStringArray:
	var lines := super.get_llm_deck_strategy_prompt(game_state, player_index)
	lines.insert(1, "17.5 Lugia adjustments: this variant replaces some generic search and cleanup cards with Nest Ball, Mesagoza, Wyrdeer V, and Regigigas. Nest Ball is an opening route to Lugia V or Minccino; Wyrdeer V and Regigigas are mid/late side attackers after Archeops is online, not opening bench padding.")
	lines.insert(2, "17.5 attacker policy: Wyrdeer V can consolidate field Energy after being promoted and scales at 40 damage per attached Energy. Regigigas is a Basic attacker that becomes much more valuable into Tera Pokemon. Do not let either delay the Lugia VSTAR + Archeops launch shell.")
	return lines


func _deck_action_ref_enables_attack(ref: Dictionary) -> bool:
	if super._deck_action_ref_enables_attack(ref):
		return true
	return _ref_has_any_name(ref, [NEST_BALL, MESAGOZA, WYRDEER_V, REGIGIGAS])


func _deck_hand_card_is_productive_piece(card_data: CardData) -> bool:
	return _is_lugia_setup_card(card_data)


func _deck_is_setup_or_resource_card(card_data: CardData) -> bool:
	return _is_lugia_setup_card(card_data)


func _append_lugia_setup_catalog(target: Array[Dictionary], seen_ids: Dictionary, has_attack: bool, no_deck_draw_lock: bool = false) -> void:
	super._append_lugia_setup_catalog(target, seen_ids, has_attack, no_deck_draw_lock)
	_append_catalog_match(target, seen_ids, "play_trainer", NEST_BALL, "")
	_append_catalog_match(target, seen_ids, "play_trainer", MESAGOZA, "")
	if not has_attack:
		_append_catalog_match(target, seen_ids, "play_basic_to_bench", WYRDEER_V, "")
		_append_catalog_match(target, seen_ids, "play_basic_to_bench", REGIGIGAS, "")


func _catalog_has_lugia_setup_action() -> bool:
	if super._catalog_has_lugia_setup_action():
		return true
	for raw_key: Variant in _llm_action_catalog.keys():
		var ref: Dictionary = _llm_action_catalog.get(raw_key, {})
		if ref.is_empty() or _is_future_action_ref(ref):
			continue
		var action_type := str(ref.get("type", ref.get("kind", "")))
		if action_type == "play_trainer" and _ref_has_any_name(ref, [NEST_BALL, MESAGOZA]):
			return true
		if action_type == "play_basic_to_bench" and _ref_has_any_name(ref, [WYRDEER_V, REGIGIGAS]):
			return true
	return false


func _is_lugia_setup_card(card_data: CardData) -> bool:
	if super._is_lugia_setup_card(card_data):
		return true
	if _is_regigigas_card_data(card_data):
		return true
	var name := _best_card_name(card_data)
	return _name_matches_any(name, [NEST_BALL, MESAGOZA, WYRDEER_V, REGIGIGAS])


func _is_lugia_side_attacker_name(name: String) -> bool:
	return super._is_lugia_side_attacker_name(name) or _name_matches_any(name, [WYRDEER_V, REGIGIGAS])


func _is_regigigas_card_data(card_data: CardData) -> bool:
	if card_data == null:
		return false
	var name := _best_card_name(card_data)
	if _name_contains(name, REGIGIGAS):
		return true
	if str(card_data.stage) != "Basic" or int(card_data.hp) != 160:
		return false
	for attack: Dictionary in card_data.attacks:
		if str(attack.get("name", "")) == REGIGIGAS_ATTACK and str(attack.get("cost", "")) == "CCCC":
			return true
	return false
