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

from scripts.ai.ptcgdap.cabt_selection import CabtSelectionWindow
from scripts.ai.ptcgdap.engine_decision_port import EngineDecisionPort
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes


CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"
SCHEMA_PATH = CONTRACT_ROOT / "godot_option_binding.schema.json"
PROFILE_PATH = CONTRACT_ROOT / "godot_option_binding_profile.json"
VECTORS_PATH = CONTRACT_ROOT / "godot_option_binding_conformance_vectors.json"
BUNDLE_PATH = CONTRACT_ROOT / "godot_option_binding_bundle.json"
PROFILE_ID = "ptcgdap-godot-option-binding-p3-wp2-v1"
PARENT_MANIFEST_CANONICAL = "B47E808277C954003494A5C414E02AD6FA81C0CE6EC73A1E7064B40E991B2F4F"
DECISION_PORT_BUNDLE_CANONICAL = "CC0026D523F2B5435031AC4E5952DB4E2C8B2C39944B333E97B1A2E4F3374C81"
SELECTION_BUNDLE_CANONICAL = "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
SOURCE_LOCK_CANONICAL = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
SAFE_MAX = 9007199254740991

ERROR_CODES = [
    "",
    "binding_contract_error",
    "invalid_port",
    "snapshot_not_current",
    "snapshot_owner_mismatch",
    "snapshot_integrity_invalid",
    "source_mutated",
    "invalid_window",
    "window_mismatch",
    "invalid_callback_binding_hash",
    "invalid_private_commands",
    "invalid_private_object_refs",
    "reference_released",
    "binding_not_current",
    "option_index_invalid",
    "binding_integrity_invalid",
    "owner_mismatch",
]


class _FixtureRef:
    pass


def _strict(properties: dict[str, Any], required: list[str] | None = None) -> dict[str, Any]:
    return {
        "type": "object",
        "additionalProperties": False,
        "required": list(properties) if required is None else required,
        "properties": properties,
    }


def _engine_options(nonnegative: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        _strict({"type": {"const": 3}}),
        _strict({"type": {"const": 7}, "index": nonnegative}),
        _strict({"type": {"const": 13}, "local_attack_index": nonnegative}),
        _strict({"type": {"const": 14}}),
        _strict({"type": {"const": 15}}),
    ]


def _window_options(safe_int: dict[str, Any], nonnegative: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        _strict({"type": {"const": 3}, "area": safe_int, "index": safe_int, "playerIndex": {"type": "integer", "enum": [0, 1]}}),
        _strict({"type": {"const": 7}, "index": nonnegative}),
        _strict({"type": {"const": 13}, "attackId": nonnegative}),
        _strict({"type": {"const": 14}}),
        _strict({"type": {"const": 15}, "cardId": nonnegative, "serial": nonnegative}),
    ]


