from __future__ import annotations

import base64
from collections import Counter
import hashlib
from pathlib import Path, PurePosixPath
import subprocess
import tempfile
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
SNAPSHOT_ROOT = ROOT / "artifacts/ptcgdap/p5_wp6/parent_snapshot"
MANIFEST_PATH = SNAPSHOT_ROOT / "manifest.json"
SUPPLEMENTAL_ROOT = ROOT / "artifacts/ptcgdap/p5_wp6/supplemental_parent_snapshot"
SUPPLEMENTAL_MANIFEST_PATH = SUPPLEMENTAL_ROOT / "manifest.json"
PARENT_MANIFEST_PATH = ROOT / "artifacts/ptcgdap/p5_wp5/manifest.json"
EXPECTED_PARENT_RAW = "F6EB27CC3CEB47B6FFA416137AC59BC0556C772A841CEB0C091656332776C256"
EXPECTED_PARENT_CANONICAL = "04C37054F6F277BE0EC82DFE748D7479A54493D2200943E908B595B82D9EDC3C"
EXPECTED_PARENT_DIGEST = "271575C318DF50AEBFDC0E63BD7CD2B7F5A8DE8A6ADB854570C2687F04D55515"
EXPECTED_COUNTS = {"untracked": 1295, "deleted": 28, "modified": 1}
EXPECTED_MANIFEST_RAW = "AC14255218D5AC3CF0D64F97D19344377005B92209A6CABA69686FC0D6EFFAED"
EXPECTED_MANIFEST_CANONICAL = "E36D3663F9DA96BFF062B5D868B33E554FFA8634EFCCDB105FD14C41918A8E72"


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


def _supplemental() -> dict[str, object]:
    return load_json_strict(SUPPLEMENTAL_MANIFEST_PATH)


def is_p5_wp6_path(path: str) -> bool:
    from tests.ptcgdap.test_p5_wp7_parent_snapshot import p5_wp6_sealed_record_paths

    if path not in p5_wp6_sealed_record_paths():
        return True
    if path.startswith("artifacts/ptcgdap/p5_wp6/"):
        return True
    manifest = load_json_strict(MANIFEST_PATH)
    return path in frozenset(manifest["rollback_scope"]["delete_exact_paths"])


def p5_wp6_parent_bytes(path: str, current: bytes) -> bytes:
    from tests.ptcgdap.test_p5_wp7_parent_snapshot import p5_wp6_sealed_bytes, p5_wp7_parent_bytes

    current = p5_wp7_parent_bytes(path, current)
    for entry in load_json_strict(MANIFEST_PATH)["files"]:
        if entry["original_path"] == path:
            return decode(entry)
    for entry in _supplemental()["files"]:
        if entry["original_path"] == path:
            return decode(entry, SUPPLEMENTAL_ROOT)
    return p5_wp6_sealed_bytes(path, current)


