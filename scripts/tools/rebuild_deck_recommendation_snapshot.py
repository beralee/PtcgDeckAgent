#!/usr/bin/env python3
"""Rebuild immutable recommendation deck snapshots from finalized event ranks."""

from __future__ import annotations

import argparse
import hashlib
import json
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


RECOMMENDATION_ENDPOINT = "http://fc.skillserver.cn/decksuggest"
TCG_API_BASE = "https://tcg.mik.moe/api/v3"
DEFAULT_OUTPUT = Path("data/deck_recommendations_web.json")
DEFAULT_PRIORITY_BASE = 400

# Recommendation ids are stable client/cache identities. The event and deck ids
# below are the finalized tcg.mik.moe records verified from event rank rows.
FINALIZED_SOURCES: dict[str, tuple[int, int, str]] = {
    "2026-08-16-t3509-d664900-v180-week5-hydrapple-ogerpon": (3506, 13, "蜜集大蛇 厄诡椪"),
    "2026-08-16-t3504-d667635-v180-week5-charizard-noctowl": (3512, 8, "喷火龙 猫头夜鹰"),
    "2026-08-16-t3512-d652710-v180-week5-gholdengo-dragapult": (3513, 3, "赛富豪 多龙巴鲁托"),
    "2026-08-19-t3506-d654422-v180-week5-raging-bolt-ogerpon": (3507, 1, "猛雷鼓 厄诡椪"),
    "2026-08-16-t3509-d653239-v180-week5-dragapult-dusknoir": (3506, 1, "多龙巴鲁托 黑夜魔灵"),
    "2026-08-09-t3490-d664356-iron-thorns-week4": (3483, 2, "铁荆棘"),
    "2026-08-08-t3501-d664180-hydreigon-week4": (3500, 5, "三首恶龙"),
    "2026-08-08-t3486-d658854-team-rocket-spidops-week4": (3495, 7, "火箭队的操陷蛛"),
    "2026-08-08-t3485-d662781-archaludon-week4": (3493, 2, "铝钢桥龙"),
    "2026-08-08-t3493-d663440-tera-box-week4": (3499, 1, "太晶Box"),
    "2026-08-02-t3475-d649596-gardevoir": (3475, 1, "沙奈朵"),
    "2026-08-02-t3475-d654034-charizard-pidgeot": (3475, 2, "喷火龙 大比鸟"),
    "2026-08-02-t3475-d653335-dragapult-dusknoir": (3475, 3, "多龙巴鲁托 黑夜魔灵"),
    "2026-08-02-t3475-d653331-raging-bolt-ogerpon": (3475, 4, "猛雷鼓 厄诡椪"),
    "2026-08-02-t3475-d646600-marnie-grimmsnarl-froslass": (3475, 5, "玛俐的长毛巨魔 雪妖女"),
    "2026-08-02-t3475-d654451-flareon-noctowl": (3475, 7, "火伊布 猫头夜鹰"),
    "2026-08-02-t3475-d656560-ns-zoroark": (3475, 15, "N的索罗亚克"),
    "2026-08-02-t3475-d643453-joltik-box": (3475, 17, "电电虫Box"),
    "2026-08-02-t3475-d645436-cynthia-garchomp": (3475, 28, "竹兰的烈咬陆鲨"),
    "2026-07-25-t3443-d644023-gardevoir": (3443, 1, "沙奈朵"),
}


