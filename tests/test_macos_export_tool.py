"""Mac rules export must not load an absent optional native backend."""
import importlib.util
from pathlib import Path
import tempfile
import unittest


MODULE = Path(__file__).resolve().parents[1] / "scripts/tools/export_macos_release.py"


class MacExportToolTests(unittest.TestCase):
    def test_snapshot_ignores_extension_without_changing_cross_platform_source(self):
        spec = importlib.util.spec_from_file_location("mac_export", MODULE)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "source"
            native = root / "scripts/ai/ptcgdap/native"
            native.mkdir(parents=True)
            extension = native / "actor.gdextension"
            extension.write_text('[libraries]\nmacos="res://missing.dylib"\n')
            (root / "project.godot").write_text('[application]\nconfig/name="Game"\n')
            (root / ".DS_Store").write_text("personal")
            target = Path(temporary) / "snapshot"
            manifest = module.prepare_snapshot(root, target, [
                "project.godot", str(extension.relative_to(root)), ".DS_Store",
            ])
            self.assertTrue((target / "scripts/ai/ptcgdap/native/.gdignore").exists())
            self.assertFalse((native / ".gdignore").exists())
            self.assertEqual(extension.read_bytes(), (target / extension.relative_to(root)).read_bytes())
            self.assertFalse((target / ".DS_Store").exists())
            self.assertIn(str(extension.relative_to(root)), manifest)
            with self.assertRaises(FileExistsError):
                module.prepare_snapshot(root, target, ["project.godot"])

    def test_engine_errors_cannot_be_hidden_by_zero_exit_code(self):
        spec = importlib.util.spec_from_file_location("mac_export", MODULE)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertTrue(module.has_engine_errors('SCRIPT ERROR: Parse Error: broken'))
        self.assertTrue(module.has_engine_errors('ERROR: Failed to load extension'))
        self.assertFalse(module.has_engine_errors('[ DONE ] export'))


if __name__ == "__main__":
    unittest.main()
