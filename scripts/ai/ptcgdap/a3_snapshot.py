from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
from typing import Any, Mapping

from .cabt_tree_hash import jcs_canonical_json_bytes
from .source_lock import load_json_strict


class A3SnapshotError(RuntimeError):
    pass


def _hash(value: Any) -> str:
    return hashlib.sha256(jcs_canonical_json_bytes(value)).hexdigest().upper()


class A3SnapshotCanonicalizer:
    """Capability-tagged parity snapshot without hidden-value publication."""

    def __init__(self, profile: Mapping[str, Any]) -> None:
        if (
            type(profile) is not dict
            or profile.get("document_type") != "ptcgdap_a3_snapshot_profile_v2"
            or profile.get("schema_version") != 2
            or type(profile.get("public_fields")) is not list
            or type(profile.get("trusted_diagnostic_fields")) is not list
        ):
            raise A3SnapshotError("parity_snapshot_profile_invalid")
        self._profile = copy.deepcopy(profile)
        self._public = tuple(profile["public_fields"])
        self._diagnostic = tuple(profile["trusted_diagnostic_fields"])
        if (
            any(type(item) is not str or not item for item in self._public + self._diagnostic)
            or len(set(self._public)) != len(self._public)
            or len(set(self._diagnostic)) != len(self._diagnostic)
            or set(self._public) & set(self._diagnostic)
        ):
            raise A3SnapshotError("parity_snapshot_profile_invalid")

    @classmethod
    def load_default(cls, repository_root: str | Path) -> "A3SnapshotCanonicalizer":
        root = Path(repository_root).resolve()
        return cls(load_json_strict(root / "contracts/ptcgdap/a3_snapshot_profile_v2.json"))

    def canonicalize(
        self,
        public_snapshot: Mapping[str, Any],
        *,
        trusted_diagnostic_snapshot: Mapping[str, Any] | None = None,
        unavailable_diagnostics: tuple[str, ...] = (),
    ) -> dict[str, Any]:
        if type(public_snapshot) is not dict:
            raise A3SnapshotError("parity_public_snapshot_invalid")
        diagnostic = {} if trusted_diagnostic_snapshot is None else trusted_diagnostic_snapshot
        if type(diagnostic) is not dict:
            raise A3SnapshotError("parity_diagnostic_snapshot_invalid")
        if set(public_snapshot) - set(self._public):
            raise A3SnapshotError("parity_public_snapshot_unknown_field")
        if set(diagnostic) - set(self._diagnostic):
            raise A3SnapshotError("parity_diagnostic_snapshot_unknown_field")
        if set(unavailable_diagnostics) - set(self._diagnostic):
            raise A3SnapshotError("parity_snapshot_capability_invalid")
        overlap = set(diagnostic) & set(unavailable_diagnostics)
        if overlap:
            raise A3SnapshotError("parity_snapshot_capability_conflict")

        fields: dict[str, Any] = {}
        for field in self._public:
            presence = "missing" if field not in public_snapshot else (
                "null" if public_snapshot[field] is None else "value"
            )
            item = {"classification": "comparable", "presence": presence}
            if presence != "missing":
                item["value"] = copy.deepcopy(public_snapshot[field])
            fields[field] = item
        diagnostics: dict[str, Any] = {}
        for field in self._diagnostic:
            if field in unavailable_diagnostics or field not in diagnostic:
                diagnostics[field] = {"classification": "unavailable", "presence": "missing"}
                continue
            presence = "null" if diagnostic[field] is None else "value"
            diagnostics[field] = {
                "classification": "diagnostic-only",
                "presence": presence,
                "private_value_sha256": _hash(diagnostic[field]),
            }
        result = {
            "document_type": "ptcgdap_a3_canonical_snapshot_v2",
            "schema_version": 2,
            "fields": fields,
            "diagnostics": diagnostics,
        }
        # Canonicalization is also the JSON-safety and safe-integer gate.
        try:
            result["canonical_sha256"] = _hash(result)
        except (TypeError, ValueError, UnicodeError) as error:
            raise A3SnapshotError("parity_snapshot_not_canonicalizable") from error
        return result

    @staticmethod
    def public_evidence(snapshot: Mapping[str, Any]) -> dict[str, Any]:
        if type(snapshot) is not dict or snapshot.get("document_type") != "ptcgdap_a3_canonical_snapshot_v2":
            raise A3SnapshotError("parity_snapshot_invalid")
        value = copy.deepcopy(snapshot)
        # Diagnostic entries contain only hashes/capabilities by construction.
        rendered = json.dumps(value, ensure_ascii=False)
        if "private_value" in rendered and "private_value_sha256" not in rendered:
            raise A3SnapshotError("parity_snapshot_private_value_leak")
        return value


__all__ = ["A3SnapshotCanonicalizer", "A3SnapshotError"]
