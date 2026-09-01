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

from scripts.ai.ptcgdap.marnie_capability_policy import MarnieCapabilityPolicy
from scripts.ai.ptcgdap.marnie_vertical_slice import MarnieVerticalSlice
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


PROFILE_ID = "ptcgdap-marnie-prompt-broker-p5-wp5-v1"
BUNDLE_ID = "ptcgdap-marnie-prompt-broker-bundle-p5-wp5-v1"
AUDIT_ID = "ptcgdap-marnie-prompt-broker-audit-p5-wp5-v1"
VECTOR_ID = "ptcgdap-marnie-prompt-broker-vectors-p5-wp5-v1"
SCHEMA_ID = "ptcgdap-marnie-prompt-broker-schema-p5-wp5-v1"
FRAME_ORDER = [
    "w0_initial", "w1_setup_active", "w2_setup_bench", "w3_main",
    "w4_spikemuth_deck", "w5_punk_up_sources", "w5_punk_up_target_1",
    "w5_punk_up_target_2", "w6_shadow_bullet_attack",
    "w6_shadow_bullet_target", "w7_take_prize", "w7_forced_send_out",
    "w7_terminal",
]
PARENT_HASHES = {
    "vertical_slice_bundle": "7E0CF80D7B2872C29F69BA15548857F1F32407943371D3C12A266A0E471EC425",
    "capability_policy_bundle": "F4E88E5DB4E480BA8441BE7B3A7C81CE3DB40ED1917EB37BCDCAC1C32B1ABD6C",
    "identity_projection_bundle": "1EB530AB7DFACBE6AB098A6C67D6AAE0BC1871FF3E2F48C9284E8539EE6ACDC4",
    "shadow_prompt_broker_bundle": "D19EC7B9B77370312C82E0572DFB016B75E3FE9F438B6C1EFFD50E0AB43C551E",
    "engine_decision_port_bundle": "CC0026D523F2B5435031AC4E5952DB4E2C8B2C39944B333E97B1A2E4F3374C81",
    "godot_option_binding_bundle": "4FFFEC48E4E1FE0774BB6E343D4D4B0384A9210057DEE06415C2A20F2899B1C1",
}
SOURCE_PREFIX = bytes.fromhex("5054434744415000454E47494E455F4445434953494F4E5F534F555243455F563100")
SNAPSHOT_PREFIX = bytes.fromhex("5054434744415000454E47494E455F4445434953494F4E5F534E415053484F545F563100")
CALLBACK_PREFIX = b"PTCGDAP\0MARNIE_PROMPT_CALLBACK_V1\0"
LIFECYCLE_PREFIX = b"PTCGDAP\0MARNIE_PROMPT_LIFECYCLE_V1\0"

OUTPUTS = {
    "schema": ROOT / "contracts/ptcgdap/marnie_prompt_broker.schema.json",
    "profile": ROOT / "contracts/ptcgdap/marnie_prompt_broker_profile.json",
    "audit": ROOT / "data/ptcgdap/marnie_vertical_slice/marnie_prompt_broker_v1.json",
    "vectors": ROOT / "contracts/ptcgdap/marnie_prompt_broker_conformance_vectors.json",
    "bundle": ROOT / "contracts/ptcgdap/marnie_prompt_broker_bundle.json",
}


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def canonical_hash(value: Any) -> str:
    return sha(canonical_json_v1_bytes(value))


def _source_option(option: dict[str, Any], attack_ordinals: dict[int, int]) -> dict[str, Any]:
    option_type = option["type"]
    if option_type == 3:
        return {"type": 3}
    if option_type == 7:
        return {"type": 7, "index": option["index"]}
    if option_type == 8:
        return {key: option[key] for key in ["type", "area", "index", "inPlayArea", "inPlayIndex"]}
    if option_type == 12:
        return {"type": 12}
    if option_type == 13:
        attack_id = option["attackId"]
        if attack_id not in attack_ordinals:
            raise RuntimeError("attack identity missing from official master")
        return {"type": 13, "local_attack_index": attack_ordinals[attack_id], "official_attack_id": attack_id}
    if option_type == 14:
        return {"type": 14}
    raise RuntimeError(f"unsupported fixture option type: {option_type}")


