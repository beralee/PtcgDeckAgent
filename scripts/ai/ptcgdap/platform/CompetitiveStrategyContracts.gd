class_name CompetitiveStrategyContracts
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")

const CONTRACT_ROOT := "res://contracts/ptcgdap"
const BUNDLE_PATH := CONTRACT_ROOT + "/competitive_strategy_platform_bundle.json"
const BUNDLE_ID := "ptcgdap-competitive-strategy-platform-csp-wp0-v1"
const PROFILE_ID := "competitive_strategy_platform_contract_v1"
const EXPECTED_BUNDLE_CANONICAL_SHA256 := "B642E704B92A8A76E0D15D02C20B8CC006C4AD2FEE90324FEEBD35114DF92262"
const FRAME_HASH_PREFIX_HEX := "50544347444150004353505F5055424C49435F5245504C41595F4652414D455F563100"
const MAX_CONTRACT_BYTES := 2_097_152
const MAX_SAFE_INTEGER := 9_007_199_254_740_991

const ARTIFACTS := [
	{
		"artifact_id": "schema",
		"filename": "competitive_strategy_platform.schema.json",
		"path": "contracts/ptcgdap/competitive_strategy_platform.schema.json",
	},
	{
		"artifact_id": "profile",
		"filename": "competitive_strategy_platform_profile.json",
		"path": "contracts/ptcgdap/competitive_strategy_platform_profile.json",
	},
	{
		"artifact_id": "threat_model",
		"filename": "competitive_strategy_platform_threat_model.json",
		"path": "contracts/ptcgdap/competitive_strategy_platform_threat_model.json",
	},
	{
		"artifact_id": "vectors",
		"filename": "competitive_strategy_platform_conformance_vectors.json",
		"path": "contracts/ptcgdap/competitive_strategy_platform_conformance_vectors.json",
	},
]

const DOCUMENT_KEYS := {
	"strategy_release_ref_v1": [
		"document_type", "schema_version", "strategy_id", "release_version",
		"author_id", "package_id", "archive_sha256", "manifest_canonical_sha256",
		"deck_identity", "policy_package_sha256", "contract_bundle_sha256",
		"catalog_bundle_sha256", "runtime_manifest_sha256", "platforms",
		"signature_key_id", "release_state", "revocation_state",
	],
	"evaluation_profile_v1": [
		"document_type", "schema_version", "profile_id", "profile_version",
		"visibility", "evaluator_id", "evaluator_build_sha256", "engine_sha256",
		"rules_sha256", "card_catalog_sha256", "host_contract_sha256", "opponents",
		"seat_policy", "seed_policy", "games_per_pair", "limits", "outcome_policy",
		"aggregation", "replay_policy",
	],
	"match_envelope_v1": [
		"document_type", "schema_version", "match_id", "lane", "evaluator_id",
		"participants", "engine_sha256", "rules_sha256", "card_catalog_sha256",
		"host_contract_sha256", "runtime_manifest_sha256", "evaluation_profile_id",
		"evaluation_profile_sha256", "seat_assignment", "seed_commitment",
		"replay_visibility_profile", "started_at_utc",
	],
	"replay_frame_v1": [
		"document_type", "schema_version", "match_id", "ordinal", "turn_number",
		"phase", "acting_seat", "event_kind", "public_state",
		"decision_trace_sha256", "previous_frame_sha256",
	],
	"replay_manifest_v1": [
		"document_type", "schema_version", "replay_id", "match_id",
		"match_envelope_sha256", "visibility_profile", "frame_count",
		"first_frame_sha256", "frame_chain_root_sha256", "card_asset_catalog_sha256",
		"event_dictionary_sha256", "complete",
	],
	"verified_match_result_v1": [
		"document_type", "schema_version", "match_id", "match_envelope_sha256",
		"trust_lane", "outcome", "winner_seat", "turn_count", "decision_count",
		"fault_counts", "dirty", "dirty_reasons", "replay_manifest_sha256",
		"evidence_sha256", "verification",
	],
	"evaluation_summary_v1": [
		"document_type", "schema_version", "strategy_release", "evaluation_profile_id",
		"evaluation_profile_sha256", "aggregation_version", "input_match_ids",
		"counts", "fault_counts", "win_rate_basis_points",
		"confidence_interval_basis_points", "seat_breakdown", "matchup_breakdown",
		"materializer_build_sha256",
	],
}

const HASH_FIELDS := [
	"archive_sha256", "manifest_canonical_sha256", "deck_sha256",
	"policy_package_sha256", "contract_bundle_sha256", "catalog_bundle_sha256",
	"runtime_manifest_sha256", "baseline_sha256", "evaluator_build_sha256",
	"engine_sha256", "rules_sha256", "card_catalog_sha256", "host_contract_sha256",
	"evaluation_profile_sha256", "commitment_sha256", "decision_trace_sha256",
	"previous_frame_sha256", "match_envelope_sha256", "first_frame_sha256",
	"frame_chain_root_sha256", "card_asset_catalog_sha256", "event_dictionary_sha256",
	"replay_manifest_sha256", "evidence_sha256", "materializer_build_sha256",
]

const FAULT_KEYS := [
	"invalid_output", "policy_error", "timeout", "engine_rejection", "fallback",
]

var _profile: Dictionary = {}
var _threat_model: Dictionary = {}
var _vectors: Dictionary = {}
var _bundle_canonical_sha256 := ""


