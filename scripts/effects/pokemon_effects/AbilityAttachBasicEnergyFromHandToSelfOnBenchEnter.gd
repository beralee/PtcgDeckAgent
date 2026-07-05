class_name AbilityAttachBasicEnergyFromHandToSelfOnBenchEnter
extends AbilityOnBenchEnter

const STEP_ID := "bench_enter_basic_energy_to_self"

var energy_filter: String = "F"
var max_energy: int = 2


func _init(required_energy: String = "F", max_count: int = 2) -> void:
	effect_type = "attach_basic_energy_to_self_on_bench_enter"
	energy_filter = required_energy
	max_energy = max(0, max_count)


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card() if pokemon != null else null
	if top == null or state == null:
		return false
	if top.owner_index < 0 or top.owner_index >= state.players.size():
		return false
	if state.current_player_index != top.owner_index:
		return false
	if not state.players[top.owner_index].bench.has(pokemon):
		return false
	if pokemon.turn_played != state.turn_number:
		return false
	if not pokemon.entered_bench_from_hand_this_turn(state.turn_number):
		return false
	if pokemon.has_ability_used(state.turn_number):
		return false
	return not _basic_energy_from_hand(state.players[top.owner_index]).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	if card == null or state == null:
		return []
	var owner := int(card.owner_index)
	if owner < 0 or owner >= state.players.size():
		return []
	var energy_items := _basic_energy_from_hand(state.players[owner])
	if energy_items.is_empty() or max_energy <= 0:
		return []
	var labels: Array[String] = []
	for energy: CardInstance in energy_items:
		labels.append(energy.card_data.name if energy.card_data != null else "")
	return [{
		"id": STEP_ID,
		"title": "Choose up to %d Basic Fighting Energy from your hand" % max_energy,
		"items": energy_items,
		"labels": labels,
		"presentation": "cards",
		"min_select": 0,
		"max_select": mini(max_energy, energy_items.size()),
		"allow_cancel": true,
		"force_confirm": true,
	}]


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> void:
	if not can_use_ability(pokemon, state):
		return
	var top := pokemon.get_top_card()
	var player := state.players[top.owner_index]
	var selected := _selected_energy(player, targets)
	for energy: CardInstance in selected:
		if energy in player.hand and _is_matching_basic_energy(energy):
			player.hand.erase(energy)
			pokemon.attached_energy.append(energy)
	pokemon.mark_ability_used(state.turn_number)


func _selected_energy(player: PlayerState, targets: Array) -> Array[CardInstance]:
	var selected: Array[CardInstance] = []
	var ctx := get_interaction_context(targets)
	var raw: Array = ctx.get(STEP_ID, [])
	var explicit_selection := ctx.has(STEP_ID)
	var seen_ids := {}
	for entry: Variant in raw:
		if selected.size() >= max_energy:
			break
		if not (entry is CardInstance):
			continue
		var energy: CardInstance = entry
		if seen_ids.has(energy.instance_id):
			continue
		if energy in player.hand and _is_matching_basic_energy(energy):
			selected.append(energy)
			seen_ids[energy.instance_id] = true
	if explicit_selection:
		return selected
	for energy: CardInstance in _basic_energy_from_hand(player):
		if selected.size() >= max_energy:
			break
		selected.append(energy)
	return selected


func _basic_energy_from_hand(player: PlayerState) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	if player == null:
		return result
	for card: CardInstance in player.hand:
		if _is_matching_basic_energy(card):
			result.append(card)
	return result


func _is_matching_basic_energy(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	var cd := card.card_data
	if cd.card_type != "Basic Energy":
		return false
	var provides := str(cd.energy_provides)
	if provides == "":
		provides = str(cd.energy_type)
	return provides == energy_filter


func get_description() -> String:
	return "When this Pokemon is played from hand onto the Bench during your turn, attach up to %d Basic %s Energy from your hand to it." % [max_energy, energy_filter]
