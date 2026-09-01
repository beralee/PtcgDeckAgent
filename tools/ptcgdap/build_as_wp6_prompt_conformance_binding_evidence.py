from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.author_strategy_release import AuthorStrategyReleaseGate  # noqa: E402
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict  # noqa: E402
from tools.ptcgdap.build_author_strategy_release_contract import build_artifacts  # noqa: E402


EVIDENCE = ROOT / "artifacts/ptcgdap/as_wp6_prompt_conformance_binding"
SUMMARY = EVIDENCE / "evidence_summary.json"
MANIFEST = EVIDENCE / "manifest.json"
TEST_RESULTS = EVIDENCE / "test_results.json"
RELEASE_BUNDLE = ROOT / "contracts/ptcgdap/author_strategy_release_bundle.json"
RELEASE_PROFILE = ROOT / "contracts/ptcgdap/author_strategy_release_profile.json"
PROMPT_APPROVALS = ROOT / "data/ptcgdap/author_strategy_prompt_conformance_approvals.json"

DECISION_ID = "D069"
D069_RELEASE_BUNDLE_CANONICAL = "EE37BB9A6AC1F5A97AC48C69DAFA4804364080D9B46B1F104240069200DB101A"
CURRENT_RELEASE_BUNDLE_CANONICAL = "527D725B50946874D62C95B957DB401A5EC6F58A5A2E8653650E89E765E7AE26"
PROMPT_APPROVALS_CANONICAL = "7FC1C3579B7A13C43BBEFA902348E949729AA1CAFD38D3B6EF0665741D469EE5"
SOURCE_LOCK_CANONICAL = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
REQUIRED_COVERAGE = [f"W{index}" for index in range(8)]

FILES = (
    "artifacts/ptcgdap/as_wp6_prompt_conformance_binding/README.md",
    "artifacts/ptcgdap/as_wp6_prompt_conformance_binding/code_review.md",
    "artifacts/ptcgdap/as_wp6_prompt_conformance_binding/known_gaps.md",
    "artifacts/ptcgdap/as_wp6_prompt_conformance_binding/rollback_report.md",
    "artifacts/ptcgdap/as_wp6_prompt_conformance_binding/test_results.json",
    "artifacts/ptcgdap/as_wp6_prompt_conformance_binding/three_pass_reflection.md",
    "artifacts/ptcgdap/as_wp6_prompt_conformance_binding/evidence_summary.json",
    "contracts/ptcgdap/author_strategy_release.schema.json",
    "contracts/ptcgdap/author_strategy_release_profile.json",
    "contracts/ptcgdap/author_strategy_release_conformance_vectors.json",
    "contracts/ptcgdap/author_strategy_release_bundle.json",
    "data/ptcgdap/author_strategy_release_approvals.json",
    "data/ptcgdap/author_strategy_device_canary_approvals.json",
    "data/ptcgdap/author_strategy_prompt_conformance_approvals.json",
    "scripts/ai/ptcgdap/author_strategy_release.py",
    "scripts/ai/ptcgdap/packages/AuthorStrategyReleaseGate.gd",
    "tools/ptcgdap/build_author_strategy_release_contract.py",
    "tools/ptcgdap/build_as_wp6_prompt_conformance_binding_evidence.py",
    "tests/ptcgdap/test_author_strategy_release_contract_builder.py",
    "tests/ptcgdap/test_author_strategy_release.py",
    "tests/ptcgdap/dragapult_acceptance_rollback.py",
    "tests/ptcgdap/godot/test_author_strategy_release_gate.gd",
    "docs/ptcgdap/07-decisions-risks-and-open-questions.md",
    "docs/ptcgdap/09-author-strategy-package-engineering-handoff.md",
    "docs/ptcgdap/STATUS.md",
    "docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md",
)


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _canonical_sha(value: object) -> str:
    return _sha(canonical_json_v1_bytes(value))


