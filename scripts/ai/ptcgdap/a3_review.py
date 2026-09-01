from __future__ import annotations

import hashlib
from typing import Any, Mapping, Sequence

from .cabt_tree_hash import jcs_canonical_json_bytes


REQUIRED_REVIEW_KINDS = frozenset(
    {"ptcg_rules", "differential_architecture", "privacy_projection"}
)


class A3ReviewError(RuntimeError):
    pass


def _hash(value: Any) -> str:
    return hashlib.sha256(jcs_canonical_json_bytes(value)).hexdigest().upper()


def _valid_hash(value: Any) -> bool:
    return (
        type(value) is str and len(value) == 64
        and all(character in "0123456789ABCDEF" for character in value)
    )


def self_hash_valid(value: Any, field: str) -> bool:
    if type(value) is not dict or not _valid_hash(value.get(field)):
        return False
    projected = dict(value)
    expected = projected.pop(field)
    return expected == _hash(projected)


def valid_independent_review(value: Any, scope_hash: str) -> bool:
    return (
        type(value) is dict
        and value.get("document_type") == "ptcgdap_a3_independent_review_v2"
        and value.get("scope_sha256") == scope_hash
        and value.get("review_kind") in REQUIRED_REVIEW_KINDS
        and _valid_hash(value.get("reviewer_identity_sha256"))
        and value.get("independent_from_implementation") is True
        and value.get("decision") == "approved"
        and value.get("blocking_finding_count") == 0
        and type(value.get("reviewed_artifact_sha256s")) is list
        and bool(value["reviewed_artifact_sha256s"])
        and all(_valid_hash(item) for item in value["reviewed_artifact_sha256s"])
        and self_hash_valid(value, "review_sha256")
    )


def valid_rollback_receipt(value: Any, scope_hash: str) -> bool:
    return (
        type(value) is dict
        and value.get("document_type") == "ptcgdap_a3_rollback_drill_v2"
        and value.get("current_scope_sha256") == scope_hash
        and _valid_hash(value.get("previous_promoted_scope_sha256"))
        and value.get("status") == "passed"
        and value.get("negative_evidence_retained") is True
        and value.get("new_scope_not_deleted") is True
        and self_hash_valid(value, "drill_sha256")
    )


def build_review_qualification(
    scope: Mapping[str, Any],
    *,
    reviews: Sequence[Mapping[str, Any]] = (),
    rollback_receipt: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    scope_hash = scope.get("scope_sha256")
    if not _valid_hash(scope_hash):
        raise A3ReviewError("a3_review_scope_invalid")
    invalid_reviews = [review for review in reviews if not valid_independent_review(review, scope_hash)]
    if invalid_reviews:
        raise A3ReviewError("a3_independent_review_invalid")
    by_kind: dict[str, Mapping[str, Any]] = {}
    for review in reviews:
        kind = review["review_kind"]
        if kind in by_kind:
            raise A3ReviewError("a3_independent_review_duplicate")
        by_kind[kind] = review
    reviewer_ids = [review["reviewer_identity_sha256"] for review in reviews]
    independent = (
        set(by_kind) == REQUIRED_REVIEW_KINDS
        and len(reviewer_ids) == len(set(reviewer_ids)) == len(REQUIRED_REVIEW_KINDS)
    )
    rollback_passed = (
        rollback_receipt is not None
        and valid_rollback_receipt(rollback_receipt, scope_hash)
    )
    value = {
        "document_type": "ptcgdap_a3_review_qualification_v2",
        "schema_version": 2,
        "scope_sha256": scope_hash,
        "reviews": [dict(by_kind[kind]) for kind in sorted(by_kind)],
        "ptcg_rules_review": "approved" if "ptcg_rules" in by_kind else "missing",
        "differential_architecture_review": (
            "approved" if "differential_architecture" in by_kind else "missing"
        ),
        "privacy_projection_review": (
            "approved" if "privacy_projection" in by_kind else "missing"
        ),
        "distinct_reviewer_count": len(set(reviewer_ids)),
        "independent_review_set_complete": independent,
        "rollback_receipt": None if rollback_receipt is None else dict(rollback_receipt),
        "rollback_drill": "passed" if rollback_passed else "missing",
        "authority": "review_qualification_owner",
        "maximum_claim": "review_gates_passed" if independent and rollback_passed else "review_gap_inventory",
    }
    value["receipt_sha256"] = _hash(value)
    return value


__all__ = [
    "A3ReviewError", "REQUIRED_REVIEW_KINDS", "build_review_qualification",
    "self_hash_valid", "valid_independent_review", "valid_rollback_receipt",
]
