from __future__ import annotations

import copy
from dataclasses import dataclass
import hashlib
from pathlib import Path
import re
from types import MappingProxyType
from typing import Any, Final, Mapping

from scripts.ai.ptcgdap.cabt_selection import (
    CabtDeterministicFallback,
    CabtSelectionResolution,
    CabtSelectionWindow,
    _require_current_window,
)
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT: Final = Path(__file__).resolve().parents[3]
CONTRACT_ROOT: Final = ROOT / "contracts" / "ptcgdap"
PROFILE_ID: Final = "ptcgdap-public-policy-budget-p4-wp6-v1"
EXPECTED_BUNDLE_SHA256: Final = "0D82BDE31BD0FA0C44527880D9D6451C2733702913708532C512F3BFF81D8BF9"
EXPECTED_PARENT_BUNDLE_SHA256: Final = "18AAB663D9B429AC8657A75692F5DD8CF37C409CC057A328B57758C692FDB7F4"
EXPECTED_SOURCE_LOCK_SHA256: Final = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
EXPECTED_ARTIFACTS: Final = {
    "public_policy_budget.schema.json": "580A410176600BA9BD0206B5035BF50A5A33D4FC14298DDC2AE699C2DF9215C7",
    "public_policy_budget_profile.json": "F70C5172F2E1286E16E142B9026532AADB5C34CFDC5E8B796F1E404FA3A83632",
    "public_policy_budget_conformance_vectors.json": "A9DF2CF48CA8BC675583B27C5E3741ABA4FA296C98ADD8106795902DD4C8EB6E",
}
TOTAL_BUDGET_MS: Final = 600_000
BASE_ONLY_THRESHOLD_MS: Final = 30_000
FALLBACK_THRESHOLD_MS: Final = 5_000
SAFE_MAX: Final = 9_007_199_254_740_991
REQUIRED_CAPABILITIES: Final = (
    "public_base_policy_v1",
    "current_window_sanitizer_v1",
    "deterministic_base_fallback_v1",
)
OPTIONAL_CAPABILITIES: Final = (
    "public_deck_adapter_v1",
    "learned_policy_head_v1",
    "search_v1",
)
KNOWN_CAPABILITIES: Final = REQUIRED_CAPABILITIES + OPTIONAL_CAPABILITIES
CAPABILITY_STATES: Final = frozenset({"available", "unavailable", "unsupported"})
MODES: Final = frozenset({"full", "base_only", "deterministic_fallback"})
LEDGER_PREFIX: Final = b"PTCGDAP\0PUBLIC_POLICY_BUDGET_LEDGER_V1\0"
TELEMETRY_PREFIX: Final = b"PTCGDAP\0PUBLIC_POLICY_BUDGET_TELEMETRY_V1\0"
RESULT_PREFIX: Final = b"PTCGDAP\0PUBLIC_POLICY_BUDGET_RESULT_V1\0"
_IDENTIFIER: Final = re.compile(r"^[a-z0-9][a-z0-9._-]{0,127}$")
_LEDGER_TOKEN: Final = object()
_RESULT_TOKEN: Final = object()


class PublicPolicyBudgetError(ValueError):
    pass


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _domain_hash(prefix: bytes, value: Any) -> str:
    return _sha(prefix + canonical_json_v1_bytes(value))


def _freeze(value: Any) -> Any:
    if type(value) is dict:
        return MappingProxyType({key: _freeze(child) for key, child in value.items()})
    if type(value) is list:
        return tuple(_freeze(child) for child in value)
    return value


def _thaw(value: Any) -> Any:
    if isinstance(value, Mapping):
        return {key: _thaw(child) for key, child in value.items()}
    if type(value) is tuple:
        return [_thaw(child) for child in value]
    return value


def _exact_safe_int(value: Any) -> bool:
    return type(value) is int and 0 <= value <= SAFE_MAX


def _identifier(value: Any) -> bool:
    return type(value) is str and _IDENTIFIER.fullmatch(value) is not None and "private" not in value.lower()


