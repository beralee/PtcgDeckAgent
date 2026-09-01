from __future__ import annotations

import argparse
import hashlib
import io
from pathlib import Path
import struct
from typing import Iterable
import zipfile


PACK_HEADER_MAGIC = 0x43504447
PACK_FORMAT_VERSION = 3
PACK_REL_FILEBASE = 2
PCK_HEADER_BYTES = 112
PCK_ALIGNMENT = 16
FIXED_ZIP_TIME = (1980, 1, 1, 0, 0, 0)
MAX_CONTAINER_BYTES = 1024 * 1024 * 1024
MAX_MEMBER_BYTES = 512 * 1024 * 1024
MAX_TOTAL_MEMBER_BYTES = 768 * 1024 * 1024
MAX_MEMBER_COUNT = 100_000
MAX_PATH_BYTES = 4096


def _sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _align(value: int, boundary: int = PCK_ALIGNMENT) -> int:
    return (-value) % boundary


def _safe_ascii_path(raw: bytes) -> str:
    if not raw or len(raw) > MAX_PATH_BYTES:
        raise ValueError("container path length invalid")
    try:
        path = raw.decode("ascii")
    except UnicodeDecodeError as error:
        raise ValueError("container path must be ASCII") from error
    if (
        path.startswith(("/", "\\"))
        or "\\" in path
        or ":" in path
        or path.endswith("/")
        or any(part in {"", ".", ".."} for part in path.split("/"))
    ):
        raise ValueError("container path is unsafe")
    return path


def _check_unique_paths(paths: Iterable[str]) -> None:
    exact: set[str] = set()
    folded: set[str] = set()
    for path in paths:
        if path in exact or path.casefold() in folded:
            raise ValueError("container path collision")
        exact.add(path)
        folded.add(path.casefold())


def canonicalize_zip_bytes(value: bytes) -> bytes:
    if not value or len(value) > MAX_CONTAINER_BYTES or not zipfile.is_zipfile(io.BytesIO(value)):
        raise ValueError("ZIP container invalid")
    members: dict[str, bytes] = {}
    total_bytes = 0
    try:
        with zipfile.ZipFile(io.BytesIO(value), "r") as source:
            infos = source.infolist()
            if not infos or len(infos) > MAX_MEMBER_COUNT:
                raise ValueError("ZIP member count invalid")
            names: list[str] = []
            for info in infos:
                if info.is_dir() or info.flag_bits & 0x1:
                    raise ValueError("ZIP member profile invalid")
                encoded = info.filename.encode("ascii", "strict")
                path = _safe_ascii_path(encoded)
                names.append(path)
                if info.file_size < 0 or info.file_size > MAX_MEMBER_BYTES:
                    raise ValueError("ZIP member size invalid")
                total_bytes += info.file_size
                if total_bytes > MAX_TOTAL_MEMBER_BYTES:
                    raise ValueError("ZIP total size invalid")
            _check_unique_paths(names)
            for info, path in zip(infos, names, strict=True):
                payload = source.read(info)
                if len(payload) != info.file_size:
                    raise ValueError("ZIP member read size mismatch")
                members[path] = payload
    except (OSError, RuntimeError, zipfile.BadZipFile, UnicodeError) as error:
        raise ValueError("ZIP container invalid") from error

    output = io.BytesIO()
    with zipfile.ZipFile(
        output,
        "w",
        compression=zipfile.ZIP_STORED,
        allowZip64=False,
        strict_timestamps=True,
    ) as archive:
        for path in sorted(members, key=lambda item: item.encode("ascii")):
            info = zipfile.ZipInfo(path, FIXED_ZIP_TIME)
            info.compress_type = zipfile.ZIP_STORED
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            info.internal_attr = 0
            info.flag_bits = 0
            info.extra = b""
            info.comment = b""
            archive.writestr(info, members[path])
        archive.comment = b""
    return output.getvalue()


def _u32(value: bytes, offset: int) -> int:
    return struct.unpack_from("<I", value, offset)[0]


def _u64(value: bytes, offset: int) -> int:
    return struct.unpack_from("<Q", value, offset)[0]


