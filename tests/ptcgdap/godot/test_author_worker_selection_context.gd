extends TestBase

const Owner = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd")

class PublicOwner extends Owner:
	var public_turn := 6
	func _uses_competitive_policy_v2() -> bool: return true
	func _build_public_state() -> Dictionary:
		return {"turn_number": public_turn, "decision": {"selection": {
			"remaining_energy_cost": null, "remaining_damage_counters": null,
			"max_assignments": null, "max_assignments_per_target": null, "allow_partial": null}}}

class SemanticPolicy extends RefCounted:
	func select(frame: Dictionary) -> Dictionary:
		var selected := 0
		for index: int in frame.options.size():
			if frame.options[index].get("card_uid") == "wanted": selected = index
		return {"ok": true, "error_code": "", "selected_indexes": [selected],
			"selection_source": "restricted_ir_same_window",
			"public_observation_hash": frame.source.public_observation_hash,
			"window_id": frame.source.window_id}
	func audit_snapshot() -> Dictionary: return {}

func _poll(owner: RefCounted, options: Array, raw: Dictionary) -> Dictionary:
	var result: Dictionary = owner._poll_or_schedule_policy_worker("assignment_source", options, 1, 1, raw)
	var deadline := Time.get_ticks_msec() + 3000
	while not result.get("ready", false) and Time.get_ticks_msec() < deadline:
		await (Engine.get_main_loop() as SceneTree).process_frame
		result = owner._poll_or_schedule_policy_worker("assignment_source", options, 1, 1, raw)
	return result

func test_worker_accepts_six_counter_windows_and_rebinds_reordered_targets() -> String:
	var owner := PublicOwner.new()
	owner.set("_policy", SemanticPolicy.new())
	for remaining: int in range(6, 0, -1):
		var options: Array = [{"card_uid": "other", "remaining_damage_counters": remaining}, {"card_uid": "wanted", "remaining_damage_counters": remaining}]
		if remaining % 2 == 0: options.reverse()
		var result := await _poll(owner, options, {"type": 1, "context": 14, "remainDamageCounter": remaining})
		assert_true(result.get("ready", false))
		assert_true(result.get("response", {}).get("ok", false), "Fresh counter window rejected: " + str(result.get("response")))
		if result.get("response", {}).get("ok", false):
			assert_eq(options[result.response.selected_indexes[0]].card_uid, "wanted")
	assert_eq(owner.get("_policy_worker_stale_results"), 0)
	owner.close_match()
	return ""

func test_request_fingerprint_includes_identical_energy_and_assignment_limits() -> String:
	var owner := PublicOwner.new()
	var options: Array = [{"card_uid": "wanted", "remaining_damage_counters": 2}]
	var raw := {"type": 1, "context": 13, "remainEnergyCost": 2, "remainDamageCounter": 3, "max_assignments": 1, "max_assignments_per_target": 1, "allow_partial": true}
	var frame: Dictionary = owner._build_frame("assignment_source", options, 1, 1, raw)
	assert_eq(frame.public_state.decision.selection.remaining_damage_counters, 2, "Accepted counter progress overrides static effect metadata")
	assert_eq(owner._selection_request_fingerprint_from_frame(frame), owner._current_selection_request_fingerprint("assignment_source", options, 1, 1, raw))
	owner.close_match()
	return ""

func test_worker_still_rejects_changed_budget_target_order_or_public_turn() -> String:
	for change: String in ["budget", "order", "turn"]:
		var owner := PublicOwner.new()
		owner.set("_policy", SemanticPolicy.new())
		var options: Array = [{"card_uid": "other", "remaining_damage_counters": 6}, {"card_uid": "wanted", "remaining_damage_counters": 6}]
		var raw := {"type": 1, "context": 14, "remainDamageCounter": 6}
		owner._poll_or_schedule_policy_worker("assignment_source", options, 1, 1, raw)
		match change:
			"budget":
				raw.remainDamageCounter = 5
				for option: Dictionary in options: option.remaining_damage_counters = 5
			"order": options.reverse()
			"turn": owner.public_turn += 1
		var result := await _poll(owner, options, raw)
		assert_eq(result.get("response", {}).get("error_code"), "stale_policy_response", change)
		assert_eq(owner.get("_policy_worker_stale_results"), 1)
		owner.close_match()
	return ""
