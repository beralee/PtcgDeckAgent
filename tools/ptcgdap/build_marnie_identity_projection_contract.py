from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import struct
import sys
from typing import Any, Iterable

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
DATA_ROOT = ROOT / "data/ptcgdap/marnie_vertical_slice"
CATALOG_DATA_ROOT = ROOT / "data/ptcgdap/card_id_catalog"
PROFILE_ID = "marnie_identity_projection_profile_v1"
AUDIT_ID = "ptcgdap-marnie-identity-projection-audit-v1"
VECTOR_ID = "ptcgdap-marnie-identity-projection-conformance-v1"
BUNDLE_ID = "ptcgdap-marnie-identity-projection-p5-wp4-v1"
PARENT_FIXTURE_HASH = "7E0CF80D7B2872C29F69BA15548857F1F32407943371D3C12A266A0E471EC425"
PARENT_POLICY_HASH = "F4E88E5DB4E480BA8441BE7B3A7C81CE3DB40ED1917EB37BCDCAC1C32B1ABD6C"
CATALOG_HASH = "AB8CF10465F492A98DA8247A84572AECEE281D0726F7BB7B8E5DBC03A6AC70D4"
PROJECTOR_HASH = "C51EA4CF1AEFCBB5B9C6D83825FF3A717CCDCC4105B804210BF6169372619041"
SOURCE_LOCK_HASH = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
FRAME_IDS = (
    "w0_initial", "w1_setup_active", "w2_setup_bench", "w3_main",
    "w4_spikemuth_deck", "w5_punk_up_sources", "w5_punk_up_target_1",
    "w5_punk_up_target_2", "w6_shadow_bullet_attack", "w6_shadow_bullet_target",
    "w7_take_prize", "w7_forced_send_out", "w7_terminal",
)
FORBIDDEN_PUBLIC_KEYS = frozenset((
    "search_begin_input", "raw_private_hash", "token_free_callback_hash",
    "host_pokemon_entity", "host_pokemon_entity_serial", "instance_id",
    "object_id", "private_sentinel",
))
MUTATIONS = (
    "card_unknown", "serial_relation_conflict", "player_index_invalid",
    "attack_unknown", "attack_owner_mismatch", "hidden_private_key",
    "host_entity_key",
)
ERROR_CODES = (
    "input_type_invalid", "frame_unknown", "frame_identity_invalid",
    "official_card_unknown", "official_attack_unknown", "attack_owner_mismatch",
    "serial_relation_conflict", "hidden_identity_present", "host_entity_present",
    "operation_unknown", "identity_integrity_invalid",
)
ARTIFACTS = (
    ("marnie_identity_projection_schema_v1", "contracts/ptcgdap/marnie_identity_projection.schema.json", "schema"),
    ("marnie_identity_projection_profile_v1", "contracts/ptcgdap/marnie_identity_projection_profile.json", "profile"),
    ("marnie_identity_projection_audit_v1", "data/ptcgdap/marnie_vertical_slice/marnie_identity_projection_v1.json", "audit"),
    ("marnie_identity_projection_vectors_v1", "contracts/ptcgdap/marnie_identity_projection_conformance_vectors.json", "vectors"),
)
MAX_SAFE_INTEGER = 9007199254740991


def sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _canonical_hash(path: Path) -> str:
    return sha256(canonical_json_v1_bytes(load_json_strict(path)))


def _require_hash(path: Path, expected: str, label: str) -> dict[str, Any]:
    value = load_json_strict(path)
    if sha256(canonical_json_v1_bytes(value)) != expected:
        raise ValueError(f"{label} drift")
    if type(value) is not dict:
        raise ValueError(f"{label} not object")
    return value


