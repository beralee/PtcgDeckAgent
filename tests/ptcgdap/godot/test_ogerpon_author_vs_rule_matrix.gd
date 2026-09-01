class_name TestOgerponAuthorVsRuleMatrix
extends TestBase

const BenchmarkScript = preload(
	"res://scripts/tools/run_ogerpon_author_vs_rule_matrix.gd"
)
const GateScript = preload(
	"res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd"
)
const CatalogScript = preload(
	"res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd"
)
const CompetitivePolicyV2Script = preload(
	"res://scripts/ai/ptcgdap/public/CompetitivePolicyV2.gd"
)
const ReviewedPolicyScript = preload(
	"res://scripts/ai/ptcgdap/runtime/local/ReviewedAuthorStrategyDevelopmentPolicy.gd"
)
const StrategicTraceScript = preload(
	"res://scripts/ai/ptcgdap/public/StrategicTraceV2.gd"
)
const OwnerFactoryScript = preload(
	"res://scripts/ui/battle/ai/BattleDecisionOwnerFactory.gd"
)
const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const AuthorOwnerScript = preload(
	"res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd"
)
const BattleSetupScene = preload("res://scenes/battle_setup/BattleSetup.tscn")


func test_matrix_declares_candidate_and_five_rule_18_matchups() -> String:
	var ids: Array = []
	for row: Dictionary in BenchmarkScript.benchmark_cases():
		ids.append(row.get("opponent_deck_id"))
	var candidate: Dictionary = GateScript.candidate_for_package_identity(
		"dev.beralee.v18.ogerpon-crustle-v523a", "0.1.0"
	)
	return run_checks([
		assert_eq(BenchmarkScript.CANDIDATE_DECK_ID, 800052301),
		assert_eq(ids, [800018501, 800017097, 800018499, 800018509, 800018502]),
		assert_eq(candidate.get("source_deck_id"), 800052301),
		assert_eq(candidate.get("runtime_kind"), "reviewed_competitive_policy_v2"),
	])


func test_seed_schedule_is_paired_and_matchup_offset_is_explicit() -> String:
	return run_checks([
		assert_eq(BenchmarkScript.seed_for_game(52300, 1000, 0, 0), 52300),
		assert_eq(BenchmarkScript.seed_for_game(52300, 1000, 0, 1), 52300),
		assert_eq(BenchmarkScript.seed_for_game(52300, 1000, 1, 0), 53300),
		assert_eq(BenchmarkScript.seed_for_game(52300, 1000, 4, 18), 56309),
		assert_eq(BenchmarkScript.candidate_seat_for_game(0), 0),
		assert_eq(BenchmarkScript.candidate_seat_for_game(1), 1),
	])


func test_bridge_does_not_invent_mulligan_prompt_after_synchronous_double_mulligan() -> String:
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(74302)
	var opponent_deck: DeckData = CardDatabase.get_ai_deck(800018499)
	var candidate_deck: DeckData = CardDatabase.get_ai_deck(800052301)
	var gsm := GameStateMachine.new()
	var checks: Array[String] = []
	if opponent_deck == null or candidate_deck == null:
		checks.append(assert_true(false, "Exact double-mulligan decks must load"))
	else:
		gsm.start_game(opponent_deck, candidate_deck, 0)
		var mulligan_count := 0
		for action_value: Variant in gsm.get_action_log():
			if action_value is GameAction \
				and action_value.action_type == GameAction.ActionType.MULLIGAN:
				mulligan_count += 1
		checks.append(assert_true(mulligan_count > 0, "Seed must retain mulligan evidence"))
		checks.append(assert_true(
			gsm.game_state.players[0].get_basic_pokemon_in_hand().size() > 0,
			"Rules deck must already have a legal Basic after synchronous mulligans"
		))
		checks.append(assert_eq(gsm.get_pending_decision_snapshot(), {}))
		var bridge := HeadlessMatchBridgeScript.new()
		bridge.bind(gsm)
		bridge.bootstrap_pending_setup()
		checks.append(assert_eq(bridge.get_pending_prompt_type(), "setup_active_0"))
		bridge.bind(null)
	gsm.prepare_for_disposal()
	seed_owner.clear_forced_shuffle_seed()
	return run_checks(checks)


func test_matrix_accepts_an_exact_reviewed_candidate_override() -> String:
	var rows: Array = BenchmarkScript.benchmark_cases(
		800018501,
		"1.0.0",
		646600,
		"dev.bodao-yongzhe.marnies-gift-box"
	)
	return run_checks([
		assert_eq(rows.size(), 1),
		assert_eq(rows[0].get("candidate_deck_id"), 646600),
		assert_eq(rows[0].get("opponent_deck_id"), 800018501),
		assert_eq(rows[0].get("package_id"), "dev.bodao-yongzhe.marnies-gift-box"),
		assert_eq(rows[0].get("package_version"), "1.0.0"),
		assert_eq(
			rows[0].get("archive_sha256"),
			"2E21FA1B9EFB1BE38A18C4B4DFA95EFAF5CBD87C3AD3A667E1CD5341D2C93EAC"
		),
	])


func test_matrix_cli_parses_exact_reviewed_candidate_override() -> String:
	var runner := BenchmarkScript.new()
	var parsed: Dictionary = runner._parse_args(PackedStringArray([
		"--candidate-deck-id=646600",
		"--candidate-package-id=dev.bodao-yongzhe.marnies-gift-box",
		"--opponent-deck-id=800018501",
		"--package-version=1.0.0",
		"--capture-developer-trace",
		"--capture-public-replays",
	]))
	runner.free()
	return run_checks([
		assert_eq(parsed.get("candidate_deck_id"), 646600),
		assert_eq(parsed.get("candidate_package_id"), "dev.bodao-yongzhe.marnies-gift-box"),
		assert_eq(parsed.get("opponent_deck_id"), 800018501),
		assert_eq(parsed.get("package_version"), "1.0.0"),
		assert_true(bool(parsed.get("capture_developer_trace", false))),
		assert_true(bool(parsed.get("capture_public_replays", false))),
	])


