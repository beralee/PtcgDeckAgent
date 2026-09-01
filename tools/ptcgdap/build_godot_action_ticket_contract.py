from __future__ import annotations

import argparse
import copy
import hashlib
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from scripts.ai.ptcgdap.cabt_selection import CabtSelectionWindow


CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"
SCHEMA_PATH = CONTRACT_ROOT / "godot_action_ticket.schema.json"
PROFILE_PATH = CONTRACT_ROOT / "godot_action_ticket_profile.json"
VECTORS_PATH = CONTRACT_ROOT / "godot_action_ticket_conformance_vectors.json"
BUNDLE_PATH = CONTRACT_ROOT / "godot_action_ticket_bundle.json"
PARENT_VECTORS_PATH = CONTRACT_ROOT / "godot_option_binding_conformance_vectors.json"
PROFILE_ID = "ptcgdap-godot-action-ticket-p3-wp3-v1"
PARENT_MANIFEST_CANONICAL = "F1ABB0D82469174C321DA42D54AC24F045908183898F16F1A80E97BE4277BA0E"
OPTION_BINDING_BUNDLE_CANONICAL = "4FFFEC48E4E1FE0774BB6E343D4D4B0384A9210057DEE06415C2A20F2899B1C1"
OPTION_BINDING_VECTORS_CANONICAL = "8B13EABF6039F20346D4F52326E4B20CDD6FE000E7F685B7527DB6163F06B40F"
DECISION_PORT_BUNDLE_CANONICAL = "CC0026D523F2B5435031AC4E5952DB4E2C8B2C39944B333E97B1A2E4F3374C81"
SELECTION_BUNDLE_CANONICAL = "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
SOURCE_LOCK_CANONICAL = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
SAFE_MAX = 9007199254740991
TICKET_PREFIX = b"PTCGDAP\0GODOT_ACTION_TICKET_V1\0"

ERROR_CODES = [
    "",
    "ticket_contract_error",
    "invalid_session_id",
    "invalid_public_observation_hash",
    "invalid_binding_owner",
    "invalid_binding",
    "binding_not_current",
    "invalid_selection_resolution",
    "selection_not_current",
    "public_hash_mismatch",
    "invalid_callback_binding_hash",
    "active_ticket_exists",
    "binding_already_claimed",
    "ticket_space_exhausted",
    "invalid_ticket",
    "ticket_not_current",
    "ticket_already_claimed",
    "ticket_revoked",
    "session_mismatch",
    "callback_mismatch",
    "private_reference_unavailable",
    "ticket_integrity_invalid",
    "owner_mismatch",
]


def _strict(properties: dict[str, Any], required: list[str] | None = None) -> dict[str, Any]:
    return {
        "type": "object",
        "additionalProperties": False,
        "required": list(properties) if required is None else required,
        "properties": properties,
    }


def _result_schema(audit: dict[str, Any]) -> dict[str, Any]:
    base = _strict({
        "accepted": {"type": "boolean"},
        "error_code": {"type": "string", "enum": ERROR_CODES},
        "audit": {"oneOf": [{"type": "null"}, audit]},
    })
    base["oneOf"] = [
        {"properties": {"accepted": {"const": True}, "error_code": {"const": ""}, "audit": audit}},
        {"properties": {"accepted": {"const": False}, "error_code": {"enum": ERROR_CODES[1:]}, "audit": {"type": "null"}}},
    ]
    return base