static func load_default() -> Dictionary:
	var bundle_source := _read_contract(BUNDLE_PATH)
	if not bool(bundle_source.get("ok", false)):
		return _failure("contract_bundle_invalid")
	if _raw_sha256(bundle_source.get("canonical_bytes", PackedByteArray())) != EXPECTED_BUNDLE_CANONICAL_SHA256:
		return _failure("contract_bundle_trust_anchor_mismatch")
	var bundle: Variant = bundle_source.get("value")
	if not bundle is Dictionary or not _has_exact_keys(bundle, [
		"document_type", "schema_version", "bundle_id", "profile_id", "digest_mode",
		"artifact_set_policy", "artifacts",
	]):
		return _failure("contract_bundle_invalid")
	if (
		bundle.get("document_type") != "competitive_strategy_platform_bundle_v1"
		or bundle.get("schema_version") != 1
		or bundle.get("bundle_id") != BUNDLE_ID
		or bundle.get("profile_id") != PROFILE_ID
		or bundle.get("digest_mode") != "canonical_json_v1"
		or bundle.get("artifact_set_policy") != "exact_ids_paths_hashes_no_duplicates"
	):
		return _failure("contract_bundle_invalid")
	var entries: Variant = bundle.get("artifacts")
	if not entries is Array or entries.size() != ARTIFACTS.size():
		return _failure("contract_bundle_invalid")
	var loaded := {}
	for index: int in ARTIFACTS.size():
		var expected: Dictionary = ARTIFACTS[index]
		var entry: Variant = entries[index]
		if not entry is Dictionary or not _has_exact_keys(entry, ["artifact_id", "path", "canonical_sha256"]):
			return _failure("contract_bundle_invalid")
		if (
			entry.get("artifact_id") != expected.get("artifact_id")
			or entry.get("path") != expected.get("path")
			or not _is_sha256(entry.get("canonical_sha256"))
		):
			return _failure("contract_bundle_invalid")
		var source := _read_contract("%s/%s" % [CONTRACT_ROOT, expected.get("filename")])
		if not bool(source.get("ok", false)):
			return _failure("contract_artifact_invalid")
		if _raw_sha256(source.get("canonical_bytes", PackedByteArray())) != entry.get("canonical_sha256"):
			return _failure("contract_artifact_hash_mismatch")
		loaded[expected.get("artifact_id")] = source.get("value")
	if not _valid_profile(loaded.get("profile")):
		return _failure("contract_profile_invalid")
	if not _valid_threat_model(loaded.get("threat_model")):
		return _failure("threat_model_invalid")
	if not _valid_vectors(loaded.get("vectors")):
		return _failure("vectors_invalid")
	var script: GDScript = load("res://scripts/ai/ptcgdap/platform/CompetitiveStrategyContracts.gd")
	var owner: RefCounted = script.new()
	owner._profile = loaded.get("profile").duplicate(true)
	owner._threat_model = loaded.get("threat_model").duplicate(true)
	owner._vectors = loaded.get("vectors").duplicate(true)
	owner._bundle_canonical_sha256 = EXPECTED_BUNDLE_CANONICAL_SHA256
	return {"accepted": true, "error_code": "", "owner": owner}


func bundle_canonical_sha256() -> String:
	return _bundle_canonical_sha256


func conformance_vectors() -> Dictionary:
	return _vectors.duplicate(true)


func validate_document(document: Variant) -> Dictionary:
	var private_error := _forbidden_key_error(document)
	if not private_error.is_empty():
		return _failure(private_error)
	var value: Variant = _deep_copy(document)
	if not value is Dictionary:
		return _failure("document_invalid")
	var document_type: Variant = value.get("document_type")
	if typeof(document_type) != TYPE_STRING or not DOCUMENT_KEYS.has(document_type):
		return _failure("document_type_unsupported")
	if not _has_exact_keys(value, DOCUMENT_KEYS[document_type]):
		if document_type == "verified_match_result_v1" and not value.has("verification"):
			return _failure("official_verification_required")
		return _failure("unknown_field")
	if not _is_integer(value.get("schema_version")) or int(value.get("schema_version")) != 1:
		return _failure("schema_unsupported")
	var canonical := CabtJsonTreeScript.canonicalize_artifact(
		value,
		{"max_input_bytes": MAX_CONTRACT_BYTES, "max_output_bytes": int(_profile.limits.max_document_bytes)},
	)
	if not bool(canonical.get("ok", false)):
		return _failure("document_invalid")
	var semantic: Dictionary
	match str(document_type):
		"strategy_release_ref_v1": semantic = _validate_strategy_release(value)
		"evaluation_profile_v1": semantic = _validate_evaluation_profile(value)
		"match_envelope_v1": semantic = _validate_match_envelope(value)
		"replay_frame_v1": semantic = _validate_replay_frame(value)
		"replay_manifest_v1": semantic = _validate_replay_manifest(value)
		"verified_match_result_v1": semantic = _validate_verified_result(value)
		"evaluation_summary_v1": semantic = _validate_evaluation_summary(value)
		_: semantic = _failure("document_type_unsupported")
	if not bool(semantic.get("accepted", false)):
		return semantic
	return {
		"accepted": true,
		"error_code": "",
		"status": "accepted",
		"document_type": document_type,
		"canonical_sha256": _raw_sha256(canonical.get("bytes", PackedByteArray())),
		"authoritative": false,
		"grants": [],
	}


