class_name AIIntentAttackPlanner
extends RefCounted

const Util = preload("res://scripts/ai/intent/AIIntentPlannerUtil.gd")


func build_attack_intents(
	game_state: GameState,
	player_index: int,
	legal_action_refs: Array,
	profile: Dictionary = {}
) -> Array[Dictionary]:
	var intents: Array[Dictionary] = []
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return intents
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return intents
	var active: PokemonSlot = player.active_pokemon
	var cd: CardData = active.get_card_data()
	if cd == null:
		return intents
	var attached := Util.attached_energy_counts(active)
	var legal_attacks := _legal_attack_refs_by_index(legal_action_refs)
	for attack_index: int in cd.attacks.size():
		var attack := Util.attack_dict(cd, attack_index)
		if attack.is_empty():
			continue
		var legal_ref: Dictionary = legal_attacks.get(attack_index, {}) if legal_attacks.get(attack_index, {}) is Dictionary else {}
		var intent := _intent_for_attack(game_state, player_index, active, cd, attack_index, attack, attached, legal_ref, profile)
		intents.append(intent)
	_mark_better_attack_blocks(intents)
	return intents


func _legal_attack_refs_by_index(legal_action_refs: Array) -> Dictionary:
	var by_index := {}
	for raw: Variant in legal_action_refs:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		var kind := Util.ref_type(ref)
		if kind not in ["attack", "granted_attack"]:
			continue
		var attack_index := int(ref.get("attack_index", -1))
		if attack_index >= 0:
			by_index[attack_index] = ref
	return by_index


