from __future__ import annotations

from pathlib import Path
import unittest

from scripts.ai.ptcgdap.marnie_portable_policy import MarniePortablePolicy
from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
VECTORS = load_json_strict(ROOT / "contracts/ptcgdap/marnie_portable_policy_conformance_vectors.json")


class MarniePortablePolicyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.owner = MarniePortablePolicy.load_default()

    def test_every_shared_vector_matches_exactly(self) -> None:
        self.assertEqual(28, len(VECTORS["cases"]))
        for case in VECTORS["cases"]:
            self.assertEqual(
                case["expected"],
                self.owner.run(case["operation"], case["input"]),
                case["case_id"],
            )

    def test_owner_recomputes_the_complete_parent_bound_trajectory(self) -> None:
        result = self.owner.evaluate_all()
        self.assertTrue(result.validate_integrity(self.owner))
        public = result.to_public_dict()
        self.assertEqual(13, public["frame_count"])
        self.assertEqual(public["frames"][-1]["portable_trace_hash"], public["chain_head"])
        self.assertFalse(public["authoritative"])
        self.assertFalse(public["execution_authority"])
        self.assertFalse(public["production_actions_used"])
        self.assertEqual(
            [
                "capability_initial_deck",
                "base_final",
                "capability_optional_zero",
                *(["base_final"] * 9),
                "terminal_lifecycle",
            ],
            [frame["owner_route"] for frame in public["frames"]],
        )

    def test_copy_mutation_does_not_change_owner_bound_result(self) -> None:
        result = self.owner.evaluate_frame("w3_main")
        self.assertTrue(result.validate_integrity(self.owner))
        value = result.to_public_dict()
        value["frames"][0]["action"] = [999999]
        self.assertTrue(result.validate_integrity(self.owner))
        self.assertEqual([2], result.to_public_dict()["frames"][0]["action"])


if __name__ == "__main__":
    unittest.main()
