from __future__ import annotations

import argparse
import copy
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"
P1_BUNDLE = CONTRACT_ROOT / "cabt_contract_bundle.json"
TYPED_PROFILE = CONTRACT_ROOT / "cabt_typed_view_profile.json"

OUTPUTS = {
    "schema": CONTRACT_ROOT / "cabt_public_observation.schema.json",
    "profile": CONTRACT_ROOT / "cabt_public_firewall_profile.json",
    "vectors": CONTRACT_ROOT / "cabt_public_firewall_conformance_vectors.json",
    "bundle": CONTRACT_ROOT / "cabt_public_firewall_bundle.json",
}

PROFILE_ID = "cabt_public_firewall_profile_v1"
BUNDLE_ID = "ptcgdap-public-firewall-p2-wp3-v1"
SOURCE_LOCK_ID = "ptcgdap-source-lock-2026-08-09-p1wp1"
PARENT_BUNDLE_ID = "ptcgdap-cabt-contract-p1-wp3-v1"
PARENT_BUNDLE_SHA256 = "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
TREE_HASH_PROFILE_ID = "cabt_tree_hash_v1"
MAX_SAFE_INTEGER = 9_007_199_254_740_991

ERROR_CODES = [
    "invalid_envelope",
    "envelope_not_policy_eligible",
    "source_contract_mismatch",
    "firewall_contract_error",
    "initial_shape_mismatch",
    "invalid_your_index",
    "invalid_player_count",
    "own_hand_not_visible",
    "opponent_hand_exposed",
    "prize_identity_exposed",
    "own_active_concealed",
    "unauthorized_select_deck",
    "opponent_draw_identity_exposed",
    "public_projection_limit",
    "public_hash_error",
    "result_integrity_invalid",
]


def _bootstrap() -> None:
    root_text = str(ROOT)
    if root_text not in sys.path:
        sys.path.insert(0, root_text)


def _strict_load(path: Path) -> Any:
    _bootstrap()
    from scripts.ai.ptcgdap.source_lock import load_json_strict

    return load_json_strict(path)


def _canonical_hash(value: Any) -> str:
    _bootstrap()
    from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, sha256_bytes

    return sha256_bytes(canonical_json_v1_bytes(value))


def _json_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def _safe_integer_schema() -> dict[str, Any]:
    return {
        "type": "integer",
        "minimum": -MAX_SAFE_INTEGER,
        "maximum": MAX_SAFE_INTEGER,
    }


def _nullable(schema: dict[str, Any], enabled: bool) -> dict[str, Any]:
    if not enabled:
        return schema
    return {"anyOf": [schema, {"type": "null"}]}


def _descriptor_schema(descriptor: dict[str, Any]) -> dict[str, Any]:
    kind = descriptor["kind"]
    if kind == "shape":
        base: dict[str, Any] = {"$ref": f"#/$defs/{descriptor['shape']}"}
    elif kind == "array":
        base = {
            "type": "array",
            "items": _descriptor_schema(descriptor["items"]),
        }
    elif kind == "integer":
        base = _safe_integer_schema()
    elif kind == "number":
        base = {"type": "number"}
    elif kind == "boolean":
        base = {"type": "boolean"}
    elif kind == "string":
        base = {"type": "string"}
    else:
        raise ValueError(f"unknown descriptor kind: {kind}")
    return _nullable(base, bool(descriptor.get("nullable", False)))


