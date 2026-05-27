class_name DiscardToHandBlockHelper
extends RefCounted


static func is_discard_to_hand_blocked(
	player_index: int,
	state: GameState,
	source_kind: String,
	processor: EffectProcessor = null
) -> bool:
	if state == null or source_kind not in ["ability", "trainer"]:
		return false
	var active_processor: Variant = processor
	if active_processor == null:
		active_processor = state.shared_turn_flags.get("_draw_effect_processor", null)
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return false
	for source: PokemonSlot in state.players[opponent_index].get_all_pokemon():
		if source == null or source.get_card_data() == null:
			continue
		if _is_ability_disabled(source, state, active_processor):
			continue
		var effect := _get_effect(source, active_processor)
		if effect != null and effect.has_method("blocks_opponent_discard_to_hand"):
			if bool(effect.call("blocks_opponent_discard_to_hand", source, player_index, source_kind, state)):
				return true
	return false


static func filter_recoverable_discard_cards(
	player_index: int,
	state: GameState,
	cards: Array[CardInstance],
	source_kind: String,
	processor: EffectProcessor = null
) -> Array[CardInstance]:
	if is_discard_to_hand_blocked(player_index, state, source_kind, processor):
		return []
	return cards.duplicate()


static func _get_effect(source: PokemonSlot, processor: Variant) -> BaseEffect:
	if source == null or source.get_card_data() == null or processor == null:
		return null
	if not processor.has_method("get_effect"):
		return null
	return processor.get_effect(source.get_card_data().effect_id)


static func _is_ability_disabled(source: PokemonSlot, state: GameState, processor: Variant) -> bool:
	if processor != null and processor.has_method("is_ability_disabled"):
		return processor.is_ability_disabled(source, state)
	if EffectCancelCologne.is_slot_directly_ability_disabled(source, state):
		return true
	return false
