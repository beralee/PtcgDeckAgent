"""Reclaim proven duplicate files from old, explicitly scoped test artifacts.

Dry-run by default. Original assets, custom user files, reports, frozen source,
unique exports and rollback packages are never selected. No recursive deletion.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import math
import os
from pathlib import Path
import re
import stat
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
TEST_ROOTS = (".tmp", ".godot_test_user", "tmp")


def is_link(path: Path) -> bool:
    try:
        return path.is_symlink() or bool(getattr(path.lstat(), "st_file_attributes", 0)
                                         & stat.FILE_ATTRIBUTE_REPARSE_POINT)
    except FileNotFoundError:
        return False


def checked_path(path: Path, boundary: Path) -> Path:
    """Reject both lexical escapes and links anywhere between file and root."""
    path, boundary = Path(os.path.abspath(path)), Path(os.path.abspath(boundary))
    if path == boundary or not path.is_relative_to(boundary):
        raise ValueError(f"Target must be below the allowed root: {path}")
    for parent in (path, *path.parents):
        if is_link(parent):
            raise ValueError(f"Refusing reparse point: {parent}")
    resolved = path.resolve()
    if not resolved.is_relative_to(boundary.resolve()):
        raise ValueError(f"Target escaped its allowed root: {path}")
    return resolved


def validate_roots(project: Path, roots: list[Path]) -> list[Path]:
    project = project.resolve()
    result = []
    for value in roots:
        root = Path(os.path.abspath(value))
        checked_path(root, root.parent)
        if project == root or project.is_relative_to(root):
            raise ValueError("A source project or its ancestor is not a test artifact root")
        if root.is_relative_to(project) and root.relative_to(project).parts[0] not in TEST_ROOTS:
            raise ValueError("Only .tmp, .godot_test_user and tmp are disposable project roots")
        for name in ("APPDATA", "LOCALAPPDATA", "USERPROFILE", "HOME"):
            player = os.environ.get(name)
            if player:
                player_root = Path(player).resolve()
                userdata = player_root / "Godot/app_userdata"
                if player_root.is_relative_to(root) or root.is_relative_to(userdata) or userdata.is_relative_to(root):
                    raise ValueError("Real player user data or its ancestor is not a test artifact root")
        if root == Path(root.anchor) or root == Path.home():
            raise ValueError("A drive or home directory is not a test artifact root")
        if root not in result:
            result.append(root)
    if any(a != b and a.is_relative_to(b) for a in result for b in result):
        raise ValueError("Test roots must not overlap")
    return result


def active_commands() -> list[str]:
    if os.name != "nt":
        raise RuntimeError("Pass an explicit process inventory on non-Windows hosts")
    query = "Get-CimInstance Win32_Process | Select-Object ProcessId,CommandLine | ConvertTo-Json -Compress"
    raw = subprocess.check_output(["powershell", "-NoProfile", "-Command", query], text=True, encoding="utf-8", errors="replace")
    rows = json.loads(raw)
    return [row["CommandLine"] for row in rows if row.get("CommandLine")
            and row["ProcessId"] != os.getpid()
            and "cleanup_test_artifacts" not in row["CommandLine"]
            and "Get-CimInstance Win32_Process" not in row["CommandLine"]]


def in_use(run: Path, commands: list[str]) -> bool:
    token = str(run).replace("\\", "/").lower()
    return any(token in command.replace("\\", "/").lower() for command in commands)


def root_in_use(root: Path, commands: list[str]) -> bool:
    # A server in one run protects that run, not every sibling in .tmp.
    token = re.escape(str(root).replace("\\", "/").lower())
    return any(re.search(token + r'''/?(?:[\s"']|$)''', command.replace("\\", "/").lower())
               for command in commands)


def assert_identifiable_tests(project: Path, commands: list[str]) -> None:
    for command in commands:
        value = command.replace("\\", "/").lower()
        if ("godot" in value and "--headless" in value and str(project).replace("\\", "/").lower() in value
                and "--log-file" not in value and "--report=" not in value):
            raise RuntimeError("A headless project process has no identifiable artifact path; retry after it exits")


def userdata_may_be_active(project: Path, commands: list[str]) -> bool:
    # A headless test's APPDATA can differ from its --log-file directory. Do
    # not infer the user-data location from logging when a test is still alive.
    return any("godot" in command.lower() and "--headless" in command.lower()
               and str(project).replace("\\", "/").lower() in command.replace("\\", "/").lower()
               for command in commands)


def latest_activity(run: Path) -> float:
    latest = 0.0
    for folder, dirs, names in os.walk(run, followlinks=False):
        dirs[:] = [name for name in dirs if not is_link(Path(folder) / name)]
        for name in names:
            path = Path(folder) / name
            if not is_link(path):
                value = path.stat()
                latest = max(latest, value.st_mtime, value.st_ctime)
    return latest


def fingerprint(path: Path) -> tuple[int, int, int]:
    stat = path.stat()
    return stat.st_size, stat.st_mtime_ns, stat.st_ctime_ns


def digest(path: Path, cache: dict | None = None) -> str:
    key = (str(path), fingerprint(path))
    if cache is not None and key in cache:
        return cache[key]
    with path.open("rb") as stream:
        result = hashlib.file_digest(stream, "sha256").hexdigest()
    if cache is not None:
        cache[key] = result
    return result


def unlink_independent_copy(path: Path) -> bool:
    """Shared hard links already save space; never alter their shared flags."""
    info = path.stat()
    if info.st_nlink > 1:
        return False
    readonly = bool(getattr(info, "st_file_attributes", 0) & stat.FILE_ATTRIBUTE_READONLY)
    if readonly:
        path.chmod(info.st_mode | stat.S_IWRITE)
    try:
        path.unlink()
    except OSError:
        if readonly and path.exists():
            path.chmod(info.st_mode)
        raise
    return True


def duplicate_source(project: Path, path: Path, scan_root: Path) -> tuple[Path, str, Path | None] | None:
    relative = path.relative_to(scan_root).as_posix()
    seeded = re.search(r"(?:^|/)[Gg]odot/app_userdata/([^/]+)/(cards/images/.+|music/battle_bgm/[^/]+)$", relative)
    if seeded:
        suffix = seeded.group(2)
        user_root = path.parents[len(Path(suffix).parts) - 1]
        if suffix.startswith("cards/images/"):
            if path.suffix.lower() == ".import":
                return None
            source = project / "data/bundled_user" / suffix
            # CardDatabase strips the export-safe .bin wrapper when seeding.
            if not source.is_file():
                source = source.with_name(source.name + ".bin")
            return source, "seed_image", user_root
        return project / "assets/audio/bgm" / path.name, "builtin_music", None
    # Only a project snapshot's nested output tree, never the retained exports
    # beside that snapshot. A name such as output alone is not proof of origin.
    for parent in path.parents:
        if parent == scan_root:
            break
        if parent.name == "output" and (parent.parent / "project.godot").is_file():
            return project / "output" / path.relative_to(parent), "copied_output", None
    return None


def plan_duplicates(project: Path, roots: list[Path], min_age_hours: float = 24,
                    commands=None, now: float | None = None) -> dict:
    if not math.isfinite(min_age_hours) or min_age_hours < 0:
        raise ValueError("Minimum age must be finite and nonnegative")
    project = project.resolve()
    roots = validate_roots(project, roots)
    commands = active_commands() if commands is None else list(commands)
    assert_identifiable_tests(project, commands)
    cutoff = (time.time() if now is None else now) - min_age_hours * 3600
    candidates, latest, cache, errors = [], {}, {}, []
    shared_links = 0
    for root in roots:
        if not root.is_dir():
            continue
        for folder, dirs, names in os.walk(root, followlinks=False):
            dirs[:] = [name for name in dirs if not is_link(Path(folder) / name)]
            for name in names:
                path = Path(folder) / name
                try:
                    if is_link(path):
                        continue
                    relative = path.relative_to(root)
                    run = root / relative.parts[0] if len(relative.parts) > 1 else root
                    stat = path.stat()
                    latest[run] = max(latest.get(run, 0), stat.st_mtime, stat.st_ctime)
                    match = duplicate_source(project, path, root)
                    if match:
                        if stat.st_nlink > 1:
                            shared_links += 1
                            continue
                        candidates.append((path, root, run, match))
                except OSError as exc:
                    errors.append(str(exc))
    files = []
    for path, root, run, (source, kind, user_root) in candidates:
        if latest[run] > cutoff or in_use(run, commands) or root_in_use(root, commands):
            continue
        if kind != "copied_output" and userdata_may_be_active(project, commands):
            continue
        try:
            checked_path(path, root)
            checked_path(source, project)
            if not source.is_file() or path.stat().st_size != source.stat().st_size:
                continue
            identity = digest(source, cache)
            if digest(path) != identity:
                continue
            files.append(dict(path=str(path), source=str(source), root=str(root), run=str(run),
                              kind=kind, bytes=path.stat().st_size, sha256=identity,
                              run_latest=latest[run],
                              user_root=str(user_root) if user_root else ""))
        except (OSError, ValueError) as exc:
            errors.append(str(exc))
    return dict(schema_version=1, mode="dry_run", project=str(project),
                roots=[str(root) for root in roots], min_age_hours=min_age_hours,
                cutoff=cutoff,
                shared_links_retained=shared_links,
                files=files, reclaimable_bytes=sum(row["bytes"] for row in files), errors=errors)


def execute_plan(plan: dict, commands=None) -> dict:
    project = Path(plan["project"]).resolve()
    roots = validate_roots(project, [Path(root) for root in plan["roots"]])
    commands = active_commands() if commands is None else list(commands)
    assert_identifiable_tests(project, commands)
    deleted_bytes, deleted_files, skipped = 0, 0, []
    # Cache only retained source hashes; targets are always opened again.
    cache, checked_runs, invalidated_users = {}, {}, set()
    for row in plan["files"]:
        path, root, run = (Path(row[name]) for name in ("path", "root", "run"))
        try:
            if root not in roots or in_use(run, commands) or root_in_use(root, commands):
                skipped.append(str(path))
                continue
            if row["kind"] != "copied_output" and userdata_may_be_active(project, commands):
                skipped.append(str(path))
                continue
            if run not in checked_runs:
                checked_runs[run] = latest_activity(run)
            if checked_runs[run] > min(plan["cutoff"], row["run_latest"]):
                skipped.append(str(path))
                continue
            checked_path(path, root)
            if path.stat().st_nlink > 1:
                skipped.append(str(path))
                continue
            match = duplicate_source(project, path, root)
            if match is None or str(match[0]) != row["source"]:
                raise ValueError("File no longer matches the duplicate policy")
            source, _, user_root = match
            checked_path(source, project)
            if digest(source, cache) != row["sha256"] or digest(path) != row["sha256"]:
                skipped.append(str(path))
                continue
            if user_root and user_root not in invalidated_users:
                marker = checked_path(user_root / ".bundled_seed_completion_v1.json", root)
                # Invalidate before removal: even an interrupted cleanup is
                # repaired by the next normal seed operation.
                marker.unlink(missing_ok=True)
                invalidated_users.add(user_root)
            if not unlink_independent_copy(path):
                skipped.append(str(path))
                continue
            deleted_files += 1
            deleted_bytes += row["bytes"]
        except (OSError, ValueError) as exc:
            skipped.append(f"{path}: {exc}")
    return {**plan, "mode": "execute", "deleted_bytes": deleted_bytes,
            "deleted_files": deleted_files, "skipped": skipped}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--test-root", type=Path, action="append", help="Explicit test artifact root; repeat for scratch runs")
    parser.add_argument("--min-age-hours", type=float, default=24)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--report", type=Path, required=True, help="Local JSON audit receipt, retained after cleanup")
    args = parser.parse_args()
    roots = args.test_root or [ROOT / name for name in TEST_ROOTS[:2]]
    result = plan_duplicates(ROOT, roots, args.min_age_hours)
    # Persist the reviewable file/source/hash proof before any deletion.
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    if args.execute:
        result = execute_plan(result)
        args.report.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    kinds = Counter()
    for row in result["files"]:
        kinds[row["kind"]] += row["bytes"]
    print(json.dumps({key: value for key, value in result.items() if key not in ("files", "errors", "skipped")}
                     | {"categories_bytes": dict(kinds), "candidate_files": len(result["files"]),
                        "skipped_count": len(result.get("skipped", [])), "error_count": len(result["errors"]),
                        "report": str(args.report.resolve())}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
