from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
from typing import Mapping


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict  # noqa: E402


EVIDENCE = ROOT / "artifacts/ptcgdap/as_wp6_author_developer_workbench"
SUMMARY = EVIDENCE / "evidence_summary.json"
MANIFEST = EVIDENCE / "manifest.json"
TEST_RESULTS = EVIDENCE / "test_results.json"
REPORT_NAMES = {
    "scaffold": "scaffold_report.json",
    "build": "build_report.json",
    "validate": "validate_report.json",
    "simulation": "simulation_report.json",
}
GODOT_LOG = EVIDENCE / "godot_rules_focused.log"
ARCHIVE_SHA256 = "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"

FILES = (
    "artifacts/ptcgdap/as_wp6_author_developer_workbench/README.md",
    "artifacts/ptcgdap/as_wp6_author_developer_workbench/known_gaps.md",
    "artifacts/ptcgdap/as_wp6_author_developer_workbench/test_results.json",
    "artifacts/ptcgdap/as_wp6_author_developer_workbench/scaffold_report.json",
    "artifacts/ptcgdap/as_wp6_author_developer_workbench/build_report.json",
    "artifacts/ptcgdap/as_wp6_author_developer_workbench/validate_report.json",
    "artifacts/ptcgdap/as_wp6_author_developer_workbench/simulation_report.json",
    "artifacts/ptcgdap/as_wp6_author_developer_workbench/godot_rules_focused.log",
    "artifacts/ptcgdap/as_wp6_author_developer_workbench/evidence_summary.json",
    "tools/ptcgdap/author_strategy_developer.py",
    "tools/ptcgdap/build_as_wp6_author_developer_workbench_evidence.py",
    "tests/ptcgdap/test_author_strategy_developer_tool.py",
    "tests/ptcgdap/test_as_wp6_author_developer_workbench_evidence.py",
    "tests/ptcgdap/godot/test_author_strategy_package_rules_e2e.gd",
    "data/ptcgdap/author_strategy_packages/ptcgdap-author-strategy-release-candidate.ptcgai",
    "scripts/ai/ptcgdap/author_strategy_package.py",
    "scripts/ai/ptcgdap/author_strategy_match_host.py",
    "scripts/ai/ptcgdap/cabt_envelope.py",
    "scripts/ai/ptcgdap/cabt_selection.py",
    "scripts/ai/ptcgdap/public_observation_firewall.py",
    "scripts/ai/ptcgdap/strategic_context_v18.py",
    "scripts/ai/ptcgdap/public_base_policy.py",
    "scripts/ai/ptcgdap/restricted_base_graph_executor.py",
    "scripts/ai/ptcgdap/public_deck_adapter.py",
    "AGENTS.md",
    "docs/ptcgdap/README.md",
    "docs/ptcgdap/07-decisions-risks-and-open-questions.md",
    "docs/ptcgdap/08-author-strategy-package-mode.md",
    "docs/ptcgdap/09-author-strategy-package-engineering-handoff.md",
    "docs/ptcgdap/10-author-strategy-developer-guide.md",
    "docs/ptcgdap/STATUS.md",
    "docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md",
    "data/ptcgdap/author_strategy_packages/README.md",
)


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _mapping(value: object, label: str) -> Mapping[str, object]:
    if type(value) is not dict:
        raise ValueError(f"{label} must be an object")
    return value


