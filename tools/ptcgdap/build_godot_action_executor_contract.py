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

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"
PROFILE_ID = "ptcgdap-godot-action-executor-p3-wp4-v1"
PARENT_MANIFEST = ROOT / "artifacts" / "ptcgdap" / "p3_wp3" / "manifest.json"
PARENT_RAW = "9564EE72D2BD400D010123E8563F50CCF0233BDC6436A3C35FDCDD9F78710556"
PARENT_CANONICAL = "5ACC39769D3A63EA7B27CAA61B107FCCF284DC52FCFB93F9B77B1547883FAF2B"
TICKET_BUNDLE = "41F3E84C6DC5C9BC6C162B848B097211E617B5558ECB59554757E82CE58817ED"
SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
PREFIX_HEX = "5054434744415000474F444F545F414354494F4E5F4558454355544F525F563100"
SAFE_MAX = 9_007_199_254_740_991

PREFLIGHT_ERRORS = [
    "executor_integrity_invalid", "invalid_ticket_owner", "invalid_claim_result",
    "claim_not_accepted", "invalid_binding_owner", "binding_not_current",
    "snapshot_not_current", "window_not_current", "callback_mismatch",
    "selection_mismatch", "private_resolution_invalid", "private_reference_unavailable",
    "active_preflight_exists", "preflight_space_exhausted",
]
COMMIT_ERRORS = [
    "executor_integrity_invalid", "invalid_preflight", "owner_mismatch",
    "preflight_integrity_invalid", "preflight_not_current", "already_committed",
    "preflight_aborted", "commit_context_changed", "private_resolution_invalid",
    "private_reference_unavailable",
]


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def artifact_schema() -> dict[str, Any]:
    sha_pattern = "^[A-F0-9]{64}$"
    safe_integer = {"type": "integer", "minimum": 0, "maximum": SAFE_MAX}
    audit = {
        "type": "object", "additionalProperties": False,
        "required": [
            "executor_profile", "preflight_id", "preflight_generation", "ticket_id",
            "ticket_generation", "binding_version", "snapshot_id", "window_id",
            "public_observation_hash", "chooser_player_index", "selected_indexes",
            "selected_fingerprint_hashes", "resolution_count", "state", "authority",
            "authoritative",
        ],
        "properties": {
            "executor_profile": {"const": PROFILE_ID},
            "preflight_id": {"type": "string", "pattern": sha_pattern},
            "preflight_generation": {"type": "integer", "minimum": 1, "maximum": SAFE_MAX},
            "ticket_id": {"type": "string", "pattern": sha_pattern},
            "ticket_generation": {"type": "integer", "minimum": 1, "maximum": SAFE_MAX},
            "binding_version": {"type": "integer", "minimum": 1, "maximum": SAFE_MAX},
            "snapshot_id": {"type": "string", "minLength": 1},
            "window_id": {"type": "string", "minLength": 1},
            "public_observation_hash": {"type": "string", "pattern": sha_pattern},
            "chooser_player_index": {"type": "integer", "enum": [0, 1]},
            "selected_indexes": {"type": "array", "items": safe_integer, "uniqueItems": True},
            "selected_fingerprint_hashes": {"type": "array", "items": {"type": "string", "pattern": sha_pattern}},
            "resolution_count": safe_integer,
            "state": {"type": "string", "enum": ["prepared", "committed", "aborted"]},
            "authority": {"const": "godot_action_executor_shadow"},
            "authoritative": {"const": False},
        },
        "allOf": [
            {"properties": {"selected_fingerprint_hashes": {"minItems": 0}}},
            {"if": {"properties": {"state": {"const": "aborted"}}}, "then": {}},
        ],
    }
    result = lambda errors: {
        "type": "object", "additionalProperties": False,
        "required": ["accepted", "error_code", "audit"],
        "properties": {
            "accepted": {"type": "boolean"},
            "error_code": {"type": "string", "enum": ["", *errors]},
            "audit": {"anyOf": [{"type": "null"}, {"$ref": "#/$defs/executorAudit"}]},
        },
        "oneOf": [
            {"properties": {"accepted": {"const": True}, "error_code": {"const": ""}, "audit": {"$ref": "#/$defs/executorAudit"}}},
            {"properties": {"accepted": {"const": False}, "error_code": {"enum": errors}, "audit": {"type": "null"}}},
        ],
    }
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/godot_action_executor.schema.json",
        "title": "PtcgDAP GodotActionExecutor audit DTOs",
        "type": "object", "additionalProperties": False,
        "required": ["schema_version", "profile_id", "kind", "value"],
        "properties": {
            "schema_version": {"const": 1}, "profile_id": {"const": PROFILE_ID},
            "kind": {"enum": ["preflight_result", "commit_result"]},
            "value": {"type": "object"},
        },
        "allOf": [
            {
                "if": {"properties": {"kind": {"const": "preflight_result"}}, "required": ["kind"]},
                "then": {"properties": {"value": {"$ref": "#/$defs/preflightResult"}}},
            },
            {
                "if": {"properties": {"kind": {"const": "commit_result"}}, "required": ["kind"]},
                "then": {"properties": {"value": {"$ref": "#/$defs/commitResult"}}},
            },
        ],
        "$defs": {"executorAudit": audit, "preflightResult": result(PREFLIGHT_ERRORS), "commitResult": result(COMMIT_ERRORS)},
    }


