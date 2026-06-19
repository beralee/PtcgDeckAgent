class_name TestExportPresets
extends TestBase

const EXPORT_PRESETS_PATH := "res://export_presets.cfg"
const PROJECT_GODOT_PATH := "res://project.godot"
const APP_VERSION_PATH := "res://scripts/app/AppVersion.gd"
const WEB_RELEASE_SCRIPT_PATH := "res://scripts/tools/export_web_release.ps1"
const WEB_RELEASE_PLUGIN_CFG_PATH := "res://addons/web_release_post_export/plugin.cfg"
const WEB_RELEASE_PLUGIN_PATH := "res://addons/web_release_post_export/web_release_export_plugin.gd"
const WEB_RELEASE_LAYOUT_PATH := "res://addons/web_release_post_export/web_release_layout.gd"
const WEB_CUSTOM_SHELL_PATH := "res://web/ptcg_web_shell.html"
const REQUIRED_BUNDLED_FILTER := "data/**"
const WEB_PRESET_NAME := "Web"
const WEB_EXCLUDE_FILTERS := ["tests/**", "docs/**", ".tmp/**", ".godot_test_user/**", "addons/web_release_post_export/**"]


func test_web_export_includes_bundled_user_data() -> String:
	var preset_text := FileAccess.get_file_as_string(EXPORT_PRESETS_PATH)
	var web_block := _extract_preset_block(preset_text, WEB_PRESET_NAME)
	var include_filter := _extract_string_value(web_block, "include_filter")

	return run_checks([
		assert_true(web_block != "", "Web export preset should exist"),
		assert_true(include_filter.split(",").has(REQUIRED_BUNDLED_FILTER), "Web export should include bundled data files such as card JSON and card image .bin files"),
	])


func test_web_export_path_is_ide_friendly_and_plugin_versionizes_it() -> String:
	var preset_text := FileAccess.get_file_as_string(EXPORT_PRESETS_PATH)
	var app_version := _extract_app_version()
	var web_block := _extract_preset_block(preset_text, WEB_PRESET_NAME)
	var export_path := _extract_string_value(web_block, "export_path")
	var plugin_text := FileAccess.get_file_as_string(WEB_RELEASE_PLUGIN_PATH)

	return run_checks([
		assert_true(app_version != "", "App version should be readable"),
		assert_false(export_path.contains("/releases/"), "IDE Web export path should stay easy to select; the post-export plugin should create releases/<version> automatically"),
		assert_true(export_path.ends_with("/PtcgDeckAgent.html"), "Web export should use the stable PtcgDeckAgent basename for versioned assets"),
		assert_true(plugin_text.contains("prepare_release_directory(export_file_path, AppVersion.VERSION)"), "Post-export plugin should normalize flat IDE exports into a CDN-safe release slug"),
	])


func test_web_progressive_web_app_is_enabled() -> String:
	var preset_text := FileAccess.get_file_as_string(EXPORT_PRESETS_PATH)
	var web_options := _extract_preset_options_block(preset_text, WEB_PRESET_NAME)
	var icon_144 := _extract_string_value(web_options, "progressive_web_app/icon_144x144")
	var icon_180 := _extract_string_value(web_options, "progressive_web_app/icon_180x180")
	var icon_512 := _extract_string_value(web_options, "progressive_web_app/icon_512x512")

	return run_checks([
		assert_true(_extract_bool_value(web_options, "progressive_web_app/enabled"), "Web export should enable PWA caching support"),
		assert_true(_extract_bool_value(web_options, "progressive_web_app/ensure_cross_origin_isolation_headers"), "Web PWA should keep cross-origin isolation header support enabled"),
		assert_true(icon_144 != "" and FileAccess.file_exists(icon_144), "PWA 144 icon should be configured and exist"),
		assert_true(icon_180 != "" and FileAccess.file_exists(icon_180), "PWA 180 icon should be configured and exist"),
		assert_true(icon_512 != "" and FileAccess.file_exists(icon_512), "PWA 512 icon should be configured and exist"),
	])


