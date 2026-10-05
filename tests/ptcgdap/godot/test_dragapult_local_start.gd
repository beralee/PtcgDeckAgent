extends TestBase

const Gate = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsExecutionGate.gd")
const Installer = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageInstaller.gd")
const Loader = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd")
const Catalog = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd")
const Materializer = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyDeckMaterializer.gd")
const Owner = preload("res://scripts/ai/ptcgdap/host/godot/ReviewedAuthorStrategyDevelopmentBattleOwner.gd")
const HubScene = preload("res://scenes/ptcgdap_strategy_hub/StrategyHub.tscn")
const Selection := {"package_id": "dev.dragapult-dusknoir", "package_version": "0.29.0", "archive_sha256": "AD8396CA9C9D15058A9507D4D2CA450636E638CE4298B12902D232C515531629", "install_source": "user"}

func test_exact_installed_dragapult_passes_start_gate_and_binds_real_engine() -> String:
	var catalog := Catalog.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(catalog)
	var bytes := FileAccess.get_file_as_bytes("res://tests/ptcgdap/fixtures/strategy_profiles/dragapult-0.29.0.ptcgai")
	var installed := Installer.new().install_local_bytes(catalog, Loader.new(), bytes)
	if not installed.get("ok", false):
		catalog.free()
		return "install failed: " + str(installed.get("error_code"))
	var admitted := Gate.evaluate_selection(catalog, Selection)
	if not admitted.get("ok", false):
		catalog.free()
		return "start gate: " + str(admitted.get("error_code"))
	var requested := await Gate.request_match_handle_async(catalog, Selection)
	if not requested.get("ok", false):
		catalog.free()
		return "handle gate: " + str(requested.get("error_code"))
	var handle: Variant = requested.get("handle")
	var deck_result := Materializer.build(handle)
	if not deck_result.get("ok", false):
		catalog.free()
		return "deck: " + str(deck_result.get("error_code"))
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(19303001)
	var gsm := GameStateMachine.new()
	gsm.start_game(deck_result.deck, deck_result.deck, 0)
	var created := Owner.create(handle, gsm, 0, "dragapult-local-start-test")
	assert_true(created.get("ok", false), "real engine owner: " + str(created.get("error_code")))
	if created.get("ok", false):
		assert_true(created.owner.is_ready())
		created.owner.close_match()
	assert_false(handle.to_public_dict().get("execution_trusted", true))
	assert_eq(requested.get("authority_mode"), Gate.DEVELOPMENT_MODE)
	var hub := HubScene.instantiate()
	hub.set("_skip_service_initialization_for_tests", true)
	hub.call("_apply_local_package_catalog", installed.get("catalog_report", {}))
	hub.call("_on_local_strategy_detail", Selection)
	assert_false(hub.get_node("%SelectedDownloadButton").disabled, "Admitted package exposes start action")
	assert_false(str(hub.get_node("%SummaryLabel").text).contains("无法开战"))
	hub.free()
	gsm.prepare_for_disposal()
	seed_owner.clear_forced_shuffle_seed()
	catalog.free()
	return ""

func test_registration_remains_bound_to_exact_version_bytes_and_source() -> String:
	for field: String in ["package_id", "package_version", "archive_sha256", "install_source"]:
		var changed := Selection.duplicate(true)
		changed[field] = "unregistered"
		var result := Gate.evaluate_selection(null, changed)
		assert_false(result.get("ok", false), field)
		assert_eq(result.get("error_code"), "development_candidate_not_authorized")
	return ""

func test_baseline_registered_and_unqualified_platform_blocked() -> String:
	var baseline := Selection.merged({"package_version": "0.23.0", "archive_sha256": "5CB6E610DBC98F770BC545101EE2387FF2F25F6DA8442BBC419FEFE84A09DA20"}, true)
	assert_true(Gate.evaluate_selection(null, baseline).get("ok", false))
	for platform: String in ["Android", "macOS", "Web", "Linux"]:
		var result := Gate.evaluate_selection(null, Selection, platform)
		assert_false(result.get("ok", false), platform)
		assert_eq(result.get("error_code"), "development_platform_not_authorized")
	return ""

func test_unregistered_package_explains_block_on_card_and_detail() -> String:
	var hub := HubScene.instantiate()
	hub.set("_skip_service_initialization_for_tests", true)
	var denied := {"ok": false, "error_code": "development_candidate_not_authorized"}
	var explanation: String = hub.call("_local_package_unavailable_text", denied)
	assert_true(explanation.contains("开发包") and explanation.contains("登记"), explanation)
	var report := {"metadata_records": [Selection.merged({"archive_sha256": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", "status": "metadata_only", "strategy": {"display_name": "未登记开发策略"}}, true)], "ready_records": [], "diagnostics": []}
	hub.call("_apply_local_package_catalog", report)
	var labels: Array[String] = []
	for label: Node in hub.find_children("*", "Label", true, false):
		labels.append(str(label.get("text")))
	assert_true("\n".join(labels).contains("开发包"), "Local card must show the actual block reason")
	var records: Array = hub.get("_local_package_records")
	if not records.is_empty():
		hub.call("_on_local_strategy_detail", records[0].stable_ref)
		assert_true(str(hub.get_node("%SummaryLabel").text).contains("开发包"), "Detail must explain why start is disabled")
		assert_true(hub.get_node("%SelectedDownloadButton").disabled)
	var unknown: String = hub.call("_local_package_unavailable_text", {"ok": false, "error_code": "future_gate_reason"})
	assert_true(unknown.contains("future_gate_reason"), "Unknown failures retain a diagnosable error code")
	hub.free()
	return ""
