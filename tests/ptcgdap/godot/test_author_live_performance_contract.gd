class_name TestAuthorLivePerformanceContract
extends TestBase

const PACING_PROFILE_PATH := "res://scripts/ui/battle/performance/BattleLivePacingProfile.gd"
const RECORDING_PROFILE_PATH := "res://scripts/ui/battle/author_strategy/AuthorStrategyRecordingProfile.gd"
const BATTLE_RUNTIME_PATH := "res://scenes/battle/BattleSceneRuntime.gd"
const HASH_PATH := "res://scripts/engine/ReplayDiagnosticHash.gd"
const TEST_LOG_PATH := "user://ptcgdap_tests/author_live_performance/batched.jsonl"
const RECORDER_PATH := "res://scripts/engine/BattleRecorder.gd"
const RECORDER_ROOT := "user://ptcgdap_tests/author_live_performance/native_batch"
const SETUP_RUNTIME_PATH := "res://scenes/battle/runtime/BattleSceneSetupEffectAiRuntime.gd"
const BOARD_RUNTIME_PATH := "res://scenes/battle/runtime/BattleSceneBoardActionRuntime.gd"
const RECORDING_CONTROLLER_PATH := "res://scripts/ui/battle/BattleRecordingController.gd"
const DISPLAY_CONTROLLER_PATH := "res://scripts/ui/battle/BattleDisplayController.gd"
const VISUAL_SEQUENCE_PATH := "res://scripts/ui/battle/visuals/BattleVisualSequenceController.gd"
const DRAW_REVEAL_PATH := "res://scripts/ui/battle/BattleDrawRevealController.gd"
const CARD_VIEW_PATH := "res://scenes/battle/BattleCardView.gd"
const AUTHOR_OWNER_PATH := "res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd"
const AUTHOR_HANDLE_PATH := "res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageHandle.gd"
const AUTHOR_DECK_MATERIALIZER_PATH := "res://scripts/ai/ptcgdap/packages/AuthorStrategyDeckMaterializer.gd"
const DIALOG_RUNTIME_PATH := "res://scenes/battle/runtime/BattleSceneDialogInteractionReviewRuntime.gd"
const SHARED_HUD_RUNTIME_PATH := "res://scenes/battle/runtime/BattleSceneSharedHudAiRuntime.gd"


func test_default_author_profiles_are_realtime_and_compact_with_explicit_rollbacks() -> String:
	if not ResourceLoader.exists(PACING_PROFILE_PATH):
		return "缺少作者实时节奏档"
	if not ResourceLoader.exists(RECORDING_PROFILE_PATH):
		return "缺少作者记录档"
	var pacing_script: Variant = load(PACING_PROFILE_PATH)
	var recording_script: Variant = load(RECORDING_PROFILE_PATH)
	var realtime: Dictionary = pacing_script.resolve_profile("")
	var cinematic: Dictionary = pacing_script.resolve_profile("cinematic_v1")
	var compact: Dictionary = recording_script.resolve_profile("")
	var full: Dictionary = recording_script.resolve_profile("developer_full_v1")
	return run_checks([
		assert_eq(str(realtime.get("profile_id", "")), "author_realtime_v1", "作者模式默认应使用实时节奏"),
		assert_true(float(realtime.get("action_pause_seconds", 9.0)) <= 0.15, "实时档动作间隔不得超过 150ms"),
		assert_true(float(realtime.get("visual_playback_speed", 0.0)) > 1.0, "实时档应加快动画播放"),
		assert_eq(str(cinematic.get("profile_id", "")), "cinematic_v1", "必须保留电影节奏回滚档"),
		assert_eq(float(cinematic.get("action_pause_seconds", 0.0)), 2.0, "电影档应保持既有 2 秒节奏"),
		assert_eq(str(compact.get("profile_id", "")), "player_compact_v1", "作者模式默认应使用精简记录档"),
		assert_false(bool(compact.get("developer_trace_enabled", true)), "精简档不应生成逐决策开发轨迹"),
		assert_eq(str(compact.get("public_replay_progress_mode", "")), "decision_boundary", "精简档应按决策边界采样公开回放"),
		assert_true(bool(full.get("developer_trace_enabled", false)), "完整开发档必须可显式恢复"),
		assert_eq(str(full.get("public_replay_progress_mode", "")), "action", "完整开发档应保留逐动作采样"),
	])


