extends RefCounted


class AttackDrifloonReturn extends CSV9CEffects.AttackReturnSelfToDeck:
	func _init() -> void:
		super(0)

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if state.players[card.owner_index].bench.is_empty():
			return [{"id": "drifloon_return_alone", "title": "是否回到牌库？场上没有其他宝可梦会败北。", "items": [true, false], "labels": ["回到牌库", "留在场上"], "min_select": 1, "max_select": 1, "allow_cancel": false, "ucis_context_name": "ACTIVATE"}]
		return super.build_ucis_attack_interaction_steps_spec_steps(card, attack, state)

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		var player := state.players[attacker.get_top_card().owner_index]
		if not player.bench.is_empty():
			super.execute_attack(attacker, defender, index, state)
			return
		if get_attack_interaction_context().get("drifloon_return_alone", [false]) != [true]:
			return
		var cards := attacker.collect_all_cards()
		BattleFieldTransitionService.remove_active(state, attacker.get_top_card().owner_index, attacker, "attack_return_to_deck")
		attacker.pokemon_stack.clear()
		attacker.attached_energy.clear()
		attacker.attached_tool = null
		for card: CardInstance in cards:
			card.face_up = false
			player.deck.append(card)
		player.shuffle_deck()


class AttackThirtyHPCircle extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		var processor: EffectProcessor = state.shared_turn_flags.get("_draw_effect_processor")
		var count := 0
		for slot: PokemonSlot in state.players[attacker.get_top_card().owner_index].bench:
			if processor.get_effective_max_hp(slot, state) == 30:
				count += 1
		return count * 30 - 30


class AttackGrudgeVortex extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(1)

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index) or defender == null:
			return
		var processor: EffectProcessor = state.shared_turn_flags.get("_draw_effect_processor")
		if processor.is_attack_effect_prevented_by_defender_ability(attacker, defender, state):
			return
		var amount := maxi(0, processor.get_effective_remaining_hp(defender, state) - 50)
		defender.damage_counters += amount
		if amount > 0:
			_mark_attack_damage_counter_placement(defender, state)


class AttackGnawTogether extends BaseEffect:
	var coin_flipper: CoinFlipper
	func _init(flipper: CoinFlipper) -> void:
		coin_flipper = flipper
		bind_default_attack_index(0)

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		var heads := 0
		for slot: PokemonSlot in state.players[attacker.get_top_card().owner_index].get_all_pokemon():
			var names := slot.get_card_data().rule_identity_names()
			if ("一家鼠" in names or "Maushold" in names) and coin_flipper.flip():
				heads += 1
		AttackMillOpponentDeck.new(heads * 2, 0).execute_attack(attacker, _defender, 0, state)


class AttackDiscardEnergyRequirements extends BaseEffect:
	const STEP_ID := "discard_typed_attached_energy_from_self"
	var required: String
	var index_to_match: int
	func _init(symbols: String, index: int) -> void:
		required = symbols
		index_to_match = index

	func applies_to_attack_index(index: int) -> bool:
		return index == index_to_match

	func _plan(cards: Array, state: GameState) -> Dictionary:
		var processor: EffectProcessor = state.shared_turn_flags.get("_draw_effect_processor")
		var units: Array[Dictionary] = []
		var seen: Array[CardInstance] = []
		for card: CardInstance in cards:
			if card in seen:
				continue
			seen.append(card)
			var types := processor.get_energy_types(card, state)
			for i in mini(required.length(), processor.get_energy_colorless_count(card, state)):
				units.append({"card": card, "types": types})
		var assigned: Dictionary = {}
		for i in required.length():
			_bind_unit(i, units, assigned, {})
		var selected: Array[CardInstance] = []
		for key: int in assigned:
			var card: CardInstance = units[key].card
			if card not in selected:
				selected.append(card)
		return {"cards": selected, "units": assigned.size()}

	func _bind_unit(requirement_index: int, units: Array[Dictionary], assigned: Dictionary, visited: Dictionary) -> bool:
		for i in units.size():
			if visited.has(i) or (required[requirement_index] != "C" and required[requirement_index] not in units[i].types and "ANY" not in units[i].types):
				continue
			visited[i] = true
			if not assigned.has(i) or _bind_unit(int(assigned[i]), units, assigned, visited):
				assigned[i] = requirement_index
				return true
		return false

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, _attack: Dictionary, state: GameState) -> Array[Dictionary]:
		return _next_discard_step(card, state, {})

	func build_ucis_followup_attack_interaction_steps_spec_steps(card: CardInstance, _attack: Dictionary, state: GameState, context: Dictionary) -> Array[Dictionary]:
		return _next_discard_step(card, state, context)

	func _selected(context: Dictionary) -> Array:
		var selected: Array = []
		for i in required.length():
			selected.append_array(context.get(STEP_ID if i == 0 else STEP_ID + "_%d" % (i + 1), []))
		return selected

	func _next_discard_step(card: CardInstance, state: GameState, context: Dictionary) -> Array[Dictionary]:
		var source := state.players[card.owner_index].active_pokemon
		var selected := _selected(context)
		var current := int(_plan(selected, state).units)
		if current >= int(_plan(source.attached_energy, state).units):
			return []
		var candidates: Array = []
		for energy: CardInstance in source.attached_energy:
			if energy not in selected and int(_plan(selected + [energy], state).units) > current:
				candidates.append(energy)
		if candidates.is_empty():
			return []
		var step_id := STEP_ID if selected.is_empty() else STEP_ID + "_%d" % (selected.size() + 1)
		return [{"id": step_id, "title": "选择提供所需 %s 能量的附着卡弃置（已选 %d 个能量）" % [required, current], "items": candidates, "min_select": 1, "max_select": 1, "allow_cancel": false, "ucis_context_name": "DISCARD_ENERGY_CARD", "ucis_select_type_name": "ATTACHED_CARD"}]

	func validate_attack_interaction(attacker: PokemonSlot, _index: int, targets: Array, state: GameState) -> Dictionary:
		var context := get_interaction_context(targets)
		if not context.has(STEP_ID):
			return {"valid": true}
		var selected := _selected(context)
		for card: Variant in selected:
			if card not in attacker.attached_energy:
				return interaction_validation_error("Energy is not attached to attacker")
		var needed := int(_plan(attacker.attached_energy, state).units)
		if int(_plan(selected, state).units) != needed or not _can_assign_selected(selected, state, needed):
			return interaction_validation_error("Selected Energy does not provide required units")
		return {"valid": true}

	func _can_assign_selected(selected: Array, state: GameState, needed: int) -> bool:
		if selected.size() > needed:
			return false
		var processor: EffectProcessor = state.shared_turn_flags.get("_draw_effect_processor")
		var specs: Array[Dictionary] = []
		var seen: Array = []
		for card: CardInstance in selected:
			if card in seen:
				return false
			seen.append(card)
			specs.append({"types": processor.get_energy_types(card, state), "count": processor.get_energy_colorless_count(card, state)})
		var used: Array[int] = []
		used.resize(selected.size())
		used.fill(0)
		return _assign_selected(0, specs, used, needed)

	func _assign_selected(index: int, specs: Array[Dictionary], used: Array[int], remaining: int) -> bool:
		if index == required.length():
			return remaining == 0 and not used.has(0)
		if required.length() - index > remaining and _assign_selected(index + 1, specs, used, remaining):
			return true
		for i in specs.size():
			if used[i] >= int(specs[i].count) or (required[index] != "C" and required[index] not in specs[i].types and "ANY" not in specs[i].types):
				continue
			used[i] += 1
			var valid := _assign_selected(index + 1, specs, used, remaining - 1)
			used[i] -= 1
			if valid:
				return true
		return false

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		var context := get_attack_interaction_context()
		var selected: Array = _selected(context) if context.has(STEP_ID) else _plan(attacker.attached_energy, state).cards
		for energy: CardInstance in selected:
			if energy in attacker.attached_energy:
				attacker.attached_energy.erase(energy)
				state.players[attacker.get_top_card().owner_index].discard_card(energy)
				_record_attack_effect_discarded_attached_energy(attacker, energy, state)


