from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import sys
import tempfile
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.dragapult_public_strategy import (  # noqa: E402
    DragapultPublicStrategy,
    DragapultPublicStrategyError,
)
from scripts.ai.ptcgdap.source_lock import load_json_strict  # noqa: E402


_REQUEST_ID_RE = re.compile(r"^[A-Za-z0-9._:-]{1,128}$")


def _response(
    request_id: str,
    public_observation_hash: str,
    window_id: str,
    indexes: list[int],
    *,
    ok: bool,
    error_code: str,
) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "request_id": request_id,
        "public_observation_hash": public_observation_hash,
        "window_id": window_id,
        "selected_indexes": indexes,
        "ok": ok,
        "error_code": error_code,
    }


def _handle(request: object) -> dict[str, Any]:
    request_id = ""
    observation_hash = ""
    window_id = ""
    try:
        if type(request) is not dict or set(request) != {"schema_version", "request_id", "frame"}:
            raise DragapultPublicStrategyError("invalid_request")
        if request.get("schema_version") != 1:
            raise DragapultPublicStrategyError("invalid_request")
        raw_request_id = request.get("request_id")
        if type(raw_request_id) is not str or _REQUEST_ID_RE.fullmatch(raw_request_id) is None:
            raise DragapultPublicStrategyError("invalid_request")
        request_id = raw_request_id
        frame = request.get("frame")
        if type(frame) is dict:
            source = frame.get("source")
            if type(source) is dict:
                observation_hash = str(source.get("public_observation_hash", ""))
                window_id = str(source.get("window_id", ""))
        indexes = DragapultPublicStrategy.load_default().select(frame)
        return _response(
            request_id,
            observation_hash,
            window_id,
            indexes,
            ok=True,
            error_code="",
        )
    except DragapultPublicStrategyError as exc:
        return _response(
            request_id,
            observation_hash,
            window_id,
            [],
            ok=False,
            error_code=exc.code,
        )
    except Exception:
        return _response(
            request_id,
            observation_hash,
            window_id,
            [],
            ok=False,
            error_code="internal_error",
        )


def _write_atomic(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(value, ensure_ascii=True, sort_keys=True, separators=(",", ":")) + "\n"
    descriptor, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    temp_path = Path(temp_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_path, path)
    finally:
        temp_path.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(description="Run one isolated Dragapult public strategy window.")
    parser.add_argument("--request", type=Path, required=True)
    parser.add_argument("--response", type=Path, required=True)
    args = parser.parse_args()
    try:
        request = load_json_strict(args.request)
    except Exception:
        request = None
    _write_atomic(args.response, _handle(request))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
