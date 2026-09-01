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
from tests.ptcgdap.dragapult_acceptance_rollback import restore_pre_dragapult_bytes  # noqa: E402


MANIFEST_PATH = ROOT / "artifacts/ptcgdap/as_wp6/manifest.json"
D051_RESULTS_PATH = ROOT / "artifacts/ptcgdap/as_wp6_policy_package_v1/test_results.json"
D052_RESULTS_PATH = ROOT / "artifacts/ptcgdap/as_wp6_policy_executor_conformance/test_results.json"
D053_RESULTS_PATH = ROOT / "artifacts/ptcgdap/as_wp6_local_policy_executor/test_results.json"
D054_RESULTS_PATH = ROOT / "artifacts/ptcgdap/as_wp6_device_manifest/test_results.json"
D055_RESULTS_PATH = ROOT / "artifacts/ptcgdap/as_wp6_windows_offline_entry/test_results.json"
D056_RESULTS_PATH = ROOT / "artifacts/ptcgdap/as_wp6_windows_profile_qualification/test_results.json"
REFRESHED_AT = "2026-08-15T03:30:00+08:00"
SIMPLE_BOUND_MANIFESTS = (
    ROOT / "artifacts/ptcgdap/as_wp6_windows_deterministic_export/manifest.json",
    ROOT / "artifacts/ptcgdap/as_wp6_windows_player_owner/manifest.json",
)

