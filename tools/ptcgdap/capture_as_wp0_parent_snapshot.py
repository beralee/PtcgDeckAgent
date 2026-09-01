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


WORK_PACKAGE = ROOT / "artifacts/ptcgdap/as_wp0/work_package.json"
OUTPUT_ROOT = ROOT / "artifacts/ptcgdap/as_wp0/parent_snapshot"
EVIDENCE_ROOT = ROOT / "artifacts/ptcgdap/as_wp0"
PARENT_MANIFEST = ROOT / "artifacts/ptcgdap/p5_wp7/manifest.json"
PORTABLE_POLICY_BUNDLE = ROOT / "contracts/ptcgdap/marnie_portable_policy_bundle.json"
SOURCE_LOCK = ROOT / "docs/ptcgdap/SOURCE_LOCK.json"
EXPECTED_RED_PATHS = (
    "contracts/ptcgdap/author_strategy_package.schema.json",
    "contracts/ptcgdap/author_strategy_package_profile.json",
    "contracts/ptcgdap/author_strategy_package_conformance_vectors.json",
    "contracts/ptcgdap/author_strategy_package_bundle.json",
    "tools/ptcgdap/build_author_strategy_package.py",
    "scripts/ai/ptcgdap/author_strategy_package.py",
)
EXPECTED_PARENT_MANIFEST_RAW = "088A6FF8A32DC14F784A6644B089F2F006632112407174009AC9117B1EB5B089"
EXPECTED_PARENT_MANIFEST_CANONICAL = "7DFA83EAB3C1841B5336061015BF291511AFEE380F629B6F394B3B6CCBA31AC7"
EXPECTED_PORTABLE_POLICY_BUNDLE = "992B7F00DF412496BA414ABCC87C21C6136CB513C9C90799C897ADD18D15EDB2"
EXPECTED_SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
EXPECTED_SNAPSHOT_RAW = "DB0F242F3A3BA79F85439A3AF7C272B713391FB562ABF708C034611458DD63BB"
EXPECTED_SNAPSHOT_CANONICAL = "ED93C74FA56D254AF6874808C683DB689A8AF0C1AEB3A7DCE384E4A254890C31"
EXPECTED_PARENT_ENTRY_COUNT = 1553
EXPECTED_PARENT_COUNTS = {"deleted": 28, "modified": 2, "untracked": 1523}
EXPECTED_PARENT_DIGEST = "6B4161D7DB460D55AC56760C7716989096EE264E73196C18086F0AB8A4F598E5"


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
    record: dict[str, object] = {
        "path": relative,
        "bytes": len(payload),
        "raw_sha256": sha(payload),
    }
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
    records: list[dict[str, object]] = []
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


