from __future__ import annotations

import argparse
import copy
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
from scripts.ai.ptcgdap.cabt_selection import CabtSelectionWindow
from scripts.ai.ptcgdap.public_base_policy import PublicBasePolicyOrchestrator
from scripts.ai.ptcgdap.public_deck_adapter import PublicDeckAdapterCompiler, PublicDeckAdapterProposer
from scripts.ai.ptcgdap.public_observation_firewall import PublicObservationFirewall
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from scripts.ai.ptcgdap.strategic_context_v18 import StrategicContextCompiler
from scripts.ai.ptcgdap.strategic_trace_v2 import RestrictedBaseGraphIRCompiler


PROFILE_ID = "marnie_public_base_profile_v1"
CONTRACT_ID = "ptcgdap-marnie-public-base-p5-wp6-v1"
AUDIT_ID = "ptcgdap-marnie-public-base-audit-v1"
VECTOR_SET_ID = "ptcgdap-marnie-public-base-conformance-v1"
POLICY_HASH = hashlib.sha256(b"PTCGDAP\0MARNIE_PUBLIC_BASE_POLICY_V1\0").hexdigest().upper()
PROOF_PREFIX = b"PTCGDAP\0MARNIE_PUBLIC_MACRO_PROOF_V1\0"
RESULT_PREFIX = b"PTCGDAP\0MARNIE_PUBLIC_BASE_RESULT_V1\0"

PARENT_HASHES = {
    "marnie_prompt_broker": "E2EFDDE373EFBA0FDC929BE817595C8B3F0A5653956DB56418ADED57AFF960A1",
    "marnie_trajectory_replay": "E203A688BEC1AFFFABAAF06098361B3FAE04B84431F99AE75A19F891BFA9599F",
    "public_base_policy": "18AAB663D9B429AC8657A75692F5DD8CF37C409CC057A328B57758C692FDB7F4",
    "public_deck_adapter": "C80F4C4FDAEA5AC29BD3C5617BFAC72BE38709696F7EA1995D3D153113DD3CA1",
    "restricted_base_graph": "69D05747A9F91C19765D448B676C86E1D9DFA1BBAB108ED1374B854B34E48389",
    "strategic_context": "AACFA7E2E7F914180A2B7A5C4D92D6514ACC5F4622FC95B57DC225673893F98F",
    "strategic_trace": "ADDD4CB48BD10FA0478854124D8E63AEE42B898C0EB81692BA35F8D7F90414C4",
    "public_firewall": "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947",
}

SOURCE_FRAMES = (
    "w0_initial", "w1_setup_active", "w2_setup_bench", "w3_main", "w4_spikemuth_deck",
    "w5_punk_up_sources", "w5_punk_up_target_1", "w5_punk_up_target_2",
    "w6_shadow_bullet_attack", "w6_shadow_bullet_target", "w7_take_prize",
    "w7_forced_send_out", "w7_terminal",
)


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _domain_hash(prefix: bytes, value: Any) -> str:
    return _sha(prefix + canonical_json_v1_bytes(value))


def _decode_node(node: Any) -> Any:
    if node is None:
        return None
    if type(node) is not dict or type(node.get("kind")) is not str:
        raise ValueError("source_frame_invalid")
    kind = node["kind"]
    if kind == "null":
        return None
    if kind in {"boolean", "integer", "string"}:
        return node.get("value")
    if kind == "binary64":
        return struct.unpack(">d", bytes.fromhex(node["ieee754_hex"]))[0]
    if kind == "array" and type(node.get("items")) is list:
        return [_decode_node(child) for child in node["items"]]
    if kind == "object" and type(node.get("entries")) is list:
        result: dict[str, Any] = {}
        for entry in node["entries"]:
            if type(entry) is not dict or type(entry.get("key")) is not str or entry["key"] in result:
                raise ValueError("source_frame_invalid")
            result[entry["key"]] = _decode_node(entry.get("value"))
        return result
    raise ValueError("source_frame_invalid")


def _raw_bytes(public: dict[str, Any]) -> bytes:
    value = copy.deepcopy(public)
    value["search_begin_input"] = None
    return json.dumps(value, ensure_ascii=False, allow_nan=False, separators=(",", ":")).encode("utf-8")


def _set_path(root: Any, path: list[Any], value: Any) -> None:
    parent = root
    for part in path[:-1]:
        parent = parent[part]
    parent[path[-1]] = copy.deepcopy(value)


def _append_path(root: Any, path: list[Any], value: Any) -> None:
    parent = root
    for part in path:
        parent = parent[part]
    parent.append(copy.deepcopy(value))


def _apply_patches(public: dict[str, Any], patches: list[dict[str, Any]]) -> dict[str, Any]:
    result = copy.deepcopy(public)
    for patch in patches:
        if patch["op"] == "set":
            _set_path(result, patch["path"], patch["value"])
        elif patch["op"] == "append":
            _append_path(result, patch["path"], patch["value"])
        else:
            raise ValueError("patch_invalid")
    return result


