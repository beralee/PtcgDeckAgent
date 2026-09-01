class_name CompetitivePolicyV2Core
extends RefCounted

const TreeHashScript = preload("res://scripts/ai/ptcgdap/cabt/CabtTreeHash.gd")
const DamagePlanningScript = preload("res://scripts/ai/ptcgdap/public/PublicDamagePlanning.gd")
const TurnProgramPlannerScript = preload(
	"res://scripts/ai/ptcgdap/public/TurnProgramPlanner.gd"
)
const TurnProgramGeneratorScript = preload(
	"res://scripts/ai/ptcgdap/public/TurnProgramGenerator.gd"
)

const PROFILE_ID := "ptcgdap-competitive-policy-v2"
const FRAME_PROFILE_ID := "ptcgdap-competitive-public-frame-v2"
const MAX_SAFE_INTEGER := 9007199254740991
const MAX_SCORE := 1000000000
const MAX_COMPILED_POLICY_CACHE := 128

# Locked to the official CABT sample bundle. Unknown appended enum values keep
# their raw integer and expose null for the symbolic alias so rules fail closed.
const SELECT_TYPE_NAMES := [
	"main", "card", "attached_card", "card_or_attached_card", "energy",
	"skill", "attack", "evolve", "count", "yes_no", "special_condition",
]
const SELECT_CONTEXT_NAMES := [
	"main", "setup_active_pokemon", "setup_bench_pokemon", "switch", "to_active",
	"to_bench", "to_field", "to_hand", "discard", "to_deck", "to_deck_bottom",
	"to_prize", "not_move", "damage_counter", "damage_counter_any", "damage",
	"remove_damage_counter", "heal", "evolves_from", "evolves_to", "devolve",
	"attach_from", "attach_to", "detach_from", "look", "effect_target",
	"discard_energy_card", "discard_tool_card", "switch_energy_card",
	"discard_card_or_attached_card", "discard_energy", "to_hand_energy",
	"to_deck_energy", "switch_energy", "skill_order", "attack", "disable_attack",
	"evolve", "draw_count", "damage_counter_count", "remove_damage_counter_count",
	"is_first", "mulligan", "activate", "first_effect", "more_devolve", "coin_head",
	"affect_special_condition", "recover_special_condition",
]

static var _compiled_execution_plans: Dictionary = {}
static var _compiled_execution_plan_order: Array[String] = []

const GOAL_STAGES := {
	"acquire": true, "deploy": true, "fund": true, "ready": true,
	"execute": true, "maintain": true, "recover": true,
}
const CHANNELS := {
	"macro": true, "tactical": true, "interaction": true,
	"future": true, "uncertainty": true,
}
const OPS := {"eq": true, "ne": true, "lt": true, "lte": true, "gt": true, "gte": true, "contains": true, "not_contains": true}
const COUNT_MODES := {
	"fixed": true,
	"goal_energy_debt": true,
	"goal_missing_energy_sources": true,
	"distinct_card_uids": true,
	"ceil_public_fact_divisor": true,
	"ceil_public_fact_divisor_with_reserve": true,
}
const PRIVATE_KEYS := {
	"deck_order": true, "private_state": true, "search_begin_input": true,
	"callback": true, "binding": true, "ticket": true, "command": true,
	"object_ref": true, "instance_id": true, "raw_private_hash": true,
}
const SCALAR_FACTS := {
	"prompt_kind": true,
	"select.type": true,
	"select.context": true,
	"select.type_raw": true,
	"select.context_raw": true,
	"turn_number": true,
	"turn.supporter_available": true,
	"turn.manual_attachment_available": true,
	"turn.retreat_available": true,
	"self.prizes_remaining": true,
	"opponent.prizes_remaining": true,
	"self.deck_count": true,
	"opponent.deck_count": true,
	"self.hand_count": true,
	"opponent.hand_count": true,
	"self.bench_count": true,
	"self.bench_capacity": true,
	"self.bench_space": true,
	"self.bench_open": true,
	"opponent.bench_count": true,
	"self.active.remaining_hp": true,
	"self.active.prize_value": true,
	"self.active.attached_tool_uid": true,
	"opponent.active.remaining_hp": true,
	"opponent.active.prize_value": true,
	"window.source_uid": true,
	"window.option_kind": true,
	"window.attack_option_count": true,
	"select.min_count": true,
	"select.max_count": true,
	"option.index": true,
	"option.kind": true,
	"option.card_uid": true,
	"option.source_uid": true,
	"option.source_serial": true,
	"option.source_entity_serial": true,
	"option.target_uid": true,
	"option.target_serial": true,
	"option.target_entity_serial": true,
	"option.target_remaining_hp": true,
	"option.target_prize_value": true,
	"option.target_attached_energy_count": true,
	"option.target_attached_energy_uids": true,
	"option.target_minimum_attack_energy_count": true,
	"option.target_attack_ready": true,
	"option.target_energy_debt": true,
	"option.projected_damage": true,
	"option.projected_knockout": true,
	"option.requires_interaction": true,
	"option.attack_index": true,
	"option.option_number": true,
	"option.ability_index": true,
	"option.pending_assignment_count": true,
	"option.tags": true,
	"option.source_is_active": true,
	"option.target_is_active": true,
	"goal.energy_debt": true,
	"goal.ready_count": true,
	"goal.deployed_count": true,
	"goal.active_ready_count": true,
	"goal.bench_ready_count": true,
	"goal.near_ready_count": true,
	"goal.board_energy_count": true,
	"goal.hand_energy_count": true,
	"goal.discard_energy_count": true,
	"goal.immediate": true,
	"goal.complete": true,
	"goal.option.matches_target": true,
	"goal.option.acquires_missing_target": true,
	"goal.option.deploys_missing_target": true,
	"goal.option.supplies_missing_energy": true,
	"goal.option.funds_target": true,
	"goal.option.completes_target": true,
	"goal.option.pivots_ready_target": true,
	"goal.option.executes_requirement": true,
	"goal.option.target_energy_debt": true,
	"goal.option.progress": true,
	"goal.option.is_max_progress": true,
	"goal.window.max_progress": true,
	"goal.option.is_max_setup_progress": true,
	"goal.window.max_setup_progress": true,
	"threat.own_attacks_to_win": true,
	"threat.opponent_attacks_to_win": true,
	"threat.tempo_margin": true,
	"damage.movable_counter_count": true,
	"damage.available_mover_count": true,
	"damage.froslass_check_count": true,
	"damage.best_transfer_count": true,
	"damage.best_transfer_target_entity_serial": true,
	"damage.best_transfer_attack_windows_to_ko": true,
	"damage.best_transfer_prize_yield": true,
	"damage.best_transfer_remaining_debt": true,
	"damage.best_target_entity_serial": true,
	"damage.best_attack_windows_to_ko": true,
	"damage.best_prize_yield": true,
	"damage.best_remaining_debt": true,
	"damage.current_attack_damage": true,
	"damage.current_attack_bench_damage": true,
	"damage.best_gust_target_entity_serial": true,
	"damage.best_gust_attack_windows_to_ko": true,
	"damage.best_gust_prize_yield": true,
	"damage.best_gust_remaining_debt": true,
	"damage.option.target_entity_serial": true,
	"damage.option.projected_damage": true,
	"damage.option.bench_damage": true,
	"damage.option.attack_windows_to_ko": true,
	"damage.option.prize_yield": true,
	"damage.option.remaining_debt": true,
	"damage.option.overkill": true,
	"damage.option.response_risk": true,
	"transaction.active": true,
	"transaction.id": true,
	"transaction.phase": true,
	"transaction.candidate.card_uid": true,
	"transaction.candidate.remaining_damage_debt": true,
	"transaction.candidate.remaining_energy_debt": true,
	"transaction.candidate.is_damage_best": true,
	"transaction.candidate.is_transfer_best": true,
	"transaction.candidate.is_gust_best": true,
	"transaction.target_entity_serial": true,
	"transaction.remaining_damage_debt": true,
	"transaction.remaining_energy_debt": true,
	"transaction.deadline_turn": true,
	"transaction.option.matches_target": true,
}
const ZONE_FACTS := {
	"self.hand.count_uid": true,
	"self.active.count_uid": true,
	"self.bench.count_uid": true,
	"self.bench.evolution_eligible_count_uid": true,
	"self.discard.count_uid": true,
	"self.board.count_uid": true,
	"opponent.active.count_uid": true,
	"opponent.bench.count_uid": true,
	"opponent.discard.count_uid": true,
	"opponent.board.count_uid": true,
}
const ENERGY_ZONE_FACTS := {
	"self.active.energy_count_uid": true,
	"self.bench.energy_count_uid": true,
	"self.board.energy_count_uid": true,
	"opponent.active.energy_count_uid": true,
	"opponent.bench.energy_count_uid": true,
	"opponent.board.energy_count_uid": true,
}
const ENERGY_BEARING_ZONE_FACTS := {
	"self.board.energy_bearing_count_uid": true,
	"self.bench.energy_bearing_evolution_eligible_count_uid": true,
}
const GOAL_UID_FACTS := {
	"goal.deployed_count_uid": true,
	"goal.ready_count_uid": true,
	"goal.near_ready_count_uid": true,
	"goal.energy_debt_uid": true,
	"goal.active_ready_count_uid": true,
	"goal.bench_ready_count_uid": true,
}
const WINDOW_UID_FACTS := {
	"window.option_count_card_uid": true,
	"window.option_count_source_uid": true,
	"window.option_count_target_uid": true,
}
const NON_NUMERIC_FACTS := {
	"prompt_kind": true, "select.type": true, "select.context": true,
	"option.kind": true, "option.card_uid": true,
	"option.source_uid": true, "option.target_uid": true, "option.tags": true,
	"option.target_attached_energy_uids": true,
	"option.source_is_active": true, "option.target_is_active": true,
	"self.bench_open": true,
	"goal.complete": true,
	"goal.immediate": true,
	"goal.option.matches_target": true,
	"goal.option.acquires_missing_target": true,
	"goal.option.deploys_missing_target": true,
	"goal.option.supplies_missing_energy": true,
	"goal.option.funds_target": true,
	"goal.option.completes_target": true,
	"goal.option.pivots_ready_target": true,
	"goal.option.executes_requirement": true,
	"goal.option.is_max_progress": true,
	"goal.option.is_max_setup_progress": true,
	"turn.supporter_available": true,
	"turn.manual_attachment_available": true,
	"turn.retreat_available": true,
	"transaction.active": true,
	"transaction.id": true,
	"transaction.phase": true,
	"transaction.candidate.card_uid": true,
	"transaction.candidate.is_damage_best": true,
	"transaction.candidate.is_transfer_best": true,
	"transaction.candidate.is_gust_best": true,
	"transaction.option.matches_target": true,
}
const DOCUMENT_REQUIRED_KEYS := ["schema_version", "adapter_id", "adapter_version", "goals", "count_rules", "rules"]
const DOCUMENT_KEYS := [
	"schema_version", "adapter_id", "adapter_version", "goals", "count_rules", "rules",
	"turn_routes", "route_candidates", "interaction_recipes", "turn_bonus_contracts",
	"damage_plans", "semantic_transactions", "turn_transactions",
]
const GOAL_KEYS := ["goal_id", "stage", "priority", "requirements"]
const REQUIREMENT_KEYS := ["card_uid", "ready_target_count", "energy_required"]
const TYPED_REQUIREMENT_KEYS := ["card_uid", "ready_target_count", "energy_required", "energy_requirements"]
const ROUTE_REQUIREMENT_KEYS := [
	"card_uid", "ready_target_count", "energy_required", "energy_requirements",
	"attack_index", "ability_index",
]
const ENERGY_REQUIREMENT_KEYS := ["energy_uid", "count"]
const COUNT_RULE_KEYS := [
	"rule_id", "priority", "goal_id", "mode", "fixed_count", "fact", "divisor", "when",
]
const RULE_KEYS := [
	"rule_id", "goal_id", "goal_stage", "channel", "horizon",
	"confidence_milli", "base_score", "when", "score_terms",
]
const TURN_ROUTE_KEYS := [
	"route_id", "priority", "goal_id", "owner_goal_id", "bridge_goal_id",
	"pivot_goal_id", "when", "steps",
]
const ROUTE_CANDIDATE_KEYS := [
	"route_id", "goal_id", "owner_goal_id", "bridge_goal_id", "pivot_goal_id",
	"when", "resource_budget", "value", "steps",
]
const ROUTE_RESOURCE_BUDGET_KEYS := [
	"supporter_uses", "manual_attachments", "retreats", "bench_slots",
	"ability_uses", "discard_cards", "search_cards",
]
const ROUTE_VALUE_COMPONENTS := [
	"attack_windows", "prize_progress", "continuity", "resource_cost",
	"response_risk", "uncertainty",
]
const ROUTE_VALUE_COMPONENT_KEYS := ["base", "terms"]
const ROUTE_STEP_KEYS := [
	"step_id", "prompt_kinds", "goal_id", "when", "option_when", "score_bonus",
	"selection_count", "terminal", "checkpoint",
]
const ROUTE_CANDIDATE_STEP_KEYS := [
	"step_id", "prompt_kinds", "goal_id", "when", "option_when",
	"selection_count", "terminal", "checkpoint",
]
const INTERACTION_RECIPE_KEYS := [
	"recipe_id", "priority", "route_id", "goal_id", "source_uids", "when", "steps",
]
const TURN_BONUS_CONTRACT_KEYS := [
	"contract_id", "priority", "goal_id", "when", "bonuses",
]
const TURN_BONUS_KEYS := [
	"bonus_id", "prompt_kinds", "goal_id", "when", "option_when", "score_bonus",
]
const TURN_TRANSACTION_REQUIRED_KEYS := [
	"transaction_id", "priority", "goal_id", "deadline_turns", "when",
	"success_when", "abort_when", "methods",
]
const TURN_TRANSACTION_KEYS := [
	"transaction_id", "priority", "goal_id", "deadline_turns", "when",
	"continue_when", "success_when", "abort_when", "methods",
]
const TURN_TRANSACTION_METHOD_KEYS := ["method_id", "priority", "when", "steps"]
const TURN_TRANSACTION_STEP_REQUIRED_KEYS := [
	"step_id", "prompt_kinds", "goal_id", "required_when", "complete_when",
	"option_when", "score_bonus", "selection_count", "terminal", "checkpoint",
	"required_before_attack",
]
const TURN_TRANSACTION_STEP_KEYS := [
	"step_id", "prompt_kinds", "goal_id", "required_when", "complete_when",
	"option_when", "score_bonus", "selection_count", "terminal", "checkpoint",
	"required_before_attack", "selection_groups", "sequence_barrier",
]
const TURN_TRANSACTION_SELECTION_GROUP_KEYS := [
	"group_id", "selection_count", "option_when",
]
const CONDITION_KEYS := ["fact", "op", "value", "card_uid"]
const TERM_KEYS := ["fact", "coefficient", "minimum", "maximum"]
const FRAME_KEYS := [
	"schema_version", "profile_id", "sequence", "seat", "prompt_kind",
	"source", "public_state", "select_semantics", "options",
]
const SLOT_REQUIRED_KEYS := [
	"serial", "local_card_uid", "remaining_hp", "prize_value",
	"attached_energy_count", "attached_energy_uids", "minimum_attack_energy_count",
	"attack_ready", "energy_debt",
]
const SLOT_KEYS := [
	"serial", "local_card_uid", "remaining_hp", "prize_value",
	"attached_energy_count", "attached_energy_uids", "minimum_attack_energy_count",
	"attack_ready", "energy_debt", "entity_serial", "max_hp", "damage_counters",
	"appeared_this_turn", "attached_tool_uid", "pokemon_stack_uids",
]
const SELF_REQUIRED_KEYS := ["hand", "active", "bench", "discard", "deck_count", "prizes_remaining"]
const SELF_KEYS := ["hand", "active", "bench", "discard", "deck_count", "prizes_remaining", "turn", "bench_capacity"]
const TURN_LEDGER_KEYS := [
	"supporter_available", "manual_attachment_available", "retreat_available",
]
const OPTION_REQUIRED_KEYS := [
	"index", "kind", "card_uid", "card_serial", "source_uid", "source_serial", "target_uid",
	"target_serial", "target_remaining_hp", "target_prize_value",
	"target_attached_energy_count", "target_attached_energy_uids",
	"target_minimum_attack_energy_count",
	"target_attack_ready", "target_energy_debt", "projected_damage",
	"projected_knockout", "requires_interaction", "attack_index", "option_number", "ability_index",
	"energy_type_raw", "energy_count", "special_condition_type",
	"pending_assignment_count", "tags", "option_type_raw", "option_player_index",
]
const OPTION_KEYS := [
	"index", "kind", "card_uid", "card_serial", "source_uid", "source_serial", "target_uid",
	"target_serial", "target_remaining_hp", "target_prize_value",
	"target_attached_energy_count", "target_attached_energy_uids",
	"target_minimum_attack_energy_count", "target_attack_ready", "target_energy_debt",
	"projected_damage", "projected_knockout", "requires_interaction", "attack_index",
	"option_number", "ability_index", "energy_type_raw", "energy_count",
	"special_condition_type", "pending_assignment_count", "tags", "option_type_raw",
	"option_player_index", "source_entity_serial", "target_entity_serial",
]


static func compile_local_uid(document: Variant, allowed_card_uids: Variant) -> Dictionary:
	if not allowed_card_uids is Array or allowed_card_uids.is_empty():
		return _compile_error("invalid_allowed_card_uids")
	var allowed := {}
	for value: Variant in allowed_card_uids:
		if not _local_uid(value) or allowed.has(value):
			return _compile_error("invalid_allowed_card_uids")
		allowed[value] = true
	var error := _document_error(document, allowed)
	if not error.is_empty():
		return _compile_error(error)
	var source: Dictionary = document.duplicate(true)
	var hash_value := _hash({"profile_id": PROFILE_ID, "document": source})
	if hash_value.is_empty():
		return _compile_error("policy_integrity_invalid")
	if not _store_execution_plan(hash_value, source, allowed, true):
		return _compile_error("policy_execution_plan_invalid")
	return {
		"accepted": true,
		"error_code": "",
		"policy": {
			"document": source,
			"allowed_card_uids": allowed.duplicate(true),
			"policy_hash": hash_value,
		},
	}


static func policy_public_dict(policy: Variant) -> Dictionary:
	return policy.get("document", {}).duplicate(true) if _policy_valid(policy) else {}


static func requires_competitive_frame_v2(policy: Variant) -> bool:
	return _policy_valid(policy)


static func decide(
	policy: Variant,
	frame: Variant,
	mandatory_indexes: Variant = [],
	terminal_indexes: Variant = [],
	base_hard_tiers: Variant = [],
	base_vetoed_indexes: Variant = [],
	transaction_journal: Variant = null,
	turn_transaction_journal: Variant = null,
	turn_program_request: Variant = null,
	turn_program_journal: Variant = null,
	auto_turn_program_shadow: bool = false,
	turn_program_canary_profile: Variant = null,
	turn_program_value_model: Variant = null,
	turn_program_action_semantics: Variant = null,
) -> Dictionary:
	if not _policy_valid(policy):
		return _decision_error("invalid_policy")
	var policy_hash := str(policy.get("policy_hash", ""))
	var execution_plan: Dictionary = _execution_plan(policy_hash)
	if execution_plan.is_empty():
		if not _store_execution_plan(
			policy_hash, policy.get("document", {}), policy.get("allowed_card_uids", {})
		):
			return _decision_error("invalid_compiled_policy")
		execution_plan = _execution_plan(policy_hash)
	if execution_plan.is_empty():
		return _decision_error("invalid_compiled_policy")
	return _decide_with_execution_plan(
		policy_hash, execution_plan, frame, mandatory_indexes, terminal_indexes,
		base_hard_tiers, base_vetoed_indexes, transaction_journal,
		turn_transaction_journal, turn_program_request, turn_program_journal,
		auto_turn_program_shadow, turn_program_canary_profile, turn_program_value_model,
		turn_program_action_semantics
	)


static func decide_compiled(
	policy_hash: Variant,
	frame: Variant,
	mandatory_indexes: Variant = [],
	terminal_indexes: Variant = [],
	base_hard_tiers: Variant = [],
	base_vetoed_indexes: Variant = [],
	transaction_journal: Variant = null,
	turn_transaction_journal: Variant = null,
	turn_program_request: Variant = null,
	turn_program_journal: Variant = null,
	auto_turn_program_shadow: bool = false,
	turn_program_canary_profile: Variant = null,
	turn_program_value_model: Variant = null,
	turn_program_action_semantics: Variant = null,
) -> Dictionary:
	if not _is_sha(policy_hash):
		return _decision_error("invalid_compiled_policy")
	var execution_plan: Dictionary = _execution_plan(str(policy_hash))
	if execution_plan.is_empty():
		return _decision_error("invalid_compiled_policy")
	return _decide_with_execution_plan(
		str(policy_hash), execution_plan, frame, mandatory_indexes, terminal_indexes,
		base_hard_tiers, base_vetoed_indexes, transaction_journal,
		turn_transaction_journal, turn_program_request, turn_program_journal,
		auto_turn_program_shadow, turn_program_canary_profile, turn_program_value_model,
		turn_program_action_semantics
	)


