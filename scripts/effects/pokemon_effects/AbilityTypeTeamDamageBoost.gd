class_name AbilityTypeTeamDamageBoost
extends BaseEffect

var damage_bonus: int = 20
var boosted_energy_types: PackedStringArray = PackedStringArray(["G", "R"])


func _init(
	bonus: int = 20,
	energy_types: PackedStringArray = PackedStringArray(["G", "R"])
) -> void:
	damage_bonus = maxi(0, bonus)
	boosted_energy_types = energy_types.duplicate()


func get_attack_modifier_for_attacker(
	source: PokemonSlot,
	attacker: PokemonSlot,
	state: GameState,
	defender: PokemonSlot = null
) -> int:
	if source == null or attacker == null or state == null or defender == null:
		return 0
	var source_top := source.get_top_card()
	var attacker_top := attacker.get_top_card()
	if source_top == null or attacker_top == null or source_top.owner_index != attacker_top.owner_index:
		return 0
	var owner_index := source_top.owner_index
	if owner_index < 0 or owner_index >= state.players.size():
		return 0
	if state.players[1 - owner_index].active_pokemon != defender:
		return 0
	var attacker_data := attacker.get_card_data()
	if attacker_data == null or attacker_data.energy_type not in boosted_energy_types:
		return 0
	return damage_bonus


func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	pass


func get_description() -> String:
	return "Your Grass and Fire Pokemon's attacks do %d more damage to the opponent's Active Pokemon." % damage_bonus
