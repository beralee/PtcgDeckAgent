from __future__ import annotations

import copy
import hashlib
from typing import Any, Callable, Mapping, Sequence

from scripts.ai.ptcgdap.a3_differential import Checkpoint, EngineAdapter, _hash
from scripts.ai.ptcgdap.cabt_tree_hash import jcs_canonical_json_bytes


class A3SelfReplayError(RuntimeError):
    pass


def _sha256(value: Any) -> str:
    return hashlib.sha256(jcs_canonical_json_bytes(value)).hexdigest().upper()


def _checkpoint_value(checkpoint: Checkpoint) -> dict[str, Any]:
    return {
        "source_lane": checkpoint.source_lane,
        "kind": checkpoint.kind,
        "transition_ordinal": checkpoint.transition_ordinal,
        "callback_ordinal": checkpoint.callback_ordinal,
        "acting_seat": checkpoint.acting_seat,
        # Never place an opaque Search token (or its value-dependent hash) in
        # the replay receipt. Checkpoint.parse already verified this parity hash.
        "raw_actor_observation_published": False,
        "raw_observation_hash": checkpoint.raw_observation_hash,
        # Window handles are engine-private replay bindings.  Their exact value
        # must be stable within one adapter's self-rerun, but is never published.
        "window_handle_sha256": (
            None if checkpoint.window_handle is None else _hash(checkpoint.window_handle)
        ),
        "window_generation": checkpoint.window_generation,
        "select": copy.deepcopy(checkpoint.select),
        "ordered_options": [copy.deepcopy(value) for value in checkpoint.ordered_options],
        "option_fingerprints": list(checkpoint.option_fingerprints),
        "incremental_logs": [copy.deepcopy(value) for value in checkpoint.incremental_logs],
        "public_snapshot": copy.deepcopy(checkpoint.public_snapshot),
        "random_event_cursor": checkpoint.random_event_cursor,
        "diagnostic_capability_mask": list(checkpoint.diagnostic_capability_mask),
    }


def _validate_indexes(checkpoint: Checkpoint, indexes: list[int]) -> None:
    select = checkpoint.select
    if (
        checkpoint.kind != "SELECTION"
        or type(indexes) is not list
        or any(type(index) is not int for index in indexes)
        or len(indexes) != len(set(indexes))
        or any(index < 0 or index >= len(checkpoint.ordered_options) for index in indexes)
        or type(select) is not dict
        or type(select.get("minCount")) is not int
        or type(select.get("maxCount")) is not int
        or not select["minCount"] <= len(indexes) <= select["maxCount"]
    ):
        raise A3SelfReplayError("a3_self_replay_selection_invalid")


def _run_once(
    factory: Callable[[], EngineAdapter],
    match_spec: Mapping[str, Any],
    selections: Sequence[Sequence[int]],
    max_transitions: int,
) -> dict[str, Any]:
    adapter = factory()
    trace: list[dict[str, Any]] = []
    selection_ordinal = 0
    try:
        checkpoint = adapter.start(copy.deepcopy(match_spec))
        trace.append({"checkpoint": _checkpoint_value(checkpoint)})
        while checkpoint.kind != "TERMINAL":
            if checkpoint.kind != "SELECTION":
                raise A3SelfReplayError("a3_self_replay_lifecycle_unsupported")
            if selection_ordinal >= len(selections) or selection_ordinal >= max_transitions:
                raise A3SelfReplayError("a3_self_replay_action_script_incomplete")
            indexes = list(selections[selection_ordinal])
            _validate_indexes(checkpoint, indexes)
            witness = adapter.commit(checkpoint.window_handle or "", indexes)
            trace[-1]["selection_indexes"] = indexes
            trace[-1]["transition_witness"] = copy.deepcopy(dict(witness))
            selection_ordinal += 1
            checkpoint = adapter.next_checkpoint()
            trace.append({"checkpoint": _checkpoint_value(checkpoint)})
        if selection_ordinal != len(selections):
            raise A3SelfReplayError("a3_self_replay_action_script_excess")
        terminal = adapter.terminal_result()
        run = {
            "adapter_id": adapter.adapter_id,
            "executed_selection_count": selection_ordinal,
            "trace": trace,
            "terminal_result": copy.deepcopy(terminal),
        }
        run["run_sha256"] = _sha256(run)
        return run
    finally:
        adapter.dispose()


class EngineSelfReplayOwner:
    @classmethod
    def evaluate(
        cls,
        factory: Callable[[], EngineAdapter],
        match_spec: Mapping[str, Any],
        selections: Sequence[Sequence[int]],
        *,
        scope_sha256: str,
        max_transitions: int = 100_000,
    ) -> dict[str, Any]:
        if (
            type(scope_sha256) is not str
            or len(scope_sha256) != 64
            or any(character not in "0123456789ABCDEF" for character in scope_sha256)
            or type(max_transitions) is not int
            or max_transitions < 1
        ):
            raise A3SelfReplayError("a3_self_replay_configuration_invalid")
        # Intentionally serial: two fresh runtime instances must never overlap
        # and accidentally share native process/global engine state.
        first = _run_once(factory, match_spec, selections, max_transitions)
        second = _run_once(factory, match_spec, selections, max_transitions)
        deterministic = (
            first["adapter_id"] == second["adapter_id"]
            and first["run_sha256"] == second["run_sha256"]
        )
        receipt: dict[str, Any] = {
            "document_type": "ptcgdap_a3_engine_self_replay_receipt_v1",
            "schema_version": 1,
            "scope_sha256": scope_sha256,
            "adapter_id": first["adapter_id"],
            "action_script_sha256": _sha256([list(indexes) for indexes in selections]),
            "match_spec_sha256": _sha256(dict(match_spec)),
            "first_run_sha256": first["run_sha256"],
            "second_run_sha256": second["run_sha256"],
            "executed_selection_count": first["executed_selection_count"],
            "deterministic": deterministic,
            "status": "aligned" if deterministic else "self_replay_mismatch",
            "private_trace_published": False,
            "a3_promoted": False,
            "promotion_authority": "qualification_owner_only",
        }
        receipt["receipt_sha256"] = _sha256(receipt)
        return receipt


__all__ = ["A3SelfReplayError", "EngineSelfReplayOwner"]
