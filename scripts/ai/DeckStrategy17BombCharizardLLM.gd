extends "res://scripts/ai/DeckStrategyCharizardExLLM.gd"

const BombCharizardRulesScript = preload("res://scripts/ai/DeckStrategy17BombCharizard.gd")

const BOMB_CHARIZARD_LLM_ID := "v17_bomb_charizard_llm"


func _init() -> void:
	_rules = BombCharizardRulesScript.new()


func get_strategy_id() -> String:
	return BOMB_CHARIZARD_LLM_ID


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if _bomb_charizard_should_hard_block_runtime_action(action, game_state, player_index):
		return -100000.0
	return super.score_action_absolute(action, game_state, player_index)


func score_action(action: Dictionary, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if _bomb_charizard_should_hard_block_runtime_action(action, game_state, player_index):
		return -100000.0
	return super.score_action(action, context)


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if item is CardInstance and str(step.get("id", "")) == "search_tool":
		var card: CardInstance = item
		if card.card_data != null and _name_contains(_best_card_name(card.card_data), FOREST_SEAL_STONE):
			var game_state: GameState = context.get("game_state", null)
			var player_index := int(context.get("player_index", -1))
			if not _bomb_has_live_forest_seal_target(game_state, player_index):
				return -200.0
	return super.score_interaction_target(item, step, context)


func make_llm_runtime_snapshot(game_state: GameState, player_index: int) -> Dictionary:
	var snapshot := super.make_llm_runtime_snapshot(game_state, player_index)
	var bomb_fact := _bomb_charizard_self_ko_fact({}, game_state, player_index)
	if not bomb_fact.is_empty():
		snapshot["v17_bomb_self_ko_route_available"] = bool(bomb_fact.get("route_available", false))
		snapshot["v17_bomb_self_ko_damage"] = int(bomb_fact.get("damage", 0))
		snapshot["v17_bomb_self_ko_best_score"] = int(bomb_fact.get("best_target_score", 0))
	return snapshot


func get_llm_deck_strategy_prompt(game_state: GameState, player_index: int) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("Deck plan: V17 Bomb Charizard is the Charizard ex / Pidgeot ex strong shell with a Dusknoir prize-conversion package. Reuse the normal Charizard plan first: build Charmander plus Pidgey, convert through Rare Candy, then attack with Charizard ex while Pidgeot ex keeps the next turn online.")
	lines.append("Opening priority: the first setup target is Charmander plus Pidgey. Buddy-Buddy Poffin, Nest Ball, Ultra Ball, Arven, Rare Candy, Forest Seal Stone on Rotom V or Lumineon V, and Pidgeot ex search should all serve this shell before optional Duskull padding.")
	lines.append("Stage 2 policy: if Rare Candy can create Pidgeot ex or Charizard ex, finish the Stage 2 before shallow draw or end_turn. Prefer Pidgeot ex when it unlocks the exact missing search piece; prefer Charizard ex when it creates the first real attack.")
	lines.append("Fire policy: attach or accelerate Fire only to Charizard ex, a Charmander/Charmeleon backup lane, or late-game Radiant Charizard. Do not put Fire on Pidgeot ex, Pidgey, Duskull, Dusclops, Dusknoir, Rotom V, Lumineon V, Fezandipiti ex, Manaphy, or Cleffa unless the structured payload proves an immediate retreat or attack.")
	lines.append("Bomb policy: Dusknoir places 130 damage counters and gives up one Prize; Dusclops places 50. Use the self-KO ability only when it immediately takes a Prize, sets up a same-turn Charizard KO, wins the game, or prevents the prize race from collapsing. Do not self-KO just because the ability is legal.")
	lines.append("Bomb timing: if a self-KO route and a Charizard attack are both live, resolve the Dusknoir/Dusclops conversion before the attack so damage counters change the active/bench KO math. If the target pool changes after the ability, replan from the updated board.")
	lines.append("Prize policy: prefer an active KO, then a gust/catcher bench KO, then a Dusknoir/Dusclops conversion on a damaged two-prize Pokemon. Never hand the opponent their final Prize with self-KO unless the same sequence wins first.")
	lines.append("Support policy: Rotom V, Lumineon V, Fezandipiti ex, Manaphy, Cleffa, Pidgey, Pidgeot ex, Duskull, Dusclops, and Dusknoir are support or conversion pieces, not Fire targets. Bench them only when their ability or future evolution matters.")
	lines.append("Attack policy: Burning Darkness and Combustion Blast are the real terminal attacks. Attack after safe setup, search, Rare Candy, Fire assignment, tool, gust/catcher, and bomb conversion actions are complete.")
	lines.append("Execution boundary: exact action ids, card text, interaction schemas, HP, energy, hand, discard, and opponent board come from the structured payload. Do not invent ids, card effects, targets, or interaction fields.")
	var custom_text := get_deck_strategy_text().strip_edges()
	if custom_text != "" and not _bomb_charizard_text_looks_garbled(custom_text):
		lines.append("Player-authored notes follow. Treat them as preferences only when they agree with legal_actions, card_rules, candidate_routes, and turn_tactical_facts.")
		for line: String in _strategy_text_to_prompt_lines(custom_text, 8):
			lines.append(line)
	return lines


func get_llm_setup_role_hint(cd: CardData) -> String:
	if cd == null:
		return "support"
	var name := _best_card_name(cd)
	if _name_contains(name, "Dusknoir"):
		return "prize conversion support: 130-damage self-KO ability, use only for a concrete prize swing"
	if _name_contains(name, "Dusclops"):
		return "prize conversion support: 50-damage self-KO ability, use only when it converts a prize or same-turn KO"
	if _name_contains(name, "Duskull"):
		return "Dusknoir line seed; secondary until Charmander and Pidgey setup is stable"
	if _name_contains(name, "Cleffa"):
		return "fallback draw pivot; use only when the Charizard/Pidgeot route is otherwise stalled"
	return super.get_llm_setup_role_hint(cd)


func _deck_augment_action_id_payload(payload: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	var result: Dictionary = super._deck_augment_action_id_payload(payload, game_state, player_index)
	var facts: Dictionary = result.get("turn_tactical_facts", {}) if result.get("turn_tactical_facts", {}) is Dictionary else {}
	facts = facts.duplicate(true)
	var bomb_fact := _bomb_charizard_self_ko_fact(result, game_state, player_index)
	if not bomb_fact.is_empty():
		facts["bomb_charizard_self_ko_conversion"] = bomb_fact
	facts["resource_negative_actions"] = _bomb_charizard_radiant_resource_negative_actions(
		facts.get("resource_negative_actions", []),
		result.get("legal_actions", []),
		game_state,
		player_index
	)
	result["turn_tactical_facts"] = facts
	var bomb_route := _bomb_charizard_self_ko_candidate_route(result, bomb_fact)
	if not bomb_route.is_empty():
		var routes: Array = result.get("candidate_routes", []) if result.get("candidate_routes", []) is Array else []
		var updated_routes := routes.duplicate(true)
		updated_routes.push_front(bomb_route)
		result["candidate_routes"] = updated_routes
	return result


func _deck_should_block_exact_queue_match(queued_action: Dictionary, runtime_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if super._deck_should_block_exact_queue_match(queued_action, runtime_action, game_state, player_index):
		return true
	if _bomb_charizard_bad_forest_seal_attachment_reason(runtime_action, game_state, player_index) != "":
		return true
	if _bomb_charizard_should_block_early_radiant_resource_sink(runtime_action, game_state, player_index):
		return true
	return _bomb_charizard_should_block_dead_self_ko(runtime_action, game_state, player_index)


func _bomb_charizard_self_ko_fact(payload: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	if player == null or opponent == null:
		return {}
	var legal_actions: Array = payload.get("legal_actions", []) if payload.get("legal_actions", []) is Array else []
	var best := _best_bomb_self_ko_window(player, opponent, game_state, player_index, legal_actions)
	if best.is_empty():
		return {}
	var best_score := float(best.get("score", 0.0))
	return {
		"route_available": best_score >= 350.0,
		"ability_action_id": str(best.get("action_id", "")),
		"source": str(best.get("source", "")),
		"damage": int(best.get("damage", 0)),
		"best_target": str(best.get("target", "")),
		"best_target_position": str(best.get("target_position", "")),
		"best_target_remaining_hp": int(best.get("remaining_hp", 0)),
		"best_target_prizes": int(best.get("prizes", 0)),
		"best_target_score": int(round(best_score)),
		"direct_prize_available": bool(best.get("direct_prize", false)),
		"same_turn_attack_followup": bool(best.get("attack_followup", false)),
		"rule": "Use Dusknoir/Dusclops self-KO only for a real prize conversion or same-turn Charizard KO setup.",
	}


func _best_bomb_self_ko_window(
	player: PlayerState,
	opponent: PlayerState,
	game_state: GameState,
	player_index: int,
	legal_actions: Array
) -> Dictionary:
	var best: Dictionary = {}
	for source_slot: PokemonSlot in _bomb_all_slots(player):
		var source_name := _slot_best_name(source_slot)
		var damage := _bomb_self_ko_damage_for_name(source_name)
		if damage <= 0:
			continue
		var action_id := _bomb_self_ko_action_id_for_source(legal_actions, source_name)
		if not legal_actions.is_empty() and action_id == "":
			continue
		var context := {
			"game_state": game_state,
			"player_index": player_index,
			"source_slot": source_slot,
		}
		for target: PokemonSlot in _bomb_all_slots(opponent):
			var score := _bomb_score_self_ko_target(target, context)
			if best.is_empty() or score > float(best.get("score", 0.0)):
				var remaining_hp := target.get_remaining_hp() if target != null else 999
				best = {
					"score": score,
					"action_id": action_id,
					"source": source_name,
					"damage": damage,
					"target": _slot_best_name(target),
					"target_position": _bomb_slot_position(opponent, target),
					"remaining_hp": remaining_hp,
					"prizes": target.get_prize_count() if target != null else 0,
					"direct_prize": remaining_hp <= damage,
					"attack_followup": score >= 350.0 and remaining_hp > damage,
				}
	return best


func _bomb_charizard_self_ko_candidate_route(payload: Dictionary, bomb_fact: Dictionary) -> Dictionary:
	if bomb_fact.is_empty() or not bool(bomb_fact.get("route_available", false)):
		return {}
	var ability_id := str(bomb_fact.get("ability_action_id", "")).strip_edges()
	if ability_id == "":
		return {}
	var legal_actions: Array = payload.get("legal_actions", []) if payload.get("legal_actions", []) is Array else []
	var route_actions: Array[Dictionary] = []
	var seen_ids := {}
	_append_payload_ref_by_id(route_actions, seen_ids, legal_actions, ability_id, {})
	if route_actions.is_empty():
		return {}
	var terminal := _charizard_terminal_attack_ref(legal_actions)
	route_actions.append(terminal if not terminal.is_empty() else {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"})
	return {
		"id": "bomb_charizard_self_ko_conversion",
		"route_action_id": "route:bomb_charizard_self_ko_conversion",
		"type": "candidate_route",
		"priority": 989,
		"goal": "self_ko_prize_conversion_before_attack",
		"description": "Use Dusknoir/Dusclops self-KO only when the rules target picker sees a real prize conversion or same-turn attack setup.",
		"actions": route_actions,
		"future_goals": [{
			"id": "goal:bomb_charizard_damage_counter_prize_swing",
			"type": "goal",
			"reason": "The current board has a concrete self-KO damage-counter conversion target.",
		}],
		"contract": "Select this route only when bomb_charizard_self_ko_conversion.route_available is true; target choice is resolved by rules fallback from the actual self_ko_target pool.",
	}


func _bomb_charizard_radiant_resource_negative_actions(
	existing: Variant,
	legal_actions: Variant,
	game_state: GameState,
	player_index: int
) -> Array:
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
		var action_id := str(ref.get("id", ref.get("action_id", ""))).strip_edges()
		if action_id == "" or bool(seen_ids.get(action_id, false)):
			continue
		var reason := _bomb_charizard_early_radiant_resource_sink_reason(ref, game_state, player_index)
		if reason == "":
			reason = _bomb_charizard_bad_forest_seal_attachment_reason(ref, game_state, player_index)
		if reason == "":
			continue
		result.append({
			"id": action_id,
			"type": str(ref.get("type", ref.get("kind", ""))),
			"card": _bomb_action_card_text(ref),
			"target": _bomb_action_target_text(ref, game_state, player_index),
			"position": str(ref.get("position", ref.get("target_position", ""))),
			"why": reason,
		})
		seen_ids[action_id] = true
	return result


func _bomb_charizard_should_block_early_radiant_resource_sink(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	return _bomb_charizard_early_radiant_resource_sink_reason(action, game_state, player_index) != ""


func _bomb_charizard_should_hard_block_runtime_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _bomb_charizard_bad_forest_seal_attachment_reason(action, game_state, player_index) != "":
		return true
	if _bomb_charizard_should_block_early_radiant_resource_sink(action, game_state, player_index):
		return true
	if _bomb_charizard_should_block_dead_self_ko(action, game_state, player_index):
		return true
	return false


func _bomb_charizard_early_radiant_resource_sink_reason(action: Dictionary, game_state: GameState, player_index: int) -> String:
	var kind := str(action.get("kind", action.get("type", "")))
	if kind not in ["attach_energy", "attach_tool"]:
		return ""
	if not _name_contains(_bomb_action_target_text(action, game_state, player_index), RADIANT_CHARIZARD):
		return ""
	var card_text := _bomb_action_card_text(action)
	if kind == "attach_tool" and _name_contains(card_text, FOREST_SEAL_STONE):
		return "Forest Seal Stone belongs on Rotom V or Lumineon V, not Radiant Charizard."
	if kind == "attach_energy" and _name_contains(card_text, FIRE_ENERGY):
		if not _bomb_radiant_charizard_is_live_attacker(game_state, player_index):
			return "Do not spend early Fire Energy on Radiant Charizard while a Charizard ex lane is still the main attacker."
	return ""


func _bomb_charizard_bad_forest_seal_attachment_reason(action: Dictionary, game_state: GameState, player_index: int) -> String:
	var kind := str(action.get("kind", action.get("type", "")))
	if kind != "attach_tool":
		return ""
	if not _name_contains(_bomb_action_card_text(action), FOREST_SEAL_STONE):
		return ""
	if _name_matches_any(_bomb_action_target_text(action, game_state, player_index), [ROTOM_V, LUMINEON_V]):
		return ""
	return "Forest Seal Stone is only a Rotom V or Lumineon V tool target in this deck."


func _bomb_has_live_forest_seal_target(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	return _charizard_count_field_name(player, ROTOM_V) > 0 or _charizard_count_field_name(player, LUMINEON_V) > 0


func _bomb_radiant_charizard_is_live_attacker(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return true
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return true
	var opponent_index := 1 - player_index
	if opponent_index >= 0 and opponent_index < game_state.players.size():
		var opponent: PlayerState = game_state.players[opponent_index]
		if opponent != null:
			var opponent_prizes_taken: int = maxi(0, 6 - opponent.prizes.size())
			if opponent_prizes_taken >= 4:
				return true
	if _charizard_count_field_name(player, CHARMANDER) > 0:
		return false
	if _charizard_count_field_name(player, CHARMELEON) > 0:
		return false
	if _charizard_count_field_name(player, CHARIZARD_EX) > 0:
		return false
	return true


func _bomb_action_card_text(action: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append(_bomb_variant_text(action.get("card", "")))
	for key: String in ["card_name", "name", "id", "action_id", "summary"]:
		parts.append(str(action.get(key, "")))
	var rules: Variant = action.get("card_rules", {})
	if rules is Dictionary:
		parts.append(_bomb_variant_text(rules))
	return " ".join(parts)


func _bomb_action_target_text(action: Dictionary, game_state: GameState, player_index: int) -> String:
	var parts: Array[String] = []
	for key: String in ["target_slot", "target", "target_name", "target_pokemon", "bench_target"]:
		parts.append(_bomb_variant_text(action.get(key, "")))
	parts.append(_bomb_resolved_target_name_from_position(action, game_state, player_index))
	parts.append(str(action.get("summary", "")))
	return " ".join(parts)


func _bomb_resolved_target_name_from_position(action: Dictionary, game_state: GameState, player_index: int) -> String:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return ""
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return ""
	for key: String in ["target_position", "position", "target"]:
		var value := str(action.get(key, "")).strip_edges()
		if value == "active":
			return _slot_best_name(player.active_pokemon)
		if value.begins_with("bench_"):
			var index_text := value.trim_prefix("bench_")
			if index_text.is_valid_int():
				var bench_index := int(index_text)
				if bench_index >= 0 and bench_index < player.bench.size():
					return _slot_best_name(player.bench[bench_index])
	return ""


func _bomb_variant_text(raw: Variant) -> String:
	if raw is CardInstance:
		var card: CardInstance = raw
		return _best_card_name(card.card_data) if card.card_data != null else ""
	if raw is CardData:
		var card_data: CardData = raw
		return _best_card_name(card_data)
	if raw is PokemonSlot:
		var slot: PokemonSlot = raw
		return _slot_best_name(slot)
	if raw is Dictionary:
		var dict: Dictionary = raw
		var parts: Array[String] = []
		for key: String in ["name", "name_en", "card", "pokemon", "target", "summary", "id", "action_id", "position"]:
			parts.append(str(dict.get(key, "")))
		return " ".join(parts)
	return str(raw)


func _bomb_charizard_should_block_dead_self_ko(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "use_ability":
		return false
	var source_slot: PokemonSlot = action.get("source_slot", null)
	if source_slot == null:
		return false
	if _bomb_self_ko_damage_for_name(_slot_best_name(source_slot)) <= 0:
		return false
	var fact := _bomb_charizard_self_ko_fact({}, game_state, player_index)
	return fact.is_empty() or not bool(fact.get("route_available", false))


func _bomb_score_self_ko_target(target: PokemonSlot, context: Dictionary) -> float:
	if target == null:
		return -99999.0
	var rules := _ensure_bomb_rules()
	if rules != null and rules.has_method("score_interaction_target"):
		return float(rules.call("score_interaction_target", target, {"id": "self_ko_target"}, context))
	return -99999.0


func _ensure_bomb_rules() -> RefCounted:
	if _rules == null:
		_rules = BombCharizardRulesScript.new()
	return _rules


func _bomb_self_ko_action_id_for_source(legal_actions: Array, source_name: String) -> String:
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if str(ref.get("type", ref.get("kind", ""))) != "use_ability":
			continue
		if _name_matches_any(_continuity_ref_text(ref), [source_name]):
			var action_id := str(ref.get("id", ref.get("action_id", ""))).strip_edges()
			if action_id != "":
				return action_id
	return ""


func _bomb_self_ko_damage_for_name(source_name: String) -> int:
	if _name_contains(source_name, DUSKNOIR):
		return 130
	if _name_contains(source_name, DUSCLOPS):
		return 50
	return 0


func _bomb_all_slots(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if player == null:
		return slots
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	return slots


func _bomb_slot_position(player: PlayerState, slot: PokemonSlot) -> String:
	if player == null or slot == null:
		return ""
	if player.active_pokemon == slot:
		return "active"
	for i: int in player.bench.size():
		if player.bench[i] == slot:
			return "bench_%d" % i
	return ""


func _bomb_charizard_text_looks_garbled(text: String) -> bool:
	var markers := ["銆", "鐨", "鍠", "榫", "俓n", "€", "涓", "绾", "濂"]
	var hits := 0
	for marker: String in markers:
		if text.contains(marker):
			hits += 1
	return hits >= 2
