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
SNAPSHOT_ROOT = ROOT / "artifacts/ptcgdap/p5_wp4/parent_snapshot"
MANIFEST_PATH = SNAPSHOT_ROOT / "manifest.json"
PARENT_MANIFEST_PATH = ROOT / "artifacts/ptcgdap/p5_wp3/manifest.json"
EXPECTED_PARENT_MANIFEST_RAW = "D71340F8A8EC0919B5A27F051753B115B346702BCFAC0C1ABFABC5F3AC00A473"
EXPECTED_PARENT_MANIFEST_CANONICAL = "6593A8C5A88495785257A3AFEF9EB63BA1ACD22D2F200636D3DB102FA23A6BDD"
EXPECTED_PARENT_DIGEST = "0B1FD8EA11D8DDC50B83900D6057427EB8BD3F7C913E8FA1D3EA67DAE374C891"
EXPECTED_COUNTS = {"untracked": 1163, "deleted": 28, "modified": 1}
EXPECTED_MANIFEST_RAW = "919C9EE7B611C51BADFB427147CF23339D6F125DCD6458E5B62196387ACCF53D"
EXPECTED_MANIFEST_CANONICAL = "53CA111448A22F8FEE7D45155AB5DAD360C38C986978CA2DA4F9FD7971DF69F0"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def safe_path(raw: object) -> str:
    if not isinstance(raw, str) or not raw or "\\" in raw or "\0" in raw:
        raise AssertionError(raw)
    path = PurePosixPath(raw)
    if path.is_absolute() or "." in path.parts or ".." in path.parts or ":" in path.parts[0] or path.as_posix() != raw:
        raise AssertionError(raw)
    return raw


def _manifest() -> dict[str, object]:
    return load_json_strict(MANIFEST_PATH)


def is_p5_wp4_path(path: str) -> bool:
    if path.startswith("artifacts/ptcgdap/p5_wp4/"):
        return True
    if MANIFEST_PATH.is_file() and path in frozenset(_manifest()["rollback_scope"]["delete_exact_paths"]):
        return True
    try:
        from tests.ptcgdap.test_p5_wp5_parent_snapshot import is_p5_wp5_path
    except ImportError:
        return False
    return is_p5_wp5_path(path)


def p5_wp5_parent_bytes(path: str, current: bytes) -> bytes:
    """Return the exact P5-WP4 byte for a path amended by P5-WP5."""
    try:
        from tests.ptcgdap.test_p5_wp5_parent_snapshot import p5_wp5_parent_bytes as restore
    except ImportError:
        return current
    return restore(path, current)


def decode(entry: dict[str, object]) -> bytes:
    name = safe_path(entry["snapshot_path"])
    if "/" in name:
        raise AssertionError(name)
    source = (SNAPSHOT_ROOT / name).read_bytes()
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
        cwd=ROOT, check=True, capture_output=True,
    ).stdout
    result = []
    for record in output.split(b"\0"):
        if not record:
            continue
        code = record[:2].decode("ascii")
        path = safe_path(record[3:].decode("utf-8").replace("\\", "/"))
        if "R" in code or "C" in code:
            raise AssertionError("rename/copy outside snapshot algorithm")
        result.append((code, path))
    return result


class P5Wp4ParentSnapshotTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        raw = MANIFEST_PATH.read_bytes()
        if sha(raw) != EXPECTED_MANIFEST_RAW:
            raise AssertionError("P5-WP4 snapshot raw drift")
        cls.manifest = load_json_strict(MANIFEST_PATH)
        if sha(canonical_json_v1_bytes(cls.manifest)) != EXPECTED_MANIFEST_CANONICAL:
            raise AssertionError("P5-WP4 snapshot canonical drift")
        cls.entries = {safe_path(entry["original_path"]): entry for entry in cls.manifest["files"]}

    def test_payloads_are_exact_safe_complete_and_bind_parent(self) -> None:
        self.assertEqual(37, self.manifest["file_count"])
        self.assertEqual(37, len(self.entries))
        parent = self.manifest["parent"]
        self.assertEqual(EXPECTED_PARENT_MANIFEST_RAW, parent["manifest_raw_sha256"])
        self.assertEqual(EXPECTED_PARENT_MANIFEST_CANONICAL, parent["manifest_canonical_sha256"])
        self.assertEqual(EXPECTED_PARENT_DIGEST, parent["worktree_snapshot_canonical_sha256"])
        self.assertEqual(EXPECTED_COUNTS, parent["worktree_status_counts"])
        self.assertEqual(EXPECTED_PARENT_MANIFEST_RAW, sha(PARENT_MANIFEST_PATH.read_bytes()))
        scope = self.manifest["rollback_scope"]
        self.assertEqual(set(self.entries), set(scope["restore_exact_paths"]))
        self.assertEqual(15, len(set(scope["delete_exact_paths"])))
        self.assertEqual("artifacts/ptcgdap/p5_wp4/", scope["delete_evidence_prefix"])
        names = [entry["snapshot_path"] for entry in self.entries.values()]
        self.assertEqual(len(names), len(set(names)))
        self.assertEqual({"manifest.json", *names}, {path.name for path in SNAPSHOT_ROOT.iterdir() if path.is_file()})
        for entry in self.entries.values():
            decode(entry)

    def test_isolated_restore_contains_only_parent_files(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-p5-wp3-parent-") as temp:
            restore_root = Path(temp)
            for path, entry in self.entries.items():
                destination = restore_root / path
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(decode(entry))
            self.assertEqual(set(self.entries), {path.relative_to(restore_root).as_posix() for path in restore_root.rglob("*") if path.is_file()})

    def test_virtual_rollback_reproduces_p5_wp3_candidate(self) -> None:
        parent_bytes = {path: decode(entry) for path, entry in self.entries.items()}
        delete_paths = set(self.manifest["rollback_scope"]["delete_exact_paths"])
        records = []
        restored = set()
        for code, path in status():
            if path.startswith("artifacts/ptcgdap/p5_wp3/") or is_p5_wp4_path(path) or path in delete_paths:
                continue
            if path in parent_bytes:
                data = parent_bytes[path]
                restored.add(path)
            elif "D" in code:
                data = None
            else:
                data = p5_wp5_parent_bytes(path, (ROOT / path).read_bytes())
            records.append({"path": path, "status": code, "bytes": None if data is None else len(data), "sha256": None if data is None else sha(data)})
        self.assertEqual(set(parent_bytes), restored)
        records.sort(key=lambda item: item["path"])
        counts = Counter("untracked" if item["status"] == "??" else "deleted" if "D" in item["status"] else "modified" for item in records)
        self.assertEqual(1192, len(records))
        self.assertEqual(EXPECTED_COUNTS, dict(counts))
        self.assertEqual(EXPECTED_PARENT_DIGEST, sha(canonical_json_v1_bytes(records)))


if __name__ == "__main__":
    unittest.main()
