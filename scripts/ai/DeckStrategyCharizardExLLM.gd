extends "res://scripts/ai/DeckStrategyLLMRuntimeBase.gd"

const CharizardRulesScript = preload("res://scripts/ai/DeckStrategyCharizardEx.gd")

const CHARIZARD_EX_LLM_ID := "charizard_ex_llm"

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
		var planned: Array = super.pick_interaction_items(items, step, context)
		if not planned.is_empty():
			return planned
	return _rules.call("pick_interaction_items", items, step, context) if _rules != null and _rules.has_method("pick_interaction_items") else []


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var game_state: GameState = context.get("game_state", null)
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var planned_score := float(super.score_interaction_target(item, step, context))
		if planned_score != 0.0:
			return planned_score
	return float(_rules.call("score_interaction_target", item, step, context)) if _rules != null and _rules.has_method("score_interaction_target") else 0.0


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if _rules != null and _rules.has_method("score_handoff_target"):
		return float(_rules.call("score_handoff_target", item, step, context))
	return score_interaction_target(item, step, context)


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
	if action_type == "play_trainer" and _name_matches_any(card_name, ["Rare Candy", "Ultra Ball", "Nest Ball", "Buddy-Buddy Poffin", "Arven"]):
		return true
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
	return false


func _deck_hand_card_is_productive_piece(card_data: CardData) -> bool:
	return _is_charizard_setup_or_resource_card(card_data)


func _deck_is_setup_or_resource_card(card_data: CardData) -> bool:
	return _is_charizard_setup_or_resource_card(card_data)


func _deck_append_short_route_followups(target: Array[Dictionary], seen_ids: Dictionary) -> void:
	_append_charizard_setup_catalog(target, seen_ids, false)


func _deck_append_productive_engine_candidates(
	target: Array[Dictionary],
	seen_ids: Dictionary,
	_actions: Array[Dictionary],
	has_attack: bool,
	_no_deck_draw_lock: bool
) -> void:
	_append_charizard_setup_catalog(target, seen_ids, has_attack)


func _deck_should_block_end_turn(game_state: GameState, player_index: int) -> bool:
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		if _active_charizard_attack_ready(game_state.players[player_index]) and _catalog_has_action_type("attack"):
			return true
	else:
		return false
	return _catalog_has_charizard_setup_action()


func _append_charizard_setup_catalog(target: Array[Dictionary], seen_ids: Dictionary, has_attack: bool) -> void:
	_append_catalog_match(target, seen_ids, "play_trainer", "Rare Candy", "")
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
