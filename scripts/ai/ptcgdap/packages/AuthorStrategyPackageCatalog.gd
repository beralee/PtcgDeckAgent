extends Node

signal catalog_ready(report: Dictionary)
signal catalog_changed(report: Dictionary)
signal package_rejected(diagnostic: Dictionary)

const LoaderScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd")
const HandleScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageHandle.gd")
const DeckGateScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyDeckGate.gd")
const ReleaseGateScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyReleaseGate.gd")
const FeatureGateScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyFeatureGate.gd")
const InstallerScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageInstaller.gd")
const RemovalStoreScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageRemovalStore.gd")
const BUILT_IN_ROOT := "res://data/ptcgdap/author_strategy_packages"
const USER_ROOT := "user://ptcgdap/author_strategy_packages"
const INSTALL_SOURCES := ["built_in", "user"]
const BUILT_IN_CACHE_PATH := "res://data/ptcgdap/author_strategy_catalog_cache.json"
const PERSISTENT_CACHE_PATH := "user://ptcgdap/author_strategy_catalog_cache.json"
const PERSISTENT_CACHE_SCHEMA_VERSION := 2
const MAX_CACHE_FILE_BYTES := 2 * 1024 * 1024
const MAX_CACHE_ENTRY_COUNT := 512
const MAX_CACHE_LOCATION_COUNT := 1024
const STARTUP_PROFILE_ENV := "PTCGDAP_AUTHOR_CATALOG_STARTUP_PROFILE"
const STARTUP_PROFILE_CACHED := "cached_v2"
const STARTUP_PROFILE_DEEP_SCAN := "deep_scan_v1"
const EAGER_SCAN_ARGS := [
	"--ptcgdap-development-export-match",
	"--ptcgdap-development-ui-match",
	"--ptcgdap-production-device-canary",
]

var _loader: Variant = null
var _metadata_records: Array[Dictionary] = []
var _ready_records: Array[Dictionary] = []
var _diagnostics: Array[Dictionary] = []
var _metadata_cache := {}
var _match_locations := {}
var _scan_generation := 0
var _last_cache_hits := 0
var _last_cache_misses := 0
var _last_scan_elapsed_usec := 0
var _release_gate: RefCounted = null
var _installer: RefCounted = null
var _removal_store: RefCounted = null
var _removed_package_keys := {}
var _removal_store_error := ""
var _persistent_cache_path := PERSISTENT_CACHE_PATH
var _persistent_cache_enabled := false
var _persistent_cache_loaded := false
var _persistent_cache_dirty := false
var _persistent_cache_keys := {}
var _bundled_cache_keys := {}
var _location_cache := {}
var _location_cache_origins := {}
var _next_location_cache := {}
var _track_scan_locations := false
var _last_persistent_cache_hits := 0
var _last_startup_location_cache_hits := 0
var _last_startup_location_cache_misses := 0
var _last_bundled_location_cache_hits := 0


func _ready() -> void:
	_loader = LoaderScript.new()
	_release_gate = ReleaseGateScript.new()
	_installer = InstallerScript.new()
	_removal_store = RemovalStoreScript.new()
	if not FeatureGateScript.is_enabled():
		scan_startup()
		return
	_ensure_user_root()
	_persistent_cache_enabled = true
	if _requires_eager_startup_scan():
		scan_startup()
	else:
		call_deferred("_scan_startup_after_first_frame")


func _scan_startup_after_first_frame() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if is_inside_tree() and _scan_generation == 0:
		scan_startup()


func _requires_eager_startup_scan() -> bool:
	var args := OS.get_cmdline_user_args()
	for arg: String in EAGER_SCAN_ARGS:
		if arg in args:
			return true
	return false


