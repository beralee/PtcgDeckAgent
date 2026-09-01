class_name TestEngineDecisionPort
extends TestBase

const PortScript = preload("res://scripts/engine/decision/EngineDecisionPort.gd")
const FirewallScript = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")
const CardInstanceScript = preload("res://scripts/data/CardInstance.gd")
const VECTOR_PATH := "res://contracts/ptcgdap/engine_decision_port_conformance_vectors.json"
const EXPECTED_BUNDLE_HASH := "CC0026D523F2B5435031AC4E5952DB4E2C8B2C39944B333E97B1A2E4F3374C81"


func _read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_buffer(file.get_length()) if file != null else PackedByteArray()


func _vectors() -> Dictionary:
	var parsed: Dictionary = FirewallScript._parse_contract_json_bytes(_read_bytes(VECTOR_PATH))
	return parsed.get("value") if bool(parsed.get("ok", false)) and parsed.get("value") is Dictionary else {}


func _materialize(value: Variant, refs: Dictionary) -> Variant:
	if typeof(value) == TYPE_STRING and str(value).begins_with("card:"):
		if not refs.has(value):
			refs[value] = CardInstanceScript.new()
		return refs[value]
	if value is Array:
		var output := []
		for item: Variant in value:
			output.append(_materialize(item, refs))
		return output
	if value is Dictionary:
		var output := {}
		for key: Variant in value:
			output[key] = _materialize(value[key], refs)
		return output
	return value


func _case(case_id: String) -> Dictionary:
	for case_value: Variant in _vectors().get("publish_cases", []):
		if case_value is Dictionary and case_value.get("id") == case_id:
			return case_value
	return {}


func test_fixed_contract_loads() -> String:
	var port: Variant = PortScript.open_match(1)
	if port == null or not port.ok:
		return "port contract failed to load"
	if port.contract_hash != EXPECTED_BUNDLE_HASH or not port.validate_integrity():
		return "port contract anchor differs"
	return ""


func test_shared_publish_vectors_preserve_exact_order() -> String:
	var cases: Array = _vectors().get("publish_cases", [])
	if cases.size() != 12:
		return "publish vector count differs: %d" % cases.size()
	for case_value: Variant in cases:
		var case: Dictionary = case_value
		var refs := {}
		var port: Variant = PortScript.open_match(case.get("match_generation"))
		var result: Variant = port.publish(
			_materialize(case.get("source"), refs),
			case.get("decision_generation"),
			case.get("chooser_player_index")
		)
		var expected: Dictionary = case.get("expected")
		if result.accepted != expected.get("accepted") or result.error_code != expected.get("error_code"):
			return "%s result differs: %s" % [case.get("id"), result.error_code]
		if result.accepted:
			if not result.validate_integrity(port) or not result.snapshot.validate_integrity(port):
				return "%s integrity failed" % case.get("id")
			var rebound: Dictionary = port.rebind(result.snapshot, _materialize(case.get("source"), refs))
			if not bool(rebound.get("ok", false)):
				return "%s rebind failed: %s" % [case.get("id"), rebound.get("error_code")]
			var expected_select: Variant = case.get("source").get("select")
			var actual_select: Variant = rebound.get("value").get("select")
			if expected_select == null:
				if actual_select != null:
					return "%s null select differs" % case.get("id")
			else:
				var expected_types := []
				var actual_types := []
				for item: Variant in expected_select.get("option", []):
					expected_types.append(item.get("type"))
				for item: Variant in actual_select.get("option", []):
					actual_types.append(item.get("type"))
				if actual_types != expected_types:
					return "%s order differs" % case.get("id")
	return ""


