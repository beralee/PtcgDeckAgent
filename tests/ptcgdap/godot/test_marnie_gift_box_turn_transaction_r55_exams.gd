class_name TestMarnieGiftBoxTurnTransactionR55Exams
extends TestBase

const HarnessScript = preload(
	"res://tests/ptcgdap/godot/support/MarnieGiftBoxReplayExamHarness.gd"
)
const GateScript = preload(
	"res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd"
)
const CatalogScript = preload(
	"res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd"
)
const ReviewedPolicyScript = preload(
	"res://scripts/ai/ptcgdap/runtime/local/ReviewedAuthorStrategyDevelopmentPolicy.gd"
)

const CORPUS_PATH := (
	"res://tests/ptcgdap/exams/marnie_gift_box_match_20260829_165713_715386_r54.json"
)
const PACKAGE_SHA256 := "D669C1C756A5D6AD8CAA36A6A91EE7FB6D031A2A00CF9ACC896080E725A6B4ED"
const TRANSACTION_MIGRATED_EXPECTATIONS := {
	# R54 ended after Adrena-Brain against the damaged Crustle wall. R55 now
	# starts the separately locked Arven -> TM Devolution transaction instead.
	"t26_end_turn_after_munkidori_and_attachment_into_late_wall": [2],
	# A public policy cannot know that two Froslass remain searchable.  When
	# both evolution families are live, the diverse Snorunt + Impidimp pair
	# keeps two independently searchable evolution lines instead.
	"tm_live_target_selects_two_distinct_snorunt_entities": [0, 2],
}


func test_r55_transaction_architecture_preserves_all_current_r54_decisions() -> String:
	var corpus: Dictionary = HarnessScript.load_corpus(CORPUS_PATH)
	corpus["strategy_package"] = {
		"package_id": "dev.bodao-yongzhe.marnies-gift-box",
		"package_version": "5.15.0",
		"archive_sha256": PACKAGE_SHA256,
		"install_source": "built_in",
	}
	for exam: Dictionary in corpus.get("exams", []):
		var migrated: Variant = TRANSACTION_MIGRATED_EXPECTATIONS.get(exam.get("exam_id"))
		if migrated is Array:
			exam["target_selected_indexes"] = migrated.duplicate()
	var report: Dictionary = HarnessScript.run_corpus(
		corpus, "target_selected_indexes", 1
	)
	var current_exam_count: int = corpus.get("exams", []).size()
	return run_checks([
		assert_true(bool(report.get("ok", false)), "R55 exam runner failed: %s" % [report]),
		assert_eq(report.get("total_exams"), current_exam_count),
		assert_eq(
			report.get("passed_exams"), current_exam_count,
			"R55 transaction regression: %s" % [report.get("results", [])]
		),
		assert_true(bool(report.get("all_passed", false))),
	])


func test_r55_same_turn_transaction_rebinds_evolution_disruption_energy_then_attack() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(
		catalog,
		{
			"package_id": "dev.bodao-yongzhe.marnies-gift-box",
			"package_version": "5.15.0",
			"archive_sha256": PACKAGE_SHA256,
			"install_source": "built_in",
		},
		"Windows"
	)
	if not bool(requested.get("ok", false)):
		catalog.free()
		return "R55 transaction-chain handle rejected: %s" % requested
	var created: Dictionary = ReviewedPolicyScript.create(
		requested.get("handle"), "r55-transaction-chain-exam"
	)
	if not bool(created.get("ok", false)):
		catalog.free()
		return "R55 transaction-chain policy rejected: %s" % created
	var policy: Variant = created.get("policy")
	var exams := [
		_chain_exam(
			["CSV7C_059", "CSV3C_123"],
			[{"uid": "CSV10C_148", "hp": 320, "energy_uids": ["CSVE1C_DAR", "CSVE1C_DAR"], "minimum_attack_energy_count": 2}],
			[{"uid": "CSV9.5C_043", "hp": 60}, {"uid": "CSV10C_146", "hp": 70}],
			[
				{"kind": "evolve", "card_uid": "CSV7C_059", "target_uid": "CSV9.5C_043"},
				{"kind": "attack", "source_uid": "CSV10C_148", "attack_index": 0, "projected_damage": 180},
				{"kind": "end_turn"},
			]
		),
		_chain_exam(
			["CSV3C_123"],
			[{"uid": "CSV10C_148", "hp": 320, "energy_uids": ["CSVE1C_DAR", "CSVE1C_DAR"], "minimum_attack_energy_count": 2}],
			[{"uid": "CSV7C_059", "hp": 90}, {"uid": "CSV10C_146", "hp": 70}],
			[
				{"kind": "play_trainer", "card_uid": "CSV3C_123"},
				{"kind": "attack", "source_uid": "CSV10C_148", "attack_index": 0, "projected_damage": 180},
				{"kind": "end_turn"},
			]
		),
		_chain_exam(
			[],
			[{"uid": "CSV10C_148", "hp": 320, "energy_uids": ["CSVE1C_DAR", "CSVE1C_DAR"], "minimum_attack_energy_count": 2}],
			[{"uid": "CSV7C_059", "hp": 90}, {"uid": "CSV10C_146", "hp": 70}],
			[
				{"kind": "use_ability", "source_uid": "CSV10C_148", "ability_index": 0, "requires_interaction": true},
				{"kind": "attack", "source_uid": "CSV10C_148", "attack_index": 0, "projected_damage": 180},
				{"kind": "end_turn"},
			]
		),
		_chain_exam(
			[],
			[{"uid": "CSV10C_148", "hp": 320, "energy_uids": ["CSVE1C_DAR", "CSVE1C_DAR"], "minimum_attack_energy_count": 2}],
			[{"uid": "CSV7C_059", "hp": 90}, {"uid": "CSV10C_146", "hp": 70, "energy_uids": ["CSVE1C_DAR", "CSVE1C_DAR"]}],
			[
				{"kind": "attack", "source_uid": "CSV10C_148", "attack_index": 0, "projected_damage": 180},
				{"kind": "end_turn"},
			]
		),
	]
	var selected_chain: Array = []
	var transaction_ids: Array = []
	for index: int in exams.size():
		var frame := HarnessScript.build_frame(exams[index], 2001 + index)
		var selected: Dictionary = policy.select(frame)
		if not bool(selected.get("ok", false)):
			policy.close()
			catalog.free()
			return "R55 transaction-chain selection failed at %d: %s" % [index, selected]
		selected_chain.append(selected.get("selected_indexes", []).duplicate())
		transaction_ids.append(
			selected.get("decision_audit", {}).get("base_result", {}).get(
				"turn_transaction", {}
			).get("transaction_id")
		)
	var snapshot_text := JSON.stringify(policy.audit_snapshot().get("turn_transaction_state", {}))
	policy.close()
	catalog.free()
	return run_checks([
		assert_eq(selected_chain, [[0], [0], [0], [0]]),
		assert_eq(
			transaction_ids,
			[
				"grimmsnarl-safe-attack-commit",
				"grimmsnarl-safe-attack-commit",
				"grimmsnarl-safe-attack-commit",
				"grimmsnarl-safe-attack-commit",
			]
		),
		assert_false("index" in snapshot_text),
		assert_false("window" in snapshot_text),
		assert_false("score" in snapshot_text),
		assert_false("binding" in snapshot_text),
	])


func test_r55_real_window_generates_non_authoritative_whole_turn_shadow() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(
		catalog,
		{
			"package_id": "dev.bodao-yongzhe.marnies-gift-box",
			"package_version": "5.15.0",
			"archive_sha256": PACKAGE_SHA256,
			"install_source": "built_in",
		},
		"Windows"
	)
	if not bool(requested.get("ok", false)):
		catalog.free()
		return "R55 whole-turn shadow handle rejected: %s" % requested
	var created: Dictionary = ReviewedPolicyScript.create(
		requested.get("handle"), "r55-whole-turn-shadow-exam"
	)
	if not bool(created.get("ok", false)):
		catalog.free()
		return "R55 whole-turn shadow policy rejected: %s" % created
	var policy: Variant = created.get("policy")
	policy.enable_turn_program_shadow(true)
	var exam := _chain_exam(
		["CSV7C_059", "CSV3C_123"],
		[{
			"uid": "CSV10C_148", "hp": 320,
			"energy_uids": ["CSVE1C_DAR", "CSVE1C_DAR"],
			"minimum_attack_energy_count": 2,
		}],
		[{"uid": "CSV9.5C_043", "hp": 60}, {"uid": "CSV10C_146", "hp": 70}],
		[
			{"kind": "evolve", "card_uid": "CSV7C_059", "target_uid": "CSV9.5C_043"},
			{
				"kind": "attack", "source_uid": "CSV10C_148",
				"attack_index": 0, "projected_damage": 180,
			},
			{"kind": "end_turn"},
		]
	)
	var selected: Dictionary = policy.select(HarnessScript.build_frame(exam, 2991))
	var base_result: Dictionary = selected.get("decision_audit", {}).get(
		"base_result", {}
	)
	var generation: Dictionary = base_result.get("turn_program_generation", {})
	var shadow: Dictionary = base_result.get("turn_program_shadow", {})
	var differential: Dictionary = base_result.get("turn_program_differential", {})
	var serialized := JSON.stringify({
		"generation": generation,
		"shadow": shadow,
		"journal": policy.audit_snapshot().get("turn_program_state", {}),
	})
	var journal_text := JSON.stringify(
		policy.audit_snapshot().get("turn_program_state", {})
	)
	policy.close()
	catalog.free()
	return run_checks([
		assert_true(bool(selected.get("ok", false)), "R55 shadow selection failed: %s" % selected),
		assert_eq(selected.get("selected_indexes"), [0]),
		assert_true(bool(generation.get("accepted", false)), "generation=%s" % generation),
		assert_true(int(generation.get("emitted_count", 0)) >= 3),
		assert_true(int(generation.get("emitted_count", 0)) <= 8),
		assert_true(bool(shadow.get("accepted", false)), "shadow=%s" % shadow),
		assert_false(bool(shadow.get("authoritative", true))),
		assert_true(bool(differential.get("current_step_matches_live", false))),
		assert_false("selected_indexes" in serialized),
		assert_false("option_index" in serialized),
		assert_false("window_id" in journal_text),
	])


