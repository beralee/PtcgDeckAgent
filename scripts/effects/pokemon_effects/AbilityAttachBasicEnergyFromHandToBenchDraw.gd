class_name AbilityAttachBasicEnergyFromHandToBenchDraw
extends BaseEffect

const STEP_ID := "attach_basic_energy_from_hand_to_bench"

var energy_type: String = "P"
var draw_count: int = 2


func _init(required_type: String = "P", cards_to_draw: int = 2) -> void:
	energy_type = required_type
	draw_count = cards_to_draw


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or state == null:
		return false
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	if state.current_player_index != top.owner_index:
		return false
	if pokemon.has_ability_used(state.turn_number):
		return false
	var player: PlayerState = state.players[top.owner_index]
	return not _basic_energy_from_hand(player).is_empty() and not _bench_targets(player).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	if card == null or state == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	var source_items: Array = _basic_energy_from_hand(player)
	var target_items: Array = _bench_targets(player)
	if source_items.is_empty() or target_items.is_empty():
		return []

	var source_labels: Array[String] = []
	for energy_card: CardInstance in source_items:
		source_labels.append(energy_card.card_data.name)

	var target_labels: Array[String] = []
	for slot: PokemonSlot in target_items:
		target_labels.append("%s (HP %d/%d)" % [
			slot.get_pokemon_name(),
			slot.get_remaining_hp(),
			slot.get_max_hp(),
		])

	return [build_card_assignment_step(
		STEP_ID,
		"选择1张手牌中的基本超能量，附着给自己的备战宝可梦",
		source_items,
		source_labels,
		target_items,
		target_labels,
		1,
		1,
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
	var player: PlayerState = state.players[top.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var assignment: Dictionary = _resolve_first_assignment(player, ctx)
	if assignment.is_empty() and not ctx.has(STEP_ID):
		assignment = _build_fallback_assignment(player)
	if assignment.is_empty():
		return

	var energy_card: CardInstance = assignment.get("source", null)
	var target_slot: PokemonSlot = assignment.get("target", null)
	if energy_card == null or target_slot == null:
		return
	player.hand.erase(energy_card)
	target_slot.attached_energy.append(energy_card)
	_draw_cards_with_log(state, top.owner_index, draw_count, top, "ability")
	pokemon.mark_ability_used(state.turn_number)


func _resolve_first_assignment(player: PlayerState, ctx: Dictionary) -> Dictionary:
	var valid_sources: Array = _basic_energy_from_hand(player)
	var valid_targets: Array = _bench_targets(player)
	for entry: Variant in ctx.get(STEP_ID, []):
		if not (entry is Dictionary):
			continue
		var source: Variant = (entry as Dictionary).get("source", null)
		var target: Variant = (entry as Dictionary).get("target", null)
		if source is CardInstance and target is PokemonSlot and source in valid_sources and target in valid_targets:
			return {"source": source, "target": target}
	return {}


func _build_fallback_assignment(player: PlayerState) -> Dictionary:
	var sources: Array = _basic_energy_from_hand(player)
	var targets: Array = _bench_targets(player)
	if sources.is_empty() or targets.is_empty():
		return {}
	return {"source": sources[0], "target": targets[0]}


func _basic_energy_from_hand(player: PlayerState) -> Array:
	var result: Array = []
	if player == null:
		return result
	for hand_card: CardInstance in player.hand:
		if hand_card == null or hand_card.card_data == null:
			continue
		if hand_card.card_data.card_type != "Basic Energy":
			continue
		var provides := str(hand_card.card_data.energy_provides)
		if provides == "":
			provides = str(hand_card.card_data.energy_type)
		if provides == energy_type:
			result.append(hand_card)
	return result


func _bench_targets(player: PlayerState) -> Array:
	var result: Array = []
	if player == null:
		return result
	for slot: PokemonSlot in player.bench:
		if slot != null and slot.get_top_card() != null:
			result.append(slot)
	return result


func get_description() -> String:
	return "Once during your turn, attach a Basic Psychic Energy from your hand to 1 of your Benched Pokemon, then draw 2 cards."
