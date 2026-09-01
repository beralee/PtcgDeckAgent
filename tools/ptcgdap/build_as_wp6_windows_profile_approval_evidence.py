from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sys
from typing import Mapping


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict  # noqa: E402


EVIDENCE = ROOT / "artifacts/ptcgdap/as_wp6_windows_profile_approval"
SUMMARY = EVIDENCE / "evidence_summary.json"
MANIFEST = EVIDENCE / "manifest.json"
TEST_RESULTS = EVIDENCE / "test_results.json"
PROFILE = ROOT / "data/ptcgdap/author_strategy_device_acceptance_profile.json"
DEVICE_MANIFEST = ROOT / "data/ptcgdap/marnie_windows_device_manifest_v1.json"
QUALIFICATION = (
    ROOT
    / "artifacts/ptcgdap/as_wp6_windows_profile_qualification/windows_profile_qualification_report.json"
)
RELEASE_PROFILE = ROOT / "contracts/ptcgdap/author_strategy_release_profile.json"
RELEASE_BUNDLE = ROOT / "contracts/ptcgdap/author_strategy_release_bundle.json"
TRUST_STORE = ROOT / "data/ptcgdap/author_strategy_release_trust_store.json"
RELEASE_APPROVALS = ROOT / "data/ptcgdap/author_strategy_release_approvals.json"
CANARY_APPROVALS = ROOT / "data/ptcgdap/author_strategy_device_canary_approvals.json"
PROMPT_CONFORMANCE_APPROVALS = ROOT / "data/ptcgdap/author_strategy_prompt_conformance_approvals.json"
POLICY_PACKAGE = ROOT / "data/ptcgdap/marnie_windows_policy_package_v1.json"

APPROVED_PROFILE_CANONICAL = "A8971FDEC09DE2B22DC131FEC35146A32013E6D7928BFDD46847B567B2B95169"
PRE_APPROVAL_PROFILE_CANONICAL = "DEE312331F6415A5A44D7767D94489A24C07B51A6164FA153765E420017F18FF"
DEVICE_MANIFEST_CANONICAL = "FCEEFEC13989C49A796905F98C099DF6E4C9C486773EA264250C75E0F39B8948"
D057_RELEASE_BUNDLE_CANONICAL = "FD33109B23713EE161EC937624E5AE3CD5935DCF35ECA438922DA2D829C7201B"
CURRENT_RELEASE_BUNDLE_CANONICAL = "527D725B50946874D62C95B957DB401A5EC6F58A5A2E8653650E89E765E7AE26"
QUALIFICATION_ID = "A19C3CBB3AD8D5F9B0FA93C6D385982DBCF8D1F97F60D61D427DB5806E1150AE"
POLICY_PACKAGE_CANONICAL = "3243ABD7937B3F53D8E5D7A887FC90BFBDF9A4D94E4030A3A9BE194C82370FFC"
SEALED_D051_RELEASE_BUNDLE_CANONICAL = "8C023680073C8CD0B7A423B07B840629812B2043305EA16411765A44F7F4D1EB"

WINDOWS_LIMITS = {
    "max_cold_start_msec": 10000,
    "max_catalog_scan_msec": 1000,
    "max_match_load_msec": 6000,
    "max_decision_p95_msec": 250,
    "max_peak_memory_mib": 1024,
    "max_package_mib": 750,
    "max_thermal_status": None,
    "max_battery_drain_percent_per_hour": None,
}

