from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import struct
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.cabt_envelope import parse_raw_cabt_json_bytes
from scripts.ai.ptcgdap.cabt_selection import build_cabt_selection_window
from scripts.ai.ptcgdap.marnie_vertical_slice import MarnieVerticalSlice
from scripts.ai.ptcgdap.public_observation_firewall import PublicObservationFirewall
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, sha256_bytes


PROFILE_ID = "marnie_trajectory_replay_profile_v1"
BUNDLE_ID = "ptcgdap-marnie-trajectory-replay-p5-wp2-v1"
PARENT_FIXTURE_HASH = "7E0CF80D7B2872C29F69BA15548857F1F32407943371D3C12A266A0E471EC425"
BASE_FIREWALL_HASH = "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947"
PARENT_MANIFEST_HASH = "673E47F897028AC4BA322818047290BBE5D5FC28E304918F32A73410A520F944"
CHAIN_PREFIX = b"PTCGDAP\0MARNIE_TRAJECTORY_REPLAY_V1\0"

PATHS = {
    "schema": ROOT / "contracts/ptcgdap/marnie_trajectory_replay.schema.json",
    "profile": ROOT / "contracts/ptcgdap/marnie_trajectory_replay_profile.json",
    "vectors": ROOT / "contracts/ptcgdap/marnie_trajectory_replay_conformance_vectors.json",
    "replay": ROOT / "data/ptcgdap/marnie_vertical_slice/w0_w7_firewall_replay_v1.json",
    "bundle": ROOT / "contracts/ptcgdap/marnie_trajectory_replay_bundle.json",
}


def _decode_node(node: Any) -> Any:
    if node is None:
        return None
    if type(node) is not dict or type(node.get("kind")) is not str:
        raise ValueError("typed public node invalid")
    kind = node["kind"]
    if kind == "null":
        return None
    if kind in {"boolean", "integer", "string"}:
        return node["value"]
    if kind == "binary64":
        return struct.unpack(">d", bytes.fromhex(node["ieee754_hex"]))[0]
    if kind == "array":
        return [_decode_node(child) for child in node["items"]]
    if kind == "object":
        return {entry["key"]: _decode_node(entry["value"]) for entry in node["entries"]}
    raise ValueError("typed public node kind invalid")


def _raw_bytes(public_tree: dict[str, Any]) -> bytes:
    raw = deepcopy(public_tree)
    raw["search_begin_input"] = None
    return json.dumps(raw, ensure_ascii=False, allow_nan=False, separators=(",", ":")).encode("utf-8")


def _witness(payload: dict[str, Any]) -> str:
    return hashlib.sha256(CHAIN_PREFIX + canonical_json_v1_bytes(payload)).hexdigest().upper()


