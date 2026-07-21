extends SceneTree

const CardDataScript := preload("res://scripts/data/CardData.gd")


func _initialize() -> void:
	var options := _parse_options(OS.get_cmdline_user_args())
	var input_dir := str(options.get("input-dir", "")).strip_edges()
	var output_dir := str(options.get("output-dir", "")).strip_edges()
	var set_code := str(options.get("set-code", "")).strip_edges()
	var first_index := int(options.get("from", 0))
	var last_index := int(options.get("to", 0))
	if input_dir == "" or output_dir == "" or set_code == "" or first_index <= 0 or last_index < first_index:
		push_error("Usage: --input-dir=<path> --output-dir=<path> --set-code=<code> --from=<n> --to=<n>")
		quit(2)
		return

	DirAccess.make_dir_recursive_absolute(output_dir)
	var converted := 0
	for card_number: int in range(first_index, last_index + 1):
		var card_index := "%03d" % card_number
		var source_path := input_dir.path_join("%s_%d.api.json" % [set_code, card_number])
		if not FileAccess.file_exists(source_path):
			push_error("Missing API cache file: %s" % source_path)
			quit(3)
			return
		var raw_text := FileAccess.get_file_as_string(source_path)
		var parsed: Variant = JSON.parse_string(raw_text.trim_prefix("\ufeff"))
		if not (parsed is Dictionary):
			push_error("Invalid API cache JSON: %s" % source_path)
			quit(4)
			return
		var card: CardData = CardDataScript.from_api_json(parsed as Dictionary)
		card.source_provider = "tcg_mik"
		card.source_url = "https://tcg.mik.moe/cards/%s/%s" % [set_code, card_index]
		card.source_set_code = set_code
		card.source_card_index = card_index
		card.source_language = "zh-CN"
		card.source_parser_version = 1
		var output_path := output_dir.path_join("%s_%s.json" % [set_code, card_index])
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		if file == null:
			push_error("Unable to create converted card: %s" % output_path)
			quit(5)
			return
		file.store_string(JSON.stringify(card.to_dict(), "  ") + "\n")
		converted += 1

	print("Converted %d tcg.mik.moe cards into %s" % [converted, output_dir])
	quit(0)


func _parse_options(args: PackedStringArray) -> Dictionary:
	var options := {}
	for arg: String in args:
		if not arg.begins_with("--") or not arg.contains("="):
			continue
		var separator := arg.find("=")
		options[arg.substr(2, separator - 2)] = arg.substr(separator + 1)
	return options
