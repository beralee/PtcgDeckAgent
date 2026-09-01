class_name PublicPolicyBudgetCore
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const CabtSelectionWindowScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd")
const CabtDeterministicFallbackScript = preload("res://scripts/ai/ptcgdap/cabt/CabtDeterministicFallback.gd")
const PublicObservationFirewallScript = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")

const DEFAULT_ROOT := "res://contracts/ptcgdap"
const PROFILE_ID := "ptcgdap-public-policy-budget-p4-wp6-v1"
const EXPECTED_BUNDLE_SHA256 := "0D82BDE31BD0FA0C44527880D9D6451C2733702913708532C512F3BFF81D8BF9"
const EXPECTED_PARENT_BUNDLE_SHA256 := "18AAB663D9B429AC8657A75692F5DD8CF37C409CC057A328B57758C692FDB7F4"
const EXPECTED_SOURCE_LOCK_SHA256 := "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
const EXPECTED_ARTIFACT_NAMES := [
	"public_policy_budget.schema.json",
	"public_policy_budget_profile.json",
	"public_policy_budget_conformance_vectors.json",
]
const EXPECTED_ARTIFACTS := {
	"public_policy_budget.schema.json": "580A410176600BA9BD0206B5035BF50A5A33D4FC14298DDC2AE699C2DF9215C7",
	"public_policy_budget_profile.json": "F70C5172F2E1286E16E142B9026532AADB5C34CFDC5E8B796F1E404FA3A83632",
	"public_policy_budget_conformance_vectors.json": "A9DF2CF48CA8BC675583B27C5E3741ABA4FA296C98ADD8106795902DD4C8EB6E",
}
const TOTAL_BUDGET_MS := 600000
const BASE_ONLY_THRESHOLD_MS := 30000
const FALLBACK_THRESHOLD_MS := 5000
const MAX_SAFE_INTEGER := 9007199254740991
const MAX_CONTRACT_BYTES := 2 * 1024 * 1024
const MAX_VALUE_BYTES := 1024 * 1024
const REQUIRED_CAPABILITIES := [
	"public_base_policy_v1",
	"current_window_sanitizer_v1",
	"deterministic_base_fallback_v1",
]
const OPTIONAL_CAPABILITIES := [
	"public_deck_adapter_v1",
	"learned_policy_head_v1",
	"search_v1",
]
const CAPABILITY_STATES := ["available", "unavailable", "unsupported"]
const MODES := ["full", "base_only", "deterministic_fallback"]
const LEDGER_PREFIX_UTF8_HEX := "50544347444150005055424C49435F504F4C4943595F4255444745545F4C45444745525F563100"
const TELEMETRY_PREFIX_UTF8_HEX := "50544347444150005055424C49435F504F4C4943595F4255444745545F54454C454D455452595F563100"
const RESULT_PREFIX_UTF8_HEX := "50544347444150005055424C49435F504F4C4943595F4255444745545F524553554C545F563100"

static var _LEDGER_TOKEN: RefCounted = RefCounted.new()
static var _RESULT_TOKEN: RefCounted = RefCounted.new()
static var _LEDGER_REGISTRY: Array = []
static var _RESULT_REGISTRY: Array = []


class StepOutcome extends RefCounted:
	var accepted := false
	var error_code := "contract_error"
	var result: Variant = null

	func _init(accepted_value: bool, error_value: String, result_value: Variant = null) -> void:
		accepted = accepted_value
		error_code = error_value
		result = result_value


