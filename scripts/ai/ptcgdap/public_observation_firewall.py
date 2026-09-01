from __future__ import annotations

import copy
from pathlib import Path
from typing import Any

from .cabt_envelope import EnvelopeParseResult, RawCabtEnvelope, parse_raw_cabt_envelope
from .cabt_tree_hash import CabtTreeHashError, public_observation_hash
from .source_lock import (
    canonical_json_v1_bytes,
    load_json_bytes_strict,
    sha256_bytes,
)


SCHEMA_VERSION = 1
PROFILE_ID = "cabt_public_firewall_profile_v1"
EXPECTED_FIREWALL_BUNDLE_SHA256 = "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947"
EXPECTED_PROFILE_SHA256 = "AA287117DF497ED51DCA19FA36DC6212E3AAC0E9A1D2B871BA6130B6E963332A"
EXPECTED_SOURCE_CONTRACT_SHA256 = "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
MAX_CONTRACT_BYTES = 2 * 1024 * 1024

_EXPECTED_ARTIFACTS = {
    "cabt_public_observation_schema_v1": "contracts/ptcgdap/cabt_public_observation.schema.json",
    PROFILE_ID: "contracts/ptcgdap/cabt_public_firewall_profile.json",
    "cabt_public_firewall_conformance_v1": "contracts/ptcgdap/cabt_public_firewall_conformance_vectors.json",
}
_CONSTRUCTION_TOKEN = object()


class PublicFirewallError(ValueError):
    def __init__(self, code: str) -> None:
        self.code = code
        super().__init__(code)


def _canonical_hash(value: Any) -> str:
    return sha256_bytes(canonical_json_v1_bytes(value))


def _read_contract(path: Path) -> Any:
    data = path.read_bytes()
    if len(data) > MAX_CONTRACT_BYTES:
        raise PublicFirewallError("firewall_contract_error")
    try:
        return load_json_bytes_strict(data)
    except (UnicodeError, ValueError, TypeError, RecursionError) as exc:
        raise PublicFirewallError("firewall_contract_error") from exc


class _FirewallContracts:
    __slots__ = ("_profile", "_contract_root", "_seal")

    def __init__(self, token: object, profile: dict[str, Any], contract_root: Path) -> None:
        if token is not _CONSTRUCTION_TOKEN:
            raise PublicFirewallError("firewall_contract_error")
        self._profile = copy.deepcopy(profile)
        self._contract_root = contract_root.resolve()
        self._seal = EXPECTED_FIREWALL_BUNDLE_SHA256

    @property
    def profile(self) -> dict[str, Any]:
        return copy.deepcopy(self._profile)

    @property
    def contract_root(self) -> Path:
        return self._contract_root

    @property
    def bundle_hash(self) -> str:
        return EXPECTED_FIREWALL_BUNDLE_SHA256

    def integrity_valid(self) -> bool:
        try:
            return (
                type(self._profile) is dict
                and isinstance(self._contract_root, Path)
                and type(self._seal) is str
                and self._seal == EXPECTED_FIREWALL_BUNDLE_SHA256
                and _canonical_hash(self._profile) == EXPECTED_PROFILE_SHA256
                and self._profile.get("profile_id") == PROFILE_ID
                and self._profile.get("parent_contract", {}).get("canonical_sha256")
                == EXPECTED_SOURCE_CONTRACT_SHA256
            )
        except Exception:
            return False


