from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys
from typing import Any

_BOOTSTRAP_ROOT = Path(__file__).resolve().parents[2]
if str(_BOOTSTRAP_ROOT) not in sys.path:
    sys.path.insert(0, str(_BOOTSTRAP_ROOT))

from scripts.ai.ptcgdap.cabt_envelope import parse_raw_cabt_envelope
from scripts.ai.ptcgdap.cabt_selection import CabtSelectionWindow
from scripts.ai.ptcgdap.cabt_tree_hash import jcs_canonical_json_bytes
from scripts.ai.ptcgdap.public_observation_firewall import PublicObservationFirewall
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"
SOURCE_LOCK = ROOT / "docs" / "ptcgdap" / "SOURCE_LOCK.json"
ORACLE_ROOT = Path(r"D:\ai\code\ptcgabc")

PROFILE_ID = "ptcgdap-strategic-context-v18-p4-wp1-v1"
DECISION_PROFILE_ID = "ptcgdap-policy-decision-p4-wp1-v1"
BUNDLE_ID = "ptcgdap-strategic-public-contract-p4-wp1-v1"
CONTEXT_PREFIX = b"PTCGDAP\0STRATEGIC_CONTEXT_V18\0"
DECISION_PREFIX = b"PTCGDAP\0POLICY_DECISION_AUDIT_V1\0"
PUBLIC_HASH_AUTHORITY = "firewall_accepted"
SAFE_MIN = -(2**53 - 1)
SAFE_MAX = 2**53 - 1
SHA_PATTERN = "^[0-9A-F]{64}$"

PATHS = {
    "schema": CONTRACT_ROOT / "strategic_context_v18.schema.json",
    "profile": CONTRACT_ROOT / "strategic_context_v18_profile.json",
    "vectors": CONTRACT_ROOT / "strategic_context_v18_conformance_vectors.json",
    "bundle": CONTRACT_ROOT / "strategic_context_v18_bundle.json",
}


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def canonical_hash(value: Any) -> str:
    return sha(canonical_json_v1_bytes(value))


def domain_hash(prefix: bytes, payload: dict[str, Any]) -> str:
    return sha(prefix + jcs_canonical_json_bytes(payload))


def strict_object(properties: dict[str, Any], required: list[str] | None = None) -> dict[str, Any]:
    return {
        "type": "object",
        "additionalProperties": False,
        "properties": properties,
        "required": required if required is not None else list(properties),
    }


def safe_integer(minimum: int = SAFE_MIN, maximum: int = SAFE_MAX) -> dict[str, Any]:
    return {"type": "integer", "minimum": minimum, "maximum": maximum}


