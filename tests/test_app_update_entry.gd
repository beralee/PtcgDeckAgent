extends TestBase

const DATA := "windows update entry fixture"

class EntryUpdater extends "res://tests/mocks/MockAppUpdater.gd":
	var at_home := true
	var unavailable := ""
	func _ready() -> void:
		pass
	func _on_home_screen() -> bool:
		return at_home
	func _install_availability() -> String:
		return unavailable

class Menu extends "res://scenes/main_menu/MainMenu.gd":
	func _ready() -> void:
		pass # Exercise the real update controls without startup networking/prewarm.
	func _apply_non_battle_layout(_viewport_size := Vector2.ZERO, _layout_mode := "") -> void:
		pass

class SceneUpdater extends "res://scripts/update/AppUpdater.gd":
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _is_editor_runtime() -> bool:
		return false


func _fixture(actual_scene_check := false) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var original_scene := tree.current_scene
	var original := tree.root.get_node("AppUpdater")
	original.name = "SavedAppUpdater"
	var updater: Node = SceneUpdater.new() if actual_scene_check else EntryUpdater.new()
	updater.name = "AppUpdater"
	tree.root.add_child(updater)
	updater.set_process(false) # Tests inspect the rehash gate before any OS launch.
	updater.offer({"latest_version": "99.0.0", "artifact": {
		"arch": "x86_64", "format": "windows_zip", "entry": "Game.exe",
		"url": "https://ptcg.skillserver.cn/dist/updates/test.zip",
		"sha256": DATA.sha256_text(), "size": DATA.to_utf8_buffer().size(),
	}})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://app_updates"))
	var file := FileAccess.open(updater._package_path(), FileAccess.WRITE)
	file.store_string(DATA)
	file.close()
	updater._state = "ready"
	var menu := Menu.new()
	menu.scene_file_path = "res://scenes/main_menu/MainMenu.tscn"
	tree.root.add_child(menu)
	tree.current_scene = menu
	menu._ensure_corner_action_buttons()
	updater.changed.connect(menu._on_app_update_state_changed)
	menu._on_app_update_state_changed(updater.snapshot())
	return {"original": original, "updater": updater, "menu": menu, "original_scene": original_scene}


func _dispose(fixture: Dictionary) -> void:
	var path: String = fixture.updater._package_path()
	(Engine.get_main_loop() as SceneTree).current_scene = fixture.original_scene
	fixture.menu.free()
	fixture.updater.free()
	fixture.original.name = "AppUpdater"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_single_home_entry_starts_install_rehash_on_first_click() -> String:
	var fixture := _fixture()
	var updater: Node = fixture.updater
	var button: Button = fixture.menu._update_button
	var checks: Array[String] = [assert_str_contains(button.text, "安装", "Home entry offers installation")]
	button.pressed.emit()
	checks.append(assert_eq(updater.snapshot().state, "verifying", "Home click starts installation rehash"))
	checks.append(assert_eq(updater._after_verify, "install", "Click authorizes install after rehash"))
	checks.append(assert_true(updater._install.is_empty(), "No helper before hash verification"))
	checks.append(assert_true(updater.has_open_dialog(), "Show progress while preparing restart"))
	button.pressed.emit()
	checks.append(assert_eq(updater._open_dialogs.size(), 1, "Repeated clicks cannot stack dialogs"))
	checks.append(assert_eq(updater._open_dialogs[0].get_ref().get_parent(), fixture.menu, "Update UI belongs to the home scene"))
	_dispose(fixture)
	return run_checks(checks)


func test_stale_home_entry_cannot_open_update_ui_during_battle() -> String:
	var fixture := _fixture()
	fixture.updater.at_home = false
	fixture.updater.activate_update_entry()
	var result := run_checks([
		assert_eq(fixture.updater.snapshot().state, "ready", "Battle cannot start an update"),
		assert_eq(fixture.updater._after_verify, "ready", "No install authority during battle"),
		assert_false(fixture.updater.has_open_dialog(), "No update dialog may interrupt the battle"),
	])
	_dispose(fixture)
	return result


func test_editor_ready_entries_explain_unavailable_installation() -> String:
	var fixture := _fixture()
	fixture.updater.unavailable = "编辑器中请使用已导出的游戏安装更新。"
	fixture.updater._emit()
	var checks: Array[String] = [
		assert_false("点击安装" in fixture.menu._update_button.text, "Menu must not offer editor self-replacement"),
	]
	fixture.menu._update_button.pressed.emit()
	checks.append(assert_eq(fixture.updater.snapshot().state, "ready", "Editor stays open"))
	checks.append(assert_true(fixture.updater.has_open_dialog(), "Unavailable install has a visible explanation"))
	if fixture.updater.has_open_dialog():
		var dialog: Control = fixture.updater._open_dialogs[0].get_ref()
		checks.append(assert_str_contains(dialog._status.text, "编辑器", "Explain unsupported launch mode"))
		checks.append(assert_true(dialog._primary.disabled, "Never replace the Godot editor executable"))
	_dispose(fixture)
	return run_checks(checks)


