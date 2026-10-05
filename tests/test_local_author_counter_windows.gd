extends "res://tests/test_author_strategy_interaction_contract_v2.gd"


class LocalCounterStrategy extends OfficialCounterWindowStrategy:
	var wanted_count := 1
	var wanted_target := "Bench"
	var waiting := false
	var invalid_count := false
	var invalid_target := false
	var sequential := true
	var offered_targets: Array = []

	func uses_external_decision_port() -> bool:
		return false

	func uses_sequential_interaction_windows() -> bool:
		return sequential

	func has_pending_external_decision() -> bool:
		return waiting

	func should_preserve_empty_interaction_selection(_step: Dictionary, _context: Dictionary = {}) -> bool:
		return true

	func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
		super.pick_interaction_items(items, step, context)
		var metadata := UcisInteractionCompiler.metadata_for_step(step)
		if waiting:
			return []
		if int(metadata.get("context_raw", -1)) == 40:
			if invalid_count:
				return [{"number": 99}]
			for item: Variant in items:
				if item is Dictionary and int(item.get("number", -1)) == wanted_count:
					return [item]
			return []
		offered_targets = items.duplicate()
		if invalid_target:
			return ["not-a-current-target"]
		for item: Variant in items:
			if item is PokemonSlot and item.get_pokemon_name() == wanted_target:
				return [item]
		return []


class CounterScene extends CounterDistributionStub:
	var finalized := false
	var aborted := false
	var failure_reason := ""
	var _pending_choice := "effect_interaction"

	func _finalize_counter_distribution() -> void:
		finalized = true

	func _reset_effect_interaction() -> void:
		aborted = true
		_pending_choice = ""
		_field_interaction_assignment_selected_source_index = -1

	func _runtime_log(_event: String, message: String) -> void:
		failure_reason = message


func _local_counter_fixture(strategy: LocalCounterStrategy) -> Dictionary:
	var resolver := ResolverScript.new()
	resolver.set_deck_strategy(strategy)
	var scene := CounterScene.new()
	var targets: Array = [_make_counter_target("Active"), _make_counter_target("Bench")]
	var step := {
		"id": "target_damage_counters", "ui_mode": "counter_distribution",
		"total_counters": 3, "target_items": targets,
		"max_assignments": 1, "max_assignments_per_target": 1, "allow_partial": true,
		"ucis_counter_count_window": {"ucis_context_name": "REMOVE_DAMAGE_COUNTER_COUNT"},
		"ucis_counter_target_window": {"ucis_context_name": "DAMAGE_COUNTER"},
	}
	return {"resolver": resolver, "scene": scene, "targets": targets, "step": step}


func test_local_counter_amounts_rebind_to_reordered_targets_and_finalize_once() -> String:
	var checks: Array[String] = []
	for amount: int in [1, 2, 3]:
		for reverse: bool in [false, true]:
			var strategy := LocalCounterStrategy.new()
			strategy.wanted_count = amount
			var f := _local_counter_fixture(strategy)
			var scene: CounterScene = f.scene
			checks.append(assert_true(f.resolver._resolve_counter_distribution_step(scene, f.step)))
			checks.append(assert_eq(scene._field_interaction_assignment_selected_source_index, amount))
			checks.append(assert_eq(scene._field_interaction_assignment_entries.size(), 0, "Count is not a target commit"))
			if reverse:
				f.targets.reverse()
			checks.append(assert_true(f.resolver._resolve_counter_distribution_step(scene, f.step)))
			checks.append(assert_eq(scene._field_interaction_assignment_entries, [{"target_index": 0 if reverse else 1, "amount": amount * 10}]))
			checks.append(assert_eq(strategy.windows.size(), 2))
			checks.append(assert_eq(strategy.windows[0].get("numbers"), [1, 2, 3]))
			checks.append(assert_eq(strategy.windows[0].get("select_context_raw"), 40))
			checks.append(assert_eq(strategy.windows[1].get("select_context_raw"), 13))
			checks.append(assert_true(f.resolver._resolve_counter_distribution_step(scene, f.step)))
			checks.append(assert_true(scene.finalized, "One assignment completes partial Munkidori movement"))
			checks.append(assert_eq(strategy.windows.size(), 2, "Completion cannot ask again or apply the amount twice"))
			scene.free()
	return run_checks(checks)


func test_local_counter_pending_count_and_target_resume_without_fallback() -> String:
	var strategy := LocalCounterStrategy.new()
	strategy.wanted_count = 2
	strategy.waiting = true
	var f := _local_counter_fixture(strategy)
	var scene: CounterScene = f.scene
	var checks: Array[String] = [
		assert_false(f.resolver._resolve_counter_distribution_step(scene, f.step)),
		assert_eq(scene._field_interaction_assignment_selected_source_index, -1),
		assert_eq(scene._field_interaction_assignment_entries.size(), 0),
	]
	strategy.waiting = false
	checks.append(assert_true(f.resolver._resolve_counter_distribution_step(scene, f.step)))
	checks.append(assert_eq(scene._field_interaction_assignment_selected_source_index, 2))
	strategy.waiting = true
	checks.append(assert_false(f.resolver._resolve_counter_distribution_step(scene, f.step)))
	checks.append(assert_eq(scene._field_interaction_assignment_entries.size(), 0))
	f.targets.reverse()
	strategy.waiting = false
	checks.append(assert_true(f.resolver._resolve_counter_distribution_step(scene, f.step)))
	checks.append(assert_eq(scene._field_interaction_assignment_entries, [{"target_index": 0, "amount": 20}]))
	checks.append(assert_false(scene.aborted))
	scene.free()
	return run_checks(checks)


