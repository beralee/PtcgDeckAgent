class_name CompetitiveStrategyEvaluator
extends RefCounted

const JsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const ContractsScript = preload("res://scripts/ai/ptcgdap/platform/CompetitiveStrategyContracts.gd")
const Ed25519Script = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageEd25519.gd")

const BUNDLE_PATH := "res://contracts/ptcgdap/competitive_strategy_evaluator_bundle.json"
const PROFILE_PATH := "res://contracts/ptcgdap/competitive_strategy_evaluator_profile.json"
const VECTORS_PATH := "res://contracts/ptcgdap/competitive_strategy_evaluator_conformance_vectors.json"
const BUNDLE_ID := "ptcgdap-competitive-strategy-evaluator-csp-wp2-v1"
const PROFILE_ID := "ptcgdap-csp-wp2-shadow-profile-v1"
const EXPECTED_BUNDLE_CANONICAL_SHA256 := "E3D4807BD7D902C4701C243D6DD6E9518C95B11B9752C0EA03E75D1E380AAD49"
const EVIDENCE_PREFIX_HEX := "50544347444150004353505F4556414C5541544F525F45564944454E43455F563100"
const RESULT_PREFIX_HEX := "50544347444150004353505F4556414C5541544F525F524553554C545F563100"
const PUBLIC_KEY_HEX := "D75A980182B10AB7D54BFED3C964073A0EE172F3DAA62325AF021A68F707511A"
const FAULT_KEYS := ["invalid_output", "policy_error", "timeout", "engine_rejection", "fallback"]
const FORCED_LOSS_FAULTS := ["invalid_output", "policy_error", "timeout"]
const DIRTY_FAULTS := ["engine_rejection", "fallback"]

var _profile: Dictionary = {}
var _vectors: Dictionary = {}
var _contracts: Variant = null


static func load_default() -> Dictionary:
	var bundle_source := _read_json(BUNDLE_PATH)
	if not bool(bundle_source.get("accepted", false)):
		return _failure("evaluator_bundle_invalid")
	if str(bundle_source.get("canonical_sha256", "")) != EXPECTED_BUNDLE_CANONICAL_SHA256:
		return _failure("evaluator_bundle_trust_anchor_mismatch")
	var bundle: Variant = bundle_source.get("value")
	if not bundle is Dictionary or not _has_exact_keys(bundle, [
		"document_type", "schema_version", "bundle_id", "digest_mode",
		"artifact_set_policy", "artifacts",
	]):
		return _failure("evaluator_bundle_invalid")
	if (
		bundle.get("document_type") != "competitive_strategy_evaluator_bundle_v1"
		or bundle.get("schema_version") != 1
		or bundle.get("bundle_id") != BUNDLE_ID
		or bundle.get("digest_mode") != "canonical_json_v1"
		or bundle.get("artifact_set_policy") != "exact_ids_paths_hashes_no_duplicates"
	):
		return _failure("evaluator_bundle_invalid")
	var artifacts: Variant = bundle.get("artifacts")
	var expected := [
		{"artifact_id": "profile", "path": "contracts/ptcgdap/competitive_strategy_evaluator_profile.json", "resource": PROFILE_PATH},
		{"artifact_id": "vectors", "path": "contracts/ptcgdap/competitive_strategy_evaluator_conformance_vectors.json", "resource": VECTORS_PATH},
	]
	if not artifacts is Array or artifacts.size() != expected.size():
		return _failure("evaluator_bundle_invalid")
	var loaded := {}
	for index: int in expected.size():
		var entry: Variant = artifacts[index]
		var spec: Dictionary = expected[index]
		if not entry is Dictionary or not _has_exact_keys(entry, ["artifact_id", "path", "canonical_sha256"]):
			return _failure("evaluator_bundle_invalid")
		if entry.get("artifact_id") != spec.artifact_id or entry.get("path") != spec.path:
			return _failure("evaluator_bundle_invalid")
		var source := _read_json(str(spec.resource))
		if not bool(source.get("accepted", false)):
			return _failure("evaluator_artifact_invalid")
		if source.get("canonical_sha256") != entry.get("canonical_sha256"):
			return _failure("evaluator_artifact_hash_mismatch")
		loaded[spec.artifact_id] = source.get("value")
	var contract_loaded: Dictionary = ContractsScript.load_default()
	if not bool(contract_loaded.get("accepted", false)):
		return contract_loaded
	var script: GDScript = load("res://scripts/ai/ptcgdap/platform/evaluation/CompetitiveStrategyEvaluator.gd")
	var owner: RefCounted = script.new()
	owner._profile = (loaded.get("profile") as Dictionary).duplicate(true)
	owner._vectors = (loaded.get("vectors") as Dictionary).duplicate(true)
	owner._contracts = contract_loaded.get("owner")
	var profile_check: Dictionary = owner._validate_profile()
	if not bool(profile_check.get("accepted", false)):
		return profile_check
	var vector_check: Dictionary = owner._validate_vectors()
	if not bool(vector_check.get("accepted", false)):
		return vector_check
	return {"accepted": true, "error_code": "", "owner": owner}


