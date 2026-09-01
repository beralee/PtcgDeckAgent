class_name TestAuthorStrategyReleaseGate
extends TestBase

const ReleaseGateScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyReleaseGate.gd")
const PackageLoaderScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd")
const DeviceCanaryGateScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDeviceCanaryGate.gd")


func test_fixed_release_documents_approve_product_trust_but_keep_player_release_closed() -> String:
	var gate := ReleaseGateScript.new()
	var audit: Dictionary = gate.audit_snapshot()
	return run_checks([
		assert_true(bool(audit.get("contract_ok", false)), str(audit)),
		assert_eq(audit.get("production_trust_status"), "approved"),
		assert_eq(audit.get("device_profile_status"), "approved"),
		assert_eq(audit.get("release_approval_status"), "unprovisioned"),
		assert_eq(audit.get("approved_package_count"), 0),
		assert_eq(audit.get("device_canary_approval_status"), "unprovisioned"),
		assert_eq(audit.get("approved_device_canary_count"), 0),
		assert_eq(audit.get("prompt_conformance_approval_status"), "unprovisioned"),
		assert_eq(audit.get("approved_prompt_conformance_count"), 0),
		assert_eq(audit.get("active_production_key_count"), 1),
		assert_true(bool(audit.get("production_trust_ready", false))),
		assert_false(bool(audit.get("production_ready", true))),
		assert_false(bool(audit.get("player_start_allowed", true))),
		assert_eq(audit.get("production_trust_error_code"), ""),
		assert_eq(audit.get("error_code"), "release_prompt_conformance_unapproved"),
		assert_eq(audit.get("release_target_platforms"), ["windows"]),
		assert_eq(audit.get("deferred_platforms"), ["android"]),
	])


func test_runtime_export_inventory_uses_release_profile_local_uid_owner_chain() -> String:
	var gate := ReleaseGateScript.new()
	var paths: Array = gate.required_export_paths()
	return run_checks([
		assert_eq(paths.size(), 23),
		assert_true(paths.has("data/ptcgdap/author_strategy_device_canary_approvals.json")),
		assert_true(paths.has("data/ptcgdap/author_strategy_prompt_conformance_approvals.json")),
		assert_true(paths.has("scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDeviceCanaryGate.gd")),
		assert_true(paths.has("scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsExecutionGate.gd")),
		assert_true(paths.has("contracts/ptcgdap/local_uid_public_context_bundle.json")),
		assert_true(paths.has("scripts/ai/ptcgdap/public/PublicDeckAdapter.gd")),
		assert_true(paths.has("scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorMatchHost.gd")),
		assert_true(paths.has("scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorLiveSeam.gd")),
	])


func test_builtin_weighted_candidate_stays_test_fixture_only() -> String:
	var loader := PackageLoaderScript.new()
	var contract: Dictionary = loader.contract_report()
	var result: Dictionary = loader.inspect_match_bytes(
		_read("res://data/ptcgdap/author_strategy_packages/ptcgdap-author-strategy-release-candidate.ptcgai")
	)
	return run_checks([
		assert_true(bool(contract.get("ok", false)), str(contract)),
		assert_eq(contract.get("production_trust_status"), "approved"),
		assert_eq(contract.get("active_production_key_count"), 1),
		assert_true(bool(result.get("ok", false)), str(result)),
		assert_eq(result.get("metadata", {}).get("signature_status"), "test_fixture_trusted"),
		assert_eq(result.get("metadata", {}).get("execution_trusted"), false),
		assert_true(result.get("payloads", {}).has("policy/weights.bin")),
	])


