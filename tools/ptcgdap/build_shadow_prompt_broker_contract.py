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
CONTRACT_ID = "ptcgdap-shadow-prompt-broker-p3-wp5-v1"
PARENT_EXECUTOR_BUNDLE = "45952BE629AE98EB6070C77188FD6A2C2A644C4B6A36876193BB745B7CDA4E92"
FAMILIES = ["W1", "W2", "W3", "W4", "W5", "W6", "W7"]
STATES = ["open", "prepared", "awaiting_reobserve", "aborted", "superseded"]
ERROR_CODES = [
    "invalid_broker", "invalid_family", "invalid_context", "active_prompt_exists",
    "prompt_not_current", "prompt_integrity_invalid", "selection_invalid",
    "ticket_issue_failed", "ticket_claim_failed", "preflight_failed", "commit_failed",
    "reobserve_required", "stale_decision_generation", "same_window_reused",
    "cross_owner", "match_generation_mismatch", "broker_aborted", "generation_exhausted",
]


def canonical_hash(value: Any) -> str:
    return hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper()


def schema() -> dict[str, Any]:
    audit = {
        "type": "object",
        "additionalProperties": False,
        "required": [
            "profile", "prompt_family", "broker_generation", "match_generation",
            "decision_generation", "snapshot_id", "window_id", "public_observation_hash",
            "chooser_player_index", "state", "witness", "resolution_count", "authority", "authoritative",
        ],
        "properties": {
            "profile": {"const": CONTRACT_ID},
            "prompt_family": {"enum": FAMILIES},
            "broker_generation": {"$ref": "#/$defs/positiveSafeInteger"},
            "match_generation": {"$ref": "#/$defs/positiveSafeInteger"},
            "decision_generation": {"$ref": "#/$defs/positiveSafeInteger"},
            "snapshot_id": {"$ref": "#/$defs/sha256"},
            "window_id": {"$ref": "#/$defs/sha256"},
            "public_observation_hash": {"$ref": "#/$defs/sha256"},
            "chooser_player_index": {"type": "integer", "minimum": 0, "maximum": 1},
            "state": {"enum": STATES},
            "witness": {
                "type": "object", "additionalProperties": False,
                "required": ["accepted", "bound", "committed"],
                "properties": {"accepted": {"type": "boolean"}, "bound": {"type": "boolean"}, "committed": {"type": "boolean"}},
            },
            "resolution_count": {"type": "integer", "minimum": 0, "maximum": 256},
            "authority": {"const": "shadow_prompt_broker_audit"},
            "authoritative": {"const": False},
        },
    }
    result = {
        "type": "object", "additionalProperties": False,
        "required": ["accepted", "error_code", "audit"],
        "properties": {
            "accepted": {"type": "boolean"},
            "error_code": {"enum": ["", *ERROR_CODES]},
            "audit": {"oneOf": [{"$ref": "#/$defs/promptAudit"}, {"type": "null"}]},
        },
        "allOf": [
            {"if": {"properties": {"accepted": {"const": True}}}, "then": {"properties": {"error_code": {"const": ""}, "audit": {"$ref": "#/$defs/promptAudit"}}}},
            {"if": {"properties": {"accepted": {"const": False}}}, "then": {"properties": {"error_code": {"enum": ERROR_CODES}}}},
        ],
    }
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/shadow_prompt_broker.schema.json",
        "title": "PtcgDAP shadow prompt broker audit DTOs",
        "oneOf": [{"$ref": "#/$defs/promptAudit"}, {"$ref": "#/$defs/brokerResult"}],
        "$defs": {
            "sha256": {"type": "string", "pattern": "^[A-F0-9]{64}$"},
            "positiveSafeInteger": {"type": "integer", "minimum": 1, "maximum": 9007199254740991},
            "promptAudit": audit,
            "brokerResult": result,
        },
    }


def profile() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "profile_id": CONTRACT_ID,
        "parent_executor_bundle_canonical_sha256": PARENT_EXECUTOR_BUNDLE,
        "prompt_families": FAMILIES,
        "states": STATES,
        "error_codes": ERROR_CODES,
        "limits": {"max_broker_generation": 9007199254740991, "max_resolution_count": 256},
        "lifecycle": {
            "open": "bind exact current port snapshot, binding owner/set and immutable selection window",
            "prepare": "accept an exact owner-produced selection, then issue/claim one ticket and create one executor preflight",
            "commit": "revalidate the prepared prompt and atomically return all exact private resolutions or none",
            "after_success": "awaiting_reobserve; old prompt and indexes have no next-prompt authority",
            "next_prompt": "requires strictly newer decision generation and distinct snapshot, window and binding",
            "failure": "abort current prompt with zero private resolutions and no engine mutation",
        },
        "authority_contract": {
            "owner_produced_selection_required": True,
            "same_window_witness_chain_required": True,
            "strictly_newer_prompt_required_after_commit": True,
            "successful_commit_count_maximum": 1,
            "engine_method_invocation": False,
            "serialized_audit_is_authority": False,
            "family_label_relaxes_legality": False,
        },
        "private_fields_forbidden_from_audit": [
            "session_id", "callback_binding_hash", "current_source", "private_engine_command",
            "private_object_refs", "private_resolutions", "ticket", "preflight",
        ],
    }


