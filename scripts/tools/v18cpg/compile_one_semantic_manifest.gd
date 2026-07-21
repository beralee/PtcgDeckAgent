extends SceneTree

## Regenerates one V18CPG semantic manifest without rewriting the other 23
## deck artifacts.  Iteration rounds use this after a deck's composed module
## list changes, so the manifest hash remains authoritative while unrelated
## in-flight deck evidence stays frozen.

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const SemanticCompilerScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGDeckSemanticCompiler.gd")
const OUTPUT_ROOT := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests"


func _initialize() -> void:
	var deck_id := _deck_id_from_args(OS.get_cmdline_user_args())
	if deck_id not in ProfileCatalogScript.ALL_DECK_IDS:
		push_error("compile_one_semantic_manifest requires a built-in --deck-id=<id>")
		quit(2)
		return
	var card_database := root.get_node_or_null("CardDatabase")
	if card_database == null:
		push_error("CardDatabase autoload is unavailable")
		quit(1)
		return
	var profile := ProfileCatalogScript.get_profile_for_deck(deck_id)
	var deck: DeckData = card_database.call("get_ai_deck", deck_id) as DeckData
	if profile.is_empty() or deck == null:
		push_error("profile_or_deck_missing:%d" % deck_id)
		quit(1)
		return
	var manifest := SemanticCompilerScript.new().compile(deck, profile)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT))
	var path := "%s/%d.json" % [OUTPUT_ROOT, deck_id]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("cannot_write_manifest:%s" % path)
		quit(1)
		return
	file.store_string(JSON.stringify(manifest, "  "))
	file.close()
	print("V18CPG semantic manifest: PASS deck=%d hash=%s" % [
		deck_id,
		str(manifest.get("manifest_hash", "")),
	])
	quit(0)


func _deck_id_from_args(args: PackedStringArray) -> int:
	for arg: String in args:
		if arg.begins_with("--deck-id="):
			return int(arg.trim_prefix("--deck-id="))
	return 0
