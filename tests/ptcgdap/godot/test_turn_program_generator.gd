class_name TestTurnProgramGenerator
extends RefCounted

const GeneratorScript = preload(
	"res://scripts/ai/ptcgdap/public/TurnProgramGenerator.gd"
)
const PlannerScript = preload("res://scripts/ai/ptcgdap/public/TurnProgramPlanner.gd")
const ConditionedValueScript = preload(
	"res://scripts/ai/ptcgdap/public/StateConditionedTransactionValueV2.gd"
)
const CompetitiveScript = preload("res://scripts/ai/ptcgdap/public/CompetitivePolicyV2.gd")
const JournalScript = preload(
	"res://scripts/ai/ptcgdap/public/TurnTransactionJournal.gd"
)
const TransactionFixtureScript = preload(
	"res://tests/ptcgdap/godot/test_turn_transaction_planner.gd"
)
const VECTOR_PATH := (
	"res://contracts/ptcgdap/turn_program_generation_v1_conformance_vectors.json"
)


func test_python_gdscript_generation_conformance_vectors() -> String:
	var file := FileAccess.open(VECTOR_PATH, FileAccess.READ)
	if file == null:
		return "Turn Program generation conformance vectors are missing"
	var vectors: Variant = JSON.parse_string(file.get_as_text())
	if not vectors is Dictionary \
			or vectors.get("profile_id") \
			!= "ptcgdap-turn-program-generation-conformance-v1":
		return "Turn Program generation conformance vectors are invalid"
	for case_value: Variant in vectors.get("cases", []):
		var generated: Dictionary = GeneratorScript.generate(
			case_value.get("frame"),
			case_value.get("candidates"),
			int(case_value.get("max_programs", 8)),
		)
		var expected: Dictionary = case_value.get("expected", {})
		if not bool(generated.get("accepted", false)) \
				or generated.get("audit_hash") != expected.get("audit_hash") \
				or generated.get("candidate_count") != expected.get("candidate_count") \
				or generated.get("emitted_count") != expected.get("emitted_count"):
			return "generation conformance result mismatch for %s: %s" % [
				case_value.get("case_id"), generated,
			]
		var program_ids: Array = []
		for program_value: Variant in generated.get("request", {}).get("programs", []):
			program_ids.append(program_value.get("program_id"))
		if program_ids != expected.get("program_ids"):
			return "generation order mismatch for %s: %s" % [
				case_value.get("case_id"), program_ids,
			]
		var selected: Dictionary = PlannerScript.evaluate(
			case_value.get("frame"), generated.get("request")
		)
		for key: String in [
			"selected_program_id", "selected_current_step_id", "ranked_program_ids",
		]:
			if selected.get(key) != expected.get(key):
				return "generation selection mismatch for %s.%s: %s" % [
					case_value.get("case_id"), key, selected,
				]
	return ""


func test_generated_outcomes_rank_full_turn_and_keep_final_prize_terminal() -> String:
	var frame := _frame(5)
	var generated: Dictionary = GeneratorScript.generate(frame, _candidates(false))
	if not bool(generated.get("accepted", false)):
		return "Turn Program generation rejected: %s" % generated
	var selected: Dictionary = PlannerScript.evaluate(frame, generated.get("request"))
	if selected.get("selected_program_id") != "tx.complete-board-then-attack" \
			or selected.get("selected_current_step_id") != "evolve-two":
		return "full turn did not beat premature attack: %s" % selected
	var serialized := JSON.stringify(generated)
	if "selected_indexes" in serialized or "option_index" in serialized:
		return "generator leaked option index authority: %s" % generated

	var final_frame := _frame(5)
	final_frame["public_state"]["self"]["prizes_remaining"] = 1
	var final_generated: Dictionary = GeneratorScript.generate(
		final_frame, _candidates(true)
	)
	var final_selected: Dictionary = PlannerScript.evaluate(
		final_frame, final_generated.get("request")
	)
	if final_selected.get("selected_program_id") != "base.attack-now":
		return "final-prize current attack was delayed: %s" % final_selected
	return ""