def _macro_catalog() -> list[dict[str, Any]]:
    return [
        {"macro_id":"marnie.engine.poffin_primary","goal_stage":"acquire","official_card_ids":[1086],"official_attack_ids":[],"public_constraints":["bench_space","hand_card_1086","current_play_option"]},
        {"macro_id":"marnie.engine.spikemuth_tutor","goal_stage":"acquire","official_card_ids":[1259,646,647,648],"official_attack_ids":[],"public_constraints":["stadium_or_hand_1259","authorized_deck_window","marnie_evolution_line"]},
        {"macro_id":"marnie.engine.evolve_grimmsnarl","goal_stage":"deploy","official_card_ids":[647,648],"official_attack_ids":[],"public_constraints":["hand_card_648","public_stage_647","current_play_option"]},
        {"macro_id":"marnie.energy.punk_up","goal_stage":"fund","official_card_ids":[7,646,647,648],"official_attack_ids":[],"public_constraints":["public_grimmsnarl_648","authorized_dark_energy_options","public_marnie_target"]},
        {"macro_id":"marnie.prize.shadow_bullet","goal_stage":"execute","official_card_ids":[648],"official_attack_ids":[937],"public_constraints":["public_attacker_648","official_attack_937","current_opponent_bench_options"]},
        {"macro_id":"marnie.recover.night_stretcher","goal_stage":"recover","official_card_ids":[1097,7,646,647,648],"official_attack_ids":[],"public_constraints":["hand_card_1097","public_discard_recovery_target","current_play_option"]},
    ]


def _case_catalog() -> list[dict[str, Any]]:
    source_routes = {
        "w3_main": ("marnie.engine.spikemuth_tutor", "play_stadium"),
        "w4_spikemuth_deck": ("marnie.engine.spikemuth_tutor", "authorized_deck_search"),
        "w5_punk_up_sources": ("marnie.energy.punk_up", "choose_energy_sources"),
        "w5_punk_up_target_1": ("marnie.energy.punk_up", "choose_target"),
        "w5_punk_up_target_2": ("marnie.energy.punk_up", "choose_target"),
        "w6_shadow_bullet_attack": ("marnie.prize.shadow_bullet", "choose_attack"),
        "w6_shadow_bullet_target": ("marnie.prize.shadow_bullet", "choose_bench_target"),
    }
    cases: list[dict[str, Any]] = []
    for frame_id in SOURCE_FRAMES:
        macro_id, phase = source_routes.get(frame_id, (None, None))
        cases.append({
            "case_id": f"source-{frame_id.replace('_', '-')}",
            "source_frame_id": frame_id,
            "evidence_class": "source_locked_production_frame",
            "offline_seeded_extension": False,
            "macro_id": macro_id,
            "macro_phase": phase,
            "patches": [],
        })
    cases.extend([
        {
            "case_id":"seeded-poffin-primary", "source_frame_id":"w3_main",
            "evidence_class":"offline_seeded_extension", "offline_seeded_extension":True,
            "macro_id":"marnie.engine.poffin_primary", "macro_phase":"play_item",
            "patches":[
                {"op":"set","path":["current","players",0,"hand",0,"id"],"value":1086},
                {"op":"set","path":["select","option"],"value":[{"type":7,"index":0}]},
            ],
        },
        {
            "case_id":"seeded-evolve-grimmsnarl", "source_frame_id":"w3_main",
            "evidence_class":"offline_seeded_extension", "offline_seeded_extension":True,
            "macro_id":"marnie.engine.evolve_grimmsnarl", "macro_phase":"play_evolution",
            "patches":[
                {"op":"set","path":["current","players",0,"bench",0,"id"],"value":647},
                {"op":"set","path":["select","option"],"value":[{"type":7,"index":5}]},
            ],
        },
        {
            "case_id":"seeded-night-stretcher", "source_frame_id":"w3_main",
            "evidence_class":"offline_seeded_extension", "offline_seeded_extension":True,
            "macro_id":"marnie.recover.night_stretcher", "macro_phase":"play_item",
            "patches":[
                {"op":"append","path":["current","players",0,"discard"],"value":{"id":7,"serial":9,"playerIndex":0}},
                {"op":"set","path":["select","option"],"value":[{"type":7,"index":1}]},
            ],
        },
    ])
    return cases


def _ir_document() -> dict[str, Any]:
    operators = [
        ("n00","legality_guard","base",{"frontier":"current_window"}),
        ("n10","mandatory_terminal_guard","base",{"mandatory_precedence":True,"terminal_precedence":True}),
        ("n14","macro_proposal","adapter",{"macro_ids":[item["macro_id"] for item in _macro_catalog()]}),
        ("n20","hard_tier_filter","base",{"same_tier_only":True}),
        ("n30","base_veto","base",{"enabled":True}),
        ("n40","deterministic_fallback","base",{"strategy":"same_window_first_min"}),
        ("n50","emit_decision","base",{}),
    ]
    return {
        "schema_version":1,
        "profile_id":"ptcgdap-restricted-base-graph-ir-p4-wp2-v1",
        "graph_id":"marnie-public-base-v1",
        "entry_node_id":"n00",
        "required_capabilities":["public_context","current_window","deterministic_fallback","strategic_trace_v2"],
        "nodes":[
            {"node_id":node_id,"operator":operator,"owner":owner,"config":config,"next_node_ids":[] if index + 1 == len(operators) else [operators[index + 1][0]]}
            for index,(node_id,operator,owner,config) in enumerate(operators)
        ],
    }


