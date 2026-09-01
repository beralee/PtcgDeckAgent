class_name RestrictedBaseGraphExecutorCore
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const PublicObservationFirewallScript = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")
const StrategicContextScript = preload("res://scripts/ai/ptcgdap/public/StrategicContextV18.gd")
const StrategicTraceScript = preload("res://scripts/ai/ptcgdap/public/StrategicTraceV2.gd")

const DEFAULT_ROOT := "res://contracts/ptcgdap"
const PROFILE_ID := "ptcgdap-restricted-base-graph-executor-p4-wp3-v1"
const BUNDLE_ID := "ptcgdap-restricted-base-graph-executor-p4-wp3-v1"
const EXPECTED_BUNDLE_SHA256 := "69D05747A9F91C19765D448B676C86E1D9DFA1BBAB108ED1374B854B34E48389"
const EXPECTED_PARENT_BUNDLE_SHA256 := "ADDD4CB48BD10FA0478854124D8E63AEE42B898C0EB81692BA35F8D7F90414C4"
const EXPECTED_ARTIFACTS := {
	"restricted_base_graph_executor.schema.json": "1B51354DBCEE1EE4C91A27BBF1FB2E3DC6847959D3B305B92E854EF1028A511E",
	"restricted_base_graph_executor_profile.json": "FCE7CD9F86F9AFC92152B0DD9342F3F7172F61EB26469397D70B85CEA95E185B",
	"restricted_base_graph_executor_conformance_vectors.json": "FBFD16F39742D7DB9DF531A4F7ADB130882EFD86477A074A1855B0F214725326",
}
const EXECUTION_PREFIX_UTF8_HEX := "5054434744415000524553545249435445445F424153455F47524150485F455845435554494F4E5F563100"
const MAX_CONTRACT_BYTES := 2 * 1024 * 1024
const MAX_VALUE_BYTES := 1024 * 1024
const MAX_SAFE_INTEGER := 9007199254740991
const INPUT_KEYS := ["execution_id", "mandatory_indexes", "terminal_indexes", "base_hard_tiers", "base_vetoed_indexes", "adapter_proposals"]
const ADAPTER_REASONS := {
	"goal_proposal": "public_goal_proposal",
	"macro_proposal": "public_macro_proposal",
	"tiebreak_score": "public_tiebreak_proposal",
}

static var _RESULT_TOKEN: RefCounted = RefCounted.new()
static var _RESULT_REGISTRY: Dictionary = {}
static var _DEFAULT_CONTRACT_CACHE: Dictionary = {}


class ExecutionOutcome extends RefCounted:
	var accepted := false
	var error_code := "contract_error"
	var result: Variant = null

	func _init(accepted_value: bool, error_value: String, result_value: Variant = null) -> void:
		accepted = accepted_value
		error_code = error_value
		result = result_value


class ExecutionValue extends RefCounted:
	var _snapshot: Variant = {}
	var _input_snapshot: Variant = {}
	var _context_binding: Variant = null
	var _ir_binding: Variant = null
	var _factory_token: Variant = null

	var selected_indexes: Array:
		get:
			var owner: GDScript = load("res://scripts/ai/ptcgdap/public/RestrictedBaseGraphExecutor.gd")
			if not bool(owner.call("validate_result", self, _context_binding, _ir_binding)):
				return []
			return _snapshot.get("selected_indexes", []).duplicate(true)

	var execution_hash: String:
		get:
			var owner: GDScript = load("res://scripts/ai/ptcgdap/public/RestrictedBaseGraphExecutor.gd")
			return str(_snapshot.get("execution_hash", "")) if bool(owner.call("validate_result", self, _context_binding, _ir_binding)) else ""

	func _init(snapshot_value: Dictionary = {}, input_value: Dictionary = {}, context_value: Variant = null, ir_value: Variant = null, token_value: Variant = null) -> void:
		_snapshot = snapshot_value.duplicate(true)
		_input_snapshot = input_value.duplicate(true)
		_context_binding = context_value
		_ir_binding = ir_value
		_factory_token = token_value

	func validate_integrity(context_value: Variant, ir_value: Variant) -> bool:
		var owner: GDScript = load("res://scripts/ai/ptcgdap/public/RestrictedBaseGraphExecutor.gd")
		return bool(owner.call("validate_result", self, context_value, ir_value))

	func to_public_dict() -> Dictionary:
		var owner: GDScript = load("res://scripts/ai/ptcgdap/public/RestrictedBaseGraphExecutor.gd")
		return owner.call("result_public_dict", self)


