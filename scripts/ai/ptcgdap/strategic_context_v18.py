from __future__ import annotations

import copy
from dataclasses import dataclass
import hashlib
from pathlib import Path
from types import MappingProxyType
from typing import Any, Final, Mapping

from .cabt_selection import CabtSelectionResolution, CabtSelectionWindow, _require_current_window
from .cabt_tree_hash import CabtTreeHashError, jcs_canonical_json_bytes
from .public_observation_firewall import PublicFirewallResult
from .source_lock import canonical_json_v1_bytes, load_json_bytes_strict


PROFILE_ID: Final = "ptcgdap-strategic-context-v18-p4-wp1-v1"
DECISION_PROFILE_ID: Final = "ptcgdap-policy-decision-p4-wp1-v1"
EXPECTED_BUNDLE_SHA256: Final = "AACFA7E2E7F914180A2B7A5C4D92D6514ACC5F4622FC95B57DC225673893F98F"
EXPECTED_ARTIFACTS: Final = MappingProxyType(
    {
        "schema": ("strategic_context_v18.schema.json", "C355A905C25EF40D228BFA1B77B3080589DA62756E162A52B8D9CC286B8DCC0C"),
        "profile": ("strategic_context_v18_profile.json", "76BB67D817D61FCAAA4CD6BA125E23F51330E94575F119653E8F364E69A720A2"),
        "vectors": ("strategic_context_v18_conformance_vectors.json", "428B2466643B0F4341FC92BA5B2918650AA4974DB8ED1B41B77114DAFC29FCEA"),
    }
)
CONTEXT_PREFIX: Final = b"PTCGDAP\0STRATEGIC_CONTEXT_V18\0"
DECISION_PREFIX: Final = b"PTCGDAP\0POLICY_DECISION_AUDIT_V1\0"
PUBLIC_HASH_AUTHORITY: Final = "firewall_accepted"
MAX_CONTRACT_BYTES: Final = 2 * 1024 * 1024
MAX_CONTEXT_BYTES: Final = 1024 * 1024
SAFE_MAX: Final = 2**53 - 1
_CONTEXT_TOKEN: Final = object()
_DECISION_TOKEN: Final = object()
_CONTEXT_KEYS: Final = frozenset(
    {
        "schema_version", "profile_id", "context_hash", "source", "clocks",
        "public_state", "select_semantics", "opponent_public_belief",
        "public_event_delta", "provenance", "authority", "authoritative",
    }
)
_DECISION_KEYS: Final = frozenset(
    {
        "schema_version", "profile_id", "selected_indexes", "selected_semantic_intent",
        "owner_layer", "reason_code", "fallback_tier", "context_hash", "policy_hash",
        "audit_id", "window_id", "public_observation_hash", "scene_id", "decision_id",
        "determinism_key", "authority", "authoritative",
    }
)
_PRIVATE_KEYS: Final = frozenset(
    {
        "raw_private_hash", "token_free_callback_hash", "search_begin_input", "session",
        "callback", "binding", "ticket", "command", "object_ref", "pokemon_entity_serial",
    }
)
_RESOLUTION_REASONS: Final = frozenset(
    {
        "policy_selection_accepted", "window_fallback_only", "invalid_policy_output",
        "policy_exception", "policy_timeout", "policy_unavailable",
    }
)


class StrategicContractError(ValueError):
    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def _upper_sha(value: Any) -> bool:
    return type(value) is str and len(value) == 64 and value == value.upper() and all(c in "0123456789ABCDEF" for c in value)


def _domain_hash(prefix: bytes, payload: dict[str, Any]) -> str:
    return _sha(prefix + jcs_canonical_json_bytes(payload))


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


def _contains_private_key(value: Any) -> bool:
    if type(value) is dict:
        return any(type(key) is not str or key in _PRIVATE_KEYS or _contains_private_key(child) for key, child in value.items())
    if type(value) is list:
        return any(_contains_private_key(child) for child in value)
    return False


@dataclass(frozen=True, slots=True)
class _StrategicContracts:
    root: Path
    profile: Mapping[str, Any]