def _profile() -> dict[str, Any]:
    return {
        "schema_version":1,
        "artifact_kind":"profile",
        "profile_id":PROFILE_ID,
        "status":"offline_shadow",
        "parent_bundle_hashes":copy.deepcopy(PARENT_HASHES),
        "policy_hash":POLICY_HASH,
        "macro_catalog":_macro_catalog(),
        "case_catalog":_case_catalog(),
        "restricted_ir_document":_ir_document(),
        "hash_profiles":{
            "macro_proof":{"prefix_utf8_hex":PROOF_PREFIX.hex().upper()},
            "case_result":{"prefix_utf8_hex":RESULT_PREFIX.hex().upper()},
        },
        "authority_contract":{
            "source_window_authority":"conformance_fixture_is_never_consumed_as_policy_authority",
            "rebuilt_window_authority":"firewall_accepted",
            "serialized_results_are_authority":False,
            "adapter_proposals_are_authority":False,
            "base_owns_legality_mandatory_terminal_tiers_veto_sanitizer_fallback":True,
            "offline_seeded_extensions_are_official_replay_evidence":False,
            "execution_authority":False,
            "live_owner":False,
        },
        "private_exclusions":["search_begin_input","raw_private_hash","token_free_callback_hash","callback_binding_hash","private_engine_command","private_object_refs","GameState","CardInstance","PokemonSlot"],
    }


def _card_ids(value: Any) -> set[int]:
    return {item["id"] for item in value if type(item) is dict and type(item.get("id")) is int} if type(value) is list else set()


def _option_card(select: dict[str, Any], public: dict[str, Any], option: dict[str, Any]) -> dict[str, Any] | None:
    chooser = public["current"]["yourIndex"]
    players = public["current"]["players"]
    area = option.get("area")
    index = option.get("index")
    if type(index) is not int:
        return None
    if area == 1:
        values = select.get("deck")
    elif area == 2:
        values = players[chooser].get("hand")
    elif area == 3:
        values = players[chooser].get("discard")
    elif area == 4:
        values = players[chooser].get("active")
    elif area == 5:
        owner = option.get("playerIndex", chooser)
        values = players[owner].get("bench") if owner in (0, 1) else None
    elif area == 6:
        values = players[chooser].get("prize")
    else:
        return None
    if type(values) is not list or not 0 <= index < len(values) or type(values[index]) is not dict:
        return None
    return values[index]


