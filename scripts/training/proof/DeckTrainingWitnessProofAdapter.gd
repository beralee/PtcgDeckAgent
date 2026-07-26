class_name DeckTrainingWitnessProofAdapter
extends RefCounted


const AIOpponentScript := preload("res://scripts/ai/AIOpponent.gd")
const GameStateClonerScript := preload("res://scripts/ai/GameStateCloner.gd")
const GoalEvaluatorScript := preload("res://scripts/training/DeckTrainingGoalEvaluator.gd")
const HeadlessMatchBridgeScript := preload("res://scripts/ai/HeadlessMatchBridge.gd")
const ProofCertificateScript := preload("res://scripts/training/proof/DeckTrainingProofCertificate.gd")
const ScenarioStateSnapshotScript := preload("res://scripts/engine/scenario/ScenarioStateSnapshot.gd")

const ROLE_PLAYER := "player"
const ROLE_OPPONENT := "opponent"
const ROLE_TERMINAL := "terminal"

var _scenario: Dictionary = {}
var _steps: Array[Dictionary] = []
var _cloner := GameStateClonerScript.new()


func configure(scenario: Dictionary, step_overrides: Dictionary = {}) -> void:
	_scenario = scenario.duplicate(true)
	_steps = _scenario_steps(_scenario)
	_apply_step_overrides(step_overrides)


func _apply_step_overrides(step_overrides: Dictionary) -> void:
	if step_overrides.is_empty():
		return
	for step_index: int in _steps.size():
		var step: Dictionary = _steps[step_index]
		var step_id := str(step.get("id", ""))
		var override_variant: Variant = step_overrides.get(step_id, null)
		if override_variant is Dictionary:
			_steps[step_index] = step.merged((override_variant as Dictionary).duplicate(true), true)


func provider_name() -> String:
	return "production_rules_ai_witness_v2"


func scenario_fingerprint() -> String:
	return ProofCertificateScript.scenario_fingerprint(_scenario)


func make_initial_state(gsm: GameStateMachine) -> Dictionary:
	if gsm == null or gsm.game_state == null:
		return {}
	var initial_prizes: Array[int] = []
	for player: PlayerState in gsm.game_state.players:
		initial_prizes.append(player.prizes.size())
	return {
		"gsm": _cloner.clone_gsm(gsm),
		"step_index": 0,
		"initial_prize_counts": initial_prizes,
		"target_instance_ids": _capture_target_instance_ids(gsm.game_state),
	}


func clone_state(state: Variant) -> Variant:
	if not (state is Dictionary):
		return {}
	var source: Dictionary = state
	var cloned := source.duplicate(true)
	var gsm: GameStateMachine = source.get("gsm", null)
	cloned["gsm"] = _cloner.clone_gsm(gsm) if gsm != null else null
	return cloned


func state_key(state: Variant) -> String:
	if not (state is Dictionary):
		return ""
	var data: Dictionary = state
	var gsm: GameStateMachine = data.get("gsm", null)
	if gsm == null or gsm.game_state == null:
		return ""
	return JSON.stringify(ProofCertificateScript._canonicalize({
		"step_index": int(data.get("step_index", 0)),
		"state": ScenarioStateSnapshotScript.capture(gsm.game_state),
	})).sha256_text()


func node_role(state: Variant) -> String:
	if not (state is Dictionary) or bool(terminal_result(state).get("terminal", false)):
		return ROLE_TERMINAL
	var step_index := int((state as Dictionary).get("step_index", 0))
	if step_index < 0 or step_index >= _steps.size():
		return ROLE_TERMINAL
	return ROLE_OPPONENT if str(_steps[step_index].get("kind", "")) == "fixed_rules_ai_turn" else ROLE_PLAYER