func test_package_value_model_is_language_neutral_and_injected() -> String:
	var frame := _frame(5)
	var model: Dictionary = GeneratorScript.default_value_model()
	model["model_version"] = 9
	model["feature_weights_milli"] = {
		"prize_gain_milli": 0,
		"board_development_milli": 0,
		"attack_pressure_milli": 0,
		"next_turn_continuity_milli": 0,
		"hand_quality_milli": 0,
		"disruption_milli": 0,
		"resource_preservation_milli": 10000,
		"risk_milli": 0,
		"unresolved_debt_milli": 0,
	}
	var generated: Dictionary = GeneratorScript.generate(
		frame, _candidates(false), 8, model
	)
	var selected: Dictionary = PlannerScript.evaluate(frame, generated.get("request"))
	if not bool(generated.get("accepted", false)) \
			or generated.get("request", {}).get("value_model") != model \
			or selected.get("selected_program_id") != "base.attack-now" \
			or "deck_id" in JSON.stringify(generated) \
			or "source_deck_id" in JSON.stringify(generated):
		return "package value model injection mismatch: %s / %s" % [generated, selected]
	return ""


func test_automatic_competitive_shadow_does_not_change_live_selection() -> String:
	var fixture: Variant = TransactionFixtureScript.new()
	var compiled: Dictionary = CompetitiveScript.compile_local_uid(
		fixture.call("_document"), ["M2_001", "PAL_185", "PAR_178"]
	)
	if not bool(compiled.get("accepted", false)):
		return "transaction fixture compile failed: %s" % compiled
	var frame: Dictionary = fixture.call("_frame", [
		fixture.call("_option", 0, "attack"),
		fixture.call("_option", 1, "play_trainer", "PAL_185"),
		fixture.call("_option", 2, "play_trainer", "PAR_178"),
	], 3)
	frame["options"][0]["projected_damage"] = 160
	var baseline: Dictionary = CompetitiveScript.decide(
		compiled.get("policy"), frame, [], [], [], [], null,
		JournalScript.new("generator-baseline", 0, "test.package@1")
	)
	var shadowed: Dictionary = CompetitiveScript.decide(
		compiled.get("policy"), frame, [], [], [], [], null,
		JournalScript.new("generator-shadow", 0, "test.package@1"),
		null, null, true
	)
	if not bool(baseline.get("accepted", false)) or not bool(shadowed.get("accepted", false)):
		return "competitive auto shadow rejected: %s / %s" % [baseline, shadowed]
	if baseline.get("selected_indexes") != [1] \
			or baseline.get("selected_indexes") != shadowed.get("selected_indexes"):
		return "automatic shadow changed live selection: %s / %s" % [baseline, shadowed]
	var audit: Dictionary = shadowed.get("audit", {})
	if not bool(audit.get("turn_program_generation", {}).get("accepted", false)) \
			or audit.get("turn_program_shadow", {}).get("selected_program_id") \
			!= "tx.develop-before-attack.supporter-then-evolution" \
			or not bool(audit.get("turn_program_differential", {}).get(
				"current_step_matches_live", false
			)):
		return "automatic shadow audit mismatch: %s" % audit
	return ""


func test_automatic_shadow_includes_current_nonterminal_base_action() -> String:
	var fixture: Variant = TransactionFixtureScript.new()
	var document: Dictionary = fixture.call("_document")
	document["rules"].append({
		"rule_id": "fund-before-end",
		"goal_id": "core-online",
		"goal_stage": "fund",
		"channel": "tactical",
		"horizon": 0,
		"confidence_milli": 1000,
		"base_score": 500000,
		"when": [{
			"fact": "option.kind", "op": "eq",
			"value": "attach_energy", "card_uid": null,
		}],
		"score_terms": [],
	})
	var compiled: Dictionary = CompetitiveScript.compile_local_uid(
		document, ["M2_001", "PAL_185", "PAR_178", "SVI_003"]
	)
	if not bool(compiled.get("accepted", false)):
		return "nonterminal base fixture compile failed: %s" % compiled
	var frame: Dictionary = fixture.call("_frame", [
		fixture.call("_option", 0, "attach_energy", "SVI_003"),
		fixture.call("_option", 1, "end_turn"),
	], 3)
	var decision: Dictionary = CompetitiveScript.decide(
		compiled.get("policy"), frame, [], [], [], [], null, null,
		null, null, true
	)
	var shadow: Dictionary = decision.get("audit", {}).get("turn_program_shadow", {})
	if decision.get("selected_indexes") != [0] \
			or not str(shadow.get("selected_program_id", "")).begins_with(
				"base.attach_energy."
			) \
			or not bool(decision.get("audit", {}).get(
				"turn_program_differential", {}
			).get("current_step_matches_live", false)):
		return "nonterminal Base action missing from shadow: %s" % decision
	return ""