func test_product_signed_golden_is_trusted_but_not_release_approved() -> String:
	var loader := PackageLoaderScript.new()
	var inspected: Dictionary = loader.inspect_match_bytes(
		_read("res://artifacts/ptcgdap/as_wp6_product_signing/ptcgdap-marnie-windows-local-0.1.0.ptcgai")
	)
	var metadata: Dictionary = inspected.get("metadata", {})
	var gate := ReleaseGateScript.new()
	var decision: Dictionary = gate.evaluate_package(metadata)
	return run_checks([
		assert_true(bool(inspected.get("ok", false)), str(inspected)),
		assert_eq(metadata.get("archive_sha256"), "AA65C8B46D2CEB0658EC18BB966F4DFECDB932750EDA3E65CD0B60208A08A0FD"),
		assert_eq(metadata.get("signature_status"), "production_trusted"),
		assert_eq(metadata.get("signature_key_id"), "ptcgdap.product.release.ed25519.v1"),
		assert_eq(metadata.get("signature_scope"), "production_release"),
		assert_true(bool(metadata.get("execution_trusted", false))),
		assert_false(bool(decision.get("accepted", true))),
		assert_eq(decision.get("error_code"), "release_package_not_approved"),
		assert_false(bool(decision.get("player_start_allowed", true))),
	])


func test_test_fixture_cannot_be_promoted_by_release_gate() -> String:
	var gate := ReleaseGateScript.new()
	var decision: Dictionary = gate.evaluate_package({
		"signature_status": "test_fixture_trusted",
		"signature_key_id": "ptcgdap-as-wp1-test-fixture-ed25519-v1",
		"signature_scope": "test_fixture_only",
		"execution_trusted": false,
	})
	var canary: Dictionary = gate.evaluate_device_canary_package({
		"signature_status": "test_fixture_trusted",
		"signature_key_id": "ptcgdap-as-wp1-test-fixture-ed25519-v1",
		"signature_scope": "test_fixture_only",
		"execution_trusted": false,
	}, "windows")
	var activation := DeviceCanaryGateScript.activation_state(PackedStringArray([
		"--ptcgdap-production-device-canary",
		"--ptcgdap-development-ui-match",
	]))
	return run_checks([
		assert_false(bool(decision.get("accepted", true))),
		assert_eq(decision.get("error_code"), "release_package_not_execution_trusted"),
		assert_false(bool(decision.get("player_start_allowed", true))),
		assert_false(bool(canary.get("accepted", true))),
		assert_eq(canary.get("error_code"), "release_package_not_execution_trusted"),
		assert_false(bool(canary.get("device_canary_allowed", true))),
		assert_false(bool(activation.get("active", true))),
		assert_eq(activation.get("error_code"), "device_canary_activation_invalid"),
	])


func test_proposed_device_profile_cannot_emit_formal_acceptance() -> String:
	var gate := ReleaseGateScript.new()
	gate._device_profile = _approved_device_profile()
	gate._device_profile["approval_status"] = "proposed"
	gate._device_profile["formal_a5_eligible"] = false
	var report := {
		"document_type": "author_strategy_device_report_v1",
		"schema_version": 1,
		"platform": "windows",
		"architecture": "x86_64",
	}
	var decision: Dictionary = gate.evaluate_device_report(report)
	return run_checks([
		assert_false(bool(decision.get("accepted", true))),
		assert_eq(decision.get("error_code"), "device_profile_not_approved"),
	])


func test_approved_non_a5_device_profile_cannot_emit_formal_acceptance() -> String:
	var gate := ReleaseGateScript.new()
	var report := {
		"document_type": "author_strategy_device_report_v1",
		"schema_version": 1,
		"platform": "windows",
		"architecture": "x86_64",
	}
	var decision: Dictionary = gate.evaluate_device_report(report)
	return run_checks([
		assert_false(bool(decision.get("accepted", true))),
		assert_eq(decision.get("error_code"), "release_a5_unapproved"),
	])