func validate_replay(manifest: Variant, frames: Variant) -> Dictionary:
	var private_error := _forbidden_key_error(manifest)
	if not private_error.is_empty():
		return _failure(private_error)
	private_error = _forbidden_key_error(frames)
	if not private_error.is_empty():
		return _failure(private_error)
	var manifest_value: Variant = _deep_copy(manifest)
	var frames_value: Variant = _deep_copy(frames)
	var manifest_result := validate_document(manifest_value)
	if not bool(manifest_result.get("accepted", false)):
		return manifest_result
	if not frames_value is Array or frames_value.is_empty():
		return _failure("replay_chain_invalid")
	if frames_value.size() > int(_profile.limits.max_replay_frames):
		return _failure("replay_too_large")
	if frames_value.size() != int(manifest_value.get("frame_count", -1)):
		return _failure("replay_chain_invalid")
	var expected_previous: Variant = null
	var first_hash := ""
	var last_hash := ""
	for ordinal: int in frames_value.size():
		var frame: Variant = frames_value[ordinal]
		var frame_result := validate_document(frame)
		if not bool(frame_result.get("accepted", false)):
			return frame_result
		if (
			frame.get("match_id") != manifest_value.get("match_id")
			or int(frame.get("ordinal", -1)) != ordinal
			or frame.get("previous_frame_sha256") != expected_previous
		):
			return _failure("replay_chain_invalid")
		var current_hash := frame_hash(frame)
		if current_hash.is_empty():
			return _failure("replay_chain_invalid")
		if ordinal == 0:
			first_hash = current_hash
		last_hash = current_hash
		expected_previous = current_hash
	if (
		manifest_value.get("first_frame_sha256") != first_hash
		or manifest_value.get("frame_chain_root_sha256") != last_hash
		or manifest_value.get("complete") != true
	):
		return _failure("replay_chain_invalid")
	return {
		"accepted": true,
		"error_code": "",
		"status": "accepted",
		"document_type": "replay_validation_v1",
		"replay_id": manifest_value.get("replay_id"),
		"match_id": manifest_value.get("match_id"),
		"frame_count": frames_value.size(),
		"frame_chain_root_sha256": last_hash,
		"authoritative": false,
		"engine_invoked": false,
		"grants": [],
	}


func validate_match_against_profile(envelope: Variant, evaluation_profile: Variant) -> Dictionary:
	var envelope_value: Variant = _deep_copy(envelope)
	var profile_value: Variant = _deep_copy(evaluation_profile)
	var envelope_result := validate_document(envelope_value)
	if not bool(envelope_result.get("accepted", false)):
		return envelope_result
	var profile_result := validate_document(profile_value)
	if not bool(profile_result.get("accepted", false)):
		return profile_result
	if not (
		envelope_value.evaluation_profile_id == profile_value.profile_id
		and envelope_value.evaluator_id == profile_value.evaluator_id
		and envelope_value.engine_sha256 == profile_value.engine_sha256
		and envelope_value.rules_sha256 == profile_value.rules_sha256
		and envelope_value.card_catalog_sha256 == profile_value.card_catalog_sha256
		and envelope_value.host_contract_sha256 == profile_value.host_contract_sha256
		and envelope_value.replay_visibility_profile == profile_value.replay_policy.visibility_profile
	):
		return _failure("evaluation_profile_mismatch")
	return {
		"accepted": true,
		"error_code": "",
		"document_type": "match_profile_binding_v1",
		"status": "accepted",
		"authoritative": false,
		"grants": [],
	}


func run_vector(case: Variant) -> Dictionary:
	if not case is Dictionary or not (
		_has_exact_keys(case, ["id", "operation", "fixture", "expected"])
		or _has_exact_keys(case, ["id", "operation", "fixture", "mutation", "error_code"])
	):
		return _failure("vector_invalid")
	var fixture_id: Variant = case.get("fixture")
	if typeof(fixture_id) != TYPE_STRING or not _vectors.fixtures.has(fixture_id):
		return _failure("vector_invalid")
	var value: Variant = _vectors.fixtures[fixture_id].duplicate(true)
	if case.has("mutation"):
		var mutated := _apply_mutation(value, case.get("mutation"))
		if not bool(mutated.get("accepted", false)):
			return mutated
		value = mutated.get("value")
	var result: Dictionary
	match str(case.get("operation")):
		"validate_document":
			result = validate_document(value)
			if bool(result.get("accepted", false)):
				return {
					"status": "accepted",
					"document_type": result.get("document_type"),
					"authoritative": false,
					"grants": [],
				}
		"validate_replay":
			result = validate_replay(value.get("manifest"), value.get("frames"))
			if bool(result.get("accepted", false)):
				return {
					"status": "accepted",
					"document_type": "replay_validation_v1",
					"frame_count": result.get("frame_count"),
					"authoritative": false,
					"grants": [],
				}
		"validate_match_against_profile":
			result = validate_match_against_profile(value.get("envelope"), value.get("profile"))
			if bool(result.get("accepted", false)):
				result.erase("accepted")
				result.erase("error_code")
				return result
		_:
			return _failure("vector_invalid")
	return result


static func frame_hash(frame: Variant) -> String:
	if not frame is Dictionary or not _forbidden_key_error(frame).is_empty():
		return ""
	var canonical := CabtJsonTreeScript.canonicalize_artifact(
		frame,
		{"max_input_bytes": MAX_CONTRACT_BYTES, "max_output_bytes": MAX_CONTRACT_BYTES},
	)
	if not bool(canonical.get("ok", false)):
		return ""
	var payload: PackedByteArray = FRAME_HASH_PREFIX_HEX.hex_decode()
	payload.append_array(canonical.get("bytes", PackedByteArray()))
	return _raw_sha256(payload)