static func execute(context: Variant, ir: Variant, execution_input: Variant, contract_root: Variant = DEFAULT_ROOT) -> ExecutionOutcome:
	if typeof(contract_root) != TYPE_STRING or not _load_contracts(str(contract_root)).get("ok", false):
		return ExecutionOutcome.new(false, "contract_error")
	if not StrategicContextScript.validate_context(context):
		return ExecutionOutcome.new(false, "invalid_context")
	if not StrategicTraceScript.validate_ir(ir):
		return ExecutionOutcome.new(false, "invalid_ir")
	var computed := _compute(StrategicContextScript.context_public_dict(context), StrategicTraceScript.ir_public_dict(ir), execution_input)
	if not bool(computed.get("ok", false)):
		return ExecutionOutcome.new(false, str(computed.get("error_code", "invalid_execution_input")))
	var payload: Dictionary = computed.get("payload")
	var value := ExecutionValue.new(payload, execution_input, context, ir, _RESULT_TOKEN)
	_register_result(value, payload, execution_input, context, ir)
	if not validate_result(value, context, ir):
		return ExecutionOutcome.new(false, "execution_integrity_invalid")
	return ExecutionOutcome.new(true, "", value)


static func validate_result(value: Variant, context: Variant, ir: Variant) -> bool:
	var entry := _registry_entry(value)
	if (
		not value is ExecutionValue
		or entry.is_empty()
		or value.get("_factory_token") != _RESULT_TOKEN
		or context != value.get("_context_binding")
		or ir != value.get("_ir_binding")
		or context != entry.get("context")
		or ir != entry.get("ir")
		or not value.get("_snapshot") is Dictionary
		or not value.get("_input_snapshot") is Dictionary
		or value.get("_snapshot") != entry.get("snapshot")
		or value.get("_input_snapshot") != entry.get("input")
		or not StrategicContextScript.validate_context(context)
		or not StrategicTraceScript.validate_ir(ir)
	):
		return false
	var computed := _compute(StrategicContextScript.context_public_dict(context), StrategicTraceScript.ir_public_dict(ir), value.get("_input_snapshot"))
	return bool(computed.get("ok", false)) and value.get("_snapshot") == computed.get("payload")


static func result_public_dict(value: Variant) -> Dictionary:
	return value.get("_snapshot").duplicate(true) if validate_result(value, value.get("_context_binding"), value.get("_ir_binding")) else {}


