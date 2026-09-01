from __future__ import annotations

import argparse
import copy
import csv
import hashlib
import json
import math
import os
from pathlib import Path
import struct
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.cabt_envelope import parse_raw_cabt_envelope
from scripts.ai.ptcgdap.cabt_selection import build_cabt_selection_window
from scripts.ai.ptcgdap.cabt_tree_hash import public_observation_hash
from scripts.ai.ptcgdap.public_observation_firewall import PublicObservationFirewall
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict, sha256_bytes


CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
DATA_ROOT = ROOT / "data/ptcgdap/marnie_vertical_slice"
DEFAULT_ORACLE_ROOT = Path(os.environ.get("PTCGABC_ORACLE_ROOT", r"D:\ai\code\ptcgabc"))
SAFE_MAX = 9_007_199_254_740_991

OFFICIAL_AGENT = Path("agents/marnie_raihan_graph_r121_pre_attack_phase_order")
OFFICIAL_EPISODE_ROOT = Path("artifacts/online_episodes/55171940_raihan_public_20260802/raw/55171940/replays")
SMALL_REPLAY = OFFICIAL_EPISODE_ROOT / "episode-89540503-replay.json"
LARGE_REPLAY = OFFICIAL_EPISODE_ROOT / "episode-89541193-replay.json"

EXPECTED_OFFICIAL_INPUTS = {
    OFFICIAL_AGENT / "candidate_manifest.json": (1366, "2BF52818FD030013B4E87BDA1872E04E90805D3D7D97092A445E78E3C25A1C1B"),
    OFFICIAL_AGENT / "deck.csv": (312, "48F1A03E8AB8162F6DC608E6743A4F3B32004CB702CA447050E62055B85DEFBF"),
    OFFICIAL_AGENT / "main.py": (112856, "3802A739CF6BD92B31168A1A455890C3FDA3EF933E65D36CB7B8DF5E98F10EC1"),
    OFFICIAL_AGENT / "source_policy.py": (48245, "4ED25A095FAF96BE23E4092250377BC770496B7DF11081AD9B7592E887B9A90B"),
    OFFICIAL_AGENT / "source_profile.py": (3429, "5845D5016FEA85F4B84E261AD2EF65FDA76C035FBCB3DC60940F76AE136A3E95"),
    SMALL_REPLAY: (757047, "90FCA708C823791055B60C38599E2A7CF82DCC9E9D2DB83240962DA7AB1B7309"),
    LARGE_REPLAY: (3871895, "D02F774EC35D8F5A7AA44831ABEA4F77833F25780E7C271A76E3121F5A980D89"),
}

FRAME_SPECS = (
    ("w0_initial", "W0", SMALL_REPLAY, 0, "initial_deck", None, None),
    ("w1_setup_active", "W1", SMALL_REPLAY, 2, "setup_active", 1, 1),
    ("w2_setup_bench", "W2", SMALL_REPLAY, 4, "setup_bench", 1, 2),
    ("w3_main", "W3", SMALL_REPLAY, 5, "main", 0, 0),
    ("w4_spikemuth_deck", "W4", LARGE_REPLAY, 131, "spikemuth_deck", 1, 7),
    ("w5_punk_up_sources", "W5", LARGE_REPLAY, 94, "punk_up_sources", 1, 22),
    ("w5_punk_up_target_1", "W5", LARGE_REPLAY, 95, "punk_up_target", 1, 21),
    ("w5_punk_up_target_2", "W5", LARGE_REPLAY, 96, "punk_up_target", 1, 21),
    ("w6_shadow_bullet_attack", "W6", LARGE_REPLAY, 142, "shadow_bullet_attack", 0, 0),
    ("w6_shadow_bullet_target", "W6", LARGE_REPLAY, 143, "shadow_bullet_target", 1, 15),
    ("w7_take_prize", "W7", LARGE_REPLAY, 50, "take_prize", 1, 7),
    ("w7_forced_send_out", "W7", LARGE_REPLAY, 119, "forced_send_out", 1, 4),
    ("w7_terminal", "W7", LARGE_REPLAY, 145, "terminal_no_new_callback", None, None),
)

ARTIFACT_PATHS = (
    "contracts/ptcgdap/marnie_vertical_slice.schema.json",
    "contracts/ptcgdap/marnie_vertical_slice_profile.json",
    "contracts/ptcgdap/marnie_vertical_slice_source_manifest.json",
    "contracts/ptcgdap/marnie_vertical_slice_conformance_vectors.json",
    "data/ptcgdap/marnie_vertical_slice/official_deck_manifest_v1.json",
    "data/ptcgdap/marnie_vertical_slice/local_deck_manifest_v1.json",
    "data/ptcgdap/marnie_vertical_slice/deck_identity_diff_v1.json",
    "data/ptcgdap/marnie_vertical_slice/capability_inventory_v1.json",
    "data/ptcgdap/marnie_vertical_slice/w0_w7_public_trajectory_v1.json",
)


