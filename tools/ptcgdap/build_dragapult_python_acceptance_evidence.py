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


EVIDENCE_ROOT = ROOT / "artifacts/ptcgdap/dragapult_python_e2e"
SUMMARY_PATH = EVIDENCE_ROOT / "evidence_summary.json"
MANIFEST_PATH = EVIDENCE_ROOT / "manifest.json"
REPORT_PATH = ROOT / "artifacts/ptcgdap/dragapult_python_e2e_10_games.json"
RESULTS_PATH = EVIDENCE_ROOT / "test_results.json"

EVIDENCE_PATHS = (
    "artifacts/ptcgdap/dragapult_python_e2e/work_package.json",
    "artifacts/ptcgdap/dragapult_python_e2e/known_gaps.md",
    "artifacts/ptcgdap/dragapult_python_e2e/rollback_report.md",
    "artifacts/ptcgdap/dragapult_python_e2e/test_commands.txt",
    "artifacts/ptcgdap/dragapult_python_e2e/test_results.json",
    "artifacts/ptcgdap/dragapult_python_e2e/evidence_summary.json",
    "artifacts/ptcgdap/dragapult_python_e2e/parent_snapshot/manifest.json",
    "artifacts/ptcgdap/dragapult_python_e2e_10_games.json",
)
DOCUMENT_PATHS = (
    "docs/ptcgdap/07-decisions-risks-and-open-questions.md",
    "docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md",
    "docs/ptcgdap/STATUS.md",
)
IMPLEMENTATION_PATHS = (
    "contracts/ptcgdap/dragapult_python_strategy.schema.json",
    "contracts/ptcgdap/dragapult_python_strategy_bundle.json",
    "contracts/ptcgdap/dragapult_python_strategy_conformance_vectors.json",
    "contracts/ptcgdap/dragapult_python_strategy_profile.json",
    "data/ptcgdap/dragapult_python_strategy/deck_manifest_v1.json",
    "data/ptcgdap/dragapult_python_strategy/policy_v1.json",
    "data/ptcgdap/dragapult_python_strategy/rules_ai_opponent_v1.json",
    "scripts/ai/ptcgdap/dragapult_public_strategy.py",
    "tests/ptcgdap/dragapult_acceptance_rollback.py",
    "tests/ptcgdap/godot/run_dragapult_python_e2e.gd",
    "tests/ptcgdap/godot/run_dragapult_python_e2e.tscn",
    "tests/ptcgdap/godot/support/DragapultPythonAIOpponent.gd",
    "tests/ptcgdap/test_dragapult_public_strategy.py",
    "tests/ptcgdap/test_dragapult_python_acceptance_evidence.py",
    "tests/ptcgdap/test_as_wp6_parent_snapshot.py",
    "tests/ptcgdap/test_as_wp6_release_evidence.py",
    "tests/test_dragapult_python_public_strategy_e2e.gd",
    "tests/TestSuiteCatalog.gd",
    "tools/ptcgdap/build_dragapult_python_acceptance_evidence.py",
    "tools/ptcgdap/build_dragapult_python_strategy_contract.py",
    "tools/ptcgdap/capture_dragapult_python_acceptance_parent.py",
    "tools/ptcgdap/run_dragapult_public_strategy.py",
)


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def canonical_sha(document: Any) -> str:
    return sha(canonical_json_v1_bytes(document))


def load_object(path: Path) -> dict[str, Any]:
    value = load_json_strict(path)
    if type(value) is not dict:
        raise RuntimeError(f"expected JSON object: {path.relative_to(ROOT).as_posix()}")
    return value


def file_entry(relative_path: str) -> dict[str, Any]:
    path = ROOT / relative_path
    value = path.read_bytes()
    entry: dict[str, Any] = {
        "path": relative_path,
        "bytes": len(value),
        "raw_sha256": sha(value),
    }
    if path.suffix.lower() == ".json":
        entry["canonical_sha256"] = canonical_sha(load_json_strict(path))
    return entry


def validate_report(report: dict[str, Any]) -> None:
    required_equal = {
        "schema_version": 1,
        "evidence_kind": "windows_development_python_strategy_real_engine_e2e",
        "card_id_domain": "godot_local_card_uid_v1",
        "dragapult_deck_id": 800018499,
        "rules_ai_deck_id": 575720,
        "games": 10,
        "wins": 2,
        "losses": 8,
        "draws": 0,
        "python_calls": 1218,
        "python_successes": 1218,
        "python_errors": 0,
        "python_timeouts": 0,
        "invalid_outputs": 0,
        "fallbacks": 0,
        "is_clean": True,
        "cabt_exportable": False,
        "development_python_only": True,
        "player_runtime_python_dependency": False,
        "player_live_allowed": False,
        "android_validated": False,
        "python_gdscript_same_policy_conformance": False,
        "official_cabt_engine_parity": False,
        "deck_identity_merge_with_official_cabt": False,
    }
    for key, expected in required_equal.items():
        if report.get(key) != expected:
            raise RuntimeError(f"Dragapult report mismatch: {key}")
    if report.get("seeds") != list(range(83200, 83210)):
        raise RuntimeError("Dragapult report seed drift")
    if report.get("source_at_start") != report.get("source_at_end"):
        raise RuntimeError("Dragapult source changed during run")
    if report.get("source_changed_during_run") is not False:
        raise RuntimeError("Dragapult source-change flag drift")
    divergence = report.get("first_rule_divergence")
    if type(divergence) is not dict or divergence.get("seed") != 83200:
        raise RuntimeError("Dragapult first-divergence drift")