def _render(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def _load_report(name: str) -> dict[str, object]:
    value = load_json_strict(EVIDENCE / REPORT_NAMES[name])
    if type(value) is not dict:
        raise ValueError(f"D058 {name} report invalid")
    return value


def _validate_reports() -> dict[str, dict[str, object]]:
    reports = {name: _load_report(name) for name in REPORT_NAMES}
    scaffold = reports["scaffold"]
    build = reports["build"]
    validate = reports["validate"]
    simulation = reports["simulation"]
    if (
        scaffold.get("document_type") != "author_strategy_developer_scaffold_report_v1"
        or scaffold.get("status") != "scaffolded"
        or scaffold.get("author_key_required") is not False
        or scaffold.get("production_authority") is not False
        or _mapping(scaffold.get("template"), "template").get("archive_sha256") != ARCHIVE_SHA256
    ):
        raise ValueError("D058 scaffold report drift")
    for name, report, status in (
        ("build", build, "built"),
        ("validate", validate, "valid"),
    ):
        if (
            report.get("document_type") != "author_strategy_developer_package_report_v1"
            or report.get("status") != status
            or report.get("archive_sha256") != ARCHIVE_SHA256
            or report.get("archive_bytes") != 18792
            or report.get("card_id_domain") != "godot_local_card_uid_v1"
            or report.get("deck_card_count") != 60
            or report.get("deck_unique_printing_count") != 28
            or report.get("signature_scope") != "test_fixture_only"
            or report.get("execution_trusted") is not False
            or report.get("production_ready") is not False
            or report.get("cabt_exportable") is not False
        ):
            raise ValueError(f"D058 {name} report drift")
    package = _mapping(simulation.get("package"), "simulation package")
    adapter = _mapping(simulation.get("adapter"), "simulation adapter")
    decision = _mapping(simulation.get("decision"), "simulation decision")
    expectation = _mapping(simulation.get("expectation"), "simulation expectation")
    claims = _mapping(simulation.get("claims"), "simulation claims")
    matched = adapter.get("matched_rules")
    if (
        simulation.get("document_type") != "author_strategy_developer_simulation_report_v1"
        or simulation.get("status") != "passed"
        or package.get("archive_sha256") != ARCHIVE_SHA256
        or type(matched) is not list
        or len(matched) != 1
        or type(matched[0]) is not dict
        or matched[0].get("rule_id") != "marnie.morgrem.evolve"
        or decision.get("selected_indexes") != [1]
        or expectation.get("matched") is not True
        or claims.get("public_only") is not True
        or claims.get("current_window_indexes_only") is not True
        or claims.get("authoritative") is not False
        or claims.get("engine_execution") is not False
        or claims.get("production_authority") is not False
    ):
        raise ValueError("D058 simulation report drift")
    return reports


def _validate_results() -> dict[str, object]:
    results = load_json_strict(TEST_RESULTS)
    if type(results) is not dict or results.get("decision_id") != "D058":
        raise ValueError("D058 test results invalid")
    green = _mapping(results.get("green"), "green results")
    for key, passed in (
        ("developer_tool", 6),
        ("package_loader_deck_and_host", 31),
        ("godot_exact_marnie_rules", 4),
        ("full_python", 971),
    ):
        row = _mapping(green.get(key), key)
        if row.get("passed") != passed or row.get("failed") != 0:
            raise ValueError(f"D058 green result drift: {key}")
    happy = _mapping(results.get("cli_happy_path"), "CLI happy path")
    if (
        happy.get("steps_passed") != 4
        or happy.get("steps_failed") != 0
        or happy.get("archive_sha256") != ARCHIVE_SHA256
        or happy.get("selected_indexes") != [1]
    ):
        raise ValueError("D058 CLI result drift")
    log = GODOT_LOG.read_text(encoding="utf-8", errors="replace")
    if (
        "Total: 4 | Failed: 0" not in log
        or "PASS test_exact_builtin_marnie_package_completes_real_rules_engine_game" not in log
        or "PASS test_package_execution_projection_keeps_opponent_private_zones_out" not in log
        or "PASS test_package_development_gate_rejects_a_different_runtime_deck" not in log
        or "PASS test_package_policy_rejects_a_stale_window_before_engine_execution" not in log
    ):
        raise ValueError("D058 Godot rules log drift")
    return results


def build_summary() -> dict[str, object]:
    reports = _validate_reports()
    results = _validate_results()
    simulation = reports["simulation"]
    return {
        "document_type": "as_wp6_author_developer_workbench_evidence_summary_v1",
        "schema_version": 1,
        "decision_id": "D058",
        "work_package": "AS-WP6/P6-37",
        "status": "developer_workbench_and_public_window_simulation_complete",
        "generated_on": "2026-08-15",
        "workflow": {
            "commands": ["scaffold", "build", "validate", "simulate"],
            "author_key_required": False,
            "archive_sha256": ARCHIVE_SHA256,
            "archive_bytes": 18792,
            "matched_rule_id": "marnie.morgrem.evolve",
            "selected_indexes": [1],
        },
        "validation": {
            "developer_tool_passed": results["green"]["developer_tool"]["passed"],
            "package_loader_deck_and_host_passed": results["green"]["package_loader_deck_and_host"]["passed"],
            "godot_exact_marnie_rules_passed": results["green"]["godot_exact_marnie_rules"]["passed"],
            "python_full_passed": results["green"]["full_python"]["passed"],
            "simulation_audit_hash": simulation["decision"]["audit_hash"],
        },
        "claims": {
            "developer_workbench": True,
            "test_fixture_signature": True,
            "public_window_simulation": True,
            "current_window_indexes_only": True,
            "engine_execution_by_simulator": False,
            "arbitrary_package_rules_integration": False,
            "execution_trusted": False,
            "production_ready": False,
            "cabt_exportable": False,
            "official_w0_w7": False,
            "a5_claimed": False,
            "android_claimed": False,
            "os_network_isolation_proven": False,
        },
    }


def _file_entry(relative_path: str) -> dict[str, object]:
    path = ROOT / relative_path
    raw = path.read_bytes()
    row: dict[str, object] = {
        "path": relative_path,
        "bytes": len(raw),
        "raw_sha256": _sha(raw),
    }
    if path.suffix.lower() == ".json":
        row["canonical_sha256"] = _sha(canonical_json_v1_bytes(load_json_strict(path)))
    return row


def build_manifest() -> dict[str, object]:
    return {
        "document_type": "as_wp6_author_developer_workbench_evidence_manifest_v1",
        "schema_version": 1,
        "decision_id": "D058",
        "files": [_file_entry(path) for path in FILES],
    }


def _copy_json(source: Path, destination: Path) -> None:
    value = load_json_strict(source)
    destination.write_bytes(_render(value))


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--write", action="store_true")
    group.add_argument("--check", action="store_true")
    for name in REPORT_NAMES:
        parser.add_argument(f"--{name}-report", type=Path)
    parser.add_argument("--godot-log", type=Path)
    args = parser.parse_args()
    if args.write:
        for name in REPORT_NAMES:
            source = getattr(args, f"{name}_report")
            if source is None:
                raise SystemExit(f"--{name}-report is required with --write")
            _copy_json(source.resolve(strict=True), EVIDENCE / REPORT_NAMES[name])
        if args.godot_log is None:
            raise SystemExit("--godot-log is required with --write")
        GODOT_LOG.write_bytes(args.godot_log.resolve(strict=True).read_bytes())
        SUMMARY.write_bytes(_render(build_summary()))
        MANIFEST.write_bytes(_render(build_manifest()))
        print("D058 evidence written")
    else:
        provided = [getattr(args, f"{name}_report") for name in REPORT_NAMES]
        if any(value is not None for value in provided) or args.godot_log is not None:
            raise SystemExit("report inputs are only valid with --write")
        expected_summary = _render(build_summary())
        if not SUMMARY.is_file() or SUMMARY.read_bytes() != expected_summary:
            raise SystemExit("D058 evidence summary drift")
        expected_manifest = _render(build_manifest())
        if not MANIFEST.is_file() or MANIFEST.read_bytes() != expected_manifest:
            raise SystemExit("D058 evidence manifest drift")
        print("D058 evidence verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
