import unittest
from scripts.tools.validate_web_test_report import assess


class WebReportContract(unittest.TestCase):
    def report(self, outcomes):
        specs = []
        stats = dict(expected=0, unexpected=0, flaky=0, skipped=0)
        for index, (status, scope) in enumerate(outcomes):
            raw = "expected" if status == "passed" else ("skipped" if status == "skipped" else "unexpected")
            stats[raw] += 1
            specs.append(dict(id=str(index), title=f"test {index}", tests=[dict(
                projectName="browser", status=raw, expectedStatus="passed",
                results=[dict(status=status)], annotations=[dict(type="not-applicable", description="desktop-only")] if scope else []
            )]))
        return dict(errors=[], suites=[dict(specs=specs)], stats=stats)

    def test_missing_prerequisite_is_incomplete_even_with_passing_tests(self):
        result = assess(self.report([("passed", False), ("skipped", False)]))
        self.assertEqual(result["status"], "incomplete")
        self.assertEqual(result["skipped"], 1)

    def test_explicit_platform_scope_does_not_inflate_pass_count(self):
        result = assess(self.report([("passed", False), ("skipped", True)]))
        self.assertEqual((result["status"], result["passed"], result["not_applicable"]), ("passed", 1, 1))

    def test_empty_or_all_out_of_scope_is_not_success(self):
        with self.assertRaises(ValueError):
            assess(self.report([]))
        self.assertEqual(assess(self.report([("skipped", True)]))["status"], "incomplete")

    def test_failure_cannot_hide_behind_scope_annotation(self):
        self.assertEqual(assess(self.report([("failed", True)]))["status"], "failed")

    def test_duplicate_identity_and_inflated_summary_rejected(self):
        report = self.report([("passed", False)])
        report["suites"] *= 2
        with self.assertRaises(ValueError):
            assess(report)
        report = self.report([("passed", False)])
        report["stats"]["expected"] = 2
        with self.assertRaises(ValueError):
            assess(report)

    def test_expected_failure_is_not_regression_success(self):
        report = self.report([("passed", False)])
        report["suites"][0]["specs"][0]["tests"][0].update(expectedStatus="failed", results=[dict(status="failed")])
        self.assertEqual(assess(report)["status"], "failed")


if __name__ == "__main__":
    unittest.main()
