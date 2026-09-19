#!/usr/bin/env python3
"""Run the diagnostic Mac export online, then restart it with OS networking denied.

Build a fresh --diagnostic export first. Test-only game code drives scene controls
and supplies the human-seat opponent; this does not claim physical mouse input.
"""
import argparse
import json
from pathlib import Path
import plistlib
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args()
    app = args.app.resolve()
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    if info["CFBundleIdentifier"] != "com.bera.ptcgdeckdojo.macos-acceptance":
        parser.error("Use a fresh diagnostic export, with its own test user directory")
    executable = app / "Contents/MacOS" / info["CFBundleExecutable"]
    out = args.output_root.resolve()
    out.mkdir(parents=True, exist_ok=False)
    profile = out / "offline.sb"
    profile.write_text("(version 1) (allow default) (deny network*)\n")
    probe = subprocess.run([
        "/usr/bin/sandbox-exec", "-f", str(profile), sys.executable, "-c",
        "import socket,errno,sys\ntry:\n socket.socket().connect(('127.0.0.1',9))\n"
        "except OSError as e:\n print(type(e).__name__,e.errno);sys.exit(0 if e.errno==errno.EPERM else 1)\n"
        "sys.exit(1)",
    ], capture_output=True, text=True, timeout=15)
    (out / "network-denial-probe.log").write_text(probe.stdout + probe.stderr)
    if probe.returncode:
        raise RuntimeError("Could not prove process-local network denial")
    reports = {}
    for mode in ("online", "offline"):
        run = out / mode
        run.mkdir()
        command = [str(executable), "--log-file", str(run / "engine.log"),
                   "--", "--macos-acceptance-output=" + str(run)]
        if mode == "offline":
            command += ["--macos-offline-receipt=" + str(out / "online/report.json")]
            command = ["/usr/bin/sandbox-exec", "-f", str(profile)] + command
        with (run / "process.log").open("w") as log:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=420)
        report = json.loads((run / "report.json").read_text())
        log_text = (run / "process.log").read_text()
        report["exit_code"] = result.returncode
        report["warnings"] = [line for line in log_text.splitlines() if line.startswith("WARNING:")]
        reports[mode] = report
        (out / "acceptance.json").write_text(json.dumps(reports, indent=2, ensure_ascii=False) + "\n")
        if result.returncode or not report.get("ok") or "SCRIPT ERROR:" in log_text or "\nERROR:" in log_text:
            raise RuntimeError(f"{mode} acceptance failed; inspect {run}")
        print(f"PASS {mode}: {run}", flush=True)
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
    print(f"Online download and OS-isolated offline UI matches passed: {out}")


if __name__ == "__main__":
    main()
