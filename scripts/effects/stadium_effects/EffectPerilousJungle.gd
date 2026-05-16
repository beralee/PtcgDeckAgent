class_name EffectPerilousJungle
extends BaseEffect

const POISON_BONUS_DAMAGE := 20


func get_poison_damage_bonus(slot: PokemonSlot, state: GameState) -> int:
	if slot == null or state == null:
		return 0
	if not _is_active(slot, state):
		return 0
	var data := slot.get_card_data()
	if data == null or data.energy_type == "D":
		return 0
	return POISON_BONUS_DAMAGE


func _is_active(slot: PokemonSlot, state: GameState) -> bool:
	for player: PlayerState in state.players:
		if player.active_pokemon == slot:
			return true
	return false


func get_description() -> String:
	return "Poison places 2 more damage counters on non-Darkness Active Pokemon."

