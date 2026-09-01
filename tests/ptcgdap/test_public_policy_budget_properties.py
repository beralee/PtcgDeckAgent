from __future__ import annotations

from enum import IntEnum
import unittest

from scripts.ai.ptcgdap.public_policy_budget import PublicPolicyBudgetController, PublicPolicyBudgetLedger
from tests.ptcgdap.test_public_policy_budget import VECTORS, budget_window


class _IntLike(IntEnum):
    ZERO = 0


class PublicPolicyBudgetPropertyTests(unittest.TestCase):
    def test_thresholds_are_monotonic_and_fallback_is_current_window_legal(self) -> None:
        modes = []
        for elapsed in (0, 569999, 570000, 594999, 595000, 600000, 600001):
            ledger = PublicPolicyBudgetLedger.start(VECTORS["fixture"]["ledger_id"])
            window = budget_window()
            result = PublicPolicyBudgetController.step(
                ledger, window, elapsed_ms=elapsed, capabilities=VECTORS["fixture"]["all_available_capabilities"]
            ).result
            modes.append(result.mode)
            if result.mode == "deterministic_fallback":
                self.assertEqual([0], result.selected_indexes)
                self.assertLess(result.selected_indexes[0], len(window.option_fingerprints))
        self.assertEqual(["full", "full", "base_only", "base_only", "deterministic_fallback", "deterministic_fallback", "deterministic_fallback"], modes)

    def test_exact_integer_mutation_and_cross_window_binding_fail_closed(self) -> None:
        for bad in (True, 0.0, _IntLike.ZERO, 9007199254740992):
            outcome = PublicPolicyBudgetController.step(
                PublicPolicyBudgetLedger.start(VECTORS["fixture"]["ledger_id"]),
                budget_window(), elapsed_ms=bad, capabilities=VECTORS["fixture"]["all_available_capabilities"]
            )
            self.assertFalse(outcome.accepted, bad)
        ledger = PublicPolicyBudgetLedger.start(VECTORS["fixture"]["ledger_id"])
        window = budget_window()
        result = PublicPolicyBudgetController.step(
            ledger, window, elapsed_ms=1, capabilities=VECTORS["fixture"]["all_available_capabilities"]
        ).result
        other = budget_window()
        self.assertFalse(result.validate_integrity(ledger, other))
        object.__setattr__(result, "_snapshot", {"PRIVATE": "SENTINEL"})
        self.assertEqual([], result.selected_indexes)


if __name__ == "__main__":
    unittest.main()
