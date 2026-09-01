from __future__ import annotations
import argparse,hashlib,json,sys
from pathlib import Path
from typing import Any
ROOT=Path(__file__).resolve().parents[2]; sys.path.insert(0,str(ROOT))
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes
CONTRACT_ROOT=ROOT/"contracts/ptcgdap"; CONTRACT_ID="ptcgdap-shadow-whole-match-harness-p3-wp8-v1"
PARENT_APPLIER="7539A9D5120666AEBA1325DD6623F437831A024996BD612F3EC677F78C9F8F4C"
PARENT_GATE="9B8202E67756E388AFB0A13EA1FD20227ADF0718DF8454420A2B1FC7A5D31B8C"
PARENT_BROKER="D19EC7B9B77370312C82E0572DFB016B75E3FE9F438B6C1EFFD50E0AB43C551E"
STATES=["ready","active","completed","faulted","dirty","rollback_verified"]
ERRORS=["invalid_harness","invalid_gate","owner_mode_not_aligned","invalid_broker","broker_not_current","already_started","not_started","match_terminal","invalid_broker_result","stale_prompt_chain","prompt_limit_exceeded","prompt_apply_failed","dirty_game_detected","rollback_request_failed","match_end_failed","rollback_not_required","invalid_match_generation","next_match_rollback_failed"]
FAULTS=["","capture_failed","command_apply_failed","rollback_failed","invalid_broker_result","stale_prompt_chain","prompt_limit_exceeded"]
def ch(v:Any)->str:return hashlib.sha256(canonical_json_v1_bytes(v)).hexdigest().upper()
def schema()->dict[str,Any]:
    report={"type":"object","additionalProperties":False,"required":["profile","state","match_generation","prompt_count","broker_generations","decision_generations","snapshot_ids","window_ids","execution_ids","fault_code","dirty","rollback_requested","match_ended","next_match_mode","authority","authoritative"],"properties":{
      "profile":{"const":CONTRACT_ID},"state":{"enum":STATES},"match_generation":{"oneOf":[{"$ref":"#/$defs/positiveSafeInteger"},{"type":"null"}]},"prompt_count":{"type":"integer","minimum":0,"maximum":64},
      "broker_generations":{"type":"array","items":{"$ref":"#/$defs/positiveSafeInteger"},"uniqueItems":True,"maxItems":64},"decision_generations":{"type":"array","items":{"$ref":"#/$defs/positiveSafeInteger"},"uniqueItems":True,"maxItems":64},
      "snapshot_ids":{"type":"array","items":{"$ref":"#/$defs/sha256"},"uniqueItems":True,"maxItems":64},"window_ids":{"type":"array","items":{"$ref":"#/$defs/sha256"},"uniqueItems":True,"maxItems":64},"execution_ids":{"type":"array","items":{"$ref":"#/$defs/sha256"},"uniqueItems":True,"maxItems":64},
      "fault_code":{"enum":FAULTS},"dirty":{"type":"boolean"},"rollback_requested":{"type":"boolean"},"match_ended":{"type":"boolean"},"next_match_mode":{"oneOf":[{"const":"legacy"},{"type":"null"}]},"authority":{"const":"shadow_whole_match_report_audit"},"authoritative":{"const":False}},
      "allOf":[{"properties":{"broker_generations":{"minItems":{"$data":"1/prompt_count"}}}}]}
    report.pop("allOf")
    result={"type":"object","additionalProperties":False,"required":["accepted","error_code","report"],"properties":{"accepted":{"type":"boolean"},"error_code":{"enum":["",*ERRORS]},"report":{"$ref":"#/$defs/wholeMatchReport"}},"allOf":[{"if":{"properties":{"accepted":{"const":True}}},"then":{"properties":{"error_code":{"const":""}}}},{"if":{"properties":{"accepted":{"const":False}}},"then":{"properties":{"error_code":{"enum":ERRORS}}}}]}
    return {"$schema":"https://json-schema.org/draft/2020-12/schema","$id":"https://ptcgdap.local/contracts/shadow_whole_match_harness.schema.json","title":"PtcgDAP shadow whole-match harness audit DTOs","oneOf":[{"$ref":"#/$defs/wholeMatchReport"},{"$ref":"#/$defs/harnessResult"}],"$defs":{"sha256":{"type":"string","pattern":"^[A-F0-9]{64}$"},"positiveSafeInteger":{"type":"integer","minimum":1,"maximum":9007199254740991},"wholeMatchReport":report,"harnessResult":result}}
def profile()->dict[str,Any]:
    return {"schema_version":1,"profile_id":CONTRACT_ID,"parent_applier_bundle_canonical_sha256":PARENT_APPLIER,"parent_owner_gate_bundle_canonical_sha256":PARENT_GATE,"parent_prompt_broker_bundle_canonical_sha256":PARENT_BROKER,"states":STATES,"error_codes":ERRORS,"fault_codes":FAULTS,"limits":{"max_prompt_count":64},"semantics":{"exact_aligned_gate_and_broker_required":True,"fresh_applier_per_prompt":True,"strict_broker_generation_order":True,"unique_snapshot_window_execution_ids":True,"any_prompt_fault_requests_next_match_legacy":True,"recoverable_restore_is_clean":True,"restore_failure_is_dirty_and_terminal":True,"next_match_generation_strictly_increases":True,"rollback_changes_current_match":False,"live_consumer":False,"serialized_report_is_authority":False,"schema_alone_authorizes_report":False},"private_fields_forbidden_from_report":["private_engine_command","private_object_refs","captured_state","session_id","callback_binding_hash","current_source","broker","gate","applier","prompt","binding","ticket","preflight"]}