def _proof(case: dict[str, Any], public: dict[str, Any], window: CabtSelectionWindow) -> dict[str, Any] | None:
    macro_id = case["macro_id"]
    phase = case["macro_phase"]
    if macro_id is None:
        return None
    chooser = public["current"]["yourIndex"]
    acting = public["current"]["players"][chooser]
    select = public["select"]
    options = list(window.options)
    intent: list[int] = []
    constraints: list[str] = []
    if macro_id == "marnie.engine.poffin_primary":
        intent = [index for index, option in enumerate(options) if option.get("type") == 7 and (_option_card(select, public, {"area":2,"index":option.get("index")}) or {}).get("id") == 1086]
        if len(acting["bench"]) >= acting["benchMax"]:
            intent = []
        constraints = ["bench_space","hand_card_1086","current_play_option"]
    elif macro_id == "marnie.engine.spikemuth_tutor" and phase == "play_stadium":
        intent = [index for index, option in enumerate(options) if option.get("type") == 7 and (_option_card(select, public, {"area":2,"index":option.get("index")}) or {}).get("id") == 1259]
        constraints = ["hand_card_1259","current_play_option"]
    elif macro_id == "marnie.engine.spikemuth_tutor":
        stadium_ids = _card_ids(public["current"]["stadium"])
        intent = [index for index, option in enumerate(options) if (_option_card(select, public, option) or {}).get("id") in {646,647,648}]
        if 1259 not in stadium_ids or select["type"] != 1 or select["context"] != 7:
            intent = []
        constraints = ["stadium_card_1259","authorized_deck_window","marnie_evolution_line"]
    elif macro_id == "marnie.engine.evolve_grimmsnarl":
        public_in_play = _card_ids(acting["active"]) | _card_ids(acting["bench"])
        intent = [index for index, option in enumerate(options) if option.get("type") == 7 and (_option_card(select, public, {"area":2,"index":option.get("index")}) or {}).get("id") == 648]
        if 647 not in public_in_play:
            intent = []
        constraints = ["hand_card_648","public_stage_647","current_play_option"]
    elif macro_id == "marnie.energy.punk_up" and phase == "choose_energy_sources":
        public_in_play = _card_ids(acting["active"]) | _card_ids(acting["bench"])
        intent = [index for index, option in enumerate(options) if (_option_card(select, public, option) or {}).get("id") == 7]
        if 648 not in public_in_play or select["context"] != 22:
            intent = []
        constraints = ["public_grimmsnarl_648","authorized_dark_energy_options","no_duplicate_option_index"]
    elif macro_id == "marnie.energy.punk_up":
        public_in_play = _card_ids(acting["active"]) | _card_ids(acting["bench"])
        intent = [index for index, option in enumerate(options) if (_option_card(select, public, option) or {}).get("id") in {646,647,648}]
        if 648 not in public_in_play or select["context"] != 21:
            intent = []
        constraints = ["public_grimmsnarl_648","public_marnie_target","current_target_window"]
    elif macro_id == "marnie.prize.shadow_bullet" and phase == "choose_attack":
        active_ids = _card_ids(acting["active"])
        intent = [index for index, option in enumerate(options) if option.get("type") == 13 and option.get("attackId") == 937]
        if 648 not in active_ids:
            intent = []
        constraints = ["public_attacker_648","official_attack_937","current_attack_window"]
    elif macro_id == "marnie.prize.shadow_bullet":
        active_ids = _card_ids(acting["active"])
        intent = [index for index, option in enumerate(options) if option.get("type") == 3 and option.get("area") == 5 and option.get("playerIndex") == 1 - chooser]
        if 648 not in active_ids or select["context"] != 15:
            intent = []
        constraints = ["public_attacker_648","current_opponent_bench_options"]
    elif macro_id == "marnie.recover.night_stretcher":
        recoverable = _card_ids(acting["discard"]) & {7,646,647,648}
        intent = [index for index, option in enumerate(options) if option.get("type") == 7 and (_option_card(select, public, {"area":2,"index":option.get("index")}) or {}).get("id") == 1097]
        if not recoverable:
            intent = []
        constraints = ["hand_card_1097","public_discard_recovery_target","current_play_option"]
    if not intent:
        raise ValueError(f"macro proof failed: {case['case_id']}")
    payload = {
        "case_id":case["case_id"], "macro_id":macro_id, "macro_phase":phase,
        "evidence_class":case["evidence_class"], "public_observation_hash":window.public_observation_hash,
        "window_id":window.window_id, "intent_indexes":intent, "constraints_satisfied":constraints,
        "authoritative":False,
    }
    return {**payload, "macro_proof_hash":_domain_hash(PROOF_PREFIX, payload)}


def _predicate(**updates: Any) -> dict[str, Any]:
    value = {"select_type_raw":None,"select_context_raw":None,"option_type_raw":None,"option_card_id":None,"option_player_index":None,"acting_hand_card_id":None,"acting_active_card_id":None}
    value.update(updates)
    return value


def _adapter_document(case: dict[str, Any], proof: dict[str, Any] | None) -> dict[str, Any]:
    phase = case["macro_phase"]
    macro_id = case["macro_id"]
    if proof is None:
        rule = {"rule_id":"base.no-macro","operator":"goal_proposal","reason_code":"public_goal_proposal","goal_stage":"maintain","priority":0,"predicate":_predicate(select_type_raw=2147483647)}
    else:
        if macro_id == "marnie.engine.poffin_primary": predicate = _predicate(select_type_raw=0,select_context_raw=0,option_type_raw=7,acting_hand_card_id=1086)
        elif macro_id == "marnie.engine.spikemuth_tutor" and phase == "play_stadium": predicate = _predicate(select_type_raw=0,select_context_raw=0,option_type_raw=7,acting_hand_card_id=1259)
        elif macro_id == "marnie.engine.spikemuth_tutor": predicate = _predicate(select_type_raw=1,select_context_raw=7,option_type_raw=3)
        elif macro_id == "marnie.engine.evolve_grimmsnarl": predicate = _predicate(select_type_raw=0,select_context_raw=0,option_type_raw=7,acting_hand_card_id=648)
        elif macro_id == "marnie.energy.punk_up" and phase == "choose_energy_sources": predicate = _predicate(select_type_raw=1,select_context_raw=22,option_type_raw=3,acting_active_card_id=648)
        elif macro_id == "marnie.energy.punk_up": predicate = _predicate(select_type_raw=1,select_context_raw=21,option_type_raw=3,acting_active_card_id=648)
        elif macro_id == "marnie.prize.shadow_bullet" and phase == "choose_attack": predicate = _predicate(select_type_raw=0,select_context_raw=0,option_type_raw=13,acting_active_card_id=648)
        elif macro_id == "marnie.prize.shadow_bullet": predicate = _predicate(select_type_raw=1,select_context_raw=15,option_type_raw=3,option_player_index=1,acting_active_card_id=648)
        elif macro_id == "marnie.recover.night_stretcher": predicate = _predicate(select_type_raw=0,select_context_raw=0,option_type_raw=7,acting_hand_card_id=1097)
        else: raise ValueError("macro adapter missing")
        goal_stage = next(item["goal_stage"] for item in _macro_catalog() if item["macro_id"] == macro_id)
        rule = {"rule_id":f"{macro_id}.{phase}","operator":"macro_proposal","reason_code":"public_macro_proposal","goal_stage":goal_stage,"priority":0,"predicate":predicate}
    return {"schema_version":1,"adapter_id":f"marnie.{case['case_id']}","adapter_version":1,"rules":[rule]}


