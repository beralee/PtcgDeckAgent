class_name PtcgDAPStrategyPlatformServiceContract
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const ReplayServiceContractScript = preload("res://scripts/ai/ptcgdap/platform/replay/PublicReplayServiceContract.gd")

const CONTRACT_PATH := "res://contracts/ptcgdap/strategy_platform_service_contract.json"
const EXPECTED_CANONICAL_SHA256 := "3C9910759750649CD446BD9491E1427AB42762EA348E77354A66E54F0959B9A0"
const MAX_CONTRACT_BYTES := 64 * 1024


static func load_fixed() -> Dictionary:
	if not FileAccess.file_exists(CONTRACT_PATH):
		return _failure("platform_service_contract_invalid")
	var file := FileAccess.open(CONTRACT_PATH, FileAccess.READ)
	if file == null:
		return _failure("platform_service_contract_invalid")
	var length := file.get_length()
	if length < 1 or length > MAX_CONTRACT_BYTES:
		file.close()
		return _failure("platform_service_contract_invalid")
	var source := file.get_buffer(length)
	file.close()
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact_json_bytes(
		source, {"max_input_bytes": MAX_CONTRACT_BYTES, "max_output_bytes": MAX_CONTRACT_BYTES}
	)
	if not bool(canonical.get("ok", false)):
		return _failure("platform_service_contract_invalid")
	var digest := sha256(canonical.get("bytes", PackedByteArray()))
	if digest != EXPECTED_CANONICAL_SHA256:
		return _failure("platform_service_contract_trust_anchor_mismatch")
	var json := JSON.new()
	if json.parse(source.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return _failure("platform_service_contract_invalid")
	var value: Dictionary = ReplayServiceContractScript.coerce_integral_numbers(json.data)
	if (
		value.get("document_type") != "strategy_platform_service_contract_v1"
		or value.get("schema_version") != 1
		or value.get("authentication", {}).get("profile") != "temporary_bearer_env_v1"
		or value.get("authentication", {}).get("persist_token") != false
		or value.get("authentication", {}).get("production_ready") != false
		or value.get("challenge", {}).get("server_metadata_grants_runtime_authority") != false
		or value.get("release_registry", {}).get("compatibility_states") != ["compatible", "incompatible"]
		or value.get("storage", {}).get("online_sqlite_backup_supported") != true
		or value.get("storage", {}).get("instrumentation_raw_retention_days") != 30
		or value.get("statistics", {}).get("official_requires_production_evaluator_authority") != true
		or value.get("marketplace", {}).get("rank_transfer") != "explicit_verified_binding_only"
		or value.get("marketplace", {}).get("ranking_snapshot_required") != true
		or value.get("marketplace", {}).get("profile_discovery") != "unique_active_fail_closed"
		or value.get("marketplace", {}).get("latest_source_artifact_domains") \
			!= ["competition_ptcgbot", "device_ptcgai"]
		or value.get("marketplace", {}).get("download_artifact_domain") != "device_ptcgai"
		or value.get("marketplace", {}).get("ranking_artifact_domain") != "competition_ptcgbot"
		or value.get("marketplace", {}).get("strategy_archive_recent_match_limit") != 20
		or value.get("marketplace", {}).get("author_top_strategy_limit") != 5
		or value.get("marketplace", {}).get("one_click_play_requires_verified_device_binding") != true
		or value.get("marketplace", {}).get("player_runtime_authority") != false
		or value.get("transport", {}).get("remote_inference") != false
		or value.get("authority", {}).get("authoritative") != false
		or value.get("authority", {}).get("current_window_authority") != false
		or value.get("authority", {}).get("engine_authority") != false
		or value.get("authority", {}).get("grants") != []
	):
		return _failure("platform_service_contract_invalid")
	return {
		"accepted": true,
		"error_code": "",
		"value": value,
		"canonical_sha256": digest,
		"authoritative": false,
		"grants": [],
	}


static func validate_endpoint(base_url: String, allow_insecure_loopback: bool) -> String:
	var loaded := load_fixed()
	if not bool(loaded.get("accepted", false)):
		return str(loaded.get("error_code", "platform_service_contract_invalid"))
	return ReplayServiceContractScript.validate_endpoint(
		base_url,
		allow_insecure_loopback,
		loaded.get("value", {}).get("transport", {}).get("development_insecure_hosts", []),
	).replace("upload_", "platform_")


static func safe_identifier(value: Variant, maximum_length: int = 128) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var text := str(value)
	if text.is_empty() or text.length() > maximum_length or text != text.strip_edges():
		return false
	for index: int in text.length():
		var code := text.unicode_at(index)
		if not (
			(code >= 48 and code <= 57)
			or (code >= 65 and code <= 90)
			or (code >= 97 and code <= 122)
			or code in [45, 46, 58, 95]
		):
			return false
	return true


static func valid_sha256(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 64:
		return false
	for index: int in str(value).length():
		var code := str(value).unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 70)):
			return false
	return true


static func valid_temporary_token(value: String) -> bool:
	return ReplayServiceContractScript.valid_temporary_token(value)


static func coerce_integral_numbers(value: Variant) -> Variant:
	return ReplayServiceContractScript.coerce_integral_numbers(value)


static func sha256(source: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(source) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


static func failure(code: String) -> Dictionary:
	return _failure(code)


static func _failure(code: String) -> Dictionary:
	return {"accepted": false, "error_code": code, "authoritative": false, "grants": []}