def build_schema() -> dict[str, Any]:
    sha = {"type": "string", "pattern": "^[A-F0-9]{64}$"}
    nonnegative = {"type": "integer", "minimum": 0, "maximum": SAFE_MAX}
    positive = {"type": "integer", "minimum": 1, "maximum": SAFE_MAX}
    indexes = {"type": "array", "minItems": 0, "maxItems": 256, "uniqueItems": True, "items": nonnegative}
    fingerprints = {"type": "array", "minItems": 0, "maxItems": 256, "items": sha}
    ticket_audit = _strict({
        "ticket_profile": {"const": PROFILE_ID},
        "ticket_id": sha,
        "ticket_generation": positive,
        "binding_version": positive,
        "snapshot_id": sha,
        "window_id": sha,
        "public_observation_hash": sha,
        "selected_indexes": indexes,
        "selected_fingerprint_hashes": fingerprints,
        "authority": {"const": "godot_action_ticket_shadow"},
        "authoritative": {"const": False},
    })
    claim_audit = _strict({
        "ticket_profile": {"const": PROFILE_ID},
        "ticket_id": sha,
        "ticket_generation": positive,
        "selected_indexes": indexes,
        "selected_fingerprint_hashes": fingerprints,
        "state": {"const": "claimed"},
        "authority": {"const": "godot_action_claim_shadow"},
        "authoritative": {"const": False},
    })
    selection_variant = _strict({
        "owner": {"type": "string", "enum": ["policy", "deterministic_fallback"]},
        "attempt_kind": {"type": "string", "enum": ["exact_indexes", "invalid_policy_output"]},
        "attempt_indexes": indexes,
        "selected_indexes": indexes,
    })
    fixture = _strict({
        "binding_fixture_id": {"const": "valid-mixed-order"},
        "binding_vectors_canonical_sha256": {"const": OPTION_BINDING_VECTORS_CANONICAL},
        "binding_fixture_patch": _strict({"window_option_0_area": {"const": 2}}),
        "session_id": {"type": "string", "pattern": "^session:[a-z0-9_-]{1,64}$"},
        "public_observation_hash": sha,
        "callback_binding_hash": sha,
        "snapshot_id": sha,
        "window_id": sha,
        "binding_version": {"const": 1},
        "option_fingerprints": {"type": "array", "minItems": 1, "maxItems": 256, "items": sha},
        "selection_variants": _strict({
            "policy_ordered": selection_variant,
            "fallback_single": selection_variant,
        }),
        "expected_ticket_audits": _strict({
            "policy_ordered": ticket_audit,
            "fallback_single": ticket_audit,
        }),
        "expected_claim_audits": _strict({
            "policy_ordered": claim_audit,
            "fallback_single": claim_audit,
        }),
    })
    issue_case = _strict({
        "id": {"type": "string", "pattern": "^[a-z0-9-]+$"},
        "selection_variant": {"type": "string", "enum": ["policy_ordered", "fallback_single"]},
        "fault": {"type": "string", "enum": [
            "none", "session_type", "session_format", "public_hash_type", "public_hash_mismatch",
            "binding_copy", "stale_snapshot", "window_copy", "resolution_copy", "callback_drift",
            "active_ticket_conflict", "claimed_binding_reissue",
        ]},
        "expected": _result_schema(ticket_audit),
    })
    claim_case = _strict({
        "id": {"type": "string", "pattern": "^[a-z0-9-]+$"},
        "selection_variant": {"type": "string", "enum": ["policy_ordered", "fallback_single"]},
        "fault": {"type": "string", "enum": [
            "none", "session_drift", "callback_drift", "public_hash_drift", "ticket_copy",
            "cross_owner", "stale_binding", "dead_command", "dead_private_ref", "double_claim", "ticket_mutation",
        ]},
        "expected": _result_schema(claim_audit),
    })
    transition_case = _strict({
        "id": {"type": "string", "pattern": "^[a-z0-9-]+$"},
        "scenario": {"type": "string", "enum": [
            "idempotent_issue", "active_conflict", "new_binding_revokes", "successful_claim_closes_binding", "failed_context_attempt_atomic",
        ]},
        "expected_error": {"type": "string", "enum": ERROR_CODES},
    })
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.invalid/contracts/godot_action_ticket.schema.json",
        "title": "PtcgDAP P3-WP3 Godot action ticket contract",
        "anyOf": [
            {"$ref": "#/$defs/profileDocument"},
            {"$ref": "#/$defs/vectorDocument"},
            {"$ref": "#/$defs/bundleDocument"},
            {"$ref": "#/$defs/ticketAudit"},
            {"$ref": "#/$defs/claimAudit"},
            {"$ref": "#/$defs/issueResult"},
            {"$ref": "#/$defs/claimResult"},
        ],
        "$defs": {
            "ticketAudit": ticket_audit,
            "claimAudit": claim_audit,
            "issueResult": _result_schema(ticket_audit),
            "claimResult": _result_schema(claim_audit),
            "profileDocument": _strict({
                "schema_version": {"const": 1},
                "profile_id": {"const": PROFILE_ID},
                "parent": {"type": "object"},
                "hash_profile": {"type": "object"},
                "limits": {"type": "object"},
                "session_contract": {"type": "object"},
                "issue_contract": {"type": "object"},
                "claim_contract": {"type": "object"},
                "serialization_contract": {"type": "object"},
                "error_codes": {"type": "array", "minItems": len(ERROR_CODES), "maxItems": len(ERROR_CODES), "uniqueItems": True, "items": {"type": "string", "enum": ERROR_CODES}},
                "next_authority": {"type": "object"},
            }),
            "vectorDocument": _strict({
                "schema_version": {"const": 1},
                "profile_id": {"const": PROFILE_ID},
                "fixture": fixture,
                "issue_cases": {"type": "array", "minItems": 12, "items": issue_case},
                "claim_cases": {"type": "array", "minItems": 11, "items": claim_case},
                "transition_cases": {"type": "array", "minItems": 5, "items": transition_case},
            }),
            "bundleDocument": _strict({
                "schema_version": {"const": 1},
                "contract_id": {"const": PROFILE_ID},
                "parent": {"type": "object"},
                "artifacts": {
                    "type": "array", "minItems": 3, "maxItems": 3,
                    "items": _strict({
                        "id": {"type": "string", "enum": ["schema", "profile", "vectors"]},
                        "path": {"type": "string", "enum": [
                            "contracts/ptcgdap/godot_action_ticket.schema.json",
                            "contracts/ptcgdap/godot_action_ticket_profile.json",
                            "contracts/ptcgdap/godot_action_ticket_conformance_vectors.json",
                        ]},
                        "canonical_sha256": sha,
                    }),
                },
            }),
        },
    }


