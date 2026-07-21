extends SceneTree

const NoctowlSearchScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGTeraNoctowlSearch.gd")


func _initialize() -> void:
	var module := NoctowlSearchScript.new()
	var trainer := CardData.new()
	trainer.name_en = "Generic Search Item"
	trainer.card_type = "Item"
	trainer.description = "Search your deck for a card."
	var picked := module.pick_pair(
		[trainer],
		{"id": "csv9c_noctowl_trainers", "min_select": 0, "max_select": 2},
		{"v18cpg_facts": {"resources": {"deck_low": true, "deck_critical": true}}},
		{"module_parameters": {"tera_noctowl_search": {"allow_explicit_empty_when_deck_critical": true}}},
		{},
		"route:noctowl_search"
	)
	var passed := picked.is_empty()
	print("tord_tera_box round09 critical-deck explicit empty: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
