class_name TestCardCatalogAudit
extends TestBase

const CardCatalogAuditRunner = preload("res://tests/CardCatalogAudit.gd")

var _cached_report: Dictionary = {}


func test_assignment_smoke_context_uses_selectable_sources_and_legal_targets() -> String:
	var audit := CardCatalogAuditRunner.new()
	var context: Dictionary = {}
	audit.call("_auto_select_step_into_context", {
		"id": "assign", "ui_mode": "card_assignment",
		"source_items": ["energy_a", "energy_b"],
		"source_card_items": ["unselectable_card", "energy_a", "energy_b"],
		"target_items": ["active", "bench"],
		"source_exclude_targets": {0: [0]}, "max_assignments_per_target": 1,
		"min_select": 2, "max_select": 2,
	}, context)
	return assert_eq(context.get("assign"), [
		{"source_index": 0, "source": "energy_a", "target_index": 1, "target": "bench"},
		{"source_index": 1, "source": "energy_b", "target_index": 0, "target": "active"},
	], "Audit assignments must respect selectable cards, exclusions and target capacity")


func test_assignment_smoke_context_respects_single_target_only() -> String:
	var audit := CardCatalogAuditRunner.new()
	var context: Dictionary = {}
	audit.call("_auto_select_step_into_context", {
		"id": "assign", "ui_mode": "card_assignment",
		"source_items": ["energy_a", "energy_b"], "target_items": ["active", "bench"],
		"source_exclude_targets": {0: [0]}, "single_target_only": true,
		"min_select": 2, "max_select": 2,
	}, context)
	var selected: Array = context.get("assign", [])
	return run_checks([
		assert_eq(selected.size(), 2, "Both sources must be assigned"),
		assert_true(selected.all(func(entry: Dictionary) -> bool: return entry.target == "bench"), "All assignments must share the legal target"),
	])


func test_waitress_audit_context_executes_real_trainer_and_attaches_energy() -> String:
	var audit := CardCatalogAuditRunner.new()
	var gsm: GameStateMachine = audit.call("_make_fixture")
	var player := gsm.game_state.players[0]
	var card := CardInstance.create(CardDatabase.get_card("30thDC", "035"), 0)
	player.hand.append(card)
	var effect := gsm.effect_processor.get_effect(card.card_data.effect_id)
	var energy := player.deck[0]
	var target := player.active_pokemon
	var context: Dictionary = audit.call("_auto_select_effect_context", effect, card, gsm.game_state)
	var result := run_checks([
		assert_true(gsm.play_trainer(0, card, [context]), "Audit must submit a valid assignment to the real trainer entry"),
		assert_true(energy in target.attached_energy, "Selected energy must actually reach its target"),
		assert_false(energy in player.deck, "Attached energy must leave the deck"),
		assert_true(card in player.discard_pile, "Successfully played supporter must be discarded"),
	])
	gsm.prepare_for_disposal()
	return result


func test_cached_cards_have_registry_and_smoke_coverage() -> String:
	if _cached_report.is_empty():
		_cached_report = CardCatalogAuditRunner.new().run()
		print(_cached_report.get("report_text", ""))

	var registry_failures: Array = _cached_report.get("registry_failures", [])
	var smoke_failures: Array = _cached_report.get("smoke_failures", [])
	var status_matrix_text: String = str(_cached_report.get("status_matrix_text", ""))
	var failure_parts: Array[String] = []

	if not registry_failures.is_empty():
		failure_parts.append("registry=%d" % registry_failures.size())
	if not smoke_failures.is_empty():
		failure_parts.append("smoke=%d" % smoke_failures.size())

	return run_checks([
		assert_gt(int(_cached_report.get("cached_cards", 0)), 0, "Should discover cached cards"),
		assert_true(status_matrix_text.contains("Card Status Matrix"), "Should generate status matrix report"),
		assert_true(failure_parts.is_empty(), "Card catalog audit failed: %s" % ", ".join(failure_parts)),
	])


