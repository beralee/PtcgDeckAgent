from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes


CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"
SCHEMA_PATH = CONTRACT_ROOT / "engine_decision_port.schema.json"
PROFILE_PATH = CONTRACT_ROOT / "engine_decision_port_profile.json"
VECTORS_PATH = CONTRACT_ROOT / "engine_decision_port_conformance_vectors.json"
BUNDLE_PATH = CONTRACT_ROOT / "engine_decision_port_bundle.json"


def _strict_object(properties: dict[str, Any], required: list[str]) -> dict[str, Any]:
    return {
        "type": "object",
        "additionalProperties": False,
        "required": required,
        "properties": properties,
    }


def build_schema() -> dict[str, Any]:
    safe_int = {"type": "integer", "minimum": -9007199254740991, "maximum": 9007199254740991}
    nonnegative = {"type": "integer", "minimum": 0, "maximum": 9007199254740991}
    positive = {"type": "integer", "minimum": 1, "maximum": 9007199254740991}
    scalar_option = _strict_object(
        {
            "type": {"type": "integer", "enum": [3, 7, 13, 14, 15]},
            "index": nonnegative,
            "local_attack_index": nonnegative,
        },
        ["type"],
    )
    source_entry = _strict_object(
        {
            "position": nonnegative,
            "option": scalar_option,
            "reference_token": {"type": ["string", "null"], "minLength": 1},
        },
        ["position", "option", "reference_token"],
    )
    select = _strict_object(
        {
            "type": nonnegative,
            "context": nonnegative,
            "minCount": nonnegative,
            "maxCount": nonnegative,
            "remainDamageCounter": nonnegative,
            "remainEnergyCost": nonnegative,
            "option": {"type": "array", "maxItems": 256, "items": source_entry},
            "deck_tokens": {"type": ["array", "null"], "maxItems": 120, "items": {"type": "string", "minLength": 1}},
            "context_token": {"type": ["string", "null"], "minLength": 1},
            "effect_token": {"type": ["string", "null"], "minLength": 1},
        },
        ["type", "context", "minCount", "maxCount", "remainDamageCounter", "remainEnergyCost", "option", "deck_tokens", "context_token", "effect_token"],
    )
    audit = _strict_object(
        {
            "match_generation": positive,
            "decision_generation": positive,
            "chooser_player_index": {"type": "integer", "enum": [0, 1]},
            "snapshot_id": {"type": "string", "pattern": "^[A-F0-9]{64}$"},
            "source_digest": {"type": "string", "pattern": "^[A-F0-9]{64}$"},
            "select": {"oneOf": [{"type": "null"}, select]},
            "turn_action_count": nonnegative,
            "reference_count": nonnegative,
            "authority": {"const": "engine_decision_port_shadow"},
            "authoritative": {"const": False},
        },
        ["match_generation", "decision_generation", "chooser_player_index", "snapshot_id", "source_digest", "select", "turn_action_count", "reference_count", "authority", "authoritative"],
    )
    result = _strict_object(
        {
            "accepted": {"type": "boolean"},
            "error_code": {"type": "string"},
            "audit": {"oneOf": [{"type": "null"}, audit]},
        },
        ["accepted", "error_code", "audit"],
    )
    vector = _strict_object(
        {
            "id": {"type": "string", "pattern": "^[a-z0-9][a-z0-9_-]*$"},
            "match_generation": safe_int,
            "decision_generation": safe_int,
            "chooser_player_index": safe_int,
            "source": {"type": "object"},
            "expected": result,
        },
        ["id", "match_generation", "decision_generation", "chooser_player_index", "source", "expected"],
    )
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/engine_decision_port.schema.json",
        "title": "PtcgDAP immutable EngineDecisionPort shadow contract",
        "$defs": {"audit": audit, "result": result, "vector": vector},
        "oneOf": [{"$ref": "#/$defs/audit"}, {"$ref": "#/$defs/result"}, {"$ref": "#/$defs/vector"}],
    }


