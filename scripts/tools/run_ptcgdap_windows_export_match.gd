extends Node

const ACCEPTANCE_SCRIPT_PATH := "res://scripts/ai/ptcgdap/acceptance/AuthorStrategyWindowsExportMatchAcceptance.gd"
const REPORT_PREFIX := "PTCGDAP_WINDOWS_EXPORT_MATCH="
const ACTIVATION_ARG := "--ptcgdap-development-export-match"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if ACTIVATION_ARG not in args:
		return
	if OS.get_name() != "Windows":
		print(REPORT_PREFIX + JSON.stringify({
			"document_type": "author_strategy_windows_export_match_report_v1",
			"runtime_platform": OS.get_name(),
			"standalone_export": OS.has_feature("template") and not OS.has_feature("editor"),
			"complete_match_finished": false,
			"is_clean": false,
			"dirty_reasons": ["development_platform_not_authorized"],
			"development_only": true,
			"production_ready": false,
		}))
		get_tree().quit(1)
		return
	var acceptance_script := load(ACCEPTANCE_SCRIPT_PATH) as Script
	if acceptance_script == null or not acceptance_script.can_instantiate():
		push_error("Windows export-match acceptance script is unavailable")
		get_tree().quit(1)
		return
	var card_database := get_node_or_null("/root/CardDatabase")
	var report: Dictionary = acceptance_script.new().run(card_database, _parse_args(args))
	var is_export_template := OS.has_feature("template") and not OS.has_feature("editor")
	report["standalone_export"] = is_export_template
	report["export_template_feature"] = OS.has_feature("template")
	report["editor_feature"] = OS.has_feature("editor")
	report["runtime_platform"] = OS.get_name()
	if not is_export_template:
		(report["dirty_reasons"] as Array).append("not_standalone_export")
		report["is_clean"] = false
		report["complete_match_finished"] = false
	print(REPORT_PREFIX + JSON.stringify(report))
	get_tree().quit(0 if bool(report.get("is_clean", false)) else 1)


func _parse_args(args: PackedStringArray) -> Dictionary:
	var parsed := {}
	for arg: String in args:
		if arg.begins_with("--games="):
			parsed["games"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--seed-base="):
			parsed["seed_base"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--max-steps="):
			parsed["max_steps"] = int(arg.get_slice("=", 1))
	return parsed
