from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes


CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
CONTRACT_ID = "ptcgdap-shadow-match-owner-gate-p3-wp6-v1"
PARENT_PROMPT_BROKER_BUNDLE = "D19EC7B9B77370312C82E0572DFB016B75E3FE9F438B6C1EFFD50E0AB43C551E"
MODES = ["legacy", "aligned_shadow"]
STATES = ["idle", "active", "between_matches"]
ERROR_CODES = [
    "invalid_gate", "invalid_mode", "invalid_match_generation", "active_match_exists",
    "no_active_match", "stale_match_generation", "broker_required", "broker_forbidden",
    "broker_invalid", "broker_match_generation_mismatch", "rollback_already_pending",
    "generation_exhausted",
]


def canonical_hash(value: Any) -> str:
    return hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper()


def schema() -> dict[str, Any]:
    audit = {
        "type": "object",
        "additionalProperties": False,
        "required": [
            "profile", "gate_generation", "state", "match_generation", "active_mode",
            "rollback_pending", "next_forced_mode", "rollback_applied", "authority", "authoritative",
        ],
        "properties": {
            "profile": {"const": CONTRACT_ID},
            "gate_generation": {"$ref": "#/$defs/nonNegativeSafeInteger"},
            "state": {"enum": STATES},
            "match_generation": {"oneOf": [{"$ref": "#/$defs/positiveSafeInteger"}, {"type": "null"}]},
            "active_mode": {"oneOf": [{"enum": MODES}, {"type": "null"}]},
            "rollback_pending": {"type": "boolean"},
            "next_forced_mode": {"oneOf": [{"const": "legacy"}, {"type": "null"}]},
            "rollback_applied": {"type": "boolean"},
            "authority": {"const": "shadow_match_owner_gate_audit"},
            "authoritative": {"const": False},
        },
        "allOf": [
            {
                "if": {"properties": {"state": {"const": "active"}}},
                "then": {
                    "properties": {
                        "match_generation": {"$ref": "#/$defs/positiveSafeInteger"},
                        "active_mode": {"enum": MODES},
                    }
                },
            },
            {
                "if": {"properties": {"state": {"const": "idle"}}},
                "then": {
                    "properties": {
                        "gate_generation": {"const": 0},
                        "match_generation": {"type": "null"},
                        "active_mode": {"type": "null"},
                        "rollback_pending": {"const": False},
                        "rollback_applied": {"const": False},
                    }
                },
            },
            {
                "if": {"properties": {"state": {"const": "between_matches"}}},
                "then": {
                    "properties": {
                        "match_generation": {"$ref": "#/$defs/positiveSafeInteger"},
                        "active_mode": {"type": "null"},
                        "rollback_applied": {"const": False},
                    }
                },
            },
            {
                "if": {"properties": {"rollback_pending": {"const": True}}},
                "then": {"properties": {"next_forced_mode": {"const": "legacy"}}},
                "else": {"properties": {"next_forced_mode": {"type": "null"}}},
            },
            {
                "if": {"properties": {"rollback_applied": {"const": True}}},
                "then": {
                    "properties": {
                        "state": {"const": "active"},
                        "active_mode": {"const": "legacy"},
                        "rollback_pending": {"const": False},
                    }
                },
            },
        ],
    }
    result = {
        "type": "object",
        "additionalProperties": False,
        "required": ["accepted", "error_code", "audit"],
        "properties": {
            "accepted": {"type": "boolean"},
            "error_code": {"enum": ["", *ERROR_CODES]},
            "audit": {"oneOf": [{"$ref": "#/$defs/gateAudit"}, {"type": "null"}]},
        },
        "allOf": [
            {
                "if": {"properties": {"accepted": {"const": True}}},
                "then": {"properties": {"error_code": {"const": ""}, "audit": {"$ref": "#/$defs/gateAudit"}}},
            },
            {
                "if": {"properties": {"accepted": {"const": False}}},
                "then": {"properties": {"error_code": {"enum": ERROR_CODES}}},
            },
        ],
    }
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/shadow_match_owner_gate.schema.json",
        "title": "PtcgDAP whole-match shadow owner gate audit DTOs",
        "oneOf": [{"$ref": "#/$defs/gateAudit"}, {"$ref": "#/$defs/gateResult"}],
        "$defs": {
            "positiveSafeInteger": {"type": "integer", "minimum": 1, "maximum": 9007199254740991},
            "nonNegativeSafeInteger": {"type": "integer", "minimum": 0, "maximum": 9007199254740991},
            "gateAudit": audit,
            "gateResult": result,
        },
    }


def profile() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "profile_id": CONTRACT_ID,
        "parent_prompt_broker_bundle_canonical_sha256": PARENT_PROMPT_BROKER_BUNDLE,
        "owner_modes": MODES,
        "states": STATES,
        "error_codes": ERROR_CODES,
        "limits": {"max_match_generation": 9007199254740991, "max_gate_generation": 9007199254740991},
        "semantics": {
            "owner_mode_immutable_during_active_match": True,
            "rollback_applies_to_next_strictly_newer_match_only": True,
            "pending_rollback_forces_legacy": True,
            "aligned_shadow_requires_same_generation_broker": True,
            "legacy_forbids_broker": True,
            "rollback_request_is_idempotent": False,
            "engine_method_invocation": False,
            "serialized_audit_is_authority": False,
            "live_owner_switch": False,
        },
        "lifecycle": {
            "begin_match": "select exactly one owner mode for a strictly newer match generation",
            "active_match": "mode remains immutable; rollback request cannot change current owner",
            "end_match": "release active broker reference and retain any next-match rollback request",
            "next_match": "a pending rollback forces legacy and is consumed exactly once",
        },
        "private_fields_forbidden_from_audit": [
            "broker", "session_id", "current_prompt", "private_engine_state", "private_object_refs",
        ],
    }


