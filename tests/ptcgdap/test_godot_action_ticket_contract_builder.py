from __future__ import annotations

import copy
import hashlib
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tools.ptcgdap.build_godot_action_ticket_contract import (
    BUNDLE_PATH,
    ERROR_CODES,
    PROFILE_ID,
    PROFILE_PATH,
    SCHEMA_PATH,
    TICKET_PREFIX,
    VECTORS_PATH,
    build_documents,
)


ROOT = Path(__file__).resolve().parents[2]
PARENT_MANIFEST = ROOT / "artifacts/ptcgdap/p3_wp2/manifest.json"
PARENT_BUNDLE = ROOT / "contracts/ptcgdap/godot_option_binding_bundle.json"


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


class GodotActionTicketContractBuilderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.schema = load_json_strict(SCHEMA_PATH)
        cls.profile = load_json_strict(PROFILE_PATH)
        cls.vectors = load_json_strict(VECTORS_PATH)
        cls.bundle = load_json_strict(BUNDLE_PATH)
        cls.validator = Draft202012Validator(cls.schema)

    def test_generated_documents_are_checked_in_exactly(self) -> None:
        for path, expected in build_documents().items():
            rendered = (Path(path).read_text(encoding="utf-8"))
            self.assertEqual(rendered, __import__("json").dumps(expected, ensure_ascii=False, indent=2) + "\n")

    def test_bundle_is_exact_noncyclic_and_parent_bound(self) -> None:
        self.assertEqual(self.bundle["contract_id"], PROFILE_ID)
        self.assertEqual([entry["id"] for entry in self.bundle["artifacts"]], ["schema", "profile", "vectors"])
        self.assertEqual(len({entry["path"] for entry in self.bundle["artifacts"]}), 3)
        self.assertFalse(any(entry["path"].endswith("godot_action_ticket_bundle.json") for entry in self.bundle["artifacts"]))
        self.assertEqual(
            self.bundle["parent"]["manifest_canonical_sha256"],
            sha(canonical_json_v1_bytes(load_json_strict(PARENT_MANIFEST))),
        )
        self.assertEqual(
            self.bundle["parent"]["option_binding_bundle_canonical_sha256"],
            sha(canonical_json_v1_bytes(load_json_strict(PARENT_BUNDLE))),
        )
        for entry in self.bundle["artifacts"]:
            self.assertEqual(
                entry["canonical_sha256"],
                sha(canonical_json_v1_bytes(load_json_strict(ROOT / entry["path"]))),
            )

    def test_schema_accepts_every_document_and_shared_result(self) -> None:
        for value in (self.profile, self.vectors, self.bundle):
            self.validator.validate(value)
        fixture = self.vectors["fixture"]
        for audit in fixture["expected_ticket_audits"].values():
            self.validator.validate(audit)
        for audit in fixture["expected_claim_audits"].values():
            self.validator.validate(audit)
        for section in ("issue_cases", "claim_cases"):
            for case in self.vectors[section]:
                self.validator.validate(case["expected"])

    def test_ticket_ids_recompute_from_exact_private_context_and_order(self) -> None:
        fixture = self.vectors["fixture"]
        for name, audit in fixture["expected_ticket_audits"].items():
            payload = {
                "profile": PROFILE_ID,
                "ticket_generation": audit["ticket_generation"],
                "session_id": fixture["session_id"],
                "callback_binding_hash": fixture["callback_binding_hash"],
                "binding_version": audit["binding_version"],
                "snapshot_id": audit["snapshot_id"],
                "window_id": audit["window_id"],
                "public_observation_hash": audit["public_observation_hash"],
                "selected_indexes": audit["selected_indexes"],
                "selected_fingerprint_hashes": audit["selected_fingerprint_hashes"],
            }
            self.assertEqual(audit["ticket_id"], sha(TICKET_PREFIX + canonical_json_v1_bytes(payload)), name)
        ordered = fixture["expected_ticket_audits"]["policy_ordered"]
        self.assertEqual(ordered["selected_indexes"], [1, 0])
        self.assertNotEqual(ordered["ticket_id"], fixture["expected_ticket_audits"]["fallback_single"]["ticket_id"])

    def test_profile_closes_private_authority_and_error_domains(self) -> None:
        serialization = self.profile["serialization_contract"]
        self.assertFalse(serialization["grants_authority"])
        self.assertTrue({"session_id", "callback_binding_hash", "private_engine_command", "private_object_refs"}.issubset(serialization["forbidden_fields"]))
        self.assertEqual(self.profile["error_codes"], ERROR_CODES)
        self.assertEqual(len(ERROR_CODES), len(set(ERROR_CODES)))
        self.assertTrue(self.profile["issue_contract"]["requires_exact_owner_selection_resolution"])
        self.assertEqual(self.profile["claim_contract"]["claim_success_count"], 1)
        self.assertFalse(self.profile["claim_contract"]["commits_or_executes"])

    def test_schema_rejects_private_echo_open_shapes_and_invalid_relations(self) -> None:
        audit = copy.deepcopy(self.vectors["fixture"]["expected_ticket_audits"]["policy_ordered"])
        audit["session_id"] = "private-sentinel"
        self.assertFalse(self.validator.is_valid(audit))
        audit = copy.deepcopy(self.vectors["fixture"]["expected_claim_audits"]["policy_ordered"])
        audit["private_engine_command"] = "private-sentinel"
        self.assertFalse(self.validator.is_valid(audit))
        result = copy.deepcopy(self.vectors["issue_cases"][0]["expected"])
        result["accepted"] = False
        self.assertFalse(self.validator.is_valid(result))
        result = copy.deepcopy(self.vectors["claim_cases"][0]["expected"])
        result["audit"]["selected_indexes"] = [1, 1]
        self.assertFalse(self.validator.is_valid(result))
        result = copy.deepcopy(self.vectors["claim_cases"][2]["expected"])
        result["error_code"] = "private-sentinel"
        self.assertFalse(self.validator.is_valid(result))


if __name__ == "__main__":
    unittest.main()