def _load_contracts(contract_root: Path) -> _FirewallContracts:
    root = contract_root.resolve()
    bundle_path = root / "cabt_public_firewall_bundle.json"
    try:
        bundle = _read_contract(bundle_path)
        if type(bundle) is not dict or _canonical_hash(bundle) != EXPECTED_FIREWALL_BUNDLE_SHA256:
            raise PublicFirewallError("firewall_contract_error")
        if bundle.get("bundle_id") != "ptcgdap-public-firewall-p2-wp3-v1":
            raise PublicFirewallError("firewall_contract_error")
        parent = bundle.get("parent_contract")
        if type(parent) is not dict or parent != {
            "id": "ptcgdap-cabt-contract-p1-wp3-v1",
            "path": "contracts/ptcgdap/cabt_contract_bundle.json",
            "canonical_sha256": EXPECTED_SOURCE_CONTRACT_SHA256,
        }:
            raise PublicFirewallError("firewall_contract_error")
        parent_value = _read_contract(root / "cabt_contract_bundle.json")
        if _canonical_hash(parent_value) != EXPECTED_SOURCE_CONTRACT_SHA256:
            raise PublicFirewallError("firewall_contract_error")

        artifacts = bundle.get("artifacts")
        if type(artifacts) is not list or len(artifacts) != len(_EXPECTED_ARTIFACTS):
            raise PublicFirewallError("firewall_contract_error")
        loaded: dict[str, Any] = {}
        seen_paths: set[str] = set()
        for entry in artifacts:
            if type(entry) is not dict or set(entry) != {"id", "path", "canonical_sha256"}:
                raise PublicFirewallError("firewall_contract_error")
            artifact_id = entry.get("id")
            relative_path = entry.get("path")
            expected_path = _EXPECTED_ARTIFACTS.get(artifact_id)
            if type(artifact_id) is not str or type(relative_path) is not str or relative_path != expected_path:
                raise PublicFirewallError("firewall_contract_error")
            if relative_path in seen_paths:
                raise PublicFirewallError("firewall_contract_error")
            seen_paths.add(relative_path)
            path = root / Path(relative_path).name
            value = _read_contract(path)
            if type(entry.get("canonical_sha256")) is not str or _canonical_hash(value) != entry["canonical_sha256"]:
                raise PublicFirewallError("firewall_contract_error")
            loaded[artifact_id] = value
        if set(loaded) != set(_EXPECTED_ARTIFACTS):
            raise PublicFirewallError("firewall_contract_error")
        profile = loaded.get(PROFILE_ID)
        if type(profile) is not dict or _canonical_hash(profile) != EXPECTED_PROFILE_SHA256:
            raise PublicFirewallError("firewall_contract_error")
        return _FirewallContracts(_CONSTRUCTION_TOKEN, profile, root)
    except PublicFirewallError:
        raise
    except (OSError, ValueError, TypeError, KeyError, RecursionError) as exc:
        raise PublicFirewallError("firewall_contract_error") from exc


