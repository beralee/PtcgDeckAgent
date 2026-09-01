from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.cabt_envelope import parse_raw_cabt_envelope
from scripts.ai.ptcgdap.public_observation_firewall import PublicObservationFirewall
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"
SCHEMA_PATH = CONTRACT_ROOT / "godot_observation_projector.schema.json"
PROFILE_PATH = CONTRACT_ROOT / "godot_observation_projector_profile.json"
VECTORS_PATH = CONTRACT_ROOT / "godot_observation_projector_conformance_vectors.json"
BUNDLE_PATH = CONTRACT_ROOT / "godot_observation_projector_bundle.json"
BUNDLE_ID = "ptcgdap-godot-observation-projector-p2-wp5-v1"
PROFILE_ID = "godot_observation_projector_v1"
PARENT_CURSOR = "ED246F029531AA8F21956A64D70F557F1BBC90450A6F9109C5286261E290319D"
FIREWALL = "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947"
CATALOG = "AB8CF10465F492A98DA8247A84572AECEE281D0726F7BB7B8E5DBC03A6AC70D4"
P1 = "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _card(card_id: int, serial: int, player: int, *, energy_type: int | None = None) -> dict[str, Any]:
    value: dict[str, Any] = {"official_card_id": card_id, "serial": serial, "player_index": player}
    if energy_type is not None:
        value["energy_type"] = energy_type
    return value


def _status() -> dict[str, bool]:
    return {"poisoned": False, "burned": False, "asleep": False, "paralyzed": False, "confused": False}


def _pokemon(stack: list[dict[str, Any]], *, energy: list[dict[str, Any]] | None = None, tool: dict[str, Any] | None = None, hp: int = 70, max_hp: int = 70, appear: bool = False) -> dict[str, Any]:
    return {"stack": copy.deepcopy(stack), "attached_energy": copy.deepcopy(energy or []), "tool": copy.deepcopy(tool), "hp": hp, "max_hp": max_hp, "appear_this_turn": appear, "status": _status()}


def _base_current() -> dict[str, Any]:
    p0_active = _pokemon([_card(646, 1, 0)], energy=[_card(7, 2, 0, energy_type=7)])
    p1_active = _pokemon([_card(646, 61, 1)], hp=60, max_hp=70)
    p1_bench = _pokemon([_card(104, 63, 1)], hp=60, max_hp=60)
    return {
        "turn": 2,
        "turn_action_count": 3,
        "acting_player_index": 0,
        "first_player_index": 0,
        "supporter_played": False,
        "stadium_played": False,
        "energy_attached": True,
        "retreated": False,
        "result": -1,
        "stadium": None,
        "players": [
            {"active":[p0_active],"bench":[],"bench_max":5,"deck_count":50,"discard":[_card(1097,4,0)],"hand":[_card(647,3,0),_card(648,5,0)],"hand_count":2,"prize_count":6,"public_prizes":{}},
            {"active":[p1_active],"bench":[p1_bench],"bench_max":5,"deck_count":49,"discard":[],"hand":None,"hand_count":1,"prize_count":6,"public_prizes":{}},
        ],
    }


def _select(select_type: int, context: int, options: list[dict[str, Any]], *, minimum: int = 1, maximum: int = 1, deck: list[dict[str, Any]] | None = None, effect: dict[str, Any] | None = None) -> dict[str, Any]:
    return {"type":select_type,"context":context,"minCount":minimum,"maxCount":maximum,"remainDamageCounter":0,"remainEnergyCost":0,"option":copy.deepcopy(options),"deck":copy.deepcopy(deck),"contextCard":None,"effect":copy.deepcopy(effect)}


def _wire_card(card: dict[str, Any]) -> dict[str, int]:
    return {"id": card["official_card_id"], "playerIndex": card["player_index"], "serial": card["serial"]}


def _wire_select(source: dict[str, Any] | None) -> dict[str, Any] | None:
    if source is None:
        return None
    value = copy.deepcopy(source)
    if value["deck"] is not None:
        value["deck"] = [_wire_card(card) for card in value["deck"]]
    for key in ("contextCard", "effect"):
        if value[key] is not None:
            value[key] = _wire_card(value[key])
    return value


