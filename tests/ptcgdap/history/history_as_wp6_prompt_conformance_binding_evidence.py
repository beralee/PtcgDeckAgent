from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import sys
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "artifacts/ptcgdap/as_wp6_prompt_conformance_binding"
SUMMARY = EVIDENCE / "evidence_summary.json"
MANIFEST = EVIDENCE / "manifest.json"
BUILDER = ROOT / "tools/ptcgdap/build_as_wp6_prompt_conformance_binding_evidence.py"


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class AsWp6PromptConformanceBindingEvidenceTests(unittest.TestCase):
    def test_evidence_builder_is_reproducible(self) -> None:
        result = subprocess.run(
            [sys.executable, str(BUILDER), "--check"],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_summary_closes_only_the_binding_gate(self) -> None:
        summary = load_json_strict(SUMMARY)
        self.assertEqual("D069", summary["decision_id"])
        self.assertTrue(summary["claims"]["p6_39_binding_gate_closed"])
        self.assertFalse(summary["authority"]["bare_prompt_coverage_authorizes_canary"])
        self.assertFalse(summary["authority"]["bare_prompt_coverage_authorizes_release"])
        self.assertEqual(0, summary["authority"]["approved_prompt_conformance_count"])
        for claim in (
            "official_w0_w7_conformance_approved",
            "production_signing_complete",
            "device_canary_complete",
            "a5_complete",
            "csp_wp3_unlocked",
            "core_engine_changed",
            "ui_changed",
        ):
            self.assertFalse(summary["claims"][claim], claim)

    def test_manifest_binds_contract_runtime_tests_and_governance(self) -> None:
        manifest = load_json_strict(MANIFEST)
        paths = [row["path"] for row in manifest["files"]]
        self.assertEqual(len(paths), len(set(paths)))
        for required in (
            "data/ptcgdap/author_strategy_prompt_conformance_approvals.json",
            "scripts/ai/ptcgdap/author_strategy_release.py",
            "scripts/ai/ptcgdap/packages/AuthorStrategyReleaseGate.gd",
            "docs/ptcgdap/STATUS.md",
            "docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md",
        ):
            self.assertIn(required, paths)
        for row in manifest["files"]:
            value = (ROOT / row["path"]).read_bytes()
            self.assertEqual(row["bytes"], len(value), row["path"])
            self.assertEqual(row["raw_sha256"], _sha(value), row["path"])
            if row.get("canonical_sha256") is not None:
                self.assertEqual(
                    row["canonical_sha256"],
                    _sha(canonical_json_v1_bytes(load_json_strict(ROOT / row["path"]))),
                    row["path"],
                )


if __name__ == "__main__":
    unittest.main()
