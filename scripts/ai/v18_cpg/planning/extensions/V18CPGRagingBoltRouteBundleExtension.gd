class_name V18CPGRagingBoltRouteBundleExtension
extends RefCounted

const TrainerPairScript = preload(
	"res://scripts/ai/v18_cpg/planning/extensions/V18CPGRagingBoltTrainerPairSolver.gd"
)

const AREA_ZERO_UID := "CSV9C_207"
const TEAL_MASK_UID := "CSV8C_028"
const NOCTOWL_UID := "CSV9C_155"

var _trainer_pair = TrainerPairScript.new()


func projected_followups(
	candidate: Dictionary,
	observation: Dictionary,
	continuity_demand: Dictionary,
	max_count: int
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if max_count <= 0:
		return result
	var route_id := str(candidate.get("route_id", ""))
	var card_uid := _candidate_card_uid(candidate)
	var source_uid := _candidate_source_uid(candidate)
	if card_uid == AREA_ZERO_UID:
		var next_route := _area_zero_followup(observation, continuity_demand)
		if next_route != "":
			result.append({
				"route_id": next_route,
				"dependency": "expanded_bench_capacity",
				"origin": "raging_bolt_area_zero",
			})
	if route_id == "route:evolve" and card_uid == NOCTOWL_UID:
		result.append({
			"route_id": "route:noctowl_search",
			"dependency": "noctowl_evolved",
			"origin": "raging_bolt_noctowl",
		})
	if source_uid == TEAL_MASK_UID and route_id == "route:information":
		result.append({
			"route_id": "route:energy_commit",
			"dependency": "teal_dance_result",
			"origin": "raging_bolt_teal_dance",
		})
	if result.size() > max_count:
		result.resize(max_count)
	return result


func annotate_bundle(
	bundle: Dictionary,
	candidate: Dictionary,
	observation: Dictionary,
	facts: Dictionary,
	continuity_demand: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var annotation := {
		"extension": "raging_bolt",
		"dynamic_damage_units_required": int(
			continuity_demand.get("dynamic_damage_units_required", 0)
		),
		"noctowl_current_lane": int(
			continuity_demand.get("noctowl_current_lane", 0)
		),
		"hoothoot_future_lane": int(
			continuity_demand.get("hoothoot_future_lane", 0)
		),
	}
	var steps: Array = bundle.get("steps", []) \
		if bundle.get("steps", []) is Array else []
	var card_uid := _candidate_card_uid(candidate)
	var source_uid := _candidate_source_uid(candidate)
	if str(candidate.get("route_id", "")) == "route:noctowl_search" \
			or source_uid == NOCTOWL_UID:
		annotation["trainer_pair_contract"] = _trainer_pair.contract_for_profile(
			profile,
			_required_pair_roles(continuity_demand)
		)
	if card_uid == AREA_ZERO_UID:
		annotation["area_zero_bound_followup"] = _has_projected_followup(
			steps,
			["route:develop", "route:evolve", "route:noctowl_search"]
		)
	if source_uid == TEAL_MASK_UID:
		annotation["teal_dance_current_value"] = _teal_dance_value(
			facts,
			continuity_demand,
			observation
		)
	var bank_before := int(
		facts.get("continuity", {}).get("banked_damage_units", 0)
	)
	annotation["banked_damage_units_before"] = bank_before
	annotation["banked_damage_units_after"] = (
		bank_before + 1 if source_uid == TEAL_MASK_UID else bank_before
	)
	var terminal_attack := str(candidate.get("route_id", "")) in [
		"route:attack_ko",
		"route:attack_pressure",
	]
	var win_now := bool(facts.get("prize", {}).get("win_now", false))
	var required_bank := int(
		continuity_demand.get("required_banked_damage_units", 0)
	)
	var continuity_closed := _continuity_debt_closed(
		continuity_demand,
		bank_before
	)
	annotation["premature_attack_prevented"] = terminal_attack \
		and not win_now and not continuity_closed
	var optional_information := str(candidate.get("route_id", "")) in [
		"route:information",
		"route:opening_search",
		"route:noctowl_search",
		"route:tutor",
	]
	annotation["optional_churn_stopped"] = optional_information \
		and (
			win_now
			or continuity_closed
		)
	return annotation


func _area_zero_followup(
	observation: Dictionary,
	demand: Dictionary
) -> String:
	var supply: Dictionary = demand.get("current_supply", {}) \
		if demand.get("current_supply", {}) is Dictionary else {}
	if int(supply.get("future_search_roots", 0)) > 0 \
			and int(supply.get("current_search_engines", 0)) <= 0:
		return "route:evolve"
	if int(supply.get("live_energy_engines", 0)) \
			< int(demand.get("minimum_energy_engine_width", 0)):
		return "route:develop"
	if int(demand.get("minimum_future_search_root", 0)) > 0 \
			and int(supply.get("future_search_roots", 0)) <= 0:
		return "route:develop"
	return ""


func _required_pair_roles(demand: Dictionary) -> Array:
	if int(demand.get("required_banked_damage_units", 0)) > 0:
		return ["supporter_acceleration", "energy_access"]
	return ["gust", "energy_access"]


func _teal_dance_value(
	facts: Dictionary,
	demand: Dictionary,
	observation: Dictionary
) -> float:
	var attack_deficit := int(facts.get("attack", {}).get("energy_deficit", 0))
	var banked := int(facts.get("continuity", {}).get("banked_damage_units", 0))
	var required := int(demand.get("required_banked_damage_units", 0))
	var bank_deficit := maxi(0, required - banked)
	var remaining_windows := int(demand.get("remaining_attack_windows", 0))
	var opponent: Dictionary = observation.get("opponent", {}) \
		if observation.get("opponent", {}) is Dictionary else {}
	var liability_penalty := 1.5 \
		if int(opponent.get("prizes_remaining", 6)) <= 2 else 0.5
	return float(
		attack_deficit * 3
		+ bank_deficit * 2
		+ remaining_windows
	) + 1.0 - liability_penalty


func _continuity_debt_closed(demand: Dictionary, banked: int) -> bool:
	var supply: Dictionary = demand.get("current_supply", {}) \
		if demand.get("current_supply", {}) is Dictionary else {}
	return banked >= int(demand.get("required_banked_damage_units", 0)) \
		and int(supply.get("live_energy_engines", 0)) \
			>= int(demand.get("minimum_energy_engine_width", 0)) \
		and int(supply.get("current_search_engines", 0)) \
			>= int(demand.get("minimum_current_search_lane", 0)) \
		and int(supply.get("future_search_roots", 0)) \
			>= int(demand.get("minimum_future_search_root", 0)) \
		and int(supply.get("next_attacker_roots", 0)) \
			>= int(demand.get("minimum_next_attacker_roots", 0))


func _has_projected_followup(
	steps: Array,
	route_ids: Array[String]
) -> bool:
	for index: int in range(1, steps.size()):
		if steps[index] is Dictionary \
				and str((steps[index] as Dictionary).get("route_id", "")) in route_ids:
			return true
	return false


func _candidate_card_uid(candidate: Dictionary) -> String:
	var action: Dictionary = candidate.get("action_ref", {}) \
		if candidate.get("action_ref", {}) is Dictionary else {}
	var card: Dictionary = action.get("card", {}) \
		if action.get("card", {}) is Dictionary else {}
	return str(card.get("uid", "")).to_upper()


func _candidate_source_uid(candidate: Dictionary) -> String:
	var action: Dictionary = candidate.get("action_ref", {}) \
		if candidate.get("action_ref", {}) is Dictionary else {}
	var card: Dictionary = action.get("source_card", {}) \
		if action.get("source_card", {}) is Dictionary else {}
	return str(card.get("uid", "")).to_upper()
