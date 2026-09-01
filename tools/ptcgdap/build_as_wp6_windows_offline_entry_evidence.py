from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict  # noqa: E402


EVIDENCE = ROOT / "artifacts/ptcgdap/as_wp6_windows_offline_entry"
NORMALIZED_REPORT = EVIDENCE / "windows_offline_entry_report.json"
SUMMARY = EVIDENCE / "evidence_summary.json"
MANIFEST = EVIDENCE / "manifest.json"
TEST_RESULTS = EVIDENCE / "test_results.json"
ENTRY_ROOT = (ROOT / ".tmp/ptcgdap_windows_offline_entry").resolve()
BUILD_ROOT = (ROOT / ".tmp/ptcgdap_device_release").resolve()

DEVICE_MANIFEST_CANONICAL = "C9D1D862BCE47A7A3FF9CDB6C73B59323505E6D88D0B04A4E097A5A25CEADD65"
LOCAL_EXECUTOR_CANONICAL = "DCFA65A979F1525BD690D6919A80C0FE0858B819B7A4DA06795EB8B38AC824B5"
AUTHOR_ARCHIVE_SHA256 = "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"
REQUIRED_DEVICE_PATHS = (
    "contracts/ptcgdap/device_manifest_v1.schema.json",
    "contracts/ptcgdap/device_manifest_v1_profile.json",
    "contracts/ptcgdap/device_manifest_v1_bundle.json",
    "data/ptcgdap/marnie_windows_device_manifest_v1.json",
    "scripts/ai/ptcgdap/runtime/local/DeviceManifest.gdc",
    "scripts/ai/ptcgdap/runtime/local/DeviceManifest.gd.remap",
)

FILES = (
    "artifacts/ptcgdap/as_wp6_windows_offline_entry/README.md",
    "artifacts/ptcgdap/as_wp6_windows_offline_entry/known_gaps.md",
    "artifacts/ptcgdap/as_wp6_windows_offline_entry/test_results.json",
    "artifacts/ptcgdap/as_wp6_windows_offline_entry/windows_offline_entry_report.json",
    "artifacts/ptcgdap/as_wp6_windows_offline_entry/evidence_summary.json",
    "contracts/ptcgdap/device_manifest_v1.schema.json",
    "contracts/ptcgdap/device_manifest_v1_profile.json",
    "contracts/ptcgdap/device_manifest_v1_bundle.json",
    "data/ptcgdap/marnie_windows_device_manifest_v1.json",
    "scripts/ai/ptcgdap/runtime/local/DeviceManifest.gd",
    "scripts/tools/export_ptcgdap_device_release.ps1",
    "scripts/tools/run_ptcgdap_windows_ui_match.ps1",
    "scripts/tools/run_ptcgdap_windows_offline_entry.ps1",
    "tests/ptcgdap/test_windows_offline_entry.py",
    "tests/ptcgdap/test_as_wp6_windows_offline_entry_evidence.py",
    "tools/ptcgdap/build_as_wp6_windows_offline_entry_evidence.py",
    "docs/ptcgdap/07-decisions-risks-and-open-questions.md",
    "docs/ptcgdap/08-author-strategy-package-mode.md",
    "docs/ptcgdap/09-author-strategy-package-engineering-handoff.md",
    "docs/ptcgdap/STATUS.md",
    "docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md",
)


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def canonical_sha(path: Path) -> str:
    return sha(canonical_json_v1_bytes(load_json_strict(path)))


