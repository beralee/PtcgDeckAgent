## Adds attack damage based on the number of Special Energy attached to the attacker.
## Used by Cinccino "Special Roll": 70 damage for each attached Special Energy.
class_name AttackSpecialEnergyMultiDamage
extends BaseEffect

var damage_per_special: int = 70


func _init(dmg_per_special: int = 70) -> void:
	damage_per_special = dmg_per_special


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	var special_count := _count_special_energy(attacker, state)
	return special_count * damage_per_special - damage_per_special


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	if state != null and state.shared_turn_flags.has("_draw_effect_processor"):
		return
	var special_count := _count_special_energy(attacker, state)
	defender.damage_counters += damage_per_special * special_count


func _count_special_energy(attacker: PokemonSlot, state: GameState = null) -> int:
	if attacker == null:
		return 0
	var count := 0
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null) if state != null else null
	for energy: CardInstance in attacker.attached_energy:
		if energy == null or energy.card_data == null:
			continue
		if energy.card_data.card_type != "Special Energy":
			continue
		if processor != null and processor.has_method("is_special_energy_suppressed"):
			if bool(processor.call("is_special_energy_suppressed", energy, state)):
				continue
		count += 1
	return count


func get_description() -> String:
	return "Damage is based on attached Special Energy count: %d per card" % damage_per_special
