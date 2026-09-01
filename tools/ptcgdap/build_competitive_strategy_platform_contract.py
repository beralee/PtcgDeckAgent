from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import (  # noqa: E402
    canonical_json_v1_bytes,
    load_json_strict,
)


CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"
BUNDLE_PATH = CONTRACT_ROOT / "competitive_strategy_platform_bundle.json"
BUNDLE_ID = "ptcgdap-competitive-strategy-platform-csp-wp0-v1"
PROFILE_ID = "competitive_strategy_platform_contract_v1"
ARTIFACTS = (
    ("schema", "competitive_strategy_platform.schema.json"),
    ("profile", "competitive_strategy_platform_profile.json"),
    ("threat_model", "competitive_strategy_platform_threat_model.json"),
    ("vectors", "competitive_strategy_platform_conformance_vectors.json"),
)


def canonical_sha256(value: Any) -> str:
    return hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper()


def expected_bundle() -> dict[str, Any]:
    entries: list[dict[str, str]] = []
    for artifact_id, filename in ARTIFACTS:
        path = CONTRACT_ROOT / filename
        value = load_json_strict(path)
        entries.append(
            {
                "artifact_id": artifact_id,
                "path": path.relative_to(ROOT).as_posix(),
                "canonical_sha256": canonical_sha256(value),
            }
        )
    return {
        "document_type": "competitive_strategy_platform_bundle_v1",
        "schema_version": 1,
        "bundle_id": BUNDLE_ID,
        "profile_id": PROFILE_ID,
        "digest_mode": "canonical_json_v1",
        "artifact_set_policy": "exact_ids_paths_hashes_no_duplicates",
        "artifacts": entries,
    }


def rendered_bundle() -> bytes:
    return (
        json.dumps(expected_bundle(), ensure_ascii=False, indent=2) + "\n"
    ).encode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build or verify the CSP-WP0 pinned contract bundle."
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Fail unless the checked-in bundle exactly matches its source artifacts.",
    )
    args = parser.parse_args()
    expected = rendered_bundle()
    if args.check:
        if not BUNDLE_PATH.is_file() or BUNDLE_PATH.read_bytes() != expected:
            raise SystemExit("competitive strategy platform bundle is stale")
    else:
        BUNDLE_PATH.write_bytes(expected)
    print(canonical_sha256(expected_bundle()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
