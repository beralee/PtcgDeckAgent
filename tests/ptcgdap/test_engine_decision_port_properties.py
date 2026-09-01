from __future__ import annotations

import unittest

from scripts.ai.ptcgdap.engine_decision_port import EngineDecisionPort


class CardRef:
    pass


def source_for(types: list[int], refs: list[object | None]):
    options = []
    for position, option_type in enumerate(types):
        if option_type == 7:
            options.append({"type": 7, "index": position})
        elif option_type == 13:
            options.append({"type": 13, "local_attack_index": position})
        else:
            options.append({"type": option_type})
    return {
        "select": {
            "type": 0, "context": 0, "minCount": 0 if not types else 1,
            "maxCount": 0 if not types else 1, "remainDamageCounter": 0,
            "remainEnergyCost": 0, "option": options, "deck": None,
            "contextCard": None, "effect": None,
        },
        "deck_cards": None, "context_card": None, "effect_card": None,
        "option_card_refs": refs, "turn_action_count": len(types),
    }


class EngineDecisionPortPropertyTests(unittest.TestCase):
    def test_deterministic_order_and_generation_sweep(self) -> None:
        shapes = [[], [3], [7, 14], [13, 3, 7, 14], [15, 7, 15]]
        for chooser in [0, 1]:
            for types in shapes:
                with self.subTest(chooser=chooser, types=types):
                    refs = [CardRef() if option_type == 15 else None for option_type in types]
                    source = source_for(types, refs)
                    port = EngineDecisionPort(9)
                    first = port.publish(source, 1, chooser)
                    second = port.publish(source, 2, chooser)
                    self.assertTrue(first.accepted and second.accepted)
                    self.assertEqual(port.rebind(first.snapshot, source)["error_code"], "snapshot_not_current")
                    rebound = port.rebind(second.snapshot, source)
                    self.assertTrue(rebound["ok"])
                    self.assertEqual([item["type"] for item in rebound["value"]["select"]["option"]], types)

    def test_all_scalar_and_reference_changes_are_detected(self) -> None:
        mutations = [
            lambda s: s["select"].__setitem__("context", 1),
            lambda s: s["select"]["option"].reverse(),
            lambda s: s.__setitem__("turn_action_count", 99),
            lambda s: s["option_card_refs"].__setitem__(0, CardRef()),
        ]
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                refs = [CardRef(), None]
                source = source_for([15, 7], refs)
                port = EngineDecisionPort(3)
                snapshot = port.publish(source, 1, 0).snapshot
                mutate(source)
                self.assertIn(port.rebind(snapshot, source)["error_code"], {"source_mutated", "reference_released"})


if __name__ == "__main__":
    unittest.main()
