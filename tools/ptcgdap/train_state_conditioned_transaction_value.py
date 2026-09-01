from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys
from typing import Any, Iterable

import numpy as np


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.state_conditioned_transaction_value import (  # noqa: E402
    StateConditionedTransactionValueV2,
)
from scripts.ai.ptcgdap.author_strategy_package import (  # noqa: E402
    AuthorStrategyPackageLoader,
)


PROFILE_ID = "ptcgdap-state-conditioned-training-run-v6"
DATASET_PROFILE_ID = "ptcgdap-state-conditioned-training-dataset-v5"
SPARSE_INTERACTION_FEATURE_BUDGETS = (16, 32, 64)

MARNIE_UID_ROLES: dict[str, list[str]] = {
    "CSV10C_146": ["grimmsnarl_basic"],
    "CSV10C_147": ["punk_up_stage1"],
    "CSV10C_148": ["grimmsnarl_engine"],
    "CSV9.5C_043": ["froslass_basic"],
    "CSV7C_059": ["froslass_engine"],
    "CSV8C_094": ["damage_engine"],
    "CSV9.5C_004": ["early_stall"],
    "CSV10C_007": ["bench_shield"],
    "CSVH1C_035": ["energy_search"],
    "CSVE1C_DAR": ["energy"],
}

INTERACTION_STATE_FEATURES = (
    "turn.progress_milli",
    "self.hand.shortage_milli",
    "self.hand.abundance_milli",
    "opponent.hand.shortage_milli",
    "opponent.hand.excess_milli",
    "hand.advantage_milli",
    "prize.advantage_milli",
    "self.board.energy_debt_milli",
    "self.board.attack_ready_milli",
    "self.board.bench_space_milli",
    "self.discard.count_milli",
    "turn.supporter_available_milli",
    "turn.supporter_spent_milli",
    "turn.manual_attachment_available_milli",
    "turn.manual_attachment_spent_milli",
    "turn.retreat_available_milli",
    "turn.retreat_spent_milli",
    "self.board.role.froslass_basic_milli",
    "self.board.role.froslass_engine_milli",
    "self.board.role.grimmsnarl_basic_milli",
    "self.board.role.punk_up_stage1_milli",
    "self.board.role.grimmsnarl_engine_milli",
    "self.board.role.damage_engine_milli",
    "self.board.role.early_stall_milli",
    "self.discard.role.froslass_engine_milli",
    "self.discard.role.grimmsnarl_engine_milli",
    "self.discard.role.energy_milli",
)

INTERACTION_ACTION_FEATURES = (
    "outcome.board_development_milli",
    "outcome.attack_pressure_milli",
    "outcome.next_turn_continuity_milli",
    "outcome.hand_quality_milli",
    "outcome.disruption_milli",
    "outcome.resource_preservation_milli",
    "outcome.risk_milli",
    "outcome.unresolved_debt_milli",
    "program.nonterminal_count_milli",
    "program.current_effect.attack_milli",
    "program.current_effect.bench_milli",
    "program.current_effect.damage_transfer_milli",
    "program.current_effect.disruption_milli",
    "program.current_effect.draw_milli",
    "program.current_effect.end_turn_milli",
    "program.current_effect.energy_milli",
    "program.current_effect.evolution_milli",
    "program.current_effect.search_milli",
    "program.current_resource.supporter_milli",
    "program.current_resource.manual_attachment_milli",
    "program.current_resource.retreat_milli",
    "action.card.role.froslass_engine_milli",
    "action.card.role.grimmsnarl_engine_milli",
    "action.card.role.damage_engine_milli",
    "action.card.role.early_stall_milli",
    "action.card.role.energy_search_milli",
)


def _canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")


def _sha_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _sha_file(path: Path) -> str:
    return _sha_bytes(path.read_bytes())


def _card(uid: str, serial: int) -> dict[str, Any]:
    return {"serial": serial, "local_card_uid": uid}


def _slot(
    uid: str, serial: int, *, energy: int = 0, debt: int = 0
) -> dict[str, Any]:
    return {
        "serial": serial,
        "entity_serial": 10_000 + serial,
        "local_card_uid": uid,
        "remaining_hp": 100,
        "max_hp": 100,
        "prize_value": 1,
        "attached_energy_count": energy,
        "attached_energy_uids": ["CSVE1C_DAR"] * energy,
        "minimum_attack_energy_count": energy + debt,
        "attack_ready": debt == 0,
        "energy_debt": debt,
        "damage_counters": 0,
    }


def _frame(
    *,
    turn: int,
    own_hand: int = 5,
    opponent_hand: int = 5,
    active: list[dict[str, Any]] | None = None,
    bench: list[dict[str, Any]] | None = None,
    discard: list[dict[str, Any]] | None = None,
    own_deck: int = 30,
    opponent_deck: int = 28,
    own_prizes: int = 4,
    opponent_prizes: int = 4,
    supporter_available: bool = True,
    manual_attachment_available: bool = True,
) -> dict[str, Any]:
    return {
        "schema_version": 2,
        "profile_id": "ptcgdap-competitive-public-frame-v2",
        "sequence": turn,
        "seat": 0,
        "prompt_kind": "main",
        "source": {
            "public_observation_hash": "A" * 64,
            "window_id": "B" * 64,
        },
        "public_state": {
            "turn_number": turn,
            "phase": "MAIN",
            "self": {
                "hand": [_card("CSVE1C_DAR", index + 1) for index in range(own_hand)],
                "active": copy.deepcopy(active or []),
                "bench": copy.deepcopy(bench or []),
                "discard": copy.deepcopy(discard or []),
                "deck_count": own_deck,
                "prizes_remaining": own_prizes,
                "turn": {
                    "supporter_available": supporter_available,
                    "manual_attachment_available": manual_attachment_available,
                    "retreat_available": True,
                },
            },
            "opponent": {
                "hand_count": opponent_hand,
                "active": [],
                "bench": [],
                "discard": [],
                "deck_count": opponent_deck,
                "prizes_remaining": opponent_prizes,
            },
        },
        "select_semantics": {
            "min_count": 1,
            "max_count": 1,
            "select_type_raw": 1,
            "select_context_raw": 0,
        },
        "options": [],
    }


def _outcome(**overrides: int) -> dict[str, int]:
    result = {
        "final_prize_knockout": 0,
        "prize_gain_milli": 0,
        "board_development_milli": 0,
        "attack_pressure_milli": 0,
        "next_turn_continuity_milli": 0,
        "hand_quality_milli": 0,
        "disruption_milli": 0,
        "resource_preservation_milli": 720,
        "risk_milli": 0,
        "unresolved_debt_milli": 0,
    }
    result.update(overrides)
    return result


def _program(
    program_id: str,
    outcome: dict[str, int],
    *,
    steps: int = 1,
    terminal: str = "none",
    card_uid: str | None = None,
    source_uid: str | None = None,
    effect_kind: str = "ability",
    resource_claim: str = "none",
) -> dict[str, Any]:
    semantic_steps: list[dict[str, Any]] = []
    for offset in range(steps):
        step_id = f"step-{offset}"
        semantic_steps.append(
            {
                "step_id": step_id,
                "transaction_id": "exam-transaction",
                "method_id": "exam-method",
                "depends_on": [] if offset == 0 else [f"step-{offset - 1}"],
                "terminal_kind": terminal if offset == steps - 1 else "none",
            }
        )
    return {
        "program_id": program_id,
        "goal_id": "exam-goal",
        "route_id": program_id,
        "deadline_turns": 0,
        "semantic_steps": semantic_steps,
        "public_outcome": copy.deepcopy(outcome),
        "public_action_context": {
            "card_uids": [] if card_uid is None else [card_uid],
            "source_uids": [] if source_uid is None else [source_uid],
            "target_uids": [],
            "kinds": ["exam"],
            "tags": [],
            "current_effect_kinds": [effect_kind],
            "current_resource_claims": [resource_claim],
        },
    }


