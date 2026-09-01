from __future__ import annotations

import copy
import hashlib
import json
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes
from tools.ptcgdap.build_strategic_trace_v2_contract import (
    ADAPTER_OPERATORS,
    ADAPTER_REASON_CODES,
    BASE_OPERATORS,
    BUNDLE_PATH,
    CAPABILITIES,
    PROFILE_PATH,
    PRIVATE_IDENTIFIER_TOKENS,
    SCHEMA_PATH,
    VECTORS_PATH,
    render,
)


class StrategicTraceV2ContractBuilderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.rendered = render()
        cls.documents = {
            path: json.loads(value.decode("utf-8"))
            for path, value in cls.rendered.items()
        }
        cls.schema = cls.documents[SCHEMA_PATH]
        cls.profile = cls.documents[PROFILE_PATH]
        cls.vectors = cls.documents[VECTORS_PATH]

    def test_rendered_artifacts_are_exact_and_bundle_has_no_cycle(self) -> None:
        for path, expected in self.rendered.items():
            self.assertTrue(path.is_file(), path)
            self.assertEqual(expected, path.read_bytes(), path)
        bundle = self.documents[BUNDLE_PATH]
        self.assertEqual(["schema", "profile", "vectors"], [entry["id"] for entry in bundle["artifacts"]])
        self.assertNotIn(BUNDLE_PATH.name, "\n".join(entry["path"] for entry in bundle["artifacts"]))
        for entry in bundle["artifacts"]:
            path = {"schema": SCHEMA_PATH, "profile": PROFILE_PATH, "vectors": VECTORS_PATH}[entry["id"]]
            digest = hashlib.sha256(canonical_json_v1_bytes(self.documents[path])).hexdigest().upper()
            self.assertEqual(digest, entry["canonical_sha256"])

    def test_profile_freezes_base_authority_hash_domains_and_scope(self) -> None:
        profile = self.profile
        self.assertEqual(list(BASE_OPERATORS), profile["ir_contract"]["base_operators_in_required_order"])
        self.assertEqual(list(ADAPTER_OPERATORS), profile["ir_contract"]["adapter_operators"])
        self.assertEqual(list(ADAPTER_REASON_CODES), profile["ir_contract"]["adapter_reason_codes"])
        self.assertEqual(list(PRIVATE_IDENTIFIER_TOKENS), profile["ir_contract"]["private_identifier_tokens_denied"])
        self.assertEqual(list(CAPABILITIES), profile["ir_contract"]["required_capabilities"])
        self.assertEqual("single_entry_linear_dag", profile["ir_contract"]["graph_shape"])
        self.assertFalse(profile["ir_contract"]["serialized_result_is_execution_authority"])
        self.assertFalse(profile["trace_contract"]["serialized_result_is_execution_authority"])
        self.assertFalse(profile["scope"]["ir_executor"])
        self.assertFalse(profile["scope"]["live_owner"])
        self.assertEqual(
            b"PTCGDAP\0RESTRICTED_BASE_GRAPH_IR_V1\0",
            bytes.fromhex(profile["hash_contract"]["ir_prefix_utf8_hex"]),
        )
        self.assertEqual(
            b"PTCGDAP\0STRATEGIC_TRACE_V2\0",
            bytes.fromhex(profile["hash_contract"]["trace_prefix_utf8_hex"]),
        )
        self.assertEqual(
            "5D3035312390936D86DE4E2BAF520CE38AB0A79137E1D93199B909D79FBCA3D2",
            profile["base_graph_v1_8_source_raw_sha256"],
        )

    def test_schema_accepts_all_expected_values(self) -> None:
        Draft202012Validator.check_schema(self.schema)
        validator = Draft202012Validator(self.schema)
        for case in self.vectors["ir_cases"]:
            self.assertEqual([], list(validator.iter_errors(case["document"])), case["id"])
            self.assertEqual([], list(validator.iter_errors(case["expected_ir"])), case["id"])
        for case in self.vectors["trace_cases"]:
            self.assertEqual([], list(validator.iter_errors(case["expected_trace"])), case["id"])

    def test_schema_rejects_nested_authority_and_type_drift(self) -> None:
        validator = Draft202012Validator(self.schema)
        ir = copy.deepcopy(self.vectors["ir_cases"][0]["document"])
        trace = copy.deepcopy(self.vectors["trace_cases"][0]["expected_trace"])
        negatives = []
        value = copy.deepcopy(ir); value["nodes"][0]["config"]["private_state"] = {}; negatives.append(value)
        value = copy.deepcopy(ir); value["nodes"][0]["name"] = "localized"; negatives.append(value)
        value = copy.deepcopy(ir); value["nodes"][0]["config"]["frontier"] = "private_engine"; negatives.append(value)
        value = copy.deepcopy(ir); value["required_capabilities"].append("private_oracle"); negatives.append(value)
        value = copy.deepcopy(ir); value["graph_id"] = "PRIVATE_SENTINEL"; negatives.append(value)
        value = copy.deepcopy(trace); value["authoritative"] = True; negatives.append(value)
        value = copy.deepcopy(trace); value["frontier"]["legal_indexes"] = [0, 0]; negatives.append(value)
        value = copy.deepcopy(trace); value["frontier"]["legal_indexes"] = [2**53]; negatives.append(value)
        value = copy.deepcopy(trace); value["adapter_proposals"][0:0] = [{"operator": "python_callable", "indexes": [0], "reason_code": "private"}]; negatives.append(value)
        value = copy.deepcopy(trace); value["source"]["raw_private_hash"] = "A" * 64; negatives.append(value)
        for value in negatives:
            self.assertTrue(list(validator.iter_errors(value)), value)

    def test_vectors_are_closed_and_contain_no_private_sentinel(self) -> None:
        self.assertEqual(2, len(self.vectors["ir_cases"]))
        self.assertEqual(7, len(self.vectors["ir_rejections"]))
        self.assertEqual(2, len(self.vectors["trace_cases"]))
        self.assertEqual(7, len(self.vectors["trace_rejections"]))
        ids = []
        for key in ("ir_cases", "ir_rejections", "trace_cases", "trace_rejections"):
            ids.extend(case["id"] for case in self.vectors[key])
        self.assertEqual(len(ids), len(set(ids)))
        serialized = json.dumps(self.vectors["trace_cases"], sort_keys=True)
        for sentinel in self.vectors["private_sentinels"]:
            self.assertNotIn(sentinel, serialized)
        self.assertIn("audit/conformance", self.vectors["consumer_rule"])


if __name__ == "__main__":
    unittest.main()