func test_player_release_requires_exact_approved_evidence_hashes() -> String:
	var gate := ReleaseGateScript.new()
	gate._trust_store = {
		"approval_status": "approved",
		"keys": [{
			"key_id": "product.release.test",
			"algorithm": "ed25519",
			"scope": "production_release",
			"execution_trusted": true,
			"status": "active",
		}],
	}
	gate._device_profile = {"approval_status": "approved", "formal_a5_eligible": true}
	var identity := {
		"package_id": "author.strategy",
		"package_version": "1.0.0",
		"archive_sha256": "A".repeat(64),
		"manifest_sha256": "B".repeat(64),
		"policy_ir_sha256": "C".repeat(64),
		"deck_manifest_sha256": "D".repeat(64),
	}
	var prompt_report_sha256 := "F".repeat(64)
	gate._prompt_conformance_approvals = {
		"approval_status": "approved",
		"records": [{
			"package_id": identity["package_id"],
			"package_version": identity["package_version"],
			"archive_sha256": identity["archive_sha256"],
			"manifest_sha256": identity["manifest_sha256"],
			"policy_ir_sha256": identity["policy_ir_sha256"],
			"deck_manifest_sha256": identity["deck_manifest_sha256"],
			"platform": "windows",
			"prompt_conformance_report_sha256": prompt_report_sha256,
			"official_source_lock_sha256": "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205",
			"evidence_class": "official_cabt_w0_w7_package_conformance",
			"prompt_coverage": ["W0", "W1", "W2", "W3", "W4", "W5", "W6", "W7"],
			"status": "active",
		}],
	}
	var approval := identity.duplicate(true)
	approval.merge({
		"prompt_coverage": ["W0", "W1", "W2", "W3", "W4", "W5", "W6", "W7"],
		"prompt_conformance_report_sha256": prompt_report_sha256,
		"device_report_sha256_by_platform": {"windows": "E".repeat(64)},
		"rollback_report_sha256": "1".repeat(64),
		"a5_evidence_sha256": "2".repeat(64),
	})
	gate._release_approvals = {"approval_status": "approved", "records": [approval]}
	var metadata := identity.duplicate(true)
	metadata.merge({
		"signature_key_id": "product.release.test",
		"signature_scope": "production_release",
		"execution_trusted": true,
	})
	var candidate := {
		"package_metadata": metadata,
		"package_execution_trusted": true,
		"package_scope": "production_release",
		"exact_deck_mapping": true,
		"prompt_coverage": ["W0", "W1", "W2", "W3", "W4", "W5", "W6", "W7"],
		"prompt_conformance_report_sha256": prompt_report_sha256,
		"offline_full_match_by_platform": {"windows": false},
		"rollback_verified": true,
		"a5_evidence_approved": true,
		"device_report_sha256_by_platform": approval["device_report_sha256_by_platform"],
		"rollback_report_sha256": approval["rollback_report_sha256"],
		"a5_evidence_sha256": approval["a5_evidence_sha256"],
	}
	var accepted: Dictionary = gate.evaluate_release_candidate(candidate)
	var installed: Dictionary = gate.evaluate_installed_package(metadata)
	var mismatch := candidate.duplicate(true)
	mismatch["device_report_sha256_by_platform"] = {}
	var rejected: Dictionary = gate.evaluate_release_candidate(mismatch)
	var cross_scope := candidate.duplicate(true)
	cross_scope["offline_full_match_by_platform"] = {"windows": true, "android": true}
	cross_scope["device_report_sha256_by_platform"] = {"windows": "E".repeat(64), "android": "F".repeat(64)}
	var cross_scope_rejected: Dictionary = gate.evaluate_release_candidate(cross_scope)
	var boolean_alias := candidate.duplicate(true)
	boolean_alias["rollback_verified"] = 1
	var alias_rejected: Dictionary = gate.evaluate_release_candidate(boolean_alias)
	var prompt_drift := candidate.duplicate(true)
	prompt_drift["prompt_conformance_report_sha256"] = "0".repeat(64)
	var prompt_drift_rejected: Dictionary = gate.evaluate_release_candidate(prompt_drift)
	return run_checks([
		assert_true(bool(accepted.get("accepted", false)), str(accepted)),
		assert_true(bool(accepted.get("player_start_allowed", false))),
		assert_true(bool(installed.get("accepted", false)), str(installed)),
		assert_true(bool(installed.get("player_start_allowed", false))),
		assert_eq(installed.get("authority_source"), "fixed_product_release_approval"),
		assert_false(bool(rejected.get("accepted", true))),
		assert_eq(rejected.get("error_code"), "release_device_evidence_incomplete"),
		assert_false(bool(cross_scope_rejected.get("accepted", true))),
		assert_eq(cross_scope_rejected.get("error_code"), "release_device_evidence_incomplete"),
		assert_false(bool(rejected.get("player_start_allowed", true))),
		assert_false(bool(alias_rejected.get("accepted", true))),
		assert_eq(alias_rejected.get("error_code"), "release_rollback_invalid"),
		assert_false(bool(prompt_drift_rejected.get("accepted", true))),
		assert_eq(prompt_drift_rejected.get("error_code"), "release_prompt_conformance_unapproved"),
	])


