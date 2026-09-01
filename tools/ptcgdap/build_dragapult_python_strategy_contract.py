from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


PROFILE_ID = "ptcgdap-dragapult-python-public-strategy-v1"
BUNDLE_ID = "ptcgdap-dragapult-python-strategy-acceptance-v1"
STRATEGY_ID = "ptcgdap.dragapult.18.0.python-public-v1"
CARD_ID_DOMAIN = "godot_local_card_uid_v1"
DECK_ID = 800018499
OPPONENT_DECK_ID = 575720
SOURCE_DECK_PATH = "data/bundled_user/decks/800018499.json"
OPPONENT_DECK_PATH = "data/bundled_user/decks/575720.json"
SOURCE_DECK_RAW_SHA256 = "9BC21DCC24F4C9F0E1E9F0F6888E96FA821F7D6BF4E10AB7E78D2E8AE27DB1E0"
SOURCE_DECK_CANONICAL_SHA256 = "91AC9D3CEC464E9CCF24720AF216EE5F0CC2917ABF995CDB992ACEBD6E6AFE60"
OPPONENT_DECK_RAW_SHA256 = "F6EE202C9FEEC256A865648066E818646F98B07227008B359CA40921864896D1"
OPPONENT_DECK_CANONICAL_SHA256 = "38C14210A0974B13C5491CE7A9E77D37E4E798C8F7CEB4EBF647F839918641F7"
ARTIFACT_PATHS = {
    "schema": "contracts/ptcgdap/dragapult_python_strategy.schema.json",
    "profile": "contracts/ptcgdap/dragapult_python_strategy_profile.json",
    "vectors": "contracts/ptcgdap/dragapult_python_strategy_conformance_vectors.json",
    "deck_manifest": "data/ptcgdap/dragapult_python_strategy/deck_manifest_v1.json",
    "policy": "data/ptcgdap/dragapult_python_strategy/policy_v1.json",
    "opponent": "data/ptcgdap/dragapult_python_strategy/rules_ai_opponent_v1.json",
    "bundle": "contracts/ptcgdap/dragapult_python_strategy_bundle.json",
}
RUNTIME_ARTIFACTS = {
    "scripts/ai/AIOpponent.gd": "00077ED32713BA6E2108D55B0B653CBFE332757AD829ED605E2DDE1201A00130",
    "scripts/ai/AILegalActionBuilder.gd": "67631B187D4C8823E3BBD399FC4AFA28FEE127B42921A876F21084134DFAADB5",
    "scripts/ai/AIStepResolver.gd": "2D9E1F29D2E5A0DAA4AAC95D853D182012B0846F7FE02C8400CC5540797B574A",
    "scripts/ai/HeadlessMatchBridge.gd": "17FAFF5AA410EC8452521E7A57777993B8E2A2D0CF236496CDD0570E5C17EC92",
    "scripts/ai/AIBenchmarkRunner.gd": "55A771DD934F41351169B3F5ED62E84200A226E5B52AC9E06A4E4A2648E7A69D",
    "scripts/ai/DeckStrategyRegistry.gd": "88D38F966B0703884C6440D7EC8176F73E4337327FFC6012D656D1285BA448E5",
    "scripts/ai/DeckStrategyMiraidon.gd": "1ACA0F5D88870D2B49A3A433E8F3BF74A263950774B61E7D45B791B24E9B584F",
    "scripts/engine/GameStateMachine.gd": "338EC3EAFAC21905C958582272BEBCDC76374E059E810A71ED2659970E52EAAC",
}
UID_RE = re.compile(r"^[A-Za-z0-9.]+_[A-Za-z0-9]+$")
HEX32_RE = re.compile(r"^[0-9a-f]{32}$")


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _strict_object(properties: dict[str, object], required: list[str]) -> dict[str, object]:
    return {"type": "object", "additionalProperties": False, "required": required, "properties": properties}


