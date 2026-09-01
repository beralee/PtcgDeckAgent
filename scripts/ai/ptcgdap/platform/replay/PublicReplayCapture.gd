class_name PtcgDAPPublicReplayCapture
extends RefCounted

const ContractScript = preload("res://scripts/ai/ptcgdap/platform/CompetitiveStrategyContracts.gd")

const SOURCE_AUTHORITY := "ptcgdap_author_public_owner_v1"
const VISIBILITY_PROFILE := "public_at_event_time_v1"
const MARNIE_STRATEGY_ID := "ptcgdap.marnie.18.0.package-local-v1"
const MARNIE_PACKAGE_ID := "ptcgdap.marnie.windows-local"
const MARNIE_DECK_ID := "800018501"
const RULES_BASELINE_ID := "rules-only-575720"
const DEVELOPER_LANE := "developer_local"
const COMMUNITY_LANE := "community_challenge"
const SOURCE_KEYS := [
	"source_authority", "match_id", "turn_number", "phase", "acting_seat", "public_state",
]

var _contract_owner: Variant = null
var _match_envelope: Dictionary = {}
var _match_envelope_sha256 := ""
var _replay_id := ""
var _card_asset_catalog_sha256 := ""
var _event_dictionary_sha256 := ""
var _frames: Array = []
var _previous_frame_sha256: Variant = null
var _last_turn := -1
var _closed := false


static func create(
	contract_owner: Variant,
	match_envelope: Variant,
	replay_id: String,
	card_asset_catalog_sha256: String,
	event_dictionary_sha256: String
) -> Dictionary:
	if contract_owner == null or not contract_owner.has_method("validate_document"):
		return _failure("contract_owner_invalid")
	if not match_envelope is Dictionary:
		return _failure("match_envelope_invalid")
	var envelope_result: Dictionary = contract_owner.validate_document(match_envelope)
	if not bool(envelope_result.get("accepted", false)):
		return envelope_result
	if not is_supported_envelope(match_envelope):
		return _failure("capture_scope_unsupported")
	if replay_id.strip_edges().is_empty() or not _is_sha256(card_asset_catalog_sha256) or not _is_sha256(event_dictionary_sha256):
		return _failure("capture_identity_invalid")
	var capture := new()
	capture._contract_owner = contract_owner
	capture._match_envelope = (match_envelope as Dictionary).duplicate(true)
	capture._match_envelope_sha256 = str(envelope_result.get("canonical_sha256", ""))
	capture._replay_id = replay_id
	capture._card_asset_catalog_sha256 = card_asset_catalog_sha256
	capture._event_dictionary_sha256 = event_dictionary_sha256
	return {"accepted": true, "error_code": "", "capture": capture}


func append_public_source(
	source: Variant,
	event_kind: String,
	decision_trace_sha256: Variant = null
) -> Dictionary:
	if _closed:
		return _failure("capture_closed")
	if not source is Dictionary or not _has_exact_keys(source, SOURCE_KEYS):
		return _failure("public_source_invalid")
	if source.get("source_authority") != SOURCE_AUTHORITY:
		return _failure("public_source_unattested")
	if source.get("match_id") != _match_envelope.get("match_id"):
		return _failure("public_source_match_mismatch")
	if typeof(source.get("turn_number")) != TYPE_INT or int(source.get("turn_number")) < 0:
		return _failure("replay_turn_transition_invalid")
	var turn_number := int(source.get("turn_number"))
	if _last_turn >= 0 and (turn_number < _last_turn or turn_number > _last_turn + 1):
		return _failure("replay_turn_transition_invalid")
	if _frames.is_empty() and event_kind != "match_started":
		return _failure("replay_event_sequence_invalid")
	if not _frames.is_empty() and event_kind == "match_started":
		return _failure("replay_event_sequence_invalid")
	if event_kind == "match_finished":
		return _failure("replay_event_sequence_invalid")
	if event_kind.strip_edges().is_empty():
		return _failure("replay_event_sequence_invalid")
	if decision_trace_sha256 != null and not _is_sha256(decision_trace_sha256):
		return _failure("hash_invalid")
	var frame := _compile_frame(source, event_kind, decision_trace_sha256)
	var validation: Dictionary = _contract_owner.validate_document(frame)
	if not bool(validation.get("accepted", false)):
		return validation
	var frame_sha256 := ContractScript.frame_hash(frame)
	if frame_sha256.is_empty():
		return _failure("replay_chain_invalid")
	_frames.append(frame.duplicate(true))
	_previous_frame_sha256 = frame_sha256
	_last_turn = turn_number
	return {
		"accepted": true,
		"error_code": "",
		"ordinal": _frames.size() - 1,
		"frame_sha256": frame_sha256,
		"authoritative": false,
		"grants": [],
	}


