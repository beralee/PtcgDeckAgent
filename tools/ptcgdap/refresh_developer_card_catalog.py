"""Regenerate the complete developer catalog and qualify its actual source set.

Checking is read-only. Refresh runs the real engine before publishing a new
qualification receipt; a metadata-only rebuild cannot qualify new cards.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes
from tools.ptcgdap.build_ucis_catalog_qualification import build_qualification, OUTPUT

PYTHON_SUITES = (
    "test_ucis_contract", "test_ucis_properties", "test_ucis_sdk",
    "test_ucis_performance", "test_a3_live_operation_witness",
)
GODOT_SUITES = (
    "30thdcCards,30thdcReview,30thcCards,SpecialStatusRules,CoinFlipInteractionOrder,"
    "GameStateMachine,RuleValidator,DamageCalculator,SharedInteractionRegressions,"
    "FullLibrarySearchPokemonUI,FullLibrarySearchAssignmentUI,FullLibrarySearchNonLeakage,"
    "FullLibrarySearchUI,FullLibrarySearchTrainerItemsUI,FullLibrarySearchSupporterStadiumUI,"
    "UcisInteractionCompiler,UcisEffectOptionShapes,A3ExternalDecisionPort,CompetitivePolicyV2,CardDatabaseSeed"
)


def refresh_commands(godot_path: Path, evidence_directory: Path) -> list[tuple[str, list[str]]]:
    py = [sys.executable]
    godot = [str(godot_path.resolve()), "--headless", "--path", str(ROOT), "-s"]
    matrix = py + ["scripts/tools/run_test_matrix.py", "--godot", str(godot_path.resolve())]
    return [
        ("attestation", godot + ["res://scripts/tools/build_ucis_runtime_attestation.gd"]),
        ("contracts", py + ["tools/ptcgdap/build_ucis_contract.py"]),
        ("performance", py + ["tools/ptcgdap/build_ucis_performance_qualification.py"]),
        ("python", py + ["-m", "unittest", *("tests.ptcgdap." + name for name in PYTHON_SUITES), "-q"]),
        # The qualification crosses functional, UI and AI categories. The
        # automatically discovered catalog owns each suite's runner/category.
        ("cards-and-host", matrix + ["--group", "all", "--suite", GODOT_SUITES,
                                   "--output", str(evidence_directory / "cards-and-host-matrix")]),
        *[(name, matrix + ["--suite-script", "res://tests/" + name + ".gd",
                           "--output", str(evidence_directory / (name + "-matrix"))])
          for name in ("test_headless_match_bridge", "test_author_strategy_interaction_contract_v2", "test_battle_ui_features_part3", "test_snorunt_csv6c_032")],
        ("qualification", py + ["tools/ptcgdap/build_ucis_catalog_qualification.py"]),
    ]


def check() -> dict:
    subprocess.run([sys.executable, str(ROOT / "tools/ptcgdap/build_ucis_contract.py"), "--check"], cwd=ROOT, check=True)
    report = build_qualification()
    report["evidence_sha256"] = hashlib.sha256(canonical_json_v1_bytes(report)).hexdigest().upper()
    if report["qualification_status"] != "passed" or OUTPUT.read_bytes() != canonical_json_v1_bytes(report):
        raise ValueError("developer_catalog_requires_requalification")
    return {"status": "passed", "total_cards": report["scope"]["total_cards"],
            "catalog_sha256": report["contract_identities"]["catalog_raw_sha256"]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--refresh", action="store_true")
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--evidence-directory", type=Path, default=ROOT / ".tmp/developer-card-catalog")
    args = parser.parse_args()
    if not args.refresh:
        print(json.dumps(check()))
        return 0
    if args.godot is None or not args.godot.is_file():
        parser.error("--refresh requires --godot pointing to the reviewed engine executable")
    args.evidence_directory.mkdir(parents=True, exist_ok=True)
    commands = refresh_commands(args.godot, args.evidence_directory.resolve())
    results = []
    for name, command in commands:
        log = args.evidence_directory / (name + ".log")
        env = dict(os.environ, PYTHONUTF8="1", PYTHONIOENCODING="utf-8")
        if name == "attestation":
            isolated_data = str((args.evidence_directory / "attestation-userdata").resolve())
            env.update(APPDATA=isolated_data, XDG_DATA_HOME=isolated_data)
        with log.open("wb") as output:
            result = subprocess.run(command, cwd=ROOT, env=env, stdout=output, stderr=subprocess.STDOUT, timeout=900)
        results.append({"step": name, "exit_code": result.returncode,
                        "log_sha256": hashlib.sha256(log.read_bytes()).hexdigest().upper()})
        (args.evidence_directory / "checks.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
        print(f"{name}: exit {result.returncode}", flush=True)
        if result.returncode:
            raise SystemExit(f"developer catalog refresh stopped; inspect {log}")
    print(json.dumps(check()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
