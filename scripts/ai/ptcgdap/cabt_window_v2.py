from __future__ import annotations

import copy
import hashlib
import hmac
from dataclasses import dataclass
from typing import Any, Callable, Mapping, Protocol

from .cabt_selection import build_cabt_selection_window
from .cabt_tree_hash import jcs_canonical_json_bytes


CONTRACT_GENERATION = 2
CANONICALIZER_ID = "cabt_jcs_tree_hash_v1"
_HASH_PREFIX = b"PTCGDAP\0CABT_WINDOW_V2\0"


class CabtWindowV2Error(RuntimeError):
    pass


class AtomicDecisionExecutor(Protocol):
    def prepare(self, private_targets: tuple[Any, ...]) -> Any: ...

    def commit(self, prepared: Any) -> Any: ...

    def rollback(self, prepared: Any) -> None: ...


def _hash(domain: str, value: Any) -> str:
    digest = hashlib.sha256()
    digest.update(_HASH_PREFIX)
    digest.update(domain.encode("ascii"))
    digest.update(b"\0")
    digest.update(jcs_canonical_json_bytes(value))
    return digest.hexdigest().upper()


def _upper_sha(value: Any) -> bool:
    return type(value) is str and len(value) == 64 and all(
        character in "0123456789ABCDEF" for character in value
    )


def _exact_json_copy(value: Any) -> Any:
    # Canonicalization validates finite JSON types, safe integers, Unicode and cycles.
    jcs_canonical_json_bytes(value)
    return copy.deepcopy(value)


@dataclass(frozen=True, slots=True)
class SelectionWindowPublicV2:
    contract_generation: int
    canonicalizer_id: str
    engine_semantic_hash: str
    policy_input_hash: str
    window_id: str
    window_generation: int
    seat: int
    select_type_raw: int
    context_raw: int
    min_count: int
    max_count: int
    remain_damage_counter: int
    remain_energy_cost: int
    options: tuple[Mapping[str, Any], ...]
    option_fingerprints: tuple[str, ...]
    authorized_deck: tuple[Mapping[str, Any], ...] | None
    context_card: Mapping[str, Any] | None
    effect: Mapping[str, Any] | None
    incremental_log_cursor: int
    incremental_log_hash: str
    time_budget: Mapping[str, Any]
    capability_profile_hash: str


@dataclass(frozen=True, slots=True)
class AcceptedSelectionV2:
    window_id: str
    window_generation: int
    indexes: tuple[int, ...]


@dataclass(frozen=True, slots=True)
class BoundSelectionV2:
    window_id: str
    window_generation: int
    indexes: tuple[int, ...]
    private_targets: tuple[Any, ...]


@dataclass(frozen=True, slots=True)
class TransitionWitnessV2:
    window_id: str
    window_generation: int
    committed_result: Any
    post_engine_semantic_hash: str
    post_log_hash: str
    public_witness: bool


