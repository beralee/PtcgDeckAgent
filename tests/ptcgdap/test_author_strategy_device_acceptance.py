from __future__ import annotations

import copy
import hashlib
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.author_strategy_release import evaluate_device_report
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
PROFILE_PATH = ROOT / "data/ptcgdap/author_strategy_device_acceptance_profile.json"
SCHEMA_PATH = ROOT / "contracts/ptcgdap/author_strategy_release.schema.json"


def canonical_sha(value: object) -> str:
    return hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper()


def good_report(platform: str, profile: dict[str, object] | None = None) -> dict[str, object]:
    bound_profile = load_json_strict(PROFILE_PATH) if profile is None else profile
    return {
        "document_type": "author_strategy_device_report_v1",
        "schema_version": 1,
        "profile_id": bound_profile["profile_id"],
        "platform": platform,
        "architecture": "x86_64" if platform == "windows" else "arm64-v8a",
        "offline": {
            "network_blocked": True,
            "complete_match_finished": True,
            "remote_inference_attempts": 0,
            "dynamic_download_attempts": 0,
        },
        "runtime": {
            "system_python_required": False,
            "sidecar_processes": [],
            "external_compute_required": False,
        },
        "samples": {
            "cold_start_msec": [80, 90, 100],
            "decision_msec": [10] * 100,
        },
        "measurements": {
            "cold_start_msec": 100,
            "catalog_scan_msec": 50,
            "match_load_msec": 100,
            "decision_p95_msec": 10,
            "peak_memory_mib": 100,
            "package_mib": 100,
            "thermal_status_max": 1 if platform == "android" else None,
            "battery_drain_percent_per_hour": 1 if platform == "android" else None,
        },
        "rollback": {
            "mode_disabled": True,
            "user_packages_preserved": True,
        },
        "evidence": {
            "profile_canonical_sha256": canonical_sha(bound_profile),
            "export_manifest_sha256": "A" * 64,
            "network_audit_sha256": "B" * 64,
            "process_audit_sha256": "C" * 64,
            "full_match_audit_sha256": "D" * 64,
            "rollback_report_sha256": "E" * 64,
        },
    }


def good_provisional_probe() -> dict[str, object]:
    sample = {
        "index": 1,
        "elapsed_msec": 100,
        "exit_code": 0,
        "peak_working_set_mib": 50,
        "stdout_sha256": "E" * 64,
        "stderr_sha256": "F" * 64,
    }
    return {
        "document_type": "author_strategy_windows_provisional_probe_v1",
        "schema_version": 1,
        "generated_at": "2026-08-13T00:00:00.0000000Z",
        "formal_device_report": False,
        "a5_claimed": False,
        "profile": {
            "path": "data/ptcgdap/author_strategy_device_acceptance_profile.json",
            "profile_id": "ptcgdap-device-acceptance-candidate-v1",
            "approval_status": "proposed",
            "formal_a5_eligible": False,
            "raw_sha256": "A" * 64,
            "canonical_sha256": "B" * 64,
        },
        "export": {
            "manifest_path": "C:\\probe\\export-manifest.json",
            "manifest_sha256": "C" * 64,
            "output_directory": "C:\\probe",
            "verified_outputs": [
                {
                    "kind": "executable",
                    "platform": "windows",
                    "path": "C:\\probe\\PtcgDeckAgent.exe",
                    "bytes": 1,
                    "sha256": "D" * 64,
                }
            ],
        },
        "host": {
            "os_caption": "Microsoft Windows 11 Pro",
            "os_version": "10.0.26200",
            "os_build": "26200",
            "architecture": "x86_64",
            "processor_name": "CPU",
            "logical_processor_count": 32,
            "total_physical_memory_mib": 65536,
        },
        "cold_start_probe": {
            "method": "wall_clock_exported_executable_headless_quit_after_one_frame",
            "required_samples": 3,
            "sample_count": 3,
            "samples": [{**sample, "index": index} for index in range(1, 4)],
            "max_elapsed_msec": 100,
        },
        "measured": {
            "package_basis": "standalone_executable",
            "package_mib": 1,
        },
        "unmeasured_gates": [
            "catalog_scan_msec",
            "match_load_msec",
            "decision_samples_minimum",
            "network_blocked",
            "runtime_process_isolation",
            "complete_match_finished",
            "rollback",
        ],
        "limitations": ["Provisional probe only; formal A5 is not claimed."],
    }


