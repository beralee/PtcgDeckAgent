from __future__ import annotations

import argparse
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.a3_scope import build_five_deck_scope  # noqa: E402
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes  # noqa: E402


OUTPUT = ROOT / "data" / "ptcgdap" / "a3" / "five_deck_scope_v2.json"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    encoded = canonical_json_v1_bytes(build_five_deck_scope(ROOT)) + b"\n"
    if args.check:
        if not OUTPUT.is_file() or OUTPUT.read_bytes() != encoded:
            print("a3_scope_generated_artifact_drift")
            return 1
        print("a3_scope_generated_artifact_ok")
        return 0
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_bytes(encoded)
    print(OUTPUT)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
