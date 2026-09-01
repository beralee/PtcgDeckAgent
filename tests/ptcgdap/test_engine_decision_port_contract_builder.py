from __future__ import annotations

import hashlib
import json
import unittest
from pathlib import Path

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes
from tools.ptcgdap.build_engine_decision_port_contract import ROOT, build_documents


class EngineDecisionPortContractBuilderTests(unittest.TestCase):
    def test_generated_documents_are_current_and_strict(self) -> None:
        documents = build_documents()
        for path, expected in documents.items():
            self.assertTrue(path.is_file(), path)
            actual = json.loads(path.read_text(encoding="utf-8"), parse_constant=lambda value: self.fail(value))
            self.assertEqual(actual, expected, path)
        bundle = documents[ROOT / "contracts/ptcgdap/engine_decision_port_bundle.json"]
        self.assertEqual([item["id"] for item in bundle["artifacts"]], ["schema", "profile", "vectors"])
        for entry in bundle["artifacts"]:
            value = json.loads((ROOT / entry["path"]).read_text(encoding="utf-8"))
            self.assertEqual(hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper(), entry["canonical_sha256"])

    def test_schema_accepts_owner_dtos_and_rejects_authority_smuggling(self) -> None:
        docs = build_documents()
        schema = docs[ROOT / "contracts/ptcgdap/engine_decision_port.schema.json"]
        vectors = docs[ROOT / "contracts/ptcgdap/engine_decision_port_conformance_vectors.json"]
        validator = Draft202012Validator(schema)
        for case in vectors["publish_cases"]:
            self.assertFalse(list(validator.iter_errors(case)), case["id"])
        accepted = {
            "accepted": True,
            "error_code": "",
            "audit": {
                "match_generation": 1,
                "decision_generation": 1,
                "chooser_player_index": 0,
                "snapshot_id": "A" * 64,
                "source_digest": "B" * 64,
                "select": None,
                "turn_action_count": 0,
                "reference_count": 0,
                "authority": "engine_decision_port_shadow",
                "authoritative": False,
            },
        }
        self.assertFalse(list(validator.iter_errors(accepted)))
        for key in ["engine_object", "private_command", "ticket", "_pending_choice"]:
            mutated = json.loads(json.dumps(accepted))
            mutated["audit"][key] = "private-sentinel"
            self.assertTrue(list(validator.iter_errors(mutated)), key)

    def test_contract_contains_no_self_hash_cycle_or_live_claim(self) -> None:
        docs = build_documents()
        bundle = docs[ROOT / "contracts/ptcgdap/engine_decision_port_bundle.json"]
        text = json.dumps({str(path): value for path, value in docs.items()})
        self.assertNotIn("engine_decision_port_bundle.json\", \"canonical_sha256\"", text)
        self.assertEqual(bundle["parent"]["work_package"], "P2-WP5")
        profile = docs[ROOT / "contracts/ptcgdap/engine_decision_port_profile.json"]
        self.assertEqual(profile["mode"], "shadow_snapshot_only")
        self.assertFalse(profile["serialization_contract"].get("authoritative", False))


if __name__ == "__main__":
    unittest.main()