func test_matrix_compact_audit_preserves_last_error_code_for_dirty_replay_diagnosis() -> String:
	var runner := BenchmarkScript.new()
	var compact: Dictionary = runner._compact_audit({
		"policy_calls": 14,
		"policy_successes": 14,
		"policy_errors": 1,
		"last_error_code": "pokemon_entity_projection_failed",
	})
	runner.free()
	return run_checks([
		assert_eq(compact.get("last_error_code"), "pokemon_entity_projection_failed"),
	])


func test_r0_package_and_exact_deck_are_locally_discoverable() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var candidate: Dictionary = GateScript.candidate_for_package_identity(
		"dev.beralee.v18.ogerpon-crustle-v523a", "0.1.0"
	)
	var selection := {
		"package_id": candidate.get("package_id"),
		"package_version": candidate.get("package_version"),
		"archive_sha256": candidate.get("archive_sha256"),
		"install_source": "built_in",
	}
	var requested: Dictionary = GateScript.request_match_handle(catalog, selection, "Windows")
	var handle: Variant = requested.get("handle")
	var deck: DeckData = CardDatabase.get_ai_deck(800052301)
	var checks: Array[String] = []
	checks.append(assert_not_null(deck, "Exact Ogerpon source deck must load through CardDatabase"))
	checks.append(assert_true(
		bool(requested.get("ok", false)),
		"R0 package must be discoverable: %s" % requested.get("error_code")
	))
	checks.append(assert_true(
		handle != null and handle.validate_integrity(), "R0 package handle must remain sealed"
	))
	checks.append(assert_eq(
		handle.to_public_dict().get("local_deck_card_count") if handle != null else -1, 60
	))
	checks.append(assert_eq(
		handle.to_public_dict().get("local_deck_unique_printing_count") if handle != null else -1, 19
	))
	catalog.free()
	return run_checks(checks)


func test_r1_package_is_exactly_pinned_and_locally_discoverable() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var candidate: Dictionary = GateScript.candidate_for_package_identity(
		"dev.beralee.v18.ogerpon-crustle-v523a", "0.2.0"
	)
	var selection := {
		"package_id": candidate.get("package_id"),
		"package_version": candidate.get("package_version"),
		"archive_sha256": candidate.get("archive_sha256"),
		"install_source": "built_in",
	}
	var requested: Dictionary = GateScript.request_match_handle(catalog, selection, "Windows")
	var handle: Variant = requested.get("handle")
	var checks: Array[String] = [
		assert_eq(candidate.get("archive_sha256"), "A2E61810BD2B91915EFFDDB73EBE0B27DD64BEDF3BE0125F4B1172C00A53A3E1"),
		assert_true(bool(requested.get("ok", false)), "R1 package must be discoverable: %s" % requested.get("error_code")),
		assert_true(handle != null and handle.validate_integrity(), "R1 package handle must remain sealed"),
	]
	catalog.free()
	return run_checks(checks)


func test_r2_package_is_exactly_pinned_and_locally_discoverable() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var candidate: Dictionary = GateScript.candidate_for_package_identity(
		"dev.beralee.v18.ogerpon-crustle-v523a", "0.3.0"
	)
	var selection := {
		"package_id": candidate.get("package_id"),
		"package_version": candidate.get("package_version"),
		"archive_sha256": candidate.get("archive_sha256"),
		"install_source": "built_in",
	}
	var requested: Dictionary = GateScript.request_match_handle(catalog, selection, "Windows")
	var handle: Variant = requested.get("handle")
	var compile_result := {"accepted": false, "error_code": "missing_handle"}
	var create_result := {"ok": false, "error_code": "missing_handle"}
	var reviewed_parts := {"ir": false, "adapter": false, "config": false}
	if handle != null:
		var allowed_uids: Array = []
		for row_value: Variant in handle.local_deck_snapshot():
			allowed_uids.append(row_value.get("local_card_uid"))
		var documents_result: Dictionary = handle.policy_documents()
		if bool(documents_result.get("ok", false)):
			var documents: Dictionary = documents_result.get("documents", {})
			compile_result = CompetitivePolicyV2Script.compile_local_uid(
				documents.get("policy/adapter.json"), allowed_uids
			)
			var ir_outcome: Variant = StrategicTraceScript.compile_ir(
				documents.get("policy/policy_ir.json")
			)
			var candidate_for_review: Dictionary = GateScript.candidate_for_package_identity(
				"dev.beralee.v18.ogerpon-crustle-v523a", "0.3.0"
			)
			reviewed_parts["ir"] = ReviewedPolicyScript._reviewed_supported_ir(
				StrategicTraceScript.ir_public_dict(ir_outcome.get("ir")), candidate_for_review
			)
			reviewed_parts["adapter"] = ReviewedPolicyScript._reviewed_supported_adapter(
				CompetitivePolicyV2Script.policy_public_dict(compile_result.get("policy")),
				candidate_for_review
			)
			reviewed_parts["config"] = ReviewedPolicyScript._reviewed_supported_config(
				documents.get("policy/config.json"), handle.to_public_dict(), candidate_for_review
			)
		create_result = ReviewedPolicyScript.create(handle, "ogerpon-r2-policy-create")
	var checks: Array[String] = [
		assert_eq(candidate.get("archive_sha256"), "A759D05AFAC27AAA41CC8C5D9EC2740AA89D5D5BA7DD69A0769FC5722A2CC468"),
		assert_true(bool(requested.get("ok", false)), "R2 package must be discoverable: %s" % requested.get("error_code")),
		assert_true(handle != null and handle.validate_integrity(), "R2 package handle must remain sealed"),
		assert_true(bool(compile_result.get("accepted", false)), "R2 policy must compile in Godot: %s" % compile_result.get("error_code")),
		assert_true(bool(create_result.get("ok", false)), "R2 reviewed policy must bind: %s; parts=%s" % [create_result.get("error_code"), reviewed_parts]),
	]
	catalog.free()
	return run_checks(checks)


