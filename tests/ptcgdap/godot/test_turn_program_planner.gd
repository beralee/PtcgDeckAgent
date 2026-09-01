class_name TestTurnProgramPlanner
extends RefCounted

const PlannerScript = preload("res://scripts/ai/ptcgdap/public/TurnProgramPlanner.gd")
const JournalScript = preload("res://scripts/ai/ptcgdap/public/TurnProgramJournal.gd")
const CompetitiveScript = preload("res://scripts/ai/ptcgdap/public/CompetitivePolicyV2.gd")
const TransactionFixtureScript = preload(
	"res://tests/ptcgdap/godot/test_turn_transaction_planner.gd"
)
const VECTOR_PATH := "res://contracts/ptcgdap/turn_program_v1_conformance_vectors.json"


func test_python_gdscript_turn_program_conformance_vectors() -> String:
	var file := FileAccess.open(VECTOR_PATH, FileAccess.READ)
	if file == null:
		return "turn program conformance vectors are missing"
	var vectors: Variant = JSON.parse_string(file.get_as_text())
	if not vectors is Dictionary \
			or vectors.get("profile_id") != "ptcgdap-turn-program-conformance-v1":
		return "turn program conformance vectors are invalid"
	for case_value: Variant in vectors.get("cases", []):
		if not case_value is Dictionary:
			return "turn program conformance case is not an object"
		var result: Dictionary = PlannerScript.evaluate(
			case_value.get("frame"), case_value.get("request")
		)
		for key: Variant in case_value.get("expected", {}):
			if result.get(key) != case_value.get("expected", {}).get(key):
				return "turn program conformance mismatch for %s.%s: %s" % [
					case_value.get("case_id"), key, result,
				]
	return ""


func test_competitive_policy_shadow_audit_cannot_change_live_selection() -> String:
	var fixture: Variant = TransactionFixtureScript.new()
	var document: Dictionary = fixture.call("_document")
	var compiled: Dictionary = CompetitiveScript.compile_local_uid(
		document, ["M2_001", "PAL_185", "PAR_178"]
	)
	if not bool(compiled.get("accepted", false)):
		return "competitive policy shadow fixture rejected: %s" % compiled
	var frame: Dictionary = fixture.call("_frame", [
		fixture.call("_option", 0, "attack"),
		fixture.call("_option", 1, "play_trainer", "PAL_185"),
	], 3)
	var case := _first_case()
	var request: Dictionary = case.get("request", {}).duplicate(true)
	request["source"] = frame.get("source", {}).duplicate(true)
	var baseline: Dictionary = CompetitiveScript.decide(compiled.get("policy"), frame)
	var shadowed: Dictionary = CompetitiveScript.decide(
		compiled.get("policy"), frame, [], [], [], [], null, null, request,
		JournalScript.new("match-shadow", 0, "dev.marnie@5.15.0")
	)
	if not bool(baseline.get("accepted", false)) \
			or not bool(shadowed.get("accepted", false)):
		return "competitive policy shadow decision rejected: %s / %s" % [
			baseline, shadowed,
		]
	if baseline.get("selected_indexes") != shadowed.get("selected_indexes"):
		return "shadow planner changed live selection: %s / %s" % [baseline, shadowed]
	var shadow: Dictionary = shadowed.get("audit", {}).get("turn_program_shadow", {})
	if shadow.get("selected_program_id") != "complete-board-then-attack" \
			or bool(shadow.get("authoritative", true)):
		return "turn program shadow audit mismatch: %s" % shadow
	var invalid_request := request.duplicate(true)
	invalid_request["source"]["window_id"] = "A".repeat(64)
	var invalid_shadow: Dictionary = CompetitiveScript.decide(
		compiled.get("policy"), frame, [], [], [], [], null, null, invalid_request
	)
	var invalid_audit: Dictionary = invalid_shadow.get("audit", {}).get(
		"turn_program_shadow", {}
	)
	if not bool(invalid_shadow.get("accepted", false)) \
			or invalid_shadow.get("selected_indexes") != baseline.get("selected_indexes") \
			or bool(invalid_audit.get("accepted", true)) \
			or invalid_audit.get("error_code") != "turn_program_source_mismatch":
		return "invalid shadow request changed or failed the live decision: %s" % invalid_shadow
	return ""


