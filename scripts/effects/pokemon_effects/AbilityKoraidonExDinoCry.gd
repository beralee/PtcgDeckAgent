class_name AbilityKoraidonExDinoCry
extends BaseEffect

const STEP_ID := "dino_cry_fighting_energy_assignments"
const END_TURN_MARKER := "ability_end_turn_draw_triggered"

var max_energy_count: int = 2


func _init(max_count: int = 2) -> void:
	max_energy_count = maxi(0, max_count)


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or state == null or pokemon.get_top_card() == null:
		return false
	var owner_index := int(pokemon.get_top_card().owner_index)
	if owner_index != state.current_player_index or pokemon.has_ability_used(state.turn_number):
		return false
	var player := state.players[owner_index]
	return not _basic_fighting_energy(player).is_empty() and not _basic_fighting_targets(player).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	if card == null or state == null:
		return []
	var player := state.players[card.owner_index]
	var energy_items := _basic_fighting_energy(player)
	var target_items := _basic_fighting_targets(player)
	if energy_items.is_empty() or target_items.is_empty():
		return []
	var energy_labels: Array[String] = []
	for energy: CardInstance in energy_items:
		energy_labels.append(energy.card_data.name)
	var target_labels: Array[String] = []
	for slot: PokemonSlot in target_items:
		target_labels.append("%s (Energy %d)" % [slot.get_pokemon_name(), slot.attached_energy.size()])
	return [build_card_assignment_step(
		STEP_ID,
		"选择最多2张基本斗能量，任意分配给己方斗属性基础宝可梦",
		energy_items,
		energy_labels,
		target_items,
		target_labels,
		1,
		mini(max_energy_count, energy_items.size()),
		true,
	)]


func validate_ability_interaction(
	pokemon: PokemonSlot,
	ability_index: int,
	targets: Array,
	state: GameState
) -> Dictionary:
	if pokemon == null or state == null or ability_index != 0 or pokemon.get_top_card() == null:
		return interaction_validation_error("Dino Cry source or ability index is invalid")
	var player := state.players[pokemon.get_top_card().owner_index]
	var context := get_interaction_context(targets)
	if not context.has(STEP_ID):
		return interaction_validation_error("missing interaction step: %s" % STEP_ID)
	var raw: Variant = context.get(STEP_ID)
	if not (raw is Array):
		return interaction_validation_error("interaction step is not an array: %s" % STEP_ID)
	var assignments: Array = raw
	if assignments.is_empty() or assignments.size() > max_energy_count:
		return interaction_validation_error("Dino Cry requires 1 to %d assignments" % max_energy_count)
	var legal_energy := _basic_fighting_energy(player)
	var legal_targets := _basic_fighting_targets(player)
	var used_sources := {}
	for entry: Variant in assignments:
		if not (entry is Dictionary):
			return interaction_validation_error("Dino Cry assignment must contain a source and target")
		var source: Variant = (entry as Dictionary).get("source", null)
		var target: Variant = (entry as Dictionary).get("target", null)
		if not (source is CardInstance) or source not in legal_energy:
			return interaction_validation_error("Dino Cry contains an illegal Basic Fighting Energy")
		if not (target is PokemonSlot) or target not in legal_targets:
			return interaction_validation_error("Dino Cry contains an illegal Basic Fighting Pokemon target")
		var source_id := int((source as CardInstance).instance_id)
		if used_sources.has(source_id):
			return interaction_validation_error("Dino Cry cannot assign the same Energy twice")
		used_sources[source_id] = true
	return interaction_validation_ok()


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> void:
	if not can_use_ability(pokemon, state):
		return
	var owner_index := int(pokemon.get_top_card().owner_index)
	var player := state.players[owner_index]
	var assignments := _resolve_assignments(player, get_interaction_context(targets))
	if assignments.is_empty():
		return
	for assignment: Dictionary in assignments:
		var energy: CardInstance = assignment.get("source", null)
		var target: PokemonSlot = assignment.get("target", null)
		if energy == null or target == null or energy not in player.discard_pile:
			continue
		player.discard_pile.erase(energy)
		energy.face_up = true
		target.attached_energy.append(energy)
	pokemon.mark_ability_used(state.turn_number)
	pokemon.effects.append({
		"type": END_TURN_MARKER,
		"turn": state.turn_number,
		"player": owner_index,
	})


func _resolve_assignments(player: PlayerState, context: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var used_sources := {}
	for entry: Variant in context.get(STEP_ID, []):
		if not (entry is Dictionary):
			continue
		var source: Variant = (entry as Dictionary).get("source", null)
		var target: Variant = (entry as Dictionary).get("target", null)
		if not (source is CardInstance) or not (target is PokemonSlot):
			continue
		var energy := source as CardInstance
		var slot := target as PokemonSlot
		if energy not in _basic_fighting_energy(player) or slot not in _basic_fighting_targets(player):
			continue
		if used_sources.has(energy.instance_id):
			continue
		used_sources[energy.instance_id] = true
		result.append({"source": energy, "target": slot})
		if result.size() >= max_energy_count:
			break
	return result


func _basic_fighting_energy(player: PlayerState) -> Array:
	var result: Array = []
	for card: CardInstance in player.discard_pile:
		if card == null or card.card_data == null or card.card_data.card_type != "Basic Energy":
			continue
		if card.card_data.energy_provides == "F" or card.card_data.energy_type == "F":
			result.append(card)
	return result


func _basic_fighting_targets(player: PlayerState) -> Array:
	var result: Array = []
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null or slot.get_remaining_hp() <= 0:
			continue
		var card_data := slot.get_card_data()
		if card_data != null and card_data.stage == "Basic" and card_data.energy_type == "F":
			result.append(slot)
	return result


func get_description() -> String:
	return "Once during your turn, attach up to 2 Basic Fighting Energy from discard to your Basic Fighting Pokemon in any way. Your turn ends."