func test_export_presets_use_unified_app_icon_assets() -> String:
	var preset_text := FileAccess.get_file_as_string(EXPORT_PRESETS_PATH)
	var windows_options := _extract_preset_options_block(preset_text, "Windows Desktop")
	var mac_options := _extract_preset_options_block(preset_text, "macOS")
	var android_options := _extract_preset_options_block(preset_text, "Android")
	var web_options := _extract_preset_options_block(preset_text, WEB_PRESET_NAME)
	var ios_options := _extract_preset_options_block(preset_text, "iOS")
	var icon_keys := {
		"Windows icon": _extract_string_value(windows_options, "application/icon"),
		"macOS icon": _extract_string_value(mac_options, "application/icon"),
		"Android launcher icon": _extract_string_value(android_options, "launcher_icons/main_192x192"),
		"Web PWA 144 icon": _extract_string_value(web_options, "progressive_web_app/icon_144x144"),
		"Web PWA 180 icon": _extract_string_value(web_options, "progressive_web_app/icon_180x180"),
		"Web PWA 512 icon": _extract_string_value(web_options, "progressive_web_app/icon_512x512"),
		"iOS app icon": _extract_string_value(ios_options, "icons/icon_1024x1024"),
		"iOS store icon": _extract_string_value(ios_options, "icons/app_store_1024x1024"),
	}
	var checks: Array[String] = []
	for label: String in icon_keys.keys():
		var icon_path := str(icon_keys[label])
		checks.append(assert_true(icon_path.begins_with("res://assets/ui/app_icon/"), "%s should use the unified app icon asset folder" % label))
		checks.append(assert_false(icon_path.ends_with("title.png"), "%s should not reuse the homepage title art as an app icon" % label))
		checks.append(assert_true(FileAccess.file_exists(icon_path), "%s path should exist" % label))
	return run_checks(checks)


func test_web_uses_custom_ios_first_html_shell() -> String:
	var preset_text := FileAccess.get_file_as_string(EXPORT_PRESETS_PATH)
	var web_options := _extract_preset_options_block(preset_text, WEB_PRESET_NAME)
	var shell_path := _extract_string_value(web_options, "html/custom_html_shell")

	return run_checks([
		assert_eq(shell_path, WEB_CUSTOM_SHELL_PATH, "Web export should use the custom iOS-first HTML shell"),
		assert_true(FileAccess.file_exists(WEB_CUSTOM_SHELL_PATH), "Custom Web shell should exist"),
	])


func test_web_custom_shell_keeps_godot_and_pwa_hooks() -> String:
	var shell_text := FileAccess.get_file_as_string(WEB_CUSTOM_SHELL_PATH)

	return run_checks([
		assert_true(shell_text.contains("$GODOT_URL"), "Custom shell should load the exported Godot JavaScript file"),
		assert_true(shell_text.contains("$GODOT_CONFIG"), "Custom shell should pass Godot export config into Engine"),
		assert_true(shell_text.contains("$GODOT_HEAD_INCLUDE"), "Custom shell should preserve generated PWA icon and manifest head includes"),
		assert_true(shell_text.contains("$GODOT_THREADS_ENABLED"), "Custom shell should preserve Godot missing-feature checks for threaded exports"),
		assert_true(shell_text.contains("Engine.getMissingFeatures"), "Custom shell should keep Godot Web feature detection"),
		assert_true(shell_text.contains("installServiceWorker"), "Custom shell should keep service-worker recovery for cross-origin isolation"),
		assert_true(shell_text.contains("engine.startGame"), "Custom shell should start Godot through the supported Engine API"),
	])


