extends RefCounted

const ZipScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageZip.gd")
const Ed25519Script = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageEd25519.gd")
const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const AuthorStrategyReleaseGateScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyReleaseGate.gd")
const CompetitivePolicyV2Script = preload("res://scripts/ai/ptcgdap/public/CompetitivePolicyV2.gd")

const PROFILE_ID := "ptcgdap-author-strategy-package-v1"
const BUNDLE_ID := "ptcgdap-author-strategy-package-as-wp1-v1"
const TEST_FIXTURE_KEY_ID := "ptcgdap-as-wp1-test-fixture-ed25519-v1"
const TEST_FIXTURE_PUBLIC_KEY_BASE64 := "A6EHv/POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg="
const EXPECTED_BUNDLE_CANONICAL_SHA256 := "B416F2CBA2795B62126B6EF7B5F07A9000E84D5FA1DF62C1753CADC9E82E106B"
const EXPECTED_ARTIFACT_CANONICAL_SHA256 := {
	"schema": "B3469DA24400407775FB6069CB5D9EE2147633770542322208B9FE102E0E20BE",
	"profile": "1137187EF1C073E081B541602A7498B7235A3606309C35212BC6559F0EF30B79",
	"vectors": "49F4493D89E74B4ED6F54957BAFDC0E3C1161C5BA695203AE3CEE17DEE50EE33",
}
const CONTRACT_PATHS := {
	"schema": "res://contracts/ptcgdap/author_strategy_package.schema.json",
	"profile": "res://contracts/ptcgdap/author_strategy_package_profile.json",
	"vectors": "res://contracts/ptcgdap/author_strategy_package_conformance_vectors.json",
	"bundle": "res://contracts/ptcgdap/author_strategy_package_bundle.json",
}
const COMPETITIVE_POLICY_V2_PROFILE_ID := "ptcgdap-competitive-policy-v2"
const COMPETITIVE_POLICY_V2_BUNDLE_ID := "ptcgdap-competitive-policy-v2-as2-wp1"
const COMPETITIVE_POLICY_V2_EXPECTED_BUNDLE_CANONICAL_SHA256 := "5F87E10C6C87B5CE71CBB2ACE2C31A5FA39C49C95F84F0D7983DEC86DCA2F3C3"
const COMPETITIVE_POLICY_V2_EXPECTED_ARTIFACT_CANONICAL_SHA256 := {
	"schema": "4A8E21D90A0B6EF1921BDC123BB58C0297F57EEACF8490F44EC0B46E8E60B910",
	"profile": "46FC76FFD292FDA0A9F4F4221EA14C8F7DFC2462163733E42876EAA7CFE63677",
	"vectors": "42BEB7D514686600F255E06BB76AF4440A08294D845C8D9CE4A7966C28701F7E",
}
const COMPETITIVE_POLICY_V2_CONTRACT_PATHS := {
	"schema": "res://contracts/ptcgdap/competitive_policy_v2.schema.json",
	"profile": "res://contracts/ptcgdap/competitive_policy_v2_profile.json",
	"vectors": "res://contracts/ptcgdap/competitive_policy_v2_conformance_vectors.json",
	"bundle": "res://contracts/ptcgdap/competitive_policy_v2_bundle.json",
}
const WINDOWS_LOCAL_DECK_PROFILE_ID := "ptcgdap-author-strategy-windows-local-deck-v1"
const WINDOWS_LOCAL_DECK_BUNDLE_ID := "ptcgdap-author-strategy-windows-local-deck-as-wp6-v1"
const WINDOWS_LOCAL_DECK_DOMAIN := "godot_local_card_uid_v1"
const WINDOWS_LOCAL_DECK_EXPECTED_BUNDLE_CANONICAL_SHA256 := "944440FB15D9C3C3533C4DFDF7B163BF690160CF1F6D6AB8C776958A6EDBDB56"
const WINDOWS_LOCAL_DECK_EXPECTED_ARTIFACT_CANONICAL_SHA256 := {
	"schema": "3E953F9289634BDD4D35C5DB4FC35BDA7BE0DABCAEDF25EA4B8190016B186F72",
	"profile": "917834D3F018CBC52B037E19FCECFF9A6B1967E4CA9206B9AE68FA70C557921C",
	"vectors": "8158B85B8F97E2B9539006810AA7D46C8B5752BC3A6DF968A8484DAA6DD7019A",
}
const WINDOWS_LOCAL_DECK_CONTRACT_PATHS := {
	"schema": "res://contracts/ptcgdap/author_strategy_windows_local_deck.schema.json",
	"profile": "res://contracts/ptcgdap/author_strategy_windows_local_deck_profile.json",
	"vectors": "res://contracts/ptcgdap/author_strategy_windows_local_deck_conformance_vectors.json",
	"bundle": "res://contracts/ptcgdap/author_strategy_windows_local_deck_bundle.json",
}
const CABT_CONTRACT_SHA256 := "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
const CARD_CATALOG_SHA256 := "AB8CF10465F492A98DA8247A84572AECEE281D0726F7BB7B8E5DBC03A6AC70D4"
const BASE_EXECUTOR_SHA256 := "69D05747A9F91C19765D448B676C86E1D9DFA1BBAB108ED1374B854B34E48389"
const MODEL_MANIFEST_PATH := "model/model_manifest.json"
const MODEL_ARTIFACT_PATH := "model/actor.ort"
const MODEL_TENSOR_PROFILE_SHA256 := "72B3430E2C94E98DABE99D674208268091ACA47CCF4A50F22F14CCABD080620B"
const MODEL_ALLOWED_OPS := ["Add", "ArgMax", "Cast", "Clip", "Constant", "Gather", "Greater", "MatMul", "Mul", "ReduceSum", "Reshape", "Where"]

const REQUIRED_PAYLOAD_PATHS := {
	"strategy_package.json": true,
	"README.md": true,
	"LICENSE": true,
	"deck/deck_manifest.json": true,
	"deck/deck.csv": true,
	"policy/policy_ir.json": true,
	"policy/adapter.json": true,
	"policy/config.json": true,
}
const GENERATED_PATHS := {"files.sha256.json": true, "signature.json": true}
const OPTIONAL_PAYLOAD_KINDS := {
	"policy/weights.bin": "weights",
	MODEL_MANIFEST_PATH: "json",
	MODEL_ARTIFACT_PATH: "weights",
	"assets/icon.png": "png",
	"assets/banner.png": "png",
	"assets/icon.webp": "webp",
	"assets/banner.webp": "webp",
}
const FIXED_PAYLOAD_KINDS := {
	"strategy_package.json": "json", "README.md": "text", "LICENSE": "text",
	"deck/deck_manifest.json": "json", "deck/deck.csv": "csv",
	"policy/policy_ir.json": "json", "policy/adapter.json": "json", "policy/config.json": "json",
}
const FORBIDDEN_SUFFIXES := [".gd", ".py", ".pck", ".exe", ".dll", ".so", ".aar", ".jar", ".sh", ".bat", ".ps1", ".zip", ".7z", ".rar", ".tar", ".gz"]
const FORBIDDEN_POLICY_KEYS := ["callable", "module", "class", "code", "script", "path", "url", "import", "private_state", "search_begin_input", "session", "callback", "binding", "ticket", "command", "object_ref", "pokemon_entity_serial"]
const SUPPORTED_CAPABILITIES := [
	"public_context", "current_window", "deterministic_fallback", "strategic_trace_v2",
	"public_damage_plan_v1", "semantic_transaction_v1", "turn_transaction_v1",
	"learned_policy_head_v1",
]
const REQUIRED_IR_CAPABILITIES := ["public_context", "current_window", "deterministic_fallback", "strategic_trace_v2"]
const BASE_OPERATOR_ORDER := ["legality_guard", "mandatory_terminal_guard", "hard_tier_filter", "base_veto", "deterministic_fallback", "emit_decision"]
const ADAPTER_OPERATORS := ["goal_proposal", "macro_proposal", "tiebreak_score"]
const ADAPTER_REASONS := {"goal_proposal": "public_goal_proposal", "macro_proposal": "public_macro_proposal", "tiebreak_score": "public_tiebreak_proposal"}
const GOAL_STAGES := ["acquire", "deploy", "fund", "ready", "execute", "maintain", "recover"]
const PREDICATE_FIELDS := ["select_type_raw", "select_context_raw", "option_type_raw", "option_card_id", "option_player_index", "acting_hand_card_id", "acting_active_card_id"]
const CARD_PREDICATE_FIELDS := ["option_card_id", "acting_hand_card_id", "acting_active_card_id"]
const MAX_SAFE_INTEGER := 9007199254740991

var _profile: Dictionary = {}
var _competitive_policy_v2_profile: Dictionary = {}
var _windows_local_deck_profile: Dictionary = {}
var _limits: Dictionary = {}
var _trust_store: Dictionary = {}
var _release_gate: RefCounted = null
var _integrity_error := ""


