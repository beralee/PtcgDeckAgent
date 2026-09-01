class_name AuthorStrategyWindowsUiMatchAcceptance
extends RefCounted

const DOCUMENT_TYPE := "author_strategy_windows_ui_match_report_v1"
const REQUIRED_SCENES := [
	"res://scenes/main_menu/MainMenu.tscn",
	"res://scenes/battle_setup/BattleSetup.tscn",
	"res://scenes/battle/BattleScene.tscn",
]


static func build_report(
	battle_scene: Control,
	winner_index: int,
	reason: String,
	observed_scene_paths: Array,
	started_usec: int,
	acceptance_mode: String = "development"
) -> Dictionary:
	var dirty_reasons: Array[String] = []
	var author_audit: Dictionary = {}
	var rules_counters: Dictionary = {}
	var turn_number := -1
	var phase := -1
	var author_owner: Variant = null
	var rules_owner: Variant = null
	if battle_scene == null:
		dirty_reasons.append("battle_scene_missing")
	else:
		author_owner = battle_scene.get("_author_player_owner")
		rules_owner = battle_scene.get("_development_player_rules_owner")
		var gsm: Variant = battle_scene.get("_gsm")
		if gsm == null or gsm.game_state == null:
			dirty_reasons.append("game_state_missing")
		else:
			turn_number = int(gsm.game_state.turn_number)
			phase = int(gsm.game_state.phase)
			if not gsm.game_state.is_game_over():
				dirty_reasons.append("match_not_terminal")
	if author_owner == null or not author_owner.has_method("audit_snapshot"):
		dirty_reasons.append("author_owner_missing")
	else:
		author_audit = author_owner.call("audit_snapshot")
	if rules_owner == null:
		dirty_reasons.append("rules_owner_missing")
	else:
		if rules_owner.has_method("get_event_counters"):
			rules_counters = rules_owner.call("get_event_counters")
		if int(rules_owner.player_index) != 0:
			dirty_reasons.append("rules_owner_wrong_seat")
		if bool(rules_owner.use_mcts):
			dirty_reasons.append("rules_owner_mcts_enabled")
		if str(rules_owner.decision_runtime_mode) != "rules_only":
			dirty_reasons.append("rules_owner_not_rules_only")
	if author_owner != null and int(author_owner.player_index) != 1:
		dirty_reasons.append("author_owner_wrong_seat")
	if winner_index not in [0, 1]:
		dirty_reasons.append("winner_missing")
	for path: String in REQUIRED_SCENES:
		if path not in observed_scene_paths:
			dirty_reasons.append("scene_not_observed:%s" % path)
	if not _contains_required_scenes_in_order(observed_scene_paths):
		dirty_reasons.append("ordinary_scene_path_out_of_order")
	if int(author_audit.get("policy_calls", 0)) <= 0 \
			or author_audit.get("policy_calls") != author_audit.get("policy_successes"):
		dirty_reasons.append("policy_accounting")
	for zero_key: String in [
		"policy_errors",
		"invalid_outputs",
		"same_window_fallbacks",
		"classic_fallbacks",
		"engine_rejections",
		"external_process_attempts",
	]:
		if int(author_audit.get(zero_key, 0)) != 0:
			dirty_reasons.append("%s:%d" % [zero_key, int(author_audit.get(zero_key, 0))])
	if int(author_audit.get("engine_commits", 0)) <= 0:
		dirty_reasons.append("no_author_engine_commits")
	var device_canary := acceptance_mode == "device_canary"
	if acceptance_mode not in ["development", "device_canary"]:
		dirty_reasons.append("acceptance_mode_invalid")
	elif device_canary:
		if (
			author_audit.get("device_canary_authority") != true
			or author_audit.get("execution_trusted") != true
			or author_audit.get("signature_scope") != "production_release"
			or author_audit.get("production_ready") != false
		):
			dirty_reasons.append("device_canary_authority_invalid")
	elif (
		author_audit.get("development_execution_only") != true
		or author_audit.get("execution_trusted") != false
	):
		dirty_reasons.append("development_authority_invalid")
	var elapsed_msec := maxi(0, int((Time.get_ticks_usec() - started_usec) / 1000))
	return {
		"schema_version": 1,
		"document_type": DOCUMENT_TYPE,
		"runtime_platform": OS.get_name(),
		"standalone_export": OS.has_feature("template") and not OS.has_feature("editor"),
		"acceptance_mode": acceptance_mode,
		"development_only": not device_canary,
		"device_canary": device_canary,
		"production_ready": false,
		"a5_claimed": false,
		"card_id_domain": "godot_local_card_uid_v1",
		"winner_index": winner_index,
		"reason": reason,
		"turn_number": turn_number,
		"phase": phase,
		"elapsed_msec": elapsed_msec,
		"complete_match_finished": dirty_reasons.is_empty(),
		"ordinary_scene_path_observed": _contains_required_scenes_in_order(observed_scene_paths),
		"observed_scene_paths": observed_scene_paths.duplicate(),
		"real_mouse_input_proven": false,
		"network_isolation_proven": false,
		"presentation_accelerated": true,
		"author_audit": author_audit.duplicate(true),
		"rules_owner": {
			"seat": int(rules_owner.player_index) if rules_owner != null else -1,
			"rules_only": rules_owner != null \
				and not bool(rules_owner.use_mcts) \
				and str(rules_owner.decision_runtime_mode) == "rules_only",
			"event_counters": rules_counters.duplicate(true),
		},
		"is_clean": dirty_reasons.is_empty(),
		"dirty_reasons": dirty_reasons,
	}


static func _contains_required_scenes_in_order(observed_scene_paths: Array) -> bool:
	var cursor := 0
	for raw_path: Variant in observed_scene_paths:
		if cursor < REQUIRED_SCENES.size() and str(raw_path) == REQUIRED_SCENES[cursor]:
			cursor += 1
	return cursor == REQUIRED_SCENES.size()
