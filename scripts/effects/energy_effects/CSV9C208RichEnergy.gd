class_name CSV9C208RichEnergy
extends BaseEffect

const DRAW_COUNT := 4


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	if card == null or state == null:
		return
	var target_slot: PokemonSlot = _resolve_attached_target(card, targets)
	if target_slot == null:
		return
	_draw_cards_with_log(state, card.owner_index, DRAW_COUNT, card, "energy")


func get_energy_type() -> String:
	return "C"


func get_energy_count() -> int:
	return 1


func _resolve_attached_target(card: CardInstance, targets: Array) -> PokemonSlot:
	if not targets.is_empty() and targets[0] is PokemonSlot and card in (targets[0] as PokemonSlot).attached_energy:
		return targets[0]
	return null


func get_description() -> String:
	return "提供1个无色能量；从手牌附着时抽4张。"