func terminal_result(state: Variant) -> Dictionary:
	if not (state is Dictionary):
		return {"terminal": true, "success": false, "reason": "invalid_witness_state"}
	var data: Dictionary = state
	var gsm: GameStateMachine = data.get("gsm", null)
	if gsm == null or gsm.game_state == null:
		return {"terminal": true, "success": false, "reason": "missing_game_state_machine"}
	var context := {
		"initial_prize_counts": data.get("initial_prize_counts", []),
		"target_knockouts": _count_target_knockouts(gsm.game_state, data.get("target_instance_ids", [])),
	}
	var goal: Dictionary = _scenario.get("goal", {})
	if gsm.game_state.is_game_over() and gsm.game_state.winner_index != 0:
		return {
			"terminal": true,
			"success": false,
			"reason": "opponent_won_before_witness_goal:%s" % gsm.game_state.win_reason,
			"score": GoalEvaluatorScript.progress(goal, gsm.game_state, context),
		}
	if GoalEvaluatorScript.is_satisfied(goal, gsm.game_state, context):
		return {
			"terminal": true,
			"success": true,
			"reason": "production_witness_reached_goal",
			"score": GoalEvaluatorScript.progress(goal, gsm.game_state, context),
		}
	if int(data.get("step_index", 0)) >= _steps.size():
		return {
			"terminal": true,
			"success": false,
			"reason": "production_witness_exhausted_before_goal:%s:%s" % [
				JSON.stringify(GoalEvaluatorScript.failure_reasons(goal, gsm.game_state, context)),
				_public_board_summary(gsm.game_state),
			],
			"score": GoalEvaluatorScript.progress(goal, gsm.game_state, context),
		}
	if gsm.game_state.is_game_over():
		return {"terminal": true, "success": false, "reason": "player_won_without_witness_goal"}
	return {"terminal": false}


func _public_board_summary(state: GameState) -> String:
	var parts: Array[String] = []
	for player_index: int in state.players.size():
		var player: PlayerState = state.players[player_index]
		if player.active_pokemon != null:
			parts.append(_slot_public_summary(player.active_pokemon, player_index, "active"))
		for bench_index: int in player.bench.size():
			var slot: PokemonSlot = player.bench[bench_index]
			parts.append(_slot_public_summary(slot, player_index, "b%d" % bench_index))
		parts.append("p%d-discard-%d" % [player_index, player.discard_pile.size()])
	return ",".join(parts)


func _slot_public_summary(slot: PokemonSlot, player_index: int, zone: String) -> String:
	var energy_ids: Array[String] = []
	for energy: CardInstance in slot.attached_energy:
		if energy != null and energy.card_data != null:
			energy_ids.append(energy.card_data.get_uid())
	var tool_id := ""
	if slot.attached_tool != null and slot.attached_tool.card_data != null:
		tool_id = slot.attached_tool.card_data.get_uid()
	return "p%d-%s-%s-%d-e[%s]-t[%s]" % [
		player_index,
		zone,
		slot.get_pokemon_name(),
		slot.get_remaining_hp(),
		"+".join(energy_ids),
		tool_id,
	]


func legal_choices(state: Variant) -> Dictionary:
	if not (state is Dictionary):
		return {"complete": false, "reason": "invalid_witness_state", "choices": []}
	var step_index := int((state as Dictionary).get("step_index", 0))
	if step_index < 0 or step_index >= _steps.size():
		return {"complete": true, "choices": []}
	var step: Dictionary = _steps[step_index]
	var kind := str(step.get("kind", ""))
	return {
		"complete": true,
		"choices": [{
			"id": "%02d:%s" % [step_index, str(step.get("id", kind))],
			"label": str(step.get("label", kind)),
			"step": step.duplicate(true),
			"supported": true,
			"player_action_cost": 0 if kind in ["end_turn", "fixed_rules_ai_turn"] else 1,
		}],
	}