func scan_startup() -> Dictionary:
	var started_usec := Time.get_ticks_usec()
	_persistent_cache_enabled = true
	_load_persistent_metadata_cache()
	_begin_location_scan()
	_refresh_removed_package_keys()
	if not FeatureGateScript.is_enabled():
		_disable_catalog()
		_last_scan_elapsed_usec = maxi(0, Time.get_ticks_usec() - started_usec)
		var disabled_report := _report()
		catalog_ready.emit(disabled_report.duplicate(true))
		catalog_changed.emit(disabled_report.duplicate(true))
		return disabled_report
	var candidates: Array[Dictionary] = []
	candidates.append_array(_capture_root(BUILT_IN_ROOT, "built_in"))
	candidates.append_array(_capture_root(USER_ROOT, "user"))
	var report := _rebuild(candidates)
	_last_scan_elapsed_usec = maxi(0, Time.get_ticks_usec() - started_usec)
	catalog_ready.emit(report.duplicate(true))
	catalog_changed.emit(report.duplicate(true))
	return report


func rebuild_from_captured_for_test(candidates: Array[Dictionary]) -> Dictionary:
	# This accepts only already-captured test bytes and still produces metadata-only
	# records. It is not a path override and cannot grant match authority.
	_track_scan_locations = false
	return _rebuild(candidates.duplicate(true)) if FeatureGateScript.is_enabled() else _disable_catalog()


func rebuild_from_paths_for_test(sources: Array) -> Dictionary:
	# The caller supplies fixed test paths only. Production roots remain constants.
	_persistent_cache_enabled = true
	_load_persistent_metadata_cache()
	_begin_location_scan()
	var candidates: Array[Dictionary] = []
	for value: Variant in sources:
		if not (value is Dictionary):
			continue
		var source := value as Dictionary
		candidates.append(_capture_path(
			str(source.get("archive_path", "")),
			str(source.get("install_source", "")),
			str(source.get("location_id", ""))
		))
	return _rebuild(candidates) if FeatureGateScript.is_enabled() else _disable_catalog()


func set_persistent_cache_path_for_tests(path: String) -> void:
	_persistent_cache_path = path
	_persistent_cache_enabled = true
	_persistent_cache_loaded = false
	_persistent_cache_dirty = false
	_persistent_cache_keys.clear()
	_bundled_cache_keys.clear()
	_location_cache.clear()
	_location_cache_origins.clear()
	_metadata_cache.clear()


func set_removal_store_path_for_tests(path: String) -> void:
	if _removal_store == null:
		_removal_store = RemovalStoreScript.new()
	_removal_store.call("set_path_for_tests", path)
	_refresh_removed_package_keys()


func list_metadata_records() -> Array[Dictionary]:
	return _metadata_records.duplicate(true)


func list_ready_records() -> Array[Dictionary]:
	return _ready_records.duplicate(true)


func list_diagnostics() -> Array[Dictionary]:
	return _diagnostics.duplicate(true)


func resolve_install_identity(
	package_id: String,
	package_version: String,
	archive_sha256: String
) -> Dictionary:
	var normalized_id := package_id.strip_edges()
	var normalized_version := package_version.strip_edges()
	var normalized_sha := archive_sha256.strip_edges().to_upper()
	if normalized_id.is_empty() or normalized_version.is_empty() \
			or normalized_sha.length() != 64:
		return {
			"ok": false,
			"error_code": "package_download_identity_invalid",
			"conflict": false,
			"user_installed": false,
			"built_in_installed": false,
		}
	var user_installed := false
	var built_in_installed := false
	for record: Dictionary in _metadata_records:
		if record.get("package_id") != normalized_id \
				or record.get("package_version") != normalized_version:
			continue
		if str(record.get("archive_sha256", "")).to_upper() != normalized_sha:
			return {
				"ok": true,
				"error_code": "",
				"conflict": true,
				"user_installed": false,
				"built_in_installed": false,
				"catalog_generation": _scan_generation,
			}
		var sources: Variant = record.get("install_sources", [])
		if sources is Array:
			user_installed = "user" in sources
			built_in_installed = "built_in" in sources
	var identity_diagnostic_id := _sha(
		("%s\n%s" % [normalized_id, normalized_version]).to_utf8_buffer()
	).substr(0, 16)
	for diagnostic: Dictionary in _diagnostics:
		if diagnostic.get("error_code") == "package_identity_conflict" \
				and diagnostic.get("candidate_id") == identity_diagnostic_id:
			return {
				"ok": true,
				"error_code": "",
				"conflict": true,
				"user_installed": false,
				"built_in_installed": false,
				"catalog_generation": _scan_generation,
			}
	return {
		"ok": true,
		"error_code": "",
		"conflict": false,
		"user_installed": user_installed,
		"built_in_installed": built_in_installed,
		"catalog_generation": _scan_generation,
	}


