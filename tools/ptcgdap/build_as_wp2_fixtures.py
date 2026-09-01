from __future__ import annotations

import argparse
import base64
import copy
import hashlib
import io
import json
from pathlib import Path
import sys
import warnings
import zipfile


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.author_strategy_package import (
    AuthorStrategyPackageError,
    AuthorStrategyPackageLoader,
    TEST_FIXTURE_KEY_ID,
)
from scripts.ai.ptcgdap.author_strategy_package_catalog import AuthorStrategyPackageCatalogOracle
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tools.ptcgdap.build_author_strategy_package import (
    build_package_bytes,
    build_synthetic_fixture_payloads,
)


OUTPUT_ROOT = ROOT / "tests/ptcgdap/fixtures/author_strategy_packages/as_wp2"
VECTOR_PATH = ROOT / "contracts/ptcgdap/author_strategy_package_conformance_vectors.json"
TEST_PRIVATE_KEY = bytes(range(32))
UNKNOWN_PRIVATE_KEY = bytes(range(32, 64))
FIXED_TIME = (1980, 1, 1, 0, 0, 0)
FIXED_MODE = 0o100644 << 16


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def json_bytes(value: object) -> bytes:
    return canonical_json_v1_bytes(value)


def base_payloads(*, pretty_manifest: bool = False) -> dict[str, bytes]:
    return build_synthetic_fixture_payloads(pretty_manifest=pretty_manifest)


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
    for name, data in add or []:
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


def _mutate_signed_payload(path: str, mutator) -> bytes:
    payloads = base_payloads()
    document = json.loads(payloads[path])
    mutator(document)
    payloads[path] = json_bytes(document)
    return build(payloads)


