extends SceneTree


const CatalogScript := preload("res://scripts/training/DeckTrainingCatalog.gd")
const StateFactoryScript := preload("res://scripts/training/DeckTrainingStateFactory.gd")
const ProofSolverScript := preload("res://scripts/training/proof/DeckTrainingProofSolver.gd")
const EngineProofAdapterScript := preload("res://scripts/training/proof/DeckTrainingEngineProofAdapter.gd")
const WitnessProofAdapterScript := preload("res://scripts/training/proof/DeckTrainingWitnessProofAdapter.gd")
const AdmissionVerifierScript := preload("res://scripts/training/DeckTrainingAdmissionVerifier.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var options := _parse_options(OS.get_cmdline_user_args())
	var scenario_id := str(options.get("scenario_id", "")).strip_edges()
	if scenario_id == "":
		printerr("Usage: --scenario-id=SCENARIO_ID [--max-depth=24] [--max-nodes=25000] [--max-ms=15000] [--require-unique]")
		quit(64)
		return
	var scenario := CatalogScript.get_scenario(scenario_id)
	if scenario.is_empty():
		printerr("Unknown deck-training scenario: %s" % scenario_id)
		quit(66)
		return
	var built := StateFactoryScript.build(scenario)
	if not (built.get("errors", []) as Array).is_empty():
		printerr("Scenario build failed: %s" % JSON.stringify(built.get("errors", [])))
		quit(65)
		return
	var gsm: GameStateMachine = built.get("gsm", null)
	if gsm == null:
		printerr("Scenario build returned no GameStateMachine")
		quit(65)
		return

	var has_witness := str(scenario.get("proof_contract_id", "")) != "" \
		or not (scenario.get("proof_steps", []) as Array).is_empty()
	var adapter: RefCounted = WitnessProofAdapterScript.new() \
		if has_witness \
		else EngineProofAdapterScript.new()
	adapter.configure(scenario)
	var certificate := ProofSolverScript.new().prove(
		adapter.make_initial_state(gsm),
		adapter,
		{
			"max_depth": int(options.get("max_depth", 24)),
			"max_nodes": int(options.get("max_nodes", 25000)),
			"max_milliseconds": int(options.get("max_milliseconds", 15000)),
			"require_unique_root": bool(options.get("require_unique", false)),
			"collect_all_player_branches": bool(options.get("require_unique", false)),
		}
	)
	var promotion := AdmissionVerifierScript.verify_for_solver_promotion(scenario, certificate)
	certificate["scenario_id"] = scenario_id
	certificate["promotion"] = promotion
	var output_path := str(options.get("output", "user://deck_training_proofs/%s.json" % scenario_id))
	var absolute_path := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write proof certificate: %s" % output_path)
		gsm.prepare_for_disposal()
		quit(73)
		return
	file.store_string(JSON.stringify(certificate, "  "))
	file.close()
	print("[DeckTrainingProof] %s status=%s nodes=%d promotion=%s output=%s" % [
		scenario_id,
		str(certificate.get("status", "")),
		int((certificate.get("metrics", {}) as Dictionary).get("nodes_visited", 0)),
		str(promotion.get("ok", false)),
		absolute_path,
	])
	gsm.prepare_for_disposal()
	quit(0 if bool(promotion.get("ok", false)) else 1)


func _parse_options(args: PackedStringArray) -> Dictionary:
	var options := {
		"scenario_id": "",
		"max_depth": 24,
		"max_nodes": 25000,
		"max_milliseconds": 15000,
		"require_unique": false,
		"output": "",
	}
	for raw: String in args:
		if raw.begins_with("--scenario-id="):
			options["scenario_id"] = raw.trim_prefix("--scenario-id=")
		elif raw.begins_with("--max-depth="):
			options["max_depth"] = int(raw.trim_prefix("--max-depth="))
		elif raw.begins_with("--max-nodes="):
			options["max_nodes"] = int(raw.trim_prefix("--max-nodes="))
		elif raw.begins_with("--max-ms="):
			options["max_milliseconds"] = int(raw.trim_prefix("--max-ms="))
		elif raw == "--require-unique":
			options["require_unique"] = true
		elif raw.begins_with("--output="):
			options["output"] = raw.trim_prefix("--output=")
	if str(options.get("output", "")) == "":
		options.erase("output")
	return options