ADDITIONAL_PATHS: dict[str, tuple[str, ...]] = {
    "evidence_files": (
        "artifacts/ptcgdap/as_wp6_policy_package_v1/manifest.json",
        "artifacts/ptcgdap/as_wp6_policy_executor_conformance/manifest.json",
        "artifacts/ptcgdap/as_wp6_local_policy_executor/manifest.json",
        "artifacts/ptcgdap/as_wp6_device_manifest/manifest.json",
        "artifacts/ptcgdap/as_wp6_windows_offline_entry/manifest.json",
        "artifacts/ptcgdap/as_wp6_windows_profile_qualification/manifest.json",
        "artifacts/ptcgdap/as_wp6_windows_profile_approval/manifest.json",
        "artifacts/ptcgdap/as_wp6_author_developer_workbench/manifest.json",
    ),
    "documentation_hashes": (
        "docs/ptcgdap/10-author-strategy-developer-guide.md",
    ),
    "implementation_hashes": (
        "contracts/ptcgdap/policy_package_v1.schema.json",
        "contracts/ptcgdap/policy_package_v1_profile.json",
        "contracts/ptcgdap/policy_package_v1_bundle.json",
        "data/ptcgdap/marnie_windows_policy_package_v1.json",
        "scripts/ai/ptcgdap/policy_package.py",
        "scripts/ai/ptcgdap/runtime/local/PolicyPackageManifest.gd",
        "scripts/ai/ptcgdap/acceptance/AuthorStrategyWindowsExportMatchAcceptance.gd",
        "tools/ptcgdap/build_policy_package_v1.py",
        "tools/ptcgdap/build_as_wp6_policy_package_evidence.py",
        "contracts/ptcgdap/policy_executor_conformance_v1.schema.json",
        "contracts/ptcgdap/policy_executor_conformance_v1_profile.json",
        "contracts/ptcgdap/policy_executor_conformance_v1_vectors.json",
        "contracts/ptcgdap/policy_executor_conformance_v1_bundle.json",
        "scripts/ai/ptcgdap/policy_executor_conformance.py",
        "scripts/ai/ptcgdap/runtime/local/PolicyExecutorConformance.gd",
        "tools/ptcgdap/build_policy_executor_conformance_v1.py",
        "tools/ptcgdap/run_policy_executor_conformance.py",
        "tools/ptcgdap/build_as_wp6_policy_executor_conformance_evidence.py",
        "contracts/ptcgdap/local_policy_executor_v1.schema.json",
        "contracts/ptcgdap/local_policy_executor_v1_profile.json",
        "contracts/ptcgdap/local_policy_executor_v1_bundle.json",
        "data/ptcgdap/marnie_windows_local_policy_executor_v1.json",
        "scripts/ai/ptcgdap/runtime/local/LocalPolicyExecutor.gd",
        "scripts/ai/ptcgdap/runtime/local/LocalPolicyExecutorManifest.gd",
        "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorLocalExecutorBattleOwner.gd",
        "scripts/ui/battle/ai/BattleDecisionOwnerFactory.gd",
        "tools/ptcgdap/build_local_policy_executor_v1.py",
        "tools/ptcgdap/build_as_wp6_local_policy_executor_evidence.py",
        "contracts/ptcgdap/device_manifest_v1.schema.json",
        "contracts/ptcgdap/device_manifest_v1_profile.json",
        "contracts/ptcgdap/device_manifest_v1_bundle.json",
        "data/ptcgdap/marnie_windows_device_manifest_v1.json",
        "scripts/ai/ptcgdap/runtime/local/DeviceManifest.gd",
        "tools/ptcgdap/build_device_manifest_v1.py",
        "tools/ptcgdap/build_as_wp6_device_manifest_evidence.py",
        "scripts/tools/run_ptcgdap_windows_offline_entry.ps1",
        "tools/ptcgdap/build_as_wp6_windows_offline_entry_evidence.py",
        "scripts/tools/run_ptcgdap_windows_profile_qualification.ps1",
        "tools/ptcgdap/build_windows_profile_qualification.py",
        "tools/ptcgdap/build_as_wp6_windows_profile_qualification_evidence.py",
        "tools/ptcgdap/build_as_wp6_windows_profile_approval_evidence.py",
        "tools/ptcgdap/build_author_strategy_device_report.py",
        "tools/ptcgdap/author_strategy_developer.py",
        "tools/ptcgdap/build_as_wp6_author_developer_workbench_evidence.py",
        "tools/ptcgdap/refresh_as_wp6_release_evidence.py",
    ),
    "validation_hashes": (
        "tests/ptcgdap/test_policy_package_v1.py",
        "tests/ptcgdap/test_as_wp6_policy_package_evidence.py",
        "tests/ptcgdap/test_policy_executor_conformance_v1.py",
        "tests/ptcgdap/test_as_wp6_policy_executor_conformance_evidence.py",
        "tests/ptcgdap/godot/test_policy_executor_conformance.gd",
        "tests/ptcgdap/test_local_policy_executor_v1.py",
        "tests/ptcgdap/test_as_wp6_local_policy_executor_evidence.py",
        "tests/ptcgdap/godot/test_local_policy_executor.gd",
        "tests/ptcgdap/test_device_manifest_v1.py",
        "tests/ptcgdap/test_as_wp6_device_manifest_evidence.py",
        "tests/ptcgdap/godot/test_device_manifest.gd",
        "tests/ptcgdap/test_windows_offline_entry.py",
        "tests/ptcgdap/test_as_wp6_windows_offline_entry_evidence.py",
        "tests/ptcgdap/test_windows_profile_qualification.py",
        "tests/ptcgdap/test_as_wp6_windows_profile_qualification_evidence.py",
        "tests/ptcgdap/test_as_wp6_windows_profile_approval_evidence.py",
        "tests/ptcgdap/test_author_strategy_developer_tool.py",
        "tests/ptcgdap/test_as_wp6_author_developer_workbench_evidence.py",
        "tests/ptcgdap/test_author_strategy_device_report_builder.py",
        "tests/ptcgdap/test_author_strategy_windows_player_owner_evidence.py",
        "tests/ptcgdap/godot/test_author_strategy_export_match_acceptance.gd",
        "tests/ptcgdap/godot/run_author_strategy_package_rules_e2e.gd",
        "tests/ptcgdap/godot/run_author_strategy_windows_player_owner_e2e.gd",
        "tests/ptcgdap/godot/support/MarniePackageDevelopmentAIOpponent.gd",
    ),
}


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _entry(relative_path: str) -> dict[str, object]:
    path = ROOT / relative_path
    current = path.read_bytes()
    historical = restore_pre_dragapult_bytes(relative_path, current)
    if historical is None:
        raise RuntimeError(f"missing AS-WP6 evidence input: {relative_path}")
    result: dict[str, object] = {
        "path": relative_path,
        "bytes": len(historical),
        "raw_sha256": _sha(historical),
    }
    if path.suffix.lower() == ".json":
        result["canonical_sha256"] = _sha(canonical_json_v1_bytes(load_json_strict(path)))
    return result


