from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import sys
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "artifacts/ptcgdap/as_wp6_device_manifest"
SUMMARY = EVIDENCE / "evidence_summary.json"
MANIFEST = EVIDENCE / "manifest.json"
BUILDER = ROOT / "tools/ptcgdap/build_as_wp6_device_manifest_evidence.py"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class AsWp6DeviceManifestEvidenceTests(unittest.TestCase):
    def test_evidence_builder_is_reproducible(self) -> None:
        result = subprocess.run(
            [sys.executable, str(BUILDER), "--check"],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_summary_keeps_p6_04_and_records_d057_profile_approval_without_a5(self) -> None:
        summary = load_json_strict(SUMMARY)
        self.assertEqual("D054", summary["decision_id"])
        self.assertEqual("windows_device_manifest_complete", summary["status"])
        self.assertEqual("windows", summary["device_manifest"]["platform"])
        self.assertEqual("x86_64", summary["device_manifest"]["architecture"])
        self.assertEqual("windows-x86_64", summary["device_manifest"]["abi"])
        self.assertEqual("none", summary["device_manifest"]["model_backend"])
        self.assertTrue(summary["claims"]["p6_04_windows_device_manifest"])
        self.assertTrue(summary["claims"]["device_profile_approved"])
        for key in (
            "production_signature_provisioned", "os_network_isolation",
            "production_ready", "a2_claimed",
            "a5_claimed", "android_claimed",
        ):
            self.assertFalse(summary["claims"][key], key)
        self.assertEqual(6, summary["validation"]["python_passed"])
        self.assertEqual(2, summary["validation"]["godot_passed"])
        self.assertEqual(1, summary["validation"]["parent_exported_terminal_games"])
        self.assertEqual(59, summary["validation"]["parent_policy_successes"])
        self.assertEqual(59, summary["validation"]["parent_engine_commits"])

    def test_manifest_binds_every_evidence_input(self) -> None:
        manifest = load_json_strict(MANIFEST)
        paths = [row["path"] for row in manifest["files"]]
        self.assertEqual(len(paths), len(set(paths)))
        for required in (
            "data/ptcgdap/marnie_windows_device_manifest_v1.json",
            "scripts/ai/ptcgdap/runtime/local/DeviceManifest.gd",
            "artifacts/ptcgdap/as_wp6_local_policy_executor/windows_ui_match_report.json",
            "data/ptcgdap/author_strategy_device_acceptance_profile.json",
        ):
            self.assertIn(required, paths)
        for row in manifest["files"]:
            path = ROOT / row["path"]
            value = path.read_bytes()
            self.assertEqual(row["bytes"], len(value), row["path"])
            self.assertEqual(row["raw_sha256"], sha(value), row["path"])
            if row.get("canonical_sha256") is not None:
                self.assertEqual(
                    row["canonical_sha256"],
                    sha(canonical_json_v1_bytes(load_json_strict(path))),
                    row["path"],
                )


if __name__ == "__main__":
    unittest.main()