class LedgerValue extends RefCounted:
	var _snapshot: Variant = {}
	var _factory_token: Variant = null

	var ledger_hash: String:
		get:
			var owner: GDScript = load("res://scripts/ai/ptcgdap/public/PublicPolicyBudget.gd")
			return str(_snapshot.get("ledger_hash", "")) if bool(owner.call("validate_ledger", self)) else ""

	var remaining_ms: int:
		get:
			var owner: GDScript = load("res://scripts/ai/ptcgdap/public/PublicPolicyBudget.gd")
			return int(_snapshot.get("remaining_ms", 0)) if bool(owner.call("validate_ledger", self)) else 0

	func _init(snapshot_value: Dictionary = {}, token_value: Variant = null) -> void:
		_snapshot = snapshot_value.duplicate(true)
		_factory_token = token_value

	func validate_integrity() -> bool:
		var owner: GDScript = load("res://scripts/ai/ptcgdap/public/PublicPolicyBudget.gd")
		return bool(owner.call("validate_ledger", self))

	func to_public_dict() -> Dictionary:
		var owner: GDScript = load("res://scripts/ai/ptcgdap/public/PublicPolicyBudget.gd")
		return owner.call("ledger_public_dict", self)


class ResultValue extends RefCounted:
	var _snapshot: Variant = {}
	var _factory_token: Variant = null
	var _ledger_binding: Variant = null
	var _window_binding: Variant = null
	var _elapsed_ms: Variant = null
	var _capabilities: Variant = {}
	var _fallback_binding: Variant = null
	var _next_ledger_binding: Variant = null

	var mode: String:
		get:
			var owner: GDScript = load("res://scripts/ai/ptcgdap/public/PublicPolicyBudget.gd")
			return str(_snapshot.get("mode", "")) if bool(owner.call("validate_result", self, _ledger_binding, _window_binding)) else ""

	var selected_indexes: Array:
		get:
			var owner: GDScript = load("res://scripts/ai/ptcgdap/public/PublicPolicyBudget.gd")
			return _snapshot.get("selected_indexes", []).duplicate(true) if bool(owner.call("validate_result", self, _ledger_binding, _window_binding)) else []

	var next_ledger: Variant:
		get:
			var owner: GDScript = load("res://scripts/ai/ptcgdap/public/PublicPolicyBudget.gd")
			return _next_ledger_binding if bool(owner.call("validate_result", self, _ledger_binding, _window_binding)) else null

	func _init(snapshot_value: Dictionary = {}, bindings: Dictionary = {}, token_value: Variant = null) -> void:
		_snapshot = snapshot_value.duplicate(true)
		_factory_token = token_value
		_ledger_binding = bindings.get("ledger")
		_window_binding = bindings.get("window")
		_elapsed_ms = bindings.get("elapsed_ms")
		_capabilities = bindings.get("capabilities", {}).duplicate(true)
		_fallback_binding = bindings.get("fallback")
		_next_ledger_binding = bindings.get("next_ledger")

	func validate_integrity(ledger: Variant, window: Variant) -> bool:
		var owner: GDScript = load("res://scripts/ai/ptcgdap/public/PublicPolicyBudget.gd")
		return bool(owner.call("validate_result", self, ledger, window))

	func to_public_dict() -> Dictionary:
		var owner: GDScript = load("res://scripts/ai/ptcgdap/public/PublicPolicyBudget.gd")
		return owner.call("result_public_dict", self)


static func start_ledger(ledger_id: Variant, contract_root: Variant = DEFAULT_ROOT) -> Variant:
	if typeof(contract_root) != TYPE_STRING or not _load_contracts(str(contract_root)).get("ok", false):
		return null
	if not _identifier(ledger_id):
		return null
	return _new_ledger(_ledger_payload(str(ledger_id), 0, TOTAL_BUDGET_MS, 0, null))