static func _decide_with_execution_plan(
	policy_hash: String,
	execution_plan: Dictionary,
	frame: Variant,
	mandatory_indexes: Variant,
	terminal_indexes: Variant,
	base_hard_tiers: Variant,
	base_vetoed_indexes: Variant,
	transaction_journal: Variant,
	turn_transaction_journal: Variant,
	turn_program_request: Variant,
	turn_program_journal: Variant,
	auto_turn_program_shadow: bool,
	turn_program_canary_profile: Variant,
	turn_program_value_model: Variant,
	turn_program_action_semantics: Variant,
) -> Dictionary:
	var frame_value: Variant = frame.duplicate(true) if frame is Dictionary else frame
	var frame_error := _frame_error(frame_value)
	if not frame_error.is_empty():
		return _decision_error(frame_error)
	var turn_program_frame: Dictionary = frame_value.duplicate(true)
	if turn_program_canary_profile != null \
			and not _turn_program_canary_profile(turn_program_canary_profile):
		return _decision_error("invalid_turn_program_canary_profile")
	if turn_program_canary_profile != null and not auto_turn_program_shadow:
		return _decision_error("turn_program_canary_requires_fresh_generation")
	if turn_program_action_semantics != null \
			and not _turn_program_action_semantics_profile(turn_program_action_semantics):
		return _decision_error("invalid_turn_program_action_semantics")
	if turn_program_action_semantics != null and not auto_turn_program_shadow:
		return _decision_error("turn_program_action_semantics_requires_fresh_generation")
	var document: Dictionary = execution_plan.get("document", {})
	var planning_execution_hash := str(
		execution_plan.get("planning_execution_plan_hash", "")
	)
	var damage_result := {
		"accepted": true, "error_code": "", "facts": {}, "options": {},
		"targets": {}, "audit_hash": "",
	}
	if not document.get("damage_plans", []).is_empty():
		damage_result = DamagePlanningScript.calculate_compiled(
			frame_value, policy_hash, planning_execution_hash
		)
		if not bool(damage_result.get("accepted", false)):
			return _decision_error(str(damage_result.get("error_code", "damage_plan_failed")))
	var transaction_result := {
		"accepted": true, "error_code": "", "event": "idle",
		"reason": "journal_not_bound", "state": {}, "audit_hash": "",
	}
	if not document.get("semantic_transactions", []).is_empty() and transaction_journal != null:
		if not transaction_journal.has_method("advance"):
			return _decision_error("semantic_transaction_unbound")
		if not transaction_journal.has_method("advance_compiled"):
			return _decision_error("semantic_transaction_unbound")
		transaction_result = transaction_journal.advance_compiled(
			frame_value, policy_hash, planning_execution_hash, damage_result
		)
		if not bool(transaction_result.get("accepted", false)):
			return _decision_error(str(
				transaction_result.get("error_code", "semantic_transaction_failed")
			))
	frame_value["_derived_damage"] = damage_result
	frame_value["_derived_transaction"] = transaction_result
	var turn_transaction_result := {
		"accepted": true, "error_code": "", "event": "idle",
		"reason": "journal_not_bound", "transaction_id": null,
		"method_id": null, "step_id": null, "goal_id": null,
		"current_indexes": [], "selection_count": null, "score_bonus": 0,
		"terminal": false, "checkpoint": false, "sequence_barrier": false,
		"required_before_attack": false, "attack_commit_blocked": false,
		"turn_commit_blocked": false,
		"state": {}, "audit_hash": "",
	}
	if not document.get("turn_transactions", []).is_empty() and turn_transaction_journal != null:
		if not turn_transaction_journal.has_method("advance"):
			return _decision_error("turn_transaction_unbound")
		var transaction_goal_result := _goal_states(document, frame_value)
		var transaction_goals: Dictionary = transaction_goal_result.get("by_id", {})
		var transaction_threat := _threat_clock(frame_value)
		var transaction_matches := func(
			conditions: Array, option: Variant, goal_id: String
		) -> bool:
			return _matches(
				conditions, frame_value, option,
				transaction_goals.get(goal_id, {}), transaction_threat
			)
		turn_transaction_result = turn_transaction_journal.advance(
			frame_value, document.get("turn_transactions", []), transaction_matches
		)
		if not bool(turn_transaction_result.get("accepted", false)):
			return _decision_error(str(
				turn_transaction_result.get("error_code", "turn_transaction_failed")
			))
	frame_value["_derived_turn_transaction"] = turn_transaction_result
	var turn_program_shadow := {
		"accepted": true, "error_code": "", "mode": "shadow",
		"authoritative": false, "public_only": true,
		"selected_program_id": null, "selected_current_step_id": null,
		"ranked_program_ids": [], "candidate_audit": [],
		"reobserve_before_execution": true, "stale_plan_has_authority": false,
		"reason": "shadow_not_requested", "audit_hash": "",
	}
	if turn_program_request != null:
		if turn_program_journal != null:
			if turn_program_journal.has_method("advance"):
				turn_program_shadow = turn_program_journal.advance(
					turn_program_frame, turn_program_request
				)
			else:
				turn_program_shadow["accepted"] = false
				turn_program_shadow["error_code"] = "turn_program_shadow_failure"
				turn_program_shadow["reason"] = "shadow_failed_closed"
		else:
			turn_program_shadow = TurnProgramPlannerScript.evaluate(
				turn_program_frame, turn_program_request
			)
	var option_count: int = frame_value.get("options", []).size()
	if (
		not _index_list(mandatory_indexes, option_count)
		or not _index_list(terminal_indexes, option_count)
		or not _index_list(base_vetoed_indexes, option_count)
	):
		return _decision_error("invalid_base_authority")
	var tiers := {}
	if base_hard_tiers is Array and base_hard_tiers.is_empty():
		for index: int in option_count:
			tiers[index] = [0]
	elif not base_hard_tiers is Array or base_hard_tiers.size() != option_count:
		return _decision_error("invalid_base_authority")
	else:
		for value: Variant in base_hard_tiers:
			if not value is Dictionary or not _has_exact_keys(value, ["index", "tier"]):
				return _decision_error("invalid_base_authority")
			var index: Variant = value.get("index")
			var tier: Variant = value.get("tier")
			if (
				typeof(index) != TYPE_INT or index < 0 or index >= option_count or tiers.has(index)
				or not tier is Array or tier.is_empty() or tier.size() > 8
			):
				return _decision_error("invalid_base_authority")
			for part: Variant in tier:
				if not _safe_int(part, true):
					return _decision_error("invalid_base_authority")
			tiers[index] = tier.duplicate()
	if tiers.size() != option_count:
		return _decision_error("invalid_base_authority")
	var minimum: int = int(frame_value.get("select_semantics", {}).get("min_count", 0))
	var maximum: int = int(frame_value.get("select_semantics", {}).get("max_count", 0))
	for forced: Variant in [terminal_indexes, mandatory_indexes]:
		if not forced.is_empty() and (forced.size() < minimum or forced.size() > maximum):
			return _decision_error("invalid_base_authority")
	var evaluated := _evaluate_compiled(execution_plan, frame_value)
	var ranked: Array = evaluated.get("ranked", [])
	var desired: int = int(evaluated.get("desired", 0))
	if not bool(evaluated.get("count_rule_matched", false)) and not bool(evaluated.get("any_rule_matched", false)):
		var fallback_ranked: Array = []
		for option_value: Variant in frame_value.get("options", []):
			if option_value is Dictionary and option_value.get("kind") == "end_turn":
				fallback_ranked.append(int(option_value.get("index")))
		for raw_index: Variant in ranked:
			if raw_index not in fallback_ranked:
				fallback_ranked.append(raw_index)
		ranked = fallback_ranked
	var selected: Array = []
	var owner := "base_graph"
	var fallback_used := false
	if not terminal_indexes.is_empty():
		owner = "terminal"
		selected = terminal_indexes.duplicate()
	elif not mandatory_indexes.is_empty():
		owner = "mandatory"
		selected = mandatory_indexes.duplicate()
	else:
		var frontier: Array = []
		for index: int in option_count:
			frontier.append(index)
		if not frontier.is_empty():
			var best_tier: Array = tiers.get(frontier[0], [0])
			for index: int in frontier:
				if _tier_less(tiers.get(index, [0]), best_tier):
					best_tier = tiers.get(index, [0])
			var same_tier: Array = []
			for index: int in frontier:
				if tiers.get(index, [0]) == best_tier:
					same_tier.append(index)
			frontier = same_tier
		var ordered: Array = []
		for raw_index: Variant in ranked:
			var index := int(raw_index)
			if index in frontier and index not in base_vetoed_indexes:
				ordered.append(index)
		var selection_quotas: Variant = evaluated.get("selection_quotas")
		if selection_quotas is Dictionary:
			var remaining: Dictionary = selection_quotas.duplicate()
			var typed_ordered: Array = []
			for index_value: Variant in ordered:
				var index := int(index_value)
				var uid: Variant = frame_value.get("options", [])[index].get("card_uid")
				if typeof(uid) == TYPE_STRING and int(remaining.get(uid, 0)) > 0:
					typed_ordered.append(index)
					remaining[uid] = int(remaining.get(uid)) - 1
			if typed_ordered.size() < minimum:
				fallback_used = true
				desired = minimum
				selected = ordered.slice(0, desired)
			else:
				desired = clampi(typed_ordered.size(), minimum, maximum)
				selected = typed_ordered.slice(0, desired)
		else:
			if desired > ordered.size():
				fallback_used = true
				desired = minimum
			selected = ordered.slice(0, desired)
		if selected.size() < minimum or selected.size() > maximum:
			return _decision_error("insufficient_candidates")
		if not bool(evaluated.get("count_rule_matched", false)) and not bool(evaluated.get("any_rule_matched", false)):
			fallback_used = true
		elif not bool(evaluated.get("count_rule_matched", false)):
			var cards_by_index: Dictionary = {}
			for card_value: Variant in evaluated.get("scorecards", []):
				if card_value is Dictionary:
					cards_by_index[int(card_value.get("index", -1))] = card_value
			for selected_index_value: Variant in selected:
				var selected_index := int(selected_index_value)
				var selected_option: Dictionary = frame_value.get("options", [])[selected_index]
				var selected_card: Dictionary = cards_by_index.get(selected_index, {})
				if selected_option.get("kind") == "end_turn" and selected_card.get("matched_rules", []).is_empty():
					# A rule on another option must not disguise Base's neutral
					# end-turn tie fallback as an adapter-owned decision.
					fallback_used = true
					break
	var turn_contract: Dictionary = evaluated.get("turn_contract", {}).duplicate(true)
	var authority_indexes: Array = turn_contract.get("route_authority_indexes", [])
	turn_contract["route_authority_applied"] = (
		not authority_indexes.is_empty()
		and bool(turn_contract.get("route_authority_eligible", false))
		and owner == "base_graph"
		and selected.any(func(index: Variant) -> bool: return index in authority_indexes)
	)
	var turn_program_generation := {
		"accepted": false,
		"error_code": "turn_program_generation_not_requested",
		"mode": "shadow",
		"authoritative": false,
		"public_only": true,
		"candidate_count": 0,
		"emitted_count": 0,
		"request": null,
		"candidate_audit": [],
		"audit_hash": "",
	}
	var turn_program_differential := {
		"accepted": false,
		"error_code": "turn_program_differential_not_requested",
		"current_step_matches_live": false,
		"shadow_current_binding_found": false,
		"live_selected_option_kinds": [],
		"live_turn_route_id": null,
		"shadow_program_id": null,
		"shadow_current_step_id": null,
		"public_only": true,
		"authoritative": false,
	}
	var turn_program_canary := {
		"accepted": turn_program_canary_profile != null,
		"error_code": "",
		"requested": turn_program_canary_profile != null,
		"applied": false,
		"authoritative": false,
		"public_only": true,
		"reason": (
			"not_requested" if turn_program_canary_profile == null
			else "awaiting_fresh_generation"
		),
		"selected_program_id": null,
		"selected_current_step_id": null,
		"utility_source": null,
		"selected_utility": null,
		"live_utility": null,
		"minimum_utility_margin": null,
		"reobserve_before_execution": true,
		"stale_plan_has_authority": false,
	}
	if auto_turn_program_shadow and turn_program_request == null:
		var auto_goal_result := _goal_states(document, frame_value)
		var automatic := _automatic_turn_program_candidates(
			document,
			frame_value,
			auto_goal_result.get("by_id", {}),
			evaluated.get("threat", {}),
			mandatory_indexes,
			terminal_indexes,
			tiers,
			base_vetoed_indexes,
			ranked,
			turn_program_action_semantics,
		)
		turn_program_generation = TurnProgramGeneratorScript.generate(
			turn_program_frame, automatic.get("candidates", []), 8,
			turn_program_value_model
		)
		var generated_request: Variant = turn_program_generation.get("request")
		if bool(turn_program_generation.get("accepted", false)) \
				and generated_request is Dictionary:
			if turn_program_journal != null and turn_program_journal.has_method("advance"):
				turn_program_shadow = turn_program_journal.advance(
					turn_program_frame, generated_request
				)
			else:
				turn_program_shadow = TurnProgramPlannerScript.evaluate(
					turn_program_frame, generated_request
				)
		else:
			turn_program_shadow = turn_program_shadow.duplicate(true)
			turn_program_shadow["accepted"] = false
			turn_program_shadow["error_code"] = str(turn_program_generation.get(
				"error_code", "turn_program_generation_failed"
			))
			turn_program_shadow["reason"] = "automatic_generation_failed_closed"
		var selected_program_id: Variant = turn_program_shadow.get("selected_program_id")
		var shadow_binding: Array = automatic.get("bindings", {}).get(
			selected_program_id, []
		).duplicate()
		var live_kinds: Array = []
		for selected_index_value: Variant in selected:
			live_kinds.append(frame_value.get("options", [])[int(selected_index_value)].get(
				"kind"
			))
		turn_program_differential = {
			"accepted": bool(turn_program_shadow.get("accepted", false)),
			"error_code": str(turn_program_shadow.get("error_code", "")),
			"current_step_matches_live": (
				not shadow_binding.is_empty()
				and shadow_binding.size() == selected.size()
				and shadow_binding.all(func(index: Variant) -> bool: return index in selected)
			),
			"shadow_current_binding_found": not shadow_binding.is_empty(),
			"live_selected_option_kinds": live_kinds,
			"live_turn_route_id": turn_contract.get("route_id"),
			"shadow_program_id": selected_program_id,
			"shadow_current_step_id": turn_program_shadow.get("selected_current_step_id"),
			"public_only": true,
			"authoritative": false,
		}
		if turn_program_canary_profile != null:
			var selected_candidate: Variant = null
			for candidate_value: Variant in automatic.get("candidates", []):
				if candidate_value.get("program_id") == selected_program_id:
					selected_candidate = candidate_value
					break
			var selected_generation_audit: Variant = null
			for row_value: Variant in turn_program_generation.get("candidate_audit", []):
				if row_value.get("program_id") == selected_program_id:
					selected_generation_audit = row_value
					break
			var selected_final_audit: Variant = null
			for row_value: Variant in turn_program_shadow.get("candidate_audit", []):
				if row_value.get("program_id") == selected_program_id:
					selected_final_audit = row_value
					break
			var live_final_rows: Array = []
			for row_value: Variant in turn_program_shadow.get("candidate_audit", []):
				var row_binding: Array = automatic.get("bindings", {}).get(
					row_value.get("program_id"), []
				)
				if not row_binding.is_empty() and row_binding.size() == selected.size() \
						and row_binding.all(func(index: Variant) -> bool: return index in selected):
					live_final_rows.append(row_value)
			var live_utility := 0
			for row_value: Variant in live_final_rows:
				live_utility = maxi(live_utility, int(row_value.get("utility_milli", 0)))
			var selected_utility: Variant = (
				null if selected_final_audit == null
				else int(selected_final_audit.get("utility_milli", 0))
			)
			var reason := "eligible"
			if not bool(turn_program_shadow.get("accepted", false)) or shadow_binding.is_empty():
				reason = "shadow_binding_unavailable"
			elif owner != "base_graph":
				reason = "base_authority_not_delegable"
			elif selected_candidate == null or selected_generation_audit == null \
					or selected_final_audit == null:
				reason = "selected_candidate_unavailable"
			elif selected_candidate.get("source_kind") not in turn_program_canary_profile.get(
				"allowed_source_kinds", []
			):
				reason = "source_kind_not_allowed"
			elif selected_candidate.get("semantic_steps", [])[0].get("effect_kind") \
					not in turn_program_canary_profile.get("allowed_current_effect_kinds", []):
				reason = "effect_kind_not_allowed"
			elif not _turn_program_public_guard_satisfied(
				frame_value, shadow_binding, turn_program_action_semantics
			):
				reason = "public_precondition_not_met"
			elif live_final_rows.is_empty():
				reason = "live_utility_unavailable"
			else:
				var transition: Dictionary = selected_generation_audit.get(
					"transition_evaluation", {}
				)
				if not bool(transition.get("accepted", false)) \
						or not bool(transition.get("commit_safe", false)) \
						or int(transition.get("uncertainty_milli", 1000)) \
						> int(turn_program_canary_profile.get("max_uncertainty_milli")):
					reason = "transition_not_commit_safe"
				else:
					var live_is_commit := false
					for index_value: Variant in selected:
						if frame_value.get("options", [])[int(index_value)].get("kind") \
								in ["attack", "granted_attack", "end_turn"]:
							live_is_commit = true
							break
					if not live_is_commit:
						reason = "live_selection_not_a_commit"
					else:
						for row_value: Variant in live_final_rows:
							if int(row_value.get("final_prize_knockout", 0)) == 1:
								reason = "final_prize_terminal_protected"
								break
					if reason == "eligible" and int(selected_utility) < (
						live_utility + int(turn_program_canary_profile.get("minimum_utility_margin"))
					):
						reason = "utility_margin_not_met"
			var applied := reason == "eligible"
			if applied:
				selected = shadow_binding.duplicate()
				owner = "turn_program_canary"
			turn_program_canary["applied"] = applied
			turn_program_canary["authoritative"] = applied
			turn_program_canary["reason"] = reason
			turn_program_canary["selected_program_id"] = selected_program_id
			turn_program_canary["selected_current_step_id"] = turn_program_shadow.get(
				"selected_current_step_id"
			)
			turn_program_canary["utility_source"] = "turn_program_shadow_final"
			turn_program_canary["selected_utility"] = selected_utility
			turn_program_canary["live_utility"] = (
				null if live_final_rows.is_empty() else live_utility
			)
			turn_program_canary["minimum_utility_margin"] = turn_program_canary_profile.get(
				"minimum_utility_margin"
			)
	var audit_payload := {
		"schema_version": 2,
		"profile_id": PROFILE_ID,
		"policy_hash": policy_hash,
		"public_observation_hash": frame_value.get("source", {}).get("public_observation_hash"),
		"window_id": frame_value.get("source", {}).get("window_id"),
		"owner_layer": owner,
		"ranked_indexes": ranked.duplicate(),
		"desired_count": desired,
		"selected_indexes": selected.duplicate(),
		"goal_states": evaluated.get("goal_states", []).duplicate(true),
		"threat_clock": evaluated.get("threat", {}).duplicate(true),
		"turn_contract": turn_contract,
		"damage_plan": {
			"audit_hash": damage_result.get("audit_hash", ""),
			"facts": damage_result.get("facts", {}).duplicate(true),
			"best_target_entity_serial": damage_result.get("best_target_entity_serial"),
		},
		"semantic_transaction": transaction_result.duplicate(true),
		"turn_transaction": turn_transaction_result.duplicate(true),
		"scorecards": evaluated.get("scorecards", []).duplicate(true),
		"fallback_used": fallback_used,
		"public_only": true,
		"stale_plan_has_authority": false,
	}
	if turn_program_request != null or auto_turn_program_shadow:
		audit_payload["turn_program_shadow"] = turn_program_shadow.duplicate(true)
	if auto_turn_program_shadow and turn_program_request == null:
		audit_payload["turn_program_generation"] = turn_program_generation.duplicate(true)
		audit_payload["turn_program_differential"] = turn_program_differential.duplicate(true)
	if turn_program_canary_profile != null:
		audit_payload["turn_program_canary"] = turn_program_canary.duplicate(true)
	var audit := audit_payload.duplicate(true)
	audit["audit_hash"] = _hash(audit_payload)
	return {
		"accepted": true,
		"error_code": "",
		"selected_indexes": selected.duplicate(),
		"audit": audit,
	}


static func _is_option_fact(fact: String) -> bool:
	return (
		fact.begins_with("option.") or fact.begins_with("goal.option.")
		or fact.begins_with("damage.option.") or fact.begins_with("transaction.option.")
	)


static func _store_execution_plan(
	policy_hash: String,
	document: Variant,
	allowed_card_uids: Variant,
	document_prevalidated: bool = false,
) -> bool:
	if _compiled_execution_plans.has(policy_hash):
		return true
	if (
		not document is Dictionary
		or not allowed_card_uids is Dictionary
		or not _is_sha(policy_hash)
		or (not document_prevalidated and not _document_error(document, allowed_card_uids).is_empty())
		or policy_hash != _hash({"profile_id": PROFILE_ID, "document": document})
	):
		return false
	while _compiled_execution_plan_order.size() >= MAX_COMPILED_POLICY_CACHE:
		var evicted_hash: String = _compiled_execution_plan_order.pop_front()
		_compiled_execution_plans.erase(evicted_hash)
	var source: Dictionary = document.duplicate(true)
	var planning_execution_plan_hash := ""
	var planning_registry_sha256 := ""
	if (
		not source.get("damage_plans", []).is_empty()
		or not source.get("semantic_transactions", []).is_empty()
	):
		var planning: Dictionary = DamagePlanningScript.compile_execution_plan(
			policy_hash,
			source.get("damage_plans", []),
			source.get("semantic_transactions", [])
		)
		if not bool(planning.get("accepted", false)):
			return false
		planning_execution_plan_hash = str(planning.get("execution_plan_hash", ""))
		planning_registry_sha256 = str(planning.get("registry_sha256", ""))
	var planned_rules: Array = []
	for rule_value: Variant in source.get("rules", []):
		var rule: Dictionary = rule_value
		var frame_when: Array = []
		var option_when: Array = []
		var bound_option_kind: Variant = null
		for condition_value: Variant in rule.get("when", []):
			var condition: Dictionary = condition_value
			if _is_option_fact(str(condition.get("fact", ""))):
				option_when.append(condition)
				if (
					condition.get("fact") == "option.kind"
					and condition.get("op") == "eq"
					and typeof(condition.get("value")) == TYPE_STRING
				):
					bound_option_kind = condition.get("value")
			else:
				frame_when.append(condition)
		planned_rules.append({
			"rule": rule,
			"frame_when": frame_when,
			"option_when": option_when,
			"bound_option_kind": bound_option_kind,
		})
	var ordered_count_rules: Array = []
	var source_count_rules: Array = source.get("count_rules", [])
	for order: int in source_count_rules.size():
		ordered_count_rules.append({"order": order, "rule": source_count_rules[order]})
	ordered_count_rules.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_rule: Dictionary = left.get("rule")
		var right_rule: Dictionary = right.get("rule")
		if int(left_rule.get("priority")) != int(right_rule.get("priority")):
			return int(left_rule.get("priority")) < int(right_rule.get("priority"))
		return int(left.get("order")) < int(right.get("order"))
	)
	_compiled_execution_plans[policy_hash] = {
		"policy_hash": policy_hash,
		"document": source,
		"rules": planned_rules,
		"count_rules": ordered_count_rules,
		"planning_execution_plan_hash": planning_execution_plan_hash,
		"planning_registry_sha256": planning_registry_sha256,
	}
	_compiled_execution_plan_order.append(policy_hash)
	return true


static func _execution_plan(policy_hash: String) -> Dictionary:
	var value: Variant = _compiled_execution_plans.get(policy_hash)
	return value if value is Dictionary else {}