class SelectionWindowBindingV2:
    """Host-private, single-use binding for one exact current official window."""

    __slots__ = (
        "public",
        "_session_id",
        "_match_generation",
        "_callback_binding_hash",
        "_private_options",
        "_state",
        "_accepted",
        "_bound",
        "_commit_result",
    )

    def __init__(
        self,
        *,
        public: SelectionWindowPublicV2,
        session_id: str,
        match_generation: int,
        callback_binding_hash: str,
        private_options: tuple[Any, ...],
    ) -> None:
        self.public = public
        self._session_id = session_id
        self._match_generation = match_generation
        self._callback_binding_hash = callback_binding_hash
        self._private_options = private_options
        self._state = "issued"
        self._accepted: AcceptedSelectionV2 | None = None
        self._bound: BoundSelectionV2 | None = None
        self._commit_result: Any = None

    @classmethod
    def issue(
        cls,
        raw_callback: Mapping[str, Any],
        *,
        session_id: str,
        match_generation: int,
        seat: int,
        window_generation: int,
        private_options: list[Any],
        log_cursor: int,
        capability_profile_hash: str,
        session_hmac_key: bytes,
    ) -> SelectionWindowBindingV2:
        if (
            type(raw_callback) is not dict
            or type(session_id) is not str
            or not session_id
            or type(match_generation) is not int
            or match_generation < 1
            or seat not in (0, 1)
            or type(window_generation) is not int
            or window_generation < 1
            or type(private_options) is not list
            or type(log_cursor) is not int
            or log_cursor < 0
            or not _upper_sha(capability_profile_hash)
            or type(session_hmac_key) is not bytes
            or len(session_hmac_key) < 32
        ):
            raise CabtWindowV2Error("cabt_window_configuration_invalid")
        raw = _exact_json_copy(raw_callback)
        select = raw.get("select")
        if type(select) is not dict or type(select.get("option")) is not list:
            raise CabtWindowV2Error("cabt_selection_window_required")
        if len(private_options) != len(select["option"]):
            raise CabtWindowV2Error("cabt_private_binding_cardinality_mismatch")
        semantic_value = {
            "select": raw.get("select"),
            "current": raw.get("current"),
            "logs": raw.get("logs"),
        }
        engine_semantic_hash = _hash("engine_semantic", semantic_value)
        policy_input_hash = _hash("policy_input", raw)
        shared = build_cabt_selection_window(
            select,
            public_observation_hash=engine_semantic_hash,
            public_hash_authority="firewall_accepted",
            chooser_player_index=seat,
        )
        if shared.window is None or shared.decision_state != "policy_allowed":
            code = shared.issues[0].code if shared.issues else "cabt_window_invalid"
            raise CabtWindowV2Error(code)
        search_value = raw.get("search_begin_input") if "search_begin_input" in raw else None
        search_binding = (
            hmac.new(session_hmac_key, search_value.encode("ascii"), hashlib.sha256)
            .hexdigest()
            .upper()
            if type(search_value) is str
            else None
        )
        callback_value = {
            "session_id": session_id,
            "match_generation": match_generation,
            "seat": seat,
            "window_generation": window_generation,
            "step_presence": "step" in raw,
            "step": raw.get("step"),
            "remaining_time_presence": "remainingOverageTime" in raw,
            "remainingOverageTime": raw.get("remainingOverageTime"),
            "engine_semantic_hash": engine_semantic_hash,
            "option_fingerprints": list(shared.window.option_fingerprints),
            "search_capability_present": type(search_value) is str,
            "search_binding_hmac": search_binding,
        }
        callback_binding_hash = _hash("callback_binding", callback_value)
        window_id = _hash(
            "window_id",
            {
                "callback_binding_hash": callback_binding_hash,
                "generation": window_generation,
            },
        )
        logs = raw.get("logs")
        if type(logs) is not list:
            raise CabtWindowV2Error("cabt_logs_invalid")
        time_budget = {
            "step_presence": "step" in raw,
            "step": raw.get("step"),
            "remaining_overage_time_presence": "remainingOverageTime" in raw,
            "remaining_overage_time": raw.get("remainingOverageTime"),
        }
        public = SelectionWindowPublicV2(
            contract_generation=CONTRACT_GENERATION,
            canonicalizer_id=CANONICALIZER_ID,
            engine_semantic_hash=engine_semantic_hash,
            policy_input_hash=policy_input_hash,
            window_id=window_id,
            window_generation=window_generation,
            seat=seat,
            select_type_raw=shared.window.select_type_raw,
            context_raw=shared.window.select_context_raw,
            min_count=shared.window.min_count,
            max_count=shared.window.max_count,
            remain_damage_counter=shared.window.remain_damage_counter,
            remain_energy_cost=shared.window.remain_energy_cost,
            options=tuple(copy.deepcopy(shared.window.options)),
            option_fingerprints=shared.window.option_fingerprints,
            authorized_deck=(
                None
                if shared.window.public_deck_candidates is None
                else tuple(copy.deepcopy(shared.window.public_deck_candidates))
            ),
            context_card=copy.deepcopy(shared.window.context_card),
            effect=copy.deepcopy(shared.window.effect),
            incremental_log_cursor=log_cursor,
            incremental_log_hash=_hash("incremental_logs", logs),
            time_budget=time_budget,
            capability_profile_hash=capability_profile_hash,
        )
        return cls(
            public=public,
            session_id=session_id,
            match_generation=match_generation,
            callback_binding_hash=callback_binding_hash,
            private_options=tuple(private_options),
        )

    @property
    def state(self) -> str:
        return self._state

    def accept(self, proposal: Any) -> AcceptedSelectionV2:
        if self._state != "issued":
            raise CabtWindowV2Error("cabt_window_stale")
        if type(proposal) is not list or any(type(index) is not int for index in proposal):
            raise CabtWindowV2Error("invalid_agent_output")
        if (
            not self.public.min_count <= len(proposal) <= self.public.max_count
            or len(proposal) != len(set(proposal))
            or any(index < 0 or index >= len(self.public.options) for index in proposal)
        ):
            raise CabtWindowV2Error("invalid_agent_output")
        accepted = AcceptedSelectionV2(
            self.public.window_id,
            self.public.window_generation,
            tuple(proposal),
        )
        self._accepted = accepted
        self._state = "accepted"
        return accepted

    def bind(self, accepted: AcceptedSelectionV2) -> BoundSelectionV2:
        if self._state != "accepted" or accepted is not self._accepted:
            raise CabtWindowV2Error("cabt_acceptance_binding_invalid")
        bound = BoundSelectionV2(
            self.public.window_id,
            self.public.window_generation,
            accepted.indexes,
            tuple(self._private_options[index] for index in accepted.indexes),
        )
        self._bound = bound
        self._state = "bound"
        return bound

    def commit(
        self,
        bound: BoundSelectionV2,
        executor: AtomicDecisionExecutor,
    ) -> Any:
        if self._state != "bound" or bound is not self._bound:
            raise CabtWindowV2Error("cabt_bound_selection_stale")
        if not all(callable(getattr(executor, name, None)) for name in ("prepare", "commit", "rollback")):
            raise CabtWindowV2Error("cabt_executor_invalid")
        prepared: Any = None
        try:
            prepared = executor.prepare(bound.private_targets)
            result = executor.commit(prepared)
        except BaseException as error:
            if prepared is not None:
                executor.rollback(prepared)
            self._state = "invalidated"
            raise CabtWindowV2Error("cabt_executor_atomic_failure") from error
        self._commit_result = result
        self._private_options = ()
        self._state = "committed"
        return result

    def witness(self, next_callback: Mapping[str, Any]) -> TransitionWitnessV2:
        if self._state != "committed":
            raise CabtWindowV2Error("cabt_commit_witness_invalid")
        next_raw = _exact_json_copy(next_callback)
        next_semantic = _hash(
            "engine_semantic",
            {
                "select": next_raw.get("select"),
                "current": next_raw.get("current"),
                "logs": next_raw.get("logs"),
            },
        )
        logs = next_raw.get("logs")
        if type(logs) is not list:
            raise CabtWindowV2Error("cabt_logs_invalid")
        post_log_hash = _hash("incremental_logs", logs)
        witnessed = (
            next_semantic != self.public.engine_semantic_hash
            or post_log_hash != self.public.incremental_log_hash
        )
        if not witnessed:
            raise CabtWindowV2Error("cabt_public_witness_missing")
        self._state = "public-witness"
        return TransitionWitnessV2(
            self.public.window_id,
            self.public.window_generation,
            self._commit_result,
            next_semantic,
            post_log_hash,
            True,
        )

    def invalidate(self) -> None:
        self._private_options = ()
        self._state = "invalidated"


__all__ = [
    "AcceptedSelectionV2",
    "AtomicDecisionExecutor",
    "BoundSelectionV2",
    "CabtWindowV2Error",
    "SelectionWindowBindingV2",
    "SelectionWindowPublicV2",
    "TransitionWitnessV2",
]
