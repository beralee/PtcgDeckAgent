class_name DeckTrainingPuzzlePipeline
extends RefCounted


const CatalogScript := preload("res://scripts/training/DeckTrainingCatalog.gd")
const AdmissionVerifierScript := preload("res://scripts/training/DeckTrainingAdmissionVerifier.gd")
const StateFactoryScript := preload("res://scripts/training/DeckTrainingStateFactory.gd")
const LegalActionBuilderScript := preload("res://scripts/ai/AILegalActionBuilder.gd")
const StrategyRegistryScript := preload("res://scripts/ai/DeckStrategyRegistry.gd")
const ProofSolverScript := preload("res://scripts/training/proof/DeckTrainingProofSolver.gd")
const WitnessProofAdapterScript := preload("res://scripts/training/proof/DeckTrainingWitnessProofAdapter.gd")
const TacticScannerScript := preload("res://scripts/training/pipeline/DeckTrainingTacticScanner.gd")

const DEFAULT_TARGETS_PATH := "res://data/deck_training/pipeline_targets.json"
const DEFAULT_PROBES_PATH := "res://data/deck_training/shortcut_probes.json"
const GARDEVOIR_PROBES_OVERLAY_PATH := "res://data/deck_training/gardevoir_graph_shortcut_probes.json"
const N_ZOROARK_PROBES_OVERLAY_PATH := "res://data/deck_training/n_zoroark_shortcut_probes.json"
const CHARIZARD_DRAGAPULT_PROBES_OVERLAY_PATH := "res://data/deck_training/charizard_dragapult_shortcut_probes.json"
const DEFAULT_PROOF_DIR := "res://data/deck_training/proofs"
const DEFAULT_TACTICS_PATH := "res://data/deck_training/tactic_recipes.json"
const CANDIDATES_PER_DECK := 10

const STATUS_REJECTED_AUTHORING := "REJECTED_AUTHORING"
const STATUS_REJECTED_STATE := "REJECTED_STATE"
const STATUS_REJECTED_PLAYABILITY := "REJECTED_PLAYABILITY"
const STATUS_PLAYABLE := "PLAYABLE"
const STATUS_NEEDS_TACTIC_DESIGN := "NEEDS_TACTIC_DESIGN"
const STATUS_PROVEN := "PROVEN"
const STATUS_RELEASE_READY := "RELEASE_READY"


