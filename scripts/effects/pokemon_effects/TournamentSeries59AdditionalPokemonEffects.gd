extends RefCounted

# Rules are bound to the source-locked printings in the companion registry.
class BronzeBody extends BaseEffect:
	func get_defense_modifier_for_defender(source: PokemonSlot, defender: PokemonSlot, _state: GameState) -> int:
		return -30 if source == defender else 0

class MysteriousShield extends BaseEffect:
	func prevents_damage_from(attacker: PokemonSlot, _defender: PokemonSlot, _state: GameState) -> bool:
		return attacker != null and attacker.get_card_data() != null and attacker.get_card_data().mechanic in ["ex", "V", "VMAX", "VSTAR"]

class CoinDamage extends BaseEffect:
	var count: int
	var per_head: int
	var printed: int
	var flipper: CoinFlipper
	var pending: Dictionary = {}
	func _init(coins: int, amount: int, base: int, index: int, coin_flipper: CoinFlipper) -> void:
		count = coins
		per_head = amount
		printed = base
		flipper = coin_flipper
		bind_default_attack_index(index)
	func _key(attacker: PokemonSlot, state: GameState) -> String:
		return "%d:%d:%d" % [state.get_instance_id(), state.turn_number, attacker.get_top_card().instance_id]
	func before_attack_damage(attacker: PokemonSlot, _defender: PokemonSlot, _index: int, state: GameState) -> void:
		var amount := -printed
		for _i: int in count:
			if flipper.flip():
				amount += per_head
		pending[_key(attacker, state)] = amount
	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		return int(pending.get(_key(attacker, state), 0))
	func cancels_attack_damage(attacker: PokemonSlot, _defender: PokemonSlot, _index: int, state: GameState) -> bool:
		# A pure multiplier with zero heads ends damage calculation before
		# external bonuses. Fixed-base "+" attacks have printed == 0 here.
		var key := _key(attacker, state)
		return printed > 0 and pending.has(key) and int(pending[key]) == -printed
	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, _index: int, state: GameState) -> void:
		pending.erase(_key(attacker, state))

class JetPunchRecoil extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)
	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, _index: int, _state: GameState) -> void:
		attacker.damage_counters += attacker.damage_counters

class PsychicMirror extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)
	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		var defender := state.players[1 - attacker.get_top_card().owner_index].active_pokemon
		return 30 if defender != null and defender.get_card_data().energy_type == "P" else 0
	func execute_attack(_attacker: PokemonSlot, _defender: PokemonSlot, _index: int, _state: GameState) -> void:
		pass

class MirrorDraw extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)
	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, _index: int, state: GameState) -> void:
		var owner := attacker.get_top_card().owner_index
		_draw_cards_with_log(state, owner, maxi(0, state.players[1-owner].hand.size() - state.players[owner].hand.size()), attacker.get_top_card(), "attack")

class BothDrawThree extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)
	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, _index: int, state: GameState) -> void:
		var owner := attacker.get_top_card().owner_index
		for seat: int in [owner, 1-owner]:
			_draw_cards_with_log(state, seat, 3, attacker.get_top_card(), "attack")

class HealOneBench extends CSV9CSimpleHealOwnPokemon:
	func _init() -> void:
		super(120, 0)
	func _damaged_own_pokemon(player: PlayerState) -> Array[PokemonSlot]:
		var result: Array[PokemonSlot] = []
		for slot: PokemonSlot in player.bench:
			if slot.damage_counters > 0:
				result.append(slot)
		return result
	func validate_attack_interaction(attacker: PokemonSlot, _index: int, targets: Array, state: GameState) -> Dictionary:
		var candidates := _damaged_own_pokemon(state.players[attacker.get_top_card().owner_index])
		if candidates.is_empty():
			return interaction_validation_ok()
		return validate_context_selection(get_interaction_context(targets), STEP_ID, candidates, 1, 1)