def _decode_node(node: Any) -> Any:
    if type(node) is not dict or type(node.get("kind")) is not str:
        raise ValueError("encoded public tree invalid")
    kind = node["kind"]
    if kind == "null":
        return None
    if kind in {"boolean", "integer", "string"}:
        return deepcopy(node.get("value"))
    if kind == "array":
        if type(node.get("items")) is not list:
            raise ValueError("encoded public array invalid")
        return [_decode_node(child) for child in node["items"]]
    if kind == "binary64":
        raw = node.get("ieee754_hex")
        if type(raw) is not str or len(raw) != 16:
            raise ValueError("encoded binary64 invalid")
        try:
            return struct.unpack(">d", bytes.fromhex(raw))[0]
        except (ValueError, struct.error) as exc:
            raise ValueError("encoded binary64 invalid") from exc
    if kind == "object":
        if type(node.get("entries")) is not list:
            raise ValueError("encoded public object invalid")
        result: dict[str, Any] = {}
        for entry in node["entries"]:
            if type(entry) is not dict or set(entry) != {"key", "value"} or type(entry["key"]) is not str or entry["key"] in result:
                raise ValueError("encoded public object entry invalid")
            result[entry["key"]] = _decode_node(entry["value"])
        return result
    raise ValueError("encoded public node kind invalid")


def _walk(value: Any) -> Iterable[dict[str, Any]]:
    if type(value) is dict:
        yield value
        for child in value.values():
            yield from _walk(child)
    elif type(value) is list:
        for child in value:
            yield from _walk(child)


def _all_keys(value: Any) -> set[str]:
    keys: set[str] = set()
    for item in _walk(value):
        keys.update(item)
    return keys


def _is_positive_safe_int(value: Any) -> bool:
    return type(value) is int and 0 < value <= MAX_SAFE_INTEGER


def _identity_tuple(item: dict[str, Any]) -> tuple[int, int, int] | None:
    if not all(key in item for key in ("serial", "playerIndex")):
        return None
    if "id" in item:
        official_id = item["id"]
    elif "cardId" in item:
        official_id = item["cardId"]
    else:
        return None
    serial = item["serial"]
    player = item["playerIndex"]
    if not _is_positive_safe_int(official_id) or not _is_positive_safe_int(serial) or type(player) is not int or player not in (0, 1):
        raise ValueError("frame identity invalid")
    return official_id, serial, player


def _audit_tree(
    tree: dict[str, Any], visibility: dict[str, Any], cards: dict[int, dict[str, Any]],
    attacks: dict[int, dict[str, Any]], mapped_ids: set[int],
) -> tuple[dict[str, Any], dict[int, tuple[int, int]]]:
    keys = _all_keys(tree)
    if keys & {"host_pokemon_entity", "host_pokemon_entity_serial"}:
        raise ValueError("host entity present")
    if keys & FORBIDDEN_PUBLIC_KEYS:
        raise ValueError("hidden identity present")
    if (
        type(visibility) is not dict
        or visibility.get("opponent_hand_hidden") is not True
        or visibility.get("prizes_concealed") is not True
        or visibility.get("opponent_draw_identity_absent") is not True
    ):
        raise ValueError("visibility evidence invalid")

    relations: dict[int, tuple[int, int]] = {}
    ids: set[int] = set()
    attack_ids: set[int] = set()
    attack_owner_pairs: set[tuple[int, int]] = set()
    occurrence_count = 0
    evolved_count = 0
    pre_evolution_count = 0
    for item in _walk(tree):
        identity = _identity_tuple(item)
        if identity is not None:
            official_id, serial, player = identity
            if official_id not in cards:
                raise ValueError("official card unknown")
            previous = relations.get(serial)
            if previous is not None and previous != (official_id, player):
                raise ValueError("serial relation conflict")
            relations[serial] = (official_id, player)
            ids.add(official_id)
            occurrence_count += 1
        if "attackId" in item:
            attack_id = item["attackId"]
            if not _is_positive_safe_int(attack_id) or attack_id not in attacks:
                raise ValueError("official attack unknown")
            attack = attacks[attack_id]
            owner = attack["owner_official_card_id"]
            if "cardId" in item and item["cardId"] != owner:
                raise ValueError("attack owner mismatch")
            attack_ids.add(attack_id)
            attack_owner_pairs.add((attack_id, owner))
        pre = item.get("preEvolution")
        if type(pre) is list and pre:
            identity = _identity_tuple(item)
            if identity is None:
                raise ValueError("evolved Pokemon identity invalid")
            top_serial = identity[1]
            evolved_count += 1
            pre_evolution_count += len(pre)
            for child in pre:
                if type(child) is not dict:
                    raise ValueError("pre-evolution card invalid")
                child_identity = _identity_tuple(child)
                if child_identity is None or child_identity[1] == top_serial or child_identity[2] != identity[2]:
                    raise ValueError("top serial equals pre-evolution serial")

    return ({
        "identity_occurrence_count": occurrence_count,
        "unique_serial_count": len(relations),
        "distinct_official_card_ids": sorted(ids),
        "mapped_official_card_ids": sorted(ids & mapped_ids),
        "known_unmapped_official_card_ids": sorted(ids - mapped_ids),
        "official_attack_ids": sorted(attack_ids),
        "attack_owner_pairs": [
            {"official_attack_id": attack_id, "owner_official_card_id": owner}
            for attack_id, owner in sorted(attack_owner_pairs)
        ],
        "evolved_pokemon_count": evolved_count,
        "pre_evolution_card_count": pre_evolution_count,
        "serial_relation_consistent": True,
        "top_serial_distinct_from_pre_evolution": True,
        "hidden_identity_absent": True,
        "host_entity_absent": True,
    }, relations)


