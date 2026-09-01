from __future__ import annotations

import json
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.author_strategy_package import AuthorStrategyPackageError, AuthorStrategyPackageLoader
from scripts.ai.ptcgdap.author_strategy_package_catalog import AuthorStrategyPackageCatalogOracle
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tools.ptcgdap.build_as_wp2_fixtures import render


ROOT = Path(__file__).resolve().parents[2]
FIXTURE_ROOT = ROOT / "tests/ptcgdap/fixtures/author_strategy_packages/as_wp2"
CASES_PATH = FIXTURE_ROOT / "cases.json"
VALID_PATH = FIXTURE_ROOT / "00-valid_minimal.ptcgai"
PRETTY_PATH = FIXTURE_ROOT / "01-valid_manifest_whitespace_identity.ptcgai"
INVALID_PATH = FIXTURE_ROOT / "20-payload_hash_mismatch.ptcgai"
EXPECTED_CASES_RAW_SHA256 = "94A612CE6F191223796D5E28601C8FDCEDF5BDEC55076DB43292DE03DAF30490"


class AuthorStrategyPackageCatalogTests(unittest.TestCase):
    def test_fixture_builder_is_byte_exact_and_all_python_expectations_hold(self) -> None:
        expected = render()
        self.assertEqual(40, len(expected))
        self.assertEqual(expected["cases.json"], CASES_PATH.read_bytes())
        self.assertEqual(EXPECTED_CASES_RAW_SHA256, __import__("hashlib").sha256(CASES_PATH.read_bytes()).hexdigest().upper())
        self.assertEqual(
            set(expected),
            {path.name for path in FIXTURE_ROOT.iterdir() if path.is_file()},
        )
        loader = AuthorStrategyPackageLoader()
        cases = load_json_strict(CASES_PATH)
        self.assertEqual(30, cases["case_count"])
        self.assertEqual(30, len(cases["cases"]))
        self.assertEqual(9, cases["loader_case_count"])
        self.assertEqual(9, len(cases["loader_cases"]))
        for case in cases["cases"] + cases["loader_cases"]:
            archive = (ROOT / case["archive_path"].removeprefix("res://")).read_bytes()
            if case["expected_accepted"]:
                self.assertEqual(case["expected_metadata"], loader.load_bytes(archive).to_dict(), case["case_id"])
            else:
                with self.assertRaises(AuthorStrategyPackageError, msg=case["case_id"]) as captured:
                    loader.load_bytes(archive)
                self.assertEqual(case["expected_error_code"], captured.exception.code, case["case_id"])

    def test_python_catalog_oracle_deduplicates_exact_bytes_and_excludes_invalid(self) -> None:
        oracle = AuthorStrategyPackageCatalogOracle()
        valid = VALID_PATH.read_bytes()
        report = oracle.build(
            [
                {"install_source": "built_in", "location_id": "a.ptcgai", "archive_bytes": valid},
                {"install_source": "user", "location_id": "b.ptcgai", "archive_bytes": valid},
                {"install_source": "user", "location_id": "bad.ptcgai", "archive_bytes": INVALID_PATH.read_bytes()},
            ]
        )
        self.assertEqual([], report["ready_records"])
        self.assertEqual(1, len(report["metadata_records"]))
        record = report["metadata_records"][0]
        self.assertEqual("metadata_only", record["status"])
        self.assertEqual(["built_in", "user"], record["install_sources"])
        self.assertFalse(record["execution_trusted"])
        self.assertFalse(record["match_authority"])
        self.assertEqual(["package_file_hash_mismatch"], [item["error_code"] for item in report["diagnostics"]])
        record["author"]["display_name"] = "mutated"
        fresh = oracle.build([{"install_source": "built_in", "location_id": "a.ptcgai", "archive_bytes": valid}])
        self.assertEqual("Fixture Author", fresh["metadata_records"][0]["author"]["display_name"])

    def test_same_identity_different_archive_hash_fails_closed(self) -> None:
        report = AuthorStrategyPackageCatalogOracle().build(
            [
                {"install_source": "built_in", "location_id": "a.ptcgai", "archive_bytes": VALID_PATH.read_bytes()},
                {"install_source": "user", "location_id": "b.ptcgai", "archive_bytes": PRETTY_PATH.read_bytes()},
            ]
        )
        self.assertEqual([], report["metadata_records"])
        self.assertEqual([], report["ready_records"])
        self.assertEqual(["package_identity_conflict"], [item["error_code"] for item in report["diagnostics"]])

    def test_project_autoload_and_every_export_preset_include_fixed_contracts(self) -> None:
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        self.assertEqual(
            1,
            project.count('AuthorStrategyPackageCatalog="*res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd"'),
        )
        presets = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        include_lines = [line for line in presets.splitlines() if line.startswith("include_filter=")]
        self.assertEqual(7, len(include_lines))
        self.assertTrue(all("contracts/ptcgdap/**" in line for line in include_lines))
        exclude_lines = [line for line in presets.splitlines() if line.startswith("exclude_filter=")]
        self.assertTrue(all("tests/**" in line and "artifacts/**" in line and "tools/**" in line for line in exclude_lines))

    def test_godot_catalog_is_fixed_root_metadata_only_and_has_no_live_or_external_capability(self) -> None:
        catalog_path = ROOT / "scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd"
        loader_path = ROOT / "scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd"
        installer_path = ROOT / "scripts/ai/ptcgdap/packages/AuthorStrategyPackageInstaller.gd"
        catalog = catalog_path.read_text(encoding="utf-8")
        installer = installer_path.read_text(encoding="utf-8")
        combined = catalog + loader_path.read_text(encoding="utf-8") + installer
        self.assertIn('const BUILT_IN_ROOT := "res://data/ptcgdap/author_strategy_packages"', catalog)
        self.assertIn('const USER_ROOT := "user://ptcgdap/author_strategy_packages"', catalog)
        self.assertNotIn("root_override", catalog)
        for forbidden in ("OS.execute", "HTTPClient", "HTTPRequest", "TCPServer", "PacketPeerUDP", "load_resource_pack", "BattleScene", "AIOpponent", "GameManager"):
            self.assertNotIn(forbidden, combined)
        self.assertIn("_ready_records", catalog)
        self.assertIn("_release_gate.evaluate_installed_package(metadata)", catalog)
        self.assertIn('"match_authority": false', catalog)
        self.assertIn('"execution_authority": false', catalog)
        self.assertIn("func remove_package(", catalog)
        self.assertIn("func remove_user_package(", catalog)
        self.assertIn("func remove(", installer)
        self.assertIn('const REMOVE_TEMP_PREFIX := ".ptcgdap-author-remove-"', installer)
        self.assertIn("_find_user_remove_targets", installer)
        self.assertNotIn("root_override", installer)
        removal_store = (ROOT / "scripts/ai/ptcgdap/packages/AuthorStrategyPackageRemovalStore.gd").read_text(encoding="utf-8")
        self.assertIn('const DEFAULT_PATH := "user://ptcgdap/author_strategy_removed.json"', removal_store)
        self.assertNotIn("root_override", removal_store)
        match_start = catalog.index("func request_match_handle(")
        match_end = catalog.index("\nfunc audit_snapshot()", match_start)
        match_api = catalog[match_start:match_end]
        startup_catalog = catalog[:match_start] + catalog[match_end:]
        self.assertNotIn("payloads", startup_catalog)
        self.assertIn("inspect_match_bytes", match_api)
        self.assertIn('inspected.get("payloads", {})', match_api)

    def test_as_wp1_contract_bundle_remains_byte_exact(self) -> None:
        bundle = load_json_strict(ROOT / "contracts/ptcgdap/author_strategy_package_bundle.json")
        self.assertEqual(
            "B416F2CBA2795B62126B6EF7B5F07A9000E84D5FA1DF62C1753CADC9E82E106B",
            __import__("hashlib").sha256(canonical_json_v1_bytes(bundle)).hexdigest().upper(),
        )


if __name__ == "__main__":
    unittest.main()