func test_ready_entry_rejects_cached_bytes_changed_since_download() -> String:
	var fixture := _fixture()
	var file := FileAccess.open(fixture.updater._package_path(), FileAccess.WRITE)
	file.store_string("x".repeat(DATA.length()))
	file.close()
	fixture.menu._update_button.pressed.emit()
	fixture.updater._verify_step()
	var result := run_checks([
		assert_eq(fixture.updater.snapshot().state, "failed", "Click must rehash and reject changed bytes"),
		assert_true(fixture.updater._install.is_empty(), "Changed bytes must never launch installer"),
	])
	_dispose(fixture)
	return result


func test_update_ui_is_destroyed_with_home_and_cannot_enter_battle() -> String:
	var fixture := _fixture(true)
	var tree := Engine.get_main_loop() as SceneTree
	var updater: Node = fixture.updater
	updater.show_progress_dialog()
	var dialog_ref: WeakRef = weakref(updater._open_dialogs[0].get_ref())
	var checks: Array[String] = [assert_eq(dialog_ref.get_ref().get_parent(), fixture.menu, "Dialog belongs to home, not an autoload layer")]
	var battle := Control.new()
	battle.scene_file_path = "res://scenes/battle/BattleScene.tscn"
	tree.root.add_child(battle)
	tree.current_scene = battle
	fixture.menu.queue_free()
	await tree.process_frame
	await tree.process_frame
	checks.append(assert_null(dialog_ref.get_ref(), "Leaving home destroys its update dialog"))
	for state: String in ["downloading", "verifying", "ready", "failed", "cancelled", "installing", "permission_required", "awaiting_install"]:
		updater._state = state
		updater._downloaded = 42
		updater._emit()
		updater.show_progress_dialog()
		checks.append(assert_false(updater.has_open_dialog(), state + " cannot create a battle dialog"))
		checks.append(assert_eq(updater.find_children("*", "Control", true, false).size(), 0, "Updater owns no global controls"))
		checks.append(assert_eq(battle.get_child_count(), 0, "Update events do not add battle UI"))
	tree.current_scene = null
	updater.activate_update_entry()
	checks.append(assert_false(updater.has_open_dialog(), "No UI or installation during scene transitions"))
	var home := Menu.new()
	home.scene_file_path = "res://scenes/main_menu/MainMenu.tscn"
	tree.root.add_child(home)
	tree.current_scene = home
	fixture.menu = home
	updater._state = "ready"
	home._on_app_update_state_changed(updater.snapshot())
	checks.append(assert_true(home._update_button.visible, "Returning home restores the single entry"))
	checks.append(assert_eq(updater._downloaded, 42, "Background progress survives scene replacement"))
	updater.show_progress_dialog()
	var dialog: Control = updater._open_dialogs[0].get_ref()
	dialog._dismiss()
	await tree.process_frame
	await tree.process_frame
	checks.append(assert_false(updater.has_open_dialog(), "Player can dismiss the actual dialog"))
	checks.append(assert_eq(updater.find_children("*", "Control", true, false).size(), 0, "Dismissal does not create a persistent banner"))
	battle.free()
	_dispose(fixture)
	return run_checks(checks)


func test_home_has_one_update_entry_and_no_global_duplicate() -> String:
	var fixture := _fixture()
	var checks: Array[String] = []
	for state: String in ["downloading", "verifying", "ready", "failed", "cancelled", "installing", "permission_required", "awaiting_install", "updated", "idle"]:
		fixture.updater._state = state
		fixture.updater._emit()
		var entries := int(fixture.menu._update_button.visible) + int(fixture.menu._manual_update_button.visible)
		for button: Node in fixture.updater.find_children("*", "Button", true, false):
			if button.visible:
				entries += 1
		checks.append(assert_eq(entries, 1, state + " must have exactly one home update entry"))
	_dispose(fixture)
	return run_checks(checks)


func test_cached_release_notice_is_retained_after_an_idle_startup() -> String:
	var fixture := _fixture()
	var info: Dictionary = fixture.updater.snapshot().info
	fixture.updater._state = "idle"
	fixture.updater._info = {}
	fixture.menu._on_update_available(info)
	var result := run_checks([
		assert_true(fixture.menu._update_button.visible, "A valid cached update remains visible on the release client"),
		assert_false(fixture.menu._manual_update_button.visible, "Cached notice is the only update entry"),
		assert_eq(fixture.updater.snapshot().state, "available", "Cached release is offered to the actual download owner"),
		assert_eq(fixture.updater.snapshot().info.latest_version, info.latest_version, "The entry opens the exact cached release"),
	])
	_dispose(fixture)
	return result


func test_completed_update_removes_the_home_banner() -> String:
	var fixture := _fixture()
	fixture.updater._state = "updated"
	fixture.updater._emit()
	var result := run_checks([
		assert_false(fixture.menu._update_button.visible, "A successful update must remove the install banner"),
		assert_true(fixture.menu._manual_update_button.visible, "Only the normal check-updates icon remains after completion"),
		assert_true(fixture.menu._available_update.is_empty(), "Completed release metadata must not reopen an install dialog"),
	])
	_dispose(fixture)
	return result


