class_name AuthorStrategyPackageInstaller
extends RefCounted

const DeckGateScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyDeckGate.gd")
const FeatureGateScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyFeatureGate.gd")
const BUILT_IN_ROOT := "res://data/ptcgdap/author_strategy_packages"
const USER_ROOT := "user://ptcgdap/author_strategy_packages"
const TEMP_PREFIX := ".ptcgdap-author-install-"
const REMOVE_TEMP_PREFIX := ".ptcgdap-author-remove-"


func install(catalog: Variant, loader: Variant, source_path: String) -> Dictionary:
	if not FeatureGateScript.is_enabled():
		return _error("author_strategy_feature_disabled")
	if catalog == null or not catalog.has_method("scan_startup") or loader == null:
		return _error("package_catalog_unavailable")
	var normalized_source := source_path.strip_edges()
	if normalized_source.is_empty() or normalized_source.get_extension().to_lower() != "ptcgai":
		return _error("package_archive_invalid")
	if not FileAccess.file_exists(normalized_source) or _is_link(normalized_source):
		return _error("package_file_missing")
	var source_file := FileAccess.open(normalized_source, FileAccess.READ)
	if source_file == null:
		return _error("package_file_missing")
	var archive_bytes := source_file.get_buffer(source_file.get_length())
	source_file = null
	return _install_captured_bytes(catalog, loader, archive_bytes, {})


func install_bytes(
	catalog: Variant,
	loader: Variant,
	archive_bytes: PackedByteArray,
	expected_release: Dictionary
) -> Dictionary:
	if not FeatureGateScript.is_enabled():
		return _error("author_strategy_feature_disabled")
	if catalog == null or not catalog.has_method("scan_startup") or loader == null:
		return _error("package_catalog_unavailable")
	if archive_bytes.is_empty() or archive_bytes.size() > 16 * 1024 * 1024:
		return _error("package_resource_limit_exceeded")
	if not _valid_expected_release(expected_release):
		return _error("package_download_identity_invalid")
	return _install_captured_bytes(catalog, loader, archive_bytes, expected_release)


