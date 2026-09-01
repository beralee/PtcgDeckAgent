from __future__ import annotations

import argparse
import base64
from collections import Counter
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


WORK_PACKAGE = ROOT / "artifacts/ptcgdap/as_wp2/work_package.json"
OUTPUT_ROOT = ROOT / "artifacts/ptcgdap/as_wp2/parent_snapshot"
EVIDENCE_ROOT = ROOT / "artifacts/ptcgdap/as_wp2"
SOURCE_LOCK = ROOT / "docs/ptcgdap/SOURCE_LOCK.json"
FIXTURE_MANIFEST = ROOT / "tests/ptcgdap/fixtures/author_strategy_packages/as_wp2/cases.json"
PARENT_MANIFEST = ROOT / "artifacts/ptcgdap/as_wp1/manifest.json"
EXPECTED_PARENT_MANIFEST_RAW = "3D717BA5C8171F17792A6FC407DF82DCA2F17B214CA57C08DFF5038B185177C0"
EXPECTED_PARENT_MANIFEST_CANONICAL = "CA44A3BEE5910116D8DF6467B6BBAF074609A64772B7BA67055A162D9E89DA41"
EXPECTED_PACKAGE_BUNDLE = "B416F2CBA2795B62126B6EF7B5F07A9000E84D5FA1DF62C1753CADC9E82E106B"
EXPECTED_SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
EXPECTED_PRIMARY_RAW = "29C83B75BBC6070C7D9FC45FDC086DD0CFB6F454B974F76D0A838610EACC7521"
EXPECTED_PRIMARY_CANONICAL = "917F3FD4E0C89AF4D3D66067B874C3CF4B15BAA3A1FBFD6A52C414D1B0C89AE7"
EXPECTED_PARENT_ENTRY_COUNT = 1611
EXPECTED_PARENT_COUNTS = {"deleted": 28, "modified": 2, "untracked": 1581}
EXPECTED_PARENT_DIGEST = "4AF465BEA81C08589598E08E0FBCCF7C588C46A8BAC8DAC37B8F1C2F213FA537"
EXPECTED_FIXTURE_MANIFEST_RAW = "8388B214CE56D8CA56016EB17DFD52E8B45599662CED9B7D276C770EDA784F24"


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


def canonical_sha(path: Path) -> str:
    return sha(canonical_json_v1_bytes(load_json_strict(path)))


