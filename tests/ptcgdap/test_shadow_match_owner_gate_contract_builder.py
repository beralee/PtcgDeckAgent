from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import sys
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
BUNDLE = CONTRACT_ROOT / "shadow_match_owner_gate_bundle.json"
PROFILE_ID = "ptcgdap-shadow-match-owner-gate-p3-wp6-v1"
PARENT_BROKER = "D19EC7B9B77370312C82E0572DFB016B75E3FE9F438B6C1EFFD50E0AB43C551E"
EXPECTED = {
    "schema": "contracts/ptcgdap/shadow_match_owner_gate.schema.json",
    "profile": "contracts/ptcgdap/shadow_match_owner_gate_profile.json",
    "vectors": "contracts/ptcgdap/shadow_match_owner_gate_conformance_vectors.json",
}


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class ShadowMatchOwnerGateContractBuilderTests(unittest.TestCase):
    def test_builder_is_deterministic_and_bundle_is_exact(self) -> None:
        subprocess.run(
            [sys.executable, "tools/ptcgdap/build_shadow_match_owner_gate_contract.py", "--check"],
            cwd=ROOT,
            check=True,
        )
        bundle = load_json_strict(BUNDLE)
        self.assertEqual(bundle["contract_id"], PROFILE_ID)
        self.assertEqual(bundle["parent_prompt_broker_bundle_canonical_sha256"], PARENT_BROKER)
        entries = bundle["artifacts"]
        self.assertEqual(len(entries), 3)
        self.assertEqual({entry["id"]: entry["path"] for entry in entries}, EXPECTED)
        for entry in entries:
            document = load_json_strict(ROOT / entry["path"])
            self.assertEqual(sha(canonical_json_v1_bytes(document)), entry["canonical_sha256"])

    def test_profile_closes_modes_states_errors_and_authority(self) -> None:
        profile = load_json_strict(CONTRACT_ROOT / "shadow_match_owner_gate_profile.json")
        self.assertEqual(profile["profile_id"], PROFILE_ID)
        self.assertEqual(profile["owner_modes"], ["legacy", "aligned_shadow"])
        self.assertEqual(profile["states"], ["idle", "active", "between_matches"])
        self.assertEqual(len(profile["error_codes"]), len(set(profile["error_codes"])))
        semantics = profile["semantics"]
        self.assertTrue(semantics["owner_mode_immutable_during_active_match"])
        self.assertTrue(semantics["rollback_applies_to_next_strictly_newer_match_only"])
        self.assertTrue(semantics["pending_rollback_forces_legacy"])
        self.assertTrue(semantics["aligned_shadow_requires_same_generation_broker"])
        self.assertFalse(semantics["engine_method_invocation"])
        self.assertFalse(semantics["serialized_audit_is_authority"])
        self.assertIn("broker", profile["private_fields_forbidden_from_audit"])
        self.assertIn("session_id", profile["private_fields_forbidden_from_audit"])

    def test_vectors_cover_owner_lock_and_next_match_rollback(self) -> None:
        vectors = load_json_strict(CONTRACT_ROOT / "shadow_match_owner_gate_conformance_vectors.json")
        self.assertEqual(vectors["profile_id"], PROFILE_ID)
        cases = vectors["cases"]
        case_ids = [case["case_id"] for case in cases]
        self.assertEqual(len(case_ids), len(set(case_ids)))
        required = {
            "begin-legacy", "begin-aligned", "active-owner-switch-rejected",
            "request-next-legacy", "current-owner-unchanged-after-request",
            "end-with-pending-rollback", "next-aligned-request-forced-legacy",
            "pending-rollback-cannot-be-overwritten", "stale-generation",
            "aligned-without-broker", "aligned-cross-generation-broker",
            "legacy-with-broker", "strictly-newer-match", "audit-copy-nonauthority",
        }
        self.assertTrue(required.issubset(case_ids))
        self.assertEqual(vectors["private_sentinels"], [
            "PRIVATE_SESSION_SENTINEL", "PRIVATE_BROKER_SENTINEL", "PRIVATE_PROMPT_SENTINEL"
        ])

    def test_schema_closes_state_relations_and_private_fields(self) -> None:
        schema = load_json_strict(CONTRACT_ROOT / "shadow_match_owner_gate.schema.json")
        Draft202012Validator.check_schema(schema)
        validator = Draft202012Validator(schema)
        base = {
            "profile": PROFILE_ID, "gate_generation": 1, "state": "active", "match_generation": 1,
            "active_mode": "legacy", "rollback_pending": False, "next_forced_mode": None,
            "rollback_applied": False, "authority": "shadow_match_owner_gate_audit", "authoritative": False,
        }
        self.assertEqual(list(validator.iter_errors(base)), [])
        mutations = [
            {**base, "active_mode": None},
            {**base, "rollback_pending": True, "next_forced_mode": None},
            {**base, "rollback_applied": True, "active_mode": "aligned_shadow"},
            {**base, "match_generation": 9007199254740992},
            {**base, "authoritative": True},
            {**base, "PRIVATE_BROKER_SENTINEL": "leak"},
            {**base, "state": "idle", "match_generation": None, "active_mode": None},
        ]
        for mutation in mutations:
            self.assertTrue(list(validator.iter_errors(mutation)), mutation)


if __name__ == "__main__":
    unittest.main()
