class_name V18CPGContracts
extends RefCounted

const ARCHITECTURE := "V18CPG"
const RUNTIME_KIND := "v18_conditional_policy"
const SCHEMA_VERSION := "v18cpg-2"
const OBSERVATION_SCHEMA_VERSION := 1
const BELIEF_SCHEMA_VERSION := 1
const ROUTE_SCHEMA_VERSION := 2
const POLICY_SCHEMA_VERSION := 2
const AUDIT_SCHEMA_VERSION := 3
## Route Value Graph v3 is an additive local planning contract.  The outer
## request/response schema intentionally remains v18cpg-2 so Graph v2 policy
## responses, rejection, and Rule fallback stay wire-compatible.
const ROUTE_VALUE_GRAPH_VERSION := 3
const BUNDLE_SCHEMA_VERSION := 1
const TRANSITION_SCHEMA_VERSION := 1
const RESPONSE_ENVELOPE_SCHEMA_VERSION := 2
const RESOURCE_LEDGER_SCHEMA_VERSION := 3

const FEATURE_FLAG := "v18_conditional_policy_enabled"
const ROUTE_VALUE_GRAPH_FEATURE_FLAG := "route_value_graph_v3_enabled"
const DEFAULT_MAX_POLICY_NODES := 8
const HARD_MAX_POLICY_NODES := 12

const EVENT_TYPES: Array[String] = [
	"TURN_HANDOFF",
	"TURN_DRAW_RESOLVED",
	"MAIN_ACTION_RESOLVED",
	"INTERACTION_OPENED",
	"INTERACTION_STEP_RESOLVED",
	"FULL_DECK_VIEW_OPENED",
	"RANDOM_DRAW_RESOLVED",
	"SHUFFLE_RESOLVED",
	"COMMITMENT_SPENT",
	"BEFORE_TERMINAL",
	"ATTACK_RESOLVED",
	"PRIZE_TAKEN",
	"SEND_OUT_REQUIRED",
	"TURN_ENDED",
]

const GUARD_OPERATORS: Array[String] = [
	"==", "!=", ">", ">=", "<", "<=", "in", "not_in", "exists",
]

const ACTION_OWNERS: Array[String] = [
	"model_selected_local_route",
	"model_synthesized_route",
	"policy_graph_branch",
	"module_verified_upgrade",
	"local_gate",
	"deadline_fallback",
	"schema_fallback",
	"rules_fallback",
]

const INTERACTION_RANK_KEYS: Array[String] = [
	"route_completion",
	"energy_fit",
	"prize_value",
	"knockout_efficiency",
	"attacker_readiness",
	"survival",
	"resource_preservation",
	"stable_id",
]

## Only facts under these public, engine-built namespaces may become policy
## checkpoint guards.  The exact leaf list is derived from the request's facts
## at runtime so the model, validator, delta detector, and graph executor cannot
## drift onto four different fact catalogs again.
const BRANCHABLE_FACT_ROOTS: Array[String] = [
	"attack",
	"board",
	"continuity",
	"fan_call",
	"hard_guard",
	"information",
	"prize",
	"prize_clock",
	"resources",
	"route",
	"turn",
]

const FACT_PATH_ALIASES := {
	# This was the public name used by the continuity solver before current and
	# future engine counts were split.  Keep only this unambiguous wire alias.
	"continuity.energized_engine_count":
		"continuity.current_energized_engine_count",
}

const REGISTERED_FACT_PATHS: Array[String] = [
	"attack.ready",
	"attack.ko_available",
	"attack.max_damage",
	"attack.dynamic_cost_applied",
	"attack.effective_energy_required",
	"attack.energy_deficit",
	"attack.cost_ready",
	"attack.engine_confirms_cost_paid",
	"board.bench_full",
	"board.has_tera",
	"board.own_active_remaining_hp",
	"board.opponent_active_remaining_hp",
	"continuity.enabled",
	"continuity.floor_met",
	"continuity.review_before_terminal",
	"continuity.debt_count",
	"continuity.banked_damage_units",
	"continuity.required_banked_damage_units",
	"continuity.live_engine_count",
	"continuity.current_live_engine_count",
	"continuity.current_energized_engine_count",
	"continuity.search_engine_roots",
	"continuity.live_search_engines",
	"continuity.bench_capacity",
	"continuity.bench_slots_free",
	"continuity.expansion_active",
	"continuity.next_attacker_roots",
	"continuity.safe_prefix_available",
	"fan_call.available",
	"information.material_action_available",
	"resources.deck_low",
	"resources.bench_slots_free",
	"resources.energy_on_board",
	"resources.distinct_energy_symbols",
	"resources.hand_size",
	"resources.prizes_remaining",
	"prize.current_swing",
	"prize.win_now",
	"prize_clock.current_attack_window_open",
	"prize_clock.own_fastest_finish_tick",
	"prize_clock.own_robust_finish_tick",
	"prize_clock.opponent_fastest_finish_tick",
	"prize_clock.opponent_robust_finish_tick",
	"prize_clock.race_margin",
	"prize_clock.opponent_wins_next_window",
	"prize_clock.continuity_debt_cost_ticks",
	"prize_clock.credible_gust",
	"prize_clock.public_gust_exhausted",
	"prize_clock.own_robust_prize_sequence",
	"prize_clock.opponent_robust_prize_sequence",
	"route.current_valid",
	"turn.energy_available",
	"turn.supporter_available",
]


static func branchable_fact_paths(facts: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for root: String in BRANCHABLE_FACT_ROOTS:
		if not facts.has(root):
			continue
		_collect_branchable_fact_paths(
			facts.get(root),
			root,
			result
		)
	result.sort()
	return result


static func canonical_fact_path(path: String) -> String:
	var canonical := path.strip_edges()
	if canonical.begins_with("facts."):
		canonical = canonical.trim_prefix("facts.")
	return str(FACT_PATH_ALIASES.get(canonical, canonical))


static func _collect_branchable_fact_paths(
	value: Variant,
	path: String,
	output: Array[String]
) -> void:
	if value is Dictionary:
		var keys: Array = (value as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for raw_key: Variant in keys:
			var key := str(raw_key)
			if key == "" or "." in key:
				continue
			_collect_branchable_fact_paths(
				(value as Dictionary).get(raw_key),
				"%s.%s" % [path, key],
				output
			)
		return
	if _is_guard_fact_value(value):
		output.append(path)


static func _is_guard_fact_value(value: Variant) -> bool:
	if value == null \
			or value is bool \
			or value is int \
			or value is float \
			or value is String:
		return true
	if not (value is Array):
		return false
	for item: Variant in value as Array:
		if item is Dictionary or item is Array or item is Object:
			return false
	return true


static func strategy_id(deck_id: int, slug: String) -> String:
	return "v18cpg_%d_%s" % [deck_id, slug]


static func make_lifecycle(run_id: String, match_id: String, turn_id: int, serial: int = 1) -> Dictionary:
	var stem := "%s:%s:t%d" % [run_id, match_id, turn_id]
	return {
		"run_id": run_id,
		"match_id": match_id,
		"turn_id": turn_id,
		"policy_id": "%s:p%d" % [stem, serial],
		"revision_id": "%s:r%d" % [stem, serial],
		"decision_window_id": "%s:w%d" % [stem, serial],
		"request_id": "%s:q%d" % [stem, serial],
	}


static func stable_hash(value: Variant) -> String:
	return JSON.stringify(_canonicalize(value)).sha256_text()


static func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		var keys: Array = (value as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key: Variant in keys:
			result[str(key)] = _canonicalize((value as Dictionary).get(key))
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_canonicalize(item))
		return result
	return value