class AttackPrankTransform extends AttackCoinSearch:
	func _init(flipper: CoinFlipper) -> void:
		super(flipper)
		card_type_filter = "Pokemon"

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		var original := attacker.get_top_card()
		var key := _key(original, state)
		var heads: bool = bool(pending[key]) if pending.has(key) else coin_flipper.flip()
		pending.erase(key)
		if not heads:
			return
		var player := state.players[original.owner_index]
		for raw: Variant in get_attack_interaction_context().get("search_cards", []):
			if raw is CardInstance and raw in player.deck and raw.card_data.is_pokemon():
				player.deck.erase(raw)
				attacker.pokemon_stack[attacker.pokemon_stack.size() - 1] = raw
				(raw as CardInstance).face_up = true
				original.face_up = false
				player.deck.append(original)
				# This exchange explicitly inherits effects; it is not evolution.
				for marker: Dictionary in attacker.effects:
					if int(marker.get("top_instance_id", -1)) == original.instance_id:
						marker["top_instance_id"] = raw.instance_id
				attacker.mark_top_card_changed()
				break
		player.shuffle_deck()


class AttackBuryItem extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)

	func build_ucis_attack_preview_interaction_steps_spec_steps(_card: CardInstance, _attack: Dictionary, _state: GameState) -> Array[Dictionary]:
		return [{"id": "hand_peek_preview", "title": "查看对手手牌后选择物品", "preview_only": true}]

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, _attack: Dictionary, state: GameState) -> Array[Dictionary]:
		var hand := state.players[1 - card.owner_index].hand
		var legal: Array = hand.filter(func(item: CardInstance) -> bool: return item.card_data.card_type == "Item")
		if hand.is_empty():
			return []
		return [build_full_library_search_step("bury_item", "查看对手手牌，将1张物品放到牌库下方", hand, legal, "opponent_hand_revealed", mini(1, legal.size()), mini(1, legal.size()), {"allow_cancel": false, "allow_hidden_search_whiff": false})]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		var player := state.players[1 - attacker.get_top_card().owner_index]
		for raw: Variant in get_attack_interaction_context().get("bury_item", []):
			if raw is CardInstance and raw in player.hand and raw.card_data.card_type == "Item":
				player.hand.erase(raw)
				(raw as CardInstance).face_up = false
				player.deck.append(raw)
				break


class AbilitySoundSleep extends BaseEffect:
	func process_pokemon_check(source: PokemonSlot, state: GameState, _damaged_slots: Array[PokemonSlot]) -> void:
		# The engine invokes this after the sleep recovery coin has resolved.
		if source == state.players[source.get_top_card().owner_index].active_pokemon and source.status_conditions.asleep:
			source.heal(source.damage_counters, state)


class AttackKnockOff extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)

	func before_attack_damage(attacker: PokemonSlot, defender: PokemonSlot, index: int, state: GameState) -> void:
		var processor: EffectProcessor = state.shared_turn_flags.get("_draw_effect_processor")
		if not applies_to_attack_index(index) or defender == null or processor.is_attack_effect_prevented_by_defender_ability(attacker, defender, state):
			return
		if defender.attached_tool != null:
			state.players[defender.get_top_card().owner_index].discard_card(defender.attached_tool)
			defender.attached_tool = null


