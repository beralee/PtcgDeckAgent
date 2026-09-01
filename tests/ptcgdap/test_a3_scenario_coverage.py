from __future__ import annotations

import hashlib
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.a3_scenario_coverage import (
    A3ScenarioCoverageError,
    build_scenario_coverage,
    load_capability_profile,
)
from scripts.ai.ptcgdap.cabt_tree_hash import jcs_canonical_json_bytes
from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
PROFILE_PATH = ROOT / "contracts/ptcgdap/a3_five_deck_capability_profile_v2.json"


def seal(value: dict) -> dict:
    result = dict(value)
    result["evidence_sha256"] = hashlib.sha256(
        jcs_canonical_json_bytes(value)
    ).hexdigest().upper()
    return result


class A3ScenarioCoverageTests(unittest.TestCase):
    def test_empty_evidence_is_an_exact_blocked_gap_inventory(self) -> None:
        scope = {"scope_sha256": "A" * 64}
        profile = load_capability_profile(PROFILE_PATH)
        report = build_scenario_coverage(scope, profile)
        self.assertEqual(report["required_capability_count"], len(profile["capabilities"]))
        self.assertEqual(report["aligned_capability_count"], 0)
        self.assertTrue(all(item["status"] == "blocked" for item in report["capabilities"]))
        self.assertTrue(all(item["status"] == "blocked" for item in report["multi_window_chains"]))

    def test_synthetic_receipt_is_recorded_but_cannot_close_official_coverage(self) -> None:
        scope = {"scope_sha256": "A" * 64}
        profile = load_capability_profile(PROFILE_PATH)
        receipt = {
            "document_type": "ptcgdap_a3_micro_scenario_receipt_v2",
            "scope_sha256": scope["scope_sha256"],
            "capability_id": profile["capabilities"][0]["capability_id"],
            "scenario_kind": "positive",
            "status": "aligned",
            "construction_authority": "godot-synthetic-only",
            "scenario_id": "synthetic",
            "public_projection_status": "reviewed",
            "private_evidence_status": "isolated",
        }
        report = build_scenario_coverage(scope, profile, scenario_receipts=[seal(receipt)])
        first = report["capabilities"][0]
        self.assertEqual(first["scenario_kinds"], ["positive"])
        self.assertEqual(first["construction_authorities"], ["godot-synthetic-only"])
        self.assertEqual(first["status"], "blocked")

    def test_generated_gap_inventory_is_exact(self) -> None:
        scope = load_json_strict(ROOT / "data/ptcgdap/a3/five_deck_scope_v2.json")
        generated = load_json_strict(ROOT / "evidence/ptcgdap/a3/scenario_coverage_v2.json")
        self.assertEqual(
            generated,
            build_scenario_coverage(scope, load_capability_profile(PROFILE_PATH)),
        )


if __name__ == "__main__":
    unittest.main()