func test_r3_package_is_exactly_pinned_and_reviewed_policy_binds() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var candidate: Dictionary = GateScript.candidate_for_package_identity(
		"dev.beralee.v18.ogerpon-crustle-v523a", "0.4.0"
	)
	var requested: Dictionary = GateScript.request_match_handle(catalog, {
		"package_id": candidate.get("package_id"),
		"package_version": candidate.get("package_version"),
		"archive_sha256": candidate.get("archive_sha256"),
		"install_source": "built_in",
	}, "Windows")
	var handle: Variant = requested.get("handle")
	var created := ReviewedPolicyScript.create(handle, "ogerpon-r3-policy-create") \
		if handle != null else {"ok": false, "error_code": "missing_handle"}
	var checks: Array[String] = [
		assert_eq(candidate.get("archive_sha256"), "A2C84D69C4F5A69D78E0821B9CE4E404953FF7138EE450C36DA651CE3E8E9423"),
		assert_true(bool(requested.get("ok", false)), "R3 package must be discoverable: %s" % requested.get("error_code")),
		assert_true(handle != null and handle.validate_integrity(), "R3 package handle must remain sealed"),
		assert_true(bool(created.get("ok", false)), "R3 reviewed policy must bind: %s" % created.get("error_code")),
	]
	catalog.free()
	return run_checks(checks)


func test_marnie_gift_box_rule_marnie_r4_is_exactly_pinned_and_binds() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var candidate: Dictionary = GateScript.candidate_for_package_identity(
		"dev.bodao-yongzhe.marnies-gift-box", "1.4.0"
	)
	var requested: Dictionary = GateScript.request_match_handle(catalog, {
		"package_id": candidate.get("package_id"),
		"package_version": candidate.get("package_version"),
		"archive_sha256": candidate.get("archive_sha256"),
		"install_source": "built_in",
	}, "Windows")
	var handle: Variant = requested.get("handle")
	var created := ReviewedPolicyScript.create(handle, "marnie-rule-r4-policy-create") \
		if handle != null else {"ok": false, "error_code": "missing_handle"}
	var checks: Array[String] = [
		assert_eq(candidate.get("archive_sha256"), "B928603BE61DBF0BF54FBB632C021E8C2D24A5557518EEE720072FB2DF67483F"),
		assert_eq(candidate.get("adapter_rule_count"), 81),
		assert_true(bool(requested.get("ok", false)), "Marnie R4 package must be discoverable: %s" % requested.get("error_code")),
		assert_true(handle != null and handle.validate_integrity(), "Marnie R4 package handle must remain sealed"),
		assert_true(bool(created.get("ok", false)), "Marnie R4 reviewed policy must bind: %s" % created.get("error_code")),
	]
	catalog.free()
	return run_checks(checks)


func test_marnie_gift_box_rule_marnie_r5_is_exactly_pinned_and_binds() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var candidate: Dictionary = GateScript.candidate_for_package_identity(
		"dev.bodao-yongzhe.marnies-gift-box", "1.5.0"
	)
	var requested: Dictionary = GateScript.request_match_handle(catalog, {
		"package_id": candidate.get("package_id"),
		"package_version": candidate.get("package_version"),
		"archive_sha256": candidate.get("archive_sha256"),
		"install_source": "built_in",
	}, "Windows")
	var handle: Variant = requested.get("handle")
	var created := ReviewedPolicyScript.create(handle, "marnie-rule-r5-policy-create") \
		if handle != null else {"ok": false, "error_code": "missing_handle"}
	var checks: Array[String] = [
		assert_eq(candidate.get("archive_sha256"), "A3251FA20C82F30E11D8A59710C15388231345C874A071804CF2643EB5FF1EC7"),
		assert_eq(candidate.get("adapter_rule_count"), 82),
		assert_true(bool(requested.get("ok", false)), "Marnie R5 package must be discoverable: %s" % requested.get("error_code")),
		assert_true(handle != null and handle.validate_integrity(), "Marnie R5 package handle must remain sealed"),
		assert_true(bool(created.get("ok", false)), "Marnie R5 reviewed policy must bind: %s" % created.get("error_code")),
	]
	catalog.free()
	return run_checks(checks)


func test_marnie_gift_box_rule_marnie_r6_is_exactly_pinned_and_binds() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var candidate: Dictionary = GateScript.candidate_for_package_identity(
		"dev.bodao-yongzhe.marnies-gift-box", "1.6.0"
	)
	var requested: Dictionary = GateScript.request_match_handle(catalog, {
		"package_id": candidate.get("package_id"),
		"package_version": candidate.get("package_version"),
		"archive_sha256": candidate.get("archive_sha256"),
		"install_source": "built_in",
	}, "Windows")
	var handle: Variant = requested.get("handle")
	var created := ReviewedPolicyScript.create(handle, "marnie-rule-r6-policy-create") \
		if handle != null else {"ok": false, "error_code": "missing_handle"}
	var checks: Array[String] = [
		assert_eq(candidate.get("archive_sha256"), "1F82B0F2FECC4BA78917A92C0F06DC5719468E469018BE210A3E3B4CCE1FD1D2"),
		assert_eq(candidate.get("adapter_rule_count"), 82),
		assert_true(bool(requested.get("ok", false)), "Marnie R6 package must be discoverable: %s" % requested.get("error_code")),
		assert_true(handle != null and handle.validate_integrity(), "Marnie R6 package handle must remain sealed"),
		assert_true(bool(created.get("ok", false)), "Marnie R6 reviewed policy must bind: %s" % created.get("error_code")),
	]
	catalog.free()
	return run_checks(checks)