def _load_contracts(contract_root: Path | None = None) -> None:
    root = CONTRACT_ROOT if contract_root is None else Path(contract_root)
    try:
        bundle = load_json_strict(root / "public_policy_budget_bundle.json")
        if _sha(canonical_json_v1_bytes(bundle)) != EXPECTED_BUNDLE_SHA256:
            raise PublicPolicyBudgetError("contract_error")
        if type(bundle) is not dict or set(bundle) != {
            "schema_version",
            "bundle_id",
            "parent_bundle_canonical_sha256",
            "source_lock_canonical_sha256",
            "artifacts",
        }:
            raise PublicPolicyBudgetError("contract_error")
        if (
            bundle["schema_version"] != 1
            or bundle["bundle_id"] != PROFILE_ID
            or bundle["parent_bundle_canonical_sha256"] != EXPECTED_PARENT_BUNDLE_SHA256
            or bundle["source_lock_canonical_sha256"] != EXPECTED_SOURCE_LOCK_SHA256
        ):
            raise PublicPolicyBudgetError("contract_error")
        entries = bundle["artifacts"]
        if type(entries) is not list or len(entries) != len(EXPECTED_ARTIFACTS):
            raise PublicPolicyBudgetError("contract_error")
        documents: dict[str, Any] = {}
        for entry, name in zip(entries, EXPECTED_ARTIFACTS, strict=True):
            if type(entry) is not dict or set(entry) != {"id", "path", "canonical_sha256"}:
                raise PublicPolicyBudgetError("contract_error")
            expected_hash = EXPECTED_ARTIFACTS[name]
            if (
                entry["id"] != name.removesuffix(".json")
                or entry["path"] != f"contracts/ptcgdap/{name}"
                or entry["canonical_sha256"] != expected_hash
            ):
                raise PublicPolicyBudgetError("contract_error")
            document = load_json_strict(root / name)
            if _sha(canonical_json_v1_bytes(document)) != expected_hash:
                raise PublicPolicyBudgetError("contract_error")
            documents[name] = document
        profile = documents["public_policy_budget_profile.json"]
        budget = profile.get("budget_contract", {}) if type(profile) is dict else {}
        capability = profile.get("capability_contract", {}) if type(profile) is dict else {}
        serialization = profile.get("serialization_contract", {}) if type(profile) is dict else {}
        if (
            profile.get("profile_id") != PROFILE_ID
            or profile.get("parent_bundle_canonical_sha256") != EXPECTED_PARENT_BUNDLE_SHA256
            or budget.get("total_match_budget_ms") != TOTAL_BUDGET_MS
            or budget.get("base_only_at_or_below_remaining_ms") != BASE_ONLY_THRESHOLD_MS
            or budget.get("fallback_at_or_below_remaining_ms") != FALLBACK_THRESHOLD_MS
            or tuple(budget.get("modes", ())) != ("full", "base_only", "deterministic_fallback")
            or tuple(capability.get("required", ())) != REQUIRED_CAPABILITIES
            or tuple(capability.get("optional", ())) != OPTIONAL_CAPABILITIES
            or set(capability.get("states", ())) != CAPABILITY_STATES
            or serialization.get("ledger_and_result_are_execution_authority") is not False
            or serialization.get("unknown_capability_names_are_serialized") is not False
            or serialization.get("consumer_must_revalidate_exact_window") is not True
        ):
            raise PublicPolicyBudgetError("contract_error")
    except PublicPolicyBudgetError:
        raise
    except Exception as exc:
        raise PublicPolicyBudgetError("contract_error") from exc


def _ledger_payload(
    ledger_id: str,
    ordinal: int,
    remaining_ms: int,
    cumulative_elapsed_ms: int,
    previous_telemetry_hash: str | None,
) -> dict[str, Any]:
    payload = {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "ledger_id": ledger_id,
        "decision_ordinal": ordinal,
        "total_budget_ms": TOTAL_BUDGET_MS,
        "remaining_ms": remaining_ms,
        "cumulative_elapsed_ms": cumulative_elapsed_ms,
        "previous_telemetry_hash": previous_telemetry_hash,
    }
    return {**payload, "ledger_hash": _domain_hash(LEDGER_PREFIX, payload)}


