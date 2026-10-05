"""Verify a production Android APK or Windows EXE contains the in-game updater.

Read-only packaging check; never installs, signs, uploads, or modifies an APK.
"""
import argparse
import hashlib
import json
import os
import re
import subprocess
import struct
import sys
import zipfile
from pathlib import Path

from ptcgdap.canonicalize_godot_export import PACK_HEADER_MAGIC, MAX_CONTAINER_BYTES, _parse_pck


def card_content_checks(members: dict[str, bytes]) -> dict[str, bool]:
    """Inspect the shipped resources, not the source tree or a separate lab APK."""
    binary = members.get("project.binary", b"")
    checks = {
        "card_content_bootstrap_autoload": b"*res://scripts/card_content/ContentBootstrap.gd" in binary,
        "card_content_updater_autoload": b"*res://scripts/card_content/ContentUpdater.gd" in binary,
    }
    for script in ("ContentBootstrap", "ContentUpdater", "ContentManifest", "ContentStore", "ContentPaths", "ContentUpdatePanel"):
        checks["card_content_" + script] = any(
            bool(members.get(f"scripts/card_content/{script}.{ext}")) for ext in ("gd", "gdc"))
    try:
        trust = json.loads(members.get("data/card_content/trust.json", b""))
        checks["card_content_trust"] = isinstance(trust, dict) and bool(trust) and all(
            isinstance(key, str) and isinstance(pem, str)
            and pem.startswith("-----BEGIN PUBLIC KEY-----") and "-----END PUBLIC KEY-----" in pem
            for key, pem in trust.items())
    except (ValueError, UnicodeError):
        checks["card_content_trust"] = False
    try:
        inventory = json.loads(members.get("data/card_content/runtime_classes.json", b""))
        checks["card_content_runtime_classes"] = (isinstance(inventory, dict)
            and inventory.get("schema_version") == 1 and isinstance(inventory.get("classes"), dict)
            and bool(inventory["classes"]))
    except (ValueError, UnicodeError):
        checks["card_content_runtime_classes"] = False
    paths = [path.decode("utf-8") for path in re.findall(
        rb'"path":\s*"res://([^"]+)"', members.get(".godot/global_script_class_cache.cfg", b""))]
    # Godot retains test-only global declarations after excluding tests from
    # export. They need no runtime resource; actual runtime declarations do.
    runtime_paths = [path for path in paths if not path.startswith(("tests/", "web/e2e/"))]
    checks["card_content_class_index_closed"] = bool(runtime_paths) and all(
        not path.startswith(("artifacts/", "output/", ".tmp/", "tmp/"))
        and (path in members or path.removesuffix(".gd") + ".gdc" in members)
        for path in runtime_paths)
    return checks


def find_aapt() -> Path:
    roots = [os.environ.get("ANDROID_HOME"), os.environ.get("ANDROID_SDK_ROOT")]
    if os.environ.get("LOCALAPPDATA"):
        roots.append(str(Path(os.environ["LOCALAPPDATA"]) / "Android/Sdk"))
    for root in filter(None, roots):
        candidates = sorted((Path(root) / "build-tools").glob("*/aapt*"), reverse=True)
        for path in candidates:
            if path.name in ("aapt", "aapt.exe"):
                return path
    raise ValueError("Android SDK aapt is required; pass --aapt")