func audit_snapshot() -> Dictionary:
	var evaluator: Dictionary = _profile.get("evaluator", {})
	return {
		"profile_id": _profile.get("profile_id"),
		"authority_mode": _profile.get("authority_mode"),
		"evaluator_id": evaluator.get("evaluator_id"),
		"key_id": evaluator.get("key_id"),
		"production_authority": _profile.get("production_authority"),
		"authoritative": false,
		"grants": (_profile.get("grants", []) as Array).duplicate(true),
		"bundle_canonical_sha256": EXPECTED_BUNDLE_CANONICAL_SHA256,
	}


func conformance_vectors() -> Dictionary:
	return _vectors.duplicate(true)


func confidence_interval_audit(wins: int, valid: int) -> Dictionary:
	if wins < 0 or valid < 0 or wins > valid or valid > 100_000:
		return _failure("aggregation_input_invalid")
	return {"accepted": true, "error_code": "", "interval": _confidence_interval(wins, valid), "grants": []}


func verify_record(record: Variant) -> Dictionary:
	if not record is Dictionary or not _has_exact_keys(record, ["evidence", "result"]):
		return _failure("evaluation_record_invalid")
	var evidence: Variant = _deep_copy(record.get("evidence"))
	var result: Variant = _deep_copy(record.get("result"))
	var identity := _validate_evidence_identity(evidence)
	if not bool(identity.get("accepted", false)):
		return identity
	var runtime := _validate_runtime_report(evidence.get("runtime_report"))
	if not bool(runtime.get("accepted", false)):
		return runtime
	var evidence_verification: Variant = evidence.get("evidence_verification")
	if not _valid_verification(evidence_verification):
		return _failure("evidence_verification_invalid")
	var evidence_payload: Dictionary = evidence.duplicate(true)
	evidence_payload.erase("evidence_verification")
	if not _verify_signature(EVIDENCE_PREFIX_HEX, evidence_payload, str(evidence_verification.get("signature", ""))):
		return _failure("evidence_signature_invalid")
	var expected: Dictionary = _derive_result(evidence)
	if not result is Dictionary:
		return _failure("evaluation_result_invalid")
	var expected_payload: Dictionary = expected.duplicate(true)
	expected_payload.erase("verification")
	var actual_payload: Dictionary = result.duplicate(true)
	var actual_verification: Variant = actual_payload.get("verification", "missing")
	actual_payload.erase("verification")
	if _canonical_hash(actual_payload) != _canonical_hash(expected_payload):
		return _failure("evaluation_result_mismatch")
	if bool(expected.get("dirty", false)):
		if actual_verification != null:
			return _failure("dirty_result_must_be_unsigned")
	else:
		if not _valid_verification(actual_verification):
			return _failure("result_verification_invalid")
		if not _verify_signature(RESULT_PREFIX_HEX, actual_payload, str(actual_verification.get("signature", ""))):
			return _failure("result_signature_invalid")
	var contract_result: Dictionary = _contracts.validate_document(result)
	if not bool(contract_result.get("accepted", false)):
		return contract_result
	return {
		"accepted": true,
		"error_code": "",
		"official": not bool(result.get("dirty", false)),
		"dirty": bool(result.get("dirty", false)),
		"match_id": result.get("match_id"),
		"grants": [],
	}