func test_local_counter_invalid_number_or_target_fails_without_assignment() -> String:
	var checks: Array[String] = []
	for invalid: String in ["number", "empty-number", "target"]:
		var strategy := LocalCounterStrategy.new()
		strategy.invalid_count = invalid == "number"
		strategy.wanted_count = 99 if invalid == "empty-number" else 1
		strategy.invalid_target = invalid == "target"
		var f := _local_counter_fixture(strategy)
		var scene: CounterScene = f.scene
		f.resolver._resolve_counter_distribution_step(scene, f.step)
		if invalid == "target":
			f.resolver._resolve_counter_distribution_step(scene, f.step)
		checks.append(assert_true(scene.aborted, invalid))
		checks.append(assert_eq(scene._field_interaction_assignment_entries.size(), 0))
		checks.append(assert_true(scene.failure_reason.contains("cardinality_invalid") or scene.failure_reason.contains("rebind_failed")))
		scene.free()
	return run_checks(checks)


func test_local_counter_lost_target_and_reduced_remaining_reject_old_selection() -> String:
	var checks: Array[String] = []
	for change: String in ["target", "remaining"]:
		var strategy := LocalCounterStrategy.new()
		strategy.wanted_count = 2
		var f := _local_counter_fixture(strategy)
		var scene: CounterScene = f.scene
		f.resolver._resolve_counter_distribution_step(scene, f.step)
		if change == "target":
			(f.targets[1] as PokemonSlot).pokemon_stack.clear()
		else:
			f.step.total_counters = 1
		f.resolver._resolve_counter_distribution_step(scene, f.step)
		checks.append(assert_true(scene.aborted, change))
		checks.append(assert_eq(scene._field_interaction_assignment_entries.size(), 0))
		scene.free()
	return run_checks(checks)


func test_local_counter_limits_and_empty_targets_fail_closed() -> String:
	var checks: Array[String] = []
	for boundary: String in ["empty", "assignment-limit", "per-target-limit", "zero"]:
		var strategy := LocalCounterStrategy.new()
		var f := _local_counter_fixture(strategy)
		var scene: CounterScene = f.scene
		match boundary:
			"empty": f.targets.clear()
			"assignment-limit":
				f.step.allow_partial = false
				scene._field_interaction_assignment_entries = [{"target_index": 1, "amount": 10}]
			"per-target-limit":
				f.step.max_assignments = 0
				scene._field_interaction_assignment_entries = [{"target_index": 1, "amount": 10}]
				scene._field_interaction_assignment_selected_source_index = 1
			"zero": f.step.total_counters = 0
		var before := scene._field_interaction_assignment_entries.size()
		f.resolver._resolve_counter_distribution_step(scene, f.step)
		checks.append(assert_eq(scene._field_interaction_assignment_entries.size(), before))
		checks.append(assert_true(scene.finalized if boundary == "zero" else scene.aborted, boundary))
		if boundary == "per-target-limit":
			checks.append(assert_eq(strategy.offered_targets, [f.targets[0]]))
		scene.free()
	return run_checks(checks)


func test_local_counter_generic_distribution_keeps_fresh_one_counter_windows() -> String:
	var strategy := LocalCounterStrategy.new()
	var f := _local_counter_fixture(strategy)
	var scene: CounterScene = f.scene
	f.step.erase("ucis_counter_count_window")
	f.step.erase("ucis_counter_target_window")
	f.step.total_counters = 2
	f.step.max_assignments = 0
	f.step.max_assignments_per_target = 0
	var checks: Array[String] = []
	for remaining: int in [2, 1]:
		checks.append(assert_true(f.resolver._resolve_counter_distribution_step(scene, f.step)))
		checks.append(assert_eq(strategy.windows[-1].get("select_context_raw"), 14))
		checks.append(assert_eq(strategy.windows[-1].get("remain_damage_counter"), remaining))
	checks.append(assert_eq(scene._field_interaction_assignment_entries, [{"target_index": 1, "amount": 10}, {"target_index": 1, "amount": 10}]))
	checks.append(assert_true(f.resolver._resolve_counter_distribution_step(scene, f.step)))
	checks.append(assert_true(scene.finalized))
	checks.append(assert_eq(strategy.windows.size(), 2))
	scene.free()
	return run_checks(checks)


func test_local_counter_capability_opt_out_keeps_classic_allocator() -> String:
	var strategy := LocalCounterStrategy.new()
	strategy.sequential = false
	var f := _local_counter_fixture(strategy)
	var scene: CounterScene = f.scene
	var handled: bool = f.resolver._resolve_counter_distribution_step(scene, f.step)
	var checks: Array[String] = [
		assert_true(handled),
		assert_eq(strategy.windows.size(), 0),
		assert_eq(scene._field_interaction_assignment_entries.size(), 1),
		assert_eq(scene._field_interaction_assignment_entries[0].amount, 30),
	]
	scene.free()
	return run_checks(checks)
