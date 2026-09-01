from __future__ import annotations

import argparse
import base64
import hashlib
import hmac
import json
import os
from pathlib import Path
import re
import sys
import zipfile
import io

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import (
    canonical_json_v1_bytes,
    load_json_bytes_strict,
    sha256_bytes,
)
from scripts.ai.ptcgdap.author_strategy_package import AuthorStrategyPackageLoader
from tools.ptcgdap.build_author_strategy_package import (
    TEST_FIXTURE_KEY_ID,
    build_package_bytes,
    read_source_directory,
)


TRUST_RELATIVE = Path("data/ptcgdap/author_strategy_release_trust_store.json")
EXPECTED_STORE_ID = "ptcgdap-product-release-trust-v1"
KEY_ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._-]{0,95}$")
TRUST_FIELDS = frozenset({"document_type", "schema_version", "store_id", "approval_status", "keys"})
KEY_FIELDS = frozenset({
    "key_id",
    "algorithm",
    "public_key_base64",
    "scope",
    "execution_trusted",
    "status",
})
TEST_VALIDATION_PRIVATE_KEY = bytes(range(32))


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _is_within(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
    except ValueError:
        return False
    return True


def _fixed_trust_path(project_root: Path) -> tuple[Path, Path]:
    root = project_root.resolve(strict=True)
    if not root.is_dir():
        raise ValueError("project root must be a directory")
    path = root / TRUST_RELATIVE
    if not path.is_file():
        raise ValueError("product release trust store missing")
    resolved = path.resolve(strict=True)
    if resolved != path or not _is_within(resolved, root):
        raise ValueError("product release trust store must be the fixed non-symlink project file")
    return root, resolved


def _decode_public_key(value: object) -> bytes:
    if type(value) is not str:
        raise ValueError("release trust public key invalid")
    try:
        decoded = base64.b64decode(value, validate=True)
    except ValueError as error:
        raise ValueError("release trust public key invalid") from error
    if len(decoded) != 32 or base64.b64encode(decoded).decode("ascii") != value:
        raise ValueError("release trust public key invalid")
    return decoded


def _approved_public_key(trust: object, key_id: str) -> bytes:
    if type(trust) is not dict or set(trust) != TRUST_FIELDS:
        raise ValueError("release trust store contract invalid")
    if (
        trust.get("document_type") != "author_strategy_release_trust_store_v1"
        or type(trust.get("schema_version")) is not int
        or trust.get("schema_version") != 1
        or trust.get("store_id") != EXPECTED_STORE_ID
    ):
        raise ValueError("release trust store contract invalid")
    approval_status = trust.get("approval_status")
    if approval_status not in ("unprovisioned", "approved", "revoked"):
        raise ValueError("release trust store contract invalid")
    keys = trust.get("keys")
    if type(keys) is not list or len(keys) > 8:
        raise ValueError("release trust store contract invalid")

    by_id: dict[str, tuple[dict[str, object], bytes]] = {}
    for entry in keys:
        if type(entry) is not dict or set(entry) != KEY_FIELDS:
            raise ValueError("release trust store key contract invalid")
        candidate_id = entry.get("key_id")
        if type(candidate_id) is not str or KEY_ID_PATTERN.fullmatch(candidate_id) is None:
            raise ValueError("release trust store key contract invalid")
        if candidate_id in by_id:
            raise ValueError("release trust store duplicate key_id")
        if (
            entry.get("algorithm") != "ed25519"
            or entry.get("scope") != "production_release"
            or entry.get("execution_trusted") is not True
            or entry.get("status") not in ("active", "revoked")
        ):
            raise ValueError("release trust store key contract invalid")
        by_id[candidate_id] = (entry, _decode_public_key(entry.get("public_key_base64")))

    if approval_status != "approved":
        raise ValueError("product release trust store is not approved")
    selected = by_id.get(key_id)
    if selected is None:
        raise ValueError("unknown production key")
    if selected[0].get("status") != "active":
        raise ValueError("selected key is not an active production key")
    return selected[1]


def _read_external_private_key(path: Path, project_root: Path) -> bytes:
    lexical = Path(os.path.abspath(path))
    if _is_within(lexical, project_root):
        raise ValueError("private key must be outside project root")
    if not path.is_file() or path.is_symlink():
        raise ValueError("external private key must be a regular non-symlink file")
    resolved = path.resolve(strict=True)
    if _is_within(resolved, project_root):
        raise ValueError("private key must be outside project root")
    value = resolved.read_bytes()
    if len(value) == 32:
        return value
    try:
        decoded = bytes.fromhex(value.decode("ascii").strip())
    except (UnicodeDecodeError, ValueError) as error:
        raise ValueError("private key must be 32 raw bytes or 64 hex characters") from error
    if len(decoded) != 32:
        raise ValueError("private key must be 32 raw bytes or 64 hex characters")
    return decoded


def _validate_destination(path: Path, source: Path, *, suffix: str) -> Path:
    if path.suffix.lower() != suffix:
        raise ValueError(f"release destination must use {suffix} suffix")
    destination = Path(os.path.abspath(path))
    parent = destination.parent.resolve(strict=True)
    if not parent.is_dir():
        raise ValueError("release destination parent must be a directory")
    destination = parent / destination.name
    if _is_within(destination, source):
        raise ValueError("release destination must be outside package source")
    if destination.is_symlink():
        raise ValueError("release destination symlink forbidden")
    if destination.exists():
        raise ValueError("release destination already exists")
    return destination


def _write_exclusive(path: Path, value: bytes) -> None:
    handle = None
    try:
        handle = path.open("xb")
        with handle:
            handle.write(value)
    except Exception:
        if handle is not None and path.is_file() and not path.is_symlink():
            path.unlink()
        raise


def _receipt(archive: bytes, payloads: dict[str, bytes], trust_raw: bytes, public_key: bytes) -> dict[str, object]:
    manifest = load_json_bytes_strict(payloads["strategy_package.json"])
    with zipfile.ZipFile(io.BytesIO(archive), "r") as package:
        signature = load_json_bytes_strict(package.read("signature.json"))
    return {
        "document_type": "author_strategy_release_signing_receipt_v1",
        "schema_version": 1,
        "package_id": manifest["package_id"],
        "package_version": manifest["package_version"],
        "signature_algorithm": "ed25519",
        "signature_key_id": signature["key_id"],
        "signature_scope": "production_release",
        "execution_trusted": True,
        "archive_bytes": len(archive),
        "archive_sha256": sha256_bytes(archive),
        "manifest_sha256": _sha(payloads["strategy_package.json"]),
        "policy_ir_sha256": _sha(payloads["policy/policy_ir.json"]),
        "deck_manifest_sha256": _sha(payloads["deck/deck_manifest.json"]),
        "signed_payload_sha256": signature["signed_payload_sha256"],
        "signing_public_key_sha256": _sha(public_key),
        "trust_store_raw_sha256": _sha(trust_raw),
        "trust_store_canonical_sha256": _sha(canonical_json_v1_bytes(load_json_bytes_strict(trust_raw))),
    }


def sign_release_package(
    *,
    project_root: Path,
    source: Path,
    output: Path,
    private_key_path: Path,
    key_id: str,
    receipt_path: Path | None = None,
) -> dict[str, object]:
    if type(key_id) is not str or KEY_ID_PATTERN.fullmatch(key_id) is None:
        raise ValueError("production key_id invalid")
    root, trust_path = _fixed_trust_path(project_root)
    trust_raw = trust_path.read_bytes()
    trust = load_json_bytes_strict(trust_raw)
    approved_public = _approved_public_key(trust, key_id)
    private_bytes = _read_external_private_key(private_key_path, root)
    private = Ed25519PrivateKey.from_private_bytes(private_bytes)
    derived_public = private.public_key().public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw,
    )
    if not hmac.compare_digest(derived_public, approved_public):
        raise ValueError("private key does not match approved public key")

    source_root = source.resolve(strict=True)
    if not source_root.is_dir():
        raise ValueError("package source directory missing")
    destination = _validate_destination(output, source_root, suffix=".ptcgai")
    receipt_destination = None
    if receipt_path is not None:
        receipt_destination = _validate_destination(receipt_path, source_root, suffix=".json")
        if receipt_destination == destination:
            raise ValueError("receipt and package destinations must differ")
    payloads = read_source_directory(source_root)
    validation_archive = build_package_bytes(
        payloads,
        TEST_VALIDATION_PRIVATE_KEY,
        key_id=TEST_FIXTURE_KEY_ID,
    )
    AuthorStrategyPackageLoader().load_bytes(validation_archive)
    archive = build_package_bytes(payloads, private_bytes, key_id=key_id)
    receipt = _receipt(archive, payloads, trust_raw, derived_public)

    destination_created = False
    receipt_created = False
    try:
        _write_exclusive(destination, archive)
        destination_created = True
        if receipt_destination is not None:
            _write_exclusive(receipt_destination, canonical_json_v1_bytes(receipt))
            receipt_created = True
    except Exception:
        if receipt_created and receipt_destination is not None and receipt_destination.is_file():
            receipt_destination.unlink()
        if destination_created and destination.is_file():
            destination.unlink()
        raise
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Sign one .ptcgai release package with an external private key bound to the fixed product trust store."
    )
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--private-key", type=Path, required=True)
    parser.add_argument("--key-id", required=True)
    parser.add_argument("--receipt", type=Path)
    args = parser.parse_args()
    try:
        receipt = sign_release_package(
            project_root=ROOT,
            source=args.source,
            output=args.output,
            private_key_path=args.private_key,
            key_id=args.key_id,
            receipt_path=args.receipt,
        )
    except (OSError, ValueError, KeyError, zipfile.BadZipFile, json.JSONDecodeError) as error:
        raise SystemExit(f"release signing refused: {error}") from None
    print(f"package_id={receipt['package_id']}")
    print(f"package_version={receipt['package_version']}")
    print(f"signature_key_id={receipt['signature_key_id']}")
    print(f"archive_bytes={receipt['archive_bytes']}")
    print(f"archive_sha256={receipt['archive_sha256']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
