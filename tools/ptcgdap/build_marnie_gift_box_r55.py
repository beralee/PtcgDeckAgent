from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.author_strategy_package import AuthorStrategyPackageLoader  # noqa: E402
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes  # noqa: E402
from tools.ptcgdap.build_author_strategy_package import (  # noqa: E402
    TEST_FIXTURE_KEY_ID,
    build_package_bytes,
)
from tools.ptcgdap.build_marnie_gift_box_r54 import (  # noqa: E402
    TEST_FIXTURE_PRIVATE_KEY,
    _condition,
    build_payloads as build_r54_payloads,
)


OUTPUT = (
    ROOT
    / "data/ptcgdap/author_strategy_packages"
    / "marnies-gift-box-rule-marnie-r55-5.15.0.ptcgai"
)


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _step(
    step_id: str,
    goal_id: str,
    *,
    prompt_kinds: list[str],
    required_when: list[dict[str, object]],
    complete_when: list[dict[str, object]],
    option_when: list[dict[str, object]],
    score_bonus: int,
    selection_count: int = 1,
    terminal: bool = False,
    sequence_barrier: bool = False,
) -> dict[str, object]:
    step: dict[str, object] = {
        "step_id": step_id,
        "prompt_kinds": prompt_kinds,
        "goal_id": goal_id,
        "required_when": required_when,
        "complete_when": complete_when,
        "option_when": option_when,
        "score_bonus": score_bonus,
        "selection_count": selection_count,
        "terminal": terminal,
        "checkpoint": True,
        "required_before_attack": True,
    }
    if sequence_barrier:
        step["sequence_barrier"] = True
    return step


def _main_step(
    step_id: str,
    goal_id: str,
    required_when: list[dict[str, object]],
    option_when: list[dict[str, object]],
    score_bonus: int,
) -> dict[str, object]:
    return _step(
        step_id,
        goal_id,
        prompt_kinds=["main"],
        required_when=required_when,
        complete_when=[],
        option_when=option_when,
        score_bonus=score_bonus,
    )


def _tm_target_group(
    group_id: str,
    card_uid: str,
    selection_count: int,
    *extra: dict[str, object],
) -> dict[str, object]:
    return {
        "group_id": group_id,
        "selection_count": selection_count,
        "option_when": [
            _condition("option.card_uid", "eq", card_uid),
            *extra,
        ],
    }


def _tm_safe_combinations() -> list[
    tuple[str, list[dict[str, object]], list[dict[str, object]]]
]:
    eligible = "self.bench.evolution_eligible_count_uid"
    funded_eligible = "self.bench.energy_bearing_evolution_eligible_count_uid"
    snorunt = "CSV9.5C_043"
    impidimp = "CSV10C_146"
    morgrem = "CSV10C_147"
    return [
        (
            "balanced-snorunt-impidimp",
            [
                _condition(eligible, "gte", 1, snorunt),
                _condition(eligible, "gte", 1, impidimp),
                _condition(funded_eligible, "eq", 0, morgrem),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_148"),
            ],
            [
                _tm_target_group("one-impidimp", impidimp, 1),
                _tm_target_group("one-snorunt", snorunt, 1),
            ],
        ),
        (
            "two-snorunt",
            [
                _condition(eligible, "gte", 2, snorunt),
            ],
            [_tm_target_group("two-snorunt", snorunt, 2)],
        ),
        (
            "snorunt-impidimp",
            [
                _condition(eligible, "gte", 1, snorunt),
                _condition(eligible, "gte", 1, impidimp),
                _condition(funded_eligible, "eq", 0, morgrem),
            ],
            [
                _tm_target_group("one-snorunt", snorunt, 1),
                _tm_target_group("one-impidimp", impidimp, 1),
            ],
        ),
        (
            "snorunt-funded-morgrem",
            [
                _condition(eligible, "gte", 1, snorunt),
                _condition(funded_eligible, "gte", 1, morgrem),
            ],
            [
                _tm_target_group("one-snorunt", snorunt, 1),
                _tm_target_group(
                    "one-funded-morgrem",
                    morgrem,
                    1,
                    _condition("option.target_attached_energy_count", "gte", 1),
                ),
            ],
        ),
        (
            "two-impidimp",
            [_condition(eligible, "gte", 2, impidimp)],
            [_tm_target_group("two-impidimp", impidimp, 2)],
        ),
        (
            "impidimp-funded-morgrem",
            [
                _condition(eligible, "gte", 1, impidimp),
                _condition(funded_eligible, "gte", 1, morgrem),
            ],
            [
                _tm_target_group("one-impidimp", impidimp, 1),
                _tm_target_group(
                    "one-funded-morgrem",
                    morgrem,
                    1,
                    _condition("option.target_attached_energy_count", "gte", 1),
                ),
            ],
        ),
        (
            "two-funded-morgrem",
            [_condition(funded_eligible, "gte", 2, morgrem)],
            [
                _tm_target_group(
                    "two-funded-morgrem",
                    morgrem,
                    2,
                    _condition("option.target_attached_energy_count", "gte", 1),
                )
            ],
        ),
    ]


def _tm_safe_methods(
    phase: str,
    steps: list[dict[str, object]],
) -> list[dict[str, object]]:
    methods: list[dict[str, object]] = []
    for offset, (name, conditions, groups) in enumerate(_tm_safe_combinations()):
        method_steps = copy.deepcopy(steps)
        if phase in {"target", "target_and_evolution"}:
            method_steps[0]["selection_groups"] = groups
        if phase == "target_and_evolution":
            evolution_by_target = {
                "CSV9.5C_043": "CSV7C_059",
                "CSV10C_146": "CSV10C_147",
                "CSV10C_147": "CSV10C_148",
            }
            evolution_groups: list[dict[str, object]] = []
            for group in groups:
                target_uid = next(
                    condition["value"]
                    for condition in group["option_when"]
                    if condition["fact"] == "option.card_uid"
                )
                evolution_groups.append(
                    {
                        "group_id": f"evolution-{group['group_id']}",
                        "selection_count": group["selection_count"],
                        "option_when": [
                            _condition("option.kind", "eq", "search"),
                            _condition(
                                "option.card_uid",
                                "eq",
                                evolution_by_target[str(target_uid)],
                            ),
                        ],
                    }
                )
            method_steps[1]["selection_groups"] = evolution_groups
        methods.append(
            {
                "method_id": f"{phase}-{name}",
                "priority": 1000 - offset,
                "when": conditions,
                "steps": method_steps,
            }
        )
    return methods


