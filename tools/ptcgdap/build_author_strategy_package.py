from __future__ import annotations

import argparse
import base64
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import sys
from typing import Mapping
import zipfile


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

from scripts.ai.ptcgdap.source_lock import (
    canonical_json_v1_bytes,
    load_json_bytes_strict,
    sha256_bytes,
)


CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
PROFILE_ID = "ptcgdap-author-strategy-package-v1"
BUNDLE_ID = "ptcgdap-author-strategy-package-as-wp1-v1"
TEST_FIXTURE_KEY_ID = "ptcgdap-as-wp1-test-fixture-ed25519-v1"
TEST_FIXTURE_PUBLIC_KEY_BASE64 = "A6EHv/POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg="
CABT_CONTRACT_SHA256 = "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
CARD_CATALOG_SHA256 = "AB8CF10465F492A98DA8247A84572AECEE281D0726F7BB7B8E5DBC03A6AC70D4"
BASE_EXECUTOR_SHA256 = "69D05747A9F91C19765D448B676C86E1D9DFA1BBAB108ED1374B854B34E48389"
FIXED_TIME = (1980, 1, 1, 0, 0, 0)
FIXED_MODE = 0o100644 << 16
GENERATED_PATHS = frozenset({"files.sha256.json", "signature.json"})
REQUIRED_PAYLOAD_PATHS = frozenset(
    {
        "strategy_package.json",
        "README.md",
        "LICENSE",
        "deck/deck_manifest.json",
        "deck/deck.csv",
        "policy/policy_ir.json",
        "policy/adapter.json",
        "policy/config.json",
    }
)
OPTIONAL_PAYLOAD_KINDS = {
    "policy/weights.bin": "weights",
    "assets/icon.png": "png",
    "assets/banner.png": "png",
    "assets/icon.webp": "webp",
    "assets/banner.webp": "webp",
}
FIXED_PAYLOAD_KINDS = {
    "strategy_package.json": "json",
    "README.md": "text",
    "LICENSE": "text",
    "deck/deck_manifest.json": "json",
    "deck/deck.csv": "csv",
    "policy/policy_ir.json": "json",
    "policy/adapter.json": "json",
    "policy/config.json": "json",
}


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _object(properties: dict[str, object], required: list[str]) -> dict[str, object]:
    return {
        "type": "object",
        "additionalProperties": False,
        "required": required,
        "properties": properties,
    }