func test_marnie_gift_box_rule_marnie_r7_is_exactly_pinned_and_binds() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var candidate: Dictionary = GateScript.candidate_for_package_identity(
		"dev.bodao-yongzhe.marnies-gift-box", "1.7.0"
	)
	var requested: Dictionary = GateScript.request_match_handle(catalog, {
		"package_id": candidate.get("package_id"),
		"package_version": candidate.get("package_version"),
		"archive_sha256": candidate.get("archive_sha256"),
		"install_source": "built_in",
	}, "Windows")
	var handle: Variant = requested.get("handle")
	var created := ReviewedPolicyScript.create(handle, "marnie-rule-r7-policy-create") \
		if handle != null else {"ok": false, "error_code": "missing_handle"}
	var checks: Array[String] = [
		assert_eq(candidate.get("archive_sha256"), "4074CB811924CF3C2EBA98B5A3ED67E78CBA1E233221FB2D13801D86FD7D80E5"),
		assert_eq(candidate.get("adapter_rule_count"), 82),
		assert_true(bool(requested.get("ok", false)), "Marnie R7 package must be discoverable: %s" % requested.get("error_code")),
		assert_true(handle != null and handle.validate_integrity(), "Marnie R7 package handle must remain sealed"),
		assert_true(bool(created.get("ok", false)), "Marnie R7 reviewed policy must bind: %s" % created.get("error_code")),
	]
	catalog.free()
	return run_checks(checks)


func test_marnie_gift_box_rule_marnie_r8_is_exactly_pinned_and_binds() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var candidate: Dictionary = GateScript.candidate_for_package_identity(
		"dev.bodao-yongzhe.marnies-gift-box", "1.8.0"
	)
	var requested: Dictionary = GateScript.request_match_handle(catalog, {
		"package_id": candidate.get("package_id"),
		"package_version": candidate.get("package_version"),
		"archive_sha256": candidate.get("archive_sha256"),
		"install_source": "built_in",
	}, "Windows")
	var handle: Variant = requested.get("handle")
	var created := ReviewedPolicyScript.create(handle, "marnie-rule-r8-policy-create") \
		if handle != null else {"ok": false, "error_code": "missing_handle"}
	var checks: Array[String] = [
		assert_eq(candidate.get("archive_sha256"), "209FA7EDF7321A142F1B8A25E44667D44E49AF728E799AFF112716951E72DFD1"),
		assert_eq(candidate.get("adapter_rule_count"), 91),
		assert_true(bool(requested.get("ok", false)), "Marnie R8 package must be discoverable: %s" % requested.get("error_code")),
		assert_true(handle != null and handle.validate_integrity(), "Marnie R8 package handle must remain sealed"),
		assert_true(bool(created.get("ok", false)), "Marnie R8 reviewed policy must bind: %s" % created.get("error_code")),
	]
	catalog.free()
	return run_checks(checks)


func test_marnie_gift_box_rule_marnie_r9_is_exactly_pinned_and_binds() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var candidate: Dictionary = GateScript.candidate_for_package_identity(
		"dev.bodao-yongzhe.marnies-gift-box", "1.9.0"
	)
	var requested: Dictionary = GateScript.request_match_handle(catalog, {
		"package_id": candidate.get("package_id"),
		"package_version": candidate.get("package_version"),
		"archive_sha256": candidate.get("archive_sha256"),
		"install_source": "built_in",
	}, "Windows")
	var handle: Variant = requested.get("handle")
	var created := ReviewedPolicyScript.create(handle, "marnie-rule-r9-policy-create") \
		if handle != null else {"ok": false, "error_code": "missing_handle"}
	var checks: Array[String] = [
		assert_eq(candidate.get("archive_sha256"), "BDC7C0969D6F4A4F5CC94C480E3CE2C19F4C2542AB1902C16DEC51AE1333DB20"),
		assert_eq(candidate.get("adapter_rule_count"), 95),
		assert_true(bool(requested.get("ok", false)), "Marnie R9 package must be discoverable: %s" % requested.get("error_code")),
		assert_true(handle != null and handle.validate_integrity(), "Marnie R9 package handle must remain sealed"),
		assert_true(bool(created.get("ok", false)), "Marnie R9 reviewed policy must bind: %s" % created.get("error_code")),
	]
	catalog.free()
	return run_checks(checks)


