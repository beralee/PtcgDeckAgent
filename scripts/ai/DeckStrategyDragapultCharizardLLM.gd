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


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	super.build_turn_plan(game_state, player_index, context)
	return _rules.call("build_turn_plan", game_state, player_index, context) if _rules != null and _rules.has_method("build_turn_plan") else {}


func build_turn_contract(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	return _rules.call("build_turn_contract", game_state, player_index, context) if _rules != null and _rules.has_method("build_turn_contract") else super.build_turn_contract(game_state, player_index, context)


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if _is_bad_dragapult_charizard_plan_action(action, game_state, player_index):
		return -10000.0
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		if _is_tm_evolution_granted_attack_action(action) and _llm_queue_has_opening_chip_attack(game_state, player_index):
			return 90000.0
		var llm_score := super.score_action_absolute(action, game_state, player_index)
		if llm_score >= 10000.0 or llm_score <= -1000.0:
			return llm_score
	return _rules.call("score_action_absolute", action, game_state, player_index) if _rules != null and _rules.has_method("score_action_absolute") else 0.0


func score_action(action: Dictionary, context: Dictionary) -> float:
	var context_game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if _is_bad_dragapult_charizard_plan_action(action, context_game_state, player_index):
		return -10000.0
	if context_game_state != null and has_llm_plan_for_turn(int(context_game_state.turn_number)):
		var absolute := score_action_absolute(action, context_game_state, player_index)
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
	var deck_picks := _pick_dragapult_charizard_interaction_items(items, step, context)
	if not deck_picks.is_empty():
		return deck_picks
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
	var deck_score := _score_dragapult_charizard_interaction_target(item, step, context)
	if deck_score > -900000000.0:
		return deck_score
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
	lines.append("Attack policy: Dragapult ex spread pressure is the main plan. If Dragapult ex can use Phantom Dive / 幻影潜袭 for 200 damage, choose that second attack over Jet Head / the 70-damage first attack. Jet Head is fallback only when Phantom Dive is not legal or reachable.")
	lines.append("Spread targeting policy: Phantom Dive places 6 damage counters on the opponent Bench. Concentrate counters on damaged, low-HP, or multi-prize bench targets first: exact bench KOs, then targets that become the next prize. Do not scatter counters randomly when one target creates prize pressure.")
	lines.append("Charizard policy: Charizard ex is a strong conversion attacker and Fire acceleration lane. Finish the Charmander -> Charizard ex lane before a non-final attack when Dragapult is already online and the setup is safe.")
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


func make_llm_runtime_snapshot(game_state: GameState, player_index: int) -> Dictionary:
	var snapshot := super.make_llm_runtime_snapshot(game_state, player_index)
	if snapshot.is_empty() or game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return snapshot
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	snapshot["dreepy_line_count"] = _count_field_names(player, ["Dreepy", "Drakloak", "Dragapult ex"])
	snapshot["charmander_line_count"] = _count_field_names(player, ["Charmander", "Charmeleon", "Charizard ex"])
	snapshot["dragapult_ex_count"] = _count_field_name(player, "Dragapult ex")
	snapshot["charizard_ex_count"] = _count_field_name(player, "Charizard ex")
	snapshot["phantom_dive_ready"] = _active_dragapult_pressure_ready(game_state, player_index)
	snapshot["phantom_dive_pickoff_visible"] = _phantom_dive_pickoff_visible(opponent)
	snapshot["backup_attacker_line_count"] = _backup_attacker_line_count(player)
	return snapshot


func _deck_action_ref_enables_attack(ref: Dictionary) -> bool:
	var action_type := str(ref.get("type", ref.get("kind", "")))
	if action_type == "evolve" and _ref_has_any_name(ref, ["Drakloak", "Dragapult ex", "Charmeleon", "Charizard ex"]):
		return true
	if action_type == "attach_energy" and _ref_has_any_name(ref, ["Fire Energy", "Psychic Energy"]):
		return true
	if action_type == "attach_tool" and _ref_has_any_name(ref, ["Technical Machine: Evolution", "Forest Seal Stone"]):
		return true
	if action_type == "use_ability" and _ref_has_any_name(ref, ["Drakloak", "Charizard ex", "Lumineon V"]):
		return true
	if action_type == "play_trainer" and _ref_has_any_name(ref, [
		"Rare Candy", "Buddy-Buddy Poffin", "Nest Ball", "Ultra Ball", "Arven",
		"Lance", "Energy Search", "Counter Catcher", "Boss", "Night Stretcher",
	]):
		return true
	return false


func _deck_should_block_exact_queue_match(queued_action: Dictionary, runtime_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _is_dragapult_low_value_attack_action(queued_action, game_state, player_index) \
			and _active_dragapult_pressure_ready(game_state, player_index):
		return true
	if _is_opening_chip_attack_with_tm_evolution_ready(queued_action, game_state, player_index):
		return true
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


func _deck_queue_item_matches_action(queued_action: Dictionary, runtime_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _is_dragapult_low_value_attack_action(queued_action, game_state, player_index) \
			and _is_dragapult_phantom_dive_attack_action(runtime_action, game_state, player_index):
		return true
	if _is_opening_chip_attack_with_tm_evolution_ready(queued_action, game_state, player_index) \
			and _is_tm_evolution_granted_attack_action(runtime_action):
		return true
	return false


func _deck_can_replace_end_turn_with_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _is_bad_dragapult_charizard_plan_action(action, game_state, player_index):
		return false
	if _is_dragapult_phantom_dive_attack_action(action, game_state, player_index):
		return true
	return _is_dragapult_charizard_runtime_setup_action(action, game_state, player_index)


func _deck_preferred_terminal_attack_for(action: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	if _is_opening_chip_attack_with_tm_evolution_ready(action, game_state, player_index):
		return _tm_evolution_granted_attack_ref(game_state, player_index)
	if not _is_dragapult_low_value_attack_action(action, game_state, player_index):
		return {}
	return _dragapult_phantom_dive_attack_ref(game_state, player_index)


func _deck_is_low_value_runtime_attack_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	return _is_dragapult_low_value_attack_action(action, game_state, player_index)


func _deck_is_high_pressure_attack_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _is_dragapult_phantom_dive_attack_action(action, game_state, player_index):
		return true
	if not _is_attack_action_ref(action):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	return player != null and _slot_name_matches_any(player.active_pokemon, ["Charizard ex"]) and _active_core_attack_ready(game_state, player_index)


func _deck_should_block_end_turn(game_state: GameState, player_index: int) -> bool:
	return _has_visible_dragapult_charizard_setup(game_state, player_index)


func _deck_hand_card_is_productive_piece(card_data: CardData) -> bool:
	return _is_dragapult_charizard_setup_card(card_data)


func _deck_is_setup_or_resource_card(card_data: CardData) -> bool:
	return _is_dragapult_charizard_setup_card(card_data)


func _deck_augment_action_id_payload(payload: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	var result := payload.duplicate(true)
	var facts: Dictionary = result.get("turn_tactical_facts", {}) if result.get("turn_tactical_facts", {}) is Dictionary else {}
	facts = facts.duplicate(true)
	var attack_policy := _dragapult_charizard_attack_policy_fact(result, game_state, player_index)
	if not attack_policy.is_empty():
		facts["dragapult_charizard_attack_policy"] = attack_policy
		_mark_dragapult_attack_quality_by_action_id(facts, attack_policy)
	var continuity: Dictionary = {}
	if _rules != null and _rules.has_method("build_continuity_contract"):
		continuity = _rules.call("build_continuity_contract", game_state, player_index, {})
	if not continuity.is_empty():
		facts["continuity_contract"] = _compact_continuity_contract_for_llm(continuity)
	result["turn_tactical_facts"] = facts
	var routes: Array = result.get("candidate_routes", []) if result.get("candidate_routes", []) is Array else []
	var updated_routes := routes.duplicate(true)
	var continuity_route := _dragapult_charizard_continuity_candidate_route(result, continuity, game_state, player_index)
	if not continuity_route.is_empty():
		updated_routes.push_front(continuity_route)
	var tm_evolution_route := _dragapult_charizard_tm_evolution_candidate_route(result, game_state, player_index)
	if not tm_evolution_route.is_empty():
		updated_routes.push_front(tm_evolution_route)
	var phantom_route := _dragapult_charizard_phantom_dive_candidate_route(result, attack_policy, game_state, player_index)
	if not phantom_route.is_empty():
		updated_routes.push_front(phantom_route)
	result["candidate_routes"] = updated_routes
	return result


func _dragapult_charizard_attack_policy_fact(payload: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	var legal_actions: Array = payload.get("legal_actions", []) if payload.get("legal_actions", []) is Array else []
	var jet_ref := _best_payload_attack_ref(legal_actions, 0, "Jet Head")
	var phantom_ref := _best_payload_attack_ref(legal_actions, 1, "Phantom Dive")
	if phantom_ref.is_empty():
		phantom_ref = _best_payload_attack_ref(legal_actions, 1, "幻影潜袭")
	var phantom_id := _payload_action_id(phantom_ref)
	var jet_id := _payload_action_id(jet_ref)
	var phantom_ready := phantom_id != "" and _active_dragapult_pressure_ready(game_state, player_index)
	var opponent: PlayerState = game_state.players[1 - player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	if phantom_id == "" and jet_id == "" and not phantom_ready:
		return {}
	return {
		"primary_attack_name": "Phantom Dive",
		"phantom_dive_action_id": phantom_id,
		"jet_head_action_id": jet_id,
		"phantom_dive_ready": phantom_ready,
		"jet_head_forbidden": phantom_ready and jet_id != "",
		"bench_pickoff_visible": _phantom_dive_pickoff_visible(opponent),
		"damage_counter_policy": "Use all 6 Phantom Dive counters on opponent Bench prize targets: exact KOs first, then one damaged or multi-prize target for the next prize.",
	}


func _mark_dragapult_attack_quality_by_action_id(facts: Dictionary, attack_policy: Dictionary) -> void:
	var raw_quality: Variant = facts.get("attack_quality_by_action_id", {})
	var quality_by_id: Dictionary = raw_quality.duplicate(true) if raw_quality is Dictionary else {}
	var jet_id := str(attack_policy.get("jet_head_action_id", ""))
	if jet_id != "":
		quality_by_id[jet_id] = {
			"role": "low_value_chip",
			"terminal_priority": "low",
			"takes_prize": false,
			"reason": "Jet Head is a 70-damage fallback and is forbidden while Phantom Dive is legal.",
		}
	var phantom_id := str(attack_policy.get("phantom_dive_action_id", ""))
	if phantom_id != "":
		quality_by_id[phantom_id] = {
			"role": "primary_damage",
			"terminal_priority": "high",
			"takes_prize": true,
			"reason": "Phantom Dive is the primary 200-damage attack and carries 6 bench damage counters.",
		}
	facts["attack_quality_by_action_id"] = quality_by_id
	if bool(attack_policy.get("jet_head_forbidden", false)):
		facts["redraw_attack_forbidden"] = true


func _dragapult_charizard_tm_evolution_candidate_route(payload: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	var target_count := _tm_evolution_target_count(player)
	if target_count <= 0:
		return {}
	var legal_actions: Array = payload.get("legal_actions", []) if payload.get("legal_actions", []) is Array else []
	var tm_ref := _best_payload_tm_evolution_ref(legal_actions)
	if tm_ref.is_empty():
		return {}
	var route_ref := _route_action_ref(tm_ref)
	var policy: Dictionary = route_ref.get("selection_policy", {}) if route_ref.get("selection_policy", {}) is Dictionary else {}
	policy["evolution_cards"] = "prefer Drakloak onto Dreepy, then Charmeleon onto Charmander"
	policy["evolution_bench"] = "prefer Dreepy first, then Charmander"
	route_ref["selection_policy"] = policy
	return _deck_route(
		"dragapult_charizard_tm_evolution",
		"Use TM Evolution's granted attack instead of a shallow Basic attack when it can evolve Dreepy or Charmander this turn.",
		[route_ref],
		988,
		"opening_tm_evolution_setup_attack",
		[{
			"id": "goal:tm_evolution_setup",
			"type": "goal",
			"max_targets": target_count,
		}]
	)


func _compact_continuity_contract_for_llm(continuity: Dictionary) -> Dictionary:
	var setup_debt: Dictionary = continuity.get("setup_debt", {}) if continuity.get("setup_debt", {}) is Dictionary else {}
	var bonuses: Array = continuity.get("action_bonuses", []) if continuity.get("action_bonuses", []) is Array else []
	var compact_bonuses: Array[Dictionary] = []
	for raw: Variant in bonuses:
		if not (raw is Dictionary):
			continue
		var bonus: Dictionary = raw
		compact_bonuses.append({
			"kind": str(bonus.get("kind", "")),
			"card_names": bonus.get("card_names", []),
			"target_names": bonus.get("target_names", []),
			"energy_types": bonus.get("energy_types", []),
			"bonus": float(bonus.get("bonus", 0.0)),
			"reason": str(bonus.get("reason", "")),
		})
		if compact_bonuses.size() >= 8:
			break
	return {
		"enabled": bool(continuity.get("enabled", false)),
		"safe_setup_before_attack": bool(continuity.get("safe_setup_before_attack", false)),
		"setup_debt": setup_debt,
		"action_bonuses": compact_bonuses,
		"contract": "Perform listed non-conflicting setup actions before a non-final attack; never delay a final-prize KO.",
	}


func _dragapult_charizard_continuity_candidate_route(payload: Dictionary, continuity: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	if not bool(continuity.get("enabled", false)) or not bool(continuity.get("safe_setup_before_attack", false)):
		return {}
	var legal_actions: Array = payload.get("legal_actions", []) if payload.get("legal_actions", []) is Array else []
	if legal_actions.is_empty():
		return {}
	var terminal_ref := _dragapult_charizard_terminal_attack_ref(legal_actions, game_state, player_index)
	if not terminal_ref.is_empty() and _attack_wins_game(terminal_ref, game_state, player_index):
		return {}
	var route_actions: Array[Dictionary] = []
	var seen_ids := {}
	var bonuses: Array = continuity.get("action_bonuses", []) if continuity.get("action_bonuses", []) is Array else []
	for raw_bonus: Variant in bonuses:
		if route_actions.size() >= 4:
			break
		if not (raw_bonus is Dictionary):
			continue
		var ref := _best_payload_ref_for_continuity_bonus(legal_actions, raw_bonus as Dictionary, seen_ids)
		if ref.is_empty():
			continue
		var action_id := _payload_action_id(ref)
		route_actions.append(_route_action_ref(ref))
		seen_ids[action_id] = true
	if route_actions.is_empty():
		return {}
	if terminal_ref.is_empty():
		terminal_ref = _best_payload_end_turn_ref(legal_actions)
	if not terminal_ref.is_empty():
		route_actions.append(_route_action_ref(terminal_ref))
	return _deck_route(
		"dragapult_charizard_continuity",
		"Complete safe second-attacker setup from the continuity contract before the non-final terminal action.",
		route_actions,
		986,
		"safe_setup_before_attack",
		[]
	)


func _dragapult_charizard_phantom_dive_candidate_route(payload: Dictionary, attack_policy: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	var phantom_id := str(attack_policy.get("phantom_dive_action_id", ""))
	if phantom_id == "" or not bool(attack_policy.get("phantom_dive_ready", false)):
		return {}
	var legal_actions: Array = payload.get("legal_actions", []) if payload.get("legal_actions", []) is Array else []
	var phantom_ref := _find_payload_ref_by_id(legal_actions, phantom_id)
	if phantom_ref.is_empty():
		return {}
	var route_ref := _route_action_ref(phantom_ref)
	var policy: Dictionary = route_ref.get("selection_policy", {}) if route_ref.get("selection_policy", {}) is Dictionary else {}
	policy["bench_damage_counters"] = "damaged low-HP or multi-prize bench target; exact KO first; concentrate all useful counters"
	policy["bench_target"] = "damaged low-HP or multi-prize bench target"
	route_ref["selection_policy"] = policy
	var priority := 995 if _attack_wins_game(phantom_ref, game_state, player_index) else 990
	return _deck_route(
		"dragapult_charizard_phantom_dive",
		"Use Dragapult ex Phantom Dive for 200 damage; never choose Jet Head while this route is legal.",
		[route_ref],
		priority,
		"primary_phantom_dive_attack",
		[{
			"id": "goal:phantom_dive_counters",
			"type": "goal",
			"counter_count": 6,
			"bench_pickoff_visible": bool(attack_policy.get("bench_pickoff_visible", false)),
		}]
	)


func _best_payload_ref_for_continuity_bonus(legal_actions: Array, bonus: Dictionary, seen_ids: Dictionary) -> Dictionary:
	var kind := str(bonus.get("kind", ""))
	var best_ref: Dictionary = {}
	var best_bonus := -999999.0
	for raw_ref: Variant in legal_actions:
		if not (raw_ref is Dictionary):
			continue
		var ref: Dictionary = raw_ref
		var action_id := _payload_action_id(ref)
		if action_id == "" or bool(seen_ids.get(action_id, false)) or _payload_ref_is_future(ref):
			continue
		if str(ref.get("type", ref.get("kind", ""))) != kind:
			continue
		if not _payload_ref_matches_bonus(ref, bonus):
			continue
		var value := float(bonus.get("bonus", 0.0))
		if value > best_bonus:
			best_bonus = value
			best_ref = ref
	return best_ref


func _payload_ref_matches_bonus(ref: Dictionary, bonus: Dictionary) -> bool:
	var queries: Array[String] = []
	for key: String in ["card_names", "target_names", "energy_types"]:
		var raw_values: Variant = bonus.get(key, [])
		if raw_values is Array:
			for value: Variant in raw_values:
				queries.append(str(value))
	if queries.is_empty():
		return true
	return _ref_has_any_name(ref, queries)


func _dragapult_charizard_terminal_attack_ref(legal_actions: Array, game_state: GameState, player_index: int) -> Dictionary:
	var phantom := _best_payload_attack_ref(legal_actions, 1, "Phantom Dive")
	if phantom.is_empty():
		phantom = _best_payload_attack_ref(legal_actions, 1, "幻影潜袭")
	if not phantom.is_empty() and _active_dragapult_pressure_ready(game_state, player_index):
		return phantom
	var best_ref: Dictionary = {}
	var best_damage := -1
	for raw_ref: Variant in legal_actions:
		if not (raw_ref is Dictionary):
			continue
		var ref: Dictionary = raw_ref
		if str(ref.get("type", ref.get("kind", ""))) not in ["attack", "granted_attack"]:
			continue
		if _payload_ref_is_future(ref):
			continue
		if _is_payload_low_dragapult_attack(ref, game_state, player_index):
			continue
		var damage := int(ref.get("projected_damage", ref.get("damage", 0)))
		if damage <= 0:
			damage = _parse_damage_value(str(ref.get("attack_damage", "")))
		if damage > best_damage:
			best_damage = damage
			best_ref = ref
	return best_ref


func _best_payload_attack_ref(legal_actions: Array, attack_index: int, attack_name: String) -> Dictionary:
	for raw_ref: Variant in legal_actions:
		if not (raw_ref is Dictionary):
			continue
		var ref: Dictionary = raw_ref
		if str(ref.get("type", ref.get("kind", ""))) not in ["attack", "granted_attack"]:
			continue
		if _payload_ref_is_future(ref):
			continue
		if int(ref.get("attack_index", -1)) == attack_index:
			return ref
		if attack_name != "" and _ref_has_any_name(ref, [attack_name]):
			return ref
	return {}


func _best_payload_tm_evolution_ref(legal_actions: Array) -> Dictionary:
	for raw_ref: Variant in legal_actions:
		if not (raw_ref is Dictionary):
			continue
		var ref: Dictionary = raw_ref
		if str(ref.get("type", ref.get("kind", ""))) not in ["granted_attack", "attack"]:
			continue
		if _payload_ref_is_future(ref):
			continue
		if _is_tm_evolution_granted_attack_action(ref) or _ref_has_any_name(ref, ["tm_evolution", "Evolution", "进化", "杩涘寲"]):
			return ref
	return {}


func _find_payload_ref_by_id(legal_actions: Array, action_id: String) -> Dictionary:
	for raw_ref: Variant in legal_actions:
		if raw_ref is Dictionary and _payload_action_id(raw_ref as Dictionary) == action_id:
			return raw_ref as Dictionary
	return {}


func _best_payload_end_turn_ref(legal_actions: Array) -> Dictionary:
	for raw_ref: Variant in legal_actions:
		if raw_ref is Dictionary and _payload_action_id(raw_ref as Dictionary) == "end_turn":
			return raw_ref as Dictionary
	return {}


func _deck_route(route_id: String, description: String, actions: Array[Dictionary], priority: int, goal: String, future_goals: Array[Dictionary]) -> Dictionary:
	var clean_actions: Array[Dictionary] = []
	var seen := {}
	for action: Dictionary in actions:
		var action_id := str(action.get("id", action.get("action_id", "")))
		if action_id == "":
			continue
		if action_id != "end_turn" and bool(seen.get(action_id, false)):
			continue
		seen[action_id] = true
		clean_actions.append(action)
	if clean_actions.is_empty():
		return {}
	return {
		"id": route_id,
		"route_action_id": "route:%s" % route_id,
		"type": "candidate_route",
		"priority": priority,
		"goal": goal,
		"description": description,
		"actions": clean_actions,
		"future_goals": future_goals,
		"contract": "LLM may choose route_action_id as a single action; runtime expands it into these exact action refs.",
	}


func _route_action_ref(ref: Dictionary) -> Dictionary:
	var action_id := _payload_action_id(ref)
	var result := {
		"id": action_id,
		"action_id": action_id,
		"type": str(ref.get("type", ref.get("kind", ""))),
	}
	for key: String in ["card", "pokemon", "ability", "position", "target", "attack_index", "attack_name", "projected_damage", "capability", "interactions", "selection_policy", "allow_deck_draw_lock", "granted_attack_data"]:
		if ref.has(key):
			result[key] = ref.get(key)
	return result


func _payload_action_id(ref: Dictionary) -> String:
	return str(ref.get("id", ref.get("action_id", "")))


func _payload_ref_is_future(ref: Dictionary) -> bool:
	var action_id := _payload_action_id(ref)
	return bool(ref.get("future", false)) or action_id.begins_with("future:") or str(ref.get("summary", "")).strip_edges().to_lower().begins_with("future:")


func _is_payload_low_dragapult_attack(ref: Dictionary, game_state: GameState, player_index: int) -> bool:
	return _is_dragapult_low_value_attack_action({
		"type": "attack",
		"kind": "attack",
		"attack_index": int(ref.get("attack_index", -1)),
		"attack_name": str(ref.get("attack_name", "")),
		"projected_damage": int(ref.get("projected_damage", ref.get("damage", 0))),
	}, game_state, player_index)


func _attack_wins_game(ref: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	if player == null or opponent == null or opponent.active_pokemon == null:
		return false
	var prizes_remaining := player.prizes.size()
	if prizes_remaining <= 0:
		return false
	var damage := int(ref.get("projected_damage", ref.get("damage", 0)))
	if damage <= 0:
		damage = _parse_damage_value(str(ref.get("attack_damage", "")))
	return damage >= opponent.active_pokemon.get_remaining_hp() and opponent.active_pokemon.get_prize_count() >= prizes_remaining


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
	var visible_setup := _catalog_has_dragapult_charizard_setup_action()
	for card: CardInstance in player.hand:
		if card != null and _is_dragapult_charizard_setup_card(card.card_data):
			visible_setup = true
			break
	if not visible_setup:
		return false
	if _count_field_name(player, "Dragapult ex") <= 0:
		return true
	if _count_field_name(player, "Charizard ex") <= 0:
		return true
	if _active_core_attack_ready(game_state, player_index) and _backup_attacker_line_count(player) <= 0:
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


func _is_bad_dragapult_charizard_plan_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _is_bad_dragapult_low_value_attack(action, game_state, player_index):
		return true
	if _is_opening_chip_attack_with_tm_evolution_ready(action, game_state, player_index):
		return true
	if _is_bad_dragapult_charizard_retreat(action, game_state, player_index):
		return true
	if _is_bad_dragapult_charizard_energy_attach(action, game_state, player_index):
		return true
	if _is_bad_dragapult_charizard_tool_attach(action):
		return true
	if _is_bad_dragapult_charizard_lost_vacuum(action, game_state, player_index):
		return true
	if _is_bad_dragapult_charizard_over_setup(action, game_state, player_index):
		return true
	if _is_bad_dragapult_charizard_optional_draw(action, game_state, player_index):
		return true
	return _is_rotom_terminal_draw_ref(action) and _should_block_rotom_terminal_draw(game_state, player_index)


func _is_bad_dragapult_low_value_attack(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	return _is_dragapult_low_value_attack_action(action, game_state, player_index) \
		and _active_dragapult_pressure_ready(game_state, player_index)


func _is_dragapult_low_value_attack_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _is_attack_action_ref(action):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or not _slot_name_matches_any(player.active_pokemon, ["Dragapult ex"]):
		return false
	var attack_index := int(action.get("attack_index", -1))
	var attack_name := _runtime_attack_name(action, player.active_pokemon, attack_index)
	if attack_index == 0:
		return true
	if _name_contains(attack_name, "Jet Head") or _name_contains(attack_name, "喷射头击") or _name_contains(attack_name, "鍠峰皠澶村嚮"):
		return true
	var projected_damage := int(action.get("projected_damage", action.get("damage", 0)))
	return projected_damage > 0 and projected_damage <= 90 and not _name_contains(attack_name, "Phantom Dive") and not _name_contains(attack_name, "幻影潜袭")


func _is_opening_chip_attack_with_tm_evolution_ready(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _is_attack_action_ref(action):
		return false
	if _is_tm_evolution_granted_attack_action(action):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if not _slot_name_matches_any(player.active_pokemon, ["Dreepy", "Charmander"]):
		return false
	if _tm_evolution_target_count(player) <= 0:
		return false
	var attack_index := int(action.get("attack_index", -1))
	var attack_name := _runtime_attack_name(action, player.active_pokemon, attack_index)
	var projected_damage := int(action.get("projected_damage", action.get("damage", 0)))
	if projected_damage <= 0:
		projected_damage = _parse_damage_value(str(action.get("attack_damage", "")))
	return attack_index >= 0 and projected_damage <= 70 and not _name_contains(attack_name, "Evolution")


func _llm_queue_has_opening_chip_attack(game_state: GameState, player_index: int) -> bool:
	for queued_action: Dictionary in _llm_action_queue:
		if _is_opening_chip_attack_with_tm_evolution_ready(queued_action, game_state, player_index):
			return true
	return false


func _is_tm_evolution_granted_attack_action(action: Dictionary) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "granted_attack":
		return false
	var granted_raw: Variant = action.get("granted_attack_data", {})
	if not (granted_raw is Dictionary):
		return false
	var granted: Dictionary = granted_raw
	return str(granted.get("id", "")) == "tm_evolution" or str(granted.get("name", "")) in ["Evolution", "进化", "杩涘寲"]


func _is_dragapult_phantom_dive_attack_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _is_attack_action_ref(action):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or not _slot_name_matches_any(player.active_pokemon, ["Dragapult ex"]):
		return false
	var attack_index := int(action.get("attack_index", -1))
	var attack_name := _runtime_attack_name(action, player.active_pokemon, attack_index)
	if attack_index == 1:
		return _dragapult_attack_index_cost_ready(player.active_pokemon, 1)
	if _name_contains(attack_name, "Phantom Dive") or _name_contains(attack_name, "幻影潜袭"):
		return _dragapult_attack_index_cost_ready(player.active_pokemon, 1)
	var projected_damage := int(action.get("projected_damage", action.get("damage", 0)))
	return projected_damage >= 180 and _dragapult_attack_index_cost_ready(player.active_pokemon, 1)


func _dragapult_phantom_dive_attack_ref(game_state: GameState, player_index: int) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	if player == null or not _slot_name_matches_any(player.active_pokemon, ["Dragapult ex"]):
		return {}
	if not _dragapult_attack_index_cost_ready(player.active_pokemon, 1):
		return {}
	if player.active_pokemon.get_card_data() == null or player.active_pokemon.get_card_data().attacks.size() <= 1:
		return {}
	var attack: Dictionary = player.active_pokemon.get_card_data().attacks[1] if player.active_pokemon.get_card_data().attacks[1] is Dictionary else {}
	var ref := _catalog_attack_ref_for_dragapult_index(1)
	if ref.is_empty():
		ref = {
			"type": "attack",
			"kind": "attack",
			"id": "attack:1",
			"action_id": "attack:1",
			"attack_index": 1,
			"attack_name": str(attack.get("name", "Phantom Dive")),
			"attack_rules": attack.duplicate(true),
			"projected_damage": _parse_damage_value(str(attack.get("damage", "200"))),
		}
	else:
		ref["attack_index"] = 1
		if not ref.has("attack_name"):
			ref["attack_name"] = str(attack.get("name", "Phantom Dive"))
		if not ref.has("projected_damage"):
			ref["projected_damage"] = _parse_damage_value(str(attack.get("damage", "200")))
	return ref


func _tm_evolution_granted_attack_ref(game_state: GameState, player_index: int) -> Dictionary:
	for raw_key: Variant in _llm_action_catalog.keys():
		var ref: Dictionary = _llm_action_catalog.get(raw_key, {})
		if _is_tm_evolution_granted_attack_action(ref):
			return ref
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null or _tm_evolution_target_count(player) <= 0:
		return {}
	return {
		"id": "granted_attack:tm_evolution",
		"action_id": "granted_attack:tm_evolution",
		"type": "granted_attack",
		"kind": "granted_attack",
		"source_slot": player.active_pokemon,
		"granted_attack_data": {"id": "tm_evolution", "name": "Evolution", "cost": "C", "damage": ""},
	}


func _catalog_attack_ref_for_dragapult_index(attack_index: int) -> Dictionary:
	for raw_key: Variant in _llm_action_catalog.keys():
		var ref: Dictionary = _llm_action_catalog.get(raw_key, {})
		if not _is_attack_action_ref(ref):
			continue
		if int(ref.get("attack_index", -1)) != attack_index:
			continue
		var copy: Dictionary = ref.duplicate(true)
		copy["id"] = str(raw_key)
		copy["action_id"] = str(raw_key)
		return copy
	return {}


func _dragapult_attack_index_cost_ready(slot: PokemonSlot, attack_index: int) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	var attacks: Array = slot.get_card_data().attacks
	if attack_index < 0 or attack_index >= attacks.size():
		return false
	var attack: Dictionary = attacks[attack_index] if attacks[attack_index] is Dictionary else {}
	return slot.attached_energy.size() >= str(attack.get("cost", "")).length()


func _runtime_attack_name(action: Dictionary, active_slot: PokemonSlot, attack_index: int) -> String:
	var attack_name := str(action.get("attack_name", ""))
	if attack_name.strip_edges() != "":
		return attack_name
	if active_slot == null or active_slot.get_card_data() == null:
		return ""
	var attacks: Array = active_slot.get_card_data().attacks
	if attack_index < 0 or attack_index >= attacks.size():
		return ""
	var attack: Dictionary = attacks[attack_index] if attacks[attack_index] is Dictionary else {}
	return str(attack.get("name", ""))


func _active_dragapult_pressure_ready(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if not _slot_name_matches_any(player.active_pokemon, ["Dragapult ex"]):
		return false
	if _dragapult_attack_index_cost_ready(player.active_pokemon, 1):
		return true
	var prediction: Dictionary = predict_attacker_damage(player.active_pokemon)
	return bool(prediction.get("can_attack", false)) and int(prediction.get("damage", 0)) >= 180


func _is_bad_dragapult_charizard_over_setup(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _active_dragapult_pressure_ready(game_state, player_index):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	var kind := str(action.get("kind", action.get("type", "")))
	if kind == "play_basic_to_bench":
		if _ref_has_any_name(action, ["Rotom V", "Lumineon V", "Fezandipiti ex", "Radiant Alakazam", "Manaphy"]):
			return true
		if _ref_has_any_name(action, ["Dreepy"]) and _backup_lane_count(player, ["Dreepy", "Drakloak", "Dragapult ex"]) >= 1:
			return true
		if _ref_has_any_name(action, ["Charmander"]) and _backup_lane_count(player, ["Charmander", "Charmeleon", "Charizard ex"]) >= 1:
			return true
	if kind == "play_trainer" and _ref_has_any_name(action, ["Buddy-Buddy Poffin", "Nest Ball"]):
		return _dragapult_charizard_board_should_stop_extra_setup(game_state, player_index)
	return false


func _dragapult_charizard_board_should_stop_extra_setup(game_state: GameState, player_index: int) -> bool:
	if not _active_dragapult_pressure_ready(game_state, player_index):
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	return _backup_lane_count(player, ["Dreepy", "Drakloak", "Dragapult ex"]) >= 1 \
		and _backup_lane_count(player, ["Charmander", "Charmeleon", "Charizard ex"]) >= 1


func _is_bad_dragapult_charizard_optional_draw(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "use_ability":
		return false
	if not _active_dragapult_pressure_ready(game_state, player_index):
		return false
	if _ref_has_any_name(action, ["Fezandipiti ex"]) and _player_hand_size(game_state, player_index) >= 4:
		return true
	return false


func _player_hand_size(game_state: GameState, player_index: int) -> int:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0
	var player: PlayerState = game_state.players[player_index]
	return player.hand.size() if player != null else 0


func _is_dragapult_charizard_runtime_setup_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var kind := str(action.get("kind", action.get("type", "")))
	if kind in ["play_basic_to_bench", "evolve"]:
		return _ref_has_any_name(action, ["Dreepy", "Drakloak", "Dragapult ex", "Charmander", "Charmeleon", "Charizard ex"])
	if kind == "attach_energy":
		return not _is_bad_dragapult_charizard_energy_attach(action, game_state, player_index)
	if kind == "attach_tool":
		return not _is_bad_dragapult_charizard_tool_attach(action) and _ref_has_any_name(action, ["Technical Machine: Evolution", "Forest Seal Stone"])
	if kind == "play_trainer":
		return _ref_has_any_name(action, [
			"Rare Candy", "Buddy-Buddy Poffin", "Nest Ball", "Ultra Ball", "Arven",
			"Lance", "Energy Search", "Counter Catcher", "Boss", "Night Stretcher", "Super Rod",
		])
	if kind == "use_ability":
		return _ref_has_any_name(action, ["Drakloak", "Charizard ex", "Lumineon V", "Radiant Alakazam"])
	if kind == "retreat":
		return not _is_bad_dragapult_charizard_retreat(action, game_state, player_index)
	return false


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
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		var player: PlayerState = game_state.players[player_index]
		if player != null and player.active_pokemon != null and target_slot != player.active_pokemon and _slot_name_matches_any(player.active_pokemon, ["Dragapult ex"]):
			if _card_is_energy(card, "Fire") and not _slot_has_energy(player.active_pokemon, "Fire"):
				return true
			if _card_is_energy(card, "Psychic") and not _slot_has_energy(player.active_pokemon, "Psychic"):
				return true
	if _slot_is_support_only(target_slot):
		return not _is_active_support_retreat_attach(target_slot, game_state, player_index)
	if not _slot_name_matches_any(target_slot, ["Dreepy", "Drakloak", "Dragapult ex"]):
		return false
	if not _card_is_energy(card, "Fire"):
		return false
	if _slot_has_energy(target_slot, "Psychic"):
		return false
	var position := _resolve_slot_position(target_slot, game_state, player_index)
	return _catalog_has_energy_attach_to_position("Psychic Energy", position)


func _is_active_support_retreat_attach(target_slot: PokemonSlot, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or target_slot == null or target_slot != player.active_pokemon:
		return false
	if player.bench.is_empty() or _retreat_gap(target_slot) <= 0:
		return false
	for slot: PokemonSlot in player.bench:
		if _slot_name_matches_any(slot, ["Dreepy", "Drakloak", "Dragapult ex", "Charmander", "Charmeleon", "Charizard ex"]):
			return true
	return false


func _retreat_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null:
		return 99
	return maxi(0, int(slot.get_card_data().retreat_cost) - slot.attached_energy.size())


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


func _pick_dragapult_charizard_interaction_items(items: Array, step: Dictionary, context: Dictionary) -> Array:
	var step_id := str(step.get("id", ""))
	if step_id not in ["bench_damage_counters", "bench_target"]:
		return []
	var max_select := int(step.get("max_select", items.size()))
	if max_select <= 0:
		return []
	var scored: Array[Dictionary] = []
	for i: int in items.size():
		var item: Variant = items[i]
		var score := _score_dragapult_charizard_interaction_target(item, step, context)
		if score <= -900000000.0:
			continue
		scored.append({
			"index": i,
			"item": item,
			"score": score,
		})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a := float(a.get("score", 0.0))
		var score_b := float(b.get("score", 0.0))
		if is_equal_approx(score_a, score_b):
			return int(a.get("index", -1)) < int(b.get("index", -1))
		return score_a > score_b
	)
	var picked: Array = []
	for i: int in mini(max_select, scored.size()):
		picked.append(scored[i].get("item"))
	return picked


func _score_dragapult_charizard_interaction_target(item: Variant, step: Dictionary, context: Dictionary) -> float:
	var step_id := str(step.get("id", ""))
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if item is PokemonSlot and step_id in ["bench_damage_counters", "bench_target"]:
		return _score_dragapult_spread_target(item as PokemonSlot)
	if item is CardInstance:
		var card := item as CardInstance
		if card.card_data == null:
			return -987654321.0
		var name := _best_card_name(card.card_data)
		if step_id == "stage2_card":
			if _name_contains(name, "Dragapult ex"):
				return 1250.0
			if _name_contains(name, "Charizard ex"):
				return 1180.0 if _active_dragapult_pressure_ready(game_state, player_index) else 760.0
	if item is PokemonSlot and step_id == "target_pokemon":
		var slot := item as PokemonSlot
		if _slot_name_matches_any(slot, ["Dreepy"]):
			return 1200.0
		if _slot_name_matches_any(slot, ["Charmander"]):
			if game_state == null or player_index < 0 or player_index >= game_state.players.size():
				return 980.0
			return 1050.0 if _count_field_name(game_state.players[player_index], "Dragapult ex") > 0 else 980.0
	return -987654321.0


func _score_dragapult_spread_target(slot: PokemonSlot) -> float:
	if slot == null or slot.get_top_card() == null:
		return -987654321.0
	var remaining_hp := slot.get_remaining_hp()
	var prize_count := slot.get_prize_count()
	var score := float(prize_count) * 180.0
	if remaining_hp <= 60:
		score += 1000.0 + float(prize_count) * 240.0
	elif remaining_hp <= 120:
		score += 330.0 + float(prize_count) * 100.0
	elif remaining_hp <= 180:
		score += 150.0
	if _is_rule_box(slot):
		score += 120.0
	score += float(slot.damage_counters) * 3.0
	score -= float(remaining_hp) * 0.75
	return score


func _is_rule_box(slot: PokemonSlot) -> bool:
	return slot != null and slot.get_card_data() != null and str(slot.get_card_data().mechanic) != ""


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
	var card: Variant = ref.get("card", null)
	if card is CardInstance and (card as CardInstance).card_data != null:
		combined += " %s %s" % [str((card as CardInstance).card_data.name), str((card as CardInstance).card_data.name_en)]
	for slot_key: String in ["target_slot", "source_slot", "bench_target"]:
		var raw_slot: Variant = ref.get(slot_key, null)
		if raw_slot is PokemonSlot:
			combined += " %s" % _slot_best_name(raw_slot as PokemonSlot)
	var card_rules: Variant = ref.get("card_rules", {})
	if card_rules is Dictionary:
		combined += " %s %s %s" % [
			str((card_rules as Dictionary).get("name", "")),
			str((card_rules as Dictionary).get("name_en", "")),
			str((card_rules as Dictionary).get("effect_id", "")),
		]
	var granted_raw: Variant = ref.get("granted_attack_data", {})
	if granted_raw is Dictionary:
		combined += " %s %s %s" % [
			str((granted_raw as Dictionary).get("id", "")),
			str((granted_raw as Dictionary).get("name", "")),
			str((granted_raw as Dictionary).get("text", "")),
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


func _count_field_names(player: PlayerState, queries: Array[String]) -> int:
	if player == null:
		return 0
	var count := 0
	if player.active_pokemon != null and _slot_name_matches_any(player.active_pokemon, queries):
		count += 1
	for slot: PokemonSlot in player.bench:
		if _slot_name_matches_any(slot, queries):
			count += 1
	return count


func _tm_evolution_target_count(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	var deck_has_drakloak := _deck_has_name(player, "Drakloak")
	var deck_has_charmeleon := _deck_has_name(player, "Charmeleon")
	for slot: PokemonSlot in player.bench:
		if slot == null or slot.get_top_card() == null:
			continue
		if _slot_name_matches_any(slot, ["Dreepy"]) and deck_has_drakloak:
			count += 1
		elif _slot_name_matches_any(slot, ["Charmander"]) and deck_has_charmeleon:
			count += 1
	return mini(count, 2)


func _deck_has_name(player: PlayerState, query: String) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.deck:
		if card != null and card.card_data != null and _name_contains(_best_card_name(card.card_data), query):
			return true
	return false


func _backup_attacker_line_count(player: PlayerState) -> int:
	if player == null:
		return 0
	return _backup_lane_count(player, ["Dreepy", "Drakloak", "Dragapult ex"]) \
		+ _backup_lane_count(player, ["Charmander", "Charmeleon", "Charizard ex"])


func _backup_lane_count(player: PlayerState, queries: Array[String]) -> int:
	if player == null:
		return 0
	var count := _count_field_names(player, queries)
	if _slot_name_matches_any(player.active_pokemon, queries):
		count -= 1
	return maxi(0, count)


func _phantom_dive_pickoff_visible(opponent: PlayerState) -> bool:
	if opponent == null:
		return false
	for slot: PokemonSlot in opponent.bench:
		if slot == null or slot.get_top_card() == null:
			continue
		if slot.get_remaining_hp() <= 60:
			return true
		if slot.damage_counters >= 40 and slot.get_prize_count() >= 2:
			return true
	return false


func _parse_damage_value(text: String) -> int:
	var digits := ""
	for i: int in text.length():
		var ch := text.substr(i, 1)
		if ch >= "0" and ch <= "9":
			digits += ch
		elif digits != "":
			break
	return int(digits) if digits.is_valid_int() else 0


func _slot_matches_name(slot: PokemonSlot, query: String) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	var cd: CardData = slot.get_card_data()
	return _name_contains(str(cd.name_en), query) or _name_contains(str(cd.name), query)
