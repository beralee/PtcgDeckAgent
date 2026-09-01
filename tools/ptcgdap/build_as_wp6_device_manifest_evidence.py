from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict  # noqa: E402


EVIDENCE = ROOT / "artifacts/ptcgdap/as_wp6_device_manifest"
SUMMARY = EVIDENCE / "evidence_summary.json"
MANIFEST = EVIDENCE / "manifest.json"
TEST_RESULTS = EVIDENCE / "test_results.json"
DEVICE_MANIFEST = ROOT / "data/ptcgdap/marnie_windows_device_manifest_v1.json"
ACCEPTANCE_PROFILE = ROOT / "data/ptcgdap/author_strategy_device_acceptance_profile.json"
LOCAL_EXECUTOR_MANIFEST = ROOT / "data/ptcgdap/marnie_windows_local_policy_executor_v1.json"
ROLLBACK_MANIFEST = ROOT / "data/ptcgdap/marnie_windows_policy_package_v1.json"
PARENT_UI_REPORT = ROOT / "artifacts/ptcgdap/as_wp6_local_policy_executor/windows_ui_match_report.json"
RUNTIME_REPORT = ROOT / "artifacts/ptcgdap/as_wp6_windows_deterministic_export/reproducibility_report.json"

DEVICE_MANIFEST_CANONICAL = "FCEEFEC13989C49A796905F98C099DF6E4C9C486773EA264250C75E0F39B8948"
ACCEPTANCE_PROFILE_CANONICAL = "A8971FDEC09DE2B22DC131FEC35146A32013E6D7928BFDD46847B567B2B95169"
LOCAL_EXECUTOR_CANONICAL = "6961EEECEEB33459002A40A52AA76AB0243871439D3FDF10B9F1F4927AB6D6E0"
ROLLBACK_CANONICAL = "3243ABD7937B3F53D8E5D7A887FC90BFBDF9A4D94E4030A3A9BE194C82370FFC"

FILES = (
    "artifacts/ptcgdap/as_wp6_device_manifest/README.md",
    "artifacts/ptcgdap/as_wp6_device_manifest/known_gaps.md",
    "artifacts/ptcgdap/as_wp6_device_manifest/test_results.json",
    "artifacts/ptcgdap/as_wp6_device_manifest/evidence_summary.json",
    "artifacts/ptcgdap/as_wp6_local_policy_executor/windows_ui_match_report.json",
    "artifacts/ptcgdap/as_wp6_local_policy_executor/evidence_summary.json",
    "artifacts/ptcgdap/as_wp6_windows_deterministic_export/reproducibility_report.json",
    "contracts/ptcgdap/device_manifest_v1.schema.json",
    "contracts/ptcgdap/device_manifest_v1_profile.json",
    "contracts/ptcgdap/device_manifest_v1_bundle.json",
    "data/ptcgdap/marnie_windows_device_manifest_v1.json",
    "data/ptcgdap/author_strategy_device_acceptance_profile.json",
    "data/ptcgdap/marnie_windows_local_policy_executor_v1.json",
    "data/ptcgdap/marnie_windows_policy_package_v1.json",
    "scripts/ai/ptcgdap/runtime/local/DeviceManifest.gd",
    "scripts/ai/ptcgdap/runtime/local/LocalPolicyExecutorManifest.gd",
    "tests/ptcgdap/test_device_manifest_v1.py",
    "tests/ptcgdap/test_as_wp6_device_manifest_evidence.py",
    "tests/ptcgdap/godot/test_device_manifest.gd",
    "tools/ptcgdap/build_device_manifest_v1.py",
    "tools/ptcgdap/build_as_wp6_device_manifest_evidence.py",
    "docs/ptcgdap/07-decisions-risks-and-open-questions.md",
    "docs/ptcgdap/08-author-strategy-package-mode.md",
    "docs/ptcgdap/09-author-strategy-package-engineering-handoff.md",
    "docs/ptcgdap/STATUS.md",
    "docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md",
)


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def canonical_sha(path: Path) -> str:
    return sha(canonical_json_v1_bytes(load_json_strict(path)))


