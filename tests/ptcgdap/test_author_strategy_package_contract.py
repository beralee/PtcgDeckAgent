from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
ARTIFACTS = {
    "schema": CONTRACT_ROOT / "author_strategy_package.schema.json",
    "profile": CONTRACT_ROOT / "author_strategy_package_profile.json",
    "vectors": CONTRACT_ROOT / "author_strategy_package_conformance_vectors.json",
    "bundle": CONTRACT_ROOT / "author_strategy_package_bundle.json",
}
IMPLEMENTATION_PATHS = (
    ROOT / "tools/ptcgdap/build_author_strategy_package.py",
    ROOT / "scripts/ai/ptcgdap/author_strategy_package.py",
)
REQUIRED_ERROR_CODES = {
    "package_file_missing",
    "package_archive_invalid",
    "package_path_invalid",
    "package_duplicate_path",
    "package_file_unlisted",
    "package_file_hash_mismatch",
    "package_signature_untrusted",
    "package_manifest_invalid",
    "package_identity_conflict",
    "package_contract_incompatible",
    "package_catalog_incompatible",
    "package_deck_unmapped",
    "package_policy_unsupported",
    "package_resource_limit_exceeded",
    "package_integrity_invalid",
}
REQUIRED_VECTOR_IDS = {
    "valid_minimal",
    "valid_manifest_whitespace_identity",
    "archive_not_zip",
    "archive_entry_order_drift",
    "archive_timestamp_drift",
    "path_parent_traversal",
    "path_backslash",
    "path_absolute",
    "path_drive_letter",
    "duplicate_exact_path",
    "duplicate_casefold_path",
    "resource_entry_count",
    "resource_single_file",
    "resource_compression_ratio",
    "manifest_duplicate_key",
    "manifest_bom",
    "manifest_float",
    "manifest_unsafe_integer",
    "missing_required_file",
    "unlisted_extra_file",
    "payload_hash_mismatch",
    "signature_unknown_key",
    "signature_tampered",
    "compatibility_contract_drift",
    "compatibility_catalog_drift",
    "deck_not_exact_60",
    "policy_document_invalid",
    "forbidden_python",
    "forbidden_native",
    "forbidden_nested_archive",
}


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class AuthorStrategyPackageContractTests(unittest.TestCase):
    def test_contract_builder_and_loader_paths_exist(self) -> None:
        missing = [path.relative_to(ROOT).as_posix() for path in (*ARTIFACTS.values(), *IMPLEMENTATION_PATHS) if not path.is_file()]
        self.assertEqual([], missing)

    def test_schema_profile_vectors_and_bundle_are_strict_and_bound(self) -> None:
        documents = {name: load_json_strict(path) for name, path in ARTIFACTS.items()}
        Draft202012Validator.check_schema(documents["schema"])
        self.assertEqual("ptcgdap-author-strategy-package-v1", documents["profile"]["profile_id"])
        self.assertEqual("ptcgdap-author-strategy-package-v1", documents["vectors"]["profile_id"])
        bundle = documents["bundle"]
        self.assertEqual("ptcgdap-author-strategy-package-as-wp1-v1", bundle["bundle_id"])
        self.assertEqual({"schema", "profile", "vectors"}, {entry["id"] for entry in bundle["artifacts"]})
        for entry in bundle["artifacts"]:
            path = ROOT / entry["path"]
            self.assertEqual(entry["canonical_sha256"], sha(canonical_json_v1_bytes(load_json_strict(path))))

    def test_profile_centralizes_limits_precedence_types_and_test_only_trust(self) -> None:
        profile = load_json_strict(ARTIFACTS["profile"])
        self.assertEqual(REQUIRED_ERROR_CODES, set(profile["stable_error_codes"]))
        self.assertEqual(
            ["archive", "path", "resource", "manifest_type", "file_hash", "signature", "compatibility", "deck_policy", "integrity"],
            profile["error_precedence"],
        )
        limits = profile["resource_limits"]
        self.assertEqual(
            {
                "max_archive_bytes",
                "max_uncompressed_bytes",
                "max_entry_count",
                "max_path_bytes",
                "max_single_file_bytes",
                "max_json_bytes",
                "max_text_bytes",
                "max_csv_bytes",
                "max_weights_bytes",
                "max_image_bytes",
                "max_image_width",
                "max_image_height",
                "max_compression_ratio",
            },
            set(limits),
        )
        self.assertTrue(all(type(value) is int and value > 0 for value in limits.values()))
        self.assertEqual([0], profile["zip_profile"]["allowed_compression_methods"])
        self.assertEqual(
            {
                "strategic_trace_v2_bundle_canonical_sha256": "ADDD4CB48BD10FA0478854124D8E63AEE42B898C0EB81692BA35F8D7F90414C4",
                "public_deck_adapter_bundle_canonical_sha256": "C80F4C4FDAEA5AC29BD3C5617BFAC72BE38709696F7EA1995D3D153113DD3CA1",
            },
            profile["policy_contract_anchors"],
        )
        roots = profile["trust_store"]["keys"]
        self.assertEqual(1, len(roots))
        self.assertEqual("test_fixture_only", roots[0]["scope"])
        self.assertFalse(roots[0]["execution_trusted"])
        self.assertNotIn("private_key", json.dumps(profile))

    def test_shared_vectors_close_required_positive_and_negative_families(self) -> None:
        vectors = load_json_strict(ARTIFACTS["vectors"])
        cases = vectors["cases"]
        ids = [case["id"] for case in cases]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertTrue(REQUIRED_VECTOR_IDS <= set(ids))
        for case in cases:
            self.assertEqual(
                {"id", "operation", "expected_accepted", "expected_error_code"},
                set(case),
            )
            if case["expected_accepted"]:
                self.assertIsNone(case["expected_error_code"])
            else:
                self.assertIn(case["expected_error_code"], REQUIRED_ERROR_CODES)

    def test_builder_reproduces_all_contract_artifacts(self) -> None:
        result = subprocess.run(
            [sys.executable, "tools/ptcgdap/build_author_strategy_package.py", "--check-contracts"],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
