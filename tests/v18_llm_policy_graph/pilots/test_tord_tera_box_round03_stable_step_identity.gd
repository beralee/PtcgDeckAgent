extends SceneTree

const NoctowlSearchScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGTeraNoctowlSearch.gd")


func _initialize() -> void:
	var module := NoctowlSearchScript.new()
	var by_registered_step := module.handles_step({
		"id": "csv9c_noctowl_trainers",
		"title": "任意本地化标题",
	})
	var fuzzy_name_only := module.handles_step({
		"id": "some_other_effect",
		"title": "Noctowl Jewel Seeker 猫头夜鹰 宝石搜寻",
	})
	var passed := by_registered_step and not fuzzy_name_only
	print("tord_tera_box round03 stable step identity: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
