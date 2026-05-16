class_name EffectSurvivalBrace
extends BaseEffect


func try_prevent_attack_knockout(
	defender: PokemonSlot,
	attacker: PokemonSlot,
	state: GameState,
	previous_damage: int,
	processor: Variant
) -> bool:
	if defender == null or attacker == null or state == null:
		return false
	if defender.attached_tool == null:
		return false
	if previous_damage != 0:
		return false
	var defender_owner := _slot_owner(defender)
	var attacker_owner := _slot_owner(attacker)
	if defender_owner < 0 or attacker_owner < 0 or defender_owner == attacker_owner:
		return false
	var max_hp := defender.get_max_hp()
	if processor != null and processor.has_method("get_effective_max_hp"):
		max_hp = int(processor.call("get_effective_max_hp", defender, state))
	if max_hp <= 10 or defender.damage_counters < max_hp:
		return false

	var tool_card: CardInstance = defender.attached_tool
	defender.damage_counters = maxi(0, max_hp - 10)
	defender.attached_tool = null
	state.players[defender_owner].discard_pile.append(tool_card)
	return true


func _slot_owner(slot: PokemonSlot) -> int:
	if slot == null or slot.get_top_card() == null:
		return -1
	return slot.get_top_card().owner_index


func get_description() -> String:
	return "If the Pokemon this card is attached to has full HP and would be Knocked Out by damage from an opponent's attack, it remains with 10 HP. Then discard this card."