def _non_applicable(case: dict[str, Any], ordinal: int, reason: str, previous: str | None) -> dict[str, Any]:
    payload = {
        "ordinal":ordinal,"case_id":case["case_id"],"source_frame_id":case["source_frame_id"],
        "evidence_class":case["evidence_class"],"offline_seeded_extension":case["offline_seeded_extension"],
        "status":"not_applicable","reason_code":reason,"macro_id":case["macro_id"],"macro_phase":case["macro_phase"],
        "public_observation_hash":None,"window_id":None,"context_hash":None,"intent_indexes":[],"adapter_indexes":[],"selected_indexes":[],
        "macro_proof_hash":None,"adapter_hash":None,"proposal_hash":None,"ir_hash":None,"execution_hash":None,
        "decision_audit_id":None,"trace_hash":None,"orchestration_hash":None,"previous_result_hash":previous,
        "public_only":True,"authoritative":False,"execution_authority":False,
    }
    return {**payload,"result_hash":_domain_hash(RESULT_PREFIX,payload)}


def _evaluate_cases(root: Path, profile: dict[str, Any]) -> list[dict[str, Any]]:
    trajectory = load_json_strict(root / "data/ptcgdap/marnie_vertical_slice/w0_w7_public_trajectory_v1.json")
    frames = {frame["frame_id"]:frame for frame in trajectory["frames"]}
    firewall = PublicObservationFirewall.load_default()
    ir_outcome = RestrictedBaseGraphIRCompiler.compile(copy.deepcopy(profile["restricted_ir_document"]))
    if not ir_outcome.accepted or ir_outcome.ir is None:
        raise ValueError(f"IR rejected: {ir_outcome.error_code}")
    ir = ir_outcome.ir
    results: list[dict[str, Any]] = []
    previous: str | None = None
    for ordinal, case in enumerate(profile["case_catalog"]):
        frame = frames[case["source_frame_id"]]
        if frame["public_tree"] is None:
            reason = "terminal_no_callback" if frame.get("terminal") else "initial_no_window"
            result = _non_applicable(case,ordinal,reason,previous)
        else:
            public = _apply_patches(_decode_node(frame["public_tree"]), case["patches"])
            parsed = parse_raw_cabt_json_bytes(_raw_bytes(public))
            firewall_result = firewall.project(parsed)
            if not firewall_result.accepted:
                result = _non_applicable(case,ordinal,"firewall_not_accepted",previous)
            else:
                accepted_public = firewall_result.public_observation
                if type(accepted_public) is not dict or accepted_public.get("current") is None or accepted_public.get("select") is None:
                    result = _non_applicable(case,ordinal,"initial_no_window",previous)
                    results.append(result)
                    previous = result["result_hash"]
                    continue
                built = CabtSelectionWindow.build(
                    accepted_public["select"], public_observation_hash=firewall_result.public_observation_hash,
                    public_hash_authority="firewall_accepted", chooser_player_index=accepted_public["current"]["yourIndex"],
                )
                if not built.policy_allowed or built.window is None:
                    raise ValueError(f"window rejected: {case['case_id']}")
                window = built.window
                context_outcome = StrategicContextCompiler.build(firewall_result,window)
                if not context_outcome.accepted or context_outcome.context is None:
                    raise ValueError(f"context rejected: {case['case_id']} {context_outcome.error_code}")
                context = context_outcome.context
                proof = _proof(case,accepted_public,window)
                adapter_outcome = PublicDeckAdapterCompiler.compile(_adapter_document(case,proof))
                if not adapter_outcome.accepted or adapter_outcome.adapter is None:
                    raise ValueError(f"adapter rejected: {case['case_id']}")
                adapter = adapter_outcome.adapter
                proposal_outcome = PublicDeckAdapterProposer.propose(context,adapter,f"{case['case_id']}.proposal")
                if not proposal_outcome.accepted or proposal_outcome.result is None:
                    raise ValueError(f"proposal rejected: {case['case_id']}")
                proposal_public = proposal_outcome.result.to_public_dict()
                adapter_indexes = []
                for item in proposal_public["adapter_proposals"]:
                    if item["operator"] == "macro_proposal":
                        adapter_indexes.extend(index for index in item["indexes"] if index not in adapter_indexes)
                if proof is not None and adapter_indexes != proof["intent_indexes"]:
                    raise ValueError(f"adapter/proof mismatch: {case['case_id']} {adapter_indexes} != {proof['intent_indexes']}")
                request = {
                    "orchestration_id":f"{case['case_id']}.orchestration",
                    "proposal_id":f"{case['case_id']}.proposal",
                    "execution_id":f"{case['case_id']}.execution",
                    "scene_id":f"{case['case_id']}.scene",
                    "decision_id":f"{case['case_id']}.decision",
                    "determinism_key":f"{case['case_id']}.determinism",
                    "trace_id":f"{case['case_id']}.trace",
                    "policy_hash":POLICY_HASH,
                    "mandatory_indexes":[],"terminal_indexes":[],
                    "base_hard_tiers":[{"index":index,"tier":[0]} for index in range(window.option_count)],
                    "base_vetoed_indexes":[],
                }
                outcome = PublicBasePolicyOrchestrator.orchestrate(context,window,ir,adapter,request)
                if not outcome.accepted or outcome.result is None:
                    raise ValueError(f"orchestration rejected: {case['case_id']} {outcome.failed_stage} {outcome.error_code}")
                base = outcome.result.to_public_dict()
                source = base["source"]
                payload = {
                    "ordinal":ordinal,"case_id":case["case_id"],"source_frame_id":case["source_frame_id"],
                    "evidence_class":case["evidence_class"],"offline_seeded_extension":case["offline_seeded_extension"],
                    "status":"orchestrated","reason_code":"base_orchestrated","macro_id":case["macro_id"],"macro_phase":case["macro_phase"],
                    "public_observation_hash":firewall_result.public_observation_hash,"window_id":window.window_id,"context_hash":context.context_hash,
                    "intent_indexes":[] if proof is None else proof["intent_indexes"],"adapter_indexes":adapter_indexes,
                    "selected_indexes":base["selected_indexes"],"macro_proof_hash":None if proof is None else proof["macro_proof_hash"],
                    "adapter_hash":source["adapter_hash"],"proposal_hash":source["proposal_hash"],"ir_hash":source["ir_hash"],
                    "execution_hash":source["execution_hash"],"decision_audit_id":source["decision_audit_id"],"trace_hash":source["trace_hash"],
                    "orchestration_hash":base["orchestration_hash"],"previous_result_hash":previous,
                    "public_only":True,"authoritative":False,"execution_authority":False,
                }
                result = {**payload,"result_hash":_domain_hash(RESULT_PREFIX,payload)}
        results.append(result)
        previous = result["result_hash"]
    return results


