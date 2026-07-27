class_name V18CPGPrizeClockSolver
extends RefCounted

## Shared public-state prize-race clock.
##
## One tick is one attack window, not one raw engine turn:
##   0 = our current attack window, 1 = opponent's next attack window,
##   2 = our following attack window, and so on.
##
## The solver deliberately exposes both a fastest visible lane and a robust
## active-lane projection.  Neither projection is an execution certificate.
## Exact route upgrades are minted by the prize-clock capability module only
## when the candidate binds every public precondition.

const ThreatResponseScript = preload(
	"res://scripts/ai/v18_cpg/planning/V18CPGThreatResponseSolver.gd"
)

const ATTACK_WINDOW_INTERVAL := 2
const OWN_CURRENT_ATTACK_TICK := 0
const OPPONENT_NEXT_ATTACK_TICK := 1

var _threat_response = ThreatResponseScript.new()


func solve(
	observation: Dictionary,
	facts: Dictionary,
	_profile: Dictionary = {}
) -> Dictionary:
	var own: Dictionary = observation.get("own", {}) \
		if observation.get("own", {}) is Dictionary else {}
	var opponent: Dictionary = observation.get("opponent", {}) \
		if observation.get("opponent", {}) is Dictionary else {}
	var own_active: Dictionary = own.get("active", {}) \
		if own.get("active", {}) is Dictionary else {}
	var opponent_active: Dictionary = opponent.get("active", {}) \
		if opponent.get("active", {}) is Dictionary else {}
	var attack: Dictionary = facts.get("attack", {}) \
		if facts.get("attack", {}) is Dictionary else {}
	var prize: Dictionary = facts.get("prize", {}) \
		if facts.get("prize", {}) is Dictionary else {}
	var continuity: Dictionary = facts.get("continuity", {}) \
		if facts.get("continuity", {}) is Dictionary else {}
	var attack_ready := bool(attack.get("ready", false))
	var ko_available := bool(attack.get("ko_available", false))
	var own_remaining := maxi(0, int(own.get("prizes_remaining", 0)))
	var opponent_remaining := maxi(
		0,
		int(opponent.get("prizes_remaining", 0))
	)
	var current_prize_swing := int(prize.get(
		"current_swing",
		int(opponent_active.get("prize_count", 1)) if ko_available else 0
	))
	if not ko_available:
		current_prize_swing = 0
	var own_active_prizes := maxi(1, int(own_active.get("prize_count", 1)))
	var opponent_active_prizes := maxi(
		1,
		int(opponent_active.get("prize_count", 1))
	)
	var fastest_visible_prizes := _maximum_visible_prize(opponent)
	var own_first_tick := OWN_CURRENT_ATTACK_TICK \
		if attack_ready and ko_available \
		else OWN_CURRENT_ATTACK_TICK + ATTACK_WINDOW_INTERVAL
	var own_fastest := _schedule(
		own_remaining,
		fastest_visible_prizes,
		current_prize_swing,
		own_first_tick
	)
	var own_robust := _schedule(
		own_remaining,
		opponent_active_prizes,
		current_prize_swing,
		own_first_tick
	)
	var continuity_floor_met := not bool(continuity.get("enabled", false)) \
		or bool(continuity.get("floor_met", true))
	var continuity_debt_cost_ticks := 0
	if not continuity_floor_met \
			and int(own_robust.get("remaining_after_first_window", 0)) > 0:
		continuity_debt_cost_ticks = ATTACK_WINDOW_INTERVAL
		own_robust["finish_tick"] = int(own_robust.get(
			"finish_tick",
			own_first_tick
		)) + continuity_debt_cost_ticks
		own_robust["continuity_debt_cost_ticks"] = continuity_debt_cost_ticks
	var threat := _threat_response.solve(observation)
	var response_evidence: Dictionary = observation.get(
		"public_response_evidence",
		{}
	) if observation.get("public_response_evidence", {}) is Dictionary else {}
	var gust_exhausted := bool(response_evidence.get(
		"gust_exhausted",
		false
	)) and str(response_evidence.get("source", "")) != ""
	var credible_gust := not gust_exhausted \
		and not (own.get("bench", []) as Array).is_empty() \
		if own.get("bench", []) is Array else false
	var liability_map := _liability_map(
		own,
		threat,
		credible_gust
	)
	var credible_next_window_prizes := _maximum_credible_liability_prizes(
		liability_map,
		own_active_prizes
	)
	var opponent_robust := _schedule(
		opponent_remaining,
		credible_next_window_prizes,
		0,
		OPPONENT_NEXT_ATTACK_TICK
	)
	var opponent_fastest := _schedule(
		opponent_remaining,
		_maximum_visible_prize(own),
		0,
		OPPONENT_NEXT_ATTACK_TICK
	)
	var opponent_wins_next_window := opponent_remaining > 0 \
		and opponent_remaining <= credible_next_window_prizes
	var race_margin := int(opponent_robust.get("finish_tick", 0)) \
		- int(own_robust.get("finish_tick", 0))
	return {
		"schema_version": 1,
		"tick_unit": "attack_window",
		"current_tick": OWN_CURRENT_ATTACK_TICK,
		"current_attack_window_open": attack_ready,
		"own": {
			"fastest": own_fastest,
			"robust": own_robust,
		},
		"opponent": {
			"fastest": opponent_fastest,
			"robust": opponent_robust,
		},
		"race_margin": race_margin,
		"opponent_wins_next_window": opponent_wins_next_window,
		"continuity_floor_met": continuity_floor_met,
		"continuity_debt_count": int(continuity.get("debt_count", 0)),
		"continuity_debt_cost_ticks": continuity_debt_cost_ticks,
		"credible_gust": credible_gust,
		"credible_next_window_prizes": credible_next_window_prizes,
		"public_gust_exhausted": gust_exhausted,
		"public_gust_evidence_source": str(response_evidence.get("source", "")),
		"threat_response": threat,
		"liability_map": liability_map,
	}


