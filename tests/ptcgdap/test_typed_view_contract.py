from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from scripts.ai.ptcgdap.wire_shapes import (
    extract_typed_wire_profile,
    verify_typed_view_contract,
)


SOURCE_LOCK = ROOT / "docs" / "ptcgdap" / "SOURCE_LOCK.json"
TYPED_VIEW_PROFILE = (
    ROOT / "contracts" / "ptcgdap" / "cabt_typed_view_profile.json"
)
DEFAULT_ORACLE_ROOT = ROOT.parent / "ptcgabc"


def _official_oracle_root(test_case: unittest.TestCase) -> Path:
    configured = os.environ.get("PTCGABC_ORACLE_ROOT")
    oracle_root = Path(configured) if configured else DEFAULT_ORACLE_ROOT
    required = (
        oracle_root
        / "official_data"
        / "kaggle_bundle"
        / "sample_submission"
        / "sample_submission"
        / "cg"
        / "api.py",
        oracle_root
        / "official_data"
        / "kaggle_bundle"
        / "ptcg_engine"
        / "ptcgProgram 22"
        / "ToJson.h",
        oracle_root
        / "official_data"
        / "kaggle_bundle"
        / "ptcg_engine"
        / "ptcgProgram 22"
        / "ApiJson.h",
    )
    if not oracle_root.is_dir() or any(not path.is_file() for path in required):
        test_case.skipTest(
            "read-only ptcgabc official oracle is unavailable; set PTCGABC_ORACLE_ROOT"
        )
    return oracle_root.resolve()


def _oracle_paths(oracle_root: Path) -> tuple[Path, Path, Path]:
    bundle = oracle_root / "official_data" / "kaggle_bundle"
    return (
        bundle
        / "sample_submission"
        / "sample_submission"
        / "cg"
        / "api.py",
        bundle / "ptcg_engine" / "ptcgProgram 22" / "ToJson.h",
        bundle / "ptcg_engine" / "ptcgProgram 22" / "ApiJson.h",
    )


def _field_names(profile: dict[str, object], shape_name: str) -> list[str]:
    shapes = profile["shapes"]
    assert isinstance(shapes, dict)
    shape = shapes[shape_name]
    assert isinstance(shape, dict)
    fields = shape["fields"]
    assert isinstance(fields, list)
    return [field["name"] for field in fields]


def _field(
    profile: dict[str, object], shape_name: str, field_name: str
) -> dict[str, object]:
    shapes = profile["shapes"]
    assert isinstance(shapes, dict)
    shape = shapes[shape_name]
    assert isinstance(shape, dict)
    fields = shape["fields"]
    assert isinstance(fields, list)
    return next(field for field in fields if field["name"] == field_name)


