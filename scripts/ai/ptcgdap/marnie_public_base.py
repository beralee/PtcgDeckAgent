from __future__ import annotations

import copy
import hashlib
import json
from collections.abc import Mapping
from pathlib import Path, PurePosixPath
import struct
from types import MappingProxyType
from typing import Any
import weakref

from .cabt_envelope import parse_raw_cabt_json_bytes
from .cabt_selection import CabtSelectionWindow
from .marnie_vertical_slice import MarnieVerticalSlice
from .public_base_policy import PublicBasePolicyOrchestrator
from .public_deck_adapter import PublicDeckAdapterCompiler, PublicDeckAdapterProposer
from .public_observation_firewall import PublicObservationFirewall
from .source_lock import canonical_json_v1_bytes, load_json_bytes_strict
from .strategic_context_v18 import StrategicContextCompiler
from .strategic_trace_v2 import RestrictedBaseGraphIRCompiler


ROOT = Path(__file__).resolve().parents[3]
PROFILE_ID = "marnie_public_base_profile_v1"
CONTRACT_ID = "ptcgdap-marnie-public-base-p5-wp6-v1"
EXPECTED_BUNDLE_CANONICAL_SHA256 = "67EBA6348277001692942FD58E8D1B9D50C54F0FFC783D8802BA3CCB45691105"
EXPECTED_DOCUMENT_INTEGRITY_SHA256 = "166906CEE9380EEF94A642CB9CCA9B2AF7A94AC546935CB91942FFD3B03B8C32"
EXPECTED_ARTIFACTS = MappingProxyType({
    "schema": ("contracts/ptcgdap/marnie_public_base.schema.json", "54F3B35CE104ECFCB4879CB37C2548EE3589C4E9CD7028D4DF6C270C99356AB0"),
    "profile": ("contracts/ptcgdap/marnie_public_base_profile.json", "4F6A0544443EFB04EAE09DDA54CECADC422F613B56F79D881AC2402473C121B9"),
    "vectors": ("contracts/ptcgdap/marnie_public_base_conformance_vectors.json", "18B9E5C3F744A086B8142BA63992BC1913C36840E4F2E848451D9012280E9552"),
    "audit": ("data/ptcgdap/marnie_vertical_slice/marnie_public_base_v1.json", "56D4E01370D0FDE971588A9A0E5ECF2556476560ABCC7A0FFD374470704B33F3"),
})
PARENT_BUNDLES = MappingProxyType({
    "marnie_prompt_broker": ("contracts/ptcgdap/marnie_prompt_broker_bundle.json", "E2EFDDE373EFBA0FDC929BE817595C8B3F0A5653956DB56418ADED57AFF960A1"),
    "marnie_trajectory_replay": ("contracts/ptcgdap/marnie_trajectory_replay_bundle.json", "E203A688BEC1AFFFABAAF06098361B3FAE04B84431F99AE75A19F891BFA9599F"),
    "public_base_policy": ("contracts/ptcgdap/public_base_policy_bundle.json", "18AAB663D9B429AC8657A75692F5DD8CF37C409CC057A328B57758C692FDB7F4"),
    "public_deck_adapter": ("contracts/ptcgdap/public_deck_adapter_bundle.json", "C80F4C4FDAEA5AC29BD3C5617BFAC72BE38709696F7EA1995D3D153113DD3CA1"),
    "restricted_base_graph": ("contracts/ptcgdap/restricted_base_graph_executor_bundle.json", "69D05747A9F91C19765D448B676C86E1D9DFA1BBAB108ED1374B854B34E48389"),
    "strategic_context": ("contracts/ptcgdap/strategic_context_v18_bundle.json", "AACFA7E2E7F914180A2B7A5C4D92D6514ACC5F4622FC95B57DC225673893F98F"),
    "strategic_trace": ("contracts/ptcgdap/strategic_trace_v2_bundle.json", "ADDD4CB48BD10FA0478854124D8E63AEE42B898C0EB81692BA35F8D7F90414C4"),
    "public_firewall": ("contracts/ptcgdap/cabt_public_firewall_bundle.json", "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947"),
})
PROOF_PREFIX = b"PTCGDAP\0MARNIE_PUBLIC_MACRO_PROOF_V1\0"
RESULT_PREFIX = b"PTCGDAP\0MARNIE_PUBLIC_BASE_RESULT_V1\0"
MAX_BYTES = 2 * 1024 * 1024
FACTORY_TOKEN = object()
FORBIDDEN_PUBLIC_KEYS = frozenset({"search_begin_input","raw_private_hash","token_free_callback_hash","callback_binding_hash","private_engine_command","private_object_refs","ticket","command"})


