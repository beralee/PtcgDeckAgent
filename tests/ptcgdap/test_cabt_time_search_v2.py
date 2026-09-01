from __future__ import annotations

import unittest
from pathlib import Path

from scripts.ai.ptcgdap.cabt_time_search_v2 import (
    CallbackBudgetV2,
    CabtCapabilityV2Error,
    SearchCapabilityV2,
    load_time_profile,
)


ROOT = Path(__file__).resolve().parents[2]
CONTRACTS = ROOT / "contracts" / "ptcgdap"


class CabtTimeSearchV2Tests(unittest.TestCase):
    def test_official_baseline_numbers_are_exact_and_hash_bound(self) -> None:
        profile = load_time_profile(CONTRACTS, "official_locked_baseline")
        self.assertEqual(profile.act_timeout, 0)
        self.assertEqual(profile.remaining_overage_time, 600)
        self.assertEqual(profile.run_timeout, 2000)
        self.assertEqual(profile.episode_steps, 10_000_000)
        self.assertEqual(len(profile.profile_hash), 64)

    def test_budget_is_monotonic_across_import_callback_and_search(self) -> None:
        budget = CallbackBudgetV2(load_time_profile(CONTRACTS, "official_locked_baseline"))
        budget.charge(10, phase="import")
        budget.charge(20, phase="callback")
        before_search = budget.remaining_overage_time
        budget.charge(30, phase="search")
        self.assertEqual(budget.steps, 2)
        self.assertLess(budget.remaining_overage_time, before_search)
        with self.assertRaisesRegex(CabtCapabilityV2Error, "policy_timeout"):
            budget.charge(541, phase="callback")

    def test_godot_search_none_rejects_tokens_and_begin(self) -> None:
        search = SearchCapabilityV2("none")
        search.observe_callback({"search_begin_input": None})
        with self.assertRaisesRegex(CabtCapabilityV2Error, "authority_search_unavailable"):
            search.begin({})
        with self.assertRaisesRegex(CabtCapabilityV2Error, "authority_search_unavailable"):
            search.observe_callback({"search_begin_input": "opaque"})

    def test_official_token_is_callback_scoped_ascii_and_never_public(self) -> None:
        search = SearchCapabilityV2("official_native")
        search.observe_callback({"search_begin_input": "opaque-current-callback"})
        generation, token, prediction = search.begin({"prize": [1]})
        self.assertEqual(generation, 1)
        self.assertEqual(token, "opaque-current-callback")
        self.assertEqual(prediction, {"prize": [1]})
        self.assertIsNone(search.public_snapshot()["token"])
        search.observe_callback({"search_begin_input": None})
        with self.assertRaisesRegex(CabtCapabilityV2Error, "authority_search_unavailable"):
            search.begin({})


if __name__ == "__main__":
    unittest.main()