static func step(
	ledger: Variant,
	window: Variant,
	elapsed_ms: Variant,
	capabilities: Variant,
	contract_root: Variant = DEFAULT_ROOT,
) -> StepOutcome:
	if typeof(contract_root) != TYPE_STRING or not _load_contracts(str(contract_root)).get("ok", false):
		return _failure("contract_error")
	if not validate_ledger(ledger):
		return _failure("invalid_ledger")
	if not _window_valid(window):
		return _failure("invalid_window")
	if not _nonnegative_safe_int(elapsed_ms):
		return _failure("invalid_elapsed_ms")
	if not _capability_error(capabilities).is_empty():
		return _failure("invalid_capability_report")
	var capability_value: Dictionary = capabilities.duplicate(true)
	var ledger_value: Dictionary = ledger_public_dict(ledger)
	var charged: int = mini(int(elapsed_ms), int(ledger_value.remaining_ms))
	var remaining: int = int(ledger_value.remaining_ms) - charged
	var classification := _classification(remaining, capability_value)
	var fallback: Variant = null
	var selected: Array = []
	if classification.mode == "deterministic_fallback":
		fallback = CabtDeterministicFallbackScript.resolve(window, "policy_unavailable")
		if fallback == null or not CabtDeterministicFallbackScript.validate_resolution_integrity(fallback, window):
			return _failure("invalid_window")
		selected = fallback.selected_indexes
	var built := _result_payload(ledger, window, int(elapsed_ms), capability_value, selected)
	if built.is_empty():
		return _failure("result_integrity_invalid")
	var next_ledger: Variant = _new_ledger(built.next_ledger)
	if next_ledger == null:
		return _failure("result_integrity_invalid")
	var bindings := {
		"ledger": ledger,
		"window": window,
		"elapsed_ms": elapsed_ms,
		"capabilities": capability_value,
		"fallback": fallback,
		"next_ledger": next_ledger,
	}
	var result := ResultValue.new(built.result, bindings, _RESULT_TOKEN)
	_register_result(result, built.result, bindings)
	if not validate_result(result, ledger, window):
		return _failure("result_integrity_invalid")
	return StepOutcome.new(true, "", result)


static func validate_ledger(value: Variant) -> bool:
	var entry := _ledger_registry_entry(value)
	if (
		not value is LedgerValue
		or entry.is_empty()
		or value.get("_factory_token") != _LEDGER_TOKEN
		or not value.get("_snapshot") is Dictionary
		or value.get("_snapshot") != entry.get("snapshot")
		or not _has_exact_keys(value.get("_snapshot"), [
			"schema_version", "profile_id", "ledger_id", "decision_ordinal", "total_budget_ms",
			"remaining_ms", "cumulative_elapsed_ms", "previous_telemetry_hash", "ledger_hash",
		])
	):
		return false
	var snapshot: Dictionary = value.get("_snapshot")
	var previous: Variant = snapshot.get("previous_telemetry_hash")
	if (
		snapshot.get("schema_version") != 1
		or snapshot.get("profile_id") != PROFILE_ID
		or not _identifier(snapshot.get("ledger_id"))
		or not _nonnegative_safe_int(snapshot.get("decision_ordinal"))
		or snapshot.get("total_budget_ms") != TOTAL_BUDGET_MS
		or not _nonnegative_safe_int(snapshot.get("remaining_ms"))
		or not _nonnegative_safe_int(snapshot.get("cumulative_elapsed_ms"))
		or int(snapshot.get("remaining_ms")) > TOTAL_BUDGET_MS
		or int(snapshot.get("cumulative_elapsed_ms")) > TOTAL_BUDGET_MS
		or int(snapshot.get("remaining_ms")) + int(snapshot.get("cumulative_elapsed_ms")) != TOTAL_BUDGET_MS
		or (previous != null and not _upper_sha(previous))
	):
		return false
	var expected := _ledger_payload(
		str(snapshot.ledger_id), int(snapshot.decision_ordinal), int(snapshot.remaining_ms),
		int(snapshot.cumulative_elapsed_ms), previous,
	)
	return not expected.is_empty() and expected == snapshot


static func ledger_public_dict(value: Variant) -> Dictionary:
	return value.get("_snapshot").duplicate(true) if validate_ledger(value) else {}


