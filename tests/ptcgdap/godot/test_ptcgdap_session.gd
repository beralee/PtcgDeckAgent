class_name TestPtcgDAPSession
extends TestBase

const CabtContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const PtcgDAPSessionScript = preload("res://scripts/ai/ptcgdap/api/PtcgDAPSession.gd")
const FIXTURE_ROOT := "res://tests/ptcgdap/fixtures/public"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991


func _restore_fixture_integer_tokens(value: Variant) -> Variant:
	if value is Dictionary:
		var restored := {}
		for key: Variant in (value as Dictionary).keys():
			restored[key] = _restore_fixture_integer_tokens((value as Dictionary)[key])
		return restored
	if value is Array:
		var restored := []
		for child: Variant in value:
			restored.append(_restore_fixture_integer_tokens(child))
		return restored
	if typeof(value) == TYPE_FLOAT:
		var number := float(value)
		if (
			is_finite(number)
			and number == floorf(number)
			and number >= -float(MAX_SAFE_INTEGER)
			and number <= float(MAX_SAFE_INTEGER)
		):
			return int(number)
	return value


func _load_fixture(fixture_name: String) -> Dictionary:
	var file := FileAccess.open("%s/%s.json" % [FIXTURE_ROOT, fixture_name], FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return _restore_fixture_integer_tokens(parsed) if parsed is Dictionary else {}


func _make_session(session_id: String) -> Variant:
	var contracts: Variant = CabtContractSetScript.load_default()
	if contracts == null or not contracts.ok:
		return null
	return PtcgDAPSessionScript.new(session_id, contracts)


func _forged_session_contracts(real_contracts: Variant) -> Variant:
	var forged: Variant = CabtContractSetScript.new()
	forged.set("_ok", true)
	forged.set("_source_lock_id", real_contracts.get("source_lock_id"))
	forged.set("_source_contract_hash", real_contracts.get("source_contract_hash"))
	forged.set("_typed_profile", real_contracts.get("typed_profile"))
	forged.set("_enum_snapshot", real_contracts.get("enum_snapshot"))
	return forged


func _issue_codes(issues: Array) -> Dictionary:
	var result := {}
	for issue_value: Variant in issues:
		if issue_value is Dictionary:
			result[str((issue_value as Dictionary).get("code", ""))] = true
	return result


func test_select_null_is_the_only_reset_and_every_callback_invalidates_local_state() -> String:
	var session: Variant = _make_session("seat-0")
	if session == null:
		return "CABT session dependencies failed to load"
	var first: Variant = session.ingest(_load_fixture("initial_callback"))
	var first_binding: Variant = session.current_callback_binding_hash
	session.remember_callback_local("semantic_intent", {"id": "old-window"})
	var regular: Variant = session.ingest(_load_fixture("normal_single_select"))
	var regular_binding: Variant = session.current_callback_binding_hash
	session.remember_callback_local("old_ticket", 17)
	var second: Variant = session.ingest(_load_fixture("initial_callback"))
	return run_checks([
		assert_true(first.reset),
		assert_true(first.policy_eligible),
		assert_true(first_binding != null),
		assert_false(regular.reset),
		assert_eq(regular_binding == first_binding, false),
		assert_true(second.reset),
		assert_eq(session.episode_generation, 2),
		assert_eq(session.callback_generation, 0),
		assert_eq(session.callback_local_state, {}),
		assert_false(session.opaque_search_capability_present),
	])


func test_missing_select_never_masquerades_as_reset_and_revokes_old_authority() -> String:
	var session: Variant = _make_session("seat-0")
	if session == null:
		return "CABT session dependencies failed to load"
	session.ingest(_load_fixture("initial_callback"))
	var token_callback := _load_fixture("normal_single_select")
	token_callback["search_begin_input"] = "ephemeral-token"
	session.ingest(token_callback)
	session.remember_callback_local("old_ticket", {"index": 1})
	var generation: int = session.episode_generation
	var callback_generation: int = session.callback_generation
	var missing := _load_fixture("normal_single_select")
	missing.erase("select")
	var result: Variant = session.ingest(missing)
	return run_checks([
		assert_false(result.reset),
		assert_false(result.policy_eligible),
		assert_eq(result.envelope, null),
		assert_eq(session.episode_generation, generation),
		assert_eq(session.callback_generation, callback_generation),
		assert_eq(session.current_callback_binding_hash, null),
		assert_false(session.opaque_search_capability_present),
		assert_eq(session.callback_local_state, {}),
	])


func test_unknown_enum_updates_callback_binding_but_is_not_policy_eligible() -> String:
	var session: Variant = _make_session("seat-1")
	if session == null:
		return "CABT session dependencies failed to load"
	session.ingest(_load_fixture("initial_callback"))
	var result: Variant = session.ingest(_load_fixture("unknown_additive_and_enum"))
	var returned_issues: Array = result.issues
	returned_issues.clear()
	return run_checks([
		assert_not_null(result.envelope),
		assert_false(result.policy_eligible),
		assert_false(result.reset),
		assert_eq(result.envelope.raw_payload.get("select", {}).get("type"), 99),
		assert_true(_issue_codes(result.issues).has("unknown_enum_value")),
		assert_eq(session.callback_generation, 1),
	])


func test_sessions_are_isolated_and_callback_local_getter_is_not_an_alias() -> String:
	var seat_zero: Variant = _make_session("seat-0")
	var seat_one: Variant = _make_session("seat-1")
	if seat_zero == null or seat_one == null:
		return "CABT session dependencies failed to load"
	seat_zero.ingest(_load_fixture("initial_callback"))
	seat_one.ingest(_load_fixture("initial_callback"))
	seat_zero.remember_callback_local("only-seat-zero", {"targets": [1]})
	var returned: Dictionary = seat_zero.callback_local_state
	(returned.get("only-seat-zero", {}) as Dictionary).get("targets", []).append(2)
	var token_callback := _load_fixture("normal_single_select")
	token_callback["search_begin_input"] = "ephemeral-token"
	seat_one.ingest(token_callback)
	return run_checks([
		assert_eq(seat_zero.callback_local_state.get("only-seat-zero", {}).get("targets"), [1]),
		assert_false(seat_one.callback_local_state.has("only-seat-zero")),
		assert_false(seat_zero.opaque_search_capability_present),
		assert_true(seat_one.opaque_search_capability_present),
		assert_true(seat_zero.current_callback_binding_hash != seat_one.current_callback_binding_hash),
	])


func test_forged_or_mutated_contracts_never_create_or_preserve_session_authority() -> String:
	var real_contracts: Variant = CabtContractSetScript.load_default()
	if real_contracts == null or not real_contracts.ok:
		return "CABT contract set failed to load"
	var forged_session: Variant = PtcgDAPSessionScript.new(
		"forged-seat",
		_forged_session_contracts(real_contracts)
	)
	var forged_result: Variant = forged_session.ingest(_load_fixture("initial_callback"))

	var mutable_contracts: Variant = CabtContractSetScript.load_default()
	var session: Variant = PtcgDAPSessionScript.new("mutable-seat", mutable_contracts)
	var initial_result: Variant = session.ingest(_load_fixture("initial_callback"))
	if initial_result.envelope == null:
		return "session mutation control failed to establish initial authority"
	session.remember_callback_local("old-window", {"indexes": [0]})
	var mutated_profile: Dictionary = mutable_contracts.get("typed_profile")
	mutated_profile["forged_runtime_authority"] = true
	mutable_contracts.set("_typed_profile", mutated_profile)
	var remembered_after_tamper: bool = session.remember_callback_local(
		"forged-window",
		{"indexes": [1]}
	)
	var mutated_result: Variant = session.ingest(_load_fixture("normal_single_select"))
	return run_checks([
		assert_eq(forged_result.envelope, null),
		assert_false(forged_result.policy_eligible),
		assert_eq(forged_session.current_callback_binding_hash, null),
		assert_false(forged_session.remember_callback_local("forged", 1)),
		assert_false(remembered_after_tamper),
		assert_eq(mutated_result.envelope, null),
		assert_false(mutated_result.policy_eligible),
		assert_eq(session.current_callback_binding_hash, null),
		assert_eq(session.callback_local_state, {}),
		assert_false(session.opaque_search_capability_present),
	])