class MarniePublicBaseError(RuntimeError):
    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _canonical_hash(value: Any) -> str:
    return _sha(canonical_json_v1_bytes(value))


def _domain_hash(prefix: bytes, value: Any) -> str:
    return _sha(prefix + canonical_json_v1_bytes(value))


def _copy(value: Any) -> Any:
    if isinstance(value, Mapping):
        return {key:_copy(item) for key,item in value.items()}
    if type(value) in (list,tuple):
        return [_copy(item) for item in value]
    return value


def _freeze(value: Any) -> Any:
    if type(value) is dict:
        return MappingProxyType({key:_freeze(item) for key,item in value.items()})
    if type(value) in (list,tuple):
        return tuple(_freeze(item) for item in value)
    return value


def _contains_forbidden(value: Any) -> bool:
    if type(value) is dict:
        return any(type(key) is not str or key in FORBIDDEN_PUBLIC_KEYS or _contains_forbidden(item) for key,item in value.items())
    if type(value) in (list,tuple):
        return any(_contains_forbidden(item) for item in value)
    return False


def _safe_relative(raw: Any) -> str:
    if type(raw) is not str or not raw or "\\" in raw or "\0" in raw:
        raise MarniePublicBaseError("contract_integrity_invalid")
    path = PurePosixPath(raw)
    if path.is_absolute() or "." in path.parts or ".." in path.parts or ":" in path.parts[0] or path.as_posix() != raw:
        raise MarniePublicBaseError("contract_integrity_invalid")
    return raw


def _contained(root: Path, relative: str) -> Path:
    resolved_root = root.resolve()
    candidate = (resolved_root / _safe_relative(relative)).resolve()
    try:
        candidate.relative_to(resolved_root)
    except ValueError as exc:
        raise MarniePublicBaseError("contract_integrity_invalid") from exc
    return candidate


def _read_json_once(path: Path) -> Any:
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise MarniePublicBaseError("contract_integrity_invalid") from exc
    if not raw or len(raw) > MAX_BYTES:
        raise MarniePublicBaseError("contract_integrity_invalid")
    try:
        return load_json_bytes_strict(raw)
    except (TypeError,UnicodeError,ValueError) as exc:
        raise MarniePublicBaseError("contract_integrity_invalid") from exc


def _decode_node(node: Any) -> Any:
    if node is None:
        return None
    if type(node) is not dict or type(node.get("kind")) is not str:
        raise MarniePublicBaseError("source_frame_invalid")
    kind = node["kind"]
    if kind == "null": return None
    if kind in {"boolean","integer","string"}: return node.get("value")
    if kind == "binary64": return struct.unpack(">d",bytes.fromhex(node["ieee754_hex"]))[0]
    if kind == "array" and type(node.get("items")) is list: return [_decode_node(item) for item in node["items"]]
    if kind == "object" and type(node.get("entries")) is list:
        result: dict[str,Any] = {}
        for entry in node["entries"]:
            if type(entry) is not dict or type(entry.get("key")) is not str or entry["key"] in result:
                raise MarniePublicBaseError("source_frame_invalid")
            result[entry["key"]] = _decode_node(entry.get("value"))
        return result
    raise MarniePublicBaseError("source_frame_invalid")