func project_candidate(
	baseline: Dictionary,
	candidate: Dictionary,
	observation: Dictionary,
	facts: Dictionary,
	extension: Dictionary = {}
) -> Dictionary:
	var own: Dictionary = observation.get("own", {}) \
		if observation.get("own", {}) is Dictionary else {}
	var opponent: Dictionary = observation.get("opponent", {}) \
		if observation.get("opponent", {}) is Dictionary else {}
	var opponent_active: Dictionary = opponent.get("active", {}) \
		if opponent.get("active", {}) is Dictionary else {}
	var own_remaining := maxi(0, int(own.get("prizes_remaining", 0)))
	var opponent_remaining := maxi(
		0,
		int(opponent.get("prizes_remaining", 0))
	)
	var action_kind := str(candidate.get("action_kind", ""))
	var outcome: Dictionary = candidate.get("outcome", {}) \
		if candidate.get("outcome", {}) is Dictionary else {}
	var same_window: Dictionary = extension.get("same_attack_window", {}) \
		if extension.get("same_attack_window", {}) is Dictionary else {}
	var prize_denial: Dictionary = extension.get("prize_denial", {}) \
		if extension.get("prize_denial", {}) is Dictionary else {}
	var prizes_now := maxi(0, int(outcome.get("prizes_now", 0)))
	var first_tick := OWN_CURRENT_ATTACK_TICK
	var first_gain := 0
	var consumes_attack_window := action_kind == "end_turn"
	var same_window_attack_preserved := not consumes_attack_window
	if action_kind in ["attack", "granted_attack"]:
		first_gain = prizes_now
		if first_gain <= 0:
			first_tick += ATTACK_WINDOW_INTERVAL
	elif action_kind == "retreat":
		same_window_attack_preserved = bool(same_window.get(
			"attack_ready",
			false
		))
		if bool(same_window.get("ko_ready", false)):
			first_gain = maxi(
				1,
				int(opponent_active.get("prize_count", 1))
			)
		else:
			first_tick += ATTACK_WINDOW_INTERVAL
	elif consumes_attack_window:
		first_tick += ATTACK_WINDOW_INTERVAL
	elif bool(baseline.get("current_attack_window_open", false)):
		first_gain = int(facts.get("prize", {}).get(
			"current_swing",
			0
		)) if facts.get("prize", {}) is Dictionary else 0
		if first_gain <= 0:
			first_tick += ATTACK_WINDOW_INTERVAL
	else:
		first_tick += ATTACK_WINDOW_INTERVAL

	var robust_prize_per_window := maxi(
		1,
		int(opponent_active.get("prize_count", 1))
	)
	var own_robust := _schedule(
		own_remaining,
		robust_prize_per_window,
		first_gain,
		first_tick
	)
	var continuity: Dictionary = facts.get("continuity", {}) \
		if facts.get("continuity", {}) is Dictionary else {}
	var continuity_floor_met_before := not bool(
		continuity.get("enabled", false)
	) or bool(continuity.get("floor_met", true))
	var continuity_effect: Dictionary = candidate.get(
		"post_attack_continuity",
		{}
	) if candidate.get("post_attack_continuity", {}) is Dictionary else {}
	var debt_count := maxi(0, int(continuity.get("debt_count", 0)))
	var debt_reduction := maxi(
		0,
		int(continuity_effect.get("debt_reduction_count", 0))
	)
	var continuity_floor_met_after := continuity_floor_met_before \
		or debt_count > 0 and debt_reduction >= debt_count
	if not continuity_floor_met_after \
			and int(own_robust.get("remaining_after_first_window", 0)) > 0:
		own_robust["finish_tick"] = int(own_robust.get(
			"finish_tick",
			first_tick
		)) + ATTACK_WINDOW_INTERVAL
		own_robust["continuity_debt_cost_ticks"] = ATTACK_WINDOW_INTERVAL

	var opponent_active_prizes := maxi(
		1,
		int((own.get("active", {}) as Dictionary).get("prize_count", 1))
	) if own.get("active", {}) is Dictionary else 1
	var opponent_robust: Dictionary
	if str(prize_denial.get("level", "")) == "forced":
		var bridge_prizes := maxi(
			1,
			int(prize_denial.get("exposed_prize_count", 1))
		)
		opponent_robust = _schedule_with_first_gain(
			opponent_remaining,
			bridge_prizes,
			opponent_active_prizes,
			OPPONENT_NEXT_ATTACK_TICK
		)
	else:
		opponent_robust = _schedule(
			opponent_remaining,
			opponent_active_prizes,
			0,
			OPPONENT_NEXT_ATTACK_TICK
		)
	var own_finish := int(own_robust.get("finish_tick", first_tick))
	var opponent_finish := int(opponent_robust.get(
		"finish_tick",
		OPPONENT_NEXT_ATTACK_TICK
	))
	var baseline_own_finish := int(
		(baseline.get("own", {}) as Dictionary).get(
			"robust",
			{}
		).get("finish_tick", own_finish)
	) if baseline.get("own", {}) is Dictionary else own_finish
	var baseline_opponent_finish := int(
		(baseline.get("opponent", {}) as Dictionary).get(
			"robust",
			{}
		).get("finish_tick", opponent_finish)
	) if baseline.get("opponent", {}) is Dictionary else opponent_finish
	var terminal_win := bool(outcome.get("win_now", false)) \
		or first_gain >= own_remaining and own_remaining > 0
	return {
		"own_robust_finish_tick": own_finish,
		"opponent_robust_finish_tick": opponent_finish,
		"race_margin": opponent_finish - own_finish,
		"baseline_race_margin": int(baseline.get("race_margin", 0)),
		"own_finish_tick_improvement": baseline_own_finish - own_finish,
		"opponent_finish_tick_delay": opponent_finish \
			- baseline_opponent_finish,
		"robust_clock_improves": own_finish < baseline_own_finish \
			or opponent_finish > baseline_opponent_finish,
		"continuity_floor_met_before": continuity_floor_met_before,
		"continuity_floor_met_after": continuity_floor_met_after,
		"continuity_debt_reduction": debt_reduction,
		"same_window_attack_preserved": same_window_attack_preserved,
		"consumes_attack_window": consumes_attack_window,
		"first_window_prizes": first_gain,
		"terminal_win": terminal_win,
		"prevents_next_window_loss": bool(
			baseline.get("opponent_wins_next_window", false)
		) and opponent_finish > OPPONENT_NEXT_ATTACK_TICK,
		"own_robust_prize_sequence": own_robust.get(
			"prize_sequence",
			[]
		),
		"opponent_robust_prize_sequence": opponent_robust.get(
			"prize_sequence",
			[]
		),
	}


