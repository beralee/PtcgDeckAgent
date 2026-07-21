class_name CardImageCacheService
extends Node

signal image_ready(uid: String, local_path: String)
signal image_failed(uid: String, reason: String)
signal image_progress(job_id: String, completed: int, total: int)
signal job_completed(job_id: String, stats: Dictionary, errors: PackedStringArray)
signal job_cancelled(job_id: String)

const STATUS_MISSING := "missing"
const STATUS_QUEUED := "queued"
const STATUS_DOWNLOADING := "downloading"
const STATUS_READY := "ready"
const STATUS_FAILED := "failed"
const STATUS_STALE := "stale"

const DEFAULT_MANIFEST_PATH := "user://cards/image_cache_manifest.json"
const MAX_IMAGE_BYTES := 3 * 1024 * 1024
const MAX_DECODE_SIZE := Vector2i(2048, 3072)
const DEFAULT_RETRY_LIMIT := 3
const DEFAULT_TIMEOUT_SECONDS := 20.0
const TRUSTED_IMAGE_HOSTS := {
	"ptcg.skillserver.cn": true,
	"tcg.mik.moe": true,
	"limitlesstcg.nyc3.cdn.digitaloceanspaces.com": true,
}

var _manifest_path := DEFAULT_MANIFEST_PATH
var _manifest: Dictionary = {}
var _queue: Array[Dictionary] = []
var _active: Dictionary = {}
var _status_by_uid: Dictionary = {}
var _jobs: Dictionary = {}
var _job_counter := 0
var _card_database: Object = null
var _max_concurrency_override := -1
var _cache_budget_override := -1


static func request_headers_for_runtime(os_name: String = "", feature_flags: Dictionary = {}, display_server_name: String = "") -> PackedStringArray:
	var headers := PackedStringArray()
	if _is_web_runtime_for_context(os_name, feature_flags, display_server_name):
		return headers
	headers.append("User-Agent: PTCGTrain/1.0")
	return headers


static func should_auto_download_for_runtime(os_name: String = "", feature_flags: Dictionary = {}, display_server_name: String = "") -> bool:
	return not _is_web_runtime_for_context(os_name, feature_flags, display_server_name)


static func max_concurrency_for_runtime(os_name: String = "", feature_flags: Dictionary = {}, display_server_name: String = "") -> int:
	if _is_web_runtime_for_context(os_name, feature_flags, display_server_name):
		return 1
	var resolved_os := os_name.strip_edges().to_lower()
	var flags := feature_flags
	if flags.is_empty() and os_name == "":
		flags = {
			"android": OS.has_feature("android"),
			"mobile": OS.has_feature("mobile"),
		}
		resolved_os = OS.get_name().strip_edges().to_lower()
	if resolved_os == "android" or bool(flags.get("android", false)) or bool(flags.get("mobile", false)):
		return 2
	return 3


static func cache_budget_bytes_for_runtime(os_name: String = "", feature_flags: Dictionary = {}, display_server_name: String = "") -> int:
	if _is_web_runtime_for_context(os_name, feature_flags, display_server_name):
		return 100 * 1024 * 1024
	var resolved_os := os_name.strip_edges().to_lower()
	var flags := feature_flags
	if flags.is_empty() and os_name == "":
		flags = {"android": OS.has_feature("android"), "mobile": OS.has_feature("mobile")}
		resolved_os = OS.get_name().strip_edges().to_lower()
	if resolved_os == "android" or bool(flags.get("android", false)) or bool(flags.get("mobile", false)):
		return 150 * 1024 * 1024
	return 300 * 1024 * 1024


static func is_trusted_image_url(url: String) -> bool:
	var parts := _parse_https_url(url)
	if parts.is_empty():
		return false
	return bool(TRUSTED_IMAGE_HOSTS.get(str(parts.get("host", "")).to_lower(), false))