func test_web_custom_shell_has_click_start_and_ios_layout_guards() -> String:
	var shell_text := FileAccess.get_file_as_string(WEB_CUSTOM_SHELL_PATH)

	return run_checks([
		assert_true(shell_text.contains("id=\"start-game\""), "Custom shell should gate startup behind an explicit player click"),
		assert_false(shell_text.contains("id=\"start-game-landscape\""), "Custom shell should not expose a separate landscape startup button"),
		assert_false(shell_text.contains("--ptcg-web-launch-layout="), "Custom shell should not choose layout through Godot command-line args"),
		assert_true(shell_text.contains("clearWebLaunchLayoutPreference"), "Custom shell should clear stale layout choices from older deployments before starting"),
		assert_false(shell_text.contains("requestFullscreen"), "Custom shell should not force browser fullscreen from the click gesture"),
		assert_false(shell_text.contains("function isMobileBrowserRuntime()"), "Custom shell should not branch into mobile browser fullscreen handling"),
		assert_false(shell_text.contains("function bestEffortLandscapeOrientation()"), "Custom shell should not attempt a landscape orientation lock"),
		assert_false(shell_text.contains("orientation.lock('landscape')"), "Custom shell should not request browser orientation lock"),
		assert_false(shell_text.contains("bestEffortFullscreen().then(bestEffortLandscapeOrientation)"), "Custom shell should not chain fullscreen before orientation lock"),
		assert_true(shell_text.contains("AudioContext"), "Custom shell should unlock browser audio from the click gesture"),
		assert_true(shell_text.contains("viewport-fit=cover"), "Custom shell should opt into iOS safe-area viewport handling"),
		assert_true(shell_text.contains("user-scalable=no"), "Custom shell should prevent iOS double-tap zoom during play"),
		assert_true(shell_text.contains("apple-mobile-web-app-capable"), "Custom shell should include iOS PWA meta"),
		assert_false(shell_text.contains("100dvh"), "Custom shell should avoid dynamic viewport height while Android canvas sizing is being stabilized"),
		assert_true(shell_text.contains("safe-area-inset"), "Custom shell should account for iOS safe areas"),
		assert_true(shell_text.contains("touch-action: none"), "Custom shell should prevent browser gesture interference"),
		assert_true(shell_text.contains("-webkit-user-select: none"), "Custom shell should prevent long-press text selection"),
	])


func test_web_custom_shell_has_perceptible_loading_copy() -> String:
	var shell_text := FileAccess.get_file_as_string(WEB_CUSTOM_SHELL_PATH)

	return run_checks([
		assert_true(shell_text.contains("TEXT_LOADING_DOWNLOAD"), "Custom shell should distinguish download progress"),
		assert_true(shell_text.contains("\\u6b63\\u5728\\u4e0b\\u8f7d\\u6e38\\u620f\\u8d44\\u6e90"), "Download progress copy should be encoded safely"),
		assert_true(shell_text.contains("TEXT_LOADING_ENGINE"), "Custom shell should distinguish engine initialization"),
		assert_true(shell_text.contains("\\u6b63\\u5728\\u521d\\u59cb\\u5316\\u5f15\\u64ce"), "Engine initialization copy should be encoded safely"),
		assert_true(shell_text.contains("&#39318;&#27425;&#21152;&#36733;&#31245;&#24930;"), "Custom shell should explain first-load cost"),
		assert_true(shell_text.contains("&#28155;&#21152;&#21040;&#20027;&#23631;&#24149;"), "Custom shell should provide a PWA install hint"),
	])


func test_web_custom_shell_has_safe_latest_version_upgrade_action() -> String:
	var shell_text := FileAccess.get_file_as_string(WEB_CUSTOM_SHELL_PATH)

	return run_checks([
		assert_true(shell_text.contains("latest-web.json"), "Custom shell should check the moving Web latest pointer"),
		assert_true(shell_text.contains("id=\"start-new-version\""), "Custom shell should offer a new-version launch button when an update exists"),
		assert_true(shell_text.contains("latest.entry"), "New-version launch should prefer the canonical entry URL from latest-web.json"),
		assert_true(shell_text.contains("release_path"), "New-version launch should fall back to release_path when entry is absent"),
		assert_true(shell_text.contains("getCurrentWebVersion"), "Custom shell should compare the current versioned directory with latest-web.json"),
		assert_true(shell_text.contains("clearOldWebReleaseCache"), "Custom shell should attempt to remove old Web resource caches before switching versions"),
		assert_true(shell_text.contains("PtcgDeckAgent-sw-cache-"), "Cache cleanup should target Godot PWA caches"),
		assert_true(shell_text.contains("navigator.serviceWorker.getRegistration('./')"), "Cache cleanup should unregister the current version service worker scope"),
		assert_false(shell_text.contains("../../' + d.web_version"), "New-version links should not rebuild the old broken sibling path by string concatenation"),
		assert_false(shell_text.contains("localStorage.clear()"), "Upgrade cache cleanup must not erase player local storage"),
		assert_false(shell_text.contains("indexedDB.deleteDatabase"), "Upgrade cache cleanup must not erase player IndexedDB data"),
	])