def operation_archives() -> dict[str, bytes]:
    valid = build()
    original_manifest = base_payloads()["strategy_package.json"]
    duplicate = original_manifest.replace(b'"schema_version":1', b'"schema_version":1,"schema_version":1', 1)
    float_manifest = json.loads(original_manifest)
    float_manifest["schema_version"] = 1.0
    unsafe_manifest = dict(float_manifest)
    unsafe_manifest["schema_version"] = 9007199254740992

    signature_bytes = next(data for info, data in entries(valid) if info.filename == "signature.json")
    signature = json.loads(signature_bytes)
    raw_signature = bytearray(base64.b64decode(signature["signature_base64"], validate=True))
    raw_signature[0] ^= 1
    signature["signature_base64"] = base64.b64encode(raw_signature).decode("ascii")

    deck_59 = _mutate_signed_payload("deck/deck_manifest.json", lambda value: value.__setitem__("card_count", 59))
    config_payloads = base_payloads()
    config = json.loads(config_payloads["policy/config.json"])
    config["values"]["bad"] = 1.5
    config_payloads["policy/config.json"] = json.dumps(config, separators=(",", ":")).encode("utf-8")

    png = base64.b64decode(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
    )
    optional_payloads = base_payloads()
    optional_manifest = json.loads(optional_payloads["strategy_package.json"])
    optional_manifest["policy"]["weights_path"] = "policy/weights.bin"
    optional_manifest["presentation"]["icon_path"] = "assets/icon.png"
    optional_payloads["strategy_package.json"] = json_bytes(optional_manifest)
    optional_payloads["policy/weights.bin"] = b"bounded-static-weights"
    optional_payloads["assets/icon.png"] = png

    unlisted_image_payloads = base_payloads()
    unlisted_image_payloads["assets/icon.png"] = png

    invalid_image_payloads = base_payloads()
    invalid_image_manifest = json.loads(invalid_image_payloads["strategy_package.json"])
    invalid_image_manifest["presentation"]["icon_path"] = "assets/icon.png"
    invalid_image_payloads["strategy_package.json"] = json_bytes(invalid_image_manifest)
    invalid_image_payloads["assets/icon.png"] = b"not-an-image"

    oversized_image_payloads = copy.deepcopy(invalid_image_payloads)
    oversized_image_payloads["assets/icon.png"] = (
        b"\x89PNG\r\n\x1a\n" + b"\x00\x00\x00\x0dIHDR" + (2049).to_bytes(4, "big") + (1).to_bytes(4, "big")
    )

    unknown_capability_payloads = base_payloads()
    unknown_capability_manifest = json.loads(unknown_capability_payloads["strategy_package.json"])
    unknown_capability_manifest["compatibility"]["required_capabilities"] = ["remote_inference"]
    unknown_capability_payloads["strategy_package.json"] = json_bytes(unknown_capability_manifest)

    forbidden_url_payloads = base_payloads()
    forbidden_url_config = json.loads(forbidden_url_payloads["policy/config.json"])
    forbidden_url_config["values"]["url"] = "https://forbidden.invalid"
    forbidden_url_payloads["policy/config.json"] = json_bytes(forbidden_url_config)

    nested_config_payloads = base_payloads()
    nested_config = json.loads(nested_config_payloads["policy/config.json"])
    nested_config["values"]["nested"] = {"value": 1}
    nested_config_payloads["policy/config.json"] = json_bytes(nested_config)

    duplicate_capability_payloads = base_payloads()
    duplicate_capability_ir = json.loads(duplicate_capability_payloads["policy/policy_ir.json"])
    duplicate_capability_ir["required_capabilities"][-1] = duplicate_capability_ir["required_capabilities"][0]
    duplicate_capability_payloads["policy/policy_ir.json"] = json_bytes(duplicate_capability_ir)

    missing_weight_payloads = base_payloads()
    missing_weight_manifest = json.loads(missing_weight_payloads["strategy_package.json"])
    missing_weight_manifest["policy"]["weights_path"] = "policy/weights.bin"
    missing_weight_payloads["strategy_package.json"] = json_bytes(missing_weight_manifest)

    return {
        "build_valid_minimal": valid,
        "rebuild_manifest_whitespace": build(base_payloads(pretty_manifest=True)),
        "replace_archive_non_zip": b"not a zip",
        "reverse_entry_order": rewrite(valid, reverse=True),
        "change_entry_timestamp": rewrite(valid, timestamp_drift="README.md"),
        "add_parent_traversal": rewrite(valid, add=[("../escape.json", b"{}")] ),
        "add_backslash_path": rewrite(valid, add=[("bad\\path.json", b"{}")] ),
        "add_absolute_path": rewrite(valid, add=[("/absolute.json", b"{}")] ),
        "add_drive_path": rewrite(valid, add=[("C:/drive.json", b"{}")] ),
        "add_duplicate_exact": rewrite(valid, add=[("README.md", b"duplicate")]),
        "add_duplicate_casefold": rewrite(valid, add=[("readme.md", b"case collision")]),
        "exceed_entry_count": rewrite(valid, add=[(f"extra-{index:02d}.txt", b"x") for index in range(20)]),
        "exceed_single_file": rewrite(valid, add=[("policy/weights.bin", b"x" * (8 * 1024 * 1024 + 1))]),
        "exceed_compression_ratio": rewrite(valid, add=[("policy/weights.bin", b"x" * (1024 * 1024))], compression=zipfile.ZIP_DEFLATED),
        "duplicate_manifest_key": rewrite(valid, mutate={"strategy_package.json": duplicate}),
        "prefix_manifest_bom": rewrite(valid, mutate={"strategy_package.json": b"\xef\xbb\xbf" + original_manifest}),
        "set_manifest_float": rewrite(valid, mutate={"strategy_package.json": json.dumps(float_manifest, separators=(",", ":")).encode("utf-8")}),
        "set_manifest_unsafe_integer": rewrite(valid, mutate={"strategy_package.json": json.dumps(unsafe_manifest, separators=(",", ":")).encode("utf-8")}),
        "drop_license": rewrite(valid, drop={"LICENSE"}),
        "add_unlisted_text": rewrite(valid, add=[("notes.txt", b"extra")]),
        "tamper_payload": rewrite(valid, mutate={"README.md": b"tampered\n"}),
        "sign_unknown_key": build(private_key=UNKNOWN_PRIVATE_KEY, key_id="unknown-test-key"),
        "tamper_signature": rewrite(valid, mutate={"signature.json": json_bytes(signature)}),
        "resign_contract_drift": _mutate_signed_payload("strategy_package.json", lambda value: value["compatibility"].__setitem__("cabt_contract_sha256", "0" * 64)),
        "resign_catalog_drift": _mutate_signed_payload("strategy_package.json", lambda value: value["compatibility"].__setitem__("card_catalog_sha256", "0" * 64)),
        "resign_deck_59": deck_59,
        "resign_policy_float": build(config_payloads),
        "add_python_member": rewrite(valid, add=[("policy/evil.py", b"pass")]),
        "add_native_member": rewrite(valid, add=[("policy/evil.dll", b"MZ")]),
        "add_nested_archive": rewrite(valid, add=[("policy/nested.zip", b"PK")]),
        "optional_weights_png_valid": build(optional_payloads),
        "optional_image_unlisted": build(unlisted_image_payloads),
        "optional_image_invalid": build(invalid_image_payloads),
        "optional_image_oversized": build(oversized_image_payloads),
        "unknown_required_capability": build(unknown_capability_payloads),
        "config_forbidden_url": build(forbidden_url_payloads),
        "config_nested_value": build(nested_config_payloads),
        "policy_duplicate_capability": build(duplicate_capability_payloads),
        "optional_weight_missing": build(missing_weight_payloads),
    }