def build_profile() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "parent": {
            "work_package": "P3-WP2",
            "manifest_canonical_sha256": PARENT_MANIFEST_CANONICAL,
            "option_binding_bundle_canonical_sha256": OPTION_BINDING_BUNDLE_CANONICAL,
            "option_binding_vectors_canonical_sha256": OPTION_BINDING_VECTORS_CANONICAL,
            "decision_port_bundle_canonical_sha256": DECISION_PORT_BUNDLE_CANONICAL,
            "selection_bundle_canonical_sha256": SELECTION_BUNDLE_CANONICAL,
            "source_lock_canonical_sha256": SOURCE_LOCK_CANONICAL,
        },
        "hash_profile": {
            "id": "godot_action_ticket_v1",
            "algorithm": "SHA-256",
            "canonicalization": "RFC8785-JCS constrained to canonical_json_v1 safe value domain",
            "prefix_utf8_hex": TICKET_PREFIX.hex().upper(),
            "payload_fields_in_order": [
                "profile", "ticket_generation", "session_id", "callback_binding_hash", "binding_version",
                "snapshot_id", "window_id", "public_observation_hash", "selected_indexes", "selected_fingerprint_hashes",
            ],
            "ticket_id_is_authority": False,
        },
        "limits": {
            "max_options": 256,
            "max_selected_indexes": 256,
            "max_private_refs_per_option": 16,
            "max_safe_integer": SAFE_MAX,
            "one_active_ticket_per_owner": True,
            "one_successful_claim_per_binding_version": True,
        },
        "session_contract": {
            "exact_host_type": "String/str",
            "pattern": "^session:[a-z0-9_-]{1,64}$",
            "serialized": False,
            "cross_session_replay": "session_mismatch",
        },
        "issue_contract": {
            "requires_exact_current_binding_owner_and_binding": True,
            "requires_exact_current_port_snapshot_window_callback": True,
            "requires_exact_owner_selection_resolution": True,
            "selection_order_preserved": True,
            "fingerprints_derived_from_exact_window_positions": True,
            "same_context_retry_is_idempotent": True,
            "different_selection_while_active": "active_ticket_exists",
            "claimed_binding_reissue": "binding_already_claimed",
        },
        "claim_contract": {
            "claim_success_count": 1,
            "wrong_session_callback_or_public_hash_does_not_consume": True,
            "stale_binding_or_dead_reference_revokes": True,
            "returns_exact_binding_resolutions": True,
            "invokes_engine_methods": False,
            "commits_or_executes": False,
        },
        "serialization_contract": {
            "dto_only": True,
            "grants_authority": False,
            "forbidden_fields": [
                "session_id", "callback_binding_hash", "private_engine_command", "private_object_refs",
                "binding_owner", "binding", "port", "snapshot", "window", "selection_resolution", "claim_resolutions",
                "current_source", "command_refs", "private_refs",
            ],
            "consumer_rule": "schema or integrity success never authorizes execution; a later executor must receive the exact owner claim and revalidate current engine context",
        },
        "error_codes": ERROR_CODES,
        "next_authority": {
            "work_package": "P3-WP4",
            "owns": "GodotActionExecutor preflight and non-live atomic command commit",
            "implemented_here": False,
        },
    }


