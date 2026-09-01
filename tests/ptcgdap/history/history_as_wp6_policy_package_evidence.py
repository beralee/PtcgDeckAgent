from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import sys
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "artifacts/ptcgdap/as_wp6_policy_package_v1"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class AsWp6PolicyPackageEvidenceTests(unittest.TestCase):
    def test_evidence_documents_exist_and_builder_is_reproducible(self) -> None:
        required = (
            EVIDENCE / "README.md",
            EVIDENCE / "known_gaps.md",
            EVIDENCE / "evidence_summary.json",
            EVIDENCE / "windows_export_manifest.json",
            EVIDENCE / "windows_export_match.json",
            EVIDENCE / "windows_export_inventory_policy_paths.json",
            EVIDENCE / "test_results.json",
            EVIDENCE / "manifest.json",
        )
        self.assertEqual([], [path.name for path in required if not path.is_file()])
        result = subprocess.run(
            [sys.executable, "tools/ptcgdap/build_as_wp6_policy_package_evidence.py", "--check"],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_summary_records_exact_no_model_and_real_rules_execution(self) -> None:
        summary = load_json_strict(EVIDENCE / "evidence_summary.json")
        self.assertEqual("D051", summary["decision_id"])
        self.assertEqual("policy_package_v1", summary["policy_package"]["document_type"])
        self.assertEqual("3243ABD7937B3F53D8E5D7A887FC90BFBDF9A4D94E4030A3A9BE194C82370FFC", summary["policy_package"]["canonical_sha256"])
        self.assertEqual("none", summary["policy_package"]["learned_model"])
        self.assertEqual("none", summary["policy_package"]["model_backend"])
        self.assertEqual("unused_non_model_payload", summary["policy_package"]["weights_status"])
        editor = summary["editor_rules_e2e"]
        self.assertTrue(editor["is_clean"])
        self.assertEqual(10, editor["games"])
        self.assertEqual(editor["policy_calls"], editor["policy_successes"])
        self.assertEqual(0, editor["policy_errors"] + editor["invalid_outputs"] + editor["fallbacks"])
        exported = summary["exported_windows_rules_e2e"]
        self.assertTrue(exported["is_clean"])
        self.assertEqual(3, exported["games"])
        self.assertEqual(exported["policy_calls"], exported["policy_successes"])
        self.assertEqual(0, exported["policy_errors"] + exported["invalid_outputs"] + exported["same_window_fallbacks"] + exported["classic_fallbacks"] + exported["engine_rejections"])
        self.assertGreater(exported["engine_commits"], 0)
        self.assertEqual([], exported["observed_child_process_ids"])
        self.assertEqual([], exported["observed_network_endpoints"])

    def test_export_inventory_contains_every_runtime_policy_package_resource(self) -> None:
        inventory = load_json_strict(EVIDENCE / "windows_export_inventory_policy_paths.json")
        paths = {entry["path"] for entry in inventory["members"]}
        self.assertEqual(
            {
                "contracts/ptcgdap/policy_package_v1.schema.json",
                "contracts/ptcgdap/policy_package_v1_profile.json",
                "contracts/ptcgdap/policy_package_v1_bundle.json",
                "data/ptcgdap/marnie_windows_policy_package_v1.json",
                "scripts/ai/ptcgdap/runtime/local/PolicyPackageManifest.gd.remap",
                "scripts/ai/ptcgdap/runtime/local/PolicyPackageManifest.gdc",
            },
            paths,
        )

    def test_manifest_hashes_every_persistent_evidence_member(self) -> None:
        manifest = load_json_strict(EVIDENCE / "manifest.json")
        self.assertEqual("as_wp6_policy_package_v1_evidence_manifest_v1", manifest["document_type"])
        for entry in manifest["files"]:
            path = ROOT / entry["path"]
            self.assertEqual(entry["bytes"], path.stat().st_size)
            self.assertEqual(entry["raw_sha256"], sha(path.read_bytes()))
            if entry.get("canonical_sha256") is not None:
                self.assertEqual(entry["canonical_sha256"], sha(canonical_json_v1_bytes(load_json_strict(path))))

    def test_known_gaps_do_not_overstate_release_or_device_scope(self) -> None:
        text = (EVIDENCE / "known_gaps.md").read_text(encoding="utf-8")
        for phrase in (
            "test-fixture signed",
            "product-approved device profile",
            "OS-level network isolation",
            "A5",
            "Android",
            "official CABT",
        ):
            self.assertIn(phrase, text)


if __name__ == "__main__":
    unittest.main()