func test_generation_replacement_and_cross_port_replay_fail_closed() -> String:
	var refs := {}
	var source: Dictionary = _materialize(_case("scalar-order").get("source"), refs)
	var port: Variant = PortScript.open_match(7)
	var first: Variant = port.publish(source, 1, 0)
	var second: Variant = port.publish(source, 2, 0)
	if not first.accepted or not second.accepted:
		return "valid generations rejected"
	if port.rebind(first.snapshot, source).get("error_code") != "snapshot_not_current":
		return "old snapshot remained current"
	if not bool(port.rebind(second.snapshot, source).get("ok", false)):
		return "current snapshot did not rebind"
	if port.publish(source, 2, 0).error_code != "stale_decision_generation":
		return "duplicate generation accepted"
	var other: Variant = PortScript.open_match(7)
	if other.rebind(second.snapshot, source).get("error_code") != "snapshot_owner_mismatch":
		return "cross-port snapshot accepted"
	return ""


func test_source_reorder_scalar_and_reference_mutation_fail_closed() -> String:
	var refs := {}
	var source: Dictionary = _materialize(_case("card-reference").get("source"), refs)
	var port: Variant = PortScript.open_match(1)
	var snapshot: Variant = port.publish(source, 1, 1).snapshot
	source.get("select").get("option").reverse()
	source.get("option_card_refs").reverse()
	if port.rebind(snapshot, source).get("error_code") != "source_mutated":
		return "reordered source accepted"

	refs = {}
	source = _materialize(_case("card-reference").get("source"), refs)
	port = PortScript.open_match(1)
	snapshot = port.publish(source, 1, 1).snapshot
	source["option_card_refs"][0] = CardInstanceScript.new()
	if port.rebind(snapshot, source).get("error_code") not in ["source_mutated", "reference_released"]:
		return "replaced reference accepted"

	refs = {}
	source = _materialize(_case("scalar-order").get("source"), refs)
	port = PortScript.open_match(1)
	snapshot = port.publish(source, 1, 0).snapshot
	source["turn_action_count"] = 99
	if port.rebind(snapshot, source).get("error_code") != "source_mutated":
		return "scalar mutation accepted"
	return ""


func test_snapshot_and_result_mutation_do_not_echo_or_authorize() -> String:
	var refs := {}
	var source: Dictionary = _materialize(_case("card-reference").get("source"), refs)
	var port: Variant = PortScript.open_match(1)
	var result: Variant = port.publish(source, 1, 1)
	var audit: Dictionary = result.snapshot.to_audit_dict()
	var serialized := JSON.stringify(result.to_public_dict())
	for forbidden: String in ["instance_id", "object_id", "private_command", "callback_binding", "ticket", "_pending_choice", "_dialog_data", "card:a"]:
		if serialized.contains(forbidden):
			return "serialized result leaked %s" % forbidden
	audit["snapshot_id"] = "F".repeat(64)
	if result.snapshot.to_audit_dict().get("snapshot_id") == audit.get("snapshot_id"):
		return "audit getter was mutable"
	result.snapshot.set("_audit", {"select": {"private_command": "private-sentinel"}})
	if result.snapshot.validate_integrity(port) or result.snapshot.to_audit_dict() != {} or JSON.stringify(result.snapshot.to_audit_dict()).contains("private-sentinel"):
		return "mutated audit retained integrity or echoed private data"
	var refs2 := {}
	var port2: Variant = PortScript.open_match(1)
	result = port2.publish(_materialize(_case("card-reference").get("source"), refs2), 1, 1)
	result.snapshot.set("_decision_generation", 999)
	if result.snapshot.validate_integrity(port2) or result.snapshot.to_audit_dict() != {}:
		return "mutated snapshot retained integrity"
	return ""


func test_strict_godot_host_types_reject() -> String:
	var case := _case("scalar-order")
	var source: Dictionary = _materialize(case.get("source"), {})
	var faults := [
		["generation_string", "1", 0],
		["chooser_string_name", 1, StringName("0")],
		["generation_float", 1.0, 0],
	]
	for fault: Array in faults:
		var port: Variant = PortScript.open_match(1)
		var result: Variant = port.publish(source, fault[1], fault[2])
		if result.accepted:
			return "%s host type accepted" % fault[0]
	return ""
