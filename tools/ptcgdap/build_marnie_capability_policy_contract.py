from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
DATA_ROOT = ROOT / "data/ptcgdap/marnie_vertical_slice"
PROFILE_ID = "marnie_capability_policy_profile_v1"
BUNDLE_ID = "ptcgdap-marnie-capability-policy-p5-wp3-v1"
POLICY_ID = "ptcgdap-marnie-capability-policy-v1"
VECTOR_ID = "ptcgdap-marnie-capability-policy-conformance-v1"
PARENT_REPLAY_HASH = "E203A688BEC1AFFFABAAF06098361B3FAE04B84431F99AE75A19F891BFA9599F"
PARENT_FIXTURE_HASH = "7E0CF80D7B2872C29F69BA15548857F1F32407943371D3C12A266A0E471EC425"
BASE_FIREWALL_HASH = "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947"
RESULT_PREFIX = b"PTCGDAP\0MARNIE_CAPABILITY_POLICY_RESULT_V1\0"
FRAME_IDS = (
    "w0_initial", "w1_setup_active", "w2_setup_bench", "w3_main",
    "w4_spikemuth_deck", "w5_punk_up_sources", "w5_punk_up_target_1",
    "w5_punk_up_target_2", "w6_shadow_bullet_attack", "w6_shadow_bullet_target",
    "w7_take_prize", "w7_forced_send_out", "w7_terminal",
)
CAPABILITIES = (
    "initial_deck", "setup_active", "setup_bench", "main_action_frontier",
    "spikemuth_tutor", "punk_up", "shadow_bullet", "take_prize",
    "forced_send_out", "terminal_without_callback",
)
RULES = (
    ("w0_initial", "initial_deck", "official_initial_deck", None),
    ("w1_setup_active", "setup_active", "first_min", None),
    ("w2_setup_bench", "setup_bench", "optional_zero", None),
    ("w3_main", "main_action_frontier", "first_min", None),
    ("w4_spikemuth_deck", "spikemuth_tutor", "public_deck_card_id", 648),
    ("w5_punk_up_sources", "punk_up", "all_public_deck_card_id", 7),
    ("w5_punk_up_target_1", "punk_up", "first_min", None),
    ("w5_punk_up_target_2", "punk_up", "first_min", None),
    ("w6_shadow_bullet_attack", "shadow_bullet", "official_attack_id", 937),
    ("w6_shadow_bullet_target", "shadow_bullet", "first_min", None),
    ("w7_take_prize", "take_prize", "first_min", None),
    ("w7_forced_send_out", "forced_send_out", "first_min", None),
    ("w7_terminal", "terminal_without_callback", "terminal_no_callback", None),
)
ARTIFACTS = (
    ("marnie_capability_policy_schema_v1", "contracts/ptcgdap/marnie_capability_policy.schema.json", "schema"),
    ("marnie_capability_policy_profile_v1", "contracts/ptcgdap/marnie_capability_policy_profile.json", "profile"),
    ("marnie_capability_policy_rules_v1", "data/ptcgdap/marnie_vertical_slice/marnie_capability_policy_v1.json", "policy"),
    ("marnie_capability_policy_vectors_v1", "contracts/ptcgdap/marnie_capability_policy_conformance_vectors.json", "vectors"),
)


def sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _strict_object(properties: dict[str, Any], required: list[str] | None = None) -> dict[str, Any]:
    return {
        "type": "object",
        "additionalProperties": False,
        "required": required or list(properties),
        "properties": properties,
    }


