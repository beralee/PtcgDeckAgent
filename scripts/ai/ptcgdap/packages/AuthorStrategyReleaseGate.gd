class_name AuthorStrategyReleaseGate
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")

const PROFILE_ID := "ptcgdap-author-strategy-release-as-wp6-v1"
const EXPECTED_BUNDLE_SHA256 := "527D725B50946874D62C95B957DB401A5EC6F58A5A2E8653650E89E765E7AE26"
const BUNDLE_PATH := "res://contracts/ptcgdap/author_strategy_release_bundle.json"
const PROFILE_PATH := "res://contracts/ptcgdap/author_strategy_release_profile.json"
const TRUST_STORE_PATH := "res://data/ptcgdap/author_strategy_release_trust_store.json"
const APPROVALS_PATH := "res://data/ptcgdap/author_strategy_release_approvals.json"
const DEVICE_CANARY_APPROVALS_PATH := "res://data/ptcgdap/author_strategy_device_canary_approvals.json"
const PROMPT_CONFORMANCE_APPROVALS_PATH := "res://data/ptcgdap/author_strategy_prompt_conformance_approvals.json"
const DEVICE_PROFILE_PATH := "res://data/ptcgdap/author_strategy_device_acceptance_profile.json"
const OFFICIAL_SOURCE_LOCK_SHA256 := "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_COLD_START_SAMPLES := 1_000
const MAX_DECISION_SAMPLES := 1_000_000
const EXPECTED_ARTIFACTS := {
	"author_strategy_release.schema": ["res://contracts/ptcgdap/author_strategy_release.schema.json", "A13F63F285542B5F069420E1E586D470ADA800FD4828AD1A1065AAFE04D90F8E"],
	"author_strategy_release_profile": [PROFILE_PATH, "ACC805D8919E67F92460AA8FE388547D20C606C0051E5382A59E5CCAFC90E7F5"],
	"author_strategy_release_conformance_vectors": ["res://contracts/ptcgdap/author_strategy_release_conformance_vectors.json", "9F669B1D2D22CD28AF86C54D05B3B003153EC2CE16B98DE06EFABD057F9D49A5"],
	"author_strategy_release_trust_store": [TRUST_STORE_PATH, "C3260FA0FAFE9A393760C5557C631672DF8DB4A7C53E8190F60084034E7E8FDE"],
	"author_strategy_release_approvals": [APPROVALS_PATH, "B879501E6C8E89B89B7728A1D33FCD6D3974741A1C70A8D71555703E90D57C87"],
	"author_strategy_device_canary_approvals": [DEVICE_CANARY_APPROVALS_PATH, "F538431445A2737B2ED24A8B034E1A6CF3C98F3473BF758E6B375724DEE6F7CA"],
	"author_strategy_prompt_conformance_approvals": [PROMPT_CONFORMANCE_APPROVALS_PATH, "7FC1C3579B7A13C43BBEFA902348E949729AA1CAFD38D3B6EF0665741D469EE5"],
	"author_strategy_device_acceptance_profile": [DEVICE_PROFILE_PATH, "A8971FDEC09DE2B22DC131FEC35146A32013E6D7928BFDD46847B567B2B95169"],
}
const REQUIRED_PROMPT_COVERAGE := ["W0", "W1", "W2", "W3", "W4", "W5", "W6", "W7"]

var _contract_ok := false
var _contract_error := "release_contract_invalid"
var _profile: Dictionary = {}
var _trust_store: Dictionary = {}
var _release_approvals: Dictionary = {}
var _device_canary_approvals: Dictionary = {}
var _prompt_conformance_approvals: Dictionary = {}
var _device_profile: Dictionary = {}


func _init() -> void:
	_load_fixed_documents()