func test_r55_survival_phase_benches_useful_reserve_but_never_late_budew() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(
		catalog,
		{
			"package_id": "dev.bodao-yongzhe.marnies-gift-box",
			"package_version": "5.15.0",
			"archive_sha256": PACKAGE_SHA256,
			"install_source": "built_in",
		},
		"Windows"
	)
	if not bool(requested.get("ok", false)):
		catalog.free()
		return "R55 survival handle rejected: %s" % requested
	var created: Dictionary = ReviewedPolicyScript.create(
		requested.get("handle"), "r55-survival-phase-exam"
	)
	if not bool(created.get("ok", false)):
		catalog.free()
		return "R55 survival policy rejected: %s" % created
	var policy: Variant = created.get("policy")
	var useful_reserve := _chain_exam(
		[],
		[{"uid": "CSV8C_094", "hp": 110, "energy_uids": ["CSVE1C_DAR"]}],
		[],
		[
			{"kind": "play_basic_to_bench", "card_uid": "CSV10C_007"},
			{"kind": "play_basic_to_bench", "card_uid": "CSV8C_094"},
			{"kind": "end_turn"},
		]
	)
	useful_reserve["turn_number"] = 4
	var useful: Dictionary = policy.select(HarnessScript.build_frame(useful_reserve, 2101))
	var late_budew := _chain_exam(
		[],
		[{
			"uid": "CSV10C_148", "hp": 320,
			"energy_uids": ["CSVE1C_DAR", "CSVE1C_DAR"],
			"minimum_attack_energy_count": 2,
		}],
		[],
		[
			{"kind": "play_basic_to_bench", "card_uid": "CSV9.5C_004"},
			{
				"kind": "attack", "source_uid": "CSV10C_148",
				"attack_index": 0, "projected_damage": 180,
			},
			{"kind": "end_turn"},
		]
	)
	late_budew["turn_number"] = 8
	var rejected: Dictionary = policy.select(HarnessScript.build_frame(late_budew, 2102))
	var grim_reserve := _chain_exam(
		[],
		[{
			"uid": "CSV10C_148", "hp": 320,
			"energy_uids": ["CSVE1C_DAR", "CSVE1C_DAR"],
			"minimum_attack_energy_count": 2,
		}],
		[],
		[
			{"kind": "play_basic_to_bench", "card_uid": "CSV10C_007"},
			{
				"kind": "attack", "source_uid": "CSV10C_148",
				"attack_index": 0, "projected_damage": 180,
			},
			{"kind": "end_turn"},
		]
	)
	grim_reserve["turn_number"] = 6
	var reserved: Dictionary = policy.select(
		HarnessScript.build_frame(grim_reserve, 2103)
	)
	var core_reserve := _chain_exam(
		[],
		[{
			"uid": "CSV10C_146", "hp": 70,
			"energy_uids": ["CSVE1C_DAR"],
			"minimum_attack_energy_count": 1,
		}],
		[],
		[
			{"kind": "play_basic_to_bench", "card_uid": "CSV8C_094"},
			{"kind": "play_basic_to_bench", "card_uid": "CSV9.5C_043"},
			{
				"kind": "attack", "source_uid": "CSV10C_146",
				"attack_index": 0, "projected_damage": 30,
			},
		]
	)
	core_reserve["turn_number"] = 4
	var developed: Dictionary = policy.select(
		HarnessScript.build_frame(core_reserve, 2104)
	)
	var duplicate_munk := _chain_exam(
		[],
		[{
			"uid": "CSV8C_094", "hp": 110,
			"energy_uids": ["CSVE1C_DAR"],
			"minimum_attack_energy_count": 2,
		}],
		[],
		[
			{"kind": "play_basic_to_bench", "card_uid": "CSV8C_094"},
			{"kind": "end_turn"},
		]
	)
	duplicate_munk["turn_number"] = 4
	var held_duplicate: Dictionary = policy.select(
		HarnessScript.build_frame(duplicate_munk, 2105)
	)
	policy.close()
	catalog.free()
	return run_checks([
		assert_true(bool(useful.get("ok", false)), "useful reserve select failed: %s" % useful),
		assert_eq(useful.get("selected_indexes"), [0]),
		assert_true(bool(rejected.get("ok", false)), "late Budew select failed: %s" % rejected),
		assert_eq(rejected.get("selected_indexes"), [1]),
		assert_eq(reserved.get("selected_indexes"), [0]),
		assert_eq(developed.get("selected_indexes"), [1]),
		assert_eq(held_duplicate.get("selected_indexes"), [1]),
	])


func test_r55_zero_damage_wall_is_one_devolution_transaction() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(
		catalog,
		{
			"package_id": "dev.bodao-yongzhe.marnies-gift-box",
			"package_version": "5.15.0",
			"archive_sha256": PACKAGE_SHA256,
			"install_source": "built_in",
		},
		"Windows"
	)
	if not bool(requested.get("ok", false)):
		catalog.free()
		return "R55 wall handle rejected: %s" % requested
	var created: Dictionary = ReviewedPolicyScript.create(
		requested.get("handle"), "r55-wall-recovery-exam"
	)
	if not bool(created.get("ok", false)):
		catalog.free()
		return "R55 wall policy rejected: %s" % created
	var policy: Variant = created.get("policy")
	var first := _chain_exam(
		["CSV5C_120"],
		[{
			"uid": "CSV10C_148", "hp": 320,
			"energy_uids": ["CSVE1C_DAR", "CSVE1C_DAR"],
			"minimum_attack_energy_count": 2,
		}],
		[{"uid": "CSV7C_059", "hp": 90}],
		[
			{
				"kind": "attach_tool", "card_uid": "CSV5C_120",
				"target_uid": "CSV10C_148", "target_is_active": true,
				"target_attached_energy_count": 2,
			},
			{
				"kind": "attack", "source_uid": "CSV10C_148",
				"attack_index": 0, "projected_damage": 0,
			},
			{"kind": "end_turn"},
		]
	)
	first["turn_number"] = 10
	first["state"]["opponent"]["active"] = [{
		"uid": "CSV10C_010", "hp": 80, "max_hp": 150,
		"damage_counters": 70,
		"energy_uids": ["CSVE1C_GRA", "CSVE1C_GRA", "CSVE1C_GRA"],
		"minimum_attack_energy_count": 3, "prize_value": 1,
	}]
	var attached: Dictionary = policy.select(HarnessScript.build_frame(first, 2201))
	var second := first.duplicate(true)
	second["hand"] = []
	second["state"]["self"]["hand"] = []
	second["options"] = [
		{
			"kind": "granted_attack", "source_uid": "CSV5C_120",
			"attack_index": 0, "projected_damage": 0, "option_type_raw": 13,
		},
		{
			"kind": "attack", "source_uid": "CSV10C_148",
			"attack_index": 0, "projected_damage": 0, "option_type_raw": 13,
		},
		{"kind": "end_turn", "option_type_raw": 14},
	]
	var devolved: Dictionary = policy.select(HarnessScript.build_frame(second, 2202))
	var first_tx: Dictionary = attached.get("decision_audit", {}).get(
		"base_result", {}
	).get("turn_transaction", {})
	var second_tx: Dictionary = devolved.get("decision_audit", {}).get(
		"base_result", {}
	).get("turn_transaction", {})
	var race := _chain_exam(
		["CSV6C_114"],
		[{
			"uid": "CSV10C_148", "hp": 320,
			"energy_uids": ["CSVE1C_DAR", "CSVE1C_DAR"],
			"minimum_attack_energy_count": 2,
		}],
		[{"uid": "CSV7C_059", "hp": 90}],
		[
			{
				"kind": "play_trainer", "card_uid": "CSV6C_114",
				"requires_interaction": true,
			},
			{
				"kind": "attack", "source_uid": "CSV10C_148",
				"attack_index": 0, "projected_damage": 60,
			},
			{"kind": "end_turn"},
		]
	)
	race["turn_number"] = 12
	race["state"]["opponent"]["active"] = [{
		"uid": "CSV10C_010", "hp": 150, "prize_value": 1,
	}]
	race["state"]["opponent"]["bench"] = [{
		"uid": "CSV8C_028", "hp": 50, "max_hp": 210, "prize_value": 2,
	}]
	var raced: Dictionary = policy.select(HarnessScript.build_frame(race, 2203))
	var race_tx: Dictionary = raced.get("decision_audit", {}).get(
		"base_result", {}
	).get("turn_transaction", {})
	var no_attack_race := race.duplicate(true)
	no_attack_race["state"]["self"]["active"] = [{
		"uid": "CSV8C_094", "hp": 110,
		"energy_uids": ["CSVE1C_DAR"],
		"minimum_attack_energy_count": 2,
	}]
	no_attack_race["state"]["self"]["bench"] = [{
		"uid": "CSV10C_148", "hp": 320,
		"energy_uids": ["CSVE1C_DAR", "CSVE1C_DAR"],
		"minimum_attack_energy_count": 2,
	}]
	no_attack_race["options"] = [
		{
			"kind": "play_trainer", "card_uid": "CSV6C_114",
			"requires_interaction": true, "option_type_raw": 7,
		},
		{
			"kind": "granted_attack", "source_uid": "CSV5C_120",
			"attack_index": 0, "projected_damage": 0, "option_type_raw": 13,
		},
		{"kind": "end_turn", "option_type_raw": 14},
	]
	var held: Dictionary = policy.select(
		HarnessScript.build_frame(no_attack_race, 2204)
	)
	var held_tx: Dictionary = held.get("decision_audit", {}).get(
		"base_result", {}
	).get("turn_transaction", {})
	var already_best := race.duplicate(true)
	already_best["state"]["opponent"]["active"] = [{
		"uid": "CSV8C_028", "hp": 110, "max_hp": 210, "prize_value": 2,
	}]
	already_best["state"]["opponent"]["bench"] = [{
		"uid": "CSV8C_028", "hp": 170, "max_hp": 210, "prize_value": 2,
	}]
	already_best["options"] = [
		{
			"kind": "play_trainer", "card_uid": "CSV6C_114",
			"requires_interaction": true, "option_type_raw": 7,
		},
		{
			"kind": "play_trainer", "card_uid": "CSVH1aC_023",
			"requires_interaction": true, "option_type_raw": 7,
		},
		{
			"kind": "attack", "source_uid": "CSV10C_148",
			"attack_index": 0, "projected_damage": 180,
			"option_type_raw": 13,
		},
		{"kind": "end_turn", "option_type_raw": 14},
	]
	var committed: Dictionary = policy.select(
		HarnessScript.build_frame(already_best, 2205)
	)
	var commit_tx: Dictionary = committed.get("decision_audit", {}).get(
		"base_result", {}
	).get("turn_transaction", {})
	policy.close()
	catalog.free()
	return run_checks([
		assert_eq(attached.get("selected_indexes"), [0]),
		assert_eq(first_tx.get("step_id"), "attach-devolution-to-funded-grimmsnarl"),
		assert_eq(devolved.get("selected_indexes"), [0]),
		assert_eq(second_tx.get("step_id"), "commit-devolution-through-wall"),
		assert_eq(first_tx.get("transaction_id"), second_tx.get("transaction_id")),
		assert_eq(raced.get("selected_indexes"), [0]),
		assert_eq(race_tx.get("step_id"), "gust-immediate-two-prize-ko"),
		assert_eq(held.get("selected_indexes"), [2]),
		assert_false(held_tx.get("step_id") == "gust-immediate-two-prize-ko"),
		assert_eq(committed.get("selected_indexes"), [2]),
		assert_eq(commit_tx.get("step_id"), "commit-current-two-prize-ko"),
	])


func test_r55_low_hp_munkidori_moves_its_own_damage_before_commit() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(
		catalog,
		{
			"package_id": "dev.bodao-yongzhe.marnies-gift-box",
			"package_version": "5.15.0",
			"archive_sha256": PACKAGE_SHA256,
			"install_source": "built_in",
		},
		"Windows"
	)
	if not bool(requested.get("ok", false)):
		catalog.free()
		return "R55 Munkidori handle rejected: %s" % requested
	var created: Dictionary = ReviewedPolicyScript.create(
		requested.get("handle"), "r55-munkidori-self-preservation-exam"
	)
	if not bool(created.get("ok", false)):
		catalog.free()
		return "R55 Munkidori policy rejected: %s" % created
	var policy: Variant = created.get("policy")
	var exam := _chain_exam(
		[],
		[{
			"uid": "CSV10C_148", "hp": 240, "max_hp": 320,
			"energy_uids": ["CSVE1C_DAR", "CSVE1C_DAR"],
			"minimum_attack_energy_count": 2, "prize_value": 2,
		}],
		[
			{"uid": "CSV7C_059", "hp": 90},
			{
				"uid": "CSV8C_094", "hp": 30, "max_hp": 110,
				"energy_uids": ["CSVE1C_DAR"], "prize_value": 1,
			},
			{"uid": "CSV7C_059", "hp": 90},
		],
		[
			{
				"kind": "effect_target", "card_uid": "CSV10C_148",
				"source_uid": "CSV8C_094", "source_serial": 12001,
				"source_entity_serial": null, "target_serial": 11000,
				"target_uid": "CSV10C_148", "target_remaining_hp": 240,
				"target_prize_value": 2, "option_type_raw": 3,
			},
			{
				"kind": "effect_target", "card_uid": "CSV8C_094",
				"source_uid": "CSV8C_094", "source_serial": 12001,
				"source_entity_serial": null, "target_serial": 12001,
				"target_uid": "CSV8C_094", "target_remaining_hp": 30,
				"target_prize_value": 1, "option_type_raw": 3,
			},
		]
	)
	exam["turn_number"] = 7
	exam["prompt_kind"] = "effect_target"
	exam["select_semantics"] = {
		"min_count": 1, "max_count": 1,
		"select_type_raw": 1, "select_context_raw": 16,
	}
	var selected: Dictionary = policy.select(HarnessScript.build_frame(exam, 2301))
	policy.close()
	catalog.free()
	return run_checks([
		assert_true(bool(selected.get("ok", false)), "Munkidori select failed: %s" % selected),
		assert_eq(selected.get("selected_indexes"), [1]),
	])


