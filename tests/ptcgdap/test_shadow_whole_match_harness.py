from __future__ import annotations
import copy,json
from pathlib import Path
import unittest
from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.shadow_engine_command_applier import ShadowEngineCommandApplier
from scripts.ai.ptcgdap.shadow_match_owner_gate import ShadowMatchOwnerGate
from scripts.ai.ptcgdap.shadow_prompt_broker import ShadowPromptBroker
from scripts.ai.ptcgdap.shadow_whole_match_harness import EXPECTED_BUNDLE_CANONICAL_SHA256,ShadowWholeMatchHarness
from tests.ptcgdap.test_shadow_engine_command_applier import ReversibleCommand,aligned_gate,committed_fixture
from tests.ptcgdap.test_shadow_prompt_broker import next_context,open_prompt

ROOT=Path(__file__).resolve().parents[2]
VECTORS=json.loads((ROOT/"contracts/ptcgdap/shadow_whole_match_harness_conformance_vectors.json").read_text(encoding="utf-8"))
SCHEMA=json.loads((ROOT/"contracts/ptcgdap/shadow_whole_match_harness.schema.json").read_text(encoding="utf-8"))
EXPECTED="0C5A8FDAB61A73F623EA6B0D364C38E6C4797087287B3DF3C88D0191261296B5"

def second_committed(ctx,broker):
    fresh=next_context(ctx)
    opened=open_prompt(broker,fresh,"W6")
    if not opened.accepted:raise AssertionError(opened.to_public_dict())
    prepared=broker.prepare_selection(opened.prompt,fresh["resolution"])
    if not prepared.accepted:raise AssertionError(prepared.to_public_dict())
    committed=broker.commit_prompt(opened.prompt)
    if not committed.accepted:raise AssertionError(committed.to_public_dict())
    return fresh,committed

def fault_fixture(kind:str):
    first=ReversibleCommand("first",raise_capture=kind=="capture",raise_restore=kind=="restore")
    second=ReversibleCommand("second",raise_apply=kind in {"apply","restore"})
    return committed_fixture(first=first,second=second)

class ShadowWholeMatchHarnessTests(unittest.TestCase):
    def setUp(self)->None:self.validator=Draft202012Validator(SCHEMA)

    def test_two_prompt_success_is_strictly_ordered_private_free(self)->None:
        self.assertEqual(EXPECTED_BUNDLE_CANONICAL_SHA256,EXPECTED)
        ctx,broker,first,_=committed_fixture();gate=aligned_gate(ctx,broker);owner=ShadowWholeMatchHarness(gate,broker)
        self.assertTrue(owner.start().accepted);self.assertTrue(owner.apply_prompt(first).accepted)
        _,second=second_committed(ctx,broker);self.assertTrue(owner.apply_prompt(second).accepted)
        final=owner.finish_match();self.assertTrue(final.accepted);self.assertTrue(final.validate_integrity(owner))
        report=final.to_public_dict()["report"];self.validator.validate(final.to_public_dict())
        self.assertEqual(report["state"],"completed");self.assertEqual(report["prompt_count"],2)
        self.assertEqual(report["broker_generations"],[1,2]);self.assertEqual(report["decision_generations"],sorted(report["decision_generations"]))
        self.assertEqual(len(set(report["snapshot_ids"])),2);self.assertEqual(len(set(report["window_ids"])),2);self.assertEqual(len(set(report["execution_ids"])),2)
        serialized=json.dumps(report,sort_keys=True);self.assertNotIn("PRIVATE_",serialized);self.assertFalse(report["authoritative"])

    def test_recoverable_and_dirty_faults_request_next_match_legacy(self)->None:
        for kind,fault,dirty in (("capture","capture_failed",False),("apply","command_apply_failed",False),("restore","rollback_failed",True)):
            with self.subTest(kind=kind):
                ctx,broker,committed,_=fault_fixture(kind);gate=aligned_gate(ctx,broker);owner=ShadowWholeMatchHarness(gate,broker)
                self.assertTrue(owner.start().accepted);failed=owner.apply_prompt(committed);self.assertFalse(failed.accepted)
                self.assertEqual(failed.error_code,"dirty_game_detected" if dirty else "prompt_apply_failed")
                self.assertEqual(failed.to_public_dict()["report"]["fault_code"],fault);self.assertEqual(failed.to_public_dict()["report"]["dirty"],dirty)
                self.assertTrue(owner.finish_match().accepted);verified=owner.verify_next_match_rollback(ctx["snapshot"].match_generation+1)
                self.assertTrue(verified.accepted);self.assertEqual(verified.to_public_dict()["report"]["next_match_mode"],"legacy")

    def test_replay_chain_is_rejected_before_a_second_apply(self)->None:
        ctx,broker,committed,selected=committed_fixture();gate=aligned_gate(ctx,broker);owner=ShadowWholeMatchHarness(gate,broker)
        self.assertTrue(owner.start().accepted);self.assertTrue(owner.apply_prompt(committed).accepted)
        replay=owner.apply_prompt(committed);self.assertEqual(replay.error_code,"stale_prompt_chain")
        self.assertEqual([command.value for command in selected],[1,1]);self.assertEqual(replay.to_public_dict()["report"]["prompt_count"],1)

    def test_invalid_result_closes_match_and_never_echoes_input(self)->None:
        ctx,broker,_,_=committed_fixture();owner=ShadowWholeMatchHarness(aligned_gate(ctx,broker),broker);self.assertTrue(owner.start().accepted)
        result=owner.apply_prompt({"private_engine_command":"PRIVATE_COMMAND_SENTINEL"})
        self.assertEqual(result.error_code,"invalid_broker_result");self.assertNotIn("PRIVATE",json.dumps(result.to_public_dict()))

    def test_legacy_and_wrong_broker_never_start(self)->None:
        ctx,broker,_,_=committed_fixture();legacy=ShadowMatchOwnerGate();self.assertTrue(legacy.begin_match(ctx["snapshot"].match_generation,"legacy").accepted)
        self.assertEqual(ShadowWholeMatchHarness(legacy,broker).start().error_code,"owner_mode_not_aligned")
        other=ShadowPromptBroker(ctx["snapshot"].match_generation,ctx["session_id"])
        self.assertEqual(ShadowWholeMatchHarness(aligned_gate(ctx,broker),other).start().error_code,"broker_not_current")

    def test_result_and_owner_mutation_fail_closed(self)->None:
        ctx,broker,committed,_=committed_fixture();owner=ShadowWholeMatchHarness(aligned_gate(ctx,broker),broker);result=owner.start()
        copied=copy.deepcopy(result.to_public_dict());copied["report"]["execution_ids"]=["F"*64];self.assertFalse(hasattr(copied,"validate_integrity"))
        object.__setattr__(result,"error_code","PRIVATE_SENTINEL");self.assertFalse(result.validate_integrity(owner));self.assertNotIn("PRIVATE",json.dumps(result.to_public_dict()))
        object.__setattr__(owner,"_fault_code","PRIVATE_SENTINEL");self.assertFalse(owner.validate_integrity());self.assertEqual(owner.audit_snapshot()["state"],"ready")

    def test_every_shared_vector_has_an_executable_scenario(self)->None:
        self.assertEqual(len(VECTORS["cases"]),9)
        self.assertEqual({case["scenario"] for case in VECTORS["cases"]},{"two_prompt_success","capture_fault","apply_fault","restore_fault","replay_chain","invalid_result","legacy_start","wrong_broker","finish_clean"})

if __name__=="__main__":unittest.main()
