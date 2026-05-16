class_name DeckStrategy17InitialRulesBase
extends "res://scripts/ai/DeckStrategyBase.gd"


const StateEncoderScript = preload("res://scripts/ai/StateEncoder.gd")

const TRAINER_SEARCH_NAMES := [
	"Nest Ball",
	"Ultra Ball",
	"Buddy-Buddy Poffin",
	"Hisuian Heavy Ball",
	"Pokegear 3.0",
	"Pok\u00e9gear 3.0",
]
const TRAINER_DRAW_NAMES := [
	"Professor's Research",
	"Iono",
	"Arven",
	"Irida",
	"Ciphermaniac's Codebreaking",
	"Professor Sada's Vitality",
]
const TRAINER_ENERGY_NAMES := [
	"Earthen Vessel",
	"Superior Energy Retrieval",
	"Energy Retrieval",
	"Energy Switch",
	"Electric Generator",
	"Dark Patch",
]
const TRAINER_GUST_NAMES := [
	"Boss's Orders",
	"Counter Catcher",
	"Prime Catcher",
	"Pokemon Catcher",
	"Pok\u00e9mon Catcher",
]
const TRAINER_SWITCH_NAMES := [
	"Switch",
	"Switch Cart",
	"Rescue Board",
]


func _profile() -> Dictionary:
	return {}


func get_strategy_id() -> String:
	return str(_profile().get("strategy_id", ""))


func get_signature_names() -> Array[String]:
	return _profile_list("signatures")


func get_state_encoder_class() -> GDScript:
	return StateEncoderScript


func load_value_net(_path: String) -> bool:
	return false


func get_value_net() -> RefCounted:
	return null


func get_mcts_config() -> Dictionary:
	return {
		"branch_factor": 3,
		"time_budget_ms": 90,
		"rollouts_per_sequence": 0,
	}


func get_intent_planner_profile() -> Dictionary:
	return {
		"primary_attackers": _profile_list("energy_priority"),
		"bench_priorities": _profile_list("bench_priority"),
		"search_priorities": _profile_list("search_priority"),
		"evolution_priorities": _profile_list("evolution_priority"),
	}


func plan_opening_setup(player: PlayerState) -> Dictionary:
	var basics: Array[Dictionary] = []
	if player == null:
		return {"active_hand_index": -1, "bench_hand_indices": []}
	for hand_index: int in player.hand.size():
		var card: CardInstance = player.hand[hand_index]
		if card == null or not card.is_basic_pokemon():
			continue
		basics.append({
			"index": hand_index,
			"active": _opening_active_score(card),
			"bench": _opening_bench_score(card),
		})
	if basics.is_empty():
		return {"active_hand_index": -1, "bench_hand_indices": []}
	basics.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("active", 0.0)) > float(b.get("active", 0.0))
	)
	var active_index: int = int(basics[0].get("index", -1))
	var bench_entries := basics.duplicate(true)
	bench_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("bench", 0.0)) > float(b.get("bench", 0.0))
	)
	var bench_indices: Array[int] = []
	for entry: Dictionary in bench_entries:
		var idx := int(entry.get("index", -1))
		if idx == active_index:
			continue
		if float(entry.get("bench", 0.0)) <= 0.0:
			continue
		bench_indices.append(idx)
		if bench_indices.size() >= 5:
			break
	return {
		"active_hand_index": active_index,
		"bench_hand_indices": bench_indices,
	}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	match str(action.get("kind", "")):
		"attack", "granted_attack":
			return _score_attack_action(action, player)
		"attach_energy":
			return _score_attach_action(action, player)
		"attach_tool":
			return _score_attach_tool_action(action, player)
		"evolve":
			return _score_evolve_action(action, player)
		"play_basic_to_bench":
			return _score_play_basic_action(action)
		"play_trainer", "play_stadium":
			return _score_trainer_action(action)
		"use_ability", "use_stadium_effect":
			return _score_ability_action(action, player)
		"retreat":
			return _score_retreat_action(player)
		"end_turn":
			return -100.0
	return 20.0


func score_action(action: Dictionary, context: Dictionary) -> float:
	return score_action_absolute(
		action,
		context.get("game_state", null),
		int(context.get("player_index", -1))
	)


