from __future__ import annotations

import copy
from dataclasses import dataclass
import hashlib
from pathlib import Path
from typing import Any

from .cabt_envelope import parse_raw_cabt_envelope
from .card_id_catalog import CardIdCatalog
from .public_observation_firewall import PublicFirewallResult, PublicObservationFirewall
from .source_lock import canonical_json_v1_bytes, load_json_strict


SCHEMA_VERSION = 1
PROFILE_ID = "godot_observation_projector_v1"
BUNDLE_ID = "ptcgdap-godot-observation-projector-p2-wp5-v1"
EXPECTED_BUNDLE_SHA256 = "C51EA4CF1AEFCBB5B9C6D83825FF3A717CCDCC4105B804210BF6169372619041"
EXPECTED_CATALOG_SHA256 = "AB8CF10465F492A98DA8247A84572AECEE281D0726F7BB7B8E5DBC03A6AC70D4"
EXPECTED_FIREWALL_SHA256 = "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947"
EXPECTED_CURSOR_SHA256 = "ED246F029531AA8F21956A64D70F557F1BBC90450A6F9109C5286261E290319D"
EXPECTED_P1_SHA256 = "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
EXPECTED_SOURCE_LOCK_SHA256 = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
EXPECTED_ARTIFACTS = {
    "godot_observation_projector_schema_v1": (
        "contracts/ptcgdap/godot_observation_projector.schema.json",
        "6045AF6A55B10FF43A917D5ED85DB98204CFDFE78AAEABCD6B20051CEAF011DF",
    ),
    "godot_observation_projector_profile_v1": (
        "contracts/ptcgdap/godot_observation_projector_profile.json",
        "175C4422EDB2DB5ECCF3BF04AC16AC8B9BF74F80E8B4C3F75E634C6772A4BFD1",
    ),
    "godot_observation_projector_conformance_v1": (
        "contracts/ptcgdap/godot_observation_projector_conformance_vectors.json",
        "D3724188C8ED7569749E8733AF8666107922E83C632ABD0D7D14F977EBF3AF73",
    ),
}
ERROR_CODES = frozenset({
    "projector_contract_error", "invalid_input", "invalid_player_index", "invalid_state",
    "invalid_decision", "invalid_select", "invalid_card_identity", "card_catalog_unmapped",
    "card_serial_unbound", "invalid_attack_identity", "hidden_information_requested",
    "invalid_public_event", "stale_match_generation", "limit_exceeded", "firewall_rejected",
    "engine_capture_unavailable", "result_integrity_invalid",
})
MAX_SAFE_INTEGER = 9_007_199_254_740_991
OPTION_SHAPES = {
    0: {"type", "number"}, 1: {"type"}, 2: {"type"},
    3: {"type", "area", "index", "playerIndex"},
    4: {"type", "area", "index", "playerIndex", "toolIndex"},
    5: {"type", "area", "index", "playerIndex", "energyIndex"},
    6: {"type", "area", "index", "playerIndex", "energyIndex", "count"},
    7: {"type", "index"},
    8: {"type", "area", "index", "inPlayArea", "inPlayIndex"},
    9: {"type", "area", "index", "inPlayArea", "inPlayIndex"},
    10: {"type", "area", "index"}, 11: {"type", "area", "index"},
    12: {"type"}, 13: {"type", "attackId"}, 14: {"type"},
    15: {"type", "cardId", "serial"}, 16: {"type", "specialConditionType"},
}
_TOKEN = object()


class ObservationProjectorError(ValueError):
    pass


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _canonical_hash(value: object) -> str:
    return _sha(canonical_json_v1_bytes(value))


def _exact_int(value: object) -> bool:
    return type(value) is int and -MAX_SAFE_INTEGER <= value <= MAX_SAFE_INTEGER


def _nonnegative(value: object) -> bool:
    return _exact_int(value) and value >= 0


def _positive(value: object) -> bool:
    return _exact_int(value) and value > 0


@dataclass(frozen=True, slots=True)
class _Contracts:
    root: Path
    profile: dict[str, Any]
    artifact_hashes: tuple[tuple[str, str], ...]

    def integrity_valid(self) -> bool:
        try:
            if _canonical_hash(self.profile) != EXPECTED_ARTIFACTS["godot_observation_projector_profile_v1"][1]:
                return False
            for relative, expected in self.artifact_hashes:
                if _canonical_hash(load_json_strict(self.root / relative)) != expected:
                    return False
            return True
        except Exception:
            return False


