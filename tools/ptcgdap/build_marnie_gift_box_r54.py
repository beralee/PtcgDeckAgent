from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
from zipfile import ZipFile


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.author_strategy_package import (  # noqa: E402
    AuthorStrategyPackageLoader,
)
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes  # noqa: E402
from tools.ptcgdap.build_author_strategy_package import (  # noqa: E402
    GENERATED_PATHS,
    TEST_FIXTURE_KEY_ID,
    build_package_bytes,
)


BASE = (
    ROOT
    / "data/ptcgdap/author_strategy_packages"
    / "marnies-gift-box-rule-marnie-r53-5.13.0.ptcgai"
)
OUTPUT = (
    ROOT
    / "data/ptcgdap/author_strategy_packages"
    / "marnies-gift-box-rule-marnie-r54-5.14.0.ptcgai"
)
BASE_SHA256 = "E7539DB5639B236365A801476F685C22BD45B10F3E9C09A46960EBC60063EBED"
TEST_FIXTURE_PRIVATE_KEY = bytes(range(32))


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _condition(fact: str, op: str, value: object, card_uid: str | None = None) -> dict[str, object]:
    return {"fact": fact, "op": op, "value": value, "card_uid": card_uid}


def _rule(
    rule_id: str,
    goal_id: str,
    stage: str,
    channel: str,
    score: int,
    when: list[dict[str, object]],
) -> dict[str, object]:
    return {
        "rule_id": rule_id,
        "goal_id": goal_id,
        "goal_stage": stage,
        "channel": channel,
        "horizon": 0,
        "confidence_milli": 1000,
        "base_score": score,
        "when": when,
        "score_terms": [],
    }


def _fixed_count(
    rule_id: str,
    priority: int,
    goal_id: str,
    fixed_count: int,
    when: list[dict[str, object]],
) -> dict[str, object]:
    return {
        "rule_id": rule_id,
        "priority": priority,
        "goal_id": goal_id,
        "mode": "fixed",
        "fixed_count": fixed_count,
        "fact": None,
        "divisor": None,
        "when": when,
    }


def _base_payloads() -> dict[str, bytes]:
    raw = BASE.read_bytes()
    if _sha(raw) != BASE_SHA256:
        raise ValueError("marnie_r53_base_hash_mismatch")
    with ZipFile(BASE, "r") as archive:
        return {
            name: archive.read(name)
            for name in archive.namelist()
            if name not in GENERATED_PATHS
        }


def _set_turn_threshold(
    rules: list[dict[str, object]], rule_ids: set[str], value: int
) -> None:
    found: set[str] = set()
    for rule in rules:
        rule_id = str(rule.get("rule_id", ""))
        if rule_id not in rule_ids:
            continue
        found.add(rule_id)
        for condition in rule.get("when", []):
            if condition.get("fact") == "turn_number":
                condition["value"] = value
    missing = rule_ids - found
    if missing:
        raise ValueError(f"marnie_r53_rule_missing:{','.join(sorted(missing))}")


def _lock_punk_up_to_exact_marnie_targets(rules: list[dict[str, object]]) -> None:
    target_specs = {
        "punk-up.target-any-marnie-below-two": "CSV10C_148",
        "punk-up.fund-impidimp-backup-line": "CSV10C_146",
        "punk-up.fund-morgrem-backup-line": "CSV10C_147",
    }
    found: set[str] = set()
    for rule in rules:
        rule_id = str(rule.get("rule_id", ""))
        target_uid = target_specs.get(rule_id)
        if target_uid is None:
            continue
        found.add(rule_id)
        rule["base_score"] = 160000
        conditions: list[dict[str, object]] = rule.get("when", [])
        if not any(
            condition.get("fact") == "option.target_uid"
            for condition in conditions
        ):
            conditions.append(_condition("option.target_uid", "eq", target_uid))
        if not any(
            condition.get("fact") == "option.target_attached_energy_count"
            for condition in conditions
        ):
            conditions.append(
                _condition("option.target_attached_energy_count", "lt", 2)
            )
    missing = set(target_specs) - found
    if missing:
        raise ValueError(
            f"marnie_r53_punk_up_rule_missing:{','.join(sorted(missing))}"
        )


