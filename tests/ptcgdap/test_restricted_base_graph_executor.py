from __future__ import annotations

import copy
from pathlib import Path
import shutil
import tempfile
import unittest

from scripts.ai.ptcgdap.restricted_base_graph_executor import (
    RestrictedBaseGraphExecutionError,
    RestrictedBaseGraphExecutionResult,
    RestrictedBaseGraphExecutor,
)
from scripts.ai.ptcgdap.source_lock import load_json_strict
from scripts.ai.ptcgdap.strategic_trace_v2 import RestrictedBaseGraphIRCompiler
from tests.ptcgdap.test_strategic_trace_v2 import _context_decision


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
VECTORS = CONTRACT_ROOT / "restricted_base_graph_executor_conformance_vectors.json"
PARENT_VECTORS = CONTRACT_ROOT / "strategic_trace_v2_conformance_vectors.json"


class RestrictedBaseGraphExecutorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.vectors = load_json_strict(VECTORS)
        parent = load_json_strict(PARENT_VECTORS)
        cls.ir_documents = {case["id"]: case["document"] for case in parent["ir_cases"]}

    def _ir(self, case_id: str):
        outcome = RestrictedBaseGraphIRCompiler.compile(copy.deepcopy(self.ir_documents[case_id]))
        self.assertTrue(outcome.accepted, outcome.error_code)
        self.assertIsNotNone(outcome.ir)
        return outcome.ir

    def test_all_shared_success_cases_match_exact_payload_and_hash(self) -> None:
        for case in self.vectors["execution_cases"]:
            with self.subTest(case=case["id"]):
                context, _decision = _context_decision()
                ir = self._ir(case["ir_case_id"])
                outcome = RestrictedBaseGraphExecutor.execute(context, ir, copy.deepcopy(case["input"]))
                self.assertTrue(outcome.accepted, outcome.error_code)
                self.assertEqual("", outcome.error_code)
                self.assertIsNotNone(outcome.result)
                self.assertTrue(outcome.result.validate_integrity(context, ir))
                self.assertEqual(case["expected_result"], outcome.result.to_public_dict())

    def test_all_shared_rejections_fail_closed(self) -> None:
        base = copy.deepcopy(self.vectors["execution_cases"][0]["input"])
        for case in self.vectors["execution_rejections"]:
            with self.subTest(case=case["id"]):
                context, _decision = _context_decision()
                ir = self._ir("minimal-base")
                value = copy.deepcopy(base)
                if "mutation" in case:
                    mutation = case["mutation"]
                    value[mutation["field"]] = copy.deepcopy(mutation["value"])
                    if "also" in mutation:
                        value[mutation["also"]["field"]] = copy.deepcopy(mutation["also"]["value"])
                source_context = object() if case.get("fault") == "fake_context" else context
                source_ir = object() if case.get("fault") == "fake_ir" else ir
                outcome = RestrictedBaseGraphExecutor.execute(source_context, source_ir, value)
                self.assertFalse(outcome.accepted)
                self.assertEqual(case["expected_error_code"], outcome.error_code)
                self.assertIsNone(outcome.result)

    def test_result_is_factory_owned_exact_bound_copy_only_and_mutation_detecting(self) -> None:
        context, _decision = _context_decision()
        ir = self._ir("minimal-base")
        execution_input = copy.deepcopy(self.vectors["execution_cases"][0]["input"])
        outcome = RestrictedBaseGraphExecutor.execute(context, ir, execution_input)
        self.assertTrue(outcome.accepted)
        result = outcome.result
        self.assertIsNotNone(result)
        with self.assertRaises(TypeError):
            RestrictedBaseGraphExecutionResult()
        public = result.to_public_dict()
        public["selected_indexes"].append(999)
        self.assertEqual([0], result.selected_indexes)
        second_context, _decision = _context_decision()
        self.assertFalse(result.validate_integrity(second_context, ir))
        object.__setattr__(result, "_snapshot", {**result.to_public_dict(), "selected_indexes": [999]})
        self.assertFalse(result.validate_integrity(context, ir))
        self.assertEqual([], result.selected_indexes)
        with self.assertRaises(RestrictedBaseGraphExecutionError):
            result.to_public_dict()

    def test_private_sentinels_never_echo(self) -> None:
        context, _decision = _context_decision()
        ir = self._ir("public-adapter-proposals")
        value = copy.deepcopy(self.vectors["execution_cases"][-1]["input"])
        for sentinel in self.vectors["private_sentinels"]:
            value["adapter_proposals"][0]["reason_code"] = sentinel
            outcome = RestrictedBaseGraphExecutor.execute(context, ir, value)
            self.assertFalse(outcome.accepted)
            self.assertEqual("invalid_execution_input", outcome.error_code)
            self.assertNotIn(sentinel, outcome.error_code)

    def test_canonical_whitespace_is_allowed_but_semantic_resign_is_rejected(self) -> None:
        context, _decision = _context_decision()
        ir = self._ir("minimal-base")
        value = copy.deepcopy(self.vectors["execution_cases"][0]["input"])
        with tempfile.TemporaryDirectory(prefix="ptcgdap-p4-wp3-contract-") as temp:
            root = Path(temp)
            for name in (
                "restricted_base_graph_executor.schema.json",
                "restricted_base_graph_executor_profile.json",
                "restricted_base_graph_executor_conformance_vectors.json",
                "restricted_base_graph_executor_bundle.json",
            ):
                shutil.copyfile(CONTRACT_ROOT / name, root / name)
            bundle = root / "restricted_base_graph_executor_bundle.json"
            bundle.write_bytes(b" \n" + bundle.read_bytes() + b" \n")
            self.assertTrue(RestrictedBaseGraphExecutor.execute(context, ir, value, contract_root=root).accepted)
            profile_path = root / "restricted_base_graph_executor_profile.json"
            profile = load_json_strict(profile_path)
            profile["execution_contract"]["adapter_authority"] = "adapter_can_filter"
            profile_path.write_text(__import__("json").dumps(profile), encoding="utf-8")
            self.assertEqual("contract_error", RestrictedBaseGraphExecutor.execute(context, ir, value, contract_root=root).error_code)


if __name__ == "__main__":
    unittest.main()
