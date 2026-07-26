class_name TestDeckTrainingPuzzlePipeline
extends TestBase


const PipelineScript := preload("res://scripts/training/pipeline/DeckTrainingPuzzlePipeline.gd")
const CatalogScript := preload("res://scripts/training/DeckTrainingCatalog.gd")
const THEORY_PATH := "res://data/deck_training/deck_theory.json"

var _cached_report: Dictionary = {}


func test_target_manifest_pins_all_seven_frozen_decks_and_production_strategies() -> String:
	var report := _report()
	var expected := {
		"dragapult": [800018506, "dragapult_dusknoir"],
		"gardevoir": [800018498, "v18_800018498_academy_gardevoir"],
		"gholdengo": [800016834, "v18_800016834_pure_gholdengo"],
		"raging_bolt": [800018509, "v18_800018509_raging_bolt_ogerpon"],
		"marnie": [800018501, "v18_800018501_marnies_grimmsnarl"],
		"n_zoroark": [800018502, "v18_800018502_ns_zoroark"],
		"charizard_dragapult": [800025404, "v17_bomb_charizard"],
	}
	var checks: Array[String] = [
		assert_true(bool(report.get("ok", false)), "Pipeline should accept the production manifests"),
		assert_eq((report.get("targets", []) as Array).size(), 7, "Pipeline should cover all seven target decks"),
	]
	for target_variant: Variant in report.get("targets", []):
		var target: Dictionary = target_variant
		var deck_key := str(target.get("deck_key", ""))
		checks.append(assert_true(expected.has(deck_key), "Unexpected target deck: %s" % deck_key))
		if not expected.has(deck_key):
			continue
		var pinned: Array = expected[deck_key]
		checks.append(assert_eq(int(target.get("deck_id", 0)), int(pinned[0]), "%s should keep its frozen deck id" % deck_key))
		checks.append(assert_eq(str(target.get("strategy_id", "")), str(pinned[1]), "%s should use the production registry strategy" % deck_key))
		checks.append(assert_eq(int(target.get("deck_card_count", 0)), 60, "%s should remain a legal 60-card deck" % deck_key))
		checks.append(assert_eq(int(target.get("candidate_count", 0)), 10, "%s should own ten curriculum candidates" % deck_key))
		checks.append(assert_eq(int(target.get("curriculum_axis_count", 0)), 10, "%s should own ten distinct curriculum axes" % deck_key))
		checks.append(assert_true(bool(target.get("tactic_scan_ok", false)), "%s tactic scan should pass" % deck_key))
		checks.append(assert_true(int(target.get("tactic_recipe_count", 0)) >= 3, "%s should expose at least three verified tactics" % deck_key))
		checks.append(assert_true(bool(target.get("ok", false)), "%s identity audit should pass" % deck_key))
	return run_checks(checks)


func test_deck_theory_defines_ten_order_sensitive_combo_lessons_per_deck() -> String:
	var json := JSON.new()
	var parse_error := json.parse(FileAccess.get_file_as_string(THEORY_PATH))
	if parse_error != OK or not (json.data is Dictionary):
		return "Deck theory should be valid JSON: %s" % json.get_error_message()
	var theory: Dictionary = json.data
	var decks: Dictionary = theory.get("decks", {})
	var checks: Array[String] = [
		assert_eq(decks.size(), 7, "Deck theory should cover all seven frozen decks"),
	]
	for deck_key: String in decks:
		var deck: Dictionary = decks[deck_key]
		var lessons: Array = deck.get("lessons", [])
		var ids: Dictionary = {}
		checks.append(assert_false(str(deck.get("identity", "")).is_empty(), "%s needs a deck-owned identity" % deck_key))
		checks.append(assert_false((deck.get("damage_equations", []) as Array).is_empty(), "%s needs exact damage equations" % deck_key))
		checks.append(assert_false((deck.get("resource_bottlenecks", []) as Array).is_empty(), "%s needs resource bottlenecks" % deck_key))
		checks.append(assert_eq(lessons.size(), 10, "%s should define exactly ten lessons" % deck_key))
		for lesson_variant: Variant in lessons:
			var lesson: Dictionary = lesson_variant
			var lesson_id := str(lesson.get("id", ""))
			checks.append(assert_false(lesson_id.is_empty(), "%s lesson needs an id" % deck_key))
			checks.append(assert_false(ids.has(lesson_id), "%s lesson ids must be unique" % deck_key))
			ids[lesson_id] = true
			checks.append(assert_false((lesson.get("prerequisites", []) as Array).is_empty(), "%s/%s needs prerequisites" % [deck_key, lesson_id]))
			checks.append(assert_true((lesson.get("ordered_steps", []) as Array).size() >= 3, "%s/%s needs at least three ordered steps" % [deck_key, lesson_id]))
			checks.append(assert_false(str(lesson.get("payoff", "")).is_empty(), "%s/%s needs an exact payoff" % [deck_key, lesson_id]))
			checks.append(assert_false(str(lesson.get("reordered_failure", "")).is_empty(), "%s/%s needs a reordered failure" % [deck_key, lesson_id]))
	return run_checks(checks)


