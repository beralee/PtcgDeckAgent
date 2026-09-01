from __future__ import annotations

import hashlib
from typing import Any, Mapping

from .a3_entity_relation import SemanticEntityRelation
from .a3_official_deck_compatibility import register_private_semantic_bridge
from .cabt_tree_hash import jcs_canonical_json_bytes


class A3OperationQualificationError(RuntimeError):
    pass


NATIVE_OPTION_TYPES = tuple(range(17))


def _hash(value: Any) -> str:
    return hashlib.sha256(jcs_canonical_json_bytes(value)).hexdigest().upper()


def build_operation_qualification(
    scope: Mapping[str, Any],
    private_correspondence: Mapping[str, Any],
    *,
    static_projection_suite_passed: bool,
    privacy_suite_passed: bool,
    live_setup_input_index_witness_passed: bool,
    source_identities: Mapping[str, str],
) -> dict[str, Any]:
    scope_hash = scope.get("scope_sha256")
    if type(scope_hash) is not str or len(scope_hash) != 64:
        raise A3OperationQualificationError("a3_operation_scope_invalid")
    relation = SemanticEntityRelation()
    try:
        loaded = register_private_semantic_bridge(relation, private_correspondence)
    except RuntimeError as error:
        raise A3OperationQualificationError(
            "a3_operation_correspondence_invalid"
        ) from error
    cards: dict[str, tuple[str, int]] = {}
    attacks: set[tuple[str, int]] = set()
    for deck in private_correspondence.get("decks", []):
        for entry in deck.get("entries", []):
            if type(entry) is not dict or entry.get("status") != "exact_corresponding_printing":
                continue
            semantic_id = entry.get("semantic_card_id")
            private_id = entry.get("private_card_uid")
            official_ids = entry.get("official_card_ids")
            if (
                type(semantic_id) is not str
                or type(private_id) is not str
                or type(official_ids) is not list
                or len(official_ids) != 1
            ):
                raise A3OperationQualificationError("a3_operation_correspondence_invalid")
            value = (private_id, official_ids[0])
            if semantic_id in cards and cards[semantic_id] != value:
                raise A3OperationQualificationError("a3_operation_correspondence_conflict")
            cards[semantic_id] = value
            private_attacks = entry.get("private_attack_ids")
            official_attacks = entry.get("official_attack_ids")
            if type(private_attacks) is not list or type(official_attacks) is not list:
                raise A3OperationQualificationError("a3_operation_correspondence_invalid")
            attacks.update(zip(private_attacks, official_attacks, strict=True))
    if loaded != len(cards) or loaded <= 0:
        raise A3OperationQualificationError("a3_operation_correspondence_incomplete")
    private_correspondence_sha256 = private_correspondence.get("evidence_sha256")
    if (
        type(private_correspondence_sha256) is not str
        or len(private_correspondence_sha256) != 64
    ):
        raise A3OperationQualificationError("a3_operation_correspondence_source_unsealed")
    required_sources = {
        "operation_contract", "differential_comparator", "godot_adapter",
        "godot_decision_owner",
        "official_adapter", "match_plan", "static_projection_test",
        "privacy_test", "live_test",
    }
    if set(source_identities) != required_sources or any(
        type(value) is not str or len(value) != 64
        for value in source_identities.values()
    ):
        raise A3OperationQualificationError("a3_operation_source_identity_invalid")
    passed = bool(
        static_projection_suite_passed
        and privacy_suite_passed
        and live_setup_input_index_witness_passed
    )
    receipt = {
        "document_type": "ptcgdap_a3_corresponding_card_operation_qualification_v1",
        "schema_version": 1,
        "scope_sha256": scope_hash,
        "claim_scope": "setup_active_corresponding_card_input_index_contract",
        "identity_equality_required": False,
        "official_deck_identity_required": False,
        "mapped_unique_private_card_count": len(cards),
        "mapped_unique_attack_identity_count": len(attacks),
        "private_correspondence_sha256": private_correspondence_sha256,
        "semantic_relation_sha256": relation.relation_hash,
        "synthetic_projection_type_coverage": list(NATIVE_OPTION_TYPES),
        "synthetic_projection_type_coverage_status": (
            "passed" if static_projection_suite_passed else "blocked"
        ),
        "live_operation_type_coverage": (
            [3] if live_setup_input_index_witness_passed else []
        ),
        "operation_input_projection_conformance": (
            "passed" if static_projection_suite_passed else "blocked"
        ),
        "privacy_negative_gate_status": (
            "passed" if privacy_suite_passed else "blocked"
        ),
        "current_window_index_acceptance_witness": (
            "passed_both_engines_setup_active_only"
            if live_setup_input_index_witness_passed else "blocked"
        ),
        "stable_public_transition_witness": "not_claimed",
        "bootstrap_prefix_comparison": "not_claimed",
        "post_transition_next_selection_comparison": "not_claimed",
        "live_private_oracle_witness_count": (
            1 if live_setup_input_index_witness_passed else 0
        ),
        "live_witness_operation": (
            "setup_active_corresponding_card_input_index_only"
            if live_setup_input_index_witness_passed else "not_witnessed"
        ),
        "all_sealed_card_and_attack_relations_bijective": True,
        "official_raw_callback_retained_separately": True,
        "godot_private_frame_retained_separately": True,
        "raw_callback_byte_equality_claimed": False,
        "operation_receipt_embeds_official_numeric_mapping": False,
        "legacy_public_contracts_may_contain_official_numeric_ids": True,
        "private_source_locator_persisted": False,
        "source_identities": dict(sorted(source_identities.items())),
        "qualification_status": "passed" if passed else "blocked",
        "maximum_claim": (
            "setup_active_corresponding_card_input_index_contract"
            if passed else "operation_qualification_gap_inventory"
        ),
        "non_claims": [
            "official_card_id_domain_equality",
            "official_deck_identity_equality",
            "raw_callback_byte_equality",
            "all_card_pool_engine_parity",
            "official_certification_or_endorsement",
            "five_deck_full_rule_outcome_a3",
            "all_17_option_types_live_engine_witnessed",
            "setup_bootstrap_prefix_parity",
            "post_transition_next_selection_parity",
            "stable_public_transition_parity",
        ],
    }
    receipt["evidence_sha256"] = _hash(receipt)
    return receipt


__all__ = [
    "A3OperationQualificationError", "NATIVE_OPTION_TYPES",
    "build_operation_qualification",
]