class SearchEnergy extends AttackSearchDeckToHand:
	func _init() -> void:
		super(1, "", 0)
	func _matches_filter(card: CardInstance) -> bool:
		return card != null and card.card_data != null and card.card_data.is_energy()

class DeckFireAttach extends AttackSearchEnergyFromDeckToSelf:
	func _init() -> void:
		super("R", 1)
	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		var steps := super.build_ucis_attack_interaction_steps_spec_steps(card, attack, state)
		for step: Dictionary in steps:
			step["min_select"] = 0 # A search of a hidden zone may fail to find.
		return steps

class HandEnergyAttach extends AttackAttachBasicEnergyFromHandToOwnPokemon:
	var bench_only := false
	func _init(only_grass_bench: bool) -> void:
		super("G" if only_grass_bench else "", 1, 0)
		bench_only = only_grass_bench
	func _matches_energy(card: CardInstance) -> bool:
		return super._matches_energy(card) if bench_only else card != null and card.card_data != null and card.card_data.is_energy()
	func _targets(player: PlayerState) -> Array:
		return player.bench.duplicate() if bench_only else player.get_all_pokemon()
	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		var player := state.players[card.owner_index]
		if _targets(player).is_empty():
			return []
		var steps := super.build_ucis_attack_interaction_steps_spec_steps(card, attack, state)
		for step: Dictionary in steps:
			step["allow_cancel"] = false
			if step.id == ENERGY_STEP_ID:
				step["title"] = "选择1张要附着的能量"
			elif step.id == TARGET_STEP_ID:
				step["items"] = _targets(player)
				var labels: Array[String] = []
				for slot: PokemonSlot in _targets(player):
					labels.append(slot.get_pokemon_name())
				step["labels"] = labels
		return steps
	func _first_valid_target(raw: Array, player: PlayerState) -> PokemonSlot:
		for item: Variant in raw:
			if item is PokemonSlot and item in _targets(player):
				return item
		return null
	func validate_attack_interaction(attacker: PokemonSlot, _index: int, targets: Array, state: GameState) -> Dictionary:
		var player := state.players[attacker.get_top_card().owner_index]
		var energies: Array = []
		for card: CardInstance in player.hand:
			if _matches_energy(card):
				energies.append(card)
		if energies.is_empty() or _targets(player).is_empty():
			return interaction_validation_ok()
		var context := get_interaction_context(targets)
		var check := validate_context_selection(context, ENERGY_STEP_ID, energies, 1, 1)
		if not bool(check.get("valid", false)):
			return check
		return validate_context_selection(context, TARGET_STEP_ID, _targets(player), 1, 1)
	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, _index: int, state: GameState) -> void:
		var player := state.players[attacker.get_top_card().owner_index]
		var context := get_attack_interaction_context()
		var target := _first_valid_target(context.get(TARGET_STEP_ID, []), player)
		if target == null:
			return
		for energy: CardInstance in _resolve_selected_energy(context.get(ENERGY_STEP_ID, []), player):
			player.hand.erase(energy)
			target.attached_energy.append(energy)
			var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
			if processor is EffectProcessor:
				processor.execute_card_effect(energy, [target], state)
				processor.process_after_energy_attached_from_hand(energy.owner_index, target, state)

class ColorfulCatch extends AttackSearchDistinctPokemonTypes:
	func _init() -> void:
		super(3, 0)
	func _is_pokemon(card: CardInstance) -> bool:
		return card != null and card.card_data != null and card.card_data.card_type == "Basic Energy"
	func _pokemon_type(card: CardInstance) -> String:
		return card.card_data.energy_type if _is_pokemon(card) else ""
	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		var steps := super.build_ucis_attack_interaction_steps_spec_steps(card, attack, state)
		for step: Dictionary in steps:
			step["title"] = "选择最多3张属性各不相同的基本能量"
		return steps
	func validate_attack_interaction(attacker: PokemonSlot, _index: int, targets: Array, state: GameState) -> Dictionary:
		var candidates := _pokemon_cards(state.players[attacker.get_top_card().owner_index].deck)
		var context := get_interaction_context(targets)
		if candidates.is_empty() and context.is_empty():
			return interaction_validation_ok()
		var check := validate_context_selection(context, STEP_ID, candidates, 0, mini(3, candidates.size()))
		if not bool(check.get("valid", false)):
			return check
		var types: Array[String] = []
		for energy: CardInstance in context.get(STEP_ID, []):
			var energy_type := _pokemon_type(energy)
			if energy_type in types:
				return interaction_validation_error("Energy types must be different")
			types.append(energy_type)
		return interaction_validation_ok()

