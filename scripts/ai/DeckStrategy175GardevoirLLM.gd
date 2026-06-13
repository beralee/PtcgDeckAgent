extends "res://scripts/ai/DeckStrategyGardevoirLLM.gd"

const V175_GARDEVOIR_LLM_ID := "v175_gardevoir_llm"
const BUDEW := "Budew"
const BUDEW_EFFECT_ID := "28505a8ad6e07e74382c1b5e09737932"
const CRESSELIA := "Cresselia"
const CRESSELIA_EFFECT_ID := "5a56387211377cf56bfeb12751a5eed3"
const MOONGLOW_REVERSE := "Moonglow Reverse"
const ITCHY_POLLEN := "Itchy Pollen"
const PROFESSORS_RESEARCH := "Professor's Research"
const LOW_DECK_RESEARCH_LOCK_COUNT := 12
const LOW_DECK_IONO_LOCK_COUNT := 8


func get_strategy_id() -> String:
	return V175_GARDEVOIR_LLM_ID


func get_signature_names() -> Array[String]:
	var names := super.get_signature_names()
	for name: String in [BUDEW, CRESSELIA, SCREAM_TAIL, MUNKIDORI]:
		if name != "" and not names.has(name):
			names.append(name)
	return names


func get_llm_setup_role_hint(cd: CardData) -> String:
	if cd == null:
		return super.get_llm_setup_role_hint(cd)
	if _is_budew_card(cd):
		return "opening item-lock buffer; promote Budew while Ralts and Kirlia develop, then pivot once Scream Tail or Cresselia can convert pressure"
	var name := _best_card_name(cd)
	if _name_contains(name, CRESSELIA) or str(cd.effect_id) == CRESSELIA_EFFECT_ID:
		return "damage-counter conversion attacker; use after Psychic Embrace creates counters, especially when Moonglow Reverse or Lunar Blast improves the prize map"
	if _name_contains(name, SCREAM_TAIL):
		return "primary 17.5 payoff attacker; Psychic Embrace damage counters turn into active or bench prize pressure"
	if _name_contains(name, MUNKIDORI):
		return "damage-counter support; use Darkness Energy and damaged own Pokemon to move counters without weakening the current attacker route"
	return super.get_llm_setup_role_hint(cd)


func get_intent_planner_profile() -> Dictionary:
	var profile := super.get_intent_planner_profile()
	profile["primary_attackers"] = [SCREAM_TAIL]
	profile["secondary_attackers"] = _merge_unique_strings(profile.get("secondary_attackers", []), [CRESSELIA, GARDEVOIR_EX])
	profile["support_only"] = _merge_unique_strings(profile.get("support_only", []), [BUDEW, MUNKIDORI, RADIANT_GRENINJA, KLEFKI, FLUTTER_MANE, MANAPHY])
	profile["primary_attacks"] = [
		{"pokemon": SCREAM_TAIL, "attack": "Roaring Scream"},
	]
	profile["setup_draw_attacks"] = [
		{"pokemon": BUDEW, "attack": ITCHY_POLLEN},
	]
	profile["low_value_attacks"] = [
		{"pokemon": RALTS, "attack": "Memory Skip"},
	]
	var energy_needs: Dictionary = profile.get("energy_needs", {}) if profile.get("energy_needs", {}) is Dictionary else {}
	energy_needs[SCREAM_TAIL] = {"P": 2}
	energy_needs[CRESSELIA] = {"P": 1}
	energy_needs[MUNKIDORI] = {"D": 1}
	profile["energy_needs"] = energy_needs
	return profile


