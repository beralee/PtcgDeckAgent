import json
from pathlib import Path
import tempfile
import unittest

from scripts.tools.merge_test_reports import merge


class MergeEvidenceContract(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.catalog = [dict(name="Example", path="res://tests/test_example.gd")]

    def attempt(self, status, name="attempt", prefix="", filtered=False):
        case = dict(suite="Example", path=self.catalog[0]["path"], test="test_behavior", status=status)
        counts = {key: int(status == key) for key in ("passed", "failed", "skipped")}
        code = {"passed": 0, "failed": 1, "skipped": 2}[status]
        data = dict(schema_version=1, cases=[case], total=1, exit_code=code, **counts,
                    filters={"test-filter": "behavior"} if filtered else {})
        result, log = self.root / (name + ".json"), self.root / (name + ".log")
        result.write_text(json.dumps(data), encoding="utf-8")
        log.write_text(prefix + "RUN: Example.test_behavior\n", encoding="utf-8")
        entry = dict(**self.catalog[0], status=status, exit_code=code, report=str(result), log=str(log), **counts, total=1)
        return dict(godot="godot.exe", suites=[entry])

    def test_full_recheck_replaces_failure_and_retains_attempts(self):
        result = merge(self.catalog, [self.attempt("failed", "red"), self.attempt("passed", "green")])
        self.assertEqual(result["status"], "passed")
        self.assertEqual(result["totals"]["total"], 1)
        self.assertEqual(len(result["attempts"][self.catalog[0]["path"]]), 2)

    def test_missing_and_skipped_coverage_is_incomplete(self):
        self.assertEqual(merge(self.catalog, [self.attempt("skipped")])["status"], "incomplete")
        self.assertEqual(merge(self.catalog + [dict(name="Missing", path="missing.gd")], [self.attempt("passed")])["status"], "incomplete")

    def test_startup_error_invalidates_reported_pass(self):
        result = merge(self.catalog, [self.attempt("passed", prefix="SCRIPT ERROR: broken autoload\n")])
        self.assertEqual(result["status"], "failed")

    def test_filtered_recheck_cannot_hide_other_suite_failures(self):
        with self.assertRaisesRegex(ValueError, "filtered test run"):
            merge(self.catalog, [self.attempt("passed", filtered=True)])

    def test_engine_versions_cannot_be_mixed(self):
        a, b = self.attempt("passed", "a"), self.attempt("passed", "b")
        b["godot"] = "different-godot.exe"
        with self.assertRaisesRegex(ValueError, "one Godot"):
            merge(self.catalog, [a, b])


if __name__ == "__main__":
    unittest.main()
