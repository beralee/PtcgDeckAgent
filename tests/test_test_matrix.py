import unittest
import json
from pathlib import Path
import tempfile
from unittest.mock import patch

from scripts.tools.run_test_matrix import validate_report, write_json, release_created_userdata, invoke, startup_script_error, timeout_for_suite, resume_entry


class TestMatrixEvidence(unittest.TestCase):
    def resume_fixture(self, folder, test_filter="", prefix=""):
        report = self.report()
        report["cases"][0]["path"] = "res://tests/test_fixture.gd"
        report["filters"] = {"test-filter": test_filter}
        result, log = Path(folder) / "result.json", Path(folder) / "console.log"
        result.write_text(json.dumps(report), encoding="utf-8")
        log.write_text(prefix + "RUN: Fixture.test_behavior\n", encoding="utf-8")
        return dict(name="Fixture", path="res://tests/test_fixture.gd", report=str(result), log=str(log), exit_code=0)

    def test_resume_rejects_a_different_or_partial_test_filter(self):
        with tempfile.TemporaryDirectory() as folder:
            entry = self.resume_fixture(folder, "behavior")
            with self.assertRaisesRegex(ValueError, "same test filter"):
                resume_entry(entry, "")
            self.assertEqual(resume_entry(entry, "behavior")["passed"], 1)

    def test_resume_recomputes_status_and_counts_from_cases(self):
        with tempfile.TemporaryDirectory() as folder:
            entry = self.resume_fixture(folder)
            entry.update(status="failed", passed=100, failed=999)
            checked = resume_entry(entry, "")
            self.assertEqual((checked["status"], checked["passed"], checked["failed"]), ("passed", 1, 0))

    def test_resume_rechecks_errors_before_runner_start(self):
        with tempfile.TemporaryDirectory() as folder:
            entry = self.resume_fixture(folder, prefix="SCRIPT ERROR: broken autoload\n")
            with self.assertRaisesRegex(ValueError, "before test execution"):
                resume_entry(entry, "")

    def test_declared_replay_budget_and_explicit_override(self):
        profile = {"suite_timeout_seconds": {"LongReplay": 600}}
        self.assertEqual(timeout_for_suite("Ordinary", profile), 180)
        self.assertEqual(timeout_for_suite("LongReplay", profile), 600)
        self.assertEqual(timeout_for_suite("LongReplay", profile, 10), 10)

    def test_invalid_budget_cannot_disable_timeout(self):
        for value in (0, -1, True, "600", float("nan"), float("inf")):
            with self.assertRaises(ValueError):
                timeout_for_suite("Broken", {"suite_timeout_seconds": {"Broken": value}})

    def test_autoload_error_before_runner_is_not_a_passing_application(self):
        self.assertTrue(startup_script_error("SCRIPT ERROR: Parse Error: broken autoload\nRUN: Fixture.test_ok\nPASS: Fixture.test_ok"))
        self.assertTrue(startup_script_error("SCRIPT ERROR: Parse Error: broken autoload\n"))
        # Runtime error fixtures are judged by the runner's per-case result.
        self.assertEqual(startup_script_error("RUN: ErrorGate.test_catches_error\nSCRIPT ERROR: deliberate negative fixture\n"), "")

    def report(self, status="passed"):
        counts = {"passed": 0, "failed": 0, "skipped": 0}
        counts[status] = 1
        return dict(schema_version=1, total=1, **counts,
                    exit_code={"passed": 0, "failed": 1, "skipped": 2}[status],
                    cases=[dict(suite="Fixture", test="test_behavior", status=status)])

    def test_exit_zero_without_results_is_not_success(self):
        self.assertTrue(validate_report({}, 0))

    def test_malformed_json_shapes_are_not_success(self):
        self.assertTrue(validate_report([], 0))
        report = self.report()
        report["cases"] = [None]
        self.assertTrue(validate_report(report, 0))

    def test_stale_or_partial_report_disagrees_with_exit(self):
        self.assertTrue(validate_report(self.report(), 1))

    def test_inflated_counts_rejected(self):
        report = self.report()
        report["passed"] = 4
        self.assertTrue(validate_report(report, 0))

    def test_duplicate_results_cannot_inflate_coverage(self):
        report = self.report()
        report["cases"] *= 2
        report.update(total=2, passed=2)
        self.assertTrue(validate_report(report, 0))

    def test_all_skipped_is_not_success(self):
        self.assertTrue(validate_report(self.report("skipped"), 0))
        self.assertEqual(validate_report(self.report("skipped"), 2), "")

    def test_consistent_pass_and_failure_evidence(self):
        self.assertEqual(validate_report(self.report(), 0), "")
        self.assertEqual(validate_report(self.report("failed"), 1), "")

    def test_failed_report_replace_preserves_previous_complete_evidence(self):
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary) / "report.json"
            write_json(target, {"previous": True})
            with patch.object(Path, "replace", side_effect=OSError("disk failure")):
                with self.assertRaises(OSError):
                    write_json(target, {"partial": True})
            self.assertEqual(json.loads(target.read_text()), {"previous": True})

    def test_cleanup_is_scoped_to_the_created_invocation_directory(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            suite = root / "suite"
            data = suite / "userdata"
            data.mkdir(parents=True)
            (data / "fixture.txt").write_text("temporary fixture")
            (suite / "result.json").write_text("retained evidence")
            with self.assertRaises(ValueError):
                release_created_userdata(suite, root)
            release_created_userdata(suite, data)
            self.assertFalse(data.exists())
            self.assertTrue((suite / "result.json").exists())

    def test_disk_guard_prevents_startup_without_creating_a_suite_cache(self):
        with tempfile.TemporaryDirectory() as temporary:
            suite = Path(temporary) / "suite"
            with patch("scripts.tools.run_test_matrix.shutil.disk_usage") as usage, patch("scripts.tools.run_test_matrix.subprocess.Popen") as process:
                usage.return_value.free = 0
                code, _, error, _ = invoke(Path("godot"), [], suite, 10)
            self.assertEqual(code, 125)
            self.assertIn("2 GiB", error)
            self.assertFalse(suite.exists())
            process.assert_not_called()


if __name__ == "__main__":
    unittest.main()
