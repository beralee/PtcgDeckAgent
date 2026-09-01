class_name CSV10C101To200Effects
extends RefCounted

const H = preload("res://scripts/effects/CSV9CHelpers.gd")
const BenchLimit = preload("res://scripts/engine/BenchLimitHelper.gd")


class AttackCoinFlipCopyOpponentAttack extends AttackCopyAttack:
	const RESULT_STEP_ID := "csv10c101_coin_result"

	var attack_index_to_match: int = -1
	var _coin_flipper: CoinFlipper = null
	var _pending_heads: bool = false
	var _has_pending_flip: bool = false

	func _init(processor: EffectProcessor, match_attack_index: int = -1, flipper: CoinFlipper = null) -> void:
		super(processor)
		attack_index_to_match = match_attack_index
		_coin_flipper = flipper

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func build_ucis_attack_preview_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, _state: GameState) -> Array[Dictionary]:
		if card == null or not applies_to_attack_index(_resolve_index(card, attack)):
			return []
		return [_coin_result_step("Flip a coin. If heads, choose an attack on the opponent Active Pokemon to copy.", "preview")]

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, _state: GameState) -> Array[Dictionary]:
		if card == null or not applies_to_attack_index(_resolve_index(card, attack)):
			return []
		var flipper := _coin_flipper if _coin_flipper != null else CoinFlipper.new()
		_pending_heads = flipper.flip()
		_has_pending_flip = true
		var result := "heads" if _pending_heads else "tails"
		var title := "Coin result: heads. Continue to choose a copied attack." if _pending_heads else "Coin result: tails. The attack has no effect."
		return [_coin_result_step(title, result)]

	func build_ucis_followup_attack_interaction_steps_spec_steps(
		card: CardInstance,
		attack: Dictionary,
		state: GameState,
		resolved_context: Dictionary
	) -> Array[Dictionary]:
		if not _heads_from_context(resolved_context):
			return []
		if not resolved_context.has(AttackCopyAttack.STEP_ID):
			return super.build_ucis_attack_interaction_steps_spec_steps(card, attack, state)
		var copied_context := resolved_context.duplicate(true)
		copied_context.erase(RESULT_STEP_ID)
		return super.build_ucis_followup_attack_interaction_steps_spec_steps(card, attack, state, copied_context)

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		return super.get_damage_bonus(attacker, state) if _resolved_heads() else 0

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if not applies_to_attack_index(attack_index):
			return
		var heads := _resolved_heads()
		_has_pending_flip = false
		if heads:
			super.execute_attack(attacker, defender, attack_index, state)

	func _resolved_heads() -> bool:
		var context := get_attack_interaction_context()
		if context.has("copied_attack"):
			return true
		var raw: Array = context.get(RESULT_STEP_ID, [])
		if not raw.is_empty():
			return str(raw[0]) == "heads"
		if _has_pending_flip:
			return _pending_heads
		var flipper := _coin_flipper if _coin_flipper != null else CoinFlipper.new()
		_pending_heads = flipper.flip()
		_has_pending_flip = true
		return _pending_heads

	func _heads_from_context(context: Dictionary) -> bool:
		var raw: Array = context.get(RESULT_STEP_ID, [])
		return not raw.is_empty() and str(raw[0]) == "heads"

	func _coin_result_step(title: String, result: String) -> Dictionary:
		return {
			"id": RESULT_STEP_ID,
			"title": title,
			"items": [result],
			"labels": ["Continue"],
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": false,
			"wait_for_coin_animation": true,
			"force_dialog": true,
		}

	func _resolve_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		if card == null or card.card_data == null:
			return -1
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AttackOwnBenchStageCountDamage extends BaseEffect:
	var stage_filter: String = "Stage 2"
	var damage_per_match: int = 40
	var attack_index_to_match: int = -1

	func _init(stage: String = "Stage 2", damage: int = 40, match_attack_index: int = -1) -> void:
		stage_filter = stage
		damage_per_match = damage
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or attacker.get_top_card() == null or state == null:
			return 0
		var player := state.players[attacker.get_top_card().owner_index]
		var count := 0
		for slot: PokemonSlot in player.bench:
			var card_data := slot.get_card_data()
			if card_data != null and card_data.stage == stage_filter:
				count += 1
		return count * damage_per_match

	func execute_attack(_attacker: PokemonSlot, _defender: PokemonSlot, _attack_index: int, _state: GameState) -> void:
		pass


class AttackDiscardOpponentActiveEnergy extends BaseEffect:
	const STEP_ID := "discard_opponent_active_energy"

	var attack_index_to_match: int = -1

	func _init(match_attack_index: int = -1) -> void:
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_index(card, attack)):
			return []
		var opponent := state.players[1 - card.owner_index]
		var active := opponent.active_pokemon
		if active == null or active.attached_energy.is_empty():
			return []
		var labels: Array[String] = []
		for energy: CardInstance in active.attached_energy:
			labels.append(energy.card_data.name if energy.card_data != null else "")
		return [{
			"id": STEP_ID,
			"title": "Choose an Energy attached to the opponent Active Pokemon to discard",
			"items": active.attached_energy.duplicate(),
			"labels": labels,
			"card_groups": build_attached_card_groups(opponent, active.attached_energy),
			"transparent_battlefield_dialog": true,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": false,
		}]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or not applies_to_attack_index(attack_index):
			return
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		var active := opponent.active_pokemon
		if active == null or active.attached_energy.is_empty():
			return
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		if processor != null and processor.has_method("is_attack_effect_prevented_by_defender_ability"):
			if bool(processor.call("is_attack_effect_prevented_by_defender_ability", attacker, active, state)):
				return
		var selected: CardInstance = null
		for raw: Variant in get_attack_interaction_context().get(STEP_ID, []):
			if raw is CardInstance and raw in active.attached_energy:
				selected = raw
				break
		if selected == null:
			selected = active.attached_energy[0]
		active.attached_energy.erase(selected)
		opponent.discard_card(selected)

	func _resolve_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AbilityActiveOpponentBasicPokemonCheckDamage extends BaseEffect:
	var damage_counters: int = 2

	func _init(counters: int = 2) -> void:
		damage_counters = maxi(0, counters)

	func process_pokemon_check(source: PokemonSlot, state: GameState, damaged_slots: Array[PokemonSlot]) -> void:
		if source == null or source.get_top_card() == null or state == null:
			return
		var owner := source.get_top_card().owner_index
		if state.players[owner].active_pokemon != source:
			return
		for slot: PokemonSlot in state.players[1 - owner].get_all_pokemon():
			var card_data := slot.get_card_data()
			if card_data == null or not card_data.is_basic_pokemon():
				continue
			slot.damage_counters += damage_counters * 10
			if slot not in damaged_slots:
				damaged_slots.append(slot)


class AttackBonusIfDefenderStage extends BaseEffect:
	var required_stage: String = "Stage 2"
	var bonus_damage: int = 140
	var attack_index_to_match: int = -1

	func _init(stage: String = "Stage 2", bonus: int = 140, match_attack_index: int = -1) -> void:
		required_stage = stage
		bonus_damage = bonus
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or attacker.get_top_card() == null or state == null:
			return 0
		var defender := state.players[1 - attacker.get_top_card().owner_index].active_pokemon
		var card_data := defender.get_card_data() if defender != null else null
		return bonus_damage if card_data != null and card_data.stage == required_stage else 0

	func execute_attack(_attacker: PokemonSlot, _defender: PokemonSlot, _attack_index: int, _state: GameState) -> void:
		pass


class AttackIgnoreResistance extends BaseEffect:
	var attack_index_to_match: int = -1

	func _init(match_attack_index: int = -1) -> void:
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func ignores_resistance(_attacker: PokemonSlot, _state: GameState, attack_index: int = -1) -> bool:
		return applies_to_attack_index(attack_index)