FILES = (
    "artifacts/ptcgdap/as_wp6_windows_profile_approval/README.md",
    "artifacts/ptcgdap/as_wp6_windows_profile_approval/known_gaps.md",
    "artifacts/ptcgdap/as_wp6_windows_profile_approval/test_results.json",
    "artifacts/ptcgdap/as_wp6_windows_profile_approval/evidence_summary.json",
    "artifacts/ptcgdap/as_wp6_windows_profile_qualification/windows_profile_qualification_report.json",
    "artifacts/ptcgdap/as_wp6_windows_profile_qualification/evidence_summary.json",
    "artifacts/ptcgdap/as_wp6_windows_profile_qualification/manifest.json",
    "data/ptcgdap/author_strategy_device_acceptance_profile.json",
    "data/ptcgdap/marnie_windows_device_manifest_v1.json",
    "contracts/ptcgdap/author_strategy_release_profile.json",
    "contracts/ptcgdap/author_strategy_release_bundle.json",
    "data/ptcgdap/author_strategy_release_trust_store.json",
    "data/ptcgdap/author_strategy_release_approvals.json",
    "data/ptcgdap/author_strategy_device_canary_approvals.json",
    "data/ptcgdap/author_strategy_prompt_conformance_approvals.json",
    "data/ptcgdap/marnie_windows_policy_package_v1.json",
    "contracts/ptcgdap/policy_package_v1_bundle.json",
    "scripts/ai/ptcgdap/author_strategy_release.py",
    "scripts/ai/ptcgdap/policy_package.py",
    "scripts/ai/ptcgdap/packages/AuthorStrategyReleaseGate.gd",
    "scripts/ai/ptcgdap/runtime/local/PolicyPackageManifest.gd",
    "scripts/ai/ptcgdap/runtime/local/DeviceManifest.gd",
    "tools/ptcgdap/build_author_strategy_release_contract.py",
    "tools/ptcgdap/build_device_manifest_v1.py",
    "tools/ptcgdap/build_windows_profile_qualification.py",
    "tools/ptcgdap/build_author_strategy_device_report.py",
    "tools/ptcgdap/build_policy_package_v1.py",
    "tools/ptcgdap/build_as_wp6_local_policy_executor_evidence.py",
    "tools/ptcgdap/build_as_wp6_windows_profile_approval_evidence.py",
    "tests/ptcgdap/test_author_strategy_release_contract_builder.py",
    "tests/ptcgdap/test_author_strategy_release.py",
    "tests/ptcgdap/test_author_strategy_device_acceptance.py",
    "tests/ptcgdap/test_device_manifest_v1.py",
    "tests/ptcgdap/test_windows_profile_qualification.py",
    "tests/ptcgdap/test_author_strategy_device_report_builder.py",
    "tests/ptcgdap/test_policy_package_v1.py",
    "tests/ptcgdap/dragapult_acceptance_rollback.py",
    "tests/ptcgdap/test_author_strategy_development_execution.py",
    "tests/ptcgdap/test_author_strategy_windows_player_owner_evidence.py",
    "tests/ptcgdap/test_as_wp6_windows_profile_approval_evidence.py",
    "docs/ptcgdap/07-decisions-risks-and-open-questions.md",
    "docs/ptcgdap/08-author-strategy-package-mode.md",
    "docs/ptcgdap/09-author-strategy-package-engineering-handoff.md",
    "docs/ptcgdap/STATUS.md",
    "docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md",
    "data/ptcgdap/author_strategy_packages/README.md",
)


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _canonical_sha(value: object) -> str:
    return _sha(canonical_json_v1_bytes(value))


def _mapping(value: object, label: str) -> Mapping[str, object]:
    if type(value) is not dict:
        raise ValueError(f"{label} must be an object")
    return value


def _validate_profile() -> dict[str, object]:
    profile = load_json_strict(PROFILE)
    if type(profile) is not dict or _canonical_sha(profile) != APPROVED_PROFILE_CANONICAL:
        raise ValueError("D057 approved device profile identity drift")
    method = _mapping(profile.get("measurement_method"), "measurement method")
    platforms = _mapping(profile.get("platforms"), "platforms")
    if (
        profile.get("document_type") != "author_strategy_device_acceptance_profile_v1"
        or profile.get("profile_id") != "ptcgdap-device-acceptance-candidate-v1"
        or profile.get("approval_status") != "approved"
        or profile.get("formal_a5_eligible") is not False
        or platforms.get("windows") != WINDOWS_LIMITS
        or method.get("full_match_required") is not True
        or method.get("airplane_or_os_block_required") is not False
        or method.get("cold_start_samples") != 3
        or method.get("decision_samples_minimum") != 100
        or method.get("rollback_required") is not True
    ):
        raise ValueError("D057 approved device profile contract drift")
    predecessor = deepcopy(profile)
    predecessor["approval_status"] = "proposed"
    predecessor["formal_a5_eligible"] = False
    predecessor["measurement_method"]["airplane_or_os_block_required"] = True
    if _canonical_sha(predecessor) != PRE_APPROVAL_PROFILE_CANONICAL:
        raise ValueError("D057 change is not limited to approval and OS-disconnection waiver")
    return profile


