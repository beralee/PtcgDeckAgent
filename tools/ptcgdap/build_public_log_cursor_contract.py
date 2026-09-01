from __future__ import annotations

import argparse
import copy
import hashlib
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"
FIREWALL_SCHEMA = CONTRACT_ROOT / "cabt_public_observation.schema.json"
FIREWALL_VECTORS = CONTRACT_ROOT / "cabt_public_firewall_conformance_vectors.json"
OUTPUTS = {
    "schema": CONTRACT_ROOT / "cabt_public_log_cursor.schema.json",
    "profile": CONTRACT_ROOT / "cabt_public_log_cursor_profile.json",
    "vectors": CONTRACT_ROOT / "cabt_public_log_cursor_conformance_vectors.json",
    "bundle": CONTRACT_ROOT / "cabt_public_log_cursor_bundle.json",
}

PROFILE_ID = "cabt_public_log_cursor_profile_v1"
VECTOR_SET_ID = "cabt_public_log_cursor_conformance_v1"
BUNDLE_ID = "ptcgdap-public-log-cursor-p2-wp4-v1"
PARENT_FIREWALL_BUNDLE_ID = "ptcgdap-public-firewall-p2-wp3-v1"
PARENT_FIREWALL_BUNDLE_SHA256 = "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947"
P1_CONTRACT_SHA256 = "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
WITNESS_PREFIX = b"PTCGDAP\0CABT_PUBLIC_LOG_SLICE_V1\0"
MAX_SAFE_INTEGER = 9_007_199_254_740_991
ERROR_CODES = [
    "invalid_firewall_result",
    "firewall_result_not_accepted",
    "cursor_contract_error",
    "pending_selection_uncommitted",
    "invalid_slice_result",
    "slice_not_pending",
    "slice_cursor_mismatch",
    "slice_generation_stale",
    "slice_integrity_invalid",
    "source_result_replayed",
    "public_log_limit",
    "witness_error",
]


def _bootstrap() -> None:
    value = str(ROOT)
    if value not in sys.path:
        sys.path.insert(0, value)


def _strict_load(path: Path) -> Any:
    _bootstrap()
    from scripts.ai.ptcgdap.source_lock import load_json_strict

    return load_json_strict(path)


def _canonical_hash(value: Any) -> str:
    _bootstrap()
    from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, sha256_bytes

    return sha256_bytes(canonical_json_v1_bytes(value))


def _jcs_bytes(value: Any) -> bytes:
    _bootstrap()
    from scripts.ai.ptcgdap.cabt_tree_hash import jcs_canonical_json_bytes

    return jcs_canonical_json_bytes(value)


def _json_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def _safe_nonnegative() -> dict[str, Any]:
    return {"type": "integer", "minimum": 0, "maximum": MAX_SAFE_INTEGER}


def _sha_schema(nullable: bool = False) -> dict[str, Any]:
    value: dict[str, Any] = {"type": "string", "pattern": "^[0-9A-F]{64}$"}
    return {"anyOf": [value, {"type": "null"}]} if nullable else value


def build_profile() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "parent_firewall": {
            "bundle_id": PARENT_FIREWALL_BUNDLE_ID,
            "canonical_sha256": PARENT_FIREWALL_BUNDLE_SHA256,
            "accepted_result_profile_id": "cabt_public_firewall_profile_v1",
        },
        "witness_contract": {
            "profile_id": "cabt_public_log_slice_v1",
            "prefix_utf8_hex": WITNESS_PREFIX.hex().upper(),
            "canonicalization": "RFC8785-JCS",
            "algorithm": "SHA-256",
            "payload_fields_in_order_independent_object": [
                "ordinal",
                "previous_witness",
                "source_public_observation_hash",
                "logs",
            ],
            "forbidden_fields": [
                "session_id",
                "match_generation",
                "raw_private_hash",
                "token_free_callback_hash",
                "search_begin_input",
                "search_capability_present",
            ],
        },
        "cursor_lifecycle": {
            "initial_ordinal": 0,
            "initial_previous_witness": None,
            "peek": "create one pending exact-owner slice; repeated peek of the same firewall owner result is idempotent",
            "pending": "a different source result is rejected until the exact pending slice is committed",
            "commit": "only the exact pending slice owner result advances ordinal and previous witness once",
            "reset": "increment the private generation, clear pending state and replay memory, reset ordinal and previous witness",
            "replay": "an exact firewall owner result already committed in the same generation is rejected",
        },
        "input_authority": {
            "required": "exact accepted PublicObservationFirewall owner result validated against its exact bound envelope",
            "copied_dictionary_authorizes": False,
            "caller_log_array_authorizes": False,
            "schema_pass_authorizes": False,
            "godot_private_event_authorizes": False,
        },
        "result_contract": {
            "serialization_authority": "audit_and_conformance_only",
            "success": "exact ordered logs, ordinal, previous witness, source public-observation hash and witness",
            "failure": "null slice or receipt plus one closed non-echoing issue",
            "error_codes": ERROR_CODES,
            "consumer_rule": "no live consumer exists; later owners must keep the exact cursor and exact pending owner result in one trusted call chain",
            "reflection_boundary": "not a hostile same-process sandbox",
        },
        "limits": {
            "max_logs_per_slice": 4096,
            "max_log_tree_depth": 64,
            "max_log_tree_nodes": 200000,
        },
        "non_claims": [
            "Godot engine log projection",
            "Host callback ticket",
            "public trajectory persistence",
            "live ownership",
            "package or device runtime",
        ],
    }


