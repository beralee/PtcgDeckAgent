extends RefCounted

const Model = preload("res://scripts/ui/battle/author_strategy/AuthorStrategySetupModel.gd")
const Gate = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsExecutionGate.gd")
const Materializer = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyDeckMaterializer.gd")
const FeatureGate = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyFeatureGate.gd")


static func collect(catalog: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not FeatureGate.is_enabled(): return result
	var view := Model.normalize_catalog_report(catalog.scan_startup())
	for record: Dictionary in view.get("records", []):
		var selection := Model.setup_selection_record(record)
		var checked := resolve(catalog, selection)
		if not checked.get("ok", false): continue
		var deck: DeckData = checked.deck
		result.append({"selection": selection, "deck_name": deck.deck_name})
	return result


static func resolve(catalog: Variant, selection: Dictionary) -> Dictionary:
	if not FeatureGate.is_enabled(): return {"ok": false, "error_code": "author_strategy_disabled"}
	if Model.stable_ref(selection).is_empty():
		return {"ok": false, "error_code": "missing_package_reference"}
	var requested := Gate.request_match_handle(catalog, selection)
	if not requested.get("ok", false): return requested
	var materialized := Materializer.build(requested.get("handle"))
	if not materialized.get("ok", false): return materialized
	return {"ok": true, "deck": materialized.deck, "handle": requested.handle, "authority_mode": requested.authority_mode}
