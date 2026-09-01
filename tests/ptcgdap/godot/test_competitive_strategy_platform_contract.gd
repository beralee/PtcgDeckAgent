class_name TestCompetitiveStrategyPlatformContract
extends TestBase

const ContractScript = preload("res://scripts/ai/ptcgdap/platform/CompetitiveStrategyContracts.gd")


func _loaded() -> Dictionary:
	return ContractScript.load_default()


func test_trusted_bundle_and_public_non_authority_are_exact() -> String:
	var loaded := _loaded()
	if not bool(loaded.get("accepted", false)):
		return "contract load failed: %s" % loaded.get("error_code")
	var owner: Variant = loaded.get("owner")
	if owner.bundle_canonical_sha256() != ContractScript.EXPECTED_BUNDLE_CANONICAL_SHA256:
		return "bundle anchor drift"
	var vectors: Dictionary = owner.conformance_vectors()
	var result: Dictionary = owner.run_vector(vectors.success_cases[0])
	if result != vectors.success_cases[0].expected:
		return "accepted vector drift"
	if result.get("authoritative") != false or result.get("grants") != []:
		return "serialized validation gained authority"
	return ""


func test_all_shared_success_and_rejection_vectors_match() -> String:
	var loaded := _loaded()
	if not bool(loaded.get("accepted", false)):
		return "contract load failed: %s" % loaded.get("error_code")
	var owner: Variant = loaded.get("owner")
	var vectors: Dictionary = owner.conformance_vectors()
	for spec: Variant in vectors.success_cases:
		var actual: Dictionary = owner.run_vector(spec)
		if actual != spec.expected:
			return "%s success mismatch: %s" % [spec.id, actual]
	for spec: Variant in vectors.rejection_cases:
		var actual: Dictionary = owner.run_vector(spec)
		if bool(actual.get("accepted", false)) or actual.get("error_code") != spec.error_code:
			return "%s rejection mismatch: %s" % [spec.id, actual]
		if actual.has("owner") or actual.has("grants") or actual.has("canonical_sha256"):
			return "%s returned partial authority" % spec.id
	return ""


func test_every_private_replay_key_fails_at_nested_depth() -> String:
	var loaded := _loaded()
	if not bool(loaded.get("accepted", false)):
		return "contract load failed: %s" % loaded.get("error_code")
	var owner: Variant = loaded.get("owner")
	var vectors: Dictionary = owner.conformance_vectors()
	var forbidden := [
		"hand", "deck", "prizes", "deck_order", "search_begin_input",
		"private_rng_state", "private_replay_snapshot", "instance_id", "object_id",
		"game_state", "game_state_machine", "action_ticket", "callback", "binding",
		"engine_object",
	]
	for key: String in forbidden:
		var replay: Dictionary = vectors.fixtures.replay.duplicate(true)
		replay.frames[0].public_state[key] = ["PRIVATE_SENTINEL"]
		var result: Dictionary = owner.validate_replay(replay.manifest, replay.frames)
		if result.get("error_code") != "private_field_forbidden":
			return "%s was not rejected: %s" % [key, result]
		if JSON.stringify(result).contains("PRIVATE_SENTINEL"):
			return "%s echoed private data" % key
	return ""


func test_replay_validation_never_invokes_or_grants_engine_authority() -> String:
	var loaded := _loaded()
	if not bool(loaded.get("accepted", false)):
		return "contract load failed: %s" % loaded.get("error_code")
	var owner: Variant = loaded.get("owner")
	var replay: Dictionary = owner.conformance_vectors().fixtures.replay
	var result: Dictionary = owner.validate_replay(replay.manifest, replay.frames)
	if not bool(result.get("accepted", false)):
		return "valid replay rejected: %s" % result
	if result.get("authoritative") != false or result.get("engine_invoked") != false or result.get("grants") != []:
		return "replay validation gained execution authority"
	return ""


func test_cyclic_in_memory_input_fails_closed() -> String:
	var loaded := _loaded()
	if not bool(loaded.get("accepted", false)):
		return "contract load failed: %s" % loaded.get("error_code")
	var cyclic := {}
	cyclic["self"] = cyclic
	var result: Dictionary = loaded.get("owner").validate_document(cyclic)
	if result.get("error_code") != "document_invalid":
		return "cyclic input did not fail closed: %s" % result
	return ""
