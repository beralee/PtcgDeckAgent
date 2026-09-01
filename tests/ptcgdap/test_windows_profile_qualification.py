from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tools.ptcgdap.build_windows_profile_qualification import (
    build_profile_qualification,
)


ROOT = Path(__file__).resolve().parents[2]
PROFILE_PATH = ROOT / "data/ptcgdap/author_strategy_device_acceptance_profile.json"
ALLOWED_ROOT = ROOT / ".tmp/ptcgdap_device_release"
SCRIPT_PATH = ROOT / "scripts/tools/run_ptcgdap_windows_profile_qualification.ps1"


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def _write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")


class WindowsProfileQualificationTests(unittest.TestCase):
    def setUp(self) -> None:
        ALLOWED_ROOT.mkdir(parents=True, exist_ok=True)
        self.root = Path(tempfile.mkdtemp(prefix="profile-qualification-", dir=ALLOWED_ROOT))
        self.executable = self.root / "PtcgDeckAgent.exe"
        self.executable.write_bytes(b"deterministic-test-executable")
        self.manifest = self.root / "export-manifest.json"
        _write_json(
            self.manifest,
            {
                "document_type": "author_strategy_device_export_manifest_v1",
                "schema_version": 1,
                "output_directory": str(self.root),
                "outputs": [
                    {
                        "kind": "executable",
                        "platform": "windows",
                        "path": str(self.executable),
                        "bytes": self.executable.stat().st_size,
                        "sha256": _sha256(self.executable),
                    }
                ],
                "release_target_platforms": ["windows"],
                "player_start_allowed": False,
                "production_ready": False,
            },
        )
        self.reports = [self.root / f"ui-{index:02d}.json" for index in range(1, 4)]
        for index, path in enumerate(self.reports, start=1):
            _write_json(path, self._ui_report(index))
        self.rollback = self.root / "rollback.json"
        _write_json(self.rollback, self._rollback_report())
        self.output = self.root / "qualification.json"

    def tearDown(self) -> None:
        shutil.rmtree(self.root, ignore_errors=True)

    def _ui_report(self, index: int) -> dict[str, object]:
        decision_samples = [10 + ((sample + index) % 11) for sample in range(40)]
        return {
            "document_type": "author_strategy_windows_real_input_ui_match_report_v1",
            "schema_version": 1,
            "passed": True,
            "executable": str(self.executable),
            "executable_sha256": _sha256(self.executable),
            "process": {
                "process_id": 1000 + index,
                "peak_working_set_mib": 500 + index,
            },
            "measurements": {
                "cold_start_msec": 4000 + index,
                "catalog_scan_msec": 300 + index,
                "match_load_msec": 2000 + index,
                "decision_msec": decision_samples,
            },
            "acceptance_mode": "development",
            "development_only": True,
            "device_canary": False,
            "production_ready": False,
            "a5_claimed": False,
            "real_mouse_input_proven": True,
            "real_mouse_click_count": 3,
            "network_isolation_proven": False,
            "application_network_disabled": True,
            "application_network_attempt_markers": "",
            "runtime_failure_markers": "",
            "engine_report": {
                "document_type": "author_strategy_windows_ui_match_report_v1",
                "schema_version": 1,
                "complete_match_finished": True,
                "is_clean": True,
                "dirty_reasons": [],
                "author_audit": {
                    "package_id": "ptcgdap.marnie.windows-local",
                    "package_version": "0.1.0",
                    "archive_sha256": "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E",
                    "signature_scope": "test_fixture_only",
                    "execution_trusted": False,
                    "card_id_domain": "godot_local_card_uid_v1",
                    "policy_calls": len(decision_samples),
                    "policy_successes": len(decision_samples),
                    "policy_errors": 0,
                    "invalid_outputs": 0,
                    "same_window_fallbacks": 0,
                    "classic_fallbacks": 0,
                    "engine_rejections": 0,
                    "engine_commits": len(decision_samples) - 1,
                    "external_process_attempts": 0,
                    "policy_engine_object_access": False,
                    "restricted_ir_executed": True,
                    "execution_location": "device_local",
                    "local_policy_executor_manifest_canonical_sha256": "6961EEECEEB33459002A40A52AA76AB0243871439D3FDF10B9F1F4927AB6D6E0",
                    "policy_package_manifest_canonical_sha256": "3243ABD7937B3F53D8E5D7A887FC90BFBDF9A4D94E4030A3A9BE194C82370FFC",
                },
            },
        }

    def _rollback_report(self) -> dict[str, object]:
        return {
            "document_type": "author_strategy_windows_feature_rollback_execution_v1",
            "schema_version": 1,
            "accepted": True,
            "failed_closed_before_execution": True,
            "policy_calls": 0,
            "engine_commits": 0,
            "user_packages_deleted": False,
            "device_canary_requested": False,
            "development_only": True,
            "production_rollback_claimed": False,
            "network_isolation_proven": False,
            "export": {
                "manifest_sha256": _sha256(self.manifest),
                "executable_sha256": _sha256(self.executable),
            },
        }

    def _build(self, reports: list[Path] | None = None) -> dict[str, object]:
        return build_profile_qualification(
            project_root=ROOT,
            export_manifest_path=self.manifest,
            evidence_root=self.root,
            ui_report_paths=self.reports if reports is None else reports,
            rollback_report_path=self.rollback,
            output_path=self.output,
        )

    def test_three_real_ui_matches_build_approved_non_a5_profile_report(self) -> None:
        result = self._build()
        persisted = load_json_strict(self.output)
        self.assertEqual(result, persisted)
        self.assertEqual("author_strategy_windows_profile_qualification_v1", result["document_type"])
        self.assertEqual(3, result["samples"]["cold_start_count"])
        self.assertEqual(120, result["samples"]["decision_count"])
        self.assertEqual(4003, result["measurements"]["cold_start_msec"])
        self.assertEqual(303, result["measurements"]["catalog_scan_msec"])
        self.assertEqual(2003, result["measurements"]["match_load_msec"])
        self.assertEqual(503, result["measurements"]["peak_memory_mib"])
        self.assertTrue(result["threshold_evaluation"]["all_limits_met"])
        self.assertEqual("approved", result["profile"]["approval_status"])
        self.assertFalse(result["profile"]["formal_a5_eligible"])
        self.assertEqual(
            hashlib.sha256(canonical_json_v1_bytes(load_json_strict(PROFILE_PATH))).hexdigest().upper(),
            result["profile"]["canonical_sha256"],
        )
        self.assertEqual(
            {
                "development_only": True,
                "profile_approval_granted": True,
                "formal_device_report": False,
                "os_network_isolation_proven": False,
                "production_ready": False,
                "a5_claimed": False,
            },
            result["claims"],
        )

    def test_rejects_insufficient_dirty_or_cross_executable_samples(self) -> None:
        cases: list[tuple[str, list[Path] | None, str]] = []
        cases.append(("only-two", self.reports[:2], "exactly three"))

        dirty = load_json_strict(self.reports[1])
        dirty["engine_report"]["author_audit"]["invalid_outputs"] = 1
        _write_json(self.reports[1], dirty)
        cases.append(("dirty", None, "policy accounting"))

        for name, reports, message in cases:
            with self.subTest(name=name):
                if self.output.exists():
                    self.output.unlink()
                with self.assertRaisesRegex(ValueError, message):
                    self._build(reports)
                if name == "only-two":
                    continue
                _write_json(self.reports[1], self._ui_report(2))

        drift = load_json_strict(self.reports[2])
        drift["executable_sha256"] = "A" * 64
        _write_json(self.reports[2], drift)
        with self.assertRaisesRegex(ValueError, "executable"):
            self._build()

    def test_rejects_threshold_failure_hardlink_and_output_overwrite(self) -> None:
        slow = load_json_strict(self.reports[0])
        slow["measurements"]["cold_start_msec"] = 10001
        _write_json(self.reports[0], slow)
        with self.assertRaisesRegex(ValueError, "candidate threshold"):
            self._build()

        _write_json(self.reports[0], self._ui_report(1))
        self._build()
        with self.assertRaisesRegex(FileExistsError, "overwrite"):
            self._build()

        self.output.unlink()
        hardlink = self.root / "ui-hardlink.json"
        hardlink.hardlink_to(self.reports[0])
        with self.assertRaisesRegex(ValueError, "hard-link"):
            self._build([hardlink, self.reports[1], self.reports[2]])

    def test_project_runner_uses_three_real_ui_runs_and_one_rollback(self) -> None:
        text = SCRIPT_PATH.read_text(encoding="utf-8")
        self.assertIn("run_ptcgdap_windows_ui_match.ps1", text)
        self.assertIn("run_ptcgdap_author_strategy_rollback_drill.ps1", text)
        self.assertIn("build_windows_profile_qualification.py", text)
        self.assertIn("--preflight", text)
        self.assertLess(text.index("--preflight"), text.index("ConvertFrom-Json"))
        self.assertRegex(text, r"for \(\$index = 1; \$index -le 3;")
        self.assertIn("-SkipExport", text)
        self.assertNotIn("ProductionDeviceCanary", text)
        self.assertNotIn("New-NetFirewallRule", text)
        self.assertNotIn("auditpol.exe", text)


if __name__ == "__main__":
    unittest.main()
