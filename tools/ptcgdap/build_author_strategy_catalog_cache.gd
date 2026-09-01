extends SceneTree

const PACKAGE_ROOT := "res://data/ptcgdap/author_strategy_packages"
const OUTPUT_PATH := "res://data/ptcgdap/author_strategy_catalog_cache.json"


func _initialize() -> void:
	OS.set_environment("PTCGDAP_AUTHOR_CATALOG_STARTUP_PROFILE", "deep_scan_v1")
	var sources: Array[Dictionary] = []
	var filenames := DirAccess.get_files_at(PACKAGE_ROOT)
	filenames.sort()
	for filename: String in filenames:
		if not filename.ends_with(".ptcgai"):
			continue
		sources.append({
			"install_source": "built_in",
			"location_id": filename,
			"archive_path": PACKAGE_ROOT.path_join(filename),
		})

	# Load after SceneTree initialization so project autoload symbols used by the
	# catalog's deck gate are registered before dependent scripts are compiled.
	var catalog_script: GDScript = load(
		"res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd"
	) as GDScript
	if catalog_script == null or not catalog_script.can_instantiate():
		push_error("author strategy package catalog could not be loaded")
		quit(1)
		return
	var catalog: Variant = catalog_script.new()
	catalog.set_persistent_cache_path_for_tests(OUTPUT_PATH)
	var report: Dictionary = catalog.rebuild_from_paths_for_test(sources)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT_PATH))
	var locations: Dictionary = parsed.get("locations", {}) if parsed is Dictionary else {}
	var entries: Dictionary = parsed.get("entries", {}) if parsed is Dictionary else {}
	var expected_locations := sources.size()
	var exit_code := 0
	if not (parsed is Dictionary) or locations.size() != expected_locations:
		exit_code = 1
		push_error("catalog cache generation incomplete: expected_locations=%d actual_locations=%d" % [
			expected_locations,
			locations.size(),
		])
	else:
		print("AUTHOR_STRATEGY_CATALOG_CACHE entries=%d locations=%d metadata_records=%d" % [
			entries.size(),
			locations.size(),
			(report.get("metadata_records", []) as Array).size(),
		])
	catalog.free()
	quit(exit_code)
