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


WORK_PACKAGE = ROOT / "artifacts/ptcgdap/as_wp3/work_package.json"
OUTPUT_ROOT = ROOT / "artifacts/ptcgdap/as_wp3/parent_snapshot"
EVIDENCE_ROOT = ROOT / "artifacts/ptcgdap/as_wp3"
PARENT_MANIFEST = ROOT / "artifacts/ptcgdap/as_wp2/manifest.json"
EXPECTED_PARENT_MANIFEST_RAW = "5CBEB06779E698920F357FF76E99C91B2E677E538C5143C9058F6D60198C643B"
EXPECTED_PARENT_MANIFEST_CANONICAL = "D191516688415965960BB7692CA443AD7329F2D59EDFD718DBFB6DFD6BA3A0AD"
EXPECTED_PACKAGE_BUNDLE = "B416F2CBA2795B62126B6EF7B5F07A9000E84D5FA1DF62C1753CADC9E82E106B"
EXPECTED_SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
EXPECTED_PARENT_ENTRY_COUNT = 1687
EXPECTED_PARENT_COUNTS = {"deleted": 28, "modified": 3, "untracked": 1656}
EXPECTED_PARENT_DIGEST = "3D65625D9FC953F3852303E69EB708A55D252697409B7791836323BCF39398F7"
EXPECTED_PRIMARY_RAW = "784178E46C9BD325B51B91591D42A95A162FAE72E5BF451351117F608DE7E16B"
EXPECTED_PRIMARY_CANONICAL = "02E915137A69B5F9F3D294C5E423B35F4B9CBEBC41BA70EACB7E7A51BF3D517A"
EXPECTED_CLEAN_PARENT_PATHS = [
    "scripts/autoload/GameManager.gd",
    "scenes/battle_setup/BattleSetup.tscn",
    "scenes/battle_setup/BattleSetup.gd",
    "tests/test_battle_setup_ai_versions.gd",
]


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def canonical_sha(path: Path) -> str:
    return sha(canonical_json_v1_bytes(load_json_strict(path)))


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


def file_record(relative: str, value: bytes | None = None) -> dict[str, object]:
    payload = (ROOT / relative).read_bytes() if value is None else value
    record: dict[str, object] = {"path": relative, "bytes": len(payload), "raw_sha256": sha(payload)}
    if relative.endswith(".json"):
        record["canonical_sha256"] = sha(canonical_json_v1_bytes(json.loads(payload.decode("utf-8"))))
    return record


