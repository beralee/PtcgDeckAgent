from __future__ import annotations

import hashlib
import json
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.a3_differential import Checkpoint, parity_observation_hash
from scripts.ai.ptcgdap.a3_entity_relation import SemanticEntityRelation
from scripts.ai.ptcgdap.a3_live_operation_witness import (
    A3LiveOperationWitnessError,
    LiveDecision,
    REQUIRED_OPERATION_FAMILIES,
    aligned_sequence_witness,
    build_public_live_operation_ledger,
)
from scripts.ai.ptcgdap.cabt_tree_hash import jcs_canonical_json_bytes


def _hash(value: object) -> str:
    return hashlib.sha256(jcs_canonical_json_bytes(value)).hexdigest().upper()


def _checkpoint(lane: str, serial: int, *, private: bool) -> Checkpoint:
    if private:
        option = {
            "option_type_raw": 3,
            "card_uid": "P_1",
            "card_serial": serial,
        }
        current = {"self": {}, "opponent": {}}
    else:
        option = {"type": 3, "area": 2, "index": 0, "playerIndex": 0}
        current = {
            "players": [
                {"hand": [{"id": 42, "serial": serial}]},
                {"hand": []},
            ]
        }
    select = {
        "type": 1, "context": 7, "minCount": 1, "maxCount": 1,
        "remainDamageCounter": 0, "remainEnergyCost": 0,
        "option": [option], "deck": None, "contextCard": None, "effect": None,
    }
    raw = {"current": current, "select": select, "logs": []}
    return Checkpoint(
        lane, "SELECTION", 1, 1, 0, raw, parity_observation_hash(raw),
        "window", 1, select, (option,), (_hash(option),), (),
        {"lifecycle": "selection"}, 0, ("test",),
    )


def _relation() -> SemanticEntityRelation:
    relation = SemanticEntityRelation()
    relation.bind_card_identity(
        semantic_card_id="private-card:P_1",
        left_card_id="P_1",
        right_card_ids=(42,),
        evidence_kind="exact_corresponding_printing",
        evidence_hash="A" * 64,
    )
    return relation


