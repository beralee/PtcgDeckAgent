class_name TestReviewedAuthorVsClassicBenchmark
extends TestBase

const BenchmarkScript = preload(
	"res://scripts/tools/run_reviewed_author_vs_classic_benchmark.gd"
)
const GateScript = preload(
	"res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd"
)
const CatalogScript = preload(
	"res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd"
)
const OwnerFactoryScript = preload(
	"res://scripts/ui/battle/ai/BattleDecisionOwnerFactory.gd"
)


func test_benchmark_declares_five_exact_mirror_matchups_and_wilson_interval() -> String:
	var cases: Array = BenchmarkScript.benchmark_cases()
	var ids: Array = []
	for row: Dictionary in cases:
		ids.append(row.get("source_deck_id"))
	var interval: Dictionary = BenchmarkScript.wilson_95(50, 100)
	return run_checks([
		assert_eq(ids, [800018501, 800017097, 800018499, 800018509, 800018502]),
		assert_true(float(interval.get("lower", 0.0)) < 0.5),
		assert_true(float(interval.get("upper", 1.0)) > 0.5),
		assert_eq(BenchmarkScript.wilson_95(0, 0).get("available"), false),
	])


func test_benchmark_can_select_one_deck_and_uses_the_current_gate_hash() -> String:
	var cases: Array = BenchmarkScript.benchmark_cases(800018509)
	var gate_candidate: Dictionary = GateScript.candidate_for_package_identity(
		"dev.beralee.v18.raging-bolt-ogerpon", "1.0.0"
	)
	return run_checks([
		assert_eq(cases.size(), 1),
		assert_eq(cases[0].get("source_deck_id"), 800018509),
		assert_eq(cases[0].get("archive_sha256"), gate_candidate.get("archive_sha256")),
	])


func test_benchmark_parse_args_can_enable_public_developer_trace() -> String:
	var parsed: Dictionary = BenchmarkScript.new()._parse_args(PackedStringArray([
		"--source-deck-id=800018509",
		"--capture-developer-trace",
	]))
	return run_checks([
		assert_eq(parsed.get("source_deck_id"), 800018509),
		assert_true(bool(parsed.get("capture_developer_trace", false))),
	])


func test_run_requested_benchmark_lane() -> String:
	var options := {
		"source_deck_id": 800018509,
		"games_per_deck": 2,
		"seed_base": 91000,
		"max_steps": 700,
	}
	var output_path := "res://artifacts/deck_training/raging_v2_requested.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--benchmark-games="):
			options["games_per_deck"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--benchmark-seed-base="):
			options["seed_base"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--benchmark-max-steps="):
			options["max_steps"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--benchmark-output="):
			output_path = arg.get_slice("=", 1)
		elif arg == "--benchmark-capture-developer-trace":
			options["capture_developer_trace"] = true
	var report: Dictionary = BenchmarkScript.new().run_benchmark(options)
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		return "benchmark report write failed: %s" % FileAccess.get_open_error()
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file = null
	return run_checks([
		assert_true(bool(report.get("is_clean", false)), str(report.get("dirty_reasons", []))),
		assert_eq(report.get("results", []).size(), 1),
		assert_eq(report.get("results", [])[0].get("source_deck_id"), 800018509),
	])


func test_each_package_binds_to_both_seats_of_its_exact_mirror_deck() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var checks: Array[String] = []
	for case: Dictionary in BenchmarkScript.benchmark_cases():
		var deck: DeckData = CardDatabase.get_ai_deck(int(case.get("source_deck_id")))
		for seat: int in 2:
			var requested: Dictionary = GateScript.request_match_handle(catalog, {
				"package_id": case.get("package_id"),
				"package_version": case.get("package_version"),
				"archive_sha256": case.get("archive_sha256"),
				"install_source": "built_in",
			}, "Windows")
			var gsm := GameStateMachine.new()
			gsm.start_game(deck, deck, 0)
			checks.append(assert_eq(
				_inventory_counts(gsm.game_state.players[seat]),
				_expected_counts(requested.get("handle").local_deck_snapshot()),
				"Mirror inventory changed for %s seat %d" % [case.get("package_id"), seat]
			))
			var built: Dictionary = OwnerFactoryScript.build_windows_development_author_owner(
				requested.get("handle"), gsm, seat,
				"mirror-bind-%s-%d" % [case.get("source_deck_id"), seat]
			)
			checks.append(assert_true(
				bool(built.get("ok", false)),
				"Mirror owner bind failed for %s seat %d: %s" % [
					case.get("package_id"), seat, built.get("error_code")
				]
			))
			var owner: Variant = built.get("owner")
			if owner != null:
				owner.close_match()
			gsm.prepare_for_disposal()
	catalog.free()
	return run_checks(checks)


func _expected_counts(rows: Array) -> Dictionary:
	var counts := {}
	for row: Dictionary in rows:
		counts[str(row.get("local_card_uid", ""))] = int(row.get("count", 0))
	return counts


func _inventory_counts(player: PlayerState) -> Dictionary:
	var cards: Array[CardInstance] = []
	cards.append_array(player.deck)
	cards.append_array(player.hand)
	cards.append_array(player.prizes)
	cards.append_array(player.discard_pile)
	cards.append_array(player.lost_zone)
	if player.active_pokemon != null:
		cards.append_array(player.active_pokemon.collect_all_cards())
	for slot: PokemonSlot in player.bench:
		cards.append_array(slot.collect_all_cards())
	var counts := {}
	for card: CardInstance in cards:
		var uid := card.card_data.get_uid()
		counts[uid] = int(counts.get(uid, 0)) + 1
	return counts