def build_schema() -> dict[str, object]:
    upper_sha = {"type": "string", "pattern": "^[0-9A-F]{64}$"}
    nullable_uid = {"type": ["string", "null"], "pattern": "^[A-Za-z0-9.]+_[A-Za-z0-9]+$"}
    option = _strict_object(
        {
            "index": {"type": "integer", "minimum": 0, "maximum": 1023},
            "kind": {"type": "string", "enum": ["setup_active", "setup_bench", "play_basic_to_bench", "play_trainer", "play_stadium", "use_stadium_effect", "evolve", "attach_tool", "attach_energy", "use_ability", "retreat", "attack", "granted_attack", "end_turn", "search", "discard", "effect_target", "attack_target", "take_prize", "send_out", "end", "yes", "no"]},
            "card_uid": nullable_uid,
            "source_uid": nullable_uid,
            "target_uid": nullable_uid,
            "target_remaining_hp": {"type": ["integer", "null"], "minimum": 0, "maximum": 9999},
            "target_prize_value": {"type": ["integer", "null"], "minimum": 0, "maximum": 6},
            "attached_energy_count": {"type": ["integer", "null"], "minimum": 0, "maximum": 64},
            "attack_index": {"type": ["integer", "null"], "minimum": 0, "maximum": 31},
            "tags": {"type": "array", "maxItems": 16, "items": {"type": "string", "pattern": "^[a-z0-9][a-z0-9._-]{0,63}$"}, "uniqueItems": True},
        },
        ["index", "kind", "card_uid", "source_uid", "target_uid", "target_remaining_hp", "target_prize_value", "attached_energy_count", "attack_index", "tags"],
    )
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/dragapult_python_strategy.schema.json",
        "title": "PTCGDAP Dragapult development Python public strategy frame",
        **_strict_object(
            {
                "schema_version": {"const": 1},
                "profile_id": {"const": PROFILE_ID},
                "strategy_id": {"const": STRATEGY_ID},
                "card_id_domain": {"const": CARD_ID_DOMAIN},
                "sequence": {"type": "integer", "minimum": 1, "maximum": 9007199254740991},
                "seat": {"type": "integer", "enum": [0, 1]},
                "prompt_kind": {"type": "string", "enum": ["setup_active", "setup_bench", "main", "search", "evolve", "attach", "effect_target", "attack", "attack_target", "take_prize", "send_out", "terminal"]},
                "source": _strict_object({"public_observation_hash": upper_sha, "window_id": upper_sha}, ["public_observation_hash", "window_id"]),
                "public_state": {"type": "object"},
                "select_semantics": _strict_object({"min_count": {"type": "integer", "minimum": 0, "maximum": 1024}, "max_count": {"type": "integer", "minimum": 0, "maximum": 1024}}, ["min_count", "max_count"]),
                "options": {"type": "array", "minItems": 1, "maxItems": 1024, "items": option},
            },
            ["schema_version", "profile_id", "strategy_id", "card_id_domain", "sequence", "seat", "prompt_kind", "source", "public_state", "select_semantics", "options"],
        ),
    }


def _source_deck() -> dict[str, Any]:
    path = ROOT / SOURCE_DECK_PATH
    value = load_json_strict(path)
    if (
        _sha(path.read_bytes()) != SOURCE_DECK_RAW_SHA256
        or _sha(canonical_json_v1_bytes(value)) != SOURCE_DECK_CANONICAL_SHA256
        or value.get("id") != DECK_ID
        or value.get("deck_name") != "18.0 多龙巴鲁托"
        or value.get("total_cards") != 60
        or type(value.get("cards")) is not list
        or len(value["cards"]) != 24
    ):
        raise ValueError("Dragapult 18.0 source deck drift")
    return value


