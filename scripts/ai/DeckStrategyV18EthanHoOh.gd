class_name DeckStrategyV18EthanHoOh
extends "res://scripts/ai/DeckStrategy17InitialRulesBase.gd"


const HO_OH := "阿响的凤王ex"
const ARMAROUGE := "红莲铠骑"
const CHARCADET := "炭小侍"
const HEARTHFLAME := "Hearthflame Mask Ogerpon ex"
const FIRE_ENERGY := "Fire Energy"
const MEW_EX := "151C_151"
const CHARCADET_UID := "CSV9C_033"
const EARTHEN_VESSEL_UID := "CSV6C_115"
const ENERGY_RETRIEVAL_UID := "CSVH1C_034"
const BLOODMOON_URSALUNA := "Bloodmoon Ursaluna ex"

const READY_HO_OH_HANDOFF_SCORE := 5600.0
const REBUILD_MEW_HANDOFF_SCORE := 3600.0
const CHARCADET_BRIDGE_HANDOFF_SCORE := 3500.0

const PURE_PROFILE := {
	"strategy_id": "v18_ethans_ho_oh_core",
	"signatures": [HO_OH, "Ethan's Ho-Oh ex", ARMAROUGE],
	"active_priority": ["Mew ex", "Squawkabilly ex", CHARCADET, HO_OH],
	"bench_priority": [HO_OH, CHARCADET, ARMAROUGE, "Latias ex", "Fezandipiti ex"],
	"search_priority": [HO_OH, CHARCADET, ARMAROUGE, FIRE_ENERGY, "Earthen Vessel", "Energy Retrieval"],
	"evolution_priority": [ARMAROUGE],
	"energy_priority": [HO_OH, HEARTHFLAME, "Iron Hands ex", ARMAROUGE],
	"ability_priority": [HO_OH, ARMAROUGE, "Squawkabilly ex", "Fezandipiti ex"],
}


func _profile() -> Dictionary:
	return PURE_PROFILE


func get_strategy_id() -> String:
	return "v18_ethans_ho_oh_core"


func build_turn_plan(game_state: GameState, player_index: int, _context: Dictionary = {}) -> Dictionary:
	var owner := HO_OH
	var phase := "establish"
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		var player: PlayerState = game_state.players[player_index]
		if _best_ho_oh(player, true) != null:
			phase = "convert"
	return {
		"id": "v18_ethans_ho_oh_fire_route",
		"intent": "accelerate_ho_oh" if phase == "establish" else "attack_with_ho_oh",
		"phase": phase,
		"owner": {
			"turn_owner_name": owner,
			"bridge_target_name": ARMAROUGE,
			"pivot_target_name": owner,
		},
		"priorities": {
			"attach": [HO_OH, HEARTHFLAME, "Iron Hands ex"],
			"handoff": [HO_OH, HEARTHFLAME, "Iron Hands ex"],
			"search": [HO_OH, CHARCADET, FIRE_ENERGY, "Earthen Vessel"],
		},
		"flags": {
			"golden_flame_route": true,
			"ho_oh_ready": _best_ho_oh(game_state.players[player_index], true) != null \
				if game_state != null and player_index >= 0 and player_index < game_state.players.size() else false,
		},
		"constraints": {},
	}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var score := super.score_action_absolute(action, game_state, player_index)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return score
	var player: PlayerState = game_state.players[player_index]
	var kind := str(action.get("kind", ""))
	match kind:
		"play_basic_to_bench":
			var card: Variant = action.get("card", null)
			if _is_ho_oh(card):
				return maxf(score, 3600.0)
			if _matches_key(card, CHARCADET):
				return maxf(score, 1700.0)
			if _matches_key(card, BLOODMOON_URSALUNA) \
					and player.prizes.size() > 2 and _best_ho_oh(player, true) == null:
				return -3000.0
		"attach_energy":
			return _score_ho_oh_attach(action, player, score)
		"use_ability":
			var source: PokemonSlot = action.get("source_slot", null)
			if _is_ho_oh(source):
				if _basic_fire_in_hand(player) <= 0:
					return -1800.0
				if not _has_productive_golden_flame_target(player):
					return -3200.0
				return maxf(score, 4300.0)
			if _matches_key(source, ARMAROUGE):
				return _score_armarouge_move(player, score)
		"play_trainer":
			var trainer: Variant = action.get("card", null)
			if _matches_key(trainer, "Professor's Research") and player.deck.size() <= 7:
				return -3200.0
			if _matches_key(trainer, "Super Rod") and not _has_recoverable_fire_route(player):
				return -1900.0
			if _matches_key(trainer, "Energy Retrieval") and _discard_basic_fire(player) <= 0:
				return -1700.0
		"retreat":
			if _partial_active_ho_oh_retreat_breaks_route(player):
				return -3400.0
			if player.active_pokemon != null and not _is_primary_attacker(player.active_pokemon) \
				and _best_ho_oh(player, true) != null:
				return maxf(score, 3200.0)
	return score