func test_author_policy_uses_worker_and_reuses_existing_thinking_hud() -> String:
	var setup_source := FileAccess.get_file_as_string(SETUP_RUNTIME_PATH)
	var owner_source := FileAccess.get_file_as_string(AUTHOR_OWNER_PATH)
	var dialog_source := FileAccess.get_file_as_string(DIALOG_RUNTIME_PATH)
	var hud_source := FileAccess.get_file_as_string(SHARED_HUD_RUNTIME_PATH)
	return run_checks([
		assert_str_contains(setup_source, "policy_execution_profile = \"worker_v1\"", "实时作者对战应默认使用工作线程"),
		assert_str_contains(setup_source, "PTCGDAP_AUTHOR_POLICY_EXECUTION_PROFILE", "必须保留显式主线程回滚开关"),
		assert_str_contains(owner_source, "AuthorStrategyPolicyWorker.gd", "作者策略纯计算应有独立工作线程 owner"),
		assert_str_contains(owner_source, "model_worker_result_missing", "可选本地模型叶也必须由同一工作线程返回结果"),
		assert_str_contains(owner_source, "stale_policy_response", "异步结果必须保留当前窗口过期保护"),
		assert_str_contains(dialog_source, "_start_llm_wait_hud(turn_number)", "作者策略等待应复用大模型思考 HUD"),
		assert_str_contains(dialog_source, "await get_tree().process_frame", "等待策略时主线程必须继续逐帧渲染"),
		assert_str_contains(hud_source, "ptcgdap-author-local", "思考 HUD 应显示本地作者策略身份"),
	])


func test_author_battle_labels_use_pinned_package_presentation_instead_of_package_id() -> String:
	var handle_source := FileAccess.get_file_as_string(AUTHOR_HANDLE_PATH)
	var materializer_source := FileAccess.get_file_as_string(AUTHOR_DECK_MATERIALIZER_PATH)
	var setup_source := FileAccess.get_file_as_string(SETUP_RUNTIME_PATH)
	var display_source := FileAccess.get_file_as_string(DISPLAY_CONTROLLER_PATH)
	var hud_source := FileAccess.get_file_as_string(SHARED_HUD_RUNTIME_PATH)
	return run_checks([
		assert_str_contains(handle_source, "func presentation_snapshot()", "exact handle 应暴露经完整性校验的公开展示快照"),
		assert_str_contains(materializer_source, "presentation.get(\"deck_name\"", "materialized deck 名称必须来自包内 deck.display_name"),
		assert_false(materializer_source.contains("作者策略包 · %s · v%s"), "玩家牌组名不得继续拼接英文 package ID"),
		assert_str_contains(setup_source, "_author_strategy_author_name", "开局必须固定本局作者显示名"),
		assert_str_contains(setup_source, "_author_strategy_deck_label", "开局必须固定本局卡组显示名和版本"),
		assert_str_contains(display_source, "_author_strategy_deck_label", "左上当前牌组应读取本局固定显示名，不能反复深检 archive"),
		assert_str_contains(hud_source, "_author_strategy_author_name", "思考标题必须读取策略包作者名"),
	])


func test_action_signal_enqueues_visuals_before_author_diagnostics() -> String:
	var source := FileAccess.get_file_as_string(BATTLE_RUNTIME_PATH)
	var function_start := source.find("func _on_action_logged")
	if function_start < 0:
		return "找不到 _on_action_logged"
	var function_end := source.find("\nfunc ", function_start + 1)
	var body := source.substr(function_start, function_end - function_start if function_end >= 0 else -1)
	var enqueue_index := body.find("_enqueue_battle_visual_action(action)")
	var evidence_index := body.find("_record_author_public_action(action)")
	var replay_index := body.find("_record_author_public_replay_progress()")
	return run_checks([
		assert_gte(enqueue_index, 0, "动作信号必须显式先进入动画队列"),
		assert_true(enqueue_index < evidence_index, "动画入队必须早于作者证据记录"),
		assert_true(replay_index < 0 or enqueue_index < replay_index, "动画入队必须早于公开回放采样"),
	])


func test_diagnostic_hash_can_append_one_log_batch_with_one_call() -> String:
	var hash_script: Variant = load(HASH_PATH)
	if not hash_script.has_method("append_lines"):
		return "ReplayDiagnosticHash 缺少批量追加接口"
	var global_path := ProjectSettings.globalize_path(TEST_LOG_PATH)
	if FileAccess.file_exists(global_path):
		DirAccess.remove_absolute(global_path)
	var batch: Array[String] = ["one", "two", "three"]
	var accepted: bool = hash_script.append_lines(TEST_LOG_PATH, batch)
	var lines: Array[String] = hash_script.read_non_empty_lines(TEST_LOG_PATH)
	return run_checks([
		assert_true(accepted, "批量追加应成功"),
		assert_eq(lines, ["one", "two", "three"], "批量追加应保持顺序和 JSONL 行边界"),
	])