def build_deck_manifest() -> dict[str, object]:
    source = _source_deck()
    rows: list[dict[str, object]] = []
    seen: set[str] = set()
    total = 0
    for source_row in source["cards"]:
        if type(source_row) is not dict:
            raise ValueError("Dragapult source deck entry drift")
        set_code = source_row.get("set_code")
        card_index = source_row.get("card_index")
        count = source_row.get("count")
        uid = f"{set_code}_{card_index}"
        card_path = ROOT / "data/bundled_user/cards" / f"{uid}.json"
        if type(set_code) is not str or type(card_index) is not str or type(count) is not int or not 1 <= count <= 60 or not UID_RE.fullmatch(uid) or uid in seen or not card_path.is_file():
            raise ValueError("Dragapult source identity drift")
        seen.add(uid)
        card_bytes = card_path.read_bytes()
        card = load_json_strict(card_path)
        effect_id = card.get("effect_id")
        if (
            card.get("set_code") != set_code
            or card.get("card_index") != card_index
            or card.get("effect_id") != source_row.get("effect_id")
            or type(effect_id) is not str
            or HEX32_RE.fullmatch(effect_id) is None
        ):
            raise ValueError(f"Dragapult source card drift: {uid}")
        rows.append(
            {
                "local_card_uid": uid,
                "set_code": set_code,
                "card_index": card_index,
                "count": count,
                "card_type": str(card.get("card_type", "")),
                "stage": str(card.get("stage", "")),
                "effect_id": effect_id,
                "source_raw_sha256": _sha(card_bytes),
                "source_canonical_sha256": _sha(canonical_json_v1_bytes(card)),
            }
        )
        total += count
    rows.sort(key=lambda row: str(row["local_card_uid"]).encode("ascii"))
    if total != 60 or len(rows) != 24:
        raise ValueError("Dragapult exact 60 relation drift")
    return {
        "document_type": "dragapult_python_strategy_deck_manifest_v1",
        "schema_version": 1,
        "deck_id": "dragapult.18.0.800018499",
        "source_deck_id": DECK_ID,
        "source_deck_raw_sha256": SOURCE_DECK_RAW_SHA256,
        "source_deck_canonical_sha256": SOURCE_DECK_CANONICAL_SHA256,
        "card_id_domain": CARD_ID_DOMAIN,
        "card_count": 60,
        "unique_card_count": 24,
        "cabt_exportable": False,
        "platform_scope": ["windows_development_acceptance"],
        "cards": rows,
    }


def build_policy() -> dict[str, object]:
    return {
        "document_type": "dragapult_python_public_policy_v1",
        "schema_version": 1,
        "strategy_id": STRATEGY_ID,
        "card_id_domain": CARD_ID_DOMAIN,
        "deck_manifest_sha256": _sha(canonical_json_v1_bytes(build_deck_manifest())),
        "setup_active_priority": ["CSV8C_157", "CSV9.5C_004", "CSV10C_008", "CSV8C_094", "CSV9C_078", "CSV8C_135", "CSV1C_079", "CSV8C_172"],
        "setup_bench_priority": ["CSV8C_157", "CSV8C_094", "CSV9C_078", "CSV8C_135", "CSV9.5C_004", "CSV10C_008", "CSV1C_079", "CSV8C_172"],
        "search_priority": ["CSV8C_159", "CSV8C_158", "CSV8C_157", "CSV1C_127", "CSVE1C_FIR", "CSVE1C_PSY", "CSV7C_203", "CSV8C_094", "CSV8C_172", "CSV8C_183"],
        "main_kind_priority": ["attack", "granted_attack", "evolve", "attach_energy", "use_ability", "play_basic_to_bench", "play_trainer", "play_stadium", "use_stadium_effect", "attach_tool", "retreat", "end_turn"],
        "main_card_priority": ["CSV8C_159", "CSV8C_158", "CSV8C_157", "CSV1C_127", "CSVE1C_FIR", "CSVE1C_PSY", "CSV7C_203", "CSV7C_177", "CSV1C_112", "CSV10C_207", "CSV8C_183", "CSV6C_114", "CSVH1aC_023", "CSV6C_125", "CSV1C_121", "CSV3C_123", "CSV8C_094"],
        "send_out_priority": ["CSV8C_159", "CSV8C_158", "CSV8C_172", "CSV8C_094", "CSV9C_078", "CSV8C_135", "CSV8C_157", "CSV9.5C_004", "CSV10C_008", "CSV1C_079"],
        "attack_tag_priority": ["phantom_dive", "projected_knockout", "spread_knockout", "attack"],
        "fallback": "same_current_window_deterministic_first_min",
    }


def build_opponent() -> dict[str, object]:
    path = ROOT / OPPONENT_DECK_PATH
    value = load_json_strict(path)
    if _sha(path.read_bytes()) != OPPONENT_DECK_RAW_SHA256 or _sha(canonical_json_v1_bytes(value)) != OPPONENT_DECK_CANONICAL_SHA256 or value.get("id") != OPPONENT_DECK_ID:
        raise ValueError("Rules AI opponent deck drift")
    rows = []
    for runtime_path, expected_sha in RUNTIME_ARTIFACTS.items():
        actual = _sha((ROOT / runtime_path).read_bytes())
        if actual != expected_sha:
            raise ValueError(f"Rules AI runtime drift: {runtime_path}")
        rows.append({"path": runtime_path, "raw_sha256": expected_sha})
    return {
        "document_type": "dragapult_rules_ai_opponent_lock_v1",
        "schema_version": 1,
        "deck_id": OPPONENT_DECK_ID,
        "deck_path": OPPONENT_DECK_PATH,
        "deck_raw_sha256": OPPONENT_DECK_RAW_SHA256,
        "deck_canonical_sha256": OPPONENT_DECK_CANONICAL_SHA256,
        "strategy_id": "miraidon",
        "decision_runtime_mode": "rules_only",
        "network_allowed": False,
        "runtime_artifacts": rows,
    }