func test_canary_rebinds_only_fresh_commit_safe_transaction_step() -> String:
	var fixture: Variant = TransactionFixtureScript.new()
	var document: Dictionary = fixture.call("_document")
	document["rules"].append({
		"rule_id": "fixture-premature-attack",
		"goal_id": "core-online",
		"goal_stage": "execute",
		"channel": "tactical",
		"horizon": 0,
		"confidence_milli": 1000,
		"base_score": 900000,
		"when": [{
			"fact": "option.kind", "op": "eq", "value": "attack", "card_uid": null,
		}],
		"score_terms": [],
	})
	var compiled: Dictionary = CompetitiveScript.compile_local_uid(
		document, ["M2_001", "PAL_185", "PAR_178"]
	)
	if not bool(compiled.get("accepted", false)):
		return "canary fixture compile failed: %s" % compiled
	var attack: Dictionary = fixture.call("_option", 0, "attack")
	attack["projected_damage"] = 160
	var frame: Dictionary = fixture.call("_frame", [
		attack,
		fixture.call("_option", 1, "play_trainer", "PAL_185"),
		fixture.call("_option", 2, "play_trainer", "PAR_178"),
	], 3)
	var profile := {
		"profile_id": "ptcgdap-turn-program-canary-v1",
		"allowed_source_kinds": ["turn_transaction", "turn_route"],
		"allowed_current_effect_kinds": ["draw", "disruption", "evolution"],
		"max_uncertainty_milli": 400,
		"minimum_utility_margin": 1,
	}
	var baseline: Dictionary = CompetitiveScript.decide(
		compiled.get("policy"), frame
	)
	var canary: Dictionary = CompetitiveScript.decide(
		compiled.get("policy"), frame, [], [], [], [], null, null,
		null, null, true, profile
	)
	var gate: Dictionary = canary.get("audit", {}).get("turn_program_canary", {})
	if baseline.get("selected_indexes") != [0] \
			or canary.get("selected_indexes") != [1] \
			or not bool(gate.get("applied", false)) \
			or not bool(gate.get("authoritative", false)) \
			or gate.get("utility_source") != "turn_program_shadow_final" \
			or int(gate.get("minimum_utility_margin", 0)) != 1 \
			or int(gate.get("selected_utility", 0)) \
				< int(gate.get("live_utility", 0)) + 1 \
			or canary.get("audit", {}).get("owner_layer") != "turn_program_canary" \
			or bool(canary.get("audit", {}).get("stale_plan_has_authority", true)):
		return "fresh safe canary did not rebind current transaction step: %s / %s" % [
			baseline, canary,
		]
	return ""