func _install_captured_bytes(
	catalog: Variant,
	loader: Variant,
	archive_bytes: PackedByteArray,
	expected_release: Dictionary
) -> Dictionary:
	var archive_sha := _sha(archive_bytes)
	if not expected_release.is_empty() and archive_sha != str(
		expected_release.get("archive_sha256", "")
	).to_upper():
		return _error("package_download_identity_mismatch")
	var inspected: Dictionary = loader.inspect_match_bytes(archive_bytes, archive_sha)
	if not bool(inspected.get("ok", false)):
		return _error(str(inspected.get("error_code", "package_archive_invalid")))
	var deck_gate: Dictionary = DeckGateScript.build(inspected.get("payloads", {}))
	if not bool(deck_gate.get("ok", false)):
		return _error(str(deck_gate.get("error_code", "package_deck_unmapped")))
	var metadata: Dictionary = inspected.get("metadata", {}).duplicate(true)
	if not expected_release.is_empty() and (
		metadata.get("package_id") != expected_release.get("package_id")
		or metadata.get("package_version") != expected_release.get("package_version")
		or str(metadata.get("archive_sha256", "")).to_upper()
			!= str(expected_release.get("archive_sha256", "")).to_upper()
		or str(metadata.get("manifest_canonical_sha256", "")).to_upper()
			!= str(expected_release.get("manifest_canonical_sha256", "")).to_upper()
	):
		return _error("package_download_identity_mismatch")
	var package_id := str(metadata.get("package_id", ""))
	var package_version := str(metadata.get("package_version", ""))
	if package_id.is_empty() or package_version.is_empty():
		return _error("package_manifest_invalid")

	var identity_started_usec := Time.get_ticks_usec()
	var identity: Dictionary = _find_installed_identity(
		catalog, package_id, package_version, archive_sha
	)
	var identity_resolution_usec := maxi(
		0, Time.get_ticks_usec() - identity_started_usec
	)
	if not bool(identity.get("ok", false)):
		return _error(str(identity.get("error_code", "package_catalog_unavailable")))
	if bool(identity.get("conflict", false)):
		return _error("package_install_identity_conflict")
	# Hash-only user-root lookup preserves custom filenames and a generation-zero
	# caller without re-running archive parsing/signature verification.
	var existing_user_path := _find_user_archive_by_hash(archive_sha)
	if bool(identity.get("user_installed", false)) and existing_user_path.is_empty():
		return _error("package_install_catalog_refresh_failed")
	if not existing_user_path.is_empty():
		return _finish_install(
			catalog, metadata, existing_user_path, true, identity_resolution_usec
		)

	var user_root_absolute := ProjectSettings.globalize_path(USER_ROOT)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(user_root_absolute)
	if mkdir_error != OK and not DirAccess.dir_exists_absolute(user_root_absolute):
		return _error("package_install_user_data_unavailable")
	var destination := USER_ROOT.path_join("package-%s.ptcgai" % archive_sha.to_lower())
	if FileAccess.file_exists(destination):
		var destination_bytes := FileAccess.get_file_as_bytes(destination)
		if _sha(destination_bytes) == archive_sha:
			return _finish_install(
				catalog, metadata, destination, true, identity_resolution_usec
			)
		return _error("package_install_destination_conflict")

	var temporary := USER_ROOT.path_join(
		"%s%d-%s.tmp" % [TEMP_PREFIX, Time.get_ticks_usec(), archive_sha.left(12).to_lower()]
	)
	if FileAccess.file_exists(temporary):
		return _error("package_install_destination_conflict")
	var temporary_file := FileAccess.open(temporary, FileAccess.WRITE)
	if temporary_file == null:
		return _error("package_install_failed")
	temporary_file.store_buffer(archive_bytes)
	temporary_file.close()
	if not FileAccess.file_exists(temporary) or _sha(FileAccess.get_file_as_bytes(temporary)) != archive_sha:
		_remove_owned_file(temporary)
		return _error("package_install_failed")
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(destination)
	)
	if rename_error != OK:
		_remove_owned_file(temporary)
		return _error("package_install_failed")

	var installed_bytes := FileAccess.get_file_as_bytes(destination)
	var installed: Dictionary = loader.inspect_match_bytes(installed_bytes, archive_sha)
	var installed_deck: Dictionary = DeckGateScript.build(installed.get("payloads", {})) if bool(installed.get("ok", false)) else {}
	if not bool(installed.get("ok", false)) or not bool(installed_deck.get("ok", false)):
		_remove_owned_file(destination)
		return _error(
			str(installed.get("error_code", "package_install_failed"))
			if not bool(installed.get("ok", false))
			else str(installed_deck.get("error_code", "package_deck_unmapped"))
		)
	var result := _finish_install(
		catalog, metadata, destination, false, identity_resolution_usec
	)
	if not bool(result.get("ok", false)):
		_remove_owned_file(destination)
		catalog.scan_startup()
	return result


