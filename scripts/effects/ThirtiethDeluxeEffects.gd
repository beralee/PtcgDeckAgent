## Rules unique to the source-locked 30thDC deluxe printings.
extends RefCounted

const Celebration = preload("res://scripts/effects/ThirtiethCelebrationEffects.gd")


class AttackComeback extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		var owner := attacker.get_top_card().owner_index
		var key := "attack_damage_knockout_names:%d:%d" % [owner, state.turn_number - 1]
		return 90 if not (state.shared_turn_flags.get(key, []) as Array).is_empty() else 0


class AttackQuickAttack extends BaseEffect:
	var coin_flipper: CoinFlipper
	var pending: Dictionary = {}

	func _init(flipper: CoinFlipper) -> void:
		coin_flipper = flipper
		bind_default_attack_index(0)

	func before_attack_damage(attacker: PokemonSlot, _defender: PokemonSlot, _index: int, state: GameState) -> void:
		pending[_key(attacker, state)] = 20 if coin_flipper.flip() else 0

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		return int(pending.get(_key(attacker, state), 0))

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, _index: int, state: GameState) -> void:
		pending.erase(_key(attacker, state))

	func _key(attacker: PokemonSlot, state: GameState) -> String:
		return "%d:%d:%d" % [state.get_instance_id(), state.turn_number, attacker.get_top_card().instance_id]


class AttackGentleGrip extends AttackDefenderRetreatLockNextTurn:
	var coin_flipper: CoinFlipper

	func _init(flipper: CoinFlipper) -> void:
		super(0)
		coin_flipper = flipper

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, index: int, state: GameState) -> void:
		if applies_to_attack_index(index) and coin_flipper.flip():
			super.execute_attack(attacker, defender, index, state)


class AbilityNightPath extends BaseEffect:
	func get_retreat_cost_modifier_for_slot(source: PokemonSlot, target: PokemonSlot, state: GameState) -> int:
		if source == null or target == null or state == null or source.get_top_card() == null:
			return 0
		var player := state.players[source.get_top_card().owner_index]
		return -2 if source in player.bench and target == player.active_pokemon else 0


class AttackSoothingScent extends CSV9CSimpleHealOwnPokemon:
	func _init() -> void:
		super(80, 0)

	func _damaged_own_pokemon(player: PlayerState) -> Array[PokemonSlot]:
		var result: Array[PokemonSlot] = []
		for slot: PokemonSlot in player.bench:
			if slot.damage_counters > 0:
				result.append(slot)
		return result

	func validate_attack_interaction(attacker: PokemonSlot, _index: int, targets: Array, state: GameState) -> Dictionary:
		var candidates := _damaged_own_pokemon(state.players[attacker.get_top_card().owner_index])
		if candidates.is_empty() and get_interaction_context(targets).is_empty():
			return interaction_validation_ok()
		return validate_context_selection(get_interaction_context(targets), STEP_ID, candidates, mini(1, candidates.size()), mini(1, candidates.size()))


