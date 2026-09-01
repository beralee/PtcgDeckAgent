from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.a3_scenario_coverage import (
    build_scenario_coverage,
    load_capability_profile,
)
from scripts.ai.ptcgdap.source_lock import load_json_strict


SCOPE = ROOT / "data/ptcgdap/a3/five_deck_scope_v2.json"
PROFILE = ROOT / "contracts/ptcgdap/a3_five_deck_capability_profile_v2.json"
OUTPUT = ROOT / "evidence/ptcgdap/a3/scenario_coverage_v2.json"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    report = build_scenario_coverage(
        load_json_strict(SCOPE), load_capability_profile(PROFILE),
    )
    encoded = (
        json.dumps(report, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n"
    ).encode("utf-8")
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(encoded)
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
