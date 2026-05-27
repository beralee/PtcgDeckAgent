class_name TestLLMDecisionAuditLogger
extends TestBase


func test_llm_decision_audit_logger_creates_user_log_dir_and_writes_event() -> String:
	var logger_script := load("res://scripts/ai/LLMDecisionAuditLogger.gd")
	var logger = logger_script.new() if logger_script != null and logger_script.can_instantiate() else null
	if logger == null:
		return "LLMDecisionAuditLogger.gd should instantiate"
	var log_path := "user://logs/test_llm_decision_audit_logger_%d.jsonl" % Time.get_ticks_usec()
	logger.set("log_path", log_path)
	logger.call("log_event", "unit_test_event", {"route": "regidrago"})
	var effective_path := str(logger.get("log_path"))
	var absolute_path := ProjectSettings.globalize_path(effective_path)
	var text := FileAccess.get_file_as_string(absolute_path)
	var removed := DirAccess.remove_absolute(absolute_path)
	return run_checks([
		assert_true(FileAccess.file_exists(absolute_path) or text != "", "Audit logger should create user://logs and write an event file"),
		assert_true(effective_path == log_path or effective_path.begins_with("res://tmp/llm_audit/logs/"), "Audit logger should fall back to a project-local path when user:// is unavailable"),
		assert_str_contains(text, "\"event\":\"unit_test_event\"", "Audit log line should include the event name"),
		assert_str_contains(text, "\"route\":\"regidrago\"", "Audit log line should include event payload fields"),
		assert_true(removed == OK or removed == ERR_FILE_NOT_FOUND, "Audit test log cleanup should not fail"),
	])
