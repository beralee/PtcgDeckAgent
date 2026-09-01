class_name PublicObservationFirewall
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const CabtTreeHashScript = preload("res://scripts/ai/ptcgdap/cabt/CabtTreeHash.gd")
const CabtContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const CabtObservationParserScript = preload("res://scripts/ai/ptcgdap/cabt/CabtObservationParser.gd")
const CabtRawEnvelopeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtRawEnvelope.gd")

const SCHEMA_VERSION := 1
const PROFILE_ID := "cabt_public_firewall_profile_v1"
const DEFAULT_ROOT := "res://contracts/ptcgdap"
const MAX_CONTRACT_BYTES := 2 * 1024 * 1024
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const EXPECTED_FIREWALL_BUNDLE_SHA256 := "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947"
const EXPECTED_PROFILE_SHA256 := "AA287117DF497ED51DCA19FA36DC6212E3AAC0E9A1D2B871BA6130B6E963332A"
const EXPECTED_SOURCE_CONTRACT_SHA256 := "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
const EXPECTED_BUNDLE_ID := "ptcgdap-public-firewall-p2-wp3-v1"
const EXPECTED_ARTIFACTS := {
	"cabt_public_observation_schema_v1": "contracts/ptcgdap/cabt_public_observation.schema.json",
	"cabt_public_firewall_profile_v1": "contracts/ptcgdap/cabt_public_firewall_profile.json",
	"cabt_public_firewall_conformance_v1": "contracts/ptcgdap/cabt_public_firewall_conformance_vectors.json",
}
const STABLE_ERROR_CODES := {
	"invalid_envelope": true,
	"envelope_not_policy_eligible": true,
	"source_contract_mismatch": true,
	"firewall_contract_error": true,
	"initial_shape_mismatch": true,
	"invalid_your_index": true,
	"invalid_player_count": true,
	"own_hand_not_visible": true,
	"opponent_hand_exposed": true,
	"prize_identity_exposed": true,
	"own_active_concealed": true,
	"unauthorized_select_deck": true,
	"opponent_draw_identity_exposed": true,
	"public_projection_limit": true,
	"public_hash_error": true,
	"result_integrity_invalid": true,
}


class FirewallResult:
	extends RefCounted

	var _status := "rejected"
	var _public_observation: Variant = null
	var _public_observation_hash: Variant = null
	var _provenance: Variant = []
	var _issues: Variant = []
	var _source_contract_hash := EXPECTED_SOURCE_CONTRACT_SHA256
	var _firewall_contract_hash := EXPECTED_FIREWALL_BUNDLE_SHA256
	var _bound_input: Variant = null
	var _owner: Variant = null
	var _snapshot: Variant = {}

	var status: String:
		get:
			return _status

	var accepted: bool:
		get:
			return _status == "accepted"

	var public_observation: Variant:
		get:
			return _copy_value(_public_observation)

	var public_observation_hash: Variant:
		get:
			return _public_observation_hash

	var provenance: Array:
		get:
			return _provenance.duplicate(true) if _provenance is Array else []

	var issues: Array:
		get:
			return _issues.duplicate(true) if _issues is Array else []

	func _init(owner_value: Variant = null, bound_value: Variant = null, evaluation: Variant = null) -> void:
		_owner = owner_value
		_bound_input = bound_value
		if evaluation is Dictionary:
			_status = str(evaluation.get("status", "rejected"))
			_public_observation = _copy_value(evaluation.get("public_observation"))
			_public_observation_hash = evaluation.get("public_observation_hash")
			_provenance = _copy_value(evaluation.get("provenance", []))
			_issues = _copy_value(evaluation.get("issues", []))
		_snapshot = _unchecked_dict()

	func _unchecked_dict() -> Dictionary:
		return {
			"schema_version": SCHEMA_VERSION,
			"profile_id": PROFILE_ID,
			"source_contract_hash": _source_contract_hash,
			"firewall_contract_hash": _firewall_contract_hash,
			"status": _status,
			"public_observation": _copy_value(_public_observation),
			"public_observation_hash": _public_observation_hash,
			"provenance": _copy_value(_provenance),
			"issues": _copy_value(_issues),
		}

	func validate_integrity(current_input: Variant) -> bool:
		return (
			_owner is RefCounted
			and _owner.has_method("_validate_result")
			and bool(_owner._validate_result(self, current_input))
		)

	func to_public_dict() -> Dictionary:
		if not validate_integrity(_bound_input):
			return {}
		return (_snapshot as Dictionary).duplicate(true)

	static func _copy_value(value: Variant) -> Variant:
		return value.duplicate(true) if value is Dictionary or value is Array else value