def schema_document() -> dict[str, Any]:
    public_defs = copy.deepcopy(load_json_strict(CONTRACT_ROOT / "cabt_public_observation.schema.json")["$defs"])
    selected_defs = {name: public_defs[name] for name in ("Card", "Pokemon", "PlayerState", "Option", "Log", "ProvenanceRecord")}
    acting_player = copy.deepcopy(public_defs["PlayerState"])
    acting_player["properties"]["hand"] = {"type": "array", "items": {"$ref": "#/$defs/Card"}}
    opponent_player = copy.deepcopy(public_defs["PlayerState"])
    opponent_player["properties"]["hand"] = {"type": "null"}
    selected_defs.update(
        {
            "ActingPlayerState": acting_player,
            "OpponentPlayerState": opponent_player,
            "SourceBinding": strict_object(
                {
                    "public_observation_hash": {"type": "string", "pattern": SHA_PATTERN},
                    "window_id": {"type": "string", "pattern": SHA_PATTERN},
                    "chooser_player_index": {"enum": [0, 1]},
                    "option_fingerprint_profile": {"const": "cabt_option_fingerprint_v1"},
                    "option_count": safe_integer(0),
                }
            ),
            "Clocks": strict_object(
                {
                    "turn": safe_integer(),
                    "turn_action_count": safe_integer(0),
                    "remaining_overage_time": safe_integer(),
                    "acting_prizes_remaining": safe_integer(0),
                    "opponent_prizes_remaining": safe_integer(0),
                    "acting_deck_count": safe_integer(0),
                    "opponent_deck_count": safe_integer(0),
                    "acting_hand_count": safe_integer(0),
                    "opponent_hand_count": safe_integer(0),
                }
            ),
            "TurnFlags": strict_object(
                {
                    "first_player": safe_integer(),
                    "result": safe_integer(),
                    "supporter_played": {"type": "boolean"},
                    "stadium_played": {"type": "boolean"},
                    "energy_attached": {"type": "boolean"},
                    "retreated": {"type": "boolean"},
                }
            ),
            "PublicState": strict_object(
                {
                    "turn_flags": {"$ref": "#/$defs/TurnFlags"},
                    "stadium": {"type": "array", "items": {"$ref": "#/$defs/Card"}},
                    "acting_player": {"$ref": "#/$defs/ActingPlayerState"},
                    "opponent_player": {"$ref": "#/$defs/OpponentPlayerState"},
                }
            ),
            "OptionSemantic": strict_object(
                {
                    "index": safe_integer(0),
                    "fingerprint": {"type": "string", "pattern": SHA_PATTERN},
                    "raw": {"$ref": "#/$defs/Option"},
                }
            ),
            "SelectSemantics": strict_object(
                {
                    "select_type_raw": safe_integer(),
                    "select_context_raw": safe_integer(),
                    "min_count": safe_integer(0),
                    "max_count": safe_integer(0),
                    "remain_damage_counter": safe_integer(),
                    "remain_energy_cost": safe_integer(),
                    "context_card": {"anyOf": [{"$ref": "#/$defs/Card"}, {"type": "null"}]},
                    "effect": {"anyOf": [{"$ref": "#/$defs/Card"}, {"type": "null"}]},
                    "options": {"type": "array", "items": {"$ref": "#/$defs/OptionSemantic"}},
                }
            ),
            "OpponentPublicBelief": strict_object(
                {
                    "status": {"const": "unknown"},
                    "candidates": {"type": "array", "maxItems": 0},
                    "public_evidence_ids": {"type": "array", "items": {"type": "string"}, "maxItems": 0},
                }
            ),
            "ContextProvenance": strict_object(
                {
                    "firewall_contract_hash": {"const": "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947"},
                    "records": {"type": "array", "minItems": 1, "items": {"$ref": "#/$defs/ProvenanceRecord"}},
                }
            ),
            "StrategicContextV18": strict_object(
                {
                    "schema_version": {"const": 1},
                    "profile_id": {"const": PROFILE_ID},
                    "context_hash": {"type": "string", "pattern": SHA_PATTERN},
                    "source": {"$ref": "#/$defs/SourceBinding"},
                    "clocks": {"$ref": "#/$defs/Clocks"},
                    "public_state": {"$ref": "#/$defs/PublicState"},
                    "select_semantics": {"$ref": "#/$defs/SelectSemantics"},
                    "opponent_public_belief": {"$ref": "#/$defs/OpponentPublicBelief"},
                    "public_event_delta": {"type": "array", "items": {"$ref": "#/$defs/Log"}},
                    "provenance": {"$ref": "#/$defs/ContextProvenance"},
                    "authority": {"const": "strategic_context_public_audit"},
                    "authoritative": {"const": False},
                }
            ),
            "SelectedSemanticIntent": strict_object(
                {
                    "kind": {"const": "current_option_fingerprints"},
                    "options": {
                        "type": "array",
                        "items": strict_object(
                            {
                                "index": safe_integer(0),
                                "fingerprint": {"type": "string", "pattern": SHA_PATTERN},
                            }
                        ),
                    },
                }
            ),
            "PolicyDecision": strict_object(
                {
                    "schema_version": {"const": 1},
                    "profile_id": {"const": DECISION_PROFILE_ID},
                    "selected_indexes": {"type": "array", "uniqueItems": True, "items": safe_integer(0)},
                    "selected_semantic_intent": {"$ref": "#/$defs/SelectedSemanticIntent"},
                    "owner_layer": {"enum": ["base_graph", "base_fallback"]},
                    "reason_code": {
                        "enum": [
                            "policy_selection_accepted",
                            "window_fallback_only",
                            "invalid_policy_output",
                            "policy_exception",
                            "policy_timeout",
                            "policy_unavailable",
                        ]
                    },
                    "fallback_tier": {"enum": ["none", "same_public_window_deterministic"]},
                    "context_hash": {"type": "string", "pattern": SHA_PATTERN},
                    "policy_hash": {"type": "string", "pattern": SHA_PATTERN},
                    "audit_id": {"type": "string", "pattern": SHA_PATTERN},
                    "window_id": {"type": "string", "pattern": SHA_PATTERN},
                    "public_observation_hash": {"type": "string", "pattern": SHA_PATTERN},
                    "scene_id": {"type": "string", "minLength": 1, "maxLength": 128},
                    "decision_id": {"type": "string", "minLength": 1, "maxLength": 128},
                    "determinism_key": {"type": "string", "minLength": 1, "maxLength": 128},
                    "authority": {"const": "policy_decision_public_audit"},
                    "authoritative": {"const": False},
                }
            ),
        }
    )
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/strategic_context_v18.schema.json",
        "title": "PTCGDAP P4-WP1 StrategicContextV18 and PolicyDecision public audit values",
        "oneOf": [{"$ref": "#/$defs/StrategicContextV18"}, {"$ref": "#/$defs/PolicyDecision"}],
        "$defs": selected_defs,
    }