def build_schema(firewall_schema: dict[str, Any]) -> dict[str, Any]:
    log_schema = copy.deepcopy(firewall_schema["$defs"]["Log"])
    defs: dict[str, Any] = {
        "Log": log_schema,
        "CursorIssue": {
            "type": "object",
            "additionalProperties": False,
            "properties": {
                "code": {"enum": ERROR_CODES},
                "severity": {"const": "error"},
            },
            "required": ["code", "severity"],
        },
        "PublicLogSlice": {
            "type": "object",
            "additionalProperties": False,
            "properties": {
                "schema_version": {"const": 1},
                "profile_id": {"const": PROFILE_ID},
                "ordinal": _safe_nonnegative(),
                "previous_witness": _sha_schema(nullable=True),
                "source_public_observation_hash": _sha_schema(),
                "logs": {"type": "array", "maxItems": 4096, "items": {"$ref": "#/$defs/Log"}},
                "witness_hash": _sha_schema(),
            },
            "required": [
                "schema_version",
                "profile_id",
                "ordinal",
                "previous_witness",
                "source_public_observation_hash",
                "logs",
                "witness_hash",
            ],
        },
    }
    defs["CursorResult"] = {
        "oneOf": [
            {
                "type": "object",
                "additionalProperties": False,
                "properties": {
                    "status": {"const": "slice_ready"},
                    "slice": {"$ref": "#/$defs/PublicLogSlice"},
                    "issues": {"type": "array", "maxItems": 0},
                },
                "required": ["status", "slice", "issues"],
            },
            {
                "type": "object",
                "additionalProperties": False,
                "properties": {
                    "status": {"const": "rejected"},
                    "slice": {"type": "null"},
                    "issues": {"type": "array", "minItems": 1, "maxItems": 1, "items": {"$ref": "#/$defs/CursorIssue"}},
                },
                "required": ["status", "slice", "issues"],
            },
        ]
    }
    defs["CommitResult"] = {
        "oneOf": [
            {
                "type": "object",
                "additionalProperties": False,
                "properties": {
                    "status": {"const": "committed"},
                    "committed_ordinal": _safe_nonnegative(),
                    "witness_hash": _sha_schema(),
                    "issues": {"type": "array", "maxItems": 0},
                },
                "required": ["status", "committed_ordinal", "witness_hash", "issues"],
            },
            {
                "type": "object",
                "additionalProperties": False,
                "properties": {
                    "status": {"const": "rejected"},
                    "committed_ordinal": {"type": "null"},
                    "witness_hash": {"type": "null"},
                    "issues": {"type": "array", "minItems": 1, "maxItems": 1, "items": {"$ref": "#/$defs/CursorIssue"}},
                },
                "required": ["status", "committed_ordinal", "witness_hash", "issues"],
            },
        ]
    }
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/cabt_public_log_cursor.schema.json",
        "title": "PtcgDAP public log cursor audit DTOs",
        "oneOf": [{"$ref": "#/$defs/PublicLogSlice"}, {"$ref": "#/$defs/CursorResult"}, {"$ref": "#/$defs/CommitResult"}],
        "$defs": defs,
    }


