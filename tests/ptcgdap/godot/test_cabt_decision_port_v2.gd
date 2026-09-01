class_name TestCabtDecisionPortV2
extends TestBase

const PortScript = preload("res://scripts/ai/ptcgdap/host/godot/CabtDecisionPortV2.gd")
const CAPABILITY_HASH := "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"


class AtomicExecutor extends RefCounted:
	var rolled_back := false
	var fail := false

	func prepare(targets: Array) -> Variant:
		return targets.duplicate()

	func commit(prepared: Variant) -> Variant:
		return null if fail else {"count": (prepared as Array).size()}

	func rollback(_prepared: Variant) -> void:
		rolled_back = true


func _select_type(context: int) -> int:
	if context == 0: return 0
	if context <= 25: return 1
	if context <= 28: return 2
	if context == 29: return 3
	if context <= 33: return 4
	if context == 34: return 5
	if context <= 36: return 6
	if context == 37: return 7
	if context <= 40: return 8
	if context <= 46: return 9
	return 10


func _option_type(context: int) -> int:
	if context == 0: return 7
	if context <= 25: return 3
	if context == 26 or context == 28: return 5
	if context == 27: return 4
	if context == 29: return 3
	if context <= 33: return 6
	if context == 34: return 15
	if context <= 36: return 13
	if context == 37: return 9
	if context <= 40: return 0
	if context <= 46: return 1
	return 16


func _option(raw: int) -> Dictionary:
	match raw:
		0: return {"type":0,"number":0}
		1: return {"type":1}
		3: return {"type":3,"area":2,"index":0,"playerIndex":0}
		4: return {"type":4,"area":4,"index":0,"playerIndex":0,"toolIndex":0}
		5: return {"type":5,"area":4,"index":0,"playerIndex":0,"energyIndex":0}
		6: return {"type":6,"area":8,"index":0,"playerIndex":0,"energyIndex":0,"count":1}
		7: return {"type":7,"index":0}
		9: return {"type":9,"area":2,"index":0,"inPlayArea":4,"inPlayIndex":0}
		13: return {"type":13,"attackId":1}
		15: return {"type":15,"cardId":0,"serial":0}
		16: return {"type":16,"specialConditionType":0}
	return {}


func _raw(context: int) -> Dictionary:
	return {
		"select": {
			"type":_select_type(context),"context":context,
			"minCount":1,"maxCount":1,"remainDamageCounter":0,"remainEnergyCost":0,
			"option":[_option(_option_type(context))],
			"deck":null,"contextCard":null,"effect":null,
		},
		"current":{},"logs":[],
	}


func _issue(context: int) -> Dictionary:
	return PortScript.issue(
		_raw(context), "session-a", 1, 0, 1, [{"private":context}], 0, CAPABILITY_HASH
	)


func test_every_official_context_uses_one_atomic_port() -> String:
	for context: int in 49:
		var issued := _issue(context)
		if not bool(issued.get("ok", false)):
			return "context %d issue failed: %s" % [context, issued.get("error_code")]
		var binding: Variant = issued.get("binding")
		var accepted: Dictionary = binding.accept([0])
		if not bool(accepted.get("ok", false)) or binding.state != "accepted":
			return "context %d accept failed" % context
		var bound: Dictionary = binding.bind(accepted.get("accepted"))
		if not bool(bound.get("ok", false)) or binding.state != "bound":
			return "context %d bind failed" % context
		var committed: Dictionary = binding.commit(bound.get("bound"), AtomicExecutor.new())
		if not bool(committed.get("ok", false)) or binding.state != "committed":
			return "context %d commit failed" % context
		var next := _raw(context)
		next["logs"] = [{"type":0,"playerIndex":0}]
		var witnessed: Dictionary = binding.witness(next)
		if not bool(witnessed.get("ok", false)) or binding.state != "public-witness":
			return "context %d witness failed" % context
	return ""


func test_hashes_match_python_and_private_binding_stays_private() -> String:
	var issued := _issue(34)
	if not bool(issued.get("ok", false)):
		return str(issued.get("error_code"))
	var binding: Variant = issued.get("binding")
	var public: Dictionary = binding.public_window
	if public.get("engine_semantic_hash") != "3F9AD93258227A92563D11965036EAD3C52A933D27A327D8AABCDBCA4D88F3F3":
		return "engine semantic hash differs from Python"
	if public.get("policy_input_hash") != "359D8C52B531534727142A8A96AA73FFE9E1B60E5CF8BC6C803C8BBA17BF2FF0":
		return "policy input hash differs from Python"
	if public.get("window_id") != "D51202145C6C8BAFE16D004D3CE4677296C7C09B0BE1437BD7539038C1737EC6":
		return "window hash differs from Python"
	var serialized := JSON.stringify(public)
	for forbidden: String in ["session-a","callback_binding_hash","private"]:
		if serialized.contains(forbidden):
			return "public window leaked %s" % forbidden
	return ""


func test_invalid_and_partial_commit_are_contained() -> String:
	var issued := _issue(34)
	var binding: Variant = issued.get("binding")
	if binding.accept([true]).get("error_code") != "invalid_agent_output":
		return "bool output was accepted"
	issued = _issue(34)
	binding = issued.get("binding")
	var accepted: Dictionary = binding.accept([0])
	var bound: Dictionary = binding.bind(accepted.get("accepted"))
	var executor := AtomicExecutor.new()
	executor.fail = true
	var failed: Dictionary = binding.commit(bound.get("bound"), executor)
	if failed.get("error_code") != "cabt_executor_atomic_failure":
		return "partial commit did not fail closed"
	if not executor.rolled_back or binding.state != "invalidated":
		return "partial commit did not roll back and invalidate"
	return ""
