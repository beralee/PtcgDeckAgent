from __future__ import annotations

import json
from pathlib import Path
import re
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
WORK = load_json_strict(ROOT / "artifacts/ptcgdap/p5_wp7/work_package.json")
MANIFEST_PATH = ROOT / "artifacts/ptcgdap/p5_wp7/manifest.json"


class P5Wp7BoundaryTests(unittest.TestCase):
    def test_work_package_is_additive_offline_and_parent_anchored(self) -> None:
        self.assertEqual("shadow", WORK["status"])
        self.assertEqual("offline_development_validation_only", WORK["execution_location"])
        self.assertEqual(
            "F4E88E5DB4E480BA8441BE7B3A7C81CE3DB40ED1917EB37BCDCAC1C32B1ABD6C",
            WORK["entry_evidence"]["parent_capability_policy_bundle_canonical_sha256"],
        )
        self.assertEqual(
            "67EBA6348277001692942FD58E8D1B9D50C54F0FFC783D8802BA3CCB45691105",
            WORK["entry_evidence"]["parent_public_base_bundle_canonical_sha256"],
        )
        self.assertEqual("AS-WP0", WORK["next_permitted_work"]["work_package"])
        self.assertFalse(WORK["next_permitted_work"]["status"] == "allowed" and not MANIFEST_PATH.is_file())

    def test_new_implementation_has_no_live_private_or_network_dependency(self) -> None:
        paths = [
            "scripts/ai/ptcgdap/marnie_portable_policy.py",
            "scripts/ai/ptcgdap/public/MarniePortablePolicy.gd",
        ]
        forbidden = re.compile(
            r"AIOpponent|BattleScene|GameState|CardInstance|PokemonSlot|ActionTicket|HTTPClient|HTTPRequest|WebSocket|socket|subprocess|requests|urllib"
        )
        for relative in paths:
            source = (ROOT / relative).read_text(encoding="utf-8")
            self.assertIsNone(forbidden.search(source), relative)

    def test_parent_bundles_source_lock_and_governance_parent_bytes_are_unchanged(self) -> None:
        expected = {
            "contracts/ptcgdap/marnie_capability_policy_bundle.json": "F4E88E5DB4E480BA8441BE7B3A7C81CE3DB40ED1917EB37BCDCAC1C32B1ABD6C",
            "contracts/ptcgdap/marnie_public_base_bundle.json": "67EBA6348277001692942FD58E8D1B9D50C54F0FFC783D8802BA3CCB45691105",
            "docs/ptcgdap/SOURCE_LOCK.json": "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205",
        }
        import hashlib

        for relative, digest in expected.items():
            self.assertEqual(digest, hashlib.sha256(canonical_json_v1_bytes(load_json_strict(ROOT / relative))).hexdigest().upper())
        snapshot = load_json_strict(ROOT / "artifacts/ptcgdap/p5_wp7/parent_snapshot/manifest.json")
        self.assertIn("docs/ptcgdap/06-first-vertical-slice.md", snapshot["rollback_scope"]["restore_exact_paths"])
        self.assertIn("docs/ptcgdap/07-decisions-risks-and-open-questions.md", snapshot["rollback_scope"]["restore_exact_paths"])

    def test_package_artifacts_are_public_audit_not_ticket_or_execution_authority(self) -> None:
        profile = load_json_strict(ROOT / "contracts/ptcgdap/marnie_portable_policy_profile.json")
        audit = load_json_strict(ROOT / "data/ptcgdap/marnie_vertical_slice/marnie_portable_policy_v1.json")
        encoded = json.dumps({"profile": profile, "audit": audit})
        self.assertNotIn('"ticket"', encoded.lower())
        self.assertFalse(profile["authority_contract"]["serialized_results_are_authority"])
        self.assertFalse(profile["authority_contract"]["ticket_or_command_authority"])
        self.assertFalse(profile["authority_contract"]["live_owner"])
        self.assertFalse(audit["authoritative"])
        self.assertFalse(audit["execution_authority"])


if __name__ == "__main__":
    unittest.main()