def _source_descriptor(source: dict[str, Any]) -> dict[str, Any]:
    select = source["select"]
    audit_options = [
        {"position": index, "option": option, "reference_token": None}
        for index, option in enumerate(select["option"])
    ]
    return {
        "select": {
            "type": select["type"], "context": select["context"],
            "minCount": select["minCount"], "maxCount": select["maxCount"],
            "remainDamageCounter": select["remainDamageCounter"],
            "remainEnergyCost": select["remainEnergyCost"],
            "option": audit_options, "deck_tokens": None,
            "context_token": None, "effect_token": None,
        },
        "turn_action_count": source["turn_action_count"],
    }


def _expected_frame(
    *, ordinal: int, frame: dict[str, Any], selected_indexes: list[int] | None,
    broker_generation: int | None, source: dict[str, Any] | None,
) -> dict[str, Any]:
    window = frame["window"]
    base = {
        "ordinal": ordinal,
        "frame_id": frame["frame_id"],
        "window_family": frame["window_family"],
        "callback_role": frame["callback_role"],
        "status": "terminal_no_callback" if frame["terminal"] is not None else "initial_deck_fixture" if window is None else "committed_shadow",
        "decision_generation": broker_generation,
        "broker_generation": broker_generation,
        "snapshot_id": None,
        "source_digest": None,
        "window_id": None if window is None else window["window_id"],
        "binding_version": broker_generation,
        "option_count": 0 if window is None else len(window["options"]),
        "option_types": [] if window is None else [option["type"] for option in window["options"]],
        "selected_indexes": selected_indexes,
        "committed_resolution_count": 0 if selected_indexes is None else len(selected_indexes),
        "serialized_private_resolution_count": 0,
        "broker_state": "not_applicable" if window is None else "awaiting_reobserve",
        "extension_profile_id": PROFILE_ID,
        "production_action_used": False,
        "execution_authority": False,
    }
    if source is not None:
        descriptor = _source_descriptor(source)
        source_digest = sha(SOURCE_PREFIX + canonical_json_v1_bytes(descriptor))
        snapshot_payload = {
            "match_generation": 1,
            "decision_generation": broker_generation,
            "chooser_player_index": window["chooser_player_index"],
            "source_digest": source_digest,
        }
        base["source_digest"] = source_digest
        base["snapshot_id"] = sha(SNAPSHOT_PREFIX + canonical_json_v1_bytes(snapshot_payload))
    return base