def _core_steps(*, include_tm_finish: bool) -> list[dict[str, object]]:
    steps = [
        _main_step(
            "move-damage-before-commit",
            "munkidori-transfer",
            [
                _condition("damage.best_transfer_count", "gt", 0),
                _condition("turn_number", "gte", 3),
            ],
            [
                _condition("option.kind", "eq", "use_ability"),
                _condition("option.source_uid", "eq", "CSV8C_094"),
            ],
            900000,
        ),
        _main_step(
            "evolve-froslass-before-commit",
            "double-froslass-engine",
            [
                _condition("self.board.count_uid", "gte", 1, "CSV9.5C_043"),
                _condition("self.board.count_uid", "lt", 2, "CSV7C_059"),
            ],
            [
                _condition("option.kind", "eq", "evolve"),
                _condition("option.card_uid", "eq", "CSV7C_059"),
                _condition("option.target_uid", "eq", "CSV9.5C_043"),
            ],
            880000,
        ),
        _main_step(
            "spikemuth-build-funded-morgrem",
            "backup-grimmsnarl",
            [
                _condition(
                    "self.board.energy_bearing_count_uid", "gte", 1, "CSV10C_146"
                ),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_147"),
                _condition("self.prizes_remaining", "gt", 1),
            ],
            [
                _condition("option.kind", "eq", "use_stadium_effect"),
                _condition("option.source_uid", "eq", "CSV10C_216"),
            ],
            860000,
        ),
        _main_step(
            "disrupt-large-opponent-hand",
            "grimmsnarl-prize-route",
            [
                _condition("self.hand.count_uid", "gte", 1, "CSV3C_123"),
                _condition("turn.supporter_available", "eq", True),
                _condition("opponent.hand_count", "gte", 5),
            ],
            [
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSV3C_123"),
            ],
            840000,
        ),
        _main_step(
            "refill-low-hand",
            "double-froslass-engine",
            [
                _condition("self.hand.count_uid", "gte", 1, "CSV1C_121"),
                _condition("self.hand_count", "lte", 5),
                _condition("self.deck_count", "gt", 10),
                _condition("turn.supporter_available", "eq", True),
            ],
            [
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSV1C_121"),
            ],
            820000,
        ),
        _main_step(
            "search-core-from-live-snorunt",
            "core-engine-online",
            [
                _condition("self.hand.count_uid", "gte", 1, "CSV1C_123"),
                _condition("self.board.count_uid", "gte", 1, "CSV9.5C_043"),
                _condition("goal.complete", "eq", False),
                _condition("turn.supporter_available", "eq", True),
            ],
            [
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSV1C_123"),
            ],
            800000,
        ),
        _main_step(
            "search-core-from-live-impidimp",
            "core-engine-online",
            [
                _condition("self.hand.count_uid", "gte", 1, "CSV1C_123"),
                _condition("self.board.count_uid", "gte", 1, "CSV10C_146"),
                _condition("goal.complete", "eq", False),
                _condition("turn.supporter_available", "eq", True),
            ],
            [
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSV1C_123"),
            ],
            800000,
        ),
        _main_step(
            "search-core-from-live-morgrem",
            "core-engine-online",
            [
                _condition("self.hand.count_uid", "gte", 1, "CSV1C_123"),
                _condition("self.board.count_uid", "gte", 1, "CSV10C_147"),
                _condition("goal.complete", "eq", False),
                _condition("turn.supporter_available", "eq", True),
            ],
            [
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSV1C_123"),
            ],
            800000,
        ),
        _main_step(
            "evolve-grimmsnarl-from-hand",
            "backup-grimmsnarl",
            [
                _condition("self.board.count_uid", "gte", 1, "CSV10C_147"),
                _condition("self.board.count_uid", "lt", 1, "CSV10C_148"),
            ],
            [
                _condition("option.kind", "eq", "evolve"),
                _condition("option.card_uid", "eq", "CSV10C_148"),
                _condition("option.target_uid", "eq", "CSV10C_147"),
            ],
            780000,
        ),
        _main_step(
            "punk-up-exact-board-debt",
            "marnie-board-exact-two",
            [_condition("goal.energy_debt", "gt", 0)],
            [
                _condition("option.kind", "eq", "use_ability"),
                _condition("option.source_uid", "eq", "CSV10C_148"),
                _condition("option.ability_index", "eq", 0),
            ],
            760000,
        ),
        _main_step(
            "evolve-funded-impidimp-only",
            "backup-grimmsnarl",
            [
                _condition(
                    "self.board.energy_bearing_count_uid", "gte", 1, "CSV10C_146"
                ),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_147"),
            ],
            [
                _condition("option.kind", "eq", "evolve"),
                _condition("option.card_uid", "eq", "CSV10C_147"),
                _condition("option.target_uid", "eq", "CSV10C_146"),
                _condition("option.target_attached_energy_count", "gte", 1),
            ],
            740000,
        ),
        _main_step(
            "bench-munkidori-for-froslass-engine",
            "munkidori-transfer",
            [
                _condition("self.board.count_uid", "gte", 1, "CSV7C_059"),
                _condition("self.board.count_uid", "eq", 0, "CSV8C_094"),
                _condition("turn_number", "gte", 3),
            ],
            [
                _condition("option.kind", "eq", "play_basic_to_bench"),
                _condition("option.card_uid", "eq", "CSV8C_094"),
            ],
            720000,
        ),
        _main_step(
            "fund-munkidori-before-commit",
            "munkidori-transfer",
            [
                _condition("self.board.count_uid", "gte", 1, "CSV8C_094"),
                _condition(
                    "self.board.energy_bearing_count_uid", "eq", 0, "CSV8C_094"
                ),
                _condition("turn.manual_attachment_available", "eq", True),
            ],
            [
                _condition("option.kind", "eq", "attach_energy"),
                _condition("option.card_uid", "eq", "CSVE1C_DAR"),
                _condition("option.target_uid", "eq", "CSV8C_094"),
                _condition("option.target_attached_energy_count", "eq", 0),
            ],
            700000,
        ),
    ]
    # Hard transaction debt is reserved for deterministic, no-opportunity-cost
    # board progress. Supporters, search, bench deployment, and manual Energy
    # remain scored proposals because they consume a scarce resource or change
    # hidden draws; the transaction must not pretend that merely legal is safe.
    opportunity_cost_steps = {
        "disrupt-large-opponent-hand",
        "refill-low-hand",
        "search-core-from-live-snorunt",
        "search-core-from-live-impidimp",
        "search-core-from-live-morgrem",
        "bench-munkidori-for-froslass-engine",
        "fund-munkidori-before-commit",
    }
    steps = [
        step for step in steps if step["step_id"] not in opportunity_cost_steps
    ]
    # Losing the only Pokemon is a turn-commit debt, not a global action bonus.
    # These steps may veto attack/end-turn when the board has no reserve, while
    # the policy arbiter still keeps an independently preferred non-commit
    # proposal (for example Buddy-Buddy Poffin or Arven) ahead of them.
    reserve_conditions = [
        _condition("self.bench_count", "eq", 0),
        _condition("self.active.count_uid", "eq", 0, "CSV8C_094"),
        _condition("self.prizes_remaining", "gt", 0),
        _condition("opponent.prizes_remaining", "gt", 0),
        _condition("turn_number", "gte", 1),
    ]
    steps.extend(
        [
            _main_step(
                "reserve-shaymin-before-commit",
                "core-engine-online",
                reserve_conditions,
                [
                    _condition("option.kind", "eq", "play_basic_to_bench"),
                    _condition("option.card_uid", "eq", "CSV10C_007"),
                ],
                990000,
            ),
            _main_step(
                "reserve-snorunt-before-commit",
                "double-froslass-engine",
                reserve_conditions,
                [
                    _condition("option.kind", "eq", "play_basic_to_bench"),
                    _condition("option.card_uid", "eq", "CSV9.5C_043"),
                ],
                970000,
            ),
            _main_step(
                "reserve-impidimp-before-commit",
                "backup-grimmsnarl",
                reserve_conditions,
                [
                    _condition("option.kind", "eq", "play_basic_to_bench"),
                    _condition("option.card_uid", "eq", "CSV10C_146"),
                ],
                950000,
            ),
            _main_step(
                "reserve-munkidori-before-commit",
                "munkidori-transfer",
                reserve_conditions,
                [
                    _condition("option.kind", "eq", "play_basic_to_bench"),
                    _condition("option.card_uid", "eq", "CSV8C_094"),
                ],
                930000,
            ),
        ]
    )
    current_two_prize_commit = _main_step(
        "commit-current-two-prize-ko",
        "grimmsnarl-prize-route",
        [
            _condition("window.attack_option_count", "gt", 0),
            _condition("damage.best_prize_yield", "gte", 2),
            _condition("damage.best_attack_windows_to_ko", "eq", 1),
            _condition("opponent.prizes_remaining", "gte", 1),
        ],
        [
            _condition("option.kind", "eq", "attack"),
            _condition("option.projected_damage", "gt", 0),
        ],
        990000,
    )
    current_two_prize_commit["terminal"] = True
    steps.extend(
        [
            current_two_prize_commit,
            _main_step(
                "gust-immediate-two-prize-ko",
                "grimmsnarl-prize-route",
                [
                    _condition("damage.current_attack_damage", "gt", 0),
                    _condition("window.attack_option_count", "gt", 0),
                    _condition("damage.best_prize_yield", "eq", 1),
                    _condition("damage.best_gust_prize_yield", "gte", 2),
                    _condition(
                        "damage.best_gust_attack_windows_to_ko", "eq", 1
                    ),
                    _condition("opponent.prizes_remaining", "gte", 2),
                ],
                [
                    _condition("option.kind", "eq", "play_trainer"),
                    _condition("option.card_uid", "eq", "CSV6C_114"),
                ],
                970000,
            ),
            _main_step(
                "boss-immediate-two-prize-ko",
                "grimmsnarl-prize-route",
                [
                    _condition("damage.current_attack_damage", "gt", 0),
                    _condition("window.attack_option_count", "gt", 0),
                    _condition("damage.best_prize_yield", "eq", 1),
                    _condition("damage.best_gust_prize_yield", "gte", 2),
                    _condition(
                        "damage.best_gust_attack_windows_to_ko", "eq", 1
                    ),
                    _condition("opponent.prizes_remaining", "gte", 2),
                    _condition("turn.supporter_available", "eq", True),
                    _condition(
                        "window.option_count_card_uid", "eq", 0, "CSV6C_114"
                    ),
                ],
                [
                    _condition("option.kind", "eq", "play_trainer"),
                    _condition("option.card_uid", "eq", "CSVH1aC_023"),
                ],
                960000,
            ),
            _main_step(
                "attach-devolution-to-funded-grimmsnarl",
                "devolution-finish",
                [
                    _condition("damage.current_attack_damage", "eq", 0),
                    _condition("self.active.count_uid", "gte", 1, "CSV10C_148"),
                    _condition("opponent.active.prize_value", "eq", 1),
                ],
                [
                    _condition("option.kind", "eq", "attach_tool"),
                    _condition("option.card_uid", "eq", "CSV5C_120"),
                    _condition("option.target_uid", "eq", "CSV10C_148"),
                    _condition("option.target_is_active", "eq", True),
                    _condition("option.target_attached_energy_count", "gte", 2),
                ],
                920000,
            ),
            _main_step(
                "commit-devolution-through-wall",
                "devolution-finish",
                [
                    _condition("damage.current_attack_damage", "eq", 0),
                    _condition("self.active.count_uid", "gte", 1, "CSV10C_148"),
                    _condition("opponent.active.prize_value", "eq", 1),
                ],
                [
                    _condition("option.kind", "eq", "granted_attack"),
                    _condition("option.source_uid", "eq", "CSV5C_120"),
                    _condition("option.attack_index", "eq", 0),
                ],
                910000,
            ),
        ]
    )
    steps[-1]["terminal"] = True
    return steps


