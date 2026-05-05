class_name AbilityPlaceDamageCountersVSTAR
extends BaseEffect

const TARGET_STEP_ID := "opponent_pokemon_damage_counter_target"

var counter_count: int = 4


func _init(count: int = 4) -> void:
	counter_count = max(0, count)


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or pokemon.get_top_card() == null or state == null:
		return false
	var top: CardInstance = pokemon.get_top_card()
	var player_index := top.owner_index
	if state.current_player_index != player_index:
		return false
	if state.phase != GameState.GamePhase.MAIN:
		return false
	if state.vstar_power_used[player_index]:
		return false
	return not state.players[1 - player_index].get_all_pokemon().is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	if card == null or state == null:
		return []
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var targets: Array = opponent.get_all_pokemon()
	if targets.is_empty():
		return []
	var labels: Array[String] = []
	for slot: PokemonSlot in targets:
		labels.append("%s (HP %d/%d)" % [
			slot.get_pokemon_name(),
			slot.get_remaining_hp(),
			slot.get_max_hp(),
		])
	return [{
		"id": TARGET_STEP_ID,
		"title": "选择对手的1只宝可梦，放置%d个伤害指示物" % counter_count,
		"items": targets,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


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
	var player_index := top.owner_index
	var opponent: PlayerState = state.players[1 - player_index]
	var legal_targets: Array = opponent.get_all_pokemon()
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_target: PokemonSlot = _first_valid_target(ctx.get(TARGET_STEP_ID, []), legal_targets)
	if selected_target == null:
		selected_target = legal_targets[0] if not legal_targets.is_empty() else null
	if selected_target == null:
		return
	selected_target.damage_counters += counter_count * 10
	state.vstar_power_used[player_index] = true


func _first_valid_target(raw: Array, legal_targets: Array) -> PokemonSlot:
	for entry: Variant in raw:
		if entry is PokemonSlot and entry in legal_targets:
			return entry as PokemonSlot
	return null


func get_description() -> String:
	return "VSTAR Power: put damage counters on 1 of your opponent's Pokemon."
