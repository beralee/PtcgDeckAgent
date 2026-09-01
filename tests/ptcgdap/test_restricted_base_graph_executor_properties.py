from __future__ import annotations

import copy
from enum import IntEnum
import unittest

from scripts.ai.ptcgdap.restricted_base_graph_executor import _compute
from scripts.ai.ptcgdap.strategic_trace_v2 import RestrictedBaseGraphIRCompiler
from scripts.ai.ptcgdap.source_lock import load_json_strict
from tests.ptcgdap.test_strategic_trace_v2 import _context_decision


class _IntegerTrap(IntEnum):
    ZERO = 0
    ONE = 1


class RestrictedBaseGraphExecutorPropertyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        parent = load_json_strict(__import__("pathlib").Path("contracts/ptcgdap/strategic_trace_v2_conformance_vectors.json"))
        documents = {case["id"]: case["document"] for case in parent["ir_cases"]}
        cls.minimal = RestrictedBaseGraphIRCompiler.compile(documents["minimal-base"]).ir.to_public_dict()
        cls.adapters = RestrictedBaseGraphIRCompiler.compile(documents["public-adapter-proposals"]).ir.to_public_dict()
        cls.base_context = _context_decision()[0].to_public_dict()

    def _context(self, option_count: int, min_count: int, max_count: int) -> dict:
        value = copy.deepcopy(self.base_context)
        value["source"]["option_count"] = option_count
        value["select_semantics"]["min_count"] = min_count
        value["select_semantics"]["max_count"] = max_count
        value["select_semantics"]["options"] = [
            {"index": index, "fingerprint": f"{index + 1:064X}", "raw": {"type": index}}
            for index in range(option_count)
        ]
        return value

    def _input(self, option_count: int, **changes) -> dict:
        value = {
            "execution_id": "property",
            "mandatory_indexes": [],
            "terminal_indexes": [],
            "base_hard_tiers": [{"index": index, "tier": [0]} for index in range(option_count)],
            "base_vetoed_indexes": [],
            "adapter_proposals": [],
        }
        value.update(copy.deepcopy(changes))
        return value

    def test_cardinality_and_optional_zero_sweep(self) -> None:
        for option_count in range(0, 9):
            for min_count in range(0, option_count + 1):
                context = self._context(option_count, min_count, option_count)
                error, result = _compute(context, self.minimal, self._input(option_count))
                self.assertIsNone(error, (option_count, min_count, error))
                self.assertEqual(list(range(min_count)), result["selected_indexes"])
                self.assertEqual("empty_selection" if min_count == 0 else "deterministic_fallback", result["reason_code"])
                self.assertEqual(len(result["node_audit"]), len(self.minimal["nodes"]))

    def test_base_tier_veto_and_adapter_permutations_never_cross_authority(self) -> None:
        context = self._context(6, 2, 4)
        tiers = [{"index": index, "tier": [0 if index in (1, 3, 5) else 1, index % 2]} for index in range(6)]
        value = self._input(
            6,
            base_hard_tiers=tiers,
            base_vetoed_indexes=[3],
            adapter_proposals=[
                {"operator": "goal_proposal", "indexes": [5, 0, 1], "reason_code": "public_goal_proposal"},
                {"operator": "tiebreak_score", "indexes": [1, 5], "reason_code": "public_tiebreak_proposal"},
            ],
        )
        error, result = _compute(context, self.adapters, value)
        self.assertIsNone(error)
        self.assertEqual([1, 5], result["selected_indexes"])
        self.assertNotIn(0, result["selected_indexes"], "adapter crossed the best Base hard tier")
        self.assertNotIn(3, result["selected_indexes"], "adapter overrode Base veto")
        value["base_vetoed_indexes"] = [1, 3, 5]
        error, result = _compute(context, self.adapters, value)
        self.assertEqual("insufficient_candidates", error)
        self.assertIsNone(result)

    def test_terminal_and_mandatory_are_never_filtered_by_tier_or_adapter(self) -> None:
        context = self._context(5, 2, 3)
        value = self._input(
            5,
            mandatory_indexes=[4, 2],
            base_hard_tiers=[{"index": index, "tier": [99 if index in (4, 2) else 0]} for index in range(5)],
            adapter_proposals=[{"operator": "goal_proposal", "indexes": [0, 1], "reason_code": "public_goal_proposal"}],
        )
        error, result = _compute(context, self.adapters, value)
        self.assertIsNone(error)
        self.assertEqual([4, 2], result["selected_indexes"])
        value["terminal_indexes"] = [3, 1]
        error, result = _compute(context, self.adapters, value)
        self.assertIsNone(error)
        self.assertEqual([3, 1], result["selected_indexes"])
        self.assertEqual("terminal_selection", result["reason_code"])

    def test_exact_host_types_and_unsafe_integers_fail_closed(self) -> None:
        context = self._context(2, 1, 1)
        traps = [
            ("mandatory_indexes", (_IntegerTrap.ZERO,)),
            ("mandatory_indexes", [_IntegerTrap.ZERO]),
            ("terminal_indexes", [True]),
            ("base_vetoed_indexes", [1.0]),
            ("base_hard_tiers", [{"index": 0, "tier": [0]}, {"index": 1, "tier": [9_007_199_254_740_992]}]),
        ]
        for field, trap in traps:
            value = self._input(2)
            value[field] = trap
            error, result = _compute(context, self.minimal, value)
            self.assertEqual("invalid_execution_input", error, (field, trap))
            self.assertIsNone(result)


if __name__ == "__main__":
    unittest.main()
