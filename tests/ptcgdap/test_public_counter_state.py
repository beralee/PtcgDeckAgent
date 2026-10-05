from __future__ import annotations

import copy
import unittest

from scripts.ai.ptcgdap.competitive_policy_v2 import CompetitivePolicyV2Compiler as Compiler, CompetitivePolicyV2Runtime as Runtime
from tools.ptcgdap.build_competitive_policy_v2_contract import _sample_policy, _option, _frame
from tools.ptcgdap.public_counter_contract import counter_cases


class PublicCounterStateTests(unittest.TestCase):
    def test_authored_vectors(self):
        for spec in counter_cases(_sample_policy, _option, _frame):
            with self.subTest(spec["case_id"]):
                compiled = Compiler.compile_local_uid(spec["policy"], allowed_card_uids=set(spec["allowed_card_uids"]))
                self.assertTrue(compiled.accepted, compiled.error_code)
                result = Runtime.decide(compiled.policy, spec["frame"])
                self.assertEqual({"accepted": result.accepted, "error_code": result.error_code,
                                  "selected_indexes": result.selected_indexes}, spec["expected"])

    def test_base_authority_and_unknown_uid(self):
        spec = counter_cases(_sample_policy, _option, _frame)[0]
        compiled = Compiler.compile_local_uid(spec["policy"], allowed_card_uids=set(spec["allowed_card_uids"]))
        self.assertTrue(compiled.accepted, compiled.error_code)
        for kwargs in ({"mandatory_indexes": [1]}, {"terminal_indexes": [1]}, {"base_vetoed_indexes": [0]}, {"base_hard_tiers": [{"index": 0, "tier": [10]}, {"index": 1, "tier": [0]}]}):
            with self.subTest(kwargs=kwargs):
                result = Runtime.decide(compiled.policy, copy.deepcopy(spec["frame"]), **kwargs)
                self.assertTrue(result.accepted, result.error_code)
                self.assertEqual(result.selected_indexes, [1])
        bad = copy.deepcopy(spec["policy"])
        bad["rules"][0]["when"] = [{"fact": "option.card_uid", "op": "eq", "value": "UNKNOWN_001", "card_uid": None}]
        self.assertFalse(Compiler.compile_local_uid(bad, allowed_card_uids=set(spec["allowed_card_uids"])).accepted)

    def test_float_rejected_before_canonicalization(self):
        spec = counter_cases(_sample_policy, _option, _frame)[0]
        compiled = Compiler.compile_local_uid(spec["policy"], allowed_card_uids=set(spec["allowed_card_uids"]))
        self.assertTrue(compiled.accepted, compiled.error_code)
        for key in ("target_pending_damage_counters", "remaining_damage_counters"):
            bad = copy.deepcopy(spec["frame"])
            bad["options"][0][key] = 1.5
            result = Runtime.decide(compiled.policy, bad)
            self.assertFalse(result.accepted)
            self.assertEqual(result.error_code, "private_or_runtime_frame")


if __name__ == "__main__":
    unittest.main()