def _shape_schema(profile: dict[str, Any], shape_name: str) -> dict[str, Any]:
    descriptor_by_name = {
        descriptor["name"]: descriptor
        for descriptor in profile["shapes"][shape_name]["fields"]
    }
    sparse_root = None
    if shape_name == "Option":
        sparse_root = profile["option_shapes"]
    elif shape_name == "Log":
        sparse_root = profile["log_shapes"]
    if sparse_root is not None:
        variants = []
        for raw_type_text, names in sorted(sparse_root.items(), key=lambda item: int(item[0])):
            properties = {}
            required = []
            for name in names:
                descriptor = descriptor_by_name[name]
                properties[name] = _descriptor_schema(descriptor)
                if bool(descriptor.get("required", False)):
                    required.append(name)
            properties["type"] = {"const": int(raw_type_text)}
            if "type" not in required:
                required.append("type")
            variants.append(
                {
                    "type": "object",
                    "additionalProperties": False,
                    "properties": properties,
                    "required": required,
                }
            )
        return {"oneOf": variants}

    properties = {
        name: _descriptor_schema(descriptor)
        for name, descriptor in descriptor_by_name.items()
    }
    required = [
        name
        for name, descriptor in descriptor_by_name.items()
        if bool(descriptor.get("required", False))
    ]
    return {
        "type": "object",
        "additionalProperties": False,
        "properties": properties,
        "required": required,
    }


def _known_pointer_pattern(profile: dict[str, Any]) -> str:
    names = {"select", "logs", "current", "step", "remainingOverageTime"}
    for shape in profile["shapes"].values():
        for descriptor in shape["fields"]:
            names.add(descriptor["name"])
    escaped = "|".join(sorted(names, key=lambda value: (len(value), value)))
    return rf"^(?:$|/(?:{escaped})(?:/(?:0|[1-9][0-9]*|{escaped}))*)$"


def build_schema(typed_profile: dict[str, Any]) -> dict[str, Any]:
    pointer_pattern = _known_pointer_pattern(typed_profile)
    definitions = {
        name: _shape_schema(typed_profile, name)
        for name in (
            "Card",
            "Pokemon",
            "PlayerState",
            "State",
            "Option",
            "SelectData",
            "Log",
        )
    }
    definitions["PublicObservation"] = {
        "type": "object",
        "additionalProperties": False,
        "properties": {
            "select": {"anyOf": [{"$ref": "#/$defs/SelectData"}, {"type": "null"}]},
            "logs": {"type": "array", "items": {"$ref": "#/$defs/Log"}},
            "current": {"anyOf": [{"$ref": "#/$defs/State"}, {"type": "null"}]},
            "step": _nullable(_safe_integer_schema(), True),
            "remainingOverageTime": {
                "anyOf": [{"type": "number"}, {"type": "null"}]
            },
        },
        "required": ["select", "logs", "current"],
    }
    definitions["ProvenanceRecord"] = {
        "type": "object",
        "additionalProperties": False,
        "properties": {
            "output_pointer": {"type": "string", "pattern": pointer_pattern},
            "source_pointer": {"type": "string", "pattern": pointer_pattern},
            "visibility": {
                "enum": [
                    "official_public",
                    "acting_player_visible",
                    "authorized_window_visible",
                    "concealed_placeholder",
                    "framework_public",
                ]
            },
            "authority": {"const": "official_cabt_wire"},
            "transform": {"enum": ["exact_copy", "framework_name_restore"]},
        },
        "required": [
            "output_pointer",
            "source_pointer",
            "visibility",
            "authority",
            "transform",
        ],
    }
    definitions["FirewallIssue"] = {
        "type": "object",
        "additionalProperties": False,
        "properties": {
            "code": {"enum": ERROR_CODES},
            "pointer": {"type": "string", "pattern": pointer_pattern},
            "severity": {"const": "error"},
        },
        "required": ["code", "pointer", "severity"],
    }
    common_properties = {
        "schema_version": {"const": 1},
        "profile_id": {"const": PROFILE_ID},
        "source_contract_hash": {
            "const": PARENT_BUNDLE_SHA256,
        },
        "firewall_contract_hash": {
            "type": "string",
            "pattern": "^[0-9A-F]{64}$",
        },
    }
    accepted_properties = {
        **common_properties,
        "status": {"const": "accepted"},
        "public_observation": {"$ref": "#/$defs/PublicObservation"},
        "public_observation_hash": {
            "type": "string",
            "pattern": "^[0-9A-F]{64}$",
        },
        "provenance": {
            "type": "array",
            "minItems": 1,
            "items": {"$ref": "#/$defs/ProvenanceRecord"},
        },
        "issues": {"type": "array", "maxItems": 0},
    }
    rejected_properties = {
        **common_properties,
        "status": {"const": "rejected"},
        "public_observation": {"type": "null"},
        "public_observation_hash": {"type": "null"},
        "provenance": {"type": "array", "maxItems": 0},
        "issues": {
            "type": "array",
            "minItems": 1,
            "items": {"$ref": "#/$defs/FirewallIssue"},
        },
    }
    required = [
        "schema_version",
        "profile_id",
        "source_contract_hash",
        "firewall_contract_hash",
        "status",
        "public_observation",
        "public_observation_hash",
        "provenance",
        "issues",
    ]
    definitions["AcceptedResult"] = {
        "type": "object",
        "additionalProperties": False,
        "properties": accepted_properties,
        "required": required,
    }
    definitions["RejectedResult"] = {
        "type": "object",
        "additionalProperties": False,
        "properties": rejected_properties,
        "required": required,
    }
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/cabt_public_observation.schema.json",
        "title": "PTCGDAP P2-WP3 Public Observation Firewall Result",
        "oneOf": [
            {"$ref": "#/$defs/AcceptedResult"},
            {"$ref": "#/$defs/RejectedResult"},
        ],
        "$defs": definitions,
    }


