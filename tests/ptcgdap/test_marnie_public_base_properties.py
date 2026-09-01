from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from scripts.ai.ptcgdap.marnie_public_base import MarniePublicBase, MarniePublicBaseError
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
FORBIDDEN = {"search_begin_input", "raw_private_hash", "token_free_callback_hash", "callback_binding_hash", "private_engine_command", "private_object_refs", "ticket", "command"}
TRUST_FILES = [
    "contracts/ptcgdap/marnie_public_base_bundle.json",
    "contracts/ptcgdap/marnie_public_base.schema.json",
    "contracts/ptcgdap/marnie_public_base_profile.json",
    "contracts/ptcgdap/marnie_public_base_conformance_vectors.json",
    "data/ptcgdap/marnie_vertical_slice/marnie_public_base_v1.json",
    "contracts/ptcgdap/marnie_prompt_broker_bundle.json",
    "contracts/ptcgdap/marnie_trajectory_replay_bundle.json",
    "contracts/ptcgdap/public_base_policy_bundle.json",
    "contracts/ptcgdap/public_deck_adapter_bundle.json",
    "contracts/ptcgdap/restricted_base_graph_executor_bundle.json",
    "contracts/ptcgdap/strategic_context_v18_bundle.json",
    "contracts/ptcgdap/strategic_trace_v2_bundle.json",
    "contracts/ptcgdap/cabt_public_firewall_bundle.json",
]


def contains_forbidden(value: object) -> bool:
    if isinstance(value, dict):
        return any(key in FORBIDDEN or contains_forbidden(item) for key, item in value.items())
    if isinstance(value, (list, tuple)):
        return any(contains_forbidden(item) for item in value)
    return False


class MarniePublicBasePropertyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.owner = MarniePublicBase.load_default()

    def test_case_chain_counts_macro_coverage_and_public_scope_are_invariant(self) -> None:
        snapshot = self.owner.evaluate_all().to_public_dict()
        cases = snapshot["cases"]
        self.assertEqual(list(range(16)), [case["ordinal"] for case in cases])
        self.assertEqual([None, *[case["result_hash"] for case in cases[:-1]]], [case["previous_result_hash"] for case in cases])
        self.assertEqual(cases[-1]["result_hash"], snapshot["chain_head"])
        self.assertEqual(13, sum(case["status"] == "orchestrated" for case in cases))
        self.assertEqual(3, sum(case["status"] == "not_applicable" for case in cases))
        self.assertEqual(3, sum(case["offline_seeded_extension"] for case in cases))
        self.assertEqual(6, len({case["macro_id"] for case in cases if case["macro_id"] is not None}))
        self.assertFalse(contains_forbidden(snapshot))
        for case in cases:
            self.assertFalse(case["authoritative"])
            self.assertFalse(case["execution_authority"])
            self.assertEqual(len(case["selected_indexes"]), len(set(case["selected_indexes"])))
            self.assertTrue(all(type(index) is int and index >= 0 for index in case["selected_indexes"]))
            if case["status"] == "not_applicable":
                self.assertEqual([], case["selected_indexes"])
                self.assertIsNone(case["window_id"])

    def test_result_mutation_and_copying_never_gain_authority_or_echo(self) -> None:
        result = self.owner.evaluate_all()
        public = result.to_public_dict()
        public["cases"][0]["selected_indexes"] = [999999]
        self.assertTrue(result.validate_integrity(self.owner))
        self.assertNotIn(999999, result.to_public_dict()["cases"][0]["selected_indexes"])
        object.__setattr__(result, "_snapshot", {"accepted": True, "cases": [{"PRIVATE_SENTINEL": 999999}]})
        self.assertFalse(result.validate_integrity(self.owner))
        safe = result.to_public_dict()
        self.assertFalse(safe["accepted"])
        self.assertNotIn("PRIVATE_SENTINEL", json.dumps(safe))

    def test_disk_artifact_parent_and_self_consistent_rehash_drift_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-p5-wp6-tamper-") as temp:
            root = Path(temp)
            for relative in TRUST_FILES:
                destination = root / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / relative, destination)

            schema_path = root / "contracts/ptcgdap/marnie_public_base.schema.json"
            schema = load_json_strict(schema_path)
            schema["title"] = "PRIVATE_SENTINEL"
            schema_path.write_text(json.dumps(schema), encoding="utf-8")
            with self.assertRaisesRegex(MarniePublicBaseError, "contract_integrity_invalid"):
                MarniePublicBase.load_trusted_bundle(root)

            shutil.copy2(ROOT / TRUST_FILES[1], schema_path)
            profile_path = root / "contracts/ptcgdap/marnie_public_base_profile.json"
            profile = load_json_strict(profile_path)
            profile["status"] = "forged"
            profile_path.write_text(json.dumps(profile), encoding="utf-8")
            bundle_path = root / "contracts/ptcgdap/marnie_public_base_bundle.json"
            bundle = load_json_strict(bundle_path)
            bundle["artifacts"][1]["canonical_sha256"] = hashlib.sha256(canonical_json_v1_bytes(profile)).hexdigest().upper()
            bundle_path.write_text(json.dumps(bundle), encoding="utf-8")
            with self.assertRaisesRegex(MarniePublicBaseError, "contract_integrity_invalid"):
                MarniePublicBase.load_trusted_bundle(root)

            shutil.copy2(ROOT / TRUST_FILES[0], bundle_path)
            shutil.copy2(ROOT / TRUST_FILES[2], profile_path)
            parent_path = root / "contracts/ptcgdap/public_base_policy_bundle.json"
            parent = load_json_strict(parent_path)
            parent["bundle_id"] = "forged"
            parent_path.write_text(json.dumps(parent), encoding="utf-8")
            with self.assertRaisesRegex(MarniePublicBaseError, "parent_contract_invalid"):
                MarniePublicBase.load_trusted_bundle(root)

    def test_z_owner_internal_mutation_fails_closed_for_every_public_surface(self) -> None:
        original_cases = self.owner._cases
        cases = copy.deepcopy(self.owner.evaluate_all().to_public_dict()["cases"])
        cases[1]["selected_indexes"] = [999999]
        object.__setattr__(self.owner, "_cases", tuple(cases))
        self.assertFalse(self.owner._integrity_valid())
        object.__setattr__(self.owner, "_cases", original_cases)
        self.assertTrue(self.owner._integrity_valid())

        expected = copy.deepcopy(self.owner.evaluate_all().to_public_dict())
        expected["execution_authority"] = True
        expected["PRIVATE_SENTINEL"] = 999999
        object.__setattr__(self.owner, "_expected", expected)
        self.assertEqual(
            {"ok": False, "error_code": "contract_integrity_invalid", "value": None},
            self.owner.run("evaluate_all", {}),
        )
        with self.assertRaisesRegex(MarniePublicBaseError, "contract_integrity_invalid"):
            self.owner.bundle_hash()
        with self.assertRaisesRegex(MarniePublicBaseError, "contract_integrity_invalid"):
            self.owner.audit_snapshot()
        self.assertNotIn("PRIVATE_SENTINEL", json.dumps(self.owner.run("evaluate_all", {})))


if __name__ == "__main__":
    unittest.main()