func remove(
	catalog: Variant,
	loader: Variant,
	package_id: String,
	package_version: String,
	archive_sha256: String
) -> Dictionary:
	if not FeatureGateScript.is_enabled():
		return _remove_error("author_strategy_feature_disabled")
	if (
		catalog == null
		or not catalog.has_method("scan_startup")
		or not catalog.has_method("list_metadata_records")
		or loader == null
	):
		return _remove_error("package_catalog_unavailable")
	var normalized_id := package_id.strip_edges()
	var normalized_version := package_version.strip_edges()
	var normalized_sha := archive_sha256.strip_edges().to_upper()
	if not _valid_remove_reference(normalized_id, normalized_version, normalized_sha):
		return _remove_error("package_remove_reference_invalid")
	var installed_record := _find_catalog_record(
		catalog.list_metadata_records(), normalized_id, normalized_version, normalized_sha
	)
	if installed_record.is_empty():
		return _remove_error("package_remove_not_found")
	var install_sources: Variant = installed_record.get("install_sources", [])
	if not install_sources is Array:
		return _remove_error("package_remove_not_found")
	var has_built_in: bool = "built_in" in install_sources

	var discovered := _find_user_remove_targets(
		loader, normalized_id, normalized_version, normalized_sha
	)
	if not bool(discovered.get("ok", false)):
		return _remove_error(str(discovered.get("error_code", "package_remove_failed")))
	var targets: Array[String] = []
	for value: Variant in discovered.get("targets", []):
		targets.append(str(value))
	if targets.is_empty() and not has_built_in:
		catalog.scan_startup()
		return _remove_error("package_remove_not_found")

	var moves: Array[Dictionary] = []
	for index: int in targets.size():
		var original := targets[index]
		var temporary := USER_ROOT.path_join(
			"%s%d-%d.tmp" % [REMOVE_TEMP_PREFIX, Time.get_ticks_usec(), index]
		)
		if FileAccess.file_exists(temporary):
			_rollback_remove_moves(moves)
			return _remove_error("package_remove_failed")
		var rename_error := DirAccess.rename_absolute(
			ProjectSettings.globalize_path(original),
			ProjectSettings.globalize_path(temporary)
		)
		if rename_error != OK:
			_rollback_remove_moves(moves)
			return _remove_error("package_remove_failed")
		moves.append({"original": original, "temporary": temporary})
	var marker_changed := false
	var marker_cleanup_pending := false
	if has_built_in:
		if not catalog.has_method("set_built_in_package_removed"):
			_rollback_remove_moves(moves)
			return _remove_error("package_removal_store_unavailable")
		var marker: Dictionary = catalog.set_built_in_package_removed({
			"package_id": normalized_id,
			"package_version": normalized_version,
			"archive_sha256": normalized_sha,
		}, true)
		if not bool(marker.get("ok", false)):
			_rollback_remove_moves(moves)
			return _remove_error(str(marker.get("error_code", "package_removal_store_unavailable")))
		marker_changed = bool(marker.get("changed", false))
		marker_cleanup_pending = bool(marker.get("cleanup_pending", false))

	var report: Dictionary = catalog.scan_startup()
	var remaining := _find_catalog_record(
		report.get("metadata_records", []), normalized_id, normalized_version, normalized_sha
	)
	if not remaining.is_empty():
		var rollback_ok := _rollback_remove_moves(moves)
		if marker_changed:
			var marker_rollback: Dictionary = catalog.set_built_in_package_removed({
				"package_id": normalized_id,
				"package_version": normalized_version,
				"archive_sha256": normalized_sha,
			}, false)
			rollback_ok = rollback_ok and bool(marker_rollback.get("ok", false))
		catalog.scan_startup()
		return _remove_error(
			"package_remove_catalog_refresh_failed" if rollback_ok else "package_remove_rollback_failed"
		)

	var cleanup_pending := marker_cleanup_pending
	for move: Dictionary in moves:
		var temporary := str(move.get("temporary", ""))
		if (
			FileAccess.file_exists(temporary)
			and DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary)) != OK
		):
			cleanup_pending = true
	return {
		"ok": true,
		"error_code": "",
		"status": "removed",
		"package_id": normalized_id,
		"package_version": normalized_version,
		"archive_sha256": normalized_sha,
		"removed_count": moves.size(),
		"remaining_built_in": false,
		"built_in_hidden": has_built_in,
		"catalog_discoverable": false,
		"cleanup_pending": cleanup_pending,
		"catalog_report": report.duplicate(true),
		"match_authority": false,
		"production_authority": false,
	}


