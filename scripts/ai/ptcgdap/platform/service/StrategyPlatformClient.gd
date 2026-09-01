class_name PtcgDAPStrategyPlatformClient
extends Node

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const ContractScript = preload("res://scripts/ai/ptcgdap/platform/service/StrategyPlatformServiceContract.gd")

const MAX_JSON_RESPONSE_BYTES := 4 * 1024 * 1024
const MAX_PACKAGE_RESPONSE_BYTES := 16 * 1024 * 1024
const CONTINUOUS_LADDER_PROFILE_ID := "godot_v18_ladder_v1"
const CONTINUOUS_LADDER_LEADERBOARD_PATH := "/v1/ladder/leaderboard"
const CONTINUOUS_LADDER_AUTHORS_PATH := "/v1/ladder/authors"
const CONTINUOUS_LADDER_RELEASE_PREFIX := "/v1/ladder/releases/"
const CONTINUOUS_LADDER_AUTHOR_PREFIX := "/v1/ladder/authors/"
const CONTINUOUS_LADDER_MATCH_PREFIX := "/v1/ladder/matches/"
const COMPETITION_SOURCE_GRANTS := [
	"developer_registry",
	"submission_registry",
	"match_orchestration",
	"platform_scoring",
	"public_replay_distribution",
]

signal request_completed(result: Dictionary)

var _transport: Variant = null
var _base_url := ""
var _contract: Dictionary = {}
var _contract_sha256 := ""
var _in_flight := false
var _operation := ""
var _expected_id := ""
var _requested_limit := 0
var _expected_profile_id := ""
var _expected_author_id := ""
var _expected_release: Dictionary = {}
var _last_result: Dictionary = {}


static func create(
	transport: Variant,
	base_url: String,
	allow_insecure_loopback: bool = false
) -> Dictionary:
	var loaded := ContractScript.load_fixed()
	if not bool(loaded.get("accepted", false)):
		return loaded
	var endpoint_error := ContractScript.validate_endpoint(base_url, allow_insecure_loopback)
	if not endpoint_error.is_empty():
		return _failure(endpoint_error)
	var client := new()
	client._base_url = base_url.trim_suffix("/")
	client._contract = loaded.get("value", {}).duplicate(true)
	client._contract_sha256 = str(loaded.get("canonical_sha256", ""))
	if transport == null:
		var request := HTTPRequest.new()
		request.timeout = 30.0
		request.use_threads = true
		client.add_child(request)
		client._transport = request
	else:
		if not transport.has_method("request"):
			client.free()
			return _failure("platform_transport_invalid")
		client._transport = transport
	if not client._transport.has_signal("request_completed"):
		client.free()
		return _failure("platform_transport_invalid")
	client._transport.request_completed.connect(client._on_transport_completed)
	return {"accepted": true, "error_code": "", "client": client}


func list_strategies(limit: int = 24, cursor: String = "") -> Dictionary:
	if _in_flight:
		return _failure("platform_request_busy")
	var maximum := int(_contract.get("listing", {}).get("maximum_limit", 0))
	if limit < 1 or limit > maximum:
		return _failure("catalog_limit_invalid")
	if not cursor.is_empty() and not ContractScript.safe_identifier(cursor):
		return _failure("catalog_cursor_invalid")
	_operation = "catalog"
	_expected_id = ""
	_requested_limit = limit
	var path := str(_contract.routes.catalog.path) + "?limit=%d" % limit
	if not cursor.is_empty():
		path += "&cursor=%s" % cursor
	return _send(path, HTTPClient.METHOD_GET, PackedStringArray(["Accept: application/json"]), "")


func list_competition_profiles(limit: int = 100) -> Dictionary:
	if _in_flight:
		return _failure("platform_request_busy")
	var maximum := int(_contract.get("listing", {}).get("maximum_limit", 0))
	if limit < 1 or limit > maximum:
		return _failure("competition_profile_limit_invalid")
	_operation = "competition_profiles"
	_expected_id = ""
	_expected_profile_id = ""
	_expected_author_id = ""
	_expected_release = {}
	_requested_limit = limit
	var path := str(_contract.routes.competition_profiles.path) + "?limit=%d" % limit
	return _send(path, HTTPClient.METHOD_GET, PackedStringArray(["Accept: application/json"]), "")


func list_continuous_ladder_leaderboard() -> Dictionary:
	if _in_flight:
		return _failure("platform_request_busy")
	_operation = "continuous_ladder_leaderboard"
	_expected_id = ""
	_expected_profile_id = CONTINUOUS_LADDER_PROFILE_ID
	_expected_author_id = ""
	_expected_release = {}
	_requested_limit = 100
	return _send(
		CONTINUOUS_LADDER_LEADERBOARD_PATH,
		HTTPClient.METHOD_GET,
		PackedStringArray(["Accept: application/json"]),
		"",
	)


func list_continuous_ladder_authors() -> Dictionary:
	if _in_flight:
		return _failure("platform_request_busy")
	_operation = "continuous_ladder_authors"
	_expected_id = ""
	_expected_profile_id = CONTINUOUS_LADDER_PROFILE_ID
	_expected_author_id = ""
	_expected_release = {}
	_requested_limit = 100
	return _send(
		CONTINUOUS_LADDER_AUTHORS_PATH,
		HTTPClient.METHOD_GET,
		PackedStringArray(["Accept: application/json"]),
		"",
	)


func fetch_continuous_ladder_release_profile(release_id: String) -> Dictionary:
	if _in_flight:
		return _failure("platform_request_busy")
	if not ContractScript.safe_identifier(release_id):
		return _failure("continuous_ladder_release_id_invalid")
	_operation = "continuous_ladder_release_profile"
	_expected_id = release_id
	_expected_profile_id = CONTINUOUS_LADDER_PROFILE_ID
	_expected_author_id = ""
	_expected_release = {}
	_requested_limit = 100
	return _send(
		CONTINUOUS_LADDER_RELEASE_PREFIX + release_id + "/profile",
		HTTPClient.METHOD_GET,
		PackedStringArray(["Accept: application/json"]),
		"",
	)


func fetch_continuous_ladder_author_profile(developer_id: String) -> Dictionary:
	if _in_flight:
		return _failure("platform_request_busy")
	if not ContractScript.safe_identifier(developer_id):
		return _failure("continuous_ladder_author_id_invalid")
	_operation = "continuous_ladder_author_profile"
	_expected_id = ""
	_expected_profile_id = CONTINUOUS_LADDER_PROFILE_ID
	_expected_author_id = developer_id
	_expected_release = {}
	_requested_limit = 100
	return _send(
		CONTINUOUS_LADDER_AUTHOR_PREFIX + developer_id + "/profile",
		HTTPClient.METHOD_GET,
		PackedStringArray(["Accept: application/json"]),
		"",
	)


func fetch_continuous_ladder_series_replay(series_id: String) -> Dictionary:
	if _in_flight:
		return _failure("platform_request_busy")
	if not ContractScript.safe_identifier(series_id):
		return _failure("continuous_ladder_series_id_invalid")
	_operation = "continuous_ladder_series_replay"
	_expected_id = series_id
	_expected_profile_id = CONTINUOUS_LADDER_PROFILE_ID
	_expected_author_id = ""
	_expected_release = {}
	_requested_limit = 0
	return _send(
		CONTINUOUS_LADDER_MATCH_PREFIX + series_id + "/replay",
		HTTPClient.METHOD_GET,
		PackedStringArray(["Accept: application/json"]),
		"",
	)


func download_continuous_ladder_release(release: Dictionary) -> Dictionary:
	if _in_flight:
		return _failure("platform_request_busy")
	if not _valid_continuous_ladder_installable_release(release):
		return _failure("continuous_ladder_package_release_invalid")
	_operation = "continuous_ladder_package_download"
	_expected_id = str(release.get("release_id", ""))
	_expected_profile_id = CONTINUOUS_LADDER_PROFILE_ID
	_expected_author_id = ""
	_expected_release = release.duplicate(true)
	_requested_limit = 0
	return _send(
		str(release.get("distribution", {}).get("href", "")),
		HTTPClient.METHOD_GET,
		PackedStringArray(["Accept: application/vnd.ptcgdap.strategy-package"]),
		"",
	)


func list_marketplace_latest(limit: int = 24, cursor: String = "") -> Dictionary:
	return _start_marketplace_list(
		"marketplace_latest",
		str(_contract.routes.marketplace_latest.path),
		"",
		limit,
		cursor,
	)


func list_marketplace_strategy_rankings(
	profile_id: String,
	limit: int = 24,
	cursor: String = ""
) -> Dictionary:
	return _start_marketplace_list(
		"marketplace_strategy_rankings",
		str(_contract.routes.marketplace_strategy_rankings.path),
		profile_id,
		limit,
		cursor,
	)


func list_marketplace_author_rankings(
	profile_id: String,
	limit: int = 24,
	cursor: String = ""
) -> Dictionary:
	return _start_marketplace_list(
		"marketplace_author_rankings",
		str(_contract.routes.marketplace_author_rankings.path),
		profile_id,
		limit,
		cursor,
	)