static func _compute(context_payload: Dictionary, ir_document: Dictionary, execution_input: Variant) -> Dictionary:
	var source: Variant = context_payload.get("source")
	var semantics: Variant = context_payload.get("select_semantics")
	if not source is Dictionary or not semantics is Dictionary:
		return {"ok": false, "error_code": "invalid_context"}
	var option_count: Variant = source.get("option_count")
	var min_count: Variant = semantics.get("min_count")
	var max_count: Variant = semantics.get("max_count")
	if not _safe_int(option_count) or not _safe_int(min_count) or not _safe_int(max_count) or option_count < 0 or min_count < 0 or max_count < min_count or max_count > option_count:
		return {"ok": false, "error_code": "invalid_context"}
	var error := _input_error(execution_input, option_count, ir_document)
	if not error.is_empty():
		return {"ok": false, "error_code": error}
	var mandatory: Array = execution_input.get("mandatory_indexes")
	var terminal: Array = execution_input.get("terminal_indexes")
	var forced: Array = terminal if not terminal.is_empty() else mandatory
	if not forced.is_empty() and (forced.size() < min_count or forced.size() > max_count):
		return {"ok": false, "error_code": "invalid_execution_input"}
	var current: Array = []
	for index: int in option_count:
		current.append(index)
	var tiers := {}
	for tier_entry: Variant in execution_input.get("base_hard_tiers"):
		tiers[tier_entry.get("index")] = tier_entry.get("tier").duplicate(true)
	var audit: Array = []
	for node: Variant in ir_document.get("nodes", []):
		var before := current.duplicate(true)
		var operator: String = str(node.get("operator"))
		match operator:
			"legality_guard":
				current.clear()
				for index: int in option_count:
					current.append(index)
			"mandatory_terminal_guard":
				if not forced.is_empty():
					current = forced.duplicate(true)
			"goal_proposal", "macro_proposal", "tiebreak_score":
				if forced.is_empty():
					current = _ordered_hint(current, execution_input.get("adapter_proposals"), operator)
			"hard_tier_filter":
				if forced.is_empty() and not current.is_empty():
					var best: Array = tiers.get(current[0])
					for index: int in current:
						var candidate: Array = tiers.get(index)
						if _tier_less(candidate, best):
							best = candidate
					var retained: Array = []
					for index: int in current:
						if tiers.get(index) == best:
							retained.append(index)
					current = retained
			"base_veto":
				if forced.is_empty():
					var retained: Array = []
					for index: int in current:
						if not execution_input.get("base_vetoed_indexes").has(index):
							retained.append(index)
					current = retained
			"deterministic_fallback":
				if current.size() < min_count:
					return {"ok": false, "error_code": "insufficient_candidates"}
				current = current.slice(0, min_count)
		audit.append({"node_id": node.get("node_id"), "operator": operator, "owner": node.get("owner"), "input_indexes": before, "output_indexes": current.duplicate(true)})
	var reason := "empty_selection" if min_count == 0 else "terminal_selection" if not terminal.is_empty() else "mandatory_selection" if not mandatory.is_empty() else "deterministic_fallback"
	var branch := "optional_zero" if min_count == 0 else "terminal" if not terminal.is_empty() else "mandatory" if not mandatory.is_empty() else "same_window_first_min"
	var payload := {
		"schema_version": 1,
		"profile_id": PROFILE_ID,
		"execution_id": execution_input.get("execution_id"),
		"source": {"context_hash": context_payload.get("context_hash"), "window_id": source.get("window_id"), "ir_hash": ir_document.get("ir_hash")},
		"selected_indexes": current.duplicate(true),
		"reason_code": reason,
		"fallback_branch": branch,
		"node_audit": audit,
		"adapter_audit": execution_input.get("adapter_proposals").duplicate(true),
		"authoritative": false,
	}
	var execution_hash := _domain_hash(payload)
	if execution_hash.is_empty():
		return {"ok": false, "error_code": "execution_integrity_invalid"}
	payload["execution_hash"] = execution_hash
	return {"ok": true, "payload": payload}