def build_schema() -> dict[str, object]:
    sha_schema = {"type": "string", "pattern": "^[0-9A-F]{64}$"}
    id_schema = {
        "type": "string",
        "minLength": 3,
        "maxLength": 128,
        "pattern": "^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])$",
    }
    display_schema = {"type": "string", "minLength": 1, "maxLength": 120}
    path_schema = {
        "type": "string",
        "minLength": 1,
        "maxLength": 128,
        "pattern": "^[A-Za-z0-9][A-Za-z0-9._-]*(?:/[A-Za-z0-9][A-Za-z0-9._-]*)*$",
    }
    safe_int = {"type": "integer", "minimum": 0, "maximum": 9007199254740991}
    strategy_package = _object(
        {
            "document_type": {"const": "strategy_package_v1"},
            "schema_version": {"const": 1},
            "package_id": id_schema,
            "package_version": {
                "type": "string",
                "pattern": "^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?$",
                "maxLength": 64,
            },
            "author": _object(
                {"author_id": id_schema, "display_name": display_schema},
                ["author_id", "display_name"],
            ),
            "strategy": _object(
                {
                    "display_name": display_schema,
                    "summary": {"type": "string", "minLength": 1, "maxLength": 512},
                },
                ["display_name", "summary"],
            ),
            "deck": _object(
                {
                    "display_name": display_schema,
                    "manifest_path": {"const": "deck/deck_manifest.json"},
                    "deck_path": {"const": "deck/deck.csv"},
                },
                ["display_name", "manifest_path", "deck_path"],
            ),
            "policy": _object(
                {
                    "entry_kind": {"const": "restricted_policy_ir_v1"},
                    "ir_path": {"const": "policy/policy_ir.json"},
                    "adapter_path": {"const": "policy/adapter.json"},
                    "config_path": {"const": "policy/config.json"},
                    "weights_path": {"oneOf": [{"const": "policy/weights.bin"}, {"type": "null"}]},
                },
                ["entry_kind", "ir_path", "adapter_path", "config_path", "weights_path"],
            ),
            "compatibility": _object(
                {
                    "minimum_game_api": {"const": "ptcgdap-author-host-v1"},
                    "cabt_contract_sha256": sha_schema,
                    "card_catalog_sha256": sha_schema,
                    "base_executor_sha256": sha_schema,
                    "required_capabilities": {
                        "type": "array",
                        "maxItems": 16,
                        "uniqueItems": True,
                        "items": {
                            "type": "string",
                            "minLength": 1,
                            "maxLength": 64,
                            "pattern": "^[a-z0-9][a-z0-9_-]*$",
                        },
                    },
                },
                [
                    "minimum_game_api",
                    "cabt_contract_sha256",
                    "card_catalog_sha256",
                    "base_executor_sha256",
                    "required_capabilities",
                ],
            ),
            "presentation": _object(
                {
                    "icon_path": {
                        "oneOf": [
                            {"enum": ["assets/icon.png", "assets/icon.webp"]},
                            {"type": "null"},
                        ]
                    },
                    "banner_path": {
                        "oneOf": [
                            {"enum": ["assets/banner.png", "assets/banner.webp"]},
                            {"type": "null"},
                        ]
                    },
                },
                ["icon_path", "banner_path"],
            ),
        },
        [
            "document_type",
            "schema_version",
            "package_id",
            "package_version",
            "author",
            "strategy",
            "deck",
            "policy",
            "compatibility",
            "presentation",
        ],
    )
    file_entry = _object(
        {
            "path": path_schema,
            "kind": {"enum": ["json", "text", "csv", "weights", "png", "webp"]},
            "bytes": safe_int,
            "sha256": sha_schema,
        },
        ["path", "kind", "bytes", "sha256"],
    )
    files_manifest = _object(
        {
            "document_type": {"const": "files_sha256_v1"},
            "schema_version": {"const": 1},
            "files": {"type": "array", "minItems": 8, "maxItems": 13, "items": file_entry},
        },
        ["document_type", "schema_version", "files"],
    )
    signature = _object(
        {
            "document_type": {"const": "signature_v1"},
            "schema_version": {"const": 1},
            "algorithm": {"const": "ed25519"},
            "key_id": id_schema,
            "signed_payload_sha256": sha_schema,
            "signature_base64": {
                "type": "string",
                "pattern": "^[A-Za-z0-9+/]{86}==$",
            },
        },
        ["document_type", "schema_version", "algorithm", "key_id", "signed_payload_sha256", "signature_base64"],
    )
    deck_manifest = _object(
        {
            "document_type": {"const": "deck_manifest_v1"},
            "schema_version": {"const": 1},
            "deck_id": id_schema,
            "card_id_domain": {"const": "official_cabt_card_id"},
            "card_count": {"const": 60},
            "deck_csv_sha256": sha_schema,
            "cabt_exportable": {"type": "boolean"},
        },
        ["document_type", "schema_version", "deck_id", "card_id_domain", "card_count", "deck_csv_sha256", "cabt_exportable"],
    )
    policy_ir = _object(
        {
            "schema_version": {"const": 1},
            "profile_id": {"const": "ptcgdap-restricted-base-graph-ir-p4-wp2-v1"},
            "graph_id": id_schema,
            "entry_node_id": {"type": "string", "minLength": 1, "maxLength": 64},
            "required_capabilities": {
                "type": "array",
                "minItems": 4,
                "maxItems": 16,
                "uniqueItems": True,
                "items": {"type": "string", "minLength": 1, "maxLength": 64},
            },
            "nodes": {
                "type": "array",
                "minItems": 6,
                "maxItems": 256,
                "items": _object(
                    {
                        "node_id": {"type": "string", "minLength": 1, "maxLength": 64},
                        "operator": {"type": "string", "minLength": 1, "maxLength": 64},
                        "owner": {"enum": ["base", "adapter"]},
                        "config": {"type": "object"},
                        "next_node_ids": {
                            "type": "array",
                            "maxItems": 1,
                            "items": {"type": "string", "minLength": 1, "maxLength": 64},
                        },
                    },
                    ["node_id", "operator", "owner", "config", "next_node_ids"],
                ),
            },
        },
        ["schema_version", "profile_id", "graph_id", "entry_node_id", "required_capabilities", "nodes"],
    )
    adapter = _object(
        {
            "schema_version": {"const": 1},
            "adapter_id": id_schema,
            "adapter_version": {"type": "integer", "minimum": 1, "maximum": 9007199254740991},
            "rules": {"type": "array", "maxItems": 256, "items": {"type": "object"}},
        },
        ["schema_version", "adapter_id", "adapter_version", "rules"],
    )
    config = _object(
        {
            "document_type": {"const": "author_policy_config_v1"},
            "schema_version": {"const": 1},
            "config_profile_id": {"const": "ptcgdap-author-policy-config-v1"},
            "values": {
                "type": "object",
                "maxProperties": 128,
                "propertyNames": {"pattern": "^[a-z][a-z0-9_]{0,63}$"},
                "additionalProperties": {
                    "oneOf": [
                        {"type": "string", "maxLength": 256},
                        {"type": "integer", "minimum": -9007199254740991, "maximum": 9007199254740991},
                        {"type": "boolean"},
                        {"type": "null"},
                    ]
                },
            },
        },
        ["document_type", "schema_version", "config_profile_id", "values"],
    )
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/author_strategy_package.schema.json",
        "title": "PtcgDAP author strategy package documents v1",
        "oneOf": [
            {"$ref": "#/$defs/strategy_package"},
            {"$ref": "#/$defs/files_manifest"},
            {"$ref": "#/$defs/signature"},
            {"$ref": "#/$defs/deck_manifest"},
            {"$ref": "#/$defs/policy_ir"},
            {"$ref": "#/$defs/adapter"},
            {"$ref": "#/$defs/config"},
        ],
        "$defs": {
            "strategy_package": strategy_package,
            "files_manifest": files_manifest,
            "signature": signature,
            "deck_manifest": deck_manifest,
            "policy_ir": policy_ir,
            "adapter": adapter,
            "config": config,
        },
    }


