from __future__ import annotations

import hashlib
from dataclasses import dataclass, replace
from typing import Any, Callable, Mapping, Sequence

from .a3_differential import (
    Checkpoint,
    EngineAdapter,
    LockstepDifferentialDriver,
)
from .a3_entity_relation import SemanticEntityRelation
from .a3_operation_contract import comparable_operation_projection
from .cabt_tree_hash import jcs_canonical_json_bytes


class A3LiveOperationWitnessError(RuntimeError):
    pass


REQUIRED_OPERATION_FAMILIES = (
    "exact_search",
    "exact_quantity",
    "sequential_source_target",
    "ability_activation",
    "attack",
    "damage_allocation",
    "retreat_switch",
    "evolution",
    "special_condition_attack",
)


def _hash(value: Any) -> str:
    return hashlib.sha256(jcs_canonical_json_bytes(value)).hexdigest().upper()


@dataclass(frozen=True, slots=True)
class LiveDecision:
    checkpoint: Checkpoint
    indexes: tuple[int, ...]
    accepted: bool
    prefix_sha256: str


def collect_live_decisions(
    adapter: EngineAdapter,
    start_spec: Mapping[str, Any],
    *,
    chooser: Callable[[Checkpoint], list[int]],
    max_checkpoints: int,
) -> tuple[LiveDecision, ...]:
    if max_checkpoints <= 0:
        raise A3LiveOperationWitnessError("a3_live_witness_limit_invalid")
    checkpoint = adapter.start(start_spec)
    decisions: list[LiveDecision] = []
    prefix: list[dict[str, Any]] = []
    for _ in range(max_checkpoints):
        if checkpoint.kind != "SELECTION":
            break
        indexes = chooser(checkpoint)
        try:
            transition = adapter.commit(checkpoint.window_handle or "", indexes)
        except Exception as error:
            raise A3LiveOperationWitnessError(
                "a3_live_witness_commit_failed"
            ) from error
        accepted = transition.get("accepted") is True
        prefix_sha256 = _hash(prefix)
        decisions.append(LiveDecision(
            checkpoint=checkpoint,
            indexes=tuple(indexes),
            accepted=accepted,
            prefix_sha256=prefix_sha256,
        ))
        prefix.append({
            "raw_observation_sha256": checkpoint.raw_observation_hash,
            "indexes": list(indexes),
            "accepted": accepted,
        })
        checkpoint = adapter.next_checkpoint()
    return tuple(decisions)


def aligned_window_witness(
    family: str,
    private_decision: LiveDecision,
    official_decision: LiveDecision,
    *,
    relation: SemanticEntityRelation,
    row_ordinal: int = 0,
    seat_alignment: str = "exact",
) -> dict[str, Any]:
    if (
        family not in REQUIRED_OPERATION_FAMILIES
        or row_ordinal < 0
        or not private_decision.accepted
        or not official_decision.accepted
        or private_decision.indexes != official_decision.indexes
        or seat_alignment not in ("exact", "mirrored")
    ):
        raise A3LiveOperationWitnessError("a3_live_witness_acceptance_invalid")
    left = private_decision.checkpoint
    right = official_decision.checkpoint
    if seat_alignment == "exact" and left.acting_seat != right.acting_seat:
        raise A3LiveOperationWitnessError("a3_live_witness_acting_seat_mismatch")
    if seat_alignment == "mirrored":
        if left.acting_seat not in (0, 1) or right.acting_seat != 1 - left.acting_seat:
            raise A3LiveOperationWitnessError("a3_live_witness_acting_seat_mismatch")
        comparable_right = replace(right, acting_seat=left.acting_seat)
    else:
        comparable_right = right
    driver = LockstepDifferentialDriver(
        None, None, entity_relation=relation,  # adapters are not used for an observed pair
    )
    driver.comparison_surface = "current_window_operation"
    try:
        driver.compare_current_operation(
            left, comparable_right, phase=f"{family}:{row_ordinal}"
        )
    except RuntimeError as error:
        # One malformed or unmappable candidate pair is not authority to abort
        # a bounded search for another complete live window.  Preserve the
        # fail-closed classification and let the owning scenario retry.
        raise A3LiveOperationWitnessError(
            "a3_live_witness_current_window_entity_invalid"
        ) from error
    if driver.first_divergence is not None:
        raise A3LiveOperationWitnessError(
            f"a3_live_witness_{driver.first_divergence.classification}"
        )
    private_semantic = relation.semantic_tree(
        "left", comparable_operation_projection(left)
    )
    official_semantic = relation.semantic_tree(
        "right", comparable_operation_projection(comparable_right)
    )
    if private_semantic != official_semantic:
        raise A3LiveOperationWitnessError("a3_live_witness_semantic_mismatch")
    select = private_semantic["select_header"]
    options = private_semantic["ordered_semantic_options"]
    return {
        "row_ordinal": row_ordinal,
        "status": "input-index-aligned",
        "acting_seat_alignment": seat_alignment,
        "private_acting_seat": left.acting_seat,
        "official_acting_seat": right.acting_seat,
        "select_header": select,
        "ordered_option_type_raw": [option["type"] for option in options],
        "ordered_semantic_options_sha256": _hash(options),
        "operation_input_sha256": _hash(private_semantic),
        "selected_indexes": list(private_decision.indexes),
        "private_engine_accepted": True,
        "official_engine_accepted": True,
        "private_raw_observation_sha256": left.raw_observation_hash,
        "official_raw_observation_sha256": right.raw_observation_hash,
        "private_legal_prefix_sha256": private_decision.prefix_sha256,
        "official_legal_prefix_sha256": official_decision.prefix_sha256,
        "raw_frames_retained_separately": True,
        "raw_frame_equality_claimed": False,
        "post_state_claimed": False,
    }