def profile() -> dict[str, Any]:
    return {
        "schema_version": 1, "profile_id": PROFILE_ID,
        "parent": {
            "work_package": "P3-WP3", "manifest_raw_sha256": PARENT_RAW,
            "manifest_canonical_sha256": PARENT_CANONICAL,
            "action_ticket_bundle_canonical_sha256": TICKET_BUNDLE,
            "source_lock_canonical_sha256": SOURCE_LOCK,
        },
        "hash_profile": {"id": "godot_action_preflight_v1", "algorithm": "SHA-256", "canonicalization": "canonical_json_v1", "prefix_utf8_hex": PREFIX_HEX},
        "states": ["none", "prepared", "committed", "aborted"],
        "preflight_error_codes": PREFLIGHT_ERRORS,
        "commit_error_codes": COMMIT_ERRORS,
        "preflight_contract": {
            "requires_exact_owner_claim": True, "requires_claim_accepted": True,
            "requires_exact_current_context": True, "requires_ordered_resolution_identity": True,
            "one_active_preflight_per_executor": True,
        },
        "commit_contract": {
            "revalidates_complete_context": True, "all_or_nothing": True,
            "successful_commit_count_maximum": 1, "engine_method_invocation": False,
            "failure_returns_private_resolutions": False,
        },
        "serialization_contract": {
            "dto_only": True, "grants_execution_authority": False,
            "forbidden_fields": [
                "session_id", "callback_binding_hash", "current_source", "private_engine_command",
                "private_object_refs", "binding_resolutions", "command_refs", "private_refs",
            ],
        },
    }