def _load_contracts(repository_root: Path) -> _Contracts:
    try:
        bundle_path = repository_root / "contracts" / "ptcgdap" / "godot_observation_projector_bundle.json"
        bundle = load_json_strict(bundle_path)
        if _canonical_hash(bundle) != EXPECTED_BUNDLE_SHA256:
            raise ObservationProjectorError("projector_contract_error")
        if type(bundle) is not dict or set(bundle) != {
            "schema_version", "bundle_id", "source_lock_canonical_sha256",
            "p1_contract_canonical_sha256", "catalog_bundle_canonical_sha256",
            "firewall_bundle_canonical_sha256", "parent_cursor_bundle_canonical_sha256", "artifacts",
        }:
            raise ObservationProjectorError("projector_contract_error")
        if (
            bundle["schema_version"] != 1 or bundle["bundle_id"] != BUNDLE_ID
            or bundle["source_lock_canonical_sha256"] != EXPECTED_SOURCE_LOCK_SHA256
            or bundle["p1_contract_canonical_sha256"] != EXPECTED_P1_SHA256
            or bundle["catalog_bundle_canonical_sha256"] != EXPECTED_CATALOG_SHA256
            or bundle["firewall_bundle_canonical_sha256"] != EXPECTED_FIREWALL_SHA256
            or bundle["parent_cursor_bundle_canonical_sha256"] != EXPECTED_CURSOR_SHA256
        ):
            raise ObservationProjectorError("projector_contract_error")
        entries = bundle["artifacts"]
        if type(entries) is not list or len(entries) != len(EXPECTED_ARTIFACTS):
            raise ObservationProjectorError("projector_contract_error")
        seen: set[str] = set()
        hashes: list[tuple[str, str]] = []
        loaded: dict[str, Any] = {}
        for entry in entries:
            if type(entry) is not dict or set(entry) != {"id", "path", "canonical_sha256"}:
                raise ObservationProjectorError("projector_contract_error")
            artifact_id = entry["id"]
            if type(artifact_id) is not str or artifact_id in seen or artifact_id not in EXPECTED_ARTIFACTS:
                raise ObservationProjectorError("projector_contract_error")
            expected_path, expected_hash = EXPECTED_ARTIFACTS[artifact_id]
            if entry["path"] != expected_path or entry["canonical_sha256"] != expected_hash:
                raise ObservationProjectorError("projector_contract_error")
            value = load_json_strict(repository_root / expected_path)
            if _canonical_hash(value) != expected_hash:
                raise ObservationProjectorError("projector_contract_error")
            seen.add(artifact_id)
            hashes.append((expected_path, expected_hash))
            loaded[artifact_id] = value
        if seen != set(EXPECTED_ARTIFACTS):
            raise ObservationProjectorError("projector_contract_error")
        profile = loaded["godot_observation_projector_profile_v1"]
        if type(profile) is not dict or set(profile["stable_error_codes"]) != ERROR_CODES:
            raise ObservationProjectorError("projector_contract_error")
        return _Contracts(repository_root, copy.deepcopy(profile), tuple(hashes))
    except ObservationProjectorError:
        raise
    except Exception as exc:
        raise ObservationProjectorError("projector_contract_error") from exc


