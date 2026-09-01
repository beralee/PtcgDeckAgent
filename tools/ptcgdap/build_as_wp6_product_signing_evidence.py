from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.author_strategy_package import AuthorStrategyPackageLoader  # noqa: E402
from scripts.ai.ptcgdap.author_strategy_release import AuthorStrategyReleaseGate  # noqa: E402
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict  # noqa: E402
from tools.ptcgdap.build_author_strategy_release_contract import (  # noqa: E402
    PRODUCT_RELEASE_KEY_ID,
    PRODUCT_RELEASE_PUBLIC_KEY_BASE64,
    build_artifacts,
)


EVIDENCE = ROOT / "artifacts/ptcgdap/as_wp6_product_signing"
SUMMARY = EVIDENCE / "evidence_summary.json"
MANIFEST = EVIDENCE / "manifest.json"
TEST_RESULTS = EVIDENCE / "test_results.json"
PRODUCT_PACKAGE = EVIDENCE / "ptcgdap-marnie-windows-local-0.1.0.ptcgai"
SIGNING_RECEIPT = EVIDENCE / "signing_receipt.json"

DECISION_ID = "D070"
RELEASE_BUNDLE_CANONICAL = "527D725B50946874D62C95B957DB401A5EC6F58A5A2E8653650E89E765E7AE26"
TRUST_STORE_CANONICAL = "C3260FA0FAFE9A393760C5557C631672DF8DB4A7C53E8190F60084034E7E8FDE"
TRUST_STORE_RAW = "EDEE3A35E537B2048CBBCC97719AACF222A0BC1BA9A1AA178C99E9EEFAA51ED3"
PUBLIC_KEY_SHA256 = "40D386D9FE5C35F9F31D45C2047A6BE5FCB956EE085BEE58542445405AB33C43"
PRODUCT_ARCHIVE_SHA256 = "AA65C8B46D2CEB0658EC18BB966F4DFECDB932750EDA3E65CD0B60208A08A0FD"
SIGNING_RECEIPT_SHA256 = "A842C2ECC35BEE6B07B382DACAFFDCDC1F002B7C12994EB58BBCFD2230865AEF"

