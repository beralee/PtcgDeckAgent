from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import sys
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE_ROOT = ROOT / "artifacts/ptcgdap/dragapult_python_e2e"
SUMMARY_PATH = EVIDENCE_ROOT / "evidence_summary.json"
MANIFEST_PATH = EVIDENCE_ROOT / "manifest.json"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class DragapultPythonAcceptanceEvidenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.summary = load_json_strict(SUMMARY_PATH)
        cls.manifest = load_json_strict(MANIFEST_PATH)

    def test_evidence_builder_is_reproducible(self) -> None:
        result = subprocess.run(
            [sys.executable, "tools/ptcgdap/build_dragapult_python_acceptance_evidence.py", "--check"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_identity_and_e2e_are_exact_without_overclaim(self) -> None:
        identity = self.summary["identity"]
        e2e = self.summary["end_to_end"]
        alignment = self.summary["alignment"]
        self.assertEqual("godot_local_card_uid_v1", identity["card_id_domain"])
        self.assertFalse(identity["official_card_id_domain_merged"])
        self.assertEqual(800018499, identity["dragapult_deck_id"])
        self.assertEqual(60, identity["dragapult_card_count"])
        self.assertEqual(24, identity["dragapult_unique_card_count"])
        self.assertFalse(identity["cabt_exportable"])
        self.assertEqual(list(range(83200, 83210)), e2e["seeds"])
        self.assertEqual((10, 2, 8, 0), (e2e["games"], e2e["wins"], e2e["losses"], e2e["draws"]))
        self.assertEqual(1218, e2e["python_calls"])
        self.assertEqual(1218, e2e["python_successes"])
        for key in ("invalid_outputs", "python_errors", "python_timeouts", "fallbacks"):
            self.assertEqual(0, e2e[key], key)
        self.assertFalse(alignment["player_runtime_python_dependency"])
        self.assertFalse(alignment["player_live_allowed"])
        self.assertFalse(alignment["python_gdscript_same_policy_conformance"])
        self.assertFalse(alignment["official_cabt_engine_parity"])
        self.assertFalse(alignment["android_validated"])

    def test_manifest_binds_evidence_docs_implementation_and_logs(self) -> None:
        for group in ("evidence_files", "documentation_hashes", "implementation_hashes", "validation_hashes"):
            for entry in self.manifest[group]:
                path = ROOT / entry["path"]
                self.assertTrue(path.is_file(), entry["path"])
                value = path.read_bytes()
                self.assertEqual(entry["bytes"], len(value), entry["path"])
                self.assertEqual(entry["raw_sha256"], sha(value), entry["path"])
                if "canonical_sha256" in entry:
                    self.assertEqual(entry["canonical_sha256"], sha(canonical_json_v1_bytes(load_json_strict(path))), entry["path"])

    def test_governance_gaps_and_rollback_remain_closed(self) -> None:
        decisions = (ROOT / "docs/ptcgdap/07-decisions-risks-and-open-questions.md").read_text(encoding="utf-8")
        checklist = (ROOT / "docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md").read_text(encoding="utf-8")
        gaps = (EVIDENCE_ROOT / "known_gaps.md").read_text(encoding="utf-8")
        rollback = (EVIDENCE_ROOT / "rollback_report.md").read_text(encoding="utf-8")
        self.assertIn("D042 — 本地作者策略的 Card ID 统一指游戏内稳定唯一 UID", decisions)
        for gate in range(1, 7):
            self.assertIn(f"[x] **REQUIRED DRA-0{gate}**", checklist)
        for fragment in (
            "玩家作者策略 live",
            "python_gdscript_same_policy_conformance=false",
            "official CABT engine parity",
            "Android",
            "2 胜 8 负",
        ):
            self.assertIn(fragment, gaps)
        self.assertIn("13 份 exact 父字节", rollback)
        self.assertFalse(self.manifest["alignment"]["player_live"])


if __name__ == "__main__":
    unittest.main()
