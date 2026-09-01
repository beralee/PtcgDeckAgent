from __future__ import annotations

import copy
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import re
from typing import Any

from .cabt_tree_hash import public_observation_hash


REGISTRY_PATH = Path(__file__).resolve().parents[3] / "contracts" / "ptcgdap" / "public_damage_capability_registry_v1.json"
MAX_SAFE_INTEGER = 9_007_199_254_740_991
IDENTIFIER = re.compile(r"^[a-z0-9][a-z0-9._-]{0,127}$")
UID = re.compile(r"^[A-Za-z0-9.]+_[A-Za-z0-9._]+$")
PRIVATE_KEYS = frozenset(
    {
        "deck_order",
        "private_state",
        "search_begin_input",
        "callback",
        "binding",
        "ticket",
        "command",
        "object_ref",
        "instance_id",
        "raw_private_hash",
    }
)
CAPABILITY_IDS = frozenset(
    {
        "attack.fixed_split.v1",
        "attack.bench_heal.v1",
        "between_turn.ability_counter.v1",
        "ability.move_damage_counters.v1",
        "tool.conditional_active_damage_bonus.v1",
        "attack.mass_devolution.v1",
    }
)
OBJECTIVES = (
    "attack_windows",
    "prize_yield",
    "remaining_debt",
    "overkill",
    "response_risk",
)
TARGET_ROLES = frozenset({"opponent.active", "opponent.bench"})
TRANSACTION_TARGET_ROLES = frozenset({"opponent.pokemon", "self.pokemon"})
TRANSACTION_STATE_KEYS = frozenset(
    {
        "transaction_id",
        "goal_id",
        "phase",
        "target_entity_serial",
        "remaining_damage_debt",
        "remaining_energy_debt",
        "deadline_turn",
    }
)