def _load_sources() -> dict[str, Any]:
    fixture_bundle = _require_hash(CONTRACT_ROOT / "marnie_vertical_slice_bundle.json", PARENT_FIXTURE_HASH, "parent fixture bundle")
    policy_bundle = _require_hash(CONTRACT_ROOT / "marnie_capability_policy_bundle.json", PARENT_POLICY_HASH, "parent policy bundle")
    catalog_bundle = _require_hash(CONTRACT_ROOT / "card_id_catalog_bundle.json", CATALOG_HASH, "card catalog bundle")
    projector_bundle = _require_hash(CONTRACT_ROOT / "godot_observation_projector_bundle.json", PROJECTOR_HASH, "projector bundle")
    trajectory = load_json_strict(DATA_ROOT / "w0_w7_public_trajectory_v1.json")
    official_deck = load_json_strict(DATA_ROOT / "official_deck_manifest_v1.json")
    local_deck = load_json_strict(DATA_ROOT / "local_deck_manifest_v1.json")
    master = load_json_strict(CATALOG_DATA_ROOT / "official_card_attack_master_v1.json")
    bridge = load_json_strict(CATALOG_DATA_ROOT / "marnie_exact_print_bridge_v1.json")
    if type(trajectory) is not dict or tuple(frame["frame_id"] for frame in trajectory["frames"]) != FRAME_IDS:
        raise ValueError("trajectory frame drift")
    if type(master) is not dict or len(master.get("cards", [])) != 1267 or len(master.get("attacks", [])) != 1556:
        raise ValueError("catalog master count drift")
    if type(bridge) is not dict or len(bridge.get("entries", [])) != 9:
        raise ValueError("catalog bridge count drift")
    return {
        "fixture_bundle": fixture_bundle, "policy_bundle": policy_bundle,
        "catalog_bundle": catalog_bundle, "projector_bundle": projector_bundle,
        "trajectory": trajectory, "official_deck": official_deck, "local_deck": local_deck,
        "master": master, "bridge": bridge,
    }