def vectors()->dict[str,Any]:
    cases=[
      {"case_id":"two-prompt-success","scenario":"two_prompt_success","expected_accepted":True,"expected_error":"","expected_state":"completed","expected_prompt_count":2,"expected_fault":"","expected_dirty":False,"expected_rollback":False,"expected_next_mode":None},
      {"case_id":"capture-fault-rolls-next-match","scenario":"capture_fault","expected_accepted":True,"expected_error":"","expected_state":"rollback_verified","expected_prompt_count":0,"expected_fault":"capture_failed","expected_dirty":False,"expected_rollback":True,"expected_next_mode":"legacy"},
      {"case_id":"apply-fault-restored-rolls-next-match","scenario":"apply_fault","expected_accepted":True,"expected_error":"","expected_state":"rollback_verified","expected_prompt_count":0,"expected_fault":"command_apply_failed","expected_dirty":False,"expected_rollback":True,"expected_next_mode":"legacy"},
      {"case_id":"restore-fault-dirty-rolls-next-match","scenario":"restore_fault","expected_accepted":True,"expected_error":"","expected_state":"rollback_verified","expected_prompt_count":0,"expected_fault":"rollback_failed","expected_dirty":True,"expected_rollback":True,"expected_next_mode":"legacy"},
      {"case_id":"replay-chain-rejected","scenario":"replay_chain","expected_accepted":True,"expected_error":"","expected_state":"rollback_verified","expected_prompt_count":1,"expected_fault":"stale_prompt_chain","expected_dirty":False,"expected_rollback":True,"expected_next_mode":"legacy"},
      {"case_id":"invalid-result-rejected","scenario":"invalid_result","expected_accepted":True,"expected_error":"","expected_state":"rollback_verified","expected_prompt_count":0,"expected_fault":"invalid_broker_result","expected_dirty":False,"expected_rollback":True,"expected_next_mode":"legacy"},
      {"case_id":"legacy-start-rejected","scenario":"legacy_start","expected_accepted":False,"expected_error":"owner_mode_not_aligned","expected_state":"ready","expected_prompt_count":0,"expected_fault":"","expected_dirty":False,"expected_rollback":False,"expected_next_mode":None},
      {"case_id":"wrong-broker-start-rejected","scenario":"wrong_broker","expected_accepted":False,"expected_error":"broker_not_current","expected_state":"ready","expected_prompt_count":0,"expected_fault":"","expected_dirty":False,"expected_rollback":False,"expected_next_mode":None},
      {"case_id":"finish-clean-match","scenario":"finish_clean","expected_accepted":True,"expected_error":"","expected_state":"completed","expected_prompt_count":1,"expected_fault":"","expected_dirty":False,"expected_rollback":False,"expected_next_mode":None}
    ]
    return {"schema_version":1,"profile_id":CONTRACT_ID,"cases":cases,"private_sentinels":["PRIVATE_COMMAND_SENTINEL","PRIVATE_STATE_SENTINEL","PRIVATE_SESSION_SENTINEL"]}
def documents()->dict[Path,dict[str,Any]]:
    docs={CONTRACT_ROOT/"shadow_whole_match_harness.schema.json":schema(),CONTRACT_ROOT/"shadow_whole_match_harness_profile.json":profile(),CONTRACT_ROOT/"shadow_whole_match_harness_conformance_vectors.json":vectors()}
    bundle={"schema_version":1,"contract_id":CONTRACT_ID,"parent_applier_bundle_canonical_sha256":PARENT_APPLIER,"parent_owner_gate_bundle_canonical_sha256":PARENT_GATE,"parent_prompt_broker_bundle_canonical_sha256":PARENT_BROKER,"artifacts":[{"id":i,"path":p.relative_to(ROOT).as_posix(),"canonical_sha256":ch(docs[p])} for i,p in (("schema",CONTRACT_ROOT/"shadow_whole_match_harness.schema.json"),("profile",CONTRACT_ROOT/"shadow_whole_match_harness_profile.json"),("vectors",CONTRACT_ROOT/"shadow_whole_match_harness_conformance_vectors.json"))]};docs[CONTRACT_ROOT/"shadow_whole_match_harness_bundle.json"]=bundle;return docs
def rendered(v:dict[str,Any])->bytes:return (json.dumps(v,ensure_ascii=False,indent=2)+"\n").encode()
def main()->int:
    ap=argparse.ArgumentParser();ap.add_argument("--check",action="store_true");args=ap.parse_args();failed=False
    for p,v in documents().items():
        b=rendered(v)
        if args.check:
            if not p.exists() or p.read_bytes()!=b:print(f"drift: {p.relative_to(ROOT)}");failed=True
        else:p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
    return 1 if failed else 0
if __name__=="__main__":raise SystemExit(main())