func apply_choice(state: Variant, choice: Dictionary) -> Dictionary:
	if not (state is Dictionary):
		return {"ok": false, "complete": false, "reason": "invalid_witness_state"}
	var data: Dictionary = state
	var gsm: GameStateMachine = data.get("gsm", null)
	var step_variant: Variant = choice.get("step", null)
	if gsm == null or gsm.game_state == null or not (step_variant is Dictionary):
		return {"ok": false, "complete": false, "reason": "missing_witness_transition_data"}
	var step: Dictionary = step_variant
	var result := _execute_step(gsm, step)
	if not bool(result.get("ok", false)):
		return {
			"ok": false,
			"complete": true,
			"reason": "%s:%s" % [
				str(result.get("reason", "witness_action_rejected")),
				_public_board_summary(gsm.game_state),
			],
		}
	data["step_index"] = int(data.get("step_index", 0)) + 1
	return {"ok": true, "complete": true, "state": data}


func _execute_step(gsm: GameStateMachine, step: Dictionary) -> Dictionary:
	var kind := str(step.get("kind", ""))
	var player: PlayerState = gsm.game_state.players[0]
	match kind:
		"play_basic_to_bench":
			var basic := _find_hand_card(player, str(step.get("card_uid", "")))
			return _action_result(
				basic != null and gsm.play_basic_to_bench(
					0,
					basic,
					bool(step.get("auto_trigger_bench_ability", true))
				),
				kind
			)
		"evolve":
			var evolve_card := _find_hand_card(player, str(step.get("card_uid", "")))
			var evolve_target := _resolve_slot(player, step.get("target", {}))
			return _action_result(evolve_card != null and evolve_target != null and gsm.evolve_pokemon(0, evolve_card, evolve_target), kind)
		"attach_energy":
			var energy := _find_hand_card(player, str(step.get("card_uid", "")))
			var energy_target := _resolve_slot(player, step.get("target", {}))
			return _action_result(energy != null and energy_target != null and gsm.attach_energy(0, energy, energy_target), kind)
		"attach_tool":
			var tool := _find_hand_card(player, str(step.get("card_uid", "")))
			var tool_target := _resolve_slot(player, step.get("target", {}))
			return _action_result(tool != null and tool_target != null and gsm.attach_tool(0, tool, tool_target), kind)
		"use_ability":
			return _execute_ability(gsm, step)
		"munkidori":
			return _execute_munkidori(gsm, step)
		"self_ko":
			return _execute_self_ko(gsm, step)
		"play_trainer":
			return _execute_trainer(gsm, step)
		"play_stadium":
			return _execute_stadium(gsm, step)
		"use_stadium":
			return _execute_stadium_action(gsm, step)
		"retreat":
			return _execute_retreat(gsm, step)
		"attack":
			return _execute_attack(gsm, step)
		"opponent_attack":
			return _execute_attack(gsm, step, 1)
		"granted_attack":
			return _execute_granted_attack(gsm, step)
		"end_turn":
			gsm.end_turn(0)
			return _action_result(gsm.game_state.current_player_index == 1, kind)
		"fixed_rules_ai_turn":
			return _run_fixed_rules_ai_turn(gsm, step)
	return {"ok": false, "reason": "unsupported_witness_step:%s" % kind}


func _execute_ability(gsm: GameStateMachine, step: Dictionary) -> Dictionary:
	var source := _resolve_slot(
		gsm.game_state.players[int(step.get("source_player", 0))],
		step.get("source", step.get("ability_source", {}))
	)
	if source == null:
		return _action_result(false, "use_ability_source")
	var targets_variant: Variant = _resolve_value(gsm, step.get("targets", []))
	if not (targets_variant is Array):
		return _action_result(false, "use_ability_targets")
	return _action_result(
		gsm.use_ability(0, source, int(step.get("ability_index", 0)), targets_variant),
		"use_ability"
	)