func compact_baseline(snapshot: Dictionary) -> Dictionary:
	var own: Dictionary = snapshot.get("own", {}) \
		if snapshot.get("own", {}) is Dictionary else {}
	var opponent: Dictionary = snapshot.get("opponent", {}) \
		if snapshot.get("opponent", {}) is Dictionary else {}
	var own_fastest: Dictionary = own.get("fastest", {}) \
		if own.get("fastest", {}) is Dictionary else {}
	var own_robust: Dictionary = own.get("robust", {}) \
		if own.get("robust", {}) is Dictionary else {}
	var opponent_fastest: Dictionary = opponent.get("fastest", {}) \
		if opponent.get("fastest", {}) is Dictionary else {}
	var opponent_robust: Dictionary = opponent.get("robust", {}) \
		if opponent.get("robust", {}) is Dictionary else {}
	return {
		"tick_unit": "attack_window",
		"current_attack_window_open": bool(snapshot.get(
			"current_attack_window_open",
			false
		)),
		"own_fastest_finish_tick": int(own_fastest.get("finish_tick", 0)),
		"own_robust_finish_tick": int(own_robust.get("finish_tick", 0)),
		"opponent_fastest_finish_tick": int(
			opponent_fastest.get("finish_tick", 0)
		),
		"opponent_robust_finish_tick": int(
			opponent_robust.get("finish_tick", 0)
		),
		"own_robust_prize_sequence": own_robust.get("prize_sequence", []),
		"opponent_robust_prize_sequence": opponent_robust.get(
			"prize_sequence",
			[]
		),
		"race_margin": int(snapshot.get("race_margin", 0)),
		"opponent_wins_next_window": bool(snapshot.get(
			"opponent_wins_next_window",
			false
		)),
		"continuity_floor_met": bool(snapshot.get(
			"continuity_floor_met",
			true
		)),
		"continuity_debt_count": int(snapshot.get(
			"continuity_debt_count",
			0
		)),
		"continuity_debt_cost_ticks": int(snapshot.get(
			"continuity_debt_cost_ticks",
			0
		)),
		"credible_gust": bool(snapshot.get("credible_gust", false)),
		"public_gust_exhausted": bool(snapshot.get(
			"public_gust_exhausted",
			false
		)),
	}