ERROR_CODES = [
    "", "decision_contract_error", "invalid_match_generation", "invalid_decision_generation",
    "invalid_chooser_player_index", "invalid_decision_source", "invalid_select", "invalid_option_source",
    "invalid_reference", "reference_released", "stale_decision_generation", "stale_match_generation",
    "source_mutated", "snapshot_not_current", "snapshot_owner_mismatch", "snapshot_integrity_invalid",
]


def build_profile() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "profile_id": "ptcgdap-engine-decision-port-p3-wp1-v1",
        "mode": "shadow_snapshot_only",
        "supported_engine_option_types": [3, 7, 13, 14, 15],
        "option_shapes": {
            "3": ["type"], "7": ["type", "index"], "13": ["type", "local_attack_index"],
            "14": ["type"], "15": ["type"],
        },
        "reference_rules": {
            "15": "exact CardInstance reference required",
            "3": "reference forbidden", "7": "reference forbidden", "13": "reference forbidden", "14": "reference forbidden",
            "deck_context_effect": "exact CardInstance references when present",
            "storage": "weak exact-object binding; never serialized",
        },
        "generation_rules": {
            "match_generation": "positive exact safe integer fixed for port lifetime",
            "decision_generation": "positive exact safe integer and strictly increasing",
            "replacement": "a newer accepted publish invalidates every older snapshot",
        },
        "hash_profile": {
            "algorithm": "SHA-256",
            "canonicalization": "canonical_json_v1",
            "source_prefix_utf8_hex": "5054434744415000454E47494E455F4445434953494F4E5F534F555243455F563100",
            "snapshot_prefix_utf8_hex": "5054434744415000454E47494E455F4445434953494F4E5F534E415053484F545F563100",
            "authority": "audit_only_not_binding_or_execution_authority",
        },
        "limits": {"max_options": 256, "max_deck_references": 120, "max_total_references": 384},
        "error_codes": ERROR_CODES,
        "serialization_contract": {
            "dto_only": True,
            "forbidden_fields": ["engine_object", "object_id", "instance_id", "name", "private_command", "callback_binding", "ticket", "_pending_choice", "_dialog_data"],
            "consumer_rule": "serialized or schema-valid data never grants decision, window, binding or execution authority",
        },
    }


def _select(option: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "type": 0, "context": 0, "minCount": 1 if option else 0, "maxCount": 1 if option else 0,
        "remainDamageCounter": 0, "remainEnergyCost": 0, "option": option,
        "deck": None, "contextCard": None, "effect": None,
    }


def _source(
    select: Any,
    refs: list[Any],
    turn_action_count: int = 0,
    deck: Any = None,
    context: Any = None,
    effect: Any = None,
) -> dict[str, Any]:
    return {
        "select": select,
        "deck_cards": deck,
        "context_card": context,
        "effect_card": effect,
        "option_card_refs": refs,
        "turn_action_count": turn_action_count,
    }