def profile_document() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "decision_profile_id": DECISION_PROFILE_ID,
        "source_lock_canonical_sha256": "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205",
        "official_base_graph_v1_8": {
            "python_raw_sha256": "5D3035312390936D86DE4E2BAF520CE38AB0A79137E1D93199B909D79FBCA3D2",
            "architecture_contract_raw_sha256": "E8A010E5B6458D2B43811DE683EA2147044D06624502B7314907747E8B0EB5B9",
            "relationship": "source_locked_semantic_oracle_only_no_runtime_import",
        },
        "parents": {
            "public_firewall_bundle_canonical_sha256": "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947",
            "selection_contract_bundle_canonical_sha256": "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294",
        },
        "hash_profiles": {
            "strategic_context_v18": {
                "algorithm": "SHA-256",
                "canonicalization": "RFC8785-JCS",
                "prefix_utf8_hex": CONTEXT_PREFIX.hex().upper(),
                "payload_rule": "the complete serialized StrategicContextV18 object with context_hash omitted",
            },
            "policy_decision_audit_v1": {
                "algorithm": "SHA-256",
                "canonicalization": "RFC8785-JCS",
                "prefix_utf8_hex": DECISION_PREFIX.hex().upper(),
                "payload_rule": "the complete serialized PolicyDecision object with audit_id omitted",
            },
        },
        "context_contract": {
            "input_authority": "exact accepted PublicFirewallResult plus exact valid matching CabtSelectionWindow",
            "acting_visibility": "copy only firewall accepted public tree; acting hand remains visible and opponent hand remains null",
            "option_semantics": "preserve current official option order and bind every item to its existing option fingerprint",
            "opponent_belief": "unknown empty public placeholder until a later public-only belief owner exists",
            "initial_select_null": "unsupported_initial_window",
            "no_private_retention": True,
        },
        "decision_contract": {
            "input_authority": "exact StrategicContextV18, exact same window and exact owner-produced CabtSelectionResolution",
            "policy_owner_mapping": {"policy": "base_graph", "deterministic_fallback": "base_fallback"},
            "fallback_mapping": {"policy": "none", "deterministic_fallback": "same_public_window_deterministic"},
            "selected_semantic_intent": "exact ordered selected indexes and current option fingerprints",
            "serialized_result_is_execution_authority": False,
            "consumer_rule": "a dict, schema pass, context hash, audit id or selected_indexes copy never authorizes binding, ticket creation or execution",
        },
        "stable_error_codes": [
            "contract_error",
            "invalid_firewall_result",
            "firewall_not_accepted",
            "unsupported_initial_window",
            "invalid_window",
            "source_hash_mismatch",
            "chooser_mismatch",
            "select_mismatch",
            "invalid_context",
            "invalid_resolution",
            "invalid_policy_hash",
            "invalid_decision_identity",
            "context_integrity_invalid",
            "decision_integrity_invalid",
        ],
        "private_forbidden_keys": [
            "raw_private_hash",
            "token_free_callback_hash",
            "search_begin_input",
            "session",
            "callback",
            "binding",
            "ticket",
            "command",
            "object_ref",
            "pokemon_entity_serial",
        ],
        "limits": {"max_context_bytes": 1048576, "max_identifier_bytes": 128, "safe_integer_minimum": SAFE_MIN, "safe_integer_maximum": SAFE_MAX},
        "scope": "offline public contract core only; no Base Graph executor, adapter, policy, trace-v2 pipeline, live owner or engine execution",
    }