func materialize(records: Variant) -> Dictionary:
	if not records is Array or records.is_empty():
		return _failure("evaluation_inputs_empty")
	if records.size() > 100_000:
		return _failure("evaluation_inputs_too_large")
	var copied: Array = records.duplicate(true)
	var match_ids := {}
	var official_count := 0
	var dirty_count := 0
	for record: Variant in copied:
		var verification := verify_record(record)
		if not bool(verification.get("accepted", false)):
			return verification
		var match_id := str(record.get("result", {}).get("match_id", ""))
		if match_ids.has(match_id):
			return _failure("duplicate_match_id")
		match_ids[match_id] = true
		if bool(record.get("result", {}).get("dirty", false)):
			dirty_count += 1
		else:
			official_count += 1
	copied.sort_custom(_record_less)
	var summary := _aggregate(copied)
	var contract_result: Dictionary = _contracts.validate_document(summary)
	if not bool(contract_result.get("accepted", false)):
		return contract_result
	return {
		"accepted": true,
		"error_code": "",
		"summary": summary,
		"verified_record_count": copied.size(),
		"official_record_count": official_count,
		"dirty_record_count": dirty_count,
		"authoritative": false,
		"grants": [],
	}


func _validate_profile() -> Dictionary:
	if not _has_exact_keys(_profile, [
		"document_type", "schema_version", "profile_id", "authority_mode",
		"production_authority", "grants", "evaluator", "candidate_release",
		"evaluation_profile", "runtime_report_contract", "fault_policy",
		"aggregation_contract", "materializer_build_sha256",
	]):
		return _failure("evaluator_profile_invalid")
	if (
		_profile.get("document_type") != "competitive_strategy_evaluator_profile_v1"
		or _profile.get("schema_version") != 1
		or _profile.get("profile_id") != PROFILE_ID
		or _profile.get("authority_mode") != "shadow_test_only"
		or _profile.get("production_authority") != false
		or _profile.get("grants") != []
	):
		return _failure("evaluator_profile_invalid")
	var evaluator: Variant = _profile.get("evaluator")
	if not evaluator is Dictionary or not _has_exact_keys(evaluator, ["evaluator_id", "key_id", "algorithm", "public_key_hex"]):
		return _failure("evaluator_profile_invalid")
	if (
		evaluator.get("evaluator_id") != "ptcgdap-csp-wp2-shadow-evaluator"
		or evaluator.get("key_id") != "csp-wp2-rfc8032-fixture-key"
		or evaluator.get("algorithm") != "ed25519"
		or evaluator.get("public_key_hex") != PUBLIC_KEY_HEX
	):
		return _failure("evaluator_profile_invalid")
	for document_key: String in ["candidate_release", "evaluation_profile"]:
		var result: Dictionary = _contracts.validate_document(_profile.get(document_key))
		if not bool(result.get("accepted", false)):
			return _failure("evaluator_profile_invalid")
	var evaluation: Dictionary = _profile.get("evaluation_profile", {})
	if (
		evaluation.get("evaluator_id") != evaluator.get("evaluator_id")
		or evaluation.get("seat_policy") != "paired_swap"
		or evaluation.get("seed_policy") != {"capability": "paired_seed_commitment_v1", "disclosure": "commitment_only"}
		or evaluation.get("outcome_policy") != {
			"draws_allowed": true,
			"invalid_output": "verified_loss_and_fault",
			"policy_error": "verified_loss_and_fault",
			"timeout": "verified_loss_and_fault",
			"dirty": "exclude_from_rank_show_separately",
		}
	):
		return _failure("evaluator_profile_invalid")
	if _profile.get("runtime_report_contract") != {
		"source": "official_evaluator_runtime",
		"terminal_required": true,
		"replay_contract_acceptance_required": true,
		"historical_import_allowed": false,
		"client_self_report_allowed": false,
	}:
		return _failure("evaluator_profile_invalid")
	if _profile.get("fault_policy") != {
		"forced_loss_faults": FORCED_LOSS_FAULTS,
		"dirty_exclusion_faults": DIRTY_FAULTS,
		"runtime_dirty_reasons_excluded": true,
		"faults_visible_in_summary": true,
	}:
		return _failure("evaluator_profile_invalid")
	if _profile.get("aggregation_contract") != {
		"version": "win_rate_ci_integer_v1",
		"point_estimate": "wins_divided_by_valid",
		"draw_value": "zero_wins",
		"confidence_interval": "wilson_95_integer_fixed_point",
		"below_minimum_interval": "zero_to_ten_thousand",
	}:
		return _failure("evaluator_profile_invalid")
	if not _is_sha256(_profile.get("materializer_build_sha256")):
		return _failure("evaluator_profile_invalid")
	return _success()