class PublicFirewallResult:
    __slots__ = (
        "_status",
        "_public_observation",
        "_public_observation_hash",
        "_provenance",
        "_issues",
        "_source_contract_hash",
        "_firewall_contract_hash",
        "_bound_input",
        "_owner",
        "_snapshot",
    )

    def __init__(
        self,
        token: object,
        *,
        owner: PublicObservationFirewall,
        bound_input: object,
        evaluation: dict[str, Any],
    ) -> None:
        if token is not _CONSTRUCTION_TOKEN:
            raise PublicFirewallError("result_integrity_invalid")
        self._status = evaluation["status"]
        self._public_observation = copy.deepcopy(evaluation["public_observation"])
        self._public_observation_hash = evaluation["public_observation_hash"]
        self._provenance = copy.deepcopy(evaluation["provenance"])
        self._issues = copy.deepcopy(evaluation["issues"])
        self._source_contract_hash = EXPECTED_SOURCE_CONTRACT_SHA256
        self._firewall_contract_hash = EXPECTED_FIREWALL_BUNDLE_SHA256
        self._bound_input = bound_input
        self._owner = owner
        self._snapshot = copy.deepcopy(self._serialize_unchecked())

    @property
    def status(self) -> str:
        return self._status

    @property
    def accepted(self) -> bool:
        return self._status == "accepted"

    @property
    def public_observation(self) -> dict[str, Any] | None:
        return copy.deepcopy(self._public_observation)

    @property
    def public_observation_hash(self) -> str | None:
        return self._public_observation_hash

    @property
    def provenance(self) -> list[dict[str, str]]:
        return copy.deepcopy(self._provenance)

    @property
    def issues(self) -> list[dict[str, str]]:
        return copy.deepcopy(self._issues)

    def _serialize_unchecked(self) -> dict[str, Any]:
        return {
            "schema_version": SCHEMA_VERSION,
            "profile_id": PROFILE_ID,
            "source_contract_hash": self._source_contract_hash,
            "firewall_contract_hash": self._firewall_contract_hash,
            "status": self._status,
            "public_observation": copy.deepcopy(self._public_observation),
            "public_observation_hash": self._public_observation_hash,
            "provenance": copy.deepcopy(self._provenance),
            "issues": copy.deepcopy(self._issues),
        }

    def _basic_integrity(self) -> bool:
        try:
            if type(self._owner) is not PublicObservationFirewall or not self._owner._integrity_valid():
                return False
            if type(self._snapshot) is not dict or self._snapshot != self._serialize_unchecked():
                return False
            if self._status == "accepted":
                return (
                    type(self._public_observation) is dict
                    and type(self._public_observation_hash) is str
                    and type(self._provenance) is list
                    and bool(self._provenance)
                    and type(self._issues) is list
                    and not self._issues
                )
            return (
                self._status == "rejected"
                and self._public_observation is None
                and self._public_observation_hash is None
                and type(self._provenance) is list
                and not self._provenance
                and type(self._issues) is list
                and bool(self._issues)
            )
        except Exception:
            return False

    def validate_integrity(self, current_input: object) -> bool:
        if not self._basic_integrity() or current_input is not self._bound_input:
            return False
        try:
            return self._owner._evaluate(current_input) == self._snapshot
        except Exception:
            return False

    def to_public_dict(self) -> dict[str, Any]:
        if not self.validate_integrity(self._bound_input):
            raise PublicFirewallError("result_integrity_invalid")
        return copy.deepcopy(self._snapshot)