@dataclass(frozen=True, slots=True, init=False)
class PublicPolicyBudgetLedger:
    _snapshot: Mapping[str, Any]
    _construction_seal: object

    def __new__(cls) -> PublicPolicyBudgetLedger:
        raise TypeError("PublicPolicyBudgetLedger instances are owner-created")

    @classmethod
    def _from_owner(cls, payload: dict[str, Any], token: object) -> PublicPolicyBudgetLedger:
        if token is not _LEDGER_TOKEN:
            raise PublicPolicyBudgetError("invalid_ledger")
        value = object.__new__(cls)
        object.__setattr__(value, "_snapshot", _freeze(copy.deepcopy(payload)))
        object.__setattr__(value, "_construction_seal", token)
        if not value.validate_integrity():
            raise PublicPolicyBudgetError("invalid_ledger")
        return value

    @classmethod
    def start(cls, ledger_id: Any, *, contract_root: Path | None = None) -> PublicPolicyBudgetLedger:
        _load_contracts(contract_root)
        if not _identifier(ledger_id):
            raise PublicPolicyBudgetError("invalid_ledger")
        return cls._from_owner(_ledger_payload(ledger_id, 0, TOTAL_BUDGET_MS, 0, None), _LEDGER_TOKEN)

    @property
    def ledger_hash(self) -> str:
        return self._snapshot["ledger_hash"] if self.validate_integrity() else ""

    @property
    def remaining_ms(self) -> int:
        return self._snapshot["remaining_ms"] if self.validate_integrity() else 0

    @property
    def decision_ordinal(self) -> int:
        return self._snapshot["decision_ordinal"] if self.validate_integrity() else 0

    def validate_integrity(self) -> bool:
        try:
            if type(self) is not PublicPolicyBudgetLedger or self._construction_seal is not _LEDGER_TOKEN:
                return False
            value = _thaw(self._snapshot)
            if type(value) is not dict or set(value) != {
                "schema_version", "profile_id", "ledger_id", "decision_ordinal", "total_budget_ms",
                "remaining_ms", "cumulative_elapsed_ms", "previous_telemetry_hash", "ledger_hash",
            }:
                return False
            if (
                value["schema_version"] != 1
                or value["profile_id"] != PROFILE_ID
                or not _identifier(value["ledger_id"])
                or not _exact_safe_int(value["decision_ordinal"])
                or value["total_budget_ms"] != TOTAL_BUDGET_MS
                or not _exact_safe_int(value["remaining_ms"])
                or not _exact_safe_int(value["cumulative_elapsed_ms"])
                or value["remaining_ms"] > TOTAL_BUDGET_MS
                or value["cumulative_elapsed_ms"] > TOTAL_BUDGET_MS
                or value["remaining_ms"] + value["cumulative_elapsed_ms"] != TOTAL_BUDGET_MS
                or (
                    value["previous_telemetry_hash"] is not None
                    and (type(value["previous_telemetry_hash"]) is not str or re.fullmatch(r"[0-9A-F]{64}", value["previous_telemetry_hash"]) is None)
                )
            ):
                return False
            expected = _ledger_payload(
                value["ledger_id"], value["decision_ordinal"], value["remaining_ms"],
                value["cumulative_elapsed_ms"], value["previous_telemetry_hash"],
            )
            return value == expected
        except Exception:
            return False

    def to_public_dict(self) -> dict[str, Any]:
        if not self.validate_integrity():
            raise PublicPolicyBudgetError("invalid_ledger")
        return copy.deepcopy(_thaw(self._snapshot))


def _capability_error(value: Any) -> str | None:
    if type(value) is not dict:
        return "invalid_capability_report"
    for key, state in value.items():
        if not _identifier(key) or type(state) is not str or state not in CAPABILITY_STATES:
            return "invalid_capability_report"
    return None


def _classification(
    remaining_after_ms: int,
    capabilities: dict[str, str],
) -> tuple[str, str, list[str], int]:
    known = set(KNOWN_CAPABILITIES)
    unknown_count = sum(1 for key in capabilities if key not in known)
    unavailable = sorted(key for key in known if capabilities.get(key) != "available")
    if unknown_count:
        return "deterministic_fallback", "unknown_capability", unavailable, unknown_count
    if any(capabilities.get(key) != "available" for key in REQUIRED_CAPABILITIES):
        return "deterministic_fallback", "required_capability_unavailable", unavailable, 0
    if remaining_after_ms == 0:
        return "deterministic_fallback", "budget_exhausted", unavailable, 0
    if remaining_after_ms <= FALLBACK_THRESHOLD_MS:
        return "deterministic_fallback", "budget_reserve", unavailable, 0
    if remaining_after_ms <= BASE_ONLY_THRESHOLD_MS:
        return "base_only", "budget_constrained", unavailable, 0
    if capabilities.get("public_deck_adapter_v1") != "available":
        return "base_only", "optional_capability_unavailable", unavailable, 0
    return "full", "full_budget_available", unavailable, 0