func test_attack_only_pokemon_interaction_status_uses_attack_steps() -> String:
	var audit := CardCatalogAuditRunner.new()
	var dragapult_ex := _make_pokemon_card(
		"Dragapult ex",
		"Stage 2",
		"52a205820de799a53a689f23cbeb8622",
		[
			{"name": "Jet Headbutt", "cost": "C", "damage": "70", "text": "", "is_vstar_power": false},
			{"name": "Phantom Dive", "cost": "RP", "damage": "200", "text": "Put 6 damage counters on your opponent's Benched Pokemon in any way you like.", "is_vstar_power": false},
		]
	)
	var haxorus := _make_pokemon_card(
		"Haxorus",
		"Stage 2",
		"e45788bd7d9ffec5b3da3730d2dc806f",
		[
			{"name": "Axe Down", "cost": "F", "damage": "", "text": "If your opponent's Active Pokemon has any Special Energy attached, it is Knocked Out.", "is_vstar_power": false},
			{"name": "Dragon Pulse", "cost": "FM", "damage": "230", "text": "Discard the top 3 cards of your deck.", "is_vstar_power": false},
		]
	)

	return run_checks([
		assert_eq(audit.call("_inspect_interaction_status", dragapult_ex), "present", "Attack-only cards with target selection should report present interaction"),
		assert_eq(audit.call("_inspect_interaction_status", haxorus), "none", "Attack-only cards without player choice should report none"),
	])


func test_catalog_only_cards_are_included_in_full_card_audit() -> String:
	# The real catalog can become fully bundled. Keep a separate catalog-only
	# record so this still tests lazy materialization rather than a fixed UID.
	var root := "user://test_card_catalog_audit"
	var card := _make_pokemon_card("Audit Catalog Only", "Basic", "", [])
	card.set_code = "AUDITONLY"
	card.card_index = "001"
	var uid := card.get_uid()
	var card_dict := card.to_dict()
	var entry := card_dict.duplicate(true)
	entry["uid"] = uid
	entry["set_file"] = "sets/AUDITONLY.json"
	var documents := {
		"catalog_manifest.json": {
			"schema_version": 3, "catalog_version": "1.0.0", "card_count": 1,
			"index_file": {"path": "index.json", "sha256": ""},
			"sets": [{"set_code": "AUDITONLY", "path": "sets/AUDITONLY.json", "card_count": 1, "sha256": ""}],
			"sources": [],
		},
		"index.json": {"schema_version": 3, "catalog_version": "1.0.0", "cards": [entry]},
		"sets/AUDITONLY.json": {"schema_version": 1, "set_code": "AUDITONLY", "cards": [card_dict]},
	}
	for relative_path: String in documents:
		var path := root.path_join(relative_path)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return "Could not create the isolated catalog-only fixture"
		file.store_string(JSON.stringify(documents[relative_path]))
		file.close()
	var saved_catalog: Variant = CardDatabase.get("_card_catalog_index")
	var saved_cache: Dictionary = CardDatabase.get("_card_cache").duplicate()
	CardDatabase.set_card_catalog_index_for_tests(CardCatalogIndex.new(root, root.path_join("unused")))
	var already_materialized := false
	for existing: CardData in CardDatabase.get_all_cards():
		if existing.get_uid() == uid:
			already_materialized = true
	var audit := CardCatalogAuditRunner.new()
	var cards: Array = audit.call("_load_cached_cards")
	var found := false
	for raw_card: Variant in cards:
		if raw_card is CardData and (raw_card as CardData).get_uid() == uid:
			found = true
			break
	CardDatabase.set_card_catalog_index_for_tests(saved_catalog)
	CardDatabase.set("_card_cache", saved_cache)
	return run_checks([
		assert_false(already_materialized, "The fixture must only exist in the lazy catalog before the audit"),
		assert_true(found, "Full card audit should explicitly materialize catalog-only cards"),
		assert_false(FileAccess.file_exists("res://data/bundled_user/cards/%s.json" % uid), "Audit coverage must not require promoting catalog-only cards into bundled user data"),
		assert_false(FileAccess.file_exists("user://cards/%s.json" % uid), "Auditing must not persist catalog-only cards into the user cache"),
	])


func _make_pokemon_card(
	name: String,
	stage: String,
	effect_id: String,
	attacks: Array
) -> CardData:
	var card_data := CardData.new()
	var attack_list: Array[Dictionary] = []
	for attack: Variant in attacks:
		if attack is Dictionary:
			attack_list.append(attack)
	card_data.name = name
	card_data.name_en = name
	card_data.card_type = "Pokemon"
	card_data.energy_type = "N"
	card_data.hp = 200
	card_data.stage = stage
	card_data.effect_id = effect_id
	card_data.attacks = attack_list
	return card_data