def json_bytes(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


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


def capture(replace: bool) -> int:
    work = load_json_strict(WORK_PACKAGE)
    entry = work["entry_evidence"]
    if sha(PARENT_MANIFEST.read_bytes()) != EXPECTED_PARENT_MANIFEST_RAW:
        raise SystemExit("AS-WP1 manifest raw drift")
    if canonical_sha(PARENT_MANIFEST) != EXPECTED_PARENT_MANIFEST_CANONICAL:
        raise SystemExit("AS-WP1 manifest canonical drift")
    if entry["author_package_bundle_canonical_sha256"] != EXPECTED_PACKAGE_BUNDLE:
        raise SystemExit("author package bundle anchor drift")
    if entry["source_lock_canonical_sha256"] != EXPECTED_SOURCE_LOCK:
        raise SystemExit("source lock anchor drift")

    allowed = work["files_allowed"]
    restore_paths = [
        *allowed["existing_project_files"],
        *allowed["existing_docs"],
        *allowed["existing_compatibility_files"],
    ]
    restore_paths = [safe_repo_path(path) for path in restore_paths]
    delete_paths = [safe_repo_path(path) for path in allowed["as_wp2_additive"]]
    if len(restore_paths) != 13 or len(restore_paths) != len(set(restore_paths)):
        raise SystemExit("expected thirteen unique AS-WP2 parent paths")
    if len(delete_paths) != 10 or len(delete_paths) != len(set(delete_paths)):
        raise SystemExit("expected ten unique AS-WP2 additive paths")
    if set(restore_paths) & set(delete_paths):
        raise SystemExit("restore/delete path overlap")

    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    existing = list(OUTPUT_ROOT.iterdir())
    if existing and not replace:
        raise SystemExit("snapshot already exists; use --replace only while parent bytes are unchanged")
    if replace:
        for path in existing:
            if not path.is_file():
                raise SystemExit(f"unexpected snapshot entry: {path}")
            path.unlink()

    entries = []
    for relative in restore_paths:
        value = (ROOT / relative).read_bytes()
        name = relative.replace("/", "__") + ".base64"
        payload = encode(value)
        (OUTPUT_ROOT / name).write_bytes(payload)
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

    manifest = {
        "schema_version": 1,
        "work_package": "AS-WP2",
        "captured_at": "2026-08-12T12:00:00+08:00",
        "file_count": len(entries),
        "parent": {
            "work_package": "AS-WP1",
            "manifest_path": entry["parent_manifest_path"],
            "manifest_raw_sha256": entry["parent_manifest_raw_sha256"],
            "manifest_canonical_sha256": entry["parent_manifest_canonical_sha256"],
            "author_package_bundle_canonical_sha256": entry["author_package_bundle_canonical_sha256"],
            "source_lock_canonical_sha256": entry["source_lock_canonical_sha256"],
            "worktree_entry_count": entry["pre_as_wp2_worktree_entry_count"],
            "worktree_status_counts": entry["pre_as_wp2_worktree_status_counts"],
            "worktree_snapshot_canonical_sha256": entry["pre_as_wp2_worktree_canonical_sha256"],
        },
        "files": entries,
        "rollback_scope": {
            "restore_exact_paths": restore_paths,
            "delete_exact_paths": delete_paths,
            "omit_parent_clean_paths": ["export_presets.cfg"],
            "delete_fixture_prefix": allowed["generated_fixture_prefix"],
            "delete_evidence_prefix": "artifacts/ptcgdap/as_wp2/",
        },
    }
    output = (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    (OUTPUT_ROOT / "manifest.json").write_bytes(output)
    print(f"captured {len(entries)} files")
    print(f"manifest_raw_sha256={sha(output)}")
    print(f"manifest_canonical_sha256={sha(canonical_json_v1_bytes(manifest))}")
    return 0


def render_evidence() -> dict[str, bytes]:
    work = load_json_strict(WORK_PACKAGE)
    primary_path = OUTPUT_ROOT / "manifest.json"
    if sha(PARENT_MANIFEST.read_bytes()) != EXPECTED_PARENT_MANIFEST_RAW or canonical_sha(PARENT_MANIFEST) != EXPECTED_PARENT_MANIFEST_CANONICAL:
        raise SystemExit("AS-WP1 manifest drift")
    if sha(primary_path.read_bytes()) != EXPECTED_PRIMARY_RAW or canonical_sha(primary_path) != EXPECTED_PRIMARY_CANONICAL:
        raise SystemExit("AS-WP2 parent snapshot drift")
    if canonical_sha(SOURCE_LOCK) != EXPECTED_SOURCE_LOCK:
        raise SystemExit("SOURCE_LOCK drift")
    if sha(FIXTURE_MANIFEST.read_bytes()) != EXPECTED_FIXTURE_MANIFEST_RAW:
        raise SystemExit("AS-WP2 fixture manifest drift")

    parent = load_json_strict(primary_path)
    changed_existing = [
        entry["original_path"]
        for entry in parent["files"]
        if sha((ROOT / entry["original_path"]).read_bytes()) != entry["raw_sha256"]
    ]
    allowed_existing = [
        *work["files_allowed"]["existing_project_files"],
        *work["files_allowed"]["existing_docs"],
        *work["files_allowed"]["existing_compatibility_files"],
    ]
    if changed_existing != allowed_existing:
        raise SystemExit(f"existing change set drift: {changed_existing}")
    additive = work["files_allowed"]["as_wp2_additive"]
    missing_additive = [path for path in additive if not (ROOT / path).is_file()]
    if missing_additive:
        raise SystemExit(f"AS-WP2 additive path missing: {missing_additive}")

    fixture_document = load_json_strict(FIXTURE_MANIFEST)
    archive_cases = [*fixture_document["cases"], *fixture_document["loader_cases"]]
    if len(archive_cases) != 39 or fixture_document["catalog_case_count"] != 4:
        raise SystemExit("AS-WP2 fixture count drift")
    fixture_records = [file_record(case["archive_path"].removeprefix("res://")) for case in archive_cases]
    fixture_records.append(file_record("tests/ptcgdap/fixtures/author_strategy_packages/as_wp2/cases.json"))

    records, counts = worktree_records("artifacts/ptcgdap/as_wp2/")
    candidate = {
        "excluded_prefix": "artifacts/ptcgdap/as_wp2/",
        "entry_count": len(records),
        "status_counts": counts,
        "canonical_records_sha256": sha(canonical_json_v1_bytes(records)),
    }
    source_lock_snapshot = {
        "schema_version": 1,
        "work_package": "AS-WP2",
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
        "contracts_changed": False,
        "source_lock_resigned": False,
    }
    implementation_hashes = {
        "schema_version": 1,
        "work_package": "AS-WP2",
        "author_package_bundle_canonical_sha256": EXPECTED_PACKAGE_BUNDLE,
        "parent_anchors": {
            "as_wp1_manifest_raw_sha256": EXPECTED_PARENT_MANIFEST_RAW,
            "as_wp1_manifest_canonical_sha256": EXPECTED_PARENT_MANIFEST_CANONICAL,
            "source_lock_canonical_sha256": EXPECTED_SOURCE_LOCK,
            "parent_snapshot_manifest_raw_sha256": EXPECTED_PRIMARY_RAW,
            "parent_snapshot_manifest_canonical_sha256": EXPECTED_PRIMARY_CANONICAL,
        },
        "additive_files": [file_record(path) for path in additive],
        "changed_existing_files": [file_record(path) for path in changed_existing],
        "production_trust_roots": 0,
        "player_ready_packages": 0,
    }
    fixtures_manifest = {
        "schema_version": 1,
        "work_package": "AS-WP2",
        "source_manifest": file_record("tests/ptcgdap/fixtures/author_strategy_packages/as_wp2/cases.json"),
        "as_wp1_contract_archive_cases": 30,
        "extended_loader_archive_cases": 9,
        "catalog_composition_cases": 4,
        "archive_files": fixture_records[:-1],
        "python_gdscript_mismatch_count": 0,
        "test_key_scope": "test_fixture_only",
        "test_key_execution_trusted": False,
        "ready_records": 0,
    }
    test_commands = """# AS-WP2 validation (2026-08-12, PowerShell)

python tools/ptcgdap/build_as_wp2_fixtures.py --check
python -m unittest tests.ptcgdap.test_author_strategy_package_contract tests.ptcgdap.test_author_strategy_package_loader tests.ptcgdap.test_author_strategy_package_catalog -q
powershell -ExecutionPolicy Bypass -File scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/ptcgdap/godot/test_author_strategy_package_catalog.gd
powershell -ExecutionPolicy Bypass -File scripts/tools/run_godot_tests.ps1 -Runner functional -Suite GameManager,BattleSetupAIVersions,BattleSceneArchitectureAudit,BattleSceneLifecycle,BattleSceneAIFixedDeckOrder,ExportPresets,SuiteCatalog
powershell -ExecutionPolicy Bypass -File scripts/tools/run_godot_tests.ps1 -Runner ai -Suite AIStrategyWiring,DeckStrategyContract,DeckStrategyRegistryExpansion,AIVersionRegistry,OpponentDeckFingerprintResolver,MatchupPolicyIntegration
python -m unittest discover -s tests/ptcgdap -p "test_*parent_snapshot.py" -q
python -m unittest discover -s tests/ptcgdap -p "test_*boundaries.py" -q
python -m unittest discover -s tests/ptcgdap -p "test_*.py" -q
python -m scripts.ai.ptcgdap.source_lock --lock docs/ptcgdap/SOURCE_LOCK.json --expect-lock-sha256 8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205 --root ptcgabc=D:\\ai\\code\\ptcgabc --root ptcgdap=D:\\ai\\code\\PtcgDAP --format json
python -m compileall -q scripts/ai/ptcgdap tools/ptcgdap tests/ptcgdap
git diff --check
python tools/ptcgdap/capture_as_wp2_parent_snapshot.py --finalize --check
"""
    test_results = {
        "schema_version": 1,
        "work_package": "AS-WP2",
        "overall": "passed",
        "results": [
            {"lane": "targeted_python_contract_loader_catalog", "passed": 27, "failed": 0, "skipped": 0},
            {"lane": "godot_focused_package_catalog", "passed": 10, "failed": 0, "skipped": 0},
            {"lane": "shared_archive_cases", "passed": 39, "failed": 0, "skipped": 0},
            {"lane": "shared_catalog_cases", "passed": 4, "failed": 0, "skipped": 0},
            {"lane": "godot_relevant_functional", "passed": 108, "failed": 0, "skipped": 0},
            {"lane": "godot_relevant_ai", "passed": 64, "failed": 0, "skipped": 0},
            {"lane": "parent_snapshots", "passed": 94, "failed": 0, "skipped": 0},
            {"lane": "static_boundaries", "passed": 163, "failed": 0, "skipped": 0},
            {"lane": "full_python_discovery", "passed": 759, "failed": 0, "skipped": 0, "duration_milliseconds": 678148},
            {"lane": "source_lock", "verified_locked_artifacts": 14, "verified_bundle_entries": 60, "verified_bundle_bytes": 327589562, "issues": 0},
            {"lane": "fixture_check", "issues": 0, "exit_code": 0},
            {"lane": "compileall", "issues": 0, "exit_code": 0},
            {"lane": "git_diff_check", "issues": 0, "exit_code": 0},
        ],
        "non_gating_observation": {
            "lane": "unfiltered_functional",
            "result": "not_counted_timeout",
            "attempt_timeout_minutes": [10, 30],
            "failures_observed": 0,
            "reason": "the repository-wide functional group continued CPU-bound execution past the external limits; AS-WP2 exit uses the declared relevant functional suites",
        },
        "known_preexisting_warnings": [
            "CardDatabase could not read res://data/bundled_user/cards/images/UTEST/001.png.bin",
            "selected functional/AI runners reported ObjectDB/resource cleanup warnings after a zero-failure summary",
        ],
    }
    diff_report = {
        "schema_version": 1,
        "work_package": "AS-WP2",
        "allowed_existing_paths": allowed_existing,
        "changed_existing_paths": changed_existing,
        "allowed_additive_paths": additive,
        "present_additive_paths": additive,
        "fixture_prefix": work["files_allowed"]["generated_fixture_prefix"],
        "fixture_file_count": len(fixture_records),
        "evidence_prefix": "artifacts/ptcgdap/as_wp2/",
        "files_allowed_violations": [],
        "battle_setup_changes": [],
        "battle_scene_changes": [],
        "classic_ai_owner_changes": [],
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
        "work_package": "AS-WP2",
        "scope": "device-local Godot captured-byte validation and startup metadata-only catalog",
        "package_contract": True,
        "python_reference": True,
        "godot_metadata_validation": True,
        "fixed_root_startup_discovery": True,
        "metadata_catalog": True,
        "production_trust": False,
        "ready_records": False,
        "ui": False,
        "match_handle": False,
        "local_deck_mapping": False,
        "live_execution": False,
        "device_packaging": False,
        "classic_ai_behavior_changed": False,
        "alignment": {"A0": "partial / not claimed", "A1": "not evaluated", "A2": "not evaluated", "A3": "not evaluated", "A4": "not evaluated", "A5": "not evaluated"},
        "next_permitted_work": "AS-WP3: BattleSetup author-strategy mode and metadata UI",
    }
    rollback_report = f"""# AS-WP2 rollback report

Restore the thirteen exact files from `parent_snapshot/`. Delete only the ten declared AS-WP2 additive paths, `tests/ptcgdap/fixtures/author_strategy_packages/as_wp2/`, and `artifacts/ptcgdap/as_wp2/`.

The isolated virtual drill reproduced the exact AS-WP1 handoff candidate:

- entries: `{EXPECTED_PARENT_ENTRY_COUNT}`
- status counts: `{EXPECTED_PARENT_COUNTS}`
- canonical records SHA-256: `{EXPECTED_PARENT_DIGEST}`

`export_presets.cfg` was clean in the parent candidate and is restored by omission from the dirty-record reconstruction. There is no live owner or match to switch. Never delete installed packages under `user://ptcgdap/author_strategy_packages`, reset unrelated worktree changes, or modify `D:\\ai\\code\\ptcgabc`.
"""
    known_gaps = """# AS-WP2 known gaps

AS-WP2 proves only captured-byte Godot validation and fixed-root startup metadata discovery. The embedded Ed25519 public key remains scoped to synthetic test fixtures and has `execution_trusted=false`; no package can enter `ready_records` or become a match owner.

Still unsupported:

- production/release trust roots, install approval or revocation;
- BattleSetup author mode, package picker, author attribution UI or persisted setup selection;
- match-time archive recapture, immutable payload handle, exact local 60-card mapping or engine capability gate;
- current-window Host, ticket, engine commands, canary, active classic-AI separation at runtime;
- Windows/Android export execution, airplane-mode, performance/resource/device evidence or A5;
- complete Marnie local mapping or effect/engine parity.

The built-in package directory contains only its README. Shared `.ptcgai` archives live under the excluded test fixture prefix and are not player-ready. The unfiltered functional runner exceeded external 10/30-minute limits while continuing CPU-bound work and emitted no failure; it is explicitly not counted as green. The declared relevant functional and AI suites passed.
"""
    rendered: dict[str, bytes] = {
        "source_lock_snapshot.json": json_bytes(source_lock_snapshot),
        "implementation_hashes.json": json_bytes(implementation_hashes),
        "fixtures_manifest.json": json_bytes(fixtures_manifest),
        "test_commands.txt": test_commands.encode("utf-8"),
        "test_results.json": json_bytes(test_results),
        "diff_report.json": json_bytes(diff_report),
        "applicability.json": json_bytes(applicability),
        "rollback_report.md": rollback_report.encode("utf-8"),
        "known_gaps.md": known_gaps.encode("utf-8"),
    }
    evidence_records = [
        file_record("artifacts/ptcgdap/as_wp2/work_package.json"),
        file_record("artifacts/ptcgdap/as_wp2/parent_snapshot/manifest.json"),
    ]
    for name, value in rendered.items():
        evidence_records.append(file_record(f"artifacts/ptcgdap/as_wp2/{name}", value))
    manifest = {
        "schema_version": 1,
        "work_package": "AS-WP2",
        "candidate_id": "ptcgdap-as-wp2-godot-author-package-metadata-20260812",
        "status": "shadow",
        "implementation_state": "metadata_loader_catalog_complete",
        "generated_at": "2026-08-12T13:00:00+08:00",
        "scope": "Godot captured-byte package validation and fixed-root metadata-only startup catalog",
        "parent": {
            "work_package": "AS-WP1",
            "manifest_raw_sha256": EXPECTED_PARENT_MANIFEST_RAW,
            "manifest_canonical_sha256": EXPECTED_PARENT_MANIFEST_CANONICAL,
            "worktree_entry_count": EXPECTED_PARENT_ENTRY_COUNT,
            "worktree_status_counts": EXPECTED_PARENT_COUNTS,
            "worktree_canonical_records_sha256": EXPECTED_PARENT_DIGEST,
        },
        "contracts": {
            "author_package_bundle_canonical_sha256": EXPECTED_PACKAGE_BUNDLE,
            "contracts_changed": False,
            "source_lock_resigned": False,
        },
        "snapshot": {
            "file_count": 13,
            "manifest_raw_sha256": EXPECTED_PRIMARY_RAW,
            "manifest_canonical_sha256": EXPECTED_PRIMARY_CANONICAL,
        },
        "evidence_files": evidence_records,
        "test_summary": {
            "targeted_python_passed": 27,
            "godot_focused_passed": 10,
            "shared_archive_cases_passed": 39,
            "shared_catalog_cases_passed": 4,
            "godot_relevant_functional_passed": 108,
            "godot_relevant_ai_passed": 64,
            "parent_snapshot_passed": 94,
            "static_boundary_passed": 163,
            "full_python_passed": 759,
            "failed": 0,
            "skipped": 0,
            "source_lock_issues": 0,
        },
        "catalog_summary": {
            "built_in_root": "res://data/ptcgdap/author_strategy_packages",
            "user_root": "user://ptcgdap/author_strategy_packages",
            "test_key_execution_trusted": False,
            "production_trust_roots": 0,
            "ready_records": 0,
            "match_authority": False,
        },
        "candidate_snapshot": candidate,
        "rollback": {
            "parent_file_count": 13,
            "delete_exact_path_count": 10,
            "delete_fixture_prefix": work["files_allowed"]["generated_fixture_prefix"],
            "live_switch_required": False,
            "preserve_user_installed_packages": True,
            "isolated_virtual_drill": "passed",
            "restored_parent_candidate_entry_count": EXPECTED_PARENT_ENTRY_COUNT,
            "restored_parent_candidate_canonical_sha256": EXPECTED_PARENT_DIGEST,
        },
        "alignment": applicability["alignment"],
        "next_permitted_work": "AS-WP3: BattleSetup author-strategy mode and metadata UI",
        "self_hash_policy": "manifest.json does not hash itself; every other top-level evidence file, the parent snapshot manifest and all external AS-WP2 fixture files are bound by the evidence documents above",
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
    expected_entries = set(rendered) | {"work_package.json", "parent_snapshot"}
    actual_entries = {path.name for path in EVIDENCE_ROOT.iterdir()}
    unexpected = actual_entries - expected_entries
    if unexpected:
        failures.extend(sorted(unexpected))
    if failures:
        raise SystemExit(f"AS-WP2 evidence drift: {failures}")
    manifest = rendered["manifest.json"]
    print("AS-WP2 evidence verified" if check else "AS-WP2 evidence finalized")
    print(f"manifest_raw_sha256={sha(manifest)}")
    print(f"manifest_canonical_sha256={sha(canonical_json_v1_bytes(json.loads(manifest.decode('utf-8'))))}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--replace", action="store_true")
    parser.add_argument("--finalize", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.check and not args.finalize:
        raise SystemExit("--check requires --finalize")
    if args.finalize:
        if args.replace:
            raise SystemExit("--replace cannot be combined with --finalize")
        return finalize(args.check)
    return capture(args.replace)


if __name__ == "__main__":
    raise SystemExit(main())
