from __future__ import annotations

import hashlib
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping

from .cabt_tree_hash import jcs_canonical_json_bytes
from .source_lock import load_json_strict


class CabtCapabilityV2Error(RuntimeError):
    pass


@dataclass(frozen=True, slots=True)
class TimeProfileV2:
    profile_id: str
    profile_hash: str
    act_timeout: int | float
    remaining_overage_time: int | float
    run_timeout: int | float
    episode_steps: int
    time_authority: str
    budget_accounting: str


def load_time_profile(contract_root: str | Path, profile_id: str) -> TimeProfileV2:
    root = Path(contract_root)
    document = load_json_strict(root / "cabt_time_profile_v2.json")
    if type(document) is not dict or type(document.get("profiles")) is not dict:
        raise CabtCapabilityV2Error("cabt_time_profile_contract_invalid")
    profile = document["profiles"].get(profile_id)
    if type(profile) is not dict:
        raise CabtCapabilityV2Error("cabt_time_profile_unknown")
    profile_hash = hashlib.sha256(jcs_canonical_json_bytes(profile)).hexdigest().upper()
    numeric = ("actTimeout", "remainingOverageTime", "runTimeout")
    if any(type(profile.get(key)) not in (int, float) for key in numeric):
        raise CabtCapabilityV2Error("cabt_time_profile_contract_invalid")
    if type(profile.get("episodeSteps")) is not int or profile["episodeSteps"] <= 0:
        raise CabtCapabilityV2Error("cabt_time_profile_contract_invalid")
    return TimeProfileV2(
        profile_id,
        profile_hash,
        profile["actTimeout"],
        profile["remainingOverageTime"],
        profile["runTimeout"],
        profile["episodeSteps"],
        str(profile.get("time_authority", "")),
        str(profile.get("budget_accounting", "")),
    )


class CallbackBudgetV2:
    """Monotonic callback/Search accounting; Search can never reset budget."""

    def __init__(self, profile: TimeProfileV2) -> None:
        self._profile = profile
        self._elapsed = 0.0
        self._steps = 0
        self._fault: str | None = None

    @property
    def remaining_overage_time(self) -> float:
        return max(0.0, float(self._profile.remaining_overage_time) - self._elapsed)

    @property
    def steps(self) -> int:
        return self._steps

    @property
    def fault(self) -> str | None:
        return self._fault

    def charge(self, elapsed: int | float, *, phase: str) -> None:
        if type(elapsed) not in (int, float) or elapsed < 0 or phase not in ("import", "callback", "search"):
            raise CabtCapabilityV2Error("cabt_budget_charge_invalid")
        self._elapsed += float(elapsed)
        if phase in ("callback", "search"):
            self._steps += 1
        if self._steps > self._profile.episode_steps or self._elapsed > float(self._profile.remaining_overage_time):
            self._fault = "policy_timeout"
            raise CabtCapabilityV2Error("policy_timeout")


class SearchCapabilityV2:
    """Callback-scoped opaque capability with no public/persistent representation."""

    def __init__(self, capability_id: str) -> None:
        if capability_id not in ("none", "official_native"):
            raise CabtCapabilityV2Error("authority_search_unavailable")
        self._capability_id = capability_id
        self._token: str | None = None
        self._callback_generation = 0

    @property
    def capability_id(self) -> str:
        return self._capability_id

    def observe_callback(self, raw_callback: Mapping[str, Any]) -> None:
        self._callback_generation += 1
        self._token = None
        token = raw_callback.get("search_begin_input")
        if token is not None:
            if self._capability_id != "official_native" or type(token) is not str or not token.isascii() or not token:
                raise CabtCapabilityV2Error("authority_search_unavailable")
            self._token = token

    def begin(self, predicted_hidden: Mapping[str, Any]) -> tuple[int, str, dict[str, Any]]:
        if self._capability_id != "official_native" or self._token is None:
            raise CabtCapabilityV2Error("authority_search_unavailable")
        if type(predicted_hidden) is not dict:
            raise CabtCapabilityV2Error("cabt_search_prediction_invalid")
        # Token is returned only to the in-memory native bridge.  It is never
        # included in public hashes, traces, receipts, or object snapshots.
        return self._callback_generation, self._token, dict(predicted_hidden)

    def release(self) -> None:
        self._token = None

    def public_snapshot(self) -> dict[str, Any]:
        return {
            "capability_id": self._capability_id,
            "callback_generation": self._callback_generation,
            "token_present": self._token is not None,
            "token": None,
        }


__all__ = [
    "CallbackBudgetV2",
    "CabtCapabilityV2Error",
    "SearchCapabilityV2",
    "TimeProfileV2",
    "load_time_profile",
]
