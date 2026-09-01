from __future__ import annotations

from copy import deepcopy
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = ROOT / "contracts/ptcgdap/marnie_identity_projection.schema.json"
DOCUMENTS = [
    ROOT / "contracts/ptcgdap/marnie_identity_projection_profile.json",
    ROOT / "data/ptcgdap/marnie_vertical_slice/marnie_identity_projection_v1.json",
    ROOT / "contracts/ptcgdap/marnie_identity_projection_conformance_vectors.json",
    ROOT / "contracts/ptcgdap/marnie_identity_projection_bundle.json",
]


class MarnieIdentityProjectionSchemaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.schema = load_json_strict(SCHEMA_PATH)
        Draft202012Validator.check_schema(cls.schema)
        cls.validator = Draft202012Validator(cls.schema)
        cls.documents = [load_json_strict(path) for path in DOCUMENTS]

    def test_all_checked_in_documents_validate_strictly(self) -> None:
        for path, document in zip(DOCUMENTS, self.documents, strict=True):
            with self.subTest(path=path.name):
                self.validator.validate(document)

    def test_nested_additive_fields_and_unsafe_integers_are_rejected(self) -> None:
        audit = deepcopy(self.documents[1])
        audit["frames"][1]["private_sentinel"] = "SECRET"
        self.assertTrue(list(self.validator.iter_errors(audit)))
        audit = deepcopy(self.documents[1])
        audit["frames"][1]["identity_occurrence_count"] = 9007199254740992
        self.assertTrue(list(self.validator.iter_errors(audit)))

    def test_result_authority_and_bundle_cycles_are_rejected(self) -> None:
        vectors = deepcopy(self.documents[2])
        vectors["cases"][0]["expected"]["value"]["execution_authority"] = True
        self.assertTrue(list(self.validator.iter_errors(vectors)))
        bundle = deepcopy(self.documents[3])
        bundle["artifacts"][0]["path"] = "contracts/ptcgdap/marnie_identity_projection_bundle.json"
        self.assertTrue(list(self.validator.iter_errors(bundle)))

    def test_identity_partitions_and_error_codes_are_closed(self) -> None:
        audit = deepcopy(self.documents[1])
        audit["frames"][1]["mapped_official_card_ids"].append(audit["frames"][1]["known_unmapped_official_card_ids"][0])
        self.assertTrue(list(self.validator.iter_errors(audit)))
        vectors = deepcopy(self.documents[2])
        vectors["cases"][-1]["expected"]["error_code"] = "private_sentinel"
        self.assertTrue(list(self.validator.iter_errors(vectors)))


if __name__ == "__main__":
    unittest.main()