def render(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def file_entry(relative: str) -> dict[str, object]:
    path = ROOT / relative
    value = path.read_bytes()
    row: dict[str, object] = {"path": relative, "bytes": len(value), "raw_sha256": sha(value)}
    if path.suffix.lower() == ".json":
        row["canonical_sha256"] = canonical_sha(path)
    return row


def _resolved_file(value: Any, root: Path, label: str) -> Path:
    if type(value) is not str or not value:
        raise ValueError(f"{label} path invalid")
    path = Path(value).resolve(strict=True)
    if not path.is_file() or path.is_symlink() or not path.is_relative_to(root):
        raise ValueError(f"{label} path invalid")
    return path


def normalize(source_path: Path) -> dict[str, object]:
    source_path = source_path.resolve(strict=True)
    if not source_path.is_relative_to(ENTRY_ROOT) or source_path.is_symlink():
        raise ValueError("D055 source report path invalid")
    source = load_json_strict(source_path)
    if (
        type(source) is not dict
        or source.get("document_type") != "author_strategy_windows_offline_entry_report_v1"
        or source.get("schema_version") != 1
        or source.get("passed") is not True
    ):
        raise ValueError("D055 source report invalid")
    phases = source.get("phases")
    claims = source.get("claims")
    if type(phases) is not dict or type(claims) is not dict:
        raise ValueError("D055 source report incomplete")
    build = phases.get("build")
    install = phases.get("install")
    launch = phases.get("launch")
    if any(type(value) is not dict or value.get("passed") is not True for value in (build, install, launch)):
        raise ValueError("D055 phase failed")
    assert isinstance(build, dict)
    assert isinstance(install, dict)
    assert isinstance(launch, dict)
    expected_claims = {
        "project_owned_entry": True,
        "windows_x86_64_only": True,
        "development_only": True,
        "application_network_disabled": True,
        "defensive_dead_proxy_environment": True,
        "player_runtime_system_python_required": False,
        "os_network_isolation_proven": False,
        "device_profile_approved": False,
        "production_ready": False,
        "a5_claimed": False,
        "android_claimed": False,
    }
    if claims != expected_claims:
        raise ValueError("D055 claims widened")

    export_manifest_path = _resolved_file(build.get("export_manifest_path"), BUILD_ROOT, "export manifest")
    inventory_path = _resolved_file(build.get("inventory_path"), BUILD_ROOT, "inventory")
    if sha(export_manifest_path.read_bytes()) != build.get("export_manifest_sha256"):
        raise ValueError("D055 export manifest hash mismatch")
    if sha(inventory_path.read_bytes()) != build.get("inventory_sha256"):
        raise ValueError("D055 inventory hash mismatch")
    export_manifest = load_json_strict(export_manifest_path)
    inventory = load_json_strict(inventory_path)
    if (
        type(export_manifest) is not dict
        or export_manifest.get("document_type") != "author_strategy_device_export_manifest_v1"
        or export_manifest.get("release_target_platforms") != ["windows"]
        or export_manifest.get("player_start_allowed") is not False
        or export_manifest.get("production_ready") is not False
        or type(inventory) is not dict
        or inventory.get("accepted") is not True
        or inventory.get("missing_paths") != []
        or build.get("required_device_member_count") != len(REQUIRED_DEVICE_PATHS)
    ):
        raise ValueError("D055 build witness invalid")
    members = {row.get("path"): row for row in inventory.get("members", []) if type(row) is dict}
    member_rows = []
    for relative in REQUIRED_DEVICE_PATHS:
        row = members.get(relative)
        if type(row) is not dict or type(row.get("bytes")) is not int or row["bytes"] <= 0:
            raise ValueError(f"D055 inventory member missing: {relative}")
        digest = row.get("sha256")
        if type(digest) is not str or len(digest) != 64:
            raise ValueError(f"D055 inventory member hash invalid: {relative}")
        source_member = ROOT / relative
        if source_member.is_file() and sha(source_member.read_bytes()) != digest:
            raise ValueError(f"D055 inventory member drift: {relative}")
        member_rows.append({"path": relative, "bytes": row["bytes"], "raw_sha256": digest})

    install_manifest_path = _resolved_file(install.get("install_manifest_path"), ENTRY_ROOT, "install manifest")
    install_manifest = load_json_strict(install_manifest_path)
    if (
        type(install_manifest) is not dict
        or install_manifest.get("document_type") != "author_strategy_windows_standalone_install_v1"
        or install_manifest.get("fresh_install_directory") is not True
        or install_manifest.get("device_manifest_canonical_sha256") != DEVICE_MANIFEST_CANONICAL
    ):
        raise ValueError("D055 install manifest invalid")
    installed_executable = _resolved_file(
        install_manifest.get("installed_executable"), ENTRY_ROOT, "installed executable"
    )
    installed_value = installed_executable.read_bytes()
    installed_sha = sha(installed_value)
    if (
        installed_sha != install.get("executable_sha256")
        or installed_sha != install_manifest.get("installed_executable_sha256")
        or len(installed_value) != install.get("executable_bytes")
        or len(installed_value) != install_manifest.get("installed_executable_bytes")
        or install.get("fresh_install_directory") is not True
        or install.get("device_manifest_canonical_sha256") != DEVICE_MANIFEST_CANONICAL
    ):
        raise ValueError("D055 installed executable drift")

    ui_report_path = _resolved_file(launch.get("ui_report_path"), ENTRY_ROOT, "UI report")
    if sha(ui_report_path.read_bytes()) != launch.get("ui_report_sha256"):
        raise ValueError("D055 UI report hash mismatch")
    ui = load_json_strict(ui_report_path)
    engine = ui.get("engine_report") if type(ui) is dict else None
    audit = engine.get("author_audit") if type(engine) is dict else None
    failure_keys = (
        "policy_errors", "invalid_outputs", "same_window_fallbacks", "classic_fallbacks",
        "engine_rejections", "external_process_attempts",
    )
    failure_total = sum(int(audit.get(key, -1)) for key in failure_keys) if type(audit) is dict else -1
    if (
        type(ui) is not dict
        or type(engine) is not dict
        or type(audit) is not dict
        or ui.get("passed") is not True
        or ui.get("real_mouse_input_proven") is not True
        or ui.get("application_network_disabled") is not True
        or ui.get("network_isolation_proven") is not False
        or engine.get("complete_match_finished") is not True
        or engine.get("is_clean") is not True
        or audit.get("policy_calls") != launch.get("policy_calls")
        or audit.get("policy_successes") != launch.get("policy_successes")
        or audit.get("engine_commits") != launch.get("engine_commits")
        or audit.get("policy_calls") != audit.get("policy_successes")
        or int(audit.get("policy_calls", 0)) <= 0
        or int(audit.get("engine_commits", 0)) <= 0
        or failure_total != 0
        or launch.get("failure_counters_total") != 0
        or audit.get("local_policy_executor_manifest_canonical_sha256") != LOCAL_EXECUTOR_CANONICAL
        or audit.get("archive_sha256") != AUTHOR_ARCHIVE_SHA256
        or audit.get("model_backend") != "none"
        or audit.get("production_ready") is not False
        or ui.get("a5_claimed") is not False
    ):
        raise ValueError("D055 launch witness invalid")
    screenshots = ui.get("screenshots")
    if type(screenshots) is not dict or len(screenshots) < 5:
        raise ValueError("D055 screenshots missing")
    screenshot_rows = []
    for name in sorted(screenshots):
        path = _resolved_file(screenshots[name], ENTRY_ROOT, f"screenshot {name}")
        value = path.read_bytes()
        screenshot_rows.append({"name": name, "bytes": len(value), "raw_sha256": sha(value)})
    return {
        "document_type": "as_wp6_windows_offline_entry_report_v1",
        "schema_version": 1,
        "decision_id": "D055",
        "accepted": True,
        "source_report_raw_sha256": sha(source_path.read_bytes()),
        "run_id": source["run_id"],
        "build_export_manifest_raw_sha256": sha(export_manifest_path.read_bytes()),
        "build_inventory_raw_sha256": sha(inventory_path.read_bytes()),
        "required_device_member_count": len(REQUIRED_DEVICE_PATHS),
        "required_device_members": member_rows,
        "fresh_install_directory": True,
        "installed_executable_bytes": len(installed_value),
        "installed_executable_raw_sha256": installed_sha,
        "device_manifest_canonical_sha256": DEVICE_MANIFEST_CANONICAL,
        "ordinary_ui": True,
        "real_mouse_input_proven": True,
        "complete_match_finished": True,
        "policy_calls": int(audit["policy_calls"]),
        "policy_successes": int(audit["policy_successes"]),
        "engine_commits": int(audit["engine_commits"]),
        "failure_counters_total": 0,
        "local_policy_executor_manifest_canonical_sha256": LOCAL_EXECUTOR_CANONICAL,
        "application_network_disabled": True,
        "defensive_dead_proxy_environment": True,
        "player_runtime_system_python_required": False,
        "working_directory_is_install_root": True,
        "screenshots": screenshot_rows,
        "os_network_isolation_proven": False,
        "device_profile_approved": False,
        "production_ready": False,
        "a5_claimed": False,
        "android_claimed": False,
    }


def build_summary() -> dict[str, object]:
    report = load_json_strict(NORMALIZED_REPORT)
    results = load_json_strict(TEST_RESULTS)
    if (
        type(report) is not dict
        or report.get("document_type") != "as_wp6_windows_offline_entry_report_v1"
        or report.get("decision_id") != "D055"
        or report.get("accepted") is not True
        or report.get("device_manifest_canonical_sha256") != DEVICE_MANIFEST_CANONICAL
        or report.get("os_network_isolation_proven") is not False
        or report.get("device_profile_approved") is not False
        or report.get("production_ready") is not False
        or report.get("a5_claimed") is not False
        or report.get("android_claimed") is not False
        or type(results) is not dict
        or results.get("python", {}).get("passed") != 4
        or results.get("python", {}).get("failed") != 0
        or results.get("windows_entry", {}).get("passed") is not True
    ):
        raise ValueError("D055 evidence inputs invalid")
    return {
        "document_type": "as_wp6_windows_offline_entry_evidence_summary_v1",
        "schema_version": 1,
        "decision_id": "D055",
        "work_package": "AS-WP6/P6-07",
        "status": "windows_project_offline_entry_complete",
        "generated_on": "2026-08-15",
        "validation": {
            "python_passed": 4,
            "fresh_windows_runs": 1,
            "build_passed": 1,
            "install_passed": 1,
            "ordinary_ui_terminal_games": 1,
            "policy_successes": report["policy_successes"],
            "engine_commits": report["engine_commits"],
            "failure_counters_total": report["failure_counters_total"],
        },
        "claims": {
            "p6_07_windows_project_entry": True,
            "application_network_disabled": True,
            "player_runtime_system_python_required": False,
            "os_network_isolation": False,
            "device_profile_approved": False,
            "production_ready": False,
            "a2_claimed": False,
            "a5_claimed": False,
            "android_claimed": False,
        },
    }


def build_manifest() -> dict[str, object]:
    return {
        "document_type": "as_wp6_windows_offline_entry_evidence_manifest_v1",
        "schema_version": 1,
        "decision_id": "D055",
        "files": [file_entry(path) for path in FILES],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--write", action="store_true")
    group.add_argument("--check", action="store_true")
    parser.add_argument("--source-report", type=Path)
    args = parser.parse_args()
    if args.write:
        if args.source_report is not None:
            NORMALIZED_REPORT.write_bytes(render(normalize(args.source_report)))
        elif not NORMALIZED_REPORT.is_file():
            raise SystemExit("--source-report is required when the normalized D055 report is missing")
        elif NORMALIZED_REPORT.read_bytes() != render(load_json_strict(NORMALIZED_REPORT)):
            raise SystemExit("D055 normalized report drift")
        SUMMARY.write_bytes(render(build_summary()))
        MANIFEST.write_bytes(render(build_manifest()))
        print("D055 evidence written")
    else:
        if args.source_report is not None:
            raise SystemExit("--source-report is only valid with --write")
        if NORMALIZED_REPORT.read_bytes() != render(load_json_strict(NORMALIZED_REPORT)):
            raise SystemExit("D055 normalized report drift")
        if SUMMARY.read_bytes() != render(build_summary()):
            raise SystemExit("D055 evidence summary drift")
        if MANIFEST.read_bytes() != render(build_manifest()):
            raise SystemExit("D055 evidence manifest drift")
        print("D055 evidence verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