func _init() -> void:
	var contracts := _load_contracts()
	if not bool(contracts.get("ok", false)):
		_integrity_error = str(contracts.get("error_code", "package_integrity_invalid"))
		return
	var local_contracts := _load_windows_local_deck_contracts()
	if not bool(local_contracts.get("ok", false)):
		_integrity_error = str(local_contracts.get("error_code", "package_integrity_invalid"))
		return
	var competitive_contracts := _load_competitive_policy_v2_contracts()
	if not bool(competitive_contracts.get("ok", false)):
		_integrity_error = str(competitive_contracts.get("error_code", "package_integrity_invalid"))
		return
	_profile = contracts.get("profile", {}).duplicate(true)
	_competitive_policy_v2_profile = competitive_contracts.get("profile", {}).duplicate(true)
	_windows_local_deck_profile = local_contracts.get("profile", {}).duplicate(true)
	_limits = _profile.get("resource_limits", {}).duplicate(true)
	for key_value in _profile.get("trust_store", {}).get("keys", []):
		if not key_value is Dictionary:
			_integrity_error = "package_integrity_invalid"
			return
		var key: Dictionary = key_value
		var key_id := str(key.get("key_id", ""))
		if key_id.is_empty() or _trust_store.has(key_id):
			_integrity_error = "package_integrity_invalid"
			return
		_trust_store[key_id] = key.duplicate(true)
	_release_gate = AuthorStrategyReleaseGateScript.new()
	for key_value in _release_gate.trusted_release_keys():
		var key: Dictionary = key_value
		var key_id := str(key.get("key_id", ""))
		if key_id.is_empty() or _trust_store.has(key_id):
			_integrity_error = "package_integrity_invalid"
			return
		_trust_store[key_id] = key.duplicate(true)


func contract_report() -> Dictionary:
	var release: Dictionary = _release_gate.audit_snapshot() if _release_gate != null else {}
	return {
		"ok": _integrity_error == "",
		"error_code": _integrity_error,
		"profile_id": PROFILE_ID,
		"bundle_id": BUNDLE_ID,
		"bundle_canonical_sha256": EXPECTED_BUNDLE_CANONICAL_SHA256,
		"competitive_policy_v2_bundle_canonical_sha256": COMPETITIVE_POLICY_V2_EXPECTED_BUNDLE_CANONICAL_SHA256,
		"windows_local_deck_bundle_canonical_sha256": WINDOWS_LOCAL_DECK_EXPECTED_BUNDLE_CANONICAL_SHA256,
		"windows_local_deck_card_id_domain": WINDOWS_LOCAL_DECK_DOMAIN,
		"test_fixture_key_execution_trusted": false,
		"production_trust_status": release.get("production_trust_status", "invalid"),
		"active_production_key_count": release.get("active_production_key_count", 0),
		"live_consumer": false,
		"execution_authority": false,
	}


func inspect_path(path: String, expected_archive_sha256: String = "") -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error("package_archive_invalid")
	var captured := file.get_buffer(file.get_length())
	file = null
	return inspect_bytes(captured, expected_archive_sha256)


func inspect_bytes(archive_bytes: PackedByteArray, expected_archive_sha256: String = "") -> Dictionary:
	return _inspect_captured_bytes(archive_bytes, expected_archive_sha256, false)


func inspect_match_bytes(archive_bytes: PackedByteArray, expected_archive_sha256: String = "") -> Dictionary:
	return _inspect_captured_bytes(archive_bytes, expected_archive_sha256, true)


func inspect_control_verified_server_match_bytes(
	archive_bytes: PackedByteArray,
	expected_archive_sha256: String,
	author_signature_binding: Dictionary
) -> Dictionary:
	if not _server_competition_authorized():
		return _error("server_competition_platform_not_authorized")
	if not _valid_control_signature_binding(author_signature_binding):
		return _error("package_signature_untrusted")
	return _inspect_captured_bytes(
		archive_bytes, expected_archive_sha256, true, author_signature_binding
	)


func _inspect_captured_bytes(
	archive_bytes: PackedByteArray,
	expected_archive_sha256: String,
	include_match_payloads: bool,
	author_signature_binding: Dictionary = {}
) -> Dictionary:
	if _integrity_error != "":
		return _error(_integrity_error)
	if archive_bytes.is_empty():
		return _error("package_archive_invalid")
	if archive_bytes.size() > int(_limits.get("max_archive_bytes", 0)):
		return _error("package_resource_limit_exceeded")
	var archive_sha := _sha(archive_bytes)
	if expected_archive_sha256 != "":
		if not _is_sha(expected_archive_sha256) or expected_archive_sha256 != archive_sha:
			return _error("package_integrity_invalid")
	var archive: Dictionary = ZipScript.read(archive_bytes, _limits)
	if not bool(archive.get("ok", false)):
		return archive
	return _validate_members(
		archive.get("members", {}), archive_sha, include_match_payloads,
		author_signature_binding
	)


func _load_contracts() -> Dictionary:
	var docs := {}
	var canonical := {}
	for artifact_id in CONTRACT_PATHS:
		var file := FileAccess.open(str(CONTRACT_PATHS[artifact_id]), FileAccess.READ)
		if file == null:
			return _error("package_integrity_invalid")
		var parsed: Dictionary = CabtJsonTreeScript.canonicalize_artifact_json_bytes(file.get_buffer(file.get_length()))
		if not bool(parsed.get("ok", false)):
			return _error("package_integrity_invalid")
		var document: Variant = JSON.parse_string(str(parsed.get("text", "")))
		if not document is Dictionary:
			return _error("package_integrity_invalid")
		docs[artifact_id] = document
		canonical[artifact_id] = _sha(parsed.get("bytes", PackedByteArray()))
	if canonical.get("bundle") != EXPECTED_BUNDLE_CANONICAL_SHA256:
		return _error("package_integrity_invalid")
	var bundle: Dictionary = docs.get("bundle", {})
	if not _exact_keys(bundle, ["schema_version", "bundle_id", "profile_id", "parent", "artifacts"]):
		return _error("package_integrity_invalid")
	if bundle.get("schema_version") != 1 or bundle.get("bundle_id") != BUNDLE_ID or bundle.get("profile_id") != PROFILE_ID or not bundle.get("parent") is Dictionary:
		return _error("package_integrity_invalid")
	var artifacts: Variant = bundle.get("artifacts")
	if not artifacts is Array or artifacts.size() != 3:
		return _error("package_integrity_invalid")
	var seen := {}
	for entry_value in artifacts:
		if not entry_value is Dictionary:
			return _error("package_integrity_invalid")
		var entry: Dictionary = entry_value
		if not _exact_keys(entry, ["id", "path", "canonical_sha256"]):
			return _error("package_integrity_invalid")
		var artifact_id := str(entry.get("id", ""))
		if not EXPECTED_ARTIFACT_CANONICAL_SHA256.has(artifact_id) or seen.has(artifact_id):
			return _error("package_integrity_invalid")
		if entry.get("path") != str(CONTRACT_PATHS[artifact_id]).trim_prefix("res://"):
			return _error("package_integrity_invalid")
		if entry.get("canonical_sha256") != EXPECTED_ARTIFACT_CANONICAL_SHA256[artifact_id] or canonical.get(artifact_id) != EXPECTED_ARTIFACT_CANONICAL_SHA256[artifact_id]:
			return _error("package_integrity_invalid")
		seen[artifact_id] = true
	if seen.size() != 3:
		return _error("package_integrity_invalid")
	var profile: Dictionary = docs.get("profile", {})
	if profile.get("schema_version") != 1 or profile.get("profile_id") != PROFILE_ID:
		return _error("package_integrity_invalid")
	if profile.get("trust_store", {}).get("caller_overrides") != false:
		return _error("package_integrity_invalid")
	return {"ok": true, "error_code": "", "profile": profile}