def _frame_summary(
    owner: MarnieVerticalSlice,
    firewall: PublicObservationFirewall,
    frame_id: str,
    ordinal: int,
    previous_witness: str | None,
) -> dict[str, Any]:
    parent = owner.frame(frame_id)
    if parent["public_tree"] is None:
        if parent["terminal"] != {
            "new_callback_expected": False,
            "final_step": 145,
            "both_seats_done": True,
        } or parent["window"] is not None:
            raise ValueError("only terminal frame may omit public tree")
        summary = {
            "ordinal": ordinal,
            "frame_id": frame_id,
            "source_replay_id": parent["source_replay_id"],
            "source_step": parent["source_step"],
            "source_seat": parent["source_seat"],
            "firewall_status": "not_applicable_terminal",
            "compatibility_rule": None,
            "public_observation_hash": None,
            "public_hash_authority": None,
            "window_id": None,
            "option_count": 0,
            "option_fingerprints": [],
            "own_active": None,
            "terminal": True,
            "previous_witness": previous_witness,
        }
        summary["witness_hash"] = _witness(summary)
        return summary

    public_tree = _decode_node(parent["public_tree"])
    if type(public_tree) is not dict:
        raise ValueError("public tree must decode to object")
    parsed = parse_raw_cabt_json_bytes(_raw_bytes(public_tree))
    if not parsed.policy_eligible:
        raise ValueError(f"parent frame {frame_id} does not reparse")
    base = firewall.project(parsed)
    evaluation = firewall._evaluate_setup_bench_concealment(parsed)
    if evaluation["status"] != "accepted":
        raise ValueError(f"overlay rejected {frame_id}: {evaluation['issues']}")
    if evaluation["public_observation"] != public_tree:
        raise ValueError(f"overlay projection drift: {frame_id}")
    if evaluation["public_observation_hash"] != parent["public_observation_hash"]:
        raise ValueError(f"public hash drift: {frame_id}")
    compatibility = "setup_bench_concealment_v1" if frame_id == "w2_setup_bench" else None
    if evaluation.get("compatibility_rule") != compatibility:
        raise ValueError(f"compatibility marker drift: {frame_id}")
    if frame_id == "w2_setup_bench":
        if base.status != "rejected" or base.issues != [{"code": "own_active_concealed", "pointer": "/current/players/0/active", "severity": "error"}]:
            raise ValueError("base firewall no longer preserves W2 rejection")
    elif base.status != "accepted":
        raise ValueError(f"base firewall unexpectedly rejected {frame_id}")

    select = public_tree["select"]
    window_id: str | None = None
    option_count = 0
    fingerprints: list[str] = []
    authority: str | None = None
    if select is not None:
        built = build_cabt_selection_window(
            select,
            public_observation_hash=evaluation["public_observation_hash"],
            public_hash_authority="firewall_accepted",
            chooser_player_index=public_tree["current"]["yourIndex"],
        )
        if not built.accepted or built.window is None or not built.validate_integrity():
            raise ValueError(f"window build failed: {frame_id}")
        window = built.window.to_public_dict()
        if parent["window"] is None or window["window_id"] != parent["window"]["window_id"] or window["option_fingerprints"] != parent["window"]["option_fingerprints"]:
            raise ValueError(f"window drift: {frame_id}")
        window_id = window["window_id"]
        option_count = len(window["options"])
        fingerprints = window["option_fingerprints"]
        authority = "firewall_accepted"
    elif parent["window"] is not None:
        raise ValueError(f"initial callback must not have window: {frame_id}")

    own_active = None
    if compatibility is not None:
        acting = public_tree["current"]["yourIndex"]
        own_active = deepcopy(public_tree["current"]["players"][acting]["active"])
    summary = {
        "ordinal": ordinal,
        "frame_id": frame_id,
        "source_replay_id": parent["source_replay_id"],
        "source_step": parent["source_step"],
        "source_seat": parent["source_seat"],
        "firewall_status": "accepted",
        "compatibility_rule": compatibility,
        "public_observation_hash": evaluation["public_observation_hash"],
        "public_hash_authority": authority,
        "window_id": window_id,
        "option_count": option_count,
        "option_fingerprints": fingerprints,
        "own_active": own_active,
        "terminal": False,
        "previous_witness": previous_witness,
    }
    summary["witness_hash"] = _witness(summary)
    return summary


def _build_replay() -> dict[str, Any]:
    owner = MarnieVerticalSlice.load_default()
    firewall = PublicObservationFirewall.load_default()
    frame_ids = [
        "w0_initial", "w1_setup_active", "w2_setup_bench", "w3_main",
        "w4_spikemuth_deck", "w5_punk_up_sources", "w5_punk_up_target_1",
        "w5_punk_up_target_2", "w6_shadow_bullet_attack",
        "w6_shadow_bullet_target", "w7_take_prize", "w7_forced_send_out",
        "w7_terminal",
    ]
    frames: list[dict[str, Any]] = []
    previous: str | None = None
    for ordinal, frame_id in enumerate(frame_ids):
        frame = _frame_summary(owner, firewall, frame_id, ordinal, previous)
        frames.append(frame)
        previous = frame["witness_hash"]
    return {
        "schema_version": 1,
        "artifact_kind": "replay",
        "artifact_id": "ptcgdap-marnie-w0-w7-firewall-replay-v1",
        "profile_id": PROFILE_ID,
        "parent_fixture_bundle_canonical_sha256": PARENT_FIXTURE_HASH,
        "base_firewall_bundle_canonical_sha256": BASE_FIREWALL_HASH,
        "frame_count": len(frames),
        "chain_head": previous,
        "frames": frames,
        "production_actions_are_policy_goldens": False,
        "execution_authority": False,
    }