def _preference(
    model: dict[str, Any],
    exam_id: str,
    frame: dict[str, Any],
    preferred: dict[str, Any],
    other: dict[str, Any],
) -> dict[str, Any]:
    encoded = StateConditionedTransactionValueV2.encode_public_state(frame, model)
    preferred_features = StateConditionedTransactionValueV2.action_features(
        preferred, preferred["public_outcome"], model
    )
    other_features = StateConditionedTransactionValueV2.action_features(
        other, other["public_outcome"], model
    )
    if not encoded.get("accepted") or preferred_features is None or other_features is None:
        raise ValueError(f"invalid authored exam: {exam_id}")
    return {
        "sample_id": exam_id,
        "group_id": exam_id,
        "source": "exam",
        "state_features_milli": encoded["features_milli"],
        "preferred_action_features_milli": preferred_features,
        "other_action_features_milli": other_features,
        "weight_milli": 5000,
    }


def build_authored_exam_preferences(model: dict[str, Any]) -> list[dict[str, Any]]:
    attack = _program(
        "attack-now",
        _outcome(attack_pressure_milli=720),
        terminal="attack",
        effect_kind="attack",
    )
    disrupt = _program(
        "disrupt-then-attack",
        _outcome(
            attack_pressure_milli=720,
            next_turn_continuity_milli=120,
            hand_quality_milli=80,
            disruption_milli=620,
            resource_preservation_milli=600,
            risk_milli=55,
        ),
        steps=2,
        terminal="attack",
        effect_kind="disruption",
        resource_claim="supporter",
    )
    evolve = _program(
        "evolve-two",
        _outcome(
            board_development_milli=640,
            next_turn_continuity_milli=600,
            resource_preservation_milli=560,
            risk_milli=110,
        ),
        steps=3,
        terminal="attack",
        effect_kind="evolution",
    )
    search = _program(
        "recover-engine",
        _outcome(
            board_development_milli=100,
            next_turn_continuity_milli=180,
            hand_quality_milli=260,
            resource_preservation_milli=630,
            risk_milli=260,
        ),
        effect_kind="search",
    )
    budew = _program(
        "bench-budew",
        _outcome(
            board_development_milli=220,
            next_turn_continuity_milli=260,
            resource_preservation_milli=650,
            risk_milli=260,
        ),
        card_uid="CSV9.5C_004",
        effect_kind="bench",
    )
    munkidori = _program(
        "bench-munkidori",
        _outcome(
            board_development_milli=220,
            next_turn_continuity_milli=260,
            resource_preservation_milli=650,
            risk_milli=260,
        ),
        card_uid="CSV8C_094",
        effect_kind="bench",
    )
    attach = _program(
        "preserve-punk-up-window",
        _outcome(
            board_development_milli=180,
            attack_pressure_milli=120,
            next_turn_continuity_milli=280,
            resource_preservation_milli=640,
            risk_milli=260,
        ),
        effect_kind="energy",
        resource_claim="manual_attachment",
    )
    second_froslass = _program(
        "late-second-froslass",
        _outcome(
            board_development_milli=320,
            next_turn_continuity_milli=560,
            resource_preservation_milli=640,
            risk_milli=260,
        ),
        card_uid="CSV7C_059",
        effect_kind="evolution",
    )
    redundant_energy_search = _program(
        "redundant-energy-search",
        _outcome(
            board_development_milli=100,
            next_turn_continuity_milli=440,
            hand_quality_milli=260,
            resource_preservation_milli=630,
            risk_milli=260,
        ),
        card_uid="CSVH1C_035",
        effect_kind="search",
    )
    end_turn = _program(
        "preserve-state-and-end",
        _outcome(resource_preservation_milli=720, unresolved_debt_milli=250),
        terminal="end_turn",
        effect_kind="end_turn",
    )
    incomplete = _frame(
        turn=4,
        bench=[
            _slot("CSV9.5C_043", 10, debt=1),
            _slot("CSV10C_146", 11, debt=2),
        ],
    )
    complete = _frame(
        turn=5,
        bench=[
            _slot("CSV7C_059", 10, debt=1),
            _slot("CSV10C_148", 11, energy=2),
        ],
    )
    energyless_morgrem = _frame(
        turn=4, bench=[_slot("CSV10C_147", 11, debt=2)]
    )
    discard_engine = _frame(
        turn=6,
        own_hand=2,
        discard=[_card("CSV7C_059", 30), _card("CSVE1C_DAR", 31)],
    )
    no_discard_engine = _frame(turn=6, own_hand=6, discard=[])
    late_complete_damage_engine = _frame(
        turn=31,
        own_hand=8,
        opponent_hand=5,
        active=[_slot("CSV8C_094", 9, debt=2)],
        bench=[
            _slot("CSV10C_148", 10, energy=2),
            _slot("CSV10C_147", 11, debt=2),
            _slot("CSV10C_146", 12, debt=1),
            _slot("CSV7C_059", 13, debt=2),
            _slot("CSV9.5C_043", 14, debt=2),
        ],
        own_deck=8,
        opponent_deck=12,
        own_prizes=2,
        opponent_prizes=1,
        supporter_available=False,
        manual_attachment_available=False,
    )
    funded_damage_engine = _frame(
        turn=9,
        own_hand=6,
        opponent_hand=3,
        active=[_slot("CSV10C_148", 9, energy=2)],
        bench=[_slot("CSV8C_094", 10, energy=1, debt=1)],
        own_deck=33,
        own_prizes=6,
        opponent_prizes=6,
    )
    spent_attachment_full_board = _frame(
        turn=5,
        own_hand=5,
        opponent_hand=6,
        active=[_slot("CSV9.5C_004", 9)],
        bench=[
            _slot("CSV9.5C_043", 10, debt=2),
            _slot("CSV8C_094", 11, energy=1, debt=1),
            _slot("CSV10C_147", 12, energy=2),
            _slot("CSV10C_146", 13, debt=1),
            _slot("CSV9.5C_043", 14, debt=2),
        ],
        own_deck=36,
        opponent_deck=39,
        own_prizes=6,
        opponent_prizes=6,
        supporter_available=False,
        manual_attachment_available=False,
    )
    spent_attachment_full_board["public_state"]["self"]["hand"] = [
        _card(uid, index + 1)
        for index, uid in enumerate(
            ["CSV6C_114", "CSV3C_123", "CSV1C_123", "CSV8C_183", "CSVH1C_035"]
        )
    ]
    spent_attachment_full_board["public_state"]["self"]["discard"] = [
        _card(uid, index + 30)
        for index, uid in enumerate(["CSV1C_123", "CSV7C_177", "CSV3C_123"])
    ]
    spent_attachment_full_board["public_state"]["opponent"].update(
        {
            "active": [_slot("CSV10C_010", 70, energy=1, debt=2)],
            "bench": [
                _slot("CSV8C_028", 114, energy=2, debt=1),
                _slot("CSV8C_028", 115, energy=1, debt=2),
            ],
            "discard": [_card("CSV10C_206", 116)],
        }
    )
    budew_attack = _program(
        "budew-stall-attack",
        _outcome(
            attack_pressure_milli=40,
            resource_preservation_milli=720,
            unresolved_debt_milli=250,
        ),
        terminal="attack",
        effect_kind="attack",
    )
    spent_attachment_energy_search = _program(
        "spent-attachment-energy-search",
        _outcome(
            board_development_milli=100,
            next_turn_continuity_milli=440,
            hand_quality_milli=260,
            resource_preservation_milli=630,
            risk_milli=260,
        ),
        card_uid="CSVH1C_035",
        effect_kind="search",
    )
    urgent_damage_wall = _frame(
        turn=13,
        own_hand=4,
        opponent_hand=10,
        active=[_slot("CSV10C_148", 9, energy=2)],
        bench=[
            _slot("CSV8C_094", 10, energy=1, debt=1),
            _slot("CSV10C_146", 11, energy=1),
            _slot("CSV7C_059", 12, debt=2),
        ],
        discard=[_card("CSV1C_123", index + 30) for index in range(17)],
        own_deck=16,
        opponent_deck=39,
        own_prizes=4,
        opponent_prizes=2,
    )
    granted_damage_attack = _program(
        "granted-damage-wall-attack",
        _outcome(
            attack_pressure_milli=720,
            resource_preservation_milli=720,
            unresolved_debt_milli=250,
        ),
        terminal="attack",
        source_uid="CSV5C_120",
        effect_kind="attack",
    )
    optional_damage_engine_bench = _program(
        "optional-damage-engine-bench",
        _outcome(
            board_development_milli=220,
            next_turn_continuity_milli=520,
            resource_preservation_milli=650,
            risk_milli=260,
        ),
        card_uid="CSV8C_094",
        effect_kind="bench",
    )
    return [
        _preference(
            model, "exam-low-hand-high-opponent-disrupt", _frame(turn=5, own_hand=1, opponent_hand=8), disrupt, attack
        ),
        _preference(
            model, "exam-rich-hand-low-opponent-attack", _frame(turn=5, own_hand=8, opponent_hand=2), attack, disrupt
        ),
        _preference(model, "exam-two-safe-evolution-targets", incomplete, evolve, attack),
        _preference(model, "exam-complete-engine-attack", complete, attack, evolve),
        _preference(
            model, "exam-energyless-morgrem-preserve-punk-up", energyless_morgrem, attach, evolve
        ),
        _preference(model, "exam-turn-one-budew-stall", _frame(turn=1, own_hand=2), budew, munkidori),
        _preference(model, "exam-late-munkidori-over-budew", _frame(turn=8), munkidori, budew),
        _preference(model, "exam-discard-engine-recovery", discard_engine, search, attack),
        _preference(model, "exam-no-discard-engine-attack", no_discard_engine, attack, search),
        _preference(
            model,
            "exam-late-complete-engine-do-not-add-second-froslass",
            late_complete_damage_engine,
            end_turn,
            second_froslass,
        ),
        _preference(
            model,
            "exam-funded-munkidori-skips-redundant-energy-search",
            funded_damage_engine,
            end_turn,
            redundant_energy_search,
        ),
        _preference(
            model,
            "exam-spent-attachment-energy-search-does-not-preempt-attack",
            spent_attachment_full_board,
            budew_attack,
            spent_attachment_energy_search,
        ),
        _preference(
            model,
            "exam-urgent-granted-attack-preserves-verified-damage-route",
            urgent_damage_wall,
            granted_damage_attack,
            optional_damage_engine_bench,
        ),
    ]