def _result_payload(
    ledger: PublicPolicyBudgetLedger,
    window: CabtSelectionWindow,
    elapsed_ms: int,
    capabilities: dict[str, str],
    selected_indexes: list[int],
) -> tuple[dict[str, Any], dict[str, Any]]:
    ledger_value = ledger.to_public_dict()
    charged = min(elapsed_ms, ledger_value["remaining_ms"])
    remaining = ledger_value["remaining_ms"] - charged
    mode, reason, unavailable, unknown_count = _classification(remaining, capabilities)
    telemetry = {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "ledger_id": ledger_value["ledger_id"],
        "window_id": window.window_id,
        "ledger_before_hash": ledger_value["ledger_hash"],
        "decision_ordinal": ledger_value["decision_ordinal"] + 1,
        "remaining_before_ms": ledger_value["remaining_ms"],
        "elapsed_ms": elapsed_ms,
        "charged_elapsed_ms": charged,
        "remaining_after_ms": remaining,
        "mode": mode,
        "reason_code": reason,
        "known_unavailable_capabilities": unavailable,
        "unknown_capability_count": unknown_count,
        "fallback_used": mode == "deterministic_fallback",
    }
    telemetry_hash = _domain_hash(TELEMETRY_PREFIX, telemetry)
    next_ledger = _ledger_payload(
        ledger_value["ledger_id"], ledger_value["decision_ordinal"] + 1, remaining,
        ledger_value["cumulative_elapsed_ms"] + charged, telemetry_hash,
    )
    payload = {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "ledger_id": ledger_value["ledger_id"],
        "window_id": window.window_id,
        "ledger_before_hash": ledger_value["ledger_hash"],
        "decision_ordinal": ledger_value["decision_ordinal"] + 1,
        "remaining_before_ms": ledger_value["remaining_ms"],
        "elapsed_ms": elapsed_ms,
        "remaining_after_ms": remaining,
        "mode": mode,
        "reason_code": reason,
        "known_unavailable_capabilities": unavailable,
        "unknown_capability_count": unknown_count,
        "selected_indexes": selected_indexes if mode == "deterministic_fallback" else [],
        "fallback_used": mode == "deterministic_fallback",
        "telemetry_hash": telemetry_hash,
        "next_ledger": next_ledger,
        "authority": "public_policy_budget_audit",
        "authoritative": False,
    }
    return {**payload, "result_hash": _domain_hash(RESULT_PREFIX, payload)}, next_ledger


@dataclass(frozen=True, slots=True, init=False)
class PublicPolicyBudgetResult:
    _snapshot: Mapping[str, Any]
    _construction_seal: object
    _ledger_binding: PublicPolicyBudgetLedger
    _window_binding: CabtSelectionWindow
    _elapsed_ms: int
    _capabilities: Mapping[str, str]
    _fallback_binding: CabtSelectionResolution | None
    _next_ledger_binding: PublicPolicyBudgetLedger

    def __new__(cls) -> PublicPolicyBudgetResult:
        raise TypeError("PublicPolicyBudgetResult instances are controller-created")

    @classmethod
    def _from_owner(
        cls,
        payload: dict[str, Any],
        ledger: PublicPolicyBudgetLedger,
        window: CabtSelectionWindow,
        elapsed_ms: int,
        capabilities: dict[str, str],
        fallback: CabtSelectionResolution | None,
        next_ledger: PublicPolicyBudgetLedger,
        token: object,
    ) -> PublicPolicyBudgetResult:
        if token is not _RESULT_TOKEN:
            raise PublicPolicyBudgetError("result_integrity_invalid")
        value = object.__new__(cls)
        for name, child in (
            ("_snapshot", _freeze(copy.deepcopy(payload))),
            ("_construction_seal", token),
            ("_ledger_binding", ledger),
            ("_window_binding", window),
            ("_elapsed_ms", elapsed_ms),
            ("_capabilities", _freeze(copy.deepcopy(capabilities))),
            ("_fallback_binding", fallback),
            ("_next_ledger_binding", next_ledger),
        ):
            object.__setattr__(value, name, child)
        if not value.validate_integrity(ledger, window):
            raise PublicPolicyBudgetError("result_integrity_invalid")
        return value

    @property
    def mode(self) -> str:
        return self._snapshot["mode"] if self.validate_integrity(self._ledger_binding, self._window_binding) else ""

    @property
    def selected_indexes(self) -> list[int]:
        if not self.validate_integrity(self._ledger_binding, self._window_binding):
            return []
        return list(self._snapshot["selected_indexes"])

    @property
    def next_ledger(self) -> PublicPolicyBudgetLedger | None:
        return self._next_ledger_binding if self.validate_integrity(self._ledger_binding, self._window_binding) else None

    def validate_integrity(self, ledger: Any, window: Any) -> bool:
        try:
            if (
                type(self) is not PublicPolicyBudgetResult
                or self._construction_seal is not _RESULT_TOKEN
                or ledger is not self._ledger_binding
                or window is not self._window_binding
                or type(ledger) is not PublicPolicyBudgetLedger
                or not ledger.validate_integrity()
                or type(window) is not CabtSelectionWindow
                or _require_current_window(window) is not window
                or not _exact_safe_int(self._elapsed_ms)
                or not isinstance(self._capabilities, Mapping)
                or _capability_error(_thaw(self._capabilities)) is not None
                or type(self._next_ledger_binding) is not PublicPolicyBudgetLedger
                or not self._next_ledger_binding.validate_integrity()
            ):
                return False
            capabilities = _thaw(self._capabilities)
            remaining = max(0, ledger.remaining_ms - min(self._elapsed_ms, ledger.remaining_ms))
            mode = _classification(remaining, capabilities)[0]
            selected: list[int] = []
            if mode == "deterministic_fallback":
                if (
                    type(self._fallback_binding) is not CabtSelectionResolution
                    or not self._fallback_binding.validate_integrity(window)
                    or self._fallback_binding.owner != "deterministic_fallback"
                ):
                    return False
                selected = list(self._fallback_binding.selected_indexes)
            elif self._fallback_binding is not None:
                return False
            expected, next_payload = _result_payload(ledger, window, self._elapsed_ms, capabilities, selected)
            return _thaw(self._snapshot) == expected and self._next_ledger_binding.to_public_dict() == next_payload
        except Exception:
            return False

    def to_public_dict(self) -> dict[str, Any]:
        if not self.validate_integrity(self._ledger_binding, self._window_binding):
            raise PublicPolicyBudgetError("result_integrity_invalid")
        return copy.deepcopy(_thaw(self._snapshot))