def build_audit(sources: dict[str, Any]) -> dict[str, Any]:
    cards = {item["official_card_id"]: item for item in sources["master"]["cards"]}
    attacks = {item["official_attack_id"]: item for item in sources["master"]["attacks"]}
    if len(cards) != 1267 or len(attacks) != 1556:
        raise ValueError("catalog identity collision")
    mapped_ids = {item["official_card_id"] for item in sources["bridge"]["entries"]}
    if len(mapped_ids) != 9:
        raise ValueError("bridge identity collision")

    frames = []
    cross_relations: dict[int, tuple[int, int]] = {}
    all_ids: set[int] = set()
    all_attacks: set[int] = set()
    total_occurrences = 0
    for ordinal, source_frame in enumerate(sources["trajectory"]["frames"]):
        frame_id = source_frame["frame_id"]
        if source_frame["public_tree"] is None:
            if frame_id != "w7_terminal" or source_frame["public_observation_hash"] is not None:
                raise ValueError("terminal frame drift")
            detail = {
                "identity_occurrence_count": 0, "unique_serial_count": 0,
                "distinct_official_card_ids": [], "mapped_official_card_ids": [],
                "known_unmapped_official_card_ids": [], "official_attack_ids": [],
                "attack_owner_pairs": [], "evolved_pokemon_count": 0,
                "pre_evolution_card_count": 0, "serial_relation_consistent": True,
                "top_serial_distinct_from_pre_evolution": True,
                "hidden_identity_absent": True, "host_entity_absent": True,
            }
            relations: dict[int, tuple[int, int]] = {}
            status = "terminal_no_observation"
        else:
            tree = _decode_node(source_frame["public_tree"])
            if type(tree) is not dict:
                raise ValueError("public frame not object")
            detail, relations = _audit_tree(tree, source_frame["visibility"], cards, attacks, mapped_ids)
            status = "verified_public_identity"
        for serial, relation in relations.items():
            previous = cross_relations.get(serial)
            if previous is not None and previous != relation:
                raise ValueError("cross-frame serial relation conflict")
            cross_relations[serial] = relation
        all_ids.update(detail["distinct_official_card_ids"])
        all_attacks.update(detail["official_attack_ids"])
        total_occurrences += detail["identity_occurrence_count"]
        frames.append({
            "ordinal": ordinal, "frame_id": frame_id, "status": status,
            "public_observation_hash": source_frame["public_observation_hash"],
            **detail,
        })

    deck_ids = sources["official_deck"]["ordered_card_ids"]
    if type(deck_ids) is not list or len(deck_ids) != 60 or any(type(value) is not int or value not in cards for value in deck_ids):
        raise ValueError("official deck identity drift")
    deck_unique = set(deck_ids)
    deck_mapped = deck_unique & mapped_ids
    deck_unmapped = deck_unique - mapped_ids
    summary = {
        "frame_count": 13,
        "public_frame_count": 12,
        "terminal_frame_count": 1,
        "identity_occurrence_count": total_occurrences,
        "cross_frame_unique_serial_count": len(cross_relations),
        "distinct_official_card_ids": sorted(all_ids),
        "mapped_official_card_ids": sorted(all_ids & mapped_ids),
        "known_unmapped_official_card_ids": sorted(all_ids - mapped_ids),
        "official_attack_ids": sorted(all_attacks),
        "cross_frame_serial_relation_consistent": True,
        "hidden_identity_absent": True,
        "host_entity_absent": True,
        "official_deck_card_count": 60,
        "official_deck_unique_card_id_count": len(deck_unique),
        "official_deck_mapped_unique_card_id_count": len(deck_mapped),
        "official_deck_known_unmapped_unique_card_id_count": len(deck_unmapped),
        "official_deck_mapped_card_count": sum(value in mapped_ids for value in deck_ids),
        "official_deck_known_unmapped_card_count": sum(value not in mapped_ids for value in deck_ids),
        "local_800018501_cabt_exportable": sources["local_deck"].get("cabt_exportable") is True,
    }
    if (
        summary["identity_occurrence_count"] != 573
        or summary["cross_frame_unique_serial_count"] != 94
        or len(all_ids) != 34
        or len(all_ids & mapped_ids) != 9
        or len(deck_unique) != 19
        or len(deck_mapped) != 9
        or summary["official_deck_mapped_card_count"] != 34
        or summary["local_800018501_cabt_exportable"] is not False
    ):
        raise ValueError("locked identity summary drift")
    return {
        "schema_version": 1, "artifact_kind": "frame_audit", "audit_id": AUDIT_ID,
        "profile_id": PROFILE_ID,
        "source_trajectory_artifact_id": sources["trajectory"]["artifact_id"],
        "source_trajectory_canonical_sha256": sha256(canonical_json_v1_bytes(sources["trajectory"])),
        "official_deck_artifact_id": sources["official_deck"]["artifact_id"],
        "official_deck_canonical_sha256": sha256(canonical_json_v1_bytes(sources["official_deck"])),
        "frames": frames, "summary": summary,
        "production_actions_used": False, "execution_authority": False,
    }


