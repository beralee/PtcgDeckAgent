"""Check the real startup graph in a fresh Godot process, before test preloads."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class StartupLoadingTests(unittest.TestCase):
    def test_home_starts_without_battle_engines_and_still_scans_catalog(self):
        godot = os.environ.get("GODOT_EXE", "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe")
        if not Path(godot).is_file():
            self.skipTest("Set GODOT_EXE to run the fresh-process startup check")
        with tempfile.TemporaryDirectory(prefix="ptcg-startup-") as user_root:
            env = dict(os.environ, APPDATA=user_root, XDG_DATA_HOME=user_root)
            for startup_state in ("first_run", "existing_install"):
                with self.subTest(startup_state=startup_state):
                    result = subprocess.run(
                        [godot, "--headless", "--path", str(ROOT), "--script",
                         "res://tests/probe_startup_loading.gd", "--", "--exercise-late-loads"],
                        env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=60,
                    )
                    self._check_result(result)

    def _check_result(self, result):
        output = result.stdout + result.stderr
        reports = [line.split("=", 1)[1] for line in output.splitlines()
                   if line.startswith("STARTUP_LOADING_REPORT=")]
        self.assertEqual(len(reports), 1, output)
        report = json.loads(reports[0])
        self.assertEqual(report["unexpected_resources"], [], output)
        self.assertTrue(report["menu_ready"], output)
        self.assertTrue(report["catalog_scanned"], output)
        self.assertTrue(report["late_loads_ok"], output)
        self.assertEqual(result.returncode, 0, output)
        self.assertNotIn("SCRIPT ERROR:", output)
        self.assertNotIn("ERROR:", output)


if __name__ == "__main__":
    unittest.main()
