class_name BattleVisualPrivacyPolicy
extends RefCounted

const VISIBILITY_FACE := "face"
const VISIBILITY_BACK := "back"
const VISIBILITY_COUNT := "count"


static func resolve_visibility(
	card_snapshot: Dictionary,
	source_zone: String,
	target_zone: String,
	action: GameAction,
	view_player: int
) -> String:
	var card_id := int(card_snapshot.get("instance_id", -1))
	if _is_publicly_revealed(action, card_id):
		return VISIBILITY_FACE
	var owner_index := int(card_snapshot.get("owner_index", -1))
	if _is_public_zone(target_zone):
		return VISIBILITY_FACE
	if target_zone == "stadium":
		return VISIBILITY_FACE
	if _is_hand_zone(target_zone):
		return VISIBILITY_FACE if owner_index == view_player else VISIBILITY_BACK
	if _is_hand_zone(source_zone) and _is_public_zone(target_zone):
		return VISIBILITY_FACE
	if _is_hidden_zone(target_zone) or _is_hidden_zone(source_zone):
		return VISIBILITY_FACE if owner_index == view_player and _is_hand_zone(target_zone) else VISIBILITY_BACK
	return VISIBILITY_FACE if bool(card_snapshot.get("face_up", false)) else VISIBILITY_BACK


static func sanitize_cards(card_snapshots: Array[Dictionary], visibility: String) -> Dictionary:
	if visibility != VISIBILITY_FACE:
		return {"cards": [], "card_names": []}
	var cards: Array[CardInstance] = []
	var names: Array[String] = []
	for card_snapshot: Dictionary in card_snapshots:
		var card: CardInstance = card_snapshot.get("card", null) as CardInstance
		if card != null:
			cards.append(card)
		names.append(str(card_snapshot.get("card_name", "")))
	return {"cards": cards, "card_names": names}


static func _is_publicly_revealed(action: GameAction, card_id: int) -> bool:
	if action == null or action.action_type != GameAction.ActionType.PUBLIC_REVEAL:
		return false
	var ids_variant: Variant = action.data.get("card_instance_ids", [])
	if not ids_variant is Array:
		return false
	for value: Variant in ids_variant as Array:
		if int(value) == card_id:
			return true
	return false


static func _is_hand_zone(zone: String) -> bool:
	return zone.ends_with(".hand")


static func _is_hidden_zone(zone: String) -> bool:
	return zone.ends_with(".deck") or zone.contains(".prize.") or zone.ends_with(".hand")


static func _is_public_zone(zone: String) -> bool:
	return (
		zone.ends_with(".discard")
		or zone.ends_with(".lost")
		or zone.ends_with(".stack")
		or zone.ends_with(".energy")
		or zone.ends_with(".tool")
		or zone == "stadium"
	)