def _source_cases(firewall_vectors: dict[str, Any]) -> dict[str, Any]:
    by_id = {case["id"]: case for case in firewall_vectors["cases"]}
    regular = copy.deepcopy(by_id["regular-accepted"]["expected_public_observation"])
    multi_logs = [
        {"type": 2, "playerIndex": 0},
        {"type": 4, "playerIndex": 0, "cardId": 104, "serial": 31},
        {"type": 5, "playerIndex": 1},
    ]
    regular["logs"] = copy.deepcopy(multi_logs)
    move_attack_logs = [
        {"type": 6, "playerIndex": 0, "cardId": 104, "serial": 31, "fromArea": 1, "toArea": 2},
        {"type": 15, "playerIndex": 0, "cardId": 104, "serial": 31, "attackId": 7},
    ]
    move_attack = copy.deepcopy(by_id["regular-accepted"]["expected_public_observation"])
    move_attack["logs"] = copy.deepcopy(move_attack_logs)
    _bootstrap()
    from scripts.ai.ptcgdap.cabt_tree_hash import public_observation_hash

    return {
        "initial_empty": {
            "firewall_base": "initial",
            "logs_override": [],
            "source_public_observation_hash": by_id["initial-accepted"]["expected_public_observation_hash"],
            "logs": [],
        },
        "regular_empty": {
            "firewall_base": "regular",
            "logs_override": [],
            "source_public_observation_hash": by_id["regular-accepted"]["expected_public_observation_hash"],
            "logs": [],
        },
        "turn_draw_ordered": {
            "firewall_base": "regular",
            "logs_override": multi_logs,
            "source_public_observation_hash": public_observation_hash(regular),
            "logs": multi_logs,
        },
        "move_attack_ordered": {
            "firewall_base": "regular",
            "logs_override": move_attack_logs,
            "source_public_observation_hash": public_observation_hash(move_attack),
            "logs": move_attack_logs,
        },
    }


def _witness(payload: dict[str, Any]) -> tuple[str, str]:
    canonical = _jcs_bytes(payload)
    return canonical.decode("utf-8"), hashlib.sha256(WITNESS_PREFIX + canonical).hexdigest().upper()


def build_vectors(firewall_vectors: dict[str, Any]) -> dict[str, Any]:
    sources = _source_cases(firewall_vectors)
    hash_vectors = []
    previous: str | None = None
    for ordinal, source_id in enumerate(("initial_empty", "turn_draw_ordered", "regular_empty", "move_attack_ordered")):
        source = sources[source_id]
        payload = {
            "ordinal": ordinal,
            "previous_witness": previous,
            "source_public_observation_hash": source["source_public_observation_hash"],
            "logs": copy.deepcopy(source["logs"]),
        }
        canonical, digest = _witness(payload)
        hash_vectors.append({"id": f"hash-{ordinal}-{source_id}", "payload": payload, "canonical_json_utf8": canonical, "witness_hash": digest})
        previous = digest
    scenarios = [
        {"id": "initial-empty-commit", "operations": [{"op": "peek", "source": "initial_empty", "status": "slice_ready", "ordinal": 0}, {"op": "commit_pending", "status": "committed", "committed_ordinal": 0}]},
        {"id": "ordered-multi-log-commit", "operations": [{"op": "peek", "source": "turn_draw_ordered", "status": "slice_ready", "ordinal": 0}, {"op": "repeat_peek", "source": "turn_draw_ordered", "status": "slice_ready", "same_owner_result": True}, {"op": "commit_pending", "status": "committed", "committed_ordinal": 0}]},
        {"id": "witness-chain-three-boundaries", "operations": [{"op": "peek", "source": "initial_empty", "status": "slice_ready", "ordinal": 0}, {"op": "commit_pending", "status": "committed", "committed_ordinal": 0}, {"op": "peek", "source": "turn_draw_ordered", "status": "slice_ready", "ordinal": 1}, {"op": "commit_pending", "status": "committed", "committed_ordinal": 1}, {"op": "peek", "source": "regular_empty", "status": "slice_ready", "ordinal": 2}]},
        {"id": "different-source-before-commit", "operations": [{"op": "peek", "source": "regular_empty", "status": "slice_ready", "ordinal": 0}, {"op": "peek", "source": "move_attack_ordered", "status": "rejected", "error_code": "pending_selection_uncommitted"}]},
        {"id": "duplicate-commit-and-replay", "operations": [{"op": "peek", "source": "regular_empty", "status": "slice_ready", "ordinal": 0}, {"op": "commit_pending", "status": "committed", "committed_ordinal": 0}, {"op": "commit_previous", "status": "rejected", "error_code": "slice_not_pending"}, {"op": "peek", "source": "regular_empty", "status": "rejected", "error_code": "source_result_replayed"}]},
        {"id": "reset-revokes-old-slice", "operations": [{"op": "peek", "source": "turn_draw_ordered", "status": "slice_ready", "ordinal": 0}, {"op": "reset"}, {"op": "commit_previous", "status": "rejected", "error_code": "slice_generation_stale"}, {"op": "peek_new_source_instance", "source": "turn_draw_ordered", "status": "slice_ready", "ordinal": 0}]},
        {"id": "cross-cursor-commit", "operations": [{"op": "peek", "source": "move_attack_ordered", "status": "slice_ready", "ordinal": 0}, {"op": "commit_on_other_cursor", "status": "rejected", "error_code": "slice_cursor_mismatch"}]},
        {"id": "copied-dto-rejected", "operations": [{"op": "peek", "source": "regular_empty", "status": "slice_ready", "ordinal": 0}, {"op": "commit_public_dict", "status": "rejected", "error_code": "invalid_slice_result"}]},
        {"id": "rejected-firewall-result", "operations": [{"op": "peek_rejected_firewall", "firewall_case": "opponent-hand-exposed", "status": "rejected", "error_code": "firewall_result_not_accepted"}]},
    ]
    return {
        "schema_version": 1,
        "vector_set_id": VECTOR_SET_ID,
        "profile_id": PROFILE_ID,
        "parent_firewall_bundle_hash": PARENT_FIREWALL_BUNDLE_SHA256,
        "sources": sources,
        "hash_vectors": hash_vectors,
        "scenarios": scenarios,
        "private_sentinels": ["PRIVATE_SEARCH_SENTINEL", "PRIVATE_KEY_SENTINEL", "PRIVATE_VALUE_SENTINEL", "RAW_PRIVATE_HASH_SENTINEL", "TOKEN_FREE_HASH_SENTINEL"],
        "consumer_rule": "shared vectors test offline cursor semantics only; no DTO or witness authorizes live selection or execution",
    }


