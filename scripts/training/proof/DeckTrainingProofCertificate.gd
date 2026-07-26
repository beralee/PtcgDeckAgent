class_name DeckTrainingProofCertificate
extends RefCounted


const ProofSolverScript := preload("res://scripts/training/proof/DeckTrainingProofSolver.gd")
const MIN_EXPERT_PLAYER_ACTIONS := 5


static func scenario_fingerprint(scenario: Dictionary) -> String:
	var source := scenario.duplicate(true)
	source.erase("proof_certificate")
	return JSON.stringify(_canonicalize(source)).sha256_text()


static func validate(
	scenario: Dictionary,
	certificate: Dictionary,
	require_unique_solution: bool = true,
	minimum_player_actions: int = MIN_EXPERT_PLAYER_ACTIONS
) -> Dictionary:
	var errors: Array[String] = []
	if int(certificate.get("format_version", 0)) != 1:
		errors.append("unsupported proof certificate format")
	if str(certificate.get("solver_version", "")) != ProofSolverScript.SOLVER_VERSION:
		errors.append("certificate was produced by a different solver version")
	if str(certificate.get("status", "")) != ProofSolverScript.STATUS_PROVEN:
		errors.append("scenario is not proven")
	if str(certificate.get("scenario_fingerprint", "")) != scenario_fingerprint(scenario):
		errors.append("certificate is stale for the current scenario")
	if not bool(certificate.get("exhaustive_defense", false)):
		errors.append("opponent defense or chance outcomes are not exhaustive")
	if not (certificate.get("unsupported_reasons", []) as Array).is_empty():
		errors.append("certificate contains unsupported branches")
	if require_unique_solution and not bool(certificate.get("unique_root_solution", false)):
		errors.append("unique root solution is not proven")
	if int(certificate.get("shortest_player_actions", 0)) < minimum_player_actions:
		errors.append("shortest solution must require at least %d player actions" % minimum_player_actions)
	var metrics_variant: Variant = certificate.get("metrics", null)
	if not (metrics_variant is Dictionary):
		errors.append("certificate metrics are missing")
	else:
		var metrics: Dictionary = metrics_variant
		if int(metrics.get("nodes_visited", 0)) <= 0:
			errors.append("certificate did not visit any proof nodes")
		if str(metrics.get("budget_reason", "")) != "":
			errors.append("proof search exhausted its budget")
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"scenario_fingerprint": scenario_fingerprint(scenario),
	}


static func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var source: Dictionary = value
		var keys: Array[String] = []
		for key: Variant in source.keys():
			keys.append(str(key))
		keys.sort()
		var result: Dictionary = {}
		for key: String in keys:
			result[key] = _canonicalize(source.get(key))
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_canonicalize(item))
		return result
	return value
