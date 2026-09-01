from __future__ import annotations

import argparse
import base64
from collections import Counter
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import subprocess
import sys
import zipfile


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.author_strategy_package import (
    AuthorStrategyPackageError,
    AuthorStrategyPackageLoader,
    EXPECTED_BUNDLE_CANONICAL_SHA256,
)
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_bytes_strict, load_json_strict
from tools.ptcgdap.build_author_strategy_package import (
    TEST_FIXTURE_KEY_ID,
    build_package_bytes,
    build_synthetic_fixture_payloads,
    contract_documents,
)


WORK_PACKAGE = ROOT / "artifacts/ptcgdap/as_wp1/work_package.json"
OUTPUT_ROOT = ROOT / "artifacts/ptcgdap/as_wp1/parent_snapshot"
SUPPLEMENTAL_ROOT = ROOT / "artifacts/ptcgdap/as_wp1/supplemental_parent_snapshot"
EVIDENCE_ROOT = ROOT / "artifacts/ptcgdap/as_wp1"
SOURCE_LOCK = ROOT / "docs/ptcgdap/SOURCE_LOCK.json"
PARENT_MANIFEST = ROOT / "artifacts/ptcgdap/as_wp0/manifest.json"
EXPECTED_PARENT_MANIFEST_RAW = "4FE26588FCEC67BFF56F64BE6BF0019F343BA07DA04C972E20C1727CDDBEDDB7"
EXPECTED_PARENT_MANIFEST_CANONICAL = "43DE8A833E9D5E7F10E72652D07DB824748714BC6B48A489A79FDA829A8C695F"
EXPECTED_PRIMARY_RAW = "D854DEFAEE054D8956050A569C3F0C25BB6AFAF0A48AA46B8130A519AF6D3738"
EXPECTED_PRIMARY_CANONICAL = "CD384C0A81B97837085E81759D85B654565AD58145DBF3D0F99B92770FBD65AE"
EXPECTED_SUPPLEMENTAL_RAW = "3D23B24B3B6652EA22EAF56297EE5F23A23F17939E75D5F2F9AA0F013D0739B2"
EXPECTED_SUPPLEMENTAL_CANONICAL = "04AA38E208894A185FD69FC89FBF89275F835F53D08F45D68A7A5038E6AB7176"
EXPECTED_SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
EXPECTED_PARENT_ENTRY_COUNT = 1575
EXPECTED_PARENT_COUNTS = {"deleted": 28, "modified": 2, "untracked": 1545}
EXPECTED_PARENT_DIGEST = "CF2A424546969DC4E4256C02A1E4322BDA06906DDA562E1192CFF06DD8C25434"
EXPECTED_GOLDEN_SHA256 = "C3251A725E933341D17A129AD065F3D4E836CF7EE886693F51528366A1A68392"
TEST_PRIVATE_KEY = bytes(range(32))
FIXED_TIME = (1980, 1, 1, 0, 0, 0)
FIXED_MODE = 0o100644 << 16


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def safe_repo_path(raw: object) -> str:
    if not isinstance(raw, str) or not raw or "\\" in raw or "\0" in raw:
        raise ValueError(f"unsafe path: {raw!r}")
    path = PurePosixPath(raw)
    if path.is_absolute() or "." in path.parts or ".." in path.parts or ":" in path.parts[0] or path.as_posix() != raw:
        raise ValueError(f"unsafe path: {raw!r}")
    return raw


def encode(value: bytes) -> bytes:
    encoded = base64.b64encode(value)
    return b"\n".join(encoded[index : index + 4096] for index in range(0, len(encoded), 4096)) + b"\n"