func finish(final_source: Variant, decision_trace_sha256: Variant = null) -> Dictionary:
	if _closed:
		return _failure("capture_closed")
	if _frames.is_empty():
		return _failure("replay_event_sequence_invalid")
	if not final_source is Dictionary or not _has_exact_keys(final_source, SOURCE_KEYS):
		return _failure("public_source_invalid")
	if final_source.get("source_authority") != SOURCE_AUTHORITY:
		return _failure("public_source_unattested")
	if final_source.get("match_id") != _match_envelope.get("match_id"):
		return _failure("public_source_match_mismatch")
	if final_source.get("phase") != "terminal":
		return _failure("replay_event_sequence_invalid")
	if typeof(final_source.get("turn_number")) != TYPE_INT:
		return _failure("replay_turn_transition_invalid")
	var final_turn := int(final_source.get("turn_number"))
	if final_turn < _last_turn or final_turn > _last_turn + 1:
		return _failure("replay_turn_transition_invalid")
	if decision_trace_sha256 != null and not _is_sha256(decision_trace_sha256):
		return _failure("hash_invalid")
	var previous_last_turn := _last_turn
	var final_frame := _compile_frame(final_source, "match_finished", decision_trace_sha256)
	var final_validation: Dictionary = _contract_owner.validate_document(final_frame)
	if not bool(final_validation.get("accepted", false)):
		return final_validation
	var final_hash := ContractScript.frame_hash(final_frame)
	if final_hash.is_empty():
		return _failure("replay_chain_invalid")
	_frames.append(final_frame.duplicate(true))
	_previous_frame_sha256 = final_hash
	_last_turn = final_turn
	var first_hash := ContractScript.frame_hash(_frames[0])
	var manifest := {
		"document_type": "replay_manifest_v1",
		"schema_version": 1,
		"replay_id": _replay_id,
		"match_id": _match_envelope.get("match_id"),
		"match_envelope_sha256": _match_envelope_sha256,
		"visibility_profile": VISIBILITY_PROFILE,
		"frame_count": _frames.size(),
		"first_frame_sha256": first_hash,
		"frame_chain_root_sha256": final_hash,
		"card_asset_catalog_sha256": _card_asset_catalog_sha256,
		"event_dictionary_sha256": _event_dictionary_sha256,
		"complete": true,
	}
	var replay_validation: Dictionary = _contract_owner.validate_replay(manifest, _frames)
	if not bool(replay_validation.get("accepted", false)):
		_frames.pop_back()
		_previous_frame_sha256 = ContractScript.frame_hash(_frames[-1])
		_last_turn = previous_last_turn
		return replay_validation
	_closed = true
	return {
		"accepted": true,
		"error_code": "",
		"artifact": {
			"match_envelope": _match_envelope.duplicate(true),
			"manifest": manifest.duplicate(true),
			"frames": _frames.duplicate(true),
		},
		"audit": audit_snapshot(),
	}


func audit_snapshot() -> Dictionary:
	return {
		"document_type": "public_replay_capture_audit_v1",
		"source_authority": SOURCE_AUTHORITY,
		"match_id": _match_envelope.get("match_id"),
		"replay_id": _replay_id,
		"frame_count": _frames.size(),
		"closed": _closed,
		"authoritative": false,
		"engine_invocations": 0,
		"ticket_invocations": 0,
		"callback_invocations": 0,
		"grants": [],
	}


func _compile_frame(source: Dictionary, event_kind: String, decision_trace_sha256: Variant) -> Dictionary:
	return {
		"document_type": "replay_frame_v1",
		"schema_version": 1,
		"match_id": source.get("match_id"),
		"ordinal": _frames.size(),
		"turn_number": source.get("turn_number"),
		"phase": source.get("phase"),
		"acting_seat": source.get("acting_seat"),
		"event_kind": event_kind,
		"public_state": (source.get("public_state") as Dictionary).duplicate(true) if source.get("public_state") is Dictionary else source.get("public_state"),
		"decision_trace_sha256": decision_trace_sha256,
		"previous_frame_sha256": _previous_frame_sha256,
	}


static func is_supported_envelope(value: Dictionary) -> bool:
	var lane := str(value.get("lane", ""))
	if lane not in [DEVELOPER_LANE, COMMUNITY_LANE] or value.get("replay_visibility_profile") != VISIBILITY_PROFILE:
		return false
	var participants: Variant = value.get("participants")
	if not participants is Array or participants.size() != 2:
		return false
	var strategy_count := 0
	var baseline_count := 0
	for participant: Variant in participants:
		if not participant is Dictionary:
			return false
		if participant.get("participant_kind") == "strategy_release":
			var deck: Variant = participant.get("deck_identity")
			if lane == DEVELOPER_LANE:
				if (
					participant.get("strategy_id") == MARNIE_STRATEGY_ID
					and participant.get("package_id") == MARNIE_PACKAGE_ID
					and deck is Dictionary
					and deck.get("domain") == "godot_local_card_uid_v1"
					and deck.get("deck_id") in [
						MARNIE_DECK_ID,
						"%s@%s" % [MARNIE_PACKAGE_ID, str(participant.get("release_version", ""))],
					]
				):
					strategy_count += 1
			else:
				if (
					deck is Dictionary
					and deck.get("domain") == "godot_local_card_uid_v1"
					and not str(participant.get("strategy_id", "")).is_empty()
					and not str(participant.get("package_id", "")).is_empty()
					and not str(deck.get("deck_id", "")).is_empty()
				):
					strategy_count += 1
		elif participant.get("participant_kind") == "platform_baseline":
			if _supported_rules_baseline_id(str(participant.get("baseline_id", ""))):
				baseline_count += 1
		else:
			return false
	return (
		(strategy_count == 1 and baseline_count == 1)
		or (lane == COMMUNITY_LANE and strategy_count == 2 and baseline_count == 0)
	)


static func _supported_rules_baseline_id(value: String) -> bool:
	if value == RULES_BASELINE_ID:
		return true
	const PREFIX := "rules-only-"
	if not value.begins_with(PREFIX):
		return false
	var suffix := value.trim_prefix(PREFIX)
	return suffix.is_valid_int() and int(suffix) > 0 and str(int(suffix)) == suffix


static func _has_exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key: Variant in keys:
		if not value.has(key):
			return false
	return true


static func _is_sha256(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 64:
		return false
	for index: int in 64:
		if not "0123456789ABCDEF".contains(str(value).substr(index, 1)):
			return false
	return true


static func _failure(code: String) -> Dictionary:
	return {"accepted": false, "error_code": code, "authoritative": false, "grants": []}
