from __future__ import annotations
import unittest
from scripts.ai.ptcgdap.shadow_whole_match_harness import ShadowWholeMatchHarness
from tests.ptcgdap.test_shadow_engine_command_applier import ReversibleCommand,aligned_gate,committed_fixture
from tests.ptcgdap.test_shadow_whole_match_harness import second_committed

class ShadowWholeMatchHarnessPropertyTests(unittest.TestCase):
    def test_prompt_chain_counts_and_ids_are_unique_for_reobserved_prefixes(self)->None:
        for length in (1,2):
            with self.subTest(length=length):
                ctx,broker,committed,_=committed_fixture();owner=ShadowWholeMatchHarness(aligned_gate(ctx,broker),broker);self.assertTrue(owner.start().accepted)
                self.assertTrue(owner.apply_prompt(committed).accepted)
                if length==2:
                    _,committed=second_committed(ctx,broker);self.assertTrue(owner.apply_prompt(committed).accepted)
                report=owner.audit_snapshot();self.assertEqual(report["prompt_count"],length)
                for key in ("broker_generations","decision_generations","snapshot_ids","window_ids","execution_ids"):
                    self.assertEqual(len(report[key]),len(set(report[key])))

    def test_every_apply_failure_position_is_terminal_and_next_match_legacy(self)->None:
        for failing in (0,1):
            first=ReversibleCommand("first",apply_ok=failing!=0);second=ReversibleCommand("second",apply_ok=failing!=1)
            ctx,broker,committed,_=committed_fixture(first=first,second=second);owner=ShadowWholeMatchHarness(aligned_gate(ctx,broker),broker);self.assertTrue(owner.start().accepted)
            self.assertFalse(owner.apply_prompt(committed).accepted);self.assertEqual(owner.audit_snapshot()["state"],"faulted")
            self.assertEqual(owner.apply_prompt(committed).error_code,"match_terminal");self.assertTrue(owner.finish_match().accepted)
            self.assertTrue(owner.verify_next_match_rollback(ctx["snapshot"].match_generation+1).accepted)

    def test_next_match_generation_must_strictly_increase_and_consumes_once(self)->None:
        first=ReversibleCommand("first",raise_capture=True);ctx,broker,committed,_=committed_fixture(first=first)
        owner=ShadowWholeMatchHarness(aligned_gate(ctx,broker),broker);self.assertTrue(owner.start().accepted);self.assertFalse(owner.apply_prompt(committed).accepted);self.assertTrue(owner.finish_match().accepted)
        current=ctx["snapshot"].match_generation
        self.assertEqual(owner.verify_next_match_rollback(current).error_code,"invalid_match_generation")
        self.assertTrue(owner.verify_next_match_rollback(current+1).accepted)
        self.assertEqual(owner.verify_next_match_rollback(current+2).error_code,"rollback_not_required")

if __name__=="__main__":unittest.main()