def build_profile() -> dict[str, Any]:
    return {
        "schema_version": 1, "artifact_kind": "profile", "profile_id": PROFILE_ID,
        "parent_fixture_bundle_canonical_sha256": PARENT_FIXTURE_HASH,
        "parent_capability_policy_bundle_canonical_sha256": PARENT_POLICY_HASH,
        "card_catalog_bundle_canonical_sha256": CATALOG_HASH,
        "projector_bundle_canonical_sha256": PROJECTOR_HASH,
        "source_lock_canonical_sha256": SOURCE_LOCK_HASH,
        "frame_ids": list(FRAME_IDS),
        "identity_authority": "official_master_plus_explicit_source_hashed_bridge_only",
        "serial_relation": "official_wire_serial_is_physical_card_identity_not_host_entity_identity",
        "unknown_mapping_policy": "known_official_unmapped_preserved_without_inference",
        "engine_projection_gate": "godot_owner_result_revalidated_against_exact_projector_and_public_tree",
        "serialization_authority": "audit_and_conformance_only_never_execution_authority",
        "production_actions_used": False, "execution_authority": False,
        "live_owner": False, "portable_ready": False,
    }


def _success(value: Any) -> dict[str, Any]:
    return {"ok": True, "error_code": "", "value": deepcopy(value)}


def _failure(code: str) -> dict[str, Any]:
    return {"ok": False, "error_code": code, "value": None}


def _audit_result(audit: dict[str, Any], frames: list[dict[str, Any]], operation: str) -> dict[str, Any]:
    return {
        "accepted": True, "operation": operation, "frame_count": len(frames),
        "frames": deepcopy(frames),
        "summary": deepcopy(audit["summary"]) if operation == "audit_all" else None,
        "production_actions_used": False, "execution_authority": False,
    }


def build_vectors(audit: dict[str, Any]) -> dict[str, Any]:
    cases = [{"case_id": "audit-all", "operation": "audit_all", "input": {}, "expected": _success(_audit_result(audit, audit["frames"], "audit_all"))}]
    for frame in audit["frames"]:
        cases.append({
            "case_id": f"frame-{frame['frame_id']}", "operation": "audit_frame",
            "input": {"frame_id": frame["frame_id"]},
            "expected": _success(_audit_result(audit, [frame], "audit_frame")),
        })
    cases.extend([
        {"case_id": "frame-type", "operation": "audit_frame", "input": {"frame_id": {"host_type": "integer", "value": 1}}, "expected": _failure("input_type_invalid")},
        {"case_id": "frame-unknown", "operation": "audit_frame", "input": {"frame_id": "private_sentinel"}, "expected": _failure("frame_unknown")},
    ])
    errors = {
        "card_unknown": "official_card_unknown",
        "serial_relation_conflict": "serial_relation_conflict",
        "player_index_invalid": "frame_identity_invalid",
        "attack_unknown": "official_attack_unknown",
        "attack_owner_mismatch": "attack_owner_mismatch",
        "hidden_private_key": "hidden_identity_present",
        "host_entity_key": "host_entity_present",
    }
    for mutation in MUTATIONS:
        cases.append({
            "case_id": f"mutation-{mutation.replace('_', '-')}",
            "operation": "probe_frame_mutation",
            "input": {"frame_id": "w6_shadow_bullet_target", "mutation": mutation},
            "expected": _failure(errors[mutation]),
        })
    if len(cases) != 23:
        raise AssertionError("vector count drift")
    return {
        "schema_version": 1, "artifact_kind": "vectors", "vector_set_id": VECTOR_ID,
        "profile_id": PROFILE_ID, "cases": cases,
    }