def build_payloads() -> dict[str, bytes]:
    payloads = _base_payloads()
    manifest = json.loads(payloads["strategy_package.json"])
    adapter = json.loads(payloads["policy/adapter.json"])

    manifest["package_version"] = "5.14.0"
    manifest["strategy"]["summary"] = (
        "波导的勇者为宁波第五名构筑研发的雪妖女、愿增猿与玛俐的长毛巨魔 ex 公共伤害规划策略；"
        "R54 锁定进化碟双目标、第二自有回合后的含羞苞止损、玛俐轴精确二能与攻击前展开顺序。"
    )
    adapter["adapter_version"] = 39
    rules: list[dict[str, object]] = adapter["rules"]
    count_rules: list[dict[str, object]] = adapter["count_rules"]

    _lock_punk_up_to_exact_marnie_targets(rules)

    _set_turn_threshold(
        rules,
        {
            "search.poffin-reject-late-budew",
            "handoff.late-ready-munkidori-engine",
            "munkidori.adrena-brain",
        },
        3,
    )
    _set_turn_threshold(rules, {"handoff.reject-late-budew-liability"}, 5)
    _set_turn_threshold(rules, {"handoff.zero-retreat-budew-pivot"}, 4)
    _set_turn_threshold(
        count_rules,
        {
            "poffin.skip-late-budew-only-whiff",
            "poffin.late-one-snorunt-without-impidimp",
            "poffin.late-one-impidimp-without-snorunt",
        },
        3,
    )

    new_rules = [
        _rule(
            "main.preserve-tm-evolution-on-first-player-turn",
            "double-froslass-engine",
            "deploy",
            "uncertainty",
            -500000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "attach_tool"),
                _condition("option.card_uid", "eq", "CSV5C_119"),
                _condition("turn_number", "eq", 1),
            ],
        ),
        _rule(
            "pre-attack-development.bench-munkidori-with-live-froslass",
            "munkidori-transfer",
            "deploy",
            "macro",
            150000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_basic_to_bench"),
                _condition("option.card_uid", "eq", "CSV8C_094"),
                _condition("self.board.count_uid", "gte", 1, "CSV7C_059"),
                _condition("self.board.count_uid", "eq", 0, "CSV8C_094"),
                _condition("self.hand.count_uid", "eq", 0, "CSV1C_117"),
                _condition("turn.supporter_available", "eq", False),
                _condition("turn_number", "gte", 5),
            ],
        ),
        _rule(
            "attach.active-budew-before-arven-tm-chain",
            "double-froslass-engine",
            "fund",
            "macro",
            180000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "attach_energy"),
                _condition("option.card_uid", "eq", "CSVE1C_DAR"),
                _condition("option.target_is_active", "eq", True),
                _condition("option.target_uid", "eq", "CSV9.5C_004"),
                _condition("option.target_attached_energy_count", "eq", 0),
                _condition("self.hand.count_uid", "gte", 1, "CSV1C_123"),
                _condition("self.board.count_uid", "gte", 1, "CSV10C_146"),
                _condition("goal.deployed_count", "lt", 2),
                _condition("turn_number", "lte", 2),
            ],
        ),
        _rule(
            "pre-attack-development.evolve-second-froslass",
            "double-froslass-engine",
            "deploy",
            "macro",
            180000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "evolve"),
                _condition("option.card_uid", "eq", "CSV7C_059"),
                _condition("option.target_uid", "eq", "CSV9.5C_043"),
                _condition("self.board.count_uid", "gte", 1, "CSV7C_059"),
                _condition("self.board.count_uid", "lt", 2, "CSV7C_059"),
                _condition("turn_number", "lte", 10),
            ],
        ),
        _rule(
            "pre-attack-development.arven-low-hand-far-behind",
            "double-froslass-engine",
            "acquire",
            "macro",
            160000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSV1C_123"),
                _condition("self.hand_count", "lte", 2),
                _condition("self.prizes_remaining", "gte", 4),
                _condition("opponent.prizes_remaining", "lte", 2),
                _condition("opponent.hand_count", "gte", 8),
                _condition("turn_number", "gte", 5),
            ],
        ),
        _rule(
            "pre-tm-development.evolve-first-froslass-before-granted-attack",
            "double-froslass-engine",
            "deploy",
            "macro",
            600000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "evolve"),
                _condition("option.card_uid", "eq", "CSV7C_059"),
                _condition("option.target_uid", "eq", "CSV9.5C_043"),
                _condition("self.board.count_uid", "eq", 0, "CSV7C_059"),
                _condition("window.option_count_source_uid", "gte", 1, "CSV5C_119"),
                _condition("opponent.prizes_remaining", "gte", 2),
            ],
        ),
        _rule(
            "pre-attack-development.iono-even-two-prize-disruption-over-arven",
            "grimmsnarl-prize-route",
            "recover",
            "macro",
            260000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSV3C_123"),
                _condition("self.active.count_uid", "gte", 1, "CSV10C_146"),
                _condition("self.active.energy_count_uid", "gte", 2, "CSVE1C_DAR"),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_148"),
                _condition("self.board.count_uid", "eq", 0, "CSV7C_059"),
                _condition("self.hand_count", "lte", 3),
                _condition("self.deck_count", "gte", 10),
                _condition("self.prizes_remaining", "lte", 2),
                _condition("opponent.hand_count", "gte", 4),
                _condition("opponent.prizes_remaining", "lte", 2),
                _condition("turn.supporter_available", "eq", True),
                _condition("turn_number", "gte", 10),
            ],
        ),
        _rule(
            "pre-attack-development.research-before-nonterminal-shadow-bullet-double-munkidori",
            "munkidori-transfer",
            "acquire",
            "macro",
            280000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSV1C_121"),
                _condition("self.active.count_uid", "gte", 1, "CSV10C_148"),
                _condition("self.board.count_uid", "gte", 2, "CSV8C_094"),
                _condition("self.board.count_uid", "eq", 0, "CSV7C_059"),
                _condition("self.hand_count", "lte", 3),
                _condition("self.deck_count", "gte", 10),
                _condition("self.prizes_remaining", "gte", 3),
                _condition("opponent.prizes_remaining", "gte", 2),
                _condition("opponent.active.remaining_hp", "gte", 190),
                _condition("damage.current_attack_damage", "gte", 1),
                _condition("turn.supporter_available", "eq", True),
                _condition("turn_number", "gte", 9),
            ],
        ),
        _rule(
            "pre-end-development.iono-before-pass-unfunded-active-munkidori-ready-grimmsnarl",
            "munkidori-transfer",
            "recover",
            "macro",
            360000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSV3C_123"),
                _condition("self.active.count_uid", "gte", 1, "CSV8C_094"),
                _condition("self.active.energy_count_uid", "eq", 0, "CSVE1C_DAR"),
                _condition("self.board.count_uid", "gte", 1, "CSV10C_148"),
                _condition("self.board.energy_count_uid", "gte", 2, "CSVE1C_DAR"),
                _condition("self.hand_count", "lte", 3),
                _condition("self.deck_count", "gte", 10),
                _condition("self.prizes_remaining", "gte", 3),
                _condition("opponent.prizes_remaining", "gte", 2),
                _condition("damage.current_attack_damage", "eq", 0),
                _condition("turn.retreat_available", "eq", False),
                _condition("turn.supporter_available", "eq", True),
                _condition("turn_number", "gte", 9),
            ],
        ),
        _rule(
            "pre-attack-development.iono-before-zero-damage-shadow-bullet-core-incomplete",
            "double-froslass-engine",
            "acquire",
            "macro",
            250000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSV3C_123"),
                _condition("self.active.count_uid", "gte", 1, "CSV10C_148"),
                _condition("self.board.count_uid", "eq", 0, "CSV7C_059"),
                _condition("self.hand_count", "lte", 6),
                _condition("opponent.hand_count", "gte", 5),
                _condition("opponent.prizes_remaining", "gte", 2),
                _condition("damage.current_attack_damage", "eq", 0),
                _condition("turn.supporter_available", "eq", True),
                _condition("turn_number", "gte", 5),
            ],
        ),
        _rule(
            "pre-attack-development.energy-search-first-munkidori-before-shadow-bullet",
            "munkidori-transfer",
            "fund",
            "macro",
            240000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSVH1C_035"),
                _condition("self.active.count_uid", "gte", 1, "CSV10C_148"),
                _condition("self.active.remaining_hp", "lte", 110),
                _condition("self.board.count_uid", "gte", 1, "CSV8C_094"),
                _condition("self.hand.count_uid", "eq", 0, "CSVE1C_DAR"),
                _condition("turn.manual_attachment_available", "eq", True),
                _condition("opponent.prizes_remaining", "gte", 2),
                _condition("turn_number", "gte", 4),
            ],
        ),
        _rule(
            "pre-attack-development.boss-ogerpon-before-zero-damage-wall-attack",
            "grimmsnarl-prize-route",
            "execute",
            "tactical",
            320000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSVH1aC_023"),
                _condition("self.active.count_uid", "gte", 1, "CSV10C_148"),
                _condition("self.active.energy_count_uid", "gte", 2, "CSVE1C_DAR"),
                _condition("damage.current_attack_damage", "eq", 0),
                _condition("damage.best_prize_yield", "eq", 2),
                _condition("opponent.prizes_remaining", "gte", 2),
                _condition("turn.supporter_available", "eq", True),
            ],
        ),
        _rule(
            "pre-attack-development.counter-catcher-ogerpon-before-zero-damage-wall-attack",
            "grimmsnarl-prize-route",
            "execute",
            "tactical",
            320000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSV6C_114"),
                _condition("self.active.count_uid", "gte", 1, "CSV10C_148"),
                _condition("self.active.energy_count_uid", "gte", 2, "CSVE1C_DAR"),
                _condition("damage.current_attack_damage", "eq", 0),
                _condition("damage.best_prize_yield", "eq", 2),
                _condition("opponent.prizes_remaining", "gte", 2),
            ],
        ),
        _rule(
            "pre-attack-development.play-energy-search-for-second-munkidori",
            "munkidori-transfer",
            "fund",
            "macro",
            200000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSVH1C_035"),
                _condition("self.board.count_uid", "gte", 2, "CSV8C_094"),
                _condition(
                    "self.board.energy_bearing_count_uid", "lt", 2, "CSV8C_094"
                ),
                _condition("self.hand.count_uid", "eq", 0, "CSVE1C_DAR"),
                _condition("self.board.energy_count_uid", "lt", 6, "CSVE1C_DAR"),
                _condition("turn.manual_attachment_available", "eq", True),
                _condition("turn_number", "gte", 5),
            ],
        ),
        _rule(
            "main.arven-before-optional-munkidori-funding",
            "double-froslass-engine",
            "acquire",
            "macro",
            170000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSV1C_123"),
                _condition("self.active.count_uid", "gte", 1, "CSV9.5C_004"),
                _condition("self.board.count_uid", "gte", 1, "CSV10C_146"),
                _condition("self.board.count_uid", "gte", 1, "CSV9.5C_043"),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_148"),
                _condition("self.board.count_uid", "eq", 0, "CSV7C_059"),
                _condition("turn.manual_attachment_available", "eq", True),
                _condition("turn_number", "gte", 3),
            ],
        ),
        _rule(
            "search.arven-empty-core-tm-evolution-transaction",
            "backup-grimmsnarl",
            "acquire",
            "interaction",
            220000,
            [
                _condition("prompt_kind", "eq", "search"),
                _condition("window.source_uid", "eq", "CSV1C_123"),
                _condition("option.card_uid", "eq", "CSV5C_119"),
                _condition("turn_number", "lte", 2),
                _condition("self.active.count_uid", "gte", 1, "CSV10C_007"),
                _condition("goal.deployed_count", "lt", 2),
            ],
        ),
        _rule(
            "search.arven-tm-evolution-live-morgrem-snorunt",
            "backup-grimmsnarl",
            "acquire",
            "interaction",
            220000,
            [
                _condition("prompt_kind", "eq", "search"),
                _condition("window.source_uid", "eq", "CSV1C_123"),
                _condition("option.card_uid", "eq", "CSV5C_119"),
                _condition("self.board.count_uid", "gte", 1, "CSV10C_147"),
                _condition("self.board.count_uid", "gte", 1, "CSV9.5C_043"),
                _condition("goal.deployed_count", "lt", 2),
            ],
        ),
        _rule(
            "search.arven-tm-evolution-two-snorunt",
            "double-froslass-engine",
            "acquire",
            "interaction",
            220000,
            [
                _condition("prompt_kind", "eq", "search"),
                _condition("window.source_uid", "eq", "CSV1C_123"),
                _condition("option.card_uid", "eq", "CSV5C_119"),
                _condition("self.board.count_uid", "gte", 2, "CSV9.5C_043"),
                _condition("self.board.count_uid", "lt", 2, "CSV7C_059"),
            ],
        ),
        _rule(
            "search.arven-energy-search-second-munkidori",
            "munkidori-transfer",
            "fund",
            "interaction",
            240000,
            [
                _condition("prompt_kind", "eq", "search"),
                _condition("window.source_uid", "eq", "CSV1C_123"),
                _condition("option.card_uid", "eq", "CSVH1C_035"),
                _condition("self.board.count_uid", "gte", 2, "CSV8C_094"),
                _condition("self.hand.count_uid", "eq", 0, "CSVE1C_DAR"),
                _condition("turn.manual_attachment_available", "eq", True),
                _condition("damage.available_mover_count", "eq", 1),
                _condition("damage.movable_counter_count", "gte", 3),
                _condition("turn_number", "gte", 5),
            ],
        ),
        _rule(
            "search.arven-energy-search-preserve-live-tm-evolutions",
            "double-froslass-engine",
            "fund",
            "interaction",
            300000,
            [
                _condition("prompt_kind", "eq", "search"),
                _condition("window.source_uid", "eq", "CSV1C_123"),
                _condition("option.card_uid", "eq", "CSVH1C_035"),
                _condition("self.hand.count_uid", "gte", 1, "CSV5C_119"),
                _condition("self.board.count_uid", "gte", 1, "CSV9.5C_043"),
                _condition("self.board.count_uid", "gte", 2, "CSV10C_146"),
                _condition("self.board.count_uid", "eq", 0, "CSV7C_059"),
                _condition("self.active.energy_count_uid", "gte", 1, "CSVE1C_DAR"),
                _condition("turn_number", "gte", 3),
            ],
        ),
        _rule(
            "search.arven-reject-ultra-ball-before-live-tm-evolutions",
            "double-froslass-engine",
            "acquire",
            "uncertainty",
            -300000,
            [
                _condition("prompt_kind", "eq", "search"),
                _condition("window.source_uid", "eq", "CSV1C_123"),
                _condition("option.card_uid", "eq", "CSV1C_112"),
                _condition("self.hand.count_uid", "gte", 1, "CSV5C_119"),
                _condition("self.board.count_uid", "gte", 1, "CSV9.5C_043"),
                _condition("self.board.count_uid", "gte", 2, "CSV10C_146"),
                _condition("self.board.count_uid", "eq", 0, "CSV7C_059"),
                _condition("self.active.energy_count_uid", "gte", 1, "CSVE1C_DAR"),
                _condition("turn_number", "gte", 3),
            ],
        ),
        _rule(
            "search.arven-energy-search-preserve-impidimp-snorunt-tm",
            "double-froslass-engine",
            "fund",
            "interaction",
            290000,
            [
                _condition("prompt_kind", "eq", "search"),
                _condition("window.source_uid", "eq", "CSV1C_123"),
                _condition("option.card_uid", "eq", "CSVH1C_035"),
                _condition("window.option_count_card_uid", "gte", 1, "CSV1C_112"),
                _condition("self.board.count_uid", "gte", 1, "CSV10C_146"),
                _condition("self.board.count_uid", "gte", 1, "CSV9.5C_043"),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_147"),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_148"),
                _condition("self.board.count_uid", "eq", 0, "CSV7C_059"),
                _condition("self.active.count_uid", "gte", 1, "CSV9.5C_004"),
                _condition("turn_number", "gte", 2),
            ],
        ),
        _rule(
            "search.arven-reject-ultra-ball-before-impidimp-snorunt-tm",
            "double-froslass-engine",
            "acquire",
            "uncertainty",
            -290000,
            [
                _condition("prompt_kind", "eq", "search"),
                _condition("window.source_uid", "eq", "CSV1C_123"),
                _condition("option.card_uid", "eq", "CSV1C_112"),
                _condition("self.board.count_uid", "gte", 1, "CSV10C_146"),
                _condition("self.board.count_uid", "gte", 1, "CSV9.5C_043"),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_147"),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_148"),
                _condition("self.board.count_uid", "eq", 0, "CSV7C_059"),
                _condition("self.active.count_uid", "gte", 1, "CSV9.5C_004"),
                _condition("turn_number", "gte", 2),
            ],
        ),
        _rule(
            "search.secret-box-tm-evolution-before-core",
            "double-froslass-engine",
            "acquire",
            "interaction",
            210000,
            [
                _condition("prompt_kind", "eq", "search"),
                _condition("window.source_uid", "eq", "CSV8C_176"),
                _condition("option.card_uid", "eq", "CSV5C_119"),
                _condition("self.board.count_uid", "eq", 0, "CSV7C_059"),
                _condition("self.board.count_uid", "gte", 1, "CSV10C_146"),
                _condition("self.board.count_uid", "gte", 1, "CSV9.5C_043"),
                _condition("goal.deployed_count", "lt", 2),
            ],
        ),
        _rule(
            "search.secret-box-tm-evolution-two-snorunt",
            "double-froslass-engine",
            "acquire",
            "interaction",
            210000,
            [
                _condition("prompt_kind", "eq", "search"),
                _condition("window.source_uid", "eq", "CSV8C_176"),
                _condition("option.card_uid", "eq", "CSV5C_119"),
                _condition("self.board.count_uid", "gte", 2, "CSV9.5C_043"),
                _condition("self.board.count_uid", "lt", 2, "CSV7C_059"),
            ],
        ),
        _rule(
            "attach.tm-evolution-active-before-munkidori",
            "double-froslass-engine",
            "fund",
            "macro",
            180000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "attach_energy"),
                _condition("option.card_uid", "eq", "CSVE1C_DAR"),
                _condition("option.target_is_active", "eq", True),
                _condition("option.target_attached_energy_count", "eq", 0),
                _condition("self.hand.count_uid", "gte", 1, "CSV5C_119"),
                _condition("self.board.count_uid", "gte", 1, "CSV9.5C_043"),
                _condition("goal.deployed_count", "lt", 2),
            ],
        ),
        _rule(
            "main.tm-evolution-before-manual-froslass-two-targets",
            "double-froslass-engine",
            "deploy",
            "macro",
            320000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "attach_tool"),
                _condition("option.card_uid", "eq", "CSV5C_119"),
                _condition("option.target_uid", "eq", "CSV10C_146"),
                _condition("option.target_is_active", "eq", True),
                _condition("option.target_attached_energy_count", "gte", 1),
                _condition("self.hand.count_uid", "gte", 1, "CSV7C_059"),
                _condition("self.board.count_uid", "gte", 1, "CSV9.5C_043"),
                _condition("self.board.count_uid", "gte", 2, "CSV10C_146"),
                _condition("self.board.count_uid", "eq", 0, "CSV7C_059"),
                _condition("turn_number", "gte", 3),
            ],
        ),
        _rule(
            "main.defer-manual-froslass-to-live-tm-evolution",
            "double-froslass-engine",
            "deploy",
            "uncertainty",
            -320000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "evolve"),
                _condition("option.card_uid", "eq", "CSV7C_059"),
                _condition("option.target_uid", "eq", "CSV9.5C_043"),
                _condition("self.hand.count_uid", "gte", 1, "CSV5C_119"),
                _condition("self.board.count_uid", "gte", 2, "CSV10C_146"),
                _condition("self.board.count_uid", "eq", 0, "CSV7C_059"),
                _condition("self.active.energy_count_uid", "gte", 1, "CSVE1C_DAR"),
                _condition("turn_number", "gte", 3),
            ],
        ),
        _rule(
            "main.defer-zero-energy-morgrem-to-tm-evolution",
            "backup-grimmsnarl",
            "deploy",
            "uncertainty",
            -300000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "evolve"),
                _condition("option.card_uid", "eq", "CSV10C_147"),
                _condition("option.target_uid", "eq", "CSV10C_146"),
                _condition("option.target_attached_energy_count", "eq", 0),
                _condition("self.hand.count_uid", "gte", 1, "CSV5C_119"),
                _condition("self.board.count_uid", "gte", 1, "CSV9.5C_043"),
                _condition("self.active.energy_count_uid", "gte", 1, "CSVE1C_DAR"),
                _condition("goal.deployed_count", "lt", 2),
            ],
        ),
        _rule(
            "tm-evolution-target.snorunt-engine-first",
            "double-froslass-engine",
            "deploy",
            "interaction",
            400000,
            [
                _condition("prompt_kind", "eq", "effect_target"),
                _condition("window.source_uid", "eq", "CSV5C_119"),
                _condition("option.target_uid", "eq", "CSV9.5C_043"),
                _condition("self.board.count_uid", "lt", 2, "CSV7C_059"),
            ],
        ),
        _rule(
            "tm-evolution-target.energy-impidimp-second",
            "backup-grimmsnarl",
            "deploy",
            "interaction",
            230000,
            [
                _condition("prompt_kind", "eq", "effect_target"),
                _condition("window.source_uid", "eq", "CSV5C_119"),
                _condition("option.target_uid", "eq", "CSV10C_146"),
                _condition("option.target_attached_energy_count", "gt", 0),
            ],
        ),
        _rule(
            "tm-evolution-target.energy-morgrem-core-first",
            "backup-grimmsnarl",
            "deploy",
            "interaction",
            450000,
            [
                _condition("prompt_kind", "eq", "effect_target"),
                _condition("window.source_uid", "eq", "CSV5C_119"),
                _condition("option.target_uid", "eq", "CSV10C_147"),
                _condition("option.target_attached_energy_count", "gt", 0),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_148"),
            ],
        ),
        _rule(
            "tm-evolution-target.impidimp-backup",
            "backup-grimmsnarl",
            "deploy",
            "interaction",
            150000,
            [
                _condition("prompt_kind", "eq", "effect_target"),
                _condition("window.source_uid", "eq", "CSV5C_119"),
                _condition("option.target_uid", "eq", "CSV10C_146"),
            ],
        ),
        _rule(
            "tm-evolution-target.reject-zero-energy-morgrem",
            "marnie-board-exact-two",
            "fund",
            "interaction",
            -240000,
            [
                _condition("prompt_kind", "eq", "effect_target"),
                _condition("window.source_uid", "eq", "CSV5C_119"),
                _condition("option.target_uid", "eq", "CSV10C_147"),
                _condition("option.target_attached_energy_count", "eq", 0),
            ],
        ),
        _rule(
            "tm-evolution-attack-target.snorunt-engine-first",
            "double-froslass-engine",
            "deploy",
            "interaction",
            400000,
            [
                _condition("prompt_kind", "eq", "attack_target"),
                _condition("window.source_uid", "eq", "CSV5C_119"),
                _condition("option.target_uid", "eq", "CSV9.5C_043"),
                _condition("self.board.count_uid", "lt", 2, "CSV7C_059"),
            ],
        ),
        _rule(
            "tm-evolution-attack-target.energy-impidimp-second",
            "backup-grimmsnarl",
            "deploy",
            "interaction",
            230000,
            [
                _condition("prompt_kind", "eq", "attack_target"),
                _condition("window.source_uid", "eq", "CSV5C_119"),
                _condition("option.target_uid", "eq", "CSV10C_146"),
                _condition("option.target_attached_energy_count", "gt", 0),
            ],
        ),
        _rule(
            "tm-evolution-attack-target.energy-morgrem-core-first",
            "backup-grimmsnarl",
            "deploy",
            "interaction",
            450000,
            [
                _condition("prompt_kind", "eq", "attack_target"),
                _condition("window.source_uid", "eq", "CSV5C_119"),
                _condition("option.target_uid", "eq", "CSV10C_147"),
                _condition("option.target_attached_energy_count", "gt", 0),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_148"),
            ],
        ),
        _rule(
            "tm-evolution-attack-target.reject-zero-energy-morgrem",
            "marnie-board-exact-two",
            "fund",
            "interaction",
            -240000,
            [
                _condition("prompt_kind", "eq", "attack_target"),
                _condition("window.source_uid", "eq", "CSV5C_119"),
                _condition("option.target_uid", "eq", "CSV10C_147"),
                _condition("option.target_attached_energy_count", "eq", 0),
            ],
        ),
        _rule(
            "search.artazon-munkidori-late-engine",
            "munkidori-transfer",
            "deploy",
            "interaction",
            180000,
            [
                _condition("prompt_kind", "eq", "search"),
                _condition("window.source_uid", "eq", "CSV2C_127"),
                _condition("option.card_uid", "eq", "CSV8C_094"),
                _condition("self.board.count_uid", "eq", 0, "CSV8C_094"),
                _condition("self.board.count_uid", "gte", 1, "CSV7C_059"),
                _condition("turn_number", "gte", 3),
            ],
        ),
        _rule(
            "search.artazon-reject-late-budew",
            "budew-tempo",
            "maintain",
            "uncertainty",
            -240000,
            [
                _condition("prompt_kind", "eq", "search"),
                _condition("window.source_uid", "eq", "CSV2C_127"),
                _condition("option.card_uid", "eq", "CSV9.5C_004"),
                _condition("turn_number", "gte", 3),
            ],
        ),
        _rule(
            "main.reject-late-budew-bench",
            "budew-tempo",
            "maintain",
            "uncertainty",
            -240000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_basic_to_bench"),
                _condition("option.card_uid", "eq", "CSV9.5C_004"),
                _condition("turn_number", "gte", 3),
            ],
        ),
        _rule(
            "search.spikemuth-grimmsnarl-with-morgrem-in-hand",
            "backup-grimmsnarl",
            "acquire",
            "interaction",
            230000,
            [
                _condition("prompt_kind", "eq", "search"),
                _condition("window.source_uid", "eq", "CSV10C_216"),
                _condition("option.card_uid", "eq", "CSV10C_148"),
                _condition("self.hand.count_uid", "gte", 1, "CSV10C_147"),
                _condition("self.board.count_uid", "gte", 1, "CSV10C_146"),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_148"),
            ],
        ),
        _rule(
            "send-out.protect-funded-impidimp-bridge-with-early-munkidori",
            "backup-grimmsnarl",
            "maintain",
            "interaction",
            260000,
            [
                _condition("prompt_kind", "eq", "send_out"),
                _condition("option.target_uid", "eq", "CSV8C_094"),
                _condition("option.target_attached_energy_count", "eq", 0),
                _condition("self.hand.count_uid", "gte", 1, "CSV10C_147"),
                _condition("self.board.count_uid", "gte", 1, "CSV10C_146"),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_147"),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_148"),
                _condition("turn_number", "lte", 4),
            ],
        ),
        _rule(
            "night-stretcher.morgrem-for-live-impidimp",
            "backup-grimmsnarl",
            "recover",
            "interaction",
            210000,
            [
                _condition("prompt_kind", "eq", "search"),
                _condition("window.source_uid", "eq", "CSV8C_183"),
                _condition("option.card_uid", "eq", "CSV10C_147"),
                _condition("self.board.count_uid", "gte", 1, "CSV10C_146"),
                _condition(
                    "self.board.energy_bearing_count_uid", "gte", 1, "CSV10C_146"
                ),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_147"),
                _condition("window.option_count_card_uid", "eq", 0, "CSVE1C_DAR"),
            ],
        ),
        _rule(
            "night-stretcher.reject-dead-grimmsnarl-without-bridge",
            "backup-grimmsnarl",
            "recover",
            "uncertainty",
            -150000,
            [
                _condition("prompt_kind", "eq", "search"),
                _condition("window.source_uid", "eq", "CSV8C_183"),
                _condition("option.card_uid", "eq", "CSV10C_148"),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_147"),
                _condition("self.hand.count_uid", "eq", 0, "CSVH1C_045"),
            ],
        ),
        _rule(
            "night-stretcher.effect-target.morgrem-for-live-impidimp",
            "backup-grimmsnarl",
            "recover",
            "interaction",
            210000,
            [
                _condition("prompt_kind", "eq", "effect_target"),
                _condition("window.source_uid", "eq", "CSV8C_183"),
                _condition("option.card_uid", "eq", "CSV10C_147"),
                _condition("self.board.count_uid", "gte", 1, "CSV10C_146"),
                _condition(
                    "self.board.energy_bearing_count_uid", "gte", 1, "CSV10C_146"
                ),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_147"),
                _condition("window.option_count_card_uid", "eq", 0, "CSVE1C_DAR"),
            ],
        ),
        _rule(
            "night-stretcher.effect-target.reject-dead-grimmsnarl-without-bridge",
            "backup-grimmsnarl",
            "recover",
            "uncertainty",
            -150000,
            [
                _condition("prompt_kind", "eq", "effect_target"),
                _condition("window.source_uid", "eq", "CSV8C_183"),
                _condition("option.card_uid", "eq", "CSV10C_148"),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_147"),
                _condition("self.hand.count_uid", "eq", 0, "CSVH1C_045"),
            ],
        ),
        _rule(
            "night-stretcher.effect-target.impidimp-bridge-when-core-is-missing",
            "backup-grimmsnarl",
            "recover",
            "interaction",
            220000,
            [
                _condition("prompt_kind", "eq", "effect_target"),
                _condition("window.source_uid", "eq", "CSV8C_183"),
                _condition("option.card_uid", "eq", "CSV10C_146"),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_146"),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_147"),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_148"),
                _condition("self.hand.count_uid", "eq", 0, "CSV10C_147"),
                _condition("self.hand.count_uid", "eq", 0, "CSV10C_148"),
                _condition("turn_number", "gte", 3),
            ],
        ),
        _rule(
            "night-stretcher.effect-target.reject-late-budew",
            "budew-tempo",
            "recover",
            "uncertainty",
            -240000,
            [
                _condition("prompt_kind", "eq", "effect_target"),
                _condition("window.source_uid", "eq", "CSV8C_183"),
                _condition("option.card_uid", "eq", "CSV9.5C_004"),
                _condition("turn_number", "gte", 3),
            ],
        ),
        _rule(
            "main.spikemuth-backup-before-nonterminal-attack",
            "backup-grimmsnarl",
            "deploy",
            "future",
            190000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "use_stadium_effect"),
                _condition("option.source_uid", "eq", "CSV10C_216"),
                _condition("self.board.count_uid", "gte", 1, "CSV10C_146"),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_147"),
                _condition("self.prizes_remaining", "gt", 1),
                _condition("turn_number", "gte", 3),
            ],
        ),
        _rule(
            "main.retreat-morgrem-to-spare-impidimp-preserve-grimmsnarl",
            "backup-grimmsnarl",
            "recover",
            "future",
            300000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "retreat"),
                _condition("option.target_uid", "eq", "CSV10C_146"),
                _condition("self.active.count_uid", "gte", 1, "CSV10C_147"),
                _condition("self.active.energy_count_uid", "gte", 1, "CSVE1C_DAR"),
                _condition("self.hand.count_uid", "gte", 1, "CSV10C_148"),
                _condition("self.hand.count_uid", "gte", 1, "CSVE1C_DAR"),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_148"),
                _condition("self.board.count_uid", "gte", 2, "CSV10C_146"),
                _condition("turn.retreat_available", "eq", True),
                _condition("turn_number", "lte", 5),
            ],
        ),
        _rule(
            "main.attach-tm-to-ready-grimmsnarl-before-attack-two-snorunt",
            "double-froslass-engine",
            "deploy",
            "macro",
            350000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "attach_tool"),
                _condition("option.card_uid", "eq", "CSV5C_119"),
                _condition("option.target_uid", "eq", "CSV10C_148"),
                _condition("option.target_is_active", "eq", True),
                _condition("option.target_attached_energy_count", "gte", 1),
                _condition("self.board.count_uid", "gte", 2, "CSV9.5C_043"),
                _condition("self.board.count_uid", "lt", 2, "CSV7C_059"),
                _condition("goal.deployed_count", "lt", 2),
            ],
        ),
        _rule(
            "main.research-before-attack-to-find-first-munkidori-energy",
            "munkidori-transfer",
            "fund",
            "macro",
            330000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSV1C_121"),
                _condition("self.active.count_uid", "gte", 1, "CSV10C_148"),
                _condition("self.board.count_uid", "gte", 1, "CSV8C_094"),
                _condition("self.board.energy_count_uid", "lt", 3, "CSVE1C_DAR"),
                _condition("self.hand.count_uid", "eq", 0, "CSVE1C_DAR"),
                _condition("self.hand_count", "lte", 5),
                _condition("turn.supporter_available", "eq", True),
                _condition("turn.manual_attachment_available", "eq", True),
                _condition("turn_number", "gte", 5),
                _condition("turn_number", "lte", 9),
            ],
        ),
        _rule(
            "attach.munkidori-before-zero-damage-wall-attack",
            "munkidori-transfer",
            "fund",
            "macro",
            340000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "attach_energy"),
                _condition("option.card_uid", "eq", "CSVE1C_DAR"),
                _condition("option.target_uid", "eq", "CSV8C_094"),
                _condition("option.target_attached_energy_count", "eq", 0),
                _condition("self.active.count_uid", "gte", 1, "CSV10C_148"),
                _condition("self.board.energy_count_uid", "lt", 3, "CSVE1C_DAR"),
                _condition("opponent.active.prize_value", "eq", 1),
                _condition("opponent.active.remaining_hp", "lte", 180),
                _condition("turn.manual_attachment_available", "eq", True),
                _condition("turn_number", "lte", 9),
            ],
        ),
        _rule(
            "attach.active-munkidori-before-last-prize-iono",
            "munkidori-transfer",
            "fund",
            "macro",
            400000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "attach_energy"),
                _condition("option.card_uid", "eq", "CSVE1C_DAR"),
                _condition("option.target_uid", "eq", "CSV8C_094"),
                _condition("option.target_is_active", "eq", True),
                _condition("option.target_attached_energy_count", "eq", 1),
                _condition("self.prizes_remaining", "eq", 2),
                _condition("opponent.prizes_remaining", "eq", 1),
                _condition("window.option_count_card_uid", "gte", 1, "CSV3C_123"),
                _condition("turn.supporter_available", "eq", True),
                _condition("turn.manual_attachment_available", "eq", True),
            ],
        ),
        _rule(
            "main.research-before-shadow-bullet-with-two-unevolved-snorunt",
            "double-froslass-engine",
            "deploy",
            "macro",
            330000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSV1C_121"),
                _condition("self.active.count_uid", "gte", 1, "CSV10C_148"),
                _condition("self.board.count_uid", "gte", 2, "CSV9.5C_043"),
                _condition("self.board.count_uid", "eq", 0, "CSV7C_059"),
                _condition("self.board.count_uid", "eq", 0, "CSV8C_094"),
                _condition("self.hand_count", "lte", 3),
                _condition("turn.supporter_available", "eq", True),
                _condition("turn_number", "lte", 6),
            ],
        ),
        _rule(
            "main.tm-devolution-before-zero-damage-crustle-wall",
            "devolution-finish",
            "deploy",
            "macro",
            360000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "attach_tool"),
                _condition("option.card_uid", "eq", "CSV5C_120"),
                _condition("option.target_uid", "eq", "CSV10C_148"),
                _condition("option.target_is_active", "eq", True),
                _condition("option.target_attached_energy_count", "gte", 2),
                _condition("self.active.count_uid", "gte", 1, "CSV10C_148"),
                _condition("opponent.active.prize_value", "eq", 1),
                _condition("damage.current_attack_damage", "eq", 0),
            ],
        ),
        _rule(
            "attack.tm-devolution-complete-zero-damage-wall-line",
            "devolution-finish",
            "execute",
            "tactical",
            370000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "granted_attack"),
                _condition("option.source_uid", "eq", "CSV5C_120"),
                _condition("self.active.count_uid", "gte", 1, "CSV10C_148"),
                _condition("opponent.active.prize_value", "eq", 1),
            ],
        ),
        _rule(
            "main.retreat-weak-impidimp-into-ready-grimmsnarl",
            "grimmsnarl-prize-route",
            "execute",
            "macro",
            360000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "retreat"),
                _condition("option.target_uid", "eq", "CSV10C_148"),
                _condition("option.target_attack_ready", "eq", True),
                _condition("self.active.count_uid", "gte", 1, "CSV10C_146"),
                _condition("damage.current_attack_damage", "lte", 10),
                _condition("turn.retreat_available", "eq", True),
                _condition("turn_number", "gte", 3),
            ],
        ),
        _rule(
            "attack-target.shadow-bullet-low-hp-single-prize-froslass-finish",
            "grimmsnarl-prize-route",
            "execute",
            "interaction",
            300000,
            [
                _condition("prompt_kind", "eq", "attack_target"),
                _condition("option.kind", "eq", "attack_target"),
                _condition("option.source_uid", "eq", "CSV10C_148"),
                _condition("option.target_prize_value", "eq", 1),
                _condition("option.target_remaining_hp", "lte", 50),
                _condition("self.board.count_uid", "gte", 1, "CSV7C_059"),
            ],
        ),
        _rule(
            "attack.morgrem-two-prize-ko-before-empty-tm-evolution",
            "grimmsnarl-prize-route",
            "execute",
            "tactical",
            420000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "attack"),
                _condition("option.source_uid", "eq", "CSV10C_147"),
                _condition("option.projected_damage", "gte", 60),
                _condition("opponent.active.remaining_hp", "lte", 60),
                _condition("opponent.active.prize_value", "eq", 2),
                _condition("self.board.count_uid", "eq", 0, "CSV9.5C_043"),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_146"),
                _condition("self.board.count_uid", "gte", 1, "CSV7C_059"),
            ],
        ),
        _rule(
            "pre-attack-development.evolve-funded-impidimp-to-morgrem",
            "backup-grimmsnarl",
            "deploy",
            "macro",
            360000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "evolve"),
                _condition("option.card_uid", "eq", "CSV10C_147"),
                _condition("option.target_uid", "eq", "CSV10C_146"),
                _condition("option.target_attached_energy_count", "gte", 1),
                _condition("self.board.count_uid", "gte", 1, "CSV10C_148"),
                _condition("self.hand.count_uid", "eq", 0, "CSV5C_119"),
                _condition("opponent.prizes_remaining", "gte", 2),
                _condition("turn_number", "gte", 3),
            ],
        ),
        _rule(
            "pre-attack-development.counter-catcher-better-two-prize-route",
            "grimmsnarl-prize-route",
            "execute",
            "macro",
            380000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSV6C_114"),
                _condition("damage.current_attack_damage", "lte", 10),
                _condition("damage.best_prize_yield", "eq", 1),
                _condition("damage.best_gust_prize_yield", "eq", 2),
                _condition("damage.best_attack_windows_to_ko", "gte", 2),
                _condition("damage.best_gust_attack_windows_to_ko", "lte", 2),
                _condition("opponent.prizes_remaining", "gte", 2),
            ],
        ),
        _rule(
            "pre-attack-development.defer-late-wall-after-munkidori-and-attachment",
            "munkidori-transfer",
            "execute",
            "tactical",
            700000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "end_turn"),
                _condition("self.active.count_uid", "gte", 1, "CSV10C_148"),
                _condition("self.active.energy_count_uid", "gte", 2, "CSVE1C_DAR"),
                _condition("self.board.count_uid", "gte", 1, "CSV7C_059"),
                _condition("self.board.count_uid", "gte", 1, "CSV8C_094"),
                _condition("window.option_count_source_uid", "eq", 0, "CSV8C_094"),
                _condition("damage.current_attack_damage", "eq", 0),
                _condition("opponent.active.prize_value", "eq", 1),
                _condition("self.prizes_remaining", "lte", 4),
                _condition("opponent.prizes_remaining", "gte", 4),
                _condition("turn.manual_attachment_available", "eq", False),
                _condition("turn_number", "gte", 10),
            ],
        ),
        _rule(
            "pre-end-development.iono-for-first-froslass-low-hand",
            "double-froslass-engine",
            "acquire",
            "macro",
            280000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSV3C_123"),
                _condition("self.board.count_uid", "eq", 1, "CSV9.5C_043"),
                _condition("self.board.count_uid", "eq", 0, "CSV7C_059"),
                _condition("self.board.count_uid", "gte", 1, "CSV10C_148"),
                _condition("self.hand.count_uid", "eq", 0, "CSV7C_059"),
                _condition("self.hand_count", "lte", 4),
                _condition("opponent.hand_count", "lte", 3),
                _condition("turn.supporter_available", "eq", True),
                _condition("opponent.prizes_remaining", "gte", 2),
                _condition("turn_number", "gte", 3),
                _condition("turn_number", "lte", 12),
            ],
        ),
        _rule(
            "pre-end-development.iono-before-zero-damage-completed-core-stall",
            "grimmsnarl-prize-route",
            "recover",
            "macro",
            380000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSV3C_123"),
                _condition("self.active.count_uid", "gte", 1, "CSV10C_148"),
                _condition("self.board.count_uid", "gte", 1, "CSV7C_059"),
                _condition(
                    "self.board.energy_bearing_count_uid", "gte", 1, "CSV8C_094"
                ),
                _condition("damage.current_attack_damage", "eq", 0),
                _condition("self.hand_count", "lte", 5),
                _condition("self.deck_count", "gt", 8),
                _condition("opponent.prizes_remaining", "gte", 2),
                _condition("turn.supporter_available", "eq", True),
                _condition("turn_number", "gte", 5),
                _condition("turn_number", "lte", 13),
            ],
        ),
        _rule(
            "pre-end-development.iono-deny-opponent-last-prizes",
            "grimmsnarl-prize-route",
            "recover",
            "interaction",
            300000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSV3C_123"),
                _condition("opponent.hand_count", "gte", 5),
                _condition("opponent.prizes_remaining", "gte", 1),
                _condition("opponent.prizes_remaining", "lte", 2),
                _condition("window.option_count_card_uid", "eq", 0, "CSVE1C_DAR"),
                _condition("turn.supporter_available", "eq", True),
                _condition("turn_number", "gte", 8),
            ],
        ),
        _rule(
            "main.spikemuth-complete-energy-bearing-morgrem-backup",
            "backup-grimmsnarl",
            "acquire",
            "future",
            340000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "use_stadium_effect"),
                _condition("option.source_uid", "eq", "CSV10C_216"),
                _condition("self.board.count_uid", "eq", 1, "CSV10C_148"),
                _condition("self.board.count_uid", "gte", 1, "CSV10C_147"),
                _condition(
                    "self.board.energy_bearing_count_uid", "gte", 1, "CSV10C_147"
                ),
                _condition("turn_number", "gte", 3),
            ],
        ),
        _rule(
            "pre-attack-development.bench-munkidori-for-live-snorunt-engine",
            "munkidori-transfer",
            "deploy",
            "macro",
            50000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_basic_to_bench"),
                _condition("option.card_uid", "eq", "CSV8C_094"),
                _condition("self.active.count_uid", "gte", 1, "CSV10C_148"),
                _condition(
                    "self.active.energy_count_uid", "gte", 2, "CSVE1C_DAR"
                ),
                _condition("self.board.count_uid", "gte", 1, "CSV9.5C_043"),
                _condition("self.board.count_uid", "eq", 0, "CSV7C_059"),
                _condition("self.board.count_uid", "eq", 0, "CSV8C_094"),
                _condition("turn.supporter_available", "eq", False),
                _condition("turn_number", "gte", 5),
            ],
        ),
        _rule(
            "send-out.ready-impidimp-over-unfunded-grimmsnarl",
            "backup-grimmsnarl",
            "maintain",
            "interaction",
            220000,
            [
                _condition("prompt_kind", "eq", "send_out"),
                _condition("option.target_uid", "eq", "CSV10C_146"),
                _condition("option.target_attack_ready", "eq", True),
                _condition("option.target_prize_value", "eq", 1),
                _condition("self.board.count_uid", "gte", 1, "CSV10C_148"),
                _condition(
                    "self.board.energy_bearing_count_uid", "eq", 0, "CSV10C_148"
                ),
                _condition(
                    "self.board.energy_bearing_count_uid", "eq", 0, "CSV8C_094"
                ),
                _condition("turn_number", "gte", 5),
            ],
        ),
        _rule(
            "self-switch.rebind-ready-grimmsnarl-after-retreat",
            "grimmsnarl-prize-route",
            "execute",
            "interaction",
            600000,
            [
                _condition("prompt_kind", "eq", "self_switch"),
                _condition("option.kind", "eq", "send_out"),
                _condition("option.target_uid", "eq", "CSV10C_148"),
                _condition("option.target_attached_energy_count", "gte", 2),
                _condition("option.target_attack_ready", "eq", True),
                _condition("opponent.prizes_remaining", "gte", 1),
                _condition("turn_number", "gte", 5),
            ],
        ),
        _rule(
            "pre-action.energy-search-for-munkidori-debt-with-manual-window",
            "munkidori-transfer",
            "fund",
            "macro",
            100000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSVH1C_035"),
                _condition("self.hand.count_uid", "eq", 0, "CSVE1C_DAR"),
                _condition("self.active.count_uid", "gte", 1, "CSV8C_094"),
                _condition("turn.manual_attachment_available", "eq", True),
                _condition("opponent.prizes_remaining", "gte", 2),
            ],
        ),
        _rule(
            "pre-attack.energy-search-for-munkidori-debt-after-supporter",
            "munkidori-transfer",
            "fund",
            "macro",
            40000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSVH1C_035"),
                _condition("self.hand.count_uid", "eq", 0, "CSVE1C_DAR"),
                _condition("self.board.count_uid", "gte", 1, "CSV8C_094"),
                _condition(
                    "self.board.energy_bearing_count_uid", "eq", 0, "CSV8C_094"
                ),
                _condition("turn.manual_attachment_available", "eq", False),
                _condition("turn.supporter_available", "eq", False),
                _condition("opponent.prizes_remaining", "gte", 2),
                _condition("turn_number", "gte", 3),
            ],
        ),
        _rule(
            "pre-attack-development.research-for-missing-froslass-low-hand",
            "double-froslass-engine",
            "acquire",
            "macro",
            90000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSV1C_121"),
                _condition("self.board.count_uid", "gte", 1, "CSV10C_148"),
                _condition("self.board.count_uid", "eq", 0, "CSV7C_059"),
                _condition("self.hand_count", "lte", 5),
                _condition("self.hand.count_uid", "eq", 0, "CSV10C_148"),
                _condition("self.hand.count_uid", "eq", 0, "CSV10C_147"),
                _condition("self.hand.count_uid", "eq", 0, "CSV7C_059"),
                _condition("self.hand.count_uid", "eq", 0, "CSV9.5C_043"),
                _condition("self.hand.count_uid", "eq", 0, "CSV10C_146"),
                _condition("self.hand.count_uid", "eq", 0, "CSV8C_094"),
                _condition("self.hand.count_uid", "eq", 0, "CSV5C_119"),
                _condition("turn.supporter_available", "eq", True),
                _condition("self.deck_count", "gt", 10),
                _condition("opponent.prizes_remaining", "gte", 3),
            ],
        ),
        _rule(
            "main.retreat-early-budew-into-funded-impidimp-for-live-tm-evolution",
            "double-froslass-engine",
            "deploy",
            "macro",
            480000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "retreat"),
                _condition("option.target_uid", "eq", "CSV10C_146"),
                _condition("option.target_attached_energy_count", "gte", 1),
                _condition("self.active.count_uid", "gte", 1, "CSV9.5C_004"),
                _condition("self.hand.count_uid", "gte", 1, "CSV5C_119"),
                _condition("self.board.count_uid", "gte", 1, "CSV9.5C_043"),
                _condition("self.board.count_uid", "lt", 2, "CSV7C_059"),
                _condition("turn.retreat_available", "eq", True),
                _condition("turn_number", "gte", 3),
                _condition("turn_number", "lte", 6),
            ],
        ),
        _rule(
            "main.retreat-budew-into-ready-marnie-pokemon-after-first-turn-stall",
            "grimmsnarl-prize-route",
            "deploy",
            "macro",
            260000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "retreat"),
                _condition("option.target_uid", "eq", "CSV10C_146"),
                _condition("option.target_attached_energy_count", "gte", 1),
                _condition("option.target_attack_ready", "eq", True),
                _condition("self.active.count_uid", "gte", 1, "CSV9.5C_004"),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_148"),
                _condition("turn.retreat_available", "eq", True),
                _condition("turn_number", "gte", 4),
                _condition("turn_number", "lte", 4),
            ],
        ),
        _rule(
            "main.retreat-developed-froslass-into-ready-grimmsnarl-before-ending",
            "grimmsnarl-prize-route",
            "execute",
            "macro",
            520000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "retreat"),
                _condition("option.target_uid", "eq", "CSV10C_148"),
                _condition("option.target_attached_energy_count", "gte", 2),
                _condition("option.target_attack_ready", "eq", True),
                _condition("self.active.count_uid", "gte", 1, "CSV7C_059"),
                _condition("self.board.count_uid", "gte", 2, "CSV7C_059"),
                _condition("self.board.count_uid", "gte", 1, "CSV8C_094"),
                _condition("turn.retreat_available", "eq", True),
                _condition("opponent.prizes_remaining", "gte", 1),
            ],
        ),
        _rule(
            "send-out.late-funded-munkidori-with-live-snorunt-transfer-line",
            "munkidori-transfer",
            "execute",
            "interaction",
            260000,
            [
                _condition("prompt_kind", "eq", "send_out"),
                _condition("option.target_uid", "eq", "CSV8C_094"),
                _condition("option.target_attached_energy_count", "gte", 1),
                _condition("option.target_prize_value", "eq", 1),
                _condition("self.board.count_uid", "gte", 1, "CSV9.5C_043"),
                _condition("turn_number", "gte", 9),
            ],
        ),
        _rule(
            "attach.active-munkidori-before-ready-grimmsnarl-retreat",
            "munkidori-transfer",
            "fund",
            "macro",
            560000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "attach_energy"),
                _condition("option.card_uid", "eq", "CSVE1C_DAR"),
                _condition("option.target_uid", "eq", "CSV8C_094"),
                _condition("option.target_attached_energy_count", "eq", 1),
                _condition("option.target_attack_ready", "eq", False),
                _condition("self.active.count_uid", "gte", 1, "CSV8C_094"),
                _condition("self.hand.count_uid", "gte", 1, "CSVE1C_DAR"),
                _condition("self.board.count_uid", "gte", 1, "CSV10C_148"),
                _condition("window.option_count_card_uid", "eq", 0, "CSV2C_127"),
                _condition("damage.current_attack_damage", "eq", 0),
                _condition("turn.manual_attachment_available", "eq", True),
                _condition("turn.retreat_available", "eq", True),
                _condition("turn_number", "gte", 7),
            ],
        ),
        _rule(
            "main.retreat-active-munkidori-into-ready-grimmsnarl-before-passing",
            "grimmsnarl-prize-route",
            "execute",
            "macro",
            520000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "retreat"),
                _condition("option.target_uid", "eq", "CSV10C_148"),
                _condition("option.target_attached_energy_count", "gte", 2),
                _condition("option.target_attack_ready", "eq", True),
                _condition("self.active.count_uid", "gte", 1, "CSV8C_094"),
                _condition("self.active.energy_count_uid", "gte", 1, "CSVE1C_DAR"),
                _condition("self.active.remaining_hp", "gt", 60),
                _condition("self.board.count_uid", "eq", 0, "CSV7C_059"),
                _condition("self.hand.count_uid", "eq", 0, "CSVE1C_DAR"),
                _condition("damage.current_attack_damage", "eq", 0),
                _condition("damage.available_mover_count", "eq", 0),
                _condition("window.option_count_card_uid", "eq", 0, "CSV7C_059"),
                _condition("window.option_count_card_uid", "eq", 0, "CSV2C_127"),
                _condition("window.option_count_source_uid", "eq", 0, "CSV2C_127"),
                _condition("window.option_count_source_uid", "eq", 0, "CSV10C_216"),
                _condition("turn.retreat_available", "eq", True),
                _condition("turn_number", "gte", 7),
            ],
        ),
        _rule(
            "pre-supporter-development.bench-munkidori-with-live-froslass-transfer-package",
            "munkidori-transfer",
            "execute",
            "macro",
            500000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_basic_to_bench"),
                _condition("option.card_uid", "eq", "CSV8C_094"),
                _condition("self.active.count_uid", "gte", 1, "CSV10C_148"),
                _condition("self.board.count_uid", "gte", 1, "CSV7C_059"),
                _condition("self.board.count_uid", "eq", 0, "CSV8C_094"),
                _condition("self.hand.count_uid", "gte", 1, "CSVE1C_DAR"),
                _condition("damage.current_attack_damage", "eq", 0),
                _condition("turn.supporter_available", "eq", True),
                _condition("turn.manual_attachment_available", "eq", True),
                _condition("turn_number", "gte", 5),
            ],
        ),
        _rule(
            "pre-supporter-development.bench-backup-munkidori-for-fragile-active-transfer-pivot",
            "munkidori-transfer",
            "deploy",
            "macro",
            90000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_basic_to_bench"),
                _condition("option.card_uid", "eq", "CSV8C_094"),
                _condition("self.active.count_uid", "gte", 1, "CSV8C_094"),
                _condition("self.active.remaining_hp", "lte", 90),
                _condition("self.board.count_uid", "eq", 1, "CSV8C_094"),
                _condition("self.board.count_uid", "gte", 1, "CSV7C_059"),
                _condition("self.hand.count_uid", "gte", 1, "CSVE1C_DAR"),
                _condition("opponent.prizes_remaining", "gte", 1),
                _condition("opponent.prizes_remaining", "lte", 2),
                _condition("turn.supporter_available", "eq", True),
                _condition("turn_number", "gte", 9),
            ],
        ),
        _rule(
            "pre-end-development.research-for-gust-or-devolution-zero-damage-out",
            "grimmsnarl-prize-route",
            "recover",
            "macro",
            420000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSV1C_121"),
                _condition("self.active.count_uid", "gte", 1, "CSV10C_148"),
                _condition(
                    "self.board.energy_bearing_count_uid", "gte", 1, "CSV8C_094"
                ),
                _condition("damage.current_attack_damage", "eq", 0),
                _condition("damage.best_gust_prize_yield", "gte", 2),
                _condition("opponent.prizes_remaining", "gte", 1),
                _condition("opponent.prizes_remaining", "lte", 3),
                _condition("self.deck_count", "gt", 7),
                _condition("turn.supporter_available", "eq", True),
                _condition("turn_number", "gte", 5),
            ],
        ),
        _rule(
            "pre-end-development.research-before-zero-damage-stalled-grimmsnarl",
            "grimmsnarl-prize-route",
            "recover",
            "macro",
            500000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSV1C_121"),
                _condition("self.active.count_uid", "gte", 1, "CSV10C_148"),
                _condition("self.board.count_uid", "gte", 2, "CSV10C_148"),
                _condition(
                    "self.active.energy_count_uid", "eq", 1, "CSVE1C_DAR"
                ),
                _condition("damage.current_attack_damage", "eq", 0),
                _condition("self.hand_count", "lte", 6),
                _condition("self.deck_count", "gt", 10),
                _condition("opponent.prizes_remaining", "gte", 3),
                _condition("turn.supporter_available", "eq", True),
                _condition("turn_number", "gte", 9),
            ],
        ),
        _rule(
            "pre-end-development.research-before-last-prize-pass-active-froslass-ready-grimmsnarl",
            "grimmsnarl-prize-route",
            "recover",
            "macro",
            520000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "play_trainer"),
                _condition("option.card_uid", "eq", "CSV1C_121"),
                _condition("self.active.count_uid", "gte", 1, "CSV7C_059"),
                _condition("self.board.count_uid", "gte", 1, "CSV10C_148"),
                _condition("self.board.energy_count_uid", "gte", 2, "CSVE1C_DAR"),
                _condition("self.hand_count", "lte", 6),
                _condition("self.deck_count", "gte", 10),
                _condition("opponent.prizes_remaining", "eq", 1),
                _condition("damage.current_attack_damage", "eq", 0),
                _condition("turn.supporter_available", "eq", True),
                _condition("turn_number", "gte", 8),
            ],
        ),
        _rule(
            "pre-end-development.evolve-froslass-with-funded-munkidori",
            "munkidori-transfer",
            "execute",
            "macro",
            520000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "evolve"),
                _condition("option.card_uid", "eq", "CSV7C_059"),
                _condition("option.target_uid", "eq", "CSV9.5C_043"),
                _condition("self.board.count_uid", "lt", 2, "CSV7C_059"),
                _condition(
                    "self.board.energy_bearing_count_uid", "gte", 1, "CSV8C_094"
                ),
                _condition("opponent.prizes_remaining", "lte", 2),
                _condition("turn_number", "gte", 9),
            ],
        ),
        _rule(
            "pre-attack-development.spikemuth-before-tm-devolution-funded-impidimp",
            "backup-grimmsnarl",
            "deploy",
            "macro",
            260000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "use_stadium_effect"),
                _condition("option.source_uid", "eq", "CSV10C_216"),
                _condition("self.active.count_uid", "gte", 1, "CSV10C_148"),
                _condition(
                    "self.board.energy_bearing_count_uid", "gte", 1, "CSV10C_146"
                ),
                _condition("self.board.count_uid", "eq", 0, "CSV10C_147"),
                _condition("self.prizes_remaining", "gt", 1),
                _condition("turn_number", "gte", 5),
            ],
        ),
        _rule(
            "main.attach-tm-to-funded-active-impidimp-before-optional-munkidori-energy",
            "double-froslass-engine",
            "deploy",
            "macro",
            520000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "attach_tool"),
                _condition("option.card_uid", "eq", "CSV5C_119"),
                _condition("option.target_uid", "eq", "CSV10C_146"),
                _condition("option.target_is_active", "eq", True),
                _condition("option.target_attached_energy_count", "gte", 1),
                _condition("self.board.count_uid", "gte", 2, "CSV10C_146"),
                _condition("self.board.count_uid", "gte", 1, "CSV9.5C_043"),
                _condition("self.board.count_uid", "lt", 2, "CSV7C_059"),
                _condition("turn_number", "gte", 3),
            ],
        ),
        _rule(
            "main.attach-tm-before-zero-damage-with-funded-morgrem-and-snorunt",
            "double-froslass-engine",
            "deploy",
            "macro",
            500000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "attach_tool"),
                _condition("option.card_uid", "eq", "CSV5C_119"),
                _condition("option.target_uid", "eq", "CSV10C_148"),
                _condition("option.target_is_active", "eq", True),
                _condition("option.target_attached_energy_count", "gte", 2),
                _condition("self.board.count_uid", "gte", 1, "CSV9.5C_043"),
                _condition("self.board.count_uid", "lt", 2, "CSV7C_059"),
                _condition("self.board.energy_bearing_count_uid", "gte", 1, "CSV10C_147"),
                _condition("damage.current_attack_damage", "eq", 0),
                _condition("opponent.prizes_remaining", "gte", 2),
                _condition("turn_number", "gte", 3),
            ],
        ),
        _rule(
            "main.attach-tm-before-zero-damage-with-funded-impidimp-and-snorunt",
            "double-froslass-engine",
            "deploy",
            "macro",
            500000,
            [
                _condition("prompt_kind", "eq", "main"),
                _condition("option.kind", "eq", "attach_tool"),
                _condition("option.card_uid", "eq", "CSV5C_119"),
                _condition("option.target_uid", "eq", "CSV10C_148"),
                _condition("option.target_is_active", "eq", True),
                _condition("option.target_attached_energy_count", "gte", 2),
                _condition("self.board.count_uid", "gte", 1, "CSV9.5C_043"),
                _condition("self.board.count_uid", "lt", 2, "CSV7C_059"),
                _condition("self.board.energy_bearing_count_uid", "gte", 1, "CSV10C_146"),
                _condition("damage.current_attack_damage", "eq", 0),
                _condition("opponent.prizes_remaining", "gte", 2),
                _condition("turn_number", "gte", 3),
            ],
        ),
        _rule(
            "secret-box.discard.preserve-boss-for-last-prize-candy-grimmsnarl-chain",
            "grimmsnarl-prize-route",
            "recover",
            "uncertainty",
            -700000,
            [
                _condition("prompt_kind", "eq", "effect_target"),
                _condition("window.source_uid", "eq", "CSV8C_176"),
                _condition("option.card_uid", "eq", "CSVH1aC_023"),
                _condition("self.active.count_uid", "gte", 1, "CSV10C_146"),
                _condition("self.hand.count_uid", "gte", 1, "CSVH1C_045"),
                _condition("self.discard.count_uid", "gte", 1, "CSV10C_148"),
                _condition("self.prizes_remaining", "eq", 1),
                _condition("opponent.prizes_remaining", "eq", 1),
                _condition("turn_number", "gte", 8),
            ],
        ),
        _rule(
            "search.secret-box-night-stretcher-for-last-prize-candy-grimmsnarl-chain",
            "grimmsnarl-prize-route",
            "recover",
            "interaction",
            520000,
            [
                _condition("prompt_kind", "eq", "search"),
                _condition("window.source_uid", "eq", "CSV8C_176"),
                _condition("option.card_uid", "eq", "CSV8C_183"),
                _condition("self.active.count_uid", "gte", 1, "CSV10C_146"),
                _condition("self.hand.count_uid", "gte", 1, "CSVH1C_045"),
                _condition("self.discard.count_uid", "gte", 1, "CSV10C_148"),
                _condition("self.prizes_remaining", "eq", 1),
                _condition("opponent.prizes_remaining", "eq", 1),
                _condition("turn_number", "gte", 8),
            ],
        ),
    ]
    existing_ids = {str(rule["rule_id"]) for rule in rules}
    if existing_ids & {str(rule["rule_id"]) for rule in new_rules}:
        raise ValueError("marnie_r54_duplicate_rule_id")
    rules.extend(new_rules)

    new_count_rules = [
        _fixed_count(
            "tm-evolution.two-live-effect-targets",
            1,
            "double-froslass-engine",
            2,
            [
                _condition("window.source_uid", "eq", "CSV5C_119"),
                _condition("select.max_count", "eq", 2),
            ],
        ),
        _fixed_count(
            "tm-evolution.live-attack-target.impidimp-and-snorunt",
            2,
            "double-froslass-engine",
            2,
            [
                _condition("prompt_kind", "eq", "attack_target"),
                _condition("select.context_raw", "eq", 25),
                _condition("select.max_count", "eq", 2),
                _condition("window.option_count_card_uid", "gte", 1, "CSV10C_146"),
                _condition("window.option_count_card_uid", "gte", 1, "CSV9.5C_043"),
            ],
        ),
        _fixed_count(
            "tm-evolution.live-attack-target.energy-morgrem-and-snorunt",
            2,
            "double-froslass-engine",
            2,
            [
                _condition("prompt_kind", "eq", "attack_target"),
                _condition("select.context_raw", "eq", 25),
                _condition("select.max_count", "eq", 2),
                _condition("window.option_count_card_uid", "gte", 1, "CSV10C_147"),
                _condition("window.option_count_card_uid", "gte", 1, "CSV9.5C_043"),
                _condition(
                    "self.board.energy_bearing_count_uid", "gte", 1, "CSV10C_147"
                ),
            ],
        ),
        _fixed_count(
            "tm-evolution.live-attack-target.two-snorunt",
            3,
            "double-froslass-engine",
            2,
            [
                _condition("prompt_kind", "eq", "attack_target"),
                _condition("select.context_raw", "eq", 25),
                _condition("select.max_count", "eq", 2),
                _condition("window.option_count_card_uid", "gte", 2, "CSV9.5C_043"),
            ],
        ),
        _fixed_count(
            "artazon.skip-late-budew-only-whiff",
            2,
            "munkidori-transfer",
            0,
            [
                _condition("prompt_kind", "eq", "search"),
                _condition("window.source_uid", "eq", "CSV2C_127"),
                _condition("turn_number", "gte", 3),
                _condition("window.option_count_card_uid", "eq", 0, "CSV10C_007"),
                _condition("window.option_count_card_uid", "eq", 0, "CSV10C_146"),
                _condition("window.option_count_card_uid", "eq", 0, "CSV9.5C_043"),
                _condition("window.option_count_card_uid", "eq", 0, "CSV8C_094"),
            ],
        ),
    ]
    existing_count_ids = {str(rule["rule_id"]) for rule in count_rules}
    if existing_count_ids & {str(rule["rule_id"]) for rule in new_count_rules}:
        raise ValueError("marnie_r54_duplicate_count_rule_id")
    count_rules.extend(new_count_rules)

    payloads["strategy_package.json"] = canonical_json_v1_bytes(manifest)
    payloads["policy/adapter.json"] = canonical_json_v1_bytes(adapter)
    readme = payloads["README.md"].decode("utf-8").rstrip()
    payloads["README.md"] = (
        readme
        + "\n\n## R54 turn-order contract\n\n"
        + "TM Evolution binds exactly two useful live effect targets, prioritizing Snorunt and an Energy-bearing Impidimp while rejecting a zero-Energy Morgrem. "
        + "From the second own turn onward, Poffin, Artazon, and main-bench choices reject a newly deployed Budew; an already deployed Budew may still preserve the intended early stall window. "
        + "Punk Up assigns only the exact Darkness Energy deficit needed to bring each Marnie Pokemon to two, while Froslass, Spikemuth, Munkidori, recovery, and supporter continuity remain pre-attack actions.\n"
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
        raise SystemExit("Marnie R54 package drift")
    adapter = json.loads(handle.payload_bytes("policy/adapter.json"))
    print(f"archive_bytes={len(archive)}")
    print(f"archive_sha256={_sha(archive)}")
    print(f"package_version={handle.package_version}")
    print(f"adapter_version={adapter['adapter_version']}")
    print(f"adapter_rule_count={len(adapter['rules'])}")
    print(f"count_rule_count={len(adapter['count_rules'])}")
    print("execution_trusted=false")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
