from __future__ import annotations

import json
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = load_json_strict(ROOT / "contracts/ptcgdap/marnie_portable_policy.schema.json")
PROFILE = load_json_strict(ROOT / "contracts/ptcgdap/marnie_portable_policy_profile.json")
VECTORS = load_json_strict(ROOT / "contracts/ptcgdap/marnie_portable_policy_conformance_vectors.json")
AUDIT = load_json_strict(ROOT / "data/ptcgdap/marnie_vertical_slice/marnie_portable_policy_v1.json")
BUNDLE = load_json_strict(ROOT / "contracts/ptcgdap/marnie_portable_policy_bundle.json")


class MarniePortablePolicySchemaTests(unittest.TestCase):
    def test_all_bound_documents_validate_strictly(self) -> None:
        validator = Draft202012Validator(SCHEMA)
        for value in (PROFILE, VECTORS, AUDIT, BUNDLE):
            errors = sorted(validator.iter_errors(value), key=lambda error: list(error.path))
            self.assertEqual([], errors, "\n".join(error.message for error in errors[:10]))

    def test_trajectory_scope_and_owner_split_are_exact(self) -> None:
        summary = AUDIT["summary"]
        self.assertEqual(13, summary["frame_count"])
        self.assertEqual(10, summary["base_owned_count"])
        self.assertEqual(2, summary["capability_owned_count"])
        self.assertEqual(1, summary["terminal_lifecycle_count"])
        self.assertEqual(11, summary["current_window_frame_count"])
        self.assertEqual(60, summary["initial_deck_card_count"])
        self.assertEqual(0, summary["python_gdscript_mismatch_count"])
        self.assertEqual(0, summary["skip_count"])
        self.assertEqual(list(range(13)), [frame["ordinal"] for frame in AUDIT["frames"]])
        self.assertEqual(
            [None, *[frame["portable_trace_hash"] for frame in AUDIT["frames"][:-1]]],
            [frame["previous_portable_trace_hash"] for frame in AUDIT["frames"]],
        )
        self.assertEqual(AUDIT["frames"][-1]["portable_trace_hash"], AUDIT["chain_head"])

    def test_public_artifacts_contain_no_private_or_live_authority(self) -> None:
        encoded = json.dumps(
            {"profile": PROFILE, "vectors": VECTORS, "audit": AUDIT, "bundle": BUNDLE},
            ensure_ascii=False,
        )
        for forbidden in (
            "search_begin_input",
            "raw_private_hash",
            "token_free_callback_hash",
            "callback_binding_hash",
            "GameState",
            "CardInstance",
            "PokemonSlot",
        ):
            self.assertNotIn(f'"{forbidden}"', encoded)
        self.assertFalse(AUDIT["authoritative"])
        self.assertFalse(AUDIT["execution_authority"])
        self.assertEqual("offline_public_differential_only", BUNDLE["runtime_authority"])


if __name__ == "__main__":
    unittest.main()
