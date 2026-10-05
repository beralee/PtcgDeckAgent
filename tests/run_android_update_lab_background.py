"""Real OS-owned download checks; only the isolated Update Lab package is touched.

Use a PC LAN fixture, not the app's embedded server. --emulator-network explicitly
allows toggling networking on a disposable emulator, never on a physical phone.
"""
import argparse
import json
import re
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

from run_android_update_lab_checks import Lab, PKG
from run_android_update_lab_native import click_text


def until(check, seconds=60):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        value = check()
        if value:
            return value
        time.sleep(.5)
    raise AssertionError("Timed out waiting for background download condition")


def metadata(lab):
    raw = lab.adb("exec-out", "run-as", PKG, "cat", "shared_prefs/ptcg_system_download.xml", check=False)
    try:
        return {entry.attrib["name"]: entry.attrib.get("value", entry.text or "") for entry in ET.fromstring(raw)}
    except ET.ParseError:
        return {}


def notices(lab):
    return lab.adb("shell", "dumpsys", "notification", "--noredact").decode("utf-8", errors="replace")


def progress(lab):
    raw = notices(lab)
    match = re.search(r"android.title=String \(游戏更新 · B 版 · 1.0.1\).*?android.progress=Integer \((\d+)\)", raw, re.S)
    return int(match[1]) if match else -1


def close_process(lab):
    lab.adb("shell", "input", "keyevent", "KEYCODE_HOME")
    time.sleep(1)
    def kill_when_cached():
        lab.adb("shell", "am", "kill", PKG)
        return not lab.adb("shell", "pidof", PKG, check=False).strip()
    until(kill_when_cached, 20)


def reopen(lab):
    lab.adb("shell", "run-as", PKG, "rm", "-f", "files/lab-result.json")
    lab.adb("shell", "am", "start", "-n", PKG + "/com.godot.game.GodotAppLauncher")


def run(lab, output, url, emulator_network):
    output.parent.mkdir(parents=True, exist_ok=True)
    results = []
    def record(name, detail):
        results.append({"scenario": name, "passed": True, "report": detail})
        output.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
        print("PASS " + name, flush=True)

    lab.write("lab-server.txt", url)
    lab.adb("shell", "pm", "grant", PKG, "android.permission.POST_NOTIFICATIONS")
    lab.start("slow")
    lab.wait("slow", {"downloading"})
    until(lambda: progress(lab) >= 2)
    lab.action("background")
    time.sleep(1)
    output.with_name("game-progress.png").write_bytes(lab.adb("exec-out", "screencap", "-p"))
    task = metadata(lab)
    close_process(lab)
    before = progress(lab)
    until(lambda: progress(lab) > before + 2, 40)
    after = progress(lab)
    assert not lab.adb("shell", "pidof", PKG, check=False).strip()
    assert metadata(lab)["id"] == task["id"]
    record("notification_progress_after_process_exit", {"task": task["id"], "before": before, "after": after, "app_process_absent": True})

    reopen(lab)
    report = lab.wait("", {"downloading"})
    assert metadata(lab)["id"] == task["id"]
    record("reopen_attaches_same_system_task", report)

    if emulator_network:
        assert lab.command[-1].startswith(("emulator-", "127.0.0.1:")), "Network changes are emulator-only"
        before = progress(lab)
        try:
            lab.adb("shell", "svc", "wifi", "disable")
            lab.adb("shell", "svc", "data", "disable")
            until(lambda: "等待网络" in lab.result().get("message", ""), 45)
            report = lab.result()
        finally:
            lab.adb("shell", "svc", "data", "enable")
            lab.adb("shell", "svc", "wifi", "enable")
        until(lambda: progress(lab) > before + 2, 100)
        assert metadata(lab)["id"] == task["id"]
        record("network_loss_waits_then_resumes_same_task", {"waiting": report, "before": before, "after": progress(lab)})

    lab.action("cancel")
    report = lab.wait("", {"cancelled"})
    until(lambda: "id" not in metadata(lab))
    until(lambda: progress(lab) == -1)
    record("explicit_cancel_removes_system_task", report)

    lab.start("good")
    lab.wait("good", {"downloading"})
    until(lambda: progress(lab) >= 1)
    close_process(lab)
    until(lambda: "android.title=String (更新包已下载)" in notices(lab), 100)
    record("download_completes_with_game_closed", {"task": metadata(lab)["id"], "completion_notification": True})
    lab.adb("shell", "cmd", "statusbar", "expand-notifications")
    time.sleep(1)
    output.with_name("completed-notification.png").write_bytes(lab.adb("exec-out", "screencap", "-p"))
    click_text(lab, "更新包已下载", "更新包已下载")
    report = lab.wait("", {"ready"}, 40)
    assert report["preserved"] == "created-in-1.0.0", report
    assert "id" not in metadata(lab), "Verified private copy should release the OS cache"
    record("completion_tap_verifies_before_install", report)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", type=Path, required=True)
    parser.add_argument("--port", type=int, default=5037)
    parser.add_argument("--serial", required=True)
    parser.add_argument("--url", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--emulator-network", action="store_true")
    args = parser.parse_args()
    run(Lab(args.adb, args.port, args.serial), args.output, args.url, args.emulator_network)