func list_marketplace_author_strategies(
	author_id: String,
	limit: int = 24,
	cursor: String = ""
) -> Dictionary:
	if _in_flight:
		return _failure("platform_request_busy")
	if not ContractScript.safe_identifier(author_id):
		return _failure("marketplace_author_id_invalid")
	var maximum := int(_contract.get("listing", {}).get("maximum_limit", 0))
	if limit < 1 or limit > maximum:
		return _failure("marketplace_limit_invalid")
	if not cursor.is_empty() and not ContractScript.safe_identifier(cursor, 512):
		return _failure("marketplace_cursor_invalid")
	_operation = "marketplace_author_strategies"
	_expected_id = ""
	_expected_profile_id = ""
	_expected_author_id = author_id
	_expected_release = {}
	_requested_limit = limit
	var path := str(_contract.routes.marketplace_author_strategies.path_template).replace(
		"{author_id}", author_id
	) + "?limit=%d" % limit
	if not cursor.is_empty():
		path += "&cursor=%s" % cursor
	return _send(path, HTTPClient.METHOD_GET, PackedStringArray(["Accept: application/json"]), "")


func fetch_marketplace_strategy_archive(
	profile_id: String,
	competition_release_id: String,
	match_limit: int = 20
) -> Dictionary:
	if _in_flight:
		return _failure("platform_request_busy")
	if not ContractScript.safe_identifier(profile_id):
		return _failure("marketplace_profile_id_invalid")
	if not ContractScript.safe_identifier(competition_release_id):
		return _failure("marketplace_competition_release_id_invalid")
	if match_limit < 1 or match_limit > int(
		_contract.get("marketplace", {}).get("strategy_archive_recent_match_limit", 0)
	):
		return _failure("marketplace_match_limit_invalid")
	_operation = "marketplace_strategy_archive"
	_expected_id = competition_release_id
	_expected_profile_id = profile_id
	_expected_author_id = ""
	_expected_release = {}
	_requested_limit = match_limit
	var path := str(_contract.routes.marketplace_strategy_archive.path_template).replace(
		"{competition_release_id}", competition_release_id
	)
	path += "?profile_id=%s&match_limit=%d" % [profile_id, match_limit]
	return _send(path, HTTPClient.METHOD_GET, PackedStringArray(["Accept: application/json"]), "")


func list_marketplace_author_top_strategies(
	profile_id: String,
	author_id: String,
	limit: int = 5
) -> Dictionary:
	if _in_flight:
		return _failure("platform_request_busy")
	if not ContractScript.safe_identifier(profile_id):
		return _failure("marketplace_profile_id_invalid")
	if not ContractScript.safe_identifier(author_id):
		return _failure("marketplace_author_id_invalid")
	if limit < 1 or limit > int(
		_contract.get("marketplace", {}).get("author_top_strategy_limit", 0)
	):
		return _failure("marketplace_top_strategy_limit_invalid")
	_operation = "marketplace_author_top_strategies"
	_expected_id = ""
	_expected_profile_id = profile_id
	_expected_author_id = author_id
	_expected_release = {}
	_requested_limit = limit
	var path := str(
		_contract.routes.marketplace_author_top_strategies.path_template
	).replace("{author_id}", author_id)
	path += "?profile_id=%s&limit=%d" % [profile_id, limit]
	return _send(path, HTTPClient.METHOD_GET, PackedStringArray(["Accept: application/json"]), "")


func download_marketplace_release(release: Dictionary) -> Dictionary:
	if _in_flight:
		return _failure("platform_request_busy")
	if not _valid_marketplace_release(release):
		return _failure("marketplace_package_release_invalid")
	var distribution: Dictionary = release.get("distribution", {})
	if distribution.get("available") != true or distribution.get("media_type") \
			!= "application/vnd.ptcgdap.strategy-package":
		return _failure("marketplace_package_unavailable")
	_operation = "marketplace_package_download"
	_expected_id = str(release.get("release_id", ""))
	_expected_profile_id = ""
	_expected_author_id = ""
	_expected_release = release.duplicate(true)
	_requested_limit = 0
	var path := str(_contract.routes.release_download.path_template).replace(
		"{release_id}", _expected_id
	)
	return _send(
		path,
		HTTPClient.METHOD_GET,
		PackedStringArray(["Accept: application/vnd.ptcgdap.strategy-package"]),
		"",
	)


func _start_marketplace_list(
	operation: String,
	base_path: String,
	profile_id: String,
	limit: int,
	cursor: String
) -> Dictionary:
	if _in_flight:
		return _failure("platform_request_busy")
	var maximum := int(_contract.get("listing", {}).get("maximum_limit", 0))
	if limit < 1 or limit > maximum:
		return _failure("marketplace_limit_invalid")
	if operation != "marketplace_latest" and not ContractScript.safe_identifier(profile_id):
		return _failure("marketplace_profile_id_invalid")
	if not cursor.is_empty() and not ContractScript.safe_identifier(cursor, 512):
		return _failure("marketplace_cursor_invalid")
	_operation = operation
	_expected_id = ""
	_expected_profile_id = profile_id
	_expected_author_id = ""
	_expected_release = {}
	_requested_limit = limit
	var query: Array[String] = []
	if not profile_id.is_empty():
		query.append("profile_id=%s" % profile_id)
	query.append("limit=%d" % limit)
	if not cursor.is_empty():
		query.append("cursor=%s" % cursor)
	return _send(
		base_path + "?" + "&".join(query),
		HTTPClient.METHOD_GET,
		PackedStringArray(["Accept: application/json"]),
		"",
	)


func fetch_strategy(strategy_id: String) -> Dictionary:
	if _in_flight:
		return _failure("platform_request_busy")
	if not ContractScript.safe_identifier(strategy_id):
		return _failure("strategy_id_invalid")
	_operation = "detail"
	_expected_id = strategy_id
	_requested_limit = 0
	var path := str(_contract.routes.strategy_detail.path_template).replace("{strategy_id}", strategy_id)
	return _send(path, HTTPClient.METHOD_GET, PackedStringArray(["Accept: application/json"]), "")


func fetch_statistics(release_id: String) -> Dictionary:
	if _in_flight:
		return _failure("platform_request_busy")
	if not ContractScript.safe_identifier(release_id):
		return _failure("release_id_invalid")
	_operation = "statistics"
	_expected_id = release_id
	_requested_limit = 0
	var path := str(_contract.routes.statistics.path_template).replace("{release_id}", release_id)
	return _send(path, HTTPClient.METHOD_GET, PackedStringArray(["Accept: application/json"]), "")


func resolve_challenge(release_id: String, replay_id: String) -> Dictionary:
	if _in_flight:
		return _failure("platform_request_busy")
	if not ContractScript.safe_identifier(release_id) or not ContractScript.safe_identifier(replay_id):
		return _failure("challenge_request_invalid")
	_operation = "challenge"
	_expected_id = release_id + "\n" + replay_id
	_requested_limit = 0
	return _send_json(
		str(_contract.routes.challenge_resolve.path),
		{"release_id": release_id, "replay_id": replay_id},
		PackedStringArray(),
	)


func record_event(event: Dictionary, temporary_write_token: String) -> Dictionary:
	if _in_flight:
		return _failure("platform_request_busy")
	if not ContractScript.valid_temporary_token(temporary_write_token):
		# Delegate token syntax to the replay contract helper without retaining it.
		return _failure("platform_write_token_invalid")
	_operation = "instrumentation"
	_expected_id = ""
	_requested_limit = 0
	return _send_json(
		str(_contract.routes.instrumentation.path),
		event,
		PackedStringArray(["Authorization: Bearer %s" % temporary_write_token]),
	)


func last_result() -> Dictionary:
	return _last_result.duplicate(true)


func audit_snapshot() -> Dictionary:
	return {
		"document_type": "strategy_platform_client_audit_v1",
		"schema_version": 1,
		"operation": _operation,
		"service_contract_sha256": _contract_sha256,
		"in_flight": _in_flight,
		"persists_credentials": false,
		"policy_inference": false,
		"current_window_authority": false,
		"engine_authority": false,
		"authoritative": false,
		"grants": [],
	}


func _send_json(path: String, value: Dictionary, extra_headers: PackedStringArray) -> Dictionary:
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact(
		value, {"max_output_bytes": 64 * 1024}
	)
	if not bool(canonical.get("ok", false)):
		return _failure("platform_request_invalid")
	var headers := PackedStringArray(["Accept: application/json", "Content-Type: application/json"])
	for header: String in extra_headers:
		headers.append(header)
	return _send(
		path,
		HTTPClient.METHOD_POST,
		headers,
		(canonical.get("bytes", PackedByteArray()) as PackedByteArray).get_string_from_utf8(),
	)


func _send(path: String, method: int, headers: PackedStringArray, body: String) -> Dictionary:
	_in_flight = true
	_last_result = {}
	var error: int = _transport.request(_base_url + path, headers, method, body)
	if error != OK:
		_in_flight = false
		_last_result = _response_failure("platform_request_start_failed", true, 0)
		_last_result["transport_error"] = error
		return _last_result.duplicate(true)
	return {
		"accepted": true,
		"error_code": "",
		"started": true,
		"operation": _operation,
		"authoritative": false,
		"grants": [],
	}