var _ok := false
var _error_code := "firewall_contract_error"
var _profile := {}
var _contract_root := ""
var _cabt_contracts: Variant = null
var _load_attempted := false

var ok: bool:
	get:
		return _ok

var error_code: String:
	get:
		return _error_code

var contract_hash: String:
	get:
		return EXPECTED_FIREWALL_BUNDLE_SHA256 if _ok else ""


static func load_default() -> Variant:
	return load_from_root(DEFAULT_ROOT)


static func load_from_root(root_path: Variant) -> Variant:
	var script: GDScript = load("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")
	var result: RefCounted = script.new()
	if typeof(root_path) != TYPE_STRING:
		result._load_attempted = true
		result._fail("firewall_contract_error")
		return result
	result._load(str(root_path))
	return result


func _load(root_path: String) -> void:
	if _load_attempted:
		return
	_load_attempted = true
	var normalized_root := root_path.trim_suffix("/")
	if normalized_root.is_empty():
		_fail("firewall_contract_error")
		return
	var bundle_bytes := _load_bytes("%s/cabt_public_firewall_bundle.json" % normalized_root)
	if bundle_bytes.is_empty() or _canonical_artifact_sha256(bundle_bytes) != EXPECTED_FIREWALL_BUNDLE_SHA256:
		_fail("firewall_contract_error")
		return
	var bundle_result := _parse_contract_json_bytes(bundle_bytes)
	if not bool(bundle_result.get("ok", false)):
		_fail("firewall_contract_error")
		return
	var bundle_value: Variant = bundle_result.get("value")
	if not bundle_value is Dictionary:
		_fail("firewall_contract_error")
		return
	var bundle: Dictionary = bundle_value
	if (
		bundle.get("schema_version") != 1
		or bundle.get("bundle_id") != EXPECTED_BUNDLE_ID
		or bundle.get("source_lock_id") != "ptcgdap-source-lock-2026-08-09-p1wp1"
	):
		_fail("firewall_contract_error")
		return
	var parent: Variant = bundle.get("parent_contract")
	if not parent is Dictionary or parent != {
		"id": "ptcgdap-cabt-contract-p1-wp3-v1",
		"path": "contracts/ptcgdap/cabt_contract_bundle.json",
		"canonical_sha256": EXPECTED_SOURCE_CONTRACT_SHA256,
	}:
		_fail("firewall_contract_error")
		return
	var artifacts_value: Variant = bundle.get("artifacts")
	if not artifacts_value is Array or artifacts_value.size() != EXPECTED_ARTIFACTS.size():
		_fail("firewall_contract_error")
		return
	var loaded := {}
	var seen_paths := {}
	for entry_value: Variant in artifacts_value:
		if not entry_value is Dictionary or entry_value.keys().size() != 3:
			_fail("firewall_contract_error")
			return
		var entry: Dictionary = entry_value
		if not entry.has("id") or not entry.has("path") or not entry.has("canonical_sha256"):
			_fail("firewall_contract_error")
			return
		var artifact_id: Variant = entry.get("id")
		var relative_path: Variant = entry.get("path")
		if typeof(artifact_id) != TYPE_STRING or typeof(relative_path) != TYPE_STRING:
			_fail("firewall_contract_error")
			return
		var expected_path: Variant = EXPECTED_ARTIFACTS.get(artifact_id)
		if expected_path == null or relative_path != expected_path or seen_paths.has(relative_path):
			_fail("firewall_contract_error")
			return
		seen_paths[relative_path] = true
		var file_name := str(relative_path).get_file()
		var source_bytes := _load_bytes("%s/%s" % [normalized_root, file_name])
		if source_bytes.is_empty() or _canonical_artifact_sha256(source_bytes) != entry.get("canonical_sha256"):
			_fail("firewall_contract_error")
			return
		var parsed := _parse_contract_json_bytes(source_bytes)
		if not bool(parsed.get("ok", false)):
			_fail("firewall_contract_error")
			return
		loaded[artifact_id] = parsed.get("value")
	if loaded.size() != EXPECTED_ARTIFACTS.size():
		_fail("firewall_contract_error")
		return
	var profile_value: Variant = loaded.get(PROFILE_ID)
	if not profile_value is Dictionary or _canonical_value_sha256(profile_value) != EXPECTED_PROFILE_SHA256:
		_fail("firewall_contract_error")
		return
	var cabt_contracts: Variant = CabtContractSetScript.load_from_root(normalized_root)
	if (
		cabt_contracts == null
		or not cabt_contracts is RefCounted
		or cabt_contracts.get_script() != CabtContractSetScript
		or not bool(cabt_contracts.get("ok"))
		or not cabt_contracts.has_method("validate_integrity")
		or cabt_contracts.validate_integrity() != true
		or cabt_contracts.source_contract_hash != EXPECTED_SOURCE_CONTRACT_SHA256
	):
		_fail("firewall_contract_error")
		return
	_profile = (profile_value as Dictionary).duplicate(true)
	_contract_root = normalized_root
	_cabt_contracts = cabt_contracts
	_ok = true
	_error_code = ""


