class_name TestReviewedAuthorStrategyPackages
extends TestBase

const GateScript = preload(
	"res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd"
)
const CatalogScript = preload(
	"res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd"
)
const GenericPolicyScript = preload(
	"res://scripts/ai/ptcgdap/runtime/local/ReviewedAuthorStrategyDevelopmentPolicy.gd"
)
const TreeHashScript = preload("res://scripts/ai/ptcgdap/cabt/CabtTreeHash.gd")
const OwnerFactoryScript = preload("res://scripts/ui/battle/ai/BattleDecisionOwnerFactory.gd")
const BattleSetupScene = preload("res://scenes/battle_setup/BattleSetup.tscn")

const EXPECTED := [
	["dev.beralee.v18.marnie-grimmsnarl", "60D0DBFED01230D524A3FFB173C152B0A1F4FDF2E6926614DBABB9ED57ED6316", 800018501, 28],
	["dev.beralee.v18.no-balloon-gardevoir", "FC2245D12044CE0ED92E877ACDA006A2DBD6F406FAE2573363D1C2EB7A69FB90", 800017097, 24],
	["dev.beralee.v18.pure-dragapult", "8CCA6A11C6F04D3267187112112244057ABCCB3073898BBE7027B264AE68D0D9", 800018499, 24],
	["dev.beralee.v18.raging-bolt-ogerpon", "5DEEC95080A537B9BF10B4744050A2C53690486B057E556FBC11E3F55BEDA57A", 800018509, 28],
	["dev.beralee.v18.ns-zoroark", "5ADE7B78A3F43E2537CE8E35FE73E1C63927C1EA0D15963EA5D98EC53664FBD0", 800018502, 29],
	["dev.bodao-yongzhe.marnies-gift-box", "2E21FA1B9EFB1BE38A18C4B4DFA95EFAF5CBD87C3AD3A667E1CD5341D2C93EAC", 646600, 28],
]
const EXECUTION_CASES := [
	["dev.beralee.v18.marnie-grimmsnarl", "60D0DBFED01230D524A3FFB173C152B0A1F4FDF2E6926614DBABB9ED57ED6316", "beralee-marnie-grimmsnarl-development-frame-v1", "beralee.marnie-grimmsnarl.18.0.author-package-v1", "CSV10C_147", "CSV10C_146", "CSV10C_148", "marnie.morgrem.evolve"],
	["dev.beralee.v18.no-balloon-gardevoir", "FC2245D12044CE0ED92E877ACDA006A2DBD6F406FAE2573363D1C2EB7A69FB90", "beralee-no-balloon-gardevoir-development-frame-v1", "beralee.no-balloon-gardevoir.18.0.author-package-v1", "CSV2C_054", "CSV2C_053", "CSV2C_055", "gardevoir.kirlia.evolve"],
	["dev.beralee.v18.pure-dragapult", "8CCA6A11C6F04D3267187112112244057ABCCB3073898BBE7027B264AE68D0D9", "beralee-pure-dragapult-development-frame-v1", "beralee.pure-dragapult.18.0.author-package-v1", "CSV8C_158", "CSV8C_157", "CSV8C_159", "dragapult.drakloak.evolve"],
	["dev.beralee.v18.raging-bolt-ogerpon", "5DEEC95080A537B9BF10B4744050A2C53690486B057E556FBC11E3F55BEDA57A", "ptcgdap-competitive-public-frame-v2", "beralee.raging-bolt-ogerpon.18.0.competitive-v2-round41", "CSV9C_155", "CSV9C_154", "CSV7C_154", "main.noctowl"],
	["dev.beralee.v18.ns-zoroark", "5ADE7B78A3F43E2537CE8E35FE73E1C63927C1EA0D15963EA5D98EC53664FBD0", "beralee-ns-zoroark-development-frame-v1", "beralee.ns-zoroark.18.0.author-package-v1", "CSV10C_145", "CSV10C_144", "CSV10C_145", "ns-zoroark.ex.evolve"],
]