def context_payload(public: dict[str, Any], public_hash: str, provenance: list[dict[str, str]], window: Any) -> dict[str, Any]:
    current = public["current"]
    chooser = current["yourIndex"]
    opponent = 1 - chooser
    players = current["players"]
    options = window.options
    fingerprints = list(window.option_fingerprints)
    payload = {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "source": {
            "public_observation_hash": public_hash,
            "window_id": window.window_id,
            "chooser_player_index": chooser,
            "option_fingerprint_profile": window.option_fingerprint_profile,
            "option_count": window.option_count,
        },
        "clocks": {
            "turn": current["turn"],
            "turn_action_count": current["turnActionCount"],
            "remaining_overage_time": public["remainingOverageTime"],
            "acting_prizes_remaining": len(players[chooser]["prize"]),
            "opponent_prizes_remaining": len(players[opponent]["prize"]),
            "acting_deck_count": players[chooser]["deckCount"],
            "opponent_deck_count": players[opponent]["deckCount"],
            "acting_hand_count": players[chooser]["handCount"],
            "opponent_hand_count": players[opponent]["handCount"],
        },
        "public_state": {
            "turn_flags": {
                "first_player": current["firstPlayer"],
                "result": current["result"],
                "supporter_played": current["supporterPlayed"],
                "stadium_played": current["stadiumPlayed"],
                "energy_attached": current["energyAttached"],
                "retreated": current["retreated"],
            },
            "stadium": copy.deepcopy(current["stadium"]),
            "acting_player": copy.deepcopy(players[chooser]),
            "opponent_player": copy.deepcopy(players[opponent]),
        },
        "select_semantics": {
            "select_type_raw": window.select_type_raw,
            "select_context_raw": window.select_context_raw,
            "min_count": window.min_count,
            "max_count": window.max_count,
            "remain_damage_counter": window.remain_damage_counter,
            "remain_energy_cost": window.remain_energy_cost,
            "context_card": window.context_card,
            "effect": window.effect,
            "options": [
                {"index": index, "fingerprint": fingerprints[index], "raw": copy.deepcopy(option)}
                for index, option in enumerate(options)
            ],
        },
        "opponent_public_belief": {"status": "unknown", "candidates": [], "public_evidence_ids": []},
        "public_event_delta": copy.deepcopy(public["logs"]),
        "provenance": {
            "firewall_contract_hash": "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947",
            "records": copy.deepcopy(provenance),
        },
        "authority": "strategic_context_public_audit",
        "authoritative": False,
    }
    return {**payload, "context_hash": domain_hash(CONTEXT_PREFIX, payload)}


