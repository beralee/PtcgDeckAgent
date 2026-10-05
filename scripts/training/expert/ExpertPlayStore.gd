extends RefCounted

const ROOT := "user://expert_play/v1"
const FORMAT := "ptcg_expert_play_envelope_v1"


static func new_attempt_id() -> String:
	return "attempt-" + Crypto.new().generate_random_bytes(12).hex_encode()


static func _valid_id(id: String) -> bool:
	if id.is_empty() or id.length() > 80:
		return false
	for character: String in id:
		if not character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-":
			return false
	return true


static func _read(path: String, fallback: Dictionary = {}) -> Dictionary:
	if not FileAccess.file_exists(path) or FileAccess.get_size(path) > 8 * 1024 * 1024:
		return fallback.duplicate(true)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (data as Dictionary).duplicate(true) if data is Dictionary else fallback.duplicate(true)


static func _write(path: String, data: Dictionary) -> bool:
	var directory := ProjectSettings.globalize_path(path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return false
	var encoded := JSON.stringify(data)
	if encoded.to_utf8_buffer().size() > 8 * 1024 * 1024:
		return false
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(encoded)
	file.flush()
	var valid := file.get_error() == OK
	file.close()
	if not valid:
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) == OK


static func save(document: Dictionary) -> bool:
	var id := str(document.get("attempt_id", ""))
	if not _valid_id(id) or str(document.get("document_type", "")) != "ptcg_expert_play_demo_v1":
		return false
	var payload := JSON.stringify(document)
	var envelope := {"format": FORMAT, "payload_json": payload, "payload_sha256": payload.sha256_text()}
	if not _write(ROOT + "/attempts/" + id + ".json", envelope):
		return false
	var index := _read(ROOT + "/index.json", {"attempts": {}})
	index.attempts[id] = {
		"scenario_id": str(document.scenario_id), "family_id": str(document.family_id),
		"revision": int(document.scenario_revision), "status": str(document.status),
		"confidence": str(document.feedback.get("confidence", "")),
		"updated_at": int(Time.get_unix_time_from_system()),
	}
	return _write(ROOT + "/index.json", index)


static func progress() -> Dictionary:
	var output: Dictionary = {}
	for attempt: Dictionary in _read(ROOT + "/index.json", {"attempts": {}}).get("attempts", {}).values():
		var id := str(attempt.get("scenario_id", ""))
		var item: Dictionary = output.get(id, {"attempts": 0, "submitted": 0, "confidence": "", "updated_at": 0})
		item.attempts += 1
		if str(attempt.get("status", "")) == "submitted":
			item.submitted += 1
		if int(attempt.get("updated_at", 0)) >= int(item.updated_at):
			item.updated_at = int(attempt.get("updated_at", 0))
			item.confidence = str(attempt.get("confidence", ""))
		output[id] = item
	return output


static func pending_feedback() -> Array[Dictionary]:
	var pending: Array[Dictionary] = []
	var index := _read(ROOT + "/index.json", {"attempts": {}})
	for id: String in index.get("attempts", {}):
		if not _valid_id(id) or str(index.attempts[id].get("status", "")) != "draft":
			continue
		var envelope := _read(ROOT + "/attempts/" + id + ".json")
		var payload := str(envelope.get("payload_json", ""))
		if str(envelope.get("format", "")) != FORMAT or payload.sha256_text() != str(envelope.get("payload_sha256", "")):
			continue
		var document: Variant = JSON.parse_string(payload)
		if document is Dictionary and str(document.get("attempt_id", "")) == id and str(document.get("status", "")) == "draft" and not (document.get("final_public_state", {}) as Dictionary).is_empty():
			pending.append(document)
	pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.created_at) > int(b.created_at))
	return pending


static func choose_queue(scenarios: Array, previous: Dictionary, count: int = 5, topic: String = "") -> Array[String]:
	var candidates: Array = []
	for scenario: Dictionary in scenarios:
		if topic == "" or str(scenario.topic) == topic:
			candidates.append(scenario)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: Dictionary = previous.get(str(a.id), {})
		var pb: Dictionary = previous.get(str(b.id), {})
		var ca := int(pa.get("submitted", 0))
		var cb := int(pb.get("submitted", 0))
		if ca != cb:
			return ca < cb
		var ua := 0 if str(pa.get("confidence", "")) in ["discuss", "mistake"] else 1
		var ub := 0 if str(pb.get("confidence", "")) in ["discuss", "mistake"] else 1
		if ua != ub:
			return ua < ub
		return int(a.order) < int(b.order)
	)
	var result: Array[String] = []
	var families: Dictionary = {}
	for pass_index: int in 2:
		for scenario: Dictionary in candidates:
			if result.size() >= count:
				return result
			if str(scenario.id) in result or (pass_index == 0 and families.has(str(scenario.family_id))):
				continue
			result.append(str(scenario.id))
			families[str(scenario.family_id)] = true
	return result


static func set_queue(ids: Array) -> bool:
	return _write(ROOT + "/session.json", {"remaining": ids, "total": ids.size()})


static func queue_state() -> Dictionary:
	return _read(ROOT + "/session.json", {"remaining": [], "total": 0})


static func advance(id: String) -> bool:
	var session := queue_state()
	(session.remaining as Array).erase(id)
	return _write(ROOT + "/session.json", session)


static func export_public() -> Dictionary:
	var index := _read(ROOT + "/index.json", {"attempts": {}})
	var path := ROOT + "/exports/expert-" + new_attempt_id() + ".jsonl"
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir())) != OK:
		return {"ok": false, "error": "expert_export_write_failed"}
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "expert_export_write_failed"}
	file.store_line(JSON.stringify({"format": "ptcg_expert_play_export_v1"}))
	var count := 0
	for id: String in index.get("attempts", {}):
		if str(index.attempts[id].status) != "submitted" or not _valid_id(id):
			continue
		var envelope := _read(ROOT + "/attempts/" + id + ".json")
		var payload := str(envelope.get("payload_json", ""))
		if str(envelope.get("format", "")) != FORMAT or payload.sha256_text() != str(envelope.get("payload_sha256", "")):
			file.close()
			return {"ok": false, "error": "expert_export_integrity_failed"}
		file.store_line(JSON.stringify(envelope))
		count += 1
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	if ok:
		ok = DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) == OK
	return {"ok": ok, "path": ProjectSettings.globalize_path(path) if ok else "", "count": count}
