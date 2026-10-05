"""Copy a frozen public working-tree snapshot without touching the live editor."""
import argparse
import filecmp
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess


# This is a build boundary, independent of Git ignore rules. Old ignored files
# can still be tracked, and an untracked export must never seed another export.
GENERATED_ROOTS = frozenset({
    ".git", ".import", ".export", ".worktrees", ".pytest_cache",
    "output", "tmp", "godot", "android", "logs", "node_modules",
    "playwright-report", "test-results", "tmp_benchmark_logs",
})
IMPORT_PATH = re.compile(r'res://(\.godot/imported/[^"\r\n]+)')


def included_source(name: str) -> bool:
    parts = Path(name).parts
    if not parts or Path(name).is_absolute() or ".." in parts:
        return False
    top = parts[0].lower()
    if top in GENERATED_ROOTS or top.startswith((".tmp", ".godot", ".codex")):
        return False
    if "__pycache__" in parts or "node_modules" in parts:
        return False
    if top == "native" and "build" in parts[1:]:
        return False
    return parts[:2] != ("artifacts", "deck_training")


def assert_plain_path(path: Path, root: Path) -> None:
    """Reject links/junctions at every component before reading or writing."""
    if '..' in path.parts:
        raise ValueError("Snapshot path contains a parent traversal")
    path.relative_to(root)
    for component in (path, *path.parents):
        if component.is_symlink() or (hasattr(component, "is_junction") and component.is_junction()):
            raise ValueError("Snapshot path contains a link or junction: " + str(component))
        if component == root:
            break


def copy_if_changed(source: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.is_file() and filecmp.cmp(source, target, shallow=False):
        return
    # Copies must remain independent: hard links would let an editor change a
    # supposedly frozen build while it is exporting.
    shutil.copy2(source, target)


def prepare_snapshot(root: Path, destination: Path, names: list[str], *, refresh: bool = False) -> dict[str, str]:
    # A previous refresh may have compared files whose timestamps were later
    # restored by another build tool; always compare this invocation's bytes.
    filecmp.clear_cache()
    root = root.resolve()
    destination = destination.absolute()
    assert_plain_path(destination, Path(destination.anchor))
    if destination == root or root.is_relative_to(destination):
        raise ValueError("Snapshot must not replace or contain its source project")
    if refresh:
        previous = destination.parent / 'source-manifest.json'
        if not (destination / 'project.godot').is_file() or not previous.is_file():
            raise ValueError('Refresh requires an existing recorded diagnostic snapshot')
        previous_names = json.loads(previous.read_text(encoding='utf-8'))
        stale = [name for name in previous_names if included_source(name) and not (root / name).is_file()]
        if stale:
            raise ValueError('Use a new snapshot after source removals: ' + repr(stale))
        # Preflight every removal against the recorded bytes. A user may have
        # replaced an old generated file with unique content since the build.
        removable = []
        for name in previous_names:
            if not included_source(name):
                target = destination / name
                assert_plain_path(target, destination)
                if target.is_file():
                    with target.open('rb') as stream:
                        actual = hashlib.file_digest(stream, 'sha256').hexdigest().upper()
                    if actual != previous_names[name]:
                        raise ValueError('Generated file changed since the snapshot; preserved: ' + name)
                    removable.append(target)
        for target in removable:
            target.unlink()
    destination.mkdir(parents=True, exist_ok=refresh)
    digests = {}
    imports = set()
    for name in sorted(set(names)):
        source = root / name
        if not included_source(name) or not source.is_file() or source.is_relative_to(destination):
            continue
        assert_plain_path(source, root)
        target = destination / name
        assert_plain_path(target, destination)
        copy_if_changed(source, target)
        with target.open('rb') as stream:
            digests[name] = hashlib.file_digest(stream, 'sha256').hexdigest().upper()
        if source.suffix == '.import':
            imports.update(IMPORT_PATH.findall(target.read_text(encoding='utf-8')))
    # A live editor's import cache can contain stale exports and test mirrors.
    # Only import products referenced by this frozen source belong to the build.
    for name in sorted(imports):
        source, target = root / name, destination / name
        assert_plain_path(source, root)
        assert_plain_path(target, destination)
        if source.is_file():
            copy_if_changed(source, target)
    for name in ("global_script_class_cache.cfg", "uid_cache.bin", "extension_list.cfg", "export_credentials.cfg"):
        source = root / ".godot" / name
        target = destination / '.godot' / name
        assert_plain_path(source, root)
        assert_plain_path(target, destination)
        if source.is_file():
            copy_if_changed(source, target)
    (destination.parent / "source-manifest.json").write_text(json.dumps(digests, indent=2), encoding="utf-8")
    return digests


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("destination", type=Path)
    parser.add_argument("--refresh", action="store_true", help="Refresh an existing diagnostic snapshot without rewriting unchanged files")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    names = subprocess.check_output(["git", "ls-files", "-c", "-o", "--exclude-standard", "-z"], cwd=root).decode().split("\0")
    destination = args.destination.absolute()
    digests = prepare_snapshot(root, destination, names, refresh=args.refresh)
    print(f"Frozen {len(digests)} public files in {destination}")


if __name__ == "__main__":
    main()
