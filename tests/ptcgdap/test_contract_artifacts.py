from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import (
    DuplicateJsonKeyError,
    canonical_json_v1_bytes,
    load_json_strict,
    sha256_bytes,
)


ENVELOPE_SCHEMA = ROOT / "contracts" / "ptcgdap" / "raw_cabt_envelope.schema.json"
FIXTURE_MANIFEST = ROOT / "tests" / "ptcgdap" / "fixtures" / "fixtures_manifest.json"
OPTION_SHAPES = ROOT / "contracts" / "ptcgdap" / "cabt_option_sparse_shapes.json"
HASH_PROFILE = ROOT / "contracts" / "ptcgdap" / "cabt_tree_hash_profile.json"
CONTRACT_BUNDLE = ROOT / "contracts" / "ptcgdap" / "cabt_contract_bundle.json"
TYPED_VIEW_PROFILE = ROOT / "contracts" / "ptcgdap" / "cabt_typed_view_profile.json"
TREE_HASH_VECTORS = ROOT / "contracts" / "ptcgdap" / "cabt_tree_hash_conformance_vectors.json"
CURRENT_CONTRACT_BUNDLE_SHA256 = "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"


class ContractArtifactTests(unittest.TestCase):
    def test_raw_envelope_schema_preserves_unknown_fields_without_exposing_them_as_known(self) -> None:
        schema = load_json_strict(ENVELOPE_SCHEMA)

        self.assertIn("raw_payload", schema["required"])
        self.assertIn("known_view", schema["required"])
        self.assertIn("unknown_fields", schema["required"])
        self.assertTrue(schema["properties"]["raw_payload"]["additionalProperties"])
        self.assertEqual(schema["properties"]["unknown_fields"]["type"], "array")
        self.assertFalse(schema["properties"]["unknown_fields"]["items"]["additionalProperties"])
        self.assertFalse(schema["properties"]["known_view"]["additionalProperties"])
        self.assertEqual(
            set(schema["properties"]["known_view"]["properties"]),
            {"select", "logs", "current"},
        )
        self.assertIn("token_free_callback_hash", schema["required"])
        self.assertIn("including additive unknown fields", schema["properties"]["token_free_callback_hash"]["description"])
        self.assertEqual(
            set(schema["properties"]["raw_payload"]["required"]),
            {"select", "logs", "current", "search_begin_input"},
        )
        self.assertIn("firewall_status", schema["required"])
        self.assertIn("null", schema["properties"]["public_observation_hash"]["type"])
        self.assertFalse(schema["properties"]["parse_issues"]["items"]["additionalProperties"])
        self.assertIn("source_contract_hash", schema["required"])
        self.assertNotIn("contract_hash", schema["properties"])
        search_when_present = schema["allOf"][0]["then"]["properties"]["raw_payload"]["properties"]["search_begin_input"]
        self.assertEqual(search_when_present, {"type": "string"})

    def test_tree_hash_profile_is_implemented_and_domain_separated(self) -> None:
        profile = load_json_strict(HASH_PROFILE)

        self.assertEqual(profile["profile_id"], "cabt_tree_hash_v1")
        self.assertEqual(profile["status"], "implemented_p1_wp2_offline_shadow")
        self.assertEqual(profile["canonical_json"]["standard"], "RFC 8785 JSON Canonicalization Scheme (JCS)")
        self.assertIn("noncharacter", profile["canonical_json"]["invalid_unicode"])
        self.assertIn("forbidden", profile["canonical_json"]["utf8_bom"])
        self.assertIn("2^53-1", profile["canonical_json"]["integer_nodes"])
        self.assertIn("binary64", profile["canonical_json"]["decimal_json_numbers"])
        self.assertEqual(
            profile["limits"],
            {
                "max_input_bytes": 67108864,
                "max_depth": 128,
                "max_nodes": 1000000,
                "max_output_bytes": 67108864,
                "node_counting": "count the root and every array element or object value as JSON values; object keys are not separate nodes",
            },
        )
        self.assertEqual(
            set(profile["domain_separation"]["domain_contracts"]),
            {"raw_private", "token_free_callback", "public_observation"},
        )
        public_domain = profile["domain_separation"]["domain_contracts"]["public_observation"]
        self.assertIn("separate", public_domain["relationship"])
        self.assertIn("neither the search_begin_input key nor its presence marker", public_domain["precondition"])
        prefix = profile["domain_separation"]["prefix_template"].format(domain="raw_private")
        self.assertEqual(
            prefix.encode("utf-8"),
            b"PTCGDAP\x00CABT_TREE_HASH_V1\x00raw_private\x00",
        )
        self.assertEqual(
            profile["conformance_vectors"],
            "contracts/ptcgdap/cabt_tree_hash_conformance_vectors.json",
        )
        artifact_subset = profile["contract_bundle"]["canonical_json_v1_subset"]
        self.assertIn("exact object/list/string/integer/boolean/null", artifact_subset["runtime_types"])
        self.assertEqual(
            artifact_subset["integer_range"],
            "-9007199254740991..9007199254740991 inclusive",
        )
        self.assertIn("noncharacter", artifact_subset["invalid_unicode"])
        self.assertEqual(artifact_subset["object_key_order"], "Unicode code-point order")
        self.assertEqual(artifact_subset["normalization"], "none")

    def test_contract_bundle_pins_every_contract_artifact(self) -> None:
        bundle = load_json_strict(CONTRACT_BUNDLE)

        self.assertEqual(bundle["schema_version"], 2)
        self.assertEqual(bundle["contract_id"], "ptcgdap-cabt-contract-p1-wp3-v1")
        self.assertEqual(
            bundle["parent_contract"],
            {
                "contract_id": "ptcgdap-cabt-contract-p1-wp2-v1",
                "canonical_sha256": "A9BD1BBB725FF002DCE5BF60043AD62AC078EC07E2FDB772ED394AC5FA3EE6F3",
            },
        )
        self.assertEqual(bundle["digest_mode"], "canonical_json_v1")
        self.assertEqual(
            sha256_bytes(canonical_json_v1_bytes(bundle)),
            CURRENT_CONTRACT_BUNDLE_SHA256,
        )
        self.assertEqual(
            {entry["id"] for entry in bundle["artifacts"]},
            {
                "raw_envelope_schema",
                "tree_hash_profile",
                "enum_snapshot",
                "option_sparse_shapes",
                "typed_view_profile",
                "tree_hash_conformance_vectors",
                "selection_window_schema",
                "selection_profile",
                "selection_conformance_vectors",
            },
        )
        self.assertEqual(len(bundle["artifacts"]), 9)
        self.assertEqual(
            {entry["id"]: entry["path"] for entry in bundle["artifacts"]},
            {
                "raw_envelope_schema": "contracts/ptcgdap/raw_cabt_envelope.schema.json",
                "tree_hash_profile": "contracts/ptcgdap/cabt_tree_hash_profile.json",
                "enum_snapshot": "contracts/ptcgdap/cabt_enum_snapshot.json",
                "option_sparse_shapes": "contracts/ptcgdap/cabt_option_sparse_shapes.json",
                "typed_view_profile": "contracts/ptcgdap/cabt_typed_view_profile.json",
                "tree_hash_conformance_vectors": "contracts/ptcgdap/cabt_tree_hash_conformance_vectors.json",
                "selection_window_schema": "contracts/ptcgdap/cabt_selection_window.schema.json",
                "selection_profile": "contracts/ptcgdap/cabt_selection_profile.json",
                "selection_conformance_vectors": "contracts/ptcgdap/cabt_selection_conformance_vectors.json",
            },
        )
        for entry in bundle["artifacts"]:
            path = ROOT / entry["path"]
            tree = load_json_strict(path)
            self.assertEqual(
                sha256_bytes(canonical_json_v1_bytes(tree)),
                entry["canonical_sha256"],
                entry["id"],
            )

        self.assertEqual(
            sha256_bytes(canonical_json_v1_bytes(load_json_strict(TYPED_VIEW_PROFILE))),
            next(entry["canonical_sha256"] for entry in bundle["artifacts"] if entry["id"] == "typed_view_profile"),
        )
        self.assertEqual(
            sha256_bytes(canonical_json_v1_bytes(load_json_strict(TREE_HASH_VECTORS))),
            next(entry["canonical_sha256"] for entry in bundle["artifacts"] if entry["id"] == "tree_hash_conformance_vectors"),
        )

    def test_contract_digest_inputs_reject_duplicate_json_keys(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "duplicate.json"
            path.write_bytes(b'{"schema_version":1,"schema_version":1}')

            with self.assertRaises(DuplicateJsonKeyError):
                load_json_strict(path)

    def test_fixture_catalog_covers_p1_wp1_matrix(self) -> None:
        manifest = json.loads(FIXTURE_MANIFEST.read_text(encoding="utf-8"))
        covered = {coverage for fixture in manifest["fixtures"] for coverage in fixture["covers"]}

        self.assertTrue(
            {
                "initial_callback",
                "single_select",
                "optional_zero",
                "multi_select",
                "ordered_multi_select",
                "hidden_regions",
                "deck_selection",
                "unknown_field",
                "unknown_enum",
                "fail_closed_contract_only",
                "private_replay_rejection",
            }.issubset(covered)
        )

    def test_all_official_option_types_have_an_exact_sparse_shape(self) -> None:
        contract = json.loads(OPTION_SHAPES.read_text(encoding="utf-8"))

        self.assertEqual(set(contract["shapes"]), {str(value) for value in range(17)})
        for raw_type, fields in contract["shapes"].items():
            self.assertEqual(fields[0], "type", raw_type)
            self.assertEqual(len(fields), len(set(fields)), raw_type)


if __name__ == "__main__":
    unittest.main()
