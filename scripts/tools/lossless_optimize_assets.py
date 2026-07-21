#!/usr/bin/env python3
"""Pixel-exact release asset optimization.

Card images keep their existing ``.png.bin`` runtime paths, but PNG payloads may
be replaced by lossless WebP payloads when smaller. Regular PNG assets remain
PNG. Every candidate is decoded and compared as RGBA pixels before replacement.

The script never rewrites already-lossy WebP card images. Originals that are
actually replaced are copied to a backup directory outside the repository.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import os
import shutil
import struct
import sys
import tempfile
import time
import zlib
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

from PIL import Image

try:
    import zopfli.zlib as zopfli_zlib
except ImportError:  # pragma: no cover - operational dependency fallback
    zopfli_zlib = None


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
WEBP_EFFORT = 100
ZOPFLI_ITERATIONS = 15


@dataclass
class Result:
    group: str
    path: str
    before: int
    after: int
    status: str
    encoding: str
    pixel_sha256: str = ""
    note: str = ""
    candidate_path: str = ""

    @property
    def saved(self) -> int:
        return max(0, self.before - self.after)


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def relative(path: Path, root: Path) -> str:
    return path.resolve().relative_to(root.resolve()).as_posix()


def is_png(path: Path) -> bool:
    with path.open("rb") as handle:
        return handle.read(8) == PNG_SIGNATURE


def is_webp(path: Path) -> bool:
    with path.open("rb") as handle:
        header = handle.read(12)
    return len(header) == 12 and header[:4] == b"RIFF" and header[8:] == b"WEBP"


def decoded_signature(path: Path) -> tuple[tuple[int, int], str]:
    with Image.open(path) as image:
        image.load()
        rgba = image.convert("RGBA")
        digest = hashlib.sha256()
        digest.update(struct.pack(">II", *rgba.size))
        digest.update(rgba.tobytes())
        return rgba.size, digest.hexdigest()


def assert_pixel_exact(source: Path, candidate: Path) -> str:
    source_size, source_hash = decoded_signature(source)
    candidate_size, candidate_hash = decoded_signature(candidate)
    if source_size != candidate_size or source_hash != candidate_hash:
        raise ValueError(
            f"decoded pixels differ: source={source_size}/{source_hash} "
            f"candidate={candidate_size}/{candidate_hash}"
        )
    return source_hash


def unique_candidate_path(source: Path, root: Path, scratch: Path, suffix: str) -> Path:
    key = hashlib.sha1(relative(source, root).encode("utf-8")).hexdigest()
    return scratch / f"{key}{suffix}"


def save_lossless_webp(source: Path, destination: Path) -> None:
    with Image.open(source) as image:
        image.load()
        has_alpha = image.mode in ("RGBA", "LA") or "transparency" in image.info
        converted = image.convert("RGBA" if has_alpha else "RGB")
        kwargs: dict[str, Any] = {
            "format": "WEBP",
            "lossless": True,
            "quality": WEBP_EFFORT,
            "method": 6,
            "exact": has_alpha,
        }
        for metadata_key in ("icc_profile", "exif", "xmp"):
            metadata_value = image.info.get(metadata_key)
            if metadata_value:
                kwargs[metadata_key] = metadata_value
        converted.save(destination, **kwargs)


def parse_png_chunks(data: bytes) -> list[tuple[bytes, bytes]]:
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError("not a PNG payload")
    chunks: list[tuple[bytes, bytes]] = []
    offset = len(PNG_SIGNATURE)
    while offset + 12 <= len(data):
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        kind = data[offset + 4 : offset + 8]
        payload_start = offset + 8
        payload_end = payload_start + length
        crc_end = payload_end + 4
        if crc_end > len(data):
            raise ValueError("truncated PNG chunk")
        chunks.append((kind, data[payload_start:payload_end]))
        offset = crc_end
        if kind == b"IEND":
            break
    if not chunks or chunks[-1][0] != b"IEND":
        raise ValueError("PNG has no IEND chunk")
    return chunks


def encode_png_chunks(chunks: list[tuple[bytes, bytes]]) -> bytes:
    output = bytearray(PNG_SIGNATURE)
    for kind, payload in chunks:
        output.extend(struct.pack(">I", len(payload)))
        output.extend(kind)
        output.extend(payload)
        output.extend(struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF))
    return bytes(output)


def zopfli_recompress_png(path: Path, iterations: int) -> None:
    if zopfli_zlib is None:
        return
    chunks = parse_png_chunks(path.read_bytes())
    compressed = b"".join(payload for kind, payload in chunks if kind == b"IDAT")
    if not compressed:
        return
    filtered_scanlines = zlib.decompress(compressed)
    recompressed = zopfli_zlib.compress(filtered_scanlines, numiterations=iterations)
    rebuilt: list[tuple[bytes, bytes]] = []
    emitted_idat = False
    for kind, payload in chunks:
        if kind == b"IDAT":
            if not emitted_idat:
                rebuilt.append((b"IDAT", recompressed))
                emitted_idat = True
            continue
        rebuilt.append((kind, payload))
    path.write_bytes(encode_png_chunks(rebuilt))


def save_optimized_png(source: Path, destination: Path, iterations: int) -> None:
    with Image.open(source) as image:
        image.load()
        kwargs: dict[str, Any] = {
            "format": "PNG",
            "optimize": True,
            "compress_level": 9,
        }
        for metadata_key in ("icc_profile", "exif", "dpi"):
            metadata_value = image.info.get(metadata_key)
            if metadata_value:
                kwargs[metadata_key] = metadata_value
        image.save(destination, **kwargs)
    zopfli_recompress_png(destination, iterations)


def optimize_card_worker(arguments: tuple[str, str, str]) -> Result:
    source = Path(arguments[0])
    root = Path(arguments[1])
    scratch = Path(arguments[2])
    rel = relative(source, root)
    before = source.stat().st_size
    group = "csv10c_cards" if "/CSV10C/" in f"/{rel}" else "other_bundle_cards"
    if is_webp(source):
        return Result(group, rel, before, before, "kept", "existing_webp", note="already WebP")
    if not is_png(source):
        return Result(group, rel, before, before, "kept", "unknown", note="unsupported payload")
    candidate = unique_candidate_path(source, root, scratch, ".lossless.webp")
    try:
        save_lossless_webp(source, candidate)
        pixel_hash = assert_pixel_exact(source, candidate)
        candidate_size = candidate.stat().st_size
        if candidate_size >= before:
            candidate.unlink(missing_ok=True)
            return Result(group, rel, before, before, "kept", "png", pixel_hash, "WebP not smaller")
        return Result(
            group,
            rel,
            before,
            candidate_size,
            "optimized",
            "lossless_webp",
            pixel_hash,
            candidate_path=str(candidate),
        )
    except Exception as exc:  # pragma: no cover - operational path
        candidate.unlink(missing_ok=True)
        return Result(group, rel, before, before, "error", "png", note=str(exc))


def optimize_png_worker(arguments: tuple[str, str, str, int]) -> Result:
    source = Path(arguments[0])
    root = Path(arguments[1])
    scratch = Path(arguments[2])
    iterations = arguments[3]
    rel = relative(source, root)
    before = source.stat().st_size
    if not is_png(source):
        return Result("asset_pngs", rel, before, before, "kept", "unknown", note="not PNG")
    candidate = unique_candidate_path(source, root, scratch, ".optimized.png")
    try:
        save_optimized_png(source, candidate, iterations)
        pixel_hash = assert_pixel_exact(source, candidate)
        candidate_size = candidate.stat().st_size
        if candidate_size >= before:
            candidate.unlink(missing_ok=True)
            return Result("asset_pngs", rel, before, before, "kept", "png", pixel_hash, "candidate not smaller")
        return Result(
            "asset_pngs",
            rel,
            before,
            candidate_size,
            "optimized",
            "zopfli_png" if zopfli_zlib is not None else "optimized_png",
            pixel_hash,
            candidate_path=str(candidate),
        )
    except Exception as exc:  # pragma: no cover - operational path
        candidate.unlink(missing_ok=True)
        return Result("asset_pngs", rel, before, before, "error", "png", note=str(exc))


def collect_tasks(root: Path, groups: list[str], card_set: str) -> list[tuple[str, tuple[Any, ...]]]:
    tasks: list[tuple[str, tuple[Any, ...]]] = []
    scratch_placeholder = ""
    if "card_images" in groups:
        card_root = root / "data/bundled_user/cards/images"
        card_paths = sorted(card_root.rglob("*.png.bin"))
        if card_set:
            card_paths = [path for path in card_paths if path.parent.name == card_set]
        tasks.extend(("card", (str(path), str(root), scratch_placeholder)) for path in card_paths)
    if "pngs" in groups:
        png_paths = sorted((root / "assets").rglob("*.png"))
        tasks.extend(("png", (str(path), str(root), scratch_placeholder, ZOPFLI_ITERATIONS)) for path in png_paths)
    return tasks


def install_candidate(result: Result, root: Path, backup_root: Path) -> None:
    source = root / result.path
    candidate = Path(result.candidate_path)
    backup = backup_root / result.path
    backup.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, backup)
    staged = source.with_name(source.name + ".lossless.tmp")
    shutil.copy2(candidate, staged)
    os.replace(staged, source)
    candidate.unlink(missing_ok=True)
    result.candidate_path = ""


def summarize(results: list[Result]) -> dict[str, dict[str, int]]:
    summary: dict[str, dict[str, int]] = {}
    for result in results:
        bucket = summary.setdefault(
            result.group,
            {"files": 0, "optimized": 0, "errors": 0, "before": 0, "after": 0, "saved": 0},
        )
        bucket["files"] += 1
        bucket["before"] += result.before
        bucket["after"] += result.after
        bucket["saved"] += result.saved
        bucket["optimized"] += int(result.status == "optimized")
        bucket["errors"] += int(result.status == "error")
    return summary


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--groups", nargs="+", choices=["card_images", "pngs"], default=["card_images", "pngs"])
    parser.add_argument("--card-set", default="", help="Optional card set directory, for example CSV10C")
    parser.add_argument("--workers", type=int, default=max(1, min(8, os.cpu_count() or 1)))
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--backup-dir", default="")
    parser.add_argument("--report", default="")
    args = parser.parse_args()

    root = repo_root()
    stamp = time.strftime("%Y%m%d_%H%M%S")
    scratch = Path(tempfile.mkdtemp(prefix="ptcg_lossless_scratch_"))
    backup_root = Path(args.backup_dir).resolve() if args.backup_dir else Path(tempfile.gettempdir()) / f"ptcg_lossless_backup_{stamp}"
    report_path = Path(args.report).resolve() if args.report else root / ".tmp" / f"lossless_asset_optimization_{stamp}.json"
    backup_root.mkdir(parents=True, exist_ok=False)
    report_path.parent.mkdir(parents=True, exist_ok=True)

    raw_tasks = collect_tasks(root, args.groups, args.card_set)
    tasks: list[tuple[str, tuple[Any, ...]]] = []
    for kind, values in raw_tasks:
        mutable = list(values)
        mutable[2] = str(scratch)
        tasks.append((kind, tuple(mutable)))

    results: list[Result] = []
    started = time.monotonic()
    print(f"tasks={len(tasks)} workers={args.workers} backup={backup_root}", flush=True)
    with concurrent.futures.ProcessPoolExecutor(max_workers=max(1, args.workers)) as executor:
        future_map = {}
        for kind, values in tasks:
            future = executor.submit(optimize_card_worker if kind == "card" else optimize_png_worker, values)
            future_map[future] = kind
        for completed, future in enumerate(concurrent.futures.as_completed(future_map), start=1):
            result = future.result()
            if result.status == "optimized" and not args.dry_run:
                install_candidate(result, root, backup_root)
            else:
                Path(result.candidate_path).unlink(missing_ok=True) if result.candidate_path else None
                result.candidate_path = ""
            results.append(result)
            if completed % 10 == 0 or completed == len(tasks):
                saved = sum(entry.saved for entry in results)
                print(
                    f"progress={completed}/{len(tasks)} saved_MiB={saved / 1024 / 1024:.2f} "
                    f"elapsed_s={time.monotonic() - started:.1f}",
                    flush=True,
                )

    shutil.rmtree(scratch, ignore_errors=True)
    summary = summarize(results)
    report = {
        "timestamp": stamp,
        "pixel_exact": True,
        "dry_run": args.dry_run,
        "backup_dir": str(backup_root),
        "summary": summary,
        "results": [asdict(result) | {"saved": result.saved} for result in sorted(results, key=lambda item: item.path)],
    }
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"report={report_path}", flush=True)
    for group, values in summary.items():
        print(
            f"{group}: files={values['files']} optimized={values['optimized']} errors={values['errors']} "
            f"before_MiB={values['before'] / 1024 / 1024:.2f} "
            f"after_MiB={values['after'] / 1024 / 1024:.2f} saved_MiB={values['saved'] / 1024 / 1024:.2f}",
            flush=True,
        )
    return 2 if any(result.status == "error" for result in results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