def status() -> list[tuple[str, str]]:
    output = subprocess.run(
        ["git", "status", "--porcelain=v1", "-z", "--untracked-files=all"],
        cwd=ROOT, check=True, capture_output=True,
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


class P5Wp6ParentSnapshotTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        raw = MANIFEST_PATH.read_bytes()
        if sha(raw) != EXPECTED_MANIFEST_RAW:
            raise AssertionError("P5-WP6 snapshot raw drift")
        cls.manifest = load_json_strict(MANIFEST_PATH)
        if sha(canonical_json_v1_bytes(cls.manifest)) != EXPECTED_MANIFEST_CANONICAL:
            raise AssertionError("P5-WP6 snapshot canonical drift")
        cls.entries = {safe_path(entry["original_path"]): entry for entry in cls.manifest["files"]}

    def test_payloads_are_exact_safe_complete_and_bind_parent(self) -> None:
        self.assertEqual(19, self.manifest["file_count"])
        self.assertEqual(19, len(self.entries))
        parent = self.manifest["parent"]
        self.assertEqual(EXPECTED_PARENT_RAW, parent["manifest_raw_sha256"])
        self.assertEqual(EXPECTED_PARENT_CANONICAL, parent["manifest_canonical_sha256"])
        self.assertEqual(EXPECTED_PARENT_DIGEST, parent["worktree_snapshot_canonical_sha256"])
        self.assertEqual(EXPECTED_COUNTS, parent["worktree_status_counts"])
        self.assertEqual(EXPECTED_PARENT_RAW, sha(PARENT_MANIFEST_PATH.read_bytes()))
        self.assertEqual(EXPECTED_PARENT_CANONICAL, sha(canonical_json_v1_bytes(load_json_strict(PARENT_MANIFEST_PATH))))
        scope = self.manifest["rollback_scope"]
        self.assertEqual(set(self.entries), set(scope["restore_exact_paths"]))
        self.assertEqual(16, len(set(scope["delete_exact_paths"])))
        self.assertFalse(set(self.entries) & set(scope["delete_exact_paths"]))
        self.assertEqual("artifacts/ptcgdap/p5_wp6/", scope["delete_evidence_prefix"])
        names = [entry["snapshot_path"] for entry in self.entries.values()]
        self.assertEqual(len(names), len(set(names)))
        self.assertEqual({"manifest.json", *names}, {path.name for path in SNAPSHOT_ROOT.iterdir() if path.is_file()})
        for entry in self.entries.values():
            decode(entry)

    def test_isolated_restore_contains_only_parent_files(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-p5-wp5-parent-") as temp:
            restore_root = Path(temp)
            for path, entry in self.entries.items():
                destination = restore_root / path
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(decode(entry))
            self.assertEqual(
                set(self.entries),
                {path.relative_to(restore_root).as_posix() for path in restore_root.rglob("*") if path.is_file()},
            )

    def test_supplemental_parent_snapshots_are_exact_and_disjoint(self) -> None:
        supplemental = _supplemental()
        self.assertEqual("P5-WP6-supplemental", supplemental["work_package"])
        self.assertEqual(7, supplemental["file_count"])
        paths = {entry["original_path"] for entry in supplemental["files"]}
        self.assertEqual(7, len(paths))
        self.assertIn("scripts/ai/ptcgdap/cabt/CabtContractSet.gd", paths)
        self.assertFalse(paths & set(self.entries))
        for entry in supplemental["files"]:
            decode(entry, SUPPLEMENTAL_ROOT)

    def test_virtual_rollback_reproduces_p5_wp5_candidate(self) -> None:
        from tests.ptcgdap.test_p5_wp7_parent_snapshot import p5_wp6_sealed_bytes, p5_wp7_parent_bytes

        parent_bytes = {path: decode(entry) for path, entry in self.entries.items()}
        supplemental = _supplemental()
        for entry in supplemental["files"]:
            parent_bytes[entry["original_path"]] = decode(entry, SUPPLEMENTAL_ROOT)
        delete_paths = set(self.manifest["rollback_scope"]["delete_exact_paths"])
        records: list[dict[str, object]] = []
        restored: set[str] = set()
        for code, path in status():
            if path.startswith("artifacts/ptcgdap/p5_wp5/") or is_p5_wp6_path(path) or path in delete_paths:
                continue
            if path in parent_bytes:
                data = parent_bytes[path]
                restored.add(path)
            elif "D" in code:
                data = None
            else:
                current = (ROOT / path).read_bytes()
                data = p5_wp6_sealed_bytes(path, p5_wp7_parent_bytes(path, current))
            records.append({"path": path, "status": code, "bytes": None if data is None else len(data), "sha256": None if data is None else sha(data)})
        self.assertEqual(set(parent_bytes), restored)
        records.sort(key=lambda item: item["path"])
        counts = Counter("untracked" if item["status"] == "??" else "deleted" if "D" in item["status"] else "modified" for item in records)
        self.assertEqual(1324, len(records))
        self.assertEqual(EXPECTED_COUNTS, dict(counts))
        self.assertEqual(EXPECTED_PARENT_DIGEST, sha(canonical_json_v1_bytes(records)))


if __name__ == "__main__":
    unittest.main()
