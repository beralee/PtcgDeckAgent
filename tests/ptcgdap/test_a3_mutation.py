from __future__ import annotations

import unittest
from pathlib import Path

from scripts.ai.ptcgdap.a3_mutation import build_mutation_receipt, evaluate_python_vectors
from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
VECTORS = ROOT / "contracts/ptcgdap/a3_comparator_conformance_v2.json"


class A3MutationTests(unittest.TestCase):
    def test_python_comparator_captures_all_shared_vectors(self) -> None:
        results = evaluate_python_vectors(load_json_strict(VECTORS))
        self.assertEqual(
            [item["case_id"] for item in results],
            ["equal", "option_reorder", "damage", "log", "serial", "rng", "terminal"],
        )

    def test_receipt_requires_exact_godot_result_and_vector_hash(self) -> None:
        vectors = load_json_strict(VECTORS)
        results = evaluate_python_vectors(vectors)
        scope = {"scope_sha256": "A" * 64}
        bad = build_mutation_receipt(
            scope, VECTORS,
            {"accepted": True, "vectors_raw_sha256": "B" * 64, "results": results},
        )
        self.assertFalse(bad["python_godot_comparator_consistent"])


if __name__ == "__main__":
    unittest.main()