def build_profile(typed_profile: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "source_lock_id": SOURCE_LOCK_ID,
        "parent_contract": {
            "id": PARENT_BUNDLE_ID,
            "canonical_sha256": PARENT_BUNDLE_SHA256,
            "typed_view_profile_id": typed_profile["profile_id"],
        },
        "hash_contract": {
            "profile_id": TREE_HASH_PROFILE_ID,
            "domain": "public_observation",
            "input": "accepted independent allow-list tree only",
            "forbidden_inputs": [
                "raw_payload",
                "known_view object by reference",
                "token_free callback",
                "raw_private_hash",
                "token_free_callback_hash",
                "search capability or presence marker",
            ],
        },
        "projection": {
            "required_root_fields": ["select", "logs", "current"],
            "optional_framework_fields": ["step", "remainingOverageTime"],
            "known_view_sources": {
                "select": "/select",
                "logs": "/logs",
                "current": "/current",
            },
            "framework_sources": {
                "step": {"view_name": "step", "source_pointer": "/step"},
                "remainingOverageTime": {
                    "view_name": "remaining_overage_time",
                    "source_pointer": "/remainingOverageTime",
                },
            },
            "unknown_field_policy": "quarantine_and_omit_key_pointer_and_value",
            "positive_allow_list_only": True,
        },
        "visibility_rules": {
            "acting_player_index": "current.yourIndex must be exact integer 0 or 1",
            "players": "current.players must contain exactly two entries",
            "hand": "acting player's hand is a visible Card array; opponent hand is exactly null",
            "prize": "both prize arrays contain null placeholders only",
            "active": "acting player's active array may not contain a concealed null; opponent active may contain null",
            "looking": "official wire value is copied as acting-seat-visible; null elements remain concealed placeholders",
            "select_deck": "non-null select.deck is authorized only when select.type is exact CARD(1)",
            "logs": "opponent DRAW(4) with identity is forbidden; official hidden draw must be DRAW_REVERSE(5)",
            "initial": "select null requires current null and empty logs; regular callbacks require non-null select and current",
        },
        "provenance": {
            "record_every_output_node": True,
            "authority": "official_cabt_wire",
            "visibility_values": [
                "official_public",
                "acting_player_visible",
                "authorized_window_visible",
                "concealed_placeholder",
                "framework_public",
            ],
            "unknown_key_names_allowed": False,
            "private_hashes_allowed": False,
            "serialized_result_authority": "audit_and_conformance_only",
            "consumer_rule": "validate the exact owner result against the exact current envelope; a copied dictionary, schema pass or hash string grants no authority",
        },
        "result_contract": {
            "accepted": {
                "public_observation": "strict allow-list object",
                "public_observation_hash": "uppercase SHA-256",
                "provenance": "non-empty known-pointer records",
                "issues": [],
            },
            "rejected": {
                "public_observation": None,
                "public_observation_hash": None,
                "provenance": [],
                "issues": "one or more closed non-echoing errors",
            },
            "error_codes": ERROR_CODES,
            "ordinary_mutation": "fail closed; public serialization uses the sealed snapshot only while integrity is valid",
            "reflection_boundary": "not a hostile same-process sandbox; no live consumer exists in P2-WP3",
        },
        "limits": {
            "max_provenance_records": 200000,
            "max_public_tree_depth": 128,
            "max_public_tree_nodes": 1000000,
        },
    }