def _raw_bytes(public: dict[str,Any]) -> bytes:
    value = copy.deepcopy(public)
    value["search_begin_input"] = None
    return json.dumps(value,ensure_ascii=False,allow_nan=False,separators=(",",":")).encode("utf-8")


def _apply_patches(public: dict[str,Any], patches: list[dict[str,Any]]) -> dict[str,Any]:
    result = copy.deepcopy(public)
    for patch in patches:
        parent: Any = result
        path = patch["path"]
        for part in path[:-1] if patch["op"] == "set" else path:
            parent = parent[part]
        if patch["op"] == "set": parent[path[-1]] = copy.deepcopy(patch["value"])
        elif patch["op"] == "append": parent.append(copy.deepcopy(patch["value"]))
        else: raise MarniePublicBaseError("contract_integrity_invalid")
    return result


def _card_ids(value: Any) -> set[int]:
    return {item["id"] for item in value if type(item) is dict and type(item.get("id")) is int} if type(value) is list else set()


def _option_card(select: dict[str,Any], public: dict[str,Any], option: dict[str,Any]) -> dict[str,Any] | None:
    chooser = public["current"]["yourIndex"]
    players = public["current"]["players"]
    area,index = option.get("area"),option.get("index")
    if type(index) is not int: return None
    if area == 1: values = select.get("deck")
    elif area == 2: values = players[chooser].get("hand")
    elif area == 3: values = players[chooser].get("discard")
    elif area == 4: values = players[chooser].get("active")
    elif area == 5:
        owner = option.get("playerIndex",chooser)
        values = players[owner].get("bench") if owner in (0,1) else None
    elif area == 6: values = players[chooser].get("prize")
    else: return None
    return values[index] if type(values) is list and 0 <= index < len(values) and type(values[index]) is dict else None


def _proof(case: dict[str,Any], public: dict[str,Any], window: CabtSelectionWindow) -> dict[str,Any] | None:
    macro_id,phase = case["macro_id"],case["macro_phase"]
    if macro_id is None: return None
    chooser = public["current"]["yourIndex"]
    acting,select,options = public["current"]["players"][chooser],public["select"],list(window.options)
    intent: list[int] = []
    constraints: list[str] = []
    hand_card = lambda option: _option_card(select,public,{"area":2,"index":option.get("index")}) or {}
    if macro_id == "marnie.engine.poffin_primary":
        intent=[i for i,o in enumerate(options) if o.get("type")==7 and hand_card(o).get("id")==1086]
        if len(acting["bench"]) >= acting["benchMax"]: intent=[]
        constraints=["bench_space","hand_card_1086","current_play_option"]
    elif macro_id == "marnie.engine.spikemuth_tutor" and phase == "play_stadium":
        intent=[i for i,o in enumerate(options) if o.get("type")==7 and hand_card(o).get("id")==1259]
        constraints=["hand_card_1259","current_play_option"]
    elif macro_id == "marnie.engine.spikemuth_tutor":
        intent=[i for i,o in enumerate(options) if (_option_card(select,public,o) or {}).get("id") in {646,647,648}]
        if 1259 not in _card_ids(public["current"]["stadium"]) or select["type"]!=1 or select["context"]!=7: intent=[]
        constraints=["stadium_card_1259","authorized_deck_window","marnie_evolution_line"]
    elif macro_id == "marnie.engine.evolve_grimmsnarl":
        intent=[i for i,o in enumerate(options) if o.get("type")==7 and hand_card(o).get("id")==648]
        if 647 not in (_card_ids(acting["active"])|_card_ids(acting["bench"])): intent=[]
        constraints=["hand_card_648","public_stage_647","current_play_option"]
    elif macro_id == "marnie.energy.punk_up" and phase == "choose_energy_sources":
        intent=[i for i,o in enumerate(options) if (_option_card(select,public,o) or {}).get("id")==7]
        if 648 not in (_card_ids(acting["active"])|_card_ids(acting["bench"])) or select["context"]!=22: intent=[]
        constraints=["public_grimmsnarl_648","authorized_dark_energy_options","no_duplicate_option_index"]
    elif macro_id == "marnie.energy.punk_up":
        intent=[i for i,o in enumerate(options) if (_option_card(select,public,o) or {}).get("id") in {646,647,648}]
        if 648 not in (_card_ids(acting["active"])|_card_ids(acting["bench"])) or select["context"]!=21: intent=[]
        constraints=["public_grimmsnarl_648","public_marnie_target","current_target_window"]
    elif macro_id == "marnie.prize.shadow_bullet" and phase == "choose_attack":
        intent=[i for i,o in enumerate(options) if o.get("type")==13 and o.get("attackId")==937]
        if 648 not in _card_ids(acting["active"]): intent=[]
        constraints=["public_attacker_648","official_attack_937","current_attack_window"]
    elif macro_id == "marnie.prize.shadow_bullet":
        intent=[i for i,o in enumerate(options) if o.get("type")==3 and o.get("area")==5 and o.get("playerIndex")==1-chooser]
        if 648 not in _card_ids(acting["active"]) or select["context"]!=15: intent=[]
        constraints=["public_attacker_648","current_opponent_bench_options"]
    elif macro_id == "marnie.recover.night_stretcher":
        intent=[i for i,o in enumerate(options) if o.get("type")==7 and hand_card(o).get("id")==1097]
        if not (_card_ids(acting["discard"]) & {7,646,647,648}): intent=[]
        constraints=["hand_card_1097","public_discard_recovery_target","current_play_option"]
    if not intent: raise MarniePublicBaseError("macro_proof_invalid")
    payload={"case_id":case["case_id"],"macro_id":macro_id,"macro_phase":phase,"evidence_class":case["evidence_class"],"public_observation_hash":window.public_observation_hash,"window_id":window.window_id,"intent_indexes":intent,"constraints_satisfied":constraints,"authoritative":False}
    return {**payload,"macro_proof_hash":_domain_hash(PROOF_PREFIX,payload)}


