class_name TestAuthorMatchEvidence
extends TestBase

const EvidenceScript = preload("res://scripts/ui/battle/author_strategy/AuthorStrategyMatchEvidence.gd")
const QuickReviewBuilderScript = preload("res://scripts/ui/battle/advice/BattleMatchEndQuickReviewBuilder.gd")


class FakeOwner extends RefCounted:
	var calls := 2

	func public_replay_identity() -> Dictionary:
		return {
			"ok": true,
			"match_id": "author-evidence-fixture",
			"source_authority": "ptcgdap_author_public_owner_v1",
			"strategy_participant": {
				"strategy_id": "ptcgdap.marnie.18.0.package-local-v1",
				"release_version": "0.1.0",
				"package_id": "ptcgdap.marnie.windows-local",
				"archive_sha256": "A".repeat(64),
			},
		}

	func audit_snapshot() -> Dictionary:
		return {
			"schema_version": 1,
			"package_id": "ptcgdap.marnie.windows-local",
			"package_version": "0.1.0",
			"archive_sha256": "A".repeat(64),
			"policy_calls": calls,
			"policy_successes": calls,
			"policy_errors": 0,
			"invalid_outputs": 0,
			"same_window_fallbacks": 0,
			"engine_commits": calls,
			"engine_rejections": 0,
			"prompt_counts": {"main": calls},
			"matched_rule_counts": {"marnie.shadow-bullet.attack": 1},
			"last_error_code": "",
			"production_ready": false,
		}


func test_author_evidence_is_incremental_public_safe_and_reviewable() -> String:
	var root := "user://ptcgdap_tests/author_match_evidence"
	var owner := FakeOwner.new()
	var evidence: Variant = EvidenceScript.new()
	var started: Dictionary = evidence.start(owner, root)
	if not bool(started.get("ok", false)):
		return "author evidence start failed: %s" % str(started)
	var attack := GameAction.create(
		GameAction.ActionType.ATTACK,
		1,
		{
			"attack_name": "暗影子弹",
			"target_pokemon_name": "烈咬陆鲨ex",
			"damage": 130,
			"opponent_hidden_hand": ["must-not-leak"],
		},
		7,
		"玩家2使用招式「暗影子弹」"
	)
	var damage := GameAction.create(
		GameAction.ActionType.DAMAGE_DEALT,
		1,
		{"target": "烈咬陆鲨ex", "damage": 130, "private_rng": 999},
		7,
		"玩家2使用 暗影子弹 对 烈咬陆鲨ex 造成 130 点伤害"
	)
	var knockout := GameAction.create(
		GameAction.ActionType.KNOCKOUT,
		0,
		{"pokemon_name": "烈咬陆鲨ex", "prize_count": 2, "private_card_id": "secret"},
		7,
		"玩家1的 烈咬陆鲨ex 昏厥"
	)
	evidence.record_action(attack)
	evidence.record_action(damage)
	evidence.record_action(knockout)
	evidence.record_owner_step(owner, "progressed")
	var finished: Dictionary = evidence.finish(owner, 1, "拿完奖赏卡", 7)
	var path := str(finished.get("path", ""))
	var raw := FileAccess.get_file_as_string(path) if path != "" else ""
	var context: Dictionary = evidence.quick_review_context()
	var recent_turns: Array = context.get("recent_turns", [])
	var recent_actions: Array = (recent_turns[0] as Dictionary).get("key_actions", []) if not recent_turns.is_empty() else []
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AUTHOR_STRATEGY_AI
	var quick_payload: Dictionary = QuickReviewBuilderScript.new().build_payload({
		"winner_index": 0,
		"players": [
			{"prizes_taken": 6},
			{"prizes_taken": 4},
		],
	}, 1, "", context)
	GameManager.current_mode = previous_mode as GameManager.GameMode
	var checks := run_checks([
		assert_true(bool(finished.get("ok", false))),
		assert_true(FileAccess.file_exists(path), "incremental audit must persist to its dedicated path"),
		assert_eq(raw.find("must-not-leak"), -1, "raw action data outside the allow-list must not persist"),
		assert_eq(raw.find("private_rng"), -1, "private RNG data must not persist"),
		assert_eq(raw.find("private_card_id"), -1, "private identity data must not persist"),
		assert_true(raw.contains("暗影子弹"), "public attack name should remain auditable"),
		assert_true(raw.contains("130"), "public damage should remain auditable"),
		assert_eq(str((context.get("evidence", {}) as Dictionary).get("visibility", "")), "public_allow_list_v1"),
		assert_true(not recent_actions.is_empty(), "quick review must receive exact public actions"),
		assert_eq(int((context.get("owner_audit", {}) as Dictionary).get("policy_errors", -1)), 0),
		assert_eq(int((quick_payload.get("review_subject", {}) as Dictionary).get("player_index", -1)), 0, "author mode quick review must stay on the human player"),
		assert_eq(
			str(((quick_payload.get("quick_review_context", {}) as Dictionary).get("evidence", {}) as Dictionary).get("visibility", "")),
			"public_allow_list_v1",
			"author public evidence must reach the quick-review request"
		),
	])
	if path != "":
		DirAccess.remove_absolute(path)
	return checks