def decision_payload(
    context: dict[str, Any],
    window: Any,
    indexes: list[int],
    owner: str,
    reason: str,
    policy_hash: str,
    scene_id: str,
    decision_id: str,
    determinism_key: str,
) -> dict[str, Any]:
    mapped_owner = "base_graph" if owner == "policy" else "base_fallback"
    fallback = "none" if owner == "policy" else "same_public_window_deterministic"
    fingerprints = list(window.option_fingerprints)
    payload = {
        "schema_version": 1,
        "profile_id": DECISION_PROFILE_ID,
        "selected_indexes": list(indexes),
        "selected_semantic_intent": {
            "kind": "current_option_fingerprints",
            "options": [{"index": index, "fingerprint": fingerprints[index]} for index in indexes],
        },
        "owner_layer": mapped_owner,
        "reason_code": reason,
        "fallback_tier": fallback,
        "context_hash": context["context_hash"],
        "policy_hash": policy_hash,
        "window_id": window.window_id,
        "public_observation_hash": window.public_observation_hash,
        "scene_id": scene_id,
        "decision_id": decision_id,
        "determinism_key": determinism_key,
        "authority": "policy_decision_public_audit",
        "authoritative": False,
    }
    return {**payload, "audit_id": domain_hash(DECISION_PREFIX, payload)}


def vector_document() -> dict[str, Any]:
    firewall_vectors = load_json_strict(CONTRACT_ROOT / "cabt_public_firewall_conformance_vectors.json")
    regular = next(case for case in firewall_vectors["cases"] if case["id"] == "regular-accepted")
    parsed = parse_raw_cabt_envelope(copy.deepcopy(firewall_vectors["base_observations"][regular["base"]]), contract_root=CONTRACT_ROOT)
    firewall = PublicObservationFirewall.load_default()
    accepted = firewall.project(parsed)
    if not accepted.accepted or not accepted.validate_integrity(parsed):
        raise RuntimeError("established public firewall fixture failed")
    public = accepted.public_observation
    assert public is not None and public["select"] is not None
    built = CabtSelectionWindow.build(
        public["select"],
        public_observation_hash=accepted.public_observation_hash,
        public_hash_authority=PUBLIC_HASH_AUTHORITY,
        chooser_player_index=public["current"]["yourIndex"],
    )
    if built.window is None:
        raise RuntimeError("established selection window fixture failed")
    window = built.window
    context = context_payload(public, accepted.public_observation_hash, accepted.provenance, window)
    policy_hash = sha(b"P4-WP1-SYNTHETIC-PUBLIC-POLICY")
    decisions = [
        ("policy-first", [0], "policy", "policy_selection_accepted"),
        ("policy-second", [1], "policy", "policy_selection_accepted"),
        ("fallback-invalid-output", [0], "deterministic_fallback", "invalid_policy_output"),
        ("fallback-timeout", [0], "deterministic_fallback", "policy_timeout"),
    ]
    decision_cases = []
    for case_id, indexes, owner, reason in decisions:
        scene_id = "fixture-scene"
        decision_id = f"fixture-{case_id}"
        determinism_key = f"fixture-determinism-{case_id}"
        decision_cases.append(
            {
                "id": case_id,
                "selected_indexes": indexes,
                "resolution_owner": owner,
                "resolution_reason_code": reason,
                "policy_hash": policy_hash,
                "scene_id": scene_id,
                "decision_id": decision_id,
                "determinism_key": determinism_key,
                "expected_decision": decision_payload(context, window, indexes, owner, reason, policy_hash, scene_id, decision_id, determinism_key),
            }
        )
    return {
        "schema_version": 1,
        "vector_set_id": "ptcgdap-strategic-context-v18-conformance-p4-wp1-v1",
        "profile_id": PROFILE_ID,
        "decision_profile_id": DECISION_PROFILE_ID,
        "fixture": {
            "firewall_vector_case_id": "regular-accepted",
            "public_hash_authority": PUBLIC_HASH_AUTHORITY,
            "expected_window": window.to_public_dict(),
            "expected_context": context,
        },
        "context_rejections": [
            {"id": "firewall-rejected", "fault": "rejected_firewall", "expected_error_code": "firewall_not_accepted"},
            {"id": "window-hash-mismatch", "fault": "window_hash_mismatch", "expected_error_code": "source_hash_mismatch"},
            {"id": "chooser-mismatch", "fault": "chooser_mismatch", "expected_error_code": "chooser_mismatch"},
            {"id": "select-mismatch", "fault": "select_mismatch", "expected_error_code": "select_mismatch"},
            {"id": "initial-window", "fault": "initial_select_null", "expected_error_code": "unsupported_initial_window"},
            {"id": "fake-firewall", "fault": "fake_firewall_result", "expected_error_code": "invalid_firewall_result"},
            {"id": "fake-window", "fault": "fake_window", "expected_error_code": "invalid_window"},
        ],
        "decision_cases": decision_cases,
        "decision_rejections": [
            {"id": "context-window-mismatch", "fault": "different_window", "expected_error_code": "invalid_context"},
            {"id": "fake-resolution", "fault": "fake_resolution", "expected_error_code": "invalid_resolution"},
            {"id": "bad-policy-hash", "fault": "lowercase_policy_hash", "expected_error_code": "invalid_policy_hash"},
            {"id": "empty-scene", "fault": "empty_scene_id", "expected_error_code": "invalid_decision_identity"},
        ],
        "private_sentinels": ["PRIVATE_SEARCH_SENTINEL", "PRIVATE_RNG_SENTINEL", "PRIVATE_CALLBACK_SENTINEL", "PRIVATE_ENGINE_SENTINEL"],
        "consumer_rule": "Serialized context and decision values are public audit only and never execution authority.",
    }