func test_marnie_gift_box_damage_plan_package_stays_below_50ms_p95() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var candidate: Dictionary = GateScript.candidate_for_package_identity(
		"dev.bodao-yongzhe.marnies-gift-box", "1.9.0"
	)
	var requested: Dictionary = GateScript.request_match_handle(catalog, {
		"package_id": candidate.get("package_id"),
		"package_version": candidate.get("package_version"),
		"archive_sha256": candidate.get("archive_sha256"),
		"install_source": "built_in",
	}, "Windows")
	var candidate_deck: DeckData = CardDatabase.get_ai_deck(646600)
	var opponent_deck: DeckData = CardDatabase.get_ai_deck(800018501)
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(1145700)
	var gsm := GameStateMachine.new()
	var failure := ""
	if not bool(requested.get("ok", false)) or candidate_deck == null or opponent_deck == null:
		failure = "exact Marnie performance fixture did not load: %s" % requested
	else:
		gsm.start_game(candidate_deck, opponent_deck, 0)
		var built: Dictionary = OwnerFactoryScript.build_windows_development_author_owner(
			requested.get("handle"), gsm, 0, "marnie-r7-package-performance"
		)
		var owner: Variant = built.get("owner")
		if owner == null:
			failure = "exact Marnie performance owner did not bind: %s" % built
		else:
			var basics: Array[CardInstance] = gsm.game_state.players[0].get_basic_pokemon_in_hand()
			if basics.is_empty():
				failure = "seeded Marnie performance fixture has no Basic Pokemon"
			else:
				var frame: Dictionary = owner._build_frame(
					"setup_active", owner._options_for_items(basics, "setup_active"), 1, 1
				)
				var policy: Variant = owner.get("_policy")
				if policy == null:
					failure = "exact Marnie performance policy is unavailable"
				else:
					for _warmup: int in 10:
						var warmup: Dictionary = policy.select(frame)
						if not bool(warmup.get("ok", false)):
							failure = "exact Marnie performance warmup failed: %s" % warmup
							break
					if failure.is_empty():
						var samples_usec: Array[int] = []
						for _sample: int in 100:
							var started := Time.get_ticks_usec()
							var decision: Dictionary = policy.select(frame)
							samples_usec.append(Time.get_ticks_usec() - started)
							if not bool(decision.get("ok", false)):
								failure = "exact Marnie performance decision failed: %s" % decision
								break
						if failure.is_empty():
							samples_usec.sort()
							var p95_usec := samples_usec[
								int(floor(float(samples_usec.size() - 1) * 0.95))
							]
							print("MARNIE_GIFT_BOX_PACKAGE_PERF samples=100 p95_usec=%d" % p95_usec)
							if p95_usec >= 50000:
								failure = "exact Marnie package P95 exceeded 50ms: %dus" % p95_usec
			owner.close_match()
	gsm.prepare_for_disposal()
	seed_owner.clear_forced_shuffle_seed()
	catalog.free()
	return failure


func test_final_package_is_exactly_pinned_and_reviewed_policy_binds() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var candidate: Dictionary = GateScript.candidate_for_package_identity(
		"dev.beralee.v18.ogerpon-crustle-v523a", "1.0.0"
	)
	var requested: Dictionary = GateScript.request_match_handle(catalog, {
		"package_id": candidate.get("package_id"),
		"package_version": candidate.get("package_version"),
		"archive_sha256": candidate.get("archive_sha256"),
		"install_source": "built_in",
	}, "Windows")
	var handle: Variant = requested.get("handle")
	var created := ReviewedPolicyScript.create(handle, "ogerpon-final-policy-create") \
		if handle != null else {"ok": false, "error_code": "missing_handle"}
	var checks: Array[String] = [
		assert_eq(candidate.get("archive_sha256"), "9531F683F2AB9E0138D8054D3E3813D7378F9F6E5F7F8CAF9C428C3FCAFF8D9F"),
		assert_true(bool(requested.get("ok", false)), "Final package must be discoverable: %s" % requested.get("error_code")),
		assert_true(handle != null and handle.validate_integrity(), "Final package handle must remain sealed"),
		assert_true(bool(created.get("ok", false)), "Final reviewed policy must bind: %s" % created.get("error_code")),
	]
	catalog.free()
	return run_checks(checks)


func test_supporter_r3_package_is_exactly_pinned_and_reviewed_policy_binds() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var candidate: Dictionary = GateScript.candidate_for_package_identity(
		"dev.beralee.v18.ogerpon-crustle-v523a", "1.3.0"
	)
	var requested: Dictionary = GateScript.request_match_handle(catalog, {
		"package_id": candidate.get("package_id"),
		"package_version": candidate.get("package_version"),
		"archive_sha256": candidate.get("archive_sha256"),
		"install_source": "built_in",
	}, "Windows")
	var handle: Variant = requested.get("handle")
	var created := ReviewedPolicyScript.create(handle, "ogerpon-supporter-r3-policy-create") \
		if handle != null else {"ok": false, "error_code": "missing_handle"}
	var checks: Array[String] = [
		assert_eq(candidate.get("archive_sha256"), "B813433007BCC1A516376D2C95E4911999B4B4B5A804BD5EE1329799280C40CA"),
		assert_eq(candidate.get("adapter_rule_count"), 65),
		assert_true(bool(requested.get("ok", false)), "Supporter R3 package must be discoverable: %s" % requested.get("error_code")),
		assert_true(handle != null and handle.validate_integrity(), "Supporter R3 package handle must remain sealed"),
		assert_true(bool(created.get("ok", false)), "Supporter R3 reviewed policy must bind: %s" % created.get("error_code")),
	]
	catalog.free()
	return run_checks(checks)


func test_supporter_r4_package_is_exactly_pinned_and_reviewed_policy_binds() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var candidate: Dictionary = GateScript.candidate_for_package_identity(
		"dev.beralee.v18.ogerpon-crustle-v523a", "1.4.0"
	)
	var requested: Dictionary = GateScript.request_match_handle(catalog, {
		"package_id": candidate.get("package_id"),
		"package_version": candidate.get("package_version"),
		"archive_sha256": candidate.get("archive_sha256"),
		"install_source": "built_in",
	}, "Windows")
	var handle: Variant = requested.get("handle")
	var created := ReviewedPolicyScript.create(handle, "ogerpon-supporter-r4-policy-create") \
		if handle != null else {"ok": false, "error_code": "missing_handle"}
	var checks: Array[String] = [
		assert_eq(candidate.get("archive_sha256"), "3B4E78A16EB2C238CD9CFB29CA29B8CF44E0D7D99822CA9C1ECD90A2651DFFB8"),
		assert_eq(candidate.get("adapter_rule_count"), 67),
		assert_true(bool(requested.get("ok", false)), "Supporter R4 package must be discoverable: %s" % requested.get("error_code")),
		assert_true(handle != null and handle.validate_integrity(), "Supporter R4 package handle must remain sealed"),
		assert_true(bool(created.get("ok", false)), "Supporter R4 reviewed policy must bind: %s" % created.get("error_code")),
	]
	catalog.free()
	return run_checks(checks)