def _load_contracts(contract_root: Path | None = None) -> _StrategicContracts:
    root = contract_root or Path(__file__).resolve().parents[3] / "contracts" / "ptcgdap"
    try:
        bundle_path = root / "strategic_context_v18_bundle.json"
        raw = bundle_path.read_bytes()
        if len(raw) > MAX_CONTRACT_BYTES:
            raise StrategicContractError("contract_error")
        bundle = load_json_bytes_strict(raw)
        if _sha(canonical_json_v1_bytes(bundle)) != EXPECTED_BUNDLE_SHA256:
            raise StrategicContractError("contract_error")
        if type(bundle) is not dict or set(bundle) != {
            "schema_version", "contract_id", "source_lock_canonical_sha256",
            "public_firewall_bundle_canonical_sha256", "selection_contract_bundle_canonical_sha256",
            "artifacts", "runtime_authority",
        }:
            raise StrategicContractError("contract_error")
        if bundle["contract_id"] != "ptcgdap-strategic-public-contract-p4-wp1-v1":
            raise StrategicContractError("contract_error")
        entries = bundle["artifacts"]
        if type(entries) is not list or len(entries) != 3:
            raise StrategicContractError("contract_error")
        documents: dict[str, Any] = {}
        seen: set[str] = set()
        for entry in entries:
            if type(entry) is not dict or set(entry) != {"id", "path", "canonical_sha256"}:
                raise StrategicContractError("contract_error")
            artifact_id = entry["id"]
            if artifact_id in seen or artifact_id not in EXPECTED_ARTIFACTS:
                raise StrategicContractError("contract_error")
            name, expected_hash = EXPECTED_ARTIFACTS[artifact_id]
            if entry["path"] != f"contracts/ptcgdap/{name}" or entry["canonical_sha256"] != expected_hash:
                raise StrategicContractError("contract_error")
            data = (root / name).read_bytes()
            if len(data) > MAX_CONTRACT_BYTES:
                raise StrategicContractError("contract_error")
            value = load_json_bytes_strict(data)
            if _sha(canonical_json_v1_bytes(value)) != expected_hash:
                raise StrategicContractError("contract_error")
            documents[artifact_id] = value
            seen.add(artifact_id)
        if seen != set(EXPECTED_ARTIFACTS):
            raise StrategicContractError("contract_error")
        profile = documents["profile"]
        if type(profile) is not dict or profile.get("profile_id") != PROFILE_ID or profile.get("decision_profile_id") != DECISION_PROFILE_ID:
            raise StrategicContractError("contract_error")
        prefixes = profile.get("hash_profiles")
        if type(prefixes) is not dict:
            raise StrategicContractError("contract_error")
        if bytes.fromhex(prefixes["strategic_context_v18"]["prefix_utf8_hex"]) != CONTEXT_PREFIX:
            raise StrategicContractError("contract_error")
        if bytes.fromhex(prefixes["policy_decision_audit_v1"]["prefix_utf8_hex"]) != DECISION_PREFIX:
            raise StrategicContractError("contract_error")
        return _StrategicContracts(root, _freeze(copy.deepcopy(profile)))
    except StrategicContractError:
        raise
    except (OSError, ValueError, TypeError, KeyError, RecursionError) as exc:
        raise StrategicContractError("contract_error") from exc