func _validate_vectors() -> Dictionary:
	if not _has_exact_keys(_vectors, [
		"document_type", "schema_version", "profile_id", "records",
		"expected_summary", "rejection_cases", "confidence_interval_cases",
	]):
		return _failure("evaluator_vectors_invalid")
	if (
		_vectors.get("document_type") != "competitive_strategy_evaluator_conformance_vectors_v1"
		or _vectors.get("schema_version") != 1
		or _vectors.get("profile_id") != PROFILE_ID
		or not _vectors.get("records") is Array
		or _vectors.get("records", []).size() != 5
		or not _vectors.get("rejection_cases") is Array
		or not _vectors.get("confidence_interval_cases") is Array
	):
		return _failure("evaluator_vectors_invalid")
	return _success()


func _validate_evidence_identity(evidence: Variant) -> Dictionary:
	if not evidence is Dictionary or not _has_exact_keys(evidence, [
		"document_type", "schema_version", "evaluation_profile_sha256",
		"match_envelope", "replay_manifest", "runtime_report", "evidence_verification",
	]):
		return _failure("evaluation_evidence_invalid")
	if evidence.get("document_type") != "evaluator_evidence_v1" or evidence.get("schema_version") != 1:
		return _failure("evaluation_evidence_invalid")
	var profile: Dictionary = _profile.get("evaluation_profile", {})
	var profile_hash := _canonical_hash(profile)
	if evidence.get("evaluation_profile_sha256") != profile_hash:
		return _failure("evaluation_profile_mismatch")
	var envelope: Variant = evidence.get("match_envelope")
	var replay: Variant = evidence.get("replay_manifest")
	var envelope_result: Dictionary = _contracts.validate_document(envelope)
	if not bool(envelope_result.get("accepted", false)):
		return envelope_result
	var replay_result: Dictionary = _contracts.validate_document(replay)
	if not bool(replay_result.get("accepted", false)):
		return replay_result
	if envelope.get("lane") != "official_evaluation":
		return _failure("match_lane_invalid")
	if (
		envelope.get("evaluator_id") != profile.get("evaluator_id")
		or envelope.get("evaluation_profile_id") != profile.get("profile_id")
		or envelope.get("evaluation_profile_sha256") != profile_hash
		or envelope.get("engine_sha256") != profile.get("engine_sha256")
		or envelope.get("rules_sha256") != profile.get("rules_sha256")
		or envelope.get("card_catalog_sha256") != profile.get("card_catalog_sha256")
		or envelope.get("host_contract_sha256") != profile.get("host_contract_sha256")
	):
		return _failure("match_profile_mismatch")
	if _canonical_hash(envelope.get("participants", [])[0]) != _canonical_hash(_release_participant()):
		return _failure("strategy_release_mismatch")
	if _canonical_hash(envelope.get("participants", [])[1]) != _canonical_hash(profile.get("opponents", [])[0]):
		return _failure("opponent_mismatch")
	if replay.get("match_id") != envelope.get("match_id"):
		return _failure("replay_match_mismatch")
	if replay.get("complete") != true:
		return _failure("replay_incomplete")
	if replay.get("match_envelope_sha256") != _canonical_hash(envelope):
		return _failure("replay_envelope_mismatch")
	return _success()


