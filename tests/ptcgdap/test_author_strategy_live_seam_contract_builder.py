from __future__ import annotations

import hashlib
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tools.ptcgdap.build_author_strategy_live_seam_contract import build_artifacts


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"


class AuthorStrategyLiveSeamContractBuilderTests(unittest.TestCase):
    def test_builder_reproduces_all_artifacts(self) -> None:
        artifacts = build_artifacts()
        self.assertEqual(
            {
                "author_strategy_live_seam.schema.json",
                "author_strategy_live_seam_profile.json",
                "author_strategy_live_seam_conformance_vectors.json",
                "author_strategy_live_seam_bundle.json",
            },
            set(artifacts),
        )
        for name, value in artifacts.items():
            self.assertEqual(value, load_json_strict(CONTRACT_ROOT / name), name)

    def test_bundle_binds_every_document_and_parent(self) -> None:
        bundle = load_json_strict(CONTRACT_ROOT / "author_strategy_live_seam_bundle.json")
        self.assertEqual("ptcgdap-author-strategy-live-seam-as-wp5-v1", bundle["bundle_id"])
        self.assertEqual(
            "4BD207E9F9200E5AF9E2206A13EAF506382B6BA42BDEE3F0FEB5CA872885DBB9",
            bundle["parent_author_match_host_bundle_canonical_sha256"],
        )
        for entry in bundle["artifacts"]:
            value = load_json_strict(ROOT / entry["path"])
            actual = hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper()
            self.assertEqual(entry["canonical_sha256"], actual)

    def test_device_timing_is_an_as_wp6_handoff_not_an_as_wp5_claim(self) -> None:
        profile = load_json_strict(CONTRACT_ROOT / "author_strategy_live_seam_profile.json")
        self.assertNotIn("max_decision_msec", profile["resource_limits"])
        self.assertEqual(
            {
                "gate_owner": "AS-WP6",
                "enforced_in_as_wp5": False,
                "candidate_max_decision_msec": 250,
            },
            profile["device_budget_handoff"],
        )


if __name__ == "__main__":
    unittest.main()