def _ticket_id(
    generation: int,
    session_id: str,
    callback_hash: str,
    binding_version: int,
    snapshot_id: str,
    window_id: str,
    public_hash: str,
    indexes: list[int],
    fingerprints: list[str],
) -> str:
    payload = {
        "profile": PROFILE_ID,
        "ticket_generation": generation,
        "session_id": session_id,
        "callback_binding_hash": callback_hash,
        "binding_version": binding_version,
        "snapshot_id": snapshot_id,
        "window_id": window_id,
        "public_observation_hash": public_hash,
        "selected_indexes": indexes,
        "selected_fingerprint_hashes": fingerprints,
    }
    return hashlib.sha256(TICKET_PREFIX + canonical_json_v1_bytes(payload)).hexdigest().upper()


def _ticket_audit(parent: dict[str, Any], session: str, callback: str, indexes: list[int]) -> dict[str, Any]:
    fingerprints = [parent["expected_option_fingerprints"][index] for index in indexes]
    return {
        "ticket_profile": PROFILE_ID,
        "ticket_id": _ticket_id(
            1, session, callback, 1, parent["expected_snapshot_id"], parent["expected_window_id"],
            parent["window"]["public_observation_hash"], indexes, fingerprints,
        ),
        "ticket_generation": 1,
        "binding_version": 1,
        "snapshot_id": parent["expected_snapshot_id"],
        "window_id": parent["expected_window_id"],
        "public_observation_hash": parent["window"]["public_observation_hash"],
        "selected_indexes": indexes,
        "selected_fingerprint_hashes": fingerprints,
        "authority": "godot_action_ticket_shadow",
        "authoritative": False,
    }


def _claim_audit(ticket: dict[str, Any]) -> dict[str, Any]:
    return {
        "ticket_profile": PROFILE_ID,
        "ticket_id": ticket["ticket_id"],
        "ticket_generation": ticket["ticket_generation"],
        "selected_indexes": ticket["selected_indexes"],
        "selected_fingerprint_hashes": ticket["selected_fingerprint_hashes"],
        "state": "claimed",
        "authority": "godot_action_claim_shadow",
        "authoritative": False,
    }