func _intent_for_attack(
	game_state: GameState,
	player_index: int,
	slot: PokemonSlot,
	cd: CardData,
	attack_index: int,
	attack: Dictionary,
	attached_counts: Dictionary,
	legal_ref: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var attack_name := str(attack.get("name", legal_ref.get("attack_name", "")))
	var cost_counts := Util.cost_counts(attack.get("cost", ""))
	var missing := Util.missing_cost(cost_counts, attached_counts)
	var damage := int(legal_ref.get("projected_damage", Util.parse_damage(attack.get("damage", ""))))
	var text := str(attack.get("text", legal_ref.get("attack_rules", {}).get("text", "") if legal_ref.get("attack_rules", {}) is Dictionary else ""))
	var role := _attack_role(cd, attack_name, attack_index, attack, profile)
	var opponent_hp := Util.opponent_active_hp(game_state, player_index)
	var ko_active := damage > 0 and opponent_hp > 0 and damage >= opponent_hp
	var ready_now := not legal_ref.is_empty()
	var priority := _terminal_priority(role, damage, ko_active, ready_now)
	var intent := {
		"action_id": Util.action_id(legal_ref),
		"pokemon_position": Util.slot_position(slot, game_state, player_index),
		"pokemon_name": Util.best_card_name(cd),
		"attack_name": attack_name,
		"attack_index": attack_index,
		"role": role,
		"ready_now": ready_now,
		"unlock_cost": _symbols_to_words(Util.symbols_from_cost(attack.get("cost", ""))),
		"missing_cost": _symbols_to_words(missing),
		"estimated_damage": damage,
		"bench_damage": _bench_damage_from_text(text),
		"ko_active": ko_active,
		"ko_bench_targets": _bench_ko_targets(game_state, player_index, _bench_damage_from_text(text)),
		"terminal_priority": priority,
		"can_replace_end_turn": ready_now and priority in ["high", "medium"],
		"blocked_by_better_attack": false,
		"deck_draw_risk": false,
		"reason": _attack_reason(role, ready_now, damage, ko_active),
	}
	if Util.damage_is_scaling(attack.get("damage", ""), text):
		intent["scaling_damage"] = true
	return intent


func _attack_role(cd: CardData, attack_name: String, attack_index: int, attack: Dictionary, profile: Dictionary) -> String:
	var pokemon_name := Util.best_card_name(cd)
	if _profile_attack_matches(profile, "primary_attacks", pokemon_name, attack_name):
		return "primary_damage"
	if _profile_attack_matches(profile, "finisher_attacks", pokemon_name, attack_name):
		return "finisher"
	if _profile_attack_matches(profile, "scaling_attacks", pokemon_name, attack_name) \
			or Util.profile_has_name(profile, "scaling_attackers", pokemon_name):
		return "scaling_damage"
	if _profile_attack_matches(profile, "desperation_redraw_attacks", pokemon_name, attack_name) \
			or _profile_attack_matches(profile, "low_value_attacks", pokemon_name, attack_name):
		return "desperation_redraw"
	if _profile_attack_matches(profile, "setup_draw_attacks", pokemon_name, attack_name):
		return "setup_draw_attack"
	var combined := ("%s %s %s" % [attack_name, str(attack.get("text", "")), str(attack.get("damage", ""))]).to_lower()
	if combined.find("discard your hand") >= 0 \
			or combined.find("hand全部") >= 0 \
			or combined.find("手牌全部") >= 0 \
			or combined.find("抽取6") >= 0 \
			or combined.find("draw 6") >= 0:
		return "desperation_redraw"
	if combined.find("draw") >= 0 or combined.find("抽") >= 0:
		return "setup_draw_attack"
	if Util.damage_is_scaling(attack.get("damage", ""), attack.get("text", "")):
		return "scaling_damage"
	var damage := Util.parse_damage(attack.get("damage", ""))
	if damage >= 150 or (attack_index >= 1 and damage >= 70):
		return "primary_damage"
	if damage > 0:
		return "chip_damage"
	return "fallback_chip"


func _profile_attack_matches(profile: Dictionary, key: String, pokemon_name: String, attack_name: String) -> bool:
	var raw: Variant = profile.get(key, [])
	if not (raw is Array):
		return false
	for entry: Variant in raw:
		if entry is Dictionary:
			var pokemon := str((entry as Dictionary).get("pokemon", ""))
			var attack := str((entry as Dictionary).get("attack", (entry as Dictionary).get("name", "")))
			if (pokemon == "" or Util.name_matches(pokemon_name, pokemon)) and (attack == "" or Util.name_matches(attack_name, attack)):
				return true
		elif Util.name_matches(attack_name, entry):
			return true
	return false


func _terminal_priority(role: String, damage: int, ko_active: bool, ready_now: bool) -> String:
	if not ready_now:
		return "future"
	if ko_active:
		return "high"
	if role in ["primary_damage", "finisher", "scaling_damage"] and damage >= 100:
		return "high"
	if role in ["desperation_redraw", "setup_draw_attack"]:
		return "low"
	if damage > 0:
		return "medium"
	return "low"


func _mark_better_attack_blocks(intents: Array[Dictionary]) -> void:
	var best_score := -999999
	for intent: Dictionary in intents:
		if not bool(intent.get("ready_now", false)):
			continue
		best_score = maxi(best_score, _priority_score(intent))
	if best_score <= -999999:
		return
	for intent: Dictionary in intents:
		if not bool(intent.get("ready_now", false)):
			continue
		var score := _priority_score(intent)
		if score + 150 < best_score:
			intent["blocked_by_better_attack"] = true
			intent["can_replace_end_turn"] = false
			intent["reason"] = "%s; blocked because a higher-value ready attack exists" % str(intent.get("reason", ""))


func _priority_score(intent: Dictionary) -> int:
	var score := int(intent.get("estimated_damage", 0))
	match str(intent.get("terminal_priority", "")):
		"high":
			score += 500
		"medium":
			score += 200
		"low":
			score -= 150
		"future":
			score -= 300
	if bool(intent.get("ko_active", false)):
		score += 400
	match str(intent.get("role", "")):
		"primary_damage", "finisher", "scaling_damage":
			score += 200
		"desperation_redraw", "setup_draw_attack":
			score -= 200
	return score


func _bench_damage_from_text(text: String) -> int:
	var lower := text.to_lower()
	if lower.find("6 damage counters") >= 0 or text.find("6个伤害") >= 0 or text.find("6 个伤害") >= 0:
		return 60
	if lower.find("90 damage") >= 0 or text.find("90") >= 0:
		return 90
	return 0


func _bench_ko_targets(game_state: GameState, player_index: int, bench_damage: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if bench_damage <= 0 or game_state == null:
		return result
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return result
	var opponent: PlayerState = game_state.players[opponent_index]
	if opponent == null:
		return result
	for i: int in opponent.bench.size():
		var slot: PokemonSlot = opponent.bench[i]
		if slot == null or slot.get_card_data() == null:
			continue
		if int(slot.get_remaining_hp()) <= bench_damage:
			result.append({
				"position": "bench_%d" % i,
				"name": Util.best_card_name(slot.get_card_data()),
				"hp_remaining": int(slot.get_remaining_hp()),
				"damage_to_place": bench_damage,
			})
	return result


func _symbols_to_words(symbols: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for symbol: String in symbols:
		result.append(Util.energy_word(symbol))
	return result


func _attack_reason(role: String, ready_now: bool, damage: int, ko_active: bool) -> String:
	if not ready_now:
		return "attack is not currently legal; facts expose missing cost only"
	if ko_active:
		return "ready attack can KO opponent active"
	if role in ["primary_damage", "finisher", "scaling_damage"]:
		return "ready primary or scaling damage attack"
	if role in ["desperation_redraw", "setup_draw_attack"]:
		return "low-priority draw/setup attack; prefer productive setup when available"
	return "ready damage attack for %d" % damage
