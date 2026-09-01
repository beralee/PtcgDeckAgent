from __future__ import annotations

from pathlib import Path
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tools.ptcgdap.build_marnie_public_base_contract import build_documents, write_documents


ROOT = Path(__file__).resolve().parents[2]


class MarniePublicBaseContractBuilderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.documents = build_documents(ROOT)

    def test_checked_in_documents_equal_fresh_build(self) -> None:
        for relative, value in self.documents.items():
            self.assertEqual(canonical_json_v1_bytes(value), canonical_json_v1_bytes(load_json_strict(ROOT / relative)), relative)

    def test_catalog_and_cases_are_complete_public_and_non_authoritative(self) -> None:
        profile = self.documents["contracts/ptcgdap/marnie_public_base_profile.json"]
        audit = self.documents["data/ptcgdap/marnie_vertical_slice/marnie_public_base_v1.json"]
        self.assertEqual(6, len(profile["macro_catalog"]))
        self.assertEqual(16, len(audit["cases"]))
        self.assertEqual(13, audit["summary"]["source_case_count"])
        self.assertEqual(3, audit["summary"]["offline_seeded_extension_count"])
        self.assertFalse(audit["authoritative"])
        serialized = canonical_json_v1_bytes(audit)
        for token in (b"search_begin_input", b"raw_private_hash", b"token_free_callback_hash", b"private_engine_command", b"GameState"):
            self.assertNotIn(token, serialized)
        self.assertEqual(
            {"search_begin_input", "raw_private_hash", "token_free_callback_hash", "callback_binding_hash", "private_engine_command", "private_object_refs", "GameState", "CardInstance", "PokemonSlot"},
            set(profile["private_exclusions"]),
        )

    def test_write_check_mode_reports_no_drift(self) -> None:
        self.assertEqual(0, write_documents(ROOT, check=True))


if __name__ == "__main__":
    unittest.main()