func _load_windows_local_deck_contracts() -> Dictionary:
	var docs := {}
	var canonical := {}
	for artifact_id in WINDOWS_LOCAL_DECK_CONTRACT_PATHS:
		var file := FileAccess.open(str(WINDOWS_LOCAL_DECK_CONTRACT_PATHS[artifact_id]), FileAccess.READ)
		if file == null:
			return _error("package_integrity_invalid")
		var parsed: Dictionary = CabtJsonTreeScript.canonicalize_artifact_json_bytes(file.get_buffer(file.get_length()))
		if not bool(parsed.get("ok", false)):
			return _error("package_integrity_invalid")
		var document: Variant = JSON.parse_string(str(parsed.get("text", "")))
		if not document is Dictionary:
			return _error("package_integrity_invalid")
		docs[artifact_id] = document
		canonical[artifact_id] = _sha(parsed.get("bytes", PackedByteArray()))
	if canonical.get("bundle") != WINDOWS_LOCAL_DECK_EXPECTED_BUNDLE_CANONICAL_SHA256:
		return _error("package_integrity_invalid")
	var bundle: Dictionary = docs.get("bundle", {})
	if not _exact_keys(bundle, ["schema_version", "bundle_id", "profile_id", "parent_author_package_bundle_canonical_sha256", "artifacts"]):
		return _error("package_integrity_invalid")
	if bundle.get("schema_version") != 1 or bundle.get("bundle_id") != WINDOWS_LOCAL_DECK_BUNDLE_ID or bundle.get("profile_id") != WINDOWS_LOCAL_DECK_PROFILE_ID or bundle.get("parent_author_package_bundle_canonical_sha256") != EXPECTED_BUNDLE_CANONICAL_SHA256:
		return _error("package_integrity_invalid")
	var artifacts: Variant = bundle.get("artifacts")
	if not artifacts is Array or artifacts.size() != 3:
		return _error("package_integrity_invalid")
	var seen := {}
	for entry_value in artifacts:
		if not entry_value is Dictionary:
			return _error("package_integrity_invalid")
		var entry: Dictionary = entry_value
		if not _exact_keys(entry, ["id", "path", "canonical_sha256"]):
			return _error("package_integrity_invalid")
		var artifact_id := str(entry.get("id", ""))
		if not WINDOWS_LOCAL_DECK_EXPECTED_ARTIFACT_CANONICAL_SHA256.has(artifact_id) or seen.has(artifact_id):
			return _error("package_integrity_invalid")
		if entry.get("path") != str(WINDOWS_LOCAL_DECK_CONTRACT_PATHS[artifact_id]).trim_prefix("res://"):
			return _error("package_integrity_invalid")
		if entry.get("canonical_sha256") != WINDOWS_LOCAL_DECK_EXPECTED_ARTIFACT_CANONICAL_SHA256[artifact_id] or canonical.get(artifact_id) != WINDOWS_LOCAL_DECK_EXPECTED_ARTIFACT_CANONICAL_SHA256[artifact_id]:
			return _error("package_integrity_invalid")
		seen[artifact_id] = true
	var profile: Dictionary = docs.get("profile", {})
	if seen.size() != 3 or profile.get("schema_version") != 1 or profile.get("profile_id") != WINDOWS_LOCAL_DECK_PROFILE_ID or profile.get("supported_platforms") != ["windows"] or profile.get("card_id_domain") != WINDOWS_LOCAL_DECK_DOMAIN or profile.get("cabt_exportable") != false:
		return _error("package_integrity_invalid")
	return {"ok": true, "error_code": "", "profile": profile}


func _load_competitive_policy_v2_contracts() -> Dictionary:
	var docs := {}
	var canonical := {}
	for artifact_id in COMPETITIVE_POLICY_V2_CONTRACT_PATHS:
		var file := FileAccess.open(str(COMPETITIVE_POLICY_V2_CONTRACT_PATHS[artifact_id]), FileAccess.READ)
		if file == null:
			return _error("package_integrity_invalid")
		var parsed: Dictionary = CabtJsonTreeScript.canonicalize_artifact_json_bytes(
			file.get_buffer(file.get_length())
		)
		if not bool(parsed.get("ok", false)):
			return _error("package_integrity_invalid")
		var document: Variant = JSON.parse_string(str(parsed.get("text", "")))
		if not document is Dictionary:
			return _error("package_integrity_invalid")
		docs[artifact_id] = document
		canonical[artifact_id] = _sha(parsed.get("bytes", PackedByteArray()))
	if canonical.get("bundle") != COMPETITIVE_POLICY_V2_EXPECTED_BUNDLE_CANONICAL_SHA256:
		return _error("package_integrity_invalid")
	var bundle: Dictionary = docs.get("bundle", {})
	if not _exact_keys(bundle, ["schema_version", "bundle_id", "profile_id", "parent_author_package_bundle_canonical_sha256", "artifacts"]):
		return _error("package_integrity_invalid")
	if (
		bundle.get("schema_version") != 2
		or bundle.get("bundle_id") != COMPETITIVE_POLICY_V2_BUNDLE_ID
		or bundle.get("profile_id") != COMPETITIVE_POLICY_V2_PROFILE_ID
		or bundle.get("parent_author_package_bundle_canonical_sha256") != EXPECTED_BUNDLE_CANONICAL_SHA256
	):
		return _error("package_integrity_invalid")
	var artifacts: Variant = bundle.get("artifacts")
	if not artifacts is Array or artifacts.size() != 3:
		return _error("package_integrity_invalid")
	var seen := {}
	for entry_value: Variant in artifacts:
		if not entry_value is Dictionary:
			return _error("package_integrity_invalid")
		var entry: Dictionary = entry_value
		if not _exact_keys(entry, ["id", "path", "canonical_sha256"]):
			return _error("package_integrity_invalid")
		var artifact_id := str(entry.get("id", ""))
		if not COMPETITIVE_POLICY_V2_EXPECTED_ARTIFACT_CANONICAL_SHA256.has(artifact_id) or seen.has(artifact_id):
			return _error("package_integrity_invalid")
		if entry.get("path") != str(COMPETITIVE_POLICY_V2_CONTRACT_PATHS[artifact_id]).trim_prefix("res://"):
			return _error("package_integrity_invalid")
		if (
			entry.get("canonical_sha256") != COMPETITIVE_POLICY_V2_EXPECTED_ARTIFACT_CANONICAL_SHA256[artifact_id]
			or canonical.get(artifact_id) != COMPETITIVE_POLICY_V2_EXPECTED_ARTIFACT_CANONICAL_SHA256[artifact_id]
		):
			return _error("package_integrity_invalid")
		seen[artifact_id] = true
	var profile: Dictionary = docs.get("profile", {})
	if (
		seen.size() != 3
		or profile.get("schema_version") != 2
		or profile.get("profile_id") != COMPETITIVE_POLICY_V2_PROFILE_ID
		or profile.get("official_policy_boundary") != "agent(raw_observation)->list[int]"
		or profile.get("compatibility", {}).get("v1_behavior_unchanged") != true
	):
		return _error("package_integrity_invalid")
	return {"ok": true, "error_code": "", "profile": profile}


