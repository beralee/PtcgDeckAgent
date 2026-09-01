class_name A3CheckpointComparator
extends RefCounted


static func compare(
	left: Dictionary,
	right: Dictionary,
	phase: String = "before_action",
	entity_relation: Dictionary = {}
) -> Dictionary:
	var left_frontier := _semantic_frontier("left", left.get("ordered_options", []), entity_relation)
	var right_frontier := _semantic_frontier("right", right.get("ordered_options", []), entity_relation)
	if not bool(left_frontier.get("ok", false)) or not bool(right_frontier.get("ok", false)):
		return _difference("entity_lineage_diff", phase, "/ordered_options/entity_relation")
	var pairs: Array = [
		[_terminal_classification(str(left.get("kind", "")), str(right.get("kind", ""))), "/kind", left.get("kind"), right.get("kind")],
		["lifecycle_diff", "/acting_seat", left.get("acting_seat"), right.get("acting_seat")],
		["contract_shape_diff", "/select", _select_descriptor(left.get("select")), _select_descriptor(right.get("select"))],
		["option_generation_diff", "/ordered_options/count", (left.get("ordered_options", []) as Array).size(), (right.get("ordered_options", []) as Array).size()],
		["option_order_diff", "/semantic_option_fingerprints", left_frontier.get("options"), right_frontier.get("options")],
		["random_schedule_diff", "/random_event_cursor", left.get("random_event_cursor"), right.get("random_event_cursor")],
		["contract_shape_diff", "/diagnostic_capability_mask", left.get("diagnostic_capability_mask", []), right.get("diagnostic_capability_mask", [])],
		["log_diff", "/incremental_logs", left.get("incremental_logs", []), right.get("incremental_logs", [])],
		["public_snapshot_diff", "/public_snapshot", left.get("public_snapshot", {}), right.get("public_snapshot", {})],
	]
	for pair: Array in pairs:
		if pair[2] == pair[3]:
			continue
		var classification := str(pair[0])
		if classification == "public_snapshot_diff":
			classification = "damage_diff" if _contains_damage(pair[2]) or _contains_damage(pair[3]) else "contract_shape_diff"
		return _difference(classification, phase, str(pair[1]))
	return {"aligned": true, "classification": null, "path": null, "phase": phase}


static func _semantic_frontier(side: String, raw_options: Variant, relation: Dictionary) -> Dictionary:
	if not raw_options is Array:
		return {"ok": false, "options": []}
	var serial_map: Dictionary = relation.get("%s_serial_to_entity" % side, {})
	var result: Array = []
	for raw_option: Variant in raw_options:
		if not raw_option is Dictionary:
			return {"ok": false, "options": []}
		var option: Dictionary = raw_option.duplicate(true)
		if option.has("serial"):
			var serial_key := str(option.get("serial"))
			if not serial_map.has(serial_key):
				return {"ok": false, "options": []}
			option["serial"] = str(serial_map[serial_key])
		result.append(option)
	return {"ok": true, "options": result}


static func _select_descriptor(raw_select: Variant) -> Variant:
	if raw_select == null:
		return null
	if not raw_select is Dictionary:
		return raw_select
	var value: Dictionary = raw_select.duplicate(true)
	value.erase("option")
	return value


static func _terminal_classification(left_kind: String, right_kind: String) -> String:
	return "terminal_diff" if left_kind == "TERMINAL" or right_kind == "TERMINAL" else "lifecycle_diff"


static func _contains_damage(value: Variant) -> bool:
	if value is Dictionary:
		for key: Variant in value.keys():
			if "damage" in str(key).to_lower() or _contains_damage(value[key]):
				return true
	elif value is Array:
		for item: Variant in value:
			if _contains_damage(item):
				return true
	return false


static func _difference(classification: String, phase: String, path: String) -> Dictionary:
	return {
		"aligned": false,
		"classification": classification,
		"path": path,
		"phase": phase,
	}
