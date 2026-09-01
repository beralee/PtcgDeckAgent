from __future__ import annotations

import copy
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .cabt_envelope import (
    CabtParseIssue,
    EnvelopeParseResult,
    RawCabtEnvelope,
    parse_raw_cabt_envelope,
)


@dataclass(frozen=True)
class SessionIngestResult:
    envelope: RawCabtEnvelope | None
    issues: tuple[CabtParseIssue, ...]
    reset: bool

    @property
    def policy_eligible(self) -> bool:
        return self.envelope is not None and not any(
            issue.severity == "error" for issue in self.issues
        )

    @property
    def ok(self) -> bool:
        return self.policy_eligible

    def safe_diagnostics(self) -> list[dict[str, str]]:
        return [issue.to_dict() for issue in self.issues]


class PtcgDAPSession:
    def __init__(self, session_id: str, *, contract_root: str | Path | None = None) -> None:
        if not isinstance(session_id, str) or not session_id:
            raise ValueError("session_id must be a non-empty string")
        self._session_id = session_id
        self._contract_root = Path(contract_root) if contract_root is not None else None
        self._episode_generation = 0
        self._callback_generation = 0
        self._current_callback_binding_hash: str | None = None
        self._opaque_search_capability_present = False
        self._callback_local_state: dict[str, Any] = {}

    @property
    def session_id(self) -> str:
        return self._session_id

    @property
    def episode_generation(self) -> int:
        return self._episode_generation

    @property
    def callback_generation(self) -> int:
        return self._callback_generation

    @property
    def current_callback_binding_hash(self) -> str | None:
        return self._current_callback_binding_hash

    @property
    def opaque_search_capability_present(self) -> bool:
        return self._opaque_search_capability_present

    @property
    def callback_local_state(self) -> dict[str, Any]:
        return copy.deepcopy(self._callback_local_state)

    def remember_callback_local(self, key: str, value: Any) -> None:
        if not isinstance(key, str) or not key:
            raise ValueError("callback-local key must be a non-empty string")
        self._callback_local_state[key] = copy.deepcopy(value)

    def ingest(self, raw_payload: Any) -> SessionIngestResult:
        # An ingest attempt revokes all authority tied to the prior callback,
        # even when the replacement callback later fails closed.
        self._callback_local_state = {}
        self._current_callback_binding_hash = None
        self._opaque_search_capability_present = False
        parse_result: EnvelopeParseResult = parse_raw_cabt_envelope(
            raw_payload,
            contract_root=self._contract_root,
        )
        envelope = parse_result.envelope
        if envelope is None:
            return SessionIngestResult(None, parse_result.issues, False)

        reset = envelope.is_initial_callback
        if reset:
            self._episode_generation += 1
            self._callback_generation = 0
        else:
            self._callback_generation += 1
        self._current_callback_binding_hash = envelope.token_free_callback_hash
        self._opaque_search_capability_present = (
            envelope.opaque_search_capability_present
        )
        return SessionIngestResult(envelope, parse_result.issues, reset)