func test_device_canary_rejects_bare_w0_w7_claim_without_bound_conformance_report() -> String:
	var gate := ReleaseGateScript.new()
	gate._trust_store = {
		"approval_status": "approved",
		"keys": [{
			"key_id": "product.release.test",
			"algorithm": "ed25519",
			"scope": "production_release",
			"execution_trusted": true,
			"status": "active",
		}],
	}
	gate._device_profile = {"approval_status": "approved", "formal_a5_eligible": true}
	var identity := {
		"package_id": "author.strategy",
		"package_version": "1.0.0",
		"archive_sha256": "A".repeat(64),
		"manifest_sha256": "B".repeat(64),
		"policy_ir_sha256": "C".repeat(64),
		"deck_manifest_sha256": "D".repeat(64),
	}
	var metadata := identity.duplicate(true)
	metadata.merge({
		"signature_key_id": "product.release.test",
		"signature_scope": "production_release",
		"execution_trusted": true,
	})
	var approval := identity.duplicate(true)
	approval.merge({
		"signature_key_id": "product.release.test",
		"platform": "windows",
		"prompt_coverage": ["W0", "W1", "W2", "W3", "W4", "W5", "W6", "W7"],
		"prompt_conformance_report_sha256": "F".repeat(64),
		"status": "active",
	})
	gate._device_canary_approvals = {"approval_status": "approved", "records": [approval]}
	gate._prompt_conformance_approvals = {"approval_status": "approved", "records": []}
	var bare: Dictionary = gate.evaluate_device_canary_package(metadata, "windows")
	return run_checks([
		assert_false(bool(bare.get("accepted", true))),
		assert_false(bool(bare.get("device_canary_allowed", true))),
		assert_eq(bare.get("error_code"), "release_prompt_conformance_unapproved"),
	])


func test_device_attempt_counters_reject_boolean_integer_aliases() -> String:
	var gate := ReleaseGateScript.new()
	gate._device_profile = _approved_device_profile()
	var report := _good_device_report(gate._device_profile)
	report["offline"]["remote_inference_attempts"] = false
	var decision: Dictionary = gate.evaluate_device_report(report)
	var malformed_package: Dictionary = gate.evaluate_package(null)
	var malformed_candidate: Dictionary = gate.evaluate_release_candidate([])
	var malformed_report: Dictionary = gate.evaluate_device_report([])
	return run_checks([
		assert_false(bool(decision.get("accepted", true))),
		assert_eq(decision.get("error_code"), "device_external_runtime_detected"),
		assert_eq(malformed_package.get("error_code"), "release_package_not_execution_trusted"),
		assert_eq(malformed_candidate.get("error_code"), "release_package_not_execution_trusted"),
		assert_eq(malformed_report.get("error_code"), "device_report_invalid"),
	])