def inspect(apk: Path, aapt: Path, require_release=False) -> dict:
    checks = {}
    with zipfile.ZipFile(apk) as archive:
        names = set(archive.namelist())
        checks["production_autoload"] = b"*res://scripts/update/AppUpdater.gd" in archive.read("assets/project.binary")
        content_members = {name.removeprefix("assets/"): b"" for name in names if name.startswith("assets/")}
        for name in names:
            if name in ("assets/project.binary", "assets/.godot/global_script_class_cache.cfg") or name.startswith(("assets/scripts/card_content/", "assets/data/card_content/")):
                content_members[name.removeprefix("assets/")] = archive.read(name)
        checks.update(card_content_checks(content_members))
        for script in ("AppUpdater", "AppUpdateDialog", "AppUpdateProgress", "AppUpdateManifest", "AppUpdateInstaller"):
            checks[script] = any(f"assets/scripts/update/{script}.{ext}" in names for ext in ("gd", "gdc"))
        checks["no_lab_resources"] = not any(name.startswith(("assets/lab/", "assets/tools/update_lab/", "assets/.tmp/", "assets/output/")) or name == "assets/payload/release.apk" for name in names)
        dex = b"\n".join(archive.read(name) for name in names if re.fullmatch(r"classes\d*\.dex", name))
        for native in ("PtcgAppUpdater", "AppDownloads", "DownloadNotice", "DownloadReceiver", "InstallResultReceiver", "InstallConfirmation", "VerifiedApkProvider"):
            checks[native] = f"Lcn/skillserver/ptcg/updater/{native};".encode() in dex
        for method in ("startDownload", "startFixedDownload", "getDownloadStatus", "cancelDownload", "updateNotificationsEnabled", "openUpdateNotificationSettings", "installUpdate", "installUpdateWithSystemInstaller", "cancelUpdate"):
            checks[method] = method.encode() + b"\0" in dex
    def dump(*args):
        return subprocess.run([str(aapt), "dump", *args], check=True, capture_output=True, timeout=30).stdout.decode("utf-8", errors="replace")
    badging = dump("badging", str(apk))
    manifest = dump("xmltree", str(apk), "AndroidManifest.xml")
    checks["production_package"] = "package: name='com.example.ptcgdeckagent'" in badging
    checks["install_permission"] = "android.permission.REQUEST_INSTALL_PACKAGES" in manifest
    checks["notification_permission"] = "android.permission.POST_NOTIFICATIONS" in manifest
    checks["internet_permission"] = "android.permission.INTERNET" in manifest
    checks["plugin_registered"] = "org.godotengine.plugin.v2.PtcgAppUpdater" in manifest
    checks["download_receiver_registered"] = all(value in manifest for value in ("cn.skillserver.ptcg.updater.DownloadReceiver", "android.intent.action.DOWNLOAD_COMPLETE", "android.intent.action.DOWNLOAD_NOTIFICATION_CLICKED"))
    checks["install_receiver_registered"] = "cn.skillserver.ptcg.updater.InstallResultReceiver" in manifest
    # Check the provider's own block, not unrelated exported receivers/permissions.
    provider = next((block for block in re.split(r"(?m)^ +E: ", manifest)
                     if block.startswith("provider ") and "cn.skillserver.ptcg.updater.VerifiedApkProvider" in block), "")
    checks["verified_apk_provider_registered"] = "com.example.ptcgdeckagent.app_update_apk" in provider
    checks["verified_apk_provider_private"] = bool(re.search(r"android:exported[^\n]*\(type 0x12\)0x0", provider))
    checks["verified_apk_provider_grants"] = bool(re.search(r"android:grantUriPermissions[^\n]*\(type 0x12\)0xffffffff", provider))
    checks["production_cleartext_policy"] = not re.search(r"android:usesCleartextTraffic[^\n]*\(type 0x12\)0xffffffff", manifest)
    debuggable = "application-debuggable" in badging
    if require_release:
        checks["release_not_debuggable"] = not debuggable
    with apk.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    return {"accepted": all(checks.values()), "checks": checks, "debuggable": debuggable,
            "package": badging.splitlines()[0], "bytes": apk.stat().st_size, "sha256": digest}


def inspect_windows(executable: Path) -> dict:
    if executable.stat().st_size > MAX_CONTAINER_BYTES:
        raise ValueError("Export exceeds the supported resource inspection limit")
    raw = executable.read_bytes()
    if len(raw) < 12 or not raw.startswith(b"MZ") or struct.unpack_from("<I", raw, len(raw) - 4)[0] != PACK_HEADER_MAGIC:
        raise ValueError("Windows export must contain an embedded Godot pack")
    size = struct.unpack_from("<Q", raw, len(raw) - 12)[0]
    if size <= 0 or size > len(raw) - 12:
        raise ValueError("Embedded pack size invalid")
    _, _, entries, _ = _parse_pck(raw[-12 - size:-12], allow_trailing_zero_padding=True)
    members = {name: payload for name, _, payload in entries}
    checks = {"production_autoload": b"*res://scripts/update/AppUpdater.gd" in members.get("project.binary", b""),
              "windows_helper": b"SHA256" in members.get("scripts/update/install_windows.ps1", b""),
              "no_macos_installer": "scripts/update/install_macos.sh" not in members,
              "no_lab_resources": not any(name.startswith(("lab/", "tools/update_lab/", ".tmp/", "output/")) or name == "payload/release.apk" for name in members)}
    for script in ("AppUpdater", "AppUpdateDialog", "AppUpdateProgress", "AppUpdateManifest", "AppUpdateInstaller"):
        checks[script] = any(f"scripts/update/{script}.{ext}" in members for ext in ("gd", "gdc"))
    checks.update(card_content_checks(members))
    return {"accepted": all(checks.values()), "checks": checks, "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", type=Path)
    parser.add_argument("--aapt", type=Path)
    parser.add_argument("--require-release", action="store_true")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        report = inspect_windows(args.artifact) if args.artifact.suffix.lower() == ".exe" else inspect(args.artifact, args.aapt or find_aapt(), args.require_release)
    except (OSError, ValueError, KeyError, zipfile.BadZipFile, subprocess.SubprocessError) as error:
        report = {"accepted": False, "error": str(error)}
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print("APP_UPDATE_EXPORT_" + ("PASS" if report["accepted"] else "FAIL") + ": " + str(args.output))
    if not report["accepted"]:
        print("Missing checks: " + ", ".join(key for key, passed in report.get("checks", {}).items() if not passed))
    return 0 if report["accepted"] else 1


if __name__ == "__main__":
    sys.exit(main())
