from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes
from tools.ptcgdap.build_godot_option_binding_contract import (
    BUNDLE_PATH,
    DECISION_PORT_BUNDLE_CANONICAL,
    PARENT_MANIFEST_CANONICAL,
    PROFILE_ID,
    PROFILE_PATH,
    SCHEMA_PATH,
    SELECTION_BUNDLE_CANONICAL,
    SOURCE_LOCK_CANONICAL,
    VECTORS_PATH,
    _render,
    build_documents,
)


ROOT = Path(__file__).resolve().parents[2]


def digest(value: object) -> str:
    return hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper()


class GodotOptionBindingContractBuilderTests(unittest.TestCase):
    def test_generated_documents_are_checked_in_exactly(self) -> None:
        documents = build_documents()
        self.assertEqual(set(documents), {SCHEMA_PATH, PROFILE_PATH, VECTORS_PATH, BUNDLE_PATH})
        for path, value in documents.items():
            self.assertTrue(path.is_file(), path)
            self.assertEqual(path.read_bytes(), _render(value), path)
        subprocess.run(
            [sys.executable, str(ROOT / "tools/ptcgdap/build_godot_option_binding_contract.py"), "--check"],
            cwd=ROOT,
            check=True,
        )

    def test_bundle_is_exact_noncyclic_and_parent_bound(self) -> None:
        documents = build_documents()
        bundle = documents[BUNDLE_PATH]
        self.assertEqual(bundle["contract_id"], PROFILE_ID)
        self.assertEqual(
            bundle["parent"],
            {
                "work_package": "P3-WP1",
                "manifest_canonical_sha256": PARENT_MANIFEST_CANONICAL,
                "decision_port_bundle_canonical_sha256": DECISION_PORT_BUNDLE_CANONICAL,
                "selection_bundle_canonical_sha256": SELECTION_BUNDLE_CANONICAL,
                "source_lock_canonical_sha256": SOURCE_LOCK_CANONICAL,
            },
        )
        self.assertEqual([entry["id"] for entry in bundle["artifacts"]], ["schema", "profile", "vectors"])
        by_path = {path.as_posix().replace(ROOT.as_posix() + "/", ""): value for path, value in documents.items()}
        for entry in bundle["artifacts"]:
            self.assertIn(entry["path"], by_path)
            self.assertNotEqual(entry["path"], "contracts/ptcgdap/godot_option_binding_bundle.json")
            self.assertEqual(entry["canonical_sha256"], digest(by_path[entry["path"]]))
        rendered = json.dumps(list(documents.values()), default=str)
        self.assertNotIn(digest(bundle), rendered)

    def test_profile_closes_private_authority_and_errors(self) -> None:
        profile = build_documents()[PROFILE_PATH]
        self.assertEqual(profile["supported_source_option_types"], [3, 7, 13, 14, 15])
        self.assertTrue(profile["serialization_contract"]["dto_only"])
        self.assertIn("callback_binding_hash", profile["serialization_contract"]["forbidden_fields"])
        self.assertIn("private_engine_command", profile["serialization_contract"]["forbidden_fields"])
        self.assertIn("private_object_refs", profile["serialization_contract"]["forbidden_fields"])
        self.assertIn("binding_not_current", profile["error_codes"])
        self.assertIn("reference_released", profile["error_codes"])
        self.assertEqual(len(profile["error_codes"]), len(set(profile["error_codes"])))

    def test_vectors_are_strict_schema_valid_and_fully_closed(self) -> None:
        documents = build_documents()
        schema = documents[SCHEMA_PATH]
        vectors = documents[VECTORS_PATH]
        Draft202012Validator.check_schema(schema)
        Draft202012Validator(schema).validate(vectors)
        self.assertEqual(len(vectors["bind_cases"]), 11)
        self.assertEqual(len(vectors["resolve_cases"]), 8)
        self.assertEqual(len(vectors["transition_cases"]), 3)
        all_ids = [case["id"] for section in ("bind_cases", "resolve_cases", "transition_cases") for case in vectors[section]]
        self.assertEqual(len(all_ids), len(set(all_ids)))
        fixture = vectors["fixture"]
        self.assertEqual(len(fixture["private_commands"]), len(fixture["expected_option_fingerprints"]))
        self.assertEqual(len(fixture["private_object_refs"]), len(fixture["private_commands"]))
        expected_values = [case["expected"] for section in ("bind_cases", "resolve_cases") for case in vectors[section]]
        expected_json = json.dumps(expected_values, sort_keys=True)
        forbidden_keys = {
            "callback_binding_hash", "private_engine_command", "private_object_refs",
            "_pending_choice", "_dialog_data",
        }
        def keys(value):
            if isinstance(value, dict):
                return set(value).union(*(keys(item) for item in value.values()))
            if isinstance(value, list):
                return set().union(*(keys(item) for item in value)) if value else set()
            return set()
        self.assertTrue(forbidden_keys.isdisjoint(keys(expected_values)))
        for token in ("command:", "object:", "card:"):
            self.assertNotIn(token, expected_json)

    def test_schema_rejects_private_echo_and_open_shapes(self) -> None:
        documents = build_documents()
        validator = Draft202012Validator(documents[SCHEMA_PATH])
        accepted = documents[VECTORS_PATH]["bind_cases"][0]["expected"]
        validator.validate(accepted)
        mutations = [
            {**accepted, "private_engine_command": "sentinel"},
            {**accepted, "error_code": "private_sentinel"},
            {**accepted, "audit": {**accepted["audit"], "callback_binding_hash": "A" * 64}},
            {**accepted, "audit": {**accepted["audit"], "option_fingerprints": ["not-a-hash"]}},
        ]
        for value in mutations:
            with self.subTest(value=value):
                self.assertTrue(list(validator.iter_errors(value)))

    def test_all_artifacts_are_canonical_json_v1_values(self) -> None:
        for value in build_documents().values():
            canonical_json_v1_bytes(value)


if __name__ == "__main__":
    unittest.main()
