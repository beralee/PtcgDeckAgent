class_name TestTurnProgramTransitionEvaluator
extends RefCounted

const EvaluatorScript = preload(
	"res://scripts/ai/ptcgdap/public/TurnProgramTransitionEvaluator.gd"
)


func test_public_roll_forward_and_resource_conflict_gate() -> String:
	var frame := _frame(5)
	var valid := _candidate("tx.complete-engine", [
		_step("evolve-engine", "evolution"),
		_step("move-damage", "damage_transfer", "none", "evolve-engine"),
		_step("attack", "attack", "attack", "move-damage"),
	], [_fact("evolve")], [_fact("attack", 180)])
	var result: Dictionary = EvaluatorScript.evaluate(frame, valid, 2)
	if not bool(result.get("accepted", false)) \
			or not bool(result.get("public_only", false)) \
			or bool(result.get("authoritative", true)) \
			or not bool(result.get("commit_safe", false)) \
			or result.get("executed_prefix_length") != 3 \
			or int(result.get("uncertainty_milli", 1000)) > 400:
		return "valid public transition was not commit-safe: %s" % result

	var invalid := _candidate("tx.double-supporter", [
		_step("research", "draw"),
		_step("iono", "disruption", "none", "research"),
		_step("attack", "attack", "attack", "iono"),
	], [_fact("play_trainer")], [_fact("attack", 180)])
	var conflict: Dictionary = EvaluatorScript.evaluate(frame, invalid, 2)
	if not bool(conflict.get("accepted", false)) \
			or conflict.get("resource_conflict_count") != 1 \
			or bool(conflict.get("commit_safe", true)):
		return "double supporter was not rejected by transition gate: %s" % conflict
	return ""


func test_unknown_current_trainer_fails_closed_and_stale_label_is_rejected() -> String:
	var frame := _frame(5)
	var candidate := _candidate("base.unknown-trainer", [
		_step("play-unknown", "search"),
	], [_fact("play_trainer")], [], "base_action")
	var result: Dictionary = EvaluatorScript.evaluate(frame, candidate, 1)
	if not bool(result.get("accepted", false)) \
			or int(result.get("uncertainty_milli", 0)) < 500 \
			or bool(result.get("commit_safe", true)):
		return "unknown trainer did not fail closed: %s" % result
	var stale: Dictionary = EvaluatorScript.label_outcome({
		"source": frame.get("source").duplicate(true),
		"program_id": "tx.evolve",
		"effect_kind": "evolution",
		"expected_delta_milli": 320,
	}, frame)
	if bool(stale.get("accepted", true)) \
			or stale.get("error_code") != "stale_transition_observation" \
			or bool(stale.get("promotion_eligible", true)):
		return "stale public transition label was accepted: %s" % stale
	return ""


func _frame(turn: int) -> Dictionary:
	return {
		"schema_version": 2,
		"profile_id": "ptcgdap-competitive-public-frame-v2",
		"sequence": turn,
		"seat": 0,
		"prompt_kind": "main",
		"source": {
			"public_observation_hash": "A".repeat(64),
			"window_id": "B".repeat(64),
		},
		"public_state": {
			"turn_number": turn,
			"self": {
				"active": [], "bench": [], "hand": [], "prizes_remaining": 4,
				"turn": {
					"manual_attachment_available": true,
					"retreat_available": true,
					"supporter_available": true,
				},
			},
			"opponent": {
				"active": [], "bench": [], "hand_count": 0, "prizes_remaining": 4,
			},
		},
		"options": [],
	}


func _step(
	step_id: String,
	effect_kind: String,
	terminal_kind: String = "none",
	previous: Variant = null,
) -> Dictionary:
	return {
		"step_id": step_id,
		"transaction_id": "develop-before-attack",
		"method_id": "complete-board",
		"depends_on": [] if previous == null else [previous],
		"terminal_kind": terminal_kind,
		"effect_kind": effect_kind,
	}


func _fact(kind: String, damage: Variant = null) -> Dictionary:
	return {
		"kind": kind,
		"projected_damage": damage,
		"projected_knockout": false,
		"target_remaining_hp": null,
		"target_prize_value": null,
	}


func _candidate(
	program_id: String,
	steps: Array,
	current_facts: Array,
	terminal_facts: Array,
	source_kind: String = "turn_transaction",
) -> Dictionary:
	return {
		"program_id": program_id,
		"goal_id": "complete-board",
		"route_id": program_id,
		"deadline_turns": 0,
		"priority": 7200,
		"source_kind": source_kind,
		"semantic_steps": steps,
		"current_step_id": steps[0].get("step_id"),
		"current_option_facts": current_facts,
		"terminal_option_facts": terminal_facts,
		"base_proof": {
			"admissible": true,
			"current_step_executable": true,
			"mandatory_preserved": true,
			"terminal_preserved": true,
			"base_vetoed": false,
		},
	}