def build_profile() -> dict[str, object]:
    return {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "container": {
            "extension": ".ptcgai",
            "format": "zip",
            "nested_archives": False,
            "arbitrary_code": False,
            "network_or_process_capability": False,
        },
        "required_payload_paths": sorted(REQUIRED_PAYLOAD_PATHS),
        "generated_member_paths": sorted(GENERATED_PATHS),
        "optional_payload_kinds": OPTIONAL_PAYLOAD_KINDS,
        "payload_kinds": FIXED_PAYLOAD_KINDS,
        "resource_limits": {
            "max_archive_bytes": 12 * 1024 * 1024,
            "max_uncompressed_bytes": 16 * 1024 * 1024,
            "max_entry_count": 16,
            "max_path_bytes": 128,
            "max_single_file_bytes": 8 * 1024 * 1024,
            "max_json_bytes": 256 * 1024,
            "max_text_bytes": 256 * 1024,
            "max_csv_bytes": 256 * 1024,
            "max_weights_bytes": 8 * 1024 * 1024,
            "max_image_bytes": 2 * 1024 * 1024,
            "max_image_width": 2048,
            "max_image_height": 2048,
            "max_compression_ratio": 20,
        },
        "zip_profile": {
            "entry_order": "ascending_ascii_path_bytes",
            "allowed_compression_methods": [0],
            "builder_compression_method": 0,
            "timestamp": "1980-01-01T00:00:00",
            "create_system": 3,
            "external_attr": FIXED_MODE,
            "internal_attr": 0,
            "flag_bits": 0,
            "entry_extra": "empty",
            "entry_comment": "empty",
            "archive_comment": "empty",
            "zip64": False,
        },
        "path_profile": {
            "separator": "/",
            "encoding": "ASCII",
            "casefold_collision": "reject",
            "empty_dot_dotdot_absolute_drive_backslash_nul": "reject",
        },
        "file_manifest_relation": {
            "path": "files.sha256.json",
            "lists": "every payload member except files.sha256.json and signature.json",
            "order": "ascending_ascii_path_bytes",
            "hash_domain": "raw member bytes SHA-256 uppercase",
        },
        "signature_profile": {
            "path": "signature.json",
            "algorithm": "ed25519",
            "domain": "ptcgdap-author-strategy-package-signature-v1",
            "signed_fields": [
                "schema_version",
                "domain",
                "package_id",
                "package_version",
                "manifest_sha256",
                "files_manifest_sha256",
            ],
            "canonicalization": "canonical_json_v1",
        },
        "trust_store": {
            "caller_overrides": False,
            "keys": [
                {
                    "key_id": TEST_FIXTURE_KEY_ID,
                    "algorithm": "ed25519",
                    "public_key_base64": TEST_FIXTURE_PUBLIC_KEY_BASE64,
                    "scope": "test_fixture_only",
                    "execution_trusted": False,
                }
            ],
        },
        "compatibility_anchors": {
            "minimum_game_api": "ptcgdap-author-host-v1",
            "cabt_contract_sha256": CABT_CONTRACT_SHA256,
            "card_catalog_sha256": CARD_CATALOG_SHA256,
            "base_executor_sha256": BASE_EXECUTOR_SHA256,
        },
        "policy_contract_anchors": {
            "strategic_trace_v2_bundle_canonical_sha256": "ADDD4CB48BD10FA0478854124D8E63AEE42B898C0EB81692BA35F8D7F90414C4",
            "public_deck_adapter_bundle_canonical_sha256": "C80F4C4FDAEA5AC29BD3C5617BFAC72BE38709696F7EA1995D3D153113DD3CA1",
        },
        "document_profiles": {
            "strategy_package": "strategy_package_v1",
            "deck_manifest": "deck_manifest_v1",
            "policy_ir": "ptcgdap-restricted-base-graph-ir-p4-wp2-v1",
            "adapter": "ptcgdap-public-deck-adapter-p4-wp4-v1",
            "config": "ptcgdap-author-policy-config-v1",
        },
        "error_precedence": [
            "archive",
            "path",
            "resource",
            "manifest_type",
            "file_hash",
            "signature",
            "compatibility",
            "deck_policy",
            "integrity",
        ],
        "stable_error_codes": [
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
        ],
    }