class AttackFestivity extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, _attack: Dictionary, state: GameState) -> Array[Dictionary]:
		var player := state.players[card.owner_index]
		if player.hand.size() != 30 or player.prizes.is_empty():
			return []
		var items: Array = range(player.prizes.size())
		var labels: Array[String] = []
		for i: int in items:
			labels.append("奖赏卡 %d" % (i + 1))
		return [{"id": "festivity_prizes", "title": "选择2张奖赏卡（不查看正面）", "items": items, "labels": labels, "visible_scope": "own_prizes_hidden", "min_select": mini(2, items.size()), "max_select": mini(2, items.size()), "allow_cancel": false, "ucis_context_name": "TO_HAND", "ucis_option_type_name": "CARD"}]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		var player := state.players[attacker.get_top_card().owner_index]
		if player.hand.size() == 30:
			var selected: Array[CardInstance] = []
			for raw: Variant in get_attack_interaction_context().get("festivity_prizes", []):
				if (raw is int or raw is float) and int(raw) >= 0 and int(raw) < player.prizes.size() and player.prizes[int(raw)] not in selected:
					selected.append(player.prizes[int(raw)])
					if selected.size() == 2:
						break
			for prize: CardInstance in player.prizes:
				if selected.size() >= mini(2, player.prizes.size()):
					break
				if prize not in selected:
					selected.append(prize)
			for prize: CardInstance in selected:
				player.take_prize_card(prize)
		for card: CardInstance in player.hand:
			card.face_up = false
			player.deck.append(card)
		player.hand.clear()
		player.shuffle_deck()


class AttackTripleSmash extends AttackIronTail:
	func _init(flipper: CoinFlipper) -> void:
		super(flipper)

	func applies_to_attack_index(index: int) -> bool:
		return index == 1

	func cancels_attack_damage(attacker: PokemonSlot, _defender: PokemonSlot, _index: int, state: GameState) -> bool:
		var heads := 0
		for i in 3:
			if coin_flipper.flip():
				heads += 1
		pending[_key(attacker, state)] = heads * 50
		return heads == 0

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		return int(pending.get(_key(attacker, state), 50)) - 50


class AttackRoaringCall extends BaseEffect:
	const BenchLimit = preload("res://scripts/engine/BenchLimitHelper.gd")
	func _init() -> void:
		bind_default_attack_index(0)

	func _candidates(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in player.discard_pile:
			if card.card_data.is_pokemon() and card.card_data.energy_type.contains("N"):
				result.append(card)
		return result

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, _attack: Dictionary, state: GameState) -> Array[Dictionary]:
		var player := state.players[card.owner_index]
		var candidates := _candidates(player)
		var count := mini(3, BenchLimit.get_available_bench_space(state, player))
		if count <= 0 or candidates.is_empty():
			return []
		return [{"id": "revive_from_discard", "title": "选择最多3张龙宝可梦放于备战区", "items": candidates, "min_select": 0, "max_select": mini(count, candidates.size()), "allow_cancel": true}]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		var player := state.players[attacker.get_top_card().owner_index]
		var legal := _candidates(player)
		var count := 0
		for raw: Variant in get_attack_interaction_context().get("revive_from_discard", []):
			if raw not in legal or raw not in player.discard_pile:
				continue
			if count >= 3 or BenchLimit.is_bench_full(state, player):
				break
			player.discard_pile.erase(raw)
			var slot := PokemonSlot.new()
			slot.pokemon_stack.append(raw)
			(raw as CardInstance).face_up = true
			slot.turn_played = state.turn_number
			slot.mark_entered_play()
			player.bench.append(slot)
			count += 1


class AttackScreech extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, index: int, state: GameState) -> void:
		var processor: EffectProcessor = state.shared_turn_flags.get("_draw_effect_processor")
		if applies_to_attack_index(index) and defender != null and not processor.is_attack_effect_prevented_by_defender_ability(attacker, defender, state):
			defender.effects.append({"type": "sweet_trap_damage_bonus", "turn": state.turn_number, "amount": 30, "source_player_index": attacker.get_top_card().owner_index})


class AttackWishComeTrue extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, index: int, state: GameState) -> void:
		if applies_to_attack_index(index):
			var owner := attacker.get_top_card().owner_index
			_draw_cards_with_log(state, owner, maxi(0, 7 - state.players[owner].hand.size()), attacker.get_top_card(), "attack")


class AttackReverseClock extends EffectSuperRod:
	func _init() -> void:
		bind_default_attack_index(0)

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, _attack: Dictionary, state: GameState) -> Array[Dictionary]:
		return build_ucis_interaction_steps_spec_steps(card, state)

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, index: int, state: GameState) -> void:
		if applies_to_attack_index(index):
			execute(attacker.get_top_card(), [get_attack_interaction_context()], state)


class AttackExplosiveNeedles extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(1)

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		for target: PokemonSlot in state.players[1 - attacker.get_top_card().owner_index].get_all_pokemon():
			load("res://scripts/effects/ThirtiethCelebrationEffects.gd").deal_target_damage(attacker, target, 50, state, get_attack_interaction_context())