func test_r55_search_stage_builds_two_safe_tm_evolution_targets_without_budew() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(
		catalog,
		{
			"package_id": "dev.bodao-yongzhe.marnies-gift-box",
			"package_version": "5.15.0",
			"archive_sha256": PACKAGE_SHA256,
			"install_source": "built_in",
		},
		"Windows"
	)
	if not bool(requested.get("ok", false)):
		catalog.free()
		return "R55 development-search handle rejected: %s" % requested
	var created: Dictionary = ReviewedPolicyScript.create(
		requested.get("handle"), "r55-development-search-exam"
	)
	if not bool(created.get("ok", false)):
		catalog.free()
		return "R55 development-search policy rejected: %s" % created
	var policy: Variant = created.get("policy")
	var poffin := _chain_exam(
		[],
		[{"uid": "CSV10C_146", "hp": 70}],
		[
			{"uid": "CSV9.5C_043", "hp": 60},
			{"uid": "CSV9.5C_043", "hp": 60},
		],
		[
			{
				"kind": "search", "card_uid": "CSV10C_146",
				"source_uid": "CSV7C_177", "source_serial": 24001,
			},
			{
				"kind": "search", "card_uid": "CSV9.5C_004",
				"source_uid": "CSV7C_177", "source_serial": 24001,
			},
		]
	)
	poffin["turn_number"] = 1
	poffin["prompt_kind"] = "search"
	poffin["select_semantics"] = {
		"min_count": 0, "max_count": 2,
		"select_type_raw": 3, "select_context_raw": 5,
	}
	var no_budew: Dictionary = policy.select(
		HarnessScript.build_frame(poffin, 2401)
	)
	var arven := _chain_exam(
		[],
		[{"uid": "CSV9.5C_004", "hp": 30}],
		[
			{"uid": "CSV9.5C_043", "hp": 60},
			{"uid": "CSV9.5C_043", "hp": 60},
		],
		[
			{
				"kind": "search", "card_uid": "CSVH1C_035",
				"source_uid": "CSV1C_123", "source_serial": 24002,
			},
			{
				"kind": "search", "card_uid": "CSV7C_185",
				"source_uid": "CSV1C_123", "source_serial": 24002,
			},
			{
				"kind": "search", "card_uid": "CSV5C_119",
				"source_uid": "CSV1C_123", "source_serial": 24002,
			},
		]
	)
	arven["turn_number"] = 5
	arven["prompt_kind"] = "search"
	arven["select_semantics"] = {
		"min_count": 1, "max_count": 1,
		"select_type_raw": 3, "select_context_raw": 5,
	}
	var double_snorunt: Dictionary = policy.select(
		HarnessScript.build_frame(arven, 2402)
	)
	var funded_pair := arven.duplicate(true)
	funded_pair["state"]["self"]["bench"] = [
		{"uid": "CSV9.5C_043", "hp": 60},
		{"uid": "CSV10C_146", "hp": 70, "energy_uids": ["CSVE1C_DAR"]},
	]
	var snorunt_impidimp: Dictionary = policy.select(
		HarnessScript.build_frame(funded_pair, 2403)
	)
	policy.close()
	catalog.free()
	return run_checks([
		assert_true(bool(no_budew.get("ok", false)), "Poffin select failed: %s" % no_budew),
		assert_eq(no_budew.get("selected_indexes"), [0]),
		assert_eq(double_snorunt.get("selected_indexes"), [2]),
		assert_true(
			"search.arven-tm-safe-postcondition.two-snorunt" in double_snorunt.get(
				"decision_audit", {}
			).get("matched_rule_ids", [])
		),
		assert_eq(snorunt_impidimp.get("selected_indexes"), [2]),
	])


func test_r55_tm_evolution_transaction_requires_two_safe_targets_before_commit() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(
		catalog,
		{
			"package_id": "dev.bodao-yongzhe.marnies-gift-box",
			"package_version": "5.15.0",
			"archive_sha256": PACKAGE_SHA256,
			"install_source": "built_in",
		},
		"Windows"
	)
	if not bool(requested.get("ok", false)):
		catalog.free()
		return "R55 TM postcondition handle rejected: %s" % requested
	var created: Dictionary = ReviewedPolicyScript.create(
		requested.get("handle"), "r55-tm-postcondition-exam"
	)
	if not bool(created.get("ok", false)):
		catalog.free()
		return "R55 TM postcondition policy rejected: %s" % created
	var policy: Variant = created.get("policy")

	# Replay-derived bad state: Arven's Tool window followed an Ultra Ball line.
	# Both Snorunt are already Froslass and there is only one Impidimp, so the
	# required two-target TM transaction cannot be proved. Rescue Board must
	# preserve the active Munkidori instead of opening a one-target attack.
	var unsafe_search := _chain_exam(
		[],
		[{
			"uid": "CSV8C_094", "hp": 50, "max_hp": 110,
			"energy_uids": ["CSVE1C_DAR"], "appeared_this_turn": false,
		}],
		[
			{"uid": "CSV7C_059", "hp": 90, "appeared_this_turn": false},
			{"uid": "CSV9.5C_004", "hp": 30, "appeared_this_turn": false},
			{"uid": "CSV7C_059", "hp": 90, "appeared_this_turn": false},
			{"uid": "CSV10C_146", "hp": 70, "appeared_this_turn": true},
		],
		[
			{
				"kind": "search", "card_uid": "CSV5C_119",
				"source_uid": "CSV1C_123", "source_serial": 25001,
			},
			{
				"kind": "search", "card_uid": "CSV7C_185",
				"source_uid": "CSV1C_123", "source_serial": 25001,
			},
		]
	)
	unsafe_search["turn_number"] = 9
	unsafe_search["prompt_kind"] = "search"
	unsafe_search["select_semantics"] = {
		"min_count": 1, "max_count": 1,
		"select_type_raw": 3, "select_context_raw": 5,
	}
	var searched: Dictionary = policy.select(
		HarnessScript.build_frame(unsafe_search, 2501)
	)

	var unsafe_attach := unsafe_search.duplicate(true)
	unsafe_attach["prompt_kind"] = "main"
	unsafe_attach["select_semantics"] = {
		"min_count": 1, "max_count": 1,
		"select_type_raw": 0, "select_context_raw": 0,
	}
	unsafe_attach["options"] = [
		{
			"kind": "attach_tool", "card_uid": "CSV5C_119",
			"target_uid": "CSV8C_094", "target_energy_uids": ["CSVE1C_DAR"],
			"option_type_raw": 8,
		},
		{"kind": "end_turn", "option_type_raw": 14},
	]
	var held: Dictionary = policy.select(
		HarnessScript.build_frame(unsafe_attach, 2502)
	)

	# Positive replay chain: two Snorunt placed by Buddy-Buddy Poffin this turn
	# are valid targets for TM Evolution. Same-turn appearance must not be confused
	# with ordinary hand evolution timing; the attack effect owns this evolution.
	var safe_attach := unsafe_attach.duplicate(true)
	safe_attach["state"]["self"]["bench"] = [
		{"uid": "CSV9.5C_043", "hp": 60, "appeared_this_turn": true},
		{"uid": "CSV9.5C_043", "hp": 60, "appeared_this_turn": true},
	]
	var attached: Dictionary = policy.select(
		HarnessScript.build_frame(safe_attach, 2503)
	)
	var safe_grant := safe_attach.duplicate(true)
	safe_grant["state"]["self"]["active"][0]["attached_tool_uid"] = "CSV5C_119"
	safe_grant["options"] = [
		{
			"kind": "granted_attack", "source_uid": "CSV5C_119",
			"attack_index": 0, "option_type_raw": 13,
		},
		{"kind": "end_turn", "option_type_raw": 14},
	]
	var granted: Dictionary = policy.select(
		HarnessScript.build_frame(safe_grant, 2504)
	)
	var targets := safe_grant.duplicate(true)
	targets["prompt_kind"] = "attack_target"
	targets["select_semantics"] = {
		"min_count": 0, "max_count": 2,
		"select_type_raw": 1, "select_context_raw": 25,
	}
	targets["state"]["self"]["bench"].append({
		"uid": "CSV10C_147", "hp": 100, "appeared_this_turn": false,
	})
	targets["state"]["self"]["bench"].append({
		"uid": "CSV10C_146", "hp": 70, "appeared_this_turn": true,
	})
	targets["options"] = [
		{
			"kind": "attack_target", "card_uid": "CSV10C_147",
			"source_uid": "CSV8C_094", "target_uid": "CSV10C_147",
			"target_energy_uids": [], "option_type_raw": 3,
		},
		{
			"kind": "attack_target", "card_uid": "CSV10C_146",
			"source_uid": "CSV8C_094", "target_uid": "CSV10C_146",
			"option_type_raw": 3,
		},
		{
			"kind": "attack_target", "card_uid": "CSV9.5C_043",
			"source_uid": "CSV8C_094", "target_uid": "CSV9.5C_043",
			"option_type_raw": 3,
		},
		{
			"kind": "attack_target", "card_uid": "CSV9.5C_043",
			"source_uid": "CSV8C_094", "target_uid": "CSV9.5C_043",
			"option_type_raw": 3,
		},
	]
	# Seed 2919005, turn 2: without either evolution line online, the method
	# must bind one Impidimp and one Snorunt instead of taking two of one class.
	var balanced_targets := targets.duplicate(true)
	balanced_targets["state"]["self"]["bench"] = [
		{"uid": "CSV10C_146", "hp": 70, "appeared_this_turn": true},
		{"uid": "CSV10C_146", "hp": 70, "appeared_this_turn": true},
		{"uid": "CSV9.5C_043", "hp": 60, "appeared_this_turn": true},
		{"uid": "CSV9.5C_043", "hp": 60, "appeared_this_turn": true},
	]
	balanced_targets["options"] = [
		{
			"kind": "attack_target", "card_uid": "CSV10C_146",
			"source_uid": "CSV9.5C_004", "target_uid": "CSV10C_146",
			"option_type_raw": 3,
		},
		{
			"kind": "attack_target", "card_uid": "CSV10C_146",
			"source_uid": "CSV9.5C_004", "target_uid": "CSV10C_146",
			"option_type_raw": 3,
		},
		{
			"kind": "attack_target", "card_uid": "CSV9.5C_043",
			"source_uid": "CSV9.5C_004", "target_uid": "CSV9.5C_043",
			"option_type_raw": 3,
		},
		{
			"kind": "attack_target", "card_uid": "CSV9.5C_043",
			"source_uid": "CSV9.5C_004", "target_uid": "CSV9.5C_043",
			"option_type_raw": 3,
		},
	]
	var balanced: Dictionary = policy.select(
		HarnessScript.build_frame(balanced_targets, 2506)
	)
	var balanced_indexes: Array = balanced.get("selected_indexes", []).duplicate()
	balanced_indexes.sort()
	# The first target choice is only half of TM Evolution. The same transaction
	# must own the follow-up full-deck search and choose one matching evolution
	# for each selected line; otherwise min_select=1 silently evolves only one.
	var balanced_evolutions := balanced_targets.duplicate(true)
	balanced_evolutions["prompt_kind"] = "search"
	balanced_evolutions["select_semantics"] = {
		"min_count": 1, "max_count": 2,
		"select_type_raw": 3, "select_context_raw": 5,
	}
	balanced_evolutions["options"] = [
		{
			"kind": "search", "card_uid": "CSV10C_147",
			"source_uid": "CSV9.5C_004", "option_type_raw": 3,
		},
		{
			"kind": "search", "card_uid": "CSV10C_147",
			"source_uid": "CSV9.5C_004", "option_type_raw": 3,
		},
		{
			"kind": "search", "card_uid": "CSV7C_059",
			"source_uid": "CSV9.5C_004", "option_type_raw": 3,
		},
		{
			"kind": "search", "card_uid": "CSV7C_059",
			"source_uid": "CSV9.5C_004", "option_type_raw": 3,
		},
	]
	var evolutions: Dictionary = policy.select(
		HarnessScript.build_frame(balanced_evolutions, 2507)
	)
	var evolution_indexes: Array = evolutions.get("selected_indexes", []).duplicate()
	evolution_indexes.sort()
	var selected_targets: Dictionary = policy.select(
		HarnessScript.build_frame(targets, 2505)
	)
	policy.close()
	catalog.free()
	return run_checks([
		assert_true(bool(searched.get("ok", false)), "TM search select failed: %s" % searched),
		assert_eq(
			searched.get("selected_indexes"), [1],
			"TM search audit=%s" % JSON.stringify(searched.get("decision_audit", {}))
		),
		assert_eq(held.get("selected_indexes"), [1]),
		assert_eq(attached.get("selected_indexes"), [0]),
		assert_eq(granted.get("selected_indexes"), [0]),
		# Even when two Snorunt are legal, one Froslass may be prized.  The
		# public-safe pair therefore keeps the independent Impidimp line live.
		assert_eq(selected_targets.get("selected_indexes"), [1, 2]),
		assert_eq(balanced_indexes, [0, 2]),
		assert_eq(evolution_indexes, [0, 2]),
	])