def _wire_pokemon(source: dict[str, Any]) -> dict[str, Any]:
    stack = source["stack"]
    top = stack[-1]
    energies = source["attached_energy"]
    tool = source["tool"]
    return {
        "appearThisTurn": source["appear_this_turn"],
        "energies": [card["energy_type"] for card in energies],
        "energyCards": [_wire_card(card) for card in energies],
        "hp": source["hp"],
        "id": top["official_card_id"],
        "maxHp": source["max_hp"],
        "playerIndex": top["player_index"],
        "preEvolution": [_wire_card(card) for card in stack[:-1]],
        "serial": top["serial"],
        "tools": [] if tool is None else [_wire_card(tool)],
    }


def _wire_player(source: dict[str, Any], player_index: int, acting_index: int) -> dict[str, Any]:
    active = source["active"]
    status = _status() if not active else active[0]["status"]
    prizes: list[dict[str, int] | None] = [None] * source["prize_count"]
    for index_text, card in source["public_prizes"].items():
        index = int(index_text)
        if index < 0 or index >= len(prizes):
            raise ValueError("invalid_state")
        prizes[index] = _wire_card(card)
    return {
        "active": [_wire_pokemon(item) for item in active],
        "asleep": status["asleep"],
        "bench": [_wire_pokemon(item) for item in source["bench"]],
        "benchMax": source["bench_max"],
        "burned": status["burned"],
        "confused": status["confused"],
        "deckCount": source["deck_count"],
        "discard": [_wire_card(card) for card in source["discard"]],
        "hand": [_wire_card(card) for card in source["hand"]] if player_index == acting_index else None,
        "handCount": source["hand_count"],
        "paralyzed": status["paralyzed"],
        "poisoned": status["poisoned"],
        "prize": prizes,
    }


def _wire_log(event: dict[str, Any]) -> dict[str, Any]:
    kind = event["kind"]
    if kind == "turn_start":
        return {"playerIndex": event["player_index"], "type": 2}
    if kind == "turn_end":
        return {"playerIndex": event["player_index"], "type": 3}
    if kind == "move_card":
        card = _wire_card(event["card"])
        return {"cardId":card["id"],"fromArea":event["from_area"],"playerIndex":card["playerIndex"],"serial":card["serial"],"toArea":event["to_area"],"type":6}
    if kind == "play":
        card = _wire_card(event["card"])
        return {"cardId":card["id"],"playerIndex":card["playerIndex"],"serial":card["serial"],"type":10}
    if kind == "attach":
        card = _wire_card(event["card"]); target = _wire_card(event["target"])
        return {"cardId":card["id"],"cardIdTarget":target["id"],"playerIndex":card["playerIndex"],"serial":card["serial"],"serialTarget":target["serial"],"type":11}
    if kind == "evolve":
        card = _wire_card(event["card"])
        return {"cardId":card["id"],"playerIndex":card["playerIndex"],"serial":card["serial"],"type":12}
    if kind == "attack":
        card = _wire_card(event["card"])
        return {"attackId":event["attack_id"],"cardId":card["id"],"playerIndex":card["playerIndex"],"serial":card["serial"],"type":15}
    if kind == "hp_change":
        card = _wire_card(event["card"])
        return {"cardId":card["id"],"playerIndex":card["playerIndex"],"putDamageCounter":event["put_damage_counter"],"serial":card["serial"],"type":16,"value":event["value"]}
    if kind == "result":
        return {"playerIndex":event["player_index"],"type":23}
    raise ValueError("invalid_public_event")


def _raw_projection(source: dict[str, Any]) -> dict[str, Any]:
    current = source["current_source"]
    acting = current["acting_player_index"]
    stadium = current["stadium"]
    wire_current = {
        "energyAttached":current["energy_attached"],"firstPlayer":current["first_player_index"],"looking":None,
        "players":[_wire_player(player,index,acting) for index,player in enumerate(current["players"])],
        "result":current["result"],"retreated":current["retreated"],
        "stadium":[] if stadium is None else [_wire_card(stadium)],"stadiumPlayed":current["stadium_played"],
        "supporterPlayed":current["supporter_played"],"turn":current["turn"],"turnActionCount":current["turn_action_count"],"yourIndex":acting,
    }
    raw: dict[str, Any] = {"select":_wire_select(source["select_source"]),"logs":[_wire_log(event) for event in source["public_events"]],"current":wire_current,"search_begin_input":None}
    if "step" in source:
        raw["step"] = source["step"]
    if "remainingOverageTime" in source:
        raw["remainingOverageTime"] = source["remainingOverageTime"]
    return raw