def _pre_attack_transaction(
    transaction_id: str, source_uid: str, priority: int
) -> dict[str, object]:
    return {
        "transaction_id": transaction_id,
        "priority": priority,
        "goal_id": "core-engine-online",
        "deadline_turns": 0,
        "when": [
            _condition("prompt_kind", "eq", "main"),
            _condition("window.option_count_source_uid", "gt", 0, source_uid),
        ],
        "success_when": [],
        "abort_when": [_condition("opponent.prizes_remaining", "eq", 0)],
        "methods": [
            {
                "method_id": "safe-development-before-commit",
                "priority": 1000,
                "when": [],
                "steps": _core_steps(include_tm_finish=False),
            }
        ],
    }


def _search_owned_tm_evolution_steps() -> list[dict[str, object]]:
    acquired_conditions = [
        _condition(
            "self.bench.evolution_eligible_count_uid", "gte", 1, "CSV9.5C_043"
        ),
        _condition(
            "self.bench.evolution_eligible_count_uid", "gte", 1, "CSV10C_146"
        ),
    ]
    poffin_target_step = _step(
        "poffin-create-tm-targets",
        "core-engine-online",
        prompt_kinds=["search"],
        required_when=[
            _condition("window.source_uid", "eq", "CSV7C_177"),
        ],
        complete_when=acquired_conditions,
        option_when=[_condition("option.kind", "eq", "search")],
        score_bonus=950000,
        selection_count=2,
    )
    poffin_target_step["selection_groups"] = [
        {
            "group_id": "one-impidimp",
            "selection_count": 1,
            "option_when": [
                _condition("option.kind", "eq", "search"),
                _condition("option.card_uid", "eq", "CSV10C_146"),
            ],
        },
        {
            "group_id": "one-snorunt",
            "selection_count": 1,
            "option_when": [
                _condition("option.kind", "eq", "search"),
                _condition("option.card_uid", "eq", "CSV9.5C_043"),
            ],
        },
    ]
    return [
        _step(
            "fund-active-tm-carrier-before-search",
            "core-engine-online",
            prompt_kinds=["main"],
            required_when=[
                _condition("self.hand.count_uid", "gte", 1, "CSV1C_123"),
                _condition("self.active.energy_count_uid", "eq", 0, "CSVE1C_DAR"),
                _condition("turn.manual_attachment_available", "eq", True),
            ],
            complete_when=[
                _condition("self.active.energy_count_uid", "gte", 1, "CSVE1C_DAR")
            ],
            option_when=[
                _condition("option.kind", "eq", "attach_energy"),
                _condition("option.card_uid", "eq", "CSVE1C_DAR"),
                _condition("option.target_is_active", "eq", True),
            ],
            score_bonus=1000000,
            sequence_barrier=True,
        ),
        _step(
            "play-arven-for-tm-evolution",
            "core-engine-online",
            prompt_kinds=["main"],
            required_when=[
                _condition("self.hand.count_uid", "eq", 0, "CSV5C_119"),
                _condition("self.hand.count_uid", "gte", 1, "CSV1C_123"),
                _condition("turn.supporter_available", "eq", True),
            ],
            complete_when=[_condition("turn.supporter_available", "eq", False)],
            option_when=[
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSV1C_123"),
            ],
            score_bonus=990000,
            sequence_barrier=True,
        ),
        _step(
            "search-poffin-for-tm-evolution",
            "core-engine-online",
            prompt_kinds=["search"],
            required_when=[
                _condition("window.source_uid", "eq", "CSV1C_123"),
                _condition("self.hand.count_uid", "eq", 0, "CSV7C_177"),
            ],
            complete_when=[
                _condition("self.hand.count_uid", "gte", 1, "CSV7C_177")
            ],
            option_when=[
                _condition("option.kind", "eq", "search"),
                _condition("option.card_uid", "eq", "CSV7C_177"),
                _condition("option.source_uid", "eq", "CSV1C_123"),
            ],
            score_bonus=980000,
        ),
        _step(
            "search-tm-after-proof",
            "core-engine-online",
            prompt_kinds=["search"],
            required_when=[
                _condition("window.source_uid", "eq", "CSV1C_123"),
                _condition("self.hand.count_uid", "eq", 0, "CSV5C_119"),
            ],
            complete_when=[
                _condition("self.hand.count_uid", "gte", 1, "CSV5C_119")
            ],
            option_when=[
                _condition("option.kind", "eq", "search"),
                _condition("option.card_uid", "eq", "CSV5C_119"),
                _condition("option.source_uid", "eq", "CSV1C_123"),
            ],
            score_bonus=970000,
        ),
        _step(
            "play-poffin-for-tm-targets",
            "core-engine-online",
            prompt_kinds=["main"],
            required_when=[
                _condition("self.hand.count_uid", "gte", 1, "CSV7C_177"),
            ],
            complete_when=acquired_conditions,
            option_when=[
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSV7C_177"),
            ],
            score_bonus=960000,
            sequence_barrier=True,
        ),
        poffin_target_step,
        _step(
            "attach-tm-to-funded-active",
            "core-engine-online",
            prompt_kinds=["main"],
            required_when=[
                *acquired_conditions,
                _condition("self.hand.count_uid", "gte", 1, "CSV5C_119"),
                _condition("self.active.energy_count_uid", "gte", 1, "CSVE1C_DAR"),
            ],
            complete_when=[
                _condition("self.active.attached_tool_uid", "eq", "CSV5C_119")
            ],
            option_when=[
                _condition("option.kind", "eq", "attach_tool"),
                _condition("option.card_uid", "eq", "CSV5C_119"),
                _condition("option.target_is_active", "eq", True),
                _condition("option.target_attached_energy_count", "gte", 1),
            ],
            score_bonus=940000,
            sequence_barrier=True,
        ),
        _step(
            "grant-tm-evolution",
            "core-engine-online",
            prompt_kinds=["main"],
            required_when=[
                _condition("self.active.attached_tool_uid", "eq", "CSV5C_119")
            ],
            complete_when=[],
            option_when=[
                _condition("option.kind", "eq", "granted_attack"),
                _condition("option.source_uid", "eq", "CSV5C_119"),
                _condition("option.attack_index", "eq", 0),
            ],
            score_bonus=930000,
            terminal=True,
        ),
    ]


