from __future__ import annotations

import copy
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.public_deck_adapter import PublicDeckAdapterCompiler, PublicDeckAdapterProposer
from scripts.ai.ptcgdap.source_lock import load_json_strict
from tests.ptcgdap.test_strategic_trace_v2 import _context_decision


ROOT = Path(__file__).resolve().parents[2]
VECTORS = ROOT / "contracts/ptcgdap/public_deck_adapter_conformance_vectors.json"


class PublicDeckAdapterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.vectors = load_json_strict(VECTORS)

    def test_shared_adapter_and_proposal_vectors(self) -> None:
        adapters = {}
        for case in self.vectors["adapter_documents"]:
            outcome = PublicDeckAdapterCompiler.compile(copy.deepcopy(case["document"]))
            self.assertTrue(outcome.accepted, outcome.error_code)
            self.assertEqual(case["expected_adapter"], outcome.adapter.to_public_dict())
            adapters[case["id"]] = outcome.adapter
        for case in self.vectors["proposal_cases"]:
            context, _decision = _context_decision()
            outcome = PublicDeckAdapterProposer.propose(context, adapters[case["adapter_case_id"]], case["proposal_id"])
            self.assertTrue(outcome.accepted, outcome.error_code)
            self.assertTrue(outcome.result.validate_integrity(context, adapters[case["adapter_case_id"]]))
            self.assertEqual(case["expected_result"], outcome.result.to_public_dict())

    def test_shared_rejections_fail_closed(self) -> None:
        document = copy.deepcopy(self.vectors["adapter_documents"][0]["document"])
        for case in self.vectors["adapter_rejections"]:
            value = copy.deepcopy(document)
            mutation = case["mutation"]
            target = value if mutation["target"] == "document" else value["rules"][mutation.get("rule_index", 0)]
            target[mutation["field"]] = copy.deepcopy(mutation["value"])
            outcome = PublicDeckAdapterCompiler.compile(value)
            self.assertFalse(outcome.accepted)
            self.assertEqual(case["expected_error_code"], outcome.error_code)
            self.assertIsNone(outcome.adapter)

    def test_fake_stale_copy_and_mutation_fail_closed(self) -> None:
        compiled = PublicDeckAdapterCompiler.compile(copy.deepcopy(self.vectors["adapter_documents"][0]["document"]))
        self.assertTrue(compiled.accepted)
        adapter = compiled.adapter
        context, _decision = _context_decision()
        self.assertEqual("invalid_context", PublicDeckAdapterProposer.propose(object(), adapter, "fake-context").error_code)
        self.assertEqual("invalid_adapter", PublicDeckAdapterProposer.propose(context, object(), "fake-adapter").error_code)
        result = PublicDeckAdapterProposer.propose(context, adapter, "bound").result
        second_context, _decision = _context_decision()
        self.assertFalse(result.validate_integrity(second_context, adapter))
        object.__setattr__(adapter, "_snapshot", {"PRIVATE": True})
        self.assertFalse(adapter.validate_integrity())
        self.assertEqual("invalid_adapter", PublicDeckAdapterProposer.propose(context, adapter, "mutated").error_code)


if __name__ == "__main__":
    unittest.main()