class AttackTripleBite extends BaseEffect:
	const STEP_ID := "discard_opponent_active_energy"
	var coin_flipper: CoinFlipper
	var pending: Dictionary = {}

	func _init(flipper: CoinFlipper) -> void:
		coin_flipper = flipper
		bind_default_attack_index(0)

	func _key(card: CardInstance, state: GameState) -> String:
		return "%d:%d:%d" % [state.get_instance_id(), state.turn_number, card.instance_id]

	func _heads(card: CardInstance, state: GameState) -> int:
		var key := _key(card, state)
		if not pending.has(key):
			var count := 0
			for _i: int in 3:
				if coin_flipper.flip():
					count += 1
			pending[key] = count
		return int(pending[key])

	func build_ucis_attack_preview_interaction_steps_spec_steps(_card: CardInstance, _attack: Dictionary, _state: GameState) -> Array[Dictionary]:
		return [{"id": "coin_preview", "title": "投掷3枚硬币", "preview_only": true, "wait_for_coin_animation": true}]

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, _attack: Dictionary, state: GameState) -> Array[Dictionary]:
		return _next_step(card, state, {})

	func build_ucis_followup_attack_interaction_steps_spec_steps(card: CardInstance, _attack: Dictionary, state: GameState, context: Dictionary) -> Array[Dictionary]:
		return _next_step(card, state, context)

	func _selected(context: Dictionary) -> Array:
		var selected: Array = []
		for i: int in 3:
			var raw: Variant = context.get(STEP_ID if i == 0 else STEP_ID + "_%d" % (i + 1), [])
			if raw is Array:
				selected.append_array(raw)
		return selected

	func _units(cards: Array, state: GameState) -> int:
		var processor: EffectProcessor = state.shared_turn_flags.get("_draw_effect_processor")
		var result := 0
		for card: CardInstance in cards:
			result += processor.get_energy_colorless_count(card, state)
		return result

	func _next_step(card: CardInstance, state: GameState, context: Dictionary) -> Array[Dictionary]:
		var heads := _heads(card, state)
		var opponent := state.players[1 - card.owner_index]
		var defender := opponent.active_pokemon
		if heads == 0 or defender == null or defender.attached_energy.is_empty():
			return []
		var selected := _selected(context)
		var needed := mini(heads, _units(defender.attached_energy, state))
		for item: Variant in selected:
			if not item is CardInstance or item not in defender.attached_energy:
				return []
		var items: Array = []
		for energy: CardInstance in defender.attached_energy:
			if energy not in selected and _units([energy], state) > 0:
				items.append(energy)
		if selected.size() >= needed or items.is_empty():
			return []
		if _units(selected, state) >= needed:
			# Each selected physical card can contribute only one of its units.
			# Choosing a double Energy must not force the player to stop early.
			var continue_id := "triple_bite_continue_%d" % selected.size()
			if not context.has(continue_id):
				return [{"id": continue_id, "title": "已可完成弃置，是否继续选择另一张能量卡？", "items": [false, true], "labels": ["完成弃置", "继续选择"], "min_select": 1, "max_select": 1, "allow_cancel": false, "requires_followup_interaction": true}]
			if context.get(continue_id) != [true]:
				return []
		var labels: Array[String] = []
		for energy: CardInstance in items:
			labels.append(energy.card_data.name)
		var step_id := STEP_ID if selected.is_empty() else STEP_ID + "_%d" % (selected.size() + 1)
		return [{
			"id": step_id, "title": "选择对手战斗宝可梦身上的能量卡（共弃置%d个能量）" % needed,
			"items": items, "labels": labels, "min_select": 1, "max_select": 1,
			"allow_cancel": false, "wait_for_coin_animation": true,
			"requires_followup_interaction": true,
			"ucis_select_type_name": "ATTACHED_CARD", "ucis_context_name": "DISCARD_ENERGY_CARD",
			"card_groups": build_attached_card_groups(opponent, items),
			"transparent_battlefield_dialog": true,
		}]

	func validate_attack_preflight(attacker: PokemonSlot, _index: int, targets: Array, state: GameState) -> Dictionary:
		var context := get_interaction_context(targets)
		var defender := state.players[1 - attacker.get_top_card().owner_index].active_pokemon
		var seen: Array = []
		for i: int in 3:
			var step_id := STEP_ID if i == 0 else STEP_ID + "_%d" % (i + 1)
			var raw: Variant = context.get(step_id, [])
			if not raw is Array:
				return interaction_validation_error("Triple Bite Energy selection must be an array")
			for item: Variant in raw:
				if not item is CardInstance or defender == null or item not in defender.attached_energy or item in seen:
					return interaction_validation_error("Invalid or duplicate Triple Bite Energy reference")
				seen.append(item)
		return interaction_validation_ok() if seen.size() <= 3 else interaction_validation_error("Too many Triple Bite Energy cards")

	func validate_attack_interaction(attacker: PokemonSlot, _index: int, targets: Array, state: GameState) -> Dictionary:
		var preflight := validate_attack_preflight(attacker, _index, targets, state)
		if not bool(preflight.get("valid", false)):
			return preflight
		var heads := _heads(attacker.get_top_card(), state)
		var defender := state.players[1 - attacker.get_top_card().owner_index].active_pokemon
		var needed := mini(heads, _units(defender.attached_energy, state)) if defender != null else 0
		var selected := _selected(get_interaction_context(targets))
		var context := get_interaction_context(targets)
		for i: int in 3:
			var step_id := STEP_ID if i == 0 else STEP_ID + "_%d" % (i + 1)
			if context.has(step_id) and not context[step_id] is Array:
				return interaction_validation_error("Triple Bite Energy selection must be an array")
			var continue_id := "triple_bite_continue_%d" % (i + 1)
			if context.has(continue_id):
				var choice: Variant = context[continue_id]
				if choice != [true] and choice != [false]:
					return interaction_validation_error("Invalid Triple Bite continuation")
				if (choice == [true]) != (selected.size() > i + 1):
					return interaction_validation_error("Triple Bite continuation is incomplete or inconsistent")
		var units := 0
		var seen: Array = []
		for item: Variant in selected:
			if seen.size() >= needed or not item is CardInstance or item not in defender.attached_energy or item in seen:
				return interaction_validation_error("Invalid or excessive Triple Bite Energy selection")
			var count := _units([item], state)
			if count <= 0:
				return interaction_validation_error("Selected card provides no Energy")
			units += count
			seen.append(item)
		return interaction_validation_ok() if units >= needed else interaction_validation_error("Triple Bite Energy selection is incomplete")

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		if not bool(validate_attack_interaction(attacker, index, [get_attack_interaction_context()], state).get("valid", false)):
			return
		var heads := _heads(attacker.get_top_card(), state)
		pending.erase(_key(attacker.get_top_card(), state))
		if defender == null or heads == 0:
			return
		var processor: EffectProcessor = state.shared_turn_flags.get("_draw_effect_processor")
		if processor != null and processor.is_attack_effect_prevented_by_defender_ability(attacker, defender, state):
			return
		var context := get_attack_interaction_context()
		var selected: Array = _selected(context)
		var unique: Array = []
		for item: Variant in selected:
			if not item is CardInstance or item not in defender.attached_energy or item in unique:
				return
			unique.append(item)
		for energy: CardInstance in unique:
			defender.attached_energy.erase(energy)
			state.players[energy.owner_index].discard_card(energy)
			_record_attack_effect_discarded_attached_energy(attacker, energy, state)


