class_name PtcgDAPPublicReplayDevelopmentEnvelope
extends RefCounted

const JsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")

const PROFILE_ID := "csp-wp1-marnie-development-v1"
const EVALUATOR_ID := "ptcgdap-csp-wp1-local-capture"
const BASELINE_ID := "rules-only-575720"
const BASELINE_VERSION := "1.0.0"
const EVENT_DICTIONARY := {
	"match_started": "first public state after setup bootstrap",
	"state_progressed": "public state after one successful engine progress",
	"match_finished": "terminal public state",
}


static func build(
	contract_owner: Variant,
	public_identity: Variant,
	seed: int,
	match_id: String
) -> Dictionary:
	if contract_owner == null or not contract_owner.has_method("validate_document"):
		return _failure("contract_owner_invalid")
	if not public_identity is Dictionary or not bool(public_identity.get("ok", false)):
		return _failure("public_identity_invalid")
	if public_identity.get("match_id") != match_id:
		return _failure("public_identity_match_mismatch")
	var engine_rows := _hash_rows(["res://scripts/engine", "res://scripts/data"])
	var rules_rows := _hash_rows(["res://scripts/effects"])
	var baseline_rows := _hash_rows(["res://scripts/ai"], ["res://scripts/ai/ptcgdap"])
	var replay_rows := _hash_rows([
		"res://scripts/ai/ptcgdap/platform/replay",
		"res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd",
	])
	if engine_rows.is_empty() or rules_rows.is_empty() or baseline_rows.is_empty() or replay_rows.is_empty():
		return _failure("provenance_source_unavailable")
	var engine_sha256 := _canonical_hash({"domain": "csp_wp1_engine_source_tree_v1", "files": engine_rows})
	var rules_sha256 := _canonical_hash({"domain": "csp_wp1_rules_source_tree_v1", "files": rules_rows})
	var baseline_sha256 := _canonical_hash({"domain": "csp_wp1_baseline_source_tree_v1", "files": baseline_rows})
	var runtime_manifest := {
		"domain": "csp_wp1_development_runtime_source_manifest_v1",
		"engine_sha256": engine_sha256,
		"rules_sha256": rules_sha256,
		"baseline_sha256": baseline_sha256,
		"replay_files": replay_rows,
	}
	var runtime_manifest_sha256 := _canonical_hash(runtime_manifest)
	var development_profile := {
		"profile_id": PROFILE_ID,
		"lane": "developer_local",
		"candidate": "exact-built-in-marnie-800018501",
		"baseline": BASELINE_ID,
		"visibility_profile": "public_at_event_time_v1",
		"hash_domain": "canonical_json_v1_sha256_over_declared_source_rows",
	}
	var profile_sha256 := _canonical_hash(development_profile)
	var event_dictionary_sha256 := _canonical_hash(EVENT_DICTIONARY)
	var strategy_participant: Variant = public_identity.get("strategy_participant")
	var card_catalog_sha256: Variant = public_identity.get("card_catalog_sha256")
	if (
		not strategy_participant is Dictionary
		or typeof(card_catalog_sha256) != TYPE_STRING
		or str(card_catalog_sha256).length() != 64
	):
		return _failure("public_identity_invalid")
	var envelope := {
		"document_type": "match_envelope_v1",
		"schema_version": 1,
		"match_id": match_id,
		"lane": "developer_local",
		"evaluator_id": EVALUATOR_ID,
		"participants": [
			(strategy_participant as Dictionary).duplicate(true),
			{
				"participant_kind": "platform_baseline",
				"baseline_id": BASELINE_ID,
				"baseline_version": BASELINE_VERSION,
				"baseline_sha256": baseline_sha256,
			},
		],
		"engine_sha256": engine_sha256,
		"rules_sha256": rules_sha256,
		"card_catalog_sha256": card_catalog_sha256,
		"host_contract_sha256": contract_owner.bundle_canonical_sha256(),
		"runtime_manifest_sha256": runtime_manifest_sha256,
		"evaluation_profile_id": PROFILE_ID,
		"evaluation_profile_sha256": profile_sha256,
		"seat_assignment": [1, 0],
		"seed_commitment": {
			"capability": "deterministic_seed_v1",
			"commitment_sha256": _canonical_hash({
				"domain": "csp_wp1_seed_commitment_v1",
				"seed": seed,
			}),
			"disclosure": "withheld",
		},
		"replay_visibility_profile": "public_at_event_time_v1",
		"started_at_utc": "%sZ" % Time.get_datetime_string_from_system(true),
	}
	var validation: Dictionary = contract_owner.validate_document(envelope)
	if not bool(validation.get("accepted", false)):
		return validation
	return {
		"accepted": true,
		"error_code": "",
		"envelope": envelope,
		"card_asset_catalog_sha256": card_catalog_sha256,
		"event_dictionary_sha256": event_dictionary_sha256,
		"provenance": {
			"development_profile": development_profile,
			"runtime_manifest": runtime_manifest,
			"evaluation_profile_sha256": profile_sha256,
			"runtime_manifest_sha256": runtime_manifest_sha256,
		},
	}


static func _hash_rows(roots: Array, excluded_roots: Array = []) -> Array:
	var paths: Array[String] = []
	for root: Variant in roots:
		var path := str(root)
		if FileAccess.file_exists(path):
			paths.append(path)
		else:
			_collect_files(path, paths, excluded_roots)
	paths.sort()
	var rows: Array = []
	for path: String in paths:
		var digest := FileAccess.get_sha256(path).to_upper()
		if digest.length() != 64:
			return []
		rows.append({"path": path.trim_prefix("res://"), "raw_sha256": digest})
	return rows


static func _collect_files(root: String, paths: Array[String], excluded_roots: Array) -> void:
	for excluded: Variant in excluded_roots:
		if root == str(excluded) or root.begins_with("%s/" % str(excluded)):
			return
	var directory := DirAccess.open(root)
	if directory == null:
		return
	directory.list_dir_begin()
	var filename := directory.get_next()
	while not filename.is_empty():
		if filename not in [".", ".."]:
			var path := "%s/%s" % [root.trim_suffix("/"), filename]
			if directory.current_is_dir():
				_collect_files(path, paths, excluded_roots)
			elif filename.ends_with(".gd") or filename.ends_with(".json"):
				paths.append(path)
		filename = directory.get_next()
	directory.list_dir_end()


static func _canonical_hash(value: Variant) -> String:
	var canonical: Dictionary = JsonTreeScript.canonicalize_artifact(value)
	if not bool(canonical.get("ok", false)):
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(canonical.get("bytes", PackedByteArray())) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


static func _failure(code: String) -> Dictionary:
	return {"accepted": false, "error_code": code, "authoritative": false, "grants": []}