func test_supporter_r4_package_is_visible_in_local_battle_setup() -> String:
	var previous_selection: Dictionary = GameManager.get_author_strategy_selection()
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var candidate: Dictionary = GateScript.candidate_for_package_identity(
		"dev.beralee.v18.ogerpon-crustle-v523a", "1.4.0"
	)
	var scene := BattleSetupScene.instantiate()
	scene.call("_ready")
	scene.call("_apply_author_strategy_catalog_report", {
		"metadata_records": catalog.list_metadata_records(),
		"ready_records": catalog.list_ready_records(),
		"diagnostics": catalog.list_diagnostics(),
	})
	var selected: bool = bool(scene.call("_select_author_strategy_ref", {
		"package_id": candidate.get("package_id"),
		"package_version": candidate.get("package_version"),
		"archive_sha256": candidate.get("archive_sha256"),
	}))
	var checks: Array[String] = []
	checks.append(assert_true(selected, "Battle setup must list the exact Ogerpon Supporter R4 package"))
	checks.append(assert_true(
		bool(scene.call("_author_strategy_start_allowed")),
		"Battle setup must allow the exact Supporter R4 development package to start"
	))
	scene.free()
	catalog.free()
	GameManager.reset_author_strategy_selection()
	if not previous_selection.is_empty():
		GameManager.set_author_strategy_selection(previous_selection)
	return run_checks(checks)


func test_marnie_gift_box_rule_marnie_r7_is_visible_in_local_battle_setup() -> String:
	var previous_selection: Dictionary = GameManager.get_author_strategy_selection()
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var candidate: Dictionary = GateScript.candidate_for_package_identity(
		"dev.bodao-yongzhe.marnies-gift-box", "1.7.0"
	)
	var scene := BattleSetupScene.instantiate()
	scene.call("_ready")
	scene.call("_apply_author_strategy_catalog_report", {
		"metadata_records": catalog.list_metadata_records(),
		"ready_records": catalog.list_ready_records(),
		"diagnostics": catalog.list_diagnostics(),
	})
	var selected: bool = bool(scene.call("_select_author_strategy_ref", {
		"package_id": candidate.get("package_id"),
		"package_version": candidate.get("package_version"),
		"archive_sha256": candidate.get("archive_sha256"),
	}))
	var checks: Array[String] = []
	checks.append(assert_true(selected, "Battle setup must list the exact Marnie Gift Box R7 package"))
	checks.append(assert_true(
		bool(scene.call("_author_strategy_start_allowed")),
		"Battle setup must allow the exact Marnie Gift Box R7 development package to start"
	))
	scene.free()
	catalog.free()
	GameManager.reset_author_strategy_selection()
	if not previous_selection.is_empty():
		GameManager.set_author_strategy_selection(previous_selection)
	return run_checks(checks)


func test_representative_selector_is_deterministic() -> String:
	var rows: Array[Dictionary] = [
		{"game": 1, "candidate_outcome": "loss", "steps": 20, "failure": "", "terminal": true},
		{"game": 2, "candidate_outcome": "win", "steps": 18, "failure": "", "terminal": true},
		{"game": 3, "candidate_outcome": "loss", "steps": 40, "failure": "", "terminal": true},
		{"game": 4, "candidate_outcome": "loss", "steps": 30, "failure": "", "terminal": true},
		{"game": 5, "candidate_outcome": "win", "steps": 12, "failure": "", "terminal": true},
	]
	var selected: Dictionary = BenchmarkScript.select_representatives(rows)
	return run_checks([
		assert_eq(selected.get("earliest_clean_win", {}).get("game"), 2),
		assert_eq(selected.get("median_length_clean_loss", {}).get("game"), 4),
		assert_eq(selected.get("longest_clean_loss", {}).get("game"), 3),
	])


func test_contract_diagnostic_identifies_semantic_and_option_shape_drift() -> String:
	var frame := {
		"schema_version": 2,
		"profile_id": "ptcgdap-competitive-public-frame-v2",
		"sequence": 1,
		"seat": 0,
		"prompt_kind": "main",
		"source": {
			"public_observation_hash": "A".repeat(64),
			"window_id": "B".repeat(64),
		},
		"public_state": {
			"turn_number": 1,
			"phase": "MAIN",
			"self": {
				"hand": [], "active": [], "bench": [], "discard": [],
				"deck_count": 60, "prizes_remaining": 6, "bench_capacity": 5,
				"turn": {
					"supporter_available": true,
					"manual_attachment_available": true,
					"retreat_available": true,
				},
			},
			"opponent": {
				"hand_count": 7, "active": [], "bench": [], "discard": [],
				"deck_count": 60, "prizes_remaining": 6,
			},
		},
		"select_semantics": {
			"min_count": 0,
			"max_count": 0,
			"select_type_raw": 0,
			"select_context_raw": 0,
		},
		"options": [],
	}
	var valid: Dictionary = BenchmarkScript.diagnose_competitive_frame(frame)
	frame["select_semantics"]["remain_damage_counter"] = 0
	frame["select_semantics"]["remain_energy_cost"] = 0
	var drifted: Dictionary = BenchmarkScript.diagnose_competitive_frame(frame)
	frame["select_semantics"].erase("remain_damage_counter")
	frame["select_semantics"].erase("remain_energy_cost")
	frame["select_semantics"]["max_count"] = 1
	var option := {}
	for key: Variant in CompetitivePolicyV2Script.OPTION_KEYS:
		option[key] = null
	option.merge({
		"index": 0,
		"kind": "number",
		"option_number": 0,
		"projected_knockout": false,
		"requires_interaction": false,
		"pending_assignment_count": 0,
		"tags": [],
		"option_type_raw": 0,
		"option_player_index": 0,
	}, true)
	frame["options"] = [option]
	var valid_option: Dictionary = BenchmarkScript.diagnose_competitive_frame(frame)
	option["option_area_index"] = null
	option["option_area_raw"] = null
	var option_drifted: Dictionary = BenchmarkScript.diagnose_competitive_frame(frame)
	return run_checks([
		assert_true(bool(valid.get("accepted", false))),
		assert_eq(valid.get("error_code"), ""),
		assert_false(bool(drifted.get("accepted", true))),
		assert_eq(drifted.get("error_code"), "invalid_public_frame"),
		assert_eq(drifted.get("unexpected_semantic_keys"), [
			"remain_damage_counter", "remain_energy_cost",
		]),
		assert_true(bool(drifted.get("normalized_without_unexpected_accepted", false))),
		assert_true(bool(valid_option.get("accepted", false))),
		assert_false(bool(option_drifted.get("accepted", true))),
		assert_eq(option_drifted.get("unexpected_option_keys"), [
			"option_area_index", "option_area_raw",
		]),
		assert_true(bool(option_drifted.get("normalized_without_unexpected_accepted", false))),
	])


