class_name AIIntentPlannerCoordinator
extends RefCounted

const AttackPlannerScript = preload("res://scripts/ai/intent/AIIntentAttackPlanner.gd")
const EnergyPlannerScript = preload("res://scripts/ai/intent/AIIntentEnergyPlanner.gd")
const EvolutionPlannerScript = preload("res://scripts/ai/intent/AIIntentEvolutionPlanner.gd")

var _attack_planner: RefCounted = AttackPlannerScript.new()
var _energy_planner: RefCounted = EnergyPlannerScript.new()
var _evolution_planner: RefCounted = EvolutionPlannerScript.new()


func build_facts(
	game_state: GameState,
	player_index: int,
	legal_action_refs: Array,
	profile: Dictionary = {}
) -> Dictionary:
	var profile_copy: Dictionary = profile.duplicate(true) if profile is Dictionary else {}
	var refs: Array = legal_action_refs.duplicate(true)
	var attack_intents: Array[Dictionary] = _attack_planner.call("build_attack_intents", game_state, player_index, refs, profile_copy)
	var evolution_intents: Array[Dictionary] = _evolution_planner.call("build_evolution_intents", game_state, player_index, refs, profile_copy)
	var energy_intents: Array[Dictionary] = _energy_planner.call("build_energy_intents", game_state, player_index, refs, attack_intents, evolution_intents, profile_copy)
	var line_status: Array[Dictionary] = _evolution_planner.call("build_line_status", game_state, player_index, profile_copy)
	var facts := {
		"schema": "ai_intent_facts_v1",
		"attack_intents": attack_intents,
		"energy_intents": energy_intents,
		"evolution_intents": evolution_intents,
		"evolution_line_status": line_status,
		"route_hints": _route_hints(attack_intents, energy_intents, evolution_intents, line_status),
		"hard_blocks": _hard_blocks(attack_intents, energy_intents),
		"soft_penalties": _soft_penalties(energy_intents, evolution_intents),
		"audit": {
			"attack_intent_count": attack_intents.size(),
			"energy_intent_count": energy_intents.size(),
			"evolution_intent_count": evolution_intents.size(),
			"profile_keys": profile_copy.keys(),
		},
	}
	return facts


func _hard_blocks(attack_intents: Array[Dictionary], energy_intents: Array[Dictionary]) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for attack: Dictionary in attack_intents:
		var action_id := str(attack.get("action_id", ""))
		if action_id == "":
			continue
		if bool(attack.get("blocked_by_better_attack", false)):
			blocks.append({
				"action_id": action_id,
				"type": "attack_blocked_by_better_ready_attack",
				"reason": str(attack.get("reason", "")),
			})
	for energy: Dictionary in energy_intents:
		var action_id := str(energy.get("action_id", ""))
		if action_id == "":
			continue
		if bool(energy.get("is_support_padding", false)) and str(energy.get("target_position", "")) != "active":
			blocks.append({
				"action_id": action_id,
				"type": "support_bench_energy_padding",
				"reason": str(energy.get("reason", "")),
			})
	return blocks


func _soft_penalties(
	energy_intents: Array[Dictionary],
	evolution_intents: Array[Dictionary]
) -> Array[Dictionary]:
	var penalties: Array[Dictionary] = []
	for energy: Dictionary in energy_intents:
		var action_id := str(energy.get("action_id", ""))
		if action_id == "":
			continue
		if bool(energy.get("is_wrong_attribute", false)):
			penalties.append({
				"action_id": action_id,
				"type": "wrong_energy_attribute",
				"reason": str(energy.get("reason", "")),
			})
		elif bool(energy.get("is_overfill", false)):
			penalties.append({
				"action_id": action_id,
				"type": "energy_overfill",
				"reason": str(energy.get("reason", "")),
			})
	for evolution: Dictionary in evolution_intents:
		if str(evolution.get("priority", "")) == "high":
			continue
	return penalties


func _route_hints(
	attack_intents: Array[Dictionary],
	energy_intents: Array[Dictionary],
	evolution_intents: Array[Dictionary],
	line_status: Array[Dictionary]
) -> Array[Dictionary]:
	var hints: Array[Dictionary] = []
	var best_attack := _best_attack_intent(attack_intents)
	if not best_attack.is_empty():
		hints.append({
			"type": "best_attack",
			"action_id": str(best_attack.get("action_id", "")),
			"attack_name": str(best_attack.get("attack_name", "")),
			"role": str(best_attack.get("role", "")),
			"priority": str(best_attack.get("terminal_priority", "")),
			"reason": str(best_attack.get("reason", "")),
		})
	var best_attach := _best_energy_intent(energy_intents)
	if not best_attach.is_empty():
		hints.append({
			"type": "best_manual_attach",
			"action_id": str(best_attach.get("action_id", "")),
			"target": str(best_attach.get("target_name", "")),
			"target_position": str(best_attach.get("target_position", "")),
			"target_role": str(best_attach.get("target_role", "")),
			"energy": str(best_attach.get("energy_name", "")),
			"energy_symbol": str(best_attach.get("energy_symbol", "")),
			"marginal_value": str(best_attach.get("marginal_value", "")),
			"reason": str(best_attach.get("reason", "")),
		})
	for evolution: Dictionary in evolution_intents:
		if str(evolution.get("priority", "")) == "high":
			hints.append({
				"type": "high_priority_evolution",
				"action_id": str(evolution.get("action_id", "")),
				"to": str(evolution.get("to", "")),
				"reason": str(evolution.get("reason", "")),
			})
	for line: Dictionary in line_status:
		if bool(line.get("needs_backup_seed", false)):
			hints.append({
				"type": "needs_backup_evolution_seed",
				"line": str(line.get("line", "")),
				"desired_count": int(line.get("desired_count", 0)),
			})
	return hints


func _best_attack_intent(intents: Array[Dictionary]) -> Dictionary:
	var best := {}
	var best_score := -999999
	for intent: Dictionary in intents:
		if not bool(intent.get("ready_now", false)):
			continue
		var score := int(intent.get("estimated_damage", 0))
		match str(intent.get("terminal_priority", "")):
			"high":
				score += 500
			"medium":
				score += 200
			"low":
				score -= 100
		if bool(intent.get("ko_active", false)):
			score += 300
		if score > best_score:
			best_score = score
			best = intent
	return best


func _best_energy_intent(intents: Array[Dictionary]) -> Dictionary:
	var best := {}
	var best_score := -999999
	for intent: Dictionary in intents:
		var score := 0
		match str(intent.get("marginal_value", "")):
			"high":
				score = 300
			"medium":
				score = 100
			"low":
				score = -100
		if score > best_score:
			best_score = score
			best = intent
	return best