def _search_owned_tm_evolution_transaction() -> dict[str, object]:
    return {
        "transaction_id": "early-search-owned-tm-evolution",
        "priority": 7300,
        "goal_id": "core-engine-online",
        "deadline_turns": 0,
        "when": [
            _condition("prompt_kind", "eq", "main"),
            _condition("turn_number", "gte", 2),
            _condition("turn_number", "lte", 3),
            _condition("self.hand.count_uid", "gte", 1, "CSV1C_123"),
            _condition("self.hand.count_uid", "eq", 0, "CSV7C_177"),
            _condition("turn.supporter_available", "eq", True),
            _condition("window.option_count_card_uid", "gt", 0, "CSV1C_123"),
            _condition("window.option_count_card_uid", "eq", 0, "CSV2C_127"),
            _condition("window.option_count_source_uid", "eq", 0, "CSV2C_127"),
            _condition("window.option_count_card_uid", "eq", 0, "CSV10C_216"),
            _condition("window.option_count_source_uid", "eq", 0, "CSV10C_216"),
            _condition("window.option_count_card_uid", "eq", 0, "CSV10C_147"),
            _condition("window.option_count_card_uid", "eq", 0, "CSV7C_059"),
            _condition("self.bench_count", "lt", 2),
            _condition("self.board.count_uid", "lt", 2, "CSV7C_059"),
            _condition("self.board.count_uid", "lt", 1, "CSV10C_148"),
            _condition("opponent.prizes_remaining", "gt", 0),
        ],
        "continue_when": [
            _condition("turn_number", "lte", 3),
            _condition("self.board.count_uid", "lt", 2, "CSV7C_059"),
            _condition("self.board.count_uid", "lt", 1, "CSV10C_148"),
            _condition("opponent.prizes_remaining", "gt", 0),
        ],
        "success_when": [
            _condition("prompt_kind", "eq", "attack_target"),
            _condition("select.context_raw", "eq", 25),
        ],
        "abort_when": [_condition("opponent.prizes_remaining", "eq", 0)],
        "methods": [
            {
                "method_id": "build-tm-pair",
                "priority": 1000,
                "when": [],
                "steps": _search_owned_tm_evolution_steps(),
            },
        ],
    }


def _search_owned_tm_devolution_transaction() -> dict[str, object]:
    return {
        "transaction_id": "zero-damage-wall-search-owned-devolution",
        "priority": 7280,
        "goal_id": "devolution-finish",
        "deadline_turns": 0,
        "when": [
            _condition("prompt_kind", "eq", "main"),
            _condition("self.active.count_uid", "gte", 1, "CSV10C_148"),
            _condition("damage.current_attack_damage", "eq", 0),
            _condition("opponent.active.remaining_hp", "lte", 80),
            _condition("opponent.active.prize_value", "eq", 1),
            _condition("opponent.prizes_remaining", "gt", 0),
            _condition("self.hand.count_uid", "gte", 1, "CSV1C_123"),
            _condition("turn.supporter_available", "eq", True),
            _condition("window.option_count_card_uid", "gt", 0, "CSV1C_123"),
            _condition("window.option_count_card_uid", "eq", 0, "CSV8C_094"),
        ],
        "continue_when": [
            _condition("self.active.count_uid", "gte", 1, "CSV10C_148"),
            _condition("damage.current_attack_damage", "eq", 0),
            _condition("opponent.active.remaining_hp", "lte", 80),
            _condition("opponent.active.prize_value", "eq", 1),
            _condition("opponent.prizes_remaining", "gt", 0),
        ],
        "success_when": [],
        "abort_when": [_condition("opponent.prizes_remaining", "eq", 0)],
        "methods": [
            {
                "method_id": "arven-search-attach-active-devolve",
                "priority": 1000,
                "when": [],
                "steps": [
                    _step(
                        "play-arven-for-zero-damage-devolution",
                        "devolution-finish",
                        prompt_kinds=["main"],
                        required_when=[
                            _condition(
                                "self.hand.count_uid", "eq", 0, "CSV5C_120"
                            ),
                            _condition(
                                "self.hand.count_uid", "gte", 1, "CSV1C_123"
                            ),
                            _condition("turn.supporter_available", "eq", True),
                        ],
                        complete_when=[
                            _condition("turn.supporter_available", "eq", False)
                        ],
                        option_when=[
                            _condition("option.kind", "eq", "play_trainer"),
                            _condition("option.card_uid", "eq", "CSV1C_123"),
                        ],
                        score_bonus=1000000,
                        sequence_barrier=True,
                    ),
                    _step(
                        "search-devolution-through-arven-tool-branch",
                        "devolution-finish",
                        prompt_kinds=["search"],
                        required_when=[
                            _condition("window.source_uid", "eq", "CSV1C_123"),
                            _condition(
                                "self.hand.count_uid", "eq", 0, "CSV5C_120"
                            ),
                        ],
                        complete_when=[
                            _condition(
                                "self.hand.count_uid", "gte", 1, "CSV5C_120"
                            )
                        ],
                        option_when=[
                            _condition("option.kind", "eq", "search"),
                            _condition("option.card_uid", "eq", "CSV5C_120"),
                            _condition("option.source_uid", "eq", "CSV1C_123"),
                        ],
                        score_bonus=990000,
                    ),
                    _step(
                        "attach-devolution-to-funded-active-only",
                        "devolution-finish",
                        prompt_kinds=["main"],
                        required_when=[
                            _condition(
                                "self.hand.count_uid", "gte", 1, "CSV5C_120"
                            )
                        ],
                        complete_when=[
                            _condition(
                                "self.active.attached_tool_uid", "eq", "CSV5C_120"
                            )
                        ],
                        option_when=[
                            _condition("option.kind", "eq", "attach_tool"),
                            _condition("option.card_uid", "eq", "CSV5C_120"),
                            _condition("option.target_is_active", "eq", True),
                            _condition(
                                "option.target_attached_energy_count", "gte", 1
                            ),
                        ],
                        score_bonus=980000,
                        sequence_barrier=True,
                    ),
                    _step(
                        "grant-search-owned-tm-devolution",
                        "devolution-finish",
                        prompt_kinds=["main"],
                        required_when=[
                            _condition(
                                "self.active.attached_tool_uid", "eq", "CSV5C_120"
                            )
                        ],
                        complete_when=[],
                        option_when=[
                            _condition("option.kind", "eq", "granted_attack"),
                            _condition("option.source_uid", "eq", "CSV5C_120"),
                            _condition("option.attack_index", "eq", 0),
                        ],
                        score_bonus=970000,
                        terminal=True,
                    ),
                ],
            }
        ],
    }