def build_schema() -> dict[str, Any]:
    sha = {"type": "string", "pattern": "^[A-F0-9]{64}$"}
    safe_int = {"type": "integer", "minimum": -SAFE_MAX, "maximum": SAFE_MAX}
    nonnegative = {"type": "integer", "minimum": 0, "maximum": SAFE_MAX}
    engine_option = {"oneOf": _engine_options(nonnegative)}
    window_option = {"oneOf": _window_options(safe_int, nonnegative)}
    engine_select = _strict({
        "type": nonnegative,
        "context": nonnegative,
        "minCount": nonnegative,
        "maxCount": nonnegative,
        "remainDamageCounter": nonnegative,
        "remainEnergyCost": nonnegative,
        "option": {"type": "array", "maxItems": 256, "items": engine_option},
        "deck": {"type": "null"},
        "contextCard": {"type": "null"},
        "effect": {"type": "null"},
    })
    source = _strict({
        "select": {"oneOf": [{"type": "null"}, engine_select]},
        "deck_cards": {"type": "null"},
        "context_card": {"type": "null"},
        "effect_card": {"type": "null"},
        "option_card_refs": {
            "type": "array",
            "maxItems": 256,
            "items": {"oneOf": [{"type": "null"}, {"type": "string", "pattern": "^card:[a-z0-9_-]+$"}]},
        },
        "turn_action_count": nonnegative,
    })
    window_select = _strict({
        "type": nonnegative,
        "context": nonnegative,
        "minCount": nonnegative,
        "maxCount": nonnegative,
        "remainDamageCounter": nonnegative,
        "remainEnergyCost": nonnegative,
        "option": {"type": "array", "maxItems": 256, "items": window_option},
        "deck": {"type": "null"},
        "contextCard": {"type": "null"},
        "effect": {"type": "null"},
    })
    binding_audit = _strict({
        "binding_profile": {"const": PROFILE_ID},
        "binding_version": {"type": "integer", "minimum": 1, "maximum": SAFE_MAX},
        "snapshot_id": sha,
        "window_id": sha,
        "public_observation_hash": sha,
        "chooser_player_index": {"type": "integer", "enum": [0, 1]},
        "option_count": nonnegative,
        "option_fingerprints": {"type": "array", "maxItems": 256, "items": sha},
        "authority": {"const": "godot_option_binding_shadow"},
        "authoritative": {"const": False},
    })
    resolution_audit = _strict({
        "binding_profile": {"const": PROFILE_ID},
        "binding_version": {"type": "integer", "minimum": 1, "maximum": SAFE_MAX},
        "snapshot_id": sha,
        "window_id": sha,
        "option_index": nonnegative,
        "fingerprint_hash": sha,
        "authority": {"const": "godot_option_resolution_shadow"},
        "authoritative": {"const": False},
    })
    bind_result = _strict({
        "accepted": {"type": "boolean"},
        "error_code": {"type": "string", "enum": ERROR_CODES},
        "audit": {"oneOf": [{"type": "null"}, binding_audit]},
    })
    resolution_result = _strict({
        "accepted": {"type": "boolean"},
        "error_code": {"type": "string", "enum": ERROR_CODES},
        "audit": {"oneOf": [{"type": "null"}, resolution_audit]},
    })
    fixture = _strict({
        "match_generation": {"type": "integer", "minimum": 1, "maximum": SAFE_MAX},
        "decision_generation": {"type": "integer", "minimum": 1, "maximum": SAFE_MAX},
        "chooser_player_index": {"type": "integer", "enum": [0, 1]},
        "source": source,
        "window": _strict({
            "select": window_select,
            "public_observation_hash": sha,
            "public_hash_authority": {"const": "conformance_fixture"},
            "chooser_player_index": {"type": "integer", "enum": [0, 1]},
        }),
        "callback_binding_hash": sha,
        "private_commands": {"type": "array", "maxItems": 256, "items": {"type": "string", "pattern": "^command:[a-z0-9_-]+$"}},
        "private_object_refs": {
            "type": "array",
            "maxItems": 256,
            "items": {
                "type": "array",
                "maxItems": 16,
                "items": {"type": "string", "pattern": "^(object|card):[a-z0-9_-]+$"},
            },
        },
        "expected_snapshot_id": sha,
        "expected_window_id": sha,
        "expected_option_fingerprints": {"type": "array", "maxItems": 256, "items": sha},
    })
    bind_case = _strict({
        "id": {"type": "string", "pattern": "^[a-z0-9][a-z0-9_-]*$"},
        "fault": {"type": "string", "enum": [
            "none", "window_option_reorder", "window_payload_change", "window_chooser_change",
            "callback_lowercase", "command_count", "command_primitive", "reference_count",
            "reference_primitive", "source_mutation", "null_window",
        ]},
        "expected": bind_result,
    })
    resolve_case = _strict({
        "id": {"type": "string", "pattern": "^[a-z0-9][a-z0-9_-]*$"},
        "fault": {"type": "string", "enum": [
            "none", "callback_change", "source_mutation", "equivalent_window_copy",
            "bool_index", "negative_index", "out_of_range",
        ]},
        "option_index": {"oneOf": [safe_int, {"type": "boolean"}]},
        "expected": resolution_result,
    })
    vector_root = _strict({
        "schema_version": {"const": 1},
        "profile_id": {"const": PROFILE_ID},
        "host_token_encoding": _strict({
            "card_reference": {"const": "card:<fixture-label>"},
            "command_reference": {"const": "command:<fixture-label>"},
            "object_reference": {"const": "object:<fixture-label>"},
            "null_reference": {"type": "null"},
        }),
        "fixture": fixture,
        "bind_cases": {"type": "array", "minItems": 10, "items": bind_case},
        "resolve_cases": {"type": "array", "minItems": 7, "items": resolve_case},
        "transition_cases": {
            "type": "array",
            "minItems": 3,
            "items": _strict({
                "id": {"type": "string", "pattern": "^[a-z0-9][a-z0-9_-]*$"},
                "scenario": {"type": "string", "enum": ["new_snapshot", "accepted_replacement", "rejected_replacement"]},
                "expected_old_error": {"type": "string", "enum": ERROR_CODES},
            }),
        },
    })
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/godot_option_binding.schema.json",
        "title": "PtcgDAP current-window Host-private GodotOptionBinding shadow contract",
        "$defs": {
            "bindingAudit": binding_audit,
            "bindingResult": bind_result,
            "resolutionAudit": resolution_audit,
            "resolutionResult": resolution_result,
            "conformanceVectors": vector_root,
        },
        "oneOf": [
            {"$ref": "#/$defs/bindingAudit"},
            {"$ref": "#/$defs/bindingResult"},
            {"$ref": "#/$defs/resolutionAudit"},
            {"$ref": "#/$defs/resolutionResult"},
            {"$ref": "#/$defs/conformanceVectors"},
        ],
    }


