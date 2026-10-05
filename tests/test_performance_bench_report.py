import copy
import unittest

from scripts.tools.run_performance_bench import aggregate, statistics, validate_report, GROUPS
from scripts.tools.compare_performance_bench import compare


class PerformanceBenchReportTests(unittest.TestCase):
    def report(self):
        return {"schema_version": 1, "kind": "ptcgdap_performance_bench", "group": "matches",
                "platform": {"os": "Windows", "architecture": "x86_64", "engine": "4.6.1",
                             "display": "windows", "viewport": [1280, 720]},
                "cases": [{"case": name, "iteration": 0, "cache_state": "first_in_process",
                           "ok": True, "duration_ms": 2500, "frame_gaps_ms": [16, 1200],
                           "measurement": "full_match_logic", "feedback_ms": None} for name in GROUPS["matches"]]}

    def test_partial_script_error_cannot_pass_even_with_zero_exit_and_success_marker(self):
        report = self.report()
        report["cases"].pop()
        errors = validate_report(report, "matches", 1, "SCRIPT ERROR: failure\nPTCGDAP_PERFORMANCE_BENCH={}")
        self.assertIn("engine_script_error", errors)
        self.assertTrue(any(e.startswith("missing_or_failed_case") for e in errors))

    def test_tail_cold_and_distinct_platforms_remain_visible(self):
        report = self.report()
        android = copy.deepcopy(report)
        android["platform"]["os"] = "Android"
        rows = aggregate([report, android])
        self.assertEqual(len(rows), 4)
        self.assertTrue(all(r["frame_gaps"]["max_ms"] == 1200 for r in rows))
        self.assertTrue(all("unresponsive_over_1s" in r["budget_misses"] for r in rows))
        self.assertEqual(statistics([1200, 10, 20])["p95_ms"], 1200)

    def test_headless_does_not_claim_smooth_rendering(self):
        report = self.report()
        report["platform"]["display"] = "headless"
        self.assertTrue(all(r["frame_acceptance"] == "unverified" for r in aggregate([report])))

    def test_missing_feedback_and_nan_cannot_pass(self):
        report = self.report()
        report["cases"][0]["measurement"] = "interaction"
        self.assertIn("feedback_unverified_or_over_1s", aggregate([report])[0]["budget_misses"])
        report["cases"][0]["duration_ms"] = float("nan")
        self.assertIn("invalid_duration", validate_report(report, "matches", 1, "PTCGDAP_PERFORMANCE_BENCH={}"))

    def test_nonfinite_feedback_is_invalid(self):
        report = self.report()
        report["cases"][0]["feedback_ms"] = float("nan")
        self.assertIn("invalid_feedback", validate_report(report, "matches", 1, "PTCGDAP_PERFORMANCE_BENCH={}"))

    def test_android_prefixed_engine_error_invalidates_completed_report(self):
        errors = validate_report(self.report(), "matches", 1,
                                 "E/godot (4144): ERROR: failed\nI/godot: PTCGDAP_PERFORMANCE_BENCH={}")
        self.assertIn("engine_script_error", errors)

    def test_completely_missing_final_iteration_is_not_inferred_away(self):
        errors = validate_report(self.report(), "matches", 2, "PTCGDAP_PERFORMANCE_BENCH={}")
        self.assertIn("missing_or_failed_case:1:match.rules", errors)

    def test_comparison_rejects_different_platform_and_failed_run(self):
        report = self.report()
        first = {"status": "needs_optimization", "summary": aggregate([report])}
        android = copy.deepcopy(report)
        android["platform"]["os"] = "Android"
        with self.assertRaises(ValueError):
            compare(first, {"status": "needs_optimization", "summary": aggregate([android])})
        with self.assertRaises(ValueError):
            compare(first, {"status": "invalid", "summary": first["summary"]})
        self.assertEqual(compare(first, first)[0]["change_percent"], 0)


if __name__ == "__main__":
    unittest.main()
