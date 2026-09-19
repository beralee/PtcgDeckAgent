extends TestBase

const Flow = preload("res://tests/ptcgdap/godot/test_strategy_hub_desktop_flow.gd")

func test_installed_ladder_entry_starts_local_archive_without_network() -> String:
	var hub := Flow.HubScene.instantiate()
	hub.set_script(Flow.HubProbe)
	var client := Flow.Client.new()
	hub.add_child(client)
	hub.set("_client", client)
	var installer := Flow.Installer.new()
	var report: Dictionary = installer.install_from_bytes(PackedByteArray(), Flow.REF).catalog_report
	hub.call("apply_local_package_catalog_for_test", report)
	hub.call("apply_continuous_ladder_leaderboard_for_test", [{"release_id": "listed.release", "owner_kind": "developer", "package_id": Flow.REF.package_id, "package_version": Flow.REF.package_version, "display_name": "Different display name", "rank": 1}], "test")
	var button := hub.find_child("LadderDownloadButton", true, false) as Button
	var checks: Array[String] = [assert_eq(button.text, "对战"), assert_false(button.disabled)]
	button.pressed.emit()
	checks.append(assert_eq(hub.get("started_ref"), Flow.REF))
	checks.append(assert_eq(client.profiles, []))
	checks.append(assert_eq(client.downloads, []))
	hub.call("apply_local_package_catalog_for_test", {"metadata_records": [], "ready_records": []})
	checks.append(assert_eq(button.get_meta("start_strategy_ref", {}), {}))
	checks.append(assert_eq(button.text, "一键下载安装"))
	hub.call("apply_local_package_catalog_for_test", report)
	checks.append(assert_eq(button.text, "对战", "Late catalogue scans must refresh the existing row"))
	hub.free()
	return run_checks(checks)

func test_listing_identity_requires_unique_id_version_and_honors_explicit_hash() -> String:
	var hub := Flow.HubScene.instantiate()
	var installer := Flow.Installer.new()
	var report: Dictionary = installer.install_from_bytes(PackedByteArray(), Flow.REF).catalog_report
	hub.call("apply_local_package_catalog_for_test", report)
	var other := Flow.REF.merged({"archive_sha256": "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"}, true)
	var listing := {"package_id": Flow.REF.package_id, "package_version": Flow.REF.package_version}
	var checks: Array[String] = [
		assert_eq(hub.call("_local_package_record_for_listing", {"display_name": "测试卡组"}), {}),
		assert_eq(hub.call("_local_package_record_for_listing", listing.merged({"package_version": "2.0.0"}, true)).stable_ref, Flow.REF, "A unique installed version must not be replaced just to play"),
		assert_eq(hub.call("_local_package_record_for_listing", other), {}),
	]
	report.metadata_records.append(other.merged({"status": "metadata_only", "install_source": "user"}))
	hub.call("apply_local_package_catalog_for_test", report)
	checks.append(assert_eq(hub.call("_local_package_record_for_listing", listing), {}, "Conflicting local archives must not choose arbitrarily"))
	checks.append(assert_eq(hub.call("_local_package_record_for_listing", Flow.REF).stable_ref, Flow.REF))
	hub.free()
	return run_checks(checks)

func test_portal_action_uses_exact_homepage_and_reports_browser_failure() -> String:
	var hub := Flow.HubScene.instantiate()
	var opened: Array = []
	hub.set("_developer_portal_opener_override", func(url: String) -> int: opened.append(url); return OK)
	hub.call("_on_developer_portal_pressed")
	var checks: Array[String] = [assert_eq(opened, ["https://ptcg.skillserver.cn/dist/developers.html"])]
	hub.call("select_workspace_for_test", "replays")
	hub.set("_developer_portal_opener_override", func(_url: String) -> int: return ERR_CANT_OPEN)
	hub.call("_on_developer_portal_pressed")
	checks.append(assert_true(hub.get_node("%StatusStrip").visible))
	checks.append(assert_str_contains(hub.get_node("%StatusLabel").text, "https://ptcg.skillserver.cn/dist/developers.html"))
	hub.free()
	return run_checks(checks)

func test_developer_onboarding_is_available_on_desktop_android_and_web() -> String:
	var hub := Flow.HubScene.instantiate()
	if hub.get_node_or_null("%DeveloperPortalButton") == null:
		hub.free()
		return "Developer workspace must include its portal entry"
	var checks: Array[String] = []
	for platform: String in ["Windows", "Android", "Web"]:
		hub.call("_configure_replay_platform", platform)
		hub.call("apply_non_battle_layout_for_test", Vector2(900, 1800) if platform != "Windows" else Vector2(1600, 900), "portrait" if platform != "Windows" else "landscape")
		hub.call("select_workspace_for_test", "replays")
		checks.append(assert_true(hub.get_node("%ReplayTab").visible))
		checks.append(assert_eq(hub.get_node("%ReplayTab").text, "开发者"))
		checks.append(assert_true(hub.get_node("%ReplayWorkspace").visible))
		checks.append(assert_true(hub.get_node("%DeveloperIntro").visible))
		checks.append(assert_eq(hub.find_child("LocalReplayScroll", true, false).visible, platform == "Windows"))
		checks.append(assert_eq(hub.get_node("%DeveloperPortalButton").tooltip_text, "https://ptcg.skillserver.cn/dist/developers.html"))
	hub.free()
	return run_checks(checks)
