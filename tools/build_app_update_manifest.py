"""Build the public v2 application feed from final, already signed packages.

Offline only: this tool neither publishes files nor changes production services.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import plistlib
import re
import stat
import zipfile
from pathlib import Path
from urllib.parse import urlsplit

ORIGIN = "https://ptcg.skillserver.cn/"
FORMATS = {"windows": "windows_zip", "android": "android_apk"}
ARCHES = {"windows": {"x86_64", "arm64", "x86"}, "macos": {"arm64", "x86_64", "universal"}, "android": {"arm64", "arm32", "x86_64", "x86", "universal"}}


def version(value: object) -> str:
    if not isinstance(value, str) or not re.fullmatch(r"[0-9]{1,8}\.[0-9]{1,8}\.[0-9]{1,8}(?:\.[0-9]{1,8})?", value):
        raise ValueError("Expected a numeric stable release version")
    return value


def safe_member(name: str) -> bool:
    if any(ord(c) < 32 or ord(c) == 127 for c in name) or any(c in name for c in '\\:*?"<>|%'):
        return False
    parts = name.rstrip("/").split("/")
    return bool(parts) and all(p not in ("", ".", "..") and not p.endswith((".", " ")) and not re.match(r"^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(?:\.|$)", p, re.I) for p in parts)


def inspect_package(path: Path, platform: str, entry: str, release_version: str) -> None:
    with zipfile.ZipFile(path) as archive:
        members = archive.infolist()
        seen: set[str] = set()
        expanded = 0
        if len(members) > 20_000:
            raise ValueError("Too many package entries")
        for item in members:
            name = item.filename.rstrip("/")
            if not safe_member(item.filename) or name.casefold() in seen:
                raise ValueError("Unsafe or duplicate package member")
            seen.add(name.casefold())
            mode = stat.S_IFMT(item.external_attr >> 16)
            if mode not in (0, stat.S_IFREG, stat.S_IFDIR):
                raise ValueError("Linked/special archive entries are unsupported")
            expanded += item.file_size
            if item.file_size > 2 * 1024**3 or expanded > 4 * 1024**3:
                raise ValueError("Package resource limit exceeded")
            if platform == "macos" and name != entry and not name.startswith(entry + "/"):
                raise ValueError("Mac update ZIP must contain exactly one app bundle")
        if platform == "windows" and entry not in archive.namelist():
            raise ValueError("Windows executable missing at ZIP root")
        if platform == "macos":
            metadata = plistlib.loads(archive.read(entry + "/Contents/Info.plist"))
            if metadata.get("CFBundleShortVersionString") != release_version:
                raise ValueError("Mac bundle version differs from feed")
            if metadata.get("CFBundleIdentifier") != "com.bera.ptcgdeckdojo":
                raise ValueError("Wrong Mac bundle identifier")
        if platform == "android" and "AndroidManifest.xml" not in archive.namelist():
            raise ValueError("Expected a full APK, not an app bundle or split archive")


def build(spec: dict, base: Path) -> dict:
    result = {
        "schema_version": 2, "channel": "stable", "latest_version": version(spec["latest_version"]),
        "release_date": str(spec.get("release_date", "")), "title": str(spec.get("title", "游戏更新")),
        "summary": spec.get("summary", []), "download_page_url": ORIGIN, "platforms": {},
    }
    if not isinstance(result["summary"], list) or any(not isinstance(s, str) for s in result["summary"]):
        raise ValueError("summary must be a list of strings")
    for platform, config in spec["platforms"].items():
        if platform in ("web", "macos"):
            if config.get("artifacts"):
                raise ValueError("Website-only platforms must not advertise native install packages")
            result["platforms"][platform] = {"version": version(config["version"])}
            continue
        if platform not in FORMATS:
            raise ValueError("Unsupported native update platform")
        release_version = version(config.get("version", result["latest_version"]))
        target = {"version": release_version, "artifacts": []}
        arches: set[str] = set()
        for source in config["artifacts"]:
            arch = source["arch"]
            if arch not in ARCHES[platform] or arch in arches or "universal" in arches or (arch == "universal" and arches):
                raise ValueError("Ambiguous or invalid architecture")
            arches.add(arch)
            path = base / source["file"]
            if path.is_symlink() or not path.is_file():
                raise ValueError("Expected a regular final package")
            size = path.stat().st_size
            if not 0 < size <= 2 * 1024**3:
                raise ValueError("Package size out of bounds")
            entry = source["entry"]
            suffix = {"windows": ".exe", "macos": ".app", "android": ".apk"}[platform]
            if not safe_member(entry) or "/" in entry or len(entry) > 120 or not entry.endswith(suffix):
                raise ValueError("Invalid package entry")
            url = source["url"]
            parsed = urlsplit(url)
            if not url.startswith(ORIGIN) or parsed.netloc != "ptcg.skillserver.cn" or any(ord(c) < 32 for c in url) or "\\" in url:
                raise ValueError("Update must use the fixed public HTTPS origin")
            inspect_package(path, platform, entry, release_version)
            with path.open("rb") as stream:
                digest = hashlib.file_digest(stream, "sha256").hexdigest()
            artifact = {"arch": arch, "format": FORMATS[platform], "entry": entry, "url": url, "size": size, "sha256": digest}
            if platform == "android":
                build_code = source.get("build")
                if type(build_code) is not int or not 0 < build_code <= 2_100_000_000:
                    raise ValueError("APK versionCode is required")
                artifact["build"] = build_code
            target["artifacts"].append(artifact)
        if not target["artifacts"] or len(target["artifacts"]) > 8:
            raise ValueError("Each platform needs 1..8 artifacts")
        result["platforms"][platform] = target
    if not any(platform in FORMATS for platform in result["platforms"]):
        raise ValueError("No update packages supplied")
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = build(json.loads(args.spec.read_text(encoding="utf-8")), args.spec.resolve().parent)
    encoded = (json.dumps(result, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    if len(encoded) > 256 * 1024:
        raise ValueError("Feed exceeds client limit")
    with args.output.open("xb") as output:
        output.write(encoded)
        output.flush()
        os.fsync(output.fileno())
    print(f"Created {args.output} ({len(result['platforms'])} platforms). Nothing was published.")


if __name__ == "__main__":
    main()
