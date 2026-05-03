extends "res://scripts/ai/DeckStrategyLLMRuntimeBase.gd"

const DragapultCharizardRulesScript = preload("res://scripts/ai/DeckStrategyDragapultCharizard.gd")

const DRAGAPULT_CHARIZARD_LLM_ID := "dragapult_charizard_llm"

var _deck_strategy_text: String = ""
var _rules: RefCounted = DragapultCharizardRulesScript.new()


func get_strategy_id() -> String:
	return DRAGAPULT_CHARIZARD_LLM_ID


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
	_deck_strategy_text = text
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
	if _is_bad_dragapult_charizard_retreat(action, game_state, player_index) \
			or _is_bad_dragapult_charizard_energy_attach(action, game_state, player_index) \
			or _is_bad_dragapult_charizard_tool_attach(action) \
			or _is_bad_dragapult_charizard_lost_vacuum(action, game_state, player_index) \
			or (_is_rotom_terminal_draw_ref(action) and _should_block_rotom_terminal_draw(game_state, player_index)):
		return -10000.0
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var llm_score := super.score_action_absolute(action, game_state, player_index)
		if llm_score >= 10000.0 or llm_score <= -1000.0:
			return llm_score
	return _rules.call("score_action_absolute", action, game_state, player_index) if _rules != null and _rules.has_method("score_action_absolute") else 0.0


func score_action(action: Dictionary, context: Dictionary) -> float:
	var context_game_state: GameState = context.get("game_state", null)
	if context_game_state != null and has_llm_plan_for_turn(int(context_game_state.turn_number)):
		var absolute := score_action_absolute(action, context_game_state, int(context.get("player_index", -1)))
		return absolute - _rules_heuristic_base(str(action.get("kind", "")))
	return _rules.call("score_action", action, context) if _rules != null and _rules.has_method("score_action") else 0.0


func evaluate_board(game_state: GameState, player_index: int) -> float:
	return float(_rules.call("evaluate_board", game_state, player_index)) if _rules != null and _rules.has_method("evaluate_board") else 0.0


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	return _rules.call("predict_attacker_damage", slot, extra_context) if _rules != null and _rules.has_method("predict_attacker_damage") else {"damage": 0, "can_attack": false, "description": ""}


func get_discard_priority(card: CardInstance) -> int:
	return int(_rules.call("get_discard_priority", card)) if _rules != null and _rules.has_method("get_discard_priority") else 0


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	var priority := int(_rules.call("get_discard_priority_contextual", card, game_state, player_index)) if _rules != null and _rules.has_method("get_discard_priority_contextual") else get_discard_priority(card)
	if card == null or card.card_data == null:
		return priority
	if _is_critical_seed_search_card(card.card_data, game_state, player_index):
		return mini(priority, 8)
	if _name_contains(_best_card_name(card.card_data), "Lost Vacuum") and _is_dead_dragapult_charizard_lost_vacuum_board(game_state, player_index):
		return maxi(priority, 240)
	return priority


func get_search_priority(card: CardInstance) -> int:
	return int(_rules.call("get_search_priority", card)) if _rules != null and _rules.has_method("get_search_priority") else 0


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var context_game_state: GameState = context.get("game_state", null)
	if context_game_state != null and has_llm_plan_for_turn(int(context_game_state.turn_number)):
		var planned: Array = super.pick_interaction_items(items, step, context)
		if not planned.is_empty():
			var protected_plan: Array = _protect_dragapult_charizard_discard_picks(planned, items, step, context)
			if protected_plan.is_empty() and planned.size() > 0:
				var discard_fallback: Array = _dragapult_charizard_discard_fallback_for_step(items, step, context)
				if not discard_fallback.is_empty():
					return discard_fallback
				return _rules.call("pick_interaction_items", items, step, context) if _rules != null and _rules.has_method("pick_interaction_items") else []
			if not protected_plan.is_empty():
				return protected_plan
			return planned
		var discard_fallback: Array = _dragapult_charizard_discard_fallback_for_step(items, step, context)
		if not discard_fallback.is_empty():
			return discard_fallback
	return _rules.call("pick_interaction_items", items, step, context) if _rules != null and _rules.has_method("pick_interaction_items") else []


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var context_game_state: GameState = context.get("game_state", null)
	if context_game_state != null and has_llm_plan_for_turn(int(context_game_state.turn_number)):
		var planned_score := float(super.score_interaction_target(item, step, context))
		if planned_score != 0.0:
			return planned_score
	return float(_rules.call("score_interaction_target", item, step, context)) if _rules != null and _rules.has_method("score_interaction_target") else 0.0


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if _rules != null and _rules.has_method("score_handoff_target"):
		return float(_rules.call("score_handoff_target", item, step, context))
	return score_interaction_target(item, step, context)