func _validate_members(
	members: Dictionary,
	archive_sha: String,
	include_match_payloads: bool = false,
	author_signature_binding: Dictionary = {}
) -> Dictionary:
	var names: Array[String] = []
	for path_value in members:
		var path := str(path_value)
		names.append(path)
		for suffix in FORBIDDEN_SUFFIXES:
			if path.to_lower().ends_with(suffix):
				return _error("package_policy_unsupported")
	var allowed := REQUIRED_PAYLOAD_PATHS.duplicate()
	allowed.merge(GENERATED_PATHS)
	for path in OPTIONAL_PAYLOAD_KINDS:
		allowed[path] = true
	for path in names:
		if not allowed.has(path):
			return _error("package_file_unlisted")
	var required := REQUIRED_PAYLOAD_PATHS.duplicate()
	required.merge(GENERATED_PATHS)
	for path in required:
		if not members.has(path):
			return _error("package_file_missing")
	var sizes := _validate_kind_sizes(members)
	if not bool(sizes.get("ok", false)):
		return sizes

	var manifest_result := _strict_document(members["strategy_package.json"], "strategy_package", "package_manifest_invalid")
	var files_result := _strict_document(members["files.sha256.json"], "files_manifest", "package_manifest_invalid")
	var signature_result := _strict_document(members["signature.json"], "signature", "package_manifest_invalid")
	for result in [manifest_result, files_result, signature_result]:
		if not bool(result.get("ok", false)):
			return result
	var manifest: Dictionary = manifest_result.get("value", {})
	var files_manifest: Dictionary = files_result.get("value", {})
	var signature: Dictionary = signature_result.get("value", {})

	var listed_entries: Array = files_manifest.get("files", [])
	var listed_paths: Array[String] = []
	var listed_seen := {}
	for entry_value in listed_entries:
		var entry: Dictionary = entry_value
		var path := str(entry.get("path", ""))
		if listed_seen.has(path):
			return _error("package_manifest_invalid")
		listed_seen[path] = true
		listed_paths.append(path)
	if listed_paths != _sorted_strings(listed_paths):
		return _error("package_manifest_invalid")
	var actual_payload := {}
	for path in names:
		if not GENERATED_PATHS.has(path):
			actual_payload[path] = true
	for path in listed_seen:
		if not actual_payload.has(path):
			return _error("package_file_missing")
	for path in actual_payload:
		if not listed_seen.has(path):
			return _error("package_file_unlisted")
	for entry_value in listed_entries:
		var entry: Dictionary = entry_value
		var path := str(entry.get("path", ""))
		var expected_kind: Variant = FIXED_PAYLOAD_KINDS.get(path, OPTIONAL_PAYLOAD_KINDS.get(path))
		if expected_kind == null or entry.get("kind") != expected_kind:
			return _error("package_manifest_invalid")
		var value: PackedByteArray = members[path]
		if entry.get("bytes") != value.size() or entry.get("sha256") != _sha(value):
			return _error("package_file_hash_mismatch")

	var signature_check := _verify_signature(
		manifest, signature, members, author_signature_binding
	)
	if not bool(signature_check.get("ok", false)):
		return signature_check
	var compatibility := _verify_compatibility(manifest)
	if not bool(compatibility.get("ok", false)):
		return compatibility
	var deck_policy := _verify_deck_and_policy(manifest, members)
	if not bool(deck_policy.get("ok", false)):
		return deck_policy
	var optional := _verify_optional_relations(manifest, members)
	if not bool(optional.get("ok", false)):
		return optional

	var signature_key: Dictionary = signature_check.get("key", {})
	var execution_trusted: bool = signature_key.get("execution_trusted") == true
	var registered_developer: bool = signature_key.get("scope") == "developer_registered_release"
	var signature_status: String = (
		"control_verified_developer" if registered_developer else (
			"production_trusted" if execution_trusted else "test_fixture_trusted"
		)
	)
	var startup_deck_manifest: Variant = JSON.parse_string(members["deck/deck_manifest.json"].get_string_from_utf8())
	startup_deck_manifest = _coerce_integral_numbers(startup_deck_manifest)
	if not startup_deck_manifest is Dictionary:
		return _error("package_deck_invalid")
	var metadata := {
		"profile_id": "ptcgdap-author-strategy-package-v2" if manifest.get("schema_version") == 2 else PROFILE_ID,
		"package_document_type": manifest.get("document_type"),
		"package_id": manifest.get("package_id"),
		"package_version": manifest.get("package_version"),
		"archive_sha256": archive_sha,
		"manifest_sha256": _sha(members["strategy_package.json"]),
		"manifest_canonical_sha256": _sha(manifest_result.get("canonical_bytes", PackedByteArray())),
		"files_manifest_sha256": _sha(members["files.sha256.json"]),
		"policy_ir_sha256": _sha(members["policy/policy_ir.json"]),
		"deck_manifest_sha256": _sha(members["deck/deck_manifest.json"]),
		"author": manifest.get("author", {}).duplicate(true),
		"strategy": manifest.get("strategy", {}).duplicate(true),
		"deck": manifest.get("deck", {}).duplicate(true),
		"compatibility": manifest.get("compatibility", {}).duplicate(true),
		"signature_status": signature_status,
		"execution_trusted": execution_trusted,
		"metadata_only": true,
		"live_consumer": false,
		"execution_authority": false,
		"deck_contract_valid": true,
		"policy_contract_valid": true,
		"policy_mode": manifest.get("policy", {}).get("policy_mode", "rules_only"),
		"model_manifest_sha256": _sha(members[MODEL_MANIFEST_PATH]) if optional.get("model_manifest") is Dictionary else null,
		"model_artifact_sha256": _sha(members[MODEL_ARTIFACT_PATH]) if optional.get("model_manifest") is Dictionary else null,
		"source_deck_id": startup_deck_manifest.get("source_deck_id"),
		"deck_card_id_domain": startup_deck_manifest.get("card_id_domain"),
		"deck_platform_scope": startup_deck_manifest.get("platform_scope", []).duplicate(true) if startup_deck_manifest.get("platform_scope", []) is Array else [],
		"deck_card_count": startup_deck_manifest.get("card_count"),
	}
	if execution_trusted:
		metadata["signature_key_id"] = signature.get("key_id")
		metadata["signature_scope"] = signature_key.get("scope")
	if registered_developer:
		metadata["server_competition_candidate"] = deck_policy.get(
			"server_competition_candidate", {}
		).duplicate(true)
	var result := {"ok": true, "error_code": "", "metadata": metadata.duplicate(true)}
	if include_match_payloads:
		var payloads := {}
		for path in REQUIRED_PAYLOAD_PATHS:
			var payload_bytes: PackedByteArray = members[path]
			payloads[path] = payload_bytes.duplicate()
		if members.has("policy/weights.bin"):
			var weights: PackedByteArray = members["policy/weights.bin"]
			payloads["policy/weights.bin"] = weights.duplicate()
		for model_path in [MODEL_MANIFEST_PATH, MODEL_ARTIFACT_PATH]:
			if members.has(model_path):
				var model_payload: PackedByteArray = members[model_path]
				payloads[model_path] = model_payload.duplicate()
		result["payloads"] = payloads
	return result


func _strict_document(value: PackedByteArray, kind: String, code: String) -> Dictionary:
	var parsed: Dictionary = CabtJsonTreeScript.canonicalize_artifact_json_bytes(value, {
		"max_input_bytes": int(_limits.get("max_json_bytes", 0)),
		"max_output_bytes": int(_limits.get("max_json_bytes", 0)),
		"max_depth": 128,
		"max_nodes": 100000,
	})
	if not bool(parsed.get("ok", false)):
		return _error(code)
	var document: Variant = JSON.parse_string(str(parsed.get("text", "")))
	document = _coerce_integral_numbers(document)
	if not document is Dictionary or not _validate_document_shape(document, kind):
		return _error(code)
	return {"ok": true, "error_code": "", "value": document, "canonical_bytes": parsed.get("bytes", PackedByteArray())}


func _validate_document_shape(document: Dictionary, kind: String) -> bool:
	match kind:
		"strategy_package":
			return _valid_strategy_manifest(document)
		"files_manifest":
			return _valid_files_manifest(document)
		"signature":
			return _valid_signature(document)
		"deck_manifest":
			return _valid_deck_manifest(document)
		"policy_ir":
			return _valid_policy_ir_shape(document)
		"adapter":
			return _valid_adapter_shape(document)
		"config":
			return _valid_config_shape(document)
		"model_manifest":
			return _valid_model_manifest(document)
	return false


func _valid_strategy_manifest(value: Dictionary) -> bool:
	if not _exact_keys(value, ["document_type", "schema_version", "package_id", "package_version", "author", "strategy", "deck", "policy", "compatibility", "presentation"]): return false
	var is_v2: bool = value.get("document_type") == "strategy_package_v2" and value.get("schema_version") == 2
	if not is_v2 and (value.get("document_type") != "strategy_package_v1" or value.get("schema_version") != 1): return false
	if not _valid_id(value.get("package_id")) or not _valid_semver(value.get("package_version")): return false
	var author: Variant = value.get("author")
	var strategy: Variant = value.get("strategy")
	var deck: Variant = value.get("deck")
	var policy: Variant = value.get("policy")
	var compatibility: Variant = value.get("compatibility")
	var presentation: Variant = value.get("presentation")
	if not author is Dictionary or not _exact_keys(author, ["author_id", "display_name"]): return false
	if not _valid_id(author.get("author_id")) or not _bounded_string(author.get("display_name"), 1, 120): return false
	if not strategy is Dictionary or not _exact_keys(strategy, ["display_name", "summary"]): return false
	if not _bounded_string(strategy.get("display_name"), 1, 120) or not _bounded_string(strategy.get("summary"), 1, 512): return false
	if not deck is Dictionary or not _exact_keys(deck, ["display_name", "manifest_path", "deck_path"]): return false
	if not _bounded_string(deck.get("display_name"), 1, 120) or deck.get("manifest_path") != "deck/deck_manifest.json" or deck.get("deck_path") != "deck/deck.csv": return false
	var policy_keys := ["entry_kind", "ir_path", "adapter_path", "config_path", "weights_path"]
	if is_v2:
		policy_keys.append_array(["policy_mode", "model_manifest_path", "model_artifact_path"])
	if not policy is Dictionary or not _exact_keys(policy, policy_keys): return false
	if policy.get("entry_kind") != "restricted_policy_ir_v1" or policy.get("ir_path") != "policy/policy_ir.json" or policy.get("adapter_path") != "policy/adapter.json" or policy.get("config_path") != "policy/config.json": return false
	if is_v2:
		if policy.get("weights_path") != null or policy.get("policy_mode") not in ["rules_only", "rules_with_model"]: return false
		if policy.get("policy_mode") == "rules_only" and (policy.get("model_manifest_path") != null or policy.get("model_artifact_path") != null): return false
		if policy.get("policy_mode") == "rules_with_model" and (policy.get("model_manifest_path") != MODEL_MANIFEST_PATH or policy.get("model_artifact_path") != MODEL_ARTIFACT_PATH): return false
	elif policy.get("weights_path") != null and policy.get("weights_path") != "policy/weights.bin": return false
	if not compatibility is Dictionary or not _exact_keys(compatibility, ["minimum_game_api", "cabt_contract_sha256", "card_catalog_sha256", "base_executor_sha256", "required_capabilities"]): return false
	for key in ["cabt_contract_sha256", "card_catalog_sha256", "base_executor_sha256"]:
		if not _is_sha(compatibility.get(key)): return false
	var capabilities: Variant = compatibility.get("required_capabilities")
	var expected_game_api := "ptcgdap-author-host-v2" if is_v2 else "ptcgdap-author-host-v1"
	if compatibility.get("minimum_game_api") != expected_game_api or not capabilities is Array or capabilities.size() > 16: return false
	var seen := {}
	for capability in capabilities:
		if not _valid_slug(capability, 1, 64, true) or seen.has(capability): return false
		seen[capability] = true
	if not presentation is Dictionary or not _exact_keys(presentation, ["icon_path", "banner_path"]): return false
	if presentation.get("icon_path") != null and presentation.get("icon_path") not in ["assets/icon.png", "assets/icon.webp"]: return false
	if presentation.get("banner_path") != null and presentation.get("banner_path") not in ["assets/banner.png", "assets/banner.webp"]: return false
	return true


