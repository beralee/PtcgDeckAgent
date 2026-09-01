extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const PROFILE_ID := "ptcgdap-author-strategy-match-host-as-wp4-v1"
const BACKEND_ID := "gdscript_public_base_policy_v1"
const BACKEND_SHA256 := "18AAB663D9B429AC8657A75692F5DD8CF37C409CC057A328B57758C692FDB7F4"
const REQUIRED_PAYLOADS := [
	"strategy_package.json",
	"deck/deck_manifest.json",
	"deck/deck.csv",
	"policy/policy_ir.json",
	"policy/adapter.json",
	"policy/config.json",
]
static var _FACTORY_TOKEN: RefCounted = RefCounted.new()

var _metadata: Dictionary = {}
var _payloads: Dictionary = {}
var _local_deck: Array = []
var _pins: Dictionary = {}
var _sealed_hash := ""
var _factory_token: Variant = null
var _claimed_match_id := ""


static func create(metadata: Variant, payloads: Variant, local_deck: Variant) -> Dictionary:
	if not metadata is Dictionary or not payloads is Dictionary or not local_deck is Array:
		return _error("package_integrity_invalid")
	var script: GDScript = load("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageHandle.gd")
	var handle: Variant = script.new(metadata, payloads, local_deck, _FACTORY_TOKEN)
	if handle == null or not handle.validate_integrity():
		return _error("package_integrity_invalid")
	return {"ok": true, "error_code": "", "handle": handle}


func _init(metadata: Dictionary = {}, payloads: Dictionary = {}, local_deck: Array = [], token: Variant = null) -> void:
	if token != _FACTORY_TOKEN:
		return
	_metadata = metadata.duplicate(true)
	_payloads = payloads.duplicate(true)
	_local_deck = local_deck.duplicate(true)
	_factory_token = token
	_pins = _build_pins()
	_sealed_hash = _integrity_hash()


func validate_integrity() -> bool:
	if _factory_token != _FACTORY_TOKEN or _sealed_hash.is_empty():
		return false
	if not _metadata is Dictionary or not _payloads is Dictionary or not _local_deck is Array or not _pins is Dictionary:
		return false
	for path in REQUIRED_PAYLOADS:
		if not _payloads.get(path) is PackedByteArray:
			return false
	if _local_deck.is_empty() or _pins != _build_pins():
		return false
	return _sealed_hash == _integrity_hash()


func to_public_dict() -> Dictionary:
	return _pins.duplicate(true) if validate_integrity() else {}


func local_deck_snapshot() -> Array:
	return _local_deck.duplicate(true) if validate_integrity() else []


func presentation_snapshot() -> Dictionary:
	return _build_presentation_snapshot().duplicate(true) if validate_integrity() else {}


func claim_for_match(match_id: String) -> Dictionary:
	if not validate_integrity():
		return _error("package_integrity_invalid")
	if not _claimed_match_id.is_empty():
		return _error("package_handle_already_claimed")
	_claimed_match_id = match_id
	return {"ok": true, "error_code": ""}


func policy_documents() -> Dictionary:
	if not validate_integrity():
		return _error("package_integrity_invalid")
	var result := {}
	for path in ["policy/policy_ir.json", "policy/adapter.json", "policy/config.json"]:
		var parsed: Variant = JSON.parse_string((_payloads[path] as PackedByteArray).get_string_from_utf8())
		parsed = _coerce_integral_numbers(parsed)
		if not parsed is Dictionary:
			return _error("package_policy_unsupported")
		result[path] = parsed
	return {"ok": true, "error_code": "", "documents": result}


func policy_weights_payload() -> Dictionary:
	if not validate_integrity():
		return _error("package_integrity_invalid")
	var payload: Variant = _payloads.get("policy/weights.bin")
	if not payload is PackedByteArray:
		return _error("package_file_missing")
	return {
		"ok": true,
		"error_code": "",
		"payload": (payload as PackedByteArray).duplicate(),
		"sha256": _sha(payload),
	}


func model_payloads() -> Dictionary:
	if not validate_integrity():
		return _error("package_integrity_invalid")
	var mode := str(_metadata.get("policy_mode", "rules_only"))
	if mode == "rules_only":
		return {"ok": true, "error_code": "", "policy_mode": mode, "model_manifest": null, "actor_ort": PackedByteArray()}
	if mode != "rules_with_model" or not _payloads.get("model/model_manifest.json") is PackedByteArray or not _payloads.get("model/actor.ort") is PackedByteArray:
		return _error("package_model_relation_invalid")
	var manifest: Variant = JSON.parse_string((_payloads["model/model_manifest.json"] as PackedByteArray).get_string_from_utf8())
	manifest = _coerce_integral_numbers(manifest)
	if not manifest is Dictionary:
		return _error("model_manifest_invalid")
	return {
		"ok": true,
		"error_code": "",
		"policy_mode": mode,
		"model_manifest": manifest,
		"actor_ort": (_payloads["model/actor.ort"] as PackedByteArray).duplicate(),
		"model_manifest_sha256": _metadata.get("model_manifest_sha256"),
		"model_artifact_sha256": _metadata.get("model_artifact_sha256"),
	}