class PublicObservationFirewall:
    __slots__ = ("_contracts", "_seal")

    def __init__(self, token: object, contracts: _FirewallContracts) -> None:
        if token is not _CONSTRUCTION_TOKEN or type(contracts) is not _FirewallContracts:
            raise PublicFirewallError("firewall_contract_error")
        self._contracts = contracts
        self._seal = EXPECTED_FIREWALL_BUNDLE_SHA256

    @classmethod
    def load_default(cls) -> PublicObservationFirewall:
        root = Path(__file__).resolve().parents[3] / "contracts" / "ptcgdap"
        return cls.load_from_root(root)

    @classmethod
    def load_from_root(cls, contract_root: str | Path) -> PublicObservationFirewall:
        if type(contract_root) is not str and not isinstance(contract_root, Path):
            raise PublicFirewallError("firewall_contract_error")
        contracts = _load_contracts(Path(contract_root))
        return cls(_CONSTRUCTION_TOKEN, contracts)

    @property
    def contract_hash(self) -> str:
        return EXPECTED_FIREWALL_BUNDLE_SHA256

    def _integrity_valid(self) -> bool:
        try:
            return (
                type(self._contracts) is _FirewallContracts
                and self._contracts.integrity_valid()
                and self._seal == EXPECTED_FIREWALL_BUNDLE_SHA256
            )
        except Exception:
            return False

    def project(self, parse_result: object) -> PublicFirewallResult:
        evaluation = self._evaluate(parse_result)
        return PublicFirewallResult(
            _CONSTRUCTION_TOKEN,
            owner=self,
            bound_input=parse_result,
            evaluation=evaluation,
        )

    def _replayed_envelope(self, parse_result: EnvelopeParseResult) -> tuple[EnvelopeParseResult, RawCabtEnvelope] | None:
        envelope = parse_result.envelope
        if type(envelope) is not RawCabtEnvelope:
            return None
        replayed = parse_raw_cabt_envelope(
            envelope.raw_payload,
            contract_root=self._contracts.contract_root,
        )
        if type(replayed.envelope) is not RawCabtEnvelope:
            return None
        if replayed.envelope.to_host_dict() != envelope.to_host_dict():
            return None
        if replayed.safe_diagnostics() != parse_result.safe_diagnostics():
            return None
        if replayed.policy_eligible != parse_result.policy_eligible:
            return None
        return replayed, replayed.envelope

    def _evaluate(self, parse_result: object) -> dict[str, Any]:
        return self._evaluate_scoped(parse_result, allow_setup_bench_concealment=False)

    def _evaluate_setup_bench_concealment(self, parse_result: object) -> dict[str, Any]:
        """P5 overlay hook; returns data only and does not create base-contract authority."""

        evaluation = self._evaluate_scoped(parse_result, allow_setup_bench_concealment=True)
        if evaluation.get("status") != "accepted":
            return evaluation
        result = copy.deepcopy(evaluation)
        result["compatibility_rule"] = (
            "setup_bench_concealment_v1"
            if self._setup_bench_concealment_applies(parse_result)
            else None
        )
        return result

    def _setup_bench_concealment_applies(self, parse_result: object) -> bool:
        if type(parse_result) is not EnvelopeParseResult:
            return False
        replayed = self._replayed_envelope(parse_result)
        if replayed is None:
            return False
        known = replayed[1].known_view
        select = known.get("select") if type(known) is dict else None
        current = known.get("current") if type(known) is dict else None
        if type(select) is not dict or type(current) is not dict:
            return False
        acting = current.get("yourIndex")
        players = current.get("players")
        if type(acting) is not int or acting not in (0, 1) or type(players) is not list or len(players) != 2:
            return False
        own = players[acting]
        opponent = players[1 - acting]
        if type(own) is not dict or type(opponent) is not dict:
            return False
        active = own.get("active")
        return type(active) is list and _is_exact_setup_bench_concealment(
            select, current, own, opponent, active
        )

    def _evaluate_scoped(
        self,
        parse_result: object,
        *,
        allow_setup_bench_concealment: bool,
    ) -> dict[str, Any]:
        if not self._integrity_valid():
            return self._rejected("firewall_contract_error", "")
        if type(parse_result) is not EnvelopeParseResult:
            return self._rejected("invalid_envelope", "")
        envelope = parse_result.envelope
        if envelope is None:
            return self._rejected("envelope_not_policy_eligible", "")
        if type(envelope) is not RawCabtEnvelope:
            return self._rejected("invalid_envelope", "")
        if envelope.source_contract_hash != EXPECTED_SOURCE_CONTRACT_SHA256:
            return self._rejected("source_contract_mismatch", "")
        replayed = self._replayed_envelope(parse_result)
        if replayed is None:
            return self._rejected("invalid_envelope", "")
        replayed_result, trusted_envelope = replayed
        if not replayed_result.policy_eligible:
            return self._rejected("envelope_not_policy_eligible", "")

        known = trusted_envelope.known_view
        if set(known) != {"select", "logs", "current"}:
            return self._rejected("invalid_envelope", "")
        select = known["select"]
        logs = known["logs"]
        current = known["current"]
        if select is None:
            if current is not None or type(logs) is not list or logs:
                return self._rejected("initial_shape_mismatch", "/select")
            acting_index: int | None = None
        else:
            if type(current) is not dict:
                return self._rejected("initial_shape_mismatch", "/current")
            acting = current.get("yourIndex")
            if type(acting) is not int or acting not in (0, 1):
                return self._rejected("invalid_your_index", "/current/yourIndex")
            acting_index = acting
            players = current.get("players")
            if type(players) is not list or len(players) != 2 or any(type(player) is not dict for player in players):
                return self._rejected("invalid_player_count", "/current/players")
            own = players[acting_index]
            opponent_index = 1 - acting_index
            opponent = players[opponent_index]
            if type(own.get("hand")) is not list:
                return self._rejected("own_hand_not_visible", f"/current/players/{acting_index}/hand")
            if opponent.get("hand") is not None:
                return self._rejected("opponent_hand_exposed", f"/current/players/{opponent_index}/hand")
            for player_index, player in enumerate(players):
                prize = player.get("prize")
                if type(prize) is not list or any(card is not None for card in prize):
                    return self._rejected("prize_identity_exposed", f"/current/players/{player_index}/prize")
            active = own.get("active")
            if type(active) is not list:
                return self._rejected("own_active_concealed", f"/current/players/{acting_index}/active")
            if type(select) is not dict:
                return self._rejected("initial_shape_mismatch", "/select")
            if any(card is None for card in active) and not (
                allow_setup_bench_concealment
                and _is_exact_setup_bench_concealment(select, current, own, opponent, active)
            ):
                return self._rejected("own_active_concealed", f"/current/players/{acting_index}/active")
            if select.get("deck") is not None and select.get("type") != 1:
                return self._rejected("unauthorized_select_deck", "/select/deck")
            if type(logs) is not list:
                return self._rejected("invalid_envelope", "/logs")
            for index, log in enumerate(logs):
                if (
                    type(log) is dict
                    and log.get("type") == 4
                    and log.get("playerIndex") != acting_index
                ):
                    return self._rejected("opponent_draw_identity_exposed", f"/logs/{index}")

        public_tree: dict[str, Any] = {
            "select": copy.deepcopy(select),
            "logs": copy.deepcopy(logs),
            "current": copy.deepcopy(current),
        }
        presence = trusted_envelope.field_presence
        framework = trusted_envelope.framework
        if presence.get("/step") != "missing":
            public_tree["step"] = copy.deepcopy(framework.get("step"))
        if presence.get("/remainingOverageTime") != "missing":
            public_tree["remainingOverageTime"] = copy.deepcopy(framework.get("remaining_overage_time"))

        try:
            provenance = self._provenance(public_tree, acting_index)
            digest = public_observation_hash(public_tree)
        except PublicFirewallError as exc:
            return self._rejected(exc.code, "")
        except (CabtTreeHashError, ValueError, TypeError, RecursionError, MemoryError):
            return self._rejected("public_hash_error", "")
        return {
            "schema_version": SCHEMA_VERSION,
            "profile_id": PROFILE_ID,
            "source_contract_hash": EXPECTED_SOURCE_CONTRACT_SHA256,
            "firewall_contract_hash": EXPECTED_FIREWALL_BUNDLE_SHA256,
            "status": "accepted",
            "public_observation": public_tree,
            "public_observation_hash": digest,
            "provenance": provenance,
            "issues": [],
        }

    def _provenance(self, public_tree: dict[str, Any], acting_index: int | None) -> list[dict[str, str]]:
        profile = self._contracts.profile
        limits = profile.get("limits", {})
        max_records = limits.get("max_provenance_records")
        max_depth = limits.get("max_public_tree_depth")
        max_nodes = limits.get("max_public_tree_nodes")
        if (
            type(max_records) is not int
            or type(max_depth) is not int
            or type(max_nodes) is not int
            or max_records < 1
            or max_depth < 0
            or max_nodes < 1
        ):
            raise PublicFirewallError("firewall_contract_error")
        records: list[dict[str, str]] = []
        stack: list[tuple[str, Any, int]] = [("", public_tree, 0)]
        while stack:
            pointer, value, depth = stack.pop()
            if (
                depth > max_depth
                or len(records) >= max_records
                or len(records) >= max_nodes
            ):
                raise PublicFirewallError("public_projection_limit")
            records.append(
                {
                    "output_pointer": pointer,
                    "source_pointer": pointer,
                    "visibility": _visibility_for(pointer, value, acting_index),
                    "authority": "official_cabt_wire",
                    "transform": "framework_name_restore" if pointer == "/remainingOverageTime" else "exact_copy",
                }
            )
            if type(value) is dict:
                children = list(value.items())
                for key, child in reversed(children):
                    if type(key) is not str:
                        raise PublicFirewallError("public_hash_error")
                    stack.append((_join_pointer(pointer, key), child, depth + 1))
            elif type(value) is list:
                for index in range(len(value) - 1, -1, -1):
                    stack.append((_join_pointer(pointer, str(index)), value[index], depth + 1))
        return records

    @staticmethod
    def _rejected(code: str, pointer: str) -> dict[str, Any]:
        return {
            "schema_version": SCHEMA_VERSION,
            "profile_id": PROFILE_ID,
            "source_contract_hash": EXPECTED_SOURCE_CONTRACT_SHA256,
            "firewall_contract_hash": EXPECTED_FIREWALL_BUNDLE_SHA256,
            "status": "rejected",
            "public_observation": None,
            "public_observation_hash": None,
            "provenance": [],
            "issues": [{"code": code, "pointer": pointer, "severity": "error"}],
        }