def build_profile() -> dict[str, object]:
    return {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "strategy_id": STRATEGY_ID,
        "public_boundary": "agent(public_frame) -> list[int]",
        "card_id_domain": CARD_ID_DOMAIN,
        "deck_identity_merge_with_official_cabt": False,
        "cabt_exportable": False,
        "development_python_only": True,
        "player_runtime_python_dependency": False,
        "engine_reference_allowed": False,
        "raw_private_state_allowed": False,
        "old_option_index_reuse_allowed": False,
        "unknown_field_policy": "fail_closed",
        "unknown_uid_policy": "fail_closed",
        "fallback": "deterministic_same_current_window",
        "prompt_families": ["setup_active", "setup_bench", "main", "search", "evolve", "attach", "effect_target", "attack", "attack_target", "take_prize", "send_out", "terminal"],
        "claims": {
            "isolated_python_policy": True,
            "godot_player_live": False,
            "production_signing": False,
            "android": False,
            "engine_parity": False,
        },
    }


def build_vectors() -> dict[str, object]:
    return {
        "schema_version": 1,
        "vector_set_id": "dragapult_python_public_strategy_v1",
        "profile_id": PROFILE_ID,
        "cases": [
            {"id": "setup_active_dreepy", "prompt_kind": "setup_active", "expected_indexes": [1]},
            {"id": "setup_bench_dreepy", "prompt_kind": "setup_bench", "expected_indexes": [1]},
            {"id": "main_evolve_dragapult", "prompt_kind": "main", "expected_indexes": [1]},
            {"id": "search_dragapult", "prompt_kind": "search", "expected_indexes": [1]},
            {"id": "attack_phantom_dive", "prompt_kind": "attack", "expected_indexes": [1]},
            {"id": "target_low_hp", "prompt_kind": "attack_target", "expected_indexes": [1]},
            {"id": "take_first_prize", "prompt_kind": "take_prize", "expected_indexes": [0]},
            {"id": "send_ready_dragapult", "prompt_kind": "send_out", "expected_indexes": [1]},
            {"id": "terminal_end", "prompt_kind": "terminal", "expected_indexes": [0]},
            {"id": "reject_private", "expected_error_code": "invalid_public_frame"},
            {"id": "reject_unknown_uid", "expected_error_code": "unknown_local_card_uid"},
        ],
    }


def build_documents() -> dict[str, dict[str, object]]:
    docs = {
        "schema": build_schema(),
        "profile": build_profile(),
        "vectors": build_vectors(),
        "deck_manifest": build_deck_manifest(),
        "policy": build_policy(),
        "opponent": build_opponent(),
    }
    docs["bundle"] = {
        "schema_version": 1,
        "bundle_id": BUNDLE_ID,
        "profile_id": PROFILE_ID,
        "artifacts": [
            {"id": key, "path": ARTIFACT_PATHS[key], "canonical_sha256": _sha(canonical_json_v1_bytes(docs[key]))}
            for key in ("schema", "profile", "vectors", "deck_manifest", "policy", "opponent")
        ],
    }
    return docs


def _render(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def rendered_artifacts() -> dict[str, bytes]:
    return {ARTIFACT_PATHS[key]: _render(value) for key, value in build_documents().items()}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write == args.check:
        raise SystemExit("choose exactly one of --write or --check")
    artifacts = rendered_artifacts()
    if args.check:
        drift = [path for path, value in artifacts.items() if not (ROOT / path).is_file() or (ROOT / path).read_bytes() != value]
        if drift:
            raise SystemExit("Dragapult Python strategy contract drift: " + ", ".join(drift))
    else:
        for relative, value in artifacts.items():
            destination = ROOT / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(value)
    print("bundle_canonical_sha256=" + _sha(canonical_json_v1_bytes(build_documents()["bundle"])))
    print("deck_manifest_canonical_sha256=" + _sha(canonical_json_v1_bytes(build_deck_manifest())))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
