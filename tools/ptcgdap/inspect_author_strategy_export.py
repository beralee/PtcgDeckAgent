from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import sys
import zipfile


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import load_json_strict


MAX_EXPORT_ENTRIES = 100_000
MAX_EXPORT_UNCOMPRESSED_BYTES = 4 * 1024 * 1024 * 1024


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _safe_path(raw: object) -> str:
    if not isinstance(raw, str) or not raw or "\\" in raw or "\0" in raw:
        raise ValueError("unsafe export path")
    path = PurePosixPath(raw)
    if path.is_absolute() or "." in path.parts or ".." in path.parts or any(not part for part in path.parts):
        raise ValueError("unsafe export path")
    if ":" in path.parts[0] or path.as_posix() != raw:
        raise ValueError("unsafe export path")
    return raw


def inspect_zip_inventory(
    archive_bytes: bytes,
    *,
    required_paths: list[str] | tuple[str, ...],
    path_prefix: str = "",
) -> dict[str, object]:
    if type(archive_bytes) is not bytes:
        raise TypeError("archive_bytes must be exact bytes")
    try:
        required = [_safe_path(path) for path in required_paths]
        if path_prefix:
            normalized_prefix = _safe_path(path_prefix.rstrip("/")) + "/"
        else:
            normalized_prefix = ""
        if len(required) != len(set(required)):
            raise ValueError("duplicate required path")
        with zipfile.ZipFile(io.BytesIO(archive_bytes), "r") as archive:
            infos = archive.infolist()
            if len(infos) > MAX_EXPORT_ENTRIES:
                raise ValueError("export entry limit exceeded")
            names: list[str] = []
            folded: set[str] = set()
            total = 0
            members: list[dict[str, object]] = []
            for info in infos:
                name = _safe_path(info.filename)
                if name in names or name.casefold() in folded or info.flag_bits & 0x1:
                    raise ValueError("duplicate or encrypted export member")
                names.append(name)
                folded.add(name.casefold())
                total += info.file_size
                if total > MAX_EXPORT_UNCOMPRESSED_BYTES:
                    raise ValueError("export size limit exceeded")
                value = archive.read(info)
                if len(value) != info.file_size:
                    raise ValueError("truncated export member")
                members.append({"path": name, "bytes": len(value), "sha256": _sha(value)})
    except (OSError, ValueError, zipfile.BadZipFile, RuntimeError):
        return {
            "document_type": "author_strategy_export_inventory_report_v1",
            "schema_version": 1,
            "accepted": False,
            "error_code": "export_inventory_archive_invalid",
            "archive_sha256": _sha(archive_bytes),
            "required_path_count": len(required_paths),
            "present_required_path_count": 0,
            "missing_paths": list(required_paths),
            "members": [],
        }
    present = set(names)
    missing = []
    for path in required:
        physical_path = normalized_prefix + path
        alternatives = {physical_path}
        if path.endswith(".gd"):
            alternatives.add(normalized_prefix + path[:-3] + ".gdc")
        if present.isdisjoint(alternatives):
            missing.append(path)
    missing.sort()
    return {
        "document_type": "author_strategy_export_inventory_report_v1",
        "schema_version": 1,
        "accepted": not missing,
        "error_code": "" if not missing else "export_inventory_missing",
        "archive_sha256": _sha(archive_bytes),
        "archive_bytes": len(archive_bytes),
        "entry_count": len(names),
        "uncompressed_bytes": total,
        "required_path_count": len(required),
        "present_required_path_count": len(required) - len(missing),
        "missing_paths": missing,
        "members": members,
    }


def required_paths_from_profile(root: Path = ROOT) -> list[str]:
    profile = load_json_strict(root / "contracts/ptcgdap/author_strategy_release_profile.json")
    paths = profile.get("required_export_paths")
    if type(paths) is not list or not paths or any(type(path) is not str for path in paths):
        raise ValueError("release profile has invalid required_export_paths")
    return list(paths)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--prefix", default="")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()
    report = inspect_zip_inventory(
        args.archive.read_bytes(),
        required_paths=required_paths_from_profile(),
        path_prefix=args.prefix,
    )
    rendered = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    if args.verbose:
        print(rendered, end="")
    else:
        print(json.dumps({
            "accepted": report["accepted"],
            "error_code": report["error_code"],
            "archive_sha256": report["archive_sha256"],
            "entry_count": report.get("entry_count", 0),
            "required_path_count": report["required_path_count"],
            "present_required_path_count": report["present_required_path_count"],
            "missing_paths": report["missing_paths"],
        }, ensure_ascii=False))
    return 0 if report["accepted"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
