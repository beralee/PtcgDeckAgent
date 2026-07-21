extends SceneTree

const NoctowlSearchScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGTeraNoctowlSearch.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")


func _initialize() -> void:
	var module := NoctowlSearchScript.new()
	var profile := ProfileCatalogScript.get_profile_for_deck(800015934)
	var vessel := _trainer("Earthen Vessel", "Item", "Search your deck for up to 2 Basic Energy cards.")
	var energy_switch := _trainer("Energy Switch", "Item", "Move a basic Energy from 1 of your Pokemon to another.")
	var nest := _trainer("Nest Ball", "Item", "Search your deck for a Basic Pokemon and put it onto your Bench.")
	var stadium := _trainer("Area Zero Underdepths", "Stadium", "Your Bench can have up to 8 Pokemon if you have a Tera Pokemon in play.")
	var step := {"id": "csv9c_noctowl_trainers", "min_select": 2, "max_select": 2}
	var energy_pair := module.pick_pair([vessel, energy_switch, nest, stadium], step, {}, profile, {}, "route:energy_commit")
	var develop_pair := module.pick_pair([vessel, energy_switch, nest, stadium], step, {}, profile, {}, "route:develop")
	var passed := vessel in energy_pair and energy_switch in energy_pair \
		and nest in develop_pair and stadium in develop_pair
	print("tord_tera_box round04 route-bound pairs: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)


func _trainer(name_en: String, card_type: String, description: String) -> CardData:
	var data := CardData.new()
	data.name_en = name_en
	data.card_type = card_type
	data.description = description
	return data
