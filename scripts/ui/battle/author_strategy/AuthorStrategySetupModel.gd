extends RefCounted

const MAX_TEXT_LENGTH := 160
const MAX_SHORT_STRATEGY_NAME_LENGTH := 24
const MAX_SHORT_AUTHOR_NAME_LENGTH := 20
const STRATEGY_PACKAGE_MARKERS := [
	" Windows 本地候选",
	" Windows 本地策略",
]
const STRATEGY_PACKAGE_SUFFIXES := [
	"完整作者策略包",
	"完整作者策略",
	"完整策略包",
	"作者策略包",
	"作者策略",
	"本地策略包",
	"本地策略",
]
const VALID_STATUSES := ["ready", "metadata_only", "incompatible", "untrusted", "invalid", "disabled"]
const STATUS_COPY := {
	"ready": {
		"label": "已验证（尚未接入对战）",
		"detail": "目录元数据已验证；AS-WP6 尚无完整 W0–W7 比赛主机，当前不能开始对战。",
	},
	"metadata_only": {
		"label": "仅可查看",
		"detail": "策略包已通过元数据检查，但当前信任配置不允许执行。",
	},
	"incompatible": {
		"label": "版本不兼容",
		"detail": "此策略包与当前游戏接口、卡牌目录或基础执行器不兼容。",
	},
	"untrusted": {
		"label": "签名未受信任",
		"detail": "可以查看公开说明，但不能交给比赛运行时。",
	},
	"invalid": {
		"label": "策略包无效",
		"detail": "策略包格式、签名或公开元数据校验失败。",
	},
	"disabled": {
		"label": "已停用",
		"detail": "此策略包已由本地配置停用。",
	},
}


static func stable_ref(record: Dictionary) -> Dictionary:
	var result := {
		"package_id": str(record.get("package_id", "")),
		"package_version": str(record.get("package_version", "")),
		"archive_sha256": str(record.get("archive_sha256", "")).to_upper(),
	}
	if not _valid_stable_ref(result):
		return {}
	return result


static func stable_key(reference: Dictionary) -> String:
	var normalized := stable_ref(reference)
	if normalized.is_empty():
		return ""
	return "%s\n%s\n%s" % [
		normalized.get("package_id"),
		normalized.get("package_version"),
		normalized.get("archive_sha256"),
	]


static func same_ref(left: Dictionary, right: Dictionary) -> bool:
	var left_key := stable_key(left)
	return left_key != "" and left_key == stable_key(right)


static func normalize_catalog_report(report: Dictionary, preferred_ref: Dictionary = {}) -> Dictionary:
	var records: Array[Dictionary] = []
	var raw_records: Variant = report.get("metadata_records", [])
	if raw_records is Array:
		for value: Variant in raw_records:
			if not value is Dictionary:
				continue
			var normalized := _normalize_record(value)
			if not normalized.is_empty():
				records.append(normalized)

	var selected_index := -1
	var selected_ref: Dictionary = {}
	if preferred_ref.is_empty() and not records.is_empty():
		selected_index = 0
		selected_ref = records[0].get("stable_ref", {}).duplicate(true)
	elif not preferred_ref.is_empty():
		for index: int in records.size():
			if same_ref(records[index].get("stable_ref", {}), preferred_ref):
				selected_index = index
				selected_ref = records[index].get("stable_ref", {}).duplicate(true)
				break

	var diagnostics: Array = report.get("diagnostics", []) if report.get("diagnostics", []) is Array else []
	var empty_reason := ""
	if records.is_empty():
		empty_reason = "catalog_invalid" if not diagnostics.is_empty() else "catalog_empty"
	return {
		"records": records.duplicate(true),
		"selected_index": selected_index,
		"selected_ref": selected_ref,
		"empty_reason": empty_reason,
		"diagnostic_count": diagnostics.size(),
		"start_allowed": false,
	}


static func setup_selection_record(record: Dictionary) -> Dictionary:
	var reference := stable_ref(record)
	if reference.is_empty():
		return {}
	return {
		"package_id": reference.get("package_id"),
		"package_version": reference.get("package_version"),
		"archive_sha256": reference.get("archive_sha256"),
		"display_name_snapshot": _clean_text(record.get("display_name", "未命名策略"), "未命名策略"),
		"install_source": _install_source(record.get("install_source", "")),
	}


