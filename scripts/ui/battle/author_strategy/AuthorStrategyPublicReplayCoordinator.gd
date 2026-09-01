class_name AuthorStrategyPublicReplayCoordinator
extends Node

const ContractScript = preload(
	"res://scripts/ai/ptcgdap/platform/CompetitiveStrategyContracts.gd"
)
const EnvelopeScript = preload(
	"res://scripts/ai/ptcgdap/platform/replay/PublicReplayLiveEnvelope.gd"
)
const CaptureScript = preload(
	"res://scripts/ai/ptcgdap/platform/replay/PublicReplayCapture.gd"
)
const StoreScript = preload(
	"res://scripts/ai/ptcgdap/platform/replay/PublicReplayStore.gd"
)
const UploadClientScript = preload(
	"res://scripts/ai/ptcgdap/platform/replay/PublicReplayUploadClient.gd"
)

const DEFAULT_STORAGE_NAMESPACE := "live-community"
const DEFAULT_BASE_URL := "http://127.0.0.1:8765"

signal replay_status_changed(audit: Dictionary)

var _contract_owner: Variant = null
var _capture: Variant = null
var _store: Variant = null
var _upload_client: Node = null
var _completed_artifact: Dictionary = {}
var _match_id := ""
var _replay_id := ""
var _base_url := DEFAULT_BASE_URL
var _bearer_token := ""
var _allow_insecure_loopback := false
var _transport: Variant = null
var _started := false
var _finished := false
var _local_saved := false
var _artifact_path := ""
var _upload_status := "not_configured"
var _upload_result: Dictionary = {}
var _last_error_code := ""
var _progress_frame_count := 0


func start(author_owner: Variant, options: Dictionary = {}) -> Dictionary:
	if _started or author_owner == null:
		return _failure("live_replay_owner_invalid")
	for method_name: String in ["public_replay_identity", "public_replay_source_snapshot"]:
		if not author_owner.has_method(method_name):
			return _failure("live_replay_owner_invalid")
	var loaded: Dictionary = ContractScript.load_default()
	if not bool(loaded.get("accepted", false)):
		return _remember_failure(str(loaded.get("error_code", "contract_bundle_invalid")))
	_contract_owner = loaded.get("owner")
	var identity: Variant = author_owner.call("public_replay_identity")
	if not identity is Dictionary or not bool(identity.get("ok", false)):
		return _remember_failure("public_identity_invalid")
	_match_id = str(identity.get("match_id", ""))
	_replay_id = _build_replay_id(_match_id)
	var envelope_result: Dictionary = EnvelopeScript.build(
		_contract_owner,
		identity,
		_match_id,
		int(options.get("opponent_deck_id", -1)),
		int(options.get("strategy_seat", 1))
	)
	if not bool(envelope_result.get("accepted", false)):
		return _remember_failure(str(envelope_result.get("error_code", "live_replay_envelope_invalid")))
	var capture_result: Dictionary = CaptureScript.create(
		_contract_owner,
		envelope_result.get("envelope"),
		_replay_id,
		str(envelope_result.get("card_asset_catalog_sha256", "")),
		str(envelope_result.get("event_dictionary_sha256", ""))
	)
	if not bool(capture_result.get("accepted", false)):
		return _remember_failure(str(capture_result.get("error_code", "live_replay_capture_invalid")))
	var storage_namespace := str(options.get("storage_namespace", DEFAULT_STORAGE_NAMESPACE))
	var store_result: Dictionary = StoreScript.create(
		_contract_owner, storage_namespace, "community_challenge"
	)
	if not bool(store_result.get("accepted", false)):
		return _remember_failure(str(store_result.get("error_code", "storage_unavailable")))
	_capture = capture_result.get("capture")
	_store = store_result.get("store")
	_base_url = str(options.get("base_url", DEFAULT_BASE_URL)).strip_edges()
	_bearer_token = str(options.get("bearer_token", ""))
	_allow_insecure_loopback = bool(options.get("allow_insecure_loopback", false))
	_transport = options.get("transport")
	var source_result := _public_source(author_owner)
	if not bool(source_result.get("accepted", false)):
		_capture = null
		_store = null
		return source_result
	var appended: Dictionary = _capture.append_public_source(
		source_result.get("source"), "match_started"
	)
	if not bool(appended.get("accepted", false)):
		_capture = null
		_store = null
		return _remember_failure(str(appended.get("error_code", "live_replay_start_failed")))
	_started = true
	_last_error_code = ""
	_upload_status = "pending" if not _bearer_token.is_empty() else "not_configured"
	_emit_status()
	return {
		"accepted": true,
		"error_code": "",
		"match_id": _match_id,
		"replay_id": _replay_id,
		"lane": "community_challenge",
		"authoritative": false,
		"grants": [],
	}


func record_progress(author_owner: Variant) -> Dictionary:
	if not _started or _finished or _capture == null:
		return _failure("live_replay_not_open")
	var source_result := _public_source(author_owner)
	if not bool(source_result.get("accepted", false)):
		return source_result
	var source: Dictionary = source_result.get("source", {})
	if source.get("phase") == "terminal":
		return {
			"accepted": true,
			"error_code": "",
			"skipped": true,
			"reason": "terminal_pending_finish",
			"authoritative": false,
			"grants": [],
		}
	var appended: Dictionary = _capture.append_public_source(source, "state_progressed")
	if bool(appended.get("accepted", false)):
		_progress_frame_count += 1
	else:
		_last_error_code = str(appended.get("error_code", "live_replay_progress_failed"))
	_emit_status()
	return appended


