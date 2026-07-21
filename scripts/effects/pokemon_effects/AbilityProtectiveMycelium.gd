class_name AbilityProtectiveMycelium
extends BaseEffect


func prevents_attack_effects_to_target(
	source: PokemonSlot,
	target: PokemonSlot,
	attacker: PokemonSlot,
	_state: GameState
) -> bool:
	if source == null or target == null or attacker == null:
		return false
	if source.get_top_card() == null or target.get_top_card() == null or attacker.get_top_card() == null:
		return false
	var owner := source.get_top_card().owner_index
	return (
		target.get_top_card().owner_index == owner
		and attacker.get_top_card().owner_index != owner
		and not target.attached_energy.is_empty()
	)


func get_description() -> String:
	return "Your Pokemon with Energy attached are protected from effects of attacks used by your opponent's Pokemon."
