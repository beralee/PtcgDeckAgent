class_name FeedbackClient
extends Node

const AppVersionScript := preload("res://scripts/app/AppVersion.gd")

const ENDPOINT_URL := "http://fc.skillserver.cn/ptcg"
const REQUEST_TIMEOUT_SECONDS := 12.0
const MAX_NAME_LENGTH := 40
const MAX_CONTENT_LENGTH := 2000

signal submit_succeeded(response: Dictionary)
signal submit_failed(message: String)

var _http_request: HTTPRequest = null
var _is_submitting := false


static func validate_feedback(_player_name: String, content: String) -> String:
	var clean_content := content.strip_edges()
	if clean_content == "":
		return "请先写下建议或 bug 描述，再提交给我。"
	if clean_content.length() > MAX_CONTENT_LENGTH:
		return "反馈内容最多 %d 字，请先压缩一下描述。" % MAX_CONTENT_LENGTH
	return ""


static func build_payload(player_name: String, content: String, metadata: Dictionary = {}) -> Dictionary:
	var clean_name := player_name.strip_edges()
	if clean_name == "":
		clean_name = "匿名玩家"
	if clean_name.length() > MAX_NAME_LENGTH:
		clean_name = clean_name.left(MAX_NAME_LENGTH)

	var clean_content := content.strip_edges()
	if clean_content.length() > MAX_CONTENT_LENGTH:
		clean_content = clean_content.left(MAX_CONTENT_LENGTH)

	return {
		"name": clean_name,
		"content": clean_content,
		"app_version": str(metadata.get("app_version", AppVersionScript.DISPLAY_VERSION)),
		"platform": str(metadata.get("platform", OS.get_name())),
		"source": str(metadata.get("source", "main_menu_feedback")),
		"submitted_at": int(metadata.get("submitted_at", Time.get_unix_time_from_system())),
	}


func submit_feedback(player_name: String, content: String, metadata: Dictionary = {}) -> int:
	if _is_submitting:
		return ERR_BUSY

	var validation_message := validate_feedback(player_name, content)
	if validation_message != "":
		submit_failed.emit(validation_message)
		return ERR_INVALID_DATA

	_ensure_http_request()
	if _http_request == null:
		submit_failed.emit("无法创建反馈提交请求。")
		return ERR_CANT_CREATE

	var body := JSON.stringify(build_payload(player_name, content, metadata))
	var headers := PackedStringArray([
		"Content-Type: application/json; charset=utf-8",
		"User-Agent: PTCGDeckAgent/%s" % AppVersionScript.VERSION,
	])

	_is_submitting = true
	var err := _http_request.request(ENDPOINT_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_is_submitting = false
		submit_failed.emit("反馈提交启动失败：%d" % err)
	return err


func _ready() -> void:
	_ensure_http_request()


func _ensure_http_request() -> void:
	if _http_request != null:
		return
	_http_request = HTTPRequest.new()
	_http_request.timeout = REQUEST_TIMEOUT_SECONDS
	_http_request.use_threads = true
	_http_request.request_completed.connect(_on_submit_response)
	add_child(_http_request)


func _on_submit_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_submitting = false
	if result != HTTPRequest.RESULT_SUCCESS:
		submit_failed.emit(_request_result_message(result))
		return
	if response_code < 200 or response_code >= 300:
		submit_failed.emit("反馈服务器返回 HTTP %d。" % response_code)
		return

	var response_text := body.get_string_from_utf8()
	var json := JSON.new()
	var parse_err := json.parse(response_text)
	if parse_err != OK or not (json.data is Dictionary):
		submit_failed.emit("反馈服务器响应解析失败。")
		return

	var response := json.data as Dictionary
	if not bool(response.get("ok", false)):
		var message := str(response.get("message", response.get("errMsg", "反馈服务器拒绝了这次提交。")))
		submit_failed.emit(message)
		return

	submit_succeeded.emit(response)


func _request_result_message(result: int) -> String:
	match result:
		HTTPRequest.RESULT_TIMEOUT:
			return "反馈提交超时，请稍后重试。"
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CONNECTION_ERROR, HTTPRequest.RESULT_NO_RESPONSE:
			return "反馈服务器暂时连接不上，请稍后重试。"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "无法解析反馈服务器地址，请检查网络。"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "反馈服务器 TLS 握手失败，请稍后重试。"
		_:
			return "反馈提交失败：result=%d。" % result
