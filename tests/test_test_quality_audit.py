import unittest
from scripts.tools.audit_test_quality import inspect_source


class TestQualityAudit(unittest.TestCase):
    def test_empty_success_is_rejected(self):
        self.assertEqual(inspect_source('func test_empty() -> String:\n\t# placeholder\n\treturn ""\n')[0]["kind"], "unconditional-pass")

    def test_environment_guard_must_be_explicit_skip(self):
        body = 'func test_live() -> String:\n\tif OS.get_environment("FIXTURE") == "":\n\t\treturn ""\n\treturn assert_true(exercise())\n'
        self.assertEqual(inspect_source(body)[0]["kind"], "silent-prerequisite-pass")
        self.assertEqual(inspect_source(body.replace('return ""', 'return "SKIP: fixture required"')), [])

    def test_source_contract_is_reviewed_not_deleted(self):
        finding = inspect_source('func test_boundary() -> String:\n\tvar source = FileAccess.get_file_as_string("res://owner.gd")\n\treturn assert_false("private_service" in source)\n')[0]
        self.assertEqual(finding["severity"], "review")

    def test_behavior_assertions_are_not_placeholders(self):
        self.assertEqual(inspect_source('func test_behavior() -> String:\n\tvar result = owner.execute()\n\tif result != expected:\n\t\treturn "wrong result"\n\treturn ""\n'), [])


if __name__ == "__main__":
    unittest.main()