def vectors() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "profile_id": CONTRACT_ID,
        "family_cases": [
            {"case_id": f"family-{family.lower()}", "family": family, "expected_accepted": True, "expected_state": "open"}
            for family in FAMILIES
        ],
        "lifecycle_cases": [
            {"case_id":"open-first","scenario":"open_first","expected_accepted":True,"expected_error":"","expected_state":"open","expected_resolution_count":0},
            {"case_id":"prepare-success","scenario":"prepare_success","expected_accepted":True,"expected_error":"","expected_state":"prepared","expected_resolution_count":0},
            {"case_id":"resolve-success","scenario":"resolve_success","expected_accepted":True,"expected_error":"","expected_state":"awaiting_reobserve","expected_resolution_count":1},
            {"case_id":"ordered-multi-success","scenario":"ordered_multi_success","expected_accepted":True,"expected_error":"","expected_state":"awaiting_reobserve","expected_resolution_count":2},
            {"case_id":"resolve-replay","scenario":"resolve_replay","expected_accepted":False,"expected_error":"reobserve_required","expected_state":"awaiting_reobserve","expected_resolution_count":0},
            {"case_id":"open-while-active","scenario":"open_while_active","expected_accepted":False,"expected_error":"active_prompt_exists","expected_state":"open","expected_resolution_count":0},
            {"case_id":"stale-next-snapshot","scenario":"stale_next_snapshot","expected_accepted":False,"expected_error":"stale_decision_generation","expected_state":"awaiting_reobserve","expected_resolution_count":0},
            {"case_id":"same-window-reused","scenario":"same_window_reused","expected_accepted":False,"expected_error":"same_window_reused","expected_state":"awaiting_reobserve","expected_resolution_count":0},
            {"case_id":"new-prompt-after-reobserve","scenario":"new_prompt_after_reobserve","expected_accepted":True,"expected_error":"","expected_state":"open","expected_resolution_count":0},
            {"case_id":"selection-wrong-window","scenario":"selection_wrong_window","expected_accepted":False,"expected_error":"selection_invalid","expected_state":"aborted","expected_resolution_count":0},
            {"case_id":"ticket-issue-failure","scenario":"ticket_issue_failure","expected_accepted":False,"expected_error":"ticket_issue_failed","expected_state":"aborted","expected_resolution_count":0},
            {"case_id":"commit-failure","scenario":"commit_failure","expected_accepted":False,"expected_error":"commit_failed","expected_state":"aborted","expected_resolution_count":0},
            {"case_id":"cross-broker-prompt","scenario":"cross_broker_prompt","expected_accepted":False,"expected_error":"cross_owner","expected_state":"open","expected_resolution_count":0},
            {"case_id":"reset-invalidates-old","scenario":"reset_invalidates_old","expected_accepted":False,"expected_error":"match_generation_mismatch","expected_state":"superseded","expected_resolution_count":0}
        ],
        "private_sentinels": ["PRIVATE_SESSION_SENTINEL", "PRIVATE_CALLBACK_SENTINEL", "PRIVATE_COMMAND_SENTINEL", "PRIVATE_SOURCE_SENTINEL"],
    }


def documents() -> dict[Path, dict[str, Any]]:
    docs = {
        CONTRACT_ROOT / "shadow_prompt_broker.schema.json": schema(),
        CONTRACT_ROOT / "shadow_prompt_broker_profile.json": profile(),
        CONTRACT_ROOT / "shadow_prompt_broker_conformance_vectors.json": vectors(),
    }
    bundle = {
        "schema_version": 1,
        "contract_id": CONTRACT_ID,
        "parent_executor_bundle_canonical_sha256": PARENT_EXECUTOR_BUNDLE,
        "artifacts": [
            {"id": artifact_id, "path": path.relative_to(ROOT).as_posix(), "canonical_sha256": canonical_hash(docs[path])}
            for artifact_id, path in (
                ("schema", CONTRACT_ROOT / "shadow_prompt_broker.schema.json"),
                ("profile", CONTRACT_ROOT / "shadow_prompt_broker_profile.json"),
                ("vectors", CONTRACT_ROOT / "shadow_prompt_broker_conformance_vectors.json"),
            )
        ],
    }
    docs[CONTRACT_ROOT / "shadow_prompt_broker_bundle.json"] = bundle
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
