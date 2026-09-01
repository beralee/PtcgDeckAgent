from __future__ import annotations

import hashlib
import io
from pathlib import Path
import struct
import tempfile
import unittest
import zipfile

from tools.ptcgdap.canonicalize_godot_export import (
    PACK_HEADER_MAGIC,
    canonicalize_embedded_executable_bytes,
    canonicalize_pck_bytes,
    canonicalize_zip_bytes,
    main,
    read_pck_members,
)


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _padded_path(path: str) -> bytes:
    value = path.encode("ascii")
    return value + (b"\0" * ((-len(value)) % 4))


def _build_pck(members: dict[str, bytes], data_order: list[str]) -> bytes:
    header = bytearray(112)
    struct.pack_into("<IIIIII", header, 0, PACK_HEADER_MAGIC, 3, 4, 6, 1, 2)
    struct.pack_into("<Q", header, 24, len(header))
    output = io.BytesIO()
    output.write(header)
    offsets: dict[str, int] = {}
    for path in data_order:
        output.write(b"\0" * (-(output.tell() - len(header)) % 16))
        offsets[path] = output.tell() - len(header)
        output.write(members[path])
    output.write(b"\0" * (-output.tell() % 16))
    directory_offset = output.tell()
    output.write(struct.pack("<I", len(members)))
    for path in sorted(members, key=lambda value: value.encode("ascii")):
        raw_path = _padded_path(path)
        payload = members[path]
        output.write(struct.pack("<I", len(raw_path)))
        output.write(raw_path)
        output.write(struct.pack("<QQ", offsets[path], len(payload)))
        output.write(hashlib.md5(payload).digest())  # noqa: S324 - Godot PCK v3 field.
        output.write(struct.pack("<I", 0))
    value = bytearray(output.getvalue())
    struct.pack_into("<Q", value, 32, directory_offset)
    return bytes(value)


def _build_zip(members: dict[str, bytes], order: list[str]) -> bytes:
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in order:
            info = zipfile.ZipInfo(path, (2026, 8, 14, 12, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, members[path])
    return output.getvalue()


class GodotExportCanonicalizerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.members = {
            "project.binary": b"project-settings",
            "scripts/main.gdc": b"compiled-script",
            "data/cards.json": b'{"cards":[]}',
        }

    def test_zip_member_order_and_metadata_canonicalize_to_exact_bytes(self) -> None:
        first = _build_zip(self.members, list(self.members))
        second = _build_zip(self.members, list(reversed(self.members)))
        self.assertNotEqual(_sha(first), _sha(second))
        canonical_a = canonicalize_zip_bytes(first)
        canonical_b = canonicalize_zip_bytes(second)
        self.assertEqual(canonical_a, canonical_b)
        with zipfile.ZipFile(io.BytesIO(canonical_a)) as archive:
            infos = archive.infolist()
            self.assertEqual(
                [info.filename for info in infos],
                sorted(self.members, key=lambda value: value.encode("ascii")),
            )
            self.assertTrue(all(info.compress_type == zipfile.ZIP_STORED for info in infos))
            self.assertEqual({info.date_time for info in infos}, {(1980, 1, 1, 0, 0, 0)})
            self.assertEqual({info.filename: archive.read(info) for info in infos}, self.members)

    def test_pck_data_order_canonicalizes_without_changing_members(self) -> None:
        first = _build_pck(self.members, list(self.members))
        second = _build_pck(self.members, list(reversed(self.members)))
        self.assertNotEqual(_sha(first), _sha(second))
        canonical_a = canonicalize_pck_bytes(first)
        canonical_b = canonicalize_pck_bytes(second)
        self.assertEqual(canonical_a, canonical_b)
        self.assertEqual(read_pck_members(canonical_a), self.members)
        self.assertEqual(canonicalize_pck_bytes(canonical_a), canonical_a)

    def test_embedded_executable_preserves_prefix_trailer_and_size(self) -> None:
        prefix = b"MZ" + (b"\x7f" * 510)
        pck_a = _build_pck(self.members, list(self.members))
        pck_b = _build_pck(self.members, list(reversed(self.members)))
        trailer_a = struct.pack("<Q", len(pck_a) + 4) + struct.pack("<I", PACK_HEADER_MAGIC)
        trailer_b = struct.pack("<Q", len(pck_b) + 4) + struct.pack("<I", PACK_HEADER_MAGIC)
        first = prefix + pck_a + (b"\0" * 4) + trailer_a
        second = prefix + pck_b + (b"\0" * 4) + trailer_b
        canonical_a = canonicalize_embedded_executable_bytes(first)
        canonical_b = canonicalize_embedded_executable_bytes(second)
        self.assertEqual(canonical_a, canonical_b)
        self.assertEqual(len(canonical_a), len(first))
        self.assertEqual(canonical_a[: len(prefix)], prefix)
        self.assertEqual(canonical_a[-12:], trailer_a)

    def test_invalid_or_unsafe_containers_fail_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "ZIP"):
            canonicalize_zip_bytes(b"not-a-zip")
        unsafe = _build_pck({"../secret": b"x"}, ["../secret"])
        with self.assertRaisesRegex(ValueError, "path"):
            canonicalize_pck_bytes(unsafe)
        with self.assertRaisesRegex(ValueError, "embedded PCK"):
            canonicalize_embedded_executable_bytes(b"MZbroken")

    def test_cli_refuses_overwrite_and_writes_exact_canonical_output(self) -> None:
        source = _build_pck(self.members, list(reversed(self.members)))
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            input_path = root / "input.pck"
            output_path = root / "output.pck"
            input_path.write_bytes(source)
            self.assertEqual(main(["--kind", "pck", "--input", str(input_path), "--output", str(output_path)]), 0)
            self.assertEqual(output_path.read_bytes(), canonicalize_pck_bytes(source))
            with self.assertRaisesRegex(ValueError, "already exists"):
                main(["--kind", "pck", "--input", str(input_path), "--output", str(output_path)])


if __name__ == "__main__":
    unittest.main()
