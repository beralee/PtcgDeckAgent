extends TestBase

const HubScene = preload("res://scenes/ptcgdap_strategy_hub/StrategyHub.tscn")
const HubScript = preload("res://scenes/ptcgdap_strategy_hub/StrategyHub.gd")
const REF = {"package_id": "desktop.flow", "package_version": "1.0.0", "archive_sha256": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}

class HubProbe extends HubScript:
	var started_ref: Dictionary = {}
	var import_requested := false
	func _on_import_local_package_pressed() -> void:
		import_requested = true
	func _local_package_can_start(_record: Dictionary) -> bool:
		return true
	func _on_local_strategy_start(reference: Dictionary) -> void:
		started_ref = reference.duplicate(true)

class Client extends Node:
	var downloads: Array = []
	var profiles: Array = []
	func fetch_continuous_ladder_release_profile(id: String) -> Dictionary:
		profiles.append(id)
		return {"accepted": true}
	func download_continuous_ladder_release(release: Dictionary) -> Dictionary:
		return download_marketplace_release(release)
	func download_marketplace_release(release: Dictionary) -> Dictionary:
		downloads.append(release.duplicate(true))
		return {"accepted": true}

class Installer extends RefCounted:
	var expected: Dictionary = {}
	func install_from_bytes(_bytes: PackedByteArray, release: Dictionary) -> Dictionary:
		expected = release.duplicate(true)
		return {"ok": true, "catalog_report": {"metadata_records": [release.merged({"install_source": "user", "status": "metadata_only", "strategy": {"display_name": "测试卡组"}})], "ready_records": [], "diagnostics": []}}

func test_desktop_discovery_prioritizes_rankings_and_import() -> String:
	var hub := HubScene.instantiate()
	if hub.get_node_or_null("%QuickImportButton") == null:
		hub.free()
		return "Desktop discovery needs a visible import action above the library"
	hub.call("_apply_hud_theme")
	hub.call("apply_non_battle_layout_for_test", Vector2(1600, 900), "landscape")
	hub.call("select_workspace_for_test", "catalog")
	var checks := run_checks([
		assert_eq(hub.get("_active_marketplace_board"), "strategy_rankings"),
		assert_true(hub.get_node("%QuickImportButton").visible),
		assert_false(hub.get_node("%HeaderSubtitle").visible),
		assert_false(hub.get_node("%StatusStrip").visible),
		assert_false(hub.find_child("LocalPackageFolderRow", true, false).visible),
	])
	hub.free()
	return checks

func test_desktop_download_becomes_exact_start_action_on_card_and_detail() -> String:
	var hub := HubScene.instantiate()
	hub.set_script(HubProbe)
	var client := Client.new()
	hub.add_child(client)
	hub.set("_client", client)
	var installer := Installer.new()
	hub.call("configure_marketplace_install_catalog_for_test", installer)
	hub.call("apply_non_battle_layout_for_test", Vector2(1600, 900), "landscape")
	var item := {"display_name": "测试卡组", "download_available": true, "installable_release": REF}
	hub.call("apply_marketplace_latest_for_test", [item], null)
	var button := hub.find_child("MarketplaceDownloadButton", true, false) as Button
	button.pressed.emit()
	hub.call("apply_marketplace_package_download_for_test", {"accepted": true, "package_bytes": PackedByteArray([1]), "expected_release": REF})
	var checks: Array[String] = [assert_eq(client.downloads, [REF]), assert_eq(installer.expected, REF),
		assert_eq(button.text, "对战"), assert_false(button.disabled)]
	button.pressed.emit()
	checks.append(assert_eq(hub.get("started_ref"), REF))
	checks.append(assert_eq(client.downloads.size(), 1, "Starting an installed strategy must not download again"))
	hub.call("show_marketplace_strategy_for_test", item)
	checks.append(assert_eq(hub.get_node("%SelectedDownloadButton").text, "对战"))
	checks.append(assert_eq(hub.get_node("%SelectedDownloadButton").get_meta("start_strategy_ref", {}), REF))
	hub.free()
	return run_checks(checks)

func test_ladder_one_click_resolves_exact_release_before_installing() -> String:
	var hub := HubScene.instantiate()
	var client := Client.new()
	hub.add_child(client)
	hub.set("_client", client)
	hub.call("apply_continuous_ladder_leaderboard_for_test", [{"release_id": "ranked.release", "owner_kind": "developer", "display_name": "榜单策略", "rank": 1}], "test")
	var button := hub.find_child("LadderDownloadButton", true, false) as Button
	if button == null:
		hub.free()
		return "Ladder must have a direct install action"
	button.pressed.emit()
	button.pressed.emit()
	var checks: Array[String] = [assert_eq(client.profiles, ["ranked.release"]), assert_eq(client.downloads, [])]
	hub.call("apply_continuous_ladder_release_profile_for_test", {"release": {"release_id": "wrong.release", "owner_kind": "developer", "download_available": true, "installable_release": REF}})
	checks.append(assert_eq(client.downloads, [], "A different profile must not trigger download"))
	checks.append(assert_false(button.disabled))
	button.pressed.emit()
	hub.call("apply_continuous_ladder_release_profile_for_test", {"release": {"release_id": "ranked.release", "owner_kind": "developer", "download_available": true, "installable_release": REF}})
	checks.append(assert_eq(client.downloads, [REF]))
	checks.append(assert_eq(button.text, "下载中…"))
	hub.call("_finish_marketplace_download_button", false)
	checks.append(assert_false(button.disabled))
	checks.append(assert_eq(button.text, "重试下载"))
	hub.free()
	return run_checks(checks)

func test_desktop_library_remains_visible_and_quick_import_opens_local_flow() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	tree.root.add_child(viewport)
	var hub := HubScene.instantiate()
	hub.set_script(HubProbe)
	hub.set("_skip_service_initialization_for_tests", true)
	viewport.add_child(hub)
	for frame: int in 5:
		await tree.process_frame
	var installer := Installer.new()
	hub.call("apply_local_package_catalog_for_test", installer.install_from_bytes(PackedByteArray(), REF).catalog_report)
	hub.call("select_workspace_for_test", "catalog")
	hub.get_node("%QuickImportButton").pressed.emit()
	for frame: int in 4:
		await tree.process_frame
	var card := hub.find_child("LocalPackageCard", true, false) as Control
	var checks := run_checks([
		assert_true(hub.get("import_requested")),
		assert_eq(hub.get("_active_workspace"), "local"),
		assert_true(card.size.y > 100, "The library must not collapse its inner scroll to zero height"),
		assert_true(card.get_global_rect().end.y < 900),
		assert_true(hub.get_node("%QuickImportButton").get_global_rect().end.x <= 1600),
	])
	viewport.queue_free()
	await tree.process_frame
	return checks