class ProjectorResult:
    __slots__ = ("_owner", "_bound_input", "_accepted", "_error_code", "_observation", "_public_hash", "_audit", "_firewall_result", "_snapshot")

    def __init__(self, token: object, owner: GodotObservationProjector, bound_input: object, evaluation: dict[str, Any]) -> None:
        if token is not _TOKEN:
            raise ObservationProjectorError("result_integrity_invalid")
        self._owner = owner
        self._bound_input = bound_input
        self._accepted = evaluation["accepted"]
        self._error_code = evaluation["error_code"]
        self._observation = copy.deepcopy(evaluation["observation"])
        self._public_hash = evaluation["public_observation_hash"]
        self._audit = copy.deepcopy(evaluation["audit"])
        self._firewall_result = evaluation.get("firewall_result")
        self._snapshot = self._serialize_unchecked()

    @property
    def accepted(self) -> bool:
        return self._accepted

    @property
    def observation(self) -> dict[str, Any] | None:
        return copy.deepcopy(self._observation)

    @property
    def public_observation_hash(self) -> str | None:
        return self._public_hash

    @property
    def firewall_result(self) -> PublicFirewallResult | None:
        return self._firewall_result if self.validate_integrity() else None

    def _serialize_unchecked(self) -> dict[str, Any]:
        return {
            "schema_version": SCHEMA_VERSION,
            "profile_id": PROFILE_ID,
            "projector_bundle_hash": EXPECTED_BUNDLE_SHA256,
            "accepted": self._accepted,
            "error_code": self._error_code,
            "observation": copy.deepcopy(self._observation),
            "public_observation_hash": self._public_hash,
            "audit": copy.deepcopy(self._audit),
        }

    def validate_integrity(self) -> bool:
        try:
            if type(self._owner) is not GodotObservationProjector or not self._owner._integrity_valid():
                return False
            if self._snapshot != self._serialize_unchecked():
                return False
            replay = self._owner._evaluate(self._bound_input)
            replay.pop("firewall_result", None)
            return replay == self._snapshot_without_header()
        except Exception:
            return False

    def _snapshot_without_header(self) -> dict[str, Any]:
        return {
            "accepted": self._accepted,
            "error_code": self._error_code,
            "observation": copy.deepcopy(self._observation),
            "public_observation_hash": self._public_hash,
            "audit": copy.deepcopy(self._audit),
        }

    def to_public_dict(self) -> dict[str, Any]:
        if not self.validate_integrity():
            raise ObservationProjectorError("result_integrity_invalid")
        return copy.deepcopy(self._snapshot)

    def to_conformance_summary(self) -> dict[str, Any]:
        if not self.validate_integrity():
            raise ObservationProjectorError("result_integrity_invalid")
        if not self._accepted:
            return {"accepted":False,"error_code":self._error_code,"public_observation_hash":None,"select_type":None,"select_context":None,"option_count":0,"log_count":0,"acting_hand_visible":False,"opponent_hand_hidden":False}
        observation = self._observation
        assert observation is not None
        select = observation["select"]
        acting = observation["current"]["yourIndex"]
        return {
            "accepted":True,"error_code":"","public_observation_hash":self._public_hash,
            "select_type":None if select is None else select["type"],"select_context":None if select is None else select["context"],
            "option_count":0 if select is None else len(select["option"]),"log_count":len(observation["logs"]),
            "acting_hand_visible":observation["current"]["players"][acting]["hand"] is not None,
            "opponent_hand_hidden":observation["current"]["players"][1-acting]["hand"] is None,
        }


