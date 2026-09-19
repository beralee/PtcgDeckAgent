"""Install at most five audited G/H/I/J printings from the frozen source snapshot."""

import argparse
import concurrent.futures
import json
from pathlib import Path

from import_tcg_mik_card_range import _convert_card, _fetch_image, _update_manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("indices", nargs="+")
    args = parser.parse_args()
    if not 1 <= len(args.indices) <= 5 or len(set(args.indices)) != len(args.indices):
        parser.error("Specify one to five unique printing indices")
    root = Path(__file__).resolve().parents[2]
    bundle = root / "data/bundled_user"
    source = root / ".tmp/30thc-card-audit/source"
    cards = []
    for index in args.indices:
        if not index.isalnum() or index == "057":
            parser.error("Invalid index or protected existing photo printing 057")
        raw = json.loads((source / f"{index}.json").read_text(encoding="utf-8"))
        assert raw["regulationMark"] in "GHIJ" and raw["setCode"] == "30thC" and raw["cardIndex"] == index
        card = _convert_card(raw)
        path = bundle / f"cards/30thC_{index}.json"
        if path.exists() and json.loads(path.read_text(encoding="utf-8")) != card:
            raise ValueError(f"Refusing to overwrite different existing card: {path}")
        cards.append((index, card, path))
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
        images = list(pool.map(lambda row: _fetch_image("30thC", row[0]), cards))
    entries = []
    for (index, card, path), image in zip(cards, images):
        path.write_text(json.dumps(card, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        image_path = bundle / f"cards/images/30THC/{index}.png.bin"
        image_path.parent.mkdir(parents=True, exist_ok=True)
        image_path.write_bytes(image)
        entries.extend([f"res://data/bundled_user/cards/30thC_{index}.json", f"res://data/bundled_user/cards/images/30THC/{index}.png.bin"])
    _update_manifest(bundle / "_manifest.txt", entries)
    print("Installed and source-verified: " + ", ".join(args.indices))


if __name__ == "__main__":
    main()