def _card(card_id: int, serial: int, player_index: int) -> dict[str, Any]:
    return {"id": card_id, "serial": serial, "playerIndex": player_index}


def _pokemon(card_id: int, serial: int, player_index: int) -> dict[str, Any]:
    return {
        "id": card_id,
        "serial": serial,
        "playerIndex": player_index,
        "hp": 70,
        "maxHp": 70,
        "appearThisTurn": False,
        "energies": [],
        "energyCards": [],
        "tools": [],
        "preEvolution": [],
    }


def _player(player_index: int, hand: Any) -> dict[str, Any]:
    return {
        "active": [_pokemon(100 + player_index, 10 + player_index, player_index)],
        "bench": [],
        "benchMax": 5,
        "deckCount": 50,
        "discard": [],
        "prize": [None, None, None, None, None, None],
        "handCount": 1 if isinstance(hand, list) else 3,
        "hand": hand,
        "poisoned": False,
        "burned": False,
        "asleep": False,
        "paralyzed": False,
        "confused": False,
    }


def _regular_observation() -> dict[str, Any]:
    return {
        "select": {
            "type": 9,
            "context": 41,
            "minCount": 1,
            "maxCount": 1,
            "remainDamageCounter": 0,
            "remainEnergyCost": 0,
            "option": [{"type": 1}, {"type": 2}],
            "deck": None,
            "contextCard": None,
            "effect": None,
        },
        "logs": [],
        "current": {
            "turn": 0,
            "turnActionCount": 1,
            "yourIndex": 0,
            "firstPlayer": -1,
            "supporterPlayed": False,
            "stadiumPlayed": False,
            "energyAttached": False,
            "retreated": False,
            "result": -1,
            "stadium": [],
            "looking": None,
            "players": [
                _player(0, [_card(7, 30, 0)]),
                _player(1, None),
            ],
        },
        "search_begin_input": None,
        "step": 1,
        "remainingOverageTime": 599,
    }


def _initial_observation() -> dict[str, Any]:
    return {
        "select": None,
        "logs": [],
        "current": None,
        "search_begin_input": None,
        "step": 0,
        "remainingOverageTime": 600,
    }


def _deck_observation() -> dict[str, Any]:
    value = _regular_observation()
    value["select"] = {
        "type": 1,
        "context": 7,
        "minCount": 0,
        "maxCount": 1,
        "remainDamageCounter": 0,
        "remainEnergyCost": 0,
        "option": [{"type": 3, "area": 1, "index": 0, "playerIndex": 0}],
        "deck": [_card(104, 31, 0)],
        "contextCard": None,
        "effect": _card(1097, 32, 0),
    }
    return value