func test_pipeline_promotes_only_proven_and_shortcut_audited_puzzles() -> String:
	var report := _report()
	var summary: Dictionary = report.get("summary", {})
	var release_ids: Array[String] = []
	var checks: Array[String] = [
		assert_eq(int(summary.get("candidate_count", 0)), 70, "Seven decks should produce a 70-candidate backlog"),
		assert_eq(int(summary.get("compiled", 0)), 70, "Every authored candidate should compile into production state"),
		assert_eq(int(summary.get("playable", 0)), 70, "Every candidate should expose a production legal opening"),
		assert_eq(int(summary.get("proven", 0)), 70, "Every current curriculum puzzle should have a production-engine proof"),
		assert_eq(int(summary.get("shortcut_audited", 0)), 70, "Every current curriculum puzzle should pass shortcut audit"),
		assert_eq(int(summary.get("release_ready", 0)), 70, "Release gate must require both positive proof and negative probes"),
		assert_eq(int(summary.get("tactic_targets_passed", 0)), 7, "All seven decks should pass tactic scanning"),
		assert_eq(int(summary.get("tactic_recipe_count", 0)), 22, "The tactic catalog should contain the verified deck-specific recipes"),
		assert_true(int(summary.get("tech_candidate_count", 0)) > 0, "Semantic scanning should find singleton tech candidates"),
	]
	for candidate_variant: Variant in report.get("candidates", []):
		var candidate: Dictionary = candidate_variant
		if str(candidate.get("status", "")) != PipelineScript.STATUS_RELEASE_READY:
			continue
		var scenario_id := str(candidate.get("scenario_id", ""))
		release_ids.append(scenario_id)
		var probes: Array = candidate.get("shortcut_probes", [])
		checks.append(assert_true(probes.size() >= 2, "%s should have at least two shortcut probes" % scenario_id))
		for probe_variant: Variant in probes:
			var probe: Dictionary = probe_variant
			checks.append(assert_true(bool(probe.get("ok", false)), "%s/%s should be a clean refutation" % [scenario_id, str(probe.get("id", ""))]))
			checks.append(assert_eq(str(probe.get("status", "")), "REFUTED", "%s/%s should fail by game outcome" % [scenario_id, str(probe.get("id", ""))]))
	release_ids.sort()
	var expected_release_ids: Array[String] = []
	for scenario: Dictionary in CatalogScript.list_scenarios():
		expected_release_ids.append(str(scenario.get("id", "")))
	expected_release_ids.sort()
	checks.append(assert_eq(release_ids, expected_release_ids, "No unproven puzzle may leak into the release set"))
	return run_checks(checks)


func test_backlog_assigns_every_candidate_a_deck_specific_curriculum_gate() -> String:
	var backlog: Array = _report().get("backlog", [])
	var checks: Array[String] = [assert_eq(backlog.size(), 70, "Backlog should contain one row per candidate")]
	var tactic_slot_count := 0
	for entry_variant: Variant in backlog:
		var entry: Dictionary = entry_variant
		checks.append(assert_false(str(entry.get("curriculum_axis_id", "")).is_empty(), "%s needs a curriculum axis" % str(entry.get("scenario_id", ""))))
		checks.append(assert_false(str(entry.get("next_gate", "")).is_empty(), "%s needs an explicit next gate" % str(entry.get("scenario_id", ""))))
		if bool(entry.get("tactic_required", false)):
			tactic_slot_count += 1
			checks.append(assert_eq(str(entry.get("tactic_dimension_id", "")), "tech_combo_application", "Tactic slots should expose the dedicated design dimension"))
			checks.append(assert_false((entry.get("suggested_tactic_ids", []) as Array).is_empty(), "Tactic slots should receive verified recipe suggestions"))
			var encoded_patterns: Array = entry.get("encoded_tactic_pattern_ids", [])
			var expected_gate := "encode_and_prove_verified_tactic_application"
			if str(entry.get("current_status", "")) == PipelineScript.STATUS_RELEASE_READY:
				expected_gate = "published_candidate"
			elif not encoded_patterns.is_empty():
				expected_gate = "generate_and_validate_positive_proof"
			checks.append(assert_eq(str(entry.get("next_gate", "")), expected_gate, "Tactic slots should advance only after a verified pattern is encoded"))
	checks.append(assert_eq(tactic_slot_count, 14, "Each of seven decks should reserve two tactic-application candidates"))
	return run_checks(checks)