static func _evaluate_compiled(execution_plan: Dictionary, frame: Dictionary) -> Dictionary:
	var document: Dictionary = execution_plan.get("document", {})
	var goal_result := _goal_states(document, frame)
	var goal_states: Array = goal_result.get("states", [])
	var goals: Dictionary = goal_result.get("by_id", {})
	var threat := _threat_clock(frame)
	var turn_contract_result := _current_turn_contract(document, frame, goals, threat)
	var route_overlays: Array = turn_contract_result.get("overlays", [])
	var frame_facts := _frame_fact_cache(frame)
	var active_rules: Array = []
	for entry_value: Variant in execution_plan.get("rules", []):
		var entry: Dictionary = entry_value
		var rule: Dictionary = entry.get("rule", {})
		var goal: Dictionary = goals.get(rule.get("goal_id"), {})
		if not _matches_cached(entry.get("frame_when", []), frame_facts, null, goal, threat):
			continue
		var resolved_terms: Array = []
		for term_value: Variant in rule.get("score_terms", []):
			var term: Dictionary = term_value
			var option_dependent := _is_option_fact(str(term.get("fact", "")))
			resolved_terms.append({
				"term": term,
				"option_dependent": option_dependent,
				"actual": null if option_dependent else _fact_cached(
					str(term.get("fact")), frame_facts, null, goal, threat, null
				),
			})
		active_rules.append({
			"entry": entry,
			"goal": goal,
			"resolved_terms": resolved_terms,
		})
	var rules_by_option_kind: Dictionary = {}
	for option_value: Variant in frame.get("options", []):
		var option_kind := str(option_value.get("kind", ""))
		if not rules_by_option_kind.has(option_kind):
			rules_by_option_kind[option_kind] = []
	for active_value: Variant in active_rules:
		var active: Dictionary = active_value
		var entry: Dictionary = active.get("entry", {})
		var bound_option_kind: Variant = entry.get("bound_option_kind")
		for option_kind: Variant in rules_by_option_kind:
			if bound_option_kind == null or bound_option_kind == option_kind:
				(rules_by_option_kind[option_kind] as Array).append(active)
	var scorecards: Array = []
	var any_rule_matched := false
	for option_value: Variant in frame.get("options", []):
		var option: Dictionary = option_value
		var total := 0
		var best_priority := 0
		var matched: Array = []
		var base_floor: Variant = _base_tactical_floor(option, frame)
		if base_floor is Dictionary:
			any_rule_matched = true
			total = _clamp_score(total + int(base_floor.get("contribution", 0)))
			matched.append(base_floor)
		for active_value: Variant in rules_by_option_kind.get(str(option.get("kind", "")), []):
			var active: Dictionary = active_value
			var entry: Dictionary = active.get("entry", {})
			var rule: Dictionary = entry.get("rule", {})
			var goal: Dictionary = active.get("goal", {})
			if not _matches_cached(
				entry.get("option_when", []), frame_facts, option, goal, threat
			):
				continue
			any_rule_matched = true
			var raw: int = int(rule.get("base_score", 0))
			for resolved_value: Variant in active.get("resolved_terms", []):
				var resolved: Dictionary = resolved_value
				var term: Dictionary = resolved.get("term", {})
				var actual: Variant = _fact_cached(
					str(term.get("fact")), frame_facts, option, goal, threat, null
				) if bool(resolved.get("option_dependent", false)) else resolved.get("actual")
				if typeof(actual) != TYPE_INT:
					continue
				var bounded := clampi(int(actual), int(term.get("minimum")), int(term.get("maximum")))
				raw = _clamp_score(raw + bounded * int(term.get("coefficient")))
			var contribution := _trunc_div(raw * int(rule.get("confidence_milli")), 1000)
			total = _clamp_score(total + contribution)
			best_priority = maxi(best_priority, int(goal.get("priority", 0)))
			matched.append({
				"rule_id": rule.get("rule_id"),
				"channel": rule.get("channel"),
				"contribution": contribution,
			})
		var proposal_total := total
		var proposal_priority := best_priority
		for overlay_value: Variant in route_overlays:
			var overlay: Dictionary = overlay_value
			if option.get("index") not in overlay.get("indexes", []):
				continue
			any_rule_matched = true
			var contribution := int(overlay.get("contribution", 0))
			total = _clamp_score(total + contribution)
			var overlay_goal: Dictionary = goals.get(overlay.get("goal_id"), {})
			best_priority = maxi(best_priority, int(overlay_goal.get("priority", 0)))
			if overlay.get("channel") != "turn_transaction":
				proposal_total = _clamp_score(proposal_total + contribution)
				proposal_priority = maxi(
					proposal_priority, int(overlay_goal.get("priority", 0))
				)
			matched.append({
				"rule_id": overlay.get("rule_id"),
				"channel": overlay.get("channel"),
				"contribution": contribution,
			})
		scorecards.append({
			"index": option.get("index"),
			"score": total,
			"goal_priority": best_priority,
			"proposal_score": proposal_total,
			"proposal_goal_priority": proposal_priority,
			"matched_rules": matched,
		})
	var ordered_cards := _ordered_scorecards(scorecards, frame)
	var ranked: Array = []
	for card: Dictionary in ordered_cards:
		ranked.append(int(card.get("index")))
	var route_authority_indexes: Array = turn_contract_result.get(
		"contract", {}
	).get("route_authority_indexes", [])
	var route_authority_eligible := (
		not route_authority_indexes.is_empty()
		and _turn_transaction_authority_eligible(
			frame, turn_contract_result.get("contract", {}), scorecards
		)
	)
	turn_contract_result.get("contract", {})["route_authority_eligible"] = route_authority_eligible
	if (
		turn_contract_result.get("contract", {}).get("route_source") == "turn_transaction"
		and not route_authority_eligible
	):
		ranked = _suppress_turn_transaction_overlay(scorecards, frame)
		turn_contract_result.get("contract", {})["turn_transaction_suppressed_reason"] = (
			"independent_noncommit_proposal"
		)
		turn_contract_result["selection_count"] = turn_contract_result.get(
			"contract", {}
		).get("proposal_selection_count")
	if route_authority_eligible:
		var route_ranked: Array = []
		for index: Variant in ranked:
			if index in route_authority_indexes:
				route_ranked.append(index)
		for index: Variant in ranked:
			if index not in route_authority_indexes:
				route_ranked.append(index)
		ranked = route_ranked
	var semantics: Dictionary = frame.get("select_semantics", {})
	var minimum := int(semantics.get("min_count", 0))
	var maximum := int(semantics.get("max_count", 0))
	var desired := minimum
	var count_rule_matched := false
	var selection_quotas: Variant = null
	for entry_value: Variant in execution_plan.get("count_rules", []):
		var entry: Dictionary = entry_value
		var rule: Dictionary = entry.get("rule", {})
		var goal: Dictionary = goals.get(rule.get("goal_id"), {})
		if not _matches_cached(rule.get("when", []), frame_facts, null, goal, threat):
			continue
		if rule.get("mode") == "fixed":
			desired = int(rule.get("fixed_count"))
		elif rule.get("mode") == "goal_energy_debt":
			desired = int(goal.get("energy_debt", 0))
		elif rule.get("mode") == "goal_missing_energy_sources":
			selection_quotas = _goal_missing_energy_source_quotas(goal, frame)
			desired = 0
			for quota_value: Variant in selection_quotas.values():
				desired += int(quota_value)
		elif rule.get("mode") == "distinct_card_uids":
			selection_quotas = _distinct_card_uid_quotas(frame)
			desired = selection_quotas.size()
		else:
			var actual: Variant = _fact_cached(
				str(rule.get("fact")), frame_facts, null, goal, threat, null
			)
			if typeof(actual) != TYPE_INT:
				continue
			var lethal := ceili(float(maxi(0, int(actual))) / float(int(rule.get("divisor"))))
			if rule.get("mode") == "ceil_public_fact_divisor_with_reserve":
				var available: int = frame.get("options", []).size()
				desired = lethal if lethal <= available else maxi(
					0, available - int(rule.get("fixed_count"))
				)
			else:
				desired = lethal
		desired = clampi(desired, minimum, maximum)
		count_rule_matched = true
		break
	if route_authority_eligible and turn_contract_result.get("selection_count") != null:
		desired = clampi(
			int(turn_contract_result.get("selection_count")), minimum, maximum
		)
		count_rule_matched = true
	return {
		"ranked": ranked,
		"desired": desired,
		"scorecards": scorecards,
		"goal_states": goal_states,
		"threat": threat,
		"count_rule_matched": count_rule_matched,
		"any_rule_matched": any_rule_matched,
		"selection_quotas": selection_quotas,
		"turn_contract": turn_contract_result.get("contract", {}).duplicate(true),
	}


static func _frame_fact_cache(frame: Dictionary) -> Dictionary:
	var state: Dictionary = frame.get("public_state", {})
	var own: Dictionary = state.get("self", {})
	var opponent: Dictionary = state.get("opponent", {})
	var turn: Dictionary = own.get("turn", {}) if own.get("turn", {}) is Dictionary else {}
	var scalar := {
		"prompt_kind": frame.get("prompt_kind"),
		"select.type": _enum_name(SELECT_TYPE_NAMES, frame.get("select_semantics", {}).get("select_type_raw")),
		"select.context": _enum_name(SELECT_CONTEXT_NAMES, frame.get("select_semantics", {}).get("select_context_raw")),
		"select.type_raw": frame.get("select_semantics", {}).get("select_type_raw"),
		"select.context_raw": frame.get("select_semantics", {}).get("select_context_raw"),
		"turn_number": state.get("turn_number"),
		"turn.supporter_available": turn.get("supporter_available"),
		"turn.manual_attachment_available": turn.get("manual_attachment_available"),
		"turn.retreat_available": turn.get("retreat_available"),
		"self.prizes_remaining": own.get("prizes_remaining"),
		"opponent.prizes_remaining": opponent.get("prizes_remaining"),
		"self.deck_count": own.get("deck_count"),
		"opponent.deck_count": opponent.get("deck_count"),
		"self.hand_count": own.get("hand", []).size(),
		"opponent.hand_count": opponent.get("hand_count"),
		"self.bench_count": own.get("bench", []).size(),
		"self.bench_capacity": own.get("bench_capacity"),
		"self.bench_space": int(own.get("bench_capacity")) - own.get("bench", []).size() if own.has("bench_capacity") else null,
		"self.bench_open": _bench_open(frame, own),
		"opponent.bench_count": opponent.get("bench", []).size(),
		"self.active.remaining_hp": _active_scalar(own, "remaining_hp"),
		"self.active.prize_value": _active_scalar(own, "prize_value"),
		"self.active.attached_tool_uid": _active_scalar(own, "attached_tool_uid"),
		"opponent.active.remaining_hp": _active_scalar(opponent, "remaining_hp"),
		"opponent.active.prize_value": _active_scalar(opponent, "prize_value"),
		"window.source_uid": _window_uniform(frame, "source_uid"),
		"window.option_kind": _window_uniform(frame, "kind"),
		"window.attack_option_count": _window_kind_count(frame, "attack"),
		"select.min_count": frame.get("select_semantics", {}).get("min_count"),
		"select.max_count": frame.get("select_semantics", {}).get("max_count"),
	}
	var counts: Dictionary = {}
	_add_card_counts(counts, "self.hand.count_uid", own.get("hand", []))
	_add_card_counts(counts, "self.active.count_uid", own.get("active", []))
	_add_card_counts(counts, "self.bench.count_uid", own.get("bench", []))
	_add_evolution_eligible_counts(
		counts, "self.bench.evolution_eligible_count_uid", own.get("bench", []), false
	)
	_add_card_counts(counts, "self.discard.count_uid", own.get("discard", []))
	var own_board: Array = []
	own_board.append_array(own.get("active", []))
	own_board.append_array(own.get("bench", []))
	_add_card_counts(counts, "self.board.count_uid", own_board)
	_add_card_counts(counts, "opponent.active.count_uid", opponent.get("active", []))
	_add_card_counts(counts, "opponent.bench.count_uid", opponent.get("bench", []))
	_add_card_counts(counts, "opponent.discard.count_uid", opponent.get("discard", []))
	var opponent_board: Array = []
	opponent_board.append_array(opponent.get("active", []))
	opponent_board.append_array(opponent.get("bench", []))
	_add_card_counts(counts, "opponent.board.count_uid", opponent_board)
	_add_energy_counts(counts, "self.active.energy_count_uid", own.get("active", []))
	_add_energy_counts(counts, "self.bench.energy_count_uid", own.get("bench", []))
	_add_energy_counts(counts, "self.board.energy_count_uid", own_board)
	_add_energy_counts(counts, "opponent.active.energy_count_uid", opponent.get("active", []))
	_add_energy_counts(counts, "opponent.bench.energy_count_uid", opponent.get("bench", []))
	_add_energy_counts(counts, "opponent.board.energy_count_uid", opponent_board)
	_add_energy_bearing_counts(counts, "self.board.energy_bearing_count_uid", own_board)
	_add_evolution_eligible_counts(
		counts,
		"self.bench.energy_bearing_evolution_eligible_count_uid",
		own.get("bench", []),
		true
	)
	_add_option_uid_counts(counts, frame.get("options", []))
	return {
		"scalar": scalar,
		"counts": counts,
		"frame": frame,
		"goal_option_facts": {},
		"goal_window_facts": {},
	}


static func _add_card_counts(target: Dictionary, fact: String, values: Array) -> void:
	for value: Variant in values:
		var uid: Variant = value.get("local_card_uid")
		var key := _count_cache_key(fact, uid)
		target[key] = int(target.get(key, 0)) + 1


static func _add_energy_counts(target: Dictionary, fact: String, slots: Array) -> void:
	for slot: Variant in slots:
		for uid: Variant in slot.get("attached_energy_uids", []):
			var key := _count_cache_key(fact, uid)
			target[key] = int(target.get(key, 0)) + 1


static func _add_energy_bearing_counts(target: Dictionary, fact: String, slots: Array) -> void:
	for slot: Variant in slots:
		if slot.get("attached_energy_uids", []).is_empty():
			continue
		var key := _count_cache_key(fact, slot.get("local_card_uid"))
		target[key] = int(target.get(key, 0)) + 1


static func _add_evolution_eligible_counts(
	target: Dictionary,
	fact: String,
	slots: Array,
	require_energy: bool,
) -> void:
	for slot: Variant in slots:
		if require_energy and slot.get("attached_energy_uids", []).is_empty():
			continue
		var key := _count_cache_key(fact, slot.get("local_card_uid"))
		target[key] = int(target.get(key, 0)) + 1


static func _add_option_uid_counts(target: Dictionary, options: Array) -> void:
	for option: Variant in options:
		for field: String in ["card_uid", "source_uid", "target_uid"]:
			var uid: Variant = option.get(field)
			if uid == null:
				continue
			var fact := "window.option_count_%s" % field
			var key := _count_cache_key(fact, uid)
			target[key] = int(target.get(key, 0)) + 1


static func _count_cache_key(fact: String, card_uid: Variant) -> String:
	return "%s\u001f%s" % [fact, str(card_uid)]


static func _goal_option_facts_cached(
	goal: Dictionary, frame_facts: Dictionary, option: Dictionary
) -> Dictionary:
	var cache: Dictionary = frame_facts.get("goal_option_facts", {})
	var cache_key := "%s\u001f%d" % [
		goal.get("goal_id", ""), int(option.get("index", -1)),
	]
	if not cache.has(cache_key):
		cache[cache_key] = _goal_option_facts(
			goal, frame_facts.get("frame", {}), option
		)
	return cache.get(cache_key, {})


static func _goal_window_max_progress_cached(
	goal: Dictionary, frame_facts: Dictionary
) -> int:
	var cache: Dictionary = frame_facts.get("goal_window_facts", {})
	var cache_key := "%s:all" % str(goal.get("goal_id", ""))
	if cache.has(cache_key):
		return int(cache.get(cache_key, 0))
	var maximum := 0
	for option_value: Variant in frame_facts.get("frame", {}).get("options", []):
		maximum = maxi(
			maximum,
			int(_goal_option_facts_cached(goal, frame_facts, option_value).get("progress", 0))
		)
	cache[cache_key] = maximum
	return maximum


static func _goal_window_max_setup_progress_cached(
	goal: Dictionary, frame_facts: Dictionary
) -> int:
	var cache: Dictionary = frame_facts.get("goal_window_facts", {})
	var cache_key := "%s:setup" % str(goal.get("goal_id", ""))
	if cache.has(cache_key):
		return int(cache.get(cache_key, 0))
	var maximum := 0
	for option_value: Variant in frame_facts.get("frame", {}).get("options", []):
		var progress := int(
			_goal_option_facts_cached(goal, frame_facts, option_value).get("progress", 0)
		)
		if progress > 0 and progress < 7:
			maximum = maxi(maximum, progress)
	cache[cache_key] = maximum
	return maximum


static func _matches_cached(
	conditions: Array,
	frame_facts: Dictionary,
	option: Variant,
	goal: Dictionary,
	threat: Dictionary,
) -> bool:
	for condition_value: Variant in conditions:
		var condition: Dictionary = condition_value
		var actual: Variant = _fact_cached(
			str(condition.get("fact")), frame_facts, option, goal, threat,
			condition.get("card_uid")
		)
		if not _compare(actual, str(condition.get("op")), condition.get("value")):
			return false
	return true


static func _fact_cached(
	fact: String,
	frame_facts: Dictionary,
	option: Variant,
	goal: Dictionary,
	threat: Dictionary,
	card_uid: Variant,
) -> Variant:
	var derived := _derived_policy_fact(frame_facts.get("frame", {}), option, fact)
	if bool(derived.get("handled", false)):
		return derived.get("value")
	var scalar: Dictionary = frame_facts.get("scalar", {})
	if scalar.has(fact):
		return scalar.get(fact)
	if fact == "goal.energy_debt":
		return goal.get("energy_debt")
	if fact == "goal.ready_count":
		return goal.get("ready_count")
	if fact == "goal.deployed_count":
		return goal.get("deployed_count")
	if fact == "goal.active_ready_count":
		return goal.get("active_ready_count")
	if fact == "goal.bench_ready_count":
		return goal.get("bench_ready_count")
	if fact == "goal.near_ready_count":
		return goal.get("near_ready_count")
	if fact == "goal.complete":
		return int(goal.get("ready_count", 0)) >= int(goal.get("required_target_count", 0))
	if fact in ["goal.board_energy_count", "goal.hand_energy_count", "goal.discard_energy_count"]:
		return _goal_energy_count(goal, frame_facts.get("frame", {}), fact)
	if fact == "goal.immediate":
		if int(goal.get("active_ready_count", 0)) > 0:
			return true
		for current_value: Variant in frame_facts.get("frame", {}).get("options", []):
			if bool(_goal_option_facts_cached(goal, frame_facts, current_value).get("pivots_ready_target", false)):
				return true
		return false
	if GOAL_UID_FACTS.has(fact):
		var field := fact.trim_prefix("goal.").trim_suffix("_uid")
		return int(goal.get("requirement_states", {}).get(card_uid, {}).get(field, 0))
	if fact == "goal.window.max_progress":
		return _goal_window_max_progress_cached(goal, frame_facts)
	if fact == "goal.option.is_max_progress":
		if not option is Dictionary:
			return null
		var route_progress := int(_goal_option_facts_cached(goal, frame_facts, option).get("progress", 0))
		var window_progress := _goal_window_max_progress_cached(goal, frame_facts)
		return window_progress > 0 and route_progress == window_progress
	if fact == "goal.window.max_setup_progress":
		return _goal_window_max_setup_progress_cached(goal, frame_facts)
	if fact == "goal.option.is_max_setup_progress":
		if not option is Dictionary:
			return null
		var route_progress := int(_goal_option_facts_cached(goal, frame_facts, option).get("progress", 0))
		var window_progress := _goal_window_max_setup_progress_cached(goal, frame_facts)
		return window_progress > 0 and route_progress == window_progress
	if fact.begins_with("goal.option."):
		if not option is Dictionary:
			return null
		var route_facts := _goal_option_facts_cached(goal, frame_facts, option)
		return route_facts.get(fact.trim_prefix("goal.option."))
	if fact == "threat.own_attacks_to_win":
		return threat.get("own_attacks_to_win")
	if fact == "threat.opponent_attacks_to_win":
		return threat.get("opponent_attacks_to_win")
	if fact == "threat.tempo_margin":
		return threat.get("tempo_margin")
	if (
		ZONE_FACTS.has(fact)
		or ENERGY_ZONE_FACTS.has(fact)
		or ENERGY_BEARING_ZONE_FACTS.has(fact)
		or WINDOW_UID_FACTS.has(fact)
	):
		return int(frame_facts.get("counts", {}).get(_count_cache_key(fact, card_uid), 0))
	if fact in ["option.source_is_active", "option.target_is_active"]:
		return _option_serial_is_active(
			frame_facts.get("frame", {}), option, fact == "option.source_is_active"
		)
	if fact.begins_with("option."):
		return null if not option is Dictionary else option.get(fact.trim_prefix("option."))
	return null


static func _evaluate(policy: Dictionary, frame: Dictionary) -> Dictionary:
	var document: Dictionary = policy.get("document", {})
	var goal_result := _goal_states(document, frame)
	var goal_states: Array = goal_result.get("states", [])
	var goals: Dictionary = goal_result.get("by_id", {})
	var threat := _threat_clock(frame)
	var turn_contract_result := _current_turn_contract(document, frame, goals, threat)
	var route_overlays: Array = turn_contract_result.get("overlays", [])
	var scorecards: Array = []
	var any_rule_matched := false
	for option_value: Variant in frame.get("options", []):
		var option: Dictionary = option_value
		var total := 0
		var best_priority := 0
		var matched: Array = []
		var base_floor: Variant = _base_tactical_floor(option, frame)
		if base_floor is Dictionary:
			any_rule_matched = true
			total = _clamp_score(total + int(base_floor.get("contribution", 0)))
			matched.append(base_floor)
		for rule_value: Variant in document.get("rules", []):
			var rule: Dictionary = rule_value
			var goal: Dictionary = goals.get(rule.get("goal_id"), {})
			if not _matches(rule.get("when", []), frame, option, goal, threat):
				continue
			any_rule_matched = true
			var raw: int = int(rule.get("base_score", 0))
			for term_value: Variant in rule.get("score_terms", []):
				var term: Dictionary = term_value
				var actual: Variant = _fact(str(term.get("fact")), frame, option, goal, threat, null)
				if typeof(actual) != TYPE_INT:
					continue
				var bounded := clampi(int(actual), int(term.get("minimum")), int(term.get("maximum")))
				raw = _clamp_score(raw + bounded * int(term.get("coefficient")))
			var contribution := _trunc_div(raw * int(rule.get("confidence_milli")), 1000)
			total = _clamp_score(total + contribution)
			best_priority = maxi(best_priority, int(goal.get("priority", 0)))
			matched.append({
				"rule_id": rule.get("rule_id"),
				"channel": rule.get("channel"),
				"contribution": contribution,
			})
		var proposal_total := total
		var proposal_priority := best_priority
		for overlay_value: Variant in route_overlays:
			var overlay: Dictionary = overlay_value
			if option.get("index") not in overlay.get("indexes", []):
				continue
			any_rule_matched = true
			var contribution := int(overlay.get("contribution", 0))
			total = _clamp_score(total + contribution)
			var overlay_goal: Dictionary = goals.get(overlay.get("goal_id"), {})
			best_priority = maxi(best_priority, int(overlay_goal.get("priority", 0)))
			if overlay.get("channel") != "turn_transaction":
				proposal_total = _clamp_score(proposal_total + contribution)
				proposal_priority = maxi(
					proposal_priority, int(overlay_goal.get("priority", 0))
				)
			matched.append({
				"rule_id": overlay.get("rule_id"),
				"channel": overlay.get("channel"),
				"contribution": contribution,
			})
		scorecards.append({
			"index": option.get("index"),
			"score": total,
			"goal_priority": best_priority,
			"proposal_score": proposal_total,
			"proposal_goal_priority": proposal_priority,
			"matched_rules": matched,
		})
	var ordered_cards := _ordered_scorecards(scorecards, frame)
	var ranked: Array = []
	for card: Dictionary in ordered_cards:
		ranked.append(int(card.get("index")))
	var route_authority_indexes: Array = turn_contract_result.get(
		"contract", {}
	).get("route_authority_indexes", [])
	var route_authority_eligible := (
		not route_authority_indexes.is_empty()
		and _turn_transaction_authority_eligible(
			frame, turn_contract_result.get("contract", {}), scorecards
		)
	)
	turn_contract_result.get("contract", {})["route_authority_eligible"] = route_authority_eligible
	if (
		turn_contract_result.get("contract", {}).get("route_source") == "turn_transaction"
		and not route_authority_eligible
	):
		ranked = _suppress_turn_transaction_overlay(scorecards, frame)
		turn_contract_result.get("contract", {})["turn_transaction_suppressed_reason"] = (
			"independent_noncommit_proposal"
		)
		turn_contract_result["selection_count"] = turn_contract_result.get(
			"contract", {}
		).get("proposal_selection_count")
	if route_authority_eligible:
		var route_ranked: Array = []
		for index: Variant in ranked:
			if index in route_authority_indexes:
				route_ranked.append(index)
		for index: Variant in ranked:
			if index not in route_authority_indexes:
				route_ranked.append(index)
		ranked = route_ranked
	var semantics: Dictionary = frame.get("select_semantics", {})
	var minimum := int(semantics.get("min_count", 0))
	var maximum := int(semantics.get("max_count", 0))
	var desired := minimum
	var count_rule_matched := false
	var selection_quotas: Variant = null
	var ordered_count_rules: Array = []
	var source_rules: Array = document.get("count_rules", [])
	for order: int in source_rules.size():
		ordered_count_rules.append({"order": order, "rule": source_rules[order]})
	ordered_count_rules.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_rule: Dictionary = left.get("rule")
		var right_rule: Dictionary = right.get("rule")
		if int(left_rule.get("priority")) != int(right_rule.get("priority")):
			return int(left_rule.get("priority")) < int(right_rule.get("priority"))
		return int(left.get("order")) < int(right.get("order"))
	)
	for entry: Dictionary in ordered_count_rules:
		var rule: Dictionary = entry.get("rule")
		var goal: Dictionary = goals.get(rule.get("goal_id"), {})
		if not _matches(rule.get("when", []), frame, null, goal, threat):
			continue
		if rule.get("mode") == "fixed":
			desired = int(rule.get("fixed_count"))
		elif rule.get("mode") == "goal_energy_debt":
			desired = int(goal.get("energy_debt", 0))
		elif rule.get("mode") == "goal_missing_energy_sources":
			selection_quotas = _goal_missing_energy_source_quotas(goal, frame)
			desired = 0
			for quota_value: Variant in selection_quotas.values():
				desired += int(quota_value)
		elif rule.get("mode") == "distinct_card_uids":
			selection_quotas = _distinct_card_uid_quotas(frame)
			desired = selection_quotas.size()
		else:
			var actual: Variant = _fact(
				str(rule.get("fact")), frame, null, goal, threat, null
			)
			if typeof(actual) != TYPE_INT:
				continue
			var lethal := ceili(float(maxi(0, int(actual))) / float(int(rule.get("divisor"))))
			if rule.get("mode") == "ceil_public_fact_divisor_with_reserve":
				var available: int = frame.get("options", []).size()
				desired = lethal if lethal <= available else maxi(
					0, available - int(rule.get("fixed_count"))
				)
			else:
				desired = lethal
		desired = clampi(desired, minimum, maximum)
		count_rule_matched = true
		break
	if route_authority_eligible and turn_contract_result.get("selection_count") != null:
		desired = clampi(
			int(turn_contract_result.get("selection_count")), minimum, maximum
		)
		count_rule_matched = true
	return {
		"ranked": ranked,
		"desired": desired,
		"scorecards": scorecards,
		"goal_states": goal_states,
		"threat": threat,
		"count_rule_matched": count_rule_matched,
		"any_rule_matched": any_rule_matched,
		"selection_quotas": selection_quotas,
		"turn_contract": turn_contract_result.get("contract", {}).duplicate(true),
	}