def _context_payload(public: dict[str, Any], public_hash: str, provenance: list[dict[str, str]], window: CabtSelectionWindow) -> dict[str, Any]:
    current = public["current"]
    chooser = current["yourIndex"]
    opponent = 1 - chooser
    players = current["players"]
    fingerprints = list(window.option_fingerprints)
    payload = {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "source": {
            "public_observation_hash": public_hash,
            "window_id": window.window_id,
            "chooser_player_index": chooser,
            "option_fingerprint_profile": window.option_fingerprint_profile,
            "option_count": window.option_count,
        },
        "clocks": {
            "turn": current["turn"],
            "turn_action_count": current["turnActionCount"],
            "remaining_overage_time": public["remainingOverageTime"],
            "acting_prizes_remaining": len(players[chooser]["prize"]),
            "opponent_prizes_remaining": len(players[opponent]["prize"]),
            "acting_deck_count": players[chooser]["deckCount"],
            "opponent_deck_count": players[opponent]["deckCount"],
            "acting_hand_count": players[chooser]["handCount"],
            "opponent_hand_count": players[opponent]["handCount"],
        },
        "public_state": {
            "turn_flags": {
                "first_player": current["firstPlayer"],
                "result": current["result"],
                "supporter_played": current["supporterPlayed"],
                "stadium_played": current["stadiumPlayed"],
                "energy_attached": current["energyAttached"],
                "retreated": current["retreated"],
            },
            "stadium": copy.deepcopy(current["stadium"]),
            "acting_player": copy.deepcopy(players[chooser]),
            "opponent_player": copy.deepcopy(players[opponent]),
        },
        "select_semantics": {
            "select_type_raw": window.select_type_raw,
            "select_context_raw": window.select_context_raw,
            "min_count": window.min_count,
            "max_count": window.max_count,
            "remain_damage_counter": window.remain_damage_counter,
            "remain_energy_cost": window.remain_energy_cost,
            "context_card": window.context_card,
            "effect": window.effect,
            "options": [
                {"index": index, "fingerprint": fingerprints[index], "raw": copy.deepcopy(option)}
                for index, option in enumerate(window.options)
            ],
        },
        "opponent_public_belief": {"status": "unknown", "candidates": [], "public_evidence_ids": []},
        "public_event_delta": copy.deepcopy(public["logs"]),
        "provenance": {
            "firewall_contract_hash": "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947",
            "records": copy.deepcopy(provenance),
        },
        "authority": "strategic_context_public_audit",
        "authoritative": False,
    }
    return {**payload, "context_hash": _domain_hash(CONTEXT_PREFIX, payload)}


def _context_payload_valid(value: Any) -> bool:
    try:
        if type(value) is not dict or set(value) != _CONTEXT_KEYS or _contains_private_key(value):
            return False
        if value["schema_version"] != 1 or value["profile_id"] != PROFILE_ID or value["authority"] != "strategic_context_public_audit" or value["authoritative"] is not False:
            return False
        source = value["source"]
        state = value["public_state"]
        semantics = value["select_semantics"]
        if type(source) is not dict or not _upper_sha(source.get("public_observation_hash")) or not _upper_sha(source.get("window_id")):
            return False
        if type(source.get("chooser_player_index")) is not int or source["chooser_player_index"] not in (0, 1):
            return False
        if source.get("option_fingerprint_profile") != "cabt_option_fingerprint_v1":
            return False
        if type(state) is not dict or type(state.get("acting_player")) is not dict or type(state.get("opponent_player")) is not dict:
            return False
        if type(state["acting_player"].get("hand")) is not list or state["opponent_player"].get("hand") is not None:
            return False
        options = semantics.get("options") if type(semantics) is dict else None
        if type(options) is not list or type(source.get("option_count")) is not int or len(options) != source["option_count"]:
            return False
        for index, option in enumerate(options):
            if type(option) is not dict or set(option) != {"index", "fingerprint", "raw"} or option["index"] != index or not _upper_sha(option["fingerprint"]) or type(option["raw"]) is not dict:
                return False
        given = value["context_hash"]
        payload = {key: copy.deepcopy(child) for key, child in value.items() if key != "context_hash"}
        return _upper_sha(given) and _domain_hash(CONTEXT_PREFIX, payload) == given and len(jcs_canonical_json_bytes(value)) <= MAX_CONTEXT_BYTES
    except (CabtTreeHashError, KeyError, TypeError, ValueError, RecursionError):
        return False