func _fail(code: String) -> void:
	_ok = false
	_error_code = code if STABLE_ERROR_CODES.has(code) else "firewall_contract_error"
	_profile = {}
	_contract_root = ""
	_cabt_contracts = null


func validate_integrity() -> bool:
	if not _ok or _error_code != "" or _contract_root.is_empty():
		return false
	if not _profile is Dictionary or _canonical_value_sha256(_profile) != EXPECTED_PROFILE_SHA256:
		return false
	if _profile.get("profile_id") != PROFILE_ID or _profile.get("parent_contract", {}).get("canonical_sha256") != EXPECTED_SOURCE_CONTRACT_SHA256:
		return false
	return (
		_cabt_contracts != null
		and _cabt_contracts is RefCounted
		and _cabt_contracts.get_script() == CabtContractSetScript
		and bool(_cabt_contracts.get("ok"))
		and _cabt_contracts.has_method("validate_integrity")
		and _cabt_contracts.validate_integrity() == true
		and _cabt_contracts.source_contract_hash == EXPECTED_SOURCE_CONTRACT_SHA256
	)


func project(parse_result: Variant) -> Variant:
	var evaluation := _evaluate(parse_result)
	return FirewallResult.new(self, parse_result, evaluation)


func _evaluate(parse_result: Variant) -> Dictionary:
	return _evaluate_scoped(parse_result, false)


func _evaluate_setup_bench_concealment(parse_result: Variant) -> Dictionary:
	# P5 overlay hook.  The returned Dictionary is audit data, not a base result.
	var evaluation := _evaluate_scoped(parse_result, true)
	if evaluation.get("status") != "accepted":
		return evaluation
	var result: Dictionary = evaluation.duplicate(true)
	result["compatibility_rule"] = (
		"setup_bench_concealment_v1"
		if _setup_bench_concealment_applies(parse_result)
		else null
	)
	return result