func test_r55_spikemuth_completes_backup_grimmsnarl_before_turn_commit() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(
		catalog,
		{
			"package_id": "dev.bodao-yongzhe.marnies-gift-box",
			"package_version": "5.15.0",
			"archive_sha256": PACKAGE_SHA256,
			"install_source": "built_in",
		},
		"Windows"
	)
	if not bool(requested.get("ok", false)):
		catalog.free()
		return "R55 Spikemuth backup handle rejected: %s" % requested
	var created: Dictionary = ReviewedPolicyScript.create(
		requested.get("handle"), "r55-spikemuth-backup-exam"
	)
	if not bool(created.get("ok", false)):
		catalog.free()
		return "R55 Spikemuth backup policy rejected: %s" % created
	var policy: Variant = created.get("policy")

	# Seed 2919004, turn 7: the active Grimmsnarl is unfunded and at 20 HP,
	# while a bench Morgrem is available. Ending the turn loses the Morgrem and
	# the Punk Up window; the whole public chain must complete first.
	var stadium_window := _chain_exam(
		[],
		[{"uid": "CSV10C_148", "hp": 20, "max_hp": 320}],
		[
			{"uid": "CSV10C_147", "hp": 100},
			{"uid": "CSV10C_146", "hp": 70},
			{"uid": "CSV9.5C_043", "hp": 60},
			{"uid": "CSV9.5C_043", "hp": 60},
		],
		[
			{
				"kind": "use_stadium_effect", "card_uid": "CSV10C_216",
				"source_uid": "CSV10C_216", "option_type_raw": 10,
			},
			{"kind": "end_turn", "option_type_raw": 14},
		]
	)
	stadium_window["turn_number"] = 7
	var used: Dictionary = policy.select(HarnessScript.build_frame(stadium_window, 2551))

	var search_window := stadium_window.duplicate(true)
	search_window["prompt_kind"] = "search"
	search_window["select_semantics"] = {
		"min_count": 1, "max_count": 1,
		"select_type_raw": 3, "select_context_raw": 5,
	}
	search_window["options"] = [
		{
			"kind": "search", "card_uid": "CSV10C_148",
			"source_uid": "CSV10C_216", "source_serial": 25501,
			"option_type_raw": 3,
		},
		{
			"kind": "search", "card_uid": "CSV10C_147",
			"source_uid": "CSV10C_216", "source_serial": 25501,
			"option_type_raw": 3,
		},
	]
	var searched: Dictionary = policy.select(HarnessScript.build_frame(search_window, 2552))

	var evolve_window := stadium_window.duplicate(true)
	evolve_window["state"]["self"]["hand"] = ["CSV10C_148"]
	evolve_window["options"] = [
		{
			"kind": "evolve", "card_uid": "CSV10C_148",
			"target_uid": "CSV10C_147", "option_type_raw": 3,
		},
		{"kind": "end_turn", "option_type_raw": 14},
	]
	var evolved: Dictionary = policy.select(HarnessScript.build_frame(evolve_window, 2553))
	var used_tx: Dictionary = used.get("decision_audit", {}).get(
		"base_result", {}
	).get("turn_transaction", {})
	var searched_tx: Dictionary = searched.get("decision_audit", {}).get(
		"base_result", {}
	).get("turn_transaction", {})
	var evolved_tx: Dictionary = evolved.get("decision_audit", {}).get(
		"base_result", {}
	).get("turn_transaction", {})
	policy.close()
	catalog.free()
	return run_checks([
		assert_eq(used.get("selected_indexes"), [0]),
		assert_eq(
			used_tx.get("transaction_id"), "spikemuth-prove-before-use"
		),
		assert_eq(searched.get("selected_indexes"), [0]),
		assert_eq(
			searched_tx.get("transaction_id"), "spikemuth-reprove-before-search"
		),
		assert_eq(evolved.get("selected_indexes"), [0]),
		assert_eq(
			evolved_tx.get("transaction_id"), "spikemuth-reprove-before-evolve"
		),
	])


func test_r55_low_hp_munkidori_retreat_transaction_requires_rescue_board_window() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(
		catalog,
		{
			"package_id": "dev.bodao-yongzhe.marnies-gift-box",
			"package_version": "5.15.0",
			"archive_sha256": PACKAGE_SHA256,
			"install_source": "built_in",
		},
		"Windows"
	)
	if not bool(requested.get("ok", false)):
		catalog.free()
		return "R55 Rescue Board handle rejected: %s" % requested
	var created: Dictionary = ReviewedPolicyScript.create(
		requested.get("handle"), "r55-rescue-board-retreat-exam"
	)
	if not bool(created.get("ok", false)):
		catalog.free()
		return "R55 Rescue Board policy rejected: %s" % created
	var policy: Variant = created.get("policy")
	var no_board := _chain_exam(
		[],
		[{
			"uid": "CSV8C_094", "hp": 50, "max_hp": 110,
			"energy_uids": ["CSVE1C_DAR"],
		}],
		[{"uid": "CSV7C_059", "hp": 90}],
		[
			{
				"kind": "retreat", "target_uid": "CSV7C_059",
				"option_type_raw": 12,
			},
			{"kind": "end_turn", "option_type_raw": 14},
		]
	)
	no_board["turn_number"] = 9
	var unforced: Dictionary = policy.select(HarnessScript.build_frame(no_board, 2601))
	var unforced_tx: Dictionary = unforced.get("decision_audit", {}).get(
		"base_result", {}
	).get("turn_transaction", {})

	var board_window := no_board.duplicate(true)
	board_window["state"]["self"]["hand"] = ["CSV7C_185"]
	board_window["options"] = [
		{
			"kind": "attach_tool", "card_uid": "CSV7C_185",
			"target_uid": "CSV8C_094", "target_energy_uids": ["CSVE1C_DAR"],
			"option_type_raw": 8,
		},
		{
			"kind": "retreat", "target_uid": "CSV7C_059",
			"option_type_raw": 12,
		},
		{"kind": "end_turn", "option_type_raw": 14},
	]
	var attached: Dictionary = policy.select(HarnessScript.build_frame(board_window, 2602))
	var attached_tx: Dictionary = attached.get("decision_audit", {}).get(
		"base_result", {}
	).get("turn_transaction", {})
	var after_attach := board_window.duplicate(true)
	after_attach["state"]["self"]["hand"] = []
	after_attach["state"]["self"]["active"][0]["attached_tool_uid"] = "CSV7C_185"
	after_attach["options"] = [
		{
			"kind": "retreat", "target_uid": "CSV7C_059",
			"option_type_raw": 12,
		},
		{"kind": "end_turn", "option_type_raw": 14},
	]
	var retreated: Dictionary = policy.select(HarnessScript.build_frame(after_attach, 2603))
	policy.close()
	catalog.free()
	return run_checks([
		assert_true(bool(unforced.get("ok", false)), "no-board select failed: %s" % unforced),
		assert_eq(unforced_tx.get("transaction_id"), null),
		assert_eq(attached.get("selected_indexes"), [0]),
		assert_eq(
			attached_tx.get("transaction_id"),
			"munkidori-low-hp-transfer-then-retreat"
		),
		assert_eq(retreated.get("selected_indexes"), [0]),
	])