def build_schema() -> dict[str, Any]:
    sha = {"type": "string", "pattern": "^[0-9A-F]{64}$"}
    safe_int = {"type": "integer", "minimum": -9007199254740991, "maximum": 9007199254740991}
    nonnegative = {"allOf": [{"$ref": "#/$defs/safeInteger"}, {"minimum": 0}]}
    string_enum = lambda values: {"type": "string", "enum": list(values)}
    rule = _strict_object({
        "frame_id": string_enum(FRAME_IDS),
        "capability_id": string_enum(CAPABILITIES),
        "rule_id": string_enum(("official_initial_deck", "first_min", "optional_zero", "public_deck_card_id", "all_public_deck_card_id", "official_attack_id", "terminal_no_callback")),
        "target_official_id": {"oneOf": [{"type": "null"}, {"allOf": [{"$ref": "#/$defs/safeInteger"}, {"minimum": 1}]}]},
    })
    frame_decision = _strict_object({
        "ordinal": nonnegative,
        "frame_id": string_enum(FRAME_IDS),
        "capability_id": string_enum(CAPABILITIES),
        "capability_state": {"const": "source_locked_fixture_only"},
        "status": string_enum(("accepted", "not_applicable_terminal")),
        "reason_code": string_enum(("official_initial_deck_fixture", "deterministic_policy_selected", "terminal_no_callback")),
        "rule_id": string_enum(("official_initial_deck", "first_min", "optional_zero", "public_deck_card_id", "all_public_deck_card_id", "official_attack_id", "terminal_no_callback")),
        "selection_domain": string_enum(("initial_deck_card_ids", "current_window_indexes", "none")),
        "selected_indexes": {"oneOf": [{"type": "null"}, {"type": "array", "uniqueItems": True, "items": nonnegative}]},
        "selected_card_ids": {"oneOf": [{"type": "null"}, {"type": "array", "minItems": 60, "maxItems": 60, "items": {"allOf": [{"$ref": "#/$defs/safeInteger"}, {"minimum": 1}]}}]},
        "public_observation_hash": {"oneOf": [{"type": "null"}, sha]},
        "window_id": {"oneOf": [{"type": "null"}, sha]},
        "option_fingerprints": {"type": "array", "items": sha},
        "previous_decision_hash": {"oneOf": [{"type": "null"}, sha]},
        "decision_hash": sha,
        "production_action_used": {"const": False},
        "execution_authority": {"const": False},
    })
    result = _strict_object({
        "accepted": {"const": True},
        "frame_count": nonnegative,
        "chain_head": sha,
        "frames": {"type": "array", "items": {"$ref": "#/$defs/frameDecision"}},
        "production_actions_used": {"const": False},
        "execution_authority": {"const": False},
    })
    dto = {
        "oneOf": [
            _strict_object({"ok": {"const": True}, "error_code": {"const": ""}, "value": {"$ref": "#/$defs/policyResult"}}),
            _strict_object({
                "ok": {"const": False},
                "error_code": string_enum(("input_type_invalid", "frame_unknown", "operation_unknown", "frame_binding_mismatch", "policy_integrity_invalid")),
                "value": {"type": "null"},
            }),
        ]
    }
    profile = _strict_object({
        "schema_version": {"const": 1}, "artifact_kind": {"const": "profile"}, "profile_id": {"const": PROFILE_ID},
        "parent_replay_bundle_canonical_sha256": sha, "parent_fixture_bundle_canonical_sha256": sha,
        "base_firewall_bundle_canonical_sha256": sha,
        "capability_ids": {"type": "array", "prefixItems": [{"const": value} for value in CAPABILITIES], "items": False, "minItems": len(CAPABILITIES), "maxItems": len(CAPABILITIES)},
        "frame_ids": {"type": "array", "prefixItems": [{"const": value} for value in FRAME_IDS], "items": False, "minItems": len(FRAME_IDS), "maxItems": len(FRAME_IDS)},
        "capability_state": {"const": "source_locked_fixture_only"},
        "result_hash_prefix_utf8_hex": {"const": RESULT_PREFIX.hex().upper()},
        "production_actions_used": {"const": False}, "execution_authority": {"const": False},
        "live_owner": {"const": False}, "portable_ready": {"const": False},
    })
    policy = _strict_object({
        "schema_version": {"const": 1}, "artifact_kind": {"const": "policy"}, "policy_id": {"const": POLICY_ID}, "profile_id": {"const": PROFILE_ID},
        "parent_replay_bundle_canonical_sha256": sha, "parent_fixture_bundle_canonical_sha256": sha,
        "rules": {"type": "array", "prefixItems": [{"$ref": "#/$defs/rule"} for _ in RULES], "items": False, "minItems": len(RULES), "maxItems": len(RULES)},
        "initial_deck_card_ids": {"type": "array", "minItems": 60, "maxItems": 60, "items": {"allOf": [{"$ref": "#/$defs/safeInteger"}, {"minimum": 1}]}},
        "production_actions_used": {"const": False}, "execution_authority": {"const": False},
    })
    evaluate_input = _strict_object({
        "frame_id": {
            "oneOf": [
                {"type": "string"},
                _strict_object({"host_type": {"const": "integer"}, "value": {"$ref": "#/$defs/safeInteger"}}),
            ]
        }
    })
    mutation_input = _strict_object({"frame_id": string_enum(FRAME_IDS), "field": string_enum(("public_observation_hash", "window_id", "option_fingerprints", "options", "min_count", "private_sentinel")), "value": {}})
    vector_case = _strict_object({
        "case_id": {"type": "string", "minLength": 1},
        "operation": string_enum(("evaluate_all", "evaluate_frame", "probe_frame_mutation", "private_sentinel")),
        "input": {"oneOf": [_strict_object({}), evaluate_input, mutation_input]},
        "expected": {"$ref": "#/$defs/dto"},
    })
    vector_case["allOf"] = [
        {"if": {"properties": {"operation": {"const": "evaluate_all"}}}, "then": {"properties": {"input": _strict_object({})}}},
        {"if": {"properties": {"operation": {"const": "evaluate_frame"}}}, "then": {"properties": {"input": evaluate_input}}},
        {"if": {"properties": {"operation": {"const": "probe_frame_mutation"}}}, "then": {"properties": {"input": mutation_input}}},
        {"if": {"properties": {"operation": {"const": "private_sentinel"}}}, "then": {"properties": {"input": _strict_object({})}}},
    ]
    vectors = _strict_object({
        "schema_version": {"const": 1}, "artifact_kind": {"const": "vectors"}, "vector_set_id": {"const": VECTOR_ID}, "profile_id": {"const": PROFILE_ID},
        "cases": {"type": "array", "minItems": 20, "items": {"$ref": "#/$defs/vectorCase"}},
    })
    bundle_entry = _strict_object({"id": {"type": "string", "minLength": 1}, "path": {"type": "string", "pattern": "^(contracts|data)/ptcgdap/[a-z0-9_./-]+\\.json$"}, "canonical_sha256": sha})
    bundle = _strict_object({
        "schema_version": {"const": 1}, "artifact_kind": {"const": "bundle"}, "bundle_id": {"const": BUNDLE_ID}, "status": {"const": "offline_shadow_policy"},
        "parent_replay_bundle": _strict_object({"path": {"const": "contracts/ptcgdap/marnie_trajectory_replay_bundle.json"}, "canonical_sha256": sha}),
        "parent_fixture_bundle": _strict_object({"path": {"const": "contracts/ptcgdap/marnie_vertical_slice_bundle.json"}, "canonical_sha256": sha}),
        "artifacts": {
            "type": "array", "minItems": 4, "maxItems": 4,
            "prefixItems": [
                _strict_object({"id": {"const": artifact_id}, "path": {"const": path}, "canonical_sha256": sha})
                for artifact_id, path, _ in ARTIFACTS
            ],
            "items": False,
        },
        "self_hash_policy": {"const": "bundle and bound artifacts do not contain the final bundle hash"},
    })
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/marnie_capability_policy.schema.json",
        "title": "PtcgDAP Marnie capability policy artifacts",
        "oneOf": [{"$ref": "#/$defs/profileArtifact"}, {"$ref": "#/$defs/policyArtifact"}, {"$ref": "#/$defs/vectorsArtifact"}, {"$ref": "#/$defs/bundleArtifact"}],
        "$defs": {"safeInteger": safe_int, "rule": rule, "frameDecision": frame_decision, "policyResult": result, "dto": dto, "profileArtifact": profile, "policyArtifact": policy, "vectorCase": vector_case, "vectorsArtifact": vectors, "bundleArtifact": bundle},
    }


