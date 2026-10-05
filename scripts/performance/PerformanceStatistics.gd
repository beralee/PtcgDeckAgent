extends RefCounted

## Nearest-rank percentiles retain every slow tail, including the first sample.
static func summarize(samples: Array) -> Dictionary:
	if samples.is_empty():
		return {"count": 0}
	var ordered := samples.duplicate()
	ordered.sort()
	var total := 0.0
	var over_50 := 0
	var over_1000 := 0
	for value: Variant in ordered:
		total += float(value)
		if float(value) > 50.0: over_50 += 1
		if float(value) >= 1000.0: over_1000 += 1
	return {
		"count": ordered.size(), "min_ms": float(ordered[0]),
		"mean_ms": total / ordered.size(),
		"p50_ms": _rank(ordered, 0.50), "p95_ms": _rank(ordered, 0.95),
		"p99_ms": _rank(ordered, 0.99), "max_ms": float(ordered[-1]),
		"over_50_ms": over_50, "at_least_1000_ms": over_1000,
	}

static func _rank(ordered: Array, quantile: float) -> float:
	return float(ordered[maxi(0, ceili(quantile * ordered.size()) - 1)])
