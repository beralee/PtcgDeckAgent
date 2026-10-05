extends RefCounted

# A teaching recorder, deliberately not a policy or current-window authority.
const Gateway := preload("res://scripts/ai/v18_cpg/observation/V18CPGObservationGateway.gd")
const Catalog := preload("res://scripts/training/expert/ExpertPlayCatalog.gd")
const MAX_EVENTS := 256
const CONFIDENCE := ["confident", "discuss", "mistake", "bad_question"]
const REASONS := ["prizes", "setup", "resource", "continuity", "information", "disruption", "other"]
var _gateway: RefCounted = Gateway.new()
var _document: Dictionary = {}
var _closed := false


func begin(scenario: Dictionary, state: GameState, attempt_id: String, repeated: bool) -> void:
	var catalog := Catalog.load_catalog()
	_document = {
		"schema_version": 1, "document_type": "ptcg_expert_play_demo_v1",
		"attempt_id": attempt_id, "scenario_id": str(scenario.id), "scenario_revision": int(scenario.revision),
		"family_id": str(scenario.family_id), "split_group": str(scenario.split_group),
		"origin": "authored_open_position", "deck_id": 675701,
		"catalog_sha256": str(catalog.catalog_sha256), "deck_sha256": str(catalog.deck_sha256),
		"created_at": int(Time.get_unix_time_from_system()), "status": "draft",
		"intent_before_play": "unspecified", "initial_public_state": _public(state),
		"events": [], "final_public_state": {}, "feedback": {},
		"exposure": {"repeated_position": repeated, "reference_answer_shown": false, "feedback_after_play": true},
		"qualification": {"bc_eligible": false, "teacher_label_qualified": false,
			"reason": "human_current_window_witness_missing", "evidence_kind": "public_engine_events_with_human_feedback",
			"review_status": "pending", "event_limit_reached": false},
	}
	_closed = false


func set_intent(intent: String) -> void:
	if intent in REASONS and (_document.events as Array).is_empty():
		_document.intent_before_play = intent


func observe_action(action: GameAction, state: GameState) -> void:
	if _closed or _document.is_empty() or action == null:
		return
	if (_document.events as Array).size() >= MAX_EVENTS:
		_document.qualification.event_limit_reached = true
		return
	# Never serialize action.data/description: draw/prize events can contain hidden identities.
	(_document.events as Array).append({
		"ordinal": (_document.events as Array).size(), "event_type": int(action.action_type),
		"actor": int(action.player_index), "turn": int(action.turn_number),
		"checkpoint_after_event": _public(state),
	})


func finish(confidence: String, reason: String, note: String, state: GameState) -> Dictionary:
	if confidence not in CONFIDENCE or (reason != "" and reason not in REASONS) or note.length() > 1000:
		return {"ok": false, "error": "expert_feedback_invalid"}
	if _document.is_empty():
		return {"ok": false, "error": "expert_attempt_missing"}
	_document.feedback = {"confidence": confidence, "reason": reason, "note": preload("res://scripts/training/expert/ExpertFeedbackGuide.gd").normalized_note(note)}
	if state != null:
		_document.final_public_state = _public(state)
	_document.status = "submitted"
	_document["submitted_at"] = int(Time.get_unix_time_from_system())
	_closed = true
	return {"ok": true}


func pause_for_feedback(state: GameState) -> void:
	_document.final_public_state = _public(state)
	_closed = true


func draft_feedback(confidence: String, reason: String, note: String) -> void:
	if _document.is_empty() or str(_document.status) != "draft":
		return
	_document.feedback = {"confidence": confidence if confidence in CONFIDENCE else "", "reason": reason if reason in REASONS else "", "note": note}


func restore_feedback(document: Dictionary) -> bool:
	if str(document.get("document_type", "")) != "ptcg_expert_play_demo_v1" or str(document.get("status", "")) != "draft" or (document.get("final_public_state", {}) as Dictionary).is_empty():
		return false
	# Godot's JSON parser represents all numbers as floats. Schema v1 has only
	# integer numeric fields: restore their exact type, never round bad values.
	var invalid: Array[String] = []
	var restored: Dictionary = _restore_integer_numbers(document, invalid)
	if not invalid.is_empty():
		return false
	_document = restored
	_document.qualification.bc_eligible = false
	_document.qualification.teacher_label_qualified = false
	_closed = true
	return true


func _restore_integer_numbers(value: Variant, invalid: Array[String]) -> Variant:
	if typeof(value) == TYPE_FLOAT:
		if not is_finite(value) or floorf(value) != value or absf(value) >= 9007199254740992.0:
			invalid.append("expert_feedback_integer_invalid")
			return null
		return int(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = _restore_integer_numbers(value[key], invalid)
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_restore_integer_numbers(item, invalid))
		return result
	return value


func document() -> Dictionary:
	return _document.duplicate(true)


func _public(state: GameState) -> Dictionary:
	var snapshot: Dictionary = _gateway.snapshot_public_state(state, 0)
	if state == null:
		return snapshot
	# These public facts distinguish the Fezandipiti and newly-played evolution pairs.
	# Keep them in the teaching schema; this does not silently extend an Actor profile.
	snapshot["public_history"] = {
		"last_knockout_turn_against": state.last_knockout_turn_against.duplicate(),
		"last_knockout_during_opponent_turn_against": state.last_knockout_during_opponent_turn_against.duplicate(),
		"knockout_provenance_tracked_against": state.knockout_provenance_tracked_against.duplicate(),
	}
	for index: int in 2:
		var side: Dictionary = snapshot.own if index == 0 else snapshot.opponent
		var player: PlayerState = state.players[index]
		if player.active_pokemon != null:
			_stamp_slot(side.active, player.active_pokemon)
		for bench_index: int in player.bench.size():
			_stamp_slot(side.bench[bench_index], player.bench[bench_index])
	# The gateway hash predates the teaching-only additions, so do not mislabel it.
	snapshot.erase("public_state_hash")
	return snapshot


func _stamp_slot(public_slot: Dictionary, slot: PokemonSlot) -> void:
	public_slot["turn_played"] = int(slot.turn_played)
	public_slot["turn_evolved"] = int(slot.turn_evolved)