class AuthorStrategyDeviceAcceptanceTests(unittest.TestCase):
    def test_proposed_profile_cannot_emit_formal_a5_acceptance(self) -> None:
        profile = copy.deepcopy(load_json_strict(PROFILE_PATH))
        profile["approval_status"] = "proposed"
        profile["formal_a5_eligible"] = False
        profile["measurement_method"]["airplane_or_os_block_required"] = True
        result = evaluate_device_report(profile, good_report("windows", profile))
        self.assertFalse(result["accepted"])
        self.assertEqual("device_profile_not_approved", result["error_code"])

    def test_fixed_profile_is_approved_but_does_not_claim_a5_or_os_isolation(self) -> None:
        profile = load_json_strict(PROFILE_PATH)
        self.assertEqual("approved", profile["approval_status"])
        self.assertFalse(profile["formal_a5_eligible"])
        self.assertFalse(profile["measurement_method"]["airplane_or_os_block_required"])

    def test_approved_profile_accepts_bounded_windows_and_defers_android(self) -> None:
        profile = copy.deepcopy(load_json_strict(PROFILE_PATH))
        profile["approval_status"] = "approved"
        profile["formal_a5_eligible"] = True
        result = evaluate_device_report(profile, good_report("windows", profile))
        self.assertTrue(result["accepted"], result)
        self.assertEqual("", result["error_code"])
        android = evaluate_device_report(profile, good_report("android", profile))
        self.assertFalse(android["accepted"], android)
        self.assertEqual("device_report_invalid", android["error_code"])

    def test_offline_external_runtime_resource_and_rollback_failures_are_stable(self) -> None:
        profile = copy.deepcopy(load_json_strict(PROFILE_PATH))
        profile["approval_status"] = "approved"
        profile["formal_a5_eligible"] = True
        cases = []
        report = good_report("windows", profile)
        report["offline"]["network_blocked"] = False
        cases.append((report, "device_network_not_blocked"))
        report = good_report("windows", profile)
        report["runtime"]["system_python_required"] = True
        cases.append((report, "device_external_runtime_detected"))
        report = good_report("windows", profile)
        report["measurements"]["decision_p95_msec"] = 999999
        report["samples"]["decision_msec"] = [999999] * 100
        cases.append((report, "device_resource_limit_exceeded"))
        report = good_report("windows", profile)
        report["rollback"]["user_packages_preserved"] = False
        cases.append((report, "device_rollback_invalid"))
        for report, error_code in cases:
            with self.subTest(error_code=error_code):
                result = evaluate_device_report(profile, report)
                self.assertFalse(result["accepted"])
                self.assertEqual(error_code, result["error_code"])

    def test_formal_report_requires_exact_profile_samples_measurements_and_evidence(self) -> None:
        profile = copy.deepcopy(load_json_strict(PROFILE_PATH))
        profile["approval_status"] = "approved"
        profile["formal_a5_eligible"] = True
        cases = []

        report = good_report("windows", profile)
        report["profile_id"] = "wrong-profile"
        cases.append((report, "device_report_profile_mismatch"))
        report = good_report("windows", profile)
        report["evidence"]["profile_canonical_sha256"] = "F" * 64
        cases.append((report, "device_report_profile_mismatch"))
        report = good_report("windows", profile)
        report["samples"]["cold_start_msec"] = [100, 100]
        cases.append((report, "device_sample_count_insufficient"))
        report = good_report("windows", profile)
        report["samples"]["decision_msec"] = [10] * 99
        cases.append((report, "device_sample_count_insufficient"))
        report = good_report("windows", profile)
        report["measurements"]["decision_p95_msec"] = 11
        cases.append((report, "device_measurement_mismatch"))
        report = good_report("windows", profile)
        report["evidence"]["network_audit_sha256"] = "lowercase"
        cases.append((report, "device_evidence_invalid"))
        report = good_report("windows", profile)
        report["unexpected"] = True
        cases.append((report, "device_report_invalid"))

        for report, error_code in cases:
            with self.subTest(error_code=error_code):
                result = evaluate_device_report(profile, report)
                self.assertFalse(result["accepted"], result)
                self.assertEqual(error_code, result["error_code"])

    def test_formal_report_shape_is_closed_in_release_schema(self) -> None:
        profile = copy.deepcopy(load_json_strict(PROFILE_PATH))
        profile["approval_status"] = "approved"
        profile["formal_a5_eligible"] = True
        schema = load_json_strict(SCHEMA_PATH)
        report = good_report("windows", profile)
        Draft202012Validator(schema).validate(report)
        report["unexpected"] = True
        self.assertTrue(list(Draft202012Validator(schema).iter_errors(report)))

    def test_windows_provisional_probe_has_a_closed_non_a5_schema(self) -> None:
        schema = load_json_strict(SCHEMA_PATH)
        probe = good_provisional_probe()
        Draft202012Validator(schema).validate(probe)
        probe["formal_device_report"] = True
        self.assertTrue(list(Draft202012Validator(schema).iter_errors(probe)))
        probe = good_provisional_probe()
        probe["profile"]["unexpected"] = True
        self.assertTrue(list(Draft202012Validator(schema).iter_errors(probe)))


if __name__ == "__main__":
    unittest.main()