def _load_sources() -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    parent_bundle = load_json_strict(CONTRACT_ROOT / "marnie_vertical_slice_bundle.json")
    replay_bundle = load_json_strict(CONTRACT_ROOT / "marnie_trajectory_replay_bundle.json")
    if sha256(canonical_json_v1_bytes(parent_bundle)) != PARENT_FIXTURE_HASH:
        raise ValueError("parent fixture bundle drift")
    if sha256(canonical_json_v1_bytes(replay_bundle)) != PARENT_REPLAY_HASH:
        raise ValueError("parent replay bundle drift")
    trajectory = load_json_strict(DATA_ROOT / "w0_w7_public_trajectory_v1.json")
    deck = load_json_strict(DATA_ROOT / "official_deck_manifest_v1.json")
    capabilities = load_json_strict(DATA_ROOT / "capability_inventory_v1.json")
    if tuple(item["capability_id"] for item in capabilities["capabilities"]) != CAPABILITIES:
        raise ValueError("capability inventory drift")
    if tuple(frame["frame_id"] for frame in trajectory["frames"]) != FRAME_IDS:
        raise ValueError("trajectory frame drift")
    if trajectory["initial_deck_action"]["exact_ordered_card_ids"] != deck["ordered_card_ids"]:
        raise ValueError("initial deck source drift")
    return trajectory, deck, capabilities


