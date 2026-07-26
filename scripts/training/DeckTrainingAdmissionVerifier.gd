class_name DeckTrainingAdmissionVerifier
extends RefCounted


const MIN_AUTHORED_OPERATIONS := 8
const MIN_DECISION_POINTS := 2
const MIN_PAYOFF_VALUE := 4
const GRAPH_PROFILES := ["precision", "deployment", "composite"]
const ProofCertificateScript := preload("res://scripts/training/proof/DeckTrainingProofCertificate.gd")


static func verify_scenario(scenario: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var operations: Array = scenario.get("validation_operations", [])
	if operations.size() < MIN_AUTHORED_OPERATIONS:
		errors.append("authored solution must contain at least %d operations" % MIN_AUTHORED_OPERATIONS)
	for operation: Variant in operations:
		if str(operation).strip_edges() == "":
			errors.append("validation operation must not be empty")
	if int(scenario.get("turn_limit", 0)) not in [1, 2]:
		errors.append("expert puzzle must allow one or two player turns")
	var challenge_variant: Variant = scenario.get("challenge", null)
	if not (challenge_variant is Dictionary):
		errors.append("expert puzzle must declare a challenge contract")
	else:
		var challenge: Dictionary = challenge_variant
		if str(challenge.get("difficulty", "")) != "expert":
			errors.append("challenge difficulty must be expert")
		var decision_points: Array = challenge.get("decision_points", [])
		if decision_points.size() < MIN_DECISION_POINTS:
			errors.append("challenge must contain at least %d irreversible decision points" % MIN_DECISION_POINTS)
		for decision_variant: Variant in decision_points:
			if not (decision_variant is Dictionary):
				errors.append("decision point must describe the choice and its failure consequence")
				continue
			var decision: Dictionary = decision_variant
			if str(decision.get("choice", "")).strip_edges() == "" or str(decision.get("failure", "")).strip_edges() == "":
				errors.append("decision point must describe the choice and its failure consequence")
		if (challenge.get("cross_turn_dependencies", []) as Array).is_empty():
			errors.append("challenge must contain a cross-turn dependency")
		if (challenge.get("resource_tensions", []) as Array).is_empty():
			errors.append("challenge must contain a scarce-resource tension")
		if int(challenge.get("payoff_value", 0)) < MIN_PAYOFF_VALUE:
			errors.append("challenge payoff must be at least %d" % MIN_PAYOFF_VALUE)
	if scenario.has("graph_contract"):
		_verify_graph_contract(scenario, errors)
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"authored_operation_count": operations.size(),
	}


static func _verify_graph_contract(scenario: Dictionary, errors: Array[String]) -> void:
	var contract_variant: Variant = scenario.get("graph_contract", null)
	if not (contract_variant is Dictionary):
		errors.append("graph contract must be a dictionary")
		return
	var contract: Dictionary = contract_variant
	var profile := str(contract.get("profile", ""))
	if profile not in GRAPH_PROFILES:
		errors.append("graph contract profile must be precision, deployment or composite")
		return
	if str(contract.get("player_operator", "")) != "OR":
		errors.append("graph contract must model the player's initial choice as OR")
	var minimum_options := 2 if profile == "precision" else 3
	if (contract.get("initial_options", []) as Array).size() < minimum_options:
		errors.append("%s graph must expose at least %d plausible initial options" % [profile, minimum_options])
	var minimum_resources := 2 if profile == "precision" else 3
	if (contract.get("scarce_resources", []) as Array).size() < minimum_resources:
		errors.append("%s graph must couple at least %d scarce resources" % [profile, minimum_resources])
	if (contract.get("public_threats", []) as Array).is_empty():
		errors.append("graph contract must expose at least one public opponent threat")
	if profile in ["deployment", "composite"] and str(contract.get("opponent_operator", "")) != "AND":
		errors.append("%s graph must survive every credible opponent reply with an AND node" % profile)
	var minimum_axes: int = int({"precision": 1, "deployment": 2, "composite": 3}.get(profile, 1))
	if (contract.get("negative_probe_axes", []) as Array).size() < minimum_axes:
		errors.append("%s graph must cover at least %d independent negative-probe axes" % [profile, minimum_axes])
	if (contract.get("success_invariants", []) as Array).size() < 3:
		errors.append("graph success must include progress, survival and handoff invariants")
	if str(contract.get("proof_claim", "")) != "policy_replay_proven":
		errors.append("graph proof claim must be policy_replay_proven")
	if str(contract.get("uniqueness_scope", "")).strip_edges() == "":
		errors.append("graph contract must state its uniqueness scope")
	var artifact_path := str(contract.get("graph_artifact", ""))
	if artifact_path == "" or not FileAccess.file_exists(artifact_path):
		errors.append("graph contract must reference an existing graph artifact")
		return
	var file := FileAccess.open(artifact_path, FileAccess.READ)
	if file == null:
		errors.append("graph artifact could not be opened")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		errors.append("graph artifact must contain a JSON object")
		return
	var graph: Dictionary = parsed
	if str(graph.get("puzzle_id", "")) != str(scenario.get("id", "")):
		errors.append("graph artifact puzzle_id must match the scenario")
	if str(graph.get("profile", "")) != profile:
		errors.append("graph artifact profile must match the graph contract")
	if int(graph.get("revision", -1)) != int(scenario.get("revision", 0)):
		errors.append("graph artifact revision must match the scenario")


static func verify_all(scenarios: Array[Dictionary]) -> Dictionary:
	var results: Array[Dictionary] = []
	var errors: Array[String] = []
	for scenario: Dictionary in scenarios:
		var result := verify_scenario(scenario)
		result["scenario_id"] = str(scenario.get("id", ""))
		results.append(result)
		for error: Variant in result.get("errors", []):
			errors.append("%s: %s" % [str(scenario.get("id", "")), str(error)])
	return {"ok": errors.is_empty(), "errors": errors, "results": results}


static func verify_for_solver_promotion(scenario: Dictionary, certificate: Dictionary) -> Dictionary:
	var authoring := verify_scenario(scenario)
	var proof := ProofCertificateScript.validate(
		scenario,
		certificate,
		true,
		ProofCertificateScript.MIN_EXPERT_PLAYER_ACTIONS
	)
	var errors: Array[String] = []
	for error: Variant in authoring.get("errors", []):
		errors.append(str(error))
	for error: Variant in proof.get("errors", []):
		errors.append(str(error))
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"authoring": authoring,
		"proof": proof,
	}
