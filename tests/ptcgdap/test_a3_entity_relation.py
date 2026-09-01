from __future__ import annotations

import unittest

from scripts.ai.ptcgdap.a3_entity_relation import (
    EntityRelationError,
    SemanticActionBinder,
    SemanticEntityRelation,
)


DECK_HASH = "D" * 64


class A3EntityRelationTests(unittest.TestCase):
    def relation(self) -> SemanticEntityRelation:
        relation = SemanticEntityRelation()
        relation.bind_deck_occurrence(
            official_card_id=646,
            deck_occurrence=0,
            left_serial=101,
            right_serial=9001,
            source_deck_hash=DECK_HASH,
        )
        return relation

    def test_different_engine_serials_have_same_semantic_frontier(self) -> None:
        relation = self.relation()
        left = [{"type": 3, "cardId": 646, "serial": 101}]
        right = [{"type": 3, "cardId": 646, "serial": 9001}]
        self.assertEqual(
            relation.semantic_frontier("left", left),
            relation.semantic_frontier("right", right),
        )

    def test_duplicate_printings_require_explicit_occurrence_evidence(self) -> None:
        relation = self.relation()
        with self.assertRaisesRegex(EntityRelationError, "parity_entity_unbound"):
            relation.semantic_option("left", {"cardId": 646, "serial": 102})

    def test_event_lineage_can_bind_successor_without_serial_equality(self) -> None:
        relation = self.relation()
        relation.bind_lineage_successor(
            semantic_id="card:646:occurrence:0",
            left_serial=202,
            right_serial=9202,
            event_ordinal=7,
            event_fingerprint="E" * 64,
        )
        self.assertEqual(
            relation.semantic_id("left", 202),
            relation.semantic_id("right", 9202),
        )

    def test_bijection_conflict_is_atomic(self) -> None:
        relation = self.relation()
        with self.assertRaisesRegex(EntityRelationError, "bijection_conflict"):
            relation.bind_deck_occurrence(
                official_card_id=647,
                deck_occurrence=1,
                left_serial=202,
                right_serial=9001,
                source_deck_hash=DECK_HASH,
            )
        with self.assertRaisesRegex(EntityRelationError, "parity_entity_unbound"):
            relation.semantic_id("left", 202)

    def test_semantic_binder_rejects_name_and_zone_guessing(self) -> None:
        relation = self.relation()
        with self.assertRaisesRegex(EntityRelationError, "forbidden_identity"):
            SemanticActionBinder.resolve(
                {"count": 1, "match": {"cardId": 646}, "name": "Grimmsnarl"},
                side="left",
                options=[{"type": 3, "cardId": 646, "serial": 101}],
                relation=relation,
            )

    def test_semantic_binder_resolves_exact_card_and_entity(self) -> None:
        relation = self.relation()
        indexes = SemanticActionBinder.resolve(
            {
                "count": 1,
                "match": {
                    "cardId": 646,
                    "serial": "card:646:occurrence:0",
                },
            },
            side="right",
            options=[{"type": 3, "cardId": 646, "serial": 9001}],
            relation=relation,
        )
        self.assertEqual(indexes, [0])

    def test_private_and_official_card_ids_require_an_evidence_bridge(self) -> None:
        relation = SemanticEntityRelation()
        relation.bind_card_identity(
            semantic_card_id="printing:dri:136",
            left_card_id="CSV10C_148",
            right_card_ids=(648,),
            evidence_kind="exact_corresponding_printing",
            evidence_hash="A" * 64,
        )
        relation.bind_deck_occurrence(
            semantic_card_id="printing:dri:136",
            left_card_id="CSV10C_148",
            official_card_id=648,
            deck_occurrence=0,
            left_serial=101,
            right_serial=9001,
            source_deck_hash=DECK_HASH,
        )
        self.assertEqual(
            relation.semantic_frontier(
                "left", [{"type": 3, "cardId": "CSV10C_148", "serial": 101}],
            ),
            relation.semantic_frontier(
                "right", [{"type": 3, "cardId": 648, "serial": 9001}],
            ),
        )

    def test_attack_ids_are_compared_through_the_same_evidence_domain(self) -> None:
        relation = SemanticEntityRelation()
        relation.bind_attack_identity(
            semantic_attack_id="printing:dri:136:attack:0",
            left_attack_id="CSV10C_148:0",
            right_attack_ids=(937,),
            owner_semantic_card_id="printing:dri:136",
            evidence_hash="B" * 64,
        )
        self.assertEqual(
            relation.semantic_option("left", {"type": 2, "attackId": "CSV10C_148:0"}),
            relation.semantic_option("right", {"type": 2, "attackId": 937}),
        )

    def test_unbridged_private_identity_fails_closed(self) -> None:
        relation = SemanticEntityRelation()
        with self.assertRaisesRegex(EntityRelationError, "parity_card_identity_unbound"):
            relation.semantic_option("left", {"type": 3, "cardId": "CSV10C_148"})

    def test_semantic_tree_maps_identity_fields_in_logs_and_snapshots(self) -> None:
        relation = SemanticEntityRelation()
        relation.bind_card_identity(
            semantic_card_id="printing:dri:136",
            left_card_id="CSV10C_148",
            right_card_ids=(648,),
            evidence_kind="exact_corresponding_printing",
            evidence_hash="C" * 64,
        )
        left = {"logs": [{"cardId": "CSV10C_148"}], "state": {"cardId": "CSV10C_148"}}
        right = {"logs": [{"cardId": 648}], "state": {"cardId": 648}}
        self.assertEqual(relation.semantic_tree("left", left), relation.semantic_tree("right", right))


if __name__ == "__main__":
    unittest.main()