@dataclass(frozen=True, slots=True, init=False)
class StrategicContextV18:
    _snapshot: Mapping[str, Any]
    _construction_seal: object
    _firewall_binding: PublicFirewallResult
    _window_binding: CabtSelectionWindow

    def __new__(cls) -> StrategicContextV18:
        raise TypeError("StrategicContextV18 is compiler-owned")

    @classmethod
    def _from_payload(
        cls,
        payload: dict[str, Any],
        firewall_result: PublicFirewallResult,
        window: CabtSelectionWindow,
        token: object,
    ) -> StrategicContextV18:
        if token is not _CONTEXT_TOKEN or not _context_payload_valid(payload):
            raise StrategicContractError("context_integrity_invalid")
        value = object.__new__(cls)
        object.__setattr__(value, "_snapshot", _freeze(copy.deepcopy(payload)))
        object.__setattr__(value, "_construction_seal", token)
        object.__setattr__(value, "_firewall_binding", firewall_result)
        object.__setattr__(value, "_window_binding", window)
        if not value.validate_integrity():
            raise StrategicContractError("context_integrity_invalid")
        return value

    @property
    def context_hash(self) -> str:
        return str(self._snapshot.get("context_hash", "")) if isinstance(self._snapshot, Mapping) else ""

    @property
    def window_id(self) -> str:
        source = self._snapshot.get("source", {}) if isinstance(self._snapshot, Mapping) else {}
        return str(source.get("window_id", "")) if isinstance(source, Mapping) else ""

    def validate_integrity(self) -> bool:
        try:
            if (
                type(self) is not StrategicContextV18
                or self._construction_seal is not _CONTEXT_TOKEN
                or type(self._firewall_binding) is not PublicFirewallResult
                or type(self._window_binding) is not CabtSelectionWindow
                or not isinstance(self._snapshot, Mapping)
                or not self._firewall_binding.validate_integrity(self._firewall_binding._bound_input)
                or not self._firewall_binding.accepted
                or _require_current_window(self._window_binding) is not self._window_binding
            ):
                return False
            public = self._firewall_binding.public_observation
            public_hash = self._firewall_binding.public_observation_hash
            if type(public) is not dict or type(public_hash) is not str:
                return False
            expected = _context_payload(
                public,
                public_hash,
                self._firewall_binding.provenance,
                self._window_binding,
            )
            return _context_payload_valid(expected) and _thaw(self._snapshot) == expected
        except (AttributeError, CabtTreeHashError, KeyError, TypeError, ValueError, RecursionError):
            return False

    def to_public_dict(self) -> dict[str, Any]:
        if not self.validate_integrity():
            raise StrategicContractError("context_integrity_invalid")
        return _thaw(self._snapshot)


@dataclass(frozen=True, slots=True)
class StrategicContextBuildResult:
    accepted: bool
    error_code: str
    context: StrategicContextV18 | None


class StrategicContextCompiler:
    __slots__ = ()

    @staticmethod
    def build(firewall_result: Any, window: Any, *, contract_root: Path | None = None) -> StrategicContextBuildResult:
        try:
            _load_contracts(contract_root)
        except StrategicContractError:
            return StrategicContextBuildResult(False, "contract_error", None)
        if type(firewall_result) is not PublicFirewallResult:
            return StrategicContextBuildResult(False, "invalid_firewall_result", None)
        try:
            bound = firewall_result._bound_input
            if not firewall_result.validate_integrity(bound):
                return StrategicContextBuildResult(False, "invalid_firewall_result", None)
            if not firewall_result.accepted:
                return StrategicContextBuildResult(False, "firewall_not_accepted", None)
            public = firewall_result.public_observation
            if type(public) is not dict:
                return StrategicContextBuildResult(False, "firewall_not_accepted", None)
            if public.get("select") is None or public.get("current") is None:
                return StrategicContextBuildResult(False, "unsupported_initial_window", None)
            try:
                current_window = _require_current_window(window)
            except (AttributeError, TypeError, ValueError):
                return StrategicContextBuildResult(False, "invalid_window", None)
            public_hash = firewall_result.public_observation_hash
            if current_window.public_hash_authority != PUBLIC_HASH_AUTHORITY or current_window.public_observation_hash != public_hash:
                return StrategicContextBuildResult(False, "source_hash_mismatch", None)
            current = public.get("current")
            if type(current) is not dict or current_window.chooser_player_index != current.get("yourIndex"):
                return StrategicContextBuildResult(False, "chooser_mismatch", None)
            if current_window.select_payload != public.get("select"):
                return StrategicContextBuildResult(False, "select_mismatch", None)
            payload = _context_payload(public, public_hash, firewall_result.provenance, current_window)
            return StrategicContextBuildResult(
                True,
                "",
                StrategicContextV18._from_payload(
                    payload,
                    firewall_result,
                    current_window,
                    _CONTEXT_TOKEN,
                ),
            )
        except (AttributeError, CabtTreeHashError, KeyError, TypeError, ValueError, RecursionError):
            return StrategicContextBuildResult(False, "invalid_firewall_result", None)


