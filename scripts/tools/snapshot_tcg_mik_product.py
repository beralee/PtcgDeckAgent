"""Snapshot an exact product listing and its card rules, without installing cards."""

from __future__ import annotations

import argparse
import concurrent.futures
import json
from pathlib import Path
import time
import urllib.request

from import_tcg_mik_card_range import _fetch_json


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--set", required=True, dest="set_code")
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    product_path = args.output / "product.json"
    if product_path.exists():
        product = json.loads(product_path.read_text(encoding="utf-8"))
    else:
        request = urllib.request.Request(
            "https://tcg.mik.moe/api/v3/card/product-detail",
            data=json.dumps({"setId": args.set_code}).encode(),
            headers={"Content-Type": "application/json", "User-Agent": "PTCGDAP/1.0"},
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.load(response)
        if payload.get("code") != 200:
            raise RuntimeError(payload)
        product = payload["data"]
        product_path.write_text(json.dumps(product, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    def fetch(entry: dict) -> dict:
        index = entry["cardIndex"]
        path = args.output / f"{index}.json"
        if path.exists():
            return json.loads(path.read_text(encoding="utf-8"))
        for attempt in range(3):
            try:
                raw = _fetch_json(args.set_code, index)
                if raw.get("setCode") != args.set_code or raw.get("cardIndex") != index:
                    raise ValueError(f"Identity mismatch: {index}")
                path.write_text(json.dumps(raw, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
                return raw
            except Exception:
                if attempt == 2:
                    raise
                time.sleep(attempt + 1)
        raise AssertionError("unreachable")

    cards = []
    entries = product["cards"]
    # Network-only threads: no engine simulations or process pools.
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        for start in range(0, len(entries), 5):
            cards.extend(executor.map(fetch, entries[start:start + 5]))
            print(f"Snapshotted {len(cards)}/{len(entries)}", flush=True)
    inventory = []
    for card in cards:
        inventory.append({
            "card_index": card["cardIndex"], "name": card["name"],
            "regulation_mark": card.get("regulationMark"),
            "effect_id": card.get("effectId"), "card_type": card.get("cardType"),
            "in_scope": card.get("regulationMark") in {"G", "H", "I", "J"},
        })
    (args.output / "inventory.json").write_text(json.dumps(inventory, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    selected = [card for card in inventory if card["in_scope"]]
    print(f"G/H/I/J: {len(selected)} printings, {len({card['effect_id'] for card in selected})} effects")


if __name__ == "__main__":
    main()
