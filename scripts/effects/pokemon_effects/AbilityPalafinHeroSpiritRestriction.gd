class_name AbilityPalafinHeroSpiritRestriction
extends BaseEffect

const EvolutionRestriction := preload("res://scripts/engine/PokemonEvolutionEntryRestriction.gd")


func can_enter_play_by_evolution(route: String) -> bool:
	return route == EvolutionRestriction.PALAFIN_ZERO_TO_HERO_ROUTE


func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	pass


func get_description() -> String:
	return "This card can be put into play only by the effect of Palafin's Zero to Hero Ability."
