class_name TestDamagePlanningAvailability
extends TestBase

const Policy = preload("res://scripts/ai/ptcgdap/public/CompetitivePolicyV2.gd")
const Planning = preload("res://scripts/ai/ptcgdap/public/PublicDamagePlanning.gd")
const Journal = preload("res://scripts/ai/ptcgdap/public/SemanticTransactionJournal.gd")
const Firewall = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")
# Negative controls must stay unknown when the bundled catalog grows.
const UNKNOWN_UIDS := ["UNREGISTERED_001", "UNREGISTERED_002", "UNREGISTERED_003"]

func _spec() -> Dictionary:
	return Firewall._parse_contract_json_bytes(FileAccess.get_file_as_bytes(
		"res://tests/fixtures/author_damage_catalog_gap.json"
	)).get("value", {})

func test_catalog_gap_keeps_independent_rules_and_base_authority() -> String:
	var spec := _spec()
	var compiled := Policy.compile_local_uid(spec.policy, spec.allowed_card_uids)
	if not compiled.accepted: return "compile: " + str(compiled)
	var checks: Array[String] = []
	for side: String in ["self", "opponent"]:
		for uid: String in UNKNOWN_UIDS:
			var frame: Dictionary = spec.frame.duplicate(true)
			frame.public_state[side].bench[0].local_card_uid = uid
			var decision := Policy.decide(compiled.policy, frame)
			if not decision.accepted: return "catalog gap aborted legal decision: " + str(decision)
			checks.append(assert_eq(decision.selected_indexes, [0]))
			checks.append(assert_eq(decision.audit.damage_plan.status, "unavailable"))
			checks.append(assert_eq(decision.audit.damage_plan.error_code, "unknown_damage_card_uid"))
			checks.append(assert_eq(decision.audit.damage_plan.facts, {}))
			var matched: Array = []
			for card: Dictionary in decision.audit.scorecards:
				for rule: Dictionary in card.matched_rules: matched.append(rule.rule_id)
			checks.append(assert_true("independent-attack" in matched))
			checks.append(assert_false("unknown-ne-must-not-match" in matched))
			checks.append(assert_false("unknown-score-must-not-match" in matched))
			checks.append(assert_eq(Policy.decide(compiled.policy, frame, [1]).selected_indexes, [1]))
			checks.append(assert_eq(Policy.decide(compiled.policy, frame, [], [1]).selected_indexes, [1]))
			checks.append(assert_eq(Policy.decide(compiled.policy, frame, [], [], [], [0]).selected_indexes, [1]))
			frame.options.reverse()
			for index: int in frame.options.size(): frame.options[index].index = index
			checks.append(assert_eq(Policy.decide(compiled.policy, frame).selected_indexes, [1]))
	return run_checks(checks)

func test_unavailable_damage_revokes_old_transaction_and_recovers() -> String:
	var spec := _spec()
	var compiled := Policy.compile_local_uid(spec.policy, spec.allowed_card_uids)
	if not compiled.accepted: return "compile: " + str(compiled)
	var journal := Journal.new("availability", 0, "package")
	var known := Policy.decide(compiled.policy, spec.frame, [], [], [], [], journal)
	if not known.accepted or journal.snapshot().is_empty(): return "known plan never started"
	var frame: Dictionary = spec.frame.duplicate(true)
	frame.public_state.opponent.bench[0].local_card_uid = UNKNOWN_UIDS[0]
	var unknown := Policy.decide(compiled.policy, frame, [], [], [], [], journal)
	if not unknown.accepted: return "unknown plan aborted policy: " + str(unknown)
	var checks: Array[String] = [
		assert_eq(unknown.audit.semantic_transaction.event, "abort"),
		assert_eq(unknown.audit.semantic_transaction.reason, "unknown_damage_card_uid"),
		assert_eq(unknown.audit.semantic_transaction.state, {}),
		assert_eq(journal.snapshot(), {}),
	]
	var recovered := Policy.decide(compiled.policy, spec.frame, [], [], [], [], journal)
	checks.append(assert_true(recovered.accepted))
	checks.append(assert_eq(recovered.audit.semantic_transaction.event, "start"))
	return run_checks(checks)

func test_damage_and_private_input_guards_still_fail_closed() -> String:
	var spec := _spec()
	var frame: Dictionary = spec.frame.duplicate(true)
	frame.public_state.opponent.bench[0].local_card_uid = UNKNOWN_UIDS[0]
	var damage := Planning.calculate(frame, spec.policy.damage_plans)
	var compiled := Policy.compile_local_uid(spec.policy, spec.allowed_card_uids)
	frame["private_state"] = {"deck_order": ["SECRET_001"]}
	return run_checks([
		assert_false(damage.accepted),
		assert_eq(damage.error_code, "unknown_damage_card_uid"),
		assert_false(Policy.decide(compiled.policy, frame).accepted),
	])


func test_catalog_gap_in_either_active_or_bench_keeps_hard_tier_guard() -> String:
	var spec := _spec()
	var compiled := Policy.compile_local_uid(spec.policy, spec.allowed_card_uids)
	if not compiled.accepted: return "compile: " + str(compiled)
	var checks: Array[String] = []
	for side: String in ["self", "opponent"]:
		for zone: String in ["active", "bench"]:
			for uid: String in UNKNOWN_UIDS:
				var frame: Dictionary = spec.frame.duplicate(true)
				frame.public_state[side][zone][0].local_card_uid = uid
				var decision := Policy.decide(compiled.policy, frame)
				checks.append(assert_true(decision.accepted, "%s/%s/%s: %s" % [side, zone, uid, decision.error_code]))
				checks.append(assert_eq(decision.selected_indexes, [0]))
				var guarded := Policy.decide(compiled.policy, frame, [], [], [{"index": 0, "tier": [1]}, {"index": 1, "tier": [0]}])
				checks.append(assert_true(guarded.accepted))
				checks.append(assert_eq(guarded.selected_indexes, [1], "Independent preference cannot override Base tier"))
	return run_checks(checks)


func test_registered_printings_keep_damage_planning_available() -> String:
	var spec := _spec()
	var compiled := Policy.compile_local_uid(spec.policy, spec.allowed_card_uids)
	if not compiled.accepted: return "compile: " + str(compiled)
	var checks: Array[String] = []
	for side: String in ["self", "opponent"]:
		for zone: String in ["active", "bench"]:
			for uid: String in ["CSV6C_067", "CSV6C_097"]:
				var frame: Dictionary = spec.frame.duplicate(true)
				frame.public_state[side][zone][0].local_card_uid = uid
				var damage := Planning.calculate(frame, spec.policy.damage_plans)
				checks.append(assert_true(damage.accepted, "%s/%s/%s: %s" % [side, zone, uid, damage.error_code]))
				var decision := Policy.decide(compiled.policy, frame)
				checks.append(assert_true(decision.accepted))
				checks.append(assert_false(decision.audit.damage_plan.facts.is_empty()))
	return run_checks(checks)
