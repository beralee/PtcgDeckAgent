extends SceneTree

const NoctowlSearchScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGTeraNoctowlSearch.gd")


func _initialize() -> void:
	var module := NoctowlSearchScript.new()
	var crispin := _trainer("Crispin", "Supporter", "Search your deck for 2 Basic Energy cards. Attach 1 to your Pokemon.")
	var vessel := _trainer("Earthen Vessel", "Item", "Search your deck for up to 2 Basic Energy cards.")
	var energy_switch := _trainer("Energy Switch", "Item", "Move a basic Energy from 1 of your Pokemon to another.")
	var profile := {
		"noctowl_pair_roles": [
			["supporter_acceleration", "energy_mover"],
			["energy_access", "energy_mover"],
		],
		"module_parameters": {"tera_noctowl_search": {"supporter_unavailable_penalty": 900.0}},
	}
	var picked := module.pick_pair(
		[crispin, vessel, energy_switch],
		{"id": "csv9c_noctowl_trainers", "min_select": 2, "max_select": 2},
		{"v18cpg_facts": {"turn": {"supporter_available": false}}},
		profile,
		{},
		"route:energy_commit"
	)
	var passed := vessel in picked and energy_switch in picked and crispin not in picked
	print("tord_tera_box round06 supporter quota pair: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)


func _trainer(name_en: String, card_type: String, description: String) -> CardData:
	var data := CardData.new()
	data.name_en = name_en
	data.card_type = card_type
	data.description = description
	return data
