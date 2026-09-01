import re
import unittest

from tools.ptcgdap.build_bundled_seed_revision import REVISION, compute_revision


class BundledSeedRevisionTests(unittest.TestCase):
    def test_bundled_seed_revision_pins_every_manifest_entry(self) -> None:
        expected = REVISION.read_text(encoding="utf-8").strip()
        self.assertRegex(expected, re.compile(r"^[0-9A-F]{64}$"))
        self.assertEqual(expected, compute_revision())


if __name__ == "__main__":
    unittest.main()
