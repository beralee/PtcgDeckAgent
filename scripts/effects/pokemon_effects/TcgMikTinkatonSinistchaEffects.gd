extends RefCounted


class AttackOwnHandCountDamage extends BaseEffect:
	var damage_per_card: int = 30
	var printed_base_damage: int = 30
	var attack_index_to_match: int = -1

	func _init(per_card: int = 30, printed_damage: int = 30, match_attack_index: int = -1) -> void:
		damage_per_card = maxi(0, per_card)
		printed_base_damage = maxi(0, printed_damage)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or attacker.get_top_card() == null or state == null:
			return -printed_base_damage
		var owner := attacker.get_top_card().owner_index
		if owner < 0 or owner >= state.players.size():
			return -printed_base_damage
		return state.players[owner].hand.size() * damage_per_card - printed_base_damage

	func get_description() -> String:
		return "This attack does %d damage for each card in your hand." % damage_per_card


class AbilityMaterialGathering extends BaseEffect:
	const STEP_ID := "tinkaton_material_gathering_discard"
	var draw_count: int = 3

	func _init(count: int = 3) -> void:
		draw_count = maxi(0, count)

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		var owner := pokemon.get_top_card().owner_index
		return (
			owner >= 0
			and owner < state.players.size()
			and state.current_player_index == owner
			and not pokemon.has_ability_used(state.turn_number)
			and not state.players[owner].hand.is_empty()
		)

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or card.owner_index < 0 or card.owner_index >= state.players.size():
			return []
		var items: Array = state.players[card.owner_index].hand.duplicate()
		if items.is_empty():
			return []
		var labels: Array[String] = []
		for hand_card: CardInstance in items:
			labels.append(hand_card.card_data.name if hand_card != null and hand_card.card_data != null else "Unknown card")
		return [{
			"id": STEP_ID,
			"title": "Choose 1 card from your hand to discard",
			"items": items,
			"labels": labels,
			"presentation": "cards",
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
			"force_confirm": true,
		}]

	func validate_ability_interaction(
		pokemon: PokemonSlot,
		_ability_index: int,
		targets: Array,
		state: GameState
	) -> Dictionary:
		if not can_use_ability(pokemon, state):
			return interaction_validation_error("Material Gathering is not available")
		var owner := pokemon.get_top_card().owner_index
		return validate_context_selection(
			get_interaction_context(targets),
			STEP_ID,
			state.players[owner].hand,
			1,
			1,
		)

	func execute_ability(
		pokemon: PokemonSlot,
		_ability_index: int,
		targets: Array,
		state: GameState
	) -> void:
		if not can_use_ability(pokemon, state):
			return
		var top := pokemon.get_top_card()
		var player := state.players[top.owner_index]
		var selected_raw: Array = get_interaction_context(targets).get(STEP_ID, [])
		if selected_raw.size() != 1 or not (selected_raw[0] is CardInstance):
			return
		var selected := selected_raw[0] as CardInstance
		if selected not in player.hand:
			return
		var discarded := _discard_cards_from_hand_with_log(state, top.owner_index, [selected], top, "ability")
		if discarded.size() != 1:
			return
		_draw_cards_with_log(state, top.owner_index, draw_count, top, "ability")
		pokemon.mark_ability_used(state.turn_number)

	func get_description() -> String:
		return "Once during your turn, discard 1 card from your hand. Then, draw %d cards." % draw_count


class AttackEnergyPresentBonus extends BaseEffect:
	var energy_filter: String = ""
	var bonus_damage: int = 0
	var attack_index_to_match: int = -1

	func _init(filter: String = "", bonus: int = 0, match_attack_index: int = -1) -> void:
		energy_filter = filter
		bonus_damage = maxi(0, bonus)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		return bonus_damage if _has_matching_energy(attacker, state) else 0

	func _has_matching_energy(attacker: PokemonSlot, state: GameState) -> bool:
		if attacker == null:
			return false
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null) if state != null else null
		for energy: CardInstance in attacker.attached_energy:
			if energy == null or energy.card_data == null:
				continue
			if energy_filter == "Special Energy":
				if energy.card_data.card_type != "Special Energy":
					continue
				if processor != null and processor.has_method("is_special_energy_suppressed"):
					if bool(processor.call("is_special_energy_suppressed", energy, state)):
						continue
				return true
			if processor != null and processor.has_method("get_energy_types"):
				if energy_filter in PackedStringArray(processor.call("get_energy_types", energy, state)):
					return true
				continue
			var provided := energy.card_data.energy_provides
			if provided == "":
				provided = energy.card_data.energy_type
			if provided == energy_filter or provided == "ANY":
				return true
		return false

	func get_description() -> String:
		return "If this Pokemon has matching Energy attached, this attack does %d more damage." % bonus_damage