def build_profile() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "mode": "shadow_host_private_option_binding_only",
        "parents": {
            "p3_wp1_manifest_canonical_sha256": PARENT_MANIFEST_CANONICAL,
            "decision_port_bundle_canonical_sha256": DECISION_PORT_BUNDLE_CANONICAL,
            "selection_bundle_canonical_sha256": SELECTION_BUNDLE_CANONICAL,
            "source_lock_canonical_sha256": SOURCE_LOCK_CANONICAL,
        },
        "supported_source_option_types": [3, 7, 13, 14, 15],
        "identity_rules": {
            "current_snapshot": "exact current EngineDecisionSnapshot owned by the exact EngineDecisionPort",
            "current_window": "exact current sealed CabtSelectionWindow instance; equivalent serialized or separately rebuilt windows are not authority",
            "position": "source and window option arrays remain position aligned and are never sorted",
            "source_window_match": "chooser, select type/context/cardinality/remain counters, option count/type and PLAY index agree; projected identity fields remain owned by the P2 projector",
            "fingerprints": "the exact current window fingerprint at each position is copied into audit and revalidated at resolution",
        },
        "private_binding_rules": {
            "callback_binding_hash": "exact uppercase SHA-256 retained only inside the owner; never serialized",
            "commands": "one exact weak-referenceable command object per current option position",
            "object_refs": "zero to sixteen exact weak-referenceable private engine objects per option position",
            "storage": "weak exact-object references only; no Godot instance ID, display name or public DTO authority",
            "liveness": "any released command or object reference invalidates resolution for that position",
        },
        "generation_rules": {
            "binding_version": "positive exact safe integer, monotonically increasing after each accepted replacement",
            "accepted_replacement": "atomically installs the new binding and invalidates the old binding",
            "rejected_replacement": "does not disturb the last accepted binding",
            "snapshot_replacement": "a newer port snapshot invalidates the previous binding even without a new bind call",
        },
        "limits": {
            "max_options": 256,
            "max_private_refs_per_option": 16,
            "max_total_private_refs": 4096,
        },
        "error_codes": ERROR_CODES,
        "serialization_contract": {
            "binding_audit_fields": [
                "binding_profile", "binding_version", "snapshot_id", "window_id",
                "public_observation_hash", "chooser_player_index", "option_count",
                "option_fingerprints", "authority", "authoritative",
            ],
            "resolution_audit_fields": [
                "binding_profile", "binding_version", "snapshot_id", "window_id",
                "option_index", "fingerprint_hash", "authority", "authoritative",
            ],
            "forbidden_fields": [
                "callback_binding_hash", "private_engine_command", "private_object_refs",
                "object_id", "instance_id", "ticket", "consume", "commit", "execute",
                "_pending_choice", "_dialog_data",
            ],
            "dto_only": True,
            "consumer_rule": "serialized/schema-valid dictionaries and result objects grant no ticket, commit or execution authority; future execution must revalidate current context and mint a separate one-use ticket",
        },
        "threat_boundary": {
            "ordinary_mutation": "fields, arrays, dictionaries, owner state and weak-reference release fail closed in tests",
            "same_process_reflection": "malicious same-process reflection is not a security sandbox and is outside this shadow slice",
        },
        "conformance_faults": {
            "bind": [
                "none", "window_option_reorder", "window_payload_change", "window_chooser_change",
                "callback_lowercase", "command_count", "command_primitive", "reference_count",
                "reference_primitive", "source_mutation", "null_window",
            ],
            "resolve": [
                "none", "callback_change", "source_mutation", "equivalent_window_copy",
                "bool_index", "negative_index", "out_of_range",
            ],
        },
    }