func test_r55_search_owned_tm_chains_fund_active_before_evolution_or_devolution() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(
		catalog,
		{
			"package_id": "dev.bodao-yongzhe.marnies-gift-box",
			"package_version": "5.15.0",
			"archive_sha256": PACKAGE_SHA256,
			"install_source": "built_in",
		},
		"Windows"
	)
	if not bool(requested.get("ok", false)):
		catalog.free()
		return "R55 search-owned TM handle rejected: %s" % requested
	var created: Dictionary = ReviewedPolicyScript.create(
		requested.get("handle"), "r55-search-owned-tm-exam"
	)
	if not bool(created.get("ok", false)):
		catalog.free()
		return "R55 search-owned TM policy rejected: %s" % created
	var policy: Variant = created.get("policy")

	# Replay seed 2919005: with one live Snorunt, Arven and one Energy, the
	# transaction must fund the active TM carrier, acquire Poffin + Evolution,
	# create the missing second target, attach only to the active, then attack.
	var fund := _chain_exam(
		["CSV1C_123", "CSVE1C_DAR"],
		[{"uid": "CSV9.5C_004", "hp": 30}],
		[{"uid": "CSV9.5C_043", "hp": 60}],
		[
			{
				"kind": "attach_energy", "card_uid": "CSVE1C_DAR",
				"target_uid": "CSV9.5C_004",
			},
			{
				"kind": "attach_energy", "card_uid": "CSVE1C_DAR",
				"target_uid": "CSV9.5C_043",
			},
			{"kind": "play_trainer", "card_uid": "CSV1C_123"},
			{
				"kind": "attack", "source_uid": "CSV9.5C_004",
				"attack_index": 0, "projected_damage": 0,
			},
			{"kind": "end_turn"},
		]
	)
	fund["turn_number"] = 3
	var funded: Dictionary = policy.select(HarnessScript.build_frame(fund, 2701))

	var arven := fund.duplicate(true)
	arven["state"]["self"]["hand"] = ["CSV1C_123"]
	arven["state"]["self"]["active"][0]["energy_uids"] = ["CSVE1C_DAR"]
	arven["options"] = [
		{"kind": "play_trainer", "card_uid": "CSV1C_123", "option_type_raw": 7},
		{
			"kind": "attack", "source_uid": "CSV9.5C_004",
			"attack_index": 0, "projected_damage": 0, "option_type_raw": 13,
		},
		{"kind": "end_turn", "option_type_raw": 14},
	]
	var arven_played: Dictionary = policy.select(HarnessScript.build_frame(arven, 2702))

	var item_search := arven.duplicate(true)
	item_search["prompt_kind"] = "search"
	item_search["state"]["self"]["hand"] = []
	item_search["state"]["self"]["turn"]["supporter_available"] = false
	item_search["select_semantics"] = {
		"min_count": 1, "max_count": 1,
		"select_type_raw": 3, "select_context_raw": 5,
	}
	item_search["options"] = [
		{
			"kind": "search", "card_uid": "CSV7C_177",
			"source_uid": "CSV1C_123", "option_type_raw": 3,
		},
		{
			"kind": "search", "card_uid": "CSVH1C_035",
			"source_uid": "CSV1C_123", "option_type_raw": 3,
		},
	]
	var item_selected: Dictionary = policy.select(
		HarnessScript.build_frame(item_search, 2703)
	)

	var tool_search := item_search.duplicate(true)
	tool_search["state"]["self"]["hand"] = ["CSV7C_177"]
	tool_search["options"] = [
		{
			"kind": "search", "card_uid": "CSV7C_185",
			"source_uid": "CSV1C_123", "option_type_raw": 3,
		},
		{
			"kind": "search", "card_uid": "CSV5C_119",
			"source_uid": "CSV1C_123", "option_type_raw": 3,
		},
	]
	var evolution_searched: Dictionary = policy.select(
		HarnessScript.build_frame(tool_search, 2704)
	)

	var poffin := arven.duplicate(true)
	poffin["state"]["self"]["hand"] = ["CSV7C_177", "CSV5C_119"]
	poffin["state"]["self"]["turn"]["supporter_available"] = false
	poffin["options"] = [
		{"kind": "play_trainer", "card_uid": "CSV7C_177", "option_type_raw": 7},
		{
			"kind": "attach_tool", "card_uid": "CSV5C_119",
			"target_uid": "CSV9.5C_004", "target_energy_uids": ["CSVE1C_DAR"],
			"option_type_raw": 8,
		},
		{
			"kind": "attack", "source_uid": "CSV9.5C_004",
			"attack_index": 0, "projected_damage": 0, "option_type_raw": 13,
		},
		{"kind": "end_turn", "option_type_raw": 14},
	]
	var poffin_played: Dictionary = policy.select(HarnessScript.build_frame(poffin, 2705))

	var poffin_search := item_search.duplicate(true)
	poffin_search["state"]["self"]["hand"] = ["CSV5C_119"]
	poffin_search["options"] = [
		{
			"kind": "search", "card_uid": "CSV10C_146",
			"source_uid": "CSV7C_177", "option_type_raw": 3,
		},
		{
			"kind": "search", "card_uid": "CSV9.5C_043",
			"source_uid": "CSV7C_177", "option_type_raw": 3,
		},
		{
			"kind": "search", "card_uid": "CSV9.5C_004",
			"source_uid": "CSV7C_177", "option_type_raw": 3,
		},
	]
	poffin_search["select_semantics"]["min_count"] = 0
	poffin_search["select_semantics"]["max_count"] = 2
	var impidimp_selected: Dictionary = policy.select(
		HarnessScript.build_frame(poffin_search, 2706)
	)
	var poffin_indexes: Array = impidimp_selected.get("selected_indexes", []).duplicate()
	poffin_indexes.sort()

	var attach := poffin.duplicate(true)
	attach["state"]["self"]["hand"] = ["CSV5C_119"]
	attach["state"]["self"]["bench"].append({"uid": "CSV10C_146", "hp": 70})
	attach["options"] = [
		{
			"kind": "attach_tool", "card_uid": "CSV5C_119",
			"target_uid": "CSV10C_146", "option_type_raw": 8,
		},
		{
			"kind": "attach_tool", "card_uid": "CSV5C_119",
			"target_uid": "CSV9.5C_004", "target_energy_uids": ["CSVE1C_DAR"],
			"option_type_raw": 8,
		},
		{"kind": "end_turn", "option_type_raw": 14},
	]
	var evolution_attached: Dictionary = policy.select(
		HarnessScript.build_frame(attach, 2707)
	)

	var grant := attach.duplicate(true)
	grant["state"]["self"]["hand"] = []
	grant["state"]["self"]["active"][0]["attached_tool_uid"] = "CSV5C_119"
	grant["options"] = [
		{
			"kind": "granted_attack", "source_uid": "CSV5C_119",
			"attack_index": 0, "option_type_raw": 13,
		},
		{
			"kind": "attack", "source_uid": "CSV9.5C_004",
			"attack_index": 0, "projected_damage": 0, "option_type_raw": 13,
		},
		{"kind": "end_turn", "option_type_raw": 14},
	]
	var evolution_granted: Dictionary = policy.select(
		HarnessScript.build_frame(grant, 2708)
	)

	# A funded Grimmsnarl facing a damaged zero-damage wall must spend Arven's
	# Tool branch on TM Devolution before another Tool can close it.  The public
	# remaining-HP clock proves this is the productive window; an undamaged wall
	# is covered separately by the wait-for-damage exam.
	var wall := _chain_exam(
		["CSV1C_123"],
		[{
			"uid": "CSV10C_148", "hp": 320,
			"energy_uids": ["CSVE1C_DAR", "CSVE1C_DAR"],
			"minimum_attack_energy_count": 2,
		}],
		[{"uid": "CSV7C_059", "hp": 90}],
		[
			{"kind": "play_trainer", "card_uid": "CSV1C_123"},
			{
				"kind": "attack", "source_uid": "CSV10C_148",
				"attack_index": 0, "projected_damage": 0,
			},
			{"kind": "end_turn"},
		]
	)
	wall["turn_number"] = 10
	wall["state"]["opponent"]["active"] = [{
		"uid": "CSV10C_010", "hp": 80, "max_hp": 150,
		"damage_counters": 70, "prize_value": 1,
	}]
	var wall_arven: Dictionary = policy.select(HarnessScript.build_frame(wall, 2710))

	var devolution_search := wall.duplicate(true)
	devolution_search["prompt_kind"] = "search"
	devolution_search["state"]["self"]["hand"] = ["CSV7C_177"]
	devolution_search["state"]["self"]["turn"]["supporter_available"] = false
	devolution_search["select_semantics"] = {
		"min_count": 1, "max_count": 1,
		"select_type_raw": 3, "select_context_raw": 5,
	}
	devolution_search["options"] = [
		{
			"kind": "search", "card_uid": "CSV1C_117",
			"source_uid": "CSV1C_123", "option_type_raw": 3,
		},
		{
			"kind": "search", "card_uid": "CSV5C_120",
			"source_uid": "CSV1C_123", "option_type_raw": 3,
		},
	]
	var devolution_searched: Dictionary = policy.select(
		HarnessScript.build_frame(devolution_search, 2711)
	)

	var devolution_attach := wall.duplicate(true)
	devolution_attach["state"]["self"]["hand"] = ["CSV5C_120"]
	devolution_attach["state"]["self"]["turn"]["supporter_available"] = false
	devolution_attach["options"] = [
		{
			"kind": "attach_tool", "card_uid": "CSV5C_120",
			"target_uid": "CSV7C_059", "option_type_raw": 8,
		},
		{
			"kind": "attach_tool", "card_uid": "CSV5C_120",
			"target_uid": "CSV10C_148",
			"target_energy_uids": ["CSVE1C_DAR", "CSVE1C_DAR"],
			"option_type_raw": 8,
		},
		{
			"kind": "attack", "source_uid": "CSV10C_148",
			"attack_index": 0, "projected_damage": 0, "option_type_raw": 13,
		},
		{"kind": "end_turn", "option_type_raw": 14},
	]
	var devolution_attached: Dictionary = policy.select(
		HarnessScript.build_frame(devolution_attach, 2712)
	)

	var devolution_grant := devolution_attach.duplicate(true)
	devolution_grant["state"]["self"]["hand"] = []
	devolution_grant["state"]["self"]["active"][0]["attached_tool_uid"] = "CSV5C_120"
	devolution_grant["options"] = [
		{
			"kind": "granted_attack", "source_uid": "CSV5C_120",
			"attack_index": 0, "projected_damage": 0, "option_type_raw": 13,
		},
		{
			"kind": "attack", "source_uid": "CSV10C_148",
			"attack_index": 0, "projected_damage": 0, "option_type_raw": 13,
		},
		{"kind": "end_turn", "option_type_raw": 14},
	]
	var devolution_granted: Dictionary = policy.select(
		HarnessScript.build_frame(devolution_grant, 2713)
	)
	policy.close()
	catalog.free()
	return run_checks([
		assert_eq(
			funded.get("selected_indexes"), [0],
			"fund-active audit=%s" % JSON.stringify(funded.get("decision_audit", {}))
		),
		assert_eq(arven_played.get("selected_indexes"), [0]),
		assert_eq(item_selected.get("selected_indexes"), [0]),
		assert_eq(evolution_searched.get("selected_indexes"), [1]),
		assert_eq(poffin_played.get("selected_indexes"), [0]),
		assert_eq(poffin_indexes, [0, 1]),
		assert_eq(evolution_attached.get("selected_indexes"), [1]),
		assert_eq(evolution_granted.get("selected_indexes"), [0]),
		assert_eq(wall_arven.get("selected_indexes"), [0]),
		assert_eq(devolution_searched.get("selected_indexes"), [1]),
		assert_eq(devolution_attached.get("selected_indexes"), [1]),
		assert_eq(devolution_granted.get("selected_indexes"), [0]),
	])


func test_r55_send_out_preserves_the_only_morgrem_evolution_bridge() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(
		catalog,
		{
			"package_id": "dev.bodao-yongzhe.marnies-gift-box",
			"package_version": "5.15.0",
			"archive_sha256": PACKAGE_SHA256,
			"install_source": "built_in",
		},
		"Windows"
	)
	if not bool(requested.get("ok", false)):
		catalog.free()
		return "R55 core-preserving send-out handle rejected: %s" % requested
	var created: Dictionary = ReviewedPolicyScript.create(
		requested.get("handle"), "r55-core-preserving-send-out-exam"
	)
	if not bool(created.get("ok", false)):
		catalog.free()
		return "R55 core-preserving send-out policy rejected: %s" % created
	var policy: Variant = created.get("policy")

	# Replay seed 2919008, turn 4: sending the only Morgrem destroys the live
	# Grimmsnarl bridge. With Froslass already online and one spare Impidimp,
	# the replaceable basic must absorb the forced send-out instead.
	var send_out := _chain_exam(
		[],
		[],
		[
			{"uid": "CSV10C_147", "hp": 100},
			{"uid": "CSV7C_059", "hp": 90},
			{"uid": "CSV10C_146", "hp": 70},
		],
		[
			{
				"kind": "send_out", "card_uid": "CSV10C_147",
				"target_uid": "CSV10C_147", "option_type_raw": 3,
			},
			{
				"kind": "send_out", "card_uid": "CSV7C_059",
				"target_uid": "CSV7C_059", "option_type_raw": 3,
			},
			{
				"kind": "send_out", "card_uid": "CSV10C_146",
				"target_uid": "CSV10C_146", "option_type_raw": 3,
			},
		]
	)
	send_out["prompt_kind"] = "send_out"
	send_out["turn_number"] = 4
	var selected: Dictionary = policy.select(HarnessScript.build_frame(send_out, 2801))
	var transaction: Dictionary = selected.get("decision_audit", {}).get(
		"base_result", {}
	).get("turn_transaction", {})
	policy.close()
	catalog.free()
	return run_checks([
		assert_eq(
			selected.get("selected_indexes"), [2],
			"send-out audit=%s" % JSON.stringify(selected.get("decision_audit", {}))
		),
		assert_eq(
			transaction.get("transaction_id"), "late-send-out-transfer-engine"
		),
	])


