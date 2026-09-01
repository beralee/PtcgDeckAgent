from __future__ import annotations

import copy
from dataclasses import dataclass
import hashlib
from pathlib import Path
import re
from types import MappingProxyType
from typing import Any, Final, Mapping

from .source_lock import canonical_json_v1_bytes, load_json_strict


PROFILE_ID: Final = "ptcgdap-dragapult-python-public-strategy-v1"
STRATEGY_ID: Final = "ptcgdap.dragapult.18.0.python-public-v1"
CARD_ID_DOMAIN: Final = "godot_local_card_uid_v1"
EXPECTED_BUNDLE_SHA256: Final = "49A117CDEF0F0E8D7BDACC1E11E8F09D7DCDACC4D59104D7523B2E7AF8EC2F98"
EXPECTED_ARTIFACTS: Final = MappingProxyType(
    {
        "schema": ("contracts/ptcgdap/dragapult_python_strategy.schema.json", "DA89A9E3BCCC19F0778BA1B2473A695CB6B57BD98F082446BDF8F9D07A460098"),
        "profile": ("contracts/ptcgdap/dragapult_python_strategy_profile.json", "BAD898A4847CD49477F2D2D8C2C67FF505C8423FD998541E36A3C5E8491FEEA3"),
        "vectors": ("contracts/ptcgdap/dragapult_python_strategy_conformance_vectors.json", "DF9FF21E0C773457669E82E788003DE827A6C7BBDCE2F285F9D06131F7EAF422"),
        "deck_manifest": ("data/ptcgdap/dragapult_python_strategy/deck_manifest_v1.json", "74D3C15E6A81D68F089B34673019CC455B73D06D2B26F02A1722BDB64C9C9EFA"),
        "policy": ("data/ptcgdap/dragapult_python_strategy/policy_v1.json", "BD2621352EEF3CDD0B4A68F1AA81CD10F1FADA7EF290704C1E46B6E2FF2C2AD6"),
        "opponent": ("data/ptcgdap/dragapult_python_strategy/rules_ai_opponent_v1.json", "93B518B0467D979BB3E72204F537669F56BC4D7826A99A26947E43EA8A9956C9"),
    }
)
DEFAULT_ROOT: Final = Path(__file__).resolve().parents[3]
_UID_RE = re.compile(r"^[A-Za-z0-9.]+_[A-Za-z0-9]+$")
_UPPER_SHA_RE = re.compile(r"^[0-9A-F]{64}$")
_SAFE_MAX: Final = 9_007_199_254_740_991
_FRAME_KEYS: Final = frozenset(
    {
        "schema_version",
        "profile_id",
        "strategy_id",
        "card_id_domain",
        "sequence",
        "seat",
        "prompt_kind",
        "source",
        "public_state",
        "select_semantics",
        "options",
    }
)
_OPTION_KEYS: Final = frozenset(
    {
        "index",
        "kind",
        "card_uid",
        "source_uid",
        "target_uid",
        "target_remaining_hp",
        "target_prize_value",
        "attached_energy_count",
        "attack_index",
        "tags",
    }
)
_PROMPT_KINDS: Final = frozenset(
    {
        "setup_active",
        "setup_bench",
        "main",
        "search",
        "evolve",
        "attach",
        "effect_target",
        "attack",
        "attack_target",
        "take_prize",
        "send_out",
        "terminal",
    }
)
_OPTION_KINDS: Final = frozenset(
    {
        "setup_active",
        "setup_bench",
        "play_basic_to_bench",
        "play_trainer",
        "play_stadium",
        "use_stadium_effect",
        "evolve",
        "attach_tool",
        "attach_energy",
        "use_ability",
        "retreat",
        "attack",
        "granted_attack",
        "end_turn",
        "search",
        "discard",
        "effect_target",
        "attack_target",
        "take_prize",
        "send_out",
        "end",
        "yes",
        "no",
    }
)
_TERMINAL_KINDS: Final = frozenset({"end", "end_turn", "yes", "no"})
_PUBLIC_STATE_KEYS: Final = frozenset({"turn_number", "phase", "self", "opponent"})
_SELF_KEYS: Final = frozenset({"hand", "active", "bench", "discard", "deck_count", "prizes_remaining"})
_OPPONENT_KEYS: Final = frozenset({"hand_count", "active", "bench", "discard", "deck_count", "prizes_remaining"})
_HIDDEN_MARKERS: Final = frozenset(
    {
        "private",
        "deck_order",
        "search_begin_input",
        "rng_state",
        "hidden_cards",
        "face_down_prizes",
        "raw_private_hash",
        "ticket",
        "command",
        "object_ref",
        "instance_id",
    }
)
_TOKEN = object()