func _validate_runtime_report(report: Variant) -> Dictionary:
	if not report is Dictionary or not _has_exact_keys(report, [
		"source", "terminal", "reported_outcome", "winner_seat", "turn_count",
		"decision_count", "fault_counts", "runtime_dirty_reasons", "replay_contract_accepted",
	]):
		return _failure("runtime_report_invalid")
	if report.get("source") != "official_evaluator_runtime":
		return _failure("evaluation_source_invalid")
	if report.get("terminal") != true:
		return _failure("evaluation_nonterminal")
	if report.get("replay_contract_accepted") != true:
		return _failure("replay_contract_not_accepted")
	var outcome := str(report.get("reported_outcome", ""))
	var winner: Variant = report.get("winner_seat")
	if not (
		(outcome == "seat_0_win" and winner == 0)
		or (outcome == "seat_1_win" and winner == 1)
		or (outcome == "draw" and winner == null)
	):
		return _failure("result_outcome_invalid")
	if not _is_non_negative_integer(report.get("turn_count")) or not _is_non_negative_integer(report.get("decision_count")):
		return _failure("runtime_report_invalid")
	var faults: Variant = report.get("fault_counts")
	if not faults is Dictionary or not _has_exact_keys(faults, FAULT_KEYS):
		return _failure("fault_counts_invalid")
	for key: String in FAULT_KEYS:
		if not _is_non_negative_integer(faults.get(key)):
			return _failure("fault_counts_invalid")
	var reasons: Variant = report.get("runtime_dirty_reasons")
	if not reasons is Array:
		return _failure("dirty_reasons_invalid")
	var normalized: Array = reasons.duplicate()
	normalized.sort()
	var unique := {}
	for reason: Variant in normalized:
		if typeof(reason) != TYPE_STRING or str(reason).is_empty() or unique.has(reason):
			return _failure("dirty_reasons_invalid")
		unique[reason] = true
	if reasons != normalized:
		return _failure("dirty_reasons_invalid")
	return _success()


func _derive_result(evidence: Dictionary) -> Dictionary:
	var envelope: Dictionary = evidence.get("match_envelope", {})
	var replay: Dictionary = evidence.get("replay_manifest", {})
	var report: Dictionary = evidence.get("runtime_report", {})
	var target_seat := int(envelope.get("seat_assignment", [0])[0])
	var faults: Dictionary = report.get("fault_counts", {}).duplicate(true)
	var outcome: Variant = report.get("reported_outcome")
	var winner: Variant = report.get("winner_seat")
	for key: String in FORCED_LOSS_FAULTS:
		if int(faults.get(key, 0)) > 0:
			winner = 1 - target_seat
			outcome = "seat_0_win" if winner == 0 else "seat_1_win"
			break
	var dirty_reasons: Array = report.get("runtime_dirty_reasons", []).duplicate()
	for key: String in DIRTY_FAULTS:
		if int(faults.get(key, 0)) > 0:
			dirty_reasons.append("fault_%s" % key)
	dirty_reasons.sort()
	var unique_reasons: Array = []
	for reason: Variant in dirty_reasons:
		if not unique_reasons.has(reason):
			unique_reasons.append(reason)
	var dirty := not unique_reasons.is_empty()
	return {
		"document_type": "verified_match_result_v1",
		"schema_version": 1,
		"match_id": envelope.get("match_id"),
		"match_envelope_sha256": _canonical_hash(envelope),
		"trust_lane": "rejected_or_dirty" if dirty else "official_verified",
		"outcome": outcome,
		"winner_seat": winner,
		"turn_count": report.get("turn_count"),
		"decision_count": report.get("decision_count"),
		"fault_counts": faults,
		"dirty": dirty,
		"dirty_reasons": unique_reasons,
		"replay_manifest_sha256": _canonical_hash(replay),
		"evidence_sha256": _canonical_hash(evidence),
		"verification": null,
	}


