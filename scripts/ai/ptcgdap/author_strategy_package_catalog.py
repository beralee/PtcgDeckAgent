from __future__ import annotations

import copy
import hashlib
from typing import Any, Iterable, Mapping

from .author_strategy_package import AuthorStrategyPackageError, AuthorStrategyPackageLoader
from .author_strategy_release import AuthorStrategyReleaseGate


INSTALL_SOURCES = ("built_in", "user")


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class AuthorStrategyPackageCatalogOracle:
    """Pure Python oracle for AS-WP2 metadata catalog merge semantics."""

    def __init__(self) -> None:
        self._loader = AuthorStrategyPackageLoader()
        self._release_gate = AuthorStrategyReleaseGate()

    def build(self, candidates: Iterable[Mapping[str, Any]]) -> dict[str, Any]:
        normalized: list[dict[str, Any]] = []
        diagnostics: list[dict[str, str]] = []
        for ordinal, source in enumerate(candidates):
            install_source = source.get("install_source")
            archive_bytes = source.get("archive_bytes")
            if install_source not in INSTALL_SOURCES or type(archive_bytes) is not bytes:
                diagnostics.append(
                    {
                        "candidate_id": f"candidate-{ordinal:04d}",
                        "install_source": install_source if install_source in INSTALL_SOURCES else "invalid",
                        "error_code": "package_archive_invalid",
                    }
                )
                continue
            location_id = source.get("location_id")
            if type(location_id) is not str or not location_id:
                location_id = f"candidate-{ordinal:04d}"
            normalized.append(
                {
                    "candidate_id": f"candidate-{ordinal:04d}",
                    "install_source": install_source,
                    "location_id": location_id,
                    "archive_bytes": archive_bytes,
                    "archive_sha256": _sha(archive_bytes),
                }
            )
        normalized.sort(key=lambda item: (INSTALL_SOURCES.index(item["install_source"]), item["location_id"]))

        accepted: list[dict[str, Any]] = []
        for candidate in normalized:
            try:
                handle = self._loader.load_bytes(
                    candidate["archive_bytes"],
                    expected_archive_sha256=candidate["archive_sha256"],
                )
            except AuthorStrategyPackageError as error:
                diagnostics.append(
                    {
                        "candidate_id": candidate["candidate_id"],
                        "install_source": candidate["install_source"],
                        "error_code": error.code,
                    }
                )
                continue
            accepted.append({**candidate, "metadata": handle.to_dict()})

        groups: dict[tuple[str, str], list[dict[str, Any]]] = {}
        for candidate in accepted:
            metadata = candidate["metadata"]
            groups.setdefault((metadata["package_id"], metadata["package_version"]), []).append(candidate)

        records: list[dict[str, Any]] = []
        ready_records: list[dict[str, Any]] = []
        for identity in sorted(groups):
            group = groups[identity]
            hashes = {candidate["archive_sha256"] for candidate in group}
            if len(hashes) != 1:
                diagnostics.append(
                    {
                        "candidate_id": _sha((identity[0] + "\n" + identity[1]).encode("utf-8"))[:16],
                        "install_source": "conflict",
                        "error_code": "package_identity_conflict",
                    }
                )
                continue
            selected = group[0]
            metadata = copy.deepcopy(selected["metadata"])
            metadata["catalog_key"] = _sha(
                (metadata["package_id"] + "\n" + metadata["package_version"] + "\n" + metadata["archive_sha256"]).encode("utf-8")
            )
            metadata["install_source"] = selected["install_source"]
            metadata["install_sources"] = sorted(
                {candidate["install_source"] for candidate in group}, key=INSTALL_SOURCES.index
            )
            release = self._release_gate.evaluate_package(metadata)
            metadata["status"] = "release_approved" if release["accepted"] else "metadata_only"
            metadata["match_authority"] = False
            records.append(metadata)
            if release["accepted"]:
                ready_records.append(copy.deepcopy(metadata))

        diagnostics.sort(key=lambda item: (item["error_code"], item["install_source"], item["candidate_id"]))
        return {
            "schema_version": 1,
            "metadata_records": copy.deepcopy(records),
            "ready_records": copy.deepcopy(ready_records),
            "diagnostics": copy.deepcopy(diagnostics),
            "metadata_only": not ready_records,
            "match_authority": False,
        }


__all__ = ["AuthorStrategyPackageCatalogOracle", "INSTALL_SOURCES"]
