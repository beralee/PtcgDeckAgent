class_name AttackOwnOpponentFieldTypeMatchBonus
extends BaseEffect

var bonus_damage: int = 120


func _init(bonus: int = 120) -> void:
	bonus_damage = max(0, bonus)


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return 0
	var owner_index: int = attacker.get_top_card().owner_index
	if owner_index < 0 or owner_index >= state.players.size():
		return 0
	var opponent_index := 1 - owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return 0

	var own_types := _collect_field_types(state.players[owner_index])
	if own_types.is_empty():
		return 0
	for type_key: String in _collect_field_types(state.players[opponent_index]).keys():
		if own_types.has(type_key):
			return bonus_damage
	return 0


func _collect_field_types(player: PlayerState) -> Dictionary:
	var result: Dictionary = {}
	if player == null:
		return result
	for slot: PokemonSlot in player.get_all_pokemon():
		var cd: CardData = slot.get_card_data() if slot != null else null
		var energy_type := str(cd.energy_type).strip_edges() if cd != null else ""
		if energy_type != "":
			result[energy_type] = true
	return result


func get_description() -> String:
	return "This attack does %d more damage if any of your Pokemon in play has the same type as any of your opponent's Pokemon in play." % bonus_damage
