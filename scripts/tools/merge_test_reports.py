"""Merge full-suite evidence in explicit order, retaining every previous attempt.

Later reports replace earlier full-suite attempts. Missing suites, partial test
filters, different engine executables and inconsistent evidence cannot go green.
"""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import json
from pathlib import Path

if __package__:
    from .run_test_matrix import startup_script_error, validate_report, write_json
else:
    from run_test_matrix import startup_script_error, validate_report, write_json


def merge(catalog: list[dict], reports: list[dict]) -> dict:
    expected = {item["path"]: item for item in catalog}
    if not expected or len(expected) != len(catalog):
        raise ValueError("Empty or duplicate catalog")
    engines = {str(Path(report["godot"]).resolve()) for report in reports}
    if len(engines) != 1:
        raise ValueError("Use one Godot executable per merged regression")
    latest, attempts = {}, {}
    for report in reports:
        for entry in report["suites"]:
            path = entry["path"]
            if path not in expected:
                continue
            if entry["name"] != expected[path]["name"]:
                raise ValueError("Suite identity does not match catalog")
            error, data = "", {}
            try:
                data = json.loads(Path(entry["report"]).read_text(encoding="utf-8-sig"))
                if not isinstance(data, dict):
                    raise ValueError("Case report is not an object")
                if data.get("filters", {}).get("test-filter") or data.get("filters", {}).get("test"):
                    raise ValueError("A filtered test run cannot replace full-suite evidence")
                error = validate_report(data, entry["exit_code"])
                if any(case.get("path") != path or case.get("suite") != entry["name"] for case in data.get("cases", [])):
                    error = "Case identity differs from requested suite"
            except (OSError, ValueError) as exc:
                if "filtered test run" in str(exc):
                    raise
                error = str(exc)
            try:
                error = error or startup_script_error(Path(entry["log"]).read_text(encoding="utf-8-sig", errors="replace"))
            except OSError as exc:
                error = str(exc)
            error = error or entry.get("infrastructure_error", "")
            status = "failed" if error or data.get("failed", 0) else ("incomplete" if data.get("skipped", 0) else "passed")
            checked = {**entry, "status": status, "infrastructure_error": error}
            for key in ("total", "passed", "failed", "skipped"):
                checked[key] = data.get(key, 0)
            attempts.setdefault(path, []).append({key: checked[key] for key in ("status", "report", "log", "infrastructure_error")})
            latest[path] = checked
    suites = [latest[item["path"]] for item in catalog if item["path"] in latest]
    missing = [item["name"] for item in catalog if item["path"] not in latest]
    counts = Counter(item["status"] for item in suites)
    status = "failed" if counts["failed"] else ("incomplete" if missing or counts["incomplete"] else "passed")
    return dict(schema_version=1, godot=next(iter(engines)), status=status,
                completed_at=datetime.now(timezone.utc).isoformat(),
                suite_count=len(catalog), completed_suites=len(suites), missing_suites=missing,
                statuses=dict(counts), suites=suites, attempts=attempts,
                totals={key: sum(item[key] for item in suites) for key in ("total", "passed", "failed", "skipped")})


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, required=True, help="Godot discovery result.json")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("reports", type=Path, nargs="+")
    args = parser.parse_args()
    try:
        result = merge(json.loads(args.catalog.read_text(encoding="utf-8-sig"))["suites"],
                       [json.loads(path.read_text(encoding="utf-8-sig")) for path in args.reports])
    except (ValueError, OSError, TypeError, KeyError) as exc:
        parser.error(str(exc))
    result["source_reports"] = [str(path.resolve()) for path in args.reports]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    write_json(args.output, result)
    print(json.dumps({key: result[key] for key in ("status", "completed_suites", "suite_count", "totals", "missing_suites")}, ensure_ascii=False))
    return {"passed": 0, "failed": 1, "incomplete": 2}[result["status"]]


if __name__ == "__main__":
    raise SystemExit(main())
