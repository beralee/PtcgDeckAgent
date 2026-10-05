"""Exercise failure paths across the actual Godot process boundary."""
import os
from pathlib import Path
import unittest
import uuid

from scripts.tools.run_test_matrix import ROOT, invoke, validate_report

GODOT = Path(os.environ.get("GODOT_EXE", r"D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe"))


@unittest.skipUnless(GODOT.is_file(), "Godot is required for the process contract")
class RunnerProcessContract(unittest.TestCase):
    def run_fixture(self, fixture, timeout=40):
        output = ROOT / ".godot_test_user" / "process-contract" / uuid.uuid4().hex
        return invoke(GODOT, ["--suite-script=res://tests/fixtures/" + fixture], output, timeout)

    def test_runtime_error_is_failed_even_if_return_value_looks_empty(self):
        code, report, error, _ = self.run_fixture("suite_runner_runtime_error_fixture.gd")
        self.assertEqual(error, "")
        self.assertEqual(code, 1)
        self.assertEqual(validate_report(report, code), "")
        self.assertEqual(report["failed"], 1)
        self.assertIn("SCRIPT ERROR", report["cases"][0]["message"])

    def test_missing_suite_is_failed_not_zero_tests_passed(self):
        code, report, error, _ = self.run_fixture("does_not_exist.gd")
        self.assertEqual(error, "")
        self.assertEqual(code, 1)
        self.assertEqual(report["failed"], 1)
        self.assertEqual(validate_report(report, code), "")

    def test_timeout_never_becomes_a_success(self):
        code, report, error, _ = self.run_fixture("suite_runner_timeout_fixture.gd", timeout=8)
        self.assertEqual(code, 124)
        self.assertIn("exceeded", error)
        self.assertTrue(validate_report(report, code))


if __name__ == "__main__":
    unittest.main()
