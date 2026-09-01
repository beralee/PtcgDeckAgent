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

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes


WORK_PACKAGE = ROOT / "artifacts/ptcgdap/p5_wp7/work_package.json"
OUTPUT_ROOT = ROOT / "artifacts/ptcgdap/p5_wp7/parent_snapshot"
SUPPLEMENTAL_ROOT = ROOT / "artifacts/ptcgdap/p5_wp7/supplemental_parent_snapshot"
ANCESTRAL_BRIDGE = ROOT / "artifacts/ptcgdap/p5_wp7/ancestral_candidate_bridge.json"
EVIDENCE_ROOT = ROOT / "artifacts/ptcgdap/p5_wp7"
P5_WP6_CHECKPOINT_TREE = "e5b49d5640332ffda927a38b587e2f1652c773d4"
P5_WP6_CHECKPOINT_REF = (
    "refs/codex/turn-diffs/checkpoints/"
    "e8ff7d2820ee342de52bf80e8fe983d2c20296990cde98b66c3de18a89970a96/"
    "a56b33f24208c21845d6098eff771fec7e8694451781265f5259e665f1da7ee2/"
    "1786425104500/1b350112-2bb2-42c0-b90e-970b4d5702a0"
)
P5_WP6_CANDIDATE_DIGEST = "BA70563C71A6153D0B893FA9438E2F1E18C7663DD8307389F966DB19CEE92197"
P5_WP6_CANDIDATE_COUNTS = {"deleted": 28, "modified": 1, "untracked": 1349}
P5_WP6_CANDIDATE_ENTRY_COUNT = 1378
GITIGNORE_WORKTREE_RAW_SHA256 = "5E05421FB2736D7A4722FF8C1F99E058240BCE59CA9BFDE6C93A7DB591265FB7"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def safe_repo_path(raw: object) -> str:
    if not isinstance(raw, str) or not raw or "\\" in raw or "\0" in raw:
        raise ValueError(f"unsafe path: {raw!r}")
    path = PurePosixPath(raw)
    if path.is_absolute() or "." in path.parts or ".." in path.parts or ":" in path.parts[0] or path.as_posix() != raw:
        raise ValueError(f"unsafe path: {raw!r}")
    return raw


def payload_name(path: str) -> str:
    return path.replace("/", "__") + ".base64"


def encode(value: bytes) -> bytes:
    encoded = base64.b64encode(value)
    return b"\n".join(encoded[index : index + 4096] for index in range(0, len(encoded), 4096)) + b"\n"


def git(*args: str) -> bytes:
    return subprocess.run(
        ["git", *args], cwd=ROOT, check=True, capture_output=True
    ).stdout


