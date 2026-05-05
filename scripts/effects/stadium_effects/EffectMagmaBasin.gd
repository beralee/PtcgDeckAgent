## Magma Basin - once per turn, attach 1 Basic Fire Energy from discard to a Benched Fire Pokemon and place 2 damage counters.
class_name EffectMagmaBasin
extends BaseEffect

const ASSIGNMENT_ID := "magma_basin_assignment"
const FIRE_TYPE: String = "R"
const DAMAGE_COUNTERS: int = 20


func can_use_as_stadium_action(_card: CardInstance, _state: GameState) -> bool:
	return true


func can_execute(_card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[state.current_player_index]
	return not _get_fire_energy(player).is_empty() and not _get_fire_targets(player).is_empty()


func get_interaction_steps(_card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[state.current_player_index]
	var source_items: Array = _get_fire_energy(player)
	var source_labels: Array[String] = []
	for energy_card: CardInstance in source_items:
		source_labels.append(energy_card.card_data.name)
	var target_items: Array = _get_fire_targets(player)
	var target_labels: Array[String] = []
	for slot: PokemonSlot in target_items:
		target_labels.append("%s (HP %d/%d)" % [
			slot.get_pokemon_name(),
			slot.get_remaining_hp(),
			slot.get_max_hp(),
		])
	return [build_card_assignment_step(
		ASSIGNMENT_ID,
		"选择弃牌区1张基本火能量附着给备战区火属性宝可梦",
		source_items,
		source_labels,
		target_items,
		target_labels,
		1,
		1,
		true
	)]


func execute(_card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[state.current_player_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var assignment: Dictionary = _resolve_assignment(player, ctx)
	if assignment.is_empty():
		return

	var energy_card: CardInstance = assignment.get("source", null)
	var target_slot: PokemonSlot = assignment.get("target", null)
	if energy_card == null or target_slot == null:
		return

	player.discard_pile.erase(energy_card)
	energy_card.face_up = true
	target_slot.attached_energy.append(energy_card)
	target_slot.damage_counters += DAMAGE_COUNTERS


func _resolve_assignment(player: PlayerState, ctx: Dictionary) -> Dictionary:
	var selected_raw: Array = ctx.get(ASSIGNMENT_ID, [])
	for entry: Variant in selected_raw:
		if not (entry is Dictionary):
			continue
		var assignment: Dictionary = entry
		var source: Variant = assignment.get("source", null)
		var target: Variant = assignment.get("target", null)
		if not (source is CardInstance) or not (target is PokemonSlot):
			continue
		var source_card: CardInstance = source
		var target_slot: PokemonSlot = target
		if source_card in _get_fire_energy(player) and target_slot in _get_fire_targets(player):
			return {
				"source": source_card,
				"target": target_slot,
			}

	var fallback_energy: Array = _get_fire_energy(player)
	var fallback_targets: Array = _get_fire_targets(player)
	if fallback_energy.is_empty() or fallback_targets.is_empty():
		return {}
	return {
		"source": fallback_energy[0],
		"target": fallback_targets[0],
	}


func _get_fire_energy(player: PlayerState) -> Array:
	var result: Array = []
	for discard_card: CardInstance in player.discard_pile:
		if discard_card.card_data == null:
			continue
		if discard_card.card_data.card_type != "Basic Energy":
			continue
		if discard_card.card_data.energy_provides != FIRE_TYPE:
			continue
		result.append(discard_card)
	return result


func _get_fire_targets(player: PlayerState) -> Array:
	var result: Array = []
	for slot: PokemonSlot in player.bench:
		var card_data: CardData = slot.get_card_data()
		if card_data != null and card_data.energy_type == FIRE_TYPE:
			result.append(slot)
	return result


func get_description() -> String:
	return "Once during each player's turn, attach a Basic Fire Energy card from their discard pile to 1 of their Benched Fire Pokemon. Put 2 damage counters on that Pokemon."
