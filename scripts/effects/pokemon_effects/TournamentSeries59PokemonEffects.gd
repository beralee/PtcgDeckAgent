extends RefCounted

## Exact printed rules used by the series-59 tournament content release.
class RagingDraw extends BaseEffect:
	const USED := "dodrio_raging_draw_used"

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null or pokemon.is_knocked_out():
			return false
		var seat := pokemon.get_top_card().owner_index
		if seat != state.current_player_index or pokemon not in state.players[seat].get_all_pokemon():
			return false
		for marker: Dictionary in pokemon.effects:
			if marker.get("type", "") == USED and int(marker.get("turn", -1)) == state.turn_number:
				return false
		return true

	func execute_ability(pokemon: PokemonSlot, _index: int, _targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var top := pokemon.get_top_card()
		pokemon.effects.append({"type": USED, "turn": state.turn_number})
		pokemon.damage_counters += 10
		# All effects finish before the state machine checks Knock Outs.
		_draw_cards_with_log(state, top.owner_index, 1, top, "ability")

	func get_description() -> String:
		return "Once during your turn, put 1 damage counter on this Pokemon, then draw a card."

class DazzlingGaze extends BaseEffect:
	func get_opponent_attack_colorless_cost_modifier(source: PokemonSlot, attacker: PokemonSlot, _attack: Dictionary, state: GameState) -> int:
		if source == null or attacker == null or state == null or source.get_top_card() == null or attacker.get_top_card() == null:
			return 0
		var owner := source.get_top_card().owner_index
		if state.players[owner].active_pokemon != source:
			return 0
		if attacker.get_top_card().owner_index == owner or state.players[1 - owner].active_pokemon != attacker:
			return 0
		return 1

	func get_description() -> String:
		return "While this Pokemon is Active, the opponent's Active Pokemon's attacks cost one more Colorless Energy."

class ActiveEnergyCountBonus extends BaseEffect:
	var _processor: WeakRef
	var _per_energy: int
	var _include_attacker: bool

	func _init(processor: EffectProcessor, per_energy: int, include_attacker: bool) -> void:
		_processor = weakref(processor)
		_per_energy = per_energy
		_include_attacker = include_attacker
		bind_default_attack_index(0)

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or attacker.get_top_card() == null or state == null:
			return 0
		var processor: EffectProcessor = _processor.get_ref()
		if processor == null:
			return 0
		var defender := state.players[1 - attacker.get_top_card().owner_index].active_pokemon
		var energy_units := 0
		var slots: Array[PokemonSlot] = [defender]
		if _include_attacker:
			slots.append(attacker)
		for slot: PokemonSlot in slots:
			if slot == null:
				continue
			for energy: CardInstance in slot.attached_energy:
				energy_units += processor.get_energy_colorless_count(energy, state)
		return energy_units * _per_energy

	func get_description() -> String:
		return "Adds printed damage per Energy unit attached to the specified Active Pokemon."

class OpponentFieldEnergyDamage extends BaseEffect:
	var _processor: WeakRef
	func _init(processor: EffectProcessor) -> void:
		_processor = weakref(processor)
		bind_default_attack_index(0)
	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		var processor: EffectProcessor = _processor.get_ref()
		var count := 0
		for slot: PokemonSlot in state.players[1-attacker.get_top_card().owner_index].get_all_pokemon():
			for energy: CardInstance in slot.attached_energy:
				count += processor.get_energy_colorless_count(energy, state)
		# Printed 50x is parsed as a base 50 by the shared damage calculator.
		return 50 * count - 50
	func cancels_attack_damage(attacker: PokemonSlot, _defender: PokemonSlot, index: int, state: GameState) -> bool:
		return index == 0 and get_damage_bonus(attacker, state) == -50

class OpponentTakenPrizeDamage extends BaseEffect:
	func _init() -> void:
		bind_default_attack_index(0)
	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		var taken := maxi(0, 6 - state.players[1-attacker.get_top_card().owner_index].prizes.size())
		return 70 * taken - 70
	func cancels_attack_damage(attacker: PokemonSlot, _defender: PokemonSlot, index: int, state: GameState) -> bool:
		return index == 0 and get_damage_bonus(attacker, state) == -70

class CrimsonArmor extends BaseEffect:
	func get_defense_modifier_for_defender(source: PokemonSlot, defender: PokemonSlot, _state: GameState) -> int:
		return -80 if source == defender and defender.damage_counters == 0 else 0

class FireEnergyBonus extends BaseEffect:
	var _processor: WeakRef
	func _init(processor: EffectProcessor) -> void:
		_processor = weakref(processor)
		bind_default_attack_index(0)
	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		var processor: EffectProcessor = _processor.get_ref()
		var count := 0
		for energy: CardInstance in attacker.attached_energy:
			var types := processor.get_energy_types(energy, state)
			if "R" in types or "ANY" in types:
				count += processor.get_energy_colorless_count(energy, state)
		return 40 * count

class ExplodingEnergy extends BaseEffect:
	const STEP := "forretress_exploding_energy"
	func knocks_out_self() -> bool:
		return true
	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or pokemon.is_knocked_out():
			return false
		var seat := pokemon.get_top_card().owner_index
		return state.current_player_index == seat and pokemon in state.players[seat].get_all_pokemon() and not pokemon.has_ability_used(state.turn_number)
	func _sources(player: PlayerState) -> Array:
		var result: Array = []
		for card: CardInstance in player.deck:
			if card.card_data.card_type == "Basic Energy" and card.card_data.energy_provides == "G":
				result.append(card)
		return result
	func _targets(player: PlayerState, source: PokemonSlot) -> Array:
		var result: Array = []
		for slot: PokemonSlot in player.get_all_pokemon():
			if slot != source and not slot.is_knocked_out():
				result.append(slot)
		return result
	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var player := state.players[card.owner_index]
		var source: PokemonSlot = null
		for slot: PokemonSlot in player.get_all_pokemon():
			if slot.get_top_card() == card:
				source = slot
		var sources := _sources(player)
		var targets := _targets(player, source)
		if sources.is_empty() or targets.is_empty():
			return []
		var source_labels: Array[String] = []
		var target_labels: Array[String] = []
		for energy: CardInstance in sources:
			source_labels.append(energy.card_data.name)
		for target: PokemonSlot in targets:
			target_labels.append(target.get_pokemon_name())
		return [build_full_library_card_assignment_step(STEP, "选择最多5张基本草能量分配给己方宝可梦", player.deck, sources, source_labels, targets, target_labels, 0, mini(5, sources.size()), VISIBLE_SCOPE_OWN_FULL_DECK, true)]
	func validate_ability_interaction(pokemon: PokemonSlot, _index: int, selections: Array, state: GameState) -> Dictionary:
		var player := state.players[pokemon.get_top_card().owner_index]
		var context := get_interaction_context(selections)
		var assignments: Variant = context.get(STEP, [])
		if not assignments is Array or assignments.size() > 5:
			return interaction_validation_error("Exploding Energy allows at most five assignments")
		if not context.has(STEP) and not _sources(player).is_empty() and not _targets(player, pokemon).is_empty():
			return interaction_validation_error("Exploding Energy needs an explicit selection or decline")
		var seen: Array = []
		for assignment: Variant in assignments:
			if not assignment is Dictionary:
				return interaction_validation_error("Invalid energy assignment")
			var source: Variant = assignment.get("source")
			if source not in _sources(player) or source in seen or assignment.get("target") not in _targets(player, pokemon):
				return interaction_validation_error("Exploding Energy requires unique Basic Grass Energy from own deck and a surviving own target")
			seen.append(source)
		return interaction_validation_ok()
	func execute_ability(pokemon: PokemonSlot, index: int, selections: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state) or not validate_ability_interaction(pokemon, index, selections, state).get("valid", false):
			return
		var player := state.players[pokemon.get_top_card().owner_index]
		pokemon.mark_ability_used(state.turn_number)
		pokemon.damage_counters = pokemon.get_max_hp()
		for assignment: Dictionary in get_interaction_context(selections).get(STEP, []):
			var energy: CardInstance = assignment.source
			player.deck.erase(energy)
			energy.face_up = true
			(assignment.target as PokemonSlot).attached_energy.append(energy)
		player.shuffle_deck()

class EvolutionInterference extends BaseEffect:
	const Rules = preload("res://scripts/engine/TournamentSeries59TemporaryRules.gd")
	func _init() -> void:
		bind_default_attack_index(0)
	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, index: int, state: GameState) -> void:
		if index == 0:
			# This affects the opposing player, so switching/KO or Mist Energy cannot remove it.
			state.shared_turn_flags[Rules.EVOLUTION_LOCK_PREFIX + str(1-attacker.get_top_card().owner_index)] = state.turn_number + 1

class OilSplash extends BaseEffect:
	const Rules = preload("res://scripts/engine/TournamentSeries59TemporaryRules.gd")
	func _init() -> void:
		bind_default_attack_index(1)
	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, index: int, state: GameState) -> void:
		if index != 1 or defender == null:
			return
		var processor: EffectProcessor = state.shared_turn_flags.get("_draw_effect_processor")
		if processor != null and processor.is_attack_effect_prevented_by_defender_ability(attacker, defender, state):
			return
		defender.effects.append({"type": Rules.OIL_TYPE, "turn": state.turn_number, "top_instance_id": defender.get_top_card().instance_id})