def _join_pointer(parent: str, segment: str) -> str:
    escaped = segment.replace("~", "~0").replace("/", "~1")
    return f"{parent}/{escaped}"


def _is_exact_setup_bench_concealment(
    select: dict[str, Any],
    current: dict[str, Any],
    own: dict[str, Any],
    opponent: dict[str, Any],
    active: list[Any],
) -> bool:
    """Recognize only the official turn-zero setup-bench concealment shape."""

    opponent_active = opponent.get("active")
    options = select.get("option")
    expected_select_keys = {
        "type", "context", "minCount", "maxCount", "remainDamageCounter",
        "remainEnergyCost", "option", "deck", "contextCard", "effect",
    }
    return (
        set(select) == expected_select_keys
        and active == [None]
        and type(opponent_active) is list
        and opponent_active == [None]
        and type(select.get("type")) is int
        and select.get("type") == 1
        and type(select.get("context")) is int
        and select.get("context") == 2
        and type(select.get("minCount")) is int
        and select.get("minCount") == 0
        and type(select.get("maxCount")) is int
        and type(options) is list
        and 0 <= select.get("maxCount") <= len(options)
        and type(select.get("remainDamageCounter")) is int
        and select.get("remainDamageCounter") == 0
        and type(select.get("remainEnergyCost")) is int
        and select.get("remainEnergyCost") == 0
        and select.get("deck") is None
        and select.get("contextCard") is None
        and select.get("effect") is None
        and type(current.get("turn")) is int
        and current.get("turn") == 0
        and type(current.get("result")) is int
        and current.get("result") == -1
        and type(own.get("bench")) is list
        and type(opponent.get("bench")) is list
    )


def _visibility_for(pointer: str, value: Any, acting_index: int | None) -> str:
    segments = pointer.split("/")[1:] if pointer else []
    if segments and segments[0] in ("step", "remainingOverageTime"):
        return "framework_public"
    if len(segments) >= 2 and segments[:2] == ["select", "deck"]:
        return "authorized_window_visible"
    if len(segments) >= 2 and segments[:2] == ["current", "looking"]:
        return "concealed_placeholder" if value is None else "acting_player_visible"
    if len(segments) >= 4 and segments[:2] == ["current", "players"]:
        try:
            player_index = int(segments[2])
        except ValueError:
            player_index = -1
        field = segments[3]
        if field == "hand":
            return "acting_player_visible" if player_index == acting_index else "concealed_placeholder"
        if field == "prize":
            return "concealed_placeholder"
        if field == "active" and value is None:
            return "concealed_placeholder"
    return "official_public"


__all__ = [
    "EXPECTED_FIREWALL_BUNDLE_SHA256",
    "PublicFirewallError",
    "PublicFirewallResult",
    "PublicObservationFirewall",
]
