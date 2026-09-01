class_name TcgMikAuditBatch20260729Effects
extends RefCounted

const CSV9CHelpers = preload("res://scripts/effects/CSV9CHelpers.gd")


class AbilityCrumblingCrystal extends BaseEffect:
	const PREVENT_PRIZES_EFFECT_TYPE := "prevent_knockout_prizes"
	const RESOLVED_FLIP_EFFECT_TYPE := "crumbling_crystal_prize_flip_resolved"

	var coin_flipper: CoinFlipper

	func _init(flipper: CoinFlipper = null) -> void:
		coin_flipper = flipper if flipper != null else CoinFlipper.new()

	func try_prevent_knockout_prizes(knocked_out: PokemonSlot, _state: GameState) -> bool:
		if knocked_out == null:
			return false
		for marker: Dictionary in knocked_out.effects:
			if marker.get("type", "") == RESOLVED_FLIP_EFFECT_TYPE:
				return bool(marker.get("prevented", false))
		var prevented := coin_flipper.flip()
		knocked_out.effects.append({
			"type": RESOLVED_FLIP_EFFECT_TYPE,
			"prevented": prevented,
		})
		if not prevented:
			return false
		knocked_out.effects.append({
			"type": PREVENT_PRIZES_EFFECT_TYPE,
			"source": "crumbling_crystal",
		})
		return true

	func get_description() -> String:
		return "When this Pokemon is Knocked Out, flip a coin. If heads, the opponent takes no Prize cards."


class AttackOpponentFieldDamageCounterMultiplier extends BaseEffect:
	var damage_per_counter: int = 10
	var attack_index_to_match: int = -1

	func _init(per_counter: int = 10, match_attack_index: int = -1) -> void:
		damage_per_counter = maxi(0, per_counter)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or attacker.get_top_card() == null or state == null:
			return 0
		var owner_index := attacker.get_top_card().owner_index
		if owner_index < 0 or owner_index >= state.players.size():
			return 0
		var counter_count := 0
		for slot: PokemonSlot in state.players[1 - owner_index].get_all_pokemon():
			if slot != null:
				counter_count += maxi(0, slot.damage_counters) / 10
		return counter_count * damage_per_counter

	func execute_attack(
		_attacker: PokemonSlot,
		_defender: PokemonSlot,
		_attack_index: int,
		_state: GameState
	) -> void:
		pass

	func get_description() -> String:
		return "This attack does more damage for each damage counter on all opposing Pokemon."


class AttackSetDefenderRemainingHP extends BaseEffect:
	var remaining_hp: int = 10
	var attack_index_to_match: int = -1

	func _init(target_remaining_hp: int = 10, match_attack_index: int = -1) -> void:
		remaining_hp = maxi(0, target_remaining_hp)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func execute_attack(
		attacker: PokemonSlot,
		defender: PokemonSlot,
		attack_index: int,
		state: GameState
	) -> void:
		if attacker == null or defender == null or state == null or not applies_to_attack_index(attack_index):
			return
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		if (
			processor != null
			and processor.has_method("is_attack_effect_prevented_by_defender_ability")
			and bool(processor.call("is_attack_effect_prevented_by_defender_ability", attacker, defender, state))
		):
			return
		var max_hp := defender.get_max_hp()
		if processor != null and processor.has_method("get_effective_max_hp"):
			max_hp = int(processor.call("get_effective_max_hp", defender, state))
		var target_damage := maxi(0, max_hp - remaining_hp)
		if defender.damage_counters >= target_damage:
			return
		defender.damage_counters = target_damage
		_mark_attack_damage_counter_placement(defender, state)

	func get_description() -> String:
		return "Place damage counters on the opponent's Active Pokemon until it has %d HP remaining." % remaining_hp


class AttackDamageCountersOnAllOpponentPokemon extends BaseEffect:
	var counter_count: int = 2
	var attack_index_to_match: int = -1

	func _init(count: int = 2, match_attack_index: int = -1) -> void:
		counter_count = maxi(0, count)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index

	func execute_attack(
		attacker: PokemonSlot,
		_defender: PokemonSlot,
		attack_index: int,
		state: GameState
	) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var owner_index := attacker.get_top_card().owner_index
		if owner_index < 0 or owner_index >= state.players.size():
			return
		var opponent := state.players[1 - owner_index]
		for target: PokemonSlot in opponent.get_all_pokemon():
			if target == null or _effect_is_prevented(attacker, target, opponent, state):
				continue
			target.damage_counters += counter_count * 10
			_mark_attack_damage_counter_placement(target, state)

	func _effect_is_prevented(
		attacker: PokemonSlot,
		target: PokemonSlot,
		opponent: PlayerState,
		state: GameState
	) -> bool:
		if target in opponent.bench and AbilityBenchImmune.prevents_opponent_attack_effect(target, attacker, state):
			return true
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		return (
			processor != null
			and processor.has_method("is_attack_effect_prevented_by_defender_ability")
			and bool(processor.call("is_attack_effect_prevented_by_defender_ability", attacker, target, state))
		)

	func get_description() -> String:
		return "Put %d damage counters on each of your opponent's Pokemon." % counter_count


