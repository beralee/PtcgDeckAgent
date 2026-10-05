import os
from pathlib import Path
import subprocess
import stat
import tempfile
import time
import unittest
from unittest.mock import patch

from scripts.tools import cleanup_test_artifacts as cleanup


class CleanupTestArtifacts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.now = time.time() + 48 * 3600
        self.root = Path(self.temp.name) / "project"
        self.scan = self.root / ".godot_test_user"
        self.run = self.scan / "old-run"
        self.user = self.run / "Godot/app_userdata/PtcgDeckAgent"
        self.source = self.put(self.root / "data/bundled_user/cards/images/SET/001.png", b"seed image")
        self.copy = self.put(self.user / "cards/images/SET/001.png", b"seed image")
        self.marker = self.put(self.user / ".bundled_seed_completion_v1.json", b"{}")
        self.log = self.put(self.run / "result.json", b"evidence")
        self.put(self.root / "project.godot", b"config_version=5")
        self.age()

    def put(self, path, data):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return path

    def age(self):
        for path in self.root.rglob("*"):
            if path.is_file():
                os.utime(path, (1, 1))

    def plan(self, commands=()):
        return cleanup.plan_duplicates(self.root, [self.scan], min_age_hours=24, commands=commands, now=self.now)

    def test_dry_run_preserves_files_and_only_selects_identical_seed(self):
        changed = self.put(self.user / "cards/images/SET/002.png", b"custom")
        self.put(self.root / "data/bundled_user/cards/images/SET/002.png", b"original")
        self.age()
        plan = self.plan()
        self.assertEqual([row["path"] for row in plan["files"]], [str(self.copy)])
        self.assertTrue(self.copy.exists())
        self.assertTrue(changed.exists())
        self.assertTrue(self.log.exists())

    def test_execute_keeps_evidence_and_original_invalidates_seed_marker(self):
        result = cleanup.execute_plan(self.plan(), commands=())
        self.assertEqual(result["deleted_bytes"], len(b"seed image"))
        self.assertFalse(self.copy.exists())
        self.assertFalse(self.marker.exists())
        self.assertTrue(self.source.exists())
        self.assertEqual(self.log.read_bytes(), b"evidence")

    def test_changed_file_after_plan_is_not_deleted(self):
        plan = self.plan()
        self.copy.write_bytes(b"custom image")
        result = cleanup.execute_plan(plan, commands=())
        self.assertEqual(result["deleted_bytes"], 0)
        self.assertTrue(self.copy.exists())
        self.assertTrue(self.marker.exists())

    def test_changed_original_after_plan_is_not_deleted(self):
        plan = self.plan()
        self.source.write_bytes(b"new original")
        result = cleanup.execute_plan(plan, commands=())
        self.assertEqual(result["deleted_bytes"], 0)
        self.assertTrue(self.copy.exists())

    def test_recent_run_is_kept_even_when_seed_copies_are_old(self):
        os.utime(self.log, (self.now, self.now))
        self.assertEqual(self.plan()["files"], [])

    def test_run_updated_after_plan_is_not_cleaned(self):
        plan = self.plan()
        self.put(self.run / "new-evidence.json", b"new result")
        result = cleanup.execute_plan(plan, commands=())
        self.assertEqual(result["deleted_bytes"], 0)
        self.assertTrue(self.copy.exists())

    def test_headless_userdata_environment_cannot_be_inferred_from_log_path(self):
        command = f'godot --headless --path "{self.root}" --log-file elsewhere.log'
        self.assertEqual(self.plan([command])["files"], [])

    def test_live_run_is_kept_at_plan_and_execute(self):
        command = f'godot --log-file "{self.run / "engine.log"}"'
        self.assertEqual(self.plan([command])["files"], [])
        result = cleanup.execute_plan(self.plan(), commands=[command])
        self.assertEqual(result["deleted_bytes"], 0)
        self.assertTrue(self.copy.exists())

    def test_server_in_another_run_does_not_block_all_old_runs(self):
        command = f'node "{self.scan / "unrelated-run/serve.cjs"}"'
        self.assertEqual(len(self.plan([command])["files"]), 1)
        whole_root = f'python -m http.server --directory "{self.scan}"'
        self.assertEqual(self.plan([whole_root])["files"], [])

    def test_snapshot_output_requires_project_and_preserves_unique_build(self):
        package = self.put(self.root / "output/release.apk", b"final package")
        snapshot = self.run / "snapshot"
        duplicate = self.put(snapshot / "output/release.apk", package.read_bytes())
        unique = self.put(snapshot / "output/old.apk", b"unique rollback")
        self.age()
        self.assertNotIn(str(duplicate), [row["path"] for row in self.plan()["files"]])
        self.put(snapshot / "project.godot", b"config_version=5")
        self.age()
        cleanup.execute_plan(self.plan(), commands=())
        self.assertFalse(duplicate.exists())
        self.assertTrue(package.exists())
        self.assertTrue(unique.exists())

    def test_music_mirror_is_reclaimable_but_custom_music_is_not(self):
        self.put(self.root / "assets/audio/bgm/track.mp3", b"music")
        mirror = self.put(self.user / "music/battle_bgm/track.mp3", b"music")
        custom = self.put(self.user / "custom_bgm/track.mp3", b"music")
        self.age()
        cleanup.execute_plan(self.plan(), commands=())
        self.assertFalse(mirror.exists())
        self.assertTrue(custom.exists())

    def test_seed_bin_wrapper_maps_to_unwrapped_user_image(self):
        wrapped = self.source.with_name(self.source.name + ".bin")
        self.source.rename(wrapped)
        self.age()
        result = cleanup.execute_plan(self.plan(), commands=())
        self.assertEqual(result["deleted_files"], 1)
        self.assertTrue(wrapped.exists())
        self.assertFalse(self.copy.exists())

    def test_linux_userdata_layout_uses_the_same_seed_mapping(self):
        path = self.run / "godot/app_userdata/PtcgDeckAgent/music/battle_bgm/track.mp3"
        source, kind, user = cleanup.duplicate_source(self.root, path, self.scan)
        self.assertEqual(source, self.root / "assets/audio/bgm/track.mp3")
        self.assertEqual(kind, "builtin_music")
        self.assertIsNone(user)

    def test_existing_shared_hardlinks_are_retained_without_inflating_reclaimable_bytes(self):
        alias = self.run / "shared-image.png"
        os.link(self.copy, alias)
        self.age()
        plan = self.plan()
        self.assertEqual(plan["reclaimable_bytes"], 0)
        self.assertEqual(plan["shared_links_retained"], 1)
        self.assertTrue(alias.exists())

    def test_new_hardlink_after_plan_is_preserved(self):
        plan = self.plan()
        alias = Path(self.temp.name) / "shared-image.png"
        os.link(self.copy, alias)
        self.addCleanup(alias.unlink)
        self.assertEqual(cleanup.execute_plan(plan, commands=())["deleted_bytes"], 0)
        self.assertTrue(self.copy.exists())

    @unittest.skipUnless(os.name == "nt", "Windows read-only attribute")
    def test_readonly_independent_copy_is_reclaimed_without_changing_original(self):
        self.copy.chmod(stat.S_IREAD)
        self.age()
        plan = self.plan()
        result = cleanup.execute_plan(plan, commands=())
        self.assertEqual(result["deleted_files"], 1)
        self.assertFalse(self.copy.exists())
        self.assertTrue(self.source.exists())

    def test_rejects_source_root_and_player_userdata(self):
        with self.assertRaises(ValueError):
            cleanup.plan_duplicates(self.root, [self.root], commands=())
        with self.assertRaises(ValueError):
            cleanup.plan_duplicates(self.root, [self.root / "data"], commands=())
        profile = Path(self.temp.name) / "player"
        appdata = profile / "AppData/Roaming"
        appdata.mkdir(parents=True)
        with patch.dict(os.environ, {"APPDATA": str(appdata)}):
            for root in (profile, appdata.parent, appdata, appdata / "Godot/app_userdata/PtcgDeckAgent"):
                with self.subTest(root=root), self.assertRaises(ValueError):
                    cleanup.plan_duplicates(self.root, [root], commands=())

    def test_reparse_target_is_never_followed(self):
        outside = Path(self.temp.name) / "outside"
        outside.mkdir()
        link = self.run / "linked"
        try:
            link.symlink_to(outside, target_is_directory=True)
        except OSError:
            if os.name != "nt":
                raise
            # Junctions need no symlink privilege on Windows.
            env = os.environ | {"TEST_LINK": str(link), "TEST_TARGET": str(outside)}
            subprocess.run(["powershell", "-NoProfile", "-Command",
                            "New-Item -ItemType Junction -Path $env:TEST_LINK -Target $env:TEST_TARGET | Out-Null"],
                           env=env, check=True, capture_output=True)
            self.addCleanup(lambda: link.rmdir() if link.exists() else None)
        protected = self.put(outside / "Godot/app_userdata/PtcgDeckAgent/cards/images/SET/001.png", b"seed image")
        self.age()
        cleanup.execute_plan(self.plan(), commands=())
        self.assertTrue(protected.exists())


if __name__ == "__main__":
    unittest.main()
