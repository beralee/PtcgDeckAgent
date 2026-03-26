class_name AIFeatureExtractor
extends RefCounted

const NEST_BALL_EFFECT_ID: String = "1af63a7e2cb7a79215474ad8db8fd8fd"


func build_context(gsm: GameStateMachine, player_index: int, action: Dictionary) -> Dictionary:
	var features := {
		"is_active_target": false,
		"is_bench_target": false,
		"improves_bench_development": false,
		"bench_development_delta": 0,
		"improves_attack_readiness": false,
		"productive": true,
		"remaining_basic_targets": 0,
	}

	if gsm == null or gsm.game_state == null:
		return features
	if player_index < 0 or player_index >= gsm.game_state.players.size():
		return features

	var player: PlayerState = gsm.game_state.players[player_index]
	match str(action.get("kind", "")):
		"attach_energy":
			var target_slot: PokemonSlot = action.get("target_slot")
			var active_slot: PokemonSlot = player.active_pokemon
			var is_active_target: bool = target_slot != null and target_slot == active_slot
			features["is_active_target"] = is_active_target
			features["is_bench_target"] = target_slot != null and not is_active_target
			features["improves_bench_development"] = bool(features["is_bench_target"])
			if is_active_target:
				features["improves_attack_readiness"] = _attach_enables_attack(gsm, active_slot, action)
		"play_basic_to_bench":
			features["improves_bench_development"] = true
			features["bench_development_delta"] = 1
		"play_trainer":
			var card: CardInstance = action.get("card")
			if _is_nest_ball(card):
				var remaining_basic_targets: int = _count_basic_targets(player.deck)
				features["remaining_basic_targets"] = remaining_basic_targets
				features["productive"] = remaining_basic_targets > 0

	return features


func _attach_enables_attack(gsm: GameStateMachine, active_slot: PokemonSlot, action: Dictionary) -> bool:
	if gsm == null or gsm.rule_validator == null or active_slot == null:
		return false
	var card_data: CardData = active_slot.get_card_data()
	var energy_card: CardInstance = action.get("card")
	if card_data == null or energy_card == null or card_data.attacks.is_empty():
		return false
	var simulated_slot := PokemonSlot.new()
	simulated_slot.pokemon_stack = active_slot.pokemon_stack.duplicate()
	simulated_slot.attached_energy = active_slot.attached_energy.duplicate()
	simulated_slot.attached_energy.append(energy_card)

	for attack: Dictionary in card_data.attacks:
		var cost: String = CardData.normalize_attack_cost(attack.get("cost", ""))
		if cost == "":
			continue
		var has_attack_before_attach: bool = gsm.rule_validator.has_enough_energy(active_slot, cost, gsm.effect_processor, gsm.game_state)
		if has_attack_before_attach:
			continue
		if gsm.rule_validator.has_enough_energy(simulated_slot, cost, gsm.effect_processor, gsm.game_state):
			return true
	return false


func _count_basic_targets(deck: Array[CardInstance]) -> int:
	var count: int = 0
	for card: CardInstance in deck:
		if card != null and card.is_basic_pokemon():
			count += 1
	return count


func _is_nest_ball(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	return card.card_data.effect_id == NEST_BALL_EFFECT_ID
