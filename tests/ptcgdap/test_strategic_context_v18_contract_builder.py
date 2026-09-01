from __future__ import annotations

import copy
import hashlib
import unittest
from pathlib import Path

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tools.ptcgdap.build_strategic_context_v18_contract import PATHS, documents, render


ROOT = Path(__file__).resolve().parents[2]


class StrategicContextV18ContractBuilderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.generated = documents()

    def test_generated_artifacts_are_exact_and_bundle_has_no_cycle(self) -> None:
        for key, value in self.generated.items():
            self.assertTrue(PATHS[key].is_file(), key)
            self.assertEqual(PATHS[key].read_bytes(), render(value), key)
        bundle = self.generated["bundle"]
        self.assertEqual([entry["id"] for entry in bundle["artifacts"]], ["schema", "profile", "vectors"])
        self.assertEqual(len({entry["path"] for entry in bundle["artifacts"]}), 3)
        self.assertNotIn("strategic_context_v18_bundle.json", "\n".join(entry["path"] for entry in bundle["artifacts"]))
        for entry in bundle["artifacts"]:
            value = self.generated[entry["id"]]
            self.assertEqual(hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper(), entry["canonical_sha256"])

    def test_profile_locks_public_authority_hash_domains_and_scope(self) -> None:
        profile = self.generated["profile"]
        self.assertEqual(profile["official_base_graph_v1_8"]["python_raw_sha256"], "5D3035312390936D86DE4E2BAF520CE38AB0A79137E1D93199B909D79FBCA3D2")
        self.assertFalse(profile["decision_contract"]["serialized_result_is_execution_authority"])
        self.assertEqual(bytes.fromhex(profile["hash_profiles"]["strategic_context_v18"]["prefix_utf8_hex"]), b"PTCGDAP\0STRATEGIC_CONTEXT_V18\0")
        self.assertEqual(bytes.fromhex(profile["hash_profiles"]["policy_decision_audit_v1"]["prefix_utf8_hex"]), b"PTCGDAP\0POLICY_DECISION_AUDIT_V1\0")
        self.assertIn("search_begin_input", profile["private_forbidden_keys"])
        self.assertIn("no Base Graph executor", profile["scope"])

    def test_schema_accepts_every_expected_value_and_rejects_authority_drift(self) -> None:
        schema = self.generated["schema"]
        Draft202012Validator.check_schema(schema)
        validator = Draft202012Validator(schema)
        vectors = self.generated["vectors"]
        context = vectors["fixture"]["expected_context"]
        self.assertEqual([], list(validator.iter_errors(context)))
        for case in vectors["decision_cases"]:
            self.assertEqual([], list(validator.iter_errors(case["expected_decision"])), case["id"])
        negatives = []
        extra_context = copy.deepcopy(context); extra_context["private"] = "sentinel"; negatives.append(extra_context)
        bad_hash = copy.deepcopy(context); bad_hash["context_hash"] = "a" * 64; negatives.append(bad_hash)
        exposed_hand = copy.deepcopy(context); exposed_hand["public_state"]["opponent_player"]["hand"] = []; negatives.append(exposed_hand)
        decision = copy.deepcopy(vectors["decision_cases"][0]["expected_decision"])
        decision["authoritative"] = True; negatives.append(decision)
        duplicate = copy.deepcopy(vectors["decision_cases"][0]["expected_decision"])
        duplicate["selected_indexes"] = [0, 0]; negatives.append(duplicate)
        private_reason = copy.deepcopy(vectors["decision_cases"][0]["expected_decision"])
        private_reason["reason_code"] = "PRIVATE_SENTINEL"; negatives.append(private_reason)
        for value in negatives:
            self.assertTrue(list(validator.iter_errors(value)), value)

    def test_vectors_are_closed_and_bind_ordered_current_options(self) -> None:
        vectors = self.generated["vectors"]
        self.assertEqual(len(vectors["context_rejections"]), 7)
        self.assertEqual(len(vectors["decision_cases"]), 4)
        self.assertEqual(len(vectors["decision_rejections"]), 4)
        context = vectors["fixture"]["expected_context"]
        options = context["select_semantics"]["options"]
        window = vectors["fixture"]["expected_window"]
        self.assertEqual([value["index"] for value in options], list(range(len(options))))
        self.assertEqual([value["fingerprint"] for value in options], window["option_fingerprints"])
        self.assertIsNone(context["public_state"]["opponent_player"]["hand"])
        self.assertIsInstance(context["public_state"]["acting_player"]["hand"], list)
        text = str(context)
        for sentinel in vectors["private_sentinels"]:
            self.assertNotIn(sentinel, text)


if __name__ == "__main__":
    unittest.main()
