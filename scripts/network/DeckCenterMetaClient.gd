class_name DeckCenterMetaClient
extends Node

const AppVersionScript := preload("res://scripts/app/AppVersion.gd")

const ENDPOINT_URL := "http://fc.skillserver.cn/deckcentermeta"
const REQUEST_TIMEOUT_SECONDS := 6.0
const STATE_PATH := "user://deck_center_meta_state.json"

signal new_revision_available(info: Dictionary)
signal no_new_revision(info: Dictionary)
signal check_failed(message: String)

var _http_request: HTTPRequest = null
var _is_checking := false


static func normalize_meta(data: Dictionary) -> Dictionary:
	if not bool(data.get("ok", false)):
		return {}
	var latest_revision := str(data.get("latest_revision", "")).strip_edges()
	if latest_revision == "":
		return {}
	return {
		"schema_version": int(data.get("schema_version", 1)),
		"channel": str(data.get("channel", "deck_recommendations")),
		"latest_revision": latest_revision,
		"latest_recommendation_id": str(data.get("latest_recommendation_id", "")).strip_edges(),
		"latest_deck_id": int(data.get("latest_deck_id", 0)),
		"latest_title": str(data.get("latest_title", "")).strip_edges(),
		"latest_deck_name": str(data.get("latest_deck_name", "")).strip_edges(),
		"updated_at": int(data.get("updated_at", 0)),
		"updated_at_iso": str(data.get("updated_at_iso", "")).strip_edges(),
		"source": str(data.get("source", "")).strip_edges(),
	}


static func is_unseen_revision(latest_revision: String, seen_revision: String) -> bool:
	var latest := latest_revision.strip_edges()
	if latest == "":
		return false
	return latest != seen_revision.strip_edges()


static func is_bootstrap_meta(info: Dictionary) -> bool:
	var latest_revision := str(info.get("latest_revision", "")).strip_edges()
	var recommendation_id := str(info.get("latest_recommendation_id", "")).strip_edges()
	var source := str(info.get("source", "")).strip_edges()
	return latest_revision.begins_with("bootstrap:") or recommendation_id == "bootstrap-old" or source == "manual_bootstrap"


func check_latest() -> int:
	if _is_checking:
		return ERR_BUSY

	_ensure_http_request()
	if _http_request == null:
		check_failed.emit("cannot create deck center metadata request")
		return ERR_CANT_CREATE

	_is_checking = true
	var err := _http_request.request(
		ENDPOINT_URL,
		PackedStringArray(["User-Agent: PTCGDeckAgent/%s" % AppVersionScript.VERSION]),
		HTTPClient.METHOD_GET
	)
	if err != OK:
		_is_checking = false
		check_failed.emit("deck center metadata request start failed: %d" % err)
	return err


func mark_revision_seen(revision: String, info: Dictionary = {}) -> void:
	var clean_revision := revision.strip_edges()
	if clean_revision == "":
		return
	var state := _load_state()
	state["last_seen_revision"] = clean_revision
	state["last_seen_at"] = int(Time.get_unix_time_from_system())
	if not info.is_empty():
		state["latest_info"] = info.duplicate(true)
	_save_state(state)


func get_last_seen_revision() -> String:
	return str(_load_state().get("last_seen_revision", "")).strip_edges()


func _ready() -> void:
	_ensure_http_request()


func _ensure_http_request() -> void:
	if _http_request != null:
		return
	_http_request = HTTPRequest.new()
	_http_request.timeout = REQUEST_TIMEOUT_SECONDS
	_http_request.use_threads = true
	_http_request.request_completed.connect(_on_meta_response)
	add_child(_http_request)


func _on_meta_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_checking = false
	if result != HTTPRequest.RESULT_SUCCESS:
		check_failed.emit("deck center metadata check failed: result=%d" % result)
		return
	if response_code < 200 or response_code >= 300:
		check_failed.emit("deck center metadata server returned HTTP %d" % response_code)
		return

	var json := JSON.new()
	var parse_err := json.parse(body.get_string_from_utf8())
	if parse_err != OK or not (json.data is Dictionary):
		check_failed.emit("deck center metadata response parse failed")
		return

	var raw := json.data as Dictionary
	var info := normalize_meta(raw)
	if info.is_empty():
		if str(raw.get("code", "")) == "EMPTY":
			no_new_revision.emit({})
			return
		check_failed.emit(str(raw.get("message", "deck center metadata missing latest_revision")))
		return

	_handle_checked_meta(info)


func _handle_checked_meta(info: Dictionary) -> void:
	var state := _load_state()
	var latest_revision := str(info.get("latest_revision", "")).strip_edges()
	var seen_revision := str(state.get("last_seen_revision", "")).strip_edges()
	var recommendation_seen_revision := str(state.get("last_recommendation_badge_seen_revision", "")).strip_edges()
	if latest_revision != "" and recommendation_seen_revision == latest_revision and seen_revision != latest_revision:
		seen_revision = latest_revision
		state["last_seen_revision"] = latest_revision
		state["last_seen_at"] = int(state.get("last_recommendation_badge_seen_at", Time.get_unix_time_from_system()))
	state["last_checked_at"] = int(Time.get_unix_time_from_system())
	state["latest_info"] = info.duplicate(true)

	if seen_revision == "":
		_save_state(state)
		if is_bootstrap_meta(info):
			mark_revision_seen(latest_revision, info)
			no_new_revision.emit(info)
		else:
			new_revision_available.emit(info)
		return

	_save_state(state)
	if is_unseen_revision(latest_revision, seen_revision):
		new_revision_available.emit(info)
	else:
		no_new_revision.emit(info)


func _load_state() -> Dictionary:
	if not FileAccess.file_exists(STATE_PATH):
		return {}
	var file := FileAccess.open(STATE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {}
	return (json.data as Dictionary).duplicate(true)


func _save_state(state: Dictionary) -> void:
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(state, "\t"))
	file.close()