func run(options: Dictionary = {}) -> Dictionary:
	var targets_path := str(options.get("targets_path", DEFAULT_TARGETS_PATH))
	var probes_path := str(options.get("probes_path", DEFAULT_PROBES_PATH))
	var catalog_path := str(options.get("catalog_path", CatalogScript.CATALOG_PATH))
	var proof_dir := str(options.get("proof_dir", DEFAULT_PROOF_DIR)).trim_suffix("/")
	var tactics_path := str(options.get("tactics_path", DEFAULT_TACTICS_PATH))
	var selected_deck_key := str(options.get("deck_key", "")).strip_edges()
	var errors: Array[String] = []

	var targets_result := _load_json_dictionary(targets_path)
	var probes_result := _load_json_dictionary(probes_path)
	if not bool(targets_result.get("ok", false)):
		errors.append(str(targets_result.get("error", "invalid target manifest")))
	if not bool(probes_result.get("ok", false)):
		errors.append(str(probes_result.get("error", "invalid shortcut probe manifest")))
	var catalog := CatalogScript.load_catalog(catalog_path)
	for error: Variant in catalog.get("errors", []):
		errors.append("catalog: %s" % str(error))
	if not errors.is_empty():
		return _empty_report(errors)

	var targets: Dictionary = targets_result.get("data", {})
	var probe_catalog: Dictionary = probes_result.get("data", {})
	_merge_probe_overlay(probe_catalog, GARDEVOIR_PROBES_OVERLAY_PATH)
	_merge_probe_overlay(probe_catalog, N_ZOROARK_PROBES_OVERLAY_PATH)
	_merge_probe_overlay(probe_catalog, CHARIZARD_DRAGAPULT_PROBES_OVERLAY_PATH)
	var target_validation := validate_target_catalog(targets)
	for error: Variant in target_validation.get("errors", []):
		errors.append("targets: %s" % str(error))
	var probe_validation := validate_probe_catalog(probe_catalog)
	for error: Variant in probe_validation.get("errors", []):
		errors.append("shortcut probes: %s" % str(error))
	var tactic_scan := TacticScannerScript.new().scan(targets, tactics_path)
	for error: Variant in tactic_scan.get("errors", []):
		errors.append("tactics: %s" % str(error))
	var tactics_by_deck: Dictionary = {}
	for tactic_deck_variant: Variant in tactic_scan.get("decks", []):
		if tactic_deck_variant is Dictionary:
			var tactic_deck: Dictionary = tactic_deck_variant
			tactics_by_deck[str(tactic_deck.get("deck_key", ""))] = tactic_deck

	var scenarios: Array[Dictionary] = CatalogScript.list_scenarios(catalog_path)
	var target_results: Array[Dictionary] = []
	var candidate_results: Array[Dictionary] = []
	var configured_keys: Dictionary = {}
	for target_variant: Variant in targets.get("targets", []):
		if not (target_variant is Dictionary):
			errors.append("target entry must be a Dictionary")
			continue
		var target: Dictionary = target_variant
		var deck_key := str(target.get("deck_key", ""))
		if selected_deck_key != "" and deck_key != selected_deck_key:
			continue
		configured_keys[deck_key] = true
		var identity := _audit_target_identity(deck_key, target)
		var tactic_deck: Dictionary = tactics_by_deck.get(deck_key, {})
		identity["tactic_scan_ok"] = bool(tactic_deck.get("ok", false))
		identity["tactic_recipe_count"] = int(tactic_deck.get("recipe_count", 0))
		identity["tech_candidate_count"] = (tactic_deck.get("tech_candidates", []) as Array).size()
		if not bool(tactic_deck.get("ok", false)):
			(identity["errors"] as Array).append("tactic scan or recipe validation failed")
			identity["ok"] = false
		var deck_candidate_count := 0
		for scenario: Dictionary in scenarios:
			if str(scenario.get("deck_key", "")) != deck_key:
				continue
			deck_candidate_count += 1
			candidate_results.append(_audit_candidate(
				scenario,
				probe_catalog,
				proof_dir,
				maxi(1, int(targets.get("minimum_negative_probes", 2))),
				target,
				tactic_deck
			))
		identity["candidate_count"] = deck_candidate_count
		var expected_candidate_count := int(target.get("candidate_count", 0))
		if deck_candidate_count != expected_candidate_count:
			(identity["errors"] as Array).append(
				"catalog contains %d candidates instead of pinned %d" % [deck_candidate_count, expected_candidate_count]
			)
			identity["ok"] = false
		target_results.append(identity)
		if not bool(identity.get("ok", false)):
			for identity_error: Variant in identity.get("errors", []):
				errors.append("%s: %s" % [deck_key, str(identity_error)])

	if selected_deck_key != "" and not configured_keys.has(selected_deck_key):
		errors.append("unknown target deck_key: %s" % selected_deck_key)
	if selected_deck_key == "":
		for deck_key: String in CatalogScript.DECKS:
			if not configured_keys.has(deck_key):
				errors.append("target manifest is missing catalog deck_key: %s" % deck_key)

	var summary := _summarize(target_results, candidate_results)
	return {
		"format_version": 1,
		"pipeline": "deck_training_puzzle_pipeline_v1",
		"ok": errors.is_empty(),
		"errors": errors,
		"summary": summary,
		"targets": target_results,
		"tactics": tactic_scan,
		"candidates": candidate_results,
		"backlog": _build_backlog(targets, candidate_results, tactics_by_deck, selected_deck_key),
	}


func _merge_probe_overlay(catalog: Dictionary, overlay_path: String) -> void:
	if not FileAccess.file_exists(overlay_path):
		return
	var loaded := _load_json_dictionary(overlay_path)
	if not bool(loaded.get("ok", false)):
		return
	var overlay: Dictionary = loaded.get("data", {})
	var scenarios: Dictionary = catalog.get("scenarios", {})
	if not (scenarios is Dictionary):
		scenarios = {}
		catalog["scenarios"] = scenarios
	var overlay_scenarios: Variant = overlay.get("scenarios", {})
	if not (overlay_scenarios is Dictionary):
		return
	for scenario_id: Variant in overlay_scenarios:
		scenarios[str(scenario_id)] = (overlay_scenarios as Dictionary)[scenario_id]