def _predicate(**updates: Any) -> dict[str,Any]:
    value={"select_type_raw":None,"select_context_raw":None,"option_type_raw":None,"option_card_id":None,"option_player_index":None,"acting_hand_card_id":None,"acting_active_card_id":None}
    value.update(updates); return value


def _adapter_document(case: dict[str,Any], proof: dict[str,Any] | None, macro_catalog: list[dict[str,Any]]) -> dict[str,Any]:
    macro_id,phase=case["macro_id"],case["macro_phase"]
    if proof is None:
        rule={"rule_id":"base.no-macro","operator":"goal_proposal","reason_code":"public_goal_proposal","goal_stage":"maintain","priority":0,"predicate":_predicate(select_type_raw=2147483647)}
    else:
        if macro_id=="marnie.engine.poffin_primary": predicate=_predicate(select_type_raw=0,select_context_raw=0,option_type_raw=7,acting_hand_card_id=1086)
        elif macro_id=="marnie.engine.spikemuth_tutor" and phase=="play_stadium": predicate=_predicate(select_type_raw=0,select_context_raw=0,option_type_raw=7,acting_hand_card_id=1259)
        elif macro_id=="marnie.engine.spikemuth_tutor": predicate=_predicate(select_type_raw=1,select_context_raw=7,option_type_raw=3)
        elif macro_id=="marnie.engine.evolve_grimmsnarl": predicate=_predicate(select_type_raw=0,select_context_raw=0,option_type_raw=7,acting_hand_card_id=648)
        elif macro_id=="marnie.energy.punk_up" and phase=="choose_energy_sources": predicate=_predicate(select_type_raw=1,select_context_raw=22,option_type_raw=3,acting_active_card_id=648)
        elif macro_id=="marnie.energy.punk_up": predicate=_predicate(select_type_raw=1,select_context_raw=21,option_type_raw=3,acting_active_card_id=648)
        elif macro_id=="marnie.prize.shadow_bullet" and phase=="choose_attack": predicate=_predicate(select_type_raw=0,select_context_raw=0,option_type_raw=13,acting_active_card_id=648)
        elif macro_id=="marnie.prize.shadow_bullet": predicate=_predicate(select_type_raw=1,select_context_raw=15,option_type_raw=3,option_player_index=1,acting_active_card_id=648)
        elif macro_id=="marnie.recover.night_stretcher": predicate=_predicate(select_type_raw=0,select_context_raw=0,option_type_raw=7,acting_hand_card_id=1097)
        else: raise MarniePublicBaseError("macro_proof_invalid")
        stage=next(item["goal_stage"] for item in macro_catalog if item["macro_id"]==macro_id)
        rule={"rule_id":f"{macro_id}.{phase}","operator":"macro_proposal","reason_code":"public_macro_proposal","goal_stage":stage,"priority":0,"predicate":predicate}
    return {"schema_version":1,"adapter_id":f"marnie.{case['case_id']}","adapter_version":1,"rules":[rule]}


