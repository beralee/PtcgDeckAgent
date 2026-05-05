class_name DeckSuggestionClient
extends Node

const AppVersionScript := preload("res://scripts/app/AppVersion.gd")

const ENDPOINT_URL := "http://fc.skillserver.cn/decksuggest"
const REQUEST_TIMEOUT_SECONDS := 10.0

signal fetch_succeeded(response: Dictionary)
signal fetch_failed(message: String)

var _http_request: HTTPRequest = null
var _is_fetching := false


static func build_payload(current_id: String = "", exclude_ids: PackedStringArray = PackedStringArray(), metadata: Dictionary = {}) -> Dictionary:
	return {
		"current_id": current_id.strip_edges(),
		"exclude_ids": Array(exclude_ids),
		"app_version": str(metadata.get("app_version", AppVersionScript.DISPLAY_VERSION)),
		"platform": str(metadata.get("platform", OS.get_name())),
		"source": str(metadata.get("source", "deck_manager_recommendation")),
		"requested_at": int(metadata.get("requested_at", Time.get_unix_time_from_system())),
	}


static func extract_recommendation(response: Dictionary) -> Dictionary:
	if not bool(response.get("ok", false)):
		return {}
	var recommendation: Variant = response.get("recommendation", {})
	return (recommendation as Dictionary).duplicate(true) if recommendation is Dictionary else {}


func fetch_next_recommendation(current_id: String = "", exclude_ids: PackedStringArray = PackedStringArray(), metadata: Dictionary = {}) -> int:
	if _is_fetching:
		return ERR_BUSY

	_ensure_http_request()
	if _http_request == null:
		fetch_failed.emit("无法创建卡组推荐请求。")
		return ERR_CANT_CREATE

	var body := JSON.stringify(build_payload(current_id, exclude_ids, metadata))
	var headers := PackedStringArray([
		"Content-Type: application/json; charset=utf-8",
		"User-Agent: PTCGDeckAgent/%s" % AppVersionScript.VERSION,
	])

	_is_fetching = true
	var err := _http_request.request(ENDPOINT_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_is_fetching = false
		fetch_failed.emit("卡组推荐请求启动失败：%d" % err)
	return err


func is_fetching() -> bool:
	return _is_fetching


func _ready() -> void:
	_ensure_http_request()


func _ensure_http_request() -> void:
	if _http_request != null:
		return
	_http_request = HTTPRequest.new()
	_http_request.timeout = REQUEST_TIMEOUT_SECONDS
	_http_request.use_threads = true
	_http_request.request_completed.connect(_on_fetch_response)
	add_child(_http_request)


func _on_fetch_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_fetching = false
	if result != HTTPRequest.RESULT_SUCCESS:
		fetch_failed.emit(_request_result_message(result))
		return
	if response_code < 200 or response_code >= 300:
		fetch_failed.emit("卡组推荐服务器返回 HTTP %d。" % response_code)
		return

	var response_text := body.get_string_from_utf8()
	var json := JSON.new()
	var parse_err := json.parse(response_text)
	if parse_err != OK or not (json.data is Dictionary):
		fetch_failed.emit("卡组推荐服务器响应解析失败。")
		return

	var response := json.data as Dictionary
	if not bool(response.get("ok", false)):
		var message := str(response.get("message", response.get("errMsg", "卡组推荐服务器暂时没有返回可用内容。")))
		fetch_failed.emit(message)
		return

	if extract_recommendation(response).is_empty():
		fetch_failed.emit("卡组推荐服务器返回的数据缺少 recommendation。")
		return

	fetch_succeeded.emit(response)


func _request_result_message(result: int) -> String:
	match result:
		HTTPRequest.RESULT_TIMEOUT:
			return "卡组推荐请求超时，已切回本地推荐。"
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CONNECTION_ERROR, HTTPRequest.RESULT_NO_RESPONSE:
			return "卡组推荐服务器暂时连接不上，已切回本地推荐。"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "无法解析卡组推荐服务器地址，已切回本地推荐。"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "卡组推荐服务器 TLS 握手失败，已切回本地推荐。"
		_:
			return "卡组推荐请求失败：result=%d。" % result