static func _ordered_scorecards(scorecards: Array, frame: Dictionary) -> Array:
	var option_kinds: Dictionary = {}
	for option_value: Variant in frame.get("options", []):
		if option_value is Dictionary:
			option_kinds[int(option_value.get("index", -1))] = str(option_value.get("kind", ""))
	var ordered := scorecards.duplicate(true)
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left.get("score")) != int(right.get("score")):
			return int(left.get("score")) > int(right.get("score"))
		if int(left.get("goal_priority")) != int(right.get("goal_priority")):
			return int(left.get("goal_priority")) > int(right.get("goal_priority"))
		var left_end: bool = option_kinds.get(int(left.get("index", -1))) == "end_turn"
		var right_end: bool = option_kinds.get(int(right.get("index", -1))) == "end_turn"
		if left_end != right_end:
			return left_end
		return int(left.get("index")) < int(right.get("index"))
	)
	return ordered


static func _base_tactical_floor(option: Dictionary, frame: Dictionary) -> Variant:
	# Keep this below deck-specific macro scores. The public proof is narrow:
	# a legal positive-damage attack dominates ending the same current window.
	# Effect attacks with zero/unknown projected damage remain adapter-owned.
	if str(option.get("kind", "")) != "attack":
		return null
	var projected_damage: Variant = option.get("projected_damage")
	var option_damage: Dictionary = frame.get("_derived_damage", {}).get(
		"options", {}
	).get(str(option.get("index")), {})
	var bench_damage: Variant = option_damage.get("bench_damage", 0)
	var active_productive := typeof(projected_damage) == TYPE_INT and int(projected_damage) > 0
	var bench_productive := typeof(bench_damage) == TYPE_INT and int(bench_damage) > 0
	if not active_productive and not bench_productive:
		return null
	return {
		"rule_id": "@base.positive-damage-attack",
		"channel": "base",
		"contribution": 1,
	}


static func _turn_transaction_authority_eligible(
	frame: Dictionary, turn_contract: Dictionary, scorecards: Array
) -> bool:
	# A deck transaction proposes an exact current-window debt. In a main
	# window it may veto a normal attack commit, but it must not reorder a
	# better setup action selected independently by the policy. Interaction
	# prompts and an already-active terminal transaction step remain exact.
	if turn_contract.get("route_source") != "turn_transaction":
		return true
	if bool(turn_contract.get("sequence_barrier", false)):
		# Base still owns forced, terminal, hard-tier and veto adjudication;
		# this only preserves a proven non-commutative ordering point.
		return true
	if frame.get("prompt_kind") != "main":
		return true
	var proposals: Array = []
	for card_value: Variant in scorecards:
		var card: Dictionary = card_value.duplicate(true)
		card["score"] = int(card.get("proposal_score", 0))
		card["goal_priority"] = int(card.get("proposal_goal_priority", 0))
		proposals.append(card)
	var ordered := _ordered_scorecards(proposals, frame)
	if ordered.is_empty():
		return false
	var top_index := int(ordered[0].get("index", -1))
	for option_value: Variant in frame.get("options", []):
		if int(option_value.get("index", -1)) == top_index:
			var proposal_kind: Variant = option_value.get("kind")
			if bool(turn_contract.get("terminal", false)):
				return proposal_kind in ["attack", "granted_attack", "end_turn"]
			return (
				bool(turn_contract.get("turn_commit_blocked", false))
				and proposal_kind in ["attack", "granted_attack", "end_turn"]
			)
	return false


static func _suppress_turn_transaction_overlay(
	scorecards: Array, frame: Dictionary
) -> Array:
	for card_index: int in scorecards.size():
		var card: Dictionary = scorecards[card_index]
		card["score"] = int(card.get("proposal_score", 0))
		card["goal_priority"] = int(card.get("proposal_goal_priority", 0))
		var retained_rules: Array = []
		for rule_value: Variant in card.get("matched_rules", []):
			if rule_value.get("channel") != "turn_transaction":
				retained_rules.append(rule_value)
		card["matched_rules"] = retained_rules
		scorecards[card_index] = card
	var ranked: Array = []
	for card_value: Variant in _ordered_scorecards(scorecards, frame):
		ranked.append(int(card_value.get("index", -1)))
	return ranked


static func _executable_route_step(
	steps: Array, frame: Dictionary, goals: Dictionary, threat: Dictionary
) -> Dictionary:
	var semantics: Dictionary = frame.get("select_semantics", {})
	var minimum := int(semantics.get("min_count", 0))
	var maximum := int(semantics.get("max_count", 0))
	for step_value: Variant in steps:
		var step: Dictionary = step_value
		if frame.get("prompt_kind") not in step.get("prompt_kinds", []):
			continue
		var goal: Dictionary = goals.get(step.get("goal_id"), {})
		if not _matches(step.get("when", []), frame, null, goal, threat):
			continue
		var matching: Array = []
		for option_value: Variant in frame.get("options", []):
			var option: Dictionary = option_value
			if _matches(step.get("option_when", []), frame, option, goal, threat):
				matching.append(int(option.get("index", -1)))
		var selection_count: Variant = step.get("selection_count")
		if selection_count != null:
			var exact_count := int(selection_count)
			if exact_count < minimum or exact_count > maximum or exact_count > matching.size():
				continue
			if exact_count == 0:
				return {"step": step, "indexes": []}
		if not matching.is_empty():
			return {"step": step, "indexes": matching}
	return {}


static func _route_budget_rejection(budget: Dictionary, frame: Dictionary) -> String:
	var own: Dictionary = frame.get("public_state", {}).get("self", {})
	var turn: Dictionary = own.get("turn", {}) if own.get("turn", {}) is Dictionary else {}
	if int(budget.get("supporter_uses", 0)) > 0 and turn.get("supporter_available") != true:
		return "supporter_unavailable"
	if (
		int(budget.get("manual_attachments", 0)) > 0
		and turn.get("manual_attachment_available") != true
	):
		return "manual_attachment_unavailable"
	if int(budget.get("retreats", 0)) > 0 and turn.get("retreat_available") != true:
		return "retreat_unavailable"
	if int(budget.get("bench_slots", 0)) > 0:
		var capacity: Variant = own.get("bench_capacity")
		if typeof(capacity) != TYPE_INT:
			return "bench_capacity_unknown"
		if int(capacity) - own.get("bench", []).size() < int(budget.get("bench_slots")):
			return "insufficient_bench_space"
	return ""


static func _route_component_value(
	component: Dictionary,
	frame: Dictionary,
	goal: Dictionary,
	threat: Dictionary,
) -> int:
	var value := int(component.get("base", 0))
	for term_value: Variant in component.get("terms", []):
		var term: Dictionary = term_value
		var actual: Variant = _fact(
			str(term.get("fact")), frame, null, goal, threat, null
		)
		if typeof(actual) != TYPE_INT:
			continue
		var bounded := clampi(
			int(actual), int(term.get("minimum")), int(term.get("maximum"))
		)
		value = _clamp_score(value + bounded * int(term.get("coefficient")))
	return value


static func _route_candidate_less(left: Dictionary, right: Dictionary) -> bool:
	var left_value: Dictionary = left.get("value", {})
	var right_value: Dictionary = right.get("value", {})
	for component_name: String in [
		"attack_windows", "prize_progress", "continuity", "resource_cost",
		"response_risk", "uncertainty",
	]:
		var left_part := int(left_value.get(component_name, 0))
		var right_part := int(right_value.get(component_name, 0))
		if left_part == right_part:
			continue
		if component_name in ["prize_progress", "continuity"]:
			return left_part > right_part
		return left_part < right_part
	var left_id := str(left.get("route", {}).get("route_id", ""))
	var right_id := str(right.get("route", {}).get("route_id", ""))
	if left_id != right_id:
		return left_id < right_id
	return int(left.get("order", 0)) < int(right.get("order", 0))


static func _route_candidate_adjudication(
	document: Dictionary, frame: Dictionary, goals: Dictionary, threat: Dictionary
) -> Dictionary:
	var considered: Array = []
	var proposals: Array = []
	var source_candidates: Array = document.get("route_candidates", [])
	for order: int in source_candidates.size():
		var route: Dictionary = source_candidates[order]
		var goal: Dictionary = goals.get(route.get("goal_id"), {})
		var row := {
			"route_id": route.get("route_id"),
			"accepted": false,
			"selected": false,
			"rejection_reason": "",
			"first_executable_step_id": null,
			"current_indexes": [],
			"value": null,
		}
		if not _matches(route.get("when", []), frame, null, goal, threat):
			row["rejection_reason"] = "route_guard_unmatched"
			considered.append(row)
			continue
		var rejection := _route_budget_rejection(route.get("resource_budget", {}), frame)
		if not rejection.is_empty():
			row["rejection_reason"] = rejection
			considered.append(row)
			continue
		var executable := _executable_route_step(route.get("steps", []), frame, goals, threat)
		if executable.is_empty():
			row["rejection_reason"] = "no_current_executable_step"
			considered.append(row)
			continue
		var step: Dictionary = executable.get("step", {})
		var route_value := {}
		for component_name: String in ROUTE_VALUE_COMPONENTS:
			route_value[component_name] = _route_component_value(
				route.get("value", {}).get(component_name, {}), frame, goal, threat
			)
		row.merge({
			"accepted": true,
			"first_executable_step_id": step.get("step_id"),
			"current_indexes": executable.get("indexes", []).duplicate(),
			"value": route_value.duplicate(true),
		}, true)
		considered.append(row)
		proposals.append({
			"route": route,
			"step": step,
			"indexes": executable.get("indexes", []).duplicate(),
			"value": route_value,
			"order": order,
		})
	var selected_route: Variant = null
	var selected_step: Variant = null
	var selected_indexes: Array = []
	var selected_value: Variant = null
	if not proposals.is_empty():
		proposals.sort_custom(_route_candidate_less)
		var selected: Dictionary = proposals[0]
		selected_route = selected.get("route")
		selected_step = selected.get("step")
		selected_indexes = selected.get("indexes", []).duplicate()
		selected_value = selected.get("value", {}).duplicate(true)
		var selected_order := int(selected.get("order", 0))
		var selected_row: Dictionary = considered[selected_order]
		selected_row["selected"] = true
		considered[selected_order] = selected_row
	return {
		"route": selected_route,
		"step": selected_step,
		"indexes": selected_indexes,
		"audit": {
			"comparison_order": [
				"attack_windows.asc", "prize_progress.desc", "continuity.desc",
				"resource_cost.asc", "response_risk.asc", "uncertainty.asc",
				"route_id.asc",
			],
			"considered_routes": considered,
			"selected_route_id": null if selected_route == null else selected_route.get("route_id"),
			"selected_step_id": null if selected_step == null else selected_step.get("step_id"),
			"selected_value": selected_value,
			"public_current_window_only": true,
		},
	}


static func _current_turn_contract(
	document: Dictionary, frame: Dictionary, goals: Dictionary, threat: Dictionary
) -> Dictionary:
	var own: Dictionary = frame.get("public_state", {}).get("self", {})
	var ledger: Dictionary = own.get("turn", {}).duplicate(true) \
		if own.get("turn", {}) is Dictionary else {}
	var contract := {
		"route_id": null,
		"route_source": null,
		"route_goal_id": null,
		"owner_goal_id": null,
		"bridge_goal_id": null,
		"pivot_goal_id": null,
		"first_executable_step_id": null,
		"interaction_recipe_id": null,
		"interaction_step_id": null,
		"terminal": false,
		"checkpoint": false,
		"sequence_barrier": false,
		"selection_count": null,
		"turn_ledger": ledger,
		"route_authority_indexes": [],
		"route_authority_eligible": false,
		"route_authority_applied": false,
		"route_candidate_adjudication": {},
		"current_window_only": true,
		"reobserve_after_commit": true,
		"stale_index_authority": false,
	}
	var overlays: Array = []
	var route_selection_count: Variant = null
	var selected_route: Variant = null
	var transaction_contract_update: Variant = null
	var transaction_selection_count: Variant = null
	var turn_transaction: Dictionary = frame.get("_derived_turn_transaction", {})
	var transaction_indexes: Array = turn_transaction.get("current_indexes", []).duplicate()
	if not transaction_indexes.is_empty():
		var transaction_id := str(turn_transaction.get("transaction_id", ""))
		var method_id := str(turn_transaction.get("method_id", ""))
		var step_id := str(turn_transaction.get("step_id", ""))
		var goal_id := str(turn_transaction.get("goal_id", ""))
		var transaction_route := {
			"route_id": "turn-transaction.%s" % transaction_id,
			"goal_id": goal_id,
		}
		transaction_selection_count = turn_transaction.get("selection_count")
		transaction_contract_update = {
			"route_id": transaction_route.get("route_id"),
			"route_source": "turn_transaction",
			"route_goal_id": goal_id,
			"owner_goal_id": goal_id,
			"bridge_goal_id": goal_id,
			"pivot_goal_id": goal_id,
			"first_executable_step_id": step_id,
			"terminal": bool(turn_transaction.get("terminal", false)),
			"checkpoint": bool(turn_transaction.get("checkpoint", false)),
			"sequence_barrier": bool(
				turn_transaction.get("sequence_barrier", false)
			),
			"selection_count": transaction_selection_count,
			"route_authority_indexes": transaction_indexes.duplicate(),
			"turn_transaction_id": transaction_id,
			"turn_transaction_method_id": method_id,
			"attack_commit_blocked": bool(
				turn_transaction.get("attack_commit_blocked", false)
			),
			"turn_commit_blocked": bool(
				turn_transaction.get("turn_commit_blocked", false)
			),
		}
		overlays.append({
			"rule_id": "@turn_transaction.%s.%s.%s" % [
				transaction_id, method_id, step_id,
			],
			"channel": "turn_transaction",
			"contribution": int(turn_transaction.get("score_bonus", 0)),
			"goal_id": goal_id,
			"indexes": transaction_indexes.duplicate(),
		})
	var candidate_result := _route_candidate_adjudication(document, frame, goals, threat)
	contract["route_candidate_adjudication"] = candidate_result.get("audit", {}).duplicate(true)
	if selected_route == null and candidate_result.get("route") is Dictionary \
		and candidate_result.get("step") is Dictionary:
		var candidate_route: Dictionary = candidate_result.get("route")
		var candidate_step: Dictionary = candidate_result.get("step")
		selected_route = candidate_route
		route_selection_count = candidate_step.get("selection_count")
		contract.merge({
			"route_id": candidate_route.get("route_id"),
			"route_source": "route_candidate",
			"route_goal_id": candidate_route.get("goal_id"),
			"owner_goal_id": candidate_route.get("owner_goal_id"),
			"bridge_goal_id": candidate_route.get("bridge_goal_id"),
			"pivot_goal_id": candidate_route.get("pivot_goal_id"),
			"first_executable_step_id": candidate_step.get("step_id"),
			"terminal": bool(candidate_step.get("terminal", false)),
			"checkpoint": bool(candidate_step.get("checkpoint", false)),
			"selection_count": route_selection_count,
			"route_authority_indexes": candidate_result.get("indexes", []).duplicate(),
		}, true)
		overlays.append({
			"rule_id": "@route_candidate.%s.%s" % [
				candidate_route.get("route_id"), candidate_step.get("step_id")
			],
			"channel": "route_candidate",
			"contribution": 0,
			"goal_id": candidate_step.get("goal_id"),
			"indexes": candidate_result.get("indexes", []).duplicate(),
		})
	var ordered_routes: Array = []
	var source_routes: Array = document.get("turn_routes", [])
	for order: int in source_routes.size():
		ordered_routes.append({"order": order, "route": source_routes[order]})
	ordered_routes.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_route: Dictionary = left.get("route", {})
		var right_route: Dictionary = right.get("route", {})
		if int(left_route.get("priority", 0)) != int(right_route.get("priority", 0)):
			return int(left_route.get("priority", 0)) > int(right_route.get("priority", 0))
		return int(left.get("order", 0)) < int(right.get("order", 0))
	)
	for entry_value: Variant in ordered_routes if selected_route == null else []:
		var route: Dictionary = entry_value.get("route", {})
		var route_goal: Dictionary = goals.get(route.get("goal_id"), {})
		if not _matches(route.get("when", []), frame, null, route_goal, threat):
			continue
		var executable := _executable_route_step(
			route.get("steps", []), frame, goals, threat
		)
		if executable.is_empty():
			continue
		var step: Dictionary = executable.get("step", {})
		selected_route = route
		route_selection_count = step.get("selection_count")
		contract.merge({
			"route_id": route.get("route_id"),
			"route_source": "turn_route",
			"route_goal_id": route.get("goal_id"),
			"owner_goal_id": route.get("owner_goal_id"),
			"bridge_goal_id": route.get("bridge_goal_id"),
			"pivot_goal_id": route.get("pivot_goal_id"),
			"first_executable_step_id": step.get("step_id"),
			"terminal": bool(step.get("terminal", false)),
			"checkpoint": bool(step.get("checkpoint", false)),
			"selection_count": route_selection_count,
		}, true)
		overlays.append({
			"rule_id": "@turn_route.%s.%s" % [route.get("route_id"), step.get("step_id")],
			"channel": "route",
			"contribution": int(step.get("score_bonus", 0)),
			"goal_id": step.get("goal_id"),
			"indexes": executable.get("indexes", []).duplicate(),
		})
		break
	var source_uid: Variant = _window_uniform(frame, "source_uid")
	var ordered_recipes: Array = []
	var source_recipes: Array = document.get("interaction_recipes", [])
	for order: int in source_recipes.size():
		ordered_recipes.append({"order": order, "recipe": source_recipes[order]})
	ordered_recipes.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_recipe: Dictionary = left.get("recipe", {})
		var right_recipe: Dictionary = right.get("recipe", {})
		if int(left_recipe.get("priority", 0)) != int(right_recipe.get("priority", 0)):
			return int(left_recipe.get("priority", 0)) > int(right_recipe.get("priority", 0))
		return int(left.get("order", 0)) < int(right.get("order", 0))
	)
	for entry_value: Variant in ordered_recipes:
		var recipe: Dictionary = entry_value.get("recipe", {})
		if source_uid not in recipe.get("source_uids", []):
			continue
		if recipe.get("route_id") != null and (
			selected_route == null
			or selected_route.get("route_id") != recipe.get("route_id")
		):
			continue
		var recipe_goal: Dictionary = goals.get(recipe.get("goal_id"), {})
		if not _matches(recipe.get("when", []), frame, null, recipe_goal, threat):
			continue
		var executable := _executable_route_step(
			recipe.get("steps", []), frame, goals, threat
		)
		if executable.is_empty():
			continue
		var step: Dictionary = executable.get("step", {})
		if step.get("selection_count") != null:
			route_selection_count = step.get("selection_count")
			contract["selection_count"] = route_selection_count
		contract["interaction_recipe_id"] = recipe.get("recipe_id")
		contract["interaction_step_id"] = step.get("step_id")
		contract["terminal"] = bool(contract.get("terminal", false)) \
			or bool(step.get("terminal", false))
		contract["checkpoint"] = bool(contract.get("checkpoint", false)) \
			or bool(step.get("checkpoint", false))
		overlays.append({
			"rule_id": "@interaction_recipe.%s.%s" % [
				recipe.get("recipe_id"), step.get("step_id")
			],
			"channel": "interaction_recipe",
			"contribution": int(step.get("score_bonus", 0)),
			"goal_id": step.get("goal_id"),
			"indexes": executable.get("indexes", []).duplicate(),
		})
		break
	if not bool(contract.get("terminal", false)):
		var ordered_contracts: Array = []
		var source_contracts: Array = document.get("turn_bonus_contracts", [])
		for order: int in source_contracts.size():
			ordered_contracts.append({"order": order, "contract": source_contracts[order]})
		ordered_contracts.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			var left_contract: Dictionary = left.get("contract", {})
			var right_contract: Dictionary = right.get("contract", {})
			if int(left_contract.get("priority", 0)) != int(right_contract.get("priority", 0)):
				return int(left_contract.get("priority", 0)) > int(right_contract.get("priority", 0))
			return int(left.get("order", 0)) < int(right.get("order", 0))
		)
		for entry_value: Variant in ordered_contracts:
			var bonus_contract: Dictionary = entry_value.get("contract", {})
			var contract_goal: Dictionary = goals.get(bonus_contract.get("goal_id"), {})
			if not _matches(
				bonus_contract.get("when", []), frame, null, contract_goal, threat
			):
				continue
			var matched_bonus_ids: Array = []
			for bonus_value: Variant in bonus_contract.get("bonuses", []):
				var bonus: Dictionary = bonus_value
				if frame.get("prompt_kind") not in bonus.get("prompt_kinds", []):
					continue
				var bonus_goal: Dictionary = goals.get(bonus.get("goal_id"), {})
				if not _matches(bonus.get("when", []), frame, null, bonus_goal, threat):
					continue
				var indexes: Array = []
				for option_value: Variant in frame.get("options", []):
					var option: Dictionary = option_value
					if _matches(
						bonus.get("option_when", []), frame, option, bonus_goal, threat
					):
						indexes.append(int(option.get("index", -1)))
				if indexes.is_empty():
					continue
				matched_bonus_ids.append(bonus.get("bonus_id"))
				overlays.append({
					"rule_id": "@turn_bonus.%s.%s" % [
						bonus_contract.get("contract_id"), bonus.get("bonus_id")
					],
					"channel": "turn_bonus",
					"contribution": int(bonus.get("score_bonus", 0)),
					"goal_id": bonus.get("goal_id"),
					"indexes": indexes,
				})
			if not matched_bonus_ids.is_empty():
				contract["turn_bonus_contract_id"] = bonus_contract.get("contract_id")
				contract["turn_bonus_ids"] = matched_bonus_ids
				break
	if transaction_contract_update is Dictionary:
		# Keep the independent route/bonus proposal intact until the commit
		# arbiter decides whether this transaction debt owns the window.
		contract["proposal_route_id"] = contract.get("route_id")
		contract["proposal_route_source"] = contract.get("route_source")
		contract["proposal_selection_count"] = route_selection_count
		contract["proposal_route_authority_indexes"] = contract.get(
			"route_authority_indexes", []
		).duplicate()
		contract.merge(transaction_contract_update, true)
		route_selection_count = transaction_selection_count
	return {
		"contract": contract,
		"overlays": overlays,
		"selection_count": route_selection_count,
	}