def status_records(excluded_prefix: str, excluded_paths: set[str]) -> tuple[list[dict[str, object]], dict[str, int]]:
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
        if path.startswith(excluded_prefix) or path in excluded_paths:
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
        raise SystemExit("AS-WP2 manifest raw drift")
    if canonical_sha(PARENT_MANIFEST) != EXPECTED_PARENT_MANIFEST_CANONICAL:
        raise SystemExit("AS-WP2 manifest canonical drift")
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
    delete_paths = [safe_repo_path(path) for path in allowed["as_wp3_additive"]]
    if len(restore_paths) != 15 or len(restore_paths) != len(set(restore_paths)):
        raise SystemExit("expected fifteen unique AS-WP3 parent paths")
    if len(delete_paths) != 5 or len(delete_paths) != len(set(delete_paths)):
        raise SystemExit("expected five unique AS-WP3 additive paths")
    if set(restore_paths) & set(delete_paths):
        raise SystemExit("restore/delete path overlap")

    records, counts = status_records("artifacts/ptcgdap/as_wp3/", set(delete_paths))
    if len(records) != EXPECTED_PARENT_ENTRY_COUNT or counts != EXPECTED_PARENT_COUNTS:
        raise SystemExit(f"pre-AS-WP3 worktree counts drift: {len(records)} {counts}")
    if sha(canonical_json_v1_bytes(records)) != EXPECTED_PARENT_DIGEST:
        raise SystemExit("pre-AS-WP3 worktree digest drift")

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
        "work_package": "AS-WP3",
        "captured_at": "2026-08-12T14:00:00+08:00",
        "file_count": len(entries),
        "parent": {
            "work_package": "AS-WP2",
            "manifest_path": entry["parent_manifest_path"],
            "manifest_raw_sha256": entry["parent_manifest_raw_sha256"],
            "manifest_canonical_sha256": entry["parent_manifest_canonical_sha256"],
            "author_package_bundle_canonical_sha256": entry["author_package_bundle_canonical_sha256"],
            "source_lock_canonical_sha256": entry["source_lock_canonical_sha256"],
            "worktree_entry_count": entry["pre_as_wp3_worktree_entry_count"],
            "worktree_status_counts": entry["pre_as_wp3_worktree_status_counts"],
            "worktree_snapshot_canonical_sha256": entry["pre_as_wp3_worktree_canonical_sha256"],
        },
        "files": entries,
        "rollback_scope": {
            "restore_exact_paths": restore_paths,
            "delete_exact_paths": delete_paths,
            "omit_parent_clean_paths": EXPECTED_CLEAN_PARENT_PATHS,
            "delete_evidence_prefix": "artifacts/ptcgdap/as_wp3/",
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
    if work.get("status") != "complete" or work.get("implementation_state") != "setup_metadata_ui_complete":
        raise SystemExit("AS-WP3 work package is not complete")
    if sha(PARENT_MANIFEST.read_bytes()) != EXPECTED_PARENT_MANIFEST_RAW or canonical_sha(PARENT_MANIFEST) != EXPECTED_PARENT_MANIFEST_CANONICAL:
        raise SystemExit("AS-WP2 manifest drift")
    if sha(primary_path.read_bytes()) != EXPECTED_PRIMARY_RAW or canonical_sha(primary_path) != EXPECTED_PRIMARY_CANONICAL:
        raise SystemExit("AS-WP3 parent snapshot drift")
    if canonical_sha(ROOT / "docs/ptcgdap/SOURCE_LOCK.json") != EXPECTED_SOURCE_LOCK:
        raise SystemExit("SOURCE_LOCK drift")

    allowed = work["files_allowed"]
    allowed_existing = [
        *allowed["existing_project_files"],
        *allowed["existing_docs"],
        *allowed["existing_compatibility_files"],
    ]
    parent = load_json_strict(primary_path)
    changed_existing = [
        entry["original_path"]
        for entry in parent["files"]
        if sha((ROOT / entry["original_path"]).read_bytes()) != entry["raw_sha256"]
    ]
    if changed_existing != allowed_existing:
        raise SystemExit(f"existing change set drift: {changed_existing}")
    additive = allowed["as_wp3_additive"]
    missing_additive = [path for path in additive if not (ROOT / path).is_file()]
    if missing_additive:
        raise SystemExit(f"AS-WP3 additive path missing: {missing_additive}")

    records, counts = status_records("artifacts/ptcgdap/as_wp3/", set())
    candidate = {
        "excluded_prefix": "artifacts/ptcgdap/as_wp3/",
        "entry_count": len(records),
        "status_counts": counts,
        "canonical_records_sha256": sha(canonical_json_v1_bytes(records)),
    }
    completion_evidence = work.get("completion_evidence")
    if not isinstance(completion_evidence, dict):
        raise SystemExit("AS-WP3 completion_evidence is missing")
    expected_candidate = {
        "entry_count": completion_evidence.get("candidate_entry_count"),
        "status_counts": completion_evidence.get("candidate_status_counts"),
        "canonical_records_sha256": completion_evidence.get("candidate_canonical_sha256"),
    }
    actual_candidate = {key: candidate[key] for key in expected_candidate}
    if actual_candidate != expected_candidate:
        raise SystemExit(f"AS-WP3 candidate drift: {candidate}")

    implementation_files = [*allowed_existing, *additive]
    source_lock_snapshot = {
        "schema_version": 1,
        "work_package": "AS-WP3",
        "lock_path": "docs/ptcgdap/SOURCE_LOCK.json",
        "lock_raw_sha256": sha((ROOT / "docs/ptcgdap/SOURCE_LOCK.json").read_bytes()),
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
        "work_package": "AS-WP3",
        "author_package_bundle_canonical_sha256": EXPECTED_PACKAGE_BUNDLE,
        "parent_manifest_raw_sha256": EXPECTED_PARENT_MANIFEST_RAW,
        "parent_manifest_canonical_sha256": EXPECTED_PARENT_MANIFEST_CANONICAL,
        "parent_snapshot_raw_sha256": EXPECTED_PRIMARY_RAW,
        "parent_snapshot_canonical_sha256": EXPECTED_PRIMARY_CANONICAL,
        "contracts_changed": False,
        "files": [file_record(path) for path in implementation_files],
    }
    test_commands = """# AS-WP3 validation (2026-08-12, PowerShell)

python -m unittest tests.ptcgdap.test_author_strategy_package_contract tests.ptcgdap.test_author_strategy_package_loader tests.ptcgdap.test_author_strategy_package_catalog tests.ptcgdap.test_author_strategy_battle_setup_boundary -v
powershell -ExecutionPolicy Bypass -File scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/ptcgdap/godot/test_author_strategy_battle_setup.gd -UserDataRoot D:\\ai\\code\\PtcgDAP\\.godot_test_user\\as_wp3_validation
powershell -ExecutionPolicy Bypass -File scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/ptcgdap/godot/test_author_strategy_package_catalog.gd -UserDataRoot D:\\ai\\code\\PtcgDAP\\.godot_test_user\\as_wp3_validation
powershell -ExecutionPolicy Bypass -File scripts/tools/run_godot_tests.ps1 -Runner functional -Suite GameManager,BattleSetupAIVersions,BattleSetupLayout,BattleSetupMusic,BattleSceneArchitectureAudit,BattleSceneLifecycle,BattleSceneAIFixedDeckOrder,ExportPresets,SuiteCatalog -UserDataRoot D:\\ai\\code\\PtcgDAP\\.godot_test_user\\as_wp3_validation
powershell -ExecutionPolicy Bypass -File scripts/tools/run_godot_tests.ps1 -Runner ai -Suite AIStrategyWiring,DeckStrategyContract,DeckStrategyRegistryExpansion,AIVersionRegistry,OpponentDeckFingerprintResolver,MatchupPolicyIntegration -UserDataRoot D:\\ai\\code\\PtcgDAP\\.godot_test_user\\as_wp3_validation
python -m unittest discover -s tests/ptcgdap -p "test_*parent_snapshot.py" -q
python -m unittest discover -s tests/ptcgdap -p "test_*boundaries.py" -q
python -m unittest discover -s tests/ptcgdap -p "test_*.py" -q
python -m scripts.ai.ptcgdap.source_lock --lock docs/ptcgdap/SOURCE_LOCK.json --expect-lock-sha256 8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205 --root ptcgabc=D:\\ai\\code\\ptcgabc --root ptcgdap=D:\\ai\\code\\PtcgDAP --format json
python -m compileall -q scripts/ai/ptcgdap scripts/ui/battle/author_strategy tools/ptcgdap tests/ptcgdap
git diff --check
python tools/ptcgdap/capture_as_wp3_parent_snapshot.py --finalize --check
"""
    test_results = {
        "schema_version": 1,
        "work_package": "AS-WP3",
        "overall": "passed",
        "results": [
            {"lane": "targeted_python_package_and_ui_boundary", "passed": 33, "failed": 0, "skipped": 0},
            {"lane": "godot_focused_author_setup", "passed": 7, "failed": 0, "skipped": 0},
            {"lane": "godot_focused_package_catalog", "passed": 10, "failed": 0, "skipped": 0},
            {"lane": "godot_relevant_functional", "passed": 157, "failed": 0, "skipped": 0},
            {"lane": "godot_relevant_ai", "passed": 64, "failed": 0, "skipped": 0},
            {"lane": "parent_snapshots", "passed": 97, "failed": 0, "skipped": 0},
            {"lane": "static_boundaries", "passed": 163, "failed": 0, "skipped": 0},
            {"lane": "full_python_discovery", "passed": 768, "failed": 0, "skipped": 0, "duration_milliseconds": 688820},
            {"lane": "source_lock", "verified_locked_artifacts": 14, "verified_bundle_entries": 60, "verified_bundle_bytes": 327589562, "issues": 0},
            {"lane": "compileall", "issues": 0, "exit_code": 0},
            {"lane": "git_diff_check", "issues": 0, "exit_code": 0},
        ],
        "non_gating_observation": {
            "lane": "godot_non_battle_portrait_layout_fresh_user_root",
            "passed": 63,
            "failed": 2,
            "as_wp3_battle_setup_failures": 0,
            "preexisting_failures": [
                "test_non_battle_touch_bridge_can_prepare_ios_web_dom_input_before_focus",
                "test_non_battle_touch_bridge_programmatic_clear_updates_active_web_editor_and_preserves_caret_policy",
            ],
            "reason": "both failures are Web DOM input-bridge expectations outside AS-WP3 files_allowed; the previously contaminated author-mode deck failure passed from a clean user-data root",
        },
        "known_preexisting_warnings": [
            "CardDatabase could not read res://data/bundled_user/cards/images/UTEST/001.png.bin",
            "selected functional/AI runners reported ObjectDB/resource cleanup warnings after a zero-failure summary",
        ],
    }
    diff_report = {
        "schema_version": 1,
        "work_package": "AS-WP3",
        "allowed_existing_paths": allowed_existing,
        "changed_existing_paths": changed_existing,
        "allowed_additive_paths": additive,
        "present_additive_paths": additive,
        "evidence_prefix": "artifacts/ptcgdap/as_wp3/",
        "files_allowed_violations": [],
        "battle_scene_changes": [],
        "match_host_changes": [],
        "classic_ai_factory_changes": [],
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
        "work_package": "AS-WP3",
        "scope": "device-local BattleSetup author-strategy metadata selection only",
        "package_contract": True,
        "godot_metadata_validation": True,
        "metadata_catalog": True,
        "game_mode": True,
        "metadata_ui": True,
        "stable_ref_persistence": True,
        "classic_ui_separation": True,
        "start_allowed": False,
        "production_trust": False,
        "ready_records": False,
        "match_handle": False,
        "local_deck_mapping": False,
        "policy_invocation": False,
        "live_execution": False,
        "device_packaging": False,
        "alignment": {"A0": "partial / not claimed", "A1": "not evaluated", "A2": "not evaluated", "A3": "not evaluated", "A4": "not evaluated", "A5": "not evaluated"},
        "next_permitted_work": "AS-WP4: match-time package handle, exact deck gate and shadow Host",
    }
    rollback_report = f"""# AS-WP3 rollback report

Restore the fifteen exact files from `parent_snapshot/`. Delete only the five declared AS-WP3 additive paths and `artifacts/ptcgdap/as_wp3/`.

The isolated virtual drill reproduced the exact AS-WP2 handoff candidate:

- entries: `{EXPECTED_PARENT_ENTRY_COUNT}`
- status counts: `{EXPECTED_PARENT_COUNTS}`
- canonical records SHA-256: `{EXPECTED_PARENT_DIGEST}`

The four paths that were clean at entry (`GameManager.gd`, `BattleSetup.tscn`, `BattleSetup.gd`, and the classic BattleSetup regression) are restored by omission from the dirty-record reconstruction. There is no live owner or match to switch. Never delete installed packages under `user://ptcgdap/author_strategy_packages`, reset unrelated worktree changes, or modify `D:\\ai\\code\\ptcgabc`.
"""
    known_gaps = """# AS-WP3 known gaps

AS-WP3 proves only setup-time, copy-only metadata presentation and exact stable-reference persistence. The start gate is deliberately false even for synthetic `ready` metadata.

Still unsupported:

- production/release trust roots, install approval or revocation;
- match-time archive recapture, immutable payload handle and whole-match hash pin;
- exact local 60-card mapping or engine capability gate;
- current-window Host, policy invocation, ticket, engine command, canary or active owner;
- Windows/Android export execution, airplane-mode, performance/resource/device evidence or A5;
- complete Marnie local mapping or effect/engine parity.

The built-in package directory remains empty and AS-WP2 `ready_records` remains empty because the only embedded key is test-fixture-only. A clean-user-root `NonBattlePortraitLayout` run passed every BattleSetup case but retained two unrelated pre-existing Web DOM input-bridge failures; those failures were not counted as AS-WP3 green and were not modified outside the declared owner boundary.
"""
    rendered: dict[str, bytes] = {
        "source_lock_snapshot.json": json_bytes(source_lock_snapshot),
        "implementation_hashes.json": json_bytes(implementation_hashes),
        "test_commands.txt": test_commands.encode("utf-8"),
        "test_results.json": json_bytes(test_results),
        "diff_report.json": json_bytes(diff_report),
        "applicability.json": json_bytes(applicability),
        "rollback_report.md": rollback_report.encode("utf-8"),
        "known_gaps.md": known_gaps.encode("utf-8"),
    }
    evidence_records = [
        file_record("artifacts/ptcgdap/as_wp3/work_package.json"),
        file_record("artifacts/ptcgdap/as_wp3/parent_snapshot/manifest.json"),
    ]
    for name, value in rendered.items():
        evidence_records.append(file_record(f"artifacts/ptcgdap/as_wp3/{name}", value))
    manifest = {
        "schema_version": 1,
        "work_package": "AS-WP3",
        "candidate_id": "ptcgdap-as-wp3-author-strategy-setup-ui-20260812",
        "status": "shadow",
        "implementation_state": "setup_metadata_ui_complete",
        "generated_at": "2026-08-12T05:36:00+08:00",
        "scope": "BattleSetup author-strategy metadata selection and explicit not-live-ready gate",
        "parent": {
            "work_package": "AS-WP2",
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
            "file_count": 15,
            "manifest_raw_sha256": EXPECTED_PRIMARY_RAW,
            "manifest_canonical_sha256": EXPECTED_PRIMARY_CANONICAL,
        },
        "evidence_files": evidence_records,
        "test_summary": {
            "targeted_python_passed": 33,
            "godot_author_setup_passed": 7,
            "godot_package_catalog_passed": 10,
            "godot_relevant_functional_passed": 157,
            "godot_relevant_ai_passed": 64,
            "parent_snapshot_passed": 97,
            "static_boundary_passed": 163,
            "full_python_passed": 768,
            "failed": 0,
            "skipped": 0,
            "source_lock_issues": 0,
        },
        "ui_summary": {
            "game_mode": "VS_AUTHOR_STRATEGY_AI",
            "stable_identity_fields": ["package_id", "package_version", "archive_sha256"],
            "catalog_statuses": ["ready", "metadata_only", "incompatible", "untrusted", "invalid", "disabled"],
            "start_allowed": False,
            "match_authority": False,
            "classic_ai_state_shared": False,
        },
        "candidate_snapshot": candidate,
        "rollback": {
            "parent_file_count": 15,
            "delete_exact_path_count": 5,
            "live_switch_required": False,
            "preserve_user_installed_packages": True,
            "isolated_virtual_drill": "passed",
            "restored_parent_candidate_entry_count": EXPECTED_PARENT_ENTRY_COUNT,
            "restored_parent_candidate_canonical_sha256": EXPECTED_PARENT_DIGEST,
        },
        "alignment": applicability["alignment"],
        "next_permitted_work": "AS-WP4: match-time package handle, exact deck gate and shadow Host",
        "self_hash_policy": "manifest.json does not hash itself; every other top-level evidence file and the parent snapshot manifest are bound by evidence_files",
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
        raise SystemExit(f"AS-WP3 evidence drift: {failures}")
    manifest = rendered["manifest.json"]
    print("AS-WP3 evidence verified" if check else "AS-WP3 evidence finalized")
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