func test_base_veto_private_input_and_source_binding_fail_closed() -> String:
	var case := _first_case()
	if case.is_empty():
		return "turn program conformance fixture missing"
	var request: Dictionary = case.get("request", {}).duplicate(true)
	request["base_proofs"][1]["base_vetoed"] = true
	var vetoed: Dictionary = PlannerScript.evaluate(case.get("frame"), request)
	if not bool(vetoed.get("accepted", false)) \
			or vetoed.get("selected_program_id") != "premature-attack":
		return "Base veto did not remain final: %s" % vetoed

	var private_frame: Dictionary = case.get("frame", {}).duplicate(true)
	private_frame["public_state"]["opponent"] = {"deck_order": [1, 2]}
	var private_result: Dictionary = PlannerScript.evaluate(
		private_frame, case.get("request")
	)
	if private_result.get("error_code") != "private_turn_program_input":
		return "private turn program input did not fail closed: %s" % private_result

	var mismatch_request: Dictionary = case.get("request", {}).duplicate(true)
	mismatch_request["source"]["window_id"] = "F".repeat(64)
	var mismatch: Dictionary = PlannerScript.evaluate(case.get("frame"), mismatch_request)
	if mismatch.get("error_code") != "turn_program_source_mismatch":
		return "turn program source mismatch did not fail closed: %s" % mismatch
	return ""


func test_journal_replans_and_persists_no_stale_authority() -> String:
	var case := _first_case()
	if case.is_empty():
		return "turn program conformance fixture missing"
	var journal: Variant = JournalScript.new("match-1", 0, "dev.marnie@5.15.0")
	var first: Dictionary = journal.advance(case.get("frame"), case.get("request"))
	if first.get("selected_program_id") != "complete-board-then-attack":
		return "journal did not select full turn program: %s" % first

	var second_frame: Dictionary = case.get("frame", {}).duplicate(true)
	second_frame["source"] = {
		"public_observation_hash": "E".repeat(64),
		"window_id": "F".repeat(64),
	}
	var second_request: Dictionary = case.get("request", {}).duplicate(true)
	second_request["source"] = second_frame["source"].duplicate(true)
	second_request["programs"][0]["public_outcome"] = _outcome({
		"prize_gain_milli": 2000,
		"attack_pressure_milli": 1000,
	})
	var second: Dictionary = journal.advance(second_frame, second_request)
	if second.get("selected_program_id") != "premature-attack" \
			or second.get("journal_event") != "replanned":
		return "journal reused stale value instead of replanning: %s" % second
	var snapshot_text := JSON.stringify(journal.snapshot())
	for forbidden: String in [
		"index", "score", "proof", "binding", "window", "observation_hash",
	]:
		if forbidden in snapshot_text:
			return "journal persisted stale authority field %s: %s" % [
				forbidden, snapshot_text,
			]
	if second.has("selected_indexes") \
			or bool(second.get("authoritative", true)) \
			or second.get("mode") != "shadow":
		return "turn program shadow acquired execution authority: %s" % second
	return ""


func _first_case() -> Dictionary:
	var file := FileAccess.open(VECTOR_PATH, FileAccess.READ)
	if file == null:
		return {}
	var vectors: Variant = JSON.parse_string(file.get_as_text())
	if not vectors is Dictionary or vectors.get("cases", []).is_empty():
		return {}
	return vectors.get("cases", [])[0]


func _outcome(updates: Dictionary) -> Dictionary:
	var value := {
		"final_prize_knockout": 0,
		"prize_gain_milli": 0,
		"board_development_milli": 0,
		"attack_pressure_milli": 0,
		"next_turn_continuity_milli": 0,
		"hand_quality_milli": 0,
		"disruption_milli": 0,
		"resource_preservation_milli": 0,
		"risk_milli": 0,
		"unresolved_debt_milli": 0,
	}
	value.merge(updates, true)
	return value