func _execute_munkidori(gsm: GameStateMachine, step: Dictionary) -> Dictionary:
	var player: PlayerState = gsm.game_state.players[0]
	var source_slot := _resolve_slot(player, step.get("ability_source", {}))
	var damage_source := _most_damaged_live_slot(player)
	var target := _resolve_slot(gsm.game_state.players[1], step.get("damage_target", {}))
	var amount := int(step.get("amount", 30))
	var targets := [{
		"source_pokemon": [damage_source],
		"target_damage_counters": [{"target": target, "amount": amount}],
	}]
	if source_slot == null or damage_source == null or target == null:
		return _action_result(false, "munkidori")
	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	if not gsm.use_ability(0, source_slot, 0, targets):
		bridge.bind(null)
		bridge.free()
		return _action_result(false, "munkidori")
	var resolved := _resolve_bound_bridge_prompts(bridge)
	bridge.bind(null)
	bridge.free()
	return resolved


func _execute_self_ko(gsm: GameStateMachine, step: Dictionary) -> Dictionary:
	var source := _resolve_slot(gsm.game_state.players[0], step.get("ability_source", {}))
	var target := _resolve_slot(gsm.game_state.players[1], step.get("damage_target", {}))
	if source == null or target == null:
		return _action_result(false, "self_ko")
	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	if not gsm.use_ability(0, source, 0, [{"self_ko_target": [target]}]):
		bridge.bind(null)
		bridge.free()
		return _action_result(false, "self_ko")
	var resolved := _resolve_bound_bridge_prompts(bridge)
	bridge.bind(null)
	bridge.free()
	return resolved


func _execute_trainer(gsm: GameStateMachine, step: Dictionary) -> Dictionary:
	var player: PlayerState = gsm.game_state.players[0]
	var card := _find_hand_card(player, str(step.get("card_uid", "")))
	if card == null:
		return _action_result(false, "play_trainer")
	if step.has("targets"):
		var targets_variant: Variant = _resolve_value(gsm, step.get("targets", []))
		if not (targets_variant is Array):
			return _action_result(false, "play_trainer_targets")
		return _action_result(gsm.play_trainer(0, card, targets_variant), "play_trainer")
	var target_player_index := int(step.get("target_player", 0))
	var target := _resolve_slot(gsm.game_state.players[target_player_index], step.get("target", {}))
	var context_key := str(step.get("context_key", ""))
	if target == null or context_key == "":
		return _action_result(false, "play_trainer")
	return _action_result(gsm.play_trainer(0, card, [{context_key: [target]}]), "play_trainer")


func _execute_stadium(gsm: GameStateMachine, step: Dictionary) -> Dictionary:
	var card := _find_hand_card(gsm.game_state.players[0], str(step.get("card_uid", "")))
	var targets_variant: Variant = _resolve_value(gsm, step.get("targets", []))
	if card == null or not (targets_variant is Array):
		return _action_result(false, "play_stadium")
	return _action_result(gsm.play_stadium(0, card, targets_variant), "play_stadium")


func _execute_stadium_action(gsm: GameStateMachine, step: Dictionary) -> Dictionary:
	var targets_variant: Variant = _resolve_value(gsm, step.get("targets", []))
	if not (targets_variant is Array):
		return _action_result(false, "use_stadium")
	return _action_result(gsm.use_stadium_effect(0, targets_variant), "use_stadium")


func _execute_retreat(gsm: GameStateMachine, step: Dictionary) -> Dictionary:
	var player: PlayerState = gsm.game_state.players[0]
	var target := _resolve_slot(player, step.get("target", {}))
	var energy_variant: Variant = _resolve_value(gsm, step.get("energy_to_discard", []))
	if target == null or not (energy_variant is Array):
		return _action_result(false, "retreat")
	var energy: Array[CardInstance] = []
	for card_variant: Variant in energy_variant:
		if card_variant is CardInstance:
			energy.append(card_variant)
	return _action_result(gsm.retreat(0, energy, target), "retreat")