def build_documents() -> dict[str, Any]:
    vertical = MarnieVerticalSlice.load_default()
    policy = MarnieCapabilityPolicy.load_default()
    master = load_json_strict(ROOT / "data/ptcgdap/card_id_catalog/official_card_attack_master_v1.json")
    attack_ordinals = {item["official_attack_id"]: item["owner_attack_ordinal"] for item in master["attacks"]}
    frames: list[dict[str, Any]] = []
    public_frames: list[dict[str, Any]] = []
    broker_generation = 0
    previous_hash: str | None = None
    for ordinal, frame_id in enumerate(FRAME_ORDER):
        source_frame = vertical.frame(frame_id)
        if source_frame["frame_id"] != frame_id:
            raise RuntimeError("vertical frame order mismatch")
        policy_frame = policy.evaluate_frame(frame_id).to_public_dict()["frames"][0]
        selected_indexes = policy_frame["selected_indexes"]
        window = source_frame["window"]
        source = None
        callback_hash = None
        if window is not None:
            broker_generation += 1
            source_options = [_source_option(option, attack_ordinals) for option in window["options"]]
            source_select = {
                "type": window["select_type_raw"], "context": window["select_context_raw"],
                "minCount": window["min_count"], "maxCount": window["max_count"],
                "remainDamageCounter": window["remain_damage_counter"],
                "remainEnergyCost": window["remain_energy_cost"],
                "option": source_options, "deck": None, "contextCard": None, "effect": None,
            }
            source = {
                "select": source_select, "deck_cards": None, "context_card": None,
                "effect_card": None, "option_card_refs": [None] * len(source_options),
                "turn_action_count": broker_generation,
            }
            callback_hash = sha(CALLBACK_PREFIX + canonical_json_v1_bytes({"ordinal": ordinal, "frame_id": frame_id, "window_id": window["window_id"]}))
        expected = _expected_frame(
            ordinal=ordinal, frame=source_frame, selected_indexes=selected_indexes,
            broker_generation=broker_generation if window is not None else None, source=source,
        )
        lifecycle_payload = {key: value for key, value in expected.items() if key not in {"previous_lifecycle_hash", "lifecycle_hash"}}
        lifecycle_payload["previous_lifecycle_hash"] = previous_hash
        lifecycle_hash = sha(LIFECYCLE_PREFIX + canonical_json_v1_bytes(lifecycle_payload))
        expected["previous_lifecycle_hash"] = previous_hash
        expected["lifecycle_hash"] = lifecycle_hash
        previous_hash = lifecycle_hash
        frames.append({
            "ordinal": ordinal,
            "frame_id": frame_id,
            "window_family": source_frame["window_family"],
            "callback_role": source_frame["callback_role"],
            "terminal": source_frame["terminal"] is not None,
            "public_observation_hash": source_frame["public_observation_hash"],
            "window": window,
            "policy_selected_indexes": selected_indexes,
            "source": source,
            "callback_binding_hash": callback_hash,
            "option_types": expected["option_types"],
            "expected_public_result": expected,
        })
        public_frames.append(expected)
    if broker_generation != 11:
        raise RuntimeError("expected exactly 11 broker frames")
    expected_all = {
        "accepted": True,
        "error_code": "",
        "frame_count": 13,
        "brokered_frame_count": 11,
        "initial_deck_frame_count": 1,
        "terminal_frame_count": 1,
        "serialized_private_resolution_count": 0,
        "extension_profile_id": PROFILE_ID,
        "lifecycle_chain_head": previous_hash,
        "frames": public_frames,
        "production_actions_used": False,
        "execution_authority": False,
    }
    audit = {
        "schema_version": 1,
        "artifact_kind": "marnie_prompt_broker_audit",
        "audit_id": AUDIT_ID,
        "profile_id": PROFILE_ID,
        "parent_contracts": PARENT_HASHES,
        "match_generation": 1,
        "session_id": "session:marnie-p5-wp5-offline",
        "frames": frames,
        "summary": {
            "frame_count": 13, "brokered_frame_count": 11,
            "initial_deck_frame_count": 1, "terminal_frame_count": 1,
            "option_type_8_count": sum(item["option_types"].count(8) for item in frames),
            "option_type_12_count": sum(item["option_types"].count(12) for item in frames),
            "option_type_13_count": sum(item["option_types"].count(13) for item in frames),
            "lifecycle_chain_head": previous_hash,
        },
        "expected_public_result": expected_all,
        "production_actions_used": False,
        "execution_authority": False,
    }
    profile = {
        "schema_version": 1,
        "artifact_kind": "marnie_prompt_broker_profile",
        "profile_id": PROFILE_ID,
        "frame_order": FRAME_ORDER,
        "match_generation": 1,
        "session_id": "session:marnie-p5-wp5-offline",
        "parent_contracts": PARENT_HASHES,
        "port_extension": {
            "method": "publish_p5_extended",
            "profile_id": PROFILE_ID,
            "option_shapes": {
                "8": ["type", "area", "index", "inPlayArea", "inPlayIndex"],
                "12": ["type"],
                "13": ["type", "local_attack_index", "official_attack_id"],
            },
        },
        "binding_extension": {
            "method": "bind_p5_extended",
            "profile_id": PROFILE_ID,
            "compare_fields": {"7": ["index"], "8": ["area", "index", "inPlayArea", "inPlayIndex"], "13": ["official_attack_id", "attackId"]},
        },
        "error_codes": ["", "input_type_invalid", "operation_unknown", "frame_unknown", "contract_integrity_invalid", "lifecycle_rejected"],
        "result_contract": {
            "serialized_results_are_authority": False,
            "private_capabilities_serialized": False,
            "execution_authority": False,
            "production_actions_used": False,
            "reobserve_after_every_commit": True,
        },
        "limits": {"frame_count": 13, "brokered_frame_count": 11, "max_options": 256},
    }
    schema = _schema()
    vectors = _vectors(audit)
    artifacts = {"schema": schema, "profile": profile, "audit": audit, "vectors": vectors}
    bundle_entries = []
    for artifact_id, path_key, path in [
        ("schema", "schema", "contracts/ptcgdap/marnie_prompt_broker.schema.json"),
        ("profile", "profile", "contracts/ptcgdap/marnie_prompt_broker_profile.json"),
        ("audit", "audit", "data/ptcgdap/marnie_vertical_slice/marnie_prompt_broker_v1.json"),
        ("vectors", "vectors", "contracts/ptcgdap/marnie_prompt_broker_conformance_vectors.json"),
    ]:
        bundle_entries.append({"id": artifact_id, "path": path, "canonical_sha256": canonical_hash(artifacts[path_key])})
    bundle = {
        "schema_version": 1,
        "artifact_kind": "marnie_prompt_broker_bundle",
        "bundle_id": BUNDLE_ID,
        "profile_id": PROFILE_ID,
        "parent_contracts": PARENT_HASHES,
        "artifacts": bundle_entries,
        "production_actions_used": False,
        "execution_authority": False,
    }
    return {**artifacts, "bundle": bundle}


