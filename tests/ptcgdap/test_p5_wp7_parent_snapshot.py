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
    is_dragapult_acceptance_additive,
    restore_pre_author_player_owner_record,
    restore_pre_dragapult_bytes,
)
from tests.ptcgdap.test_as_wp5_parent_snapshot import (
    as_wp5_parent_bytes,
    is_as_wp5_parent_clean_path,
    is_as_wp5_path,
)


ROOT = Path(__file__).resolve().parents[2]
SNAPSHOT_ROOT = ROOT / "artifacts/ptcgdap/p5_wp7/parent_snapshot"
MANIFEST_PATH = SNAPSHOT_ROOT / "manifest.json"
SUPPLEMENTAL_ROOT = ROOT / "artifacts/ptcgdap/p5_wp7/supplemental_parent_snapshot"
SUPPLEMENTAL_MANIFEST_PATH = SUPPLEMENTAL_ROOT / "manifest.json"
ANCESTRAL_BRIDGE_PATH = ROOT / "artifacts/ptcgdap/p5_wp7/ancestral_candidate_bridge.json"
PARENT_MANIFEST_PATH = ROOT / "artifacts/ptcgdap/p5_wp6/manifest.json"
SUCCESSOR_MANIFEST_PATHS = (
    ROOT / "artifacts/ptcgdap/as_wp0/parent_snapshot/manifest.json",
    ROOT / "artifacts/ptcgdap/as_wp1/parent_snapshot/manifest.json",
    ROOT / "artifacts/ptcgdap/as_wp2/parent_snapshot/manifest.json",
    ROOT / "artifacts/ptcgdap/as_wp3/parent_snapshot/manifest.json",
)
LATEST_SUCCESSOR_ROOT = ROOT / "artifacts/ptcgdap/as_wp2/parent_snapshot"
AS_WP4_SUCCESSOR_ROOT = ROOT / "artifacts/ptcgdap/as_wp4/parent_snapshot"
AS_WP4_SUCCESSOR_MANIFEST_PATH = AS_WP4_SUCCESSOR_ROOT / "manifest.json"
AS_WP4_WORK_PACKAGE_PATH = ROOT / "artifacts/ptcgdap/as_wp4/work_package.json"
AS_WP4_EVIDENCE_PREFIX = "artifacts/ptcgdap/as_wp4/"
EXPECTED_PARENT_MANIFEST_RAW = "15B4D16AB8E3DDB254B8615187E1CEDF340D3DCFC45DF1C90614ED3E50ACFE09"
EXPECTED_PARENT_MANIFEST_CANONICAL = "ADFBB7ED4D20EB6E750731AAD75302A2E7C59E229CC3A3580548D2F345CB7004"
EXPECTED_PARENT_DIGEST = "DE54EA7E55DF33F6A7773CF900CC4041DEE5B58B8B0A6DB6DAECE474A1265D80"
EXPECTED_COUNTS = {"deleted": 28, "modified": 2, "untracked": 1454}
EXPECTED_MANIFEST_RAW = "0496C6FF64BCFC9CFF0FC2125C1E2672F5D2C461D0345D537C6FD6A7F34C5D87"
EXPECTED_MANIFEST_CANONICAL = "477524688CE1B4D2653C27EE0DFB2B91747F29084A97CD88E5606CF181EF2AEE"
EXPECTED_SUPPLEMENTAL_MANIFEST_RAW = "3AE4A4E480EC3905E9FAFBCE5DCA83670AC593F823D7D62C39668633B886D8EF"
EXPECTED_SUPPLEMENTAL_MANIFEST_CANONICAL = "056D18E4C7FB9ACD0054275FE68D30DFE808722B40AB68C8BE38BA1E06229C35"
EXPECTED_ANCESTRAL_BRIDGE_RAW = "7B223D40557C791BF824715189D999469B649ACFF98F0B0708E9107617F3E933"
EXPECTED_ANCESTRAL_BRIDGE_CANONICAL = "BEDC45821F38DB5517753D02E175F36D56DDBA42D17250ED93C7EBD7BC5B1A66"
EXPECTED_P5_WP6_CANDIDATE = "BA70563C71A6153D0B893FA9438E2F1E18C7663DD8307389F966DB19CEE92197"
ANCESTRAL_CHAIN = (
    "p5_wp6", "p5_wp5", "p5_wp4", "p5_wp3", "p5_wp2", "p5_wp1",
    "p4_wp6", "p4_wp5", "p4_wp4", "p4_wp3", "p4_wp2", "p4_wp1",
    "p3_wp8", "p3_wp7", "p3_wp6", "p3_wp5", "p3_wp4", "p3_wp3", "p3_wp2", "p3_wp1",
    "p2_wp5", "p2_wp4", "p2_wp3", "p2_wp2", "p2_wp1",
)
_ANCESTRAL_BRIDGE_CACHE: dict[str, object] | None = None
_ANCESTRAL_RECORD_CACHE: dict[str, dict[str, object]] | None = None
_ANCESTRAL_PAYLOAD_CACHE: dict[str, bytes] | None = None
_AS_WP4_PARENT_BYTES_CACHE: dict[str, bytes] | None = None


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


