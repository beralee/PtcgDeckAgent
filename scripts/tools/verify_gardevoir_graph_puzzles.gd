extends SceneTree


const CatalogScript := preload("res://scripts/training/DeckTrainingCatalog.gd")
const StateFactoryScript := preload("res://scripts/training/DeckTrainingStateFactory.gd")
const SolverScript := preload("res://scripts/training/proof/DeckTrainingProofSolver.gd")
const AdapterScript := preload("res://scripts/training/proof/DeckTrainingWitnessProofAdapter.gd")
const AdmissionScript := preload("res://scripts/training/DeckTrainingAdmissionVerifier.gd")


func _initialize() -> void:
	var catalog := CatalogScript.load_catalog()
	print("CATALOG_ERRORS ", JSON.stringify(catalog.get("errors", [])))
	var failed := false
	for scenario: Dictionary in CatalogScript.list_scenarios(CatalogScript.CATALOG_PATH, "gardevoir"):
		var scenario_id := str(scenario.get("id", ""))
		var built := StateFactoryScript.build(scenario)
		var gsm: GameStateMachine = built.get("gsm", null)
		if gsm == null:
			failed = true
			print("%s BUILD_FAILED %s" % [scenario_id, JSON.stringify(built.get("errors", []))])
			continue
		var adapter := AdapterScript.new()
		adapter.configure(scenario)
		var certificate := SolverScript.new().prove(
			adapter.make_initial_state(gsm),
			adapter,
			{
				"max_depth": 48,
				"max_nodes": 1024,
				"max_milliseconds": 30000,
				"require_unique_root": true,
				"collect_all_player_branches": true,
			}
		)
		var promotion := AdmissionScript.verify_for_solver_promotion(scenario, certificate)
		var status := str(certificate.get("status", ""))
		if status != SolverScript.STATUS_PROVEN:
			failed = true
			_trace_witness(scenario, gsm)
		print("%s %s actions=%d reason=%s unsupported=%s promotion=%s trace=%s" % [
			scenario_id,
			status,
			int(certificate.get("shortest_player_actions", 0)),
			str(certificate.get("reason", "")),
			JSON.stringify(certificate.get("unsupported_reasons", [])),
			JSON.stringify(promotion.get("errors", [])),
			JSON.stringify(_failure_trace(certificate.get("proof_tree", {}))),
		])
		if status == SolverScript.STATUS_PROVEN:
			var path := "res://data/deck_training/proofs/%s.json" % scenario_id
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(certificate, "\t") + "\n")
				file.close()
		gsm.prepare_for_disposal()
	quit(1 if failed or not (catalog.get("errors", []) as Array).is_empty() else 0)


func _trace_witness(scenario: Dictionary, source_gsm: GameStateMachine) -> void:
	var adapter := AdapterScript.new()
	adapter.configure(scenario)
	var proof_state: Dictionary = adapter.make_initial_state(source_gsm)
	var trace: Array[String] = []
	for _index: int in 48:
		var terminal: Dictionary = adapter.terminal_result(proof_state)
		if bool(terminal.get("terminal", false)):
			trace.append("terminal=%s" % str(terminal.get("reason", "")))
			break
		var choices: Array = adapter.legal_choices(proof_state).get("choices", [])
		if choices.is_empty():
			trace.append("no_choice")
			break
		var label := str((choices[0] as Dictionary).get("label", ""))
		var transition := adapter.apply_choice(proof_state, choices[0])
		if not bool(transition.get("ok", false)):
			trace.append("%s REJECT %s" % [label, str(transition.get("reason", ""))])
			break
		proof_state = transition.get("state", {})
		var witness_gsm: GameStateMachine = proof_state.get("gsm", null)
		trace.append("%s prizes=%d/%d" % [
			label,
			witness_gsm.game_state.players[0].prizes.size(),
			witness_gsm.game_state.players[1].prizes.size(),
		])
	print("TRACE_%s %s" % [str(scenario.get("id", "")), JSON.stringify(trace)])
	var traced_gsm: GameStateMachine = proof_state.get("gsm", null)
	if traced_gsm != null:
		traced_gsm.prepare_for_disposal()


func _first_leaf_reason(node_variant: Variant) -> String:
	if not (node_variant is Dictionary):
		return ""
	var node: Dictionary = node_variant
	var reason := str(node.get("reason", ""))
	if reason != "":
		return reason
	for branch_variant: Variant in node.get("branches", []):
		if not (branch_variant is Dictionary):
			continue
		var branch: Dictionary = branch_variant
		var branch_reason := str(branch.get("reason", ""))
		if branch_reason != "":
			return branch_reason
		var nested := _first_leaf_reason(branch.get("tree", {}))
		if nested != "":
			return nested
	return ""


func _failure_trace(node_variant: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (node_variant is Dictionary):
		return result
	var node: Dictionary = node_variant
	var reason := str(node.get("reason", ""))
	if reason != "":
		result.append(reason)
	for branch_variant: Variant in node.get("branches", []):
		if not (branch_variant is Dictionary):
			continue
		var branch: Dictionary = branch_variant
		var choice: Dictionary = branch.get("choice", {}) if branch.get("choice", {}) is Dictionary else {}
		result.append("%s=>%s" % [str(choice.get("label", choice.get("id", ""))), str(branch.get("reason", ""))])
		var nested := _failure_trace(branch.get("tree", {}))
		result.append_array(nested)
		if result.size() >= 18:
			break
	return result