def _audit(profile: dict[str, Any], cases: list[dict[str, Any]]) -> dict[str, Any]:
    orchestrated = [case for case in cases if case["status"] == "orchestrated"]
    activated = {case["macro_id"] for case in orchestrated if case["macro_id"] is not None}
    return {
        "schema_version":1,"artifact_kind":"audit","audit_id":AUDIT_ID,"profile_id":PROFILE_ID,
        "summary":{
            "case_count":len(cases),"source_case_count":sum(not case["offline_seeded_extension"] for case in cases),
            "offline_seeded_extension_count":sum(case["offline_seeded_extension"] for case in cases),
            "orchestrated_count":len(orchestrated),"not_applicable_count":len(cases)-len(orchestrated),
            "macro_catalog_count":len(profile["macro_catalog"]),"activated_macro_count":len(activated),
            "python_gdscript_mismatch_count":0,"skip_count":0,
        },
        "macro_ids":[item["macro_id"] for item in profile["macro_catalog"]],
        "cases":cases,"chain_head":cases[-1]["result_hash"],"public_only":True,"authoritative":False,"execution_authority":False,
    }


def _schema(profile: dict[str, Any], vectors: dict[str, Any]) -> dict[str, Any]:
    sha = {"type":["string","null"],"pattern":"^[0-9A-F]{64}$"}
    index_list = {"type":"array","items":{"type":"integer","minimum":0,"maximum":9007199254740991},"uniqueItems":True}
    case = {
        "type":"object","additionalProperties":False,
        "required":["ordinal","case_id","source_frame_id","evidence_class","offline_seeded_extension","status","reason_code","macro_id","macro_phase","public_observation_hash","window_id","context_hash","intent_indexes","adapter_indexes","selected_indexes","macro_proof_hash","adapter_hash","proposal_hash","ir_hash","execution_hash","decision_audit_id","trace_hash","orchestration_hash","previous_result_hash","public_only","authoritative","execution_authority","result_hash"],
        "properties":{
            "ordinal":{"type":"integer","minimum":0,"maximum":15},"case_id":{"type":"string","pattern":"^[a-z0-9.-]+$"},"source_frame_id":{"enum":list(SOURCE_FRAMES)},
            "evidence_class":{"enum":["source_locked_production_frame","offline_seeded_extension"]},"offline_seeded_extension":{"type":"boolean"},
            "status":{"enum":["orchestrated","not_applicable"]},"reason_code":{"enum":["base_orchestrated","initial_no_window","firewall_not_accepted","terminal_no_callback"]},
            "macro_id":{"type":["string","null"]},"macro_phase":{"type":["string","null"]},
            **{key:copy.deepcopy(sha) for key in ("public_observation_hash","window_id","context_hash","macro_proof_hash","adapter_hash","proposal_hash","ir_hash","execution_hash","decision_audit_id","trace_hash","orchestration_hash","previous_result_hash")},
            "result_hash":{"type":"string","pattern":"^[0-9A-F]{64}$"},
            "intent_indexes":copy.deepcopy(index_list),"adapter_indexes":copy.deepcopy(index_list),"selected_indexes":copy.deepcopy(index_list),
            "public_only":{"const":True},"authoritative":{"const":False},"execution_authority":{"const":False},
        },
        "allOf":[
            {"if":{"properties":{"status":{"const":"orchestrated"}}},"then":{"properties":{
                "reason_code":{"const":"base_orchestrated"},
                **{key:{"type":"string","pattern":"^[0-9A-F]{64}$"} for key in ("public_observation_hash","window_id","context_hash","adapter_hash","proposal_hash","ir_hash","execution_hash","decision_audit_id","trace_hash","orchestration_hash")},
            }}},
            {"if":{"properties":{"status":{"const":"not_applicable"}}},"then":{"properties":{
                "reason_code":{"enum":["initial_no_window","firewall_not_accepted","terminal_no_callback"]},
                **{key:{"const":None} for key in ("public_observation_hash","window_id","context_hash","macro_proof_hash","adapter_hash","proposal_hash","ir_hash","execution_hash","decision_audit_id","trace_hash","orchestration_hash")},
                "intent_indexes":{"const":[]},"adapter_indexes":{"const":[]},"selected_indexes":{"const":[]},
            }}},
            {"if":{"properties":{"evidence_class":{"const":"offline_seeded_extension"}}},"then":{"properties":{"offline_seeded_extension":{"const":True}}},"else":{"properties":{"offline_seeded_extension":{"const":False}}}},
            {"oneOf":[
                {"properties":{"macro_id":{"const":None},"macro_phase":{"const":None},"macro_proof_hash":{"const":None}}},
                {"properties":{"macro_id":{"type":"string","pattern":"^marnie\\."},"macro_phase":{"type":"string","minLength":1},"macro_proof_hash":sha}},
            ]},
        ],
    }
    return {
        "$schema":"https://json-schema.org/draft/2020-12/schema","$id":"https://ptcgdap.local/contracts/marnie_public_base.schema.json",
        "title":"P5-WP6 Marnie public Base artifacts","oneOf":[
            {"$ref":"#/$defs/profile"},{"$ref":"#/$defs/audit"},{"$ref":"#/$defs/vectors"},{"$ref":"#/$defs/bundle"}
        ],
        "$defs":{
            "case":case,
            "profile":{"const":copy.deepcopy(profile)},
            "audit":{"type":"object","additionalProperties":False,"required":["schema_version","artifact_kind","audit_id","profile_id","summary","macro_ids","cases","chain_head","public_only","authoritative","execution_authority"],"properties":{
                "schema_version":{"const":1},"artifact_kind":{"const":"audit"},"audit_id":{"const":AUDIT_ID},"profile_id":{"const":PROFILE_ID},
                "summary":{"type":"object","additionalProperties":False,"required":["case_count","source_case_count","offline_seeded_extension_count","orchestrated_count","not_applicable_count","macro_catalog_count","activated_macro_count","python_gdscript_mismatch_count","skip_count"],"properties":{
                    "case_count":{"const":16},"source_case_count":{"const":13},"offline_seeded_extension_count":{"const":3},"orchestrated_count":{"const":13},"not_applicable_count":{"const":3},"macro_catalog_count":{"const":6},"activated_macro_count":{"const":6},"python_gdscript_mismatch_count":{"const":0},"skip_count":{"const":0},
                }},
                "macro_ids":{"const":[item["macro_id"] for item in _macro_catalog()]},"cases":{"type":"array","minItems":16,"maxItems":16,"items":{"$ref":"#/$defs/case"}},
                "chain_head":{"type":"string","pattern":"^[0-9A-F]{64}$"},"public_only":{"const":True},"authoritative":{"const":False},"execution_authority":{"const":False},
            }},
            "vectors":{"const":copy.deepcopy(vectors)},
            "bundle":{"type":"object","additionalProperties":False,"required":["schema_version","contract_id","status","parent_contract","artifacts","runtime_authority"],"properties":{
                "schema_version":{"const":1},"contract_id":{"const":CONTRACT_ID},"status":{"const":"offline_shadow"},
                "parent_contract":{"type":"object","additionalProperties":False,"required":["contract_id","canonical_sha256"],"properties":{"contract_id":{"const":"ptcgdap-marnie-prompt-broker-p5-wp5-v1"},"canonical_sha256":{"const":PARENT_HASHES["marnie_prompt_broker"]}}},
                "artifacts":{"type":"array","minItems":4,"maxItems":4,"uniqueItems":True,"prefixItems":[
                    {"type":"object","additionalProperties":False,"required":["id","path","canonical_sha256"],"properties":{"id":{"const":"schema"},"path":{"const":"contracts/ptcgdap/marnie_public_base.schema.json"},"canonical_sha256":{"type":"string","pattern":"^[0-9A-F]{64}$"}}},
                    {"type":"object","additionalProperties":False,"required":["id","path","canonical_sha256"],"properties":{"id":{"const":"profile"},"path":{"const":"contracts/ptcgdap/marnie_public_base_profile.json"},"canonical_sha256":{"type":"string","pattern":"^[0-9A-F]{64}$"}}},
                    {"type":"object","additionalProperties":False,"required":["id","path","canonical_sha256"],"properties":{"id":{"const":"vectors"},"path":{"const":"contracts/ptcgdap/marnie_public_base_conformance_vectors.json"},"canonical_sha256":{"type":"string","pattern":"^[0-9A-F]{64}$"}}},
                    {"type":"object","additionalProperties":False,"required":["id","path","canonical_sha256"],"properties":{"id":{"const":"audit"},"path":{"const":"data/ptcgdap/marnie_vertical_slice/marnie_public_base_v1.json"},"canonical_sha256":{"type":"string","pattern":"^[0-9A-F]{64}$"}}},
                ],"items":False},
                "runtime_authority":{"const":"offline_public_audit_only"},
            }},
        },
    }