def build_vectors() -> dict[str, object]:
    rows = [
        ("valid_minimal", "build_valid_minimal", True, None),
        ("valid_manifest_whitespace_identity", "rebuild_manifest_whitespace", True, None),
        ("archive_not_zip", "replace_archive_non_zip", False, "package_archive_invalid"),
        ("archive_entry_order_drift", "reverse_entry_order", False, "package_archive_invalid"),
        ("archive_timestamp_drift", "change_entry_timestamp", False, "package_archive_invalid"),
        ("path_parent_traversal", "add_parent_traversal", False, "package_path_invalid"),
        ("path_backslash", "add_backslash_path", False, "package_path_invalid"),
        ("path_absolute", "add_absolute_path", False, "package_path_invalid"),
        ("path_drive_letter", "add_drive_path", False, "package_path_invalid"),
        ("duplicate_exact_path", "add_duplicate_exact", False, "package_duplicate_path"),
        ("duplicate_casefold_path", "add_duplicate_casefold", False, "package_duplicate_path"),
        ("resource_entry_count", "exceed_entry_count", False, "package_resource_limit_exceeded"),
        ("resource_single_file", "exceed_single_file", False, "package_resource_limit_exceeded"),
        ("resource_compression_ratio", "exceed_compression_ratio", False, "package_resource_limit_exceeded"),
        ("manifest_duplicate_key", "duplicate_manifest_key", False, "package_manifest_invalid"),
        ("manifest_bom", "prefix_manifest_bom", False, "package_manifest_invalid"),
        ("manifest_float", "set_manifest_float", False, "package_manifest_invalid"),
        ("manifest_unsafe_integer", "set_manifest_unsafe_integer", False, "package_manifest_invalid"),
        ("missing_required_file", "drop_license", False, "package_file_missing"),
        ("unlisted_extra_file", "add_unlisted_text", False, "package_file_unlisted"),
        ("payload_hash_mismatch", "tamper_payload", False, "package_file_hash_mismatch"),
        ("signature_unknown_key", "sign_unknown_key", False, "package_signature_untrusted"),
        ("signature_tampered", "tamper_signature", False, "package_signature_untrusted"),
        ("compatibility_contract_drift", "resign_contract_drift", False, "package_contract_incompatible"),
        ("compatibility_catalog_drift", "resign_catalog_drift", False, "package_catalog_incompatible"),
        ("deck_not_exact_60", "resign_deck_59", False, "package_deck_unmapped"),
        ("policy_document_invalid", "resign_policy_float", False, "package_policy_unsupported"),
        ("forbidden_python", "add_python_member", False, "package_policy_unsupported"),
        ("forbidden_native", "add_native_member", False, "package_policy_unsupported"),
        ("forbidden_nested_archive", "add_nested_archive", False, "package_policy_unsupported"),
    ]
    return {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "artifact_id": "author_strategy_package_conformance_vectors_v1",
        "cases": [
            {
                "id": case_id,
                "operation": operation,
                "expected_accepted": accepted,
                "expected_error_code": error,
            }
            for case_id, operation, accepted, error in rows
        ],
    }