func test_public_action_semantics_admits_known_supporter_without_deck_id() -> String:
	var fixture: Variant = TransactionFixtureScript.new()
	var document: Dictionary = fixture.call("_document")
	document["turn_transactions"] = []
	document["turn_routes"] = []
	document["rules"].append({
		"rule_id": "fixture-premature-attack",
		"goal_id": "core-online",
		"goal_stage": "execute",
		"channel": "tactical",
		"horizon": 0,
		"confidence_milli": 1000,
		"base_score": 900000,
		"when": [{
			"fact": "option.kind", "op": "eq", "value": "attack", "card_uid": null,
		}],
		"score_terms": [],
	})
	var compiled: Dictionary = CompetitiveScript.compile_local_uid(
		document, ["M2_001", "PAL_185", "PAR_178"]
	)
	if not bool(compiled.get("accepted", false)):
		return "semantic fixture compile failed: %s" % compiled
	var attack: Dictionary = fixture.call("_option", 0, "attack")
	attack["projected_damage"] = 0
	var frame: Dictionary = fixture.call("_frame", [
		attack, fixture.call("_option", 1, "play_trainer", "PAL_185"),
	], 3)
	var canary_profile := {
		"profile_id": "ptcgdap-turn-program-canary-v1",
		"allowed_source_kinds": ["base_action"],
		"allowed_current_effect_kinds": ["disruption"],
		"max_uncertainty_milli": 400,
		"minimum_utility_margin": 1,
	}
	var semantics := {
		"profile_id": "ptcgdap-turn-program-action-semantics-v1",
		"uid_effect_kinds": {"PAL_185": "disruption"},
		"uid_resource_claims": {"PAL_185": "supporter"},
	}
	var decision: Dictionary = CompetitiveScript.decide(
		compiled.get("policy"), frame, [], [], [], [], null, null,
		null, null, true, canary_profile, null, semantics
	)
	var gate: Dictionary = decision.get("audit", {}).get("turn_program_canary", {})
	if decision.get("selected_indexes") != [1] or not bool(gate.get("applied", false)):
		return "known public supporter was not admitted: %s" % decision
	var selected_program: Variant = gate.get("selected_program_id")
	var selected_row: Dictionary = {}
	for row_value: Variant in decision.get("audit", {}).get(
		"turn_program_generation", {}
	).get("candidate_audit", []):
		if row_value.get("program_id") == selected_program:
			selected_row = row_value
			break
	var step_audit: Array = selected_row.get("transition_evaluation", {}).get("step_audit", [])
	if step_audit.is_empty() or step_audit[0].get("effect_kind") != "disruption" \
			or step_audit[0].get("resource_claim") != "supporter" \
			or "deck_id" in str(decision.get("audit", {})):
		return "semantic proof missing or deck-coupled: %s" % decision
	var unavailable: Dictionary = frame.duplicate(true)
	unavailable["source"]["window_id"] = "D".repeat(64)
	unavailable["public_state"]["self"]["turn"]["supporter_available"] = false
	var blocked: Dictionary = CompetitiveScript.decide(
		compiled.get("policy"), unavailable, [], [], [], [], null, null,
		null, null, true, canary_profile, null, semantics
	)
	if blocked.get("selected_indexes") != [0] or blocked.get("audit", {}).get(
		"turn_program_canary", {}
	).get("reason") != "transition_not_commit_safe":
		return "spent supporter resource was not blocked: %s" % blocked
	var guarded_semantics: Dictionary = semantics.duplicate(true)
	guarded_semantics["uid_public_guards"] = {"PAL_185": {
		"mode": "any", "max_own_hand_count": 4,
		"min_opponent_hand_count": 5,
	}}
	var healthy_hand: Dictionary = frame.duplicate(true)
	healthy_hand["source"]["window_id"] = "E".repeat(64)
	healthy_hand["public_state"]["self"]["hand"] = []
	for offset: int in 6:
		healthy_hand["public_state"]["self"]["hand"].append({
			"serial": 10 + offset, "local_card_uid": "PAR_178",
		})
	healthy_hand["public_state"]["opponent"]["hand_count"] = 2
	var guarded: Dictionary = CompetitiveScript.decide(
		compiled.get("policy"), healthy_hand, [], [], [], [], null, null,
		null, null, true, canary_profile, null, guarded_semantics
	)
	if guarded.get("selected_indexes") != [0] or guarded.get("audit", {}).get(
		"turn_program_canary", {}
	).get("reason") != "public_precondition_not_met":
		return "public hand guard did not block harmful reset: %s" % guarded
	return ""


func test_public_active_prize_value_proves_current_final_knockout() -> String:
	var fixture: Variant = TransactionFixtureScript.new()
	var document: Dictionary = fixture.call("_document")
	document["rules"].append({
		"rule_id": "prefer-attachment-fixture",
		"goal_id": "core-online",
		"goal_stage": "fund",
		"channel": "tactical",
		"horizon": 0,
		"confidence_milli": 1000,
		"base_score": 500000,
		"when": [{
			"fact": "option.kind", "op": "eq",
			"value": "attach_energy", "card_uid": null,
		}],
		"score_terms": [],
	})
	var compiled: Dictionary = CompetitiveScript.compile_local_uid(
		document, ["M2_001", "PAL_185", "PAR_178", "SVI_003"]
	)
	if not bool(compiled.get("accepted", false)):
		return "final knockout fixture compile failed: %s" % compiled
	var attack: Dictionary = fixture.call("_option", 0, "attack")
	attack["projected_damage"] = 320
	attack["projected_knockout"] = true
	var frame: Dictionary = fixture.call("_frame", [
		attack,
		fixture.call("_option", 1, "attach_energy", "SVI_003"),
	], 3)
	frame["public_state"]["self"]["prizes_remaining"] = 2
	frame["public_state"]["opponent"]["active"] = [{
		"serial": 77,
		"local_card_uid": "M2_001",
		"remaining_hp": 200,
		"prize_value": 2,
		"attached_energy_count": 0,
		"attached_energy_uids": [],
		"minimum_attack_energy_count": 0,
		"attack_ready": true,
		"energy_debt": 0,
	}]
	var decision: Dictionary = CompetitiveScript.decide(
		compiled.get("policy"), frame, [], [], [], [], null, null,
		null, null, true
	)
	var shadow: Dictionary = decision.get("audit", {}).get("turn_program_shadow", {})
	if not str(shadow.get("selected_program_id", "")).begins_with("base.attack."):
		return "public active prize did not protect final attack: %s" % decision
	var final_channel := 0
	for program_value: Variant in decision.get("audit", {}).get(
			"turn_program_generation", {}
		).get("request", {}).get("programs", []):
		if program_value.get("program_id") == shadow.get("selected_program_id"):
			final_channel = int(program_value.get("public_outcome", {}).get(
				"final_prize_knockout", 0
			))
	if final_channel != 1:
		return "final knockout hard channel was not proven: %s" % decision
	return ""