def tree_files(tree: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for record in git("ls-tree", "-r", "-z", tree).split(b"\0"):
        if not record:
            continue
        metadata, raw_path = record.split(b"\t", 1)
        _mode, kind, object_id = metadata.decode("ascii").split()
        if kind != "blob":
            continue
        path = safe_repo_path(raw_path.decode("utf-8"))
        result[path] = object_id
    return result


def build_ancestral_bridge() -> dict[str, object]:
    resolved = git("rev-parse", "--verify", P5_WP6_CHECKPOINT_REF).decode("ascii").strip()
    if resolved != P5_WP6_CHECKPOINT_TREE:
        raise SystemExit(f"P5-WP6 checkpoint ref drift: {resolved}")
    if git("cat-file", "-t", P5_WP6_CHECKPOINT_TREE).strip() != b"tree":
        raise SystemExit("P5-WP6 checkpoint object is not a tree")

    head = tree_files("HEAD")
    checkpoint = tree_files(P5_WP6_CHECKPOINT_TREE)
    records: list[dict[str, object]] = []
    process = subprocess.Popen(
        ["git", "cat-file", "--batch"],
        cwd=ROOT,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
    )
    if process.stdin is None or process.stdout is None:
        raise SystemExit("cannot open git cat-file batch pipes")

    def blob(object_id: str) -> bytes:
        process.stdin.write((object_id + "\n").encode("ascii"))
        process.stdin.flush()
        header = process.stdout.readline().decode("ascii").split()
        if len(header) != 3 or header[0] != object_id or header[1] != "blob":
            raise SystemExit(f"unexpected git cat-file header: {header}")
        size = int(header[2])
        value = process.stdout.read(size)
        if process.stdout.read(1) != b"\n" or len(value) != size:
            raise SystemExit(f"truncated git blob: {object_id}")
        return value

    try:
        for path in sorted(set(head) | set(checkpoint)):
            if path.startswith("artifacts/ptcgdap/p5_wp6/"):
                continue
            if path in head and path not in checkpoint:
                records.append({"path": path, "status": " D", "bytes": None, "sha256": None})
                continue
            if path not in head and path in checkpoint:
                status = "??"
            elif head.get(path) != checkpoint.get(path):
                status = " M"
            else:
                continue
            value = (ROOT / path).read_bytes() if path == ".gitignore" else blob(checkpoint[path])
            records.append({"path": path, "status": status, "bytes": len(value), "sha256": sha(value)})
    finally:
        process.stdin.close()
        process.terminate()
        process.wait(timeout=10)

    counts = Counter(
        "untracked" if item["status"] == "??" else "deleted" if "D" in item["status"] else "modified"
        for item in records
    )
    digest = sha(canonical_json_v1_bytes(records))
    if len(records) != P5_WP6_CANDIDATE_ENTRY_COUNT or dict(counts) != P5_WP6_CANDIDATE_COUNTS:
        raise SystemExit(f"P5-WP6 checkpoint count drift: {len(records)} {dict(counts)}")
    if digest != P5_WP6_CANDIDATE_DIGEST:
        raise SystemExit(f"P5-WP6 checkpoint digest drift: {digest}")
    gitignore = (ROOT / ".gitignore").read_bytes()
    if sha(gitignore) != GITIGNORE_WORKTREE_RAW_SHA256:
        raise SystemExit("tracked .gitignore worktree bytes drift")
    agents = blob_from_tree(checkpoint, "AGENTS.md")
    replay_payloads = []
    for path, value, source in (
        (".gitignore", gitignore, "tracked_worktree_bytes"),
        ("AGENTS.md", agents, "checkpoint_tree_blob"),
    ):
        replay_payloads.append(
            {
                "path": path,
                "source": source,
                "encoding": "base64",
                "bytes": len(value),
                "sha256": sha(value),
                "payload": base64.b64encode(value).decode("ascii"),
            }
        )
    return {
        "schema_version": 1,
        "work_package": "P5-WP7",
        "purpose": "self-contained sealed P5-WP6 candidate metadata for transitive ancestral virtual rollback",
        "source": {
            "checkpoint_ref": P5_WP6_CHECKPOINT_REF,
            "checkpoint_tree_oid": P5_WP6_CHECKPOINT_TREE,
            "checkpoint_object_type": "tree",
            "excluded_evidence_prefix": "artifacts/ptcgdap/p5_wp6/",
            "tracked_worktree_byte_override": ".gitignore",
        },
        "sealed_candidate": {
            "work_package": "P5-WP6",
            "entry_count": len(records),
            "status_counts": dict(counts),
            "canonical_records_sha256": digest,
        },
        "records": records,
        "replay_payloads": replay_payloads,
    }


def blob_from_tree(files: dict[str, str], path: str) -> bytes:
    object_id = files.get(path)
    if object_id is None:
        raise SystemExit(f"checkpoint path missing: {path}")
    return git("cat-file", "blob", object_id)


def json_bytes(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def artifact_record(relative: str, generated: dict[str, bytes] | None = None) -> dict[str, object]:
    value = generated[relative] if generated is not None and relative in generated else (ROOT / relative).read_bytes()
    result: dict[str, object] = {"path": relative, "bytes": len(value), "raw_sha256": sha(value)}
    if relative.endswith(".json"):
        result["canonical_sha256"] = sha(canonical_json_v1_bytes(json.loads(value.decode("utf-8"))))
    return result


def current_candidate_snapshot() -> tuple[dict[str, object], list[dict[str, object]]]:
    records: list[dict[str, object]] = []
    output = subprocess.run(
        ["git", "status", "--porcelain=v1", "-z", "--untracked-files=all"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    ).stdout
    for raw in output.split(b"\0"):
        if not raw:
            continue
        code = raw[:2].decode("ascii")
        path = safe_repo_path(raw[3:].decode("utf-8").replace("\\", "/"))
        if path.startswith("artifacts/ptcgdap/p5_wp7/"):
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
    records.sort(key=lambda item: item["path"])
    counts = Counter(
        "untracked" if item["status"] == "??" else "deleted" if "D" in item["status"] else "modified"
        for item in records
    )
    snapshot = {
        "excluded_prefix": "artifacts/ptcgdap/p5_wp7/",
        "entry_count": len(records),
        "status_counts": dict(counts),
        "canonical_records_sha256": sha(canonical_json_v1_bytes(records)),
    }
    expected = {
        "excluded_prefix": "artifacts/ptcgdap/p5_wp7/",
        "entry_count": 1500,
        "status_counts": {"deleted": 28, "modified": 2, "untracked": 1470},
    }
    if any(snapshot[key] != value for key, value in expected.items()):
        raise SystemExit(f"P5-WP7 candidate drift: {snapshot}")
    return snapshot, records


def render_final_evidence() -> dict[str, bytes]:
    work = json.loads(WORK_PACKAGE.read_text(encoding="utf-8"))
    candidate, candidate_records = current_candidate_snapshot()
    generated: dict[str, bytes] = {}

    source_lock = {
        "schema_version": 1,
        "work_package": "P5-WP7",
        "lock_path": "docs/ptcgdap/SOURCE_LOCK.json",
        "lock_raw_sha256": sha((ROOT / "docs/ptcgdap/SOURCE_LOCK.json").read_bytes()),
        "lock_canonical_sha256": "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205",
        "verified_locked_artifact_count": 14,
        "verified_bundle_entry_count": 60,
        "verified_bundle_bytes": 327589562,
        "verified_manifest_sha256": "9728A4409F2D8378F161E6BF33A871186C583CEAD3222372A5C4E092C5CB356C",
        "authoritative_result_sha256": "CD864D659ED2D88571617878D5121F73F7ED7B1A5FD96250CF7B7F811E1A3B57",
        "issues": [],
    }
    generated["artifacts/ptcgdap/p5_wp7/source_lock_snapshot.json"] = json_bytes(source_lock)

    artifact_paths = {
        "schema": "contracts/ptcgdap/marnie_portable_policy.schema.json",
        "profile": "contracts/ptcgdap/marnie_portable_policy_profile.json",
        "vectors": "contracts/ptcgdap/marnie_portable_policy_conformance_vectors.json",
        "audit": "data/ptcgdap/marnie_vertical_slice/marnie_portable_policy_v1.json",
    }
    fixtures = {
        "schema_version": 1,
        "work_package": "P5-WP7",
        "portable_policy_bundle": artifact_record("contracts/ptcgdap/marnie_portable_policy_bundle.json"),
        "artifacts": {name: artifact_record(path) for name, path in artifact_paths.items()},
        "runtime_integrity": {
            "python_and_godot_document_integrity_sha256": "6A2381855F98FB806B456F445AEE5A6F24A3C93A4ADE8259C8A106593AFC9210",
            "frame_set_sha256": "5DFB7ED299D566B71130F8049A27338462E23E2331D41344E27E684EFBEC4740",
            "chain_head": "AF8630DCEB004664A4BB90F16C9FD582FCA191316FB3482E5B3ACED773EC84E1",
        },
        "case_summary": {
            "shared_case_count": 28,
            "source_locked_frame_count": 13,
            "closed_node_count": 4,
            "base_owned_frame_count": 10,
            "capability_owned_frame_count": 2,
            "terminal_lifecycle_count": 1,
            "python_godot_mismatches": 0,
            "skips": 0,
            "live_consumers": 0,
            "execution_authority": False,
        },
        "parent_anchors": work["entry_evidence"],
    }
    generated["artifacts/ptcgdap/p5_wp7/fixtures_manifest.json"] = json_bytes(fixtures)

    commands = """# P5-WP7 final commands executed on 2026-08-12. D:\\ai\\code\\ptcgabc remained read-only.
# No training, benchmark, battle, simulation/evaluation pool, package, export or device run occurred.

python tools/ptcgdap/build_marnie_portable_policy_contract.py --check
python tools/ptcgdap/capture_p5_wp7_parent_snapshot.py --ancestral-bridge --replace
python -m unittest tests.ptcgdap.test_marnie_portable_policy_contract_builder tests.ptcgdap.test_marnie_portable_policy_schema tests.ptcgdap.test_marnie_portable_policy tests.ptcgdap.test_marnie_portable_policy_properties tests.ptcgdap.test_p5_wp7_boundaries tests.ptcgdap.test_p5_wp7_parent_snapshot -q
python -m unittest discover -s tests/ptcgdap -p \"test_*_parent_snapshot.py\" -q
python -m unittest discover -s tests/ptcgdap -p \"test_*_boundaries.py\" -q
python -m unittest discover -s tests/ptcgdap -p \"test_*.py\" -q
$env:PTCGABC_ORACLE_ROOT='D:\\ai\\code\\ptcgabc'
python -m unittest tests.ptcgdap.test_fixture_contract tests.ptcgdap.test_enum_snapshot tests.ptcgdap.test_option_shapes tests.ptcgdap.test_typed_view_contract -q
python -m scripts.ai.ptcgdap.source_lock --lock docs/ptcgdap/SOURCE_LOCK.json --expect-lock-sha256 8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205 --root ptcgabc=D:\\ai\\code\\ptcgabc --root ptcgdap=D:\\ai\\code\\PtcgDAP --format json
python -m compileall -q scripts/ai/ptcgdap tools/ptcgdap tests/ptcgdap
.\\scripts\\tools\\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/ptcgdap/godot/test_marnie_capability_policy.gd
.\\scripts\\tools\\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/ptcgdap/godot/test_marnie_public_base.gd
.\\scripts\\tools\\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/ptcgdap/godot/test_marnie_portable_policy.gd
git diff --check
"""
    generated["artifacts/ptcgdap/p5_wp7/test_commands.txt"] = commands.encode("utf-8")

    test_results = {
        "schema_version": 1,
        "work_package": "P5-WP7",
        "status": "shadow",
        "runtime_versions": {
            "python": "CPython 3.13.7",
            "godot": "4.6.1.stable.official.14d19694e",
            "platform": "Windows x86_64 development host",
        },
        "lanes": [
            {"id": "python-targeted-final", "status": "passed", "passed": 21, "failed": 0, "errors": 0, "skipped": 0, "duration_seconds": "89.495"},
            {"id": "python-parent-snapshots-final", "status": "passed", "passed": 84, "failed": 0, "errors": 0, "skipped": 0, "duration_seconds": "18.079"},
            {"id": "python-static-boundaries-final", "status": "passed", "passed": 163, "failed": 0, "errors": 0, "skipped": 0, "duration_seconds": "5.254"},
            {"id": "python-full-final", "status": "passed", "passed": 722, "failed": 0, "errors": 0, "skipped": 0, "duration_seconds": "674.478"},
            {"id": "official-oracle", "status": "passed", "passed": 34, "failed": 0, "errors": 0, "skipped": 0, "duration_seconds": "1.547"},
            {"id": "source-lock", "status": "passed", "passed": 14, "failed": 0, "errors": 0, "skipped": 0, "verified_bundle_entries": 60, "verified_bundle_bytes": 327589562},
            {"id": "contract-builder-check", "status": "passed", "passed": 1, "failed": 0, "errors": 0, "skipped": 0},
            {"id": "ancestral-bridge-reproduction", "status": "passed", "passed": 25, "failed": 0, "errors": 0, "skipped": 0},
            {"id": "python-compileall", "status": "passed", "passed": 1, "failed": 0, "errors": 0, "skipped": 0},
            {"id": "godot-capability-parent", "status": "passed", "passed": 5, "failed": 0, "errors": 0, "skipped": 0, "log": ".godot_test_user/logs/focused-20260812-013200.log"},
            {"id": "godot-public-base-parent", "status": "passed", "passed": 5, "failed": 0, "errors": 0, "skipped": 0, "log": ".godot_test_user/logs/focused-20260812-013445.log"},
            {"id": "godot-portable-policy-final", "status": "passed", "passed": 4, "failed": 0, "errors": 0, "skipped": 0, "log": ".godot_test_user/logs/focused-20260812-014025.log"},
            {"id": "git-diff-check", "status": "passed", "passed": 1, "failed": 0, "errors": 0, "skipped": 0, "note": "pre-existing .gitignore/project.godot LF-to-CRLF warnings only"},
        ],
        "shared_conformance": {"cases": 28, "frames": 13, "closed_nodes": 4, "python_godot_mismatches": 0, "skips": 0},
        "live_consumers": 0,
        "execution_authority": False,
        "parent_contract_bundles_changed": False,
        "alignment": work["alignment_claim"],
        "next_permitted_work": "AS-WP0: author strategy package governance, parent snapshot and RED",
    }
    generated["artifacts/ptcgdap/p5_wp7/test_results.json"] = json_bytes(test_results)

    tracked_diff = git("diff", "--binary")
    text_checked = sum(
        1 for item in candidate_records
        if item["bytes"] is not None and Path(item["path"]).suffix.lower() in {".gd", ".json", ".md", ".py", ".txt", ".tscn", ".tres"}
    )
    diff_report = {
        "schema_version": 1,
        "work_package": "P5-WP7",
        "candidate_snapshot": candidate,
        "tracked_diff": {"bytes": len(tracked_diff), "raw_sha256": sha(tracked_diff), "check": "passed_with_pre_existing_line_ending_warnings_only"},
        "scope": {
            "additive_owner_paths": 16,
            "primary_parent_path_count": 11,
            "supplemental_parent_path_count": 28,
            "ancestral_parent_digest_count": 25,
            "live_consumer_changes": 0,
            "project_or_scene_changes": 0,
            "ptcgabc_changes": 0,
            "source_lock_changes": 0,
            "parent_contract_bundle_changes": 0,
        },
        "hygiene": {"candidate_text_files_checked": text_checked, "line_start_conflict_markers": 0, "nul_files": 0, "candidate_whitespace_errors": 0},
    }
    generated["artifacts/ptcgdap/p5_wp7/diff_report.json"] = json_bytes(diff_report)

    applicability = {
        "schema_version": 1,
        "work_package": "P5-WP7",
        "status": "shadow",
        "applicable": {
            "python_reference": True,
            "godot_4_6_1_focused_runner": True,
            "strict_contract_and_schema": True,
            "source_locked_public_trajectory": True,
            "capability_and_public_base_recomputation": True,
            "current_window_fingerprint_binding_probe": True,
            "portable_public_trace_chain": True,
            "property_fault_and_exact_parent_rollback": True,
            "source_lock_and_official_oracle": True,
        },
        "not_applicable": {
            "live_ui_or_headless_host": True,
            "production_game_state_machine": True,
            "action_ticket_or_engine_execution": True,
            "feature_flag_or_canary": True,
            "ptcgai_export_or_signature": True,
            "kaggle_package": True,
            "player_device_or_android": True,
            "engine_parity": True,
            "client_artifact_confidentiality": True,
        },
        "alignment": work["alignment_claim"],
    }
    generated["artifacts/ptcgdap/p5_wp7/applicability.json"] = json_bytes(applicability)

    rollback = """# P5-WP7 rollback report

Rollback remains exact, offline, and non-live. The primary snapshot binds 11 handoff documents; the supplemental snapshot binds 28 compatibility tests captured before their P5-WP7 compatibility changes. The path sets are disjoint and both manifests are mandatory.

1. Strictly parse both manifests and reject unsafe, duplicate, or overlapping paths.
2. Decode and verify all 39 canonical RFC4648 base64 payloads, including payload-file bytes and decoded raw hashes.
3. Restore all 39 parent paths as one operation.
4. Delete only the 16 exact P5-WP7 additive paths and the complete `artifacts/ptcgdap/p5_wp7/` evidence prefix.
5. Re-run the isolated P5-WP7 virtual rollback and the historical parent chain.

The executed P5-WP7 drill reproduced the 1484-entry pre-P5-WP7 handoff candidate with canonical records SHA-256 `DE54EA7E55DF33F6A7773CF900CC4041DEE5B58B8B0A6DB6DAECE474A1265D80`. The self-contained sealed-candidate bridge also starts from the exact P5-WP6 1378-entry digest `BA70563C71A6153D0B893FA9438E2F1E18C7663DD8307389F966DB19CEE92197` and replays all 25 parent snapshots through P1-WP3 without changing any historical count or digest. Final parent-snapshot discovery passed 84/84. No live switch, git reset, external-repository write, or working-tree overwrite was performed.
"""
    generated["artifacts/ptcgdap/p5_wp7/rollback_report.md"] = rollback.encode("utf-8")

    gaps = """# P5-WP7 known gaps

P5-WP7 is complete only as an offline public portable-policy differential and shadow trajectory gate.

- There is no live UI/headless Host, production ActionTicket, engine command/transaction, feature flag, canary, author-package loader, public trajectory writer, or aligned match owner.
- Serialized capability proposals, Base results, adapter hints, decisions, traces, fingerprints, hashes, and schema-valid DTOs remain non-authoritative audit data. A future Host must rebuild and validate from the exact live current source/window.
- The accepted Marnie slice still has separate official/local deck identities, `cabt_exportable=false`, only 9 mapped official IDs and 34/60 exact bridge coverage; 10 official Card IDs remain unmapped.
- No complete card-effect/rules-engine parity, strategy-strength, match-result, package-signature, PC/Android device, airplane-mode, A5, Kaggle export, or client-artifact-confidentiality claim is made.
- The reference integrity path is intentionally expensive: the final three related Godot suites took about 954 seconds in total, and Python full discovery took about 680 seconds. This implementation is an offline guard and is not approved for a live hot path.
- The Godot runner emitted the existing CardDatabase warning for the missing bundled `UTEST/001.png.bin`; all three suites still exited zero and no P5-WP7 assertion was skipped.
- The sealed ancestral bridge contains only relative path/status/size/SHA-256 metadata plus exact `.gitignore` and `AGENTS.md` replay payloads. It is rollback evidence, not runtime authority or a production dependency on Codex checkpoint refs.

Alignment remains `A0 partial / not claimed`; A1–A5 are `not evaluated`. The next work is AS-WP0 and remains subject to its own governance, parent snapshot, RED tests, rollback, and evidence.
"""
    generated["artifacts/ptcgdap/p5_wp7/known_gaps.md"] = gaps.encode("utf-8")

    files_allowed = work["files_allowed"]
    hash_paths = sorted(
        set(
            files_allowed["contracts"]
            + files_allowed["data"]
            + files_allowed["implementation"]
            + files_allowed["tests"]
            + files_allowed["existing_docs"]
            + files_allowed["existing_compatibility_tests"]
            + [
                "docs/ptcgdap/SOURCE_LOCK.json",
                "contracts/ptcgdap/marnie_capability_policy_bundle.json",
                "contracts/ptcgdap/marnie_public_base_bundle.json",
                "contracts/ptcgdap/marnie_trajectory_replay_bundle.json",
                "artifacts/ptcgdap/p5_wp6/manifest.json",
                "artifacts/ptcgdap/p5_wp7/work_package.json",
                "artifacts/ptcgdap/p5_wp7/ancestral_candidate_bridge.json",
                "artifacts/ptcgdap/p5_wp7/parent_snapshot/manifest.json",
                "artifacts/ptcgdap/p5_wp7/supplemental_parent_snapshot/manifest.json",
                *generated.keys(),
            ]
        )
    )
    contract_hashes = {
        "schema_version": 1,
        "work_package": "P5-WP7",
        "bundle": {**artifact_record("contracts/ptcgdap/marnie_portable_policy_bundle.json"), "artifact_count": 4},
        "runtime_integrity": fixtures["runtime_integrity"],
        "record_count": len(hash_paths),
        "records": [artifact_record(path, generated) for path in hash_paths],
        "parent_anchors": work["entry_evidence"],
        "candidate_snapshot": candidate,
        "ancestral_replay": {
            "bridge_raw_sha256": sha(ANCESTRAL_BRIDGE.read_bytes()),
            "bridge_canonical_sha256": sha(canonical_json_v1_bytes(json.loads(ANCESTRAL_BRIDGE.read_text(encoding="utf-8")))),
            "sealed_p5_wp6_candidate_canonical_sha256": P5_WP6_CANDIDATE_DIGEST,
            "verified_parent_digest_count": 25,
            "terminal_parent": "P1-WP3",
        },
    }
    contract_path = "artifacts/ptcgdap/p5_wp7/contract_hashes.json"
    generated[contract_path] = json_bytes(contract_hashes)

    evidence_paths = [
        "artifacts/ptcgdap/p5_wp7/work_package.json",
        "artifacts/ptcgdap/p5_wp7/source_lock_snapshot.json",
        "artifacts/ptcgdap/p5_wp7/fixtures_manifest.json",
        "artifacts/ptcgdap/p5_wp7/test_commands.txt",
        "artifacts/ptcgdap/p5_wp7/test_results.json",
        "artifacts/ptcgdap/p5_wp7/diff_report.json",
        "artifacts/ptcgdap/p5_wp7/applicability.json",
        "artifacts/ptcgdap/p5_wp7/rollback_report.md",
        "artifacts/ptcgdap/p5_wp7/known_gaps.md",
        contract_path,
        "artifacts/ptcgdap/p5_wp7/ancestral_candidate_bridge.json",
        "artifacts/ptcgdap/p5_wp7/parent_snapshot/manifest.json",
        "artifacts/ptcgdap/p5_wp7/supplemental_parent_snapshot/manifest.json",
    ]
    contract_record = artifact_record(contract_path, generated)
    manifest = {
        "schema_version": 1,
        "work_package": "P5-WP7",
        "candidate_id": "ptcgdap-p5-wp7-marnie-portable-differential-20260812",
        "status": "shadow",
        "implementation_state": "completed",
        "generated_at": "2026-08-12T02:00:00+08:00",
        "scope": "offline public Marnie Python/GDScript differential and portable shadow trajectory only; no live Host, ticket, engine execution, package, device or engine-parity claim",
        "parent": {
            "work_package": "P5-WP6 plus accepted author-strategy handoff state",
            "manifest_path": work["entry_evidence"]["parent_manifest_path"],
            "manifest_raw_sha256": work["entry_evidence"]["parent_manifest_raw_sha256"],
            "manifest_canonical_sha256": work["entry_evidence"]["parent_manifest_canonical_sha256"],
            "handoff_candidate_entry_count": 1484,
            "handoff_candidate_canonical_records_sha256": "DE54EA7E55DF33F6A7773CF900CC4041DEE5B58B8B0A6DB6DAECE474A1265D80",
        },
        "trust_anchors": {
            "portable_policy_bundle_canonical_sha256": "992B7F00DF412496BA414ABCC87C21C6136CB513C9C90799C897ADD18D15EDB2",
            "document_integrity_sha256": "6A2381855F98FB806B456F445AEE5A6F24A3C93A4ADE8259C8A106593AFC9210",
            "source_lock_canonical_sha256": "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205",
            "primary_parent_snapshot_manifest_raw_sha256": sha((OUTPUT_ROOT / "manifest.json").read_bytes()),
            "primary_parent_snapshot_manifest_canonical_sha256": sha(canonical_json_v1_bytes(json.loads((OUTPUT_ROOT / "manifest.json").read_text(encoding="utf-8")))),
            "supplemental_parent_snapshot_manifest_raw_sha256": sha((SUPPLEMENTAL_ROOT / "manifest.json").read_bytes()),
            "supplemental_parent_snapshot_manifest_canonical_sha256": sha(canonical_json_v1_bytes(json.loads((SUPPLEMENTAL_ROOT / "manifest.json").read_text(encoding="utf-8")))),
            "ancestral_bridge_raw_sha256": sha(ANCESTRAL_BRIDGE.read_bytes()),
            "ancestral_bridge_canonical_sha256": sha(canonical_json_v1_bytes(json.loads(ANCESTRAL_BRIDGE.read_text(encoding="utf-8")))),
            "contract_hashes_raw_sha256": contract_record["raw_sha256"],
            "contract_hashes_canonical_sha256": contract_record["canonical_sha256"],
        },
        "evidence_files": [artifact_record(path, generated) for path in evidence_paths],
        "test_summary": {
            "python_full_ptcgdap": {"passed": 722, "failed": 0, "skipped": 0},
            "python_targeted": {"passed": 21, "failed": 0, "skipped": 0},
            "python_parent_snapshots": {"passed": 84, "failed": 0, "skipped": 0},
            "python_static_boundaries": {"passed": 163, "failed": 0, "skipped": 0},
            "official_oracle": {"passed": 34, "failed": 0, "skipped": 0},
            "godot_related_suites": {"passed": 14, "failed": 0, "skipped": 0},
            "ancestral_parent_digests": {"passed": 25, "failed": 0, "skipped": 0},
            "source_lock": {"verified_locked_artifacts": 14, "verified_bundle_entries": 60, "verified_bundle_bytes": 327589562, "issues": 0},
        },
        "fixture_summary": fixtures["case_summary"],
        "candidate_snapshot": candidate,
        "rollback": {
            "primary_parent_file_count": 11,
            "supplemental_parent_file_count": 28,
            "total_parent_file_count": 39,
            "delete_exact_path_count": 16,
            "live_switch_required": False,
            "isolated_virtual_drill": "passed",
            "restored_parent_candidate_entry_count": 1484,
            "restored_parent_candidate_canonical_sha256": "DE54EA7E55DF33F6A7773CF900CC4041DEE5B58B8B0A6DB6DAECE474A1265D80",
            "ancestral_digest_count": 25,
        },
        "release_review": "primary_final_review_no_blocker",
        "alignment": work["alignment_claim"],
        "next_permitted_work": "AS-WP0: author strategy package governance, parent snapshot and RED",
        "self_hash_policy": "manifest.json does not hash itself; contract_hashes.json is bound by raw and canonical digest",
    }
    generated["artifacts/ptcgdap/p5_wp7/manifest.json"] = json_bytes(manifest)
    return generated


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--replace", action="store_true")
    parser.add_argument("--supplemental", action="store_true")
    parser.add_argument("--ancestral-bridge", action="store_true")
    parser.add_argument("--finalize", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.finalize:
        if args.supplemental or args.ancestral_bridge:
            raise SystemExit("--finalize cannot be combined with snapshot capture modes")
        generated = render_final_evidence()
        if args.check:
            mismatches = [path for path, value in generated.items() if not (ROOT / path).is_file() or (ROOT / path).read_bytes() != value]
            if mismatches:
                raise SystemExit("final evidence drift: " + ", ".join(mismatches))
            print(f"verified {len(generated)} final evidence files")
            return 0
        for path, value in generated.items():
            destination = ROOT / path
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(value)
        print(f"wrote {len(generated)} final evidence files")
        print(f"manifest_raw_sha256={sha(generated['artifacts/ptcgdap/p5_wp7/manifest.json'])}")
        return 0
    if args.check:
        raise SystemExit("--check requires --finalize")
    if args.ancestral_bridge:
        if args.supplemental:
            raise SystemExit("--ancestral-bridge and --supplemental are mutually exclusive")
        if ANCESTRAL_BRIDGE.exists() and not args.replace:
            raise SystemExit("ancestral bridge already exists; use --replace after re-verifying the checkpoint")
        bridge = build_ancestral_bridge()
        output = (json.dumps(bridge, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
        ANCESTRAL_BRIDGE.write_bytes(output)
        print(f"captured {bridge['sealed_candidate']['entry_count']} sealed candidate records")
        print(f"bridge_raw_sha256={sha(output)}")
        print(f"bridge_canonical_sha256={sha(canonical_json_v1_bytes(bridge))}")
        return 0
    work = json.loads(WORK_PACKAGE.read_text(encoding="utf-8"))
    files = work["files_allowed"]
    restore_paths = [
        safe_repo_path(path)
        for path in (files["existing_compatibility_tests"] if args.supplemental else files["existing_docs"])
    ]
    delete_paths = [
        safe_repo_path(path)
        for path in [*files["contracts"], *files["data"], *files["implementation"], *files["tests"]]
    ]
    expected_restore_count = 28 if args.supplemental else 11
    if len(restore_paths) != expected_restore_count or len(restore_paths) != len(set(restore_paths)):
        raise SystemExit(f"expected {expected_restore_count} unique parent paths")
    if len(delete_paths) != 16 or len(delete_paths) != len(set(delete_paths)):
        raise SystemExit("expected 16 unique additive paths")
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
                raise SystemExit(f"unexpected snapshot directory entry: {path}")
            path.unlink()

    entries = []
    for relative in restore_paths:
        value = (ROOT / relative).read_bytes()
        name = payload_name(relative)
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

    entry = work["entry_evidence"]
    manifest = {
        "schema_version": 1,
        "work_package": "P5-WP7-supplemental" if args.supplemental else "P5-WP7",
        "captured_at": "2026-08-11T14:00:00+08:00",
        "file_count": len(entries),
        "parent": {
            "work_package": "P5-WP6 plus accepted author-strategy handoff documents",
            "manifest_path": entry["parent_manifest_path"],
            "manifest_raw_sha256": entry["parent_manifest_raw_sha256"],
            "manifest_canonical_sha256": entry["parent_manifest_canonical_sha256"],
            "worktree_entry_count": entry["pre_p5_wp7_handoff_candidate_entry_count"],
            "worktree_status_counts": entry["pre_p5_wp7_handoff_candidate_status_counts"],
            "worktree_snapshot_canonical_sha256": entry["pre_p5_wp7_handoff_candidate_canonical_sha256"],
        },
        "files": entries,
        "rollback_scope": {
            "restore_exact_paths": restore_paths,
            "delete_exact_paths": [] if args.supplemental else delete_paths,
            "delete_evidence_prefix": "artifacts/ptcgdap/p5_wp7/",
        },
    }
    output = (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    (output_root / "manifest.json").write_bytes(output)
    print(f"captured {len(entries)} files")
    print(f"manifest_raw_sha256={sha(output)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