func _valid_model_manifest(value: Dictionary) -> bool:
	if not _exact_keys(value, ["document_type", "schema_version", "model_id", "artifact", "runtime", "operator_profile", "tensor_profile", "contract_hashes", "resource_limits", "provenance"]): return false
	if value.get("document_type") != "ptcgai_model_manifest_v1" or value.get("schema_version") != 1 or not _valid_id(value.get("model_id")): return false
	var artifact: Variant = value.get("artifact")
	if not artifact is Dictionary or not _exact_keys(artifact, ["path", "format", "sha256", "bytes", "external_data"]): return false
	if artifact.get("path") != MODEL_ARTIFACT_PATH or artifact.get("format") != "ort" or not _is_sha(artifact.get("sha256")) or typeof(artifact.get("bytes")) != TYPE_INT or int(artifact.get("bytes")) < 1 or int(artifact.get("bytes")) > 8388608 or artifact.get("external_data") != false: return false
	var runtime: Variant = value.get("runtime")
	if not runtime is Dictionary or runtime != {"engine":"onnxruntime", "minimum_version":"1.26.0", "execution_provider":"CPUExecutionProvider", "intra_op_threads":1, "inter_op_threads":1, "custom_ops":false, "remote_inference":false, "dynamic_download":false, "stateful":false}: return false
	var operators: Variant = value.get("operator_profile")
	if not operators is Dictionary or operators != {"profile_id":"ptcgai-actor-ort-cpu-v1", "opset":18, "allowed_ops":MODEL_ALLOWED_OPS}: return false
	var tensor: Variant = value.get("tensor_profile")
	if not tensor is Dictionary or tensor.get("profile_id") != "competitive_public_actor_i32_v1" or tensor.get("max_options") != 1024 or tensor.get("frame_width") != 24 or tensor.get("option_width") != 16: return false
	var hashes: Variant = value.get("contract_hashes")
	if not hashes is Dictionary or hashes != {"cabt_contract_sha256":CABT_CONTRACT_SHA256, "card_catalog_sha256":CARD_CATALOG_SHA256, "tensor_profile_sha256":MODEL_TENSOR_PROFILE_SHA256}: return false
	var limits: Variant = value.get("resource_limits")
	if not limits is Dictionary or limits != {"max_artifact_bytes":8388608, "max_options":1024, "decision_timeout_ms":25, "cpu_only":true}: return false
	var provenance: Variant = value.get("provenance")
	return provenance is Dictionary and _exact_keys(provenance, ["training_method", "source_run_id", "authoritative"]) and provenance.get("training_method") in ["bc", "rl", "bc_rl", "hybrid", "other"] and _bounded_string(provenance.get("source_run_id"), 1, 128) and provenance.get("authoritative") == false


func _valid_files_manifest(value: Dictionary) -> bool:
	if not _exact_keys(value, ["document_type", "schema_version", "files"]) or value.get("document_type") != "files_sha256_v1" or value.get("schema_version") != 1: return false
	var files: Variant = value.get("files")
	if not files is Array or files.size() < 8 or files.size() > 13: return false
	for entry in files:
		if not entry is Dictionary or not _exact_keys(entry, ["path", "kind", "bytes", "sha256"]): return false
		if not _valid_manifest_path(entry.get("path")) or entry.get("kind") not in ["json", "text", "csv", "weights", "png", "webp"]: return false
		if typeof(entry.get("bytes")) != TYPE_INT or int(entry.get("bytes")) < 0 or int(entry.get("bytes")) > MAX_SAFE_INTEGER or not _is_sha(entry.get("sha256")): return false
	return true


func _valid_signature(value: Dictionary) -> bool:
	return _exact_keys(value, ["document_type", "schema_version", "algorithm", "key_id", "signed_payload_sha256", "signature_base64"]) and value.get("document_type") == "signature_v1" and value.get("schema_version") == 1 and value.get("algorithm") == "ed25519" and _valid_id(value.get("key_id")) and _is_sha(value.get("signed_payload_sha256")) and _valid_base64_signature(value.get("signature_base64"))


func _valid_deck_manifest(value: Dictionary) -> bool:
	if value.get("document_type") == "deck_manifest_windows_local_v1":
		return _valid_windows_local_deck_manifest(value)
	return _exact_keys(value, ["document_type", "schema_version", "deck_id", "card_id_domain", "card_count", "deck_csv_sha256", "cabt_exportable"]) and value.get("document_type") == "deck_manifest_v1" and value.get("schema_version") == 1 and _valid_id(value.get("deck_id")) and value.get("card_id_domain") == "official_cabt_card_id" and value.get("card_count") == 60 and _is_sha(value.get("deck_csv_sha256")) and typeof(value.get("cabt_exportable")) == TYPE_BOOL


func _valid_windows_local_deck_manifest(value: Dictionary) -> bool:
	if not _exact_keys(value, ["document_type", "schema_version", "deck_id", "card_id_domain", "card_count", "unique_card_count", "deck_csv_sha256", "cabt_exportable", "platform_scope", "source_deck_id", "source_deck_raw_sha256", "source_deck_canonical_sha256", "cards"]): return false
	if value.get("document_type") != "deck_manifest_windows_local_v1" or value.get("schema_version") != 1 or not _valid_id(value.get("deck_id")) or value.get("card_id_domain") != WINDOWS_LOCAL_DECK_DOMAIN or value.get("card_count") != 60 or value.get("cabt_exportable") != false or value.get("platform_scope") != ["windows"]: return false
	if typeof(value.get("unique_card_count")) != TYPE_INT or int(value.get("unique_card_count")) < 1 or int(value.get("unique_card_count")) > 60 or typeof(value.get("source_deck_id")) != TYPE_INT or int(value.get("source_deck_id")) < 1 or int(value.get("source_deck_id")) > MAX_SAFE_INTEGER: return false
	if not _is_sha(value.get("deck_csv_sha256")) or not _is_sha(value.get("source_deck_raw_sha256")) or not _is_sha(value.get("source_deck_canonical_sha256")): return false
	var cards: Variant = value.get("cards")
	if not cards is Array or cards.size() != int(value.get("unique_card_count")): return false
	var seen := {}
	var previous := ""
	var total := 0
	var basic_pokemon := 0
	for entry_value in cards:
		if not entry_value is Dictionary: return false
		var entry: Dictionary = entry_value
		if not _exact_keys(entry, ["local_card_uid", "set_code", "card_index", "count", "card_type", "stage", "effect_id", "source_raw_sha256", "source_canonical_sha256"]): return false
		var uid := str(entry.get("local_card_uid", ""))
		var set_code := str(entry.get("set_code", ""))
		var card_index := str(entry.get("card_index", ""))
		if uid != "%s_%s" % [set_code, card_index] or not _valid_local_uid(uid) or not _valid_local_component(set_code, true) or not _valid_local_component(card_index, false) or seen.has(uid) or (not previous.is_empty() and uid <= previous): return false
		if typeof(entry.get("count")) != TYPE_INT or int(entry.get("count")) < 1 or int(entry.get("count")) > 60 or not _bounded_string(entry.get("card_type"), 1, 32) or not _bounded_string(entry.get("stage"), 0, 32) or not _valid_effect_id(entry.get("effect_id")) or not _is_sha(entry.get("source_raw_sha256")) or not _is_sha(entry.get("source_canonical_sha256")): return false
		if int(entry.get("count")) > 4 and entry.get("card_type") != "Basic Energy": return false
		if entry.get("card_type") == "Pokemon" and entry.get("stage") == "Basic": basic_pokemon += int(entry.get("count"))
		total += int(entry.get("count")); seen[uid] = true; previous = uid
	return total == 60 and basic_pokemon > 0


