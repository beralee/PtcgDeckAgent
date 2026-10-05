extends RefCounted
## Exact printings audited for series 59. Public rules sources are in the tests.


class GiovanniCharisma extends BaseEffect:
	const RETURN := "giovanni_return_energy"
	const ATTACH := "giovanni_attach_energy"

	func can_execute(card: CardInstance, state: GameState) -> bool:
		var opponent := state.players[1 - card.owner_index]
		return opponent.active_pokemon != null and not opponent.active_pokemon.attached_energy.is_empty()

	func _hand_energy(card: CardInstance, state: GameState) -> Array:
		var result: Array = []
		for value: CardInstance in state.players[card.owner_index].hand:
			if value.card_data.is_energy():
				result.append(value)
		return result

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		if not can_execute(card, state):
			return []
		var opponent := state.players[1 - card.owner_index]
		var energies: Array = opponent.active_pokemon.attached_energy.duplicate()
		return [{"id": RETURN, "title": "选择放回对手手牌的能量", "items": energies,
			"min_select": 1, "max_select": 1, "allow_cancel": false,
			"ucis_select_type_name": "ATTACHED_CARD", "ucis_context_name": "SWITCH_ENERGY_CARD", "ucis_option_type_name": "ENERGY_CARD",
			"card_groups": build_attached_card_groups(opponent, energies), "requires_followup_interaction": true}]

	func build_ucis_followup_interaction_steps_spec_steps(card: CardInstance, state: GameState, context: Dictionary) -> Array[Dictionary]:
		var energies := _hand_energy(card, state)
		if not context.has(RETURN) or energies.is_empty() or state.players[card.owner_index].active_pokemon == null:
			return []
		return [{"id": ATTACH, "title": "选择附着于自己战斗宝可梦的能量", "items": energies,
			"min_select": 1, "max_select": 1, "allow_cancel": false}]

	func validate_card_interaction(card: CardInstance, targets: Array, state: GameState) -> Dictionary:
		if not can_execute(card, state):
			return interaction_validation_error("opponent active has no Energy")
		var ctx := get_interaction_context(targets)
		var check := validate_context_selection(ctx, RETURN, state.players[1-card.owner_index].active_pokemon.attached_energy, 1, 1)
		if not check.valid:
			return check
		var energies := _hand_energy(card, state)
		if not energies.is_empty() and state.players[card.owner_index].active_pokemon != null:
			return validate_context_selection(ctx, ATTACH, energies, 1, 1)
		return interaction_validation_ok()

	func execute(card: CardInstance, targets: Array, state: GameState) -> void:
		if not validate_card_interaction(card, targets, state).valid:
			return
		var ctx := get_interaction_context(targets)
		var opponent := state.players[1-card.owner_index]
		var returned: CardInstance = ctx[RETURN][0]
		opponent.active_pokemon.attached_energy.erase(returned)
		opponent.hand.append(returned)
		var player := state.players[card.owner_index]
		var selected := interaction_context_selection(ctx, ATTACH)
		if selected.is_empty() or player.active_pokemon == null:
			return
		var energy: CardInstance = selected[0]
		player.hand.erase(energy)
		energy.face_up = true
		player.active_pokemon.attached_energy.append(energy)
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor")
		if processor != null:
			processor.execute_card_effect(energy, [player.active_pokemon], state)
			processor.process_after_energy_attached_from_hand(card.owner_index, player.active_pokemon, state)
			if processor.prevents_special_status(player.active_pokemon, state):
				player.active_pokemon.clear_all_status()