class DragapultPublicStrategyError(ValueError):
    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _freeze(value: Any) -> Any:
    if type(value) is dict:
        return MappingProxyType({key: _freeze(child) for key, child in value.items()})
    if type(value) is list:
        return tuple(_freeze(child) for child in value)
    return value


def _thaw(value: Any) -> Any:
    if isinstance(value, MappingProxyType):
        return {key: _thaw(child) for key, child in value.items()}
    if type(value) is tuple:
        return [_thaw(child) for child in value]
    return value


def _exact_int(value: Any, minimum: int, maximum: int) -> bool:
    return type(value) is int and minimum <= value <= maximum


def _uid(value: Any) -> bool:
    return type(value) is str and len(value) <= 64 and _UID_RE.fullmatch(value) is not None


def _contains_hidden(value: Any) -> bool:
    if type(value) is str:
        lowered = value.lower()
        return "private" in lowered or lowered in _HIDDEN_MARKERS
    if type(value) is list:
        return any(_contains_hidden(child) for child in value)
    if type(value) is dict:
        return any(_contains_hidden(key) or _contains_hidden(child) for key, child in value.items())
    return False


@dataclass(frozen=True, slots=True)
class _Contracts:
    documents: Mapping[str, Any]
    allowed_uids: frozenset[str]
    own_uids: frozenset[str]
    opponent_uids: frozenset[str]


def _load_contracts(root: Path) -> _Contracts:
    try:
        bundle = load_json_strict(root / "contracts/ptcgdap/dragapult_python_strategy_bundle.json")
        if _sha(canonical_json_v1_bytes(bundle)) != EXPECTED_BUNDLE_SHA256:
            raise DragapultPublicStrategyError("contract_error")
        if type(bundle) is not dict or set(bundle) != {"schema_version", "bundle_id", "profile_id", "artifacts"}:
            raise DragapultPublicStrategyError("contract_error")
        if bundle["schema_version"] != 1 or bundle["profile_id"] != PROFILE_ID or bundle["bundle_id"] != "ptcgdap-dragapult-python-strategy-acceptance-v1":
            raise DragapultPublicStrategyError("contract_error")
        entries = bundle["artifacts"]
        if type(entries) is not list or len(entries) != len(EXPECTED_ARTIFACTS):
            raise DragapultPublicStrategyError("contract_error")
        documents: dict[str, Any] = {}
        for entry, (artifact_id, expected) in zip(entries, EXPECTED_ARTIFACTS.items(), strict=True):
            expected_path, expected_hash = expected
            if type(entry) is not dict or entry != {"id": artifact_id, "path": expected_path, "canonical_sha256": expected_hash}:
                raise DragapultPublicStrategyError("contract_error")
            document = load_json_strict(root / expected_path)
            if _sha(canonical_json_v1_bytes(document)) != expected_hash:
                raise DragapultPublicStrategyError("contract_error")
            documents[artifact_id] = document

        profile = documents["profile"]
        deck = documents["deck_manifest"]
        policy = documents["policy"]
        opponent = documents["opponent"]
        if (
            profile.get("profile_id") != PROFILE_ID
            or profile.get("strategy_id") != STRATEGY_ID
            or profile.get("public_boundary") != "agent(public_frame) -> list[int]"
            or profile.get("card_id_domain") != CARD_ID_DOMAIN
            or profile.get("deck_identity_merge_with_official_cabt") is not False
            or profile.get("cabt_exportable") is not False
            or profile.get("development_python_only") is not True
            or profile.get("player_runtime_python_dependency") is not False
            or profile.get("engine_reference_allowed") is not False
            or profile.get("raw_private_state_allowed") is not False
            or profile.get("old_option_index_reuse_allowed") is not False
            or deck.get("source_deck_id") != 800018499
            or deck.get("card_id_domain") != CARD_ID_DOMAIN
            or deck.get("card_count") != 60
            or deck.get("unique_card_count") != 24
            or deck.get("cabt_exportable") is not False
            or policy.get("strategy_id") != STRATEGY_ID
            or policy.get("card_id_domain") != CARD_ID_DOMAIN
            or policy.get("deck_manifest_sha256") != EXPECTED_ARTIFACTS["deck_manifest"][1]
            or opponent.get("deck_id") != 575720
            or opponent.get("decision_runtime_mode") != "rules_only"
            or opponent.get("network_allowed") is not False
        ):
            raise DragapultPublicStrategyError("contract_error")

        own_cards = deck.get("cards")
        if type(own_cards) is not list or len(own_cards) != 24:
            raise DragapultPublicStrategyError("contract_error")
        own_uids = frozenset(row.get("local_card_uid") for row in own_cards if type(row) is dict)
        if len(own_uids) != 24 or not all(_uid(value) for value in own_uids):
            raise DragapultPublicStrategyError("contract_error")

        opponent_path = root / str(opponent.get("deck_path", ""))
        opponent_deck = load_json_strict(opponent_path)
        if (
            _sha(opponent_path.read_bytes()) != opponent.get("deck_raw_sha256")
            or _sha(canonical_json_v1_bytes(opponent_deck)) != opponent.get("deck_canonical_sha256")
            or opponent_deck.get("id") != 575720
            or type(opponent_deck.get("cards")) is not list
        ):
            raise DragapultPublicStrategyError("contract_error")
        opponent_uids = frozenset(
            f"{row.get('set_code')}_{row.get('card_index')}"
            for row in opponent_deck["cards"]
            if type(row) is dict
        )
        if not opponent_uids or not all(_uid(value) for value in opponent_uids):
            raise DragapultPublicStrategyError("contract_error")
        runtime_rows = opponent.get("runtime_artifacts")
        if type(runtime_rows) is not list or len(runtime_rows) < 6:
            raise DragapultPublicStrategyError("contract_error")
        for row in runtime_rows:
            if type(row) is not dict or set(row) != {"path", "raw_sha256"} or _UPPER_SHA_RE.fullmatch(str(row["raw_sha256"])) is None:
                raise DragapultPublicStrategyError("contract_error")
            if _sha((root / row["path"]).read_bytes()) != row["raw_sha256"]:
                raise DragapultPublicStrategyError("contract_error")
        return _Contracts(_freeze(documents), own_uids | opponent_uids, own_uids, opponent_uids)
    except DragapultPublicStrategyError:
        raise
    except Exception as exc:
        raise DragapultPublicStrategyError("contract_error") from exc


