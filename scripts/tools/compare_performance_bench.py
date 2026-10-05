"""Compare validated runs only when device, build mode and fixtures match."""
import argparse
import json
from pathlib import Path
import sys
if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from scripts.tools.run_performance_bench import platform_key, write_json


def compare(before, after):
    if before.get("status") == "invalid" or after.get("status") == "invalid":
        raise ValueError("Invalid or incomplete measurements cannot be compared")
    old = {(platform_key(r["platform"]), r["case"], r["cache_state"]): r for r in before["summary"]}
    result = []
    for row in after["summary"]:
        key = (platform_key(row["platform"]), row["case"], row["cache_state"])
        if key not in old:
            continue
        previous = old[key]
        b, a = previous["duration"]["p50_ms"], row["duration"]["p50_ms"]
        result.append({"platform": row["platform"], "case": row["case"], "cache_state": row["cache_state"],
                       "before_p50_ms": b, "after_p50_ms": a, "change_percent": (a / b - 1) * 100 if b else None,
                       "before_max_frame_ms": previous["frame_gaps"].get("max_ms"),
                       "after_max_frame_ms": row["frame_gaps"].get("max_ms"),
                       "after_feedback_max_ms": row["feedback"].get("max_ms"),
                       "remaining_budget_misses": row["budget_misses"]})
    if not result:
        raise ValueError("No matching device/build-mode/case/cache cohorts")
    return result


def fixture_sets(report):
    values = set()
    for run in report["runs"]:
        raw = json.loads(Path(run["report"]).read_text(encoding="utf-8-sig"))
        values.add(json.dumps({"group": raw.get("group"), "fixtures": raw.get("fixtures", {})}, sort_keys=True))
    return values


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    before = json.loads(args.before.read_text(encoding="utf-8-sig"))
    after = json.loads(args.after.read_text(encoding="utf-8-sig"))
    if fixture_sets(before) != fixture_sets(after):
        raise SystemExit("Fixture identities differ; refusing a misleading before/after comparison")
    rows = compare(before, after)
    write_json(args.output, {"before": str(args.before.resolve()), "after": str(args.after.resolve()), "comparisons": rows})
    print(f"Compared {len(rows)} matching cohorts: {args.output}")


if __name__ == "__main__":
    main()