func _finish_install(
	catalog: Variant,
	metadata: Dictionary,
	installed_path: String,
	already_installed: bool,
	identity_resolution_usec: int
) -> Dictionary:
	var finish_started_usec := Time.get_ticks_usec()
	var removal_restored := false
	if catalog.has_method("set_built_in_package_removed"):
		var restored: Dictionary = catalog.set_built_in_package_removed({
			"package_id": metadata.get("package_id", ""),
			"package_version": metadata.get("package_version", ""),
			"archive_sha256": metadata.get("archive_sha256", ""),
		}, false)
		if not bool(restored.get("ok", false)):
			return _error(str(restored.get("error_code", "package_removal_store_unavailable")))
		removal_restored = bool(restored.get("changed", false))
	var refresh_started_usec := Time.get_ticks_usec()
	var report: Dictionary = catalog.scan_startup()
	var catalog_refresh_usec := maxi(0, Time.get_ticks_usec() - refresh_started_usec)
	var matched: Dictionary = {}
	for value: Variant in report.get("metadata_records", []):
		if not value is Dictionary:
			continue
		var record := value as Dictionary
		if (
			record.get("package_id") == metadata.get("package_id")
			and record.get("package_version") == metadata.get("package_version")
			and record.get("archive_sha256") == metadata.get("archive_sha256")
			and "user" in record.get("install_sources", [])
		):
			matched = record.duplicate(true)
			break
	if matched.is_empty():
		if removal_restored:
			catalog.set_built_in_package_removed({
				"package_id": metadata.get("package_id", ""),
				"package_version": metadata.get("package_version", ""),
				"archive_sha256": metadata.get("archive_sha256", ""),
			}, true)
			catalog.scan_startup()
		return _error("package_install_catalog_refresh_failed")
	return {
		"ok": true,
		"error_code": "",
		"status": "installed",
		"already_installed": already_installed,
		"installed_path": installed_path,
		"archive_sha256": metadata.get("archive_sha256"),
		"package_id": metadata.get("package_id"),
		"package_version": metadata.get("package_version"),
		"metadata": matched,
		"catalog_report": report.duplicate(true),
		"identity_resolution_usec": identity_resolution_usec,
		"catalog_refresh_usec": catalog_refresh_usec,
		"finish_elapsed_usec": maxi(0, Time.get_ticks_usec() - finish_started_usec),
		"catalog_discoverable": true,
		"player_start_allowed": matched.get("player_start_allowed") == true,
		"match_authority": false,
		"production_authority": false,
	}


func _find_user_remove_targets(
	loader: Variant,
	package_id: String,
	package_version: String,
	archive_sha: String
) -> Dictionary:
	var targets: Array[String] = []
	if not DirAccess.dir_exists_absolute(USER_ROOT):
		return {"ok": true, "targets": targets}
	var filenames := DirAccess.get_files_at(USER_ROOT)
	filenames.sort()
	for raw_filename: Variant in filenames:
		var filename := str(raw_filename)
		if filename != filename.get_file() or not filename.ends_with(".ptcgai"):
			continue
		var path := USER_ROOT.path_join(filename)
		if _is_link(path):
			continue
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.is_empty() or _sha(bytes) != archive_sha:
			continue
		var inspected: Dictionary = loader.inspect_bytes(bytes, archive_sha)
		if not bool(inspected.get("ok", false)):
			return {"ok": false, "error_code": "package_remove_verification_failed"}
		var metadata: Dictionary = inspected.get("metadata", {})
		if (
			metadata.get("package_id") == package_id
			and metadata.get("package_version") == package_version
			and str(metadata.get("archive_sha256", "")).to_upper() == archive_sha
		):
			targets.append(path)
	return {"ok": true, "targets": targets}


func _find_catalog_record(
	records: Variant,
	package_id: String,
	package_version: String,
	archive_sha: String
) -> Dictionary:
	if not records is Array:
		return {}
	for value: Variant in records:
		if not value is Dictionary:
			continue
		var record := value as Dictionary
		if (
			record.get("package_id") == package_id
			and record.get("package_version") == package_version
			and str(record.get("archive_sha256", "")).to_upper() == archive_sha
		):
			return record.duplicate(true)
	return {}


