from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from scripts.tools import run_macos_game as launcher


class MacSourceLauncherTests(unittest.TestCase):
    def make_project(self, root):
        (root / launcher.IGNORE).parent.mkdir(parents=True)
        (root / ".godot").mkdir()

    def test_missing_backend_is_ignored_before_import_even_with_stale_cache(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.make_project(root)
            cache = root / ".godot/extension_list.cfg"
            cache.write_text(launcher.EXTENSION + "\nres://other.gdextension\n")

            def imported(command, log):
                self.assertEqual((root / launcher.IGNORE).read_text(), launcher.MARKER)
                self.assertEqual(cache.read_text(), "res://other.gdextension\n")
                self.assertEqual(command[-1], "--import")

            with patch.object(launcher, "run_logged", side_effect=imported) as call:
                launcher.prepare_project(root, Path("godot"), root)
            call.assert_called_once()

    def test_available_libraries_only_remove_the_launchers_own_ignore(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.make_project(root)
            ignore = root / launcher.IGNORE
            ignore.write_text(launcher.MARKER)
            for library in launcher.LIBRARIES:
                path = root / library
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"fixture")
            launcher.configure_optional_runtime(root)
            self.assertFalse(ignore.exists())
            ignore.write_text("# user-owned\n")
            launcher.configure_optional_runtime(root)
            self.assertEqual(ignore.read_text(), "# user-owned\n")

    def test_failed_import_aborts_preparation(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.make_project(root)
            with patch.object(launcher, "run_logged", side_effect=RuntimeError("import failed")):
                with self.assertRaisesRegex(RuntimeError, "import failed"):
                    launcher.prepare_project(root, Path("godot"), root)


if __name__ == "__main__":
    unittest.main()
