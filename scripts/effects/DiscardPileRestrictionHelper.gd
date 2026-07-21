class_name DiscardPileRestrictionHelper
extends RefCounted

const NEUTRALIZATION_ZONE_EFFECT_ID := "6697150282b5d32d026ce20a993b4b53"


static func can_move_to_hand_or_deck(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	return card.card_data.effect_id != NEUTRALIZATION_ZONE_EFFECT_ID


static func filter_cards(cards: Array) -> Array:
	var result: Array = []
	for value: Variant in cards:
		if value is CardInstance and can_move_to_hand_or_deck(value):
			result.append(value)
	return result
