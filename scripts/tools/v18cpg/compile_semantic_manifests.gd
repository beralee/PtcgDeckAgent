extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const SemanticCompilerScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGDeckSemanticCompiler.gd")
const OUTPUT_ROOT := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests"


func _initialize() -> void:
	var compiler := SemanticCompilerScript.new()
	var card_database := root.get_node_or_null("CardDatabase")
	var rows: Array[Dictionary] = []
	var failures: Array[String] = []
	if card_database == null:
		push_error("CardDatabase autoload is unavailable")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT))
	for deck_id: int in ProfileCatalogScript.ALL_DECK_IDS:
		var profile := ProfileCatalogScript.get_profile_for_deck(deck_id)
		# Built-in AI strategy manifests must never inherit a stale player-deck
		# mirror from user://decks.  CardDatabase guarantees get_ai_deck() uses
		# the bundled source for supported AI deck ids.
		var deck: DeckData = card_database.call("get_ai_deck", deck_id) as DeckData
		if profile.is_empty() or deck == null:
			failures.append("%d: profile_or_deck_missing" % deck_id)
			continue
		var manifest := compiler.compile(deck, profile)
		var path := "%s/%d.json" % [OUTPUT_ROOT, deck_id]
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			failures.append("%d: cannot_write_manifest" % deck_id)
			continue
		file.store_string(JSON.stringify(manifest, "  "))
		file.close()
		rows.append({
			"deck_id": deck_id,
			"strategy_id": str(profile.get("strategy_id", "")),
			"manifest_hash": str(manifest.get("manifest_hash", "")),
			"card_kinds": (manifest.get("cards", []) as Array).size() if manifest.get("cards", []) is Array else 0,
			"role_counts": manifest.get("role_counts", {}),
		})
	var ledger := {
		"schema_version": 1,
		"architecture": "V18CPG",
		"generated_count": rows.size(),
		"all_passed": failures.is_empty() and rows.size() == 24,
		"rows": rows,
		"failures": failures,
	}
	var ledger_file := FileAccess.open("%s/coverage_ledger.json" % OUTPUT_ROOT, FileAccess.WRITE)
	if ledger_file != null:
		ledger_file.store_string(JSON.stringify(ledger, "  "))
		ledger_file.close()
	if failures.is_empty() and rows.size() == 24:
		print("V18CPG semantic manifests: PASS (24/24)")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
