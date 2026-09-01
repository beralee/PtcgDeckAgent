from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.a3_operation_qualification import build_operation_qualification


SCOPE = ROOT / "data/ptcgdap/a3/five_deck_scope_v2.json"
PRIVATE_REPORT = ROOT / "artifacts/ptcgdap/private/a3/private_semantic_correspondence_v2.json"
OUTPUT = ROOT / "evidence/ptcgdap/a3/corresponding_card_operation_qualification_v1.json"


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def _source_identities() -> dict[str, str]:
    return {
        "operation_contract": _sha(ROOT / "scripts/ai/ptcgdap/a3_operation_contract.py"),
        "differential_comparator": _sha(ROOT / "scripts/ai/ptcgdap/a3_differential.py"),
        "godot_adapter": _sha(ROOT / "tools/ptcgdap/a3_godot_headless_bridge.gd"),
        "godot_decision_owner": _sha(
            ROOT / "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd"
        ),
        "official_adapter": _sha(ROOT / "tools/ptcgdap/private_official_cabt_bridge.py"),
        "match_plan": _sha(ROOT / "scripts/ai/ptcgdap/a3_match_plan.py"),
        "static_projection_test": _sha(ROOT / "tests/ptcgdap/test_a3_differential.py"),
        "privacy_test": _sha(ROOT / "tests/ptcgdap/test_godot_a3_jsonline_bridge.py"),
        "live_test": _sha(ROOT / "tests/ptcgdap/test_a3_private_corresponding_card_live.py"),
    }


def _canonical(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--private-bundle-root", required=True)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    private_root = Path(args.private_bundle_root).resolve()
    if not private_root.joinpath("sample_submission/sample_submission/cg/cg.dll").is_file():
        print("a3_operation_private_oracle_unavailable", file=sys.stderr)
        return 2
    environment = os.environ.copy()
    environment["PTCGDAP_PRIVATE_CABT_BUNDLE"] = str(private_root)
    completed = subprocess.run(
        [
            sys.executable, "-m", "unittest",
            "tests.ptcgdap.test_a3_differential",
            "tests.ptcgdap.test_godot_a3_jsonline_bridge",
            "tests.ptcgdap.test_a3_private_corresponding_card_live",
            "-q",
        ],
        cwd=ROOT,
        env=environment,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="strict",
        timeout=120,
        check=False,
    )
    if completed.returncode != 0:
        sys.stderr.write(completed.stdout)
        sys.stderr.write(completed.stderr)
        print("a3_operation_live_witness_failed", file=sys.stderr)
        return 1
    scope = json.loads(SCOPE.read_text(encoding="utf-8"))
    private_report = json.loads(PRIVATE_REPORT.read_text(encoding="utf-8"))
    value = build_operation_qualification(
        scope,
        private_report,
        static_projection_suite_passed=True,
        privacy_suite_passed=True,
        live_setup_input_index_witness_passed=True,
        source_identities=_source_identities(),
    )
    expected = _canonical(value)
    if args.check:
        if not OUTPUT.is_file() or OUTPUT.read_bytes() != expected:
            print("a3_operation_qualification_drift", file=sys.stderr)
            return 1
    else:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_bytes(expected)
    print(OUTPUT)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