func _selection(row: Array) -> Dictionary:
	return {
		"package_id": row[0],
		"package_version": "1.0.0",
		"archive_sha256": row[1],
		"install_source": "built_in",
	}


func test_reviewed_packages_are_exactly_admitted_and_discoverable() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var checks: Array[String] = []
	for row: Array in EXPECTED:
		var selection := _selection(row)
		var candidate: Dictionary = GateScript.candidate_for_selection(selection)
		checks.append(assert_false(candidate.is_empty(), "Missing exact development candidate %s" % row[0]))
		checks.append(assert_eq(candidate.get("source_deck_id"), row[2]))
		checks.append(assert_eq(candidate.get("unique_printing_count"), row[3]))
		var requested: Dictionary = GateScript.request_match_handle(catalog, selection, "Windows")
		checks.append(assert_true(bool(requested.get("ok", false)), "Package is not locally discoverable: %s (%s)" % [row[0], requested.get("error_code")]))
		var handle: Variant = requested.get("handle")
		checks.append(assert_true(handle != null and handle.validate_integrity(), "Invalid handle for %s" % row[0]))
	catalog.free()
	return run_checks(checks)


func _option(index: int, uid: Variant) -> Dictionary:
	return {
		"index": index,
		"kind": "reviewed_primary",
		"card_uid": uid,
		"card_serial": null,
		"source_uid": null,
		"target_uid": null,
		"target_remaining_hp": null,
		"target_prize_value": null,
		"attached_energy_count": null,
		"attack_index": null,
		"option_number": null,
		"tags": [],
		"option_type_raw": 3,
		"option_card_uid": uid,
		"option_player_index": 0,
		"energy_type_raw": null,
		"energy_count": null,
		"special_condition_type": null,
	}


func _frame(row: Array) -> Dictionary:
	var state := {
		"self": {
			"hand": [{"local_card_uid": row[4]}],
			"active": [{"local_card_uid": row[6]}],
		},
		"opponent": {"hand_count": 0},
	}
	var observation: Dictionary = TreeHashScript.public_observation_hash({
		"schema_version": 1,
		"sequence": 1,
		"seat": 0,
		"prompt_kind": "reviewed_primary",
		"public_state": state,
	})
	var semantics := {
		"min_count": 1,
		"max_count": 1,
		"select_type_raw": 9,
		"select_context_raw": 41,
	}
	var options := [_option(0, null), _option(1, row[5])]
	var window: Dictionary = TreeHashScript.public_observation_hash({
		"public_observation_hash": observation.get("sha256"),
		"select_semantics": semantics,
		"options": options,
	})
	return {
		"schema_version": 1,
		"profile_id": row[2],
		"strategy_id": row[3],
		"card_id_domain": "godot_local_card_uid_v1",
		"sequence": 1,
		"seat": 0,
		"prompt_kind": "reviewed_primary",
		"source": {
			"public_observation_hash": observation.get("sha256"),
			"window_id": window.get("sha256"),
		},
		"public_state": state,
		"select_semantics": semantics,
		"options": options,
	}


func test_reviewed_packages_execute_their_primary_current_window_macro() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var checks: Array[String] = []
	var case_index := 0
	for row: Array in EXECUTION_CASES:
		var requested: Dictionary = GateScript.request_match_handle(
			catalog, _selection(row), "Windows"
		)
		var candidate: Dictionary = GateScript.candidate_for_package_identity(str(row[0]), "1.0.0")
		if candidate.get("runtime_kind") == "reviewed_competitive_policy_v2":
			checks.append(assert_true(bool(requested.get("ok", false)), "Competitive package did not bind for %s" % row[0]))
			case_index += 1
			continue
		var created: Dictionary = GenericPolicyScript.create(
			requested.get("handle"), "reviewed-policy-%d" % case_index
		)
		checks.append(assert_true(bool(created.get("ok", false)), "Policy create failed for %s: %s" % [row[0], created.get("error_code")]))
		var policy: Variant = created.get("policy")
		var selected: Dictionary = policy.select(_frame(row)) if policy != null else {}
		checks.append(assert_true(bool(selected.get("ok", false)), "Policy select failed for %s: %s" % [row[0], selected.get("error_code")]))
		checks.append(assert_eq(selected.get("selected_indexes"), [1], "Wrong selection for %s" % row[0]))
		checks.append(assert_contains(selected.get("matched_rule_ids", []), row[7], "Primary macro did not match for %s" % row[0]))
		case_index += 1
	catalog.free()
	return run_checks(checks)


