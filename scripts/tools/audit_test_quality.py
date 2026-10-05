"""Inventory test evidence without pretending static heuristics prove behavior.

Hard failures: unconditional passes, duplicate top-level test identities, and
environment/CLI guards that silently return success. Source inspections are
review items, not automatically invalid: architecture boundary tests use them.
"""
from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
METHOD = re.compile(r"^(?:static )?func (test_\w+)\([^\n]*\n(.*?)(?=^(?:func |class |static func )|\Z)", re.M | re.S)


def inspect_source(source: str) -> list[dict]:
    findings = []
    names: set[str] = set()
    for match in METHOD.finditer(source):
        name, body = match.groups()
        line = source[:match.start()].count("\n") + 1
        clean = "\n".join(value.strip() for value in body.splitlines()
                          if value.strip() and not value.lstrip().startswith("#"))
        kinds = []
        if name in names:
            kinds.append(("error", "duplicate-test-name"))
        names.add(name)
        if clean in ('return ""', "return ''", "pass"):
            kinds.append(("error", "unconditional-pass"))
        # Only inspect the precondition block before any actual exercise.
        prefix = body.split('return ""', 1)[0]
        if ('return ""' in body and
            ("OS.get_environment(" in prefix or "_arguments()" in prefix) and
            not re.search(r"\b(?:assert_\w+|await|\.new|\.instantiate)\b", prefix) and
            len(prefix.splitlines()) <= 14):
            kinds.append(("error", "silent-prerequisite-pass"))
        if "get_file_as_string(" in body:
            kinds.append(("review", "source-inspection"))
        for severity, kind in kinds:
            findings.append(dict(test=name, line=line, severity=severity, kind=kind))
    return findings


def audit(root: Path) -> dict:
    records, standalone, suites, methods = [], [], 0, 0
    for path in sorted((root / "tests").rglob("test_*.gd")):
        source = path.read_text(encoding="utf-8-sig")
        relative = path.relative_to(root).as_posix()
        matches = list(METHOD.finditer(source))
        if matches:
            suites += 1
            methods += len(matches)
        else:
            standalone.append(relative)
        records.extend(dict(path=relative, **finding) for finding in inspect_source(source))
    return dict(schema_version=1, suites=suites, methods=methods,
                findings=records, counts=dict(Counter(record["kind"] for record in records)),
                standalone_scripts=standalone,
                note="Source inspections need owner review; standalone SceneTree probes require their dedicated harness. Neither is silently counted as runtime coverage.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / ".tmp" / "test-quality-audit.json")
    args = parser.parse_args()
    report = audit(ROOT)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps({key: value for key, value in report.items() if key not in ("findings", "standalone_scripts")}, ensure_ascii=False))
    errors = [item for item in report["findings"] if item["severity"] == "error"]
    for item in errors:
        print(f"ERROR {item['path']}:{item['line']} {item['kind']} {item['test']}")
    print(f"Report: {args.output}; standalone probes: {len(report['standalone_scripts'])}")
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