func _build_pins() -> Dictionary:
	if not _metadata is Dictionary or not _payloads is Dictionary or not _local_deck is Array:
		return {}
	var compatibility: Variant = _metadata.get("compatibility")
	if not compatibility is Dictionary:
		return {}
	var weights_sha: Variant = null
	var deck_manifest: Variant = JSON.parse_string((_payloads.get("deck/deck_manifest.json", PackedByteArray()) as PackedByteArray).get_string_from_utf8())
	deck_manifest = _coerce_integral_numbers(deck_manifest)
	if not deck_manifest is Dictionary:
		return {}
	if _payloads.get("policy/weights.bin") is PackedByteArray:
		weights_sha = _sha(_payloads.get("policy/weights.bin"))
	var result := {
		"schema_version": 1,
		"profile_id": PROFILE_ID,
		"package_id": _metadata.get("package_id"),
		"package_version": _metadata.get("package_version"),
		"package_document_type": _metadata.get("package_document_type", "strategy_package_v1"),
		"package_schema_version": _metadata.get("package_schema_version", 1),
		"archive_sha256": _metadata.get("archive_sha256"),
		"manifest_sha256": _metadata.get("manifest_sha256"),
		"manifest_canonical_sha256": _metadata.get("manifest_canonical_sha256"),
		"files_manifest_sha256": _metadata.get("files_manifest_sha256"),
		"cabt_contract_sha256": compatibility.get("cabt_contract_sha256"),
		"card_catalog_sha256": compatibility.get("card_catalog_sha256"),
		"base_executor_sha256": compatibility.get("base_executor_sha256"),
		"policy_ir_sha256": _metadata.get("policy_ir_sha256"),
		"adapter_sha256": _sha(_payloads.get("policy/adapter.json", PackedByteArray())),
		"config_sha256": _sha(_payloads.get("policy/config.json", PackedByteArray())),
		"weights_sha256": weights_sha,
		"policy_mode": _metadata.get("policy_mode", "rules_only"),
		"model_manifest_sha256": _metadata.get("model_manifest_sha256"),
		"model_artifact_sha256": _metadata.get("model_artifact_sha256"),
		"backend_id": BACKEND_ID,
		"backend_sha256": BACKEND_SHA256,
		"deck_manifest_sha256": _metadata.get("deck_manifest_sha256"),
		"deck_csv_sha256": _sha(_payloads.get("deck/deck.csv", PackedByteArray())),
		"deck_card_id_domain": deck_manifest.get("card_id_domain"),
		"source_deck_id": deck_manifest.get("source_deck_id"),
		"deck_platform_scope": deck_manifest.get("platform_scope", []).duplicate(true) if deck_manifest.get("platform_scope", []) is Array else [],
		"cabt_exportable": deck_manifest.get("cabt_exportable"),
		"local_deck_mapping_sha256": _canonical_hash(_local_deck),
		"local_deck_card_count": _deck_count(),
		"local_deck_unique_printing_count": _local_deck.size(),
		"signature_status": _metadata.get("signature_status"),
		"signature_key_id": _metadata.get("signature_key_id"),
		"signature_scope": _metadata.get(
			"signature_scope",
			"test_fixture_only" if _metadata.get("signature_status") == "test_fixture_trusted" else null
		),
		"execution_trusted": bool(_metadata.get("execution_trusted", false)),
		"development_shadow_ready": _metadata.get("signature_status") == "test_fixture_trusted" and not bool(_metadata.get("execution_trusted", false)),
		"live_authority": false,
	}
	if _metadata.get("server_competition_candidate") is Dictionary:
		result["server_competition_candidate"] = _metadata.get(
			"server_competition_candidate"
		).duplicate(true)
	return result


func _deck_count() -> int:
	var total := 0
	for row_value in _local_deck:
		if row_value is Dictionary:
			total += int(row_value.get("count", 0))
	return total


func _integrity_hash() -> String:
	var payload_hashes := {}
	for path in _payloads:
		if _payloads[path] is PackedByteArray:
			payload_hashes[path] = _sha(_payloads[path])
	return _canonical_hash({
		"pins": _pins,
		"presentation": _build_presentation_snapshot(),
		"local_deck": _local_deck,
		"payload_hashes": payload_hashes,
	})


func _build_presentation_snapshot() -> Dictionary:
	if not _metadata is Dictionary:
		return {}
	var author: Variant = _metadata.get("author")
	var strategy: Variant = _metadata.get("strategy")
	var deck: Variant = _metadata.get("deck")
	if not author is Dictionary or not strategy is Dictionary or not deck is Dictionary:
		return {}
	var author_name := _clean_display_text(author.get("display_name", ""))
	var strategy_name := _clean_display_text(strategy.get("display_name", ""))
	var deck_name := _clean_display_text(deck.get("display_name", ""))
	var package_version := _clean_display_text(_metadata.get("package_version", ""))
	if author_name.is_empty() or strategy_name.is_empty() or deck_name.is_empty() \
			or package_version.is_empty():
		return {}
	return {
		"author_name": author_name,
		"strategy_name": strategy_name,
		"deck_name": deck_name,
		"package_version": package_version,
	}


func _clean_display_text(value: Variant) -> String:
	var raw := str(value)
	var result := ""
	var previous_space := false
	for index: int in raw.length():
		var code := raw.unicode_at(index)
		if code < 32 or code == 127:
			if not previous_space and not result.is_empty():
				result += " "
			previous_space = true
			continue
		result += String.chr(code)
		previous_space = code == 32
		if result.length() >= 120:
			break
	return result.strip_edges()


static func _canonical_hash(value: Variant) -> String:
	var parsed: Dictionary = CabtJsonTreeScript.canonicalize_artifact_json_bytes(JSON.stringify(value).to_utf8_buffer())
	return _sha(parsed.get("bytes", PackedByteArray())) if bool(parsed.get("ok", false)) else ""


static func _coerce_integral_numbers(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT and is_equal_approx(float(value), floor(float(value))):
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


static func _sha(value: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value)
	return context.finish().hex_encode().to_upper()


static func _error(code: String) -> Dictionary:
	return {"ok": false, "error_code": code, "handle": null}