static func _is_web_runtime_for_context(os_name: String = "", feature_flags: Dictionary = {}, display_server_name: String = "") -> bool:
	var resolved_os := os_name.strip_edges().to_lower()
	var resolved_display := display_server_name.strip_edges().to_lower()
	var flags := feature_flags
	if flags.is_empty() and os_name == "" and display_server_name == "":
		flags = {
			"web": OS.has_feature("web"),
			"web_android": OS.has_feature("web_android"),
			"web_ios": OS.has_feature("web_ios"),
		}
		resolved_os = OS.get_name().strip_edges().to_lower()
		resolved_display = DisplayServer.get_name().strip_edges().to_lower()
	if resolved_os in ["web", "html5"] or resolved_display in ["web", "html5"]:
		return true
	for feature: String in ["web", "web_android", "web_ios"]:
		if bool(flags.get(feature, false)):
			return true
	return false


static func _parse_https_url(url: String) -> Dictionary:
	var text := url.strip_edges()
	var regex := RegEx.new()
	if regex.compile("(?i)^https://([^/?#:]+)(?::[0-9]+)?(?:[/?#].*)?$") != OK:
		return {}
	var match := regex.search(text)
	if match == null:
		return {}
	return {"host": match.get_string(1)}


func _ready() -> void:
	_load_manifest()


func set_card_database(card_database: Object) -> void:
	_card_database = card_database


func get_status(set_code: String, card_index: String) -> String:
	var uid := _uid(set_code, card_index)
	if _status_by_uid.has(uid):
		return str(_status_by_uid[uid])
	var entry := _manifest_entry(uid)
	var local_path := str(entry.get("local_path", CardData.build_local_image_path(set_code, card_index)))
	if local_path != "" and CardData.is_valid_card_image_file(local_path):
		return STATUS_READY
	if not entry.is_empty() and int(entry.get("fail_count", 0)) > 0:
		return STATUS_FAILED
	if not entry.is_empty() and local_path != "" and FileAccess.file_exists(local_path):
		return STATUS_STALE
	return STATUS_MISSING


func get_local_path_if_ready(set_code: String, card_index: String) -> String:
	var uid := _uid(set_code, card_index)
	var entry := _manifest_entry(uid)
	var preferred := str(entry.get("local_path", CardData.build_local_image_path(set_code, card_index)))
	var resolved := CardData.resolve_existing_image_path(CardData.get_image_candidate_paths(set_code, card_index, preferred))
	if resolved != "":
		_touch_manifest_entry(uid, resolved)
	return resolved


func ensure_image(card: CardData, priority: int = 0, reason: String = "") -> String:
	return ensure_image_with_options(card, {"priority": priority, "reason": reason})


func ensure_image_with_options(card: CardData, options: Dictionary = {}) -> String:
	return ensure_cards([card], options)


func ensure_cards(cards: Array, options: Dictionary = {}) -> String:
	var job_id := _new_job_id()
	var unique_cards: Array[CardData] = []
	var seen := {}
	for raw: Variant in cards:
		if not (raw is CardData):
			continue
		var card := raw as CardData
		card.ensure_image_metadata()
		var uid := card.get_uid()
		if uid == "" or seen.has(uid):
			continue
		seen[uid] = true
		unique_cards.append(card)
	_register_job(job_id, unique_cards.size())
	for card: CardData in unique_cards:
		_enqueue_card_for_job(card, job_id, options)
	_finish_job_if_complete(job_id)
	_process_queue()
	return job_id


func ensure_deck_images(deck: DeckData, options: Dictionary = {}) -> String:
	var cards: Array[CardData] = []
	var seen := {}
	if deck != null:
		for key: Dictionary in deck.get_card_keys():
			var set_code := str(key.get("set_code", "")).strip_edges()
			var card_index := str(key.get("card_index", "")).strip_edges()
			var uid := _uid(set_code, card_index)
			if uid == "_" or seen.has(uid):
				continue
			seen[uid] = true
			var card := _resolve_card(set_code, card_index, options.get("card_database", null))
			if card != null:
				cards.append(card)
	return ensure_cards(cards, options)


