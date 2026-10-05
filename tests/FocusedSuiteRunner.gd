extends "res://tests/CliTestRunner.gd"


func _initialize() -> void:
	if not parse_args(OS.get_cmdline_user_args()).has("suite-script"):
		push_error("Missing --suite-script")
		quit(2)
		return
	super._initialize()