def _schema() -> dict[str, Any]:
    safe_int = {"type": "integer", "minimum": 0, "maximum": 9007199254740991}
    sha_schema = {"type": "string", "pattern": "^[A-F0-9]{64}$"}
    json_scalar = {"type": ["string", "integer", "boolean", "null"]}
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": SCHEMA_ID,
        "title": "PtcgDAP Marnie prompt broker P5-WP5 artifacts",
        "oneOf": [
            {"$ref": "#/$defs/profile"}, {"$ref": "#/$defs/audit"},
            {"$ref": "#/$defs/vectors"}, {"$ref": "#/$defs/bundle"},
        ],
        "$defs": {
            "sha": sha_schema,
            "safeInt": safe_int,
            "closedObject": {"type": "object"},
            "parentContracts": {
                "type": "object", "additionalProperties": False,
                "required": list(PARENT_HASHES),
                "properties": {key: {"const": value} for key, value in PARENT_HASHES.items()},
            },
            "option": {
                "oneOf": [
                    {"type": "object", "additionalProperties": False, "required": ["type"], "properties": {"type": {"const": 3}}},
                    {"type": "object", "additionalProperties": False, "required": ["type", "index"], "properties": {"type": {"const": 7}, "index": safe_int}},
                    {"type": "object", "additionalProperties": False, "required": ["type", "area", "index", "inPlayArea", "inPlayIndex"], "properties": {"type": {"const": 8}, "area": safe_int, "index": safe_int, "inPlayArea": safe_int, "inPlayIndex": safe_int}},
                    {"type": "object", "additionalProperties": False, "required": ["type"], "properties": {"type": {"const": 12}}},
                    {"type": "object", "additionalProperties": False, "required": ["type", "local_attack_index", "official_attack_id"], "properties": {"type": {"const": 13}, "local_attack_index": safe_int, "official_attack_id": safe_int}},
                    {"type": "object", "additionalProperties": False, "required": ["type"], "properties": {"type": {"const": 14}}},
                ]
            },
            "card": {
                "type": "object", "additionalProperties": False,
                "required": ["id", "serial", "playerIndex"],
                "properties": {"id": safe_int, "serial": safe_int, "playerIndex": {"type": "integer", "minimum": 0, "maximum": 1}},
            },
            "rawOption": {
                "oneOf": [
                    {"type": "object", "additionalProperties": False, "required": ["type", "area", "index", "playerIndex"], "properties": {"type": {"const": 3}, "area": safe_int, "index": safe_int, "playerIndex": {"type": "integer", "minimum": 0, "maximum": 1}}},
                    {"type": "object", "additionalProperties": False, "required": ["type", "index"], "properties": {"type": {"const": 7}, "index": safe_int}},
                    {"type": "object", "additionalProperties": False, "required": ["type", "area", "index", "inPlayArea", "inPlayIndex"], "properties": {"type": {"const": 8}, "area": safe_int, "index": safe_int, "inPlayArea": safe_int, "inPlayIndex": safe_int}},
                    {"type": "object", "additionalProperties": False, "required": ["type"], "properties": {"type": {"const": 12}}},
                    {"type": "object", "additionalProperties": False, "required": ["type", "attackId"], "properties": {"type": {"const": 13}, "attackId": safe_int}},
                    {"type": "object", "additionalProperties": False, "required": ["type"], "properties": {"type": {"const": 14}}},
                ]
            },
            "sourceSelect": {
                "type": "object", "additionalProperties": False,
                "required": ["type", "context", "minCount", "maxCount", "remainDamageCounter", "remainEnergyCost", "option", "deck", "contextCard", "effect"],
                "properties": {
                    "type": safe_int, "context": safe_int, "minCount": safe_int, "maxCount": safe_int,
                    "remainDamageCounter": safe_int, "remainEnergyCost": safe_int,
                    "option": {"type": "array", "items": {"$ref": "#/$defs/option"}, "maxItems": 256},
                    "deck": {"type": "null"}, "contextCard": {"type": "null"}, "effect": {"type": "null"},
                },
            },
            "source": {
                "type": ["object", "null"],
                "additionalProperties": False,
                "required": ["select", "deck_cards", "context_card", "effect_card", "option_card_refs", "turn_action_count"],
                "properties": {
                    "select": {"oneOf": [{"$ref": "#/$defs/sourceSelect"}, {"type": "null"}]}, "deck_cards": {"type": "null"},
                    "context_card": {"type": "null"}, "effect_card": {"type": "null"},
                    "option_card_refs": {"type": "array", "items": {"type": "null"}, "maxItems": 256},
                    "turn_action_count": safe_int,
                },
            },
            "serializedWindow": {
                "type": "object", "additionalProperties": False,
                "required": ["window_version", "window_id", "hash_profile", "option_fingerprint_profile", "public_observation_hash", "public_hash_authority", "chooser_player_index", "decision_state", "fallback_reasons", "select_type_raw", "select_context_raw", "min_count", "max_count", "remain_damage_counter", "remain_energy_cost", "context_card", "effect", "public_deck_candidates", "options", "option_fingerprints"],
                "properties": {
                    "window_version": {"const": 1}, "window_id": sha_schema,
                    "hash_profile": {"const": "cabt_selection_window_v1"}, "option_fingerprint_profile": {"const": "cabt_option_fingerprint_v1"},
                    "public_observation_hash": sha_schema, "public_hash_authority": {"const": "conformance_fixture"},
                    "chooser_player_index": {"type": "integer", "minimum": 0, "maximum": 1}, "decision_state": {"const": "policy_allowed"},
                    "fallback_reasons": {"const": []}, "select_type_raw": safe_int, "select_context_raw": safe_int,
                    "min_count": safe_int, "max_count": safe_int, "remain_damage_counter": safe_int, "remain_energy_cost": safe_int,
                    "context_card": {"oneOf": [{"$ref": "#/$defs/card"}, {"type": "null"}]},
                    "effect": {"oneOf": [{"$ref": "#/$defs/card"}, {"type": "null"}]},
                    "public_deck_candidates": {"oneOf": [{"type": "array", "items": {"$ref": "#/$defs/card"}, "maxItems": 120}, {"type": "null"}]},
                    "options": {"type": "array", "items": {"$ref": "#/$defs/rawOption"}, "maxItems": 256},
                    "option_fingerprints": {"type": "array", "items": sha_schema, "maxItems": 256},
                },
            },
            "expectedFrame": {
                "type": "object", "additionalProperties": False,
                "required": ["ordinal", "frame_id", "window_family", "callback_role", "status", "decision_generation", "broker_generation", "snapshot_id", "source_digest", "window_id", "binding_version", "option_count", "option_types", "selected_indexes", "committed_resolution_count", "serialized_private_resolution_count", "broker_state", "extension_profile_id", "production_action_used", "execution_authority", "previous_lifecycle_hash", "lifecycle_hash"],
                "properties": {
                    "ordinal": safe_int, "frame_id": {"type": "string", "minLength": 1}, "window_family": {"type": "string", "pattern": "^W[0-7]$"},
                    "callback_role": {"type": "string", "minLength": 1}, "status": {"enum": ["initial_deck_fixture", "committed_shadow", "terminal_no_callback"]},
                    "decision_generation": {"oneOf": [safe_int, {"type": "null"}]}, "broker_generation": {"oneOf": [safe_int, {"type": "null"}]},
                    "snapshot_id": {"oneOf": [sha_schema, {"type": "null"}]}, "source_digest": {"oneOf": [sha_schema, {"type": "null"}]},
                    "window_id": {"oneOf": [sha_schema, {"type": "null"}]}, "binding_version": {"oneOf": [safe_int, {"type": "null"}]},
                    "option_count": safe_int, "option_types": {"type": "array", "items": safe_int, "maxItems": 256},
                    "selected_indexes": {"oneOf": [{"type": "array", "items": safe_int, "uniqueItems": True, "maxItems": 256}, {"type": "null"}]},
                    "committed_resolution_count": safe_int, "serialized_private_resolution_count": {"const": 0},
                    "broker_state": {"enum": ["not_applicable", "awaiting_reobserve"]}, "extension_profile_id": {"const": PROFILE_ID},
                    "production_action_used": {"const": False}, "execution_authority": {"const": False},
                    "previous_lifecycle_hash": {"oneOf": [sha_schema, {"type": "null"}]}, "lifecycle_hash": sha_schema,
                },
            },
            "summary": {
                "type": "object", "additionalProperties": False,
                "required": ["frame_count", "brokered_frame_count", "initial_deck_frame_count", "terminal_frame_count", "option_type_8_count", "option_type_12_count", "option_type_13_count", "lifecycle_chain_head"],
                "properties": {"frame_count": {"const": 13}, "brokered_frame_count": {"const": 11}, "initial_deck_frame_count": {"const": 1}, "terminal_frame_count": {"const": 1}, "option_type_8_count": {"const": 2}, "option_type_12_count": {"const": 1}, "option_type_13_count": {"const": 1}, "lifecycle_chain_head": sha_schema},
            },
            "expectedAll": {
                "type": "object", "additionalProperties": False,
                "required": ["accepted", "error_code", "frame_count", "brokered_frame_count", "initial_deck_frame_count", "terminal_frame_count", "serialized_private_resolution_count", "extension_profile_id", "lifecycle_chain_head", "frames", "production_actions_used", "execution_authority"],
                "properties": {"accepted": {"const": True}, "error_code": {"const": ""}, "frame_count": {"const": 13}, "brokered_frame_count": {"const": 11}, "initial_deck_frame_count": {"const": 1}, "terminal_frame_count": {"const": 1}, "serialized_private_resolution_count": {"const": 0}, "extension_profile_id": {"const": PROFILE_ID}, "lifecycle_chain_head": sha_schema, "frames": {"type": "array", "items": {"$ref": "#/$defs/expectedFrame"}, "minItems": 13, "maxItems": 13}, "production_actions_used": {"const": False}, "execution_authority": {"const": False}},
            },
            "frame": {
                "type": "object", "additionalProperties": False,
                "required": ["ordinal", "frame_id", "window_family", "callback_role", "terminal", "public_observation_hash", "window", "policy_selected_indexes", "source", "callback_binding_hash", "option_types", "expected_public_result"],
                "properties": {
                    "ordinal": safe_int, "frame_id": {"type": "string", "minLength": 1},
                    "window_family": {"type": "string", "pattern": "^W[0-7]$"},
                    "callback_role": {"type": "string", "minLength": 1}, "terminal": {"type": "boolean"},
                    "public_observation_hash": {"oneOf": [sha_schema, {"type": "null"}]}, "window": {"oneOf": [{"$ref": "#/$defs/serializedWindow"}, {"type": "null"}]},
                    "policy_selected_indexes": {"type": ["array", "null"], "items": safe_int, "uniqueItems": True},
                    "source": {"$ref": "#/$defs/source"}, "callback_binding_hash": {"oneOf": [sha_schema, {"type": "null"}]},
                    "option_types": {"type": "array", "items": safe_int}, "expected_public_result": {"$ref": "#/$defs/expectedFrame"},
                },
                "allOf": [
                    {
                        "if": {"properties": {"terminal": {"const": True}}, "required": ["terminal"]},
                        "then": {"properties": {
                            "public_observation_hash": {"type": "null"}, "window": {"type": "null"},
                            "policy_selected_indexes": {"type": "null"}, "source": {"type": "null"},
                            "callback_binding_hash": {"type": "null"}, "option_types": {"maxItems": 0},
                        }},
                        "else": {"properties": {"public_observation_hash": sha_schema}},
                    },
                    {
                        "if": {"properties": {"ordinal": {"const": 0}}, "required": ["ordinal"]},
                        "then": {"properties": {
                            "terminal": {"const": False}, "window": {"type": "null"},
                            "policy_selected_indexes": {"type": "null"}, "source": {"type": "null"},
                            "callback_binding_hash": {"type": "null"}, "option_types": {"maxItems": 0},
                        }},
                        "else": {
                            "if": {"properties": {"terminal": {"const": False}}, "required": ["terminal"]},
                            "then": {"properties": {
                                "window": {"$ref": "#/$defs/serializedWindow"},
                                "policy_selected_indexes": {"type": "array", "items": safe_int, "uniqueItems": True},
                                "source": {"type": "object"}, "callback_binding_hash": sha_schema,
                            }},
                        },
                    },
                ],
            },
            "profile": {
                "type": "object", "additionalProperties": False,
                "required": ["schema_version", "artifact_kind", "profile_id", "frame_order", "match_generation", "session_id", "parent_contracts", "port_extension", "binding_extension", "error_codes", "result_contract", "limits"],
                "properties": {
                    "schema_version": {"const": 1}, "artifact_kind": {"const": "marnie_prompt_broker_profile"},
                    "profile_id": {"const": PROFILE_ID}, "frame_order": {"const": FRAME_ORDER},
                    "match_generation": {"const": 1}, "session_id": {"const": "session:marnie-p5-wp5-offline"},
                    "parent_contracts": {"$ref": "#/$defs/parentContracts"},
                    "port_extension": {"const": {"method": "publish_p5_extended", "profile_id": PROFILE_ID, "option_shapes": {"8": ["type", "area", "index", "inPlayArea", "inPlayIndex"], "12": ["type"], "13": ["type", "local_attack_index", "official_attack_id"]}}},
                    "binding_extension": {"const": {"method": "bind_p5_extended", "profile_id": PROFILE_ID, "compare_fields": {"7": ["index"], "8": ["area", "index", "inPlayArea", "inPlayIndex"], "13": ["official_attack_id", "attackId"]}}},
                    "error_codes": {"const": ["", "input_type_invalid", "operation_unknown", "frame_unknown", "contract_integrity_invalid", "lifecycle_rejected"]},
                    "result_contract": {"const": {"serialized_results_are_authority": False, "private_capabilities_serialized": False, "execution_authority": False, "production_actions_used": False, "reobserve_after_every_commit": True}},
                    "limits": {"const": {"frame_count": 13, "brokered_frame_count": 11, "max_options": 256}},
                },
            },
            "audit": {
                "type": "object", "additionalProperties": False,
                "required": ["schema_version", "artifact_kind", "audit_id", "profile_id", "parent_contracts", "match_generation", "session_id", "frames", "summary", "expected_public_result", "production_actions_used", "execution_authority"],
                "properties": {
                    "schema_version": {"const": 1}, "artifact_kind": {"const": "marnie_prompt_broker_audit"},
                    "audit_id": {"const": AUDIT_ID}, "profile_id": {"const": PROFILE_ID},
                    "parent_contracts": {"$ref": "#/$defs/parentContracts"}, "match_generation": {"const": 1},
                    "session_id": {"const": "session:marnie-p5-wp5-offline"},
                    "frames": {"type": "array", "prefixItems": [
                        {"allOf": [
                            {"$ref": "#/$defs/frame"},
                            {"properties": {"ordinal": {"const": ordinal}, "frame_id": {"const": frame_id}}, "required": ["ordinal", "frame_id"]},
                        ]}
                        for ordinal, frame_id in enumerate(FRAME_ORDER)
                    ], "items": False, "minItems": 13, "maxItems": 13},
                    "summary": {"$ref": "#/$defs/summary"}, "expected_public_result": {"$ref": "#/$defs/expectedAll"},
                    "production_actions_used": {"const": False}, "execution_authority": {"const": False},
                },
            },
            "vectorCase": {
                "type": "object", "additionalProperties": False,
                "required": ["case_id", "operation", "input", "expected"],
                "properties": {"case_id": {"type": "string", "minLength": 1}, "operation": {"type": ["string", "integer", "null"]}, "input": {}, "expected": {"type": "object", "additionalProperties": False, "required": ["ok", "error_code", "value"], "properties": {"ok": {"type": "boolean"}, "error_code": {"enum": ["", "input_type_invalid", "operation_unknown", "frame_unknown"]}, "value": {"oneOf": [{"$ref": "#/$defs/expectedFrame"}, {"$ref": "#/$defs/expectedAll"}, {"$ref": "#/$defs/summary"}, {"type": "null"}]}}}},
            },
            "vectors": {
                "type": "object", "additionalProperties": False,
                "required": ["schema_version", "artifact_kind", "vector_id", "profile_id", "cases"],
                "properties": {"schema_version": {"const": 1}, "artifact_kind": {"const": "marnie_prompt_broker_vectors"}, "vector_id": {"const": VECTOR_ID}, "profile_id": {"const": PROFILE_ID}, "cases": {"type": "array", "items": {"$ref": "#/$defs/vectorCase"}, "minItems": 23, "maxItems": 23}},
            },
            "bundle": {
                "type": "object", "additionalProperties": False,
                "required": ["schema_version", "artifact_kind", "bundle_id", "profile_id", "parent_contracts", "artifacts", "production_actions_used", "execution_authority"],
                "properties": {
                    "schema_version": {"const": 1}, "artifact_kind": {"const": "marnie_prompt_broker_bundle"},
                    "bundle_id": {"const": BUNDLE_ID}, "profile_id": {"const": PROFILE_ID},
                    "parent_contracts": {"$ref": "#/$defs/parentContracts"},
                    "artifacts": {"type": "array", "minItems": 4, "maxItems": 4, "items": False, "prefixItems": [
                        {"type": "object", "additionalProperties": False, "required": ["id", "path", "canonical_sha256"], "properties": {"id": {"const": "schema"}, "path": {"const": "contracts/ptcgdap/marnie_prompt_broker.schema.json"}, "canonical_sha256": sha_schema}},
                        {"type": "object", "additionalProperties": False, "required": ["id", "path", "canonical_sha256"], "properties": {"id": {"const": "profile"}, "path": {"const": "contracts/ptcgdap/marnie_prompt_broker_profile.json"}, "canonical_sha256": sha_schema}},
                        {"type": "object", "additionalProperties": False, "required": ["id", "path", "canonical_sha256"], "properties": {"id": {"const": "audit"}, "path": {"const": "data/ptcgdap/marnie_vertical_slice/marnie_prompt_broker_v1.json"}, "canonical_sha256": sha_schema}},
                        {"type": "object", "additionalProperties": False, "required": ["id", "path", "canonical_sha256"], "properties": {"id": {"const": "vectors"}, "path": {"const": "contracts/ptcgdap/marnie_prompt_broker_conformance_vectors.json"}, "canonical_sha256": sha_schema}},
                    ]},
                    "production_actions_used": {"const": False}, "execution_authority": {"const": False},
                },
            },
        },
    }