def render(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def file_entry(relative: str) -> dict[str, object]:
    path = ROOT / relative
    value = path.read_bytes()
    row: dict[str, object] = {
        "path": relative,
        "bytes": len(value),
        "raw_sha256": sha(value),
    }
    if path.suffix.lower() == ".json":
        row["canonical_sha256"] = canonical_sha(path)
    return row


def build_summary() -> dict[str, object]:
    device = load_json_strict(DEVICE_MANIFEST)
    acceptance = load_json_strict(ACCEPTANCE_PROFILE)
    results = load_json_strict(TEST_RESULTS)
    parent = load_json_strict(PARENT_UI_REPORT)
    runtime = load_json_strict(RUNTIME_REPORT)
    if canonical_sha(DEVICE_MANIFEST) != DEVICE_MANIFEST_CANONICAL:
        raise ValueError("D054 device manifest drift")
    if canonical_sha(ACCEPTANCE_PROFILE) != ACCEPTANCE_PROFILE_CANONICAL:
        raise ValueError("D054 acceptance profile drift")
    if canonical_sha(LOCAL_EXECUTOR_MANIFEST) != LOCAL_EXECUTOR_CANONICAL:
        raise ValueError("D054 D053 parent drift")
    if canonical_sha(ROLLBACK_MANIFEST) != ROLLBACK_CANONICAL:
        raise ValueError("D054 D051 rollback drift")
    if type(device) is not dict or device.get("document_type") != "device_manifest_v1":
        raise ValueError("D054 manifest invalid")
    if (
        device.get("target_platforms") != [{
            "os": "windows", "architecture": "x86_64", "abi": "windows-x86_64",
            "host": "godot", "minimum_runtime_version": "4.6.1",
            "runtime_build": "4.6.1.stable.official.14d19694e",
            "portable_baseline": "gdscript",
        }]
        or device.get("inference_backend", {}).get("kind") != "none"
        or device.get("model_artifacts") != []
        or device.get("execution", {}).get("location") != "device_local"
        or device.get("execution", {}).get("aligned_ai_network") != "denied"
        or device.get("execution", {}).get("external_compute") != "denied"
        or device.get("release_status", {}).get("p6_04_windows_manifest_complete") is not True
        or device.get("release_status", {}).get("device_profile_approved") is not True
        or any(device.get("release_status", {}).get(key) is not False for key in (
            "os_network_isolation_proven", "production_ready",
            "a2_claimed", "a5_claimed", "android_claimed",
        ))
    ):
        raise ValueError("D054 claim boundary invalid")
    if (
        type(acceptance) is not dict
        or acceptance.get("approval_status") != "approved"
        or acceptance.get("formal_a5_eligible") is not False
        or acceptance.get("measurement_method", {}).get("airplane_or_os_block_required") is not False
        or device.get("resource_profile", {}).get("acceptance_claim") is not True
        or device.get("resource_profile", {}).get("limits")
        != acceptance.get("platforms", {}).get("windows")
    ):
        raise ValueError("D054 resource profile invalid")
    if (
        device.get("package_integrity", {}).get("production_signature_status") != "unprovisioned"
        or device.get("package_integrity", {}).get("development_unsigned_allowed") is not True
        or device.get("package_integrity", {}).get("signing_key_id") is not None
    ):
        raise ValueError("D054 signature boundary invalid")
    if (
        type(results) is not dict
        or results.get("python", {}).get("passed") != 6
        or results.get("python", {}).get("failed") != 0
        or results.get("godot", {}).get("passed") != 2
        or results.get("godot", {}).get("failed") != 0
    ):
        raise ValueError("D054 test results invalid")
    godot_log = ROOT / str(results["godot"]["log_path"])
    if "Total: 2 | Failed: 0" not in godot_log.read_text(encoding="utf-8", errors="replace"):
        raise ValueError("D054 Godot log invalid")
    check = subprocess.run(
        [sys.executable, str(ROOT / "tools/ptcgdap/build_device_manifest_v1.py"), "--check"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if check.returncode != 0:
        raise ValueError("D054 generator drift: " + check.stdout + check.stderr)
    if (
        type(parent) is not dict
        or parent.get("accepted") is not True
        or parent.get("terminal_games") != 1
        or type(parent.get("policy_calls")) is not int
        or parent.get("policy_calls") < 1
        or parent.get("policy_successes") != parent.get("policy_calls")
        or type(parent.get("engine_commits")) is not int
        or parent.get("engine_commits") < 1
        or parent.get("engine_commits") > parent.get("policy_calls")
        or parent.get("failure_counters_total") != 0
    ):
        raise ValueError("D054 D053 exported parent invalid")
    if type(runtime) is not dict or runtime.get("godot_version") != "4.6.1.stable.official.14d19694e":
        raise ValueError("D054 runtime evidence invalid")
    return {
        "document_type": "as_wp6_device_manifest_evidence_summary_v1",
        "schema_version": 1,
        "decision_id": "D054",
        "work_package": "AS-WP6/P6-04",
        "status": "windows_device_manifest_complete",
        "generated_on": "2026-08-15",
        "device_manifest": {
            "manifest_id": device["manifest_id"],
            "canonical_sha256": DEVICE_MANIFEST_CANONICAL,
            "platform": "windows",
            "architecture": "x86_64",
            "abi": "windows-x86_64",
            "minimum_runtime_version": "4.6.1",
            "runtime_build": "4.6.1.stable.official.14d19694e",
            "portable_baseline": "gdscript",
            "execution_location": "device_local",
            "model_backend": "none",
            "local_executor_manifest_canonical_sha256": LOCAL_EXECUTOR_CANONICAL,
            "rollback_manifest_canonical_sha256": ROLLBACK_CANONICAL,
            "device_acceptance_profile_canonical_sha256": ACCEPTANCE_PROFILE_CANONICAL,
        },
        "validation": {
            "python_passed": 6,
            "godot_passed": 2,
            "parent_exported_terminal_games": 1,
            "parent_policy_successes": 59,
            "parent_engine_commits": 59,
            "parent_failure_counters_total": 0,
        },
        "claims": {
            "p6_04_windows_device_manifest": True,
            "device_profile_approved": True,
            "production_signature_provisioned": False,
            "os_network_isolation": False,
            "production_ready": False,
            "a2_claimed": False,
            "a5_claimed": False,
            "android_claimed": False,
        },
    }


def build_manifest() -> dict[str, object]:
    return {
        "document_type": "as_wp6_device_manifest_evidence_manifest_v1",
        "schema_version": 1,
        "decision_id": "D054",
        "files": [file_entry(path) for path in FILES],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--write", action="store_true")
    group.add_argument("--check", action="store_true")
    args = parser.parse_args()
    expected_summary = render(build_summary())
    if args.write:
        SUMMARY.write_bytes(expected_summary)
        MANIFEST.write_bytes(render(build_manifest()))
        print("D054 evidence written")
    else:
        if not SUMMARY.is_file() or SUMMARY.read_bytes() != expected_summary:
            raise SystemExit("D054 evidence summary drift")
        expected_manifest = render(build_manifest())
        if not MANIFEST.is_file() or MANIFEST.read_bytes() != expected_manifest:
            raise SystemExit("D054 evidence manifest drift")
        print("D054 evidence verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