static func _goal_states(document: Dictionary, frame: Dictionary) -> Dictionary:
	var state: Dictionary = frame.get("public_state", {}).get("self", {})
	var slots: Array = []
	slots.append_array(state.get("active", []))
	slots.append_array(state.get("bench", []))
	var active_serials := {}
	for active_value: Variant in state.get("active", []):
		active_serials[active_value.get("serial")] = true
	var states: Array = []
	var by_id := {}
	for goal_value: Variant in document.get("goals", []):
		var goal: Dictionary = goal_value
		var deployed := 0
		var ready := 0
		var debt := 0
		var active_ready := 0
		var bench_ready := 0
		var near_ready := 0
		var requirement_states := {}
		var energy_uids := {}
		for requirement_value: Variant in goal.get("requirements", []):
			var requirement: Dictionary = requirement_value
			for energy_value: Variant in requirement.get("energy_requirements", []):
				energy_uids[energy_value.get("energy_uid")] = true
			var matches: Array = []
			for slot_value: Variant in slots:
				if slot_value.get("local_card_uid") == requirement.get("card_uid"):
					matches.append(slot_value)
			matches.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
				var left_debt := _requirement_slot_debt(requirement, left)
				var right_debt := _requirement_slot_debt(requirement, right)
				if left_debt != right_debt:
					return left_debt < right_debt
				if int(left.get("attached_energy_count")) != int(right.get("attached_energy_count")):
					return int(left.get("attached_energy_count")) > int(right.get("attached_energy_count"))
				return int(left.get("serial")) < int(right.get("serial"))
			)
			matches = matches.slice(0, int(requirement.get("ready_target_count")))
			var deployed_count := matches.size()
			var ready_count := 0
			var requirement_debt := 0
			var near_ready_count := 0
			var active_ready_count := 0
			for slot: Dictionary in matches:
				var slot_debt := _requirement_slot_debt(requirement, slot)
				if _requirement_slot_ready(requirement, slot):
					ready_count += 1
					if active_serials.has(slot.get("serial")):
						active_ready_count += 1
				if slot_debt <= 1:
					near_ready_count += 1
				requirement_debt += slot_debt
			var bench_ready_count := ready_count - active_ready_count
			deployed += deployed_count
			ready += ready_count
			debt += requirement_debt
			active_ready += active_ready_count
			bench_ready += bench_ready_count
			near_ready += near_ready_count
			requirement_states[requirement.get("card_uid")] = {
				"deployed_count": deployed_count,
				"ready_count": ready_count,
				"near_ready_count": near_ready_count,
				"energy_debt": requirement_debt,
				"active_ready_count": active_ready_count,
				"bench_ready_count": bench_ready_count,
			}
		var goal_state := {
			"goal_id": goal.get("goal_id"),
			"stage": goal.get("stage"),
			"priority": goal.get("priority"),
			"deployed_count": deployed,
			"ready_count": ready,
			"energy_debt": debt,
			"active_ready_count": active_ready,
			"bench_ready_count": bench_ready,
			"near_ready_count": near_ready,
		}
		states.append(goal_state)
		by_id[goal.get("goal_id")] = {
			"goal_id": goal.get("goal_id"),
			"priority": int(goal.get("priority")),
			"deployed_count": deployed,
			"ready_count": ready,
			"energy_debt": debt,
			"active_ready_count": active_ready,
			"bench_ready_count": bench_ready,
			"near_ready_count": near_ready,
			"requirement_states": requirement_states,
			"energy_uids": energy_uids.keys(),
			"required_target_count": _goal_required_target_count(goal),
			"requirements": goal.get("requirements", []).duplicate(true),
		}
	return {"states": states, "by_id": by_id}


static func _requirement_slot_debt(requirement: Dictionary, slot: Dictionary) -> int:
	var attached := int(slot.get("attached_energy_count", 0))
	var generic_debt := maxi(0, int(requirement.get("energy_required", 0)) - attached)
	var typed_debt := 0
	var attached_uids: Array = slot.get("attached_energy_uids", [])
	for typed_value: Variant in requirement.get("energy_requirements", []):
		var typed: Dictionary = typed_value
		typed_debt += maxi(
			0,
			int(typed.get("count", 0)) - attached_uids.count(typed.get("energy_uid"))
		)
	return maxi(generic_debt, typed_debt)


static func _requirement_slot_ready(requirement: Dictionary, slot: Dictionary) -> bool:
	if _requirement_slot_debt(requirement, slot) != 0:
		return false
	if requirement.get("attack_index") != null:
		return true
	if requirement.get("ability_index") != null:
		return true
	return bool(slot.get("attack_ready", false))


static func _goal_required_target_count(goal: Dictionary) -> int:
	var total := 0
	for requirement_value: Variant in goal.get("requirements", []):
		total += int(requirement_value.get("ready_target_count", 0))
	return total


static func _self_slots(frame: Dictionary) -> Array:
	var own: Dictionary = frame.get("public_state", {}).get("self", {})
	var slots: Array = []
	slots.append_array(own.get("active", []))
	slots.append_array(own.get("bench", []))
	return slots


static func _target_slot(frame: Dictionary, option: Dictionary) -> Variant:
	var slots := _self_slots(frame)
	var target_serial: Variant = option.get("target_serial")
	var target_uid: Variant = option.get("target_uid")
	if target_serial != null:
		for slot_value: Variant in slots:
			if slot_value.get("serial") == target_serial:
				return slot_value
	if target_uid != null:
		for slot_value: Variant in slots:
			if slot_value.get("local_card_uid") == target_uid:
				return slot_value
	return null


static func _energy_uid_needed(
	requirement: Dictionary, slot: Variant, energy_uid: Variant
) -> bool:
	if typeof(energy_uid) != TYPE_STRING:
		return false
	var typed: Array = requirement.get("energy_requirements", [])
	if not typed.is_empty():
		var attached_uids: Array = [] if slot == null else slot.get("attached_energy_uids", [])
		for typed_value: Variant in typed:
			if (
				typed_value.get("energy_uid") == energy_uid
				and attached_uids.count(energy_uid) < int(typed_value.get("count", 0))
			):
				return true
		return false
	if slot == null:
		return int(requirement.get("energy_required", 0)) > 0
	return int(slot.get("attached_energy_count", 0)) < int(requirement.get("energy_required", 0))


static func _goal_missing_energy_source_quotas(
	goal: Dictionary, frame: Dictionary
) -> Dictionary:
	var slots := _self_slots(frame)
	var debt_by_uid := {}
	for requirement_value: Variant in goal.get("requirements", []):
		var requirement: Dictionary = requirement_value
		var typed: Array = requirement.get("energy_requirements", [])
		if typed.is_empty():
			continue
		var matches: Array = []
		for slot_value: Variant in slots:
			if slot_value.get("local_card_uid") == requirement.get("card_uid"):
				matches.append(slot_value)
		matches.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			var left_debt := _requirement_slot_debt(requirement, left)
			var right_debt := _requirement_slot_debt(requirement, right)
			if left_debt != right_debt:
				return left_debt < right_debt
			var left_energy := int(left.get("attached_energy_count", 0))
			var right_energy := int(right.get("attached_energy_count", 0))
			if left_energy != right_energy:
				return left_energy > right_energy
			return int(left.get("serial", 0)) < int(right.get("serial", 0))
		)
		var target_count := mini(matches.size(), int(requirement.get("ready_target_count", 0)))
		for target_index: int in target_count:
			var slot: Dictionary = matches[target_index]
			var attached_uids: Array = slot.get("attached_energy_uids", [])
			for typed_value: Variant in typed:
				var uid := str(typed_value.get("energy_uid", ""))
				var debt := maxi(0, int(typed_value.get("count", 0)) - attached_uids.count(uid))
				debt_by_uid[uid] = int(debt_by_uid.get(uid, 0)) + debt
	var available_by_uid := {}
	for option_value: Variant in frame.get("options", []):
		var uid: Variant = option_value.get("card_uid")
		if typeof(uid) == TYPE_STRING:
			available_by_uid[uid] = int(available_by_uid.get(uid, 0)) + 1
	var quotas := {}
	for uid_value: Variant in debt_by_uid:
		var debt := int(debt_by_uid.get(uid_value, 0))
		var available := int(available_by_uid.get(uid_value, 0))
		if debt > 0 and available > 0:
			quotas[uid_value] = mini(debt, available)
	return quotas


static func _distinct_card_uid_quotas(frame: Dictionary) -> Dictionary:
	var quotas := {}
	for option_value: Variant in frame.get("options", []):
		var uid: Variant = option_value.get("card_uid")
		if typeof(uid) == TYPE_STRING and not uid.is_empty():
			quotas[uid] = 1
	return quotas


static func _slot_after_energy(slot: Dictionary, energy_uid: String) -> Dictionary:
	var projected: Dictionary = slot.duplicate(true)
	projected["attached_energy_count"] = int(slot.get("attached_energy_count", 0)) + 1
	var attached_uids: Array = slot.get("attached_energy_uids", []).duplicate()
	attached_uids.append(energy_uid)
	projected["attached_energy_uids"] = attached_uids
	return projected


static func _goal_option_facts(
	goal: Dictionary, frame: Dictionary, option: Variant
) -> Dictionary:
	var facts := {
		"matches_target": false,
		"acquires_missing_target": false,
		"deploys_missing_target": false,
		"supplies_missing_energy": false,
		"funds_target": false,
		"completes_target": false,
		"pivots_ready_target": false,
		"executes_requirement": false,
		"target_energy_debt": null,
		"progress": 0,
	}
	if not option is Dictionary:
		return facts
	var current: Dictionary = option
	var kind := str(current.get("kind", ""))
	var slots := _self_slots(frame)
	var target_value: Variant = _target_slot(frame, current)
	var target_uid: Variant = current.get("target_uid")
	var source_uid: Variant = current.get("source_uid")
	var card_uid: Variant = current.get("card_uid")
	for requirement_value: Variant in goal.get("requirements", []):
		var requirement: Dictionary = requirement_value
		var uid: Variant = requirement.get("card_uid")
		var matches: Array = []
		for slot_value: Variant in slots:
			if slot_value.get("local_card_uid") == uid:
				matches.append(slot_value)
		var missing_target: bool = matches.size() < int(requirement.get("ready_target_count", 0))
		var target_matches: bool = target_uid == uid and target_value is Dictionary
		if target_matches:
			facts["matches_target"] = true
			var target_debt := _requirement_slot_debt(requirement, target_value)
			if facts.get("target_energy_debt") == null:
				facts["target_energy_debt"] = target_debt
			else:
				facts["target_energy_debt"] = mini(
					int(facts.get("target_energy_debt")), target_debt
				)
		if kind == "search" and missing_target and card_uid == uid:
			facts["acquires_missing_target"] = true
		if kind in ["setup_active", "setup_bench", "play_basic_to_bench", "evolve"] \
				and missing_target and card_uid == uid:
			facts["deploys_missing_target"] = true
		if frame.get("prompt_kind") in ["search", "assignment_source"]:
			var energy_targets: Array = matches if not matches.is_empty() else [null]
			for energy_target: Variant in energy_targets:
				if _energy_uid_needed(requirement, energy_target, card_uid):
					facts["supplies_missing_energy"] = true
					break
		if kind in ["attach_energy", "assignment_target"] and target_matches \
				and _energy_uid_needed(requirement, target_value, card_uid):
			facts["funds_target"] = true
			var projected := _slot_after_energy(target_value, str(card_uid))
			if _requirement_slot_debt(requirement, projected) == 0:
				facts["completes_target"] = true
		if kind in ["retreat", "send_out"] and target_matches \
				and _requirement_slot_ready(requirement, target_value):
			facts["pivots_ready_target"] = true
		if kind in ["attack", "granted_attack"] and source_uid == uid:
			var declared_attack: Variant = requirement.get("attack_index")
			if declared_attack != null and current.get("attack_index") == declared_attack:
				var source_slot: Variant = null
				for slot_value: Variant in slots:
					if slot_value.get("serial") == current.get("source_serial"):
						source_slot = slot_value
						break
				if source_slot is Dictionary and _requirement_slot_ready(requirement, source_slot):
					facts["executes_requirement"] = true
		if kind == "use_ability" and source_uid == uid:
			var declared_ability: Variant = requirement.get("ability_index")
			if declared_ability != null and current.get("ability_index") == declared_ability:
				facts["executes_requirement"] = true
	var progress_levels := [
		["executes_requirement", 7],
		["pivots_ready_target", 6],
		["completes_target", 5],
		["funds_target", 4],
		["supplies_missing_energy", 3],
		["deploys_missing_target", 2],
		["acquires_missing_target", 1],
	]
	for entry: Array in progress_levels:
		if bool(facts.get(entry[0], false)):
			facts["progress"] = entry[1]
			break
	return facts


static func _goal_window_max_progress(goal: Dictionary, frame: Dictionary) -> int:
	var maximum := 0
	for option_value: Variant in frame.get("options", []):
		maximum = maxi(
			maximum,
			int(_goal_option_facts(goal, frame, option_value).get("progress", 0))
		)
	return maximum


static func _goal_window_max_setup_progress(goal: Dictionary, frame: Dictionary) -> int:
	var maximum := 0
	for option_value: Variant in frame.get("options", []):
		var progress := int(_goal_option_facts(goal, frame, option_value).get("progress", 0))
		if progress > 0 and progress < 7:
			maximum = maxi(maximum, progress)
	return maximum


static func _threat_clock(frame: Dictionary) -> Dictionary:
	var own: Dictionary = frame.get("public_state", {}).get("self", {})
	var opponent: Dictionary = frame.get("public_state", {}).get("opponent", {})
	var opponent_targets: Array = []
	opponent_targets.append_array(opponent.get("active", []))
	opponent_targets.append_array(opponent.get("bench", []))
	var own_targets: Array = []
	own_targets.append_array(own.get("active", []))
	own_targets.append_array(own.get("bench", []))
	var opponent_yield := 1
	for slot: Dictionary in opponent_targets:
		opponent_yield = maxi(opponent_yield, int(slot.get("prize_value", 1)))
	var own_yield := 1
	for slot: Dictionary in own_targets:
		own_yield = maxi(own_yield, int(slot.get("prize_value", 1)))
	var own_prizes := int(own.get("prizes_remaining", 0))
	var opponent_prizes := int(opponent.get("prizes_remaining", 0))
	var own_attacks := ceili(float(own_prizes) / float(maxi(1, opponent_yield)))
	var opponent_attacks := ceili(float(opponent_prizes) / float(maxi(1, own_yield)))
	return {
		"own_attacks_to_win": own_attacks,
		"opponent_attacks_to_win": opponent_attacks,
		"tempo_margin": opponent_attacks - own_attacks,
	}


static func _matches(
	conditions: Array,
	frame: Dictionary,
	option: Variant,
	goal: Dictionary,
	threat: Dictionary,
) -> bool:
	for condition_value: Variant in conditions:
		var condition: Dictionary = condition_value
		var actual: Variant = _fact(
			str(condition.get("fact")), frame, option, goal, threat, condition.get("card_uid")
		)
		if not _compare(actual, str(condition.get("op")), condition.get("value")):
			return false
	return true


static func _fact(
	fact: String,
	frame: Dictionary,
	option: Variant,
	goal: Dictionary,
	threat: Dictionary,
	card_uid: Variant,
) -> Variant:
	var derived := _derived_policy_fact(frame, option, fact)
	if bool(derived.get("handled", false)):
		return derived.get("value")
	var state: Dictionary = frame.get("public_state", {})
	var own: Dictionary = state.get("self", {})
	var opponent: Dictionary = state.get("opponent", {})
	var turn: Dictionary = own.get("turn", {}) if own.get("turn", {}) is Dictionary else {}
	var scalar := {
		"prompt_kind": frame.get("prompt_kind"),
		"select.type": _enum_name(SELECT_TYPE_NAMES, frame.get("select_semantics", {}).get("select_type_raw")),
		"select.context": _enum_name(SELECT_CONTEXT_NAMES, frame.get("select_semantics", {}).get("select_context_raw")),
		"select.type_raw": frame.get("select_semantics", {}).get("select_type_raw"),
		"select.context_raw": frame.get("select_semantics", {}).get("select_context_raw"),
		"turn_number": state.get("turn_number"),
		"turn.supporter_available": turn.get("supporter_available"),
		"turn.manual_attachment_available": turn.get("manual_attachment_available"),
		"turn.retreat_available": turn.get("retreat_available"),
		"self.prizes_remaining": own.get("prizes_remaining"),
		"opponent.prizes_remaining": opponent.get("prizes_remaining"),
		"self.deck_count": own.get("deck_count"),
		"opponent.deck_count": opponent.get("deck_count"),
		"self.hand_count": own.get("hand", []).size(),
		"opponent.hand_count": opponent.get("hand_count"),
		"self.bench_count": own.get("bench", []).size(),
		"self.bench_capacity": own.get("bench_capacity"),
		"self.bench_space": int(own.get("bench_capacity")) - own.get("bench", []).size() if own.has("bench_capacity") else null,
		"self.bench_open": _bench_open(frame, own),
		"opponent.bench_count": opponent.get("bench", []).size(),
		"self.active.remaining_hp": _active_scalar(own, "remaining_hp"),
		"self.active.prize_value": _active_scalar(own, "prize_value"),
		"self.active.attached_tool_uid": _active_scalar(own, "attached_tool_uid"),
		"opponent.active.remaining_hp": _active_scalar(opponent, "remaining_hp"),
		"opponent.active.prize_value": _active_scalar(opponent, "prize_value"),
		"window.source_uid": _window_uniform(frame, "source_uid"),
		"window.option_kind": _window_uniform(frame, "kind"),
		"window.attack_option_count": _window_kind_count(frame, "attack"),
		"select.min_count": frame.get("select_semantics", {}).get("min_count"),
		"select.max_count": frame.get("select_semantics", {}).get("max_count"),
		"goal.energy_debt": goal.get("energy_debt"),
		"goal.ready_count": goal.get("ready_count"),
		"goal.deployed_count": goal.get("deployed_count"),
		"goal.active_ready_count": goal.get("active_ready_count"),
		"goal.bench_ready_count": goal.get("bench_ready_count"),
		"goal.near_ready_count": goal.get("near_ready_count"),
		"goal.complete": int(goal.get("ready_count", 0)) >= int(goal.get("required_target_count", 0)),
		"threat.own_attacks_to_win": threat.get("own_attacks_to_win"),
		"threat.opponent_attacks_to_win": threat.get("opponent_attacks_to_win"),
		"threat.tempo_margin": threat.get("tempo_margin"),
	}
	if scalar.has(fact):
		return scalar.get(fact)
	if fact in ["goal.board_energy_count", "goal.hand_energy_count", "goal.discard_energy_count"]:
		return _goal_energy_count(goal, frame, fact)
	if fact == "goal.immediate":
		if int(goal.get("active_ready_count", 0)) > 0:
			return true
		for current_value: Variant in frame.get("options", []):
			if bool(_goal_option_facts(goal, frame, current_value).get("pivots_ready_target", false)):
				return true
		return false
	if GOAL_UID_FACTS.has(fact):
		var field := fact.trim_prefix("goal.").trim_suffix("_uid")
		return int(goal.get("requirement_states", {}).get(card_uid, {}).get(field, 0))
	if fact == "goal.window.max_progress":
		return _goal_window_max_progress(goal, frame)
	if fact == "goal.option.is_max_progress":
		if not option is Dictionary:
			return null
		var progress := int(_goal_option_facts(goal, frame, option).get("progress", 0))
		var maximum := _goal_window_max_progress(goal, frame)
		return maximum > 0 and progress == maximum
	if fact == "goal.window.max_setup_progress":
		return _goal_window_max_setup_progress(goal, frame)
	if fact == "goal.option.is_max_setup_progress":
		if not option is Dictionary:
			return null
		var progress := int(_goal_option_facts(goal, frame, option).get("progress", 0))
		var maximum := _goal_window_max_setup_progress(goal, frame)
		return maximum > 0 and progress == maximum
	if fact.begins_with("goal.option."):
		return _goal_option_facts(goal, frame, option).get(
			fact.trim_prefix("goal.option.")
		)
	if ZONE_FACTS.has(fact):
		var parts := fact.split(".")
		var owner_state: Dictionary = state.get(parts[0], {})
		var values: Array = []
		if parts[1] == "board":
			values.append_array(owner_state.get("active", []))
			values.append_array(owner_state.get("bench", []))
		else:
			values = owner_state.get(parts[1], [])
		var count := 0
		for value: Variant in values:
			if value.get("local_card_uid") == card_uid:
				count += 1
		return count
	if ENERGY_ZONE_FACTS.has(fact):
		var parts := fact.split(".")
		var owner_state: Dictionary = state.get(parts[0], {})
		var slots: Array = []
		if parts[1] == "board":
			slots.append_array(owner_state.get("active", []))
			slots.append_array(owner_state.get("bench", []))
		else:
			slots = owner_state.get(parts[1], [])
		var count := 0
		for slot: Variant in slots:
			for uid: Variant in slot.get("attached_energy_uids", []):
				if uid == card_uid:
					count += 1
		return count
	if ENERGY_BEARING_ZONE_FACTS.has(fact):
		var parts := fact.split(".")
		var owner_state: Dictionary = state.get(parts[0], {})
		var slots: Array = []
		if parts[1] == "board":
			slots.append_array(owner_state.get("active", []))
			slots.append_array(owner_state.get("bench", []))
		else:
			slots = owner_state.get(parts[1], [])
		var count := 0
		for slot: Variant in slots:
			if (
				slot.get("local_card_uid") == card_uid
				and not slot.get("attached_energy_uids", []).is_empty()
			):
				count += 1
		return count
	if WINDOW_UID_FACTS.has(fact):
		var field := fact.trim_prefix("window.option_count_")
		var count := 0
		for current: Variant in frame.get("options", []):
			if current.get(field) == card_uid:
				count += 1
		return count
	if fact in ["option.source_is_active", "option.target_is_active"]:
		return _option_serial_is_active(frame, option, fact == "option.source_is_active")
	if fact.begins_with("option."):
		return null if not option is Dictionary else option.get(fact.trim_prefix("option."))
	return null


static func _goal_energy_count(goal: Dictionary, frame: Dictionary, fact: String) -> int:
	var energy_uids := {}
	for uid: Variant in goal.get("energy_uids", []):
		energy_uids[uid] = true
	var own: Dictionary = frame.get("public_state", {}).get("self", {})
	if fact == "goal.board_energy_count":
		var count := 0
		for slot_value: Variant in _self_slots(frame):
			for uid: Variant in slot_value.get("attached_energy_uids", []):
				if energy_uids.has(uid):
					count += 1
		return count
	var zone_name := "hand" if fact == "goal.hand_energy_count" else "discard"
	var count := 0
	for card_value: Variant in own.get(zone_name, []):
		if energy_uids.has(card_value.get("local_card_uid")):
			count += 1
	return count


static func _derived_policy_fact(frame: Dictionary, option: Variant, fact: String) -> Dictionary:
	var damage: Dictionary = frame.get("_derived_damage", {})
	var transaction: Dictionary = frame.get("_derived_transaction", {})
	if fact.begins_with("damage.option."):
		if not option is Dictionary:
			return {"handled": true, "value": null}
		var metrics: Dictionary = damage.get("options", {}).get(str(option.get("index")), {})
		return {"handled": true, "value": metrics.get(fact.trim_prefix("damage.option."))}
	if fact.begins_with("damage."):
		return {"handled": true, "value": damage.get("facts", {}).get(fact)}
	if fact == "transaction.active":
		return {"handled": true, "value": not transaction.get("state", {}).is_empty()}
	if fact == "transaction.id":
		return {"handled": true, "value": transaction.get("state", {}).get("transaction_id")}
	if fact == "transaction.phase":
		return {"handled": true, "value": transaction.get("state", {}).get("phase")}
	if fact.begins_with("transaction.option."):
		if not option is Dictionary:
			return {"handled": true, "value": null}
		var target: Variant = transaction.get("state", {}).get("target_entity_serial")
		var option_target: Variant = option.get("target_entity_serial")
		if option.get("kind") in ["attack", "granted_attack"]:
			option_target = damage.get("options", {}).get(
				str(option.get("index")), {}
			).get("target_entity_serial")
		return {"handled": true, "value": typeof(target) == TYPE_INT and target == option_target}
	if fact.begins_with("transaction."):
		return {
			"handled": true,
			"value": transaction.get("state", {}).get(fact.trim_prefix("transaction.")),
		}
	return {"handled": false, "value": null}


static func _option_serial_is_active(
	frame: Dictionary, option: Variant, use_source: bool
) -> Variant:
	if not option is Dictionary:
		return null
	var prefix := "source" if use_source else "target"
	var entity: Variant = option.get("%s_entity_serial" % prefix)
	var serial: Variant = option.get("%s_serial" % prefix)
	if entity == null and serial == null:
		return false
	for slot_value: Variant in frame.get("public_state", {}).get("self", {}).get("active", []):
		if (
			(slot_value.get("entity_serial") == entity if entity != null else slot_value.get("serial") == serial)
		):
			return true
	return false


