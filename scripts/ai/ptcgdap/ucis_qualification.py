"""Check whether a historical UCIS receipt applies to current inputs."""
from __future__ import annotations

import hashlib
from typing import Any, Mapping

from .source_lock import canonical_json_v1_bytes


def audit_qualification_inputs(
    receipt: Mapping[str, Any],
    source_identities: Mapping[str, str],
    contract_identities: Mapping[str, str],
) -> dict[str, Any]:
    payload = dict(receipt)
    evidence_hash = payload.pop("evidence_sha256", None)
    if evidence_hash != hashlib.sha256(canonical_json_v1_bytes(payload)).hexdigest().upper():
        raise ValueError("ucis_qualification_evidence_hash_invalid")
    changed: list[str] = []
    unverified: list[str] = []
    for group, current in (("source_identities", source_identities), ("contract_identities", contract_identities)):
        recorded = payload.get(group)
        if not isinstance(recorded, Mapping) or not recorded:
            raise ValueError("ucis_qualification_identities_invalid")
        for key, expected in recorded.items():
            identity = f"{group}.{key}"
            if key not in current:
                unverified.append(identity)
            elif current[key] != expected:
                changed.append(identity)
    applicable = not changed and not unverified and payload.get("qualification_status") == "passed"
    return {
        "status": "applicable" if applicable else "requires_requalification",
        "current_inputs_qualified": applicable,
        "changed_identities": sorted(changed),
        "unverified_identities": sorted(unverified),
        "historical_evidence_sha256": evidence_hash,
    }