def _mutate(root: Any, mutation: dict[str, Any]) -> None:
    operation = mutation["op"]
    path = mutation["path"]
    parent = root
    for segment in path[:-1]:
        parent = parent[segment]
    key = path[-1] if path else None
    if operation == "set":
        parent[key] = copy.deepcopy(mutation["value"])
    elif operation == "delete":
        del parent[key]
    elif operation == "append":
        parent[key].append(copy.deepcopy(mutation["value"]))
    else:
        raise ValueError(f"unknown mutation operation: {operation}")


def _reference_projection(raw: dict[str, Any]) -> dict[str, Any]:
    _bootstrap()
    from scripts.ai.ptcgdap.cabt_envelope import parse_raw_cabt_envelope

    result = parse_raw_cabt_envelope(raw, contract_root=CONTRACT_ROOT)
    if not result.policy_eligible or result.envelope is None:
        raise ValueError("reference projection requires a policy-eligible envelope")
    envelope = result.envelope
    tree = {
        "select": envelope.known_view["select"],
        "logs": envelope.known_view["logs"],
        "current": envelope.known_view["current"],
    }
    presence = envelope.field_presence
    framework = envelope.framework
    if presence.get("/step") != "missing":
        tree["step"] = framework["step"]
    if presence.get("/remainingOverageTime") != "missing":
        tree["remainingOverageTime"] = framework["remaining_overage_time"]
    return tree


