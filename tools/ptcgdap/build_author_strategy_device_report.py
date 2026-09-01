from __future__ import annotations

import argparse
import hashlib
import math
import os
from pathlib import Path, PurePosixPath
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.author_strategy_release import evaluate_device_report
from scripts.ai.ptcgdap.source_lock import (
    canonical_json_v1_bytes,
    load_json_bytes_strict,
    load_json_strict,
)


PROFILE_RELATIVE = Path("data/ptcgdap/author_strategy_device_acceptance_profile.json")
MAX_MEASUREMENT_INPUT_BYTES = 4 * 1024 * 1024
MAX_AUDIT_JSON_BYTES = 4 * 1024 * 1024
MAX_EVIDENCE_FILE_BYTES = 512 * 1024 * 1024
MAX_SAFE_INTEGER = 9_007_199_254_740_991
WINDOWS_FORBIDDEN_PATH_CHARACTERS = frozenset('<>:"|?*')
WINDOWS_RESERVED_BASENAMES = frozenset(
    {"con", "prn", "aux", "nul"}
    | {f"com{index}" for index in range(1, 10)}
    | {f"lpt{index}" for index in range(1, 10)}
)

INPUT_KEYS = frozenset(
    {
        "document_type",
        "schema_version",
        "platform",
        "architecture",
        "offline",
        "runtime",
        "samples",
        "measurements",
        "rollback",
        "evidence_files",
    }
)
INPUT_NESTED_KEYS = {
    "offline": frozenset(
        {
            "network_blocked",
            "complete_match_finished",
            "remote_inference_attempts",
            "dynamic_download_attempts",
        }
    ),
    "runtime": frozenset(
        {"system_python_required", "sidecar_processes", "external_compute_required"}
    ),
    "samples": frozenset({"cold_start_msec", "decision_msec"}),
    "measurements": frozenset(
        {
            "catalog_scan_msec",
            "match_load_msec",
            "peak_memory_mib",
            "package_mib",
            "thermal_status_max",
            "battery_drain_percent_per_hour",
        }
    ),
    "rollback": frozenset({"mode_disabled", "user_packages_preserved"}),
    "evidence_files": frozenset(
        {
            "export_manifest_sha256",
            "network_audit_sha256",
            "process_audit_sha256",
            "full_match_audit_sha256",
            "rollback_report_sha256",
        }
    ),
}

EXPORT_MANIFEST_KEYS = frozenset(
    {
        "document_type",
        "schema_version",
        "generated_at",
        "project_root",
        "godot_executable",
        "godot_version",
        "output_directory",
        "outputs",
        "release_target_platforms",
        "player_start_allowed",
        "production_ready",
        "limitations",
    }
)
EXPORT_OUTPUT_KEYS = frozenset({"kind", "platform", "path", "bytes", "sha256"})
NETWORK_AUDIT_KEYS = frozenset(
    {
        "document_type",
        "schema_version",
        "run_id",
        "platform",
        "target_executable_sha256",
        "audit_method",
        "target_process_ids",
        "os_network_block_enforced",
        "socket_attempts",
        "dns_attempts",
        "http_attempts",
        "remote_inference_attempts",
        "dynamic_download_attempts",
        "firewall_rules_removed",
        "audit_policy_restored",
        "passed",
    }
)
PROCESS_AUDIT_KEYS = frozenset(
    {
        "document_type",
        "schema_version",
        "run_id",
        "platform",
        "target_executable_sha256",
        "audit_method",
        "target_process_ids",
        "child_process_ids",
        "external_process_attempts",
        "system_python_required",
        "sidecar_processes",
        "external_compute_required",
        "audit_policy_restored",
        "passed",
    }
)
FULL_MATCH_AUDIT_KEYS = frozenset(
    {
        "document_type",
        "schema_version",
        "run_id",
        "platform",
        "target_executable_sha256",
        "package_id",
        "package_version",
        "package_archive_sha256",
        "signature_scope",
        "execution_trusted",
        "ordinary_ui",
        "real_mouse_input",
        "complete_match_finished",
        "cold_start_msec",
        "decision_msec",
        "catalog_scan_msec",
        "match_load_msec",
        "peak_memory_mib",
        "policy_calls",
        "policy_successes",
        "policy_errors",
        "invalid_outputs",
        "same_window_fallbacks",
        "classic_fallbacks",
        "engine_rejections",
        "engine_commits",
        "passed",
    }
)
ROLLBACK_AUDIT_KEYS = frozenset(
    {
        "document_type",
        "schema_version",
        "run_id",
        "platform",
        "target_executable_sha256",
        "mode_disabled",
        "user_packages_preserved",
        "policy_calls_after_disable",
        "engine_commits_after_disable",
        "passed",
    }
)


