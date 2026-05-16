class_name CSV9CSimplePreviousOwnTurnOtherAncientAttackBonus
extends BaseEffect

const FLAG_PREFIX := "csv9c_ancient_attack_sources"

var bonus_damage: int = 150
var attack_index_to_match: int = -1


func _init(bonus: int = 150, match_attack_index: int = -1) -> void:
	bonus_damage = bonus
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == attack_index


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	if attacker == null or state == null or attacker.get_top_card() == null:
		return 0
	var owner_index := attacker.get_top_card().owner_index
	var previous_own_turn := state.turn_number - 2
	if previous_own_turn < 1:
		return 0
	var current_source_id := attacker.get_top_card().instance_id
	var sources: Array = state.shared_turn_flags.get(_flag_key(owner_index, previous_own_turn), [])
	for raw_source_id: Variant in sources:
		if int(raw_source_id) != current_source_id:
			return bonus_damage
	return 0


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or state == null or not applies_to_attack_index(attack_index):
		return
	record_ancient_attack(attacker, state)


static func record_ancient_attack(attacker: PokemonSlot, state: GameState) -> void:
	if attacker == null or state == null or attacker.get_top_card() == null:
		return
	var data := attacker.get_card_data()
	if data == null or not data.is_ancient_pokemon():
		return
	var owner_index := attacker.get_top_card().owner_index
	var key := _flag_key(owner_index, state.turn_number)
	var sources: Array = state.shared_turn_flags.get(key, [])
	var source_id := attacker.get_top_card().instance_id
	if source_id not in sources:
		sources.append(source_id)
	state.shared_turn_flags[key] = sources


static func _flag_key(player_index: int, turn_number: int) -> String:
	return "%s_%d_%d" % [FLAG_PREFIX, player_index, turn_number]


func get_description() -> String:
	return "This attack does more damage if another Ancient Pokemon attacked during your previous turn."
