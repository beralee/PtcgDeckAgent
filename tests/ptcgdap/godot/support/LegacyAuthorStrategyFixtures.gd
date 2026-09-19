extends RefCounted

# Archived public packages are explicit fixtures, never player catalog entries.
const ROOT := "res://tests/ptcgdap/fixtures/legacy_author_strategy_packages/"
static func sources(archive_hash: String = "") -> Array:
	var sources: Array = []
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "provenance.json"))
	for record: Dictionary in manifest.get("archives", []):
		var filename: String = record.get("path", "")
		if not archive_hash.is_empty() and record.get("sha256") != archive_hash:
			continue
		sources.append({
			"archive_path": ROOT + filename,
			"install_source": "built_in",
			"location_id": filename,
		})
	return sources


static func populate(catalog: Node, archive_hash: String = "") -> Dictionary:
	return catalog.rebuild_from_paths_for_test(sources(archive_hash))