func evaluate_board(game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var score := 0.0
	for slot: PokemonSlot in _all_slots(player):
		var cd := _card_data_from_item(slot)
		if cd == null:
			continue
		score += 40.0
		score += float(cd.hp) * 0.10
		score += _profile_score(slot, "energy_priority", 420.0, 30.0)
		score += _profile_score(slot, "bench_priority", 140.0, 12.0)
		score += float(slot.attached_energy.size()) * (55.0 + _profile_score(slot, "energy_priority", 5.0, 0.4))
		if _is_stage2(cd):
			score += 180.0
		elif _is_stage1(cd):
			score += 90.0
		if cd.mechanic in ["ex", "V", "VSTAR"]:
			score += 80.0
	return score


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	var cd := _card_data_from_item(slot)
	if slot == null or cd == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	var attached := slot.attached_energy.size() + extra_context
	var best_damage := 0
	var can_attack := false
	for attack: Dictionary in cd.attacks:
		var cost := CardData.normalize_attack_cost(str(attack.get("cost", "")))
		var damage := _parse_damage(str(attack.get("damage", "0")))
		if attached >= cost.length():
			can_attack = true
			best_damage = maxi(best_damage, damage)
	return {"damage": best_damage, "can_attack": can_attack, "description": ""}


func get_discard_priority(card: CardInstance) -> int:
	var cd := _card_data_from_item(card)
	if cd == null:
		return 0
	if _matches_profile(card, "energy_priority") or _matches_profile(card, "evolution_priority"):
		return 15
	if _matches_profile(card, "bench_priority") or _matches_profile(card, "search_priority"):
		return 30
	if cd.is_energy():
		return 120
	if cd.is_trainer():
		return 85
	return 70


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	var priority := get_discard_priority(card)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return priority
	if _matches_profile(card, "bench_priority") and _count_matching_on_field(game_state.players[player_index], card) == 0:
		return mini(priority, 10)
	return priority


func get_search_priority(card: CardInstance) -> int:
	var cd := _card_data_from_item(card)
	if cd == null:
		return 0
	var score := int(round(_profile_score(card, "search_priority", 240.0, 14.0)))
	score = maxi(score, int(round(_profile_score(card, "evolution_priority", 220.0, 14.0))))
	score = maxi(score, int(round(_profile_score(card, "bench_priority", 180.0, 12.0))))
	score = maxi(score, int(round(_profile_score(card, "energy_priority", 190.0, 12.0))))
	if score > 0:
		return score
	if cd.is_energy():
		return 55
	if cd.is_trainer():
		return 40 + int(_trainer_name_score(_primary_name(card)) * 0.20)
	return 70


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var max_select := int(step.get("max_select", 1))
	if max_select <= 0:
		max_select = 1
	var ranked: Array[Dictionary] = []
	for item: Variant in items:
		ranked.append({
			"item": item,
			"score": score_interaction_target(item, step, context),
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	var selected: Array = []
	for entry: Dictionary in ranked:
		if selected.size() >= max_select:
			break
		selected.append(entry.get("item"))
	return selected


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", "")).to_lower()
	if item is CardInstance:
		var card := item as CardInstance
		if step_id.contains("discard"):
			return float(get_discard_priority(card))
		if step_id.contains("recover") or step_id.contains("rod") or step_id.contains("stretcher"):
			return float(get_search_priority(card)) * 0.80
		return float(get_search_priority(card))
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if step_id.contains("assign") or step_id.contains("attach") or step_id.contains("energy"):
			return _attach_target_score(slot)
		if step_id.contains("switch") or step_id.contains("send") or step_id.contains("active") or step_id.contains("handoff"):
			return _handoff_target_score(slot)
		return _slot_general_score(slot)
	var target_name := str(item)
	if target_name != "":
		return _profile_key_score(target_name, "search_priority", 120.0, 8.0)
	return 0.0


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if item is PokemonSlot:
		return _handoff_target_score(item as PokemonSlot)
	return score_interaction_target(item, step, context)


func build_turn_plan(game_state: GameState, player_index: int, _context: Dictionary = {}) -> Dictionary:
	var primary_name := ""
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		primary_name = _best_profile_name_on_field(game_state.players[player_index], "energy_priority")
	if primary_name == "":
		var energy_priority := _profile_list("energy_priority")
		if not energy_priority.is_empty():
			primary_name = energy_priority[0]
	return {
		"id": "v17_initial_rules",
		"intent": "advance_primary_attack",
		"owner": {
			"turn_owner_name": primary_name,
			"bridge_target_name": primary_name,
			"pivot_target_name": primary_name,
		},
		"priorities": {
			"attach": _profile_list("energy_priority"),
			"handoff": _profile_list("energy_priority"),
			"search": _profile_list("search_priority"),
		},
		"constraints": {},
	}


func _score_attack_action(action: Dictionary, player: PlayerState) -> float:
	var source: PokemonSlot = action.get("source_slot", null)
	if source == null and player != null:
		source = player.active_pokemon
	var score := 760.0 + _profile_score(source, "energy_priority", 240.0, 18.0)
	score += float(int(action.get("projected_damage", 0))) * 1.8
	if bool(action.get("projected_knockout", false)):
		score += 850.0
	return score


func _score_attach_action(action: Dictionary, _player: PlayerState) -> float:
	var target: PokemonSlot = action.get("target_slot", null)
	if target == null:
		return 0.0
	return 210.0 + _attach_target_score(target)


func _score_attach_tool_action(action: Dictionary, _player: PlayerState) -> float:
	var target: PokemonSlot = action.get("target_slot", null)
	return 120.0 + _slot_general_score(target)


func _score_evolve_action(action: Dictionary, _player: PlayerState) -> float:
	var card: CardInstance = action.get("card", null)
	var score := 260.0
	score += _profile_score(card, "evolution_priority", 360.0, 28.0)
	score += _profile_score(card, "energy_priority", 220.0, 18.0)
	var cd := _card_data_from_item(card)
	if cd != null:
		if _is_stage2(cd):
			score += 160.0
		elif _is_stage1(cd):
			score += 90.0
	return score


func _score_play_basic_action(action: Dictionary) -> float:
	var card: CardInstance = action.get("card", null)
	return 170.0 + _opening_bench_score(card)


func _score_trainer_action(action: Dictionary) -> float:
	var card: CardInstance = action.get("card", null)
	var score := 130.0
	if bool(action.get("productive", true)):
		score += 50.0
	score += _trainer_name_score(_primary_name(card))
	return score


func _score_ability_action(action: Dictionary, player: PlayerState) -> float:
	var source: PokemonSlot = action.get("source_slot", null)
	if source == null and player != null:
		source = player.active_pokemon
	return 230.0 + _profile_score(source, "ability_priority", 180.0, 14.0) + _slot_general_score(source) * 0.35


func _score_retreat_action(player: PlayerState) -> float:
	if player == null or player.active_pokemon == null:
		return 0.0
	var active_score := _handoff_target_score(player.active_pokemon)
	var best_bench_score := 0.0
	for slot: PokemonSlot in player.bench:
		best_bench_score = maxf(best_bench_score, _handoff_target_score(slot))
	return 160.0 if best_bench_score > active_score + 80.0 else 45.0


func _opening_active_score(card: CardInstance) -> float:
	return 80.0 + _profile_score(card, "active_priority", 260.0, 20.0) + _profile_score(card, "energy_priority", 120.0, 10.0)


func _opening_bench_score(card: CardInstance) -> float:
	return _profile_score(card, "bench_priority", 260.0, 18.0) + _profile_score(card, "search_priority", 120.0, 8.0)


func _attach_target_score(slot: PokemonSlot) -> float:
	if slot == null:
		return 0.0
	var score := _profile_score(slot, "energy_priority", 330.0, 24.0)
	score += _profile_score(slot, "evolution_priority", 110.0, 8.0)
	var prediction := predict_attacker_damage(slot, 1)
	if bool(prediction.get("can_attack", false)):
		score += 120.0
	score += _slot_general_score(slot) * 0.30
	return score


func _handoff_target_score(slot: PokemonSlot) -> float:
	if slot == null:
		return 0.0
	var score := _profile_score(slot, "energy_priority", 300.0, 24.0)
	var prediction := predict_attacker_damage(slot)
	if bool(prediction.get("can_attack", false)):
		score += 240.0 + float(int(prediction.get("damage", 0))) * 1.2
	return score + _slot_general_score(slot) * 0.20


func _slot_general_score(slot: PokemonSlot) -> float:
	var cd := _card_data_from_item(slot)
	if slot == null or cd == null:
		return 0.0
	var score := _profile_score(slot, "bench_priority", 150.0, 10.0)
	score += _profile_score(slot, "search_priority", 100.0, 8.0)
	score += float(slot.attached_energy.size()) * 20.0
	if cd.mechanic in ["ex", "V", "VSTAR"]:
		score += 55.0
	if _is_stage2(cd):
		score += 75.0
	elif _is_stage1(cd):
		score += 40.0
	return score


func _trainer_name_score(name: String) -> float:
	var lowered := name.to_lower()
	for trainer_name: String in TRAINER_SEARCH_NAMES:
		if lowered == trainer_name.to_lower():
			return 150.0
	for trainer_name: String in TRAINER_DRAW_NAMES:
		if lowered == trainer_name.to_lower():
			return 135.0
	for trainer_name: String in TRAINER_ENERGY_NAMES:
		if lowered == trainer_name.to_lower():
			return 145.0
	for trainer_name: String in TRAINER_GUST_NAMES:
		if lowered == trainer_name.to_lower():
			return 90.0
	for trainer_name: String in TRAINER_SWITCH_NAMES:
		if lowered == trainer_name.to_lower():
			return 80.0
	if lowered.contains("rare candy"):
		return 150.0
	if lowered.contains("night stretcher") or lowered.contains("super rod"):
		return 80.0
	return 35.0


func _profile_score(item: Variant, list_key: String, max_score: float, step_down: float) -> float:
	var keys := _profile_list(list_key)
	for index: int in keys.size():
		if _matches_key(item, keys[index]):
			return maxf(0.0, max_score - float(index) * step_down)
	return 0.0


func _profile_key_score(name: String, list_key: String, max_score: float, step_down: float) -> float:
	var keys := _profile_list(list_key)
	var lowered := name.to_lower()
	for index: int in keys.size():
		if lowered == keys[index].to_lower():
			return maxf(0.0, max_score - float(index) * step_down)
	return 0.0


func _matches_profile(item: Variant, list_key: String) -> bool:
	for key: String in _profile_list(list_key):
		if _matches_key(item, key):
			return true
	return false


func _matches_key(item: Variant, key: String) -> bool:
	var lowered_key := key.to_lower()
	for label: String in _labels_for_item(item):
		if label.to_lower() == lowered_key:
			return true
	return false


func _labels_for_item(item: Variant) -> Array[String]:
	var labels: Array[String] = []
	var cd := _card_data_from_item(item)
	if cd == null:
		var raw := str(item)
		if raw != "":
			labels.append(raw)
		return labels
	_append_label(labels, str(cd.name))
	_append_label(labels, str(cd.name_en))
	_append_label(labels, str(cd.get_uid()))
	if str(cd.set_code) != "" and str(cd.card_index) != "":
		_append_label(labels, "%s_%s" % [str(cd.set_code), str(cd.card_index)])
	_append_label(labels, str(cd.effect_id))
	return labels


func _append_label(labels: Array[String], label: String) -> void:
	var normalized := label.strip_edges()
	if normalized != "" and not labels.has(normalized):
		labels.append(normalized)


func _card_data_from_item(item: Variant) -> CardData:
	if item is CardInstance:
		return (item as CardInstance).card_data
	if item is PokemonSlot:
		return (item as PokemonSlot).get_card_data()
	if item is CardData:
		return item as CardData
	return null


func _primary_name(item: Variant) -> String:
	var cd := _card_data_from_item(item)
	if cd == null:
		return str(item)
	if str(cd.name_en) != "":
		return str(cd.name_en)
	return str(cd.name)


func _profile_list(key: String) -> Array[String]:
	var result: Array[String] = []
	var value: Variant = _profile().get(key, [])
	if value is Array:
		for item: Variant in value:
			result.append(str(item))
	return result


func _all_slots(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if player == null:
		return slots
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	return slots


func _best_profile_name_on_field(player: PlayerState, list_key: String) -> String:
	var best_name := ""
	var best_score := 0.0
	for slot: PokemonSlot in _all_slots(player):
		var score := _profile_score(slot, list_key, 300.0, 20.0)
		if score > best_score:
			best_score = score
			best_name = _primary_name(slot)
	return best_name


func _count_matching_on_field(player: PlayerState, card: CardInstance) -> int:
	var count := 0
	for slot: PokemonSlot in _all_slots(player):
		if _shares_any_label(slot, card):
			count += 1
	return count


func _shares_any_label(left: Variant, right: Variant) -> bool:
	var right_labels := _labels_for_item(right)
	for label: String in _labels_for_item(left):
		if right_labels.has(label):
			return true
	return false


func _is_stage2(cd: CardData) -> bool:
	return cd != null and str(cd.stage).to_lower() == "stage 2"


func _is_stage1(cd: CardData) -> bool:
	return cd != null and str(cd.stage).to_lower() == "stage 1"


func _parse_damage(raw_damage: String) -> int:
	var digits := ""
	for i: int in raw_damage.length():
		var ch := raw_damage.substr(i, 1)
		if ch >= "0" and ch <= "9":
			digits += ch
		elif digits != "":
			break
	return int(digits) if digits != "" else 0
