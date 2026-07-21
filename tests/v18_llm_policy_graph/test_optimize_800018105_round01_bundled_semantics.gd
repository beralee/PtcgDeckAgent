extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")

const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/800018105.json"

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(800018105)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	var manifest: Dictionary = parsed as Dictionary if parsed is Dictionary else {}
	_check(int(profile.get("profile_version", 0)) >= 3, "bundled semantic profile must be active")
	_check(int(profile.get("semantic_version", 0)) >= 2, "same-name print correction must advance semantic version")
	_check(str(manifest.get("deck_content_fingerprint", "")) == "5c28d940ed7d45948c1b72a3ced52dd2ed24479ef50ea1cd68ee3f16d113a4c1", "manifest must bind the bundled deck content")
	_check(not _roles(manifest, "CSV2C_054").has("ability_engine"), "regulation-G Kirlia without Refinement must not be an ability engine")
	_check(_roles(manifest, "CSV8C_094").has("damage_counter_mover"), "Munkidori must expose its counter-mover role")
	_check(not _roles(manifest, "CSV7C_030").has("attacker"), "Rellor must not be promoted as a strategic attacker")
	_check(_roles(manifest, "CSV7C_031").has("bench_protection"), "Rabsca must expose bench protection")
	_check(_roles(manifest, "CSV10C_082").has("embrace_target"), "Lillie's Clefairy ex must be a public Embrace target")
	_check(_roles(manifest, "CSV3C_123").has("hand_disruption"), "Iono must expose hand disruption")
	_check(_roles(manifest, "CSV8C_176").has("search_engine"), "Secret Box must expose multi-category search semantics")
	var parameters: Dictionary = profile.get("module_parameters", {})
	var embrace: Dictionary = parameters.get("gardevoir_embrace", {})
	var counter: Dictionary = parameters.get("damage_counter_control", {})
	_check(embrace.get("attack_cost_by_uid", {}).get("CSV10C_082", []) == ["P", "C"], "Clefairy attack must retain its typed PC cost")
	_check(str(counter.get("counter_mover_uid", "")) == "CSV8C_094", "Munkidori must be the exact counter mover")
	_check(str(counter.get("activation_symbol", "")) == "D", "Munkidori ability must require Darkness")
	_check(int(counter.get("move_points_per_use", 0)) == 30, "Munkidori must move exactly 30 damage")
	_check(int(profile.get("turn_visible_wait_budget_ms", 0)) == 6500, "semantic correction must not increase visible wait")
	if _failures.is_empty():
		print("V18CPG 800018105 bundled semantics: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _roles(manifest: Dictionary, uid: String) -> Array:
	for raw_card: Variant in manifest.get("cards", []):
		if raw_card is Dictionary and str((raw_card as Dictionary).get("uid", "")) == uid:
			return (raw_card as Dictionary).get("roles", []) as Array
	return []


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