static func validate_result(value: Variant, ledger: Variant, window: Variant) -> bool:
	var entry := _result_registry_entry(value)
	if (
		not value is ResultValue
		or entry.is_empty()
		or value.get("_factory_token") != _RESULT_TOKEN
		or ledger != value.get("_ledger_binding")
		or window != value.get("_window_binding")
		or ledger != entry.get("ledger")
		or window != entry.get("window")
		or not validate_ledger(ledger)
		or not _window_valid(window)
		or not _nonnegative_safe_int(value.get("_elapsed_ms"))
		or not value.get("_capabilities") is Dictionary
		or not _capability_error(value.get("_capabilities")).is_empty()
		or not validate_ledger(value.get("_next_ledger_binding"))
		or not value.get("_snapshot") is Dictionary
		or value.get("_snapshot") != entry.get("snapshot")
		or value.get("_capabilities") != entry.get("capabilities")
		or value.get("_elapsed_ms") != entry.get("elapsed_ms")
		or value.get("_fallback_binding") != entry.get("fallback")
		or value.get("_next_ledger_binding") != entry.get("next_ledger")
	):
		return false
	var ledger_value := ledger_public_dict(ledger)
	var elapsed := int(value.get("_elapsed_ms"))
	var charged: int = mini(elapsed, int(ledger_value.remaining_ms))
	var remaining: int = int(ledger_value.remaining_ms) - charged
	var classification := _classification(remaining, value.get("_capabilities"))
	var selected: Array = []
	var fallback: Variant = value.get("_fallback_binding")
	if classification.mode == "deterministic_fallback":
		if fallback == null or not CabtDeterministicFallbackScript.validate_resolution_integrity(fallback, window) or fallback.owner != "deterministic_fallback":
			return false
		selected = fallback.selected_indexes
	elif fallback != null:
		return false
	var expected := _result_payload(ledger, window, elapsed, value.get("_capabilities"), selected)
	return (
		not expected.is_empty()
		and value.get("_snapshot") == expected.result
		and ledger_public_dict(value.get("_next_ledger_binding")) == expected.next_ledger
	)


static func result_public_dict(value: Variant) -> Dictionary:
	return value.get("_snapshot").duplicate(true) if validate_result(value, value.get("_ledger_binding"), value.get("_window_binding")) else {}


static func _new_ledger(payload: Dictionary) -> Variant:
	var value := LedgerValue.new(payload, _LEDGER_TOKEN)
	_register_ledger(value, payload)
	return value if validate_ledger(value) else null


static func _ledger_payload(
	ledger_id: String,
	ordinal: int,
	remaining_ms: int,
	cumulative_elapsed_ms: int,
	previous_telemetry_hash: Variant,
) -> Dictionary:
	var payload := {
		"schema_version": 1,
		"profile_id": PROFILE_ID,
		"ledger_id": ledger_id,
		"decision_ordinal": ordinal,
		"total_budget_ms": TOTAL_BUDGET_MS,
		"remaining_ms": remaining_ms,
		"cumulative_elapsed_ms": cumulative_elapsed_ms,
		"previous_telemetry_hash": previous_telemetry_hash,
	}
	var ledger_hash := _domain_hash(LEDGER_PREFIX_UTF8_HEX, payload)
	if ledger_hash.is_empty():
		return {}
	payload["ledger_hash"] = ledger_hash
	return payload


static func _classification(remaining: int, capabilities: Dictionary) -> Dictionary:
	var known := REQUIRED_CAPABILITIES + OPTIONAL_CAPABILITIES
	var unknown_count := 0
	for key: Variant in capabilities.keys():
		if not known.has(key):
			unknown_count += 1
	var unavailable: Array = []
	for capability: String in known:
		if capabilities.get(capability) != "available":
			unavailable.append(capability)
	unavailable.sort()
	if unknown_count > 0:
		return {"mode": "deterministic_fallback", "reason": "unknown_capability", "unavailable": unavailable, "unknown_count": unknown_count}
	for capability: String in REQUIRED_CAPABILITIES:
		if capabilities.get(capability) != "available":
			return {"mode": "deterministic_fallback", "reason": "required_capability_unavailable", "unavailable": unavailable, "unknown_count": 0}
	if remaining == 0:
		return {"mode": "deterministic_fallback", "reason": "budget_exhausted", "unavailable": unavailable, "unknown_count": 0}
	if remaining <= FALLBACK_THRESHOLD_MS:
		return {"mode": "deterministic_fallback", "reason": "budget_reserve", "unavailable": unavailable, "unknown_count": 0}
	if remaining <= BASE_ONLY_THRESHOLD_MS:
		return {"mode": "base_only", "reason": "budget_constrained", "unavailable": unavailable, "unknown_count": 0}
	if capabilities.get("public_deck_adapter_v1") != "available":
		return {"mode": "base_only", "reason": "optional_capability_unavailable", "unavailable": unavailable, "unknown_count": 0}
	return {"mode": "full", "reason": "full_budget_available", "unavailable": unavailable, "unknown_count": 0}


