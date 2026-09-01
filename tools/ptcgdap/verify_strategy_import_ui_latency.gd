extends Node

const HubScene = preload("res://scenes/ptcgdap_strategy_hub/StrategyHub.tscn")
const EXPECTED_PACKAGE_ID := "dev.beralee.v18.ogerpon-crustle-v523a"
const EXPECTED_VERSION := "1.4.0"
const EXPECTED_SHA := "3B4E78A16EB2C238CD9CFB29CA29B8CF44E0D7D99822CA9C1ECD90A2651DFFB8"
const MAX_CLICK_TO_INSTALLED_MSEC := 5000


func _ready() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var hub := HubScene.instantiate()
	add_child(hub)
	var status := await _wait_for_status(hub, "已连接 godot_v18_ladder_v1", 30_000)
	var release_button := _find_button(
		hub, "ContinuousLadderReleaseButton", "厄诡椪/岩殿居蟹"
	)
	if release_button != null:
		release_button.emit_signal("pressed")
		status = await _wait_for_status(hub, "策略档案已加载", 10_000)
	var download := hub.get_node_or_null("%SelectedDownloadButton") as Button
	var click_started_usec := Time.get_ticks_usec()
	if download != null and download.visible and not download.disabled:
		download.emit_signal("pressed")
		status = await _wait_for_status(hub, "策略安装完成", 10_000)
	var click_elapsed_usec := maxi(0, Time.get_ticks_usec() - click_started_usec)
	var installed_record: Dictionary = {}
	for record: Dictionary in AuthorStrategyPackageCatalog.list_metadata_records():
		if record.get("package_id") == EXPECTED_PACKAGE_ID \
				and record.get("package_version") == EXPECTED_VERSION \
				and record.get("archive_sha256") == EXPECTED_SHA:
			installed_record = record.duplicate(true)
			break
	var accepted: bool = status.begins_with("策略安装完成") \
		and click_elapsed_usec <= MAX_CLICK_TO_INSTALLED_MSEC * 1000 \
		and "user" in installed_record.get("install_sources", [])
	print("PTCGDAP_STRATEGY_IMPORT_UI_LATENCY=" + JSON.stringify({
		"accepted": accepted,
		"document_type": "ptcgdap_strategy_import_ui_latency_v1",
		"schema_version": 1,
		"status": status,
		"click_elapsed_usec": click_elapsed_usec,
		"max_click_to_installed_msec": MAX_CLICK_TO_INSTALLED_MSEC,
		"download_button_found": download != null,
		"catalog_discoverable": not installed_record.is_empty(),
		"user_install_source": "user" in installed_record.get("install_sources", []),
		"package_id": EXPECTED_PACKAGE_ID,
		"package_version": EXPECTED_VERSION,
		"archive_sha256": EXPECTED_SHA,
	}))
	hub.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if accepted else 1)


func _wait_for_status(hub: Node, prefix: String, timeout_msec: int) -> String:
	var deadline := Time.get_ticks_msec() + timeout_msec
	var status := ""
	while Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.05).timeout
		var snapshot: Dictionary = hub.call("workspace_status_snapshot")
		status = str(snapshot.get("catalog", {}).get("text", ""))
		if status.begins_with(prefix) \
				or bool(snapshot.get("catalog", {}).get("error", false)):
			break
	return status


func _find_button(root: Node, node_name: String, fragment: String) -> Button:
	for node: Node in root.find_children(node_name, "Button", true, false):
		var button := node as Button
		if fragment in button.text:
			return button
	return null