func audit_snapshot() -> Dictionary:
	var trust_error_code := _current_error()
	var readiness_error_code := _production_readiness_error(trust_error_code)
	return {
		"profile_id": PROFILE_ID,
		"contract_ok": _contract_ok,
		"production_trust_status": str(_trust_store.get("approval_status", "invalid")),
		"device_profile_status": str(_device_profile.get("approval_status", "invalid")),
		"release_approval_status": str(_release_approvals.get("approval_status", "invalid")),
		"approved_package_count": _release_approvals.get("records", []).size(),
		"device_canary_approval_status": str(_device_canary_approvals.get("approval_status", "invalid")),
		"approved_device_canary_count": _device_canary_approvals.get("records", []).size(),
		"prompt_conformance_approval_status": str(_prompt_conformance_approvals.get("approval_status", "invalid")),
		"approved_prompt_conformance_count": _prompt_conformance_approvals.get("records", []).size(),
		"active_production_key_count": _active_production_keys().size(),
		"production_trust_ready": trust_error_code == "",
		"production_trust_error_code": trust_error_code,
		# This snapshot has no exact installed package identity. Only the
		# package-specific evaluator may ever authorize a final release.
		"production_ready": false,
		"player_start_allowed": false,
		"release_target_platforms": _release_target_platforms(),
		"deferred_platforms": _deferred_platforms(),
		"error_code": readiness_error_code,
	}


func _production_readiness_error(trust_error_code: String) -> String:
	if not trust_error_code.is_empty():
		return trust_error_code
	var has_prompt := false
	if _prompt_conformance_approvals.get("approval_status") == "approved":
		for value: Variant in _prompt_conformance_approvals.get("records", []):
			if value is Dictionary and value.get("status") == "active":
				has_prompt = true
				break
	if not has_prompt:
		return "release_prompt_conformance_unapproved"
	var has_canary := false
	if _device_canary_approvals.get("approval_status") == "approved":
		for value: Variant in _device_canary_approvals.get("records", []):
			if value is Dictionary and value.get("status") == "active":
				has_canary = true
				break
	if not has_canary:
		return "device_canary_not_approved"
	if _device_profile.get("formal_a5_eligible") != true:
		return "release_a5_unapproved"
	if _release_approvals.get("approval_status") != "approved" \
			or _release_approvals.get("records", []).is_empty():
		return "release_package_not_approved"
	# Only evaluate_installed_package() owns exact cross-store/archive authority.
	return "release_package_not_approved"


func required_export_paths() -> Array[String]:
	var result: Array[String] = []
	if not _contract_ok:
		return result
	var raw_paths: Variant = _profile.get("required_export_paths")
	if not raw_paths is Array:
		return result
	var seen := {}
	for value: Variant in raw_paths:
		if typeof(value) != TYPE_STRING:
			return []
		var path := str(value)
		if path.is_empty() or path.begins_with("/") or path.begins_with("res://") or path.contains("\\") or path.contains("//"):
			return []
		for segment: String in path.split("/"):
			if segment.is_empty() or segment == "." or segment == "..":
				return []
		if seen.has(path):
			return []
		seen[path] = true
		result.append(path)
	return result


func trusted_release_keys() -> Array[Dictionary]:
	if not _contract_ok or _trust_store.get("approval_status") != "approved":
		return []
	var result: Array[Dictionary] = []
	for key_value in _active_production_keys():
		result.append((key_value as Dictionary).duplicate(true))
	return result


func _has_approved_prompt_conformance(
	metadata: Dictionary,
	report_sha256: Variant,
	platform: String
) -> bool:
	if _prompt_conformance_approvals.get("approval_status") != "approved" \
			or not _is_sha256(report_sha256):
		return false
	for record_value: Variant in _prompt_conformance_approvals.get("records", []):
		if not record_value is Dictionary:
			continue
		var record: Dictionary = record_value
		var matches: bool = (
			record.get("status") == "active"
			and record.get("platform") == platform
			and record.get("prompt_conformance_report_sha256") == report_sha256
			and record.get("official_source_lock_sha256") == OFFICIAL_SOURCE_LOCK_SHA256
			and record.get("evidence_class") == "official_cabt_w0_w7_package_conformance"
			and record.get("prompt_coverage") == REQUIRED_PROMPT_COVERAGE
		)
		for field: String in ["package_id", "package_version", "archive_sha256", "manifest_sha256", "policy_ir_sha256", "deck_manifest_sha256"]:
			if record.get(field) != metadata.get(field):
				matches = false
		if matches:
			return true
	return false