func _execute_attack(gsm: GameStateMachine, step: Dictionary, player_index: int = 0) -> Dictionary:
	var direct_targets: Variant = null
	if step.has("targets"):
		direct_targets = _resolve_value(gsm, step.get("targets", []))
		if not (direct_targets is Array):
			return _action_result(false, "attack_targets")
	var assignments: Array[Dictionary] = []
	if direct_targets == null:
		for assignment_variant: Variant in step.get("bench_assignments", []):
			if not (assignment_variant is Dictionary):
				continue
			var assignment: Dictionary = assignment_variant
			var target := _resolve_slot(gsm.game_state.players[1 - player_index], assignment.get("target", {}))
			if target == null:
				return _action_result(false, "attack_target")
			assignments.append({"target": target, "amount": int(assignment.get("amount", 0))})
	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	var attack_targets: Array = direct_targets \
		if direct_targets is Array \
		else [{"bench_damage_counters": assignments}]
	var attacked := gsm.use_attack(player_index, int(step.get("attack_index", 1)), attack_targets)
	if not attacked:
		bridge.bind(null)
		bridge.free()
		return _action_result(false, "attack")
	var resolved := _resolve_bound_bridge_prompts(bridge)
	bridge.bind(null)
	bridge.free()
	return resolved


func _execute_granted_attack(gsm: GameStateMachine, step: Dictionary) -> Dictionary:
	var player: PlayerState = gsm.game_state.players[0]
	var source := _resolve_slot(player, step.get("source", {"zone": "active"}))
	if source == null:
		return _action_result(false, "granted_attack_source")
	var granted_attacks: Array[Dictionary] = gsm.effect_processor.get_granted_attacks(
		source,
		gsm.game_state
	)
	var granted_index := int(step.get("granted_attack_index", 0))
	if granted_index < 0 or granted_index >= granted_attacks.size():
		return _action_result(false, "granted_attack_index")
	var targets_variant: Variant = _resolve_value(gsm, step.get("targets", []))
	if not (targets_variant is Array):
		return _action_result(false, "granted_attack_targets")
	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	var attacked := gsm.use_granted_attack(
		0,
		source,
		granted_attacks[granted_index],
		targets_variant
	)
	if not attacked:
		bridge.bind(null)
		bridge.free()
		return _action_result(false, "granted_attack")
	var resolved := _resolve_bound_bridge_prompts(bridge)
	bridge.bind(null)
	bridge.free()
	return resolved


func _run_fixed_rules_ai_turn(gsm: GameStateMachine, step: Dictionary) -> Dictionary:
	if gsm.game_state.current_player_index != 1:
		return _action_result(false, "fixed_rules_ai_turn_wrong_owner")
	var action_log_start := gsm.action_log.size()
	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	var ai := AIOpponentScript.new()
	ai.configure(1, 3)
	ai.decision_runtime_mode = "rules_only"
	bridge.set_ai_controllers(null, ai)
	for _step_index: int in 80:
		if gsm.game_state.current_player_index != 1 or gsm.game_state.is_game_over():
			break
		if bridge.has_pending_prompt() and bridge.can_auto_resolve_pending_prompt():
			if not bridge.resolve_pending_prompt():
				bridge.bind(null)
				bridge.free()
				return _action_result(false, "fixed_rules_ai_prompt_rejected")
			continue
		if not ai.run_single_step(bridge, gsm):
			bridge.bind(null)
			bridge.free()
			return _action_result(false, "fixed_rules_ai_stalled:%s" % bridge.get_pending_prompt_type())
	var returned_to_player := gsm.game_state.current_player_index == 0
	var opponent_attacked := false
	for action_index: int in range(action_log_start, gsm.action_log.size()):
		var action_variant: Variant = gsm.action_log[action_index]
		if action_variant is GameAction \
				and (action_variant as GameAction).action_type == GameAction.ActionType.ATTACK \
				and (action_variant as GameAction).player_index == 1:
			opponent_attacked = true
			break
	bridge.bind(null)
	bridge.free()
	if bool(step.get("require_attack", false)) and not opponent_attacked:
		return _action_result(false, "fixed_rules_ai_turn_missing_attack")
	return _action_result(returned_to_player, "fixed_rules_ai_turn")