class OgreMask extends BaseEffect:
	const DISCARD := "ogre_mask_discard"
	const FIELD := "ogre_mask_field"

	func _is_ogerpon(card: CardInstance) -> bool:
		if card == null or card.card_data == null:
			return false
		var data := card.card_data
		return data.is_pokemon() and data.mechanic.to_lower() == "ex" and ("厄诡椪" in data.name or "Ogerpon" in data.name)

	func _discard(player: PlayerState) -> Array:
		var result: Array = []
		for card: CardInstance in player.discard_pile:
			if _is_ogerpon(card):
				result.append(card)
		return result

	func _field(player: PlayerState) -> Array:
		var result: Array = []
		for slot: PokemonSlot in player.get_all_pokemon():
			if _is_ogerpon(slot.get_top_card()):
				result.append(slot)
		return result

	func can_execute(card: CardInstance, state: GameState) -> bool:
		var player := state.players[card.owner_index]
		return not _discard(player).is_empty() and not _field(player).is_empty()

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		if not can_execute(card, state):
			return []
		return [{"id": DISCARD, "title": "选择弃牌区的厄诡椪ex", "items": _discard(state.players[card.owner_index]),
			"min_select": 1, "max_select": 1, "allow_cancel": false, "requires_followup_interaction": true}]

	func build_ucis_followup_interaction_steps_spec_steps(card: CardInstance, state: GameState, _context: Dictionary) -> Array[Dictionary]:
		return [{"id": FIELD, "title": "选择场上要互换的厄诡椪ex", "items": _field(state.players[card.owner_index]),
			"min_select": 1, "max_select": 1, "allow_cancel": false, "presentation": "pokemon_slots"}]

	func validate_card_interaction(card: CardInstance, targets: Array, state: GameState) -> Dictionary:
		var ctx := get_interaction_context(targets)
		var player := state.players[card.owner_index]
		var check := validate_context_selection(ctx, DISCARD, _discard(player), 1, 1)
		return check if not check.valid else validate_context_selection(ctx, FIELD, _field(player), 1, 1)

	func execute(card: CardInstance, targets: Array, state: GameState) -> void:
		if not validate_card_interaction(card, targets, state).valid:
			return
		var ctx := get_interaction_context(targets)
		var player := state.players[card.owner_index]
		var replacement: CardInstance = ctx[DISCARD][0]
		var slot: PokemonSlot = ctx[FIELD][0]
		var previous := slot.get_top_card()
		player.discard_pile.erase(replacement)
		replacement.face_up = true
		slot.pokemon_stack[slot.pokemon_stack.size()-1] = replacement
		player.discard_pile.append(previous)
		# The same Pokemon entity retains all attached cards, counters, conditions,
		# effects, usage markers and turns in play. This is not a Bench entry.
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor")
		if processor != null:
			processor.register_pokemon_card(replacement.card_data)


class Drayton extends BaseEffect:
	const POKEMON := "drayton_pokemon"
	const TRAINER := "drayton_trainer"

	func can_execute(card: CardInstance, state: GameState) -> bool:
		return not state.players[card.owner_index].deck.is_empty()

	func _looked(player: PlayerState) -> Array:
		return player.deck.slice(0, mini(7, player.deck.size()))

	func _matches(cards: Array, pokemon: bool) -> Array:
		var result: Array = []
		for card: CardInstance in cards:
			if card.card_data.is_pokemon() if pokemon else card.card_data.card_type in ["Item", "Supporter", "Tool", "Stadium"]:
				result.append(card)
		return result

	func _step(player: PlayerState, pokemon: bool) -> Dictionary:
		var looked := _looked(player)
		var items := _matches(looked, pokemon)
		var options := {"allow_cancel": true}
		if items.is_empty():
			options["utility_actions"] = [build_empty_dialog_utility_action("继续")]
		return build_full_library_search_step(POKEMON if pokemon else TRAINER,
			"从上方7张选择1张宝可梦" if pokemon else "从上方7张选择1张训练家", looked, items,
			"own_top_%d_cards" % looked.size(), 0, mini(1, items.size()), options)

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var step := _step(state.players[card.owner_index], true)
		step["requires_followup_interaction"] = true
		return [step]

	func build_ucis_followup_interaction_steps_spec_steps(card: CardInstance, state: GameState, _context: Dictionary) -> Array[Dictionary]:
		return [_step(state.players[card.owner_index], false)]

	func validate_card_interaction(card: CardInstance, targets: Array, state: GameState) -> Dictionary:
		var ctx := get_interaction_context(targets)
		var looked := _looked(state.players[card.owner_index])
		for kind: bool in [true, false]:
			var check := validate_context_selection(ctx, POKEMON if kind else TRAINER, _matches(looked, kind), 0, 1)
			if not check.valid:
				return check
		return interaction_validation_ok()

	func execute(card: CardInstance, targets: Array, state: GameState) -> void:
		if not validate_card_interaction(card, targets, state).valid:
			return
		var ctx := get_interaction_context(targets)
		var selected: Array[CardInstance] = []
		selected.assign(interaction_context_selection(ctx, POKEMON) + interaction_context_selection(ctx, TRAINER))
		_move_public_cards_to_hand_with_log(state, card.owner_index, selected, card, "trainer", "toplook_to_hand", ["宝可梦", "训练家"])
		state.players[card.owner_index].shuffle_deck()


