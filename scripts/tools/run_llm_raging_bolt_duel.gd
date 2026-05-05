extends SceneTree

const DuelToolScript = preload("res://scripts/ai/LLMRagingBoltDuelTool.gd")

const DEFAULT_MODE := "miraidon"
const DEFAULT_GAMES := 1
const DEFAULT_JSON_OUTPUT := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	var mode := str(args.get("mode", DEFAULT_MODE)).strip_edges().to_lower()
	var games: int = maxi(int(args.get("games", DEFAULT_GAMES)), 1)
	var tool: Node = DuelToolScript.new()
	root.add_child(tool)
	var options := {}
	if args.has("seed"):
		options["seed"] = int(args.get("seed"))
	if args.has("max-steps"):
		options["max_steps"] = int(args.get("max-steps"))
	if args.has("max-game-seconds"):
		options["max_game_seconds"] = float(args.get("max-game-seconds"))
	if args.has("first-player"):
		options["first_player_index"] = int(args.get("first-player"))
	if args.has("llm-timeout"):
		options["llm_wait_timeout_seconds"] = float(args.get("llm-timeout"))
	if args.has("output-root"):
		options["output_root"] = str(args.get("output-root"))
	if args.has("llm-wait-timeout-seconds"):
		options["llm_wait_timeout_seconds"] = float(args.get("llm-wait-timeout-seconds"))
	if args.has("llm-wait-poll-seconds"):
		options["llm_wait_poll_seconds"] = float(args.get("llm-wait-poll-seconds"))
	if args.has("llm-max-failures"):
		options["llm_max_failures_per_strategy"] = int(args.get("llm-max-failures"))
	if args.has("strong-fixed-opening"):
		options["strong_fixed_opening"] = _parse_bool(str(args.get("strong-fixed-opening")))
	if args.has("rule-strong-fixed-opening"):
		options["rule_strong_fixed_opening"] = _parse_bool(str(args.get("rule-strong-fixed-opening")))
	if args.has("llm-strong-fixed-opening"):
		options["llm_strong_fixed_opening"] = _parse_bool(str(args.get("llm-strong-fixed-opening")))
	if args.has("rule-deck-id"):
		options["rule_deck_id"] = int(args.get("rule-deck-id"))
	if args.has("llm-deck-id"):
		options["llm_deck_id"] = int(args.get("llm-deck-id"))
	if args.has("rule-strategy-id"):
		options["rule_strategy_id"] = str(args.get("rule-strategy-id"))
	if args.has("llm-strategy-id"):
		options["llm_strategy_id"] = str(args.get("llm-strategy-id"))

	var report: Dictionary
	match mode:
		"self_play", "self-play", "mirror":
			if options.has("llm_deck_id"):
				options["player_0_deck_id"] = int(options.get("llm_deck_id"))
				options["player_1_deck_id"] = int(options.get("llm_deck_id"))
			if options.has("llm_strategy_id"):
				options["player_0_strategy_id"] = str(options.get("llm_strategy_id"))
				options["player_1_strategy_id"] = str(options.get("llm_strategy_id"))
			report = await tool.call("run_llm_self_play", games, options)
			report["mode"] = "self_play"
		"miraidon", "rule_miraidon", "vs_miraidon", "rule_vs_llm", "rule-vs-llm":
			report = await tool.call("run_rule_vs_llm", games, options)
			report["mode"] = "rule_vs_llm"
		_:
			report = {
				"mode": mode,
				"error": "unsupported mode",
				"supported_modes": ["self_play", "rule_vs_llm", "miraidon"],
			}

	var json_text := JSON.stringify(_json_ascii_safe(report), "\t")
	var json_output := str(args.get("json-output", DEFAULT_JSON_OUTPUT))
	if json_output != "":
		_write_text(json_output, json_text)
	print(json_text)
	if is_instance_valid(tool):
		tool.queue_free()
	quit(1 if report.has("error") else 0)


func _parse_args(raw_args: PackedStringArray) -> Dictionary:
	var parsed := {}
	for raw_arg: String in raw_args:
		if not raw_arg.begins_with("--"):
			continue
		var eq_index := raw_arg.find("=")
		if eq_index <= 2:
			continue
		var key := raw_arg.substr(2, eq_index - 2)
		var value := raw_arg.substr(eq_index + 1)
		parsed[key] = value
	return parsed


func _parse_bool(value: String) -> bool:
	var normalized := value.strip_edges().to_lower()
	return normalized in ["1", "true", "yes", "y", "on", "strong"]


func _write_text(path: String, text: String) -> void:
	var normalized_path := path.strip_edges()
	if normalized_path == "":
		return
	var absolute_path := normalized_path
	if normalized_path.begins_with("res://") or normalized_path.begins_with("user://"):
		absolute_path = ProjectSettings.globalize_path(normalized_path)
	var dir := absolute_path.get_base_dir()
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write JSON output: %s" % normalized_path)
		return
	file.store_string(text)
	file.close()


func _json_ascii_safe(value: Variant) -> Variant:
	if value is Dictionary:
		var safe_dict := {}
		for raw_key: Variant in (value as Dictionary).keys():
			safe_dict[str(raw_key)] = _json_ascii_safe((value as Dictionary).get(raw_key))
		return safe_dict
	if value is Array:
		var safe_array: Array = []
		for raw_item: Variant in value:
			safe_array.append(_json_ascii_safe(raw_item))
		return safe_array
	if value is String:
		return _ascii_safe_string(str(value))
	return value


func _ascii_safe_string(text: String) -> String:
	var parts := PackedStringArray()
	for i: int in text.length():
		var code := text.unicode_at(i)
		if code >= 32 and code <= 126:
			parts.append(text.substr(i, 1))
		elif code in [9, 10, 13]:
			parts.append(" ")
		else:
			parts.append("?")
	return "".join(parts)
