import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("parity_review", ROOT / "scripts/tools/compare_android_strategy_parity.py")
review = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(review)


class ParityReviewTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.left, self.right = (Path(self.tmp.name) / name for name in ("android", "windows"))
        for directory, platform in ((self.left, "Android"), (self.right, "Windows")):
            directory.mkdir()
            matches = [{"seed": seed, "seat": seat, "error": ""} for seed in review.SEEDS for seat in (0, 1)]
            self.write(directory / "complete.json", {"ok": True, "platform": platform, "standalone_export": True, "script_errors": [], "package_sha256": "A" * 64, "matches": matches})
            self.write(directory / "smoke.json", [{"test": str(i), "error": ""} for i in range(12)])
            for match in matches:
                audit = dict.fromkeys(review.ZERO_COUNTERS, 0)
                audit.update(policy_successes=1, model_diagnostic_counts={}, model_inference_successes=0, model_fallbacks=0, prompt_counts={"search": 1})
                record = {"frame": {"source": {"public_observation_hash": "B" * 64, "window_id": "window"}, "options": [{"index": 0, "option_fingerprint": "C" * 64}, {"index": 1, "option_fingerprint": "D" * 64}]},
                          "policy": {"ok": True, "error_code": "", "reported_public_observation_hash": "B" * 64, "reported_window_id": "window", "reported_indexes": [0]},
                          "host": {"status": "accepted", "fallback_used": False, "error_code": "", "accepted_indexes": [0], "accepted_option_fingerprints": ["C" * 64], "latency_usec": 100 if platform == "Android" else 10, "model_input_evidence": {"status": "unavailable"}}}
                self.write(directory / f"match-{match['seed']}-{match['seat']}.json", {"package_sha256": "A" * 64, "seed": match["seed"], "summary": {"seat": match["seat"], "game_over": True, "failure": "", "steps": 1}, "test_error": "", "audit": audit, "trace": [record], "winner": 0})

    @staticmethod
    def write(path, value):
        path.write_text(json.dumps(value), encoding="utf-8")

    def mutate_match(self, callback):
        path = self.right / "match-84590-0.json"
        data = review.read(path)
        callback(data)
        self.write(path, data)

    def test_equivalent_windows_allow_only_timing_difference(self):
        self.assertTrue(review.compare(self.left, self.right)["ok"])

    def test_missing_completion_does_not_pass(self):
        (self.right / "complete.json").unlink()
        with self.assertRaises(OSError): review.compare(self.left, self.right)

    def test_truncated_trace_does_not_pass(self):
        self.mutate_match(lambda data: data["trace"].clear())
        with self.assertRaisesRegex(AssertionError, "trace"): review.compare(self.left, self.right)

    def test_stale_worker_fallback_does_not_pass(self):
        self.mutate_match(lambda data: data["audit"].update(policy_worker_stale_results=1))
        with self.assertRaisesRegex(AssertionError, "dirty counter"): review.compare(self.left, self.right)

    def test_changed_package_does_not_pass(self):
        self.mutate_match(lambda data: data.update(package_sha256="D" * 64))
        with self.assertRaisesRegex(AssertionError, "package changed"): review.compare(self.left, self.right)

    def test_legal_but_different_policy_output_is_localized(self):
        def change_selection(data):
            data["trace"][0]["policy"]["reported_indexes"] = [1]
            data["trace"][0]["host"].update(accepted_indexes=[1], accepted_option_fingerprints=["D" * 64])
        self.mutate_match(change_selection)
        result = review.compare(self.left, self.right)
        self.assertFalse(result["ok"])
        self.assertEqual(result["first_difference"]["path"], "$[0].host.accepted_indexes[0]")

    def test_real_model_fallback_cannot_use_fixture_exception(self):
        self.mutate_match(lambda data: data["audit"].update(model_diagnostic_counts={"model_unknown_uid": 1}))
        with self.assertRaisesRegex(AssertionError, "unexpected model fallback"): review.compare(self.left, self.right)

    def model_report(self):
        report = review.read(self.left / "match-84590-0.json")
        report["audit"]["model_inference_successes"] = 1
        host = report["trace"][0]["host"]
        host.update(accepted_indexes=[1], accepted_option_fingerprints=["D" * 64],
                    model_decision={"invoked": True, "diagnostic_code": "", "fallback_indexes": [0], "selected_indexes": [1]},
                    model_input_evidence={"status": "captured", "projector_sha256": "E" * 64, "frontier_indexes": [0, 1]})
        return report

    def test_model_may_change_selection_inside_base_frontier(self):
        review.validate_match(self.model_report(), "A" * 64, 84590, 0)

    def test_model_cannot_escape_base_frontier(self):
        report = self.model_report()
        report["trace"][0]["host"]["model_input_evidence"]["frontier_indexes"] = [0]
        with self.assertRaisesRegex(AssertionError, "escaped"):
            review.validate_match(report, "A" * 64, 84590, 0)

    def test_unexplained_host_selection_change_fails(self):
        report = self.model_report()
        report["trace"][0]["host"].pop("model_decision")
        with self.assertRaisesRegex(AssertionError, "without model"):
            review.validate_match(report, "A" * 64, 84590, 0)


if __name__ == "__main__":
    unittest.main()
