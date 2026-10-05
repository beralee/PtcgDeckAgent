extends TestBase

const Updater := preload("res://tests/mocks/MockAppUpdater.gd")
const Dialog := preload("res://scripts/update/AppUpdateDialog.gd")
const Manifest := preload("res://scripts/update/AppUpdateManifest.gd")
const Installer := preload("res://scripts/update/AppUpdateInstaller.gd")
const DATA := "verified release fixture"


class WebsiteDialog extends Dialog:
	var website_opens := 0
	func _reinstall() -> void:
		website_opens += 1

class ReleaseUpdater extends "res://scripts/update/AppUpdater.gd":
	func _is_editor_runtime() -> bool:
		return false


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
		assert_eq(fallback.text, "去网页下载", "Website action has the same label on all platforms"),
		assert_eq(initial, "游戏内更新", "In-app download is the primary action"),
		assert_eq(primary.text, "安装更新", "Verified download offers explicit installation"),
		assert_eq(dialog._actions.get_child_count(), 2, "Only website download and in-game update occupy the action row"),
		assert_true(dialog._actions is HFlowContainer, "Narrow devices wrap actions instead of clipping them"),
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


func test_abandoned_install_preparation_revokes_helper_authority() -> String:
	var updater := _new_updater()
	var session := "user://app_updates/test-cancel-install"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(session))
	for marker: String in ["prepared", "cancelled", "proceed"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(session.path_join(marker)))
	updater._state = "installing"
	updater._install = {"session": session}
	updater._install_started_ms = Time.get_ticks_msec() - 120001
	updater._poll_install()
	var timed_out := FileAccess.file_exists(session.path_join("cancelled"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(session.path_join("cancelled")))
	var prepared := FileAccess.open(session.path_join("prepared"), FileAccess.WRITE)
	prepared.close()
	updater._state = "installing"
	updater._poll_install()
	var result := run_checks([
		assert_true(timed_out, "Preparation timeout must cancel the external helper"),
		assert_true(FileAccess.file_exists(session.path_join("cancelled")), "Leaving home must revoke installation"),
		assert_false(FileAccess.file_exists(session.path_join("proceed")), "No mutation authority is granted away from home"),
		assert_eq(updater.snapshot().state, "ready", "Verified package remains retryable"),
	])
	for marker: String in ["prepared", "cancelled", "proceed"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(session.path_join(marker)))
	updater.free()
	return result


func test_dialog_displays_active_download_instead_of_a_newer_offer() -> String:
	var updater := _new_updater()
	updater.start_download()
	var newer := _info()
	newer.latest_version = "100.0.0"
	newer.display_version = "v100.0.0"
	var dialog := Dialog.new()
	dialog.configure(updater, newer)
	var result := assert_eq(dialog._info.latest_version, "99.0.0", "Progress and installation must name the package actually owned by the downloader")
	dialog.free()
	updater.cancel_download()
	updater.free()
	_cleanup()
	return result


func test_real_pending_file_restores_and_reverifies_after_restart() -> String:
	var owner = ReleaseUpdater
	var state_path: String = owner.STATE_PATH
	var previous := FileAccess.get_file_as_bytes(state_path) if FileAccess.file_exists(state_path) else PackedByteArray()
	var writer: Node = owner.new()
	writer.offer(_info())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(owner.ROOT))
	var package_path: String = writer._package_path()
	var package := FileAccess.open(package_path, FileAccess.WRITE)
	package.store_string(DATA)
	package.close()
	writer._save_pending()
	writer.free()
	var restored: Node = owner.new()
	restored._restore_pending()
	var initial: String = restored.snapshot().state
	restored._verify_step()
	var result := run_checks([
		assert_eq(initial, "verifying", "Persisted state must rehash before offering install"),
		assert_eq(restored.snapshot().state, "ready", "Complete download survives an application restart"),
		assert_eq(restored.snapshot().info.latest_version, "99.0.0", "Restored package retains the exact release identity"),
	])
	restored.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(package_path))
	if previous.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(state_path))
	else:
		var saved := FileAccess.open(state_path, FileAccess.WRITE)
		saved.store_buffer(previous)
		saved.close()
	return result