func evaluate_package(metadata: Variant) -> Dictionary:
	if not metadata is Dictionary or not _exact_boolean(metadata.get("execution_trusted"), true):
		return _result(false, "release_package_not_execution_trusted")
	if metadata.get("signature_scope") != "production_release":
		return _result(false, "release_package_scope_invalid")
	var current := _current_error()
	if current != "":
		return _result(false, current)
	var key_id := str(metadata.get("signature_key_id", ""))
	for key_value in _active_production_keys():
		var key: Dictionary = key_value
		if key.get("key_id") == key_id:
			if _release_approvals.get("approval_status") != "approved":
				return _result(false, "release_package_not_approved")
			for approval_value in _release_approvals.get("records", []):
				if not approval_value is Dictionary:
					continue
				var approval: Dictionary = approval_value
				var matches := true
				for field: String in ["package_id", "package_version", "archive_sha256", "manifest_sha256", "policy_ir_sha256", "deck_manifest_sha256"]:
					if approval.get(field) != metadata.get(field):
						matches = false
				if not matches:
					continue
				if approval.get("prompt_coverage") != REQUIRED_PROMPT_COVERAGE:
					return _result(false, "release_prompt_coverage_incomplete")
				var release_platforms := _release_target_platforms()
				if release_platforms.is_empty():
					return _result(false, "release_prompt_conformance_unapproved")
				for platform: String in release_platforms:
					if not _has_approved_prompt_conformance(
						metadata, approval.get("prompt_conformance_report_sha256"), platform
					):
						return _result(false, "release_prompt_conformance_unapproved")
				return {"accepted": true, "error_code": "", "player_start_allowed": false, "approval": approval.duplicate(true)}
			return _result(false, "release_package_not_approved")
	return _result(false, "release_package_scope_invalid")


func evaluate_device_canary_package(metadata: Variant, platform: String) -> Dictionary:
	if platform != "windows" or platform not in _release_target_platforms():
		return _canary_result(false, "device_canary_platform_invalid")
	if not metadata is Dictionary or not _exact_boolean(metadata.get("execution_trusted"), true):
		return _canary_result(false, "release_package_not_execution_trusted")
	if metadata.get("signature_scope") != "production_release":
		return _canary_result(false, "release_package_scope_invalid")
	var current := _current_error()
	if current != "":
		return _canary_result(false, current)
	var key_id := str(metadata.get("signature_key_id", ""))
	var key_accepted := false
	for key_value in _active_production_keys():
		if (key_value as Dictionary).get("key_id") == key_id:
			key_accepted = true
			break
	if not key_accepted:
		return _canary_result(false, "release_package_scope_invalid")
	if _device_canary_approvals.get("approval_status") != "approved":
		return _canary_result(false, "device_canary_not_approved")
	for approval_value in _device_canary_approvals.get("records", []):
		if not approval_value is Dictionary:
			continue
		var approval: Dictionary = approval_value
		var matches: bool = approval.get("status") == "active" \
			and approval.get("platform") == platform \
			and approval.get("signature_key_id") == key_id
		for field: String in ["package_id", "package_version", "archive_sha256", "manifest_sha256", "policy_ir_sha256", "deck_manifest_sha256"]:
			if approval.get(field) != metadata.get(field):
				matches = false
		if not matches:
			continue
		if approval.get("prompt_coverage") != REQUIRED_PROMPT_COVERAGE:
			return _canary_result(false, "release_prompt_coverage_incomplete")
		if not _has_approved_prompt_conformance(
			metadata, approval.get("prompt_conformance_report_sha256"), platform
		):
			return _canary_result(false, "release_prompt_conformance_unapproved")
		if matches:
			return {
				"accepted": true,
				"error_code": "",
				"player_start_allowed": false,
				"device_canary_allowed": true,
				"approval": approval.duplicate(true),
				"authority_source": "fixed_product_device_canary_approval",
			}
	return _canary_result(false, "device_canary_not_approved")


