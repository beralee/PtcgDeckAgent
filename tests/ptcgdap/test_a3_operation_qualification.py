from __future__ import annotations

import hashlib
import json
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.a3_operation_qualification import (
    A3OperationQualificationError,
    NATIVE_OPTION_TYPES,
    build_operation_qualification,
)
from scripts.ai.ptcgdap.cabt_tree_hash import jcs_canonical_json_bytes


def _seal(value: dict) -> dict:
    result = dict(value)
    result["evidence_sha256"] = hashlib.sha256(
        jcs_canonical_json_bytes(value)
    ).hexdigest().upper()
    return result


class A3OperationQualificationTests(unittest.TestCase):
    def test_live_pass_closes_only_the_narrow_input_index_contract(self) -> None:
        private_report = _seal({
            "document_type": "ptcgdap_a3_private_semantic_correspondence_v2",
            "schema_version": 2,
            "evidence_classification": "trusted-private",
            "publishable": False,
            "decks": [{"entries": [{
                "status": "exact_corresponding_printing",
                "semantic_card_id": "private-card:P_1",
                "private_card_uid": "P_1",
                "official_card_ids": [42],
                "private_attack_ids": ["P_1:attack:0"],
                "official_attack_ids": [7],
                "bridge_record_sha256": "B" * 64,
            }]}],
        })
        receipt = build_operation_qualification(
            {"scope_sha256": "A" * 64}, private_report,
            static_projection_suite_passed=True,
            privacy_suite_passed=True,
            live_setup_input_index_witness_passed=True,
            source_identities={
                key: character * 64 for key, character in zip(
                    (
                        "operation_contract", "differential_comparator", "godot_adapter",
                        "godot_decision_owner",
                        "official_adapter", "match_plan", "static_projection_test",
                        "privacy_test", "live_test",
                    ),
                    "CDEFGHIJK", strict=True,
                )
            },
        )
        self.assertEqual(receipt["qualification_status"], "passed")
        self.assertEqual(receipt["synthetic_projection_type_coverage"], list(NATIVE_OPTION_TYPES))
        self.assertEqual(receipt["live_operation_type_coverage"], [3])
        self.assertEqual(
            receipt["maximum_claim"],
            "setup_active_corresponding_card_input_index_contract",
        )
        self.assertEqual(
            receipt["current_window_index_acceptance_witness"],
            "passed_both_engines_setup_active_only",
        )
        self.assertEqual(receipt["stable_public_transition_witness"], "not_claimed")
        self.assertEqual(receipt["private_correspondence_sha256"], private_report["evidence_sha256"])
        self.assertEqual(len(receipt["semantic_relation_sha256"]), 64)
        self.assertIn("five_deck_full_rule_outcome_a3", receipt["non_claims"])
        self.assertIn("stable_public_transition_parity", receipt["non_claims"])
        projected = dict(receipt)
        expected = projected.pop("evidence_sha256")
        self.assertEqual(expected, hashlib.sha256(jcs_canonical_json_bytes(projected)).hexdigest().upper())

    def test_source_identity_or_unsealed_correspondence_fails_closed(self) -> None:
        with self.assertRaises(A3OperationQualificationError):
            build_operation_qualification(
                {"scope_sha256": "A" * 64}, {},
                static_projection_suite_passed=True,
                privacy_suite_passed=True,
                live_setup_input_index_witness_passed=True,
                source_identities={},
            )

    def test_generated_public_receipt_contains_no_private_ids_or_machine_locator(self) -> None:
        path = Path(__file__).resolve().parents[2] / (
            "evidence/ptcgdap/a3/corresponding_card_operation_qualification_v1.json"
        )
        receipt = json.loads(path.read_text(encoding="utf-8"))
        text = json.dumps(receipt, ensure_ascii=False, sort_keys=True)
        self.assertEqual(receipt["qualification_status"], "passed")
        self.assertFalse(receipt["operation_receipt_embeds_official_numeric_mapping"])
        self.assertFalse(receipt["private_source_locator_persisted"])
        self.assertNotIn("CSV10C_", text)
        self.assertNotIn("D:\\ai\\code", text)
        self.assertNotIn("private-bundle-root", text)


if __name__ == "__main__":
    unittest.main()
