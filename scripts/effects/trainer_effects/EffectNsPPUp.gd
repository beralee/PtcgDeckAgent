class_name EffectNsPPUp
extends BaseEffect

const ASSIGNMENT_ID := "ns_pp_up_assignment"


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not _get_basic_energy(player).is_empty() and not _get_ns_bench_targets(player).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var source_items := _get_basic_energy(player)
	var source_labels: Array[String] = []
	for energy_card: CardInstance in source_items:
		source_labels.append(energy_card.card_data.name)

	var target_items := _get_ns_bench_targets(player)
	var target_labels: Array[String] = []
	for slot: PokemonSlot in target_items:
		target_labels.append("%s (HP %d/%d)" % [
			slot.get_pokemon_name(),
			slot.get_remaining_hp(),
			slot.get_max_hp(),
		])

	return [build_card_assignment_step(
		ASSIGNMENT_ID,
		"Choose 1 Basic Energy in discard and 1 Benched N's Pokemon",
		source_items,
		source_labels,
		target_items,
		target_labels,
		1,
		1,
		true
	)]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var assignment := _resolve_assignment(player, get_interaction_context(targets))
	if assignment.is_empty():
		return

	var energy_card: CardInstance = assignment.get("source", null)
	var target_slot: PokemonSlot = assignment.get("target", null)
	if energy_card == null or target_slot == null:
		return

	player.discard_pile.erase(energy_card)
	energy_card.face_up = true
	target_slot.attached_energy.append(energy_card)


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
		if source_card in _get_basic_energy(player) and target_slot in _get_ns_bench_targets(player):
			return {
				"source": source_card,
				"target": target_slot,
			}

	var fallback_energy := _get_basic_energy(player)
	var fallback_targets := _get_ns_bench_targets(player)
	if fallback_energy.is_empty() or fallback_targets.is_empty():
		return {}
	return {
		"source": fallback_energy[0],
		"target": fallback_targets[0],
	}


func _get_basic_energy(player: PlayerState) -> Array:
	var result: Array = []
	for discard_card: CardInstance in player.discard_pile:
		if discard_card.card_data == null:
			continue
		if discard_card.card_data.card_type == "Basic Energy":
			result.append(discard_card)
	return result


func _get_ns_bench_targets(player: PlayerState) -> Array:
	var result: Array = []
	for slot: PokemonSlot in player.bench:
		if _is_ns_pokemon(slot):
			result.append(slot)
	return result


func _is_ns_pokemon(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	var cd := slot.get_card_data()
	if not cd.is_pokemon():
		return false
	return _name_is_ns(str(cd.name_en)) or _name_is_ns(str(cd.name))


func _name_is_ns(value: String) -> bool:
	var normalized := value.strip_edges()
	normalized = normalized.replace(char(0x2019), "'")
	normalized = normalized.replace(char(0x2018), "'")
	normalized = normalized.replace(char(0x02BC), "'")
	return normalized.begins_with("N's ") or normalized.begins_with("N的")


func get_description() -> String:
	return "Attach a Basic Energy card from your discard pile to 1 of your Benched N's Pokemon."