def decode_ancestral(entry: dict[str, object], root: Path) -> bytes:
    name = safe_path(entry["snapshot_path"])
    if "/" in name:
        raise AssertionError(name)
    source = (root / name).read_bytes()
    if not source.endswith(b"\n") or b"\r" in source:
        raise AssertionError(name)
    encoded = b"".join(source.splitlines())
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


def is_p5_wp7_path(path: str) -> bool:
    if is_as_wp5_path(path) or is_as_wp5_parent_clean_path(path):
        return True
    if path.startswith("artifacts/ptcgdap/p5_wp7/"):
        return True
    manifest = load_json_strict(MANIFEST_PATH)
    return path in frozenset(manifest["rollback_scope"]["delete_exact_paths"])


def p5_wp7_parent_bytes(path: str, current: bytes) -> bytes:
    global _AS_WP4_PARENT_BYTES_CACHE
    current = as_wp5_parent_bytes(path, current)
    if _AS_WP4_PARENT_BYTES_CACHE is None:
        successor = load_json_strict(AS_WP4_SUCCESSOR_MANIFEST_PATH)
        _AS_WP4_PARENT_BYTES_CACHE = {
            safe_path(entry["original_path"]): decode(entry, AS_WP4_SUCCESSOR_ROOT)
            for entry in successor["files"]
        }
    current = _AS_WP4_PARENT_BYTES_CACHE.get(path, current)
    for entry in load_json_strict(MANIFEST_PATH)["files"]:
        if entry["original_path"] == path:
            return decode(entry)
    for entry in load_json_strict(SUPPLEMENTAL_MANIFEST_PATH)["files"]:
        if entry["original_path"] == path:
            return decode(entry, SUPPLEMENTAL_ROOT)
    return current


def ancestral_bridge() -> dict[str, object]:
    global _ANCESTRAL_BRIDGE_CACHE
    if _ANCESTRAL_BRIDGE_CACHE is None:
        _ANCESTRAL_BRIDGE_CACHE = load_json_strict(ANCESTRAL_BRIDGE_PATH)
    return _ANCESTRAL_BRIDGE_CACHE


def p5_wp6_sealed_record_paths() -> frozenset[str]:
    return frozenset(p5_wp6_sealed_records())


def p5_wp6_sealed_records() -> dict[str, dict[str, object]]:
    global _ANCESTRAL_RECORD_CACHE
    if _ANCESTRAL_RECORD_CACHE is None:
        _ANCESTRAL_RECORD_CACHE = {
            safe_path(entry["path"]): entry for entry in ancestral_bridge()["records"]
        }
    return _ANCESTRAL_RECORD_CACHE


def p5_wp6_sealed_payloads() -> dict[str, bytes]:
    global _ANCESTRAL_PAYLOAD_CACHE
    if _ANCESTRAL_PAYLOAD_CACHE is None:
        result: dict[str, bytes] = {}
        for payload in ancestral_bridge()["replay_payloads"]:
            path = safe_path(payload["path"])
            value = base64.b64decode(payload["payload"], validate=True)
            if len(value) != payload["bytes"] or sha(value) != payload["sha256"]:
                raise AssertionError(f"sealed replay payload drift: {path}")
            result[path] = value
        _ANCESTRAL_PAYLOAD_CACHE = result
    return _ANCESTRAL_PAYLOAD_CACHE


