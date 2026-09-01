from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import sys
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tests.ptcgdap.dragapult_acceptance_rollback import is_dragapult_acceptance_additive


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "artifacts/ptcgdap/as_wp6_product_signing"
SUMMARY = EVIDENCE / "evidence_summary.json"
MANIFEST = EVIDENCE / "manifest.json"
BUILDER = ROOT / "tools/ptcgdap/build_as_wp6_product_signing_evidence.py"


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class AsWp6ProductSigningEvidenceTests(unittest.TestCase):
    def test_d070_additions_are_excluded_from_older_virtual_rollbacks(self) -> None:
        for path in (
            "tools/ptcgdap/sign_author_strategy_product_release_candidate.py",
            "tools/ptcgdap/build_as_wp6_product_signing_evidence.py",
            "tests/ptcgdap/test_author_strategy_product_release_signing.py",
            "tests/ptcgdap/test_as_wp6_product_signing_evidence.py",
            "artifacts/ptcgdap/as_wp6_product_signing/signing_receipt.json",
        ):
            self.assertTrue(is_dragapult_acceptance_additive(path), path)

    def test_evidence_builder_is_reproducible(self) -> None:
        result = subprocess.run(
            [sys.executable, str(BUILDER), "--check"],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_summary_closes_only_product_trust_and_exact_signing(self) -> None:
        summary = load_json_strict(SUMMARY)
        self.assertEqual("D070", summary["decision_id"])
        self.assertTrue(summary["claims"]["p6_06_product_trust_approved"])
        self.assertTrue(summary["claims"]["exact_product_package_signed"])
        self.assertFalse(summary["claims"]["private_key_in_repository"])
        self.assertEqual(
            "release_package_not_approved",
            summary["authority"]["exact_package_gate_error"],
        )
        self.assertTrue(summary["authority"]["production_trust_ready"])
        self.assertFalse(summary["authority"]["production_ready"])
        self.assertEqual("", summary["authority"]["production_trust_error_code"])
        self.assertEqual(
            "release_prompt_conformance_unapproved",
            summary["authority"]["production_ready_error_code"],
        )
        self.assertFalse(summary["authority"]["player_start_allowed"])
        for claim in (
            "test_fixture_promoted",
            "package_release_approved",
            "official_w0_w7_conformance_approved",
            "device_canary_complete",
            "a5_complete",
            "csp_wp3_unlocked",
            "core_engine_changed",
            "ui_changed",
        ):
            self.assertFalse(summary["claims"][claim], claim)

    def test_manifest_binds_package_receipt_runtime_tests_and_governance(self) -> None:
        manifest = load_json_strict(MANIFEST)
        paths = [row["path"] for row in manifest["files"]]
        self.assertEqual(len(paths), len(set(paths)))
        for required in (
            "artifacts/ptcgdap/as_wp6_product_signing/ptcgdap-marnie-windows-local-0.1.0.ptcgai",
            "artifacts/ptcgdap/as_wp6_product_signing/signing_receipt.json",
            "data/ptcgdap/author_strategy_release_trust_store.json",
            "tools/ptcgdap/sign_author_strategy_product_release_candidate.py",
            "scripts/ai/ptcgdap/packages/AuthorStrategyReleaseGate.gd",
            "docs/ptcgdap/STATUS.md",
        ):
            self.assertIn(required, paths)
        for row in manifest["files"]:
            path = ROOT / row["path"]
            value = path.read_bytes()
            self.assertEqual(row["bytes"], len(value), row["path"])
            self.assertEqual(row["raw_sha256"], _sha(value), row["path"])
            if row.get("canonical_sha256") is not None:
                self.assertEqual(
                    row["canonical_sha256"],
                    _sha(canonical_json_v1_bytes(load_json_strict(path))),
                    row["path"],
                )


if __name__ == "__main__":
    unittest.main()
