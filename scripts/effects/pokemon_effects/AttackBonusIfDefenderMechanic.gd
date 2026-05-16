class_name AttackBonusIfDefenderMechanic
extends BaseEffect

var bonus_damage: int = 150
var mechanic_filter: String = "VMAX"
var attack_index_to_match: int = -1


func _init(bonus: int = 150, required_mechanic: String = "VMAX", match_attack_index: int = -1) -> void:
	bonus_damage = bonus
	mechanic_filter = required_mechanic
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	if attacker == null or state == null or attacker.get_top_card() == null:
		return 0
	var owner := attacker.get_top_card().owner_index
	var opponent_index := 1 - owner
	if opponent_index < 0 or opponent_index >= state.players.size():
		return 0
	var defender: PokemonSlot = state.players[opponent_index].active_pokemon
	if defender == null:
		return 0
	var cd: CardData = defender.get_card_data()
	if cd == null:
		return 0
	return bonus_damage if _matches_mechanic(cd) else 0


func _matches_mechanic(cd: CardData) -> bool:
	if mechanic_filter == "":
		return true
	if cd.mechanic == mechanic_filter or cd.has_tag(mechanic_filter):
		return true
	return mechanic_filter == "V" and cd.mechanic in ["V", "VSTAR", "VMAX"]


func get_description() -> String:
	return "This attack does more damage if the opponent Active Pokemon matches %s." % mechanic_filter
