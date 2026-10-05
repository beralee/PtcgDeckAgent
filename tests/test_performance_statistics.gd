extends TestBase

const Stats = preload("res://scripts/performance/PerformanceStatistics.gd")

func test_tail_and_cold_sample_are_not_discarded() -> String:
	var values: Array = [1200.0, 10.0, 20.0, 30.0]
	var result := Stats.summarize(values)
	return run_checks([
		assert_eq(result.count, 4), assert_eq(result.p50_ms, 20.0),
		assert_eq(result.p95_ms, 1200.0), assert_eq(result.p99_ms, 1200.0),
		assert_eq(result.at_least_1000_ms, 1), assert_eq(values[0], 1200.0),
	])

func test_empty_measurement_is_not_zero_latency_success() -> String:
	return assert_eq(Stats.summarize([]), {"count": 0})