func test_reviewed_packages_bind_the_generic_engine_owner() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var checks: Array[String] = []
	var opponent: DeckData = CardDatabase.get_deck(575720)
	var case_index := 0
	for row: Array in EXPECTED:
		var deck: DeckData = CardDatabase.get_deck(int(row[2]))
		checks.append(assert_not_null(deck, "Missing exact source deck %s" % row[2]))
		var requested: Dictionary = GateScript.request_match_handle(
			catalog, _selection(row), "Windows"
		)
		var gsm := GameStateMachine.new()
		gsm.start_game(deck, opponent, 0)
		var built: Dictionary = OwnerFactoryScript.build_windows_development_author_owner(
			requested.get("handle"), gsm, 0, "reviewed-owner-%d" % case_index
		)
		checks.append(assert_true(bool(built.get("ok", false)), "Owner bind failed for %s: %s" % [row[0], built.get("error_code")]))
		var owner: Variant = built.get("owner")
		checks.append(assert_eq(
			owner.get_script().resource_path if owner != null else "",
			"res://scripts/ai/ptcgdap/host/godot/ReviewedAuthorStrategyDevelopmentBattleOwner.gd"
		))
		checks.append(assert_true(owner != null and owner.validate_integrity(), "Invalid owner for %s" % row[0]))
		if owner != null:
			var basics: Array[CardInstance] = gsm.game_state.players[0].get_basic_pokemon_in_hand()
			checks.append(assert_true(not basics.is_empty(), "No public setup option for %s" % row[0]))
			if not basics.is_empty():
				var frame: Dictionary = owner._build_frame(
					"setup_active", owner._options_for_items(basics, "setup_active"), 1, 1
				)
				var response: Dictionary = owner._policy.select(frame)
				checks.append(assert_true(bool(response.get("ok", false)), "Actual owner frame rejected for %s: %s" % [row[0], response.get("error_code")]))
			owner.close_match()
		gsm.prepare_for_disposal()
		case_index += 1
	catalog.free()
	return run_checks(checks)


func test_competitive_v2_package_routes_to_reviewed_engine_owner() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var row: Array = EXECUTION_CASES[3]
	var requested: Dictionary = GateScript.request_match_handle(
		catalog, _selection(row), "Windows"
	)
	var deck: DeckData = CardDatabase.get_ai_deck(800018509)
	var gsm := GameStateMachine.new()
	gsm.start_game(deck, deck, 0)
	var built: Dictionary = OwnerFactoryScript.build_windows_development_author_owner(
		requested.get("handle"), gsm, 0, "competitive-v2-reviewed-owner"
	)
	var owner: Variant = built.get("owner")
	var checks: Array[String] = []
	checks.append(assert_true(
		bool(built.get("ok", false)),
		"Competitive v2 owner bind failed: %s" % built.get("error_code")
	))
	checks.append(assert_eq(
		owner.get_script().resource_path if owner != null else "",
		"res://scripts/ai/ptcgdap/host/godot/ReviewedAuthorStrategyDevelopmentBattleOwner.gd"
	))
	if owner != null:
		var initial_turn: Dictionary = owner._build_public_state().get("self", {}).get("turn", {})
		checks.append(assert_eq(initial_turn, {
			"supporter_available": true,
			"manual_attachment_available": true,
			"retreat_available": true,
		}))
		gsm.game_state.supporter_used_this_turn = true
		gsm.game_state.energy_attached_this_turn = true
		gsm.game_state.retreat_used_this_turn = true
		var spent_turn: Dictionary = owner._build_public_state().get("self", {}).get("turn", {})
		checks.append(assert_eq(spent_turn, {
			"supporter_available": false,
			"manual_attachment_available": false,
			"retreat_available": false,
		}))
		owner.close_match()
	gsm.prepare_for_disposal()
	catalog.free()
	return run_checks(checks)


