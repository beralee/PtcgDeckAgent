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


EVIDENCE = ROOT / "artifacts/ptcgdap/as_wp6_local_policy_executor"
NORMALIZED_REPORT = EVIDENCE / "windows_ui_match_report.json"
SUMMARY = EVIDENCE / "evidence_summary.json"
MANIFEST = EVIDENCE / "manifest.json"
TEST_RESULTS = EVIDENCE / "test_results.json"
LOCAL_MANIFEST = ROOT / "data/ptcgdap/marnie_windows_local_policy_executor_v1.json"
PARENT_MANIFEST = ROOT / "data/ptcgdap/marnie_windows_policy_package_v1.json"
ROLLBACK_REPORT = ROOT / "artifacts/ptcgdap/as_wp6_windows_player_owner/player_owner_10_games.json"

LOCAL_MANIFEST_CANONICAL_SHA256 = "6961EEECEEB33459002A40A52AA76AB0243871439D3FDF10B9F1F4927AB6D6E0"
PARENT_MANIFEST_CANONICAL_SHA256 = "3243ABD7937B3F53D8E5D7A887FC90BFBDF9A4D94E4030A3A9BE194C82370FFC"
POST_D053_SEALED_PARENT_UPDATES = {
    "scripts/ai/ptcgdap/runtime/local/PolicyPackageManifest.gd":
        "24A5570491CB0B2DB2B737533652B9713DC508567C3122168015D9D8C8DB84CF",
}

