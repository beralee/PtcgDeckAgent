class_name CSV9C178GlassTrumpet
extends BaseEffect

const ASSIGNMENT_ID := "csv9c178_energy_assignments"
const H = preload("res://scripts/effects/CSV9CHelpers.gd")


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return _has_tera_pokemon(player) and not _get_basic_energy(player).is_empty() and not _get_colorless_bench_targets(player).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var source_items: Array = _get_basic_energy(player)
	var source_labels: Array[String] = []
	for energy_card: CardInstance in source_items:
		source_labels.append(energy_card.card_data.name)
	var target_items: Array = _get_colorless_bench_targets(player)
	var target_labels: Array[String] = []
	for slot: PokemonSlot in target_items:
		target_labels.append(H.slot_label(slot, state))
	var step := build_card_assignment_step(
		ASSIGNMENT_ID,
		"选择最多2张弃牌区基本能量，各附着给1只备战区无属性宝可梦",
		source_items,
		source_labels,
		target_items,
		target_labels,
		0,
		mini(2, mini(source_items.size(), target_items.size())),
		true
	)
	step["max_assignments_per_target"] = 1
	return [step]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	if not _has_tera_pokemon(player):
		return
	var assignments := _resolve_assignments(player, get_interaction_context(targets))
	if assignments.is_empty() and not get_interaction_context(targets).has(ASSIGNMENT_ID):
		assignments = _build_fallback_assignments(player)
	for assignment: Dictionary in assignments:
		var energy_card: CardInstance = assignment.get("source")
		var target_slot: PokemonSlot = assignment.get("target")
		if energy_card == null or target_slot == null:
			continue
		if energy_card not in player.discard_pile or target_slot not in _get_colorless_bench_targets(player):
			continue
		player.discard_pile.erase(energy_card)
		energy_card.face_up = true
		target_slot.attached_energy.append(energy_card)


func _resolve_assignments(player: PlayerState, ctx: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var used_sources: Array[CardInstance] = []
	var used_targets: Array[PokemonSlot] = []
	for entry: Variant in ctx.get(ASSIGNMENT_ID, []):
		if not (entry is Dictionary):
			continue
		var source: Variant = (entry as Dictionary).get("source")
		var target: Variant = (entry as Dictionary).get("target")
		if not (source is CardInstance) or not (target is PokemonSlot):
			continue
		var energy_card: CardInstance = source
		var target_slot: PokemonSlot = target
		if energy_card in used_sources or target_slot in used_targets:
			continue
		if not _is_basic_energy(energy_card) or energy_card not in player.discard_pile:
			continue
		if target_slot not in _get_colorless_bench_targets(player):
			continue
		used_sources.append(energy_card)
		used_targets.append(target_slot)
		result.append({"source": energy_card, "target": target_slot})
		if result.size() >= 2:
			break
	return result


func _build_fallback_assignments(player: PlayerState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var sources := _get_basic_energy(player)
	var targets := _get_colorless_bench_targets(player)
	for i: int in mini(2, mini(sources.size(), targets.size())):
		result.append({"source": sources[i], "target": targets[i]})
	return result


func _has_tera_pokemon(player: PlayerState) -> bool:
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot != null and _is_tera_pokemon(slot.get_card_data()):
			return true
	return false


func _is_tera_pokemon(cd: CardData) -> bool:
	if cd == null or not cd.is_pokemon():
		return false
	return cd.is_tera_pokemon()


func _get_basic_energy(player: PlayerState) -> Array:
	var result: Array = []
	for discard_card: CardInstance in player.discard_pile:
		if _is_basic_energy(discard_card):
			result.append(discard_card)
	return result


func _get_colorless_bench_targets(player: PlayerState) -> Array:
	var result: Array = []
	for slot: PokemonSlot in player.bench:
		var cd := slot.get_card_data()
		if cd != null and cd.energy_type == "C":
			result.append(slot)
	return result


func _is_basic_energy(card: CardInstance) -> bool:
	return card != null and card.card_data != null and card.card_data.card_type == "Basic Energy"


func get_description() -> String:
	return "自己场上有太晶宝可梦时，给最多2只备战区无属性宝可梦各附着1张弃牌区基本能量。"
