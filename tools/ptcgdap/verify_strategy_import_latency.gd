extends Node

const CatalogScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd")
const LoaderScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd")
const PACKAGE_PATH := "res://data/ptcgdap/author_strategy_packages/ogerpon-crustle-v523a-supporter-r4-1.4.0.ptcgai"
const MAX_INTERACTIVE_IMPORT_MSEC := 5000.0


func _ready() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var catalog := CatalogScript.new()
	var startup_started_usec := Time.get_ticks_usec()
	var startup_report: Dictionary = catalog.scan_startup()
	var startup_elapsed_usec := maxi(0, Time.get_ticks_usec() - startup_started_usec)
	var archive_bytes := FileAccess.get_file_as_bytes(PACKAGE_PATH)
	var loader := LoaderScript.new()
	var inspected: Dictionary = loader.inspect_match_bytes(archive_bytes)
	if not bool(inspected.get("ok", false)):
		print("PTCGDAP_STRATEGY_IMPORT_LATENCY=" + JSON.stringify({
			"accepted": false,
			"error_code": str(inspected.get("error_code", "package_archive_invalid")),
		}))
		catalog.free()
		get_tree().quit(1)
		return
	var metadata: Dictionary = inspected.get("metadata", {})
	var expected := {
		"package_id": metadata.get("package_id"),
		"package_version": metadata.get("package_version"),
		"archive_sha256": metadata.get("archive_sha256"),
		"manifest_canonical_sha256": metadata.get("manifest_canonical_sha256"),
	}
	var install_started_usec := Time.get_ticks_usec()
	var installed: Dictionary = catalog.install_from_bytes(archive_bytes, expected)
	var install_elapsed_usec := maxi(0, Time.get_ticks_usec() - install_started_usec)
	var install_elapsed_msec := float(install_elapsed_usec) / 1000.0
	var accepted: bool = bool(installed.get("ok", false)) \
		and bool(installed.get("catalog_discoverable", false)) \
		and install_elapsed_msec <= MAX_INTERACTIVE_IMPORT_MSEC
	print("PTCGDAP_STRATEGY_IMPORT_LATENCY=" + JSON.stringify({
		"accepted": accepted,
		"document_type": "ptcgdap_strategy_import_latency_v1",
		"schema_version": 1,
		"package_id": expected.get("package_id"),
		"package_version": expected.get("package_version"),
		"archive_sha256": expected.get("archive_sha256"),
		"startup_elapsed_usec": startup_elapsed_usec,
		"startup_record_count": startup_report.get("metadata_records", []).size(),
		"install_elapsed_usec": install_elapsed_usec,
		"identity_resolution_usec": installed.get("identity_resolution_usec", -1),
		"catalog_refresh_usec": installed.get("catalog_refresh_usec", -1),
		"already_installed": installed.get("already_installed", false),
		"catalog_discoverable": installed.get("catalog_discoverable", false),
		"max_interactive_import_msec": MAX_INTERACTIVE_IMPORT_MSEC,
		"error_code": installed.get("error_code", ""),
	}))
	catalog.free()
	get_tree().quit(0 if accepted else 1)
