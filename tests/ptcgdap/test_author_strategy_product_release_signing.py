from __future__ import annotations

import base64
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import zipfile

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

from scripts.ai.ptcgdap.author_strategy_package import AuthorStrategyPackageLoader
from scripts.ai.ptcgdap.author_strategy_release import AuthorStrategyReleaseGate
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tools.ptcgdap.build_author_strategy_release_candidate import (
    build_candidate_payloads,
    build_product_candidate_payloads,
)
from tools.ptcgdap.build_author_strategy_release_contract import PRODUCT_RELEASE_KEY_ID
from tools.ptcgdap.sign_author_strategy_product_release_candidate import (
    sign_product_release_candidate,
)
from tools.ptcgdap import sign_author_strategy_product_release_candidate as product_signer


PRIVATE_KEY = bytes(range(32))
ROOT = Path(__file__).resolve().parents[2]
PRODUCT_PACKAGE = (
    ROOT
    / "artifacts/ptcgdap/as_wp6_product_signing/ptcgdap-marnie-windows-local-0.1.0.ptcgai"
)
PRODUCT_RECEIPT = ROOT / "artifacts/ptcgdap/as_wp6_product_signing/signing_receipt.json"
PRODUCT_ARCHIVE_SHA256 = "AA65C8B46D2CEB0658EC18BB966F4DFECDB932750EDA3E65CD0B60208A08A0FD"


def _public_key_base64() -> str:
    public = Ed25519PrivateKey.from_private_bytes(PRIVATE_KEY).public_key().public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw,
    )
    return base64.b64encode(public).decode("ascii")


def _approved_trust() -> dict[str, object]:
    return {
        "document_type": "author_strategy_release_trust_store_v1",
        "schema_version": 1,
        "store_id": "ptcgdap-product-release-trust-v1",
        "approval_status": "approved",
        "keys": [{
            "key_id": PRODUCT_RELEASE_KEY_ID,
            "algorithm": "ed25519",
            "public_key_base64": _public_key_base64(),
            "scope": "production_release",
            "execution_trusted": True,
            "status": "active",
        }],
    }


class AuthorStrategyProductReleaseSigningTests(unittest.TestCase):
    def test_current_product_archive_is_exactly_bound_but_not_release_approved(self) -> None:
        receipt = load_json_strict(PRODUCT_RECEIPT)
        handle = AuthorStrategyPackageLoader().load_path(
            PRODUCT_PACKAGE,
            expected_archive_sha256=PRODUCT_ARCHIVE_SHA256,
        )
        metadata = handle.to_dict()
        self.assertEqual(PRODUCT_ARCHIVE_SHA256, receipt["archive_sha256"])
        self.assertEqual(receipt["manifest_sha256"], handle.manifest_sha256)
        self.assertEqual(receipt["policy_ir_sha256"], handle.policy_ir_sha256)
        self.assertEqual(receipt["deck_manifest_sha256"], handle.deck_manifest_sha256)
        self.assertEqual("production_trusted", handle.signature_status)
        self.assertEqual(PRODUCT_RELEASE_KEY_ID, handle.signature_key_id)
        self.assertEqual("production_release", handle.signature_scope)
        self.assertTrue(handle.execution_trusted)
        decision = AuthorStrategyReleaseGate(ROOT).evaluate_package(metadata)
        self.assertFalse(decision["accepted"])
        self.assertEqual("release_package_not_approved", decision["error_code"])
        self.assertFalse(decision["player_start_allowed"])

    def test_product_payload_changes_only_release_presentation_claims(self) -> None:
        fixture = build_candidate_payloads()
        product = build_product_candidate_payloads()
        self.assertEqual(set(fixture), set(product))
        changed = {
            path for path in fixture
            if fixture[path] != product[path]
        }
        self.assertEqual({"strategy_package.json", "README.md"}, changed)

        manifest = json.loads(product["strategy_package.json"])
        summary = manifest["strategy"]["summary"]
        readme = product["README.md"].decode("utf-8")
        claims = f"{summary}\n{readme}".lower()
        self.assertIn("product-signed", claims)
        self.assertIn("approval", claims)
        self.assertNotIn("test signed", claims)
        self.assertNotIn("test_fixture_only", claims)
        self.assertNotIn("execution_trusted=false", claims)

    def test_fixed_product_signer_emits_exact_payloads_and_safe_receipt(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-product-sign-") as temp:
            root = Path(temp)
            project = root / "project"
            trust_path = project / "data/ptcgdap/author_strategy_release_trust_store.json"
            private_path = root / "external" / "release.key"
            trust_path.parent.mkdir(parents=True)
            private_path.parent.mkdir(parents=True)
            trust_path.write_bytes(canonical_json_v1_bytes(_approved_trust()))
            private_path.write_bytes(PRIVATE_KEY)
            output = root / "product.ptcgai"
            receipt_path = root / "product-receipt.json"

            receipt = sign_product_release_candidate(
                project_root=project,
                private_key_path=private_path,
                output=output,
                receipt_path=receipt_path,
            )

            self.assertEqual(receipt, load_json_strict(receipt_path))
            self.assertEqual(PRODUCT_RELEASE_KEY_ID, receipt["signature_key_id"])
            self.assertTrue(receipt["execution_trusted"])
            serialized = json.dumps(receipt, sort_keys=True)
            self.assertNotIn(str(private_path), serialized)
            self.assertNotIn(PRIVATE_KEY.hex(), serialized)
            expected_payloads = build_product_candidate_payloads()
            with zipfile.ZipFile(output, "r") as archive:
                signature = json.loads(archive.read("signature.json"))
                self.assertEqual(PRODUCT_RELEASE_KEY_ID, signature["key_id"])
                for path, value in expected_payloads.items():
                    self.assertEqual(value, archive.read(path), path)

    def test_product_materializer_rejects_unsafe_path_before_signing(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-product-path-") as temp:
            root = Path(temp)
            output = root / "must-not-exist.ptcgai"
            receipt = root / "must-not-exist.json"
            with mock.patch.object(
                product_signer,
                "build_product_candidate_payloads",
                return_value={"../escape": b"forbidden"},
            ):
                with self.assertRaisesRegex(ValueError, "unsafe product payload path"):
                    sign_product_release_candidate(
                        project_root=root,
                        private_key_path=root / "missing.key",
                        output=output,
                        receipt_path=receipt,
                    )
            self.assertFalse(output.exists())
            self.assertFalse(receipt.exists())


if __name__ == "__main__":
    unittest.main()