def _public_card_list(value: Any, allowed_uids: frozenset[str], *, field_cards: bool) -> str | None:
    if type(value) is not list or len(value) > 60:
        return "invalid_public_frame"
    seen: set[int] = set()
    expected_keys = {"serial", "local_card_uid", "remaining_hp", "attached_energy_count"} if field_cards else {"serial", "local_card_uid"}
    for row in value:
        if type(row) is not dict or set(row) != expected_keys:
            return "invalid_public_frame"
        if not _exact_int(row.get("serial"), 1, _SAFE_MAX) or row["serial"] in seen:
            return "invalid_public_frame"
        seen.add(row["serial"])
        uid = row.get("local_card_uid")
        if not _uid(uid):
            return "invalid_public_frame"
        if uid not in allowed_uids:
            return "unknown_local_card_uid"
        if field_cards and (
            not _exact_int(row.get("remaining_hp"), 0, 9999)
            or not _exact_int(row.get("attached_energy_count"), 0, 64)
        ):
            return "invalid_public_frame"
    return None


def _state_error(value: Any, contracts: _Contracts) -> str | None:
    if type(value) is not dict or set(value) != _PUBLIC_STATE_KEYS:
        return "invalid_public_frame"
    if not _exact_int(value.get("turn_number"), 0, _SAFE_MAX) or type(value.get("phase")) is not str or not value["phase"] or len(value["phase"]) > 32:
        return "invalid_public_frame"
    own = value.get("self")
    opponent = value.get("opponent")
    if type(own) is not dict or set(own) != _SELF_KEYS or type(opponent) is not dict or set(opponent) != _OPPONENT_KEYS:
        return "invalid_public_frame"
    for key in ("deck_count", "prizes_remaining"):
        if not _exact_int(own.get(key), 0, 60) or not _exact_int(opponent.get(key), 0, 60):
            return "invalid_public_frame"
    if not _exact_int(opponent.get("hand_count"), 0, 60):
        return "invalid_public_frame"
    for rows, field_cards, domain in (
        (own["hand"], False, contracts.own_uids),
        (own["active"], True, contracts.own_uids),
        (own["bench"], True, contracts.own_uids),
        (own["discard"], False, contracts.own_uids),
        (opponent["active"], True, contracts.opponent_uids),
        (opponent["bench"], True, contracts.opponent_uids),
        (opponent["discard"], False, contracts.opponent_uids),
    ):
        error = _public_card_list(rows, contracts.allowed_uids, field_cards=field_cards)
        if error is not None:
            return error
        for row in rows:
            if row["local_card_uid"] not in domain:
                return "wrong_local_card_uid_domain"
    return None