func cancel_job(job_id: String) -> void:
	if not _jobs.has(job_id):
		return
	var job: Dictionary = _jobs[job_id]
	job["cancelled"] = true
	_jobs[job_id] = job
	var kept: Array[Dictionary] = []
	for item: Dictionary in _queue:
		if str(item.get("job_id", "")) != job_id:
			kept.append(item)
		else:
			var stats: Dictionary = job.get("stats", {})
			stats["cancelled"] = int(stats.get("cancelled", 0)) + 1
			stats["completed"] = int(stats.get("completed", 0)) + 1
			job["stats"] = stats
	_queue = kept
	job_cancelled.emit(job_id)
	_finish_job_if_complete(job_id)


func retry_failed(set_code: String, card_index: String) -> String:
	var card := _resolve_card(set_code, card_index, null)
	if card == null:
		return ""
	_status_by_uid.erase(card.get_uid())
	return ensure_image(card, 10, "retry")


func enforce_cache_budget(options: Dictionary = {}) -> void:
	_load_manifest()
	var budget := int(options.get("budget_bytes", _cache_budget_override if _cache_budget_override > 0 else cache_budget_bytes_for_runtime()))
	if budget <= 0:
		return
	var protected := _protected_uids(options)
	var entries: Dictionary = _manifest.get("entries", {}) if _manifest.get("entries", {}) is Dictionary else {}
	var total := 0
	var candidates: Array[Dictionary] = []
	for uid_variant: Variant in entries.keys():
		var uid := str(uid_variant)
		var entry: Dictionary = entries[uid] if entries[uid] is Dictionary else {}
		var bytes := int(entry.get("bytes", 0))
		total += bytes
		candidates.append({
			"uid": uid,
			"bytes": bytes,
			"last_accessed_at": int(entry.get("last_accessed_at", 0)),
			"local_path": str(entry.get("local_path", "")),
		})
	if total <= budget:
		return
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("last_accessed_at", 0)) < int(b.get("last_accessed_at", 0))
	)
	for candidate: Dictionary in candidates:
		if total <= budget:
			break
		var uid := str(candidate.get("uid", ""))
		if protected.has(uid):
			continue
		var local_path := str(candidate.get("local_path", ""))
		if local_path != "":
			var absolute := ProjectSettings.globalize_path(local_path)
			if FileAccess.file_exists(local_path) or FileAccess.file_exists(absolute):
				DirAccess.remove_absolute(absolute)
		total -= int(candidate.get("bytes", 0))
		entries.erase(uid)
		_status_by_uid.erase(uid)
	_manifest["entries"] = entries
	_save_manifest()


func save_image_bytes_for_tests(card: CardData, bytes: PackedByteArray) -> int:
	_load_manifest()
	return _save_image_bytes(card, bytes)


func set_manifest_path_for_tests(path: String) -> void:
	_manifest_path = path
	_manifest.clear()
	_load_manifest()


func set_max_concurrency_for_tests(value: int) -> void:
	_max_concurrency_override = value


func set_cache_budget_bytes_for_tests(value: int) -> void:
	_cache_budget_override = value


func get_job_stats_for_tests(job_id: String) -> Dictionary:
	return get_job_stats(job_id)


func get_job_stats(job_id: String) -> Dictionary:
	var job: Dictionary = _jobs.get(job_id, {})
	var stats: Dictionary = job.get("stats", {}) if job.get("stats", {}) is Dictionary else {}
	return stats.duplicate(true)


func get_job_errors(job_id: String) -> PackedStringArray:
	var job: Dictionary = _jobs.get(job_id, {})
	var errors: PackedStringArray = job.get("errors", PackedStringArray())
	return PackedStringArray(errors)


func manifest_for_tests() -> Dictionary:
	_load_manifest()
	return _manifest.duplicate(true)


func queued_count_for_tests() -> int:
	return _queue.size()


func _new_job_id() -> String:
	_job_counter += 1
	return "card_images_%d_%d" % [Time.get_ticks_msec(), _job_counter]