func test_web_custom_shell_is_ascii_safe_for_export_encoding() -> String:
	var shell_text := FileAccess.get_file_as_string(WEB_CUSTOM_SHELL_PATH)

	return run_checks([
		assert_true(_is_ascii_only(shell_text), "Custom Web shell should stay ASCII-only; use HTML entities and JS unicode escapes for Chinese text to avoid export encoding mojibake"),
	])


func test_web_export_excludes_development_only_files() -> String:
	var preset_text := FileAccess.get_file_as_string(EXPORT_PRESETS_PATH)
	var web_block := _extract_preset_block(preset_text, WEB_PRESET_NAME)
	var windows_block := _extract_preset_block(preset_text, "Windows Desktop")
	var web_exclude_filter := _extract_string_value(web_block, "exclude_filter")
	var web_filters := web_exclude_filter.split(",")
	var checks: Array[String] = []
	for filter: String in WEB_EXCLUDE_FILTERS:
		checks.append(assert_true(web_filters.has(filter), "Web export should exclude development-only path %s" % filter))
	checks.append(assert_eq(_extract_string_value(windows_block, "exclude_filter"), "", "Windows full export should not be changed by Web-only trimming"))
	return run_checks(checks)


func test_web_release_script_generates_versioned_manifests() -> String:
	var script_text := FileAccess.get_file_as_string(WEB_RELEASE_SCRIPT_PATH)

	return run_checks([
		assert_true(script_text != "", "Web release script should exist"),
		assert_true(script_text.contains("AppVersion.gd"), "Web release script should read the app version"),
		assert_true(script_text.contains("--export-release"), "Web release script should run Godot's Web export"),
		assert_true(script_text.contains("latest-web.json"), "Web release script should write the moving latest pointer"),
		assert_true(script_text.contains("release-manifest.json"), "Web release script should write a versioned release manifest"),
		assert_true(script_text.contains("Where-Object { $_.Name -ne \"release-manifest.json\" }"), "Web release script should not hash a stale previous release manifest into the new manifest"),
		assert_true(script_text.contains("Get-FileHash"), "Web release script should hash versioned assets"),
		assert_true(script_text.contains("/dist"), "Web release script should default to the deployed /dist public base path"),
		assert_true(script_text.contains("Get-ReleaseSlug"), "Web release script should use a CDN-safe release slug without dots"),
		assert_true(script_text.contains("$publicBase/web/$releaseSlug"), "Web release script should place versioned resources under /dist/web/<slug>"),
	])


func test_web_release_post_export_plugin_is_enabled() -> String:
	var project_text := FileAccess.get_file_as_string(PROJECT_GODOT_PATH)
	var cfg_text := FileAccess.get_file_as_string(WEB_RELEASE_PLUGIN_CFG_PATH)

	return run_checks([
		assert_true(project_text.contains("[editor_plugins]"), "Project should enable editor plugins"),
		assert_true(project_text.contains(WEB_RELEASE_PLUGIN_CFG_PATH), "Web release post-export plugin should be enabled in project.godot"),
		assert_true(cfg_text.contains("script=\"plugin.gd\""), "Web release plugin.cfg should point to the editor plugin entry script using Godot's plugin-relative path"),
	])


