class_name AILegalActionBuilder
extends RefCounted


func build_actions(gsm: GameStateMachine, player_index: int) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if gsm == null or gsm.game_state == null:
		return actions
	var state := gsm.game_state
	if state.current_player_index != player_index:
		return actions
	if state.phase != GameState.GamePhase.MAIN:
		return actions
	if player_index < 0 or player_index >= state.players.size():
		return actions

	var player: PlayerState = state.players[player_index]
	actions.append_array(_build_attach_energy_actions(gsm, player_index, player))
	actions.append_array(_build_play_basic_to_bench_actions(gsm, player_index, player))
	actions.append_array(_build_evolve_actions(gsm, player_index, player))
	actions.append_array(_build_play_trainer_actions(gsm, player_index, player))
	actions.append_array(_build_play_stadium_actions(gsm, player_index, player))
	actions.append_array(_build_use_ability_actions(gsm, player_index, player))
	actions.append_array(_build_retreat_actions(gsm, player_index, player))
	actions.append_array(_build_attack_actions(gsm, player_index, player))
	actions.append({"kind": "end_turn"})
	return actions


func _build_attach_energy_actions(gsm: GameStateMachine, player_index: int, player: PlayerState) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if not gsm.rule_validator.can_attach_energy(gsm.game_state, player_index):
		return actions
	var slots: Array[PokemonSlot] = _get_player_slots(player)
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null or not card.card_data.is_energy():
			continue
		for target_slot: PokemonSlot in slots:
			actions.append({
				"kind": "attach_energy",
				"card": card,
				"target_slot": target_slot,
			})
	return actions


func _build_play_basic_to_bench_actions(gsm: GameStateMachine, player_index: int, player: PlayerState) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		if not gsm.rule_validator.can_play_basic_to_bench(gsm.game_state, player_index, card):
			continue
		actions.append({
			"kind": "play_basic_to_bench",
			"card": card,
		})
	return actions


func _build_evolve_actions(gsm: GameStateMachine, player_index: int, player: PlayerState) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var slots: Array[PokemonSlot] = _get_player_slots(player)
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null or not card.card_data.is_pokemon():
			continue
		for target_slot: PokemonSlot in slots:
			if not gsm.rule_validator.can_evolve(gsm.game_state, player_index, target_slot, card):
				continue
			actions.append({
				"kind": "evolve",
				"card": card,
				"target_slot": target_slot,
			})
	return actions


func _build_play_trainer_actions(gsm: GameStateMachine, player_index: int, player: PlayerState) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	for card: CardInstance in player.hand:
		if not _can_play_trainer_immediately(gsm, player_index, card):
			continue
		actions.append({
			"kind": "play_trainer",
			"card": card,
			"targets": [],
		})
	return actions


func _build_play_stadium_actions(gsm: GameStateMachine, player_index: int, player: PlayerState) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null or card.card_data.card_type != "Stadium":
			continue
		if not gsm.rule_validator.can_play_stadium(gsm.game_state, player_index, card):
			continue
		var effect: BaseEffect = gsm.effect_processor.get_effect(card.card_data.effect_id)
		if effect != null and not effect.get_on_play_interaction_steps(card, gsm.game_state).is_empty():
			continue
		actions.append({
			"kind": "play_stadium",
			"card": card,
			"targets": [],
		})
	return actions


func _build_use_ability_actions(gsm: GameStateMachine, player_index: int, player: PlayerState) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	for slot: PokemonSlot in _get_player_slots(player):
		actions.append_array(_build_slot_ability_actions(gsm, player_index, slot))
	return actions


func _build_slot_ability_actions(gsm: GameStateMachine, player_index: int, slot: PokemonSlot) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if slot == null or slot.get_top_card() == null:
		return actions
	var state: GameState = gsm.game_state
	var card_data: CardData = slot.get_card_data()
	for ability_index: int in card_data.abilities.size():
		if not gsm.effect_processor.can_use_ability(slot, state, ability_index):
			continue
		var source_card: CardInstance = gsm.effect_processor.get_ability_source_card(slot, ability_index, state)
		var effect: BaseEffect = gsm.effect_processor.get_ability_effect(slot, ability_index, state)
		if source_card == null or effect == null:
			continue
		if not effect.get_interaction_steps(source_card, state).is_empty():
			continue
		actions.append({
			"kind": "use_ability",
			"source_slot": slot,
			"ability_index": ability_index,
			"targets": [],
		})
	for granted: Dictionary in gsm.effect_processor.get_granted_abilities(slot, state):
		var ability_index: int = int(granted.get("ability_index", -1))
		if ability_index < 0 or not gsm.effect_processor.can_use_ability(slot, state, ability_index):
			continue
		var source_card: CardInstance = gsm.effect_processor.get_ability_source_card(slot, ability_index, state)
		var effect: BaseEffect = gsm.effect_processor.get_ability_effect(slot, ability_index, state)
		if source_card == null or effect == null:
			continue
		if not effect.get_interaction_steps(source_card, state).is_empty():
			continue
		actions.append({
			"kind": "use_ability",
			"source_slot": slot,
			"ability_index": ability_index,
			"targets": [],
		})
	return actions