def build_profile() -> dict[str, Any]:
    return {
        "schema_version": 1, "artifact_kind": "profile", "profile_id": PROFILE_ID,
        "parent_replay_bundle_canonical_sha256": PARENT_REPLAY_HASH,
        "parent_fixture_bundle_canonical_sha256": PARENT_FIXTURE_HASH,
        "base_firewall_bundle_canonical_sha256": BASE_FIREWALL_HASH,
        "capability_ids": list(CAPABILITIES), "frame_ids": list(FRAME_IDS),
        "capability_state": "source_locked_fixture_only",
        "result_hash_prefix_utf8_hex": RESULT_PREFIX.hex().upper(),
        "production_actions_used": False, "execution_authority": False,
        "live_owner": False, "portable_ready": False,
    }


def build_policy(deck: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema_version": 1, "artifact_kind": "policy", "policy_id": POLICY_ID, "profile_id": PROFILE_ID,
        "parent_replay_bundle_canonical_sha256": PARENT_REPLAY_HASH,
        "parent_fixture_bundle_canonical_sha256": PARENT_FIXTURE_HASH,
        "rules": [
            {"frame_id": frame_id, "capability_id": capability_id, "rule_id": rule_id, "target_official_id": target}
            for frame_id, capability_id, rule_id, target in RULES
        ],
        "initial_deck_card_ids": deepcopy(deck["ordered_card_ids"]),
        "production_actions_used": False, "execution_authority": False,
    }