class AbilitySearchNamedPokemon extends BaseEffect:
	const STEP_ID := "csv10c_named_pokemon_search"

	var name_prefixes: PackedStringArray = PackedStringArray()
	var search_count: int = 1

	func _init(prefixes: PackedStringArray, count: int = 1) -> void:
		name_prefixes = prefixes.duplicate()
		search_count = maxi(0, count)

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		var owner := pokemon.get_top_card().owner_index
		return state.current_player_index == owner and not pokemon.has_ability_used(state.turn_number) and not state.players[owner].deck.is_empty()

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		if card == null or state == null:
			return []
		var player := state.players[card.owner_index]
		var candidates := _candidates(player)
		if candidates.is_empty():
			return [build_empty_search_resolution_step("No matching named Pokemon in deck.")]
		return [build_full_library_search_step(
			STEP_ID,
			"Choose a matching named Pokemon from your deck",
			player.deck,
			candidates,
			VISIBLE_SCOPE_OWN_FULL_DECK,
			0,
			mini(search_count, candidates.size()),
			{"allow_cancel": true}
		)]

	func build_ucis_followup_interaction_steps_spec_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
		if not should_preview_empty_search_deck(resolved_context):
			return []
		return [build_readonly_deck_preview_step("View deck", state.players[card.owner_index].deck)]

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return
		var owner := pokemon.get_top_card().owner_index
		var player := state.players[owner]
		var candidates := _candidates(player)
		var context := get_interaction_context(targets)
		var selected: Array[CardInstance] = []
		for raw: Variant in context.get(STEP_ID, []):
			if raw is CardInstance and raw in candidates and raw not in selected:
				selected.append(raw)
				if selected.size() >= search_count:
					break
		if selected.is_empty() and not context.has(STEP_ID) and not candidates.is_empty():
			selected.append(candidates[0])
		_move_public_cards_to_hand_with_log(state, owner, selected, pokemon.get_top_card(), "ability", "search_to_hand", ["named Pokemon"])
		player.shuffle_deck()
		pokemon.mark_ability_used(state.turn_number)

	func _candidates(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for deck_card: CardInstance in player.deck:
			if _matches(deck_card):
				result.append(deck_card)
		return result

	func _matches(card: CardInstance) -> bool:
		if card == null or card.card_data == null or not card.card_data.is_pokemon():
			return false
		for identity: String in card.card_data.rule_identity_names():
			var normalized := identity.strip_edges().to_lower()
			for prefix: String in name_prefixes:
				if normalized.begins_with(prefix.strip_edges().to_lower()):
					return true
		return false


class AttackLookTopOptionalDiscard extends BaseEffect:
	const STEP_ID := "csv10c_top_card_choice"

	var attack_index_to_match: int = -1

	func _init(match_attack_index: int = -1) -> void:
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_index(card, attack)):
			return []
		var player := state.players[card.owner_index]
		if player.deck.is_empty():
			return []
		var top_card := player.deck[0]
		return [{
			"id": STEP_ID,
			"title": "Look at the top card of your deck. You may discard it.",
			"items": ["keep", "discard"],
			"labels": ["Keep on top", "Discard"],
			"card_items": [top_card],
			"private_to_player": card.owner_index,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		}]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or not applies_to_attack_index(attack_index):
			return
		var player := state.players[attacker.get_top_card().owner_index]
		if player.deck.is_empty():
			return
		var raw: Array = get_attack_interaction_context().get(STEP_ID, [])
		if not raw.is_empty() and str(raw[0]) == "discard":
			var discarded: CardInstance = player.deck.pop_front()
			discarded.face_up = true
			player.discard_pile.append(discarded)

	func _resolve_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AbilityEvolveAttachNamedEnergyFromDiscard extends BaseEffect:
	const STEP_ID := "csv10c_spiky_energy"

	var names: PackedStringArray = PackedStringArray()
	var max_count: int = 2

	func _init(energy_names: PackedStringArray, count: int = 2) -> void:
		names = energy_names.duplicate()
		max_count = maxi(0, count)

	func is_evolve_triggered_ability() -> bool:
		return true

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		var owner := pokemon.get_top_card().owner_index
		return state.current_player_index == owner and pokemon.turn_evolved == state.turn_number and not pokemon.has_ability_used(state.turn_number) and not _candidates(state.players[owner]).is_empty()

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		if card == null or state == null:
			return []
		var candidates := _candidates(state.players[card.owner_index])
		var labels: Array[String] = []
		for energy: CardInstance in candidates:
			labels.append(energy.card_data.display_name())
		return [{
			"id": STEP_ID,
			"title": "Choose up to %d matching Energy from your discard pile" % max_count,
			"items": candidates,
			"labels": labels,
			"presentation": "cards",
			"min_select": 0,
			"max_select": mini(max_count, candidates.size()),
			"allow_cancel": true,
			"force_confirm": true,
		}]

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return
		var player := state.players[pokemon.get_top_card().owner_index]
		var candidates := _candidates(player)
		var context := get_interaction_context(targets)
		var selected: Array[CardInstance] = []
		for raw: Variant in context.get(STEP_ID, []):
			if raw is CardInstance and raw in candidates and raw not in selected:
				selected.append(raw)
				if selected.size() >= max_count:
					break
		if selected.is_empty() and not context.has(STEP_ID):
			selected.assign(candidates.slice(0, mini(max_count, candidates.size())))
		for energy: CardInstance in selected:
			player.discard_pile.erase(energy)
			pokemon.attached_energy.append(energy)
		pokemon.mark_ability_used(state.turn_number)

	func _candidates(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in player.discard_pile:
			if card != null and card.card_data != null and _matches_name(card.card_data):
				result.append(card)
		return result

	func _matches_name(card_data: CardData) -> bool:
		for identity: String in card_data.rule_identity_names():
			var normalized := identity.strip_edges().to_lower()
			for required: String in names:
				if normalized == required.strip_edges().to_lower():
					return true
		return false


class AttackDefenderDamageCounterMultiplierBonus extends BaseEffect:
	var damage_per_counter: int = 40
	var attack_index_to_match: int = -1

	func _init(per_counter: int = 40, match_attack_index: int = -1) -> void:
		damage_per_counter = per_counter
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or attacker.get_top_card() == null or state == null:
			return 0
		var defender := state.players[1 - attacker.get_top_card().owner_index].active_pokemon
		return (defender.damage_counters / 10) * damage_per_counter if defender != null else 0

	func execute_attack(_attacker: PokemonSlot, _defender: PokemonSlot, _attack_index: int, _state: GameState) -> void:
		pass


class AttackDamageOwnBenchAll extends BaseEffect:
	var damage_amount: int = 20
	var attack_index_to_match: int = -1

	func _init(damage: int = 20, match_attack_index: int = -1) -> void:
		damage_amount = maxi(0, damage)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		for slot: PokemonSlot in state.players[attacker.get_top_card().owner_index].bench:
			slot.damage_counters += damage_amount


class AttackChooseOpponentBenchAsActive extends AttackSwitchOpponentActive:
	func _init(match_attack_index: int = -1) -> void:
		super(match_attack_index)

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		var steps := super.build_ucis_attack_interaction_steps_spec_steps(card, attack, state)
		for step: Dictionary in steps:
			step["title"] = "Choose 1 opposing Benched Pokemon to switch into the Active Spot"
			step["opponent_chooses"] = false
		return steps

	func get_description() -> String:
		return "Choose 1 of the opponent's Benched Pokemon and switch it with their Active Pokemon."


class AbilityActiveBlocksOpponentAbilityPokemonExceptNamed extends BaseEffect:
	var exempt_prefixes: PackedStringArray = PackedStringArray()

	func _init(prefixes: PackedStringArray) -> void:
		exempt_prefixes = prefixes.duplicate()

	func blocks_card_from_hand(source: PokemonSlot, card: CardInstance, player_index: int, state: GameState) -> bool:
		if source == null or source.get_top_card() == null or card == null or card.card_data == null or state == null:
			return false
		var owner := source.get_top_card().owner_index
		if owner < 0 or owner >= state.players.size() or player_index == owner:
			return false
		if state.players[owner].active_pokemon != source:
			return false
		if not card.card_data.is_pokemon() or card.card_data.abilities.is_empty():
			return false
		for identity: String in card.card_data.rule_identity_names():
			var normalized := identity.strip_edges().to_lower()
			for prefix: String in exempt_prefixes:
				if normalized.begins_with(prefix.strip_edges().to_lower()):
					return false
		return true

	func get_description() -> String:
		return "While this Pokemon is Active, the opponent cannot play Pokemon with Abilities from hand, except exempt named Pokemon."


class AttackDamageAllOpponentPokemon extends BaseEffect:
	var damage_amount: int = 30
	var attack_index_to_match: int = -1

	func _init(damage: int = 30, match_attack_index: int = -1) -> void:
		damage_amount = maxi(0, damage)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		if defender != null:
			defender.damage_counters += _calculate_attack_target_damage(attacker, defender, damage_amount, state)
		for slot: PokemonSlot in opponent.bench:
			if slot != null and slot.get_top_card() != null:
				slot.damage_counters += damage_amount


class AttackEvolveOwnPokemonFromDeck extends BaseEffect:
	const TARGET_STEP_ID := "csv10c_dark_evolution_targets"
	const CARD_STEP_ID := "csv10c_dark_evolution_cards"

	var max_count: int = 2
	var required_energy_type: String = "D"
	var attack_index_to_match: int = -1

	func _init(count: int = 2, energy_type: String = "D", match_attack_index: int = -1) -> void:
		max_count = maxi(0, count)
		required_energy_type = energy_type
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var player := state.players[card.owner_index]
		var candidates := _eligible_slots(player)
		if candidates.is_empty():
			return []
		var labels: Array[String] = []
		for slot: PokemonSlot in candidates:
			labels.append(slot.get_pokemon_name())
		return [{
			"id": TARGET_STEP_ID,
			"title": "Choose up to %d Darkness Pokemon to evolve" % max_count,
			"items": candidates,
			"labels": labels,
			"presentation": "pokemon_slots",
			"min_select": 0,
			"max_select": mini(max_count, candidates.size()),
			"allow_cancel": true,
			"force_confirm": true,
			"requires_followup_interaction": true,
		}]

	func build_ucis_followup_attack_interaction_steps_spec_steps(
		card: CardInstance,
		attack: Dictionary,
		state: GameState,
		resolved_context: Dictionary
	) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var player := state.players[card.owner_index]
		var selected_slots := _selected_slots(resolved_context, _eligible_slots(player))
		if selected_slots.is_empty():
			return []
		var legal_cards := _evolutions_for_slots(player, selected_slots)
		if legal_cards.is_empty():
			return []
		return [build_full_library_search_step(
			CARD_STEP_ID,
			"Choose an evolution for each selected Pokemon",
			player.deck,
			legal_cards,
			VISIBLE_SCOPE_OWN_FULL_DECK,
			0,
			mini(selected_slots.size(), legal_cards.size()),
			{"allow_cancel": true, "force_confirm": true}
		)]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var player := state.players[attacker.get_top_card().owner_index]
		var context := get_attack_interaction_context()
		var eligible_slots := _eligible_slots(player)
		var selected_slots := _selected_slots(context, eligible_slots)
		if selected_slots.is_empty() and not context.has(TARGET_STEP_ID):
			selected_slots.assign(eligible_slots.slice(0, mini(max_count, eligible_slots.size())))
		var legal_cards := _evolutions_for_slots(player, selected_slots)
		var selected_cards: Array[CardInstance] = []
		for raw: Variant in context.get(CARD_STEP_ID, []):
			if raw is CardInstance and raw in legal_cards and raw not in selected_cards:
				selected_cards.append(raw)
				if selected_cards.size() >= selected_slots.size():
					break
		if selected_cards.is_empty() and not context.has(CARD_STEP_ID):
			selected_cards = _default_evolutions_for_slots(player, selected_slots)
		var evolved_slots: Array[PokemonSlot] = []
		for evolution: CardInstance in selected_cards:
			for slot: PokemonSlot in selected_slots:
				if slot in evolved_slots or slot.get_top_card() == null:
					continue
				if evolution.card_data != null and evolution.card_data.evolves_from_matches(slot.get_top_card().card_data):
					player.deck.erase(evolution)
					evolution.face_up = true
					slot.pokemon_stack.append(evolution)
					slot.turn_evolved = state.turn_number
					slot.clear_all_status()
					evolved_slots.append(slot)
					break
		player.shuffle_deck()

	func _eligible_slots(player: PlayerState) -> Array[PokemonSlot]:
		var result: Array[PokemonSlot] = []
		for slot: PokemonSlot in player.get_all_pokemon():
			if slot == null or slot.get_top_card() == null:
				continue
			if slot.get_card_data().energy_type != required_energy_type:
				continue
			if not _evolutions_for_slots(player, [slot]).is_empty():
				result.append(slot)
		return result

	func _selected_slots(context: Dictionary, eligible: Array[PokemonSlot]) -> Array[PokemonSlot]:
		var result: Array[PokemonSlot] = []
		for raw: Variant in context.get(TARGET_STEP_ID, []):
			if raw is PokemonSlot and raw in eligible and raw not in result:
				result.append(raw)
				if result.size() >= max_count:
					break
		return result

	func _evolutions_for_slots(player: PlayerState, slots: Array[PokemonSlot]) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for deck_card: CardInstance in player.deck:
			if deck_card == null or deck_card.card_data == null or not deck_card.card_data.is_pokemon():
				continue
			for slot: PokemonSlot in slots:
				if slot != null and slot.get_top_card() != null and deck_card.card_data.evolves_from_matches(slot.get_top_card().card_data):
					result.append(deck_card)
					break
		return result

	func _default_evolutions_for_slots(player: PlayerState, slots: Array[PokemonSlot]) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for slot: PokemonSlot in slots:
			for deck_card: CardInstance in player.deck:
				if deck_card not in result and deck_card.card_data != null and deck_card.card_data.evolves_from_matches(slot.get_card_data()):
					result.append(deck_card)
					break
		return result

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AttackBonusIfOwnBenchNameContains extends BaseEffect:
	var required_names: PackedStringArray = PackedStringArray()
	var bonus_damage: int = 0
	var attack_index_to_match: int = -1

	func _init(names: PackedStringArray, bonus: int, match_attack_index: int = -1) -> void:
		required_names = names.duplicate()
		bonus_damage = maxi(0, bonus)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or attacker.get_top_card() == null or state == null:
			return 0
		for slot: PokemonSlot in state.players[attacker.get_top_card().owner_index].bench:
			if slot == null or slot.get_top_card() == null:
				continue
			for identity: String in slot.get_card_data().rule_identity_names():
				var normalized := identity.to_lower()
				for required: String in required_names:
					if normalized.contains(required.to_lower()):
						return bonus_damage
		return 0

	func execute_attack(_attacker: PokemonSlot, _defender: PokemonSlot, _attack_index: int, _state: GameState) -> void:
		pass


class AttackApplySeverePoison extends BaseEffect:
	const EFFECT_TYPE := "csv10c_poison_damage_bonus"

	var total_poison_damage: int = 80
	var attack_index_to_match: int = -1

	func _init(total_damage: int = 80, match_attack_index: int = -1) -> void:
		total_poison_damage = maxi(10, total_damage)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func execute_attack(_attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if defender == null or state == null or not applies_to_attack_index(attack_index):
			return
		_apply_special_status(defender, "poisoned", state)
		if not defender.status_conditions.get("poisoned", false):
			return
		H.remove_effect_type(defender, EFFECT_TYPE)
		defender.effects.append({
			"type": EFFECT_TYPE,
			"amount": total_poison_damage - 10,
		})


class AbilityEvolvePlaceDamageCounters extends BaseEffect:
	const STEP_ID := "csv10c_evolve_damage_targets"

	var target_count: int = 1
	var counter_count: int = 2

	func _init(targets: int = 1, counters: int = 2) -> void:
		target_count = maxi(0, targets)
		counter_count = maxi(0, counters)

	func is_evolve_triggered_ability() -> bool:
		return true

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		var owner := pokemon.get_top_card().owner_index
		return state.current_player_index == owner \
			and H.evolved_from_hand_this_turn(pokemon, state) \
			and not pokemon.has_ability_used(state.turn_number) \
			and not state.players[1 - owner].get_all_pokemon().is_empty()

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		if card == null or state == null:
			return []
		var candidates := state.players[1 - card.owner_index].get_all_pokemon()
		if candidates.is_empty():
			return []
		var labels: Array[String] = []
		for slot: PokemonSlot in candidates:
			labels.append(slot.get_pokemon_name())
		var required := mini(target_count, candidates.size())
		return [{
			"id": STEP_ID,
			"title": "Choose %d opposing Pokemon to put %d damage counters on" % [required, counter_count],
			"items": candidates,
			"labels": labels,
			"presentation": "pokemon_slots",
			"min_select": required,
			"max_select": required,
			"allow_cancel": false,
		}]

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var opponent := state.players[1 - pokemon.get_top_card().owner_index]
		var candidates := opponent.get_all_pokemon()
		var selected: Array[PokemonSlot] = []
		var context := get_interaction_context(targets)
		for raw: Variant in context.get(STEP_ID, []):
			if raw is PokemonSlot and raw in candidates and raw not in selected:
				selected.append(raw)
				if selected.size() >= target_count:
					break
		if selected.is_empty() and not context.has(STEP_ID):
			selected.assign(candidates.slice(0, mini(target_count, candidates.size())))
		if selected.is_empty():
			pokemon.mark_ability_used(state.turn_number)
			return
		for slot: PokemonSlot in selected:
			slot.damage_counters += counter_count * 10
		pokemon.mark_ability_used(state.turn_number)


class AttackOptionalReturnPokemonStackToHand extends BaseEffect:
	const STEP_ID := "csv10c_crobat_return_choice"

	var attack_index_to_match: int = -1

	func _init(match_attack_index: int = -1) -> void:
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var player := state.players[card.owner_index]
		if H.player_field_return_to_hand_blocked(card.owner_index, state):
			return []
		var attacker := H.find_owner_slot(card, player)
		if attacker == null:
			return []
		if player.active_pokemon == attacker:
			if player.bench.is_empty():
				return []
			var labels: Array[String] = []
			for slot: PokemonSlot in player.bench:
				labels.append("Return Crobat and promote %s" % slot.get_pokemon_name())
			return [{
				"id": STEP_ID,
				"title": "You may return this Pokemon to your hand",
				"items": player.bench.duplicate(),
				"labels": labels,
				"min_select": 0,
				"max_select": 1,
				"allow_cancel": true,
				"force_confirm": true,
			}]
		return [{
			"id": STEP_ID,
			"title": "You may return this Pokemon to your hand",
			"items": ["return"],
			"labels": ["Return this Pokemon"],
			"min_select": 0,
			"max_select": 1,
			"allow_cancel": true,
			"force_confirm": true,
		}]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var owner := attacker.get_top_card().owner_index
		var player := state.players[owner]
		if H.player_field_return_to_hand_blocked(owner, state):
			return
		var raw: Array = get_attack_interaction_context().get(STEP_ID, [])
		if raw.is_empty():
			return
		var replacement: PokemonSlot = null
		if player.active_pokemon == attacker:
			if not (raw[0] is PokemonSlot) or raw[0] not in player.bench:
				return
			replacement = raw[0]
		elif str(raw[0]) != "return":
			return
		var was_active := player.active_pokemon == attacker
		if was_active and not _remove_active_and_promote(
			state,
			owner,
			attacker,
			replacement,
			"attack_return_self_to_hand"
		):
			return
		for pokemon_card: CardInstance in attacker.pokemon_stack:
			pokemon_card.face_up = true
			player.hand.append(pokemon_card)
		for energy: CardInstance in attacker.attached_energy:
			energy.face_up = true
			player.discard_pile.append(energy)
		if attacker.attached_tool != null:
			attacker.attached_tool.face_up = true
			player.discard_pile.append(attacker.attached_tool)
		attacker.pokemon_stack.clear()
		attacker.attached_energy.clear()
		attacker.attached_tool = null
		attacker.damage_counters = 0
		attacker.clear_all_status()
		attacker.effects.clear()
		if not was_active:
			player.bench.erase(attacker)

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AttackDelayedDiscardEndOpponentTurn extends BaseEffect:
	const EFFECT_TYPE := "csv10c_delayed_discard_end_turn"

	var attack_index_to_match: int = -1

	func _init(match_attack_index: int = -1) -> void:
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or defender == null or state == null or not applies_to_attack_index(attack_index):
			return
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		if processor != null and processor.has_method("is_attack_effect_prevented_by_defender_ability"):
			if bool(processor.call("is_attack_effect_prevented_by_defender_ability", attacker, defender, state)):
				return
		elif EffectMistEnergy.has_mist_energy(defender):
			return
		H.remove_effect_type(defender, EFFECT_TYPE)
		defender.effects.append({
			"type": EFFECT_TYPE,
			"turn": state.turn_number,
			"source_owner": attacker.get_top_card().owner_index,
		})


class AttackSpecialConditionCountDamage extends BaseEffect:
	var damage_per_condition: int = 100
	var printed_damage: int = 100
	var attack_index_to_match: int = -1

	func _init(per_condition: int = 100, printed: int = 100, match_attack_index: int = -1) -> void:
		damage_per_condition = maxi(0, per_condition)
		printed_damage = maxi(0, printed)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or attacker.get_top_card() == null or state == null:
			return 0
		var defender := state.players[1 - attacker.get_top_card().owner_index].active_pokemon
		if defender == null:
			return -printed_damage
		var condition_count := 0
		for active: Variant in defender.status_conditions.values():
			if bool(active):
				condition_count += 1
		return condition_count * damage_per_condition - printed_damage

	func execute_attack(_attacker: PokemonSlot, _defender: PokemonSlot, _attack_index: int, _state: GameState) -> void:
		pass


class AbilityActiveDamagedSearchNamedPokemonToBench extends BaseEffect:
	const SEARCH_STEP_ID := "csv10c_reactive_named_bench_search"

	var name_fragments: PackedStringArray = PackedStringArray()
	var max_count: int = 2

	func _init(fragments: PackedStringArray, count: int = 2) -> void:
		name_fragments = fragments.duplicate()
		max_count = maxi(0, count)

	func build_ucis_reactive_interaction_steps_spec_steps(source: PokemonSlot, attacker: PokemonSlot, state: GameState) -> Array[Dictionary]:
		if source == null or source.get_top_card() == null or attacker == null or attacker.get_top_card() == null or state == null:
			return []
		var owner := source.get_top_card().owner_index
		if state.players[owner].active_pokemon != source or attacker.get_top_card().owner_index == owner:
			return []
		var player := state.players[owner]
		var available := mini(max_count, BenchLimit.get_available_bench_space(state, player))
		var legal: Array[CardInstance] = []
		for card: CardInstance in player.deck:
			if _matches(card):
				legal.append(card)
		if available <= 0 or legal.is_empty():
			return []
		var step := build_full_library_search_step(
			SEARCH_STEP_ID,
			"警戒烟雾：选择最多%d张名字中带有“瓦斯弹”的宝可梦放于备战区" % mini(available, legal.size()),
			player.deck,
			legal,
			VISIBLE_SCOPE_OWN_FULL_DECK,
			0,
			mini(available, legal.size()),
			{"allow_cancel": true}
		)
		step["chooser_player_index"] = owner
		return [step]

	func on_damaged_by_attack(source: PokemonSlot, attacker: PokemonSlot, damage: int, state: GameState) -> void:
		if source == null or source.get_top_card() == null or attacker == null or damage <= 0 or state == null:
			return
		var owner := source.get_top_card().owner_index
		if state.players[owner].active_pokemon != source or attacker.get_top_card() == null or attacker.get_top_card().owner_index == owner:
			return
		var player := state.players[owner]
		var available := mini(max_count, BenchLimit.get_available_bench_space(state, player))
		if available <= 0:
			return
		var chosen: Array[CardInstance] = []
		var context := get_attack_interaction_context()
		for raw: Variant in context.get(SEARCH_STEP_ID, []):
			if raw is CardInstance and raw in player.deck and _matches(raw) and raw not in chosen:
				chosen.append(raw)
				if chosen.size() >= available:
					break
		if chosen.is_empty() and not context.has(SEARCH_STEP_ID):
			for card: CardInstance in player.deck:
				if _matches(card) and card not in chosen:
					chosen.append(card)
					if chosen.size() >= available:
						break
		for card: CardInstance in chosen:
			player.deck.erase(card)
			card.face_up = true
			var slot := PokemonSlot.new()
			slot.pokemon_stack.append(card)
			slot.turn_played = state.turn_number
			player.bench.append(slot)
		if not chosen.is_empty() or context.has(SEARCH_STEP_ID):
			player.shuffle_deck()

	func _matches(card: CardInstance) -> bool:
		if card == null or card.card_data == null or not card.card_data.is_pokemon():
			return false
		for identity: String in card.card_data.rule_identity_names():
			var normalized := identity.to_lower()
			for fragment: String in name_fragments:
				if normalized.contains(fragment.to_lower()):
					return true
		return false


class AttackBothFieldsNameCountDamage extends BaseEffect:
	var name_fragments: PackedStringArray = PackedStringArray()
	var damage_per_match: int = 40
	var printed_damage: int = 40
	var attack_index_to_match: int = -1

	func _init(fragments: PackedStringArray, per_match: int = 40, printed: int = 40, match_attack_index: int = -1) -> void:
		name_fragments = fragments.duplicate()
		damage_per_match = maxi(0, per_match)
		printed_damage = maxi(0, printed)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func get_damage_bonus(_attacker: PokemonSlot, state: GameState) -> int:
		if state == null:
			return -printed_damage
		var count := 0
		for player: PlayerState in state.players:
			for slot: PokemonSlot in player.get_all_pokemon():
				if _matches(slot.get_card_data() if slot != null else null):
					count += 1
		return count * damage_per_match - printed_damage

	func execute_attack(_attacker: PokemonSlot, _defender: PokemonSlot, _attack_index: int, _state: GameState) -> void:
		pass

	func _matches(card: CardData) -> bool:
		if card == null:
			return false
		for identity: String in card.rule_identity_names():
			var normalized := identity.to_lower()
			for fragment: String in name_fragments:
				if normalized.contains(fragment.to_lower()):
					return true
		return false


class AttackDamagedBenchCounterMultiplier extends BaseEffect:
	const STEP_ID := "csv10c_damaged_bench_target"

	var damage_per_counter: int = 20
	var attack_index_to_match: int = -1

	func _init(per_counter: int = 20, match_attack_index: int = -1) -> void:
		damage_per_counter = maxi(0, per_counter)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var candidates := state.players[1 - card.owner_index].bench.duplicate()
		if candidates.is_empty():
			return []
		var labels: Array[String] = []
		for slot: PokemonSlot in candidates:
			labels.append(slot.get_pokemon_name())
		return [{
			"id": STEP_ID,
			"title": "Choose an opposing Benched Pokemon",
			"items": candidates,
			"labels": labels,
			"presentation": "pokemon_slots",
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": false,
		}]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		var target: PokemonSlot = null
		var raw: Array = get_attack_interaction_context().get(STEP_ID, [])
		if not raw.is_empty() and raw[0] is PokemonSlot and raw[0] in opponent.bench:
			target = raw[0]
		elif not get_attack_interaction_context().has(STEP_ID) and not opponent.bench.is_empty():
			target = opponent.bench[0]
		if target == null:
			return
		if AbilityBenchImmune.prevents_opponent_attack_damage(target, attacker, state) or AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(target, state):
			return
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		if processor != null and processor.has_method("is_damage_prevented_by_defender_ability"):
			if bool(processor.call("is_damage_prevented_by_defender_ability", attacker, target, state)):
				return
		var damage := (target.damage_counters / 10) * damage_per_counter
		target.damage_counters += _calculate_attack_target_damage(attacker, target, damage, state)

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AbilityActiveBlocksOpponentCardType extends BaseEffect:
	var blocked_card_type: String = "Item"

	func _init(card_type: String = "Item") -> void:
		blocked_card_type = card_type

	func blocks_card_from_hand(source: PokemonSlot, card: CardInstance, player_index: int, state: GameState) -> bool:
		if source == null or source.get_top_card() == null or card == null or card.card_data == null or state == null:
			return false
		var owner := source.get_top_card().owner_index
		return player_index == 1 - owner \
			and state.players[owner].active_pokemon == source \
			and card.card_data.card_type == blocked_card_type


class AttackOwnBenchNamedDamageCounterScale extends BaseEffect:
	var name_fragments: PackedStringArray = PackedStringArray()
	var damage_per_counter: int = 10
	var printed_damage: int = 10
	var attack_index_to_match: int = -1

	func _init(fragments: PackedStringArray, per_counter: int = 10, printed: int = 10, match_attack_index: int = -1) -> void:
		name_fragments = fragments.duplicate()
		damage_per_counter = maxi(0, per_counter)
		printed_damage = maxi(0, printed)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or attacker.get_top_card() == null or state == null:
			return -printed_damage
		var counter_count := 0
		for slot: PokemonSlot in state.players[attacker.get_top_card().owner_index].bench:
			if _matches(slot.get_card_data() if slot != null else null):
				counter_count += slot.damage_counters / 10
		return counter_count * damage_per_counter - printed_damage

	func execute_attack(_attacker: PokemonSlot, _defender: PokemonSlot, _attack_index: int, _state: GameState) -> void:
		pass

	func _matches(card: CardData) -> bool:
		if card == null:
			return false
		for identity: String in card.rule_identity_names():
			var normalized := identity.to_lower()
			for fragment: String in name_fragments:
				if normalized.begins_with(fragment.to_lower()):
					return true
		return false


class AttackRevealOpponentHandCardToBottom extends BaseEffect:
	const STEP_ID := "csv10c_opponent_hand_to_bottom"

	var attack_index_to_match: int = -1

	func _init(match_attack_index: int = -1) -> void:
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var opponent := state.players[1 - card.owner_index]
		if opponent.hand.is_empty():
			return []
		var labels: Array[String] = []
		for hand_card: CardInstance in opponent.hand:
			labels.append(hand_card.card_data.display_name())
		return [{
			"id": STEP_ID,
			"title": "Look at the opponent's hand and choose a card to put on the bottom of their deck",
			"items": opponent.hand.duplicate(),
			"labels": labels,
			"presentation": "cards",
			"visible_scope": "opponent_hand_revealed",
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": false,
		}]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		if opponent.hand.is_empty():
			return
		var selected: CardInstance = null
		for raw: Variant in get_attack_interaction_context().get(STEP_ID, []):
			if raw is CardInstance and raw in opponent.hand:
				selected = raw
				break
		if selected == null and not get_attack_interaction_context().has(STEP_ID):
			selected = opponent.hand[0]
		if selected == null:
			return
		opponent.hand.erase(selected)
		selected.face_up = false
		opponent.deck.append(selected)

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AttackBonusIfSelfUndamaged extends BaseEffect:
	var bonus_damage: int = 120
	var attack_index_to_match: int = -1

	func _init(bonus: int = 120, match_attack_index: int = -1) -> void:
		bonus_damage = maxi(0, bonus)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func get_damage_bonus(attacker: PokemonSlot, _state: GameState) -> int:
		return bonus_damage if attacker != null and attacker.damage_counters <= 0 else 0

	func execute_attack(_attacker: PokemonSlot, _defender: PokemonSlot, _attack_index: int, _state: GameState) -> void:
		pass


class AttackDamageTwoOpponentPokemon extends BaseEffect:
	const STEP_ID := "csv10c_two_opponent_targets"

	var damage_amount: int = 50
	var target_count: int = 2
	var attack_index_to_match: int = -1

	func _init(damage: int = 50, count: int = 2, match_attack_index: int = -1) -> void:
		damage_amount = maxi(0, damage)
		target_count = maxi(0, count)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var candidates := state.players[1 - card.owner_index].get_all_pokemon()
		if candidates.is_empty():
			return []
		var labels: Array[String] = []
		for slot: PokemonSlot in candidates:
			labels.append(slot.get_pokemon_name())
		var required := mini(target_count, candidates.size())
		return [{
			"id": STEP_ID,
			"title": "Choose %d opposing Pokemon" % required,
			"items": candidates,
			"labels": labels,
			"presentation": "pokemon_slots",
			"min_select": required,
			"max_select": required,
			"allow_cancel": false,
		}]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		var candidates := opponent.get_all_pokemon()
		var selected: Array[PokemonSlot] = []
		var context := get_attack_interaction_context()
		for raw: Variant in context.get(STEP_ID, []):
			if raw is PokemonSlot and raw in candidates and raw not in selected:
				selected.append(raw)
				if selected.size() >= target_count:
					break
		if selected.is_empty() and not context.has(STEP_ID):
			selected.assign(candidates.slice(0, mini(target_count, candidates.size())))
		for target: PokemonSlot in selected:
			if target != opponent.active_pokemon and AbilityBenchImmune.prevents_opponent_attack_damage(target, attacker, state):
				continue
			if AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(target, state):
				continue
			var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
			if processor != null and processor.has_method("is_damage_prevented_by_defender_ability"):
				if bool(processor.call("is_damage_prevented_by_defender_ability", attacker, target, state)):
					continue
			target.damage_counters += _calculate_attack_target_damage(attacker, target, damage_amount, state)

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AbilitySearchPsychicMetalEnergyAssign extends BaseEffect:
	const STEP_ID := "csv10c_x_boot_assignments"

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		var owner := pokemon.get_top_card().owner_index
		var player := state.players[owner]
		return state.current_player_index == owner \
			and not pokemon.has_ability_used(state.turn_number) \
			and not _energies(player).is_empty() \
			and not _targets(player).is_empty()

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		if card == null or state == null:
			return []
		var player := state.players[card.owner_index]
		var sources := _energies(player)
		var targets := _targets(player)
		if sources.is_empty() or targets.is_empty():
			return []
		var source_labels: Array[String] = []
		for energy: CardInstance in sources:
			source_labels.append(energy.card_data.display_name())
		var target_labels: Array[String] = []
		for slot: PokemonSlot in targets:
			target_labels.append(slot.get_pokemon_name())
		var step := build_full_library_card_assignment_step(
			STEP_ID,
			"Choose up to 1 Basic Psychic Energy and 1 Basic Metal Energy to attach",
			player.deck,
			sources,
			source_labels,
			targets,
			target_labels,
			0,
			mini(2, sources.size()),
			VISIBLE_SCOPE_OWN_FULL_DECK,
			true,
			{"force_confirm": true}
		)
		step["source_bucket_keys"] = sources.map(func(energy: CardInstance) -> String: return _energy_type(energy))
		step["max_assignments_per_source_bucket"] = {"P": 1, "M": 1}
		return [step]

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, raw_targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var player := state.players[pokemon.get_top_card().owner_index]
		var context := get_interaction_context(raw_targets)
		var assignments := _resolve_assignments(player, context)
		for assignment: Dictionary in assignments:
			var source: CardInstance = assignment.get("source")
			var target: PokemonSlot = assignment.get("target")
			if source == null or target == null or source not in player.deck:
				continue
			player.deck.erase(source)
			source.face_up = true
			target.attached_energy.append(source)
		player.shuffle_deck()
		pokemon.mark_ability_used(state.turn_number)

	func _resolve_assignments(player: PlayerState, context: Dictionary) -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		var used_types: Dictionary = {}
		var legal_targets := _targets(player)
		for raw: Variant in context.get(STEP_ID, []):
			if not (raw is Dictionary):
				continue
			var source: CardInstance = raw.get("source")
			var target: PokemonSlot = raw.get("target")
			var energy_type := _energy_type(source)
			if source not in player.deck or target not in legal_targets or energy_type == "" or used_types.has(energy_type):
				continue
			used_types[energy_type] = true
			result.append({"source": source, "target": target})
			if result.size() >= 2:
				break
		if not result.is_empty() or context.has(STEP_ID):
			return result
		for source: CardInstance in _energies(player):
			var energy_type := _energy_type(source)
			if used_types.has(energy_type):
				continue
			used_types[energy_type] = true
			result.append({"source": source, "target": legal_targets[result.size() % legal_targets.size()]})
		return result

	func _energies(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in player.deck:
			if _energy_type(card) != "":
				result.append(card)
		return result

	func _targets(player: PlayerState) -> Array[PokemonSlot]:
		var result: Array[PokemonSlot] = []
		for slot: PokemonSlot in player.get_all_pokemon():
			if slot.get_card_data() != null and slot.get_card_data().energy_type in ["P", "M"]:
				result.append(slot)
		return result

	func _energy_type(card: CardInstance) -> String:
		if card == null or card.card_data == null or card.card_data.card_type != "Basic Energy":
			return ""
		var energy_type := card.card_data.energy_provides if card.card_data.energy_provides != "" else card.card_data.energy_type
		return energy_type if energy_type in ["P", "M"] else ""


class AbilityActiveHealHandEnergyAttachmentTarget extends BaseEffect:
	var heal_amount: int = 90

	func _init(amount: int = 90) -> void:
		heal_amount = maxi(0, amount)

	func on_energy_attached_from_hand(source: PokemonSlot, player_index: int, target: PokemonSlot, state: GameState) -> void:
		if source == null or source.get_top_card() == null or target == null or state == null:
			return
		var owner := source.get_top_card().owner_index
		if player_index != owner or state.players[owner].active_pokemon != source or target not in state.players[owner].get_all_pokemon():
			return
		target.damage_counters = maxi(0, target.damage_counters - heal_amount)


class AttackDiscardSelectedSelfEnergy extends BaseEffect:
	const STEP_ID := "csv10c_self_energy_discard"

	var discard_count: int = 2
	var attack_index_to_match: int = -1

	func _init(count: int = 2, match_attack_index: int = -1) -> void:
		discard_count = maxi(0, count)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var player := state.players[card.owner_index]
		var attacker := H.find_owner_slot(card, player)
		if attacker == null or attacker.attached_energy.is_empty():
			return []
		var labels: Array[String] = []
		for energy: CardInstance in attacker.attached_energy:
			labels.append(energy.card_data.display_name())
		var required := mini(discard_count, attacker.attached_energy.size())
		return [{
			"id": STEP_ID,
			"title": "Choose %d Energy attached to this Pokemon to discard" % required,
			"items": attacker.attached_energy.duplicate(),
			"labels": labels,
			"card_groups": build_attached_card_groups(player, attacker.attached_energy),
			"transparent_battlefield_dialog": true,
			"min_select": required,
			"max_select": required,
			"allow_cancel": false,
		}]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var selected: Array[CardInstance] = []
		var context := get_attack_interaction_context()
		for raw: Variant in context.get(STEP_ID, []):
			if raw is CardInstance and raw in attacker.attached_energy and raw not in selected:
				selected.append(raw)
				if selected.size() >= discard_count:
					break
		if selected.is_empty() and not context.has(STEP_ID):
			selected.assign(attacker.attached_energy.slice(0, mini(discard_count, attacker.attached_energy.size())))
		if context.has(STEP_ID) and selected.size() != mini(discard_count, attacker.attached_energy.size()):
			return
		var player := state.players[attacker.get_top_card().owner_index]
		for energy: CardInstance in selected:
			attacker.attached_energy.erase(energy)
			player.discard_pile.append(energy)
			_record_attack_effect_discarded_attached_energy(attacker, energy, state)

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AttackRecoilIfAllCoinFlipsTails extends BaseEffect:
	var coin_count: int = 2
	var recoil_damage: int = 90
	var attack_index_to_match: int = -1
	var coin_flipper: CoinFlipper = null

	func _init(count: int = 2, recoil: int = 90, match_attack_index: int = -1, flipper: CoinFlipper = null) -> void:
		coin_count = maxi(0, count)
		recoil_damage = maxi(0, recoil)
		attack_index_to_match = match_attack_index
		coin_flipper = flipper

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, _state: GameState) -> void:
		if attacker == null or not applies_to_attack_index(attack_index):
			return
		var flipper := coin_flipper if coin_flipper != null else CoinFlipper.new()
		for _index: int in coin_count:
			if flipper.flip():
				return
		attacker.damage_counters += recoil_damage


class AttackCopyOpponentTopDeckPokemonAttack extends BaseEffect:
	const STEP_ID := "csv10c_persian_top_attack"

	var processor: EffectProcessor = null
	var reveal_count: int = 10
	var attack_index_to_match: int = -1

	func _init(effect_processor: EffectProcessor, count: int = 10, match_attack_index: int = -1) -> void:
		processor = effect_processor
		reveal_count = maxi(0, count)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var opponent := state.players[1 - card.owner_index]
		var revealed: Array[CardInstance] = []
		revealed.assign(opponent.deck.slice(0, mini(reveal_count, opponent.deck.size())))
		var options: Array[Dictionary] = []
		var labels: Array[String] = []
		for source: CardInstance in revealed:
			if source == null or source.card_data == null or not source.card_data.is_pokemon():
				continue
			if processor != null:
				processor.register_pokemon_card(source.card_data)
			for copied_index: int in source.card_data.attacks.size():
				var copied_attack := source.card_data.attacks[copied_index]
				var attack_name := str(copied_attack.get("name", ""))
				if bool(copied_attack.get("is_vstar_power", false)) or attack_name in ["高傲指令", "Haughty Orders"]:
					continue
				options.append({
					"source_card": source,
					"source_effect_id": source.card_data.effect_id,
					"attack_index": copied_index,
					"attack": copied_attack,
				})
				labels.append("%s - %s" % [source.card_data.display_name(), CardData.dictionary_display_name(copied_attack)])
		return [{
			"id": STEP_ID,
			"title": "Reveal the top %d opponent deck cards; you may use an attack from a Pokemon found there" % reveal_count,
			"items": options,
			"labels": labels,
			"presentation": "action_hud",
			"visible_scope": "opponent_top_cards_revealed",
			"revealed_cards": revealed,
			"min_select": 0,
			"max_select": 1,
			"allow_cancel": true,
			"force_confirm": true,
		}]

	func build_ucis_followup_attack_interaction_steps_spec_steps(
		card: CardInstance,
		_attack: Dictionary,
		state: GameState,
		resolved_context: Dictionary
	) -> Array[Dictionary]:
		if processor == null or _has_followup_context(resolved_context):
			return []
		var option := _selected_option(resolved_context)
		if option.is_empty():
			return []
		return processor.get_attack_interaction_steps_by_id(
			str(option.get("source_effect_id", "")),
			int(option.get("attack_index", -1)),
			card,
			option.get("attack", {}),
			state,
			get_script()
		)

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		var option := _selected_option(get_attack_interaction_context())
		if option.is_empty():
			return 0
		var total := DamageCalculator.new().parse_damage(str((option.get("attack", {}) as Dictionary).get("damage", "")))
		if processor != null:
			total += processor.get_attack_damage_bonus_by_id(
				str(option.get("source_effect_id", "")),
				int(option.get("attack_index", -1)),
				attacker,
				state,
				[get_attack_interaction_context()],
				get_script()
			)
		return total

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		var option := _selected_option(get_attack_interaction_context())
		if processor != null and not option.is_empty():
			processor.execute_attack_effect_by_id(
				str(option.get("source_effect_id", "")),
				int(option.get("attack_index", -1)),
				attacker,
				defender,
				state,
				[get_attack_interaction_context()],
				get_script()
			)
		opponent.shuffle_deck()

	func _selected_option(context: Dictionary) -> Dictionary:
		var raw: Array = context.get(STEP_ID, [])
		return raw[0] if not raw.is_empty() and raw[0] is Dictionary else {}

	func _has_followup_context(context: Dictionary) -> bool:
		return has_resolved_non_internal_interaction_step(context, [STEP_ID])

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AttackBothPlayersDiscardSelectedHandCard extends BaseEffect:
	const OWN_STEP_ID := "csv10c_own_hand_discard"
	const OPPONENT_STEP_ID := "csv10c_opponent_hand_discard"

	var attack_index_to_match: int = -1

	func _init(match_attack_index: int = -1) -> void:
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var own := state.players[card.owner_index]
		var opponent := state.players[1 - card.owner_index]
		var steps: Array[Dictionary] = []
		if not own.hand.is_empty():
			steps.append(_hand_step(OWN_STEP_ID, "Choose 1 card from your hand to discard", own.hand, false))
		if not opponent.hand.is_empty():
			steps.append(_hand_step(OPPONENT_STEP_ID, "Opponent chooses 1 card from their hand to discard", opponent.hand, true))
		return steps

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var own := state.players[attacker.get_top_card().owner_index]
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		_discard_selection(own, OWN_STEP_ID)
		_discard_selection(opponent, OPPONENT_STEP_ID)

	func _hand_step(step_id: String, title: String, cards: Array[CardInstance], opponent_chooses: bool) -> Dictionary:
		var labels: Array[String] = []
		for card: CardInstance in cards:
			labels.append(card.card_data.display_name())
		return {
			"id": step_id,
			"title": title,
			"items": cards.duplicate(),
			"labels": labels,
			"presentation": "cards",
			"opponent_chooses": opponent_chooses,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": false,
		}

	func _discard_selection(player: PlayerState, step_id: String) -> void:
		if player.hand.is_empty():
			return
		var selected: CardInstance = null
		for raw: Variant in get_attack_interaction_context().get(step_id, []):
			if raw is CardInstance and raw in player.hand:
				selected = raw
				break
		if selected == null and not get_attack_interaction_context().has(step_id):
			selected = player.hand[0]
		if selected != null:
			player.hand.erase(selected)
			player.discard_pile.append(selected)

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AttackRocketSupporterDiscardCountDamage extends BaseEffect:
	var damage_per_card: int = 20
	var printed_damage: int = 20
	var attack_index_to_match: int = -1

	func _init(per_card: int = 20, printed: int = 20, match_attack_index: int = -1) -> void:
		damage_per_card = maxi(0, per_card)
		printed_damage = maxi(0, printed)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or attacker.get_top_card() == null or state == null:
			return -printed_damage
		var count := 0
		for card: CardInstance in state.players[attacker.get_top_card().owner_index].discard_pile:
			if card == null or card.card_data == null or card.card_data.card_type != "Supporter":
				continue
			for identity: String in card.card_data.rule_identity_names():
				var normalized := identity.to_lower()
				if normalized.contains("火箭队") or normalized.contains("team rocket"):
					count += 1
					break
		return count * damage_per_card - printed_damage

	func execute_attack(_attacker: PokemonSlot, _defender: PokemonSlot, _attack_index: int, _state: GameState) -> void:
		pass


class AbilityDiscardTwoDrawOne extends BaseEffect:
	const STEP_ID := "csv10c_reconstruct_discard"

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		var owner := pokemon.get_top_card().owner_index
		return state.current_player_index == owner \
			and not pokemon.has_ability_used(state.turn_number) \
			and state.players[owner].hand.size() >= 2

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		if card == null or state == null:
			return []
		var hand := state.players[card.owner_index].hand
		if hand.size() < 2:
			return []
		var labels: Array[String] = []
		for hand_card: CardInstance in hand:
			labels.append(hand_card.card_data.display_name())
		return [{
			"id": STEP_ID,
			"title": "Choose 2 cards from your hand to discard",
			"items": hand.duplicate(),
			"labels": labels,
			"presentation": "cards",
			"min_select": 2,
			"max_select": 2,
			"allow_cancel": true,
		}]

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var owner := pokemon.get_top_card().owner_index
		var player := state.players[owner]
		var selected: Array[CardInstance] = []
		var context := get_interaction_context(targets)
		for raw: Variant in context.get(STEP_ID, []):
			if raw is CardInstance and raw in player.hand and raw not in selected:
				selected.append(raw)
				if selected.size() >= 2:
					break
		if selected.is_empty() and not context.has(STEP_ID):
			selected.assign(player.hand.slice(0, 2))
		if selected.size() != 2:
			return
		var discarded := _discard_cards_from_hand_with_log(state, owner, selected, pokemon.get_top_card(), "ability")
		if discarded.size() != 2:
			return
		_draw_cards_with_log(state, owner, 1, pokemon.get_top_card(), "ability")
		pokemon.mark_ability_used(state.turn_number)


class AbilityNonStackingNamedTeamDamageBoost extends BaseEffect:
	var damage_bonus: int = 30
	var name_prefixes: PackedStringArray = PackedStringArray()

	func _init(bonus: int = 30, prefixes: PackedStringArray = PackedStringArray()) -> void:
		damage_bonus = maxi(0, bonus)
		name_prefixes = prefixes.duplicate()

	func get_attack_modifier_for_attacker(source: PokemonSlot, attacker: PokemonSlot, state: GameState, defender: PokemonSlot = null) -> int:
		if source == null or source.get_top_card() == null or attacker == null or attacker.get_top_card() == null or state == null:
			return 0
		var owner := source.get_top_card().owner_index
		if attacker.get_top_card().owner_index != owner or defender != state.players[1 - owner].active_pokemon:
			return 0
		if not _matches(attacker.get_card_data()):
			return 0
		var effect_id := source.get_card_data().effect_id
		var effect_processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		for candidate: PokemonSlot in state.players[owner].get_all_pokemon():
			if candidate == null or candidate.get_card_data() == null or candidate.get_card_data().effect_id != effect_id:
				continue
			if effect_processor != null and effect_processor.has_method("is_ability_disabled") and bool(effect_processor.call("is_ability_disabled", candidate, state)):
				continue
			return damage_bonus if candidate == source else 0
		return 0

	func _matches(card: CardData) -> bool:
		if card == null:
			return false
		for identity: String in card.rule_identity_names():
			var normalized := identity.to_lower()
			for prefix: String in name_prefixes:
				if normalized.begins_with(prefix.to_lower()):
					return true
		return false


class AbilityEqualHandSizeFreeAttack extends BaseEffect:
	var attack_names: PackedStringArray = PackedStringArray()

	func _init(names: PackedStringArray = PackedStringArray()) -> void:
		attack_names = names.duplicate()

	func is_cost_modifier_ability() -> bool:
		return true

	func get_attack_any_cost_modifier(attacker: PokemonSlot, attack: Dictionary, state: GameState) -> int:
		if attacker == null or attacker.get_top_card() == null or state == null:
			return 0
		if not attack_names.is_empty() and str(attack.get("name", "")) not in attack_names:
			return 0
		var owner := attacker.get_top_card().owner_index
		if owner < 0 or owner >= state.players.size() or state.players.size() < 2:
			return 0
		if state.players[owner].hand.size() != state.players[1 - owner].hand.size():
			return 0
		return -CardData.normalize_attack_cost(str(attack.get("cost", ""))).length()

	func execute_ability(_pokemon: PokemonSlot, _ability_index: int, _targets: Array, _state: GameState) -> void:
		pass


class AttackDiscardDefenderToolBeforeDamage extends BaseEffect:
	var attack_index_to_match: int = -1

	func _init(match_attack_index: int = -1) -> void:
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func before_attack_damage(attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if defender == null or state == null or not applies_to_attack_index(attack_index):
			return
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		if attacker != null and processor != null and processor.has_method("is_attack_effect_prevented_by_defender_ability"):
			if bool(processor.call("is_attack_effect_prevented_by_defender_ability", attacker, defender, state)):
				return
		var tool := defender.attached_tool
		if tool == null:
			return
		defender.attached_tool = null
		var owner := tool.owner_index
		if owner < 0 or owner >= state.players.size():
			for player_index: int in state.players.size():
				if defender in state.players[player_index].get_all_pokemon():
					owner = player_index
					break
		if owner >= 0 and owner < state.players.size():
			state.players[owner].discard_card(tool)

	func execute_attack(_attacker: PokemonSlot, _defender: PokemonSlot, _attack_index: int, _state: GameState) -> void:
		# This effect resolves through before_attack_damage so Tool-based defense and HP
		# are already gone when the printed damage is calculated.
		pass


class AbilityEvolveRecoverNamedItems extends BaseEffect:
	const STEP_ID := "csv10c_arven_sandwiches"

	var max_count: int = 2
	var names: PackedStringArray = PackedStringArray()

	func _init(required_names: PackedStringArray, count: int = 2) -> void:
		names = required_names.duplicate()
		max_count = maxi(0, count)

	func is_evolve_triggered_ability() -> bool:
		return true

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		var owner := pokemon.get_top_card().owner_index
		return state.current_player_index == owner \
			and H.evolved_from_hand_this_turn(pokemon, state) \
			and not pokemon.has_ability_used(state.turn_number) \
			and not _candidates(state.players[owner]).is_empty()

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		if card == null or state == null:
			return []
		var candidates := _candidates(state.players[card.owner_index])
		if candidates.is_empty():
			return []
		var labels: Array[String] = []
		for item: CardInstance in candidates:
			labels.append(item.card_data.display_name())
		return [{
			"id": STEP_ID,
			"title": "Choose up to %d Arven's Sandwich cards from your discard pile" % max_count,
			"items": candidates,
			"labels": labels,
			"presentation": "cards",
			"min_select": 0,
			"max_select": mini(max_count, candidates.size()),
			"allow_cancel": true,
			"force_confirm": true,
		}]

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var player := state.players[pokemon.get_top_card().owner_index]
		var candidates := _candidates(player)
		var selected: Array[CardInstance] = []
		var context := get_interaction_context(targets)
		for raw: Variant in context.get(STEP_ID, []):
			if raw is CardInstance and raw in candidates and raw not in selected:
				selected.append(raw)
				if selected.size() >= max_count:
					break
		if selected.is_empty() and not context.has(STEP_ID):
			selected.assign(candidates.slice(0, mini(max_count, candidates.size())))
		for item: CardInstance in selected:
			player.discard_pile.erase(item)
			player.hand.append(item)
		pokemon.mark_ability_used(state.turn_number)

	func _candidates(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in player.discard_pile:
			if _matches(card):
				result.append(card)
		return result

	func _matches(card: CardInstance) -> bool:
		if card == null or card.card_data == null or card.card_data.card_type != "Item":
			return false
		for identity: String in card.card_data.rule_identity_names():
			for required: String in names:
				if identity.to_lower() == required.to_lower():
					return true
		return false


class AttackReduceDefenderOutgoingDamageNextTurn extends BaseEffect:
	var amount: int = 20
	var attack_index_to_match: int = -1

	func _init(reduction: int = 20, match_attack_index: int = -1) -> void:
		amount = maxi(0, reduction)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if defender == null or state == null or not applies_to_attack_index(attack_index):
			return
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		if attacker != null and processor != null and processor.has_method("is_attack_effect_prevented_by_defender_ability"):
			if bool(processor.call("is_attack_effect_prevented_by_defender_ability", attacker, defender, state)):
				return
		defender.effects.append({
			"type": H.OUTGOING_DAMAGE_REDUCTION_EFFECT_TYPE,
			"amount": amount,
			"turn": state.turn_number,
		})


class AbilityEvolveGustOpponentBench extends BaseEffect:
	const STEP_ID := "csv10c_challenge_horn_target"

	func is_evolve_triggered_ability() -> bool:
		return true

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		var owner := pokemon.get_top_card().owner_index
		return state.current_player_index == owner \
			and H.evolved_from_hand_this_turn(pokemon, state) \
			and not pokemon.has_ability_used(state.turn_number) \
			and not state.players[1 - owner].bench.is_empty()

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		if card == null or state == null:
			return []
		var opponent := state.players[1 - card.owner_index]
		if opponent.bench.is_empty():
			return []
		var labels: Array[String] = []
		for slot: PokemonSlot in opponent.bench:
			labels.append(slot.get_pokemon_name())
		return [{
			"id": STEP_ID,
			"title": "Choose an opponent's Benched Pokemon to switch into the Active Spot",
			"items": opponent.bench.duplicate(),
			"labels": labels,
			"presentation": "pokemon_slots",
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		}]

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var owner := pokemon.get_top_card().owner_index
		var opponent := state.players[1 - owner]
		var selected: PokemonSlot = null
		var context := get_interaction_context(targets)
		for raw: Variant in context.get(STEP_ID, []):
			if raw is PokemonSlot and raw in opponent.bench:
				selected = raw
				break
		if selected == null and not context.has(STEP_ID):
			selected = opponent.bench[0]
		if selected == null:
			pokemon.mark_ability_used(state.turn_number)
			return
		_switch_active_with_bench(state, 1 - owner, selected, "ability_gust", true)
		pokemon.mark_ability_used(state.turn_number)


class AttackCancelUnlessOpponentPrizeCount extends BaseEffect:
	var allowed_counts: PackedInt32Array = PackedInt32Array()
	var attack_index_to_match: int = -1

	func _init(counts: PackedInt32Array, match_attack_index: int = -1) -> void:
		allowed_counts = counts.duplicate()
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func cancels_attack_damage(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> bool:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return false
		var owner := attacker.get_top_card().owner_index
		return state.players[1 - owner].prizes.size() not in allowed_counts

	func execute_attack(_attacker: PokemonSlot, _defender: PokemonSlot, _attack_index: int, _state: GameState) -> void:
		pass


class EffectHealSelectedPokemonDiscardEnergy extends BaseEffect:
	const STEP_ID := "csv10c_heal_energy_assignment"

	var heal_amount: int = 60

	func _init(amount: int = 60) -> void:
		heal_amount = maxi(0, amount)

	func can_execute(card: CardInstance, state: GameState) -> bool:
		if card == null or state == null:
			return false
		return not _eligible_pairs(state.players[card.owner_index]).is_empty()

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		if card == null or state == null:
			return []
		var player := state.players[card.owner_index]
		var pairs := _eligible_pairs(player)
		if pairs.is_empty():
			return []
		var energies: Array = []
		var energy_labels: Array[String] = []
		var slots: Array = []
		var slot_labels: Array[String] = []
		for pair: Dictionary in pairs:
			var energy: CardInstance = pair.get("source", null)
			var slot: PokemonSlot = pair.get("target", null)
			if energy != null and energy not in energies:
				energies.append(energy)
				energy_labels.append(energy.card_data.display_name())
			if slot != null and slot not in slots:
				slots.append(slot)
				slot_labels.append(slot.get_pokemon_name())
		var step := build_card_assignment_step(
			STEP_ID,
			"Choose a damaged Pokemon to heal 60, then discard 1 Energy attached to it",
			energies,
			energy_labels,
			slots,
			slot_labels,
			1,
			1,
			true
		)
		var source_groups: Array[Dictionary] = []
		var source_exclude_targets := {}
		for slot: PokemonSlot in player.get_all_pokemon():
			var energy_indices: Array[int] = []
			for energy: CardInstance in slot.attached_energy:
				var source_index := energies.find(energy)
				if source_index < 0:
					continue
				energy_indices.append(source_index)
				var allowed_target_index := slots.find(slot)
				var excluded: Array[int] = []
				for target_index: int in slots.size():
					if target_index != allowed_target_index:
						excluded.append(target_index)
				source_exclude_targets[source_index] = excluded
			if not energy_indices.is_empty():
				source_groups.append({"slot": slot, "energy_indices": energy_indices})
		step["source_groups"] = source_groups
		step["source_exclude_targets"] = source_exclude_targets
		return [step]

	func execute(card: CardInstance, targets: Array, state: GameState) -> void:
		if not can_execute(card, state):
			return
		var player := state.players[card.owner_index]
		var selected := _resolve_pair(player, get_interaction_context(targets))
		if selected.is_empty():
			return
		var energy: CardInstance = selected.get("source", null)
		var slot: PokemonSlot = selected.get("target", null)
		if energy == null or slot == null:
			return
		slot.damage_counters = maxi(0, slot.damage_counters - heal_amount)
		slot.attached_energy.erase(energy)
		player.discard_card(energy)

	func _resolve_pair(player: PlayerState, context: Dictionary) -> Dictionary:
		var pairs := _eligible_pairs(player)
		for raw: Variant in context.get(STEP_ID, []):
			if not (raw is Dictionary):
				continue
			var source: Variant = raw.get("source", null)
			var target: Variant = raw.get("target", null)
			for pair: Dictionary in pairs:
				if pair.get("source", null) == source and pair.get("target", null) == target:
					return pair
		if not context.has(STEP_ID) and not pairs.is_empty():
			return pairs[0]
		return {}

	func _eligible_pairs(player: PlayerState) -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		for slot: PokemonSlot in player.get_all_pokemon():
			if slot == null or slot.damage_counters <= 0:
				continue
			for energy: CardInstance in slot.attached_energy:
				result.append({"source": energy, "target": slot})
		return result


class EffectReturnDiscardCardsToDeck extends BaseEffect:
	const STEP_ID := "csv10c_recycle_discard_cards"

	var max_count: int = 5
	var filter_kind: String = "basic_energy"

	func _init(kind: String, count: int = 5) -> void:
		filter_kind = kind
		max_count = maxi(0, count)

	func can_execute(card: CardInstance, state: GameState) -> bool:
		return card != null and state != null and not _legal(state.players[card.owner_index]).is_empty()

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		if card == null or state == null:
			return []
		var legal := _legal(state.players[card.owner_index])
		if legal.is_empty():
			return []
		var labels: Array[String] = []
		for candidate: CardInstance in legal:
			labels.append(candidate.card_data.display_name())
		return [{
			"id": STEP_ID,
			"title": "Choose up to %d cards from your discard pile to shuffle into your deck" % max_count,
			"items": legal,
			"labels": labels,
			"presentation": "cards",
			"min_select": 0,
			"max_select": mini(max_count, legal.size()),
			"allow_cancel": true,
			"force_confirm": true,
		}]

	func execute(card: CardInstance, targets: Array, state: GameState) -> void:
		if card == null or state == null:
			return
		var player := state.players[card.owner_index]
		var legal := _legal(player)
		var selected: Array[CardInstance] = []
		var context := get_interaction_context(targets)
		for raw: Variant in context.get(STEP_ID, []):
			if raw is CardInstance and raw in legal and raw not in selected:
				selected.append(raw)
				if selected.size() >= max_count:
					break
		if selected.is_empty() and not context.has(STEP_ID):
			selected.assign(legal.slice(0, mini(max_count, legal.size())))
		for selected_card: CardInstance in selected:
			player.discard_pile.erase(selected_card)
			selected_card.face_up = false
			player.deck.append(selected_card)
		player.shuffle_deck()

	func _legal(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in player.discard_pile:
			if card == null or card.card_data == null:
				continue
			if filter_kind == "basic_energy" and card.card_data.card_type == "Basic Energy":
				result.append(card)
			elif filter_kind == "pokemon" and card.card_data.is_pokemon():
				result.append(card)
		return result


class EffectExchangeAllPrizes extends BaseEffect:
	func can_execute(card: CardInstance, state: GameState) -> bool:
		return card != null and state != null and not state.players[card.owner_index].prizes.is_empty()

	func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
		if card == null or state == null:
			return
		var player := state.players[card.owner_index]
		var count := player.prizes.size()
		if count <= 0:
			return
		var old_prizes := player.prizes.duplicate()
		player.shuffle_cards(old_prizes, "exchange_all_prizes")
		player.prizes.clear()
		for old_prize: CardInstance in old_prizes:
			old_prize.face_up = false
			player.deck.append(old_prize)
		for _index: int in count:
			if player.deck.is_empty():
				break
			var new_prize: CardInstance = player.deck.pop_front()
			new_prize.face_up = false
			player.prizes.append(new_prize)
		player.reset_prize_layout()


class EffectHealActiveNamedTeam extends BaseEffect:
	var normal_heal: int = 30
	var named_heal: int = 100
	var prefixes: PackedStringArray = PackedStringArray()

	func _init(normal_amount: int, named_amount: int, team_prefixes: PackedStringArray) -> void:
		normal_heal = maxi(0, normal_amount)
		named_heal = maxi(0, named_amount)
		prefixes = team_prefixes.duplicate()

	func can_execute(card: CardInstance, state: GameState) -> bool:
		if card == null or state == null:
			return false
		var active := state.players[card.owner_index].active_pokemon
		return active != null and active.damage_counters > 0

	func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
		if not can_execute(card, state):
			return
		var active := state.players[card.owner_index].active_pokemon
		var amount := named_heal if _matches(active.get_card_data()) else normal_heal
		active.damage_counters = maxi(0, active.damage_counters - amount)

	func _matches(card: CardData) -> bool:
		if card == null:
			return false
		for identity: String in card.rule_identity_names():
			var normalized := identity.to_lower()
			for prefix: String in prefixes:
				if normalized.begins_with(prefix.to_lower()):
					return true
		return false


class EffectSearchBasicNamedPokemonToBench extends BaseEffect:
	const STEP_ID := "csv10c_hop_bag_targets"

	var max_count: int = 2
	var prefixes: PackedStringArray = PackedStringArray()

	func _init(team_prefixes: PackedStringArray, count: int = 2) -> void:
		prefixes = team_prefixes.duplicate()
		max_count = maxi(0, count)

	func can_execute(card: CardInstance, state: GameState) -> bool:
		if card == null or state == null:
			return false
		var player := state.players[card.owner_index]
		return BenchLimit.get_available_bench_space(state, player) > 0 and not _legal(player).is_empty()

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		if card == null or state == null:
			return []
		var player := state.players[card.owner_index]
		var legal := _legal(player)
		var available := mini(max_count, BenchLimit.get_available_bench_space(state, player))
		if legal.is_empty() or available <= 0:
			return []
		return [build_full_library_search_step(
			STEP_ID,
			"Choose up to %d Basic Hop's Pokemon to put on your Bench" % max_count,
			player.deck,
			legal,
			VISIBLE_SCOPE_OWN_FULL_DECK,
			0,
			mini(available, legal.size()),
			{"allow_cancel": true}
		)]

	func execute(card: CardInstance, targets: Array, state: GameState) -> void:
		if card == null or state == null:
			return
		var player := state.players[card.owner_index]
		var legal := _legal(player)
		var available := mini(max_count, BenchLimit.get_available_bench_space(state, player))
		var selected: Array[CardInstance] = []
		var context := get_interaction_context(targets)
		for raw: Variant in context.get(STEP_ID, []):
			if raw is CardInstance and raw in legal and raw not in selected:
				selected.append(raw)
				if selected.size() >= available:
					break
		if selected.is_empty() and not context.has(STEP_ID):
			selected.assign(legal.slice(0, mini(available, legal.size())))
		for pokemon: CardInstance in selected:
			if pokemon not in player.deck or BenchLimit.is_bench_full(state, player):
				continue
			player.deck.erase(pokemon)
			pokemon.face_up = true
			var slot := PokemonSlot.new()
			slot.pokemon_stack.append(pokemon)
			slot.turn_played = state.turn_number
			player.bench.append(slot)
		player.shuffle_deck()

	func _legal(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in player.deck:
			if card == null or card.card_data == null or not card.card_data.is_basic_pokemon():
				continue
			for identity: String in card.card_data.rule_identity_names():
				var normalized := identity.to_lower()
				var matched := false
				for prefix: String in prefixes:
					if normalized.begins_with(prefix.to_lower()):
						matched = true
						break
				if matched:
					result.append(card)
					break
		return result


class EffectHiddenPrizeHandSwap extends BaseEffect:
	const PRIZE_STEP_ID := "csv10c_robot_prize_index"
	const HAND_STEP_ID := "csv10c_robot_hidden_hand"
	const SWAP_STEP_ID := "csv10c_robot_swap"

	func can_execute(card: CardInstance, state: GameState) -> bool:
		if card == null or state == null:
			return false
		var opponent := state.players[1 - card.owner_index]
		return not opponent.hand.is_empty() and not _facedown_prize_indices(opponent).is_empty()

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		if not can_execute(card, state):
			return []
		var opponent := state.players[1 - card.owner_index]
		var prize_indices := _facedown_prize_indices(opponent)
		var prize_labels: Array[String] = []
		for index: int in prize_indices:
			prize_labels.append("Opponent Prize %d" % (index + 1))
		var hand_labels: Array[String] = []
		for index: int in opponent.hand.size():
			hand_labels.append("Opponent hand card %d" % (index + 1))
		return [{
			"id": PRIZE_STEP_ID,
			"title": "Choose 1 facedown opponent Prize card without looking at its face",
			"items": prize_indices,
			"labels": prize_labels,
			"visible_scope": "opponent_prizes_hidden",
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		}, {
			"id": HAND_STEP_ID,
			"title": "Choose 1 opponent hand card without looking at its face",
			"items": opponent.hand.duplicate(),
			"labels": hand_labels,
			"presentation": "list",
			"visible_scope": "opponent_hand_hidden",
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		}]

	func build_ucis_followup_interaction_steps_spec_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
		var selected := _resolve_selection(card, state, resolved_context)
		if selected.is_empty():
			return []
		var prize: CardInstance = selected.get("prize", null)
		var hand: CardInstance = selected.get("hand", null)
		return [{
			"id": SWAP_STEP_ID,
			"title": "Look at the selected cards. Swap them?",
			"items": ["keep", "swap"],
			"labels": ["Do not swap", "Swap the selected cards"],
			"card_items": [prize, hand],
			"private_to_player": card.owner_index,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": false,
		}]

	func execute(card: CardInstance, targets: Array, state: GameState) -> void:
		if card == null or state == null:
			return
		var context := get_interaction_context(targets)
		var selected := _resolve_selection(card, state, context)
		if selected.is_empty():
			return
		var opponent := state.players[1 - card.owner_index]
		var prize_index := int(selected.get("prize_index", -1))
		var hand_card: CardInstance = selected.get("hand", null)
		var prize_card: CardInstance = selected.get("prize", null)
		var swap := false
		for raw: Variant in context.get(SWAP_STEP_ID, []):
			if str(raw) == "swap":
				swap = true
				break
		if swap:
			var hand_index := opponent.hand.find(hand_card)
			if hand_index >= 0 and prize_index >= 0 and prize_index < opponent.prizes.size():
				opponent.prizes[prize_index] = hand_card
				opponent.hand[hand_index] = prize_card
		if prize_index >= 0 and prize_index < opponent.prizes.size():
			opponent.prizes[prize_index].face_up = true

	func _resolve_selection(card: CardInstance, state: GameState, context: Dictionary) -> Dictionary:
		if card == null or state == null:
			return {}
		var opponent := state.players[1 - card.owner_index]
		var legal_indices := _facedown_prize_indices(opponent)
		var prize_index := -1
		for raw: Variant in context.get(PRIZE_STEP_ID, []):
			if raw is int and int(raw) in legal_indices:
				prize_index = int(raw)
				break
		var hand_card: CardInstance = null
		for raw: Variant in context.get(HAND_STEP_ID, []):
			if raw is CardInstance and raw in opponent.hand:
				hand_card = raw
				break
		if prize_index < 0 or hand_card == null:
			return {}
		return {
			"prize_index": prize_index,
			"prize": opponent.prizes[prize_index],
			"hand": hand_card,
		}

	func _facedown_prize_indices(player: PlayerState) -> Array[int]:
		var result: Array[int] = []
		for index: int in player.prizes.size():
			var prize: CardInstance = player.prizes[index]
			if prize != null and not prize.face_up:
				result.append(index)
		return result


class EffectCoinSearchNamedPokemonByStage extends BaseEffect:
	const STEP_ID := "csv10c_rocket_ball_search"

	var prefixes: PackedStringArray = PackedStringArray()
	var coin_flipper: CoinFlipper = null
	var _pending_results: Dictionary = {}

	func _init(team_prefixes: PackedStringArray, flipper: CoinFlipper = null) -> void:
		prefixes = team_prefixes.duplicate()
		coin_flipper = flipper

	func can_execute(card: CardInstance, state: GameState) -> bool:
		return card != null and state != null and not state.players[card.owner_index].deck.is_empty()

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		if not can_execute(card, state):
			return []
		var heads := _flipper().flip()
		_pending_results[card.instance_id] = heads
		var legal := _legal(state.players[card.owner_index], heads)
		if legal.is_empty():
			return [build_empty_search_resolution_step("Coin result: %s. No matching Team Rocket Pokemon was found." % ("heads" if heads else "tails"))]
		return [build_full_library_search_step(
			STEP_ID,
			"Coin result: %s. Choose 1 %s Team Rocket Pokemon" % ["heads" if heads else "tails", "Evolution" if heads else "Basic"],
			state.players[card.owner_index].deck,
			legal,
			VISIBLE_SCOPE_OWN_FULL_DECK,
			0,
			1,
			{"allow_cancel": true, "force_confirm": true}
		)]

	func build_ucis_followup_interaction_steps_spec_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
		if not should_preview_empty_search_deck(resolved_context):
			return []
		return [build_readonly_deck_preview_step("View deck", state.players[card.owner_index].deck)]

	func execute(card: CardInstance, targets: Array, state: GameState) -> void:
		if card == null or state == null:
			return
		var heads := _take_result(card)
		var player := state.players[card.owner_index]
		var legal := _legal(player, heads)
		var chosen: CardInstance = null
		var context := get_interaction_context(targets)
		for raw: Variant in context.get(STEP_ID, []):
			if raw is CardInstance and raw in legal:
				chosen = raw
				break
		if chosen == null and not context.has(STEP_ID) and not legal.is_empty():
			chosen = legal[0]
		if chosen != null:
			player.deck.erase(chosen)
			chosen.face_up = true
			player.hand.append(chosen)
		player.shuffle_deck()

	func _take_result(card: CardInstance) -> bool:
		if _pending_results.has(card.instance_id):
			var result := bool(_pending_results.get(card.instance_id, false))
			_pending_results.erase(card.instance_id)
			return result
		return _flipper().flip()

	func _flipper() -> CoinFlipper:
		return coin_flipper if coin_flipper != null else CoinFlipper.new()

	func _legal(player: PlayerState, heads: bool) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in player.deck:
			if card == null or card.card_data == null or not card.card_data.is_pokemon() or not _matches(card.card_data):
				continue
			if heads and not card.card_data.is_basic_pokemon():
				result.append(card)
			elif not heads and card.card_data.is_basic_pokemon():
				result.append(card)
		return result

	func _matches(card: CardData) -> bool:
		for identity: String in card.rule_identity_names():
			var normalized := identity.to_lower()
			for prefix: String in prefixes:
				if normalized.begins_with(prefix.to_lower()):
					return true
		return false


class EffectCoinDamageCountersOpponentOrSelf extends BaseEffect:
	const STEP_ID := "csv10c_scare_bomb_target"

	var counter_count: int = 2
	var coin_flipper: CoinFlipper = null
	var _pending_results: Dictionary = {}

	func _init(counters: int = 2, flipper: CoinFlipper = null) -> void:
		counter_count = maxi(0, counters)
		coin_flipper = flipper

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		if card == null or state == null:
			return []
		var heads := _flipper().flip()
		_pending_results[card.instance_id] = heads
		if not heads:
			return []
		var candidates := state.players[1 - card.owner_index].get_all_pokemon()
		var labels: Array[String] = []
		for slot: PokemonSlot in candidates:
			labels.append(slot.get_pokemon_name())
		return [{
			"id": STEP_ID,
			"title": "Coin result: heads. Choose an opponent's Pokemon for 2 damage counters",
			"items": candidates,
			"labels": labels,
			"presentation": "pokemon_slots",
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": false,
		}]

	func execute(card: CardInstance, targets: Array, state: GameState) -> void:
		if card == null or state == null:
			return
		var heads := _take_result(card)
		var player := state.players[card.owner_index]
		if not heads:
			if player.active_pokemon != null:
				player.active_pokemon.damage_counters += counter_count * 10
			return
		var opponent := state.players[1 - card.owner_index]
		var candidates := opponent.get_all_pokemon()
		var selected: PokemonSlot = null
		var context := get_interaction_context(targets)
		for raw: Variant in context.get(STEP_ID, []):
			if raw is PokemonSlot and raw in candidates:
				selected = raw
				break
		if selected == null and not context.has(STEP_ID) and not candidates.is_empty():
			selected = candidates[0]
		if selected != null:
			selected.damage_counters += counter_count * 10

	func _take_result(card: CardInstance) -> bool:
		if _pending_results.has(card.instance_id):
			var result := bool(_pending_results.get(card.instance_id, false))
			_pending_results.erase(card.instance_id)
			return result
		return _flipper().flip()

	func _flipper() -> CoinFlipper:
		return coin_flipper if coin_flipper != null else CoinFlipper.new()


class EffectSearchNamedSupporter extends BaseEffect:
	const STEP_ID := "csv10c_rocket_receiver_search"

	var fragments: PackedStringArray = PackedStringArray()

	func _init(name_fragments: PackedStringArray) -> void:
		fragments = name_fragments.duplicate()

	func can_execute(card: CardInstance, state: GameState) -> bool:
		return card != null and state != null and not state.players[card.owner_index].deck.is_empty()

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		if card == null or state == null:
			return []
		var player := state.players[card.owner_index]
		var legal := _legal(player)
		if legal.is_empty():
			return [build_empty_search_resolution_step("No matching Team Rocket Supporter was found.")]
		return [build_full_library_search_step(STEP_ID, "Choose 1 Team Rocket Supporter", player.deck, legal, VISIBLE_SCOPE_OWN_FULL_DECK, 0, 1, {"allow_cancel": true, "force_confirm": true})]

	func build_ucis_followup_interaction_steps_spec_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
		if not should_preview_empty_search_deck(resolved_context):
			return []
		return [build_readonly_deck_preview_step("View deck", state.players[card.owner_index].deck)]

	func execute(card: CardInstance, targets: Array, state: GameState) -> void:
		if card == null or state == null:
			return
		var player := state.players[card.owner_index]
		var legal := _legal(player)
		var chosen: CardInstance = null
		var context := get_interaction_context(targets)
		for raw: Variant in context.get(STEP_ID, []):
			if raw is CardInstance and raw in legal:
				chosen = raw
				break
		if chosen == null and not context.has(STEP_ID) and not legal.is_empty():
			chosen = legal[0]
		if chosen != null:
			player.deck.erase(chosen)
			chosen.face_up = true
			player.hand.append(chosen)
		player.shuffle_deck()

	func _legal(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in player.deck:
			if card == null or card.card_data == null or card.card_data.card_type != "Supporter":
				continue
			for identity: String in card.card_data.rule_identity_names():
				var normalized := identity.to_lower()
				var matched := false
				for fragment: String in fragments:
					if normalized.contains(fragment.to_lower()):
						matched = true
						break
				if matched:
					result.append(card)
					break
		return result


class EffectNamedTeamHPModifier extends BaseEffect:
	var hp_modifier: int = 70
	var prefixes: PackedStringArray = PackedStringArray()

	func _init(amount: int, team_prefixes: PackedStringArray) -> void:
		hp_modifier = amount
		prefixes = team_prefixes.duplicate()

	func get_hp_modifier(slot: PokemonSlot, _state: GameState = null) -> int:
		if slot == null or slot.get_card_data() == null:
			return 0
		for identity: String in slot.get_card_data().rule_identity_names():
			var normalized := identity.to_lower()
			for prefix: String in prefixes:
				if normalized.begins_with(prefix.to_lower()):
					return hp_modifier
		return 0
