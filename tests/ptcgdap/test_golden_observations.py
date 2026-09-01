from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.fixture_contract import load_public_fixture


MANIFEST = ROOT / "tests" / "ptcgdap" / "fixtures" / "fixtures_manifest.json"
OPTION_SHAPES = ROOT / "contracts" / "ptcgdap" / "cabt_option_sparse_shapes.json"
ENUM_SNAPSHOT = ROOT / "contracts" / "ptcgdap" / "cabt_enum_snapshot.json"
FIXTURE_CATALOG_CANONICAL_SHA256 = "A210E518F5D045F718F66A1FD92925D43B5C567C307EBBC1DF795F993CD1A658"


def _load(fixture_id: str) -> dict:
    return load_public_fixture(
        MANIFEST,
        fixture_id,
        expected_catalog_canonical_sha256=FIXTURE_CATALOG_CANONICAL_SHA256,
    )


class GoldenObservationTests(unittest.TestCase):
    def test_initial_callback_preserves_null_and_empty_distinctions(self) -> None:
        observation = _load("initial_callback")

        self.assertIsNone(observation["select"])
        self.assertEqual(observation["logs"], [])
        self.assertIsNone(observation["current"])
        self.assertIsNone(observation["search_begin_input"])
        self.assertEqual(observation["step"], 0)

    def test_optional_zero_exposes_deck_only_through_select_capability(self) -> None:
        observation = _load("optional_zero_deck_search")
        selection = observation["select"]

        self.assertEqual(selection["minCount"], 0)
        self.assertEqual(selection["maxCount"], 1)
        self.assertEqual(len(selection["deck"]), 46)
        self.assertTrue(all("deck" not in player for player in observation["current"]["players"]))
        self.assertIsNone(observation["current"]["players"][1]["hand"])
        self.assertTrue(
            all(
                card is None
                for player in observation["current"]["players"]
                for card in player["prize"]
            )
        )

    def test_missing_framework_step_is_not_normalized_to_null(self) -> None:
        observation = _load("normal_multi_select")

        self.assertNotIn("step", observation)
        self.assertIn("remainingOverageTime", observation)
        self.assertEqual(observation["select"]["minCount"], 2)
        self.assertEqual(observation["select"]["maxCount"], 2)

    def test_ordered_skill_options_retain_official_sequence(self) -> None:
        observation = _load("ordered_skill_multi_select")

        self.assertEqual(observation["select"]["type"], 5)
        self.assertEqual(observation["select"]["context"], 34)
        self.assertEqual(
            [option["serial"] for option in observation["select"]["option"]],
            [115, 116],
        )

    def test_engine_only_area_value_is_not_mislabeled_as_official_sdk_enum(self) -> None:
        observation = _load("engine_only_area_log")
        snapshot = json.loads(ENUM_SNAPSHOT.read_text(encoding="utf-8"))

        self.assertIn(14, [log.get("toArea") for log in observation["logs"]])
        self.assertNotIn(14, snapshot["enums"]["AreaType"].values())
        self.assertEqual(snapshot["locked_engine_only_observations"]["AreaType"]["14"], "DECK_BOTTOM_INTERNAL")

    def test_unknown_fields_and_enum_integers_remain_exact(self) -> None:
        observation = _load("unknown_additive_and_enum")

        self.assertEqual(observation["futureHostField"]["nested"], [1, None, {"keep": "exact"}])
        self.assertEqual(observation["select"]["type"], 99)
        self.assertEqual(observation["select"]["context"], 777)
        self.assertEqual(observation["select"]["option"][0]["type"], 901)
        self.assertEqual(observation["logs"][0]["type"], 999)

        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        metadata = next(item for item in manifest["fixtures"] if item["id"] == "unknown_additive_and_enum")
        self.assertIn("fail_closed_contract_only", metadata["covers"])
        self.assertEqual(
            metadata["expected"]["implementation_status"],
            "not_implemented_until_p1_wp2_wp3",
        )

    def test_live_fixture_options_match_locked_sparse_key_shapes(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        shapes = json.loads(OPTION_SHAPES.read_text(encoding="utf-8"))["shapes"]
        for fixture in manifest["fixtures"]:
            if fixture["classification"] != "public_agent_observation":
                continue
            observation = _load(fixture["id"])
            selection = observation.get("select")
            if not selection:
                continue
            for option in selection["option"]:
                with self.subTest(fixture=fixture["id"], option=option):
                    self.assertEqual(set(option), set(shapes[str(option["type"])]))

    def test_no_real_search_token_is_persisted(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        for fixture in manifest["fixtures"]:
            if fixture["classification"] not in {
                "public_agent_observation",
                "synthetic_forward_compat_observation",
            }:
                continue
            observation = _load(fixture["id"])
            self.assertIsNone(observation["search_begin_input"])


if __name__ == "__main__":
    unittest.main()