class TMBlindside extends BaseEffect:
	const TARGET := "tm_blindside_target"
	const ID := "tm_blindside"

	func _targets(attacker: PokemonSlot, state: GameState) -> Array:
		var result: Array = []
		for slot: PokemonSlot in state.players[1-attacker.get_top_card().owner_index].get_all_pokemon():
			if slot.damage_counters > 0:
				result.append(slot)
		return result

	func get_granted_attacks(_pokemon: PokemonSlot, _state: GameState) -> Array[Dictionary]:
		return [{"id": ID, "name": "暗中奇袭", "cost": "CCC", "damage": "", "text": "给身上有伤害指示物的1只对手宝可梦造成100伤害。"}]

	func build_ucis_granted_attack_interaction_steps_spec_steps(pokemon: PokemonSlot, _attack: Dictionary, state: GameState) -> Array[Dictionary]:
		var items := _targets(pokemon, state)
		if items.is_empty():
			return []
		return [{"id": TARGET, "title": "选择已有伤害指示物的对手宝可梦", "items": items,
			"min_select": 1, "max_select": 1, "allow_cancel": false, "presentation": "pokemon_slots"}]

	func validate_granted_attack_interaction(attacker: PokemonSlot, _attack: Dictionary, targets: Array, state: GameState) -> Dictionary:
		var legal := _targets(attacker, state)
		var ctx := get_interaction_context(targets)
		if legal.is_empty() and interaction_context_selection(ctx, TARGET).is_empty():
			return interaction_validation_ok()
		return validate_context_selection(ctx, TARGET, legal, 1, 1)

	func execute_granted_attack(attacker: PokemonSlot, attack: Dictionary, state: GameState, targets: Array = []) -> void:
		if str(attack.get("id")) != ID or not validate_granted_attack_interaction(attacker, attack, targets, state).valid:
			return
		var selected := interaction_context_selection(get_interaction_context(targets), TARGET)
		if selected.is_empty():
			return
		var target: PokemonSlot = selected[0]
		if AbilityBenchImmune.prevents_opponent_attack_damage(target, attacker, state) or AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(target, state):
			return
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor")
		if processor != null and processor.is_damage_prevented_by_defender_ability(attacker, target, state):
			return
		var damage := _calculate_attack_target_damage(attacker, target, 100, state)
		var previous := target.damage_counters
		target.damage_counters += damage
		if processor != null and processor.has_method("finish_attack_text_damage"):
			processor.finish_attack_text_damage(attacker, target, damage, previous, state, targets)

	func discard_at_end_of_turn(_slot: PokemonSlot, _state: GameState) -> bool:
		return true


class VengefulPunch extends BaseEffect:
	func on_attack_damage_knockout_tool_reaction(defender: PokemonSlot, attacker: PokemonSlot, _state: GameState) -> void:
		if defender.get_top_card().owner_index != attacker.get_top_card().owner_index:
			attacker.damage_counters += 40


