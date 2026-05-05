## Magneton - Knock Out this Pokemon, then attach up to 3 Basic Energy
## from your discard pile to your Lightning Pokemon in any way.
class_name AbilityOvervoltDischarge
extends BaseEffect

const SELECT_ASSIGNMENTS_ID := "overvolt_discharge_assignments"

var max_energy_count: int = 3
var target_energy_type: String = "L"


func _init(max_count: int = 3, target_type: String = "L") -> void:
	max_energy_count = max_count
	target_energy_type = target_type


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or pokemon.get_top_card() == null:
		return false
	if pokemon.get_remaining_hp() <= 0:
		return false
	var pi: int = pokemon.get_top_card().owner_index
	if state.current_player_index != pi:
		return false
	if pokemon.has_ability_used(state.turn_number):
		return false
	var player: PlayerState = state.players[pi]
	return not _get_basic_energy_cards(player.discard_pile).is_empty() and not _get_targets(player, pokemon).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	if card == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	var source_slot := _find_slot_for_card(player, card)
	var energy_items: Array = _get_basic_energy_cards(player.discard_pile)
	var target_items: Array[PokemonSlot] = _get_targets(player, source_slot)
	if energy_items.is_empty() or target_items.is_empty():
		return []

	var energy_labels: Array[String] = []
	for energy_card: CardInstance in energy_items:
		energy_labels.append(energy_card.card_data.name)

	var target_labels: Array[String] = []
	for target_slot: PokemonSlot in target_items:
		target_labels.append("%s（HP %d/%d，能量%d）" % [
			target_slot.get_pokemon_name(),
			target_slot.get_remaining_hp(),
			target_slot.get_max_hp(),
			target_slot.attached_energy.size(),
		])

	return [build_card_assignment_step(
		SELECT_ASSIGNMENTS_ID,
		"选择最多3张基本能量并分配给己方雷属性宝可梦",
		energy_items,
		energy_labels,
		target_items,
		target_labels,
		1,
		mini(max_energy_count, energy_items.size()),
		true
	)]


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> void:
	if not can_use_ability(pokemon, state):
		return
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return
	var pi: int = top.owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(targets)
	var assignments: Array[Dictionary] = _resolve_assignments(player, pokemon, ctx)
	if assignments.is_empty():
		return

	for assignment: Dictionary in assignments:
		var energy_card: CardInstance = assignment.get("source")
		var target_slot: PokemonSlot = assignment.get("target")
		if energy_card == null or target_slot == null:
			continue
		if energy_card not in player.discard_pile:
			continue
		if target_slot not in _get_targets(player, pokemon):
			continue
		player.discard_pile.erase(energy_card)
		energy_card.face_up = true
		target_slot.attached_energy.append(energy_card)

	pokemon.mark_ability_used(state.turn_number)
	pokemon.damage_counters = pokemon.get_max_hp()


func _resolve_assignments(player: PlayerState, source_slot: PokemonSlot, ctx: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var selected_raw: Array = ctx.get(SELECT_ASSIGNMENTS_ID, [])
	var has_explicit_assignments: bool = ctx.has(SELECT_ASSIGNMENTS_ID)
	var used_sources: Dictionary = {}
	for entry: Variant in selected_raw:
		if not (entry is Dictionary):
			continue
		var assignment: Dictionary = entry
		var source: Variant = assignment.get("source")
		var target: Variant = assignment.get("target")
		if not (source is CardInstance) or not (target is PokemonSlot):
			continue
		var source_card: CardInstance = source as CardInstance
		var target_slot: PokemonSlot = target as PokemonSlot
		if used_sources.has(source_card.instance_id):
			continue
		if source_card not in _get_basic_energy_cards(player.discard_pile):
			continue
		if target_slot not in _get_targets(player, source_slot):
			continue
		used_sources[source_card.instance_id] = true
		result.append({
			"source": source_card,
			"target": target_slot,
		})
		if result.size() >= max_energy_count:
			break
	if not result.is_empty():
		return result
	if has_explicit_assignments:
		return []

	var fallback_targets: Array[PokemonSlot] = _get_targets(player, source_slot)
	if fallback_targets.is_empty():
		return []
	var fallback_target: PokemonSlot = fallback_targets[0]
	for energy_card: CardInstance in _get_basic_energy_cards(player.discard_pile):
		result.append({
			"source": energy_card,
			"target": fallback_target,
		})
		if result.size() >= max_energy_count:
			break
	return result


func _get_basic_energy_cards(cards: Array[CardInstance]) -> Array:
	var result: Array = []
	for card: CardInstance in cards:
		if card != null and card.card_data != null and card.card_data.card_type == "Basic Energy":
			result.append(card)
	return result


func _get_targets(player: PlayerState, source_slot: PokemonSlot) -> Array[PokemonSlot]:
	var result: Array[PokemonSlot] = []
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null or slot == source_slot or slot.get_top_card() == null:
			continue
		if slot.get_remaining_hp() <= 0:
			continue
		var cd: CardData = slot.get_card_data()
		if cd != null and cd.energy_type == target_energy_type:
			result.append(slot)
	return result


func _find_slot_for_card(player: PlayerState, card: CardInstance) -> PokemonSlot:
	if card == null:
		return null
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot != null and slot.get_top_card() == card:
			return slot
	return null


func get_description() -> String:
	return "Knock Out this Pokemon and attach up to 3 Basic Energy from discard to your Lightning Pokemon."
