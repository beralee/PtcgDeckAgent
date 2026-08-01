"""Compare aligned candidate/baseline decision traces and report first divergence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ALIGN_KEYS = (
    "observation_step",
    "select_type",
    "option_count",
    "action",
)


def _load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _first_divergence(
    candidate: list[dict[str, Any]],
    baseline: list[dict[str, Any]],
) -> tuple[int | None, dict[str, Any] | None, dict[str, Any] | None]:
    for index, (left, right) in enumerate(zip(candidate, baseline)):
        if any(left.get(key) != right.get(key) for key in ALIGN_KEYS):
            return index, left, right
    if len(candidate) != len(baseline):
        index = min(len(candidate), len(baseline))
        return (
            index,
            candidate[index] if index < len(candidate) else None,
            baseline[index] if index < len(baseline) else None,
        )
    return None, None, None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate-report", type=Path, required=True)
    parser.add_argument("--baseline-report", type=Path, required=True)
    parser.add_argument(
        "--mode",
        choices=("all", "flips", "candidate-only", "baseline-only"),
        default="flips",
    )
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    candidate = _load(args.candidate_report.resolve())
    baseline = _load(args.baseline_report.resolve())
    baseline_by_pair = {
        str(row["pair_id"]): row
        for row in baseline.get("records", [])
        if row.get("pair_id") is not None
    }
    results: list[dict[str, Any]] = []
    missing_pairs: list[str] = []
    for left in candidate.get("records", []):
        pair_id = str(left.get("pair_id"))
        right = baseline_by_pair.get(pair_id)
        if right is None:
            missing_pairs.append(pair_id)
            continue
        left_reward = left.get("candidate_reward")
        right_reward = right.get("candidate_reward")
        candidate_only = left_reward == 1 and right_reward != 1
        baseline_only = left_reward != 1 and right_reward == 1
        if args.mode == "flips" and not (candidate_only or baseline_only):
            continue
        if args.mode == "candidate-only" and not candidate_only:
            continue
        if args.mode == "baseline-only" and not baseline_only:
            continue
        left_trace = (left.get("subject_trace") or {}).get(
            "decision_trace",
            [],
        )
        right_trace = (right.get("subject_trace") or {}).get(
            "decision_trace",
            [],
        )
        ordinal, left_step, right_step = _first_divergence(
            left_trace,
            right_trace,
        )
        results.append(
            {
                "pair_id": pair_id,
                "run_seed": left.get("run_seed"),
                "candidate_reward": left_reward,
                "baseline_reward": right_reward,
                "candidate_only": candidate_only,
                "baseline_only": baseline_only,
                "first_divergence_ordinal": ordinal,
                "candidate": left_step,
                "baseline": right_step,
                "candidate_trace_length": len(left_trace),
                "baseline_trace_length": len(right_trace),
            }
        )

    payload = {
        "schema_version": 1,
        "mode": args.mode,
        "candidate_report": str(args.candidate_report.resolve()),
        "baseline_report": str(args.baseline_report.resolve()),
        "pairs": len(results),
        "missing_pairs": missing_pairs,
        "results": results,
    }
    rendered = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        output = args.output.resolve()
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 0 if not missing_pairs else 1


if __name__ == "__main__":
    raise SystemExit(main())
