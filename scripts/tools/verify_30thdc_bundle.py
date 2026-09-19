"""Check every 30thDC asset against the frozen source without network access."""
import json
from pathlib import Path

from import_tcg_mik_card_range import _convert_card


ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    fixture = ROOT / "tests/fixtures/30thdc_source.json"
    source = json.loads(fixture.read_text(encoding="utf-8"))
    expected_indexes = {f"{i:03d}" for i in range(1, 41)} | {"GRA", "FIR", "LIG", "PSY", "DAR"}
    cards = source["cards"]
    assert len(cards) == 45
    assert {card["cardIndex"] for card in cards} == expected_indexes
    bundle = ROOT / "data/bundled_user"
    manifest = (bundle / "_manifest.txt").read_text(encoding="utf-8").splitlines()
    image_bytes = 0
    for raw in cards:
        index = raw["cardIndex"]
        card_path = bundle / f"cards/30thDC_{index}.json"
        image_path = bundle / f"cards/images/30thDC/{index}.png.bin"
        actual = json.loads(card_path.read_text(encoding="utf-8"))
        assert actual == _convert_card(raw), f"Source mismatch: {index}"
        for path in (card_path, image_path):
            resource_path = "res://" + path.relative_to(ROOT).as_posix()
            assert manifest.count(resource_path) == 1, f"Missing/duplicate manifest entry: {resource_path}"
            assert path.name in {item.name for item in path.parent.iterdir()}, f"Case mismatch: {path}"
        image = image_path.read_bytes()
        assert image[:4] == b"RIFF" and image[8:12] == b"WEBP", f"Image is not WebP: {index}"
        image_bytes += len(image)
    print(f"Verified 45 exact source JSONs, 45 WebP images ({image_bytes:,} bytes), and 90 unique manifest entries.")


if __name__ == "__main__":
    main()