def build_vectors() -> dict[str, Any]:
    valid = [
        ("null-reset", 1, 1, 0, _source(None, [])),
        ("scalar-order", 1, 2, 0, _source(_select([{"type": 7, "index": 2}, {"type": 14}, {"type": 3}]), [None, None, None], 3)),
        ("attack-index", 1, 3, 0, _source(_select([{"type": 13, "local_attack_index": 0}, {"type": 13, "local_attack_index": 1}]), [None, None], 4)),
        ("card-reference", 1, 4, 1, _source(_select([{"type": 15}, {"type": 15}]), ["card:a", "card:b"], 0)),
        ("deck-context-effect", 1, 5, 1, _source(_select([{"type": 14}]), [None], 0, ["card:a", "card:b"], "card:c", "card:d")),
    ]
    cases = []
    for case_id, match_generation, decision_generation, chooser, source in valid:
        cases.append({
            "id": case_id,
            "match_generation": match_generation,
            "decision_generation": decision_generation,
            "chooser_player_index": chooser,
            "source": source,
            "expected": {"accepted": True, "error_code": "", "audit": None},
        })
    invalid = [
        ("bad-match", 0, 1, 0, _source(None, []), "invalid_match_generation"),
        ("bad-generation", 1, 0, 0, _source(None, []), "invalid_decision_generation"),
        ("bad-chooser", 1, 1, 2, _source(None, []), "invalid_chooser_player_index"),
        ("source-extra-key", 1, 1, 0, {**_source(None, []), "private": "sentinel"}, "invalid_decision_source"),
        ("bad-option-shape", 1, 1, 0, _source(_select([{"type": 14, "index": 0}]), [None]), "invalid_option_source"),
        ("missing-card-ref", 1, 1, 0, _source(_select([{"type": 15}]), [None]), "invalid_reference"),
        ("ref-on-scalar", 1, 1, 0, _source(_select([{"type": 14}]), ["card:a"]), "invalid_reference"),
    ]
    for case_id, match_generation, decision_generation, chooser, source, code in invalid:
        cases.append({
            "id": case_id,
            "match_generation": match_generation,
            "decision_generation": decision_generation,
            "chooser_player_index": chooser,
            "source": source,
            "expected": {"accepted": False, "error_code": code, "audit": None},
        })
    return {
        "schema_version": 1,
        "profile_id": "ptcgdap-engine-decision-port-p3-wp1-v1",
        "host_token_encoding": {"card_reference": "card:<fixture-label>", "null_reference": None},
        "publish_cases": cases,
        "transition_cases": [
            {"id": "strictly-increasing", "generations": [1, 2, 3], "expected": ["", "", ""]},
            {"id": "duplicate-generation", "generations": [1, 1], "expected": ["", "stale_decision_generation"]},
            {"id": "decreasing-generation", "generations": [2, 1], "expected": ["", "stale_decision_generation"]},
        ],
        "mutation_cases": ["option_reorder", "scalar_change", "reference_replace", "reference_release", "cross_port", "copied_dto"],
    }


def _canonical_hash(value: Any) -> str:
    return hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper()


def build_documents() -> dict[Path, dict[str, Any]]:
    schema = build_schema()
    profile = build_profile()
    vectors = build_vectors()
    docs = {SCHEMA_PATH: schema, PROFILE_PATH: profile, VECTORS_PATH: vectors}
    bundle = {
        "schema_version": 1,
        "contract_id": "ptcgdap-engine-decision-port-p3-wp1-v1",
        "parent": {
            "work_package": "P2-WP5",
            "manifest_canonical_sha256": "F0A2C3E92E566163F14FA4B49C33728637660BCF192D59CA32B2B578DBAFB816",
            "projector_bundle_canonical_sha256": "C51EA4CF1AEFCBB5B9C6D83825FF3A717CCDCC4105B804210BF6169372619041",
        },
        "artifacts": [
            {"id": "schema", "path": "contracts/ptcgdap/engine_decision_port.schema.json", "canonical_sha256": _canonical_hash(schema)},
            {"id": "profile", "path": "contracts/ptcgdap/engine_decision_port_profile.json", "canonical_sha256": _canonical_hash(profile)},
            {"id": "vectors", "path": "contracts/ptcgdap/engine_decision_port_conformance_vectors.json", "canonical_sha256": _canonical_hash(vectors)},
        ],
    }
    docs[BUNDLE_PATH] = bundle
    return docs


def _render(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    docs = build_documents()
    if args.check:
        mismatches = [str(path.relative_to(ROOT)) for path, value in docs.items() if not path.is_file() or path.read_bytes() != _render(value)]
        if mismatches:
            raise SystemExit("generated artifacts differ: " + ", ".join(mismatches))
        return 0
    for path, value in docs.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(_render(value))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