def _non_applicable(case: dict[str,Any], ordinal: int, reason: str, previous: str | None) -> dict[str,Any]:
    payload={"ordinal":ordinal,"case_id":case["case_id"],"source_frame_id":case["source_frame_id"],"evidence_class":case["evidence_class"],"offline_seeded_extension":case["offline_seeded_extension"],"status":"not_applicable","reason_code":reason,"macro_id":case["macro_id"],"macro_phase":case["macro_phase"],"public_observation_hash":None,"window_id":None,"context_hash":None,"intent_indexes":[],"adapter_indexes":[],"selected_indexes":[],"macro_proof_hash":None,"adapter_hash":None,"proposal_hash":None,"ir_hash":None,"execution_hash":None,"decision_audit_id":None,"trace_hash":None,"orchestration_hash":None,"previous_result_hash":previous,"public_only":True,"authoritative":False,"execution_authority":False}
    return {**payload,"result_hash":_domain_hash(RESULT_PREFIX,payload)}


class MarniePublicBaseResult:
    __slots__=("__weakref__","_owner_ref","_snapshot","_snapshot_hash","_factory_token")
    def __new__(cls,*_:Any,**__:Any) -> "MarniePublicBaseResult":
        raise TypeError("MarniePublicBaseResult is owner-produced")
    @classmethod
    def _from_owner(cls, owner: "MarniePublicBase", snapshot: dict[str,Any]) -> "MarniePublicBaseResult":
        result=object.__new__(cls)
        object.__setattr__(result,"_owner_ref",weakref.ref(owner)); object.__setattr__(result,"_snapshot",_freeze(snapshot))
        object.__setattr__(result,"_snapshot_hash",_canonical_hash(snapshot)); object.__setattr__(result,"_factory_token",FACTORY_TOKEN)
        return result
    def validate_integrity(self, owner: object) -> bool:
        try:
            snapshot=_copy(self._snapshot)
            return type(owner) is MarniePublicBase and self._owner_ref() is owner and self._factory_token is FACTORY_TOKEN and owner._integrity_valid() and not _contains_forbidden(snapshot) and _canonical_hash(snapshot)==self._snapshot_hash and owner._result_valid(snapshot)
        except (AttributeError,TypeError,ValueError): return False
    def to_public_dict(self) -> dict[str,Any]:
        owner=self._owner_ref()
        if owner is None or not self.validate_integrity(owner):
            return {"accepted":False,"case_count":0,"chain_head":None,"cases":[],"public_only":True,"authoritative":False,"execution_authority":False}
        return _copy(self._snapshot)