def _refresh_group(manifest: dict[str, Any], group: str) -> None:
    existing = manifest.get(group)
    if type(existing) is not list:
        raise RuntimeError(f"invalid AS-WP6 manifest group: {group}")
    paths: list[str] = []
    for row in existing:
        if type(row) is not dict or type(row.get("path")) is not str:
            raise RuntimeError(f"invalid AS-WP6 manifest row: {group}")
        path = row["path"]
        if path not in paths:
            paths.append(path)
    for path in ADDITIONAL_PATHS.get(group, ()):
        if path not in paths:
            paths.append(path)
    manifest[group] = [_entry(path) for path in paths]


def _refresh_test_summary(manifest: dict[str, Any]) -> None:
    results = load_json_strict(D051_RESULTS_PATH)
    if type(results) is not dict:
        raise RuntimeError("invalid D051 test results")
    summary = manifest.get("test_summary")
    if type(summary) is not dict:
        raise RuntimeError("invalid AS-WP6 test summary")
    focused = results.get("focused")
    real_rules = results.get("real_rules")
    full = results.get("full_regression")
    if type(focused) is not list or type(real_rules) is not dict or type(full) is not dict:
        raise RuntimeError("invalid D051 validation summary")
    summary["d051_policy_package_focused_passed"] = sum(
        int(row.get("passed", 0)) for row in focused if type(row) is dict
    )
    summary["d051_editor_terminal_games"] = int(real_rules.get("editor_games", 0))
    summary["d051_exported_terminal_games"] = int(real_rules.get("exported_games", 0))
    summary["d051_policy_errors_invalid_fallbacks_rejections"] = int(
        real_rules.get("errors_invalid_fallbacks_rejections", -1)
    )
    if full.get("status") == "passed":
        for source, destination in (
            ("python_passed", "d051_final_python_full_passed"),
            ("godot_ai_passed", "d051_final_godot_ai_passed"),
            ("godot_functional_ui_passed", "d051_final_godot_functional_ui_passed"),
        ):
            value = full.get(source)
            if type(value) is not int or value <= 0:
                raise RuntimeError(f"invalid D051 full-regression count: {source}")
            summary[destination] = value

    d052_results = load_json_strict(D052_RESULTS_PATH)
    if type(d052_results) is not dict:
        raise RuntimeError("invalid D052 test results")
    d052_python = d052_results.get("python")
    d052_godot = d052_results.get("godot")
    d052_coverage = d052_results.get("coverage")
    if type(d052_python) is not dict or type(d052_godot) is not dict or type(d052_coverage) is not dict:
        raise RuntimeError("invalid D052 validation summary")
    for source, destination, owner in (
        ("passed", "d052_python_owner_passed", d052_python),
        ("passed", "d052_godot_owner_passed", d052_godot),
        ("parent_vector_cases", "d052_parent_vector_cases", d052_coverage),
        ("p6_probe_cases", "d052_p6_probe_cases", d052_coverage),
        ("mismatches", "d052_mismatches", d052_coverage),
        ("skips", "d052_skips", d052_coverage),
        ("operator_cases", "d052_operator_cases", d052_coverage),
        ("operator_skips", "d052_operator_skips", d052_coverage),
    ):
        value = owner.get(source)
        if type(value) is not int or value < 0:
            raise RuntimeError(f"invalid D052 validation count: {source}")
        summary[destination] = value

    d055_results = load_json_strict(D055_RESULTS_PATH)
    if type(d055_results) is not dict:
        raise RuntimeError("invalid D055 test results")
    d055_python = d055_results.get("python")
    d055_entry = d055_results.get("windows_entry")
    if type(d055_python) is not dict or type(d055_entry) is not dict:
        raise RuntimeError("invalid D055 validation summary")
    for source, destination, owner in (
        ("passed", "d055_python_entry_passed", d055_python),
        ("required_device_member_count", "d055_required_device_member_count", d055_entry),
        ("policy_successes", "d055_policy_successes", d055_entry),
        ("engine_commits", "d055_engine_commits", d055_entry),
        ("failure_counters_total", "d055_failure_counters_total", d055_entry),
    ):
        value = owner.get(source)
        if type(value) is not int or value < 0:
            raise RuntimeError(f"invalid D055 validation count: {source}")
        summary[destination] = value
    for key in ("passed", "build_passed", "install_passed", "launch_passed"):
        if d055_entry.get(key) is not True:
            raise RuntimeError(f"D055 entry phase failed: {key}")

    d056_results = load_json_strict(D056_RESULTS_PATH)
    if type(d056_results) is not dict:
        raise RuntimeError("invalid D056 test results")
    d056_focused = d056_results.get("focused_green")
    d056_regression = d056_results.get("release_device_regression")
    d056_real = d056_results.get("real_windows_qualification")
    d056_full = d056_results.get("full_python_regression")
    if any(type(value) is not dict for value in (d056_focused, d056_regression, d056_real, d056_full)):
        raise RuntimeError("invalid D056 validation summary")
    assert isinstance(d056_focused, dict)
    assert isinstance(d056_regression, dict)
    assert isinstance(d056_real, dict)
    assert isinstance(d056_full, dict)
    for source, destination, owner in (
        ("passed", "d056_python_focused_passed", d056_focused),
        ("passed", "d056_release_device_regression_passed", d056_regression),
        ("ordinary_ui_terminal_games", "d056_ordinary_ui_terminal_games", d056_real),
        ("decision_samples", "d056_decision_samples", d056_real),
        ("policy_successes", "d056_policy_successes", d056_real),
        ("engine_commits", "d056_engine_commits", d056_real),
        ("failure_counters_total", "d056_failure_counters_total", d056_real),
        ("candidate_thresholds_met", "d056_candidate_thresholds_met", d056_real),
        ("candidate_thresholds_failed", "d056_candidate_thresholds_failed", d056_real),
        ("passed", "d056_final_python_full_passed", d056_full),
    ):
        value = owner.get(source)
        if type(value) is not int or value < 0:
            raise RuntimeError(f"invalid D056 validation count: {source}")
        summary[destination] = value
    if d056_real.get("passed") is not True:
        raise RuntimeError("D056 real Windows qualification did not pass")

    d054_results = load_json_strict(D054_RESULTS_PATH)
    if type(d054_results) is not dict:
        raise RuntimeError("invalid D054 test results")
    d054_python = d054_results.get("python")
    d054_godot = d054_results.get("godot")
    d054_parent = d054_results.get("parent_windows_ordinary_ui")
    if any(type(value) is not dict for value in (d054_python, d054_godot, d054_parent)):
        raise RuntimeError("invalid D054 validation summary")
    assert isinstance(d054_python, dict)
    assert isinstance(d054_godot, dict)
    assert isinstance(d054_parent, dict)
    for source, destination, owner in (
        ("passed", "d054_python_device_manifest_passed", d054_python),
        ("passed", "d054_godot_device_manifest_passed", d054_godot),
        ("terminal_games", "d054_parent_exported_terminal_games", d054_parent),
        ("policy_successes", "d054_parent_policy_successes", d054_parent),
        ("engine_commits", "d054_parent_engine_commits", d054_parent),
        ("failure_counters_total", "d054_parent_failure_counters_total", d054_parent),
    ):
        value = owner.get(source)
        if type(value) is not int or value < 0:
            raise RuntimeError(f"invalid D054 validation count: {source}")
        summary[destination] = value

    d053_results = load_json_strict(D053_RESULTS_PATH)
    if type(d053_results) is not dict:
        raise RuntimeError("invalid D053 test results")
    d053_python = d053_results.get("python")
    d053_godot = d053_results.get("godot_local_executor")
    d053_regression = d053_results.get("godot_player_owner_regression")
    d053_ui = d053_results.get("windows_ordinary_ui")
    d053_full = d053_results.get("full_regression")
    if any(type(value) is not dict for value in (d053_python, d053_godot, d053_regression, d053_ui, d053_full)):
        raise RuntimeError("invalid D053 validation summary")
    assert isinstance(d053_python, dict)
    assert isinstance(d053_godot, dict)
    assert isinstance(d053_regression, dict)
    assert isinstance(d053_ui, dict)
    assert isinstance(d053_full, dict)
    for source, destination, owner in (
        ("passed", "d053_python_owner_passed", d053_python),
        ("passed", "d053_godot_local_executor_passed", d053_godot),
        ("passed", "d053_godot_player_owner_regression_passed", d053_regression),
        ("terminal_games", "d053_exported_ui_terminal_games", d053_ui),
        ("policy_successes", "d053_exported_ui_policy_successes", d053_ui),
        ("engine_commits", "d053_exported_ui_engine_commits", d053_ui),
        ("failure_counters_total", "d053_exported_ui_failure_counters_total", d053_ui),
    ):
        value = owner.get(source)
        if type(value) is not int or value < 0:
            raise RuntimeError(f"invalid D053 validation count: {source}")
        summary[destination] = value
    if d053_ui.get("passed") is not True:
        raise RuntimeError("D053 exported UI acceptance did not pass")
    for key, destination in (
        ("python", "d053_final_python_full_passed"),
        ("godot_ai", "d053_final_godot_ai_passed"),
        ("godot_functional_ui", "d053_final_godot_functional_ui_passed"),
    ):
        owner = d053_full.get(key)
        value = owner.get("passed") if type(owner) is dict else None
        failed = owner.get("failed") if type(owner) is dict else None
        if type(value) is not int or value <= 0 or failed != 0:
            raise RuntimeError(f"invalid D053 full-regression count: {key}")
        summary[destination] = value


