from __future__ import annotations

import base64
from collections import Counter
import hashlib
from pathlib import Path, PurePosixPath
import subprocess
import tempfile
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tests.ptcgdap.dragapult_acceptance_rollback import (
    POST_ACCEPTANCE_DEVELOPMENT_PARENT_RESTORE_PATHS,
    is_dragapult_acceptance_additive,
    restore_pre_author_player_owner_record,
    restore_pre_dragapult_bytes,
)


ROOT = Path(__file__).resolve().parents[2]
SNAPSHOT_ROOT = ROOT / "artifacts/ptcgdap/as_wp5/parent_snapshot"
MANIFEST_PATH = SNAPSHOT_ROOT / "manifest.json"
PARENT_MANIFEST_PATH = ROOT / "artifacts/ptcgdap/as_wp4/manifest.json"
WORK_PACKAGE_PATH = ROOT / "artifacts/ptcgdap/as_wp5/work_package.json"
EXPECTED_MANIFEST_RAW = "DA2B946303B454CDDCE22A4373C4175E556648AE73C9F60773A3C00185E00E77"
EXPECTED_MANIFEST_CANONICAL = "BC17973CF54E8B8BE6C45D7494DCBE47FE2CB0AD9DC784455DC7E54FFDE34E33"
EXPECTED_PARENT_MANIFEST_RAW = "1C65FB41A15C433FCB43F29A354218B4D8BE93E46B9E0E762B338E9760554DB6"
EXPECTED_PARENT_MANIFEST_CANONICAL = "21E201F8C550781B95E45ED537BA0B3CAFE5FAFD078C46CC8D3E2AC16BC8A19F"
EXPECTED_MATCH_HOST_BUNDLE = "4BD207E9F9200E5AF9E2206A13EAF506382B6BA42BDEE3F0FEB5CA872885DBB9"
EXPECTED_SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
EXPECTED_PARENT_ENTRY_COUNT = 1774
EXPECTED_PARENT_COUNTS = {"deleted": 28, "modified": 7, "untracked": 1739}
EXPECTED_PARENT_DIGEST = "D8FEB0F9D8179ABAE07B2A6BB5CE2D657DE8700D65999DD74E81C300DE2BDA4F"
AS_WP5_EVIDENCE_PREFIX = "artifacts/ptcgdap/as_wp5/"
AS_WP5_ADDITIVE_PATHS = frozenset(
    load_json_strict(WORK_PACKAGE_PATH)["files_allowed"]["as_wp5_additive"]
)
AS_WP5_APPROVED_SUCCESSOR_RUNTIME_PATHS = frozenset(
    {
        "scripts/ai/ptcgdap/host/godot/AuthorStrategySourceDocuments.gd",
        "scripts/ai/ptcgdap/host/godot/AuthorStrategyLiveCommand.gd",
        "scripts/ai/ptcgdap/host/godot/AuthorStrategyLivePromptSource.gd",
        "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorLiveSeam.gd",
        "scripts/ai/ptcgdap/host/godot/GodotObservationProjector.gd",
        "scripts/ui/battle/prompts/BattlePromptRouter.gd",
        "scripts/ui/battle/BattleDialogController.gd",
        "scenes/battle/runtime/BattleSceneRuntimeFoundation.gd",
        "scenes/battle/runtime/BattleSceneSetupEffectAiRuntime.gd",
    }
)
AS_WP6_SNAPSHOT_ROOT = ROOT / "artifacts/ptcgdap/as_wp6/parent_snapshot"
AS_WP6_MANIFEST_PATH = AS_WP6_SNAPSHOT_ROOT / "manifest.json"
AS_WP6_WORK_PACKAGE_PATH = ROOT / "artifacts/ptcgdap/as_wp6/work_package.json"
AS_WP6_EVIDENCE_PREFIX = "artifacts/ptcgdap/as_wp6/"
AS_WP6_ADDITIVE_PATHS = frozenset(
    load_json_strict(AS_WP6_WORK_PACKAGE_PATH)["files_allowed"]["as_wp6_additive"]
)
_AS_WP5_PARENT_BYTES: dict[str, bytes] | None = None
_AS_WP6_PARENT_BYTES: dict[str, bytes] | None = None


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def safe_path(raw: object) -> str:
    if not isinstance(raw, str) or not raw or "\\" in raw or "\0" in raw:
        raise AssertionError(raw)
    path = PurePosixPath(raw)
    if path.is_absolute() or "." in path.parts or ".." in path.parts or ":" in path.parts[0] or path.as_posix() != raw:
        raise AssertionError(raw)
    return raw


