class_name AbilityPoisonDamageBoost
extends BaseEffect

const POISON_BONUS_DAMAGE := 20


func get_poison_damage_bonus_for_target(source: PokemonSlot, target: PokemonSlot, state: GameState) -> int:
	if source == null or target == null or state == null or source.get_top_card() == null:
		return 0
	var owner_index := source.get_top_card().owner_index
	var opponent_index := 1 - owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return 0
	return POISON_BONUS_DAMAGE if state.players[opponent_index].active_pokemon == target else 0


func get_description() -> String:
	return "Opponent's Active Pokemon takes 2 more damage counters from Poison."