func get_llm_setup_role_hint(cd: CardData) -> String:
	if cd == null:
		return "support"
	var name := _best_card_name(cd)
	if _name_contains(name, "Dreepy") or _name_contains(name, "Charmander"):
		return "priority opener: basic evolution seed for the two-stage engine"
	if _name_contains(name, "Rotom V"):
		return "fallback opener only; Quick Charge draws but ends the turn, so do not choose it before legal setup actions"
	if _name_contains(name, "Lumineon V"):
		return "support search piece; bench when its supporter search matters"
	if _name_contains(name, "Fezandipiti ex"):
		return "recovery draw after a knockout; avoid early bench unless needed"
	if _name_contains(name, "Radiant Alakazam"):
		return "damage-shift support for Dragapult math; usually not the first active"
	if _name_contains(name, "Manaphy"):
		return "bench protection tech; open only if forced"
	return "support"


func get_llm_deck_strategy_prompt(game_state: GameState, player_index: int) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("Deck plan: Dragapult ex / Charizard ex is a two-lane Stage 2 deck. Build Dreepy -> Drakloak -> Dragapult ex as the primary pressure lane, while Charmander -> Charizard ex is the acceleration and late conversion lane.")
	lines.append("Setup priority: establish at least one Dreepy and one Charmander early. Prefer Buddy-Buddy Poffin, Nest Ball, Ultra Ball, Lance, Arven, Rare Candy, and TM Evolution when they build these lines. Do not over-bench support Pokemon before the two evolution seeds are down.")
	lines.append("Engine policy: Drakloak draw, Lumineon V supporter search, Arven item/tool search, Rare Candy, Buddy-Buddy Poffin, Nest Ball, Ultra Ball, and TM Evolution are setup engines. If an engine action can create a Stage 2, enable an attack, or find missing Fire/Psychic energy, it is usually better than a shallow attack or end_turn.")
	lines.append("Rotom V policy: Quick Charge / Instant Charge is a terminal draw ability because it ends the turn. Use Rotom only after all currently legal bench, search, evolution, Rare Candy, TM Evolution, manual attach, tool, pivot, gust, or attack routes are unavailable or clearly worse. Never use Rotom before Poffin/Nest/Ultra/Arven/Rare Candy/TM/manual attach when those actions progress Dreepy, Charmander, Dragapult ex, or Charizard ex.")
	lines.append("Attack policy: Dragapult ex spread pressure is the main plan; value attacks that take an active KO while placing damage for future bench KOs. Charizard ex is a strong conversion attacker and energy accelerator. Radiant Alakazam damage movement matters when it enables Dragapult prize math.")
	lines.append("Energy policy: attach Psychic/Fire to the attacker that is closest to attacking. Dragapult ex needs both Psychic and Fire; if Psychic is available and the Dragapult line has no Psychic attached, attach Psychic before extra Fire. Charizard ex ability should place Fire energy to the Pokemon that can attack this turn or next turn; do not attach off-plan energy to Rotom V, Fezandipiti ex, Lumineon V, Radiant Alakazam, Manaphy, or other support Pokemon unless it immediately enables a retreat into an attacker.")
	lines.append("Targeting policy: prefer exact prize math. If Boss's Orders or Counter Catcher can KO a damaged bench Pokemon, close the prize. If Dragapult spread can create a two-turn prize map, choose targets that set up the next KO, not random damage.")
	lines.append("Resource policy: preserve Rare Candy, Stage 2 pieces, Arven, Counter Catcher, Boss, and recovery until they produce a concrete line. Avoid Iono/Unfair Stamp if your current hand already contains a near-complete evolution or attack conversion route. If deck_count is 12 or less, stop Rotom-style terminal draw unless it is the only way to avoid immediate loss.")
	lines.append("Tool and pivot policy: TM Evolution belongs on an early Basic evolution seed, not on an already-evolved Dragapult ex/Charizard ex. Forest Seal Stone belongs on a Pokemon V such as Rotom V or Lumineon V. Do not retreat Dragapult ex or Charizard ex into Rotom V, Fezandipiti ex, Lumineon V, Radiant Alakazam, or Manaphy unless that support Pokemon is the only legal survivor.")
	lines.append("Replan policy: after Rotom/Drakloak/Lumineon/Arven/search effects change the hand, reassess with the updated legal_actions instead of blindly following an old route.")
	var custom_text := get_deck_strategy_text().strip_edges()
	if custom_text != "":
		lines.append("Player-authored deck strategy text follows; obey it when it does not conflict with legal_actions or the structured board facts:")
		lines.append(custom_text)
	lines.append("Current tactical note: exact legal action ids, card rules, interaction schemas, HP, tools, energy, hand, discard, and opponent board are provided by the structured payload. Never invent ids or card effects.")
	return lines


