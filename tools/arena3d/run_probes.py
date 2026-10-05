"""Run the standalone Arena SceneTree probes serially with bounded lifetimes."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', type=Path, default=Path('D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe'))
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--renderer', default='gl_compatibility', choices=['gl_compatibility', 'forward_plus'])
    parser.add_argument('--timeout', type=int, help='Process limit in seconds; defaults to 200 for a full match, 100 otherwise')
    parser.add_argument('--probe', action='append', help='Exact probe filename; defaults to all test_arena3d*.gd scripts')
    parser.add_argument('--full-match', action='store_true')
    parser.add_argument('--exe', type=Path, help='Run the exported Windows platform acceptance instead of source probes')
    args = parser.parse_args()
    # The full-match probe has its own 180-second terminal deadline. Its
    # outer process guard must leave time for that verdict and clean exit.
    if args.timeout is None:
        args.timeout = 200 if args.full_match else 100
    run = args.output.resolve() / time.strftime('run-%Y%m%d-%H%M%S')
    run.mkdir(parents=True, exist_ok=False)
    probes = sorted(ROOT.glob('tests/test_arena3d*.gd'))
    if args.probe:
        requested = set(args.probe)
        probes = [p for p in probes if p.name in requested]
        if {p.name for p in probes} != requested: parser.error('Unknown probe')
    if not probes or args.timeout <= 0: parser.error('Empty probes or invalid timeout')
    if args.exe and (not args.exe.is_file() or [p.name for p in probes] != ['test_arena3d_platforms.gd']):
        parser.error('--exe requires an existing executable and --probe test_arena3d_platforms.gd')
    results = []
    for probe in probes:
        folder = run / probe.stem
        folder.mkdir()
        env = os.environ.copy()
        env['APPDATA'] = str(folder / 'user')
        command = [str(args.godot), '--path', str(ROOT), '--rendering-method', args.renderer,
                   '--log-file', str(folder / 'engine.log'), '-s', 'res://' + probe.relative_to(ROOT).as_posix(),
                   '--']

        if probe.name != 'test_arena3d_product_entry.gd': command.append('--arena-3d')
        if args.full_match: command.append('--arena-full-match')
        if args.exe:
            command = [str(args.exe.resolve()), '--rendering-method', args.renderer, '--log-file', str(folder / 'engine.log'),
                       '--', '--arena-acceptance', '--arena-3d', '--arena-platform-checks']
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = subprocess.SW_HIDE
        started = time.monotonic()
        timed_out = False
        with (folder / 'console.log').open('wb') as log:
            process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT,
                                       startupinfo=startup, creationflags=subprocess.CREATE_NO_WINDOW)
            try:
                code = process.wait(timeout=args.timeout)
            except subprocess.TimeoutExpired:
                timed_out = True
                subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], stdout=log, stderr=subprocess.STDOUT)
                process.wait(timeout=10)
                code = process.returncode
        logs = '\n'.join(p.read_text(encoding='utf-8-sig', errors='replace') for p in folder.glob('*.log'))
        errors = re.findall(r'^(?:SCRIPT ERROR:|ERROR:).*', logs, re.M)
        markers = re.findall(r'^ARENA[^\n]*PASS[^\n]*', logs, re.M)
        passed = code == 0 and not timed_out and not errors and bool(markers)
        if args.full_match: passed = passed and 'ARENA3D FULL MATCH PASS' in logs
        entry = dict(probe=probe.name, passed=passed, exit_code=code, timed_out=timed_out,
                     seconds=round(time.monotonic()-started, 2), errors=errors, markers=markers)
        results.append(entry)
        print(('PASS ' if passed else 'FAIL ') + probe.name, flush=True)
        (run / 'report.json').write_text(json.dumps(dict(renderer=args.renderer, results=results,
            total=len(results), failed=sum(not row['passed'] for row in results)), indent=2), encoding='utf-8')
    return int(any(not row['passed'] for row in results))


if __name__ == '__main__':
    sys.exit(main())