def _build_profile() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "artifact_kind": "profile",
        "profile_id": PROFILE_ID,
        "status": "offline_shadow_replay",
        "parents": {
            "p5_wp1_manifest_canonical_sha256": PARENT_MANIFEST_HASH,
            "p5_wp1_fixture_bundle_canonical_sha256": PARENT_FIXTURE_HASH,
            "p2_firewall_bundle_canonical_sha256": BASE_FIREWALL_HASH,
        },
        "setup_bench_concealment": {
            "required_select_keys": ["type", "context", "minCount", "maxCount", "remainDamageCounter", "remainEnergyCost", "option", "deck", "contextCard", "effect"],
            "select_type_raw": 1,
            "select_context_raw": 2,
            "turn": 0,
            "own_active_exact": [None],
            "opponent_active_exact": [None],
            "min_count": 0,
            "max_count_relation": "safe_integer_0_to_option_count",
            "remain_damage_counter": 0,
            "remain_energy_cost": 0,
            "deck": None,
            "context_card": None,
            "effect": None,
            "preserve_placeholder": True,
            "identity_reconstruction": "forbidden",
            "all_other_own_active_null_shapes": "reject_own_active_concealed",
        },
        "replay": {
            "frame_count": 13,
            "input": "P5-WP1 public typed frames only",
            "search_capability_materialization": "root search_begin_input is restored as null solely to satisfy raw-envelope structure and is omitted by the firewall",
            "window_authority": "firewall_accepted",
            "production_actions_are_policy_goldens": False,
            "terminal_without_callback": "not_applicable_terminal",
        },
        "chain": {"algorithm": "SHA-256", "prefix_utf8_hex": CHAIN_PREFIX.hex().upper(), "payload": "canonical_json_v1(frame summary without witness_hash)"},
        "serialized_authority": "audit_and_conformance_only",
        "live_authority": False,
        "reflection_boundary": "not a hostile same-process sandbox; no live consumer exists in P5-WP2",
    }


def _build_vectors(replay: dict[str, Any]) -> dict[str, Any]:
    w2 = next(frame for frame in replay["frames"] if frame["frame_id"] == "w2_setup_bench")
    cases = [
        {"case_id": "replay-all", "operation": "replay_all", "input": {}, "expected": {"accepted": True, "frame_count": 13, "chain_head": replay["chain_head"]}},
        {"case_id": "replay-w2", "operation": "replay_frame", "input": {"frame_id": "w2_setup_bench"}, "expected": {"accepted": True, "frame": w2}},
        {"case_id": "wrong-select-type", "operation": "probe_w2_mutation", "input": {"field": "select_type", "value": 0}, "expected": {"ok": False, "error_code": "setup_concealment_scope_mismatch", "value": None}},
        {"case_id": "wrong-select-context", "operation": "probe_w2_mutation", "input": {"field": "select_context", "value": 1}, "expected": {"ok": False, "error_code": "setup_concealment_scope_mismatch", "value": None}},
        {"case_id": "wrong-turn", "operation": "probe_w2_mutation", "input": {"field": "turn", "value": 1}, "expected": {"ok": False, "error_code": "setup_concealment_scope_mismatch", "value": None}},
        {"case_id": "wrong-active-shape", "operation": "probe_w2_mutation", "input": {"field": "own_active", "value": []}, "expected": {"ok": False, "error_code": "setup_concealment_scope_mismatch", "value": None}},
        {"case_id": "wrong-max-count", "operation": "probe_w2_mutation", "input": {"field": "max_count", "value": 2}, "expected": {"ok": False, "error_code": "setup_concealment_scope_mismatch", "value": None}},
        {"case_id": "wrong-result", "operation": "probe_w2_mutation", "input": {"field": "result", "value": 0}, "expected": {"ok": False, "error_code": "setup_concealment_scope_mismatch", "value": None}},
        {"case_id": "remain-damage", "operation": "probe_w2_mutation", "input": {"field": "remain_damage_counter", "value": 1}, "expected": {"ok": False, "error_code": "setup_concealment_scope_mismatch", "value": None}},
        {"case_id": "remain-energy", "operation": "probe_w2_mutation", "input": {"field": "remain_energy_cost", "value": 1}, "expected": {"ok": False, "error_code": "setup_concealment_scope_mismatch", "value": None}},
        {"case_id": "unauthorized-deck", "operation": "probe_w2_mutation", "input": {"field": "select_deck", "value": []}, "expected": {"ok": False, "error_code": "setup_concealment_scope_mismatch", "value": None}},
        {"case_id": "context-card-present", "operation": "probe_w2_mutation", "input": {"field": "context_card", "value": {"id": 7, "serial": 8, "playerIndex": 0}}, "expected": {"ok": False, "error_code": "setup_concealment_scope_mismatch", "value": None}},
        {"case_id": "effect-present", "operation": "probe_w2_mutation", "input": {"field": "effect", "value": {"id": 7, "serial": 8, "playerIndex": 0}}, "expected": {"ok": False, "error_code": "setup_concealment_scope_mismatch", "value": None}},
        {"case_id": "opponent-active-shape", "operation": "probe_w2_mutation", "input": {"field": "opponent_active", "value": []}, "expected": {"ok": False, "error_code": "setup_concealment_scope_mismatch", "value": None}},
        {"case_id": "opponent-hand-exposed", "operation": "probe_w2_mutation", "input": {"field": "opponent_hand", "value": [{"id": 7, "serial": 9, "playerIndex": 1}]}, "expected": {"ok": False, "error_code": "setup_concealment_scope_mismatch", "value": None}},
        {"case_id": "prize-identity-exposed", "operation": "probe_w2_mutation", "input": {"field": "own_prize", "value": {"id": 7, "serial": 8, "playerIndex": 0}}, "expected": {"ok": False, "error_code": "setup_concealment_scope_mismatch", "value": None}},
        {"case_id": "opponent-draw-exposed", "operation": "probe_w2_mutation", "input": {"field": "opponent_draw_log", "value": {"type": 4, "playerIndex": 1, "cardId": 7, "serial": 9}}, "expected": {"ok": False, "error_code": "setup_concealment_scope_mismatch", "value": None}},
        {"case_id": "unknown-frame", "operation": "replay_frame", "input": {"frame_id": "private-sentinel"}, "expected_error_code": "frame_unknown"},
        {"case_id": "input-type", "operation": "run", "input": {"operation": {"host_type": "integer", "value": 1}, "value": {}}, "expected": {"ok": False, "error_code": "input_type_invalid", "value": None}},
    ]
    return {"schema_version": 1, "artifact_kind": "vectors", "vector_set_id": "ptcgdap-marnie-trajectory-replay-conformance-v1", "profile_id": PROFILE_ID, "cases": cases}


