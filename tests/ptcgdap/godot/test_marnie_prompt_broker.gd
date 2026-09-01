class_name TestMarniePromptBroker
extends TestBase

const BrokerScript = preload("res://scripts/ai/ptcgdap/public/MarniePromptBroker.gd")
const PortScript = preload("res://scripts/engine/decision/EngineDecisionPort.gd")
const BindingScript = preload("res://scripts/engine/decision/GodotOptionBinding.gd")
const WindowScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd")
const ContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const VECTORS_PATH := "res://contracts/ptcgdap/marnie_prompt_broker_conformance_vectors.json"
const AUDIT_PATH := "res://data/ptcgdap/marnie_vertical_slice/marnie_prompt_broker_v1.json"
const EXPECTED_BUNDLE_HASH := "E2EFDDE373EFBA0FDC929BE817595C8B3F0A5653956DB56418ADED57AFF960A1"
const PROFILE_ID := "ptcgdap-marnie-prompt-broker-p5-wp5-v1"


class HostCapability extends RefCounted:
	pass

var _owner_value: Variant = null


func _owner() -> Variant:
	if _owner_value == null:
		_owner_value = BrokerScript.load_default()
	return _owner_value


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return null
	return _restore_integer_tokens(parser.data)


func _restore_integer_tokens(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var number := float(value)
			return int(number) if is_finite(number) and number == floorf(number) else number
		TYPE_ARRAY:
			var array: Array = []
			for child: Variant in value:
				array.append(_restore_integer_tokens(child))
			return array
		TYPE_DICTIONARY:
			var object: Dictionary = {}
			for key: Variant in value:
				object[key] = _restore_integer_tokens(value[key])
			return object
	return value


func _build_window(frame: Dictionary, mutation: String = "") -> Variant:
	var document: Dictionary = (frame.get("window") as Dictionary).duplicate(true)
	if mutation == "reorder":
		document.get("options").reverse()
	elif mutation == "attack_id":
		document.get("options")[1]["attackId"] = 938
	var select_payload := {
		"type": document.get("select_type_raw"), "context": document.get("select_context_raw"),
		"minCount": document.get("min_count"), "maxCount": document.get("max_count"),
		"remainDamageCounter": document.get("remain_damage_counter"),
		"remainEnergyCost": document.get("remain_energy_cost"),
		"option": document.get("options"), "deck": document.get("public_deck_candidates"),
		"contextCard": document.get("context_card"), "effect": document.get("effect"),
	}
	var built: Variant = WindowScript.build({
		"select": select_payload,
		"public_observation_hash": document.get("public_observation_hash"),
		"public_hash_authority": document.get("public_hash_authority"),
		"chooser_player_index": document.get("chooser_player_index"),
	}, ContractSetScript.load_default())
	return built.get("window") if built != null else null


func test_exact_bundle_loads_and_remains_shadow_only() -> String:
	var owner: Variant = _owner()
	if owner == null or not bool(owner.get("ok")):
		return "prompt broker failed to load: %s" % ("null" if owner == null else owner.error_code)
	if not owner.validate_integrity() or owner.bundle_hash() != EXPECTED_BUNDLE_HASH:
		return "prompt broker trust anchor differs"
	var audit: Dictionary = owner.audit_snapshot()
	if audit.get("frame_count") != 13 or audit.get("brokered_frame_count") != 11:
		return "prompt broker summary differs"
	return ""


func test_shared_vectors_match_python_without_skip() -> String:
	var owner: Variant = _owner()
	var vectors: Variant = _read_json(VECTORS_PATH)
	if not vectors is Dictionary or vectors.get("cases", []).size() != 23:
		return "prompt broker vector set differs"
	var seen := {}
	for case_value: Variant in vectors.get("cases"):
		if not case_value is Dictionary or seen.has(case_value.get("case_id")):
			return "invalid or duplicate vector case"
		seen[case_value.get("case_id")] = true
		var actual: Dictionary = owner.run(case_value.get("operation"), case_value.get("input"))
		if actual != case_value.get("expected"):
			return "%s differs: %s" % [case_value.get("case_id"), actual]
	return ""


func test_full_lifecycle_rebuilds_every_window_and_serializes_no_private_authority() -> String:
	var owner: Variant = _owner()
	var result: Variant = owner.evaluate_all()
	if result == null or not result.validate_integrity(owner):
		return "full lifecycle result invalid"
	var public: Dictionary = result.to_public_dict()
	if public.get("frame_count") != 13 or public.get("brokered_frame_count") != 11:
		return "full lifecycle count differs"
	var snapshots := {}
	var windows := {}
	var bindings := {}
	for frame_value: Variant in public.get("frames"):
		var frame: Dictionary = frame_value
		if frame.get("status") != "committed_shadow":
			continue
		if snapshots.has(frame.get("snapshot_id")) or windows.has(frame.get("window_id")) or bindings.has(frame.get("binding_version")):
			return "snapshot/window/binding authority was reused"
		snapshots[frame.get("snapshot_id")] = true
		windows[frame.get("window_id")] = true
		bindings[frame.get("binding_version")] = true
	if snapshots.size() != 11:
		return "broker lifecycle count differs"
	var text := JSON.stringify(public)
	for forbidden: String in ["private_engine_command", "private_object_refs", "private_resolutions", "callback_binding_hash", "session_id", "ticket", "preflight"]:
		if text.contains(forbidden):
			return "private field serialized: %s" % forbidden
	return ""


func test_w3_w6_frontiers_and_optional_zero_are_preserved_exactly() -> String:
	var public: Dictionary = _owner().evaluate_all().to_public_dict()
	var by_id := {}
	for frame: Variant in public.get("frames"):
		by_id[frame.get("frame_id")] = frame
	if by_id["w3_main"].get("option_types") != [8, 8, 7, 14]:
		return "W3 official frontier was rewritten"
	if by_id["w6_shadow_bullet_attack"].get("option_types") != [7, 13, 12, 14]:
		return "W6 official frontier was rewritten"
	if by_id["w2_setup_bench"].get("selected_indexes") != [] or by_id["w2_setup_bench"].get("committed_resolution_count") != 0:
		return "W2 optional-zero path differs"
	return ""


func test_explicit_full_revalidation_and_ordinary_mutation_fail_closed() -> String:
	var owner: Variant = _owner()
	if not owner.revalidate_full_lifecycle():
		return "explicit full lifecycle revalidation failed"
	var result: Variant = owner.evaluate_frame("w3_main")
	var changed: Dictionary = result.to_public_dict()
	changed["private_engine_command"] = "private-sentinel"
	result.set("_snapshot", changed)
	if result.validate_integrity(owner):
		return "mutated result retained integrity"
	var safe := JSON.stringify(result.to_public_dict())
	if safe.contains("private-sentinel") or result.to_public_dict().get("accepted") != false:
		return "mutated result echoed private value"

	var damaged: Variant = BrokerScript.load_default()
	var shifted: Dictionary = damaged.get("_frames_by_id").duplicate(true)
	shifted["w1_setup_active"] = shifted["w2_setup_bench"]
	damaged.set("_frames_by_id", shifted)
	if damaged.validate_integrity() or damaged.run("audit_snapshot", null).get("error_code") != "contract_integrity_invalid":
		return "shifted derived frame index retained integrity"
	return ""


func test_p5_extension_rejects_reorder_attack_drift_wrong_profile_and_stale_window() -> String:
	var audit: Variant = _read_json(AUDIT_PATH)
	if not audit is Dictionary:
		return "audit fixture unavailable"
	for spec: Array in [[3, "reorder"], [8, "attack_id"]]:
		var frame: Dictionary = audit.get("frames")[spec[0]]
		var source: Dictionary = frame.get("source").duplicate(true)
		var port: Variant = PortScript.open_match(1)
		var published: Variant = port.publish_p5_extended(source, frame.get("ordinal"), 0, PROFILE_ID)
		if not published.accepted:
			return "%s P5 publish failed: %s" % [frame.get("frame_id"), published.error_code]
		var window: Variant = _build_window(frame)
		var commands := []
		var refs := []
		for unused: int in range(window.option_count):
			commands.append(HostCapability.new())
			refs.append([])
		var binding_owner: Variant = BindingScript.new()
		var bound: Variant = binding_owner.bind_p5_extended(
			port, published.snapshot, source, window, frame.get("callback_binding_hash"),
			commands, refs, PROFILE_ID
		)
		if not bound.accepted:
			return "%s P5 bind failed: %s" % [frame.get("frame_id"), bound.error_code]
		var stale: Variant = _build_window(frame)
		if binding_owner.resolve(
			bound.binding, port, published.snapshot, source, stale,
			frame.get("callback_binding_hash"), 0
		).error_code != "window_mismatch":
			return "%s equivalent stale window was accepted" % frame.get("frame_id")
		var drifted: Variant = _build_window(frame, spec[1])
		var rejected: Variant = BindingScript.new().bind_p5_extended(
			port, published.snapshot, source, drifted, frame.get("callback_binding_hash"),
			commands, refs, PROFILE_ID
		)
		if rejected.accepted or rejected.error_code != "window_mismatch":
			return "%s drifted window was accepted" % frame.get("frame_id")
		var wrong: Variant = BindingScript.new().bind_p5_extended(
			port, published.snapshot, source, window, frame.get("callback_binding_hash"),
			commands, refs, StringName(PROFILE_ID)
		)
		if wrong.accepted or wrong.error_code != "window_mismatch":
			return "%s wrong extension profile was accepted" % frame.get("frame_id")
	return ""
