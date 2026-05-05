extends "res://scripts/ai/DeckStrategyLLMRuntimeBase.gd"

const LugiaArcheopsRulesScript = preload("res://scripts/ai/DeckStrategyLugiaArcheops.gd")

const LUGIA_ARCHETYPE_LLM_ID := "lugia_archeops_llm"
const LUGIA_V := "Lugia V"
const LUGIA_VSTAR := "Lugia VSTAR"
const ARCHEOPS := "Archeops"
const MINCCINO := "Minccino"
const CINCCINO := "Cinccino"
const LUMINEON_V := "Lumineon V"
const FEZANDIPITI_EX := "Fezandipiti ex"
const IRON_HANDS_EX := "Iron Hands ex"
const BLOODMOON_URSALUNA_EX := "Bloodmoon Ursaluna ex"
const WELLSPRING_OGERPON_EX := "Wellspring Mask Ogerpon ex"
const CORNERSTONE_OGERPON_EX := "Cornerstone Mask Ogerpon ex"

var _deck_strategy_text: String = ""
var _rules: RefCounted = LugiaArcheopsRulesScript.new()


func get_strategy_id() -> String:
	return LUGIA_ARCHETYPE_LLM_ID


func get_signature_names() -> Array[String]:
	var names: Array[String] = []
	if _rules != null and _rules.has_method("get_signature_names"):
		for raw_name: Variant in _rules.call("get_signature_names"):
			names.append(str(raw_name))
	for name: String in [
		LUGIA_V,
		LUGIA_VSTAR,
		ARCHEOPS,
		MINCCINO,
		CINCCINO,
		IRON_HANDS_EX,
		BLOODMOON_URSALUNA_EX,
	]:
		if not names.has(name):
			names.append(name)
	return names


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


func build_continuity_contract(game_state: GameState, player_index: int, turn_contract: Dictionary = {}) -> Dictionary:
	return _rules.call("build_continuity_contract", game_state, player_index, turn_contract) if _rules != null and _rules.has_method("build_continuity_contract") else {}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		if _is_lugia_low_deck_unplanned_draw_action(action, game_state, player_index):
			return -10000.0
		var llm_score := super.score_action_absolute(action, game_state, player_index)
		if llm_score >= 10000.0 or llm_score <= -1000.0:
			return llm_score
		if _is_lugia_low_deck_unplanned_draw_action(action, game_state, player_index):
			return -10000.0
	if _is_lugia_low_deck_unplanned_draw_action(action, game_state, player_index):
		return -10000.0
	return _rules_score_action_absolute(action, game_state, player_index)