static func _normalize_record(source: Dictionary) -> Dictionary:
	var reference := stable_ref(source)
	if reference.is_empty():
		return {}
	var status := str(source.get("status", "invalid"))
	if status not in VALID_STATUSES:
		status = "invalid"
	var author: Dictionary = source.get("author", {}) if source.get("author", {}) is Dictionary else {}
	var strategy: Dictionary = source.get("strategy", {}) if source.get("strategy", {}) is Dictionary else {}
	var deck: Dictionary = source.get("deck", {}) if source.get("deck", {}) is Dictionary else {}
	var status_copy: Dictionary = STATUS_COPY.get(status, STATUS_COPY["invalid"])
	var display_name := _clean_text(strategy.get("display_name", "未命名策略"), "未命名策略")
	var short_display_name := _short_strategy_name(display_name)
	var author_name := _clean_text(author.get("display_name", "未知作者"), "未知作者")
	var version_label := _version_label(reference.get("package_version", ""))
	return {
		"stable_ref": reference.duplicate(true),
		"stable_key": stable_key(reference),
		"package_id": reference.get("package_id"),
		"package_version": reference.get("package_version"),
		"archive_sha256": reference.get("archive_sha256"),
		"display_name": display_name,
		"short_display_name": short_display_name,
		"author_name": author_name,
		"package_version_label": version_label,
		"display_label": "%s · %s · %s" % [
			short_display_name,
			_ellipsize(author_name, MAX_SHORT_AUTHOR_NAME_LENGTH),
			version_label,
		],
		"deck_name": _clean_text(deck.get("display_name", "未命名卡组"), "未命名卡组"),
		"summary": _clean_text(strategy.get("summary", "暂无说明"), "暂无说明"),
		"install_source": _install_source(source.get("install_source", "")),
		"install_sources": _install_sources(source.get("install_sources", [])),
		"status": status,
		"status_label": str(status_copy.get("label", "策略包无效")),
		"status_detail": str(status_copy.get("detail", "当前不能开始对战。")),
		"start_allowed": false,
	}


static func _short_strategy_name(value: String) -> String:
	var result := value.strip_edges()
	for marker: String in STRATEGY_PACKAGE_MARKERS:
		var marker_index := result.rfind(marker)
		if marker_index > 0:
			result = result.left(marker_index).strip_edges()
			break
	var removed_suffix := true
	while removed_suffix:
		removed_suffix = false
		for suffix: String in STRATEGY_PACKAGE_SUFFIXES:
			if result.ends_with(suffix) and result.length() > suffix.length():
				result = result.left(result.length() - suffix.length()).strip_edges()
				removed_suffix = true
				break
	if result.is_empty():
		result = value.strip_edges()
	return _ellipsize(result, MAX_SHORT_STRATEGY_NAME_LENGTH)


static func _version_label(value: Variant) -> String:
	var version := _clean_text(value, "?")
	if version.to_lower().begins_with("v"):
		version = version.substr(1).strip_edges()
	return "v%s" % (version if not version.is_empty() else "?")


static func _ellipsize(value: String, maximum_length: int) -> String:
	if value.length() <= maximum_length:
		return value
	return value.left(maximum_length - 1).strip_edges() + "…"


static func _valid_stable_ref(reference: Dictionary) -> bool:
	var package_id := str(reference.get("package_id", ""))
	var package_version := str(reference.get("package_version", ""))
	var archive_sha256 := str(reference.get("archive_sha256", ""))
	if package_id.is_empty() or package_id.length() > 128 or _contains_control(package_id):
		return false
	if package_version.is_empty() or package_version.length() > 64 or _contains_control(package_version):
		return false
	if archive_sha256.length() != 64:
		return false
	for index: int in archive_sha256.length():
		var code := archive_sha256.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 65 and code <= 70):
			return false
	return true


static func _contains_control(value: String) -> bool:
	for index: int in value.length():
		var code := value.unicode_at(index)
		if code < 32 or code == 127:
			return true
	return false


static func _clean_text(value: Variant, fallback: String) -> String:
	var raw := str(value)
	var result := ""
	var previous_space := false
	for index: int in raw.length():
		var code := raw.unicode_at(index)
		if code < 32 or code == 127:
			if not previous_space and not result.is_empty():
				result += " "
			previous_space = true
			continue
		result += String.chr(code)
		previous_space = code == 32
		if result.length() >= MAX_TEXT_LENGTH:
			break
	result = result.strip_edges()
	return fallback if result.is_empty() else result


static func _install_source(value: Variant) -> String:
	var source := str(value)
	return source if source in ["built_in", "user"] else "unknown"


static func _install_sources(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			var source := _install_source(item)
			if source != "unknown" and source not in result:
				result.append(source)
	if result.is_empty():
		var fallback := _install_source(value)
		if fallback != "unknown":
			result.append(fallback)
	return result