func validate_target_catalog(catalog: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if int(catalog.get("format_version", 0)) != 1:
		errors.append("unsupported target catalog format")
	if int(catalog.get("minimum_player_actions", 0)) < 5:
		errors.append("minimum_player_actions must be at least 5")
	if int(catalog.get("minimum_negative_probes", 0)) < 2:
		errors.append("minimum_negative_probes must be at least 2")
	if int(catalog.get("minimum_tactic_patterns", 0)) < 3:
		errors.append("minimum_tactic_patterns must be at least 3")
	var targets_variant: Variant = catalog.get("targets", null)
	if not (targets_variant is Array):
		errors.append("targets must be an Array")
		return {"ok": false, "errors": errors}
	var seen: Dictionary = {}
	for target_variant: Variant in targets_variant:
		if not (target_variant is Dictionary):
			errors.append("target entry must be a Dictionary")
			continue
		var target: Dictionary = target_variant
		var deck_key := str(target.get("deck_key", "")).strip_edges()
		if deck_key == "":
			errors.append("target is missing deck_key")
		elif seen.has(deck_key):
			errors.append("duplicate target deck_key: %s" % deck_key)
		seen[deck_key] = true
		if int(target.get("deck_id", 0)) <= 0:
			errors.append("%s must pin a positive deck_id" % deck_key)
		if str(target.get("strategy_id", "")).strip_edges() == "":
			errors.append("%s must pin a production strategy_id" % deck_key)
		if int(target.get("candidate_count", 0)) <= 0:
			errors.append("%s must pin a positive candidate_count" % deck_key)
		var axes_variant: Variant = target.get("curriculum_axes", null)
		if not (axes_variant is Array) or (axes_variant as Array).size() != CANDIDATES_PER_DECK:
			errors.append("%s must define exactly %d curriculum axes" % [deck_key, CANDIDATES_PER_DECK])
		var tactic_dimension_variant: Variant = target.get("tactic_dimension", null)
		if not (tactic_dimension_variant is Dictionary):
			errors.append("%s must define a tactic_dimension" % deck_key)
		else:
			var tactic_dimension: Dictionary = tactic_dimension_variant
			if str(tactic_dimension.get("id", "")) != "tech_combo_application":
				errors.append("%s tactic_dimension must use tech_combo_application" % deck_key)
			var candidate_slots: Array = tactic_dimension.get("candidate_slots", [])
			if candidate_slots.size() < 2:
				errors.append("%s must reserve at least two tactic candidate slots" % deck_key)
			var seen_slots: Dictionary = {}
			for slot_variant: Variant in candidate_slots:
				var slot := int(slot_variant)
				if slot < 1 or slot > int(target.get("candidate_count", 0)):
					errors.append("%s tactic slot %d is outside candidate range" % [deck_key, slot])
				elif seen_slots.has(slot):
					errors.append("%s contains duplicate tactic slot %d" % [deck_key, slot])
				seen_slots[slot] = true
	return {"ok": errors.is_empty(), "errors": errors}


func validate_probe_catalog(catalog: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if int(catalog.get("format_version", 0)) != 1:
		errors.append("unsupported probe catalog format")
	var scenarios_variant: Variant = catalog.get("scenarios", null)
	if not (scenarios_variant is Dictionary):
		errors.append("scenarios must be a Dictionary")
		return {"ok": false, "errors": errors}
	for scenario_id_variant: Variant in (scenarios_variant as Dictionary).keys():
		var scenario_id := str(scenario_id_variant).strip_edges()
		var probes_variant: Variant = (scenarios_variant as Dictionary).get(scenario_id_variant)
		if scenario_id == "" or not (probes_variant is Array):
			errors.append("each scenario probe entry needs a non-empty id and Array")
			continue
		var seen: Dictionary = {}
		for probe_variant: Variant in probes_variant:
			if not (probe_variant is Dictionary):
				errors.append("%s contains a non-Dictionary probe" % scenario_id)
				continue
			var probe: Dictionary = probe_variant
			var probe_id := str(probe.get("id", "")).strip_edges()
			if probe_id == "":
				errors.append("%s contains a probe without id" % scenario_id)
			elif seen.has(probe_id):
				errors.append("%s contains duplicate probe id %s" % [scenario_id, probe_id])
			seen[probe_id] = true
			if str(probe.get("category", "")).strip_edges() == "":
				errors.append("%s/%s is missing category" % [scenario_id, probe_id])
			if str(probe.get("description", "")).strip_edges() == "":
				errors.append("%s/%s is missing description" % [scenario_id, probe_id])
			var has_step_overrides := probe.get("step_overrides", null) is Dictionary \
				and not (probe.get("step_overrides", {}) as Dictionary).is_empty()
			var has_replacement_steps := probe.get("proof_steps", null) is Array \
				and not (probe.get("proof_steps", []) as Array).is_empty()
			if not has_step_overrides and not has_replacement_steps:
				errors.append("%s/%s must override a witness step or provide a complete negative proof_steps route" % [scenario_id, probe_id])
	return {"ok": errors.is_empty(), "errors": errors}


func _audit_target_identity(deck_key: String, target: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var catalog_target_variant: Variant = CatalogScript.DECKS.get(deck_key, null)
	if not (catalog_target_variant is Dictionary):
		return {"deck_key": deck_key, "ok": false, "errors": ["not present in DeckTrainingCatalog.DECKS"]}
	var catalog_target: Dictionary = catalog_target_variant
	var deck_id := int(catalog_target.get("id", 0))
	if int(target.get("deck_id", 0)) != deck_id:
		errors.append("pinned deck_id %d does not match catalog deck_id %d" % [int(target.get("deck_id", 0)), deck_id])
	var deck_path := "res://data/bundled_user/decks/%d.json" % deck_id
	var deck_result := _load_json_dictionary(deck_path)
	var deck_total := 0
	if not bool(deck_result.get("ok", false)):
		errors.append(str(deck_result.get("error", "cannot load frozen deck")))
	else:
		deck_total = _deck_total(deck_result.get("data", {}))
		if deck_total != 60:
			errors.append("frozen deck contains %d cards instead of 60" % deck_total)
	var strategy_id := StrategyRegistryScript.strategy_id_for_deck_id(deck_id)
	if strategy_id == "":
		errors.append("production registry returned no strategy")
	elif str(target.get("strategy_id", "")) != strategy_id:
		errors.append("pinned strategy_id %s does not match production registry %s" % [str(target.get("strategy_id", "")), strategy_id])
	var curriculum_axes: Array = target.get("curriculum_axes", [])
	if curriculum_axes.size() != CANDIDATES_PER_DECK:
		errors.append("curriculum must define exactly %d deck-specific axes" % CANDIDATES_PER_DECK)
	return {
		"deck_key": deck_key,
		"deck_id": deck_id,
		"deck_name": str(catalog_target.get("name", deck_key)),
		"strategy_id": strategy_id,
		"deck_card_count": deck_total,
		"curriculum_axis_count": curriculum_axes.size(),
		"ok": errors.is_empty(),
		"errors": errors,
	}


func _audit_candidate(
	scenario: Dictionary,
	probe_catalog: Dictionary,
	proof_dir: String,
	minimum_negative_probes: int,
	target: Dictionary,
	tactic_deck: Dictionary
) -> Dictionary:
	var scenario_id := str(scenario.get("id", ""))
	var authoring := AdmissionVerifierScript.verify_scenario(scenario)
	var build := StateFactoryScript.build(scenario)
	var gsm: GameStateMachine = build.get("gsm", null)
	var state_compiled := gsm != null and (build.get("errors", []) as Array).is_empty()
	var legal_action_count := 0
	if state_compiled:
		legal_action_count = LegalActionBuilderScript.new().build_actions(gsm, 0, false).size()
	if gsm != null:
		gsm.prepare_for_disposal()

	var certificate_path := "%s/%s.json" % [proof_dir, scenario_id]
	var proof_result := {
		"available": FileAccess.file_exists(certificate_path),
		"ok": false,
		"errors": [],
		"path": certificate_path,
	}
	if bool(proof_result.get("available", false)):
		var certificate_load := _load_json_dictionary(certificate_path)
		if bool(certificate_load.get("ok", false)):
			var promotion := AdmissionVerifierScript.verify_for_solver_promotion(
				scenario,
				certificate_load.get("data", {})
			)
			proof_result["ok"] = bool(promotion.get("ok", false))
			proof_result["errors"] = (promotion.get("errors", []) as Array).duplicate()
		else:
			proof_result["errors"] = [str(certificate_load.get("error", "invalid proof certificate"))]

	var scenario_probes: Array = []
	var probe_scenarios: Dictionary = probe_catalog.get("scenarios", {})
	if probe_scenarios.has(scenario_id) and probe_scenarios[scenario_id] is Array:
		scenario_probes = (probe_scenarios[scenario_id] as Array).duplicate(true)
	var shortcut_results: Array[Dictionary] = []
	for probe_variant: Variant in scenario_probes:
		if probe_variant is Dictionary:
			shortcut_results.append(_run_negative_probe(scenario, probe_variant))
	var shortcuts_ok := shortcut_results.size() >= minimum_negative_probes
	for shortcut: Dictionary in shortcut_results:
		if not bool(shortcut.get("ok", false)):
			shortcuts_ok = false
	var tactic_dimension: Dictionary = target.get("tactic_dimension", {})
	var tactic_slots: Array = tactic_dimension.get("candidate_slots", [])
	var tactic_required := _int_array_contains(tactic_slots, int(scenario.get("order", 0)))
	var tactic_pattern_ids: Array = scenario.get("tactic_pattern_ids", [])
	var valid_recipe_ids: Dictionary = {}
	for recipe_variant: Variant in tactic_deck.get("recipes", []):
		if recipe_variant is Dictionary and bool((recipe_variant as Dictionary).get("ok", false)):
			valid_recipe_ids[str((recipe_variant as Dictionary).get("id", ""))] = true
	var tactic_errors: Array[String] = []
	if tactic_required and tactic_pattern_ids.is_empty():
		tactic_errors.append("reserved tactic candidate must declare tactic_pattern_ids")
	for tactic_id_variant: Variant in tactic_pattern_ids:
		var tactic_id := str(tactic_id_variant)
		if not valid_recipe_ids.has(tactic_id):
			tactic_errors.append("unknown or invalid tactic pattern: %s" % tactic_id)
	var tactic_coverage := not tactic_required or tactic_errors.is_empty()

	var status := STATUS_PLAYABLE
	if not bool(authoring.get("ok", false)):
		status = STATUS_REJECTED_AUTHORING
	elif not state_compiled:
		status = STATUS_REJECTED_STATE
	elif legal_action_count <= 0:
		status = STATUS_REJECTED_PLAYABILITY
	elif not tactic_coverage:
		status = STATUS_NEEDS_TACTIC_DESIGN
	elif bool(proof_result.get("ok", false)):
		status = STATUS_RELEASE_READY if shortcuts_ok else STATUS_PROVEN

	return {
		"scenario_id": scenario_id,
		"deck_key": str(scenario.get("deck_key", "")),
		"order": int(scenario.get("order", 0)),
		"title": str(scenario.get("title", "")),
		"status": status,
		"stages": {
			"author_contract": bool(authoring.get("ok", false)),
			"state_compiled": state_compiled,
			"production_opening_legal": legal_action_count > 0,
			"positive_proof": bool(proof_result.get("ok", false)),
			"shortcut_audit": shortcuts_ok,
			"tactic_coverage": tactic_coverage,
		},
		"tactic_required": tactic_required,
		"tactic_pattern_ids": tactic_pattern_ids.duplicate(),
		"tactic_errors": tactic_errors,
		"legal_action_count": legal_action_count,
		"authoring_errors": (authoring.get("errors", []) as Array).duplicate(),
		"state_errors": (build.get("errors", []) as Array).duplicate(),
		"proof": proof_result,
		"shortcut_probes": shortcut_results,
	}


func _run_negative_probe(scenario: Dictionary, probe: Dictionary) -> Dictionary:
	var result := {
		"id": str(probe.get("id", "")),
		"category": str(probe.get("category", "")),
		"description": str(probe.get("description", "")),
		"ok": false,
		"status": ProofSolverScript.STATUS_INCONCLUSIVE,
		"reason": "",
	}
	if str(scenario.get("proof_contract_id", "")) == "" \
		and (scenario.get("proof_steps", []) as Array).is_empty():
		result["reason"] = "scenario_has_no_production_witness_contract"
		return result
	var built := StateFactoryScript.build(scenario)
	var gsm: GameStateMachine = built.get("gsm", null)
	if gsm == null:
		result["reason"] = "negative_probe_state_build_failed:%s" % JSON.stringify(built.get("errors", []))
		return result
	var adapter_scenario := scenario.duplicate(true)
	if probe.get("proof_steps", null) is Array and not (probe.get("proof_steps", []) as Array).is_empty():
		adapter_scenario["proof_steps"] = (probe.get("proof_steps", []) as Array).duplicate(true)
		adapter_scenario.erase("proof_contract_id")
	var adapter := WitnessProofAdapterScript.new()
	adapter.configure(adapter_scenario, probe.get("step_overrides", {}))
	var certificate := ProofSolverScript.new().prove(
		adapter.make_initial_state(gsm),
		adapter,
		{
			"max_depth": 20,
			"max_nodes": 256,
			"max_milliseconds": 15000,
			"require_unique_root": false,
			"collect_all_player_branches": true,
		}
	)
	gsm.prepare_for_disposal()
	var status := str(certificate.get("status", ProofSolverScript.STATUS_INCONCLUSIVE))
	var invalid_reasons: Array[String] = []
	_collect_invalid_transition_reasons(certificate.get("proof_tree", {}), invalid_reasons)
	var metrics: Dictionary = certificate.get("metrics", {})
	var clean_refutation := status == ProofSolverScript.STATUS_REFUTED \
		and (certificate.get("unsupported_reasons", []) as Array).is_empty() \
		and str(metrics.get("budget_reason", "")) == "" \
		and invalid_reasons.is_empty()
	result["ok"] = clean_refutation
	result["status"] = status
	result["reason"] = str(certificate.get("reason", ""))
	result["invalid_transition_reasons"] = invalid_reasons
	result["nodes_visited"] = int(metrics.get("nodes_visited", 0))
	return result


func _collect_invalid_transition_reasons(node_variant: Variant, output: Array[String]) -> void:
	if not (node_variant is Dictionary):
		return
	var node: Dictionary = node_variant
	var reason := str(node.get("reason", ""))
	if ("production_action_rejected" in reason or "missing_witness" in reason) and reason not in output:
		output.append(reason)
	for branch_variant: Variant in node.get("branches", []):
		if not (branch_variant is Dictionary):
			continue
		var branch: Dictionary = branch_variant
		var branch_reason := str(branch.get("reason", ""))
		if ("production_action_rejected" in branch_reason or "missing_witness" in branch_reason) \
				and branch_reason not in output:
			output.append(branch_reason)
		_collect_invalid_transition_reasons(branch.get("tree", {}), output)


func _build_backlog(
	targets: Dictionary,
	candidates: Array[Dictionary],
	tactics_by_deck: Dictionary,
	selected_deck_key: String
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var candidates_by_deck: Dictionary = {}
	for candidate: Dictionary in candidates:
		var deck_key := str(candidate.get("deck_key", ""))
		if not candidates_by_deck.has(deck_key):
			candidates_by_deck[deck_key] = []
		(candidates_by_deck[deck_key] as Array).append(candidate)
	for target_variant: Variant in targets.get("targets", []):
		if not (target_variant is Dictionary):
			continue
		var target: Dictionary = target_variant
		var deck_key := str(target.get("deck_key", ""))
		if selected_deck_key != "" and deck_key != selected_deck_key:
			continue
		var axes: Array = target.get("curriculum_axes", [])
		var tactic_dimension: Dictionary = target.get("tactic_dimension", {})
		var tactic_slots: Array = tactic_dimension.get("candidate_slots", [])
		var tactic_deck: Dictionary = tactics_by_deck.get(deck_key, {})
		var tactic_recipes: Array = tactic_deck.get("recipes", [])
		var deck_candidates: Array = candidates_by_deck.get(deck_key, [])
		deck_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("order", 0)) < int(b.get("order", 0))
		)
		for candidate_variant: Variant in deck_candidates:
			var candidate: Dictionary = candidate_variant
			var order := maxi(1, int(candidate.get("order", 1)))
			var axis: Dictionary = axes[(order - 1) % axes.size()] if not axes.is_empty() else {}
			var tactic_required := _int_array_contains(tactic_slots, order)
			var suggested_tactic_ids: Array[String] = []
			if tactic_required:
				var tactic_slot_index := _int_array_find(tactic_slots, order)
				for recipe_index: int in tactic_recipes.size():
					if recipe_index % tactic_slots.size() != tactic_slot_index:
						continue
					var recipe_variant: Variant = tactic_recipes[recipe_index]
					if recipe_variant is Dictionary and bool((recipe_variant as Dictionary).get("ok", false)):
						suggested_tactic_ids.append(str((recipe_variant as Dictionary).get("id", "")))
			var next_gate := _next_gate(str(candidate.get("status", STATUS_PLAYABLE)))
			if tactic_required and not bool((candidate.get("stages", {}) as Dictionary).get("tactic_coverage", false)):
				next_gate = "encode_and_prove_verified_tactic_application"
			result.append({
				"scenario_id": str(candidate.get("scenario_id", "")),
				"deck_key": deck_key,
				"order": order,
				"curriculum_axis_id": str(axis.get("id", "")),
				"curriculum_axis_name": str(axis.get("name", "")),
				"current_status": str(candidate.get("status", STATUS_PLAYABLE)),
				"next_gate": next_gate,
				"tactic_required": tactic_required,
				"tactic_dimension_id": str(tactic_dimension.get("id", "")) if tactic_required else "",
				"tactic_dimension_name": str(tactic_dimension.get("name", "")) if tactic_required else "",
				"suggested_tactic_ids": suggested_tactic_ids,
				"encoded_tactic_pattern_ids": (candidate.get("tactic_pattern_ids", []) as Array).duplicate(),
			})
	return result


func _next_gate(status: String) -> String:
	match status:
		STATUS_RELEASE_READY:
			return "published_candidate"
		STATUS_PROVEN:
			return "add_two_clean_negative_shortcut_probes"
		STATUS_PLAYABLE:
			return "generate_and_validate_positive_proof"
		STATUS_NEEDS_TACTIC_DESIGN:
			return "encode_and_prove_verified_tactic_application"
		_:
			return "repair_previous_failed_stage"


func _int_array_contains(values: Array, wanted: int) -> bool:
	return _int_array_find(values, wanted) >= 0


func _int_array_find(values: Array, wanted: int) -> int:
	var index := 0
	for value_variant: Variant in values:
		if int(value_variant) == wanted:
			return index
		index += 1
	return -1


func _summarize(targets: Array[Dictionary], candidates: Array[Dictionary]) -> Dictionary:
	var summary := {
		"target_count": targets.size(),
		"identity_passed": 0,
		"tactic_targets_passed": 0,
		"tactic_recipe_count": 0,
		"tech_candidate_count": 0,
		"candidate_count": candidates.size(),
		"compiled": 0,
		"playable": 0,
		"proven": 0,
		"shortcut_audited": 0,
		"release_ready": 0,
	}
	for target: Dictionary in targets:
		if bool(target.get("ok", false)):
			summary["identity_passed"] = int(summary["identity_passed"]) + 1
		if bool(target.get("tactic_scan_ok", false)):
			summary["tactic_targets_passed"] = int(summary["tactic_targets_passed"]) + 1
		summary["tactic_recipe_count"] = int(summary["tactic_recipe_count"]) + int(target.get("tactic_recipe_count", 0))
		summary["tech_candidate_count"] = int(summary["tech_candidate_count"]) + int(target.get("tech_candidate_count", 0))
	for candidate: Dictionary in candidates:
		var stages: Dictionary = candidate.get("stages", {})
		if bool(stages.get("state_compiled", false)):
			summary["compiled"] = int(summary["compiled"]) + 1
		if bool(stages.get("production_opening_legal", false)):
			summary["playable"] = int(summary["playable"]) + 1
		if bool(stages.get("positive_proof", false)):
			summary["proven"] = int(summary["proven"]) + 1
		if bool(stages.get("shortcut_audit", false)):
			summary["shortcut_audited"] = int(summary["shortcut_audited"]) + 1
		if str(candidate.get("status", "")) == STATUS_RELEASE_READY:
			summary["release_ready"] = int(summary["release_ready"]) + 1
	return summary


func _deck_total(deck: Dictionary) -> int:
	var total := 0
	for card_variant: Variant in deck.get("cards", []):
		if card_variant is Dictionary:
			total += int((card_variant as Dictionary).get("count", 0))
	return total


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "missing JSON: %s" % path, "data": {}}
	var json := JSON.new()
	var parse_error := json.parse(FileAccess.get_file_as_string(path))
	if parse_error != OK or not (json.data is Dictionary):
		return {"ok": false, "error": "invalid JSON %s: %s" % [path, json.get_error_message()], "data": {}}
	return {"ok": true, "error": "", "data": (json.data as Dictionary).duplicate(true)}


func _empty_report(errors: Array[String]) -> Dictionary:
	return {
		"format_version": 1,
		"pipeline": "deck_training_puzzle_pipeline_v1",
		"ok": false,
		"errors": errors,
		"summary": {},
		"targets": [],
		"tactics": {},
		"candidates": [],
		"backlog": [],
	}
