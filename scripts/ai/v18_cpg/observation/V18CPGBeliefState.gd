class_name V18CPGBeliefState
extends RefCounted

const ContractsScript = preload("res://scripts/ai/v18_cpg/schema/V18CPGContracts.gd")

var _events: Array[Dictionary] = []
var _known_own_deck_counts: Dictionary = {}
var _possible_prized: Dictionary = {}
var _opponent_revealed_counts: Dictionary = {}
var _last_full_deck_turn: int = -1


func reset() -> void:
	_events.clear()
	_known_own_deck_counts.clear()
	_possible_prized.clear()
	_opponent_revealed_counts.clear()
	_last_full_deck_turn = -1


func apply_event(event: Dictionary) -> void:
	var event_type := str(event.get("type", ""))
	if event_type not in ContractsScript.EVENT_TYPES:
		return
	var safe_event := event.duplicate(true)
	_events.append(safe_event)
	if event_type == "FULL_DECK_VIEW_OPENED":
		_apply_full_deck_view(safe_event)
	elif event_type in ["INTERACTION_STEP_RESOLVED", "PRIZE_TAKEN"]:
		_apply_public_reveals(safe_event)


func snapshot() -> Dictionary:
	var result := {
		"schema_version": ContractsScript.BELIEF_SCHEMA_VERSION,
		"own": {
			"possible_prized": _possible_prized.duplicate(true),
			"last_full_deck_turn": _last_full_deck_turn,
			"known_deck_counts": _known_own_deck_counts.duplicate(true),
			"deck_order_known": false,
		},
		"opponent": {
			"revealed_counts": _opponent_revealed_counts.duplicate(true),
			"hand_contents_known": false,
		},
		"event_count": _events.size(),
	}
	result["belief_hash"] = ContractsScript.stable_hash(result)
	return result


func replay(events: Array[Dictionary]) -> Dictionary:
	reset()
	for event: Dictionary in events:
		apply_event(event)
	return snapshot()


func event_log() -> Array[Dictionary]:
	return _events.duplicate(true)


func _apply_full_deck_view(event: Dictionary) -> void:
	var cards: Variant = event.get("visible_cards", [])
	if not (cards is Array):
		return
	_known_own_deck_counts.clear()
	for raw_card: Variant in cards as Array:
		if not (raw_card is Dictionary):
			continue
		var identity := str((raw_card as Dictionary).get("uid", (raw_card as Dictionary).get("name", "")))
		if identity != "":
			_known_own_deck_counts[identity] = int(_known_own_deck_counts.get(identity, 0)) + 1
	_last_full_deck_turn = int(event.get("turn", -1))
	var expected_counts: Variant = event.get("expected_counts", {})
	if expected_counts is Dictionary:
		for raw_identity: Variant in (expected_counts as Dictionary).keys():
			var identity := str(raw_identity)
			var missing := maxi(0, int((expected_counts as Dictionary).get(raw_identity, 0)) - int(_known_own_deck_counts.get(identity, 0)))
			_possible_prized[identity] = [0, missing]


func _apply_public_reveals(event: Dictionary) -> void:
	var cards: Variant = event.get("opponent_revealed_cards", [])
	if not (cards is Array):
		return
	for raw_card: Variant in cards as Array:
		if not (raw_card is Dictionary):
			continue
		var identity := str((raw_card as Dictionary).get("uid", (raw_card as Dictionary).get("name", "")))
		if identity != "":
			_opponent_revealed_counts[identity] = int(_opponent_revealed_counts.get(identity, 0)) + 1