class DeductionKit extends BaseEffect:
	const MODE := "deduction_bottom"
	const ORDER := "deduction_order"

	func can_execute(card: CardInstance, state: GameState) -> bool:
		return not state.players[card.owner_index].deck.is_empty()

	func _looked(card: CardInstance, state: GameState) -> Array:
		var deck := state.players[card.owner_index].deck
		return deck.slice(0, mini(3, deck.size()))

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var looked := _looked(card, state)
		return [{"id": ORDER, "title": "查看上方3张，并按从牌库上方起的顺序选择；下一步可改为重洗后放到下方", "items": looked,
			"min_select": looked.size(), "max_select": looked.size(), "allow_cancel": false, "ordered_selection": true,
			"visible_scope": "own_top_%d_cards" % looked.size(), "requires_followup_interaction": true}]

	func build_ucis_followup_interaction_steps_spec_steps(card: CardInstance, state: GameState, context: Dictionary) -> Array[Dictionary]:
		if not context.has(ORDER):
			return []
		return [{"id": MODE, "title": "按刚才顺序放回上方，或重洗这3张后放到下方", "items": [false, true],
			"labels": ["按顺序放回上方", "重洗这些卡放到下方"], "card_items": _looked(card, state),
			"min_select": 1, "max_select": 1, "allow_cancel": false}]

	func validate_card_interaction(card: CardInstance, targets: Array, state: GameState) -> Dictionary:
		var ctx := get_interaction_context(targets)
		var check := validate_context_selection(ctx, MODE, [false, true], 1, 1)
		if not check.valid:
			return check
		var looked := _looked(card, state)
		return validate_context_selection(ctx, ORDER, looked, looked.size(), looked.size())

	func execute(card: CardInstance, targets: Array, state: GameState) -> void:
		if not validate_card_interaction(card, targets, state).valid:
			return
		var player := state.players[card.owner_index]
		var looked := _looked(card, state)
		var ctx := get_interaction_context(targets)
		for value: CardInstance in looked:
			player.deck.erase(value)
			value.face_up = false
		if ctx[MODE] == [true]:
			player.shuffle_cards(looked, "deduction_kit_bottom")
			player.deck.append_array(looked)
		else:
			var ordered: Array = ctx[ORDER].duplicate()
			ordered.reverse()
			for value: CardInstance in ordered:
				player.deck.push_front(value)


class Miriam extends BaseEffect:
	const RETURN := "miriam_return"

	func _cards(card: CardInstance, state: GameState) -> Array:
		var result: Array = []
		for value: CardInstance in state.players[card.owner_index].discard_pile:
			if value.card_data.is_pokemon() and DiscardPileRestriction.can_move_to_hand_or_deck(value):
				result.append(value)
		return result

	func can_execute(card: CardInstance, state: GameState) -> bool:
		return not _cards(card, state).is_empty()

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var cards := _cards(card,state)
		if cards.is_empty(): return []
		return [{"id":RETURN,"title":"选择最多5张弃牌区宝可梦放回牌库，然后抽3张","items":cards,
			"min_select":1,"max_select":mini(5,cards.size()),"allow_cancel":false,"ucis_context_name":"TO_DECK"}]

	func validate_card_interaction(card: CardInstance, targets: Array, state: GameState) -> Dictionary:
		return validate_context_selection(get_interaction_context(targets),RETURN,_cards(card,state),1,5)

	func execute(card: CardInstance, targets: Array, state: GameState) -> void:
		if not validate_card_interaction(card,targets,state).valid: return
		var player := state.players[card.owner_index]
		for value: CardInstance in get_interaction_context(targets)[RETURN]:
			player.discard_pile.erase(value)
			value.face_up=false
			player.deck.append(value)
		player.shuffle_deck()
		_draw_cards_with_log(state,card.owner_index,3,card,"trainer")


class Rika extends BaseEffect:
	const PICK := "rika_pick"

	func _looked(card: CardInstance, state: GameState) -> Array:
		var deck := state.players[card.owner_index].deck
		return deck.slice(0,mini(4,deck.size()))

	func can_execute(card: CardInstance, state: GameState) -> bool:
		return not _looked(card,state).is_empty()

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var looked := _looked(card,state)
		var count := mini(2,looked.size())
		return [build_full_library_search_step(PICK,"查看牌库上方4张，选择2张加入手牌",looked,looked,
			"own_top_%d_cards" % looked.size(),count,count,{"allow_cancel":false,"allow_hidden_search_whiff":false})]

	func validate_card_interaction(card: CardInstance, targets: Array, state: GameState) -> Dictionary:
		var looked := _looked(card,state)
		return validate_context_selection(get_interaction_context(targets),PICK,looked,mini(2,looked.size()),mini(2,looked.size()))

	func execute(card: CardInstance, targets: Array, state: GameState) -> void:
		if not validate_card_interaction(card,targets,state).valid: return
		var player := state.players[card.owner_index]
		var looked := _looked(card,state)
		var picked := interaction_context_selection(get_interaction_context(targets),PICK)
		var bottom: Array = []
		for value: CardInstance in looked:
			player.deck.erase(value)
			if value in picked:
				# Unfiltered look-and-choose does not reveal the selected hand cards.
				value.face_up=true
				player.hand.append(value)
			else:
				value.face_up=false
				bottom.append(value)
		player.shuffle_cards(bottom,"rika_bottom")
		player.deck.append_array(bottom)