func _aggregate(records: Array) -> Dictionary:
	var counts := {"wins": 0, "losses": 0, "draws": 0, "valid": 0, "dirty": 0}
	var faults := {}
	for key: String in FAULT_KEYS:
		faults[key] = 0
	var seats := [
		{"seat": 0, "wins": 0, "losses": 0, "draws": 0},
		{"seat": 1, "wins": 0, "losses": 0, "draws": 0},
	]
	var opponent_id := str(_profile.get("evaluation_profile", {}).get("opponents", [])[0].get("baseline_id", ""))
	var matchup := {"opponent_id": opponent_id, "wins": 0, "losses": 0, "draws": 0}
	for record: Dictionary in records:
		var result: Dictionary = record.get("result", {})
		for key: String in FAULT_KEYS:
			faults[key] = int(faults[key]) + int(result.get("fault_counts", {}).get(key, 0))
		if bool(result.get("dirty", false)):
			counts.dirty = int(counts.dirty) + 1
			continue
		counts.valid = int(counts.valid) + 1
		var target_seat := int(record.get("evidence", {}).get("match_envelope", {}).get("seat_assignment", [0])[0])
		var kind := ""
		if result.get("outcome") == "draw":
			kind = "draws"
		elif int(result.get("winner_seat", -1)) == target_seat:
			kind = "wins"
		else:
			kind = "losses"
		counts[kind] = int(counts[kind]) + 1
		seats[target_seat][kind] = int(seats[target_seat][kind]) + 1
		matchup[kind] = int(matchup[kind]) + 1
	var valid := int(counts.valid)
	var rate := int(counts.wins) * 10_000 / valid if valid > 0 else 0
	var release: Dictionary = _profile.get("candidate_release", {})
	var profile: Dictionary = _profile.get("evaluation_profile", {})
	var ids: Array = []
	for record: Dictionary in records:
		ids.append(record.get("result", {}).get("match_id"))
	return {
		"document_type": "evaluation_summary_v1",
		"schema_version": 1,
		"strategy_release": {
			"strategy_id": release.get("strategy_id"),
			"release_version": release.get("release_version"),
			"archive_sha256": release.get("archive_sha256"),
		},
		"evaluation_profile_id": profile.get("profile_id"),
		"evaluation_profile_sha256": _canonical_hash(profile),
		"aggregation_version": "win_rate_ci_integer_v1",
		"input_match_ids": ids,
		"counts": counts,
		"fault_counts": faults,
		"win_rate_basis_points": rate,
		"confidence_interval_basis_points": _confidence_interval(int(counts.wins), valid),
		"seat_breakdown": seats,
		"matchup_breakdown": [matchup],
		"materializer_build_sha256": _profile.get("materializer_build_sha256"),
	}