FILES = (
    "artifacts/ptcgdap/as_wp6_local_policy_executor/README.md",
    "artifacts/ptcgdap/as_wp6_local_policy_executor/known_gaps.md",
    "artifacts/ptcgdap/as_wp6_local_policy_executor/test_results.json",
    "artifacts/ptcgdap/as_wp6_local_policy_executor/windows_ui_match_report.json",
    "artifacts/ptcgdap/as_wp6_local_policy_executor/evidence_summary.json",
    "artifacts/ptcgdap/as_wp6_windows_player_owner/player_owner_10_games.json",
    "contracts/ptcgdap/local_policy_executor_v1.schema.json",
    "contracts/ptcgdap/local_policy_executor_v1_profile.json",
    "contracts/ptcgdap/local_policy_executor_v1_bundle.json",
    "data/ptcgdap/marnie_windows_local_policy_executor_v1.json",
    "data/ptcgdap/marnie_windows_policy_package_v1.json",
    "scripts/ai/ptcgdap/runtime/local/LocalPolicyExecutor.gd",
    "scripts/ai/ptcgdap/runtime/local/LocalPolicyExecutorManifest.gd",
    "scripts/ai/ptcgdap/runtime/local/PolicyPackageManifest.gd",
    "scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd",
    "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorLocalExecutorBattleOwner.gd",
    "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd",
    "scripts/ui/battle/ai/BattleDecisionOwnerFactory.gd",
    "tests/ptcgdap/test_local_policy_executor_v1.py",
    "tests/ptcgdap/test_as_wp6_local_policy_executor_evidence.py",
    "tests/ptcgdap/godot/test_local_policy_executor.gd",
    "tests/ptcgdap/godot/test_author_strategy_windows_player_owner.gd",
    "tools/ptcgdap/build_local_policy_executor_v1.py",
    "tools/ptcgdap/build_as_wp6_local_policy_executor_evidence.py",
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
    row: dict[str, object] = {
        "path": relative,
        "bytes": len(value),
        "raw_sha256": sha(value),
    }
    if path.suffix.lower() == ".json":
        try:
            row["canonical_sha256"] = canonical_sha(path)
        except ValueError:
            row["canonical_sha256"] = None
    return row


def normalize_ui_report(path: Path) -> dict[str, object]:
    source = load_json_strict(path)
    if type(source) is not dict or source.get("passed") is not True:
        raise ValueError("D053 UI source report rejected")
    engine = source.get("engine_report")
    audit = engine.get("author_audit") if type(engine) is dict else None
    if type(engine) is not dict or type(audit) is not dict:
        raise ValueError("D053 UI engine report missing")
    failure_keys = (
        "policy_errors", "invalid_outputs", "same_window_fallbacks", "classic_fallbacks",
        "engine_rejections", "external_process_attempts",
    )
    failure_total = sum(int(audit.get(key, -1)) for key in failure_keys)
    if (
        engine.get("is_clean") is not True
        or engine.get("complete_match_finished") is not True
        or audit.get("local_policy_executor_id") != "ptcgdap-local-policy-executor-v1"
        or audit.get("local_policy_executor_version") != "1.0.0"
        or audit.get("local_policy_executor_manifest_canonical_sha256") != LOCAL_MANIFEST_CANONICAL_SHA256
        or audit.get("policy_package_manifest_canonical_sha256") != PARENT_MANIFEST_CANONICAL_SHA256
        or audit.get("policy_calls") != audit.get("policy_successes")
        or int(audit.get("policy_calls", 0)) <= 0
        or int(audit.get("engine_commits", 0)) <= 0
        or failure_total != 0
        or audit.get("restricted_ir_executed") is not True
        or audit.get("policy_engine_object_access") is not False
        or source.get("real_mouse_input_proven") is not True
        or int(source.get("real_mouse_click_count", 0)) < 3
        or source.get("application_network_disabled") is not True
        or source.get("network_isolation_proven") is not False
        or source.get("production_ready") is not False
        or source.get("a5_claimed") is not False
    ):
        raise ValueError("D053 UI semantic witness invalid")
    executable_path = Path(str(source.get("executable", ""))).resolve()
    executable_value = executable_path.read_bytes()
    if sha(executable_value) != source.get("executable_sha256"):
        raise ValueError("D053 exported executable hash mismatch")
    screenshot_rows = []
    screenshots = source.get("screenshots")
    if type(screenshots) is not dict or len(screenshots) < 5:
        raise ValueError("D053 screenshots missing")
    for name in sorted(screenshots):
        screenshot_path = Path(str(screenshots[name])).resolve()
        value = screenshot_path.read_bytes()
        screenshot_rows.append({"name": name, "bytes": len(value), "raw_sha256": sha(value)})
    measurements = source.get("measurements")
    process = source.get("process")
    if type(measurements) is not dict or type(process) is not dict:
        raise ValueError("D053 UI measurements missing")
    decisions = measurements.get("decision_msec")
    if type(decisions) is not list or len(decisions) != int(audit["policy_calls"]):
        raise ValueError("D053 decision timing witness invalid")
    return {
        "document_type": "local_policy_executor_windows_acceptance_report_v1",
        "schema_version": 1,
        "decision_id": "D053",
        "accepted": True,
        "source_report_raw_sha256": sha(path.read_bytes()),
        "executor_id": audit["local_policy_executor_id"],
        "executor_version": audit["local_policy_executor_version"],
        "local_executor_manifest_canonical_sha256": audit["local_policy_executor_manifest_canonical_sha256"],
        "parent_policy_package_manifest_canonical_sha256": audit["policy_package_manifest_canonical_sha256"],
        "exported_executable": {
            "bytes": len(executable_value),
            "raw_sha256": sha(executable_value),
        },
        "ordinary_ui": {
            "real_mouse_input_proven": True,
            "real_mouse_click_count": int(source["real_mouse_click_count"]),
            "author_mode_click_attempts": int(source["author_mode_click_attempts"]),
            "observed_scene_paths": list(engine.get("observed_scene_paths", [])),
        },
        "terminal_games": 1,
        "winner_index": int(engine["winner_index"]),
        "turn_number": int(engine["turn_number"]),
        "win_reason": str(engine["reason"]),
        "policy_calls": int(audit["policy_calls"]),
        "policy_successes": int(audit["policy_successes"]),
        "engine_commits": int(audit["engine_commits"]),
        "failure_counters_total": failure_total,
        "restricted_ir_executed": True,
        "policy_engine_object_access": False,
        "measurements": {
            "cold_start_msec": int(measurements["cold_start_msec"]),
            "catalog_scan_msec": int(measurements["catalog_scan_msec"]),
            "match_load_msec": int(measurements["match_load_msec"]),
            "decision_sample_count": len(decisions),
            "decision_max_msec": max(int(value) for value in decisions),
            "peak_working_set_mib": int(process["peak_working_set_mib"]),
            "approved_profile_evaluation": False,
        },
        "screenshots": screenshot_rows,
        "application_network_disabled": True,
        "network_isolation_proven": False,
        "production_ready": False,
        "a5_claimed": False,
        "android_claimed": False,
    }


def build_summary() -> dict[str, object]:
    report = load_json_strict(NORMALIZED_REPORT)
    results = load_json_strict(TEST_RESULTS)
    rollback_report = load_json_strict(ROLLBACK_REPORT)
    if type(report) is not dict or report.get("accepted") is not True:
        raise ValueError("D053 normalized report invalid")
    if (
        type(results) is not dict
        or results.get("python", {}).get("passed") != 7
        or results.get("python", {}).get("failed") != 0
        or results.get("godot_local_executor", {}).get("passed") != 2
        or results.get("godot_local_executor", {}).get("failed") != 0
        or results.get("godot_player_owner_regression", {}).get("passed") != 10
        or results.get("godot_player_owner_regression", {}).get("failed") != 0
        or results.get("windows_ordinary_ui", {}).get("passed") is not True
    ):
        raise ValueError("D053 test results invalid")
    full = results.get("full_regression")
    if type(full) is not dict:
        raise ValueError("D053 full regression missing")
    for key, expected_passed in (
        ("python", 931),
        ("godot_ai", 1496),
        ("godot_functional_ui", 4976),
    ):
        row = full.get(key)
        if type(row) is not dict or row.get("passed") != expected_passed or row.get("failed") != 0:
            raise ValueError(f"D053 full regression invalid: {key}")
        log_path = row.get("log_path")
        if type(log_path) is str:
            log_text = (ROOT / log_path).read_text(encoding="utf-8", errors="replace")
            if f"Total: {expected_passed} | Passed: {expected_passed} | Failed: 0" not in log_text:
                raise ValueError(f"D053 full regression log invalid: {key}")
    for key in ("godot_local_executor", "godot_player_owner_regression"):
        log_path = ROOT / results[key]["log_path"]
        text = log_path.read_text(encoding="utf-8", errors="replace")
        expected = f"Total: {results[key]['passed']} | Failed: 0"
        if expected not in text:
            raise ValueError(f"D053 focused log invalid: {key}")
    if canonical_sha(LOCAL_MANIFEST) != LOCAL_MANIFEST_CANONICAL_SHA256:
        raise ValueError("D053 local executor manifest drift")
    if canonical_sha(PARENT_MANIFEST) != PARENT_MANIFEST_CANONICAL_SHA256:
        raise ValueError("D053 D051 parent drift")
    expected_rollback_totals = {
        "classic_fallbacks": 0,
        "engine_commits": 586,
        "engine_rejections": 0,
        "invalid_outputs": 0,
        "policy_calls": 593,
        "policy_errors": 0,
        "policy_successes": 593,
        "same_window_fallbacks": 0,
    }
    if (
        type(rollback_report) is not dict
        or rollback_report.get("evidence_kind") != "windows_development_player_owner_real_rules_e2e"
        or rollback_report.get("games") != 10
        or rollback_report.get("is_clean") is not True
        or rollback_report.get("source_changed_during_run") is not False
        or rollback_report.get("source_at_start") != rollback_report.get("source_at_end")
        or rollback_report.get("totals") != expected_rollback_totals
    ):
        raise ValueError("D053 D051/D044 rollback real-rules report invalid")
    for row in rollback_report["source_at_start"]["files"]:
        if type(row) is not dict or type(row.get("path")) is not str:
            raise ValueError("D053 rollback source row invalid")
        current_sha = sha((ROOT / row["path"]).read_bytes())
        if current_sha != row.get("raw_sha256"):
            if POST_D053_SEALED_PARENT_UPDATES.get(row["path"]) != current_sha:
                raise ValueError(f"D053 rollback source drift: {row['path']}")
    return {
        "document_type": "as_wp6_local_policy_executor_evidence_summary_v1",
        "schema_version": 1,
        "decision_id": "D053",
        "work_package": "AS-WP6/P6-03",
        "status": "windows_no_model_local_policy_executor_complete",
        "generated_on": "2026-08-14",
        "executor": {
            "executor_id": report["executor_id"],
            "executor_version": report["executor_version"],
            "manifest_canonical_sha256": LOCAL_MANIFEST_CANONICAL_SHA256,
            "parent_policy_package_manifest_canonical_sha256": PARENT_MANIFEST_CANONICAL_SHA256,
            "portable_baseline": "gdscript",
            "learned_model": "none",
            "backend": "none",
            "resource_closure": ["contract", "ir", "config", "catalog", "weights", "fallback"],
        },
        "validation": {
            "python_passed": results["python"]["passed"],
            "godot_local_executor_passed": results["godot_local_executor"]["passed"],
            "godot_player_owner_regression_passed": results["godot_player_owner_regression"]["passed"],
            "exported_ordinary_ui_terminal_games": report["terminal_games"],
            "policy_calls": report["policy_calls"],
            "policy_successes": report["policy_successes"],
            "engine_commits": report["engine_commits"],
            "failure_counters_total": report["failure_counters_total"],
            "python_full_passed": full["python"]["passed"],
            "godot_ai_full_passed": full["godot_ai"]["passed"],
            "godot_functional_ui_full_passed": full["godot_functional_ui"]["passed"],
        },
        "rollback": {
            "immutable_parent_preserved": True,
            "previous_policy_path": "scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd",
            "previous_owner_path": "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd",
            "real_rules_terminal_games": 10,
            "real_rules_policy_successes": 593,
            "real_rules_engine_commits": 586,
            "real_rules_failure_counters_total": 0,
            "new_matches_only": True,
            "match_hot_swap": False,
            "post_d053_sealed_parent_updates": sorted(POST_D053_SEALED_PARENT_UPDATES),
        },
        "claims": {
            "p6_03_windows_no_model": True,
            "production_ready": False,
            "os_network_isolation": False,
            "device_profile_approved": False,
            "a2_claimed": False,
            "a5_claimed": False,
            "model_backed": False,
            "official_cabt_parity": False,
            "android_claimed": False,
        },
    }


def build_manifest() -> dict[str, object]:
    return {
        "document_type": "as_wp6_local_policy_executor_evidence_manifest_v1",
        "schema_version": 1,
        "decision_id": "D053",
        "files": [file_entry(path) for path in FILES],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--write", action="store_true")
    group.add_argument("--check", action="store_true")
    parser.add_argument("--ui-report", type=Path)
    args = parser.parse_args()
    if args.write:
        if args.ui_report is None:
            raise SystemExit("--ui-report is required with --write")
        NORMALIZED_REPORT.write_bytes(render(normalize_ui_report(args.ui_report.resolve())))
        SUMMARY.write_bytes(render(build_summary()))
        MANIFEST.write_bytes(render(build_manifest()))
        print("D053 evidence written")
    else:
        if args.ui_report is not None:
            raise SystemExit("--ui-report is only valid with --write")
        expected_summary = render(build_summary())
        if SUMMARY.read_bytes() != expected_summary:
            raise SystemExit("D053 evidence summary drift")
        expected_manifest = render(build_manifest())
        if MANIFEST.read_bytes() != expected_manifest:
            raise SystemExit("D053 evidence manifest drift")
        print("D053 evidence verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
