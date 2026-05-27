class_name AbilityTorrentHeart
extends BaseEffect

const USED_FLAG_TYPE := "torrent_heart_used"
const BONUS_FLAG_TYPE := "torrent_heart_damage_bonus"

var self_damage_counters: int = 5
var bonus_damage: int = 120


func _init(counter_count: int = 5, damage_bonus: int = 120) -> void:
	self_damage_counters = counter_count
	bonus_damage = damage_bonus


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or pokemon.get_top_card() == null or state == null:
		return false
	if pokemon.is_knocked_out():
		return false
	var owner_index := int(pokemon.get_top_card().owner_index)
	if owner_index < 0 or owner_index >= state.players.size():
		return false
	if state.current_player_index != owner_index:
		return false
	if pokemon not in state.players[owner_index].get_all_pokemon():
		return false
	for effect_data: Dictionary in pokemon.effects:
		if effect_data.get("type", "") == USED_FLAG_TYPE and int(effect_data.get("turn", -999)) == state.turn_number:
			return false
	return true


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	state: GameState
) -> void:
	if not can_use_ability(pokemon, state):
		return
	pokemon.damage_counters += self_damage_counters * 10
	pokemon.effects.append({
		"type": USED_FLAG_TYPE,
		"turn": state.turn_number,
	})
	pokemon.effects.append({
		"type": BONUS_FLAG_TYPE,
		"turn": state.turn_number,
		"amount": bonus_damage,
	})


func get_attack_modifier_for_attacker(
	source: PokemonSlot,
	attacker: PokemonSlot,
	state: GameState,
	defender: PokemonSlot = null
) -> int:
	if source == null or attacker == null or source != attacker or state == null:
		return 0
	if defender == null:
		return 0
	var top := attacker.get_top_card()
	if top == null:
		return 0
	var opponent_index := 1 - int(top.owner_index)
	if opponent_index < 0 or opponent_index >= state.players.size():
		return 0
	if defender != state.players[opponent_index].active_pokemon:
		return 0
	for effect_data: Dictionary in attacker.effects:
		if effect_data.get("type", "") == BONUS_FLAG_TYPE and int(effect_data.get("turn", -999)) == state.turn_number:
			return int(effect_data.get("amount", bonus_damage))
	return 0


func get_description() -> String:
	return "Once during your turn, place 5 damage counters on this Pokemon. Its attacks do 120 more damage to the opponent's Active Pokemon this turn."