class TypedViewProfileTests(unittest.TestCase):
    def test_profile_is_language_neutral_and_declares_quarantine_policy(self) -> None:
        profile = load_json_strict(TYPED_VIEW_PROFILE)

        self.assertIsInstance(profile, dict)
        self.assertEqual(profile["schema_version"], 1)
        self.assertEqual(profile["profile_id"], "cabt_typed_view_profile_v1")
        self.assertEqual(
            profile["policies"]["field_presence"],
            "preserve_missing_null_value",
        )
        self.assertIn("exact_integer_node_only", profile["policies"]["integer_wire_type"])
        self.assertIn("forbidden", profile["policies"]["safe_metadata_unknown_pointer"])
        self.assertEqual(
            profile["policies"]["unknown_subtree"],
            {
                "action": "quarantine_entire_subtree",
                "descend_into_unknown_object": False,
                "metadata_fields": ["pointer", "presence", "json_type"],
                "raw_value_location": "raw_payload_only",
            },
        )
        self.assertEqual(
            profile["policies"]["known_view_search_capability"],
            "exclude_search_begin_input",
        )
        self.assertEqual(
            profile["policies"]["unknown_enum"],
            "preserve_raw_integer_fail_closed",
        )
        canonical_json_v1_bytes(profile)

    def test_callback_framework_and_object_shapes_are_complete(self) -> None:
        profile = load_json_strict(TYPED_VIEW_PROFILE)

        callback = profile["callback_root"]
        self.assertEqual(callback["name"], "Callback")
        self.assertEqual(
            [field["name"] for field in callback["fields"]],
            ["select", "logs", "current", "search_begin_input"],
        )
        self.assertEqual(
            callback["known_view_fields"], ["select", "logs", "current"]
        )
        self.assertEqual(
            [field["name"] for field in profile["framework_fields"]],
            ["step", "remainingOverageTime"],
        )
        self.assertEqual(profile["framework_fields"][0]["kind"], "integer")
        self.assertEqual(profile["framework_fields"][1]["kind"], "number")
        self.assertEqual(
            [field["view_name"] for field in profile["framework_fields"]],
            ["step", "remaining_overage_time"],
        )

        self.assertEqual(_field_names(profile, "Card"), ["id", "serial", "playerIndex"])
        self.assertEqual(
            _field_names(profile, "Pokemon"),
            [
                "id",
                "serial",
                "playerIndex",
                "hp",
                "maxHp",
                "appearThisTurn",
                "energies",
                "energyCards",
                "tools",
                "preEvolution",
            ],
        )
        self.assertEqual(
            _field(profile, "Pokemon", "playerIndex")["authority"],
            "wire_only_sdk_gap",
        )
        self.assertEqual(
            _field_names(profile, "PlayerState"),
            [
                "active",
                "bench",
                "benchMax",
                "deckCount",
                "discard",
                "prize",
                "handCount",
                "hand",
                "poisoned",
                "burned",
                "asleep",
                "paralyzed",
                "confused",
            ],
        )
        self.assertEqual(
            _field_names(profile, "State"),
            [
                "turn",
                "turnActionCount",
                "yourIndex",
                "firstPlayer",
                "supporterPlayed",
                "stadiumPlayed",
                "energyAttached",
                "retreated",
                "result",
                "stadium",
                "looking",
                "players",
            ],
        )
        self.assertEqual(
            _field_names(profile, "SelectData"),
            [
                "type",
                "context",
                "minCount",
                "maxCount",
                "remainDamageCounter",
                "remainEnergyCost",
                "option",
                "deck",
                "contextCard",
                "effect",
            ],
        )

    def test_option_log_sparse_shapes_and_enum_locations_are_frozen(self) -> None:
        profile = load_json_strict(TYPED_VIEW_PROFILE)

        self.assertEqual(len(profile["option_types"]), 17)
        self.assertEqual(len(profile["option_shapes"]), 17)
        self.assertEqual(
            profile["option_shapes"]["6"],
            ["type", "area", "index", "playerIndex", "energyIndex", "count"],
        )
        self.assertEqual(
            profile["option_shapes"]["15"], ["type", "cardId", "serial"]
        )
        self.assertEqual(len(profile["log_types"]), 24)
        self.assertEqual(len(profile["log_shapes"]), 24)
        self.assertEqual(
            profile["log_shapes"]["6"],
            ["type", "playerIndex", "cardId", "serial", "fromArea", "toArea"],
        )
        self.assertEqual(
            profile["log_shapes"]["7"],
            ["type", "playerIndex", "fromArea", "toArea"],
        )
        self.assertEqual(
            profile["log_shapes"]["14"],
            [
                "type",
                "playerIndex",
                "cardId",
                "serial",
                "cardIdBefore",
                "serialBefore",
                "cardIdAfter",
                "serialAfter",
            ],
        )
        self.assertEqual(
            profile["log_shapes"]["23"], ["type", "result", "reason"]
        )
        self.assertEqual(
            profile["enum_locations"],
            [
                {"enum": "SelectType", "pattern": "/select/type"},
                {"enum": "SelectContext", "pattern": "/select/context"},
                {"enum": "OptionType", "pattern": "/select/option/*/type"},
                {"enum": "AreaType", "pattern": "/select/option/*/area"},
                {"enum": "AreaType", "pattern": "/select/option/*/inPlayArea"},
                {
                    "enum": "SpecialConditionType",
                    "pattern": "/select/option/*/specialConditionType",
                },
                {"enum": "LogType", "pattern": "/logs/*/type"},
                {"enum": "AreaType", "pattern": "/logs/*/fromArea"},
                {"enum": "AreaType", "pattern": "/logs/*/toArea"},
                {
                    "enum": "EnergyType",
                    "pattern": "/current/players/*/active/*/energies/*",
                },
                {
                    "enum": "EnergyType",
                    "pattern": "/current/players/*/bench/*/energies/*",
                },
            ],
        )


