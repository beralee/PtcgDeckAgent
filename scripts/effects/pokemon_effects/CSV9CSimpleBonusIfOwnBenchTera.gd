class_name CSV9CSimpleBonusIfOwnBenchTera
extends BaseEffect

var bonus_damage: int = 100
var attack_index_to_match: int = -1


func _init(bonus: int = 100, match_attack_index: int = -1) -> void:
	bonus_damage = bonus
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == attack_index


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	if attacker == null or state == null or attacker.get_top_card() == null:
		return 0
	var owner_index := attacker.get_top_card().owner_index
	if owner_index < 0 or owner_index >= state.players.size():
		return 0
	for slot: PokemonSlot in state.players[owner_index].bench:
		var data := slot.get_card_data() if slot != null else null
		if data != null and _is_tera(data):
			return bonus_damage
	return 0


func _is_tera(data: CardData) -> bool:
	return data.ancient_trait == "Tera" or data.has_tag("Tera")


func get_description() -> String:
	return "This attack does more damage if your Bench has a Tera Pokemon."