def _parse_pck(
    value: bytes,
    *,
    allow_trailing_zero_padding: bool,
) -> tuple[bytes, tuple[int, int, int], list[tuple[str, bytes, bytes]], int]:
    if not value or len(value) > MAX_CONTAINER_BYTES or len(value) < PCK_HEADER_BYTES + 4:
        raise ValueError("PCK container invalid")
    if _u32(value, 0) != PACK_HEADER_MAGIC:
        raise ValueError("PCK magic invalid")
    if _u32(value, 4) != PACK_FORMAT_VERSION:
        raise ValueError("PCK format version unsupported")
    engine_version = (_u32(value, 8), _u32(value, 12), _u32(value, 16))
    if engine_version[:2] != (4, 6):
        raise ValueError("PCK engine version unsupported")
    if _u32(value, 20) != PACK_REL_FILEBASE:
        raise ValueError("PCK flags unsupported")
    file_base = _u64(value, 24)
    directory_offset = _u64(value, 32)
    if file_base != PCK_HEADER_BYTES or any(value[40:PCK_HEADER_BYTES]):
        raise ValueError("PCK header profile invalid")
    if directory_offset < file_base or directory_offset + 4 > len(value):
        raise ValueError("PCK directory offset invalid")

    position = directory_offset
    count = _u32(value, position)
    position += 4
    if count <= 0 or count > MAX_MEMBER_COUNT:
        raise ValueError("PCK member count invalid")
    entries: list[tuple[str, bytes, bytes]] = []
    ranges: list[tuple[int, int]] = []
    total_bytes = 0
    for _ in range(count):
        if position + 4 > len(value):
            raise ValueError("PCK directory truncated")
        path_bytes = _u32(value, position)
        position += 4
        if path_bytes <= 0 or path_bytes > MAX_PATH_BYTES or position + path_bytes + 36 > len(value):
            raise ValueError("PCK path length invalid")
        raw_path = value[position : position + path_bytes]
        position += path_bytes
        logical_raw = raw_path.rstrip(b"\0")
        if raw_path != logical_raw + (b"\0" * _align(len(logical_raw), 4)):
            raise ValueError("PCK path padding invalid")
        path = _safe_ascii_path(logical_raw)
        offset = _u64(value, position)
        size = _u64(value, position + 8)
        expected_md5 = value[position + 16 : position + 32]
        flags = _u32(value, position + 32)
        position += 36
        if flags != 0 or offset % PCK_ALIGNMENT != 0:
            raise ValueError("PCK member profile invalid")
        if size > MAX_MEMBER_BYTES:
            raise ValueError("PCK member size invalid")
        total_bytes += size
        if total_bytes > MAX_TOTAL_MEMBER_BYTES:
            raise ValueError("PCK total size invalid")
        start = file_base + offset
        end = start + size
        if start < file_base or end < start or end > directory_offset:
            raise ValueError("PCK member range invalid")
        payload = value[start:end]
        if hashlib.md5(payload).digest() != expected_md5:  # noqa: S324 - Godot PCK v3 field.
            raise ValueError("PCK member MD5 mismatch")
        entries.append((path, raw_path, payload))
        ranges.append((start, end))

    _check_unique_paths(path for path, _, _ in entries)
    previous_end = file_base
    for start, end in sorted(ranges):
        if start < previous_end:
            raise ValueError("PCK member ranges overlap")
        if any(value[previous_end:start]):
            raise ValueError("PCK alignment padding invalid")
        previous_end = end
    if any(value[previous_end:directory_offset]):
        raise ValueError("PCK data padding invalid")
    trailing = value[position:]
    if trailing and (
        not allow_trailing_zero_padding
        or len(trailing) >= PCK_ALIGNMENT
        or any(trailing)
    ):
        raise ValueError("PCK trailing data invalid")
    return value[:file_base], engine_version, entries, position


