## Typed, serializable contract between rule-owned zone mutations and UI projection.
##
## Rule code publishes exact card membership plus the visual boundary at which a
## hidden/public surface may reconcile. UI code observes this contract; it does
## not infer a mutation from hand counts or from a particular card/effect name.
class_name BattleZoneChangeContract
extends RefCounted

const DATA_KEY := "zone_changes"

const ZONE_DECK := "deck"
const ZONE_HAND := "hand"
const ZONE_DISCARD := "discard"
const ZONE_PRIZES := "prizes"

const PROJECTION_IMMEDIATE := "immediate"
const PROJECTION_AFTER_REVEAL := "after_reveal"
const PROJECTION_AFTER_PRESENTATION := "after_presentation"


static func append_to_data(
	data: Dictionary,
	player_index: int,
	source_zone: String,
	destination_zone: String,
	card_instance_ids: Array,
	projection_timing: String
) -> void:
	if (
		player_index < 0
		or source_zone.strip_edges() == ""
		or destination_zone.strip_edges() == ""
		or projection_timing not in [
			PROJECTION_IMMEDIATE,
			PROJECTION_AFTER_REVEAL,
			PROJECTION_AFTER_PRESENTATION,
		]
	):
		return
	var normalized_ids: Array[int] = []
	for raw_id: Variant in card_instance_ids:
		var instance_id := int(raw_id)
		if instance_id >= 0 and instance_id not in normalized_ids:
			normalized_ids.append(instance_id)
	if normalized_ids.is_empty():
		return
	var raw_changes: Variant = data.get(DATA_KEY, [])
	var changes: Array = raw_changes.duplicate(true) if raw_changes is Array else []
	var change := {
		"player_index": player_index,
		"source_zone": source_zone,
		"destination_zone": destination_zone,
		"card_instance_ids": normalized_ids,
		"projection_timing": projection_timing,
	}
	if change not in changes:
		changes.append(change)
	data[DATA_KEY] = changes


static func changes_for_action(action: GameAction) -> Array:
	if action == null:
		return []
	var raw_changes: Variant = action.data.get(DATA_KEY, [])
	if raw_changes is not Array:
		return []
	var changes: Array = []
	for raw_change: Variant in raw_changes:
		if raw_change is Dictionary:
			changes.append((raw_change as Dictionary).duplicate(true))
	return changes


static func action_changes_zone(
	action: GameAction,
	player_index: int,
	source_zone: String,
	destination_zone: String
) -> bool:
	if action == null or action.player_index != player_index:
		return false
	for change: Dictionary in changes_for_action(action):
		if (
			int(change.get("player_index", action.player_index)) == player_index
			and str(change.get("source_zone", "")) == source_zone
			and str(change.get("destination_zone", "")) == destination_zone
		):
			return true
	return (
		str(action.data.get("source_zone", "")) == source_zone
		and str(action.data.get("destination_zone", "")) == destination_zone
	)


static func should_reconcile_hand_immediately(action: GameAction, view_player_index: int) -> bool:
	if action == null or action.player_index != view_player_index:
		return false
	for change: Dictionary in changes_for_action(action):
		if (
			int(change.get("player_index", action.player_index)) == view_player_index
			and str(change.get("projection_timing", "")) == PROJECTION_IMMEDIATE
			and (
				str(change.get("source_zone", "")) == ZONE_HAND
				or str(change.get("destination_zone", "")) == ZONE_HAND
			)
		):
			return true
	# Saved recordings created before the typed contract used PUBLIC_REVEAL plus
	# either destination_zone or public_result_kind for search-to-hand effects.
	return (
		action.action_type == GameAction.ActionType.PUBLIC_REVEAL
		and (
			str(action.data.get("destination_zone", "")) == ZONE_HAND
			or str(action.data.get("public_result_kind", "")) == "search_to_hand"
		)
	)