func install_from_local_path(source_path: String) -> Dictionary:
	if _loader == null:
		_loader = LoaderScript.new()
	if _installer == null:
		_installer = InstallerScript.new()
	return _installer.call("install", self, _loader, source_path)


func install_from_bytes(
	archive_bytes: PackedByteArray,
	expected_release: Dictionary
) -> Dictionary:
	if _loader == null:
		_loader = LoaderScript.new()
	if _installer == null:
		_installer = InstallerScript.new()
	return _installer.call(
		"install_bytes", self, _loader, archive_bytes, expected_release.duplicate(true)
	)


func remove_package(
	package_id: String,
	package_version: String,
	archive_sha256: String
) -> Dictionary:
	if _loader == null:
		_loader = LoaderScript.new()
	if _installer == null:
		_installer = InstallerScript.new()
	return _installer.call(
		"remove", self, _loader, package_id, package_version, archive_sha256
	)


func remove_user_package(
	package_id: String,
	package_version: String,
	archive_sha256: String
) -> Dictionary:
	# Compatibility alias for D122 callers. Product removal now also covers
	# immutable built-in packages through the fixed user-data removal store.
	return remove_package(package_id, package_version, archive_sha256)


func set_built_in_package_removed(reference: Dictionary, removed: bool) -> Dictionary:
	if _removal_store == null:
		_removal_store = RemovalStoreScript.new()
	var result: Dictionary = _removal_store.call("set_removed", reference, removed)
	_refresh_removed_package_keys()
	return result


func request_match_handle(package_id: String, package_version: String, archive_sha256: String) -> Dictionary:
	return _request_match_handle(package_id, package_version, archive_sha256, false)


func request_ready_match_handle(package_id: String, package_version: String, archive_sha256: String) -> Dictionary:
	return _request_match_handle(package_id, package_version, archive_sha256, true)


func _request_match_handle(
	package_id: String,
	package_version: String,
	archive_sha256: String,
	require_player_ready: bool
) -> Dictionary:
	if not FeatureGateScript.is_enabled():
		return {"ok": false, "error_code": "author_strategy_feature_disabled", "handle": null}
	var catalog_key := ""
	var source_records: Array[Dictionary] = _ready_records if require_player_ready else _metadata_records
	for record in source_records:
		if record.get("package_id") == package_id and record.get("package_version") == package_version and record.get("archive_sha256") == archive_sha256:
			catalog_key = str(record.get("catalog_key", ""))
			break
	if catalog_key.is_empty() or not _match_locations.has(catalog_key):
		return {
			"ok": false,
			"error_code": "package_release_not_approved" if require_player_ready else "package_integrity_invalid",
			"handle": null,
		}
	var path := str(_match_locations[catalog_key])
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error_code": "package_file_missing", "handle": null}
	var captured := file.get_buffer(file.get_length())
	file = null
	if _sha(captured) != archive_sha256:
		return {"ok": false, "error_code": "package_integrity_invalid", "handle": null}
	var inspected: Dictionary = _loader.inspect_match_bytes(captured, archive_sha256)
	if not bool(inspected.get("ok", false)):
		return {"ok": false, "error_code": str(inspected.get("error_code", "package_integrity_invalid")), "handle": null}
	if require_player_ready:
		var release: Dictionary = _release_gate.evaluate_installed_package(inspected.get("metadata", {}))
		if not bool(release.get("accepted", false)) or not bool(release.get("player_start_allowed", false)):
			return {
				"ok": false,
				"error_code": str(release.get("error_code", "package_release_not_approved")),
				"handle": null,
			}
	var gated: Dictionary = DeckGateScript.build(inspected.get("payloads", {}))
	if not bool(gated.get("ok", false)):
		return {"ok": false, "error_code": str(gated.get("error_code", "package_deck_unmapped")), "handle": null}
	return HandleScript.create(inspected.get("metadata", {}), inspected.get("payloads", {}), gated.get("local_deck", []))