def _arven_complete_live_morgrem_transaction() -> dict[str, object]:
    """Bind Arven's item branch to the live Morgrem -> Grimmsnarl bridge."""
    return {
        "transaction_id": "arven-complete-live-morgrem",
        "priority": 7260,
        "goal_id": "backup-grimmsnarl",
        "deadline_turns": 0,
        "when": [
            _condition("prompt_kind", "eq", "main"),
            _condition("self.hand.count_uid", "gte", 1, "CSV1C_123"),
            _condition("self.hand.count_uid", "eq", 0, "CSV10C_148"),
            _condition("turn.supporter_available", "eq", True),
            _condition("window.option_count_card_uid", "gt", 0, "CSV1C_123"),
            _condition("self.bench.count_uid", "gte", 1, "CSV10C_147"),
            _condition("self.bench.count_uid", "gte", 1, "CSV7C_059"),
            _condition("self.board.count_uid", "eq", 0, "CSV10C_148"),
            _condition("opponent.prizes_remaining", "gt", 0),
        ],
        "continue_when": [
            _condition("self.bench.count_uid", "gte", 1, "CSV10C_147"),
            _condition("self.bench.count_uid", "gte", 1, "CSV7C_059"),
            _condition("self.board.count_uid", "eq", 0, "CSV10C_148"),
            _condition("opponent.prizes_remaining", "gt", 0),
        ],
        "success_when": [
            _condition("self.hand.count_uid", "gte", 1, "CSV1C_112"),
        ],
        "abort_when": [_condition("opponent.prizes_remaining", "eq", 0)],
        "methods": [
            {
                "method_id": "arven-item-branch-ultra-ball",
                "priority": 1000,
                "when": [],
                "steps": [
                    _step(
                        "play-arven-to-complete-live-morgrem",
                        "backup-grimmsnarl",
                        prompt_kinds=["main"],
                        required_when=[
                            _condition(
                                "self.hand.count_uid", "eq", 0, "CSV1C_112"
                            ),
                            _condition("turn.supporter_available", "eq", True),
                        ],
                        complete_when=[
                            _condition("turn.supporter_available", "eq", False)
                        ],
                        option_when=[
                            _condition("option.kind", "eq", "play_trainer"),
                            _condition("option.card_uid", "eq", "CSV1C_123"),
                        ],
                        score_bonus=1000000,
                        sequence_barrier=True,
                    ),
                    _step(
                        "search-ultra-ball-for-live-morgrem",
                        "backup-grimmsnarl",
                        prompt_kinds=["search"],
                        required_when=[
                            _condition("window.source_uid", "eq", "CSV1C_123"),
                            _condition(
                                "self.hand.count_uid", "eq", 0, "CSV1C_112"
                            ),
                        ],
                        complete_when=[
                            _condition(
                                "self.hand.count_uid", "gte", 1, "CSV1C_112"
                            )
                        ],
                        option_when=[
                            _condition("option.kind", "eq", "search"),
                            _condition("option.card_uid", "eq", "CSV1C_112"),
                            _condition("option.source_uid", "eq", "CSV1C_123"),
                        ],
                        score_bonus=990000,
                        terminal=True,
                    ),
                ],
            }
        ],
    }


def _counter_catcher_open_wall_transaction() -> dict[str, object]:
    """Open a zero-damage wall and retain authority through attack commit."""
    positive_damage = [_condition("damage.current_attack_damage", "gt", 0)]
    return {
        "transaction_id": "counter-catcher-open-wall-then-attack",
        "priority": 7270,
        "goal_id": "grimmsnarl-prize-route",
        "deadline_turns": 0,
        "when": [
            _condition("prompt_kind", "eq", "main"),
            _condition("self.active.count_uid", "gte", 1, "CSV10C_148"),
            _condition("damage.current_attack_damage", "eq", 0),
            _condition("damage.best_gust_prize_yield", "gte", 2),
            _condition("window.option_count_card_uid", "gt", 0, "CSV6C_114"),
            _condition("opponent.prizes_remaining", "gte", 2),
        ],
        "continue_when": [
            _condition("self.active.count_uid", "gte", 1, "CSV10C_148"),
            _condition("opponent.prizes_remaining", "gt", 0),
        ],
        "success_when": [],
        "abort_when": [_condition("opponent.prizes_remaining", "eq", 0)],
        "methods": [
            {
                "method_id": "open-two-prize-route-and-commit",
                "priority": 1000,
                "when": [],
                "steps": [
                    _step(
                        "play-one-counter-catcher-through-zero-damage-wall",
                        "grimmsnarl-prize-route",
                        prompt_kinds=["main"],
                        required_when=[
                            _condition("damage.current_attack_damage", "eq", 0),
                            _condition(
                                "window.option_count_card_uid",
                                "gt",
                                0,
                                "CSV6C_114",
                            ),
                        ],
                        complete_when=positive_damage,
                        option_when=[
                            _condition("option.kind", "eq", "play_trainer"),
                            _condition("option.card_uid", "eq", "CSV6C_114"),
                        ],
                        score_bonus=1000000,
                        sequence_barrier=True,
                    ),
                    _step(
                        "select-two-prize-target-behind-wall",
                        "grimmsnarl-prize-route",
                        prompt_kinds=["effect_target"],
                        required_when=[
                            _condition(
                                "window.option_count_source_uid",
                                "gt",
                                0,
                                "CSV6C_114",
                            )
                        ],
                        complete_when=positive_damage,
                        option_when=[
                            _condition("option.kind", "eq", "effect_target"),
                            _condition("option.source_uid", "eq", "CSV6C_114"),
                            _condition("option.target_prize_value", "gte", 2),
                        ],
                        score_bonus=980000,
                    ),
                    _step(
                        "commit-positive-grimmsnarl-attack-before-second-catcher",
                        "grimmsnarl-prize-route",
                        prompt_kinds=["main"],
                        required_when=positive_damage,
                        complete_when=[],
                        option_when=[
                            _condition("option.kind", "eq", "attack"),
                            _condition("option.source_uid", "eq", "CSV10C_148"),
                            _condition("option.projected_damage", "gt", 0),
                        ],
                        score_bonus=960000,
                        terminal=True,
                        sequence_barrier=True,
                    ),
                ],
            }
        ],
    }


