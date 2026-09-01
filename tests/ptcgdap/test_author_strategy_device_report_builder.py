from __future__ import annotations

import copy
import hashlib
import json
import math
from pathlib import Path
import tempfile
import unittest

from scripts.ai.ptcgdap.author_strategy_release import evaluate_device_report
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
PROFILE_RELATIVE = Path("data/ptcgdap/author_strategy_device_acceptance_profile.json")


def approved_profile() -> dict[str, object]:
    profile = copy.deepcopy(load_json_strict(ROOT / PROFILE_RELATIVE))
    profile["approval_status"] = "approved"
    profile["formal_a5_eligible"] = True
    return profile


def measurement_input() -> dict[str, object]:
    decision_samples = list(range(1, 101))
    return {
        "document_type": "author_strategy_device_measurement_input_v1",
        "schema_version": 1,
        "platform": "windows",
        "architecture": "x86_64",
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
            "cold_start_msec": [100, 120, 110],
            "decision_msec": decision_samples,
        },
        "measurements": {
            "catalog_scan_msec": 50,
            "match_load_msec": 75,
            "peak_memory_mib": 256,
            "package_mib": 263,
            "thermal_status_max": None,
            "battery_drain_percent_per_hour": None,
        },
        "rollback": {
            "mode_disabled": True,
            "user_packages_preserved": True,
        },
        "evidence_files": {
            "export_manifest_sha256": "export-manifest.json",
            "network_audit_sha256": "network-audit.json",
            "process_audit_sha256": "process-audit.json",
            "full_match_audit_sha256": "full-match-audit.json",
            "rollback_report_sha256": "rollback-report.json",
        },
    }


def evidence_documents(evidence: Path) -> dict[str, dict[str, object]]:
    executable = evidence / "PtcgDeckAgent.exe"
    executable_bytes = b"MZ\x00ptcgdap-formal-device-test"
    executable.write_bytes(executable_bytes)
    executable_sha256 = hashlib.sha256(executable_bytes).hexdigest().upper()
    run_id = "windows-a5-test-run-001"
    decision_samples = list(range(1, 101))
    return {
        "export-manifest.json": {
            "document_type": "author_strategy_device_export_manifest_v1",
            "schema_version": 1,
            "generated_at": "2026-08-14T00:00:00Z",
            "project_root": str(evidence.parent / "project"),
            "godot_executable": "Godot_v4.6.1-stable_win64_console.exe",
            "godot_version": "4.6.1.stable.official.14d19694e",
            "output_directory": str(evidence),
            "outputs": [
                {
                    "kind": "executable",
                    "platform": "windows",
                    "path": str(executable),
                    "bytes": len(executable_bytes),
                    "sha256": executable_sha256,
                }
            ],
            "release_target_platforms": ["windows"],
            "player_start_allowed": False,
            "production_ready": False,
            "limitations": ["Release canary export; player start remains gated."],
        },
        "network-audit.json": {
            "document_type": "author_strategy_windows_network_audit_v1",
            "schema_version": 1,
            "run_id": run_id,
            "platform": "windows",
            "target_executable_sha256": executable_sha256,
            "audit_method": "windows_filtering_platform_security_events_5154_5159_v1",
            "target_process_ids": [111],
            "os_network_block_enforced": True,
            "socket_attempts": 0,
            "dns_attempts": 0,
            "http_attempts": 0,
            "remote_inference_attempts": 0,
            "dynamic_download_attempts": 0,
            "firewall_rules_removed": True,
            "audit_policy_restored": True,
            "passed": True,
        },
        "process-audit.json": {
            "document_type": "author_strategy_windows_process_audit_v1",
            "schema_version": 1,
            "run_id": run_id,
            "platform": "windows",
            "target_executable_sha256": executable_sha256,
            "audit_method": "windows_security_process_creation_4688_v1",
            "target_process_ids": [111],
            "child_process_ids": [],
            "external_process_attempts": 0,
            "system_python_required": False,
            "sidecar_processes": [],
            "external_compute_required": False,
            "audit_policy_restored": True,
            "passed": True,
        },
        "full-match-audit.json": {
            "document_type": "author_strategy_windows_full_match_audit_v1",
            "schema_version": 1,
            "run_id": run_id,
            "platform": "windows",
            "target_executable_sha256": executable_sha256,
            "package_id": "ptcgdap.marnie.windows-local",
            "package_version": "0.1.0",
            "package_archive_sha256": "A" * 64,
            "signature_scope": "production_release",
            "execution_trusted": True,
            "ordinary_ui": True,
            "real_mouse_input": True,
            "complete_match_finished": True,
            "cold_start_msec": [100, 120, 110],
            "decision_msec": decision_samples,
            "catalog_scan_msec": 50,
            "match_load_msec": 75,
            "peak_memory_mib": 256,
            "policy_calls": len(decision_samples),
            "policy_successes": len(decision_samples),
            "policy_errors": 0,
            "invalid_outputs": 0,
            "same_window_fallbacks": 0,
            "classic_fallbacks": 0,
            "engine_rejections": 0,
            "engine_commits": 97,
            "passed": True,
        },
        "rollback-report.json": {
            "document_type": "author_strategy_windows_rollback_audit_v1",
            "schema_version": 1,
            "run_id": run_id,
            "platform": "windows",
            "target_executable_sha256": executable_sha256,
            "mode_disabled": True,
            "user_packages_preserved": True,
            "policy_calls_after_disable": 0,
            "engine_commits_after_disable": 0,
            "passed": True,
        },
    }


