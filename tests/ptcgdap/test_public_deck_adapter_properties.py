from __future__ import annotations

import copy
from enum import IntEnum
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.public_deck_adapter import PublicDeckAdapterCompiler, PublicDeckAdapterProposer
from scripts.ai.ptcgdap.restricted_base_graph_executor import RestrictedBaseGraphExecutor
from scripts.ai.ptcgdap.source_lock import load_json_strict
from scripts.ai.ptcgdap.strategic_trace_v2 import RestrictedBaseGraphIRCompiler
from tests.ptcgdap.test_strategic_trace_v2 import _context_decision


ROOT = Path(__file__).resolve().parents[2]


def predicate(**changes):
    value = {
        "select_type_raw": None,
        "select_context_raw": None,
        "option_type_raw": None,
        "option_card_id": None,
        "option_player_index": None,
        "acting_hand_card_id": None,
        "acting_active_card_id": None,
    }
    value.update(changes)
    return value


def rule(rule_id: str, option_type: int, priority: int):
    return {
        "rule_id": rule_id,
        "operator": "goal_proposal",
        "reason_code": "public_goal_proposal",
        "goal_stage": "execute",
        "priority": priority,
        "predicate": predicate(option_type_raw=option_type),
    }


class PublicDeckAdapterPropertyTests(unittest.TestCase):
    def test_priority_rule_order_and_option_order_are_deterministic(self) -> None:
        context, _decision = _context_decision()
        for first_priority in range(3):
            for second_priority in range(3):
                document = {
                    "schema_version": 1,
                    "adapter_id": f"sweep.{first_priority}.{second_priority}",
                    "adapter_version": 1,
                    "rules": [rule("type1", 1, first_priority), rule("type2", 2, second_priority)],
                }
                adapter = PublicDeckAdapterCompiler.compile(document).adapter
                self.assertIsNotNone(adapter)
                first = PublicDeckAdapterProposer.propose(context, adapter, "sweep").result
                second = PublicDeckAdapterProposer.propose(context, adapter, "sweep").result
                self.assertEqual(first.to_public_dict(), second.to_public_dict())
                indexes = first.adapter_proposals[0]["indexes"]
                expected = [0, 1] if first_priority <= second_priority else [1, 0]
                self.assertEqual(expected, indexes)
                self.assertEqual(len(indexes), len(set(indexes)))
                self.assertTrue(all(0 <= index < 2 for index in indexes))

    def test_adapter_proposal_cannot_override_forced_tier_or_veto(self) -> None:
        vectors = load_json_strict(ROOT / "contracts/ptcgdap/public_deck_adapter_conformance_vectors.json")
        parent = load_json_strict(ROOT / "contracts/ptcgdap/strategic_trace_v2_conformance_vectors.json")
        document = copy.deepcopy(vectors["adapter_documents"][0]["document"])
        adapter = PublicDeckAdapterCompiler.compile(document).adapter
        context, _decision = _context_decision()
        proposals = PublicDeckAdapterProposer.propose(context, adapter, "integration").result.adapter_proposals
        ir_document = next(case["document"] for case in parent["ir_cases"] if case["id"] == "public-adapter-proposals")
        ir = RestrictedBaseGraphIRCompiler.compile(copy.deepcopy(ir_document)).ir
        base = {
            "execution_id": "adapter-integration",
            "mandatory_indexes": [0],
            "terminal_indexes": [1],
            "base_hard_tiers": [{"index": 0, "tier": [9]}, {"index": 1, "tier": [0]}],
            "base_vetoed_indexes": [],
            "adapter_proposals": proposals,
        }
        self.assertEqual([1], RestrictedBaseGraphExecutor.execute(context, ir, base).result.selected_indexes)
        base["terminal_indexes"] = []
        self.assertEqual([0], RestrictedBaseGraphExecutor.execute(context, ir, base).result.selected_indexes)
        base["mandatory_indexes"] = []
        base["base_vetoed_indexes"] = [1]
        rejected = RestrictedBaseGraphExecutor.execute(context, ir, base)
        self.assertFalse(rejected.accepted)
        self.assertEqual("insufficient_candidates", rejected.error_code)

    def test_python_integer_subtypes_bool_float_and_unsafe_values_fail_closed(self) -> None:
        class Number(IntEnum):
            ONE = 1

        base = {
            "schema_version": 1,
            "adapter_id": "exact.types",
            "adapter_version": 1,
            "rules": [rule("type1", 1, 0)],
        }
        for value in (True, 1.0, Number.ONE, 9007199254740992):
            document = copy.deepcopy(base)
            document["rules"][0]["priority"] = value
            outcome = PublicDeckAdapterCompiler.compile(document)
            self.assertFalse(outcome.accepted, value)
            self.assertEqual("invalid_adapter_document", outcome.error_code)


if __name__ == "__main__":
    unittest.main()
