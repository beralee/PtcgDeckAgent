"""Public-only semantic turn-transaction journal.

The journal retains only durable semantic intent (transaction, method and
turn deadline).  Every call decomposes that intent against the fresh public
observation and binds the current legal option indexes anew.
"""

from __future__ import annotations

import copy
from typing import Any, Callable

from .cabt_tree_hash import CabtTreeHashError, public_observation_hash


ConditionMatcher = Callable[[list[dict[str, Any]], dict[str, Any] | None, str], bool]


class TurnTransactionJournal:
    """Match-scoped semantic state for HTN-like turn transactions."""

    def __init__(self, match_id: str, seat: int, package_identity: str) -> None:
        if not match_id or type(seat) is not int or seat < 0 or not package_identity:
            raise ValueError("invalid_turn_transaction_scope")
        self._scope = {
            "match_id": match_id,
            "seat": seat,
            "package_identity": package_identity,
        }
        self._state: dict[str, Any] = {}

    def snapshot(self) -> dict[str, Any]:
        return {
            "scope": copy.deepcopy(self._scope),
            "state": copy.deepcopy(self._state),
        }

    def clear(self) -> None:
        self._state = {}

    def advance(
        self,
        frame: dict[str, Any],
        definitions: list[dict[str, Any]],
        matches: ConditionMatcher,
    ) -> dict[str, Any]:
        if type(frame) is not dict or frame.get("seat") != self._scope["seat"]:
            return self._result(False, "turn_transaction_scope_mismatch", "rejected", "scope_mismatch")
        turn_number = frame.get("public_state", {}).get("turn_number")
        if type(turn_number) is not int or turn_number < 0:
            return self._result(False, "invalid_turn_transaction_frame", "rejected", "turn_unknown")

        definitions_by_id = {
            definition["transaction_id"]: definition for definition in definitions
        }
        event = "continued"
        active = definitions_by_id.get(self._state.get("transaction_id"))
        if active is not None:
            goal_id = active["goal_id"]
            if self._state.get("deadline_turn", turn_number) < turn_number:
                self.clear()
                active = None
                event = "expired"
            elif active["abort_when"] and matches(active["abort_when"], None, goal_id):
                self.clear()
                active = None
                event = "aborted"
            elif active["success_when"] and matches(active["success_when"], None, goal_id):
                self.clear()
                active = None
                event = "completed"
            elif (
                active.get("continue_when", active["when"])
                and not matches(
                    active.get("continue_when", active["when"]), None, goal_id
                )
            ):
                # A durable transaction retains semantic intent only. The
                # continuation predicate is re-proven from each fresh public
                # observation before the journal may own another window.
                self.clear()
                active = None
                event = "continuation_invalidated"
        elif self._state:
            self.clear()
            event = "definition_missing"

        if active is None:
            eligible = [
                definition
                for definition in definitions
                if matches(definition["when"], None, definition["goal_id"])
                and not (
                    definition["success_when"]
                    and matches(
                        definition["success_when"], None, definition["goal_id"]
                    )
                )
                and not (
                    definition["abort_when"]
                    and matches(definition["abort_when"], None, definition["goal_id"])
                )
            ]
            if eligible:
                active = min(
                    enumerate(eligible),
                    key=lambda pair: (-pair[1]["priority"], pair[0]),
                )[1]
                self._state = {
                    "transaction_id": active["transaction_id"],
                    "method_id": "",
                    "start_turn": turn_number,
                    "deadline_turn": turn_number + active["deadline_turns"],
                }
                event = "started"

        if active is None:
            return self._result(True, "", "idle", event)

        goal_id = active["goal_id"]
        method = self._method(active, matches)
        if method is None:
            self.clear()
            return self._result(True, "", "retired", "no_applicable_method")
        self._state["method_id"] = method["method_id"]

        required_steps = self._required_steps(method, matches)
        if not required_steps:
            self.clear()
            return self._result(True, "", "retired", "method_complete")
        step: dict[str, Any] | None = None
        current_indexes: list[int] = []
        minimum = frame.get("select_semantics", {}).get("min_count", 0)
        maximum = frame.get("select_semantics", {}).get("max_count", 0)
        for candidate_step in required_steps:
            if frame.get("prompt_kind") not in candidate_step["prompt_kinds"]:
                continue
            candidate_indexes = [
                option["index"]
                for option in frame.get("options", [])
                if matches(
                    candidate_step["option_when"], option, candidate_step["goal_id"]
                )
            ]
            grouped_indexes = self._selection_group_indexes(
                candidate_step,
                frame.get("options", []),
                candidate_indexes,
                matches,
            )
            if grouped_indexes is None:
                continue
            candidate_indexes = grouped_indexes
            selection_count = candidate_step["selection_count"]
            if selection_count is not None and (
                selection_count < minimum
                or selection_count > maximum
                or selection_count > len(candidate_indexes)
            ):
                continue
            if candidate_indexes:
                step = candidate_step
                current_indexes = candidate_indexes
                break

        if step is None:
            return self._result(
                True,
                "",
                "no_current_safe_step",
                "fresh_window_has_no_executable_binding",
                active,
                method,
                required_steps[0],
                [],
                False,
            )

        has_attack = any(
            option.get("kind") in {"attack", "granted_attack"}
            for option in frame["options"]
        )
        has_turn_commit = has_attack or any(
            option.get("kind") == "end_turn" for option in frame["options"]
        )
        attack_blocked = bool(step["required_before_attack"] and has_attack)
        turn_commit_blocked = bool(
            step["required_before_attack"] and has_turn_commit
        )
        return self._result(
            True,
            "",
            "step_bound",
            event,
            active,
            method,
            step,
            current_indexes,
            attack_blocked,
            turn_commit_blocked,
        )

    @staticmethod
    def _selection_group_indexes(
        step: dict[str, Any],
        options: list[dict[str, Any]],
        candidate_indexes: list[int],
        matches: ConditionMatcher,
    ) -> list[int] | None:
        groups = step.get("selection_groups", [])
        if not groups:
            return candidate_indexes
        allowed = set(candidate_indexes)
        used: set[int] = set()
        selected: list[int] = []
        for group in groups:
            group_indexes = [
                option["index"]
                for option in options
                if option["index"] in allowed
                and option["index"] not in used
                and matches(group["option_when"], option, step["goal_id"])
            ]
            count = group["selection_count"]
            if len(group_indexes) < count:
                return None
            for index in group_indexes[:count]:
                used.add(index)
                selected.append(index)
        return selected

    def _method(
        self, active: dict[str, Any], matches: ConditionMatcher
    ) -> dict[str, Any] | None:
        applicable = [
            method
            for method in active["methods"]
            if matches(method["when"], None, active["goal_id"])
        ]
        if not applicable:
            return None
        current_method_id = self._state.get("method_id")
        for method in applicable:
            if method["method_id"] == current_method_id:
                return method
        return min(
            enumerate(applicable),
            key=lambda pair: (-pair[1]["priority"], pair[0]),
        )[1]

    @staticmethod
    def _required_steps(
        method: dict[str, Any], matches: ConditionMatcher
    ) -> list[dict[str, Any]]:
        required: list[dict[str, Any]] = []
        for step in method["steps"]:
            if step["complete_when"] and matches(
                step["complete_when"], None, step["goal_id"]
            ):
                continue
            if step["required_when"] and not matches(
                step["required_when"], None, step["goal_id"]
            ):
                continue
            required.append(step)
        return required

    def _result(
        self,
        accepted: bool,
        error_code: str,
        event: str,
        reason: str,
        active: dict[str, Any] | None = None,
        method: dict[str, Any] | None = None,
        step: dict[str, Any] | None = None,
        current_indexes: list[int] | None = None,
        attack_commit_blocked: bool = False,
        turn_commit_blocked: bool = False,
    ) -> dict[str, Any]:
        payload = {
            "accepted": accepted,
            "error_code": error_code,
            "event": event,
            "reason": reason,
            "transaction_id": None if active is None else active["transaction_id"],
            "method_id": None if method is None else method["method_id"],
            "step_id": None if step is None else step["step_id"],
            "goal_id": None if step is None else step["goal_id"],
            "current_indexes": [] if current_indexes is None else list(current_indexes),
            "selection_count": None if step is None else step["selection_count"],
            "score_bonus": 0 if step is None else step["score_bonus"],
            "terminal": False if step is None else step["terminal"],
            "checkpoint": False if step is None else step["checkpoint"],
            "sequence_barrier": (
                False if step is None else step.get("sequence_barrier", False)
            ),
            "required_before_attack": (
                False if step is None else step["required_before_attack"]
            ),
            "attack_commit_blocked": attack_commit_blocked,
            "turn_commit_blocked": turn_commit_blocked,
            "state": copy.deepcopy(self._state),
            "public_current_window_only": True,
            "reobserve_after_commit": True,
            "stale_index_authority": False,
        }
        try:
            audit_hash = public_observation_hash(payload)
        except CabtTreeHashError:
            audit_hash = ""
        return {**payload, "audit_hash": audit_hash}


__all__ = ["TurnTransactionJournal"]
