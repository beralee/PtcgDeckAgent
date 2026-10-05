"""Validate Playwright evidence; missing prerequisites cannot produce green gates."""
from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path


def assess(report: dict) -> dict:
    records, identities = [], set()
    raw_counts = Counter()
    if not isinstance(report, dict) or report.get("errors"):
        raise ValueError("Missing report or Playwright runner errors")

    def visit(suites):
        if not isinstance(suites, list):
            raise ValueError("Malformed suite list")
        for suite in suites:
            for spec in suite.get("specs", []):
                for case in spec.get("tests", []):
                    identity = (spec["id"], case["projectName"])
                    if identity in identities:
                        raise ValueError("Duplicate browser test identity")
                    identities.add(identity)
                    results = case.get("results", [])
                    if not results:
                        raise ValueError("Test has no execution result")
                    raw = case.get("status")
                    if raw not in ("expected", "unexpected", "flaky", "skipped"):
                        raise ValueError("Unknown Playwright outcome")
                    raw_counts[raw] += 1
                    last = results[-1].get("status")
                    annotations = case.get("annotations", [])
                    scope = [a for a in annotations if a.get("type") == "not-applicable" and a.get("description", "").strip()]
                    status = "failed"
                    if raw == "expected" and case.get("expectedStatus") == "passed" and all(r.get("status") == "passed" for r in results):
                        status = "passed"
                    elif raw == "skipped" and last == "skipped":
                        status = "not_applicable" if scope else "skipped"
                    records.append(dict(project=case["projectName"], test=spec["title"],
                                        status=status, annotations=annotations))
            visit(suite.get("suites", []))

    visit(report.get("suites", []))
    if not records:
        raise ValueError("No browser tests selected")
    stats = report.get("stats", {})
    for key in ("expected", "unexpected", "flaky", "skipped"):
        if stats.get(key) != raw_counts[key]:
            raise ValueError("Playwright summary disagrees with case records: " + key)
    counts = Counter(record["status"] for record in records)
    status = "failed" if counts["failed"] else ("incomplete" if counts["skipped"] or not counts["passed"] else "passed")
    return dict(schema_version=1, status=status, total=len(records),
                **{key: counts[key] for key in ("passed", "failed", "skipped", "not_applicable")},
                cases=records)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--started-after", type=float, default=0)
    parser.add_argument("--process-exit", type=int, default=0)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.report.stat().st_mtime < args.started_after:
            raise ValueError("Report predates this run")
        result = assess(json.loads(args.report.read_text(encoding="utf-8-sig")))
        if args.process_exit:
            result.update(status="failed", infrastructure_error=f"Playwright exited {args.process_exit}")
    except (OSError, ValueError, TypeError, KeyError, AttributeError) as exc:
        result = dict(schema_version=1, status="failed", infrastructure_error=str(exc))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps({key: value for key, value in result.items() if key != "cases"}, ensure_ascii=False))
    return {"passed": 0, "failed": 1, "incomplete": 2}[result["status"]]


if __name__ == "__main__":
    raise SystemExit(main())