func _validate_strategy_release(value: Dictionary) -> Dictionary:
	var common := _require_hashes(value)
	if not common.is_empty():
		return _failure(common)
	if not _is_identifier(value.strategy_id) or not _is_version(value.release_version):
		return _failure("version_invalid" if not _is_version(value.release_version) else "identifier_invalid")
	if not _is_identifier(value.author_id) or not _is_identifier(value.package_id):
		return _failure("identifier_invalid")
	if not _valid_deck_identity(value.deck_identity):
		return _failure("deck_identity_invalid")
	if not value.platforms is Array or value.platforms.is_empty() or value.platforms.size() > int(_profile.limits.max_platforms):
		return _failure("release_platform_invalid")
	if _has_duplicates(value.platforms):
		return _failure("release_platform_invalid")
	for platform: Variant in value.platforms:
		if not _profile.allowed_platforms.has(platform):
			return _failure("release_platform_invalid")
	if not _is_identifier(value.signature_key_id):
		return _failure("identifier_invalid")
	if not _profile.release_states.has(value.release_state) or not _profile.revocation_states.has(value.revocation_state):
		return _failure("release_state_invalid")
	return _success()


func _validate_evaluation_profile(value: Dictionary) -> Dictionary:
	var hashes := _require_hashes(value)
	if not hashes.is_empty():
		return _failure(hashes)
	if not _is_identifier(value.profile_id) or not _is_version(value.profile_version) or not _is_identifier(value.evaluator_id):
		return _failure("evaluation_profile_invalid")
	if not _profile.evaluation_visibility.has(value.visibility):
		return _failure("evaluation_profile_invalid")
	if not value.opponents is Array or value.opponents.is_empty() or value.opponents.size() > int(_profile.limits.max_opponents):
		return _failure("evaluation_profile_invalid")
	for opponent: Variant in value.opponents:
		if not _valid_participant(opponent):
			return _failure("match_participants_invalid")
	if value.seat_policy != "paired_swap" or not _has_exact_keys(value.seed_policy, ["capability", "disclosure"]):
		return _failure("evaluation_profile_invalid")
	if not _profile.seed_capabilities.has(value.seed_policy.capability) or not ["public_exact", "commitment_only"].has(value.seed_policy.disclosure):
		return _failure("evaluation_profile_invalid")
	if not _is_positive_integer(value.games_per_pair) or int(value.games_per_pair) > 100_000:
		return _failure("evaluation_profile_invalid")
	if not _has_exact_keys(value.limits, ["match_time_ms", "decision_time_ms", "memory_mib"]):
		return _failure("evaluation_profile_invalid")
	for limit: Variant in value.limits.values():
		if not _is_positive_integer(limit):
			return _failure("evaluation_profile_invalid")
	if not _has_exact_keys(value.outcome_policy, ["draws_allowed", "invalid_output", "policy_error", "timeout", "dirty"]):
		return _failure("evaluation_profile_invalid")
	if typeof(value.outcome_policy.draws_allowed) != TYPE_BOOL or value.outcome_policy.invalid_output != "verified_loss_and_fault" or value.outcome_policy.policy_error != "verified_loss_and_fault" or value.outcome_policy.timeout != "verified_loss_and_fault" or value.outcome_policy.dirty != "exclude_from_rank_show_separately":
		return _failure("evaluation_profile_invalid")
	if not _has_exact_keys(value.aggregation, ["version", "minimum_publish_games", "confidence_level_basis_points"]):
		return _failure("evaluation_profile_invalid")
	if not _is_identifier(value.aggregation.version) or not _is_positive_integer(value.aggregation.minimum_publish_games) or not _is_positive_integer(value.aggregation.confidence_level_basis_points) or int(value.aggregation.confidence_level_basis_points) > 10_000:
		return _failure("evaluation_profile_invalid")
	if not _has_exact_keys(value.replay_policy, ["visibility_profile", "sampling"]) or not _profile.replay_visibility_profiles.has(value.replay_policy.visibility_profile) or not _is_identifier(value.replay_policy.sampling):
		return _failure("evaluation_profile_invalid")
	return _success()


func _validate_match_envelope(value: Dictionary) -> Dictionary:
	var hashes := _require_hashes(value)
	if not hashes.is_empty():
		return _failure(hashes)
	if not _is_identifier(value.match_id) or not _is_identifier(value.evaluator_id) or not _is_identifier(value.evaluation_profile_id):
		return _failure("identifier_invalid")
	if not _profile.match_lanes.has(value.lane):
		return _failure("match_lane_invalid")
	if not value.participants is Array or value.participants.size() != 2:
		return _failure("match_participants_invalid")
	for participant: Variant in value.participants:
		if not _valid_participant(participant):
			return _failure("match_participants_invalid")
	if (
		not value.seat_assignment is Array
		or value.seat_assignment.size() != 2
		or not _is_integer(value.seat_assignment[0])
		or not _is_integer(value.seat_assignment[1])
		or (value.seat_assignment != [0, 1] and value.seat_assignment != [1, 0])
	):
		return _failure("match_participants_invalid")
	if not _has_exact_keys(value.seed_commitment, ["capability", "commitment_sha256", "disclosure"]):
		return _failure("seed_commitment_invalid")
	if not _profile.seed_capabilities.has(value.seed_commitment.capability) or not ["public", "withheld"].has(value.seed_commitment.disclosure):
		return _failure("seed_commitment_invalid")
	if not _profile.replay_visibility_profiles.has(value.replay_visibility_profile):
		return _failure("replay_visibility_invalid")
	if not _is_timestamp(value.started_at_utc):
		return _failure("timestamp_invalid")
	return _success()