func _on_transport_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS:
		_finish(_response_failure("platform_transport_failed", true, response_code))
		return
	var response_limit := (
		MAX_PACKAGE_RESPONSE_BYTES
		if _operation in [
			"marketplace_package_download", "continuous_ladder_package_download"
		] else MAX_JSON_RESPONSE_BYTES
	)
	if body.is_empty() or body.size() > response_limit:
		_finish(_response_failure(
			"platform_response_too_large" if body.size() > MAX_JSON_RESPONSE_BYTES else "platform_response_invalid",
			false,
			response_code,
		))
		return
	if response_code < 200 or response_code >= 300:
		_finish(_response_failure(_server_error_code(body), response_code >= 500, response_code))
		return
	if _operation == "marketplace_package_download":
		var package_result := _validate_package_download(headers, body)
		package_result["http_status"] = response_code
		_finish(package_result)
		return
	if _operation == "continuous_ladder_package_download":
		var ladder_package_result := _validate_continuous_ladder_package_download(
			headers, body
		)
		ladder_package_result["http_status"] = response_code
		_finish(ladder_package_result)
		return
	var parsed := _parse_canonical(body)
	if not bool(parsed.get("accepted", false)):
		parsed["http_status"] = response_code
		_finish(parsed)
		return
	var validated: Dictionary
	match _operation:
		"competition_profiles":
			validated = _validate_competition_profiles(parsed.get("value"))
		"continuous_ladder_leaderboard":
			validated = _validate_continuous_ladder_board(parsed.get("value"), false)
		"continuous_ladder_authors":
			validated = _validate_continuous_ladder_board(parsed.get("value"), true)
		"continuous_ladder_release_profile":
			validated = _validate_continuous_ladder_release_profile(parsed.get("value"))
		"continuous_ladder_author_profile":
			validated = _validate_continuous_ladder_author_profile(parsed.get("value"))
		"continuous_ladder_series_replay":
			validated = _validate_continuous_ladder_series_replay(parsed.get("value"))
		"catalog":
			validated = _validate_catalog(parsed.get("value"))
		"detail":
			validated = _validate_detail(parsed.get("value"))
		"statistics":
			validated = _validate_statistics(parsed.get("value"))
		"challenge":
			validated = _validate_challenge(parsed.get("value"))
		"instrumentation":
			validated = _validate_instrumentation(parsed.get("value"))
		"marketplace_latest":
			validated = _validate_marketplace_latest(parsed.get("value"))
		"marketplace_strategy_rankings":
			validated = _validate_marketplace_rankings(parsed.get("value"), false)
		"marketplace_author_rankings":
			validated = _validate_marketplace_rankings(parsed.get("value"), true)
		"marketplace_author_strategies":
			validated = _validate_marketplace_author_strategies(parsed.get("value"))
		"marketplace_strategy_archive":
			validated = _validate_marketplace_strategy_archive(parsed.get("value"))
		"marketplace_author_top_strategies":
			validated = _validate_marketplace_author_top_strategies(parsed.get("value"))
		_:
			validated = _failure("platform_operation_invalid")
	validated["http_status"] = response_code
	_finish(validated)


func _validate_continuous_ladder_board(value: Variant, author_board: bool) -> Dictionary:
	var expected_type := (
		"godot_v18_author_leaderboard_v1"
		if author_board else "godot_v18_release_leaderboard_v1"
	)
	if not value is Dictionary \
			or value.get("document_type") != expected_type \
			or value.get("profile_id") != CONTINUOUS_LADDER_PROFILE_ID \
			or not value.get("items") is Array:
		return _failure("continuous_ladder_response_invalid")
	var items: Array = value.get("items")
	if items.size() > _requested_limit:
		return _failure("continuous_ladder_response_invalid")
	var previous_rank := 0
	var normalized_items: Array[Dictionary] = []
	for item_value: Variant in items:
		if not item_value is Dictionary:
			return _failure("continuous_ladder_response_invalid")
		var item := item_value as Dictionary
		if typeof(item.get("rank")) != TYPE_INT \
				or int(item.get("rank")) <= previous_rank \
				or not ContractScript.safe_identifier(item.get("release_id")) \
				or not ContractScript.safe_identifier(item.get("developer_id")) \
				or not _valid_ladder_rating(item.get("mu"), item.get("sigma")) \
				or typeof(item.get("provisional")) != TYPE_BOOL \
				or not _valid_optional_ladder_label(item.get("display_name")) \
				or not _valid_optional_ladder_label(item.get("author_display_name")):
			return _failure("continuous_ladder_response_invalid")
		previous_rank = int(item.get("rank"))
		if author_board:
			var normalized_author := item.duplicate(true)
			normalized_author["mu"] = float(item.get("mu"))
			normalized_author["sigma"] = float(item.get("sigma"))
			normalized_items.append(normalized_author)
			continue
		if item.get("profile_id") != CONTINUOUS_LADDER_PROFILE_ID \
				or item.get("owner_kind") not in ["developer", "platform_npc"] \
				or not ContractScript.safe_identifier(item.get("owner_id")) \
				or not ContractScript.safe_identifier(
					item.get("competition_conflict_group")
				) \
				or item.get("release_source_kind") not in [
					"developer_ptcgai", "platform_builtin_v18_rule"
				] \
				or item.get("runtime_kind") not in [
					"godot_restricted_ptcgai_v1", "godot_builtin_rule_v18"
				] \
				or item.get("state") != "active" \
				or not _valid_nonnegative_epoch(item.get("uploaded_at_epoch"), false) \
				or not _valid_nonnegative_epoch(item.get("next_due_at_epoch"), false) \
				or not _valid_nonnegative_epoch(item.get("last_series_at_epoch"), true) \
				or typeof(item.get("rated_series_count")) != TYPE_INT \
				or int(item.get("rated_series_count")) < 0 \
				or typeof(item.get("actual_game_count")) != TYPE_INT \
				or int(item.get("actual_game_count")) < 0:
			return _failure("continuous_ladder_response_invalid")
		var normalized_release := item.duplicate(true)
		normalized_release["mu"] = float(item.get("mu"))
		normalized_release["sigma"] = float(item.get("sigma"))
		normalized_items.append(normalized_release)
	return _success({
		"profile_id": value.get("profile_id"),
		"items": normalized_items,
	})


func _validate_continuous_ladder_release_profile(value: Variant) -> Dictionary:
	if not value is Dictionary \
			or value.get("document_type") != "godot_v18_release_profile_v1" \
			or value.get("schema_version") != 1 \
			or value.get("profile_id") != CONTINUOUS_LADDER_PROFILE_ID \
			or not value.get("release") is Dictionary \
			or value.get("release", {}).get("release_id") != _expected_id \
			or not _valid_continuous_ladder_release(value.get("release")) \
			or not _valid_continuous_ladder_performance(value.get("performance")) \
			or not value.get("rating_history") is Array \
			or not value.get("recent_matches") is Array:
		return _failure("continuous_ladder_release_profile_invalid")
	if value.get("rating_history", []).size() > _requested_limit \
			or value.get("recent_matches", []).size() > _requested_limit:
		return _failure("continuous_ladder_release_profile_invalid")
	var normalized: Dictionary = (value as Dictionary).duplicate(true)
	normalized["release"]["mu"] = float(value.get("release", {}).get("mu"))
	normalized["release"]["sigma"] = float(value.get("release", {}).get("sigma"))
	var previous_sequence := 2147483647
	for index: int in value.get("rating_history", []).size():
		var event: Variant = value.get("rating_history", [])[index]
		if not event is Dictionary \
				or not ContractScript.safe_identifier(event.get("event_id")) \
				or not ContractScript.safe_identifier(event.get("series_id")) \
				or not ContractScript.safe_identifier(event.get("opponent_release_id")) \
				or event.get("subject_outcome") not in ["win", "loss", "draw"] \
				or typeof(event.get("sequence_no")) != TYPE_INT \
				or int(event.get("sequence_no")) >= previous_sequence \
				or not _valid_ladder_rating(event.get("prior_mu"), event.get("prior_sigma")) \
				or not _valid_ladder_rating(event.get("after_mu"), event.get("after_sigma")) \
				or not _valid_nonnegative_epoch(event.get("created_at_epoch"), false):
			return _failure("continuous_ladder_release_profile_invalid")
		previous_sequence = int(event.get("sequence_no"))
		normalized["rating_history"][index]["prior_mu"] = float(event.get("prior_mu"))
		normalized["rating_history"][index]["prior_sigma"] = float(event.get("prior_sigma"))
		normalized["rating_history"][index]["after_mu"] = float(event.get("after_mu"))
		normalized["rating_history"][index]["after_sigma"] = float(event.get("after_sigma"))
	for match_value: Variant in value.get("recent_matches", []):
		if not match_value is Dictionary:
			return _failure("continuous_ladder_release_profile_invalid")
		var match_item := match_value as Dictionary
		if not ContractScript.safe_identifier(match_item.get("series_id")) \
				or match_item.get("state") not in ["rated", "quarantined"] \
				or not _valid_nonnegative_epoch(match_item.get("completed_at_epoch"), false) \
				or not match_item.get("opponent") is Dictionary \
				or not ContractScript.safe_identifier(match_item.get("opponent", {}).get("release_id")) \
				or not _valid_optional_ladder_label(match_item.get("opponent", {}).get("display_name")) \
				or match_item.get("opponent", {}).get("owner_kind") not in ["developer", "platform_npc"] \
				or match_item.get("subject_result") not in ["win", "loss", "draw", "quarantined"] \
				or not _valid_continuous_ladder_match_games(match_item) \
				or typeof(match_item.get("replay_available")) != TYPE_BOOL \
				or not _valid_continuous_ladder_replay_path(match_item):
			return _failure("continuous_ladder_release_profile_invalid")
	return _success({"profile": normalized})


