class_name V18CPGVisibleWaitBudget
extends RefCounted

const DEFAULT_BUDGET_MS := 12000
const DEFAULT_COLD_ESTIMATE_MS := 6500


func budget_for_turn(
	base_budget_ms: int,
	turn_number: int,
	growth_ms: int,
	growth_every_turns: int,
	cap_ms: int
) -> int:
	var base := maxi(1000, base_budget_ms)
	var bounded_cap := maxi(base, cap_ms)
	var cadence := maxi(1, growth_every_turns)
	var completed_growth_steps := maxi(0, maxi(1, turn_number) - 1) / cadence
	return mini(
		bounded_cap,
		base + completed_growth_steps * maxi(0, growth_ms)
	)


func may_request(
	spent_ms: int,
	wait_samples_ms: Array[float],
	requests_this_turn: int,
	budget_ms: int = DEFAULT_BUDGET_MS,
	cold_estimate_ms: int = DEFAULT_COLD_ESTIMATE_MS
) -> Dictionary:
	var bounded_budget := maxi(1000, budget_ms)
	# Every decision-bearing turn may make its first valuable request.  Later
	# revisions are controlled by expected visible wait, not a hard call count:
	# a faster/cached model can still replan repeatedly inside the same budget.
	if requests_this_turn <= 0:
		return {
			"allowed": true,
			"reason": "first_request",
			"expected_request_ms": _expected_wait(wait_samples_ms, cold_estimate_ms),
			"remaining_ms": maxi(0, bounded_budget - spent_ms),
		}
	var expected := _expected_wait(wait_samples_ms, cold_estimate_ms)
	var remaining := maxi(0, bounded_budget - spent_ms)
	return {
		"allowed": expected <= remaining,
		"reason": "within_visible_wait_budget" if expected <= remaining else "visible_wait_budget_exhausted",
		"expected_request_ms": expected,
		"remaining_ms": remaining,
	}


func _expected_wait(samples: Array[float], cold_estimate_ms: int) -> int:
	if samples.is_empty():
		return maxi(1000, cold_estimate_ms)
	var sorted := samples.duplicate()
	sorted.sort()
	var index := clampi(int(ceil(float(sorted.size()) * 0.75)) - 1, 0, sorted.size() - 1)
	return maxi(1000, int(ceil(sorted[index])))
