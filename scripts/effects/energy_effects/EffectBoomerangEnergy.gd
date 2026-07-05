class_name EffectBoomerangEnergy
extends BaseEffect


func get_energy_type() -> String:
	return "C"


func get_energy_count() -> int:
	return 1


func should_return_after_attack_effect_discard(_energy: CardInstance, _attacker: PokemonSlot, _state: GameState) -> bool:
	return true


func get_description() -> String:
	return "Provides 1 Colorless Energy. If discarded by the attached Pokemon's attack effect, return it to that Pokemon after the attack damage and effects."