class GodotObservationProjector:
    __slots__ = ("_contracts", "_catalog", "_firewall", "_seal")

    def __init__(self, token: object, contracts: _Contracts, catalog: CardIdCatalog, firewall: PublicObservationFirewall) -> None:
        if token is not _TOKEN:
            raise ObservationProjectorError("projector_contract_error")
        self._contracts = contracts
        self._catalog = catalog
        self._firewall = firewall
        self._seal = EXPECTED_BUNDLE_SHA256

    @classmethod
    def load_default(cls) -> GodotObservationProjector:
        return cls.load_from_root(Path(__file__).resolve().parents[3])

    @classmethod
    def load_from_root(cls, repository_root: str | Path) -> GodotObservationProjector:
        if type(repository_root) is not str and not isinstance(repository_root, Path):
            raise ObservationProjectorError("projector_contract_error")
        root = Path(repository_root)
        contracts = _load_contracts(root)
        catalog = CardIdCatalog.load_trusted_bundle(root)
        firewall = PublicObservationFirewall.load_from_root(root / "contracts" / "ptcgdap")
        return cls(_TOKEN, contracts, catalog, firewall)

    @property
    def contract_hash(self) -> str:
        return EXPECTED_BUNDLE_SHA256

    def _integrity_valid(self) -> bool:
        try:
            return (
                self._seal == EXPECTED_BUNDLE_SHA256 and self._contracts.integrity_valid()
                and self._catalog.catalog_hash() == EXPECTED_CATALOG_SHA256
                and self._firewall.contract_hash == EXPECTED_FIREWALL_SHA256
            )
        except Exception:
            return False

    def project_conformance_case(self, vectors: object, case: object) -> ProjectorResult:
        materialized = self._materialize_case(vectors, case)
        evaluation = self._evaluate(materialized)
        return ProjectorResult(_TOKEN, self, materialized, evaluation)

    def project_conformance_fixture(self, fixture: object) -> ProjectorResult:
        bound = copy.deepcopy(fixture)
        evaluation = self._evaluate(bound)
        return ProjectorResult(_TOKEN, self, bound, evaluation)

    def _materialize_case(self, vectors: object, case: object) -> object:
        try:
            if type(vectors) is not dict or type(case) is not dict:
                return None
            if vectors.get("artifact_id") != "ptcgdap-godot-observation-projector-conformance-v1" or vectors.get("profile_id") != PROFILE_ID:
                return None
            if "window" in case:
                current = copy.deepcopy(vectors["state_fixtures"][case["state_fixture_id"]])
                return {"current_source":current,"select_source":copy.deepcopy(case["select_source"]),"public_events":copy.deepcopy(case["public_events"]),"step":case["step"],"remainingOverageTime":case["remainingOverageTime"]}
            base_id = case["base_case_id"]
            base = next(item for item in vectors["projection_cases"] if item["case_id"] == base_id)
            value = self._materialize_case(vectors, base)
            if type(value) is not dict:
                return None
            self._apply_fault(value, case["fault"])
            return value
        except Exception:
            return None

    @staticmethod
    def _apply_fault(value: dict[str, Any], fault: dict[str, Any]) -> None:
        kind = fault["kind"]
        if kind == "replace_public_events":
            value["public_events"] = copy.deepcopy(fault["value"])
            return
        if kind == "replace_select_options":
            value["select_source"]["option"] = copy.deepcopy(fault["value"])
            return
        if kind != "replace":
            raise ValueError("invalid fault")
        parts = fault["pointer"].split("/")[1:]
        cursor: Any = value
        for part in parts[:-1]:
            cursor = cursor[int(part)] if type(cursor) is list else cursor[part]
        last = parts[-1]
        if type(cursor) is list:
            cursor[int(last)] = copy.deepcopy(fault["value"])
        else:
            cursor[last] = copy.deepcopy(fault["value"])

    def _rejected(self, code: str) -> dict[str, Any]:
        return {"accepted":False,"error_code":code if code in ERROR_CODES else "invalid_input","observation":None,"public_observation_hash":None,"audit":None}

    def _evaluate(self, fixture: object) -> dict[str, Any]:
        if not self._integrity_valid():
            return self._rejected("projector_contract_error")
        try:
            validated = self._validate_fixture(fixture)
            if type(validated) is str:
                return self._rejected(validated)
            raw, identity_checks = validated
            parsed = parse_raw_cabt_envelope(raw, contract_root=self._contracts.root / "contracts" / "ptcgdap")
            firewall_result = self._firewall.project(parsed)
            if not firewall_result.accepted:
                return self._rejected("firewall_rejected")
            observation = firewall_result.public_observation
            audit = {
                "authority":"conformance_fixture_only",
                "source_classes":["conformance_fixture_only","strict_catalog"],
                "projector_bundle_hash":EXPECTED_BUNDLE_SHA256,
                "identity_checks":identity_checks,
                "hidden_fields_emitted":0,
            }
            return {"accepted":True,"error_code":"","observation":observation,"public_observation_hash":firewall_result.public_observation_hash,"audit":audit,"firewall_result":firewall_result}
        except (KeyError, TypeError, ValueError, IndexError, RecursionError):
            return self._rejected("invalid_input")

    def _validate_fixture(self, fixture: object) -> str | tuple[dict[str, Any], int]:
        if type(fixture) is not dict or not {"current_source","select_source","public_events"}.issubset(fixture):
            return "invalid_input"
        if set(fixture) - {"current_source","select_source","public_events","step","remainingOverageTime"}:
            return "invalid_input"
        current = fixture["current_source"]
        if type(current) is not dict:
            return "invalid_state"
        acting = current.get("acting_player_index")
        if type(acting) is not int or acting not in (0, 1):
            return "invalid_player_index"
        players = current.get("players")
        if type(players) is not list or len(players) != 2:
            return "invalid_state"
        authority: dict[int, tuple[int, int]] = {}
        checks = 0
        for player_index, player in enumerate(players):
            error, count = self._validate_player(player, player_index, acting, authority)
            if error:
                return error
            checks += count
        stadium = current.get("stadium")
        if stadium is not None:
            error = self._register_card(stadium, None, authority)
            if error:
                return error
            checks += 1
        if not all(type(current.get(key)) is bool for key in ("supporter_played","stadium_played","energy_attached","retreated")):
            return "invalid_state"
        for key in ("turn","turn_action_count"):
            if not _nonnegative(current.get(key)):
                return "invalid_state"
        if type(current.get("first_player_index")) is not int or current["first_player_index"] not in (-1,0,1):
            return "invalid_state"
        if type(current.get("result")) is not int or current["result"] not in (-1,0,1):
            return "invalid_state"
        select = fixture["select_source"]
        select_error, select_checks = self._validate_select(select, current, authority)
        if select_error:
            return select_error
        checks += select_checks
        events = fixture["public_events"]
        if type(events) is not list or len(events) > 512:
            return "limit_exceeded" if type(events) is list else "invalid_public_event"
        for event in events:
            event_error, event_checks = self._validate_event(event, authority, current)
            if event_error:
                return event_error
            checks += event_checks
        if "step" in fixture and not _nonnegative(fixture["step"]):
            return "invalid_input"
        if "remainingOverageTime" in fixture and not _nonnegative(fixture["remainingOverageTime"]):
            return "invalid_input"
        return self._build_raw(fixture), checks

    def _validate_player(self, player: object, owner: int, acting: int, authority: dict[int, tuple[int, int]]) -> tuple[str, int]:
        if type(player) is not dict or set(player) != {"active","bench","bench_max","deck_count","discard","hand","hand_count","prize_count","public_prizes"}:
            return "invalid_state", 0
        if type(player["active"]) is not list or len(player["active"]) > 1 or type(player["bench"]) is not list or len(player["bench"]) > 8:
            return "invalid_state", 0
        if not _nonnegative(player["bench_max"]) or player["bench_max"] > 8 or not _nonnegative(player["deck_count"]) or player["deck_count"] > 120:
            return "invalid_state", 0
        if owner == acting:
            if type(player["hand"]) is not list or len(player["hand"]) > 60 or player["hand_count"] != len(player["hand"]):
                return "invalid_state", 0
        elif player["hand"] is not None or not _nonnegative(player["hand_count"]) or player["hand_count"] > 60:
            return "invalid_state", 0
        if type(player["discard"]) is not list or len(player["discard"]) > 120 or not _nonnegative(player["prize_count"]) or player["prize_count"] > 12:
            return "invalid_state", 0
        if type(player["public_prizes"]) is not dict:
            return "invalid_state", 0
        count = 0
        for pokemon in player["active"] + player["bench"]:
            error, added = self._validate_pokemon(pokemon, owner, authority)
            if error:
                return error, count
            count += added
        visible_hand = player["hand"] if owner == acting else []
        for card in player["discard"] + visible_hand:
            error = self._register_card(card, owner, authority)
            if error:
                return error, count
            count += 1
        for key, card in player["public_prizes"].items():
            if type(key) is not str or not key.isdecimal() or (len(key) > 1 and key.startswith("0")) or int(key) >= player["prize_count"]:
                return "invalid_state", count
            error = self._register_card(card, owner, authority)
            if error:
                return error, count
            count += 1
        return "", count

    def _validate_pokemon(self, pokemon: object, owner: int, authority: dict[int, tuple[int, int]]) -> tuple[str, int]:
        if type(pokemon) is not dict or set(pokemon) != {"stack","attached_energy","tool","hp","max_hp","appear_this_turn","status"}:
            return "invalid_state", 0
        stack = pokemon["stack"]
        energy = pokemon["attached_energy"]
        if type(stack) is not list or not 1 <= len(stack) <= 3 or type(energy) is not list or len(energy) > 64:
            return "invalid_state", 0
        if not _nonnegative(pokemon["hp"]) or not _positive(pokemon["max_hp"]) or pokemon["hp"] > pokemon["max_hp"] or type(pokemon["appear_this_turn"]) is not bool:
            return "invalid_state", 0
        status = pokemon["status"]
        status_keys = {"poisoned","burned","asleep","paralyzed","confused"}
        if type(status) is not dict or set(status) != status_keys or not all(type(status[key]) is bool for key in status_keys):
            return "invalid_state", 0
        count = 0
        for card in stack:
            error = self._register_card(card, owner, authority)
            if error:
                return error, count
            count += 1
        for card in energy:
            if type(card) is not dict or type(card.get("energy_type")) is not int or not 0 <= card["energy_type"] <= 11:
                return "invalid_card_identity", count
            error = self._register_card(card, None, authority)
            if error:
                return error, count
            count += 1
        if pokemon["tool"] is not None:
            error = self._register_card(pokemon["tool"], None, authority)
            if error:
                return error, count
            count += 1
        return "", count

    def _register_card(self, card: object, expected_owner: int | None, authority: dict[int, tuple[int, int]]) -> str:
        if type(card) is not dict or set(card) - {"official_card_id","serial","player_index","energy_type"} or not {"official_card_id","serial","player_index"}.issubset(card):
            return "invalid_card_identity"
        card_id, serial, player = card["official_card_id"], card["serial"], card["player_index"]
        if not _positive(card_id) or not _positive(serial) or type(player) is not int or player not in (0,1) or (expected_owner is not None and player != expected_owner):
            return "invalid_card_identity"
        known = self._catalog.lookup_local_printing_for_official_card(card_id)
        if not known.get("ok", False):
            return "card_catalog_unmapped"
        identity = (card_id, player)
        if serial in authority:
            return "invalid_card_identity"
        authority[serial] = identity
        return ""

    def _reference_card(self, value: object, authority: dict[int, tuple[int, int]]) -> bool:
        if type(value) is not dict or set(value) != {"id","playerIndex","serial"}:
            return False
        serial = value["serial"]
        return _positive(serial) and authority.get(serial) == (value["id"], value["playerIndex"])

    def _register_or_match_card(self, card: object, authority: dict[int, tuple[int, int]]) -> bool:
        if type(card) is not dict or set(card) - {"official_card_id","serial","player_index","energy_type"} or not {"official_card_id","serial","player_index"}.issubset(card):
            return False
        serial = card.get("serial")
        if not _positive(card.get("official_card_id")) or not _positive(serial) or type(card.get("player_index")) is not int or card.get("player_index") not in (0, 1):
            return False
        if serial in authority:
            return authority.get(serial) == (card.get("official_card_id"), card.get("player_index"))
        return self._register_card(card, None, authority) == ""

    def _validate_select(self, select: object, current: dict[str, Any], authority: dict[int, tuple[int, int]]) -> tuple[str, int]:
        if select is None:
            return "", 0
        required = {"type","context","minCount","maxCount","remainDamageCounter","remainEnergyCost","option","deck","contextCard","effect"}
        if type(select) is not dict or set(select) != required:
            return "invalid_select", 0
        if type(select["type"]) is not int or not 0 <= select["type"] <= 10 or not _nonnegative(select["context"]):
            return "invalid_select", 0
        options = select["option"]
        minimum, maximum = select["minCount"], select["maxCount"]
        if type(options) is not list or len(options) > 256 or not _nonnegative(minimum) or not _nonnegative(maximum) or not 0 <= minimum <= maximum <= len(options):
            return "invalid_select", 0
        for key in ("remainDamageCounter","remainEnergyCost"):
            if not _nonnegative(select[key]):
                return "invalid_select", 0
        deck_authority: dict[int, tuple[int, int]] = {}
        if select["deck"] is not None:
            if type(select["deck"]) is not list or len(select["deck"]) > 120:
                return "limit_exceeded", 0
            for wire_card in select["deck"]:
                if type(wire_card) is not dict or set(wire_card) != {"official_card_id","serial","player_index"}:
                    return "invalid_select", 0
                error = self._register_card(wire_card, current["acting_player_index"], deck_authority)
                if error:
                    return "invalid_select", 0
        checks = len(deck_authority)
        for name in ("contextCard","effect"):
            value = select[name]
            if value is not None:
                wire = {"id":value.get("official_card_id"),"serial":value.get("serial"),"playerIndex":value.get("player_index")} if type(value) is dict else None
                if wire is None or not self._reference_card(wire, authority):
                    return "invalid_select", checks
                checks += 1
        actor = current["acting_player_index"]
        for option in options:
            if type(option) is not dict or type(option.get("type")) is not int or option["type"] not in OPTION_SHAPES or set(option) != OPTION_SHAPES[option["type"]]:
                return "invalid_select", checks
            option_type = option["type"]
            if option_type == 7 and (not _nonnegative(option["index"]) or option["index"] >= len(current["players"][actor]["hand"])):
                return "invalid_select", checks
            if option_type == 13:
                if not self._attack_matches(option["attackId"], current["players"][actor]["active"][-1]["stack"][-1]["official_card_id"] if current["players"][actor]["active"] else None):
                    return "invalid_attack_identity", checks
                checks += 1
            if option_type == 15:
                if not _positive(option["cardId"]) or not _positive(option["serial"]) or authority.get(option["serial"], (None,None))[0] != option["cardId"]:
                    return "invalid_select", checks
                checks += 1
            if option_type == 3 and not self._coordinate_exists(option, current, select["deck"]):
                return "invalid_select", checks
        return "", checks

    @staticmethod
    def _coordinate_exists(option: dict[str, Any], current: dict[str, Any], deck: object) -> bool:
        if not all(type(option[key]) is int for key in ("area","index","playerIndex")) or option["playerIndex"] not in (0,1) or option["index"] < 0:
            return False
        area, index, player = option["area"], option["index"], option["playerIndex"]
        source = current["players"][player]
        if area == 1:
            return type(deck) is list and index < len(deck)
        if area == 2:
            return type(source["hand"]) is list and index < len(source["hand"])
        if area == 4:
            return index < len(source["active"])
        if area == 5:
            return index < len(source["bench"])
        if area == 6:
            return index < source["prize_count"]
        return False

    def _attack_matches(self, attack_id: object, owner_card_id: object) -> bool:
        if not _positive(attack_id) or not _positive(owner_card_id):
            return False
        result = self._catalog.official_attack_owner(attack_id)
        return bool(result.get("ok", False)) and result.get("value", {}).get("owner_official_card_id") == owner_card_id

    def _validate_event(self, event: object, authority: dict[int, tuple[int, int]], current: dict[str, Any]) -> tuple[str, int]:
        if type(event) is not dict or type(event.get("kind")) is not str:
            return "invalid_public_event", 0
        kind = event["kind"]
        if kind in {"turn_start","turn_end","result"}:
            if set(event) != {"kind","player_index"} or type(event["player_index"]) is not int or event["player_index"] not in (0,1):
                return "invalid_public_event", 0
            return "", 0
        allowed_keys = {
            "move_card":{"kind","card","from_area","to_area"},
            "play":{"kind","card"},
            "attach":{"kind","card","target"},
            "evolve":{"kind","card"},
            "attack":{"kind","card","attack_id"},
            "hp_change":{"kind","card","value","put_damage_counter"},
        }
        if kind not in allowed_keys or set(event) != allowed_keys[kind]:
            return "invalid_public_event", 0
        card = event.get("card")
        if not self._register_or_match_card(card, authority):
            return "invalid_public_event", 0
        if kind == "attack" and not self._attack_matches(event.get("attack_id"), card["official_card_id"]):
            return "invalid_attack_identity", 0
        if kind == "attach":
            target = event.get("target")
            if not self._register_or_match_card(target, authority):
                return "invalid_public_event", 0
        if kind == "move_card" and (not _nonnegative(event.get("from_area")) or not _nonnegative(event.get("to_area"))):
            return "invalid_public_event", 0
        if kind == "hp_change" and (not _exact_int(event.get("value")) or type(event.get("put_damage_counter")) is not bool):
            return "invalid_public_event", 0
        return "", 1

    @staticmethod
    def _wire_card(card: dict[str, Any]) -> dict[str, int]:
        return {"id":card["official_card_id"],"playerIndex":card["player_index"],"serial":card["serial"]}

    def _wire_select(self, source: dict[str, Any] | None) -> dict[str, Any] | None:
        if source is None:
            return None
        value = copy.deepcopy(source)
        if value["deck"] is not None:
            value["deck"] = [self._wire_card(card) for card in value["deck"]]
        for key in ("contextCard", "effect"):
            if value[key] is not None:
                value[key] = self._wire_card(value[key])
        return value

    def _wire_pokemon(self, source: dict[str, Any]) -> dict[str, Any]:
        top = source["stack"][-1]
        return {"appearThisTurn":source["appear_this_turn"],"energies":[card["energy_type"] for card in source["attached_energy"]],"energyCards":[self._wire_card(card) for card in source["attached_energy"]],"hp":source["hp"],"id":top["official_card_id"],"maxHp":source["max_hp"],"playerIndex":top["player_index"],"preEvolution":[self._wire_card(card) for card in source["stack"][:-1]],"serial":top["serial"],"tools":[] if source["tool"] is None else [self._wire_card(source["tool"])]}

    def _wire_player(self, source: dict[str, Any], index: int, acting: int) -> dict[str, Any]:
        status = {"poisoned":False,"burned":False,"asleep":False,"paralyzed":False,"confused":False} if not source["active"] else source["active"][0]["status"]
        prizes: list[dict[str,int] | None] = [None] * source["prize_count"]
        for key, card in source["public_prizes"].items():
            prizes[int(key)] = self._wire_card(card)
        return {"active":[self._wire_pokemon(item) for item in source["active"]],"asleep":status["asleep"],"bench":[self._wire_pokemon(item) for item in source["bench"]],"benchMax":source["bench_max"],"burned":status["burned"],"confused":status["confused"],"deckCount":source["deck_count"],"discard":[self._wire_card(card) for card in source["discard"]],"hand":[self._wire_card(card) for card in source["hand"]] if index == acting else None,"handCount":source["hand_count"],"paralyzed":status["paralyzed"],"poisoned":status["poisoned"],"prize":prizes}

    def _wire_log(self, event: dict[str, Any]) -> dict[str, Any]:
        kind = event["kind"]
        if kind == "turn_start": return {"playerIndex":event["player_index"],"type":2}
        if kind == "turn_end": return {"playerIndex":event["player_index"],"type":3}
        if kind == "result": return {"playerIndex":event["player_index"],"type":23}
        card = self._wire_card(event["card"])
        if kind == "move_card": return {"cardId":card["id"],"fromArea":event["from_area"],"playerIndex":card["playerIndex"],"serial":card["serial"],"toArea":event["to_area"],"type":6}
        if kind == "play": return {"cardId":card["id"],"playerIndex":card["playerIndex"],"serial":card["serial"],"type":10}
        if kind == "attach":
            target=self._wire_card(event["target"]); return {"cardId":card["id"],"cardIdTarget":target["id"],"playerIndex":card["playerIndex"],"serial":card["serial"],"serialTarget":target["serial"],"type":11}
        if kind == "evolve": return {"cardId":card["id"],"playerIndex":card["playerIndex"],"serial":card["serial"],"type":12}
        if kind == "attack": return {"attackId":event["attack_id"],"cardId":card["id"],"playerIndex":card["playerIndex"],"serial":card["serial"],"type":15}
        return {"cardId":card["id"],"playerIndex":card["playerIndex"],"putDamageCounter":event["put_damage_counter"],"serial":card["serial"],"type":16,"value":event["value"]}

    def _build_raw(self, fixture: dict[str, Any]) -> dict[str, Any]:
        current=fixture["current_source"]; acting=current["acting_player_index"]; stadium=current["stadium"]
        raw={"select":self._wire_select(fixture["select_source"]),"logs":[self._wire_log(event) for event in fixture["public_events"]],"current":{"energyAttached":current["energy_attached"],"firstPlayer":current["first_player_index"],"looking":None,"players":[self._wire_player(player,index,acting) for index,player in enumerate(current["players"])],"result":current["result"],"retreated":current["retreated"],"stadium":[] if stadium is None else [self._wire_card(stadium)],"stadiumPlayed":current["stadium_played"],"supporterPlayed":current["supporter_played"],"turn":current["turn"],"turnActionCount":current["turn_action_count"],"yourIndex":acting},"search_begin_input":None}
        if "step" in fixture: raw["step"]=fixture["step"]
        if "remainingOverageTime" in fixture: raw["remainingOverageTime"]=fixture["remainingOverageTime"]
        return raw


__all__ = ["GodotObservationProjector", "ObservationProjectorError", "ProjectorResult"]
