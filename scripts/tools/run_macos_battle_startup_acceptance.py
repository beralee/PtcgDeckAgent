#!/usr/bin/env python3
"""Check ordinary battle startup using this checkout's actual imported resources."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import uuid

from export_macos_release import PUBLIC_ROOTS, has_engine_errors
from run_macos_game import prepare_project


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, default=Path("/Applications/Godot.app/Contents/MacOS/Godot"))
    parser.add_argument("--output-root", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    out = args.output_root.resolve()
    out.mkdir(parents=True, exist_ok=False)
    godot = args.godot.resolve()
    prepare_project(root, godot, out)
    project = out / "project"
    project.mkdir()
    # Use the real checkout/cache; only settings are copied to isolate user://.
    for name in PUBLIC_ROOTS | {".godot"}:
        if (root / name).exists():
            (project / name).symlink_to(root / name, target_is_directory=True)
    settings = (root / "project.godot").read_text().replace(
        "[application]", '[application]\nconfig/use_custom_user_dir=true\n'
        'config/custom_user_dir_name="PtcgDAP-macOS-startup-' + uuid.uuid4().hex[:12] + '"')
    (project / "project.godot").write_text(settings)
    reports = {}
    for mode in ("practice", "ai"):
        run = out / mode
        run.mkdir()
        with (run / "process.log").open("w") as log:
            result = subprocess.run([
                str(godot), "--path", str(project), "-s", "res://tests/ui/run_macos_battle_startup.gd",
                "--", "--mode=" + mode, "--output=" + str(run),
            ], stdout=log, stderr=subprocess.STDOUT, timeout=300)
        report = json.loads((run / "report.json").read_text())
        report["exit_code"] = result.returncode
        text = (run / "process.log").read_text()
        report["warnings"] = [line for line in text.splitlines() if line.startswith("WARNING:")]
        # Existing built-in AI teardown can retain resources at engine exit.
        # Record it separately from startup/input errors; do not call the log clean.
        cleanup_pattern = r"(?m)^ERROR: \d+ resources still in use at exit \(run with --verbose for details\)\.\n?"
        report["teardown_errors"] = re.findall(cleanup_pattern, text)
        report["log_clean"] = not has_engine_errors(text) and not report["warnings"]
        runtime_log = re.sub(cleanup_pattern, "", text)
        reports[mode] = report
        (out / "acceptance.json").write_text(json.dumps(reports, indent=2, ensure_ascii=False) + "\n")
        if result.returncode or not report.get("ok") or has_engine_errors(runtime_log):
            raise RuntimeError(f"{mode} failed; see {run}")
        print(f"PASS {mode}: {run}", flush=True)
        if not report["log_clean"]:
            print("  Existing exit cleanup diagnostics recorded; log_clean=false", flush=True)


if __name__ == "__main__":
    main()
