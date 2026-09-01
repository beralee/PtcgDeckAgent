from __future__ import annotations

import copy
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
DATA_ROOT = ROOT / "data/ptcgdap/marnie_vertical_slice"


class MarnieVerticalSliceSchemaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.schema = load_json_strict(CONTRACT_ROOT / "marnie_vertical_slice.schema.json")
        Draft202012Validator.check_schema(cls.schema)
        cls.validator = Draft202012Validator(cls.schema)
        cls.documents = [
            load_json_strict(CONTRACT_ROOT / "marnie_vertical_slice_profile.json"),
            load_json_strict(CONTRACT_ROOT / "marnie_vertical_slice_source_manifest.json"),
            load_json_strict(CONTRACT_ROOT / "marnie_vertical_slice_conformance_vectors.json"),
            load_json_strict(DATA_ROOT / "official_deck_manifest_v1.json"),
            load_json_strict(DATA_ROOT / "local_deck_manifest_v1.json"),
            load_json_strict(DATA_ROOT / "deck_identity_diff_v1.json"),
            load_json_strict(DATA_ROOT / "capability_inventory_v1.json"),
            load_json_strict(DATA_ROOT / "w0_w7_public_trajectory_v1.json"),
        ]

    def test_all_bound_documents_validate(self) -> None:
        self.assertEqual(8, len(self.documents))
        for document in self.documents:
            with self.subTest(artifact=document.get("artifact_id", document.get("profile_id"))):
                self.validator.validate(document)

    def test_nested_unknown_private_fields_are_rejected(self) -> None:
        mutations = []
        profile = copy.deepcopy(self.documents[0])
        profile["private_engine_state"] = "PRIVATE_SENTINEL"
        mutations.append(profile)
        source = copy.deepcopy(self.documents[1])
        source["inputs"][0]["display_name"] = "PRIVATE_SENTINEL"
        mutations.append(source)
        local = copy.deepcopy(next(value for value in self.documents if value.get("artifact_id") == "ptcgdap-marnie-local-deck-manifest-v1"))
        local["cards"][0]["name"] = "PRIVATE_SENTINEL"
        mutations.append(local)
        trajectory = copy.deepcopy(next(value for value in self.documents if value.get("artifact_id") == "ptcgdap-marnie-w0-w7-public-trajectory-v1"))
        trajectory["frames"][0]["private_replay"] = {"deck_order": [1, 2, 3]}
        mutations.append(trajectory)
        node = trajectory["frames"][0]["public_tree"]
        node["private_value"] = "PRIVATE_SENTINEL"
        mutations.append(trajectory)
        for index, document in enumerate(mutations):
            with self.subTest(index=index):
                self.assertFalse(self.validator.is_valid(document))


if __name__ == "__main__":
    unittest.main()
