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

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tools.ptcgdap.build_as_wp4_author_strategy_fixture import build_fixture_payloads
from tools.ptcgdap import sign_author_strategy_release_package as release_signer
from tools.ptcgdap.sign_author_strategy_release_package import sign_release_package


ROOT = Path(__file__).resolve().parents[2]
TRUST_RELATIVE = Path("data/ptcgdap/author_strategy_release_trust_store.json")
KEY_ID = "product.release.test-v1"
PRIVATE_KEY = bytes(range(32))


def public_key_base64(private_key: bytes = PRIVATE_KEY) -> str:
    key = Ed25519PrivateKey.from_private_bytes(private_key)
    public = key.public_key().public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw,
    )
    return base64.b64encode(public).decode("ascii")


def approved_trust(*, approval_status: str = "approved", status: str = "active") -> dict[str, object]:
    return {
        "document_type": "author_strategy_release_trust_store_v1",
        "schema_version": 1,
        "store_id": "ptcgdap-product-release-trust-v1",
        "approval_status": approval_status,
        "keys": [{
            "key_id": KEY_ID,
            "algorithm": "ed25519",
            "public_key_base64": public_key_base64(),
            "scope": "production_release",
            "execution_trusted": True,
            "status": status,
        }],
    }


class AuthorStrategyReleaseSigningTests(unittest.TestCase):
    def prepare(self, root: Path) -> tuple[Path, Path, Path]:
        project = root / "project"
        source = project / "source"
        trust_path = project / TRUST_RELATIVE
        private_path = root / "external-secrets" / "release.key"
        source.mkdir(parents=True)
        trust_path.parent.mkdir(parents=True)
        private_path.parent.mkdir(parents=True)
        for relative, value in build_fixture_payloads().items():
            path = source / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(value)
        trust_path.write_bytes(canonical_json_v1_bytes(approved_trust()))
        private_path.write_bytes(PRIVATE_KEY)
        return project, source, private_path

    def test_external_matching_product_key_builds_deterministic_package_and_safe_receipt(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-release-sign-") as temp:
            root = Path(temp)
            project, source, private_path = self.prepare(root)
            first = root / "release-1.ptcgai"
            second = root / "release-2.ptcgai"
            receipt_path = root / "release-receipt.json"

            receipt = sign_release_package(
                project_root=project,
                source=source,
                output=first,
                private_key_path=private_path,
                key_id=KEY_ID,
                receipt_path=receipt_path,
            )
            sign_release_package(
                project_root=project,
                source=source,
                output=second,
                private_key_path=private_path,
                key_id=KEY_ID,
            )

            self.assertEqual(first.read_bytes(), second.read_bytes())
            self.assertEqual(receipt, load_json_strict(receipt_path))
            self.assertEqual("author_strategy_release_signing_receipt_v1", receipt["document_type"])
            self.assertEqual(KEY_ID, receipt["signature_key_id"])
            self.assertEqual("production_release", receipt["signature_scope"])
            self.assertTrue(receipt["execution_trusted"])
            serialized = json.dumps(receipt, sort_keys=True)
            self.assertNotIn(str(private_path), serialized)
            self.assertNotIn(PRIVATE_KEY.hex(), serialized)
            with zipfile.ZipFile(first, "r") as archive:
                signature = json.loads(archive.read("signature.json"))
            self.assertEqual(KEY_ID, signature["key_id"])
            self.assertEqual(receipt["signed_payload_sha256"], signature["signed_payload_sha256"])

    def test_private_key_must_be_outside_project_and_match_approved_public_key(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-release-sign-") as temp:
            root = Path(temp)
            project, source, private_path = self.prepare(root)
            inside = project / "private.key"
            inside.write_bytes(PRIVATE_KEY)
            with self.assertRaisesRegex(ValueError, "outside project root"):
                sign_release_package(
                    project_root=project,
                    source=source,
                    output=root / "inside.ptcgai",
                    private_key_path=inside,
                    key_id=KEY_ID,
                )

            private_path.write_bytes(bytes(reversed(PRIVATE_KEY)))
            with self.assertRaisesRegex(ValueError, "does not match approved public key"):
                sign_release_package(
                    project_root=project,
                    source=source,
                    output=root / "wrong.ptcgai",
                    private_key_path=private_path,
                    key_id=KEY_ID,
                )

    def test_unapproved_revoked_duplicate_or_unknown_product_key_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-release-sign-") as temp:
            root = Path(temp)
            project, source, private_path = self.prepare(root)
            trust_path = project / TRUST_RELATIVE

            for label, trust, error in (
                ("unapproved", approved_trust(approval_status="unprovisioned"), "not approved"),
                ("revoked", approved_trust(status="revoked"), "not an active production key"),
                ("unknown", approved_trust(), "unknown production key"),
            ):
                trust_path.write_bytes(canonical_json_v1_bytes(trust))
                key_id = "product.release.unknown" if label == "unknown" else KEY_ID
                with self.subTest(label=label), self.assertRaisesRegex(ValueError, error):
                    sign_release_package(
                        project_root=project,
                        source=source,
                        output=root / f"{label}.ptcgai",
                        private_key_path=private_path,
                        key_id=key_id,
                    )

            duplicate = approved_trust()
            duplicate["keys"].append(dict(duplicate["keys"][0]))
            trust_path.write_bytes(canonical_json_v1_bytes(duplicate))
            with self.assertRaisesRegex(ValueError, "duplicate key_id"):
                sign_release_package(
                    project_root=project,
                    source=source,
                    output=root / "duplicate.ptcgai",
                    private_key_path=private_path,
                    key_id=KEY_ID,
                )

    def test_current_repository_product_trust_rejects_an_unmatched_external_key(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-release-sign-") as temp:
            root = Path(temp)
            source = root / "source"
            source.mkdir()
            private_path = root / "release.key"
            private_path.write_bytes(PRIVATE_KEY)
            with self.assertRaisesRegex(ValueError, "does not match approved public key"):
                sign_release_package(
                    project_root=ROOT,
                    source=source,
                    output=root / "must-not-exist.ptcgai",
                    private_key_path=private_path,
                    key_id="ptcgdap.product.release.ed25519.v1",
                )
            self.assertFalse((root / "must-not-exist.ptcgai").exists())

    def test_invalid_package_contract_is_rejected_before_any_output_is_written(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-release-sign-") as temp:
            root = Path(temp)
            project, source, private_path = self.prepare(root)
            manifest_path = source / "strategy_package.json"
            manifest = load_json_strict(manifest_path)
            manifest["unexpected_release_field"] = True
            manifest_path.write_bytes(canonical_json_v1_bytes(manifest))
            output = root / "invalid.ptcgai"
            receipt = root / "invalid.json"
            with self.assertRaisesRegex(ValueError, "package_manifest_invalid"):
                sign_release_package(
                    project_root=project,
                    source=source,
                    output=output,
                    private_key_path=private_path,
                    key_id=KEY_ID,
                    receipt_path=receipt,
                )
            self.assertFalse(output.exists())
            self.assertFalse(receipt.exists())

    def test_existing_destinations_and_partial_receipt_failures_never_replace_release_artifacts(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-release-sign-") as temp:
            root = Path(temp)
            project, source, private_path = self.prepare(root)
            output = root / "release.ptcgai"
            receipt = root / "release.json"
            output.write_bytes(b"existing-package")
            with self.assertRaisesRegex(ValueError, "already exists"):
                sign_release_package(
                    project_root=project,
                    source=source,
                    output=output,
                    private_key_path=private_path,
                    key_id=KEY_ID,
                    receipt_path=receipt,
                )
            self.assertEqual(b"existing-package", output.read_bytes())
            self.assertFalse(receipt.exists())

            output.unlink()
            receipt.write_bytes(b"existing-receipt")
            with self.assertRaisesRegex(ValueError, "already exists"):
                sign_release_package(
                    project_root=project,
                    source=source,
                    output=output,
                    private_key_path=private_path,
                    key_id=KEY_ID,
                    receipt_path=receipt,
                )
            self.assertFalse(output.exists())
            self.assertEqual(b"existing-receipt", receipt.read_bytes())

            receipt.unlink()
            real_write = release_signer._write_exclusive

            def fail_receipt(path: Path, value: bytes) -> None:
                if path == receipt:
                    raise OSError("simulated receipt write failure")
                real_write(path, value)

            with mock.patch.object(release_signer, "_write_exclusive", side_effect=fail_receipt):
                with self.assertRaisesRegex(OSError, "simulated receipt write failure"):
                    sign_release_package(
                        project_root=project,
                        source=source,
                        output=output,
                        private_key_path=private_path,
                        key_id=KEY_ID,
                        receipt_path=receipt,
                    )
            self.assertFalse(output.exists())
            self.assertFalse(receipt.exists())


if __name__ == "__main__":
    unittest.main()
