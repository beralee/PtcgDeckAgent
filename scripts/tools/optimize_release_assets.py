#!/usr/bin/env python3
"""Optimize release assets without changing runtime resource paths.

The script creates a full backup under .tmp before replacing any asset.
It only replaces a generated asset when the result can be decoded and is
smaller than the original.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass, asdict
from pathlib import Path

from PIL import Image


CARD_WEBP_QUALITY = 94
BGM_BITRATE = "192k"

EXCLUDED_DIR_NAMES = {
    ".git",
    ".godot",
    ".tmp",
    "tmp",
    "tmp_benchmark_logs",
    "tools",
    "android",
}


@dataclass
class AssetResult:
    group: str
    path: str
    before: int
    after: int
    status: str
    note: str = ""

    @property
    def saved(self) -> int:
        return max(0, self.before - self.after)


def repo_root_from_script() -> Path:
    return Path(__file__).resolve().parents[2]


def rel(path: Path, root: Path) -> str:
    return path.resolve().relative_to(root.resolve()).as_posix()


def ensure_inside_repo(path: Path, root: Path) -> None:
    path.resolve().relative_to(root.resolve())


def collect_targets(root: Path) -> dict[str, list[Path]]:
    card_images = sorted((root / "data/bundled_user/cards/images").rglob("*.png.bin"))
    bgm = sorted((root / "assets/audio/bgm").glob("*.mp3"))
    fonts = [root / "assets/fonts/NotoSansSC-VF.ttf"]
    fonts = [p for p in fonts if p.exists()]
    pngs = sorted((root / "assets").rglob("*.png"))
    return {
        "card_images": card_images,
        "bgm": bgm,
        "fonts": fonts,
        "pngs": pngs,
    }


def backup_targets(root: Path, targets: dict[str, list[Path]], backup_dir: Path) -> None:
    backup_dir.mkdir(parents=True, exist_ok=False)
    manifest: list[dict[str, object]] = []
    seen: set[Path] = set()
    for group, files in targets.items():
        for source in files:
            source = source.resolve()
            if source in seen:
                continue
            seen.add(source)
            ensure_inside_repo(source, root)
            destination = backup_dir / rel(source, root)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
            manifest.append({
                "group": group,
                "path": rel(source, root),
                "bytes": source.stat().st_size,
            })
    (backup_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def verify_image(path: Path) -> None:
    with Image.open(path) as image:
        image.verify()


def is_webp_file(path: Path) -> bool:
    with path.open("rb") as file:
        header = file.read(12)
    return len(header) >= 12 and header[0:4] == b"RIFF" and header[8:12] == b"WEBP"


def optimize_card_image(path: Path, root: Path, tmp_dir: Path) -> AssetResult:
    before = path.stat().st_size
    tmp = tmp_dir / (path.name + ".webp.tmp")
    try:
        if is_webp_file(path):
            return AssetResult("card_images", rel(path, root), before, before, "kept", "already_webp")
        with Image.open(path) as image:
            image.load()
            has_alpha = image.mode in ("RGBA", "LA") or "transparency" in image.info
            converted = image.convert("RGBA" if has_alpha else "RGB")
            converted.save(
                tmp,
                format="WEBP",
                quality=CARD_WEBP_QUALITY,
                method=6,
                exact=has_alpha,
            )
        verify_image(tmp)
        after = tmp.stat().st_size
        if after < before:
            shutil.move(str(tmp), str(path))
            return AssetResult("card_images", rel(path, root), before, after, "optimized", "webp")
        tmp.unlink(missing_ok=True)
        return AssetResult("card_images", rel(path, root), before, before, "kept", "webp_not_smaller")
    except Exception as exc:  # pragma: no cover - operational script
        tmp.unlink(missing_ok=True)
        return AssetResult("card_images", rel(path, root), before, before, "error", str(exc))


def optimize_png(path: Path, root: Path, tmp_dir: Path) -> AssetResult:
    before = path.stat().st_size
    tmp = tmp_dir / (path.name + ".png.tmp")
    try:
        with Image.open(path) as image:
            image.load()
            save_kwargs: dict[str, object] = {"format": "PNG", "optimize": True, "compress_level": 9}
            if "icc_profile" in image.info:
                save_kwargs["icc_profile"] = image.info["icc_profile"]
            image.save(tmp, **save_kwargs)
        verify_image(tmp)
        after = tmp.stat().st_size
        if after < before:
            shutil.move(str(tmp), str(path))
            return AssetResult("pngs", rel(path, root), before, after, "optimized", "png_lossless")
        tmp.unlink(missing_ok=True)
        return AssetResult("pngs", rel(path, root), before, before, "kept", "png_not_smaller")
    except Exception as exc:  # pragma: no cover - operational script
        tmp.unlink(missing_ok=True)
        return AssetResult("pngs", rel(path, root), before, before, "error", str(exc))


def run_checked(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, text=True, capture_output=True, check=True)


def optimize_bgm(path: Path, root: Path, tmp_dir: Path) -> AssetResult:
    before = path.stat().st_size
    tmp = tmp_dir / (path.stem + ".optimized.mp3")
    command = [
        "ffmpeg",
        "-y",
        "-hide_banner",
        "-loglevel",
        "error",
        "-i",
        str(path),
        "-map_metadata",
        "0",
        "-vn",
        "-codec:a",
        "libmp3lame",
        "-b:a",
        BGM_BITRATE,
        "-ar",
        "44100",
        "-ac",
        "2",
        str(tmp),
    ]
    try:
        run_checked(command)
        run_checked([
            "ffprobe",
            "-v",
            "error",
            "-select_streams",
            "a:0",
            "-show_entries",
            "stream=codec_name,duration,bit_rate",
            "-of",
            "default=noprint_wrappers=1",
            str(tmp),
        ])
        after = tmp.stat().st_size
        if after < before:
            shutil.move(str(tmp), str(path))
            return AssetResult("bgm", rel(path, root), before, after, "optimized", f"mp3_{BGM_BITRATE}")
        tmp.unlink(missing_ok=True)
        return AssetResult("bgm", rel(path, root), before, before, "kept", "mp3_not_smaller")
    except Exception as exc:  # pragma: no cover - operational script
        tmp.unlink(missing_ok=True)
        return AssetResult("bgm", rel(path, root), before, before, "error", str(exc))


def iter_text_files(root: Path) -> list[Path]:
    scan_roots = [
        root / "scenes",
        root / "scripts",
        root / "data",
        root / "community",
        root / "assets",
    ]
    extensions = {".gd", ".tscn", ".tres", ".json", ".cfg", ".godot", ".txt", ".md"}
    files: list[Path] = []
    for scan_root in scan_roots:
        if not scan_root.exists():
            continue
        for path in scan_root.rglob("*"):
            if not path.is_file() or path.suffix.lower() not in extensions:
                continue
            if any(part in EXCLUDED_DIR_NAMES for part in path.parts):
                continue
            files.append(path)
    for path in [root / "project.godot", root / "export_presets.cfg", root / "README.md", root / "README_EN.md"]:
        if path.exists():
            files.append(path)
    return sorted(set(files))


def gb2312_chars() -> set[str]:
    chars: set[str] = set()
    for high in range(0xB0, 0xF8):
        for low in range(0xA1, 0xFF):
            try:
                chars.add(bytes([high, low]).decode("gb2312"))
            except UnicodeDecodeError:
                continue
    return chars


def build_font_text(root: Path, tmp_dir: Path) -> Path:
    chars: set[str] = set()
    chars.update(chr(code) for code in range(0x20, 0x7F))
    chars.update(chr(code) for code in range(0xA0, 0x100))
    chars.update(chr(code) for code in range(0x2000, 0x2070))
    chars.update(chr(code) for code in range(0x3000, 0x3040))
    chars.update(chr(code) for code in range(0xFF00, 0xFFF0))
    chars.update(gb2312_chars())
    chars.update("宝可梦卡牌智能练牌器训练器卡组中心对战设置大模型规则模型先攻后攻胜利失败冠军")
    chars.update("：；，。！？（）《》【】、·…-—+×/abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

    for path in iter_text_files(root):
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        chars.update(ch for ch in text if not ch.isspace() or ch in "\n\t ")

    text_path = tmp_dir / "font_subset_chars.txt"
    text_path.write_text("".join(sorted(chars)), encoding="utf-8")
    return text_path


def optimize_font(path: Path, root: Path, tmp_dir: Path) -> AssetResult:
    before = path.stat().st_size
    tmp = tmp_dir / (path.name + ".subset.tmp")
    text_file = build_font_text(root, tmp_dir)
    command = [
        "pyftsubset",
        str(path),
        f"--output-file={tmp}",
        f"--text-file={text_file}",
        "--layout-features=*",
        "--recommended-glyphs",
        "--ignore-missing-glyphs",
        "--no-hinting",
    ]
    try:
        run_checked(command)
        after = tmp.stat().st_size
        if after < before:
            shutil.move(str(tmp), str(path))
            return AssetResult("fonts", rel(path, root), before, after, "optimized", "subset_gb2312_repo_chars")
        tmp.unlink(missing_ok=True)
        return AssetResult("fonts", rel(path, root), before, before, "kept", "subset_not_smaller")
    except Exception as exc:  # pragma: no cover - operational script
        tmp.unlink(missing_ok=True)
        return AssetResult("fonts", rel(path, root), before, before, "error", str(exc))


def summarize(results: list[AssetResult]) -> dict[str, dict[str, int]]:
    summary: dict[str, dict[str, int]] = {}
    for result in results:
        bucket = summary.setdefault(result.group, {"count": 0, "optimized": 0, "before": 0, "after": 0, "saved": 0, "errors": 0})
        bucket["count"] += 1
        bucket["before"] += result.before
        bucket["after"] += result.after
        bucket["saved"] += result.saved
        if result.status == "optimized":
            bucket["optimized"] += 1
        if result.status == "error":
            bucket["errors"] += 1
    return summary


def print_summary(summary: dict[str, dict[str, int]], backup_dir: Path, report_path: Path) -> None:
    print(f"backup_dir={backup_dir}")
    print(f"report={report_path}")
    for group, data in summary.items():
        before_mb = data["before"] / 1024 / 1024
        after_mb = data["after"] / 1024 / 1024
        saved_mb = data["saved"] / 1024 / 1024
        print(
            f"{group}: files={data['count']} optimized={data['optimized']} "
            f"errors={data['errors']} before={before_mb:.2f}MB after={after_mb:.2f}MB saved={saved_mb:.2f}MB"
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--backup-only", action="store_true")
    parser.add_argument(
        "--groups",
        nargs="+",
        choices=["card_images", "bgm", "fonts", "pngs"],
        default=["card_images", "bgm", "fonts", "pngs"],
    )
    args = parser.parse_args()

    root = repo_root_from_script()
    stamp = time.strftime("%Y%m%d_%H%M%S")
    work_root = root / ".tmp" / f"release_asset_optimization_{stamp}"
    backup_dir = work_root / "backup"
    scratch_dir = work_root / "scratch"
    scratch_dir.mkdir(parents=True, exist_ok=True)

    all_targets = collect_targets(root)
    targets = {group: files for group, files in all_targets.items() if group in args.groups}
    backup_targets(root, targets, backup_dir)

    results: list[AssetResult] = []
    if not args.backup_only:
        for path in targets.get("card_images", []):
            results.append(optimize_card_image(path, root, scratch_dir))
        for path in targets.get("bgm", []):
            results.append(optimize_bgm(path, root, scratch_dir))
        for path in targets.get("fonts", []):
            results.append(optimize_font(path, root, scratch_dir))
        for path in targets.get("pngs", []):
            results.append(optimize_png(path, root, scratch_dir))
    else:
        for group, files in targets.items():
            for path in files:
                size = path.stat().st_size
                results.append(AssetResult(group, rel(path, root), size, size, "backed_up"))

    summary = summarize(results)
    report = {
        "timestamp": stamp,
        "backup_dir": str(backup_dir),
        "summary": summary,
        "results": [asdict(result) | {"saved": result.saved} for result in results],
    }
    report_path = work_root / "report.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print_summary(summary, backup_dir, report_path)

    if any(result.status == "error" for result in results):
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
