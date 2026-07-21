extends SceneTree

const NoctowlSearchScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGTeraNoctowlSearch.gd")


func _initialize() -> void:
	var module := NoctowlSearchScript.new()
	var vessel := _trainer("Earthen Vessel", "Item", "Search your deck for up to 2 Basic Energy cards.")
	var energy_switch := _trainer("Energy Switch", "Item", "Move a basic Energy from 1 of your Pokemon to another.")
	var nest := _trainer("Nest Ball", "Item", "Search your deck for a Basic Pokemon and put it onto your Bench.")
	var stadium := _trainer("Visible Bench Expander", "Stadium", "Your Bench can have more Pokemon while a public condition is met.")
	var profile := {
		"noctowl_pair_roles": [
			["energy_access", "energy_mover"],
			["stadium", "pokemon_search"],
		],
		"module_parameters": {"tera_noctowl_search": {
			"full_bench_expansion_pair_bonus": 760.0,
			"full_bench_dead_search_penalty": 950.0,
		}},
	}
	var picked := module.pick_pair(
		[vessel, energy_switch, nest, stadium],
		{"id": "csv9c_noctowl_trainers", "min_select": 2, "max_select": 2},
		{"v18cpg_facts": {"board": {"bench_full": true}}},
		profile,
		{},
		"route:develop"
	)
	var passed := nest in picked and stadium in picked
	print("tord_tera_box round08 full-bench pair: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)


func _trainer(name_en: String, card_type: String, description: String) -> CardData:
	var data := CardData.new()
	data.name_en = name_en
	data.card_type = card_type
	data.description = description
	return data