def vectors() -> dict[str, Any]:
    preflight = [
        ("preflight-success", True, ""), ("preflight-invalid-owner", False, "invalid_ticket_owner"),
        ("preflight-invalid-claim", False, "invalid_claim_result"), ("preflight-rejected-claim", False, "claim_not_accepted"),
        ("preflight-invalid-binding-owner", False, "invalid_binding_owner"), ("preflight-binding-stale", False, "binding_not_current"),
        ("preflight-snapshot-stale", False, "snapshot_not_current"), ("preflight-window-stale", False, "window_not_current"),
        ("preflight-callback-drift", False, "callback_mismatch"), ("preflight-selection-reordered", False, "selection_mismatch"),
        ("preflight-resolution-mutated", False, "private_resolution_invalid"), ("preflight-reference-released", False, "private_reference_unavailable"),
        ("preflight-active-exists", False, "active_preflight_exists"),
    ]
    commit = [
        ("commit-success", True, ""), ("commit-invalid-preflight", False, "invalid_preflight"),
        ("commit-cross-owner", False, "owner_mismatch"), ("commit-mutated-preflight", False, "preflight_integrity_invalid"),
        ("commit-stale-batch", False, "preflight_not_current"), ("commit-replay", False, "already_committed"),
        ("commit-aborted", False, "preflight_aborted"), ("commit-context-drift", False, "commit_context_changed"),
        ("commit-resolution-mutated", False, "private_resolution_invalid"), ("commit-reference-released", False, "private_reference_unavailable"),
    ]
    transition = [
        {"id": "prepare-commit-replay", "steps": ["prepare_accept", "commit_accept", "commit_already_committed"]},
        {"id": "prepare-abort-commit", "steps": ["prepare_accept", "abort_accept", "commit_preflight_aborted"]},
        {"id": "failed-prepare-is-atomic", "steps": ["prepare_reject", "state_none"]},
        {"id": "failed-commit-aborts-without-output", "steps": ["prepare_accept", "commit_reject", "state_aborted"]},
        {"id": "ordered-multi-preserved", "steps": ["prepare_indexes_1_0", "commit_indexes_1_0"]},
    ]
    return {
        "schema_version": 1, "profile_id": PROFILE_ID,
        "fixture": {"selected_indexes": [1, 0], "chooser_player_index": 0, "resolution_count": 2},
        "preflight_cases": [{"id": i, "expected": {"accepted": a, "error_code": c}} for i, a, c in preflight],
        "commit_cases": [{"id": i, "expected": {"accepted": a, "error_code": c}} for i, a, c in commit],
        "transition_cases": transition,
    }


def documents() -> dict[str, dict[str, Any]]:
    schema, prof, vec = artifact_schema(), profile(), vectors()
    docs = {"schema": schema, "profile": prof, "vectors": vec}
    paths = {
        "schema": "contracts/ptcgdap/godot_action_executor.schema.json",
        "profile": "contracts/ptcgdap/godot_action_executor_profile.json",
        "vectors": "contracts/ptcgdap/godot_action_executor_conformance_vectors.json",
    }
    bundle = {
        "schema_version": 1, "contract_id": PROFILE_ID,
        "parent": {"work_package": "P3-WP3", "manifest_raw_sha256": PARENT_RAW, "manifest_canonical_sha256": PARENT_CANONICAL, "action_ticket_bundle_canonical_sha256": TICKET_BUNDLE, "source_lock_canonical_sha256": SOURCE_LOCK},
        "artifacts": [{"id": key, "path": paths[key], "canonical_sha256": sha(canonical_json_v1_bytes(docs[key]))} for key in ("schema", "profile", "vectors")],
    }
    return {**docs, "bundle": bundle}


def rendered() -> dict[Path, bytes]:
    names = {"schema": "godot_action_executor.schema.json", "profile": "godot_action_executor_profile.json", "vectors": "godot_action_executor_conformance_vectors.json", "bundle": "godot_action_executor_bundle.json"}
    return {CONTRACT_ROOT / names[key]: (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8") for key, value in documents().items()}


def verify_parent() -> None:
    raw = PARENT_MANIFEST.read_bytes()
    if sha(raw) != PARENT_RAW or sha(canonical_json_v1_bytes(load_json_strict(PARENT_MANIFEST))) != PARENT_CANONICAL:
        raise SystemExit("P3-WP3 parent manifest drift")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    verify_parent()
    outputs = rendered()
    if args.check:
        bad = [str(path.relative_to(ROOT)) for path, data in outputs.items() if not path.is_file() or path.read_bytes() != data]
        if bad:
            raise SystemExit("generated artifact drift: " + ", ".join(bad))
        return 0
    for path, data in outputs.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