def _engine_select(options: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "type": 0,
        "context": 0,
        "minCount": 1,
        "maxCount": 2,
        "remainDamageCounter": 0,
        "remainEnergyCost": 0,
        "option": options,
        "deck": None,
        "contextCard": None,
        "effect": None,
    }


def _window_select(options: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "type": 0,
        "context": 0,
        "minCount": 1,
        "maxCount": 2,
        "remainDamageCounter": 0,
        "remainEnergyCost": 0,
        "option": options,
        "deck": None,
        "contextCard": None,
        "effect": None,
    }


def _materialize_source(value: Any, refs: dict[str, _FixtureRef]) -> Any:
    if type(value) is str and value.startswith("card:"):
        return refs.setdefault(value, _FixtureRef())
    if type(value) is list:
        return [_materialize_source(item, refs) for item in value]
    if type(value) is dict:
        return {key: _materialize_source(item, refs) for key, item in value.items()}
    return value


def _fixture() -> dict[str, Any]:
    source = {
        "select": _engine_select([
            {"type": 3},
            {"type": 7, "index": 4},
            {"type": 13, "local_attack_index": 0},
            {"type": 14},
            {"type": 15},
        ]),
        "deck_cards": None,
        "context_card": None,
        "effect_card": None,
        "option_card_refs": [None, None, None, None, "card:a"],
        "turn_action_count": 7,
    }
    window_input = {
        "select": _window_select([
            {"type": 3, "area": 0, "index": 2, "playerIndex": 0},
            {"type": 7, "index": 4},
            {"type": 13, "attackId": 101},
            {"type": 14},
            {"type": 15, "cardId": 7, "serial": 41},
        ]),
        "public_observation_hash": "1" * 64,
        "public_hash_authority": "conformance_fixture",
        "chooser_player_index": 0,
    }
    refs: dict[str, _FixtureRef] = {}
    port = EngineDecisionPort(11)
    published = port.publish(_materialize_source(source, refs), 23, 0)
    if not published.accepted or published.snapshot is None:
        raise RuntimeError(f"parent decision fixture rejected: {published.error_code}")
    built = CabtSelectionWindow.build(
        window_input["select"],
        public_observation_hash=window_input["public_observation_hash"],
        public_hash_authority=window_input["public_hash_authority"],
        chooser_player_index=window_input["chooser_player_index"],
    )
    if not built.accepted or built.window is None or not built.validate_integrity():
        raise RuntimeError("parent window fixture rejected")
    return {
        "match_generation": 11,
        "decision_generation": 23,
        "chooser_player_index": 0,
        "source": source,
        "window": window_input,
        "callback_binding_hash": "A" * 64,
        "private_commands": [f"command:{index}" for index in range(5)],
        "private_object_refs": [
            ["object:card-choice"],
            [],
            ["object:attack", "object:energy"],
            [],
            ["card:a"],
        ],
        "expected_snapshot_id": published.snapshot.snapshot_id,
        "expected_window_id": built.window.window_id,
        "expected_option_fingerprints": list(built.window.option_fingerprints),
    }


def _binding_audit(fixture: dict[str, Any]) -> dict[str, Any]:
    return {
        "binding_profile": PROFILE_ID,
        "binding_version": 1,
        "snapshot_id": fixture["expected_snapshot_id"],
        "window_id": fixture["expected_window_id"],
        "public_observation_hash": fixture["window"]["public_observation_hash"],
        "chooser_player_index": fixture["chooser_player_index"],
        "option_count": len(fixture["private_commands"]),
        "option_fingerprints": fixture["expected_option_fingerprints"],
        "authority": "godot_option_binding_shadow",
        "authoritative": False,
    }


def _resolution_audit(fixture: dict[str, Any], index: int) -> dict[str, Any]:
    return {
        "binding_profile": PROFILE_ID,
        "binding_version": 1,
        "snapshot_id": fixture["expected_snapshot_id"],
        "window_id": fixture["expected_window_id"],
        "option_index": index,
        "fingerprint_hash": fixture["expected_option_fingerprints"][index],
        "authority": "godot_option_resolution_shadow",
        "authoritative": False,
    }