def _build_simple_bound_manifest(path: Path) -> dict[str, Any]:
    manifest = load_json_strict(path)
    if type(manifest) is not dict or type(manifest.get("files")) is not list:
        raise RuntimeError(f"invalid bound manifest: {path.relative_to(ROOT).as_posix()}")
    evidence_root = path.parent
    refreshed: list[dict[str, object]] = []
    for row in manifest["files"]:
        if type(row) is not dict or type(row.get("path")) is not str:
            raise RuntimeError(f"invalid bound-manifest row: {path.relative_to(ROOT).as_posix()}")
        relative = row["path"]
        source = ROOT / relative if "/" in relative else evidence_root / relative
        value = source.read_bytes()
        refreshed.append({"path": relative, "bytes": len(value), "sha256": _sha(value)})
    manifest["files"] = refreshed
    return manifest


def _sync_simple_bound_manifests(*, write: bool) -> None:
    for path in SIMPLE_BOUND_MANIFESTS:
        expected = _render(_build_simple_bound_manifest(path))
        if write:
            path.write_bytes(expected)
        elif path.read_bytes() != expected:
            raise SystemExit(f"bound evidence manifest drift: {path.relative_to(ROOT).as_posix()}")


def build() -> dict[str, Any]:
    manifest = load_json_strict(MANIFEST_PATH)
    if type(manifest) is not dict or manifest.get("work_package") != "AS-WP6":
        raise RuntimeError("invalid AS-WP6 release manifest")
    manifest["refreshed_at"] = REFRESHED_AT
    for group in (
        "evidence_files",
        "documentation_hashes",
        "implementation_hashes",
        "validation_hashes",
    ):
        _refresh_group(manifest, group)
    _refresh_test_summary(manifest)
    return manifest


def _render(value: dict[str, Any]) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--write", action="store_true")
    group.add_argument("--check", action="store_true")
    args = parser.parse_args()
    _sync_simple_bound_manifests(write=args.write)
    rendered = _render(build())
    if args.write:
        MANIFEST_PATH.write_bytes(rendered)
        document = load_json_strict(MANIFEST_PATH)
        print("manifest_raw_sha256=" + _sha(rendered))
        print("manifest_canonical_sha256=" + _sha(canonical_json_v1_bytes(document)))
    elif MANIFEST_PATH.read_bytes() != rendered:
        raise SystemExit("AS-WP6 release manifest drift")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
