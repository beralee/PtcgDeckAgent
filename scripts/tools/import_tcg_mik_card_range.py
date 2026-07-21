#!/usr/bin/env python3
"""Import a contiguous tcg.mik.moe card range into bundled_user.

The generated JSON mirrors CardData.from_api_json().to_dict(). Images keep the
intentional .png.bin suffix used by CardDatabase's bundled seeding workflow.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
from pathlib import Path
import urllib.request


CARD_DETAIL_URL = "https://tcg.mik.moe/api/v3/card/card-detail"
IMAGE_BASE_URL = "https://tcg.mik.moe/static/img"
USER_AGENT = "PTCGTrain/1.0"
SUPPORTED_IMAGE_SIGNATURES = (
    b"\x89PNG\r\n\x1a\n",
    b"\xff\xd8",
    b"RIFF",
)


def _text(value: object) -> str:
    return value if isinstance(value, str) else ""


def _tags(value: object) -> list[str]:
    if isinstance(value, list):
        return [_text(item) for item in value if _text(item)]
    text = _text(value)
    return [text] if text else []


def _label(value: object) -> str:
    return ", ".join(_tags(value))


def _is_supported_image(payload: bytes) -> bool:
    if payload.startswith(SUPPORTED_IMAGE_SIGNATURES[0]):
        return True
    if payload.startswith(SUPPORTED_IMAGE_SIGNATURES[1]):
        return True
    return len(payload) >= 12 and payload.startswith(b"RIFF") and payload[8:12] == b"WEBP"


def _fetch_json(set_code: str, card_index: str) -> dict:
    request = urllib.request.Request(
        CARD_DETAIL_URL,
        data=json.dumps({"setCode": set_code, "cardIndex": card_index}).encode("utf-8"),
        headers={"Content-Type": "application/json", "User-Agent": USER_AGENT},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = json.load(response)
    if payload.get("code") != 200 or not isinstance(payload.get("data"), dict):
        raise RuntimeError(f"card API failed for {set_code}/{card_index}: {payload!r}")
    return payload["data"]


def _fetch_image(set_code: str, card_index: str) -> bytes:
    url = f"{IMAGE_BASE_URL}/{set_code}/{card_index}.png"
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        payload = response.read()
    if not _is_supported_image(payload):
        raise RuntimeError(f"invalid card image for {set_code}/{card_index}: {payload[:16]!r}")
    return payload


def _infer_basic_energy(name: str) -> str:
    for marker, symbol in {
        "草": "G",
        "火": "R",
        "水": "W",
        "雷": "L",
        "超": "P",
        "斗": "F",
        "恶": "D",
        "钢": "M",
    }.items():
        if marker in name:
            return symbol
    return "C"


def _convert_card(raw: dict) -> dict:
    set_code = _text(raw.get("setCode"))
    card_index = _text(raw.get("cardIndex"))
    pokemon = raw.get("pokemonAttr") if isinstance(raw.get("pokemonAttr"), dict) else {}
    weakness = pokemon.get("weakness") if isinstance(pokemon.get("weakness"), dict) else {}
    resistance = pokemon.get("resistance") if isinstance(pokemon.get("resistance"), dict) else {}

    attacks = []
    for attack in pokemon.get("attack", []) if isinstance(pokemon.get("attack"), list) else []:
        if not isinstance(attack, dict):
            continue
        cost = _text(attack.get("cost")).strip()
        attacks.append(
            {
                "name": _text(attack.get("name")),
                "text": _text(attack.get("text")),
                "cost": "" if cost == "0" else cost,
                "damage": _text(attack.get("damage")),
                "is_vstar_power": attack.get("isVStarPower") is True,
            }
        )

    abilities = []
    for ability in pokemon.get("ability", []) if isinstance(pokemon.get("ability"), list) else []:
        if isinstance(ability, dict):
            abilities.append({"name": _text(ability.get("name")), "text": _text(ability.get("text"))})

    tags: list[str] = []
    for tag in [*_tags(raw.get("is")), *_tags(raw.get("label"))]:
        normalized = {"future": "Future", "未来": "Future", "ancient": "Ancient", "古代": "Ancient"}.get(
            tag.lower(), tag
        )
        if normalized and normalized not in tags:
            tags.append(normalized)

    regulation = raw.get("regulationLegal") if isinstance(raw.get("regulationLegal"), dict) else {}
    card_type = _text(raw.get("cardType"))
    name = _text(raw.get("name"))
    return {
        "name": name,
        "card_type": card_type,
        "mechanic": _text(raw.get("mechanic")),
        "label": _label(raw.get("label")),
        "description": _text(raw.get("description")),
        "yoren_code": _text(raw.get("yorenCode")),
        "set_code": set_code,
        "card_index": card_index,
        "set_code_en": _text(raw.get("setCodeEn")),
        "card_index_en": _text(raw.get("cardIndexEn")),
        "name_en": _text(raw.get("nameEn")),
        "name_zh": "",
        "artist": _text(raw.get("artist")),
        "rarity": _text(raw.get("rarity")),
        "release_date": _text(raw.get("releaseDate")),
        "regulation_mark": _text(raw.get("regulationMark")),
        "effect_id": _text(raw.get("effectId")),
        "image_url": f"{IMAGE_BASE_URL}/{set_code}/{card_index}.png",
        "image_local_path": f"user://cards/images/{set_code}/{card_index}.png",
        "source_provider": "tcg_mik",
        "source_url": f"https://tcg.mik.moe/cards/{set_code}/{card_index}",
        "source_set_code": set_code,
        "source_card_index": card_index,
        "source_language": "zh-CN",
        "source_prints": [],
        "source_imported_at": 0,
        "source_parser_version": 1,
        "is_tags": tags,
        "regulation_standard": regulation.get("standard", True) is True,
        "regulation_expanded": regulation.get("expanded", True) is True,
        "energy_type": _text(pokemon.get("energyType")),
        "stage": _text(pokemon.get("stage")),
        "hp": int(pokemon.get("hp", 0) or 0),
        "weakness_energy": _text(weakness.get("energy")),
        "weakness_value": _text(weakness.get("value")),
        "resistance_energy": _text(resistance.get("energy")),
        "resistance_value": _text(resistance.get("value")),
        "retreat_cost": int(pokemon.get("retreatCost", 0) or 0),
        "evolves_from": _text(pokemon.get("evolvesFrom")),
        "ancient_trait": _text(pokemon.get("ancientTrait")),
        "attacks": attacks,
        "abilities": abilities,
        "energy_provides": _infer_basic_energy(name) if card_type == "Basic Energy" else "",
    }


def _fetch_card(set_code: str, index: int) -> tuple[str, dict, bytes]:
    card_index = f"{index:03d}"
    raw = _fetch_json(set_code, card_index)
    image = _fetch_image(set_code, card_index)
    return card_index, _convert_card(raw), image


def _update_manifest(manifest_path: Path, entries: list[str]) -> None:
    existing_text = manifest_path.read_text(encoding="utf-8") if manifest_path.exists() else ""
    lines = existing_text.splitlines()
    known = set(lines)
    added = [entry for entry in entries if entry not in known]
    if not added:
        return
    if lines and lines[-1] != "":
        lines.append("")
    lines.extend(added)
    manifest_path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--set", required=True, dest="set_code")
    parser.add_argument("--start", required=True, type=int)
    parser.add_argument("--end", required=True, type=int)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--workers", type=int, default=10)
    args = parser.parse_args()
    if args.start > args.end:
        parser.error("--start must not exceed --end")

    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.workers)) as executor:
        cards = list(executor.map(lambda index: _fetch_card(args.set_code, index), range(args.start, args.end + 1)))

    cards_dir = args.root / "data" / "bundled_user" / "cards"
    images_dir = cards_dir / "images" / args.set_code
    images_dir.mkdir(parents=True, exist_ok=True)
    manifest_entries: list[str] = []
    for card_index, card, image in sorted(cards):
        json_path = cards_dir / f"{args.set_code}_{card_index}.json"
        image_path = images_dir / f"{card_index}.png.bin"
        json_path.write_text(json.dumps(card, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
        image_path.write_bytes(image)
        manifest_entries.append(f"res://data/bundled_user/cards/{args.set_code}_{card_index}.json")
    for card_index, _card, _image in sorted(cards):
        manifest_entries.append(f"res://data/bundled_user/cards/images/{args.set_code}/{card_index}.png.bin")
    _update_manifest(args.root / "data" / "bundled_user" / "_manifest.txt", manifest_entries)
    print(f"Imported {len(cards)} cards from {args.set_code} {args.start:03d}-{args.end:03d}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