static func _input_error(value: Variant, option_count: int, ir_document: Dictionary) -> String:
	if not value is Dictionary or not _has_exact_keys(value, INPUT_KEYS) or not _identifier(value.get("execution_id")):
		return "invalid_execution_input"
	for key: String in ["mandatory_indexes", "terminal_indexes", "base_vetoed_indexes"]:
		if not _index_list(value.get(key), option_count):
			return "invalid_execution_input"
	if _intersects(value.get("mandatory_indexes"), value.get("base_vetoed_indexes")) or _intersects(value.get("terminal_indexes"), value.get("base_vetoed_indexes")):
		return "forced_index_vetoed"
	var tier_entries: Variant = value.get("base_hard_tiers")
	if not tier_entries is Array or tier_entries.size() != option_count:
		return "invalid_execution_input"
	var seen_tiers := {}
	for entry: Variant in tier_entries:
		if not entry is Dictionary or not _has_exact_keys(entry, ["index", "tier"]):
			return "invalid_execution_input"
		var index: Variant = entry.get("index")
		var tier: Variant = entry.get("tier")
		if not _safe_int(index) or index < 0 or index >= option_count or seen_tiers.has(index) or not tier is Array or tier.is_empty() or tier.size() > 8:
			return "invalid_execution_input"
		for part: Variant in tier:
			if not _safe_int(part):
				return "invalid_execution_input"
		seen_tiers[index] = true
	var operators := {}
	for node: Variant in ir_document.get("nodes", []):
		operators[node.get("operator")] = true
	var proposals: Variant = value.get("adapter_proposals")
	if not proposals is Array or proposals.size() > 64:
		return "invalid_execution_input"
	for proposal: Variant in proposals:
		if not proposal is Dictionary or not _has_exact_keys(proposal, ["operator", "indexes", "reason_code"]):
			return "invalid_execution_input"
		var operator: Variant = proposal.get("operator")
		if typeof(operator) != TYPE_STRING or not ADAPTER_REASONS.has(operator) or not operators.has(operator) or proposal.get("reason_code") != ADAPTER_REASONS.get(operator) or not _index_list(proposal.get("indexes"), option_count):
			return "invalid_execution_input"
		for child: Variant in proposal.values():
			if typeof(child) == TYPE_STRING and str(child).to_upper().contains("PRIVATE"):
				return "invalid_execution_input"
	return ""


static func _ordered_hint(current: Array, proposals: Array, operator: String) -> Array:
	var preferred: Array = []
	for proposal: Variant in proposals:
		if proposal.get("operator") == operator:
			for index: Variant in proposal.get("indexes"):
				if current.has(index) and not preferred.has(index):
					preferred.append(index)
	var result := preferred.duplicate(true)
	for index: Variant in current:
		if not result.has(index):
			result.append(index)
	return result


static func _register_result(value: Variant, snapshot: Dictionary, execution_input: Dictionary, context: Variant, ir: Variant) -> void:
	_prune_registry()
	_RESULT_REGISTRY[value.get_instance_id()] = {"weak": weakref(value), "snapshot": snapshot.duplicate(true), "input": execution_input.duplicate(true), "context": context, "ir": ir}