func test_android_invalid_package_is_discarded_but_storage_or_denial_can_retry() -> String:
	var updater := _new_updater()
	updater.start_download()
	updater.requests[0].complete(DATA.to_utf8_buffer())
	updater._verify_step()
	updater._handle_android_status("failed_storage")
	var storage_kept: bool = updater.snapshot().state == "ready" and FileAccess.file_exists(updater._package_path())
	updater._handle_android_status("permission_denied")
	var permission_kept: bool = updater.snapshot().state == "ready" and FileAccess.file_exists(updater._package_path())
	updater._handle_android_status("failed_package_invalid")
	var rejected: bool = updater.snapshot().state == "failed" and not FileAccess.file_exists(updater._package_path())
	updater.redownload()
	var result := run_checks([
		assert_true(storage_kept, "Storage errors preserve verified bytes for later installation"),
		assert_true(permission_kept, "Permission refusal must leave the game usable and package retryable"),
		assert_true(rejected, "An unparseable APK must not loop forever as ready to install"),
		assert_eq(updater.requests.size(), 2, "Invalid APK offers a real fresh download"),
	])
	updater.cancel_download()
	updater.free()
	_cleanup()
	return result


func test_android_timeout_and_cancel_abandon_native_session() -> String:
	var updater := _new_updater()
	updater._state = "installing"
	updater._install = {"android": true}
	updater._install_started_ms = Time.get_ticks_msec() - 120001
	updater._poll_install()
	var timeout_ready: bool = updater.snapshot().state == "ready"
	updater._state = "awaiting_install"
	updater.cancel_installation()
	var result := run_checks([
		assert_true(timeout_ready, "Android preparation cannot leave an uncloseable UI forever"),
		assert_eq(updater.cancelled_installs, 2, "Both timeout and player cancellation revoke the actual native session"),
		assert_eq(updater.snapshot().state, "ready", "Cancelled install keeps a retry path"),
		assert_true(updater._install.is_empty(), "Old native callbacks are no longer polled"),
	])
	updater.free()
	return result


func test_android_system_abort_preserves_package_and_offers_explicit_compatible_retry() -> String:
	var updater := _new_updater()
	updater.start_download()
	updater.requests[0].complete(DATA.to_utf8_buffer())
	updater._verify_step()
	updater._handle_android_status("failed_3")
	var data: Dictionary = updater.snapshot()
	var dialog := Dialog.new()
	dialog.configure(updater, _info())
	dialog.refresh(data)
	var result := run_checks([
		assert_eq(data.state, "ready", "System abort preserves a verified package for retry"),
		assert_true(FileAccess.file_exists(updater._package_path()), "No second download is required"),
		assert_true(data.message.contains("系统中止"), "An OS abort must not be attributed to the player"),
		assert_true(bool(data.get("compatibility_install", false)), "A failed session offers the independent system installer"),
		assert_eq(dialog._primary.text, "使用系统安装器", "The changed install route requires an explicit, labelled action"),
	])
	dialog.free()
	updater.free()
	_cleanup()
	return result


func test_android_background_confirmation_waits_without_timing_out_or_claiming_success() -> String:
	var updater := _new_updater()
	updater._state = "installing"
	updater._install = {"android": true}
	updater._install_started_ms = Time.get_ticks_msec() - 120001
	updater.native_status = "awaiting_foreground"
	updater._poll_install()
	var result := run_checks([
		assert_eq(updater.snapshot().state, "awaiting_install", "A queued confirmation waits for a foreground Activity"),
		assert_eq(updater.cancelled_installs, 0, "Backgrounding must not abandon an otherwise valid install"),
		assert_true(updater.snapshot().message.contains("返回游戏"), "The player gets an actionable foreground instruction"),
	])
	updater.free()
	return result


