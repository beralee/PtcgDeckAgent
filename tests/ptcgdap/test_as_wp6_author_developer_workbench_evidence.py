from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import sys
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "artifacts/ptcgdap/as_wp6_author_developer_workbench"
SUMMARY = EVIDENCE / "evidence_summary.json"
MANIFEST = EVIDENCE / "manifest.json"
BUILDER = ROOT / "tools/ptcgdap/build_as_wp6_author_developer_workbench_evidence.py"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class AsWp6AuthorDeveloperWorkbenchEvidenceTests(unittest.TestCase):
    def test_evidence_builder_is_reproducible(self) -> None:
        result = subprocess.run(
            [sys.executable, str(BUILDER), "--check"],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_summary_closes_only_the_developer_workflow_subgate(self) -> None:
        summary = load_json_strict(SUMMARY)
        self.assertEqual("D058", summary["decision_id"])
        self.assertTrue(summary["claims"]["developer_workbench"])
        self.assertTrue(summary["claims"]["public_window_simulation"])
        self.assertEqual([1], summary["workflow"]["selected_indexes"])
        self.assertEqual(971, summary["validation"]["python_full_passed"])
        for key in (
            "engine_execution_by_simulator",
            "arbitrary_package_rules_integration",
            "execution_trusted",
            "production_ready",
            "cabt_exportable",
            "official_w0_w7",
            "a5_claimed",
            "android_claimed",
            "os_network_isolation_proven",
        ):
            self.assertFalse(summary["claims"][key], key)

    def test_manifest_binds_tool_guide_tests_package_and_governance(self) -> None:
        manifest = load_json_strict(MANIFEST)
        paths = [row["path"] for row in manifest["files"]]
        self.assertEqual(len(paths), len(set(paths)))
        for required in (
            "tools/ptcgdap/author_strategy_developer.py",
            "docs/ptcgdap/10-author-strategy-developer-guide.md",
            "tests/ptcgdap/test_author_strategy_developer_tool.py",
            "data/ptcgdap/author_strategy_packages/ptcgdap-author-strategy-release-candidate.ptcgai",
            "docs/ptcgdap/STATUS.md",
        ):
            self.assertIn(required, paths)
        for row in manifest["files"]:
            path = ROOT / row["path"]
            raw = path.read_bytes()
            self.assertEqual(len(raw), row["bytes"], row["path"])
            self.assertEqual(sha(raw), row["raw_sha256"], row["path"])
            if row.get("canonical_sha256") is not None:
                self.assertEqual(
                    sha(canonical_json_v1_bytes(load_json_strict(path))),
                    row["canonical_sha256"],
                    row["path"],
                )

    def test_normalized_reports_preserve_the_public_only_happy_path(self) -> None:
        package = load_json_strict(EVIDENCE / "validate_report.json")
        simulation = load_json_strict(EVIDENCE / "simulation_report.json")
        self.assertEqual("test_fixture_only", package["signature_scope"])
        self.assertFalse(package["execution_trusted"])
        self.assertEqual(
            "marnie.morgrem.evolve",
            simulation["adapter"]["matched_rules"][0]["rule_id"],
        )
        self.assertEqual([1], simulation["decision"]["selected_indexes"])
        self.assertFalse(simulation["claims"]["engine_execution"])


if __name__ == "__main__":
    unittest.main()
