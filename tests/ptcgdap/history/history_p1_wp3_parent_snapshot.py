from __future__ import annotations

import base64
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from scripts.ai.ptcgdap.source_lock import (
    canonical_json_v1_bytes,
    load_json_strict,
    sha256_bytes,
)


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE_ROOT = ROOT / "artifacts" / "ptcgdap" / "p1_wp3"
PRIMARY_ROOT = EVIDENCE_ROOT / "parent_snapshot"
SUPPLEMENTAL_ROOT = EVIDENCE_ROOT / "supplemental_parent_snapshot"
PARENT_CONTRACT_SHA256 = (
    "A9BD1BBB725FF002DCE5BF60043AD62AC078EC07E2FDB772ED394AC5FA3EE6F3"
)


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def _decode_snapshot(root: Path, entry: dict[str, object]) -> bytes:
    snapshot_path = root / str(entry["snapshot_path"])
    encoded_bytes = snapshot_path.read_bytes()
    encoded = encoded_bytes.decode("ascii").strip()
    decoded = base64.b64decode(encoded, validate=True)
    if base64.b64encode(decoded).decode("ascii") != encoded:
        raise AssertionError(f"non-canonical base64: {snapshot_path}")
    if _sha256(decoded) != entry["raw_sha256"]:
        raise AssertionError(f"decoded parent hash drift: {snapshot_path}")
    expected_snapshot_hash = entry.get("snapshot_file_raw_sha256")
    if expected_snapshot_hash is not None and _sha256(encoded_bytes) != expected_snapshot_hash:
        raise AssertionError(f"snapshot file hash drift: {snapshot_path}")
    if len(decoded) != entry["bytes"]:
        raise AssertionError(f"decoded parent byte count drift: {snapshot_path}")
    return decoded


class P1Wp3ParentSnapshotTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.primary = load_json_strict(PRIMARY_ROOT / "manifest.json")
        cls.supplemental = load_json_strict(SUPPLEMENTAL_ROOT / "manifest.json")

    def test_primary_and_supplemental_snapshots_are_exact_and_non_overlapping(self) -> None:
        self.assertEqual(self.primary["file_count"], 24)
        self.assertEqual(self.supplemental["file_count"], 7)
        primary_paths = {entry["original_path"] for entry in self.primary["files"]}
        supplemental_paths = {
            entry["original_path"] for entry in self.supplemental["files"]
        }
        self.assertTrue(primary_paths.isdisjoint(supplemental_paths))
        for root, manifest in (
            (PRIMARY_ROOT, self.primary),
            (SUPPLEMENTAL_ROOT, self.supplemental),
        ):
            for entry in manifest["files"]:
                with self.subTest(path=entry["original_path"]):
                    _decode_snapshot(root, entry)

        parent_hashes = load_json_strict(
            ROOT / "artifacts" / "ptcgdap" / "p1_wp2" / "contract_hashes.json"
        )
        recorded = {
            entry["path"]: entry["raw_sha256"]
            for section in ("runtime_files", "test_and_fixture_files")
            for entry in parent_hashes[section]
        }
        for entry in self.supplemental["files"]:
            self.assertEqual(
                entry["raw_sha256"],
                recorded[entry["original_path"]],
            )

    def test_isolated_restore_reloads_the_exact_p1_wp2_contract(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-p1-wp3-rollback-") as temp:
            restore_root = Path(temp)
            for snapshot_root, manifest in (
                (PRIMARY_ROOT, self.primary),
                (SUPPLEMENTAL_ROOT, self.supplemental),
            ):
                for entry in manifest["files"]:
                    destination = restore_root / entry["original_path"]
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    destination.write_bytes(_decode_snapshot(snapshot_root, entry))

            contract_root = restore_root / "contracts" / "ptcgdap"
            bundle_path = contract_root / "cabt_contract_bundle.json"
            self.assertEqual(
                sha256_bytes(canonical_json_v1_bytes(load_json_strict(bundle_path))),
                PARENT_CONTRACT_SHA256,
            )
            self.assertFalse((contract_root / "cabt_selection_profile.json").exists())

            parent_hashes = load_json_strict(
                ROOT / "artifacts" / "ptcgdap" / "p1_wp2" / "contract_hashes.json"
            )
            recorded_runtime = {
                entry["path"]: entry["raw_sha256"]
                for entry in parent_hashes["runtime_files"]
            }
            unchanged_dependency = Path("scripts/ai/ptcgdap/cabt_tree_hash.py")
            dependency_bytes = (ROOT / unchanged_dependency).read_bytes()
            self.assertEqual(
                _sha256(dependency_bytes),
                recorded_runtime[unchanged_dependency.as_posix()],
            )
            restored_dependency = restore_root / unchanged_dependency
            restored_dependency.parent.mkdir(parents=True, exist_ok=True)
            restored_dependency.write_bytes(dependency_bytes)

            probe = r"""
import json
from pathlib import Path
import sys
from ptcgdap import cabt_envelope, cabt_tree_hash, source_lock

contract_root = Path(sys.argv[1]).resolve()
restore_root = Path(sys.argv[2]).resolve()
restored = cabt_envelope._load_contract_set(contract_root)
modules = (cabt_envelope, cabt_tree_hash, source_lock)
for module in modules:
    if not Path(module.__file__).resolve().is_relative_to(restore_root):
        raise SystemExit("live module leaked into rollback probe: " + module.__name__)
print(json.dumps({
    "source_contract_hash": restored.source_contract_hash,
    "typed_profile_id": restored.typed_profile["profile_id"],
    "module_files": [str(Path(module.__file__).resolve()) for module in modules],
}, sort_keys=True))
"""
            environment = dict(os.environ)
            environment["PYTHONPATH"] = str(restore_root / "scripts" / "ai")
            completed = subprocess.run(
                [
                    sys.executable,
                    "-c",
                    probe,
                    str(contract_root),
                    str(restore_root),
                ],
                cwd=restore_root,
                env=environment,
                check=False,
                capture_output=True,
                text=True,
                timeout=30,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            result = json.loads(completed.stdout)
            self.assertEqual(result["source_contract_hash"], PARENT_CONTRACT_SHA256)
            self.assertEqual(
                result["typed_profile_id"],
                "cabt_typed_view_profile_v1",
            )


if __name__ == "__main__":
    unittest.main()
