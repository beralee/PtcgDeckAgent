extends Node

signal state_changed(snapshot: Dictionary)
const Manifest := preload("res://scripts/card_content/ContentManifest.gd")
const Paths := preload("res://scripts/card_content/ContentPaths.gd")
const Bootstrap := preload("res://scripts/card_content/ContentBootstrap.gd")
var _state := "idle"
var _message := "卡牌内容已就绪"
var _candidate := {}
var _envelope := {}
var _store: RefCounted
var _busy := false
var _checked_at := 0
var _etag := ""
var _completed := 0
var _total := 0
var _auto_download := true

func _ready() -> void:
	if not Bootstrap.is_enabled():
		_auto_download = false
		_state = "disabled"
		_message = ""
		return
	var bootstrap := get_node_or_null("/root/CardContentBootstrap")
	if bootstrap != null: _store = bootstrap.store
	var config := ConfigFile.new()
	if config.load("user://card_content/preferences.cfg") == OK:
		_auto_download = bool(config.get_value("updates", "auto_download", true))
	if _store != null and not _store.read_json(_store.root.path_join("pending.json")).is_empty():
		_state = "ready"
		_message = "卡牌更新已下载，重启游戏后生效"

func snapshot() -> Dictionary:
	var active := Paths.snapshot()
	return {"state": _state, "message": _message, "auto_download": Bootstrap.is_enabled() and _auto_download,
		"current_version": active.get("manifest", {}).get("content_version", "内置版本"),
		"available_version": _candidate.get("manifest", {}).get("content_version", ""),
		"notes": _candidate.get("manifest", {}).get("notes", ""), "completed_bytes": _completed,
		"total_bytes": _total, "busy": _busy,
		"restart_available": Bootstrap.is_enabled() and _store != null and not _store.read_json(_store.root.path_join("pending.json")).is_empty()}

func _set_state(state: String, message: String) -> void:
	_state = state
	_message = message
	state_changed.emit(snapshot())

func set_auto_download(enabled: bool) -> void:
	if not Bootstrap.is_enabled(): return
	_auto_download = enabled
	var config := ConfigFile.new()
	config.set_value("updates", "auto_download", enabled)
	config.save("user://card_content/preferences.cfg")
	state_changed.emit(snapshot())

func check_for_updates(manual: bool = false) -> void:
	if not Bootstrap.is_enabled(): return
	if _busy or _store == null: return
	if not manual and (DisplayServer.get_name() == "headless" or Time.get_ticks_msec() - _checked_at < 300000 and _checked_at > 0): return
	_busy = true
	_checked_at = Time.get_ticks_msec()
	_set_state("checking", "正在检查卡牌更新…")
	var headers := PackedStringArray()
	if not _etag.is_empty() and not _candidate.is_empty(): headers.append("If-None-Match: " + _etag)
	var response: Dictionary = await _fetch("/v1/card-content/channels/stable", Manifest.MAX_MANIFEST * 2, headers)
	_busy = false
	if response.code == 304:
		if not _store.read_json(_store.root.path_join("pending.json")).is_empty():
			_set_state("ready", "卡牌更新已下载，重启游戏后生效")
		elif _candidate.get("release_id", "") != Paths.release_id():
			_set_state("available", "发现卡牌更新 · " + str(_candidate.manifest.content_version))
			if _auto_download: download_update()
		else:
			_set_state("current", "已是最新卡牌内容")
		return
	if response.code == 404:
		_set_state("current", "暂无新的卡牌内容")
		return
	if response.code != 200:
		_set_state("failed", "暂时无法检查更新，已下载卡牌仍可使用")
		return
	var envelope: Variant = JSON.parse_string(response.body.get_string_from_utf8())
	var trust: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/card_content/trust.json"))
	var checked := Manifest.verify(envelope, trust if trust is Dictionary else {}, str(ProjectSettings.get_setting("application/config/version", "0.0.0")), preload("res://scripts/card_content/ContentBootstrap.gd").platform())
	if not checked.ok:
		_set_state("failed", "此卡牌更新需要新版客户端" if checked.error_code == "client_update_required" else "卡牌更新校验失败，保留当前版本")
		return
	var admitted: Dictionary = _store.assess(envelope)
	if not admitted.ok:
		_candidate = {}
		_envelope = {}
		_etag = ""
		_set_state("failed", "已保留可用版本，等待新的卡牌修复" if admitted.error_code == "candidate_previously_failed" else "此更新早于已安装版本，保留当前卡牌")
		return
	_candidate = checked
	_envelope = envelope
	for header: String in response.headers:
		if header.to_lower().begins_with("etag:"): _etag = header.substr(5).strip_edges()
	if checked.release_id == Paths.release_id():
		_set_state("current", "已是最新卡牌内容")
		return
	_total = 0
	for pack: Dictionary in _store.missing_packs(checked.manifest): _total += int(pack.size)
	_set_state("available", "发现卡牌更新 · " + str(checked.manifest.content_version))
	if _auto_download: download_update()

func download_update() -> void:
	if not Bootstrap.is_enabled(): return
	if _busy or _candidate.is_empty() or _store == null: return
	_busy = true
	_completed = 0
	var missing: Array = _store.missing_packs(_candidate.manifest)
	_total = 0
	for pack: Dictionary in missing: _total += int(pack.size)
	_set_state("downloading", "正在下载卡牌更新…")
	for pack: Dictionary in missing:
		var response: Dictionary = await _fetch("/v1/card-content/objects/" + str(pack.sha256), int(pack.size))
		if response.code != 200 or _store.put_object(pack, response.body, true) != OK:
			_busy = false
			_set_state("failed", "下载未完成，可重试；当前卡牌版本保持不变")
			return
		_completed += int(pack.size)
		state_changed.emit(snapshot())
	var result: Dictionary = _store.stage(_envelope)
	_busy = false
	_set_state("ready" if result.ok else "failed", "卡牌更新已下载，重启游戏后生效" if result.ok else "更新未能准备就绪，保留当前版本")

func _fetch(path: String, limit: int, headers: PackedStringArray = PackedStringArray()) -> Dictionary:
	if not Bootstrap.is_enabled():
		return {"code": 0, "body": PackedByteArray(), "headers": PackedStringArray()}
	var origin := Paths.origin()
	# Plain HTTP is only accepted by an explicitly built local acceptance project.
	if not origin.begins_with("https://") and not (OS.has_feature("card_content_test") and origin.begins_with("http://127.0.0.1:")):
		return {"code": 0, "body": PackedByteArray(), "headers": PackedStringArray()}
	var request := HTTPRequest.new()
	request.timeout = 45.0
	request.max_redirects = 0
	request.body_size_limit = limit
	add_child(request)
	var error := request.request(origin + path, headers)
	if error != OK:
		request.queue_free()
		return {"code": 0, "body": PackedByteArray(), "headers": PackedStringArray()}
	var result: Array = await request.request_completed
	request.queue_free()
	return {"code": int(result[1]) if int(result[0]) == HTTPRequest.RESULT_SUCCESS else 0, "headers": result[2], "body": result[3]}