def contract_documents() -> dict[str, dict[str, object]]:
    documents = {
        "schema": build_schema(),
        "profile": build_profile(),
        "vectors": build_vectors(),
    }
    bundle = {
        "schema_version": 1,
        "bundle_id": BUNDLE_ID,
        "profile_id": PROFILE_ID,
        "parent": {
            "p5_wp7_manifest_canonical_sha256": "7DFA83EAB3C1841B5336061015BF291511AFEE380F629B6F394B3B6CCBA31AC7",
            "portable_policy_bundle_canonical_sha256": "992B7F00DF412496BA414ABCC87C21C6136CB513C9C90799C897ADD18D15EDB2",
            "source_lock_canonical_sha256": "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205",
            "as_wp1_parent_snapshot_manifest_canonical_sha256": "CD384C0A81B97837085E81759D85B654565AD58145DBF3D0F99B92770FBD65AE",
        },
        "artifacts": [
            {
                "id": artifact_id,
                "path": f"contracts/ptcgdap/author_strategy_package{suffix}",
                "canonical_sha256": sha256_bytes(canonical_json_v1_bytes(documents[artifact_id])),
            }
            for artifact_id, suffix in (
                ("schema", ".schema.json"),
                ("profile", "_profile.json"),
                ("vectors", "_conformance_vectors.json"),
            )
        ],
    }
    documents["bundle"] = bundle
    return documents


def _contract_paths() -> dict[str, Path]:
    return {
        "schema": CONTRACT_ROOT / "author_strategy_package.schema.json",
        "profile": CONTRACT_ROOT / "author_strategy_package_profile.json",
        "vectors": CONTRACT_ROOT / "author_strategy_package_conformance_vectors.json",
        "bundle": CONTRACT_ROOT / "author_strategy_package_bundle.json",
    }


