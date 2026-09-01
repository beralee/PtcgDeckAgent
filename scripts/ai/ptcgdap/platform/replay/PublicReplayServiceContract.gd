class_name PtcgDAPPublicReplayServiceContract
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")

const CONTRACT_PATH := "res://contracts/ptcgdap/public_replay_service_contract.json"
const EXPECTED_CANONICAL_SHA256 := "9558738C24FFF4D9D4C80D7BFC0FFD68A1536666E0696BCFD1193CC18A2066C4"
const MAX_CONTRACT_BYTES := 64 * 1024
const COMMUNITY_LANE := "community_challenge"


static func load_fixed() -> Dictionary:
	if not FileAccess.file_exists(CONTRACT_PATH):
		return _failure("service_contract_invalid")
	var file := FileAccess.open(CONTRACT_PATH, FileAccess.READ)
	if file == null:
		return _failure("service_contract_invalid")
	var length := file.get_length()
	if length < 1 or length > MAX_CONTRACT_BYTES:
		file.close()
		return _failure("service_contract_invalid")
	var source := file.get_buffer(length)
	file.close()
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact_json_bytes(
		source,
		{"max_input_bytes": MAX_CONTRACT_BYTES, "max_output_bytes": MAX_CONTRACT_BYTES}
	)
	if not bool(canonical.get("ok", false)):
		return _failure("service_contract_invalid")
	var canonical_sha256 := _sha256(canonical.get("bytes", PackedByteArray()))
	if canonical_sha256 != EXPECTED_CANONICAL_SHA256:
		return _failure("service_contract_trust_anchor_mismatch")
	var json := JSON.new()
	if json.parse(source.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return _failure("service_contract_invalid")
	var value: Dictionary = coerce_integral_numbers(json.data)
	if (
		value.get("document_type") != "public_replay_service_contract_v1"
		or value.get("schema_version") != 1
		or value.get("ingest", {}).get("accepted_lanes") != [COMMUNITY_LANE]
		or value.get("ingest", {}).get("server_revalidates_envelope_manifest_and_complete_frame_chain") != true
		or int(value.get("ingest", {}).get("max_upload_bytes", 0)) < 1
		or int(value.get("ingest", {}).get("max_response_bytes", 0)) < 1
		or value.get("authentication", {}).get("profile") != "temporary_bearer_env_v1"
		or value.get("authentication", {}).get("persist_token") != false
		or value.get("authentication", {}).get("production_ready") != false
		or value.get("transport", {}).get("remote_inference") != false
		or value.get("authority", {}).get("authoritative") != false
		or value.get("authority", {}).get("grants") != []
	):
		return _failure("service_contract_invalid")
	return {
		"accepted": true,
		"error_code": "",
		"value": value,
		"canonical_sha256": canonical_sha256,
		"authoritative": false,
		"grants": [],
	}


static func validate_endpoint(
	base_url: String,
	allow_insecure_loopback: bool,
	development_insecure_hosts: Array
) -> String:
	var value := base_url.trim_suffix("/")
	if value.begins_with("https://"):
		return "" if _valid_authority(value.trim_prefix("https://")) else "upload_endpoint_invalid"
	if allow_insecure_loopback and value.begins_with("http://"):
		var authority := value.trim_prefix("http://")
		var host := authority.get_slice(":", 0)
		if host in development_insecure_hosts and _valid_authority(authority):
			return ""
	return "upload_endpoint_insecure"


static func valid_temporary_token(value: String) -> bool:
	if value.length() < 32 or value.length() > 256:
		return false
	for index: int in value.length():
		var code := value.unicode_at(index)
		if not (
			(code >= 48 and code <= 57)
			or (code >= 65 and code <= 90)
			or (code >= 97 and code <= 122)
			or code in [45, 46, 95, 126]
		):
			return false
	return true


static func safe_replay_id(value: String) -> bool:
	if value.is_empty() or value.length() > 128 or value != value.strip_edges():
		return false
	for index: int in value.length():
		var code := value.unicode_at(index)
		if not (
			(code >= 48 and code <= 57)
			or (code >= 65 and code <= 90)
			or (code >= 97 and code <= 122)
			or code in [45, 46, 95]
		):
			return false
	return true


static func coerce_integral_numbers(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value):
		return int(value)
	if value is Array:
		var array_result: Array = []
		for child: Variant in value:
			array_result.append(coerce_integral_numbers(child))
		return array_result
	if value is Dictionary:
		var dictionary_result := {}
		for key: Variant in value:
			dictionary_result[key] = coerce_integral_numbers(value[key])
		return dictionary_result
	return value


static func sha256(source: PackedByteArray) -> String:
	return _sha256(source)


static func _valid_authority(authority: String) -> bool:
	if authority.is_empty() or authority.contains("/") or authority.contains("?") \
			or authority.contains("#") or authority.contains("@"):
		return false
	var parts := authority.split(":", false)
	if parts.size() < 1 or parts.size() > 2:
		return false
	var host := str(parts[0])
	if host.is_empty() or host.begins_with(".") or host.ends_with("."):
		return false
	for index: int in host.length():
		var code := host.unicode_at(index)
		if not (
			(code >= 48 and code <= 57)
			or (code >= 65 and code <= 90)
			or (code >= 97 and code <= 122)
			or code in [45, 46]
		):
			return false
	if parts.size() == 2:
		var port := str(parts[1])
		if port.is_empty() or not port.is_valid_int():
			return false
		var port_value := int(port)
		if port_value < 1 or port_value > 65_535:
			return false
	return true


static func _sha256(source: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(source) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


static func _failure(code: String) -> Dictionary:
	return {"accepted": false, "error_code": code, "authoritative": false, "grants": []}