func test_development_startup_does_not_restore_exported_package_as_installable() -> String:
	var owner := load("res://scripts/update/AppUpdater.gd")
	var saved := {"latest_version": "99.0.0", "artifact": {
		"arch": "x86_64", "format": "windows_zip", "entry": "Game.exe",
		"url": "https://ptcg.skillserver.cn/dist/updates/test.zip",
		"sha256": DATA.sha256_text(), "size": DATA.to_utf8_buffer().size(),
	}}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(owner.ROOT))
	var state := FileAccess.open(owner.STATE_PATH, FileAccess.WRITE)
	state.store_string(JSON.stringify(saved))
	state.close()
	var package_path: String = owner.ROOT.path_join(DATA.sha256_text() + ".zip")
	var package := FileAccess.open(package_path, FileAccess.WRITE)
	package.store_string(DATA)
	package.close()
	var checks: Array[String] = []
	for boot in range(2):
		var updater: Node = owner.new()
		updater._restore_pending()
		checks.append(assert_eq(updater.snapshot().state, "idle", "Source startup %d must ignore exported-client pending state" % boot))
		checks.append(assert_true(updater.snapshot().info.is_empty(), "Source run must not advertise an unusable cached installation"))
		checks.append(assert_null(updater._hash_file, "Source run must not rehash the cached release on every launch"))
		updater.free()
	checks.append(assert_true(FileAccess.file_exists(owner.STATE_PATH) and FileAccess.file_exists(package_path), "Source runs preserve the real installed client's download"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(owner.STATE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(package_path))
	return run_checks(checks)


func test_development_manual_offer_uses_website_without_a_native_download() -> String:
	var updater: Node = load("res://scripts/update/AppUpdater.gd").new()
	updater.offer({"latest_version": "99.0.0", "artifact": {
		"arch": "x86_64", "format": "windows_zip", "entry": "Game.exe",
		"url": "https://ptcg.skillserver.cn/dist/updates/test.zip",
		"sha256": DATA.sha256_text(), "size": DATA.to_utf8_buffer().size(),
	}})
	var dialog := preload("res://scripts/update/AppUpdateDialog.gd").new()
	dialog.configure(updater, updater.snapshot().info)
	var result := run_checks([
		assert_true(dialog._primary.disabled, "Development runtime cannot download a package it cannot install"),
		assert_true(updater.snapshot().info.get("website_only", false), "Manual development check offers the website"),
	])
	dialog.free()
	updater.free()
	return result


class CheckProbe extends Node:
	var calls := 0
	func check_for_updates(_force: bool) -> int:
		calls += 1
		return OK


func test_development_automatic_check_stays_quiet_but_manual_check_works() -> String:
	var menu := Menu.new()
	var checker := CheckProbe.new()
	menu._update_checker = checker
	menu._start_update_check(false)
	var automatic_calls := checker.calls
	menu._start_update_check(true)
	var result := run_checks([
		assert_eq(automatic_calls, 0, "Source startup must not recreate cached release banners"),
		assert_eq(checker.calls, 1, "Explicit update checks remain available"),
	])
	menu.free()
	checker.free()
	return result


func test_installed_release_clears_pending_and_stays_idle_on_next_boot() -> String:
	var checks: Array[String] = []
	for has_artifact in [true, false]:
		var artifact := {"arch": "x86_64", "format": "windows_zip", "entry": "Game.exe",
			"url": "https://ptcg.skillserver.cn/dist/updates/test.zip",
			"sha256": DATA.sha256_text(), "size": DATA.to_utf8_buffer().size()}
		var info := {"latest_version": "0.0.1", "artifact": artifact if has_artifact else {}}
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SceneUpdater.ROOT))
		var state := FileAccess.open(SceneUpdater.STATE_PATH, FileAccess.WRITE)
		state.store_string(JSON.stringify(info))
		state.close()
		var package_path: String = SceneUpdater.ROOT.path_join(DATA.sha256_text() + ".zip")
		if has_artifact:
			var package := FileAccess.open(package_path, FileAccess.WRITE)
			package.store_string(DATA)
			package.close()
		for boot in range(2):
			var updater := SceneUpdater.new()
			updater._restore_pending()
			checks.append(assert_eq(updater.snapshot().state, "idle", "Already-installed release is idle on boot %d" % boot))
			checks.append(assert_true(updater.snapshot().info.is_empty(), "No completed release metadata remains actionable"))
			checks.append(assert_false(FileAccess.file_exists(SceneUpdater.STATE_PATH), "Retire pending state even when old artifact metadata is unavailable"))
			updater.free()
		if has_artifact:
			checks.append(assert_false(FileAccess.file_exists(package_path), "Verified completed package no longer consumes update storage"))
	return run_checks(checks)