func finish(author_owner: Variant) -> Dictionary:
	if not _started or _finished or _capture == null or _store == null:
		return _failure("live_replay_not_open")
	var source_result := _public_source(author_owner)
	if not bool(source_result.get("accepted", false)):
		return source_result
	var source: Dictionary = source_result.get("source", {})
	if source.get("phase") != "terminal":
		return _remember_failure("replay_event_sequence_invalid")
	var completed: Dictionary = _capture.finish(source)
	if not bool(completed.get("accepted", false)):
		return _remember_failure(str(completed.get("error_code", "live_replay_finish_failed")))
	_completed_artifact = (completed.get("artifact") as Dictionary).duplicate(true)
	var saved: Dictionary = _store.save_completed(_completed_artifact)
	if not bool(saved.get("accepted", false)):
		_completed_artifact.clear()
		return _remember_failure(str(saved.get("error_code", "live_replay_save_failed")))
	_finished = true
	_local_saved = true
	_artifact_path = str(saved.get("artifact_path", ""))
	_last_error_code = ""
	var upload_start := _start_upload()
	_emit_status()
	return {
		"accepted": true,
		"error_code": "",
		"replay_id": _replay_id,
		"artifact_path": _artifact_path,
		"upload_started": bool(upload_start.get("started", false)) or bool(upload_start.get("scheduled", false)),
		"upload_status": _upload_status,
		"upload_error_code": str(upload_start.get("error_code", "")),
		"authoritative": false,
		"grants": [],
	}


func close_incomplete(reason: String = "scene_closed") -> void:
	if _started and not _finished:
		_last_error_code = reason.left(80)
		_upload_status = "not_attempted"
		_emit_status()
	_capture = null
	_store = null


func completed_artifact() -> Dictionary:
	return _completed_artifact.duplicate(true)


func audit_snapshot() -> Dictionary:
	return {
		"document_type": "author_strategy_public_replay_audit_v1",
		"schema_version": 1,
		"match_id": _match_id,
		"replay_id": _replay_id,
		"started": _started,
		"complete": _finished,
		"local_saved": _local_saved,
		"artifact_path": _artifact_path,
		"progress_frame_count": _progress_frame_count,
		"upload_status": _upload_status,
		"upload_attempt_count": int(
			_upload_client.audit_snapshot().get("attempt_count", 0)
			if _upload_client != null else 0
		),
		"upload_result": _upload_result.duplicate(true),
		"last_error_code": _last_error_code,
		"private_replay_used": false,
		"authoritative": false,
		"engine_invocations": 0,
		"ticket_invocations": 0,
		"callback_invocations": 0,
		"grants": [],
	}


func _start_upload() -> Dictionary:
	if _bearer_token.is_empty():
		_upload_status = "not_configured"
		return _failure("upload_token_unavailable")
	var created: Dictionary = UploadClientScript.create(
		_contract_owner,
		_transport,
		_base_url,
		_bearer_token,
		_allow_insecure_loopback
	)
	if not bool(created.get("accepted", false)):
		_upload_status = "configuration_error"
		_upload_result = created.duplicate(true)
		return created
	_upload_client = created.get("client")
	add_child(_upload_client)
	_upload_client.upload_completed.connect(_on_upload_completed)
	_upload_status = "scheduled"
	call_deferred("_begin_upload_request")
	return {
		"accepted": true,
		"error_code": "",
		"scheduled": true,
		"replay_id": _replay_id,
		"authoritative": false,
		"grants": [],
	}


func _begin_upload_request() -> void:
	if _upload_client == null or not is_instance_valid(_upload_client):
		_upload_status = "failed"
		_last_error_code = "upload_client_unavailable"
		_emit_status()
		return
	var started: Dictionary = _upload_client.upload(_completed_artifact)
	if not bool(started.get("accepted", false)):
		_upload_status = "failed"
		_upload_result = started.duplicate(true)
		_last_error_code = str(started.get("error_code", "upload_start_failed"))
		_emit_status()
		return
	_upload_status = "uploading"
	_emit_status()


func _on_upload_completed(result: Dictionary) -> void:
	_upload_result = result.duplicate(true)
	_upload_status = "uploaded" if bool(result.get("accepted", false)) else "failed"
	if not bool(result.get("accepted", false)):
		_last_error_code = str(result.get("error_code", "upload_failed"))
	_emit_status()


func _public_source(author_owner: Variant) -> Dictionary:
	if author_owner == null or not author_owner.has_method("public_replay_source_snapshot"):
		return _remember_failure("live_replay_owner_invalid")
	var result: Variant = author_owner.call("public_replay_source_snapshot")
	if not result is Dictionary or not bool(result.get("ok", false)):
		return _remember_failure(
			str(result.get("error_code", "public_replay_source_unavailable"))
			if result is Dictionary else "public_replay_source_unavailable"
		)
	var source: Variant = result.get("source")
	if not source is Dictionary:
		return _remember_failure("public_source_invalid")
	return {"accepted": true, "error_code": "", "source": source}


func _emit_status() -> void:
	replay_status_changed.emit(audit_snapshot())


func _remember_failure(code: String) -> Dictionary:
	_last_error_code = code
	_emit_status()
	return _failure(code)


static func _build_replay_id(match_id: String) -> String:
	var candidate := "community-%s" % match_id
	if candidate.length() <= 96:
		return candidate
	return "community-%s" % match_id.sha256_text().to_upper()


static func _failure(code: String) -> Dictionary:
	return {"accepted": false, "error_code": code, "authoritative": false, "grants": []}
