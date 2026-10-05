"""Serial, isolated Godot regression runner. The Godot catalog owns discovery.

No training pools, service credentials, real player user-data or implicit retries.
JSON reports are mandatory: an exit code alone is not evidence of a passing test.
"""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
MIN_FREE_BYTES = 2 * 1024**3


def timeout_for_suite(name: str, profiles: dict, override: float | None = None) -> float:
    value = override if override is not None else profiles.get("suite_timeout_seconds", {}).get(name, 180)
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value <= 0:
        raise ValueError("Suite timeout must be a finite positive number: " + name)
    return float(value)


def startup_script_error(log: str) -> str:
    # Autoloads run before the GDScript logger is installed. A valid suite
    # report cannot excuse an already broken application startup.
    first_test = re.search(r"^RUN: ", log, re.MULTILINE)
    startup = log[:first_test.start()] if first_test else log
    if re.search(r"^SCRIPT ERROR:", startup, re.MULTILINE):
        return "Godot emitted script errors before test execution; see console.log"
    return ""


def write_json(path: Path, value: dict) -> None:
    """A failed or interrupted write must not destroy the last complete report."""
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2, ensure_ascii=False)
        stream.flush()
        os.fsync(stream.fileno())
    temporary.replace(path)


def release_created_userdata(folder: Path, appdata: Path) -> None:
    """Release only the temporary directory created by this invocation."""
    expected = folder.resolve() / "userdata"
    if appdata.is_symlink() or appdata.resolve() != expected:
        raise ValueError("Refusing to release user data outside this invocation")
    if appdata.exists():
        shutil.rmtree(appdata)


def validate_report(report: dict, exit_code: int) -> str:
    """Return infrastructure error, keeping skipped coverage visibly incomplete."""
    if not isinstance(report, dict):
        return "Test report must be an object"
    cases = report.get("cases", [])
    if report.get("schema_version") != 1 or not isinstance(cases, list) or not cases:
        return "Missing or empty structured test results"
    if any(not isinstance(case, dict) or any(not isinstance(case.get(key), str) for key in ("suite", "test", "status")) for case in cases):
        return "Malformed case record"
    counts = Counter(case.get("status") for case in cases)
    if set(counts) - {"passed", "failed", "skipped"}:
        return "Unknown case status"
    if report.get("total") != len(cases):
        return "Total does not match recorded cases"
    for status in ("passed", "failed", "skipped"):
        if report.get(status) != counts[status]:
            return f"{status} count does not match recorded cases"
    expected = 1 if counts["failed"] else (2 if not counts["passed"] else 0)
    if exit_code != expected or report.get("exit_code") != expected:
        return f"Process exit {exit_code} disagrees with report (expected {expected})"
    identities = [(case.get("suite"), case.get("test")) for case in cases]
    if len(set(identities)) != len(identities):
        return "Duplicate case identities"
    return ""


def resume_entry(item: dict, test_filter: str) -> dict:
    checked = dict(item)
    if item.get("infrastructure_error"):
        checked["status"] = "failed"
        return checked
    saved = json.loads(Path(item["report"]).read_text(encoding="utf-8-sig"))
    invalid = validate_report(saved, item["exit_code"]) or startup_script_error(
        Path(item["log"]).read_text(encoding="utf-8-sig", errors="replace"))
    if invalid:
        raise ValueError("Resume evidence is invalid: " + invalid)
    saved_filter = saved.get("filters", {}).get("test-filter", saved.get("filters", {}).get("test", ""))
    if saved_filter != test_filter:
        raise ValueError("Resume must use the same test filter; partial tests cannot replace a full suite")
    if any(case.get("suite") != item["name"] or case.get("path") != item["path"] for case in saved["cases"]):
        raise ValueError("Resume case identity differs from selected suite")
    checked["status"] = "failed" if saved["failed"] else ("incomplete" if saved["skipped"] else "passed")
    for key in ("total", "passed", "failed", "skipped"):
        checked[key] = saved[key]
    return checked