func _deck_should_block_exact_queue_match(queued_action: Dictionary, runtime_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _is_bad_dragapult_charizard_retreat(runtime_action, game_state, player_index):
		return true
	if _is_bad_dragapult_charizard_energy_attach(runtime_action, game_state, player_index):
		return true
	if _is_bad_dragapult_charizard_tool_attach(runtime_action):
		return true
	if _is_bad_dragapult_charizard_lost_vacuum(runtime_action, game_state, player_index) or _is_bad_dragapult_charizard_lost_vacuum(queued_action, game_state, player_index):
		return true
	if (_is_rotom_terminal_draw_ref(queued_action) or _is_rotom_terminal_draw_ref(runtime_action)) and _should_block_rotom_terminal_draw(game_state, player_index):
		return true
	if not (_is_rotom_terminal_draw_ref(queued_action) or _is_rotom_terminal_draw_ref(runtime_action)):
		return false
	return _has_visible_dragapult_charizard_setup(game_state, player_index)


func _deck_should_block_end_turn(game_state: GameState, player_index: int) -> bool:
	return _has_visible_dragapult_charizard_setup(game_state, player_index)


func _deck_hand_card_is_productive_piece(card_data: CardData) -> bool:
	return _is_dragapult_charizard_setup_card(card_data)


func _deck_is_setup_or_resource_card(card_data: CardData) -> bool:
	return _is_dragapult_charizard_setup_card(card_data)


func _deck_append_short_route_followups(target: Array[Dictionary], seen_ids: Dictionary) -> void:
	_append_dragapult_charizard_setup_catalog(target, seen_ids, false)


func _deck_append_productive_engine_candidates(
	target: Array[Dictionary],
	seen_ids: Dictionary,
	_actions: Array[Dictionary],
	has_attack: bool,
	_no_deck_draw_lock: bool
) -> void:
	_append_dragapult_charizard_setup_catalog(target, seen_ids, has_attack)


func _rules_heuristic_base(kind: String) -> float:
	if _rules != null and _rules.has_method("_estimate_heuristic_base"):
		return float(_rules.call("_estimate_heuristic_base", kind))
	return 0.0


func _best_card_name(cd: CardData) -> String:
	if cd == null:
		return ""
	if str(cd.name_en) != "":
		return str(cd.name_en)
	return str(cd.name)


func _append_dragapult_charizard_setup_catalog(target: Array[Dictionary], seen_ids: Dictionary, has_attack: bool) -> void:
	_append_catalog_match(target, seen_ids, "play_basic_to_bench", "Dreepy", "")
	_append_catalog_match(target, seen_ids, "play_basic_to_bench", "Charmander", "")
	_append_catalog_match(target, seen_ids, "play_trainer", "Buddy-Buddy Poffin", "")
	_append_catalog_match(target, seen_ids, "play_trainer", "Nest Ball", "")
	_append_catalog_match(target, seen_ids, "play_trainer", "Ultra Ball", "")
	_append_catalog_match(target, seen_ids, "play_trainer", "Arven", "")
	_append_catalog_match(target, seen_ids, "play_trainer", "Rare Candy", "")
	_append_catalog_match(target, seen_ids, "play_trainer", "Technical Machine: Evolution", "")
	_append_catalog_match(target, seen_ids, "evolve", "Drakloak", "")
	_append_catalog_match(target, seen_ids, "evolve", "Dragapult ex", "")
	_append_catalog_match(target, seen_ids, "evolve", "Charizard ex", "")
	_append_catalog_match(target, seen_ids, "attach_energy", "Psychic Energy", "")
	_append_catalog_match(target, seen_ids, "attach_energy", "Fire Energy", "")
	_append_catalog_match(target, seen_ids, "play_trainer", "Energy Search", "")
	if not has_attack:
		_append_catalog_match(target, seen_ids, "use_ability", "", "Drakloak")
		_append_catalog_match(target, seen_ids, "use_ability", "", "Lumineon V")
		_append_catalog_match(target, seen_ids, "play_trainer", "Iono", "")


func _has_visible_dragapult_charizard_setup(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	if _count_field_name(player, "Dragapult ex") > 0 and _count_field_name(player, "Charizard ex") > 0:
		return false
	if _catalog_has_dragapult_charizard_setup_action():
		return true
	for card: CardInstance in player.hand:
		if card != null and _is_dragapult_charizard_setup_card(card.card_data):
			return true
	return false


func _active_core_attack_ready(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	var active_name := _slot_best_name(player.active_pokemon)
	if not _name_matches_any(active_name, ["Dragapult ex", "Charizard ex"]):
		return false
	var prediction: Dictionary = predict_attacker_damage(player.active_pokemon)
	if not bool(prediction.get("can_attack", false)):
		return false
	return int(prediction.get("damage", 0)) >= 160


func _catalog_has_dragapult_charizard_setup_action() -> bool:
	for raw_key: Variant in _llm_action_catalog.keys():
		var ref: Dictionary = _llm_action_catalog.get(raw_key, {})
		if ref.is_empty() or _is_future_action_ref(ref):
			continue
		if _is_rotom_terminal_draw_ref(ref):
			continue
		var action_type := str(ref.get("type", ref.get("kind", "")))
		if action_type in ["end_turn", "attack", "granted_attack", "route"]:
			continue
		if action_type in ["play_basic_to_bench", "evolve", "attach_energy", "attach_tool", "retreat"]:
			return true
		if action_type == "play_trainer" and _ref_has_any_name(ref, [
			"Buddy-Buddy Poffin", "Nest Ball", "Ultra Ball", "Arven", "Rare Candy",
			"Technical Machine: Evolution", "Energy Search", "Forest Seal Stone",
			"Counter Catcher", "Boss", "Night Stretcher", "Super Rod",
		]):
			return true
		if action_type == "use_ability" and _ref_has_any_name(ref, ["Drakloak", "Lumineon V", "Fezandipiti ex", "Radiant Alakazam"]):
			return true
	return false


func _is_dragapult_charizard_setup_card(card_data: CardData) -> bool:
	if card_data == null:
		return false
	var name := _best_card_name(card_data)
	var setup_names := [
		"Dreepy", "Drakloak", "Dragapult ex", "Charmander", "Charmeleon", "Charizard ex",
		"Buddy-Buddy Poffin", "Nest Ball", "Ultra Ball", "Arven", "Rare Candy",
		"Technical Machine: Evolution", "Energy Search", "Forest Seal Stone",
		"Counter Catcher", "Boss", "Night Stretcher", "Super Rod", "Psychic Energy", "Fire Energy",
	]
	for query: String in setup_names:
		if _name_contains(name, query):
			return true
	return false


func _is_rotom_terminal_draw_ref(ref: Dictionary) -> bool:
	if ref.is_empty():
		return false
	var action_type := str(ref.get("type", ref.get("kind", "")))
	if action_type != "use_ability":
		return false
	var source_slot: PokemonSlot = ref.get("source_slot", null)
	if source_slot != null and _slot_name_matches_any(source_slot, ["Rotom V"]):
		return true
	if _action_ref_has_tag(ref, "ends_turn"):
		return true
	if _ref_has_any_name(ref, ["Rotom V", "Quick Charge", "Instant Charge"]):
		return true
	var rules: Dictionary = ref.get("card_rules", {}) if ref.get("card_rules", {}) is Dictionary else {}
	return str(rules.get("effect_id", "")) == "8ef5ff61fd97838af568f00fe3b0e3ea"


func _should_block_rotom_terminal_draw(game_state: GameState, player_index: int) -> bool:
	if _active_core_attack_ready(game_state, player_index):
		return true
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	return player != null and player.deck.size() <= 12


func _is_bad_dragapult_charizard_retreat(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "retreat":
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	var active_name := _slot_best_name(player.active_pokemon)
	if not _name_matches_any(active_name, ["Dragapult ex", "Charizard ex"]):
		return false
	var bench_target: PokemonSlot = action.get("bench_target", null)
	if bench_target == null:
		return false
	return _slot_is_support_only(bench_target)


func _is_bad_dragapult_charizard_energy_attach(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "attach_energy":
		return false
	var target_slot: PokemonSlot = action.get("target_slot", null)
	var card: CardInstance = action.get("card", null)
	if target_slot == null or card == null or card.card_data == null:
		return false
	if _slot_is_support_only(target_slot):
		return true
	if not _slot_name_matches_any(target_slot, ["Dreepy", "Drakloak", "Dragapult ex"]):
		return false
	if not _card_is_energy(card, "Fire"):
		return false
	if _slot_has_energy(target_slot, "Psychic"):
		return false
	var position := _resolve_slot_position(target_slot, game_state, player_index)
	return _catalog_has_energy_attach_to_position("Psychic Energy", position)


func _is_bad_dragapult_charizard_tool_attach(action: Dictionary) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "attach_tool":
		return false
	var target_slot: PokemonSlot = action.get("target_slot", null)
	var card: CardInstance = action.get("card", null)
	if target_slot == null or card == null or card.card_data == null:
		return false
	var tool_name := _best_card_name(card.card_data)
	if _name_contains(tool_name, "Technical Machine: Evolution") and not _slot_name_matches_any(target_slot, ["Dreepy", "Charmander"]):
		return true
	if _name_contains(tool_name, "Forest Seal Stone") and not _slot_name_matches_any(target_slot, ["Rotom V", "Lumineon V"]):
		return true
	return false


func _protect_dragapult_charizard_discard_picks(planned: Array, items: Array, step: Dictionary, context: Dictionary) -> Array:
	var step_id := str(step.get("id", ""))
	if step_id not in ["discard_card", "discard_cards", "discard_energy"]:
		return planned
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null:
		return planned
	var filtered: Array = []
	for item: Variant in planned:
		if item is CardInstance and (item as CardInstance).card_data != null:
			if _is_critical_seed_search_card((item as CardInstance).card_data, game_state, player_index):
				continue
		filtered.append(item)
	if filtered.size() == planned.size():
		return planned
	var max_select := int(step.get("max_select", planned.size()))
	if max_select <= 0:
		max_select = planned.size()
	var required_count := mini(max_select, planned.size())
	if filtered.size() < required_count:
		return _best_dragapult_charizard_discard_fallback(items, step, game_state, player_index)
	if filtered.size() > max_select:
		return filtered.slice(0, max_select)
	return filtered


func _dragapult_charizard_discard_fallback_for_step(items: Array, step: Dictionary, context: Dictionary) -> Array:
	var step_id := str(step.get("id", ""))
	if step_id not in ["discard_card", "discard_cards", "discard_energy"]:
		return []
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null:
		return []
	return _best_dragapult_charizard_discard_fallback(items, step, game_state, player_index)


func _best_dragapult_charizard_discard_fallback(items: Array, step: Dictionary, game_state: GameState, player_index: int) -> Array:
	var max_select := int(step.get("max_select", items.size()))
	if max_select <= 0:
		max_select = items.size()
	var ranked: Array[Dictionary] = []
	for item: Variant in items:
		if not (item is CardInstance) or (item as CardInstance).card_data == null:
			continue
		if _is_critical_seed_search_card((item as CardInstance).card_data, game_state, player_index):
			continue
		ranked.append({
			"card": item,
			"score": get_discard_priority_contextual(item as CardInstance, game_state, player_index),
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("score", 0)) > int(b.get("score", 0))
	)
	var result: Array = []
	for entry: Dictionary in ranked:
		if result.size() >= max_select:
			break
		result.append(entry.get("card"))
	return result


func _is_bad_dragapult_charizard_lost_vacuum(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "play_trainer":
		return false
	if not _action_name_matches(action, "Lost Vacuum"):
		return false
	return _is_dead_dragapult_charizard_lost_vacuum_board(game_state, player_index)


func _is_dead_dragapult_charizard_lost_vacuum_board(game_state: GameState, player_index: int) -> bool:
	if game_state == null:
		return false
	if _opponent_has_attached_tool(game_state, player_index):
		return false
	return not _stadium_is_harmful_to_dragapult_charizard(game_state.stadium_card)


func _opponent_has_attached_tool(game_state: GameState, player_index: int) -> bool:
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[opponent_index]
	if opponent == null:
		return false
	if opponent.active_pokemon != null and opponent.active_pokemon.attached_tool != null:
		return true
	for slot: PokemonSlot in opponent.bench:
		if slot != null and slot.attached_tool != null:
			return true
	return false


func _stadium_is_harmful_to_dragapult_charizard(stadium: CardInstance) -> bool:
	if stadium == null or stadium.card_data == null:
		return false
	var stadium_name := _best_card_name(stadium.card_data)
	if stadium_name == "":
		return false
	if _name_matches_any(stadium_name, ["Magma Basin", "Temple of Sinnoh"]):
		return false
	return true


func _is_critical_seed_search_card(card_data: CardData, game_state: GameState, player_index: int) -> bool:
	if card_data == null or game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	var missing_seed := _count_field_name(player, "Dreepy") == 0 or _count_field_name(player, "Charmander") == 0
	if not missing_seed:
		return false
	var name := _best_card_name(card_data)
	return _name_matches_any(name, ["Buddy-Buddy Poffin", "Nest Ball", "Ultra Ball", "Arven", "Lance"])


func _action_name_matches(action: Dictionary, query: String) -> bool:
	var combined := " ".join([
		str(action.get("card", "")),
		str(action.get("pokemon", "")),
		str(action.get("summary", "")),
		str(action.get("id", action.get("action_id", ""))),
	])
	var card: Variant = action.get("card")
	if card is CardInstance and (card as CardInstance).card_data != null:
		combined += " %s %s" % [str((card as CardInstance).card_data.name), str((card as CardInstance).card_data.name_en)]
	var rules: Variant = action.get("card_rules", {})
	if rules is Dictionary:
		combined += " %s %s" % [str((rules as Dictionary).get("name", "")), str((rules as Dictionary).get("name_en", ""))]
	return _name_contains(combined, query)


func _ref_has_any_name(ref: Dictionary, queries: Array[String]) -> bool:
	var combined := " ".join([
		str(ref.get("id", "")),
		str(ref.get("card", "")),
		str(ref.get("pokemon", "")),
		str(ref.get("ability", "")),
		str(ref.get("target", "")),
	])
	var card_rules: Variant = ref.get("card_rules", {})
	if card_rules is Dictionary:
		combined += " %s %s %s" % [
			str((card_rules as Dictionary).get("name", "")),
			str((card_rules as Dictionary).get("name_en", "")),
			str((card_rules as Dictionary).get("effect_id", "")),
		]
	var ability_rules: Variant = ref.get("ability_rules", {})
	if ability_rules is Dictionary:
		combined += " %s %s" % [
			str((ability_rules as Dictionary).get("name", "")),
			str((ability_rules as Dictionary).get("text", "")),
		]
	for query: String in queries:
		if _name_contains(combined, query):
			return true
	return false


func _catalog_has_energy_attach_to_position(energy_query: String, position: String) -> bool:
	if position == "":
		return false
	for raw_key: Variant in _llm_action_catalog.keys():
		var ref: Dictionary = _llm_action_catalog.get(raw_key, {})
		if str(ref.get("type", ref.get("kind", ""))) != "attach_energy":
			continue
		if str(ref.get("position", "")) != position:
			continue
		if _ref_has_any_name(ref, [energy_query]):
			return true
	return false


func _slot_is_support_only(slot: PokemonSlot) -> bool:
	return _slot_name_matches_any(slot, ["Rotom V", "Fezandipiti ex", "Lumineon V", "Radiant Alakazam", "Manaphy"])


func _slot_name_matches_any(slot: PokemonSlot, queries: Array[String]) -> bool:
	return _name_matches_any(_slot_best_name(slot), queries)


func _slot_best_name(slot: PokemonSlot) -> String:
	if slot == null or slot.get_card_data() == null:
		return ""
	return _best_card_name(slot.get_card_data())


func _name_matches_any(name: String, queries: Array[String]) -> bool:
	for query: String in queries:
		if _name_contains(name, query):
			return true
	return false


func _card_is_energy(card: CardInstance, query: String) -> bool:
	if card == null or card.card_data == null:
		return false
	return card.card_data.is_energy() and (_name_contains(_best_card_name(card.card_data), query) or _energy_type_matches(query, str(card.card_data.energy_provides)))


func _slot_has_energy(slot: PokemonSlot, query: String) -> bool:
	if slot == null:
		return false
	for energy: CardInstance in slot.attached_energy:
		if _card_is_energy(energy, query):
			return true
	return false


func _count_field_name(player: PlayerState, query: String) -> int:
	if player == null:
		return 0
	var count := 0
	if player.active_pokemon != null and _slot_matches_name(player.active_pokemon, query):
		count += 1
	for slot: PokemonSlot in player.bench:
		if _slot_matches_name(slot, query):
			count += 1
	return count


func _slot_matches_name(slot: PokemonSlot, query: String) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	var cd: CardData = slot.get_card_data()
	return _name_contains(str(cd.name_en), query) or _name_contains(str(cd.name), query)