func _register_job(job_id: String, total: int) -> void:
	_jobs[job_id] = {
		"cancelled": false,
		"stats": {
			"total": total,
			"completed": 0,
			"downloaded": 0,
			"skipped": 0,
			"failed": 0,
			"cancelled": 0,
		},
		"errors": PackedStringArray(),
	}
	image_progress.emit(job_id, 0, total)


func _enqueue_card_for_job(card: CardData, job_id: String, options: Dictionary) -> void:
	if card == null:
		_record_job_failure(job_id, "", "missing card")
		return
	card.ensure_image_metadata()
	var uid := card.get_uid()
	var local_path := get_local_path_if_ready(card.set_code, card.card_index)
	if local_path != "":
		_status_by_uid[uid] = STATUS_READY
		_record_job_skip(job_id)
		image_ready.emit(uid, local_path)
		return
	var allow_remote := bool(options.get("allow_remote", should_auto_download_for_runtime()))
	if bool(options.get("skip_remote", false)) or not allow_remote:
		_status_by_uid[uid] = STATUS_MISSING
		_record_job_skip(job_id)
		return
	if not is_trusted_image_url(card.image_url):
		_record_card_failure(job_id, uid, "untrusted image url")
		return
	_status_by_uid[uid] = STATUS_QUEUED
	_queue.append({
		"job_id": job_id,
		"uid": uid,
		"card": card,
		"priority": int(options.get("priority", 0)),
		"reason": str(options.get("reason", "")),
		"attempt": 0,
	})
	_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := int(a.get("priority", 0))
		var pb := int(b.get("priority", 0))
		if pa != pb:
			return pa > pb
		return str(a.get("uid", "")) < str(b.get("uid", ""))
	)


func _process_queue() -> void:
	var limit := _max_concurrency_override if _max_concurrency_override > 0 else max_concurrency_for_runtime()
	while _active.size() < limit and not _queue.is_empty():
		var item: Dictionary = _queue.pop_front()
		var job_id := str(item.get("job_id", ""))
		var job: Dictionary = _jobs.get(job_id, {})
		if bool(job.get("cancelled", false)):
			_record_job_cancelled(job_id)
			continue
		var card: CardData = item.get("card", null)
		if card == null:
			_record_job_failure(job_id, str(item.get("uid", "")), "missing card")
			continue
		_start_request(item)


func _start_request(item: Dictionary) -> void:
	var card: CardData = item.get("card", null)
	var uid := str(item.get("uid", ""))
	if card == null:
		_record_card_failure(str(item.get("job_id", "")), uid, "missing card")
		return
	var request := HTTPRequest.new()
	request.timeout = DEFAULT_TIMEOUT_SECONDS
	add_child(request)
	_status_by_uid[uid] = STATUS_DOWNLOADING
	_active[request.get_instance_id()] = item
	request.request_completed.connect(_on_request_completed.bind(request), CONNECT_ONE_SHOT)
	var err := request.request(card.image_url, request_headers_for_runtime(), HTTPClient.METHOD_GET)
	if err != OK:
		_active.erase(request.get_instance_id())
		request.queue_free()
		_record_card_failure(str(item.get("job_id", "")), uid, "network start error %d" % err)
		_process_queue()


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
	var item: Dictionary = _active.get(request.get_instance_id(), {})
	_active.erase(request.get_instance_id())
	request.queue_free()
	var job_id := str(item.get("job_id", ""))
	var uid := str(item.get("uid", ""))
	var card: CardData = item.get("card", null)
	if card == null:
		_record_job_failure(job_id, uid, "missing card")
		_process_queue()
		return
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var save_err := _save_image_bytes(card, body)
		if save_err == OK:
			_status_by_uid[uid] = STATUS_READY
			_record_job_download(job_id)
			image_ready.emit(uid, card.image_local_path)
		else:
			_record_card_failure(job_id, uid, "invalid image response %d" % save_err)
	elif _should_retry(result, response_code, int(item.get("attempt", 0))):
		item["attempt"] = int(item.get("attempt", 0)) + 1
		_status_by_uid[uid] = STATUS_QUEUED
		_queue.append(item)
	else:
		_record_card_failure(job_id, uid, "HTTP %d result=%d" % [response_code, result])
	_finish_job_if_complete(job_id)
	_process_queue()


