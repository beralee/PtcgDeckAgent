from __future__ import annotations

import copy
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.marnie_public_base import MarniePublicBase
from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
VECTORS = load_json_strict(ROOT / "contracts/ptcgdap/marnie_public_base_conformance_vectors.json")


class MarniePublicBaseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.owner = MarniePublicBase.load_default()

    def test_shared_cases_match_exact_public_audit(self) -> None:
        for case in VECTORS["cases"]:
            with self.subTest(case=case["case_id"]):
                result = self.owner.run(case["operation"], copy.deepcopy(case["input"]))
                self.assertEqual(case["expected"], result)

    def test_evaluate_all_is_owner_sealed_and_non_authoritative(self) -> None:
        result = self.owner.evaluate_all()
        self.assertTrue(result.validate_integrity(self.owner))
        public = result.to_public_dict()
        self.assertEqual(16, public["case_count"])
        self.assertFalse(public["authoritative"])
        self.assertFalse(public["execution_authority"])


if __name__ == "__main__":
    unittest.main()