def decode(entry: dict[str, object], root: Path = SNAPSHOT_ROOT) -> bytes:
    name = safe_path(entry["snapshot_path"])
    if "/" in name:
        raise AssertionError(name)
    source = (root / name).read_bytes()
    if not source.endswith(b"\n") or b"\r" in source:
        raise AssertionError(name)
    lines = source[:-1].split(b"\n")
    if not lines or any(not line or len(line) > 4096 for line in lines) or any(len(line) != 4096 for line in lines[:-1]):
        raise AssertionError(name)
    encoded = b"".join(lines)
    value = base64.b64decode(encoded.decode("ascii"), validate=True)
    if base64.b64encode(value) != encoded:
        raise AssertionError(name)
    if len(source) != entry["snapshot_file_bytes"] or sha(source) != entry["snapshot_file_raw_sha256"]:
        raise AssertionError(name)
    if len(value) != entry["bytes"] or sha(value) != entry["raw_sha256"]:
        raise AssertionError(name)
    return value


def status() -> list[tuple[str, str]]:
    output = subprocess.run(
        ["git", "status", "--porcelain=v1", "-z", "--untracked-files=all"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    ).stdout
    result: list[tuple[str, str]] = []
    for record in output.split(b"\0"):
        if not record:
            continue
        code = record[:2].decode("ascii")
        path = safe_path(record[3:].decode("utf-8").replace("\\", "/"))
        if "R" in code or "C" in code:
            raise AssertionError("rename/copy outside snapshot algorithm")
        result.append((code, path))
    return result


def tracked_head_bytes(path: str) -> bytes | None:
    result = subprocess.run(
        ["git", "cat-file", "--filters", f"--path={path}", f"HEAD:{path}"],
        cwd=ROOT,
        capture_output=True,
    )
    return result.stdout if result.returncode == 0 else None


def as_wp5_parent_bytes(path: str, current: bytes) -> bytes:
    global _AS_WP5_PARENT_BYTES
    if _AS_WP5_PARENT_BYTES is None:
        manifest = load_json_strict(MANIFEST_PATH)
        _AS_WP5_PARENT_BYTES = {
            safe_path(entry["original_path"]): decode(entry) for entry in manifest["files"]
        }
    return _AS_WP5_PARENT_BYTES.get(path, as_wp6_parent_bytes(path, current))


def as_wp6_parent_bytes(path: str, current: bytes) -> bytes:
    global _AS_WP6_PARENT_BYTES
    if _AS_WP6_PARENT_BYTES is None:
        manifest = load_json_strict(AS_WP6_MANIFEST_PATH)
        _AS_WP6_PARENT_BYTES = {
            safe_path(entry["original_path"]): decode(entry, AS_WP6_SNAPSHOT_ROOT)
            for entry in manifest["files"]
        }
    return _AS_WP6_PARENT_BYTES.get(path, current)


def is_as_wp6_path(path: str) -> bool:
    return path.startswith(AS_WP6_EVIDENCE_PREFIX) or path in AS_WP6_ADDITIVE_PATHS


def is_as_wp5_path(path: str) -> bool:
    return is_as_wp6_path(path) or path.startswith(AS_WP5_EVIDENCE_PREFIX) or path in AS_WP5_ADDITIVE_PATHS


def is_as_wp5_parent_clean_path(path: str) -> bool:
    global _AS_WP5_PARENT_BYTES, _AS_WP6_PARENT_BYTES
    if _AS_WP5_PARENT_BYTES is None:
        as_wp5_parent_bytes("", b"")
    value = _AS_WP5_PARENT_BYTES.get(path) if _AS_WP5_PARENT_BYTES is not None else None
    if value is not None:
        return tracked_head_bytes(path) == value
    if _AS_WP6_PARENT_BYTES is None:
        as_wp6_parent_bytes("", b"")
    successor_value = _AS_WP6_PARENT_BYTES.get(path) if _AS_WP6_PARENT_BYTES is not None else None
    return successor_value is not None and tracked_head_bytes(path) == successor_value


class AsWp5ParentSnapshotTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if EXPECTED_MANIFEST_RAW != sha(MANIFEST_PATH.read_bytes()):
            raise AssertionError("AS-WP5 snapshot raw drift")
        cls.manifest = load_json_strict(MANIFEST_PATH)
        if EXPECTED_MANIFEST_CANONICAL != sha(canonical_json_v1_bytes(cls.manifest)):
            raise AssertionError("AS-WP5 snapshot canonical drift")
        cls.entries = {safe_path(entry["original_path"]): entry for entry in cls.manifest["files"]}
        cls.work = load_json_strict(WORK_PACKAGE_PATH)

    def test_payloads_are_exact_safe_complete_and_bind_as_wp4(self) -> None:
        self.assertEqual("AS-WP5", self.manifest["work_package"])
        self.assertEqual(31, self.manifest["file_count"])
        self.assertEqual(31, len(self.entries))
        parent = self.manifest["parent"]
        self.assertEqual(EXPECTED_PARENT_MANIFEST_RAW, parent["manifest_raw_sha256"])
        self.assertEqual(EXPECTED_PARENT_MANIFEST_CANONICAL, parent["manifest_canonical_sha256"])
        self.assertEqual(EXPECTED_MATCH_HOST_BUNDLE, parent["author_match_host_bundle_canonical_sha256"])
        self.assertEqual(EXPECTED_SOURCE_LOCK, parent["source_lock_canonical_sha256"])
        self.assertEqual(EXPECTED_PARENT_ENTRY_COUNT, parent["worktree_entry_count"])
        self.assertEqual(EXPECTED_PARENT_COUNTS, parent["worktree_status_counts"])
        self.assertEqual(EXPECTED_PARENT_DIGEST, parent["worktree_snapshot_canonical_sha256"])
        self.assertEqual(EXPECTED_PARENT_MANIFEST_RAW, sha(PARENT_MANIFEST_PATH.read_bytes()))
        self.assertEqual(EXPECTED_PARENT_MANIFEST_CANONICAL, sha(canonical_json_v1_bytes(load_json_strict(PARENT_MANIFEST_PATH))))
        allowed = self.work["files_allowed"]
        expected_restore = {
            *allowed["existing_project_files"],
            *allowed["existing_docs"],
            *allowed["existing_compatibility_files"],
        }
        scope = self.manifest["rollback_scope"]
        self.assertEqual(expected_restore, set(self.entries))
        self.assertEqual(expected_restore, set(scope["restore_exact_paths"]))
        self.assertEqual(set(allowed["as_wp5_additive"]), set(scope["delete_exact_paths"]))
        self.assertFalse(set(self.entries) & set(scope["delete_exact_paths"]))
        names = [entry["snapshot_path"] for entry in self.entries.values()]
        self.assertEqual({"manifest.json", *names}, {path.name for path in SNAPSHOT_ROOT.iterdir() if path.is_file()})
        for entry in self.entries.values():
            decode(entry)

    def test_isolated_restore_contains_only_parent_files(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-as-wp5-parent-") as temp:
            restore_root = Path(temp)
            for path, entry in self.entries.items():
                destination = restore_root / path
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(decode(entry))
            self.assertEqual(
                set(self.entries),
                {path.relative_to(restore_root).as_posix() for path in restore_root.rglob("*") if path.is_file()},
            )

    def test_virtual_rollback_reproduces_pre_as_wp5_candidate(self) -> None:
        parent_bytes = {path: decode(entry) for path, entry in self.entries.items()}
        scope = self.manifest["rollback_scope"]
        delete_paths = set(scope["delete_exact_paths"])
        delete_prefix = scope["delete_evidence_prefix"]
        records: list[dict[str, object]] = []
        restored: set[str] = set()
        observed_paths: set[str] = set()
        for code, path in status():
            if (
                is_dragapult_acceptance_additive(path)
                and path not in POST_ACCEPTANCE_DEVELOPMENT_PARENT_RESTORE_PATHS
            ):
                continue
            if is_as_wp6_path(path) or path in delete_paths or path.startswith(delete_prefix):
                continue
            observed_paths.add(path)
            if path in parent_bytes:
                data = parent_bytes[path]
                restored.add(path)
                if tracked_head_bytes(path) == data:
                    continue
            elif "D" in code:
                data = None
            else:
                data = as_wp6_parent_bytes(
                    path,
                    restore_pre_dragapult_bytes(path, (ROOT / path).read_bytes()),
                )
                if tracked_head_bytes(path) == data:
                    continue
            records.append(
                restore_pre_author_player_owner_record("AS-WP5", {
                    "path": path,
                    "status": code,
                    "bytes": None if data is None else len(data),
                    "sha256": None if data is None else sha(data),
                })
            )
        for path, data in parent_bytes.items():
            if path not in observed_paths:
                self.assertEqual(data, (ROOT / path).read_bytes())
                restored.add(path)
        self.assertEqual(set(parent_bytes), restored)
        records.sort(key=lambda item: item["path"])
        counts = Counter(
            "untracked" if item["status"] == "??" else "deleted" if "D" in item["status"] else "modified"
            for item in records
        )
        self.assertEqual(EXPECTED_PARENT_ENTRY_COUNT, len(records))
        self.assertEqual(EXPECTED_PARENT_COUNTS, dict(counts))
        self.assertEqual(EXPECTED_PARENT_DIGEST, sha(canonical_json_v1_bytes(records)))


if __name__ == "__main__":
    unittest.main()