def _build_canonical_pck(header: bytes, entries: list[tuple[str, bytes, bytes]]) -> bytes:
    ordered = sorted(entries, key=lambda item: item[0].encode("ascii"))
    output = io.BytesIO()
    output.write(header)
    directory: list[tuple[bytes, int, bytes]] = []
    for path, _, payload in ordered:
        output.write(b"\0" * _align(output.tell() - len(header)))
        offset = output.tell() - len(header)
        output.write(payload)
        logical = path.encode("ascii")
        raw_path = logical + (b"\0" * _align(len(logical), 4))
        directory.append((raw_path, offset, payload))
    output.write(b"\0" * _align(output.tell()))
    directory_offset = output.tell()
    output.write(struct.pack("<I", len(directory)))
    for raw_path, offset, payload in directory:
        output.write(struct.pack("<I", len(raw_path)))
        output.write(raw_path)
        output.write(struct.pack("<QQ", offset, len(payload)))
        output.write(hashlib.md5(payload).digest())  # noqa: S324 - Godot PCK v3 field.
        output.write(struct.pack("<I", 0))
    value = bytearray(output.getvalue())
    struct.pack_into("<Q", value, 32, directory_offset)
    return bytes(value)


def canonicalize_pck_bytes(value: bytes) -> bytes:
    header, _, entries, _ = _parse_pck(value, allow_trailing_zero_padding=False)
    return _build_canonical_pck(header, entries)


def read_pck_members(value: bytes) -> dict[str, bytes]:
    _, _, entries, _ = _parse_pck(value, allow_trailing_zero_padding=False)
    return {path: payload for path, _, payload in entries}


def canonicalize_embedded_executable_bytes(value: bytes) -> bytes:
    if len(value) < PCK_HEADER_BYTES + 14 or not value.startswith(b"MZ"):
        raise ValueError("embedded PCK executable invalid")
    if _u32(value, len(value) - 4) != PACK_HEADER_MAGIC:
        raise ValueError("embedded PCK trailer invalid")
    embedded_size = _u64(value, len(value) - 12)
    if embedded_size <= PCK_HEADER_BYTES or embedded_size > len(value) - 12:
        raise ValueError("embedded PCK size invalid")
    embedded_start = len(value) - 12 - embedded_size
    if embedded_start < 2 or _u32(value, embedded_start) != PACK_HEADER_MAGIC:
        raise ValueError("embedded PCK start invalid")
    segment = value[embedded_start : len(value) - 12]
    header, _, entries, directory_end = _parse_pck(
        segment,
        allow_trailing_zero_padding=True,
    )
    canonical = _build_canonical_pck(header, entries)
    if len(canonical) > len(segment) or len(segment) - directory_end >= PCK_ALIGNMENT:
        raise ValueError("embedded PCK canonical size invalid")
    padding = b"\0" * (len(segment) - len(canonical))
    result = value[:embedded_start] + canonical + padding + value[len(value) - 12 :]
    if len(result) != len(value):
        raise ValueError("embedded PCK executable size changed")
    return result


def _canonicalize(kind: str, value: bytes) -> bytes:
    if kind == "zip":
        return canonicalize_zip_bytes(value)
    if kind == "pck":
        return canonicalize_pck_bytes(value)
    if kind == "embedded-exe":
        return canonicalize_embedded_executable_bytes(value)
    raise ValueError("unknown canonicalization kind")


def _regular_input(path: Path) -> Path:
    if path.is_symlink() or not path.is_file():
        raise ValueError("input must be a regular non-symlink file")
    return path.resolve(strict=True)


def _exclusive_output(path: Path, value: bytes) -> None:
    if path.exists() or path.is_symlink():
        raise ValueError("output already exists")
    parent = path.parent.resolve(strict=True)
    if not parent.is_dir() or parent.is_symlink():
        raise ValueError("output parent invalid")
    destination = parent / path.name
    with destination.open("xb") as handle:
        handle.write(value)
        handle.flush()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Canonicalize a Godot 4.6 Windows export container.")
    parser.add_argument("--kind", required=True, choices=("zip", "pck", "embedded-exe"))
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args(argv)
    source = _regular_input(args.input)
    destination = args.output.absolute()
    if destination == source:
        raise ValueError("input and output must differ")
    raw = source.read_bytes()
    canonical = _canonicalize(args.kind, raw)
    if _canonicalize(args.kind, canonical) != canonical:
        raise ValueError("canonicalization is not idempotent")
    _exclusive_output(destination, canonical)
    print(f"kind={args.kind}")
    print(f"input_bytes={len(raw)}")
    print(f"input_sha256={_sha256(raw)}")
    print(f"output_bytes={len(canonical)}")
    print(f"output_sha256={_sha256(canonical)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
