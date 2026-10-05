"""Native consent/restart/real-upgrade regression for the isolated Update Lab.

This explicitly confirms installation of B over A in the lab package only.
Requires an installed A with a complete B download and an English system UI.
"""
import argparse
import json
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

from run_android_update_lab_checks import Lab, PKG


def click_text(lab, text, required_text):
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        lab.adb("shell", "uiautomator", "dump", "/sdcard/updater-ui.xml")
        raw = lab.adb("exec-out", "cat", "/sdcard/updater-ui.xml")
        root = ET.fromstring(raw)
        nodes = list(root.iter("node"))
        if any(node.get("text") == required_text for node in nodes):
            matches = [node for node in nodes if node.get("text") == text and node.get("enabled") == "true"]
            if len(matches) == 1:
                bounds = matches[0].get("bounds").replace("][", ",").strip("[]")
                left, top, right, bottom = map(int, bounds.split(","))
                lab.adb("shell", "input", "tap", str((left + right) // 2), str((top + bottom) // 2))
                return
        time.sleep(.25)
    raise AssertionError(f"Could not observe the expected system control: {text}")


def run(lab, output):
    results = []

    def record(scenario, report):
        results.append({"scenario": scenario, "passed": True, "report": report})
        output.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
        print("PASS " + scenario, flush=True)

    def begin_install():
        lab.action("install")
        lab.wait("", {"installing", "awaiting_install"}, seconds=20)
        return lab.wait_native({"awaiting_user", "awaiting_external"})

    assert lab.result().get("version") == "1.0.0", "Install lab A first"
    lab.adb("shell", "appops", "set", PKG, "REQUEST_INSTALL_PACKAGES", "deny")
    lab.start()
    lab.wait("", {"ready"})
    lab.action("install")
    # The game renderer may pause as soon as Settings opens. Its JSON UI report
    # can lag until return; the durable native owner is authoritative here.
    lab.wait_native({"permission_required"})
    # Wait for the actual settings activity before pressing Back.
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        lab.adb("shell", "uiautomator", "dump", "/sdcard/updater-ui.xml")
        current = ET.fromstring(lab.adb("exec-out", "cat", "/sdcard/updater-ui.xml"))
        visible = {node.get("text") for node in current.iter("node")}
        if {"Allow from this source", "升级验证"} <= visible:
            break
        time.sleep(.25)
    else:
        raise AssertionError("Permission settings did not open")
    lab.adb("shell", "input", "keyevent", "KEYCODE_BACK")
    report = lab.wait("", {"ready"})
    assert report["issue"] == "permission_denied", report
    record("permission_denied_then_retry", report)

    lab.action("install")
    lab.wait_native({"permission_required"})
    click_text(lab, "Allow from this source", "升级验证")
    lab.adb("shell", "input", "keyevent", "KEYCODE_BACK")
    lab.wait_native({"awaiting_user"})
    click_text(lab, "Cancel", "Do you want to update this app?")
    report = lab.wait("", {"ready"})
    assert report["issue"] == "failed_3", report
    record("system_cancel_then_retry", report)

    begin_install()
    lab.start()  # Kill the game while the external system dialog still exists.
    report = lab.wait("", {"ready"})
    native = lab.native_status()
    assert native["status"] == "cancelled_restart" and native["token"] == "" and native["session"] == "-1", native
    record("process_death_during_confirmation", {"app": report, "native": native})

    begin_install()
    click_text(lab, "Update", "Do you want to update this app?")
    deadline = time.monotonic() + 90
    while time.monotonic() < deadline:
        package = lab.adb("shell", "dumpsys", "package", PKG).decode()
        if "versionName=1.0.1" in package and "versionCode=2 " in package:
            break
        time.sleep(.5)
    else:
        raise AssertionError(f"B was not installed: {lab.native_status()}")
    lab.start()
    report = lab.wait("", {"updated"})
    assert report["version"] == "1.0.1" and report["preserved"] == "created-in-1.0.0", report
    record("real_A_to_B_upgrade_preserves_data", report)
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
