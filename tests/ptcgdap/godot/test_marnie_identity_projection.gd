class_name TestMarnieIdentityProjection
extends TestBase

const IdentityScript = preload("res://scripts/ai/ptcgdap/public/MarnieIdentityProjection.gd")
const FirewallScript = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")
const ProjectorScript = preload("res://scripts/ai/ptcgdap/host/godot/GodotObservationProjector.gd")
const ProjectorTestScript = preload("res://tests/ptcgdap/godot/test_observation_projector.gd")
const VECTOR_PATH := "res://contracts/ptcgdap/marnie_identity_projection_conformance_vectors.json"
const EXPECTED_BUNDLE_HASH := "1EB530AB7DFACBE6AB098A6C67D6AAE0BC1871FF3E2F48C9284E8539EE6ACDC4"


func _read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_buffer(file.get_length()) if file != null else PackedByteArray()


func _vectors() -> Dictionary:
	var parsed: Dictionary = FirewallScript._parse_contract_json_bytes(_read_bytes(VECTOR_PATH))
	return parsed.get("value", {}) if bool(parsed.get("ok", false)) else {}


func _materialize(value: Variant) -> Variant:
	if value is Dictionary and value.keys().size() == 2 and value.get("host_type") == "integer" and value.has("value"):
		return value.get("value")
	if value is Dictionary:
		var output := {}
		for key: Variant in value:
			output[key] = _materialize(value[key])
		return output
	if value is Array:
		var output := []
		for child: Variant in value:
			output.append(_materialize(child))
		return output
	return value


func test_default_gate_loads_exact_bundle_and_is_audit_only() -> String:
	var owner: Variant = IdentityScript.load_default()
	if owner == null or not bool(owner.get("ok")):
		return "identity gate failed to load: %s" % ("null" if owner == null else owner.error_code)
	if not owner.validate_integrity() or owner.bundle_hash() != EXPECTED_BUNDLE_HASH:
		return "identity gate trust anchor differs"
	var audit: Dictionary = owner.audit_snapshot()
	if audit.get("frame_count") != 13 or audit.get("distinct_official_card_id_count") != 34 or audit.get("cross_frame_unique_serial_count") != 94:
		return "identity audit summary differs"
	if audit.get("execution_authority") != false or audit.get("production_actions_used") != false:
		return "identity audit gained authority"
	return ""


func test_shared_source_frame_vectors_match_python_exactly() -> String:
	var owner: Variant = IdentityScript.load_default()
	var vectors := _vectors()
	var cases: Array = vectors.get("cases", [])
	if cases.size() != 23:
		return "identity vector count differs"
	for case_value: Variant in cases:
		var case: Dictionary = case_value
		var result: Dictionary = owner.run(case.get("operation"), _materialize(case.get("input", {})).duplicate(true))
		if result != case.get("expected"):
			return "%s differs: %s" % [case.get("case_id"), result]
		var text := JSON.stringify(result)
		if text.contains("private_sentinel") or text.contains("host_pokemon_entity_serial"):
			return "%s echoed private input" % case.get("case_id")
	return ""


func test_real_engine_projection_revalidates_projector_registry_catalog_and_hidden_shape() -> String:
	var helper: Variant = ProjectorTestScript.new()
	var fixture: Dictionary = helper._engine_fixture()
	if not bool(fixture.get("ok", false)):
		return str(fixture.get("error"))
	var projector: Variant = ProjectorScript.load_default()
	var result: Variant = projector.capture_engine(
		fixture.get("state"), fixture.get("registry"), helper._main_engine_decision(),
		[{"kind":"attack","card_ref":fixture.get("cards")["p0_active"],"local_attack_index":0}],
		fixture.get("sources"), 3, 600,
	)
	if result == null or not result.accepted:
		return "source-attested engine projection failed"
	var owner: Variant = IdentityScript.load_default()
	var attestation: Dictionary = owner.attest_engine_projection(projector, result)
	if not bool(attestation.get("ok", false)):
		return "engine projection attestation failed: %s" % attestation.get("error_code")
	var value: Dictionary = attestation.get("value")
	if value.get("source") != "engine_attested_shadow" or value.get("identity_occurrence_count", 0) <= 0:
		return "engine projection audit source or count differs"
	if not (value.get("known_unmapped_official_card_ids", []) as Array).is_empty():
		return "engine source fixture unexpectedly used an unmapped visible identity"
	if value.get("execution_authority") != false or value.get("production_actions_used") != false:
		return "engine attestation gained authority"
	var public_dict: Dictionary = result.to_public_dict()
	var players: Array = public_dict.get("observation", {}).get("current", {}).get("players", [])
	var registry_card: Dictionary = fixture.get("registry").lookup_card(
		fixture.get("cards")["p0_active"], fixture.get("registry").get_match_generation(), 0,
	)
	if players[0].get("active", [])[0].get("serial") != registry_card.get("serial"):
		return "wire Pokemon serial did not equal the top physical-card serial"
	var text := JSON.stringify(public_dict)
	for hidden_id: int in [1080, 112, 1259]:
		if text.contains('"id":%d' % hidden_id):
			return "hidden identity leaked: %d" % hidden_id
	if text.contains("host_pokemon_entity"):
		return "Host-private entity identity leaked"
	return ""


func test_stale_or_mutated_projector_result_is_rejected_without_echo() -> String:
	var helper: Variant = ProjectorTestScript.new()
	var fixture: Dictionary = helper._engine_fixture()
	if not bool(fixture.get("ok", false)):
		return str(fixture.get("error"))
	var projector: Variant = ProjectorScript.load_default()
	var result: Variant = projector.capture_engine(
		fixture.get("state"), fixture.get("registry"), helper._main_engine_decision(), [], fixture.get("sources"),
	)
	var owner: Variant = IdentityScript.load_default()
	result.set("_public_observation_hash", "F".repeat(64))
	var rejected: Dictionary = owner.attest_engine_projection(projector, result)
	if rejected != {"ok":false,"error_code":"projector_result_invalid","value":null}:
		return "mutated projector result did not fail closed: %s" % rejected
	return ""


func test_copy_and_internal_mutation_fail_closed() -> String:
	var owner: Variant = IdentityScript.load_default()
	var first: Dictionary = owner.audit_all()
	first.get("value").get("frames")[1].get("distinct_official_card_ids")[0] = 9999
	if first == owner.audit_all():
		return "caller mutation changed owner output"
	owner.set("_known_cards", {})
	if owner.validate_integrity():
		return "relation cache mutation retained integrity"
	if owner.audit_all() != {"ok":false,"error_code":"identity_integrity_invalid","value":null}:
		return "mutated owner did not fail closed"
	return ""


func test_runtime_has_no_live_consumer_or_mapping_guess_path() -> String:
	var source := FileAccess.get_file_as_string("res://scripts/ai/ptcgdap/public/MarnieIdentityProjection.gd")
	for forbidden: String in ["AIOpponent", "BattleScene", "HeadlessMatchBridge", "CardDatabase", "CardCatalogIndex", "set_code_en", "card_index_en", "HTTPRequest", "HTTPClient", "FileAccess.WRITE"]:
		if source.contains(forbidden):
			return "identity gate contains forbidden marker %s" % forbidden
	return ""
