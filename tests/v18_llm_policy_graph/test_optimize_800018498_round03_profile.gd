extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const DecisionClientScript = preload("res://scripts/ai/v18_cpg/network/V18CPGDecisionClient.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(800018498)
	_check(int(profile.get("profile_version", 0)) >= 3, "profile must retain or advance round03")
	_check(int(profile.get("max_policy_nodes", 0)) == 8, "round03 must admit the wire hard maximum")
	_check(int(profile.get("turn_visible_wait_budget_ms", 0)) == 6500, "visible wait budget must not increase")
	_check(int(profile.get("initial_response_token_budget", 0)) == 400, "initial token budget must not increase")
	_check(int(profile.get("delta_response_token_budget", 0)) == 170, "delta token budget must not increase")
	var payload := DecisionClientScript.new()._build_payload({
		"limits": {"max_policy_nodes": int(profile.get("max_policy_nodes", 0))},
		"frontier": [],
		"allowed_follow_route_ids": [],
	}, 400, false)
	var messages: Array = payload.get("messages", []) if payload.get("messages", []) is Array else []
	var decoded: Variant = JSON.parse_string(
		str((messages[1] as Dictionary).get("content", "")) if messages.size() > 1 else ""
	)
	_check(
		decoded is Dictionary \
			and int((decoded as Dictionary).get("limits", {}).get("max_policy_nodes", 0)) == 8,
		"wire must receive the active eight-node profile limit"
	)
	if _failures.is_empty():
		print("optimization21 800018498 round03 profile: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