func _setup_bench_concealment_applies(parse_result: Variant) -> bool:
	if parse_result == null or not parse_result is RefCounted:
		return false
	var envelope: Variant = parse_result.get("envelope")
	if envelope == null or not envelope is RefCounted or envelope.get_script() != CabtRawEnvelopeScript:
		return false
	var replayed: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(
		envelope.raw_payload,
		_cabt_contracts
	)
	if replayed == null or not replayed is RefCounted or replayed.envelope == null:
		return false
	var known_value: Variant = replayed.envelope.known_view
	if not known_value is Dictionary:
		return false
	var select_value: Variant = known_value.get("select")
	var current_value: Variant = known_value.get("current")
	if not select_value is Dictionary or not current_value is Dictionary:
		return false
	var acting: Variant = current_value.get("yourIndex")
	var players_value: Variant = current_value.get("players")
	if typeof(acting) != TYPE_INT or int(acting) not in [0, 1] or not players_value is Array or players_value.size() != 2:
		return false
	var own_value: Variant = players_value[int(acting)]
	var opponent_value: Variant = players_value[1 - int(acting)]
	if not own_value is Dictionary or not opponent_value is Dictionary:
		return false
	var active_value: Variant = own_value.get("active")
	return active_value is Array and _is_exact_setup_bench_concealment(
		select_value,
		current_value,
		own_value,
		opponent_value,
		active_value
	)


