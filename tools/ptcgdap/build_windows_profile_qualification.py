from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import sys
from typing import Mapping, Sequence


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import (  # noqa: E402
    canonical_json_v1_bytes,
    load_json_bytes_strict,
)


PROFILE_RELATIVE_PATH = Path("data/ptcgdap/author_strategy_device_acceptance_profile.json")
ALLOWED_EXPORT_RELATIVE_ROOT = Path(".tmp/ptcgdap_device_release")
MAX_JSON_BYTES = 16 * 1024 * 1024
MAX_SAFE_INTEGER = 9_007_199_254_740_991
MARNIE_ARCHIVE_SHA256 = "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"
POLICY_PACKAGE_SHA256 = "3243ABD7937B3F53D8E5D7A887FC90BFBDF9A4D94E4030A3A9BE194C82370FFC"
LOCAL_EXECUTOR_SHA256 = "6961EEECEEB33459002A40A52AA76AB0243871439D3FDF10B9F1F4927AB6D6E0"


def _is_within(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
    except ValueError:
        return False
    return True


def _regular_non_symlink(path: Path, root: Path, *, label: str) -> Path:
    lexical = Path(os.path.abspath(path))
    if not _is_within(lexical, root):
        raise ValueError(f"{label} must stay inside the fixed evidence root")
    if not lexical.is_file() or lexical.is_symlink():
        raise ValueError(f"{label} must be a regular non-symlink file")
    resolved = lexical.resolve(strict=True)
    if resolved != lexical or not _is_within(resolved, root):
        raise ValueError(f"{label} must be a regular non-symlink file")
    stat = resolved.stat()
    if stat.st_size <= 0 or stat.st_size > MAX_JSON_BYTES:
        raise ValueError(f"{label} has an invalid byte size")
    if getattr(stat, "st_nlink", 1) != 1:
        raise ValueError(f"{label} must not be a hard-link alias")
    return resolved


def _read_json(path: Path, root: Path, *, label: str) -> tuple[dict[str, object], str]:
    resolved = _regular_non_symlink(path, root, label=label)
    raw = resolved.read_bytes()
    value = load_json_bytes_strict(raw)
    if type(value) is not dict:
        raise ValueError(f"{label} must contain one JSON object")
    return value, hashlib.sha256(raw).hexdigest().upper()


def _exact_bool(value: object, expected: bool) -> bool:
    return type(value) is bool and value is expected


def _positive_int(value: object) -> bool:
    return type(value) is int and 0 < value <= MAX_SAFE_INTEGER


def _nonnegative_int(value: object) -> bool:
    return type(value) is int and 0 <= value <= MAX_SAFE_INTEGER


def _sha256(value: object) -> bool:
    return type(value) is str and len(value) == 64 and all(
        character in "0123456789ABCDEF" for character in value
    )


def _nearest_rank_p95(values: list[int]) -> int:
    if not values:
        raise ValueError("decision samples must not be empty")
    ordered = sorted(values)
    return ordered[((95 * len(ordered) + 99) // 100) - 1]


def _mapping(value: object, *, label: str) -> Mapping[str, object]:
    if type(value) is not dict:
        raise ValueError(f"{label} must be an object")
    return value


def _fixed_project_root(project_root: Path) -> tuple[Path, Path]:
    root = Path(os.path.abspath(project_root))
    if not root.is_dir() or root.is_symlink() or root.resolve(strict=True) != root:
        raise ValueError("project root must be a regular non-symlink directory")
    allowed = root / ALLOWED_EXPORT_RELATIVE_ROOT
    allowed.mkdir(parents=True, exist_ok=True)
    if allowed.is_symlink() or allowed.resolve(strict=True) != allowed:
        raise ValueError("fixed export root must be a regular non-symlink directory")
    return root, allowed


def _profile(root: Path) -> tuple[dict[str, object], str, str]:
    path = root / PROFILE_RELATIVE_PATH
    if not path.is_file() or path.is_symlink() or path.resolve(strict=True) != path:
        raise ValueError("fixed device profile is missing or redirected")
    raw = path.read_bytes()
    value = load_json_bytes_strict(raw)
    if type(value) is not dict:
        raise ValueError("fixed device profile must be an object")
    if (
        value.get("document_type") != "author_strategy_device_acceptance_profile_v1"
        or value.get("schema_version") != 1
        or value.get("approval_status") not in ("proposed", "approved")
        or type(value.get("formal_a5_eligible")) is not bool
    ):
        raise ValueError("fixed device profile has an unsupported identity or status")
    platforms = _mapping(value.get("platforms"), label="profile platforms")
    windows = _mapping(platforms.get("windows"), label="Windows profile")
    required_limits = {
        "max_cold_start_msec",
        "max_catalog_scan_msec",
        "max_match_load_msec",
        "max_decision_p95_msec",
        "max_peak_memory_mib",
        "max_package_mib",
    }
    if not required_limits.issubset(windows) or any(
        not _positive_int(windows[key]) for key in required_limits
    ):
        raise ValueError("fixed Windows profile limits are incomplete")
    method = _mapping(value.get("measurement_method"), label="profile measurement method")
    if (
        method.get("cold_start_samples") != 3
        or not _positive_int(method.get("decision_samples_minimum"))
        or not _exact_bool(method.get("full_match_required"), True)
        or not _exact_bool(method.get("rollback_required"), True)
    ):
        raise ValueError("fixed device profile requires an unsupported qualification method")
    return (
        value,
        hashlib.sha256(raw).hexdigest().upper(),
        hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper(),
    )


def _manifest(
    manifest_path: Path,
    allowed_root: Path,
) -> tuple[dict[str, object], str, Path, int, str]:
    value, raw_sha = _read_json(manifest_path, allowed_root, label="export manifest")
    if (
        value.get("document_type") != "author_strategy_device_export_manifest_v1"
        or value.get("schema_version") != 1
        or value.get("release_target_platforms") != ["windows"]
        or not _exact_bool(value.get("player_start_allowed"), False)
        or not _exact_bool(value.get("production_ready"), False)
    ):
        raise ValueError("export manifest is not the closed Windows development shape")
    output_directory = Path(os.path.abspath(str(value.get("output_directory", ""))))
    manifest_resolved = Path(os.path.abspath(manifest_path)).resolve(strict=True)
    if (
        output_directory != manifest_resolved.parent
        or not _is_within(output_directory, allowed_root)
        or not output_directory.is_dir()
        or output_directory.is_symlink()
        or output_directory.resolve(strict=True) != output_directory
    ):
        raise ValueError("export manifest output directory is not fixed to its parent")
    outputs = value.get("outputs")
    if type(outputs) is not list:
        raise ValueError("export manifest outputs must be an array")
    executables = [
        entry
        for entry in outputs
        if type(entry) is dict
        and entry.get("kind") == "executable"
        and entry.get("platform") == "windows"
    ]
    if len(executables) != 1:
        raise ValueError("export manifest must bind exactly one Windows executable")
    entry = executables[0]
    executable = Path(os.path.abspath(str(entry.get("path", ""))))
    if (
        not _is_within(executable, output_directory)
        or not executable.is_file()
        or executable.is_symlink()
        or executable.resolve(strict=True) != executable
    ):
        raise ValueError("export executable must be a regular file inside the output directory")
    actual_bytes = executable.stat().st_size
    actual_sha = hashlib.sha256(executable.read_bytes()).hexdigest().upper()
    if entry.get("bytes") != actual_bytes or entry.get("sha256") != actual_sha:
        raise ValueError("export executable no longer matches its manifest")
    return value, raw_sha, executable, actual_bytes, actual_sha


def _ui_measurement(
    report: dict[str, object],
    *,
    executable_sha256: str,
) -> dict[str, object]:
    if (
        report.get("document_type") != "author_strategy_windows_real_input_ui_match_report_v1"
        or report.get("schema_version") != 1
        or not _exact_bool(report.get("passed"), True)
        or report.get("executable_sha256") != executable_sha256
    ):
        raise ValueError("UI report does not bind the exact passing executable")
    if (
        report.get("acceptance_mode") != "development"
        or not _exact_bool(report.get("development_only"), True)
        or not _exact_bool(report.get("device_canary"), False)
        or not _exact_bool(report.get("production_ready"), False)
        or not _exact_bool(report.get("a5_claimed"), False)
        or not _exact_bool(report.get("real_mouse_input_proven"), True)
        or not _positive_int(report.get("real_mouse_click_count"))
        or not _exact_bool(report.get("network_isolation_proven"), False)
        or not _exact_bool(report.get("application_network_disabled"), True)
        or report.get("application_network_attempt_markers") != ""
        or report.get("runtime_failure_markers") != ""
    ):
        raise ValueError("UI report is not a clean development-only ordinary-input run")
    process = _mapping(report.get("process"), label="UI process")
    measurements = _mapping(report.get("measurements"), label="UI measurements")
    engine = _mapping(report.get("engine_report"), label="UI engine report")
    audit = _mapping(engine.get("author_audit"), label="UI author audit")
    decision_samples = measurements.get("decision_msec")
    if (
        not _positive_int(process.get("process_id"))
        or not _positive_int(process.get("peak_working_set_mib"))
        or not _positive_int(measurements.get("cold_start_msec"))
        or not _positive_int(measurements.get("catalog_scan_msec"))
        or not _positive_int(measurements.get("match_load_msec"))
        or type(decision_samples) is not list
        or not decision_samples
        or any(not _nonnegative_int(value) for value in decision_samples)
    ):
        raise ValueError("UI report measurements are invalid")
    if (
        engine.get("document_type") != "author_strategy_windows_ui_match_report_v1"
        or engine.get("schema_version") != 1
        or not _exact_bool(engine.get("complete_match_finished"), True)
        or not _exact_bool(engine.get("is_clean"), True)
        or engine.get("dirty_reasons") != []
    ):
        raise ValueError("UI engine report did not finish one clean match")
    if (
        audit.get("package_id") != "ptcgdap.marnie.windows-local"
        or audit.get("package_version") != "0.1.0"
        or audit.get("archive_sha256") != MARNIE_ARCHIVE_SHA256
        or audit.get("signature_scope") != "test_fixture_only"
        or not _exact_bool(audit.get("execution_trusted"), False)
        or audit.get("card_id_domain") != "godot_local_card_uid_v1"
        or audit.get("local_policy_executor_manifest_canonical_sha256") != LOCAL_EXECUTOR_SHA256
        or audit.get("policy_package_manifest_canonical_sha256") != POLICY_PACKAGE_SHA256
        or not _exact_bool(audit.get("policy_engine_object_access"), False)
        or not _exact_bool(audit.get("restricted_ir_executed"), True)
        or audit.get("execution_location") != "device_local"
    ):
        raise ValueError("UI author audit is not the exact current local policy owner")
    policy_calls = audit.get("policy_calls")
    if (
        policy_calls != len(decision_samples)
        or audit.get("policy_successes") != policy_calls
        or audit.get("policy_errors") != 0
        or audit.get("invalid_outputs") != 0
        or audit.get("same_window_fallbacks") != 0
        or audit.get("classic_fallbacks") != 0
        or audit.get("engine_rejections") != 0
        or audit.get("external_process_attempts") != 0
        or not _positive_int(audit.get("engine_commits"))
    ):
        raise ValueError("UI report policy accounting is not clean")
    return {
        "process_id": process["process_id"],
        "cold_start_msec": measurements["cold_start_msec"],
        "catalog_scan_msec": measurements["catalog_scan_msec"],
        "match_load_msec": measurements["match_load_msec"],
        "decision_msec": list(decision_samples),
        "peak_memory_mib": process["peak_working_set_mib"],
        "policy_calls": policy_calls,
        "engine_commits": audit["engine_commits"],
    }


def _rollback(
    report: dict[str, object],
    *,
    export_manifest_sha256: str,
    executable_sha256: str,
) -> None:
    export = _mapping(report.get("export"), label="rollback export")
    if (
        report.get("document_type") != "author_strategy_windows_feature_rollback_execution_v1"
        or report.get("schema_version") != 1
        or not _exact_bool(report.get("accepted"), True)
        or not _exact_bool(report.get("failed_closed_before_execution"), True)
        or report.get("policy_calls") != 0
        or report.get("engine_commits") != 0
        or not _exact_bool(report.get("user_packages_deleted"), False)
        or not _exact_bool(report.get("device_canary_requested"), False)
        or not _exact_bool(report.get("development_only"), True)
        or not _exact_bool(report.get("production_rollback_claimed"), False)
        or not _exact_bool(report.get("network_isolation_proven"), False)
        or export.get("manifest_sha256") != export_manifest_sha256
        or export.get("executable_sha256") != executable_sha256
    ):
        raise ValueError("rollback report does not prove development fail-closed behavior")


def build_profile_qualification(
    *,
    project_root: Path,
    export_manifest_path: Path,
    evidence_root: Path,
    ui_report_paths: Sequence[Path],
    rollback_report_path: Path,
    output_path: Path,
) -> dict[str, object]:
    root, allowed_root = _fixed_project_root(project_root)
    evidence = Path(os.path.abspath(evidence_root))
    if (
        not evidence.is_dir()
        or evidence.is_symlink()
        or evidence.resolve(strict=True) != evidence
        or not _is_within(evidence, allowed_root)
    ):
        raise ValueError("evidence root must be a regular directory under the fixed export root")
    profile, profile_raw_sha, profile_canonical_sha = _profile(root)
    _, manifest_sha, _, executable_bytes, executable_sha = _manifest(
        export_manifest_path,
        allowed_root,
    )
    if len(ui_report_paths) != 3:
        raise ValueError("profile qualification requires exactly three UI reports")
    ui_rows: list[dict[str, object]] = []
    ui_evidence: list[dict[str, object]] = []
    seen_paths: set[Path] = set()
    for index, path in enumerate(ui_report_paths, start=1):
        resolved = Path(os.path.abspath(path))
        if resolved in seen_paths:
            raise ValueError("UI report paths must be unique")
        seen_paths.add(resolved)
        value, raw_sha = _read_json(path, evidence, label=f"UI report {index}")
        ui_rows.append(_ui_measurement(value, executable_sha256=executable_sha))
        ui_evidence.append(
            {
                "index": index,
                "path": resolved.relative_to(evidence).as_posix(),
                "raw_sha256": raw_sha,
            }
        )
    process_ids = [int(row["process_id"]) for row in ui_rows]
    if len(set(process_ids)) != 3:
        raise ValueError("UI reports must bind three distinct target processes")
    rollback_value, rollback_sha = _read_json(
        rollback_report_path,
        evidence,
        label="rollback report",
    )
    _rollback(
        rollback_value,
        export_manifest_sha256=manifest_sha,
        executable_sha256=executable_sha,
    )

    cold_starts = [int(row["cold_start_msec"]) for row in ui_rows]
    catalog_samples = [int(row["catalog_scan_msec"]) for row in ui_rows]
    match_load_samples = [int(row["match_load_msec"]) for row in ui_rows]
    peak_samples = [int(row["peak_memory_mib"]) for row in ui_rows]
    decision_samples = [
        int(value)
        for row in ui_rows
        for value in row["decision_msec"]  # type: ignore[union-attr]
    ]
    method = _mapping(profile["measurement_method"], label="profile measurement method")
    if len(decision_samples) < int(method["decision_samples_minimum"]):
        raise ValueError("decision sample count is below the fixed profile minimum")
    measurements = {
        "cold_start_msec": max(cold_starts),
        "catalog_scan_msec": max(catalog_samples),
        "match_load_msec": max(match_load_samples),
        "decision_p95_msec": _nearest_rank_p95(decision_samples),
        "peak_memory_mib": max(peak_samples),
        "package_mib": math.ceil(executable_bytes / (1024 * 1024)),
    }
    windows = _mapping(
        _mapping(profile["platforms"], label="profile platforms")["windows"],
        label="Windows profile",
    )
    metric_limits = {
        "cold_start_msec": "max_cold_start_msec",
        "catalog_scan_msec": "max_catalog_scan_msec",
        "match_load_msec": "max_match_load_msec",
        "decision_p95_msec": "max_decision_p95_msec",
        "peak_memory_mib": "max_peak_memory_mib",
        "package_mib": "max_package_mib",
    }
    evaluations = {
        metric: {
            "actual": measurements[metric],
            "limit": int(windows[limit_key]),
            "met": measurements[metric] <= int(windows[limit_key]),
        }
        for metric, limit_key in metric_limits.items()
    }
    all_limits_met = all(bool(value["met"]) for value in evaluations.values())
    if not all_limits_met:
        raise ValueError("one or more fixed candidate thresholds were exceeded")

    rollback_resolved = Path(os.path.abspath(rollback_report_path))
    identity_scope = {
        "profile_canonical_sha256": profile_canonical_sha,
        "export_manifest_sha256": manifest_sha,
        "executable_sha256": executable_sha,
        "ui_report_sha256": [row["raw_sha256"] for row in ui_evidence],
        "rollback_report_sha256": rollback_sha,
    }
    qualification_id = hashlib.sha256(canonical_json_v1_bytes(identity_scope)).hexdigest().upper()
    result: dict[str, object] = {
        "document_type": "author_strategy_windows_profile_qualification_v1",
        "schema_version": 1,
        "qualification_id": qualification_id,
        "profile": {
            "path": PROFILE_RELATIVE_PATH.as_posix(),
            "profile_id": profile["profile_id"],
            "approval_status": profile["approval_status"],
            "formal_a5_eligible": profile["formal_a5_eligible"],
            "raw_sha256": profile_raw_sha,
            "canonical_sha256": profile_canonical_sha,
        },
        "export": {
            "manifest_raw_sha256": manifest_sha,
            "executable_sha256": executable_sha,
            "executable_bytes": executable_bytes,
        },
        "package": {
            "package_id": "ptcgdap.marnie.windows-local",
            "package_version": "0.1.0",
            "archive_sha256": MARNIE_ARCHIVE_SHA256,
            "policy_package_manifest_canonical_sha256": POLICY_PACKAGE_SHA256,
            "local_policy_executor_manifest_canonical_sha256": LOCAL_EXECUTOR_SHA256,
            "signature_scope": "test_fixture_only",
            "execution_trusted": False,
        },
        "samples": {
            "cold_start_count": len(cold_starts),
            "cold_start_msec": cold_starts,
            "catalog_scan_msec": catalog_samples,
            "match_load_msec": match_load_samples,
            "peak_memory_mib": peak_samples,
            "decision_count": len(decision_samples),
            "decision_msec": decision_samples,
            "target_process_ids": process_ids,
        },
        "measurements": measurements,
        "threshold_evaluation": {
            "metrics": evaluations,
            "all_limits_met": True,
        },
        "match_accounting": {
            "ui_runs_passed": 3,
            "policy_calls": sum(int(row["policy_calls"]) for row in ui_rows),
            "engine_commits": sum(int(row["engine_commits"]) for row in ui_rows),
            "policy_errors": 0,
            "invalid_outputs": 0,
            "same_window_fallbacks": 0,
            "classic_fallbacks": 0,
            "engine_rejections": 0,
            "external_process_attempts": 0,
        },
        "rollback": {
            "failed_closed_before_execution": True,
            "policy_calls": 0,
            "engine_commits": 0,
            "user_packages_deleted": False,
        },
        "evidence": {
            "ui_reports": ui_evidence,
            "rollback_report": {
                "path": rollback_resolved.relative_to(evidence).as_posix(),
                "raw_sha256": rollback_sha,
            },
        },
        "claims": {
            "development_only": True,
            "profile_approval_granted": profile["approval_status"] == "approved",
            "formal_device_report": False,
            "os_network_isolation_proven": False,
            "production_ready": False,
            "a5_claimed": False,
        },
        "limitations": [
            "This report qualifies the fixed candidate resource thresholds on one Windows host; it does not approve the product profile.",
            "Application-level network disablement is not Administrator-audited WFP/4688 isolation evidence.",
            "The development package is test-fixture signed and execution_trusted=false; production trust and A5 remain closed.",
        ],
    }
    output = Path(os.path.abspath(output_path))
    if not _is_within(output, evidence) or output.parent != evidence:
        raise ValueError("output must be a direct child of the fixed evidence root")
    if output.exists():
        raise FileExistsError(f"refusing to overwrite existing output: {output}")
    raw_output = json.dumps(
        result,
        ensure_ascii=False,
        indent=2,
        sort_keys=True,
    ).encode("utf-8") + b"\n"
    with output.open("xb") as stream:
        stream.write(raw_output)
    return result


def build_preflight(
    *,
    project_root: Path,
    export_manifest_path: Path,
) -> dict[str, object]:
    root, allowed_root = _fixed_project_root(project_root)
    profile, profile_raw_sha, profile_canonical_sha = _profile(root)
    manifest, manifest_raw_sha, executable, executable_bytes, executable_sha = _manifest(
        export_manifest_path,
        allowed_root,
    )
    return {
        "document_type": "author_strategy_windows_profile_qualification_preflight_v1",
        "schema_version": 1,
        "export_manifest_raw_sha256": manifest_raw_sha,
        "output_directory": manifest["output_directory"],
        "executable_path": str(executable),
        "executable_bytes": executable_bytes,
        "executable_sha256": executable_sha,
        "profile_id": profile["profile_id"],
        "profile_approval_status": profile["approval_status"],
        "profile_raw_sha256": profile_raw_sha,
        "profile_canonical_sha256": profile_canonical_sha,
        "formal_a5_eligible": profile["formal_a5_eligible"],
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Build a non-A5 Windows device-profile qualification report from three real UI matches."
    )
    parser.add_argument("--project-root", type=Path, default=ROOT)
    parser.add_argument("--preflight", action="store_true")
    parser.add_argument("--export-manifest", type=Path, required=True)
    parser.add_argument("--evidence-root", type=Path)
    parser.add_argument("--ui-report", type=Path, action="append")
    parser.add_argument("--rollback-report", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    try:
        if args.preflight:
            if any(
                value is not None
                for value in (
                    args.evidence_root,
                    args.ui_report,
                    args.rollback_report,
                    args.output,
                )
            ):
                raise ValueError("preflight does not accept evidence or output arguments")
            result = build_preflight(
                project_root=args.project_root,
                export_manifest_path=args.export_manifest,
            )
            print(json.dumps(result, ensure_ascii=False, sort_keys=True))
            return 0
        if (
            args.evidence_root is None
            or args.ui_report is None
            or args.rollback_report is None
            or args.output is None
        ):
            raise ValueError("report mode requires evidence root, three UI reports, rollback, and output")
        result = build_profile_qualification(
            project_root=args.project_root,
            export_manifest_path=args.export_manifest,
            evidence_root=args.evidence_root,
            ui_report_paths=args.ui_report,
            rollback_report_path=args.rollback_report,
            output_path=args.output,
        )
    except (FileExistsError, OSError, TypeError, ValueError) as exc:
        print(str(exc), file=sys.stderr)
        return 2
    print(json.dumps({"qualification_id": result["qualification_id"], "passed": True}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