func _should_retry(result: int, response_code: int, attempt: int) -> bool:
	if attempt >= DEFAULT_RETRY_LIMIT - 1:
		return false
	if result != HTTPRequest.RESULT_SUCCESS:
		return true
	return response_code >= 500


func _save_image_bytes(card: CardData, bytes: PackedByteArray) -> int:
	if card == null:
		return ERR_INVALID_PARAMETER
	card.ensure_image_metadata()
	if card.image_local_path == "":
		return ERR_INVALID_PARAMETER
	if bytes.is_empty() or bytes.size() > MAX_IMAGE_BYTES:
		return ERR_INVALID_DATA
	if not CardData.has_supported_image_signature(bytes):
		return ERR_INVALID_DATA
	var decoded := _decode_image(bytes)
	if decoded == null:
		return ERR_FILE_UNRECOGNIZED
	if decoded.get_width() > MAX_DECODE_SIZE.x or decoded.get_height() > MAX_DECODE_SIZE.y:
		return ERR_INVALID_DATA

	var final_path := card.image_local_path
	var tmp_path := "%s.tmp" % final_path
	var absolute_dir := ProjectSettings.globalize_path(final_path.get_base_dir())
	if not DirAccess.dir_exists_absolute(absolute_dir):
		var mkdir_err := DirAccess.make_dir_recursive_absolute(absolute_dir)
		if mkdir_err != OK:
			return mkdir_err
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.close()
	if not CardData.is_valid_card_image_file(tmp_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
		return ERR_FILE_CORRUPT
	var absolute_final := ProjectSettings.globalize_path(final_path)
	if FileAccess.file_exists(final_path) or FileAccess.file_exists(absolute_final):
		DirAccess.remove_absolute(absolute_final)
	var rename_err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp_path), absolute_final)
	if rename_err != OK:
		return rename_err
	_update_manifest_success(card, bytes)
	_save_manifest()
	return OK


func _decode_image(bytes: PackedByteArray) -> Image:
	var image := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if CardData.has_png_signature(bytes):
		err = image.load_png_from_buffer(bytes)
	elif CardData.has_jpg_signature(bytes):
		err = image.load_jpg_from_buffer(bytes)
	elif CardData.has_webp_signature(bytes):
		err = image.load_webp_from_buffer(bytes)
	if err != OK:
		return null
	return image


func _record_card_failure(job_id: String, uid: String, reason: String) -> void:
	if uid != "":
		_status_by_uid[uid] = STATUS_FAILED
		_update_manifest_failure(uid, reason)
		image_failed.emit(uid, reason)
	_record_job_failure(job_id, uid, reason)


func _record_job_failure(job_id: String, uid: String, reason: String) -> void:
	if not _jobs.has(job_id):
		return
	var job: Dictionary = _jobs[job_id]
	var stats: Dictionary = job.get("stats", {})
	stats["failed"] = int(stats.get("failed", 0)) + 1
	stats["completed"] = int(stats.get("completed", 0)) + 1
	job["stats"] = stats
	var errors: PackedStringArray = job.get("errors", PackedStringArray())
	errors.append("%s %s" % [uid, reason])
	job["errors"] = errors
	_jobs[job_id] = job
	_emit_job_progress(job_id)


func _record_job_skip(job_id: String) -> void:
	if not _jobs.has(job_id):
		return
	var job: Dictionary = _jobs[job_id]
	var stats: Dictionary = job.get("stats", {})
	stats["skipped"] = int(stats.get("skipped", 0)) + 1
	stats["completed"] = int(stats.get("completed", 0)) + 1
	job["stats"] = stats
	_jobs[job_id] = job
	_emit_job_progress(job_id)


