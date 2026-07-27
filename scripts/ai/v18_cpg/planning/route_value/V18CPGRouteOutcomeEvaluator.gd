class_name V18CPGRouteOutcomeEvaluator
extends RefCounted


func evaluate(
	candidate: Dictionary,
	transition: Dictionary,
	continuity_demand: Dictionary,
	response_envelope: Dictionary,
	facts: Dictionary
) -> Dictionary:
	var legacy_outcome: Dictionary = candidate.get("outcome", {}) \
		if candidate.get("outcome", {}) is Dictionary else {}
	var current_debt := int(facts.get("continuity", {}).get("debt_count", 0))
	var debt_reduction := int(legacy_outcome.get("continuity_debt_reduction", 0))
	var ledger_debt := 0
	if not bool(transition.get("supported", false)):
		ledger_debt += 1
	var uncertainty := float(legacy_outcome.get("uncertainty", 0.0))
	if bool(transition.get("requires_reobservation", false)):
		uncertainty = maxf(uncertainty, 0.45)
	var verified_responses := int(response_envelope.get("verified_response_count", 0))
	var credible_responses := int(response_envelope.get("credible_response_count", 0))
	var liability := float(verified_responses) + float(credible_responses) * 0.45
	var race_margin := int(
		facts.get("prize_clock", {}).get(
			"race_margin",
			continuity_demand.get("race_margin", 0)
		)
	)
	return {
		"win_now": bool(legacy_outcome.get("win_now", false)),
		"prevents_next_window_loss": bool(
			legacy_outcome.get("prevents_next_window_loss", false)
		),
		"prizes_now": int(legacy_outcome.get("prizes_now", 0)),
		"own_finish_tick": int(
			facts.get("prize_clock", {}).get("own_robust_finish_tick", 0)
		),
		"opponent_finish_tick": int(
			facts.get("prize_clock", {}).get("opponent_robust_finish_tick", 0)
		),
		"race_margin": race_margin,
		"current_attack_window_preserved": (
			str(candidate.get("route_id", "")) != "route:end_turn"
		),
		"next_attack_window_uptime": _next_window_uptime(
			continuity_demand,
			facts,
			debt_reduction
		),
		"continuity_debt": maxi(0, current_debt - debt_reduction),
		"ledger_debt": ledger_debt,
		"liability": liability,
		"information_value": float(legacy_outcome.get("information_gain", 0.0)),
		"uncertainty": uncertainty,
	}


func _next_window_uptime(
	demand: Dictionary,
	facts: Dictionary,
	debt_reduction: int
) -> bool:
	if int(demand.get("remaining_attack_windows", 0)) == 0:
		return true
	var supply: Dictionary = demand.get("current_supply", {}) \
		if demand.get("current_supply", {}) is Dictionary else {}
	if int(supply.get("next_attacker_roots", 0)) \
			< int(demand.get("minimum_next_attacker_roots", 0)):
		return false
	if int(supply.get("live_energy_engines", 0)) \
			< int(demand.get("minimum_energy_engine_width", 0)):
		return false
	if int(supply.get("current_search_engines", 0)) \
			< int(demand.get("minimum_current_search_lane", 0)):
		return false
	if int(supply.get("future_search_roots", 0)) \
			< int(demand.get("minimum_future_search_root", 0)):
		return false
	var banked := int(facts.get("continuity", {}).get("banked_damage_units", 0))
	return banked + debt_reduction \
		>= int(demand.get("required_banked_damage_units", 0))