def render() -> dict[str, bytes]:
    vectors = load_json_strict(VECTOR_PATH)
    operations = operation_archives()
    loader = AuthorStrategyPackageLoader()
    rendered: dict[str, bytes] = {}
    cases = []
    for index, vector in enumerate(vectors["cases"]):
        operation = vector["operation"]
        archive = operations[operation]
        filename = f"{index:02d}-{vector['id']}.ptcgai"
        expected_accepted = vector["expected_accepted"]
        expected_error = vector["expected_error_code"]
        metadata = None
        try:
            handle = loader.load_bytes(archive)
            actual_accepted = True
            actual_error = None
            metadata = handle.to_dict()
        except AuthorStrategyPackageError as error:
            actual_accepted = False
            actual_error = error.code
        if actual_accepted != expected_accepted or actual_error != expected_error:
            raise SystemExit(f"fixture expectation drift: {operation}: {actual_accepted}/{actual_error}")
        rendered[filename] = archive
        cases.append(
            {
                "case_id": vector["id"],
                "operation": operation,
                "archive_path": f"res://tests/ptcgdap/fixtures/author_strategy_packages/as_wp2/{filename}",
                "archive_bytes": len(archive),
                "archive_sha256": sha(archive),
                "expected_accepted": expected_accepted,
                "expected_error_code": expected_error,
                "expected_metadata": metadata,
            }
        )
    loader_specs = [
        ("optional_weights_png_valid", True, None),
        ("optional_image_unlisted", False, "package_file_unlisted"),
        ("optional_image_invalid", False, "package_policy_unsupported"),
        ("optional_image_oversized", False, "package_resource_limit_exceeded"),
        ("unknown_required_capability", False, "package_policy_unsupported"),
        ("config_forbidden_url", False, "package_policy_unsupported"),
        ("config_nested_value", False, "package_policy_unsupported"),
        ("policy_duplicate_capability", False, "package_policy_unsupported"),
        ("optional_weight_missing", False, "package_file_missing"),
    ]
    loader_cases = []
    for offset, (operation, expected_accepted, expected_error) in enumerate(loader_specs, start=len(cases)):
        archive = operations[operation]
        filename = f"{offset:02d}-{operation}.ptcgai"
        metadata = None
        try:
            handle = loader.load_bytes(archive)
            actual_accepted = True
            actual_error = None
            metadata = handle.to_dict()
        except AuthorStrategyPackageError as error:
            actual_accepted = False
            actual_error = error.code
        if actual_accepted != expected_accepted or actual_error != expected_error:
            raise SystemExit(f"extended fixture expectation drift: {operation}: {actual_accepted}/{actual_error}")
        rendered[filename] = archive
        loader_cases.append(
            {
                "case_id": operation,
                "archive_path": f"res://tests/ptcgdap/fixtures/author_strategy_packages/as_wp2/{filename}",
                "archive_bytes": len(archive),
                "archive_sha256": sha(archive),
                "expected_accepted": expected_accepted,
                "expected_error_code": expected_error,
                "expected_metadata": metadata,
            }
        )
    archive_by_operation = operations
    catalog_specs = [
        {
            "case_id": "empty_roots",
            "candidates": [],
        },
        {
            "case_id": "exact_duplicate_and_invalid",
            "candidates": [
                {"install_source": "built_in", "location_id": "a.ptcgai", "operation": "build_valid_minimal"},
                {"install_source": "user", "location_id": "b.ptcgai", "operation": "build_valid_minimal"},
                {"install_source": "user", "location_id": "bad.ptcgai", "operation": "tamper_payload"},
            ],
        },
        {
            "case_id": "same_identity_different_archive",
            "candidates": [
                {"install_source": "built_in", "location_id": "a.ptcgai", "operation": "build_valid_minimal"},
                {"install_source": "user", "location_id": "b.ptcgai", "operation": "rebuild_manifest_whitespace"},
            ],
        },
        {
            "case_id": "invalid_install_source",
            "candidates": [
                {"install_source": "remote", "location_id": "forbidden.ptcgai", "operation": "build_valid_minimal"},
            ],
        },
    ]
    operation_paths = {case["operation"]: case["archive_path"] for case in cases}
    oracle = AuthorStrategyPackageCatalogOracle()
    catalog_cases = []
    for spec in catalog_specs:
        oracle_candidates = [
            {
                "install_source": candidate["install_source"],
                "location_id": candidate["location_id"],
                "archive_bytes": archive_by_operation[candidate["operation"]],
            }
            for candidate in spec["candidates"]
        ]
        serialized_candidates = [
            {
                "install_source": candidate["install_source"],
                "location_id": candidate["location_id"],
                "archive_path": operation_paths[candidate["operation"]],
            }
            for candidate in spec["candidates"]
        ]
        catalog_cases.append(
            {
                "case_id": spec["case_id"],
                "candidates": serialized_candidates,
                "expected": oracle.build(oracle_candidates),
            }
        )
    manifest = {
        "schema_version": 1,
        "work_package": "AS-WP2",
        "source_vector_path": "contracts/ptcgdap/author_strategy_package_conformance_vectors.json",
        "source_vector_canonical_sha256": sha(canonical_json_v1_bytes(vectors)),
        "case_count": len(cases),
        "cases": cases,
        "loader_case_count": len(loader_cases),
        "loader_cases": loader_cases,
        "catalog_case_count": len(catalog_cases),
        "catalog_cases": catalog_cases,
    }
    rendered["cases.json"] = (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    return rendered


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    rendered = render()
    failures = []
    if not args.check:
        OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    for name, value in rendered.items():
        path = OUTPUT_ROOT / name
        if args.check:
            if not path.is_file() or path.read_bytes() != value:
                failures.append(name)
        else:
            path.write_bytes(value)
    expected = set(rendered)
    if OUTPUT_ROOT.is_dir():
        unexpected = {path.name for path in OUTPUT_ROOT.iterdir() if path.is_file()} - expected
        if unexpected:
            failures.extend(sorted(unexpected))
    if failures:
        raise SystemExit(f"AS-WP2 fixture drift: {failures}")
    print("AS-WP2 fixtures verified" if args.check else "AS-WP2 fixtures generated")
    print(f"archive_case_count={len(rendered) - 1}")
    print(f"manifest_sha256={sha(rendered['cases.json'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
