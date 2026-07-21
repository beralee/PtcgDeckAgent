extends SceneTree

const NoctowlSearchScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGTeraNoctowlSearch.gd")


func _initialize() -> void:
	var module := NoctowlSearchScript.new()
	var vessel := _trainer("Earthen Vessel", "Item", "Search your deck for up to 2 Basic Energy cards.")
	var energy_switch := _trainer("Energy Switch", "Item", "Move a basic Energy from 1 of your Pokemon to another.")
	var crispin := _trainer("Crispin", "Supporter", "Search your deck for 2 Basic Energy cards. Attach 1 to your Pokemon.")
	var profile := {
		"noctowl_pair_roles": [
			["energy_access", "energy_mover"],
			["supporter_acceleration", "energy_access"],
		],
		"module_parameters": {"tera_noctowl_search": {
			"energy_mover_requires_board_energy": true,
			"dead_energy_mover_penalty": 1100.0,
		}},
	}
	var picked := module.pick_pair(
		[vessel, energy_switch, crispin],
		{"id": "csv9c_noctowl_trainers", "min_select": 2, "max_select": 2},
		{
			"v18cpg_facts": {"turn": {"supporter_available": true}},
			"v18cpg_observation": {"own": {"active": {"energy_count": 0}, "bench": []}},
		},
		profile,
		{},
		"route:accelerate"
	)
	var passed := crispin in picked and vessel in picked and energy_switch not in picked
	print("tord_tera_box round10 energy-mover liveness: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)


func _trainer(name_en: String, card_type: String, description: String) -> CardData:
	var data := CardData.new()
	data.name_en = name_en
	data.card_type = card_type
	data.description = description
	return data