def _strict(properties: dict[str, Any], required: list[str] | None = None) -> dict[str, Any]:
    return {"type": "object", "additionalProperties": False, "required": required or list(properties), "properties": properties}


def build_schema(audit: dict[str, Any]) -> dict[str, Any]:
    sha = {"type": "string", "pattern": "^[0-9A-F]{64}$"}
    safe_int = {"type": "integer", "minimum": -MAX_SAFE_INTEGER, "maximum": MAX_SAFE_INTEGER}
    nonnegative = {"allOf": [{"$ref": "#/$defs/safeInteger"}, {"minimum": 0}]}
    positive = {"allOf": [{"$ref": "#/$defs/safeInteger"}, {"minimum": 1}]}
    positive_array = {"type": "array", "uniqueItems": True, "items": positive}
    attack_pair = _strict({"official_attack_id": positive, "owner_official_card_id": positive})
    frame = _strict({
        "ordinal": nonnegative, "frame_id": {"type": "string", "enum": list(FRAME_IDS)},
        "status": {"enum": ["verified_public_identity", "terminal_no_observation"]},
        "public_observation_hash": {"oneOf": [sha, {"type": "null"}]},
        "identity_occurrence_count": nonnegative, "unique_serial_count": nonnegative,
        "distinct_official_card_ids": positive_array, "mapped_official_card_ids": positive_array,
        "known_unmapped_official_card_ids": positive_array, "official_attack_ids": positive_array,
        "attack_owner_pairs": {"type": "array", "uniqueItems": True, "items": attack_pair},
        "evolved_pokemon_count": nonnegative, "pre_evolution_card_count": nonnegative,
        "serial_relation_consistent": {"const": True},
        "top_serial_distinct_from_pre_evolution": {"const": True},
        "hidden_identity_absent": {"const": True}, "host_entity_absent": {"const": True},
    })
    summary = _strict({
        "frame_count": nonnegative, "public_frame_count": nonnegative, "terminal_frame_count": nonnegative,
        "identity_occurrence_count": nonnegative, "cross_frame_unique_serial_count": nonnegative,
        "distinct_official_card_ids": positive_array, "mapped_official_card_ids": positive_array,
        "known_unmapped_official_card_ids": positive_array, "official_attack_ids": positive_array,
        "cross_frame_serial_relation_consistent": {"const": True},
        "hidden_identity_absent": {"const": True}, "host_entity_absent": {"const": True},
        "official_deck_card_count": nonnegative, "official_deck_unique_card_id_count": nonnegative,
        "official_deck_mapped_unique_card_id_count": nonnegative,
        "official_deck_known_unmapped_unique_card_id_count": nonnegative,
        "official_deck_mapped_card_count": nonnegative,
        "official_deck_known_unmapped_card_count": nonnegative,
        "local_800018501_cabt_exportable": {"const": False},
    })
    result = _strict({
        "accepted": {"const": True}, "operation": {"enum": ["audit_all", "audit_frame"]},
        "frame_count": nonnegative, "frames": {"type": "array", "items": {"$ref": "#/$defs/frameRecord"}},
        "summary": {"oneOf": [{"$ref": "#/$defs/summaryRecord"}, {"type": "null"}]},
        "production_actions_used": {"const": False}, "execution_authority": {"const": False},
    })
    dto = {"oneOf": [
        _strict({"ok": {"const": True}, "error_code": {"const": ""}, "value": {"$ref": "#/$defs/auditResult"}}),
        _strict({"ok": {"const": False}, "error_code": {"type": "string", "enum": list(ERROR_CODES)}, "value": {"type": "null"}}),
    ]}
    profile = _strict({
        "schema_version": {"const": 1}, "artifact_kind": {"const": "profile"}, "profile_id": {"const": PROFILE_ID},
        "parent_fixture_bundle_canonical_sha256": sha, "parent_capability_policy_bundle_canonical_sha256": sha,
        "card_catalog_bundle_canonical_sha256": sha, "projector_bundle_canonical_sha256": sha,
        "source_lock_canonical_sha256": sha,
        "frame_ids": {"type": "array", "prefixItems": [{"const": value} for value in FRAME_IDS], "items": False, "minItems": 13, "maxItems": 13},
        "identity_authority": {"const": "official_master_plus_explicit_source_hashed_bridge_only"},
        "serial_relation": {"const": "official_wire_serial_is_physical_card_identity_not_host_entity_identity"},
        "unknown_mapping_policy": {"const": "known_official_unmapped_preserved_without_inference"},
        "engine_projection_gate": {"const": "godot_owner_result_revalidated_against_exact_projector_and_public_tree"},
        "serialization_authority": {"const": "audit_and_conformance_only_never_execution_authority"},
        "production_actions_used": {"const": False}, "execution_authority": {"const": False},
        "live_owner": {"const": False}, "portable_ready": {"const": False},
    })
    exact_frames = {
        "type": "array", "minItems": 13, "maxItems": 13,
        "prefixItems": [{"allOf": [{"$ref": "#/$defs/frameRecord"}, {"const": frame_value}]} for frame_value in audit["frames"]],
        "items": False,
    }
    audit_artifact = _strict({
        "schema_version": {"const": 1}, "artifact_kind": {"const": "frame_audit"}, "audit_id": {"const": AUDIT_ID},
        "profile_id": {"const": PROFILE_ID}, "source_trajectory_artifact_id": {"type": "string", "minLength": 1},
        "source_trajectory_canonical_sha256": sha, "official_deck_artifact_id": {"type": "string", "minLength": 1},
        "official_deck_canonical_sha256": sha, "frames": exact_frames,
        "summary": {"allOf": [{"$ref": "#/$defs/summaryRecord"}, {"const": audit["summary"]}]},
        "production_actions_used": {"const": False}, "execution_authority": {"const": False},
    })
    frame_input = _strict({"frame_id": {"oneOf": [{"type": "string"}, _strict({"host_type": {"const": "integer"}, "value": safe_int})]}})
    mutation_input = _strict({"frame_id": {"type": "string", "enum": list(FRAME_IDS)}, "mutation": {"type": "string", "enum": list(MUTATIONS)}})
    vector_case = _strict({
        "case_id": {"type": "string", "minLength": 1},
        "operation": {"enum": ["audit_all", "audit_frame", "probe_frame_mutation"]},
        "input": {"oneOf": [_strict({}), frame_input, mutation_input]},
        "expected": {"$ref": "#/$defs/dto"},
    })
    vector_case["allOf"] = [
        {"if": {"properties": {"operation": {"const": "audit_all"}}}, "then": {"properties": {"input": _strict({})}}},
        {"if": {"properties": {"operation": {"const": "audit_frame"}}}, "then": {"properties": {"input": frame_input}}},
        {"if": {"properties": {"operation": {"const": "probe_frame_mutation"}}}, "then": {"properties": {"input": mutation_input}}},
    ]
    vectors = _strict({
        "schema_version": {"const": 1}, "artifact_kind": {"const": "vectors"}, "vector_set_id": {"const": VECTOR_ID},
        "profile_id": {"const": PROFILE_ID}, "cases": {"type": "array", "minItems": 23, "maxItems": 23, "items": {"$ref": "#/$defs/vectorCase"}},
    })
    bundle = _strict({
        "schema_version": {"const": 1}, "artifact_kind": {"const": "bundle"}, "bundle_id": {"const": BUNDLE_ID},
        "status": {"const": "offline_shadow_identity_projection_gate"},
        "parent_fixture_bundle": _strict({"path": {"const": "contracts/ptcgdap/marnie_vertical_slice_bundle.json"}, "canonical_sha256": sha}),
        "parent_capability_policy_bundle": _strict({"path": {"const": "contracts/ptcgdap/marnie_capability_policy_bundle.json"}, "canonical_sha256": sha}),
        "card_catalog_bundle": _strict({"path": {"const": "contracts/ptcgdap/card_id_catalog_bundle.json"}, "canonical_sha256": sha}),
        "projector_bundle": _strict({"path": {"const": "contracts/ptcgdap/godot_observation_projector_bundle.json"}, "canonical_sha256": sha}),
        "artifacts": {
            "type": "array", "minItems": 4, "maxItems": 4,
            "prefixItems": [_strict({"id": {"const": artifact_id}, "path": {"const": path}, "canonical_sha256": sha}) for artifact_id, path, _ in ARTIFACTS],
            "items": False,
        },
        "self_hash_policy": {"const": "bundle and bound artifacts do not contain the final bundle hash"},
    })
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/marnie_identity_projection.schema.json",
        "title": "PtcgDAP Marnie identity and projection shadow gate artifacts",
        "oneOf": [{"$ref": "#/$defs/profileArtifact"}, {"$ref": "#/$defs/auditArtifact"}, {"$ref": "#/$defs/vectorsArtifact"}, {"$ref": "#/$defs/bundleArtifact"}],
        "$defs": {
            "safeInteger": safe_int, "attackOwnerPair": attack_pair, "frameRecord": frame,
            "summaryRecord": summary, "auditResult": result, "dto": dto,
            "profileArtifact": profile, "auditArtifact": audit_artifact,
            "vectorCase": vector_case, "vectorsArtifact": vectors, "bundleArtifact": bundle,
        },
    }