def _is_within(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
    except ValueError:
        return False
    return True


def _exact_nonnegative_int(value: object) -> bool:
    return type(value) is int and 0 <= value <= MAX_SAFE_INTEGER


def _positive_int_list(value: object) -> bool:
    return (
        type(value) is list
        and bool(value)
        and all(type(item) is int and 0 < item <= MAX_SAFE_INTEGER for item in value)
        and len(set(value)) == len(value)
    )


def _nonempty_text(value: object, maximum: int = 128) -> bool:
    return (
        type(value) is str
        and 0 < len(value) <= maximum
        and all(ord(character) >= 32 and ord(character) != 127 for character in value)
    )


def _identifier(value: object) -> bool:
    if not _nonempty_text(value):
        return False
    assert type(value) is str
    for index, character in enumerate(value):
        code = ord(character)
        alphanumeric = 48 <= code <= 57 or 65 <= code <= 90 or 97 <= code <= 122
        if not alphanumeric and (index == 0 or character not in "._-"):
            return False
    return True


def _sha256(value: object) -> bool:
    return type(value) is str and len(value) == 64 and all(
        character in "0123456789ABCDEF" for character in value
    )


def _nearest_rank_p95(values: list[int]) -> int:
    ordered = sorted(values)
    return ordered[((95 * len(ordered) + 99) // 100) - 1]


def _fixed_profile(project_root: Path) -> tuple[Path, dict[str, object]]:
    root = project_root.resolve(strict=True)
    if not root.is_dir() or project_root.is_symlink():
        raise ValueError("project root must be a regular directory")
    lexical = root / PROFILE_RELATIVE
    if not lexical.is_file() or lexical.is_symlink():
        raise ValueError("fixed device acceptance profile missing")
    resolved = lexical.resolve(strict=True)
    if resolved != lexical or not _is_within(resolved, root):
        raise ValueError("fixed device acceptance profile path invalid")
    profile = load_json_strict(resolved)
    if type(profile) is not dict:
        raise ValueError("fixed device acceptance profile invalid")
    if profile.get("approval_status") != "approved":
        raise ValueError("product device acceptance profile is not approved")
    if profile.get("formal_a5_eligible") is not True:
        raise ValueError("product device acceptance profile is not A5 eligible")
    return root, profile


def _fixed_evidence_root(evidence_root: Path) -> Path:
    lexical = Path(os.path.abspath(evidence_root))
    if not lexical.is_dir() or lexical.is_symlink():
        raise ValueError("evidence root must be a regular non-symlink directory")
    resolved = lexical.resolve(strict=True)
    if resolved != lexical:
        raise ValueError("evidence root must be a regular non-symlink directory")
    return resolved


def _measurement_path(path: Path, evidence_root: Path) -> Path:
    lexical = Path(os.path.abspath(path))
    if not _is_within(lexical, evidence_root):
        raise ValueError("measurements file must be inside evidence root")
    _safe_relative_path(lexical.relative_to(evidence_root).as_posix())
    if not lexical.is_file() or lexical.is_symlink():
        raise ValueError("measurements file must be a regular non-symlink file")
    resolved = lexical.resolve(strict=True)
    if resolved != lexical or not _is_within(resolved, evidence_root):
        raise ValueError("measurements file must be inside evidence root")
    size = resolved.stat().st_size
    if size <= 0 or size > MAX_MEASUREMENT_INPUT_BYTES:
        raise ValueError("measurements file size invalid")
    return resolved


def _safe_relative_path(value: object) -> PurePosixPath:
    if type(value) is not str or not value or "\\" in value or "\0" in value:
        raise ValueError("evidence path invalid")
    path = PurePosixPath(value)
    if (
        path.is_absolute()
        or "." in path.parts
        or ".." in path.parts
        or any(not part for part in path.parts)
        or path.as_posix() != value
    ):
        raise ValueError("evidence path invalid")
    for part in path.parts:
        if (
            any(ord(character) < 32 for character in part)
            or any(character in WINDOWS_FORBIDDEN_PATH_CHARACTERS for character in part)
            or part.endswith((" ", "."))
            or part.split(".", 1)[0].casefold() in WINDOWS_RESERVED_BASENAMES
        ):
            raise ValueError("evidence path invalid")
    return path


def _resolve_evidence_file(root: Path, relative: object) -> Path:
    safe = _safe_relative_path(relative)
    lexical = root.joinpath(*safe.parts)
    if not lexical.exists():
        raise ValueError("evidence file missing")
    if not lexical.is_file() or lexical.is_symlink():
        raise ValueError("evidence file must be a regular non-symlink file")
    resolved = lexical.resolve(strict=True)
    if resolved != lexical or not _is_within(resolved, root):
        raise ValueError("evidence path invalid")
    return resolved


def _hash_evidence_file(resolved: Path) -> str:
    digest = hashlib.sha256()
    total = 0
    with resolved.open("rb") as handle:
        initial = os.fstat(handle.fileno())
        while True:
            chunk = handle.read(1024 * 1024)
            if not chunk:
                break
            total += len(chunk)
            if total > MAX_EVIDENCE_FILE_BYTES:
                raise ValueError("evidence file size limit exceeded")
            digest.update(chunk)
        final = os.fstat(handle.fileno())
    if total == 0:
        raise ValueError("evidence file must be non-empty")
    if (
        total != initial.st_size
        or final.st_size != initial.st_size
        or final.st_mtime_ns != initial.st_mtime_ns
    ):
        raise ValueError("evidence file changed while hashing")
    return digest.hexdigest().upper()


def _load_evidence_json(
    path: Path, label: str, expected_sha256: str
) -> dict[str, object]:
    if not _sha256(expected_sha256):
        raise ValueError(f"{label} invalid")
    try:
        with path.open("rb") as handle:
            initial = os.fstat(handle.fileno())
            data = handle.read(MAX_AUDIT_JSON_BYTES + 1)
            final = os.fstat(handle.fileno())
    except OSError:
        raise ValueError(f"{label} invalid") from None
    if (
        not data
        or len(data) > MAX_AUDIT_JSON_BYTES
        or len(data) != initial.st_size
        or final.st_size != initial.st_size
        or final.st_mtime_ns != initial.st_mtime_ns
    ):
        raise ValueError(f"{label} invalid")
    actual_sha256 = hashlib.sha256(data).hexdigest().upper()
    if actual_sha256 != expected_sha256:
        raise ValueError(f"{label} changed after hashing")
    try:
        value = load_json_bytes_strict(data)
    except (TypeError, ValueError):
        raise ValueError(f"{label} invalid") from None
    if type(value) is not dict:
        raise ValueError(f"{label} invalid")
    return value


def _validate_export_manifest(
    path: Path, evidence_root: Path, expected_sha256: str
) -> tuple[str, int]:
    value = _load_evidence_json(path, "export manifest", expected_sha256)
    if (
        set(value) != EXPORT_MANIFEST_KEYS
        or value.get("document_type") != "author_strategy_device_export_manifest_v1"
        or value.get("schema_version") != 1
        or value.get("release_target_platforms") != ["windows"]
        or type(value.get("outputs")) is not list
        or not value.get("outputs")
        or type(value.get("limitations")) is not list
        or type(value.get("player_start_allowed")) is not bool
        or type(value.get("production_ready")) is not bool
    ):
        raise ValueError("export manifest invalid")
    executables: list[dict[str, object]] = []
    for output in value["outputs"]:
        if (
            type(output) is not dict
            or set(output) != EXPORT_OUTPUT_KEYS
            or output.get("platform") != "windows"
            or not _nonempty_text(output.get("kind"), 64)
            or not _nonempty_text(output.get("path"), 1024)
            or not _exact_nonnegative_int(output.get("bytes"))
            or not _sha256(output.get("sha256"))
        ):
            raise ValueError("export manifest invalid")
        if output.get("kind") == "executable":
            executables.append(output)
    if len(executables) != 1:
        raise ValueError("export manifest invalid")
    executable = executables[0]
    lexical = Path(os.path.abspath(str(executable["path"])))
    if not _is_within(lexical, evidence_root) or not lexical.is_file() or lexical.is_symlink():
        raise ValueError("export executable invalid")
    resolved = lexical.resolve(strict=True)
    if resolved != lexical or not _is_within(resolved, evidence_root):
        raise ValueError("export executable invalid")
    actual_size = resolved.stat().st_size
    actual_sha256 = _hash_evidence_file(resolved)
    if actual_size != executable["bytes"]:
        raise ValueError("export executable size mismatch")
    if actual_sha256 != executable["sha256"]:
        raise ValueError("export executable hash mismatch")
    return actual_sha256, actual_size


def _validate_network_audit(
    path: Path, expected_sha256: str, executable_sha256: str
) -> dict[str, object]:
    value = _load_evidence_json(path, "network audit", expected_sha256)
    zero_keys = (
        "socket_attempts",
        "dns_attempts",
        "http_attempts",
        "remote_inference_attempts",
        "dynamic_download_attempts",
    )
    if (
        set(value) != NETWORK_AUDIT_KEYS
        or value.get("document_type") != "author_strategy_windows_network_audit_v1"
        or value.get("schema_version") != 1
        or value.get("platform") != "windows"
        or not _identifier(value.get("run_id"))
        or value.get("target_executable_sha256") != executable_sha256
        or value.get("audit_method")
        != "windows_filtering_platform_security_events_5154_5159_v1"
        or not _positive_int_list(value.get("target_process_ids"))
        or value.get("os_network_block_enforced") is not True
        or any(value.get(key) != 0 for key in zero_keys)
        or value.get("firewall_rules_removed") is not True
        or value.get("audit_policy_restored") is not True
        or value.get("passed") is not True
    ):
        raise ValueError("network audit invalid")
    return value


def _validate_process_audit(
    path: Path,
    expected_sha256: str,
    executable_sha256: str,
    run_id: str,
    target_process_ids: list[int],
) -> dict[str, object]:
    value = _load_evidence_json(path, "process audit", expected_sha256)
    if (
        set(value) != PROCESS_AUDIT_KEYS
        or value.get("document_type") != "author_strategy_windows_process_audit_v1"
        or value.get("schema_version") != 1
        or value.get("platform") != "windows"
        or value.get("run_id") != run_id
        or value.get("target_executable_sha256") != executable_sha256
        or value.get("audit_method") != "windows_security_process_creation_4688_v1"
        or value.get("target_process_ids") != target_process_ids
        or value.get("child_process_ids") != []
        or value.get("external_process_attempts") != 0
        or value.get("system_python_required") is not False
        or value.get("sidecar_processes") != []
        or value.get("external_compute_required") is not False
        or value.get("audit_policy_restored") is not True
        or value.get("passed") is not True
    ):
        raise ValueError("process audit invalid")
    return value


def _validate_full_match_audit(
    path: Path, expected_sha256: str, executable_sha256: str, run_id: str
) -> dict[str, object]:
    value = _load_evidence_json(path, "full match audit", expected_sha256)
    cold = value.get("cold_start_msec")
    decisions = value.get("decision_msec")
    zero_keys = (
        "policy_errors",
        "invalid_outputs",
        "same_window_fallbacks",
        "classic_fallbacks",
        "engine_rejections",
    )
    if (
        set(value) != FULL_MATCH_AUDIT_KEYS
        or value.get("document_type") != "author_strategy_windows_full_match_audit_v1"
        or value.get("schema_version") != 1
        or value.get("platform") != "windows"
        or value.get("run_id") != run_id
        or value.get("target_executable_sha256") != executable_sha256
        or not _identifier(value.get("package_id"))
        or not _nonempty_text(value.get("package_version"), 64)
        or not _sha256(value.get("package_archive_sha256"))
        or value.get("signature_scope") != "production_release"
        or value.get("execution_trusted") is not True
        or value.get("ordinary_ui") is not True
        or value.get("real_mouse_input") is not True
        or value.get("complete_match_finished") is not True
        or type(cold) is not list
        or type(decisions) is not list
        or not cold
        or not decisions
        or any(not _exact_nonnegative_int(item) for item in cold)
        or any(not _exact_nonnegative_int(item) for item in decisions)
        or any(
            not _exact_nonnegative_int(value.get(key))
            for key in ("catalog_scan_msec", "match_load_msec", "peak_memory_mib")
        )
        or value.get("policy_calls") != len(decisions)
        or value.get("policy_successes") != len(decisions)
        or any(value.get(key) != 0 for key in zero_keys)
        or not _exact_nonnegative_int(value.get("engine_commits"))
        or value.get("engine_commits") < 1
        or value.get("passed") is not True
    ):
        raise ValueError("full match audit invalid")
    return value


def _validate_rollback_audit(
    path: Path, expected_sha256: str, executable_sha256: str, run_id: str
) -> dict[str, object]:
    value = _load_evidence_json(path, "rollback audit", expected_sha256)
    if (
        set(value) != ROLLBACK_AUDIT_KEYS
        or value.get("document_type") != "author_strategy_windows_rollback_audit_v1"
        or value.get("schema_version") != 1
        or value.get("platform") != "windows"
        or value.get("run_id") != run_id
        or value.get("target_executable_sha256") != executable_sha256
        or value.get("mode_disabled") is not True
        or value.get("user_packages_preserved") is not True
        or value.get("policy_calls_after_disable") != 0
        or value.get("engine_commits_after_disable") != 0
        or value.get("passed") is not True
    ):
        raise ValueError("rollback audit invalid")
    return value


def _validate_evidence_semantics(
    *,
    evidence_root: Path,
    evidence_paths: dict[str, Path],
    evidence_sha256: dict[str, str],
    source: dict[str, object],
) -> None:
    executable_sha256, executable_size = _validate_export_manifest(
        evidence_paths["export_manifest_sha256"],
        evidence_root,
        evidence_sha256["export_manifest_sha256"],
    )
    network = _validate_network_audit(
        evidence_paths["network_audit_sha256"],
        evidence_sha256["network_audit_sha256"],
        executable_sha256,
    )
    run_id = str(network["run_id"])
    target_process_ids = list(network["target_process_ids"])
    process = _validate_process_audit(
        evidence_paths["process_audit_sha256"],
        evidence_sha256["process_audit_sha256"],
        executable_sha256,
        run_id,
        target_process_ids,
    )
    full_match = _validate_full_match_audit(
        evidence_paths["full_match_audit_sha256"],
        evidence_sha256["full_match_audit_sha256"],
        executable_sha256,
        run_id,
    )
    rollback = _validate_rollback_audit(
        evidence_paths["rollback_report_sha256"],
        evidence_sha256["rollback_report_sha256"],
        executable_sha256,
        run_id,
    )
    offline = source["offline"]
    runtime = source["runtime"]
    samples = source["samples"]
    measurements = source["measurements"]
    rollback_claim = source["rollback"]
    expected_package_mib = math.ceil(executable_size / (1024 * 1024))
    if (
        offline.get("network_blocked") is not network.get("os_network_block_enforced")
        or offline.get("complete_match_finished")
        is not full_match.get("complete_match_finished")
        or offline.get("remote_inference_attempts")
        != network.get("remote_inference_attempts")
        or offline.get("dynamic_download_attempts")
        != network.get("dynamic_download_attempts")
        or runtime.get("system_python_required")
        is not process.get("system_python_required")
        or runtime.get("sidecar_processes") != process.get("sidecar_processes")
        or runtime.get("external_compute_required")
        is not process.get("external_compute_required")
        or samples.get("cold_start_msec") != full_match.get("cold_start_msec")
        or samples.get("decision_msec") != full_match.get("decision_msec")
        or measurements.get("catalog_scan_msec") != full_match.get("catalog_scan_msec")
        or measurements.get("match_load_msec") != full_match.get("match_load_msec")
        or measurements.get("peak_memory_mib") != full_match.get("peak_memory_mib")
        or measurements.get("package_mib") != expected_package_mib
        or rollback_claim.get("mode_disabled") is not rollback.get("mode_disabled")
        or rollback_claim.get("user_packages_preserved")
        is not rollback.get("user_packages_preserved")
    ):
        raise ValueError("measurement evidence mismatch")


def _load_measurements(path: Path) -> dict[str, object]:
    value = load_json_strict(path)
    if type(value) is not dict or set(value) != INPUT_KEYS:
        raise ValueError("measurement input invalid")
    if (
        value.get("document_type") != "author_strategy_device_measurement_input_v1"
        or value.get("schema_version") != 1
    ):
        raise ValueError("measurement input invalid")
    for key, expected_keys in INPUT_NESTED_KEYS.items():
        nested = value.get(key)
        if type(nested) is not dict or set(nested) != expected_keys:
            raise ValueError("measurement input invalid")
    samples = value["samples"]
    cold = samples.get("cold_start_msec")
    decisions = samples.get("decision_msec")
    if (
        type(cold) is not list
        or type(decisions) is not list
        or not cold
        or not decisions
        or any(not _exact_nonnegative_int(item) for item in cold)
        or any(not _exact_nonnegative_int(item) for item in decisions)
    ):
        raise ValueError("measurement input invalid")
    return value


def build_device_report(
    *,
    project_root: Path,
    measurements_path: Path,
    evidence_root: Path,
) -> dict[str, object]:
    _, profile = _fixed_profile(project_root)
    evidence_directory = _fixed_evidence_root(evidence_root)
    measurements_file = _measurement_path(measurements_path, evidence_directory)
    source = _load_measurements(measurements_file)

    cold_samples = list(source["samples"]["cold_start_msec"])
    decision_samples = list(source["samples"]["decision_msec"])
    supplied_measurements = source["measurements"]
    evidence_files = source["evidence_files"]
    relative_evidence_paths = [
        evidence_files[key] for key in sorted(INPUT_NESTED_KEYS["evidence_files"])
    ]
    normalized_evidence_paths = [
        _safe_relative_path(value).as_posix() for value in relative_evidence_paths
    ]
    if len({value.casefold() for value in normalized_evidence_paths}) != len(
        normalized_evidence_paths
    ):
        raise ValueError("evidence files must be distinct")
    ordered_evidence_keys = sorted(INPUT_NESTED_KEYS["evidence_files"])
    resolved_evidence_paths = [
        _resolve_evidence_file(evidence_directory, value)
        for value in relative_evidence_paths
    ]
    resolved_by_key = dict(zip(ordered_evidence_keys, resolved_evidence_paths))
    for index, path in enumerate(resolved_evidence_paths):
        if os.path.samefile(path, measurements_file):
            raise ValueError("measurements file cannot be evidence")
        for previous in resolved_evidence_paths[:index]:
            if os.path.samefile(path, previous):
                raise ValueError("evidence files must be distinct")
    evidence = {
        "profile_canonical_sha256": hashlib.sha256(
            canonical_json_v1_bytes(profile)
        ).hexdigest().upper()
    }
    for key, path in zip(
        ordered_evidence_keys, resolved_evidence_paths
    ):
        evidence[key] = _hash_evidence_file(path)

    report: dict[str, object] = {
        "document_type": "author_strategy_device_report_v1",
        "schema_version": 1,
        "profile_id": profile.get("profile_id"),
        "platform": source["platform"],
        "architecture": source["architecture"],
        "offline": dict(source["offline"]),
        "runtime": {
            **dict(source["runtime"]),
            "sidecar_processes": list(source["runtime"]["sidecar_processes"]),
        },
        "samples": {
            "cold_start_msec": cold_samples,
            "decision_msec": decision_samples,
        },
        "measurements": {
            "cold_start_msec": max(cold_samples),
            "catalog_scan_msec": supplied_measurements["catalog_scan_msec"],
            "match_load_msec": supplied_measurements["match_load_msec"],
            "decision_p95_msec": _nearest_rank_p95(decision_samples),
            "peak_memory_mib": supplied_measurements["peak_memory_mib"],
            "package_mib": supplied_measurements["package_mib"],
            "thermal_status_max": supplied_measurements["thermal_status_max"],
            "battery_drain_percent_per_hour": supplied_measurements[
                "battery_drain_percent_per_hour"
            ],
        },
        "rollback": dict(source["rollback"]),
        "evidence": evidence,
    }
    result = evaluate_device_report(profile, report)
    if result.get("accepted") is not True:
        raise ValueError(str(result.get("error_code", "device_report_invalid")))
    _validate_evidence_semantics(
        evidence_root=evidence_directory,
        evidence_paths=resolved_by_key,
        evidence_sha256={key: str(evidence[key]) for key in ordered_evidence_keys},
        source=source,
    )
    return report


def _output_destination(path: Path) -> Path:
    if path.suffix.lower() != ".json":
        raise ValueError("device report destination must use .json suffix")
    lexical = Path(os.path.abspath(path))
    _safe_relative_path(lexical.name)
    parent = lexical.parent.resolve(strict=True)
    if not parent.is_dir() or lexical.parent.is_symlink():
        raise ValueError("device report destination parent invalid")
    destination = parent / lexical.name
    if destination.is_symlink():
        raise ValueError("device report destination symlink forbidden")
    if destination.exists():
        raise ValueError("device report destination already exists")
    return destination


def write_device_report(
    *,
    project_root: Path,
    measurements_path: Path,
    evidence_root: Path,
    output_path: Path,
) -> dict[str, object]:
    report = build_device_report(
        project_root=project_root,
        measurements_path=measurements_path,
        evidence_root=evidence_root,
    )
    destination = _output_destination(output_path)
    handle = None
    try:
        handle = destination.open("xb")
        with handle:
            handle.write(canonical_json_v1_bytes(report))
    except Exception:
        if handle is not None and destination.is_file() and not destination.is_symlink():
            destination.unlink()
        raise
    return report


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Build a formal author-strategy device report from actual evidence files, "
            "using only the fixed product-approved device profile."
        )
    )
    parser.add_argument("--measurements", type=Path, required=True)
    parser.add_argument("--evidence-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        report = write_device_report(
            project_root=ROOT,
            measurements_path=args.measurements,
            evidence_root=args.evidence_root,
            output_path=args.output,
        )
    except (OSError, TypeError, ValueError) as error:
        raise SystemExit(f"formal device report refused: {error}") from None
    print(f"platform={report['platform']}")
    print(f"architecture={report['architecture']}")
    print(f"profile_id={report['profile_id']}")
    print(f"report_sha256={hashlib.sha256(canonical_json_v1_bytes(report)).hexdigest().upper()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