class OfficialTypedViewBindingTests(unittest.TestCase):
    def test_profile_matches_all_three_locked_sources_with_explicit_root(self) -> None:
        oracle_root = _official_oracle_root(self)

        report = verify_typed_view_contract(
            TYPED_VIEW_PROFILE,
            SOURCE_LOCK,
            root_overrides={"ptcgabc": oracle_root},
        )

        self.assertTrue(report.ok, report.to_dict())
        self.assertEqual(report.shape_count, 7)
        self.assertEqual(report.option_shape_count, 17)
        self.assertEqual(report.log_shape_count, 24)
        self.assertEqual(
            set(report.source_hashes),
            {"python_api", "observation_writer", "option_log_writer"},
        )

    def test_extraction_uses_sdk_and_both_wire_writers(self) -> None:
        oracle_root = _official_oracle_root(self)
        api_path, to_json_path, api_json_path = _oracle_paths(oracle_root)

        extracted = extract_typed_wire_profile(
            api_path, to_json_path, api_json_path
        )

        self.assertEqual(
            _field(extracted, "Pokemon", "playerIndex")["authority"],
            "wire_only_sdk_gap",
        )
        self.assertEqual(extracted["option_types"]["SPECIAL_CONDITION"], 16)
        self.assertEqual(extracted["log_types"]["RESULT"], 23)
        self.assertEqual(
            extracted["log_shapes"]["5"], ["type", "playerIndex"]
        )
        self.assertEqual(
            extracted["shapes"]["PlayerState"]["quarantined_writer_fields"],
            {"deck": "non_contract_send_deck_or_visualizer"},
        )
        self.assertEqual(
            extracted["shapes"]["State"]["quarantined_writer_fields"],
            {"lookingCount": "web_only"},
        )

    def test_contract_field_drift_is_detected(self) -> None:
        oracle_root = _official_oracle_root(self)
        profile = json.loads(TYPED_VIEW_PROFILE.read_text(encoding="utf-8"))
        profile["shapes"]["Pokemon"]["fields"] = [
            field
            for field in profile["shapes"]["Pokemon"]["fields"]
            if field["name"] != "playerIndex"
        ]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "profile.json"
            path.write_text(json.dumps(profile), encoding="utf-8")

            report = verify_typed_view_contract(
                path,
                SOURCE_LOCK,
                root_overrides={"ptcgabc": oracle_root},
            )

        self.assertFalse(report.ok)
        self.assertIn("typed_profile_mismatch", {issue.code for issue in report.issues})

    def test_each_source_hash_binding_is_strict(self) -> None:
        oracle_root = _official_oracle_root(self)
        for source_name in (
            "python_api",
            "observation_writer",
            "option_log_writer",
        ):
            with self.subTest(source=source_name):
                profile = json.loads(TYPED_VIEW_PROFILE.read_text(encoding="utf-8"))
                profile["sources"][source_name]["sha256"] = "0" * 64
                with tempfile.TemporaryDirectory() as directory:
                    path = Path(directory) / "profile.json"
                    path.write_text(json.dumps(profile), encoding="utf-8")
                    report = verify_typed_view_contract(
                        path,
                        SOURCE_LOCK,
                        root_overrides={"ptcgabc": oracle_root},
                    )

                self.assertFalse(report.ok)
                self.assertIn(
                    "source_hash_binding_mismatch",
                    {issue.code for issue in report.issues},
                )

    def test_writer_mutation_changes_extracted_contract(self) -> None:
        oracle_root = _official_oracle_root(self)
        api_path, to_json_path, api_json_path = _oracle_paths(oracle_root)
        original = extract_typed_wire_profile(api_path, to_json_path, api_json_path)
        source = to_json_path.read_text(encoding="utf-8-sig")
        mutated = source.replace(
            'j.appendCommaKeyValue("playerIndex", card.playerIndex);',
            'j.appendCommaKeyValue("futureOwner", card.playerIndex);',
            1,
        )
        self.assertNotEqual(source, mutated)

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "ToJson.h"
            path.write_text(mutated, encoding="utf-8")
            changed = extract_typed_wire_profile(api_path, path, api_json_path)

        self.assertNotEqual(changed["shapes"]["Card"], original["shapes"]["Card"])

    def test_sdk_and_log_writer_mutations_change_extracted_contract(self) -> None:
        oracle_root = _official_oracle_root(self)
        api_path, to_json_path, api_json_path = _oracle_paths(oracle_root)
        original = extract_typed_wire_profile(api_path, to_json_path, api_json_path)
        api_source = api_path.read_text(encoding="utf-8-sig")
        mutated_api = api_source.replace(
            "    playerIndex: int  # Represents which player's card.",
            "    playerIndex: bool  # Represents which player's card.",
            1,
        )
        log_source = api_json_path.read_text(encoding="utf-8-sig")
        mutated_log = log_source.replace(
            'j.appendCommaKeyValue("reason", log.param[1]);',
            'j.appendCommaKeyValue("futureReason", log.param[1]);',
            1,
        )
        self.assertNotEqual(api_source, mutated_api)
        self.assertNotEqual(log_source, mutated_log)

        with tempfile.TemporaryDirectory() as directory:
            directory_path = Path(directory)
            changed_api_path = directory_path / "api.py"
            changed_log_path = directory_path / "ApiJson.h"
            changed_api_path.write_text(mutated_api, encoding="utf-8")
            changed_log_path.write_text(mutated_log, encoding="utf-8")
            changed_api = extract_typed_wire_profile(
                changed_api_path, to_json_path, api_json_path
            )
            changed_log = extract_typed_wire_profile(
                api_path, to_json_path, changed_log_path
            )

        self.assertNotEqual(changed_api["shapes"]["Card"], original["shapes"]["Card"])
        self.assertEqual(
            changed_log["log_shapes"]["23"], ["type", "result", "futureReason"]
        )


if __name__ == "__main__":
    unittest.main()