func test_state_conditioned_value_matches_python_rank_flip() -> String:
	var model: Dictionary = ConditionedValueScript.default_model({}, "exam-state-value-v2")
	for key: Variant in model.get("fallback_value_model", {}).get(
		"feature_weights_milli", {}
	):
		model["fallback_value_model"]["feature_weights_milli"][key] = 0
	model["action_value_weights_milli"] = {"outcome.attack_pressure_milli": 1200}
	model["interaction_weights_milli"] = {
		"self.hand.shortage_milli::outcome.disruption_milli": 9000,
		"self.hand.abundance_milli::outcome.disruption_milli": -9000,
		"opponent.hand.excess_milli::outcome.disruption_milli": 6000,
		"opponent.hand.shortage_milli::outcome.disruption_milli": -6000,
	}
	var attack := _fact("attack", 180, false, 1, 100)
	var candidates := [
		_candidate("base.attack-now", [
			_step("attack-now", "attack", "attack"),
		], [attack], [attack], 1000, "base_terminal"),
		_candidate("tx.disrupt-then-attack", [
			_step("disrupt-hand", "disruption"),
			_step("attack-after-disruption", "attack", "attack", "disrupt-hand"),
		], [_fact("play_trainer")], [attack], 1000, "turn_transaction"),
	]
	var low := _conditioned_frame(1, 8)
	var rich := _conditioned_frame(8, 2)
	var low_generated: Dictionary = GeneratorScript.generate(low, candidates, 8, model)
	var rich_generated: Dictionary = GeneratorScript.generate(rich, candidates, 8, model)
	if not bool(low_generated.get("accepted", false)) \
			or not bool(rich_generated.get("accepted", false)):
		return "state-conditioned generator rejected: %s / %s" % [low_generated, rich_generated]
	var low_result: Dictionary = PlannerScript.evaluate(low, low_generated.get("request"))
	var rich_result: Dictionary = PlannerScript.evaluate(rich, rich_generated.get("request"))
	if low_result.get("selected_program_id") != "tx.disrupt-then-attack" \
			or rich_result.get("selected_program_id") != "base.attack-now":
		return "complete public state did not flip the ranking: %s / %s" % [low_result, rich_result]
	var low_values := {}
	for row_value: Variant in low_generated.get("candidate_audit", []):
		low_values[row_value.get("program_id")] = row_value.get("utility")
	var rich_values := {}
	for row_value: Variant in rich_generated.get("candidate_audit", []):
		rich_values[row_value.get("program_id")] = row_value.get("utility")
	if low_values != {"base.attack-now": 864000, "tx.disrupt-then-attack": 9048000} \
			or rich_values != {"base.attack-now": 864000, "tx.disrupt-then-attack": -4344000}:
		return "Python/GDScript integer score mismatch: %s / %s" % [low_values, rich_values]
	if "deck_id" in JSON.stringify([low_generated, rich_generated]):
		return "conditioned value leaked deck identity"
	return ""