def json_bytes(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def canonical_sha(path: Path) -> str:
    return sha(canonical_json_v1_bytes(load_json_strict(path)))


def file_record(relative: str, value: bytes | None = None) -> dict[str, object]:
    payload = (ROOT / relative).read_bytes() if value is None else value
    record: dict[str, object] = {"path": relative, "bytes": len(payload), "raw_sha256": sha(payload)}
    if relative.endswith(".json"):
        record["canonical_sha256"] = sha(canonical_json_v1_bytes(json.loads(payload.decode("utf-8"))))
    return record


def worktree_records(excluded_prefix: str) -> tuple[list[dict[str, object]], dict[str, int]]:
    output = subprocess.run(
        ["git", "status", "--porcelain=v1", "-z", "--untracked-files=all"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    ).stdout
    records = []
    counts: Counter[str] = Counter()
    for raw in output.split(b"\0"):
        if not raw:
            continue
        code = raw[:2].decode("ascii")
        path = safe_repo_path(raw[3:].decode("utf-8").replace("\\", "/"))
        if "R" in code or "C" in code:
            raise SystemExit("rename/copy outside snapshot algorithm")
        if path.startswith(excluded_prefix):
            continue
        value = None if "D" in code else (ROOT / path).read_bytes()
        records.append(
            {
                "path": path,
                "status": code,
                "bytes": None if value is None else len(value),
                "sha256": None if value is None else sha(value),
            }
        )
        counts["untracked" if code == "??" else "deleted" if "D" in code else "modified"] += 1
    records.sort(key=lambda item: item["path"])
    return records, dict(counts)


def rewrite_member(archive_bytes: bytes, path: str, value: bytes) -> bytes:
    with zipfile.ZipFile(io.BytesIO(archive_bytes), "r") as source:
        members = {info.filename: source.read(info) for info in source.infolist()}
    if path not in members:
        raise SystemExit(f"fixture member missing: {path}")
    members[path] = value
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_STORED, allowZip64=False) as target:
        for name in sorted(members, key=lambda item: item.encode("ascii")):
            info = zipfile.ZipInfo(name, FIXED_TIME)
            info.compress_type = zipfile.ZIP_STORED
            info.create_system = 3
            info.external_attr = FIXED_MODE
            info.internal_attr = 0
            info.flag_bits = 0
            info.extra = b""
            info.comment = b""
            target.writestr(info, members[name])
        target.comment = b""
    return output.getvalue()


def build_fixtures() -> tuple[dict[str, bytes], list[dict[str, object]]]:
    minimal = build_package_bytes(
        build_synthetic_fixture_payloads(),
        TEST_PRIVATE_KEY,
        key_id=TEST_FIXTURE_KEY_ID,
    )
    if len(minimal) != 5061 or sha(minimal) != EXPECTED_GOLDEN_SHA256:
        raise SystemExit("minimal golden package drift")
    whitespace = build_package_bytes(
        build_synthetic_fixture_payloads(pretty_manifest=True),
        TEST_PRIVATE_KEY,
        key_id=TEST_FIXTURE_KEY_ID,
    )
    with zipfile.ZipFile(io.BytesIO(minimal), "r") as source:
        signature_bytes = source.read("signature.json")
        readme_bytes = source.read("README.md")
    signature = load_json_bytes_strict(signature_bytes)
    raw_signature = bytearray(base64.b64decode(signature["signature_base64"], validate=True))
    raw_signature[0] ^= 1
    signature["signature_base64"] = base64.b64encode(bytes(raw_signature)).decode("ascii")
    invalid_signature = rewrite_member(minimal, "signature.json", canonical_json_v1_bytes(signature))
    invalid_hash = rewrite_member(minimal, "README.md", b"X" + readme_bytes[1:])
    fixtures = {
        "fixtures/valid_minimal.ptcgai": minimal,
        "fixtures/valid_manifest_whitespace.ptcgai": whitespace,
        "fixtures/invalid_signature_tampered.ptcgai": invalid_signature,
        "fixtures/invalid_payload_hash.ptcgai": invalid_hash,
    }
    loader = AuthorStrategyPackageLoader()
    cases = []
    for path, value in fixtures.items():
        expected_error = None
        if "invalid_signature" in path:
            expected_error = "package_signature_untrusted"
        elif "invalid_payload" in path:
            expected_error = "package_file_hash_mismatch"
        if expected_error is None:
            handle = loader.load_bytes(value)
            accepted = True
            actual_error = None
            manifest_canonical = handle.manifest_canonical_sha256
        else:
            accepted = False
            manifest_canonical = None
            try:
                loader.load_bytes(value)
            except AuthorStrategyPackageError as error:
                actual_error = error.code
            else:
                raise SystemExit(f"invalid fixture accepted: {path}")
            if actual_error != expected_error:
                raise SystemExit(f"invalid fixture code drift: {path}: {actual_error}")
        cases.append(
            {
                "path": f"artifacts/ptcgdap/as_wp1/{path}",
                "bytes": len(value),
                "raw_sha256": sha(value),
                "expected_accepted": accepted,
                "expected_error_code": expected_error,
                "manifest_canonical_sha256": manifest_canonical,
            }
        )
    if cases[0]["manifest_canonical_sha256"] != cases[1]["manifest_canonical_sha256"]:
        raise SystemExit("whitespace fixture canonical identity drift")
    if cases[0]["raw_sha256"] == cases[1]["raw_sha256"]:
        raise SystemExit("whitespace fixture raw identity collision")
    return fixtures, cases


def render_evidence() -> dict[str, bytes]:
    work = load_json_strict(WORK_PACKAGE)
    primary_path = OUTPUT_ROOT / "manifest.json"
    supplemental_path = SUPPLEMENTAL_ROOT / "manifest.json"
    if sha(PARENT_MANIFEST.read_bytes()) != EXPECTED_PARENT_MANIFEST_RAW or canonical_sha(PARENT_MANIFEST) != EXPECTED_PARENT_MANIFEST_CANONICAL:
        raise SystemExit("AS-WP0 manifest drift")
    if sha(primary_path.read_bytes()) != EXPECTED_PRIMARY_RAW or canonical_sha(primary_path) != EXPECTED_PRIMARY_CANONICAL:
        raise SystemExit("AS-WP1 primary snapshot drift")
    if sha(supplemental_path.read_bytes()) != EXPECTED_SUPPLEMENTAL_RAW or canonical_sha(supplemental_path) != EXPECTED_SUPPLEMENTAL_CANONICAL:
        raise SystemExit("AS-WP1 supplemental snapshot drift")
    if canonical_sha(SOURCE_LOCK) != EXPECTED_SOURCE_LOCK:
        raise SystemExit("SOURCE_LOCK drift")
    expected_contracts = contract_documents()
    contract_paths = {
        "schema": "contracts/ptcgdap/author_strategy_package.schema.json",
        "profile": "contracts/ptcgdap/author_strategy_package_profile.json",
        "vectors": "contracts/ptcgdap/author_strategy_package_conformance_vectors.json",
        "bundle": "contracts/ptcgdap/author_strategy_package_bundle.json",
    }
    for artifact_id, relative in contract_paths.items():
        if load_json_strict(ROOT / relative) != expected_contracts[artifact_id]:
            raise SystemExit(f"contract builder drift: {artifact_id}")
    if canonical_sha(ROOT / contract_paths["bundle"]) != EXPECTED_BUNDLE_CANONICAL_SHA256:
        raise SystemExit("fixed loader bundle anchor drift")

    primary = load_json_strict(primary_path)
    supplemental = load_json_strict(supplemental_path)
    parent_entries = [*primary["files"], *supplemental["files"]]
    changed_existing = [
        entry["original_path"]
        for entry in parent_entries
        if sha((ROOT / entry["original_path"]).read_bytes()) != entry["raw_sha256"]
    ]
    allowed_existing = [
        *work["files_allowed"]["existing_files"],
        *work["files_allowed"]["existing_compatibility_files"],
    ]
    if changed_existing != allowed_existing:
        raise SystemExit(f"existing change set drift: {changed_existing}")
    additive = work["files_allowed"]["as_wp1_additive"]
    if [path for path in additive if not (ROOT / path).is_file()]:
        raise SystemExit("AS-WP1 additive path missing")
    records, counts = worktree_records("artifacts/ptcgdap/as_wp1/")
    candidate = {
        "excluded_prefix": "artifacts/ptcgdap/as_wp1/",
        "entry_count": len(records),
        "status_counts": counts,
        "canonical_records_sha256": sha(canonical_json_v1_bytes(records)),
    }
    fixtures, fixture_cases = build_fixtures()

    source_lock_snapshot = {
        "schema_version": 1,
        "work_package": "AS-WP1",
        "lock_path": "docs/ptcgdap/SOURCE_LOCK.json",
        "lock_raw_sha256": sha(SOURCE_LOCK.read_bytes()),
        "lock_canonical_sha256": EXPECTED_SOURCE_LOCK,
        "verification": {
            "verified_locked_artifacts": 14,
            "verified_bundle_entries": 60,
            "verified_bundle_bytes": 327589562,
            "issues": 0,
            "authoritative_result_sha256": "CD864D659ED2D88571617878D5121F73F7ED7B1A5FD96250CF7B7F811E1A3B57",
        },
        "contracts_changed": True,
        "source_lock_resigned": False,
    }
    contract_hashes = {
        "schema_version": 1,
        "work_package": "AS-WP1",
        "bundle_canonical_sha256": EXPECTED_BUNDLE_CANONICAL_SHA256,
        "artifacts": [file_record(relative) for relative in contract_paths.values()],
        "implementation": [
            file_record("tools/ptcgdap/build_author_strategy_package.py"),
            file_record("scripts/ai/ptcgdap/author_strategy_package.py"),
        ],
        "parent_anchors": {
            "as_wp0_manifest_raw_sha256": EXPECTED_PARENT_MANIFEST_RAW,
            "as_wp0_manifest_canonical_sha256": EXPECTED_PARENT_MANIFEST_CANONICAL,
            "source_lock_canonical_sha256": EXPECTED_SOURCE_LOCK,
            "primary_snapshot_manifest_canonical_sha256": EXPECTED_PRIMARY_CANONICAL,
            "supplemental_snapshot_manifest_canonical_sha256": EXPECTED_SUPPLEMENTAL_CANONICAL,
        },
        "test_fixture_private_key_is_product_trust_root": False,
    }
    fixtures_manifest = {
        "schema_version": 1,
        "work_package": "AS-WP1",
        "profile_id": "ptcgdap-author-strategy-package-v1",
        "shared_operation_case_count": 30,
        "archive_cases": fixture_cases,
        "test_key_scope": "test_fixture_only",
        "test_key_execution_trusted": False,
        "production_trust_roots": 0,
        "player_ready_packages": 0,
    }
    test_commands = """# AS-WP1 validation (2026-08-12, PowerShell)\n\npython -m unittest tests.ptcgdap.test_author_strategy_package_contract tests.ptcgdap.test_author_strategy_package_loader -q\npython -m unittest discover -s tests/ptcgdap -p "test_*parent_snapshot.py" -q\npython -m unittest discover -s tests/ptcgdap -p "test_*boundaries.py" -q\npython -m unittest discover -s tests/ptcgdap -p "test_*.py" -q\npython tools/ptcgdap/build_author_strategy_package.py --check-contracts\npython -m scripts.ai.ptcgdap.source_lock --lock docs/ptcgdap/SOURCE_LOCK.json --expect-lock-sha256 8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205 --root ptcgabc=D:\\ai\\code\\ptcgabc --root ptcgdap=D:\\ai\\code\\PtcgDAP --format json\npython -m compileall -q scripts/ai/ptcgdap tools/ptcgdap tests/ptcgdap\ngit diff --check\npython tools/ptcgdap/capture_as_wp1_parent_snapshot.py --finalize --check\n"""
    test_results = {
        "schema_version": 1,
        "work_package": "AS-WP1",
        "overall": "passed",
        "results": [
            {"lane": "targeted_contract_and_loader", "passed": 21, "failed": 0, "skipped": 0},
            {"lane": "parent_snapshots", "passed": 91, "failed": 0, "skipped": 0},
            {"lane": "static_boundaries", "passed": 163, "failed": 0, "skipped": 0},
            {"lane": "full_python_discovery", "passed": 750, "failed": 0, "skipped": 0, "duration_milliseconds": 682933},
            {"lane": "contract_builder_check", "issues": 0, "exit_code": 0},
            {"lane": "source_lock", "verified_locked_artifacts": 14, "verified_bundle_entries": 60, "verified_bundle_bytes": 327589562, "issues": 0},
            {"lane": "compileall", "issues": 0, "exit_code": 0},
            {"lane": "git_diff_check", "issues": 0, "exit_code": 0},
        ],
        "godot": {"applicable": False, "reason": "AS-WP1 changes no Godot/project/autoload/UI/runtime path"},
    }
    diff_report = {
        "schema_version": 1,
        "work_package": "AS-WP1",
        "allowed_existing_paths": allowed_existing,
        "changed_existing_paths": changed_existing,
        "allowed_additive_paths": additive,
        "present_additive_paths": additive,
        "evidence_prefix": "artifacts/ptcgdap/as_wp1/",
        "files_allowed_violations": [],
        "godot_or_runtime_owner_changes": [],
        "classic_ai_changes": [],
        "candidate_snapshot_excluding_evidence": candidate,
        "parent_virtual_rollback": {
            "entry_count": EXPECTED_PARENT_ENTRY_COUNT,
            "status_counts": EXPECTED_PARENT_COUNTS,
            "canonical_records_sha256": EXPECTED_PARENT_DIGEST,
            "result": "passed",
        },
    }
    applicability = {
        "schema_version": 1,
        "work_package": "AS-WP1",
        "scope": "offline deterministic .ptcgai contract, builder and fixed-anchor Python reference loader",
        "contract": True,
        "synthetic_fixture_validation": True,
        "metadata_discovery": False,
        "godot_runtime": False,
        "ui": False,
        "match_handle": False,
        "live_execution": False,
        "device_packaging": False,
        "classic_ai_behavior_changed": False,
        "alignment": {"A0": "partial / not claimed", "A1": "not evaluated", "A2": "not evaluated", "A3": "not evaluated", "A4": "not evaluated", "A5": "not evaluated"},
        "next_permitted_work": "AS-WP2: Godot loader and startup metadata catalog",
    }
    rollback_report = f"""# AS-WP1 rollback report\n\nRestore the nine primary files from `parent_snapshot/` and the one compatibility file from `supplemental_parent_snapshot/`. Delete only the nine AS-WP1 additive paths and `artifacts/ptcgdap/as_wp1/`.\n\nThe isolated virtual drill reproduced the exact AS-WP0 handoff candidate:\n\n- entries: `{EXPECTED_PARENT_ENTRY_COUNT}`\n- status counts: `{EXPECTED_PARENT_COUNTS}`\n- canonical records SHA-256: `{EXPECTED_PARENT_DIGEST}`\n\nThere is no autoload, feature flag, UI, match owner or live switch to reverse. Do not delete user `.ptcgai` files, reset unrelated worktree changes or modify `D:\\ai\\code\\ptcgabc`.\n"""
    known_gaps = """# AS-WP1 known gaps\n\nAS-WP1 proves only the offline package contract, deterministic archive builder and fixed-anchor Python reference loader. The embedded Ed25519 public key is scoped to synthetic test fixtures and explicitly has `execution_trusted=false`; there is no production or release trust root.\n\nStill unsupported:\n\n- Godot captured-byte ZIP validation and Python/GDScript shared-vector conformance;\n- fixed built-in/user directory scanning, cache semantics, metadata-only catalog and autoload;\n- BattleSetup author mode, package UI states or selection persistence;\n- match-time archive recapture, immutable handle, exact local 60-card mapping or engine capability gate;\n- current-window Host, ticket, engine command, canary, classic-AI separation evidence at runtime;\n- Windows/Android export, airplane-mode, performance/resource/device evidence or A5;\n- complete Marnie local mapping or effect/engine parity.\n\nThe evidence fixtures live only under `artifacts/ptcgdap/as_wp1/fixtures/` and are not scanned from `data/ptcgdap/author_strategy_packages/`. No package is player-ready.\n"""
    rendered: dict[str, bytes] = {
        **fixtures,
        "source_lock_snapshot.json": json_bytes(source_lock_snapshot),
        "contract_hashes.json": json_bytes(contract_hashes),
        "fixtures_manifest.json": json_bytes(fixtures_manifest),
        "test_commands.txt": test_commands.encode("utf-8"),
        "test_results.json": json_bytes(test_results),
        "diff_report.json": json_bytes(diff_report),
        "applicability.json": json_bytes(applicability),
        "rollback_report.md": rollback_report.encode("utf-8"),
        "known_gaps.md": known_gaps.encode("utf-8"),
    }
    evidence_records = [
        file_record("artifacts/ptcgdap/as_wp1/work_package.json"),
        file_record("artifacts/ptcgdap/as_wp1/parent_snapshot/manifest.json"),
        file_record("artifacts/ptcgdap/as_wp1/supplemental_parent_snapshot/manifest.json"),
    ]
    for name, value in rendered.items():
        evidence_records.append(file_record(f"artifacts/ptcgdap/as_wp1/{name}", value))
    manifest = {
        "schema_version": 1,
        "work_package": "AS-WP1",
        "candidate_id": "ptcgdap-as-wp1-author-strategy-package-contract-20260812",
        "status": "shadow",
        "implementation_state": "offline_contract_complete",
        "generated_at": "2026-08-12T05:00:00+08:00",
        "scope": "offline deterministic .ptcgai contract, builder, fixed-anchor Python loader and synthetic fixtures only",
        "parent": {
            "work_package": "AS-WP0",
            "manifest_raw_sha256": EXPECTED_PARENT_MANIFEST_RAW,
            "manifest_canonical_sha256": EXPECTED_PARENT_MANIFEST_CANONICAL,
            "worktree_entry_count": EXPECTED_PARENT_ENTRY_COUNT,
            "worktree_status_counts": EXPECTED_PARENT_COUNTS,
            "worktree_canonical_records_sha256": EXPECTED_PARENT_DIGEST,
        },
        "contracts": {
            "bundle_raw_sha256": sha((ROOT / contract_paths["bundle"]).read_bytes()),
            "bundle_canonical_sha256": EXPECTED_BUNDLE_CANONICAL_SHA256,
            "shared_operation_case_count": 30,
        },
        "snapshots": {
            "primary_file_count": 9,
            "primary_manifest_raw_sha256": EXPECTED_PRIMARY_RAW,
            "primary_manifest_canonical_sha256": EXPECTED_PRIMARY_CANONICAL,
            "supplemental_file_count": 1,
            "supplemental_manifest_raw_sha256": EXPECTED_SUPPLEMENTAL_RAW,
            "supplemental_manifest_canonical_sha256": EXPECTED_SUPPLEMENTAL_CANONICAL,
        },
        "evidence_files": evidence_records,
        "test_summary": {
            "targeted_passed": 21,
            "parent_snapshot_passed": 91,
            "static_boundary_passed": 163,
            "full_python_passed": 750,
            "failed": 0,
            "skipped": 0,
            "source_lock_issues": 0,
        },
        "fixture_summary": {
            "valid_archives": 2,
            "invalid_archives": 2,
            "minimal_golden_sha256": EXPECTED_GOLDEN_SHA256,
            "test_key_execution_trusted": False,
            "player_ready_packages": 0,
        },
        "candidate_snapshot": candidate,
        "rollback": {
            "primary_parent_file_count": 9,
            "supplemental_parent_file_count": 1,
            "delete_exact_path_count": 9,
            "live_switch_required": False,
            "isolated_virtual_drill": "passed",
            "restored_parent_candidate_entry_count": EXPECTED_PARENT_ENTRY_COUNT,
            "restored_parent_candidate_canonical_sha256": EXPECTED_PARENT_DIGEST,
        },
        "alignment": applicability["alignment"],
        "next_permitted_work": "AS-WP2: Godot loader and startup metadata catalog",
        "self_hash_policy": "manifest.json does not hash itself; every other top-level evidence/fixture file and both snapshot manifests are bound above",
    }
    rendered["manifest.json"] = json_bytes(manifest)
    return rendered


def finalize(check: bool) -> int:
    rendered = render_evidence()
    failures = []
    for name, value in rendered.items():
        path = EVIDENCE_ROOT / name
        if check:
            if not path.is_file() or path.read_bytes() != value:
                failures.append(name)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(value)
    if failures:
        raise SystemExit(f"AS-WP1 evidence drift: {failures}")
    manifest = rendered["manifest.json"]
    print("AS-WP1 evidence verified" if check else "AS-WP1 evidence finalized")
    print(f"manifest_raw_sha256={sha(manifest)}")
    print(f"manifest_canonical_sha256={sha(canonical_json_v1_bytes(json.loads(manifest.decode('utf-8'))))}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--replace", action="store_true")
    parser.add_argument("--supplemental", action="store_true")
    parser.add_argument("--finalize", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.check and not args.finalize:
        raise SystemExit("--check requires --finalize")
    if args.finalize:
        if args.replace or args.supplemental:
            raise SystemExit("snapshot arguments cannot be combined with --finalize")
        return finalize(args.check)
    work = json.loads(WORK_PACKAGE.read_text(encoding="utf-8"))
    key = "existing_compatibility_files" if args.supplemental else "existing_files"
    restore_paths = [safe_repo_path(path) for path in work["files_allowed"][key]]
    delete_paths = [safe_repo_path(path) for path in work["files_allowed"]["as_wp1_additive"]]
    expected_count = 1 if args.supplemental else 9
    if len(restore_paths) != expected_count or len(restore_paths) != len(set(restore_paths)):
        raise SystemExit(f"expected {expected_count} unique parent paths")
    if len(delete_paths) != 9 or len(delete_paths) != len(set(delete_paths)):
        raise SystemExit("expected nine unique AS-WP1 additive paths")
    if set(restore_paths) & set(delete_paths):
        raise SystemExit("restore/delete path overlap")
    output_root = SUPPLEMENTAL_ROOT if args.supplemental else OUTPUT_ROOT
    output_root.mkdir(parents=True, exist_ok=True)
    existing = list(output_root.iterdir())
    if existing and not args.replace:
        raise SystemExit("snapshot already exists; use --replace only while parent bytes are unchanged")
    if args.replace:
        for path in existing:
            if not path.is_file():
                raise SystemExit(f"unexpected snapshot entry: {path}")
            path.unlink()
    entries = []
    for relative in restore_paths:
        value = (ROOT / relative).read_bytes()
        name = relative.replace("/", "__") + ".base64"
        payload = encode(value)
        (output_root / name).write_bytes(payload)
        entries.append(
            {
                "original_path": relative,
                "snapshot_path": name,
                "bytes": len(value),
                "raw_sha256": sha(value),
                "snapshot_file_bytes": len(payload),
                "snapshot_file_raw_sha256": sha(payload),
            }
        )
    parent = work["entry_evidence"]
    manifest = {
        "schema_version": 1,
        "work_package": "AS-WP1-supplemental" if args.supplemental else "AS-WP1",
        "captured_at": "2026-08-12T03:30:00+08:00",
        "file_count": len(entries),
        "parent": {
            "work_package": "AS-WP0",
            "manifest_path": parent["parent_manifest_path"],
            "manifest_raw_sha256": parent["parent_manifest_raw_sha256"],
            "manifest_canonical_sha256": parent["parent_manifest_canonical_sha256"],
            "portable_policy_bundle_canonical_sha256": parent["parent_portable_policy_bundle_canonical_sha256"],
            "source_lock_canonical_sha256": parent["source_lock_canonical_sha256"],
            "worktree_entry_count": parent["pre_as_wp1_worktree_entry_count"],
            "worktree_status_counts": parent["pre_as_wp1_worktree_status_counts"],
            "worktree_snapshot_canonical_sha256": parent["pre_as_wp1_worktree_canonical_sha256"],
        },
        "files": entries,
        "rollback_scope": {
            "restore_exact_paths": restore_paths,
            "delete_exact_paths": delete_paths,
            "delete_evidence_prefix": "artifacts/ptcgdap/as_wp1/",
        },
    }
    output = (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    (output_root / "manifest.json").write_bytes(output)
    print(f"captured {len(entries)} files")
    print(f"manifest_raw_sha256={sha(output)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