def invoke(godot: Path, args: list[str], folder: Path, timeout: float,
           user_data: Path | None = None, keep_user_data: bool = False) -> tuple[int, dict, str, float]:
    folder.parent.mkdir(parents=True, exist_ok=True)
    if shutil.disk_usage(folder.parent).free < MIN_FREE_BYTES:
        return 125, {}, "Less than 2 GiB free; refusing to start another suite", 0.0
    folder.mkdir(parents=True, exist_ok=False)
    appdata = user_data or folder / "userdata"
    appdata.mkdir(parents=True, exist_ok=True)
    report_path = folder / "result.json"
    env = os.environ.copy()
    env.update(APPDATA=str(appdata), XDG_DATA_HOME=str(appdata))
    command = [str(godot), "--headless", "--path", str(ROOT), "--log-file",
               str(folder / "engine.log"), "--script", "res://tests/CliTestRunner.gd",
               "--", *args, f"--report={report_path.as_posix()}"]
    started = time.monotonic()
    code, error = 1, ""
    try:
        with (folder / "console.log").open("wb") as log:
            with subprocess.Popen(command, cwd=ROOT, env=env, stdout=log,
                                  stderr=subprocess.STDOUT) as process:
                try:
                    code = process.wait(timeout=timeout)
                except BaseException:
                    # Own the process lifetime before releasing its user data.
                    if os.name == "nt" and process.poll() is None:
                        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
                    if process.poll() is None:
                        process.kill()
                    process.wait()
                    raise
    except subprocess.TimeoutExpired:
        code, error = 124, f"Suite exceeded {timeout:g} seconds; process terminated"
    finally:
        if user_data is None and not keep_user_data:
            try:
                release_created_userdata(folder, appdata)
            except OSError as exc:
                error = f"Could not release invocation-owned user data: {exc}"
    try:
        report = json.loads(report_path.read_text(encoding="utf-8-sig"))
        if not isinstance(report, dict):
            raise ValueError("Report is not an object")
    except (OSError, ValueError):
        report = {}
        error = error or "Godot did not produce a valid JSON report (crash, parse error or early exit)"
    error = error or startup_script_error((folder / "console.log").read_text(encoding="utf-8-sig", errors="replace"))
    return code, report, error, round(time.monotonic() - started, 3)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, default=os.environ.get("GODOT_EXE", r"D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe"))
    parser.add_argument("--group", default="all", help="ui,functional,ai (ai_training remains an alias)")
    parser.add_argument("--tier", choices=("full", "smoke"), default="full")
    parser.add_argument("--suite", default="", help="Comma-separated catalog names, exact case-insensitive matches")
    parser.add_argument("--suite-script", default="", help="One res:// script; bypass category selection")
    parser.add_argument("--profile", default="")
    parser.add_argument("--ai-version", default="")
    parser.add_argument("--test-filter", default="")
    parser.add_argument("--timeout", type=float, help="Override profile budget; otherwise 180 seconds, with declared long-suite exceptions")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--user-data-root", type=Path, help="Explicit opt-in to an existing test-only user-data directory")
    parser.add_argument("--keep-user-data", action="store_true", help="Keep new isolated caches for debugging; disk guard remains active")
    parser.add_argument("--rerun-failed", type=Path, help="Previous aggregate report; preserve original evidence")
    parser.add_argument("--resume", type=Path, help="Continue an interrupted matrix, retaining completed suite evidence")
    parser.add_argument("--list", action="store_true")
    args, extra = parser.parse_known_args(argv)
    extra = [item for item in extra if item != "--"]
    if not args.godot.is_file() or (args.timeout is not None and (not math.isfinite(args.timeout) or args.timeout <= 0)):
        parser.error("--godot must exist and --timeout must be positive")
    groups = ["ai" if value.strip().lower() == "ai_training" else value.strip().lower()
              for value in args.group.split(",")]
    if groups != ["all"] and (not groups or set(groups) - {"ui", "functional", "ai"}):
        parser.error("Unknown or empty group; choose ui,functional,ai or all")
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:6]
    output = (args.output or ROOT / ".godot_test_user" / "matrix" / stamp).resolve()
    output.mkdir(parents=True, exist_ok=True)
    if __package__:
        from .audit_test_quality import audit
    else:
        from audit_test_quality import audit
    quality = audit(ROOT)
    write_json(output / "quality-audit.json", quality)
    quality_errors = [finding for finding in quality["findings"] if finding["severity"] == "error"]
    if quality_errors:
        print(f"Test quality gate rejected {len(quality_errors)} ineffective tests; see {output / 'quality-audit.json'}")
        return 2
    profiles = json.loads((ROOT / "tests" / "test_profiles.json").read_text(encoding="utf-8"))
    for name in profiles.get("suite_timeout_seconds", {}):
        timeout_for_suite(name, profiles)
    filters = [] if groups == ["all"] else ["--group=" + ",".join(groups)]
    if args.profile:
        filters.append("--profile=" + args.profile)
    if args.ai_version:
        filters.append("--ai-version=" + args.ai_version)
    if args.suite_script:
        filters.append("--suite-script=" + args.suite_script)
    code, catalog, error, _ = invoke(args.godot.resolve(), [*filters, "--list"], output / "discovery", 60)
    if code or error or not isinstance(catalog.get("suites"), list):
        print(f"Discovery failed: {error or code}; see {output / 'discovery'}", flush=True)
        return 2
    suites = catalog["suites"]
    selected = {value.strip().lower() for value in args.suite.split(",") if value.strip()}
    if args.tier == "smoke":
        if args.suite_script or args.profile or args.ai_version or args.rerun_failed:
            parser.error("Smoke tier selects its declared suites; use full tier with profile/version/rerun selectors")
        smoke_groups = ("ui", "functional", "ai") if groups == ["all"] else groups
        smoke = {name.lower() for group in smoke_groups for name in profiles["smoke"][group]}
        missing = smoke - {suite["name"].lower() for suite in suites}
        if missing:
            parser.error("Smoke profile has missing suites: " + ", ".join(sorted(missing)))
        if selected and selected - smoke:
            parser.error("Requested suite is not in the smoke profile")
        selected = selected or smoke
    if args.rerun_failed:
        previous = json.loads(args.rerun_failed.read_text(encoding="utf-8-sig"))
        selected.update(item["name"].lower() for item in previous["suites"] if item["status"] == "failed")
        if not selected:
            parser.error("Previous report has no failed suites; refusing an empty rerun")
    unknown = selected - {suite["name"].lower() for suite in suites}
    if unknown:
        parser.error("Unknown suites in selected category/profile: " + ", ".join(sorted(unknown)))
    if selected:
        suites = [suite for suite in suites if suite["name"].lower() in selected]
    names = [suite["name"].lower() for suite in suites]
    paths = [suite["path"] for suite in suites]
    if not suites or len(set(names)) != len(names) or len(set(paths)) != len(paths):
        parser.error("Empty or duplicate suite selection")
    if args.list:
        print(json.dumps(suites, indent=2, ensure_ascii=False))
        return 0
    retained = []
    if args.resume:
        if args.rerun_failed:
            parser.error("Choose either --resume or --rerun-failed")
        previous = json.loads(args.resume.read_text(encoding="utf-8-sig"))
        if Path(previous.get("godot", "")).resolve() != args.godot.resolve():
            parser.error("Resume must use the same Godot executable; another version requires a fresh run")
        selected_paths = {suite["path"] for suite in suites}
        for item in previous["suites"]:
            if item["path"] not in selected_paths:
                continue
            if item.get("exit_code") == 125:
                continue  # The disk guard stopped this suite before execution.
            if not Path(item["log"]).is_file():
                parser.error("Resume evidence is missing: " + item["log"])
            try:
                retained.append(resume_entry(item, args.test_filter))
            except (ValueError, OSError) as exc:
                parser.error(str(exc))
        retained_paths = {item["path"] for item in retained}
        if len(retained_paths) != len(retained):
            parser.error("Duplicate suites in resume evidence")
        suites = [suite for suite in suites if suite["path"] not in retained_paths]
    aggregate = {"schema_version": 1, "started_at": datetime.now(timezone.utc).isoformat(),
                 "godot": str(args.godot), "filters": filters, "suite_count": len(suites) + len(retained),
                 "isolation": "process-and-userdata-per-suite", "suites": retained,
                 "resumed_from": str(args.resume) if args.resume else ""}
    summary_path = output / "report.json"
    print(f"Running {len(suites)} suites serially; reports: {output}", flush=True)
    counts = Counter(item["status"] for item in retained)
    aggregate.update(status="running", completed_suites=len(retained), statuses=dict(counts))
    write_json(summary_path, aggregate)
    for index, suite in enumerate(suites, len(retained) + 1):
        folder = output / f"{index:04d}-{suite['name']}"
        case_args = ["--suite-script=" + suite["path"], *extra]
        if args.test_filter:
            case_args.append("--test-filter=" + args.test_filter)
        user_data = args.user_data_root.resolve() if args.user_data_root else None
        budget = timeout_for_suite(suite["name"], profiles, args.timeout)
        code, report, error, elapsed = invoke(args.godot.resolve(), case_args, folder, budget, user_data, args.keep_user_data)
        error = error or validate_report(report, code)
        status = "failed" if error or report.get("failed", 0) else ("incomplete" if report.get("skipped", 0) else "passed")
        result = {**suite, "status": status, "exit_code": code, "infrastructure_error": error,
                  "timeout_seconds": budget,
                  "elapsed_seconds": elapsed, "report": str(folder / "result.json"),
                  "log": str(folder / "console.log"),
                  "passed": report.get("passed", 0), "failed": report.get("failed", 0),
                  "skipped": report.get("skipped", 0), "total": report.get("total", 0)}
        aggregate["suites"].append(result)
        counts = Counter(item["status"] for item in aggregate["suites"])
        aggregate.update(completed_suites=index, statuses=dict(counts))
        write_json(summary_path, aggregate)
        print(f"[{index}/{aggregate['suite_count']}] {status.upper()} {suite['name']}: "
              f"{result['passed']} passed, {result['failed']} failed, {result['skipped']} skipped ({elapsed}s) {error}", flush=True)
        if code == 125 or "Could not release invocation-owned" in error:
            aggregate["status"] = "blocked"
            write_json(summary_path, aggregate)
            print("Matrix stopped before disk exhaustion; use --resume after resolving the infrastructure error", flush=True)
            return 2
    aggregate["completed_at"] = datetime.now(timezone.utc).isoformat()
    aggregate["status"] = "failed" if counts["failed"] else ("incomplete" if counts["incomplete"] else "passed")
    aggregate["totals"] = {key: sum(item[key] for item in aggregate["suites"]) for key in ("total", "passed", "failed", "skipped")}
    write_json(summary_path, aggregate)
    print(f"{aggregate['status'].upper()}: {aggregate['totals']}; {summary_path}", flush=True)
    return 1 if counts["failed"] else (2 if counts["incomplete"] else 0)


if __name__ == "__main__":
    raise SystemExit(main())