func _validate_replay_frame(value: Dictionary) -> Dictionary:
	var hashes := _require_hashes(value)
	if not hashes.is_empty():
		return _failure(hashes)
	if not _is_identifier(value.match_id) or not _is_non_negative_integer(value.ordinal) or not _is_non_negative_integer(value.turn_number):
		return _failure("replay_frame_invalid")
	if not _is_identifier(value.phase) or not _is_identifier(value.event_kind) or not _is_integer(value.acting_seat) or not [-1, 0, 1].has(int(value.acting_seat)):
		return _failure("replay_frame_invalid")
	if not _has_exact_keys(value.public_state, ["zone_counts", "board", "public_cards"]):
		return _failure("replay_frame_invalid")
	if not value.public_state.zone_counts is Array or value.public_state.zone_counts.size() != 2:
		return _failure("replay_frame_invalid")
	var seats := []
	for row: Variant in value.public_state.zone_counts:
		if not row is Dictionary or not _has_exact_keys(row, ["seat", "hand_count", "deck_count", "prize_count"]):
			return _failure("replay_frame_invalid")
		if not _is_integer(row.seat) or not [0, 1].has(int(row.seat)):
			return _failure("replay_frame_invalid")
		seats.append(int(row.seat))
		for key: String in ["hand_count", "deck_count", "prize_count"]:
			if not _is_non_negative_integer(row[key]):
				return _failure("replay_frame_invalid")
	seats.sort()
	if seats != [0, 1]:
		return _failure("replay_frame_invalid")
	if not value.public_state.board is Array or value.public_state.board.size() > int(_profile.limits.max_public_board_entries):
		return _failure("replay_frame_invalid")
	if not value.public_state.public_cards is Array or value.public_state.public_cards.size() > int(_profile.limits.max_public_card_entries):
		return _failure("replay_frame_invalid")
	for entry: Variant in value.public_state.board:
		if not _valid_board_entry(entry):
			return _failure("replay_frame_invalid")
	for entry: Variant in value.public_state.public_cards:
		if not _valid_public_card(entry):
			return _failure("replay_frame_invalid")
	return _success()


func _validate_replay_manifest(value: Dictionary) -> Dictionary:
	var hashes := _require_hashes(value)
	if not hashes.is_empty():
		return _failure(hashes)
	if not _is_identifier(value.replay_id) or not _is_identifier(value.match_id):
		return _failure("replay_manifest_invalid")
	if not _profile.replay_visibility_profiles.has(value.visibility_profile):
		return _failure("replay_visibility_invalid")
	if not _is_positive_integer(value.frame_count):
		return _failure("replay_manifest_invalid")
	if int(value.frame_count) > int(_profile.limits.max_replay_frames):
		return _failure("replay_too_large")
	if typeof(value.complete) != TYPE_BOOL:
		return _failure("replay_manifest_invalid")
	return _success()


func _validate_verified_result(value: Dictionary) -> Dictionary:
	var hashes := _require_hashes(value)
	if not hashes.is_empty():
		return _failure(hashes)
	if not _is_identifier(value.match_id) or not _profile.result_lanes.has(value.trust_lane):
		return _failure("result_lane_invalid")
	if not ["seat_0_win", "seat_1_win", "draw", "aborted"].has(value.outcome):
		return _failure("result_outcome_invalid")
	if (value.outcome == "seat_0_win" and (not _is_integer(value.winner_seat) or int(value.winner_seat) != 0)) or (value.outcome == "seat_1_win" and (not _is_integer(value.winner_seat) or int(value.winner_seat) != 1)) or (["draw", "aborted"].has(value.outcome) and value.winner_seat != null):
		return _failure("result_outcome_invalid")
	if not _is_non_negative_integer(value.turn_count) or not _is_non_negative_integer(value.decision_count) or not _valid_fault_counts(value.fault_counts):
		return _failure("result_counts_invalid")
	if typeof(value.dirty) != TYPE_BOOL or not value.dirty_reasons is Array or bool(value.dirty) != not value.dirty_reasons.is_empty():
		return _failure("result_dirty_invalid")
	if value.dirty_reasons.size() > 64 or _has_duplicates(value.dirty_reasons):
		return _failure("result_dirty_invalid")
	for reason: Variant in value.dirty_reasons:
		if not _is_identifier(reason):
			return _failure("identifier_invalid")
	if value.trust_lane == "official_verified":
		if value.dirty or not _valid_verification(value.verification):
			return _failure("lane_authority_mismatch" if value.dirty else "official_verification_required")
	elif value.verification != null:
		return _failure("lane_authority_mismatch")
	if value.trust_lane == "rejected_or_dirty" and not value.dirty:
		return _failure("lane_authority_mismatch")
	return _success()


