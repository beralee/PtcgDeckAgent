"""Verify the frozen 30thC source against installed JSON, images and manifest."""
import argparse
import json
from pathlib import Path

from import_tcg_mik_card_range import _convert_card, _is_supported_image

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--normalize-manifest", action="store_true")
    args = parser.parse_args()
    bundle = ROOT / "data/bundled_user"
    manifest_path = bundle / "_manifest.txt"
    manifest = manifest_path.read_text(encoding="utf-8").splitlines()
    if args.normalize_manifest:
        manifest = [s.replace("cards/images/30thC/", "cards/images/30THC/") for s in manifest]
        manifest_path.write_text("\n".join(manifest) + "\n", encoding="utf-8")
    source = ROOT / ".tmp/30thc-card-audit/source"
    rows = json.loads((source / "inventory.json").read_text(encoding="utf-8"))
    reviewed = []
    for row in rows:
        if not row["in_scope"]:
            continue
        index = row["card_index"]
        raw = json.loads((source / f"{index}.json").read_text(encoding="utf-8"))
        name = f"30THC_{index}.json" if index == "057" else f"30thC_{index}.json"
        path = bundle / "cards" / name
        card = json.loads(path.read_text(encoding="utf-8"))
        if index != "057":
            assert card == _convert_card(raw), f"Source mismatch: {index}"
        else:
            assert card["source_provider"] == "user_photo" and card["effect_id"] == "9256615fd387482e220b7e2630343eb7"
        image = bundle / f"cards/images/30THC/{index}.png.bin"
        assert _is_supported_image(image.read_bytes()), f"Invalid image: {index}"
        for asset in [path, image]:
            expected = "res://" + asset.relative_to(ROOT).as_posix()
            assert manifest.count(expected) == 1, f"Missing/duplicate/case-incorrect manifest entry: {expected}"
            assert asset.name in [p.name for p in asset.parent.iterdir()], f"Case mismatch: {asset}"
        reviewed.append({"index": index, "source_match": index != "057", "preserved_photo_identity": index == "057", "image_valid": True, "manifest_valid": True})
    output = {"printings": len(reviewed), "source_exact": len(reviewed) - 1, "preserved_legacy_photo": 1, "results": reviewed}
    (source.parent / "bundle-verification.json").write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print(f"Verified {len(reviewed)} printings: {len(reviewed)-1} exact API JSON + protected photo 057; all images and manifest references valid")


if __name__ == "__main__":
    main()