def _vectors(audit: dict[str, Any]) -> dict[str, Any]:
    cases = [
        {"case_id": f"frame-{frame['ordinal']:02d}-{frame['frame_id']}", "operation": "evaluate_frame", "input": frame["frame_id"], "expected": {"ok": True, "error_code": "", "value": frame["expected_public_result"]}}
        for frame in audit["frames"]
    ]
    cases.extend([
        {"case_id": "evaluate-all", "operation": "evaluate_all", "input": None, "expected": {"ok": True, "error_code": "", "value": audit["expected_public_result"]}},
        {"case_id": "audit-snapshot", "operation": "audit_snapshot", "input": None, "expected": {"ok": True, "error_code": "", "value": audit["summary"]}},
        {"case_id": "unknown-frame", "operation": "evaluate_frame", "input": "missing", "expected": {"ok": False, "error_code": "frame_unknown", "value": None}},
        {"case_id": "frame-int", "operation": "evaluate_frame", "input": 1, "expected": {"ok": False, "error_code": "input_type_invalid", "value": None}},
        {"case_id": "all-input", "operation": "evaluate_all", "input": [], "expected": {"ok": False, "error_code": "input_type_invalid", "value": None}},
        {"case_id": "audit-input", "operation": "audit_snapshot", "input": {}, "expected": {"ok": False, "error_code": "input_type_invalid", "value": None}},
        {"case_id": "operation-unknown", "operation": "missing", "input": None, "expected": {"ok": False, "error_code": "operation_unknown", "value": None}},
        {"case_id": "operation-int", "operation": 7, "input": None, "expected": {"ok": False, "error_code": "input_type_invalid", "value": None}},
        {"case_id": "operation-null", "operation": None, "input": None, "expected": {"ok": False, "error_code": "input_type_invalid", "value": None}},
        {"case_id": "frame-null", "operation": "evaluate_frame", "input": None, "expected": {"ok": False, "error_code": "input_type_invalid", "value": None}},
    ])
    if len(cases) != 23 or len({item["case_id"] for item in cases}) != 23:
        raise RuntimeError("vector cardinality mismatch")
    return {"schema_version": 1, "artifact_kind": "marnie_prompt_broker_vectors", "vector_id": VECTOR_ID, "profile_id": PROFILE_ID, "cases": cases}


def render(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    documents = build_documents()
    mismatches = []
    for key, path in OUTPUTS.items():
        expected = render(documents[key])
        if args.check:
            if not path.is_file() or path.read_bytes() != expected:
                mismatches.append(path.relative_to(ROOT).as_posix())
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(expected)
    if mismatches:
        print("mismatch: " + ", ".join(mismatches))
        return 1
    for key in ["schema", "profile", "audit", "vectors", "bundle"]:
        print(f"{key}={canonical_hash(documents[key])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
