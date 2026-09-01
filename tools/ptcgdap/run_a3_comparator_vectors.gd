extends SceneTree

const ComparatorScript = preload("res://scripts/ai/ptcgdap/host/godot/A3CheckpointComparator.gd")
const VECTORS_PATH := "res://contracts/ptcgdap/a3_comparator_conformance_v2.json"


func _initialize() -> void:
	var output_path := _argument("output")
	if output_path.is_empty():
		printerr("a3_comparator_output_required")
		quit(2)
		return
	var file := FileAccess.open(VECTORS_PATH, FileAccess.READ)
	if file == null:
		printerr("a3_comparator_vectors_unavailable")
		quit(2)
		return
	var raw := file.get_buffer(file.get_length())
	file.close()
	var vectors: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not vectors is Dictionary:
		printerr("a3_comparator_vectors_invalid")
		quit(2)
		return
	var results: Array = []
	for case_value: Variant in vectors.get("cases", []):
		var case: Dictionary = case_value
		var left := _checkpoint(vectors.get("base", {}), false)
		var right := _checkpoint(vectors.get("base", {}), true)
		_mutate(right, str(case.get("mutation", "")))
		var compared: Dictionary = ComparatorScript.compare(
			left, right, "before_action", vectors.get("entity_relation", {})
		)
		var item := {
			"case_id": case.get("case_id"),
			"classification": compared.get("classification"),
			"path": compared.get("path"),
		}
		if item.get("classification") != case.get("classification") or item.get("path") != case.get("path"):
			printerr("a3_godot_comparator_conformance_failed:%s" % case.get("case_id"))
			quit(1)
			return
		results.append(item)
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(raw)
	var report := {
		"accepted": true,
		"document_type": "ptcgdap_a3_godot_comparator_result_v2",
		"vectors_raw_sha256": context.finish().hex_encode().to_upper(),
		"results": results,
	}
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output == null:
		printerr("a3_comparator_output_unavailable")
		quit(2)
		return
	output.store_string(JSON.stringify(report))
	output.close()
	quit(0)


func _checkpoint(base: Dictionary, right_domain: bool) -> Dictionary:
	var serial := 9001 if right_domain else int(base.get("serial", 101))
	var options: Array = []
	var option_order: Array = base.get("option_order", [])
	for index: int in option_order.size():
		options.append({"type": option_order[index], "index": index, "cardId": 646, "serial": serial})
	return {
		"kind": base.get("kind"),
		"acting_seat": base.get("acting_seat"),
		"select": {
			"type": base.get("select_type"), "context": base.get("select_context"),
			"minCount": 1, "maxCount": 1, "option": options.duplicate(true),
		},
		"ordered_options": options,
		"incremental_logs": (base.get("incremental_logs", []) as Array).duplicate(true),
		"public_snapshot": {"damage": base.get("damage"), "terminal": false},
		"random_event_cursor": base.get("random_event_cursor"),
		"diagnostic_capability_mask": [],
	}


func _mutate(checkpoint: Dictionary, mutation: String) -> void:
	match mutation:
		"none": pass
		"option_reorder":
			checkpoint["ordered_options"].reverse()
			checkpoint["select"]["option"] = checkpoint["ordered_options"].duplicate(true)
		"damage": checkpoint["public_snapshot"]["damage"] = 10
		"log": checkpoint["incremental_logs"] = [{"type": 7}]
		"serial":
			checkpoint["ordered_options"][0]["serial"] = 9002
			checkpoint["select"]["option"] = checkpoint["ordered_options"].duplicate(true)
		"rng": checkpoint["random_event_cursor"] = 1
		"terminal":
			checkpoint["kind"] = "TERMINAL"
			checkpoint["acting_seat"] = null
			checkpoint["select"] = null
			checkpoint["ordered_options"] = []
			checkpoint["public_snapshot"]["terminal"] = true


func _argument(name: String) -> String:
	var prefix := "--%s=" % name
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix):
			return value.trim_prefix(prefix)
	return ""