def _select(rule: dict[str, Any], frame: dict[str, Any], deck_ids: list[int]) -> tuple[str, str, list[int] | None, list[int] | None]:
    rule_id = rule["rule_id"]
    window = frame["window"]
    if rule_id == "official_initial_deck":
        return "accepted", "official_initial_deck_fixture", None, deepcopy(deck_ids)
    if rule_id == "terminal_no_callback":
        return "not_applicable_terminal", "terminal_no_callback", None, None
    if type(window) is not dict:
        raise ValueError("regular rule without window")
    if rule_id == "optional_zero":
        indexes: list[int] = []
    elif rule_id == "first_min":
        indexes = list(range(window["min_count"]))
    elif rule_id in {"public_deck_card_id", "all_public_deck_card_id"}:
        candidates = window["public_deck_candidates"]
        matches = [index for index, option in enumerate(window["options"]) if candidates[option["index"]]["id"] == rule["target_official_id"]]
        indexes = matches[:1] if rule_id == "public_deck_card_id" else matches[:window["max_count"]]
    elif rule_id == "official_attack_id":
        indexes = [index for index, option in enumerate(window["options"]) if option.get("attackId") == rule["target_official_id"]][:1]
    else:
        raise ValueError("unknown rule")
    if not (window["min_count"] <= len(indexes) <= window["max_count"] and len(indexes) == len(set(indexes)) and all(type(i) is int and 0 <= i < len(window["options"]) for i in indexes)):
        raise ValueError(f"illegal deterministic selection: {rule['frame_id']}")
    return "accepted", "deterministic_policy_selected", indexes, None


def _decision_hash(value: dict[str, Any]) -> str:
    return sha256(RESULT_PREFIX + canonical_json_v1_bytes(value))


def build_expected_frames(trajectory: dict[str, Any], policy: dict[str, Any]) -> list[dict[str, Any]]:
    rules = {rule["frame_id"]: rule for rule in policy["rules"]}
    frames = {frame["frame_id"]: frame for frame in trajectory["frames"]}
    result = []
    previous: str | None = None
    for ordinal, frame_id in enumerate(FRAME_IDS):
        frame = frames[frame_id]; rule = rules[frame_id]
        status, reason, indexes, cards = _select(rule, frame, policy["initial_deck_card_ids"])
        window = frame["window"]
        value = {
            "ordinal": ordinal, "frame_id": frame_id, "capability_id": rule["capability_id"],
            "capability_state": "source_locked_fixture_only", "status": status, "reason_code": reason,
            "rule_id": rule["rule_id"],
            "selection_domain": "initial_deck_card_ids" if cards is not None else "none" if indexes is None else "current_window_indexes",
            "selected_indexes": indexes, "selected_card_ids": cards,
            "public_observation_hash": frame["public_observation_hash"],
            "window_id": None if window is None else window["window_id"],
            "option_fingerprints": [] if window is None else deepcopy(window["option_fingerprints"]),
            "previous_decision_hash": previous,
            "production_action_used": False, "execution_authority": False,
        }
        value["decision_hash"] = _decision_hash(value)
        previous = value["decision_hash"]
        result.append(value)
    return result


def _dto(value: Any = None, error: str = "") -> dict[str, Any]:
    return {"ok": error == "", "error_code": error, "value": deepcopy(value) if not error else None}