def _base_action_score(model: dict[str, Any], action: dict[str, int]) -> int:
    weights = model["fallback_value_model"]["feature_weights_milli"]
    return sum(action.get(f"outcome.{name}", 0) * weight for name, weight in weights.items())


def _pair_basis(
    sample: dict[str, Any], action_names: list[str], interaction_names: list[str]
) -> np.ndarray:
    preferred = sample["preferred_action_features_milli"]
    other = sample["other_action_features_milli"]
    state = sample["state_features_milli"]
    action_delta = {name: preferred.get(name, 0) - other.get(name, 0) for name in action_names}
    values: list[float] = [float(action_delta[name]) for name in action_names]
    for pair in interaction_names:
        state_name, action_name = pair.split("::", 1)
        values.append(float(state.get(state_name, 0) * action_delta.get(action_name, 0) // 1000))
    return np.asarray(values, dtype=np.float64)


def _select_sparse_interactions(
    model: dict[str, Any],
    preference_samples: list[dict[str, Any]],
    interaction_names: list[str],
    *,
    max_interaction_features: int | None,
) -> list[str]:
    """Rank interaction columns from fit-only evidence and keep a fixed budget.

    The ranking uses normalized weighted correlation with the residual utility
    left after the rollback value head.  It never looks at calibration or
    benchmark rows, so held-out branch outcomes cannot leak into feature
    selection.  Lexical order is the deterministic final tie-break.
    """
    if (
        max_interaction_features is None
        or len(interaction_names) <= max_interaction_features
    ):
        return interaction_names
    if type(max_interaction_features) is not int or max_interaction_features < 0:
        raise ValueError("invalid interaction feature budget")
    if max_interaction_features == 0:
        return []
    residual_targets = np.asarray(
        [
            2_000_000
            - (
                _base_action_score(model, sample["preferred_action_features_milli"])
                - _base_action_score(model, sample["other_action_features_milli"])
            )
            for sample in preference_samples
        ],
        dtype=np.float64,
    )
    sample_weights = np.asarray(
        [sample.get("weight_milli", 1000) / 1000.0 for sample in preference_samples],
        dtype=np.float64,
    )
    root_weights = np.sqrt(sample_weights)
    action_names = sorted(
        {
            name
            for sample in preference_samples
            for side in (
                sample["preferred_action_features_milli"],
                sample["other_action_features_milli"],
            )
            for name in side
        }
    )
    action_matrix = np.vstack(
        [_pair_basis(sample, action_names, []) for sample in preference_samples]
    )
    columns: dict[str, np.ndarray] = {}
    active_counts: dict[str, int] = {}
    for pair in interaction_names:
        state_name, action_name = pair.split("::", 1)
        column = np.asarray(
            [
                sample["state_features_milli"].get(state_name, 0)
                * (
                    sample["preferred_action_features_milli"].get(action_name, 0)
                    - sample["other_action_features_milli"].get(action_name, 0)
                )
                // 1000
                for sample in preference_samples
            ],
            dtype=np.float64,
        )
        columns[pair] = column
        active_counts[pair] = int(np.count_nonzero(column))

    selected: list[str] = []
    remaining = set(interaction_names)
    weighted_targets = residual_targets * root_weights
    for _offset in range(max_interaction_features):
        selected_matrix = (
            np.column_stack([action_matrix, *(columns[name] for name in selected)])
            if selected
            else action_matrix
        )
        weighted_matrix = selected_matrix * root_weights[:, None]
        coefficients = _ridge_weights(
            weighted_matrix, weighted_targets, regularization=50_000.0
        )
        residual = weighted_targets - weighted_matrix @ coefficients
        ranked: list[tuple[float, int, str]] = []
        for name in remaining:
            weighted_column = columns[name] * root_weights
            energy = float(weighted_column @ weighted_column)
            correlation = (
                abs(float(weighted_column @ residual)) / np.sqrt(energy)
                if energy > 0.0
                else 0.0
            )
            ranked.append((correlation, active_counts[name], name))
        if not ranked:
            break
        ranked.sort(key=lambda row: (-row[0], -row[1], row[2]))
        best = ranked[0]
        if best[0] <= 0.0:
            break
        selected.append(best[2])
        remaining.remove(best[2])
    return sorted(selected)


def _model_pair_score(model: dict[str, Any], sample: dict[str, Any]) -> int:
    preferred = sample["preferred_action_features_milli"]
    other = sample["other_action_features_milli"]
    state = sample["state_features_milli"]
    base_score = _base_action_score(model, preferred) - _base_action_score(model, other)
    raw_adjustment = sum(
        (preferred.get(name, 0) - other.get(name, 0)) * weight
        for name, weight in model["action_value_weights_milli"].items()
    )
    raw_adjustment += sum(
        state.get(state_name, 0)
        * (preferred.get(action_name, 0) - other.get(action_name, 0))
        * weight
        // 1000
        for pair, weight in model["interaction_weights_milli"].items()
        for state_name, action_name in [pair.split("::", 1)]
    )
    temperature = model["calibration"]["temperature_milli"]
    return base_score + raw_adjustment * 1000 // temperature


def preference_accuracy(
    model: dict[str, Any], samples: Iterable[dict[str, Any]]
) -> float:
    rows = list(samples)
    return (
        sum(_model_pair_score(model, sample) > 0 for sample in rows) / len(rows)
        if rows
        else 0.0
    )


def _ridge_weights(
    matrix: np.ndarray, targets: np.ndarray, *, regularization: float
) -> np.ndarray:
    if matrix.size == 0 or matrix.shape[0] == 0 or matrix.shape[1] == 0:
        return np.zeros(matrix.shape[1] if matrix.ndim == 2 else 0, dtype=np.float64)
    identity = np.eye(matrix.shape[1], dtype=np.float64)
    return np.linalg.pinv(matrix.T @ matrix + regularization * identity) @ matrix.T @ targets


def _clip_weight(value: float) -> int:
    return max(-100_000, min(100_000, int(round(value))))


def _weight_hash(model: dict[str, Any]) -> str:
    return _sha_bytes(
        _canonical_bytes(
            {
                "state": model["state_value_weights_milli"],
                "action": model["action_value_weights_milli"],
                "interaction": model["interaction_weights_milli"],
                "calibration": model["calibration"],
            }
        )
    )


def _stamp_training_identity(
    model: dict[str, Any], *, training_run_id: str, dataset_sha256: str
) -> None:
    model["training"] = {
        "profile_id": "ptcgdap-joint-decision-training-v2",
        "run_id": training_run_id,
        "label_profile_id": "ptcgdap-public-executed-better-than-self-v6",
        "dataset_sha256": dataset_sha256,
        "weights_sha256": "0" * 64,
    }
    model["training"]["weights_sha256"] = _weight_hash(model)


def fit_joint_model(
    seed_model: dict[str, Any],
    *,
    state_samples: list[dict[str, Any]],
    preference_samples: list[dict[str, Any]],
    calibration_samples: list[dict[str, Any]] | None = None,
    max_interaction_features: int | None = None,
    training_run_id: str,
    dataset_sha256: str,
) -> dict[str, Any]:
    model = copy.deepcopy(seed_model)
    state_names = sorted(
        {
            name
            for sample in state_samples
            for name in sample["features_milli"]
            if name != "bias_milli"
        }
    )
    if state_samples and state_names:
        matrix = np.asarray(
            [
                [sample["features_milli"].get(name, 0) / 1000.0 for name in state_names]
                for sample in state_samples
            ],
            dtype=np.float64,
        )
        targets = np.asarray(
            [sample["label_utility"] for sample in state_samples], dtype=np.float64
        )
        fitted = _ridge_weights(matrix, targets, regularization=2.0)
        model["state_value_weights_milli"] = {
            name: weight
            for name, coefficient in zip(state_names, fitted, strict=True)
            if (weight := _clip_weight(coefficient / 1000.0)) != 0
        }
    else:
        model["state_value_weights_milli"] = {"turn.progress_milli": 1}

    action_names = sorted(
        {
            name
            for sample in preference_samples
            for side in (
                sample["preferred_action_features_milli"],
                sample["other_action_features_milli"],
            )
            for name in side
        }
    )
    interaction_names = sorted(
        f"{state_name}::{action_name}"
        for state_name in INTERACTION_STATE_FEATURES
        for action_name in INTERACTION_ACTION_FEATURES
        if any(
            state_name in sample["state_features_milli"]
            and (
                sample["preferred_action_features_milli"].get(action_name, 0)
                != sample["other_action_features_milli"].get(action_name, 0)
            )
            for sample in preference_samples
        )
    )
    interaction_names = _select_sparse_interactions(
        model,
        preference_samples,
        interaction_names,
        max_interaction_features=max_interaction_features,
    )
    if preference_samples:
        matrix = np.vstack(
            [
                _pair_basis(sample, action_names, interaction_names)
                for sample in preference_samples
            ]
        )
        targets = np.asarray(
            [
                2_000_000
                - (
                    _base_action_score(model, sample["preferred_action_features_milli"])
                    - _base_action_score(model, sample["other_action_features_milli"])
                )
                for sample in preference_samples
            ],
            dtype=np.float64,
        )
        sample_weights = np.sqrt(
            np.asarray(
                [sample.get("weight_milli", 1000) / 1000.0 for sample in preference_samples],
                dtype=np.float64,
            )
        )
        weighted_matrix = matrix * sample_weights[:, None]
        weighted_targets = targets * sample_weights
        fitted = _ridge_weights(weighted_matrix, weighted_targets, regularization=50_000.0)
        action_count = len(action_names)
        model["action_value_weights_milli"] = {
            name: weight
            for name, coefficient in zip(action_names, fitted[:action_count], strict=True)
            if (weight := _clip_weight(coefficient)) != 0
        }
        model["interaction_weights_milli"] = {
            name: weight
            for name, coefficient in zip(
                interaction_names, fitted[action_count:], strict=True
            )
            if (weight := _clip_weight(coefficient)) != 0
        }
    else:
        model["action_value_weights_milli"] = {"outcome.attack_pressure_milli": 1}
        model["interaction_weights_milli"] = {
            "turn.progress_milli::outcome.attack_pressure_milli": 1
        }

    # Integer projection is a calibration constraint, not an oracle label.  It
    # repairs only authored public exams; trace preferences remain untouched.
    exams = [sample for sample in preference_samples if sample.get("source") == "exam"]
    all_names = [*action_names, *interaction_names]
    coefficients = np.asarray(
        [
            model["action_value_weights_milli"].get(name, 0)
            if "::" not in name
            else model["interaction_weights_milli"].get(name, 0)
            for name in all_names
        ],
        dtype=np.float64,
    )
    for _epoch in range(200):
        changed = False
        for sample in exams:
            score = _model_pair_score(model, sample)
            if score >= 100_000:
                continue
            vector = _pair_basis(sample, action_names, interaction_names)
            denominator = float(vector @ vector)
            if denominator <= 0:
                continue
            gap = 150_000 - score
            coefficients += (gap / denominator) * vector
            coefficients = np.clip(coefficients, -100_000, 100_000)
            action_count = len(action_names)
            model["action_value_weights_milli"] = {
                name: weight
                for name, value in zip(action_names, coefficients[:action_count], strict=True)
                if (weight := _clip_weight(value)) != 0
            }
            model["interaction_weights_milli"] = {
                name: weight
                for name, value in zip(
                    interaction_names, coefficients[action_count:], strict=True
                )
                if (weight := _clip_weight(value)) != 0
            }
            changed = True
        if not changed:
            break

    # Calibrate the learned residual against held-out match groups.  The
    # fallback utility retains its original scale; only the learned heads are
    # temperature-scaled.  Authored public exams are hard constraints, then
    # validation accuracy wins, with the most conservative temperature as the
    # deterministic tie-break.
    calibration_rows = list(calibration_samples or [])
    selected_temperature: int | None = None
    selected_key: tuple[float, int] | None = None
    for temperature in (1000, 1250, 1500, 1750, 2000, 3000, 4000, 6000, 8000, 10000):
        model["calibration"]["temperature_milli"] = temperature
        if exams and preference_accuracy(model, exams) != 1.0:
            continue
        accuracy = preference_accuracy(model, calibration_rows) if calibration_rows else 1.0
        key = (accuracy, temperature)
        if selected_key is None or key > selected_key:
            selected_key = key
            selected_temperature = temperature
    if selected_temperature is None:
        raise ValueError("no calibrated temperature preserves authored exams")
    model["calibration"]["temperature_milli"] = selected_temperature
    authored_margins = [_model_pair_score(model, sample) for sample in exams]
    if authored_margins:
        # Keep one quarter of the weakest locked preference as drift reserve.
        # The remaining margin gates learned replacement of a fresh Base commit.
        model["calibration"]["minimum_override_margin_utility"] = (
            (min(authored_margins) * 3 // 4) // 50_000
        ) * 50_000
    else:
        model["calibration"]["minimum_override_margin_utility"] = 0

    model["model_version"] = 2
    _stamp_training_identity(
        model,
        training_run_id=training_run_id,
        dataset_sha256=dataset_sha256,
    )
    error = StateConditionedTransactionValueV2.model_error(model)
    if error:
        raise ValueError(error)
    if exams and preference_accuracy(model, exams) != 1.0:
        failed = [
            sample["sample_id"]
            for sample in exams
            if _model_pair_score(model, sample) <= 0
        ]
        raise ValueError(f"authored exams not locked: {failed}")
    return model


def extract_trace_samples(
    paths: list[Path], model: dict[str, Any]
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], dict[str, Any]]:
    state_samples: list[dict[str, Any]] = []
    preferences: list[dict[str, Any]] = []
    seen_state_labels: set[tuple[str, int]] = set()
    seen_preference_ids: set[str] = set()
    source_groups: dict[str, str] = {}
    source_outcomes: dict[str, set[int]] = {}
    groups: set[str] = set()
    wins = 0
    losses = 0
    winning_shadow_window_count = 0
    executed_preference_window_count = 0
    canary_executed_preference_window_count = 0
    shadow_mismatch_preference_window_count = 0
    source_receipts: list[dict[str, Any]] = []
    documents: list[tuple[Path, dict[str, Any]]] = []
    for path in paths:
        document = json.loads(path.read_text(encoding="utf-8"))
        if not document.get("capture_developer_trace") or not document.get("is_clean"):
            raise ValueError(f"trace is not clean developer evidence: {path}")
        documents.append((path, document))
        source_receipts.append(
            {
                "path": path.resolve().as_posix(),
                "sha256": _sha_file(path),
                "games": document.get("games"),
                "candidate_wins": document.get("candidate_wins"),
            }
        )

    # Old fallback traces predate the fixed public-action-context field.  Join
    # exact same-observation programs across clean traces and prefer the richest
    # public representation.  This keeps training features identical to live
    # conditioned inference without inventing hidden or unavailable facts.
    public_programs_by_source: dict[str, dict[str, dict[str, Any]]] = {}
    for _path, document in documents:
        for game in document.get("per_game", []):
            for decision in game.get("candidate_developer_decisions", []):
                frame = decision.get("frame", {})
                if frame.get("prompt_kind") != "main":
                    continue
                source_hash = frame.get("source", {}).get(
                    "public_observation_hash", ""
                )
                generation = (
                    decision.get("policy", {})
                    .get("base_result", {})
                    .get("turn_program_generation", {})
                )
                if not source_hash or not generation.get("accepted"):
                    continue
                catalog = public_programs_by_source.setdefault(source_hash, {})
                for program in generation.get("request", {}).get("programs", []):
                    if type(program) is not dict or type(program.get("program_id")) is not str:
                        continue
                    existing = catalog.get(program["program_id"])
                    existing_context = (
                        existing.get("public_action_context")
                        if type(existing) is dict
                        else None
                    )
                    candidate_context = program.get("public_action_context")
                    if existing is None or (
                        type(existing_context) is not dict
                        and type(candidate_context) is dict
                    ):
                        catalog[program["program_id"]] = copy.deepcopy(program)

    for path, document in documents:
        for game_index, game in enumerate(document.get("per_game", [])):
            candidate_seat = game.get("candidate_seat")
            won = game.get("winner_index") == candidate_seat
            wins += int(won)
            losses += int(not won)
            match_group_id = (
                f"{path.stem}.seed-{game.get('seed')}.seat-{candidate_seat}.game-{game_index}"
            )
            for decision in game.get("candidate_developer_decisions", []):
                frame = decision.get("frame", {})
                if frame.get("prompt_kind") != "main":
                    continue
                base = decision.get("policy", {}).get("base_result", {})
                generation = base.get("turn_program_generation", {})
                shadow = base.get("turn_program_shadow", {})
                request = generation.get("request", {})
                if not generation.get("accepted") or not shadow.get("accepted"):
                    continue
                source_hash = frame.get("source", {}).get("public_observation_hash", "")
                if not source_hash:
                    continue
                group_id = source_groups.setdefault(source_hash, match_group_id)
                groups.add(group_id)
                encoded = StateConditionedTransactionValueV2.encode_public_state(frame, model)
                if not encoded.get("accepted"):
                    raise ValueError(encoded.get("error_code"))
                state_label = 1_000_000 if won else -1_000_000
                source_outcomes.setdefault(source_hash, set()).add(state_label)
                state_identity = (source_hash, state_label)
                if state_identity not in seen_state_labels:
                    seen_state_labels.add(state_identity)
                    state_samples.append(
                        {
                            "sample_id": f"{source_hash}.{state_label:+d}",
                            "group_id": group_id,
                            "features_milli": encoded["features_milli"],
                            "label_utility": state_label,
                        }
                    )
                # Winning-trajectory preference is better-than-self evidence;
                # losing selections are not inverted into fake counterfactuals.
                if not won:
                    continue
                winning_shadow_window_count += 1
                differential = base.get("turn_program_differential", {})
                policy = decision.get("policy", {})
                host = decision.get("host", {})
                reported_indexes = policy.get("reported_indexes")
                accepted_indexes = host.get("accepted_indexes")
                source = frame.get("source", {})
                exact_host_commit = bool(
                    host.get("status") == "accepted"
                    and type(reported_indexes) is list
                    and reported_indexes
                    and accepted_indexes == reported_indexes
                    and policy.get("reported_public_observation_hash")
                    == source.get("public_observation_hash")
                    and policy.get("reported_window_id") == source.get("window_id")
                )
                canary = base.get("turn_program_canary", {})
                exact_canary_commit = bool(
                    canary.get("applied")
                    and canary.get("authoritative")
                    and base.get("owner_layer") == "turn_program_canary"
                    and canary.get("selected_program_id")
                    == shadow.get("selected_program_id")
                )
                exact_executed_shadow = bool(
                    differential.get("current_step_matches_live")
                    or exact_canary_commit
                )
                if not (
                    differential.get("accepted")
                    and differential.get("public_only")
                    and differential.get("shadow_current_binding_found")
                    and exact_host_commit
                    and exact_executed_shadow
                ):
                    # A shadow suggestion that was not the exact current-window
                    # engine commit is not causal win evidence.  The frame still
                    # trains the state head, but it cannot label either action or
                    # interaction weights.
                    shadow_mismatch_preference_window_count += 1
                    continue
                local_programs = {
                    program["program_id"]: program
                    for program in request.get("programs", [])
                    if type(program) is dict
                }
                rich_programs = public_programs_by_source.get(source_hash, {})
                programs = {
                    program_id: copy.deepcopy(
                        rich_programs.get(program_id, program)
                    )
                    for program_id, program in local_programs.items()
                }
                selected = programs.get(shadow.get("selected_program_id"))
                if selected is None or selected.get("public_outcome", {}).get(
                    "final_prize_knockout"
                ):
                    continue
                preferred = StateConditionedTransactionValueV2.action_features(
                    selected, selected.get("public_outcome", {}), model
                )
                if preferred is None:
                    continue
                preference_count_before = len(preferences)
                for other_id, other in programs.items():
                    if other_id == selected["program_id"] or other.get(
                        "public_outcome", {}
                    ).get("final_prize_knockout"):
                        continue
                    other_features = StateConditionedTransactionValueV2.action_features(
                        other, other.get("public_outcome", {}), model
                    )
                    if other_features is None or preferred == other_features:
                        continue
                    preference_id = f"{source_hash}.{selected['program_id']}.{other_id}"
                    if preference_id in seen_preference_ids:
                        continue
                    seen_preference_ids.add(preference_id)
                    preferences.append(
                        {
                            "sample_id": preference_id,
                            "group_id": group_id,
                            "source": (
                                "winning_executed_canary_trace"
                                if exact_canary_commit
                                else "winning_executed_trace"
                            ),
                            "state_features_milli": encoded["features_milli"],
                            "preferred_action_features_milli": preferred,
                            "other_action_features_milli": other_features,
                            # A successful canary is an exact host-executed
                            # counterfactual, not merely an agreement with the
                            # incumbent Base action.  Keep it below authored
                            # exams in the promotion order, but give its
                            # causal label twice the generic trace weight.
                            "weight_milli": 2000 if exact_canary_commit else 1000,
                        }
                    )
                if len(preferences) > preference_count_before:
                    executed_preference_window_count += 1
                    if exact_canary_commit:
                        canary_executed_preference_window_count += 1
    return state_samples, preferences, {
        "source_receipts": source_receipts,
        "match_group_count": len(groups),
        "state_sample_count": len(state_samples),
        "winning_preference_count": len(preferences),
        "winning_shadow_window_count": winning_shadow_window_count,
        "executed_preference_window_count": executed_preference_window_count,
        "canary_executed_preference_window_count": (
            canary_executed_preference_window_count
        ),
        "shadow_mismatch_preference_window_count": (
            shadow_mismatch_preference_window_count
        ),
        "conflicting_outcome_observation_count": sum(
            len(labels) > 1 for labels in source_outcomes.values()
        ),
        "candidate_wins": wins,
        "candidate_losses": losses,
    }


def _exact_committed_options(decision: dict[str, Any]) -> list[dict[str, Any]] | None:
    frame = decision.get("frame", {})
    policy = decision.get("policy", {})
    host = decision.get("host", {})
    source = frame.get("source", {})
    indexes = policy.get("reported_indexes")
    if not (
        host.get("status") == "accepted"
        and type(indexes) is list
        and host.get("accepted_indexes") == indexes
        and policy.get("reported_public_observation_hash")
        == source.get("public_observation_hash")
        and policy.get("reported_window_id") == source.get("window_id")
    ):
        return None
    options = frame.get("options", [])
    if type(options) is not list:
        return None
    selected: list[dict[str, Any]] = []
    for index in indexes:
        if type(index) is not int or index < 0 or index >= len(options):
            return None
        option = options[index]
        if type(option) is not dict:
            return None
        selected.append(option)
    return selected


def _committed_option_signature(decision: dict[str, Any]) -> tuple[Any, ...] | None:
    selected = _exact_committed_options(decision)
    if selected is None:
        return None
    fields = (
        "kind",
        "card_uid",
        "card_serial",
        "source_uid",
        "source_serial",
        "target_uid",
        "target_serial",
        "attack_index",
        "ability_index",
        "option_number",
    )
    return tuple(tuple(option.get(field) for field in fields) for option in selected)


def _program_for_exact_commit(decision: dict[str, Any]) -> dict[str, Any] | None:
    """Resolve the exact host commit to one public generated program.

    This resolver is deliberately narrower than the runtime binder.  Paired
    branch credit is admitted only for a single current main action whose
    public kind/card/source/target identity maps to exactly one generated
    program.  Ambiguity fails closed rather than inventing a counterfactual.
    """
    frame = decision.get("frame", {})
    if frame.get("prompt_kind") != "main":
        return None
    selected = _exact_committed_options(decision)
    if selected is None or len(selected) != 1:
        return None
    option = selected[0]
    base = decision.get("policy", {}).get("base_result", {})
    generation = base.get("turn_program_generation", {})
    if not generation.get("accepted"):
        return None
    programs = generation.get("request", {}).get("programs", [])
    if type(programs) is not list:
        return None
    context_fields = (
        ("card_uids", "card_uid"),
        ("source_uids", "source_uid"),
        ("target_uids", "target_uid"),
    )
    matches: list[dict[str, Any]] = []
    for program in programs:
        if type(program) is not dict:
            continue
        context = program.get("public_action_context")
        if type(context) is not dict or context.get("kinds") != [option.get("kind")]:
            continue
        matched = True
        for context_name, option_name in context_fields:
            values = context.get(context_name, [])
            if type(values) is not list:
                matched = False
                break
            expected = option.get(option_name)
            if values and values != [expected]:
                matched = False
                break
            if not values and expected is not None and option_name == "card_uid":
                matched = False
                break
        if matched:
            matches.append(copy.deepcopy(program))
    if len(matches) != 1:
        return None
    return matches[0]


def extract_paired_branch_preferences(
    path_pairs: list[tuple[Path, Path]], model: dict[str, Any]
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    """Extract first-divergence credit from deterministic public A/B branches.

    A label is admitted only when two clean traces share seed, seat, opponent,
    exact public observations, and identical exact host commits until one main
    window.  If one resulting branch wins and the other loses, only that first
    differing transaction is labeled.  Later actions receive no inherited
    terminal credit.
    """
    preferences: list[dict[str, Any]] = []
    qualified_pairs: list[dict[str, Any]] = []
    source_receipts: list[dict[str, Any]] = []
    seen_sample_ids: set[str] = set()
    rejected_pair_count = 0
    for left_path, right_path in path_pairs:
        left = json.loads(left_path.read_text(encoding="utf-8"))
        right = json.loads(right_path.read_text(encoding="utf-8"))
        if not all(
            document.get("capture_developer_trace") and document.get("is_clean")
            for document in (left, right)
        ):
            raise ValueError("paired branch trace is not clean developer evidence")
        opponent_archive_sha256 = left.get("opponent", {}).get("archive_sha256")
        if opponent_archive_sha256 != right.get("opponent", {}).get(
            "archive_sha256"
        ):
            raise ValueError("paired branch opponent identity drift")
        source_receipts.append(
            {
                "left_path": left_path.resolve().as_posix(),
                "left_sha256": _sha_file(left_path),
                "right_path": right_path.resolve().as_posix(),
                "right_sha256": _sha_file(right_path),
            }
        )
        left_games = {
            (game.get("seed"), game.get("candidate_seat")): game
            for game in left.get("per_game", [])
        }
        right_games = {
            (game.get("seed"), game.get("candidate_seat")): game
            for game in right.get("per_game", [])
        }
        for game_key in sorted(set(left_games) & set(right_games)):
            left_game = left_games[game_key]
            right_game = right_games[game_key]
            left_won = left_game.get("winner_index") == left_game.get("candidate_seat")
            right_won = right_game.get("winner_index") == right_game.get("candidate_seat")
            if left_won == right_won or not (
                left_game.get("terminal") and right_game.get("terminal")
            ):
                continue
            left_decisions = left_game.get("candidate_developer_decisions", [])
            right_decisions = right_game.get("candidate_developer_decisions", [])
            divergence: tuple[dict[str, Any], dict[str, Any]] | None = None
            for left_decision, right_decision in zip(
                left_decisions, right_decisions, strict=False
            ):
                left_source = left_decision.get("frame", {}).get("source", {})
                right_source = right_decision.get("frame", {}).get("source", {})
                if left_source.get("public_observation_hash") != right_source.get(
                    "public_observation_hash"
                ):
                    break
                left_signature = _committed_option_signature(left_decision)
                right_signature = _committed_option_signature(right_decision)
                if left_signature is None or right_signature is None:
                    break
                if left_signature != right_signature:
                    divergence = (left_decision, right_decision)
                    break
            if divergence is None:
                rejected_pair_count += 1
                continue
            winning_decision, losing_decision = (
                divergence if left_won else (divergence[1], divergence[0])
            )
            winning_frame = winning_decision.get("frame", {})
            if winning_frame.get("prompt_kind") != "main" or losing_decision.get(
                "frame", {}
            ).get("prompt_kind") != "main":
                rejected_pair_count += 1
                continue
            preferred_program = _program_for_exact_commit(winning_decision)
            other_program = _program_for_exact_commit(losing_decision)
            if preferred_program is None or other_program is None:
                rejected_pair_count += 1
                continue
            if preferred_program.get("public_outcome", {}).get("final_prize_knockout") \
                    or other_program.get("public_outcome", {}).get("final_prize_knockout"):
                rejected_pair_count += 1
                continue
            encoded = StateConditionedTransactionValueV2.encode_public_state(
                winning_frame, model
            )
            preferred = StateConditionedTransactionValueV2.action_features(
                preferred_program, preferred_program.get("public_outcome", {}), model
            )
            other = StateConditionedTransactionValueV2.action_features(
                other_program, other_program.get("public_outcome", {}), model
            )
            if not encoded.get("accepted") or preferred is None or other is None \
                    or preferred == other:
                rejected_pair_count += 1
                continue
            source_hash = winning_frame["source"]["public_observation_hash"]
            group_id = (
                f"paired.{opponent_archive_sha256}.seed-{game_key[0]}."
                f"seat-{game_key[1]}"
            )
            sample_id = (
                f"{group_id}.{source_hash}."
                f"{preferred_program['program_id']}.{other_program['program_id']}"
            )
            if sample_id in seen_sample_ids:
                continue
            seen_sample_ids.add(sample_id)
            preferences.append(
                {
                    "sample_id": sample_id,
                    "group_id": group_id,
                    "source": "paired_branch_outcome_trace",
                    "state_features_milli": encoded["features_milli"],
                    "preferred_action_features_milli": preferred,
                    "other_action_features_milli": other,
                    "weight_milli": 3000,
                }
            )
            qualified_pairs.append(
                {
                    "seed": game_key[0],
                    "candidate_seat": game_key[1],
                    "group_id": group_id,
                    "source_hash": source_hash,
                    "preferred_program_id": preferred_program["program_id"],
                    "other_program_id": other_program["program_id"],
                }
            )
    return preferences, {
        "profile_id": "ptcgdap-paired-public-branch-credit-v1",
        "public_only": True,
        "first_divergence_only": True,
        "source_receipts": source_receipts,
        "qualified_pair_count": len(qualified_pairs),
        "rejected_pair_count": rejected_pair_count,
        "preference_count": len(preferences),
        "qualified_pairs": qualified_pairs,
    }


def _split_groups(groups: set[str]) -> tuple[set[str], set[str]]:
    ordered = sorted(groups, key=lambda value: hashlib.sha256(value.encode()).digest())
    validation = {group for offset, group in enumerate(ordered) if offset % 5 == 0}
    training = set(ordered) - validation
    if not training and validation:
        training.add(validation.pop())
    return training, validation


def split_paired_branch_preferences(
    samples: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], dict[str, Any]]:
    """Split whole deterministic match branches before fitting or selection."""
    groups = {sample["group_id"] for sample in samples}
    training_groups, validation_groups = _split_groups(groups)
    training = [
        sample for sample in samples if sample["group_id"] in training_groups
    ]
    validation = [
        sample for sample in samples if sample["group_id"] in validation_groups
    ]
    return training, validation, {
        "profile_id": "ptcgdap-paired-branch-group-split-v1",
        "training_groups": sorted(training_groups),
        "validation_groups": sorted(validation_groups),
        "training_preference_count": len(training),
        "validation_preference_count": len(validation),
        "group_disjoint": training_groups.isdisjoint(validation_groups),
    }


def _state_sign_accuracy(model: dict[str, Any], samples: list[dict[str, Any]]) -> float:
    if not samples:
        return 0.0
    weights = model["state_value_weights_milli"]
    return sum(
        (
            sum(sample["features_milli"].get(name, 0) * weight for name, weight in weights.items())
            > 0
        )
        == (sample["label_utility"] > 0)
        for sample in samples
    ) / len(samples)


def _model_weight_drift_l1(
    anchor: dict[str, Any], candidate: dict[str, Any]
) -> int:
    total = 0
    for head in (
        "state_value_weights_milli",
        "action_value_weights_milli",
        "interaction_weights_milli",
    ):
        names = set(anchor.get(head, {})) | set(candidate.get(head, {}))
        total += sum(
            abs(
                int(candidate.get(head, {}).get(name, 0))
                - int(anchor.get(head, {}).get(name, 0))
            )
            for name in names
        )
    for name in ("temperature_milli", "minimum_override_margin_utility"):
        total += abs(
            int(candidate.get("calibration", {}).get(name, 0))
            - int(anchor.get("calibration", {}).get(name, 0))
        )
    return total


def select_validation_calibrated_model(
    anchored_prior: dict[str, Any],
    fresh_refit: dict[str, Any],
    *,
    alternate_candidates: dict[str, dict[str, Any]] | None = None,
    authored_exams: list[dict[str, Any]],
    paired_branch_exams: list[dict[str, Any]] | None = None,
    executed_canary_exams: list[dict[str, Any]] | None = None,
    validation_preferences: list[dict[str, Any]],
    validation_states: list[dict[str, Any]],
) -> tuple[dict[str, Any], dict[str, Any]]:
    """Select the highest-evidence model without rewarding parameter churn.

    Authored exams remain the strongest locks.  Deterministic paired branches
    then own the first-divergence credit gate, followed by exact host-executed
    canary wins.  Aggregate held-out accuracy cannot hide failure to reproduce
    either stronger class.  Weight drift is only the final tie-break.
    """
    paired_exams = list(paired_branch_exams or [])
    canary_exams = list(executed_canary_exams or [])
    candidates = {
        "anchored_prior": anchored_prior,
        "fresh_refit": fresh_refit,
    }
    for name, candidate in (alternate_candidates or {}).items():
        if name in candidates:
            raise ValueError(f"duplicate model candidate: {name}")
        candidates[name] = candidate
    rows: dict[str, dict[str, Any]] = {}
    selected_name = "anchored_prior"
    selected_key: tuple[float, float, float, float, float, int, int] | None = None
    for name, candidate in candidates.items():
        exam_accuracy = preference_accuracy(candidate, authored_exams)
        paired_branch_accuracy = preference_accuracy(candidate, paired_exams)
        executed_canary_accuracy = preference_accuracy(candidate, canary_exams)
        validation_preference_accuracy = preference_accuracy(
            candidate, validation_preferences
        )
        validation_state_accuracy = _state_sign_accuracy(
            candidate, validation_states
        )
        drift = _model_weight_drift_l1(anchored_prior, candidate)
        rows[name] = {
            "authored_exam_accuracy": exam_accuracy,
            "paired_branch_exam_accuracy": paired_branch_accuracy,
            "paired_branch_exam_count": len(paired_exams),
            "executed_canary_exam_accuracy": executed_canary_accuracy,
            "executed_canary_exam_count": len(canary_exams),
            "validation_preference_accuracy": validation_preference_accuracy,
            "validation_state_sign_accuracy": validation_state_accuracy,
            "interaction_feature_count": len(
                candidate.get("interaction_weights_milli", {})
            ),
            "anchor_weight_drift_l1": drift,
        }
        key = (
            exam_accuracy,
            paired_branch_accuracy,
            executed_canary_accuracy,
            validation_preference_accuracy,
            validation_state_accuracy,
            -len(candidate.get("interaction_weights_milli", {})),
            -drift,
        )
        if selected_key is None or key > selected_key:
            selected_name = name
            selected_key = key
    return copy.deepcopy(candidates[selected_name]), {
        "profile_id": "ptcgdap-validation-anchored-model-selection-v4",
        "selected_candidate": selected_name,
        "selection_order": [
            "authored_exam_accuracy.desc",
            "paired_branch_exam_accuracy.desc",
            "executed_canary_exam_accuracy.desc",
            "validation_preference_accuracy.desc",
            "validation_state_sign_accuracy.desc",
            "interaction_feature_count.asc",
            "anchor_weight_drift_l1.asc",
        ],
        "candidates": rows,
        "public_only": True,
    }


def build_training_run(
    trace_paths: list[Path],
    run_dir: Path,
    *,
    training_run_id: str,
    prior_model_path: Path | None = None,
    prior_package_path: Path | None = None,
    paired_trace_pairs: list[tuple[Path, Path]] | None = None,
) -> dict[str, Any]:
    if prior_model_path is not None and prior_package_path is not None:
        raise ValueError("prior model and prior package are mutually exclusive")
    seed_model = StateConditionedTransactionValueV2.default_model(
        uid_roles=MARNIE_UID_ROLES,
        training_run_id=training_run_id,
    )
    # Retain the strongest clean v1 confirmation as the explicit rollback leaf.
    seed_model["fallback_value_model"]["model_version"] = 6
    seed_model["fallback_value_model"]["feature_weights_milli"].update(
        {"attack_pressure_milli": 1500, "next_turn_continuity_milli": 1800}
    )
    state_samples, trace_preferences, extraction = extract_trace_samples(
        trace_paths, seed_model
    )
    paired_preferences, paired_extraction = extract_paired_branch_preferences(
        list(paired_trace_pairs or []), seed_model
    )
    (
        training_paired_preferences,
        validation_paired_preferences,
        paired_group_split,
    ) = split_paired_branch_preferences(paired_preferences)
    exams = build_authored_exam_preferences(seed_model)
    groups = {sample["group_id"] for sample in state_samples}
    train_groups, validation_groups = _split_groups(groups)
    train_states = [sample for sample in state_samples if sample["group_id"] in train_groups]
    validation_states = [
        sample for sample in state_samples if sample["group_id"] in validation_groups
    ]
    train_preferences = [
        sample for sample in trace_preferences if sample["group_id"] in train_groups
    ]
    validation_preferences = [
        sample for sample in trace_preferences if sample["group_id"] in validation_groups
    ]
    executed_canary_exams = [
        sample
        for sample in validation_preferences
        if sample.get("source") == "winning_executed_canary_trace"
    ]
    dataset = {
        "profile_id": DATASET_PROFILE_ID,
        "training_run_id": training_run_id,
        "group_split": {
            "trace_training": sorted(train_groups),
            "trace_validation": sorted(validation_groups),
            "paired_training": paired_group_split["training_groups"],
            "paired_validation": paired_group_split["validation_groups"],
        },
        "state_samples": state_samples,
        "preference_samples": [*trace_preferences, *paired_preferences, *exams],
    }
    dataset_bytes = _canonical_bytes(dataset)
    dataset_sha = _sha_bytes(dataset_bytes)
    sparse_refits = {
        budget: fit_joint_model(
            seed_model,
            state_samples=train_states,
            preference_samples=[
                *train_preferences,
                *training_paired_preferences,
                *exams,
            ],
            calibration_samples=validation_preferences,
            max_interaction_features=budget,
            training_run_id=training_run_id,
            dataset_sha256=dataset_sha,
        )
        for budget in SPARSE_INTERACTION_FEATURE_BUDGETS
    }
    fresh_refit = sparse_refits[max(SPARSE_INTERACTION_FEATURE_BUDGETS)]
    model_selection: dict[str, Any] = {
        "profile_id": "ptcgdap-validation-anchored-model-selection-v4",
        "selected_candidate": "fresh_refit",
        "selection_order": [],
        "candidates": {},
        "public_only": True,
    }
    model = fresh_refit
    prior_source_path = prior_model_path or prior_package_path
    if prior_source_path is not None:
        if prior_package_path is not None:
            prior_handle = AuthorStrategyPackageLoader().load_bytes(
                prior_package_path.read_bytes()
            )
            anchored_prior = json.loads(
                prior_handle.payload_bytes("policy/weights.bin")
            )
            prior_source_kind = "signed_package_embedded_model"
        else:
            anchored_prior = json.loads(
                prior_model_path.read_text(encoding="utf-8")
            )
            prior_source_kind = "model_file"
        prior_error = StateConditionedTransactionValueV2.model_error(anchored_prior)
        if prior_error:
            raise ValueError(f"invalid prior model: {prior_error}")
        if anchored_prior.get("uid_roles") != seed_model.get("uid_roles"):
            raise ValueError("prior model role schema drift")
        model, model_selection = select_validation_calibrated_model(
            anchored_prior,
            fresh_refit,
            alternate_candidates={
                f"sparse_{budget}": candidate
                for budget, candidate in sparse_refits.items()
                if budget != max(SPARSE_INTERACTION_FEATURE_BUDGETS)
            },
            authored_exams=exams,
            paired_branch_exams=validation_paired_preferences,
            executed_canary_exams=executed_canary_exams,
            validation_preferences=validation_preferences,
            validation_states=validation_states,
        )
        model_selection["prior_source_kind"] = prior_source_kind
        model_selection["prior_source_path"] = prior_source_path.resolve().as_posix()
        model_selection["prior_source_sha256"] = _sha_file(prior_source_path)
        _stamp_training_identity(
            model,
            training_run_id=training_run_id,
            dataset_sha256=dataset_sha,
        )
        selected_error = StateConditionedTransactionValueV2.model_error(model)
        if selected_error:
            raise ValueError(selected_error)
    metrics = {
        "training_state_sign_accuracy": _state_sign_accuracy(model, train_states),
        "validation_state_sign_accuracy": _state_sign_accuracy(model, validation_states),
        "training_preference_accuracy": preference_accuracy(model, train_preferences),
        "validation_preference_accuracy": preference_accuracy(
            model, validation_preferences
        ),
        "authored_exam_accuracy": preference_accuracy(model, exams),
        "authored_exam_count": len(exams),
        "training_paired_branch_accuracy": preference_accuracy(
            model, training_paired_preferences
        ),
        "training_paired_branch_count": len(training_paired_preferences),
        "paired_branch_exam_accuracy": preference_accuracy(
            model, validation_paired_preferences
        ),
        "paired_branch_exam_count": len(validation_paired_preferences),
        "executed_canary_exam_accuracy": preference_accuracy(
            model, executed_canary_exams
        ),
        "executed_canary_exam_count": len(executed_canary_exams),
        "calibrated_temperature_milli": model["calibration"]["temperature_milli"],
        "minimum_override_margin_utility": model["calibration"][
            "minimum_override_margin_utility"
        ],
        "state_head_feature_count": len(model["state_value_weights_milli"]),
        "action_head_feature_count": len(model["action_value_weights_milli"]),
        "interaction_head_feature_count": len(model["interaction_weights_milli"]),
        "interaction_feature_budgets": list(SPARSE_INTERACTION_FEATURE_BUDGETS),
        "selected_candidate": model_selection["selected_candidate"],
    }
    run_dir.mkdir(parents=True, exist_ok=False)
    (run_dir / "dataset.json").write_bytes(dataset_bytes + b"\n")
    (run_dir / "model.json").write_bytes(_canonical_bytes(model) + b"\n")
    (run_dir / "metrics.json").write_bytes(_canonical_bytes(metrics) + b"\n")
    manifest = {
        "profile_id": PROFILE_ID,
        "training_run_id": training_run_id,
        "dataset_sha256": dataset_sha,
        "model_sha256": _sha_file(run_dir / "model.json"),
        "metrics_sha256": _sha_file(run_dir / "metrics.json"),
        "public_only": True,
        "grouped_validation": True,
        "paired_branch_group_split": paired_group_split,
        "label_policy": {
            "state_value": "terminal candidate-seat outcome",
            "action": "winning exact executed-shadow agreement better-than-self only",
            "interaction": "winning exact executed-shadow agreement plus authored public exams",
            "executed_canary": (
                "exact authoritative host-executed winning override; 2x trace weight; "
                "selection gate below authored exams and above generic validation"
            ),
            "paired_branch": (
                "same seed/seat/opponent and exact public history through first differing "
                "host commit; winning transaction over losing transaction only; whole-match "
                "groups split before fit; validation branches are selection-only"
            ),
            "interaction_distillation": (
                "fit-only normalized orthogonal residual ranking with fixed sparse budgets; "
                "held-out branch and benchmark rows are excluded from feature selection"
            ),
            "losing_unselected_counterfactuals_invented": False,
        },
        "model_selection": model_selection,
        "paired_branch_extraction": paired_extraction,
        **extraction,
        "metrics": metrics,
        "promotion_eligible": False,
        "promotion_reason": "requires_clean_benchmark_gate",
        "rollback_profile_id": model["fallback_value_model"]["profile_id"],
        "rollback_model_version": model["fallback_value_model"]["model_version"],
    }
    (run_dir / "manifest.json").write_bytes(_canonical_bytes(manifest) + b"\n")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--trace", action="append", type=Path, required=True)
    parser.add_argument("--run-dir", type=Path, required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--prior-model", type=Path)
    parser.add_argument("--prior-package", type=Path)
    parser.add_argument(
        "--paired-trace", action="append", nargs=2, type=Path, default=[]
    )
    args = parser.parse_args()
    manifest = build_training_run(
        [path.resolve() for path in args.trace],
        args.run_dir.resolve(),
        training_run_id=args.run_id,
        prior_model_path=(
            args.prior_model.resolve() if args.prior_model is not None else None
        ),
        prior_package_path=(
            args.prior_package.resolve() if args.prior_package is not None else None
        ),
        paired_trace_pairs=[
            (left.resolve(), right.resolve()) for left, right in args.paired_trace
        ],
    )
    print(json.dumps(manifest, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
