#!/usr/bin/env python3
"""Compress one project image asset into a bounded-size WebP file.

This is intended for generated UI/background art where the source image can be
large, but the runtime asset must stay small enough for release packages.
"""

from __future__ import annotations

import argparse
import shutil
import time
from pathlib import Path

from PIL import Image


def repo_root_from_script() -> Path:
    return Path(__file__).resolve().parents[2]


def resolve_path(path_text: str, root: Path) -> Path:
    if path_text.startswith("res://"):
        return root / path_text.removeprefix("res://")
    return Path(path_text)


def ensure_inside_repo(path: Path, root: Path) -> None:
    path.resolve().relative_to(root.resolve())


def crop_cover(image: Image.Image, target_width: int, target_height: int) -> Image.Image:
    source_width, source_height = image.size
    target_ratio = target_width / target_height
    source_ratio = source_width / source_height
    if abs(source_ratio - target_ratio) < 0.001:
        return image

    if source_ratio > target_ratio:
        new_width = int(source_height * target_ratio)
        left = (source_width - new_width) // 2
        return image.crop((left, 0, left + new_width, source_height))

    new_height = int(source_width / target_ratio)
    top = (source_height - new_height) // 2
    return image.crop((0, top, source_width, top + new_height))


def backup_existing(output_path: Path, root: Path) -> None:
    if not output_path.exists():
        return
    ensure_inside_repo(output_path, root)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    backup_root = root / ".tmp" / "asset_compress_backups" / stamp
    relative = output_path.resolve().relative_to(root.resolve())
    backup_path = backup_root / relative
    backup_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(output_path, backup_path)


def save_candidate(image: Image.Image, output_path: Path, quality: int) -> int:
    temp_path = output_path.with_suffix(output_path.suffix + ".tmp")
    image.save(
        temp_path,
        format="WEBP",
        quality=quality,
        method=6,
    )
    with Image.open(temp_path) as verify_image:
        verify_image.verify()
    size = temp_path.stat().st_size
    shutil.move(str(temp_path), str(output_path))
    return size


def compress(source_path: Path, output_path: Path, max_bytes: int, width: int, height: int) -> tuple[int, int, int]:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(source_path) as source:
        source.load()
        image = crop_cover(source.convert("RGB"), width, height)
        if image.size != (width, height):
            image = image.resize((width, height), Image.Resampling.LANCZOS)

    last_size = 0
    last_quality = 0
    for quality in range(84, 48, -4):
        last_size = save_candidate(image, output_path, quality)
        last_quality = quality
        if last_size <= max_bytes:
            return width, height, last_quality

    last_width = width
    last_height = height
    for scale in (0.9, 0.8, 0.7):
        scaled_width = int(width * scale)
        scaled_height = int(height * scale)
        last_width = scaled_width
        last_height = scaled_height
        scaled = image.resize((scaled_width, scaled_height), Image.Resampling.LANCZOS)
        for quality in range(72, 48, -4):
            last_size = save_candidate(scaled, output_path, quality)
            last_quality = quality
            if last_size <= max_bytes:
                return scaled_width, scaled_height, last_quality

    return last_width, last_height, last_quality


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--max-bytes", type=int, default=450_000)
    parser.add_argument("--width", type=int, default=1920)
    parser.add_argument("--height", type=int, default=1080)
    args = parser.parse_args()

    root = repo_root_from_script()
    source_path = resolve_path(args.source, root)
    output_path = resolve_path(args.output, root)
    ensure_inside_repo(output_path, root)
    backup_existing(output_path, root)

    width, height, quality = compress(
        source_path,
        output_path,
        args.max_bytes,
        args.width,
        args.height,
    )
    size = output_path.stat().st_size
    print(f"output={output_path}")
    print(f"size={size}")
    print(f"dimensions={width}x{height}")
    print(f"quality={quality}")
    if size > args.max_bytes:
        print(f"warning=size_over_limit max={args.max_bytes}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
