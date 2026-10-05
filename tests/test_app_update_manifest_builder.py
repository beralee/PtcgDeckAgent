import hashlib
import tempfile
import unittest
import zipfile
from pathlib import Path

from tools.build_app_update_manifest import build


class AppUpdateBuilderTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.package = self.root / "game.zip"
        with zipfile.ZipFile(self.package, "w") as archive:
            archive.writestr("Game.exe", b"application fixture")
        self.spec = {"latest_version": "0.7.0", "platforms": {"windows": {"version": "0.6.2", "artifacts": [{
            "file": "game.zip", "arch": "x86_64", "entry": "Game.exe", "url": "https://ptcg.skillserver.cn/dist/updates/0.6.2/game.zip"
        }]}}}

    def test_derives_integrity_from_final_bytes(self):
        result = build(self.spec, self.root)
        target = result["platforms"]["windows"]
        self.assertEqual(target["version"], "0.6.2")
        artifact = target["artifacts"][0]
        self.assertEqual(artifact["sha256"], hashlib.sha256(self.package.read_bytes()).hexdigest())
        self.assertEqual(artifact["size"], self.package.stat().st_size)
        self.assertNotIn("file", artifact)

    def test_rejects_traversal_and_case_collisions(self):
        for bad in ("../outside.exe", "folder/CON.txt", "GAME.exe"):
            with self.subTest(bad=bad):
                with zipfile.ZipFile(self.package, "w") as archive:
                    archive.writestr("Game.exe", b"fixture")
                    archive.writestr(bad, b"bad")
                with self.assertRaises(ValueError):
                    build(self.spec, self.root)

    def test_rejects_untrusted_origin_and_architecture(self):
        artifact = self.spec["platforms"]["windows"]["artifacts"][0]
        artifact["url"] = "https://ptcg.skillserver.cn.evil.test/update.zip"
        with self.assertRaises(ValueError):
            build(self.spec, self.root)
        artifact["url"] = "https://ptcg.skillserver.cn/update.zip"
        artifact["arch"] = "universal"
        with self.assertRaises(ValueError):
            build(self.spec, self.root)

    def test_preserves_independent_web_version(self):
        self.spec["platforms"]["web"] = {"version": "0.6.0.2"}
        result = build(self.spec, self.root)
        self.assertEqual(result["platforms"]["web"], {"version": "0.6.0.2"})
        self.assertTrue(result["platforms"]["windows"]["artifacts"])

    def test_macos_is_version_metadata_only(self):
        self.spec["platforms"]["macos"] = {"version": "0.7.0"}
        self.assertEqual(build(self.spec, self.root)["platforms"]["macos"], {"version": "0.7.0"})
        self.spec["platforms"]["macos"]["artifacts"] = [{"file": "game.zip"}]
        with self.assertRaises(ValueError):
            build(self.spec, self.root)


if __name__ == "__main__":
    unittest.main()