def p5_wp6_sealed_bytes(path: str, current: bytes) -> bytes:
    records = p5_wp6_sealed_records()
    if path not in records:
        raise AssertionError(f"path is absent from sealed P5-WP6 candidate: {path}")
    current = p5_wp6_sealed_payloads().get(path, current)
    record = records[path]
    if len(current) != record["bytes"] or sha(current) != record["sha256"]:
        raise AssertionError(f"current bytes do not match sealed P5-WP6 record: {path}")
    return current


class P5Wp7ParentSnapshotTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        raw = MANIFEST_PATH.read_bytes()
        if sha(raw) != EXPECTED_MANIFEST_RAW:
            raise AssertionError("P5-WP7 snapshot raw drift")
        cls.manifest = load_json_strict(MANIFEST_PATH)
        if sha(canonical_json_v1_bytes(cls.manifest)) != EXPECTED_MANIFEST_CANONICAL:
            raise AssertionError("P5-WP7 snapshot canonical drift")
        cls.entries = {safe_path(entry["original_path"]): entry for entry in cls.manifest["files"]}

    def test_payloads_are_exact_safe_complete_and_bind_parent(self) -> None:
        self.assertEqual(11, self.manifest["file_count"])
        self.assertEqual(11, len(self.entries))
        self.assertIn("docs/ptcgdap/06-first-vertical-slice.md", self.entries)
        self.assertIn("docs/ptcgdap/07-decisions-risks-and-open-questions.md", self.entries)
        parent = self.manifest["parent"]
        self.assertEqual(EXPECTED_PARENT_MANIFEST_RAW, parent["manifest_raw_sha256"])
        self.assertEqual(EXPECTED_PARENT_MANIFEST_CANONICAL, parent["manifest_canonical_sha256"])
        self.assertEqual(1484, parent["worktree_entry_count"])
        self.assertEqual(EXPECTED_COUNTS, parent["worktree_status_counts"])
        self.assertEqual(EXPECTED_PARENT_DIGEST, parent["worktree_snapshot_canonical_sha256"])
        self.assertEqual(EXPECTED_PARENT_MANIFEST_RAW, sha(PARENT_MANIFEST_PATH.read_bytes()))
        self.assertEqual(
            EXPECTED_PARENT_MANIFEST_CANONICAL,
            sha(canonical_json_v1_bytes(load_json_strict(PARENT_MANIFEST_PATH))),
        )
        scope = self.manifest["rollback_scope"]
        self.assertEqual(set(self.entries), set(scope["restore_exact_paths"]))
        self.assertEqual(16, len(set(scope["delete_exact_paths"])))
        self.assertFalse(set(self.entries) & set(scope["delete_exact_paths"]))
        self.assertEqual("artifacts/ptcgdap/p5_wp7/", scope["delete_evidence_prefix"])
        names = [entry["snapshot_path"] for entry in self.entries.values()]
        self.assertEqual(len(names), len(set(names)))
        self.assertEqual(
            {"manifest.json", *names},
            {path.name for path in SNAPSHOT_ROOT.iterdir() if path.is_file()},
        )
        for entry in self.entries.values():
            decode(entry)

    def test_isolated_restore_contains_only_parent_files(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-p5-wp7-parent-") as temp:
            restore_root = Path(temp)
            for path, entry in self.entries.items():
                destination = restore_root / path
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(decode(entry))
            self.assertEqual(
                set(self.entries),
                {path.relative_to(restore_root).as_posix() for path in restore_root.rglob("*") if path.is_file()},
            )

    def test_supplemental_compatibility_snapshots_are_exact_and_disjoint(self) -> None:
        raw = SUPPLEMENTAL_MANIFEST_PATH.read_bytes()
        self.assertEqual(EXPECTED_SUPPLEMENTAL_MANIFEST_RAW, sha(raw))
        supplemental = load_json_strict(SUPPLEMENTAL_MANIFEST_PATH)
        self.assertEqual(
            EXPECTED_SUPPLEMENTAL_MANIFEST_CANONICAL,
            sha(canonical_json_v1_bytes(supplemental)),
        )
        self.assertEqual("P5-WP7-supplemental", supplemental["work_package"])
        self.assertEqual(28, supplemental["file_count"])
        paths = {safe_path(entry["original_path"]) for entry in supplemental["files"]}
        self.assertEqual(28, len(paths))
        self.assertFalse(paths & set(self.entries))
        self.assertIn("tests/ptcgdap/test_p5_wp6_parent_snapshot.py", paths)
        self.assertIn("tests/ptcgdap/test_p5_wp3_boundaries.py", paths)
        self.assertIn("tests/ptcgdap/test_p5_wp6_boundaries.py", paths)
        self.assertEqual([], supplemental["rollback_scope"]["delete_exact_paths"])
        for entry in supplemental["files"]:
            decode(entry, SUPPLEMENTAL_ROOT)

    def test_ancestral_candidate_bridge_is_exact_and_self_contained(self) -> None:
        raw = ANCESTRAL_BRIDGE_PATH.read_bytes()
        self.assertEqual(EXPECTED_ANCESTRAL_BRIDGE_RAW, sha(raw))
        bridge = ancestral_bridge()
        self.assertEqual(EXPECTED_ANCESTRAL_BRIDGE_CANONICAL, sha(canonical_json_v1_bytes(bridge)))
        self.assertEqual("P5-WP7", bridge["work_package"])
        self.assertEqual("e5b49d5640332ffda927a38b587e2f1652c773d4", bridge["source"]["checkpoint_tree_oid"])
        sealed = bridge["sealed_candidate"]
        self.assertEqual(1378, sealed["entry_count"])
        self.assertEqual({"deleted": 28, "modified": 1, "untracked": 1349}, sealed["status_counts"])
        self.assertEqual(EXPECTED_P5_WP6_CANDIDATE, sealed["canonical_records_sha256"])
        records = bridge["records"]
        self.assertEqual(1378, len(records))
        self.assertEqual(sorted(entry["path"] for entry in records), [entry["path"] for entry in records])
        self.assertEqual(1378, len(p5_wp6_sealed_record_paths()))
        self.assertEqual(EXPECTED_P5_WP6_CANDIDATE, sha(canonical_json_v1_bytes(records)))
        payload_paths = {entry["path"] for entry in bridge["replay_payloads"]}
        self.assertEqual({".gitignore", "AGENTS.md"}, payload_paths)
        for path in payload_paths:
            value = p5_wp6_sealed_bytes(path, b"intentionally replaced by the embedded payload")
            record = next(entry for entry in records if entry["path"] == path)
            self.assertEqual(record["bytes"], len(value))
            self.assertEqual(record["sha256"], sha(value))

    def test_ancestral_bridge_replays_all_25_parent_digests(self) -> None:
        records = {entry["path"]: dict(entry) for entry in ancestral_bridge()["records"]}
        reached: list[str] = []
        for work_package in ANCESTRAL_CHAIN:
            snapshot_root = ROOT / "artifacts/ptcgdap" / work_package / "parent_snapshot"
            manifest = load_json_strict(snapshot_root / "manifest.json")
            scope = manifest["rollback_scope"]
            prefixes = list(scope.get("delete_prefixes", []))
            if "delete_evidence_prefix" in scope:
                prefixes.append(scope["delete_evidence_prefix"])
            parent_slug = manifest["parent"]["work_package"].lower().replace("-", "_")
            prefixes.append(f"artifacts/ptcgdap/{parent_slug}/")
            delete_paths = set(scope.get("delete_exact_paths", []))
            for path in list(records):
                if path in delete_paths or any(path.startswith(prefix) for prefix in prefixes):
                    records.pop(path)
            manifests = [(manifest, snapshot_root)]
            supplemental_root = ROOT / "artifacts/ptcgdap" / work_package / "supplemental_parent_snapshot"
            if (supplemental_root / "manifest.json").is_file():
                manifests.append((load_json_strict(supplemental_root / "manifest.json"), supplemental_root))
            for source_manifest, source_root in manifests:
                for entry in source_manifest["files"]:
                    path = safe_path(entry["original_path"])
                    value = decode_ancestral(entry, source_root)
                    status_code = records[path]["status"] if path in records else entry.get("original_git_status", "??")
                    records[path] = {
                        "path": path,
                        "status": status_code,
                        "bytes": len(value),
                        "sha256": sha(value),
                    }
            values = sorted(records.values(), key=lambda item: item["path"])
            parent = manifest["parent"]
            virtual_parent = manifest.get("virtual_parent_worktree", {})
            expected_digest = parent.get("worktree_snapshot_canonical_sha256", virtual_parent.get("canonical_records_sha256"))
            expected_count = parent.get(
                "worktree_entry_count",
                parent.get("worktree_snapshot_entry_count", virtual_parent.get("entry_count")),
            )
            self.assertEqual(expected_count, len(values), work_package)
            self.assertEqual(expected_digest, sha(canonical_json_v1_bytes(values)), work_package)
            reached.append(parent["work_package"])
        self.assertEqual(25, len(reached))
        self.assertEqual("P1-WP3", reached[-1])

    def test_virtual_rollback_reproduces_pre_p5_wp7_handoff_candidate(self) -> None:
        parent_bytes = {path: decode(entry) for path, entry in self.entries.items()}
        supplemental = load_json_strict(SUPPLEMENTAL_MANIFEST_PATH)
        for entry in supplemental["files"]:
            parent_bytes[safe_path(entry["original_path"])] = decode(entry, SUPPLEMENTAL_ROOT)
        delete_paths = set(self.manifest["rollback_scope"]["delete_exact_paths"])
        successor_scopes = [load_json_strict(path)["rollback_scope"] for path in SUCCESSOR_MANIFEST_PATHS]
        successor_delete_paths = {
            path for scope in successor_scopes for path in scope["delete_exact_paths"]
        }
        successor_omit_clean_paths = {
            path for scope in successor_scopes for path in scope.get("omit_parent_clean_paths", [])
        }
        successor_delete_prefixes = [scope["delete_evidence_prefix"] for scope in successor_scopes]
        successor_delete_prefixes.extend(
            scope["delete_fixture_prefix"] for scope in successor_scopes if "delete_fixture_prefix" in scope
        )
        latest_successor = load_json_strict(LATEST_SUCCESSOR_ROOT / "manifest.json")
        latest_parent_bytes = {
            safe_path(entry["original_path"]): decode(entry, LATEST_SUCCESSOR_ROOT)
            for entry in latest_successor["files"]
        }
        as_wp4_successor = load_json_strict(AS_WP4_SUCCESSOR_MANIFEST_PATH)
        as_wp4_parent_bytes = {
            safe_path(entry["original_path"]): decode(entry, AS_WP4_SUCCESSOR_ROOT)
            for entry in as_wp4_successor["files"]
        }
        as_wp4_additive_paths = set(
            load_json_strict(AS_WP4_WORK_PACKAGE_PATH)["files_allowed"]["as_wp4_additive"]
        )
        records: list[dict[str, object]] = []
        restored: set[str] = set()
        for code, path in status():
            if is_dragapult_acceptance_additive(path):
                continue
            if (
                is_as_wp5_path(path)
                or is_as_wp5_parent_clean_path(path)
                or path in as_wp4_additive_paths
                or path.startswith(AS_WP4_EVIDENCE_PREFIX)
                or any(path.startswith(prefix) for prefix in successor_delete_prefixes)
                or path in successor_delete_paths
                or path in successor_omit_clean_paths
                or path.startswith("artifacts/ptcgdap/p5_wp7/")
                or path in delete_paths
            ):
                continue
            if path in parent_bytes:
                data = parent_bytes[path]
                restored.add(path)
            elif path in latest_parent_bytes:
                data = latest_parent_bytes[path]
            elif path in as_wp4_parent_bytes:
                data = as_wp4_parent_bytes[path]
            elif "D" in code:
                data = None
            else:
                data = as_wp5_parent_bytes(
                    path,
                    restore_pre_dragapult_bytes(path, (ROOT / path).read_bytes()),
                )
            records.append(
                restore_pre_author_player_owner_record("P5-WP7", {
                    "path": path,
                    "status": code,
                    "bytes": None if data is None else len(data),
                    "sha256": None if data is None else sha(data),
                })
            )
        self.assertEqual(set(parent_bytes), restored)
        records.sort(key=lambda item: item["path"])
        counts = Counter(
            "untracked" if item["status"] == "??" else "deleted" if "D" in item["status"] else "modified"
            for item in records
        )
        self.assertEqual(1484, len(records))
        self.assertEqual(EXPECTED_COUNTS, dict(counts))
        self.assertEqual(EXPECTED_PARENT_DIGEST, sha(canonical_json_v1_bytes(records)))


if __name__ == "__main__":
    unittest.main()
