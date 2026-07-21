class_name AttackDamageAllOpponentMechanic
extends BaseEffect

var damage_amount: int = 60
var mechanic_filter: String = "ex"
var attack_index_to_match: int = -1


func _init(amount: int = 60, mechanic: String = "ex", match_attack_index: int = -1) -> void:
	damage_amount = maxi(0, amount)
	mechanic_filter = mechanic
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index == attack_index_to_match


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
		return
	var owner_index := attacker.get_top_card().owner_index
	var opponent_index := 1 - owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	for target: PokemonSlot in state.players[opponent_index].get_all_pokemon():
		if target == null or target.get_card_data() == null or not _matches(target.get_card_data()):
			continue
		if processor != null and processor.has_method("is_damage_prevented_by_defender_ability"):
			if bool(processor.call("is_damage_prevented_by_defender_ability", attacker, target, state)):
				continue
		var resolved_damage := damage_amount
		if processor != null:
			if processor.has_method("get_attacker_modifier"):
				resolved_damage += int(processor.call("get_attacker_modifier", attacker, state, target))
			if processor.has_method("get_defender_modifier"):
				resolved_damage += int(processor.call("get_defender_modifier", target, state, attacker))
		resolved_damage = maxi(0, resolved_damage)
		if resolved_damage <= 0:
			continue
		DamageCalculator.new().apply_damage_to_slot(target, resolved_damage)
		if processor != null and processor.has_method("record_effect_damage"):
			processor.call("record_effect_damage", owner_index, target, resolved_damage, state, "attack")


func get_description() -> String:
	return "Deal %d damage to each opposing Pokemon %s without applying Weakness or Resistance." % [damage_amount, mechanic_filter]


func _matches(card_data: CardData) -> bool:
	if card_data == null:
		return false
	return card_data.mechanic == mechanic_filter or card_data.has_tag(mechanic_filter)
