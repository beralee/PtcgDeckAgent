#!/usr/bin/env python3
"""Fetch the current server recommendation rotation and print known ids."""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from typing import Any


DEFAULT_ENDPOINT = "http://fc.skillserver.cn/decksuggest"


def _post_json(endpoint: str, payload: dict[str, Any], timeout: float) -> dict[str, Any]:
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        endpoint,
        data=body,
        headers={
            "Content-Type": "application/json; charset=utf-8",
            "User-Agent": "PTCGRecommendationWriter/1.0",
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        raw = response.read().decode("utf-8", errors="replace")
    parsed = json.loads(raw)
    if not isinstance(parsed, dict):
        raise RuntimeError("server response is not a JSON object")
    return parsed


def fetch_existing(endpoint: str, timeout: float, max_rounds: int) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    seen_ids: set[str] = set()
    current_id = ""

    for _ in range(max_rounds):
        response = _post_json(
            endpoint,
            {
                "current_id": current_id,
                "exclude_ids": list(seen_ids),
                "source": "ptcg_recommendation_writer",
            },
            timeout,
        )
        if not response.get("ok"):
            raise RuntimeError(str(response.get("message") or response))

        rec = response.get("recommendation")
        if not isinstance(rec, dict):
            break

        rec_id = str(rec.get("id", "")).strip()
        if not rec_id or rec_id in seen_ids:
            break

        seen_ids.add(rec_id)
        current_id = rec_id
        results.append(rec)

        total = response.get("total_available", response.get("total"))
        if isinstance(total, int) and len(results) >= total:
            break

    return results


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--endpoint", default=DEFAULT_ENDPOINT)
    parser.add_argument("--timeout", type=float, default=10.0)
    parser.add_argument("--max-rounds", type=int, default=40)
    args = parser.parse_args()

    try:
        records = fetch_existing(args.endpoint, args.timeout, args.max_rounds)
    except (urllib.error.URLError, TimeoutError, RuntimeError, json.JSONDecodeError) as exc:
        print(f"ERROR: failed to fetch recommendations: {exc}", file=sys.stderr)
        return 1

    summary = [
        {
            "id": record.get("id"),
            "deck_id": record.get("deck_id"),
            "deck_name": record.get("deck_name"),
            "source": record.get("source", {}),
            "import_url": record.get("import_url"),
        }
        for record in records
    ]
    print(json.dumps({"count": len(summary), "recommendations": summary}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