func _evaluate_scoped(parse_result: Variant, allow_setup_bench_concealment: bool) -> Dictionary:
	if not validate_integrity():
		return _rejected("firewall_contract_error", "")
	if (
		parse_result == null
		or not parse_result is RefCounted
		or not parse_result.has_method("safe_diagnostics")
	):
		return _rejected("invalid_envelope", "")
	var envelope: Variant = parse_result.get("envelope")
	if envelope == null:
		return _rejected("envelope_not_policy_eligible", "")
	if not envelope is RefCounted or envelope.get_script() != CabtRawEnvelopeScript:
		return _rejected("invalid_envelope", "")
	if envelope.source_contract_hash != EXPECTED_SOURCE_CONTRACT_SHA256:
		return _rejected("source_contract_mismatch", "")
	var replayed: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(
		envelope.raw_payload,
		_cabt_contracts
	)
	if (
		replayed == null
		or not replayed is RefCounted
		or replayed.envelope == null
		or replayed.envelope.to_host_dict() != envelope.to_host_dict()
		or replayed.safe_diagnostics() != parse_result.safe_diagnostics()
		or bool(replayed.get("policy_eligible")) != bool(parse_result.get("policy_eligible"))
	):
		return _rejected("invalid_envelope", "")
	if not bool(replayed.get("policy_eligible")):
		return _rejected("envelope_not_policy_eligible", "")
	var trusted: Variant = replayed.envelope
	var known: Dictionary = trusted.known_view
	if known.size() != 3 or not known.has("select") or not known.has("logs") or not known.has("current"):
		return _rejected("invalid_envelope", "")
	var select_value: Variant = known.get("select")
	var logs_value: Variant = known.get("logs")
	var current_value: Variant = known.get("current")
	var acting_index: Variant = null
	if select_value == null:
		if current_value != null or not logs_value is Array or not (logs_value as Array).is_empty():
			return _rejected("initial_shape_mismatch", "/select")
	else:
		if not current_value is Dictionary:
			return _rejected("initial_shape_mismatch", "/current")
		var acting: Variant = current_value.get("yourIndex")
		if typeof(acting) != TYPE_INT or int(acting) not in [0, 1]:
			return _rejected("invalid_your_index", "/current/yourIndex")
		acting_index = int(acting)
		var players_value: Variant = current_value.get("players")
		if not players_value is Array or players_value.size() != 2:
			return _rejected("invalid_player_count", "/current/players")
		var players: Array = players_value
		if not players[0] is Dictionary or not players[1] is Dictionary:
			return _rejected("invalid_player_count", "/current/players")
		var opponent_index := 1 - int(acting_index)
		var own: Dictionary = players[int(acting_index)]
		var opponent: Dictionary = players[opponent_index]
		if not own.get("hand") is Array:
			return _rejected("own_hand_not_visible", "/current/players/%d/hand" % acting_index)
		if opponent.get("hand") != null:
			return _rejected("opponent_hand_exposed", "/current/players/%d/hand" % opponent_index)
		for player_index: int in 2:
			var player: Dictionary = players[player_index]
			var prize_value: Variant = player.get("prize")
			if not prize_value is Array:
				return _rejected("prize_identity_exposed", "/current/players/%d/prize" % player_index)
			for prize_card: Variant in prize_value:
				if prize_card != null:
					return _rejected("prize_identity_exposed", "/current/players/%d/prize" % player_index)
		var active_value: Variant = own.get("active")
		if not active_value is Array:
			return _rejected("own_active_concealed", "/current/players/%d/active" % acting_index)
		if not select_value is Dictionary:
			return _rejected("initial_shape_mismatch", "/select")
		var has_concealed_active := false
		for active_card: Variant in active_value:
			if active_card == null:
				has_concealed_active = true
		if has_concealed_active and not (
			allow_setup_bench_concealment
			and _is_exact_setup_bench_concealment(select_value, current_value, own, opponent, active_value)
		):
			return _rejected("own_active_concealed", "/current/players/%d/active" % acting_index)
		if select_value.get("deck") != null and select_value.get("type") != 1:
			return _rejected("unauthorized_select_deck", "/select/deck")
		if not logs_value is Array:
			return _rejected("invalid_envelope", "/logs")
		for index: int in logs_value.size():
			var log_value: Variant = logs_value[index]
			if log_value is Dictionary and log_value.get("type") == 4 and log_value.get("playerIndex") != acting_index:
				return _rejected("opponent_draw_identity_exposed", "/logs/%d" % index)
	var public_tree := {
		"select": _copy_value(select_value),
		"logs": _copy_value(logs_value),
		"current": _copy_value(current_value),
	}
	var presence: Dictionary = trusted.field_presence
	var framework: Dictionary = trusted.framework
	if presence.get("/step") != "missing":
		public_tree["step"] = _copy_value(framework.get("step"))
	if presence.get("/remainingOverageTime") != "missing":
		public_tree["remainingOverageTime"] = _copy_value(framework.get("remaining_overage_time"))
	var provenance_result := _build_provenance(public_tree, acting_index)
	if not bool(provenance_result.get("ok", false)):
		return _rejected(str(provenance_result.get("error_code", "public_projection_limit")), "")
	var hash_result: Dictionary = CabtTreeHashScript.public_observation_hash(public_tree)
	if not bool(hash_result.get("ok", false)):
		return _rejected("public_hash_error", "")
	return {
		"schema_version": SCHEMA_VERSION,
		"profile_id": PROFILE_ID,
		"source_contract_hash": EXPECTED_SOURCE_CONTRACT_SHA256,
		"firewall_contract_hash": EXPECTED_FIREWALL_BUNDLE_SHA256,
		"status": "accepted",
		"public_observation": public_tree,
		"public_observation_hash": str(hash_result.get("sha256", "")),
		"provenance": provenance_result.get("value", []),
		"issues": [],
	}


