class_name AbilityTachyonBits
extends BaseEffect

const STEP_ID := "tachyon_bits_target"
const DAMAGE_COUNTERS := 20


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or pokemon.get_top_card() == null or state == null:
		return false
	var owner_index := pokemon.get_top_card().owner_index
	if state.current_player_index != owner_index:
		return false
	if state.players[owner_index].active_pokemon != pokemon:
		return false
	if not pokemon.entered_active_from_bench_this_turn(state.turn_number):
		return false
	if pokemon.has_ability_used(state.turn_number):
		return false
	return state.players[1 - owner_index].active_pokemon != null


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var opponent := state.players[1 - card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	if opponent.active_pokemon != null:
		items.append(opponent.active_pokemon)
		labels.append("Active: %s" % opponent.active_pokemon.get_pokemon_name())
	for i: int in opponent.bench.size():
		var slot: PokemonSlot = opponent.bench[i]
		items.append(slot)
		labels.append("Bench %d: %s" % [i + 1, slot.get_pokemon_name()])
	return [{
		"id": STEP_ID,
		"title": "Choose 1 of your opponent's Pokemon to place 2 damage counters on",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
	if not can_use_ability(pokemon, state):
		return
	var owner_index := pokemon.get_top_card().owner_index
	var opponent := state.players[1 - owner_index]
	var target := _resolve_target(get_interaction_context(targets), opponent)
	if target == null:
		return
	target.damage_counters += DAMAGE_COUNTERS
	pokemon.mark_ability_used(state.turn_number)


func _resolve_target(ctx: Dictionary, opponent: PlayerState) -> PokemonSlot:
	var selected_raw: Array = ctx.get(STEP_ID, [])
	if not selected_raw.is_empty() and selected_raw[0] is PokemonSlot:
		var selected: PokemonSlot = selected_raw[0]
		if selected == opponent.active_pokemon or selected in opponent.bench:
			return selected
	return opponent.active_pokemon


func get_description() -> String:
	return "When this Pokemon moves from the Bench to the Active Spot, place 2 damage counters on 1 of your opponent's Pokemon."