class AttackSeekingMountain extends BaseEffect:
	const STEP_ID := "tinkatink_seeking_mountain_choice"
	const KEEP_CHOICE := "put_in_hand"
	const DISCARD_DRAW_CHOICE := "discard_draw"
	var attack_index_to_match: int = -1

	func _init(match_attack_index: int = -1) -> void:
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var player := state.players[card.owner_index]
		if player.deck.is_empty():
			return []
		var top_card := player.deck[0]
		var top_name := top_card.card_data.name if top_card != null and top_card.card_data != null else "Unknown card"
		return [{
			"id": STEP_ID,
			"title": "Top card: %s" % top_name,
			"items": [KEEP_CHOICE, DISCARD_DRAW_CHOICE],
			"labels": ["Put it into your hand", "Discard it, then draw 1 card"],
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": false,
			"force_confirm": true,
		}]

	func validate_attack_interaction(
		attacker: PokemonSlot,
		attack_index: int,
		targets: Array,
		state: GameState
	) -> Dictionary:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return interaction_validation_error("Seeking Mountain is not available")
		var player := state.players[attacker.get_top_card().owner_index]
		if player.deck.is_empty():
			return interaction_validation_ok()
		return validate_context_selection(
			get_interaction_context(targets),
			STEP_ID,
			[KEEP_CHOICE, DISCARD_DRAW_CHOICE],
			1,
			1,
		)

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var top := attacker.get_top_card()
		var player := state.players[top.owner_index]
		if player.deck.is_empty():
			return
		var selected: Array = get_attack_interaction_context().get(STEP_ID, [])
		if selected.size() != 1:
			return
		var looked_at: CardInstance = player.deck.pop_front()
		if str(selected[0]) == KEEP_CHOICE:
			looked_at.face_up = true
			player.hand.append(looked_at)
		elif str(selected[0]) == DISCARD_DRAW_CHOICE:
			player.discard_card(looked_at)
			_draw_cards_with_log(state, top.owner_index, 1, top, "attack")
		else:
			player.deck.push_front(looked_at)

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		if card == null or card.card_data == null:
			return -1
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AttackDistributeOpponentDamageCounters extends BaseEffect:
	const STEP_ID := "sinistcha_curse_droplets_counters"
	var total_counters: int = 4
	var attack_index_to_match: int = -1

	func _init(count: int = 4, match_attack_index: int = -1) -> void:
		total_counters = maxi(0, count)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var targets: Array = state.players[1 - card.owner_index].get_all_pokemon()
		if targets.is_empty():
			return []
		var labels: Array[String] = []
		for target: PokemonSlot in targets:
			labels.append(target.get_pokemon_name())
		return [{
			"id": STEP_ID,
			"title": "Distribute %d damage counters among your opponent's Pokemon" % total_counters,
			"ui_mode": "counter_distribution",
			"total_counters": total_counters,
			"target_items": targets,
			"target_labels": labels,
			"min_select": total_counters,
			"max_select": total_counters,
			"allow_cancel": false,
		}]

	func validate_attack_interaction(
		attacker: PokemonSlot,
		attack_index: int,
		targets: Array,
		state: GameState
	) -> Dictionary:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return interaction_validation_error("Curse Droplets is not available")
		var legal: Array = state.players[1 - attacker.get_top_card().owner_index].get_all_pokemon()
		if legal.is_empty():
			return interaction_validation_ok()
		var context := get_interaction_context(targets)
		if not context.has(STEP_ID) or not (context.get(STEP_ID) is Array):
			return interaction_validation_error("missing interaction step: %s" % STEP_ID)
		var assigned := 0
		for entry: Variant in context.get(STEP_ID, []):
			if not (entry is Dictionary):
				return interaction_validation_error("Curse Droplets contains an invalid assignment")
			var target: Variant = (entry as Dictionary).get("target", null)
			var amount := int((entry as Dictionary).get("amount", 0))
			if not (target is PokemonSlot) or target not in legal:
				return interaction_validation_error("Curse Droplets contains an illegal target")
			if amount <= 0 or amount % 10 != 0:
				return interaction_validation_error("Curse Droplets assignments must use 10-damage increments")
			assigned += amount / 10
		if assigned != total_counters:
			return interaction_validation_error("Curse Droplets must distribute exactly %d counters" % total_counters)
		return interaction_validation_ok()

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		var legal: Array = opponent.get_all_pokemon()
		for entry: Variant in get_attack_interaction_context().get(STEP_ID, []):
			if not (entry is Dictionary):
				continue
			var target: Variant = (entry as Dictionary).get("target", null)
			var amount := int((entry as Dictionary).get("amount", 0))
			if target is PokemonSlot and target in legal and amount > 0 and not _effect_is_prevented(attacker, target, opponent, state):
				(target as PokemonSlot).damage_counters += amount
				_mark_attack_damage_counter_placement(target as PokemonSlot, state)

	func _effect_is_prevented(attacker: PokemonSlot, target: PokemonSlot, opponent: PlayerState, state: GameState) -> bool:
		if target in opponent.bench and AbilityBenchImmune.prevents_opponent_attack_effect(target, attacker, state):
			return true
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		return (
			processor != null
			and processor.has_method("is_attack_effect_prevented_by_defender_ability")
			and bool(processor.call("is_attack_effect_prevented_by_defender_ability", attacker, target, state))
		)

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		if card == null or card.card_data == null:
			return -1
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AttackDiscardGrassEnergyFromFieldDamage extends BaseEffect:
	const STEP_ID := "sinistcha_tea_splash_grass_energy"
	var max_discard: int = 3
	var damage_per_energy: int = 70
	var printed_base_damage: int = 70
	var attack_index_to_match: int = -1

	func _init(max_count: int = 3, per_energy: int = 70, printed_damage: int = 70, match_attack_index: int = -1) -> void:
		max_discard = maxi(0, max_count)
		damage_per_energy = maxi(0, per_energy)
		printed_base_damage = maxi(0, printed_damage)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var player := state.players[card.owner_index]
		var items := _grass_energy_on_field(player, state)
		if items.is_empty():
			return []
		var labels: Array[String] = []
		for energy: CardInstance in items:
			labels.append(_energy_source_label(player, energy))
		return [{
			"id": STEP_ID,
			"title": "Choose up to %d Grass Energy from your Pokemon to discard" % max_discard,
			"items": items,
			"labels": labels,
			"presentation": "cards",
			"min_select": 0,
			"max_select": mini(max_discard, items.size()),
			"allow_cancel": true,
			"force_confirm": true,
			"transparent_battlefield_dialog": true,
		}]

	func validate_attack_interaction(
		attacker: PokemonSlot,
		attack_index: int,
		targets: Array,
		state: GameState
	) -> Dictionary:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return interaction_validation_error("Tea Splash is not available")
		var legal := _grass_energy_on_field(state.players[attacker.get_top_card().owner_index], state)
		if legal.is_empty():
			return interaction_validation_ok()
		var context := get_interaction_context(targets)
		if not context.has(STEP_ID):
			return interaction_validation_error("missing interaction step: %s" % STEP_ID)
		return validate_context_selection(context, STEP_ID, legal, 0, mini(max_discard, legal.size()))

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or attacker.get_top_card() == null or state == null:
			return -printed_base_damage
		var legal := _grass_energy_on_field(state.players[attacker.get_top_card().owner_index], state)
		var selected := _selected_energy(legal)
		return selected.size() * damage_per_energy - printed_base_damage

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var player := state.players[attacker.get_top_card().owner_index]
		var selected := _selected_energy(_grass_energy_on_field(player, state))
		for energy: CardInstance in selected:
			for slot: PokemonSlot in player.get_all_pokemon():
				if energy in slot.attached_energy:
					slot.attached_energy.erase(energy)
					player.discard_card(energy)
					break

	func _selected_energy(legal: Array[CardInstance]) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for entry: Variant in get_attack_interaction_context().get(STEP_ID, []):
			if entry is CardInstance and entry in legal and entry not in result and result.size() < max_discard:
				result.append(entry)
		return result

	func _grass_energy_on_field(player: PlayerState, state: GameState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		if player == null:
			return result
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null) if state != null else null
		for slot: PokemonSlot in player.get_all_pokemon():
			for energy: CardInstance in slot.attached_energy:
				if energy == null or energy.card_data == null:
					continue
				if processor != null and processor.has_method("get_energy_types"):
					if "G" in PackedStringArray(processor.call("get_energy_types", energy, state)):
						result.append(energy)
					continue
				var provided := energy.card_data.energy_provides
				if provided == "":
					provided = energy.card_data.energy_type
				if provided == "G" or provided == "ANY":
					result.append(energy)
		return result

	func _energy_source_label(player: PlayerState, energy: CardInstance) -> String:
		for slot: PokemonSlot in player.get_all_pokemon():
			if energy in slot.attached_energy:
				return "%s (%s)" % [energy.card_data.name, slot.get_pokemon_name()]
		return energy.card_data.name if energy != null and energy.card_data != null else "Energy"

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		if card == null or card.card_data == null:
			return -1
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AttackRebrewBasicGrassEnergy extends BaseEffect:
	const STEP_ID := "sinistcha_ex_rebrew_target"
	var counters_per_energy: int = 2
	var attack_index_to_match: int = -1

	func _init(per_energy: int = 2, match_attack_index: int = -1) -> void:
		counters_per_energy = maxi(0, per_energy)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		if _basic_grass_energy(state.players[card.owner_index]).is_empty():
			return []
		var targets: Array = state.players[1 - card.owner_index].get_all_pokemon()
		if targets.is_empty():
			return []
		var labels: Array[String] = []
		for target: PokemonSlot in targets:
			labels.append(target.get_pokemon_name())
		return [{
			"id": STEP_ID,
			"title": "Choose 1 of your opponent's Pokemon",
			"items": targets,
			"labels": labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": false,
		}]

	func validate_attack_interaction(
		attacker: PokemonSlot,
		attack_index: int,
		targets: Array,
		state: GameState
	) -> Dictionary:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return interaction_validation_error("Rebrew is not available")
		var owner := attacker.get_top_card().owner_index
		if _basic_grass_energy(state.players[owner]).is_empty():
			return interaction_validation_ok()
		var legal: Array = state.players[1 - owner].get_all_pokemon()
		return validate_context_selection(get_interaction_context(targets), STEP_ID, legal, 1, 1)

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var owner := attacker.get_top_card().owner_index
		var player := state.players[owner]
		var opponent := state.players[1 - owner]
		var energy_cards := _basic_grass_energy(player)
		if energy_cards.is_empty():
			return
		var selected: Array = get_attack_interaction_context().get(STEP_ID, [])
		var target: PokemonSlot = selected[0] as PokemonSlot if selected.size() == 1 and selected[0] is PokemonSlot and selected[0] in opponent.get_all_pokemon() else null
		if target != null and not _effect_is_prevented(attacker, target, opponent, state):
			target.damage_counters += energy_cards.size() * counters_per_energy * 10
			_mark_attack_damage_counter_placement(target, state)
		for energy: CardInstance in energy_cards:
			player.discard_pile.erase(energy)
			energy.face_up = false
			player.deck.append(energy)
		player.shuffle_deck()

	func _basic_grass_energy(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		if player == null:
			return result
		for energy: CardInstance in player.discard_pile:
			if energy == null or energy.card_data == null or energy.card_data.card_type != "Basic Energy":
				continue
			var provided := energy.card_data.energy_provides
			if provided == "":
				provided = energy.card_data.energy_type
			if provided == "G":
				result.append(energy)
		return result

	func _effect_is_prevented(attacker: PokemonSlot, target: PokemonSlot, opponent: PlayerState, state: GameState) -> bool:
		if target in opponent.bench and AbilityBenchImmune.prevents_opponent_attack_effect(target, attacker, state):
			return true
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		return (
			processor != null
			and processor.has_method("is_attack_effect_prevented_by_defender_ability")
			and bool(processor.call("is_attack_effect_prevented_by_defender_ability", attacker, target, state))
		)

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		if card == null or card.card_data == null:
			return -1
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AttackHealAllOwnPokemon extends BaseEffect:
	var heal_amount: int = 30
	var attack_index_to_match: int = -1

	func _init(amount: int = 30, match_attack_index: int = -1) -> void:
		heal_amount = maxi(0, amount)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		for slot: PokemonSlot in state.players[attacker.get_top_card().owner_index].get_all_pokemon():
			if slot != null:
				slot.damage_counters = maxi(0, slot.damage_counters - heal_amount)

	func get_description() -> String:
		return "Heal %d damage from each of your Pokemon." % heal_amount
