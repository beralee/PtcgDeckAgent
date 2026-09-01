class_name MarnieVerticalSlice
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")

const DEFAULT_ROOT := "res://"
const MAX_JSON_BYTES := 2 * 1024 * 1024
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const EXPECTED_BUNDLE_CANONICAL_SHA256 := "7E0CF80D7B2872C29F69BA15548857F1F32407943371D3C12A266A0E471EC425"
const EXPECTED_RUNTIME_INTEGRITY_SHA256 := "B0559C5A404EB22058E4A21C28F17F4ADFEB8BA4B894A1FCBBA3DFACF65FCDE0"
const EXPECTED_BUNDLE_PATH := "contracts/ptcgdap/marnie_vertical_slice_bundle.json"
const EXPECTED_ARTIFACTS := [
	["marnie_vertical_slice.schema", "contracts/ptcgdap/marnie_vertical_slice.schema.json", "schema"],
	["marnie_vertical_slice_profile", "contracts/ptcgdap/marnie_vertical_slice_profile.json", "profile"],
	["marnie_vertical_slice_source_manifest", "contracts/ptcgdap/marnie_vertical_slice_source_manifest.json", "source_manifest"],
	["marnie_vertical_slice_conformance_vectors", "contracts/ptcgdap/marnie_vertical_slice_conformance_vectors.json", "vectors"],
	["official_deck_manifest_v1", "data/ptcgdap/marnie_vertical_slice/official_deck_manifest_v1.json", "official_deck"],
	["local_deck_manifest_v1", "data/ptcgdap/marnie_vertical_slice/local_deck_manifest_v1.json", "local_deck"],
	["deck_identity_diff_v1", "data/ptcgdap/marnie_vertical_slice/deck_identity_diff_v1.json", "deck_diff"],
	["capability_inventory_v1", "data/ptcgdap/marnie_vertical_slice/capability_inventory_v1.json", "capabilities"],
	["w0_w7_public_trajectory_v1", "data/ptcgdap/marnie_vertical_slice/w0_w7_public_trajectory_v1.json", "trajectory"],
]

var _ok := false
var _error_code := "fixture_bundle_invalid"
var _bundle: Variant = {}
var _schema: Variant = {}
var _profile: Variant = {}
var _source_manifest: Variant = {}
var _vectors: Variant = {}
var _official_deck: Variant = {}
var _local_deck: Variant = {}
var _deck_diff: Variant = {}
var _capabilities: Variant = {}
var _trajectory: Variant = {}
var _runtime_integrity_sha256 := ""
var _load_attempted := false

var ok: bool:
	get:
		return _ok and validate_integrity()

var error_code: String:
	get:
		return "" if ok else _error_code


static func load_default() -> Variant:
	return load_from_root(DEFAULT_ROOT)


static func load_from_root(root_path: Variant) -> Variant:
	var script: GDScript = load("res://scripts/ai/ptcgdap/public/MarnieVerticalSlice.gd")
	var result: RefCounted = script.new()
	if typeof(root_path) != TYPE_STRING:
		result._load_attempted = true
		result._fail("fixture_path_invalid")
		return result
	result._load(str(root_path))
	return result


