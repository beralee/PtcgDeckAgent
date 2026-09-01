from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.a3_qualification import qualification_evidence


SCOPE = ROOT / "data/ptcgdap/a3/five_deck_scope_v2.json"
OUTPUT = ROOT / "evidence/ptcgdap/a3/qualification_v2.json"
MUTATION = ROOT / "evidence/ptcgdap/a3/mutation_receipt_v2.json"
SCENARIO_COVERAGE = ROOT / "evidence/ptcgdap/a3/scenario_coverage_v2.json"
REVIEW = ROOT / "evidence/ptcgdap/a3/review_qualification_v2.json"
CORRESPONDENCE = ROOT / "evidence/ptcgdap/a3/private_semantic_correspondence_summary_v2.json"
OPERATION = ROOT / "evidence/ptcgdap/a3/corresponding_card_operation_qualification_v1.json"


def canonical(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def build() -> bytes:
    scope = json.loads(SCOPE.read_text(encoding="utf-8"))
    mutation = json.loads(MUTATION.read_text(encoding="utf-8")) if MUTATION.is_file() else None
    scenario_coverage = (
        json.loads(SCENARIO_COVERAGE.read_text(encoding="utf-8"))
        if SCENARIO_COVERAGE.is_file() else None
    )
    review = json.loads(REVIEW.read_text(encoding="utf-8")) if REVIEW.is_file() else None
    correspondence = (
        json.loads(CORRESPONDENCE.read_text(encoding="utf-8"))
        if CORRESPONDENCE.is_file() else None
    )
    operation = json.loads(OPERATION.read_text(encoding="utf-8")) if OPERATION.is_file() else None
    from scripts.ai.ptcgdap.a3_qualification import A3QualificationOwner
    return canonical(A3QualificationOwner.evaluate(
        scope,
        mutation_receipt=mutation,
        scenario_coverage=scenario_coverage,
        review_receipt=review,
        correspondence_receipt=correspondence,
        operation_receipt=operation,
    ))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    expected = build()
    if args.check:
        if not OUTPUT.is_file() or OUTPUT.read_bytes() != expected:
            print("a3_qualification_evidence_drift", file=sys.stderr)
            return 1
    else:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_bytes(expected)
    print(OUTPUT)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
