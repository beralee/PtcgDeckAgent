from __future__ import annotations

from copy import deepcopy
from pathlib import Path
import sys
import unittest

from jsonschema import Draft202012Validator


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import load_json_strict  # noqa: E402


SCHEMA_PATH = ROOT / "contracts" / "ptcgdap" / "card_id_catalog.schema.json"
DOCUMENT_PATHS = {
    "source_manifest": ROOT
    / "contracts"
    / "ptcgdap"
    / "card_id_catalog_source_manifest.json",
    "official_master": ROOT
    / "data"
    / "ptcgdap"
    / "card_id_catalog"
    / "official_card_attack_master_v1.json",
    "exact_bridge": ROOT
    / "data"
    / "ptcgdap"
    / "card_id_catalog"
    / "marnie_exact_print_bridge_v1.json",
    "catalog_bundle": ROOT
    / "contracts"
    / "ptcgdap"
    / "card_id_catalog_bundle.json",
    "conformance_vectors": ROOT
    / "contracts"
    / "ptcgdap"
    / "card_id_catalog_conformance_vectors.json",
}
MAX_SAFE_INTEGER = 9_007_199_254_740_991
BUNDLE_PATH = "contracts/ptcgdap/card_id_catalog_bundle.json"


class CardIdCatalogSchemaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.schema = load_json_strict(SCHEMA_PATH)
        cls.documents = {
            definition: load_json_strict(path)
            for definition, path in DOCUMENT_PATHS.items()
        }

    @classmethod
    def _validator_for(cls, definition: str) -> Draft202012Validator:
        wrapper = {
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "$defs": cls.schema["$defs"],
            "$ref": f"#/$defs/{definition}",
        }
        return Draft202012Validator(wrapper)

    def _assert_valid(self, definition: str, document: object) -> None:
        errors = sorted(
            self._validator_for(definition).iter_errors(document),
            key=lambda error: tuple(str(part) for part in error.absolute_path),
        )
        self.assertEqual(
            errors,
            [],
            "\n".join(
                f"/{'/'.join(str(part) for part in error.absolute_path)}: {error.message}"
                for error in errors
            ),
        )

    def _assert_invalid(self, definition: str, document: object, label: str) -> None:
        errors = list(self._validator_for(definition).iter_errors(document))
        self.assertTrue(errors, f"schema accepted invalid {label}")

    def test_schema_is_valid_draft_202012_and_current_documents_match_intended_defs(self) -> None:
        self.assertEqual(
            self.schema["$schema"],
            "https://json-schema.org/draft/2020-12/schema",
        )
        Draft202012Validator.check_schema(self.schema)
        self.assertEqual(
            [branch["$ref"] for branch in self.schema["oneOf"]],
            [
                "#/$defs/official_master",
                "#/$defs/exact_bridge",
                "#/$defs/source_manifest",
                "#/$defs/catalog_bundle",
                "#/$defs/conformance_vectors",
            ],
        )
        self.assertFalse(self.schema["unevaluatedProperties"])

        root_validator = Draft202012Validator(self.schema)
        for definition, document in self.documents.items():
            with self.subTest(definition=definition, entry="direct_def"):
                self._assert_valid(definition, document)
            with self.subTest(definition=definition, entry="root_one_of"):
                self.assertEqual(list(root_validator.iter_errors(document)), [])

    def test_nested_name_and_text_payloads_are_rejected_in_identity_records(self) -> None:
        cases: list[tuple[str, dict[str, object], str]] = []

        master_card = deepcopy(self.documents["official_master"])
        master_card["cards"][0]["name"] = "forbidden display payload"
        cases.append(("official_master", master_card, "card name"))

        master_attack = deepcopy(self.documents["official_master"])
        master_attack["attacks"][0]["text"] = "forbidden effect payload"
        cases.append(("official_master", master_attack, "attack text"))

        bridge = deepcopy(self.documents["exact_bridge"])
        bridge["entries"][0]["local_printing"]["name"] = "forbidden local name"
        cases.append(("exact_bridge", bridge, "bridge printing name"))

        source = deepcopy(self.documents["source_manifest"])
        source["inputs"][0]["text"] = "forbidden source annotation"
        cases.append(("source_manifest", source, "source input text"))

        vector = deepcopy(self.documents["conformance_vectors"])
        vector["vectors"][0]["expected"]["value"]["name"] = "forbidden echo"
        cases.append(("conformance_vectors", vector, "result value name"))

        vector_input = deepcopy(self.documents["conformance_vectors"])
        vector_input["vectors"][0]["input"]["text"] = "forbidden input payload"
        cases.append(("conformance_vectors", vector_input, "vector input text"))

        for definition, document, label in cases:
            with self.subTest(label=label):
                self._assert_invalid(definition, document, label)

    def test_unsafe_integers_are_rejected_in_all_bound_numeric_payloads(self) -> None:
        cases: list[tuple[str, dict[str, object], str]] = []

        master_card = deepcopy(self.documents["official_master"])
        master_card["cards"][0]["official_card_id"] = MAX_SAFE_INTEGER + 1
        cases.append(("official_master", master_card, "unsafe official card id"))

        master_attack = deepcopy(self.documents["official_master"])
        master_attack["attacks"][0]["official_attack_id"] = MAX_SAFE_INTEGER + 1
        cases.append(("official_master", master_attack, "unsafe official attack id"))

        bridge = deepcopy(self.documents["exact_bridge"])
        bridge["entries"][0]["source_bytes"] = MAX_SAFE_INTEGER + 1
        cases.append(("exact_bridge", bridge, "unsafe bridge source size"))

        source = deepcopy(self.documents["source_manifest"])
        source["inputs"][0]["bytes"] = MAX_SAFE_INTEGER + 1
        cases.append(("source_manifest", source, "unsafe source input size"))

        vector = deepcopy(self.documents["conformance_vectors"])
        vector["vectors"][0]["input"]["official_card_id"] = MAX_SAFE_INTEGER + 1
        cases.append(("conformance_vectors", vector, "unsafe vector input"))

        for definition, document, label in cases:
            with self.subTest(label=label):
                self._assert_invalid(definition, document, label)

    def test_bundle_rejects_extra_artifacts_and_a_self_referential_path(self) -> None:
        extra = deepcopy(self.documents["catalog_bundle"])
        extra["artifacts"].append(deepcopy(extra["artifacts"][0]))
        self._assert_invalid("catalog_bundle", extra, "sixth bundle artifact")

        self_cycle = deepcopy(self.documents["catalog_bundle"])
        self_cycle["artifacts"][0]["path"] = BUNDLE_PATH
        self._assert_invalid("catalog_bundle", self_cycle, "bundle self-cycle")

    def test_bridge_and_source_records_fail_closed_on_structural_mutation(self) -> None:
        bridge_missing_hash = deepcopy(self.documents["exact_bridge"])
        del bridge_missing_hash["entries"][0]["source_raw_sha256"]
        self._assert_invalid(
            "exact_bridge",
            bridge_missing_hash,
            "bridge entry missing raw hash",
        )

        bridge_bad_attack_index = deepcopy(self.documents["exact_bridge"])
        bridge_bad_attack_index["entries"][1][
            "local_attack_index_to_official_attack_id"
        ]["01"] = 1
        self._assert_invalid(
            "exact_bridge",
            bridge_bad_attack_index,
            "non-canonical local attack index",
        )

        source_missing_path = deepcopy(self.documents["source_manifest"])
        del source_missing_path["inputs"][0]["path"]
        self._assert_invalid(
            "source_manifest",
            source_missing_path,
            "source record missing path",
        )

        source_lower_hash = deepcopy(self.documents["source_manifest"])
        source_lower_hash["inputs"][0]["raw_sha256"] = source_lower_hash["inputs"][0][
            "raw_sha256"
        ].lower()
        self._assert_invalid(
            "source_manifest",
            source_lower_hash,
            "lowercase source hash",
        )

    def test_uniform_result_dto_and_vector_shape_reject_semantic_malformation(self) -> None:
        cases: list[tuple[dict[str, object], str]] = []

        missing_value = deepcopy(self.documents["conformance_vectors"])
        del missing_value["vectors"][0]["expected"]["value"]
        cases.append((missing_value, "result DTO missing value"))

        extra_dto_field = deepcopy(self.documents["conformance_vectors"])
        extra_dto_field["vectors"][0]["expected"]["debug"] = "forbidden"
        cases.append((extra_dto_field, "result DTO extra field"))

        success_with_error = deepcopy(self.documents["conformance_vectors"])
        success_with_error["vectors"][0]["expected"] = {
            "ok": True,
            "error_code": "official_card_unknown",
            "value": None,
        }
        cases.append((success_with_error, "successful DTO carrying an error"))

        failure_without_error = deepcopy(self.documents["conformance_vectors"])
        failure_without_error["vectors"][0]["expected"] = {
            "ok": False,
            "error_code": None,
            "value": None,
        }
        cases.append((failure_without_error, "failed DTO without an error code"))

        unknown_error_code = deepcopy(self.documents["conformance_vectors"])
        unknown_error_code["vectors"][0]["expected"] = {
            "ok": False,
            "error_code": "not_in_the_closed_error_domain",
            "value": None,
        }
        cases.append((unknown_error_code, "DTO error outside the closed domain"))

        malformed_success_contract = deepcopy(self.documents["conformance_vectors"])
        malformed_success_contract["result_contract"]["success"]["name"] = "forbidden"
        cases.append((malformed_success_contract, "success contract extra field"))

        malformed_failure_contract = deepcopy(self.documents["conformance_vectors"])
        malformed_failure_contract["result_contract"]["failure"]["text"] = "forbidden"
        cases.append((malformed_failure_contract, "failure contract extra field"))

        for document, label in cases:
            with self.subTest(label=label):
                self._assert_invalid("conformance_vectors", document, label)


if __name__ == "__main__":
    unittest.main()
