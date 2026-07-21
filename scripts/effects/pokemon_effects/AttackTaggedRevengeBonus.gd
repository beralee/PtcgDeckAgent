class_name AttackTaggedRevengeBonus
extends BaseEffect

const FLAG_PREFIX := "attack_damage_knockout_names"

var bonus_damage: int = 100
var required_name_prefixes: PackedStringArray = PackedStringArray()
var attack_index_to_match: int = -1


func _init(
	bonus: int = 100,
	name_prefixes: PackedStringArray = PackedStringArray(),
	match_attack_index: int = -1
) -> void:
	bonus_damage = bonus
	required_name_prefixes = name_prefixes.duplicate()
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index == attack_index_to_match


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return 0
	var owner_index := attacker.get_top_card().owner_index
	var previous_turn := state.turn_number - 1
	var key := "%s:%d:%d" % [FLAG_PREFIX, owner_index, previous_turn]
	var names_raw: Variant = state.shared_turn_flags.get(key, [])
	if not (names_raw is Array):
		return 0
	for raw_name: Variant in names_raw:
		if _matches_required_prefix(str(raw_name)):
			return bonus_damage
	return 0


func execute_attack(
	_attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	pass


func _matches_required_prefix(card_name: String) -> bool:
	for prefix: String in required_name_prefixes:
		if prefix != "" and card_name.begins_with(prefix):
			return true
	return false


func get_description() -> String:
	return "Deal %d more damage if a matching Pokemon was Knocked Out by attack damage during the opponent's previous turn." % bonus_damage
