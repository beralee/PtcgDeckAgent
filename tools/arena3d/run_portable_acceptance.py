"""Run the isolated diagnostic APK's rendered inventory and touch-owner probes."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import time

PACKAGE = 'com.example.ptcgdeckagent.performance'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--apk', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--groups', nargs='+', choices=['arena_review', 'arena_input', 'arena_live', 'arena_feedback'], default=['arena_review', 'arena_input'])
    parser.add_argument('--sizes', nargs='+', default=['1080x2400', '2400x1080'])
    parser.add_argument('--compact-evidence', action='store_true', help='Keep every inventory assertion but pull selected visual PNGs to conserve disk space')
    args = parser.parse_args()
    root = Path(os.environ['LOCALAPPDATA']) / 'Android/Sdk'
    adb = root / 'platform-tools/adb.exe'
    remote = f'/sdcard/Android/data/{PACKAGE}/files/performance'
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)

    def command(parts, timeout=120):
        result = subprocess.run([str(x) for x in parts], capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=timeout)
        if result.returncode: raise RuntimeError(result.stdout + result.stderr)
        return result.stdout

    def device(*parts): return command([adb, '-s', args.device, *parts])

    badging = command([root / 'build-tools/36.1.0/aapt.exe', 'dump', 'badging', args.apk])
    if not re.search(r"^package: name='" + re.escape(PACKAGE) + r"' ", badging, re.M):
        raise RuntimeError('Only the diagnostic package may be installed or cleared')
    device('wait-for-device')
    device('install', '-r', args.apk.resolve())
    original_size = device('shell', 'wm', 'size')
    results = []
    try:
        for size in args.sizes:
            if not re.fullmatch(r'\d+x\d+', size): raise ValueError('Invalid size')
            device('shell', 'wm', 'size', size)
            for group in args.groups:
                folder = output / f'{size}-{group}'
                folder.mkdir()
                device('shell', 'am', 'force-stop', PACKAGE)
                device('shell', 'pm', 'clear', PACKAGE)
                request = folder / 'request.json'
                requested_window = [int(v) for v in size.split('x')]
                request.write_text(json.dumps({'group': group, 'repeat': 1, 'window': requested_window}), encoding='utf-8')
                device('shell', 'am', 'start', '-W', '-n', PACKAGE + '/com.godot.game.GodotAppLauncher')
                pid = device('shell', 'pidof', PACKAGE).strip()
                for _ in range(100):
                    exists = subprocess.run([str(adb), '-s', args.device, 'shell', 'test', '-d', remote], capture_output=True)
                    if exists.returncode == 0: break
                    time.sleep(.2)
                else: raise RuntimeError('App did not create its diagnostic directory')
                device('push', request, remote + '/request.json')
                complete = False
                failure_reason = 'probe_timed_out'
                missing_process_samples = 0
                for _ in range(150):
                    exists = subprocess.run([str(adb), '-s', args.device, 'shell', 'test', '-f', remote + '/result.json'], capture_output=True, timeout=15)
                    if exists.returncode == 0:
                        complete = True
                        break
                    alive = subprocess.run([str(adb), '-s', args.device, 'shell', 'pidof', PACKAGE], capture_output=True, text=True, timeout=15)
                    process_exists = subprocess.run([str(adb), '-s', args.device, 'shell', 'test', '-d', '/proc/' + pid], capture_output=True, timeout=15)
                    missing_process_samples = missing_process_samples + 1 if pid not in alive.stdout.split() and process_exists.returncode == 1 and not process_exists.stderr else 0
                    if missing_process_samples >= 3:
                        # Failed probes can quit before writing their result. Keep
                        # their logs and continue the matrix instead of waiting
                        # out the entire timeout and losing later cases.
                        failure_reason = 'probe_exited_without_result'
                        (folder / 'process-exit.json').write_text(json.dumps({'expected_pid': pid, 'pidof_stdout': alive.stdout, 'pidof_stderr': alive.stderr, 'pidof_exit': alive.returncode, 'proc_exit': process_exists.returncode, 'consecutive_absent_samples': missing_process_samples}, indent=2), encoding='utf-8')
                        break
                    time.sleep(1)
                log = device('logcat', '-d', f'--pid={pid}', '-v', 'brief')
                (folder / 'engine.log').write_text(log, encoding='utf-8')
                if args.compact_evidence:
                    (folder / 'app').mkdir()
                    for name in device('shell','ls','-1',remote).splitlines():
                        if '/' in name or '\\' in name or name.startswith('.'): continue
                        if name.endswith('.json') or name.startswith('platform') or name in ['board.png','result.png','pokemon-charizard.png','supporter-boss.png','supporter-iono.png']:
                            device('pull',remote+'/'+name,folder/'app'/name)
                else:
                    device('pull', remote + '/.', folder / 'app')
                errors = bool(re.search(r'SCRIPT ERROR:|(?:^|\s)ERROR:', log, re.M))
                report_path = folder / 'app/result.json'
                # The app may have written the report between the existence
                # check and exiting. The copied report resolves that race.
                complete = report_path.is_file()
                report = json.loads(report_path.read_text(encoding='utf-8-sig')) if complete else {}
                if not complete:
                    passed = False
                elif group == 'arena_review':
                    visual = json.loads((folder / 'app/visual-inventory.json').read_text(encoding='utf-8-sig'))
                    checks = visual['checks']
                    passed = len(checks) == 32 and all(c['accepted'] and c.get('joints_retained', True) and c.get('pose_count', 6) == 6 for c in checks)
                    passed = passed and report['platform']['os'] == 'Android' and visual['low'] and report['platform']['window'] == requested_window
                else: passed = report.get('passed', False) and report.get('platform') == 'Android' and report.get('window') == requested_window
                results.append({'size': size, 'group': group, 'passed': passed and not errors, 'engine_errors': errors})
                if not complete: results[-1]['failure_reason'] = failure_reason
                print(json.dumps(results[-1]), flush=True)
                complete = len(results) == len(args.sizes)*len(args.groups)
                (output / 'summary.json').write_text(json.dumps({'complete': complete, 'passed': complete and all(r['passed'] for r in results), 'results': results}, indent=2), encoding='utf-8')
    finally:
        override = re.search(r'Override size: (\d+x\d+)', original_size)
        device('shell', 'wm', 'size', override[1] if override else 'reset')
        device('shell', 'am', 'force-stop', PACKAGE)
    return int(not all(r['passed'] for r in results))


if __name__ == '__main__': raise SystemExit(main())
