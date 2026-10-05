import tempfile
import unittest
import random
from pathlib import Path

from PIL import Image

from scripts.tools.optimize_release_assets import optimize_card_image


class ReleaseCardImageOptimizationTests(unittest.TestCase):
    def test_lossless_webp_is_optimized_once_without_resizing_or_losing_alpha(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "latest.png.bin"
            scratch = root / "scratch"
            scratch.mkdir()
            source = Image.new("RGBA", (120, 168))
            random_pixels = random.Random(73)
            source.putdata([
                (random_pixels.randrange(256), random_pixels.randrange(256),
                 random_pixels.randrange(256), 0 if x < 3 else 255)
                for y in range(168) for x in range(120)
            ])
            # Extended WebP + EXIF is the format used by the newest card batch.
            source.save(path, format="WEBP", lossless=True, exif=b"Exif\x00\x00test")
            before = path.read_bytes()
            result = optimize_card_image(path, root, scratch)
            self.assertEqual("optimized", result.status)
            self.assertLess(path.stat().st_size, len(before))
            with Image.open(path) as optimized:
                self.assertEqual(source.size, optimized.size)
                self.assertEqual(source.getchannel("A").tobytes(), optimized.convert("RGBA").getchannel("A").tobytes())
            once = path.read_bytes()
            second = optimize_card_image(path, root, scratch)
            self.assertEqual("kept", second.status)
            self.assertEqual(once, path.read_bytes())

    def test_existing_lossy_webp_is_preserved_byte_for_byte(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "old.png.bin"
            Image.new("RGB", (300, 419), "white").save(path, format="WEBP", quality=90)
            before = path.read_bytes()
            result = optimize_card_image(path, root, root)
            self.assertEqual("kept", result.status)
            self.assertEqual(before, path.read_bytes())

    def test_invalid_image_is_preserved_and_reported(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "corrupt.png.bin"
            path.write_bytes(b"invalid-image")
            result = optimize_card_image(path, root, root)
            self.assertEqual("error", result.status)
            self.assertEqual(b"invalid-image", path.read_bytes())


if __name__ == "__main__":
    unittest.main()
