"""Exercise the isolated Android lab through real HTTP and the native APK bridge.

Requires a running emulator/device and installed Install-A-first.apk. Never targets
the actual game package. The final system confirmation is intentionally interactive.
"""
import argparse
import json
import shlex
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

PKG = "cn.skillserver.ptcg.updatelab"

class Lab:
    def __init__(self, adb, port, serial):
        self.command = [str(adb), "-P", str(port), "-s", serial]
    def adb(self, *args, data=None, check=True):
        return subprocess.run(self.command + list(args), input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=check, timeout=30).stdout
    def write(self, name, value):
        if name not in ("lab-command.txt", "lab-action.txt", "lab-server.txt"):
            raise ValueError("Only lab control files are writable")
        command = "mkdir -p files && printf '%s' " + shlex.quote(value) + " > files/" + name + ".tmp && mv files/" + name + ".tmp files/" + name
        self.adb("shell", "run-as", PKG, "sh", "-c", shlex.quote(command))
    def start(self, case=None):
        self.adb("shell", "am", "force-stop", PKG)
        self.adb("shell", "run-as", PKG, "rm", "-f", "files/lab-result.json")
        if case is not None:
            self.write("lab-command.txt", case)
        self.adb("shell", "am", "start", "-n", PKG + "/com.godot.game.GodotAppLauncher")
    def result(self):
        raw = self.adb("exec-out", "run-as", PKG, "cat", "files/lab-result.json", check=False)
        try:
            return json.loads(raw)
        except (ValueError, UnicodeDecodeError):
            return {}
    def wait(self, case, states, seconds=150):
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            report = self.result()
            if report.get("case") == case and report.get("state") in states:
                return report
            time.sleep(.5)
        raise AssertionError(f"Timed out: {case}: {self.result()}")
    def action(self, value):
        self.write("lab-action.txt", value)
    def native_status(self):
        raw = self.adb("exec-out", "run-as", PKG, "cat", "shared_prefs/ptcg_app_update.xml", check=False)
        try:
            return {entry.attrib["name"]: entry.attrib.get("value", entry.text or "") for entry in ET.fromstring(raw)}
        except ET.ParseError:
            return {}
    def wait_native(self, states, seconds=30):
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            report = self.native_status()
            if report.get("status") in states:
                return report
            if report.get("status", "").startswith("failed"):
                raise AssertionError(report)
            time.sleep(.25)
        raise AssertionError(f"Native timeout: {self.native_status()}")

CASES = ("low_space", "missing", "truncated", "drop", "corrupt", "invalid", "deleted", "wrong_build")


def run(lab, output, cases=None):
    results = json.loads(output.read_text(encoding="utf-8")) if cases and output.exists() else []
    lab.adb("shell", "appops", "set", PKG, "REQUEST_INSTALL_PACKAGES", "allow")
    for case in cases or CASES:
        lab.start(case)
        report = lab.wait(case, {"failed", "ready"})
        if case in ("invalid", "deleted", "wrong_build"):
            assert report["state"] == "ready", report
            lab.action("install")
            report = lab.wait(case, {"failed"})
        assert report["state"] == "failed", report
        expected = {"invalid": "failed_package_invalid", "wrong_build": "failed_version", "low_space": "storage"}.get(case)
        if expected:
            assert report["issue"] == expected, report
        assert report["preserved"] == "created-in-1.0.0", report
        results.append({"scenario": case, "passed": True, "report": report})
        output.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
        print("PASS " + case + ": " + report["message"], flush=True)
    # Android transport owns timeouts/retries; the UI must remain cancellable.
    lab.start("stall")
    lab.wait("stall", {"downloading"})
    time.sleep(6)
    assert lab.result()["state"] == "downloading", lab.result()
    lab.action("cancel")
    report = lab.wait("stall", {"cancelled"}, 10)
    results.append({"scenario": "stalled_system_download_can_cancel", "passed": True, "report": report})
    output.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print("PASS stalled_system_download_can_cancel", flush=True)
    lab.start("good")
    report = lab.wait("good", {"ready"})
    results.append({"scenario": "recovery_good_download", "passed": True, "report": report})
    output.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print("PASS recovery_good_download; ready for system confirmation", flush=True)

if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", type=Path, required=True)
    parser.add_argument("--port", type=int, default=5037)
    parser.add_argument("--serial", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--cases", nargs="+", choices=CASES, help="Run remaining selected cases and append to the evidence")
    args = parser.parse_args()
    run(Lab(args.adb, args.port, args.serial), args.output, args.cases)