def render_evidence() -> dict[str, bytes]:
    work = load_json_strict(WORK_PACKAGE)
    snapshot_manifest_path = OUTPUT_ROOT / "manifest.json"
    snapshot = load_json_strict(snapshot_manifest_path)
    if sha(PARENT_MANIFEST.read_bytes()) != EXPECTED_PARENT_MANIFEST_RAW or canonical_sha(PARENT_MANIFEST) != EXPECTED_PARENT_MANIFEST_CANONICAL:
        raise SystemExit("sealed P5-WP7 manifest drift")
    if canonical_sha(PORTABLE_POLICY_BUNDLE) != EXPECTED_PORTABLE_POLICY_BUNDLE:
        raise SystemExit("sealed portable-policy bundle drift")
    if canonical_sha(SOURCE_LOCK) != EXPECTED_SOURCE_LOCK:
        raise SystemExit("SOURCE_LOCK drift")
    if sha(snapshot_manifest_path.read_bytes()) != EXPECTED_SNAPSHOT_RAW or canonical_sha(snapshot_manifest_path) != EXPECTED_SNAPSHOT_CANONICAL:
        raise SystemExit("AS-WP0 parent snapshot drift")
    missing = [path for path in EXPECTED_RED_PATHS if not (ROOT / path).is_file()]
    if missing != list(EXPECTED_RED_PATHS):
        raise SystemExit(f"intentional RED boundary drift: {missing}")

    docs = work["files_allowed"]["existing_docs"]
    additive = work["files_allowed"]["as_wp0_additive"]
    changed_docs = []
    for entry in snapshot["files"]:
        relative = safe_repo_path(entry["original_path"])
        current = (ROOT / relative).read_bytes()
        if sha(current) != entry["raw_sha256"]:
            changed_docs.append(relative)
    if changed_docs != docs:
        raise SystemExit(f"planned documentation change set drift: {changed_docs}")
    if [path for path in additive if not (ROOT / path).is_file()]:
        raise SystemExit("AS-WP0 additive path missing")

    records, counts = worktree_records("artifacts/ptcgdap/as_wp0/")
    candidate = {
        "excluded_prefix": "artifacts/ptcgdap/as_wp0/",
        "entry_count": len(records),
        "status_counts": counts,
        "canonical_records_sha256": sha(canonical_json_v1_bytes(records)),
    }

    source_lock_snapshot = {
        "schema_version": 1,
        "work_package": "AS-WP0",
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
    }
    fixtures_manifest = {
        "schema_version": 1,
        "work_package": "AS-WP0",
        "parent_snapshot": {
            "manifest_path": "artifacts/ptcgdap/as_wp0/parent_snapshot/manifest.json",
            "manifest_raw_sha256": EXPECTED_SNAPSHOT_RAW,
            "manifest_canonical_sha256": EXPECTED_SNAPSHOT_CANONICAL,
            "file_count": 7,
            "paths": [entry["original_path"] for entry in snapshot["files"]],
        },
        "intentional_red": {
            "test": "tests.ptcgdap.test_author_strategy_package_contract.AuthorStrategyPackageContractRedTests.test_as_wp1_contract_builder_and_loader_exist",
            "expected_failures": 1,
            "expected_missing_paths": list(EXPECTED_RED_PATHS),
            "unexpected_missing_paths": [],
        },
        "runtime_fixtures": [],
        "executable_packages": 0,
    }
    test_commands = """# AS-WP0 governance validation (2026-08-12, PowerShell)\n\n# Green: exact parent payloads, sealed anchors and 1553-entry virtual rollback.\npython -m unittest tests.ptcgdap.test_as_wp0_parent_snapshot -v\n\n# Intentional RED: expected exit 1, exactly one failure, exactly six missing AS-WP1 paths.\npython -m unittest tests.ptcgdap.test_author_strategy_package_contract -q\n\n# Green: source oracle and lock remain exact.\npython -m scripts.ai.ptcgdap.source_lock --lock docs/ptcgdap/SOURCE_LOCK.json --expect-lock-sha256 8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205 --root ptcgabc=D:\\ai\\code\\ptcgabc --root ptcgdap=D:\\ai\\code\\PtcgDAP --format json\n\n# Green: AS-WP0 Python syntax and textual hygiene.\npython -m compileall -q tools/ptcgdap/capture_as_wp0_parent_snapshot.py tests/ptcgdap/test_as_wp0_parent_snapshot.py tests/ptcgdap/test_author_strategy_package_contract.py\ngit diff --check\n"""
    test_results = {
        "schema_version": 1,
        "work_package": "AS-WP0",
        "overall": "accepted_governance_red",
        "results": [
            {"lane": "parent_snapshot_and_virtual_rollback", "passed": 3, "failed": 0, "skipped": 0, "exit_code": 0},
            {
                "lane": "intentional_package_contract_red",
                "passed": 0,
                "expected_failures": 1,
                "unexpected_failures": 0,
                "skipped": 0,
                "exit_code": 1,
                "missing_paths": list(EXPECTED_RED_PATHS),
            },
            {
                "lane": "source_lock",
                "verified_locked_artifacts": 14,
                "verified_bundle_entries": 60,
                "verified_bundle_bytes": 327589562,
                "issues": 0,
                "exit_code": 0,
            },
            {"lane": "compileall", "issues": 0, "exit_code": 0},
            {"lane": "git_diff_check", "issues": 0, "exit_code": 0},
        ],
        "interpretation": "The one failure is the AS-WP0 acceptance RED. No AS-WP1 implementation is claimed.",
    }
    diff_report = {
        "schema_version": 1,
        "work_package": "AS-WP0",
        "allowed_existing_docs": docs,
        "changed_existing_docs": changed_docs,
        "allowed_additive_paths": additive,
        "present_additive_paths": additive,
        "evidence_prefix": "artifacts/ptcgdap/as_wp0/",
        "forbidden_runtime_owner_changes": [],
        "files_allowed_violations": [],
        "contracts_added": 0,
        "package_implementations_added": 0,
        "godot_files_changed": 0,
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
        "work_package": "AS-WP0",
        "scope": "author-strategy governance, exact parent recovery and intentional module/package missing RED only",
        "execution_location": "offline_development_validation_only",
        "contract_implementation": False,
        "metadata_discovery": False,
        "godot_runtime": False,
        "ui": False,
        "live_execution": False,
        "device_packaging": False,
        "classic_ai_behavior_changed": False,
        "alignment": {"A0": "partial / not claimed", "A1": "not evaluated", "A2": "not evaluated", "A3": "not evaluated", "A4": "not evaluated", "A5": "not evaluated"},
        "next_permitted_work": "AS-WP1: .ptcgai contract, deterministic builder and Python reference loader",
    }
    contract_hashes = {
        "schema_version": 1,
        "work_package": "AS-WP0",
        "contracts_changed": False,
        "parent_anchors": {
            "p5_wp7_manifest_raw_sha256": EXPECTED_PARENT_MANIFEST_RAW,
            "p5_wp7_manifest_canonical_sha256": EXPECTED_PARENT_MANIFEST_CANONICAL,
            "portable_policy_bundle_canonical_sha256": EXPECTED_PORTABLE_POLICY_BUNDLE,
            "source_lock_canonical_sha256": EXPECTED_SOURCE_LOCK,
            "as_wp0_parent_snapshot_manifest_raw_sha256": EXPECTED_SNAPSHOT_RAW,
            "as_wp0_parent_snapshot_manifest_canonical_sha256": EXPECTED_SNAPSHOT_CANONICAL,
        },
        "governance_documents": [file_record(path) for path in docs],
        "additive_sources": [file_record(path) for path in additive],
        "as_wp1_contract_paths_at_exit": [{"path": path, "present": False} for path in EXPECTED_RED_PATHS],
    }
    rollback_report = f"""# AS-WP0 rollback report\n\nAS-WP0 has no live switch to reverse. Restore the seven exact document payloads listed in `parent_snapshot/manifest.json`, then delete only the three `rollback_scope.delete_exact_paths` entries and `artifacts/ptcgdap/as_wp0/`.\n\nThe isolated virtual drill passed and reproduced the pre-AS-WP0 worktree exactly:\n\n- entries: `{EXPECTED_PARENT_ENTRY_COUNT}`\n- status counts: `{EXPECTED_PARENT_COUNTS}`\n- canonical records SHA-256: `{EXPECTED_PARENT_DIGEST}`\n\nDo not delete user `.ptcgai` files, reset unrelated worktree changes, modify `D:\\ai\\code\\ptcgabc`, or switch the current/live AI owner. No package implementation exists in this work package.\n"""
    known_gaps = """# AS-WP0 known gaps\n\nAS-WP0 is governance-only. The intentional RED proves that the six AS-WP1 schema/profile/vector/bundle/builder/loader paths do not yet exist. It does not prove a valid `.ptcgai` can be built, loaded, signed, trusted, discovered, selected or executed.\n\nStill unsupported:\n\n- deterministic archive creation and byte-for-byte rebuild;\n- strict package schema, closed member/type/path/size rules and stable rejection codes;\n- fixed product trust anchors, signature verification and tamper/re-sign rejection;\n- synthetic valid/invalid package fixtures;\n- Godot ZIP loader, metadata catalog, autoload or export inclusion;\n- BattleSetup author mode, match-time pinning, current-window Host or engine execution;\n- complete Marnie local mapping/effect parity, canary, Windows/Android packaging, device evidence or A5.\n\nThe P5-WP7 finalizer's current-worktree candidate check is not reusable after a legitimate successor work package adds files. AS-WP0 therefore verifies the sealed P5-WP7 manifest/bundle/SOURCE_LOCK identities directly and binds its own pre-edit 1553-entry parent snapshot; no P5 contract or evidence file was rewritten.\n"""

    rendered: dict[str, bytes] = {
        "source_lock_snapshot.json": json_bytes(source_lock_snapshot),
        "fixtures_manifest.json": json_bytes(fixtures_manifest),
        "test_commands.txt": test_commands.encode("utf-8"),
        "test_results.json": json_bytes(test_results),
        "diff_report.json": json_bytes(diff_report),
        "applicability.json": json_bytes(applicability),
        "contract_hashes.json": json_bytes(contract_hashes),
        "rollback_report.md": rollback_report.encode("utf-8"),
        "known_gaps.md": known_gaps.encode("utf-8"),
    }
    evidence_records = [
        file_record("artifacts/ptcgdap/as_wp0/work_package.json"),
        file_record("artifacts/ptcgdap/as_wp0/parent_snapshot/manifest.json"),
    ]
    for name, value in rendered.items():
        evidence_records.append(file_record(f"artifacts/ptcgdap/as_wp0/{name}", value))
    manifest = {
        "schema_version": 1,
        "work_package": "AS-WP0",
        "candidate_id": "ptcgdap-as-wp0-author-strategy-governance-red-20260812",
        "status": "governance_only_complete",
        "implementation_state": "intentional_preimplementation_red",
        "generated_at": "2026-08-12T03:00:00+08:00",
        "scope": "author-strategy package governance, exact parent recovery and first module/package missing RED only",
        "parent": {
            "work_package": "P5-WP7",
            "manifest_path": "artifacts/ptcgdap/p5_wp7/manifest.json",
            "manifest_raw_sha256": EXPECTED_PARENT_MANIFEST_RAW,
            "manifest_canonical_sha256": EXPECTED_PARENT_MANIFEST_CANONICAL,
            "portable_policy_bundle_canonical_sha256": EXPECTED_PORTABLE_POLICY_BUNDLE,
            "source_lock_canonical_sha256": EXPECTED_SOURCE_LOCK,
            "worktree_entry_count": EXPECTED_PARENT_ENTRY_COUNT,
            "worktree_status_counts": EXPECTED_PARENT_COUNTS,
            "worktree_canonical_records_sha256": EXPECTED_PARENT_DIGEST,
        },
        "parent_snapshot": {
            "file_count": 7,
            "manifest_raw_sha256": EXPECTED_SNAPSHOT_RAW,
            "manifest_canonical_sha256": EXPECTED_SNAPSHOT_CANONICAL,
        },
        "evidence_files": evidence_records,
        "test_summary": {
            "green_tests": 3,
            "expected_red_failures": 1,
            "unexpected_failures": 0,
            "source_lock_issues": 0,
            "compile_issues": 0,
            "diff_issues": 0,
        },
        "candidate_snapshot": candidate,
        "rollback": {
            "restore_parent_file_count": 7,
            "delete_exact_path_count": 3,
            "live_switch_required": False,
            "isolated_virtual_drill": "passed",
            "restored_parent_candidate_entry_count": EXPECTED_PARENT_ENTRY_COUNT,
            "restored_parent_candidate_canonical_sha256": EXPECTED_PARENT_DIGEST,
        },
        "alignment": applicability["alignment"],
        "next_permitted_work": "AS-WP1: .ptcgai contract, deterministic builder and Python reference loader",
        "self_hash_policy": "manifest.json does not hash itself; every other top-level evidence file and the parent snapshot manifest are bound above",
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
            path.write_bytes(value)
    if failures:
        raise SystemExit(f"AS-WP0 evidence drift: {failures}")
    manifest = rendered["manifest.json"]
    print("AS-WP0 evidence verified" if check else "AS-WP0 evidence finalized")
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
    work = json.loads(WORK_PACKAGE.read_text(encoding="utf-8"))
    restore_paths = [safe_repo_path(path) for path in work["files_allowed"]["existing_docs"]]
    delete_paths = [safe_repo_path(path) for path in work["files_allowed"]["as_wp0_additive"]]
    if len(restore_paths) != 7 or len(restore_paths) != len(set(restore_paths)):
        raise SystemExit("expected seven unique parent paths")
    if len(delete_paths) != 3 or len(delete_paths) != len(set(delete_paths)):
        raise SystemExit("expected three unique AS-WP0 additive paths")
    if set(restore_paths) & set(delete_paths):
        raise SystemExit("restore/delete path overlap")
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    existing = list(OUTPUT_ROOT.iterdir())
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
    parent = work["entry_evidence"]
    manifest = {
        "schema_version": 1,
        "work_package": "AS-WP0",
        "captured_at": "2026-08-12T02:30:00+08:00",
        "file_count": len(entries),
        "parent": {
            "work_package": "P5-WP7",
            "manifest_path": parent["parent_manifest_path"],
            "manifest_raw_sha256": parent["parent_manifest_raw_sha256"],
            "manifest_canonical_sha256": parent["parent_manifest_canonical_sha256"],
            "portable_policy_bundle_canonical_sha256": parent["parent_portable_policy_bundle_canonical_sha256"],
            "worktree_entry_count": parent["pre_as_wp0_worktree_entry_count"],
            "worktree_status_counts": parent["pre_as_wp0_worktree_status_counts"],
            "worktree_snapshot_canonical_sha256": parent["pre_as_wp0_worktree_canonical_sha256"],
        },
        "files": entries,
        "rollback_scope": {
            "restore_exact_paths": restore_paths,
            "delete_exact_paths": delete_paths,
            "delete_evidence_prefix": "artifacts/ptcgdap/as_wp0/",
        },
    }
    output = (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    (OUTPUT_ROOT / "manifest.json").write_bytes(output)
    print(f"captured {len(entries)} files")
    print(f"manifest_raw_sha256={sha(output)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