func _valid_policy_ir_shape(value: Dictionary) -> bool:
	if not _exact_keys(value, ["schema_version", "profile_id", "graph_id", "entry_node_id", "required_capabilities", "nodes"]): return false
	if value.get("schema_version") != 1 or value.get("profile_id") != "ptcgdap-restricted-base-graph-ir-p4-wp2-v1" or not _valid_id(value.get("graph_id")) or not _bounded_string(value.get("entry_node_id"), 1, 64): return false
	var capabilities: Variant = value.get("required_capabilities")
	var nodes: Variant = value.get("nodes")
	if not capabilities is Array or capabilities.size() < 4 or capabilities.size() > 16 or not nodes is Array or nodes.size() < 6 or nodes.size() > 256: return false
	var seen_capabilities := {}
	for capability in capabilities:
		if not _bounded_string(capability, 1, 64) or seen_capabilities.has(capability): return false
		seen_capabilities[capability] = true
	for node in nodes:
		if not node is Dictionary or not _exact_keys(node, ["node_id", "operator", "owner", "config", "next_node_ids"]): return false
		if not _bounded_string(node.get("node_id"), 1, 64) or not _bounded_string(node.get("operator"), 1, 64) or node.get("owner") not in ["base", "adapter"] or not node.get("config") is Dictionary or not node.get("next_node_ids") is Array or node.get("next_node_ids").size() > 1: return false
		for next_node_id in node.get("next_node_ids"):
			if not _bounded_string(next_node_id, 1, 64): return false
	return true


func _valid_adapter_shape(value: Dictionary) -> bool:
	if value.get("schema_version") == 2:
		var allowed_uids := _competitive_v2_candidate_uids(value)
		if allowed_uids.is_empty():
			return false
		return bool(CompetitivePolicyV2Script.compile_local_uid(value, allowed_uids).get("accepted", false))
	if not _exact_keys(value, ["schema_version", "adapter_id", "adapter_version", "rules"]) or value.get("schema_version") != 1 or not _valid_id(value.get("adapter_id")) or typeof(value.get("adapter_version")) != TYPE_INT or int(value.get("adapter_version")) < 1 or int(value.get("adapter_version")) > MAX_SAFE_INTEGER or not value.get("rules") is Array or value.get("rules").size() > 256: return false
	for rule in value.get("rules"):
		if not rule is Dictionary: return false
	return true


func _valid_config_shape(value: Dictionary) -> bool:
	if not _exact_keys(value, ["document_type", "schema_version", "config_profile_id", "values"]) or value.get("document_type") != "author_policy_config_v1" or value.get("schema_version") != 1 or value.get("config_profile_id") != "ptcgdap-author-policy-config-v1" or not value.get("values") is Dictionary: return false
	var config_values: Dictionary = value.get("values")
	if config_values.size() > 128: return false
	for key in config_values:
		if not _valid_config_key(key) or not _valid_config_value(config_values[key]): return false
	return true


func _validate_kind_sizes(members: Dictionary) -> Dictionary:
	var per_kind := {"json": _limits.get("max_json_bytes"), "text": _limits.get("max_text_bytes"), "csv": _limits.get("max_csv_bytes"), "weights": _limits.get("max_weights_bytes"), "png": _limits.get("max_image_bytes"), "webp": _limits.get("max_image_bytes")}
	for path_value in members:
		var path := str(path_value)
		var kind: Variant = FIXED_PAYLOAD_KINDS.get(path, OPTIONAL_PAYLOAD_KINDS.get(path))
		var value: PackedByteArray = members[path]
		if kind != null and value.size() > int(per_kind.get(kind, 0)):
			return _error("package_resource_limit_exceeded")
		if kind in ["png", "webp"]:
			var dimensions := _image_dimensions(value, str(kind))
			if not bool(dimensions.get("ok", false)):
				return _error("package_policy_unsupported")
			if int(dimensions.get("width", 0)) < 1 or int(dimensions.get("height", 0)) < 1 or int(dimensions.get("width", 0)) > int(_limits.get("max_image_width", 0)) or int(dimensions.get("height", 0)) > int(_limits.get("max_image_height", 0)):
				return _error("package_resource_limit_exceeded")
	return {"ok": true, "error_code": ""}


func _verify_signature(
	manifest: Dictionary,
	signature: Dictionary,
	members: Dictionary,
	author_signature_binding: Dictionary = {}
) -> Dictionary:
	var key: Variant
	if not author_signature_binding.is_empty():
		if (
			not _valid_control_signature_binding(author_signature_binding)
			or signature.get("key_id") != author_signature_binding.get("key_id")
			or manifest.get("author", {}).get("author_id") \
			!= author_signature_binding.get("developer_id")
		):
			return _error("package_signature_untrusted")
		key = {
			"key_id": author_signature_binding.get("key_id"),
			"public_key_base64": Marshalls.raw_to_base64(
				str(author_signature_binding.get("public_key_hex", "")).hex_decode()
			),
			"scope": "developer_registered_release",
			"execution_trusted": true,
			"status": "active",
		}
	else:
		key = _trust_store.get(str(signature.get("key_id", "")))
	if not key is Dictionary:
		return _error("package_signature_untrusted")
	var is_test_key: bool = key.get("scope") == "test_fixture_only" and key.get("execution_trusted") == false
	var is_release_key: bool = key.get("scope") == "production_release" and key.get("execution_trusted") == true and key.get("status") == "active"
	var is_registered_key: bool = key.get("scope") == "developer_registered_release" and key.get("execution_trusted") == true and key.get("status") == "active"
	if not is_test_key and not is_release_key and not is_registered_key:
		return _error("package_signature_untrusted")
	var signed_payload := {"schema_version": 1, "domain": "ptcgdap-author-strategy-package-signature-v1", "package_id": manifest.get("package_id"), "package_version": manifest.get("package_version"), "manifest_sha256": _sha(members["strategy_package.json"]), "files_manifest_sha256": _sha(members["files.sha256.json"])}
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact(signed_payload)
	if not bool(canonical.get("ok", false)):
		return _error("package_signature_untrusted")
	var signed_bytes: PackedByteArray = canonical.get("bytes", PackedByteArray())
	if signature.get("signed_payload_sha256") != _sha(signed_bytes):
		return _error("package_signature_untrusted")
	var public_key := Marshalls.base64_to_raw(str(key.get("public_key_base64", "")))
	var raw_signature := Marshalls.base64_to_raw(str(signature.get("signature_base64", "")))
	if public_key.size() != 32 or raw_signature.size() != 64 or not Ed25519Script.verify(public_key, signed_bytes, raw_signature):
		return _error("package_signature_untrusted")
	return {"ok": true, "error_code": "", "key": key.duplicate(true)}


func _verify_compatibility(manifest: Dictionary) -> Dictionary:
	var compatibility: Dictionary = manifest.get("compatibility", {})
	var expected_game_api := "ptcgdap-author-host-v2" if manifest.get("document_type") == "strategy_package_v2" else "ptcgdap-author-host-v1"
	if compatibility.get("minimum_game_api") != expected_game_api or compatibility.get("cabt_contract_sha256") != CABT_CONTRACT_SHA256 or compatibility.get("base_executor_sha256") != BASE_EXECUTOR_SHA256:
		return _error("package_contract_incompatible")
	if compatibility.get("card_catalog_sha256") != CARD_CATALOG_SHA256:
		return _error("package_catalog_incompatible")
	for capability in compatibility.get("required_capabilities", []):
		if capability not in SUPPORTED_CAPABILITIES:
			return _error("package_policy_unsupported")
	return {"ok": true, "error_code": ""}


func _verify_deck_and_policy(manifest: Dictionary, members: Dictionary) -> Dictionary:
	var deck_result := _strict_document(members["deck/deck_manifest.json"], "deck_manifest", "package_deck_unmapped")
	var ir_result := _strict_document(members["policy/policy_ir.json"], "policy_ir", "package_policy_unsupported")
	var adapter_result := _strict_document(members["policy/adapter.json"], "adapter", "package_policy_unsupported")
	var config_result := _strict_document(members["policy/config.json"], "config", "package_policy_unsupported")
	for result in [deck_result, ir_result, adapter_result, config_result]:
		if not bool(result.get("ok", false)): return result
	var deck: Dictionary = deck_result.get("value", {})
	var ir: Dictionary = ir_result.get("value", {})
	var adapter: Dictionary = adapter_result.get("value", {})
	var config: Dictionary = config_result.get("value", {})
	if _contains_forbidden_key(ir) or _contains_forbidden_key(adapter) or _contains_forbidden_key(config): return _error("package_policy_unsupported")
	var csv_check := _verify_deck_csv(deck, members["deck/deck.csv"])
	if not bool(csv_check.get("ok", false)): return csv_check
	if not _restricted_ir_valid(ir) or not _public_adapter_valid(adapter, deck) or manifest.get("policy", {}).get("entry_kind") != "restricted_policy_ir_v1": return _error("package_policy_unsupported")
	if deck.get("card_id_domain") == WINDOWS_LOCAL_DECK_DOMAIN:
		var values: Variant = config.get("values")
		if not values is Dictionary or values.get("card_id_domain") != WINDOWS_LOCAL_DECK_DOMAIN or values.get("source_deck_id") != deck.get("source_deck_id") or values.get("cabt_exportable") != false:
			return _error("package_policy_unsupported")
		if values.get("deck_manifest_sha256") != _sha(members["deck/deck_manifest.json"]):
			return _error("package_deck_unmapped")
	var runtime_kind := (
		"reviewed_competitive_policy_v2"
		if adapter.get("schema_version") == 2
		else "reviewed_restricted_ir_v1"
	)
	return {
		"ok": true,
		"error_code": "",
		"server_competition_candidate": {
			"package_id": manifest.get("package_id"),
			"package_version": manifest.get("package_version"),
			"source_deck_id": deck.get("source_deck_id"),
			"unique_printing_count": deck.get("unique_card_count"),
			"adapter_rule_count": adapter.get("rules", []).size(),
			"strategy_id": "%s.v%s" % [
				str(adapter.get("adapter_id", manifest.get("package_id", ""))),
				str(adapter.get("adapter_version", 1)),
			],
			"frame_profile_id": (
				"ptcgdap-competitive-public-frame-v2"
				if adapter.get("schema_version") == 2
				else "ptcgdap-restricted-public-frame-v1"
			),
			"runtime_kind": runtime_kind,
		},
	}