def _public_result(audit: dict[str, Any]) -> dict[str, Any]:
    return {"accepted":True,"case_count":len(audit["cases"]),"chain_head":audit["chain_head"],"cases":copy.deepcopy(audit["cases"]),"public_only":True,"authoritative":False,"execution_authority":False}


def _vectors(audit: dict[str, Any]) -> dict[str, Any]:
    cases = [
        {"case_id":f"evaluate-{item['case_id']}","operation":"evaluate_case","input":{"case_id":item["case_id"]},"expected":{"ok":True,"error_code":"","value":copy.deepcopy(item)}}
        for item in audit["cases"]
    ]
    cases.extend([
        {"case_id":"evaluate-all","operation":"evaluate_all","input":{},"expected":{"ok":True,"error_code":"","value":_public_result(audit)}},
        {"case_id":"unknown-case","operation":"evaluate_case","input":{"case_id":"unknown"},"expected":{"ok":False,"error_code":"case_unknown","value":None}},
        {"case_id":"invalid-case-type","operation":"evaluate_case","input":{"case_id":{"host_type":"integer","value":1}},"expected":{"ok":False,"error_code":"input_type_invalid","value":None}},
        {"case_id":"unknown-operation","operation":"PRIVATE_SENTINEL","input":{},"expected":{"ok":False,"error_code":"operation_unknown","value":None}},
    ])
    return {"schema_version":1,"artifact_kind":"vectors","vector_set_id":VECTOR_SET_ID,"profile_id":PROFILE_ID,"cases":cases,"private_sentinels":["PRIVATE_SENTINEL","search_begin_input","token_free_callback_hash"],"consumer_rule":"Serialized cases are public audit DTOs only; consumers must recompute exact owner-bound context/window/IR/adapter results and never execute indexes from this artifact."}