class FeintAttack extends AttackAnyTargetDamage:
	func _init() -> void:
		super(50)
		bind_default_attack_index(0)
	func ignores_weakness_and_resistance(_attacker: PokemonSlot, _state: GameState, _index: int) -> bool:
		return true
	func ignores_defender_effects(_attacker: PokemonSlot, _state: GameState, _index: int) -> bool:
		return true
	func cancels_attack_damage(_attacker: PokemonSlot, _defender: PokemonSlot, _index: int, _state: GameState) -> bool:
		# All damage belongs to the selected target; positive attacker modifiers
		# must never manufacture a second hit on the opposing Active Pokemon.
		return true
	func validate_attack_interaction(attacker: PokemonSlot, _index: int, targets: Array, state: GameState) -> Dictionary:
		return validate_context_selection(get_interaction_context(targets), "any_target", state.players[1-attacker.get_top_card().owner_index].get_all_pokemon(), 1, 1)
	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, _index: int, state: GameState) -> void:
		var legal := state.players[1-attacker.get_top_card().owner_index].get_all_pokemon()
		for target: Variant in get_attack_interaction_context().get("any_target", []):
			if target is PokemonSlot and target in legal:
				var amount := 50
				var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
				if processor is EffectProcessor:
					amount += processor.get_attacker_modifier(attacker, state, target)
					amount += processor.get_attack_damage_modifier(attacker, target, {"damage": "50"}, state, [], 0)
				target.damage_counters += maxi(0, amount)
				return

