from __future__ import annotations

import argparse
import base64
import hashlib
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import load_json_strict  # noqa: E402


SNAPSHOT_ROOT = ROOT / "artifacts/ptcgdap/dragapult_python_e2e/parent_snapshot"
MANIFEST_PATH = SNAPSHOT_ROOT / "manifest.json"
PARENT_PATHS = (
    "docs/ptcgdap/07-decisions-risks-and-open-questions.md",
    "docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md",
    "docs/ptcgdap/STATUS.md",
    "tests/TestSuiteCatalog.gd",
    "tests/ptcgdap/test_as_wp0_parent_snapshot.py",
    "tests/ptcgdap/test_as_wp1_parent_snapshot.py",
    "tests/ptcgdap/test_as_wp2_parent_snapshot.py",
    "tests/ptcgdap/test_as_wp3_parent_snapshot.py",
    "tests/ptcgdap/test_as_wp4_parent_snapshot.py",
    "tests/ptcgdap/test_as_wp5_parent_snapshot.py",
    "tests/ptcgdap/test_as_wp6_parent_snapshot.py",
    "tests/ptcgdap/test_as_wp6_release_evidence.py",
    "tests/ptcgdap/test_p5_wp7_parent_snapshot.py",
)
CATALOG_ADDITION = b'\t"test_dragapult_python_public_strategy_e2e.gd": true,\n'
ROLLBACK_IMPORT = b"from tests.ptcgdap.dragapult_acceptance_rollback import (\n    is_dragapult_acceptance_additive,\n    restore_pre_dragapult_bytes,\n)\n"
ROLLBACK_SKIP = b"            if is_dragapult_acceptance_additive(path):\n                continue\n"
ROLLBACK_RESTORE = b"                data = restore_pre_dragapult_bytes(path, (ROOT / path).read_bytes())\n"
ROLLBACK_ORIGINAL = b"                data = (ROOT / path).read_bytes()\n"
ROLLBACK_TEST_PATHS = frozenset(path for path in PARENT_PATHS if path.endswith("_parent_snapshot.py"))
EVIDENCE_IMPORT = b"from tests.ptcgdap.dragapult_acceptance_rollback import restore_pre_dragapult_bytes\n"
EVIDENCE_READ = b"                value = restore_pre_dragapult_bytes(entry[\"path\"], path.read_bytes())\n"
EVIDENCE_ORIGINAL_READ = b"                value = path.read_bytes()\n"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def snapshot_name(path: str) -> str:
    return path.replace("/", "__") + ".base64"


def parent_bytes(path: str) -> bytes:
    value = (ROOT / path).read_bytes()
    if path == "tests/TestSuiteCatalog.gd":
        if value.count(CATALOG_ADDITION) != 1:
            raise RuntimeError("unable to reconstruct pre-Dragapult TestSuiteCatalog bytes")
        value = value.replace(CATALOG_ADDITION, b"", 1)
    if path in ROLLBACK_TEST_PATHS:
        if value.count(ROLLBACK_IMPORT) != 1 or value.count(ROLLBACK_SKIP) != 1:
            raise RuntimeError(f"unable to reconstruct pre-Dragapult rollback test bytes: {path}")
        value = value.replace(ROLLBACK_IMPORT, b"", 1)
        value = value.replace(ROLLBACK_SKIP, b"", 1)
        direct_count = value.count(ROLLBACK_RESTORE)
        for helper in (b"as_wp5_parent_bytes", b"as_wp6_parent_bytes"):
            wrapped = (
                b"                data = " + helper + b"(\n"
                b"                    path,\n"
                b"                    restore_pre_dragapult_bytes(path, (ROOT / path).read_bytes()),\n"
                b"                )\n"
            )
            if value.count(wrapped) == 1:
                value = value.replace(
                    wrapped,
                    b"                data = " + helper + b"(path, (ROOT / path).read_bytes())\n",
                    1,
                )
                direct_count += 1
        if value.count(ROLLBACK_RESTORE) == 1:
            value = value.replace(ROLLBACK_RESTORE, ROLLBACK_ORIGINAL, 1)
        elif direct_count != 1:
            raise RuntimeError(f"unable to restore pre-Dragapult data expression: {path}")
    if path == "tests/ptcgdap/test_as_wp6_release_evidence.py" and EVIDENCE_IMPORT in value:
        if value.count(EVIDENCE_IMPORT) != 1 or value.count(EVIDENCE_READ) != 1:
            raise RuntimeError("unable to reconstruct pre-Dragapult AS-WP6 evidence test bytes")
        value = value.replace(EVIDENCE_IMPORT, b"", 1)
        value = value.replace(EVIDENCE_READ, EVIDENCE_ORIGINAL_READ, 1)
    return value


def build_manifest() -> dict[str, object]:
    rows = []
    for path in PARENT_PATHS:
        value = parent_bytes(path)
        rows.append(
            {
                "original_path": path,
                "snapshot_path": snapshot_name(path),
                "bytes": len(value),
                "raw_sha256": sha(value),
            }
        )
    return {
        "schema_version": 1,
        "work_package": "DRA-WINDOWS-PYTHON-E2E",
        "purpose": "exact_parent_bytes_for_future-safe_virtual_rollback",
        "files": rows,
    }


def encoded(value: bytes) -> bytes:
    text = base64.b64encode(value).decode("ascii")
    return ("\n".join(text[index : index + 76] for index in range(0, len(text), 76)) + "\n").encode("ascii")


def write() -> None:
    manifest = build_manifest()
    SNAPSHOT_ROOT.mkdir(parents=True, exist_ok=True)
    for row in manifest["files"]:
        (SNAPSHOT_ROOT / row["snapshot_path"]).write_bytes(encoded(parent_bytes(row["original_path"])))
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=True, indent=2) + "\n", encoding="utf-8", newline="\n")


def check() -> None:
    manifest = load_json_strict(MANIFEST_PATH)
    if type(manifest) is not dict or manifest.get("work_package") != "DRA-WINDOWS-PYTHON-E2E":
        raise RuntimeError("invalid parent snapshot manifest")
    if tuple(row.get("original_path") for row in manifest.get("files", [])) != PARENT_PATHS:
        raise RuntimeError("parent snapshot path drift")
    for row in manifest["files"]:
        source = SNAPSHOT_ROOT / row["snapshot_path"]
        value = base64.b64decode(b"".join(source.read_bytes().split()), validate=True)
        if len(value) != row["bytes"] or sha(value) != row["raw_sha256"]:
            raise RuntimeError(f"parent snapshot drift: {row['original_path']}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write == args.check:
        parser.error("choose exactly one of --write or --check")
    write() if args.write else check()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