class AttackMeteorShot extends Celebration.AttackAnyTargetFixed:
	func _init() -> void:
		super(120)

	func validate_attack_interaction(attacker: PokemonSlot, _index: int, targets: Array, state: GameState) -> Dictionary:
		var candidates := state.players[1 - attacker.get_top_card().owner_index].get_all_pokemon()
		return validate_context_selection(get_interaction_context(targets), "any_target", candidates, 1, 1)

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		super.execute_attack(attacker, defender, index, state)
		AttackDiscardAllAttachedEnergyFromSelf.new(0).execute_attack(attacker, defender, index, state)


class Potion extends BaseEffect:
	const STEP_ID := "heal_target"

	func _targets(card: CardInstance, state: GameState) -> Array[PokemonSlot]:
		var result: Array[PokemonSlot] = []
		for slot: PokemonSlot in state.players[card.owner_index].get_all_pokemon():
			if slot.damage_counters > 0:
				result.append(slot)
		return result

	func can_execute(card: CardInstance, state: GameState) -> bool:
		return not _targets(card, state).is_empty()

	func validate_card_interaction(card: CardInstance, targets: Array, state: GameState) -> Dictionary:
		return validate_context_selection(get_interaction_context(targets), STEP_ID, _targets(card, state), 1, 1)

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var items := _targets(card, state)
		if items.is_empty():
			return []
		var labels: Array[String] = []
		for slot: PokemonSlot in items:
			labels.append(slot.get_pokemon_name())
		return [{"id": STEP_ID, "title": "选择回复30HP的宝可梦", "items": items, "labels": labels, "min_select": 1, "max_select": 1, "allow_cancel": false}]

	func execute(card: CardInstance, targets: Array, state: GameState) -> void:
		var selected: Array = get_interaction_context(targets).get(STEP_ID, [])
		if selected.size() == 1 and selected[0] in _targets(card, state):
			(selected[0] as PokemonSlot).heal(30, state)


class Waitress extends BaseEffect:
	const STEP_ID := "waitress_energy_assignment"

	func can_execute(card: CardInstance, state: GameState) -> bool:
		return not state.players[card.owner_index].deck.is_empty()

	func _top(player: PlayerState) -> Array[CardInstance]:
		return player.deck.slice(0, mini(6, player.deck.size()))

	func _energy(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in _top(player):
			if card.card_data.card_type == "Basic Energy":
				result.append(card)
		return result

	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var player := state.players[card.owner_index]
		var visible := _top(player)
		var sources := _energy(player)
		if sources.is_empty():
			return [build_readonly_card_preview_step("牌库上方6张中没有基本能量", visible)]
		var targets := player.get_all_pokemon()
		var source_labels: Array[String] = []
		var target_labels: Array[String] = []
		for energy: CardInstance in sources:
			source_labels.append(energy.card_data.name)
		for slot: PokemonSlot in targets:
			target_labels.append(slot.get_pokemon_name())
		return [build_full_library_card_assignment_step(
			STEP_ID, "选择上方6张中的1张基本能量并附着", visible, sources, source_labels,
			targets, target_labels, 1, 1, "own_top_%d_cards" % visible.size(), false
		)]

	func execute(card: CardInstance, targets: Array, state: GameState) -> void:
		if not bool(validate_card_interaction(card, targets, state).get("valid", false)):
			return
		var player := state.players[card.owner_index]
		var selected: Array = get_interaction_context(targets).get(STEP_ID, [])
		if selected.size() == 1 and selected[0] is Dictionary:
			var assignment: Dictionary = selected[0]
			var energy: Variant = assignment.get("source")
			var target: Variant = assignment.get("target")
			if energy is CardInstance and energy in _energy(player) and target is PokemonSlot and target in player.get_all_pokemon():
				player.deck.erase(energy)
				energy.face_up = true
				target.attached_energy.append(energy)
		player.shuffle_deck()

	func validate_card_interaction(card: CardInstance, targets: Array, state: GameState) -> Dictionary:
		var player := state.players[card.owner_index]
		var context := get_interaction_context(targets)
		var selected: Variant = context.get(STEP_ID, [])
		if not selected is Array:
			return interaction_validation_error("Invalid Waitress assignment")
		var candidates := _energy(player)
		if candidates.is_empty() and selected.is_empty():
			return interaction_validation_ok()
		if selected.size() != 1 or not selected[0] is Dictionary:
			return interaction_validation_error("Waitress requires one Energy assignment")
		var assignment: Dictionary = selected[0]
		if assignment.get("source") not in candidates or assignment.get("target") not in player.get_all_pokemon():
			return interaction_validation_error("Waitress selection is outside the top six or own field")
		return interaction_validation_ok()
