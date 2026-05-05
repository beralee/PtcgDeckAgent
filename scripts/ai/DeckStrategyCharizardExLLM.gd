extends "res://scripts/ai/DeckStrategyLLMRuntimeBase.gd"

const CharizardRulesScript = preload("res://scripts/ai/DeckStrategyCharizardEx.gd")

const CHARIZARD_EX_LLM_ID := "charizard_ex_llm"
const CHARMANDER := "Charmander"
const CHARMELEON := "Charmeleon"
const CHARIZARD_EX := "Charizard ex"
const PIDGEY := "Pidgey"
const PIDGEOT_EX := "Pidgeot ex"
const DUSKULL := "Duskull"
const DUSCLOPS := "Dusclops"
const DUSKNOIR := "Dusknoir"
const RADIANT_CHARIZARD := "Radiant Charizard"
const ROTOM_V := "Rotom V"
const LUMINEON_V := "Lumineon V"
const FEZANDIPITI_EX := "Fezandipiti ex"
const MANAPHY := "Manaphy"
const RARE_CANDY := "Rare Candy"
const BUDDY_BUDDY_POFFIN := "Buddy-Buddy Poffin"
const NEST_BALL := "Nest Ball"
const ULTRA_BALL := "Ultra Ball"
const ARVEN := "Arven"
const FOREST_SEAL_STONE := "Forest Seal Stone"
const BOSSS_ORDERS := "Boss's Orders"
const COUNTER_CATCHER := "Counter Catcher"
const FIRE_ENERGY := "Fire Energy"

var _deck_strategy_text: String = ""
var _rules: RefCounted = CharizardRulesScript.new()


func get_strategy_id() -> String:
	return CHARIZARD_EX_LLM_ID


func get_signature_names() -> Array[String]:
	return _rules.call("get_signature_names") if _rules != null and _rules.has_method("get_signature_names") else []


func get_state_encoder_class() -> GDScript:
	return _rules.call("get_state_encoder_class") if _rules != null and _rules.has_method("get_state_encoder_class") else null


func load_value_net(path: String) -> bool:
	return bool(_rules.call("load_value_net", path)) if _rules != null and _rules.has_method("load_value_net") else false


func get_value_net() -> RefCounted:
	return _rules.call("get_value_net") if _rules != null and _rules.has_method("get_value_net") else null


func get_mcts_config() -> Dictionary:
	return _rules.call("get_mcts_config") if _rules != null and _rules.has_method("get_mcts_config") else {}


func set_deck_strategy_text(text: String) -> void:
	_deck_strategy_text = text.strip_edges()
	if _rules != null and _rules.has_method("set_deck_strategy_text"):
		_rules.call("set_deck_strategy_text", text)


func get_deck_strategy_text() -> String:
	if _deck_strategy_text.strip_edges() != "":
		return _deck_strategy_text
	if _rules != null and _rules.has_method("get_deck_strategy_text"):
		return str(_rules.call("get_deck_strategy_text"))
	return ""


func plan_opening_setup(player: PlayerState) -> Dictionary:
	return _rules.call("plan_opening_setup", player) if _rules != null and _rules.has_method("plan_opening_setup") else {}


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	super.build_turn_plan(game_state, player_index, context)
	return _rules.call("build_turn_plan", game_state, player_index, context) if _rules != null and _rules.has_method("build_turn_plan") else {}


