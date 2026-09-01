from __future__ import annotations

import hashlib
import unittest

from scripts.ai.ptcgdap.a3_execution import (
    A3ExecutionReceiptError,
    build_execution_receipt,
)
from scripts.ai.ptcgdap.cabt_tree_hash import jcs_canonical_json_bytes


def seal(value: dict) -> dict:
    result = dict(value)
    result["receipt_sha256"] = hashlib.sha256(
        jcs_canonical_json_bytes(value)
    ).hexdigest().upper()
    return result


class A3ExecutionTests(unittest.TestCase):
    @staticmethod
    def scope() -> dict:
        return {
            "scope_sha256": "A" * 64,
            "decks": [
                {"deck_id": 1, "ordered_private_deck_sha256": "B" * 64},
                {"deck_id": 2, "ordered_private_deck_sha256": "C" * 64},
            ],
            "oracle_provenance": {"official_engine_sha256": "D" * 64},
            "godot_candidate": {"dirty_scope_content_manifest_sha256": "E" * 64},
            "adapter_snapshot_comparator_action_protocol_files": [{
                "path": "contracts/ptcgdap/a3_engine_adapter_v2.json",
                "sha256": "F" * 64,
            }],
        }

    @staticmethod
    def self_replay(adapter_id: str) -> dict:
        return seal({
            "scope_sha256": "A" * 64,
            "adapter_id": adapter_id,
            "status": "aligned",
            "deterministic": True,
            "action_script_sha256": "1" * 64,
            "match_spec_sha256": "2" * 64,
            "a3_promoted": False,
        })

    def test_owner_seals_exact_configuration_and_component_identities(self) -> None:
        differential = {
            "document_type": "ptcgdap_a3_differential_report_v2",
            "scope_sha256": "A" * 64,
            "status": "aligned",
            "first_divergence": None,
            "a3_promoted": False,
        }
        exploration = {
            "scope_sha256": "A" * 64,
            "status": "complete",
            "unexplained_difference_count": 0,
            "dirty_case_count": 0,
            "harness_error_count": 0,
            "public_projection_status": "reviewed",
            "private_evidence_status": "isolated",
            "random_capability": "R0",
        }
        receipt = build_execution_receipt(
            self.scope(), (1, 2), self.self_replay("official-cabt-native"),
            self.self_replay("godot-headless-decision-owner-v2"),
            differential, exploration,
        )
        self.assertEqual(receipt["configuration_id"], "1->2")
        self.assertFalse(receipt["a3_promoted"])

    def test_mismatched_action_scripts_fail_closed(self) -> None:
        official = self.self_replay("official-cabt-native")
        godot = self.self_replay("godot-headless-decision-owner-v2")
        godot["action_script_sha256"] = "3" * 64
        godot = seal({key: value for key, value in godot.items() if key != "receipt_sha256"})
        with self.assertRaisesRegex(A3ExecutionReceiptError, "a3_execution_self_replay_input_mismatch"):
            build_execution_receipt(self.scope(), (1, 2), official, godot, {}, {})


if __name__ == "__main__":
    unittest.main()
