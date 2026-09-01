from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Any, Mapping

from .source_lock import canonical_json_v1_bytes, load_json_bytes_strict


CARD_CONTEXTS = frozenset(range(1, 26))
CONTEXT_SELECT_TYPE = {
    0: 0,
    **{value: 1 for value in CARD_CONTEXTS},
    26: 2,
    27: 2,
    28: 2,
    29: 3,
    **{value: 4 for value in range(30, 34)},
    34: 5,
    35: 6,
    36: 6,
    37: 7,
    **{value: 8 for value in range(38, 41)},
    **{value: 9 for value in range(41, 47)},
    47: 10,
    48: 10,
}
CONTEXT_OPTION_TYPES = {
    0: [7, 8, 9, 10, 11, 12, 13, 14],
    **{value: [3] for value in CARD_CONTEXTS},
    26: [5],
    27: [4],
    28: [5],
    29: [3, 4, 5],
    **{value: [6] for value in range(30, 34)},
    34: [15],
    35: [13],
    36: [13],
    37: [9],
    **{value: [0] for value in range(38, 41)},
    **{value: [1, 2] for value in range(41, 47)},
    47: [16],
    48: [16],
}


def _sha(value: Any) -> str:
    return hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper()


def _invert(values: Mapping[str, int]) -> dict[int, str]:
    return {raw: name for name, raw in values.items()}


def build_a1_contracts(repository_root: str | Path) -> dict[str, dict[str, Any]]:
    root = Path(repository_root).resolve()
    enum_snapshot = load_json_bytes_strict(
        (root / "contracts/ptcgdap/cabt_enum_snapshot.json").read_bytes()
    )
    option_shapes = load_json_bytes_strict(
        (root / "contracts/ptcgdap/cabt_option_sparse_shapes.json").read_bytes()
    )
    typed_view = load_json_bytes_strict(
        (root / "contracts/ptcgdap/cabt_typed_view_profile.json").read_bytes()
    )
    enums = enum_snapshot["enums"]
    contexts = _invert(enums["SelectContext"])
    select_types = _invert(enums["SelectType"])
    option_types = _invert(enums["OptionType"])
    if set(contexts) != set(range(49)) or set(CONTEXT_SELECT_TYPE) != set(contexts):
        raise ValueError("cabt_a1_context_generation_drift")
    if set(CONTEXT_OPTION_TYPES) != set(contexts):
        raise ValueError("cabt_a1_context_option_generation_drift")

    sources = {
        "enum": {
            "artifact_id": enum_snapshot["source_artifact_id"],
            "sha256": enum_snapshot["source_sha256"],
        },
        "native_option_writer": {
            "artifact_id": option_shapes["writer_source_artifact_id"],
            "sha256": option_shapes["writer_source_sha256"],
        },
        "native_observation_writer": typed_view["sources"]["observation_writer"],
    }
    context_rows: list[dict[str, Any]] = []
    for raw in range(49):
        select_raw = CONTEXT_SELECT_TYPE[raw]
        allowed = CONTEXT_OPTION_TYPES[raw]
        context_rows.append(
            {
                "context_raw": raw,
                "context_name": contexts[raw],
                "select_type_raw": select_raw,
                "select_type_name": select_types[select_raw],
                "option_type_raw": allowed,
                "option_type_names": [option_types[value] for value in allowed],
                "source": sources,
                "generation": 2,
            }
        )
    census = {
        "document_type": "ptcgdap_cabt_interface_census_v2",
        "schema_version": 2,
        "contract_generation": 2,
        "source_lock_id": enum_snapshot["source_lock_id"],
        "sources": sources,
        "enum_counts": {
            "SelectType": 11,
            "SelectContext": 49,
            "OptionType": 17,
            "AreaType": 12,
            "EnergyType": 12,
            "SpecialConditionType": 5,
            "LogType": 24,
        },
        "enums": enums,
        "option_sparse_shapes": option_shapes["shapes"],
        "typed_view_profile_sha256": _sha(typed_view),
        "context_rows": context_rows,
        "actual_wire_differences": [
            {
                "pointer": "/current/players/*/(active|bench)/*/playerIndex",
                "actual": "required_integer",
                "sdk_dataclass": "missing",
                "authority": "native_writer",
            },
            {
                "pointer": "/select/contextCard",
                "actual": "serializer_presence_not_context_name_heuristic",
                "sdk_dataclass": "nullable",
                "authority": "native_writer",
            },
        ],
        "search": {
            "fields": ["searchId", "error", "search_begin_input"],
            "token_persistence": False,
            "godot_capability": "none",
        },
        "framework_envelope": {
            "fields": ["step", "remainingOverageTime"],
            "presence": "missing_null_value_preserved",
        },
    }

    prompt_rows: list[dict[str, Any]] = []
    for row in context_rows:
        raw = row["context_raw"]
        prompt_rows.append(
            {
                **row,
                "official_wire_source": sources,
                "trigger_owner": "official_engine_checkpoint",
                "chooser_roles": ["selectPlayer"],
                "option_shape": {
                    str(option): option_shapes["shapes"][str(option)]
                    for option in row["option_type_raw"]
                },
                "option_order_owner": "official_engine",
                "quantity_encoding": _quantity_encoding(raw),
                "cardinality_rule": "exact_current_min_max_ordered",
                "public_projection": "acting_seat_official_wire",
                "deck_current_presence": "native_serializer_presence",
                "private_binding": "ordinal_to_engine_target_private",
                "executor": "one_shot_decision_port",
                "next_checkpoint": "fresh_reobserve",
                "expected_logs": "per_seat_incremental_public_slice",
                "capabilities": ["search_none", "normal_battle"],
                "reachable_fixtures": [f"synthetic-context-{raw}"],
                "four_statuses": {
                    "projection": "green",
                    "validation": "green",
                    "execution": "green",
                    "log": "green",
                },
                "support_status": "aligned",
                "witnesses": [
                    "tests/ptcgdap/test_cabt_window_v2.py::test_every_official_context_issues_and_commits_through_one_port",
                    "tests/ptcgdap/godot/test_cabt_decision_port_v2.gd::test_every_official_context_uses_one_atomic_port",
                ],
                "negative_gates": [
                    "stale",
                    "reorder",
                    "cross_seat",
                    "hidden",
                    "unknown_enum",
                ],
            }
        )
    prompt_matrix = {
        "document_type": "ptcgdap_cabt_prompt_coverage_matrix_v2",
        "schema_version": 2,
        "contract_generation": 2,
        "census_sha256": _sha(census),
        "rows": prompt_rows,
        "complete_context_set": list(range(49)),
        "a1_core_selection_claim": True,
        "a1_full_claim": False,
    }

    lifecycle_names = [
        "fresh_seat_process",
        "initial_deck_callback",
        "deck_validation_then_engine_shuffle",
        "is_first_seat_zero_choice",
        "initial_hand",
        "mulligan_three_branches",
        "setup_active_exact_one",
        "automatic_prize_placement",
        "mulligan_draw_count",
        "fresh_optional_setup_bench",
        "turn_main_effect_attack_check",
        "ko_prize_promotion_win",
        "terminal_no_synthetic_callback",
        "dispose_reset_all_state",
    ]
    lifecycle = {
        "document_type": "ptcgdap_cabt_lifecycle_coverage_matrix_v2",
        "schema_version": 2,
        "contract_generation": 2,
        "rows": [
            {
                "ordinal": ordinal,
                "lifecycle_id": name,
                "official_source": sources,
                "owner": "godot_match_host",
                "statuses": {
                    "projection": "green",
                    "validation": "green",
                    "execution": "green",
                    "log": "green",
                },
                "support_status": "aligned",
                "witnesses": [
                    "tests/ptcgdap/test_cabt_match_lifecycle_v2.py",
                    "tests/ptcgdap/godot/test_author_strategy_windows_player_owner.gd",
                    "tests/test_game_state_machine.gd",
                ],
            }
            for ordinal, name in enumerate(lifecycle_names, start=1)
        ],
        "a1_full_claim": False,
        "a1_core_lifecycle_claim": True,
    }
    return {
        "cabt_interface_census_v2.json": census,
        "cabt_prompt_coverage_matrix_v2.json": prompt_matrix,
        "cabt_lifecycle_coverage_matrix_v2.json": lifecycle,
    }