def _canonical(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def _sha(value: Any) -> str:
    return hashlib.sha256(_canonical(value)).hexdigest().upper()


def _tree_sha(value: Any) -> str:
    return public_observation_hash(value)


def _safe_int(value: Any) -> bool:
    return type(value) is int and 0 <= value <= MAX_SAFE_INTEGER


def _contains_private(value: Any) -> bool:
    stack = [value]
    while stack:
        current = stack.pop()
        if type(current) is dict:
            for key, child in current.items():
                if type(key) is not str or key.casefold() in PRIVATE_KEYS:
                    return True
                stack.append(child)
        elif type(current) is list:
            stack.extend(current)
    return False


def _error(code: str) -> dict[str, Any]:
    return {"accepted": False, "error_code": code, "facts": {}, "options": {}, "targets": {}, "audit_hash": ""}


@dataclass(frozen=True, slots=True)
class PublicDamageCapabilityRegistry:
    _document: dict[str, Any]

    @classmethod
    def load_default(cls) -> "PublicDamageCapabilityRegistry":
        return cls(json.loads(REGISTRY_PATH.read_text(encoding="utf-8")))

    @property
    def registry_sha256(self) -> str:
        return str(self._document.get("registry_sha256", "")) if self.validate_integrity() else ""

    @property
    def capabilities(self) -> frozenset[str]:
        return frozenset(self._document.get("capabilities", [])) if self.validate_integrity() else frozenset()

    def card(self, uid: str) -> dict[str, Any]:
        value = self._document.get("cards", {}).get(uid, {})
        return copy.deepcopy(value) if self.validate_integrity() and type(value) is dict else {}

    def validate_integrity(self) -> bool:
        value = self._document
        if (
            type(value) is not dict
            or value.get("schema_version") != 1
            or value.get("profile_id") != "ptcgdap-public-damage-capability-registry-v1"
            or value.get("card_identity_domain") != "godot_local_card_uid_v1"
            or type(value.get("cards")) is not dict
            or type(value.get("capabilities")) is not list
            or set(value.get("capabilities", [])) != set(CAPABILITY_IDS)
        ):
            return False
        expected = value.get("registry_sha256")
        payload = {key: child for key, child in value.items() if key != "registry_sha256"}
        if expected != _sha(payload):
            return False
        for uid, card in value["cards"].items():
            if not UID.fullmatch(uid) or type(card) is not dict:
                return False
            if any(capability not in CAPABILITY_IDS for capability in card.get("capability_ids", [])):
                return False
        return True


class PublicDamagePlanner:
    @staticmethod
    def calculate(
        frame: Any,
        damage_plans: Any,
        registry: PublicDamageCapabilityRegistry,
    ) -> dict[str, Any]:
        if _contains_private(frame) or _contains_private(damage_plans):
            return _error("private_damage_plan_input")
        if type(frame) is not dict or not registry.validate_integrity():
            return _error("invalid_damage_plan_input")
        plan_error = _damage_plan_error(damage_plans, registry.capabilities)
        if plan_error:
            return _error(plan_error)
        own = frame.get("public_state", {}).get("self", {})
        opponent = frame.get("public_state", {}).get("opponent", {})
        if type(own) is not dict or type(opponent) is not dict:
            return _error("invalid_damage_plan_input")
        own_slots = _slots(own)
        opponent_slots = _slots(opponent)
        all_slots = [*own_slots, *opponent_slots]
        if any(not registry.card(str(slot.get("local_card_uid", ""))) for slot in all_slots):
            return _error("unknown_damage_card_uid")

        froslass_checks = sum(
            1
            for slot in all_slots
            if "between_turn.ability_counter.v1"
            in registry.card(str(slot.get("local_card_uid", ""))).get("capability_ids", [])
        )
        movable_counters = sum(max(0, int(slot.get("damage_counters", 0))) // 10 for slot in own_slots)
        ready_movers = 0
        for slot in own_slots:
            card = registry.card(str(slot.get("local_card_uid", "")))
            if "ability.move_damage_counters.v1" not in card.get("capability_ids", []):
                continue
            if "CSVE1C_DAR" in slot.get("attached_energy_uids", []):
                ready_movers += 1
        available_movers = ready_movers
        if frame.get("prompt_kind") in {"main", "main_action"}:
            legal_mover_entities: set[int] = set()
            own_by_entity = {int(slot["entity_serial"]): slot for slot in own_slots}
            for option in frame.get("options", []):
                if type(option) is not dict or option.get("kind") != "use_ability":
                    continue
                source_entity = option.get("source_entity_serial")
                source_slot = own_by_entity.get(source_entity) if type(source_entity) is int else None
                source_uid = str(option.get("source_uid") or (
                    source_slot.get("local_card_uid", "") if source_slot is not None else ""
                ))
                source_card = registry.card(source_uid)
                if (
                    source_slot is not None
                    and "ability.move_damage_counters.v1" in source_card.get("capability_ids", [])
                    and "CSVE1C_DAR" in source_slot.get("attached_energy_uids", [])
                ):
                    legal_mover_entities.add(int(source_entity))
            available_movers = len(legal_mover_entities)
        transferable = min(movable_counters, available_movers * 3)
        best_transfer = min(3, transferable)
        bench_heal_amount = _ready_bench_heal_amount(opponent, registry)

        option_metrics: dict[str, dict[str, Any]] = {}
        target_metrics: dict[str, dict[str, Any]] = {}
        transfer_target_metrics: dict[str, dict[str, Any]] = {}
        active_target = opponent_slots[0] if opponent.get("active") else None
        active_entity = active_target.get("entity_serial") if active_target is not None else None
        for target in opponent_slots:
            metrics = _target_metrics(
                target,
                registry,
                froslass_checks,
                transferable,
                projected_damage=0,
                opponent_prizes=int(opponent.get("prizes_remaining", 0)),
                is_bench=target.get("entity_serial") != active_entity,
                bench_heal_amount=bench_heal_amount,
            )
            target_metrics[str(target["entity_serial"])] = metrics
            transfer_target_metrics[str(target["entity_serial"])] = copy.deepcopy(metrics)

        for option in frame.get("options", []):
            if type(option) is not dict or not _safe_int(option.get("index")):
                return _error("invalid_damage_plan_input")
            target = _target_for_option(option, own_slots, opponent_slots)
            projected = _projected_damage(option, target, own, opponent, own_slots, registry)
            metrics = _target_metrics(
                target,
                registry,
                froslass_checks,
                transferable,
                projected_damage=projected,
                opponent_prizes=int(opponent.get("prizes_remaining", 0)),
                is_bench=target.get("entity_serial") != active_entity,
                bench_heal_amount=bench_heal_amount,
            ) if target is not None else _neutral_option_metrics()
            metrics["bench_damage"] = _projected_bench_damage(
                option,
                own_slots,
                opponent,
                registry,
            )
            option_metrics[str(option["index"])] = metrics
            if target is not None:
                current = target_metrics.get(str(target["entity_serial"]), {})
                if not current or _target_sort_key(metrics) < _target_sort_key(current):
                    target_metrics[str(target["entity_serial"])] = copy.deepcopy(metrics)

        best_target: dict[str, Any] = {}
        for metrics in target_metrics.values():
            if not best_target or _target_sort_key(metrics) < _target_sort_key(best_target):
                best_target = metrics
        best_transfer_target: dict[str, Any] = {}
        for metrics in transfer_target_metrics.values():
            if not best_transfer_target or _target_sort_key(metrics) < _target_sort_key(best_transfer_target):
                best_transfer_target = metrics

        attack_options = [
            option for option in frame.get("options", [])
            if type(option) is dict and option.get("kind") in {"attack", "granted_attack"}
        ]
        current_attack_damage = max(
            (
                _projected_damage(option, active_target, own, opponent, own_slots, registry)
                for option in attack_options
            ),
            default=0,
        )
        current_attack_bench_damage = max(
            (
                int(option_metrics[str(option["index"])].get("bench_damage", 0))
                for option in attack_options
            ),
            default=0,
        )
        gust_target_metrics: dict[str, dict[str, Any]] = {}
        for target in opponent.get("bench", []):
            if type(target) is not dict or not _safe_int(target.get("entity_serial")):
                continue
            target_damage = 0
            for option in attack_options:
                rebound = copy.deepcopy(option)
                rebound["projected_damage"] = None
                target_damage = max(
                    target_damage,
                    _projected_damage(rebound, target, own, opponent, own_slots, registry),
                )
            gust_target_metrics[str(target["entity_serial"])] = _target_metrics(
                target,
                registry,
                0,
                0,
                projected_damage=target_damage,
                opponent_prizes=int(opponent.get("prizes_remaining", 0)),
                is_bench=False,
                bench_heal_amount=0,
            )
        best_gust_target: dict[str, Any] = {}
        for metrics in gust_target_metrics.values():
            if not best_gust_target or _target_sort_key(metrics) < _target_sort_key(best_gust_target):
                best_gust_target = metrics
        facts = {
            "damage.movable_counter_count": transferable,
            "damage.available_mover_count": available_movers,
            "damage.froslass_check_count": froslass_checks,
            "damage.best_transfer_count": best_transfer,
            "damage.best_transfer_target_entity_serial": best_transfer_target.get("target_entity_serial"),
            "damage.best_transfer_attack_windows_to_ko": best_transfer_target.get("attack_windows_to_ko"),
            "damage.best_transfer_prize_yield": best_transfer_target.get("prize_yield"),
            "damage.best_transfer_remaining_debt": best_transfer_target.get("remaining_debt"),
            "damage.best_target_entity_serial": best_target.get("target_entity_serial"),
            "damage.best_attack_windows_to_ko": best_target.get("attack_windows_to_ko"),
            "damage.best_prize_yield": best_target.get("prize_yield"),
            "damage.best_remaining_debt": best_target.get("remaining_debt"),
            "damage.current_attack_damage": current_attack_damage,
            "damage.current_attack_bench_damage": current_attack_bench_damage,
            "damage.best_gust_target_entity_serial": best_gust_target.get("target_entity_serial"),
            "damage.best_gust_attack_windows_to_ko": best_gust_target.get("attack_windows_to_ko"),
            "damage.best_gust_prize_yield": best_gust_target.get("prize_yield"),
            "damage.best_gust_remaining_debt": best_gust_target.get("remaining_debt"),
        }
        audit_payload = {
            "schema_version": 1,
            "profile_id": "ptcgdap-public-damage-plan-v1",
            "registry_sha256": registry.registry_sha256,
            "public_observation_hash": frame.get("source", {}).get("public_observation_hash"),
            "window_id": frame.get("source", {}).get("window_id"),
            "plan_ids": [plan["plan_id"] for plan in damage_plans],
            "facts": facts,
            "options": option_metrics,
            "targets": target_metrics,
            "public_only": True,
        }
        return {
            "accepted": True,
            "error_code": "",
            "facts": facts,
            "options": option_metrics,
            "targets": target_metrics,
            "best_target_entity_serial": best_target.get("target_entity_serial"),
            "audit_hash": _tree_sha(audit_payload),
            "audit": audit_payload,
        }


def _damage_plan_error(value: Any, capabilities: frozenset[str]) -> str:
    if type(value) is not list or not value or len(value) > 32:
        return "invalid_damage_plan"
    seen: set[str] = set()
    required_keys = {
        "plan_id",
        "goal_id",
        "priority",
        "horizon_attack_windows",
        "capability_ids",
        "target_roles",
        "objective_order",
    }
    for plan in value:
        if type(plan) is not dict or set(plan) != required_keys:
            return "invalid_damage_plan"
        plan_id = plan["plan_id"]
        if not IDENTIFIER.fullmatch(str(plan_id)) or plan_id in seen:
            return "invalid_damage_plan"
        seen.add(plan_id)
        raw_caps = plan["capability_ids"]
        if type(raw_caps) is not list or not raw_caps or len(raw_caps) != len(set(raw_caps)):
            return "invalid_damage_plan"
        if any(capability not in capabilities for capability in raw_caps):
            return "unknown_damage_capability"
        if (
            not IDENTIFIER.fullmatch(str(plan["goal_id"]))
            or not _safe_int(plan["priority"])
            or plan["horizon_attack_windows"] not in [1, 2]
            or type(plan["target_roles"]) is not list
            or not plan["target_roles"]
            or any(role not in TARGET_ROLES for role in plan["target_roles"])
            or plan["objective_order"] != list(OBJECTIVES)
        ):
            return "invalid_damage_plan"
    return ""


def validate_damage_plans(
    value: Any,
    registry: PublicDamageCapabilityRegistry | None = None,
) -> str:
    trusted = registry if registry is not None else PublicDamageCapabilityRegistry.load_default()
    if not trusted.validate_integrity():
        return "invalid_damage_capability_registry"
    return _damage_plan_error(value, trusted.capabilities)


def _slots(player: dict[str, Any]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for zone in ("active", "bench"):
        values = player.get(zone, [])
        if type(values) is not list:
            continue
        for value in values:
            if (
                type(value) is dict
                and _safe_int(value.get("entity_serial"))
                and value.get("entity_serial", 0) > 0
                and UID.fullmatch(str(value.get("local_card_uid", "")))
            ):
                result.append(value)
    return result


def _target_for_option(
    option: dict[str, Any],
    own_slots: list[dict[str, Any]],
    opponent_slots: list[dict[str, Any]],
) -> dict[str, Any] | None:
    entity = option.get("target_entity_serial")
    if _safe_int(entity) and entity > 0:
        for slot in [*own_slots, *opponent_slots]:
            if slot.get("entity_serial") == entity:
                return slot
    if option.get("kind") in {"attack", "granted_attack"} and opponent_slots:
        return opponent_slots[0]
    return None


def _projected_damage(
    option: dict[str, Any],
    target: dict[str, Any] | None,
    own: dict[str, Any],
    opponent: dict[str, Any],
    own_slots: list[dict[str, Any]],
    registry: PublicDamageCapabilityRegistry,
) -> int:
    if target is None or option.get("kind") not in {"attack", "granted_attack"}:
        return 0
    # The Host builds this value from the current legal attack option after
    # weakness, resistance, prevention and other public modifiers.  When it
    # is present it is more specific than catalog base damage and must remain
    # authoritative, including the meaningful value zero.
    option_projected = option.get("projected_damage")
    if _safe_int(option_projected):
        return int(option_projected)
    source: dict[str, Any] | None = None
    source_entity = option.get("source_entity_serial")
    for slot in own_slots:
        if slot.get("entity_serial") == source_entity or slot.get("serial") == option.get("source_serial"):
            source = slot
            break
    if source is None:
        return 0
    source_card = registry.card(str(source.get("local_card_uid", "")))
    attack_index = option.get("attack_index")
    attack = next(
        (row for row in source_card.get("attacks", []) if row.get("attack_index") == attack_index),
        None,
    )
    if type(attack) is not dict or type(attack.get("active_damage")) is not int:
        return 0
    damage = max(0, int(attack["active_damage"]))
    tool_uid = source.get("attached_tool_uid")
    if type(tool_uid) is str:
        tool = registry.card(tool_uid)
        if (
            "tool.conditional_active_damage_bonus.v1" in tool.get("capability_ids", [])
            and int(own.get("prizes_remaining", 0)) > int(opponent.get("prizes_remaining", 0))
        ):
            damage += 30
    target_card = registry.card(str(target.get("local_card_uid", "")))
    source_type = str(source_card.get("energy_type", ""))
    if source_type and source_type == target_card.get("weakness_energy"):
        damage *= int(target_card.get("weakness_multiplier", 1))
    if source_type and source_type == target_card.get("resistance_energy"):
        damage = max(0, damage - int(target_card.get("resistance_reduction", 0)))
    return damage


def _projected_bench_damage(
    option: dict[str, Any],
    own_slots: list[dict[str, Any]],
    opponent: dict[str, Any],
    registry: PublicDamageCapabilityRegistry,
) -> int:
    """Return trusted public secondary bench damage for the current attack.

    Active damage remains owned by the Host's post-modifier projection.  This
    independent field preserves a fixed split attack's still-productive public
    bench effect when active damage is prevented.
    """
    if option.get("kind") not in {"attack", "granted_attack"}:
        return 0
    opponent_bench = opponent.get("bench", [])
    if type(opponent_bench) is not list or not any(type(slot) is dict for slot in opponent_bench):
        return 0
    source_uid = str(option.get("source_uid") or "")
    if not source_uid:
        for slot in own_slots:
            if (
                slot.get("entity_serial") == option.get("source_entity_serial")
                or slot.get("serial") == option.get("source_serial")
            ):
                source_uid = str(slot.get("local_card_uid", ""))
                break
    source_card = registry.card(source_uid)
    if "attack.fixed_split.v1" not in source_card.get("capability_ids", []):
        return 0
    attack_index = option.get("attack_index")
    attack = next(
        (row for row in source_card.get("attacks", []) if row.get("attack_index") == attack_index),
        None,
    )
    if type(attack) is not dict or type(attack.get("bench_damage")) is not int:
        return 0
    return max(0, int(attack["bench_damage"]))


def _target_metrics(
    target: dict[str, Any] | None,
    registry: PublicDamageCapabilityRegistry,
    froslass_checks: int,
    transferable: int,
    *,
    projected_damage: int,
    opponent_prizes: int,
    is_bench: bool = False,
    bench_heal_amount: int = 0,
) -> dict[str, Any]:
    if target is None:
        return _neutral_option_metrics()
    remaining_hp = max(0, int(target.get("remaining_hp", 0)))
    target_card = registry.card(str(target.get("local_card_uid", "")))
    check_damage = froslass_checks * 10 if bool(target_card.get("has_ability", False)) else 0
    remaining_debt = max(0, remaining_hp - projected_damage)
    transfer_used = min(transferable, (remaining_debt + 9) // 10) if remaining_debt > 0 else 0
    immediate_total = projected_damage + transfer_used * 10
    heal_threat = is_bench and bench_heal_amount > 0 and immediate_total < remaining_hp
    total = immediate_total
    check_used = check_damage if total < remaining_hp and not heal_threat else 0
    total += check_used
    if total >= remaining_hp and total > 0:
        windows = 1
    elif projected_damage > 0:
        windows = 2
    else:
        windows = 3
    overkill = max(0, total - remaining_hp)
    prize_value = min(max(1, int(target.get("prize_value", 1))), 3)
    response_risk = max(0, 3 - min(opponent_prizes, 3))
    if bool(target_card.get("has_ability", False)):
        response_risk += 1
    if heal_threat:
        response_risk += 100 + min(bench_heal_amount, 400)
    return {
        "target_entity_serial": int(target.get("entity_serial", 0)),
        "projected_damage": projected_damage,
        "attack_windows_to_ko": windows,
        "prize_yield": prize_value,
        "remaining_debt": remaining_debt,
        "overkill": overkill,
        "response_risk": response_risk,
        "between_turn_damage": check_used,
        "transferable_damage": transfer_used * 10,
    }


def _ready_bench_heal_amount(
    opponent: dict[str, Any],
    registry: PublicDamageCapabilityRegistry,
) -> int:
    active = opponent.get("active", [])
    if type(active) is not list or not active or type(active[0]) is not dict:
        return 0
    slot = active[0]
    card = registry.card(str(slot.get("local_card_uid", "")))
    if "attack.bench_heal.v1" not in card.get("capability_ids", []):
        return 0
    attached = int(slot.get("attached_energy_count", 0))
    amount = 0
    for attack in card.get("attacks", []):
        if type(attack) is not dict or type(attack.get("bench_heal_amount")) is not int:
            continue
        cost = str(attack.get("cost", ""))
        if attached >= len(cost):
            amount = max(amount, int(attack["bench_heal_amount"]))
    return amount


def _neutral_option_metrics() -> dict[str, Any]:
    return {
        "target_entity_serial": None,
        "projected_damage": 0,
        "bench_damage": 0,
        "attack_windows_to_ko": 3,
        "prize_yield": 0,
        "remaining_debt": 0,
        "overkill": 0,
        "response_risk": 0,
        "between_turn_damage": 0,
        "transferable_damage": 0,
    }


def _target_sort_key(value: dict[str, Any]) -> tuple[int, int, int, int, int, int]:
    serial = value.get("target_entity_serial")
    return (
        int(value.get("attack_windows_to_ko", 3)),
        -int(value.get("prize_yield", 0)),
        int(value.get("remaining_debt", 0)),
        int(value.get("overkill", 0)),
        int(value.get("response_risk", 0)),
        int(serial) if type(serial) is int else MAX_SAFE_INTEGER,
    )


class SemanticTransactionJournal:
    def __init__(self, match_id: str, seat: int, package_identity: str) -> None:
        self._match_id = match_id
        self._seat = seat
        self._package_identity = package_identity
        self._state: dict[str, Any] = {}

    def snapshot(self) -> dict[str, Any]:
        return copy.deepcopy(self._state)

    def clear(self) -> None:
        self._state.clear()

    def advance(
        self,
        frame: Any,
        definitions: Any,
        damage_result: Any,
    ) -> dict[str, Any]:
        if _contains_private(frame) or _contains_private(definitions) or _contains_private(damage_result):
            return self._result(False, "private_transaction_input", "reject", "private_input", {})
        if (
            type(frame) is not dict
            or frame.get("seat") != self._seat
            or not self._match_id
            or not self._package_identity
        ):
            return self._result(False, "scope_mismatch", "reject", "scope_mismatch", self._state)
        error = _transaction_error(definitions)
        if error:
            return self._result(False, error, "reject", error, self._state)
        if type(damage_result) is not dict or not damage_result.get("accepted"):
            return self._result(False, "damage_plan_unavailable", "reject", "damage_plan_unavailable", self._state)
        turn = int(frame.get("public_state", {}).get("turn_number", 0))
        targets = damage_result.get("targets", {})
        if self._state:
            definition = next(
                (
                    row
                    for row in definitions
                    if row.get("transaction_id") == self._state.get("transaction_id")
                ),
                None,
            )
            if type(definition) is not dict:
                previous = copy.deepcopy(self._state)
                self.clear()
                return self._result(True, "", "abort", "definition_unavailable", previous)
            entity = str(self._state["target_entity_serial"])
            candidate = _transaction_candidate(
                frame,
                damage_result,
                str(definition["target_role"]),
                int(self._state["target_entity_serial"]),
            )
            if not candidate:
                previous = copy.deepcopy(self._state)
                self.clear()
                return self._result(True, "", "abort", "target_unavailable", previous)
            if turn > int(self._state["deadline_turn"]):
                previous = copy.deepcopy(self._state)
                self.clear()
                return self._result(True, "", "abort", "deadline_expired", previous)
            old_debt = int(self._state["remaining_damage_debt"])
            old_energy_debt = int(self._state["remaining_energy_debt"])
            self._state["remaining_damage_debt"] = int(
                candidate.get("remaining_damage_debt", old_debt)
            )
            self._state["remaining_energy_debt"] = int(
                candidate.get("remaining_energy_debt", old_energy_debt)
            )
            if definition["abort_when"] and _transaction_conditions_match(
                definition["abort_when"], frame, damage_result, self._state, candidate
            ):
                aborted = copy.deepcopy(self._state)
                self.clear()
                return self._result(True, "", "abort", "abort_condition", aborted)
            if definition["success_when"] and _transaction_conditions_match(
                definition["success_when"], frame, damage_result, self._state, candidate
            ):
                self._state["phase"] = "complete"
                complete = copy.deepcopy(self._state)
                self.clear()
                return self._result(True, "", "complete", "success_condition", complete)
            if definition["continue_when"] and not _transaction_conditions_match(
                definition["continue_when"], frame, damage_result, self._state, candidate
            ):
                aborted = copy.deepcopy(self._state)
                self.clear()
                return self._result(True, "", "abort", "continuation_invalid", aborted)
            self._state["phase"] = "active"
            changed = (
                int(self._state["remaining_damage_debt"]) != old_debt
                or int(self._state["remaining_energy_debt"]) != old_energy_debt
            )
            reason = (
                "fresh_public_observation"
                if frame.get("prompt_kind") in definition["step_prompt_kinds"]
                else "prompt_not_actionable"
            )
            return self._result(
                True, "", "replan" if changed else "continue", reason, self._state
            )

        eligible: list[tuple[int, int, str, dict[str, Any], dict[str, Any]]] = []
        for definition in definitions:
            if frame.get("prompt_kind") not in definition["step_prompt_kinds"]:
                continue
            for candidate in _transaction_candidates(
                frame, damage_result, str(definition["target_role"])
            ):
                if _transaction_conditions_match(
                    definition["start_when"], frame, damage_result, {}, candidate
                ):
                    eligible.append(
                        (
                            -int(definition["priority"]),
                            int(candidate["target_entity_serial"]),
                            str(definition["transaction_id"]),
                            definition,
                            candidate,
                        )
                    )
        if not eligible:
            return self._result(True, "", "idle", "no_eligible_transaction", {})
        _, _, _, definition, candidate = min(eligible)
        self._state = {
            "transaction_id": definition["transaction_id"],
            "goal_id": definition["goal_id"],
            "phase": "active",
            "target_entity_serial": int(candidate["target_entity_serial"]),
            "remaining_damage_debt": int(candidate.get("remaining_damage_debt", 0)),
            "remaining_energy_debt": int(candidate.get("remaining_energy_debt", 0)),
            "deadline_turn": turn + int(definition["max_own_turns"]) - 1,
        }
        if set(self._state) != set(TRANSACTION_STATE_KEYS):
            self.clear()
            return self._result(False, "invalid_transaction_state", "reject", "invalid_state", {})
        return self._result(True, "", "start", "best_public_route", self._state)

    def _result(
        self,
        accepted: bool,
        error_code: str,
        event: str,
        reason: str,
        state: dict[str, Any],
    ) -> dict[str, Any]:
        payload = {
            "schema_version": 1,
            "event": event,
            "reason": reason,
            "state": copy.deepcopy(state),
            "public_only": True,
        }
        return {
            "accepted": accepted,
            "error_code": error_code,
            "event": event,
            "reason": reason,
            "state": copy.deepcopy(state),
            "audit_hash": _tree_sha(payload),
        }


def _transaction_error(value: Any) -> str:
    required = {
        "transaction_id",
        "goal_id",
        "priority",
        "max_own_turns",
        "target_role",
        "start_when",
        "continue_when",
        "success_when",
        "abort_when",
        "step_prompt_kinds",
    }
    if type(value) is not list or not value or len(value) > 32:
        return "invalid_semantic_transaction"
    seen: set[str] = set()
    for definition in value:
        if type(definition) is not dict or set(definition) != required:
            return "invalid_semantic_transaction"
        identifier = definition["transaction_id"]
        if not IDENTIFIER.fullmatch(str(identifier)) or identifier in seen:
            return "invalid_semantic_transaction"
        seen.add(identifier)
        if (
            not IDENTIFIER.fullmatch(str(definition["goal_id"]))
            or not _safe_int(definition["priority"])
            or definition["max_own_turns"] not in [1, 2]
            or definition["target_role"] not in TRANSACTION_TARGET_ROLES
            or type(definition["step_prompt_kinds"]) is not list
            or not definition["step_prompt_kinds"]
        ):
            return "invalid_semantic_transaction"
        for key in ("start_when", "continue_when", "success_when", "abort_when"):
            if type(definition[key]) is not list or len(definition[key]) > 32:
                return "invalid_semantic_transaction"
    return ""


def _transaction_candidates(
    frame: dict[str, Any],
    damage_result: dict[str, Any],
    target_role: str,
) -> list[dict[str, Any]]:
    if target_role == "opponent.pokemon":
        result = []
        for raw in damage_result.get("targets", {}).values():
            if type(raw) is not dict or not _safe_int(raw.get("target_entity_serial")):
                continue
            row = copy.deepcopy(raw)
            row["card_uid"] = _entity_card_uid(
                frame, "opponent", int(row["target_entity_serial"])
            )
            row["remaining_damage_debt"] = int(row.get("remaining_debt", 0))
            row["remaining_energy_debt"] = 0
            serial = int(row["target_entity_serial"])
            facts = damage_result.get("facts", {})
            row["is_damage_best"] = serial == facts.get("damage.best_target_entity_serial")
            row["is_transfer_best"] = serial == facts.get("damage.best_transfer_target_entity_serial")
            row["is_gust_best"] = serial == facts.get("damage.best_gust_target_entity_serial")
            result.append(row)
        return sorted(result, key=lambda row: _target_sort_key(row))
    result = []
    own = frame.get("public_state", {}).get("self", {})
    for slot in _slots(own if type(own) is dict else {}):
        result.append(
            {
                "target_entity_serial": int(slot["entity_serial"]),
                "card_uid": str(slot.get("local_card_uid", "")),
                "remaining_damage_debt": 0,
                "remaining_energy_debt": max(0, int(slot.get("energy_debt", 0))),
                "prize_yield": int(slot.get("prize_value", 1)),
            }
        )
    return sorted(result, key=lambda row: int(row["target_entity_serial"]))


def _transaction_candidate(
    frame: dict[str, Any],
    damage_result: dict[str, Any],
    target_role: str,
    entity_serial: int,
) -> dict[str, Any]:
    return next(
        (
            row
            for row in _transaction_candidates(frame, damage_result, target_role)
            if row.get("target_entity_serial") == entity_serial
        ),
        {},
    )


def _entity_card_uid(frame: dict[str, Any], owner: str, entity_serial: int) -> str:
    state = frame.get("public_state", {}).get(owner, {})
    if type(state) is not dict:
        return ""
    return next(
        (
            str(slot.get("local_card_uid", ""))
            for slot in _slots(state)
            if slot.get("entity_serial") == entity_serial
        ),
        "",
    )


def _transaction_conditions_match(
    conditions: list[dict[str, Any]],
    frame: dict[str, Any],
    damage_result: dict[str, Any],
    state: dict[str, Any],
    candidate: dict[str, Any],
) -> bool:
    return all(
        _transaction_compare(
            _transaction_fact(
                str(condition.get("fact", "")),
                condition.get("card_uid"),
                frame,
                damage_result,
                state,
                candidate,
            ),
            str(condition.get("op", "")),
            condition.get("value"),
        )
        for condition in conditions
    )


def _transaction_fact(
    fact: str,
    card_uid: Any,
    frame: dict[str, Any],
    damage_result: dict[str, Any],
    state: dict[str, Any],
    candidate: dict[str, Any],
) -> Any:
    if fact.startswith("damage."):
        return damage_result.get("facts", {}).get(fact)
    if fact.startswith("transaction.candidate."):
        return candidate.get(fact.removeprefix("transaction.candidate."))
    if fact.startswith("transaction."):
        return state.get(fact.removeprefix("transaction."))
    public = frame.get("public_state", {})
    own = public.get("self", {})
    opponent = public.get("opponent", {})
    scalars = {
        "prompt_kind": frame.get("prompt_kind"),
        "turn_number": public.get("turn_number"),
        "self.prizes_remaining": own.get("prizes_remaining") if type(own) is dict else None,
        "opponent.prizes_remaining": opponent.get("prizes_remaining") if type(opponent) is dict else None,
    }
    if fact in scalars:
        return scalars[fact]
    match = re.fullmatch(r"(self|opponent)\.(hand|discard|board)\.count_uid", fact)
    if match and type(card_uid) is str:
        state_owner = public.get(match.group(1), {})
        if type(state_owner) is not dict:
            return 0
        zone = match.group(2)
        values = _slots(state_owner) if zone == "board" else state_owner.get(zone, [])
        return sum(
            1
            for row in values
            if type(row) is dict and row.get("local_card_uid") == card_uid
        )
    return None


def _transaction_compare(actual: Any, op: str, expected: Any) -> bool:
    if op == "eq":
        return actual == expected
    if op == "ne":
        return actual != expected
    if type(actual) is int and type(expected) is int:
        return {
            "lt": actual < expected,
            "lte": actual <= expected,
            "gt": actual > expected,
            "gte": actual >= expected,
        }.get(op, False)
    if op == "contains" and type(actual) in {list, str}:
        return expected in actual
    if op == "not_contains" and type(actual) in {list, str}:
        return expected not in actual
    return False


def validate_semantic_transactions(value: Any) -> str:
    return _transaction_error(value)


__all__ = [
    "PublicDamageCapabilityRegistry",
    "PublicDamagePlanner",
    "SemanticTransactionJournal",
    "validate_damage_plans",
    "validate_semantic_transactions",
]
