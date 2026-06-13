class_name AbilityZamazentaVSTARShield
extends BaseEffect

const SHIELD_FLAG_KEY := "zamazenta_vstar_star_shield"
const DAMAGE_REDUCTION := 100


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or state == null:
		return false
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	var pi: int = top.owner_index
	if pi < 0 or pi >= state.vstar_power_used.size():
		return false
	if state.current_player_index != pi:
		return false
	return not state.vstar_power_used[pi]


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	state: GameState
) -> void:
	if not can_use_ability(pokemon, state):
		return
	var owner_index: int = pokemon.get_top_card().owner_index
	_record_shield(owner_index, state)
	state.vstar_power_used[owner_index] = true


static func get_global_defense_modifier(
	defender: PokemonSlot,
	attacker: PokemonSlot,
	state: GameState
) -> int:
	if defender == null or attacker == null or state == null:
		return 0
	var defender_owner := _slot_owner(defender)
	var attacker_owner := _slot_owner(attacker)
	if defender_owner < 0 or attacker_owner < 0 or defender_owner == attacker_owner:
		return 0
	for entry: Dictionary in _get_shield_entries(state):
		if int(entry.get("player_index", -1)) != defender_owner:
			continue
		if int(entry.get("applies_turn", -999)) != state.turn_number:
			continue
		if state.current_player_index == defender_owner:
			continue
		return -DAMAGE_REDUCTION
	return 0


func get_description() -> String:
	return "VSTAR Power: during the opponent's next turn, your Pokemon take 100 less damage from attacks."


func _record_shield(player_index: int, state: GameState) -> void:
	var entries := _get_shield_entries(state)
	var next_turn := state.turn_number + 1
	var kept: Array[Dictionary] = []
	for entry: Dictionary in entries:
		if int(entry.get("applies_turn", -999)) >= state.turn_number and int(entry.get("player_index", -1)) != player_index:
			kept.append(entry)
	kept.append({
		"player_index": player_index,
		"source_turn": state.turn_number,
		"applies_turn": next_turn,
	})
	state.shared_turn_flags[SHIELD_FLAG_KEY] = kept


static func _get_shield_entries(state: GameState) -> Array[Dictionary]:
	var raw: Variant = state.shared_turn_flags.get(SHIELD_FLAG_KEY, [])
	if not (raw is Array):
		return []
	var result: Array[Dictionary] = []
	for item: Variant in raw:
		if item is Dictionary:
			result.append(item)
	return result


static func _slot_owner(slot: PokemonSlot) -> int:
	if slot == null or slot.get_top_card() == null:
		return -1
	return slot.get_top_card().owner_index
