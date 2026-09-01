from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import sys
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlsplit
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.author_strategy_package import (
    AuthorStrategyPackageError,
    AuthorStrategyPackageLoader,
)
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_bytes_strict


MAX_ARCHIVE_BYTES = 16 * 1024 * 1024


class PublishError(RuntimeError):
    pass


def publish(
    *,
    endpoint: str,
    strategy_id: str,
    package_path: Path,
    token: str,
    allow_insecure_loopback: bool = False,
) -> dict[str, Any]:
    base = _validated_endpoint(endpoint, allow_insecure_loopback)
    if not _valid_token(token):
        raise PublishError("platform_write_token_invalid")
    if not package_path.is_file() or package_path.is_symlink():
        raise PublishError("package_file_invalid")
    raw = package_path.read_bytes()
    if not raw or len(raw) > MAX_ARCHIVE_BYTES:
        raise PublishError("package_resource_limit_exceeded")
    try:
        local = AuthorStrategyPackageLoader().load_bytes(raw)
    except AuthorStrategyPackageError as error:
        raise PublishError(str(error)) from error
    request = Request(
        f"{base}/v1/strategy-releases?strategy_id={quote(strategy_id, safe='._:-')}",
        data=raw,
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/vnd.ptcgdap.strategy-package",
            "Accept": "application/json",
        },
    )
    try:
        with urlopen(request, timeout=45) as response:
            status = response.status
            body = response.read(4 * 1024 * 1024 + 1)
    except HTTPError as error:
        body = error.read(64 * 1024)
        try:
            value = load_json_bytes_strict(body)
            code = value.get("error_code", "platform_server_rejected")
        except (UnicodeError, ValueError, AttributeError):
            code = "platform_server_rejected"
        raise PublishError(str(code)) from error
    except URLError as error:
        raise PublishError("platform_transport_failed") from error
    if status not in (200, 201) or len(body) > 4 * 1024 * 1024:
        raise PublishError("platform_response_invalid")
    try:
        value = load_json_bytes_strict(body)
    except (UnicodeError, ValueError) as error:
        raise PublishError("platform_response_invalid") from error
    if (
        type(value) is not dict
        or value.get("authoritative") is not False
        or value.get("grants") != []
        or type(value.get("record")) is not dict
        or value["record"].get("package_id") != local.package_id
        or value["record"].get("package_version") != local.package_version
        or value["record"].get("archive_sha256") != local.archive_sha256
    ):
        raise PublishError("platform_response_invalid")
    return {
        "document_type": "strategy_release_submission_report_v1",
        "schema_version": 1,
        "created": value.get("created"),
        "release": value["record"],
        "credential_persisted": False,
        "production_authority": False,
        "authoritative": False,
        "grants": [],
    }


def _validated_endpoint(value: str, allow_insecure_loopback: bool) -> str:
    base = value.strip().rstrip("/")
    parsed = urlsplit(base)
    if parsed.scheme == "https" and parsed.hostname and not parsed.username and not parsed.password:
        return base
    if (
        allow_insecure_loopback
        and parsed.scheme == "http"
        and parsed.hostname in {"127.0.0.1", "localhost"}
        and not parsed.username
        and not parsed.password
    ):
        return base
    raise PublishError("platform_endpoint_insecure")


def _valid_token(value: object) -> bool:
    return (
        type(value) is str
        and 32 <= len(value) <= 256
        and all(character.isascii() and (character.isalnum() or character in "-._~") for character in value)
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Submit one validated .ptcgai release.")
    parser.add_argument("--endpoint", required=True)
    parser.add_argument("--strategy-id", required=True)
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--allow-insecure-loopback", action="store_true")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    token = os.environ.get("PTCGDAP_PLATFORM_WRITE_TOKEN", "")
    try:
        report = publish(
            endpoint=args.endpoint,
            strategy_id=args.strategy_id,
            package_path=args.package,
            token=token,
            allow_insecure_loopback=args.allow_insecure_loopback,
        )
    except PublishError as error:
        raise SystemExit(f"release submission failed: {error}") from None
    raw = canonical_json_v1_bytes(report)
    if args.report is not None:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_bytes(raw)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