def _decision_payload(
    context: StrategicContextV18,
    window: CabtSelectionWindow,
    resolution: CabtSelectionResolution,
    policy_hash: str,
    scene_id: str,
    decision_id: str,
    determinism_key: str,
) -> dict[str, Any]:
    indexes = list(resolution.selected_indexes)
    fingerprints = list(window.option_fingerprints)
    owner_layer = "base_graph" if resolution.owner == "policy" else "base_fallback"
    fallback_tier = "none" if resolution.owner == "policy" else "same_public_window_deterministic"
    payload = {
        "schema_version": 1,
        "profile_id": DECISION_PROFILE_ID,
        "selected_indexes": indexes,
        "selected_semantic_intent": {
            "kind": "current_option_fingerprints",
            "options": [{"index": index, "fingerprint": fingerprints[index]} for index in indexes],
        },
        "owner_layer": owner_layer,
        "reason_code": resolution.reason_code,
        "fallback_tier": fallback_tier,
        "context_hash": context.context_hash,
        "policy_hash": policy_hash,
        "window_id": window.window_id,
        "public_observation_hash": window.public_observation_hash,
        "scene_id": scene_id,
        "decision_id": decision_id,
        "determinism_key": determinism_key,
        "authority": "policy_decision_public_audit",
        "authoritative": False,
    }
    return {**payload, "audit_id": _domain_hash(DECISION_PREFIX, payload)}


def _identifier(value: Any) -> bool:
    return type(value) is str and bool(value) and len(value.encode("utf-8")) <= 128


@dataclass(frozen=True, slots=True, init=False)
class PolicyDecision:
    _snapshot: Mapping[str, Any]
    _construction_seal: object
    _context_binding: StrategicContextV18
    _window_binding: CabtSelectionWindow
    _resolution_binding: CabtSelectionResolution

    def __new__(cls) -> PolicyDecision:
        raise TypeError("PolicyDecision is factory-owned")

    @classmethod
    def _from_owner(
        cls,
        payload: dict[str, Any],
        context: StrategicContextV18,
        window: CabtSelectionWindow,
        resolution: CabtSelectionResolution,
        token: object,
    ) -> PolicyDecision:
        if token is not _DECISION_TOKEN:
            raise StrategicContractError("decision_integrity_invalid")
        value = object.__new__(cls)
        object.__setattr__(value, "_snapshot", _freeze(copy.deepcopy(payload)))
        object.__setattr__(value, "_construction_seal", token)
        object.__setattr__(value, "_context_binding", context)
        object.__setattr__(value, "_window_binding", window)
        object.__setattr__(value, "_resolution_binding", resolution)
        if not value.validate_integrity(context, window, resolution):
            raise StrategicContractError("decision_integrity_invalid")
        return value

    @property
    def selected_indexes(self) -> tuple[int, ...]:
        value = self._snapshot.get("selected_indexes", ()) if isinstance(self._snapshot, Mapping) else ()
        return tuple(value) if type(value) is tuple else ()

    @property
    def audit_id(self) -> str:
        return str(self._snapshot.get("audit_id", "")) if isinstance(self._snapshot, Mapping) else ""

    def validate_integrity(self, context: StrategicContextV18, window: CabtSelectionWindow, resolution: CabtSelectionResolution) -> bool:
        try:
            current = _require_current_window(window)
            if (
                type(self) is not PolicyDecision
                or self._construction_seal is not _DECISION_TOKEN
                or context is not self._context_binding
                or current is not self._window_binding
                or resolution is not self._resolution_binding
                or not context.validate_integrity()
                or not resolution.validate_integrity(current)
                or context.window_id != current.window_id
                or not isinstance(self._snapshot, Mapping)
            ):
                return False
            public = _thaw(self._snapshot)
            if type(public) is not dict or set(public) != _DECISION_KEYS or _contains_private_key(public):
                return False
            if public["schema_version"] != 1 or public["profile_id"] != DECISION_PROFILE_ID or public["authority"] != "policy_decision_public_audit" or public["authoritative"] is not False:
                return False
            if not _upper_sha(public["policy_hash"]) or not _identifier(public["scene_id"]) or not _identifier(public["decision_id"]) or not _identifier(public["determinism_key"]):
                return False
            expected = _decision_payload(context, current, resolution, public["policy_hash"], public["scene_id"], public["decision_id"], public["determinism_key"])
            return public == expected
        except (AttributeError, CabtTreeHashError, KeyError, TypeError, ValueError, RecursionError):
            return False

    def to_public_dict(self) -> dict[str, Any]:
        if not self.validate_integrity(self._context_binding, self._window_binding, self._resolution_binding):
            raise StrategicContractError("decision_integrity_invalid")
        return _thaw(self._snapshot)

    def agent_output(self) -> list[int]:
        return list(self.selected_indexes) if self.validate_integrity(self._context_binding, self._window_binding, self._resolution_binding) else []


