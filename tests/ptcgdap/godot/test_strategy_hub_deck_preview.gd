extends TestBase

const HubScene = preload("res://scenes/ptcgdap_strategy_hub/StrategyHub.tscn")
const Materializer = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyDeckMaterializer.gd")
const Fixture = preload("res://tests/ptcgdap/godot/test_author_strategy_windows_player_owner.gd")

class PreviewCatalog extends RefCounted:
	var handle: Variant
	var calls: Array = []
	func request_match_handle(id: String, version: String, sha: String) -> Dictionary:
		calls.append([id, version, sha])
		return {"ok": handle != null, "handle": handle}

func test_downloaded_strategy_details_show_exact_deck_and_clear_on_navigation() -> String:
	var hub := HubScene.instantiate()
	if hub.get_node_or_null("%StrategyDeckGrid") == null:
		hub.free()
		return "Strategy details must include an inline deck image grid"
	var inspected: Dictionary = Fixture.PackageLoaderScript.new().inspect_control_distributed_player_match_bytes(
		FileAccess.get_file_as_bytes(Fixture.CONTROL_PLAYER_FIXTURE), FileAccess.get_sha256(Fixture.CONTROL_PLAYER_FIXTURE).to_upper())
	var gated: Dictionary = Fixture.PackageDeckGateScript.build(inspected.get("payloads", {}))
	var created: Dictionary = Fixture.PackageHandleScript.create(inspected.get("metadata", {}), inspected.get("payloads", {}), gated.get("local_deck", []))
	if not created.get("ok", false):
		hub.free()
		return "Local package fixture failed"
	var catalog := PreviewCatalog.new()
	catalog.handle = created.handle
	hub.set("_package_preview_catalog_override", catalog)
	hub.call("apply_local_package_catalog_for_test", {"metadata_records": [inspected.metadata], "ready_records": [], "diagnostics": []})
	var record: Dictionary = hub.get("_local_package_records")[0]
	var reference: Dictionary = record.stable_ref
	var detail_button := hub.get_node("%LocalPackageList").find_child("LocalPackageDetailButton", true, false) as Button
	if detail_button == null:
		hub.free()
		return "Downloaded strategy needs a details entry"
	detail_button.pressed.emit()
	var grid := hub.get_node("%StrategyDeckGrid") as GridContainer
	var total := 0
	for tile: Node in grid.get_children():
		total += int(tile.get_meta("deck_view_count", 0))
	var expected: DeckData = Materializer.build(created.handle).deck
	var checks: Array[String] = [
		assert_true(hub.get_node("%StrategyDeckSection").visible),
		assert_eq(grid.get_child_count(), expected.cards.size()),
		assert_eq(total, 60),
		assert_eq(catalog.calls, [[reference.package_id, reference.package_version, reference.archive_sha256]]),
		assert_str_contains(hub.get_node("%StrategyDeckTitle").text, "60"),
	]
	hub.call("_open_strategy_detail")
	checks.append(assert_false(hub.get_node("%StrategyDeckSection").visible))
	checks.append(assert_eq(grid.get_child_count(), 0))
	var wrong := reference.duplicate()
	wrong.archive_sha256 = "A".repeat(64)
	hub.call("_update_strategy_deck_preview", wrong)
	checks.append(assert_false(hub.get_node("%StrategyDeckSection").visible))
	checks.append(assert_eq(catalog.calls.size(), 1, "Do not substitute another installed version"))
	hub.call("_show_marketplace_strategy", {"display_name": "Downloaded", "installable_release": reference})
	checks.append(assert_eq(grid.get_child_count(), expected.cards.size(), "Marketplace details reuse the installed deck"))
	catalog.handle = null
	hub.call("_update_strategy_deck_preview", reference)
	checks.append(assert_eq(grid.get_child_count(), 0, "Failed inspection must not retain the old card art"))
	checks.append(assert_str_contains(hub.get_node("%StrategyDeckTitle").text, "无法读取"))
	hub.free()
	return run_checks(checks)


func test_inline_deck_grid_fits_phone_and_desktop_widths() -> String:
	var view = preload("res://scripts/ui/decks/DeckViewDialog.gd").new()
	var deck := DeckData.new()
	deck.cards = [{"name": "Basic Energy", "set_code": "CSVE1C", "card_index": "GRA", "count": 60}]
	var grid := GridContainer.new()
	var checks: Array[String] = []
	for width: float in [280.0, 342.0, 880.0, 1450.0]:
		view.populate_preview_grid(grid, deck, width, width != 880.0)
		var tile := grid.get_child(0) as Control
		var required := tile.get_combined_minimum_size().x * grid.columns + grid.get_theme_constant("h_separation") * (grid.columns - 1)
		checks.append(assert_true(required <= width, "Card grid must fit %.0f px, got %.0f" % [width, required]))
		checks.append(assert_eq(tile.get_meta("deck_view_count"), 60))
	grid.free()
	return run_checks(checks)