func evaluate_installed_package(metadata: Variant) -> Dictionary:
	# Derive the player-start candidate only from the exact fixed product
	# approval. Callers cannot inject prompt, device, rollback, or A5 claims.
	var package: Dictionary = evaluate_package(metadata)
	if not bool(package.get("accepted", false)):
		return package
	var approval: Variant = package.get("approval")
	if not approval is Dictionary:
		return _result(false, "release_package_not_approved")
	var required_platforms := _release_target_platforms()
	var reports: Variant = approval.get("device_report_sha256_by_platform")
	if required_platforms.is_empty() or not reports is Dictionary \
		or not _has_exact_platform_keys(reports, required_platforms):
		return _result(false, "release_device_evidence_incomplete")
	var offline := _offline_requirements()
	var candidate := {
		"package_metadata": metadata.duplicate(true),
		"package_execution_trusted": true,
		"package_scope": "production_release",
		"exact_deck_mapping": true,
		"prompt_coverage": REQUIRED_PROMPT_COVERAGE.duplicate(),
		"prompt_conformance_report_sha256": approval.get("prompt_conformance_report_sha256"),
		"offline_full_match_by_platform": offline,
		"rollback_verified": true,
		"a5_evidence_approved": true,
		"device_report_sha256_by_platform": reports.duplicate(true),
		"rollback_report_sha256": approval.get("rollback_report_sha256"),
		"a5_evidence_sha256": approval.get("a5_evidence_sha256"),
	}
	var released: Dictionary = evaluate_release_candidate(candidate)
	if not bool(released.get("accepted", false)):
		return released
	released["approval"] = approval.duplicate(true)
	released["authority_source"] = "fixed_product_release_approval"
	return released