def _frame_error(value: Any, contracts: _Contracts) -> str | None:
    if _contains_hidden(value):
        return "invalid_public_frame"
    if type(value) is not dict or set(value) != _FRAME_KEYS:
        return "invalid_public_frame"
    if (
        value["schema_version"] != 1
        or value["profile_id"] != PROFILE_ID
        or value["strategy_id"] != STRATEGY_ID
        or value["card_id_domain"] != CARD_ID_DOMAIN
        or not _exact_int(value["sequence"], 1, _SAFE_MAX)
        or type(value["seat"]) is not int
        or value["seat"] not in (0, 1)
        or type(value["prompt_kind"]) is not str
        or value["prompt_kind"] not in _PROMPT_KINDS
    ):
        return "invalid_public_frame"
    source = value["source"]
    if type(source) is not dict or set(source) != {"public_observation_hash", "window_id"} or any(_UPPER_SHA_RE.fullmatch(str(source[key])) is None for key in source):
        return "invalid_public_frame"
    semantics = value["select_semantics"]
    options = value["options"]
    if (
        type(semantics) is not dict
        or set(semantics) != {"min_count", "max_count"}
        or type(options) is not list
        or not 1 <= len(options) <= 1024
        or not _exact_int(semantics.get("min_count"), 0, len(options))
        or not _exact_int(semantics.get("max_count"), 0, len(options))
        or semantics["min_count"] > semantics["max_count"]
    ):
        return "invalid_public_frame"
    for expected_index, row in enumerate(options):
        if type(row) is not dict or set(row) != _OPTION_KEYS:
            return "invalid_public_frame"
        if type(row["index"]) is not int or row["index"] != expected_index or type(row["kind"]) is not str or row["kind"] not in _OPTION_KINDS:
            return "invalid_public_frame"
        for key in ("card_uid", "source_uid", "target_uid"):
            uid = row[key]
            if uid is not None and not _uid(uid):
                return "invalid_public_frame"
            if uid is not None and uid not in contracts.allowed_uids:
                return "unknown_local_card_uid"
        for key, maximum in (("target_remaining_hp", 9999), ("target_prize_value", 6), ("attached_energy_count", 64), ("attack_index", 31)):
            child = row[key]
            if child is not None and not _exact_int(child, 0, maximum):
                return "invalid_public_frame"
        tags = row["tags"]
        if type(tags) is not list or len(tags) > 16 or len(tags) != len(set(tags)) or any(type(tag) is not str or not tag or len(tag) > 64 or not re.fullmatch(r"[a-z0-9][a-z0-9._-]*", tag) for tag in tags):
            return "invalid_public_frame"
    return _state_error(value["public_state"], contracts)


def _rank(value: Any, order: list[str]) -> int:
    return order.index(value) if value in order else len(order) + 20


def _score_option(prompt_kind: str, option: dict[str, Any], policy: dict[str, Any]) -> tuple[Any, ...]:
    kind = option["kind"]
    card_uid = option["card_uid"]
    source_uid = option["source_uid"]
    target_uid = option["target_uid"]
    if prompt_kind == "setup_active":
        return (_rank(card_uid, policy["setup_active_priority"]), option["index"])
    if prompt_kind == "setup_bench":
        return (1 if kind in _TERMINAL_KINDS else 0, _rank(card_uid, policy["setup_bench_priority"]), option["index"])
    if prompt_kind in {"search", "evolve"}:
        return (_rank(card_uid, policy["search_priority"]), 1 if kind in _TERMINAL_KINDS else 0, option["index"])
    if prompt_kind == "attach":
        dragapult_target = 0 if target_uid in {"CSV8C_159", "CSV8C_158", "CSV8C_157"} else 1
        return (dragapult_target, _rank(card_uid, policy["main_card_priority"]), option["index"])
    if prompt_kind == "attack":
        tag_rank = min((_rank(tag, policy["attack_tag_priority"]) for tag in option["tags"]), default=len(policy["attack_tag_priority"]) + 20)
        phantom = 0 if "phantom_dive" in option["tags"] or (source_uid == "CSV8C_159" and option["attack_index"] == 1) else 1
        return (phantom, tag_rank, -(option["attack_index"] if option["attack_index"] is not None else -1), option["index"])
    if prompt_kind in {"effect_target", "attack_target"}:
        knockout = 0 if "projected_knockout" in option["tags"] or "spread_knockout" in option["tags"] else 1
        hp = option["target_remaining_hp"] if option["target_remaining_hp"] is not None else 9999
        prizes = option["target_prize_value"] if option["target_prize_value"] is not None else 0
        return (knockout, hp, -prizes, option["index"])
    if prompt_kind == "send_out":
        energy = option["attached_energy_count"] if option["attached_energy_count"] is not None else 0
        return (_rank(card_uid, policy["send_out_priority"]), -energy, option["index"])
    if prompt_kind in {"take_prize", "terminal"}:
        return (option["index"],)
    if prompt_kind == "main":
        attack_bias = 0 if ("phantom_dive" in option["tags"] or "projected_knockout" in option["tags"]) else 1
        return (
            attack_bias if kind in {"attack", "granted_attack"} else 0,
            _rank(kind, policy["main_kind_priority"]),
            _rank(card_uid, policy["main_card_priority"]),
            _rank(target_uid, policy["send_out_priority"]),
            option["index"],
        )
    return (option["index"],)