@dataclass(frozen=True, slots=True)
class PublicPolicyBudgetOutcome:
    accepted: bool
    error_code: str
    result: PublicPolicyBudgetResult | None


def _failure(code: str) -> PublicPolicyBudgetOutcome:
    return PublicPolicyBudgetOutcome(False, code, None)


class PublicPolicyBudgetController:
    __slots__ = ()

    @staticmethod
    def step(
        ledger: Any,
        window: Any,
        *,
        elapsed_ms: Any,
        capabilities: Any,
        contract_root: Path | None = None,
    ) -> PublicPolicyBudgetOutcome:
        try:
            _load_contracts(contract_root)
        except PublicPolicyBudgetError:
            return _failure("contract_error")
        if type(ledger) is not PublicPolicyBudgetLedger or not ledger.validate_integrity():
            return _failure("invalid_ledger")
        try:
            if type(window) is not CabtSelectionWindow or _require_current_window(window) is not window:
                return _failure("invalid_window")
        except Exception:
            return _failure("invalid_window")
        if not _exact_safe_int(elapsed_ms):
            return _failure("invalid_elapsed_ms")
        if _capability_error(capabilities) is not None:
            return _failure("invalid_capability_report")
        capability_value = copy.deepcopy(capabilities)
        remaining = max(0, ledger.remaining_ms - min(elapsed_ms, ledger.remaining_ms))
        mode = _classification(remaining, capability_value)[0]
        fallback: CabtSelectionResolution | None = None
        selected: list[int] = []
        if mode == "deterministic_fallback":
            try:
                fallback = CabtDeterministicFallback.resolve(window, reason_code="policy_unavailable")
                if not fallback.validate_integrity(window):
                    return _failure("invalid_window")
                selected = list(fallback.selected_indexes)
            except Exception:
                return _failure("invalid_window")
        try:
            payload, next_payload = _result_payload(ledger, window, elapsed_ms, capability_value, selected)
            next_ledger = PublicPolicyBudgetLedger._from_owner(next_payload, _LEDGER_TOKEN)
            result = PublicPolicyBudgetResult._from_owner(
                payload, ledger, window, elapsed_ms, capability_value, fallback, next_ledger, _RESULT_TOKEN
            )
            return PublicPolicyBudgetOutcome(True, "", result)
        except Exception:
            return _failure("result_integrity_invalid")


__all__ = [
    "EXPECTED_BUNDLE_SHA256",
    "PROFILE_ID",
    "PublicPolicyBudgetController",
    "PublicPolicyBudgetError",
    "PublicPolicyBudgetLedger",
    "PublicPolicyBudgetOutcome",
    "PublicPolicyBudgetResult",
]