func evaluate_release_candidate(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return _result(false, "release_package_not_execution_trusted")
	var current := _current_error()
	if current != "":
		return _result(false, current)
	if not _exact_boolean(candidate.get("package_execution_trusted"), true):
		return _result(false, "release_package_not_execution_trusted")
	if candidate.get("package_scope") != "production_release":
		return _result(false, "release_package_scope_invalid")
	if not _exact_boolean(candidate.get("exact_deck_mapping"), true):
		return _result(false, "release_package_not_execution_trusted")
	if candidate.get("prompt_coverage") != REQUIRED_PROMPT_COVERAGE:
		return _result(false, "release_prompt_coverage_incomplete")
	var required_platforms := _release_target_platforms()
	var expected_offline := _offline_requirements()
	var offline_by_platform: Variant = candidate.get("offline_full_match_by_platform")
	if required_platforms.is_empty() or not _has_exact_platform_keys(expected_offline, required_platforms) or not offline_by_platform is Dictionary or not _has_exact_platform_keys(offline_by_platform, required_platforms):
		return _result(false, "release_device_evidence_incomplete")
	for platform: String in required_platforms:
		if typeof(offline_by_platform.get(platform)) != TYPE_BOOL or offline_by_platform.get(platform) != expected_offline.get(platform):
			return _result(false, "release_device_evidence_incomplete")
	if not _exact_boolean(candidate.get("rollback_verified"), true):
		return _result(false, "release_rollback_invalid")
	if not _exact_boolean(candidate.get("a5_evidence_approved"), true):
		return _result(false, "release_a5_unapproved")
	var package_metadata: Variant = candidate.get("package_metadata")
	if not package_metadata is Dictionary:
		return _result(false, "release_package_not_execution_trusted")
	var package: Dictionary = evaluate_package(package_metadata)
	if package.get("accepted") != true:
		return _result(false, str(package.get("error_code", "release_package_not_approved")))
	var approval: Variant = package.get("approval")
	if not approval is Dictionary:
		return _result(false, "release_package_not_approved")
	if candidate.get("prompt_conformance_report_sha256") != approval.get("prompt_conformance_report_sha256"):
		return _result(false, "release_prompt_conformance_unapproved")
	var candidate_reports: Variant = candidate.get("device_report_sha256_by_platform")
	var approval_reports: Variant = approval.get("device_report_sha256_by_platform")
	if not candidate_reports is Dictionary or not approval_reports is Dictionary:
		return _result(false, "release_device_evidence_incomplete")
	if not _has_exact_platform_keys(candidate_reports, required_platforms) or not _has_exact_platform_keys(approval_reports, required_platforms):
		return _result(false, "release_device_evidence_incomplete")
	for platform: String in required_platforms:
		if candidate_reports.get(platform) != approval_reports.get(platform):
			return _result(false, "release_device_evidence_incomplete")
	if candidate.get("rollback_report_sha256") != approval.get("rollback_report_sha256"):
		return _result(false, "release_rollback_invalid")
	if candidate.get("a5_evidence_sha256") != approval.get("a5_evidence_sha256"):
		return _result(false, "release_a5_unapproved")
	return {"accepted": true, "error_code": "", "player_start_allowed": true}


func evaluate_device_report(report: Variant) -> Dictionary:
	if _device_profile.get("approval_status") != "approved":
		return _result(false, "device_profile_not_approved")
	if not _exact_boolean(_device_profile.get("formal_a5_eligible"), true):
		return _result(false, "release_a5_unapproved")
	if not report is Dictionary:
		return _result(false, "device_report_invalid")
	var report_keys := [
		"document_type", "schema_version", "profile_id", "platform", "architecture",
		"offline", "runtime", "samples", "measurements", "rollback", "evidence",
	]
	if not _has_exact_keys(report, report_keys):
		return _result(false, "device_report_invalid")
	if report.get("document_type") != "author_strategy_device_report_v1" or report.get("schema_version") != 1:
		return _result(false, "device_report_invalid")
	var platform := str(report.get("platform", ""))
	var expected_architecture := "x86_64" if platform == "windows" else "arm64-v8a" if platform == "android" else ""
	var limits: Variant = _device_profile.get("platforms", {}).get(platform)
	var offline: Variant = report.get("offline")
	var runtime: Variant = report.get("runtime")
	var samples: Variant = report.get("samples")
	var measurements: Variant = report.get("measurements")
	var rollback: Variant = report.get("rollback")
	var evidence: Variant = report.get("evidence")
	if expected_architecture == "" or report.get("architecture") != expected_architecture:
		return _result(false, "device_report_invalid")
	if not limits is Dictionary or not offline is Dictionary or not runtime is Dictionary or not samples is Dictionary or not measurements is Dictionary or not rollback is Dictionary or not evidence is Dictionary:
		return _result(false, "device_report_invalid")
	if not _has_exact_keys(offline, ["network_blocked", "complete_match_finished", "remote_inference_attempts", "dynamic_download_attempts"]):
		return _result(false, "device_report_invalid")
	if not _has_exact_keys(runtime, ["system_python_required", "sidecar_processes", "external_compute_required"]):
		return _result(false, "device_report_invalid")
	if not _has_exact_keys(samples, ["cold_start_msec", "decision_msec"]):
		return _result(false, "device_report_invalid")
	if not _has_exact_keys(measurements, ["cold_start_msec", "catalog_scan_msec", "match_load_msec", "decision_p95_msec", "peak_memory_mib", "package_mib", "thermal_status_max", "battery_drain_percent_per_hour"]):
		return _result(false, "device_report_invalid")
	if not _has_exact_keys(rollback, ["mode_disabled", "user_packages_preserved"]):
		return _result(false, "device_report_invalid")
	var evidence_keys := ["profile_canonical_sha256", "export_manifest_sha256", "network_audit_sha256", "process_audit_sha256", "full_match_audit_sha256", "rollback_report_sha256"]
	if not _has_exact_keys(evidence, evidence_keys):
		return _result(false, "device_report_invalid")
	if report.get("profile_id") != _device_profile.get("profile_id") or evidence.get("profile_canonical_sha256") != canonical_profile_sha256(_device_profile):
		return _result(false, "device_report_profile_mismatch")
	for evidence_key: String in evidence_keys:
		if not _is_sha256(evidence.get(evidence_key)):
			return _result(false, "device_evidence_invalid")
	var cold_start_samples: Variant = samples.get("cold_start_msec")
	var decision_samples: Variant = samples.get("decision_msec")
	if not cold_start_samples is Array or not decision_samples is Array:
		return _result(false, "device_report_invalid")
	if cold_start_samples.size() > MAX_COLD_START_SAMPLES or decision_samples.size() > MAX_DECISION_SAMPLES:
		return _result(false, "device_report_invalid")
	for value: Variant in cold_start_samples:
		if not _exact_nonnegative_integer(value):
			return _result(false, "device_report_invalid")
	for value: Variant in decision_samples:
		if not _exact_nonnegative_integer(value):
			return _result(false, "device_report_invalid")
	var measurement_method: Variant = _device_profile.get("measurement_method")
	if not measurement_method is Dictionary:
		return _result(false, "device_report_invalid")
	var required_cold_starts: Variant = measurement_method.get("cold_start_samples")
	var required_decisions: Variant = measurement_method.get("decision_samples_minimum")
	if not _exact_positive_integer(required_cold_starts) or not _exact_positive_integer(required_decisions):
		return _result(false, "device_report_invalid")
	if cold_start_samples.size() != int(required_cold_starts) or decision_samples.size() < int(required_decisions):
		return _result(false, "device_sample_count_insufficient")
	if measurements.get("cold_start_msec") != _maximum_integer(cold_start_samples) or measurements.get("decision_p95_msec") != _nearest_rank_p95(decision_samples):
		return _result(false, "device_measurement_mismatch")
	if not _exact_boolean(offline.get("network_blocked"), true):
		return _result(false, "device_network_not_blocked")
	if not _exact_boolean(runtime.get("system_python_required"), false) or not _exact_boolean(runtime.get("external_compute_required"), false):
		return _result(false, "device_external_runtime_detected")
	if not runtime.get("sidecar_processes") is Array or not runtime.get("sidecar_processes").is_empty():
		return _result(false, "device_external_runtime_detected")
	var remote_attempts: Variant = offline.get("remote_inference_attempts")
	var download_attempts: Variant = offline.get("dynamic_download_attempts")
	if not _exact_nonnegative_integer(remote_attempts) or not _exact_nonnegative_integer(download_attempts):
		return _result(false, "device_external_runtime_detected")
	if int(remote_attempts) != 0 or int(download_attempts) != 0:
		return _result(false, "device_external_runtime_detected")
	if not _exact_boolean(offline.get("complete_match_finished"), true):
		return _result(false, "device_full_match_incomplete")
	var pairs := [
		["cold_start_msec", "max_cold_start_msec"],
		["catalog_scan_msec", "max_catalog_scan_msec"],
		["match_load_msec", "max_match_load_msec"],
		["decision_p95_msec", "max_decision_p95_msec"],
		["peak_memory_mib", "max_peak_memory_mib"],
		["package_mib", "max_package_mib"],
	]
	if platform == "android":
		pairs.append(["thermal_status_max", "max_thermal_status"])
		pairs.append(["battery_drain_percent_per_hour", "max_battery_drain_percent_per_hour"])
	elif measurements.get("thermal_status_max") != null or measurements.get("battery_drain_percent_per_hour") != null:
		return _result(false, "device_report_invalid")
	for pair: Array in pairs:
		var value: Variant = measurements.get(pair[0])
		var limit: Variant = limits.get(pair[1])
		if not _exact_nonnegative_integer(value) or not _exact_nonnegative_integer(limit):
			return _result(false, "device_report_invalid")
		if int(value) > int(limit):
			return _result(false, "device_resource_limit_exceeded")
	if not _exact_boolean(rollback.get("mode_disabled"), true) or not _exact_boolean(rollback.get("user_packages_preserved"), true):
		return _result(false, "device_rollback_invalid")
	return _result(true, "")


static func canonical_profile_sha256(value: Variant) -> String:
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact(value)
	if not bool(canonical.get("ok", false)):
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(canonical.get("bytes", PackedByteArray()))
	return context.finish().hex_encode().to_upper()


func _load_fixed_documents() -> void:
	var documents := {}
	var canonical := {}
	var all_paths := {"bundle": [BUNDLE_PATH, EXPECTED_BUNDLE_SHA256]}
	for artifact_id in EXPECTED_ARTIFACTS:
		all_paths[artifact_id] = EXPECTED_ARTIFACTS[artifact_id]
	for artifact_id in all_paths:
		var pair: Array = all_paths[artifact_id]
		var parsed := _read_document(str(pair[0]))
		if not bool(parsed.get("ok", false)) or parsed.get("canonical_sha256") != pair[1]:
			return
		documents[artifact_id] = parsed.get("value", {})
		canonical[artifact_id] = parsed.get("canonical_sha256", "")
	var bundle: Dictionary = documents.get("bundle", {})
	if bundle.get("schema_version") != 1 or bundle.get("bundle_id") != PROFILE_ID or bundle.get("profile_id") != PROFILE_ID:
		return
	var artifacts: Variant = bundle.get("artifacts")
	if not artifacts is Array or artifacts.size() != EXPECTED_ARTIFACTS.size():
		return
	var seen := {}
	for entry_value in artifacts:
		if not entry_value is Dictionary:
			return
		var entry: Dictionary = entry_value
		var artifact_id := str(entry.get("id", ""))
		if not EXPECTED_ARTIFACTS.has(artifact_id) or seen.has(artifact_id):
			return
		var pair: Array = EXPECTED_ARTIFACTS[artifact_id]
		if entry.get("path") != str(pair[0]).trim_prefix("res://"):
			return
		if entry.get("canonical_sha256") != pair[1] or canonical.get(artifact_id) != pair[1]:
			return
		seen[artifact_id] = true
	if seen.size() != EXPECTED_ARTIFACTS.size():
		return
	var profile: Dictionary = documents.get("author_strategy_release_profile", {})
	var trust_store: Dictionary = documents.get("author_strategy_release_trust_store", {})
	var release_approvals: Dictionary = documents.get("author_strategy_release_approvals", {})
	var device_canary_approvals: Dictionary = documents.get("author_strategy_device_canary_approvals", {})
	var prompt_conformance_approvals: Dictionary = documents.get("author_strategy_prompt_conformance_approvals", {})
	var device_profile: Dictionary = documents.get("author_strategy_device_acceptance_profile", {})
	if profile.get("profile_id") != PROFILE_ID:
		return
	if profile.get("trust_store", {}).get("path") != TRUST_STORE_PATH.trim_prefix("res://"):
		return
	if profile.get("trust_store", {}).get("caller_overrides") != false:
		return
	if profile.get("device_acceptance", {}).get("profile_path") != DEVICE_PROFILE_PATH.trim_prefix("res://"):
		return
	if profile.get("release_approvals", {}).get("path") != APPROVALS_PATH.trim_prefix("res://") or profile.get("release_approvals", {}).get("caller_overrides") != false:
		return
	if (
		profile.get("device_canary_approvals", {}).get("path") != DEVICE_CANARY_APPROVALS_PATH.trim_prefix("res://")
		or profile.get("device_canary_approvals", {}).get("caller_overrides") != false
		or profile.get("device_canary_approvals", {}).get("activation_arg") != "--ptcgdap-production-device-canary"
		or profile.get("device_canary_approvals", {}).get("ordinary_player_start") != false
	):
		return
	if (
		profile.get("prompt_conformance_approvals", {}).get("path") != PROMPT_CONFORMANCE_APPROVALS_PATH.trim_prefix("res://")
		or profile.get("prompt_conformance_approvals", {}).get("caller_overrides") != false
		or profile.get("prompt_conformance_approvals", {}).get("official_source_lock_sha256") != OFFICIAL_SOURCE_LOCK_SHA256
	):
		return
	if trust_store.get("document_type") != "author_strategy_release_trust_store_v1" or not trust_store.get("keys") is Array:
		return
	if device_profile.get("document_type") != "author_strategy_device_acceptance_profile_v1":
		return
	if release_approvals.get("document_type") != "author_strategy_release_approvals_v1" or not release_approvals.get("records") is Array:
		return
	if device_canary_approvals.get("document_type") != "author_strategy_device_canary_approvals_v1" or not device_canary_approvals.get("records") is Array:
		return
	if prompt_conformance_approvals.get("document_type") != "author_strategy_prompt_conformance_approvals_v1" or not prompt_conformance_approvals.get("records") is Array:
		return
	_profile = profile.duplicate(true)
	_trust_store = trust_store.duplicate(true)
	_release_approvals = release_approvals.duplicate(true)
	_device_canary_approvals = device_canary_approvals.duplicate(true)
	_prompt_conformance_approvals = prompt_conformance_approvals.duplicate(true)
	_device_profile = device_profile.duplicate(true)
	_contract_ok = true
	_contract_error = ""


func _read_document(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false}
	var parsed: Dictionary = CabtJsonTreeScript.canonicalize_artifact_json_bytes(file.get_buffer(file.get_length()))
	if not bool(parsed.get("ok", false)):
		return {"ok": false}
	var value: Variant = JSON.parse_string(str(parsed.get("text", "")))
	value = _coerce_integral_numbers(value)
	if not value is Dictionary:
		return {"ok": false}
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(parsed.get("bytes", PackedByteArray()))
	return {"ok": true, "value": value, "canonical_sha256": context.finish().hex_encode().to_upper()}


func _current_error() -> String:
	if not _contract_ok:
		return _contract_error
	var trust_status := str(_trust_store.get("approval_status", ""))
	if trust_status == "unprovisioned":
		return "release_trust_unprovisioned"
	if trust_status != "approved":
		return "release_trust_revoked"
	if _active_production_keys().is_empty():
		return "release_trust_unprovisioned"
	if _device_profile.get("approval_status") != "approved":
		return "device_profile_not_approved"
	return ""


func _release_target_platforms() -> Array[String]:
	var result: Array[String] = []
	var targets: Variant = _profile.get("supported_targets", [])
	if not targets is Array:
		return result
	for target_value in targets:
		if target_value is Dictionary and target_value.get("platform") is String:
			result.append(str(target_value.get("platform")))
	return result


func _offline_requirements() -> Dictionary:
	var prerequisites: Variant = _profile.get("release_prerequisites")
	var required_platforms := _release_target_platforms()
	if not prerequisites is Dictionary:
		return {}
	var value: Variant = prerequisites.get("offline_full_match_by_platform")
	if not value is Dictionary or not _has_exact_platform_keys(value, required_platforms):
		return {}
	var result := {}
	for platform: String in required_platforms:
		if typeof(value.get(platform)) != TYPE_BOOL:
			return {}
		result[platform] = value.get(platform)
	return result


func _deferred_platforms() -> Array[String]:
	var result: Array[String] = []
	var targets: Variant = _profile.get("deferred_targets", [])
	if not targets is Array:
		return result
	for target_value in targets:
		if target_value is Dictionary and target_value.get("platform") is String:
			result.append(str(target_value.get("platform")))
	return result


static func _has_exact_platform_keys(value: Dictionary, platforms: Array[String]) -> bool:
	if value.size() != platforms.size():
		return false
	for platform: String in platforms:
		if not value.has(platform):
			return false
	return true


static func _has_exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key: Variant in keys:
		if not value.has(key):
			return false
	return true


static func _is_sha256(value: Variant) -> bool:
	if not value is String:
		return false
	var text := str(value)
	if text.length() != 64:
		return false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 65 and code <= 70):
			return false
	return true


