from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes
from scripts.ai.ptcgdap.ucis_performance import build_ucis_performance_report


OUTPUT = ROOT / "evidence/ptcgdap/ucis/ucis_performance_qualification_v1.json"


def main() -> int:
    report = build_ucis_performance_report(ROOT)
    report["source_identities"] = {
        "measurement_owner": hashlib.sha256(
            (ROOT / "scripts/ai/ptcgdap/ucis_performance.py").read_bytes()
        ).hexdigest().upper(),
        "runtime_owner": hashlib.sha256(
            (ROOT / "scripts/ai/ptcgdap/ucis.py").read_bytes()
        ).hexdigest().upper(),
    }
    payload = dict(report)
    report["evidence_sha256"] = hashlib.sha256(canonical_json_v1_bytes(payload)).hexdigest().upper()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_bytes(canonical_json_v1_bytes(report))
    print(json.dumps(report, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
    return 0 if report["qualification"]["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