class MagneticAbsorption extends BaseEffect:
	const STEP := "magnetic_absorption"
	func _energies(player: PlayerState) -> Array:
		return player.discard_pile.filter(func(card: CardInstance) -> bool: return card.card_data != null and card.card_data.card_type == "Basic Energy" and card.card_data.energy_type == "F")
	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		var owner := pokemon.get_top_card().owner_index
		return owner == state.current_player_index and not pokemon.has_ability_used(state.turn_number) and state.players[1-owner].prizes.size() <= 4 and not _energies(state.players[owner]).is_empty()
	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var items := _energies(state.players[card.owner_index])
		return [{"id": STEP, "title": "选择1张基本斗能量附着到这只宝可梦", "items": items, "labels": items.map(func(energy: CardInstance) -> String: return energy.card_data.name), "min_select": 1, "max_select": 1, "allow_cancel": true}]
	func validate_ability_interaction(pokemon: PokemonSlot, _index: int, targets: Array, state: GameState) -> Dictionary:
		return validate_context_selection(get_interaction_context(targets), STEP, _energies(state.players[pokemon.get_top_card().owner_index]), 1, 1)
	func execute_ability(pokemon: PokemonSlot, _index: int, targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var player := state.players[pokemon.get_top_card().owner_index]
		for energy: Variant in get_interaction_context(targets).get(STEP, []):
			if energy is CardInstance and energy in _energies(player):
				player.discard_pile.erase(energy)
				pokemon.attached_energy.append(energy)
				pokemon.mark_ability_used(state.turn_number)
				return

class MetalBridge extends BaseEffect:
	var processor_ref: WeakRef
	func _init(processor: EffectProcessor) -> void:
		processor_ref = weakref(processor)
	func get_retreat_cost_modifier_for_slot(source: PokemonSlot, target: PokemonSlot, state: GameState) -> int:
		if source.get_top_card().owner_index != target.get_top_card().owner_index:
			return 0
		var processor: EffectProcessor = processor_ref.get_ref()
		if processor != null:
			for energy: CardInstance in target.attached_energy:
				var types := processor.get_energy_types(energy, state)
				if "M" in types or "ANY" in types:
					return -99
		return 0

class AssaultingHunt extends BaseEffect:
	const STEP := "assaulting_hunt"
	const USED_ENTRY := "assaulting_hunt_used_entry"
	func _targets(card: CardInstance, state: GameState) -> Array:
		return state.players[1-card.owner_index].bench.filter(func(slot: PokemonSlot) -> bool: return slot.get_card_data() != null and slot.get_card_data().is_basic_pokemon())
	func _entry_used(pokemon: PokemonSlot, state: GameState) -> bool:
		for marker: Dictionary in pokemon.effects:
			if marker.get("type") == USED_ENTRY and int(marker.get("turn", -1)) == state.turn_number and int(marker.get("active_order", -1)) == pokemon.active_order:
				return true
		return false
	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		var top := pokemon.get_top_card()
		return top.owner_index == state.current_player_index and state.players[top.owner_index].active_pokemon == pokemon and pokemon.entered_active_from_bench_this_turn(state.turn_number) and not _entry_used(pokemon, state) and not _targets(top, state).is_empty()
	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var targets := _targets(card, state)
		return [{"id": STEP, "title": "选择对手1只基础备战宝可梦换到战斗场", "items": targets, "labels": targets.map(func(slot: PokemonSlot) -> String: return slot.get_pokemon_name()), "min_select": 1, "max_select": 1, "allow_cancel": true}]
	func validate_ability_interaction(pokemon: PokemonSlot, _index: int, targets: Array, state: GameState) -> Dictionary:
		return validate_context_selection(get_interaction_context(targets), STEP, _targets(pokemon.get_top_card(), state), 1, 1)
	func execute_ability(pokemon: PokemonSlot, _index: int, targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		for target: Variant in get_interaction_context(targets).get(STEP, []):
			if target is PokemonSlot and target in _targets(pokemon.get_top_card(), state):
				_switch_active_with_bench(state, 1-pokemon.get_top_card().owner_index, target, "assaulting_hunt")
				pokemon.effects.append({"type": USED_ENTRY, "turn": state.turn_number, "active_order": pokemon.active_order})
				return

class CursedWords extends BaseEffect:
	const STEP := "cursed_words"
	func _init() -> void:
		bind_default_attack_index(0)
	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, _attack: Dictionary, state: GameState) -> Array[Dictionary]:
		var items: Array = state.players[1-card.owner_index].hand.duplicate()
		if items.is_empty():
			return []
		return [{"id": STEP, "title": "选择自己3张手牌放回牌库", "items": items, "labels": items.map(func(item: CardInstance) -> String: return item.card_data.name), "visible_scope": "own_hand", "opponent_chooses": true, "min_select": mini(3, items.size()), "max_select": mini(3, items.size()), "allow_cancel": false}]
	func validate_attack_interaction(attacker: PokemonSlot, _index: int, targets: Array, state: GameState) -> Dictionary:
		var cards := state.players[1-attacker.get_top_card().owner_index].hand
		if cards.is_empty():
			return interaction_validation_ok()
		return validate_context_selection(get_interaction_context(targets), STEP, cards, mini(3, cards.size()), mini(3, cards.size()))
	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, _index: int, state: GameState) -> void:
		var opponent := state.players[1-attacker.get_top_card().owner_index]
		for card: Variant in get_attack_interaction_context().get(STEP, []):
			if card is CardInstance and card in opponent.hand:
				opponent.hand.erase(card)
				card.face_up = false
				opponent.deck.append(card)
		opponent.shuffle_deck()