def build_vectors() -> dict[str, Any]:
    fixture = _fixture()
    accepted = {"accepted": True, "error_code": "", "audit": _binding_audit(fixture)}
    bind_cases = [
        {"id": "valid-mixed-order", "fault": "none", "expected": accepted},
        {"id": "window-option-reorder", "fault": "window_option_reorder", "expected": {"accepted": False, "error_code": "window_mismatch", "audit": None}},
        {"id": "window-payload-change", "fault": "window_payload_change", "expected": {"accepted": False, "error_code": "window_mismatch", "audit": None}},
        {"id": "window-chooser-change", "fault": "window_chooser_change", "expected": {"accepted": False, "error_code": "window_mismatch", "audit": None}},
        {"id": "callback-lowercase", "fault": "callback_lowercase", "expected": {"accepted": False, "error_code": "invalid_callback_binding_hash", "audit": None}},
        {"id": "command-count", "fault": "command_count", "expected": {"accepted": False, "error_code": "invalid_private_commands", "audit": None}},
        {"id": "command-primitive", "fault": "command_primitive", "expected": {"accepted": False, "error_code": "invalid_private_commands", "audit": None}},
        {"id": "reference-count", "fault": "reference_count", "expected": {"accepted": False, "error_code": "invalid_private_object_refs", "audit": None}},
        {"id": "reference-primitive", "fault": "reference_primitive", "expected": {"accepted": False, "error_code": "invalid_private_object_refs", "audit": None}},
        {"id": "source-mutation", "fault": "source_mutation", "expected": {"accepted": False, "error_code": "source_mutated", "audit": None}},
        {"id": "null-window", "fault": "null_window", "expected": {"accepted": False, "error_code": "invalid_window", "audit": None}},
    ]
    resolve_cases = [
        {"id": "resolve-first", "fault": "none", "option_index": 0, "expected": {"accepted": True, "error_code": "", "audit": _resolution_audit(fixture, 0)}},
        {"id": "resolve-card", "fault": "none", "option_index": 4, "expected": {"accepted": True, "error_code": "", "audit": _resolution_audit(fixture, 4)}},
        {"id": "resolve-callback-drift", "fault": "callback_change", "option_index": 0, "expected": {"accepted": False, "error_code": "binding_not_current", "audit": None}},
        {"id": "resolve-source-drift", "fault": "source_mutation", "option_index": 0, "expected": {"accepted": False, "error_code": "source_mutated", "audit": None}},
        {"id": "resolve-equivalent-window-copy", "fault": "equivalent_window_copy", "option_index": 0, "expected": {"accepted": False, "error_code": "window_mismatch", "audit": None}},
        {"id": "resolve-bool-index", "fault": "bool_index", "option_index": True, "expected": {"accepted": False, "error_code": "option_index_invalid", "audit": None}},
        {"id": "resolve-negative-index", "fault": "negative_index", "option_index": -1, "expected": {"accepted": False, "error_code": "option_index_invalid", "audit": None}},
        {"id": "resolve-out-of-range", "fault": "out_of_range", "option_index": 5, "expected": {"accepted": False, "error_code": "option_index_invalid", "audit": None}},
    ]
    return {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "host_token_encoding": {
            "card_reference": "card:<fixture-label>",
            "command_reference": "command:<fixture-label>",
            "object_reference": "object:<fixture-label>",
            "null_reference": None,
        },
        "fixture": fixture,
        "bind_cases": bind_cases,
        "resolve_cases": resolve_cases,
        "transition_cases": [
            {"id": "new-snapshot-invalidates", "scenario": "new_snapshot", "expected_old_error": "snapshot_not_current"},
            {"id": "accepted-replacement-invalidates", "scenario": "accepted_replacement", "expected_old_error": "binding_not_current"},
            {"id": "rejected-replacement-is-atomic", "scenario": "rejected_replacement", "expected_old_error": ""},
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
            "work_package": "P3-WP1",
            "manifest_canonical_sha256": PARENT_MANIFEST_CANONICAL,
            "decision_port_bundle_canonical_sha256": DECISION_PORT_BUNDLE_CANONICAL,
            "selection_bundle_canonical_sha256": SELECTION_BUNDLE_CANONICAL,
            "source_lock_canonical_sha256": SOURCE_LOCK_CANONICAL,
        },
        "artifacts": [
            {"id": "schema", "path": "contracts/ptcgdap/godot_option_binding.schema.json", "canonical_sha256": _canonical_hash(schema)},
            {"id": "profile", "path": "contracts/ptcgdap/godot_option_binding_profile.json", "canonical_sha256": _canonical_hash(profile)},
            {"id": "vectors", "path": "contracts/ptcgdap/godot_option_binding_conformance_vectors.json", "canonical_sha256": _canonical_hash(vectors)},
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
