from __future__ import annotations

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


def _option(raw: int, marker: int = 0) -> dict:
    return {
        0: {"type": 0, "number": marker},
        1: {"type": 1},
        2: {"type": 2},
        3: {"type": 3, "area": 2, "index": marker, "playerIndex": 0},
        4: {"type": 4, "area": 4, "index": 0, "playerIndex": 0, "toolIndex": marker},
        5: {"type": 5, "area": 4, "index": 0, "playerIndex": 0, "energyIndex": marker},
        6: {"type": 6, "area": 8, "index": 0, "playerIndex": 0, "energyIndex": marker, "count": 1},
        7: {"type": 7, "index": marker},
        8: {"type": 8, "area": 2, "index": marker, "inPlayArea": 4, "inPlayIndex": 0},
        9: {"type": 9, "area": 2, "index": marker, "inPlayArea": 4, "inPlayIndex": 0},
        10: {"type": 10, "area": 2, "index": marker},
        11: {"type": 11, "area": 2, "index": marker},
        12: {"type": 12},
        13: {"type": 13, "attackId": marker + 1},
        14: {"type": 14},
        15: {"type": 15, "cardId": marker, "serial": marker},
        16: {"type": 16, "specialConditionType": marker},
    }[raw]


class UcisDeveloperSdkTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        from scripts.ai.ptcgdap.ucis_sdk import UcisDeveloperSdk

        cls.sdk = UcisDeveloperSdk.load(ROOT)

    def test_every_context_and_registered_sparse_option_parses(self) -> None:
        for context, row in self.sdk.registry.context_rows.items():
            for option_type in row.option_types:
                with self.subTest(context=context, option_type=option_type):
                    raw = self.sdk.build_scenario_window(
                        context_name=row.context_name,
                        options=[_option(option_type)],
                        min_count=0,
                        max_count=1,
                    )
                    view = self.sdk.parse_selection(raw)
                    self.assertEqual(view.context_raw, context)
                    self.assertEqual(view.options[0].option_type_raw, option_type)
                    self.assertTrue(view.public_facts["optional_zero"])

    def test_semantic_rebind_tracks_reordered_current_options_and_ordered_multi(self) -> None:
        raw = self.sdk.build_scenario_window(
            context_name="TO_HAND",
            options=[_option(3, 10), _option(3, 20), _option(3, 30)],
            min_count=2,
            max_count=3,
        )
        first = self.sdk.parse_selection(raw)
        intent = [
            first.options[2].semantic_fingerprint,
            first.options[0].semantic_fingerprint,
        ]
        reordered = self.sdk.build_scenario_window(
            context_name="TO_HAND",
            options=[_option(3, 30), _option(3, 20), _option(3, 10)],
            min_count=2,
            max_count=3,
        )
        second = self.sdk.parse_selection(reordered)
        self.assertEqual(second.rebind_semantic_fingerprints(intent), [0, 2])
        self.assertEqual(second.validate_indexes([2, 0]), [2, 0])

    def test_exact_quantity_and_public_debt_are_exposed_without_private_state(self) -> None:
        raw = self.sdk.build_scenario_window(
            context_name="DISCARD_ENERGY",
            options=[_option(6, 0), _option(6, 1), _option(6, 2)],
            min_count=2,
            max_count=2,
            remain_energy_cost=3,
        )
        raw["opponent_private_hand"] = ["secret"]
        view = self.sdk.parse_selection(raw)
        self.assertEqual(view.remain_energy_cost, 3)
        self.assertTrue(view.public_facts["exact_count_required"])
        self.assertFalse(hasattr(view, "opponent_private_hand"))
        self.assertEqual(view.indexes_where(lambda option: option.field("count") == 1), [0, 1, 2])

    def test_unknown_fields_sparse_shapes_and_invalid_indexes_fail_closed(self) -> None:
        from scripts.ai.ptcgdap.ucis_sdk import UcisSdkError

        raw = self.sdk.build_scenario_window(
            context_name="TO_ACTIVE",
            options=[_option(3)],
            min_count=1,
            max_count=1,
        )
        raw["select"]["private_ticket"] = "secret"
        with self.assertRaisesRegex(UcisSdkError, "ucis_sdk_select_fields_invalid"):
            self.sdk.parse_selection(raw)

        raw = self.sdk.build_scenario_window(
            context_name="TO_ACTIVE",
            options=[_option(3)],
            min_count=1,
            max_count=1,
        )
        raw["select"]["option"][0]["extra"] = 1
        with self.assertRaisesRegex(UcisSdkError, "ucis_sdk_sparse_option_invalid"):
            self.sdk.parse_selection(raw)

        view = self.sdk.parse_selection(
            self.sdk.build_scenario_window(
                context_name="TO_ACTIVE",
                options=[_option(3)],
                min_count=1,
                max_count=1,
            )
        )
        for invalid in ([], [0, 0], [1], ["0"]):
            with self.subTest(invalid=invalid), self.assertRaisesRegex(
                UcisSdkError, "ucis_sdk_indexes_invalid"
            ):
                view.validate_indexes(invalid)

    def test_capability_catalog_is_generation_and_hash_bound(self) -> None:
        catalog = self.sdk.capability_catalog()
        self.assertEqual(catalog["ucis_generation"], 1)
        self.assertEqual(len(catalog["primitives"]), 16)
        self.assertEqual(set(catalog["primitive_coverage"]), set(catalog["primitives"]))
        self.assertEqual(catalog["closure"]["unregistered"], 0)


if __name__ == "__main__":
    unittest.main()