def write_or_check_contracts(*, check: bool) -> None:
    failures = []
    for artifact_id, document in contract_documents().items():
        expected = (json.dumps(document, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
        path = _contract_paths()[artifact_id]
        if check:
            if not path.is_file() or path.read_bytes() != expected:
                failures.append(path.relative_to(ROOT).as_posix())
        else:
            path.write_bytes(expected)
    if failures:
        raise SystemExit(f"author strategy contract drift: {failures}")


def _safe_payload_path(raw: object) -> str:
    if not isinstance(raw, str) or not raw or "\\" in raw or "\0" in raw:
        raise ValueError("unsafe package path")
    try:
        raw.encode("ascii")
    except UnicodeEncodeError as error:
        raise ValueError("package path must be ASCII") from error
    path = PurePosixPath(raw)
    if path.is_absolute() or "." in path.parts or ".." in path.parts or any(not part for part in path.parts) or ":" in path.parts[0]:
        raise ValueError("unsafe package path")
    if path.as_posix() != raw:
        raise ValueError("non-canonical package path")
    return raw


def _payload_kind(path: str) -> str:
    if path in FIXED_PAYLOAD_KINDS:
        return FIXED_PAYLOAD_KINDS[path]
    if path in OPTIONAL_PAYLOAD_KINDS:
        return OPTIONAL_PAYLOAD_KINDS[path]
    raise ValueError(f"unsupported package payload path: {path}")


def _files_manifest(payloads: Mapping[str, bytes]) -> dict[str, object]:
    return {
        "document_type": "files_sha256_v1",
        "schema_version": 1,
        "files": [
            {
                "path": path,
                "kind": _payload_kind(path),
                "bytes": len(payloads[path]),
                "sha256": _sha(payloads[path]),
            }
            for path in sorted(payloads, key=lambda value: value.encode("ascii"))
        ],
    }


def _signature_payload(manifest: dict[str, object], manifest_bytes: bytes, files_bytes: bytes) -> dict[str, object]:
    return {
        "schema_version": 1,
        "domain": "ptcgdap-author-strategy-package-signature-v1",
        "package_id": manifest["package_id"],
        "package_version": manifest["package_version"],
        "manifest_sha256": _sha(manifest_bytes),
        "files_manifest_sha256": _sha(files_bytes),
    }


def build_synthetic_fixture_payloads(*, pretty_manifest: bool = False) -> dict[str, bytes]:
    deck_csv = b"card_id,count\n7,60\n"
    manifest = {
        "document_type": "strategy_package_v1",
        "schema_version": 1,
        "package_id": "test.fixture.author-ai",
        "package_version": "1.0.0",
        "author": {"author_id": "test.fixture", "display_name": "Fixture Author"},
        "strategy": {"display_name": "Fixture Public AI", "summary": "Synthetic offline package fixture"},
        "deck": {
            "display_name": "Synthetic Exact 60",
            "manifest_path": "deck/deck_manifest.json",
            "deck_path": "deck/deck.csv",
        },
        "policy": {
            "entry_kind": "restricted_policy_ir_v1",
            "ir_path": "policy/policy_ir.json",
            "adapter_path": "policy/adapter.json",
            "config_path": "policy/config.json",
            "weights_path": None,
        },
        "compatibility": {
            "minimum_game_api": "ptcgdap-author-host-v1",
            "cabt_contract_sha256": CABT_CONTRACT_SHA256,
            "card_catalog_sha256": CARD_CATALOG_SHA256,
            "base_executor_sha256": BASE_EXECUTOR_SHA256,
            "required_capabilities": [],
        },
        "presentation": {"icon_path": None, "banner_path": None},
    }
    manifest_bytes = (
        (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
        if pretty_manifest
        else canonical_json_v1_bytes(manifest)
    )
    return {
        "strategy_package.json": manifest_bytes,
        "README.md": b"Synthetic AS-WP1 package fixture.\n",
        "LICENSE": b"Test fixture only.\n",
        "deck/deck_manifest.json": canonical_json_v1_bytes(
            {
                "document_type": "deck_manifest_v1",
                "schema_version": 1,
                "deck_id": "test.fixture.deck",
                "card_id_domain": "official_cabt_card_id",
                "card_count": 60,
                "deck_csv_sha256": _sha(deck_csv),
                "cabt_exportable": False,
            }
        ),
        "deck/deck.csv": deck_csv,
        "policy/policy_ir.json": canonical_json_v1_bytes(
            {
                "schema_version": 1,
                "profile_id": "ptcgdap-restricted-base-graph-ir-p4-wp2-v1",
                "graph_id": "test.fixture.base-minimal",
                "entry_node_id": "n00",
                "required_capabilities": [
                    "public_context",
                    "current_window",
                    "deterministic_fallback",
                    "strategic_trace_v2",
                ],
                "nodes": [
                    {"node_id": "n00", "operator": "legality_guard", "owner": "base", "config": {"frontier": "current_window"}, "next_node_ids": ["n10"]},
                    {"node_id": "n10", "operator": "mandatory_terminal_guard", "owner": "base", "config": {"mandatory_precedence": True, "terminal_precedence": True}, "next_node_ids": ["n20"]},
                    {"node_id": "n20", "operator": "hard_tier_filter", "owner": "base", "config": {"same_tier_only": True}, "next_node_ids": ["n30"]},
                    {"node_id": "n30", "operator": "base_veto", "owner": "base", "config": {"enabled": True}, "next_node_ids": ["n40"]},
                    {"node_id": "n40", "operator": "deterministic_fallback", "owner": "base", "config": {"strategy": "same_window_first_min"}, "next_node_ids": ["n50"]},
                    {"node_id": "n50", "operator": "emit_decision", "owner": "base", "config": {}, "next_node_ids": []},
                ],
            }
        ),
        "policy/adapter.json": canonical_json_v1_bytes(
            {
                "schema_version": 1,
                "adapter_id": "test.fixture.public-adapter",
                "adapter_version": 1,
                "rules": [],
            }
        ),
        "policy/config.json": canonical_json_v1_bytes(
            {
                "document_type": "author_policy_config_v1",
                "schema_version": 1,
                "config_profile_id": "ptcgdap-author-policy-config-v1",
                "values": {},
            }
        ),
    }


def build_package_bytes(payload_files: Mapping[str, bytes], private_key: bytes, *, key_id: str) -> bytes:
    if type(private_key) is not bytes or len(private_key) != 32:
        raise ValueError("Ed25519 private key must be exact 32 raw bytes")
    payloads: dict[str, bytes] = {}
    folded: set[str] = set()
    for raw_path, raw_value in payload_files.items():
        path = _safe_payload_path(raw_path)
        if path in GENERATED_PATHS or path in payloads or path.casefold() in folded:
            raise ValueError("reserved or duplicate package path")
        if type(raw_value) is not bytes:
            raise TypeError("package payload values must be exact bytes")
        _payload_kind(path)
        payloads[path] = raw_value
        folded.add(path.casefold())
    if not REQUIRED_PAYLOAD_PATHS <= set(payloads):
        raise ValueError("required package payload missing")
    manifest = load_json_bytes_strict(payloads["strategy_package.json"])
    if type(manifest) is not dict or type(manifest.get("package_id")) is not str or type(manifest.get("package_version")) is not str:
        raise ValueError("strategy package identity missing")
    files_bytes = canonical_json_v1_bytes(_files_manifest(payloads))
    signed = _signature_payload(manifest, payloads["strategy_package.json"], files_bytes)
    signed_bytes = canonical_json_v1_bytes(signed)
    signature = Ed25519PrivateKey.from_private_bytes(private_key).sign(signed_bytes)
    signature_document = {
        "document_type": "signature_v1",
        "schema_version": 1,
        "algorithm": "ed25519",
        "key_id": key_id,
        "signed_payload_sha256": _sha(signed_bytes),
        "signature_base64": base64.b64encode(signature).decode("ascii"),
    }
    members = dict(payloads)
    members["files.sha256.json"] = files_bytes
    members["signature.json"] = canonical_json_v1_bytes(signature_document)
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_STORED, allowZip64=False) as archive:
        for path in sorted(members, key=lambda value: value.encode("ascii")):
            info = zipfile.ZipInfo(path, FIXED_TIME)
            info.compress_type = zipfile.ZIP_STORED
            info.create_system = 3
            info.external_attr = FIXED_MODE
            info.internal_attr = 0
            info.flag_bits = 0
            info.extra = b""
            info.comment = b""
            archive.writestr(info, members[path])
        archive.comment = b""
    return output.getvalue()


def read_source_directory(path: Path) -> dict[str, bytes]:
    if not path.is_dir():
        raise ValueError("package source directory missing")
    result = {}
    for child in sorted(path.rglob("*")):
        if child.is_symlink():
            raise ValueError("package source symlink forbidden")
        if child.is_dir():
            continue
        relative = child.relative_to(path).as_posix()
        result[_safe_payload_path(relative)] = child.read_bytes()
    return result


def _read_private_key(path: Path) -> bytes:
    value = path.read_bytes()
    if len(value) == 32:
        return value
    try:
        text = value.decode("ascii").strip()
        decoded = bytes.fromhex(text)
    except (UnicodeDecodeError, ValueError) as error:
        raise ValueError("private key must be 32 raw bytes or 64 hex characters") from error
    if len(decoded) != 32:
        raise ValueError("private key must be 32 raw bytes or 64 hex characters")
    return decoded


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--write-contracts", action="store_true")
    group.add_argument("--check-contracts", action="store_true")
    group.add_argument("--source", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--private-key", type=Path)
    parser.add_argument("--key-id")
    args = parser.parse_args()
    if args.write_contracts or args.check_contracts:
        if args.output or args.private_key or args.key_id:
            raise SystemExit("package build arguments cannot be combined with contract generation")
        write_or_check_contracts(check=args.check_contracts)
        print("author strategy package contracts verified" if args.check_contracts else "author strategy package contracts written")
        return 0
    if not args.output or not args.private_key or not args.key_id:
        raise SystemExit("--source requires --output, --private-key and --key-id")
    archive = build_package_bytes(read_source_directory(args.source), _read_private_key(args.private_key), key_id=args.key_id)
    args.output.write_bytes(archive)
    print(f"archive_bytes={len(archive)}")
    print(f"archive_sha256={sha256_bytes(archive)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