func _load(root_path: String) -> void:
	if _load_attempted:
		return
	_load_attempted = true
	var root := root_path.trim_suffix("/") + "/"
	if root == "/" or not _root_is_supported(root):
		_fail("fixture_path_invalid")
		return
	var bundle_result := _read_json("%s%s" % [root, EXPECTED_BUNDLE_PATH])
	if not bool(bundle_result.get("ok", false)):
		_fail(str(bundle_result.get("error_code", "fixture_bundle_invalid")))
		return
	var bundle: Variant = bundle_result.get("value")
	if not bundle is Dictionary or _canonical_sha256(bundle) != EXPECTED_BUNDLE_CANONICAL_SHA256:
		_fail("fixture_bundle_trust_anchor_mismatch")
		return
	if (
		bundle.get("bundle_id") != "ptcgdap-marnie-vertical-slice-p5-wp1-v1"
		or bundle.get("status") != "offline_shadow_fixture"
		or not bundle.get("artifacts") is Array
		or bundle.get("artifacts").size() != EXPECTED_ARTIFACTS.size()
	):
		_fail("fixture_bundle_invalid")
		return
	var documents := {"bundle": (bundle as Dictionary).duplicate(true)}
	var seen_paths := {}
	for index: int in range(EXPECTED_ARTIFACTS.size()):
		var entry_value: Variant = bundle.get("artifacts")[index]
		var expected: Array = EXPECTED_ARTIFACTS[index]
		if not entry_value is Dictionary:
			_fail("fixture_bundle_invalid")
			return
		var entry: Dictionary = entry_value
		if entry.keys().size() != 3 or not entry.has("id") or not entry.has("path") or not entry.has("canonical_sha256"):
			_fail("fixture_bundle_invalid")
			return
		if typeof(entry.get("id")) != TYPE_STRING or typeof(entry.get("path")) != TYPE_STRING or typeof(entry.get("canonical_sha256")) != TYPE_STRING:
			_fail("fixture_bundle_invalid")
			return
		if entry.get("id") != expected[0] or entry.get("path") != expected[1] or seen_paths.has(entry.get("path")):
			_fail("fixture_bundle_invalid")
			return
		if not _is_safe_relative_path(str(entry.get("path"))):
			_fail("fixture_path_invalid")
			return
		seen_paths[entry.get("path")] = true
		var artifact_result := _read_json("%s%s" % [root, entry.get("path")])
		if not bool(artifact_result.get("ok", false)):
			_fail(str(artifact_result.get("error_code", "fixture_artifact_invalid")))
			return
		var artifact: Variant = artifact_result.get("value")
		if _canonical_sha256(artifact) != entry.get("canonical_sha256"):
			_fail("fixture_artifact_hash_mismatch")
			return
		documents[expected[2]] = _copy(artifact)
	if documents.size() != 10:
		_fail("fixture_bundle_invalid")
		return
	_bundle = documents["bundle"]
	_schema = documents["schema"]
	_profile = documents["profile"]
	_source_manifest = documents["source_manifest"]
	_vectors = documents["vectors"]
	_official_deck = documents["official_deck"]
	_local_deck = documents["local_deck"]
	_deck_diff = documents["deck_diff"]
	_capabilities = documents["capabilities"]
	_trajectory = documents["trajectory"]
	_runtime_integrity_sha256 = _runtime_digest()
	if _runtime_integrity_sha256 != EXPECTED_RUNTIME_INTEGRITY_SHA256:
		_fail("fixture_integrity_invalid")
		return
	_ok = true
	_error_code = ""


func _fail(code: String) -> void:
	_ok = false
	_error_code = code


func validate_integrity() -> bool:
	if not _ok or _runtime_integrity_sha256 != EXPECTED_RUNTIME_INTEGRITY_SHA256:
		return false
	return _runtime_digest() == EXPECTED_RUNTIME_INTEGRITY_SHA256


func bundle_hash() -> String:
	return EXPECTED_BUNDLE_CANONICAL_SHA256 if validate_integrity() else ""


func audit_snapshot() -> Dictionary:
	if not validate_integrity():
		return {}
	return {
		"bundle_canonical_sha256": EXPECTED_BUNDLE_CANONICAL_SHA256,
		"artifact_count": EXPECTED_ARTIFACTS.size(),
		"frame_count": _trajectory.get("frames", []).size(),
		"capability_count": _capabilities.get("capabilities", []).size(),
		"execution_authority": false,
		"live_consumer": false,
	}


func frame(frame_id: Variant) -> Dictionary:
	if not validate_integrity() or typeof(frame_id) != TYPE_STRING:
		return {}
	for frame_value: Variant in _trajectory.get("frames", []):
		if frame_value is Dictionary and frame_value.get("frame_id") == frame_id:
			return frame_value.duplicate(true)
	return {}


func run(operation: Variant, input_value: Variant) -> Dictionary:
	if not validate_integrity():
		return _result(null, "fixture_integrity_invalid")
	if typeof(operation) != TYPE_STRING or not input_value is Dictionary:
		return _result(null, "input_type_invalid")
	if operation == "official_summary" or operation == "local_summary" or operation == "identity_summary":
		if not input_value.is_empty():
			return _result(null, "input_type_invalid")
		if operation == "official_summary":
			return _result({
				"card_count": _official_deck.get("card_count"),
				"unique_card_id_count": _official_deck.get("unique_card_id_count"),
				"cabt_exportable": _official_deck.get("cabt_exportable"),
			})
		if operation == "local_summary":
			return _result({
				"card_count": _local_deck.get("card_count"),
				"unique_printing_count": _local_deck.get("unique_printing_count"),
				"cabt_exportable": _local_deck.get("cabt_exportable"),
			})
		return _result({
			"same_deck": _deck_diff.get("same_deck"),
			"official_bridged": _deck_diff.get("official", {}).get("bridged_card_count"),
			"official_unmapped": _deck_diff.get("official", {}).get("unmapped_card_count"),
			"local_bridged": _deck_diff.get("local", {}).get("bridged_card_count"),
			"local_unbridged": _deck_diff.get("local", {}).get("unbridged_card_count"),
		})
	if operation == "frame_summary":
		if input_value.keys().size() != 1 or not input_value.has("frame_id") or typeof(input_value.get("frame_id")) != TYPE_STRING:
			return _result(null, "input_type_invalid")
		var selected := frame(input_value.get("frame_id"))
		if selected.is_empty():
			return _result(null, "frame_unknown")
		var window_value: Variant = selected.get("window")
		return _result({
			"family": selected.get("window_family"),
			"firewall_status": selected.get("current_firewall", {}).get("status"),
			"issue_code": selected.get("current_firewall", {}).get("issue_code"),
			"window_state": window_value.get("decision_state") if window_value is Dictionary else null,
		})
	if operation == "capability":
		if input_value.keys().size() != 1 or not input_value.has("capability_id") or typeof(input_value.get("capability_id")) != TYPE_STRING:
			return _result(null, "input_type_invalid")
		for capability_value: Variant in _capabilities.get("capabilities", []):
			if capability_value is Dictionary and capability_value.get("capability_id") == input_value.get("capability_id"):
				return _result({
					"window_family": capability_value.get("window_family"),
					"portable_ready": capability_value.get("portable_ready"),
				})
		return _result(null, "capability_unknown")
	return _result(null, "operation_unknown")


