extends TestBase

const Updater := preload("res://tests/mocks/MockAppUpdater.gd")
const Dialog := preload("res://scripts/update/AppUpdateDialog.gd")
const Manifest := preload("res://scripts/update/AppUpdateManifest.gd")
const Installer := preload("res://scripts/update/AppUpdateInstaller.gd")
const DATA := "verified release fixture"


func _info() -> Dictionary:
	return {"latest_version": "99.0.0", "display_version": "v99.0.0", "summary": ["更流畅的升级体验"], "artifact": {
		"arch": Manifest.architecture(), "format": "windows_zip", "entry": "Game.exe",
		"url": "https://ptcg.skillserver.cn/dist/updates/test.zip", "sha256": DATA.sha256_text(), "size": DATA.to_utf8_buffer().size(),
	}}


func _new_updater() -> Node:
	_cleanup()
	var updater := Updater.new()
	updater.offer(_info())
	return updater


func _cleanup() -> void:
	for name: String in ["user://app_updates/updater-test.zip", "user://app_updates/updater-test.zip.part"]:
		if FileAccess.file_exists(name):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(name))


func test_download_hash_gate_persists_ready_and_does_not_start_installer() -> String:
	var updater := _new_updater()
	updater.start_download()
	updater.requests[0].complete(DATA.to_utf8_buffer())
	var verifying: String = updater.snapshot().state
	updater._verify_step()
	var result := run_checks([
		assert_eq(verifying, "verifying", "HTTP success alone must not grant install authority"),
		assert_eq(updater.snapshot().state, "ready", "Exact bytes become ready after hashing"),
		assert_eq(updater.pending.get("latest_version"), "99.0.0", "Ready release persists for next launch"),
		assert_true(updater._install.is_empty(), "Download never shuts down or installs by itself"),
	])
	updater.free()
	_cleanup()
	return result


func test_corrupt_download_is_removed_and_retry_succeeds() -> String:
	var updater := _new_updater()
	updater.start_download()
	updater.requests[0].complete("x".repeat(DATA.length()).to_utf8_buffer())
	updater._verify_step()
	var failed: String = updater.snapshot().state
	var removed := not FileAccess.file_exists(updater._package_path() + ".part")
	updater.start_download()
	updater.requests[1].complete(DATA.to_utf8_buffer())
	updater._verify_step()
	var result := run_checks([
		assert_eq(failed, "failed", "A same-size corrupt file must fail SHA-256"),
		assert_true(removed, "Untrusted partial bytes must not remain installable"),
		assert_eq(updater.snapshot().state, "ready", "Retry can recover without restarting the game"),
	])
	updater.free()
	_cleanup()
	return result


func test_cancel_invalidates_late_callbacks_and_prevents_parallel_downloads() -> String:
	var updater := _new_updater()
	updater.start_download()
	updater.start_download()
	var generation: int = updater._generation
	var count: int = updater.requests.size()
	updater.cancel_download()
	updater._on_download_complete(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray(), generation)
	var result := run_checks([
		assert_eq(count, 1, "Rapid clicks must keep exactly one request"),
		assert_eq(updater.snapshot().state, "cancelled", "A late completion cannot resurrect a cancelled update"),
		assert_true(updater.requests[0].cancelled, "Cancellation stops network transfer"),
	])
	updater.free()
	_cleanup()
	return result


func test_ready_cache_reverified_and_battle_install_refused() -> String:
	var updater := _new_updater()
	updater.start_download()
	updater.requests[0].complete(DATA.to_utf8_buffer())
	updater._verify_step()
	updater.install_ready_update()
	var refused: bool = updater._install.is_empty()
	updater.offer(_info())
	var kept: String = updater.snapshot().state
	var file := FileAccess.open(updater._package_path(), FileAccess.WRITE)
	file.store_string("x".repeat(DATA.length()))
	file.close()
	updater.start_download()
	updater._verify_step()
	var result := run_checks([
		assert_true(refused, "A background download must never interrupt a battle"),
		assert_eq(kept, "ready", "Checking the same release retains ready state"),
		assert_eq(updater.snapshot().state, "failed", "Cached files must be rehashed"),
	])
	updater.free()
	_cleanup()
	return result


func test_dialog_always_has_fallback_and_changes_primary_action() -> String:
	var updater := _new_updater()
	var dialog := Dialog.new()
	dialog.size = Vector2(360, 740)
	dialog.configure(updater, _info())
	var fallback := dialog.find_child("ReinstallFallback", true, false) as Button
	var primary := dialog.find_child("DownloadOrInstallUpdate", true, false) as Button
	var initial := primary.text
	dialog.refresh({"state": "ready", "message": "已校验", "install_reason": ""})
	var result := run_checks([
		assert_not_null(fallback, "Manual reinstall is always reachable"),
		assert_eq(initial, "下载更新", "In-app download is the primary action"),
		assert_eq(primary.text, "安装并重启", "Verified download offers explicit installation"),
		assert_true(dialog._actions is HFlowContainer, "Narrow devices wrap actions instead of clipping them"),
		assert_eq(Installer.mac_bundle("/Applications/Game.app/Contents/MacOS/Game"), "/Applications/Game.app", "Only the exact application bundle is replaced on Mac"),
	])
	dialog.free()
	updater.free()
	_cleanup()
	return result


func test_older_release_and_unsafe_platform_packages_cannot_be_installed() -> String:
	var updater := _new_updater()
	var older := _info()
	older.latest_version = "0.0.1"
	updater.offer(older)
	updater.start_download()
	var result := run_checks([
		assert_eq(updater.snapshot().state, "failed", "Old persisted feeds cannot downgrade the app"),
		assert_eq(updater.requests.size(), 0, "Rejected metadata never launches a request"),
	])
	updater.free()
	return result
