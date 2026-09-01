from __future__ import annotations

import hashlib
from typing import Any, Mapping

from .cabt_tree_hash import jcs_canonical_json_bytes


class A3ExecutionReceiptError(RuntimeError):
    pass


def _hash(value: Any) -> str:
    return hashlib.sha256(jcs_canonical_json_bytes(value)).hexdigest().upper()


def _self_hash_valid(value: Any, field: str = "receipt_sha256") -> bool:
    if type(value) is not dict or type(value.get(field)) is not str:
        return False
    projected = dict(value)
    expected = projected.pop(field)
    return len(expected) == 64 and expected == _hash(projected)


def _deck(scope: Mapping[str, Any], deck_id: int) -> Mapping[str, Any]:
    candidates = [
        deck for deck in scope.get("decks", [])
        if type(deck) is dict and deck.get("deck_id") == deck_id
    ]
    if len(candidates) != 1:
        raise A3ExecutionReceiptError("a3_execution_deck_unknown")
    return candidates[0]


def _protocol_hash(scope: Mapping[str, Any], path: str) -> str:
    candidates = [
        item.get("sha256") for item in scope.get(
            "adapter_snapshot_comparator_action_protocol_files", []
        )
        if type(item) is dict and item.get("path") == path
    ]
    if len(candidates) != 1 or type(candidates[0]) is not str:
        raise A3ExecutionReceiptError("a3_execution_protocol_unlocked")
    return candidates[0]


def build_execution_receipt(
    scope: Mapping[str, Any],
    deck_pair: tuple[int, int],
    official_self_replay: Mapping[str, Any],
    godot_self_replay: Mapping[str, Any],
    differential_report: Mapping[str, Any],
    bounded_exploration: Mapping[str, Any],
) -> dict[str, Any]:
    scope_hash = scope.get("scope_sha256")
    if type(scope_hash) is not str or len(scope_hash) != 64 or len(deck_pair) != 2:
        raise A3ExecutionReceiptError("a3_execution_configuration_invalid")
    left_deck = _deck(scope, deck_pair[0])
    right_deck = _deck(scope, deck_pair[1])
    for receipt, adapter_prefix in (
        (official_self_replay, "official-"),
        (godot_self_replay, "godot-"),
    ):
        if (
            not _self_hash_valid(receipt)
            or receipt.get("scope_sha256") != scope_hash
            or receipt.get("status") != "aligned"
            or receipt.get("deterministic") is not True
            or not str(receipt.get("adapter_id", "")).startswith(adapter_prefix)
            or receipt.get("a3_promoted") is not False
        ):
            raise A3ExecutionReceiptError("a3_execution_self_replay_invalid")
    if (
        official_self_replay.get("action_script_sha256")
        != godot_self_replay.get("action_script_sha256")
        or official_self_replay.get("match_spec_sha256")
        != godot_self_replay.get("match_spec_sha256")
    ):
        raise A3ExecutionReceiptError("a3_execution_self_replay_input_mismatch")
    if (
        type(differential_report) is not dict
        or differential_report.get("document_type") != "ptcgdap_a3_differential_report_v2"
        or differential_report.get("scope_sha256") != scope_hash
        or differential_report.get("status") != "aligned"
        or differential_report.get("first_divergence") is not None
        or differential_report.get("a3_promoted") is not False
    ):
        raise A3ExecutionReceiptError("a3_execution_differential_invalid")
    if (
        type(bounded_exploration) is not dict
        or bounded_exploration.get("scope_sha256") != scope_hash
        or bounded_exploration.get("status") != "complete"
        or bounded_exploration.get("unexplained_difference_count") != 0
        or bounded_exploration.get("dirty_case_count") != 0
        or bounded_exploration.get("harness_error_count") != 0
    ):
        raise A3ExecutionReceiptError("a3_execution_exploration_invalid")
    provenance = scope.get("oracle_provenance", {})
    candidate = scope.get("godot_candidate", {})
    receipt = {
        "document_type": "ptcgdap_a3_execution_receipt_v2",
        "schema_version": 2,
        "scope_sha256": scope_hash,
        "configuration_id": f"{deck_pair[0]}->{deck_pair[1]}",
        "deck_pair": list(deck_pair),
        "left_ordered_deck_sha256": left_deck.get("ordered_private_deck_sha256"),
        "right_ordered_deck_sha256": right_deck.get("ordered_private_deck_sha256"),
        "official_engine_sha256": provenance.get("official_engine_sha256"),
        "godot_scope_content_sha256": candidate.get("dirty_scope_content_manifest_sha256"),
        "adapter_protocol_sha256": _protocol_hash(
            scope, "contracts/ptcgdap/a3_engine_adapter_v2.json"
        ),
        "status": "aligned",
        "left_self_rerun_sha256": official_self_replay["receipt_sha256"],
        "right_self_rerun_sha256": godot_self_replay["receipt_sha256"],
        "differential_report_sha256": _hash(differential_report),
        "bounded_exploration_sha256": _hash(bounded_exploration),
        "bounded_exploration_status": "complete",
        "public_projection_status": bounded_exploration.get(
            "public_projection_status", "reviewed"
        ),
        "private_evidence_status": bounded_exploration.get(
            "private_evidence_status", "isolated"
        ),
        "unexplained_difference_count": 0,
        "dirty_case_count": 0,
        "harness_error_count": 0,
        "random_capability": bounded_exploration.get("random_capability"),
        "a3_promoted": False,
        "promotion_authority": "qualification_owner_only",
    }
    receipt["receipt_sha256"] = _hash(receipt)
    return receipt


__all__ = ["A3ExecutionReceiptError", "build_execution_receipt"]