func test_real_supporter_r4_owner_setup_frame_conforms_to_competitive_v2_contract() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var candidate: Dictionary = GateScript.candidate_for_package_identity(
		"dev.beralee.v18.ogerpon-crustle-v523a", "1.4.0"
	)
	var requested: Dictionary = GateScript.request_match_handle(catalog, {
		"package_id": candidate.get("package_id"),
		"package_version": candidate.get("package_version"),
		"archive_sha256": candidate.get("archive_sha256"),
		"install_source": "built_in",
	}, "Windows")
	var candidate_deck: DeckData = CardDatabase.get_ai_deck(800052301)
	var opponent_deck: DeckData = CardDatabase.get_ai_deck(800018501)
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(52300)
	var gsm := GameStateMachine.new()
	var checks: Array[String] = []
	checks.append(assert_true(bool(requested.get("ok", false)), "Exact Supporter R4 handle must load"))
	checks.append(assert_not_null(candidate_deck, "Exact Ogerpon deck must load"))
	checks.append(assert_not_null(opponent_deck, "Exact Marnie Rule deck must load"))
	if bool(requested.get("ok", false)) and candidate_deck != null and opponent_deck != null:
		gsm.start_game(candidate_deck, opponent_deck, 0)
		var built: Dictionary = OwnerFactoryScript.build_windows_development_author_owner(
			requested.get("handle"), gsm, 0, "ogerpon-real-frame-contract-red"
		)
		var owner: Variant = built.get("owner")
		checks.append(assert_not_null(owner, "Competitive v2 owner must bind"))
		if owner != null:
			var basics: Array[CardInstance] = gsm.game_state.players[0].get_basic_pokemon_in_hand()
			checks.append(assert_false(basics.is_empty(), "Seeded setup must expose a current option"))
			if not basics.is_empty():
				var frame: Dictionary = owner._build_frame(
					"setup_active", owner._options_for_items(basics, "setup_active"), 1, 1
				)
				var diagnostic: Dictionary = BenchmarkScript.diagnose_competitive_frame(frame)
				checks.append(assert_true(
					bool(diagnostic.get("accepted", false)),
					"Real Host frame must match the frozen v2 contract: %s" % diagnostic
				))
				checks.append(assert_true(
					(diagnostic.get("unexpected_semantic_keys", []) as Array).is_empty(),
					"Real Host semantics must be an exact allow-list"
				))
				checks.append(assert_true(
					(diagnostic.get("unexpected_option_keys", []) as Array).is_empty(),
					"Real Host options must be an exact allow-list"
				))
			owner.close_match()
	gsm.prepare_for_disposal()
	seed_owner.clear_forced_shuffle_seed()
	catalog.free()
	return run_checks(checks)


func test_assignment_target_keeps_originating_effect_source_identity() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var candidate: Dictionary = GateScript.candidate_for_package_identity(
		"dev.beralee.v18.ogerpon-crustle-v523a", "0.2.0"
	)
	var requested: Dictionary = GateScript.request_match_handle(catalog, {
		"package_id": candidate.get("package_id"),
		"package_version": candidate.get("package_version"),
		"archive_sha256": candidate.get("archive_sha256"),
		"install_source": "built_in",
	}, "Windows")
	var candidate_deck: DeckData = CardDatabase.get_ai_deck(800052301)
	var opponent_deck: DeckData = CardDatabase.get_ai_deck(800018501)
	var gsm := GameStateMachine.new()
	var checks: Array[String] = []
	checks.append(assert_true(bool(requested.get("ok", false)), "Exact R1 handle must load"))
	if bool(requested.get("ok", false)) and candidate_deck != null and opponent_deck != null:
		gsm.start_game(candidate_deck, opponent_deck, 0)
		var built: Dictionary = OwnerFactoryScript.build_windows_development_author_owner(
			requested.get("handle"), gsm, 0, "ogerpon-effect-source-continuity"
		)
		var owner: Variant = built.get("owner")
		checks.append(assert_not_null(owner, "Competitive v2 owner must bind"))
		if owner != null:
			var effect_card: CardInstance = null
			var selected_energy: CardInstance = null
			var target_card: CardInstance = null
			for card: CardInstance in owner._collect_player_cards(gsm.game_state.players[0]):
				if card.card_data == null:
					continue
				match card.card_data.get_uid():
					"CSVH1aC_008": effect_card = card
					"CSVE1C_GRA": selected_energy = card
					"CSV8C_028": target_card = card
			checks.append(assert_not_null(effect_card, "Energy Switch must exist in the exact deck"))
			checks.append(assert_not_null(selected_energy, "Grass Energy must exist in the exact deck"))
			checks.append(assert_not_null(target_card, "Ogerpon must exist in the exact deck"))
			if effect_card != null and selected_energy != null and target_card != null:
				var target_slot := PokemonSlot.new()
				target_slot.pokemon_stack.append(target_card)
				var option: Dictionary = owner._make_option(0, target_slot, "assignment_target", {
					"source_card": selected_energy,
					"pending_effect_card": effect_card,
					"cabt_option_type_raw": 3,
				})
				checks.append(assert_eq(option.get("source_uid"), "CSVH1aC_008"))
				checks.append(assert_eq(option.get("source_serial"), owner._serial_for_card(effect_card)))
				checks.append(assert_eq(option.get("card_uid"), "CSV8C_028"))
				checks.append(assert_eq(option.get("target_uid"), "CSV8C_028"))
			owner.close_match()
	gsm.prepare_for_disposal()
	catalog.free()
	return run_checks(checks)