def build_vectors(expected_frames: list[dict[str, Any]]) -> dict[str, Any]:
    cases = []
    for frame in expected_frames:
        cases.append({"case_id": f"frame-{frame['frame_id']}", "operation": "evaluate_frame", "input": {"frame_id": frame["frame_id"]}, "expected": _dto({"accepted": True, "frame_count": 1, "chain_head": frame["decision_hash"], "frames": [frame], "production_actions_used": False, "execution_authority": False})})
    cases.append({"case_id": "all-frames", "operation": "evaluate_all", "input": {}, "expected": _dto({"accepted": True, "frame_count": 13, "chain_head": expected_frames[-1]["decision_hash"], "frames": expected_frames, "production_actions_used": False, "execution_authority": False})})
    cases.extend([
        {"case_id":"frame-type", "operation":"evaluate_frame", "input":{"frame_id":{"host_type":"integer","value":1}}, "expected":_dto(error="input_type_invalid")},
        {"case_id":"frame-unknown", "operation":"evaluate_frame", "input":{"frame_id":"private_sentinel"}, "expected":_dto(error="frame_unknown")},
        {"case_id":"mutate-public-hash", "operation":"probe_frame_mutation", "input":{"frame_id":"w6_shadow_bullet_attack","field":"public_observation_hash","value":"0" * 64}, "expected":_dto(error="frame_binding_mismatch")},
        {"case_id":"mutate-window-id", "operation":"probe_frame_mutation", "input":{"frame_id":"w4_spikemuth_deck","field":"window_id","value":"0" * 64}, "expected":_dto(error="frame_binding_mismatch")},
        {"case_id":"mutate-fingerprints", "operation":"probe_frame_mutation", "input":{"frame_id":"w6_shadow_bullet_target","field":"option_fingerprints","value":[]}, "expected":_dto(error="frame_binding_mismatch")},
        {"case_id":"reorder-options", "operation":"probe_frame_mutation", "input":{"frame_id":"w3_main","field":"options","value":"reverse"}, "expected":_dto(error="frame_binding_mismatch")},
        {"case_id":"mutate-cardinality", "operation":"probe_frame_mutation", "input":{"frame_id":"w1_setup_active","field":"min_count","value":0}, "expected":_dto(error="frame_binding_mismatch")},
        {"case_id":"private-field", "operation":"probe_frame_mutation", "input":{"frame_id":"w3_main","field":"private_sentinel","value":"PRIVATE"}, "expected":_dto(error="input_type_invalid")},
        {"case_id":"operation-unknown", "operation":"private_sentinel", "input":{}, "expected":_dto(error="operation_unknown")},
    ])
    return {"schema_version": 1, "artifact_kind": "vectors", "vector_set_id": VECTOR_ID, "profile_id": PROFILE_ID, "cases": cases}


def build_documents() -> dict[str, dict[str, Any]]:
    trajectory, deck, _ = _load_sources()
    schema = build_schema(); profile = build_profile(); policy = build_policy(deck)
    expected = build_expected_frames(trajectory, policy); vectors = build_vectors(expected)
    documents = {"schema": schema, "profile": profile, "policy": policy, "vectors": vectors}
    entries = [{"id": artifact_id, "path": path, "canonical_sha256": sha256(canonical_json_v1_bytes(documents[key]))} for artifact_id, path, key in ARTIFACTS]
    documents["bundle"] = {
        "schema_version": 1, "artifact_kind": "bundle", "bundle_id": BUNDLE_ID, "status": "offline_shadow_policy",
        "parent_replay_bundle": {"path": "contracts/ptcgdap/marnie_trajectory_replay_bundle.json", "canonical_sha256": PARENT_REPLAY_HASH},
        "parent_fixture_bundle": {"path": "contracts/ptcgdap/marnie_vertical_slice_bundle.json", "canonical_sha256": PARENT_FIXTURE_HASH},
        "artifacts": entries, "self_hash_policy": "bundle and bound artifacts do not contain the final bundle hash",
    }
    return documents


def _render(value: dict[str, Any]) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2, separators=(",", ": ")) + "\n").encode("utf-8")


def output_paths() -> dict[str, Path]:
    return {
        "schema": CONTRACT_ROOT / "marnie_capability_policy.schema.json",
        "profile": CONTRACT_ROOT / "marnie_capability_policy_profile.json",
        "policy": DATA_ROOT / "marnie_capability_policy_v1.json",
        "vectors": CONTRACT_ROOT / "marnie_capability_policy_conformance_vectors.json",
        "bundle": CONTRACT_ROOT / "marnie_capability_policy_bundle.json",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    documents = build_documents(); mismatches = []
    for key, path in output_paths().items():
        expected = _render(documents[key])
        if args.check:
            if not path.is_file() or path.read_bytes() != expected:
                mismatches.append(path.as_posix())
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(expected)
    bundle_raw = _render(documents["bundle"])
    print(json.dumps({"bundle_raw_sha256": sha256(bundle_raw), "bundle_canonical_sha256": sha256(canonical_json_v1_bytes(documents["bundle"])), "artifact_count": 4, "frame_count": 13, "vector_count": len(documents["vectors"]["cases"]), "mismatches": mismatches}, separators=(",", ":")))
    return 1 if mismatches else 0


if __name__ == "__main__":
    raise SystemExit(main())