static func _maximum_integer(values: Array) -> int:
	var maximum := 0
	for value: Variant in values:
		maximum = maxi(maximum, int(value))
	return maximum


static func _nearest_rank_p95(values: Array) -> int:
	var ordered := values.duplicate()
	ordered.sort()
	var rank := int(floor(float(95 * ordered.size() + 99) / 100.0)) - 1
	return int(ordered[rank])


func _active_production_keys() -> Array:
	var result := []
	for value in _trust_store.get("keys", []):
		if not value is Dictionary:
			continue
		var key: Dictionary = value
		if key.get("algorithm") == "ed25519" and key.get("scope") == "production_release" and _exact_boolean(key.get("execution_trusted"), true) and key.get("status") == "active":
			result.append(key.duplicate(true))
	return result


static func _coerce_integral_numbers(value: Variant) -> Variant:
	if value is float and value == floor(value):
		return int(value)
	if value is Array:
		var array_result := []
		for item in value:
			array_result.append(_coerce_integral_numbers(item))
		return array_result
	if value is Dictionary:
		var dictionary_result := {}
		for key in value:
			dictionary_result[key] = _coerce_integral_numbers(value[key])
		return dictionary_result
	return value


static func _exact_nonnegative_integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= 0 and int(value) <= MAX_SAFE_INTEGER


static func _exact_positive_integer(value: Variant) -> bool:
	return _exact_nonnegative_integer(value) and int(value) > 0


static func _exact_boolean(value: Variant, expected: bool) -> bool:
	return typeof(value) == TYPE_BOOL and bool(value) == expected


static func _result(accepted: bool, error_code: String) -> Dictionary:
	return {"accepted": accepted, "error_code": error_code, "player_start_allowed": false}


static func _canary_result(accepted: bool, error_code: String) -> Dictionary:
	return {
		"accepted": accepted,
		"error_code": error_code,
		"player_start_allowed": false,
		"device_canary_allowed": false,
	}