func _runtime_digest() -> String:
	if not (
		_bundle is Dictionary and _schema is Dictionary and _profile is Dictionary
		and _source_manifest is Dictionary and _vectors is Dictionary
		and _official_deck is Dictionary and _local_deck is Dictionary
		and _deck_diff is Dictionary and _capabilities is Dictionary
		and _trajectory is Dictionary
	):
		return ""
	return _canonical_sha256({
		"bundle": _copy(_bundle),
		"schema": _copy(_schema),
		"profile": _copy(_profile),
		"source_manifest": _copy(_source_manifest),
		"vectors": _copy(_vectors),
		"official_deck": _copy(_official_deck),
		"local_deck": _copy(_local_deck),
		"deck_diff": _copy(_deck_diff),
		"capabilities": _copy(_capabilities),
		"trajectory": _copy(_trajectory),
	})


static func _result(value: Variant, error: String = "") -> Dictionary:
	return {
		"ok": error.is_empty(),
		"error_code": error,
		"value": _copy(value) if error.is_empty() else null,
	}


static func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value


static func _root_is_supported(root: String) -> bool:
	return root.begins_with("res://") or root.begins_with("user://")


static func _is_safe_relative_path(path: String) -> bool:
	return (
		not path.is_empty()
		and not path.begins_with("/")
		and not path.contains("\\")
		and not path.split("/").has("..")
		and not path.split("/").has(".")
	)


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error_code": "fixture_file_missing", "value": null}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error_code": "fixture_file_missing", "value": null}
	var length := file.get_length()
	if length < 1 or length > MAX_JSON_BYTES:
		return {"ok": false, "error_code": "fixture_file_too_large", "value": null}
	var source_bytes := file.get_buffer(length)
	var canonical := CabtJsonTreeScript.canonicalize_artifact_json_bytes(
		source_bytes,
		{"max_input_bytes": MAX_JSON_BYTES, "max_output_bytes": MAX_JSON_BYTES}
	)
	if not bool(canonical.get("ok", false)):
		return {"ok": false, "error_code": "fixture_json_invalid", "value": null}
	var text := source_bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != source_bytes:
		return {"ok": false, "error_code": "fixture_json_invalid", "value": null}
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {"ok": false, "error_code": "fixture_json_invalid", "value": null}
	var state := {"ok": true}
	var restored: Variant = _restore_integer_tokens(parser.data, state)
	if not bool(state.get("ok", false)) or not restored is Dictionary:
		return {"ok": false, "error_code": "fixture_json_invalid", "value": null}
	return {"ok": true, "error_code": "", "value": restored}


static func _restore_integer_tokens(value: Variant, state: Dictionary) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var number := float(value)
			if not is_finite(number) or number != floorf(number) or number < -float(MAX_SAFE_INTEGER) or number > float(MAX_SAFE_INTEGER):
				state["ok"] = false
				return null
			return int(number)
		TYPE_ARRAY:
			var result := []
			for child: Variant in value:
				result.append(_restore_integer_tokens(child, state))
				if not bool(state.get("ok", false)):
					return null
			return result
		TYPE_DICTIONARY:
			var result := {}
			for key: Variant in value:
				if typeof(key) != TYPE_STRING:
					state["ok"] = false
					return null
				result[key] = _restore_integer_tokens(value[key], state)
				if not bool(state.get("ok", false)):
					return null
			return result
		_:
			return value


static func _canonical_sha256(value: Variant) -> String:
	var canonical := CabtJsonTreeScript.canonicalize_artifact(
		value,
		{"max_input_bytes": MAX_JSON_BYTES, "max_output_bytes": MAX_JSON_BYTES}
	)
	if not bool(canonical.get("ok", false)):
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(canonical.get("bytes", PackedByteArray())) != OK:
		return ""
	return context.finish().hex_encode().to_upper()
