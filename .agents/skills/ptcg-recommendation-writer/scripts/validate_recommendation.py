#!/usr/bin/env python3
"""Validate a PTCG deck recommendation payload before cloud submission."""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import re
import sys
from pathlib import Path
from typing import Any


ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]{5,127}$")
IMPORT_RE = re.compile(r"^https://tcg\.mik\.moe/decks/list/([0-9]+)$")


def _load_json(path: str) -> Any:
    if path == "-":
        return json.load(sys.stdin)
    with Path(path).open("r", encoding="utf-8-sig") as fh:
        return json.load(fh)


def _is_non_empty_text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _text_len(value: Any) -> int:
    return len(value.strip()) if isinstance(value, str) else 0


def _parse_iso(value: str) -> bool:
    try:
        _dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
        return True
    except ValueError:
        return False


def validate_payload(payload: Any) -> list[str]:
    errors: list[str] = []

    if not isinstance(payload, dict):
        return ["payload must be a JSON object"]

    if "recommendation" not in payload:
        errors.append("missing top-level recommendation object")
        return errors

    priority = payload.get("priority")
    if priority is not None and (not isinstance(priority, int) or priority < 0):
        errors.append("priority must be a non-negative integer when provided")

    rec = payload.get("recommendation")
    if not isinstance(rec, dict):
        errors.append("recommendation must be an object")
        return errors

    required_text = [
        "id",
        "deck_name",
        "title",
        "style_summary",
        "best_for",
        "pilot_tip",
        "import_url",
        "generated_at",
    ]
    for key in required_text:
        if not _is_non_empty_text(rec.get(key)):
            errors.append(f"recommendation.{key} must be a non-empty string")

    rec_id = rec.get("id", "")
    if isinstance(rec_id, str) and rec_id and not ID_RE.match(rec_id):
        errors.append("recommendation.id must be stable ASCII: lowercase letters, digits, dot, underscore, hyphen")

    deck_id = rec.get("deck_id")
    if not isinstance(deck_id, int) or deck_id <= 0:
        errors.append("recommendation.deck_id must be a positive integer")

    import_url = rec.get("import_url", "")
    if isinstance(import_url, str):
        match = IMPORT_RE.match(import_url.strip())
        if not match:
            errors.append("recommendation.import_url must be https://tcg.mik.moe/decks/list/<deck_id>")
        elif isinstance(deck_id, int) and int(match.group(1)) != deck_id:
            errors.append("recommendation.import_url deck id must match recommendation.deck_id")

    generated_at = rec.get("generated_at", "")
    if isinstance(generated_at, str) and generated_at and not _parse_iso(generated_at.strip()):
        errors.append("recommendation.generated_at must be an ISO timestamp")

    why_play = rec.get("why_play")
    if not isinstance(why_play, list) or not 1 <= len(why_play) <= 3:
        errors.append("recommendation.why_play must contain 1 to 3 items")
    elif any(not _is_non_empty_text(item) for item in why_play):
        errors.append("recommendation.why_play items must be non-empty strings")

    source = rec.get("source")
    if not isinstance(source, dict):
        errors.append("recommendation.source must be an object")
    else:
        if not _is_non_empty_text(source.get("label")):
            errors.append("recommendation.source.label must be a non-empty string")
        players = source.get("players")
        if players is not None and (not isinstance(players, int) or players < 0):
            errors.append("recommendation.source.players must be a non-negative integer when provided")
        rank = source.get("rank")
        if rank is not None and (not isinstance(rank, int) or rank <= 0):
            errors.append("recommendation.source.rank must be a positive integer when provided")

    detail = rec.get("detail")
    sections = detail.get("sections") if isinstance(detail, dict) else None
    if not isinstance(sections, list) or not 1 <= len(sections) <= 8:
        errors.append("recommendation.detail.sections must contain 1 to 8 sections")
    else:
        for index, section in enumerate(sections, start=1):
            if not isinstance(section, dict):
                errors.append(f"detail section {index} must be an object")
                continue
            if not _is_non_empty_text(section.get("heading")):
                errors.append(f"detail section {index}.heading must be a non-empty string")
            if not _is_non_empty_text(section.get("body")):
                errors.append(f"detail section {index}.body must be a non-empty string")
            bullets = section.get("bullets", [])
            if bullets is not None:
                if not isinstance(bullets, list) or len(bullets) > 5:
                    errors.append(f"detail section {index}.bullets must be a list with at most 5 items")
                elif any(not _is_non_empty_text(item) for item in bullets):
                    errors.append(f"detail section {index}.bullets items must be non-empty strings")

    length_limits = {
        "deck_name": 40,
        "title": 60,
        "style_summary": 120,
        "best_for": 80,
        "pilot_tip": 100,
    }
    for key, limit in length_limits.items():
        if _text_len(rec.get(key)) > limit:
            errors.append(f"recommendation.{key} should be <= {limit} characters for the in-game UI")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("payload", help="JSON payload path, or '-' for stdin")
    args = parser.parse_args()

    try:
        payload = _load_json(args.payload)
    except Exception as exc:  # noqa: BLE001
        print(f"ERROR: failed to load JSON: {exc}", file=sys.stderr)
        return 2

    errors = validate_payload(payload)
    if errors:
        print("INVALID recommendation payload:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    rec = payload["recommendation"]
    print(
        json.dumps(
            {
                "ok": True,
                "id": rec.get("id"),
                "deck_id": rec.get("deck_id"),
                "title": rec.get("title"),
                "sections": len(rec.get("detail", {}).get("sections", [])),
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