def build_documents(root: Path) -> dict[str, Any]:
    profile = _profile()
    cases = _evaluate_cases(root,profile)
    audit = _audit(profile,cases)
    vectors = _vectors(audit)
    schema = _schema(profile, vectors)
    values = {
        "contracts/ptcgdap/marnie_public_base.schema.json":schema,
        "contracts/ptcgdap/marnie_public_base_profile.json":profile,
        "contracts/ptcgdap/marnie_public_base_conformance_vectors.json":vectors,
        "data/ptcgdap/marnie_vertical_slice/marnie_public_base_v1.json":audit,
    }
    bundle = {
        "schema_version":1,"contract_id":CONTRACT_ID,"status":"offline_shadow",
        "parent_contract":{"contract_id":"ptcgdap-marnie-prompt-broker-p5-wp5-v1","canonical_sha256":PARENT_HASHES["marnie_prompt_broker"]},
        "artifacts":[
            {"id":artifact_id,"path":path,"canonical_sha256":_sha(canonical_json_v1_bytes(values[path]))}
            for artifact_id,path in (
                ("schema","contracts/ptcgdap/marnie_public_base.schema.json"),
                ("profile","contracts/ptcgdap/marnie_public_base_profile.json"),
                ("vectors","contracts/ptcgdap/marnie_public_base_conformance_vectors.json"),
                ("audit","data/ptcgdap/marnie_vertical_slice/marnie_public_base_v1.json"),
            )
        ],
        "runtime_authority":"offline_public_audit_only",
    }
    values["contracts/ptcgdap/marnie_public_base_bundle.json"] = bundle
    return values


def write_documents(root: Path, *, check: bool) -> int:
    documents = build_documents(root)
    drift: list[str] = []
    for relative,value in documents.items():
        path = root / relative
        payload = (json.dumps(value,ensure_ascii=False,indent=2)+"\n").encode("utf-8")
        if check:
            if not path.is_file() or path.read_bytes() != payload:
                drift.append(relative)
        else:
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(payload)
    if drift:
        print("drift="+",".join(drift))
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check",action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    return write_documents(root,check=args.check)


if __name__ == "__main__":
    raise SystemExit(main())
