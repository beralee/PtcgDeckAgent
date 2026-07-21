extends SceneTree

const NoctowlSearchScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGTeraNoctowlSearch.gd")


func _initialize() -> void:
	var module := NoctowlSearchScript.new()
	var vessel := _trainer("Earthen Vessel", "Item", "Search your deck for up to 2 Basic Energy cards.")
	var energy_switch := _trainer("Energy Switch", "Item", "Move a basic Energy from 1 of your Pokemon to another.")
	var boss := _trainer("Boss's Orders", "Supporter", "Switch in 1 of your opponent's Benched Pokemon.")
	var stretcher := _trainer("Night Stretcher", "Item", "Put a Pokemon or Basic Energy from your discard pile into your hand.")
	var profile := {
		"noctowl_pair_roles": [["energy_access", "energy_mover"]],
		"module_parameters": {"tera_noctowl_search": {
			"secured_attack_churn_penalty": 650.0,
			"secured_attack_preserve_bonus": 420.0,
		}},
	}
	var picked := module.pick_pair(
		[vessel, energy_switch, boss, stretcher],
		{"id": "csv9c_noctowl_trainers", "min_select": 2, "max_select": 2},
		{"v18cpg_facts": {"attack": {"ready": true, "ko_available": true}}},
		profile,
		{},
		"route:attack_ko"
	)
	var passed := boss in picked and stretcher in picked and vessel not in picked and energy_switch not in picked
	print("tord_tera_box round07 minimum-resource after KO: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)


func _trainer(name_en: String, card_type: String, description: String) -> CardData:
	var data := CardData.new()
	data.name_en = name_en
	data.card_type = card_type
	data.description = description
	return data