func _validate_continuous_ladder_series_replay(value: Variant) -> Dictionary:
	if not value is Dictionary \
			or value.get("document_type") != "godot_v18_public_series_replay_v1" \
			or value.get("schema_version") != 1 \
			or value.get("profile_id") != CONTINUOUS_LADDER_PROFILE_ID \
			or value.get("series_id") != _expected_id \
			or not ContractScript.safe_identifier(value.get("release_a_id")) \
			or not ContractScript.safe_identifier(value.get("release_b_id")) \
			or value.get("release_a_id") == value.get("release_b_id") \
			or not _valid_nonnegative_epoch(value.get("created_at_epoch"), false) \
			or not _valid_nonnegative_epoch(value.get("completed_at_epoch"), false) \
			or int(value.get("completed_at_epoch", -1)) < int(value.get("created_at_epoch", 0)) \
			or not value.get("games") is Array \
			or value.get("games", []).size() != 2 \
			or _contains_forbidden_public_key(value):
		return _failure("continuous_ladder_series_replay_invalid")
	var release_a_id := str(value.get("release_a_id"))
	var release_b_id := str(value.get("release_b_id"))
	var seen_job_ids := {}
	for index: int in 2:
		var game_value: Variant = value.get("games", [])[index]
		if not game_value is Dictionary:
			return _failure("continuous_ladder_series_replay_invalid")
		var game := game_value as Dictionary
		var expected_seat0 := release_a_id if index == 0 else release_b_id
		var expected_seat1 := release_b_id if index == 0 else release_a_id
		var job_id: Variant = game.get("job_id")
		if not ContractScript.safe_identifier(job_id) \
				or seen_job_ids.has(job_id) \
				or game.get("seat_variant") != index \
				or game.get("seat0_release_id") != expected_seat0 \
				or game.get("seat1_release_id") != expected_seat1 \
				or game.get("outcome") not in ["seat0_win", "seat1_win", "draw"] \
				or not _valid_continuous_ladder_decision_counts(game.get("decision_counts")) \
				or not _valid_continuous_ladder_public_replay(
					game.get("public_replay"), game.get("decision_counts"), str(game.get("outcome"))
				) \
				or not game.get("execution_proof") is Dictionary:
			return _failure("continuous_ladder_series_replay_invalid")
		seen_job_ids[job_id] = true
	return _success({"replay": (value as Dictionary).duplicate(true)})


func _validate_continuous_ladder_author_profile(value: Variant) -> Dictionary:
	if not value is Dictionary \
			or value.get("document_type") != "godot_v18_author_profile_v1" \
			or value.get("schema_version") != 1 \
			or value.get("profile_id") != CONTINUOUS_LADDER_PROFILE_ID \
			or not value.get("author") is Dictionary \
			or value.get("author", {}).get("developer_id") != _expected_author_id \
			or not value.get("releases") is Array \
			or value.get("releases", []).size() > _requested_limit:
		return _failure("continuous_ladder_author_profile_invalid")
	var author: Dictionary = value.get("author")
	if not _valid_optional_ladder_label(author.get("display_name")) \
			or typeof(author.get("release_count")) != TYPE_INT \
			or int(author.get("release_count")) != value.get("releases", []).size() \
			or typeof(author.get("active_release_count")) != TYPE_INT \
			or int(author.get("active_release_count")) < 0 \
			or int(author.get("active_release_count")) > int(author.get("release_count")) \
			or not ContractScript.safe_identifier(author.get("best_release_id")) \
			or not _valid_ladder_rating(author.get("mu"), author.get("sigma")) \
			or typeof(author.get("provisional")) != TYPE_BOOL:
		return _failure("continuous_ladder_author_profile_invalid")
	if author.get("rank") != null and (
		typeof(author.get("rank")) != TYPE_INT or int(author.get("rank")) < 1
	):
		return _failure("continuous_ladder_author_profile_invalid")
	var normalized: Dictionary = (value as Dictionary).duplicate(true)
	normalized["author"]["mu"] = float(author.get("mu"))
	normalized["author"]["sigma"] = float(author.get("sigma"))
	var seen := {}
	for index: int in value.get("releases", []).size():
		var item: Variant = value.get("releases", [])[index]
		if not item is Dictionary \
				or not _valid_continuous_ladder_release(item.get("release")) \
				or item.get("release", {}).get("developer_id") != _expected_author_id \
				or not _valid_continuous_ladder_performance(item.get("performance")):
			return _failure("continuous_ladder_author_profile_invalid")
		var release_id := str(item.get("release", {}).get("release_id", ""))
		if seen.has(release_id):
			return _failure("continuous_ladder_author_profile_invalid")
		seen[release_id] = true
		normalized["releases"][index]["release"]["mu"] = float(item.get("release", {}).get("mu"))
		normalized["releases"][index]["release"]["sigma"] = float(item.get("release", {}).get("sigma"))
	return _success({"profile": normalized})


static func _valid_continuous_ladder_release(value: Variant) -> bool:
	if not value is Dictionary \
			or value.get("profile_id", CONTINUOUS_LADDER_PROFILE_ID) != CONTINUOUS_LADDER_PROFILE_ID \
			or not ContractScript.safe_identifier(value.get("release_id")) \
			or not ContractScript.safe_identifier(value.get("developer_id")) \
			or value.get("owner_kind") not in ["developer", "platform_npc"] \
			or value.get("state") not in ["active", "historical", "suspended"] \
			or not _valid_ladder_rating(value.get("mu"), value.get("sigma")) \
			or typeof(value.get("rated_series_count")) != TYPE_INT \
			or int(value.get("rated_series_count")) < 0 \
			or typeof(value.get("actual_game_count")) != TYPE_INT \
			or int(value.get("actual_game_count")) < 0 \
			or typeof(value.get("provisional")) != TYPE_BOOL \
			or not _valid_optional_ladder_label(value.get("display_name")) \
			or not _valid_optional_ladder_label(value.get("author_display_name")) \
			or typeof(value.get("summary")) != TYPE_STRING \
			or typeof(value.get("download_available")) != TYPE_BOOL:
		return false
	if value.get("rank") != null and (
		typeof(value.get("rank")) != TYPE_INT or int(value.get("rank")) < 1
	):
		return false
	if bool(value.get("download_available")):
		return _valid_continuous_ladder_installable_release(
			value.get("installable_release")
		)
	return value.get("installable_release") == null


static func _valid_continuous_ladder_performance(value: Variant) -> bool:
	return value is Dictionary \
		and _valid_ladder_counts(value.get("series")) \
		and _valid_ladder_counts(value.get("individual_games"))