def build_documents() -> dict[str, dict[str, Any]]:
    sources = _load_sources()
    audit = build_audit(sources)
    profile = build_profile()
    vectors = build_vectors(audit)
    schema = build_schema(audit)
    documents = {"schema": schema, "profile": profile, "audit": audit, "vectors": vectors}
    documents["bundle"] = {
        "schema_version": 1, "artifact_kind": "bundle", "bundle_id": BUNDLE_ID,
        "status": "offline_shadow_identity_projection_gate",
        "parent_fixture_bundle": {"path": "contracts/ptcgdap/marnie_vertical_slice_bundle.json", "canonical_sha256": PARENT_FIXTURE_HASH},
        "parent_capability_policy_bundle": {"path": "contracts/ptcgdap/marnie_capability_policy_bundle.json", "canonical_sha256": PARENT_POLICY_HASH},
        "card_catalog_bundle": {"path": "contracts/ptcgdap/card_id_catalog_bundle.json", "canonical_sha256": CATALOG_HASH},
        "projector_bundle": {"path": "contracts/ptcgdap/godot_observation_projector_bundle.json", "canonical_sha256": PROJECTOR_HASH},
        "artifacts": [
            {"id": artifact_id, "path": path, "canonical_sha256": sha256(canonical_json_v1_bytes(documents[key]))}
            for artifact_id, path, key in ARTIFACTS
        ],
        "self_hash_policy": "bundle and bound artifacts do not contain the final bundle hash",
    }
    return documents