func test_generator_and_final_planner_share_exact_conditioned_utility() -> String:
	var model: Dictionary = ConditionedValueScript.default_model(
		{}, "generator-planner-single-score-exam"
	)
	for key: Variant in model.get("fallback_value_model", {}).get(
			"feature_weights_milli", {}
	):
		model["fallback_value_model"]["feature_weights_milli"][key] = 0
	model["action_value_weights_milli"] = {
		"program.current_effect.attack_milli": -500,
		"program.current_effect.disruption_milli": 1200,
		"program.current_effect.evolution_milli": 800,
	}
	var attack := _fact("attack", 180, false, 1, 100)
	var candidates := [
		_candidate("base.attack-now", [
			_step("attack-now", "attack", "attack"),
		], [attack], [attack], 1000, "base_terminal"),
		_candidate("tx.complete-board-then-attack", [
			_step("evolve-two", "evolution"),
			_step("disrupt-hand", "disruption", "none", "evolve-two"),
			_step("attack-after-debt", "attack", "attack", "disrupt-hand"),
		], [_fact("evolve")], [attack], 7300, "turn_transaction"),
	]
	var frame := _conditioned_frame(4, 4)
	var generated: Dictionary = GeneratorScript.generate(frame, candidates, 8, model)
	if not bool(generated.get("accepted", false)):
		return "conditioned generator rejected single-score exam: %s" % generated
	var final: Dictionary = PlannerScript.evaluate(frame, generated.get("request"))
	if not bool(final.get("accepted", false)):
		return "conditioned planner rejected single-score exam: %s" % final
	var generated_values := {}
	for row_value: Variant in generated.get("candidate_audit", []):
		if bool(row_value.get("emitted", false)):
			generated_values[row_value.get("program_id")] = [
				row_value.get("utility"),
				row_value.get("conditioned_value", {}).get("action_feature_hash"),
			]
	var final_values := {}
	for row_value: Variant in final.get("candidate_audit", []):
		final_values[row_value.get("program_id")] = [
			row_value.get("utility_milli"),
			row_value.get("conditioned_value", {}).get("action_feature_hash"),
		]
	if generated_values != final_values:
		return "generator/planner conditioned utility split: %s / %s" % [
			generated_values, final_values,
		]
	if int(generated_values.get("tx.complete-board-then-attack", [0])[0]) \
			<= int(generated_values.get("base.attack-now", [0])[0]):
		return "conditioned action context did not affect generator rank: %s" % generated_values
	return ""


func _conditioned_frame(own_hand_count: int, opponent_hand_count: int) -> Dictionary:
	var result := _frame(5)
	var hand: Array = []
	for index: int in own_hand_count:
		hand.append({"serial": index + 1, "local_card_uid": "SVE_007"})
	result["public_state"]["self"].merge({
		"hand": hand, "active": [], "bench": [], "discard": [], "deck_count": 30,
		"turn": {
			"supporter_available": true, "manual_attachment_available": true,
			"retreat_available": true,
		},
	})
	result["public_state"]["opponent"].merge({
		"hand_count": opponent_hand_count, "active": [], "bench": [], "discard": [],
		"deck_count": 28,
	})
	return result


func _frame(turn: int) -> Dictionary:
	return {
		"schema_version": 2,
		"profile_id": "ptcgdap-competitive-public-frame-v2",
		"sequence": turn,
		"seat": 0,
		"prompt_kind": "main",
		"source": {
			"public_observation_hash": ("A" if turn == 5 else "C").repeat(64),
			"window_id": ("B" if turn == 5 else "D").repeat(64),
		},
		"public_state": {
			"turn_number": turn,
			"self": {"prizes_remaining": 4},
			"opponent": {"prizes_remaining": 4},
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


func _fact(
	kind: String,
	damage: Variant = null,
	knockout: bool = false,
	prize_value: Variant = null,
	remaining_hp: Variant = null,
) -> Dictionary:
	return {
		"kind": kind,
		"projected_damage": damage,
		"projected_knockout": knockout,
		"target_remaining_hp": remaining_hp,
		"target_prize_value": prize_value,
	}


func _candidate(
	program_id: String,
	steps: Array,
	current_facts: Array,
	terminal_facts: Array,
	priority: int,
	source_kind: String,
) -> Dictionary:
	return {
		"program_id": program_id,
		"goal_id": "complete-board",
		"route_id": program_id,
		"deadline_turns": 0,
		"priority": priority,
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


func _candidates(final_prize: bool) -> Array:
	var attack := _fact("attack", 180, final_prize, 1, 100)
	return [
		_candidate("base.attack-now", [
			{
				"step_id": "attack-now",
				"transaction_id": "base-terminal",
				"method_id": "current-attack",
				"depends_on": [],
				"terminal_kind": "attack",
				"effect_kind": "attack",
			},
		], [attack], [attack], 0, "base_terminal"),
		_candidate("route.optional-draw", [
			_step("draw-more", "draw"),
			_step("attack-after-draw", "attack", "attack", "draw-more"),
		], [_fact("play_trainer")], [attack], 500, "turn_route"),
		_candidate("tx.complete-board-then-attack", [
			_step("evolve-two", "evolution"),
			_step("fill-board-energy", "energy", "none", "evolve-two"),
			_step("move-damage", "damage_transfer", "none", "fill-board-energy"),
			_step("disrupt-hand", "disruption", "none", "move-damage"),
			_step("attack-after-debt", "attack", "attack", "disrupt-hand"),
		], [_fact("evolve")], [attack], 7300, "turn_transaction"),
	]
