from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.enum_snapshot import extract_int_enums, verify_enum_snapshot


SOURCE_LOCK = ROOT / "docs" / "ptcgdap" / "SOURCE_LOCK.json"
ENUM_SNAPSHOT = ROOT / "contracts" / "ptcgdap" / "cabt_enum_snapshot.json"
ORACLE_ROOT = Path(os.environ.get("PTCGABC_ORACLE_ROOT", ROOT.parent / "ptcgabc"))


class EnumSnapshotTests(unittest.TestCase):
    def test_snapshot_matches_locked_official_sdk_source(self) -> None:
        if not ORACLE_ROOT.is_dir():
            self.skipTest("official oracle integration requires PTCGABC_ORACLE_ROOT")
        report = verify_enum_snapshot(
            ENUM_SNAPSHOT,
            SOURCE_LOCK,
            root_overrides={"ptcgabc": ORACLE_ROOT, "ptcgdap": ROOT},
        )

        self.assertTrue(report.ok, report.to_dict())
        self.assertEqual(report.enum_count, 8)

    def test_snapshot_declares_raw_integer_forward_compatibility(self) -> None:
        snapshot = json.loads(ENUM_SNAPSHOT.read_text(encoding="utf-8"))

        self.assertEqual(snapshot["unknown_value_policy"], "preserve_raw_integer_fail_closed_contract_only")
        self.assertEqual(snapshot["append_only_warning"]["SelectContext"], True)
        self.assertEqual(snapshot["append_only_warning"]["LogType"], True)
        self.assertNotIn(14, snapshot["enums"]["AreaType"].values())

    def test_non_literal_int_enum_assignment_is_not_silently_ignored(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "api.py"
            path.write_text(
                "from enum import IntEnum\nclass OptionType(IntEnum):\n    NUMBER = 0\n    FUTURE = int(1)\n",
                encoding="utf-8",
            )

            with self.assertRaises(ValueError):
                extract_int_enums(path)

    def test_engine_only_labels_are_part_of_the_verified_contract(self) -> None:
        if not ORACLE_ROOT.is_dir():
            self.skipTest("official oracle integration requires PTCGABC_ORACLE_ROOT")
        snapshot = json.loads(ENUM_SNAPSHOT.read_text(encoding="utf-8"))
        snapshot["locked_engine_only_observations"]["AreaType"]["14"] = "WRONG_LABEL"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "snapshot.json"
            path.write_text(json.dumps(snapshot), encoding="utf-8")
            report = verify_enum_snapshot(
                path,
                SOURCE_LOCK,
                root_overrides={"ptcgabc": ORACLE_ROOT, "ptcgdap": ROOT},
            )

        self.assertFalse(report.ok)
        self.assertIn("engine_authority_metadata_mismatch", {issue.code for issue in report.issues})


if __name__ == "__main__":
    unittest.main()