func _validate_evaluation_summary(value: Dictionary) -> Dictionary:
	var hashes := _require_hashes(value)
	if not hashes.is_empty():
		return _failure(hashes)
	if not _has_exact_keys(value.strategy_release, ["strategy_id", "release_version", "archive_sha256"]):
		return _failure("summary_release_invalid")
	if not _is_identifier(value.strategy_release.strategy_id) or not _is_version(value.strategy_release.release_version):
		return _failure("summary_release_invalid")
	if not _is_identifier(value.evaluation_profile_id) or not _is_identifier(value.aggregation_version):
		return _failure("identifier_invalid")
	if not value.input_match_ids is Array or value.input_match_ids.is_empty() or value.input_match_ids.size() > 100_000 or _has_duplicates(value.input_match_ids):
		return _failure("summary_inputs_invalid")
	var sorted_ids: Array = value.input_match_ids.duplicate()
	sorted_ids.sort()
	if sorted_ids != value.input_match_ids:
		return _failure("summary_inputs_invalid")
	for match_id: Variant in value.input_match_ids:
		if not _is_identifier(match_id):
			return _failure("summary_inputs_invalid")
	if not _has_exact_keys(value.counts, ["wins", "losses", "draws", "valid", "dirty"]):
		return _failure("summary_counts_invalid")
	for count: Variant in value.counts.values():
		if not _is_non_negative_integer(count):
			return _failure("summary_counts_invalid")
	if int(value.counts.wins) + int(value.counts.losses) + int(value.counts.draws) != int(value.counts.valid) or int(value.counts.valid) + int(value.counts.dirty) != value.input_match_ids.size():
		return _failure("summary_counts_invalid")
	if not _valid_fault_counts(value.fault_counts) or not _is_non_negative_integer(value.win_rate_basis_points) or int(value.win_rate_basis_points) > 10_000:
		return _failure("summary_counts_invalid")
	if not _has_exact_keys(value.confidence_interval_basis_points, ["low", "high"]):
		return _failure("summary_counts_invalid")
	var low: Variant = value.confidence_interval_basis_points.low
	var high: Variant = value.confidence_interval_basis_points.high
	if not _is_non_negative_integer(low) or not _is_non_negative_integer(high) or int(low) > int(value.win_rate_basis_points) or int(value.win_rate_basis_points) > int(high) or int(high) > 10_000:
		return _failure("summary_counts_invalid")
	if not _valid_seat_breakdown(value.seat_breakdown, value.counts) or not value.matchup_breakdown is Array or value.matchup_breakdown.size() > int(_profile.limits.max_opponents):
		return _failure("summary_counts_invalid")
	for row: Variant in value.matchup_breakdown:
		if not row is Dictionary or not _has_exact_keys(row, ["opponent_id", "wins", "losses", "draws"]) or not _is_identifier(row.opponent_id):
			return _failure("summary_counts_invalid")
		for key: String in ["wins", "losses", "draws"]:
			if not _is_non_negative_integer(row[key]):
				return _failure("summary_counts_invalid")
	return _success()


