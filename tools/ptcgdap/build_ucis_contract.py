from __future__ import annotations

import argparse
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes
from scripts.ai.ptcgdap.ucis_contract import build_ucis_contracts, validate_ucis_contracts


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    documents = build_ucis_contracts(ROOT)
    validate_ucis_contracts(documents)
    for name, document in documents.items():
        path = ROOT / "contracts/ptcgdap" / name
        body = canonical_json_v1_bytes(document)
        if args.check:
            if not path.is_file() or path.read_bytes() != body:
                raise SystemExit(f"UCIS contract drift: {name}")
        else:
            path.write_bytes(body)
            print(path)
    if args.check:
        print("UCIS contracts ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