static func _result_payload(
	ledger: Variant,
	window: Variant,
	elapsed_ms: int,
	capabilities: Dictionary,
	selected_indexes: Array,
) -> Dictionary:
	var ledger_value := ledger_public_dict(ledger)
	if ledger_value.is_empty() or not _window_valid(window):
		return {}
	var charged: int = mini(elapsed_ms, int(ledger_value.remaining_ms))
	var remaining: int = int(ledger_value.remaining_ms) - charged
	var classification := _classification(remaining, capabilities)
	var telemetry := {
		"schema_version": 1,
		"profile_id": PROFILE_ID,
		"ledger_id": ledger_value.ledger_id,
		"window_id": window.get("window_id"),
		"ledger_before_hash": ledger_value.ledger_hash,
		"decision_ordinal": int(ledger_value.decision_ordinal) + 1,
		"remaining_before_ms": ledger_value.remaining_ms,
		"elapsed_ms": elapsed_ms,
		"charged_elapsed_ms": charged,
		"remaining_after_ms": remaining,
		"mode": classification.mode,
		"reason_code": classification.reason,
		"known_unavailable_capabilities": classification.unavailable.duplicate(true),
		"unknown_capability_count": classification.unknown_count,
		"fallback_used": classification.mode == "deterministic_fallback",
	}
	var telemetry_hash := _domain_hash(TELEMETRY_PREFIX_UTF8_HEX, telemetry)
	if telemetry_hash.is_empty():
		return {}
	var next_ledger := _ledger_payload(
		str(ledger_value.ledger_id), int(ledger_value.decision_ordinal) + 1, remaining,
		int(ledger_value.cumulative_elapsed_ms) + charged, telemetry_hash,
	)
	if next_ledger.is_empty():
		return {}
	var payload := {
		"schema_version": 1,
		"profile_id": PROFILE_ID,
		"ledger_id": ledger_value.ledger_id,
		"window_id": window.get("window_id"),
		"ledger_before_hash": ledger_value.ledger_hash,
		"decision_ordinal": int(ledger_value.decision_ordinal) + 1,
		"remaining_before_ms": ledger_value.remaining_ms,
		"elapsed_ms": elapsed_ms,
		"remaining_after_ms": remaining,
		"mode": classification.mode,
		"reason_code": classification.reason,
		"known_unavailable_capabilities": classification.unavailable.duplicate(true),
		"unknown_capability_count": classification.unknown_count,
		"selected_indexes": selected_indexes.duplicate(true) if classification.mode == "deterministic_fallback" else [],
		"fallback_used": classification.mode == "deterministic_fallback",
		"telemetry_hash": telemetry_hash,
		"next_ledger": next_ledger.duplicate(true),
		"authority": "public_policy_budget_audit",
		"authoritative": false,
	}
	var result_hash := _domain_hash(RESULT_PREFIX_UTF8_HEX, payload)
	if result_hash.is_empty():
		return {}
	payload["result_hash"] = result_hash
	return {"result": payload, "next_ledger": next_ledger}


static func _failure(code: String) -> StepOutcome:
	return StepOutcome.new(false, code)


static func _window_valid(value: Variant) -> bool:
	return (
		typeof(value) == TYPE_OBJECT
		and value != null
		and value.get_script() == CabtSelectionWindowScript
		and value.has_method("validate_integrity")
		and value.validate_integrity() == true
	)