func _valid_participant(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if value.get("participant_kind") == "platform_baseline":
		return (
			_has_exact_keys(value, ["participant_kind", "baseline_id", "baseline_version", "baseline_sha256"])
			and _is_identifier(value.get("baseline_id"))
			and _is_version(value.get("baseline_version"))
			and _require_hashes(value).is_empty()
		)
	if value.get("participant_kind") == "strategy_release":
		return (
			_has_exact_keys(value, [
				"participant_kind", "strategy_id", "release_version", "package_id",
				"archive_sha256", "manifest_canonical_sha256", "deck_identity",
				"policy_package_sha256",
			])
			and _is_identifier(value.get("strategy_id"))
			and _is_version(value.get("release_version"))
			and _is_identifier(value.get("package_id"))
			and _require_hashes(value).is_empty()
			and _valid_deck_identity(value.get("deck_identity"))
		)
	return false


func _valid_deck_identity(value: Variant) -> bool:
	return (
		value is Dictionary
		and _has_exact_keys(value, ["domain", "deck_id", "deck_sha256"])
		and ["official_card_id_v1", "godot_local_card_uid_v1"].has(value.get("domain"))
		and _is_identifier(value.get("deck_id"))
		and _require_hashes(value).is_empty()
	)


func _valid_board_entry(value: Variant) -> bool:
	if not value is Dictionary or not _has_exact_keys(value, ["seat", "zone", "slot", "card_uid", "card_serial", "damage", "status"]):
		return false
	if not _is_integer(value.seat) or not [0, 1].has(int(value.seat)) or not ["active", "bench", "stadium", "discard", "lost_zone"].has(value.zone):
		return false
	if not _is_non_negative_integer(value.slot) or not _is_non_negative_integer(value.damage) or not value.status is Array or value.status.size() > 32:
		return false
	if value.card_uid != null and not _is_identifier(value.card_uid):
		return false
	if value.card_serial != null and not _is_positive_integer(value.card_serial):
		return false
	for status: Variant in value.status:
		if not _is_identifier(status):
			return false
	return true


func _valid_public_card(value: Variant) -> bool:
	return (
		value is Dictionary
		and _has_exact_keys(value, ["seat", "zone", "card_uid", "card_serial"])
		and _is_integer(value.get("seat"))
		and [0, 1].has(int(value.get("seat")))
		and ["active", "bench", "stadium", "discard", "lost_zone", "revealed"].has(value.get("zone"))
		and _is_identifier(value.get("card_uid"))
		and (value.get("card_serial") == null or _is_positive_integer(value.get("card_serial")))
	)


func _valid_verification(value: Variant) -> bool:
	return (
		value is Dictionary
		and _has_exact_keys(value, ["evaluator_id", "key_id", "signature"])
		and _is_identifier(value.get("evaluator_id"))
		and _is_identifier(value.get("key_id"))
		and typeof(value.get("signature")) == TYPE_STRING
		and not str(value.get("signature")).is_empty()
		and str(value.get("signature")).length() <= 1024
	)


func _valid_fault_counts(value: Variant) -> bool:
	if not value is Dictionary or not _has_exact_keys(value, FAULT_KEYS):
		return false
	for count: Variant in value.values():
		if not _is_non_negative_integer(count):
			return false
	return true


func _valid_seat_breakdown(value: Variant, counts: Dictionary) -> bool:
	if not value is Array or value.size() != 2:
		return false
	var seats := []
	var totals := {"wins": 0, "losses": 0, "draws": 0}
	for row: Variant in value:
		if not row is Dictionary or not _has_exact_keys(row, ["seat", "wins", "losses", "draws"]):
			return false
		if not _is_integer(row.seat) or not [0, 1].has(int(row.seat)):
			return false
		seats.append(int(row.seat))
		for key: String in totals:
			if not _is_non_negative_integer(row[key]):
				return false
			totals[key] += int(row[key])
	seats.sort()
	return seats == [0, 1] and totals.wins == int(counts.wins) and totals.losses == int(counts.losses) and totals.draws == int(counts.draws)


func _require_hashes(value: Variant) -> String:
	if not value is Dictionary:
		return "hash_invalid"
	for key: Variant in value:
		var child: Variant = value[key]
		if HASH_FIELDS.has(key) and child != null and not _is_sha256(child):
			return "hash_invalid"
		if child is Dictionary:
			var nested := _require_hashes(child)
			if not nested.is_empty():
				return nested
	return ""


static func _valid_profile(value: Variant) -> bool:
	if not value is Dictionary or not _has_exact_keys(value, [
		"document_type", "schema_version", "profile_id", "hash_domains",
		"allowed_platforms", "release_states", "revocation_states",
		"evaluation_visibility", "match_lanes", "result_lanes", "seed_capabilities",
		"replay_visibility_profiles", "limits", "retention",
	]):
		return false
	if value.document_type != "competitive_strategy_platform_profile_v1" or value.schema_version != 1 or value.profile_id != PROFILE_ID:
		return false
	if not _has_exact_keys(value.hash_domains, ["document", "replay_frame_prefix_utf8_hex"]):
		return false
	if value.hash_domains.document != "canonical_json_v1_sha256" or value.hash_domains.replay_frame_prefix_utf8_hex != FRAME_HASH_PREFIX_HEX:
		return false
	if not _has_exact_keys(value.limits, ["max_document_bytes", "max_replay_frames", "max_public_board_entries", "max_public_card_entries", "max_platforms", "max_opponents"]):
		return false
	for limit: Variant in value.limits.values():
		if not _is_positive_integer(limit):
			return false
	return true


static func _valid_threat_model(value: Variant) -> bool:
	return (
		value is Dictionary
		and _has_exact_keys(value, [
			"document_type", "schema_version", "threat_model_id", "protected_assets",
			"forbidden_public_keys", "trust_boundaries", "required_controls",
			"explicit_non_authorities",
		])
		and value.get("document_type") == "competitive_strategy_platform_threat_model_v1"
		and value.get("schema_version") == 1
		and value.get("threat_model_id") == "csp-wp0-threat-model-v1"
		and value.get("forbidden_public_keys") is Array
		and not value.get("forbidden_public_keys").is_empty()
		and not _has_duplicates(value.get("forbidden_public_keys"))
	)


static func _valid_vectors(value: Variant) -> bool:
	if not value is Dictionary or not _has_exact_keys(value, ["document_type", "schema_version", "profile_id", "fixtures", "success_cases", "rejection_cases"]):
		return false
	if value.document_type != "competitive_strategy_platform_conformance_vectors_v1" or value.schema_version != 1 or value.profile_id != PROFILE_ID:
		return false
	return value.fixtures is Dictionary and value.success_cases is Array and value.success_cases.size() >= 8 and value.rejection_cases is Array and value.rejection_cases.size() >= 16


static func _apply_mutation(value: Variant, mutation: Variant) -> Dictionary:
	if not mutation is Dictionary or not (
		_has_exact_keys(mutation, ["op", "path", "value"])
		or _has_exact_keys(mutation, ["op", "path"])
	):
		return _failure("vector_invalid")
	var path: Variant = mutation.get("path")
	if not path is Array or path.is_empty():
		return _failure("vector_invalid")
	var parent: Variant = value
	for index: int in path.size() - 1:
		var part: Variant = path[index]
		if parent is Dictionary and parent.has(part):
			parent = parent[part]
		elif parent is Array and _is_integer(part) and int(part) >= 0 and int(part) < parent.size():
			parent = parent[int(part)]
		else:
			return _failure("vector_invalid")
	var final: Variant = path[-1]
	match str(mutation.get("op")):
		"set":
			if parent is Dictionary:
				parent[final] = _deep_copy(mutation.get("value"))
			elif parent is Array and _is_integer(final) and int(final) >= 0 and int(final) < parent.size():
				parent[int(final)] = _deep_copy(mutation.get("value"))
			else:
				return _failure("vector_invalid")
		"delete":
			if parent is Dictionary and parent.has(final):
				parent.erase(final)
			elif parent is Array and _is_integer(final) and int(final) >= 0 and int(final) < parent.size():
				parent.remove_at(int(final))
			else:
				return _failure("vector_invalid")
		"append":
			if not parent is Dictionary or not parent.has(final) or not parent[final] is Array:
				return _failure("vector_invalid")
			parent[final].append(_deep_copy(mutation.get("value")))
		"reverse":
			if not parent is Dictionary or not parent.has(final) or not parent[final] is Array:
				return _failure("vector_invalid")
			parent[final].reverse()
		_:
			return _failure("vector_invalid")
	return {"accepted": true, "error_code": "", "value": value}


static func _forbidden_key_error(value: Variant) -> String:
	var forbidden := [
		"hand", "deck", "prizes", "deck_order", "search_begin_input",
		"private_rng_state", "private_replay_snapshot", "instance_id", "object_id",
		"game_state", "game_state_machine", "action_ticket", "callback", "binding",
		"engine_object",
	]
	var pending := [{"exiting": false, "value": value, "depth": 0}]
	var active := []
	var nodes := 0
	while not pending.is_empty():
		var frame: Dictionary = pending.pop_back()
		var current: Variant = frame.get("value")
		if bool(frame.get("exiting", false)):
			_remove_same(active, current)
			continue
		nodes += 1
		if nodes > 200_000 or int(frame.get("depth", 0)) > 128:
			return "document_invalid"
		if current is Dictionary:
			if _contains_same(active, current):
				return "document_invalid"
			active.append(current)
			pending.append({"exiting": true, "value": current, "depth": frame.get("depth")})
			for key: Variant in current:
				if typeof(key) != TYPE_STRING:
					return "document_invalid"
				if forbidden.has(str(key).to_lower()):
					return "private_field_forbidden"
				pending.append({"exiting": false, "value": current[key], "depth": int(frame.get("depth")) + 1})
		elif current is Array:
			if _contains_same(active, current):
				return "document_invalid"
			active.append(current)
			pending.append({"exiting": true, "value": current, "depth": frame.get("depth")})
			for child: Variant in current:
				pending.append({"exiting": false, "value": child, "depth": int(frame.get("depth")) + 1})
	return ""


static func _contains_same(values: Array, target: Variant) -> bool:
	for value: Variant in values:
		if is_same(value, target):
			return true
	return false


static func _remove_same(values: Array, target: Variant) -> void:
	for index: int in values.size():
		if is_same(values[index], target):
			values.remove_at(index)
			return


static func _read_contract(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false}
	var length := file.get_length()
	if length < 1 or length > MAX_CONTRACT_BYTES:
		return {"ok": false}
	var source := file.get_buffer(length)
	var canonical := CabtJsonTreeScript.canonicalize_artifact_json_bytes(
		source,
		{"max_input_bytes": MAX_CONTRACT_BYTES, "max_output_bytes": MAX_CONTRACT_BYTES},
	)
	if not bool(canonical.get("ok", false)):
		return {"ok": false}
	var parser := JSON.new()
	if parser.parse(source.get_string_from_utf8()) != OK:
		return {"ok": false}
	var state := {"ok": true}
	var restored: Variant = _restore_integer_tokens(parser.data, state)
	if not bool(state.get("ok", false)) or not restored is Dictionary:
		return {"ok": false}
	return {
		"ok": true,
		"value": restored,
		"canonical_bytes": canonical.get("bytes", PackedByteArray()),
	}


static func _restore_integer_tokens(value: Variant, state: Dictionary) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var number := float(value)
			if not is_finite(number) or number != floorf(number) or number < -float(MAX_SAFE_INTEGER) or number > float(MAX_SAFE_INTEGER):
				state["ok"] = false
				return null
			return int(number)
		TYPE_ARRAY:
			var array := []
			for child: Variant in value:
				array.append(_restore_integer_tokens(child, state))
				if not bool(state.get("ok", false)):
					return null
			return array
		TYPE_DICTIONARY:
			var object := {}
			for key: Variant in value:
				if typeof(key) != TYPE_STRING:
					state["ok"] = false
					return null
				object[key] = _restore_integer_tokens(value[key], state)
				if not bool(state.get("ok", false)):
					return null
			return object
		_:
			return value


static func _raw_sha256(source: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(source) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


static func _is_sha256(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 64:
		return false
	for index: int in 64:
		if not "0123456789ABCDEF".contains(str(value).substr(index, 1)):
			return false
	return true


static func _is_identifier(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var text := str(value)
	if text.is_empty() or text.length() > 128 or text != text.strip_edges():
		return false
	for index: int in text.length():
		if text.unicode_at(index) < 0x20:
			return false
	return true


static func _is_version(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var parts := str(value).split(".")
	if parts.size() != 3:
		return false
	for part: String in parts:
		if part.is_empty() or not part.is_valid_int() or int(part) < 0:
			return false
	return true


static func _is_timestamp(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var text := str(value)
	if not (text.length() == 20 and text.substr(4, 1) == "-" and text.substr(7, 1) == "-" and text.substr(10, 1) == "T" and text.substr(13, 1) == ":" and text.substr(16, 1) == ":" and text.ends_with("Z")):
		return false
	var digits := text.substr(0, 4) + text.substr(5, 2) + text.substr(8, 2) + text.substr(11, 2) + text.substr(14, 2) + text.substr(17, 2)
	for index: int in digits.length():
		if digits.unicode_at(index) < 0x30 or digits.unicode_at(index) > 0x39:
			return false
	return true


static func _is_integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= -MAX_SAFE_INTEGER and int(value) <= MAX_SAFE_INTEGER


static func _is_positive_integer(value: Variant) -> bool:
	return _is_integer(value) and int(value) > 0


static func _is_non_negative_integer(value: Variant) -> bool:
	return _is_integer(value) and int(value) >= 0


static func _has_exact_keys(value: Variant, expected: Array) -> bool:
	if not value is Dictionary or value.size() != expected.size():
		return false
	for key: Variant in value:
		if typeof(key) != TYPE_STRING or not expected.has(key):
			return false
	return true


static func _has_duplicates(values: Variant) -> bool:
	if not values is Array:
		return true
	var seen := {}
	for value: Variant in values:
		var signature := JSON.stringify(value)
		if seen.has(signature):
			return true
		seen[signature] = true
	return false


static func _deep_copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value


static func _success() -> Dictionary:
	return {"accepted": true, "error_code": ""}


static func _failure(code: String) -> Dictionary:
	return {"accepted": false, "error_code": code}