func test_r55_counter_catcher_opens_the_wall_then_commits_the_attack() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(
		catalog,
		{
			"package_id": "dev.bodao-yongzhe.marnies-gift-box",
			"package_version": "5.15.0",
			"archive_sha256": PACKAGE_SHA256,
			"install_source": "built_in",
		},
		"Windows"
	)
	if not bool(requested.get("ok", false)):
		catalog.free()
		return "R55 wall-opening transaction handle rejected: %s" % requested
	var created: Dictionary = ReviewedPolicyScript.create(
		requested.get("handle"), "r55-wall-opening-attack-exam"
	)
	if not bool(created.get("ok", false)):
		catalog.free()
		return "R55 wall-opening transaction policy rejected: %s" % created
	var policy: Variant = created.get("policy")

	# Replay seed 2919005, turn 9: the first Counter Catcher opens the zero-
	# damage Crustle wall. A second copy must not switch Crustle back in before
	# the now-positive Grimmsnarl attack is committed.
	var wall := _chain_exam(
		["CSV6C_114", "CSV6C_114"],
		[{
			"uid": "CSV10C_148", "hp": 320,
			"energy_uids": ["CSVE1C_DAR", "CSVE1C_DAR"],
			"minimum_attack_energy_count": 2,
		}],
		[{"uid": "CSV7C_059", "hp": 90}],
		[
			{"kind": "play_trainer", "card_uid": "CSV6C_114"},
			{
				"kind": "attack", "source_uid": "CSV10C_148",
				"attack_index": 0, "projected_damage": 0,
			},
			{"kind": "end_turn"},
		]
	)
	wall["turn_number"] = 9
	wall["state"]["opponent"]["active"] = [
		{"uid": "CSV10C_010", "hp": 150, "prize_value": 1},
	]
	wall["state"]["opponent"]["bench"] = [
		{"uid": "CSV8C_028", "hp": 210, "prize_value": 2},
	]
	var catcher_played: Dictionary = policy.select(HarnessScript.build_frame(wall, 2810))

	var target := wall.duplicate(true)
	target["prompt_kind"] = "effect_target"
	target["select_semantics"] = {
		"min_count": 1, "max_count": 1,
		"select_type_raw": 1, "select_context_raw": 25,
	}
	target["options"] = [{
		"kind": "effect_target", "card_uid": "CSV8C_028",
		"source_uid": "CSV6C_114", "target_uid": "CSV8C_028",
		"target_prize_value": 2, "option_type_raw": 3,
	}]
	var target_selected: Dictionary = policy.select(HarnessScript.build_frame(target, 2811))

	var attack := wall.duplicate(true)
	attack["state"]["self"]["hand"] = ["CSV6C_114"]
	attack["state"]["opponent"]["active"] = [
		{"uid": "CSV8C_028", "hp": 210, "prize_value": 2},
	]
	attack["state"]["opponent"]["bench"] = [
		{"uid": "CSV10C_010", "hp": 150, "prize_value": 1},
	]
	attack["options"] = [
		{"kind": "play_trainer", "card_uid": "CSV6C_114", "option_type_raw": 7},
		{
			"kind": "attack", "source_uid": "CSV10C_148",
			"attack_index": 0, "projected_damage": 180, "option_type_raw": 13,
		},
		{"kind": "end_turn", "option_type_raw": 14},
	]
	var attacked: Dictionary = policy.select(HarnessScript.build_frame(attack, 2812))
	var transaction_ids: Array = []
	for result: Dictionary in [catcher_played, target_selected, attacked]:
		transaction_ids.append(
			result.get("decision_audit", {}).get("base_result", {}).get(
				"turn_transaction", {}
			).get("transaction_id")
		)
	policy.close()
	catalog.free()
	return run_checks([
		assert_eq(catcher_played.get("selected_indexes"), [0]),
		assert_eq(target_selected.get("selected_indexes"), [0]),
		assert_eq(
			attacked.get("selected_indexes"), [1],
			"attack-commit audit=%s" % JSON.stringify(attacked.get("decision_audit", {}))
		),
		assert_eq(
			transaction_ids,
			[
				"counter-catcher-open-wall-then-attack",
				"counter-catcher-open-wall-then-attack",
				"counter-catcher-open-wall-then-attack",
			]
		),
	])


func test_r55_arven_item_search_completes_live_morgrem_before_munkidori_energy() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(
		catalog,
		{
			"package_id": "dev.bodao-yongzhe.marnies-gift-box",
			"package_version": "5.15.0",
			"archive_sha256": PACKAGE_SHA256,
			"install_source": "built_in",
		},
		"Windows"
	)
	if not bool(requested.get("ok", false)):
		catalog.free()
		return "R55 Morgrem-completion handle rejected: %s" % requested
	var created: Dictionary = ReviewedPolicyScript.create(
		requested.get("handle"), "r55-arven-morgrem-completion-exam"
	)
	if not bool(created.get("ok", false)):
		catalog.free()
		return "R55 Morgrem-completion policy rejected: %s" % created
	var policy: Variant = created.get("policy")

	# Replay seed 2919008, turn 5, Arven's item branch: Froslass and Morgrem
	# are already public on the bench, but Grimmsnarl is not.  Ultra Ball is
	# the turn-completing bridge; Energy Search merely funds Munkidori and
	# leaves the irreplaceable Morgrem exposed for the opponent's next KO.
	var search := _chain_exam(
		[
			"CSV8C_183", "CSV5C_120", "CSV1C_123",
			"CSV2C_127", "CSVH1aC_023", "CSVH1aC_008",
		],
		[{"uid": "CSV10C_146", "hp": 70}],
		[
			{"uid": "CSV10C_147", "hp": 100},
			{"uid": "CSV7C_059", "hp": 90},
			{"uid": "CSV8C_094", "hp": 110},
		],
		[
			{"kind": "search", "card_uid": "CSVH1C_045", "source_uid": "CSV1C_123", "option_type_raw": 3},
			{"kind": "search", "card_uid": "CSV8C_176", "source_uid": "CSV1C_123", "option_type_raw": 3},
			{"kind": "search", "card_uid": "CSV6C_114", "source_uid": "CSV1C_123", "option_type_raw": 3},
			{"kind": "search", "card_uid": "CSV1C_109", "source_uid": "CSV1C_123", "option_type_raw": 3},
			{"kind": "search", "card_uid": "CSVH1C_035", "source_uid": "CSV1C_123", "option_type_raw": 3},
			{"kind": "search", "card_uid": "CSV6C_114", "source_uid": "CSV1C_123", "option_type_raw": 3},
			{"kind": "search", "card_uid": "CSVH1C_045", "source_uid": "CSV1C_123", "option_type_raw": 3},
			{"kind": "search", "card_uid": "CSV8C_183", "source_uid": "CSV1C_123", "option_type_raw": 3},
			{"kind": "search", "card_uid": "CSV1C_112", "source_uid": "CSV1C_123", "option_type_raw": 3},
		]
	)
	search["prompt_kind"] = "search"
	search["turn_number"] = 5
	search["state"]["self"]["prizes_remaining"] = 6
	search["state"]["self"]["deck_count"] = 36
	var selected: Dictionary = policy.select(HarnessScript.build_frame(search, 2820))
	policy.close()
	catalog.free()
	return run_checks([
		assert_eq(
			selected.get("selected_indexes"), [8],
			"Arven item audit=%s" % JSON.stringify(selected.get("decision_audit", {}))
		),
	])


func test_r55_existing_poffin_line_is_not_hijacked_by_search_owned_transaction() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(
		catalog,
		{
			"package_id": "dev.bodao-yongzhe.marnies-gift-box",
			"package_version": "5.15.0",
			"archive_sha256": PACKAGE_SHA256,
			"install_source": "built_in",
		},
		"Windows"
	)
	if not bool(requested.get("ok", false)):
		catalog.free()
		return "R55 existing-Poffin handle rejected: %s" % requested
	var created: Dictionary = ReviewedPolicyScript.create(
		requested.get("handle"), "r55-existing-poffin-owner-scope-exam"
	)
	if not bool(created.get("ok", false)):
		catalog.free()
		return "R55 existing-Poffin policy rejected: %s" % created
	var policy: Variant = created.get("policy")

	# Exact first divergence from the r54 win at seed 2919001, seat 1.  The
	# search-owned transaction exists to acquire a missing Poffin through
	# Arven; it must not claim authority when two Poffin are already in hand.
	var opening := _chain_exam(
		["CSVE1C_DAR", "CSV7C_177", "CSV7C_177", "CSV1C_123"],
		[{"uid": "CSV9.5C_043", "hp": 60}],
		[],
		[
			{
				"kind": "attach_energy", "card_uid": "CSVE1C_DAR",
				"target_uid": "CSV9.5C_043", "target_is_active": true,
				"option_type_raw": 8,
			},
			{"kind": "play_trainer", "card_uid": "CSV7C_177"},
			{"kind": "play_trainer", "card_uid": "CSV1C_123"},
			{"kind": "end_turn"},
		]
	)
	opening["turn_number"] = 2
	var funded: Dictionary = policy.select(HarnessScript.build_frame(opening, 2830))

	var poffin_main := opening.duplicate(true)
	poffin_main["state"]["self"]["hand"] = ["CSV7C_177", "CSV7C_177", "CSV1C_123"]
	poffin_main["state"]["self"]["active"][0]["energy_uids"] = ["CSVE1C_DAR"]
	poffin_main["state"]["self"]["turn"]["manual_attachment_available"] = false
	poffin_main["options"] = [
		{"kind": "play_trainer", "card_uid": "CSV7C_177", "option_type_raw": 7},
		{"kind": "play_trainer", "card_uid": "CSV1C_123", "option_type_raw": 7},
		{"kind": "end_turn", "option_type_raw": 14},
	]
	var poffin_played: Dictionary = policy.select(
		HarnessScript.build_frame(poffin_main, 2831)
	)

	var poffin_search := poffin_main.duplicate(true)
	poffin_search["prompt_kind"] = "search"
	poffin_search["state"]["self"]["hand"] = ["CSV7C_177", "CSV1C_123"]
	poffin_search["select_semantics"] = {
		"min_count": 1, "max_count": 2,
		"select_type_raw": 3, "select_context_raw": 5,
	}
	poffin_search["options"] = [
		{"kind": "search", "card_uid": "CSV10C_146", "source_uid": "CSV7C_177", "option_type_raw": 3},
		{"kind": "search", "card_uid": "CSV9.5C_004", "source_uid": "CSV7C_177", "option_type_raw": 3},
		{"kind": "search", "card_uid": "CSV9.5C_043", "source_uid": "CSV7C_177", "option_type_raw": 3},
		{"kind": "search", "card_uid": "CSV10C_146", "source_uid": "CSV7C_177", "option_type_raw": 3},
		{"kind": "search", "card_uid": "CSV10C_146", "source_uid": "CSV7C_177", "option_type_raw": 3},
		{"kind": "search", "card_uid": "CSV9.5C_004", "source_uid": "CSV7C_177", "option_type_raw": 3},
	]
	var searched: Dictionary = policy.select(
		HarnessScript.build_frame(poffin_search, 2832)
	)
	var opening_transaction: Dictionary = funded.get("decision_audit", {}).get(
		"base_result", {}
	).get("turn_transaction", {})
	policy.close()
	catalog.free()
	return run_checks([
		assert_true(bool(funded.get("ok", false))),
		assert_true(bool(poffin_played.get("ok", false))),
		assert_true(
			opening_transaction.get("transaction_id")
			!= "early-search-owned-tm-evolution",
			"existing Poffin must remain outside the search-owned transaction"
		),
		assert_eq(
			searched.get("selected_indexes"), [0, 3],
			"Poffin audit=%s" % JSON.stringify(searched.get("decision_audit", {}))
		),
	])