def _render(value: dict[str, Any]) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2, separators=(",", ": ")) + "\n").encode("utf-8")


def output_paths() -> dict[str, Path]:
    return {
        "schema": CONTRACT_ROOT / "marnie_identity_projection.schema.json",
        "profile": CONTRACT_ROOT / "marnie_identity_projection_profile.json",
        "audit": DATA_ROOT / "marnie_identity_projection_v1.json",
        "vectors": CONTRACT_ROOT / "marnie_identity_projection_conformance_vectors.json",
        "bundle": CONTRACT_ROOT / "marnie_identity_projection_bundle.json",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    documents = build_documents()
    mismatches = []
    for key, path in output_paths().items():
        expected = _render(documents[key])
        if args.check:
            if not path.is_file() or path.read_bytes() != expected:
                mismatches.append(path.as_posix())
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(expected)
    bundle_raw = _render(documents["bundle"])
    print(json.dumps({
        "bundle_raw_sha256": sha256(bundle_raw),
        "bundle_canonical_sha256": sha256(canonical_json_v1_bytes(documents["bundle"])),
        "artifact_count": 4, "frame_count": 13, "vector_count": 23,
        "mismatches": mismatches,
    }, separators=(",", ":")))
    return 1 if mismatches else 0


if __name__ == "__main__":
    raise SystemExit(main())
