"""Serial, isolated Windows UI checks against source or a packaged executable.

No private replay or training dependency. Each run produces a machine-readable
report and captures failures even when the application crashes before reporting.
"""
from __future__ import annotations

import argparse
import html
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
LEGACY = {
    "core_input": (["--arena-battle-smoke", "--arena-ac-checks", "--arena-product-checks"], "ARENA_PACKAGE_SMOKE_PASS"),
    "search_motion": (["--arena-search-checks"], "ARENA_SEARCH_CHOREOGRAPHY_PASS"),
    "bench_eight": (["--arena-living-checks"], "ARENA_LIVING_ACCEPTANCE_PASS"),
    "two_prizes": (["--arena-knockout-checks", "--ko-cancel-exit", "--ko-two-prize", "--ko-fast"], "ARENA_KNOCKOUT_ACCEPTANCE_PASS"),
}
CASES = ["setup", "mulligan", "search", "prize_overlays", "replacement", "stadium_detail", "hand_resume", *LEGACY]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, default=Path(r"D:\ai\godot\Godot_v4.6.1-stable_win64.exe"))
    parser.add_argument("--exe", type=Path, help="Test an export instead of source")
    parser.add_argument("--cases", nargs="+", choices=CASES, default=CASES)
    parser.add_argument("--themes", nargs="+", choices=["grove"], default=["grove"])
    parser.add_argument("--renderer", choices=["gl_compatibility", "forward_plus"], default="gl_compatibility")
    parser.add_argument("--repeat", type=int, default=1)
    parser.add_argument("--timeout", type=int, default=160)
    parser.add_argument("--output", type=Path, default=ROOT / "evidence/arena3d/ui-regression" / time.strftime("%Y%m%d-%H%M%S"))
    args = parser.parse_args()
    if args.repeat < 1 or args.timeout < 1:
        parser.error("repeat and timeout must be positive")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    (output / ".gdignore").write_text("", encoding="utf-8")
    # A fresh run directory prevents stale PASS results from masking failures.
    run = output / (time.strftime("run-%Y%m%d-%H%M%S") + f"-{time.time_ns() % 1000000:06}")
    run.mkdir()
    env = os.environ.copy()
    env["APPDATA"] = str(run / "user")
    env.pop("ARENA_REPRO_RECORD", None)
    executable = (args.exe or args.godot).resolve()
    if not executable.is_file():
        parser.error(f"Executable missing: {executable}")
    results = []
    for repeat in range(args.repeat):
        for theme in args.themes:
            for case in args.cases:
                name = f"{repeat + 1:02}-{theme}-{case}"
                folder = run / name
                folder.mkdir()
                env["ARENA_UI_ARTIFACT_DIR"] = str(folder)
                command = [str(executable), "--rendering-method", args.renderer,
                           "--log-file", str(folder / "engine.log")]
                if not args.exe:
                    command += ["--path", str(ROOT)]
                case_flags = LEGACY[case][0] if case in LEGACY else ["--arena-ui-regression", f"--ui-case={case}"]
                command += ["--", "--arena-acceptance", "--arena-3d", *case_flags, f"--arena-theme={theme}"]
                startup = subprocess.STARTUPINFO()
                startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
                startup.wShowWindow = subprocess.SW_HIDE
                start = time.monotonic()
                wall_start = time.time()
                with (folder / "process.log").open("wb") as log:
                    process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT,
                                               startupinfo=startup, creationflags=subprocess.CREATE_NO_WINDOW)
                    timed_out = False
                    try:
                        code = process.wait(timeout=args.timeout)
                    except subprocess.TimeoutExpired:
                        timed_out = True
                        # Only this runner's own child tree is terminated.
                        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                                       stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
                        process.wait(timeout=10)
                        code = process.returncode
                report = {}
                if (folder / "result.json").exists():
                    try:
                        report = json.loads((folder / "result.json").read_text(encoding="utf-8-sig"))
                    except (ValueError, OSError):
                        pass
                logs = "\n".join(p.read_text(encoding="utf-8-sig", errors="replace")
                                 for p in [folder / "engine.log", folder / "process.log"] if p.exists())
                errors = re.findall(r"^(?:SCRIPT ERROR:|ERROR:|.*Parse Error:).*", logs, re.M)
                if case in LEGACY:
                    report = dict(case=case, passed=LEGACY[case][1] in logs, fixture=True,
                                  input="Viewport mouse", reason="" if LEGACY[case][1] in logs else "missing acceptance marker")
                    pictures = sorted((run / "user/Godot/app_userdata/PtcgDeckAgent").glob("*.png"))
                    captured = []
                    for picture in pictures:
                        if picture.stat().st_mtime >= wall_start:
                            shutil.copy2(picture, folder / picture.name)
                            captured.append(picture.name)
                    if captured:
                        shutil.copy2(folder / captured[-1], folder / "result.png")
                    report["screenshots"] = captured
                    (folder / "result.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
                passed = bool(report.get("passed")) and code == 0 and not timed_out and not errors
                reason = ("process timeout" if timed_out else errors[0] if errors else
                          report.get("reason", "missing scenario result") if not passed else "")
                if not passed and not reason:
                    reason = f"exit code {code}" if code != 0 else "scenario did not pass"
                entry = dict(name=name, case=case, theme=theme, renderer=args.renderer,
                             passed=passed, reason=reason, exit_code=code,
                             seconds=round(time.monotonic() - start, 2),
                             artifacts=folder.relative_to(run).as_posix(), scenario=report)
                results.append(entry)
                print(f"{'PASS' if passed else 'FAIL'} {name}: {reason}", flush=True)
                write_report(run, results, executable)
    failed = sum(not r["passed"] for r in results)
    print(f"Total: {len(results)} | Failed: {failed} | Report: {run / 'report.html'}", flush=True)
    return 1 if failed else 0


def write_report(run: Path, results: list[dict], executable: Path) -> None:
    summary = {"executable": str(executable), "fixture": True, "serial": True,
               "total": len(results), "failed": sum(not r["passed"] for r in results), "results": results}
    (run / "report.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    rows = []
    for result in results:
        path = result["artifacts"]
        rows.append(f'<tr><td>{html.escape(result["name"])}</td><td>{"PASS" if result["passed"] else "FAIL"}</td>'
                    f'<td>{html.escape(str(result["reason"]))}</td><td>{result["seconds"]}s</td>'
                    f'<td><a href="{path}/result.png">截图</a> · <a href="{path}/engine.log">日志</a> · '
                    f'<a href="{path}/result.json">步骤</a></td></tr>')
    (run / "report.html").write_text('<!doctype html><meta charset="utf-8"><title>3D UI 回归</title>'
        '<style>body{font:16px system-ui;max-width:1200px;margin:40px auto;background:#f4f6f7;color:#172630}'
        'table{border-collapse:collapse;width:100%;background:white}td,th{padding:12px;text-align:left;border-bottom:1px solid #ddd}'
        'a{color:#14628c}</style><h1>3D UI 自动回归</h1><p>合成场面 · 实际 Viewport 鼠标输入 · 独立存档 · 串行运行</p>'
        f'<p>{len(results)} 项，失败 {summary["failed"]} 项</p><table><tr><th>场景</th><th>结果</th><th>原因</th><th>时间</th><th>证据</th></tr>'
        + ''.join(rows) + '</table>', encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
