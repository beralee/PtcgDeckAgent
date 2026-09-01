extends SceneTree

const ReleaseGateScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyReleaseGate.gd")
const PackageLoaderScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd")
const PACKAGE_PATH := "res://data/ptcgdap/author_strategy_packages/ptcgdap-author-strategy-release-candidate.ptcgai"


func _initialize() -> void:
	var gate := ReleaseGateScript.new()
	var release: Dictionary = gate.audit_snapshot()
	var required_paths: Array[String] = gate.required_export_paths()
	var missing: Array[String] = []
	for relative_path: String in required_paths:
		var path := "res://" + relative_path
		if not FileAccess.file_exists(path) and not (path.ends_with(".gd") and FileAccess.file_exists(path.trim_suffix(".gd") + ".gdc")):
			missing.append(relative_path)
	var loader := PackageLoaderScript.new()
	var package_bytes := _read(PACKAGE_PATH)
	var package: Dictionary = loader.inspect_match_bytes(package_bytes)
	var accepted := not required_paths.is_empty() and missing.is_empty()
	accepted = accepted and bool(release.get("contract_ok", false))
	accepted = accepted and release.get("production_ready") == false
	accepted = accepted and bool(package.get("ok", false))
	accepted = accepted and package.get("metadata", {}).get("execution_trusted") == false
	accepted = accepted and package.get("payloads", {}).has("policy/weights.bin")
	var report := {
		"document_type": "author_strategy_export_runtime_probe_v1",
		"schema_version": 1,
		"accepted": accepted,
		"missing_paths": missing,
		"required_path_count": required_paths.size(),
		"present_required_path_count": required_paths.size() - missing.size(),
		"release": release,
		"package_ok": bool(package.get("ok", false)),
		"package_error_code": package.get("error_code", ""),
		"package_bytes": package_bytes.size(),
		"package_sha256": _sha(package_bytes),
		"package_execution_trusted": package.get("metadata", {}).get("execution_trusted"),
		"weights_present": package.get("payloads", {}).has("policy/weights.bin"),
	}
	print("PTCGDAP_EXPORT_INVENTORY=" + JSON.stringify(report))
	quit(0 if accepted else 1)


func _read(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	return PackedByteArray() if file == null else file.get_buffer(file.get_length())


func _sha(value: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value)
	return context.finish().hex_encode().to_upper()