func _rollback_remove_moves(moves: Array[Dictionary]) -> bool:
	var ok := true
	for index: int in range(moves.size() - 1, -1, -1):
		var move := moves[index]
		var original := str(move.get("original", ""))
		var temporary := str(move.get("temporary", ""))
		if not FileAccess.file_exists(temporary):
			continue
		if FileAccess.file_exists(original):
			ok = false
			continue
		if DirAccess.rename_absolute(
			ProjectSettings.globalize_path(temporary),
			ProjectSettings.globalize_path(original)
		) != OK:
			ok = false
	return ok


func _valid_remove_reference(package_id: String, package_version: String, archive_sha: String) -> bool:
	if package_id.is_empty() or package_id.length() > 128 or _contains_control(package_id):
		return false
	if package_version.is_empty() or package_version.length() > 64 or _contains_control(package_version):
		return false
	if archive_sha.length() != 64:
		return false
	for index: int in archive_sha.length():
		var code := archive_sha.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 65 and code <= 70):
			return false
	return true


func _valid_expected_release(value: Dictionary) -> bool:
	if value.size() != 4:
		return false
	for key: String in [
		"package_id", "package_version", "archive_sha256", "manifest_canonical_sha256"
	]:
		if not value.has(key) or not value.get(key) is String:
			return false
	var package_id := str(value.get("package_id", ""))
	var package_version := str(value.get("package_version", ""))
	if (
		package_id.is_empty()
		or package_id.length() > 128
		or _contains_control(package_id)
		or package_version.is_empty()
		or package_version.length() > 64
		or _contains_control(package_version)
	):
		return false
	for sha_key: String in ["archive_sha256", "manifest_canonical_sha256"]:
		var sha := str(value.get(sha_key, "")).to_upper()
		if sha.length() != 64:
			return false
		for index: int in sha.length():
			var code := sha.unicode_at(index)
			if not (code >= 48 and code <= 57) and not (code >= 65 and code <= 70):
				return false
	return true


func _contains_control(value: String) -> bool:
	for index: int in value.length():
		var code := value.unicode_at(index)
		if code < 32 or code == 127:
			return true
	return false


func _find_installed_identity(
	catalog: Variant,
	package_id: String,
	package_version: String,
	archive_sha: String
) -> Dictionary:
	if catalog == null or not catalog.has_method("resolve_install_identity"):
		return {
			"ok": false,
			"error_code": "package_catalog_unavailable",
			"conflict": false,
			"user_installed": false,
			"built_in_installed": false,
		}
	var resolved: Variant = catalog.call(
		"resolve_install_identity", package_id, package_version, archive_sha
	)
	if not resolved is Dictionary:
		return {
			"ok": false,
			"error_code": "package_catalog_unavailable",
			"conflict": false,
			"user_installed": false,
			"built_in_installed": false,
		}
	return (resolved as Dictionary).duplicate(true)


func _find_user_archive_by_hash(archive_sha: String) -> String:
	if not DirAccess.dir_exists_absolute(USER_ROOT):
		return ""
	var filenames := DirAccess.get_files_at(USER_ROOT)
	filenames.sort()
	for filename: String in filenames:
		if filename != filename.get_file() or not filename.ends_with(".ptcgai"):
			continue
		var path := USER_ROOT.path_join(filename)
		if _is_link(path):
			continue
		var bytes := FileAccess.get_file_as_bytes(path)
		if not bytes.is_empty() and _sha(bytes) == archive_sha:
			return path
	return ""


func _is_link(path: String) -> bool:
	var parent := DirAccess.open(path.get_base_dir())
	return parent != null and parent.is_link(path.get_file())


func _remove_owned_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _sha(value: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value)
	return context.finish().hex_encode().to_upper()


func _error(code: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": code,
		"already_installed": false,
		"installed_path": "",
		"catalog_discoverable": false,
		"player_start_allowed": false,
		"match_authority": false,
		"production_authority": false,
	}


func _remove_error(code: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": code,
		"status": "remove_failed",
		"removed_count": 0,
		"remaining_built_in": false,
		"built_in_hidden": false,
		"catalog_discoverable": false,
		"cleanup_pending": false,
		"catalog_report": {},
		"match_authority": false,
		"production_authority": false,
	}
