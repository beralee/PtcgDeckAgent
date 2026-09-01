from __future__ import annotations

import copy
from enum import IntEnum
import unittest

from scripts.ai.ptcgdap.public_base_policy import PublicBasePolicyOrchestrator
from tests.ptcgdap.test_public_base_policy import VECTORS, policy_owners


class _IntLike(IntEnum):
    ZERO = 0


class PublicBasePolicyPropertyTests(unittest.TestCase):
    def test_forced_nonminimum_tier_remains_base_authority_and_traceable(self) -> None:
        case = next(value for value in VECTORS["orchestration_cases"] if value["id"] == "mandatory-nonminimum-tier")
        context, window, ir, adapter = policy_owners()
        result = PublicBasePolicyOrchestrator.orchestrate(context, window, ir, adapter, copy.deepcopy(case["request"])).result
        self.assertEqual([0], result.agent_output())
        trace = result.trace.to_public_dict()
        self.assertEqual([0], trace["frontier"]["mandatory_indexes"])
        self.assertEqual([1], trace["frontier"]["base_hard_tiers"][0]["tier"])

    def test_adapter_never_restores_veto_or_crosses_minimum_tier(self) -> None:
        for case_id in ("best-hard-tier", "veto-adapter-first"):
            case = next(value for value in VECTORS["orchestration_cases"] if value["id"] == case_id)
            context, window, ir, adapter = policy_owners()
            result = PublicBasePolicyOrchestrator.orchestrate(context, window, ir, adapter, copy.deepcopy(case["request"])).result
            self.assertEqual(case["expected_selected_indexes"], result.agent_output())

    def test_exact_integer_types_and_stale_result_binding_fail_closed(self) -> None:
        base = copy.deepcopy(VECTORS["orchestration_cases"][0]["request"])
        for bad in (True, 0.0, _IntLike.ZERO, 9007199254740992):
            context, window, ir, adapter = policy_owners()
            request = copy.deepcopy(base); request["base_hard_tiers"][0]["tier"] = [bad]
            outcome = PublicBasePolicyOrchestrator.orchestrate(context, window, ir, adapter, request)
            self.assertFalse(outcome.accepted, bad)
        context, window, ir, adapter = policy_owners()
        result = PublicBasePolicyOrchestrator.orchestrate(context, window, ir, adapter, base).result
        other_context, other_window, _, _ = policy_owners()
        self.assertFalse(result.validate_integrity(other_context, other_window, ir, adapter))
        object.__setattr__(result, "_snapshot", {"PRIVATE": "SENTINEL"})
        self.assertEqual([], result.agent_output())


if __name__ == "__main__":
    unittest.main()