def bundle_document(schema: dict[str, Any], profile: dict[str, Any], vectors: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "contract_id": BUNDLE_ID,
        "source_lock_canonical_sha256": profile["source_lock_canonical_sha256"],
        "public_firewall_bundle_canonical_sha256": profile["parents"]["public_firewall_bundle_canonical_sha256"],
        "selection_contract_bundle_canonical_sha256": profile["parents"]["selection_contract_bundle_canonical_sha256"],
        "artifacts": [
            {"id": "schema", "path": "contracts/ptcgdap/strategic_context_v18.schema.json", "canonical_sha256": canonical_hash(schema)},
            {"id": "profile", "path": "contracts/ptcgdap/strategic_context_v18_profile.json", "canonical_sha256": canonical_hash(profile)},
            {"id": "vectors", "path": "contracts/ptcgdap/strategic_context_v18_conformance_vectors.json", "canonical_sha256": canonical_hash(vectors)},
        ],
        "runtime_authority": "schema/profile only; vectors are conformance fixtures and never runtime policy input",
    }


def render(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2, separators=(",", ": ")) + "\n").encode("utf-8")


def documents() -> dict[str, dict[str, Any]]:
    source_lock = SOURCE_LOCK.read_bytes()
    if canonical_hash(load_json_strict(SOURCE_LOCK)) != "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205":
        raise RuntimeError("SOURCE_LOCK canonical mismatch")
    if sha((ORACLE_ROOT / "strategy_graph/base_graph_v1_8.py").read_bytes()) != "5D3035312390936D86DE4E2BAF520CE38AB0A79137E1D93199B909D79FBCA3D2":
        raise RuntimeError("Base Graph v1.8 Python oracle mismatch")
    if sha((ORACLE_ROOT / "strategy_graph/base_graph_v1_8_architecture_contract.json").read_bytes()) != "E8A010E5B6458D2B43811DE683EA2147044D06624502B7314907747E8B0EB5B9":
        raise RuntimeError("Base Graph v1.8 architecture oracle mismatch")
    if not source_lock:
        raise RuntimeError("SOURCE_LOCK empty")
    schema = schema_document()
    profile = profile_document()
    vectors = vector_document()
    return {"schema": schema, "profile": profile, "vectors": vectors, "bundle": bundle_document(schema, profile, vectors)}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    docs = documents()
    if args.check:
        mismatches = [key for key, value in docs.items() if not PATHS[key].is_file() or PATHS[key].read_bytes() != render(value)]
        if mismatches:
            raise SystemExit("strategic context contract drift: " + ",".join(mismatches))
        return 0
    for key, value in docs.items():
        PATHS[key].parent.mkdir(parents=True, exist_ok=True)
        PATHS[key].write_bytes(render(value))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