func test_android_verification_rejection_and_external_cancel_remain_retryable() -> String:
	var updater := _new_updater()
	updater._handle_android_status("failed_verification")
	var verification: Dictionary = updater.snapshot()
	updater._handle_android_status("external_cancelled")
	var cancelled: Dictionary = updater.snapshot()
	var result := run_checks([
		assert_true(verification.message.contains("系统安全校验"), "System verification is distinct from a corrupt download"),
		assert_eq(cancelled.state, "ready", "Returning from a system installer cannot leave a permanent spinner"),
		assert_true(bool(cancelled.get("compatibility_install", false)), "An external retry remains on the explicitly chosen route"),
	])
	updater.free()
	return result


func test_android_permission_return_resumes_preparation_timeout() -> String:
	var updater := _new_updater()
	updater._state = "permission_required"
	updater._install = {"android": true}
	updater._install_started_ms = Time.get_ticks_msec() - 120001
	updater.native_status = "preparing"
	updater._poll_install()
	var resumed: bool = updater.snapshot().state == "installing"
	updater._install_started_ms = Time.get_ticks_msec() - 120001
	updater._poll_install()
	var result := run_checks([
		assert_true(resumed, "Returning from granted permission starts a fresh preparation deadline"),
		assert_eq(updater.snapshot().state, "ready", "A stalled native worker still times out after permission was granted"),
		assert_eq(updater.cancelled_installs, 1, "Timeout revokes the native session"),
	])
	updater.free()
	return result


func test_low_space_timeout_http_error_and_short_file_are_recoverable() -> String:
	var updater := _new_updater()
	updater.available_bytes = 1
	updater.start_download()
	var space_blocked: bool = updater.requests.is_empty() and updater.snapshot().state == "failed"
	updater.available_bytes = -1
	updater.start_download()
	updater._last_progress_ms = Time.get_ticks_msec() - 60001
	updater._process(0.0)
	var timed_out: bool = updater.snapshot().state == "failed"
	updater.start_download()
	updater.requests[1].complete(PackedByteArray(), HTTPRequest.RESULT_SUCCESS, 404)
	var http_failed: bool = updater.snapshot().state == "failed"
	updater.start_download()
	updater.requests[2].complete("half".to_utf8_buffer())
	var short_rejected: bool = updater.snapshot().state == "failed" and not FileAccess.file_exists(updater._package_path() + ".part")
	var result := run_checks([
		assert_true(space_blocked, "Known low space fails before network transfer"),
		assert_true(timed_out, "A stalled download exposes retry"),
		assert_true(http_failed, "404 cannot authorize installation"),
		assert_true(short_rejected, "An HTTP-success half-file is discarded"),
	])
	updater.free()
	_cleanup()
	return result


func test_macos_dialog_keeps_the_same_two_actions_and_explains_install_availability() -> String:
	var info := _info()
	info.website_only = true
	info.artifact = {}
	info.native_update_reason = "macOS 请前往官网下载。"
	var dialog := Dialog.new()
	dialog.configure(null, info)
	var result := run_checks([
		assert_eq(dialog._primary.text, "游戏内更新", "All platforms share the same in-game update action"),
		assert_true(dialog._primary.visible and dialog._primary.disabled, "Unsupported installation remains clearly unavailable"),
		assert_eq(dialog._actions.get_child_count(), 2, "Mac uses the same two-action layout"),
	])
	dialog.free()
	return result


func test_website_download_remains_usable_without_native_metadata() -> String:
	var selected := Manifest.select_release({"schema_version": 1, "latest_version": "99.0.0"}, "windows", "x86_64")
	var dialog := WebsiteDialog.new()
	dialog.configure(null, selected)
	var website := dialog.find_child("ReinstallFallback", true, false) as Button
	var offered := website.visible and not website.disabled
	website.pressed.emit()
	var result := run_checks([
		assert_true(offered, "A release announcement without an APK must still offer a prominent working download action"),
		assert_eq(website.text, "去网页下载", "Website action retains the user-requested label"),
		assert_eq(dialog.website_opens, 1, "The primary button must open the download page, not start an empty native download"),
	])
	dialog.free()
	return result


