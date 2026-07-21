extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(800015934)
	var priorities: Array = profile.get("strategic_priorities", [])
	var route_preferences: Dictionary = profile.get("route_preferences", {})
	var safety: Dictionary = profile.get("safety", {})
	var parameters: Dictionary = profile.get("module_parameters", {}).get("tera_noctowl_search", {})
	var passed := int(profile.get("profile_version", 0)) >= 2 \
		and priorities.size() >= 5 \
		and float(route_preferences.get("model_consideration_margin", 0.0)) == 240.0 \
		and bool(safety.get("block_search_when_deck_low", false)) \
		and bool(parameters.get("minimum_attack_commitment", false))
	print("tord_tera_box round01 profile: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