def _expected(source: dict[str, Any]) -> dict[str, Any]:
    try:
        raw = _raw_projection(source)
        parsed = parse_raw_cabt_envelope(raw)
        result = PublicObservationFirewall.load_default().project(parsed)
        if not result.accepted:
            return {"accepted":False,"error_code":"firewall_rejected","public_observation_hash":None,"select_type":None,"select_context":None,"option_count":0,"log_count":0,"acting_hand_visible":False,"opponent_hand_hidden":False}
        observation = result.public_observation
        select = observation["select"]
        return {
            "accepted":True,"error_code":"","public_observation_hash":result.public_observation_hash,
            "select_type":None if select is None else select["type"],"select_context":None if select is None else select["context"],
            "option_count":0 if select is None else len(select["option"]),"log_count":len(observation["logs"]),
            "acting_hand_visible":observation["current"]["players"][observation["current"]["yourIndex"]]["hand"] is not None,
            "opponent_hand_hidden":observation["current"]["players"][1-observation["current"]["yourIndex"]]["hand"] is None,
        }
    except (KeyError, TypeError, ValueError, IndexError):
        return {"accepted":False,"error_code":"invalid_input","public_observation_hash":None,"select_type":None,"select_context":None,"option_count":0,"log_count":0,"acting_hand_visible":False,"opponent_hand_hidden":False}


def _case(case_id: str, window: str, select_source: dict[str, Any], events: list[dict[str, Any]]) -> dict[str, Any]:
    input_value = {"current_source":_base_current(),"select_source":select_source,"public_events":copy.deepcopy(events),"step":int(window[1:]),"remainingOverageTime":600}
    return {
        "case_id": case_id,
        "window": window,
        "state_fixture_id": "base_mapped_state",
        "select_source": copy.deepcopy(select_source),
        "public_events": copy.deepcopy(events),
        "step": int(window[1:]),
        "remainingOverageTime": 600,
        "expected_result": _expected(input_value),
    }


def _rejection(case_id: str, fault: dict[str, Any], error_code: str) -> dict[str, Any]:
    return {
        "case_id":case_id,
        "base_case_id":"w1_setup_active",
        "fault":copy.deepcopy(fault),
        "expected_result":{"accepted":False,"error_code":error_code,"public_observation_hash":None,"select_type":None,"select_context":None,"option_count":0,"log_count":0,"acting_hand_visible":False,"opponent_hand_hidden":False},
    }