func test_reviewed_packages_render_as_loaded_and_startable_in_battle_setup() -> String:
	AuthorStrategyPackageCatalog.scan_startup()
	var previous_selection: Dictionary = GameManager.get_author_strategy_selection()
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var report := {
		"metadata_records": catalog.list_metadata_records(),
		"ready_records": catalog.list_ready_records(),
		"diagnostics": catalog.list_diagnostics(),
	}
	var scene := BattleSetupScene.instantiate()
	scene.call("_ready")
	scene.call("_apply_author_strategy_catalog_report", report)
	var checks: Array[String] = []
	for row: Array in EXPECTED:
		var selected: bool = bool(scene.call("_select_author_strategy_ref", {
			"package_id": row[0],
			"package_version": "1.0.0",
			"archive_sha256": row[1],
		}))
		checks.append(assert_true(selected, "Battle setup did not list %s" % row[0]))
		checks.append(assert_true(bool(scene.call("_author_strategy_start_allowed")), "Battle setup did not enable %s" % row[0]))
		var record: Dictionary = scene.call("_selected_author_strategy_record")
		checks.append(assert_eq(scene.call("_author_strategy_display_status_label", record), "已加载 · 可开战"))
	scene.free()
	catalog.free()
	GameManager.reset_author_strategy_selection()
	if not previous_selection.is_empty():
		GameManager.set_author_strategy_selection(previous_selection)
	return run_checks(checks)


func test_marnies_gift_box_renders_as_loaded_and_startable_in_battle_setup() -> String:
	AuthorStrategyPackageCatalog.scan_startup()
	var row: Array = EXPECTED[EXPECTED.size() - 1]
	var previous_selection: Dictionary = GameManager.get_author_strategy_selection()
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var report := {
		"metadata_records": catalog.list_metadata_records(),
		"ready_records": catalog.list_ready_records(),
		"diagnostics": catalog.list_diagnostics(),
	}
	var scene := BattleSetupScene.instantiate()
	scene.call("_ready")
	scene.call("_apply_author_strategy_catalog_report", report)
	var selected: bool = bool(scene.call("_select_author_strategy_ref", {
		"package_id": row[0],
		"package_version": "1.0.0",
		"archive_sha256": row[1],
	}))
	scene.call("_select_mode_option", 2)
	scene.call("_refresh_deck_options", false)
	scene.call("_refresh_ai_ui_visibility")
	var record: Dictionary = scene.call("_selected_author_strategy_record")
	var applied: bool = bool(scene.call("_apply_setup_selection"))
	var checks: Array[String] = [
		assert_true(selected, "Battle setup did not list %s" % row[0]),
		assert_true(
			bool(scene.call("_author_strategy_start_allowed")),
			"Battle setup did not enable %s" % row[0]
		),
		assert_eq(scene.call("_author_strategy_display_status_label", record), "已加载 · 可开战"),
		assert_true(applied, "Battle setup did not apply the exact author package selection"),
		assert_eq(GameManager.current_mode, GameManager.GameMode.VS_AUTHOR_STRATEGY_AI),
		assert_eq(GameManager.selected_deck_ids[1], 0),
		assert_eq(
			GameManager.get_author_strategy_selection().get("archive_sha256"),
			row[1]
		),
	]
	scene.free()
	catalog.free()
	GameManager.reset_author_strategy_selection()
	if not previous_selection.is_empty():
		GameManager.set_author_strategy_selection(previous_selection)
	return run_checks(checks)
