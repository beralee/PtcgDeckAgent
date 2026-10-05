"""Diagnostic builds must not duplicate generated exports or retain scratch trees."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import unittest

from scripts.tools import snapshot_strategy_parity as snapshot


class SnapshotStrategyParityTests(unittest.TestCase):
    def test_generated_outputs_are_excluded_even_if_git_lists_them(self):
        with tempfile.TemporaryDirectory() as temporary:
            root, target = Path(temporary) / "source", Path(temporary) / "build/snapshot"
            names = ["project.godot", "data/card.json", "output/old.apk",
                     "tmp/run/copy.png", ".godot_test_user/run/copy.png",
                     "Godot/app_userdata/file", "android/build/assets/game.pck",
                     "native/actor/build/result.dll"]
            for name in names:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"source")
            manifest = snapshot.prepare_snapshot(root, target, names)
            self.assertEqual(set(manifest), {"project.godot", "data/card.json"})
            self.assertFalse((target / "output").exists())
            self.assertFalse((target / "android").exists())
            (root / "data/card.json").write_bytes(b"changed later")
            self.assertEqual((target / "data/card.json").read_bytes(), b"source")

    def test_refresh_keeps_unchanged_files_and_replaces_changed_source(self):
        with tempfile.TemporaryDirectory() as temporary:
            root, target = Path(temporary) / "source", Path(temporary) / "build/snapshot"
            root.mkdir()
            (root / "project.godot").write_bytes(b"project")
            (root / "script.gd").write_bytes(b"before")
            names = ["project.godot", "script.gd"]
            snapshot.prepare_snapshot(root, target, names)
            unchanged = target / "project.godot"
            os.utime(unchanged, ns=(1000000000, 1000000000))
            (root / "script.gd").write_bytes(b"after")
            snapshot.prepare_snapshot(root, target, names, refresh=True)
            self.assertEqual(unchanged.stat().st_mtime_ns, 1000000000)
            self.assertEqual((target / "script.gd").read_bytes(), b"after")

    def test_only_imports_referenced_by_snapshot_sources_are_copied(self):
        with tempfile.TemporaryDirectory() as temporary:
            root, target = Path(temporary) / "source", Path(temporary) / "build/snapshot"
            (root / ".godot/imported").mkdir(parents=True)
            (root / "project.godot").write_bytes(b"project")
            (root / "texture.png.import").write_text('path="res://.godot/imported/needed.ctex"\n')
            (root / ".godot/imported/needed.ctex").write_bytes(b"needed")
            (root / ".godot/imported/old-export.ctex").write_bytes(b"old")
            snapshot.prepare_snapshot(root, target, ["project.godot", "texture.png.import"])
            self.assertEqual((target / ".godot/imported/needed.ctex").read_bytes(), b"needed")
            self.assertFalse((target / ".godot/imported/old-export.ctex").exists())

    def test_refresh_removes_only_recorded_generated_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root, target = Path(temporary) / "source", Path(temporary) / "build/snapshot"
            root.mkdir()
            (root / "project.godot").write_bytes(b"project")
            snapshot.prepare_snapshot(root, target, ["project.godot"])
            (target / "output").mkdir()
            (target / "output/old.apk").write_bytes(b"old export")
            (target / "output/user-note.txt").write_bytes(b"keep")
            manifest_path = target.parent / "source-manifest.json"
            manifest = json.loads(manifest_path.read_text())
            manifest["output/old.apk"] = hashlib.sha256(b"old export").hexdigest().upper()
            manifest_path.write_text(json.dumps(manifest))
            snapshot.prepare_snapshot(root, target, ["project.godot"], refresh=True)
            self.assertFalse((target / "output/old.apk").exists())
            self.assertEqual((target / "output/user-note.txt").read_bytes(), b"keep")

    def test_refresh_preserves_recorded_output_changed_after_the_snapshot(self):
        with tempfile.TemporaryDirectory() as temporary:
            root, target = Path(temporary) / "source", Path(temporary) / "build/snapshot"
            root.mkdir()
            (root / "project.godot").write_bytes(b"project")
            snapshot.prepare_snapshot(root, target, ["project.godot"])
            changed = target / "output/old.apk"
            changed.parent.mkdir()
            changed.write_bytes(b"unique user content")
            manifest_path = target.parent / "source-manifest.json"
            manifest = json.loads(manifest_path.read_text())
            manifest["output/old.apk"] = hashlib.sha256(b"old export").hexdigest().upper()
            manifest_path.write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, "changed since the snapshot"):
                snapshot.prepare_snapshot(root, target, ["project.godot"], refresh=True)
            self.assertEqual(changed.read_bytes(), b"unique user content")
            self.assertEqual(json.loads(manifest_path.read_text()), manifest)

    def test_refresh_rejects_manifest_path_escape(self):
        with tempfile.TemporaryDirectory() as temporary:
            root, target = Path(temporary) / "source", Path(temporary) / "build/snapshot"
            root.mkdir()
            (root / "project.godot").write_bytes(b"project")
            snapshot.prepare_snapshot(root, target, ["project.godot"])
            outside = target.parent / "do-not-delete"
            outside.write_bytes(b"keep")
            (target.parent / "source-manifest.json").write_text('{"../do-not-delete":"hash"}')
            with self.assertRaises(ValueError):
                snapshot.prepare_snapshot(root, target, ["project.godot"], refresh=True)
            self.assertEqual(outside.read_bytes(), b"keep")


@unittest.skipUnless(os.name == "nt" and shutil.which("powershell"), "Windows PowerShell lifecycle checks")
class DiagnosticBuildLifecycleTests(unittest.TestCase):
    """Run real wrapper control flow with tiny stand-ins, never a Godot export."""

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / "project"
        self.tools = self.root / "scripts/tools"
        self.tools.mkdir(parents=True)
        self.output = self.root / "exports"
        real_tools = Path(__file__).resolve().parents[1] / "scripts/tools"
        for name in ("build_performance_player.ps1", "build_strategy_parity_exports.ps1"):
            shutil.copy2(real_tools / name, self.tools / name)
        (self.tools / "snapshot_strategy_parity.py").write_text('''import json, pathlib, sys
p = pathlib.Path(sys.argv[1]); p.mkdir(parents=True, exist_ok="--refresh" in sys.argv)
(p / "project.godot").write_text('[application]\\nconfig/name="PtcgDeckAgent"\\n[autoload]\\n')
(p / "export_presets.cfg").write_text('include_filter="data/**,"\\nexclude_filter="tests/**,"\\ngradle_build/use_gradle_build=false\\ncommand_line/extra_args=""\\n')
(p.parent / "source-manifest.json").write_text(json.dumps({"project.godot":"fixture"}))
''', encoding="utf-8")
        self.godot = self.root / "tiny-export.ps1"
        self.godot.write_text('''$target = $args[-1]
Write-Output 'SNAPSHOT_TEST_EXPORT_STARTED'
if ($env:SNAPSHOT_TEST_JUNCTION) {
    New-Item -ItemType Junction -Path (Join-Path $args[2] 'linked') -Target $env:SNAPSHOT_TEST_JUNCTION | Out-Null
}
if ($env:SNAPSHOT_TEST_FAIL) { Write-Output 'SNAPSHOT_TEST_EXPORT_EXIT=9'; $global:LASTEXITCODE = 9; return }
if ($target.EndsWith('.apk')) {
    Add-Type -AssemblyName System.IO.Compression
    $stream = [IO.File]::Create($target)
    $zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
    foreach ($entry in @('lib/arm64-v8a/libgodot_android.so','lib/arm64-v8a/libonnxruntime.so','lib/arm64-v8a/libptcgai_ort.android.template_release.arm64.so','assets/tests/ai/ptcgdap/AndroidStrategyParityRunner.gdc','assets/tests/ai/ptcgdap/fixtures/platform_actor.ort','assets/tests/ai/ptcgdap/fixtures/platform_model.ptcgai')) { $null = $zip.CreateEntry($entry) }
    $zip.Dispose(); $stream.Dispose()
} else { [IO.File]::WriteAllText($target, 'tiny export') }
$global:LASTEXITCODE = 0
''', encoding="utf-8")

    def build(self, name, *, fail=False, extra=(), junction=None):
        env = os.environ.copy()
        # Codex may run under PowerShell 7; do not pass its module path to 5.1.
        env["PSMODULEPATH"] = str(Path(os.environ["SystemRoot"]) / "System32/WindowsPowerShell/v1.0/Modules")
        env.pop("SNAPSHOT_TEST_FAIL", None)
        env.pop("SNAPSHOT_TEST_JUNCTION", None)
        if fail:
            env["SNAPSHOT_TEST_FAIL"] = "1"
        if junction:
            env["SNAPSHOT_TEST_JUNCTION"] = str(junction)
        return subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                               str(self.tools / name), "-GodotExe", str(self.godot),
                               "-OutputRoot", str(self.output), *map(str, extra)],
                              env=env, capture_output=True, text=True, timeout=30)

    def test_success_releases_scratch_but_keeps_binary_manifest_and_hashes(self):
        for name in ("build_performance_player.ps1", "build_strategy_parity_exports.ps1"):
            with self.subTest(name=name):
                result = self.build(name)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                manifest = json.loads((self.output / "build.json").read_text(encoding="utf-8-sig"))
                self.assertFalse(manifest["sourceSnapshotRetained"])
                self.assertFalse(Path(manifest["sourceSnapshot"]).exists())
                self.assertTrue((self.output / "source-manifest.json").is_file())
                self.assertTrue(manifest["projectSha256"] and manifest["presetsSha256"])
                self.assertTrue(list(self.output.glob("*.apk")))

    def test_failed_export_releases_only_its_new_scratch(self):
        self.output.mkdir()
        older = self.output / ("snapshot-" + "a" * 32)
        older.mkdir()
        (older / "keep").write_text("older build")
        for name in ("build_performance_player.ps1", "build_strategy_parity_exports.ps1"):
            with self.subTest(name=name):
                result = self.build(name, fail=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(list(self.output.glob("snapshot-*")), [older])
                self.assertEqual((older / "keep").read_text(), "older build")
                self.assertTrue((self.output / "source-manifest.json").exists())

    def test_keep_and_user_supplied_reuse_remain_available_after_failure(self):
        for name in ("build_performance_player.ps1", "build_strategy_parity_exports.ps1"):
            result = self.build(name, fail=True, extra=("-KeepSourceSnapshot",))
            self.assertNotEqual(result.returncode, 0)
        retained = set(self.output.glob("snapshot-*"))
        self.assertEqual(len(retained), 2)
        reused = next(iter(retained))
        (reused / "user-note").write_text("keep")
        export_log = self.output / "android-export.private.log"
        export_log.unlink(missing_ok=True)
        result = self.build("build_performance_player.ps1", fail=True,
                            extra=("-ReuseSourceSnapshot", reused))
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(export_log.is_file(), result.stdout + result.stderr)
        self.assertIn("SNAPSHOT_TEST_EXPORT_EXIT=9", export_log.read_text(encoding="utf-16"))
        self.assertEqual(set(self.output.glob("snapshot-*")), retained)
        self.assertEqual((reused / "user-note").read_text(), "keep")

    def test_successful_reuse_in_same_output_root_keeps_the_snapshot(self):
        result = self.build("build_performance_player.ps1", extra=("-KeepSourceSnapshot",))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        original = json.loads((self.output / "build.json").read_text(encoding="utf-8-sig"))
        reused = Path(original["sourceSnapshot"])
        (reused / "user-note").write_text("keep")
        result = self.build("build_performance_player.ps1", extra=("-ReuseSourceSnapshot", reused))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        manifest = json.loads((self.output / "build.json").read_text(encoding="utf-8-sig"))
        self.assertEqual(Path(manifest["sourceSnapshot"]), reused)
        self.assertTrue(manifest["sourceSnapshotRetained"])
        self.assertEqual(list(self.output.glob("snapshot-*")), [reused])
        self.assertEqual((reused / "user-note").read_text(), "keep")

    def test_nested_junction_is_rejected_without_touching_its_target(self):
        outside = self.root / "outside"
        outside.mkdir()
        (outside / "keep").write_text("untouched")
        result = self.build("build_performance_player.ps1", fail=True, junction=outside)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("link or junction", result.stderr)
        self.assertEqual((outside / "keep").read_text(), "untouched")
        # Remove just the test junction before TemporaryDirectory cleanup.
        for retained in self.output.glob("snapshot-*/linked"):
            retained.rmdir()


if __name__ == "__main__":
    unittest.main()