static func _capability_error(value: Variant) -> String:
	if not value is Dictionary:
		return "invalid_capability_report"
	for key: Variant in value.keys():
		if not _identifier(key):
			return "invalid_capability_report"
		var state: Variant = value.get(key)
		if typeof(state) != TYPE_STRING or not CAPABILITY_STATES.has(state):
			return "invalid_capability_report"
	return ""


static func _identifier(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).is_empty() or str(value).length() > 128 or str(value).to_lower().contains("private"):
		return false
	const ALLOWED := "abcdefghijklmnopqrstuvwxyz0123456789._-"
	for character: String in str(value):
		if not ALLOWED.contains(character):
			return false
	return str(value)[0] in "abcdefghijklmnopqrstuvwxyz0123456789"


static func _nonnegative_safe_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 0 and value <= MAX_SAFE_INTEGER


static func _upper_sha(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 64:
		return false
	for character: String in str(value):
		if not "0123456789ABCDEF".contains(character):
			return false
	return true


static func _register_ledger(value: Variant, snapshot: Dictionary) -> void:
	_prune_registries()
	_LEDGER_REGISTRY.append({"weak": weakref(value), "snapshot": snapshot.duplicate(true)})


static func _ledger_registry_entry(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_OBJECT or value == null:
		return {}
	_prune_registries()
	for entry: Variant in _LEDGER_REGISTRY:
		var weak_value: Variant = entry.get("weak") if entry is Dictionary else null
		if typeof(weak_value) == TYPE_OBJECT and weak_value != null and weak_value.get_ref() == value:
			return entry
	return {}


static func _register_result(value: Variant, snapshot: Dictionary, bindings: Dictionary) -> void:
	_prune_registries()
	_RESULT_REGISTRY.append({
		"weak": weakref(value),
		"snapshot": snapshot.duplicate(true),
		"ledger": bindings.ledger,
		"window": bindings.window,
		"elapsed_ms": bindings.elapsed_ms,
		"capabilities": bindings.capabilities.duplicate(true),
		"fallback": bindings.fallback,
		"next_ledger": bindings.next_ledger,
	})


static func _result_registry_entry(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_OBJECT or value == null:
		return {}
	_prune_registries()
	for entry: Variant in _RESULT_REGISTRY:
		var weak_value: Variant = entry.get("weak") if entry is Dictionary else null
		if typeof(weak_value) == TYPE_OBJECT and weak_value != null and weak_value.get_ref() == value:
			return entry
	return {}


static func _prune_registries() -> void:
	for registry: Array in [_LEDGER_REGISTRY, _RESULT_REGISTRY]:
		for index: int in range(registry.size() - 1, -1, -1):
			var entry: Variant = registry[index]
			var weak_value: Variant = entry.get("weak") if entry is Dictionary else null
			if typeof(weak_value) != TYPE_OBJECT or weak_value == null or weak_value.get_ref() == null:
				registry.remove_at(index)


static func _load_contracts(root_path: String) -> Dictionary:
	var root := root_path.trim_suffix("/")
	if root.is_empty():
		return {"ok": false}
	var bundle_bytes := _load_bytes("%s/public_policy_budget_bundle.json" % root)
	if bundle_bytes.is_empty() or _canonical_artifact_sha256(bundle_bytes) != EXPECTED_BUNDLE_SHA256:
		return {"ok": false}
	var parsed := PublicObservationFirewallScript._parse_contract_json_bytes(bundle_bytes)
	var bundle: Variant = parsed.get("value") if bool(parsed.get("ok", false)) else null
	if not bundle is Dictionary or not _has_exact_keys(bundle, ["schema_version", "bundle_id", "parent_bundle_canonical_sha256", "source_lock_canonical_sha256", "artifacts"]):
		return {"ok": false}
	if bundle.get("schema_version") != 1 or bundle.get("bundle_id") != PROFILE_ID or bundle.get("parent_bundle_canonical_sha256") != EXPECTED_PARENT_BUNDLE_SHA256 or bundle.get("source_lock_canonical_sha256") != EXPECTED_SOURCE_LOCK_SHA256:
		return {"ok": false}
	var artifacts: Variant = bundle.get("artifacts")
	if not artifacts is Array or artifacts.size() != EXPECTED_ARTIFACT_NAMES.size():
		return {"ok": false}
	var profile: Variant = null
	for index: int in EXPECTED_ARTIFACT_NAMES.size():
		var name: String = EXPECTED_ARTIFACT_NAMES[index]
		var entry: Variant = artifacts[index]
		if not entry is Dictionary or not _has_exact_keys(entry, ["id", "path", "canonical_sha256"]):
			return {"ok": false}
		if entry.get("id") != name.trim_suffix(".json") or entry.get("path") != "contracts/ptcgdap/%s" % name or entry.get("canonical_sha256") != EXPECTED_ARTIFACTS.get(name):
			return {"ok": false}
		var bytes := _load_bytes("%s/%s" % [root, name])
		if bytes.is_empty() or _canonical_artifact_sha256(bytes) != EXPECTED_ARTIFACTS.get(name):
			return {"ok": false}
		var document := PublicObservationFirewallScript._parse_contract_json_bytes(bytes)
		if not bool(document.get("ok", false)):
			return {"ok": false}
		if name == "public_policy_budget_profile.json":
			profile = document.get("value")
	if not profile is Dictionary:
		return {"ok": false}
	var budget: Variant = profile.get("budget_contract")
	var capability: Variant = profile.get("capability_contract")
	var serialization: Variant = profile.get("serialization_contract")
	if (
		profile.get("profile_id") != PROFILE_ID
		or profile.get("parent_bundle_canonical_sha256") != EXPECTED_PARENT_BUNDLE_SHA256
		or not budget is Dictionary
		or budget.get("total_match_budget_ms") != TOTAL_BUDGET_MS
		or budget.get("base_only_at_or_below_remaining_ms") != BASE_ONLY_THRESHOLD_MS
		or budget.get("fallback_at_or_below_remaining_ms") != FALLBACK_THRESHOLD_MS
		or budget.get("modes") != MODES
		or not capability is Dictionary
		or capability.get("required") != REQUIRED_CAPABILITIES
		or capability.get("optional") != OPTIONAL_CAPABILITIES
		or capability.get("states") != CAPABILITY_STATES
		or not serialization is Dictionary
		or serialization.get("ledger_and_result_are_execution_authority") != false
		or serialization.get("unknown_capability_names_are_serialized") != false
		or serialization.get("consumer_must_revalidate_exact_window") != true
	):
		return {"ok": false}
	return {"ok": true}


static func _load_bytes(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var length := file.get_length()
	if length < 1 or length > MAX_CONTRACT_BYTES:
		return PackedByteArray()
	return file.get_buffer(length)


static func _canonical_artifact_sha256(source_bytes: PackedByteArray) -> String:
	var result := CabtJsonTreeScript.canonicalize_artifact_json_bytes(source_bytes, {"max_input_bytes": MAX_CONTRACT_BYTES, "max_output_bytes": MAX_CONTRACT_BYTES})
	return _raw_sha256(result.get("bytes", PackedByteArray())) if bool(result.get("ok", false)) else ""


static func _domain_hash(prefix_hex: String, payload: Dictionary) -> String:
	var result := CabtJsonTreeScript.canonicalize(payload, {"max_output_bytes": MAX_VALUE_BYTES})
	if not bool(result.get("ok", false)):
		return ""
	var bytes: PackedByteArray = prefix_hex.hex_decode()
	bytes.append_array(result.get("bytes", PackedByteArray()))
	return _raw_sha256(bytes)


static func _raw_sha256(source_bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(source_bytes) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key: Variant in value.keys():
		if typeof(key) != TYPE_STRING or not expected.has(key):
			return false
	return true