func _schedule(
	prizes_remaining: int,
	prizes_per_window: int,
	first_window_gain: int,
	first_tick: int
) -> Dictionary:
	var remaining := maxi(0, prizes_remaining)
	var per_window := maxi(1, prizes_per_window)
	var sequence: Array[int] = []
	var tick := maxi(0, first_tick)
	var first_gain := mini(remaining, maxi(0, first_window_gain))
	if first_gain > 0:
		sequence.append(first_gain)
		remaining -= first_gain
		if remaining > 0:
			tick += ATTACK_WINDOW_INTERVAL
	var remaining_after_first := remaining
	while remaining > 0:
		var gain := mini(remaining, per_window)
		sequence.append(gain)
		remaining -= gain
		if remaining > 0:
			tick += ATTACK_WINDOW_INTERVAL
	return {
		"prize_sequence": sequence,
		"finish_tick": tick,
		"first_attack_tick": first_tick,
		"remaining_after_first_window": remaining_after_first,
	}


func _schedule_with_first_gain(
	prizes_remaining: int,
	first_gain: int,
	followup_gain: int,
	first_tick: int
) -> Dictionary:
	var remaining := maxi(0, prizes_remaining)
	var sequence: Array[int] = []
	var tick := maxi(0, first_tick)
	if remaining > 0:
		var gain := mini(remaining, maxi(1, first_gain))
		sequence.append(gain)
		remaining -= gain
	while remaining > 0:
		tick += ATTACK_WINDOW_INTERVAL
		var gain := mini(remaining, maxi(1, followup_gain))
		sequence.append(gain)
		remaining -= gain
	return {
		"prize_sequence": sequence,
		"finish_tick": tick,
		"first_attack_tick": first_tick,
		"remaining_after_first_window": maxi(
			0,
			prizes_remaining - maxi(1, first_gain)
		),
	}