static func _valid_ladder_counts(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for field: String in ["games", "wins", "losses", "draws", "win_rate_micros"]:
		if typeof(value.get(field)) != TYPE_INT or int(value.get(field)) < 0:
			return false
	return int(value.get("wins")) + int(value.get("losses")) + int(value.get("draws")) \
		== int(value.get("games")) \
		and int(value.get("win_rate_micros")) <= 1000000


static func _valid_continuous_ladder_match_games(value: Dictionary) -> bool:
	var games_value: Variant = value.get("games")
	if not games_value is Array:
		return false
	var games := games_value as Array
	if games.size() > 2:
		return false
	var seen_job_ids := {}
	var seen_seat_variants := {}
	var seen_subject_seats := {}
	var result_counts := {"win": 0, "loss": 0, "draw": 0}
	for game_value: Variant in games:
		if not game_value is Dictionary:
			return false
		var game := game_value as Dictionary
		var job_id: Variant = game.get("job_id")
		var seat_variant: Variant = game.get("seat_variant")
		var subject_seat: Variant = game.get("subject_seat")
		var subject_result: Variant = game.get("subject_result")
		if not ContractScript.safe_identifier(job_id) \
				or seen_job_ids.has(job_id) \
				or typeof(seat_variant) != TYPE_INT \
				or int(seat_variant) not in [0, 1] \
				or seen_seat_variants.has(seat_variant) \
				or typeof(subject_seat) != TYPE_INT \
				or int(subject_seat) not in [0, 1] \
				or seen_subject_seats.has(subject_seat) \
				or subject_result not in ["win", "loss", "draw"]:
			return false
		seen_job_ids[job_id] = true
		seen_seat_variants[seat_variant] = true
		seen_subject_seats[subject_seat] = true
		result_counts[subject_result] = int(result_counts.get(subject_result, 0)) + 1
	for field: String in ["wins", "losses", "draws", "win_rate_micros"]:
		if typeof(value.get(field)) != TYPE_INT or int(value.get(field)) < 0:
			return false
	if int(value.get("wins")) != int(result_counts.win) \
			or int(value.get("losses")) != int(result_counts.loss) \
			or int(value.get("draws")) != int(result_counts.draw) \
			or int(value.get("win_rate_micros")) > 1000000:
		return false
	return not bool(value.get("replay_available", false)) or games.size() == 2


static func _valid_continuous_ladder_replay_path(value: Dictionary) -> bool:
	if not bool(value.get("replay_available", false)):
		return value.get("replay_path") == null
	return value.get("replay_path") == (
		"/v1/ladder/matches/%s/replay" % str(value.get("series_id", ""))
	)


static func _valid_continuous_ladder_decision_counts(value: Variant) -> bool:
	if not value is Array or value.size() != 2:
		return false
	for count: Variant in value:
		if typeof(count) != TYPE_INT or int(count) < 0:
			return false
	return true


static func _valid_continuous_ladder_public_replay(
	value: Variant,
	decision_counts: Variant,
	outcome: String
) -> bool:
	if not value is Dictionary \
			or value.get("document_type") != "godot_v18_public_replay_v1" \
			or typeof(value.get("complete")) != TYPE_BOOL \
			or not value.get("frames") is Array \
			or value.get("frames", []).size() > 4096 \
			or not value.get("terminal") is Dictionary:
		return false
	if value.get("frames", []).size() != (
		int(decision_counts[0]) + int(decision_counts[1])
	):
		return false
	for frame_value: Variant in value.get("frames", []):
		if not _valid_continuous_ladder_public_frame(frame_value):
			return false
	var winner: Variant = value.get("terminal", {}).get("winner_index")
	if typeof(winner) != TYPE_INT or int(winner) not in [-1, 0, 1]:
		return false
	if bool(value.get("complete", false)):
		return (outcome == "seat0_win" and int(winner) == 0) \
			or (outcome == "seat1_win" and int(winner) == 1) \
			or (outcome == "draw" and int(winner) == -1)
	return true


static func _valid_continuous_ladder_public_frame(value: Variant) -> bool:
	if not value is Dictionary \
			or typeof(value.get("sequence")) != TYPE_INT \
			or int(value.get("sequence")) < 1 \
			or typeof(value.get("seat")) != TYPE_INT \
			or int(value.get("seat")) not in [0, 1] \
			or typeof(value.get("prompt_kind")) != TYPE_STRING \
			or str(value.get("prompt_kind")).is_empty() \
			or typeof(value.get("selection_source")) != TYPE_STRING \
			or str(value.get("selection_source")).is_empty() \
			or typeof(value.get("latency_usec")) != TYPE_INT \
			or int(value.get("latency_usec")) < 0 \
			or not value.get("accepted_indexes") is Array \
			or not value.get("accepted_option_fingerprints") is Array \
			or value.get("accepted_indexes", []).is_empty() \
			or value.get("accepted_indexes", []).size() \
				!= value.get("accepted_option_fingerprints", []).size() \
			or not value.get("source") is Dictionary \
			or not ContractScript.valid_sha256(
				value.get("source", {}).get("public_observation_hash")
			) \
			or not ContractScript.safe_identifier(value.get("source", {}).get("window_id")):
		return false
	for option_index: Variant in value.get("accepted_indexes", []):
		if typeof(option_index) != TYPE_INT or int(option_index) < 0:
			return false
	for fingerprint: Variant in value.get("accepted_option_fingerprints", []):
		if not ContractScript.valid_sha256(fingerprint):
			return false
	return true


static func _contains_forbidden_public_key(value: Variant) -> bool:
	var pending: Array[Variant] = [value]
	var forbidden := {
		"raw_state": true,
		"game_state": true,
		"private_state": true,
		"private_rng_state": true,
		"opponent_hand": true,
		"deck_order": true,
		"face_down_prizes": true,
		"search_begin_input": true,
		"select_payload": true,
		"service_credential": true,
	}
	while not pending.is_empty():
		var current: Variant = pending.pop_back()
		if current is Dictionary:
			for key: Variant in current:
				if forbidden.has(str(key).to_lower()):
					return true
				pending.append(current[key])
		elif current is Array:
			pending.append_array(current)
	return false


static func _valid_continuous_ladder_installable_release(value: Variant) -> bool:
	if not value is Dictionary \
			or not ContractScript.safe_identifier(value.get("release_id")) \
			or not ContractScript.safe_identifier(value.get("package_id")) \
			or not ContractScript.safe_identifier(value.get("package_version"), 64) \
			or not ContractScript.valid_sha256(value.get("archive_sha256")) \
			or not ContractScript.valid_sha256(value.get("manifest_canonical_sha256")) \
			or typeof(value.get("archive_bytes")) != TYPE_INT \
			or int(value.get("archive_bytes")) < 1 \
			or int(value.get("archive_bytes")) > MAX_PACKAGE_RESPONSE_BYTES \
			or not value.get("distribution") is Dictionary:
		return false
	var distribution: Dictionary = value.get("distribution")
	return distribution.get("href") == "/v1/ladder/releases/%s/package" % value.get("release_id") \
		and distribution.get("media_type") == "application/vnd.ptcgdap.strategy-package" \
		and distribution.get("etag") == value.get("archive_sha256")


static func _valid_ladder_rating(mu: Variant, sigma: Variant) -> bool:
	if not _valid_fixed_six_decimal(mu, true) \
			or not _valid_fixed_six_decimal(sigma, false):
		return false
	return is_finite(float(mu)) and is_finite(float(sigma)) \
		and float(sigma) >= 0.0


static func _valid_fixed_six_decimal(value: Variant, allow_negative: bool) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var text := str(value)
	var parts := text.split(".", true)
	if parts.size() != 2 or parts[1].length() != 6:
		return false
	var integer := parts[0]
	if integer.begins_with("-"):
		if not allow_negative:
			return false
		integer = integer.substr(1)
	if integer.is_empty():
		return false
	for character_index: int in integer.length():
		var code := integer.unicode_at(character_index)
		if code < 48 or code > 57:
			return false
	for character_index: int in parts[1].length():
		var code := parts[1].unicode_at(character_index)
		if code < 48 or code > 57:
			return false
	return true


static func _valid_nonnegative_epoch(value: Variant, nullable: bool) -> bool:
	return (nullable and value == null) or (
		typeof(value) == TYPE_INT and int(value) >= 0
	)


static func _valid_optional_ladder_label(value: Variant) -> bool:
	if value == null:
		return true
	return typeof(value) == TYPE_STRING \
		and not str(value).is_empty() \
		and str(value).length() <= 160 \
		and str(value) == str(value).strip_edges()


func _validate_competition_profiles(value: Variant) -> Dictionary:
	if not value is Dictionary \
			or value.get("document_type") != "competition_profile_list_v1" \
			or value.get("schema_version") != 1 \
			or value.get("platform_competition_authority") != true \
			or value.get("player_runtime_authority") != false \
			or value.get("kaggle_official_authority") != false \
			or value.get("grants") != COMPETITION_SOURCE_GRANTS \
			or not value.get("items") is Array:
		return _failure("competition_profile_response_invalid")
	var items: Array = value.get("items")
	if items.size() > _requested_limit:
		return _failure("competition_profile_response_invalid")
	var previous := ""
	for item_value: Variant in items:
		if not item_value is Dictionary:
			return _failure("competition_profile_response_invalid")
		var item := item_value as Dictionary
		var profile_id := str(item.get("profile_id", ""))
		if not ContractScript.safe_identifier(profile_id) \
				or (not previous.is_empty() and profile_id <= previous) \
				or typeof(item.get("display_name")) != TYPE_STRING \
				or str(item.get("display_name")).is_empty() \
				or item.get("state") not in ["draft", "active", "retired"] \
				or typeof(item.get("games_per_seat")) != TYPE_INT \
				or int(item.get("games_per_seat")) < 1 \
				or typeof(item.get("minimum_publish_games")) != TYPE_INT \
				or int(item.get("minimum_publish_games")) < 1 \
				or typeof(item.get("score_formula")) != TYPE_STRING:
			return _failure("competition_profile_response_invalid")
		previous = profile_id
	var next_cursor: Variant = value.get("next_cursor")
	if next_cursor != null and not ContractScript.safe_identifier(next_cursor):
		return _failure("competition_profile_response_invalid")
	return _success({"items": items.duplicate(true), "next_cursor": next_cursor})


func _validate_catalog(value: Variant) -> Dictionary:
	if not value is Dictionary or not _base_non_authoritative(value) \
			or value.get("document_type") != "strategy_catalog_v1" \
			or value.get("schema_version") != 1 or not value.get("items") is Array:
		return _failure("catalog_response_invalid")
	var items: Array = value.get("items")
	if items.size() > _requested_limit:
		return _failure("catalog_response_invalid")
	var previous := ""
	for item: Variant in items:
		if not item is Dictionary or not ContractScript.safe_identifier(item.get("strategy_id")) \
				or not item.get("featured_release") is Dictionary \
				or not _valid_release(item.get("featured_release")):
			return _failure("catalog_response_invalid")
		var strategy_id := str(item.get("strategy_id"))
		if not previous.is_empty() and strategy_id <= previous:
			return _failure("catalog_response_invalid")
		previous = strategy_id
	var next_cursor: Variant = value.get("next_cursor")
	if next_cursor != null and not ContractScript.safe_identifier(next_cursor):
		return _failure("catalog_response_invalid")
	return _success({"items": items.duplicate(true), "next_cursor": next_cursor})


func _validate_detail(value: Variant) -> Dictionary:
	if not value is Dictionary or not _base_non_authoritative(value) \
			or value.get("document_type") != "strategy_detail_v1" \
			or value.get("schema_version") != 1 \
			or value.get("strategy_id") != _expected_id \
			or not value.get("releases") is Array \
			or not value.get("representative_replays") is Array:
		return _failure("strategy_detail_response_invalid")
	for release: Variant in value.get("releases"):
		if not _valid_release(release) or release.get("strategy_id") != _expected_id:
			return _failure("strategy_detail_response_invalid")
	for replay: Variant in value.get("representative_replays"):
		if not replay is Dictionary or not _base_non_authoritative(replay) \
				or not ContractScript.safe_identifier(replay.get("replay_id")) \
				or not ContractScript.safe_identifier(replay.get("release_id")):
			return _failure("strategy_detail_response_invalid")
	return _success({"detail": value.duplicate(true)})


func _validate_statistics(value: Variant) -> Dictionary:
	if not value is Dictionary or not _base_non_authoritative(value) \
			or value.get("document_type") != "strategy_release_statistics_v1" \
			or value.get("schema_version") != 1 or value.get("release_id") != _expected_id:
		return _failure("statistics_response_invalid")
	var official: Variant = value.get("official")
	var shadow: Variant = value.get("shadow")
	var community: Variant = value.get("community")
	if not _valid_stats_lane(official, true) or not _valid_stats_lane(shadow, false) \
			or not community is Dictionary \
			or typeof(community.get("active_replay_count")) != TYPE_INT \
			or int(community.get("active_replay_count")) < 0 \
			or community.get("enters_official_statistics") != false:
		return _failure("statistics_response_invalid")
	return _success({"statistics": value.duplicate(true)})


func _validate_challenge(value: Variant) -> Dictionary:
	var parts := _expected_id.split("\n", false, 1)
	if not value is Dictionary or not _base_non_authoritative(value) \
			or value.get("document_type") != "exact_release_challenge_intent_v1" \
			or value.get("schema_version") != 1 \
			or parts.size() != 2 \
			or value.get("release_id") != parts[0] \
			or value.get("replay_id") != parts[1] \
			or value.get("runtime_authority") != false \
			or not value.get("release_identity") is Dictionary \
			or not value.get("local_selection") is Dictionary:
		return _failure("challenge_response_invalid")
	return _success({"intent": value.duplicate(true)})


func _validate_instrumentation(value: Variant) -> Dictionary:
	if not value is Dictionary or not _base_non_authoritative(value) \
			or value.get("accepted") != true or not ContractScript.safe_identifier(value.get("event_id")):
		return _failure("instrumentation_response_invalid")
	return _success({"event": value.duplicate(true)})


func _validate_marketplace_latest(value: Variant) -> Dictionary:
	if not _valid_marketplace_document(value) \
			or value.get("document_type") != "strategy_marketplace_latest_v1" \
			or value.get("order") != "published_at_desc" \
			or value.get("artifact_domain") not in ["competition_ptcgbot", "device_ptcgai"]:
		return _failure("marketplace_latest_response_invalid")
	if value.get("artifact_domain") == "competition_ptcgbot" \
			and value.get("download_artifact_domain") != "device_ptcgai":
		return _failure("marketplace_latest_response_invalid")
	var items: Array = value.get("items")
	if items.size() > _requested_limit or not _valid_marketplace_item_order(
		items, str(value.get("artifact_domain"))
	):
		return _failure("marketplace_latest_response_invalid")
	var next_cursor: Variant = value.get("next_cursor")
	if next_cursor != null and not ContractScript.safe_identifier(next_cursor, 512):
		return _failure("marketplace_latest_response_invalid")
	return _success({"items": items.duplicate(true), "next_cursor": next_cursor})


func _validate_marketplace_rankings(value: Variant, author_board: bool) -> Dictionary:
	var expected_type := (
		"strategy_marketplace_author_ranking_v1"
		if author_board else "strategy_marketplace_strategy_ranking_v1"
	)
	if not _valid_marketplace_document(value) \
			or value.get("document_type") != expected_type \
			or value.get("profile_id") != _expected_profile_id \
			or not ContractScript.safe_identifier(value.get("ranking_snapshot_id")) \
			or typeof(value.get("snapshot_created_at_utc")) != TYPE_STRING \
			or str(value.get("snapshot_created_at_utc")).is_empty() \
			or value.get("snapshot_consistent") != true \
			or value.get("ranking_artifact_domain") != "competition_ptcgbot" \
			or value.get("download_artifact_domain") != "device_ptcgai" \
			or typeof(value.get("score_formula")) != TYPE_STRING \
			or typeof(value.get("minimum_publish_games")) != TYPE_INT:
		return _failure("marketplace_ranking_response_invalid")
	if author_board and value.get("contribution_formula_id") \
			!= "competition_performance_mean_v1":
		return _failure("marketplace_ranking_response_invalid")
	var items: Array = value.get("items")
	if items.size() > _requested_limit:
		return _failure("marketplace_ranking_response_invalid")
	var previous_rank := 0
	for item_value: Variant in items:
		if not item_value is Dictionary:
			return _failure("marketplace_ranking_response_invalid")
		var item := item_value as Dictionary
		if not _valid_score_item(item) or int(item.get("rank")) <= previous_rank:
			return _failure("marketplace_ranking_response_invalid")
		previous_rank = int(item.get("rank"))
		if author_board:
			if (
				not ContractScript.safe_identifier(item.get("author_id"))
				or typeof(item.get("author_display_name")) != TYPE_STRING
				or typeof(item.get("published_strategy_count")) != TYPE_INT
				or int(item.get("published_strategy_count")) < 0
				or typeof(item.get("works_available")) != TYPE_BOOL
				or item.get("contribution_formula_id") != "competition_performance_mean_v1"
			):
				return _failure("marketplace_ranking_response_invalid")
		else:
			if not _valid_strategy_ranking_item(item):
				return _failure("marketplace_ranking_response_invalid")
	var next_cursor: Variant = value.get("next_cursor")
	if next_cursor != null and not ContractScript.safe_identifier(next_cursor, 512):
		return _failure("marketplace_ranking_response_invalid")
	var fields := {
		"items": items.duplicate(true),
		"next_cursor": next_cursor,
		"ranking_snapshot_id": value.get("ranking_snapshot_id"),
		"snapshot_created_at_utc": value.get("snapshot_created_at_utc"),
		"score_formula": value.get("score_formula"),
		"minimum_publish_games": value.get("minimum_publish_games"),
		"ranking_artifact_domain": value.get("ranking_artifact_domain"),
		"download_artifact_domain": value.get("download_artifact_domain"),
	}
	if author_board:
		fields["contribution_formula_id"] = value.get("contribution_formula_id")
		fields["contribution_explanation"] = value.get("contribution_explanation", "")
	return _success(fields)


func _validate_marketplace_author_strategies(value: Variant) -> Dictionary:
	if not _valid_marketplace_document(value) \
			or value.get("document_type") != "strategy_marketplace_author_strategies_v1" \
			or value.get("order") != "published_at_desc" \
			or value.get("artifact_domain") != "device_ptcgai" \
			or not value.get("author") is Dictionary \
			or value.get("author", {}).get("author_id") != _expected_author_id:
		return _failure("marketplace_author_strategies_response_invalid")
	var items: Array = value.get("items")
	if items.size() > _requested_limit or not _valid_marketplace_item_order(items):
		return _failure("marketplace_author_strategies_response_invalid")
	var next_cursor: Variant = value.get("next_cursor")
	if next_cursor != null and not ContractScript.safe_identifier(next_cursor, 512):
		return _failure("marketplace_author_strategies_response_invalid")
	return _success({
		"author": value.get("author", {}).duplicate(true),
		"items": items.duplicate(true),
		"next_cursor": next_cursor,
	})


func _validate_marketplace_strategy_archive(value: Variant) -> Dictionary:
	if not value is Dictionary or not _base_non_authoritative(value) \
			or value.get("document_type") != "strategy_marketplace_strategy_archive_v1" \
			or value.get("schema_version") != 1 \
			or value.get("profile_id") != _expected_profile_id \
			or value.get("order") != "completed_at_desc_match_id_desc" \
			or value.get("ranking_artifact_domain") != "competition_ptcgbot" \
			or value.get("download_artifact_domain") != "device_ptcgai" \
			or not value.get("strategy") is Dictionary \
			or not _valid_competition_marketplace_item(value.get("strategy")) \
			or value.get("strategy", {}).get("competition_release_id") != _expected_id \
			or not value.get("recent_matches") is Array:
		return _failure("marketplace_strategy_archive_response_invalid")
	var matches: Array = value.get("recent_matches")
	if matches.size() > _requested_limit:
		return _failure("marketplace_strategy_archive_response_invalid")
	var previous_completed := ""
	var previous_match_id := ""
	var seen := {}
	for match_value: Variant in matches:
		if not match_value is Dictionary:
			return _failure("marketplace_strategy_archive_response_invalid")
		var item := match_value as Dictionary
		var match_id := str(item.get("match_id", ""))
		var completed := str(item.get("completed_at_utc", ""))
		var subject_seat := int(item.get("subject_seat", -1))
		var reward := int(item.get("subject_reward", 99))
		var participants: Variant = item.get("participants")
		if not ContractScript.safe_identifier(match_id) or seen.has(match_id) \
				or not completed.ends_with("Z") or subject_seat not in [0, 1] \
				or reward not in [-1, 0, 1] \
				or item.get("subject_result") != {1: "win", 0: "draw", -1: "loss"}[reward] \
				or item.get("result_outcome") not in ["seat0_win", "seat1_win", "draw"] \
				or typeof(item.get("clean")) != TYPE_BOOL \
				or not participants is Array or participants.size() != 2 \
				or typeof(item.get("replay_available")) != TYPE_BOOL:
			return _failure("marketplace_strategy_archive_response_invalid")
		if not previous_completed.is_empty() and (
			completed > previous_completed
			or (completed == previous_completed and match_id >= previous_match_id)
		):
			return _failure("marketplace_strategy_archive_response_invalid")
		previous_completed = completed
		previous_match_id = match_id
		seen[match_id] = true
		for seat: int in 2:
			var participant: Variant = participants[seat]
			if not participant is Dictionary or participant.get("seat") != seat \
					or not ContractScript.safe_identifier(participant.get("release_id")) \
					or not ContractScript.safe_identifier(participant.get("strategy_id")) \
					or not ContractScript.safe_identifier(participant.get("author_id")) \
					or typeof(participant.get("display_name")) != TYPE_STRING \
					or str(participant.get("display_name")).is_empty() \
					or typeof(participant.get("deck_display_name")) != TYPE_STRING:
				return _failure("marketplace_strategy_archive_response_invalid")
		if participants[subject_seat].get("release_id") != _expected_id:
			return _failure("marketplace_strategy_archive_response_invalid")
		var replay_path: Variant = item.get("replay_path")
		if bool(item.get("replay_available")):
			if replay_path != "/v1/competition-matches/%s/replay" % match_id:
				return _failure("marketplace_strategy_archive_response_invalid")
		elif replay_path != null:
			return _failure("marketplace_strategy_archive_response_invalid")
	return _success({
		"profile_id": value.get("profile_id"),
		"strategy": value.get("strategy", {}).duplicate(true),
		"recent_matches": matches.duplicate(true),
	})


func _validate_marketplace_author_top_strategies(value: Variant) -> Dictionary:
	if not _valid_marketplace_document(value) \
			or value.get("document_type") != "strategy_marketplace_author_top_strategies_v1" \
			or value.get("profile_id") != _expected_profile_id \
			or not value.get("author") is Dictionary \
			or value.get("author", {}).get("author_id") != _expected_author_id \
			or value.get("order") != "score_desc_global_rank_asc" \
			or value.get("ranking_artifact_domain") != "competition_ptcgbot" \
			or value.get("download_artifact_domain") != "device_ptcgai" \
			or not ContractScript.safe_identifier(value.get("ranking_snapshot_id")) \
			or value.get("snapshot_consistent") != true:
		return _failure("marketplace_author_top_strategies_response_invalid")
	var items: Array = value.get("items")
	if items.size() > _requested_limit or items.size() > 5:
		return _failure("marketplace_author_top_strategies_response_invalid")
	var previous_global_rank := 0
	for index: int in items.size():
		var item_value: Variant = items[index]
		if not item_value is Dictionary:
			return _failure("marketplace_author_top_strategies_response_invalid")
		var item := item_value as Dictionary
		if not _valid_score_item(item) or not _valid_strategy_ranking_item(item) \
				or item.get("author_id") != _expected_author_id \
				or item.get("author_strategy_rank") != index + 1 \
				or int(item.get("rank")) <= previous_global_rank:
			return _failure("marketplace_author_top_strategies_response_invalid")
		previous_global_rank = int(item.get("rank"))
	return _success({
		"author": value.get("author", {}).duplicate(true),
		"items": items.duplicate(true),
		"ranking_snapshot_id": value.get("ranking_snapshot_id"),
		"score_formula": value.get("score_formula", ""),
	})


func _validate_package_download(headers: PackedStringArray, body: PackedByteArray) -> Dictionary:
	if _expected_release.is_empty() or not _valid_marketplace_release(_expected_release):
		return _failure("marketplace_package_release_invalid")
	var normalized := {}
	for header: String in headers:
		var separator := header.find(":")
		if separator <= 0:
			continue
		normalized[header.left(separator).strip_edges().to_lower()] = header.substr(
			separator + 1
		).strip_edges()
	if normalized.get("content-type") != "application/vnd.ptcgdap.strategy-package":
		return _failure("marketplace_package_content_type_invalid")
	if not normalized.has("content-length") or not str(normalized.get("content-length")).is_valid_int() \
			or int(normalized.get("content-length")) != body.size():
		return _failure("marketplace_package_length_invalid")
	var expected_sha := str(_expected_release.get("archive_sha256", ""))
	var etag := str(normalized.get("etag", ""))
	if etag != "\"%s\"" % expected_sha:
		return _failure("marketplace_package_etag_invalid")
	if ContractScript.sha256(body) != expected_sha:
		return _failure("marketplace_package_hash_mismatch")
	var expected := {
		"package_id": _expected_release.get("package_id"),
		"package_version": _expected_release.get("package_version"),
		"archive_sha256": expected_sha,
		"manifest_canonical_sha256": _expected_release.get("manifest_canonical_sha256"),
	}
	return _success({
		"package_bytes": body.duplicate(),
		"expected_release": expected,
		"release_id": _expected_release.get("release_id"),
	})


func _validate_continuous_ladder_package_download(
	headers: PackedStringArray, body: PackedByteArray
) -> Dictionary:
	if not _valid_continuous_ladder_installable_release(_expected_release):
		return _failure("continuous_ladder_package_release_invalid")
	var normalized := {}
	for header: String in headers:
		var separator := header.find(":")
		if separator <= 0:
			continue
		normalized[header.left(separator).strip_edges().to_lower()] = header.substr(
			separator + 1
		).strip_edges()
	if normalized.get("content-type") != "application/vnd.ptcgdap.strategy-package" \
			or not normalized.has("content-length") \
			or not str(normalized.get("content-length")).is_valid_int() \
			or int(normalized.get("content-length")) != body.size() \
			or body.size() != int(_expected_release.get("archive_bytes", 0)):
		return _failure("continuous_ladder_package_response_invalid")
	var expected_sha := str(_expected_release.get("archive_sha256", ""))
	if str(normalized.get("etag", "")) != "\"%s\"" % expected_sha \
			or ContractScript.sha256(body) != expected_sha:
		return _failure("continuous_ladder_package_hash_mismatch")
	return _success({
		"package_bytes": body.duplicate(),
		"expected_release": {
			"package_id": _expected_release.get("package_id"),
			"package_version": _expected_release.get("package_version"),
			"archive_sha256": expected_sha,
			"manifest_canonical_sha256": _expected_release.get(
				"manifest_canonical_sha256"
			),
		},
		"release_id": _expected_release.get("release_id"),
	})


func _valid_marketplace_document(value: Variant) -> bool:
	return value is Dictionary \
		and value.get("schema_version") == 1 \
		and value.get("player_runtime_authority") == false \
		and _base_non_authoritative(value) \
		and value.get("items") is Array


func _valid_marketplace_item_order(
	items: Array, artifact_domain: String = "device_ptcgai"
) -> bool:
	var previous_published := ""
	var previous_strategy := ""
	var previous_release := ""
	for item_value: Variant in items:
		if not item_value is Dictionary:
			return false
		var item := item_value as Dictionary
		if (
			artifact_domain == "competition_ptcgbot"
			and not _valid_competition_marketplace_item(item)
		) or (
			artifact_domain == "device_ptcgai"
			and not _valid_marketplace_item(item)
		):
			return false
		var published := str(item.get("published_at_utc"))
		var strategy_id := str(item.get("strategy_id"))
		var release_id := str(
			item.get("competition_release_id", "")
			if artifact_domain == "competition_ptcgbot"
			else item.get("installable_release", {}).get("release_id")
		)
		if not previous_published.is_empty() and (
			published > previous_published
			or (published == previous_published and strategy_id < previous_strategy)
			or (
				published == previous_published and strategy_id == previous_strategy
				and release_id <= previous_release
			)
		):
			return false
		previous_published = published
		previous_strategy = strategy_id
		previous_release = release_id
	return true


func _valid_competition_marketplace_item(item: Dictionary) -> bool:
	if not ContractScript.safe_identifier(item.get("competition_release_id")) \
			or not ContractScript.safe_identifier(item.get("strategy_id")) \
			or not ContractScript.safe_identifier(item.get("competition_release_version"), 64) \
			or typeof(item.get("display_name")) != TYPE_STRING \
			or str(item.get("display_name")).is_empty() \
			or typeof(item.get("summary")) != TYPE_STRING \
			or not item.get("author") is Dictionary \
			or not ContractScript.safe_identifier(item.get("author", {}).get("author_id")) \
			or typeof(item.get("published_at_utc")) != TYPE_STRING \
			or not str(item.get("published_at_utc")).ends_with("Z") \
			or item.get("artifact_domain") != "competition_ptcgbot" \
			or typeof(item.get("download_available")) != TYPE_BOOL:
		return false
	if bool(item.get("download_available")):
		var binding: Variant = item.get("distribution_binding")
		return item.get("download_unavailable_reason") == "" \
			and item.get("installable_release") is Dictionary \
			and _valid_marketplace_release(item.get("installable_release")) \
			and binding is Dictionary \
			and binding.get("binding_state") == "verified" \
			and binding.get("association_kind") == "exact_behavior_conformant" \
			and binding.get("rank_transfer_allowed") == true \
			and ContractScript.valid_sha256(binding.get("conformance_evidence_sha256"))
	return item.get("installable_release") == null \
		and item.get("distribution_binding") == null \
		and item.get("download_unavailable_reason") in [
			"device_release_binding_missing", "device_release_unavailable"
		]


func _valid_marketplace_item(item: Dictionary) -> bool:
	return ContractScript.safe_identifier(item.get("strategy_id")) \
		and typeof(item.get("display_name")) == TYPE_STRING \
		and not str(item.get("display_name")).is_empty() \
		and item.get("author") is Dictionary \
		and ContractScript.safe_identifier(item.get("author", {}).get("author_id")) \
		and typeof(item.get("published_at_utc")) == TYPE_STRING \
		and str(item.get("published_at_utc")).ends_with("Z") \
		and item.get("download_available") == true \
		and item.get("artifact_domain") == "device_ptcgai" \
		and item.get("installable_release") is Dictionary \
		and _valid_marketplace_release(item.get("installable_release")) \
		and item.get("installable_release", {}).get("strategy_id") == item.get("strategy_id")


func _valid_strategy_ranking_item(item: Dictionary) -> bool:
	if not ContractScript.safe_identifier(item.get("competition_release_id")) \
			or not ContractScript.safe_identifier(item.get("strategy_id")) \
			or not ContractScript.safe_identifier(item.get("author_id")) \
			or item.get("artifact_domain") != "device_ptcgai" \
			or typeof(item.get("download_available")) != TYPE_BOOL:
		return false
	if bool(item.get("download_available")):
		var binding: Variant = item.get("distribution_binding")
		return item.get("download_unavailable_reason") == "" \
			and item.get("installable_release") is Dictionary \
			and _valid_marketplace_release(item.get("installable_release")) \
			and binding is Dictionary \
			and binding.get("binding_state") == "verified" \
			and binding.get("association_kind") == "exact_behavior_conformant" \
			and binding.get("rank_transfer_allowed") == true \
			and ContractScript.valid_sha256(binding.get("conformance_evidence_sha256"))
	return item.get("installable_release") == null \
		and item.get("distribution_binding") == null \
		and item.get("download_unavailable_reason") in [
			"device_release_binding_missing", "device_release_unavailable"
		]


func _valid_score_item(item: Dictionary) -> bool:
	for field: String in [
		"rank", "games", "wins", "losses", "draws", "kaggle_score_micros",
		"win_rate_micros", "points_rate_micros"
	]:
		if typeof(item.get(field)) != TYPE_INT:
			return false
	if int(item.get("rank")) < 1 or int(item.get("games")) < 0 \
			or int(item.get("wins")) < 0 or int(item.get("losses")) < 0 \
			or int(item.get("draws")) < 0 \
			or int(item.get("wins")) + int(item.get("losses")) + int(item.get("draws")) \
				!= int(item.get("games")) \
			or typeof(item.get("provisional")) != TYPE_BOOL:
		return false
	return true


func _valid_marketplace_release(value: Variant) -> bool:
	if not _valid_release(value) or value.get("release_state") != "curated" \
			or value.get("revocation_state") != "active" \
			or value.get("compatibility_state") != "compatible" \
			or value.get("download_available") != true \
			or value.get("artifact_domain") != "device_ptcgai" \
			or not value.get("author") is Dictionary \
			or not ContractScript.safe_identifier(value.get("author", {}).get("author_id")) \
			or typeof(value.get("published_at_utc")) != TYPE_STRING:
		return false
	var distribution: Variant = value.get("distribution")
	return distribution is Dictionary \
		and distribution.get("available") == true \
		and distribution.get("reason") == "" \
		and distribution.get("href") == "/v1/strategy-releases/%s/package" % value.get("release_id") \
		and distribution.get("media_type") == "application/vnd.ptcgdap.strategy-package" \
		and typeof(distribution.get("archive_bytes")) == TYPE_INT \
		and int(distribution.get("archive_bytes")) > 0 \
		and int(distribution.get("archive_bytes")) <= MAX_PACKAGE_RESPONSE_BYTES \
		and distribution.get("etag") == value.get("archive_sha256")


func _valid_release(value: Variant) -> bool:
	return value is Dictionary and _base_non_authoritative(value) \
		and value.get("document_type") == "strategy_release_record_v1" \
		and value.get("schema_version") == 1 \
		and ContractScript.safe_identifier(value.get("release_id")) \
		and ContractScript.safe_identifier(value.get("strategy_id")) \
		and ContractScript.safe_identifier(value.get("package_id")) \
		and ContractScript.safe_identifier(value.get("package_version"), 64) \
		and ContractScript.valid_sha256(value.get("archive_sha256")) \
		and ContractScript.valid_sha256(value.get("manifest_canonical_sha256")) \
		and value.get("release_state") in ["curated", "deprecated", "revoked"] \
		and value.get("revocation_state") in ["active", "deprecated", "revoked"] \
		and value.get("compatibility_state") in ["compatible", "incompatible"] \
		and typeof(value.get("challenge_available")) == TYPE_BOOL \
		and typeof(value.get("player_start_allowed")) == TYPE_BOOL


func _valid_stats_lane(value: Variant, official: bool) -> bool:
	if not value is Dictionary or value.get("official") != official \
			or typeof(value.get("available")) != TYPE_BOOL:
		return false
	if not bool(value.get("available")):
		return value.get("status") == "data_unavailable" and value.get("summary") == null
	return value.get("status") == ("published" if official else "shadow_test_only") \
		and value.get("summary") is Dictionary


func _parse_canonical(body: PackedByteArray) -> Dictionary:
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return _failure("platform_response_invalid")
	var value: Variant = ContractScript.coerce_integral_numbers(json.data)
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact(
		value, {"max_output_bytes": MAX_JSON_RESPONSE_BYTES}
	)
	if not bool(canonical.get("ok", false)) or canonical.get("bytes", PackedByteArray()) != body:
		return _failure("platform_response_noncanonical")
	return {"accepted": true, "value": value}


func _server_error_code(body: PackedByteArray) -> String:
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return "platform_server_rejected"
	var value: Dictionary = json.data
	if not _base_non_authoritative(value):
		return "platform_server_rejected"
	var code: Variant = value.get("error_code")
	return str(code) if typeof(code) == TYPE_STRING and ContractScript.safe_identifier(code) \
		else "platform_server_rejected"


func _finish(value: Dictionary) -> void:
	_last_result = value.duplicate(true)
	request_completed.emit(_last_result.duplicate(true))


static func _base_non_authoritative(value: Dictionary) -> bool:
	return value.get("authoritative") == false and value.get("grants") == []


static func _success(fields: Dictionary) -> Dictionary:
	var result := {"accepted": true, "error_code": "", "authoritative": false, "grants": []}
	result.merge(fields)
	return result


static func _response_failure(code: String, retryable: bool, status: int) -> Dictionary:
	return {
		"accepted": false,
		"error_code": code,
		"retryable": retryable,
		"http_status": status,
		"authoritative": false,
		"grants": [],
	}


static func _failure(code: String) -> Dictionary:
	return {"accepted": false, "error_code": code, "authoritative": false, "grants": []}
