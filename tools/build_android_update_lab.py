"""Build a separate two-version Android lab from the actual application updater.

No production version, package identity, export presets, feed, or server is changed.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def build(godot: Path, output: Path) -> None:
    project = ROOT / ".tmp" / "android-update-lab-project"
    project.mkdir(parents=True, exist_ok=True)
    output.mkdir(parents=True, exist_ok=True)
    sources = [
        *[f"scripts/update/{name}.gd" for name in ("AppUpdater", "AppUpdateManifest", "AppUpdateInstaller", "AppUpdateDialog", "AppUpdateProgress")],
        "scripts/ui/HudTheme.gd", "assets/fonts/NotoSansSC-VF.ttf",
        "addons/app_updater/plugin.cfg", "addons/app_updater/export_plugin.gd", "addons/app_updater/PtcgAppUpdater.aar",
    ]
    for name in sources:
        destination = project / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / name, destination)
    (project / "lab").mkdir(exist_ok=True)
    for path in (ROOT / "tools/update_lab").glob("*.gd"):
        shutil.copy2(path, project / "lab" / path.name)
    (project / "scripts/app").mkdir(parents=True, exist_ok=True)
    (project / "payload").mkdir(exist_ok=True)
    (project / "scenes/main_menu").mkdir(parents=True, exist_ok=True)
    (project / "scenes/main_menu/MainMenu.tscn").write_text('''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://lab/Main.gd" id="1"]
[node name="MainMenu" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")
''', encoding="utf-8")
    (project / "project.godot").write_text('''config_version=5
[application]
config/name="PtcgUpdateLab"
run/main_scene="res://scenes/main_menu/MainMenu.tscn"
[autoload]
AppUpdater="*res://lab/LabUpdater.gd"
[display]
window/size/viewport_width=432
window/size/viewport_height=900
window/stretch/mode="canvas_items"
window/handheld/orientation=1
[gui]
theme/default_font="res://assets/fonts/NotoSansSC-VF.ttf"
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/vram_compression/import_etc2_astc=true
[editor_plugins]
enabled=PackedStringArray("res://addons/app_updater/plugin.cfg")
''', encoding="utf-8")
    def configure(code: int) -> None:
        version = "1.0.0" if code == 1 else "1.0.1"
        (project / "scripts/app/AppVersion.gd").write_text(f'''extends RefCounted
const VERSION := "{version}"
const BUILD_NUMBER := {code}
static func current_version() -> String: return VERSION
static func current_display_version() -> String: return "验证版 " + VERSION
static func current_build_number() -> int: return BUILD_NUMBER
''', encoding="utf-8")
        (project / "export_presets.cfg").write_text(f'''[preset.0]
name="Android Lab"
platform="Android"
runnable=true
custom_features="app_update_lab"
export_filter="all_resources"
include_filter="payload/*.apk,lab/*.json"
exclude_filter=""
export_path=""
script_export_mode=2
[preset.0.options]
gradle_build/use_gradle_build=true
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=true
version/code={code}
version/name="{version}"
package/unique_name="cn.skillserver.ptcg.updatelab"
package/name="升级验证"
package/signed=true
permissions/internet=true
screen/immersive_mode=false
screen/edge_to_edge=false
user_data_backup/allow=false
''', encoding="utf-8")
    def run(label: str, *args: str) -> None:
        with (output / (label + ".log")).open("w", encoding="utf-8") as log:
            result = subprocess.run([str(godot), "--headless", "--path", str(project), *args], stdout=log, stderr=subprocess.STDOUT, timeout=600)
        if result.returncode or "SCRIPT ERROR:" in (output / (label + ".log")).read_text(encoding="utf-8", errors="replace"):
            raise RuntimeError(f"{label} failed; inspect {output / (label + '.log')}")
        print(f"{label}: exit 0", flush=True)
    payload = project / "payload/release.apk"
    if payload.exists():
        payload.unlink()  # Exact lab-owned file only; never recursively clear projects.
    (project / "lab/release.json").write_text("{}", encoding="utf-8")
    configure(2)
    run("import-b", "--editor", "--import", "--quit")
    if not (project / "android/build/build.gradle").exists():
        source = Path(os.environ["APPDATA"]) / "Godot/export_templates/4.6.1.stable/android_source.zip"
        android_build = project / "android/build"
        android_build.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(source) as archive:
            for item in archive.infolist():
                if not (android_build / item.filename).resolve().is_relative_to(android_build.resolve()):
                    raise ValueError("Unsafe template entry")
            archive.extractall(android_build)
        (project / "android/.build_version").write_text("4.6.1.stable\n", encoding="utf-8")
        (android_build / ".gdignore").touch()
    target = output / "B-update-payload.apk"
    # Local HTTP fixtures are permitted only in this separate debug application.
    manifest = project / "android/build/src/main/AndroidManifest.xml"
    content = manifest.read_text(encoding="utf-8")
    if 'android:usesCleartextTraffic=' not in content:
        manifest.write_text(content.replace("<application", '<application android:usesCleartextTraffic="true"', 1), encoding="utf-8")
    run("export-b", "--export-debug", "Android Lab", str(target), "--quit")
    shutil.copy2(target, payload)
    with target.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    release = {"arch": "universal", "format": "android_apk", "entry": "UpdateLab.apk", "size": target.stat().st_size, "sha256": digest, "build": 2}
    (project / "lab/release.json").write_text(json.dumps(release), encoding="utf-8")
    configure(1)
    run("import-a", "--editor", "--import", "--quit")
    run("export-a", "--export-debug", "Android Lab", str(output / "Install-A-first.apk"), "--quit")
    shutil.copy2(ROOT / "tools/update_lab/serve_lab.py", output / "serve_lab.py")
    shutil.copy2(ROOT / "docs/updates/android-validation.md", output / "使用说明.md")
    (output / "start-lan.ps1").write_text("Set-Location -LiteralPath $PSScriptRoot\npython ./serve_lab.py --package ./B-update-payload.apk\n", encoding="utf-8")
    (output / "build-info.json").write_text(json.dumps({"package": "cn.skillserver.ptcg.updatelab", "initial": "1.0.0 / 1", "target": "1.0.1 / 2", "payload": release, "production_modified": False}, indent=2), encoding="utf-8")
    checksums = []
    for name in ("Install-A-first.apk", "B-update-payload.apk"):
        package = output / name
        with package.open("rb") as stream:
            checksums.append({"name": name, "bytes": package.stat().st_size, "sha256": hashlib.file_digest(stream, "sha256").hexdigest()})
    (output / "checksums.json").write_text(json.dumps(checksums, indent=2), encoding="utf-8")
    print(f"Ready: {output / 'Install-A-first.apk'}", flush=True)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, default=Path("D:/ai/godot/Godot_v4.6.1-stable_win64.exe"))
    parser.add_argument("--output", type=Path, default=ROOT / "output/android-update-lab")
    options = parser.parse_args()
    build(options.godot.resolve(), options.output.resolve())