def _validate_qualification() -> dict[str, object]:
    report = load_json_strict(QUALIFICATION)
    if type(report) is not dict or report.get("qualification_id") != QUALIFICATION_ID:
        raise ValueError("D057 qualification identity drift")
    profile = _mapping(report.get("profile"), "qualification profile")
    samples = _mapping(report.get("samples"), "qualification samples")
    measurements = _mapping(report.get("measurements"), "qualification measurements")
    thresholds = _mapping(report.get("threshold_evaluation"), "threshold evaluation")
    accounting = _mapping(report.get("match_accounting"), "match accounting")
    claims = _mapping(report.get("claims"), "qualification claims")
    if (
        profile.get("approval_status") != "proposed"
        or profile.get("formal_a5_eligible") is not False
        or profile.get("canonical_sha256") != PRE_APPROVAL_PROFILE_CANONICAL
        or samples.get("decision_count") != 173
        or accounting.get("ui_runs_passed") != 3
        or accounting.get("policy_calls") != 173
        or accounting.get("engine_commits") != 172
        or thresholds.get("all_limits_met") is not True
        or len(_mapping(thresholds.get("metrics"), "threshold metrics")) != 6
        or claims.get("profile_approval_granted") is not False
        or claims.get("os_network_isolation_proven") is not False
        or claims.get("production_ready") is not False
        or claims.get("a5_claimed") is not False
    ):
        raise ValueError("D057 historical qualification boundary drift")
    expected_measurements = {
        "catalog_scan_msec": 305,
        "cold_start_msec": 5252,
        "decision_p95_msec": 22,
        "match_load_msec": 2103,
        "package_mib": 262,
        "peak_memory_mib": 545,
    }
    if dict(measurements) != expected_measurements:
        raise ValueError("D057 qualification measurements drift")
    for key in (
        "policy_errors",
        "invalid_outputs",
        "same_window_fallbacks",
        "classic_fallbacks",
        "engine_rejections",
        "external_process_attempts",
    ):
        if accounting.get(key) != 0:
            raise ValueError(f"D057 qualification failure counter drift: {key}")
    return report


def _validate_release(profile: dict[str, object]) -> None:
    device = load_json_strict(DEVICE_MANIFEST)
    release_profile = load_json_strict(RELEASE_PROFILE)
    release_bundle = load_json_strict(RELEASE_BUNDLE)
    trust = load_json_strict(TRUST_STORE)
    approvals = load_json_strict(RELEASE_APPROVALS)
    canary = load_json_strict(CANARY_APPROVALS)
    prompt_conformance = load_json_strict(PROMPT_CONFORMANCE_APPROVALS)
    policy_package = load_json_strict(POLICY_PACKAGE)
    if type(device) is not dict or _canonical_sha(device) != DEVICE_MANIFEST_CANONICAL:
        raise ValueError("D057 device manifest identity drift")
    if (
        device.get("manifest_version") != "1.1.0"
        or device.get("device_acceptance_profile", {}).get("canonical_sha256")
        != APPROVED_PROFILE_CANONICAL
        or device.get("device_acceptance_profile", {}).get("approval_status") != "approved"
        or device.get("device_acceptance_profile", {}).get("formal_a5_eligible") is not False
        or device.get("resource_profile", {}).get("acceptance_claim") is not True
        or device.get("resource_profile", {}).get("limits") != profile["platforms"]["windows"]
        or device.get("release_status", {}).get("device_profile_approved") is not True
        or device.get("release_status", {}).get("os_network_isolation_proven") is not False
        or device.get("release_status", {}).get("production_ready") is not False
        or device.get("release_status", {}).get("a5_claimed") is not False
        or device.get("release_status", {}).get("android_claimed") is not False
        or device.get("package_integrity", {}).get("production_signature_status") != "unprovisioned"
    ):
        raise ValueError("D057 device manifest claim boundary drift")
    if type(release_profile) is not dict or type(release_bundle) is not dict:
        raise ValueError("D057 release contract invalid")
    prerequisites = _mapping(release_profile.get("release_prerequisites"), "release prerequisites")
    acceptance = _mapping(release_profile.get("device_acceptance"), "release acceptance")
    if (
        _canonical_sha(release_bundle) != CURRENT_RELEASE_BUNDLE_CANONICAL
        or acceptance.get("candidate_thresholds_are_claims") is not True
        or prerequisites.get("device_profile_approved") is not True
        or prerequisites.get("offline_full_match_by_platform") != {"windows": False}
        or trust != {
            "document_type": "author_strategy_release_trust_store_v1",
            "schema_version": 1,
            "store_id": "ptcgdap-product-release-trust-v1",
            "approval_status": "approved",
            "keys": [{
                "key_id": "ptcgdap.product.release.ed25519.v1",
                "algorithm": "ed25519",
                "public_key_base64": "vdpuqrowRq72ecivA+cpZfvg7deqCpX9Gq9KS292DAA=",
                "scope": "production_release",
                "execution_trusted": True,
                "status": "active",
            }],
        }
        or approvals.get("approval_status") != "unprovisioned"
        or approvals.get("records") != []
        or canary.get("approval_status") != "unprovisioned"
        or canary.get("records") != []
        or prompt_conformance.get("approval_status") != "unprovisioned"
        or prompt_conformance.get("records") != []
        or _canonical_sha(policy_package) != POLICY_PACKAGE_CANONICAL
        or policy_package.get("parents", {}).get("author_release_bundle_canonical_sha256")
        != SEALED_D051_RELEASE_BUNDLE_CANONICAL
        or policy_package.get("parents", {}).get("author_release_bundle_canonical_sha256")
        == CURRENT_RELEASE_BUNDLE_CANONICAL
    ):
        raise ValueError("D057 release boundary drift")


