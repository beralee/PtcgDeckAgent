#!/usr/bin/env python3
"""Export the macOS rules player from a fresh, recorded public source snapshot.

Godot 4.6.1 on macOS crashes during import when a discovered GDExtension
references an absent dylib. Preset exclusions only apply later, during export.
Ignore that optional descriptor in the snapshot, never in the shared checkout.
"""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import plistlib
import re
import shutil
import subprocess
import uuid

PUBLIC_ROOTS = {"addons", "assets", "bin", "community", "contracts", "data",
                "scenes", "scripts", "tests", "web"}
PROJECT_FILES = {"project.godot", "export_presets.cfg", "LICENSE"}
NATIVE = Path("scripts/ai/ptcgdap/native")


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def prepare_snapshot(root, destination, names):
    destination.mkdir(parents=True, exist_ok=False)
    manifest = {}
    for name in sorted(set(names)):
        relative = Path(name)
        if not name or relative.is_absolute() or ".." in relative.parts:
            continue
        if relative.parts[0] not in PUBLIC_ROOTS and name not in PROJECT_FILES:
            continue
        if any(part.startswith(".") and part != ".gdignore" for part in relative.parts):
            continue
        source = root / relative
        if not source.is_file() or source.is_symlink():
            continue
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        manifest[name] = sha256(target)
    (destination / NATIVE).mkdir(parents=True, exist_ok=True)
    (destination / NATIVE / ".gdignore").write_text(
        "# Mac rules snapshot: optional native model backend is not shipped.\n"
    )
    return manifest


def has_engine_errors(log):
    return bool(re.search(r"(?m)^(?:SCRIPT ERROR:|ERROR:)|Parse Error:|uncaught exception", log))


def run_logged(command, path, timeout=600):
    with path.open("w") as output:
        result = subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, timeout=timeout)
    if result.returncode or has_engine_errors(path.read_text(errors="replace")):
        raise RuntimeError(f"Command failed ({result.returncode}); see {path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path,
                        help="New directory; existing output is never overwritten")
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--diagnostic", action="store_true",
                        help="Separate test-only export with isolated user data and UI acceptance runner")
    args = parser.parse_args()
    if platform.system() != "Darwin":
        parser.error("Run on macOS for native signature and bundle verification")
    root = Path(__file__).resolve().parents[2]
    presets = (root / "export_presets.cfg").read_text()
    mac = next((block for block in re.split(r"(?=\[preset\.\d+\])", presets)
                if 'name="macOS"' in block), "")
    excluded = re.search(r'^exclude_filter="([^"]*)"', mac, re.M)
    required_exclusions = {"scripts/ai/ptcgdap/native/ptcgai_ort_actor.gdextension", "bin/ptcgai_ort/**", "tests/**"}
    if excluded is None or not required_exclusions.issubset(set(excluded[1].split(","))):
        parser.error("This tool requires the rules-only macOS preset; model exports need native build verification")
    godot = args.godot.resolve()
    version = subprocess.check_output([str(godot), "--version"], text=True).strip()
    if version != "4.6.1.stable.official.14d19694e":
        parser.error(f"Expected official Godot 4.6.1; got {version}")
    out = args.output_root.resolve()
    out.mkdir(parents=True, exist_ok=False)
    names = subprocess.check_output(
        ["git", "ls-files", "-c", "-o", "--exclude-standard", "-z"], cwd=root
    ).decode().split("\0")
    snapshot = out / "source"
    manifest = prepare_snapshot(root, snapshot, names)
    if args.diagnostic:
        project = (snapshot / "project.godot").read_text()
        project = project.replace('[autoload]', '[autoload]\n\nMacOSRulesAcceptanceRunner="*res://tests/ai/ptcgdap/MacOSRulesAcceptanceRunner.gd"')
        project = project.replace('[application]', '[application]\n\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="PtcgDAP-macOS-acceptance-' + uuid.uuid4().hex[:12] + '"')
        (snapshot / "project.godot").write_text(project)
        diagnostic_mac = mac.replace('tests/**,', '').replace('include_filter="', 'include_filter="tests/**,', 1)
        diagnostic_mac = diagnostic_mac.replace('com.bera.ptcgdeckdojo', 'com.bera.ptcgdeckdojo.macos-acceptance')
        (snapshot / "export_presets.cfg").write_text(presets.replace(mac, diagnostic_mac))
    (out / "source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    build = {"godot": version, "host_os": platform.mac_ver()[0],
             "host_arch": platform.machine(), "rules_only": True,
             "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
             "source_status": subprocess.check_output(["git", "status", "--short"], cwd=root, text=True),
             "diagnostic_only": args.diagnostic,
             "snapshot_changes": [str(NATIVE / ".gdignore")] + (["project.godot", "export_presets.cfg"] if args.diagnostic else []),
             "source_manifest_sha256": sha256(out / "source-manifest.json"),
             "published": False, "notarized": False}
    (out / "build.json").write_text(json.dumps(build, indent=2) + "\n")
    print(f"Prepared {len(manifest)} files: {snapshot}", flush=True)
    if args.prepare_only:
        return
    run_logged([str(godot), "--headless", "--path", str(snapshot), "--import"], out / "import.log")
    archive = out / ("PtcgDeckAgent-macOS-diagnostic.zip" if args.diagnostic else "PtcgDeckAgent-macOS-0.6.0-rules.zip")
    run_logged([str(godot), "--headless", "--path", str(snapshot),
                "--export-release", "macOS", str(archive)], out / "export.log")
    unpacked = out / "unpacked"
    subprocess.run(["ditto", "-x", "-k", str(archive), str(unpacked)], check=True)
    apps = list(unpacked.glob("*.app"))
    if len(apps) != 1:
        raise RuntimeError("Expected exactly one exported app")
    app = apps[0]
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    executable = app / "Contents/MacOS" / info["CFBundleExecutable"]
    architectures = subprocess.check_output(["lipo", "-archs", str(executable)], text=True).split()
    if set(architectures) != {"x86_64", "arm64"}:
        raise RuntimeError(f"Unexpected architectures: {architectures}")
    if list(app.rglob("*onnxruntime*")) or list(app.rglob("*ptcgai_ort*")):
        raise RuntimeError("Rules player contains a native model backend")
    run_logged(["codesign", "--verify", "--deep", "--strict", "--verbose=2", str(app)], out / "codesign.log")
    build.update({"archive_sha256": sha256(archive), "archive_bytes": archive.stat().st_size,
                  "app": str(app), "architectures": architectures, "signature_verified": True})
    (out / "build.json").write_text(json.dumps(build, indent=2) + "\n")
    print(json.dumps(build, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
