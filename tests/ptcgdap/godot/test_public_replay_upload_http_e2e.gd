class_name TestPublicReplayUploadHttpE2E
extends TestBase

const ContractScript = preload("res://scripts/ai/ptcgdap/platform/CompetitiveStrategyContracts.gd")
const PresentationScript = preload("res://scripts/ai/ptcgdap/platform/replay/PublicReplayPresentation.gd")
const RemoteReaderScript = preload("res://scripts/ai/ptcgdap/platform/replay/PublicReplayRemoteReader.gd")
const UploadClientScript = preload("res://scripts/ai/ptcgdap/platform/replay/PublicReplayUploadClient.gd")
const MAX_ARTIFACT_BYTES := 16 * 1024 * 1024


func test_live_python_service_round_trip() -> String:
	var arguments := _arguments()
	var endpoint := str(arguments.get("replay-e2e-endpoint", ""))
	var token := str(arguments.get("replay-e2e-token", ""))
	var artifact_path := str(arguments.get("replay-e2e-artifact", ""))
	if endpoint.is_empty() and token.is_empty() and artifact_path.is_empty():
		return ""
	if endpoint.is_empty() or token.is_empty() or artifact_path.is_empty():
		return "missing replay E2E endpoint, token, or artifact argument"
	var artifact_result := _read_artifact(artifact_path)
	if not bool(artifact_result.get("accepted", false)):
		return "artifact read failed: %s" % artifact_result
	var artifact: Dictionary = artifact_result.artifact
	var contracts: Dictionary = ContractScript.load_default()
	if not bool(contracts.get("accepted", false)):
		return "contract load failed: %s" % contracts
	var owner: Variant = contracts.owner
	var replay_validation: Dictionary = owner.validate_replay(artifact.manifest, artifact.frames)
	if not bool(replay_validation.get("accepted", false)):
		return "input replay invalid: %s" % replay_validation
	var client_result: Dictionary = UploadClientScript.create(owner, null, endpoint, token, true)
	if not bool(client_result.get("accepted", false)):
		return "client creation failed: %s" % client_result
	var client: Node = client_result.client
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(client)
	await tree.process_frame
	var upload_results: Array[Dictionary] = []
	client.upload_completed.connect(func(result: Dictionary) -> void:
		upload_results.append(result.duplicate(true))
	)
	var started: Dictionary = client.upload(artifact)
	if not bool(started.get("accepted", false)):
		tree.root.remove_child(client)
		client.free()
		return "upload start failed: %s" % started
	var deadline := Time.get_ticks_msec() + 35_000
	while upload_results.is_empty() and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	if upload_results.is_empty():
		tree.root.remove_child(client)
		client.free()
		return "upload timed out"
	var upload_result: Dictionary = upload_results[0]
	var upload_audit: Dictionary = client.audit_snapshot()
	tree.root.remove_child(client)
	client.free()
	if not bool(upload_result.get("accepted", false)):
		return "upload rejected: %s" % upload_result

	var reader_result: Dictionary = RemoteReaderScript.create(owner, null, endpoint, true)
	if not bool(reader_result.get("accepted", false)):
		return "reader creation failed: %s" % reader_result
	var reader: Node = reader_result.reader
	tree.root.add_child(reader)
	await tree.process_frame
	var read_results: Array[Dictionary] = []
	reader.read_completed.connect(func(result: Dictionary) -> void:
		read_results.append(result.duplicate(true))
	)
	var list_started: Dictionary = reader.list(10)
	if not bool(list_started.get("accepted", false)):
		tree.root.remove_child(reader)
		reader.free()
		return "list start failed: %s" % list_started
	deadline = Time.get_ticks_msec() + 35_000
	while read_results.is_empty() and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	if read_results.is_empty():
		tree.root.remove_child(reader)
		reader.free()
		return "list timed out"
	var list_result: Dictionary = read_results.pop_front()
	if not bool(list_result.get("accepted", false)):
		tree.root.remove_child(reader)
		reader.free()
		return "list rejected: %s" % list_result
	var read_started: Dictionary = reader.fetch(artifact.manifest.replay_id)
	if not bool(read_started.get("accepted", false)):
		tree.root.remove_child(reader)
		reader.free()
		return "GET start failed: %s" % read_started
	deadline = Time.get_ticks_msec() + 35_000
	while read_results.is_empty() and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	if read_results.is_empty():
		tree.root.remove_child(reader)
		reader.free()
		return "GET timed out"
	var read_result: Dictionary = read_results[0]
	var reader_audit: Dictionary = reader.audit_snapshot()
	tree.root.remove_child(reader)
	reader.free()
	if not bool(read_result.get("accepted", false)):
		return "GET rejected: %s" % read_result
	var downloaded: Dictionary = read_result.artifact
	var downloaded_envelope: Dictionary = owner.validate_document(downloaded.get("match_envelope"))
	var downloaded_replay: Dictionary = owner.validate_replay(
		downloaded.get("manifest"), downloaded.get("frames")
	)
	var opened: Dictionary = PresentationScript.create(
		owner, downloaded.get("manifest"), downloaded.get("frames")
	)
	var presentation_audit: Dictionary = {}
	if bool(opened.get("accepted", false)):
		presentation_audit = opened.presentation.audit_snapshot()
	return run_checks([
		assert_true(bool(downloaded_envelope.get("accepted", false))),
		assert_true(bool(downloaded_replay.get("accepted", false))),
		assert_true(bool(opened.get("accepted", false))),
		assert_eq(list_result.get("items", []).size(), 1),
		assert_eq(list_result.get("items", [])[0].get("replay_id"), artifact.manifest.replay_id),
		assert_eq(list_result.get("items", [])[0].get("artifact_sha256"), upload_result.get("artifact_sha256")),
		assert_eq(downloaded.manifest.replay_id, artifact.manifest.replay_id),
		assert_eq(downloaded.manifest.frame_chain_root_sha256, artifact.manifest.frame_chain_root_sha256),
		assert_eq(downloaded.frames.size(), artifact.frames.size()),
		assert_false(bool(upload_audit.get("authoritative", true))),
		assert_eq(upload_audit.get("engine_invocations"), 0),
		assert_eq(upload_audit.get("ticket_invocations"), 0),
		assert_false(bool(reader_audit.get("authoritative", true))),
		assert_eq(reader_audit.get("engine_invocations"), 0),
		assert_eq(reader_audit.get("ticket_invocations"), 0),
		assert_eq(reader_audit.get("artifact_sha256"), upload_result.get("artifact_sha256")),
		assert_eq(presentation_audit.get("engine_invocations"), 0),
		assert_eq(presentation_audit.get("ticket_invocations"), 0),
	])


static func _read_artifact(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"accepted": false, "error_code": "artifact_open_failed"}
	var length := file.get_length()
	if length < 1 or length > MAX_ARTIFACT_BYTES:
		file.close()
		return {"accepted": false, "error_code": "artifact_size_invalid"}
	var source := file.get_buffer(length)
	file.close()
	var json := JSON.new()
	if json.parse(source.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return {"accepted": false, "error_code": "artifact_json_invalid"}
	return {
		"accepted": true,
		"error_code": "",
		"artifact": _coerce_integral_numbers(json.data),
	}


static func _coerce_integral_numbers(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value):
		return int(value)
	if value is Array:
		var array_result: Array = []
		for child: Variant in value:
			array_result.append(_coerce_integral_numbers(child))
		return array_result
	if value is Dictionary:
		var dictionary_result := {}
		for key: Variant in value:
			dictionary_result[key] = _coerce_integral_numbers(value[key])
		return dictionary_result
	return value


static func _arguments() -> Dictionary:
	var result := {}
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--"):
			continue
		var separator := argument.find("=")
		if separator <= 2:
			continue
		result[argument.substr(2, separator - 2)] = argument.substr(separator + 1)
	return result
