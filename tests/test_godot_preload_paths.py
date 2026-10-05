"""Catch missing script dependencies before opening the project in Godot."""
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PRELOAD = re.compile(r'\bpreload\s*\(\s*["\']([^"\']+\.gd)["\']\s*\)')


class GodotPreloadPathTests(unittest.TestCase):
    def test_public_script_preloads_resolve_in_the_source_project(self):
        missing = []
        for directory in ("addons", "scenes", "scripts", "tools"):
            for source in sorted((ROOT / directory).rglob("*.gd")):
                if any(
                    (parent / ".gdignore").exists()
                    for parent in source.parents
                    if parent != ROOT and ROOT in parent.parents
                ):
                    continue
                content = source.read_text(encoding="utf-8-sig")
                content = "\n".join(
                    line for line in content.splitlines()
                    if not line.lstrip().startswith("#")
                )
                for match in SCRIPT_PRELOAD.finditer(content):
                    reference = match.group(1)
                    if reference.startswith("res://"):
                        target = ROOT / reference.removeprefix("res://")
                    else:
                        target = source.parent / reference
                    if not target.is_file():
                        missing.append(
                            f"{source.relative_to(ROOT).as_posix()}: {reference}"
                        )
        self.assertEqual(
            missing, [], "Missing Godot preload dependencies:\n" + "\n".join(missing)
        )


if __name__ == "__main__":
    unittest.main()
