extends SceneTree

const BattleRecorderScript = preload("res://scripts/engine/BattleRecorder.gd")
const DeveloperTraceScript = preload(
	"res://scripts/ui/battle/author_strategy/AuthorStrategyDeveloperDecisionTrace.gd"
)


class FixtureOwner extends RefCounted:
	var records: Array = []
	var trace_enabled := false

	func public_replay_identity() -> Dictionary:
		return {
			"ok": true,
			"match_id": "cross-runtime-policy-fixture",
			"source_authority": "ptcgdap_author_public_owner_v1",
			"card_catalog_sha256": "B".repeat(64),
			"strategy_participant": {
				"strategy_id": "fixture.strategy",
				"release_version": "0.1.0",
				"package_id": "fixture.package",
				"archive_sha256": "A".repeat(64),
			},
		}

	func audit_snapshot() -> Dictionary:
		return {
			"policy_calls": 1,
			"policy_successes": 1,
			"policy_errors": 0,
			"invalid_outputs": 0,
			"same_window_fallbacks": 0,
			"engine_commits": 1,
			"engine_rejections": 0,
		}

	func enable_developer_decision_trace(value: bool = true) -> void:
		trace_enabled = value

	func drain_developer_decision_records() -> Array:
		var drained := records.duplicate(true)
		records.clear()
		return drained


func _initialize() -> void:
	var output_root := _argument("output-root")
	if output_root.is_empty():
		printerr("missing --output-root")
		quit(2)
		return
	var recorder: Variant = BattleRecorderScript.new()
	recorder.set_output_root(output_root)
	recorder.start_match({
		"mode": "ai",
		"player_types": ["human", "ai"],
		"player_labels": ["fixture-human", "fixture-author"],
		"first_player_index": 0,
	})
	var match_dir := str(recorder.get_match_dir())
	if match_dir.is_empty():
		printerr("recorder start failed")
		quit(1)
		return
	recorder.record_event({
		"event_type": "state_snapshot",
		"snapshot_reason": "turn_start",
		"turn_number": 1,
		"phase": "main",
		"player_index": 0,
	})
	var owner := FixtureOwner.new()
	owner.records.append({
		"document_type": "decision_window_record_v1",
		"schema_version": 1,
		"decision_id": "cross-runtime-policy-fixture.window.1",
		"policy_match_id": "cross-runtime-policy-fixture",
		"frame": {
			"sequence": 1,
			"prompt_kind": "main",
			"source": {
				"public_observation_hash": "C".repeat(64),
				"window_id": "D".repeat(64),
			},
			"public_state": {
				"self": {"hand": [{"local_card_uid": "SVI_001"}]},
				"opponent": {"hand_count": 7},
			},
			"select_semantics": {"min_count": 1, "max_count": 1},
			"options": [{
				"index": 0,
				"kind": "attack",
				"option_fingerprint": "E".repeat(64),
			}],
		},
		"policy": {
			"ok": true,
			"reported_indexes": [0],
			"matched_rule_ids": ["fixture.attack"],
			"base_result": {
				"selected_indexes": [0],
				"reason_code": "deterministic_fallback",
				"fallback_branch": "same_window_first_min",
				"node_audit": [{"node_id": "emit", "output_indexes": [0]}],
				"execution_hash": "F".repeat(64),
			},
		},
		"host": {
			"status": "accepted",
			"accepted_indexes": [0],
			"accepted_option_fingerprints": ["E".repeat(64)],
			"fallback_used": false,
			"error_code": "",
			"latency_usec": 123,
		},
	})
	var trace: Variant = DeveloperTraceScript.new()
	var started: Dictionary = trace.start(owner, match_dir, 1)
	if not bool(started.get("ok", false)):
		printerr("trace start failed: %s" % str(started))
		quit(1)
		return
	recorder.record_event({
		"event_type": "action_selected",
		"turn_number": 1,
		"phase": "main",
		"player_index": 1,
	})
	trace.record_owner_step(owner, "progressed", 2)
	var trace_finished: Dictionary = trace.finish(owner, 0, "prize_out", 1)
	if not bool(trace_finished.get("complete", false)):
		printerr("trace finish failed: %s" % str(trace_finished))
		quit(1)
		return
	recorder.finalize_match({
		"winner_index": 0,
		"reason": "prize_out",
		"turn_number": 1,
		"seat_statuses": ["DONE", "DONE"],
		"rewards": [1, -1],
		"faults": [null, null],
		"terminal_source": "controlled_fixture_v1",
	})
	print("NATIVE_REPLAY_FIXTURE=" + ProjectSettings.globalize_path(match_dir))
	quit(0)


func _argument(name: String) -> String:
	var prefix := "--%s=" % name
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""
