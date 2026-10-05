"""Real foreground handoff and compatible APK installation in the isolated lab only."""
import argparse
import json
import sys
import time
import subprocess
from pathlib import Path

from run_android_update_lab_checks import Lab, PKG
from run_android_update_lab_native import click_text


def run(lab, output):
    results = []

    def record(name, report):
        results.append({"scenario": name, "passed": True, "report": report})
        output.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
        print("PASS " + name, flush=True)

    lab.adb("shell", "appops", "set", PKG, "REQUEST_INSTALL_PACKAGES", "allow")
    lab.write("lab-server.txt", "")
    lab.start("good")
    assert lab.wait("good", {"ready"})["version"] == "1.0.0"
    lab.action("install")
    lab.wait("good", {"verifying", "installing"})
    lab.adb("shell", "input", "keyevent", "KEYCODE_HOME")
    native = lab.wait_native({"awaiting_foreground"})
    time.sleep(2)
    activity = lab.adb("shell", "dumpsys", "activity", "activities").decode(errors="replace")
    resumed = [line for line in activity.splitlines() if "topResumedActivity=" in line or "mResumedActivity:" in line]
    assert resumed and all("packageinstaller" not in line.lower() for line in resumed), resumed
    record("background_consent_is_queued_without_launch", {"native": native, "foreground": resumed})

    lab.adb("shell", "am", "start", "-n", PKG + "/com.godot.game.GodotAppLauncher")
    lab.wait_native({"awaiting_user"})
    click_text(lab, "Cancel", "Do you want to update this app?")
    report = lab.wait("good", {"ready"})
    assert report["issue"] == "failed_3", report
    record("foreground_resume_shows_real_consent_and_abort_is_distinct", report)

    lab.action("install")
    lab.wait("good", {"installing", "awaiting_install"}, seconds=20)
    native = lab.wait_native({"awaiting_external"})
    # No broad file sharing: another UID has no grant even for the active URI.
    uri = "content://" + PKG + ".app_update_apk/" + native["token"] + "/" + native["shared_apk"]
    denial = subprocess.run(lab.command + ["shell", "content", "read", "--uri", uri],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30).stdout.decode(errors="replace")
    assert "Permission Denial" in denial or "SecurityException" in denial, denial
    click_text(lab, "Cancel", "Do you want to update this app?")
    report = lab.wait("good", {"ready"})
    assert report["issue"] == "external_cancelled", report
    assert lab.native_status().get("shared_apk", "") == "", lab.native_status()
    record("compatible_installer_cancel_revokes_private_apk_grant", report)

    lab.action("install")
    lab.wait("good", {"installing", "awaiting_install"}, seconds=20)
    lab.wait_native({"awaiting_external"})
    click_text(lab, "Update", "Do you want to update this app?")
    deadline = time.monotonic() + 90
    while time.monotonic() < deadline:
        package = lab.adb("shell", "dumpsys", "package", PKG).decode()
        if "versionName=1.0.1" in package and "versionCode=2 " in package:
            break
        time.sleep(.5)
    else:
        raise AssertionError(f"Compatible install did not replace A: {lab.native_status()}")
    lab.start()
    report = lab.wait("", {"updated"})
    assert report["preserved"] == "created-in-1.0.0" and report["version"] == "1.0.1", report
    record("compatible_real_A_to_B_upgrade_preserves_data", report)
    output.with_suffix(".png").write_bytes(lab.adb("exec-out", "screencap", "-p"))


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", type=Path, required=True)
    parser.add_argument("--port", type=int, default=5037)
    parser.add_argument("--serial", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--confirm-test-update", action="store_true", required=True)
    args = parser.parse_args()
    run(Lab(args.adb, args.port, args.serial), args.output)