def _vector_cases() -> list[dict[str, Any]]:
    return [
        {"id": "initial-accepted", "base": "initial", "mutations": [], "status": "accepted"},
        {"id": "regular-accepted", "base": "regular", "mutations": [], "status": "accepted"},
        {"id": "authorized-deck-accepted", "base": "deck", "mutations": [], "status": "accepted"},
        {
            "id": "search-token-omitted",
            "base": "regular",
            "mutations": [{"op": "set", "path": ["search_begin_input"], "value": "PRIVATE_SEARCH_SENTINEL"}],
            "status": "accepted",
        },
        {
            "id": "unknown-private-fields-quarantined",
            "base": "regular",
            "mutations": [
                {"op": "set", "path": ["private_rng_state"], "value": "PRIVATE_RNG_SENTINEL"},
                {"op": "set", "path": ["oracle_label"], "value": "PRIVATE_ORACLE_SENTINEL"},
                {"op": "set", "path": ["current", "players", 0, "deck"], "value": [_card(1259, 99, 0)]},
            ],
            "status": "accepted",
        },
        {
            "id": "unknown-key-name-quarantined",
            "base": "regular",
            "mutations": [{"op": "set", "path": ["PRIVATE_KEY_SENTINEL"], "value": {"nested": "PRIVATE_VALUE_SENTINEL"}}],
            "status": "accepted",
        },
        {
            "id": "opponent-hand-exposed",
            "base": "regular",
            "mutations": [{"op": "set", "path": ["current", "players", 1, "hand"], "value": [_card(646, 91, 1)]}],
            "status": "rejected",
            "issue_code": "opponent_hand_exposed",
        },
        {
            "id": "own-prize-exposed",
            "base": "regular",
            "mutations": [{"op": "set", "path": ["current", "players", 0, "prize", 0], "value": _card(647, 92, 0)}],
            "status": "rejected",
            "issue_code": "prize_identity_exposed",
        },
        {
            "id": "opponent-prize-exposed",
            "base": "regular",
            "mutations": [{"op": "set", "path": ["current", "players", 1, "prize", 0], "value": _card(648, 93, 1)}],
            "status": "rejected",
            "issue_code": "prize_identity_exposed",
        },
        {
            "id": "own-active-concealed",
            "base": "regular",
            "mutations": [{"op": "set", "path": ["current", "players", 0, "active", 0], "value": None}],
            "status": "rejected",
            "issue_code": "own_active_concealed",
        },
        {
            "id": "opponent-active-concealed-accepted",
            "base": "regular",
            "mutations": [{"op": "set", "path": ["current", "players", 1, "active", 0], "value": None}],
            "status": "accepted",
        },
        {
            "id": "unauthorized-select-deck",
            "base": "regular",
            "mutations": [{"op": "set", "path": ["select", "deck"], "value": [_card(104, 31, 0)]}],
            "status": "rejected",
            "issue_code": "unauthorized_select_deck",
        },
        {
            "id": "opponent-draw-identity-exposed",
            "base": "regular",
            "mutations": [{"op": "append", "path": ["logs"], "value": {"type": 4, "playerIndex": 1, "cardId": 646, "serial": 91}}],
            "status": "rejected",
            "issue_code": "opponent_draw_identity_exposed",
        },
        {
            "id": "opponent-draw-reverse-accepted",
            "base": "regular",
            "mutations": [{"op": "append", "path": ["logs"], "value": {"type": 5, "playerIndex": 1}}],
            "status": "accepted",
        },
        {
            "id": "unknown-select-enum",
            "base": "regular",
            "mutations": [{"op": "set", "path": ["select", "type"], "value": 999}],
            "status": "rejected",
            "issue_code": "envelope_not_policy_eligible",
        },
        {
            "id": "invalid-your-index-bool",
            "base": "regular",
            "mutations": [{"op": "set", "path": ["current", "yourIndex"], "value": True}],
            "status": "rejected",
            "issue_code": "envelope_not_policy_eligible",
        },
        {
            "id": "invalid-player-count",
            "base": "regular",
            "mutations": [{"op": "set", "path": ["current", "players"], "value": [_player(0, [_card(7, 30, 0)])]}],
            "status": "rejected",
            "issue_code": "invalid_player_count",
        },
        {
            "id": "own-hand-not-visible",
            "base": "regular",
            "mutations": [{"op": "set", "path": ["current", "players", 0, "hand"], "value": None}],
            "status": "rejected",
            "issue_code": "own_hand_not_visible",
        },
        {
            "id": "initial-current-mismatch",
            "base": "initial",
            "mutations": [{"op": "set", "path": ["current"], "value": _regular_observation()["current"]}],
            "status": "rejected",
            "issue_code": "initial_shape_mismatch",
        },
        {
            "id": "initial-logs-mismatch",
            "base": "initial",
            "mutations": [{"op": "append", "path": ["logs"], "value": {"type": 2, "playerIndex": 0}}],
            "status": "rejected",
            "issue_code": "initial_shape_mismatch",
        },
        {
            "id": "regular-select-null-mismatch",
            "base": "regular",
            "mutations": [{"op": "set", "path": ["select"], "value": None}],
            "status": "rejected",
            "issue_code": "initial_shape_mismatch",
        },
        {
            "id": "string-name-host-fault",
            "base": "regular",
            "mutations": [{"op": "set", "path": ["current", "players", 0, "hand", 0, "id"], "value": {"host_type": "string_name", "value": "7"}}],
            "status": "rejected",
            "issue_code": "envelope_not_policy_eligible",
        },
        {
            "id": "unsafe-integer-host-fault",
            "base": "regular",
            "mutations": [{"op": "set", "path": ["current", "players", 0, "hand", 0, "id"], "value": {"host_type": "unsafe_integer", "decimal": "9007199254740992"}}],
            "status": "rejected",
            "issue_code": "envelope_not_policy_eligible",
        },
    ]


def _contains_host_descriptor(value: Any) -> bool:
    if isinstance(value, dict):
        if set(value) in ({"host_type", "value"}, {"host_type", "decimal"}) and value.get("host_type") in {"string_name", "unsafe_integer"}:
            return True
        return any(_contains_host_descriptor(child) for child in value.values())
    if isinstance(value, list):
        return any(_contains_host_descriptor(child) for child in value)
    return False