class AbilityReturnOpponentDiscardSupporter extends BaseEffect:
	const STEP_ID := "homecoming_opponent_supporter"

	func is_evolve_triggered_ability() -> bool:
		return true

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		var owner_index := pokemon.get_top_card().owner_index
		if owner_index < 0 or owner_index >= state.players.size():
			return false
		return (
			state.current_player_index == owner_index
			and CSV9CHelpers.evolved_from_hand_this_turn(pokemon, state)
			and not pokemon.has_ability_used(state.turn_number)
			and not _opponent_supporters(owner_index, state).is_empty()
		)

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		if card == null or state == null:
			return []
		var items := _opponent_supporters(card.owner_index, state)
		if items.is_empty():
			return []
		var labels: Array[String] = []
		for supporter: CardInstance in items:
			labels.append(supporter.card_data.name if supporter.card_data != null else "")
		return [{
			"id": STEP_ID,
			"title": "Choose 1 Supporter from your opponent's discard pile",
			"items": items,
			"labels": labels,
			"presentation": "cards",
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		}]

	func validate_ability_interaction(
		pokemon: PokemonSlot,
		_ability_index: int,
		targets: Array,
		state: GameState
	) -> Dictionary:
		if not can_use_ability(pokemon, state):
			return interaction_validation_error("Homecoming is not available")
		var owner_index := pokemon.get_top_card().owner_index
		return validate_context_selection(
			get_interaction_context(targets),
			STEP_ID,
			_opponent_supporters(owner_index, state),
			1,
			1
		)

	func execute_ability(
		pokemon: PokemonSlot,
		_ability_index: int,
		targets: Array,
		state: GameState
	) -> void:
		if not can_use_ability(pokemon, state):
			return
		var owner_index := pokemon.get_top_card().owner_index
		var opponent := state.players[1 - owner_index]
		var legal := _opponent_supporters(owner_index, state)
		var selected: CardInstance = null
		for entry: Variant in get_interaction_context(targets).get(STEP_ID, []):
			if entry is CardInstance and entry in legal:
				selected = entry
				break
		if selected == null:
			return
		opponent.discard_pile.erase(selected)
		selected.face_up = true
		opponent.hand.append(selected)
		pokemon.mark_ability_used(state.turn_number)

	func _opponent_supporters(owner_index: int, state: GameState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		if state == null or owner_index < 0 or owner_index >= state.players.size():
			return result
		for card: CardInstance in state.players[1 - owner_index].discard_pile:
			if card != null and card.card_data != null and card.card_data.card_type == "Supporter":
				result.append(card)
		return result

	func get_empty_interaction_message(_card: CardInstance, _state: GameState) -> String:
		return "There are no Supporter cards in your opponent's discard pile."

	func get_description() -> String:
		return "When this Pokemon evolves from your hand, put 1 Supporter from your opponent's discard pile into their hand."


class AttackDistributedBenchCountersExact extends AttackDistributedBenchCounters:
	func _init(total: int = 30, match_attack_index: int = -1) -> void:
		super(total, match_attack_index)

	func validate_attack_interaction(
		attacker: PokemonSlot,
		attack_index: int,
		targets: Array,
		state: GameState
	) -> Dictionary:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return interaction_validation_error("Phantom Dive is not available")
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		var legal: Array[PokemonSlot] = []
		for slot: PokemonSlot in opponent.bench:
			if not _is_attack_effect_prevented(slot, attacker, state):
				legal.append(slot)
		if legal.is_empty():
			return interaction_validation_ok()
		var context := get_interaction_context(targets)
		if not context.has("bench_damage_counters"):
			return interaction_validation_error("missing interaction step: bench_damage_counters")
		var raw: Variant = context.get("bench_damage_counters")
		if not (raw is Array):
			return interaction_validation_error("bench_damage_counters must be an array")
		var assigned_damage := 0
		for entry: Variant in raw:
			if not (entry is Dictionary):
				return interaction_validation_error("bench_damage_counters contains an invalid assignment")
			var assignment: Dictionary = entry
			var target: Variant = assignment.get("target", null)
			var amount := int(assignment.get("amount", 0))
			if not (target is PokemonSlot) or target not in legal:
				return interaction_validation_error("bench_damage_counters contains an illegal target")
			if amount <= 0 or amount % 10 != 0:
				return interaction_validation_error("damage-counter assignments must use positive 10-damage increments")
			assigned_damage += amount
		if assigned_damage != total_damage:
			return interaction_validation_error("Phantom Dive must distribute exactly %d damage counters" % (total_damage / 10))
		return interaction_validation_ok()


class AttackOpponentHandTrainerCountDamageReveal extends AttackOpponentHandCountDamage:
	const PREVIEW_STEP_ID := "poltergeist_opponent_hand_preview"

	func _init(
		per_trainer: int = 50,
		printed_damage: int = 50,
		match_attack_index: int = -1
	) -> void:
		super(per_trainer, true, printed_damage)
		attack_index_to_match = match_attack_index

	func build_ucis_attack_interaction_steps_spec_steps(
		card: CardInstance,
		attack: Dictionary,
		state: GameState
	) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var opponent := state.players[1 - card.owner_index]
		if opponent.hand.is_empty():
			return []
		var preview := build_readonly_card_preview_step(
			"Look at your opponent's hand",
			opponent.hand,
			"Confirm and continue"
		)
		preview["id"] = PREVIEW_STEP_ID
		preview["visible_scope"] = "opponent_hand_revealed"
		preview["force_confirm"] = true
		return [preview]

	func active_damage_is_invariant_under_interaction(attack_index: int) -> bool:
		return applies_to_attack_index(attack_index)

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1