func score_action(action: Dictionary, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var absolute := score_action_absolute(action, game_state, player_index)
		return absolute - _rules_heuristic_base(str(action.get("kind", "")))
	var turn_plan := _context_turn_plan(context)
	if not turn_plan.is_empty() and _rules != null and _rules.has_method("score_action_absolute_with_plan"):
		return float(_rules.call("score_action_absolute_with_plan", action, game_state, player_index, turn_plan)) - _rules_heuristic_base(str(action.get("kind", "")))
	return _rules.call("score_action", action, context) if _rules != null and _rules.has_method("score_action") else 0.0


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


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var game_state: GameState = context.get("game_state", null)
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var planned: Array = super.pick_interaction_items(items, step, context)
		if not planned.is_empty():
			var protected_plan := _protect_lugia_interaction_picks(planned, items, step, context)
			if protected_plan.is_empty() and planned.size() > 0:
				var fallback := _lugia_interaction_fallback_for_step(items, step, context)
				if not fallback.is_empty():
					return fallback
				return _rules.call("pick_interaction_items", items, step, context) if _rules != null and _rules.has_method("pick_interaction_items") else []
			return _repair_lugia_search_interaction_picks(protected_plan, items, step, context)
	var deck_fallback := _lugia_interaction_fallback_for_step(items, step, context)
	if not deck_fallback.is_empty():
		return deck_fallback
	return _rules.call("pick_interaction_items", items, step, context) if _rules != null and _rules.has_method("pick_interaction_items") else []


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var game_state: GameState = context.get("game_state", null)
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var player_index := int(context.get("player_index", -1))
		var planned_score := float(super.score_interaction_target(item, step, context))
		if planned_score != 0.0:
			if _is_discard_step(step) and item is CardInstance:
				var card: CardInstance = item as CardInstance
				if card.card_data != null and _is_lugia_protected_discard_card(card.card_data, game_state, player_index):
					return minf(planned_score, -1000.0)
			if _is_assignment_target_step(step) and item is PokemonSlot:
				var slot: PokemonSlot = item as PokemonSlot
				if _slot_is_bad_lugia_energy_assignment_target(slot):
					return minf(planned_score, -1000.0)
			return planned_score
	var deck_score := _lugia_interaction_target_score_override(item, step, context)
	if deck_score != 0.0:
		return deck_score
	return _rules_score_interaction_target(item, step, context)


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if _rules != null and _rules.has_method("score_handoff_target"):
		return _rules_score_handoff_target(item, step, context)
	return score_interaction_target(item, step, context)


func make_llm_runtime_snapshot(game_state: GameState, player_index: int) -> Dictionary:
	var snapshot: Dictionary = super.make_llm_runtime_snapshot(game_state, player_index)
	if snapshot.is_empty() or game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return snapshot
	var player: PlayerState = game_state.players[player_index]
	var archeops_field := _count_field_name(player, ARCHEOPS)
	var archeops_discard := _count_discard_name(player, ARCHEOPS)
	snapshot["lugia_field_count"] = _count_field_name(player, LUGIA_V) + _count_field_name(player, LUGIA_VSTAR)
	snapshot["lugia_vstar_field_count"] = _count_field_name(player, LUGIA_VSTAR)
	snapshot["archeops_field_count"] = archeops_field
	snapshot["archeops_discard_count"] = archeops_discard
	snapshot["minccino_field_count"] = _count_field_name(player, MINCCINO)
	snapshot["cinccino_field_count"] = _count_field_name(player, CINCCINO)
	snapshot["lugia_engine_online"] = archeops_field > 0
	snapshot["summoning_star_ready"] = _count_field_name(player, LUGIA_VSTAR) > 0 and archeops_discard > 0
	snapshot["ready_attacker_count"] = _count_ready_lugia_attackers(player)
	snapshot["ready_backup_attacker_count"] = _count_ready_lugia_backup_attackers(player)
	snapshot["field_energy_count"] = _count_field_energy(player)
	return snapshot


func get_llm_setup_role_hint(cd: CardData) -> String:
	if cd == null:
		return "support"
	var name := _best_card_name(cd)
	if _name_contains(name, LUGIA_V):
		return "highest priority opener and Summoning Star shell owner; establish it early"
	if _name_contains(name, MINCCINO):
		return "priority bench seed for Cinccino follow-up attacker"
	if _name_contains(name, LUGIA_VSTAR):
		return "evolution and Summoning Star engine piece; not an opening Basic"
	if _name_contains(name, ARCHEOPS):
		return "discard and summon engine; usually wants discard before Lugia VSTAR ability"
	if _name_contains(name, CINCCINO):
		return "special-energy scaling attacker after the Archeops engine is online"
	if _name_contains(name, LUMINEON_V):
		return "supporter search piece; bench only when the supporter route matters"
	if _name_contains(name, FEZANDIPITI_EX):
		return "comeback draw support after a knockout; avoid unnecessary early bench"
	if _is_lugia_side_attacker_name(name):
		return "side attacker for specific prize maps after Lugia engine setup"
	return "support"


func get_llm_deck_strategy_prompt(game_state: GameState, player_index: int) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("Deck plan: Lugia VSTAR / Archeops is a shell-and-convert deck. Build Lugia V into Lugia VSTAR, discard one or two Archeops, use Summoning Star, then let Archeops attach Special Energy to Lugia VSTAR, Cinccino, Iron Hands ex, Bloodmoon Ursaluna ex, or Ogerpon ex attackers.")
	lines.append("Early setup: prioritize Lugia V plus at least one follow-up seed such as Minccino. Ultra Ball, Capturing Aroma, Great Ball, Professor's Research, Carmine, Jacq, and Lumineon V should serve the Lugia VSTAR plus Archeops-discard plan.")
	lines.append("Capturing Aroma policy: the coin flip determines whether only Evolution or only Basic Pokemon are selectable after the action starts. Give ranked search intent for the current board, but expect execution to choose from the actual revealed pool. If only Basics are offered after Lugia plus Archeops are online, prefer meaningful closers such as Bloodmoon Ursaluna ex or Iron Hands ex over low-impact Ogerpon padding.")
	lines.append("Archeops policy: Archeops in hand is often discard fuel before Summoning Star. Do not preserve two Archeops in hand if a legal discard/search route can put them in discard and create Summoning Star pressure.")
	lines.append("Summoning Star policy: use Lugia VSTAR's VSTAR ability when one or two Archeops are in discard, especially two. Avoid spending the VSTAR ability before Archeops is available unless no productive route remains.")
	lines.append("Primal Turbo policy: after Archeops is online, attach Special Energy to the Pokemon closest to attacking this turn or next turn. Lugia VSTAR stabilizes the board, Cinccino scales with Special Energy, Iron Hands ex is for extra-prize lines, and Bloodmoon Ursaluna ex closes late games.")
	lines.append("Energy policy: protect Special Energy. Double Turbo, Gift, Jet, Mist, V Guard, and Legacy Energy are engine resources, not random attachments. Prefer attack-cost completion and prize pressure over padding a support Pokemon.")
	lines.append("Attack policy: attack is terminal. Before attacking, perform safe setup, evolution, search, tool, Archeops acceleration, pivot, gust, and manual attach that improve this turn's prize pressure or next-turn continuity. Low-value setup or redraw attacks are fallback only.")
	lines.append("Prize policy: prefer a current KO or a two-turn prize map. Use Boss's Orders, Counter Catcher, Iron Hands ex, Cinccino scaling, or Bloodmoon Ursaluna ex when they convert prizes; do not gust without damage or survival purpose.")
	lines.append("Resource policy: once Archeops is online and an attacker is ready, stop optional draw/churn unless it unlocks a KO, a safer attacker, or a required next-turn engine piece.")
	var custom_text := get_deck_strategy_text().strip_edges()
	if custom_text != "":
		lines.append("Player-authored Lugia strategy text follows; obey it when it does not conflict with legal_actions, card rules, current board facts, or resource constraints:")
		lines.append(custom_text)
	lines.append("Execution boundary: exact action ids, legal actions, card rules, interaction_schema fields, HP, attached tools, energy, hand, discard, prizes, and opponent board come from the structured payload. Never invent ids, card effects, targets, or interaction keys.")
	return lines


func _deck_action_ref_enables_attack(ref: Dictionary) -> bool:
	var action_type := str(ref.get("type", ref.get("kind", "")))
	if action_type == "use_ability" and _ref_has_any_name(ref, [LUGIA_VSTAR, ARCHEOPS, "Summoning Star", "Primal Turbo"]):
		return true
	if action_type == "evolve" and _ref_has_any_name(ref, [LUGIA_VSTAR, CINCCINO]):
		return true
	if action_type == "attach_energy" and _ref_is_special_energy(ref):
		return true
	if action_type == "play_trainer" and _ref_has_any_name(ref, [
		"Ultra Ball",
		"Capturing Aroma",
		"Great Ball",
		"Professor",
		"Carmine",
		"Jacq",
		"Boss",
		"Counter Catcher",
	]):
		return true
	return false


func _deck_hand_card_is_productive_piece(card_data: CardData) -> bool:
	return _is_lugia_setup_card(card_data)


func _deck_is_setup_or_resource_card(card_data: CardData) -> bool:
	return _is_lugia_setup_card(card_data)


func _deck_append_short_route_followups(target: Array[Dictionary], seen_ids: Dictionary) -> void:
	_append_lugia_setup_catalog(target, seen_ids, false, false)


func _deck_append_productive_engine_candidates(
	target: Array[Dictionary],
	seen_ids: Dictionary,
	_actions: Array[Dictionary],
	has_attack: bool,
	_no_deck_draw_lock: bool
) -> void:
	_append_lugia_setup_catalog(target, seen_ids, has_attack, _no_deck_draw_lock)


func _deck_should_block_end_turn(game_state: GameState, player_index: int) -> bool:
	return _has_visible_lugia_setup(game_state, player_index)


func _deck_can_replace_end_turn_with_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _is_lugia_low_deck_unplanned_draw_action(action, game_state, player_index):
		return false
	var kind := str(action.get("kind", action.get("type", "")))
	if kind == "retreat":
		return _is_lugia_productive_end_turn_replacement_retreat(action, game_state, player_index)
	if kind in ["attack", "granted_attack"]:
		return _is_lugia_productive_end_turn_replacement_attack(action, game_state, player_index)
	return _is_lugia_runtime_setup_action(action, game_state, player_index)


func _deck_should_block_exact_queue_match(queued_action: Dictionary, runtime_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var kind := str(runtime_action.get("kind", runtime_action.get("type", "")))
	if _is_lugia_low_deck_unplanned_draw_action(runtime_action, game_state, player_index):
		return true
	if kind in ["attack", "granted_attack"] and _deck_is_low_value_runtime_attack_action(runtime_action, game_state, player_index):
		return true
	if kind == "attach_energy" and _is_bad_lugia_energy_attach(runtime_action):
		return true
	if kind == "retreat" and _is_bad_lugia_retreat(runtime_action, game_state, player_index):
		return true
	return false


func _deck_replan_trigger_after_state_change(before_snapshot: Dictionary, after_snapshot: Dictionary, context: Dictionary) -> Dictionary:
	var before_archeops := int(before_snapshot.get("archeops_field_count", 0))
	var after_archeops := int(after_snapshot.get("archeops_field_count", 0))
	if after_archeops > before_archeops:
		return {
			"should_replan": true,
			"reason": "lugia_summoning_star_archeops_online",
			"before_archeops_field_count": before_archeops,
			"after_archeops_field_count": after_archeops,
		}
	var before_ready := int(before_snapshot.get("ready_attacker_count", 0))
	var after_ready := int(after_snapshot.get("ready_attacker_count", 0))
	var before_energy := int(before_snapshot.get("field_energy_count", 0))
	var after_energy := int(after_snapshot.get("field_energy_count", 0))
	if after_ready > before_ready and after_energy > before_energy:
		return {
			"should_replan": true,
			"reason": "lugia_energy_acceleration_unlocked_attack",
			"before_ready_attacker_count": before_ready,
			"after_ready_attacker_count": after_ready,
		}
	if str(context.get("action_kind", "")) == "use_ability" and after_energy > before_energy:
		return {
			"should_replan": true,
			"reason": "lugia_primal_turbo_energy_distribution_resolved",
			"before_field_energy_count": before_energy,
			"after_field_energy_count": after_energy,
		}
	return {"should_replan": false}


func _deck_is_low_value_runtime_attack_action(_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null or player.active_pokemon.get_card_data() == null:
		return false
	var active_name := _slot_best_name(player.active_pokemon)
	if _name_contains(active_name, LUGIA_V) and not _name_contains(active_name, LUGIA_VSTAR):
		var lower_text := "%s %s" % [
			str(_action.get("attack_name", "")),
			JSON.stringify(_action.get("attack_rules", {})),
		]
		lower_text = lower_text.to_lower()
		if player.deck.size() <= 12 and (lower_text.contains("draw") or int(_action.get("attack_index", -1)) == 0):
			return true
	if _name_matches_any(active_name, [LUMINEON_V, FEZANDIPITI_EX, MINCCINO]):
		return _has_visible_lugia_setup(game_state, player_index)
	if _name_contains(active_name, ARCHEOPS) and (_count_field_name(player, LUGIA_VSTAR) > 0 or _has_ready_lugia_attacker(player)):
		return true
	return false


func _deck_is_high_pressure_attack_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if not _slot_name_matches_any(player.active_pokemon, [LUGIA_VSTAR, CINCCINO, IRON_HANDS_EX, BLOODMOON_URSALUNA_EX]):
		return false
	var projected_damage := int(action.get("projected_damage", predict_attacker_damage(player.active_pokemon).get("damage", 0)))
	var opponent: PlayerState = game_state.players[1 - player_index]
	if opponent != null and opponent.active_pokemon != null and projected_damage >= opponent.active_pokemon.get_remaining_hp():
		return true
	return projected_damage >= 160


func _deck_estimate_multiplier_attack_damage(_action: Dictionary, game_state: GameState, player_index: int, _base_damage: int, lower_text: String) -> int:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0
	var active: PokemonSlot = game_state.players[player_index].active_pokemon
	if active == null or not _slot_name_matches_any(active, [CINCCINO]):
		return 0
	if not lower_text.contains("special") and not lower_text.contains("70x"):
		return 0
	var special_count := 0
	for energy: CardInstance in active.attached_energy:
		if energy != null and energy.card_data != null and str(energy.card_data.card_type) == "Special Energy":
			special_count += 1
	return special_count * 70


func _deck_hand_has_recovery_or_pivot_piece(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		var name := _best_card_name(card.card_data)
		if _name_matches_any(name, [
			LUGIA_V,
			LUGIA_VSTAR,
			ARCHEOPS,
			CINCCINO,
			"Ultra Ball",
			"Capturing Aroma",
			"Great Ball",
			"Jacq",
			"Boss",
			"Counter Catcher",
			"Switch",
			"Jet Energy",
		]):
			return true
	return false


func _is_lugia_low_deck_unplanned_draw_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.deck.size() <= 0 or player.deck.size() > 12:
		return false
	var engine_or_attack_ready := _count_field_name(player, ARCHEOPS) > 0 or _has_ready_lugia_attacker(player) or player.deck.size() <= 6
	if not engine_or_attack_ready:
		return false
	var kind := str(action.get("kind", action.get("type", "")))
	if kind == "play_trainer":
		var card: CardInstance = action.get("card", null)
		if card == null or card.card_data == null:
			return false
		var card_name := "%s %s" % [str(card.card_data.name_en), str(card.card_data.name)]
		return _name_contains(card_name, "Professor") \
			or _name_contains(card_name, "Carmine") \
			or _name_contains(card_name, "Iono")
	if kind == "use_ability":
		var source_slot: PokemonSlot = action.get("source_slot", null)
		if source_slot == null or source_slot.get_card_data() == null:
			return false
		var source_name := _slot_best_name(source_slot)
		return _name_matches_any(source_name, [FEZANDIPITI_EX, LUMINEON_V]) and player.deck.size() <= 8
	if kind in ["attack", "granted_attack"]:
		return _deck_is_low_value_runtime_attack_action(action, game_state, player_index)
	return false


func _deck_augment_action_id_payload(payload: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	var result := payload.duplicate(true)
	var facts: Dictionary = result.get("turn_tactical_facts", {}) if result.get("turn_tactical_facts", {}) is Dictionary else {}
	facts = facts.duplicate(true)
	var shell := _lugia_shell_fact(result, game_state, player_index)
	if not shell.is_empty():
		facts["lugia_shell"] = shell
	var continuity := build_continuity_contract(game_state, player_index, {})
	if not continuity.is_empty():
		facts["lugia_continuity_contract"] = _compact_lugia_continuity_contract_for_llm(continuity)
	result["turn_tactical_facts"] = facts
	var routes: Array = result.get("candidate_routes", []) if result.get("candidate_routes", []) is Array else []
	var updated_routes := routes.duplicate(true)
	var ready_handoff := _lugia_ready_backup_handoff_candidate_route(result, game_state, player_index)
	if not ready_handoff.is_empty():
		updated_routes.push_front(ready_handoff)
	var backup_search := _lugia_backup_basic_search_candidate_route(result, game_state, player_index, shell)
	if not backup_search.is_empty():
		updated_routes.push_front(backup_search)
	var primal_turbo := _lugia_primal_turbo_candidate_route(result, game_state, player_index)
	if not primal_turbo.is_empty():
		updated_routes.push_front(primal_turbo)
	var continuity_route := _lugia_continuity_candidate_route(result, continuity)
	if not continuity_route.is_empty():
		updated_routes.push_front(continuity_route)
	var summoning_route := _lugia_summoning_star_candidate_route(result, shell)
	if not summoning_route.is_empty():
		updated_routes.push_front(summoning_route)
	result["candidate_routes"] = _dedupe_lugia_candidate_routes(updated_routes)
	return result


func _protect_lugia_interaction_picks(planned: Array, items: Array, step: Dictionary, context: Dictionary) -> Array:
	if not _is_discard_step(step):
		return planned
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var filtered: Array = []
	for item: Variant in planned:
		if item is CardInstance and (item as CardInstance).card_data != null:
			if _is_lugia_protected_discard_card((item as CardInstance).card_data, game_state, player_index):
				continue
		filtered.append(item)
	if filtered.size() == planned.size():
		return planned
	var required := _step_pick_count(step, planned.size())
	if filtered.size() >= required:
		return filtered.slice(0, required)
	var fallback := _lugia_interaction_fallback_for_step(items, step, context)
	return _merge_lugia_interaction_picks(filtered, fallback, required)


func _lugia_interaction_fallback_for_step(items: Array, step: Dictionary, context: Dictionary) -> Array:
	if items.is_empty():
		return []
	if _is_discard_step(step):
		return _rank_lugia_interaction_items(items, step, context, _step_pick_count(step, 1), "discard")
	if _is_lugia_search_step(step):
		return _pick_lugia_search_items_by_prefer(items, step, context, _step_pick_count(step, 1))
	if _is_lugia_primal_turbo_energy_source_step(step, context):
		return _rank_lugia_interaction_items(items, step, context, _step_pick_count(step, 2), "primal_turbo_energy")
	return []


func _lugia_interaction_target_score_override(item: Variant, step: Dictionary, context: Dictionary) -> float:
	if _is_assignment_target_step(step) and item is PokemonSlot and _slot_is_bad_lugia_energy_assignment_target(item as PokemonSlot):
		return -1000.0
	if _is_assignment_target_step(step) and item is PokemonSlot:
		return _lugia_assignment_target_score(item as PokemonSlot, context)
	if _is_lugia_primal_turbo_energy_source_step(step, context) and item is CardInstance:
		return _lugia_primal_turbo_energy_source_score(item as CardInstance, context)
	if _is_lugia_search_step(step) and item is CardInstance:
		return float(_lugia_search_candidate_score(item as CardInstance, context))
	if _is_discard_step(step) and item is CardInstance:
		var card: CardInstance = item as CardInstance
		if card.card_data != null and _is_lugia_protected_discard_card(card.card_data, context.get("game_state", null), int(context.get("player_index", -1))):
			return -1000.0
		return float(_lugia_discard_candidate_score(card, context))
	return 0.0


func _is_discard_step(step: Dictionary) -> bool:
	var step_id := str(step.get("id", ""))
	return step_id in ["discard_card", "discard_cards", "discard_energy", "discard_basic_energy"] or step_id.contains("discard")


func _is_lugia_search_step(step: Dictionary) -> bool:
	var step_id := str(step.get("id", ""))
	return step_id in ["search_pokemon", "search_cards", "search_targets", "search_item"] or step_id.contains("search")


func _is_assignment_target_step(step: Dictionary) -> bool:
	var step_id := str(step.get("id", ""))
	return step_id in ["assignment_target", "energy_assignment", "energy_assignments"] or step_id.contains("assignment")


func _is_lugia_protected_discard_card(card_data: CardData, game_state: GameState, player_index: int) -> bool:
	if card_data == null:
		return false
	var name := _best_card_name(card_data)
	if not _name_matches_any(name, [LUGIA_V, LUGIA_VSTAR, MINCCINO, CINCCINO]):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return true
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return true
	var lugia_field := _count_field_name(player, LUGIA_V) + _count_field_name(player, LUGIA_VSTAR)
	var vstar_field := _count_exact_name_on_field(player, LUGIA_VSTAR)
	if _name_contains(name, LUGIA_V) and lugia_field == 0:
		return true
	if _name_contains(name, LUGIA_VSTAR) and _count_field_name(player, LUGIA_V) > 0 and vstar_field == 0:
		return true
	if _name_contains(name, MINCCINO) and _count_field_name(player, MINCCINO) + _count_field_name(player, CINCCINO) == 0:
		return true
	if _name_contains(name, CINCCINO) and _count_field_name(player, MINCCINO) > 0 and _count_field_name(player, CINCCINO) == 0:
		return true
	return false


func _slot_is_bad_lugia_energy_assignment_target(slot: PokemonSlot) -> bool:
	return _slot_is_support_only(slot) or _slot_name_matches_any(slot, [ARCHEOPS, MINCCINO])


func _count_ready_lugia_attackers(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	if _slot_is_ready_lugia_attacker(player.active_pokemon):
		count += 1
	for slot: PokemonSlot in player.bench:
		if _slot_is_ready_lugia_attacker(slot):
			count += 1
	return count


func _count_ready_lugia_backup_attackers(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in player.bench:
		if _slot_is_ready_lugia_attacker(slot):
			count += 1
	return count


func _slot_is_ready_lugia_attacker(slot: PokemonSlot) -> bool:
	if slot == null or not _slot_name_matches_any(slot, [LUGIA_VSTAR, CINCCINO, IRON_HANDS_EX, BLOODMOON_URSALUNA_EX, WELLSPRING_OGERPON_EX, CORNERSTONE_OGERPON_EX]):
		return false
	return bool(predict_attacker_damage(slot).get("can_attack", false))


func _count_field_energy(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	if player.active_pokemon != null:
		count += player.active_pokemon.attached_energy.size()
	for slot: PokemonSlot in player.bench:
		if slot != null:
			count += slot.attached_energy.size()
	return count


func _has_ready_lugia_attacker(player: PlayerState) -> bool:
	return _count_ready_lugia_attackers(player) > 0


func _step_pick_count(step: Dictionary, fallback: int) -> int:
	var candidates: Array[int] = [fallback]
	for key: String in ["max_select", "count", "required_count", "min_select", "min_count"]:
		if step.has(key):
			candidates.append(int(step.get(key, 0)))
	var result := 1
	for value: int in candidates:
		result = maxi(result, value)
	return result


func _merge_lugia_interaction_picks(primary: Array, fallback: Array, limit: int) -> Array:
	var result: Array = []
	for item: Variant in primary:
		if result.size() >= limit:
			break
		if not result.has(item):
			result.append(item)
	for item: Variant in fallback:
		if result.size() >= limit:
			break
		if not result.has(item):
			result.append(item)
	return result


func _rank_lugia_interaction_items(
	items: Array,
	step: Dictionary,
	context: Dictionary,
	limit: int,
	mode: String
) -> Array:
	var scored: Array[Dictionary] = []
	for item: Variant in items:
		var score := -999999.0
		if mode == "discard" and item is CardInstance:
			score = float(_lugia_discard_candidate_score(item as CardInstance, context))
		elif mode == "primal_turbo_energy" and item is CardInstance:
			score = _lugia_primal_turbo_energy_source_score(item as CardInstance, context)
		elif mode == "search" and item is CardInstance:
			score = float(_lugia_search_candidate_score(item as CardInstance, context))
		if score <= -999998.0:
			continue
		scored.append({"item": item, "score": score})
	scored.sort_custom(Callable(self, "_sort_lugia_scored_item_desc"))
	var picked: Array = []
	for entry: Dictionary in scored:
		if picked.size() >= limit:
			break
		picked.append(entry.get("item"))
	return picked


func _sort_lugia_scored_item_desc(a: Dictionary, b: Dictionary) -> bool:
	var left := float(a.get("score", 0.0))
	var right := float(b.get("score", 0.0))
	if left != right:
		return left > right
	var left_card: CardInstance = a.get("item", null)
	var right_card: CardInstance = b.get("item", null)
	return _card_instance_name(left_card) < _card_instance_name(right_card)


func _lugia_discard_candidate_score(card: CardInstance, context: Dictionary) -> int:
	if card == null or card.card_data == null:
		return -999999
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if _is_lugia_protected_discard_card(card.card_data, game_state, player_index):
		return -999999
	var score := get_discard_priority_contextual(card, game_state, player_index)
	var name := _best_card_name(card.card_data)
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		var player: PlayerState = game_state.players[player_index]
		if _name_contains(name, ARCHEOPS) and _needs_lugia_archeops_discard(player):
			score += 320
		elif str(card.card_data.card_type) == "Special Energy" and _count_total_visible_special_energy(player) <= 4:
			score -= 110
	if _name_matches_any(name, [LUMINEON_V, FEZANDIPITI_EX]) and game_state != null:
		score += 45
	return score


func _repair_lugia_search_interaction_picks(planned: Array, items: Array, step: Dictionary, context: Dictionary) -> Array:
	if planned.is_empty() or not _is_lugia_search_step(step):
		return planned
	var fallback := _lugia_interaction_fallback_for_step(items, step, context)
	if fallback.is_empty():
		return planned
	var planned_score := _lugia_pick_score(planned, context, "search")
	var fallback_score := _lugia_pick_score(fallback, context, "search")
	if fallback_score > planned_score + 120.0:
		return fallback
	return planned


func _lugia_pick_score(items: Array, context: Dictionary, mode: String) -> float:
	var score := 0.0
	for item: Variant in items:
		if mode == "search" and item is CardInstance:
			score += float(_lugia_search_candidate_score(item as CardInstance, context))
		elif mode == "discard" and item is CardInstance:
			score += float(_lugia_discard_candidate_score(item as CardInstance, context))
	return score


func _lugia_search_candidate_score(card: CardInstance, context: Dictionary) -> int:
	if card == null or card.card_data == null:
		return -999999
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var name := _best_card_name(card.card_data)
	var score := get_search_priority(card)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return score
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return score
	var prefer := _lugia_search_prefer_names(player)
	var exact_index := _name_index_in_prefer(name, prefer)
	if exact_index >= 0:
		score += 1000 - exact_index * 80
	if _lugia_should_prioritize_backup_basic_search(player):
		if _is_exact_lugia_v_name(name):
			score += 760
		elif _is_high_value_lugia_basic_continuity_name(name):
			score += 420
		elif _name_contains(name, LUGIA_VSTAR) and _has_lugia_vstar_access(player):
			score -= 620
	if _lugia_needs_vstar_search(player) and _name_contains(name, LUGIA_VSTAR):
		score += 760
	if _lugia_needs_archeops_search(player) and _name_contains(name, ARCHEOPS):
		score += 720
	return score


func _pick_lugia_search_items_by_prefer(items: Array, _step: Dictionary, context: Dictionary, limit: int) -> Array:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var prefer: Array[String] = [LUGIA_VSTAR, ARCHEOPS, CINCCINO, MINCCINO, IRON_HANDS_EX, BLOODMOON_URSALUNA_EX]
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		var player: PlayerState = game_state.players[player_index]
		if player != null:
			prefer = _lugia_search_prefer_names(player)
	var picked: Array = []
	for preferred: String in prefer:
		for item: Variant in items:
			if picked.size() >= limit:
				return picked
			if picked.has(item) or not (item is CardInstance):
				continue
			var card: CardInstance = item as CardInstance
			if card.card_data == null:
				continue
			if not _search_card_matches_lugia_prefer(_best_card_name(card.card_data), preferred):
				continue
			picked.append(item)
	if picked.size() >= limit:
		return picked
	var ranked := _rank_lugia_interaction_items(items, _step, context, limit, "search")
	return _merge_lugia_interaction_picks(picked, ranked, limit)


func _search_card_matches_lugia_prefer(card_name: String, preferred: String) -> bool:
	if preferred in [
		LUGIA_V,
		LUGIA_VSTAR,
		ARCHEOPS,
		MINCCINO,
		CINCCINO,
		IRON_HANDS_EX,
		BLOODMOON_URSALUNA_EX,
		WELLSPRING_OGERPON_EX,
		CORNERSTONE_OGERPON_EX,
		LUMINEON_V,
		FEZANDIPITI_EX,
	]:
		return card_name.strip_edges().to_lower() == preferred.to_lower()
	return _name_contains(card_name, preferred)


func _lugia_primal_turbo_energy_source_score(card: CardInstance, _context: Dictionary) -> float:
	if card == null or card.card_data == null:
		return -999999.0
	if str(card.card_data.card_type) != "Special Energy":
		return -999999.0
	var name := _best_card_name(card.card_data)
	if _name_contains(name, "Double Turbo Energy"):
		return 620.0
	if _name_contains(name, "Gift Energy"):
		return 560.0
	if _name_contains(name, "Jet Energy"):
		return 530.0
	if _name_contains(name, "Legacy Energy"):
		return 510.0
	if _name_contains(name, "Mist Energy") or _name_contains(name, "V Guard Energy"):
		return 470.0
	return 420.0


func _lugia_assignment_target_score(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null:
		return 0.0
	var score := 0.0
	var slot_name := _slot_best_name(slot)
	var gap := _slot_attack_energy_gap(slot)
	var source_card: CardInstance = context.get("source_card", null)
	var source_name := _card_instance_name(source_card)
	if _name_matches_any(slot_name, [LUGIA_VSTAR]):
		score = 620.0 if gap > 0 else 360.0
	elif _name_matches_any(slot_name, [LUGIA_V]):
		score = 520.0 if gap > 0 else 260.0
	elif _name_matches_any(slot_name, [CINCCINO]):
		score = 590.0 if gap > 0 else 480.0
	elif _name_matches_any(slot_name, [IRON_HANDS_EX]):
		score = 540.0 if gap > 0 else 420.0
	elif _name_matches_any(slot_name, [BLOODMOON_URSALUNA_EX]):
		score = 500.0 if gap > 0 else 380.0
	elif _name_matches_any(slot_name, [WELLSPRING_OGERPON_EX, CORNERSTONE_OGERPON_EX]):
		score = 310.0 if gap > 0 else 210.0
	else:
		return 0.0
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		if slot == game_state.players[player_index].active_pokemon and gap > 0:
			score += 90.0
	if _name_contains(source_name, "Double Turbo Energy") and _name_matches_any(slot_name, [LUGIA_VSTAR, LUGIA_V, CINCCINO, BLOODMOON_URSALUNA_EX]):
		score += 90.0
	if _name_contains(source_name, "Legacy Energy") and _name_matches_any(slot_name, [IRON_HANDS_EX, BLOODMOON_URSALUNA_EX, LUGIA_VSTAR]):
		score += 80.0
	if _name_contains(source_name, "Gift Energy") and _name_matches_any(slot_name, [CINCCINO, LUGIA_VSTAR, LUGIA_V]):
		score += 60.0
	return score


func _is_lugia_primal_turbo_energy_source_step(step: Dictionary, context: Dictionary) -> bool:
	var step_id := str(step.get("id", ""))
	if not (step_id in ["search_cards", "search_energy", "energy_card", "selected_energy_card_id"] or step_id.contains("energy")):
		return false
	var source_slot: PokemonSlot = context.get("source_slot", null)
	if source_slot != null and _slot_name_matches_any(source_slot, [ARCHEOPS]):
		return true
	var source_card: CardInstance = context.get("source_card", null)
	if source_card != null and source_card.card_data != null and _name_contains(_best_card_name(source_card.card_data), ARCHEOPS):
		return true
	var source_text := "%s %s %s" % [
		str(context.get("source", "")),
		str(context.get("ability", "")),
		JSON.stringify(context.get("action", {})),
	]
	return _name_contains(source_text, ARCHEOPS) or _name_contains(source_text, "Primal Turbo")


func _needs_lugia_archeops_discard(player: PlayerState) -> bool:
	if player == null:
		return false
	if _count_field_name(player, ARCHEOPS) >= 2:
		return false
	return _count_discard_name(player, ARCHEOPS) < maxi(1, mini(2, 2 - _count_field_name(player, ARCHEOPS)))


func _count_total_visible_special_energy(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and str(card.card_data.card_type) == "Special Energy":
			count += 1
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and str(card.card_data.card_type) == "Special Energy":
			count += 1
	for slot: PokemonSlot in _all_lugia_slots(player):
		for energy: CardInstance in slot.attached_energy:
			if energy != null and energy.card_data != null and str(energy.card_data.card_type) == "Special Energy":
				count += 1
	return count


func _slot_attack_energy_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null or slot.get_card_data().attacks.is_empty():
		return 99
	var min_gap := 99
	for attack: Dictionary in slot.get_card_data().attacks:
		var cost := str(attack.get("cost", ""))
		min_gap = mini(min_gap, maxi(0, cost.length() - slot.attached_energy.size()))
	return min_gap


func _all_lugia_slots(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if player == null:
		return slots
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	return slots


func _card_instance_name(card: CardInstance) -> String:
	if card == null or card.card_data == null:
		return ""
	return _best_card_name(card.card_data)


func _lugia_shell_fact(payload: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return {}
	var archeops_discard := _count_discard_name(player, ARCHEOPS)
	var vstar_field := _count_field_name(player, LUGIA_VSTAR)
	var legal_actions := _payload_legal_actions(payload)
	var summoning_ref := _first_payload_ref(legal_actions, "use_ability", LUGIA_VSTAR)
	var primal_ref := _first_payload_ref(legal_actions, "use_ability", ARCHEOPS)
	return {
		"lugia_vstar_field_count": vstar_field,
		"archeops_discard_count": archeops_discard,
		"archeops_field_count": _count_field_name(player, ARCHEOPS),
		"lugia_v_field_count": _count_field_name(player, LUGIA_V),
		"lugia_v_hand_count": _count_exact_lugia_v_in_hand(player),
		"lugia_vstar_hand_count": _count_hand_name(player, LUGIA_VSTAR),
		"minccino_field_count": _count_field_name(player, MINCCINO),
		"cinccino_field_count": _count_field_name(player, CINCCINO),
		"ready_attacker_count": _count_ready_lugia_attackers(player),
		"ready_backup_attacker_count": _count_ready_lugia_backup_attackers(player),
		"deck_count": player.deck.size(),
		"summoning_star_ready": vstar_field > 0 and archeops_discard > 0 and _lugia_vstar_power_unused(game_state, player_index),
		"summoning_star_action_id": str(summoning_ref.get("id", summoning_ref.get("action_id", ""))),
		"primal_turbo_action_id": str(primal_ref.get("id", primal_ref.get("action_id", ""))),
		"backup_basic_search_preferred": _lugia_should_prioritize_backup_basic_search(player),
		"backup_basic_search_prefer": _lugia_search_prefer_names(player),
	}


func _compact_lugia_continuity_contract_for_llm(continuity: Dictionary) -> Dictionary:
	return continuity.duplicate(true)


func _lugia_ready_backup_handoff_candidate_route(payload: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null or _slot_is_ready_lugia_attacker(player.active_pokemon):
		return {}
	var bench_position := _best_ready_lugia_backup_position(player)
	if bench_position == "":
		return {}
	var pivot_ref := _best_lugia_ready_backup_pivot_ref(_payload_legal_actions(payload), bench_position)
	if pivot_ref.is_empty():
		return {}
	var pivot_action := _lugia_route_ref(pivot_ref, _lugia_handoff_selection_policy(bench_position))
	return {
		"id": "lugia_ready_backup_handoff",
		"route_action_id": "route:lugia_ready_backup_handoff",
		"type": "candidate_route",
		"priority": 990,
		"goal": "ready_backup_handoff_attack",
		"description": "Pivot from a non-attacking active into the charged Lugia/Cinccino side attacker before any extra draw or padding.",
		"actions": [pivot_action, {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}],
		"future_goals": [_lugia_attack_future_goal("future:lugia_attack_after_handoff:%s" % bench_position, bench_position)],
		"contract": "Select this route when a benched Lugia-family attacker is already ready and the active cannot pressure prizes.",
	}


func _lugia_backup_basic_search_candidate_route(payload: Dictionary, game_state: GameState, player_index: int, shell: Dictionary) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	if player == null or not bool(shell.get("backup_basic_search_preferred", false)):
		return {}
	var legal_actions := _payload_legal_actions(payload)
	var search_ref := _first_payload_ref(legal_actions, "play_trainer", "Ultra Ball")
	if search_ref.is_empty():
		search_ref = _first_payload_ref(legal_actions, "play_trainer", "Capturing Aroma")
	if search_ref.is_empty():
		search_ref = _first_payload_ref(legal_actions, "play_trainer", "Great Ball")
	if search_ref.is_empty():
		return {}
	var route_actions: Array[Dictionary] = []
	var seen_ids := {}
	_append_payload_ref_to_lugia_route(route_actions, seen_ids, search_ref, _lugia_search_selection_policy(game_state, player_index))
	if route_actions.is_empty():
		return {}
	route_actions.append({"id": "end_turn", "action_id": "end_turn", "type": "end_turn"})
	return {
		"id": "lugia_backup_basic_search",
		"route_action_id": "route:lugia_backup_basic_search",
		"type": "candidate_route",
		"priority": 991,
		"goal": "core_attacker_setup",
		"description": "When Lugia VSTAR is already in hand but only one Lugia shell is on board, use Ultra Ball/search to find backup Lugia V or a high-value Basic attacker instead of a duplicate VSTAR.",
		"actions": route_actions,
		"future_goals": [{
			"id": "goal:lugia_backup_basic_survives_miraidon_counterko",
			"type": "goal",
			"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
			"reason": "Fixed-opening Miraidon can KO active Lugia V before T2 evolution; Lugia needs a backup Basic while preserving double Archeops.",
		}],
		"contract": "Select this route when lugia_shell.backup_basic_search_preferred is true.",
	}


func _lugia_primal_turbo_candidate_route(payload: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	var legal_actions := _payload_legal_actions(payload)
	var primal_ref := _first_payload_ref(legal_actions, "use_ability", ARCHEOPS)
	if primal_ref.is_empty():
		return {}
	var route_actions: Array[Dictionary] = []
	var seen_ids := {}
	_append_payload_ref_to_lugia_route(route_actions, seen_ids, primal_ref, _lugia_primal_turbo_selection_policy(game_state, player_index))
	if route_actions.is_empty():
		return {}
	route_actions.append(_lugia_terminal_ref(legal_actions))
	var priority := 984
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		var player: PlayerState = game_state.players[player_index]
		if player != null and player.active_pokemon != null and not _slot_is_ready_lugia_attacker(player.active_pokemon):
			priority = 989
	return {
		"id": "lugia_primal_turbo_to_attacker",
		"route_action_id": "route:lugia_primal_turbo_to_attacker",
		"type": "candidate_route",
		"priority": priority,
		"goal": "setup_to_primary_attack",
		"description": "Use Archeops Primal Turbo to finish the closest prize-pressure attacker, prioritizing active Lugia VSTAR before backup attackers and never padding Archeops.",
		"actions": route_actions,
		"future_goals": [_lugia_attack_future_goal("future:lugia_attack_after_primal_turbo", "active")],
		"contract": "Select this route when Archeops is legal and an attacker needs Special Energy before attack/end.",
	}


func _lugia_continuity_candidate_route(payload: Dictionary, continuity: Dictionary) -> Dictionary:
	if not bool(continuity.get("enabled", false)):
		return {}
	if bool(continuity.get("terminal_attack_locked", false)):
		return {}
	var legal_actions := _payload_legal_actions(payload)
	if legal_actions.is_empty():
		return {}
	var route_actions: Array[Dictionary] = []
	var seen_ids := {}
	var bonuses: Array = continuity.get("action_bonuses", []) if continuity.get("action_bonuses", []) is Array else []
	for raw_bonus: Variant in _sorted_lugia_continuity_bonuses(bonuses):
		if route_actions.size() >= 5:
			break
		if not (raw_bonus is Dictionary):
			continue
		var bonus: Dictionary = raw_bonus
		var ref := _best_payload_ref_for_lugia_bonus(legal_actions, bonus, route_actions)
		if ref.is_empty():
			continue
		_append_payload_ref_to_lugia_route(route_actions, seen_ids, ref, _lugia_default_selection_policy_for_ref(ref))
	if route_actions.is_empty():
		return {}
	route_actions.append(_lugia_terminal_ref(legal_actions))
	return {
		"id": "lugia_continuity_before_attack",
		"route_action_id": "route:lugia_continuity_before_attack",
		"type": "candidate_route",
		"priority": 982,
		"goal": "continuity_before_attack",
		"description": "Before a non-final attack, finish dual Archeops, evolve/seed Cinccino, or charge the next attacker so Miraidon cannot trade through a single threat.",
		"actions": route_actions,
		"future_goals": [{
			"id": "goal:lugia_second_attacker_chain",
			"type": "goal",
			"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
			"reason": "Lugia must keep a second attacker and Archeops chain online before low-value attacks or end_turn.",
		}],
		"contract": "Select this route when lugia_continuity_contract.enabled is true and no final-prize attack is locked.",
	}


func _lugia_summoning_star_candidate_route(payload: Dictionary, shell: Dictionary) -> Dictionary:
	if shell.is_empty() or not bool(shell.get("summoning_star_ready", false)):
		return {}
	var action_id := str(shell.get("summoning_star_action_id", "")).strip_edges()
	if action_id == "":
		return {}
	var legal_actions := _payload_legal_actions(payload)
	var summoning_ref := _payload_ref_by_id(legal_actions, action_id)
	if summoning_ref.is_empty():
		return {}
	var route_actions: Array[Dictionary] = []
	var seen_ids := {}
	_append_payload_ref_to_lugia_route(route_actions, seen_ids, summoning_ref, _lugia_summoning_star_selection_policy())
	if route_actions.is_empty():
		return {}
	route_actions.append({"id": "end_turn", "action_id": "end_turn", "type": "end_turn"})
	return {
		"id": "lugia_summoning_star",
		"route_action_id": "route:lugia_summoning_star",
		"type": "candidate_route",
		"priority": 996,
		"goal": "setup_to_primary_attack",
		"description": "Use Lugia VSTAR Summoning Star immediately while Archeops is in discard, then replan into Primal Turbo/attack after Archeops enters play.",
		"actions": route_actions,
		"future_goals": [{
			"id": "goal:dual_archeops_online",
			"type": "goal",
			"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
			"reason": "Strong fixed Lugia opening converts only if Summoning Star brings Archeops online before extra churn or retreat.",
		}],
		"contract": "Select this route whenever summoning_star_ready is true.",
	}


func _payload_legal_actions(payload: Dictionary) -> Array:
	var result: Array = []
	var raw_actions: Variant = payload.get("legal_actions", [])
	if not (raw_actions is Array):
		return result
	for raw: Variant in raw_actions:
		if raw is Dictionary:
			result.append(raw)
	return result


func _first_payload_ref(legal_actions: Array, action_type: String, query: String) -> Dictionary:
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if _payload_ref_is_future(ref):
			continue
		if str(ref.get("type", ref.get("kind", ""))) != action_type:
			continue
		if query != "" and not _ref_has_any_name(ref, [query]):
			continue
		return ref
	return {}


func _payload_ref_by_id(legal_actions: Array, action_id: String) -> Dictionary:
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if str(ref.get("id", ref.get("action_id", ""))) == action_id:
			return ref
	return {}


func _payload_ref_is_future(ref: Dictionary) -> bool:
	if bool(ref.get("future", false)):
		return true
	var action_id := str(ref.get("id", ref.get("action_id", "")))
	return action_id.begins_with("future:")


func _append_payload_ref_to_lugia_route(
	route_actions: Array[Dictionary],
	seen_ids: Dictionary,
	ref: Dictionary,
	selection_policy: Dictionary = {}
) -> void:
	if ref.is_empty() or _payload_ref_is_future(ref):
		return
	var action_id := str(ref.get("id", ref.get("action_id", ""))).strip_edges()
	if action_id == "" or bool(seen_ids.get(action_id, false)):
		return
	var route_ref := _lugia_route_ref(ref, selection_policy)
	if route_ref.is_empty():
		return
	route_actions.append(route_ref)
	seen_ids[action_id] = true


func _lugia_route_ref(ref: Dictionary, selection_policy: Dictionary = {}) -> Dictionary:
	var action_id := str(ref.get("id", ref.get("action_id", ""))).strip_edges()
	if action_id == "":
		return {}
	var result := {
		"id": action_id,
		"action_id": action_id,
		"type": str(ref.get("type", ref.get("kind", ""))),
		"capability": str(ref.get("capability", "")),
	}
	if not selection_policy.is_empty():
		result["selection_policy"] = selection_policy.duplicate(true)
	elif ref.has("selection_policy") and ref.get("selection_policy", {}) is Dictionary:
		result["selection_policy"] = (ref.get("selection_policy", {}) as Dictionary).duplicate(true)
	return result


func _lugia_terminal_ref(legal_actions: Array) -> Dictionary:
	var best_attack: Dictionary = {}
	var best_score := -999999
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if _payload_ref_is_future(ref):
			continue
		var kind := str(ref.get("type", ref.get("kind", "")))
		if kind not in ["attack", "granted_attack"]:
			continue
		var quality: Dictionary = ref.get("attack_quality", {}) if ref.get("attack_quality", {}) is Dictionary else {}
		if str(quality.get("terminal_priority", "")) == "low":
			continue
		var score := 500 + int(ref.get("projected_damage", 0)) + int(ref.get("attack_index", 0)) * 20
		if str(quality.get("role", "")) == "primary_damage":
			score += 260
		if score > best_score:
			best_score = score
			best_attack = ref
	if not best_attack.is_empty():
		var attack_id := str(best_attack.get("id", best_attack.get("action_id", "")))
		return {"id": attack_id, "action_id": attack_id, "type": str(best_attack.get("type", "attack"))}
	return {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}


func _lugia_attack_future_goal(goal_id: String, position: String) -> Dictionary:
	return {
		"id": goal_id,
		"action_id": goal_id,
		"type": "attack",
		"future": true,
		"position": position,
		"source_pokemon": LUGIA_VSTAR,
		"attack_name": "Tempest Dive",
		"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
		"reason": "Visible Lugia engine action should convert into prize pressure rather than an empty end_turn.",
	}


func _lugia_summoning_star_selection_policy() -> Dictionary:
	return {
		"summon_targets": {"prefer": [ARCHEOPS, ARCHEOPS]},
		"search_pokemon": {"prefer": [ARCHEOPS, ARCHEOPS]},
		"search_targets": {"prefer": [ARCHEOPS, ARCHEOPS]},
	}


func _lugia_primal_turbo_selection_policy(game_state: GameState, player_index: int) -> Dictionary:
	var target_prefer := [LUGIA_VSTAR, CINCCINO, IRON_HANDS_EX, BLOODMOON_URSALUNA_EX, LUGIA_V, WELLSPRING_OGERPON_EX, CORNERSTONE_OGERPON_EX]
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		var player: PlayerState = game_state.players[player_index]
		if player != null:
			var best_target := _best_lugia_energy_target_name(player)
			if best_target != "" and target_prefer.has(best_target):
				target_prefer.erase(best_target)
				target_prefer.push_front(best_target)
	return {
		"search_energy": {"prefer": ["Double Turbo Energy", "Gift Energy", "Jet Energy", "Legacy Energy", "Mist Energy", "V Guard Energy"]},
		"search_cards": {"prefer": ["Double Turbo Energy", "Gift Energy", "Jet Energy", "Legacy Energy", "Mist Energy", "V Guard Energy"]},
		"energy_assignments": {
			"target_prefer": target_prefer,
			"avoid": [ARCHEOPS, MINCCINO, LUMINEON_V, FEZANDIPITI_EX],
		},
		"assignments": {
			"target_prefer": target_prefer,
			"avoid": [ARCHEOPS, MINCCINO, LUMINEON_V, FEZANDIPITI_EX],
		},
		"target": {"prefer": target_prefer},
	}


func _lugia_default_selection_policy_for_ref(ref: Dictionary, game_state: GameState = null, player_index: int = -1) -> Dictionary:
	var kind := str(ref.get("type", ref.get("kind", "")))
	var text := _lugia_ref_text(ref)
	if kind == "use_ability" and _name_contains(text, LUGIA_VSTAR):
		return _lugia_summoning_star_selection_policy()
	if kind == "use_ability" and _name_contains(text, ARCHEOPS):
		return _lugia_primal_turbo_selection_policy(null, -1)
	if kind == "play_trainer" and _name_matches_any(text, ["Ultra Ball", "Capturing Aroma", "Great Ball", "Jacq"]):
		return _lugia_search_selection_policy(game_state, player_index)
	return {}


func _lugia_search_selection_policy(game_state: GameState = null, player_index: int = -1) -> Dictionary:
	var search_prefer := [LUGIA_VSTAR, ARCHEOPS, CINCCINO, MINCCINO, IRON_HANDS_EX, BLOODMOON_URSALUNA_EX]
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		var player: PlayerState = game_state.players[player_index]
		if player != null:
			search_prefer = _lugia_search_prefer_names(player)
	return {
		"discard": {"prefer": [ARCHEOPS, ARCHEOPS, LUMINEON_V, FEZANDIPITI_EX], "avoid": [LUGIA_V, LUGIA_VSTAR, MINCCINO, CINCCINO]},
		"discard_cards": {"prefer": [ARCHEOPS, ARCHEOPS, LUMINEON_V, FEZANDIPITI_EX], "avoid": [LUGIA_V, LUGIA_VSTAR, MINCCINO, CINCCINO]},
		"search": {"prefer": search_prefer},
		"search_pokemon": {"prefer": search_prefer},
		"search_targets": {"prefer": search_prefer},
	}


func _lugia_search_prefer_names(player: PlayerState) -> Array[String]:
	var prefer: Array[String] = []
	if player == null:
		return [LUGIA_VSTAR, ARCHEOPS, CINCCINO, MINCCINO, IRON_HANDS_EX, BLOODMOON_URSALUNA_EX]
	if _lugia_needs_archeops_search(player):
		prefer.append(ARCHEOPS)
	if _lugia_needs_vstar_search(player):
		prefer.append(LUGIA_VSTAR)
	if _lugia_should_prioritize_backup_basic_search(player):
		prefer.append(LUGIA_V)
		if _count_field_name(player, MINCCINO) + _count_field_name(player, CINCCINO) + _count_hand_name(player, MINCCINO) + _count_hand_name(player, CINCCINO) == 0:
			prefer.append(MINCCINO)
		prefer.append(IRON_HANDS_EX)
		prefer.append(BLOODMOON_URSALUNA_EX)
		prefer.append(WELLSPRING_OGERPON_EX)
		prefer.append(CORNERSTONE_OGERPON_EX)
	if _count_field_name(player, MINCCINO) > 0 and _count_field_name(player, CINCCINO) == 0:
		prefer.append(CINCCINO)
	for name: String in [LUGIA_VSTAR, ARCHEOPS, LUGIA_V, MINCCINO, CINCCINO, IRON_HANDS_EX, BLOODMOON_URSALUNA_EX]:
		prefer.append(name)
	return _dedupe_string_array(prefer)


func _lugia_should_prioritize_backup_basic_search(player: PlayerState) -> bool:
	if player == null or player.is_bench_full():
		return false
	if not _has_lugia_vstar_access(player):
		return false
	var lugia_field := _count_exact_lugia_v_on_field(player) + _count_exact_name_on_field(player, LUGIA_VSTAR)
	if lugia_field <= 1 and _count_exact_lugia_v_in_hand(player) == 0:
		return true
	return _lugia_high_value_basic_continuity_count(player) == 0


func _has_lugia_vstar_access(player: PlayerState) -> bool:
	if player == null:
		return false
	return _count_exact_name_on_field(player, LUGIA_VSTAR) > 0 or _count_exact_name_in_hand(player, LUGIA_VSTAR) > 0


func _lugia_needs_vstar_search(player: PlayerState) -> bool:
	if player == null:
		return false
	return _count_exact_lugia_v_on_field(player) > 0 and not _has_lugia_vstar_access(player)


func _lugia_needs_archeops_search(player: PlayerState) -> bool:
	if player == null or _count_field_name(player, ARCHEOPS) >= 2:
		return false
	return _count_discard_name(player, ARCHEOPS) + _count_hand_name(player, ARCHEOPS) < 2


func _lugia_high_value_basic_continuity_count(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in _all_lugia_slots(player):
		if _is_high_value_lugia_basic_continuity_name(_slot_best_name(slot)):
			count += 1
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and _is_high_value_lugia_basic_continuity_name(_best_card_name(card.card_data)):
			count += 1
	return count


func _is_high_value_lugia_basic_continuity_name(name: String) -> bool:
	return _is_exact_lugia_v_name(name) or _name_matches_any(name, [
		MINCCINO,
		IRON_HANDS_EX,
		BLOODMOON_URSALUNA_EX,
		WELLSPRING_OGERPON_EX,
		CORNERSTONE_OGERPON_EX,
	])


func _is_exact_lugia_v_name(name: String) -> bool:
	return name.strip_edges().to_lower() == LUGIA_V.to_lower()


func _name_index_in_prefer(name: String, prefer: Array[String]) -> int:
	for index: int in prefer.size():
		var preferred := prefer[index]
		if preferred == "":
			continue
		if _search_card_matches_lugia_prefer(name, preferred):
			return index
	return -1


func _dedupe_string_array(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value: String in values:
		if value == "" or result.has(value):
			continue
		result.append(value)
	return result


func _best_lugia_energy_target_name(player: PlayerState) -> String:
	if player == null:
		return ""
	var best_name := ""
	var best_score := -999999.0
	for slot: PokemonSlot in _all_lugia_slots(player):
		if _slot_is_bad_lugia_energy_assignment_target(slot):
			continue
		var score := _lugia_assignment_target_score(slot, {"game_state": null, "player_index": -1})
		var gap := _slot_attack_energy_gap(slot)
		if gap <= 0:
			score -= 80.0
		if slot == player.active_pokemon and gap > 0:
			score += 120.0
		if score > best_score:
			best_score = score
			best_name = _slot_best_name(slot)
	return best_name


func _sorted_lugia_continuity_bonuses(bonuses: Array) -> Array:
	var result := bonuses.duplicate(true)
	result.sort_custom(Callable(self, "_sort_lugia_continuity_bonus_desc"))
	return result


func _sort_lugia_continuity_bonus_desc(a: Variant, b: Variant) -> bool:
	var left: Dictionary = a if a is Dictionary else {}
	var right: Dictionary = b if b is Dictionary else {}
	var left_score := float(left.get("bonus", 0.0))
	var right_score := float(right.get("bonus", 0.0))
	if left_score != right_score:
		return left_score > right_score
	return str(left.get("reason", "")) < str(right.get("reason", ""))


func _best_payload_ref_for_lugia_bonus(
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
		if not _payload_ref_matches_lugia_bonus(ref, bonus):
			continue
		if _lugia_ref_conflicts_with_route(ref, route_actions):
			continue
		scored.append({"score": _lugia_continuity_ref_score(ref, bonus), "ref": ref})
	scored.sort_custom(Callable(self, "_sort_lugia_scored_ref_desc"))
	if scored.is_empty():
		return {}
	return scored[0].get("ref", {}) if scored[0].get("ref", {}) is Dictionary else {}


func _sort_lugia_scored_ref_desc(a: Dictionary, b: Dictionary) -> bool:
	var left := float(a.get("score", 0.0))
	var right := float(b.get("score", 0.0))
	if left != right:
		return left > right
	var left_ref: Dictionary = a.get("ref", {}) if a.get("ref", {}) is Dictionary else {}
	var right_ref: Dictionary = b.get("ref", {}) if b.get("ref", {}) is Dictionary else {}
	return str(left_ref.get("id", "")) < str(right_ref.get("id", ""))


func _payload_ref_matches_lugia_bonus(ref: Dictionary, bonus: Dictionary) -> bool:
	var kind := str(bonus.get("kind", ""))
	if kind != "" and str(ref.get("type", ref.get("kind", ""))) != kind:
		return false
	var ref_text := _lugia_ref_text(ref)
	var card_names := _string_array_from_variant(bonus.get("card_names", []))
	if not card_names.is_empty() and not _text_matches_any_lugia_name(ref_text, card_names):
		return false
	var target_names := _string_array_from_variant(bonus.get("target_names", []))
	if not target_names.is_empty() and not _text_matches_any_lugia_name(ref_text, target_names):
		return false
	var pokemon_names := _string_array_from_variant(bonus.get("pokemon_names", []))
	if not pokemon_names.is_empty() and not _text_matches_any_lugia_name(ref_text, pokemon_names):
		return false
	return true


func _lugia_continuity_ref_score(ref: Dictionary, bonus: Dictionary) -> float:
	var score := float(bonus.get("bonus", 0.0))
	var kind := str(ref.get("type", ref.get("kind", "")))
	var text := _lugia_ref_text(ref)
	if kind == "use_ability" and _name_contains(text, LUGIA_VSTAR):
		score += 180.0
	elif kind == "use_ability" and _name_contains(text, ARCHEOPS):
		score += 150.0
	elif kind == "evolve" and _name_contains(text, LUGIA_VSTAR):
		score += 170.0
	elif kind == "evolve" and _name_contains(text, CINCCINO):
		score += 120.0
	elif kind == "attach_energy" and _ref_is_special_energy(ref):
		if _name_matches_any(text, [LUGIA_VSTAR, CINCCINO, IRON_HANDS_EX, BLOODMOON_URSALUNA_EX]):
			score += 120.0
	elif kind == "play_trainer":
		if _name_contains(text, "Ultra Ball"):
			score += 130.0
		elif _name_contains(text, "Jacq"):
			score += 95.0
		elif _name_contains(text, "Capturing Aroma"):
			score += 80.0
	return score


func _lugia_ref_conflicts_with_route(ref: Dictionary, route_actions: Array[Dictionary]) -> bool:
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


func _lugia_ref_text(ref: Dictionary) -> String:
	var base := "%s %s %s %s %s %s" % [
		str(ref.get("id", ref.get("action_id", ""))),
		str(ref.get("card", "")),
		str(ref.get("pokemon", "")),
		str(ref.get("target", "")),
		str(ref.get("ability", "")),
		str(ref.get("summary", "")),
	]
	return base + " " + JSON.stringify(ref.get("card_rules", {})) + " " + JSON.stringify(ref.get("ability_rules", {}))


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


func _text_matches_any_lugia_name(text: String, names: Array[String]) -> bool:
	for name: String in names:
		if name != "" and _name_contains(text, name):
			return true
	return false


func _best_ready_lugia_backup_position(player: PlayerState) -> String:
	if player == null:
		return ""
	var best_position := ""
	var best_score := -999999.0
	for index: int in player.bench.size():
		var slot: PokemonSlot = player.bench[index]
		if not _slot_is_ready_lugia_attacker(slot):
			continue
		var score := float(predict_attacker_damage(slot).get("damage", 0))
		if _slot_name_matches_any(slot, [CINCCINO]):
			score += 120.0
		elif _slot_name_matches_any(slot, [IRON_HANDS_EX]):
			score += 90.0
		elif _slot_name_matches_any(slot, [BLOODMOON_URSALUNA_EX]):
			score += 70.0
		if score > best_score:
			best_score = score
			best_position = "bench_%d" % index
	return best_position


func _best_lugia_ready_backup_pivot_ref(legal_actions: Array, bench_position: String) -> Dictionary:
	var best_ref: Dictionary = {}
	var best_score := -999999
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if _payload_ref_is_future(ref):
			continue
		var score := _lugia_ready_backup_pivot_score(ref, bench_position)
		if score <= best_score:
			continue
		best_ref = ref
		best_score = score
	return best_ref


func _lugia_ready_backup_pivot_score(ref: Dictionary, bench_position: String) -> int:
	var action_id := str(ref.get("id", ref.get("action_id", "")))
	var kind := str(ref.get("type", ref.get("kind", "")))
	var text := _lugia_ref_text(ref)
	if kind == "retreat" and action_id.contains("retreat:%s" % bench_position):
		return 850
	if kind != "play_trainer":
		return -999999
	if _name_contains(text, "Prime Catcher"):
		return 1120
	if _name_contains(text, "Switch Cart"):
		return 1060
	if _name_contains(text, "Switch") and not _name_contains(text, "Switching Cups"):
		return 1000
	if _name_contains(text, "Escape Rope"):
		return 720
	return -999999


func _lugia_handoff_selection_policy(bench_position: String) -> Dictionary:
	return {
		"own_bench_target": bench_position,
		"switch_target": bench_position,
		"self_pivot_target": bench_position,
		"retreat_target": bench_position,
		"target_position": bench_position,
		"gust_target": {"prefer": ["lowest_hp_ex", "lowest_hp_v", "active"]},
		"opponent_bench_target": {"prefer": ["lowest_hp_ex", "lowest_hp_v", "lowest_hp"]},
	}


func _lugia_vstar_power_unused(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0:
		return false
	if player_index >= game_state.vstar_power_used.size():
		return true
	return not bool(game_state.vstar_power_used[player_index])


func _dedupe_lugia_candidate_routes(routes: Array) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for raw_route: Variant in routes:
		if not (raw_route is Dictionary):
			continue
		var route: Dictionary = raw_route
		var route_id := str(route.get("route_action_id", route.get("id", "")))
		if route_id != "" and bool(seen.get(route_id, false)):
			continue
		if route_id != "":
			seen[route_id] = true
		result.append(route)
	return result


func _rules_score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if _rules == null:
		return 0.0
	var turn_plan := get_turn_contract_context()
	if not turn_plan.is_empty() and _rules.has_method("score_action_absolute_with_plan"):
		return float(_rules.call("score_action_absolute_with_plan", action, game_state, player_index, turn_plan))
	return float(_rules.call("score_action_absolute", action, game_state, player_index)) if _rules.has_method("score_action_absolute") else 0.0


func _rules_score_interaction_target(item: Variant, step: Dictionary, context: Dictionary) -> float:
	if _rules == null or not _rules.has_method("score_interaction_target"):
		return 0.0
	var turn_plan := _context_turn_plan(context)
	if not turn_plan.is_empty() and _rules.has_method("_set_turn_contract_context"):
		_rules.call("_set_turn_contract_context", turn_plan)
		var score := float(_rules.call("score_interaction_target", item, step, context))
		if _rules.has_method("_clear_turn_contract_context"):
			_rules.call("_clear_turn_contract_context")
		return score
	return float(_rules.call("score_interaction_target", item, step, context))


func _rules_score_handoff_target(item: Variant, step: Dictionary, context: Dictionary) -> float:
	if _rules == null or not _rules.has_method("score_handoff_target"):
		return 0.0
	var turn_plan := _context_turn_plan(context)
	if not turn_plan.is_empty() and _rules.has_method("_set_turn_contract_context"):
		_rules.call("_set_turn_contract_context", turn_plan)
		var score := float(_rules.call("score_handoff_target", item, step, context))
		if _rules.has_method("_clear_turn_contract_context"):
			_rules.call("_clear_turn_contract_context")
		return score
	return float(_rules.call("score_handoff_target", item, step, context))


func _context_turn_plan(context: Dictionary) -> Dictionary:
	if context.get("turn_contract", {}) is Dictionary:
		return context.get("turn_contract", {})
	if context.get("turn_plan", {}) is Dictionary:
		return context.get("turn_plan", {})
	return get_turn_contract_context()


func _rules_heuristic_base(kind: String) -> float:
	if _rules != null and _rules.has_method("_estimate_heuristic_base"):
		return float(_rules.call("_estimate_heuristic_base", kind))
	return 0.0


func _append_lugia_setup_catalog(target: Array[Dictionary], seen_ids: Dictionary, has_attack: bool, no_deck_draw_lock: bool = false) -> void:
	_append_catalog_match(target, seen_ids, "play_basic_to_bench", LUGIA_V, "")
	_append_catalog_match(target, seen_ids, "play_basic_to_bench", MINCCINO, "")
	_append_catalog_match(target, seen_ids, "evolve", LUGIA_VSTAR, "")
	_append_catalog_match(target, seen_ids, "evolve", CINCCINO, "")
	_append_catalog_match(target, seen_ids, "play_trainer", "Ultra Ball", "")
	_append_catalog_match(target, seen_ids, "play_trainer", "Capturing Aroma", "")
	_append_catalog_match(target, seen_ids, "play_trainer", "Great Ball", "")
	if not no_deck_draw_lock:
		_append_catalog_match(target, seen_ids, "play_trainer", "Professor", "")
		_append_catalog_match(target, seen_ids, "play_trainer", "Carmine", "")
	_append_catalog_match(target, seen_ids, "play_trainer", "Jacq", "")
	_append_catalog_match(target, seen_ids, "use_ability", "", LUGIA_VSTAR)
	_append_catalog_match(target, seen_ids, "use_ability", "", ARCHEOPS)
	if not has_attack:
		_append_catalog_match(target, seen_ids, "attach_energy", "", LUGIA_VSTAR)
		_append_catalog_match(target, seen_ids, "attach_energy", "", CINCCINO)
		_append_catalog_match(target, seen_ids, "play_trainer", "Boss", "")
		_append_catalog_match(target, seen_ids, "play_trainer", "Counter Catcher", "")


func _has_visible_lugia_setup(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	if _count_field_name(player, LUGIA_VSTAR) > 0 and _count_field_name(player, ARCHEOPS) >= 1 and _has_ready_attacker(player):
		return false
	if _catalog_has_lugia_setup_action():
		return true
	for card: CardInstance in player.hand:
		if card != null and _is_lugia_setup_card(card.card_data):
			return true
	return false


func _catalog_has_lugia_setup_action() -> bool:
	for raw_key: Variant in _llm_action_catalog.keys():
		var ref: Dictionary = _llm_action_catalog.get(raw_key, {})
		if ref.is_empty() or _is_future_action_ref(ref):
			continue
		var action_type := str(ref.get("type", ref.get("kind", "")))
		if action_type in ["end_turn", "attack", "granted_attack", "route"]:
			continue
		if action_type in ["play_basic_to_bench", "evolve", "attach_energy", "attach_tool", "retreat"]:
			return true
		if action_type == "play_trainer" and _ref_has_any_name(ref, [
			"Ultra Ball",
			"Capturing Aroma",
			"Great Ball",
			"Professor",
			"Carmine",
			"Jacq",
			"Boss",
			"Counter Catcher",
			"Forest Seal Stone",
		]):
			return true
		if action_type == "use_ability" and _ref_has_any_name(ref, [LUGIA_VSTAR, ARCHEOPS, LUMINEON_V, FEZANDIPITI_EX]):
			return true
	return false


func _is_lugia_setup_card(card_data: CardData) -> bool:
	if card_data == null:
		return false
	var name := _best_card_name(card_data)
	if str(card_data.card_type) == "Special Energy":
		return true
	for query: String in [
		LUGIA_V,
		LUGIA_VSTAR,
		ARCHEOPS,
		MINCCINO,
		CINCCINO,
		LUMINEON_V,
		FEZANDIPITI_EX,
		IRON_HANDS_EX,
		BLOODMOON_URSALUNA_EX,
		WELLSPRING_OGERPON_EX,
		CORNERSTONE_OGERPON_EX,
		"Ultra Ball",
		"Capturing Aroma",
		"Great Ball",
		"Professor",
		"Carmine",
		"Jacq",
		"Boss",
		"Counter Catcher",
		"Forest Seal Stone",
		"Double Turbo Energy",
		"Gift Energy",
		"Jet Energy",
		"Mist Energy",
		"V Guard Energy",
		"Legacy Energy",
	]:
		if _name_contains(name, query):
			return true
	return false


func _is_lugia_runtime_setup_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _is_lugia_low_deck_unplanned_draw_action(action, game_state, player_index):
		return false
	var kind := str(action.get("kind", action.get("type", "")))
	if kind in ["play_basic_to_bench", "evolve", "attach_energy", "attach_tool", "use_ability", "retreat"]:
		return not _deck_should_block_exact_queue_match({}, action, game_state, player_index)
	if kind == "play_trainer":
		return _runtime_action_has_any_name(action, [
			"Ultra Ball",
			"Capturing Aroma",
			"Great Ball",
			"Professor",
			"Carmine",
			"Jacq",
			"Boss",
			"Counter Catcher",
		])
	return false


func _is_bad_lugia_energy_attach(action: Dictionary) -> bool:
	var target_slot: PokemonSlot = action.get("target_slot", null)
	var card: CardInstance = action.get("card", null)
	if target_slot == null or card == null or card.card_data == null:
		return false
	if _slot_is_bad_lugia_energy_assignment_target(target_slot):
		return str(card.card_data.card_type) == "Special Energy" or card.card_data.is_energy()
	return false


func _is_bad_lugia_retreat(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var active := game_state.players[player_index].active_pokemon
	if active == null:
		return false
	var bench_target: PokemonSlot = action.get("bench_target", null)
	if bench_target == null:
		return false
	if _slot_name_matches_any(active, [LUGIA_V, LUGIA_VSTAR]) \
			and (_slot_is_bad_lugia_energy_assignment_target(bench_target) or _slot_is_support_only(bench_target)) \
			and not _slot_is_ready_lugia_attacker(bench_target):
		return true
	if not _slot_name_matches_any(active, [LUGIA_VSTAR, CINCCINO, IRON_HANDS_EX, BLOODMOON_URSALUNA_EX]):
		return false
	return _slot_is_support_only(bench_target) or (_slot_name_matches_any(bench_target, [ARCHEOPS, MINCCINO]) and not _slot_is_ready_lugia_attacker(bench_target))


func _is_lugia_productive_end_turn_replacement_retreat(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _is_bad_lugia_retreat(action, game_state, player_index):
		return false
	var bench_target: PokemonSlot = action.get("bench_target", null)
	if bench_target == null:
		return false
	return _slot_is_ready_lugia_attacker(bench_target)


func _is_lugia_productive_end_turn_replacement_attack(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	var active_name := _slot_best_name(player.active_pokemon).strip_edges().to_lower()
	if active_name != LUGIA_V.to_lower():
		return false
	if _current_active_has_high_pressure_ready_attack(game_state, player_index):
		return false
	var attack_index := int(action.get("attack_index", -1))
	var attack_name := str(action.get("attack_name", "")).strip_edges()
	var attack_rules: Dictionary = action.get("attack_rules", {}) if action.get("attack_rules", {}) is Dictionary else {}
	var text := "%s %s %s" % [
		attack_name,
		str(attack_rules.get("name", "")),
		str(attack_rules.get("text", "")),
	]
	text = text.to_lower()
	if attack_index != 0 and not (_name_contains(text, "Read the Wind") or (text.contains("discard") and text.contains("draw"))):
		return false
	return player.deck.size() > 12


func _has_ready_attacker(player: PlayerState) -> bool:
	if player == null:
		return false
	if player.active_pokemon != null and bool(predict_attacker_damage(player.active_pokemon).get("can_attack", false)):
		return true
	for slot: PokemonSlot in player.bench:
		if slot != null and bool(predict_attacker_damage(slot).get("can_attack", false)):
			return true
	return false


func _ref_is_special_energy(ref: Dictionary) -> bool:
	if str(ref.get("card_type", "")) == "Special Energy":
		return true
	var rules: Variant = ref.get("card_rules", {})
	if rules is Dictionary and str((rules as Dictionary).get("card_type", "")) == "Special Energy":
		return true
	return _ref_has_any_name(ref, [
		"Double Turbo Energy",
		"Gift Energy",
		"Jet Energy",
		"Mist Energy",
		"V Guard Energy",
		"Legacy Energy",
	])


func _ref_has_any_name(ref: Dictionary, queries: Array[String]) -> bool:
	var combined := " ".join([
		str(ref.get("id", ref.get("action_id", ""))),
		str(ref.get("card", "")),
		str(ref.get("pokemon", "")),
		str(ref.get("ability", "")),
		str(ref.get("target", "")),
		str(ref.get("summary", "")),
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


func _runtime_action_has_any_name(action: Dictionary, queries: Array[String]) -> bool:
	var combined := " ".join([
		str(action.get("card", "")),
		str(action.get("pokemon", "")),
		str(action.get("summary", "")),
		str(action.get("id", action.get("action_id", ""))),
	])
	var card: Variant = action.get("card")
	if card is CardInstance and (card as CardInstance).card_data != null:
		combined += " %s %s" % [str((card as CardInstance).card_data.name), str((card as CardInstance).card_data.name_en)]
	for query: String in queries:
		if _name_contains(combined, query):
			return true
	return false


func _slot_is_support_only(slot: PokemonSlot) -> bool:
	return _slot_name_matches_any(slot, [LUMINEON_V, FEZANDIPITI_EX, "Radiant Greninja", "Squawkabilly ex"])


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


func _is_lugia_side_attacker_name(name: String) -> bool:
	return _name_matches_any(name, [
		IRON_HANDS_EX,
		BLOODMOON_URSALUNA_EX,
		WELLSPRING_OGERPON_EX,
		CORNERSTONE_OGERPON_EX,
	])


func _best_card_name(cd: CardData) -> String:
	if cd == null:
		return ""
	if str(cd.name_en) != "":
		return str(cd.name_en)
	return str(cd.name)


func _count_field_name(player: PlayerState, query: String) -> int:
	if player == null:
		return 0
	var count := 0
	if player.active_pokemon != null and _slot_name_matches_any(player.active_pokemon, [query]):
		count += 1
	for slot: PokemonSlot in player.bench:
		if _slot_name_matches_any(slot, [query]):
			count += 1
	return count


func _count_discard_name(player: PlayerState, query: String) -> int:
	if player == null:
		return 0
	var count := 0
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and _name_contains(_best_card_name(card.card_data), query):
			count += 1
	return count


func _count_hand_name(player: PlayerState, query: String) -> int:
	if player == null:
		return 0
	var count := 0
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and _name_contains(_best_card_name(card.card_data), query):
			count += 1
	return count


func _count_exact_lugia_v_in_hand(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and _is_exact_lugia_v_name(_best_card_name(card.card_data)):
			count += 1
	return count


func _count_exact_lugia_v_on_field(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in _all_lugia_slots(player):
		if _is_exact_lugia_v_name(_slot_best_name(slot)):
			count += 1
	return count


func _count_exact_name_on_field(player: PlayerState, target_name: String) -> int:
	if player == null:
		return 0
	var count := 0
	var target := target_name.strip_edges().to_lower()
	for slot: PokemonSlot in _all_lugia_slots(player):
		if _slot_best_name(slot).strip_edges().to_lower() == target:
			count += 1
	return count


func _count_exact_name_in_hand(player: PlayerState, target_name: String) -> int:
	if player == null:
		return 0
	var count := 0
	var target := target_name.strip_edges().to_lower()
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and _best_card_name(card.card_data).strip_edges().to_lower() == target:
			count += 1
	return count
