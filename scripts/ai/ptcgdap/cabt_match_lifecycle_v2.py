from __future__ import annotations

import copy
from dataclasses import dataclass
from typing import Any, Callable, Mapping

from .cabt_window_v2 import (
    AcceptedSelectionV2,
    AtomicDecisionExecutor,
    BoundSelectionV2,
    CabtWindowV2Error,
    SelectionWindowBindingV2,
    TransitionWitnessV2,
)


class CabtLifecycleV2Error(RuntimeError):
    pass


@dataclass(frozen=True, slots=True)
class DeckBootstrapV2:
    seat: int
    deck: tuple[int, ...]
    match_generation: int


@dataclass(frozen=True, slots=True)
class TerminalCheckpointV2:
    match_generation: int
    result: Mapping[str, Any]
    log_cursors: tuple[int, int]


class CabtMatchLifecycleV2:
    """Owns the non-prompt CABT lifecycle around immutable selection windows.

    This owner deliberately keeps the initial deck-return domain separate from
    the later option-index domain.  It has no engine mutation API other than a
    supplied atomic executor for the exact current window.
    """

    def __init__(
        self,
        match_id: str,
        *,
        capability_profile_hash: str,
        session_hmac_keys: tuple[bytes, bytes],
        deck_validator: Callable[[int, tuple[int, ...]], bool],
    ) -> None:
        if (
            type(match_id) is not str
            or not match_id
            or type(capability_profile_hash) is not str
            or len(capability_profile_hash) != 64
            or any(character not in "0123456789ABCDEF" for character in capability_profile_hash)
            or type(session_hmac_keys) is not tuple
            or len(session_hmac_keys) != 2
            or any(type(key) is not bytes or len(key) < 32 for key in session_hmac_keys)
            or not callable(deck_validator)
        ):
            raise CabtLifecycleV2Error("cabt_lifecycle_configuration_invalid")
        self._match_id = match_id
        self._capability_profile_hash = capability_profile_hash
        self._session_hmac_keys = session_hmac_keys
        self._deck_validator = deck_validator
        self._match_generation = 1
        self._state = "created"
        self._bootstrap_seen = [False, False]
        self._decks: list[tuple[int, ...] | None] = [None, None]
        self._log_cursors = [0, 0]
        self._window_generation = [0, 0]
        self._current_seat: int | None = None
        self._current: SelectionWindowBindingV2 | None = None
        self._terminal: TerminalCheckpointV2 | None = None

    @property
    def state(self) -> str:
        return self._state

    @property
    def match_generation(self) -> int:
        return self._match_generation

    @property
    def log_cursors(self) -> tuple[int, int]:
        return tuple(self._log_cursors)

    @property
    def current_window(self) -> SelectionWindowBindingV2 | None:
        return self._current

    @staticmethod
    def _seat(value: Any) -> int:
        if type(value) is not int or value not in (0, 1):
            raise CabtLifecycleV2Error("cabt_lifecycle_seat_invalid")
        return value

    @staticmethod
    def _require_initial(raw_callback: Any) -> dict[str, Any]:
        if type(raw_callback) is not dict:
            raise CabtLifecycleV2Error("cabt_initial_callback_invalid")
        required = ("select", "current", "logs", "search_begin_input")
        if any(key not in raw_callback for key in required):
            raise CabtLifecycleV2Error("cabt_initial_callback_invalid")
        if (
            raw_callback["select"] is not None
            or raw_callback["current"] is not None
            or type(raw_callback["logs"]) is not list
            or raw_callback["logs"]
            or raw_callback["search_begin_input"] is not None
        ):
            raise CabtLifecycleV2Error("cabt_initial_callback_invalid")
        return copy.deepcopy(raw_callback)

    def bootstrap(self, seat: int, raw_initial: Any, agent_output: Any) -> DeckBootstrapV2:
        seat = self._seat(seat)
        if self._state not in ("created", "awaiting-decks") or self._bootstrap_seen[seat]:
            raise CabtLifecycleV2Error("cabt_bootstrap_stale")
        self._require_initial(raw_initial)
        if (
            type(agent_output) is not list
            or len(agent_output) != 60
            or any(type(card_id) is not int or card_id <= 0 for card_id in agent_output)
        ):
            raise CabtLifecycleV2Error("cabt_bootstrap_deck_invalid")
        deck = tuple(agent_output)
        if not self._deck_validator(seat, deck):
            raise CabtLifecycleV2Error("cabt_bootstrap_deck_illegal")
        self._bootstrap_seen[seat] = True
        self._decks[seat] = deck
        self._state = "ready" if all(self._bootstrap_seen) else "awaiting-decks"
        return DeckBootstrapV2(seat, deck, self._match_generation)

    def start_engine(self) -> tuple[tuple[int, ...], tuple[int, ...]]:
        if self._state != "ready" or any(deck is None for deck in self._decks):
            raise CabtLifecycleV2Error("cabt_engine_start_before_decks")
        self._state = "started"
        return (self._decks[0], self._decks[1])  # type: ignore[return-value]

    def issue_selection(
        self,
        seat: int,
        raw_callback: Mapping[str, Any],
        *,
        private_options: list[Any],
    ) -> SelectionWindowBindingV2:
        seat = self._seat(seat)
        if self._state not in ("started", "committed", "public-witness"):
            raise CabtLifecycleV2Error("cabt_selection_checkpoint_out_of_order")
        if self._current is not None and self._current.state not in ("public-witness", "invalidated"):
            raise CabtLifecycleV2Error("cabt_previous_window_not_witnessed")
        if type(raw_callback) is not dict or type(raw_callback.get("logs")) is not list:
            raise CabtLifecycleV2Error("cabt_selection_callback_invalid")
        self._window_generation[seat] += 1
        try:
            binding = SelectionWindowBindingV2.issue(
                raw_callback,
                session_id=f"{self._match_id}:seat-{seat}",
                match_generation=self._match_generation,
                seat=seat,
                window_generation=self._window_generation[seat],
                private_options=private_options,
                log_cursor=self._log_cursors[seat],
                capability_profile_hash=self._capability_profile_hash,
                session_hmac_key=self._session_hmac_keys[seat],
            )
        except CabtWindowV2Error as error:
            raise CabtLifecycleV2Error(str(error)) from error
        self._log_cursors[seat] += len(raw_callback["logs"])
        self._current_seat = seat
        self._current = binding
        self._state = "waiting-selection"
        return binding

    def accept(self, seat: int, indexes: Any) -> AcceptedSelectionV2:
        seat = self._seat(seat)
        if self._state != "waiting-selection" or seat != self._current_seat or self._current is None:
            raise CabtLifecycleV2Error("cabt_window_seat_or_state_invalid")
        try:
            accepted = self._current.accept(indexes)
        except CabtWindowV2Error as error:
            raise CabtLifecycleV2Error(str(error)) from error
        self._state = "accepted"
        return accepted

    def bind(self, accepted: AcceptedSelectionV2) -> BoundSelectionV2:
        if self._state != "accepted" or self._current is None:
            raise CabtLifecycleV2Error("cabt_acceptance_binding_invalid")
        try:
            bound = self._current.bind(accepted)
        except CabtWindowV2Error as error:
            raise CabtLifecycleV2Error(str(error)) from error
        self._state = "bound"
        return bound

    def commit(self, bound: BoundSelectionV2, executor: AtomicDecisionExecutor) -> Any:
        if self._state != "bound" or self._current is None:
            raise CabtLifecycleV2Error("cabt_bound_selection_stale")
        try:
            result = self._current.commit(bound, executor)
        except CabtWindowV2Error as error:
            self._state = "invalidated"
            raise CabtLifecycleV2Error(str(error)) from error
        self._state = "committed"
        return result

    def witness(self, next_callback: Mapping[str, Any]) -> TransitionWitnessV2:
        if self._state != "committed" or self._current is None:
            raise CabtLifecycleV2Error("cabt_commit_witness_invalid")
        try:
            witness = self._current.witness(next_callback)
        except CabtWindowV2Error as error:
            raise CabtLifecycleV2Error(str(error)) from error
        self._state = "public-witness"
        return witness

    def terminal(self, result: Any, *, incremental_logs_by_seat: tuple[list[Any], list[Any]]) -> TerminalCheckpointV2:
        if self._state not in ("started", "committed", "public-witness"):
            raise CabtLifecycleV2Error("cabt_terminal_out_of_order")
        if type(result) is not dict or type(incremental_logs_by_seat) is not tuple or len(incremental_logs_by_seat) != 2:
            raise CabtLifecycleV2Error("cabt_terminal_invalid")
        if any(type(logs) is not list for logs in incremental_logs_by_seat):
            raise CabtLifecycleV2Error("cabt_terminal_invalid")
        if self._current is not None and self._current.state not in ("public-witness", "invalidated"):
            self._current.invalidate()
        for seat in (0, 1):
            self._log_cursors[seat] += len(incremental_logs_by_seat[seat])
        self._current = None
        self._current_seat = None
        self._terminal = TerminalCheckpointV2(
            self._match_generation,
            copy.deepcopy(result),
            tuple(self._log_cursors),
        )
        self._state = "terminal"
        return self._terminal

    def dispose(self) -> None:
        if self._current is not None:
            self._current.invalidate()
        self._decks = [None, None]
        self._bootstrap_seen = [False, False]
        self._log_cursors = [0, 0]
        self._window_generation = [0, 0]
        self._current_seat = None
        self._current = None
        self._terminal = None
        self._state = "disposed"


__all__ = [
    "CabtLifecycleV2Error",
    "CabtMatchLifecycleV2",
    "DeckBootstrapV2",
    "TerminalCheckpointV2",
]