def vectors() -> dict[str, Any]:
    cases = [
        {"case_id":"begin-legacy","scenario":"begin_legacy","expected_accepted":True,"expected_error":"","expected_state":"active","expected_mode":"legacy","expected_rollback_pending":False},
        {"case_id":"begin-aligned","scenario":"begin_aligned","expected_accepted":True,"expected_error":"","expected_state":"active","expected_mode":"aligned_shadow","expected_rollback_pending":False},
        {"case_id":"active-owner-switch-rejected","scenario":"active_owner_switch","expected_accepted":False,"expected_error":"active_match_exists","expected_state":"active","expected_mode":"legacy","expected_rollback_pending":False},
        {"case_id":"request-next-legacy","scenario":"request_next_legacy","expected_accepted":True,"expected_error":"","expected_state":"active","expected_mode":"aligned_shadow","expected_rollback_pending":True},
        {"case_id":"current-owner-unchanged-after-request","scenario":"current_owner_after_request","expected_accepted":True,"expected_error":"","expected_state":"active","expected_mode":"aligned_shadow","expected_rollback_pending":True},
        {"case_id":"end-with-pending-rollback","scenario":"end_with_pending","expected_accepted":True,"expected_error":"","expected_state":"between_matches","expected_mode":None,"expected_rollback_pending":True},
        {"case_id":"next-aligned-request-forced-legacy","scenario":"next_forced_legacy","expected_accepted":True,"expected_error":"","expected_state":"active","expected_mode":"legacy","expected_rollback_pending":False,"expected_rollback_applied":True},
        {"case_id":"pending-rollback-cannot-be-overwritten","scenario":"duplicate_rollback_request","expected_accepted":False,"expected_error":"rollback_already_pending","expected_state":"active","expected_mode":"aligned_shadow","expected_rollback_pending":True},
        {"case_id":"stale-generation","scenario":"stale_generation","expected_accepted":False,"expected_error":"stale_match_generation","expected_state":"between_matches","expected_mode":None,"expected_rollback_pending":False},
        {"case_id":"aligned-without-broker","scenario":"aligned_without_broker","expected_accepted":False,"expected_error":"broker_required","expected_state":"idle","expected_mode":None,"expected_rollback_pending":False},
        {"case_id":"aligned-cross-generation-broker","scenario":"aligned_cross_generation_broker","expected_accepted":False,"expected_error":"broker_match_generation_mismatch","expected_state":"idle","expected_mode":None,"expected_rollback_pending":False},
        {"case_id":"legacy-with-broker","scenario":"legacy_with_broker","expected_accepted":False,"expected_error":"broker_forbidden","expected_state":"idle","expected_mode":None,"expected_rollback_pending":False},
        {"case_id":"strictly-newer-match","scenario":"strictly_newer_match","expected_accepted":True,"expected_error":"","expected_state":"active","expected_mode":"legacy","expected_rollback_pending":False},
        {"case_id":"audit-copy-nonauthority","scenario":"audit_copy_nonauthority","expected_accepted":False,"expected_error":"invalid_gate","expected_state":"active","expected_mode":"legacy","expected_rollback_pending":False},
    ]
    return {
        "schema_version": 1,
        "profile_id": CONTRACT_ID,
        "cases": cases,
        "private_sentinels": ["PRIVATE_SESSION_SENTINEL", "PRIVATE_BROKER_SENTINEL", "PRIVATE_PROMPT_SENTINEL"],
    }


def documents() -> dict[Path, dict[str, Any]]:
    docs = {
        CONTRACT_ROOT / "shadow_match_owner_gate.schema.json": schema(),
        CONTRACT_ROOT / "shadow_match_owner_gate_profile.json": profile(),
        CONTRACT_ROOT / "shadow_match_owner_gate_conformance_vectors.json": vectors(),
    }
    bundle = {
        "schema_version": 1,
        "contract_id": CONTRACT_ID,
        "parent_prompt_broker_bundle_canonical_sha256": PARENT_PROMPT_BROKER_BUNDLE,
        "artifacts": [
            {"id": artifact_id, "path": path.relative_to(ROOT).as_posix(), "canonical_sha256": canonical_hash(docs[path])}
            for artifact_id, path in (
                ("schema", CONTRACT_ROOT / "shadow_match_owner_gate.schema.json"),
                ("profile", CONTRACT_ROOT / "shadow_match_owner_gate_profile.json"),
                ("vectors", CONTRACT_ROOT / "shadow_match_owner_gate_conformance_vectors.json"),
            )
        ],
    }
    docs[CONTRACT_ROOT / "shadow_match_owner_gate_bundle.json"] = bundle
    return docs


def rendered(value: dict[str, Any]) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    failed = False
    for path, value in documents().items():
        expected = rendered(value)
        if args.check:
            if not path.exists() or path.read_bytes() != expected:
                print(f"drift: {path.relative_to(ROOT)}")
                failed = True
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(expected)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