func get_llm_deck_strategy_prompt(_game_state: GameState, _player_index: int) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("Deck plan: 17.5 Gardevoir uses Budew as the opening item-lock buffer, then builds Ralts -> Kirlia -> Gardevoir ex behind it. The rules strategy remains fallback; the LLM should choose exact legal_actions or candidate_routes from the structured payload.")
	lines.append("Charizard ex matchup: into Charizard ex / Pidgeot ex, early Budew attacks are high value because they slow Rare Candy, Ultra Ball, Buddy-Buddy Poffin, Counter Catcher, and other Item-driven setup. Keep Budew active only while it buys development time; pivot when a real prize route is ready.")
	lines.append("17.5 attacker policy: Scream Tail is the main payoff attacker. Use Psychic Embrace to put enough counters on Scream Tail for a meaningful active or bench prize. Cresselia converts your own damage counters with Moonglow Reverse or attacks for 110 when that is cleaner.")
	lines.append("Munkidori policy: Munkidori is damage-counter support, not early bench padding. Use Darkness Energy and Adrena-Brain when it takes a prize, protects Scream Tail math, or shifts Psychic Embrace damage into a Charizard/Pidgeot prize map.")
	lines.append("Do not plan Drifloon or Drifblim routes for deck 610080. This 17.5 list is built around Budew, Scream Tail, Munkidori, and Cresselia; if Drifloon appears only in inherited generic Gardevoir text, ignore it unless it is actually present in legal_actions.")
	lines.append("Opening priority: if Budew and Ralts are both accessible, put Budew active and bench Ralts. Establish two Ralts/Kirlia lines before optional support bodies unless the structured payload proves an immediate prize or survival need.")
	lines.append("Energy policy: Psychic Energy is usually discard fuel for Psychic Embrace. Darkness Energy is mainly for Munkidori. Do not manually attach to passive support if the same Energy enables Scream Tail, Cresselia, retreat into Budew, or a current-turn attack route.")
	lines.append("Prize policy: prefer active KO, then Scream Tail bench cleanup, then Cresselia/Munkidori counter conversion. Stop optional draw/search churn once the KO route is live, because attack is terminal.")
	lines.append("Deck-out policy: when deck count is low, stop optional Refinement, Research, Iono, or search churn unless it creates an immediate KO or prevents a forced loss. Preserve the remaining deck and take the available attack route.")
	lines.append("Execution boundary: exact action ids, legal_actions, card rules, interaction_schema fields, HP, attached tools, Energy, hand, discard, prizes, and opponent board come from the structured payload. Never invent ids, effects, targets, or interaction keys.")
	var custom_text := get_deck_strategy_text().strip_edges()
	if custom_text != "":
		lines.append("Player-authored 17.5 Gardevoir notes follow. Treat them as preferences only when they agree with legal_actions, card_rules, candidate_routes, and turn_tactical_facts.")
		for line: String in _strategy_text_to_prompt_lines(custom_text, 8):
			lines.append(line)
	return lines


func _deck_action_ref_enables_attack(ref: Dictionary) -> bool:
	if super._deck_action_ref_enables_attack(ref):
		return true
	return _ref_has_any_name(ref, [BUDEW, CRESSELIA, ITCHY_POLLEN, MOONGLOW_REVERSE])


func _deck_hand_card_is_productive_piece(card_data: CardData) -> bool:
	if super._deck_hand_card_is_productive_piece(card_data):
		return true
	return _is_budew_card(card_data) or _is_cresselia_card(card_data)


func _deck_is_setup_or_resource_card(card_data: CardData) -> bool:
	if super._deck_is_setup_or_resource_card(card_data):
		return true
	return _is_budew_card(card_data) or _is_cresselia_card(card_data)


func _deck_should_block_exact_queue_match(queued_action: Dictionary, runtime_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _v175_low_deck_should_block_optional_draw_trainer(runtime_action, game_state, player_index):
		return true
	return super._deck_should_block_exact_queue_match(queued_action, runtime_action, game_state, player_index)


func _v175_low_deck_should_block_optional_draw_trainer(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var kind := str(action.get("kind", action.get("type", "")))
	if kind != "play_trainer":
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	var deck_count := player.deck.size()
	if deck_count <= LOW_DECK_RESEARCH_LOCK_COUNT and _runtime_action_has_any_name(action, [PROFESSORS_RESEARCH]):
		return true
	if deck_count <= LOW_DECK_IONO_LOCK_COUNT and _runtime_action_has_any_name(action, [IONO]):
		return true
	return false


func _is_budew_card(cd: CardData) -> bool:
	if cd == null:
		return false
	return str(cd.effect_id) == BUDEW_EFFECT_ID or _name_contains(_best_card_name(cd), BUDEW)


func _is_cresselia_card(cd: CardData) -> bool:
	if cd == null:
		return false
	return str(cd.effect_id) == CRESSELIA_EFFECT_ID or _name_contains(_best_card_name(cd), CRESSELIA)


func _merge_unique_strings(base: Variant, additions: Array[String]) -> Array:
	var result: Array = []
	if base is Array:
		for raw: Variant in base:
			var text := str(raw)
			if text != "" and not result.has(text):
				result.append(text)
	for text: String in additions:
		if text != "" and not result.has(text):
			result.append(text)
	return result