def _validate_results() -> None:
    results = load_json_strict(TEST_RESULTS)
    if type(results) is not dict or results.get("decision_id") != "D057":
        raise ValueError("D057 test result identity drift")
    red = _mapping(results.get("core_contract_red"), "core RED")
    green = _mapping(results.get("core_contract_green"), "core GREEN")
    evidence_red = _mapping(results.get("evidence_red"), "evidence RED")
    if (
        red.get("tests") != 29
        or red.get("failures") != 5
        or green.get("passed") != 29
        or green.get("failed") != 0
        or evidence_red.get("tests") != 3
        or evidence_red.get("failures") != 1
        or evidence_red.get("errors") != 2
    ):
        raise ValueError("D057 RED/GREEN result drift")


def build_summary() -> dict[str, object]:
    profile = _validate_profile()
    qualification = _validate_qualification()
    _validate_release(profile)
    _validate_results()
    accounting = _mapping(qualification["match_accounting"], "match accounting")
    measurements = _mapping(qualification["measurements"], "measurements")
    return {
        "document_type": "as_wp6_windows_profile_approval_evidence_summary_v1",
        "schema_version": 1,
        "decision_id": "D057",
        "work_package": "AS-WP6/P6-05/P6-08-waiver/P6-11",
        "status": "windows_profile_product_approved",
        "generated_on": "2026-08-15",
        "approval": {
            "approved_profile_canonical_sha256": APPROVED_PROFILE_CANONICAL,
            "pre_approval_profile_canonical_sha256": PRE_APPROVAL_PROFILE_CANONICAL,
            "device_manifest_canonical_sha256": DEVICE_MANIFEST_CANONICAL,
            "release_bundle_at_decision_canonical_sha256": D057_RELEASE_BUNDLE_CANONICAL,
            "current_release_bundle_canonical_sha256": CURRENT_RELEASE_BUNDLE_CANONICAL,
            "formal_a5_eligible": False,
            "os_disconnection_evidence_required": False,
        },
        "qualification": {
            "qualification_id": QUALIFICATION_ID,
            "thresholds_met": 6,
            "decision_samples": 173,
            "ordinary_ui_terminal_games": 3,
            "policy_successes": accounting["policy_calls"],
            "engine_commits": accounting["engine_commits"],
            "failure_counters_total": 0,
            "measurements": dict(measurements),
        },
        "claims": {
            "p6_05_profile_approved": True,
            "p6_11_windows_resources_accepted": True,
            "p6_08_os_disconnection": "waived_by_product",
            "os_network_isolation_proven": False,
            "production_ready": False,
            "a5_claimed": False,
            "android_claimed": False,
        },
    }


def _file_entry(relative_path: str) -> dict[str, object]:
    path = ROOT / relative_path
    raw = path.read_bytes()
    row: dict[str, object] = {
        "path": relative_path,
        "bytes": len(raw),
        "raw_sha256": _sha(raw),
    }
    if path.suffix.lower() == ".json":
        row["canonical_sha256"] = _canonical_sha(load_json_strict(path))
    return row


def build_manifest() -> dict[str, object]:
    return {
        "document_type": "as_wp6_windows_profile_approval_evidence_manifest_v1",
        "schema_version": 1,
        "decision_id": "D057",
        "files": [_file_entry(path) for path in FILES],
    }


def _render(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--write", action="store_true")
    group.add_argument("--check", action="store_true")
    args = parser.parse_args()
    expected_summary = _render(build_summary())
    if args.write:
        SUMMARY.write_bytes(expected_summary)
        MANIFEST.write_bytes(_render(build_manifest()))
        print("D057 evidence written")
    else:
        if not SUMMARY.is_file() or SUMMARY.read_bytes() != expected_summary:
            raise SystemExit("D057 evidence summary drift")
        expected_manifest = _render(build_manifest())
        if not MANIFEST.is_file() or MANIFEST.read_bytes() != expected_manifest:
            raise SystemExit("D057 evidence manifest drift")
        print("D057 evidence verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