class MarniePublicBase:
    __slots__=("__weakref__","_documents","_cases","_expected","_document_integrity","_construction_seal")
    def __new__(cls,*_:Any,**__:Any) -> "MarniePublicBase": raise TypeError("use load_default() or load_trusted_bundle()")
    @classmethod
    def load_default(cls) -> "MarniePublicBase": return cls.load_trusted_bundle(ROOT)
    @classmethod
    def load_trusted_bundle(cls, repository_root: Path) -> "MarniePublicBase":
        if not isinstance(repository_root,Path): raise MarniePublicBaseError("contract_integrity_invalid")
        root=repository_root.resolve(); bundle=_read_json_once(_contained(root,"contracts/ptcgdap/marnie_public_base_bundle.json"))
        if type(bundle) is not dict or _canonical_hash(bundle)!=EXPECTED_BUNDLE_CANONICAL_SHA256 or bundle.get("contract_id")!=CONTRACT_ID: raise MarniePublicBaseError("contract_integrity_invalid")
        entries=bundle.get("artifacts")
        if type(entries) is not list or len(entries)!=4: raise MarniePublicBaseError("contract_integrity_invalid")
        documents: dict[str,Any]={}; seen:set[str]=set()
        for entry in entries:
            if type(entry) is not dict or set(entry)!={"id","path","canonical_sha256"}: raise MarniePublicBaseError("contract_integrity_invalid")
            artifact_id=entry["id"]
            if artifact_id in seen or artifact_id not in EXPECTED_ARTIFACTS: raise MarniePublicBaseError("contract_integrity_invalid")
            path,digest=EXPECTED_ARTIFACTS[artifact_id]
            if entry!={"id":artifact_id,"path":path,"canonical_sha256":digest}: raise MarniePublicBaseError("contract_integrity_invalid")
            value=_read_json_once(_contained(root,path))
            if _canonical_hash(value)!=digest: raise MarniePublicBaseError("contract_integrity_invalid")
            documents[artifact_id]=value; seen.add(artifact_id)
        if seen!=set(EXPECTED_ARTIFACTS): raise MarniePublicBaseError("contract_integrity_invalid")
        profile=documents["profile"]
        if type(profile) is not dict or profile.get("profile_id")!=PROFILE_ID or profile.get("parent_bundle_hashes")!={key:value[1] for key,value in PARENT_BUNDLES.items()}: raise MarniePublicBaseError("contract_integrity_invalid")
        for key,(path,digest) in PARENT_BUNDLES.items():
            if _canonical_hash(_read_json_once(_contained(root,path)))!=digest: raise MarniePublicBaseError("parent_contract_invalid")
        document_integrity=_canonical_hash(documents)
        if document_integrity!=EXPECTED_DOCUMENT_INTEGRITY_SHA256: raise MarniePublicBaseError("contract_integrity_invalid")
        actual=cls._execute(profile)
        if actual!=documents["audit"]["cases"]: raise MarniePublicBaseError("runtime_conformance_mismatch")
        expected={"accepted":True,"case_count":len(actual),"chain_head":actual[-1]["result_hash"],"cases":actual,"public_only":True,"authoritative":False,"execution_authority":False}
        owner=object.__new__(cls); object.__setattr__(owner,"_documents",_freeze(documents)); object.__setattr__(owner,"_cases",_freeze(actual)); object.__setattr__(owner,"_expected",_freeze(expected)); object.__setattr__(owner,"_document_integrity",document_integrity); object.__setattr__(owner,"_construction_seal",FACTORY_TOKEN)
        return owner

    @staticmethod
    def _execute(profile: dict[str,Any]) -> list[dict[str,Any]]:
        parent=MarnieVerticalSlice.load_default(); firewall=PublicObservationFirewall.load_default()
        ir_outcome=RestrictedBaseGraphIRCompiler.compile(copy.deepcopy(profile["restricted_ir_document"]))
        if not ir_outcome.accepted or ir_outcome.ir is None: raise MarniePublicBaseError("runtime_conformance_mismatch")
        ir=ir_outcome.ir; results=[]; previous=None
        for ordinal,case in enumerate(profile["case_catalog"]):
            frame=parent.frame(case["source_frame_id"])
            if frame["public_tree"] is None:
                result=_non_applicable(case,ordinal,"terminal_no_callback" if frame.get("terminal") else "initial_no_window",previous)
            else:
                public=_apply_patches(_decode_node(frame["public_tree"]),case["patches"])
                firewall_result=firewall.project(parse_raw_cabt_json_bytes(_raw_bytes(public)))
                if not firewall_result.accepted: result=_non_applicable(case,ordinal,"firewall_not_accepted",previous)
                elif type(firewall_result.public_observation) is not dict or firewall_result.public_observation.get("current") is None or firewall_result.public_observation.get("select") is None: result=_non_applicable(case,ordinal,"initial_no_window",previous)
                else:
                    accepted=firewall_result.public_observation
                    built=CabtSelectionWindow.build(accepted["select"],public_observation_hash=firewall_result.public_observation_hash,public_hash_authority="firewall_accepted",chooser_player_index=accepted["current"]["yourIndex"])
                    if not built.policy_allowed or built.window is None: raise MarniePublicBaseError("runtime_conformance_mismatch")
                    window=built.window; context_outcome=StrategicContextCompiler.build(firewall_result,window)
                    if not context_outcome.accepted or context_outcome.context is None: raise MarniePublicBaseError("runtime_conformance_mismatch")
                    context=context_outcome.context; proof=_proof(case,accepted,window)
                    adapter_outcome=PublicDeckAdapterCompiler.compile(_adapter_document(case,proof,profile["macro_catalog"]))
                    if not adapter_outcome.accepted or adapter_outcome.adapter is None: raise MarniePublicBaseError("runtime_conformance_mismatch")
                    adapter=adapter_outcome.adapter; proposal_outcome=PublicDeckAdapterProposer.propose(context,adapter,f"{case['case_id']}.proposal")
                    if not proposal_outcome.accepted or proposal_outcome.result is None: raise MarniePublicBaseError("runtime_conformance_mismatch")
                    proposal=proposal_outcome.result.to_public_dict(); adapter_indexes=[]
                    for item in proposal["adapter_proposals"]:
                        if item["operator"]=="macro_proposal": adapter_indexes.extend(index for index in item["indexes"] if index not in adapter_indexes)
                    if proof is not None and adapter_indexes!=proof["intent_indexes"]: raise MarniePublicBaseError("runtime_conformance_mismatch")
                    request={"orchestration_id":f"{case['case_id']}.orchestration","proposal_id":f"{case['case_id']}.proposal","execution_id":f"{case['case_id']}.execution","scene_id":f"{case['case_id']}.scene","decision_id":f"{case['case_id']}.decision","determinism_key":f"{case['case_id']}.determinism","trace_id":f"{case['case_id']}.trace","policy_hash":profile["policy_hash"],"mandatory_indexes":[],"terminal_indexes":[],"base_hard_tiers":[{"index":index,"tier":[0]} for index in range(window.option_count)],"base_vetoed_indexes":[]}
                    outcome=PublicBasePolicyOrchestrator.orchestrate(context,window,ir,adapter,request)
                    if not outcome.accepted or outcome.result is None: raise MarniePublicBaseError("runtime_conformance_mismatch")
                    base=outcome.result.to_public_dict(); source=base["source"]
                    payload={"ordinal":ordinal,"case_id":case["case_id"],"source_frame_id":case["source_frame_id"],"evidence_class":case["evidence_class"],"offline_seeded_extension":case["offline_seeded_extension"],"status":"orchestrated","reason_code":"base_orchestrated","macro_id":case["macro_id"],"macro_phase":case["macro_phase"],"public_observation_hash":firewall_result.public_observation_hash,"window_id":window.window_id,"context_hash":context.context_hash,"intent_indexes":[] if proof is None else proof["intent_indexes"],"adapter_indexes":adapter_indexes,"selected_indexes":base["selected_indexes"],"macro_proof_hash":None if proof is None else proof["macro_proof_hash"],"adapter_hash":source["adapter_hash"],"proposal_hash":source["proposal_hash"],"ir_hash":source["ir_hash"],"execution_hash":source["execution_hash"],"decision_audit_id":source["decision_audit_id"],"trace_hash":source["trace_hash"],"orchestration_hash":base["orchestration_hash"],"previous_result_hash":previous,"public_only":True,"authoritative":False,"execution_authority":False}
                    result={**payload,"result_hash":_domain_hash(RESULT_PREFIX,payload)}
            results.append(result); previous=result["result_hash"]
        return results

    def _integrity_valid(self) -> bool:
        try:
            cases = _copy(self._cases)
            expected = {
                "accepted": True,
                "case_count": len(cases),
                "chain_head": cases[-1]["result_hash"],
                "cases": copy.deepcopy(cases),
                "public_only": True,
                "authoritative": False,
                "execution_authority": False,
            }
            return (
                self._construction_seal is FACTORY_TOKEN
                and self._document_integrity == EXPECTED_DOCUMENT_INTEGRITY_SHA256
                and _canonical_hash(_copy(self._documents)) == EXPECTED_DOCUMENT_INTEGRITY_SHA256
                and cases == _copy(self._documents)["audit"]["cases"]
                and _copy(self._expected) == expected
                and not _contains_forbidden(expected)
            )
        except (AttributeError,IndexError,KeyError,TypeError,ValueError): return False
    def _require_integrity(self) -> None:
        if not self._integrity_valid(): raise MarniePublicBaseError("contract_integrity_invalid")
    def _result_valid(self, snapshot: dict[str,Any]) -> bool:
        return snapshot==_copy(self._expected)
    def evaluate_all(self) -> MarniePublicBaseResult:
        self._require_integrity(); return MarniePublicBaseResult._from_owner(self,_copy(self._expected))
    def evaluate_case(self, case_id: Any) -> dict[str,Any]:
        self._require_integrity()
        if type(case_id) is not str: raise MarniePublicBaseError("input_type_invalid")
        for case in _copy(self._cases):
            if case["case_id"]==case_id: return case
        raise MarniePublicBaseError("case_unknown")
    @staticmethod
    def _dto(value: Any=None,error_code: str="") -> dict[str,Any]: return {"ok":error_code=="","error_code":error_code,"value":copy.deepcopy(value) if not error_code else None}
    def run(self, operation: Any, input_value: Any) -> dict[str,Any]:
        if not self._integrity_valid(): return self._dto(error_code="contract_integrity_invalid")
        if type(operation) is not str or type(input_value) is not dict: return self._dto(error_code="input_type_invalid")
        try:
            if operation=="evaluate_all" and not input_value: return self._dto(self.evaluate_all().to_public_dict())
            if operation=="evaluate_case" and set(input_value)=={"case_id"}: return self._dto(self.evaluate_case(input_value["case_id"]))
            if operation not in {"evaluate_all","evaluate_case"}: return self._dto(error_code="operation_unknown")
            return self._dto(error_code="input_type_invalid")
        except MarniePublicBaseError as exc: return self._dto(error_code=exc.code)
    def bundle_hash(self) -> str:
        self._require_integrity(); return EXPECTED_BUNDLE_CANONICAL_SHA256
    def audit_snapshot(self) -> dict[str,Any]:
        self._require_integrity(); return {"bundle_canonical_sha256":EXPECTED_BUNDLE_CANONICAL_SHA256,"document_integrity_sha256":EXPECTED_DOCUMENT_INTEGRITY_SHA256,"case_count":len(self._cases),"macro_count":len(_copy(self._documents)["profile"]["macro_catalog"]),"execution_authority":False,"live_consumer":False}


def load_default() -> MarniePublicBase:
    return MarniePublicBase.load_default()


__all__=["EXPECTED_BUNDLE_CANONICAL_SHA256","EXPECTED_DOCUMENT_INTEGRITY_SHA256","MarniePublicBase","MarniePublicBaseError","MarniePublicBaseResult","load_default"]