func _restricted_ir_valid(document: Dictionary) -> bool:
	if document.get("required_capabilities") != REQUIRED_IR_CAPABILITIES: return false
	var nodes: Array = document.get("nodes", [])
	var ids: Array = nodes.map(func(node: Variant) -> Variant: return node.get("node_id") if node is Dictionary else null)
	var seen := {}
	for id_value in ids:
		if seen.has(id_value): return false
		seen[id_value] = true
	if ids.is_empty() or document.get("entry_node_id") != ids[0]: return false
	var base_operators: Array = []
	for index in range(nodes.size()):
		var node: Dictionary = nodes[index]
		var expected_next := [] if index + 1 == nodes.size() else [ids[index + 1]]
		if node.get("next_node_ids") != expected_next: return false
		if node.get("operator") in BASE_OPERATOR_ORDER:
			if node.get("owner") != "base": return false
			base_operators.append(node.get("operator"))
		elif node.get("operator") in ADAPTER_OPERATORS:
			if node.get("owner") != "adapter": return false
		else: return false
	return base_operators == BASE_OPERATOR_ORDER


func _public_adapter_valid(document: Dictionary, deck: Dictionary) -> bool:
	var local_domain: bool = deck.get("card_id_domain") == WINDOWS_LOCAL_DECK_DOMAIN
	var local_uids := {}
	if local_domain:
		for entry_value: Variant in deck.get("cards", []):
			if not entry_value is Dictionary or not _valid_local_uid(str(entry_value.get("local_card_uid", ""))): return false
			local_uids[str(entry_value.get("local_card_uid"))] = true
		if local_uids.size() != int(deck.get("unique_card_count", 0)): return false
	if document.get("schema_version") == 2:
		return local_domain and bool(
			CompetitivePolicyV2Script.compile_local_uid(document, local_uids.keys()).get("accepted", false)
		)
	if document.get("schema_version") != 1:
		return false
	var seen := {}
	for rule_value in document.get("rules", []):
		if not rule_value is Dictionary: return false
		var rule: Dictionary = rule_value
		if not _exact_keys(rule, ["rule_id", "operator", "reason_code", "goal_stage", "priority", "predicate"]): return false
		if not _bounded_string(rule.get("rule_id"), 1, 128) or seen.has(rule.get("rule_id")) or rule.get("operator") not in ADAPTER_OPERATORS or rule.get("reason_code") != ADAPTER_REASONS.get(rule.get("operator")) or rule.get("goal_stage") not in GOAL_STAGES: return false
		if typeof(rule.get("priority")) != TYPE_INT or int(rule.get("priority")) < 0 or int(rule.get("priority")) > MAX_SAFE_INTEGER: return false
		var predicate: Variant = rule.get("predicate")
		if not predicate is Dictionary or not _exact_keys(predicate, PREDICATE_FIELDS): return false
		for field in PREDICATE_FIELDS:
			var value: Variant = predicate.get(field)
			if value == null: continue
			if local_domain and field in CARD_PREDICATE_FIELDS:
				if typeof(value) != TYPE_STRING or not local_uids.has(str(value)): return false
			elif typeof(value) != TYPE_INT or int(value) < 0 or int(value) > MAX_SAFE_INTEGER: return false
		seen[rule.get("rule_id")] = true
	return true


func _competitive_v2_candidate_uids(document: Dictionary) -> Array:
	var found := {}
	for goal_value: Variant in document.get("goals", []):
		if not goal_value is Dictionary:
			continue
		for requirement_value: Variant in goal_value.get("requirements", []):
			if not requirement_value is Dictionary:
				continue
			if _valid_local_uid(str(requirement_value.get("card_uid", ""))):
				found[str(requirement_value.get("card_uid"))] = true
			for typed_value: Variant in requirement_value.get("energy_requirements", []):
				if typed_value is Dictionary and _valid_local_uid(str(typed_value.get("energy_uid", ""))):
					found[str(typed_value.get("energy_uid"))] = true
	for collection_name: String in ["count_rules", "rules"]:
		for rule_value: Variant in document.get(collection_name, []):
			if not rule_value is Dictionary:
				continue
			for condition_value: Variant in rule_value.get("when", []):
				if not condition_value is Dictionary:
					continue
				for field: String in ["card_uid", "value"]:
					var uid: Variant = condition_value.get(field)
					if typeof(uid) == TYPE_STRING and _valid_local_uid(str(uid)):
						found[str(uid)] = true
	return found.keys()


func _verify_deck_csv(deck: Dictionary, value: PackedByteArray) -> Dictionary:
	if deck.get("deck_csv_sha256") != _sha(value): return _error("package_deck_unmapped")
	var text := value.get_string_from_ascii()
	if text.to_ascii_buffer() != value or not text.ends_with("\n") or text.contains("\r"): return _error("package_deck_unmapped")
	var lines := text.trim_suffix("\n").split("\n", false)
	if deck.get("card_id_domain") == WINDOWS_LOCAL_DECK_DOMAIN:
		return _verify_windows_local_deck_csv(deck, lines)
	if lines.size() < 2 or lines[0] != "card_id,count": return _error("package_deck_unmapped")
	var total := 0
	var previous := -1
	var seen := {}
	for index in range(1, lines.size()):
		var columns := str(lines[index]).split(",", true)
		if columns.size() != 2 or not str(columns[0]).is_valid_int() or not str(columns[1]).is_valid_int(): return _error("package_deck_unmapped")
		if (str(columns[0]).length() > 1 and str(columns[0]).begins_with("0")) or (str(columns[1]).length() > 1 and str(columns[1]).begins_with("0")): return _error("package_deck_unmapped")
		var card_id := int(columns[0]); var count := int(columns[1])
		if card_id < 0 or card_id > MAX_SAFE_INTEGER or count < 1 or count > 60 or seen.has(card_id) or card_id <= previous: return _error("package_deck_unmapped")
		seen[card_id] = true; previous = card_id; total += count
	if total != 60 or deck.get("card_count") != 60: return _error("package_deck_unmapped")
	return {"ok": true, "error_code": ""}


func _verify_windows_local_deck_csv(deck: Dictionary, lines: PackedStringArray) -> Dictionary:
	if lines.size() < 2 or lines[0] != "local_card_uid,count" or not deck.get("cards") is Array: return _error("package_deck_unmapped")
	var rows: Array = []
	var previous := ""
	var total := 0
	for index in range(1, lines.size()):
		var columns := str(lines[index]).split(",", true)
		if columns.size() != 2 or not _valid_local_uid(str(columns[0])) or not _ascii_digits(str(columns[1])): return _error("package_deck_unmapped")
		if str(columns[1]).length() > 1 and str(columns[1]).begins_with("0"): return _error("package_deck_unmapped")
		var uid := str(columns[0]); var count := int(columns[1])
		if (not previous.is_empty() and uid <= previous) or count < 1 or count > 60: return _error("package_deck_unmapped")
		rows.append({"local_card_uid": uid, "count": count}); previous = uid; total += count
	var cards: Array = deck.get("cards")
	if rows.size() != cards.size() or rows.size() != int(deck.get("unique_card_count", 0)) or total != 60 or deck.get("card_count") != 60: return _error("package_deck_unmapped")
	for index in range(rows.size()):
		var card: Variant = cards[index]
		if not card is Dictionary or rows[index] != {"local_card_uid": card.get("local_card_uid"), "count": card.get("count")}: return _error("package_deck_unmapped")
	return {"ok": true, "error_code": ""}