class A3LiveOperationWitnessTests(unittest.TestCase):
    def test_current_window_pair_is_semantically_aligned_across_id_domains(self) -> None:
        private = LiveDecision(_checkpoint("godot_private", 11, private=True), (0,), True, "B" * 64)
        official = LiveDecision(_checkpoint("official_native", 91, private=False), (0,), True, "C" * 64)
        family = aligned_sequence_witness(
            "exact_search", [(private, official)], relation_factory=_relation,
            source_locked_operation_sha256="D" * 64,
        )
        self.assertEqual(family["status"], "input-index-aligned")
        self.assertEqual(family["rows"][0]["selected_indexes"], [0])
        self.assertEqual(family["rows"][0]["ordered_option_type_raw"], [3])
        self.assertFalse(family["rows"][0]["post_state_claimed"])

    def test_public_ledger_requires_every_family_and_refuses_post_state_claims(self) -> None:
        private = LiveDecision(_checkpoint("godot_private", 11, private=True), (0,), True, "B" * 64)
        official = LiveDecision(_checkpoint("official_native", 91, private=False), (0,), True, "C" * 64)
        families = [
            aligned_sequence_witness(
                family, [(private, official)], relation_factory=_relation,
                source_locked_operation_sha256=_hash({"family": family}),
            )
            for family in REQUIRED_OPERATION_FAMILIES
        ]
        ledger = build_public_live_operation_ledger(
            scope_sha256="E" * 64,
            private_correspondence_sha256="F" * 64,
            families=families,
            source_identities={"live_witness": "1" * 64},
        )
        self.assertEqual(ledger["qualification_status"], "passed")
        self.assertEqual(
            ledger["maximum_claim"],
            "corresponding_card_whole_battle_input_index_contract",
        )
        self.assertFalse(ledger["official_numeric_mapping_embedded"])
        self.assertEqual(ledger["post_state_comparison"], "not_claimed")
        broken = list(families)
        broken.pop()
        with self.assertRaises(A3LiveOperationWitnessError):
            build_public_live_operation_ledger(
                scope_sha256="E" * 64,
                private_correspondence_sha256="F" * 64,
                families=broken,
                source_identities={"live_witness": "1" * 64},
            )

    def test_generated_whole_battle_ledger_is_closed_private_safe_and_narrow(self) -> None:
        root = Path(__file__).resolve().parents[2]
        path = root / (
            "evidence/ptcgdap/a3/"
            "corresponding_card_whole_battle_input_index_v1.json"
        )
        ledger = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual(ledger["qualification_status"], "passed")
        self.assertEqual(
            ledger["maximum_claim"],
            "corresponding_card_whole_battle_input_index_contract",
        )
        self.assertEqual(
            {row["family"] for row in ledger["families"]},
            set(REQUIRED_OPERATION_FAMILIES),
        )
        expected_contexts = {
            "ability_activation": [43],
            "attack": [0],
            "damage_allocation": [14] * 6,
            "evolution": [37],
            "exact_quantity": [22],
            "exact_search": [7],
            "retreat_switch": [3],
            "sequential_source_target": [22, 21, 21, 21],
            "special_condition_attack": [0],
        }
        for family in ledger["families"]:
            rows = family["rows"]
            with self.subTest(family=family["family"]):
                self.assertEqual(
                    [row["select_header"]["context"] for row in rows],
                    expected_contexts[family["family"]],
                )
                self.assertTrue(family["all_current_window_indexes_accepted"])
                self.assertTrue(all(
                    row["private_engine_accepted"]
                    and row["official_engine_accepted"]
                    and row["selected_indexes"]
                    and not row["post_state_claimed"]
                    for row in rows
                ))
        damage = next(
            family for family in ledger["families"]
            if family["family"] == "damage_allocation"
        )
        self.assertEqual(damage["remain_damage_counter_sequence"], [6, 5, 4, 3, 2, 1])
        self.assertEqual(ledger["post_state_comparison"], "not_claimed")
        self.assertIn("post_state_or_full_rule_a3", ledger["non_claims"])
        self.assertTrue(all(
            type(value) is str and len(value) == 64
            for value in ledger["source_identities"].values()
        ))
        public_source_paths = {
            "live_witness_owner": "scripts/ai/ptcgdap/a3_live_operation_witness.py",
            "operation_contract": "scripts/ai/ptcgdap/a3_operation_contract.py",
            "differential_comparator": "scripts/ai/ptcgdap/a3_differential.py",
            "godot_adapter": "tools/ptcgdap/a3_godot_headless_bridge.gd",
            "godot_decision_owner": (
                "scripts/ai/ptcgdap/host/godot/"
                "PtcgDAPAuthorDevelopmentBattleOwner.gd"
            ),
            "godot_engine_action_executor": (
                "scripts/ai/ptcgdap/host/godot/"
                "AuthorStrategyEngineActionExecutor.gd"
            ),
            "godot_headless_bridge": "scripts/ai/HeadlessMatchBridge.gd",
            "ucis_registry": "contracts/ptcgdap/ucis_registry_v1.json",
            "ucis_card_catalog": "contracts/ptcgdap/ucis_card_catalog_v1.json",
            "ucis_runtime_attestation": (
                "contracts/ptcgdap/ucis_runtime_attestation_v1.json"
            ),
        }
        for source_id, relative_path in public_source_paths.items():
            self.assertEqual(
                ledger["source_identities"][source_id],
                hashlib.sha256((root / relative_path).read_bytes()).hexdigest().upper(),
                source_id,
            )
        private_source_paths = {
            "qualification_generator": "tools/ptcgdap/build_a3_whole_battle_operation_qualification.py",
            "official_adapter": "tools/ptcgdap/private_official_cabt_bridge.py",
            "probe_recipe_owner": "tools/ptcgdap/probe_a3_live_trace.py",
        }
        self.assertTrue(all(
            source_id in ledger["source_identities"]
            and not (root / relative_path).exists()
            for source_id, relative_path in private_source_paths.items()
        ))
        projected = dict(ledger)
        expected_hash = projected.pop("evidence_sha256")
        self.assertEqual(expected_hash, _hash(projected))
        text = json.dumps(ledger, ensure_ascii=False, sort_keys=True)
        self.assertNotIn(r"D:\ai\code", text)
        self.assertNotIn("private-bundle-root", text)
        self.assertNotIn("CSV10C_", text)


if __name__ == "__main__":
    unittest.main()