func audit_snapshot() -> Dictionary:
	return {
		"scan_generation": _scan_generation,
		"metadata_record_count": _metadata_records.size(),
		"ready_record_count": _ready_records.size(),
		"diagnostic_count": _diagnostics.size(),
		"cache_hits": _last_cache_hits,
		"cache_misses": _last_cache_misses,
		"persistent_cache_hits": _last_persistent_cache_hits,
		"persistent_cache_path": _persistent_cache_path,
		"startup_location_cache_hits": _last_startup_location_cache_hits,
		"startup_location_cache_misses": _last_startup_location_cache_misses,
		"bundled_location_cache_hits": _last_bundled_location_cache_hits,
		"startup_cache_authority": false,
		"match_time_archive_revalidation": true,
		"startup_profile": STARTUP_PROFILE_CACHED if startup_location_cache_enabled() else STARTUP_PROFILE_DEEP_SCAN,
		"startup_profile_environment": STARTUP_PROFILE_ENV,
		"removal_store_path": _removal_store.call("path") if _removal_store != null else "",
		"removed_package_count": _removed_package_keys.size(),
		"removal_store_error": _removal_store_error,
		"last_scan_elapsed_usec": _last_scan_elapsed_usec,
		"built_in_root": BUILT_IN_ROOT,
		"user_root": USER_ROOT,
		"metadata_only": true,
		"match_authority": false,
		"execution_authority": false,
		"live_consumer": false,
	}


func _disable_catalog() -> Dictionary:
	_scan_generation += 1
	_last_cache_hits = 0
	_last_cache_misses = 0
	_metadata_records = []
	_ready_records = []
	_match_locations = {}
	_diagnostics = [_diagnostic("feature_gate", "disabled", "author_strategy_feature_disabled")]
	return _report()