func _resolve_bound_bridge_prompts(bridge: HeadlessMatchBridge) -> Dictionary:
	for _index: int in 16:
		if not bridge.has_pending_prompt():
			return _action_result(true, "resolve_prompts")
		if not bridge.can_auto_resolve_pending_prompt() or not bridge.resolve_pending_prompt():
			var prompt := bridge.get_pending_prompt_type()
			return _action_result(false, "unresolved_production_prompt:%s" % prompt)
	return _action_result(false, "production_prompt_loop_exhausted")


func _resolve_slot(player: PlayerState, selector_variant: Variant) -> PokemonSlot:
	if not (selector_variant is Dictionary):
		return null
	var selector: Dictionary = selector_variant
	var zone := str(selector.get("zone", "active"))
	if zone == "active":
		return player.active_pokemon
	if zone == "bench":
		var index := int(selector.get("index", -1))
		return player.bench[index] if index >= 0 and index < player.bench.size() else null
	if zone in ["bench_uid", "bench_name", "active_or_bench_uid"]:
		var wanted := str(selector.get("uid", selector.get("name", ""))).strip_edges().to_lower()
		var occurrence := maxi(0, int(selector.get("occurrence", 0)))
		var seen := 0
		var candidates: Array[PokemonSlot] = []
		if zone == "active_or_bench_uid" and player.active_pokemon != null:
			candidates.append(player.active_pokemon)
		candidates.append_array(player.bench)
		for slot: PokemonSlot in candidates:
			if slot == null or slot.get_top_card() == null or slot.get_top_card().card_data == null:
				continue
			var card_data: CardData = slot.get_top_card().card_data
			var matches := wanted in [
				card_data.get_uid().strip_edges().to_lower(),
				card_data.name.strip_edges().to_lower(),
				card_data.name_en.strip_edges().to_lower(),
			]
			if not matches:
				continue
			if seen == occurrence:
				return slot
			seen += 1
		return null
	if zone == "bench_remaining_hp":
		var wanted := int(selector.get("remaining_hp", -1))
		for slot: PokemonSlot in player.bench:
			if slot != null and slot.get_remaining_hp() == wanted:
				return slot
	return null


func _resolve_value(gsm: GameStateMachine, value: Variant) -> Variant:
	if value is Array:
		var resolved_array: Array = []
		for item: Variant in value:
			resolved_array.append(_resolve_value(gsm, item))
		return resolved_array
	if not (value is Dictionary):
		return value
	var source: Dictionary = value
	if source.has("$slot"):
		var selector_variant: Variant = source.get("$slot", {})
		if not (selector_variant is Dictionary):
			return null
		var selector: Dictionary = selector_variant
		var player_index := int(selector.get("player", 0))
		if player_index < 0 or player_index >= gsm.game_state.players.size():
			return null
		return _resolve_slot(gsm.game_state.players[player_index], selector)
	if source.has("$card"):
		return _resolve_card(gsm, source.get("$card", {}))
	if source.has("$cards"):
		return _resolve_cards(gsm, source.get("$cards", {}))
	var resolved_dictionary: Dictionary = {}
	for key: Variant in source:
		resolved_dictionary[key] = _resolve_value(gsm, source[key])
	return resolved_dictionary


func _resolve_card(gsm: GameStateMachine, selector_variant: Variant) -> CardInstance:
	var cards := _zone_cards(gsm, selector_variant)
	if cards.is_empty():
		return null
	var selector: Dictionary = selector_variant
	var occurrence := int(selector.get("occurrence", 0))
	return cards[occurrence] if occurrence >= 0 and occurrence < cards.size() else null


func _resolve_cards(gsm: GameStateMachine, selector_variant: Variant) -> Array[CardInstance]:
	var cards := _zone_cards(gsm, selector_variant)
	if not (selector_variant is Dictionary):
		return cards
	var limit := int((selector_variant as Dictionary).get("limit", -1))
	if limit >= 0 and cards.size() > limit:
		cards.resize(limit)
	return cards


