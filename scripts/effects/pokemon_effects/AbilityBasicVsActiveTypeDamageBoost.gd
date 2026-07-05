class_name AbilityBasicVsActiveTypeDamageBoost
extends BaseEffect

var bonus_damage: int = 30
var defender_energy_type: String = "D"


func _init(amount: int = 30, target_energy_type: String = "D") -> void:
	bonus_damage = amount
	defender_energy_type = target_energy_type


func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	pass


func get_attack_modifier_for_attacker(
	_source: PokemonSlot,
	attacker: PokemonSlot,
	state: GameState,
	defender: PokemonSlot = null
) -> int:
	if attacker == null or defender == null or state == null:
		return 0
	var attacker_card := attacker.get_card_data()
	var defender_card := defender.get_card_data()
	if attacker_card == null or defender_card == null:
		return 0
	if not attacker_card.is_basic_pokemon():
		return 0
	if defender_card.energy_type != defender_energy_type:
		return 0
	var attacker_owner := _owner_index(attacker)
	if attacker_owner < 0:
		return 0
	var opponent_index := 1 - attacker_owner
	if opponent_index < 0 or opponent_index >= state.players.size():
		return 0
	if state.players[opponent_index].active_pokemon != defender:
		return 0
	return bonus_damage


func _owner_index(slot: PokemonSlot) -> int:
	if slot == null:
		return -1
	var top := slot.get_top_card()
	return top.owner_index if top != null else -1


func get_description() -> String:
	return "Your Basic Pokemon's attacks do %d more damage to the opponent's Active %s Pokemon." % [
		bonus_damage,
		defender_energy_type,
	]