func test_raging_bolt_scan_captures_slither_wing_pikachu_counter() -> String:
	var tactics: Dictionary = _report().get("tactics", {})
	var raging: Dictionary = {}
	for deck_variant: Variant in tactics.get("decks", []):
		if deck_variant is Dictionary and str((deck_variant as Dictionary).get("deck_key", "")) == "raging_bolt":
			raging = deck_variant
			break
	var recipe: Dictionary = {}
	for recipe_variant: Variant in raging.get("recipes", []):
		if recipe_variant is Dictionary and str((recipe_variant as Dictionary).get("id", "")) == "raging_bolt_slither_wing_pikachu_counter":
			recipe = recipe_variant
			break
	var predicate: Dictionary = recipe.get("target_predicate", {})
	var field_equals: Dictionary = predicate.get("field_equals", {})
	return run_checks([
		assert_true(bool(raging.get("ok", false)), "Raging Bolt tactic scan should pass"),
		assert_false(recipe.is_empty(), "Slither Wing versus Pikachu ex should be a first-class tactic recipe"),
		assert_true(bool(recipe.get("ok", false)), "Slither Wing recipe should reference real frozen-deck and target cards"),
		assert_true("CSV6C_082" in (recipe.get("source_card_refs", []) as Array), "Recipe should own the exact Slither Wing print"),
		assert_true("CSV9C_054" in (recipe.get("target_card_refs", []) as Array), "Recipe should pin Pikachu ex as the concrete matchup target"),
		assert_eq(str(field_equals.get("weakness_energy", "")), "F", "Counter recipe should verify Pikachu ex's Fighting weakness"),
		assert_true(str(recipe.get("payoff", "")).contains("灼伤"), "Recipe should teach the burn check that finishes Sturdy Heart"),
	])


func test_pipeline_manifests_fail_closed_on_weak_or_ambiguous_contracts() -> String:
	var pipeline := PipelineScript.new()
	var target_validation := pipeline.validate_target_catalog({
		"format_version": 1,
		"minimum_player_actions": 4,
		"minimum_negative_probes": 1,
		"minimum_tactic_patterns": 2,
		"targets": [{
			"deck_key": "duplicate",
			"deck_id": 1,
			"strategy_id": "strategy",
			"candidate_count": 1,
			"curriculum_axes": [],
		}, {
			"deck_key": "duplicate",
			"deck_id": 1,
			"strategy_id": "strategy",
			"candidate_count": 1,
			"curriculum_axes": [],
		}],
	})
	var probe_validation := pipeline.validate_probe_catalog({
		"format_version": 1,
		"scenarios": {"scenario": [{
			"id": "same",
			"category": "",
			"description": "",
			"step_overrides": {},
		}, {
			"id": "same",
			"category": "wrong_route",
			"description": "duplicate id",
			"step_overrides": {"step": {"amount": 10}},
		}]},
	})
	return run_checks([
		assert_false(bool(target_validation.get("ok", true)), "Weak target admission thresholds and duplicate keys must be rejected"),
		assert_true((target_validation.get("errors", []) as Array).size() >= 4, "Target validator should explain every contract defect"),
		assert_false(bool(probe_validation.get("ok", true)), "Duplicate and empty shortcut probes must be rejected"),
		assert_true((probe_validation.get("errors", []) as Array).size() >= 4, "Probe validator should explain every contract defect"),
	])


func _report() -> Dictionary:
	if _cached_report.is_empty():
		_cached_report = PipelineScript.new().run()
	return _cached_report