func _liability_map(
	own: Dictionary,
	threat: Dictionary,
	credible_gust: bool
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var slots: Array = []
	if own.get("active", {}) is Dictionary \
			and not (own.get("active", {}) as Dictionary).is_empty():
		slots.append({
			"position": "active",
			"slot": own.get("active", {}),
		})
	if own.get("bench", []) is Array:
		for raw_slot: Variant in own.get("bench", []):
			if raw_slot is Dictionary:
				slots.append({"position": "bench", "slot": raw_slot})
	for raw_entry: Variant in slots:
		var entry: Dictionary = raw_entry
		var slot: Dictionary = entry.get("slot", {}) \
			if entry.get("slot", {}) is Dictionary else {}
		var pokemon: Dictionary = slot.get("pokemon", {}) \
			if slot.get("pokemon", {}) is Dictionary else {}
		var max_hp := maxi(
			1,
			int(slot.get(
				"max_hp",
				int(slot.get("remaining_hp", 0)) + int(slot.get("damage", 0))
			))
		)
		var damage := maxi(0, int(slot.get("damage", 0)))
		var position := str(entry.get("position", ""))
		var prize_count := maxi(1, int(slot.get("prize_count", 1)))
		var gust_exposed := position == "bench" and credible_gust
		var credible_ko := position == "active" \
			or gust_exposed
		result.append({
			"slot_id": str(slot.get("slot_id", "")),
			"position": position,
			"pokemon_uid": str(pokemon.get("uid", "")),
			"prize_count": prize_count,
			"remaining_hp": int(slot.get("remaining_hp", 0)),
			"max_hp": max_hp,
			"damage": damage,
			"damage_ratio": snappedf(
				float(damage) / float(max_hp),
				0.001
			),
			"retreat_cost": int(slot.get("retreat_cost", 0)),
			"attached_energy_count": _slot_energy_count(slot),
			"credible_ko": credible_ko,
			"gust_exposed": gust_exposed,
			"liability_weight": prize_count * 100 \
				+ int(round(float(damage) / float(max_hp) * 50.0)) \
				+ _slot_energy_count(slot) * 10,
			"threat_uncertainty": float(threat.get("uncertainty", 1.0)),
		})
	return result


func _maximum_visible_prize(side: Dictionary) -> int:
	var result := 1
	if side.get("active", {}) is Dictionary:
		result = maxi(
			result,
			int((side.get("active", {}) as Dictionary).get("prize_count", 1))
		)
	if side.get("bench", []) is Array:
		for raw_slot: Variant in side.get("bench", []):
			if raw_slot is Dictionary:
				result = maxi(
					result,
					int((raw_slot as Dictionary).get("prize_count", 1))
				)
	return result


func _maximum_credible_liability_prizes(
	liability_map: Array[Dictionary],
	fallback: int
) -> int:
	var result := maxi(1, fallback)
	for entry: Dictionary in liability_map:
		if not bool(entry.get("credible_ko", false)):
			continue
		result = maxi(result, int(entry.get("prize_count", 1)))
	return result


func _slot_energy_count(slot: Dictionary) -> int:
	return maxi(
		int(slot.get("energy_count", 0)),
		(slot.get("energy", []) as Array).size() \
			if slot.get("energy", []) is Array else 0
	)
