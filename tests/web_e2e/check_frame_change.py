"""Check rendered pixels, independently of the Godot semantic test bridge."""
import json
import sys
from PIL import Image, ImageChops, ImageStat

before = Image.open(sys.argv[1]).convert("RGB").resize((128, 128))
after = Image.open(sys.argv[2]).convert("RGB").resize((128, 128))
diff = ImageChops.difference(before, after)
pixels = diff.tobytes()
print(json.dumps({
    "color_deviation": max(ImageStat.Stat(after).stddev),
    "changed_fraction": sum(max(pixel) > 16 for pixel in zip(pixels[::3], pixels[1::3], pixels[2::3])) / (128 * 128),
}))
