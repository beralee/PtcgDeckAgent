#!/usr/bin/env python3
"""Submit a validated deck recommendation payload to the cloud function."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


DEFAULT_ENDPOINT = "http://fc.skillserver.cn/suggestinsert"
DEFAULT_DECK_CENTER_ENDPOINT = "http://fc.skillserver.cn/deckcentermeta"
DECK_CENTER_SECRET_ENV = "PTCG_DECK_CENTER_UPDATE_SECRET"
DEFAULT_DECK_CENTER_SECRET_FILE = Path(__file__).with_name("deck_center_secret.local")


def _load_payload(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8-sig") as fh:
        payload = json.load(fh)
    if not isinstance(payload, dict):
        raise RuntimeError("payload must be a JSON object")
    return payload


def _load_default_deck_center_secret() -> str:
    env_secret = os.environ.get(DECK_CENTER_SECRET_ENV, "").strip()
    if env_secret:
        return env_secret
    if DEFAULT_DECK_CENTER_SECRET_FILE.exists():
        return DEFAULT_DECK_CENTER_SECRET_FILE.read_text(encoding="utf-8-sig").strip()
    return ""


def _run_validator(path: Path) -> None:
    validator = Path(__file__).with_name("validate_recommendation.py")
    result = subprocess.run(
        [sys.executable, str(validator), str(path)],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        if result.stdout:
            print(result.stdout, file=sys.stderr)
        if result.stderr:
            print(result.stderr, file=sys.stderr)
        raise RuntimeError("payload failed validation")


def _post_json(endpoint: str, payload: dict[str, Any], timeout: float) -> tuple[int, str, Any]:
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
        status = response.status

    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        parsed = None
    return status, raw, parsed


def _post_form(endpoint: str, payload: dict[str, Any], timeout: float) -> tuple[int, str, Any]:
    body = urllib.parse.urlencode({
        "data": json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
    }).encode("utf-8")
    request = urllib.request.Request(
        endpoint,
        data=body,
        headers={
            "Content-Type": "application/x-www-form-urlencoded; charset=utf-8",
            "User-Agent": "PTCGRecommendationWriter/1.0",
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        raw = response.read().decode("utf-8", errors="replace")
        status = response.status

    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        parsed = None
    return status, raw, parsed


def _is_success_response(status: int, parsed: Any) -> bool:
    if status < 200 or status >= 300:
        return False
    if isinstance(parsed, dict) and parsed.get("ok") is False:
        return False
    return True


def _build_deck_center_update_payload(
    recommendation_payload: dict[str, Any],
    secret: str,
    source: str,
) -> dict[str, Any]:
    rec = recommendation_payload.get("recommendation", {})
    if not isinstance(rec, dict):
        rec = {}
    generated_at = rec.get("generated_at")
    recommendation_id = rec.get("id")
    deck_id = rec.get("deck_id")
    revision_parts = [
        str(generated_at or "").strip(),
        str(recommendation_id or "").strip(),
        str(deck_id or "").strip(),
    ]
    latest_revision = ":".join([part for part in revision_parts if part])
    return {
        "action": "update",
        "secret": secret,
        "source": source,
        "latest_revision": latest_revision,
        "latest_recommendation_id": recommendation_id,
        "latest_deck_id": deck_id,
        "latest_title": rec.get("title"),
        "latest_deck_name": rec.get("deck_name"),
        "generated_at": generated_at,
    }


def _update_deck_center_meta(
    endpoint: str,
    recommendation_payload: dict[str, Any],
    secret: str,
    source: str,
    timeout: float,
) -> dict[str, Any]:
    update_payload = _build_deck_center_update_payload(recommendation_payload, secret, source)
    status, raw, parsed = _post_form(endpoint, update_payload, timeout)
    result: dict[str, Any] = {"http_status": status}
    if parsed is None:
        result["raw"] = raw
        result["ok"] = 200 <= status < 300
    else:
        result["response"] = parsed
        result["ok"] = _is_success_response(status, parsed)
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("payload", type=Path)
    parser.add_argument("--endpoint", default=DEFAULT_ENDPOINT)
    parser.add_argument("--deck-center-endpoint", default=DEFAULT_DECK_CENTER_ENDPOINT)
    parser.add_argument("--deck-center-secret", default=_load_default_deck_center_secret())
    parser.add_argument("--deck-center-source", default="ptcg_recommendation_writer")
    parser.add_argument("--skip-deck-center-update", action="store_true")
    parser.add_argument(
        "--require-deck-center-update",
        action="store_true",
        help="return a non-zero exit code if the deck center metadata update is skipped or fails",
    )
    parser.add_argument("--timeout", type=float, default=15.0)
    parser.add_argument("--deck-center-timeout", type=float, default=10.0)
    parser.add_argument("--dry-run", action="store_true", help="validate and print payload summary without submitting")
    args = parser.parse_args()

    try:
        payload = _load_payload(args.payload)
        _run_validator(args.payload)
    except Exception as exc:  # noqa: BLE001
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    rec = payload.get("recommendation", {})
    summary = {
        "id": rec.get("id"),
        "deck_id": rec.get("deck_id"),
        "title": rec.get("title"),
        "endpoint": args.endpoint,
        "deck_center_endpoint": args.deck_center_endpoint,
        "deck_center_update_enabled": not args.skip_deck_center_update,
        "deck_center_secret_configured": bool(str(args.deck_center_secret).strip()),
    }

    if args.dry_run:
        print(json.dumps({"dry_run": True, **summary}, ensure_ascii=False, indent=2))
        return 0

    try:
        status, raw, parsed = _post_json(args.endpoint, payload, args.timeout)
    except (urllib.error.URLError, TimeoutError) as exc:
        print(f"ERROR: submit request failed: {exc}", file=sys.stderr)
        return 1

    submit_success = _is_success_response(status, parsed)
    output: dict[str, Any]
    if parsed is None:
        output = {"http_status": status, "raw": raw, "submitted": summary}
    else:
        output = {"http_status": status, "response": parsed, "submitted": summary}

    if not submit_success:
        print(json.dumps(output, ensure_ascii=False, indent=2))
        return 1

    deck_center_secret = str(args.deck_center_secret).strip()
    deck_center_update: dict[str, Any] = {
        "endpoint": args.deck_center_endpoint,
        "skipped": False,
    }
    if args.skip_deck_center_update:
        deck_center_update.update({"skipped": True, "reason": "skip flag set"})
    elif not deck_center_secret:
        deck_center_update.update({
            "skipped": True,
            "reason": f"missing {DECK_CENTER_SECRET_ENV}",
        })
    else:
        try:
            deck_center_update.update(_update_deck_center_meta(
                args.deck_center_endpoint,
                payload,
                deck_center_secret,
                args.deck_center_source,
                args.deck_center_timeout,
            ))
        except (urllib.error.URLError, TimeoutError) as exc:
            deck_center_update.update({"ok": False, "error": str(exc)})

    output["deck_center_update"] = deck_center_update
    print(json.dumps(output, ensure_ascii=False, indent=2))

    if args.require_deck_center_update and (deck_center_update.get("skipped") or deck_center_update.get("ok") is False):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
