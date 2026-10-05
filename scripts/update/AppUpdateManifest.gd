extends RefCounted
## Public HTTPS feed for full application updates. Strategy packages use their
## own independent trust/installation owner and never enter this path.

const DOWNLOAD_PAGE := "https://ptcg.skillserver.cn/"
const DOWNLOAD_ORIGIN := "https://ptcg.skillserver.cn/"
const ANDROID_APK_URL := "https://ptcg.skillserver.cn/dist/downloads/ptcgdeckagent-android.apk"
const MAX_PACKAGE_BYTES := 2 * 1024 * 1024 * 1024
const FORMATS := {"windows": "windows_zip", "android": "android_apk"}


static func platform_key() -> String:
	if OS.has_feature("web"):
		return "web"
	return {"Windows": "windows", "macOS": "macos", "Android": "android"}.get(OS.get_name(), OS.get_name().to_lower())


static func architecture() -> String:
	return {"arm64": "arm64", "x86_64": "x86_64", "arm32": "arm32", "x86_32": "x86"}.get(Engine.get_architecture_name(), "unknown")


static func valid_version(value: Variant) -> bool:
	if not value is String or value.length() > 48:
		return false
	var expression := RegEx.new()
	expression.compile("^[0-9]{1,8}\\.[0-9]{1,8}\\.[0-9]{1,8}(\\.[0-9]{1,8})?$")
	return expression.search(value) != null


static func safe_page(value: Variant) -> String:
	return value if value is String and value.begins_with(DOWNLOAD_ORIGIN) and not _has_control(value) else DOWNLOAD_PAGE


static func compare_versions(left: String, right: String) -> int:
	var a := left.split(".")
	var b := right.split(".")
	for index: int in maxi(a.size(), b.size()):
		var x := int(a[index]) if index < a.size() else 0
		var y := int(b[index]) if index < b.size() else 0
		if x != y:
			return 1 if x > y else -1
	return 0


static func select_release(data: Dictionary, platform: String, arch: String) -> Dictionary:
	var schema: Variant = data.get("schema_version", 1)
	# Godot parses JSON numeric fields as floats; Array.has uses strict types.
	if typeof(schema) not in [TYPE_INT, TYPE_FLOAT] or float(schema) not in [1.0, 2.0] or str(data.get("channel", "stable")) != "stable":
		return {}
	var platforms: Variant = data.get("platforms", {})
	var target: Dictionary = {}
	if platforms is Dictionary and platforms.get(platform, {}) is Dictionary:
		target = platforms.get(platform, {})
	var version := str(target.get("version", data.get("latest_version", data.get("version", "")))).trim_prefix("v").trim_prefix("V")
	if not valid_version(version):
		return {}
	var result := {
		"latest_version": version,
		"download_page_url": safe_page(target.get("download_page_url", target.get("page_url", data.get("download_page_url", DOWNLOAD_PAGE)))),
		"artifact": {},
		"native_update_reason": "这个平台暂未提供游戏内更新包，请点击“去网页下载”。",
	}
	var artifacts: Variant = target.get("artifacts", [])
	if int(schema) == 1 and platform == "android" and arch == "arm64":
		result.artifact = fixed_android_download(version)
		result.native_update_reason = ""
		return result
	if platform == "macos":
		result.native_update_reason = "macOS 版本请前往官网下载新版，按原有方式安装。"
		result["website_only"] = true
		return result
	if int(schema) != 2 or not artifacts is Array or artifacts.size() > 8:
		return result
	var candidates: Array[Dictionary] = []
	for item: Variant in artifacts:
		if not item is Dictionary:
			continue
		if item.get("verification") == "android_signature":
			continue # The fixed-address fallback is a client-owned v1 policy only.
		var selected: Dictionary = validate_artifact(item, platform, arch)
		if not selected.is_empty():
			candidates.append(selected)
	# Ambiguous feeds are not installation authority.
	if candidates.size() == 1:
		result["artifact"] = candidates[0]
		result["native_update_reason"] = ""
	return result


static func validate_artifact(item: Dictionary, platform: String, arch: String) -> Dictionary:
	if item.get("verification") == "android_signature":
		if platform != "android" or arch != "arm64" or not valid_version(item.get("version", "")):
			return {}
		var fixed := fixed_android_download(str(item.version))
		var normalized := item.duplicate(true)
		if typeof(normalized.get("size")) not in [TYPE_INT, TYPE_FLOAT] or normalized.size != 0:
			return {}
		normalized.size = 0 # JSON restores the bounded zero-size placeholder as float.
		# This grants transport only. Native signature/identity/version validation
		# must produce real size, digest and build before the ordinary install gate.
		return fixed if normalized == fixed else {}
	if not FORMATS.has(platform) or item.get("format") != FORMATS[platform]:
		return {}
	var artifact_arch: Variant = item.get("arch")
	if artifact_arch != arch and not (artifact_arch == "universal" and platform == "android"):
		return {}
	var url: Variant = item.get("url")
	var size: Variant = item.get("size")
	var digest: Variant = item.get("sha256")
	if not url is String or not url.begins_with(DOWNLOAD_ORIGIN) or url.length() > 2048 or _has_control(url) or "\\" in url:
		return {}
	# JSON numbers arrive as floats in Godot; only exact bounded integers qualify.
	if typeof(size) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(size)) or float(size) != floor(float(size)) or size <= 0 or size > MAX_PACKAGE_BYTES:
		return {}
	if not digest is String or digest.length() != 64 or not digest.is_valid_hex_number(false):
		return {}
	var entry: Variant = item.get("entry", "")
	if not entry is String or not safe_component(entry):
		return {}
	var suffix: String = {"windows": ".exe", "macos": ".app", "android": ".apk"}[platform]
	if not entry.ends_with(suffix):
		return {}
	if platform == "android":
		var code: Variant = item.get("build", 0)
		if typeof(code) not in [TYPE_INT, TYPE_FLOAT] or float(code) != floor(float(code)) or code <= 0 or code > 2100000000:
			return {}
	return {
		"arch": artifact_arch, "format": item.format, "url": url,
		"size": int(size), "sha256": digest.to_lower(), "entry": entry,
		"build": int(item.get("build", 0)),
	}


static func fixed_android_download(version: String) -> Dictionary:
	return {"verification": "android_signature", "version": version,
		"url": ANDROID_APK_URL, "arch": "arm64", "format": "android_apk",
		"entry": "PtcgDeckAgent.apk", "size": 0,
		"download_id": (ANDROID_APK_URL + "\n" + version).sha256_text()}


static func safe_component(value: String) -> bool:
	if value.is_empty() or value.length() > 120 or value in [".", ".."] or value.ends_with(".") or value.ends_with(" "):
		return false
	for forbidden: String in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", "%"]:
		if forbidden in value:
			return false
	var basename := value.get_basename().to_upper()
	if basename in ["CON", "PRN", "AUX", "NUL"] or (basename.length() == 4 and basename.left(3) in ["COM", "LPT"] and basename.right(1).is_valid_int()):
		return false
	return not _has_control(value)


static func _has_control(value: String) -> bool:
	for index: int in value.length():
		if value.unicode_at(index) < 32 or value.unicode_at(index) == 127:
			return true
	return false