static func _enum_name(names: Array, raw: Variant) -> Variant:
	return names[int(raw)] if typeof(raw) == TYPE_INT and int(raw) >= 0 and int(raw) < names.size() else null


static func _active_scalar(state: Dictionary, field: String) -> Variant:
	var active: Array = state.get("active", [])
	return active[0].get(field) if not active.is_empty() else null


static func _bench_open(frame: Dictionary, own: Dictionary) -> bool:
	if own.has("bench_capacity"):
		return own.get("bench", []).size() < int(own.get("bench_capacity"))
	for current: Variant in frame.get("options", []):
		if current is Dictionary and current.get("kind") == "play_basic_to_bench":
			return true
	return false


static func _window_uniform(frame: Dictionary, field: String) -> Variant:
	var values: Array = []
	for option: Variant in frame.get("options", []):
		var value: Variant = option.get(field)
		if value != null and value not in values:
			values.append(value)
	return values[0] if values.size() == 1 else null


static func _window_kind_count(frame: Dictionary, kind: String) -> int:
	var count := 0
	for option: Variant in frame.get("options", []):
		if option is Dictionary and option.get("kind") == kind:
			count += 1
	return count


static func _compare(actual: Variant, op: String, expected: Variant) -> bool:
	if op == "eq":
		return typeof(actual) == typeof(expected) and actual == expected
	if op == "ne":
		return typeof(actual) != typeof(expected) or actual != expected
	if op == "contains":
		return actual is Array and expected in actual
	if op == "not_contains":
		return actual is Array and expected not in actual
	if typeof(actual) != TYPE_INT or typeof(expected) != TYPE_INT:
		return false
	match op:
		"lt": return actual < expected
		"lte": return actual <= expected
		"gt": return actual > expected
		"gte": return actual >= expected
	return false


static func _document_error(value: Variant, allowed: Dictionary) -> String:
	if _contains_forbidden_value(value):
		return "private_policy_input"
	if (
		not value is Dictionary
		or not _has_required_allowed_keys(value, DOCUMENT_REQUIRED_KEYS, DOCUMENT_KEYS)
	):
		return "invalid_policy_document"
	if (
		value.get("schema_version") != 2 or not _identifier(value.get("adapter_id"))
		or not _safe_int(value.get("adapter_version")) or value.get("adapter_version") < 2
	):
		return "invalid_policy_document"
	var goals: Variant = value.get("goals")
	var count_rules: Variant = value.get("count_rules")
	var rules: Variant = value.get("rules")
	var turn_routes: Variant = value.get("turn_routes", [])
	var route_candidates: Variant = value.get("route_candidates", [])
	var interaction_recipes: Variant = value.get("interaction_recipes", [])
	var turn_bonus_contracts: Variant = value.get("turn_bonus_contracts", [])
	var damage_plans: Variant = value.get("damage_plans", [])
	var semantic_transactions: Variant = value.get("semantic_transactions", [])
	var turn_transactions: Variant = value.get("turn_transactions", [])
	if not goals is Array or goals.is_empty() or goals.size() > 64:
		return "invalid_goal_state"
	if not count_rules is Array or count_rules.size() > 128:
		return "invalid_count_rule"
	if not rules is Array or rules.is_empty() or rules.size() > 512:
		return "invalid_score_rule"
	if not turn_routes is Array or turn_routes.size() > 64:
		return "invalid_turn_route"
	if not route_candidates is Array or route_candidates.size() > 32:
		return "invalid_route_candidate"
	if not interaction_recipes is Array or interaction_recipes.size() > 128:
		return "invalid_interaction_recipe"
	if not turn_bonus_contracts is Array or turn_bonus_contracts.size() > 64:
		return "invalid_turn_bonus_contract"
	if not turn_transactions is Array or turn_transactions.size() > 64:
		return "invalid_turn_transaction"
	if not damage_plans is Array or (not damage_plans.is_empty() \
		and not DamagePlanningScript.validate_damage_plans(damage_plans).is_empty()):
		return "invalid_damage_plan"
	if not semantic_transactions is Array or (not semantic_transactions.is_empty() \
		and not DamagePlanningScript.validate_semantic_transactions(semantic_transactions).is_empty()):
		return "invalid_semantic_transaction"
	var goal_ids := {}
	for goal_value: Variant in goals:
		if not goal_value is Dictionary or not _has_exact_keys(goal_value, GOAL_KEYS):
			return "invalid_goal_state"
		var goal: Dictionary = goal_value
		if (
			not _identifier(goal.get("goal_id")) or goal_ids.has(goal.get("goal_id"))
			or not GOAL_STAGES.has(goal.get("stage")) or not _safe_int(goal.get("priority"))
		):
			return "invalid_goal_state"
		goal_ids[goal.get("goal_id")] = true
		var requirements: Variant = goal.get("requirements")
		if not requirements is Array or requirements.is_empty() or requirements.size() > 32:
			return "invalid_goal_state"
		var seen_uids := {}
		for requirement_value: Variant in requirements:
			if (
				not requirement_value is Dictionary
				or not _has_required_allowed_keys(
					requirement_value, REQUIREMENT_KEYS, ROUTE_REQUIREMENT_KEYS
				)
			):
				return "invalid_goal_state"
			var requirement: Dictionary = requirement_value
			var uid: Variant = requirement.get("card_uid")
			if (
				not _local_uid(uid) or not allowed.has(uid) or seen_uids.has(uid)
				or not _safe_int(requirement.get("ready_target_count"))
				or requirement.get("ready_target_count") < 1 or requirement.get("ready_target_count") > 6
				or not _safe_int(requirement.get("energy_required"))
				or requirement.get("energy_required") > 16
			):
				return "invalid_goal_state"
			var energy_requirements: Variant = requirement.get("energy_requirements", [])
			if not energy_requirements is Array or energy_requirements.size() > 16:
				return "invalid_goal_state"
			var seen_energy_uids := {}
			var typed_total := 0
			for typed_value: Variant in energy_requirements:
				if not typed_value is Dictionary or not _has_exact_keys(typed_value, ENERGY_REQUIREMENT_KEYS):
					return "invalid_goal_state"
				var energy_uid: Variant = typed_value.get("energy_uid")
				var energy_count: Variant = typed_value.get("count")
				if (
					not _local_uid(energy_uid) or not allowed.has(energy_uid)
					or seen_energy_uids.has(energy_uid) or not _safe_int(energy_count)
					or int(energy_count) < 1 or int(energy_count) > 16
				):
					return "invalid_goal_state"
				seen_energy_uids[energy_uid] = true
				typed_total += int(energy_count)
			if typed_total > 16:
				return "invalid_goal_state"
			var attack_index: Variant = requirement.get("attack_index")
			var ability_index: Variant = requirement.get("ability_index")
			if attack_index != null and (
				not _safe_int(attack_index) or int(attack_index) < 0 or int(attack_index) > 15
			):
				return "invalid_goal_state"
			if ability_index != null and (
				not _safe_int(ability_index) or int(ability_index) < 0 or int(ability_index) > 15
			):
				return "invalid_goal_state"
			if attack_index != null and ability_index != null:
				return "invalid_goal_state"
			seen_uids[uid] = true
	for damage_plan_value: Variant in damage_plans:
		if not damage_plan_value is Dictionary or not goal_ids.has(damage_plan_value.get("goal_id")):
			return "invalid_damage_plan"
	for transaction_value: Variant in semantic_transactions:
		if not transaction_value is Dictionary or not goal_ids.has(transaction_value.get("goal_id")):
			return "invalid_semantic_transaction"
		for key: String in ["start_when", "continue_when", "success_when", "abort_when"]:
			var transaction_condition_error := _condition_list_error(
				transaction_value.get(key), allowed, false
			)
			if not transaction_condition_error.is_empty():
				return transaction_condition_error
	var transaction_ids := {}
	for transaction_value: Variant in turn_transactions:
		var turn_transaction_error := _turn_transaction_error(
			transaction_value, allowed, goal_ids
		)
		if not turn_transaction_error.is_empty():
			return turn_transaction_error
		var transaction_id: Variant = transaction_value.get("transaction_id")
		if transaction_ids.has(transaction_id):
			return "invalid_turn_transaction"
		transaction_ids[transaction_id] = true
	var route_ids := {}
	for route_value: Variant in turn_routes:
		if not route_value is Dictionary or not _has_exact_keys(route_value, TURN_ROUTE_KEYS):
			return "invalid_turn_route"
		var route: Dictionary = route_value
		var route_id: Variant = route.get("route_id")
		if (
			not _identifier(route_id) or route_ids.has(route_id)
			or not _safe_int(route.get("priority")) or int(route.get("priority")) > 1000000
			or not goal_ids.has(route.get("goal_id"))
			or not goal_ids.has(route.get("owner_goal_id"))
			or not goal_ids.has(route.get("bridge_goal_id"))
			or not goal_ids.has(route.get("pivot_goal_id"))
			or not route.get("steps") is Array or route.get("steps").is_empty()
			or route.get("steps").size() > 32
		):
			return "invalid_turn_route"
		route_ids[route_id] = true
		var condition_error := _condition_list_error(route.get("when"), allowed, false)
		if not condition_error.is_empty():
			return condition_error
		var step_ids := {}
		for step_value: Variant in route.get("steps"):
			var step_error := _route_step_error(step_value, allowed, goal_ids)
			if not step_error.is_empty():
				return step_error
			var step_id: Variant = step_value.get("step_id")
			if step_ids.has(step_id):
				return "invalid_turn_route"
			step_ids[step_id] = true
	for route_value: Variant in route_candidates:
		if not route_value is Dictionary or not _has_exact_keys(route_value, ROUTE_CANDIDATE_KEYS):
			return "invalid_route_candidate"
		var route: Dictionary = route_value
		var route_id: Variant = route.get("route_id")
		var budget: Variant = route.get("resource_budget")
		var route_value_tuple: Variant = route.get("value")
		if (
			not _identifier(route_id) or route_ids.has(route_id)
			or not goal_ids.has(route.get("goal_id"))
			or not goal_ids.has(route.get("owner_goal_id"))
			or not goal_ids.has(route.get("bridge_goal_id"))
			or not goal_ids.has(route.get("pivot_goal_id"))
			or not budget is Dictionary
			or not _has_exact_keys(budget, ROUTE_RESOURCE_BUDGET_KEYS)
			or not route_value_tuple is Dictionary
			or not _has_exact_keys(route_value_tuple, ROUTE_VALUE_COMPONENTS)
			or not route.get("steps") is Array or route.get("steps").is_empty()
			or route.get("steps").size() > 32
		):
			return "invalid_route_candidate"
		for budget_key: String in ROUTE_RESOURCE_BUDGET_KEYS:
			if not _safe_int(budget.get(budget_key)):
				return "invalid_route_candidate"
		if (
			int(budget.get("supporter_uses")) > 1
			or int(budget.get("manual_attachments")) > 1
			or int(budget.get("retreats")) > 1
			or int(budget.get("bench_slots")) > 8
			or int(budget.get("ability_uses")) > 16
			or int(budget.get("discard_cards")) > 60
			or int(budget.get("search_cards")) > 60
		):
			return "invalid_route_candidate"
		route_ids[route_id] = true
		var condition_error := _condition_list_error(route.get("when"), allowed, false)
		if not condition_error.is_empty():
			return condition_error
		for component_name: String in ROUTE_VALUE_COMPONENTS:
			var value_error := _route_value_component_error(route_value_tuple.get(component_name))
			if not value_error.is_empty():
				return value_error
		var step_ids := {}
		for step_value: Variant in route.get("steps"):
			var step_error := _route_candidate_step_error(step_value, allowed, goal_ids)
			if not step_error.is_empty():
				return step_error
			var step_id: Variant = step_value.get("step_id")
			if step_ids.has(step_id):
				return "invalid_route_candidate"
			step_ids[step_id] = true
	var recipe_ids := {}
	for recipe_value: Variant in interaction_recipes:
		if not recipe_value is Dictionary or not _has_exact_keys(recipe_value, INTERACTION_RECIPE_KEYS):
			return "invalid_interaction_recipe"
		var recipe: Dictionary = recipe_value
		var recipe_id: Variant = recipe.get("recipe_id")
		var recipe_route_id: Variant = recipe.get("route_id")
		var source_uids: Variant = recipe.get("source_uids")
		if (
			not _identifier(recipe_id) or recipe_ids.has(recipe_id)
			or not _safe_int(recipe.get("priority")) or int(recipe.get("priority")) > 1000000
			or (recipe_route_id != null and not route_ids.has(recipe_route_id))
			or not goal_ids.has(recipe.get("goal_id"))
			or not source_uids is Array or source_uids.is_empty() or source_uids.size() > 32
			or not recipe.get("steps") is Array or recipe.get("steps").is_empty()
			or recipe.get("steps").size() > 32
		):
			return "invalid_interaction_recipe"
		var seen_source_uids := {}
		for source_uid: Variant in source_uids:
			if not _local_uid(source_uid) or not allowed.has(source_uid) or seen_source_uids.has(source_uid):
				return "invalid_interaction_recipe"
			seen_source_uids[source_uid] = true
		recipe_ids[recipe_id] = true
		var recipe_condition_error := _condition_list_error(recipe.get("when"), allowed, false)
		if not recipe_condition_error.is_empty():
			return recipe_condition_error
		var recipe_step_ids := {}
		for step_value: Variant in recipe.get("steps"):
			var step_error := _route_step_error(step_value, allowed, goal_ids)
			if not step_error.is_empty():
				return "invalid_interaction_recipe" if step_error == "invalid_turn_route" else step_error
			var step_id: Variant = step_value.get("step_id")
			if recipe_step_ids.has(step_id):
				return "invalid_interaction_recipe"
			recipe_step_ids[step_id] = true
	var contract_ids := {}
	for contract_value: Variant in turn_bonus_contracts:
		if not contract_value is Dictionary or not _has_exact_keys(
			contract_value, TURN_BONUS_CONTRACT_KEYS
		):
			return "invalid_turn_bonus_contract"
		var bonus_contract: Dictionary = contract_value
		var contract_id: Variant = bonus_contract.get("contract_id")
		var bonuses: Variant = bonus_contract.get("bonuses")
		if (
			not _identifier(contract_id) or contract_ids.has(contract_id)
			or not _safe_int(bonus_contract.get("priority"))
			or int(bonus_contract.get("priority")) > 1000000
			or not goal_ids.has(bonus_contract.get("goal_id"))
			or not bonuses is Array or bonuses.is_empty() or bonuses.size() > 64
		):
			return "invalid_turn_bonus_contract"
		contract_ids[contract_id] = true
		var contract_condition_error := _condition_list_error(
			bonus_contract.get("when"), allowed, false
		)
		if not contract_condition_error.is_empty():
			return contract_condition_error
		var bonus_ids := {}
		for bonus_value: Variant in bonuses:
			var bonus_error := _turn_bonus_error(bonus_value, allowed, goal_ids)
			if not bonus_error.is_empty():
				return bonus_error
			var bonus_id: Variant = bonus_value.get("bonus_id")
			if bonus_ids.has(bonus_id):
				return "invalid_turn_bonus_contract"
			bonus_ids[bonus_id] = true
	var rule_ids := {}
	for count_value: Variant in count_rules:
		if not count_value is Dictionary or not _has_exact_keys(count_value, COUNT_RULE_KEYS):
			return "invalid_count_rule"
		var count_rule: Dictionary = count_value
		if (
			not _identifier(count_rule.get("rule_id")) or rule_ids.has(count_rule.get("rule_id"))
			or not _safe_int(count_rule.get("priority")) or not goal_ids.has(count_rule.get("goal_id"))
			or not COUNT_MODES.has(count_rule.get("mode"))
		):
			return "invalid_count_rule"
		rule_ids[count_rule.get("rule_id")] = true
		if count_rule.get("mode") == "fixed":
			if (
				not _safe_int(count_rule.get("fixed_count"))
				or count_rule.get("fixed_count") > 1024
				or count_rule.get("fact") != null
				or count_rule.get("divisor") != null
			):
				return "invalid_count_rule"
		elif count_rule.get("mode") in [
			"goal_energy_debt", "goal_missing_energy_sources", "distinct_card_uids",
		]:
			if (
				count_rule.get("fixed_count") != null
				or count_rule.get("fact") != null
				or count_rule.get("divisor") != null
			):
				return "invalid_count_rule"
			if count_rule.get("mode") == "goal_missing_energy_sources":
				var typed_goal_found := false
				for goal_value: Variant in goals:
					if goal_value.get("goal_id") != count_rule.get("goal_id"):
						continue
					for requirement_value: Variant in goal_value.get("requirements", []):
						if not requirement_value.get("energy_requirements", []).is_empty():
							typed_goal_found = true
							break
					break
				if not typed_goal_found:
					return "invalid_count_rule"
		else:
			if (
				not SCALAR_FACTS.has(count_rule.get("fact"))
				or NON_NUMERIC_FACTS.has(count_rule.get("fact"))
				or _is_option_fact(str(count_rule.get("fact")))
				or not _safe_int(count_rule.get("divisor"))
				or int(count_rule.get("divisor")) < 1
				or int(count_rule.get("divisor")) > 1000000
			):
				return "invalid_count_rule"
			if count_rule.get("mode") == "ceil_public_fact_divisor":
				if count_rule.get("fixed_count") != null:
					return "invalid_count_rule"
			elif (
				not _safe_int(count_rule.get("fixed_count"))
				or int(count_rule.get("fixed_count")) > 1024
			):
				return "invalid_count_rule"
		if not count_rule.get("when") is Array or count_rule.get("when").size() > 32:
			return "invalid_count_rule"
		for condition: Variant in count_rule.get("when"):
			var error := _condition_error(condition, allowed)
			if not error.is_empty():
				return error
	for rule_value: Variant in rules:
		if not rule_value is Dictionary or not _has_exact_keys(rule_value, RULE_KEYS):
			return "invalid_score_rule"
		var rule: Dictionary = rule_value
		if (
			not _identifier(rule.get("rule_id")) or rule_ids.has(rule.get("rule_id"))
			or not goal_ids.has(rule.get("goal_id")) or not GOAL_STAGES.has(rule.get("goal_stage"))
			or not CHANNELS.has(rule.get("channel")) or not _safe_int(rule.get("horizon"))
			or rule.get("horizon") > 2 or not _safe_int(rule.get("confidence_milli"))
			or rule.get("confidence_milli") > 1000 or not _safe_int(rule.get("base_score"), true)
			or absi(int(rule.get("base_score"))) > 1000000
		):
			return "invalid_score_rule"
		rule_ids[rule.get("rule_id")] = true
		if not rule.get("when") is Array or rule.get("when").size() > 32:
			return "invalid_score_rule"
		for condition: Variant in rule.get("when"):
			var error := _condition_error(condition, allowed)
			if not error.is_empty():
				return error
		if not rule.get("score_terms") is Array or rule.get("score_terms").size() > 16:
			return "invalid_score_rule"
		for term_value: Variant in rule.get("score_terms"):
			if not term_value is Dictionary or not _has_exact_keys(term_value, TERM_KEYS):
				return "invalid_score_rule"
			var term: Dictionary = term_value
			if (
				not SCALAR_FACTS.has(term.get("fact")) or NON_NUMERIC_FACTS.has(term.get("fact"))
				or not _safe_int(term.get("coefficient"), true)
				or absi(int(term.get("coefficient"))) > 10000
				or not _safe_int(term.get("minimum"), true)
				or not _safe_int(term.get("maximum"), true)
				or term.get("minimum") > term.get("maximum")
			):
				return "invalid_score_rule"
	return ""


static func _condition_error(value: Variant, allowed: Dictionary) -> String:
	if not value is Dictionary or not _has_exact_keys(value, CONDITION_KEYS):
		return "invalid_public_condition"
	var fact: Variant = value.get("fact")
	if (
		typeof(fact) != TYPE_STRING
		or (
			not SCALAR_FACTS.has(fact)
			and not ZONE_FACTS.has(fact)
			and not ENERGY_ZONE_FACTS.has(fact)
			and not ENERGY_BEARING_ZONE_FACTS.has(fact)
			and not GOAL_UID_FACTS.has(fact)
			and not WINDOW_UID_FACTS.has(fact)
		)
	):
		return "invalid_public_fact"
	if not OPS.has(value.get("op")):
		return "invalid_public_condition"
	var card_uid: Variant = value.get("card_uid")
	if (
		ZONE_FACTS.has(fact)
		or ENERGY_ZONE_FACTS.has(fact)
		or ENERGY_BEARING_ZONE_FACTS.has(fact)
		or GOAL_UID_FACTS.has(fact)
		or WINDOW_UID_FACTS.has(fact)
	):
		if not _local_uid(card_uid) or not allowed.has(card_uid):
			return "invalid_public_condition"
	elif card_uid != null:
		return "invalid_public_condition"
	var scalar: Variant = value.get("value")
	if typeof(scalar) not in [TYPE_STRING, TYPE_INT, TYPE_BOOL, TYPE_NIL]:
		return "invalid_public_condition"
	if typeof(scalar) == TYPE_INT and not _safe_int(scalar, true):
		return "invalid_public_condition"
	if (
		not ZONE_FACTS.has(fact)
		and not ENERGY_ZONE_FACTS.has(fact)
		and not ENERGY_BEARING_ZONE_FACTS.has(fact)
		and not GOAL_UID_FACTS.has(fact)
		and not WINDOW_UID_FACTS.has(fact)
		and str(fact).ends_with("_uid")
		and scalar != null
	):
		if not _local_uid(scalar) or not allowed.has(scalar):
			return "invalid_public_condition"
	return ""


static func _condition_list_error(
	value: Variant, allowed: Dictionary, allow_option_facts: bool
) -> String:
	if not value is Array or value.size() > 32:
		return "invalid_public_condition"
	for condition: Variant in value:
		var error := _condition_error(condition, allowed)
		if not error.is_empty():
			return error
		if not allow_option_facts and _is_option_fact(str(condition.get("fact", ""))):
			return "invalid_public_condition"
	return ""


static func _route_step_error(
	value: Variant, allowed: Dictionary, goal_ids: Dictionary
) -> String:
	if not value is Dictionary or not _has_exact_keys(value, ROUTE_STEP_KEYS):
		return "invalid_turn_route"
	var step: Dictionary = value
	var prompt_kinds: Variant = step.get("prompt_kinds")
	if (
		not _identifier(step.get("step_id")) or not goal_ids.has(step.get("goal_id"))
		or not prompt_kinds is Array or prompt_kinds.is_empty() or prompt_kinds.size() > 16
		or not _safe_int(step.get("score_bonus"))
		or int(step.get("score_bonus")) > 1000000
		or typeof(step.get("terminal")) != TYPE_BOOL
		or typeof(step.get("checkpoint")) != TYPE_BOOL
	):
		return "invalid_turn_route"
	var seen_prompt_kinds := {}
	for prompt_kind: Variant in prompt_kinds:
		if (
			typeof(prompt_kind) != TYPE_STRING or str(prompt_kind).is_empty()
			or str(prompt_kind).length() > 64 or seen_prompt_kinds.has(prompt_kind)
		):
			return "invalid_turn_route"
		seen_prompt_kinds[prompt_kind] = true
	var selection_count: Variant = step.get("selection_count")
	if selection_count != null and (
		not _safe_int(selection_count) or int(selection_count) > 1024
	):
		return "invalid_turn_route"
	var when_error := _condition_list_error(step.get("when"), allowed, false)
	if not when_error.is_empty():
		return when_error
	if not step.get("option_when") is Array or step.get("option_when").is_empty():
		return "invalid_turn_route"
	return _condition_list_error(step.get("option_when"), allowed, true)