def _strict_json_bytes(value: bytes, *, allow_float: bool = False) -> Any:
    def pairs(items: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, child in items:
            if key in result:
                raise ValueError(f"duplicate key: {key}")
            result[key] = child
        return result

    def number(text: str) -> float:
        if not allow_float:
            raise ValueError("float forbidden")
        result = float(text)
        if not math.isfinite(result):
            raise ValueError("non-finite float")
        return result

    return json.loads(
        value.decode("utf-8"),
        object_pairs_hook=pairs,
        parse_float=number,
        parse_constant=lambda text: (_ for _ in ()).throw(ValueError(text)),
    )


def _source_bytes(path: Path, expected: tuple[int, str]) -> bytes:
    value = path.read_bytes()
    if len(value) != expected[0] or sha256_bytes(value) != expected[1]:
        raise ValueError(f"source drift: {path}")
    return value


def _encode_node(value: Any) -> dict[str, Any]:
    if value is None:
        return {"kind": "null"}
    if type(value) is bool:
        return {"kind": "boolean", "value": value}
    if type(value) is int:
        if not -SAFE_MAX <= value <= SAFE_MAX:
            raise ValueError("unsafe integer in public tree")
        return {"kind": "integer", "value": value}
    if type(value) is float:
        if not math.isfinite(value):
            raise ValueError("non-finite binary64")
        return {"kind": "binary64", "ieee754_hex": struct.pack(">d", value).hex().upper()}
    if type(value) is str:
        return {"kind": "string", "value": value}
    if type(value) is list:
        return {"kind": "array", "items": [_encode_node(child) for child in value]}
    if type(value) is dict:
        if any(type(key) is not str for key in value):
            raise ValueError("non-string public tree key")
        return {
            "kind": "object",
            "entries": [
                {"key": key, "value": _encode_node(value[key])}
                for key in sorted(value, key=lambda text: [ord(char) for char in text])
            ],
        }
    raise ValueError(f"unsupported public tree value: {type(value)!r}")


def _deck_ids(value: bytes) -> list[int]:
    rows = list(csv.reader(value.decode("utf-8-sig").splitlines()))
    if not rows or any(len(row) != 1 for row in rows):
        raise ValueError("official deck must be one numeric ID per CSV row")
    ids = [int(row[0]) for row in rows]
    if len(ids) != 60 or any(card_id < 1 for card_id in ids):
        raise ValueError("official deck is not exact positive 60")
    return ids


def _public_tree_from_parse(parsed: Any) -> dict[str, Any]:
    envelope = parsed.envelope
    if envelope is None:
        raise ValueError("missing envelope")
    known = envelope.known_view
    tree = {
        "select": copy.deepcopy(known["select"]),
        "logs": copy.deepcopy(known["logs"]),
        "current": copy.deepcopy(known["current"]),
    }
    presence = envelope.field_presence
    framework = envelope.framework
    if presence.get("/step") != "missing":
        tree["step"] = copy.deepcopy(framework.get("step"))
    if presence.get("/remainingOverageTime") != "missing":
        tree["remainingOverageTime"] = copy.deepcopy(framework.get("remaining_overage_time"))
    return tree


def _visibility(tree: dict[str, Any]) -> dict[str, Any]:
    select = tree.get("select")
    current = tree.get("current")
    if select is None:
        return {
            "acting_hand_visible": False,
            "opponent_hand_hidden": True,
            "prizes_concealed": True,
            "own_active_concealed": False,
            "authorized_select_deck": False,
            "opponent_draw_identity_absent": True,
        }
    if type(select) is not dict or type(current) is not dict:
        raise ValueError("regular public tree shape")
    acting = current.get("yourIndex")
    players = current.get("players")
    if type(acting) is not int or acting not in (0, 1) or type(players) is not list or len(players) != 2:
        raise ValueError("player visibility shape")
    own = players[acting]
    opponent = players[1 - acting]
    if type(own) is not dict or type(opponent) is not dict:
        raise ValueError("player visibility value")
    prizes_concealed = all(
        type(player.get("prize")) is list and all(card is None for card in player["prize"])
        for player in players
    )
    own_active = own.get("active")
    logs = tree.get("logs")
    return {
        "acting_hand_visible": type(own.get("hand")) is list,
        "opponent_hand_hidden": opponent.get("hand") is None,
        "prizes_concealed": prizes_concealed,
        "own_active_concealed": type(own_active) is list and any(card is None for card in own_active),
        "authorized_select_deck": select.get("deck") is not None and select.get("type") == 1,
        "opponent_draw_identity_absent": type(logs) is list and not any(
            type(log) is dict and log.get("type") == 4 and log.get("playerIndex") != acting
            for log in logs
        ),
    }


def _trajectory(oracle_root: Path, official_ids: list[int]) -> dict[str, Any]:
    replay_documents = {
        relative: _strict_json_bytes(_source_bytes(oracle_root / relative, EXPECTED_OFFICIAL_INPUTS[relative]), allow_float=True)
        for relative in (SMALL_REPLAY, LARGE_REPLAY)
    }
    firewall = PublicObservationFirewall.load_default()
    frames: list[dict[str, Any]] = []
    for frame_id, family, replay_path, step, role, expected_type, expected_context in FRAME_SPECS:
        document = replay_documents[replay_path]
        entry = document["steps"][step][0]
        base = {
            "frame_id": frame_id,
            "window_family": family,
            "callback_role": role,
            "source_replay_id": replay_path.name.removesuffix("-replay.json").removeprefix("episode-"),
            "source_step": step,
            "source_seat": 0,
            "source_status": entry["status"],
            "source_action_authority": "not_policy_golden",
        }
        if frame_id == "w7_terminal":
            if entry["status"] != "DONE" or document["statuses"] != ["DONE", "DONE"] or step != len(document["steps"]) - 1:
                raise ValueError("terminal evidence drift")
            base.update(
                {
                    "public_tree": None,
                    "public_observation_hash": None,
                    "current_firewall": {"status": "not_invoked_after_terminal", "issue_code": None},
                    "window": None,
                    "visibility": None,
                    "terminal": {"new_callback_expected": False, "final_step": step, "both_seats_done": True},
                }
            )
            frames.append(base)
            continue
        observation = entry["observation"]
        parsed = parse_raw_cabt_envelope(observation, contract_root=CONTRACT_ROOT)
        if not parsed.policy_eligible:
            raise ValueError(f"frame not envelope eligible: {frame_id}")
        result = firewall.project(parsed)
        if frame_id == "w2_setup_bench":
            if result.accepted or not result.issues or result.issues[0]["code"] != "own_active_concealed":
                raise ValueError("W2 firewall mismatch changed")
            tree = _public_tree_from_parse(parsed)
            current_firewall = {"status": "rejected", "issue_code": "own_active_concealed"}
        else:
            if not result.accepted or not result.validate_integrity(parsed):
                raise ValueError(f"firewall rejected source frame: {frame_id}: {result.issues}")
            tree = result.public_observation
            current_firewall = {"status": "accepted", "issue_code": None}
        digest = public_observation_hash(tree)
        if result.accepted and digest != result.public_observation_hash:
            raise ValueError("firewall/public hash mismatch")
        select = tree.get("select")
        window = None
        if select is not None:
            if select.get("type") != expected_type or select.get("context") != expected_context:
                raise ValueError(f"selection family drift: {frame_id}")
            built = build_cabt_selection_window(
                select,
                public_observation_hash=digest,
                public_hash_authority="conformance_fixture",
                chooser_player_index=0,
            )
            if built.decision_state != "policy_allowed" or built.window is None or built.issues:
                raise ValueError(f"window build failed: {frame_id}")
            window = built.window.to_public_dict()
        elif frame_id != "w0_initial":
            raise ValueError("unexpected null selection")
        visibility = _visibility(tree)
        if not all(
            visibility[key]
            for key in ("acting_hand_visible", "opponent_hand_hidden", "prizes_concealed", "opponent_draw_identity_absent")
        ) and frame_id != "w0_initial":
            raise ValueError(f"visibility failure: {frame_id}")
        if frame_id == "w2_setup_bench" and not visibility["own_active_concealed"]:
            raise ValueError("W2 concealment evidence missing")
        if frame_id == "w4_spikemuth_deck" and not visibility["authorized_select_deck"]:
            raise ValueError("Spikemuth deck authorization missing")
        if frame_id == "w6_shadow_bullet_attack" and not any(option.get("attackId") == 937 for option in select["option"]):
            raise ValueError("Shadow Bullet attack option missing")
        base.update(
            {
                "public_tree": _encode_node(tree),
                "public_observation_hash": digest,
                "current_firewall": current_firewall,
                "window": window,
                "visibility": visibility,
                "terminal": None,
            }
        )
        frames.append(base)
    initial_action = replay_documents[SMALL_REPLAY]["steps"][1][0]["action"]
    if initial_action != official_ids:
        raise ValueError("official initial deck action drift")
    return {
        "schema_version": 1,
        "artifact_id": "ptcgdap-marnie-w0-w7-public-trajectory-v1",
        "status": "offline_source_locked_fixture",
        "source_container_policy": "private replay containers remain outside the repository; only exact public seat/step extractions are serialized",
        "initial_deck_action": {
            "source_replay_id": "89540503",
            "observation_step": 0,
            "action_step": 1,
            "official_deck_manifest_id": "ptcgdap-marnie-official-deck-manifest-v1",
            "card_count": 60,
            "exact_ordered_card_ids": official_ids,
        },
        "frames": frames,
    }


def _manifest_entry(path: Path, role: str, root_id: str, relative: str | None = None) -> dict[str, Any]:
    value = path.read_bytes()
    return {
        "id": role,
        "root_id": root_id,
        "path": relative or path.relative_to(ROOT).as_posix(),
        "bytes": len(value),
        "raw_sha256": sha256_bytes(value),
        "canonical_json_v1_sha256": sha256_bytes(canonical_json_v1_bytes(load_json_strict(path))) if path.suffix == ".json" and root_id == "ptcgdap" else None,
    }


def _source_manifest(oracle_root: Path) -> dict[str, Any]:
    inputs: list[dict[str, Any]] = []
    for relative, expected in EXPECTED_OFFICIAL_INPUTS.items():
        value = _source_bytes(oracle_root / relative, expected)
        inputs.append(
            {
                "id": relative.name.replace(".", "_").replace("-", "_") + "_official",
                "root_id": "ptcgabc_read_only_oracle",
                "path": relative.as_posix(),
                "bytes": len(value),
                "raw_sha256": sha256_bytes(value),
                "canonical_json_v1_sha256": None,
            }
        )
    local_paths = (
        (ROOT / "data/bundled_user/decks/800018501.json", "local_deck_800018501"),
        (ROOT / "contracts/ptcgdap/card_id_catalog_bundle.json", "p2_card_id_catalog_bundle"),
        (ROOT / "contracts/ptcgdap/card_id_catalog_source_manifest.json", "p2_card_id_source_manifest"),
        (ROOT / "data/ptcgdap/card_id_catalog/official_card_attack_master_v1.json", "p2_official_card_attack_master"),
        (ROOT / "data/ptcgdap/card_id_catalog/marnie_exact_print_bridge_v1.json", "p2_marnie_exact_bridge"),
        (ROOT / "artifacts/ptcgdap/p4_wp6/manifest.json", "p4_wp6_parent_manifest"),
        (ROOT / "docs/ptcgdap/SOURCE_LOCK.json", "ptcgdap_source_lock"),
    )
    inputs.extend(_manifest_entry(path, role, "ptcgdap") for path, role in local_paths)
    return {
        "schema_version": 1,
        "artifact_id": "ptcgdap-marnie-vertical-slice-source-manifest-p5-wp1-v1",
        "source_policy": {
            "official_oracle": "read_only_development_source_compiler_input_only",
            "runtime_dependency": False,
            "private_replay_copy_allowed": False,
            "public_seat_step_extraction_only": True,
            "name_text_art_inference": "forbidden",
        },
        "inputs": inputs,
    }


def _documents(oracle_root: Path) -> dict[str, Any]:
    official_bytes = _source_bytes(oracle_root / OFFICIAL_AGENT / "deck.csv", EXPECTED_OFFICIAL_INPUTS[OFFICIAL_AGENT / "deck.csv"])
    official_ids = _deck_ids(official_bytes)
    master = load_json_strict(ROOT / "data/ptcgdap/card_id_catalog/official_card_attack_master_v1.json")
    bridge = load_json_strict(ROOT / "data/ptcgdap/card_id_catalog/marnie_exact_print_bridge_v1.json")
    local_deck = load_json_strict(ROOT / "data/bundled_user/decks/800018501.json")
    master_by_id = {row["official_card_id"]: row for row in master["cards"]}
    bridge_by_id = {row["official_card_id"]: row for row in bridge["entries"]}
    bridge_by_local = {(row["local_printing"]["set_code"], row["local_printing"]["card_index"]): row for row in bridge["entries"]}
    counts: dict[int, int] = {}
    for card_id in official_ids:
        counts[card_id] = counts.get(card_id, 0) + 1
    if len(counts) != 19:
        raise ValueError("official unique card count drift")
    official_rows = []
    for card_id in sorted(counts):
        card = master_by_id[card_id]
        bridge_row = bridge_by_id.get(card_id)
        official_rows.append(
            {
                "official_card_id": card_id,
                "count": counts[card_id],
                "exact_english_printing": card["exact_english_printing_or_null"],
                "ordered_official_attack_ids": card["ordered_official_attack_ids"],
                "exact_local_bridge": None if bridge_row is None else {
                    "local_printing": bridge_row["local_printing"],
                    "source_file": bridge_row["source_file"],
                    "local_attack_index_to_official_attack_id": bridge_row["local_attack_index_to_official_attack_id"],
                },
            }
        )
    official_manifest = {
        "schema_version": 1,
        "artifact_id": "ptcgdap-marnie-official-deck-manifest-v1",
        "deck_identity": "cabt:marnie_grimmsnarl_froslass:48f1a03e8ab8162f",
        "source_deck_raw_sha256": EXPECTED_OFFICIAL_INPUTS[OFFICIAL_AGENT / "deck.csv"][1],
        "ordered_card_ids_canonical_sha256": sha256_bytes(canonical_json_v1_bytes(official_ids)),
        "card_count": len(official_ids),
        "unique_card_id_count": len(counts),
        "ordered_card_ids": official_ids,
        "cards": official_rows,
        "native_deck_legality": "official_production_replay_accepted_source_deck",
        "cabt_exportable": True,
    }
    local_rows = []
    local_total = 0
    for source in local_deck["cards"]:
        key = (source["set_code"], source["card_index"])
        local_total += source["count"]
        bridge_row = bridge_by_local.get(key)
        local_rows.append(
            {
                "local_printing": {"set_code": key[0], "card_index": key[1]},
                "count": source["count"],
                "card_type": source["card_type"],
                "effect_id": source["effect_id"],
                "godot_card_implementation_status_expected": "implemented",
                "official_equivalence": "not_evaluated" if bridge_row is None else "exact_print_bridge_only_not_engine_parity",
                "official_card_id": None if bridge_row is None else bridge_row["official_card_id"],
            }
        )
    if local_total != 60 or len(local_rows) != 28:
        raise ValueError("local deck count drift")
    local_manifest = {
        "schema_version": 1,
        "artifact_id": "ptcgdap-marnie-local-deck-manifest-v1",
        "deck_id": 800018501,
        "deck_identity": "godot:800018501:" + sha256_bytes(canonical_json_v1_bytes(local_deck["cards"]))[:16].lower(),
        "source_deck_raw_sha256": sha256_bytes((ROOT / "data/bundled_user/decks/800018501.json").read_bytes()),
        "source_deck_canonical_sha256": sha256_bytes(canonical_json_v1_bytes(local_deck)),
        "card_count": local_total,
        "unique_printing_count": len(local_rows),
        "cards": local_rows,
        "cabt_exportable": False,
        "support_claim": "Godot CardImplementationStatus only; not official semantic or engine parity",
    }
    official_bridged = sum(row["count"] for row in official_rows if row["exact_local_bridge"] is not None)
    official_unmapped = [row["official_card_id"] for row in official_rows if row["exact_local_bridge"] is None]
    local_bridged = sum(row["count"] for row in local_rows if row["official_card_id"] is not None)
    identity_diff = {
        "schema_version": 1,
        "artifact_id": "ptcgdap-marnie-deck-identity-diff-v1",
        "same_deck": False,
        "comparison_authority": "exact numeric official Card ID and explicitly reviewed source-hashed printing bridge only",
        "name_text_art_inference": "forbidden",
        "official": {
            "card_count": 60,
            "unique_card_id_count": 19,
            "bridged_card_count": official_bridged,
            "bridged_unique_card_id_count": len(official_rows) - len(official_unmapped),
            "unmapped_card_count": 60 - official_bridged,
            "unmapped_official_card_ids": official_unmapped,
        },
        "local": {
            "card_count": 60,
            "unique_printing_count": 28,
            "bridged_card_count": local_bridged,
            "bridged_unique_printing_count": sum(row["official_card_id"] is not None for row in local_rows),
            "unbridged_card_count": 60 - local_bridged,
        },
        "cabt_exportable": False,
        "reason_codes": ["deck_lists_not_equal", "official_ids_local_unmapped", "local_printings_unbridged", "engine_parity_not_evaluated"],
    }
    if (official_bridged, len(official_unmapped), 60 - official_bridged, local_bridged) != (34, 10, 26, 15):
        raise ValueError("identity diff counts drift")
    capabilities = [
        ("initial_deck", "W0", [7, 104, 112, 646, 647, 648, 860, 1079, 1080, 1086, 1097, 1122, 1137, 1152, 1182, 1219, 1227, 1231, 1259]),
        ("setup_active", "W1", []),
        ("setup_bench", "W2", []),
        ("main_action_frontier", "W3", []),
        ("spikemuth_tutor", "W4", [1259]),
        ("punk_up", "W5", [648]),
        ("shadow_bullet", "W6", [648]),
        ("take_prize", "W7", []),
        ("forced_send_out", "W7", []),
        ("terminal_without_callback", "W7", []),
    ]
    capability_inventory = {
        "schema_version": 1,
        "artifact_id": "ptcgdap-marnie-capability-inventory-v1",
        "ability_numeric_identity": "unsupported_by_official_payload_no_synthesis",
        "capabilities": [
            {
                "capability_id": capability,
                "window_family": family,
                "required": True,
                "official_evidence": "source_locked_profile_policy_and_or_production_frame",
                "official_card_ids": card_ids,
                "local_engine_support": "implemented_current_godot_card_implementation_status" if capability in {"initial_deck", "spikemuth_tutor", "punk_up", "shadow_bullet"} else "interface_fixture_only",
                "portable_ready": False,
                "portable_blockers": ["exact_deck_equivalence_absent", "host_trajectory_not_replayed"] + (["current_firewall_setup_concealment_mismatch"] if capability == "setup_bench" else []),
            }
            for capability, family, card_ids in capabilities
        ],
    }
    trajectory = _trajectory(oracle_root, official_ids)
    profile = {
        "schema_version": 1,
        "profile_id": "marnie_vertical_slice_profile_v1",
        "status": "offline_shadow_fixture",
        "parent": {
            "p4_wp6_manifest_canonical_sha256": "93B0F8170124AE5DD184FBD1BD17BBEC60C805A6EFC9D348C1B5ADAF5AD3369E",
            "p4_budget_bundle_canonical_sha256": "0D82BDE31BD0FA0C44527880D9D6451C2733702913708532C512F3BFF81D8BF9",
            "source_lock_canonical_sha256": "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205",
        },
        "artifact_serialization": "canonical_json_v1; public binary64 values use exact IEEE-754 hex typed nodes",
        "deck_identity_rule": "official and local manifests are permanently distinct until every count/printing/effect/support relation is explicitly proven",
        "trajectory_rule": "private replay containers remain oracle-only; serialized frames contain only allow-listed public seat/step extraction",
        "w2_firewall_rule": "current own_active_concealed rejection is recorded, not converted to acceptance",
        "serialized_authority": "audit_and_conformance_only",
        "live_authority": False,
        "client_confidentiality": "artifacts are assumed extractable; hashes provide integrity and provenance only",
    }
    source_manifest = _source_manifest(oracle_root)
    vectors = {
        "schema_version": 1,
        "artifact_id": "ptcgdap-marnie-vertical-slice-conformance-v1",
        "cases": [
            {"id": "official-summary", "operation": "official_summary", "input": {}, "expected": {"card_count": 60, "unique_card_id_count": 19, "cabt_exportable": True}},
            {"id": "local-summary", "operation": "local_summary", "input": {}, "expected": {"card_count": 60, "unique_printing_count": 28, "cabt_exportable": False}},
            {"id": "identity-summary", "operation": "identity_summary", "input": {}, "expected": {"same_deck": False, "official_bridged": 34, "official_unmapped": 26, "local_bridged": 15, "local_unbridged": 45}},
            {"id": "w2-firewall", "operation": "frame_summary", "input": {"frame_id": "w2_setup_bench"}, "expected": {"family": "W2", "firewall_status": "rejected", "issue_code": "own_active_concealed", "window_state": "policy_allowed"}},
            {"id": "w4-deck", "operation": "frame_summary", "input": {"frame_id": "w4_spikemuth_deck"}, "expected": {"family": "W4", "firewall_status": "accepted", "issue_code": None, "window_state": "policy_allowed"}},
            {"id": "terminal", "operation": "frame_summary", "input": {"frame_id": "w7_terminal"}, "expected": {"family": "W7", "firewall_status": "not_invoked_after_terminal", "issue_code": None, "window_state": None}},
            {"id": "unknown-frame", "operation": "frame_summary", "input": {"frame_id": "PRIVATE_UNKNOWN"}, "expected_error": "frame_unknown"},
            {"id": "wrong-frame-type", "operation": "frame_summary", "input": {"frame_id": {"host_type": "string_name", "value": "w3_main"}}, "expected_error": "input_type_invalid"},
            {"id": "capability-punk-up", "operation": "capability", "input": {"capability_id": "punk_up"}, "expected": {"window_family": "W5", "portable_ready": False}},
            {"id": "unknown-capability", "operation": "capability", "input": {"capability_id": "PRIVATE_UNKNOWN"}, "expected_error": "capability_unknown"},
        ],
    }
    schema = _schema()
    return {
        "contracts/ptcgdap/marnie_vertical_slice.schema.json": schema,
        "contracts/ptcgdap/marnie_vertical_slice_profile.json": profile,
        "contracts/ptcgdap/marnie_vertical_slice_source_manifest.json": source_manifest,
        "contracts/ptcgdap/marnie_vertical_slice_conformance_vectors.json": vectors,
        "data/ptcgdap/marnie_vertical_slice/official_deck_manifest_v1.json": official_manifest,
        "data/ptcgdap/marnie_vertical_slice/local_deck_manifest_v1.json": local_manifest,
        "data/ptcgdap/marnie_vertical_slice/deck_identity_diff_v1.json": identity_diff,
        "data/ptcgdap/marnie_vertical_slice/capability_inventory_v1.json": capability_inventory,
        "data/ptcgdap/marnie_vertical_slice/w0_w7_public_trajectory_v1.json": trajectory,
    }


def _schema() -> dict[str, Any]:
    def closed(required: list[str], properties: dict[str, Any]) -> dict[str, Any]:
        return {
            "type": "object",
            "additionalProperties": False,
            "required": required,
            "properties": properties,
        }

    safe_integer = {"type": "integer", "minimum": -SAFE_MAX, "maximum": SAFE_MAX}
    positive_integer = {"type": "integer", "minimum": 1, "maximum": SAFE_MAX}
    nonnegative_integer = {"type": "integer", "minimum": 0, "maximum": SAFE_MAX}
    sha = {"type": "string", "pattern": "^[0-9A-F]{64}$"}
    string = {"type": "string"}
    nonempty = {"type": "string", "minLength": 1}
    local_printing = closed(
        ["set_code", "card_index"],
        {"set_code": nonempty, "card_index": nonempty},
    )
    official_printing = closed(
        ["expansion", "collection_no"],
        {"expansion": nonempty, "collection_no": nonempty},
    )
    node_ref = {"$ref": "#/$defs/encodedNode"}
    encoded_node = {
        "oneOf": [
            {"type": "object", "additionalProperties": False, "required": ["kind"], "properties": {"kind": {"const": "null"}}},
            {"type": "object", "additionalProperties": False, "required": ["kind", "value"], "properties": {"kind": {"const": "boolean"}, "value": {"type": "boolean"}}},
            {"type": "object", "additionalProperties": False, "required": ["kind", "value"], "properties": {"kind": {"const": "integer"}, "value": safe_integer}},
            {"type": "object", "additionalProperties": False, "required": ["kind", "ieee754_hex"], "properties": {"kind": {"const": "binary64"}, "ieee754_hex": {"type": "string", "pattern": "^[0-9A-F]{16}$"}}},
            {"type": "object", "additionalProperties": False, "required": ["kind", "value"], "properties": {"kind": {"const": "string"}, "value": {"type": "string"}}},
            {"type": "object", "additionalProperties": False, "required": ["kind", "items"], "properties": {"kind": {"const": "array"}, "items": {"type": "array", "items": node_ref}}},
            {"type": "object", "additionalProperties": False, "required": ["kind", "entries"], "properties": {"kind": {"const": "object"}, "entries": {"type": "array", "items": {"type": "object", "additionalProperties": False, "required": ["key", "value"], "properties": {"key": {"type": "string"}, "value": node_ref}}}}},
        ]
    }
    card = closed(
        ["id", "serial", "playerIndex"],
        {"id": positive_integer, "serial": nonnegative_integer, "playerIndex": {"enum": [0, 1]}},
    )
    option = closed(
        ["type"],
        {
            "type": nonnegative_integer,
            "area": {"anyOf": [nonnegative_integer, {"type": "null"}]},
            "index": {"anyOf": [nonnegative_integer, {"type": "null"}]},
            "playerIndex": {"anyOf": [{"enum": [0, 1]}, {"type": "null"}]},
            "inPlayArea": {"anyOf": [nonnegative_integer, {"type": "null"}]},
            "inPlayIndex": {"anyOf": [nonnegative_integer, {"type": "null"}]},
            "specialConditionType": {"anyOf": [nonnegative_integer, {"type": "null"}]},
            "attackId": {"anyOf": [positive_integer, {"type": "null"}]},
            "toolIndex": {"anyOf": [nonnegative_integer, {"type": "null"}]},
            "count": {"anyOf": [nonnegative_integer, {"type": "null"}]},
            "cardId": {"anyOf": [positive_integer, {"type": "null"}]},
        },
    )
    window = closed(
        [
            "window_version", "window_id", "hash_profile", "option_fingerprint_profile",
            "public_observation_hash", "public_hash_authority", "chooser_player_index", "decision_state",
            "fallback_reasons", "select_type_raw", "select_context_raw", "min_count", "max_count",
            "remain_damage_counter", "remain_energy_cost", "context_card", "effect",
            "public_deck_candidates", "options", "option_fingerprints",
        ],
        {
            "window_version": {"const": 1},
            "window_id": sha,
            "hash_profile": {"const": "cabt_selection_window_v1"},
            "option_fingerprint_profile": {"const": "cabt_option_fingerprint_v1"},
            "public_observation_hash": sha,
            "public_hash_authority": {"const": "conformance_fixture"},
            "chooser_player_index": {"enum": [0, 1]},
            "decision_state": {"enum": ["policy_allowed", "fallback_only"]},
            "fallback_reasons": {"type": "array", "items": nonempty, "uniqueItems": True},
            "select_type_raw": nonnegative_integer,
            "select_context_raw": nonnegative_integer,
            "min_count": nonnegative_integer,
            "max_count": nonnegative_integer,
            "remain_damage_counter": nonnegative_integer,
            "remain_energy_cost": nonnegative_integer,
            "context_card": {"anyOf": [card, {"type": "null"}]},
            "effect": {"anyOf": [card, {"type": "null"}]},
            "public_deck_candidates": {"anyOf": [{"type": "array", "items": card}, {"type": "null"}]},
            "options": {"type": "array", "items": option},
            "option_fingerprints": {"type": "array", "items": sha, "uniqueItems": True},
        },
    )
    source_input = closed(
        ["id", "root_id", "path", "bytes", "raw_sha256", "canonical_json_v1_sha256"],
        {
            "id": nonempty,
            "root_id": {"enum": ["ptcgdap", "ptcgabc_read_only_oracle"]},
            "path": {"type": "string", "pattern": "^(?![A-Za-z]:)(?!/)(?!.*(?:^|/)\\.\\.(?:/|$))[^\\\\\\0]+$"},
            "bytes": positive_integer,
            "raw_sha256": sha,
            "canonical_json_v1_sha256": {"anyOf": [sha, {"type": "null"}]},
        },
    )
    profile_schema = closed(
        [
            "schema_version", "profile_id", "status", "parent", "artifact_serialization",
            "deck_identity_rule", "trajectory_rule", "w2_firewall_rule", "serialized_authority",
            "live_authority", "client_confidentiality",
        ],
        {
            "schema_version": {"const": 1},
            "profile_id": {"const": "marnie_vertical_slice_profile_v1"},
            "status": {"const": "offline_shadow_fixture"},
            "parent": closed(
                ["p4_wp6_manifest_canonical_sha256", "p4_budget_bundle_canonical_sha256", "source_lock_canonical_sha256"],
                {"p4_wp6_manifest_canonical_sha256": sha, "p4_budget_bundle_canonical_sha256": sha, "source_lock_canonical_sha256": sha},
            ),
            "artifact_serialization": nonempty,
            "deck_identity_rule": nonempty,
            "trajectory_rule": nonempty,
            "w2_firewall_rule": nonempty,
            "serialized_authority": {"const": "audit_and_conformance_only"},
            "live_authority": {"const": False},
            "client_confidentiality": nonempty,
        },
    )
    source_schema = closed(
        ["schema_version", "artifact_id", "source_policy", "inputs"],
        {
            "schema_version": {"const": 1},
            "artifact_id": {"const": "ptcgdap-marnie-vertical-slice-source-manifest-p5-wp1-v1"},
            "source_policy": closed(
                ["official_oracle", "runtime_dependency", "private_replay_copy_allowed", "public_seat_step_extraction_only", "name_text_art_inference"],
                {
                    "official_oracle": {"const": "read_only_development_source_compiler_input_only"},
                    "runtime_dependency": {"const": False},
                    "private_replay_copy_allowed": {"const": False},
                    "public_seat_step_extraction_only": {"const": True},
                    "name_text_art_inference": {"const": "forbidden"},
                },
            ),
            "inputs": {"type": "array", "minItems": 14, "maxItems": 14, "items": source_input},
        },
    )
    vector_input = closed(
        [],
        {
            "frame_id": {"anyOf": [string, closed(["host_type", "value"], {"host_type": {"const": "string_name"}, "value": string})]},
            "capability_id": string,
        },
    )
    vector_expected = closed(
        [],
        {
            "card_count": nonnegative_integer,
            "unique_card_id_count": nonnegative_integer,
            "unique_printing_count": nonnegative_integer,
            "cabt_exportable": {"type": "boolean"},
            "same_deck": {"type": "boolean"},
            "official_bridged": nonnegative_integer,
            "official_unmapped": nonnegative_integer,
            "local_bridged": nonnegative_integer,
            "local_unbridged": nonnegative_integer,
            "family": {"pattern": "^W[0-7]$"},
            "firewall_status": {"enum": ["accepted", "rejected", "not_invoked_after_terminal"]},
            "issue_code": {"anyOf": [nonempty, {"type": "null"}]},
            "window_state": {"anyOf": [{"enum": ["policy_allowed", "fallback_only"]}, {"type": "null"}]},
            "window_family": {"pattern": "^W[0-7]$"},
            "portable_ready": {"type": "boolean"},
        },
    )
    success_vector = closed(
        ["id", "operation", "input", "expected"],
        {"id": nonempty, "operation": {"enum": ["official_summary", "local_summary", "identity_summary", "frame_summary", "capability"]}, "input": vector_input, "expected": vector_expected},
    )
    error_vector = closed(
        ["id", "operation", "input", "expected_error"],
        {"id": nonempty, "operation": {"enum": ["frame_summary", "capability"]}, "input": vector_input, "expected_error": {"enum": ["frame_unknown", "capability_unknown", "input_type_invalid"]}},
    )
    vectors_schema = closed(
        ["schema_version", "artifact_id", "cases"],
        {
            "schema_version": {"const": 1},
            "artifact_id": {"const": "ptcgdap-marnie-vertical-slice-conformance-v1"},
            "cases": {"type": "array", "minItems": 10, "maxItems": 10, "items": {"oneOf": [success_vector, error_vector]}},
        },
    )
    attack_map = {"type": "object", "additionalProperties": False, "patternProperties": {"^(?:0|[1-9][0-9]*)$": positive_integer}}
    exact_bridge = closed(
        ["local_printing", "source_file", "local_attack_index_to_official_attack_id"],
        {"local_printing": local_printing, "source_file": nonempty, "local_attack_index_to_official_attack_id": attack_map},
    )
    official_row = closed(
        ["official_card_id", "count", "exact_english_printing", "ordered_official_attack_ids", "exact_local_bridge"],
        {
            "official_card_id": positive_integer,
            "count": positive_integer,
            "exact_english_printing": {"anyOf": [official_printing, {"type": "null"}]},
            "ordered_official_attack_ids": {"type": "array", "items": positive_integer, "uniqueItems": True},
            "exact_local_bridge": {"anyOf": [exact_bridge, {"type": "null"}]},
        },
    )
    official_schema = closed(
        ["schema_version", "artifact_id", "deck_identity", "source_deck_raw_sha256", "ordered_card_ids_canonical_sha256", "card_count", "unique_card_id_count", "ordered_card_ids", "cards", "native_deck_legality", "cabt_exportable"],
        {
            "schema_version": {"const": 1}, "artifact_id": {"const": "ptcgdap-marnie-official-deck-manifest-v1"},
            "deck_identity": {"const": "cabt:marnie_grimmsnarl_froslass:48f1a03e8ab8162f"}, "source_deck_raw_sha256": sha,
            "ordered_card_ids_canonical_sha256": sha, "card_count": {"const": 60}, "unique_card_id_count": {"const": 19},
            "ordered_card_ids": {"type": "array", "minItems": 60, "maxItems": 60, "items": positive_integer},
            "cards": {"type": "array", "minItems": 19, "maxItems": 19, "items": official_row},
            "native_deck_legality": {"const": "official_production_replay_accepted_source_deck"}, "cabt_exportable": {"const": True},
        },
    )
    local_row = closed(
        ["local_printing", "count", "card_type", "effect_id", "godot_card_implementation_status_expected", "official_equivalence", "official_card_id"],
        {
            "local_printing": local_printing, "count": positive_integer, "card_type": nonempty, "effect_id": nonempty,
            "godot_card_implementation_status_expected": {"const": "implemented"},
            "official_equivalence": {"enum": ["not_evaluated", "exact_print_bridge_only_not_engine_parity"]},
            "official_card_id": {"anyOf": [positive_integer, {"type": "null"}]},
        },
    )
    local_schema = closed(
        ["schema_version", "artifact_id", "deck_id", "deck_identity", "source_deck_raw_sha256", "source_deck_canonical_sha256", "card_count", "unique_printing_count", "cards", "cabt_exportable", "support_claim"],
        {
            "schema_version": {"const": 1}, "artifact_id": {"const": "ptcgdap-marnie-local-deck-manifest-v1"}, "deck_id": {"const": 800018501},
            "deck_identity": {"type": "string", "pattern": "^godot:800018501:[0-9a-f]{16}$"}, "source_deck_raw_sha256": sha, "source_deck_canonical_sha256": sha,
            "card_count": {"const": 60}, "unique_printing_count": {"const": 28}, "cards": {"type": "array", "minItems": 28, "maxItems": 28, "items": local_row},
            "cabt_exportable": {"const": False}, "support_claim": nonempty,
        },
    )
    diff_side_official = closed(
        ["card_count", "unique_card_id_count", "bridged_card_count", "bridged_unique_card_id_count", "unmapped_card_count", "unmapped_official_card_ids"],
        {"card_count": {"const": 60}, "unique_card_id_count": {"const": 19}, "bridged_card_count": {"const": 34}, "bridged_unique_card_id_count": {"const": 9}, "unmapped_card_count": {"const": 26}, "unmapped_official_card_ids": {"type": "array", "minItems": 10, "maxItems": 10, "items": positive_integer, "uniqueItems": True}},
    )
    diff_side_local = closed(
        ["card_count", "unique_printing_count", "bridged_card_count", "bridged_unique_printing_count", "unbridged_card_count"],
        {"card_count": {"const": 60}, "unique_printing_count": {"const": 28}, "bridged_card_count": {"const": 15}, "bridged_unique_printing_count": {"const": 4}, "unbridged_card_count": {"const": 45}},
    )
    diff_schema = closed(
        ["schema_version", "artifact_id", "same_deck", "comparison_authority", "name_text_art_inference", "official", "local", "cabt_exportable", "reason_codes"],
        {"schema_version": {"const": 1}, "artifact_id": {"const": "ptcgdap-marnie-deck-identity-diff-v1"}, "same_deck": {"const": False}, "comparison_authority": nonempty, "name_text_art_inference": {"const": "forbidden"}, "official": diff_side_official, "local": diff_side_local, "cabt_exportable": {"const": False}, "reason_codes": {"type": "array", "minItems": 4, "maxItems": 4, "items": {"enum": ["deck_lists_not_equal", "official_ids_local_unmapped", "local_printings_unbridged", "engine_parity_not_evaluated"]}, "uniqueItems": True}},
    )
    capability_row = closed(
        ["capability_id", "window_family", "required", "official_evidence", "official_card_ids", "local_engine_support", "portable_ready", "portable_blockers"],
        {"capability_id": nonempty, "window_family": {"pattern": "^W[0-7]$"}, "required": {"const": True}, "official_evidence": nonempty, "official_card_ids": {"type": "array", "items": positive_integer, "uniqueItems": True}, "local_engine_support": {"enum": ["implemented_current_godot_card_implementation_status", "interface_fixture_only"]}, "portable_ready": {"const": False}, "portable_blockers": {"type": "array", "minItems": 2, "items": nonempty, "uniqueItems": True}},
    )
    capability_schema = closed(
        ["schema_version", "artifact_id", "ability_numeric_identity", "capabilities"],
        {"schema_version": {"const": 1}, "artifact_id": {"const": "ptcgdap-marnie-capability-inventory-v1"}, "ability_numeric_identity": {"const": "unsupported_by_official_payload_no_synthesis"}, "capabilities": {"type": "array", "minItems": 10, "maxItems": 10, "items": capability_row}},
    )
    firewall_record = closed(
        ["status", "issue_code"],
        {"status": {"enum": ["accepted", "rejected", "not_invoked_after_terminal"]}, "issue_code": {"anyOf": [{"const": "own_active_concealed"}, {"type": "null"}]}},
    )
    visibility = closed(
        ["acting_hand_visible", "opponent_hand_hidden", "prizes_concealed", "own_active_concealed", "authorized_select_deck", "opponent_draw_identity_absent"],
        {key: {"type": "boolean"} for key in ["acting_hand_visible", "opponent_hand_hidden", "prizes_concealed", "own_active_concealed", "authorized_select_deck", "opponent_draw_identity_absent"]},
    )
    terminal = closed(
        ["new_callback_expected", "final_step", "both_seats_done"],
        {"new_callback_expected": {"const": False}, "final_step": nonnegative_integer, "both_seats_done": {"const": True}},
    )
    frame = closed(
        ["frame_id", "window_family", "callback_role", "source_replay_id", "source_step", "source_seat", "source_status", "source_action_authority", "public_tree", "public_observation_hash", "current_firewall", "window", "visibility", "terminal"],
        {"frame_id": nonempty, "window_family": {"pattern": "^W[0-7]$"}, "callback_role": nonempty, "source_replay_id": {"type": "string", "pattern": "^[0-9]+$"}, "source_step": nonnegative_integer, "source_seat": {"enum": [0, 1]}, "source_status": {"enum": ["ACTIVE", "INACTIVE", "DONE"]}, "source_action_authority": {"const": "not_policy_golden"}, "public_tree": {"anyOf": [node_ref, {"type": "null"}]}, "public_observation_hash": {"anyOf": [sha, {"type": "null"}]}, "current_firewall": firewall_record, "window": {"anyOf": [window, {"type": "null"}]}, "visibility": {"anyOf": [visibility, {"type": "null"}]}, "terminal": {"anyOf": [terminal, {"type": "null"}]}},
    )
    initial_action = closed(
        ["source_replay_id", "observation_step", "action_step", "official_deck_manifest_id", "card_count", "exact_ordered_card_ids"],
        {"source_replay_id": {"type": "string", "pattern": "^[0-9]+$"}, "observation_step": nonnegative_integer, "action_step": nonnegative_integer, "official_deck_manifest_id": {"const": "ptcgdap-marnie-official-deck-manifest-v1"}, "card_count": {"const": 60}, "exact_ordered_card_ids": {"type": "array", "minItems": 60, "maxItems": 60, "items": positive_integer}},
    )
    trajectory_schema = closed(
        ["schema_version", "artifact_id", "status", "source_container_policy", "initial_deck_action", "frames"],
        {"schema_version": {"const": 1}, "artifact_id": {"const": "ptcgdap-marnie-w0-w7-public-trajectory-v1"}, "status": {"const": "offline_source_locked_fixture"}, "source_container_policy": nonempty, "initial_deck_action": initial_action, "frames": {"type": "array", "minItems": 13, "maxItems": 13, "items": frame}},
    )
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/marnie_vertical_slice.schema.json",
        "title": "PtcgDAP Marnie vertical-slice fixture artifacts",
        "$defs": {
            "safeInteger": safe_integer,
            "positiveInteger": positive_integer,
            "sha256": sha,
            "localPrinting": local_printing,
            "encodedNode": encoded_node,
        },
        "oneOf": [
            profile_schema,
            source_schema,
            vectors_schema,
            official_schema,
            local_schema,
            diff_schema,
            capability_schema,
            trajectory_schema,
        ],
    }