func _build_provenance(public_tree: Dictionary, acting_index: Variant) -> Dictionary:
	var limits_value: Variant = _profile.get("limits")
	if not limits_value is Dictionary:
		return {"ok": false, "error_code": "firewall_contract_error"}
	var max_records: Variant = limits_value.get("max_provenance_records")
	var max_depth: Variant = limits_value.get("max_public_tree_depth")
	var max_nodes: Variant = limits_value.get("max_public_tree_nodes")
	if (
		typeof(max_records) != TYPE_INT
		or typeof(max_depth) != TYPE_INT
		or typeof(max_nodes) != TYPE_INT
		or int(max_records) < 1
		or int(max_depth) < 0
		or int(max_nodes) < 1
	):
		return {"ok": false, "error_code": "firewall_contract_error"}
	var records := []
	var stack := [{"pointer": "", "value": public_tree, "depth": 0}]
	while not stack.is_empty():
		var current: Dictionary = stack.pop_back()
		var pointer := str(current.get("pointer"))
		var value: Variant = current.get("value")
		var depth := int(current.get("depth"))
		if (
			depth > int(max_depth)
			or records.size() >= int(max_records)
			or records.size() >= int(max_nodes)
		):
			return {"ok": false, "error_code": "public_projection_limit"}
		records.append({
			"output_pointer": pointer,
			"source_pointer": pointer,
			"visibility": _visibility_for(pointer, value, acting_index),
			"authority": "official_cabt_wire",
			"transform": "framework_name_restore" if pointer == "/remainingOverageTime" else "exact_copy",
		})
		if value is Dictionary:
			var keys: Array = value.keys()
			for key_index: int in range(keys.size() - 1, -1, -1):
				var key: Variant = keys[key_index]
				if typeof(key) != TYPE_STRING:
					return {"ok": false, "error_code": "public_hash_error"}
				stack.append({"pointer": _join_pointer(pointer, str(key)), "value": value[key], "depth": depth + 1})
		elif value is Array:
			for index: int in range(value.size() - 1, -1, -1):
				stack.append({"pointer": _join_pointer(pointer, str(index)), "value": value[index], "depth": depth + 1})
	return {"ok": true, "error_code": "", "value": records}


func _validate_result(result: Variant, current_input: Variant) -> bool:
	if not validate_integrity() or result == null or not result is FirewallResult:
		return false
	if result.get("_owner") != self or current_input != result.get("_bound_input"):
		return false
	var snapshot: Variant = result.get("_snapshot")
	if not snapshot is Dictionary or result._unchecked_dict() != snapshot:
		return false
	var recomputed := _evaluate(current_input)
	return recomputed == snapshot


static func _rejected(code: String, pointer: String) -> Dictionary:
	var safe_code := code if STABLE_ERROR_CODES.has(code) else "firewall_contract_error"
	return {
		"schema_version": SCHEMA_VERSION,
		"profile_id": PROFILE_ID,
		"source_contract_hash": EXPECTED_SOURCE_CONTRACT_SHA256,
		"firewall_contract_hash": EXPECTED_FIREWALL_BUNDLE_SHA256,
		"status": "rejected",
		"public_observation": null,
		"public_observation_hash": null,
		"provenance": [],
		"issues": [{"code": safe_code, "pointer": pointer, "severity": "error"}],
	}


static func _visibility_for(pointer: String, value: Variant, acting_index: Variant) -> String:
	var segments: PackedStringArray = pointer.trim_prefix("/").split("/") if not pointer.is_empty() else PackedStringArray()
	if not segments.is_empty() and segments[0] in ["step", "remainingOverageTime"]:
		return "framework_public"
	if segments.size() >= 2 and segments[0] == "select" and segments[1] == "deck":
		return "authorized_window_visible"
	if segments.size() >= 2 and segments[0] == "current" and segments[1] == "looking":
		return "concealed_placeholder" if value == null else "acting_player_visible"
	if segments.size() >= 4 and segments[0] == "current" and segments[1] == "players":
		var player_index := int(segments[2]) if segments[2].is_valid_int() else -1
		var field := segments[3]
		if field == "hand":
			return "acting_player_visible" if player_index == acting_index else "concealed_placeholder"
		if field == "prize":
			return "concealed_placeholder"
		if field == "active" and value == null:
			return "concealed_placeholder"
	return "official_public"