def build_summary() -> dict[str, Any]:
    report = load_object(REPORT_PATH)
    validate_report(report)
    bundle_path = ROOT / "contracts/ptcgdap/dragapult_python_strategy_bundle.json"
    deck_path = ROOT / "data/ptcgdap/dragapult_python_strategy/deck_manifest_v1.json"
    policy_path = ROOT / "data/ptcgdap/dragapult_python_strategy/policy_v1.json"
    opponent_path = ROOT / "data/ptcgdap/dragapult_python_strategy/rules_ai_opponent_v1.json"
    bundle = load_object(bundle_path)
    deck = load_object(deck_path)
    policy = load_object(policy_path)
    opponent = load_object(opponent_path)
    results = load_object(RESULTS_PATH)
    parent_path = EVIDENCE_ROOT / "parent_snapshot/manifest.json"
    parent = load_object(parent_path)
    return {
        "schema_version": 1,
        "work_package": "DRA-WINDOWS-PYTHON-E2E",
        "status": "development_acceptance_complete_player_live_closed",
        "generated_on": "2026-08-13",
        "identity": {
            "card_id_domain": deck["card_id_domain"],
            "official_card_id_domain_merged": False,
            "dragapult_deck_identity": deck["deck_id"],
            "dragapult_deck_id": deck["source_deck_id"],
            "dragapult_card_count": deck["card_count"],
            "dragapult_unique_card_count": deck["unique_card_count"],
            "cabt_exportable": deck["cabt_exportable"],
            "deck_manifest_raw_sha256": sha(deck_path.read_bytes()),
            "deck_manifest_canonical_sha256": canonical_sha(deck),
            "strategy_bundle_raw_sha256": sha(bundle_path.read_bytes()),
            "strategy_bundle_canonical_sha256": canonical_sha(bundle),
            "policy_raw_sha256": sha(policy_path.read_bytes()),
            "policy_canonical_sha256": canonical_sha(policy),
            "opponent_deck_id": opponent["deck_id"],
            "opponent_strategy_id": opponent["strategy_id"],
            "opponent_runtime_mode": opponent["decision_runtime_mode"],
            "opponent_lock_raw_sha256": sha(opponent_path.read_bytes()),
            "opponent_lock_canonical_sha256": canonical_sha(opponent),
        },
        "end_to_end": {
            "report_path": REPORT_PATH.relative_to(ROOT).as_posix(),
            "report_bytes": REPORT_PATH.stat().st_size,
            "report_raw_sha256": sha(REPORT_PATH.read_bytes()),
            "report_canonical_sha256": canonical_sha(report),
            "seeds": report["seeds"],
            "tracked_seats": report["tracked_seats"],
            "games": report["games"],
            "wins": report["wins"],
            "losses": report["losses"],
            "draws": report["draws"],
            "python_calls": report["python_calls"],
            "python_successes": report["python_successes"],
            "interaction_calls": report["interaction_calls"],
            "send_out_calls": report["send_out_calls"],
            "invalid_outputs": report["invalid_outputs"],
            "python_errors": report["python_errors"],
            "python_timeouts": report["python_timeouts"],
            "fallbacks": report["fallbacks"],
            "failure_reasons": report["failure_reasons"],
            "first_rule_divergence": report["first_rule_divergence"],
            "source_changed_during_run": report["source_changed_during_run"],
        },
        "validation": results,
        "rollback": {
            "parent_manifest_path": parent_path.relative_to(ROOT).as_posix(),
            "parent_manifest_bytes": parent_path.stat().st_size,
            "parent_manifest_raw_sha256": sha(parent_path.read_bytes()),
            "parent_manifest_canonical_sha256": canonical_sha(parent),
            "parent_file_count": len(parent["files"]),
            "live_owner_changed": False,
        },
        "alignment": {
            "local_godot_python_host_interface": "accepted_for_development_test",
            "cross_runtime_policy_conformance": False,
            "python_gdscript_same_policy_conformance": False,
            "official_cabt_engine_parity": False,
            "player_runtime_python_dependency": False,
            "player_live_allowed": False,
            "android_validated": False,
            "A0": "partial / not claimed",
            "A1_A5": "not evaluated",
        },
    }


def build_manifest() -> dict[str, Any]:
    results = load_object(RESULTS_PATH)
    validation_paths: list[str] = []
    for group in (results.get("results", []), results.get("retained_failures", [])):
        for row in group:
            path = row.get("log_path") if type(row) is dict else None
            if type(path) is str and path and path not in validation_paths:
                validation_paths.append(path)
    return {
        "schema_version": 1,
        "work_package": "DRA-WINDOWS-PYTHON-E2E",
        "status": "development_acceptance_complete_player_live_closed",
        "evidence_files": [file_entry(path) for path in EVIDENCE_PATHS],
        "documentation_hashes": [file_entry(path) for path in DOCUMENT_PATHS],
        "implementation_hashes": [file_entry(path) for path in IMPLEMENTATION_PATHS],
        "validation_hashes": [file_entry(path) for path in validation_paths],
        "alignment": {
            "interface": "windows_development_test_accepted",
            "player_live": False,
            "python_player_runtime": False,
            "android": False,
            "official_cabt_engine_parity": False,
        },
    }


def write() -> None:
    EVIDENCE_ROOT.mkdir(parents=True, exist_ok=True)
    summary = build_summary()
    SUMMARY_PATH.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    manifest = build_manifest()
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")


def check() -> None:
    expected_summary = build_summary()
    actual_summary = load_object(SUMMARY_PATH)
    if actual_summary != expected_summary:
        raise RuntimeError("Dragapult evidence summary drift")
    expected_manifest = build_manifest()
    actual_manifest = load_object(MANIFEST_PATH)
    if actual_manifest != expected_manifest:
        raise RuntimeError("Dragapult evidence manifest drift")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write == args.check:
        parser.error("choose exactly one of --write or --check")
    write() if args.write else check()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
