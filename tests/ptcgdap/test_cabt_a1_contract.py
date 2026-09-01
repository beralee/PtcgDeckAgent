from __future__ import annotations

import copy
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.cabt_a1_contract import (
    CONTEXT_OPTION_TYPES,
    CONTEXT_SELECT_TYPE,
    build_a1_contracts,
    validate_a1_contracts,
)
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes


ROOT = Path(__file__).resolve().parents[2]


class CabtA1ContractTests(unittest.TestCase):
    def test_generated_census_and_matrices_are_exact_and_complete(self) -> None:
        documents = build_a1_contracts(ROOT)
        validate_a1_contracts(documents)
        for name, value in documents.items():
            self.assertEqual(
                canonical_json_v1_bytes(value),
                (ROOT / "contracts/ptcgdap" / name).read_bytes(),
                name,
            )
        census = documents["cabt_interface_census_v2.json"]
        self.assertEqual(49, len(census["context_rows"]))
        self.assertEqual(17, census["enum_counts"]["OptionType"])
        self.assertEqual(24, census["enum_counts"]["LogType"])
        self.assertEqual(set(range(49)), set(CONTEXT_SELECT_TYPE))
        self.assertEqual(set(range(49)), set(CONTEXT_OPTION_TYPES))

    def test_alignment_cannot_be_claimed_without_four_green_statuses(self) -> None:
        documents = build_a1_contracts(ROOT)
        changed = copy.deepcopy(documents)
        changed["cabt_prompt_coverage_matrix_v2.json"]["rows"][0]["four_statuses"][
            "execution"
        ] = "pending"
        with self.assertRaisesRegex(ValueError, "false_alignment"):
            validate_a1_contracts(changed)

    def test_context_option_mapping_matches_normative_sparse_families(self) -> None:
        self.assertEqual(0, CONTEXT_SELECT_TYPE[0])
        self.assertEqual([7, 8, 9, 10, 11, 12, 13, 14], CONTEXT_OPTION_TYPES[0])
        self.assertTrue(all(CONTEXT_OPTION_TYPES[value] == [3] for value in range(1, 26)))
        self.assertEqual([3, 4, 5], CONTEXT_OPTION_TYPES[29])
        self.assertTrue(all(CONTEXT_OPTION_TYPES[value] == [0] for value in range(38, 41)))
        self.assertTrue(all(CONTEXT_OPTION_TYPES[value] == [1, 2] for value in range(41, 47)))


if __name__ == "__main__":
    unittest.main()
