class_name EffectFestivalGrounds
extends BaseEffect

const EFFECT_ID := "357d55b54ded5db071b55ebe165749fc"


func execute_on_play(_card: CardInstance, state: GameState, _targets: Array = []) -> void:
	clear_protected_statuses(state)


static func is_active(state: GameState) -> bool:
	return (
		state != null
		and state.stadium_card != null
		and state.stadium_card.card_data != null
		and state.stadium_card.card_data.effect_id == EFFECT_ID
	)


static func prevents_special_status(slot: PokemonSlot, state: GameState) -> bool:
	return is_active(state) and slot != null and not slot.attached_energy.is_empty()


static func clear_status_if_protected(slot: PokemonSlot, state: GameState) -> void:
	if prevents_special_status(slot, state):
		slot.clear_all_status()


static func clear_protected_statuses(state: GameState) -> void:
	if not is_active(state):
		return
	for player: PlayerState in state.players:
		for slot: PokemonSlot in player.get_all_pokemon():
			clear_status_if_protected(slot, state)


func get_description() -> String:
	return "Pokemon with Energy attached do not have Special Conditions and recover from them."
