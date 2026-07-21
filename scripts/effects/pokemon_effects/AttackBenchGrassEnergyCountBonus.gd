class_name AttackBenchGrassEnergyCountBonus
extends BaseEffect

var bonus_per_pokemon: int = 40
var attack_index_to_match: int = -1


func _init(bonus: int = 40, match_attack_index: int = -1) -> void:
	bonus_per_pokemon = bonus
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index == attack_index_to_match


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return 0
	var player: PlayerState = state.players[attacker.get_top_card().owner_index]
	var eligible := 0
	for slot: PokemonSlot in player.bench:
		if _has_grass_energy(slot, state):
			eligible += 1
	return eligible * bonus_per_pokemon


func _has_grass_energy(slot: PokemonSlot, state: GameState) -> bool:
	if slot == null:
		return false
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	for energy: CardInstance in slot.attached_energy:
		if energy == null or energy.card_data == null:
			continue
		if processor != null and processor.has_method("get_energy_types"):
			var types := PackedStringArray(processor.call("get_energy_types", energy, state))
			if "G" in types or "ANY" in types:
				return true
		else:
			var provided := energy.card_data.energy_provides if energy.card_data.energy_provides != "" else energy.card_data.energy_type
			if provided in ["G", "ANY"]:
				return true
	return false


func get_description() -> String:
	return "This attack does 40 more damage for each of your Benched Pokemon with Grass Energy attached."