func test_r55_early_search_transaction_waits_for_free_artazon_development() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(
		catalog,
		{
			"package_id": "dev.bodao-yongzhe.marnies-gift-box",
			"package_version": "5.15.0",
			"archive_sha256": PACKAGE_SHA256,
			"install_source": "built_in",
		},
		"Windows"
	)
	if not bool(requested.get("ok", false)):
		catalog.free()
		return "R55 Artazon-defer handle rejected: %s" % requested
	var created: Dictionary = ReviewedPolicyScript.create(
		requested.get("handle"), "r55-artazon-before-search-transaction-exam"
	)
	if not bool(created.get("ok", false)):
		catalog.free()
		return "R55 Artazon-defer policy rejected: %s" % created
	var policy: Variant = created.get("policy")

	# Exact first divergence from the R54 win at seed 2919003, seat 1.  Arven
	# can own the subsequent search chain, but it must not consume the Supporter
	# window before the free Artazon development action has been taken.
	var main := _chain_exam(
		[
			"CSV1C_123", "CSVH1C_045", "CSV7C_059",
			"CSVH1C_045", "CSV8C_094",
		],
		[{
			"uid": "CSV8C_094", "hp": 110,
			"energy_uids": ["CSVE1C_DAR"],
			"minimum_attack_energy_count": 2,
		}],
		[],
		[
			{"kind": "play_basic_to_bench", "card_uid": "CSV8C_094"},
			{"kind": "play_trainer", "card_uid": "CSV1C_123"},
			{
				"kind": "use_stadium_effect", "card_uid": "CSV2C_127",
				"source_uid": "CSV2C_127", "option_type_raw": 10,
			},
			{"kind": "end_turn"},
		]
	)
	main["turn_number"] = 2
	main["state"]["self"]["turn"]["manual_attachment_available"] = false
	var selected: Dictionary = policy.select(HarnessScript.build_frame(main, 2840))
	policy.close()
	catalog.free()
	return run_checks([
		assert_eq(
			selected.get("selected_indexes"), [2],
			"Artazon-defer audit=%s" % JSON.stringify(selected.get("decision_audit", {}))
		),
	])


func test_r55_opening_budew_keeps_the_manual_attachment() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(
		catalog,
		{
			"package_id": "dev.bodao-yongzhe.marnies-gift-box",
			"package_version": "5.15.0",
			"archive_sha256": PACKAGE_SHA256,
			"install_source": "built_in",
		},
		"Windows"
	)
	if not bool(requested.get("ok", false)):
		catalog.free()
		return "R55 Budew-attachment handle rejected: %s" % requested
	var created: Dictionary = ReviewedPolicyScript.create(
		requested.get("handle"), "r55-opening-budew-manual-attachment-exam"
	)
	if not bool(created.get("ok", false)):
		catalog.free()
		return "R55 Budew-attachment policy rejected: %s" % created
	var policy: Variant = created.get("policy")

	# Exact first divergence from the R54 win at seed 2919005, seat 1.  The
	# search-owned transaction is not active here; the opening Budew still needs
	# the manual Darkness attachment that preserves the Arven -> TM route.
	var main := _chain_exam(
		["CSVE1C_DAR", "CSV1C_123", "CSV1C_121"],
		[{"uid": "CSV9.5C_004", "hp": 30, "attack_ready": true, "minimum_attack_energy_count": 0}],
		[
			{"uid": "CSV10C_146", "hp": 70, "minimum_attack_energy_count": 1},
			{"uid": "CSV10C_146", "hp": 70, "minimum_attack_energy_count": 1},
		],
		[
			{
				"kind": "attach_energy", "card_uid": "CSVE1C_DAR",
				"target_uid": "CSV9.5C_004", "target_is_active": true,
				"target_energy_uids": [],
			},
			{
				"kind": "attach_energy", "card_uid": "CSVE1C_DAR",
				"target_uid": "CSV10C_146", "target_energy_uids": [],
			},
			{"kind": "play_trainer", "card_uid": "CSV1C_123"},
			{
				"kind": "attack", "source_uid": "CSV9.5C_004",
				"attack_index": 0, "projected_damage": 10,
			},
			{"kind": "end_turn"},
		]
	)
	main["turn_number"] = 2
	main["state"]["self"]["deck_count"] = 40
	main["state"]["self"]["prizes_remaining"] = 6
	main["state"]["opponent"] = {
		"hand_count": 7, "deck_count": 43, "prizes_remaining": 6,
	}
	var selected: Dictionary = policy.select(HarnessScript.build_frame(main, 2850))
	policy.close()
	catalog.free()
	return run_checks([
		assert_eq(
			selected.get("selected_indexes"), [0],
			"Budew-attachment audit=%s" % JSON.stringify(selected.get("decision_audit", {}))
		),
	])


func test_r55_arven_tm_evolution_search_is_not_globally_rejected_with_developed_board() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(
		catalog,
		{
			"package_id": "dev.bodao-yongzhe.marnies-gift-box",
			"package_version": "5.15.0",
			"archive_sha256": PACKAGE_SHA256,
			"install_source": "built_in",
		},
		"Windows"
	)
	if not bool(requested.get("ok", false)):
		catalog.free()
		return "R55 developed-board TM handle rejected: %s" % requested
	var created: Dictionary = ReviewedPolicyScript.create(
		requested.get("handle"), "r55-developed-board-arven-tm-search-exam"
	)
	if not bool(created.get("ok", false)):
		catalog.free()
		return "R55 developed-board TM policy rejected: %s" % created
	var policy: Variant = created.get("policy")

	# Exact first divergence from the R54 win at seed 2919009, seat 0.  The
	# current search window is already legal and public; a global negative rule
	# must not reject TM Evolution merely because no future target window exists
	# yet.  Exact target cardinality is proved after re-observation.
	var search := _chain_exam(
		[
			"CSV9.5C_004", "CSV9.5C_004", "CSV5C_113", "CSV7C_185",
			"CSV8C_094", "CSV10C_175", "CSVH1C_035", "CSV1C_123",
		],
		[{
			"uid": "CSV10C_148", "hp": 320,
			"energy_uids": ["CSVE1C_DAR", "CSVE1C_DAR"],
			"minimum_attack_energy_count": 2,
		}],
		[{"uid": "CSV8C_094", "hp": 110, "energy_uids": ["CSVE1C_DAR"]}],
		[
			{"kind": "search", "card_uid": "CSV5C_119", "source_uid": "CSV1C_123"},
			{"kind": "search", "card_uid": "CSV1C_117", "source_uid": "CSV1C_123"},
			{"kind": "search", "card_uid": "CSV5C_120", "source_uid": "CSV1C_123"},
		]
	)
	search["turn_number"] = 13
	search["prompt_kind"] = "search"
	search["state"]["self"]["prizes_remaining"] = 2
	search["state"]["opponent"]["prizes_remaining"] = 1
	search["state"]["opponent"]["active"] = [{
		"uid": "CSV10C_010", "hp": 150, "remaining_hp": 150,
		"prize_value": 1,
	}]
	search["select_semantics"] = {
		"min_count": 1, "max_count": 1,
		"select_type_raw": 3, "select_context_raw": 5,
	}
	var selected: Dictionary = policy.select(HarnessScript.build_frame(search, 2860))
	policy.close()
	catalog.free()
	return run_checks([
		assert_eq(
			selected.get("selected_indexes"), [0],
			"Developed-board TM audit=%s" % JSON.stringify(selected.get("decision_audit", {}))
		),
	])


func test_r55_early_item_lock_handoff_protects_the_only_ready_grimmsnarl() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(
		catalog,
		{
			"package_id": "dev.bodao-yongzhe.marnies-gift-box",
			"package_version": "5.15.0",
			"archive_sha256": PACKAGE_SHA256,
			"install_source": "built_in",
		},
		"Windows"
	)
	if not bool(requested.get("ok", false)):
		catalog.free()
		return "R55 early item-lock handoff handle rejected: %s" % requested
	var created: Dictionary = ReviewedPolicyScript.create(
		requested.get("handle"), "r55-early-item-lock-protect-core-exam"
	)
	if not bool(created.get("ok", false)):
		catalog.free()
		return "R55 early item-lock handoff policy rejected: %s" % created
	var policy: Variant = created.get("policy")

	# Exact first divergence from seed 2919002, seat 0.  This is not generic
	# late-Budew priority: the double-Froslass engine is online, Munkidori has no
	# Darkness, and the sole ready Grimmsnarl must be protected from an already
	# ready opposing attacker.  Budew is a one-turn Item-lock bridge only.
	var handoff := _chain_exam(
		["CSV1C_109", "CSV10C_148", "CSV6C_114", "CSV3C_123"],
		[],
		[
			{
				"uid": "CSV10C_148", "hp": 280, "max_hp": 320,
				"damage_counters": 40,
				"energy_uids": ["CSVE1C_DAR", "CSVE1C_DAR"],
				"minimum_attack_energy_count": 2,
			},
			{"uid": "CSV7C_059", "hp": 90},
			{"uid": "CSV9.5C_004", "hp": 30, "minimum_attack_energy_count": 0},
			{
				"uid": "CSV8C_094", "hp": 70, "max_hp": 110,
				"damage_counters": 40,
			},
			{"uid": "CSV7C_059", "hp": 90},
		],
		[
			{
				"kind": "send_out", "card_uid": "CSV10C_148",
				"target_uid": "CSV10C_148", "target_attached_energy_count": 2,
				"target_attack_ready": true, "target_remaining_hp": 280,
			},
			{
				"kind": "send_out", "card_uid": "CSV7C_059",
				"target_uid": "CSV7C_059", "target_attached_energy_count": 0,
				"target_attack_ready": false, "target_remaining_hp": 90,
			},
			{
				"kind": "send_out", "card_uid": "CSV9.5C_004",
				"target_uid": "CSV9.5C_004", "target_attached_energy_count": 0,
				"target_attack_ready": true, "target_remaining_hp": 30,
			},
			{
				"kind": "send_out", "card_uid": "CSV8C_094",
				"target_uid": "CSV8C_094", "target_attached_energy_count": 0,
				"target_attack_ready": false, "target_remaining_hp": 70,
			},
		]
	)
	handoff["turn_number"] = 4
	handoff["prompt_kind"] = "send_out"
	handoff["state"]["self"]["prizes_remaining"] = 6
	handoff["state"]["opponent"]["prizes_remaining"] = 5
	handoff["state"]["opponent"]["active"] = [{
		"uid": "CSV8C_028", "hp": 110, "max_hp": 210,
		"damage_counters": 100,
		"energy_uids": ["CSVE1C_GRA", "CSVE1C_GRA", "CSVE1C_GRA"],
		"minimum_attack_energy_count": 3, "prize_value": 2,
	}]
	handoff["select_semantics"] = {
		"min_count": 1, "max_count": 1,
		"select_type_raw": 1, "select_context_raw": 4,
	}
	var selected: Dictionary = policy.select(HarnessScript.build_frame(handoff, 2870))
	policy.close()
	catalog.free()
	return run_checks([
		assert_eq(
			selected.get("selected_indexes"), [2],
			"Early item-lock audit=%s" % JSON.stringify(selected.get("decision_audit", {}))
		),
	])