func _record_job_download(job_id: String) -> void:
	if not _jobs.has(job_id):
		return
	var job: Dictionary = _jobs[job_id]
	var stats: Dictionary = job.get("stats", {})
	stats["downloaded"] = int(stats.get("downloaded", 0)) + 1
	stats["completed"] = int(stats.get("completed", 0)) + 1
	job["stats"] = stats
	_jobs[job_id] = job
	_emit_job_progress(job_id)


func _record_job_cancelled(job_id: String) -> void:
	if not _jobs.has(job_id):
		return
	var job: Dictionary = _jobs[job_id]
	var stats: Dictionary = job.get("stats", {})
	stats["cancelled"] = int(stats.get("cancelled", 0)) + 1
	stats["completed"] = int(stats.get("completed", 0)) + 1
	job["stats"] = stats
	_jobs[job_id] = job
	_emit_job_progress(job_id)


func _finish_job_if_complete(job_id: String) -> void:
	if not _jobs.has(job_id):
		return
	var job: Dictionary = _jobs[job_id]
	var stats: Dictionary = job.get("stats", {})
	var total := int(stats.get("total", 0))
	var completed := int(stats.get("completed", 0))
	if completed < total:
		return
	if bool(job.get("emitted", false)):
		return
	job["emitted"] = true
	_jobs[job_id] = job
	var errors: PackedStringArray = job.get("errors", PackedStringArray())
	job_completed.emit(job_id, stats.duplicate(true), errors)


func _emit_job_progress(job_id: String) -> void:
	var job: Dictionary = _jobs.get(job_id, {})
	var stats: Dictionary = job.get("stats", {}) if job.get("stats", {}) is Dictionary else {}
	image_progress.emit(job_id, int(stats.get("completed", 0)), int(stats.get("total", 0)))


func _update_manifest_success(card: CardData, bytes: PackedByteArray) -> void:
	var entries: Dictionary = _manifest.get("entries", {}) if _manifest.get("entries", {}) is Dictionary else {}
	var now := int(Time.get_unix_time_from_system())
	var uid := card.get_uid()
	entries[uid] = {
		"set_code": card.set_code,
		"card_index": card.card_index,
		"local_path": card.image_local_path,
		"source_url": card.image_url,
		"bytes": bytes.size(),
		"sha256": _sha256_hex(bytes),
		"content_type": _content_type_for_bytes(bytes),
		"last_accessed_at": now,
		"downloaded_at": now,
		"fail_count": 0,
		"last_error": "",
	}
	_manifest["schema_version"] = 1
	_manifest["updated_at"] = now
	_manifest["entries"] = entries


func _update_manifest_failure(uid: String, reason: String) -> void:
	_load_manifest()
	var entries: Dictionary = _manifest.get("entries", {}) if _manifest.get("entries", {}) is Dictionary else {}
	var now := int(Time.get_unix_time_from_system())
	var parts := uid.split("_", false, 1)
	var set_code := parts[0] if parts.size() > 0 else ""
	var card_index := parts[1] if parts.size() > 1 else ""
	var entry: Dictionary = entries.get(uid, {}) if entries.get(uid, {}) is Dictionary else {}
	entry["set_code"] = str(entry.get("set_code", set_code))
	entry["card_index"] = str(entry.get("card_index", card_index))
	entry["local_path"] = str(entry.get("local_path", CardData.build_local_image_path(set_code, card_index)))
	entry["bytes"] = int(entry.get("bytes", 0))
	entry["last_accessed_at"] = now
	entry["fail_count"] = int(entry.get("fail_count", 0)) + 1
	entry["last_error"] = reason
	entries[uid] = entry
	_manifest["schema_version"] = 1
	_manifest["updated_at"] = now
	_manifest["entries"] = entries
	_save_manifest()


