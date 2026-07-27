class_name DeckTrainingFeatureNotice
extends RefCounted


const NOTICE_REVISION := "18.0_challenge_training_r1"
const STATE_PATH := "user://deck_training_feature_notice.json"
const HEADLESS_STATE_PATH := "user://deck_training_feature_notice.headless.json"


static func state_path_for_display_server(display_server_name: String) -> String:
	return HEADLESS_STATE_PATH if display_server_name.strip_edges().to_lower() == "headless" else STATE_PATH


static func state_path() -> String:
	return state_path_for_display_server(DisplayServer.get_name())


static func load_state(path_override: String = "") -> Dictionary:
	var path := _resolved_path(path_override)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return {}
	return (parsed as Dictionary).duplicate(true)


static func is_unseen(revision: String = NOTICE_REVISION, path_override: String = "") -> bool:
	var normalized := revision.strip_edges()
	if normalized == "":
		return false
	return str(load_state(path_override).get("last_seen_revision", "")).strip_edges() != normalized


static func mark_seen(revision: String = NOTICE_REVISION, path_override: String = "") -> bool:
	var normalized := revision.strip_edges()
	if normalized == "":
		return false
	var state := load_state(path_override)
	state["format_version"] = 1
	state["last_seen_revision"] = normalized
	state["last_seen_at"] = int(Time.get_unix_time_from_system())
	var file := FileAccess.open(_resolved_path(path_override), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(state, "\t"))
	file.close()
	return true


static func _resolved_path(path_override: String) -> String:
	var normalized := path_override.strip_edges()
	return normalized if normalized != "" else state_path()
