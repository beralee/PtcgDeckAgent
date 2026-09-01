from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from scripts.ai.ptcgdap.source_lock import load_json_strict
from tools.ptcgdap.author_strategy_developer import (
    DEFAULT_TEMPLATE_PACKAGE,
    DeveloperToolError,
    _adjudication_report,
    build_development_package,
    install_development_package,
    scaffold_workspace,
    simulate_public_window,
    validate_development_package,
)


ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / "tools/ptcgdap/author_strategy_developer.py"
GUIDE = ROOT / "docs/ptcgdap/10-author-strategy-developer-guide.md"


class AuthorStrategyDeveloperToolTests(unittest.TestCase):
    def test_adjudication_report_handles_legal_optional_zero_without_calling_it_fallback(self) -> None:
        report = _adjudication_report(
            {
                "terminal_indexes": [],
                "mandatory_indexes": [],
                "base_hard_tiers": [],
                "base_vetoed_indexes": [],
            },
            option_count=0,
            proposals=[],
            selected_indexes=[],
        )
        self.assertEqual("optional_zero", report["selected_source"])
        self.assertFalse(report["deterministic_fallback_used"])
        self.assertEqual([], report["candidates"])

    def test_scaffold_build_validate_is_deterministic_and_needs_no_author_key(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / ".tmp") as raw:
            workspace = Path(raw) / "workspace"
            scaffold = scaffold_workspace(workspace)
            source = workspace / "package"
            output = workspace / "build/marnie-dev.ptcgai"

            self.assertEqual("scaffolded", scaffold["status"])
            self.assertTrue((source / "strategy_package.json").is_file())
            self.assertFalse((source / "files.sha256.json").exists())
            self.assertFalse((source / "signature.json").exists())
            self.assertFalse(any("private_key" in path.name for path in workspace.rglob("*")))

            built = build_development_package(source, output)
            validated = validate_development_package(output)
            self.assertEqual(DEFAULT_TEMPLATE_PACKAGE.read_bytes(), output.read_bytes())
            self.assertEqual("built", built["status"])
            self.assertEqual("valid", validated["status"])
            self.assertEqual("test_fixture_trusted", validated["signature_status"])
            self.assertFalse(validated["execution_trusted"])
            self.assertFalse(validated["production_ready"])
            self.assertEqual(60, validated["deck_card_count"])
            self.assertEqual(28, validated["deck_unique_printing_count"])

    def test_install_places_package_in_fixed_user_catalog_without_promoting_trust(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / ".tmp") as raw:
            root = Path(raw)
            workspace = root / "workspace"
            scaffold_workspace(workspace)
            package = workspace / "build/marnie-dev.ptcgai"
            build_development_package(workspace / "package", package)

            installed = install_development_package(package, appdata_root=root / "appdata")
            destination = Path(installed["installed_path"])
            expected_root = (
                root
                / "appdata/Godot/app_userdata/PtcgDeckAgent/ptcgdap/author_strategy_packages"
            )
            self.assertEqual(expected_root.resolve(), destination.parent.resolve())
            self.assertEqual(package.read_bytes(), destination.read_bytes())
            self.assertEqual("installed", installed["status"])
            self.assertTrue(installed["catalog_discoverable"])
            self.assertEqual("metadata_only", installed["catalog_status"])
            self.assertFalse(installed["player_start_allowed"])
            self.assertFalse(installed["execution_trusted"])
            self.assertFalse(installed["production_ready"])
            self.assertTrue(installed["catalog_reload_required"])

            repeated = install_development_package(package, appdata_root=root / "appdata")
            self.assertTrue(repeated["already_installed"])
            self.assertEqual(destination, Path(repeated["installed_path"]))

            conflicting_workspace = root / "conflicting-workspace"
            scaffold_workspace(conflicting_workspace)
            readme = conflicting_workspace / "package/README.md"
            readme.write_text(readme.read_text(encoding="utf-8") + "\nconflict\n", encoding="utf-8")
            conflicting_package = conflicting_workspace / "build/marnie-dev-conflict.ptcgai"
            build_development_package(conflicting_workspace / "package", conflicting_package)
            with self.assertRaises(DeveloperToolError) as conflict:
                install_development_package(conflicting_package, appdata_root=root / "appdata")
            self.assertEqual("developer_install_identity_conflict", conflict.exception.code)

    def test_public_window_simulation_uses_real_host_and_reports_matched_rule(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / ".tmp") as raw:
            workspace = Path(raw) / "workspace"
            scaffold_workspace(workspace)
            package = workspace / "build/marnie-dev.ptcgai"
            build_development_package(workspace / "package", package)

            scenario = workspace / "scenarios/morgrem-evolve.json"
            value = load_json_strict(scenario)
            self.assertNotIn("context_hash", json.dumps(value, sort_keys=True))
            self.assertNotIn("window_id", json.dumps(value, sort_keys=True))

            report = simulate_public_window(package, scenario)
            self.assertEqual("passed", report["status"])
            self.assertEqual("", report["error_code"])
            self.assertEqual([1], report["decision"]["selected_indexes"])
            self.assertEqual("policy_allowed", report["frontier"]["decision_state"])
            self.assertEqual(
                ["marnie.morgrem.evolve"],
                [row["rule_id"] for row in report["adapter"]["matched_rules"]],
            )
            self.assertEqual("adapter_proposal", report["adjudication"]["selected_source"])
            self.assertTrue(report["adjudication"]["adapter_preference_applied"])
            self.assertFalse(report["adjudication"]["deterministic_fallback_used"])
            self.assertEqual([], report["adjudication"]["candidates"][1]["elimination_reasons"])
            self.assertTrue(report["claims"]["public_only"])
            self.assertFalse(report["claims"]["engine_execution"])
            self.assertFalse(report["claims"]["production_authority"])
            serialized = json.dumps(report, sort_keys=True)
            for forbidden in (
                "raw_observation",
                "search_begin_input",
                "private_key",
                "GameState",
                "BattleScene",
                "object_ref",
            ):
                self.assertNotIn(forbidden, serialized)

    def test_expectation_mismatch_is_a_clean_non_authoritative_failure(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / ".tmp") as raw:
            workspace = Path(raw) / "workspace"
            scaffold_workspace(workspace)
            package = workspace / "build/marnie-dev.ptcgai"
            build_development_package(workspace / "package", package)
            scenario = workspace / "scenarios/morgrem-evolve.json"
            value = load_json_strict(scenario)
            value["expected_selected_indexes"] = [0]
            scenario.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

            report = simulate_public_window(package, scenario)
            self.assertEqual("failed", report["status"])
            self.assertEqual("simulation_expectation_failed", report["error_code"])
            self.assertEqual([0], report["expectation"]["selected_indexes"])
            self.assertEqual([1], report["decision"]["selected_indexes"])
            self.assertFalse(report["claims"]["authoritative"])

    def test_unknown_uid_and_output_overwrite_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / ".tmp") as raw:
            workspace = Path(raw) / "workspace"
            scaffold_workspace(workspace)
            with self.assertRaises(DeveloperToolError) as duplicate_scaffold:
                scaffold_workspace(workspace)
            self.assertEqual("developer_output_exists", duplicate_scaffold.exception.code)

            package = workspace / "build/marnie-dev.ptcgai"
            build_development_package(workspace / "package", package)
            with self.assertRaises(DeveloperToolError) as duplicate_build:
                build_development_package(workspace / "package", package)
            self.assertEqual("developer_output_exists", duplicate_build.exception.code)

            scenario = workspace / "scenarios/morgrem-evolve.json"
            value = load_json_strict(scenario)
            value["local_uid_bindings"]["options"][1]["local_card_uid"] = "CSV999C_999"
            scenario.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            with self.assertRaises(DeveloperToolError) as invalid:
                simulate_public_window(package, scenario)
            self.assertEqual("invalid_local_uid_public_context", invalid.exception.code)

    def test_missing_template_and_malformed_scenario_return_stable_codes(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / ".tmp") as raw:
            root = Path(raw)
            with self.assertRaises(DeveloperToolError) as missing:
                scaffold_workspace(
                    root / "workspace",
                    template_package=root / "missing.ptcgai",
                )
            self.assertEqual("developer_template_invalid", missing.exception.code)

            workspace = root / "valid-workspace"
            scaffold_workspace(workspace)
            package = workspace / "build/marnie-dev.ptcgai"
            build_development_package(workspace / "package", package)
            malformed = workspace / "scenarios/malformed.json"
            malformed.write_text('{"schema_version":1,"unknown":true}\n', encoding="utf-8")
            with self.assertRaises(DeveloperToolError) as scenario:
                simulate_public_window(package, malformed)
            self.assertEqual("developer_scenario_invalid", scenario.exception.code)

            unhashable = workspace / "scenarios/unhashable-index.json"
            value = load_json_strict(workspace / "scenarios/morgrem-evolve.json")
            value["expected_selected_indexes"] = [{}]
            unhashable.write_text(
                json.dumps(value, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
            with self.assertRaises(DeveloperToolError) as invalid_index:
                simulate_public_window(package, unhashable)
            self.assertEqual("developer_scenario_invalid", invalid_index.exception.code)

    def test_cli_and_guide_expose_one_copyable_happy_path(self) -> None:
        self.assertTrue(TOOL.is_file())
        self.assertTrue(GUIDE.is_file())
        guide = GUIDE.read_text(encoding="utf-8")
        for command in ("scaffold", "build", "validate", "simulate", "install"):
            self.assertIn(f"author_strategy_developer.py {command}", guide)
        result = subprocess.run(
            [sys.executable, str(TOOL), "--help"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        for command in ("scaffold", "build", "validate", "simulate", "install"):
            self.assertIn(command, result.stdout)


if __name__ == "__main__":
    unittest.main()
