class_name AuthorStrategyFeatureGate
extends RefCounted

const PROJECT_SETTING := "ptcgdap/author_strategy/enabled"
const DISABLE_ARG := "--ptcgdap-disable-author-strategy-mode"


static func is_enabled() -> bool:
	return is_enabled_for_args(OS.get_cmdline_user_args())


static func is_enabled_for_args(args: PackedStringArray) -> bool:
	return bool(ProjectSettings.get_setting(PROJECT_SETTING, true)) and DISABLE_ARG not in args
