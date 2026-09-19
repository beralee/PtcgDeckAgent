extends TestBase

const ManifestPath := "res://scripts/update/AppUpdateManifest.gd"


func _release() -> Dictionary:
	return {
		"schema_version": 2, "latest_version": "0.7.0", "channel": "stable",
		"platforms": {
			"windows": {"version": "0.6.2", "artifacts": [{
				"arch": "x86_64", "format": "windows_zip", "entry": "PtcgDeckAgent.exe",
				"url": "https://ptcg.skillserver.cn/dist/updates/0.6.2/windows.zip",
				"size": 100, "sha256": "a".repeat(64),
			}]},
		},
	}


func test_update_manifest_owner_exists() -> String:
	return assert_true(ResourceLoader.exists(ManifestPath), "Native updates need a validated platform artifact, not just a download page")


func test_selects_actual_platform_version_and_architecture() -> String:
	if not ResourceLoader.exists(ManifestPath):
		return "Missing platform manifest owner"
	var owner = load(ManifestPath)
	var result: Dictionary = owner.select_release(_release(), "windows", "x86_64")
	return run_checks([
		assert_eq(result.get("latest_version"), "0.6.2", "Platform rollout version must override the global marketing version"),
		assert_eq(result.get("artifact", {}).get("format"), "windows_zip", "Select a usable native artifact"),
		assert_true(owner.select_release(_release(), "windows", "arm64").get("artifact", {}).is_empty(), "Wrong CPU cannot silently install"),
		assert_true(owner.select_release(_release(), "android", "arm64").get("artifact", {}).is_empty(), "Wrong platform cannot silently install"),
	])


func test_rejects_unsafe_or_incomplete_native_artifacts() -> String:
	if not ResourceLoader.exists(ManifestPath):
		return "Missing platform manifest owner"
	var owner = load(ManifestPath)
	for change: Dictionary in [
		{"url": "http://ptcg.skillserver.cn/update.zip"},
		{"url": "https://ptcg.skillserver.cn.evil.test/update.zip"},
		{"url": "https://ptcg.skillserver.cn@evil.test/update.zip"},
		{"sha256": "bad"}, {"size": -1}, {"size": 1.5},
		{"entry": "../outside.exe"}, {"entry": "C:/outside.exe"},
		{"entry": "folder/app.exe"}, {"format": "android_apk"},
	]:
		var data := _release()
		data.platforms.windows.artifacts[0].merge(change, true)
		var result: Dictionary = owner.select_release(data, "windows", "x86_64")
		if not result.get("artifact", {}).is_empty():
			return "Unsafe update accepted: %s" % str(change)
	return ""


func test_legacy_feed_keeps_manual_reinstall_without_inventing_downloads() -> String:
	if not ResourceLoader.exists(ManifestPath):
		return "Missing platform manifest owner"
	var owner = load(ManifestPath)
	var result: Dictionary = owner.select_release({"latest_version": "0.7.0", "download_page_url": "javascript:alert(1)"}, "windows", "x86_64")
	return run_checks([
		assert_true(result.get("artifact", {}).is_empty(), "Legacy feed cannot authorize an unverified installer"),
		assert_eq(result.get("download_page_url"), "https://ptcg.skillserver.cn/", "Manual fallback must remain a safe web URL"),
	])