func _zone_cards(gsm: GameStateMachine, selector_variant: Variant) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	if not (selector_variant is Dictionary):
		return result
	var selector: Dictionary = selector_variant
	var player_index := int(selector.get("player", 0))
	if player_index < 0 or player_index >= gsm.game_state.players.size():
		return result
	var player: PlayerState = gsm.game_state.players[player_index]
	var zone := str(selector.get("zone", "hand"))
	match zone:
		"hand":
			result.assign(player.hand)
		"discard":
			result.assign(player.discard_pile)
		"deck":
			result.assign(player.deck)
		"prizes":
			result.assign(player.prizes)
		"active_energy":
			if player.active_pokemon != null:
				result.assign(player.active_pokemon.attached_energy)
		"bench_energy":
			var bench_index := int(selector.get("index", -1))
			if bench_index >= 0 and bench_index < player.bench.size():
				result.assign(player.bench[bench_index].attached_energy)
		"all_attached_energy":
			for slot: PokemonSlot in player.get_all_pokemon():
				result.append_array(slot.attached_energy)
	var uid := str(selector.get("uid", ""))
	var card_type := str(selector.get("card_type", ""))
	var filtered: Array[CardInstance] = []
	for card: CardInstance in result:
		if card == null or card.card_data == null:
			continue
		if uid != "" and card.card_data.get_uid() != uid:
			continue
		if card_type != "" and card.card_data.card_type != card_type:
			continue
		filtered.append(card)
	return filtered


func _most_damaged_live_slot(player: PlayerState) -> PokemonSlot:
	var selected: PokemonSlot = null
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null or slot.get_top_card() == null or slot.get_remaining_hp() <= 0:
			continue
		if selected == null or slot.damage_counters > selected.damage_counters:
			selected = slot
	return selected if selected != null and selected.damage_counters > 0 else null


func _find_hand_card(player: PlayerState, uid: String) -> CardInstance:
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.get_uid() == uid:
			return card
	return null


func _action_result(ok: bool, label: String) -> Dictionary:
	return {"ok": ok, "reason": "production_action_rejected:%s" % label if not ok else ""}


func _capture_target_instance_ids(state: GameState) -> Array[int]:
	var result: Array[int] = []
	var goal: Dictionary = GoalEvaluatorScript.base_goal(_scenario.get("goal", {}))
	for target_variant: Variant in goal.get("targets", []):
		if not (target_variant is Dictionary):
			continue
		var target: Dictionary = target_variant
		var player_index := int(target.get("player", 1))
		if player_index < 0 or player_index >= state.players.size():
			continue
		var slot := _resolve_slot(state.players[player_index], target)
		if slot != null and slot.get_top_card() != null:
			result.append(slot.get_top_card().instance_id)
	return result


func _count_target_knockouts(state: GameState, ids_variant: Variant) -> int:
	if not (ids_variant is Array):
		return 0
	var found: Dictionary = {}
	for player: PlayerState in state.players:
		for card: CardInstance in player.discard_pile:
			if card != null and card.instance_id in (ids_variant as Array):
				found[card.instance_id] = true
	return found.size()


