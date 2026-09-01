from __future__ import annotations

import hashlib
import unittest

from scripts.ai.ptcgdap.a3_review import A3ReviewError, build_review_qualification
from scripts.ai.ptcgdap.cabt_tree_hash import jcs_canonical_json_bytes


def seal(value: dict, field: str) -> dict:
    result = dict(value)
    result[field] = hashlib.sha256(jcs_canonical_json_bytes(value)).hexdigest().upper()
    return result


class A3ReviewTests(unittest.TestCase):
    def test_empty_review_set_is_a_blocked_gap_inventory(self) -> None:
        report = build_review_qualification({"scope_sha256": "A" * 64})
        self.assertFalse(report["independent_review_set_complete"])
        self.assertEqual(report["rollback_drill"], "missing")

    def test_same_reviewer_cannot_approve_all_independent_domains(self) -> None:
        reviews = []
        for kind in ("ptcg_rules", "differential_architecture", "privacy_projection"):
            reviews.append(seal({
                "document_type": "ptcgdap_a3_independent_review_v2",
                "scope_sha256": "A" * 64,
                "review_kind": kind,
                "reviewer_identity_sha256": "B" * 64,
                "independent_from_implementation": True,
                "decision": "approved",
                "blocking_finding_count": 0,
                "reviewed_artifact_sha256s": ["C" * 64],
            }, "review_sha256"))
        report = build_review_qualification({"scope_sha256": "A" * 64}, reviews=reviews)
        self.assertFalse(report["independent_review_set_complete"])

    def test_unsealed_review_fails_closed(self) -> None:
        with self.assertRaisesRegex(A3ReviewError, "a3_independent_review_invalid"):
            build_review_qualification(
                {"scope_sha256": "A" * 64},
                reviews=[{"review_kind": "ptcg_rules"}],
            )


if __name__ == "__main__":
    unittest.main()