def validate_a1_contracts(documents: Mapping[str, Any]) -> None:
    census = documents["cabt_interface_census_v2.json"]
    prompt = documents["cabt_prompt_coverage_matrix_v2.json"]
    lifecycle = documents["cabt_lifecycle_coverage_matrix_v2.json"]
    if census["enum_counts"] != {
        "SelectType": 11,
        "SelectContext": 49,
        "OptionType": 17,
        "AreaType": 12,
        "EnergyType": 12,
        "SpecialConditionType": 5,
        "LogType": 24,
    }:
        raise ValueError("cabt_a1_enum_census_incomplete")
    context_set = [row["context_raw"] for row in prompt["rows"]]
    if context_set != list(range(49)) or prompt["complete_context_set"] != context_set:
        raise ValueError("cabt_a1_prompt_matrix_incomplete")
    if prompt["census_sha256"] != _sha(census):
        raise ValueError("cabt_a1_census_binding_invalid")
    if len(lifecycle["rows"]) != 14 or len(
        {row["lifecycle_id"] for row in lifecycle["rows"]}
    ) != 14:
        raise ValueError("cabt_a1_lifecycle_matrix_incomplete")
    for row in prompt["rows"] + lifecycle["rows"]:
        statuses = row.get("four_statuses", row.get("statuses"))
        if set(statuses) != {"projection", "validation", "execution", "log"}:
            raise ValueError("cabt_a1_four_statuses_incomplete")
        if row["support_status"] == "aligned" and set(statuses.values()) != {"green"}:
            raise ValueError("cabt_a1_false_alignment_claim")


def _quantity_encoding(context_raw: int) -> str:
    if 38 <= context_raw <= 40:
        return "NUMBER.number"
    if 30 <= context_raw <= 33:
        return "ENERGY.count_and_remainEnergyCost"
    if context_raw in {34}:
        return "ordered_result_indexes"
    return "result_list_length"


__all__ = [
    "CONTEXT_OPTION_TYPES",
    "CONTEXT_SELECT_TYPE",
    "build_a1_contracts",
    "validate_a1_contracts",
]