static func _route_candidate_step_error(
	value: Variant, allowed: Dictionary, goal_ids: Dictionary
) -> String:
	if not value is Dictionary or not _has_exact_keys(value, ROUTE_CANDIDATE_STEP_KEYS):
		return "invalid_route_candidate"
	var step: Dictionary = value
	var prompt_kinds: Variant = step.get("prompt_kinds")
	if (
		not _identifier(step.get("step_id")) or not goal_ids.has(step.get("goal_id"))
		or not prompt_kinds is Array or prompt_kinds.is_empty() or prompt_kinds.size() > 16
		or typeof(step.get("terminal")) != TYPE_BOOL
		or typeof(step.get("checkpoint")) != TYPE_BOOL
	):
		return "invalid_route_candidate"
	var seen_prompt_kinds := {}
	for prompt_kind: Variant in prompt_kinds:
		if (
			typeof(prompt_kind) != TYPE_STRING or str(prompt_kind).is_empty()
			or str(prompt_kind).length() > 64 or seen_prompt_kinds.has(prompt_kind)
		):
			return "invalid_route_candidate"
		seen_prompt_kinds[prompt_kind] = true
	var selection_count: Variant = step.get("selection_count")
	if selection_count != null and (
		not _safe_int(selection_count) or int(selection_count) > 1024
	):
		return "invalid_route_candidate"
	var when_error := _condition_list_error(step.get("when"), allowed, false)
	if not when_error.is_empty():
		return when_error
	if not step.get("option_when") is Array or step.get("option_when").is_empty():
		return "invalid_route_candidate"
	return _condition_list_error(step.get("option_when"), allowed, true)


static func _route_value_component_error(value: Variant) -> String:
	if not value is Dictionary or not _has_exact_keys(value, ROUTE_VALUE_COMPONENT_KEYS):
		return "invalid_route_value"
	var component: Dictionary = value
	var terms: Variant = component.get("terms")
	if (
		not _safe_int(component.get("base"), true)
		or absi(int(component.get("base"))) > 1000000
		or not terms is Array or terms.size() > 16
	):
		return "invalid_route_value"
	for term_value: Variant in terms:
		if not term_value is Dictionary or not _has_exact_keys(term_value, TERM_KEYS):
			return "invalid_route_value"
		var term: Dictionary = term_value
		var fact := str(term.get("fact", ""))
		if (
			not SCALAR_FACTS.has(fact) or NON_NUMERIC_FACTS.has(fact)
			or _is_option_fact(fact)
			or not _safe_int(term.get("coefficient"), true)
			or absi(int(term.get("coefficient"))) > 10000
			or not _safe_int(term.get("minimum"), true)
			or not _safe_int(term.get("maximum"), true)
			or int(term.get("minimum")) > int(term.get("maximum"))
		):
			return "invalid_route_value"
	return ""


static func _turn_bonus_error(
	value: Variant, allowed: Dictionary, goal_ids: Dictionary
) -> String:
	if not value is Dictionary or not _has_exact_keys(value, TURN_BONUS_KEYS):
		return "invalid_turn_bonus_contract"
	var bonus: Dictionary = value
	var prompt_kinds: Variant = bonus.get("prompt_kinds")
	if (
		not _identifier(bonus.get("bonus_id")) or not goal_ids.has(bonus.get("goal_id"))
		or not prompt_kinds is Array or prompt_kinds.is_empty() or prompt_kinds.size() > 16
		or not _safe_int(bonus.get("score_bonus"), true)
		or int(bonus.get("score_bonus")) < -1000000
		or int(bonus.get("score_bonus")) > 1000000
	):
		return "invalid_turn_bonus_contract"
	var seen_prompt_kinds := {}
	for prompt_kind: Variant in prompt_kinds:
		if (
			typeof(prompt_kind) != TYPE_STRING or str(prompt_kind).is_empty()
			or str(prompt_kind).length() > 64 or seen_prompt_kinds.has(prompt_kind)
		):
			return "invalid_turn_bonus_contract"
		seen_prompt_kinds[prompt_kind] = true
	var when_error := _condition_list_error(bonus.get("when"), allowed, false)
	if not when_error.is_empty():
		return when_error
	if not bonus.get("option_when") is Array or bonus.get("option_when").is_empty():
		return "invalid_turn_bonus_contract"
	return _condition_list_error(bonus.get("option_when"), allowed, true)


static func _turn_transaction_error(
	value: Variant, allowed: Dictionary, goal_ids: Dictionary
) -> String:
	if not value is Dictionary or not _has_required_allowed_keys(
		value, TURN_TRANSACTION_REQUIRED_KEYS, TURN_TRANSACTION_KEYS
	):
		return "invalid_turn_transaction"
	var transaction: Dictionary = value
	var methods: Variant = transaction.get("methods")
	if (
		not _identifier(transaction.get("transaction_id"))
		or not goal_ids.has(transaction.get("goal_id"))
		or not _safe_int(transaction.get("priority"))
		or int(transaction.get("priority")) > 1000000
		or not _safe_int(transaction.get("deadline_turns"))
		or int(transaction.get("deadline_turns")) > 16
		or not methods is Array or methods.is_empty() or methods.size() > 16
	):
		return "invalid_turn_transaction"
	for key: String in ["when", "continue_when", "success_when", "abort_when"]:
		var condition_error := _condition_list_error(
			transaction.get(key, []), allowed, false
		)
		if not condition_error.is_empty():
			return condition_error
	var method_ids := {}
	for method_value: Variant in methods:
		if not method_value is Dictionary or not _has_exact_keys(
			method_value, TURN_TRANSACTION_METHOD_KEYS
		):
			return "invalid_turn_transaction"
		var method: Dictionary = method_value
		var method_id: Variant = method.get("method_id")
		var steps: Variant = method.get("steps")
		if (
			not _identifier(method_id) or method_ids.has(method_id)
			or not _safe_int(method.get("priority"))
			or int(method.get("priority")) > 1000000
			or not steps is Array or steps.is_empty() or steps.size() > 32
		):
			return "invalid_turn_transaction"
		method_ids[method_id] = true
		var method_condition_error := _condition_list_error(
			method.get("when"), allowed, false
		)
		if not method_condition_error.is_empty():
			return method_condition_error
		var step_ids := {}
		for step_value: Variant in steps:
			if not step_value is Dictionary or not _has_required_allowed_keys(
				step_value, TURN_TRANSACTION_STEP_REQUIRED_KEYS, TURN_TRANSACTION_STEP_KEYS
			):
				return "invalid_turn_transaction"
			var step: Dictionary = step_value
			var step_id: Variant = step.get("step_id")
			var prompt_kinds: Variant = step.get("prompt_kinds")
			if (
				not _identifier(step_id) or step_ids.has(step_id)
				or not goal_ids.has(step.get("goal_id"))
				or not prompt_kinds is Array or prompt_kinds.is_empty()
				or prompt_kinds.size() > 16
				or not _safe_int(step.get("score_bonus"))
				or int(step.get("score_bonus")) > 1000000
				or typeof(step.get("terminal")) != TYPE_BOOL
				or typeof(step.get("checkpoint")) != TYPE_BOOL
				or typeof(step.get("required_before_attack")) != TYPE_BOOL
				or typeof(step.get("sequence_barrier", false)) != TYPE_BOOL
			):
				return "invalid_turn_transaction"
			step_ids[step_id] = true
			var seen_prompt_kinds := {}
			for prompt_kind: Variant in prompt_kinds:
				if (
					typeof(prompt_kind) != TYPE_STRING
					or str(prompt_kind).is_empty() or str(prompt_kind).length() > 64
					or seen_prompt_kinds.has(prompt_kind)
				):
					return "invalid_turn_transaction"
				seen_prompt_kinds[prompt_kind] = true
			var selection_count: Variant = step.get("selection_count")
			if selection_count != null and (
				not _safe_int(selection_count) or int(selection_count) > 1024
			):
				return "invalid_turn_transaction"
			for key: String in ["required_when", "complete_when"]:
				var step_condition_error := _condition_list_error(
					step.get(key), allowed, false
				)
				if not step_condition_error.is_empty():
					return step_condition_error
			if not step.get("option_when") is Array or step.get("option_when").is_empty():
				return "invalid_turn_transaction"
			var option_error := _condition_list_error(
				step.get("option_when"), allowed, true
			)
			if not option_error.is_empty():
				return option_error
			var selection_groups: Variant = step.get("selection_groups", [])
			if not selection_groups is Array or selection_groups.size() > 16:
				return "invalid_turn_transaction"
			var group_ids := {}
			var grouped_count := 0
			for group_value: Variant in selection_groups:
				if not group_value is Dictionary or not _has_exact_keys(
					group_value, TURN_TRANSACTION_SELECTION_GROUP_KEYS
				):
					return "invalid_turn_transaction"
				var group: Dictionary = group_value
				var group_id: Variant = group.get("group_id")
				var group_count: Variant = group.get("selection_count")
				if (
					not _identifier(group_id) or group_ids.has(group_id)
					or not _safe_int(group_count) or int(group_count) < 1
					or int(group_count) > 1024
					or not group.get("option_when") is Array
					or group.get("option_when").is_empty()
				):
					return "invalid_turn_transaction"
				group_ids[group_id] = true
				grouped_count += int(group_count)
				var group_option_error := _condition_list_error(
					group.get("option_when"), allowed, true
				)
				if not group_option_error.is_empty():
					return group_option_error
			if not selection_groups.is_empty() and (
				selection_count == null or grouped_count != int(selection_count)
			):
				return "invalid_turn_transaction"
	return ""


static func _frame_error(value: Variant) -> String:
	if _contains_forbidden_value(value):
		return "private_or_runtime_frame"
	if not value is Dictionary or not _has_exact_keys(value, FRAME_KEYS):
		return "invalid_public_frame"
	if (
		value.get("schema_version") != 2 or value.get("profile_id") != FRAME_PROFILE_ID
		or not _safe_int(value.get("sequence")) or value.get("sequence") < 1
		or value.get("seat") not in [0, 1] or typeof(value.get("prompt_kind")) != TYPE_STRING
		or str(value.get("prompt_kind")).is_empty()
	):
		return "invalid_public_frame"
	var source: Variant = value.get("source")
	var state: Variant = value.get("public_state")
	var semantics: Variant = value.get("select_semantics")
	var options: Variant = value.get("options")
	if (
		not source is Dictionary or not _has_exact_keys(source, ["public_observation_hash", "window_id"])
		or not _is_sha(source.get("public_observation_hash")) or not _is_sha(source.get("window_id"))
		or not state is Dictionary or not _has_exact_keys(state, ["turn_number", "phase", "self", "opponent"])
		or not semantics is Dictionary
		or not _has_exact_keys(semantics, ["min_count", "max_count", "select_type_raw", "select_context_raw"])
		or not options is Array or options.size() > 1024
	):
		return "invalid_public_frame"
	if not _safe_int(state.get("turn_number")) or typeof(state.get("phase")) != TYPE_STRING:
		return "invalid_public_frame"
	var own: Variant = state.get("self")
	var opponent: Variant = state.get("opponent")
	if (
		not own is Dictionary
		or not _has_required_allowed_keys(own, SELF_REQUIRED_KEYS, SELF_KEYS)
		or not opponent is Dictionary
		or not _has_exact_keys(opponent, ["hand_count", "active", "bench", "discard", "deck_count", "prizes_remaining"])
	):
		return "invalid_public_frame"
	if own.has("turn"):
		var turn: Variant = own.get("turn")
		if not turn is Dictionary or not _has_exact_keys(turn, TURN_LEDGER_KEYS):
			return "invalid_public_frame"
		for turn_value: Variant in turn.values():
			if typeof(turn_value) != TYPE_BOOL:
				return "invalid_public_frame"
	for key: String in ["hand", "active", "bench", "discard"]:
		if not own.get(key) is Array:
			return "invalid_public_frame"
		for card: Variant in own.get(key):
			if _card_error(card, key in ["active", "bench"]):
				return "invalid_public_frame"
	if own.has("bench_capacity") and (
		not _safe_int(own.get("bench_capacity"))
		or int(own.get("bench_capacity")) > 8
		or int(own.get("bench_capacity")) < own.get("bench", []).size()
	):
		return "invalid_public_frame"
	for key: String in ["active", "bench", "discard"]:
		if not opponent.get(key) is Array:
			return "invalid_public_frame"
		for card: Variant in opponent.get(key):
			if _card_error(card, key in ["active", "bench"]):
				return "invalid_public_frame"
	for scalar: Variant in [
		own.get("deck_count"), own.get("prizes_remaining"), opponent.get("hand_count"),
		opponent.get("deck_count"), opponent.get("prizes_remaining"),
	]:
		if not _safe_int(scalar):
			return "invalid_public_frame"
	var minimum: Variant = semantics.get("min_count")
	var maximum: Variant = semantics.get("max_count")
	if (
		not _safe_int(minimum) or not _safe_int(maximum) or minimum > maximum
		or maximum > options.size() or not _safe_int(semantics.get("select_type_raw"))
		or not _safe_int(semantics.get("select_context_raw"))
	):
		return "invalid_public_frame"
	for index: int in options.size():
		var option: Variant = options[index]
		if not option is Dictionary or not _has_required_allowed_keys(
			option, OPTION_REQUIRED_KEYS, OPTION_KEYS
		) or option.get("index") != index:
			return "invalid_public_frame"
		if typeof(option.get("kind")) != TYPE_STRING or str(option.get("kind")).is_empty():
			return "invalid_public_frame"
		for key: String in ["card_uid", "source_uid", "target_uid"]:
			if option.get(key) != null and not _local_uid(option.get(key)):
				return "invalid_public_frame"
		for key: String in [
			"source_serial", "source_entity_serial", "target_serial", "target_entity_serial",
			"target_remaining_hp", "target_prize_value",
			"target_attached_energy_count", "target_minimum_attack_energy_count",
			"target_energy_debt", "projected_damage", "attack_index", "option_number", "ability_index",
			"card_serial", "energy_type_raw", "energy_count", "special_condition_type",
		]:
			if option.get(key) != null and not _safe_int(option.get(key)):
				return "invalid_public_frame"
		var target_energy_uids: Variant = option.get("target_attached_energy_uids")
		if target_energy_uids != null and (
			not target_energy_uids is Array
			or target_energy_uids.size() > 64
			or not _uid_array(target_energy_uids)
		):
			return "invalid_public_frame"
		if option.get("target_attack_ready") != null and typeof(option.get("target_attack_ready")) != TYPE_BOOL:
			return "invalid_public_frame"
		if (
			typeof(option.get("projected_knockout")) != TYPE_BOOL
			or typeof(option.get("requires_interaction")) != TYPE_BOOL
			or not _safe_int(option.get("pending_assignment_count"))
			or not option.get("tags") is Array or not _string_array(option.get("tags"))
			or not _safe_int(option.get("option_type_raw"))
			or option.get("option_player_index") not in [0, 1, null]
		):
			return "invalid_public_frame"
		if not _valid_native_option_shape(option):
			return "invalid_public_frame"
	return ""


static func _valid_native_option_shape(option: Dictionary) -> bool:
	var option_type := int(option.get("option_type_raw", -1))
	match option_type:
		0:
			return _safe_int(option.get("option_number"))
		3, 4, 5, 7, 11:
			return _local_uid(option.get("card_uid")) and _positive_int(option.get("card_serial"))
		6:
			return (
				_local_uid(option.get("source_uid"))
				and _positive_int(option.get("source_serial"))
				and _safe_int(option.get("energy_type_raw"))
				and int(option.get("energy_type_raw")) >= 0
				and int(option.get("energy_type_raw")) <= 11
				and _positive_int(option.get("energy_count"))
			)
		8, 9:
			return (
				_local_uid(option.get("card_uid"))
				and _positive_int(option.get("card_serial"))
				and _local_uid(option.get("target_uid"))
				and _positive_int(option.get("target_serial"))
			)
		10:
			return _local_uid(option.get("source_uid")) and _positive_int(option.get("source_serial"))
		13:
			return _local_uid(option.get("source_uid")) and _safe_int(option.get("attack_index"))
		15:
			return (
				(option.get("card_uid") == null and option.get("card_serial") == null)
				or (_local_uid(option.get("card_uid")) and _positive_int(option.get("card_serial")))
			)
		16:
			return (
				_safe_int(option.get("special_condition_type"))
				and int(option.get("special_condition_type")) >= 0
				and int(option.get("special_condition_type")) <= 4
			)
		1, 2, 12, 14:
			return true
		_:
			return false


static func _positive_int(value: Variant) -> bool:
	return _safe_int(value) and int(value) > 0


static func _card_error(value: Variant, slot: bool) -> bool:
	if not value is Dictionary:
		return true
	if slot:
		if not _has_required_allowed_keys(value, SLOT_REQUIRED_KEYS, SLOT_KEYS):
			return true
	elif not _has_exact_keys(value, ["serial", "local_card_uid"]):
		return true
	if not _safe_int(value.get("serial")) or not _local_uid(value.get("local_card_uid")):
		return true
	if not slot:
		return false
	if value.has("entity_serial") and not _positive_int(value.get("entity_serial")):
		return true
	if value.has("max_hp") and not _safe_int(value.get("max_hp")):
		return true
	if value.has("damage_counters") and not _safe_int(value.get("damage_counters")):
		return true
	if value.has("appeared_this_turn") and not value.get("appeared_this_turn") is bool:
		return true
	if value.has("attached_tool_uid") and value.get("attached_tool_uid") != null \
		and not _local_uid(value.get("attached_tool_uid")):
		return true
	if value.has("pokemon_stack_uids") and (
		not value.get("pokemon_stack_uids") is Array
		or value.get("pokemon_stack_uids").is_empty()
		or not _uid_array(value.get("pokemon_stack_uids"))
	):
		return true
	var count: Variant = value.get("attached_energy_count")
	var energy_uids: Variant = value.get("attached_energy_uids")
	return (
		not _safe_int(value.get("remaining_hp")) or not _safe_int(value.get("prize_value"))
		or value.get("prize_value") < 1 or value.get("prize_value") > 3
		or not _safe_int(count) or not energy_uids is Array or energy_uids.size() != count
		or not _uid_array(energy_uids) or not _safe_int(value.get("minimum_attack_energy_count"))
		or typeof(value.get("attack_ready")) != TYPE_BOOL or not _safe_int(value.get("energy_debt"))
		or int(value.get("energy_debt")) > 16
	)


static func _policy_valid(policy: Variant) -> bool:
	if not policy is Dictionary or not _has_exact_keys(policy, ["document", "allowed_card_uids", "policy_hash"]):
		return false
	var document: Variant = policy.get("document")
	var allowed: Variant = policy.get("allowed_card_uids")
	if not allowed is Dictionary or allowed.is_empty():
		return false
	for uid: Variant in allowed:
		if not _local_uid(uid) or allowed.get(uid) != true:
			return false
	return (
		_document_error(document, allowed).is_empty()
		and _is_sha(policy.get("policy_hash"))
		and policy.get("policy_hash") == _hash({"profile_id": PROFILE_ID, "document": document})
	)


static func _contains_forbidden_value(value: Variant) -> bool:
	var stack: Array = [value]
	while not stack.is_empty():
		var current: Variant = stack.pop_back()
		if current is Dictionary:
			for key: Variant in current:
				if typeof(key) != TYPE_STRING:
					return true
				var lower := str(key).to_lower()
				if PRIVATE_KEYS.has(lower) or "private" in lower:
					return true
				stack.append(current.get(key))
		elif current is Array:
			for child: Variant in current:
				stack.append(child)
		elif typeof(current) not in [TYPE_STRING, TYPE_INT, TYPE_BOOL, TYPE_NIL]:
			return true
	return false


static func _index_list(value: Variant, option_count: int) -> bool:
	if not value is Array:
		return false
	var seen := {}
	for index: Variant in value:
		if typeof(index) != TYPE_INT or index < 0 or index >= option_count or seen.has(index):
			return false
		seen[index] = true
	return true


static func _turn_program_option_fact(
	option: Dictionary, frame: Variant = null
) -> Dictionary:
	var public_target: Dictionary = {}
	if frame is Dictionary and option.get("kind") in ["attack", "granted_attack"]:
		var active: Array = frame.get("public_state", {}).get(
			"opponent", {}
		).get("active", [])
		if not active.is_empty() and active[0] is Dictionary:
			public_target = active[0]
	return {
		"kind": option.get("kind"),
		"card_uid": option.get("card_uid"),
		"source_uid": option.get("source_uid"),
		"target_uid": option.get("target_uid"),
		"tags": option.get("tags", []).duplicate(),
		"projected_damage": option.get("projected_damage"),
		"projected_knockout": bool(option.get("projected_knockout", false)),
		"target_remaining_hp": (
			option.get("target_remaining_hp")
			if option.get("target_remaining_hp") != null
			else public_target.get("remaining_hp")
		),
		"target_prize_value": (
			option.get("target_prize_value")
			if option.get("target_prize_value") != null
			else public_target.get("prize_value")
		),
	}


static func _turn_program_condition_value(conditions: Array, fact: String) -> Variant:
	for condition_value: Variant in conditions:
		if condition_value is Dictionary \
				and condition_value.get("fact") == fact \
				and condition_value.get("op") == "eq":
			return condition_value.get("value")
	return null


static func _turn_program_action_semantics_profile(value: Variant) -> bool:
	if not value is Dictionary or not _required_optional_keys(value, [
		"profile_id", "uid_effect_kinds", "uid_resource_claims",
	], ["uid_public_guards"]) \
			or value.get("profile_id") != "ptcgdap-turn-program-action-semantics-v1" \
			or not value.get("uid_effect_kinds") is Dictionary \
			or value.get("uid_effect_kinds", {}).is_empty() \
			or not value.get("uid_resource_claims") is Dictionary:
		return false
	var effects: Dictionary = value.get("uid_effect_kinds")
	var claims: Dictionary = value.get("uid_resource_claims")
	if effects.size() != claims.size():
		return false
	for uid: Variant in effects:
		if typeof(uid) != TYPE_STRING or str(uid).is_empty() or str(uid).length() > 128 \
				or not claims.has(uid) or effects.get(uid) not in [
					"ability", "bench", "conversion", "damage_transfer", "disruption",
					"draw", "energy", "evolution", "handoff", "search", "tool",
				] or claims.get(uid) not in [
					"none", "supporter", "manual_attachment", "retreat",
				]:
			return false
	var guards: Variant = value.get("uid_public_guards", {})
	if not guards is Dictionary:
		return false
	for uid: Variant in guards:
		var guard: Variant = guards.get(uid)
		if not effects.has(uid) or not guard is Dictionary or not _has_exact_keys(
			guard, ["mode", "max_own_hand_count", "min_opponent_hand_count"]
		) or guard.get("mode") not in ["all", "any"]:
			return false
		var max_hand: Variant = guard.get("max_own_hand_count")
		var min_opponent: Variant = guard.get("min_opponent_hand_count")
		if (max_hand != null and (typeof(max_hand) != TYPE_INT \
				or int(max_hand) < 0 or int(max_hand) > 30)) \
				or (min_opponent != null and (typeof(min_opponent) != TYPE_INT \
				or int(min_opponent) < 0 or int(min_opponent) > 30)) \
				or (max_hand == null and min_opponent == null):
			return false
	return true


static func _turn_program_declared_semantics(
	card_uid: Variant, action_semantics: Variant
) -> Dictionary:
	if action_semantics == null or typeof(card_uid) != TYPE_STRING \
			or not action_semantics.get("uid_effect_kinds", {}).has(card_uid):
		return {}
	return {
		"effect_kind": action_semantics.get("uid_effect_kinds", {}).get(card_uid),
		"resource_claim": action_semantics.get("uid_resource_claims", {}).get(card_uid),
	}