def _validate_contract() -> None:
    generated = build_artifacts()
    for relative, expected in generated.items():
        if load_json_strict(ROOT / relative) != expected:
            raise ValueError(f"release contract drift: {relative}")
    bundle = load_json_strict(RELEASE_BUNDLE)
    profile = load_json_strict(RELEASE_PROFILE)
    approvals = load_json_strict(PROMPT_APPROVALS)
    if _canonical_sha(bundle) != CURRENT_RELEASE_BUNDLE_CANONICAL:
        raise ValueError("D069 successor release bundle identity drift")
    if _canonical_sha(approvals) != PROMPT_APPROVALS_CANONICAL:
        raise ValueError("D069 prompt approval store identity drift")
    prompt_profile = profile.get("prompt_conformance_approvals")
    prerequisites = profile.get("release_prerequisites")
    if (
        type(prompt_profile) is not dict
        or type(prerequisites) is not dict
        or prompt_profile.get("path")
        != "data/ptcgdap/author_strategy_prompt_conformance_approvals.json"
        or prompt_profile.get("caller_overrides") is not False
        or prompt_profile.get("exact_package_identity_required") is not True
        or prompt_profile.get("official_source_lock_sha256") != SOURCE_LOCK_CANONICAL
        or prompt_profile.get("required_evidence_class")
        != "official_cabt_w0_w7_package_conformance"
        or prerequisites.get("prompt_coverage") != REQUIRED_COVERAGE
        or prerequisites.get("prompt_conformance_report_hash_required") is not True
        or approvals != {
            "document_type": "author_strategy_prompt_conformance_approvals_v1",
            "schema_version": 1,
            "approval_status": "unprovisioned",
            "records": [],
        }
    ):
        raise ValueError("D069 prompt conformance authority drift")
    audit = AuthorStrategyReleaseGate(ROOT).audit_snapshot()
    if (
        audit.get("contract_ok") is not True
        or audit.get("prompt_conformance_approval_status") != "unprovisioned"
        or audit.get("approved_prompt_conformance_count") != 0
        or audit.get("production_trust_ready") is not True
        or audit.get("production_ready") is not False
        or audit.get("player_start_allowed") is not False
    ):
        raise ValueError("D069 runtime fail-closed state drift")


def build_summary() -> dict[str, object]:
    _validate_contract()
    tests = load_json_strict(TEST_RESULTS)
    if type(tests) is not dict or tests.get("decision_id") != DECISION_ID:
        raise ValueError("D069 test evidence missing")
    return {
        "document_type": "as_wp6_prompt_conformance_binding_evidence_summary_v1",
        "schema_version": 1,
        "decision_id": DECISION_ID,
        "work_package": "AS-WP6/P6-39",
        "status": "prompt_conformance_hash_binding_gate_complete_external_evidence_unprovisioned",
        "contract": {
            "release_bundle_at_decision_canonical_sha256": D069_RELEASE_BUNDLE_CANONICAL,
            "current_successor_release_bundle_canonical_sha256": CURRENT_RELEASE_BUNDLE_CANONICAL,
            "prompt_approval_store_canonical_sha256": PROMPT_APPROVALS_CANONICAL,
            "official_source_lock_canonical_sha256": SOURCE_LOCK_CANONICAL,
            "required_prompt_coverage": REQUIRED_COVERAGE,
            "required_evidence_class": "official_cabt_w0_w7_package_conformance",
            "package_identity_fields": [
                "package_id",
                "package_version",
                "archive_sha256",
                "manifest_sha256",
                "policy_ir_sha256",
                "deck_manifest_sha256",
            ],
        },
        "authority": {
            "caller_overrides_allowed": False,
            "bare_prompt_coverage_authorizes_canary": False,
            "bare_prompt_coverage_authorizes_release": False,
            "approved_prompt_conformance_count": 0,
            "production_ready": False,
            "player_start_allowed": False,
        },
        "sequencing": [
            "configure_product_key",
            "sign_exact_package",
            "generate_and_approve_pre_canary_official_w0_w7_package_conformance_report",
            "approve_and_run_device_canary",
            "approve_device_rollback_a5_and_release",
        ],
        "claims": {
            "p6_39_binding_gate_closed": True,
            "official_w0_w7_conformance_approved": False,
            "production_signing_complete": False,
            "device_canary_complete": False,
            "a5_complete": False,
            "csp_wp3_unlocked": False,
            "core_engine_changed": False,
            "ui_changed": False,
        },
        "tests": tests.get("green", {}),
    }


def _entry(relative: str) -> dict[str, object]:
    path = ROOT / relative
    raw = path.read_bytes()
    row: dict[str, object] = {
        "path": relative,
        "bytes": len(raw),
        "raw_sha256": _sha(raw),
    }
    if path.suffix.lower() == ".json":
        row["canonical_sha256"] = _canonical_sha(load_json_strict(path))
    return row


def build_manifest() -> dict[str, object]:
    return {
        "document_type": "as_wp6_prompt_conformance_binding_evidence_manifest_v1",
        "schema_version": 1,
        "decision_id": DECISION_ID,
        "files": [_entry(relative) for relative in FILES],
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
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        SUMMARY.write_bytes(expected_summary)
        MANIFEST.write_bytes(_render(build_manifest()))
        print("D069 evidence written")
    else:
        if not SUMMARY.is_file() or SUMMARY.read_bytes() != expected_summary:
            raise SystemExit("D069 evidence summary drift")
        expected_manifest = _render(build_manifest())
        if not MANIFEST.is_file() or MANIFEST.read_bytes() != expected_manifest:
            raise SystemExit("D069 evidence manifest drift")
        print("D069 evidence verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