func test_update_dialog_never_offers_ignore_version() -> String:
	var dialog := Dialog.new()
	dialog.configure(null, _info())
	var result := ""
	for state: String in ["available", "downloading", "ready", "failed", "cancelled", "permission_required"]:
		dialog.refresh({"state": state, "install_reason": ""})
		if dialog._actions.get_child_count() != 2:
			result = "Every update state must retain exactly two actions"
		for node: Node in dialog.find_children("*", "Button", true, false):
			if "忽略" in node.text:
				result = "Update dialogs must not create an ignore-version button in any state"
	dialog.free()
	return result


func _fixed_android_updater() -> Node:
	var updater := Updater.new()
	updater.android_fixture = true
	updater.system_download = true
	updater.offer(Manifest.select_release({"schema_version": 1, "latest_version": "99.0.0"}, "android", "arm64"))
	return updater


func test_fixed_android_download_promotes_native_metadata_then_rehashes_and_preserves_ready() -> String:
	var updater := _fixed_android_updater()
	updater.system_status = {"state": "running", "downloaded": 8, "total": DATA.length()}
	updater.start_download()
	var original_path: String = updater._package_path()
	var total: int = updater.snapshot().total
	var file := FileAccess.open(original_path, FileAccess.WRITE)
	file.store_string(DATA)
	file.close()
	updater.system_status = {"state": "completed", "resolved": {"version": "99.0.0", "size": DATA.length(), "sha256": DATA.sha256_text(), "build": 999}}
	updater._poll_system_download()
	var before_hash: String = updater.snapshot().state
	updater._verify_step()
	var saved: Dictionary = updater.pending.duplicate(true)
	updater.offer(Manifest.select_release({"latest_version": "99.0.0"}, "android", "arm64"))
	var result := run_checks([
		assert_eq(total, DATA.length(), "System download headers supply progress size without a server manifest change"),
		assert_eq(before_hash, "verifying", "Native metadata must still pass the ordinary local hashing gate"),
		assert_eq(updater.snapshot().state, "ready", "Rechecking the same legacy notice preserves the prepared package"),
		assert_eq(saved.artifact.get("sha256"), DATA.sha256_text(), "Resume data contains a real measured digest, not the transport ID"),
		assert_eq(saved.artifact.get("build"), 999, "APK's checked native build is persisted"),
		assert_true(FileAccess.file_exists(updater._package_path()) and not FileAccess.file_exists(original_path), "Verified fixed-address download moves to the normal private install path"),
		assert_true(updater._install.is_empty(), "Download never installs without the player's action"),
	])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(updater._package_path()))
	updater.free()
	return result


func test_fixed_android_completion_without_matching_native_identity_is_rejected() -> String:
	for metadata: Dictionary in [{}, {"version": "98.0.0", "size": DATA.length(), "sha256": DATA.sha256_text(), "build": 999}]:
		var updater := _fixed_android_updater()
		updater.start_download()
		updater.system_status = {"state": "completed", "resolved": metadata}
		updater._poll_system_download()
		var result := assert_eq(updater.snapshot().state, "failed", "A completed transfer cannot replace native package identity verification")
		updater.free()
		if not result.is_empty():
			return result
	return ""


func test_fixed_android_two_actions_start_and_cancel_without_unknown_size_percentage() -> String:
	var updater := _fixed_android_updater()
	var dialog := Dialog.new()
	dialog.configure(updater, updater.snapshot().info)
	var offered: bool = dialog._primary.visible and not dialog._primary.disabled and dialog._primary.text == "游戏内更新"
	dialog._primary.pressed.emit()
	var downloading: bool = updater.snapshot().state == "downloading" and dialog._primary.text == "取消下载" and dialog._progress.indeterminate
	dialog._primary.pressed.emit()
	var result := run_checks([
		assert_true(offered, "Legacy Android announcements have an enabled in-game update action"),
		assert_true(downloading, "The same button cancels the download while unknown size shows indeterminate progress"),
		assert_eq(updater.snapshot().state, "cancelled", "Cancel remains available without adding a third action"),
		assert_eq(dialog._actions.get_child_count(), 2, "Only the two requested actions exist"),
	])
	dialog.free()
	updater.free()
	return result