static func _turn_program_public_guard_satisfied(
	frame: Dictionary, binding: Array, action_semantics: Variant
) -> bool:
	if action_semantics == null or action_semantics.get("uid_public_guards", {}).is_empty():
		return true
	var guards: Dictionary = action_semantics.get("uid_public_guards")
	var selected_guards: Array = []
	for index_value: Variant in binding:
		var option: Dictionary = frame.get("options", [])[int(index_value)]
		var uid: Variant = option.get("card_uid") \
			if option.get("card_uid") != null else option.get("source_uid")
		if guards.has(uid):
			selected_guards.append(guards.get(uid))
	if selected_guards.is_empty():
		return true
	var own_hand: int = frame.get("public_state", {}).get("self", {}).get("hand", []).size()
	var opponent_hand := int(frame.get("public_state", {}).get(
		"opponent", {}
	).get("hand_count", 0))
	for guard_value: Variant in selected_guards:
		var guard: Dictionary = guard_value
		var checks: Array = []
		if guard.get("max_own_hand_count") != null:
			checks.append(own_hand <= int(guard.get("max_own_hand_count")))
		if guard.get("min_opponent_hand_count") != null:
			checks.append(opponent_hand >= int(guard.get("min_opponent_hand_count")))
		var passed := checks.all(func(value: Variant) -> bool: return bool(value)) \
			if guard.get("mode") == "all" \
			else checks.any(func(value: Variant) -> bool: return bool(value))
		if not passed:
			return false
	return true


static func _turn_program_effect_kind(
	step: Dictionary, action_semantics: Variant = null
) -> String:
	var option_kind: Variant = _turn_program_condition_value(
		step.get("option_when", []), "option.kind"
	)
	var card_uid: Variant = _turn_program_condition_value(
		step.get("option_when", []), "option.card_uid"
	)
	if card_uid == null:
		card_uid = _turn_program_condition_value(
			step.get("option_when", []), "option.source_uid"
		)
	var declared := _turn_program_declared_semantics(card_uid, action_semantics)
	if not declared.is_empty():
		return str(declared.get("effect_kind"))
	var tokens := "%s-%s" % [
		str(step.get("step_id", "")).to_lower(),
		str(step.get("goal_id", "")).to_lower(),
	]
	if option_kind in ["attack", "granted_attack"]:
		return "attack"
	if "munkidori" in tokens or "move-damage" in tokens or "transfer" in tokens:
		return "damage_transfer"
	if "iono" in tokens or "disrupt" in tokens:
		return "disruption"
	if "research" in tokens or "draw" in tokens or "refill" in tokens or "refresh" in tokens:
		return "draw"
	if option_kind == "evolve" or "evol" in tokens:
		return "evolution"
	if option_kind == "attach_energy" or "energy" in tokens or "fund" in tokens \
			or "punk" in tokens:
		return "energy"
	if option_kind == "play_basic_to_bench" or "bench" in tokens or "reserve" in tokens:
		return "bench"
	if option_kind in ["send_out", "retreat", "switch"] \
			or "send-out" in tokens or "retreat" in tokens \
			or "handoff" in tokens or "pivot" in tokens:
		return "handoff"
	if option_kind == "attach_tool":
		return "tool"
	if option_kind in ["search", "use_stadium_effect"] or "search" in tokens:
		return "search"
	if option_kind == "use_ability":
		return "ability"
	if "gust" in tokens or "prize" in tokens or "devolution" in tokens \
			or "finish" in tokens:
		return "conversion"
	if option_kind == "end_turn":
		return "end_turn"
	return "search" if option_kind == "play_trainer" else "ability"


static func _turn_program_terminal_kind(step: Dictionary) -> String:
	if not bool(step.get("terminal", false)):
		return "none"
	var option_kind: Variant = _turn_program_condition_value(
		step.get("option_when", []), "option.kind"
	)
	return "attack" if option_kind in ["attack", "granted_attack"] else "end_turn"


static func _turn_program_group_indexes(
	step: Dictionary,
	frame: Dictionary,
	candidate_indexes: Array,
	goal: Dictionary,
	threat: Dictionary,
) -> Variant:
	var groups: Array = step.get("selection_groups", [])
	if groups.is_empty():
		return candidate_indexes.duplicate()
	var used := {}
	var selected: Array = []
	for group_value: Variant in groups:
		var group: Dictionary = group_value
		var group_indexes: Array = []
		for option_value: Variant in frame.get("options", []):
			var option: Dictionary = option_value
			var index := int(option.get("index", -1))
			if index in candidate_indexes and not used.has(index) \
					and _matches(group.get("option_when", []), frame, option, goal, threat):
				group_indexes.append(index)
		var count := int(group.get("selection_count", 0))
		if group_indexes.size() < count:
			return null
		for offset: int in count:
			var index := int(group_indexes[offset])
			used[index] = true
			selected.append(index)
	return selected


static func _turn_program_step_binding(
	step: Dictionary, frame: Dictionary, goal: Dictionary, threat: Dictionary
) -> Variant:
	if frame.get("prompt_kind") not in step.get("prompt_kinds", []):
		return null
	var indexes: Array = []
	for option_value: Variant in frame.get("options", []):
		var option: Dictionary = option_value
		if _matches(step.get("option_when", []), frame, option, goal, threat):
			indexes.append(int(option.get("index", -1)))
	var grouped: Variant = _turn_program_group_indexes(
		step, frame, indexes, goal, threat
	)
	if grouped == null:
		return null
	indexes = grouped
	var count: Variant = step.get("selection_count")
	var minimum := int(frame.get("select_semantics", {}).get("min_count", 0))
	var maximum := int(frame.get("select_semantics", {}).get("max_count", 0))
	if count != null and (
		int(count) < minimum or int(count) > maximum or int(count) > indexes.size()
	):
		return null
	return indexes if not indexes.is_empty() else null


static func _turn_program_proof(
	indexes: Array,
	selection_count: Variant,
	frame: Dictionary,
	mandatory: Array,
	terminal: Array,
	tiers: Dictionary,
	vetoed: Array,
) -> Dictionary:
	var frontier: Array = []
	for index: int in frame.get("options", []).size():
		frontier.append(index)
	if not frontier.is_empty():
		var best_tier: Array = tiers.get(frontier[0], [0])
		for index_value: Variant in frontier:
			if _tier_less(tiers.get(int(index_value), [0]), best_tier):
				best_tier = tiers.get(int(index_value), [0])
		var same_tier: Array = []
		for index_value: Variant in frontier:
			if tiers.get(int(index_value), [0]) == best_tier:
				same_tier.append(int(index_value))
		frontier = same_tier
	var non_vetoed: Array = []
	for index_value: Variant in indexes:
		if int(index_value) not in vetoed:
			non_vetoed.append(int(index_value))
	var current: Array = []
	for index_value: Variant in non_vetoed:
		if int(index_value) in frontier:
			current.append(int(index_value))
	var count := int(frame.get("select_semantics", {}).get("min_count", 0)) \
		if selection_count == null else int(selection_count)
	var executable := current.size() >= count
	var forced: Array = terminal if not terminal.is_empty() else mandatory
	var forced_preserved := forced.is_empty() or (
		forced.size() == count
		and forced.all(func(index: Variant) -> bool: return index in current)
	)
	return {
		"admissible": executable,
		"current_step_executable": executable,
		"mandatory_preserved": mandatory.is_empty() or forced_preserved,
		"terminal_preserved": terminal.is_empty() or forced_preserved,
		"base_vetoed": non_vetoed.is_empty(),
	}


static func _turn_program_semantic_step(
	step: Dictionary, transaction_id: String, method_id: String, previous: Variant,
	action_semantics: Variant = null
) -> Dictionary:
	var card_uid: Variant = _turn_program_condition_value(
		step.get("option_when", []), "option.card_uid"
	)
	if card_uid == null:
		card_uid = _turn_program_condition_value(
			step.get("option_when", []), "option.source_uid"
		)
	var declared := _turn_program_declared_semantics(card_uid, action_semantics)
	return {
		"step_id": step.get("step_id"),
		"transaction_id": transaction_id,
		"method_id": method_id,
		"depends_on": [] if previous == null else [previous],
		"terminal_kind": _turn_program_terminal_kind(step),
		"effect_kind": _turn_program_effect_kind(step, action_semantics),
		"resource_claim": declared.get("resource_claim"),
	}


static func _turn_program_terminal_options(
	frame: Dictionary, tiers: Dictionary, vetoed: Array
) -> Array:
	var result: Array = []
	for option_value: Variant in _turn_program_base_options(frame, tiers, vetoed):
		if option_value.get("kind") in ["attack", "granted_attack", "end_turn"]:
			result.append(option_value)
	return result


static func _turn_program_base_options(
	frame: Dictionary, tiers: Dictionary, vetoed: Array
) -> Array:
	var frontier: Array = []
	for index: int in frame.get("options", []).size():
		frontier.append(index)
	if not frontier.is_empty():
		var best_tier: Array = tiers.get(frontier[0], [0])
		for index_value: Variant in frontier:
			if _tier_less(tiers.get(int(index_value), [0]), best_tier):
				best_tier = tiers.get(int(index_value), [0])
		frontier = frontier.filter(func(index: Variant) -> bool:
			return tiers.get(int(index), [0]) == best_tier
		)
	var result: Array = []
	for option_value: Variant in frame.get("options", []):
		var option: Dictionary = option_value
		var index := int(option.get("index", -1))
		if index in frontier and index not in vetoed:
			result.append(option)
	return result


static func _turn_program_base_effect_kind(
	option: Dictionary, action_semantics: Variant = null
) -> String:
	var kind := str(option.get("kind", ""))
	var declared := _turn_program_declared_semantics(
		option.get("card_uid") if option.get("card_uid") != null else option.get("source_uid"),
		action_semantics
	)
	if not declared.is_empty() and kind not in ["attack", "granted_attack", "end_turn"]:
		return str(declared.get("effect_kind"))
	if kind in ["attack", "granted_attack"]:
		return "attack"
	if kind == "end_turn":
		return "end_turn"
	if kind == "evolve":
		return "evolution"
	if kind in ["attach_energy", "assignment_target"]:
		return "energy"
	if kind == "attach_tool":
		return "tool"
	if kind in ["play_basic_to_bench", "setup_active", "setup_bench"]:
		return "bench"
	if kind in ["send_out", "retreat", "switch"]:
		return "handoff"
	if kind == "use_ability":
		return "ability"
	if kind in ["play_trainer", "play_stadium", "use_stadium_effect", "search"]:
		return "search"
	return "ability"


static func _turn_program_base_resource_claim(
	option: Dictionary, action_semantics: Variant
) -> Variant:
	var declared := _turn_program_declared_semantics(
		option.get("card_uid") if option.get("card_uid") != null else option.get("source_uid"),
		action_semantics
	)
	if not declared.is_empty():
		return declared.get("resource_claim")
	if option.get("kind") == "attach_energy":
		return "manual_attachment"
	if option.get("kind") == "retreat":
		return "retreat"
	return null


static func _turn_program_canary_profile(value: Variant) -> bool:
	if not value is Dictionary or not _has_exact_keys(value, [
		"profile_id", "allowed_source_kinds", "allowed_current_effect_kinds",
		"max_uncertainty_milli", "minimum_utility_margin",
	]):
		return false
	if value.get("profile_id") != "ptcgdap-turn-program-canary-v1":
		return false
	var sources: Variant = value.get("allowed_source_kinds")
	var effects: Variant = value.get("allowed_current_effect_kinds")
	if not sources is Array or sources.is_empty() or sources.size() != _unique(sources).size() \
			or not effects is Array or effects.is_empty() or effects.size() != _unique(effects).size():
		return false
	for source: Variant in sources:
		if source not in ["turn_transaction", "turn_route", "base_action"]:
			return false
	for effect: Variant in effects:
		if effect not in [
			"ability", "bench", "conversion", "damage_transfer", "disruption",
			"draw", "energy", "evolution", "handoff", "search", "tool",
		]:
			return false
	return (
		_safe_int(value.get("max_uncertainty_milli"))
		and int(value.get("max_uncertainty_milli")) <= 1000
		and _safe_int(value.get("minimum_utility_margin"))
		and int(value.get("minimum_utility_margin")) <= 10000000
	)


static func _unique(values: Array) -> Array:
	var seen := {}
	for value: Variant in values:
		seen[value] = true
	return seen.keys()


static func _automatic_turn_program_candidates(
	document: Dictionary,
	frame: Dictionary,
	goals: Dictionary,
	threat: Dictionary,
	mandatory: Array,
	terminal: Array,
	tiers: Dictionary,
	vetoed: Array,
	ranked_indexes: Array,
	action_semantics: Variant = null,
) -> Dictionary:
	var candidates: Array = []
	var bindings := {}
	var terminal_options := _turn_program_terminal_options(frame, tiers, vetoed)
	var terminal_facts: Array = []
	for option_value: Variant in terminal_options:
		if option_value.get("kind") in ["attack", "granted_attack"]:
			terminal_facts.append(_turn_program_option_fact(option_value, frame))
	for transaction_value: Variant in document.get("turn_transactions", []):
		var transaction: Dictionary = transaction_value
		var transaction_goal: Dictionary = goals.get(transaction.get("goal_id"), {})
		if not _matches(transaction.get("when", []), frame, null, transaction_goal, threat):
			continue
		if not transaction.get("success_when", []).is_empty() and _matches(
			transaction.get("success_when", []), frame, null, transaction_goal, threat
		):
			continue
		if not transaction.get("abort_when", []).is_empty() and _matches(
			transaction.get("abort_when", []), frame, null, transaction_goal, threat
		):
			continue
		for method_value: Variant in transaction.get("methods", []):
			var method: Dictionary = method_value
			if not _matches(method.get("when", []), frame, null, transaction_goal, threat):
				continue
			var required_steps: Array = []
			for step_value: Variant in method.get("steps", []):
				var step: Dictionary = step_value
				var step_goal: Dictionary = goals.get(step.get("goal_id"), {})
				var complete: bool = not step.get("complete_when", []).is_empty() and _matches(
					step.get("complete_when", []), frame, null, step_goal, threat
				)
				var required: bool = step.get("required_when", []).is_empty() or _matches(
					step.get("required_when", []), frame, null, step_goal, threat
				)
				if not complete and required:
					required_steps.append(step)
			var current_offset := -1
			var current_indexes: Array = []
			for offset: int in required_steps.size():
				var step: Dictionary = required_steps[offset]
				var bound: Variant = _turn_program_step_binding(
					step, frame, goals.get(step.get("goal_id"), {}), threat
				)
				if bound != null:
					current_offset = offset
					current_indexes = bound
					break
			if current_offset < 0:
				continue
			var current_step: Dictionary = required_steps[current_offset]
			var selected_steps: Array = [current_step]
			if not bool(current_step.get("terminal", false)):
				for offset: int in range(current_offset + 1, required_steps.size()):
					var later_step: Dictionary = required_steps[offset]
					if selected_steps.size() >= 7 or bool(later_step.get("terminal", false)):
						break
					if bool(later_step.get("required_before_attack", false)):
						selected_steps.append(later_step)
			var semantic_steps: Array = []
			var previous: Variant = null
			for step_value: Variant in selected_steps:
				var semantic := _turn_program_semantic_step(
					step_value,
					str(transaction.get("transaction_id")),
					str(method.get("method_id")),
					previous,
					action_semantics,
				)
				semantic_steps.append(semantic)
				previous = semantic.get("step_id")
			if semantic_steps[-1].get("terminal_kind") == "none" \
					and not terminal_facts.is_empty():
				var terminal_id := ("terminal-after-%s" % semantic_steps[0].get(
					"step_id"
				)).substr(0, 128)
				semantic_steps.append({
					"step_id": terminal_id,
					"transaction_id": transaction.get("transaction_id"),
					"method_id": method.get("method_id"),
					"depends_on": [previous],
					"terminal_kind": "attack",
					"effect_kind": "attack",
					"resource_claim": "none",
				})
			var program_id := ("tx.%s.%s" % [
				transaction.get("transaction_id"), method.get("method_id")
			]).substr(0, 128)
			var facts: Array = []
			for index_value: Variant in current_indexes:
				facts.append(_turn_program_option_fact(
					frame.get("options", [])[int(index_value)], frame
				))
			candidates.append({
				"program_id": program_id,
				"goal_id": transaction.get("goal_id"),
				"route_id": transaction.get("transaction_id"),
				"deadline_turns": transaction.get("deadline_turns"),
				"priority": int(transaction.get("priority", 0)) + int(method.get("priority", 0)),
				"source_kind": "turn_transaction",
				"semantic_steps": semantic_steps,
				"current_step_id": semantic_steps[0].get("step_id"),
				"current_option_facts": facts,
				"terminal_option_facts": terminal_facts.duplicate(true),
				"base_proof": _turn_program_proof(
					current_indexes, current_step.get("selection_count"), frame,
					mandatory, terminal, tiers, vetoed
				),
			})
			bindings[program_id] = current_indexes.duplicate()
	for route_value: Variant in document.get("turn_routes", []):
		var route: Dictionary = route_value
		var route_goal: Dictionary = goals.get(route.get("goal_id"), {})
		if not _matches(route.get("when", []), frame, null, route_goal, threat):
			continue
		var executable := _executable_route_step(
			route.get("steps", []), frame, goals, threat
		)
		if executable.is_empty():
			continue
		var current_step: Dictionary = executable.get("step", {})
		var current_indexes: Array = executable.get("indexes", []).duplicate()
		var current_offset: int = route.get("steps", []).find(current_step)
		var source_steps: Array = [current_step]
		if not bool(current_step.get("terminal", false)):
			for offset: int in range(current_offset + 1, route.get("steps", []).size()):
				var later_step: Dictionary = route.get("steps", [])[offset]
				source_steps.append(later_step)
				if bool(later_step.get("terminal", false)) or source_steps.size() >= 7:
					break
		var semantic_steps: Array = []
		var previous: Variant = null
		for step_value: Variant in source_steps:
			var semantic := _turn_program_semantic_step(
				step_value, str(route.get("route_id")), str(route.get("route_id")), previous,
				action_semantics
			)
			semantic_steps.append(semantic)
			previous = semantic.get("step_id")
		if semantic_steps[-1].get("terminal_kind") == "none" \
				and not terminal_facts.is_empty():
			var terminal_id := ("terminal-after-%s" % semantic_steps[0].get(
				"step_id"
			)).substr(0, 128)
			semantic_steps.append({
				"step_id": terminal_id,
				"transaction_id": route.get("route_id"),
				"method_id": route.get("route_id"),
				"depends_on": [previous],
				"terminal_kind": "attack",
				"effect_kind": "attack",
				"resource_claim": "none",
			})
		var program_id := ("route.%s" % route.get("route_id")).substr(0, 128)
		var facts: Array = []
		for index_value: Variant in current_indexes:
			facts.append(_turn_program_option_fact(
				frame.get("options", [])[int(index_value)], frame
			))
		candidates.append({
			"program_id": program_id,
			"goal_id": route.get("goal_id"),
			"route_id": route.get("route_id"),
			"deadline_turns": 0,
			"priority": route.get("priority"),
			"source_kind": "turn_route",
			"semantic_steps": semantic_steps,
			"current_step_id": semantic_steps[0].get("step_id"),
			"current_option_facts": facts,
			"terminal_option_facts": terminal_facts.duplicate(true),
			"base_proof": _turn_program_proof(
				current_indexes, current_step.get("selection_count"), frame,
				mandatory, terminal, tiers, vetoed
			),
		})
		bindings[program_id] = current_indexes.duplicate()
	var seen_base_ids := {}
	var rank_by_index := {}
	for offset: int in ranked_indexes.size():
		rank_by_index[int(ranked_indexes[offset])] = offset
	for option_value: Variant in _turn_program_base_options(frame, tiers, vetoed):
		if candidates.size() >= 64:
			break
		var option: Dictionary = option_value
		var semantic_identity := {}
		for key: String in [
			"kind", "card_uid", "card_serial", "source_uid", "source_serial",
			"source_entity_serial", "target_uid", "target_serial",
			"target_entity_serial", "attack_index", "ability_index",
			"option_number", "projected_damage", "projected_knockout",
		]:
			semantic_identity[key] = option.get(key)
		var digest := _hash(semantic_identity).substr(0, 16).to_lower()
		var program_id := "base.%s.%s" % [option.get("kind"), digest]
		if seen_base_ids.has(program_id):
			continue
		seen_base_ids[program_id] = true
		var terminal_kind := (
			"end_turn" if option.get("kind") == "end_turn"
			else "attack" if option.get("kind") in ["attack", "granted_attack"]
			else "none"
		)
		var step_id := "current-%s-%s" % [option.get("kind"), digest]
		var facts := [_turn_program_option_fact(option, frame)]
		candidates.append({
			"program_id": program_id,
			"goal_id": "base-terminal",
			"route_id": program_id,
			"deadline_turns": 0,
			"priority": (
				0 if terminal_kind != "none"
				else maxi(0, 8000 - 250 * int(rank_by_index.get(
					int(option.get("index")), 32
				)))
			),
			"source_kind": "base_terminal" if terminal_kind != "none" else "base_action",
			"semantic_steps": [{
				"step_id": step_id,
				"transaction_id": "base-terminal",
				"method_id": "current-%s" % option.get("kind"),
				"depends_on": [],
				"terminal_kind": terminal_kind,
				"effect_kind": _turn_program_base_effect_kind(option, action_semantics),
				"resource_claim": _turn_program_base_resource_claim(
					option, action_semantics
				),
			}],
			"current_step_id": step_id,
			"current_option_facts": facts,
			"terminal_option_facts": facts.duplicate(true) if terminal_kind == "attack" else [],
			"base_proof": _turn_program_proof(
				[int(option.get("index"))], 1, frame, mandatory, terminal, tiers, vetoed
			),
		})
		bindings[program_id] = [int(option.get("index"))]
	return {"candidates": candidates, "bindings": bindings}


static func _tier_less(left: Array, right: Array) -> bool:
	for index: int in mini(left.size(), right.size()):
		if int(left[index]) != int(right[index]):
			return int(left[index]) < int(right[index])
	return left.size() < right.size()


static func _trunc_div(value: int, divisor: int) -> int:
	return value / divisor if value >= 0 else -((-value) / divisor)


static func _clamp_score(value: int) -> int:
	return clampi(value, -MAX_SCORE, MAX_SCORE)


static func _safe_int(value: Variant, signed: bool = false) -> bool:
	return typeof(value) == TYPE_INT and value <= MAX_SAFE_INTEGER and value >= (-MAX_SAFE_INTEGER if signed else 0)


static func _local_uid(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.length() < 3 or value.length() > 64 or not "_" in value:
		return false
	var separator: int = str(value).find("_")
	if separator < 1 or separator >= value.length() - 1:
		return false
	for character: String in value:
		var code := character.unicode_at(0)
		if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or character in [".", "_"]):
			return false
	return true


static func _identifier(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.is_empty() or value.length() > 128 or "private" in value:
		return false
	for index: int in value.length():
		var character: String = value[index]
		var code := character.unicode_at(0)
		var valid := (code >= 48 and code <= 57) or (code >= 97 and code <= 122) or character in [".", "_", "-"]
		if not valid or (index == 0 and not ((code >= 48 and code <= 57) or (code >= 97 and code <= 122))):
			return false
	return true


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key: Variant in expected:
		if not value.has(key):
			return false
	return true


static func _required_optional_keys(
	value: Dictionary, required: Array, optional: Array
) -> bool:
	for key: Variant in required:
		if not value.has(key):
			return false
	for key: Variant in value:
		if key not in required and key not in optional:
			return false
	return true


static func _has_required_allowed_keys(
	value: Dictionary, required: Array, allowed: Array
) -> bool:
	for key: Variant in required:
		if not value.has(key):
			return false
	for key: Variant in value:
		if key not in allowed:
			return false
	return true


static func _uid_array(value: Array) -> bool:
	for child: Variant in value:
		if not _local_uid(child):
			return false
	return true


static func _string_array(value: Array) -> bool:
	for child: Variant in value:
		if typeof(child) != TYPE_STRING:
			return false
	return true


static func _is_sha(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != 64:
		return false
	for character: String in value:
		var code := character.unicode_at(0)
		if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 70)):
			return false
	return true


static func _hash(value: Variant) -> String:
	var result: Dictionary = TreeHashScript.public_observation_hash(value)
	return str(result.get("sha256", "")) if bool(result.get("ok", false)) else ""


static func _compile_error(code: String) -> Dictionary:
	return {"accepted": false, "error_code": code, "policy": null}


static func _decision_error(code: String) -> Dictionary:
	return {"accepted": false, "error_code": code, "selected_indexes": [], "audit": {}}