func _touch_manifest_entry(uid: String, resolved_path: String) -> void:
	_load_manifest()
	var entries: Dictionary = _manifest.get("entries", {}) if _manifest.get("entries", {}) is Dictionary else {}
	if entries.has(uid):
		var entry: Dictionary = entries[uid] if entries[uid] is Dictionary else {}
		entry["last_accessed_at"] = int(Time.get_unix_time_from_system())
		entry["local_path"] = resolved_path if resolved_path.begins_with("user://") else str(entry.get("local_path", resolved_path))
		entries[uid] = entry
		_manifest["entries"] = entries
		_save_manifest()


func _manifest_entry(uid: String) -> Dictionary:
	_load_manifest()
	var entries: Dictionary = _manifest.get("entries", {}) if _manifest.get("entries", {}) is Dictionary else {}
	var entry: Variant = entries.get(uid, {})
	if entry is Dictionary:
		return (entry as Dictionary).duplicate(true)
	return {}


func _load_manifest() -> void:
	if not _manifest.is_empty():
		return
	_manifest = {"schema_version": 1, "updated_at": 0, "entries": {}}
	if not FileAccess.file_exists(_manifest_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_manifest_path))
	if parsed is Dictionary:
		var dict := parsed as Dictionary
		if dict.get("entries", {}) is Dictionary:
			_manifest = dict.duplicate(true)


func _save_manifest() -> void:
	var dir := ProjectSettings.globalize_path(_manifest_path.get_base_dir())
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var tmp_path := "%s.tmp" % _manifest_path
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_manifest, "\t"))
	file.close()
	var absolute_final := ProjectSettings.globalize_path(_manifest_path)
	if FileAccess.file_exists(_manifest_path) or FileAccess.file_exists(absolute_final):
		DirAccess.remove_absolute(absolute_final)
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp_path), absolute_final)


func _resolve_card(set_code: String, card_index: String, card_database_override: Variant) -> CardData:
	if card_database_override != null and card_database_override is Object and (card_database_override as Object).has_method("get_card"):
		var card_variant: Variant = (card_database_override as Object).call("get_card", set_code, card_index)
		if card_variant is CardData:
			return card_variant as CardData
	if _card_database != null and _card_database.has_method("get_card"):
		var from_injected: Variant = _card_database.call("get_card", set_code, card_index)
		if from_injected is CardData:
			return from_injected as CardData
	var runtime_database := _runtime_card_database()
	if runtime_database != null and runtime_database.has_method("get_card"):
		var from_runtime: Variant = runtime_database.call("get_card", set_code, card_index)
		if from_runtime is CardData:
			return from_runtime as CardData
	return null


func _runtime_card_database() -> Node:
	if not is_inside_tree() or get_tree() == null or get_tree().root == null:
		return null
	return get_tree().root.get_node_or_null("CardDatabase")


func _protected_uids(options: Dictionary) -> Dictionary:
	var protected := {}
	var raw_protected: Variant = options.get("protected_uids", PackedStringArray())
	if raw_protected is PackedStringArray:
		for uid: String in raw_protected:
			protected[uid] = true
	elif raw_protected is Array:
		for uid_variant: Variant in raw_protected:
			protected[str(uid_variant)] = true
	if _card_database != null and _card_database.has_method("get_all_decks"):
		var decks: Array = _card_database.call("get_all_decks")
		for deck_raw: Variant in decks:
			if deck_raw is DeckData:
				for key: Dictionary in (deck_raw as DeckData).get_card_keys():
					protected[_uid(str(key.get("set_code", "")), str(key.get("card_index", "")))] = true
	return protected


func _sha256_hex(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


func _content_type_for_bytes(bytes: PackedByteArray) -> String:
	if CardData.has_png_signature(bytes):
		return "image/png"
	if CardData.has_jpg_signature(bytes):
		return "image/jpeg"
	if CardData.has_webp_signature(bytes):
		return "image/webp"
	return "application/octet-stream"


func _uid(set_code: String, card_index: String) -> String:
	return "%s_%s" % [set_code.strip_edges(), card_index.strip_edges()]