func _verify_optional_relations(manifest: Dictionary, members: Dictionary) -> Dictionary:
	var expected := {}
	var weights: Variant = manifest.get("policy", {}).get("weights_path")
	if weights != null: expected[weights] = true
	for key in ["icon_path", "banner_path"]:
		var path: Variant = manifest.get("presentation", {}).get(key)
		if path != null: expected[path] = true
	var model_manifest: Variant = null
	if manifest.get("document_type") == "strategy_package_v2" and manifest.get("policy", {}).get("policy_mode") == "rules_with_model":
		expected[MODEL_MANIFEST_PATH] = true
		expected[MODEL_ARTIFACT_PATH] = true
		if "learned_policy_head_v1" not in manifest.get("compatibility", {}).get("required_capabilities", []): return _error("package_policy_unsupported")
		var model_result := _strict_document(members.get(MODEL_MANIFEST_PATH, PackedByteArray()), "model_manifest", "model_manifest_invalid")
		if not bool(model_result.get("ok", false)): return model_result
		model_manifest = model_result.get("value")
		var artifact: PackedByteArray = members.get(MODEL_ARTIFACT_PATH, PackedByteArray())
		if artifact.is_empty() or artifact.size() > 8388608: return _error("model_resource_limit_exceeded")
		if model_manifest.get("artifact", {}).get("sha256") != _sha(artifact) or model_manifest.get("artifact", {}).get("bytes") != artifact.size(): return _error("model_artifact_hash_mismatch")
	var actual := {}
	for path in OPTIONAL_PAYLOAD_KINDS:
		if members.has(path): actual[path] = true
	for path in expected:
		if not actual.has(path): return _error("package_file_missing")
	for path in actual:
		if not expected.has(path): return _error("package_file_unlisted")
	return {"ok": true, "error_code": "", "model_manifest": model_manifest}


func _contains_forbidden_key(root: Variant) -> bool:
	var stack: Array = [root]
	while not stack.is_empty():
		var current: Variant = stack.pop_back()
		if current is Dictionary:
			for key in current:
				if str(key).to_lower() in FORBIDDEN_POLICY_KEYS: return true
				stack.append(current[key])
		elif current is Array:
			stack.append_array(current)
	return false


func _coerce_integral_numbers(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	if value is Array:
		var result: Array = []
		for child in value:
			result.append(_coerce_integral_numbers(child))
		return result
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = _coerce_integral_numbers(value[key])
		return result
	return value


func _image_dimensions(value: PackedByteArray, kind: String) -> Dictionary:
	if kind == "png":
		if value.size() < 24 or value.slice(0, 8) != PackedByteArray([137,80,78,71,13,10,26,10]) or value.slice(12, 16).get_string_from_ascii() != "IHDR": return _error("invalid_image")
		return {"ok": true, "width": _be(value, 16, 4), "height": _be(value, 20, 4)}
	if value.size() < 30 or value.slice(0, 4).get_string_from_ascii() != "RIFF" or value.slice(8, 12).get_string_from_ascii() != "WEBP": return _error("invalid_image")
	var chunk := value.slice(12, 16).get_string_from_ascii()
	if chunk == "VP8X": return {"ok": true, "width": 1 + _le(value, 24, 3), "height": 1 + _le(value, 27, 3)}
	if chunk == "VP8 " and value.size() >= 30 and value.slice(23, 26) == PackedByteArray([157,1,42]): return {"ok": true, "width": _le(value, 26, 2) & 0x3FFF, "height": _le(value, 28, 2) & 0x3FFF}
	if chunk == "VP8L" and value.size() >= 25 and value[20] == 0x2F:
		return {"ok": true, "width": 1 + value[21] + ((value[22] & 0x3F) << 8), "height": 1 + ((value[22] & 0xC0) >> 6) + (value[23] << 2) + ((value[24] & 0x0F) << 10)}
	return _error("invalid_image")


func _exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size(): return false
	for key in keys:
		if not value.has(key): return false
	return true


func _valid_id(value: Variant) -> bool:
	return _valid_slug(value, 3, 128, false)


func _valid_slug(value: Variant, minimum: int, maximum: int, underscores: bool) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() < minimum or str(value).length() > maximum: return false
	var text := str(value)
	for index in range(text.length()):
		var character := text.substr(index, 1)
		var code := character.unicode_at(0)
		var valid := (code >= 48 and code <= 57) or (code >= 97 and code <= 122) or character in (["-", "_"] if underscores else ["-", "."])
		if not valid or ((index == 0 or index == text.length() - 1) and not ((code >= 48 and code <= 57) or (code >= 97 and code <= 122))): return false
	return true


func _valid_semver(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).is_empty() or str(value).length() > 64: return false
	var text := str(value)
	var hyphen := text.find("-")
	var main := text if hyphen < 0 else text.substr(0, hyphen)
	if hyphen >= 0:
		var prerelease := text.substr(hyphen + 1)
		if prerelease.is_empty(): return false
		for character in prerelease:
			var code := character.unicode_at(0)
			if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or character in [".", "-"]): return false
	var parts := main.split(".", true)
	if parts.size() != 3: return false
	for part in parts:
		if not _ascii_digits(str(part)) or (str(part).length() > 1 and str(part).begins_with("0")): return false
	return true


func _ascii_digits(value: String) -> bool:
	if value.is_empty(): return false
	for character in value:
		var code := character.unicode_at(0)
		if code < 48 or code > 57: return false
	return true


func _valid_local_uid(value: String) -> bool:
	if value.count("_") != 1 or value.length() < 3 or value.length() > 64:
		return false
	var parts := value.split("_", true)
	return parts.size() == 2 and _valid_local_component(str(parts[0]), true) and _valid_local_component(str(parts[1]), false)


func _valid_local_component(value: String, allow_dot: bool) -> bool:
	if value.is_empty() or value.length() > 32:
		return false
	for character in value:
		var code := character.unicode_at(0)
		if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or (allow_dot and character == ".")):
			return false
	return true


func _valid_effect_id(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 32:
		return false
	for character in str(value):
		if character not in "0123456789abcdef":
			return false
	return true


func _valid_manifest_path(value: Variant) -> bool:
	if not _bounded_string(value, 1, 128): return false
	var segments := str(value).split("/", true)
	for segment in segments:
		if str(segment).is_empty(): return false
		for index in range(str(segment).length()):
			var character := str(segment).substr(index, 1)
			var code := character.unicode_at(0)
			var alphanumeric := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
			if (index == 0 and not alphanumeric) or (index > 0 and not alphanumeric and character not in [".", "_", "-"]): return false
	return true


func _valid_config_key(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).is_empty() or str(value).length() > 64: return false
	for index in range(str(value).length()):
		var code := str(value).unicode_at(index)
		if (index == 0 and (code < 97 or code > 122)) or (index > 0 and not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95)): return false
	return true


func _valid_config_value(value: Variant) -> bool:
	if value == null or typeof(value) == TYPE_BOOL: return true
	if typeof(value) == TYPE_STRING: return str(value).length() <= 256
	if typeof(value) == TYPE_INT: return int(value) >= -MAX_SAFE_INTEGER and int(value) <= MAX_SAFE_INTEGER
	return false


func _bounded_string(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) == TYPE_STRING and str(value).length() >= minimum and str(value).length() <= maximum


func _is_sha(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 64: return false
	for character in str(value):
		if character not in "0123456789ABCDEF": return false
	return true


func _valid_control_signature_binding(value: Variant) -> bool:
	if not value is Dictionary or not _exact_keys(value, [
		"developer_id", "document_type", "fingerprint_sha256", "key_id",
		"public_key_hex", "schema_version",
	]):
		return false
	var binding: Dictionary = value
	var public_key_hex := str(binding.get("public_key_hex", ""))
	if (
		binding.get("document_type") != "control_developer_signing_binding_v1"
		or binding.get("schema_version") != 1
		or not _valid_id(binding.get("developer_id"))
		or not _valid_id(binding.get("key_id"))
		or public_key_hex.length() != 64
		or not _is_sha(binding.get("fingerprint_sha256"))
	):
		return false
	for character in public_key_hex:
		if character not in "0123456789abcdef":
			return false
	var public_key := public_key_hex.hex_decode()
	return (
		public_key.size() == 32
		and _sha(public_key) == binding.get("fingerprint_sha256")
	)


func _server_competition_authorized() -> bool:
	return (
		OS.get_name() == "Linux"
		and OS.has_feature("dedicated_server")
		and OS.get_environment("PTCGDAP_GODOT_V18_SERVER_COMPETITION") == "enabled"
		and OS.get_environment("PTCGDAP_COMPETITION_NETWORK") == "disabled"
	)


func _valid_base64_signature(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 88 or not str(value).ends_with("=="): return false
	for index in range(86):
		if str(value).substr(index, 1) not in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/": return false
	return true


func _sorted_strings(values: Array[String]) -> Array[String]:
	var result := values.duplicate(); result.sort(); return result


func _sha(value: PackedByteArray) -> String:
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(value); return context.finish().hex_encode().to_upper()


func _le(value: PackedByteArray, offset: int, count: int) -> int:
	var result := 0
	for index in range(count): result |= int(value[offset + index]) << (8 * index)
	return result


func _be(value: PackedByteArray, offset: int, count: int) -> int:
	var result := 0
	for index in range(count): result = (result << 8) | int(value[offset + index])
	return result


func _error(code: String) -> Dictionary:
	return {"ok": false, "error_code": code}
