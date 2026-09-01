from __future__ import annotations

import copy
import hashlib
from dataclasses import dataclass
from typing import Any, Mapping

from .cabt_tree_hash import jcs_canonical_json_bytes


class A3MatchPlanError(RuntimeError):
    pass


def _hash(value: Any) -> str:
    return hashlib.sha256(jcs_canonical_json_bytes(value)).hexdigest().upper()


def _private_entries(value: Any) -> list[dict[str, Any]]:
    if type(value) is not list or not value or len(value) > 60:
        raise A3MatchPlanError("a3_match_plan_private_deck_invalid")
    result: list[dict[str, Any]] = []
    seen: set[str] = set()
    total = 0
    for row in value:
        if type(row) is not dict or set(row) != {"set_code", "card_index", "count"}:
            raise A3MatchPlanError("a3_match_plan_private_deck_invalid")
        set_code = row.get("set_code")
        card_index = row.get("card_index")
        count = row.get("count")
        if (
            type(set_code) is not str or not set_code
            or type(card_index) is not str or not card_index
            or type(count) is not int or count <= 0 or count > 60
        ):
            raise A3MatchPlanError("a3_match_plan_private_deck_invalid")
        uid = f"{set_code}_{card_index}"
        if uid in seen:
            raise A3MatchPlanError("a3_match_plan_private_deck_invalid")
        seen.add(uid)
        total += count
        result.append(copy.deepcopy(row))
    if total != 60:
        raise A3MatchPlanError("a3_match_plan_private_deck_invalid")
    return result


def _official_deck(value: Any) -> list[int]:
    if (
        type(value) is not list or len(value) != 60
        or any(type(card_id) is not int or card_id <= 0 for card_id in value)
    ):
        raise A3MatchPlanError("a3_match_plan_official_deck_invalid")
    return list(value)