@dataclass(frozen=True, slots=True)
class PolicyDecisionBuildResult:
    accepted: bool
    error_code: str
    decision: PolicyDecision | None


class PolicyDecisionFactory:
    __slots__ = ()

    @staticmethod
    def build(
        context: Any,
        window: Any,
        resolution: Any,
        *,
        policy_hash: Any,
        scene_id: Any,
        decision_id: Any,
        determinism_key: Any,
        contract_root: Path | None = None,
    ) -> PolicyDecisionBuildResult:
        try:
            _load_contracts(contract_root)
        except StrategicContractError:
            return PolicyDecisionBuildResult(False, "contract_error", None)
        if type(context) is not StrategicContextV18 or not context.validate_integrity():
            return PolicyDecisionBuildResult(False, "invalid_context", None)
        try:
            current = _require_current_window(window)
        except (AttributeError, TypeError, ValueError):
            return PolicyDecisionBuildResult(False, "invalid_context", None)
        if context.window_id != current.window_id or context.to_public_dict()["source"]["public_observation_hash"] != current.public_observation_hash:
            return PolicyDecisionBuildResult(False, "invalid_context", None)
        if type(resolution) is not CabtSelectionResolution or not resolution.validate_integrity(current):
            return PolicyDecisionBuildResult(False, "invalid_resolution", None)
        if resolution.owner not in ("policy", "deterministic_fallback") or resolution.reason_code not in _RESOLUTION_REASONS:
            return PolicyDecisionBuildResult(False, "invalid_resolution", None)
        if not _upper_sha(policy_hash):
            return PolicyDecisionBuildResult(False, "invalid_policy_hash", None)
        if not all(_identifier(value) for value in (scene_id, decision_id, determinism_key)):
            return PolicyDecisionBuildResult(False, "invalid_decision_identity", None)
        try:
            payload = _decision_payload(context, current, resolution, policy_hash, scene_id, decision_id, determinism_key)
            decision = PolicyDecision._from_owner(payload, context, current, resolution, _DECISION_TOKEN)
            return PolicyDecisionBuildResult(True, "", decision)
        except (StrategicContractError, CabtTreeHashError, KeyError, TypeError, ValueError, RecursionError):
            return PolicyDecisionBuildResult(False, "decision_integrity_invalid", None)


__all__ = [
    "DECISION_PROFILE_ID",
    "EXPECTED_BUNDLE_SHA256",
    "PROFILE_ID",
    "PolicyDecision",
    "PolicyDecisionBuildResult",
    "PolicyDecisionFactory",
    "StrategicContextBuildResult",
    "StrategicContextCompiler",
    "StrategicContextV18",
    "StrategicContractError",
]
