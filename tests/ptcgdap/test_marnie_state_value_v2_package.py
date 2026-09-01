from __future__ import annotations

import json
import hashlib
import unittest

from scripts.ai.ptcgdap.author_strategy_package import AuthorStrategyPackageLoader
from scripts.ai.ptcgdap.state_conditioned_transaction_value import (
    StateConditionedTransactionValueV2,
)
from tools.ptcgdap.build_marnie_gift_box_state_value_v2 import (
    PACKAGE_VERSION,
    build_bytes,
)


class MarnieStateValueV2PackageTest(unittest.TestCase):
    def test_package_embeds_trained_language_neutral_model_and_v1_rollback(self) -> None:
        first = build_bytes()
        second = build_bytes()
        self.assertEqual(first, second)

        handle = AuthorStrategyPackageLoader().load_bytes(first)
        self.assertEqual(PACKAGE_VERSION, handle.package_version)
        config = json.loads(handle.payload_bytes("policy/config.json"))["values"]
        allowed_effects = set(config["turn_program_allowed_effects"].split(","))
        self.assertTrue({"draw", "disruption", "bench"}.issubset(allowed_effects))
        self.assertEqual(4, config["turn_program_semantic_guard_draw_max_own_hand"])
        self.assertEqual(4, config["turn_program_semantic_guard_disruption_max_own_hand"])
        self.assertEqual(5, config["turn_program_semantic_guard_disruption_min_opponent_hand"])
        model_bytes = handle.payload_bytes("policy/weights.bin")
        model = json.loads(model_bytes)
        self.assertEqual(
            hashlib.sha256(model_bytes).hexdigest().upper(),
            config["turn_program_conditioned_value_sha256"],
        )
        self.assertIsNone(StateConditionedTransactionValueV2.model_error(model))
        self.assertEqual(
            model["fallback_value_model"]["feature_weights_milli"]["attack_pressure_milli"],
            config["turn_program_weight_attack_pressure_milli"],
        )
        self.assertNotIn("deck_id", json.dumps(model, sort_keys=True))

        adapter = json.loads(handle.payload_bytes("policy/adapter.json"))
        reject_rules = [
            rule
            for rule in adapter["rules"]
            if rule["rule_id"] == "attack.zero-total-damage"
        ]
        self.assertEqual(1, len(reject_rules))
        self.assertIn(
            {
                "fact": "damage.option.bench_damage",
                "op": "eq",
                "value": 0,
                "card_uid": None,
            },
            reject_rules[0]["when"],
        )


if __name__ == "__main__":
    unittest.main()