@dataclass(frozen=True, slots=True)
class A3MatchPlan:
    plan_sha256: str
    official_start: Mapping[str, Any]
    godot_start: Mapping[str, Any]
    relation_sha256: str
    comparison_surface: str
    synchronize_starting_player_chooser: bool
    operation_anchor: Mapping[str, Any]
    bootstrap_prefix_claimed: bool

    @classmethod
    def build(
        cls,
        *,
        official_deck0: Any,
        official_deck1: Any,
        private_deck0_entries: Any,
        private_deck1_entries: Any,
        relation_sha256: str,
        godot_seed: int = 1,
    ) -> "A3MatchPlan":
        if (
            type(relation_sha256) is not str or len(relation_sha256) != 64
            or any(character not in "0123456789ABCDEF" for character in relation_sha256)
            or type(godot_seed) is not int
        ):
            raise A3MatchPlanError("a3_match_plan_identity_invalid")
        official = {
            "deck0": _official_deck(official_deck0),
            "deck1": _official_deck(official_deck1),
        }
        godot = {
            "private_deck0_entries": _private_entries(private_deck0_entries),
            "private_deck1_entries": _private_entries(private_deck1_entries),
            "seed": godot_seed,
        }
        body = {
            "document_type": "ptcgdap_a3_sealed_match_plan_v2",
            "schema_version": 2,
            "official_start": official,
            "godot_start": godot,
            "relation_sha256": relation_sha256,
            "comparison_surface": "current_window_operation",
            "synchronize_starting_player_chooser": True,
            "operation_anchor": {
                "lifecycle_id": "setup_active_after_starting_player_yes",
                "select_type": 1,
                "select_context": 1,
                "acting_seat_source": "starting_player_chooser",
                "occurrence_ordinal": 1,
                "candidate_count": 1,
                "starting_player_choice_index": 0,
            },
            "bootstrap_prefix_claimed": False,
        }
        return cls(
            _hash(body), official, godot, relation_sha256,
            "current_window_operation", True,
            {
                "lifecycle_id": "setup_active_after_starting_player_yes",
                "select_type": 1,
                "select_context": 1,
                "acting_seat_source": "starting_player_chooser",
                "occurrence_ordinal": 1,
                "candidate_count": 1,
                "starting_player_choice_index": 0,
            },
            False,
        )

    @classmethod
    def parse(cls, value: Any) -> "A3MatchPlan":
        if type(value) is not dict or set(value) != {
            "document_type", "schema_version", "plan_sha256", "official_start",
            "godot_start", "relation_sha256", "comparison_surface",
            "synchronize_starting_player_chooser", "operation_anchor",
            "bootstrap_prefix_claimed",
        }:
            raise A3MatchPlanError("a3_match_plan_invalid")
        if (
            value.get("document_type") != "ptcgdap_a3_sealed_match_plan_v2"
            or value.get("schema_version") != 2
            or value.get("comparison_surface") != "current_window_operation"
            or value.get("synchronize_starting_player_chooser") is not True
            or value.get("operation_anchor") != {
                "lifecycle_id": "setup_active_after_starting_player_yes",
                "select_type": 1,
                "select_context": 1,
                "acting_seat_source": "starting_player_chooser",
                "occurrence_ordinal": 1,
                "candidate_count": 1,
                "starting_player_choice_index": 0,
            }
            or value.get("bootstrap_prefix_claimed") is not False
        ):
            raise A3MatchPlanError("a3_match_plan_invalid")
        official = value.get("official_start")
        godot = value.get("godot_start")
        if type(official) is not dict or set(official) != {"deck0", "deck1"}:
            raise A3MatchPlanError("a3_match_plan_invalid")
        if type(godot) is not dict or set(godot) != {
            "private_deck0_entries", "private_deck1_entries", "seed"
        } or type(godot.get("seed")) is not int:
            raise A3MatchPlanError("a3_match_plan_invalid")
        relation_sha256 = value.get("relation_sha256")
        plan_sha256 = value.get("plan_sha256")
        body = copy.deepcopy(value)
        body.pop("plan_sha256")
        if (
            type(relation_sha256) is not str or len(relation_sha256) != 64
            or type(plan_sha256) is not str or len(plan_sha256) != 64
            or _hash(body) != plan_sha256
        ):
            raise A3MatchPlanError("a3_match_plan_identity_invalid")
        return cls.build(
            official_deck0=official["deck0"], official_deck1=official["deck1"],
            private_deck0_entries=godot["private_deck0_entries"],
            private_deck1_entries=godot["private_deck1_entries"],
            relation_sha256=relation_sha256, godot_seed=godot["seed"],
        )

    def to_private_dict(self) -> dict[str, Any]:
        return {
            "document_type": "ptcgdap_a3_sealed_match_plan_v2",
            "schema_version": 2,
            "plan_sha256": self.plan_sha256,
            "official_start": copy.deepcopy(dict(self.official_start)),
            "godot_start": copy.deepcopy(dict(self.godot_start)),
            "relation_sha256": self.relation_sha256,
            "comparison_surface": self.comparison_surface,
            "synchronize_starting_player_chooser": self.synchronize_starting_player_chooser,
            "operation_anchor": copy.deepcopy(dict(self.operation_anchor)),
            "bootstrap_prefix_claimed": self.bootstrap_prefix_claimed,
        }

    def official_projection(self) -> dict[str, Any]:
        return copy.deepcopy(dict(self.official_start))

    def godot_projection(self, official_first_checkpoint: Any) -> dict[str, Any]:
        if (
            getattr(official_first_checkpoint, "kind", None) != "SELECTION"
            or getattr(official_first_checkpoint, "acting_seat", None) not in (0, 1)
            or type(getattr(official_first_checkpoint, "select", None)) is not dict
            or official_first_checkpoint.select.get("type") != 9
            or official_first_checkpoint.select.get("context") != 41
        ):
            raise A3MatchPlanError("a3_match_plan_starting_player_checkpoint_invalid")
        result = copy.deepcopy(dict(self.godot_start))
        result["force_first"] = official_first_checkpoint.acting_seat
        return result

    def resolved_operation_anchor(
        self,
        official_first_checkpoint: Any,
    ) -> dict[str, Any]:
        if (
            getattr(official_first_checkpoint, "kind", None) != "SELECTION"
            or getattr(official_first_checkpoint, "acting_seat", None) not in (0, 1)
            or type(getattr(official_first_checkpoint, "select", None)) is not dict
            or official_first_checkpoint.select.get("type") != 9
            or official_first_checkpoint.select.get("context") != 41
        ):
            raise A3MatchPlanError("a3_match_plan_starting_player_checkpoint_invalid")
        anchor = copy.deepcopy(dict(self.operation_anchor))
        anchor.pop("acting_seat_source")
        anchor["acting_seat"] = official_first_checkpoint.acting_seat
        return anchor


__all__ = ["A3MatchPlan", "A3MatchPlanError"]