func _contract_steps(contract_id: String) -> Array[Dictionary]:
	match contract_id:
		"dragapult_borrowed_damage_v1":
			return [
				{"id": "evolve_backup", "kind": "evolve", "label": "进化备战多龙", "card_uid": "CSV8C_159", "target": {"zone": "bench", "index": 0}},
				{"id": "attach_fire", "kind": "attach_energy", "label": "给备战多龙贴火能", "card_uid": "CSVE1C_FIR", "target": {"zone": "bench", "index": 0}},
				{"id": "offer_dusknoir", "kind": "end_turn", "label": "结束回合，送出黑夜魔灵"},
				{"id": "dragapult_reply", "kind": "fixed_rules_ai_turn", "label": "自爆多龙规则AI完整回合", "require_attack": true},
				{"id": "return_thirty", "kind": "munkidori", "label": "愿增猿搬30到230HP目标", "ability_source": {"zone": "bench", "index": 0}, "damage_target": {"zone": "bench", "index": 0}, "amount": 30},
				{"id": "gust_target", "kind": "play_trainer", "label": "反击捕捉器拉出目标", "card_uid": "CSV6C_114", "target_player": 1, "target": {"zone": "bench", "index": 0}, "context_key": "opponent_bench_target"},
				{"id": "double_ko", "kind": "attack", "label": "幻影潜袭200+60双杀", "attack_index": 1, "bench_assignments": [{"target": {"zone": "bench_remaining_hp", "remaining_hp": 60}, "amount": 60}]},
			]
		"dragapult_five_prize_clear_v1":
			return [
				{"id": "evolve_active", "kind": "evolve", "label": "进化前场多龙", "card_uid": "CSV8C_159", "target": {"zone": "active"}},
				{"id": "attach_fire", "kind": "attach_energy", "label": "给前场多龙贴火能", "card_uid": "CSVE1C_FIR", "target": {"zone": "active"}},
				{"id": "cross_item_lock", "kind": "end_turn", "label": "结束回合"},
				{"id": "budew_reply", "kind": "fixed_rules_ai_turn", "label": "含羞苞规则AI完整回合", "require_attack": true},
				{"id": "tune_dreepy", "kind": "munkidori", "label": "愿增猿把60HP目标调到30HP", "ability_source": {"zone": "bench", "index": 1}, "damage_target": {"zone": "bench", "index": 1}, "amount": 30},
				{"id": "blast_ex", "kind": "self_ko", "label": "咒怨炸弹击倒130HP双奖目标", "ability_source": {"zone": "bench", "index": 0}, "damage_target": {"zone": "bench", "index": 0}},
				{"id": "five_prize_attack", "kind": "attack", "label": "幻影潜袭3+3三杀", "attack_index": 1, "bench_assignments": [
					{"target": {"zone": "bench", "index": 0}, "amount": 30},
					{"target": {"zone": "bench", "index": 1}, "amount": 30}
				]},
			]
		"dragapult_gust_spread_mate_v1":
			return [
				{"id": "tune_active_target", "kind": "munkidori", "label": "愿增猿把230HP目标调到200HP", "ability_source": {"zone": "bench", "index": 1}, "damage_target": {"zone": "bench", "index": 0}, "amount": 30},
				{"id": "gust_target", "kind": "play_trainer", "label": "反击捕捉器拉出200HP目标", "card_uid": "CSV6C_114", "target_player": 1, "target": {"zone": "bench", "index": 0}, "context_key": "opponent_bench_target"},
				{"id": "evolve_backup", "kind": "evolve", "label": "进化备战多龙", "card_uid": "CSV8C_159", "target": {"zone": "bench", "index": 0}},
				{"id": "attach_fire", "kind": "attach_energy", "label": "给备战多龙贴火能", "card_uid": "CSVE1C_FIR", "target": {"zone": "bench", "index": 0}},
				{"id": "switch_attacker", "kind": "play_trainer", "label": "宝可梦交替换入多龙", "card_uid": "CSV1C_113", "target_player": 0, "target": {"zone": "bench", "index": 0}, "context_key": "self_switch_target"},
				{"id": "mate_in_one", "kind": "attack", "label": "幻影潜袭200+60四奖", "attack_index": 1, "bench_assignments": [{"target": {"zone": "bench_remaining_hp", "remaining_hp": 60}, "amount": 60}]},
			]
	return []


func _scenario_steps(scenario: Dictionary) -> Array[Dictionary]:
	var authored: Array[Dictionary] = []
	var steps_variant: Variant = scenario.get("proof_steps", [])
	if steps_variant is Array:
		for step_variant: Variant in steps_variant:
			if step_variant is Dictionary:
				authored.append((step_variant as Dictionary).duplicate(true))
	if not authored.is_empty():
		return authored
	return _contract_steps(str(scenario.get("proof_contract_id", "")))