func test_r55_search_owned_devolution_waits_for_public_wall_damage() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(
		catalog,
		{
			"package_id": "dev.bodao-yongzhe.marnies-gift-box",
			"package_version": "5.15.0",
			"archive_sha256": PACKAGE_SHA256,
			"install_source": "built_in",
		},
		"Windows"
	)
	if not bool(requested.get("ok", false)):
		catalog.free()
		return "R55 damaged-wall devolution handle rejected: %s" % requested
	var created: Dictionary = ReviewedPolicyScript.create(
		requested.get("handle"), "r55-damaged-wall-before-devolution-exam"
	)
	if not bool(created.get("ok", false)):
		catalog.free()
		return "R55 damaged-wall devolution policy rejected: %s" % created
	var policy: Variant = created.get("policy")

	# Exact first divergence from seed 2919006, seat 1.  At only 10 visible
	# damage, devolution opens the wall without taking a Prize and hands the
	# opponent an immediate Ogerpon promotion.  Defiance Band is the safe tool;
	# the devolution transaction must wait for the wall's public damage clock.
	var main := _chain_exam(
		["CSV1C_123"],
		[{
			"uid": "CSV10C_148", "hp": 320,
			"energy_uids": ["CSVE1C_DAR", "CSVE1C_DAR"],
			"minimum_attack_energy_count": 2,
		}],
		[
			{"uid": "CSV10C_146", "hp": 70, "energy_uids": ["CSVE1C_DAR", "CSVE1C_DAR"]},
			{"uid": "CSV8C_094", "hp": 110, "energy_uids": ["CSVE1C_DAR"]},
			{"uid": "CSV10C_146", "hp": 70, "energy_uids": ["CSVE1C_DAR"]},
		],
		[
			{"kind": "play_trainer", "card_uid": "CSV1C_123"},
			{"kind": "end_turn"},
		]
	)
	main["turn_number"] = 8
	main["state"]["opponent"]["active"] = [{
		"uid": "CSV10C_010", "hp": 140, "max_hp": 150,
		"damage_counters": 10,
		"energy_uids": ["CSVE1C_GRA"],
		"minimum_attack_energy_count": 3, "prize_value": 1,
	}]
	var supporter: Dictionary = policy.select(HarnessScript.build_frame(main, 2880))

	var item_search := main.duplicate(true)
	item_search["prompt_kind"] = "search"
	item_search["options"] = [{
		"kind": "search", "card_uid": "CSV7C_177",
		"source_uid": "CSV1C_123", "option_type_raw": 3,
	}]
	item_search["select_semantics"] = {
		"min_count": 1, "max_count": 1,
		"select_type_raw": 3, "select_context_raw": 5,
	}
	var item: Dictionary = policy.select(HarnessScript.build_frame(item_search, 2881))

	var tool_search := item_search.duplicate(true)
	tool_search["options"] = [
		{
			"kind": "search", "card_uid": "CSV1C_117",
			"source_uid": "CSV1C_123", "option_type_raw": 3,
		},
		{
			"kind": "search", "card_uid": "CSV5C_120",
			"source_uid": "CSV1C_123", "option_type_raw": 3,
		},
	]
	var tool: Dictionary = policy.select(HarnessScript.build_frame(tool_search, 2882))
	var transaction_id: Variant = supporter.get("decision_audit", {}).get(
		"base_result", {}
	).get("turn_transaction", {}).get("transaction_id")
	policy.close()
	catalog.free()
	return run_checks([
		assert_eq(supporter.get("selected_indexes"), [0]),
		assert_eq(item.get("selected_indexes"), [0]),
		assert_true(
			transaction_id != "zero-damage-wall-search-owned-devolution",
			"lightly damaged wall must not start the devolution transaction"
		),
		assert_eq(
			tool.get("selected_indexes"), [0],
			"Damaged-wall tool audit=%s" % JSON.stringify(tool.get("decision_audit", {}))
		),
	])


func test_r55_early_tm_search_waits_for_free_board_development() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(
		catalog,
		{
			"package_id": "dev.bodao-yongzhe.marnies-gift-box",
			"package_version": "5.15.0",
			"archive_sha256": PACKAGE_SHA256,
			"install_source": "built_in",
		},
		"Windows"
	)
	if not bool(requested.get("ok", false)):
		catalog.free()
		return "R55 free-development handle rejected: %s" % requested
	var created: Dictionary = ReviewedPolicyScript.create(
		requested.get("handle"), "r55-free-development-before-search-exam"
	)
	if not bool(created.get("ok", false)):
		catalog.free()
		return "R55 free-development policy rejected: %s" % created
	var policy: Variant = created.get("policy")

	# Seed 2919024, seat 0: using the already-played Spikemuth is free board
	# development.  Starting Arven's TM transaction first caused the journal to
	# retire after the retreat branch and the Stadium development was lost.
	var spikemuth := _chain_exam(
		["CSV1C_121", "CSV1C_121", "CSV9.5C_004", "CSV10C_216", "CSV1C_123"],
		[{"uid": "CSV9.5C_004", "hp": 30, "minimum_attack_energy_count": 0}],
		[{
			"uid": "CSV10C_146", "hp": 70,
			"energy_uids": ["CSVE1C_DAR"], "minimum_attack_energy_count": 1,
		}],
		[
			{"kind": "play_basic_to_bench", "card_uid": "CSV9.5C_004"},
			{"kind": "play_trainer", "card_uid": "CSV1C_121"},
			{"kind": "play_trainer", "card_uid": "CSV1C_121"},
			{"kind": "play_trainer", "card_uid": "CSV1C_123"},
			{
				"kind": "use_stadium_effect", "card_uid": "CSV10C_216",
				"source_uid": "CSV10C_216", "option_type_raw": 10,
			},
			{
				"kind": "attack", "source_uid": "CSV9.5C_004",
				"attack_index": 0, "projected_damage": 0,
			},
			{
				"kind": "retreat", "target_uid": "CSV10C_146",
				"option_type_raw": 12,
			},
			{"kind": "end_turn"},
		]
	)
	spikemuth["turn_number"] = 3
	spikemuth["state"]["opponent"]["active"] = [{
		"uid": "CSV10C_010", "hp": 150,
		"energy_uids": ["CSVE1C_GRA"],
		"minimum_attack_energy_count": 3, "prize_value": 1,
	}]
	var stadium_first: Dictionary = policy.select(
		HarnessScript.build_frame(spikemuth, 2890)
	)

	# Seed 2919033, seat 0: evolving an in-play Impidimp to Morgrem is also a
	# free, deterministic step.  It must precede a supporter-owned search chain
	# so the transaction proves targets from the post-evolution board.
	var morgrem := _chain_exam(
		[
			"CSV3C_123", "CSV1C_121", "CSVH1C_045", "CSV1C_123",
			"CSV10C_147", "CSV6C_114", "CSV1C_121", "CSV8C_094",
		],
		[{"uid": "CSV10C_146", "hp": 70}],
		[],
		[
			{"kind": "play_basic_to_bench", "card_uid": "CSV8C_094"},
			{
				"kind": "evolve", "card_uid": "CSV10C_147",
				"target_uid": "CSV10C_146",
			},
			{"kind": "play_trainer", "card_uid": "CSV3C_123"},
			{"kind": "play_trainer", "card_uid": "CSV1C_121"},
			{"kind": "play_trainer", "card_uid": "CSV1C_123"},
			{"kind": "play_trainer", "card_uid": "CSV1C_121"},
			{"kind": "end_turn"},
		]
	)
	morgrem["turn_number"] = 3
	morgrem["state"]["opponent"]["active"][0]["energy_uids"] = [
		"CSVE1C_GRA", "CSVE1C_GRA",
	]
	var evolve_first: Dictionary = policy.select(HarnessScript.build_frame(morgrem, 2891))
	policy.close()
	catalog.free()
	return run_checks([
		assert_eq(
			stadium_first.get("selected_indexes"), [4],
			"Spikemuth-first result=%s" % JSON.stringify(stadium_first)
		),
		assert_eq(
			evolve_first.get("selected_indexes"), [1],
			"Morgrem-first result=%s" % JSON.stringify(evolve_first)
		),
	])


func test_r55_late_sendout_munkidori_does_not_require_attack_ready() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(
		catalog,
		{
			"package_id": "dev.bodao-yongzhe.marnies-gift-box",
			"package_version": "5.15.0",
			"archive_sha256": PACKAGE_SHA256,
			"install_source": "built_in",
		},
		"Windows"
	)
	if not bool(requested.get("ok", false)):
		catalog.free()
		return "R55 unfunded Munkidori send-out handle rejected: %s" % requested
	var created: Dictionary = ReviewedPolicyScript.create(
		requested.get("handle"), "r55-unfunded-munkidori-send-out-exam"
	)
	if not bool(created.get("ok", false)):
		catalog.free()
		return "R55 unfunded Munkidori send-out policy rejected: %s" % created
	var policy: Variant = created.get("policy")

	# Seed 2919030, seat 1: Munkidori is the late transfer engine even when its
	# attack is not yet funded.  Requiring attack readiness made the transaction
	# skip it and promote a one-prize Impidimp instead.
	var send_out := _chain_exam(
		["CSV8C_094", "CSV7C_177", "CSV1C_123", "CSV5C_120", "CSV6C_114"],
		[],
		[
			{"uid": "CSV9.5C_004", "hp": 30, "minimum_attack_energy_count": 0},
			{"uid": "CSV7C_059", "hp": 90},
			{
				"uid": "CSV10C_146", "hp": 70,
				"energy_uids": ["CSVE1C_DAR"], "minimum_attack_energy_count": 1,
			},
			{
				"uid": "CSV8C_094", "hp": 90, "max_hp": 110,
				"damage_counters": 20, "energy_uids": ["CSVE1C_DAR"],
				"minimum_attack_energy_count": 2,
			},
			{"uid": "CSV10C_007", "hp": 60},
		],
		[
			{
				"kind": "send_out", "card_uid": "CSV9.5C_004",
				"target_uid": "CSV9.5C_004", "target_attack_ready": true,
			},
			{
				"kind": "send_out", "card_uid": "CSV7C_059",
				"target_uid": "CSV7C_059", "target_attack_ready": false,
			},
			{
				"kind": "send_out", "card_uid": "CSV10C_146",
				"target_uid": "CSV10C_146", "target_attack_ready": true,
			},
			{
				"kind": "send_out", "card_uid": "CSV8C_094",
				"target_uid": "CSV8C_094", "target_attack_ready": false,
			},
			{
				"kind": "send_out", "card_uid": "CSV10C_007",
				"target_uid": "CSV10C_007", "target_attack_ready": false,
			},
		]
	)
	send_out["turn_number"] = 9
	send_out["prompt_kind"] = "send_out"
	send_out["select_semantics"] = {
		"min_count": 1, "max_count": 1,
		"select_type_raw": 1, "select_context_raw": 4,
	}
	send_out["state"]["self"]["prizes_remaining"] = 6
	send_out["state"]["opponent"]["prizes_remaining"] = 5
	send_out["state"]["opponent"]["active"][0]["hp"] = 110
	var selected: Dictionary = policy.select(HarnessScript.build_frame(send_out, 2892))
	policy.close()
	catalog.free()
	return run_checks([
		assert_eq(
			selected.get("selected_indexes"), [3],
			"Unfunded Munkidori send-out audit=%s" % JSON.stringify(
				selected.get("decision_audit", {})
			)
		),
	])


func _chain_exam(hand: Array, active: Array, bench: Array, options: Array) -> Dictionary:
	var normalized_options: Array = options.duplicate(true)
	var option_types := {
		"evolve": 3,
		"play_basic_to_bench": 7,
		"attach_tool": 8,
		"play_trainer": 7,
		"use_ability": 10,
		"attack": 13,
		"granted_attack": 13,
		"end_turn": 14,
	}
	for option_value: Variant in normalized_options:
		if not option_value.has("option_type_raw"):
			option_value["option_type_raw"] = option_types.get(
				option_value.get("kind"), 3
			)
	return {
		"exam_id": "r55-same-turn-chain",
		"turn_number": 8,
		"prompt_kind": "main",
		"select_semantics": {
			"min_count": 1, "max_count": 1,
			"select_type_raw": 0, "select_context_raw": 0,
		},
		"state": {
			"phase": "MAIN",
			"self": {
				"hand": hand, "active": active, "bench": bench,
				"discard": [], "deck_count": 24, "prizes_remaining": 4,
				"turn": {
					"supporter_available": true,
					"manual_attachment_available": true,
					"retreat_available": true,
				},
			},
			"opponent": {
				"hand_count": 7,
				"active": [{
					"uid": "CSV8C_028", "hp": 210,
					"energy_uids": ["CSVE1C_GRA", "CSVE1C_GRA", "CSVE1C_GRA"],
					"minimum_attack_energy_count": 3, "prize_value": 2,
				}],
				"bench": [],
				"deck_count": 25, "prizes_remaining": 4,
			},
		},
		"options": normalized_options,
	}