def _render(value: Any) -> bytes:
    canonical_json_v1_bytes(value)
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def _bundle(documents: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "bundle_id": "ptcgdap-marnie-vertical-slice-p5-wp1-v1",
        "status": "offline_shadow_fixture",
        "parent": {
            "manifest_path": "artifacts/ptcgdap/p4_wp6/manifest.json",
            "manifest_canonical_sha256": "93B0F8170124AE5DD184FBD1BD17BBEC60C805A6EFC9D348C1B5ADAF5AD3369E",
        },
        "artifacts": [
            {
                "id": Path(path).stem,
                "path": path,
                "canonical_sha256": sha256_bytes(canonical_json_v1_bytes(documents[path])),
            }
            for path in ARTIFACT_PATHS
        ],
        "self_hash_policy": "bundle and bound artifacts do not contain the final bundle hash",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--oracle-root", type=Path, default=DEFAULT_ORACLE_ROOT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    documents = _documents(args.oracle_root.resolve())
    bundle = _bundle(documents)
    documents["contracts/ptcgdap/marnie_vertical_slice_bundle.json"] = bundle
    changed = []
    for relative, value in documents.items():
        path = ROOT / relative
        rendered = _render(value)
        if args.check:
            if not path.is_file() or path.read_bytes() != rendered:
                changed.append(relative)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(rendered)
    if changed:
        raise SystemExit("generated artifact drift: " + ", ".join(changed))
    bundle_bytes = _render(bundle)
    print(f"bundle_raw_sha256={sha256_bytes(bundle_bytes)}")
    print(f"bundle_canonical_sha256={sha256_bytes(canonical_json_v1_bytes(bundle))}")
    print(f"artifact_count={len(ARTIFACT_PATHS)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
