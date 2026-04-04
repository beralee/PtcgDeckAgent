class_name TestSuiteFilter
extends RefCounted


static func parse_suite_filter(args: PackedStringArray) -> Dictionary:
	return _parse_filter_values(args, "--suite=", normalize_suite_name)


static func parse_group_filter(args: PackedStringArray) -> Dictionary:
	return _parse_filter_values(args, "--group=", normalize_group_name)


static func should_run_suite(selected: Dictionary, suite_name: String) -> bool:
	if selected.is_empty():
		return true
	return bool(selected.get(normalize_suite_name(suite_name), false))


static func should_run_any_group(selected: Dictionary, suite_groups: Array) -> bool:
	if selected.is_empty():
		return true
	for group_name in suite_groups:
		if should_run_group(selected, str(group_name)):
			return true
	return false


static func should_run_group(selected: Dictionary, group_name: String) -> bool:
	if selected.is_empty():
		return true
	return bool(selected.get(normalize_group_name(group_name), false))


static func normalize_suite_name(suite_name: String) -> String:
	return suite_name.strip_edges().to_lower()


static func normalize_group_name(group_name: String) -> String:
	return group_name.strip_edges().to_lower()


static func _parse_filter_values(args: PackedStringArray, prefix: String, normalizer: Callable) -> Dictionary:
	var selected: Dictionary = {}
	for raw_arg: String in args:
		if not raw_arg.begins_with(prefix):
			continue
		var raw_value := raw_arg.split("=", false, 1)[1]
		for item_name: String in raw_value.split(",", false):
			var normalized := str(normalizer.call(item_name))
			if normalized == "":
				continue
			selected[normalized] = true
	return selected