def aligned_sequence_witness(
    family: str,
    pairs: Sequence[tuple[LiveDecision, LiveDecision]],
    *,
    relation_factory: Callable[[], SemanticEntityRelation],
    source_locked_operation_sha256: str,
    seat_alignment: str = "exact",
) -> dict[str, Any]:
    if (
        family not in REQUIRED_OPERATION_FAMILIES
        or not pairs
        or type(source_locked_operation_sha256) is not str
        or len(source_locked_operation_sha256) != 64
    ):
        raise A3LiveOperationWitnessError("a3_live_witness_sequence_invalid")
    rows: list[dict[str, Any]] = []
    for ordinal, (private, official) in enumerate(pairs):
        try:
            rows.append(aligned_window_witness(
                family, private, official,
                relation=relation_factory(), row_ordinal=ordinal,
                seat_alignment=seat_alignment,
            ))
        except A3LiveOperationWitnessError as error:
            raise A3LiveOperationWitnessError(f"{error}:row={ordinal}") from error
    return {
        "family": family,
        "status": "input-index-aligned",
        "source_locked_operation_sha256": source_locked_operation_sha256,
        "window_count": len(rows),
        "rows": rows,
        "sequence_sha256": _hash(rows),
        "all_current_window_indexes_accepted": True,
        "reobserve_between_windows": len(rows) > 1,
        "post_state_claimed": False,
    }


def build_public_live_operation_ledger(
    *,
    scope_sha256: str,
    private_correspondence_sha256: str,
    families: Sequence[Mapping[str, Any]],
    source_identities: Mapping[str, str],
) -> dict[str, Any]:
    if (
        type(scope_sha256) is not str or len(scope_sha256) != 64
        or type(private_correspondence_sha256) is not str
        or len(private_correspondence_sha256) != 64
        or not source_identities
        or any(type(value) is not str or len(value) != 64 for value in source_identities.values())
    ):
        raise A3LiveOperationWitnessError("a3_live_witness_ledger_identity_invalid")
    copied = [dict(value) for value in families]
    ids = [value.get("family") for value in copied]
    if tuple(sorted(ids)) != tuple(sorted(REQUIRED_OPERATION_FAMILIES)):
        raise A3LiveOperationWitnessError("a3_live_witness_family_coverage_incomplete")
    for value in copied:
        rows = value.get("rows")
        if (
            value.get("status") != "input-index-aligned"
            or value.get("all_current_window_indexes_accepted") is not True
            or value.get("post_state_claimed") is not False
            or type(rows) is not list or not rows
            or any(
                type(row) is not dict
                or row.get("status") != "input-index-aligned"
                or row.get("private_engine_accepted") is not True
                or row.get("official_engine_accepted") is not True
                or row.get("post_state_claimed") is not False
                for row in rows
            )
        ):
            raise A3LiveOperationWitnessError("a3_live_witness_family_invalid")
    ledger = {
        "document_type": "ptcgdap_corresponding_card_whole_battle_input_index_ledger_v1",
        "schema_version": 1,
        "scope_sha256": scope_sha256,
        "private_correspondence_sha256": private_correspondence_sha256,
        "claim_scope": "corresponding_card_whole_battle_input_index_contract",
        "identity_equality_required": False,
        "official_deck_identity_required": False,
        "required_operation_families": list(REQUIRED_OPERATION_FAMILIES),
        "families": sorted(copied, key=lambda value: value["family"]),
        "source_identities": dict(sorted(source_identities.items())),
        "qualification_status": "passed",
        "maximum_claim": "corresponding_card_whole_battle_input_index_contract",
        "private_source_locator_persisted": False,
        "official_numeric_mapping_embedded": False,
        "bootstrap_prefix_comparison": "not_claimed",
        "post_state_comparison": "not_claimed",
        "logs_comparison": "not_claimed",
        "next_checkpoint_comparison": "not_claimed",
        "damage_ko_random_terminal_comparison": "not_claimed",
        "non_claims": [
            "official_card_id_domain_equality",
            "official_deck_identity_equality",
            "raw_callback_byte_equality",
            "post_state_or_full_rule_a3",
            "all_card_pool_engine_parity",
            "official_certification_or_endorsement",
        ],
    }
    ledger["evidence_sha256"] = _hash(ledger)
    return ledger


__all__ = [
    "A3LiveOperationWitnessError", "LiveDecision",
    "REQUIRED_OPERATION_FAMILIES", "aligned_sequence_witness",
    "aligned_window_witness", "build_public_live_operation_ledger",
    "collect_live_decisions",
]