def build_vectors() -> dict[str, Any]:
    _bootstrap()
    from scripts.ai.ptcgdap.cabt_tree_hash import public_observation_hash

    bases = {
        "initial": _initial_observation(),
        "regular": _regular_observation(),
        "deck": _deck_observation(),
    }
    cases = []
    for definition in _vector_cases():
        case = copy.deepcopy(definition)
        if case["status"] == "accepted":
            raw = copy.deepcopy(bases[case["base"]])
            for mutation in case["mutations"]:
                _mutate(raw, mutation)
            if _contains_host_descriptor(raw):
                raise ValueError(f"accepted case contains host descriptor: {case['id']}")
            public_tree = _reference_projection(raw)
            case["expected_public_observation"] = public_tree
            case["expected_public_observation_hash"] = public_observation_hash(public_tree)
            case["expected_issue_code"] = None
        else:
            case["expected_public_observation"] = None
            case["expected_public_observation_hash"] = None
            case["expected_issue_code"] = case.pop("issue_code")
        cases.append(case)
    return {
        "schema_version": 1,
        "vector_set_id": "cabt_public_firewall_conformance_v1",
        "profile_id": PROFILE_ID,
        "source_contract_hash": PARENT_BUNDLE_SHA256,
        "base_observations": bases,
        "cases": cases,
        "sentinel_strings": [
            "PRIVATE_SEARCH_SENTINEL",
            "PRIVATE_RNG_SENTINEL",
            "PRIVATE_ORACLE_SENTINEL",
            "PRIVATE_KEY_SENTINEL",
            "PRIVATE_VALUE_SENTINEL",
        ],
        "consumer_rule": "materialize host_type descriptors before parsing; consume every case and assert exact status, public tree, public hash and first issue code",
    }


def build_bundle(schema: dict[str, Any], profile: dict[str, Any], vectors: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "bundle_id": BUNDLE_ID,
        "source_lock_id": SOURCE_LOCK_ID,
        "parent_contract": {
            "id": PARENT_BUNDLE_ID,
            "path": "contracts/ptcgdap/cabt_contract_bundle.json",
            "canonical_sha256": PARENT_BUNDLE_SHA256,
        },
        "artifacts": [
            {
                "id": "cabt_public_observation_schema_v1",
                "path": "contracts/ptcgdap/cabt_public_observation.schema.json",
                "canonical_sha256": _canonical_hash(schema),
            },
            {
                "id": PROFILE_ID,
                "path": "contracts/ptcgdap/cabt_public_firewall_profile.json",
                "canonical_sha256": _canonical_hash(profile),
            },
            {
                "id": "cabt_public_firewall_conformance_v1",
                "path": "contracts/ptcgdap/cabt_public_firewall_conformance_vectors.json",
                "canonical_sha256": _canonical_hash(vectors),
            },
        ],
        "self_hash_policy": "bundle and bound artifacts do not contain the final bundle hash",
    }


def build_all() -> dict[str, Any]:
    parent = _strict_load(P1_BUNDLE)
    if parent.get("contract_id") != PARENT_BUNDLE_ID or _canonical_hash(parent) != PARENT_BUNDLE_SHA256:
        raise ValueError("P1 contract bundle trust anchor mismatch")
    typed_profile = _strict_load(TYPED_PROFILE)
    schema = build_schema(typed_profile)
    profile = build_profile(typed_profile)
    vectors = build_vectors()
    bundle = build_bundle(schema, profile, vectors)
    return {"schema": schema, "profile": profile, "vectors": vectors, "bundle": bundle}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    built = build_all()
    mismatches = []
    for name, path in OUTPUTS.items():
        expected = _json_bytes(built[name])
        if args.check:
            if not path.is_file() or path.read_bytes() != expected:
                mismatches.append(path.as_posix())
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(expected)
    if mismatches:
        for mismatch in mismatches:
            print(f"mismatch: {mismatch}")
        return 1
    for name, value in built.items():
        print(f"{name}: {_canonical_hash(value)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
