from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import sys
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "contracts/ptcgdap/policy_executor_conformance_v1.schema.json"
PROFILE = ROOT / "contracts/ptcgdap/policy_executor_conformance_v1_profile.json"
VECTORS = ROOT / "contracts/ptcgdap/policy_executor_conformance_v1_vectors.json"
BUNDLE = ROOT / "contracts/ptcgdap/policy_executor_conformance_v1_bundle.json"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class PolicyExecutorConformanceV1Tests(unittest.TestCase):
    def test_contract_runtime_builder_and_godot_suite_exist(self) -> None:
        paths = (
            SCHEMA,
            PROFILE,
            VECTORS,
            BUNDLE,
            ROOT / "scripts/ai/ptcgdap/policy_executor_conformance.py",
            ROOT / "scripts/ai/ptcgdap/runtime/local/PolicyExecutorConformance.gd",
            ROOT / "tests/ptcgdap/godot/test_policy_executor_conformance.gd",
            ROOT / "tools/ptcgdap/build_policy_executor_conformance_v1.py",
            ROOT / "tools/ptcgdap/run_policy_executor_conformance.py",
        )
        self.assertEqual([], [path.relative_to(ROOT).as_posix() for path in paths if not path.is_file()])

    def test_schema_profile_vectors_and_bundle_are_exact(self) -> None:
        schema = load_json_strict(SCHEMA)
        profile = load_json_strict(PROFILE)
        vectors = load_json_strict(VECTORS)
        Draft202012Validator.check_schema(schema)
        validator = Draft202012Validator(schema)
        self.assertEqual([], list(validator.iter_errors(profile)))
        self.assertEqual([], list(validator.iter_errors(vectors)))
        self.assertEqual(8, len(vectors["cases"]))
        self.assertEqual(
            {"order", "float", "default", "unknown_node", "fault", "tie_break", "option_reorder", "unknown_operation"},
            set(profile["required_dimensions"]),
        )
        self.assertEqual("none", profile["model_contract"]["learned_model"])
        self.assertEqual(0, profile["model_contract"]["required_operator_case_count"])
        self.assertEqual(0, profile["model_contract"]["skipped_operator_case_count"])
        bundle = load_json_strict(BUNDLE)
        self.assertEqual({"schema", "profile", "vectors"}, {row["id"] for row in bundle["artifacts"]})
        for row in bundle["artifacts"]:
            value = load_json_strict(ROOT / row["path"])
            self.assertEqual(row["canonical_sha256"], sha(canonical_json_v1_bytes(value)))

    def test_python_runner_matches_parent_and_all_shared_probes(self) -> None:
        from scripts.ai.ptcgdap.policy_executor_conformance import PolicyExecutorConformance

        report = PolicyExecutorConformance.load_default().run_all()
        self.assertTrue(report["accepted"], report)
        self.assertEqual(28, report["parent_vector_case_count"])
        self.assertEqual(0, report["parent_vector_mismatch_count"])
        self.assertEqual(8, report["probe_case_count"])
        self.assertEqual(0, report["probe_mismatch_count"])
        self.assertEqual(0, report["skipped_case_count"])
        self.assertEqual("none", report["model"]["learned_model"])
        self.assertEqual(0, report["model"]["operator_case_count"])
        self.assertEqual(0, report["model"]["operator_skip_count"])
        self.assertTrue(all(row["matched"] for row in report["cases"]))

    def test_builder_is_reproducible_and_gdscript_has_no_remote_escape(self) -> None:
        result = subprocess.run(
            [sys.executable, "tools/ptcgdap/build_policy_executor_conformance_v1.py", "--check"],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        gdscript = (ROOT / "scripts/ai/ptcgdap/runtime/local/PolicyExecutorConformance.gd").read_text(encoding="utf-8")
        for forbidden in ("HTTPClient", "HTTPRequest", "StreamPeerTCP", "OS.execute("):
            self.assertNotIn(forbidden, gdscript)


if __name__ == "__main__":
    unittest.main()