func test_web_release_post_export_plugin_generates_metadata() -> String:
	var plugin_text := FileAccess.get_file_as_string(WEB_RELEASE_PLUGIN_PATH)

	return run_checks([
		assert_true(plugin_text.contains("extends EditorExportPlugin"), "Web release post-export hook should use Godot's EditorExportPlugin"),
		assert_true(plugin_text.contains(WEB_RELEASE_LAYOUT_PATH), "Web release plugin should use the tested release-layout helper"),
		assert_true(plugin_text.contains("func _get_name"), "Web release post-export hook should implement Godot's required EditorExportPlugin name method"),
		assert_true(plugin_text.contains("func _export_begin"), "Web release plugin should detect the export target at export begin"),
		assert_true(plugin_text.contains("func _export_end"), "Web release plugin should generate metadata after export finishes"),
		assert_true(plugin_text.contains("latest-web.json"), "Web release plugin should write the moving latest pointer during Godot export"),
		assert_true(plugin_text.contains("release-manifest.json"), "Web release plugin should write the versioned release manifest during Godot export"),
		assert_true(plugin_text.contains("FileAccess.get_sha256"), "Web release plugin should hash release files during Godot export"),
		assert_true(plugin_text.contains("file_name != RELEASE_MANIFEST_FILE_NAME"), "Web release plugin should not include a stale previous manifest in the new manifest"),
		assert_true(plugin_text.contains("_infer_release_path"), "Web release plugin should write public URLs based on the normalized release directory"),
	])


func _extract_preset_block(preset_text: String, preset_name: String) -> String:
	var current_block := PackedStringArray()
	var in_block := false
	var current_name := ""
	for raw_line: String in preset_text.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("[preset.") and line.ends_with("]"):
			if in_block and current_name == preset_name:
				return "\n".join(current_block)
			current_block = PackedStringArray([line])
			in_block = true
			current_name = ""
			continue
		if not in_block:
			continue
		current_block.append(line)
		if line.begins_with("name="):
			current_name = _unquote(line.substr("name=".length()))
	if in_block and current_name == preset_name:
		return "\n".join(current_block)
	return ""


func _extract_preset_options_block(preset_text: String, preset_name: String) -> String:
	var preset_index := _extract_preset_index(preset_text, preset_name)
	if preset_index == "":
		return ""
	return _extract_section_block(preset_text, "[preset.%s.options]" % preset_index)


func _extract_preset_index(preset_text: String, preset_name: String) -> String:
	var in_block := false
	var current_index := ""
	for raw_line: String in preset_text.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("[preset.") and line.ends_with("]") and not line.ends_with(".options]"):
			in_block = true
			current_index = line.trim_prefix("[preset.").trim_suffix("]")
			continue
		if not in_block:
			continue
		if line.begins_with("[") and line.ends_with("]"):
			in_block = false
			current_index = ""
			continue
		if line.begins_with("name=") and _unquote(line.substr("name=".length())) == preset_name:
			return current_index
	return ""


func _extract_section_block(preset_text: String, section_name: String) -> String:
	var lines := PackedStringArray()
	var in_section := false
	for raw_line: String in preset_text.split("\n"):
		var line := raw_line.strip_edges()
		if line == section_name:
			in_section = true
			lines.append(line)
			continue
		if in_section and line.begins_with("[") and line.ends_with("]"):
			return "\n".join(lines)
		if in_section:
			lines.append(line)
	return "\n".join(lines) if in_section else ""


func _extract_string_value(block: String, key: String) -> String:
	for raw_line: String in block.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("%s=" % key):
			return _unquote(line.substr(key.length() + 1))
	return ""


func _extract_bool_value(block: String, key: String) -> bool:
	for raw_line: String in block.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("%s=" % key):
			return line.substr(key.length() + 1).strip_edges() == "true"
	return false


func _extract_app_version() -> String:
	var version_text := FileAccess.get_file_as_string(APP_VERSION_PATH)
	var marker := "const VERSION := \""
	var start := version_text.find(marker)
	if start < 0:
		return ""
	start += marker.length()
	var end := version_text.find("\"", start)
	if end < 0:
		return ""
	return version_text.substr(start, end - start)


func _is_ascii_only(text: String) -> bool:
	for index: int in range(text.length()):
		if text.unicode_at(index) > 127:
			return false
	return true


func _unquote(value: String) -> String:
	var trimmed := value.strip_edges()
	if trimmed.length() >= 2 and trimmed.begins_with("\"") and trimmed.ends_with("\""):
		return trimmed.substr(1, trimmed.length() - 2)
	return trimmed
