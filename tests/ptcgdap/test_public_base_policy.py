from __future__ import annotations

import copy
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.public_base_policy import PublicBasePolicyOrchestrator
from scripts.ai.ptcgdap.public_deck_adapter import PublicDeckAdapterCompiler
from scripts.ai.ptcgdap.source_lock import load_json_strict
from scripts.ai.ptcgdap.strategic_context_v18 import StrategicContextCompiler
from scripts.ai.ptcgdap.strategic_trace_v2 import RestrictedBaseGraphIRCompiler
from tests.ptcgdap.test_strategic_context_v18 import _firewall_case, _window


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
VECTORS = load_json_strict(CONTRACT_ROOT / "public_base_policy_conformance_vectors.json")
TRACE_VECTORS = load_json_strict(CONTRACT_ROOT / "strategic_trace_v2_conformance_vectors.json")
ADAPTER_VECTORS = load_json_strict(CONTRACT_ROOT / "public_deck_adapter_conformance_vectors.json")


def policy_owners():
    _, firewall = _firewall_case("regular-accepted")
    window = _window(firewall)
    context = StrategicContextCompiler.build(firewall, window).context
    ir_document = next(case["document"] for case in TRACE_VECTORS["ir_cases"] if case["id"] == VECTORS["fixture"]["ir_case_id"])
    ir = RestrictedBaseGraphIRCompiler.compile(copy.deepcopy(ir_document)).ir
    adapter_document = next(case["document"] for case in ADAPTER_VECTORS["adapter_documents"] if case["id"] == VECTORS["fixture"]["adapter_case_id"])
    adapter = PublicDeckAdapterCompiler.compile(copy.deepcopy(adapter_document)).adapter
    assert context is not None and ir is not None and adapter is not None
    return context, window, ir, adapter


class PublicBasePolicyTests(unittest.TestCase):
    def test_all_shared_orchestration_cases_issue_exact_decision_and_trace(self) -> None:
        for case in VECTORS["orchestration_cases"]:
            with self.subTest(case=case["id"]):
                context, window, ir, adapter = policy_owners()
                outcome = PublicBasePolicyOrchestrator.orchestrate(context, window, ir, adapter, copy.deepcopy(case["request"]))
                self.assertTrue(outcome.accepted, (outcome.failed_stage, outcome.error_code))
                result = outcome.result
                self.assertIsNotNone(result)
                self.assertTrue(result.validate_integrity(context, window, ir, adapter))
                self.assertEqual(case["expected_result"], result.to_public_dict())
                self.assertEqual(case["expected_decision_audit_id"], result.decision.audit_id)
                self.assertEqual(case["expected_trace_hash"], result.trace.trace_hash)
                self.assertEqual(case["expected_selected_indexes"], result.agent_output())

    def test_shared_rejections_fail_atomically_without_echo(self) -> None:
        base = VECTORS["orchestration_cases"][0]["request"]
        for case in VECTORS["orchestration_rejections"]:
            with self.subTest(case=case["id"]):
                context, window, ir, adapter = policy_owners()
                request = copy.deepcopy(base)
                fault = case["fault"]
                if fault == "fake_context": context = object()
                elif fault == "fake_window": window = object()
                elif fault == "fake_ir": ir = object()
                elif fault == "fake_adapter": adapter = object()
                elif fault == "private_identity": request["orchestration_id"] = "PRIVATE_SENTINEL"
                elif fault == "lowercase_policy_hash": request["policy_hash"] = request["policy_hash"].lower()
                elif fault == "mandatory_bool": request["mandatory_indexes"] = [True]
                elif fault == "forced_veto": request["mandatory_indexes"] = [0]; request["base_vetoed_indexes"] = [0]
                elif fault == "cross_window": window = _window(_firewall_case("regular-accepted")[1], select={**window.select_payload, "option": list(reversed(window.select_payload["option"]))})
                elif fault == "mutated_adapter": object.__setattr__(adapter, "_snapshot", {"PRIVATE": True})
                else: raise AssertionError(fault)
                outcome = PublicBasePolicyOrchestrator.orchestrate(context, window, ir, adapter, request)
                self.assertFalse(outcome.accepted)
                self.assertEqual(case["expected_failed_stage"], outcome.failed_stage)
                self.assertEqual(case["expected_error_code"], outcome.error_code)
                self.assertIsNone(outcome.result)
                self.assertNotIn("PRIVATE_SENTINEL", outcome.error_code)


if __name__ == "__main__":
    unittest.main()