static func _join_pointer(parent: String, segment: String) -> String:
	return "%s/%s" % [parent, segment.replace("~", "~0").replace("/", "~1")]


static func _is_exact_setup_bench_concealment(
	select_value: Dictionary,
	current: Dictionary,
	own: Dictionary,
	opponent: Dictionary,
	active: Array
) -> bool:
	var opponent_active: Variant = opponent.get("active")
	var options_value: Variant = select_value.get("option")
	var expected_select_keys := [
		"type", "context", "minCount", "maxCount", "remainDamageCounter",
		"remainEnergyCost", "option", "deck", "contextCard", "effect",
	]
	return (
		_same_string_keys(select_value, expected_select_keys)
		and active == [null]
		and opponent_active is Array
		and opponent_active == [null]
		and typeof(select_value.get("type")) == TYPE_INT
		and select_value.get("type") == 1
		and typeof(select_value.get("context")) == TYPE_INT
		and select_value.get("context") == 2
		and typeof(select_value.get("minCount")) == TYPE_INT
		and select_value.get("minCount") == 0
		and typeof(select_value.get("maxCount")) == TYPE_INT
		and options_value is Array
		and 0 <= int(select_value.get("maxCount"))
		and int(select_value.get("maxCount")) <= options_value.size()
		and typeof(select_value.get("remainDamageCounter")) == TYPE_INT
		and select_value.get("remainDamageCounter") == 0
		and typeof(select_value.get("remainEnergyCost")) == TYPE_INT
		and select_value.get("remainEnergyCost") == 0
		and select_value.get("deck") == null
		and select_value.get("contextCard") == null
		and select_value.get("effect") == null
		and typeof(current.get("turn")) == TYPE_INT
		and current.get("turn") == 0
		and typeof(current.get("result")) == TYPE_INT
		and current.get("result") == -1
		and own.get("bench") is Array
		and opponent.get("bench") is Array
	)


static func _same_string_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key: Variant in expected:
		if typeof(key) != TYPE_STRING or not value.has(key):
			return false
	return true


static func _copy_value(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value


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


static func _parse_contract_json_bytes(source_bytes: PackedByteArray) -> Dictionary:
	var canonical := CabtJsonTreeScript.canonicalize_artifact_json_bytes(
		source_bytes,
		{"max_input_bytes": MAX_CONTRACT_BYTES, "max_output_bytes": MAX_CONTRACT_BYTES}
	)
	if not bool(canonical.get("ok", false)):
		return {"ok": false, "value": null}
	var text := source_bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != source_bytes:
		return {"ok": false, "value": null}
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {"ok": false, "value": null}
	var state := {"ok": true}
	var restored: Variant = _restore_integer_tokens(parser.data, state)
	if not bool(state.get("ok", false)) or not restored is Dictionary:
		return {"ok": false, "value": null}
	return {"ok": true, "value": restored}


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


static func _canonical_artifact_sha256(source_bytes: PackedByteArray) -> String:
	var canonical := CabtJsonTreeScript.canonicalize_artifact_json_bytes(
		source_bytes,
		{"max_input_bytes": MAX_CONTRACT_BYTES, "max_output_bytes": MAX_CONTRACT_BYTES}
	)
	if not bool(canonical.get("ok", false)):
		return ""
	return _raw_sha256(canonical.get("bytes", PackedByteArray()))


static func _canonical_value_sha256(value: Variant) -> String:
	var canonical := CabtJsonTreeScript.canonicalize_artifact(
		value,
		{"max_input_bytes": MAX_CONTRACT_BYTES, "max_output_bytes": MAX_CONTRACT_BYTES}
	)
	if not bool(canonical.get("ok", false)):
		return ""
	return _raw_sha256(canonical.get("bytes", PackedByteArray()))


static func _raw_sha256(source_bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(source_bytes) != OK:
		return ""
	return context.finish().hex_encode().to_upper()