class AbilitySunrise extends AbilityAttachFromDeck:
	func _init() -> void:
		super("M", 2, "self", false, true)

	func can_use_ability(source: PokemonSlot, state: GameState) -> bool:
		if source == null or state == null or source.get_top_card() == null or state.current_player_index != source.get_top_card().owner_index:
			return false
		var player := state.players[source.get_top_card().owner_index]
		if source not in player.bench or player.deck.is_empty():
			return false
		return not source.effects.any(func(marker: Dictionary) -> bool: return marker.get("type") == USED_KEY and marker.get("turn") == state.turn_number)

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var steps := super.build_ucis_interaction_steps_spec_steps(card, state)
		if steps.is_empty() and not state.players[card.owner_index].deck.is_empty():
			return [build_empty_search_resolution_step("日出：没有基本钢能量，可查看牌库后重洗。")]
		return steps

	func build_ucis_followup_interaction_steps_spec_steps(card: CardInstance, state: GameState, context: Dictionary) -> Array[Dictionary]:
		if should_preview_empty_search_deck(context):
			return [build_readonly_deck_preview_step("日出：查看牌库", state.players[card.owner_index].deck)]
		return []

	func execute_ability(source: PokemonSlot, index: int, targets: Array, state: GameState) -> void:
		if not can_use_ability(source, state):
			return
		super.execute_ability(source, index, targets, state)
		if can_use_ability(source, state):
			_mark_usage(source, state)
		# Searching zero cards still requires shuffling.
		if get_interaction_context(targets).get(ASSIGNMENT_STEP_ID, []).is_empty():
			state.players[source.get_top_card().owner_index].shuffle_deck()


class AttackToolBonus extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)

	func get_damage_bonus(attacker: PokemonSlot, _state: GameState) -> int:
		return 40 if attacker.attached_tool != null else 0


class AbilityLifeConstraint extends BaseEffect:
	func prevents_healing(source: PokemonSlot, target: PokemonSlot, state: GameState) -> bool:
		return target == state.players[1 - source.get_top_card().owner_index].active_pokemon


class AbilityDeathSentence extends BaseEffect:
	var coin_flipper: CoinFlipper
	func _init(flipper: CoinFlipper) -> void:
		coin_flipper = flipper

	func on_knocked_out_by_attack_damage(source: PokemonSlot, attacker: PokemonSlot, state: GameState) -> void:
		if source.get_top_card().owner_index != attacker.get_top_card().owner_index and coin_flipper.flip():
			var processor: EffectProcessor = state.shared_turn_flags.get("_draw_effect_processor")
			attacker.damage_counters = maxi(attacker.damage_counters, processor.get_effective_max_hp(attacker, state))


class AttackDamageKORevenge extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		var key := "attack_damage_knockout_names:%d:%d" % [attacker.get_top_card().owner_index, state.turn_number - 1]
		return 100 if not (state.shared_turn_flags.get(key, []) as Array).is_empty() else 0


class AttackOpponentShuffleDrawFour extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		var owner := 1 - attacker.get_top_card().owner_index
		var player := state.players[owner]
		for card: CardInstance in player.hand:
			card.face_up = false
			player.deck.append(card)
		player.hand.clear()
		player.shuffle_deck()
		_draw_cards_with_log(state, owner, 4, attacker.get_top_card(), "attack")


class AttackHandSizeDamage extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(1)

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		return state.players[attacker.get_top_card().owner_index].hand.size() * 10 - 10


class AttackCounterDamage extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		var received: Dictionary = state.shared_turn_flags.get("attack_damage_received:%d" % attacker.get_top_card().instance_id, {})
		return int(received.get("damage", 0)) if int(received.get("turn", -2)) == state.turn_number - 1 else 0


class AbilityShareHappiness extends BaseEffect:
	func can_use_ability(source: PokemonSlot, state: GameState) -> bool:
		if source == null or state == null or source.get_top_card() == null:
			return false
		return state.current_player_index == source.get_top_card().owner_index and not source.has_ability_used(state.turn_number) and not _targets(source.get_top_card(), state).is_empty()

	func _targets(card: CardInstance, state: GameState) -> Array[PokemonSlot]:
		var result: Array[PokemonSlot] = []
		for slot: PokemonSlot in state.players[card.owner_index].get_all_pokemon():
			if slot.damage_counters > 0:
				result.append(slot)
		return result

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var candidates := _targets(card, state)
		if candidates.is_empty():
			return []
		return [{"id": "heal_target", "title": "选择1只己方宝可梦回复30HP", "items": candidates, "min_select": 1, "max_select": 1, "allow_cancel": false}]

	func execute_ability(source: PokemonSlot, _index: int, targets: Array, state: GameState) -> void:
		if not can_use_ability(source, state):
			return
		var context := get_interaction_context(targets)
		var chosen: Array = context.get("heal_target", [])
		var candidates := _targets(source.get_top_card(), state)
		if chosen.size() == 1 and chosen[0] in candidates:
			(chosen[0] as PokemonSlot).heal(30, state)
			source.mark_ability_used(state.turn_number)


class AttackVibrationPunch extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, index: int, state: GameState) -> void:
		if applies_to_attack_index(index):
			state.shared_turn_flags["trainer_disruption:%d" % (1 - attacker.get_top_card().owner_index)] = state.turn_number + 1


class AttackOwnBenchWave extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		for target: PokemonSlot in state.players[attacker.get_top_card().owner_index].bench:
			# Tera's printed Bench rule prevents all attack damage, including own attacks.
			if not target.get_card_data().is_tera_pokemon():
				DamageCalculator.new().apply_damage_to_slot(target, 20)


