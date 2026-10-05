"""Run repeatable local Godot performance cases and compare like-for-like reports.

No process pool, network service, user save files, or installed-player changes.
Rendered and headless runs are distinct evidence. Android reports use the same
GDScript runner, exported by build_performance_player.ps1.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import filecmp
import hashlib
import json
import math
import os
from pathlib import Path
import re
import signal
import stat
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
GROUPS = {
    "components": ["cards.search", "decks.list", "catalog.refresh"] + [
        f"{kind}.{case}" for kind in ("rules", "model") for case in (
            "loader_construct", "archive_verify", "deck_validate", "handle_create",
            "handle_snapshot", "deck_materialize", "engine_start", "owner_create", "worker_prepare")],
    "navigation": [f"navigation.{name}" for name in (
        "battle_setup", "deck_manager", "strategy_hub", "settings", "deck_training")]
        + ["setup.ai_picker", "setup.picker_search"],
    "battle": ["battle.classic_start", "battle.author_start", "battle.ui_refresh", "battle.idle_frames"],
    "author_start": ["battle.author_start", "battle.ui_refresh", "battle.idle_frames"],
    "matches": ["match.model", "match.rules"],
}
ERROR_RE = re.compile(r"SCRIPT ERROR|Parse Error|(?:^|\s)ERROR:|Fatal signal|Scudo ERROR", re.MULTILINE)


def plain_path(path: Path, root: Path) -> None:
    if '..' in path.parts or not path.is_relative_to(root):
        raise ValueError('Performance user data escaped its run directory')
    for item in (path, *path.parents):
        if item.exists() or item.is_symlink():
            info = item.lstat()
            if stat.S_ISLNK(info.st_mode) or getattr(info, 'st_file_attributes', 0) & 0x400:
                raise ValueError('Performance user data contains a link or junction')
        if item == root:
            break


def release_userdata(run: Path, user: Path, source_project: Path = ROOT) -> None:
    """Release verified seed copies; retain every other byte as local evidence."""
    run, user = run.absolute(), user.absolute()
    if user != run / 'user':
        raise ValueError('Refusing to release user data outside this run')
    plain_path(user, Path(user.anchor))
    evidence = run / 'user-evidence'
    if evidence.exists() or evidence.is_symlink():
        raise FileExistsError('Refusing to overwrite retained user evidence')
    if not user.exists():
        return
    # Preflight the complete tree without following links before deleting or
    # moving anything. A failed guard leaves the invocation's user data intact.
    files, directories, pending = [], [], [user]
    while pending:
        directory = pending.pop()
        directories.append(directory)
        for item in directory.iterdir():
            plain_path(item, user)
            if item.is_dir():
                pending.append(item)
            else:
                files.append(item)
    filecmp.clear_cache()
    if __package__:
        from .cleanup_test_artifacts import duplicate_source
    else:
        from cleanup_test_artifacts import duplicate_source
    for path in files:
        relative = path.relative_to(user)
        # Windows uses Godot/app_userdata/<app>; Linux uses godot/app_userdata/<app>.
        # Unknown layouts and new diagnostic types are retained by default.
        if len(relative.parts) < 4 or relative.parts[1] != 'app_userdata':
            continue
        mapped = duplicate_source(source_project, path, user)
        source = mapped[0] if mapped else source_project / 'data/bundled_user' / Path(*relative.parts[3:])
        plain_path(source.absolute(), source_project.absolute())
        if source.is_file() and filecmp.cmp(path, source, shallow=False):
            path.unlink()
    for directory in reversed(directories):
        if directory != user and not any(directory.iterdir()):
            directory.rmdir()
    if any(user.iterdir()):
        user.rename(evidence)
    else:
        user.rmdir()


def terminate_process_tree(process, log_file) -> None:
    if process.poll() is None:
        if os.name == 'nt':
            result = subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'],
                                    stdout=log_file, stderr=subprocess.STDOUT, check=False)
            if result.returncode and process.poll() is None:
                raise RuntimeError('Could not terminate performance process tree; user data retained')
        else:
            os.killpg(process.pid, signal.SIGKILL)
    process.wait()


def invoke_process(command, project: Path, run: Path, timeout: float,
                   keep_user_data: bool = False, source_project: Path = ROOT) -> list[str]:
    user = run / 'user'
    plain_path(user.absolute(), Path(user.absolute().anchor))
    user.mkdir(exist_ok=False)
    env = os.environ.copy()
    env.update(APPDATA=str(user), XDG_DATA_HOME=str(user))
    errors, process, stopped = [], None, False
    try:
        with (run / 'console.log').open('w', encoding='utf-8') as log_file:
            try:
                process = subprocess.Popen(command, cwd=project, env=env, stdout=log_file,
                                           stderr=subprocess.STDOUT, start_new_session=os.name != 'nt')
                returncode = process.wait(timeout=timeout)
                stopped = True
                if returncode:
                    errors.append(f'exit_code:{returncode}')
            except BaseException as exc:
                if process is not None:
                    terminate_process_tree(process, log_file)
                    stopped = True
                if isinstance(exc, subprocess.TimeoutExpired):
                    errors.append('process_timeout')
                else:
                    raise
    finally:
        if not keep_user_data and (process is None or stopped):
            release_userdata(run, user, source_project)
    return errors


def percentile(values, q):
    values = sorted(values)
    if not values:
        return None
    return values[max(0, math.ceil(len(values) * q) - 1)]


def statistics(values):
    if not values:
        return {"count": 0}
    return {"count": len(values), "min_ms": min(values), "max_ms": max(values),
            "p50_ms": percentile(values, .5), "p95_ms": percentile(values, .95),
            "p99_ms": percentile(values, .99)}


def validate_report(report, group, repeat, log):
    errors = []
    if report.get("schema_version") != 1 or report.get("kind") != "ptcgdap_performance_bench":
        errors.append("invalid_report_identity")
    if report.get("group") != group:
        errors.append("wrong_group")
    if group not in ["all", *GROUPS]:
        return errors + ["unknown_group"]
    platform = report.get("platform", {})
    if not all(platform.get(key) for key in ("os", "architecture", "engine", "display")):
        errors.append("platform_identity_missing")
    rows = report.get("cases", [])
    if not isinstance(rows, list) or not rows:
        return errors + ["empty_cases"]
    expected = sum((GROUPS[g] for g in ("components", "navigation", "battle")), []) if group == "all" else GROUPS[group]
    for iteration in range(repeat):
        measured = {row.get("case") for row in rows if row.get("iteration") == iteration and row.get("ok") is True}
        for name in expected:
            if name not in measured:
                errors.append(f"missing_or_failed_case:{iteration}:{name}")
    for row in rows:
        value = row.get("duration_ms")
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
            errors.append("invalid_duration")
        for value in row.get("frame_gaps_ms", []):
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
                errors.append("invalid_frame_sample")
        feedback = row.get("feedback_ms")
        if feedback is not None and (isinstance(feedback, bool) or not isinstance(feedback, (int, float)) or not math.isfinite(feedback) or feedback < 0):
            errors.append("invalid_feedback")
        if row.get("ok") is not True:
            errors.append(f"case_failed:{row.get('case')}:{row.get('error')}")
    if ERROR_RE.search(log):
        errors.append("engine_script_error")
    if "PTCGDAP_PERFORMANCE_BENCH=" not in log:
        errors.append("completion_marker_missing")
    return sorted(set(errors))


def platform_key(platform):
    # A phone-shaped desktop window must never be grouped with Android.
    keys = ("os", "os_version", "architecture", "model", "cpu", "gpu", "engine", "display", "renderer", "debug_build", "editor_binary", "viewport")
    return json.dumps({k: platform.get(k) for k in keys}, sort_keys=True)


def aggregate(reports):
    groups = defaultdict(list)
    for report in reports:
        for row in report["cases"]:
            groups[(platform_key(report["platform"]), row["case"], row["cache_state"])].append(row)
    result = []
    for (platform, case, cache), rows in sorted(groups.items()):
        gaps = [v for row in rows for v in row.get("frame_gaps_ms", [])]
        timings = statistics([row["duration_ms"] for row in rows])
        frame = statistics(gaps)
        rendered = json.loads(platform)["display"] != "headless"
        frame_window = rows[0].get("measurement") in ("frame_window", "full_match_logic")
        missed = []
        if not frame_window and timings["max_ms"] >= 1000:
            missed.append("completion_over_1s")
        if rendered and gaps and max(gaps) > 50:
            missed.append("frame_gap_over_50ms")
        if rendered and gaps and max(gaps) >= 1000:
            missed.append("unresponsive_over_1s")
        feedback = [r["feedback_ms"] for r in rows if isinstance(r.get("feedback_ms"), (float, int))]
        if rows[0].get("measurement") in ("navigation", "interaction") and (not feedback or max(feedback) >= 1000):
            missed.append("feedback_unverified_or_over_1s")
        result.append({"platform": json.loads(platform), "case": case, "cache_state": cache,
                       "duration": timings, "frame_gaps": frame, "feedback": statistics(feedback),
                       "budget_misses": missed, "frame_acceptance": "measured" if rendered and gaps else "unverified"})
    return result


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False), encoding="utf-8")
    temp.replace(path)


def write_summary(path, summary):
    text = ["# PtcgDAP 性能基线", "", f"状态：{summary['status']}。运行次数：{len(summary['runs'])}。",
            "", "1 秒是操作完成目标；首反馈另测。画面停顿目标 ≤50 ms。headless 不证明画面流畅。",
            "首次进程与进程内热运行分别统计；首次安装、系统文件缓存、温度与后台负载需在设备记录中另行注明。", "",
            "| 平台 / 渲染 | 环节 | 缓存 | N | P50 ms | P95 ms | Max ms | 最大帧间隔 ms | 问题 |",
            "|---|---|---|---:|---:|---:|---:|---:|---|"]
    for row in summary["summary"]:
        p, d, f = row["platform"], row["duration"], row["frame_gaps"]
        text.append(f"| {p['os']} {p['architecture']} / {p['display']} | {row['case']} | {row['cache_state']} | {d['count']} | "
                    f"{d['p50_ms']:.2f} | {d['p95_ms']:.2f} | {d['max_ms']:.2f} | {f.get('max_ms', 0):.2f} | {', '.join(row['budget_misses']) or '—'} |")
    text += ["", "未实测的物理 Android、小米 14 Pro、macOS、iOS/Web 不继承其他平台结论。", ""]
    path.write_text("\n".join(text), encoding="utf-8")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_EXE", "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe"))
    parser.add_argument("--project", type=Path, default=ROOT, help="Frozen diagnostic snapshot or working project")
    parser.add_argument("--exported", action="store_true", help="--godot is a diagnostic export with the runner installed")
    parser.add_argument("--group", choices=["all", *GROUPS], default="all")
    parser.add_argument("--runs", type=int, default=3)
    parser.add_argument("--repeat", type=int, default=3)
    parser.add_argument("--timeout", type=int, default=600)
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--import-reports", type=Path, nargs="*")
    parser.add_argument("--enforce-budgets", action="store_true")
    parser.add_argument("--keep-user-data", action="store_true", help="Retain seeded user data for debugging; otherwise keep only non-seed evidence")
    args = parser.parse_args(argv)
    if not 1 <= args.runs <= 30 or not 1 <= args.repeat <= 30 or args.timeout <= 0:
        parser.error("runs/repeat must be in 1..30 and timeout positive")
    output = args.output.resolve()
    project = args.project.resolve()
    output.mkdir(parents=True, exist_ok=False)
    summary = {"schema_version": 1, "status": "running", "runs": [], "summary": [],
               "source": {"commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()},
               "unverified_platforms": ["Xiaomi 14 Pro physical Android", "macOS", "iOS Safari/Web"]}
    diff = subprocess.check_output(["git", "-c", "core.safecrlf=false", "-c", "core.autocrlf=false", "diff", "--binary"], cwd=ROOT)
    summary["source"]["worktree_diff_sha256"] = hashlib.sha256(diff).hexdigest()
    summary["source"]["project"] = str(project)
    manifest = project.parent / "source-manifest.json"
    if manifest.is_file():
        summary["source"]["source_manifest_sha256"] = hashlib.sha256(manifest.read_bytes()).hexdigest()
    write_json(output / "report.json", summary)
    reports = []
    if args.import_reports:
        for index, path in enumerate(args.import_reports):
            report = json.loads(path.read_text(encoding="utf-8-sig"))
            # Original diagnostic stdout accompanies every imported report.
            log_path = path.with_suffix(".log")
            log = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
            # Expected coverage comes from the request, never from the samples
            # that happened to survive. A missing final iteration must fail.
            errors = validate_report(report, args.group, args.repeat, log)
            summary["runs"].append({"report": str(path), "errors": errors})
            if not errors: reports.append(report)
    else:
        godot = Path(args.godot).resolve()
        if not godot.is_file():
            parser.error(f"Godot unavailable: {godot}")
        summary["source"]["engine_sha256"] = hashlib.sha256(godot.read_bytes()).hexdigest()
        for index in range(args.runs):
            run = output / f"run-{index+1:02d}"
            run.mkdir()
            if sys.platform == "darwin":
                raise SystemExit("Use the diagnostic exported project with an isolated custom user-data path on macOS.")
            command = [str(godot), "--log-file", str(run / "godot.log")]
            if not args.exported: command += ["--path", str(project)]
            command += ["--headless"] if args.headless else ["--resolution", "1280x720"]
            if not args.exported: command += ["-s", "res://tests/performance/PerformanceBenchCli.gd"]
            command += ["--",
                        f"--perf-group={args.group}", f"--perf-repeat={args.repeat}",
                        f"--perf-output={run / 'samples.json'}", "--ptcgdap-performance-trace"]
            print(f"Performance run {index+1}/{args.runs}: {run}", flush=True)
            started = time.monotonic()
            errors = invoke_process(command, project, run, args.timeout, args.keep_user_data,
                                    project)
            log = (run / "console.log").read_text(encoding="utf-8", errors="replace")
            if (run / "godot.log").is_file():
                log += (run / "godot.log").read_text(encoding="utf-8", errors="replace")
            if (run / "samples.json").is_file():
                report = json.loads((run / "samples.json").read_text(encoding="utf-8"))
                errors += validate_report(report, args.group, args.repeat, log)
                if not errors: reports.append(report)
            else:
                errors.append("report_missing")
            summary["runs"].append({"report": str(run / "samples.json"), "errors": errors,
                                    "process_elapsed_s": time.monotonic() - started})
            write_json(output / "report.json", summary)
    summary["summary"] = aggregate(reports)
    summary["status"] = "invalid" if any(r["errors"] for r in summary["runs"]) or not reports else (
        "needs_optimization" if any(r["budget_misses"] for r in summary["summary"]) else "within_measured_budgets")
    write_json(output / "report.json", summary)
    write_summary(output / "report.md", summary)
    print(f"{summary['status']}: {output / 'report.md'}")
    return 1 if summary["status"] == "invalid" or args.enforce_budgets and summary["status"] != "within_measured_budgets" else 0


if __name__ == "__main__":
    raise SystemExit(main())