class AuthorStrategyDeviceReportBuilderTests(unittest.TestCase):
    def prepare(
        self,
        root: Path,
        *,
        approved: bool = True,
        a5_eligible: bool = True,
    ) -> tuple[Path, Path, Path]:
        project = root / "project"
        evidence = root / "device-evidence"
        profile_path = project / PROFILE_RELATIVE
        profile_path.parent.mkdir(parents=True)
        profile = copy.deepcopy(load_json_strict(ROOT / PROFILE_RELATIVE))
        profile["approval_status"] = "approved" if approved else "proposed"
        profile["formal_a5_eligible"] = a5_eligible if approved else False
        profile_path.write_bytes(canonical_json_v1_bytes(profile))
        evidence.mkdir()
        documents = evidence_documents(evidence)
        for filename, document in documents.items():
            (evidence / filename).write_bytes(canonical_json_v1_bytes(document))
        source = measurement_input()
        source["measurements"]["package_mib"] = math.ceil(
            (evidence / "PtcgDeckAgent.exe").stat().st_size / (1024 * 1024)
        )
        measurements = evidence / "measurements.json"
        measurements.write_bytes(canonical_json_v1_bytes(source))
        return project, evidence, measurements

    def _builder(self):
        from tools.ptcgdap.build_author_strategy_device_report import (
            build_device_report,
            write_device_report,
        )

        return build_device_report, write_device_report

    def test_fixed_approved_profile_builds_recomputed_closed_report(self) -> None:
        build_device_report, write_device_report = self._builder()
        with tempfile.TemporaryDirectory(prefix="ptcgdap-device-report-") as temp:
            project, evidence, measurements = self.prepare(Path(temp))
            report = build_device_report(
                project_root=project,
                measurements_path=measurements,
                evidence_root=evidence,
            )
            self.assertEqual("author_strategy_device_report_v1", report["document_type"])
            self.assertEqual(120, report["measurements"]["cold_start_msec"])
            self.assertEqual(95, report["measurements"]["decision_p95_msec"])
            self.assertNotIn("evidence_files", json.dumps(report, sort_keys=True))
            self.assertNotIn(str(evidence), json.dumps(report, sort_keys=True))
            source = load_json_strict(measurements)
            for key, filename in source["evidence_files"].items():
                expected = hashlib.sha256((evidence / filename).read_bytes()).hexdigest().upper()
                self.assertEqual(expected, report["evidence"][key])
            profile = load_json_strict(project / PROFILE_RELATIVE)
            self.assertTrue(evaluate_device_report(profile, report)["accepted"])

            output = evidence / "formal-device-report.json"
            written = write_device_report(
                project_root=project,
                measurements_path=measurements,
                evidence_root=evidence,
                output_path=output,
            )
            self.assertEqual(report, written)
            self.assertEqual(report, load_json_strict(output))
            self.assertEqual(canonical_json_v1_bytes(report), output.read_bytes())
            with self.assertRaisesRegex(ValueError, "already exists"):
                write_device_report(
                    project_root=project,
                    measurements_path=measurements,
                    evidence_root=evidence,
                    output_path=output,
                )

    def test_unapproved_fixed_profile_refuses_before_report_output(self) -> None:
        _, write_device_report = self._builder()
        with tempfile.TemporaryDirectory(prefix="ptcgdap-device-report-") as temp:
            project, evidence, measurements = self.prepare(Path(temp), approved=False)
            output = evidence / "must-not-exist.json"
            with self.assertRaisesRegex(ValueError, "profile is not approved"):
                write_device_report(
                    project_root=project,
                    measurements_path=measurements,
                    evidence_root=evidence,
                    output_path=output,
                )
            self.assertFalse(output.exists())

    def test_approved_non_a5_profile_refuses_with_distinct_error(self) -> None:
        _, write_device_report = self._builder()
        with tempfile.TemporaryDirectory(prefix="ptcgdap-device-report-") as temp:
            project, evidence, measurements = self.prepare(
                Path(temp),
                approved=True,
                a5_eligible=False,
            )
            output = evidence / "must-not-exist.json"
            with self.assertRaisesRegex(ValueError, "profile is not A5 eligible"):
                write_device_report(
                    project_root=project,
                    measurements_path=measurements,
                    evidence_root=evidence,
                    output_path=output,
                )
            self.assertFalse(output.exists())

    def test_invalid_measurement_claims_and_evidence_paths_fail_closed(self) -> None:
        build_device_report, _ = self._builder()
        with tempfile.TemporaryDirectory(prefix="ptcgdap-device-report-") as temp:
            project, evidence, measurements = self.prepare(Path(temp))
            cases: list[tuple[str, dict[str, object], str]] = []
            value = measurement_input()
            value["unexpected"] = True
            cases.append(("extra", value, "measurement input invalid"))
            value = measurement_input()
            value["samples"]["decision_msec"] = [10] * 99
            cases.append(("few-decisions", value, "device_sample_count_insufficient"))
            value = measurement_input()
            value["offline"]["network_blocked"] = False
            cases.append(("network", value, "device_network_not_blocked"))
            value = measurement_input()
            value["runtime"]["system_python_required"] = True
            cases.append(("python", value, "device_external_runtime_detected"))
            value = measurement_input()
            value["evidence_files"]["network_audit_sha256"] = "../outside.json"
            cases.append(("traversal", value, "evidence path invalid"))
            for label, unsafe_path in (
                ("ads", "nested/network.json:stream"),
                ("reserved", "NUL.json"),
                ("trailing-dot", "network-audit.json."),
                ("trailing-space", "network-audit.json "),
            ):
                value = measurement_input()
                value["evidence_files"]["network_audit_sha256"] = unsafe_path
                cases.append((label, value, "evidence path invalid"))

            for label, value, error in cases:
                path = evidence / f"{label}.json"
                path.write_bytes(canonical_json_v1_bytes(value))
                with self.subTest(label=label), self.assertRaisesRegex(ValueError, error):
                    build_device_report(
                        project_root=project,
                        measurements_path=path,
                        evidence_root=evidence,
                    )

            missing = measurement_input()
            missing["evidence_files"]["network_audit_sha256"] = "missing.json"
            missing_path = evidence / "missing-input.json"
            missing_path.write_bytes(canonical_json_v1_bytes(missing))
            with self.assertRaisesRegex(ValueError, "evidence file missing"):
                build_device_report(
                    project_root=project,
                    measurements_path=missing_path,
                    evidence_root=evidence,
                )

            duplicate = measurement_input()
            duplicate["evidence_files"]["network_audit_sha256"] = duplicate["evidence_files"][
                "export_manifest_sha256"
            ]
            duplicate_path = evidence / "duplicate-input.json"
            duplicate_path.write_bytes(canonical_json_v1_bytes(duplicate))
            with self.assertRaisesRegex(ValueError, "evidence files must be distinct"):
                build_device_report(
                    project_root=project,
                    measurements_path=duplicate_path,
                    evidence_root=evidence,
                )

            self_reference = measurement_input()
            self_reference["evidence_files"]["network_audit_sha256"] = "self-input.json"
            self_path = evidence / "self-input.json"
            self_path.write_bytes(canonical_json_v1_bytes(self_reference))
            with self.assertRaisesRegex(ValueError, "measurements file cannot be evidence"):
                build_device_report(
                    project_root=project,
                    measurements_path=self_path,
                    evidence_root=evidence,
                )

    def test_evidence_semantics_are_bound_to_every_formal_claim(self) -> None:
        build_device_report, _ = self._builder()
        with tempfile.TemporaryDirectory(prefix="ptcgdap-device-report-") as temp:
            project, evidence, measurements = self.prepare(Path(temp))
            source = load_json_strict(measurements)
            cases = (
                ("network-audit.json", "os_network_block_enforced", False, "network audit invalid"),
                ("network-audit.json", "socket_attempts", 1, "network audit invalid"),
                ("process-audit.json", "external_process_attempts", 1, "process audit invalid"),
                ("full-match-audit.json", "ordinary_ui", False, "full match audit invalid"),
                ("full-match-audit.json", "signature_scope", "test_fixture_only", "full match audit invalid"),
                ("rollback-report.json", "user_packages_preserved", False, "rollback audit invalid"),
            )
            for filename, key, unsafe, error in cases:
                path = evidence / filename
                original = path.read_bytes()
                value = load_json_strict(path)
                value[key] = unsafe
                path.write_bytes(canonical_json_v1_bytes(value))
                with self.subTest(filename=filename, key=key), self.assertRaisesRegex(ValueError, error):
                    build_device_report(
                        project_root=project,
                        measurements_path=measurements,
                        evidence_root=evidence,
                    )
                path.write_bytes(original)

            full_match_path = evidence / "full-match-audit.json"
            full_match = load_json_strict(full_match_path)
            full_match["decision_msec"] = [2] * 100
            full_match_path.write_bytes(canonical_json_v1_bytes(full_match))
            with self.assertRaisesRegex(ValueError, "measurement evidence mismatch"):
                build_device_report(
                    project_root=project,
                    measurements_path=measurements,
                    evidence_root=evidence,
                )

            full_match_path.write_bytes(canonical_json_v1_bytes(evidence_documents(evidence)["full-match-audit.json"]))
            export_path = evidence / "export-manifest.json"
            export = load_json_strict(export_path)
            export["outputs"][0]["sha256"] = "B" * 64
            export_path.write_bytes(canonical_json_v1_bytes(export))
            with self.assertRaisesRegex(ValueError, "export executable hash mismatch"):
                build_device_report(
                    project_root=project,
                    measurements_path=measurements,
                    evidence_root=evidence,
                )

    def test_measurements_and_evidence_must_be_regular_files_inside_fixed_root(self) -> None:
        build_device_report, _ = self._builder()
        with tempfile.TemporaryDirectory(prefix="ptcgdap-device-report-") as temp:
            root = Path(temp)
            project, evidence, measurements = self.prepare(root)
            outside = root / "outside.json"
            outside.write_bytes(measurements.read_bytes())
            with self.assertRaisesRegex(ValueError, "measurements file must be inside evidence root"):
                build_device_report(
                    project_root=project,
                    measurements_path=outside,
                    evidence_root=evidence,
                )

            empty = measurement_input()
            empty["evidence_files"]["process_audit_sha256"] = "empty.json"
            (evidence / "empty.json").write_bytes(b"")
            empty_path = evidence / "empty-input.json"
            empty_path.write_bytes(canonical_json_v1_bytes(empty))
            with self.assertRaisesRegex(ValueError, "evidence file must be non-empty"):
                build_device_report(
                    project_root=project,
                    measurements_path=empty_path,
                    evidence_root=evidence,
                )

            _, write_device_report = self._builder()
            for output_name in ("NUL.json", "formal.json:stream.json"):
                with self.subTest(output_name=output_name), self.assertRaisesRegex(
                    ValueError, "evidence path invalid"
                ):
                    write_device_report(
                        project_root=project,
                        measurements_path=measurements,
                        evidence_root=evidence,
                        output_path=evidence / output_name,
                    )

    def test_semantic_json_load_is_bound_to_precomputed_evidence_hash(self) -> None:
        from tools.ptcgdap.build_author_strategy_device_report import (
            _load_evidence_json,
        )

        with tempfile.TemporaryDirectory(prefix="ptcgdap-device-report-") as temp:
            path = Path(temp) / "audit.json"
            original = canonical_json_v1_bytes({"passed": True})
            path.write_bytes(original)
            expected_sha256 = hashlib.sha256(original).hexdigest().upper()
            path.write_bytes(canonical_json_v1_bytes({"passed": False}))
            with self.assertRaisesRegex(ValueError, "changed after hashing"):
                _load_evidence_json(path, "audit", expected_sha256)


if __name__ == "__main__":
    unittest.main()