def build_bundle(schema: dict[str, Any], profile: dict[str, Any], vectors: dict[str, Any]) -> dict[str, Any]:
    paths = {
        "cabt_public_log_cursor_schema_v1": "contracts/ptcgdap/cabt_public_log_cursor.schema.json",
        PROFILE_ID: "contracts/ptcgdap/cabt_public_log_cursor_profile.json",
        VECTOR_SET_ID: "contracts/ptcgdap/cabt_public_log_cursor_conformance_vectors.json",
    }
    values = {"cabt_public_log_cursor_schema_v1": schema, PROFILE_ID: profile, VECTOR_SET_ID: vectors}
    return {
        "schema_version": 1,
        "bundle_id": BUNDLE_ID,
        "parent_firewall_bundle": {"id": PARENT_FIREWALL_BUNDLE_ID, "canonical_sha256": PARENT_FIREWALL_BUNDLE_SHA256},
        "p1_contract_canonical_sha256": P1_CONTRACT_SHA256,
        "artifacts": [
            {"id": artifact_id, "path": paths[artifact_id], "canonical_sha256": _canonical_hash(values[artifact_id])}
            for artifact_id in ("cabt_public_log_cursor_schema_v1", PROFILE_ID, VECTOR_SET_ID)
        ],
    }


def build_documents() -> dict[str, Any]:
    firewall_schema = _strict_load(FIREWALL_SCHEMA)
    firewall_vectors = _strict_load(FIREWALL_VECTORS)
    schema = build_schema(firewall_schema)
    profile = build_profile()
    vectors = build_vectors(firewall_vectors)
    return {"schema": schema, "profile": profile, "vectors": vectors, "bundle": build_bundle(schema, profile, vectors)}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    documents = build_documents()
    if args.check:
        failed = False
        for artifact_id, path in OUTPUTS.items():
            expected = _json_bytes(documents[artifact_id])
            if not path.is_file() or path.read_bytes() != expected:
                print(f"drift: {path.relative_to(ROOT)}", file=sys.stderr)
                failed = True
        if failed:
            return 1
    else:
        for artifact_id, path in OUTPUTS.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(_json_bytes(documents[artifact_id]))
    for artifact_id, value in documents.items():
        print(f"{artifact_id}: {_canonical_hash(value)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
