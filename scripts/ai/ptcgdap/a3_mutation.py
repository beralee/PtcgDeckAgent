from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
from typing import Any, Mapping, Sequence

from .a3_differential import Checkpoint, _hash, compare_checkpoints, parity_observation_hash
from .a3_entity_relation import SemanticEntityRelation
from .cabt_tree_hash import jcs_canonical_json_bytes
from .source_lock import load_json_strict


class A3MutationError(RuntimeError):
    pass


def _checkpoint(base: Mapping[str, Any], *, right_domain: bool) -> dict[str, Any]:
    serial = 9001 if right_domain else int(base["serial"])
    options = [
        {"type": value, "index": index, "cardId": 646, "serial": serial}
        for index, value in enumerate(base["option_order"])
    ]
    select = {
        "type": int(base["select_type"]),
        "context": int(base["select_context"]),
        "minCount": 1,
        "maxCount": 1,
        "option": copy.deepcopy(options),
    }
    raw = {"select": copy.deepcopy(select)}
    return {
        "source_lane": "test_fixture",
        "kind": str(base["kind"]),
        "transition_ordinal": 0,
        "callback_ordinal": 0,
        "acting_seat": int(base["acting_seat"]),
        "raw_actor_observation": raw,
        "raw_observation_hash": parity_observation_hash(raw),
        "window_handle": "right-window" if right_domain else "left-window",
        "window_generation": 1,
        "select": select,
        "ordered_options": options,
        "option_fingerprints": [_hash(option) for option in options],
        "incremental_logs": copy.deepcopy(base["incremental_logs"]),
        "public_snapshot": {"damage": int(base["damage"]), "terminal": False},
        "random_event_cursor": int(base["random_event_cursor"]),
        "diagnostic_capability_mask": [],
    }


def _mutate(checkpoint: dict[str, Any], mutation: str) -> None:
    if mutation == "none":
        return
    if mutation == "option_reorder":
        checkpoint["ordered_options"].reverse()
        checkpoint["select"]["option"] = copy.deepcopy(checkpoint["ordered_options"])
    elif mutation == "damage":
        checkpoint["public_snapshot"]["damage"] = 10
    elif mutation == "log":
        checkpoint["incremental_logs"] = [{"type": 7}]
    elif mutation == "serial":
        checkpoint["ordered_options"][0]["serial"] = 9002
        checkpoint["select"]["option"] = copy.deepcopy(checkpoint["ordered_options"])
    elif mutation == "rng":
        checkpoint["random_event_cursor"] = 1
    elif mutation == "terminal":
        checkpoint.update({
            "kind": "TERMINAL", "acting_seat": None, "window_handle": None,
            "window_generation": None, "select": None, "ordered_options": [],
            "option_fingerprints": [], "raw_actor_observation": None,
            "raw_observation_hash": parity_observation_hash(None),
        })
        checkpoint["public_snapshot"]["terminal"] = True
    else:
        raise A3MutationError("a3_mutation_unknown")
    checkpoint["option_fingerprints"] = [
        _hash(option) for option in checkpoint["ordered_options"]
    ]


def _relation(vectors: Mapping[str, Any]) -> SemanticEntityRelation:
    relation = SemanticEntityRelation()
    relation.bind_deck_occurrence(
        official_card_id=646,
        deck_occurrence=0,
        left_serial=101,
        right_serial=9001,
        source_deck_hash="D" * 64,
    )
    return relation


def evaluate_python_vectors(vectors: Mapping[str, Any]) -> list[dict[str, Any]]:
    if (
        type(vectors) is not dict
        or vectors.get("document_type") != "ptcgdap_a3_comparator_conformance_v2"
        or type(vectors.get("base")) is not dict
        or type(vectors.get("cases")) is not list
    ):
        raise A3MutationError("a3_comparator_vectors_invalid")
    result: list[dict[str, Any]] = []
    for case in vectors["cases"]:
        if type(case) is not dict:
            raise A3MutationError("a3_comparator_vectors_invalid")
        left_value = _checkpoint(vectors["base"], right_domain=False)
        right_value = _checkpoint(vectors["base"], right_domain=True)
        _mutate(right_value, str(case.get("mutation", "")))
        divergence = compare_checkpoints(
            Checkpoint.parse(left_value), Checkpoint.parse(right_value),
            phase="before_action", relation=_relation(vectors),
        )
        item = {
            "case_id": case.get("case_id"),
            "classification": None if divergence is None else divergence.classification,
            "path": None if divergence is None else divergence.path,
        }
        if item["classification"] != case.get("classification") or item["path"] != case.get("path"):
            raise A3MutationError("a3_python_comparator_conformance_failed")
        result.append(item)
    return result


def build_mutation_receipt(
    scope: Mapping[str, Any],
    vectors_path: str | Path,
    godot_result: Mapping[str, Any],
) -> dict[str, Any]:
    vectors_file = Path(vectors_path)
    vectors = load_json_strict(vectors_file)
    python_results = evaluate_python_vectors(vectors)
    godot_results = godot_result.get("results") if type(godot_result) is dict else None
    expected_vector_sha = hashlib.sha256(vectors_file.read_bytes()).hexdigest().upper()
    consistent = (
        godot_result.get("accepted") is True
        and godot_result.get("vectors_raw_sha256") == expected_vector_sha
        and godot_results == python_results
    )
    captured = sorted(
        item["case_id"] for item in python_results if item["case_id"] != "equal"
    )
    receipt = {
        "document_type": "ptcgdap_a3_mutation_receipt_v2",
        "schema_version": 2,
        "scope_sha256": scope.get("scope_sha256"),
        "vectors_raw_sha256": expected_vector_sha,
        "captured": captured,
        "python_results": python_results,
        "godot_results": godot_results,
        "python_godot_comparator_consistent": consistent,
        "authority": "harness_qualification_only_not_engine_parity",
    }
    receipt["receipt_sha256"] = hashlib.sha256(
        jcs_canonical_json_bytes(receipt)
    ).hexdigest().upper()
    return receipt


__all__ = ["A3MutationError", "build_mutation_receipt", "evaluate_python_vectors"]