func test_assignment_source_exposes_current_attached_owner_profile() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var candidate: Dictionary = GateScript.candidate_for_package_identity(
		"dev.beralee.v18.ogerpon-crustle-v523a", "0.2.0"
	)
	var requested: Dictionary = GateScript.request_match_handle(catalog, {
		"package_id": candidate.get("package_id"),
		"package_version": candidate.get("package_version"),
		"archive_sha256": candidate.get("archive_sha256"),
		"install_source": "built_in",
	}, "Windows")
	var candidate_deck: DeckData = CardDatabase.get_ai_deck(800052301)
	var opponent_deck: DeckData = CardDatabase.get_ai_deck(800018501)
	var gsm := GameStateMachine.new()
	var checks: Array[String] = []
	checks.append(assert_true(bool(requested.get("ok", false)), "Exact R1 handle must load"))
	if bool(requested.get("ok", false)) and candidate_deck != null and opponent_deck != null:
		gsm.start_game(candidate_deck, opponent_deck, 0)
		var built: Dictionary = OwnerFactoryScript.build_windows_development_author_owner(
			requested.get("handle"), gsm, 0, "ogerpon-assignment-source-owner-profile"
		)
		var owner: Variant = built.get("owner")
		checks.append(assert_not_null(owner, "Competitive v2 owner must bind"))
		if owner != null:
			var effect_card: CardInstance = null
			var selected_energy: CardInstance = null
			var target_card: CardInstance = null
			for card: CardInstance in owner._collect_player_cards(gsm.game_state.players[0]):
				if card.card_data == null:
					continue
				match card.card_data.get_uid():
					"CSVH1aC_008": effect_card = card
					"CSVE1C_GRA": selected_energy = card
					"CSV8C_028": target_card = card
			checks.append(assert_not_null(effect_card, "Energy Switch must exist in the exact deck"))
			checks.append(assert_not_null(selected_energy, "Grass Energy must exist in the exact deck"))
			checks.append(assert_not_null(target_card, "Ogerpon must exist in the exact deck"))
			if effect_card != null and selected_energy != null and target_card != null:
				var source_owner := PokemonSlot.new()
				source_owner.pokemon_stack.append(target_card)
				source_owner.attached_energy.append(selected_energy)
				gsm.game_state.players[0].active_pokemon = source_owner
				var option: Dictionary = owner._make_option(0, selected_energy, "assignment_source", {
					"pending_effect_card": effect_card,
					"cabt_option_type_raw": 5,
				})
				checks.append(assert_eq(option.get("source_uid"), "CSVH1aC_008"))
				checks.append(assert_eq(option.get("card_uid"), "CSVE1C_GRA"))
				checks.append(assert_eq(option.get("target_uid"), "CSV8C_028"))
				checks.append(assert_eq(option.get("target_serial"), owner._serial_for_card(target_card)))
				checks.append(assert_eq(option.get("target_attached_energy_count"), 1))
				checks.append(assert_eq(option.get("target_energy_debt"), 2))
			owner.close_match()
	gsm.prepare_for_disposal()
	catalog.free()
	return run_checks(checks)


func test_competitive_v2_keeps_hidden_prize_choice_under_base_authority() -> String:
	return run_checks([
		assert_eq(AuthorOwnerScript._base_owned_hidden_prize_selection([2, 4, 5]), [0]),
		assert_eq(AuthorOwnerScript._base_owned_hidden_prize_selection([]), []),
	])


func test_send_out_frontier_excludes_effectively_knocked_out_bench_slots() -> String:
	var card_data := CardData.new()
	card_data.name = "Send-out fixture"
	card_data.card_type = "Pokemon"
	card_data.hp = 100
	var knocked_out := PokemonSlot.new()
	knocked_out.pokemon_stack.append(CardInstance.create(card_data, 0))
	knocked_out.damage_counters = 100
	var healthy := PokemonSlot.new()
	healthy.pokemon_stack.append(CardInstance.create(card_data, 0))
	var state := GameState.new()
	var processor := EffectProcessor.new()
	var original_order: Array[PokemonSlot] = [knocked_out, healthy]
	var reordered: Array[PokemonSlot] = [healthy, knocked_out]
	return run_checks([
		assert_eq(
			AuthorOwnerScript._legal_send_out_slots(original_order, processor, state),
			[healthy],
			"Accepted send-out options must be a subset the engine can commit"
		),
		assert_eq(
			AuthorOwnerScript._legal_send_out_slots(reordered, processor, state),
			[healthy],
			"Filtering must preserve semantic identity across option reorder"
		),
		assert_eq(
			AuthorOwnerScript._legal_send_out_slots([knocked_out], processor, state),
			[],
			"An all-KO replacement frontier must fail closed"
		),
	])