func test_device_reports_require_profile_sample_measurement_and_evidence_binding() -> String:
	var gate := ReleaseGateScript.new()
	gate._device_profile = _approved_device_profile()
	var valid: Dictionary = gate.evaluate_device_report(_good_device_report(gate._device_profile))
	var short_samples := _good_device_report(gate._device_profile)
	short_samples["samples"]["decision_msec"] = (short_samples["samples"]["decision_msec"] as Array).slice(0, 99)
	var short_result: Dictionary = gate.evaluate_device_report(short_samples)
	var mismatched := _good_device_report(gate._device_profile)
	mismatched["measurements"]["decision_p95_msec"] = 11
	var mismatch_result: Dictionary = gate.evaluate_device_report(mismatched)
	var wrong_profile := _good_device_report(gate._device_profile)
	wrong_profile["profile_id"] = "wrong-profile"
	var profile_result: Dictionary = gate.evaluate_device_report(wrong_profile)
	var invalid_evidence := _good_device_report(gate._device_profile)
	invalid_evidence["evidence"]["network_audit_sha256"] = "invalid"
	var evidence_result: Dictionary = gate.evaluate_device_report(invalid_evidence)
	var additive := _good_device_report(gate._device_profile)
	additive["unexpected"] = true
	var additive_result: Dictionary = gate.evaluate_device_report(additive)
	return run_checks([
		assert_true(bool(valid.get("accepted", false)), str(valid)),
		assert_eq(short_result.get("error_code"), "device_sample_count_insufficient"),
		assert_eq(mismatch_result.get("error_code"), "device_measurement_mismatch"),
		assert_eq(profile_result.get("error_code"), "device_report_profile_mismatch"),
		assert_eq(evidence_result.get("error_code"), "device_evidence_invalid"),
		assert_eq(additive_result.get("error_code"), "device_report_invalid"),
	])


func _approved_device_profile() -> Dictionary:
	return {
		"document_type": "author_strategy_device_acceptance_profile_v1",
		"schema_version": 1,
		"profile_id": "ptcgdap-device-acceptance-candidate-v1",
		"approval_status": "approved",
		"formal_a5_eligible": true,
		"platforms": {
			"windows": {
				"max_cold_start_msec": 5000,
				"max_catalog_scan_msec": 1000,
				"max_match_load_msec": 2000,
				"max_decision_p95_msec": 250,
				"max_peak_memory_mib": 1024,
				"max_package_mib": 750,
				"max_thermal_status": null,
				"max_battery_drain_percent_per_hour": null,
			},
		},
		"measurement_method": {
			"full_match_required": true,
			"airplane_or_os_block_required": true,
			"cold_start_samples": 3,
			"decision_samples_minimum": 100,
			"rollback_required": true,
		},
	}


func _good_device_report(profile: Dictionary) -> Dictionary:
	var decisions := []
	decisions.resize(100)
	decisions.fill(10)
	return {
		"document_type": "author_strategy_device_report_v1",
		"schema_version": 1,
		"profile_id": profile["profile_id"],
		"platform": "windows",
		"architecture": "x86_64",
		"offline": {
			"network_blocked": true,
			"remote_inference_attempts": 0,
			"dynamic_download_attempts": 0,
			"complete_match_finished": true,
		},
		"runtime": {
			"system_python_required": false,
			"external_compute_required": false,
			"sidecar_processes": [],
		},
		"samples": {
			"cold_start_msec": [80, 90, 100],
			"decision_msec": decisions,
		},
		"measurements": {
			"cold_start_msec": 100,
			"catalog_scan_msec": 50,
			"match_load_msec": 100,
			"decision_p95_msec": 10,
			"peak_memory_mib": 100,
			"package_mib": 100,
			"thermal_status_max": null,
			"battery_drain_percent_per_hour": null,
		},
		"rollback": {"mode_disabled": true, "user_packages_preserved": true},
		"evidence": {
			"profile_canonical_sha256": _canonical_sha256(profile),
			"export_manifest_sha256": "A".repeat(64),
			"network_audit_sha256": "B".repeat(64),
			"process_audit_sha256": "C".repeat(64),
			"full_match_audit_sha256": "D".repeat(64),
			"rollback_report_sha256": "E".repeat(64),
		},
	}


func _canonical_sha256(value: Variant) -> String:
	return ReleaseGateScript.canonical_profile_sha256(value)


func _read(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	return PackedByteArray() if file == null else file.get_buffer(file.get_length())