def build_payloads() -> dict[str, bytes]:
    payloads = build_r54_payloads()
    manifest = json.loads(payloads["strategy_package.json"])
    adapter = json.loads(payloads["policy/adapter.json"])

    # These pre-R55 scalar rules attempted to preserve a future multi-window
    # line by independently scoring search and target options.  The transaction
    # journal now owns that chain and semantic selection groups own its exact
    # multi-select result, so retaining both would create conflicting owners
    # and consume the sealed device package budget.
    superseded_point_rule_prefixes = (
        "search.arven-tm-evolution-live",
        "search.arven-tm-evolution-two",
        "search.arven-tm-evolution-core",
        "search.arven-tm-evolution-snorunt",
        "search.arven-reject-ultra-ball-before",
        "tm-evolution-target.",
        "tm-evolution-attack-target.",
        "tm-target.",
        "attach.tm-evolution-active-snorunt",
        "attach.tm-evolution-active-impidimp",
        "main.counter-catcher-window",
        "pre-attack-development.counter-catcher-ogerpon-before-zero-damage-wall-attack",
        "handoff.ready-grimmsnarl",
        "handoff.late-ready-munkidori-engine",
        "main.attach-tm-before-zero-damage-with-funded-impidimp-and-snorunt",
        "main.attach-tm-before-zero-damage-with-funded-morgrem-and-snorunt",
        "main.tm-evolution-before-manual-froslass-two-targets",
        "main.attach-tm-to-ready-grimmsnarl-before-attack-two-snorunt",
        "main.tm-devolution-before-zero-damage-crustle-wall",
    )
    adapter["rules"] = [
        rule
        for rule in adapter["rules"]
        if not rule["rule_id"].startswith(superseded_point_rule_prefixes)
    ]

    manifest["package_version"] = "5.15.0"
    manifest["strategy"]["summary"] = (
        "R55 事务级决策架构：以公共目标、方法与步骤链完成支援者、进化、尖钉镇、"
        "庞克泵感、愿增猿转伤和攻击提交，并在每个新窗口重新绑定合法选项。"
    )
    required_capabilities = manifest["compatibility"]["required_capabilities"]
    if "turn_transaction_v1" not in required_capabilities:
        required_capabilities.append("turn_transaction_v1")

    adapter["adapter_version"] = 48
    adapter["goals"].append(
        {
            "goal_id": "core-engine-online",
            "stage": "maintain",
            "priority": 2000,
            "requirements": [
                {
                    "card_uid": "CSV7C_059",
                    "ready_target_count": 2,
                    "energy_required": 0,
                    "energy_requirements": [],
                    "attack_index": None,
                    "ability_index": 0,
                },
                {
                    "card_uid": "CSV10C_148",
                    "ready_target_count": 1,
                    "energy_required": 2,
                    "energy_requirements": [
                        {"energy_uid": "CSVE1C_DAR", "count": 2}
                    ],
                    "attack_index": 0,
                    "ability_index": None,
                },
            ],
        }
    )
    adapter.setdefault("turn_bonus_contracts", []).append(
        {
            "contract_id": "survival-reserve-before-commit",
            "priority": 9000,
            "goal_id": "core-engine-online",
            "when": [
                _condition("prompt_kind", "eq", "main"),
                _condition("self.bench_count", "eq", 0),
                _condition("self.active.count_uid", "gte", 1, "CSV8C_094"),
                _condition(
                    "window.option_count_source_uid", "eq", 0, "CSV8C_094"
                ),
                _condition("self.prizes_remaining", "gt", 0),
                _condition("opponent.prizes_remaining", "gt", 0),
            ],
            "bonuses": [
                {
                    "bonus_id": "reserve-shaymin-shield",
                    "prompt_kinds": ["main"],
                    "goal_id": "core-engine-online",
                    "when": [],
                    "option_when": [
                        _condition("option.kind", "eq", "play_basic_to_bench"),
                        _condition("option.card_uid", "eq", "CSV10C_007"),
                    ],
                    "score_bonus": 900000,
                },
            ],
        }
    )
    adapter["turn_bonus_contracts"].append(
        {
            "contract_id": "no-redundant-gust-before-current-two-prize-ko",
            "priority": 9500,
            "goal_id": "grimmsnarl-prize-route",
            "when": [
                _condition("prompt_kind", "eq", "main"),
                _condition("window.attack_option_count", "gt", 0),
                _condition("damage.best_prize_yield", "gte", 2),
                _condition("damage.best_attack_windows_to_ko", "eq", 1),
            ],
            "bonuses": [
                {
                    "bonus_id": "hold-redundant-counter-catcher",
                    "prompt_kinds": ["main"],
                    "goal_id": "grimmsnarl-prize-route",
                    "when": [],
                    "option_when": [
                        _condition("option.kind", "eq", "play_trainer"),
                        _condition("option.card_uid", "eq", "CSV6C_114"),
                    ],
                    "score_bonus": -1000000,
                },
                {
                    "bonus_id": "hold-redundant-boss",
                    "prompt_kinds": ["main"],
                    "goal_id": "grimmsnarl-prize-route",
                    "when": [],
                    "option_when": [
                        _condition("option.kind", "eq", "play_trainer"),
                        _condition("option.card_uid", "eq", "CSVH1aC_023"),
                    ],
                    "score_bonus": -1000000,
                },
            ],
        }
    )
    adapter["rules"].append(
        {
            "rule_id": "munkidori.source-preserve-low-hp-transfer-engine",
            "goal_id": "munkidori-transfer",
            "goal_stage": "maintain",
            "channel": "interaction",
            "horizon": 0,
            "confidence_milli": 1000,
            "base_score": 520000,
            "when": [
                _condition("prompt_kind", "eq", "effect_target"),
                _condition("window.source_uid", "eq", "CSV8C_094"),
                _condition("option.target_uid", "eq", "CSV8C_094"),
                _condition("option.target_remaining_hp", "lte", 30),
                _condition("self.board.count_uid", "gte", 1, "CSV7C_059"),
                _condition("turn_number", "gte", 3),
            ],
            "score_terms": [],
        }
    )
    adapter["rules"].extend(
        [
            {
                "rule_id": "search.poffin-reject-budew-after-core-ready",
                "goal_id": "core-engine-online",
                "goal_stage": "maintain",
                "channel": "uncertainty",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": -800000,
                "when": [
                    _condition("prompt_kind", "eq", "search"),
                    _condition("window.source_uid", "eq", "CSV7C_177"),
                    _condition("option.card_uid", "eq", "CSV9.5C_004"),
                    _condition("self.board.count_uid", "gte", 2, "CSV9.5C_043"),
                    _condition("self.board.count_uid", "gte", 1, "CSV10C_146"),
                ],
                "score_terms": [],
            },
        ]
    )
    adapter["rules"].extend(
        [
            {
                "rule_id": f"search.arven-tm-safe-postcondition.{name}",
                "goal_id": "core-engine-online",
                "goal_stage": "deploy",
                "channel": "interaction",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 1000000,
                "when": [
                    _condition("prompt_kind", "eq", "search"),
                    _condition("window.source_uid", "eq", "CSV1C_123"),
                    _condition("option.card_uid", "eq", "CSV5C_119"),
                    _condition("self.board.count_uid", "lt", 2, "CSV7C_059"),
                    _condition("self.prizes_remaining", "gt", 1),
                    *conditions,
                ],
                "score_terms": [],
            }
            for name, conditions, _groups in _tm_safe_combinations()
            if name != "snorunt-impidimp"
        ]
    )
    adapter["rules"].extend(
        [
            {
                "rule_id": "search.arven-ultra-ball-complete-live-morgrem-froslass",
                "goal_id": "backup-grimmsnarl",
                "goal_stage": "deploy",
                "channel": "interaction",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 900000,
                "when": [
                    _condition("prompt_kind", "eq", "search"),
                    _condition("window.source_uid", "eq", "CSV1C_123"),
                    _condition("option.card_uid", "eq", "CSV1C_112"),
                    _condition("self.hand.count_uid", "eq", 0, "CSV10C_148"),
                    _condition("self.bench.count_uid", "gte", 1, "CSV10C_147"),
                    _condition("self.bench.count_uid", "gte", 1, "CSV7C_059"),
                    _condition("self.board.count_uid", "eq", 0, "CSV10C_148"),
                ],
                "score_terms": [],
            },
            {
                "rule_id": "tm-evolution.reject-unproven-attach",
                "goal_id": "core-engine-online",
                "goal_stage": "maintain",
                "channel": "interaction",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": -100000,
                "when": [
                    _condition("option.kind", "eq", "attach_tool"),
                    _condition("option.card_uid", "eq", "CSV5C_119"),
                ],
                "score_terms": [],
            },
            {
                "rule_id": "tm-evolution.reject-unproven-granted-attack",
                "goal_id": "core-engine-online",
                "goal_stage": "maintain",
                "channel": "interaction",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": -100000,
                "when": [
                    _condition("option.kind", "eq", "granted_attack"),
                    _condition("option.source_uid", "eq", "CSV5C_119"),
                ],
                "score_terms": [],
            },
            {
                "rule_id": "search.arven-rescue-board-for-low-hp-munkidori",
                "goal_id": "munkidori-transfer",
                "goal_stage": "maintain",
                "channel": "interaction",
                "horizon": 0,
                "confidence_milli": 1000,
                "base_score": 700000,
                "when": [
                    _condition("prompt_kind", "eq", "search"),
                    _condition("window.source_uid", "eq", "CSV1C_123"),
                    _condition("option.card_uid", "eq", "CSV7C_185"),
                    _condition("self.active.count_uid", "gte", 1, "CSV8C_094"),
                    _condition("self.active.remaining_hp", "lte", 50),
                    _condition("self.bench.count_uid", "gte", 1, "CSV7C_059"),
                ],
                "score_terms": [],
            },
        ]
    )
    budew_transaction = _pre_attack_transaction(
        "budew-safe-attack-commit", "CSV9.5C_004", 5800
    )
    budew_transaction["when"].append(_condition("turn_number", "lte", 2))
    tm_attach_steps = [
        _main_step(
            "attach-tm-only-after-two-target-proof",
            "core-engine-online",
            [],
            [
                _condition("option.kind", "eq", "attach_tool"),
                _condition("option.card_uid", "eq", "CSV5C_119"),
                _condition("option.target_is_active", "eq", True),
                _condition("option.target_attached_energy_count", "gte", 1),
            ],
            980000,
        )
    ]
    tm_grant_steps = [
        _main_step(
            "grant-tm-only-after-reobserved-two-target-proof",
            "core-engine-online",
            [],
            [
                _condition("option.kind", "eq", "granted_attack"),
                _condition("option.source_uid", "eq", "CSV5C_119"),
                _condition("option.attack_index", "eq", 0),
            ],
            960000,
        )
    ]
    tm_grant_steps[0]["terminal"] = True
    tm_target_steps = [
        _step(
            "select-exactly-two-reproved-safe-evolution-targets",
            "core-engine-online",
            prompt_kinds=["attack_target", "effect_target"],
            required_when=[
                _condition("select.max_count", "eq", 2),
            ],
            complete_when=[],
            option_when=[_condition("option.kind", "ne", "search")],
            score_bonus=940000,
            selection_count=2,
        ),
        _step(
            "select-one-evolution-card-for-each-proved-target",
            "core-engine-online",
            prompt_kinds=["search"],
            required_when=[
                _condition("select.max_count", "eq", 2),
            ],
            complete_when=[],
            option_when=[
                _condition("option.kind", "eq", "search"),
            ],
            score_bonus=930000,
            selection_count=2,
            terminal=True,
        )
    ]
    munkidori_preserve_steps = [
        _main_step(
            "move-damage-before-low-hp-retreat",
            "munkidori-transfer",
            [_condition("damage.best_transfer_count", "gt", 0)],
            [
                _condition("option.kind", "eq", "use_ability"),
                _condition("option.source_uid", "eq", "CSV8C_094"),
            ],
            990000,
        ),
        _main_step(
            "attach-rescue-board-to-low-hp-active-munkidori",
            "munkidori-transfer",
            [
                _condition(
                    "window.option_count_card_uid", "gt", 0, "CSV7C_185"
                )
            ],
            [
                _condition("option.kind", "eq", "attach_tool"),
                _condition("option.card_uid", "eq", "CSV7C_185"),
                _condition("option.target_uid", "eq", "CSV8C_094"),
                _condition("option.target_is_active", "eq", True),
            ],
            970000,
        ),
        _main_step(
            "retreat-low-hp-munkidori-into-froslass",
            "munkidori-transfer",
            [_condition("turn.retreat_available", "eq", True)],
            [
                _condition("option.kind", "eq", "retreat"),
                _condition("option.target_uid", "eq", "CSV7C_059"),
            ],
            950000,
        ),
    ]
    adapter["turn_transactions"] = [
        _search_owned_tm_evolution_transaction(),
        _search_owned_tm_devolution_transaction(),
        _counter_catcher_open_wall_transaction(),
        _arven_complete_live_morgrem_transaction(),
        {
            "transaction_id": "poffin-core-ready-no-budew-overfill",
            "priority": 7100,
            "goal_id": "core-engine-online",
            "deadline_turns": 0,
            "when": [
                _condition("prompt_kind", "eq", "search"),
                _condition("window.source_uid", "eq", "CSV7C_177"),
                _condition("self.board.count_uid", "gte", 2, "CSV9.5C_043"),
                _condition("self.board.count_uid", "gte", 1, "CSV10C_146"),
            ],
            "success_when": [],
            "abort_when": [],
            "methods": [
                {
                    "method_id": "take-one-impidimp-without-budew",
                    "priority": 1000,
                    "when": [],
                    "steps": [
                        _step(
                            "select-one-safe-backup-impidimp",
                            "backup-grimmsnarl",
                            prompt_kinds=["search"],
                            required_when=[],
                            complete_when=[],
                            option_when=[
                                _condition(
                                    "option.card_uid", "eq", "CSV10C_146"
                                )
                            ],
                            score_bonus=990000,
                            selection_count=1,
                            terminal=True,
                        )
                    ],
                }
            ],
        },
        {
            "transaction_id": "spikemuth-prove-before-use",
            "priority": 7190,
            "goal_id": "backup-grimmsnarl",
            "deadline_turns": 0,
            "when": [
                _condition("prompt_kind", "eq", "main"),
                _condition(
                    "window.option_count_source_uid", "gt", 0, "CSV10C_216"
                ),
                _condition("self.bench.count_uid", "gte", 1, "CSV10C_147"),
                _condition("self.bench.count_uid", "eq", 0, "CSV10C_148"),
                _condition("goal.ready_count", "eq", 0),
            ],
            "success_when": [],
            "abort_when": [_condition("opponent.prizes_remaining", "eq", 0)],
            "methods": [
                {
                    "method_id": "complete-bench-morgrem-before-turn-commit",
                    "priority": 1000,
                    "when": [],
                    "steps": [
                        _step(
                            "use-spikemuth-for-bench-morgrem",
                            "backup-grimmsnarl",
                            prompt_kinds=["main"],
                            required_when=[],
                            complete_when=[],
                            option_when=[
                                _condition("option.kind", "eq", "use_stadium_effect"),
                                _condition("option.source_uid", "eq", "CSV10C_216"),
                            ],
                            score_bonus=995000,
                            terminal=True,
                        )
                    ],
                }
            ],
        },
        {
            "transaction_id": "spikemuth-reprove-before-search",
            "priority": 7180,
            "goal_id": "backup-grimmsnarl",
            "deadline_turns": 0,
            "when": [
                _condition("prompt_kind", "eq", "search"),
                _condition("window.source_uid", "eq", "CSV10C_216"),
                _condition(
                    "window.option_count_card_uid", "gt", 0, "CSV10C_148"
                ),
                _condition("self.bench.count_uid", "gte", 1, "CSV10C_147"),
                _condition("self.bench.count_uid", "eq", 0, "CSV10C_148"),
            ],
            "success_when": [],
            "abort_when": [_condition("opponent.prizes_remaining", "eq", 0)],
            "methods": [
                {
                    "method_id": "search-grimmsnarl-for-bench-morgrem",
                    "priority": 1000,
                    "when": [],
                    "steps": [
                        _step(
                            "search-grimmsnarl-after-spikemuth-proof",
                            "backup-grimmsnarl",
                            prompt_kinds=["search"],
                            required_when=[],
                            complete_when=[],
                            option_when=[
                                _condition("option.card_uid", "eq", "CSV10C_148"),
                                _condition("option.source_uid", "eq", "CSV10C_216"),
                            ],
                            score_bonus=995000,
                            terminal=True,
                        )
                    ],
                }
            ],
        },
        {
            "transaction_id": "spikemuth-reprove-before-evolve",
            "priority": 7170,
            "goal_id": "backup-grimmsnarl",
            "deadline_turns": 0,
            "when": [
                _condition("prompt_kind", "eq", "main"),
                _condition(
                    "window.option_count_card_uid", "gt", 0, "CSV10C_148"
                ),
                _condition("self.bench.count_uid", "gte", 1, "CSV10C_147"),
                _condition("self.bench.count_uid", "eq", 0, "CSV10C_148"),
                _condition("goal.ready_count", "eq", 0),
            ],
            "success_when": [],
            "abort_when": [_condition("opponent.prizes_remaining", "eq", 0)],
            "methods": [
                {
                    "method_id": "evolve-bench-morgrem-before-turn-commit",
                    "priority": 1000,
                    "when": [],
                    "steps": [
                        _step(
                            "evolve-bench-morgrem-after-search-proof",
                            "backup-grimmsnarl",
                            prompt_kinds=["main"],
                            required_when=[],
                            complete_when=[],
                            option_when=[
                                _condition("option.kind", "eq", "evolve"),
                                _condition("option.card_uid", "eq", "CSV10C_148"),
                                _condition("option.target_uid", "eq", "CSV10C_147"),
                            ],
                            score_bonus=995000,
                            terminal=True,
                        )
                    ],
                }
            ],
        },
        {
            "transaction_id": "tm-evolution-prove-before-attach",
            "priority": 7150,
            "goal_id": "core-engine-online",
            "deadline_turns": 0,
            "when": [
                _condition("prompt_kind", "eq", "main"),
                _condition("turn_number", "gte", 2),
                _condition(
                    "window.option_count_card_uid", "gt", 0, "CSV5C_119"
                ),
            ],
            "success_when": [],
            "abort_when": [_condition("opponent.prizes_remaining", "eq", 0)],
            "methods": _tm_safe_methods("attach", tm_attach_steps),
        },
        {
            "transaction_id": "tm-evolution-reprove-before-grant",
            "priority": 7140,
            "goal_id": "core-engine-online",
            "deadline_turns": 0,
            "when": [
                _condition("prompt_kind", "eq", "main"),
                _condition("turn_number", "gte", 2),
                _condition(
                    "window.option_count_source_uid", "gt", 0, "CSV5C_119"
                ),
            ],
            "success_when": [],
            "abort_when": [_condition("opponent.prizes_remaining", "eq", 0)],
            "methods": _tm_safe_methods("grant", tm_grant_steps),
        },
        {
            "transaction_id": "tm-evolution-reprove-before-target-selection",
            "priority": 7130,
            "goal_id": "core-engine-online",
            "deadline_turns": 0,
            "when": [
                _condition("prompt_kind", "ne", "search"),
                _condition("select.max_count", "eq", 2),
                _condition(
                    "self.active.attached_tool_uid", "eq", "CSV5C_119"
                ),
            ],
            "continue_when": [
                _condition(
                    "self.active.attached_tool_uid", "eq", "CSV5C_119"
                ),
                _condition("opponent.prizes_remaining", "gt", 0),
            ],
            "success_when": [],
            "abort_when": [_condition("opponent.prizes_remaining", "eq", 0)],
            "methods": _tm_safe_methods(
                "target_and_evolution", tm_target_steps
            ),
        },
        {
            "transaction_id": "munkidori-low-hp-transfer-then-retreat",
            "priority": 7200,
            "goal_id": "munkidori-transfer",
            "deadline_turns": 0,
            "when": [
                _condition("prompt_kind", "eq", "main"),
                _condition("self.active.count_uid", "gte", 1, "CSV8C_094"),
                _condition("self.active.remaining_hp", "lte", 50),
                _condition("self.bench.count_uid", "gte", 1, "CSV7C_059"),
                _condition("turn_number", "gte", 3),
            ],
            "success_when": [],
            "abort_when": [_condition("opponent.prizes_remaining", "eq", 0)],
            "methods": [
                {
                    "method_id": "transfer-attach-board-retreat",
                    "priority": 1000,
                    "when": [
                        _condition(
                            "window.option_count_card_uid",
                            "gt",
                            0,
                            "CSV7C_185",
                        )
                    ],
                    "steps": munkidori_preserve_steps,
                },
                {
                    "method_id": "retreat-after-board-postcondition",
                    "priority": 990,
                    "when": [
                        _condition(
                            "self.active.attached_tool_uid",
                            "eq",
                            "CSV7C_185",
                        )
                    ],
                    "steps": munkidori_preserve_steps,
                },
            ],
        },
        {
            "transaction_id": "single-board-continuity-before-commit",
            "priority": 6200,
            "goal_id": "core-engine-online",
            "deadline_turns": 0,
            "when": [
                _condition("prompt_kind", "eq", "main"),
                _condition("self.bench_count", "eq", 0),
                _condition("self.active.count_uid", "eq", 0, "CSV8C_094"),
                _condition("self.prizes_remaining", "gt", 0),
                _condition("opponent.prizes_remaining", "gt", 0),
                _condition("turn_number", "gte", 1),
            ],
            "success_when": [],
            "abort_when": [_condition("opponent.prizes_remaining", "eq", 0)],
            "methods": [
                {
                    "method_id": "develop-reserve-before-turn-commit",
                    "priority": 1000,
                    "when": [],
                    "steps": _core_steps(include_tm_finish=False),
                }
            ],
        },
        _pre_attack_transaction(
            "grimmsnarl-safe-attack-commit", "CSV10C_148", 6000
        ),
        _pre_attack_transaction("munkidori-safe-attack-commit", "CSV8C_094", 5900),
        budew_transaction,
        {
            "transaction_id": "late-send-out-transfer-engine",
            "priority": 6500,
            "goal_id": "munkidori-transfer",
            "deadline_turns": 0,
            "when": [
                _condition("prompt_kind", "eq", "send_out"),
                _condition("turn_number", "gte", 3),
            ],
            "success_when": [],
            "abort_when": [],
            "methods": [
                {
                    "method_id": "munkidori-before-liability",
                    "priority": 1000,
                    "when": [],
                    "steps": [
                        _step(
                            "send-out-early-budew-item-lock-protect-sole-grimmsnarl",
                            "grimmsnarl-prize-route",
                            prompt_kinds=["send_out"],
                            required_when=[
                                _condition("turn_number", "lte", 4),
                                _condition(
                                    "self.board.count_uid", "eq", 1, "CSV10C_148"
                                ),
                                _condition(
                                    "self.board.count_uid", "gte", 2, "CSV7C_059"
                                ),
                                _condition(
                                    "self.board.count_uid", "gte", 1, "CSV9.5C_004"
                                ),
                                _condition(
                                    "self.board.energy_bearing_count_uid",
                                    "eq",
                                    0,
                                    "CSV8C_094",
                                ),
                                _condition("opponent.active.prize_value", "eq", 2),
                            ],
                            complete_when=[],
                            option_when=[
                                _condition("option.target_uid", "eq", "CSV9.5C_004"),
                                _condition("option.target_attack_ready", "eq", True),
                            ],
                            score_bonus=990000,
                            terminal=False,
                        ),
                        _step(
                            "send-out-munkidori-transfer-engine",
                            "munkidori-transfer",
                            prompt_kinds=["send_out"],
                            required_when=[
                                _condition(
                                    "self.board.count_uid", "gte", 1, "CSV8C_094"
                                ),
                                _condition(
                                    "self.board.count_uid", "gte", 1, "CSV7C_059"
                                ),
                            ],
                            complete_when=[],
                            option_when=[
                                _condition("option.target_uid", "eq", "CSV8C_094"),
                            ],
                            score_bonus=980000,
                            terminal=False,
                        ),
                        _step(
                            "send-out-ready-grimmsnarl",
                            "grimmsnarl-prize-route",
                            prompt_kinds=["send_out"],
                            required_when=[
                                _condition(
                                    "self.board.count_uid", "gte", 1, "CSV10C_148"
                                )
                            ],
                            complete_when=[],
                            option_when=[
                                _condition("option.target_uid", "eq", "CSV10C_148"),
                                _condition("option.target_attack_ready", "eq", True),
                            ],
                            score_bonus=960000,
                            terminal=False,
                        ),
                        _step(
                            "send-out-spare-impidimp-preserve-core-bridge",
                            "backup-grimmsnarl",
                            prompt_kinds=["send_out"],
                            required_when=[
                                _condition(
                                    "self.board.count_uid", "gte", 1, "CSV10C_147"
                                ),
                                _condition(
                                    "self.board.count_uid", "gte", 1, "CSV7C_059"
                                ),
                                _condition(
                                    "self.board.count_uid", "gte", 1, "CSV10C_146"
                                ),
                                _condition("goal.ready_count", "eq", 0),
                            ],
                            complete_when=[],
                            option_when=[
                                _condition("option.target_uid", "eq", "CSV10C_146"),
                            ],
                            score_bonus=940000,
                            terminal=False,
                        ),
                    ],
                }
            ],
        },
    ]

    payloads["strategy_package.json"] = canonical_json_v1_bytes(manifest)
    payloads["policy/adapter.json"] = canonical_json_v1_bytes(adapter)
    readme = payloads["README.md"].decode("utf-8").rstrip()
    payloads["README.md"] = (
        readme
        + "\n\n## R55 transaction architecture\n\n"
        + "A public-only HTN transaction journal now retains semantic transaction and method identity only. "
        + "Every select window recomputes incomplete safe steps and rebinds current legal indexes. "
        + "Attack commitment is delayed only when an exact safe step is executable in that same window; Base Graph terminal, mandatory, hard-tier, veto, cardinality, and fallback remain final.\n"
    ).encode("utf-8")
    return payloads


def build_bytes() -> bytes:
    return build_package_bytes(
        build_payloads(), TEST_FIXTURE_PRIVATE_KEY, key_id=TEST_FIXTURE_KEY_ID
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--write", action="store_true")
    action.add_argument("--check", action="store_true")
    args = parser.parse_args()
    archive = build_bytes()
    handle = AuthorStrategyPackageLoader().load_bytes(archive)
    if args.write:
        OUTPUT.write_bytes(archive)
    elif not OUTPUT.is_file() or OUTPUT.read_bytes() != archive:
        raise SystemExit("Marnie R55 package drift")
    adapter = json.loads(handle.payload_bytes("policy/adapter.json"))
    print(f"archive_bytes={len(archive)}")
    print(f"archive_sha256={_sha(archive)}")
    print(f"package_version={handle.package_version}")
    print(f"adapter_version={adapter['adapter_version']}")
    print(f"turn_transaction_count={len(adapter['turn_transactions'])}")
    print("execution_trusted=false")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