func test_compact_profiles_are_wired_to_author_startup_and_owner_boundaries() -> String:
	var setup_source := FileAccess.get_file_as_string(SETUP_RUNTIME_PATH)
	var board_source := FileAccess.get_file_as_string(BOARD_RUNTIME_PATH)
	var recording_source := FileAccess.get_file_as_string(RECORDING_CONTROLLER_PATH)
	return run_checks([
		assert_str_contains(setup_source, "_configure_battle_runtime_profiles()", "开局必须先应用节奏与记录档"),
		assert_str_contains(setup_source, "_start_author_recording_channels(_author_player_owner)", "作者 owner 应按记录档启动通道"),
		assert_str_contains(recording_source, "player_compact_v1", "原生记录器应只在精简作者档切换批量模式"),
		assert_str_contains(recording_source, "decision_batch_v1", "精简作者档必须选择决策批量写入"),
		assert_str_contains(board_source, "_battle_recorder.call(\"flush_pending\")", "owner 决策结束必须形成增量落盘边界"),
	])


func test_battle_ui_refresh_keeps_authoritative_rebind_without_performance_shortcuts() -> String:
	var display_source := FileAccess.get_file_as_string(DISPLAY_CONTROLLER_PATH)
	var sequence_source := FileAccess.get_file_as_string(VISUAL_SEQUENCE_PATH)
	var board_source := FileAccess.get_file_as_string(BOARD_RUNTIME_PATH)
	var draw_source := FileAccess.get_file_as_string(DRAW_REVEAL_PATH)
	var card_view_source := FileAccess.get_file_as_string(CARD_VIEW_PATH)
	return run_checks([
		assert_false(display_source.contains("is_bound_to_instance"), "战场刷新不得按卡牌身份跳过完整 UI 绑定"),
		assert_false(display_source.contains("battle_field_slot_style_signature"), "战场槽样式不得用性能签名跳过恢复"),
		assert_false(card_view_source.contains("func is_bound_to_instance"), "BattleCardView 不得暴露性能复用捷径"),
		assert_false(sequence_source.contains("_pending_field_resync_events"), "动画结束不得把 UI 恢复改成批量延迟重绘"),
		assert_false(board_source.contains("_request_battle_visual_completion_resync"), "战斗运行时不得跨帧接管 UI 完成恢复"),
		assert_false(draw_source.contains("_request_draw_reveal_completion_reconciliation"), "抽牌动画不得通过延迟性能边界改变原 UI 时序"),
	])


func test_compact_native_recorder_flushes_one_batch_at_decision_boundary() -> String:
	_remove_tree(RECORDER_ROOT)
	var recorder_script: Variant = load(RECORDER_PATH)
	var recorder: Variant = recorder_script.new()
	if not recorder.has_method("set_write_profile") or not recorder.has_method("flush_pending"):
		return "BattleRecorder 缺少精简档批量写入边界"
	recorder.set_output_root(RECORDER_ROOT)
	recorder.set_write_profile("decision_batch_v1")
	recorder.start_match({
		"mode": "vs_author_strategy_ai",
		"author_recording_profile_id": "player_compact_v1",
	})
	for index: int in 3:
		recorder.record_event({
			"event_type": "state_snapshot" if index == 1 else "action_resolved",
			"turn_number": 1,
			"player_index": 1,
		})
	var before: Dictionary = recorder.get_write_audit()
	var flushed: bool = recorder.flush_pending()
	var after: Dictionary = recorder.get_write_audit()
	var detail_lines: Array[String] = load(HASH_PATH).read_non_empty_lines(
		str(recorder.get_match_dir()).path_join("detail.jsonl")
	)
	recorder.finalize_match({"winner_index": 1, "reason": "test"})
	var manifest: Dictionary = load(HASH_PATH).read_json(
		str(recorder.get_match_dir()).path_join("native_replay_manifest.json")
	)
	var developer_trace: Dictionary = manifest.get("developer_decision_trace", {})
	var result := run_checks([
		assert_eq(int(before.get("pending_event_count", -1)), 3, "容量阈值前应保留一个决策批次"),
		assert_eq(int(before.get("batch_write_count", -1)), 0, "决策边界前不应逐事件强制刷盘"),
		assert_true(flushed, "决策边界批次应成功落盘"),
		assert_eq(int(after.get("pending_event_count", -1)), 0, "落盘后不得残留待写事件"),
		assert_eq(int(after.get("batch_write_count", -1)), 1, "三个事件应合并为一次批量写入"),
		assert_eq(detail_lines.size(), 3, "批量写入不得丢失原生事件"),
		assert_eq(int(manifest.get("record_count", -1)), 3, "完整性清单应覆盖批量写入的全部事件"),
		assert_eq(str(developer_trace.get("reason", "")), "disabled_by_recording_profile", "精简档应审计为主动停用开发轨迹"),
	])
	_remove_tree(RECORDER_ROOT)
	return result


func _remove_tree(path: String) -> void:
	var global_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(global_path):
		return
	var directory := DirAccess.open(global_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry not in [".", ".."]:
			var child_global := global_path.path_join(entry)
			if directory.current_is_dir():
				_remove_tree(path.path_join(entry))
				DirAccess.remove_absolute(child_global)
			else:
				DirAccess.remove_absolute(child_global)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(global_path)