static func _registry_entry(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_OBJECT or value == null:
		return {}
	_prune_registry()
	var entry: Variant = _RESULT_REGISTRY.get(value.get_instance_id())
	if not entry is Dictionary:
		return {}
	var weak_value: Variant = entry.get("weak")
	if typeof(weak_value) != TYPE_OBJECT or weak_value == null or weak_value.get_ref() != value:
		return {}
	return entry


static func _prune_registry() -> void:
	for instance_id: Variant in _RESULT_REGISTRY.keys():
		var entry: Variant = _RESULT_REGISTRY.get(instance_id)
		var weak_value: Variant = entry.get("weak") if entry is Dictionary else null
		if typeof(weak_value) != TYPE_OBJECT or weak_value == null or weak_value.get_ref() == null:
			_RESULT_REGISTRY.erase(instance_id)


static func _load_contracts(root_path: String) -> Dictionary:
	var root := root_path.trim_suffix("/")
	if root.is_empty():
		return {"ok": false}
	if root == DEFAULT_ROOT and bool(_DEFAULT_CONTRACT_CACHE.get("ok", false)):
		return _DEFAULT_CONTRACT_CACHE.duplicate(true)
	var bundle_bytes := _load_bytes("%s/restricted_base_graph_executor_bundle.json" % root)
	if bundle_bytes.is_empty() or _canonical_artifact_sha256(bundle_bytes) != EXPECTED_BUNDLE_SHA256:
		return {"ok": false}
	var parsed := PublicObservationFirewallScript._parse_contract_json_bytes(bundle_bytes)
	var bundle: Variant = parsed.get("value") if bool(parsed.get("ok", false)) else null
	if not bundle is Dictionary or not _has_exact_keys(bundle, ["schema_version", "bundle_id", "parent_bundle_canonical_sha256", "source_lock_canonical_sha256", "artifacts"]):
		return {"ok": false}
	if bundle.get("schema_version") != 1 or bundle.get("bundle_id") != BUNDLE_ID or bundle.get("parent_bundle_canonical_sha256") != EXPECTED_PARENT_BUNDLE_SHA256:
		return {"ok": false}
	var artifacts: Variant = bundle.get("artifacts")
	if not artifacts is Array or artifacts.size() != 3:
		return {"ok": false}
	var seen := {}
	var profile: Variant = null
	for entry: Variant in artifacts:
		if not entry is Dictionary or not _has_exact_keys(entry, ["id", "path", "canonical_sha256"]):
			return {"ok": false}
		var path: Variant = entry.get("path")
		if typeof(path) != TYPE_STRING:
			return {"ok": false}
		var name := str(path).get_file()
		if not EXPECTED_ARTIFACTS.has(name) or seen.has(name) or entry.get("canonical_sha256") != EXPECTED_ARTIFACTS.get(name):
			return {"ok": false}
		var bytes := _load_bytes("%s/%s" % [root, name])
		if bytes.is_empty() or _canonical_artifact_sha256(bytes) != EXPECTED_ARTIFACTS.get(name):
			return {"ok": false}
		var document_result := PublicObservationFirewallScript._parse_contract_json_bytes(bytes)
		if not bool(document_result.get("ok", false)):
			return {"ok": false}
		if name == "restricted_base_graph_executor_profile.json":
			profile = document_result.get("value")
		seen[name] = true
	if seen.size() != 3 or not profile is Dictionary:
		return {"ok": false}
	if profile.get("profile_id") != PROFILE_ID or profile.get("parent_bundle_canonical_sha256") != EXPECTED_PARENT_BUNDLE_SHA256 or profile.get("source_authority") != "exact_current_p4_wp1_context_and_p4_wp2_ir_owner" or profile.get("execution_contract", {}).get("adapter_authority") != "same_tier_ordering_hint_only" or profile.get("result_contract", {}).get("serialized_result_is_execution_authority") != false:
		return {"ok": false}
	var result := {"ok": true}
	if root == DEFAULT_ROOT:
		_DEFAULT_CONTRACT_CACHE = result.duplicate(true)
	return result


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


static func _domain_hash(payload: Dictionary) -> String:
	var result := CabtJsonTreeScript.canonicalize(payload, {"max_output_bytes": MAX_VALUE_BYTES})
	if not bool(result.get("ok", false)):
		return ""
	var bytes: PackedByteArray = EXECUTION_PREFIX_UTF8_HEX.hex_decode()
	bytes.append_array(result.get("bytes", PackedByteArray()))
	return _raw_sha256(bytes)


static func _raw_sha256(source_bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(source_bytes) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


static func _safe_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= -MAX_SAFE_INTEGER and value <= MAX_SAFE_INTEGER


static func _identifier(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).is_empty() or str(value).length() > 128 or str(value).to_upper().contains("PRIVATE"):
		return false
	const ALLOWED := "abcdefghijklmnopqrstuvwxyz0123456789._-"
	for character: String in str(value):
		if not ALLOWED.contains(character):
			return false
	return str(value)[0] in "abcdefghijklmnopqrstuvwxyz0123456789"


static func _index_list(value: Variant, option_count: int) -> bool:
	if not value is Array or value.size() > 1024:
		return false
	var seen := {}
	for child: Variant in value:
		if not _safe_int(child) or child < 0 or child >= option_count or seen.has(child):
			return false
		seen[child] = true
	return true


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key: Variant in value.keys():
		if typeof(key) != TYPE_STRING or not expected.has(key):
			return false
	return true


static func _intersects(left: Array, right: Array) -> bool:
	for value: Variant in left:
		if right.has(value):
			return true
	return false


static func _tier_less(left: Array, right: Array) -> bool:
	var count := mini(left.size(), right.size())
	for index: int in count:
		if left[index] < right[index]:
			return true
		if left[index] > right[index]:
			return false
	return left.size() < right.size()