def build_vectors() -> dict[str, Any]:
    parent_vectors = load_json_strict(PARENT_VECTORS_PATH)
    parent = copy.deepcopy(parent_vectors["fixture"])
    parent["window"]["select"]["option"][0]["area"] = 2
    built = CabtSelectionWindow.build(
        copy.deepcopy(parent["window"]["select"]),
        public_observation_hash=parent["window"]["public_observation_hash"],
        public_hash_authority=parent["window"]["public_hash_authority"],
        chooser_player_index=parent["window"]["chooser_player_index"],
    )
    if not built.accepted or not built.validate_integrity() or built.window.decision_state != "policy_allowed":
        raise AssertionError(built.to_public_dict())
    parent["expected_window_id"] = built.window.window_id
    parent["expected_option_fingerprints"] = list(built.window.option_fingerprints)
    session = "session:alpha"
    callback = parent["callback_binding_hash"]
    policy_ticket = _ticket_audit(parent, session, callback, [1, 0])
    fallback_ticket = _ticket_audit(parent, session, callback, [0])
    policy_claim = _claim_audit(policy_ticket)
    fallback_claim = _claim_audit(fallback_ticket)
    ok_policy = {"accepted": True, "error_code": "", "audit": policy_ticket}
    ok_fallback = {"accepted": True, "error_code": "", "audit": fallback_ticket}
    reject = lambda code: {"accepted": False, "error_code": code, "audit": None}
    return {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "fixture": {
            "binding_fixture_id": "valid-mixed-order",
            "binding_vectors_canonical_sha256": OPTION_BINDING_VECTORS_CANONICAL,
            "binding_fixture_patch": {"window_option_0_area": 2},
            "session_id": session,
            "public_observation_hash": parent["window"]["public_observation_hash"],
            "callback_binding_hash": callback,
            "snapshot_id": parent["expected_snapshot_id"],
            "window_id": parent["expected_window_id"],
            "binding_version": 1,
            "option_fingerprints": parent["expected_option_fingerprints"],
            "selection_variants": {
                "policy_ordered": {"owner": "policy", "attempt_kind": "exact_indexes", "attempt_indexes": [1, 0], "selected_indexes": [1, 0]},
                "fallback_single": {"owner": "deterministic_fallback", "attempt_kind": "invalid_policy_output", "attempt_indexes": [], "selected_indexes": [0]},
            },
            "expected_ticket_audits": {"policy_ordered": policy_ticket, "fallback_single": fallback_ticket},
            "expected_claim_audits": {"policy_ordered": policy_claim, "fallback_single": fallback_claim},
        },
        "issue_cases": [
            {"id": "issue-policy-ordered", "selection_variant": "policy_ordered", "fault": "none", "expected": ok_policy},
            {"id": "issue-fallback-single", "selection_variant": "fallback_single", "fault": "none", "expected": ok_fallback},
            {"id": "issue-session-type", "selection_variant": "policy_ordered", "fault": "session_type", "expected": reject("invalid_session_id")},
            {"id": "issue-session-format", "selection_variant": "policy_ordered", "fault": "session_format", "expected": reject("invalid_session_id")},
            {"id": "issue-public-hash-type", "selection_variant": "policy_ordered", "fault": "public_hash_type", "expected": reject("invalid_public_observation_hash")},
            {"id": "issue-public-hash-mismatch", "selection_variant": "policy_ordered", "fault": "public_hash_mismatch", "expected": reject("public_hash_mismatch")},
            {"id": "issue-binding-copy", "selection_variant": "policy_ordered", "fault": "binding_copy", "expected": reject("invalid_binding")},
            {"id": "issue-stale-snapshot", "selection_variant": "policy_ordered", "fault": "stale_snapshot", "expected": reject("binding_not_current")},
            {"id": "issue-window-copy", "selection_variant": "policy_ordered", "fault": "window_copy", "expected": reject("binding_not_current")},
            {"id": "issue-resolution-copy", "selection_variant": "policy_ordered", "fault": "resolution_copy", "expected": reject("invalid_selection_resolution")},
            {"id": "issue-callback-drift", "selection_variant": "policy_ordered", "fault": "callback_drift", "expected": reject("binding_not_current")},
            {"id": "issue-active-conflict", "selection_variant": "fallback_single", "fault": "active_ticket_conflict", "expected": reject("active_ticket_exists")},
            {"id": "issue-claimed-reissue", "selection_variant": "policy_ordered", "fault": "claimed_binding_reissue", "expected": reject("binding_already_claimed")},
        ],
        "claim_cases": [
            {"id": "claim-policy-ordered", "selection_variant": "policy_ordered", "fault": "none", "expected": {"accepted": True, "error_code": "", "audit": policy_claim}},
            {"id": "claim-fallback-single", "selection_variant": "fallback_single", "fault": "none", "expected": {"accepted": True, "error_code": "", "audit": fallback_claim}},
            {"id": "claim-session-drift", "selection_variant": "policy_ordered", "fault": "session_drift", "expected": reject("session_mismatch")},
            {"id": "claim-callback-drift", "selection_variant": "policy_ordered", "fault": "callback_drift", "expected": reject("callback_mismatch")},
            {"id": "claim-public-hash-drift", "selection_variant": "policy_ordered", "fault": "public_hash_drift", "expected": reject("public_hash_mismatch")},
            {"id": "claim-ticket-copy", "selection_variant": "policy_ordered", "fault": "ticket_copy", "expected": reject("invalid_ticket")},
            {"id": "claim-cross-owner", "selection_variant": "policy_ordered", "fault": "cross_owner", "expected": reject("owner_mismatch")},
            {"id": "claim-stale-binding", "selection_variant": "policy_ordered", "fault": "stale_binding", "expected": reject("binding_not_current")},
            {"id": "claim-dead-command", "selection_variant": "policy_ordered", "fault": "dead_command", "expected": reject("private_reference_unavailable")},
            {"id": "claim-dead-private-ref", "selection_variant": "policy_ordered", "fault": "dead_private_ref", "expected": reject("private_reference_unavailable")},
            {"id": "claim-double", "selection_variant": "policy_ordered", "fault": "double_claim", "expected": reject("ticket_already_claimed")},
            {"id": "claim-ticket-mutation", "selection_variant": "policy_ordered", "fault": "ticket_mutation", "expected": reject("ticket_integrity_invalid")},
        ],
        "transition_cases": [
            {"id": "issue-idempotent", "scenario": "idempotent_issue", "expected_error": ""},
            {"id": "active-conflict-atomic", "scenario": "active_conflict", "expected_error": "active_ticket_exists"},
            {"id": "new-binding-revokes", "scenario": "new_binding_revokes", "expected_error": "ticket_revoked"},
            {"id": "claim-closes-binding", "scenario": "successful_claim_closes_binding", "expected_error": "binding_already_claimed"},
            {"id": "wrong-context-does-not-consume", "scenario": "failed_context_attempt_atomic", "expected_error": "session_mismatch"},
        ],
    }