class AttackCoinSearch extends AttackSearchDeckToHand:
	var coin_flipper: CoinFlipper
	var pending: Dictionary = {}
	func _init(flipper: CoinFlipper) -> void:
		super(1, "", 0)
		coin_flipper = flipper

	func _key(card: CardInstance, state: GameState) -> String:
		return "%d:%d:%d" % [state.get_instance_id(), state.turn_number, card.owner_index]

	func build_ucis_attack_preview_interaction_steps_spec_steps(_card: CardInstance, _attack: Dictionary, _state: GameState) -> Array[Dictionary]:
		return [{"id": "coin_preview", "title": "投掷1枚硬币", "preview_only": true, "wait_for_coin_animation": true}]

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		var key := _key(card, state)
		if not pending.has(key):
			pending[key] = coin_flipper.flip()
		if not bool(pending[key]):
			return []
		return super.build_ucis_attack_interaction_steps_spec_steps(card, attack, state)

	func build_ucis_followup_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState, context: Dictionary) -> Array[Dictionary]:
		if not bool(pending.get(_key(card, state), false)):
			return []
		return super.build_ucis_followup_attack_interaction_steps_spec_steps(card, attack, state, context)

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		var key := _key(attacker.get_top_card(), state)
		var heads: bool = bool(pending[key]) if pending.has(key) else coin_flipper.flip()
		pending.erase(key)
		if heads:
			super.execute_attack(attacker, defender, index, state)


class AttackPsychic extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		var target := state.players[1 - attacker.get_top_card().owner_index].active_pokemon
		var processor: EffectProcessor = state.shared_turn_flags.get("_draw_effect_processor")
		var units := 0
		if target != null:
			for energy: CardInstance in target.attached_energy:
				units += processor.get_energy_colorless_count(energy, state)
		return units * 40


class AttackMiracleBeam extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		var processor: EffectProcessor = state.shared_turn_flags.get("_draw_effect_processor")
		for slot: PokemonSlot in opponent.get_all_pokemon():
			if slot.pokemon_stack.size() <= 1 or processor.is_attack_effect_prevented_by_defender_ability(attacker, slot, state) or AbilityBenchImmune.prevents_opponent_attack_effect(slot, attacker, state):
				continue
			var removed: CardInstance = slot.pokemon_stack.pop_back()
			slot.mark_top_card_changed()
			slot.clear_all_status()
			slot.effects.clear()
			removed.face_up = false
			opponent.hand.append(removed)


class AttackColorfulHarmony extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		var types: Dictionary = {}
		for slot: PokemonSlot in state.players[attacker.get_top_card().owner_index].get_all_pokemon():
			for energy: CardInstance in slot.attached_energy:
				if energy.card_data.card_type == "Basic Energy":
					types[energy.card_data.energy_provides] = true
		return types.size() * 50 - 50


class AttackPickSnack extends BaseEffect:
	const STEP_ID := "pick_snack"
	func _init() -> void:
		bind_default_attack_index(0)

	func build_ucis_attack_preview_interaction_steps_spec_steps(_card: CardInstance, _attack: Dictionary, _state: GameState) -> Array[Dictionary]:
		return [{"id": "snack_preview", "title": "弃置牌库顶3张并回收其中1张", "preview_only": true, "min_select": 0, "max_select": 0}]

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, _attack: Dictionary, state: GameState) -> Array[Dictionary]:
		var viewed: Array = state.players[card.owner_index].deck.slice(0, 3)
		var legal: Array = DiscardPileRestriction.filter_cards(viewed)
		if viewed.is_empty():
			return []
		return [build_full_library_search_step(STEP_ID, "查看牌库顶3张，选择其中1张加入手牌", viewed, legal, "own_deck_top", mini(1, legal.size()), mini(1, legal.size()), {"allow_cancel": false, "allow_hidden_search_whiff": false})]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		var owner := attacker.get_top_card().owner_index
		var player := state.players[owner]
		var milled: Array[CardInstance] = []
		for i in mini(3, player.deck.size()):
			var card: CardInstance = player.deck.pop_front()
			card.face_up = true
			player.discard_pile.append(card)
			milled.append(card)
		var chosen: Array[CardInstance] = []
		for raw: Variant in get_attack_interaction_context().get(STEP_ID, []):
			if raw is CardInstance and raw in milled and DiscardPileRestriction.can_move_to_hand_or_deck(raw):
				chosen.append(raw)
				break
		if chosen.is_empty() and not get_attack_interaction_context().has(STEP_ID):
			for card: CardInstance in milled:
				if DiscardPileRestriction.can_move_to_hand_or_deck(card):
					chosen.append(card)
					break
		_move_discard_cards_to_hand_with_log(state, owner, chosen, attacker.get_top_card(), "attack")


class AttackPhotonBullet extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		for target: PokemonSlot in state.players[1 - attacker.get_top_card().owner_index].get_all_pokemon():
			var card := target.get_card_data()
			if card.mechanic == "ex" or card.has_tag("ex"):
				load("res://scripts/effects/ThirtiethCelebrationEffects.gd").deal_target_damage(attacker, target, 50, state, get_attack_interaction_context())


class AttackPlayRough extends AttackIronTail:
	func _init(flipper: CoinFlipper) -> void:
		super(flipper)

	func cancels_attack_damage(attacker: PokemonSlot, _defender: PokemonSlot, _index: int, state: GameState) -> bool:
		pending[_key(attacker, state)] = 20 if coin_flipper.flip() else 0
		return false

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		return int(pending.get(_key(attacker, state), 0))


class AttackCollectBasicEnergy extends CSV9CSimpleRecoverPokemonFromDiscard:
	func _init() -> void:
		super(2, 0)

	func _pokemon_cards(cards: Array[CardInstance]) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in cards:
			if card != null and card.card_data != null and card.card_data.card_type == "Basic Energy":
				result.append(card)
		return result

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		var steps := super.build_ucis_attack_interaction_steps_spec_steps(card, attack, state)
		for step: Dictionary in steps:
			step["min_select"] = 0
			step["title"] = "选择弃牌区中最多2张基本能量加入手牌"
		return steps