func _partial_active_ho_oh_retreat_breaks_route(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null or not _is_ho_oh(player.active_pokemon):
		return false
	var attached_fire := _attached_fire(player.active_pokemon)
	return attached_fire > 0 and attached_fire < 4 and _best_ho_oh(player, true) == null


func get_discard_priority(card: CardInstance) -> int:
	if _is_basic_fire(card):
		return 4
	if _energy_pays_fire(card):
		return 8
	if _is_ho_oh(card):
		return 6
	if _matches_key(card, ARMAROUGE) or _matches_key(card, CHARCADET):
		return 12
	if _matches_key(card, "Wellspring Mask Ogerpon ex") \
		or _matches_key(card, "Terapagos ex") \
		or _matches_key(card, "Durant ex"):
		return 95
	return super.get_discard_priority(card)


func get_search_priority(card: CardInstance) -> int:
	if _is_ho_oh(card):
		return 1000
	if _matches_key(card, CHARCADET):
		return 760
	if _matches_key(card, ARMAROUGE):
		return 700
	if _is_basic_fire(card):
		return 620
	return super.get_search_priority(card)


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", "")).to_lower()
	var player := _player_from_context(context)
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if step_id == "attach_fire_to_benched_ethan":
			if _is_ho_oh(slot):
				return _golden_flame_target_score(slot, step, player)
			return 400.0
		if step_id.contains("switch") or step_id.contains("active") or step_id.contains("handoff"):
			if _is_ho_oh(slot):
				return 4200.0 + float(_attached_fire(slot)) * 180.0
	if item is CardInstance and step_id == "move_fire_energy_from_bench_to_active":
		var source := _source_slot_for_energy(player, item as CardInstance)
		if source != null and _is_ho_oh(source):
			return 1600.0 - float(_attached_fire(source)) * 120.0
	return super.score_interaction_target(item, step, context)


func _golden_flame_target_score(slot: PokemonSlot, step: Dictionary, player: PlayerState) -> float:
	var paying_fire := _attached_fire(slot)
	var positive_gap := 4 - paying_fire
	var batch_size := _golden_flame_batch_size(step, player)
	if positive_gap == batch_size:
		return 6200.0
	if positive_gap > 0:
		return 5200.0 - float(positive_gap) * 240.0
	return -2600.0 - float(maxi(0, paying_fire - 4)) * 120.0


func _has_productive_golden_flame_target(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if _is_ho_oh(slot) and _attached_fire(slot) < 4:
			return true
	return false


func _golden_flame_batch_size(step: Dictionary, player: PlayerState) -> int:
	var max_batch := clampi(int(step.get("max_select", 2)), 1, 2)
	var available_fire := 0
	var source_items: Variant = step.get("source_items", [])
	if source_items is Array:
		for source: Variant in source_items:
			if source is CardInstance and _is_basic_fire(source as CardInstance):
				available_fire += 1
	if available_fire <= 0:
		available_fire = _basic_fire_in_hand(player)
	if available_fire <= 0:
		return max_batch
	return mini(max_batch, available_fire)


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var base_score := super.score_handoff_target(item, step, context)
	var step_id := str(step.get("id", "")).strip_edges().to_lower()
	if not item is PokemonSlot or step_id.contains("opponent"):
		return base_score
	var slot := item as PokemonSlot
	var attached_fire := _attached_fire(slot)
	if _is_ho_oh(slot) and attached_fire >= 4:
		return maxf(base_score, READY_HO_OH_HANDOFF_SCORE)
	var player := _player_from_context(context)
	if step_id == "send_out" and _is_charcadet(slot) and slot.attached_energy.is_empty() \
			and player != null and slot in player.bench and _best_ho_oh(player, true) == null \
			and not _has_benched_mew(player) and _can_complete_benched_rebuild_ho_oh(player):
		return maxf(base_score, CHARCADET_BRIDGE_HANDOFF_SCORE)
	if _is_mew_ex(slot) and slot.attached_energy.is_empty() \
			and player != null and _best_ho_oh(player, true) == null \
			and _has_benched_rebuild_ho_oh(player) and _basic_fire_in_hand(player) > 0:
		return maxf(base_score, REBUILD_MEW_HANDOFF_SCORE)
	return base_score


func _score_ho_oh_attach(action: Dictionary, player: PlayerState, base_score: float) -> float:
	var card: CardInstance = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	if not _energy_pays_fire(card, target):
		return base_score
	if _is_ho_oh(target):
		var route_score := 3900.0 if _is_basic_fire(card) else 3500.0
		return maxf(base_score, route_score - float(_attached_fire(target)) * 260.0)
	if _matches_key(target, HEARTHFLAME) \
			and _best_ho_oh(player, true) == null \
			and _has_benched_rebuild_ho_oh(player) \
			and target.get_remaining_hp() <= target.get_max_hp() / 4 \
			and not bool(predict_attacker_damage(target, 1).get("can_attack", false)):
		return minf(base_score, -2600.0)
	if _matches_key(target, ARMAROUGE) and _best_ho_oh(player, false) == null:
		return maxf(base_score, 900.0)
	return minf(base_score, -1700.0)


func _score_armarouge_move(player: PlayerState, base_score: float) -> float:
	if player == null or player.active_pokemon == null:
		return -2200.0
	var active := player.active_pokemon
	if _is_ho_oh(active) and _attached_fire(active) < 4:
		return maxf(base_score, 3600.0)
	if _matches_key(active, HEARTHFLAME):
		return maxf(base_score, 1900.0)
	return -2200.0


func _best_ho_oh(player: PlayerState, require_ready: bool) -> PokemonSlot:
	var best: PokemonSlot = null
	var best_fire := -1
	for slot: PokemonSlot in _all_slots(player):
		if not _is_ho_oh(slot):
			continue
		var fire := _attached_fire(slot)
		if require_ready and fire < 4:
			continue
		if fire > best_fire:
			best = slot
			best_fire = fire
	return best


func _has_benched_rebuild_ho_oh(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if _is_ho_oh(slot):
			var attached_fire := _attached_fire(slot)
			if attached_fire >= 1 and attached_fire <= 3:
				return true
	return false


func _can_complete_benched_rebuild_ho_oh(player: PlayerState) -> bool:
	if player == null:
		return false
	var hand_fire := _basic_fire_in_hand(player)
	var vessel_fire := _fire_available_through_vessel(player, hand_fire)
	var retrieval_fire := _fire_available_through_retrieval(player, hand_fire)
	var available_fire := maxi(hand_fire, maxi(vessel_fire, retrieval_fire))
	for slot: PokemonSlot in player.bench:
		if not _is_ho_oh(slot):
			continue
		var attached_fire := _attached_fire(slot)
		if attached_fire >= 1 and attached_fire <= 3 \
				and available_fire >= 4 - attached_fire:
			return true
	return false


func _fire_available_through_vessel(player: PlayerState, hand_fire: int) -> int:
	var deck_fire := _basic_fire_in_cards(player.deck)
	if deck_fire <= 0:
		return hand_fire
	var best := hand_fire
	for vessel: CardInstance in player.hand:
		if not _is_earthen_vessel(vessel) or vessel.card_data == null \
				or str(vessel.card_data.card_type) != "Item":
			continue
		var can_pay_cost := false
		var fire_after_cost := hand_fire
		for discard_candidate: CardInstance in player.hand:
			if discard_candidate == vessel:
				continue
			can_pay_cost = true
			if not _is_basic_fire(discard_candidate):
				fire_after_cost = hand_fire
				break
			fire_after_cost = maxi(0, hand_fire - 1)
		if can_pay_cost:
			best = maxi(best, fire_after_cost + mini(2, deck_fire))
	return best


func _fire_available_through_retrieval(player: PlayerState, hand_fire: int) -> int:
	var discard_fire := _discard_basic_fire(player)
	if discard_fire <= 0:
		return hand_fire
	for card: CardInstance in player.hand:
		if _is_energy_retrieval(card) and card.card_data != null \
				and str(card.card_data.card_type) == "Item":
			return hand_fire + mini(2, discard_fire)
	return hand_fire


func _basic_fire_in_cards(cards: Array) -> int:
	var result := 0
	for card: CardInstance in cards:
		if _is_basic_fire(card):
			result += 1
	return result


func _has_benched_mew(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if _is_mew_ex(slot):
			return true
	return false


func _is_primary_attacker(item: Variant) -> bool:
	return _is_ho_oh(item) or _matches_key(item, HEARTHFLAME) or _matches_key(item, "Iron Hands ex")


func _is_ho_oh(item: Variant) -> bool:
	return _matches_key(item, HO_OH) or _matches_key(item, "Ethan's Ho-Oh ex") or _matches_key(item, "CSV10C_035")


func _is_charcadet(item: Variant) -> bool:
	return _matches_key(item, CHARCADET) or _matches_key(item, "Charcadet") or _matches_key(item, CHARCADET_UID)


func _is_mew_ex(item: Variant) -> bool:
	return _matches_key(item, MEW_EX) or _matches_key(item, "梦幻ex") or _matches_key(item, "Mew ex")


func _is_earthen_vessel(item: Variant) -> bool:
	return _matches_key(item, EARTHEN_VESSEL_UID) or _matches_key(item, "大地容器") \
		or _matches_key(item, "Earthen Vessel")


func _is_energy_retrieval(item: Variant) -> bool:
	return _matches_key(item, ENERGY_RETRIEVAL_UID) or _matches_key(item, "能量回收") \
		or _matches_key(item, "Energy Retrieval")


func _is_basic_fire(card: CardInstance) -> bool:
	if card == null or card.card_data == null or str(card.card_data.card_type) != "Basic Energy":
		return false
	var provides := str(card.card_data.energy_provides)
	if provides == "":
		provides = str(card.card_data.energy_type)
	return provides == "R"


func _energy_pays_fire(card: CardInstance, target: PokemonSlot = null) -> bool:
	if card == null or card.card_data == null or not card.card_data.is_energy():
		return false
	if _matches_key(card, "Legacy Energy") or _matches_key(card, "遗赠能量"):
		return true
	if _matches_key(card, "Luminous Energy") or _matches_key(card, "夜光能量"):
		return not _luminous_is_suppressed(card, target)
	var provides := str(card.card_data.energy_provides)
	if provides == "":
		provides = str(card.card_data.energy_type)
	return provides == "ANY" or "R" in provides


func _luminous_is_suppressed(card: CardInstance, target: PokemonSlot) -> bool:
	if target == null:
		return false
	for attached: CardInstance in target.attached_energy:
		if attached == card:
			continue
		if attached != null and attached.card_data != null \
			and str(attached.card_data.card_type) == "Special Energy":
			return true
	return false


func _attached_fire(slot: PokemonSlot) -> int:
	var result := 0
	if slot == null:
		return result
	for energy: CardInstance in slot.attached_energy:
		if _energy_pays_fire(energy, slot):
			result += 1
	return result


func _basic_fire_in_hand(player: PlayerState) -> int:
	var result := 0
	if player == null:
		return result
	for card: CardInstance in player.hand:
		if _is_basic_fire(card):
			result += 1
	return result


func _discard_basic_fire(player: PlayerState) -> int:
	var result := 0
	if player == null:
		return result
	for card: CardInstance in player.discard_pile:
		if _is_basic_fire(card):
			result += 1
	return result


func _has_recoverable_fire_route(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.discard_pile:
		if _is_basic_fire(card) or _is_ho_oh(card) or _matches_key(card, CHARCADET) or _matches_key(card, ARMAROUGE):
			return true
	return false


func _player_from_context(context: Dictionary) -> PlayerState:
	if context.get("player", null) is PlayerState:
		return context.get("player") as PlayerState
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		return game_state.players[player_index]
	return null


func _source_slot_for_energy(player: PlayerState, energy: CardInstance) -> PokemonSlot:
	if player == null or energy == null:
		return null
	for slot: PokemonSlot in _all_slots(player):
		if energy in slot.attached_energy:
			return slot
	return null