def _canonical_hash(value: Any) -> str:
    return hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper()


def build_documents() -> dict[Path, dict[str, Any]]:
    schema = build_schema()
    profile = build_profile()
    vectors = build_vectors()
    documents = {SCHEMA_PATH: schema, PROFILE_PATH: profile, VECTORS_PATH: vectors}
    bundle = {
        "schema_version": 1,
        "contract_id": PROFILE_ID,
        "parent": {
            "work_package": "P3-WP2",
            "manifest_canonical_sha256": PARENT_MANIFEST_CANONICAL,
            "option_binding_bundle_canonical_sha256": OPTION_BINDING_BUNDLE_CANONICAL,
            "decision_port_bundle_canonical_sha256": DECISION_PORT_BUNDLE_CANONICAL,
            "selection_bundle_canonical_sha256": SELECTION_BUNDLE_CANONICAL,
            "source_lock_canonical_sha256": SOURCE_LOCK_CANONICAL,
        },
        "artifacts": [
            {"id": "schema", "path": "contracts/ptcgdap/godot_action_ticket.schema.json", "canonical_sha256": _canonical_hash(schema)},
            {"id": "profile", "path": "contracts/ptcgdap/godot_action_ticket_profile.json", "canonical_sha256": _canonical_hash(profile)},
            {"id": "vectors", "path": "contracts/ptcgdap/godot_action_ticket_conformance_vectors.json", "canonical_sha256": _canonical_hash(vectors)},
        ],
    }
    documents[BUNDLE_PATH] = bundle
    return documents


def _render(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    documents = build_documents()
    if args.check:
        mismatches = [
            str(path.relative_to(ROOT))
            for path, value in documents.items()
            if not path.is_file() or path.read_bytes() != _render(value)
        ]
        if mismatches:
            raise SystemExit("generated artifacts differ: " + ", ".join(mismatches))
        return 0
    for path, value in documents.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(_render(value))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
