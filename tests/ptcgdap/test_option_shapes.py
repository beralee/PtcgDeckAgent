from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.option_shapes import (
    extract_option_sparse_shapes,
    verify_option_shape_contract,
)


SOURCE_LOCK = ROOT / "docs" / "ptcgdap" / "SOURCE_LOCK.json"
OPTION_SHAPES = ROOT / "contracts" / "ptcgdap" / "cabt_option_sparse_shapes.json"
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
        / "ApiJson.h",
    )
    if not oracle_root.is_dir() or any(not path.is_file() for path in required):
        test_case.skipTest(
            "read-only ptcgabc official oracle is unavailable; set PTCGABC_ORACLE_ROOT"
        )
    return oracle_root.resolve()


class OfficialOptionShapeBindingTests(unittest.TestCase):
    def test_contract_matches_locked_sources_with_explicit_root_override(self) -> None:
        oracle_root = _official_oracle_root(self)

        report = verify_option_shape_contract(
            OPTION_SHAPES,
            SOURCE_LOCK,
            root_overrides={"ptcgabc": oracle_root},
        )

        self.assertTrue(report.ok, report.to_dict())
        self.assertEqual(report.option_type_count, 17)
        self.assertEqual(report.shape_count, 17)

    def test_extraction_binds_ordinals_to_ordered_sparse_fields(self) -> None:
        oracle_root = _official_oracle_root(self)
        api_path = (
            oracle_root
            / "official_data"
            / "kaggle_bundle"
            / "sample_submission"
            / "sample_submission"
            / "cg"
            / "api.py"
        )
        api_json_path = (
            oracle_root
            / "official_data"
            / "kaggle_bundle"
            / "ptcg_engine"
            / "ptcgProgram 22"
            / "ApiJson.h"
        )

        option_types, shapes = extract_option_sparse_shapes(api_path, api_json_path)

        self.assertEqual(option_types["ENERGY"], 6)
        self.assertEqual(
            shapes["6"],
            ["type", "area", "index", "playerIndex", "energyIndex", "count"],
        )
        self.assertEqual(shapes["15"], ["type", "cardId", "serial"])
        self.assertEqual(shapes["16"], ["type", "specialConditionType"])

    def test_contract_shape_drift_fails_closed(self) -> None:
        oracle_root = _official_oracle_root(self)
        contract = json.loads(OPTION_SHAPES.read_text(encoding="utf-8"))
        contract["shapes"]["6"] = [
            "type",
            "area",
            "index",
            "playerIndex",
            "count",
            "energyIndex",
        ]
        with tempfile.TemporaryDirectory() as directory:
            drifted_contract = Path(directory) / "cabt_option_sparse_shapes.json"
            drifted_contract.write_text(
                json.dumps(contract, ensure_ascii=False), encoding="utf-8"
            )

            report = verify_option_shape_contract(
                drifted_contract,
                SOURCE_LOCK,
                root_overrides={"ptcgabc": oracle_root},
            )

        self.assertFalse(report.ok)
        self.assertIn("option_shape_mismatch", {issue.code for issue in report.issues})

    def test_contract_ordinal_drift_is_detected_even_for_equal_shapes(self) -> None:
        oracle_root = _official_oracle_root(self)
        contract = json.loads(OPTION_SHAPES.read_text(encoding="utf-8"))
        contract["option_types"]["YES"] = 2
        contract["option_types"]["NO"] = 1
        with tempfile.TemporaryDirectory() as directory:
            drifted_contract = Path(directory) / "cabt_option_sparse_shapes.json"
            drifted_contract.write_text(
                json.dumps(contract, ensure_ascii=False), encoding="utf-8"
            )

            report = verify_option_shape_contract(
                drifted_contract,
                SOURCE_LOCK,
                root_overrides={"ptcgabc": oracle_root},
            )

        self.assertFalse(report.ok)
        self.assertIn(
            "option_type_ordinal_mismatch", {issue.code for issue in report.issues}
        )

    def test_contract_source_hash_binding_is_strict(self) -> None:
        oracle_root = _official_oracle_root(self)
        contract = json.loads(OPTION_SHAPES.read_text(encoding="utf-8"))
        contract["writer_source_sha256"] = "0" * 64
        with tempfile.TemporaryDirectory() as directory:
            drifted_contract = Path(directory) / "cabt_option_sparse_shapes.json"
            drifted_contract.write_text(
                json.dumps(contract, ensure_ascii=False), encoding="utf-8"
            )

            report = verify_option_shape_contract(
                drifted_contract,
                SOURCE_LOCK,
                root_overrides={"ptcgabc": oracle_root},
            )

        self.assertFalse(report.ok)
        self.assertIn(
            "source_hash_binding_mismatch", {issue.code for issue in report.issues}
        )

    def test_writer_extraction_rejects_numeric_label_and_conditional_field_drift(self) -> None:
        oracle_root = _official_oracle_root(self)
        api_path = (
            oracle_root
            / "official_data"
            / "kaggle_bundle"
            / "sample_submission"
            / "sample_submission"
            / "cg"
            / "api.py"
        )
        writer_path = (
            oracle_root
            / "official_data"
            / "kaggle_bundle"
            / "ptcg_engine"
            / "ptcgProgram 22"
            / "ApiJson.h"
        )
        source = writer_path.read_text(encoding="utf-8-sig")
        mutations = {
            "numeric_type": source.replace("j.append((int)option.type);", "j.append(0);", 1),
            "web_label": source.replace('j.appendDoubleQuote("Yes");', 'j.appendDoubleQuote("No");', 1),
            "conditional_field": source.replace(
                'j.appendCommaKeyValue("number", option.param0);',
                'if (option.param0) { j.appendCommaKeyValue("number", option.param0); }',
                1,
            ),
        }
        for name, mutated in mutations.items():
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                drifted_writer = Path(directory) / "ApiJson.h"
                drifted_writer.write_text(mutated, encoding="utf-8")
                with self.assertRaises(ValueError):
                    extract_option_sparse_shapes(api_path, drifted_writer)


if __name__ == "__main__":
    unittest.main()