def _build_schema() -> dict[str, Any]:
    sha = {"type": "string", "pattern": "^[0-9A-F]{64}$"}
    nullable_sha = {"oneOf": [sha, {"type": "null"}]}
    exact_null_slot = {"type": "array", "minItems": 1, "maxItems": 1, "items": {"type": "null"}}
    frame = {
        "type": "object", "additionalProperties": False,
        "required": ["ordinal","frame_id","source_replay_id","source_step","source_seat","firewall_status","compatibility_rule","public_observation_hash","public_hash_authority","window_id","option_count","option_fingerprints","own_active","terminal","previous_witness","witness_hash"],
        "properties": {
            "ordinal":{"type":"integer","minimum":0,"maximum":12}, "frame_id":{"type":"string","minLength":1},
            "source_replay_id":{"type":"string","minLength":1}, "source_step":{"type":"integer","minimum":0}, "source_seat":{"type":"integer","minimum":0,"maximum":1},
            "firewall_status":{"enum":["accepted","not_applicable_terminal"]}, "compatibility_rule":{"enum":[None,"setup_bench_concealment_v1"]},
            "public_observation_hash":nullable_sha, "public_hash_authority":{"enum":[None,"firewall_accepted"]}, "window_id":nullable_sha,
            "option_count":{"type":"integer","minimum":0}, "option_fingerprints":{"type":"array","items":sha}, "own_active":{"oneOf":[{"type":"null"},{"type":"array","maxItems":1,"items":{"type":"null"}}]},
            "terminal":{"type":"boolean"}, "previous_witness":nullable_sha, "witness_hash":sha,
        },
    }
    profile = {
        "type": "object", "additionalProperties": False,
        "required": ["schema_version","artifact_kind","profile_id","status","parents","setup_bench_concealment","replay","chain","serialized_authority","live_authority","reflection_boundary"],
        "properties": {
            "schema_version": {"const": 1}, "artifact_kind": {"const": "profile"}, "profile_id": {"const": PROFILE_ID},
            "status": {"const": "offline_shadow_replay"},
            "parents": {
                "type": "object", "additionalProperties": False,
                "required": ["p5_wp1_manifest_canonical_sha256","p5_wp1_fixture_bundle_canonical_sha256","p2_firewall_bundle_canonical_sha256"],
                "properties": {
                    "p5_wp1_manifest_canonical_sha256": sha,
                    "p5_wp1_fixture_bundle_canonical_sha256": sha,
                    "p2_firewall_bundle_canonical_sha256": sha,
                },
            },
            "setup_bench_concealment": {
                "type": "object", "additionalProperties": False,
                "required": ["required_select_keys","select_type_raw","select_context_raw","turn","own_active_exact","opponent_active_exact","min_count","max_count_relation","remain_damage_counter","remain_energy_cost","deck","context_card","effect","preserve_placeholder","identity_reconstruction","all_other_own_active_null_shapes"],
                "properties": {
                    "required_select_keys": {"const": ["type","context","minCount","maxCount","remainDamageCounter","remainEnergyCost","option","deck","contextCard","effect"]},
                    "select_type_raw": {"const": 1}, "select_context_raw": {"const": 2}, "turn": {"const": 0},
                    "own_active_exact": exact_null_slot, "opponent_active_exact": exact_null_slot,
                    "min_count": {"const": 0}, "max_count_relation": {"const":"safe_integer_0_to_option_count"},
                    "remain_damage_counter": {"const":0}, "remain_energy_cost": {"const":0},
                    "deck": {"type": "null"}, "context_card":{"type":"null"}, "effect":{"type":"null"},
                    "preserve_placeholder": {"const": True},
                    "identity_reconstruction": {"const": "forbidden"},
                    "all_other_own_active_null_shapes": {"const": "reject_own_active_concealed"},
                },
            },
            "replay": {
                "type": "object", "additionalProperties": False,
                "required": ["frame_count","input","search_capability_materialization","window_authority","production_actions_are_policy_goldens","terminal_without_callback"],
                "properties": {
                    "frame_count": {"const": 13}, "input": {"const": "P5-WP1 public typed frames only"},
                    "search_capability_materialization": {"const": "root search_begin_input is restored as null solely to satisfy raw-envelope structure and is omitted by the firewall"},
                    "window_authority": {"const": "firewall_accepted"}, "production_actions_are_policy_goldens": {"const": False},
                    "terminal_without_callback": {"const": "not_applicable_terminal"},
                },
            },
            "chain": {
                "type": "object", "additionalProperties": False, "required": ["algorithm","prefix_utf8_hex","payload"],
                "properties": {"algorithm":{"const":"SHA-256"},"prefix_utf8_hex":{"const":CHAIN_PREFIX.hex().upper()},"payload":{"const":"canonical_json_v1(frame summary without witness_hash)"}},
            },
            "serialized_authority": {"const": "audit_and_conformance_only"}, "live_authority": {"const": False},
            "reflection_boundary": {"type": "string", "minLength": 1},
        },
    }
    vector_input = {
        "type": "object", "additionalProperties": False,
        "properties": {
            "frame_id": {"type": "string", "minLength": 1}, "field": {"enum": ["select_type","select_context","turn","own_active","max_count","result","remain_damage_counter","remain_energy_cost","select_deck","context_card","effect","opponent_active","opponent_hand","own_prize","opponent_draw_log"]},
            "value": {}, "operation": {"oneOf": [{"type":"string"},{"type":"object","additionalProperties":False,"required":["host_type","value"],"properties":{"host_type":{"const":"integer"},"value":{"type":"integer"}}}]},
        },
    }
    vector_expected = {
        "oneOf": [
            {"type":"object","additionalProperties":False,"required":["accepted","frame_count","chain_head"],"properties":{"accepted":{"const":True},"frame_count":{"const":13},"chain_head":sha}},
            {"type":"object","additionalProperties":False,"required":["accepted","frame"],"properties":{"accepted":{"const":True},"frame":frame}},
            {"type":"object","additionalProperties":False,"required":["ok","error_code","value"],"properties":{"ok":{"const":False},"error_code":{"enum":["setup_concealment_scope_mismatch","input_type_invalid"]},"value":{"type":"null"}}},
        ]
    }
    vector_case = {
        "type": "object", "additionalProperties": False,
        "required": ["case_id","operation","input"],
        "properties": {
            "case_id":{"type":"string","minLength":1}, "operation":{"enum":["replay_all","replay_frame","probe_w2_mutation","run"]},
            "input":vector_input, "expected":vector_expected, "expected_error_code":{"const":"frame_unknown"},
        },
        "oneOf": [
            {"required":["expected"],"not":{"required":["expected_error_code"]}},
            {"required":["expected_error_code"],"not":{"required":["expected"]}},
        ],
    }
    vectors = {
        "type":"object","additionalProperties":False,
        "required":["schema_version","artifact_kind","vector_set_id","profile_id","cases"],
        "properties":{"schema_version":{"const":1},"artifact_kind":{"const":"vectors"},"vector_set_id":{"const":"ptcgdap-marnie-trajectory-replay-conformance-v1"},"profile_id":{"const":PROFILE_ID},"cases":{"type":"array","minItems":19,"maxItems":19,"items":vector_case}},
    }
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/marnie_trajectory_replay.schema.json",
        "title": "P5-WP2 Marnie trajectory replay artifacts",
        "oneOf": [
            {"type":"object","additionalProperties":False,"required":["schema_version","artifact_kind","artifact_id","profile_id","parent_fixture_bundle_canonical_sha256","base_firewall_bundle_canonical_sha256","frame_count","chain_head","frames","production_actions_are_policy_goldens","execution_authority"],"properties":{"schema_version":{"const":1},"artifact_kind":{"const":"replay"},"artifact_id":{"const":"ptcgdap-marnie-w0-w7-firewall-replay-v1"},"profile_id":{"const":PROFILE_ID},"parent_fixture_bundle_canonical_sha256":sha,"base_firewall_bundle_canonical_sha256":sha,"frame_count":{"const":13},"chain_head":sha,"frames":{"type":"array","minItems":13,"maxItems":13,"items":frame},"production_actions_are_policy_goldens":{"const":False},"execution_authority":{"const":False}}},
            profile,
            vectors,
        ],
    }