FILES = (
    "artifacts/ptcgdap/as_wp6_product_signing/README.md",
    "artifacts/ptcgdap/as_wp6_product_signing/code_review.md",
    "artifacts/ptcgdap/as_wp6_product_signing/known_gaps.md",
    "artifacts/ptcgdap/as_wp6_product_signing/rollback_report.md",
    "artifacts/ptcgdap/as_wp6_product_signing/three_pass_reflection.md",
    "artifacts/ptcgdap/as_wp6_product_signing/test_results.json",
    "artifacts/ptcgdap/as_wp6_product_signing/evidence_summary.json",
    "artifacts/ptcgdap/as_wp6_product_signing/ptcgdap-marnie-windows-local-0.1.0.ptcgai",
    "artifacts/ptcgdap/as_wp6_product_signing/signing_receipt.json",
    "artifacts/ptcgdap/as_wp6_windows_profile_approval/README.md",
    "artifacts/ptcgdap/as_wp6_windows_profile_approval/known_gaps.md",
    "artifacts/ptcgdap/as_wp6_windows_profile_approval/evidence_summary.json",
    "artifacts/ptcgdap/as_wp6_windows_profile_approval/manifest.json",
    "artifacts/ptcgdap/as_wp6_prompt_conformance_binding/three_pass_reflection.md",
    "artifacts/ptcgdap/as_wp6_prompt_conformance_binding/evidence_summary.json",
    "artifacts/ptcgdap/as_wp6_prompt_conformance_binding/manifest.json",
    "contracts/ptcgdap/author_strategy_release_profile.json",
    "contracts/ptcgdap/author_strategy_release_conformance_vectors.json",
    "contracts/ptcgdap/author_strategy_release_bundle.json",
    "data/ptcgdap/author_strategy_release_trust_store.json",
    "data/ptcgdap/author_strategy_release_approvals.json",
    "data/ptcgdap/author_strategy_device_canary_approvals.json",
    "data/ptcgdap/author_strategy_prompt_conformance_approvals.json",
    "scripts/ai/ptcgdap/author_strategy_release.py",
    "scripts/ai/ptcgdap/packages/AuthorStrategyReleaseGate.gd",
    "tools/ptcgdap/build_author_strategy_release_candidate.py",
    "tools/ptcgdap/build_author_strategy_release_contract.py",
    "tools/ptcgdap/sign_author_strategy_release_package.py",
    "tools/ptcgdap/sign_author_strategy_product_release_candidate.py",
    "tools/ptcgdap/build_as_wp6_product_signing_evidence.py",
    "tools/ptcgdap/build_as_wp6_windows_profile_approval_evidence.py",
    "tools/ptcgdap/build_as_wp6_prompt_conformance_binding_evidence.py",
    "tests/ptcgdap/test_author_strategy_release_contract_builder.py",
    "tests/ptcgdap/test_author_strategy_release.py",
    "tests/ptcgdap/test_author_strategy_release_signing.py",
    "tests/ptcgdap/test_author_strategy_product_release_signing.py",
    "tests/ptcgdap/test_as_wp6_product_signing_evidence.py",
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


def _validate_current_state() -> tuple[dict[str, object], dict[str, object]]:
    generated = build_artifacts()
    for relative, expected in generated.items():
        if load_json_strict(ROOT / relative) != expected:
            raise ValueError(f"D070 release contract drift: {relative}")
    bundle = load_json_strict(ROOT / "contracts/ptcgdap/author_strategy_release_bundle.json")
    trust_path = ROOT / "data/ptcgdap/author_strategy_release_trust_store.json"
    trust = load_json_strict(trust_path)
    expected_trust = {
        "document_type": "author_strategy_release_trust_store_v1",
        "schema_version": 1,
        "store_id": "ptcgdap-product-release-trust-v1",
        "approval_status": "approved",
        "keys": [{
            "key_id": PRODUCT_RELEASE_KEY_ID,
            "algorithm": "ed25519",
            "public_key_base64": PRODUCT_RELEASE_PUBLIC_KEY_BASE64,
            "scope": "production_release",
            "execution_trusted": True,
            "status": "active",
        }],
    }
    if _canonical_sha(bundle) != RELEASE_BUNDLE_CANONICAL:
        raise ValueError("D070 release bundle identity drift")
    if trust != expected_trust or _canonical_sha(trust) != TRUST_STORE_CANONICAL:
        raise ValueError("D070 product trust identity drift")
    if _sha(trust_path.read_bytes()) != TRUST_STORE_RAW:
        raise ValueError("D070 product trust raw identity drift")

    receipt = load_json_strict(SIGNING_RECEIPT)
    if _sha(SIGNING_RECEIPT.read_bytes()) != SIGNING_RECEIPT_SHA256:
        raise ValueError("D070 signing receipt identity drift")
    if any("private" in str(key).casefold() for key in receipt):
        raise ValueError("D070 signing receipt exposes private-key metadata")
    handle = AuthorStrategyPackageLoader().load_path(
        PRODUCT_PACKAGE,
        expected_archive_sha256=PRODUCT_ARCHIVE_SHA256,
    )
    metadata = handle.to_dict()
    if (
        receipt.get("archive_sha256") != PRODUCT_ARCHIVE_SHA256
        or receipt.get("archive_bytes") != PRODUCT_PACKAGE.stat().st_size
        or receipt.get("signature_key_id") != PRODUCT_RELEASE_KEY_ID
        or receipt.get("signature_algorithm") != "ed25519"
        or receipt.get("signature_scope") != "production_release"
        or receipt.get("execution_trusted") is not True
        or receipt.get("signing_public_key_sha256") != PUBLIC_KEY_SHA256
        or receipt.get("trust_store_canonical_sha256") != TRUST_STORE_CANONICAL
        or receipt.get("trust_store_raw_sha256") != TRUST_STORE_RAW
        or receipt.get("manifest_sha256") != handle.manifest_sha256
        or receipt.get("policy_ir_sha256") != handle.policy_ir_sha256
        or receipt.get("deck_manifest_sha256") != handle.deck_manifest_sha256
        or handle.signature_status != "production_trusted"
        or handle.signature_key_id != PRODUCT_RELEASE_KEY_ID
        or handle.signature_scope != "production_release"
        or handle.execution_trusted is not True
    ):
        raise ValueError("D070 product package identity drift")

    gate = AuthorStrategyReleaseGate(ROOT)
    audit = gate.audit_snapshot()
    decision = gate.evaluate_package(metadata)
    if (
        audit.get("contract_ok") is not True
        or audit.get("production_trust_status") != "approved"
        or audit.get("active_production_key_count") != 1
        or audit.get("production_trust_ready") is not True
        or audit.get("production_ready") is not False
        or audit.get("production_trust_error_code") != ""
        or audit.get("error_code") != "release_prompt_conformance_unapproved"
        or audit.get("release_approval_status") != "unprovisioned"
        or audit.get("device_canary_approval_status") != "unprovisioned"
        or audit.get("prompt_conformance_approval_status") != "unprovisioned"
        or audit.get("player_start_allowed") is not False
        or decision.get("accepted") is not False
        or decision.get("error_code") != "release_package_not_approved"
        or decision.get("player_start_allowed") is not False
    ):
        raise ValueError("D070 release authority boundary drift")
    return receipt, audit


def build_summary() -> dict[str, object]:
    receipt, audit = _validate_current_state()
    tests = load_json_strict(TEST_RESULTS)
    if type(tests) is not dict or tests.get("decision_id") != DECISION_ID:
        raise ValueError("D070 test evidence missing")
    return {
        "document_type": "as_wp6_product_signing_evidence_summary_v1",
        "schema_version": 1,
        "decision_id": DECISION_ID,
        "work_package": "AS-WP6/P6-06",
        "status": "product_trust_and_exact_package_signing_complete_approval_pending",
        "contract": {
            "release_bundle_canonical_sha256": RELEASE_BUNDLE_CANONICAL,
            "trust_store_raw_sha256": TRUST_STORE_RAW,
            "trust_store_canonical_sha256": TRUST_STORE_CANONICAL,
            "key_id": PRODUCT_RELEASE_KEY_ID,
            "algorithm": "ed25519",
            "public_key_sha256": PUBLIC_KEY_SHA256,
            "private_key_repository_path": None,
        },
        "package": {
            "package_id": receipt["package_id"],
            "package_version": receipt["package_version"],
            "archive_bytes": receipt["archive_bytes"],
            "archive_sha256": receipt["archive_sha256"],
            "manifest_sha256": receipt["manifest_sha256"],
            "policy_ir_sha256": receipt["policy_ir_sha256"],
            "deck_manifest_sha256": receipt["deck_manifest_sha256"],
            "signed_payload_sha256": receipt["signed_payload_sha256"],
            "signing_receipt_raw_sha256": SIGNING_RECEIPT_SHA256,
            "signature_scope": receipt["signature_scope"],
            "execution_trusted": receipt["execution_trusted"],
            "deterministic_real_key_resign_byte_identical": True,
        },
        "authority": {
            "production_trust_status": audit["production_trust_status"],
            "active_production_key_count": audit["active_production_key_count"],
            "production_trust_ready": audit["production_trust_ready"],
            "production_ready": audit["production_ready"],
            "production_trust_error_code": audit["production_trust_error_code"],
            "production_ready_error_code": audit["error_code"],
            "release_approval_status": audit["release_approval_status"],
            "device_canary_approval_status": audit["device_canary_approval_status"],
            "prompt_conformance_approval_status": audit["prompt_conformance_approval_status"],
            "exact_package_gate_error": "release_package_not_approved",
            "player_start_allowed": False,
        },
        "claims": {
            "p6_06_product_trust_approved": True,
            "exact_product_package_signed": True,
            "private_key_in_repository": False,
            "test_fixture_promoted": False,
            "package_release_approved": False,
            "official_w0_w7_conformance_approved": False,
            "device_canary_complete": False,
            "a5_complete": False,
            "csp_wp3_unlocked": False,
            "core_engine_changed": False,
            "ui_changed": False,
        },
        "next_permitted_work": (
            "generate and approve the exact-package pre-canary official W0-W7 "
            "conformance report; package/canary/A5/release approval remain closed"
        ),
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
        "document_type": "as_wp6_product_signing_evidence_manifest_v1",
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
        print("D070 evidence written")
    else:
        if not SUMMARY.is_file() or SUMMARY.read_bytes() != expected_summary:
            raise SystemExit("D070 evidence summary drift")
        expected_manifest = _render(build_manifest())
        if not MANIFEST.is_file() or MANIFEST.read_bytes() != expected_manifest:
            raise SystemExit("D070 evidence manifest drift")
        print("D070 evidence verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