class AttackThunderCrash extends AttackAnyTargetFixed:
	func _init() -> void:
		super(90)

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		var processor: EffectProcessor = state.shared_turn_flags.get("_draw_effect_processor")
		for energy: CardInstance in attacker.attached_energy.duplicate():
			var types := processor.get_energy_types(energy, state)
			if "L" in types or "ANY" in types:
				attacker.attached_energy.erase(energy)
				state.players[attacker.get_top_card().owner_index].discard_pile.append(energy)
				_record_attack_effect_discarded_attached_energy(attacker, energy, state)
		super.execute_attack(attacker, defender, index, state)


class AttackChargeDash extends AttackSearchEnergyFromDeckToSelf:
	var coin_flipper: CoinFlipper
	var pending: Dictionary = {}

	func _init(flipper: CoinFlipper) -> void:
		super("L", 0)
		coin_flipper = flipper
		bind_default_attack_index(0)

	func _key(card: CardInstance, state: GameState) -> String:
		return "%d:%d:%d" % [state.get_instance_id(), state.turn_number, card.owner_index]

	func _matches_energy(card: CardInstance) -> bool:
		return card != null and card.card_data != null and card.card_data.card_type == "Basic Energy" and card.card_data.energy_provides == "L"

	func build_ucis_attack_preview_interaction_steps_spec_steps(_card: CardInstance, _attack: Dictionary, _state: GameState) -> Array[Dictionary]:
		return [{"id": "coin_flip_preview", "title": "抛币直到反面，再选择基本雷能量", "wait_for_coin_animation": true, "preview_only": true}]

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		var key := _key(card, state)
		if not pending.has(key):
			pending[key] = coin_flipper.flip_until_tails()
		max_count = int(pending[key])
		if max_count <= 0:
			return []
		var steps := super.build_ucis_attack_interaction_steps_spec_steps(card, attack, state)
		if steps.is_empty() and not state.players[card.owner_index].deck.is_empty():
			return [build_empty_search_resolution_step("冲锋之舞：没有基本雷能量，可查看牌库后重洗。")]
		return steps

	func build_ucis_followup_attack_interaction_steps_spec_steps(card: CardInstance, _attack: Dictionary, state: GameState, context: Dictionary) -> Array[Dictionary]:
		if int(pending.get(_key(card, state), 0)) > 0 and should_preview_empty_search_deck(context):
			return [build_readonly_deck_preview_step("冲锋之舞：查看牌库", state.players[card.owner_index].deck)]
		return []

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		var key := _key(attacker.get_top_card(), state)
		if pending.has(key):
			max_count = int(pending[key])
			pending.erase(key)
		else:
			max_count = coin_flipper.flip_until_tails()
		if max_count <= 0:
			state.players[attacker.get_top_card().owner_index].shuffle_deck()
			return
		super.execute_attack(attacker, defender, index, state)


class AttackTropicalMood extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		_apply_special_status(attacker, "asleep", state)
		var owner := attacker.get_top_card().owner_index
		_draw_cards_with_log(state, owner, maxi(0, 6 - state.players[owner].hand.size()), attacker.get_top_card(), "attack")


class AttackSearchEnergy extends AttackSearchDeckToHand:
	func _init() -> void:
		super(1, "", 0)

	func _matches_filter(card: CardInstance) -> bool:
		return card != null and card.card_data != null and card.card_data.is_energy()


class AttackAnyTargetFixed extends AttackAnyTargetDamage:
	func _init(amount: int) -> void:
		super(amount)
		bind_default_attack_index(0)

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		var choices: Array = get_attack_interaction_context().get("any_target", [])
		var target := defender
		if choices.size() == 1 and choices[0] in state.players[1 - attacker.get_top_card().owner_index].get_all_pokemon():
			target = choices[0]
		load("res://scripts/effects/ThirtiethCelebrationEffects.gd").deal_target_damage(attacker, target, damage_amount, state, get_attack_interaction_context())


class AttackIronTail extends BaseEffect:
	var coin_flipper: CoinFlipper
	var pending: Dictionary = {}

	func _init(flipper: CoinFlipper) -> void:
		coin_flipper = flipper
		bind_default_attack_index(0)

	func cancels_attack_damage(attacker: PokemonSlot, _defender: PokemonSlot, _index: int, state: GameState) -> bool:
		var heads := coin_flipper.flip_until_tails()
		pending[_key(attacker, state)] = heads * 20
		return heads == 0

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		return int(pending.get(_key(attacker, state), 20)) - 20

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, _index: int, state: GameState) -> void:
		pending.erase(_key(attacker, state))

	func _key(attacker: PokemonSlot, state: GameState) -> String:
		return "%d:%d:%d" % [state.get_instance_id(), state.turn_number, attacker.get_top_card().instance_id]


class AttackRewriteVolt extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		var processor: EffectProcessor = state.shared_turn_flags.get("_draw_effect_processor")
		if processor != null and processor.is_attack_effect_prevented_by_defender_ability(attacker, defender, state):
			return
		defender.effects.append({"type": "attack_weakness_rewrite", "expires_turn": state.turn_number + 2, "top_instance_id": defender.get_top_card().instance_id, "energy": "L", "value": "x2"})


class AttackMandatorySelfSwitch extends AttackSwitchSelfToBench:
	func _init() -> void:
		attack_index_to_match = 0

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		var steps := super.build_ucis_attack_interaction_steps_spec_steps(card, attack, state)
		for step: Dictionary in steps:
			step["allow_cancel"] = false
		return steps


