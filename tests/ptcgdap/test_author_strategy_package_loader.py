from __future__ import annotations

import base64
import copy
import hashlib
import io
import json
from pathlib import Path
import shutil
import tempfile
import unittest
import warnings
import zipfile

from scripts.ai.ptcgdap.author_strategy_package import (
    AuthorStrategyPackageError,
    AuthorStrategyPackageLoader,
    BASE_EXECUTOR_SHA256,
    CABT_CONTRACT_SHA256,
    CARD_CATALOG_SHA256,
    PROFILE_ID,
    TEST_FIXTURE_KEY_ID,
)
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes
from tools.ptcgdap.build_author_strategy_package import build_package_bytes, build_synthetic_fixture_payloads


ROOT = Path(__file__).resolve().parents[2]
TEST_PRIVATE_KEY = bytes(range(32))
UNKNOWN_PRIVATE_KEY = bytes(range(32, 64))
FIXED_TIME = (1980, 1, 1, 0, 0, 0)
FIXED_MODE = 0o100644 << 16


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def json_bytes(value: object, *, pretty: bool = False) -> bytes:
    if pretty:
        return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    return canonical_json_v1_bytes(value)


def base_payloads(*, pretty_manifest: bool = False) -> dict[str, bytes]:
    deck_csv = b"card_id,count\n7,60\n"
    deck_manifest = {
        "document_type": "deck_manifest_v1",
        "schema_version": 1,
        "deck_id": "test.fixture.deck",
        "card_id_domain": "official_cabt_card_id",
        "card_count": 60,
        "deck_csv_sha256": sha(deck_csv),
        "cabt_exportable": False,
    }
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
    return {
        "strategy_package.json": json_bytes(manifest, pretty=pretty_manifest),
        "README.md": b"Synthetic AS-WP1 package fixture.\n",
        "LICENSE": b"Test fixture only.\n",
        "deck/deck_manifest.json": json_bytes(deck_manifest),
        "deck/deck.csv": deck_csv,
        "policy/policy_ir.json": json_bytes(
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
        "policy/adapter.json": json_bytes(
            {
                "schema_version": 1,
                "adapter_id": "test.fixture.public-adapter",
                "adapter_version": 1,
                "rules": [],
            }
        ),
        "policy/config.json": json_bytes(
            {
                "document_type": "author_policy_config_v1",
                "schema_version": 1,
                "config_profile_id": "ptcgdap-author-policy-config-v1",
                "values": {},
            }
        ),
    }


def build(
    payloads: dict[str, bytes] | None = None,
    *,
    private_key: bytes = TEST_PRIVATE_KEY,
    key_id: str = TEST_FIXTURE_KEY_ID,
) -> bytes:
    return build_package_bytes(base_payloads() if payloads is None else payloads, private_key, key_id=key_id)


def entries(archive: bytes) -> list[tuple[zipfile.ZipInfo, bytes]]:
    with zipfile.ZipFile(io.BytesIO(archive), "r") as stream:
        return [(copy.copy(info), stream.read(info)) for info in stream.infolist()]


def rewrite(
    archive: bytes,
    *,
    add: list[tuple[str, bytes]] | None = None,
    drop: set[str] | None = None,
    mutate: dict[str, bytes] | None = None,
    reverse: bool = False,
    timestamp_drift: str | None = None,
    compression: int = zipfile.ZIP_STORED,
) -> bytes:
    values = entries(archive)
    if drop:
        values = [(info, data) for info, data in values if info.filename not in drop]
    if mutate:
        values = [(info, mutate.get(info.filename, data)) for info, data in values]
    if add:
        for name, data in add:
            info = zipfile.ZipInfo(name, FIXED_TIME)
            info.create_system = 3
            info.external_attr = FIXED_MODE
            values.append((info, data))
    if reverse:
        values.reverse()
    else:
        values.sort(key=lambda item: item[0].filename.replace("\\", "/").encode("ascii"))
    output = io.BytesIO()
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", UserWarning)
        with zipfile.ZipFile(output, "w", compression=compression, allowZip64=False) as stream:
            for info, data in values:
                info.compress_type = compression
                info.date_time = (1981, 1, 1, 0, 0, 0) if info.filename == timestamp_drift else FIXED_TIME
                info.create_system = 3
                info.external_attr = FIXED_MODE
                info.extra = b""
                info.comment = b""
                stream.writestr(info, data)
    result = output.getvalue()
    for name, _data in add or []:
        if "\\" in name:
            result = result.replace(name.replace("\\", "/").encode("ascii"), name.encode("ascii"))
    return result


class AuthorStrategyPackageLoaderTests(unittest.TestCase):
    def setUp(self) -> None:
        self.loader = AuthorStrategyPackageLoader()
        self.archive = build()

    def assert_code(self, code: str, archive: bytes, **kwargs: object) -> AuthorStrategyPackageError:
        with self.assertRaises(AuthorStrategyPackageError) as captured:
            self.loader.load_bytes(archive, **kwargs)
        self.assertEqual(code, captured.exception.code)
        self.assertEqual(code, str(captured.exception))
        return captured.exception

    def test_valid_package_rebuild_is_byte_deterministic_and_result_is_copy_only(self) -> None:
        self.assertEqual(base_payloads(), build_synthetic_fixture_payloads())
        self.assertEqual(self.archive, build())
        handle = self.loader.load_bytes(self.archive, expected_archive_sha256=sha(self.archive))
        self.assertEqual(PROFILE_ID, handle.profile_id)
        self.assertEqual("test.fixture.author-ai", handle.package_id)
        self.assertEqual("1.0.0", handle.package_version)
        self.assertEqual(sha(self.archive), handle.archive_sha256)
        self.assertEqual("test_fixture_trusted", handle.signature_status)
        self.assertFalse(handle.execution_trusted)
        first = handle.to_dict()
        first["author"]["display_name"] = "mutated"
        self.assertEqual("Fixture Author", handle.to_dict()["author"]["display_name"])
        self.assertEqual(base_payloads()["deck/deck.csv"], handle.payload_bytes("deck/deck.csv"))
        with self.assertRaises(KeyError):
            handle.payload_bytes("signature.json")

    def test_manifest_whitespace_changes_raw_and_archive_identity_not_canonical_identity(self) -> None:
        pretty_archive = build(base_payloads(pretty_manifest=True))
        canonical = self.loader.load_bytes(self.archive)
        pretty = self.loader.load_bytes(pretty_archive)
        self.assertNotEqual(canonical.archive_sha256, pretty.archive_sha256)
        self.assertNotEqual(canonical.manifest_sha256, pretty.manifest_sha256)
        self.assertEqual(canonical.manifest_canonical_sha256, pretty.manifest_canonical_sha256)

    def test_archive_identity_pin_is_strict_but_never_a_trust_override(self) -> None:
        self.assert_code("package_integrity_invalid", self.archive, expected_archive_sha256="0" * 64)
        self.assert_code("package_integrity_invalid", self.archive, expected_archive_sha256=sha(self.archive).lower())
        self.assert_code("package_archive_invalid", bytearray(self.archive))
        with self.assertRaises(TypeError):
            self.loader.load_bytes(self.archive, trusted_hash=sha(self.archive))
        with self.assertRaises(TypeError):
            AuthorStrategyPackageLoader(accept_any_key=True)

    def test_archive_path_and_metadata_fail_closed_before_payload_validation(self) -> None:
        self.assert_code("package_archive_invalid", b"not a zip")
        self.assert_code("package_archive_invalid", rewrite(self.archive, reverse=True))
        self.assert_code("package_archive_invalid", rewrite(self.archive, timestamp_drift="README.md"))
        self.assert_code("package_path_invalid", rewrite(self.archive, add=[("../escape.json", b"{}")]))
        self.assert_code("package_path_invalid", rewrite(self.archive, add=[("bad\\path.json", b"{}")]))
        self.assert_code("package_path_invalid", rewrite(self.archive, add=[("/absolute.json", b"{}")]))
        self.assert_code("package_path_invalid", rewrite(self.archive, add=[("C:/drive.json", b"{}")]))

    def test_duplicate_exact_and_casefold_paths_are_rejected(self) -> None:
        self.assert_code("package_duplicate_path", rewrite(self.archive, add=[("README.md", b"duplicate")]))
        self.assert_code("package_duplicate_path", rewrite(self.archive, add=[("readme.md", b"case collision")]))

    def test_missing_unlisted_forbidden_and_nested_members_are_rejected(self) -> None:
        self.assert_code("package_file_missing", rewrite(self.archive, drop={"LICENSE"}))
        self.assert_code("package_file_unlisted", rewrite(self.archive, add=[("notes.txt", b"extra")]))
        self.assert_code("package_policy_unsupported", rewrite(self.archive, add=[("policy/evil.py", b"pass")]))
        self.assert_code("package_policy_unsupported", rewrite(self.archive, add=[("policy/evil.dll", b"MZ")]))
        self.assert_code("package_policy_unsupported", rewrite(self.archive, add=[("policy/nested.zip", b"PK")]))

    def test_resource_limits_cover_entry_count_single_file_and_compression_ratio(self) -> None:
        extras = [(f"extra-{index:02d}.txt", b"x") for index in range(20)]
        self.assert_code("package_resource_limit_exceeded", rewrite(self.archive, add=extras))
        oversized = b"x" * (8 * 1024 * 1024 + 1)
        self.assert_code("package_resource_limit_exceeded", rewrite(self.archive, add=[("policy/weights.bin", oversized)]))
        bomb = b"x" * (1024 * 1024)
        self.assert_code(
            "package_resource_limit_exceeded",
            rewrite(self.archive, add=[("policy/weights.bin", bomb)], compression=zipfile.ZIP_DEFLATED),
        )

    def test_strict_manifest_rejects_duplicate_bom_float_and_unsafe_integer(self) -> None:
        original = base_payloads()["strategy_package.json"]
        duplicate = original.replace(b'"schema_version":1', b'"schema_version":1,"schema_version":1', 1)
        self.assert_code("package_manifest_invalid", rewrite(self.archive, mutate={"strategy_package.json": duplicate}))
        self.assert_code("package_manifest_invalid", rewrite(self.archive, mutate={"strategy_package.json": b"\xef\xbb\xbf" + original}))
        manifest = json.loads(original)
        manifest["schema_version"] = 1.0
        invalid = json.dumps(manifest, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        self.assert_code("package_manifest_invalid", rewrite(self.archive, mutate={"strategy_package.json": invalid}))
        manifest["schema_version"] = 9007199254740992
        invalid = json.dumps(manifest, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        self.assert_code("package_manifest_invalid", rewrite(self.archive, mutate={"strategy_package.json": invalid}))

    def test_all_package_documents_use_closed_shapes_and_generated_documents_are_strict(self) -> None:
        payloads = base_payloads()
        manifest = json.loads(payloads["strategy_package.json"])
        manifest["unexpected"] = True
        payloads["strategy_package.json"] = json_bytes(manifest)
        self.assert_code("package_manifest_invalid", build(payloads))
        files_data = next(data for info, data in entries(self.archive) if info.filename == "files.sha256.json")
        malformed = files_data.replace(b'"schema_version":1', b'"schema_version":1,"schema_version":1', 1)
        self.assert_code("package_manifest_invalid", rewrite(self.archive, mutate={"files.sha256.json": malformed}))
        signature_data = next(data for info, data in entries(self.archive) if info.filename == "signature.json")
        signature = json.loads(signature_data)
        signature["unexpected"] = True
        self.assert_code("package_manifest_invalid", rewrite(self.archive, mutate={"signature.json": json_bytes(signature)}))

    def test_payload_hash_and_signature_tamper_have_stable_distinct_codes(self) -> None:
        self.assert_code("package_file_hash_mismatch", rewrite(self.archive, mutate={"README.md": b"tampered\n"}))
        signature_info = next(data for info, data in entries(self.archive) if info.filename == "signature.json")
        signature = json.loads(signature_info)
        raw = bytearray(base64.b64decode(signature["signature_base64"]))
        raw[0] ^= 1
        signature["signature_base64"] = base64.b64encode(bytes(raw)).decode("ascii")
        self.assert_code("package_signature_untrusted", rewrite(self.archive, mutate={"signature.json": json_bytes(signature)}))
        self.assert_code(
            "package_signature_untrusted",
            build(base_payloads(), private_key=UNKNOWN_PRIVATE_KEY, key_id="unknown-test-key"),
        )

    def test_compatibility_is_checked_only_after_hash_and_signature(self) -> None:
        payloads = base_payloads()
        manifest = json.loads(payloads["strategy_package.json"])
        manifest["compatibility"]["cabt_contract_sha256"] = "0" * 64
        payloads["strategy_package.json"] = json_bytes(manifest)
        self.assert_code("package_contract_incompatible", build(payloads))
        payloads = base_payloads()
        manifest = json.loads(payloads["strategy_package.json"])
        manifest["compatibility"]["card_catalog_sha256"] = "0" * 64
        payloads["strategy_package.json"] = json_bytes(manifest)
        self.assert_code("package_catalog_incompatible", build(payloads))

    def test_deck_and_policy_documents_are_strict_but_do_not_claim_local_mapping(self) -> None:
        payloads = base_payloads()
        deck = json.loads(payloads["deck/deck_manifest.json"])
        deck["card_count"] = 59
        payloads["deck/deck_manifest.json"] = json_bytes(deck)
        self.assert_code("package_deck_unmapped", build(payloads))
        payloads = base_payloads()
        config = json.loads(payloads["policy/config.json"])
        config["values"]["bad"] = 1.5
        payloads["policy/config.json"] = json.dumps(config, separators=(",", ":")).encode("utf-8")
        self.assert_code("package_policy_unsupported", build(payloads))
        payloads = base_payloads()
        config = json.loads(payloads["policy/config.json"])
        config["values"]["url"] = "https://forbidden.invalid"
        payloads["policy/config.json"] = json_bytes(config)
        self.assert_code("package_policy_unsupported", build(payloads))

    def test_optional_weights_and_static_image_are_exactly_manifest_bound(self) -> None:
        png = base64.b64decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        )
        payloads = base_payloads()
        manifest = json.loads(payloads["strategy_package.json"])
        manifest["policy"]["weights_path"] = "policy/weights.bin"
        manifest["presentation"]["icon_path"] = "assets/icon.png"
        payloads["strategy_package.json"] = json_bytes(manifest)
        payloads["policy/weights.bin"] = b"bounded-static-weights"
        payloads["assets/icon.png"] = png
        handle = self.loader.load_bytes(build(payloads))
        self.assertEqual(png, handle.payload_bytes("assets/icon.png"))
        payloads = base_payloads()
        payloads["assets/icon.png"] = png
        self.assert_code("package_file_unlisted", build(payloads))
        payloads = base_payloads()
        manifest = json.loads(payloads["strategy_package.json"])
        manifest["presentation"]["icon_path"] = "assets/icon.png"
        payloads["strategy_package.json"] = json_bytes(manifest)
        payloads["assets/icon.png"] = b"not-an-image"
        self.assert_code("package_policy_unsupported", build(payloads))
        oversized_header = b"\x89PNG\r\n\x1a\n" + b"\x00\x00\x00\x0dIHDR" + (2049).to_bytes(4, "big") + (1).to_bytes(4, "big")
        payloads["assets/icon.png"] = oversized_header
        self.assert_code("package_resource_limit_exceeded", build(payloads))

    def test_unknown_required_capability_is_signed_but_unsupported(self) -> None:
        payloads = base_payloads()
        manifest = json.loads(payloads["strategy_package.json"])
        manifest["compatibility"]["required_capabilities"] = ["remote_inference"]
        payloads["strategy_package.json"] = json_bytes(manifest)
        self.assert_code("package_policy_unsupported", build(payloads))

    def test_self_consistent_contract_rewrite_cannot_rebaseline_fixed_loader_anchor(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-as-wp1-contract-") as temp:
            root = Path(temp)
            for name in (
                "author_strategy_package.schema.json",
                "author_strategy_package_profile.json",
                "author_strategy_package_conformance_vectors.json",
                "author_strategy_package_bundle.json",
            ):
                shutil.copyfile(ROOT / "contracts/ptcgdap" / name, root / name)
            profile_path = root / "author_strategy_package_profile.json"
            profile = json.loads(profile_path.read_text(encoding="utf-8"))
            profile["resource_limits"]["max_path_bytes"] += 1
            profile_path.write_text(json.dumps(profile, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            bundle_path = root / "author_strategy_package_bundle.json"
            bundle = json.loads(bundle_path.read_text(encoding="utf-8"))
            for artifact in bundle["artifacts"]:
                if artifact["id"] == "profile":
                    artifact["canonical_sha256"] = sha(canonical_json_v1_bytes(profile))
            bundle_path.write_text(json.dumps(bundle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            with self.assertRaises(AuthorStrategyPackageError) as captured:
                AuthorStrategyPackageLoader(contract_root=root)
            self.assertEqual("package_integrity_invalid", captured.exception.code)

    def test_load_path_captures_bytes_and_does_not_retain_file_handle(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-as-wp1-") as temp:
            path = Path(temp) / "fixture.ptcgai"
            path.write_bytes(self.archive)
            handle = self.loader.load_path(path)
            path.write_bytes(b"replaced after load")
            self.assertEqual(sha(self.archive), handle.archive_sha256)
            self.assertEqual(base_payloads()["README.md"], handle.payload_bytes("README.md"))


if __name__ == "__main__":
    unittest.main()