def _serialized(value: Any) -> bytes:
    return (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode("utf-8")


def build_documents() -> dict[str, bytes]:
    replay = _build_replay()
    values = {"schema": _build_schema(), "profile": _build_profile(), "vectors": _build_vectors(replay), "replay": replay}
    artifacts = []
    ids = {"schema":"marnie_trajectory_replay.schema","profile":PROFILE_ID,"vectors":"marnie_trajectory_replay_conformance_v1","replay":"w0_w7_firewall_replay_v1"}
    for key in ("schema", "profile", "vectors", "replay"):
        relative = PATHS[key].relative_to(ROOT).as_posix()
        artifacts.append({"id":ids[key],"path":relative,"canonical_sha256":sha256_bytes(canonical_json_v1_bytes(values[key]))})
    bundle = {"schema_version":1,"bundle_id":BUNDLE_ID,"status":"offline_shadow_replay","parent_fixture_bundle":{"path":"contracts/ptcgdap/marnie_vertical_slice_bundle.json","canonical_sha256":PARENT_FIXTURE_HASH},"base_firewall_bundle":{"path":"contracts/ptcgdap/cabt_public_firewall_bundle.json","canonical_sha256":BASE_FIREWALL_HASH},"artifacts":artifacts,"self_hash_policy":"bundle and bound artifacts do not contain the final bundle hash"}
    values["bundle"] = bundle
    return {key:_serialized(value) for key,value in values.items()}


def main() -> int:
    parser=argparse.ArgumentParser();parser.add_argument("--check",action="store_true");args=parser.parse_args();docs=build_documents()
    failures=[]
    for key,data in docs.items():
        path=PATHS[key]
        if args.check:
            if not path.is_file() or path.read_bytes()!=data:failures.append(path.as_posix())
        else:
            path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
    bundle=json.loads(docs["bundle"])
    print(f"bundle_raw_sha256={sha256_bytes(docs['bundle'])}")
    print(f"bundle_canonical_sha256={sha256_bytes(canonical_json_v1_bytes(bundle))}")
    print(f"artifact_count={len(bundle['artifacts'])}")
    if failures:
        print("drift="+",".join(failures));return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