func _confidence_interval(wins: int, valid: int) -> Dictionary:
	var minimum := int(_profile.get("evaluation_profile", {}).get("aggregation", {}).get("minimum_publish_games", 20))
	if valid < minimum:
		return {"low": 0, "high": 10_000}
	var scale := 10_000
	var z := 19_600
	var z_squared := z * z
	var radicand := z_squared + (4 * wins * (valid - wins) * scale * scale) / valid
	var root := _integer_sqrt(radicand)
	var center := 2 * wins * scale * scale + z_squared
	var spread := z * root
	var denominator := 2 * (valid * scale * scale + z_squared)
	var low_numerator := maxi(0, center - spread)
	var high_numerator := mini(denominator, center + spread)
	return {
		"low": low_numerator * 10_000 / denominator,
		"high": mini(10_000, (high_numerator * 10_000 + denominator - 1) / denominator),
	}


func _release_participant() -> Dictionary:
	var release: Dictionary = _profile.get("candidate_release", {})
	return {
		"participant_kind": "strategy_release",
		"strategy_id": release.get("strategy_id"),
		"release_version": release.get("release_version"),
		"package_id": release.get("package_id"),
		"archive_sha256": release.get("archive_sha256"),
		"manifest_canonical_sha256": release.get("manifest_canonical_sha256"),
		"deck_identity": _deep_copy(release.get("deck_identity")),
		"policy_package_sha256": release.get("policy_package_sha256"),
	}


func _valid_verification(value: Variant) -> bool:
	return (
		value is Dictionary
		and _has_exact_keys(value, ["evaluator_id", "key_id", "signature"])
		and value.get("evaluator_id") == _profile.get("evaluator", {}).get("evaluator_id")
		and value.get("key_id") == _profile.get("evaluator", {}).get("key_id")
		and typeof(value.get("signature")) == TYPE_STRING
		and str(value.get("signature")).length() == 128
	)


func _verify_signature(prefix_hex: String, value: Variant, signature_hex: String) -> bool:
	var canonical: Dictionary = JsonTreeScript.canonicalize_artifact(value)
	if not bool(canonical.get("ok", false)):
		return false
	var message: PackedByteArray = prefix_hex.hex_decode()
	message.append_array(canonical.get("bytes", PackedByteArray()))
	return Ed25519Script.verify(PUBLIC_KEY_HEX.hex_decode(), message, signature_hex.hex_decode())


static func _read_json(path: String) -> Dictionary:
	var source: Dictionary = ContractsScript._read_contract(path)
	if not bool(source.get("ok", false)):
		return _failure("json_invalid")
	var value: Variant = source.get("value")
	if not value is Dictionary:
		return _failure("json_invalid")
	return {
		"accepted": true,
		"error_code": "",
		"value": value,
		"canonical_sha256": _raw_sha256(source.get("canonical_bytes", PackedByteArray())),
	}


static func _canonical_hash(value: Variant) -> String:
	var canonical: Dictionary = JsonTreeScript.canonicalize_artifact(value)
	if not bool(canonical.get("ok", false)):
		return ""
	return _raw_sha256(canonical.get("bytes", PackedByteArray()))


static func _raw_sha256(value: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(value) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


static func _integer_sqrt(value: int) -> int:
	if value <= 0:
		return 0
	var low := 1
	var high := value
	while low <= high:
		var middle := low + (high - low) / 2
		if middle <= value / middle:
			low = middle + 1
		else:
			high = middle - 1
	return high


static func _record_less(left: Variant, right: Variant) -> bool:
	return str(left.get("result", {}).get("match_id", "")) < str(right.get("result", {}).get("match_id", ""))


static func _has_exact_keys(value: Variant, expected: Array) -> bool:
	if not value is Dictionary or value.size() != expected.size():
		return false
	for key: Variant in expected:
		if not value.has(key):
			return false
	return true


static func _is_sha256(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 64:
		return false
	for character: String in str(value):
		if character not in "0123456789ABCDEF":
			return false
	return true


static func _is_non_negative_integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= 0


static func _deep_copy(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value


static func _success() -> Dictionary:
	return {"accepted": true, "error_code": ""}


static func _failure(code: String) -> Dictionary:
	return {"accepted": false, "error_code": code, "authoritative": false, "grants": []}