func test_android_system_download_survives_ui_lifecycle_and_network_wait() -> String:
	var updater := _new_updater()
	updater.system_download = true
	updater.system_status = {"state": "running", "downloaded": 8}
	updater.start_download()
	updater._last_progress_ms = Time.get_ticks_msec() - 600001
	updater._poll_system_download()
	var active: String = updater.snapshot().state
	var bytes: int = updater.snapshot().downloaded
	updater.system_status = {"state": "paused", "downloaded": 8, "reason": 2}
	updater._poll_system_download()
	var waiting: String = updater.snapshot().message
	updater._exit_tree()
	var survived: int = updater.system_cancels
	updater.cancel_download()
	var result := run_checks([
		assert_eq(updater.requests.size(), 0, "Android delegates networking to the system, not the Godot scene"),
		assert_eq(updater.system_starts, 1, "Only one system task is started"),
		assert_eq(active, "downloading", "Game frame timeout cannot cancel a system-owned download"),
		assert_eq(bytes, 8, "Real system bytes remain visible"),
		assert_true("网络" in waiting, "Offline waiting must be explicit"),
		assert_eq(survived, 0, "Closing the app must not cancel the system task"),
		assert_eq(updater.system_cancels, 1, "Explicit player cancellation still cancels it"),
	])
	updater.free()
	_cleanup()
	return result


func test_android_system_completion_still_requires_hash_verification() -> String:
	var updater := _new_updater()
	updater.system_download = true
	updater.start_download()
	var file := FileAccess.open(updater._package_path(), FileAccess.WRITE)
	file.store_string("x".repeat(DATA.length()))
	file.close()
	updater.system_status = {"state": "completed", "downloaded": DATA.length()}
	updater._poll_system_download()
	var initial: String = updater.snapshot().state
	updater._verify_step()
	var result := run_checks([
		assert_eq(initial, "verifying", "System success does not grant installation authority"),
		assert_eq(updater.snapshot().state, "failed", "A corrupt system download is rejected"),
		assert_true(updater.system_cancels > 0, "Rejected system bytes cannot be reimported forever"),
	])
	updater.free()
	_cleanup()
	return result


func test_reopening_reattaches_to_existing_system_download() -> String:
	var updater := _new_updater()
	updater.system_download = true
	updater.system_status = {"state": "running", "downloaded": 12}
	var restored: bool = updater._restore_system_download()
	var result := run_checks([
		assert_true(restored, "Persisted system task is recovered before deleting any half file"),
		assert_eq(updater.snapshot().downloaded, 12, "Reopen shows current system bytes"),
		assert_eq(updater.system_starts, 0, "Recovery does not start a duplicate download"),
	])
	updater.free()
	return result


func test_progress_dialog_keeps_percentage_and_can_be_reopened_without_a_global_banner() -> String:
	var updater := _new_updater()
	updater._state = "downloading"
	updater._artifact.size = 100
	updater._downloaded = 40
	var dialog := Dialog.new()
	dialog.configure(updater, _info())
	var visible := dialog._progress.visible and dialog._progress.value == 40
	dialog.free()
	var closed: bool = not updater.has_open_dialog()
	dialog = Dialog.new()
	dialog.configure(updater, _info())
	var reopened: bool = dialog._progress.value == 40 and updater._open_dialogs.size() == 1
	updater._state = "ready"
	updater._emit()
	var result := run_checks([
		assert_true(visible, "Dialog shows current download percentage"),
		assert_true(closed, "Closing removes dialog ownership"),
		assert_true(reopened, "Reopening resumes the same progress without another download"),
		assert_eq(dialog._primary.text, "安装更新", "Completed download offers installation in the dialog"),
		assert_eq(updater.find_children("*", "Control", true, false).size(), 0, "The download owner never creates a global banner"),
	])
	dialog.free()
	updater.free()
	return result