class DragapultPublicStrategy:
    __slots__ = ("_contracts", "_root", "_seal")

    def __init__(self, *_: Any, **__: Any) -> None:
        raise DragapultPublicStrategyError("direct_construction_forbidden")

    @classmethod
    def load_default(cls) -> "DragapultPublicStrategy":
        return cls.load_trusted_bundle(DEFAULT_ROOT)

    @classmethod
    def load_trusted_bundle(cls, repository_root: Path) -> "DragapultPublicStrategy":
        root = Path(repository_root).resolve()
        contracts = _load_contracts(root)
        value = object.__new__(cls)
        object.__setattr__(value, "_contracts", contracts)
        object.__setattr__(value, "_root", root)
        object.__setattr__(value, "_seal", _TOKEN)
        if not value.validate_integrity():
            raise DragapultPublicStrategyError("contract_error")
        return value

    def validate_integrity(self) -> bool:
        return self._seal is _TOKEN and isinstance(self._contracts, _Contracts) and self._root.is_absolute() and len(self._contracts.own_uids) == 24

    def select(self, public_frame: object) -> list[int]:
        if not self.validate_integrity():
            raise DragapultPublicStrategyError("contract_error")
        value = copy.deepcopy(public_frame)
        error = _frame_error(value, self._contracts)
        if error is not None:
            raise DragapultPublicStrategyError(error)
        policy = _thaw(self._contracts.documents["policy"])
        options: list[dict[str, Any]] = value["options"]
        semantics = value["select_semantics"]
        minimum = semantics["min_count"]
        maximum = semantics["max_count"]
        ranked = sorted(options, key=lambda row: _score_option(value["prompt_kind"], row, policy))
        selectable = [row for row in ranked if row["kind"] not in _TERMINAL_KINDS]
        if minimum == 0 and not selectable:
            return []
        pool = selectable if selectable else ranked
        count = minimum if minimum > 0 else min(1, maximum)
        if len(pool) < count:
            pool = ranked
        indexes = [row["index"] for row in pool[:count]]
        if not minimum <= len(indexes) <= maximum or len(indexes) != len(set(indexes)):
            raise DragapultPublicStrategyError("same_window_fallback_failed")
        return indexes

    def bundle_hash(self) -> str:
        return EXPECTED_BUNDLE_SHA256 if self.validate_integrity() else ""

    def audit_snapshot(self) -> dict[str, object]:
        if not self.validate_integrity():
            raise DragapultPublicStrategyError("contract_error")
        return {
            "profile_id": PROFILE_ID,
            "strategy_id": STRATEGY_ID,
            "card_id_domain": CARD_ID_DOMAIN,
            "deck_id": 800018499,
            "deck_card_count": 60,
            "deck_unique_card_count": 24,
            "opponent_deck_id": 575720,
            "opponent_runtime_mode": "rules_only",
            "cabt_exportable": False,
            "public_only": True,
            "player_runtime_python_dependency": False,
            "bundle_sha256": EXPECTED_BUNDLE_SHA256,
        }


def agent(public_frame: object) -> list[int]:
    return DragapultPublicStrategy.load_default().select(public_frame)


__all__ = [
    "CARD_ID_DOMAIN",
    "DragapultPublicStrategy",
    "DragapultPublicStrategyError",
    "EXPECTED_BUNDLE_SHA256",
    "PROFILE_ID",
    "STRATEGY_ID",
    "agent",
]
