class_name EffectLetterOfEncouragement
extends EffectSearchBasicEnergy


func _init() -> void:
	super(3, 0)


func can_execute(card: CardInstance, state: GameState) -> bool:
	if not state.was_knocked_out_during_opponents_previous_turn(card.owner_index):
		return false
	return super.can_execute(card, state)


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	if not state.was_knocked_out_during_opponents_previous_turn(card.owner_index):
		return false
	return super.can_headless_execute(card, state)