class AttackPikachuChain extends CSV10CEffects.AttackOwnFieldNamedPokemonCountDamage:
	func _init() -> void:
		super(40, PackedStringArray(), 0)

	func _matches(slot: PokemonSlot) -> bool:
		for identity: String in slot.get_card_data().rule_identity_names():
			if identity in ["皮卡丘", "皮卡丘ex", "Pikachu", "Pikachu ex"]:
				return true
		return false


class AbilityLonelyGaze extends BaseEffect:
	func get_opponent_attack_modifier(source: PokemonSlot, attacker: PokemonSlot, state: GameState, _defender: PokemonSlot) -> int:
		var owner := source.get_top_card().owner_index
		return -20 if source == state.players[owner].active_pokemon and attacker == state.players[1 - owner].active_pokemon else 0


class AttackBenchTarget extends AttackTargetOpponentBenchDamage:
	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		var bench := state.players[1 - attacker.get_top_card().owner_index].bench
		var chosen: Array = get_attack_interaction_context().get(STEP_ID, [])
		if chosen.size() == 1 and chosen[0] in bench:
			load("res://scripts/effects/ThirtiethCelebrationEffects.gd").deal_target_damage(attacker, chosen[0], damage_amount, state, get_attack_interaction_context())


class AbilitySchoolingRetaliation extends BaseEffect:
	func on_ally_damaged_by_attack(source: PokemonSlot, defender: PokemonSlot, attacker: PokemonSlot, damage: int, state: GameState) -> void:
		if damage <= 0 or source == null or defender == null or attacker == null:
			return
		var owner := source.get_top_card().owner_index
		if defender != state.players[owner].active_pokemon or attacker.get_top_card().owner_index == owner:
			return
		for identity: String in defender.get_card_data().rule_identity_names():
			if identity in ["弱丁鱼", "弱丁鱼ex", "Wishiwashi", "Wishiwashi ex"]:
				attacker.damage_counters += 30
				return


class AttackPeek extends Batch3178WorkerCSupportPokemonEffects.SilentWingsOpponentHandPreview:
	func build_ucis_attack_preview_interaction_steps_spec_steps(_card: CardInstance, _attack: Dictionary, _state: GameState) -> Array[Dictionary]:
		return [{"id": "peek_preview", "title": "使用招式后查看对手手牌", "preview_only": true, "min_select": 0, "max_select": 0}]


static func deal_target_damage(attacker: PokemonSlot, target: PokemonSlot, amount: int, state: GameState, context: Dictionary = {}) -> void:
	if target == null or amount <= 0:
		return
	var processor: EffectProcessor = state.shared_turn_flags.get("_draw_effect_processor")
	var active := target == state.players[1 - attacker.get_top_card().owner_index].active_pokemon
	if AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(target, state):
		return
	if not active and AbilityBenchImmune.prevents_opponent_attack_damage(target, attacker, state):
		return
	if processor != null and processor.is_damage_prevented_by_defender_ability(attacker, target, state):
		return
	var damage := amount
	if processor != null:
		if active:
			damage = DamageCalculator.new().calculate_damage(attacker, target, {"damage": str(amount)}, state, 0,
				processor.get_attacker_modifier(attacker, state, target), processor.get_defender_modifier(target, state, attacker),
				false, false, processor.get_weakness_value_override(attacker, target, state), processor.get_weakness_energy_override(attacker, target, state))
		else:
			damage = maxi(0, amount + processor.get_attacker_modifier(attacker, state, target) + processor.get_defender_modifier(target, state, attacker))
	var previous_damage := target.damage_counters
	DamageCalculator.new().apply_damage_to_slot(target, damage)
	if processor != null and damage > 0:
		processor.finish_attack_text_damage(attacker, target, damage, previous_damage, state, [context])


class AttackHail extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		for target: PokemonSlot in state.players[1 - attacker.get_top_card().owner_index].get_all_pokemon():
			load("res://scripts/effects/ThirtiethCelebrationEffects.gd").deal_target_damage(attacker, target, 30, state, get_attack_interaction_context())


class AttackWaterEnergyBonus extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		var processor: EffectProcessor = state.shared_turn_flags.get("_draw_effect_processor")
		var count := 0
		for energy: CardInstance in attacker.attached_energy:
			var types := processor.get_energy_types(energy, state)
			if "W" in types or "ANY" in types:
				count += processor.get_energy_colorless_count(energy, state)
		return count * 30


class AttackWormhole extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		var steps := AttackSwitchSelfToBench.new().build_ucis_attack_interaction_steps_spec_steps(card, attack, state)
		for step: Dictionary in steps:
			step["allow_cancel"] = false
		steps.append_array(AttackSwitchOpponentActive.new(0).build_ucis_attack_interaction_steps_spec_steps(card, attack, state))
		return steps

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		var context := get_attack_interaction_context()
		var self_switch := AttackSwitchSelfToBench.new()
		self_switch.set_attack_interaction_context([context])
		self_switch.execute_attack(attacker, defender, index, state)
		var opponent_switch := AttackSwitchOpponentActive.new(0)
		opponent_switch.set_attack_interaction_context([context])
		opponent_switch.execute_attack(attacker, defender, index, state)


class AttackStealthSlash extends AttackAnyTargetDamage:
	func _init() -> void:
		bind_default_attack_index(0)

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		var targets: Array = get_attack_interaction_context().get("any_target", [])
		var target := defender
		if targets.size() == 1 and targets[0] in opponent.get_all_pokemon():
			target = targets[0]
		if target != null:
			load("res://scripts/effects/ThirtiethCelebrationEffects.gd").deal_target_damage(attacker, target, (target.damage_counters / 10) * 30, state, get_attack_interaction_context())