def post_json(url: str, payload: dict[str, Any], timeout: float = 20.0) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={
            "Content-Type": "application/json; charset=utf-8",
            "User-Agent": "PTCGRecommendationSnapshotAudit/1.0",
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        parsed = json.loads(response.read().decode("utf-8"))
    if not isinstance(parsed, dict):
        raise RuntimeError(f"{url} returned a non-object response")
    return parsed


def tcg_post(path: str, payload: dict[str, Any]) -> dict[str, Any]:
    response = post_json(f"{TCG_API_BASE}/{path}", payload)
    if int(response.get("code", 0)) != 200:
        raise RuntimeError(f"{path} failed: {response.get('msg', response)}")
    data = response.get("data", {})
    if not isinstance(data, dict):
        raise RuntimeError(f"{path} returned invalid data")
    return data


def fetch_recommendations() -> list[dict[str, Any]]:
    response = post_json(RECOMMENDATION_ENDPOINT, {"limit": 20, "source": "snapshot_rebuild"})
    if not response.get("ok"):
        raise RuntimeError(str(response.get("message", response)))
    raw_items = response.get("recommendations", [])
    if not isinstance(raw_items, list) or not raw_items:
        single = response.get("recommendation")
        raw_items = [single] if isinstance(single, dict) else []
    items = [item for item in raw_items if isinstance(item, dict)]
    if len(items) != len(FINALIZED_SOURCES):
        raise RuntimeError(f"expected {len(FINALIZED_SOURCES)} active recommendations, got {len(items)}")
    return items


def rank_row(tournament_id: int, rank: int) -> tuple[dict[str, Any], dict[str, Any]]:
    tournament = tcg_post("tournament/detail", {"tournamentId": tournament_id})
    ranking = tcg_post(
        "tournament/rank-individual",
        {"tournamentId": tournament_id, "page": 1, "pageSize": 64},
    )
    rows = ranking.get("list", [])
    if not isinstance(rows, list):
        raise RuntimeError(f"tournament {tournament_id} has invalid rank data")
    for row in rows:
        if isinstance(row, dict) and int(row.get("rank", 0)) == rank:
            return tournament, row
    raise RuntimeError(f"tournament {tournament_id} has no rank {rank}")


def normalized_cards(deck_data: dict[str, Any]) -> list[dict[str, Any]]:
    cards_raw = deck_data.get("cards", [])
    if not isinstance(cards_raw, list):
        raise RuntimeError("deck detail cards is not an array")
    cards: list[dict[str, Any]] = []
    for raw in cards_raw:
        if not isinstance(raw, dict):
            continue
        card = {
            "set_code": str(raw.get("setCode", "")).strip(),
            "card_index": str(raw.get("cardIndex", "")).strip(),
            "count": int(raw.get("count", 0)),
            "name": str(raw.get("cardName", "")).strip(),
            "name_en": str(raw.get("nameEn", "")).strip(),
            "card_type": str(raw.get("cardType", "")).strip(),
            "effect_id": str(raw.get("effectId", "")).strip(),
        }
        if not card["set_code"] or not card["card_index"] or card["count"] <= 0:
            raise RuntimeError(f"invalid card row: {raw}")
        cards.append(card)
    cards.sort(key=lambda item: (item["set_code"], item["card_index"], item["name"]))
    total = sum(int(card["count"]) for card in cards)
    if total != 60:
        raise RuntimeError(f"deck snapshot contains {total} cards instead of 60")
    return cards


def card_fingerprint(cards: list[dict[str, Any]]) -> str:
    identity = "\n".join(
        f"{card['set_code']}:{card['card_index']}:{card['count']}" for card in cards
    )
    return hashlib.sha256(identity.encode("utf-8")).hexdigest()


def write_submission_payloads(
    recommendations: list[dict[str, Any]],
    payload_dir: Path,
    priority_base: int,
) -> list[Path]:
    payload_dir.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []
    for index, recommendation in enumerate(recommendations, start=1):
        cloud_recommendation = {
            key: value
            for key, value in recommendation.items()
            if key != "deck_snapshot"
        }
        payload = {
            "priority": max(0, priority_base - index + 1),
            "recommendation": cloud_recommendation,
        }
        recommendation_id = str(recommendation.get("id", "")).strip()
        payload_path = payload_dir / f"{index:02d}-{recommendation_id}.json"
        payload_path.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        written.append(payload_path)
    return written


def build_snapshot(item: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    recommendation_id = str(item.get("id", "")).strip()
    if recommendation_id not in FINALIZED_SOURCES:
        raise RuntimeError(f"no finalized source mapping for {recommendation_id}")
    tournament_id, expected_rank, expected_variant = FINALIZED_SOURCES[recommendation_id]
    tournament, row = rank_row(tournament_id, expected_rank)
    decks = row.get("decks", [])
    if not isinstance(decks, list) or len(decks) != 1 or not isinstance(decks[0], dict):
        raise RuntimeError(f"{recommendation_id} rank row does not contain exactly one deck")
    rank_deck = decks[0]
    deck_id = int(rank_deck.get("deckId", 0))
    variant_name = str(rank_deck.get("variantName", "")).strip()
    if deck_id <= 0 or variant_name != expected_variant:
        raise RuntimeError(
            f"{recommendation_id} expected {expected_variant}, got deck={deck_id} variant={variant_name}"
        )

    deck_data = tcg_post("deck/detail", {"deckId": deck_id})
    detail_variant = deck_data.get("variant", {})
    if not isinstance(detail_variant, dict) or str(detail_variant.get("variantName", "")).strip() != expected_variant:
        raise RuntimeError(f"{recommendation_id} deck detail variant no longer matches rank data")
    cards = normalized_cards(deck_data)
    event_date = str(tournament.get("date", ""))[:10]
    corrected = json.loads(json.dumps(item, ensure_ascii=False))
    corrected["deck_id"] = deck_id
    corrected["import_url"] = f"https://tcg.mik.moe/decks/list/{deck_id}"
    corrected["source"] = {
        "label": str(tournament.get("name", "")).strip(),
        "city": str(tournament.get("location", "")).strip(),
        "date": event_date,
        "players": int(tournament.get("participantCount", 0)),
        "rank": expected_rank,
        "url": f"https://tcg.mik.moe/tournaments/{tournament_id}",
    }
    corrected.pop("server_order", None)
    corrected.pop("server_order_batch", None)
    corrected["deck_snapshot"] = {
        "deck_id": deck_id,
        "source_provider": "tcg_mik",
        "source_tournament_id": tournament_id,
        "source_rank": expected_rank,
        "variant_id": int(detail_variant.get("variantId", rank_deck.get("variantId", 0))),
        "variant_name": expected_variant,
        "deck_code": str(deck_data.get("deckCode", "")).strip(),
        "total_cards": 60,
        "fingerprint_sha256": card_fingerprint(cards),
        "cards": cards,
    }
    audit = {
        "id": recommendation_id,
        "tournament_id": tournament_id,
        "rank": expected_rank,
        "deck_id": deck_id,
        "variant": expected_variant,
        "fingerprint": corrected["deck_snapshot"]["fingerprint_sha256"],
    }
    return corrected, audit


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--payload-dir", type=Path)
    parser.add_argument("--priority-base", type=int, default=DEFAULT_PRIORITY_BASE)
    args = parser.parse_args()

    recommendations = fetch_recommendations()
    rebuilt: list[dict[str, Any]] = []
    audit_rows: list[dict[str, Any]] = []
    for item in recommendations:
        corrected, audit = build_snapshot(item)
        rebuilt.append(corrected)
        audit_rows.append(audit)

    result = {
        "schema_version": 2,
        "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "total_available": len(rebuilt),
        "snapshot_policy": "finalized-event-rank-and-immutable-60-card-list",
        "recommendations": rebuilt,
    }
    if args.write:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(
            json.dumps(result, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    payload_paths: list[Path] = []
    if args.payload_dir is not None:
        payload_paths = write_submission_payloads(
            rebuilt,
            args.payload_dir,
            args.priority_base,
        )
    print(json.dumps({
        "written": bool(args.write),
        "output": str(args.output),
        "payloads": [str(path) for path in payload_paths],
        "items": audit_rows,
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
