class_name V18CPGContinuityDemandSolver
extends RefCounted

const ContractsScript = preload(
	"res://scripts/ai/v18_cpg/schema/V18CPGContracts.gd"
)
const RagingBoltDemandScript = preload(
	"res://scripts/ai/v18_cpg/planning/extensions/V18CPGRagingBoltContinuityDemand.gd"
)


func solve(
	observation: Dictionary,
	facts: Dictionary,
	prize_clock: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var win_now := bool(facts.get("prize", {}).get("win_now", false))
	var prize_sequence := _own_robust_sequence(prize_clock)
	var remaining_windows := 0 if win_now else maxi(1, prize_sequence.size())
	var target_hp := 0 if win_now else _next_target_hp(
		observation,
		bool(facts.get("attack", {}).get("ko_available", false))
	)
	var continuity: Dictionary = profile.get("post_attack_continuity", {}) \
		if profile.get("post_attack_continuity", {}) is Dictionary else {}
	var required_types: Array = continuity.get("required_attack_types", []) \
		if continuity.get("required_attack_types", []) is Array else []
	var current_supply := _public_supply(observation, continuity)
	var tracks_energy_engine := bool(current_supply.get("tracks_energy_engine", false))
	var tracks_search_engine := bool(current_supply.get("tracks_search_engine", false))
	var tracks_next_attacker := bool(current_supply.get("tracks_next_attacker", false))
	var result := {
		"schema_version": 1,
		"route_value_graph_version": ContractsScript.ROUTE_VALUE_GRAPH_VERSION,
		"win_now_release": win_now,
		"remaining_attack_windows": remaining_windows,
		"next_target_damage": target_hp,
		"minimum_next_attacker_roots": (
			0 if win_now or not tracks_next_attacker else 1
		),
		"minimum_next_attacker_cost_units": (
			0 if win_now else required_types.size()
		),
		"required_attack_types": required_types.duplicate(),
		"minimum_energy_engine_width": (
			0 if win_now or not tracks_energy_engine
			else mini(2, maxi(1, ceili(float(remaining_windows) / 2.0)))
		),
		"minimum_current_search_lane": (
			0 if win_now or not tracks_search_engine
			else (1 if remaining_windows >= 1 else 0)
		),
		"minimum_future_search_root": (
			0 if win_now or not tracks_search_engine
			else (1 if remaining_windows >= 2 else 0)
		),
		"required_banked_damage_units": 0,
		"bench_capacity_required": (
			0 if win_now else _required_bench_capacity(current_supply)
		),
		"recovery_window_required": not win_now and remaining_windows >= 2,
		"low_deck_risk": _low_deck_risk(observation, profile),
		"current_supply": current_supply,
	}
	if int(profile.get("deck_id", 0)) == 800018509:
		result.merge(
			RagingBoltDemandScript.new().solve(
				observation,
				facts,
				prize_clock,
				profile
			),
			true
		)
	result["demand_hash"] = ContractsScript.stable_hash(result)
	return result


func _own_robust_sequence(prize_clock: Dictionary) -> Array:
	var own: Dictionary = prize_clock.get("own", {}) \
		if prize_clock.get("own", {}) is Dictionary else {}
	var robust: Dictionary = own.get("robust", {}) \
		if own.get("robust", {}) is Dictionary else {}
	return robust.get("prize_sequence", []) \
		if robust.get("prize_sequence", []) is Array else []


func _next_target_hp(observation: Dictionary, current_ko: bool) -> int:
	var opponent: Dictionary = observation.get("opponent", {}) \
		if observation.get("opponent", {}) is Dictionary else {}
	var active: Dictionary = opponent.get("active", {}) \
		if opponent.get("active", {}) is Dictionary else {}
	if not current_ko:
		return int(active.get("remaining_hp", 0))
	var best := 0
	for raw_slot: Variant in opponent.get("bench", []):
		if raw_slot is Dictionary:
			best = maxi(best, int((raw_slot as Dictionary).get("remaining_hp", 0)))
	return best if best > 0 else int(active.get("remaining_hp", 0))


func _public_supply(observation: Dictionary, continuity: Dictionary) -> Dictionary:
	var own: Dictionary = observation.get("own", {}) \
		if observation.get("own", {}) is Dictionary else {}
	var engine_uids := _upper_strings(continuity.get("engine_uids", []))
	var root_uids := _upper_strings(continuity.get("search_engine_root_uids", []))
	var search_uids := _upper_strings(continuity.get("search_engine_uids", []))
	var next_attacker_uids := _upper_strings(
		continuity.get("next_attacker_uids", [])
	)
	var live_engines := 0
	var energized_engines := 0
	var current_search := 0
	var future_roots := 0
	var next_attacker_roots := 0
	var slots: Array = []
	if own.get("active", {}) is Dictionary:
		slots.append(own.get("active", {}))
	if own.get("bench", []) is Array:
		slots.append_array(own.get("bench", []))
	for raw_slot: Variant in slots:
		if not (raw_slot is Dictionary):
			continue
		var slot: Dictionary = raw_slot
		var pokemon: Dictionary = slot.get("pokemon", {}) \
			if slot.get("pokemon", {}) is Dictionary else {}
		var uid := str(pokemon.get("uid", "")).to_upper()
		if uid in engine_uids:
			live_engines += 1
			if int(slot.get("energy_count", 0)) > 0:
				energized_engines += 1
		if uid in search_uids:
			current_search += 1
		if uid in root_uids:
			future_roots += 1
		if uid in next_attacker_uids:
			next_attacker_roots += 1
	return {
		"tracks_energy_engine": not engine_uids.is_empty(),
		"tracks_search_engine": (
			not search_uids.is_empty() or not root_uids.is_empty()
		),
		"tracks_next_attacker": not next_attacker_uids.is_empty(),
		"live_energy_engines": live_engines,
		"energized_energy_engines": energized_engines,
		"current_search_engines": current_search,
		"future_search_roots": future_roots,
		"next_attacker_roots": next_attacker_roots,
		"bench_occupied": (
			(own.get("bench", []) as Array).size()
			if own.get("bench", []) is Array else 0
		),
	}


func _required_bench_capacity(supply: Dictionary) -> int:
	var missing_engine := 1 if (
		bool(supply.get("tracks_energy_engine", false))
		and int(supply.get("live_energy_engines", 0)) <= 0
	) else 0
	var missing_search := 1 if (
		bool(supply.get("tracks_search_engine", false))
		and int(supply.get("current_search_engines", 0)) <= 0
		and int(supply.get("future_search_roots", 0)) <= 0
	) else 0
	return missing_engine + missing_search


func _low_deck_risk(observation: Dictionary, profile: Dictionary) -> String:
	var own: Dictionary = observation.get("own", {}) \
		if observation.get("own", {}) is Dictionary else {}
	var safety: Dictionary = profile.get("safety", {}) \
		if profile.get("safety", {}) is Dictionary else {}
	var deck_count := int(own.get("deck_count", 0))
	if deck_count <= int(safety.get("critical_deck_threshold", 5)):
		return "critical"
	if deck_count <= int(safety.get("low_deck_threshold", 8)):
		return "low"
	return "normal"


func _upper_strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value:
			result.append(str(raw).strip_edges().to_upper())
	return result
