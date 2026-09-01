from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.policy_executor_conformance import PolicyExecutorConformance  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = PolicyExecutorConformance.load_default().run_all()
    rendered = (json.dumps(report, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    if args.output is not None:
        output = args.output.resolve()
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(rendered)
    else:
        sys.stdout.buffer.write(rendered)
    return 0 if report.get("accepted") else 1


if __name__ == "__main__":
    raise SystemExit(main())
