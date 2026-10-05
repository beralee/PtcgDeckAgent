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


func test_v2_wire_json_numbers_preserve_artifact_authority() -> String:
	var owner = load(ManifestPath)
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(_release()))
	var result: Dictionary = owner.select_release(decoded, "windows", "x86_64")
	return run_checks([
		assert_eq(result.get("latest_version"), "0.6.2", "Wire JSON must not reject numeric schema 2"),
		assert_false(result.get("artifact", {}).is_empty(), "Numeric schema/size parsed from real JSON must authorize a valid artifact"),
	])


func test_android_v2_metadata_and_legacy_fixed_url_both_offer_in_app_update() -> String:
	var owner = load(ManifestPath)
	var data := {"schema_version": 2, "latest_version": "0.6.1", "platforms": {"android": {"version": "0.6.1", "artifacts": [{
		"arch": "arm64", "format": "android_apk", "entry": "PtcgDeckAgent.apk", "build": 61,
		"url": "https://ptcg.skillserver.cn/dist/updates/0.6.1/android-arm64.apk", "size": 100, "sha256": "a".repeat(64),
	}]}}}
	var selected: Dictionary = owner.select_release(JSON.parse_string(JSON.stringify(data)), "android", "arm64")
	var legacy: Dictionary = owner.select_release({"schema_version": 1, "latest_version": "0.6.1"}, "android", "arm64")
	return run_checks([
		assert_eq(selected.artifact.get("build"), 61, "Android must retain the actual APK build from wire JSON"),
		assert_eq(selected.artifact.get("format"), "android_apk", "A complete matching APK enables in-game download and installation"),
		assert_true(selected.native_update_reason.is_empty(), "A valid APK must not show the missing-package notice"),
		assert_eq(legacy.artifact.get("url"), "https://ptcg.skillserver.cn/dist/downloads/ptcgdeckagent-android.apk", "Legacy announcements use the existing fixed APK address"),
		assert_eq(legacy.artifact.get("verification"), "android_signature", "The legacy path must require native APK identity verification"),
		assert_false(legacy.artifact.has("sha256"), "A download identity must never pretend to be a server-provided content digest"),
	])


func test_fixed_android_offer_cannot_redirect_or_bypass_complete_v2_metadata() -> String:
	var owner = load(ManifestPath)
	var selected: Dictionary = owner.select_release({"latest_version": "0.6.1"}, "android", "arm64")
	if selected.artifact.is_empty():
		return "Legacy Android release must offer the pinned download"
	if owner.validate_artifact(JSON.parse_string(JSON.stringify(selected.artifact)), "android", "arm64").is_empty():
		return "Persisted fixed-download metadata must survive JSON number parsing"
	var v2 := {"schema_version": 2, "latest_version": "0.6.1", "platforms": {"android": {"artifacts": [selected.artifact]}}}
	if not owner.select_release(v2, "android", "arm64").artifact.is_empty():
		return "A v2 feed cannot opt into client-only signature fallback instead of providing its required digest"
	for mutation: Dictionary in [{"url": "https://ptcg.skillserver.cn/other.apk"}, {"version": "bad"}, {"download_id": "a".repeat(64)}]:
		var candidate: Dictionary = selected.artifact.duplicate(true)
		candidate.merge(mutation, true)
		if not owner.validate_artifact(candidate, "android", "arm64").is_empty():
			return "A fixed APK download accepted altered identity: " + str(mutation)
	return run_checks([
		assert_true(owner.select_release({"schema_version": 2, "latest_version": "0.6.1", "platforms": {"android": {"artifacts": [{}]}}}, "android", "arm64").artifact.is_empty(), "An invalid v2 artifact must not downgrade its trust policy"),
		assert_true(owner.select_release({"latest_version": "0.6.1"}, "android", "x86_64").artifact.is_empty(), "The fixed production APK supports arm64 only"),
		assert_true(owner.validate_artifact(selected.artifact, "windows", "arm64").is_empty(), "APK signature fallback is Android-only"),
	])


func test_macos_keeps_website_flow_even_when_feed_contains_a_native_package() -> String:
	var owner = load(ManifestPath)
	var data := _release()
	data.platforms.macos = {"version": "0.7.0", "artifacts": [{"arch": "universal", "format": "macos_zip", "entry": "Game.app", "url": "https://ptcg.skillserver.cn/mac.zip", "size": 100, "sha256": "a".repeat(64)}]}
	var selected: Dictionary = owner.select_release(data, "macos", "arm64")
	return run_checks([
		assert_true(selected.artifact.is_empty(), "Mac always uses website download, including stale v2 native feeds"),
		assert_true("官网" in selected.native_update_reason, "Mac has a clear website upgrade message"),
		assert_true(owner.validate_artifact(data.platforms.macos.artifacts[0], "macos", "arm64").is_empty(), "Persisted Mac packages cannot bypass the website-only policy"),
	])