func _build_retreat_actions(gsm: GameStateMachine, player_index: int, player: PlayerState) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if not gsm.rule_validator.can_retreat(gsm.game_state, player_index):
		return actions
	var active: PokemonSlot = player.active_pokemon
	if active == null:
		return actions
	var cost: int = gsm.effect_processor.get_effective_retreat_cost(active, gsm.game_state)
	var discards: Array[Array] = _get_minimal_retreat_discards(gsm, active, cost)
	for bench_slot: PokemonSlot in player.bench:
		for discard_variant: Array in discards:
			var discard_cards: Array[CardInstance] = []
			for energy: Variant in discard_variant:
				if energy is CardInstance:
					discard_cards.append(energy)
			actions.append({
				"kind": "retreat",
				"bench_target": bench_slot,
				"energy_to_discard": discard_cards,
			})
	return actions


func _build_attack_actions(gsm: GameStateMachine, player_index: int, player: PlayerState) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var active: PokemonSlot = player.active_pokemon
	if active == null or active.get_top_card() == null:
		return actions
	var attacks: Array = active.get_card_data().attacks
	for attack_index: int in attacks.size():
		if not gsm.can_use_attack(player_index, attack_index):
			continue
		if not _get_attack_interaction_steps(gsm, active, attack_index).is_empty():
			continue
		actions.append({
			"kind": "attack",
			"attack_index": attack_index,
			"targets": [],
		})
	return actions


func _get_player_slots(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for bench_slot: PokemonSlot in player.bench:
		if bench_slot != null:
			slots.append(bench_slot)
	return slots


func _can_play_trainer_immediately(gsm: GameStateMachine, player_index: int, card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	if card.card_data.card_type != "Item" and card.card_data.card_type != "Supporter":
		return false
	if card.card_data.card_type == "Supporter":
		if not gsm.rule_validator.can_play_supporter(gsm.game_state, player_index) and not gsm._can_play_supporter_exception(player_index, card):
			return false
	if not card in gsm.game_state.players[player_index].hand:
		return false
	var effect: BaseEffect = gsm.effect_processor.get_effect(card.card_data.effect_id)
	if effect == null:
		return true
	if not effect.can_execute(card, gsm.game_state):
		return false
	return effect.get_interaction_steps(card, gsm.game_state).is_empty()


func _get_minimal_retreat_discards(gsm: GameStateMachine, active: PokemonSlot, retreat_cost: int) -> Array[Array]:
	if retreat_cost <= 0:
		return [[]]
	var legal_discards: Array[Array] = []
	var attached_energy: Array[CardInstance] = active.attached_energy
	var subsets: Array[Array] = []
	_collect_energy_subsets(attached_energy, 0, [], subsets)
	var min_size: int = 999999
	for subset_variant: Array in subsets:
		var subset: Array[CardInstance] = []
		for energy: Variant in subset_variant:
			if energy is CardInstance:
				subset.append(energy)
		if subset.is_empty():
			continue
		if not gsm.rule_validator.has_enough_energy_to_retreat(active, subset, retreat_cost, gsm.effect_processor, gsm.game_state):
			continue
		if subset.size() < min_size:
			min_size = subset.size()
			legal_discards.clear()
		if subset.size() == min_size and not _contains_energy_subset(legal_discards, subset):
			legal_discards.append(subset)
	return legal_discards


func _collect_energy_subsets(
	energy_cards: Array[CardInstance],
	index: int,
	current: Array[CardInstance],
	results: Array[Array]
) -> void:
	if index >= energy_cards.size():
		results.append(current.duplicate())
		return
	_collect_energy_subsets(energy_cards, index + 1, current, results)
	current.append(energy_cards[index])
	_collect_energy_subsets(energy_cards, index + 1, current, results)
	current.pop_back()


func _contains_energy_subset(existing: Array[Array], candidate: Array[CardInstance]) -> bool:
	var candidate_ids: PackedInt32Array = _to_instance_id_array(candidate)
	for subset_variant: Array in existing:
		var subset: Array[CardInstance] = []
		for energy: Variant in subset_variant:
			if energy is CardInstance:
				subset.append(energy)
		if _to_instance_id_array(subset) == candidate_ids:
			return true
	return false


func _to_instance_id_array(cards: Array[CardInstance]) -> PackedInt32Array:
	var ids := PackedInt32Array()
	for card: CardInstance in cards:
		ids.append(card.instance_id)
	return ids


func _get_attack_interaction_steps(gsm: GameStateMachine, slot: PokemonSlot, attack_index: int) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	if slot == null or slot.get_top_card() == null:
		return steps
	var card: CardInstance = slot.get_top_card()
	var attacks: Array = card.card_data.attacks
	if attack_index < 0 or attack_index >= attacks.size():
		return steps
	var attack: Dictionary = attacks[attack_index]
	for effect: BaseEffect in gsm.effect_processor.get_attack_effects_for_slot(slot, attack_index):
		steps.append_array(effect.get_attack_interaction_steps(card, attack, gsm.game_state))
	return steps