func build_turn_contract(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	return _rules.call("build_turn_contract", game_state, player_index, context) if _rules != null and _rules.has_method("build_turn_contract") else super.build_turn_contract(game_state, player_index, context)


func build_continuity_contract(game_state: GameState, player_index: int, turn_contract: Dictionary = {}) -> Dictionary:
	return _rules.call("build_continuity_contract", game_state, player_index, turn_contract) if _rules != null and _rules.has_method("build_continuity_contract") else {}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var llm_score := super.score_action_absolute(action, game_state, player_index)
		if llm_score >= 10000.0 or llm_score <= -1000.0:
			return llm_score
	return float(_rules.call("score_action_absolute", action, game_state, player_index)) if _rules != null and _rules.has_method("score_action_absolute") else 0.0


func score_action(action: Dictionary, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var absolute := score_action_absolute(action, game_state, int(context.get("player_index", -1)))
		return absolute - _rules_heuristic_base(str(action.get("kind", "")))
	return float(_rules.call("score_action", action, context)) if _rules != null and _rules.has_method("score_action") else 0.0


func evaluate_board(game_state: GameState, player_index: int) -> float:
	return float(_rules.call("evaluate_board", game_state, player_index)) if _rules != null and _rules.has_method("evaluate_board") else 0.0


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	return _rules.call("predict_attacker_damage", slot, extra_context) if _rules != null and _rules.has_method("predict_attacker_damage") else {"damage": 0, "can_attack": false, "description": ""}


func get_discard_priority(card: CardInstance) -> int:
	return int(_rules.call("get_discard_priority", card)) if _rules != null and _rules.has_method("get_discard_priority") else 0


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	return int(_rules.call("get_discard_priority_contextual", card, game_state, player_index)) if _rules != null and _rules.has_method("get_discard_priority_contextual") else get_discard_priority(card)


func get_search_priority(card: CardInstance) -> int:
	return int(_rules.call("get_search_priority", card)) if _rules != null and _rules.has_method("get_search_priority") else 0


func score_search_target(card: CardInstance, context: Dictionary = {}) -> float:
	if _rules != null and _rules.has_method("score_search_target"):
		return float(_rules.call("score_search_target", card, context))
	return score_interaction_target(card, {"id": "search_cards"}, context)


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var game_state: GameState = context.get("game_state", null)
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var guarded_pick := _pick_charizard_llm_interaction_items(items, step, context)
		if not guarded_pick.is_empty():
			return guarded_pick
		var planned: Array = super.pick_interaction_items(items, step, context)
		if not planned.is_empty():
			return planned
	return _rules.call("pick_interaction_items", items, step, context) if _rules != null and _rules.has_method("pick_interaction_items") else []


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var game_state: GameState = context.get("game_state", null)
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var guarded_score := _score_charizard_llm_interaction_target(item, step, context)
		if guarded_score != 0.0:
			return guarded_score
		var planned_score := float(super.score_interaction_target(item, step, context))
		if planned_score != 0.0:
			return planned_score
	return float(_rules.call("score_interaction_target", item, step, context)) if _rules != null and _rules.has_method("score_interaction_target") else 0.0


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if _rules != null and _rules.has_method("score_handoff_target"):
		return float(_rules.call("score_handoff_target", item, step, context))
	return score_interaction_target(item, step, context)


func _pick_charizard_llm_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var step_id := str(step.get("id", ""))
	if not _is_charizard_search_step(step_id):
		return []
	var max_select := int(step.get("max_select", 1))
	if max_select <= 0:
		max_select = items.size()
	var scored: Array[Dictionary] = []
	for index: int in items.size():
		var item: Variant = items[index]
		if not (item is CardInstance):
			continue
		var card := item as CardInstance
		var score := _charizard_llm_search_item_score(card, context)
		if score <= 0.0:
			continue
		scored.append({
			"index": index,
			"score": score,
			"item": item,
		})
	if scored.is_empty():
		return []
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left := float(a.get("score", 0.0))
		var right := float(b.get("score", 0.0))
		if not is_equal_approx(left, right):
			return left > right
		return int(a.get("index", -1)) < int(b.get("index", -1))
	)
	var picked: Array = []
	for i: int in mini(max_select, scored.size()):
		picked.append(scored[i].get("item"))
	return picked


func _score_charizard_llm_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", ""))
	if item is CardInstance and _is_charizard_search_step(step_id):
		return _charizard_llm_search_item_score(item as CardInstance, context)
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if step_id == "target_pokemon" and context.has("stage2_card"):
			return _score_charizard_stage2_target(slot, context)
		if _is_charizard_energy_target_step(step_id):
			return _score_charizard_llm_energy_target(slot, context)
	return 0.0


func _is_charizard_search_step(step_id: String) -> bool:
	return step_id in [
		"search_cards",
		"search_targets",
		"search_pokemon",
		"search_future_pokemon",
		"basic_pokemon",
		"bench_pokemon",
		"buddy_poffin_pokemon",
		"stage2_card",
		"supporter_card",
		"search_item",
		"search_tool",
	]


func _is_charizard_energy_target_step(step_id: String) -> bool:
	return step_id in [
		"attach_energy_target",
		"manual_attach_energy_target",
		"energy_target",
		"assignment_target",
		"energy_assignments",
	]


func _charizard_llm_search_item_score(card: CardInstance, context: Dictionary) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	var name := _best_card_name(card.card_data)
	var continuity := build_continuity_contract(game_state, player_index, {}) if game_state != null else {}
	var setup: Dictionary = continuity.get("setup_debt", {}) if continuity.get("setup_debt", {}) is Dictionary else {}
	var score := 0.0
	if player != null:
		var has_charmander_lane := _charizard_count_field_name(player, CHARMANDER) + _charizard_count_field_name(player, CHARMELEON) + _charizard_count_field_name(player, CHARIZARD_EX) > 0
		var has_pidgey_lane := _charizard_count_field_name(player, PIDGEY) + _charizard_count_field_name(player, PIDGEOT_EX) > 0
		var has_pidgeot := _charizard_count_field_name(player, PIDGEOT_EX) > 0
		var line_count := _charizard_count_field_name(player, CHARMANDER) + _charizard_count_field_name(player, CHARMELEON) + _charizard_count_field_name(player, CHARIZARD_EX)
		if name == RARE_CANDY and (has_charmander_lane or has_pidgey_lane):
			score = 980.0
		elif name == PIDGEOT_EX and has_pidgey_lane and not has_pidgeot:
			score = 960.0
		elif name == CHARIZARD_EX and has_charmander_lane:
			score = 940.0 if _charizard_count_field_name(player, CHARIZARD_EX) == 0 else 760.0
		elif name == CHARMANDER and line_count < 2:
			score = 900.0
		elif name == PIDGEY and not has_pidgey_lane:
			score = 880.0
		elif name == ROTOM_V and has_charmander_lane and has_pidgey_lane and _charizard_count_field_name(player, ROTOM_V) == 0 and _charizard_count_field_name(player, PIDGEOT_EX) == 0:
			score = 920.0
		elif name == CHARMELEON and _charizard_count_field_name(player, CHARMANDER) > 0:
			score = 720.0
		elif name == ARVEN:
			score = 650.0 if bool(setup.get("need_rare_candy", false)) or bool(setup.get("need_arven_or_search", false)) else 260.0
		elif name == ULTRA_BALL:
			score = 620.0 if bool(setup.get("need_second_charizard_ex", false)) or bool(setup.get("need_engine_online", false)) else 300.0
		elif name in [BUDDY_BUDDY_POFFIN, NEST_BALL]:
			score = 600.0 if line_count < 2 or not has_pidgey_lane else 120.0
		elif name == FIRE_ENERGY:
			score = 480.0 if _charizard_needs_fire_energy(player) else 20.0
		elif name == BOSSS_ORDERS or name == COUNTER_CATCHER:
			score = 520.0 if bool(setup.get("final_prize_ko_available", false)) else 280.0
		elif name == FOREST_SEAL_STONE:
			score = 360.0 if _charizard_count_field_name(player, PIDGEOT_EX) == 0 else 80.0
	if score <= 0.0 and _rules != null and _rules.has_method("score_interaction_target"):
		score = float(_rules.call("score_interaction_target", card, {"id": "search_cards"}, context))
	return score


func _score_charizard_stage2_target(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null:
		return 0.0
	var stage2_card: Variant = context.get("stage2_card", null)
	var stage2_name := ""
	if stage2_card is CardInstance and (stage2_card as CardInstance).card_data != null:
		stage2_name = _best_card_name((stage2_card as CardInstance).card_data)
	else:
		stage2_name = str(stage2_card)
	var target_name := _slot_best_name(slot)
	if _name_contains(stage2_name, PIDGEOT_EX):
		return 100000.0 if _name_contains(target_name, PIDGEY) else -1000.0
	if _name_contains(stage2_name, CHARIZARD_EX):
		return 100000.0 if _name_matches_any(target_name, [CHARMANDER, CHARMELEON]) else -1000.0
	return 0.0


func _score_charizard_llm_energy_target(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null:
		return 0.0
	var source: Variant = context.get("source_card", context.get("assignment_source", null))
	if source is CardInstance and not _is_fire_energy_card(source as CardInstance):
		return 0.0
	var name := _slot_best_name(slot)
	if _slot_is_support_only(slot) or _name_matches_any(name, [PIDGEY, PIDGEOT_EX, DUSKULL, DUSCLOPS, DUSKNOIR]):
		return -1000.0
	if _name_contains(name, CHARIZARD_EX):
		if _slot_attached_energy_count(slot) >= 2 and bool(predict_attacker_damage(slot).get("can_attack", false)):
			return -1000.0
		return 900.0
	if _name_matches_any(name, [CHARMANDER, CHARMELEON]):
		return 820.0
	if _name_contains(name, RADIANT_CHARIZARD):
		return 540.0
	return 0.0


func _charizard_needs_fire_energy(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _charizard_all_slots(player):
		if slot == null:
			continue
		var name := _slot_best_name(slot)
		if _name_matches_any(name, [CHARMANDER, CHARMELEON, CHARIZARD_EX, RADIANT_CHARIZARD]) and _slot_attached_energy_count(slot) < 2:
			return true
	return false


func _charizard_all_slots(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if player == null:
		return slots
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	return slots


func _slot_attached_energy_count(slot: PokemonSlot) -> int:
	return slot.attached_energy.size() if slot != null else 0


func make_llm_runtime_snapshot(game_state: GameState, player_index: int) -> Dictionary:
	var snapshot := super.make_llm_runtime_snapshot(game_state, player_index)
	if snapshot.is_empty() or game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return snapshot
	var player: PlayerState = game_state.players[player_index]
	snapshot["charizard_ex_count"] = _charizard_count_field_name(player, "Charizard ex")
	snapshot["pidgeot_ex_count"] = _charizard_count_field_name(player, "Pidgeot ex")
	snapshot["charmander_count"] = _charizard_count_field_name(player, "Charmander")
	snapshot["pidgey_count"] = _charizard_count_field_name(player, "Pidgey")
	snapshot["charizard_attack_ready"] = _active_charizard_attack_ready(player)
	return snapshot


func get_llm_setup_role_hint(cd: CardData) -> String:
	if cd == null:
		return "support"
	var name := _best_card_name(cd)
	if _name_contains(name, "Charmander"):
		return "priority opener: Charizard ex evolution seed; protect it on bench when possible"
	if _name_contains(name, "Pidgey"):
		return "priority opener: Pidgeot ex search-engine seed; bench early next to Charmander"
	if _name_contains(name, "Charizard ex"):
		return "main Stage 2 attacker and Fire-energy acceleration payoff"
	if _name_contains(name, "Pidgeot ex"):
		return "Stage 2 search engine; online Pidgeot finds the missing route piece"
	if _name_contains(name, "Duskull"):
		return "third-lane prize conversion seed; secondary until Charizard and Pidgeot are stable"
	if _name_contains(name, "Rotom V"):
		return "fallback draw pivot; use after safe setup actions because the draw ability is terminal"
	if _name_contains(name, "Lumineon V"):
		return "supporter search support; bench only when the supporter route matters"
	if _name_contains(name, "Fezandipiti ex"):
		return "recovery draw support after a knockout; not an early energy target"
	if _name_contains(name, "Radiant Charizard"):
		return "late-game backup attacker once prizes make its attack efficient"
	if _name_contains(name, "Manaphy"):
		return "bench-protection tech; open only if forced"
	return "support"


func get_llm_deck_strategy_prompt(game_state: GameState, player_index: int) -> PackedStringArray:
	var custom_text := get_deck_strategy_text().strip_edges()
	if custom_text != "":
		var custom_lines := PackedStringArray()
		custom_lines.append("Player-authored Charizard ex strategy text follows. Use it as the tactical preference layer when it does not conflict with legal_actions, card_rules, candidate_routes, or turn_tactical_facts.")
		for line: String in _strategy_text_to_prompt_lines(custom_text, 18):
			custom_lines.append(line)
		custom_lines.append("Execution boundary: exact action ids, card text, interaction schemas, HP, energy, hand, discard, and opponent board come from the structured payload. Do not invent ids, card effects, targets, or interaction fields.")
		return custom_lines

	var lines := PackedStringArray()
	lines.append("Deck plan: Charizard ex / Pidgeot ex is a Stage 2 setup deck. Build Charmander into Charizard ex for prize pressure and Fire-energy acceleration, while building Pidgey into Pidgeot ex as the repeat search engine.")
	lines.append("Setup priority: establish at least one Charmander and one Pidgey before padding support Pokemon. Buddy-Buddy Poffin, Nest Ball, Ultra Ball, Arven, and Rare Candy are valuable when they complete those lanes.")
	lines.append("Evolution policy: if Rare Candy plus a legal Basic and Stage 2 piece can create Charizard ex or Pidgeot ex, prefer finishing the Stage 2 over shallow draw, extra bench padding, or premature end_turn. If only normal evolution is legal, preserve the line and advance it.")
	lines.append("Pidgeot policy: once Pidgeot ex is online, search for the exact missing piece: Rare Candy, Charizard ex, Pidgeot ex, Boss/Counter Catcher for prize math, recovery, or Fire Energy. Do not use Quick Search on redundant basics when the engine and backup lane are already online.")
	lines.append("Energy policy: Charizard-style Fire acceleration and manual attach should fill real attack costs first. Prioritize Charizard ex, a backup Charizard line, or Radiant Charizard when it is a live attacker; avoid assigning Fire to Rotom V, Lumineon V, Fezandipiti ex, Manaphy, Pidgey, or Pidgeot ex unless it immediately enables a retreat or legal attack.")
	lines.append("Tool policy: Forest Seal Stone belongs on Rotom V or Lumineon V only. Do not attach it to Charmander, Charizard ex, Pidgey, Pidgeot ex, Duskull, Manaphy, Fezandipiti ex, or Radiant Charizard.")
	lines.append("Attack policy: Burning Darkness and other real damage attacks should close prizes when available, but early setup that creates Charizard ex plus Pidgeot ex can be worth doing before the first attack. Setup or draw attacks are desperation lines, not normal terminal choices.")
	lines.append("Prize and target policy: prefer active KO, then gust/catcher bench KO, then damaged bench cleanup. Duskull/Dusclops/Dusknoir lines are conversion tools; do not self-damage or self-KO unless it creates or protects a prize swing.")
	lines.append("Resource policy: preserve Rare Candy, Stage 2 Pokemon, Arven, Ultra Ball, Boss, Counter Catcher, and recovery until they produce a concrete route. If the current hand already contains the evolution or attack conversion, stop digging and execute it.")
	lines.append("Pivot policy: Rotom V and Lumineon V are support pivots. Use terminal draw only after safe bench, search, evolution, attach, tool, gust, and attack routes have been considered.")
	lines.append("Replan policy: after Pidgeot search, Ultra Ball, Arven, Rotom draw, recovery, or any search effect changes hand/deck/board, reassess with updated legal_actions instead of blindly following stale route steps.")
	lines.append("Execution boundary: exact action ids, card text, interaction schemas, HP, energy, hand, discard, and opponent board come from the structured payload. Do not invent ids, card effects, targets, or interaction fields.")
	return lines


func _deck_action_ref_enables_attack(ref: Dictionary) -> bool:
	var action_type := str(ref.get("type", ref.get("kind", "")))
	var card_name := str(ref.get("card", ""))
	var pokemon_name := str(ref.get("pokemon", ""))
	if action_type == "evolve" and _name_matches_any(card_name, ["Charizard ex", "Charmeleon"]):
		return true
	if action_type == "play_trainer" and _name_matches_any(card_name, ["Ultra Ball", "Nest Ball", "Buddy-Buddy Poffin", "Arven"]):
		return true
	if action_type == "play_trainer" and _name_matches_any(card_name, ["Rare Candy"]):
		return _charizard_rare_candy_ref_has_real_target(ref)
	if action_type == "attach_energy" and _name_matches_any(card_name, ["Fire Energy"]):
		return true
	if action_type == "use_ability" and _name_matches_any(pokemon_name, ["Charizard ex", "Pidgeot ex"]):
		return true
	return false


func _deck_should_block_exact_queue_match(_queued_action: Dictionary, runtime_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _is_bad_charizard_energy_attach(runtime_action, game_state, player_index):
		return true
	if _is_bad_charizard_tool_attach(runtime_action):
		return true
	if _is_bad_charizard_retreat(runtime_action, game_state, player_index):
		return true
	if _is_bad_charizard_rare_candy_play(runtime_action):
		return true
	return false


func _deck_hand_card_is_productive_piece(card_data: CardData) -> bool:
	return _is_charizard_setup_or_resource_card(card_data)


func _deck_is_setup_or_resource_card(card_data: CardData) -> bool:
	return _is_charizard_setup_or_resource_card(card_data)


func _deck_augment_action_id_payload(payload: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	var result := payload.duplicate(true)
	var facts: Dictionary = result.get("turn_tactical_facts", {}) if result.get("turn_tactical_facts", {}) is Dictionary else {}
	facts = facts.duplicate(true)
	var continuity := build_continuity_contract(game_state, player_index, {})
	if not continuity.is_empty():
		facts["continuity_contract"] = _compact_charizard_continuity_contract_for_llm(continuity)
	var charizard_setup := _charizard_setup_fact(result, game_state, player_index, continuity)
	if not charizard_setup.is_empty():
		facts["charizard_setup"] = charizard_setup
	facts["resource_negative_actions"] = _merge_charizard_resource_negative_actions(
		facts.get("resource_negative_actions", []),
		result.get("legal_actions", [])
	)
	result["turn_tactical_facts"] = facts
	var routes: Array = result.get("candidate_routes", []) if result.get("candidate_routes", []) is Array else []
	var updated_routes := routes.duplicate(true)
	var continuity_route := _charizard_continuity_candidate_route(result, continuity)
	if not continuity_route.is_empty():
		updated_routes.push_front(continuity_route)
	var stage2_route := _charizard_stage2_engine_candidate_route(result, charizard_setup)
	if not stage2_route.is_empty():
		updated_routes.push_front(stage2_route)
	var opening_route := _charizard_core_opening_candidate_route(result, charizard_setup)
	if not opening_route.is_empty():
		updated_routes.push_front(opening_route)
	result["candidate_routes"] = updated_routes
	return result


func _deck_append_short_route_followups(target: Array[Dictionary], seen_ids: Dictionary) -> void:
	_append_charizard_setup_catalog(target, seen_ids, false)


func _deck_append_productive_engine_candidates(
	target: Array[Dictionary],
	seen_ids: Dictionary,
	_actions: Array[Dictionary],
	has_attack: bool,
	_no_deck_draw_lock: bool
) -> void:
	if has_attack:
		_append_catalog_match(target, seen_ids, "play_basic_to_bench", CHARMANDER, "")
		_append_catalog_match(target, seen_ids, "play_basic_to_bench", PIDGEY, "")
		_append_catalog_match(target, seen_ids, "evolve", CHARIZARD_EX, "")
		_append_catalog_match(target, seen_ids, "evolve", PIDGEOT_EX, "")
		return
	_append_charizard_setup_catalog(target, seen_ids, has_attack)


func _deck_should_block_end_turn(game_state: GameState, player_index: int) -> bool:
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		if _active_charizard_attack_ready(game_state.players[player_index]) and _catalog_has_action_type("attack"):
			return true
	else:
		return false
	return _catalog_has_charizard_setup_action()


func _compact_charizard_continuity_contract_for_llm(continuity: Dictionary) -> Dictionary:
	var setup_debt: Dictionary = continuity.get("setup_debt", {}) if continuity.get("setup_debt", {}) is Dictionary else {}
	var raw_bonuses: Array = continuity.get("action_bonuses", []) if continuity.get("action_bonuses", []) is Array else []
	var compact_bonuses: Array[Dictionary] = []
	for raw: Variant in raw_bonuses:
		if not (raw is Dictionary):
			continue
		var bonus: Dictionary = raw
		compact_bonuses.append({
			"kind": str(bonus.get("kind", "")),
			"card_names": bonus.get("card_names", []),
			"target_names": bonus.get("target_names", []),
			"bonus": float(bonus.get("bonus", 0.0)),
			"reason": str(bonus.get("reason", "")),
		})
		if compact_bonuses.size() >= 10:
			break
	return {
		"enabled": bool(continuity.get("enabled", false)),
		"safe_setup_before_attack": bool(continuity.get("safe_setup_before_attack", false)),
		"terminal_attack_locked": bool(continuity.get("terminal_attack_locked", false)),
		"setup_debt": setup_debt,
		"action_bonuses": compact_bonuses,
		"contract": "If enabled, finish listed non-conflicting Charmander/Pidgey/Stage 2/search/backup-energy setup before a non-final Charizard attack. Do not delay final-prize or forced KO attacks.",
	}


func _charizard_setup_fact(payload: Dictionary, game_state: GameState, player_index: int, continuity: Dictionary) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return {}
	var legal_actions: Array = payload.get("legal_actions", []) if payload.get("legal_actions", []) is Array else []
	var setup_debt: Dictionary = continuity.get("setup_debt", {}) if continuity.get("setup_debt", {}) is Dictionary else {}
	var missing_core: Array[String] = []
	if _charizard_count_field_name(player, CHARMANDER) + _charizard_count_field_name(player, CHARMELEON) + _charizard_count_field_name(player, CHARIZARD_EX) < 2:
		missing_core.append("backup_charmander_line")
	if _charizard_count_field_name(player, PIDGEY) == 0 and _charizard_count_field_name(player, PIDGEOT_EX) == 0:
		missing_core.append("pidgey_engine_seed")
	elif _charizard_count_field_name(player, PIDGEOT_EX) == 0:
		missing_core.append("pidgeot_engine_online")
	return {
		"active_charizard_attack_ready": _active_charizard_attack_ready(player),
		"charizard_ex_count": _charizard_count_field_name(player, CHARIZARD_EX),
		"charmander_count": _charizard_count_field_name(player, CHARMANDER),
		"charmeleon_count": _charizard_count_field_name(player, CHARMELEON),
		"pidgey_count": _charizard_count_field_name(player, PIDGEY),
		"pidgeot_ex_count": _charizard_count_field_name(player, PIDGEOT_EX),
		"rotom_v_count": _charizard_count_field_name(player, ROTOM_V),
		"backup_attacker_gap": int(setup_debt.get("backup_attacker_gap", 99)),
		"missing_core": missing_core,
		"direct_charmander_action_id": _first_payload_action_id(legal_actions, "play_basic_to_bench", CHARMANDER),
		"direct_pidgey_action_id": _first_payload_action_id(legal_actions, "play_basic_to_bench", PIDGEY),
		"basic_search_action_id": _first_payload_basic_search_action_id(legal_actions),
		"rare_candy_action_id": _first_payload_action_id(legal_actions, "play_trainer", RARE_CANDY),
		"charizard_evolve_action_id": _first_payload_action_id(legal_actions, "evolve", CHARIZARD_EX),
		"pidgeot_evolve_action_id": _first_payload_action_id(legal_actions, "evolve", PIDGEOT_EX),
		"pidgeot_search_action_id": _first_payload_action_id(legal_actions, "use_ability", PIDGEOT_EX),
		"continuity_enabled": bool(continuity.get("enabled", false)),
		"final_prize_ko_available": bool(setup_debt.get("final_prize_ko_available", false)),
		"terminal_attack_locked": bool(continuity.get("terminal_attack_locked", false)),
		"energy_discipline": "Fire goes to active/backup Charizard attackers only; never overfill an attack-ready Charizard ex past two Fire unless it is the only legal route to a KO.",
	}


func _charizard_core_opening_candidate_route(payload: Dictionary, setup: Dictionary) -> Dictionary:
	if setup.is_empty() or bool(setup.get("terminal_attack_locked", false)):
		return {}
	var missing_core: Array = setup.get("missing_core", []) if setup.get("missing_core", []) is Array else []
	if missing_core.is_empty() or bool(setup.get("active_charizard_attack_ready", false)):
		return {}
	var legal_actions: Array = payload.get("legal_actions", []) if payload.get("legal_actions", []) is Array else []
	var route_actions: Array[Dictionary] = []
	var seen_ids := {}
	_append_payload_ref_by_id(route_actions, seen_ids, legal_actions, str(setup.get("direct_charmander_action_id", "")), {})
	_append_payload_ref_by_id(route_actions, seen_ids, legal_actions, str(setup.get("direct_pidgey_action_id", "")), {})
	if route_actions.size() < 2:
		var search_id := str(setup.get("basic_search_action_id", ""))
		var search_ref := _payload_ref_by_id(legal_actions, search_id)
		_append_payload_ref_by_id(route_actions, seen_ids, legal_actions, search_id, _charizard_basic_search_policy_for_ref(search_ref, setup))
	if route_actions.is_empty():
		return {}
	route_actions.append({"id": "end_turn", "action_id": "end_turn", "type": "end_turn"})
	return {
		"id": "charizard_core_opening_setup",
		"route_action_id": "route:charizard_core_opening_setup",
		"type": "candidate_route",
		"priority": 986,
		"goal": "core_attacker_setup",
		"description": "Strong-mode opening: establish Charmander plus Pidgey before optional support draw or bench padding.",
		"actions": route_actions,
		"future_goals": [{
			"id": "goal:charizard_pidgeot_shell",
			"type": "goal",
			"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
			"reason": "Charizard LLM strong mode needs both the attacker seed and Pidgeot search-engine seed.",
		}],
		"contract": "Select this route when charizard_setup.missing_core is non-empty and Charizard ex is not already attacking this turn.",
	}


func _charizard_stage2_engine_candidate_route(payload: Dictionary, setup: Dictionary) -> Dictionary:
	if setup.is_empty() or bool(setup.get("terminal_attack_locked", false)):
		return {}
	var legal_actions: Array = payload.get("legal_actions", []) if payload.get("legal_actions", []) is Array else []
	var route_actions: Array[Dictionary] = []
	var seen_ids := {}
	var rare_candy_id := str(setup.get("rare_candy_action_id", ""))
	var pidgeot_evolve_id := str(setup.get("pidgeot_evolve_action_id", ""))
	var charizard_evolve_id := str(setup.get("charizard_evolve_action_id", ""))
	var pidgeot_search_id := str(setup.get("pidgeot_search_action_id", ""))
	if rare_candy_id != "" and (pidgeot_evolve_id != "" or charizard_evolve_id != ""):
		var rare_candy_ref := _payload_ref_by_id(legal_actions, rare_candy_id)
		if _charizard_rare_candy_ref_has_real_target(rare_candy_ref):
			_append_payload_ref_by_id(route_actions, seen_ids, legal_actions, rare_candy_id, _charizard_rare_candy_policy(setup))
	if pidgeot_evolve_id != "":
		_append_payload_ref_by_id(route_actions, seen_ids, legal_actions, pidgeot_evolve_id, {})
	if charizard_evolve_id != "":
		_append_payload_ref_by_id(route_actions, seen_ids, legal_actions, charizard_evolve_id, {})
	if route_actions.is_empty() and pidgeot_search_id != "" and _charizard_setup_needs_search(setup):
		_append_payload_ref_by_id(route_actions, seen_ids, legal_actions, pidgeot_search_id, _charizard_search_policy(setup))
	if route_actions.is_empty():
		return {}
	var terminal := _charizard_terminal_attack_ref(legal_actions)
	route_actions.append(terminal if not terminal.is_empty() else {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"})
	return {
		"id": "charizard_stage2_engine_conversion",
		"route_action_id": "route:charizard_stage2_engine_conversion",
		"type": "candidate_route",
		"priority": 984,
		"goal": "setup_to_primary_attack",
		"description": "Convert visible Rare Candy, Charizard ex, or Pidgeot ex pieces before ending or attacking.",
		"actions": route_actions,
		"future_goals": [{
			"id": "goal:charizard_pidgeot_stage2_online",
			"type": "goal",
			"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
			"reason": "Online Pidgeot ex and Charizard ex turn searches into attacks and backup attackers.",
		}],
		"contract": "Select this route when a visible Rare Candy/Stage 2 or Pidgeot Quick Search conversion is legal and no terminal KO is locked.",
	}


func _charizard_continuity_candidate_route(payload: Dictionary, continuity: Dictionary) -> Dictionary:
	if not bool(continuity.get("enabled", false)) or bool(continuity.get("terminal_attack_locked", false)):
		return {}
	var legal_actions: Array = payload.get("legal_actions", []) if payload.get("legal_actions", []) is Array else []
	if legal_actions.is_empty():
		return {}
	var terminal_ref := _charizard_terminal_attack_ref(legal_actions)
	if terminal_ref.is_empty():
		return {}
	var route_actions: Array[Dictionary] = []
	var seen_ids := {}
	var bonuses: Array = continuity.get("action_bonuses", []) if continuity.get("action_bonuses", []) is Array else []
	for raw_bonus: Variant in _sorted_charizard_continuity_bonuses(bonuses):
		if route_actions.size() >= 4:
			break
		if not (raw_bonus is Dictionary):
			continue
		var bonus: Dictionary = raw_bonus
		var ref := _best_payload_ref_for_charizard_continuity_bonus(legal_actions, bonus, route_actions)
		if ref.is_empty():
			continue
		var action_id := str(ref.get("id", ref.get("action_id", ""))).strip_edges()
		if action_id == "" or bool(seen_ids.get(action_id, false)):
			continue
		route_actions.append(_charizard_route_ref(ref, _charizard_policy_for_ref(ref, continuity)))
		seen_ids[action_id] = true
	if route_actions.is_empty():
		return {}
	route_actions.append(terminal_ref)
	return {
		"id": "charizard_continuity_before_attack",
		"route_action_id": "route:charizard_continuity_before_attack",
		"type": "candidate_route",
		"priority": 982,
		"goal": "continuity_before_attack",
		"description": "Before a non-final Charizard attack, pay visible continuity debt: second Charmander line, Pidgey/Pidgeot engine, Rare Candy/search, or backup attacker Energy.",
		"actions": route_actions,
		"future_goals": [{
			"id": "goal:maintain_charizard_pidgeot_chain",
			"type": "goal",
			"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
			"reason": "Attack this turn while leaving the next Charizard/Pidgeot turn intact.",
		}],
		"contract": "Select this route when continuity_contract.enabled is true. Do not select it when terminal_attack_locked or final_prize_ko_available is true.",
	}


func _sorted_charizard_continuity_bonuses(bonuses: Array) -> Array:
	var result := bonuses.duplicate(true)
	result.sort_custom(Callable(self, "_sort_charizard_continuity_bonus_desc"))
	return result


func _sort_charizard_continuity_bonus_desc(a: Variant, b: Variant) -> bool:
	var left: Dictionary = a if a is Dictionary else {}
	var right: Dictionary = b if b is Dictionary else {}
	var left_score := float(left.get("bonus", 0.0))
	var right_score := float(right.get("bonus", 0.0))
	if not is_equal_approx(left_score, right_score):
		return left_score > right_score
	return str(left.get("reason", "")) < str(right.get("reason", ""))


func _best_payload_ref_for_charizard_continuity_bonus(
	legal_actions: Array,
	bonus: Dictionary,
	route_actions: Array[Dictionary]
) -> Dictionary:
	var scored: Array[Dictionary] = []
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if _payload_ref_is_future(ref):
			continue
		if not _charizard_ref_matches_continuity_bonus(ref, bonus):
			continue
		if _charizard_ref_conflicts_with_route(ref, route_actions):
			continue
		scored.append({"score": _charizard_continuity_ref_score(ref, bonus), "ref": ref})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left := float(a.get("score", 0.0))
		var right := float(b.get("score", 0.0))
		if not is_equal_approx(left, right):
			return left > right
		var left_ref: Dictionary = a.get("ref", {}) if a.get("ref", {}) is Dictionary else {}
		var right_ref: Dictionary = b.get("ref", {}) if b.get("ref", {}) is Dictionary else {}
		return str(left_ref.get("id", "")) < str(right_ref.get("id", ""))
	)
	return scored[0].get("ref", {}) if not scored.is_empty() and scored[0].get("ref", {}) is Dictionary else {}


func _charizard_ref_matches_continuity_bonus(ref: Dictionary, bonus: Dictionary) -> bool:
	var kind := str(bonus.get("kind", "")).strip_edges()
	if kind != "" and str(ref.get("type", ref.get("kind", ""))) != kind:
		return false
	var text := _continuity_ref_text(ref)
	var card_names := _string_array_from_variant(bonus.get("card_names", []))
	if not card_names.is_empty() and not _text_matches_any_name(text, card_names):
		return false
	var target_names := _string_array_from_variant(bonus.get("target_names", []))
	if not target_names.is_empty():
		var target_text := "%s %s %s %s" % [
			str(ref.get("target", "")),
			str(ref.get("pokemon", "")),
			str(ref.get("position", "")),
			str(ref.get("summary", "")),
		]
		if not _text_matches_any_name(target_text, target_names):
			return false
	return true


func _charizard_continuity_ref_score(ref: Dictionary, bonus: Dictionary) -> float:
	var score := float(bonus.get("bonus", 0.0))
	var kind := str(ref.get("type", ref.get("kind", "")))
	var text := _continuity_ref_text(ref)
	if kind == "play_basic_to_bench":
		if _name_contains(text, CHARMANDER) or _name_contains(text, PIDGEY):
			score += 120.0
	elif kind == "evolve":
		if _name_contains(text, PIDGEOT_EX):
			score += 110.0
		elif _name_contains(text, CHARIZARD_EX):
			score += 100.0
	elif kind == "play_trainer":
		if _name_contains(text, RARE_CANDY):
			score += 100.0
		elif _name_contains(text, BUDDY_BUDDY_POFFIN) or _name_contains(text, NEST_BALL):
			score += 90.0
		elif _name_contains(text, ARVEN):
			score += 70.0
		elif _name_contains(text, ULTRA_BALL):
			score += 60.0
	elif kind == "use_ability":
		if _name_contains(text, PIDGEOT_EX):
			score += 100.0
		elif _name_contains(text, ROTOM_V):
			score -= 180.0
	elif kind == "attach_energy":
		var target_text := "%s %s" % [str(ref.get("target", "")), str(ref.get("summary", ""))]
		if _name_matches_any(target_text, [CHARMANDER, CHARMELEON, CHARIZARD_EX, RADIANT_CHARIZARD]):
			score += 90.0
		if _name_matches_any(target_text, [PIDGEY, PIDGEOT_EX, ROTOM_V, LUMINEON_V, FEZANDIPITI_EX, MANAPHY]):
			score -= 400.0
	return score


func _charizard_route_ref(ref: Dictionary, policy: Dictionary = {}) -> Dictionary:
	var action_id := str(ref.get("id", ref.get("action_id", ""))).strip_edges()
	var result := {
		"id": action_id,
		"action_id": action_id,
		"type": str(ref.get("type", ref.get("kind", ""))),
		"capability": str(ref.get("capability", "")),
	}
	if not policy.is_empty():
		result["selection_policy"] = policy.duplicate(true)
		result["interactions"] = policy.duplicate(true)
	elif ref.has("selection_policy"):
		result["selection_policy"] = ref.get("selection_policy")
	return result


func _charizard_policy_for_ref(ref: Dictionary, continuity: Dictionary = {}) -> Dictionary:
	var kind := str(ref.get("type", ref.get("kind", "")))
	var text := _continuity_ref_text(ref)
	var setup: Dictionary = continuity.get("setup_debt", {}) if continuity.get("setup_debt", {}) is Dictionary else {}
	if kind == "play_trainer" and (_name_contains(text, BUDDY_BUDDY_POFFIN) or _name_contains(text, NEST_BALL)):
		return _charizard_basic_search_policy_for_ref(ref, setup)
	if kind == "play_trainer" and _name_contains(text, ULTRA_BALL):
		return _charizard_search_policy(setup)
	if kind == "play_trainer" and _name_contains(text, ARVEN):
		return {
			"search": {"prefer": [RARE_CANDY, BUDDY_BUDDY_POFFIN, NEST_BALL, ULTRA_BALL, FOREST_SEAL_STONE]},
			"search_item": {"prefer": [RARE_CANDY, BUDDY_BUDDY_POFFIN, NEST_BALL, ULTRA_BALL]},
			"search_tool": {"prefer": [FOREST_SEAL_STONE]},
		}
	if kind == "play_trainer" and _name_contains(text, RARE_CANDY):
		return _charizard_rare_candy_policy(setup)
	if kind == "use_ability" and _name_matches_any(text, [PIDGEOT_EX, ROTOM_V, LUMINEON_V]):
		return _charizard_search_policy(setup)
	if kind == "attach_energy":
		return {
			"target": {"prefer": [CHARMELEON, CHARMANDER, CHARIZARD_EX, RADIANT_CHARIZARD]},
			"energy_assignments": {"prefer": [CHARMELEON, CHARMANDER, CHARIZARD_EX, RADIANT_CHARIZARD]},
		}
	return {}


func _charizard_basic_search_policy(setup: Dictionary = {}) -> Dictionary:
	var prefer := _charizard_basic_prefer_list(setup)
	return {
		"search": {"prefer": prefer},
		"search_pokemon": {"prefer": prefer},
		"basic_pokemon": {"prefer": prefer},
		"bench_pokemon": {"prefer": prefer},
	}


func _charizard_basic_search_policy_for_ref(ref: Dictionary, setup: Dictionary = {}) -> Dictionary:
	var source_card := str(ref.get("card", ""))
	var prefer := _charizard_basic_prefer_list(setup, source_card)
	return {
		"search": {"prefer": prefer},
		"search_pokemon": {"prefer": prefer},
		"basic_pokemon": {"prefer": prefer},
		"bench_pokemon": {"prefer": prefer},
	}


func _charizard_rare_candy_policy(setup: Dictionary = {}) -> Dictionary:
	var stage2 := _charizard_stage2_prefer_list(setup)
	return {
		"stage2_card": {"prefer": stage2},
		"target_pokemon": {"prefer": [PIDGEY, CHARMANDER]},
		"search_cards": {"prefer": stage2},
	}


func _charizard_search_policy(setup: Dictionary = {}) -> Dictionary:
	var prefer := _charizard_search_prefer_list(setup)
	return {
		"search": {"prefer": prefer},
		"search_cards": {"prefer": prefer},
		"search_targets": {"prefer": prefer},
		"search_pokemon": {"prefer": prefer},
		"search_item": {"prefer": [RARE_CANDY, BUDDY_BUDDY_POFFIN, NEST_BALL, ULTRA_BALL]},
		"search_tool": {"prefer": [FOREST_SEAL_STONE]},
		"supporter_card": {"prefer": [ARVEN, BOSSS_ORDERS]},
	}


func _charizard_basic_prefer_list(setup: Dictionary = {}, source_card: String = "") -> Array[String]:
	var prefer: Array[String] = []
	var charmander_count := int(setup.get("charmander_count", 0)) + int(setup.get("charmeleon_count", 0)) + int(setup.get("charizard_ex_count", 0))
	var pidgey_count := int(setup.get("pidgey_count", 0)) + int(setup.get("pidgeot_ex_count", 0))
	var rotom_count := int(setup.get("rotom_v_count", 0))
	if _name_contains(source_card, NEST_BALL) and charmander_count >= 1 and pidgey_count >= 1 and rotom_count == 0:
		prefer.append(ROTOM_V)
	if bool(setup.get("need_backup_attacker_seed", setup.get("need_second_charmander", false))) or charmander_count < 2:
		prefer.append(CHARMANDER)
	if bool(setup.get("need_engine_seed", false)) or pidgey_count < 1:
		prefer.append(PIDGEY)
	if _name_contains(source_card, BUDDY_BUDDY_POFFIN):
		for name: String in [CHARMANDER, PIDGEY, DUSKULL, MANAPHY]:
			if not prefer.has(name):
				prefer.append(name)
		return prefer
	for name: String in [ROTOM_V, CHARMANDER, PIDGEY, DUSKULL, RADIANT_CHARIZARD, MANAPHY]:
		if not prefer.has(name):
			prefer.append(name)
	return prefer


func _charizard_stage2_prefer_list(setup: Dictionary = {}) -> Array[String]:
	var prefer: Array[String] = []
	if bool(setup.get("need_engine_online", false)):
		prefer.append(PIDGEOT_EX)
	if bool(setup.get("need_second_charizard_ex", false)):
		prefer.append(CHARIZARD_EX)
	for name: String in [PIDGEOT_EX, CHARIZARD_EX, CHARMELEON, DUSKNOIR]:
		if not prefer.has(name):
			prefer.append(name)
	return prefer


func _charizard_search_prefer_list(setup: Dictionary = {}) -> Array[String]:
	var prefer: Array[String] = []
	if bool(setup.get("need_rare_candy", false)):
		prefer.append(RARE_CANDY)
	if bool(setup.get("need_engine_seed", false)):
		prefer.append(PIDGEY)
	if bool(setup.get("need_backup_attacker_seed", setup.get("need_second_charmander", false))):
		prefer.append(CHARMANDER)
	if bool(setup.get("need_engine_online", false)):
		prefer.append(PIDGEOT_EX)
	if bool(setup.get("need_second_charizard_ex", false)):
		prefer.append(CHARIZARD_EX)
	for name: String in [RARE_CANDY, PIDGEOT_EX, CHARIZARD_EX, CHARMANDER, PIDGEY, ARVEN, ULTRA_BALL, BOSSS_ORDERS, COUNTER_CATCHER, FIRE_ENERGY]:
		if not prefer.has(name):
			prefer.append(name)
	return prefer


func _merge_charizard_resource_negative_actions(existing: Variant, legal_actions: Variant) -> Array:
	var result: Array = []
	if existing is Array:
		result.append_array(existing as Array)
	if not (legal_actions is Array):
		return result
	var seen_ids := {}
	for raw_existing: Variant in result:
		if raw_existing is Dictionary:
			seen_ids[str((raw_existing as Dictionary).get("id", ""))] = true
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		var action_id := str(ref.get("id", ref.get("action_id", "")))
		if action_id == "" or bool(seen_ids.get(action_id, false)):
			continue
		var reason := _charizard_resource_negative_reason(ref)
		if reason == "":
			continue
		result.append({
			"id": action_id,
			"type": str(ref.get("type", "")),
			"card": str(ref.get("card", "")),
			"target": str(ref.get("target", "")),
			"position": str(ref.get("position", "")),
			"why": reason,
		})
		seen_ids[action_id] = true
	return result


func _charizard_resource_negative_reason(ref: Dictionary) -> String:
	var kind := str(ref.get("type", ref.get("kind", "")))
	var text := _continuity_ref_text(ref)
	if kind == "play_trainer" and _name_contains(text, RARE_CANDY) and not _charizard_rare_candy_ref_has_real_target(ref):
		return "Do not play Rare Candy when the action exposes no valid Stage 2 target; preserve it for Charizard ex or Pidgeot ex conversion."
	if kind == "attach_energy":
		var target := "%s %s" % [str(ref.get("target", "")), str(ref.get("summary", ""))]
		if _name_matches_any(target, [ROTOM_V, LUMINEON_V, FEZANDIPITI_EX, MANAPHY, PIDGEY, PIDGEOT_EX]):
			return "Do not attach Fire to support or Pidgeot engine Pokemon while Charizard attacker lanes exist."
		if _name_contains(target, CHARIZARD_EX) and _name_contains(text, FIRE_ENERGY):
			return "Do not overfill an attack-ready Charizard ex beyond its real two-Fire attack cost."
	if kind == "attach_tool" and _name_contains(text, FOREST_SEAL_STONE) and not _name_matches_any(text, [ROTOM_V, LUMINEON_V]):
		return "Forest Seal Stone belongs on Rotom V or Lumineon V only."
	return ""


func _append_payload_ref_by_id(
	route_actions: Array[Dictionary],
	seen_ids: Dictionary,
	legal_actions: Array,
	action_id: String,
	policy: Dictionary = {}
) -> void:
	var ref := _payload_ref_by_id(legal_actions, action_id)
	if ref.is_empty():
		return
	var ref_id := str(ref.get("id", ref.get("action_id", ""))).strip_edges()
	if ref_id == "" or bool(seen_ids.get(ref_id, false)):
		return
	if _charizard_ref_conflicts_with_route(ref, route_actions):
		return
	route_actions.append(_charizard_route_ref(ref, policy))
	seen_ids[ref_id] = true


func _payload_ref_by_id(legal_actions: Array, action_id: String) -> Dictionary:
	if action_id.strip_edges() == "":
		return {}
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if str(ref.get("id", ref.get("action_id", ""))) == action_id:
			return ref
	return {}


func _first_payload_action_id(legal_actions: Array, action_type: String, query: String) -> String:
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if _payload_ref_is_future(ref):
			continue
		if str(ref.get("type", ref.get("kind", ""))) != action_type:
			continue
		if query != "" and not _text_matches_any_name(_continuity_ref_text(ref), [query]):
			continue
		var action_id := str(ref.get("id", ref.get("action_id", ""))).strip_edges()
		if action_id != "":
			return action_id
	return ""


func _first_payload_basic_search_action_id(legal_actions: Array) -> String:
	for query: String in [BUDDY_BUDDY_POFFIN, NEST_BALL, ULTRA_BALL, ARVEN]:
		var action_id := _first_payload_action_id(legal_actions, "play_trainer", query)
		if action_id != "":
			return action_id
	return ""


func _charizard_terminal_attack_ref(legal_actions: Array) -> Dictionary:
	var best_attack: Dictionary = {}
	var best_score := -999999
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if str(ref.get("type", ref.get("kind", ""))) not in ["attack", "granted_attack"]:
			continue
		var quality: Dictionary = ref.get("attack_quality", {}) if ref.get("attack_quality", {}) is Dictionary else {}
		if str(quality.get("terminal_priority", "")) == "low":
			continue
		var score := 500 + int(ref.get("attack_index", 0)) * 25
		if _name_matches_any(str(ref.get("attack_name", "")), ["Burning Darkness", "Combustion Blast"]):
			score += 250
		if str(quality.get("role", "")) == "primary_damage":
			score += 160
		if score > best_score:
			best_score = score
			best_attack = ref
	if best_attack.is_empty():
		return {}
	var action_id := str(best_attack.get("id", best_attack.get("action_id", ""))).strip_edges()
	return {"id": action_id, "action_id": action_id, "type": str(best_attack.get("type", "attack"))} if action_id != "" else {}


func _charizard_setup_needs_search(setup: Dictionary) -> bool:
	if bool(setup.get("continuity_enabled", false)):
		return true
	var missing_core: Array = setup.get("missing_core", []) if setup.get("missing_core", []) is Array else []
	return not missing_core.is_empty()


func _payload_ref_is_future(ref: Dictionary) -> bool:
	if bool(ref.get("future", false)):
		return true
	var action_id := str(ref.get("id", ref.get("action_id", ""))).strip_edges()
	return action_id.begins_with("future:") or action_id.begins_with("virtual:")


func _charizard_ref_conflicts_with_route(ref: Dictionary, route_actions: Array[Dictionary]) -> bool:
	var ref_id := str(ref.get("id", ref.get("action_id", "")))
	var ref_conflicts := _string_array_from_variant(ref.get("resource_conflicts", []))
	for existing: Dictionary in route_actions:
		var existing_id := str(existing.get("id", existing.get("action_id", "")))
		if ref_id != "" and existing_id == ref_id:
			return true
		if ref_conflicts.has(existing_id):
			return true
		var existing_conflicts := _string_array_from_variant(existing.get("resource_conflicts", []))
		if ref_id != "" and existing_conflicts.has(ref_id):
			return true
	return false


func _continuity_ref_text(ref: Dictionary) -> String:
	return "%s %s %s %s %s %s %s" % [
		str(ref.get("id", ref.get("action_id", ""))),
		str(ref.get("card", "")),
		str(ref.get("pokemon", "")),
		str(ref.get("target", "")),
		str(ref.get("ability", "")),
		str(ref.get("summary", "")),
		JSON.stringify(ref.get("card_rules", {})),
	]


func _text_matches_any_name(text: String, names: Array[String]) -> bool:
	for name: String in names:
		if name != "" and _name_contains(text, name):
			return true
	return false


func _string_array_from_variant(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value:
			var text := str(raw)
			if text != "":
				result.append(text)
	elif value is PackedStringArray:
		for text: String in value:
			if text != "":
				result.append(text)
	elif str(value) != "":
		result.append(str(value))
	return result


func _append_charizard_setup_catalog(target: Array[Dictionary], seen_ids: Dictionary, has_attack: bool) -> void:
	_append_charizard_rare_candy_catalog_match(target, seen_ids)
	_append_catalog_match(target, seen_ids, "evolve", "Charizard ex", "")
	_append_catalog_match(target, seen_ids, "evolve", "Pidgeot ex", "")
	_append_catalog_match(target, seen_ids, "use_ability", "", "Pidgeot ex")
	_append_catalog_match(target, seen_ids, "attach_energy", "Fire Energy", "")
	_append_catalog_match(target, seen_ids, "play_trainer", "Buddy-Buddy Poffin", "")
	_append_catalog_match(target, seen_ids, "play_trainer", "Nest Ball", "")
	_append_catalog_match(target, seen_ids, "play_trainer", "Ultra Ball", "")
	_append_catalog_match(target, seen_ids, "play_trainer", "Arven", "")
	_append_catalog_match(target, seen_ids, "play_basic_to_bench", "Charmander", "")
	_append_catalog_match(target, seen_ids, "play_basic_to_bench", "Pidgey", "")
	if not has_attack:
		_append_catalog_match(target, seen_ids, "use_ability", "", "Rotom V")
		_append_catalog_match(target, seen_ids, "play_trainer", "Iono", "")


func _append_charizard_rare_candy_catalog_match(target: Array[Dictionary], seen_ids: Dictionary) -> void:
	if target.size() >= 8:
		return
	for raw_key: Variant in _llm_action_catalog.keys():
		var action_id := str(raw_key)
		if bool(seen_ids.get(action_id, false)):
			continue
		var ref: Dictionary = _llm_action_catalog.get(action_id, {}) if _llm_action_catalog.get(action_id, {}) is Dictionary else {}
		if str(ref.get("type", ref.get("kind", ""))) != "play_trainer":
			continue
		if not _charizard_ref_has_any_name(ref, [RARE_CANDY]):
			continue
		if not _charizard_rare_candy_ref_has_real_target(ref):
			continue
		var copy := ref.duplicate(true)
		copy["id"] = action_id
		copy["action_id"] = action_id
		target.append(copy)
		seen_ids[action_id] = true
		return


func _catalog_has_charizard_setup_action() -> bool:
	for raw_key: Variant in _llm_action_catalog.keys():
		var ref: Dictionary = _llm_action_catalog.get(raw_key, {}) if _llm_action_catalog.get(raw_key, {}) is Dictionary else {}
		if ref.is_empty() or _is_future_action_ref(ref):
			continue
		var action_type := str(ref.get("type", ref.get("kind", "")))
		if action_type in ["end_turn", "attack", "granted_attack", "route"]:
			continue
		if action_type in ["evolve", "attach_energy", "play_basic_to_bench"]:
			if _charizard_ref_has_any_name(ref, ["Charizard ex", "Charmander", "Pidgeot ex", "Pidgey", "Fire Energy"]):
				return true
		if action_type == "play_trainer" and _charizard_ref_has_any_name(ref, ["Rare Candy", "Buddy-Buddy Poffin", "Nest Ball", "Ultra Ball", "Arven", "Boss", "Counter Catcher"]):
			return true
		if action_type == "use_ability" and _charizard_ref_has_any_name(ref, ["Pidgeot ex", "Charizard ex"]):
			return true
	return false


func _catalog_has_action_type(action_type: String) -> bool:
	for raw_key: Variant in _llm_action_catalog.keys():
		var ref: Dictionary = _llm_action_catalog.get(raw_key, {}) if _llm_action_catalog.get(raw_key, {}) is Dictionary else {}
		if str(ref.get("type", ref.get("kind", ""))) == action_type:
			return true
	return false


func _is_bad_charizard_energy_attach(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "attach_energy":
		return false
	var target_slot: PokemonSlot = action.get("target_slot", null)
	var card: CardInstance = action.get("card", null)
	if target_slot == null or card == null or card.card_data == null:
		return false
	if _slot_is_support_only(target_slot):
		return true
	if not _is_fire_energy_card(card):
		return false
	var target_name := _slot_best_name(target_slot)
	if not _name_matches_any(target_name, ["Pidgey", "Pidgeot ex", "Duskull", "Dusclops", "Dusknoir"]):
		return false
	return _has_charizard_attack_lane(game_state, player_index) or _catalog_has_attach_to_charizard_lane()


func _is_bad_charizard_tool_attach(action: Dictionary) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "attach_tool":
		return false
	var target_slot: PokemonSlot = action.get("target_slot", null)
	var card: CardInstance = action.get("card", null)
	if target_slot == null or card == null or card.card_data == null:
		return false
	var tool_name := _best_card_name(card.card_data)
	return _name_contains(tool_name, "Forest Seal Stone") and not _name_matches_any(_slot_best_name(target_slot), ["Rotom V", "Lumineon V"])


func _is_bad_charizard_rare_candy_play(action: Dictionary) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "play_trainer":
		return false
	var card: CardInstance = action.get("card", null)
	if card == null or card.card_data == null or not _name_contains(_best_card_name(card.card_data), RARE_CANDY):
		return false
	if bool(action.get("requires_interaction", false)):
		return false
	var targets: Variant = action.get("targets", [])
	if targets is Array and not (targets as Array).is_empty():
		return false
	return true


func _is_bad_charizard_retreat(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "retreat":
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	var active_name := _slot_best_name(player.active_pokemon)
	if not _name_matches_any(active_name, ["Charizard ex", "Pidgeot ex", "Radiant Charizard"]):
		return false
	var bench_target: PokemonSlot = action.get("bench_target", null)
	return _slot_is_support_only(bench_target)


func _charizard_rare_candy_ref_has_real_target(ref: Dictionary) -> bool:
	if ref.is_empty() or not _charizard_ref_has_any_name(ref, [RARE_CANDY]):
		return false
	if ref.has("targets") and ref.get("targets", []) is Array and not (ref.get("targets", []) as Array).is_empty():
		return true
	var schema: Dictionary = ref.get("interaction_schema", {}) if ref.get("interaction_schema", {}) is Dictionary else {}
	if schema.has("stage2_card") and schema.has("target_pokemon"):
		return true
	if bool(ref.get("requires_interaction", false)):
		return true
	return false


func _is_charizard_setup_or_resource_card(card_data: CardData) -> bool:
	if card_data == null:
		return false
	var name := _best_card_name(card_data)
	return _name_matches_any(name, [
		"Charmander", "Charmeleon", "Charizard ex", "Pidgey", "Pidgeot ex",
		"Duskull", "Dusclops", "Dusknoir", "Rare Candy", "Buddy-Buddy Poffin",
		"Nest Ball", "Ultra Ball", "Arven", "Forest Seal Stone", "Boss",
		"Counter Catcher", "Night Stretcher", "Super Rod", "Fire Energy",
		"Radiant Charizard",
	])


func _has_charizard_attack_lane(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	return _charizard_count_field_name(player, "Charizard ex") > 0 \
		or _charizard_count_field_name(player, "Charmander") > 0 \
		or _charizard_count_field_name(player, "Charmeleon") > 0


func _catalog_has_attach_to_charizard_lane() -> bool:
	for raw_key: Variant in _llm_action_catalog.keys():
		var ref: Dictionary = _llm_action_catalog.get(raw_key, {}) if _llm_action_catalog.get(raw_key, {}) is Dictionary else {}
		if str(ref.get("type", ref.get("kind", ""))) != "attach_energy":
			continue
		if _charizard_ref_has_any_name(ref, ["Charmander", "Charmeleon", "Charizard ex"]):
			return true
	return false


func _active_charizard_attack_ready(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	if not _name_matches_any(_slot_best_name(player.active_pokemon), ["Charizard ex", "Radiant Charizard"]):
		return false
	return bool(predict_attacker_damage(player.active_pokemon).get("can_attack", false))


func _charizard_count_field_name(player: PlayerState, query: String) -> int:
	if player == null:
		return 0
	var count := 0
	if _slot_name_matches(player.active_pokemon, query):
		count += 1
	for slot: PokemonSlot in player.bench:
		if _slot_name_matches(slot, query):
			count += 1
	return count


func _slot_name_matches(slot: PokemonSlot, query: String) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	return _name_contains(_slot_best_name(slot), query)


func _slot_is_support_only(slot: PokemonSlot) -> bool:
	return slot != null and _name_matches_any(_slot_best_name(slot), ["Rotom V", "Lumineon V", "Fezandipiti ex", "Manaphy"])


func _is_fire_energy_card(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	return card.card_data.is_energy() and (str(card.card_data.energy_provides) == "R" or _name_contains(_best_card_name(card.card_data), "Fire Energy"))


func _charizard_ref_has_any_name(ref: Dictionary, queries: Array[String]) -> bool:
	var combined := " ".join([
		str(ref.get("id", "")),
		str(ref.get("action_id", "")),
		str(ref.get("card", "")),
		str(ref.get("pokemon", "")),
		str(ref.get("ability", "")),
		str(ref.get("target", "")),
		str(ref.get("position", "")),
	])
	for key: String in ["card_rules", "ability_rules", "attack_rules"]:
		var raw: Variant = ref.get(key, {})
		if raw is Dictionary:
			var rules: Dictionary = raw
			combined += " %s %s %s %s" % [
				str(rules.get("name", "")),
				str(rules.get("name_en", "")),
				str(rules.get("text", "")),
				str(rules.get("description", "")),
			]
	return _name_matches_any(combined, queries)


func _name_matches_any(name: String, queries: Array[String]) -> bool:
	for query: String in queries:
		if _name_contains(name, query):
			return true
	return false


func _slot_best_name(slot: PokemonSlot) -> String:
	if slot == null or slot.get_card_data() == null:
		return ""
	return _best_card_name(slot.get_card_data())


func _best_card_name(cd: CardData) -> String:
	if cd == null:
		return ""
	if str(cd.name_en) != "":
		return str(cd.name_en)
	return str(cd.name)


func _rules_heuristic_base(kind: String) -> float:
	if _rules != null and _rules.has_method("_estimate_heuristic_base"):
		return float(_rules.call("_estimate_heuristic_base", kind))
	return 0.0
