from __future__ import annotations

import copy
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.public_policy_budget import PublicPolicyBudgetController, PublicPolicyBudgetLedger
from scripts.ai.ptcgdap.source_lock import load_json_strict
from tests.ptcgdap.test_strategic_context_v18 import _firewall_case, _window


ROOT = Path(__file__).resolve().parents[2]
VECTORS = load_json_strict(ROOT / "contracts/ptcgdap/public_policy_budget_conformance_vectors.json")


def budget_window():
    return _window(_firewall_case("regular-accepted")[1])


class PublicPolicyBudgetTests(unittest.TestCase):
    def test_shared_start_and_step_cases_match_exactly(self) -> None:
        started = PublicPolicyBudgetLedger.start(VECTORS["fixture"]["ledger_id"])
        self.assertTrue(started.validate_integrity())
        self.assertEqual(VECTORS["fixture"]["initial_ledger"], started.to_public_dict())
        for case in VECTORS["step_cases"]:
            with self.subTest(case=case["id"]):
                ledger = PublicPolicyBudgetLedger.start(VECTORS["fixture"]["ledger_id"])
                window = budget_window()
                outcome = PublicPolicyBudgetController.step(
                    ledger,
                    window,
                    elapsed_ms=case["elapsed_ms"],
                    capabilities=copy.deepcopy(case["capabilities"]),
                )
                self.assertTrue(outcome.accepted, outcome.error_code)
                self.assertIsNotNone(outcome.result)
                self.assertTrue(outcome.result.validate_integrity(ledger, window))
                self.assertEqual(case["expected_result"], outcome.result.to_public_dict())

    def test_shared_rejections_fail_closed_without_echo(self) -> None:
        for case in VECTORS["rejections"]:
            with self.subTest(case=case["id"]):
                ledger = PublicPolicyBudgetLedger.start(VECTORS["fixture"]["ledger_id"])
                window = budget_window()
                elapsed = 1
                capabilities = copy.deepcopy(VECTORS["fixture"]["all_available_capabilities"])
                if case["fault"] == "fake_ledger": ledger = object()
                elif case["fault"] == "fake_window": window = object()
                elif case["fault"] == "elapsed_bool": elapsed = True
                elif case["fault"] == "elapsed_negative": elapsed = -1
                elif case["fault"] == "elapsed_unsafe": elapsed = 9007199254740992
                elif case["fault"] == "capabilities_not_object": capabilities = []
                elif case["fault"] == "capability_state_not_string": capabilities["search_v1"] = True
                elif case["fault"] == "capability_state_unknown": capabilities["search_v1"] = "PRIVATE_SENTINEL"
                else: raise AssertionError(case["fault"])
                outcome = PublicPolicyBudgetController.step(ledger, window, elapsed_ms=elapsed, capabilities=capabilities)
                self.assertFalse(outcome.accepted)
                self.assertEqual(case["expected_error_code"], outcome.error_code)
                self.assertIsNone(outcome.result)
                self.assertNotIn("PRIVATE_SENTINEL", outcome.error_code)


if __name__ == "__main__":
    unittest.main()