class AbilityLegendaryBirdAttachment extends AbilityAttachBasicEnergyFromHandDraw:
	var partners: Array[PackedStringArray] = []

	func _init(symbol: String, required_partners: Array[PackedStringArray]) -> void:
		super(symbol, 0)
		partners = required_partners

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or state == null or not super.can_use_ability(pokemon, state):
			return false
		var player := state.players[pokemon.get_top_card().owner_index]
		for aliases: PackedStringArray in partners:
			var found := false
			for slot: PokemonSlot in player.get_all_pokemon():
				for identity: String in slot.get_card_data().rule_identity_names():
					if identity in aliases:
						found = true
			if not found:
				return false
		return true


class AttackSacredBreath extends AttackDiscardAllAttachedEnergyFromSelf:
	const HEAL_STEP := "thirtieth_heal_bench"

	func _init() -> void:
		super(0)

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if not applies_to_attack_index(int(attack.get("_override_attack_index", card.card_data.attacks.find(attack)))):
			return []
		var items: Array = state.players[card.owner_index].bench.duplicate()
		if items.is_empty():
			return []
		return [{"id": HEAL_STEP, "title": "选择1只备战宝可梦回复全部HP", "items": items, "min_select": 1, "max_select": 1, "allow_cancel": false}]

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		super.execute_attack(attacker, defender, index, state)
		var player := state.players[attacker.get_top_card().owner_index]
		var context := get_attack_interaction_context()
		var selected: Array = context.get(HEAL_STEP, [])
		if selected.size() == 1 and selected[0] in player.bench:
			(selected[0] as PokemonSlot).heal((selected[0] as PokemonSlot).damage_counters, state)


class AttackAttachedTypeBonus extends BaseEffect:
	var symbol: String
	var bonus: int
	var attack_index_to_match: int

	func _init(energy_symbol: String, amount: int, index: int) -> void:
		symbol = energy_symbol
		bonus = amount
		attack_index_to_match = index

	func applies_to_attack_index(index: int) -> bool:
		return index == attack_index_to_match

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		var processor: EffectProcessor = state.shared_turn_flags.get("_draw_effect_processor")
		for energy: CardInstance in attacker.attached_energy:
			var types := processor.get_energy_types(energy, state) if processor != null else PackedStringArray([energy.card_data.energy_provides])
			if symbol in types or "ANY" in types:
				return bonus
		return 0


class AttackOwnTakenPrizeMultiplier extends BaseEffect:
	var attack_index_to_match := 1

	func applies_to_attack_index(index: int) -> bool:
		return index == attack_index_to_match

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		var taken := maxi(0, 6 - state.players[attacker.get_top_card().owner_index].prizes.size())
		# DamageCalculator parses the printed 70x as 70; replace, do not add to it.
		return taken * 70 - 70


class AbilityGrassEnergyHP extends BaseEffect:
	func get_hp_modifier_for_source(slot: PokemonSlot, state: GameState) -> int:
		if slot == null or state == null:
			return 0
		var processor: EffectProcessor = state.shared_turn_flags.get("_draw_effect_processor")
		if processor == null:
			return 0
		var count := 0
		for energy: CardInstance in slot.attached_energy:
			var types := processor.get_energy_types(energy, state)
			if "G" in types or "ANY" in types:
				count += processor.get_energy_colorless_count(energy, state)
		return 250 if count >= 6 else 0


class AbilityExcellentPheromone extends BaseEffect:
	func get_global_weakness_value_override(source: PokemonSlot, defender: PokemonSlot, state: GameState) -> String:
		if source == null or defender == null or state == null:
			return ""
		if defender != state.players[0].active_pokemon and defender != state.players[1].active_pokemon:
			return ""
		var owner := source.get_top_card().owner_index
		for slot: PokemonSlot in state.players[owner].get_all_pokemon():
			for identity: String in slot.get_card_data().rule_identity_names():
				if identity in ["电萤虫", "Volbeat"]:
					return "x3"
		return ""


class AbilityGuidingDance extends AbilitySearchDeckCardType:
	var coin_flipper: CoinFlipper
	var pending: Dictionary = {}

	func _init(flipper: CoinFlipper) -> void:
		super(1, "Pokemon")
		coin_flipper = flipper

	func build_ucis_preview_interaction_steps_spec_steps(_card: CardInstance, _state: GameState) -> Array[Dictionary]:
		return [{"id": "coin_flip_preview", "title": "投掷1枚硬币", "wait_for_coin_animation": true, "preview_only": true}]

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var key := _key(card, state)
		if not pending.has(key):
			pending[key] = coin_flipper.flip()
		if not bool(pending[key]):
			return []
		return super.build_ucis_interaction_steps_spec_steps(card, state)

	func build_ucis_followup_interaction_steps_spec_steps(card: CardInstance, state: GameState, context: Dictionary) -> Array[Dictionary]:
		if not bool(pending.get(_key(card, state), false)):
			return []
		return super.build_ucis_followup_interaction_steps_spec_steps(card, state, context)

	func execute_ability(pokemon: PokemonSlot, ability_index: int, targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var key := _key(pokemon.get_top_card(), state)
		var heads: bool
		if pending.has(key):
			heads = bool(pending[key])
			pending.erase(key)
		else:
			heads = coin_flipper.flip()
		if heads:
			super.execute_ability(pokemon, ability_index, targets, state)
		else:
			pokemon.mark_ability_used(state.turn_number)

	func _key(card: CardInstance, state: GameState) -> String:
		return "%d:%d:%d" % [state.get_instance_id(), state.turn_number, card.instance_id]