func _capture_root(root: String, install_source: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(root):
		return result
	var files := DirAccess.get_files_at(root)
	files.sort()
	for filename in files:
		if not str(filename).ends_with(".ptcgai"):
			continue
		var path := root.path_join(str(filename))
		result.append(_capture_path(path, install_source, str(filename)))
	return result


func _capture_path(path: String, install_source: String, location_id: String) -> Dictionary:
	var base := {
		"install_source": install_source,
		"location_id": location_id,
		"archive_path": path,
	}
	if path.is_empty() or install_source not in INSTALL_SOURCES or location_id.is_empty():
		base["archive_error"] = "package_archive_invalid"
		return base
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		base["archive_error"] = "package_archive_invalid"
		return base
	var archive_size := file.get_length()
	var modified_time := int(FileAccess.get_modified_time(path))
	base["archive_size"] = archive_size
	base["archive_modified_time"] = modified_time
	var location_key := _location_key(install_source, location_id)
	var cached: Variant = _location_cache.get(location_key)
	var cache_origin := str(_location_cache_origins.get(location_key, ""))
	if startup_location_cache_enabled() and cached is Dictionary and _location_cache_matches(
		cached, path, install_source, location_id, archive_size, modified_time, cache_origin
	):
		var archive_sha := str((cached as Dictionary).get("archive_sha256", ""))
		if _metadata_cache.has(archive_sha):
			base["archive_sha256"] = archive_sha
			base["startup_location_cache_hit"] = true
			_last_startup_location_cache_hits += 1
			if cache_origin == "bundled":
				_last_bundled_location_cache_hits += 1
			file.close()
			return base
	_last_startup_location_cache_misses += 1
	base["archive_bytes"] = file.get_buffer(archive_size)
	file.close()
	return base


func _begin_location_scan() -> void:
	_track_scan_locations = true
	_next_location_cache = {}
	_last_startup_location_cache_hits = 0
	_last_startup_location_cache_misses = 0
	_last_bundled_location_cache_hits = 0


func startup_location_cache_enabled(profile_override: String = "") -> bool:
	var profile := profile_override.strip_edges()
	if profile.is_empty():
		profile = OS.get_environment(STARTUP_PROFILE_ENV).strip_edges()
	return profile != STARTUP_PROFILE_DEEP_SCAN


func _rebuild(raw_candidates: Array[Dictionary]) -> Dictionary:
	if _loader == null:
		_loader = LoaderScript.new()
	if _release_gate == null:
		_release_gate = ReleaseGateScript.new()
	if _persistent_cache_enabled:
		_load_persistent_metadata_cache()
	_scan_generation += 1
	_last_cache_hits = 0
	_last_cache_misses = 0
	_last_persistent_cache_hits = 0
	var candidates: Array[Dictionary] = []
	var diagnostics: Array[Dictionary] = []
	_match_locations = {}
	for index in range(raw_candidates.size()):
		var source: Dictionary = raw_candidates[index]
		var install_source := str(source.get("install_source", ""))
		var candidate_id := "candidate-%04d" % index
		var has_archive_bytes := source.get("archive_bytes") is PackedByteArray
		var cached_archive_sha := str(source.get("archive_sha256", ""))
		var has_cached_archive := (
			not has_archive_bytes
			and cached_archive_sha.length() == 64
			and _metadata_cache.has(cached_archive_sha)
		)
		if install_source not in INSTALL_SOURCES or source.has("archive_error") or (not has_archive_bytes and not has_cached_archive):
			diagnostics.append(_diagnostic(candidate_id, install_source if install_source in INSTALL_SOURCES else "invalid", "package_archive_invalid"))
			continue
		var location_id := str(source.get("location_id", candidate_id))
		if location_id.is_empty():
			location_id = candidate_id
		var archive_bytes: PackedByteArray = source.get("archive_bytes", PackedByteArray())
		var captured_candidate := {
			"candidate_id": candidate_id,
			"install_source": install_source,
			"location_id": location_id,
			"archive_sha256": _sha(archive_bytes) if has_archive_bytes else cached_archive_sha,
		}
		if has_archive_bytes:
			captured_candidate["archive_bytes"] = archive_bytes
		if source.get("archive_path") is String:
			captured_candidate["archive_path"] = str(source.get("archive_path"))
		for descriptor_key: String in ["archive_size", "archive_modified_time"]:
			if source.has(descriptor_key):
				captured_candidate[descriptor_key] = int(source.get(descriptor_key, 0))
		candidates.append(captured_candidate)
	candidates.sort_custom(_candidate_less)

	var accepted: Array[Dictionary] = []
	for candidate in candidates:
		var archive_sha := str(candidate.get("archive_sha256", ""))
		var metadata: Dictionary
		if _metadata_cache.has(archive_sha):
			_last_cache_hits += 1
			if _persistent_cache_keys.has(archive_sha):
				_last_persistent_cache_hits += 1
			metadata = _metadata_cache[archive_sha].duplicate(true)
		else:
			_last_cache_misses += 1
			var inspected: Dictionary = _loader.inspect_bytes(candidate.get("archive_bytes"), archive_sha)
			if not bool(inspected.get("ok", false)):
				diagnostics.append(_diagnostic(str(candidate.get("candidate_id", "")), str(candidate.get("install_source", "")), str(inspected.get("error_code", "package_archive_invalid"))))
				continue
			metadata = inspected.get("metadata", {}).duplicate(true)
			_metadata_cache[archive_sha] = metadata.duplicate(true)
			_persistent_cache_dirty = true
		var accepted_candidate := candidate.duplicate()
		accepted_candidate.erase("archive_bytes")
		accepted_candidate["metadata"] = metadata
		accepted.append(accepted_candidate)
		_remember_location_candidate(accepted_candidate)

	var groups := {}
	for candidate in accepted:
		var metadata: Dictionary = candidate.get("metadata", {})
		var identity := str(metadata.get("package_id", "")) + "\n" + str(metadata.get("package_version", ""))
		if not groups.has(identity):
			groups[identity] = []
		groups[identity].append(candidate)
	var identities: Array[String] = []
	for identity in groups:
		identities.append(identity)
	identities.sort()
	var records: Array[Dictionary] = []
	for identity in identities:
		var group: Array = groups[identity]
		var hashes := {}
		for candidate in group:
			hashes[candidate.get("archive_sha256")] = true
		if hashes.size() != 1:
			diagnostics.append(_diagnostic(_sha(identity.to_utf8_buffer()).substr(0, 16), "conflict", "package_identity_conflict"))
			continue
		var selected: Dictionary = group[0]
		var metadata: Dictionary = selected.get("metadata", {}).duplicate(true)
		metadata["catalog_key"] = _sha((str(metadata.get("package_id")) + "\n" + str(metadata.get("package_version")) + "\n" + str(metadata.get("archive_sha256"))).to_utf8_buffer())
		if _removed_package_keys.has(_package_ref_key(metadata)):
			continue
		metadata["install_source"] = selected.get("install_source")
		var sources: Array[String] = []
		for candidate in group:
			var source := str(candidate.get("install_source", ""))
			if source not in sources:
				sources.append(source)
		sources.sort_custom(func(a: String, b: String) -> bool: return INSTALL_SOURCES.find(a) < INSTALL_SOURCES.find(b))
		metadata["install_sources"] = sources
		var release: Dictionary = _release_gate.evaluate_installed_package(metadata)
		var player_ready := bool(release.get("accepted", false)) \
			and bool(release.get("player_start_allowed", false))
		metadata["status"] = "ready" if player_ready else "metadata_only"
		if player_ready:
			metadata["player_start_allowed"] = true
		metadata["match_authority"] = false
		if selected.get("archive_path") is String:
			_match_locations[metadata["catalog_key"]] = str(selected.get("archive_path"))
		records.append(metadata)
	if not _removal_store_error.is_empty():
		diagnostics.append(_diagnostic("removal_store", "user", _removal_store_error))
	diagnostics.sort_custom(_diagnostic_less)
	_metadata_records = records.duplicate(true)
	_ready_records = []
	for record: Dictionary in _metadata_records:
		if record.get("status") == "ready" and record.get("player_start_allowed") == true:
			_ready_records.append(record.duplicate(true))
	_diagnostics = diagnostics.duplicate(true)
	for diagnostic in _diagnostics:
		package_rejected.emit(diagnostic.duplicate(true))
	_finish_location_scan()
	if _persistent_cache_enabled and _persistent_cache_dirty:
		_persist_metadata_cache()
	return _report()


func _load_persistent_metadata_cache() -> void:
	if _persistent_cache_loaded:
		return
	_persistent_cache_loaded = true
	_persistent_cache_keys.clear()
	_bundled_cache_keys.clear()
	_location_cache.clear()
	_location_cache_origins.clear()
	_merge_cache_document(BUILT_IN_CACHE_PATH, "bundled")
	_merge_cache_document(_persistent_cache_path, "persistent")


func _merge_cache_document(path: String, origin: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var cache_file := FileAccess.open(path, FileAccess.READ)
	if cache_file == null or cache_file.get_length() > MAX_CACHE_FILE_BYTES:
		return
	var parsed: Variant = JSON.parse_string(cache_file.get_as_text())
	cache_file.close()
	if not (parsed is Dictionary):
		return
	var root := parsed as Dictionary
	if int(root.get("schema_version", 0)) != PERSISTENT_CACHE_SCHEMA_VERSION:
		return
	if str(root.get("cache_identity", "")) != _persistent_cache_identity():
		return
	var entries: Variant = root.get("entries", {})
	var locations: Variant = root.get("locations", {})
	if not (entries is Dictionary) or not (locations is Dictionary):
		return
	if (entries as Dictionary).size() > MAX_CACHE_ENTRY_COUNT \
			or (locations as Dictionary).size() > MAX_CACHE_LOCATION_COUNT:
		return
	for archive_sha_value: Variant in (entries as Dictionary).keys():
		var archive_sha := str(archive_sha_value)
		var metadata: Variant = _coerce_integral_numbers((entries as Dictionary).get(archive_sha_value))
		if not _valid_persistent_metadata(archive_sha, metadata):
			continue
		if origin == "persistent" and _bundled_cache_keys.has(archive_sha):
			# User-writable metadata may accelerate user archives, but it cannot
			# replace the generated projection for identical built-in bytes.
			continue
		_metadata_cache[archive_sha] = (metadata as Dictionary).duplicate(true)
		if origin == "bundled":
			_bundled_cache_keys[archive_sha] = true
		else:
			_persistent_cache_keys[archive_sha] = true
	for location_key_value: Variant in (locations as Dictionary).keys():
		var location_key := str(location_key_value)
		var location: Variant = _coerce_integral_numbers((locations as Dictionary).get(location_key_value))
		if not _valid_location_cache_record(location_key, location):
			continue
		var archive_sha := str((location as Dictionary).get("archive_sha256", ""))
		if not _metadata_cache.has(archive_sha):
			continue
		if origin == "persistent" \
				and str((location as Dictionary).get("install_source", "")) == "built_in" \
				and str(_location_cache_origins.get(location_key, "")) == "bundled":
			# The generated resource index is checkout/PCK portable. A per-user
			# cache must not replace it with one machine's source-file timestamp.
			continue
		_location_cache[location_key] = (location as Dictionary).duplicate(true)
		_location_cache_origins[location_key] = origin


func _persist_metadata_cache() -> void:
	var absolute_dir := ProjectSettings.globalize_path(_persistent_cache_path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK and not DirAccess.dir_exists_absolute(absolute_dir):
		return
	var entries := {}
	for archive_sha_value: Variant in _metadata_cache.keys():
		var archive_sha := str(archive_sha_value)
		var metadata: Variant = _metadata_cache.get(archive_sha_value)
		if _valid_persistent_metadata(archive_sha, metadata):
			entries[archive_sha] = (metadata as Dictionary).duplicate(true)
	var file := FileAccess.open(_persistent_cache_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"document_type": "author_strategy_catalog_metadata_cache_v2",
		"schema_version": PERSISTENT_CACHE_SCHEMA_VERSION,
		"cache_identity": _persistent_cache_identity(),
		"entries": entries,
		"locations": _location_cache.duplicate(true),
	}) + "\n")
	file.close()
	_persistent_cache_dirty = false
	_persistent_cache_keys = {}
	for archive_sha: Variant in entries.keys():
		_persistent_cache_keys[str(archive_sha)] = true


func _remember_location_candidate(candidate: Dictionary) -> void:
	if not _track_scan_locations or not candidate.has("archive_path"):
		return
	var install_source := str(candidate.get("install_source", ""))
	var location_id := str(candidate.get("location_id", ""))
	var archive_sha := str(candidate.get("archive_sha256", ""))
	if install_source not in INSTALL_SOURCES or location_id.is_empty() or archive_sha.length() != 64:
		return
	_next_location_cache[_location_key(install_source, location_id)] = {
		"install_source": install_source,
		"location_id": location_id,
		"archive_path": str(candidate.get("archive_path", "")),
		"archive_size": int(candidate.get("archive_size", 0)),
		"archive_modified_time": int(candidate.get("archive_modified_time", 0)),
		"archive_sha256": archive_sha,
	}


func _finish_location_scan() -> void:
	if not _track_scan_locations:
		return
	_track_scan_locations = false
	if _location_cache != _next_location_cache:
		_persistent_cache_dirty = true
	_location_cache = _next_location_cache.duplicate(true)
	_location_cache_origins.clear()
	_next_location_cache.clear()


func _location_key(install_source: String, location_id: String) -> String:
	return "%s\n%s" % [install_source, location_id]


func _location_cache_matches(
	value: Variant,
	path: String,
	install_source: String,
	location_id: String,
	archive_size: int,
	modified_time: int,
	cache_origin: String
) -> bool:
	if not (value is Dictionary):
		return false
	var cached := value as Dictionary
	return (
		str(cached.get("archive_path", "")) == path
		and str(cached.get("install_source", "")) == install_source
		and str(cached.get("location_id", "")) == location_id
		and int(cached.get("archive_size", -1)) == archive_size
		and (
			int(cached.get("archive_modified_time", -1)) == modified_time
			or (cache_origin == "bundled" and install_source == "built_in")
		)
		and str(cached.get("archive_sha256", "")).length() == 64
	)


func _valid_location_cache_record(location_key: String, value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var record := value as Dictionary
	var install_source := str(record.get("install_source", ""))
	var location_id := str(record.get("location_id", ""))
	return (
		install_source in INSTALL_SOURCES
		and not location_id.is_empty()
		and location_key == _location_key(install_source, location_id)
		and not str(record.get("archive_path", "")).is_empty()
		and int(record.get("archive_size", -1)) >= 0
		and int(record.get("archive_modified_time", -1)) >= 0
		and str(record.get("archive_sha256", "")).length() == 64
	)


func _persistent_cache_identity() -> String:
	if _loader == null:
		_loader = LoaderScript.new()
	if _release_gate == null:
		_release_gate = ReleaseGateScript.new()
	var identity := {
		"schema_version": PERSISTENT_CACHE_SCHEMA_VERSION,
		"loader": _loader.contract_report(),
		"release_gate": _release_gate.audit_snapshot(),
	}
	return _sha(JSON.stringify(identity).to_utf8_buffer())


func _valid_persistent_metadata(archive_sha: String, value: Variant) -> bool:
	if archive_sha.length() != 64 or not (value is Dictionary):
		return false
	var metadata := value as Dictionary
	return (
		str(metadata.get("archive_sha256", "")) == archive_sha
		and not str(metadata.get("package_id", "")).is_empty()
		and not str(metadata.get("package_version", "")).is_empty()
		and metadata.get("author") is Dictionary
		and metadata.get("strategy") is Dictionary
		and metadata.get("deck") is Dictionary
	)


func _coerce_integral_numbers(value: Variant) -> Variant:
	if value is float and value == floor(value):
		return int(value)
	if value is Array:
		var array_result: Array = []
		for item: Variant in value:
			array_result.append(_coerce_integral_numbers(item))
		return array_result
	if value is Dictionary:
		var dictionary_result: Dictionary = {}
		for key: Variant in value:
			dictionary_result[key] = _coerce_integral_numbers(value[key])
		return dictionary_result
	return value


func _report() -> Dictionary:
	return {
		"schema_version": 1,
		"scan_generation": _scan_generation,
		"metadata_records": _metadata_records.duplicate(true),
		"ready_records": _ready_records.duplicate(true),
		"diagnostics": _diagnostics.duplicate(true),
		"metadata_only": true,
		"match_authority": false,
	}


func _ensure_user_root() -> void:
	var user := DirAccess.open("user://")
	if user != null:
		user.make_dir_recursive("ptcgdap/author_strategy_packages")


func _refresh_removed_package_keys() -> void:
	if _removal_store == null:
		_removal_store = RemovalStoreScript.new()
	_removed_package_keys.clear()
	_removal_store_error = ""
	var loaded: Dictionary = _removal_store.call("snapshot")
	if not bool(loaded.get("ok", false)):
		_removal_store_error = str(loaded.get("error_code", "package_removal_store_invalid"))
		return
	for value: Variant in loaded.get("removed_packages", []):
		if value is Dictionary:
			_removed_package_keys[_package_ref_key(value)] = true


func _package_ref_key(reference: Dictionary) -> String:
	return "%s\n%s\n%s" % [
		reference.get("package_id", ""),
		reference.get("package_version", ""),
		str(reference.get("archive_sha256", "")).to_upper(),
	]


func _candidate_less(a: Dictionary, b: Dictionary) -> bool:
	var source_a := INSTALL_SOURCES.find(str(a.get("install_source", "")))
	var source_b := INSTALL_SOURCES.find(str(b.get("install_source", "")))
	if source_a != source_b:
		return source_a < source_b
	return str(a.get("location_id", "")) < str(b.get("location_id", ""))


func _diagnostic_less(a: Dictionary, b: Dictionary) -> bool:
	var key_a := str(a.get("error_code", "")) + "\n" + str(a.get("install_source", "")) + "\n" + str(a.get("candidate_id", ""))
	var key_b := str(b.get("error_code", "")) + "\n" + str(b.get("install_source", "")) + "\n" + str(b.get("candidate_id", ""))
	return key_a < key_b


func _diagnostic(candidate_id: String, install_source: String, code: String) -> Dictionary:
	return {"candidate_id": candidate_id, "install_source": install_source, "error_code": code}


func _sha(value: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value)
	return context.finish().hex_encode().to_upper()
