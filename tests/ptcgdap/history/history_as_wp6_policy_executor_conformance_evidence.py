from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import sys
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "artifacts/ptcgdap/as_wp6_policy_executor_conformance"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class AsWp6PolicyExecutorConformanceEvidenceTests(unittest.TestCase):
    def test_evidence_exists_and_builder_is_reproducible(self) -> None:
        for name in ("README.md", "known_gaps.md", "test_results.json", "python_report.json", "evidence_summary.json", "manifest.json"):
            self.assertTrue((EVIDENCE / name).is_file(), name)
        result = subprocess.run(
            [sys.executable, "tools/ptcgdap/build_as_wp6_policy_executor_conformance_evidence.py", "--check"],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_summary_keeps_scope_and_results_exact(self) -> None:
        summary = load_json_strict(EVIDENCE / "evidence_summary.json")
        self.assertEqual("D052", summary["decision_id"])
        self.assertEqual(28, summary["python"]["parent_cases"])
        self.assertEqual(8, summary["python"]["probe_cases"])
        self.assertEqual(0, summary["python"]["mismatches"])
        self.assertEqual(0, summary["python"]["skips"])
        self.assertEqual(1, summary["godot"]["focused_passed"])
        self.assertEqual(0, summary["godot"]["mismatches"])
        self.assertEqual({"learned_model": "none", "backend": "none", "operator_case_count": 0, "operator_skip_count": 0}, summary["model"])
        self.assertTrue(summary["claims"]["p6_02_declared_no_model_subset"])
        for key in ("p6_03_local_policy_executor", "model_backed_lane", "execution_authority", "production_ready", "device_accepted", "a2_claimed", "a5_claimed", "android_claimed"):
            self.assertFalse(summary["claims"][key], key)

    def test_manifest_binds_every_file(self) -> None:
        manifest = load_json_strict(EVIDENCE / "manifest.json")
        self.assertEqual("D052", manifest["decision_id"])
        for row in manifest["files"]:
            path = ROOT / row["path"]
            self.assertEqual(row["bytes"], path.stat().st_size, row["path"])
            self.assertEqual(row["raw_sha256"], sha(path.read_bytes()), row["path"])
            if row.get("canonical_sha256") is not None:
                self.assertEqual(row["canonical_sha256"], sha(canonical_json_v1_bytes(load_json_strict(path))), row["path"])


if __name__ == "__main__":
    unittest.main()