def build_vectors() -> dict[str, Any]:
    c647 = _card(647,3,0); c648 = _card(648,5,0); energy = _card(7,2,0,energy_type=7); active = _card(646,1,0); opp_bench = _card(104,63,1)
    cases = [
        _case("w1_setup_active","W1",_select(1,1,[{"type":3,"area":2,"index":0,"playerIndex":0}]),[]),
        _case("w2_setup_bench","W2",_select(1,2,[{"type":3,"area":2,"index":0,"playerIndex":0},{"type":3,"area":2,"index":1,"playerIndex":0}],minimum=0,maximum=2),[{"kind":"play","card":c647}]),
        _case("w3_main_atomic","W3",_select(0,0,[{"type":7,"index":0},{"type":13,"attackId":934},{"type":14}]),[{"kind":"turn_start","player_index":0}]),
        _case("w4_authorized_search","W4",_select(1,7,[{"type":3,"area":1,"index":0,"playerIndex":0},{"type":3,"area":1,"index":1,"playerIndex":0}],minimum=0,maximum=1,deck=[c647,c648],effect=active),[{"kind":"play","card":active}]),
        _case("w5_ordered_energy_skill","W5",_select(5,34,[{"type":15,"cardId":7,"serial":2}],minimum=1,maximum=1),[{"kind":"attach","card":energy,"target":active}]),
        _case("w6_bench_target","W6",_select(1,25,[{"type":3,"area":5,"index":0,"playerIndex":1}]),[{"kind":"attack","card":active,"attack_id":934},{"kind":"hp_change","card":opp_bench,"value":-10,"put_damage_counter":False}]),
        _case("w7_prize_choice","W7",_select(1,7,[{"type":3,"area":6,"index":0,"playerIndex":0}],minimum=1,maximum=1),[{"kind":"move_card","card":c647,"from_area":6,"to_area":2}]),
    ]
    rejection_cases = [
        _rejection("invalid_actor",{"kind":"replace","pointer":"/current_source/acting_player_index","value":2},"invalid_player_index"),
        _rejection("hand_count_mismatch",{"kind":"replace","pointer":"/current_source/players/0/hand_count","value":1},"invalid_state"),
        _rejection("catalog_unmapped_card",{"kind":"replace","pointer":"/current_source/players/0/hand/0/official_card_id","value":860},"card_catalog_unmapped"),
        _rejection("card_owner_mismatch",{"kind":"replace","pointer":"/current_source/players/0/hand/0/player_index","value":1},"invalid_card_identity"),
        _rejection("hp_exceeds_max",{"kind":"replace","pointer":"/current_source/players/0/active/0/hp","value":71},"invalid_state"),
        _rejection("attack_owner_mismatch",{"kind":"replace_public_events","value":[{"kind":"attack","card":active,"attack_id":936}]},"invalid_attack_identity"),
        _rejection("skill_serial_unbound",{"kind":"replace_select_options","value":[{"type":15,"cardId":7,"serial":999}]},"invalid_select"),
        _rejection("duplicate_card_serial",{"kind":"replace","pointer":"/current_source/players/0/hand/0/serial","value":1},"invalid_card_identity"),
    ]
    return {"schema_version":1,"artifact_id":"ptcgdap-godot-observation-projector-conformance-v1","profile_id":PROFILE_ID,"state_fixtures":{"base_mapped_state":_base_current()},"projection_cases":cases,"rejection_cases":rejection_cases}


def build_bundle() -> dict[str, Any]:
    artifacts = [
        ("godot_observation_projector_schema_v1", "contracts/ptcgdap/godot_observation_projector.schema.json", SCHEMA_PATH),
        ("godot_observation_projector_profile_v1", "contracts/ptcgdap/godot_observation_projector_profile.json", PROFILE_PATH),
        ("godot_observation_projector_conformance_v1", "contracts/ptcgdap/godot_observation_projector_conformance_vectors.json", VECTORS_PATH),
    ]
    return {
        "schema_version":1,"bundle_id":BUNDLE_ID,"source_lock_canonical_sha256":SOURCE_LOCK,"p1_contract_canonical_sha256":P1,
        "catalog_bundle_canonical_sha256":CATALOG,"firewall_bundle_canonical_sha256":FIREWALL,"parent_cursor_bundle_canonical_sha256":PARENT_CURSOR,
        "artifacts":[{"id":artifact_id,"path":path,"canonical_sha256":_sha(canonical_json_v1_bytes(load_json_strict(file_path)))} for artifact_id,path,file_path in artifacts],
    }


def _pretty(value: object) -> str:
    return json.dumps(value, ensure_ascii=False, indent=2, sort_keys=False) + "\n"


def check() -> int:
    expected_vectors = build_vectors()
    if load_json_strict(VECTORS_PATH) != expected_vectors:
        print("projector vectors drift", file=sys.stderr)
        return 1
    expected_bundle = build_bundle()
    if load_json_strict(BUNDLE_PATH) != expected_bundle:
        print("projector bundle drift", file=sys.stderr)
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--check", action="store_true")
    group.add_argument("--print-vectors", action="store_true")
    group.add_argument("--print-bundle", action="store_true")
    group.add_argument("--write", action="store_true")
    args = parser.parse_args()
    if args.print_vectors:
        print(_pretty(build_vectors()), end="")
        return 0
    if args.print_bundle:
        print(_pretty(build_bundle()), end="")
        return 0
    if args.write:
        VECTORS_PATH.write_text(_pretty(build_vectors()), encoding="utf-8", newline="\n")
        BUNDLE_PATH.write_text(_pretty(build_bundle()), encoding="utf-8", newline="\n")
        return 0
    return check()


if __name__ == "__main__":
    raise SystemExit(main())
