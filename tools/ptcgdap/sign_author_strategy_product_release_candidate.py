from __future__ import annotations

import argparse
import json
from pathlib import Path, PurePosixPath
import sys
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.ptcgdap.build_author_strategy_release_candidate import (
    build_product_candidate_payloads,
)
from tools.ptcgdap.build_author_strategy_release_contract import (
    PRODUCT_RELEASE_KEY_ID,
)
from tools.ptcgdap.sign_author_strategy_release_package import sign_release_package


def _materialize_product_payloads(source: Path, payloads: dict[str, bytes]) -> None:
    seen_casefold: set[str] = set()
    for relative, value in payloads.items():
        if type(relative) is not str or type(value) is not bytes:
            raise ValueError("unsafe product payload path or value")
        posix = PurePosixPath(relative)
        folded = relative.casefold()
        if (
            not relative
            or "\\" in relative
            or "\0" in relative
            or posix.is_absolute()
            or "." in posix.parts
            or ".." in posix.parts
            or any(":" in part for part in posix.parts)
            or posix.as_posix() != relative
            or folded in seen_casefold
        ):
            raise ValueError("unsafe product payload path or value")
        seen_casefold.add(folded)
        path = source.joinpath(*posix.parts)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(value)


def sign_product_release_candidate(
    *,
    project_root: Path,
    private_key_path: Path,
    output: Path,
    receipt_path: Path,
) -> dict[str, object]:
    """Sign the fixed built-in candidate without persisting an unsigned source."""

    payloads = build_product_candidate_payloads()
    with tempfile.TemporaryDirectory(prefix="ptcgdap-product-release-source-") as temp:
        source = Path(temp) / "source"
        source.mkdir()
        _materialize_product_payloads(source, payloads)
        return sign_release_package(
            project_root=project_root,
            source=source,
            output=output,
            private_key_path=private_key_path,
            key_id=PRODUCT_RELEASE_KEY_ID,
            receipt_path=receipt_path,
        )


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Product-sign the fixed PtcgDAP built-in strategy candidate with "
            "the repository's approved key id and an external private key."
        )
    )
    parser.add_argument("--private-key", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--receipt", type=Path, required=True)
    args = parser.parse_args()
    try:
        receipt = sign_product_release_candidate(
            project_root=ROOT,
            private_key_path=args.private_key,
            output=args.output,
            receipt_path=args.receipt,
        )
    except (OSError, ValueError, KeyError, zipfile.BadZipFile, json.JSONDecodeError) as error:
        raise SystemExit(f"product release signing refused: {error}") from None
    print(f"package_id={receipt['package_id']}")
    print(f"package_version={receipt['package_version']}")
    print(f"signature_key_id={receipt['signature_key_id']}")
    print(f"archive_bytes={receipt['archive_bytes']}")
    print(f"archive_sha256={receipt['archive_sha256']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
