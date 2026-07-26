#!/usr/bin/env python3
"""Build the authored N's Zoroark expert-puzzle and shortcut-probe overlays.

The source stays executable so card/deck revisions can regenerate a stable,
reviewable JSON artifact without hand-editing the shared 70-scenario catalog.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
PUZZLE_PATH = ROOT / "data" / "deck_training" / "n_zoroark_high_difficulty_puzzles.json"
PROBE_PATH = ROOT / "data" / "deck_training" / "n_zoroark_shortcut_probes.json"

DARK = "CSVE1C_DAR"
ZORUA = "CSV10C_144"
ZOROARK = "CSV10C_145"
RESHIRAM = "CSV10C_166"
DARUMAKA = "CSV10C_040"
DARMANITAN = "CSV10C_041"
FEZ = "CSV8C_135"
MUNK = "CSV8C_094"
CLEFFA = "CSV4C_044"
CIPHER = "CSV7C_191"
PP_UP = "CSV10C_190"
N_CASTLE = "CSV10C_215"
COUNTER = "CSV6C_114"
BOSS = "CSVH1aC_023"
ENERGY_SWITCH = "CSVH1aC_008"
BLACK_BELT = "CSV9.5C_188"
DEFIANCE = "CSV1C_117"
NIGHT = "CSV8C_183"

COMMON_HAND = [
    ZORUA,
    "CSV3C_123",
    "CSV6C_125",
    "CSV7C_177",
    "CSV8C_183",
    "CSV2C_114",
    "CSV2C_127",
]
ALT_HAND_WITHOUT_NIGHT = [
    ZORUA,
    "CSV3C_123",
    "CSV6C_125",
    "CSV7C_177",
    "CSV1C_111",
    "CSV2C_114",
    "CSV2C_127",
]

REIGNITE = {
    "name": "复燃",
    "text": "造成对手弃牌区中基本能量张数×30伤害。",
    "cost": "CC",
    "damage": "30×",
    "is_vstar_power": False,
}
IMMOLATING = {
    "name": "焚身加农炮",
    "text": "将这只宝可梦身上附着的能量全部放于弃牌区，给对手的1只备战宝可梦也造成90伤害。[备战宝可梦不计算弱点、抗性。]",
    "cost": "RRC",
    "damage": "90",
    "is_vstar_power": False,
}
POWERFUL_RAGE = {
    "name": "力量愤怒",
    "text": "造成这只宝可梦身上放置的伤害指示物数量×20伤害。",
    "cost": "RL",
    "damage": "20×",
    "is_vstar_power": False,
}


def copied_attack(source_index: int, source: str, attack_index: int, attack: dict[str, Any]) -> list[dict[str, Any]]:
    effect_id = {
        DARMANITAN: "26c746f169b803e490f3d0a92ca94412",
        RESHIRAM: "7ee514e3fb601f1f743a3d329b98daab",
    }[source]
    return [{
        "copied_attack": [{
            "source_effect_id": effect_id,
            "source_zone": "bench",
            "attack_index": attack_index,
            "attack": attack,
            "source_slot": {"$slot": {"player": 0, "zone": "bench", "index": source_index}},
        }]
    }]


def damage_row(
    target: str,
    hp: int,
    existing: int,
    damage: int,
    payment: str,
    planned: int = 0,
    modifiers: int = 0,
) -> dict[str, Any]:
    remaining = hp + modifiers - existing - planned
    return {
        "target": target,
        "printed_hp": hp,
        "hp_modifiers": modifiers,
        "existing_damage": existing,
        "planned_counter_damage": planned,
        "remaining_hp": remaining,
        "final_damage": damage,
        "payment": payment,
        "overkill": damage - remaining,
    }


def energy_row(
    checkpoint: str,
    starting: int,
    acquired: int,
    spent: int,
    requirement: int,
) -> dict[str, Any]:
    return {
        "checkpoint": checkpoint,
        "starting_attached": starting,
        "acquired": acquired,
        "spent_or_discarded": spent,
        "attack_requirement": requirement,
        "remaining_for_next_turn": starting + acquired - spent,
    }


def checkpoint(
    order: int,
    source: str,
    kind: str,
    reveals: list[str],
    must_precede: str,
    reason: str,
) -> dict[str, Any]:
    return {
        "order": order,
        "source": source,
        "acquisition_kind": kind,
        "reveals": reveals,
        "must_precede": must_precede,
        "reason": reason,
    }


def bait(
    sid: str,
    suffix: str,
    opening: str,
    good: str,
    trace: list[str],
    resource: str,
    failure: str,
    equation: str,
) -> dict[str, Any]:
    return {
        "id": suffix,
        "opening": opening,
        "looks_good_because": good,
        "gained_information": "、".join(trace),
        "draw_trace": trace,
        "consumed_resource": resource,
        "fails_because": failure,
        "failed_equation": equation,
        "negative_probe_id": f"{sid}_{suffix}",
    }


def roles(player: list[str], opponent: list[str]) -> dict[str, str]:
    result = {"player.active": player[0], "opponent.active": opponent[0]}
    for index, text in enumerate(player[1:]):
        result[f"player.bench.{index}"] = text
    for index, text in enumerate(opponent[1:]):
        result[f"opponent.bench.{index}"] = text
    return result


def puzzle(
    *,
    order: int,
    title: str,
    focus: str,
    objective: str,
    player: dict[str, Any],
    opponent: dict[str, Any],
    opponent_deck_id: int,
    opponent_name: str,
    goal_count: int,
    learning_axis: str,
    combo_id: str,
    combo_steps: list[str],
    keys: dict[str, str],
    checkpoints: list[dict[str, Any]],
    win_sequence: list[str],
    order_pair: list[str],
    baits: list[dict[str, Any]],
    damage_math: list[dict[str, Any]],
    energy_math: list[dict[str, Any]],
    board_roles: dict[str, str],
    proof_steps: list[dict[str, Any]],
    validation: list[str],
    decisions: list[dict[str, str]],
    tactic_ids: list[str] | None = None,
    finisher_card: str | None = None,
    board_history: dict[str, Any] | None = None,
) -> dict[str, Any]:
    sid = f"n_zoroark_{order:02d}"
    hand = player["hand"]
    finisher = finisher_card or list(keys)[-1]
    finisher_order = max(
        cp["order"] for cp in checkpoints if finisher in cp["reveals"]
    )
    reveal_sequence = [
        uid for cp in checkpoints for uid in cp["reveals"]
    ]
    history = board_history or {
        "elapsed_turns": 5,
        "energy_origins": ["双恶能来自此前两回合手贴或题面明确的PP提升剂加速", "关键能量的移动与弃置均由证明步骤记录"],
        "damage_origins": ["双方伤害均来自此前公开攻击，数值为10的整数倍且没有超出最大HP", "题面伤害用于建立唯一斩杀档"],
        "prize_history": ["双方在残局前已按题面奖差交换奖赏", "第一回合与第二回合的取奖顺序共同构成目标"],
    }
    hand_categories = ["Pokemon", "Supporter", "Item", "Tool", "Stadium"]
    return {
        "id": sid,
        "deck_key": "n_zoroark",
        "order": order,
        "revision": 3,
        "title": title,
        "focus": focus,
        "objective": objective,
        "player_deck_id": 800018502,
        "opponent_deck_id": opponent_deck_id,
        "opponent_name": opponent_name,
        "turn_number": 9 + order,
        "first_player_index": 0,
        "turn_limit": 2,
        "last_knockout_turn_against": [-999, -999],
        "tactic_pattern_ids": tactic_ids or [],
        "player": player,
        "opponent": opponent,
        "goal": {"type": "prizes", "count": goal_count},
        "validation_operations": validation,
        "challenge": {
            "difficulty": "expert",
            "payoff_value": max(4, goal_count),
            "decision_points": decisions,
            "cross_turn_dependencies": [
                "第一回合的攻击、弃能、奖差或站位直接决定第二回合是否存在合法终结线",
                "隐藏牌必须按三个以上信息节点依次兑现，不能用一次大抽替代",
            ],
            "resource_tensions": [
                "交易、支援者次数、恶能归属与备战复制源都只有一个正确分配",
                "错误抽牌路线即使看到更多牌，也会失去冻结牌序或终结窗口",
            ],
            "learning_outcome": focus,
        },
        "design_contract": {
            "learning_axis": learning_axis,
            "combo_id": combo_id,
            "deck_identity": "N的索罗亚克以备战区N宝可梦作为招式工具箱，用暗码迷控制牌顶、交易兑现隐藏组件，并通过PP提升剂、城堡和能量移动完成精确交接。",
            "solution_key_inventory_complete": True,
            "combo_contract": {
                "prerequisites": ["双方满场且奖差、伤害与能量均已冻结", "所有解题关键牌初始不在手牌", "至少保留一个合法的备战N宝可梦复制源"],
                "ordered_steps": combo_steps,
                "payoff": objective,
                "reordered_failure": "任一抽牌、能量、撤退、复制源或捕捉步骤提前，都会破坏唯一伤害式或支付式。",
            },
            "engine_cards_in_play": [ZOROARK, RESHIRAM, DARMANITAN],
            "key_cards": list(keys),
            "key_card_roles": keys,
            "initial_hand_decoys": hand[:4],
            "random_hand_profile": {
                "functional_categories": hand_categories,
                "awkward_cards": [hand[0], hand[-1]],
                "redundant_cards": [hand[2], hand[3]],
                "plausible_openings": ["直接攻击", "先用奇树", "先用弗图博士", "先发动交易", "先处理场地", "先回收弃牌"],
            },
            "draw_checkpoints": checkpoints,
            "winning_draw_route": {
                "opening": win_sequence[0],
                "sequence": win_sequence,
                "draw_trace": reveal_sequence,
                "hidden_reveal": [finisher],
                "order_sensitive_pair": order_pair,
                "exact_reason": "正确线逐层清走无关牌、固定牌顶并保留最后的攻击或捕捉窗口；诱导线只要交换两个节点就会少一张牌、一个能量或一个合法目标。",
            },
            "bait_lines": baits,
            "board_capacity": {"player_bench": 5, "opponent_bench": 5},
            "board_roles": board_roles,
            "board_exemptions": [],
            "board_exemption_reasons": {},
            "damage_math": damage_math,
            "energy_math": energy_math,
            "luck_contract": {
                "kind": f"{combo_id}_frozen_hidden_order",
                "deterministic": True,
                "shuffle_points": ["Ciphermaniac controlled shuffle", "Iono lure only"],
                "reveal_sequence": reveal_sequence,
                "same_state_for_all_routes": True,
            },
            "climax_contract": {
                "apparent_dead_end": "手牌看似随机，关键攻击牌、移动牌或捕捉牌都不在手里，场上还存在能量与复制源错位。",
                "comeback_chain": combo_steps,
                "finisher": f"在第{finisher_order}信息节点取得{keys[finisher]}，把此前所有资源转换成精确取奖。",
                "finisher_card": finisher,
                "finisher_checkpoint_order": finisher_order,
                "filtering_checkpoints_before_finisher": min(2, finisher_order - 1),
                "finisher_was_hidden": True,
                "exact_payoff": objective,
            },
            "board_history": history,
            "witness": {
                "player_turns": 2,
                "minimum_meaningful_actions": max(5, len([s for s in proof_steps if s["kind"] != "fixed_rules_ai_turn"])),
                "irreversible_decisions": max(3, len(decisions)),
                "one_turn_shortcut_refuted": True,
            },
        },
        "proof_steps": proof_steps,
    }


def base_player(active: dict[str, Any], bench: list[dict[str, Any]], hand: list[str] | None = None, **extra: Any) -> dict[str, Any]:
    result: dict[str, Any] = {
        "prize_count": 6,
        "active": active,
        "bench": bench,
        "hand": list(hand or COMMON_HAND),
        "discard": [],
        "lost_zone": [],
        "deck_top": [],
    }
    result.update(extra)
    return result


def base_opponent(active: dict[str, Any], bench: list[dict[str, Any]], **extra: Any) -> dict[str, Any]:
    result: dict[str, Any] = {
        "prize_count": 6,
        "active": active,
        "bench": bench,
        "hand": [],
        "discard": [],
        "lost_zone": [],
        "deck_top": [],
    }
    result.update(extra)
    return result


def build_puzzles() -> list[dict[str, Any]]:
    scenarios: list[dict[str, Any]] = []

    # 02 — choose Reignite for a 120 breakpoint, then switch to 90+90 split damage.
    sid = "n_zoroark_02"
    first_reignite = {
        "id": "reignite_120",
        "kind": "attack",
        "label": "按4张基本能量计算复燃120，击倒剩120HP月月熊",
        "attack_index": 0,
        "targets": copied_attack(2, DARMANITAN, 0, REIGNITE),
    }
    second_immolating_targets = copied_attack(1, DARMANITAN, 1, IMMOLATING)
    second_immolating_targets.append({
        "opponent_bench_damage_targets": [
            {"$slot": {"player": 1, "zone": "bench_remaining_hp", "remaining_hp": 80}}
        ]
    })
    proof = [
        first_reignite,
        {"id": "ns_reply", "kind": "fixed_rules_ai_turn", "label": "对手索罗亚克复制力量愤怒反杀首攻者", "require_attack": True},
        {"id": "fez_draw", "kind": "use_ability", "label": "化危为吉取得暗码迷、城堡与杂牌", "source": {"zone": "bench", "index": 2}, "targets": []},
        {
            "id": "cipher_counter",
            "kind": "play_trainer",
            "label": "暗码迷把反击捕捉器与担架置顶",
            "card_uid": CIPHER,
            "targets": [{"top_cards": [
                {"$card": {"player": 0, "zone": "deck", "uid": COUNTER, "occurrence": 0}},
                {"$card": {"player": 0, "zone": "deck", "uid": NIGHT, "occurrence": 0}},
            ]}],
        },
        {"id": "trade_counter", "kind": "use_ability", "label": "自动晋升的第二索罗亚克交易抽到捕捉器与担架", "source": {"zone": "active"}, "targets": [{"discard_card": [{"$card": {"player": 0, "zone": "hand", "uid": ZORUA, "occurrence": 0}}]}]},
        {"id": "counter_zorua", "kind": "play_trainer", "label": "捕捉70HP索罗亚作为前场90目标", "card_uid": COUNTER, "targets": [{"opponent_bench_target": [{"$slot": {"player": 1, "zone": "bench_remaining_hp", "remaining_hp": 70}}]}]},
        {"id": "split_finish", "kind": "attack", "label": "焚身加农炮90+90带走索罗亚与火红不倒翁", "attack_index": 0, "targets": second_immolating_targets},
    ]
    player = base_player(
        {"stack": [ZORUA, ZOROARK], "energy": [DARK, DARK], "damage": 260},
        [
            {"stack": [RESHIRAM]},
            {"stack": [ZORUA, ZOROARK], "energy": [DARK, DARK]},
            {"stack": [DARUMAKA, DARMANITAN]},
            {"stack": [FEZ]},
            {"stack": [MUNK]},
        ],
    )
    player["deck_top"] = ["CSV1C_111", CIPHER, N_CASTLE, DARK, "CSV8C_176", COUNTER, NIGHT]
    opponent = base_opponent(
        {"stack": ["CSV8C_172"], "damage": 140},
        [
            {"stack": [ZORUA, ZOROARK], "energy": [DARK, DARK], "damage": 100},
            {"stack": [ZORUA]},
            {"stack": [DARUMAKA]},
            {"stack": [FEZ]},
            {"stack": [RESHIRAM]},
        ],
        hand=["CSV7C_177", "CSV7C_177", "CSV7C_177", "CSV7C_177", "CSV2C_114", "CSV2C_114"],
        prize_count=5,
        discard=[DARK, DARK, DARK, DARK, "CSV2C_128"],
        deck_top=["CSV1C_111", "CSV2C_127", "CSV10C_215", "CSV8C_183"],
    )
    scenarios.append(puzzle(
        order=2,
        title="工具箱不是四选一：120之后必须换成90+90",
        focus="第一回合根据对手弃牌区4张基本能量复制复燃120；第二回合不能继续对健康主攻手使用复燃，而要捕捉两个一奖基础宝可梦，改复制焚身加农炮完成90+90。特殊能量逆转能量不计入复燃。",
        objective="两回合分别选择复燃与焚身加农炮，累计取得4奖。",
        player=player,
        opponent=opponent,
        opponent_deck_id=800018502,
        opponent_name="N的索罗亚克",
        goal_count=4,
        learning_axis="night_joker_toolbox",
        combo_id="reignite_then_immolating_mode_switch",
        combo_steps=["复燃按4张基本能量造成120", "接受首攻者被反杀并让第二索罗亚克自动晋升", "化危为吉后暗码迷置顶", "战斗场交易兑现捕捉器", "捕捉两只一奖目标", "焚身加农炮90+90"],
        keys={CIPHER: "冻结第二回合牌顶", COUNTER: "抓出70HP前场目标"},
        checkpoints=[
            checkpoint(1, "second-turn natural draw", "natural_draw", ["CSV1C_111"], "Fezandipiti", "移走牌顶杂牌"),
            checkpoint(2, "Fezandipiti ex draw 3", "ability_draw", [CIPHER, N_CASTLE, DARK], "Ciphermaniac", "取得控制器与城堡"),
            checkpoint(3, "Ciphermaniac then Trade", "ability_draw", [COUNTER, NIGHT], "Immolating Cannon", "取得隐藏捕捉器"),
        ],
        win_sequence=["化危为吉先清牌顶", "暗码迷置顶捕捉器", "自动晋升的索罗亚克交易抽取", "捕捉双目标", "焚身加农炮双杀"],
        order_pair=["暗码迷", "交易"],
        baits=[
            bait(sid, "repeat_reignite", "第二回合继续复制复燃", "复燃首回合刚取得2奖", ["120 damage"], "第二次攻击", "健康索罗亚克剩280HP，120只打到160HP", "2+0=2，目标4"),
            bait(sid, "count_reversal_as_basic", "把逆转能量也算作基本能量", "弃牌区视觉上有5张能量", [DARK, "CSV2C_128"], "正确伤害档", "复燃只检查Basic Energy，实际120而不是150", "150预期-120实际=30误差"),
        ],
        damage_math=[
            damage_row("first Bloodmoon Ursaluna ex", 260, 140, 120, "4 Basic Energy x 30"),
            damage_row("second N's Zorua", 70, 0, 90, "Immolating Cannon active"),
            damage_row("second N's Darumaka", 80, 0, 90, "Immolating Cannon bench"),
        ],
        energy_math=[
            energy_row("first Night Joker", 2, 0, 0, 2),
            energy_row("second Night Joker then Immolating discard", 2, 0, 2, 2),
        ],
        board_roles=roles(
            ["260伤首攻索罗亚克负责复燃120并确保被20伤反击击倒", "莱希拉姆保留为另一种复制选项", "双恶第二索罗亚克自动晋升并负责90+90", "达摩狒狒提供两种题眼招式", "吉雉鸡提供第二信息节点", "愿增猿是错误能量归属诱饵"],
            ["剩120HP月月熊验证复燃计数", "100伤索罗亚克反杀首攻者", "70HP索罗亚是第二回合前场目标", "80HP火红不倒翁是后场目标", "吉雉鸡是错误双奖目标", "莱希拉姆保证AI反击招式"],
        ),
        proof_steps=proof,
        validation=[
            "数清弃牌区4张基本恶能与1张特殊逆转能量",
            "复制复燃120精确击倒月月熊",
            "接受对手力量愤怒反杀",
            "化危为吉取得暗码迷与城堡",
            "暗码迷先于交易",
            "确认第二索罗亚克自动晋升并可使用交易",
            "反击捕捉器抓索罗亚",
            "改选焚身加农炮",
            "前场90击倒索罗亚",
            "后场90击倒火红不倒翁",
        ],
        decisions=[
            {"choice": "第一回合复制哪招", "failure": "90无法击倒120HP月月熊"},
            {"choice": "第二回合是否重复复燃", "failure": "120不能击倒健康双奖主攻手"},
            {"choice": "捕捉与备战伤害目标", "failure": "必须同时命中70与80HP两个一奖目标"},
        ],
    ))

    # 03 — the second Darkness Energy is on Munkidori and must be moved.
    sid = "n_zoroark_03"
    proof = [
        {"id": "trade_cipher", "kind": "use_ability", "label": "备战索罗亚克交易取得暗码迷", "source": {"zone": "bench", "index": 1}, "targets": [{"discard_card": [{"$card": {"player": 0, "zone": "hand", "uid": ZORUA, "occurrence": 0}}]}]},
        {"id": "cipher_castle_switch", "kind": "play_trainer", "label": "暗码迷把城堡与能量转移置顶", "card_uid": CIPHER, "targets": [{"top_cards": [
            {"$card": {"player": 0, "zone": "deck", "uid": N_CASTLE, "occurrence": 0}},
            {"$card": {"player": 0, "zone": "deck", "uid": ENERGY_SWITCH, "occurrence": 0}},
        ]}]},
        {"id": "cleffa_draw", "kind": "attack", "label": "皮宝宝抽到城堡并把能量转移留给下回合自然抽", "attack_index": 0, "targets": []},
        {"id": "dragapult_reply", "kind": "fixed_rules_ai_turn", "label": "剩90HP多龙击倒皮宝宝", "require_attack": True},
        {"id": "move_dark", "kind": "play_trainer", "label": "把愿增猿的恶能移动给自动晋升的索罗亚克", "card_uid": ENERGY_SWITCH, "targets": [{"energy_assignment": [{
            "source": {"$card": {"player": 0, "zone": "bench_energy", "index": 1, "uid": DARK, "occurrence": 0}},
            "target": {"$slot": {"player": 0, "zone": "active"}},
        }]}]},
        {"id": "reignite_finish", "kind": "attack", "label": "复燃按对手3张基本能量造成90精确终结", "attack_index": 0, "targets": copied_attack(2, DARMANITAN, 0, REIGNITE)},
    ]
    hand = [ZORUA, "CSV3C_123", "CSV6C_125", "CSV7C_177", "CSV2C_114", "CSV2C_127"]
    player = base_player(
        {"stack": [CLEFFA]},
        [
            {"stack": [RESHIRAM]},
            {"stack": [ZORUA, ZOROARK], "energy": [DARK]},
            {"stack": [MUNK], "energy": [DARK]},
            {"stack": [DARUMAKA, DARMANITAN]},
            {"stack": [FEZ]},
        ],
        hand=hand,
    )
    player["deck_top"] = [CIPHER, "CSV1C_111", "CSV8C_176", N_CASTLE, ENERGY_SWITCH]
    opponent = base_opponent(
        {"stack": ["CSV8C_157", "CSV8C_158", "CSV8C_159"], "energy": ["CSV7C_203"], "damage": 230},
        [
            {"stack": ["CSV8C_157"]},
            {"stack": ["CSV8C_157", "CSV8C_158"]},
            {"stack": [FEZ]},
            {"stack": [MUNK]},
            {"stack": ["CSV9.5C_004"]},
        ],
        hand=["CSV8C_183", "CSV8C_183", "CSV6C_114", "CSV4C_117", "CSV7C_177", "CSV7C_177"],
        discard=["CSVE1C_PSY", "CSVE1C_PSY", "CSVE1C_FIR"],
        deck_top=["CSV8C_183", "CSV8C_183", "CSV6C_114", "CSV1C_113"],
    )
    scenarios.append(puzzle(
        order=3,
        title="恶能在错误的人身上：皮宝宝留下的下一张",
        focus="索罗亚克已有1恶能，第二恶能却附在愿增猿上。第一回合必须用交易取得暗码迷，再让皮宝宝只抽到置顶第一张N的城堡，把第二张能量转移保留成下回合自然抽；皮宝宝倒下后索罗亚克自动晋升，随后必须把愿增猿的恶能移动到战斗场索罗亚克才能复制复燃90。",
        objective="两回合完成牌顶跨回合保留、能量所有者修正与2奖精确击倒。",
        player=player,
        opponent=opponent,
        opponent_deck_id=800018506,
        opponent_name="自爆多龙",
        goal_count=2,
        learning_axis="dark_energy_owner",
        combo_id="cleffa_one_draw_preserves_energy_switch",
        combo_steps=["交易取得暗码迷", "暗码迷依次置顶城堡与能量转移", "控制手牌为6让皮宝宝只抽1", "接受皮宝宝倒下并让索罗亚克晋升", "自然抽能量转移", "移动愿增猿恶能到战斗场", "复燃90"],
        keys={CIPHER: "控制跨回合两张牌顶", N_CASTLE: "控制皮宝宝只抽一张并留下第二张", ENERGY_SWITCH: "把错误所有者的恶能移动到索罗亚克"},
        checkpoints=[
            checkpoint(1, "N's Zoroark ex Trade", "ability_draw", [CIPHER, "CSV1C_111"], "Ciphermaniac", "取得牌顶控制器"),
            checkpoint(2, "Cleffa Grasping Draw to 7", "ability_draw", [N_CASTLE], "opponent turn", "只抽第一张并保留第二张"),
            checkpoint(3, "second-turn natural draw", "natural_draw", [ENERGY_SWITCH], "Night Joker", "取得隐藏的能量所有权修正牌"),
        ],
        win_sequence=["把手牌精确控制为6", "皮宝宝只抽城堡", "自然抽能量转移", "索罗亚克晋升后移动恶能", "复燃攻击"],
        order_pair=["皮宝宝抱抱抽牌", "下回合自然抽"],
        baits=[
            bait(sid, "draw_too_many_with_cleffa", "先打掉一张额外手牌再用皮宝宝", "手牌越少看似抽得越赚", [N_CASTLE, ENERGY_SWITCH, "random-third"], "跨回合自然抽", "能量转移提前进手，下一回合自然抽不再冻结且奇树诱导线可打乱", "冻结节点2张变成未知牌"),
            bait(sid, "leave_dark_on_munk", "不使用能量转移直接撤退", "索罗亚克与愿增猿合计已有2恶能", [DARK, DARK], "能量所有权", "攻击费用只检查攻击者自身附着，索罗亚克仍只有1恶能", "1D<暗夜小丑2D"),
        ],
        damage_math=[damage_row("damaged Dragapult ex", 320, 230, 90, "3 opponent Basic Energy x 30")],
        energy_math=[energy_row("after Energy Switch", 1, 1, 0, 2)],
        board_roles=roles(
            ["皮宝宝控制抽牌数量并承接一奖", "莱希拉姆保留为备用复制源", "一恶索罗亚克在皮宝宝倒下后自动晋升", "愿增猿持有错位恶能", "达摩狒狒提供复燃", "吉雉鸡是大抽诱饵"],
            ["剩90HP多龙既是AI攻击手也是终结目标", "多龙梅西亚吸收铺伤", "多龙奇是错误复燃目标", "吉雉鸡是捕捉诱饵", "愿增猿无恶能不能搬伤", "含羞苞制造物品封锁压力"],
        ),
        proof_steps=proof,
        validation=["交易弃索罗亚", "抽到暗码迷", "城堡在能量转移之前置顶", "皮宝宝只抽1张", "多龙击倒皮宝宝", "索罗亚克自动晋升", "自然抽能量转移", "从愿增猿移动基本恶能到战斗场", "复燃只数3张基本能量"],
        decisions=[
            {"choice": "皮宝宝前保留几张手牌", "failure": "少于6会把能量转移提前抽走并破坏跨回合冻结"},
            {"choice": "移动哪张能量", "failure": "愿增猿的恶能必须去索罗亚克而非莱希拉姆"},
            {"choice": "能量转移的目标区域", "failure": "自动晋升后必须选择战斗场索罗亚克，不能仍按旧备战索引"},
        ],
    ))

    # 04 — keep Reshiram public and move it from Active to Bench before copying.
    sid = "n_zoroark_04"
    proof = [
        {"id": "trade_cipher", "kind": "use_ability", "label": "第一只索罗亚克交易取得暗码迷", "source": {"zone": "bench", "index": 0}, "targets": [{"discard_card": [{"$card": {"player": 0, "zone": "hand", "uid": ZORUA, "occurrence": 0}}]}]},
        {"id": "cipher_castle", "kind": "play_trainer", "label": "暗码迷置顶N的城堡与PP提升剂", "card_uid": CIPHER, "targets": [{"top_cards": [
            {"$card": {"player": 0, "zone": "deck", "uid": N_CASTLE, "occurrence": 0}},
            {"$card": {"player": 0, "zone": "deck", "uid": PP_UP, "occurrence": 0}},
        ]}]},
        {"id": "second_trade", "kind": "use_ability", "label": "第二只索罗亚克交易抽到城堡与PP提升剂", "source": {"zone": "bench", "index": 1}, "targets": [{"discard_card": [{"$card": {"player": 0, "zone": "hand", "uid": "CSV2C_127", "occurrence": 0}}]}]},
        {"id": "castle", "kind": "play_stadium", "label": "放下N的城堡", "card_uid": N_CASTLE, "targets": []},
        {"id": "retreat_reshiram", "kind": "retreat", "label": "让莱希拉姆回到备战区，换入90伤索罗亚克", "target": {"zone": "bench", "index": 0}, "energy_to_discard": []},
        {"id": "first_rage", "kind": "attack", "label": "复制力量愤怒180击倒月月熊", "attack_index": 0, "targets": copied_attack(4, RESHIRAM, 0, POWERFUL_RAGE)},
        {"id": "budew_reply", "kind": "fixed_rules_ai_turn", "label": "含羞苞花粉10把索罗亚克推到100伤", "require_attack": True},
        {"id": "boss_fez", "kind": "play_trainer", "label": "使用奖赏卡中的老大抓剩200HP吉雉鸡", "card_uid": BOSS, "targets": [{"opponent_bench_target": [{"$slot": {"player": 1, "zone": "bench_remaining_hp", "remaining_hp": 200}}]}]},
        {"id": "second_rage", "kind": "attack", "label": "复制力量愤怒200终结吉雉鸡", "attack_index": 0, "targets": copied_attack(4, RESHIRAM, 0, POWERFUL_RAGE)},
    ]
    player = base_player(
        {"stack": [RESHIRAM]},
        [
            {"stack": [ZORUA, ZOROARK], "energy": [DARK, DARK], "damage": 90},
            {"stack": [ZORUA, ZOROARK]},
            {"stack": [DARUMAKA, DARMANITAN]},
            {"stack": [FEZ]},
            {"stack": [MUNK]},
        ],
        prizes=[BOSS],
    )
    player["deck_top"] = [CIPHER, "CSV1C_111", "CSV8C_176", N_CASTLE, PP_UP]
    opponent = base_opponent(
        {"stack": ["CSV8C_172"], "damage": 80},
        [
            {"stack": ["CSV9.5C_004"]},
            {"stack": [FEZ], "damage": 10},
            {"stack": ["CSV8C_157", "CSV8C_158", "CSV8C_159"]},
            {"stack": ["CSV8C_157"]},
            {"stack": [MUNK]},
        ],
        hand=["CSV8C_183", "CSV8C_183", "CSV6C_114", "CSV4C_117", "CSV7C_177", "CSV7C_177"],
        deck_top=["CSV8C_183", "CSV8C_183", "CSV6C_114", "CSV7C_177"],
    )
    scenarios.append(puzzle(
        order=4,
        title="复制源必须在备战区：先把莱希拉姆送回去",
        focus="N的莱希拉姆在战斗场时不能被暗夜小丑复制。必须通过两只索罗亚克的交易链取得N的城堡，零撤退后让莱希拉姆回到备战区；90伤索罗亚克先打180，含羞苞再补10伤，使第二次力量愤怒变成200。",
        objective="保留同一张莱希拉姆作为公开复制源，两回合取得4奖。",
        player=player,
        opponent=opponent,
        opponent_deck_id=800018506,
        opponent_name="自爆多龙",
        goal_count=4,
        learning_axis="bench_identity_preservation",
        combo_id="castle_returns_reshiram_copy_identity",
        combo_steps=["第一交易取得暗码迷", "暗码迷置顶城堡", "第二交易兑现", "城堡零撤退把莱希拉姆送回备战", "力量愤怒180", "奖赏区取得老大", "含羞苞补10伤", "力量愤怒200"],
        keys={CIPHER: "建立双交易牌顶链", N_CASTLE: "把莱希拉姆从前场送回备战", BOSS: "首杀后从奖赏卡取得的最终抓杀牌"},
        checkpoints=[
            checkpoint(1, "first N's Zoroark Trade", "ability_draw", [CIPHER, "CSV1C_111"], "Ciphermaniac", "取得控制器"),
            checkpoint(2, "second N's Zoroark Trade", "ability_draw", [N_CASTLE, PP_UP], "retreat", "兑现城堡"),
            checkpoint(3, "first knockout Prize pickup", "prize_pickup", [BOSS, "implicit-second-prize"], "second attack", "取得隐藏老大"),
        ],
        win_sequence=["两只交易分工", "城堡零撤退", "保留莱希拉姆身份", "首杀取老大", "第二次力量愤怒"],
        order_pair=["N的城堡", "莱希拉姆撤退"],
        baits=[
            bait(sid, "turo_reshiram", "用弗图博士回收前场莱希拉姆", "既能清前场又能保存宝可梦", [RESHIRAM], "唯一复制源", "莱希拉姆进入手牌后暗夜小丑没有力量愤怒可选", "复制源数量1-1=0"),
            bait(sid, "attack_before_source_benched", "不撤退就尝试暗夜小丑", "索罗亚克已带双恶", [ZOROARK, RESHIRAM], "备战身份", "莱希拉姆仍在战斗场，不满足备战区来源条件", "合法力量愤怒选项=0"),
        ],
        damage_math=[
            damage_row("first Bloodmoon Ursaluna ex", 260, 80, 180, "9 damage counters x 20"),
            damage_row("second Fezandipiti ex", 210, 10, 200, "10 damage counters x 20"),
        ],
        energy_math=[energy_row("both Night Joker attacks", 2, 0, 0, 2)],
        board_roles=roles(
            ["前场莱希拉姆必须回到备战区", "90伤双恶索罗亚克是连续攻击手", "第二索罗亚克负责暗码后的抽取", "达摩狒狒提供错误招式选项", "吉雉鸡是无效大抽诱饵", "愿增猿提示不要移动90伤"],
            ["剩180HP月月熊是首个双奖", "含羞苞在AI回合增加10伤", "剩200HP吉雉鸡是第二双奖", "带能多龙是错误老大目标", "多龙梅西亚是一奖诱饵", "无恶愿增猿不能改变伤害线"],
        ),
        proof_steps=proof,
        validation=["第一只交易取得暗码迷", "第二只交易留到暗码之后", "放下N的城堡", "莱希拉姆零撤退", "确认莱希拉姆回到备战区", "力量愤怒180", "从奖赏卡取得老大", "含羞苞造成10伤", "老大抓吉雉鸡", "力量愤怒200"],
        decisions=[
            {"choice": "如何清空莱希拉姆前场", "failure": "弗图博士会删除唯一复制源"},
            {"choice": "两只交易的使用顺序", "failure": "第二只必须留在暗码迷之后"},
            {"choice": "第二回合老大目标", "failure": "健康多龙320无法被200击倒"},
        ],
    ))

    # 05 — rebuild a Zoroark from the discard, then reload both Darkness Energy.
    sid = "n_zoroark_05"
    first_targets = copied_attack(2, DARMANITAN, 1, IMMOLATING)
    first_targets.append({"opponent_bench_damage_targets": [{"$slot": {"player": 1, "zone": "bench", "index": 0}}]})
    proof = [
        {"id": "first_split", "kind": "attack", "label": "焚身加农炮90+90取得两个一奖", "attack_index": 0, "targets": first_targets},
        {"id": "ns_reply", "kind": "fixed_rules_ai_turn", "label": "对手索罗亚克反杀首攻者", "require_attack": True},
        {"id": "fez_draw", "kind": "use_ability", "label": "化危为吉取得担架、PP提升剂与城堡", "source": {"zone": "bench", "index": 2}, "targets": []},
        {"id": "cipher_stack", "kind": "play_trainer", "label": "暗码迷置顶第二张PP提升剂与捕捉器", "card_uid": CIPHER, "targets": [{"top_cards": [
            {"$card": {"player": 0, "zone": "deck", "uid": PP_UP, "occurrence": 0}},
            {"$card": {"player": 0, "zone": "deck", "uid": COUNTER, "occurrence": 0}},
        ]}]},
        {"id": "recover_zoroark", "kind": "play_trainer", "label": "夜间担架回收弃牌区索罗亚克ex", "card_uid": NIGHT, "targets": [{"night_stretcher_choice": [{"$card": {"player": 0, "zone": "discard", "uid": ZOROARK, "occurrence": 0}}]}]},
        {"id": "evolve_backup", "kind": "evolve", "label": "把60伤索罗亚进化为第二索罗亚克", "card_uid": ZOROARK, "target": {"zone": "bench", "index": 0}},
        {"id": "trade_stack", "kind": "use_ability", "label": "新索罗亚克交易抽到第二PP与捕捉器", "source": {"zone": "bench", "index": 0}, "targets": [{"discard_card": [{"$card": {"player": 0, "zone": "hand", "uid": ZORUA, "occurrence": 0}}]}]},
        {"id": "pp_one", "kind": "play_trainer", "label": "第一PP回收一恶", "card_uid": PP_UP, "targets": [{"ns_pp_up_assignment": [{"source": {"$card": {"player": 0, "zone": "discard", "uid": DARK, "occurrence": 0}}, "target": {"$slot": {"player": 0, "zone": "bench", "index": 0}}}]}]},
        {"id": "pp_two", "kind": "play_trainer", "label": "第二PP回收另一恶", "card_uid": PP_UP, "targets": [{"ns_pp_up_assignment": [{"source": {"$card": {"player": 0, "zone": "discard", "uid": DARK, "occurrence": 0}}, "target": {"$slot": {"player": 0, "zone": "bench", "index": 0}}}]}]},
        {"id": "castle", "kind": "play_stadium", "label": "N的城堡让莱希拉姆零撤退", "card_uid": N_CASTLE, "targets": []},
        {"id": "retreat", "kind": "retreat", "label": "换入重建完成的索罗亚克", "target": {"zone": "bench", "index": 0}, "energy_to_discard": []},
        {"id": "counter_bloodmoon", "kind": "play_trainer", "label": "捕捉剩120HP月月熊", "card_uid": COUNTER, "targets": [{"opponent_bench_target": [{"$slot": {"player": 1, "zone": "bench_remaining_hp", "remaining_hp": 120}}]}]},
        {"id": "rage_120", "kind": "attack", "label": "60伤索罗亚克复制力量愤怒120终结", "attack_index": 0, "targets": copied_attack(3, RESHIRAM, 0, POWERFUL_RAGE)},
    ]
    player = base_player(
        {"stack": [ZORUA, ZOROARK], "energy": [DARK, DARK], "damage": 80},
        [
            {"stack": [RESHIRAM]},
            {"stack": [ZORUA], "damage": 60},
            {"stack": [DARUMAKA, DARMANITAN]},
            {"stack": [FEZ]},
            {"stack": [MUNK]},
        ],
        hand=ALT_HAND_WITHOUT_NIGHT,
        discard=[ZOROARK],
    )
    player["deck_top"] = [CIPHER, NIGHT, PP_UP, N_CASTLE, DARK, PP_UP, COUNTER]
    opponent = base_opponent(
        {"stack": [ZORUA]},
        [
            {"stack": [DARUMAKA]},
            {"stack": [ZORUA, ZOROARK], "energy": [DARK, DARK], "damage": 100},
            {"stack": ["CSV8C_172"], "damage": 140},
            {"stack": [RESHIRAM]},
            {"stack": [FEZ]},
        ],
        hand=["CSV7C_177", "CSV7C_177", "CSV7C_177", "CSV7C_177", "CSV2C_114", "CSV2C_114"],
        prize_count=5,
        discard=[DARK, DARK, DARK, DARK],
        deck_top=["CSV1C_111", "CSV2C_127", N_CASTLE, "CSV8C_183"],
    )
    scenarios.append(puzzle(
        order=5,
        title="第一只倒下后：担架重建、双PP再点火",
        focus="首攻索罗亚克用焚身加农炮双杀并弃双恶，随后被反杀。第二回合不能只找能量，必须先用夜间担架回收索罗亚克ex、进化60伤索罗亚，再让新出现的交易兑现暗码迷置顶的第二张PP提升剂与反击捕捉器。",
        objective="从弃牌区重建第二条索罗亚克线并在两回合取得4奖。",
        player=player,
        opponent=opponent,
        opponent_deck_id=800018502,
        opponent_name="N的索罗亚克",
        goal_count=4,
        learning_axis="zoroark_rebuild",
        combo_id="night_stretcher_evolve_double_pp_rebuild",
        combo_steps=["焚身加农炮双杀并弃双恶", "首攻者被反杀", "化危为吉取得担架/PP/城堡", "暗码迷置顶第二PP与捕捉器", "担架回收索罗亚克ex", "进化60伤索罗亚", "新交易兑现", "双PP回能", "城堡交接", "力量愤怒120"],
        keys={CIPHER: "冻结重建末端两张牌", NIGHT: "从弃牌区取回索罗亚克ex", PP_UP: "两张副本重装双恶", N_CASTLE: "莱希拉姆零撤退", COUNTER: "抓出120HP双奖目标"},
        checkpoints=[
            checkpoint(1, "second-turn natural draw", "natural_draw", [CIPHER], "Fezandipiti", "先取得暗码迷"),
            checkpoint(2, "Fezandipiti ex draw 3", "ability_draw", [NIGHT, PP_UP, N_CASTLE], "Ciphermaniac", "取得重建前半段"),
            checkpoint(3, "new Zoroark Trade after Ciphermaniac", "ability_draw", [PP_UP, COUNTER], "double PP Up", "取得重建后半段与终结捕捉器"),
        ],
        win_sequence=["担架回收进化件", "进化后才获得新的交易", "交易抽第二PP与捕捉器", "双PP回能", "城堡交接", "力量愤怒终结"],
        order_pair=["夜间担架进化", "新索罗亚克交易"],
        baits=[
            bait(sid, "recover_dark_instead", "夜间担架回收基本恶能", "能量是眼前最明显的缺口", [DARK], "唯一索罗亚克进化件", "索罗亚仍不能进化，PP提升剂也没有合法第二攻击手", "攻击手数量0"),
            bait(sid, "pp_before_evolve", "先使用PP提升剂", "弃牌区已有双恶", [PP_UP, DARK], "备战N进化目标", "索罗亚可收能但还没有暗夜小丑与交易，后续抽不到第二PP和捕捉器", "有效交易节点0"),
        ],
        damage_math=[
            damage_row("first N's Zorua", 70, 0, 90, "Immolating Cannon active"),
            damage_row("first N's Darumaka", 80, 0, 90, "Immolating Cannon bench"),
            damage_row("second Bloodmoon Ursaluna ex", 260, 140, 120, "6 damage counters x 20"),
        ],
        energy_math=[
            energy_row("first Immolating Cannon", 2, 0, 2, 2),
            energy_row("rebuilt Night Joker", 0, 2, 0, 2),
        ],
        board_roles=roles(
            ["双恶首攻者负责90+90并把恶能送弃牌区", "莱希拉姆承接昏厥和提供力量愤怒", "60伤索罗亚是待重建核心", "达摩狒狒提供首攻", "吉雉鸡抽取担架与PP", "愿增猿是回收错误目标诱饵"],
            ["70HP索罗亚是首个一奖", "80HP火红不倒翁是后场一奖", "100伤索罗亚克反杀首攻者", "剩120HP月月熊是终结双奖", "莱希拉姆支撑AI反击", "吉雉鸡是错误捕捉目标"],
        ),
        proof_steps=proof,
        validation=["焚身加农炮90+90", "双恶进入弃牌区", "首攻者被反杀", "化危为吉三张", "暗码迷置顶", "担架选索罗亚克而非恶能", "进化60伤索罗亚", "新交易抽2", "两次PP分别附能", "城堡撤退", "反击捕捉器", "力量愤怒120"],
        decisions=[
            {"choice": "担架回收宝可梦还是能量", "failure": "必须回收唯一进化件"},
            {"choice": "何时使用新索罗亚克交易", "failure": "必须在暗码迷置顶后"},
            {"choice": "PP提升剂附给谁", "failure": "两张都必须给新索罗亚克"},
        ],
        tactic_ids=["n_castle_pp_booster_handoff"],
    ))

    # 06 — Ciphermaniac + two Trades turns a random hand into Counter + Band.
    sid = "n_zoroark_06"
    first = copied_attack(0, RESHIRAM, 0, POWERFUL_RAGE)
    second = copied_attack(1, DARMANITAN, 1, IMMOLATING)
    second.append({"opponent_bench_damage_targets": [{"$slot": {"player": 1, "zone": "bench_remaining_hp", "remaining_hp": 70}}]})
    proof = [
        {"id": "first_trade", "kind": "use_ability", "label": "主攻索罗亚克交易取得暗码迷", "source": {"zone": "active"}, "targets": [{"discard_card": [{"$card": {"player": 0, "zone": "hand", "uid": ZORUA, "occurrence": 0}}]}]},
        {"id": "cipher_band_counter", "kind": "play_trainer", "label": "暗码迷置顶不服输头带与反击捕捉器", "card_uid": CIPHER, "targets": [{"top_cards": [
            {"$card": {"player": 0, "zone": "deck", "uid": DEFIANCE, "occurrence": 0}},
            {"$card": {"player": 0, "zone": "deck", "uid": COUNTER, "occurrence": 0}},
        ]}]},
        {"id": "second_trade", "kind": "use_ability", "label": "第二索罗亚克交易兑现头带与捕捉器", "source": {"zone": "bench", "index": 1}, "targets": [{"discard_card": [{"$card": {"player": 0, "zone": "hand", "uid": "CSV2C_127", "occurrence": 0}}]}]},
        {"id": "attach_band", "kind": "attach_tool", "label": "给主攻索罗亚克附不服输头带", "card_uid": DEFIANCE, "target": {"zone": "active"}},
        {"id": "counter_fez", "kind": "play_trainer", "label": "反击捕捉器抓健康吉雉鸡", "card_uid": COUNTER, "targets": [{"opponent_bench_target": [{"$slot": {"player": 1, "zone": "bench_remaining_hp", "remaining_hp": 210}}]}]},
        {"id": "rage_210", "kind": "attack", "label": "力量愤怒180加头带30精确击倒吉雉鸡", "attack_index": 0, "targets": first},
        {"id": "budew_reply", "kind": "fixed_rules_ai_turn", "label": "含羞苞攻击10并封锁物品", "require_attack": True},
        {"id": "immolating_finish", "kind": "attack", "label": "物品封锁下改复制焚身加农炮，90+90双杀", "attack_index": 0, "targets": second},
    ]
    player = base_player(
        {"stack": [ZORUA, ZOROARK], "energy": [DARK, DARK], "damage": 90},
        [
            {"stack": [RESHIRAM]},
            {"stack": [ZORUA, ZOROARK]},
            {"stack": [DARUMAKA, DARMANITAN]},
            {"stack": [FEZ]},
            {"stack": [MUNK]},
        ],
    )
    player["deck_top"] = [CIPHER, "CSV1C_111", "CSV8C_176", DEFIANCE, COUNTER]
    opponent = base_opponent(
        {"stack": ["CSV9.5C_004"]},
        [
            {"stack": [FEZ]},
            {"stack": ["CSV9.5C_004"]},
            {"stack": ["CSV8C_157"]},
            {"stack": ["CSV8C_157", "CSV8C_158", "CSV8C_159"], "damage": 90},
            {"stack": [MUNK]},
        ],
        prize_count=5,
        hand=["CSV8C_183", "CSV8C_183", "CSV6C_114", "CSV4C_117", "CSV7C_177", "CSV7C_177"],
        deck_top=["CSV8C_183", "CSV8C_183", "CSV6C_114", "CSV1C_113"],
    )
    scenarios.append(puzzle(
        order=6,
        title="两次交易各有工作：先找暗码，再兑现双组件",
        focus="随机手牌里没有捕捉器和伤害补正。主攻索罗亚克的交易只能负责找到暗码迷，第二只索罗亚克的交易必须保留到暗码迷把不服输头带与反击捕捉器置顶之后；首回合210精确双奖，物品封锁后改用焚身加农炮收两个一奖。",
        objective="用暗码迷与两次独立交易完成四奖路线。",
        player=player,
        opponent=opponent,
        opponent_deck_id=800018506,
        opponent_name="自爆多龙",
        goal_count=4,
        learning_axis="cipher_trade_stack",
        combo_id="two_trades_cipher_band_counter",
        combo_steps=["第一交易取得暗码迷", "暗码迷置顶头带与捕捉器", "第二交易兑现双组件", "头带加成力量愤怒210", "承受花粉10", "封物品下切换焚身加农炮", "90+90双杀"],
        keys={CIPHER: "把随机手牌变成可控牌顶", DEFIANCE: "奖差下补足30伤", COUNTER: "抓出健康210HP吉雉鸡"},
        checkpoints=[
            checkpoint(1, "active Zoroark Trade", "ability_draw", [CIPHER, "CSV1C_111"], "Ciphermaniac", "取得暗码迷"),
            checkpoint(2, "Ciphermaniac full-deck selection", "effect_reveal", [DEFIANCE, COUNTER], "second Trade", "指定双组件"),
            checkpoint(3, "bench Zoroark Trade", "ability_draw", [DEFIANCE, COUNTER], "first attack", "兑现隐藏捕捉器"),
        ],
        win_sequence=["第一交易只找暗码迷", "第二交易留到置顶后", "头带与捕捉器同时到手", "力量愤怒210", "焚身加农炮90+90"],
        order_pair=["第一只交易", "第二只交易"],
        baits=[
            bait(sid, "use_both_trades_early", "暗码迷前连续发动两次交易", "一次抽4张看起来最强", [CIPHER, "CSV1C_111", "CSV8C_176", "random"], "第二交易节点", "暗码迷置顶后没有可用交易抽取头带与捕捉器", "置顶2-可用抽牌0=2张滞留"),
            bait(sid, "counter_without_band", "只拿捕捉器不拿头带", "捕捉器直接提供双奖目标", [COUNTER], "30伤补正", "力量愤怒180打健康吉雉鸡210会残30", "210-180=30"),
        ],
        damage_math=[
            damage_row("first Fezandipiti ex", 210, 0, 210, "9 counters x20 + Defiance Band30"),
            damage_row("second Budew", 30, 0, 90, "Immolating Cannon active"),
            damage_row("second Dreepy", 70, 0, 90, "Immolating Cannon bench"),
        ],
        energy_math=[
            energy_row("first Night Joker", 2, 0, 0, 2),
            energy_row("second Immolating Cannon", 2, 0, 2, 2),
        ],
        board_roles=roles(
            ["90伤双恶主攻承担两次不同复制招式", "莱希拉姆提供首攻力量愤怒", "第二索罗亚克保留交易节点", "达摩狒狒提供封物品后的90+90", "吉雉鸡是错误大抽", "愿增猿提示奖差但不搬伤"],
            ["含羞苞是反击捕捉器前的前场掩护", "健康吉雉鸡是210精确目标", "第二含羞苞承接AI回合与第二攻", "70HP多龙梅西亚是后场90目标", "230HP多龙是错误复制目标", "愿增猿无恶不能改线"],
        ),
        proof_steps=proof,
        validation=["第一交易只使用一次", "暗码迷选头带与捕捉器", "第二交易抽2", "头带附主攻", "捕捉健康吉雉鸡", "力量愤怒180+30", "含羞苞攻击10", "物品封锁下不依赖物品", "改复制焚身加农炮", "90+90双杀"],
        decisions=[
            {"choice": "哪只索罗亚克先交易", "failure": "必须保留第二节点兑现置顶"},
            {"choice": "暗码迷选哪两张", "failure": "捕捉器和头带缺一都会少2奖"},
            {"choice": "第二回合复制哪招", "failure": "力量愤怒200只能处理一个目标，无法达到4奖"},
        ],
    ))

    # 07 — Powerful Rage reads Zoroark's damage, including the opponent's 40 reply.
    sid = "n_zoroark_07"
    proof = [
        {"id": "first_trade", "kind": "use_ability", "label": "第一索罗亚克交易取得暗码迷", "source": {"zone": "bench", "index": 0}, "targets": [{"discard_card": [{"$card": {"player": 0, "zone": "hand", "uid": ZORUA, "occurrence": 0}}]}]},
        {"id": "cipher_castle", "kind": "play_trainer", "label": "暗码迷置顶N的城堡与PP提升剂", "card_uid": CIPHER, "targets": [{"top_cards": [
            {"$card": {"player": 0, "zone": "deck", "uid": N_CASTLE, "occurrence": 0}},
            {"$card": {"player": 0, "zone": "deck", "uid": PP_UP, "occurrence": 0}},
        ]}]},
        {"id": "second_trade", "kind": "use_ability", "label": "第二索罗亚克交易兑现城堡", "source": {"zone": "bench", "index": 1}, "targets": [{"discard_card": [{"$card": {"player": 0, "zone": "hand", "uid": "CSV2C_127", "occurrence": 0}}]}]},
        {"id": "castle", "kind": "play_stadium", "label": "放下N的城堡", "card_uid": N_CASTLE, "targets": []},
        {"id": "retreat", "kind": "retreat", "label": "莱希拉姆回到备战区，换入90伤索罗亚克", "target": {"zone": "bench", "index": 0}, "energy_to_discard": []},
        {"id": "rage_180", "kind": "attack", "label": "力量愤怒读取索罗亚克90伤，造成180", "attack_index": 0, "targets": copied_attack(4, RESHIRAM, 0, POWERFUL_RAGE)},
        {"id": "ns_reply", "kind": "fixed_rules_ai_turn", "label": "20伤对手索罗亚克复制力量愤怒40，把我方推到130伤", "require_attack": True},
        {"id": "rage_260", "kind": "attack", "label": "第二次力量愤怒读取130伤，造成260反杀", "attack_index": 0, "targets": copied_attack(4, RESHIRAM, 0, POWERFUL_RAGE)},
    ]
    player = base_player(
        {"stack": [RESHIRAM]},
        [
            {"stack": [ZORUA, ZOROARK], "energy": [DARK, DARK], "damage": 90},
            {"stack": [ZORUA, ZOROARK]},
            {"stack": [DARUMAKA, DARMANITAN]},
            {"stack": [FEZ]},
            {"stack": [MUNK]},
        ],
    )
    player["deck_top"] = [CIPHER, "CSV1C_111", "CSV8C_176", N_CASTLE, PP_UP]
    opponent = base_opponent(
        {"stack": ["CSV8C_172"], "damage": 80},
        [
            {"stack": [ZORUA, ZOROARK], "energy": [DARK, DARK], "damage": 20},
            {"stack": [RESHIRAM]},
            {"stack": [DARUMAKA]},
            {"stack": [FEZ]},
            {"stack": [MUNK]},
        ],
        hand=["CSV7C_177", "CSV7C_177", "CSV7C_177", "CSV7C_177", "CSV2C_114", "CSV2C_114"],
        discard=[DARK, DARK, DARK, DARK],
        deck_top=["CSV1C_111", "CSV2C_127", N_CASTLE, NIGHT],
    )
    scenarios.append(puzzle(
        order=7,
        title="愤怒看的是谁：90伤、40反击、再变260",
        focus="暗夜小丑复制力量愤怒时读取攻击者N的索罗亚克ex自身伤害，而不是备战莱希拉姆。90伤先造成180；对手20伤索罗亚克复制同招只打40，却把我方累积到130伤，第二次力量愤怒因此变成260并反杀。",
        objective="读懂复制攻击的伤害归属，用对手的低伤反击把第二次攻击推到260并取得4奖。",
        player=player,
        opponent=opponent,
        opponent_deck_id=800018502,
        opponent_name="N的索罗亚克",
        goal_count=4,
        learning_axis="reshiram_damage_copy",
        combo_id="powerful_rage_attacker_damage_recalculation",
        combo_steps=["双交易取得城堡", "莱希拉姆回备战", "90伤索罗亚克打180", "承受对手40反击", "重新读取130伤", "力量愤怒260反杀"],
        keys={CIPHER: "控制城堡牌顶", N_CASTLE: "把莱希拉姆变回合法复制源"},
        checkpoints=[
            checkpoint(1, "first Zoroark Trade", "ability_draw", [CIPHER, "CSV1C_111"], "Ciphermaniac", "取得控制器"),
            checkpoint(2, "Ciphermaniac selection", "effect_reveal", [N_CASTLE, PP_UP], "second Trade", "确认城堡在牌顶"),
            checkpoint(3, "second Zoroark Trade", "ability_draw", [N_CASTLE, PP_UP], "retreat", "取得隐藏城堡"),
        ],
        win_sequence=["两次交易拆分", "城堡让莱希拉姆回备战", "按90伤算180", "接受40反击", "按130伤重算260"],
        order_pair=["莱希拉姆回到备战区", "第一次力量愤怒"],
        baits=[
            bait(sid, "use_reshiram_damage", "按备战莱希拉姆0伤计算", "招式文字印在莱希拉姆上", [RESHIRAM, "0 counters"], "攻击者归属", "复制招式的attacker仍是索罗亚克，实际读取90伤", "错误预览0，实际180"),
            bait(sid, "munk_before_second_rage", "第二回合先用愿增猿搬30伤", "搬伤能削弱对手并治疗主攻", ["move 30"], "自身伤害倍率", "索罗亚克从130降到100伤，力量愤怒从260降到200，打不倒260HP对手", "260-200=60"),
        ],
        damage_math=[
            damage_row("first Bloodmoon Ursaluna ex", 260, 80, 180, "player Zoroark 9 counters x20"),
            damage_row("opponent N's Zoroark ex", 280, 20, 260, "player Zoroark 13 counters x20"),
        ],
        energy_math=[energy_row("two Powerful Rage copies", 2, 0, 0, 2)],
        board_roles=roles(
            ["莱希拉姆必须先回备战", "90伤双恶索罗亚克是倍率主体", "第二索罗亚克负责兑现城堡", "达摩狒狒提供错误复制选项", "吉雉鸡是无效抽牌诱饵", "愿增猿是降低自身倍率的陷阱"],
            ["剩180HP月月熊验证90伤倍率", "20伤索罗亚克以40反击并成为260HP目标", "莱希拉姆让AI合法复制力量愤怒", "火红不倒翁是错误一奖目标", "吉雉鸡是错误双奖目标", "愿增猿没有恶能不能改线"],
        ),
        proof_steps=proof,
        validation=["第一交易取得暗码迷", "第二交易留到置顶后", "城堡零撤退", "莱希拉姆进入备战区", "读取索罗亚克90伤", "首攻180", "对手20伤只造成40", "我方累积130伤", "第二攻260", "累计4奖"],
        decisions=[
            {"choice": "力量愤怒读取谁的伤害", "failure": "按莱希拉姆计算会完全误判"},
            {"choice": "是否让40反击发生", "failure": "没有额外40伤，第二次只有180"},
            {"choice": "第二回合是否搬伤治疗", "failure": "治疗会把260伤害降到200"},
        ],
    ))

    # 08 — count only Basic Energy in the opponent's discard pile.
    sid = "n_zoroark_08"
    proof = [
        {"id": "first_trade", "kind": "use_ability", "label": "第一索罗亚克交易取得暗码迷", "source": {"zone": "bench", "index": 0}, "targets": [{"discard_card": [{"$card": {"player": 0, "zone": "hand", "uid": ZORUA, "occurrence": 0}}]}]},
        {"id": "cipher_castle", "kind": "play_trainer", "label": "暗码迷置顶N的城堡与PP提升剂", "card_uid": CIPHER, "targets": [{"top_cards": [
            {"$card": {"player": 0, "zone": "deck", "uid": N_CASTLE, "occurrence": 0}},
            {"$card": {"player": 0, "zone": "deck", "uid": PP_UP, "occurrence": 0}},
        ]}]},
        {"id": "second_trade", "kind": "use_ability", "label": "第二索罗亚克交易取得城堡", "source": {"zone": "bench", "index": 1}, "targets": [{"discard_card": [{"$card": {"player": 0, "zone": "hand", "uid": "CSV2C_127", "occurrence": 0}}]}]},
        {"id": "castle", "kind": "play_stadium", "label": "N的城堡零撤退", "card_uid": N_CASTLE, "targets": []},
        {"id": "retreat", "kind": "retreat", "label": "换入首攻索罗亚克并保留达摩狒狒", "target": {"zone": "bench", "index": 0}, "energy_to_discard": []},
        {"id": "reignite_120_first", "kind": "attack", "label": "只数4张基本恶能，复燃120击倒月月熊", "attack_index": 0, "targets": copied_attack(1, DARMANITAN, 0, REIGNITE)},
        {"id": "ns_reply", "kind": "fixed_rules_ai_turn", "label": "160伤对手索罗亚克反杀首攻者", "require_attack": True},
        {"id": "reignite_120_second", "kind": "attack", "label": "第二索罗亚克再次复燃120击倒剩120HP对手", "attack_index": 0, "targets": copied_attack(0, DARMANITAN, 0, REIGNITE)},
    ]
    player = base_player(
        {"stack": [RESHIRAM]},
        [
            {"stack": [ZORUA, ZOROARK], "energy": [DARK, DARK], "damage": 80},
            {"stack": [ZORUA, ZOROARK], "energy": [DARK, DARK]},
            {"stack": [DARUMAKA, DARMANITAN]},
            {"stack": [FEZ]},
            {"stack": [MUNK]},
        ],
    )
    player["deck_top"] = [CIPHER, "CSV1C_111", "CSV8C_176", N_CASTLE, PP_UP]
    opponent = base_opponent(
        {"stack": ["CSV8C_172"], "damage": 140},
        [
            {"stack": [ZORUA, ZOROARK], "energy": [DARK, DARK], "damage": 160},
            {"stack": [RESHIRAM]},
            {"stack": [DARUMAKA]},
            {"stack": [FEZ]},
            {"stack": [MUNK]},
        ],
        hand=["CSV7C_177", "CSV7C_177", "CSV7C_177", "CSV7C_177", "CSV2C_114", "CSV2C_114"],
        discard=[DARK, DARK, DARK, DARK, "CSV2C_128"],
        deck_top=["CSV1C_111", "CSV2C_127", N_CASTLE, NIGHT],
    )
    scenarios.append(puzzle(
        order=8,
        title="五张能量只有四张算数：复燃的类型审计",
        focus="对手弃牌区有4张基本恶能与1张逆转能量。复燃不是数所有能量，而是严格造成4×30=120。第一回合击倒剩120HP月月熊；对手160伤索罗亚克反杀后自身也正好剩120HP，第二索罗亚克再用同一计数完成双奖。",
        objective="两回合两次按基本能量类型精确计算复燃120，取得4奖。",
        player=player,
        opponent=opponent,
        opponent_deck_id=800018502,
        opponent_name="N的索罗亚克",
        goal_count=4,
        learning_axis="darmanitan_discard_count",
        combo_id="reignite_basic_not_special_energy_count",
        combo_steps=["双交易取得城堡", "莱希拉姆零撤退", "审计弃牌区能量类型", "第一次复燃120", "接受高伤索罗亚克反杀", "第二攻击手接棒", "第二次复燃120"],
        keys={CIPHER: "控制城堡牌顶", N_CASTLE: "零撤退保留达摩狒狒复制源"},
        checkpoints=[
            checkpoint(1, "first Zoroark Trade", "ability_draw", [CIPHER, "CSV1C_111"], "Ciphermaniac", "取得控制器"),
            checkpoint(2, "Ciphermaniac selection", "effect_reveal", [N_CASTLE, PP_UP], "second Trade", "确认城堡"),
            checkpoint(3, "second Zoroark Trade", "ability_draw", [N_CASTLE, PP_UP], "first Reignite", "取得隐藏城堡"),
        ],
        win_sequence=["先把达摩狒狒留在备战", "城堡交接", "只数基本恶能", "两次复燃120"],
        order_pair=["能量类型审计", "选择复燃目标"],
        baits=[
            bait(sid, "count_reversal", "把逆转能量计入复燃", "弃牌区共5张能量", [DARK, "CSV2C_128"], "类型过滤", "逆转能量是Special Energy，实际不计数", "5×30预期150，实际4×30=120"),
            bait(sid, "choose_150_target", "捕捉剩150HP目标", "错误计数看起来正好斩杀", ["150 HP"], "捕捉窗口", "实际120会残30并失去两回合四奖", "150-120=30"),
        ],
        damage_math=[
            damage_row("first Bloodmoon Ursaluna ex", 260, 140, 120, "4 Basic Energy x30"),
            damage_row("opponent N's Zoroark ex", 280, 160, 120, "4 Basic Energy x30"),
        ],
        energy_math=[
            energy_row("first Reignite", 2, 0, 0, 2),
            energy_row("second Reignite", 2, 0, 0, 2),
        ],
        board_roles=roles(
            ["莱希拉姆是零撤退前场", "80伤首攻索罗亚克", "双恶第二索罗亚克接棒", "达摩狒狒是两回合共同复制源", "吉雉鸡是错误抽牌路线", "愿增猿不能改变弃牌计数"],
            ["剩120HP月月熊是第一计数靶", "剩120HP高伤索罗亚克是第二靶兼反击手", "莱希拉姆支撑AI高伤反击", "火红不倒翁是错误一奖", "吉雉鸡是150误算诱饵", "愿增猿无恶能不能改线"],
        ),
        proof_steps=proof,
        validation=["双交易链", "N的城堡", "达摩狒狒留在备战", "识别4张基本能量", "排除逆转能量", "首攻120", "接受反杀", "第二攻击手自动接棒", "第二攻120", "累计4奖"],
        decisions=[
            {"choice": "弃牌区能量如何分类", "failure": "特殊能量不能计入"},
            {"choice": "首攻目标HP档", "failure": "只能选择120而非150"},
            {"choice": "是否保留达摩狒狒", "failure": "第二回合仍需同一复制源"},
        ],
    ))

    # 09 — pre-bank one Energy with PP Up, take Castle + second PP from Prizes.
    sid = "n_zoroark_09"
    proof = [
        {"id": "active_trade", "kind": "use_ability", "label": "首攻索罗亚克在备战区交易取得暗码迷", "source": {"zone": "bench", "index": 0}, "targets": [{"discard_card": [{"$card": {"player": 0, "zone": "hand", "uid": ZORUA, "occurrence": 0}}]}]},
        {"id": "cipher_dark_pp", "kind": "play_trainer", "label": "暗码迷置顶基本恶能与PP提升剂", "card_uid": CIPHER, "targets": [{"top_cards": [
            {"$card": {"player": 0, "zone": "deck", "uid": N_CASTLE, "occurrence": 0}},
            {"$card": {"player": 0, "zone": "deck", "uid": PP_UP, "occurrence": 0}},
        ]}]},
        {"id": "backup_trade", "kind": "use_ability", "label": "第二索罗亚克交易抽到N的城堡与PP提升剂", "source": {"zone": "bench", "index": 1}, "targets": [{"discard_card": [{"$card": {"player": 0, "zone": "hand", "uid": "CSV2C_127", "occurrence": 0}}]}]},
        {"id": "prebank_pp", "kind": "play_trainer", "label": "第一PP把弃牌区恶能预存给备战索罗亚克", "card_uid": PP_UP, "targets": [{"ns_pp_up_assignment": [{"source": {"$card": {"player": 0, "zone": "discard", "uid": DARK, "occurrence": 0}}, "target": {"$slot": {"player": 0, "zone": "bench", "index": 1}}}]}]},
        {"id": "castle", "kind": "play_stadium", "label": "N的城堡让前场莱希拉姆零撤退", "card_uid": N_CASTLE, "targets": []},
        {"id": "first_handoff", "kind": "retreat", "label": "莱希拉姆换入双恶首攻索罗亚克", "target": {"zone": "bench", "index": 0}, "energy_to_discard": []},
        {"id": "first_rage", "kind": "attack", "label": "60伤首攻者力量愤怒120击倒月月熊", "attack_index": 0, "targets": copied_attack(4, RESHIRAM, 0, POWERFUL_RAGE)},
        {"id": "ns_reply", "kind": "fixed_rules_ai_turn", "label": "160伤对手索罗亚克反杀首攻者", "require_attack": True},
        {"id": "energy_switch_finish", "kind": "play_trainer", "label": "奖赏卡能量转移把愿增猿恶能送给自动晋升的第二索罗亚克", "card_uid": ENERGY_SWITCH, "targets": [{"energy_assignment": [{
            "source": {"$card": {"player": 0, "zone": "bench_energy", "index": 2, "uid": DARK, "occurrence": 0}},
            "target": {"$slot": {"player": 0, "zone": "active"}}
        }]}]},
        {"id": "second_rage", "kind": "attack", "label": "第二索罗亚克力量愤怒120击倒剩120HP对手", "attack_index": 0, "targets": copied_attack(3, RESHIRAM, 0, POWERFUL_RAGE)},
    ]
    player = base_player(
        {"stack": [RESHIRAM]},
        [
            {"stack": [ZORUA, ZOROARK], "energy": [DARK, DARK], "damage": 60},
            {"stack": [ZORUA, ZOROARK], "damage": 60},
            {"stack": [DARUMAKA, DARMANITAN]},
            {"stack": [FEZ]},
            {"stack": [MUNK], "energy": [DARK]},
        ],
        prizes=[ENERGY_SWITCH],
        discard=[DARK],
    )
    player["deck_top"] = [CIPHER, "CSV1C_111", "CSV8C_176", N_CASTLE, PP_UP]
    opponent = base_opponent(
        {"stack": ["CSV8C_172"], "damage": 140},
        [
            {"stack": [ZORUA, ZOROARK], "energy": [DARK, DARK], "damage": 160},
            {"stack": [RESHIRAM]},
            {"stack": [DARUMAKA]},
            {"stack": [FEZ]},
            {"stack": [MUNK]},
        ],
        hand=["CSV7C_177", "CSV7C_177", "CSV7C_177", "CSV7C_177", "CSV2C_114", "CSV2C_114"],
        discard=[DARK, DARK, DARK, DARK],
        deck_top=["CSV1C_111", "CSV2C_127", N_CASTLE, NIGHT],
    )
    scenarios.append(puzzle(
        order=9,
        title="一张先存、一张奖区接力：PP提升剂与城堡交棒",
        focus="莱希拉姆在前场，两只索罗亚克分别是双恶首攻者与0恶接班人。暗码迷→第二交易取得N的城堡和PP提升剂：PP先给接班人预存1恶，城堡让莱希拉姆零撤退交出首攻位。首杀从奖赏区拿到能量转移；首攻者倒下后，接班索罗亚克自动晋升，再把愿增猿的恶能移入战斗场补足第二恶。",
        objective="用PP提升剂预存、N的城堡第一次交棒与奖赏区能量转移第二次交棒，完成两次120双奖攻击。",
        player=player,
        opponent=opponent,
        opponent_deck_id=800018502,
        opponent_name="N的索罗亚克",
        goal_count=4,
        learning_axis="pp_castle_handoff",
        combo_id="pp_prebank_prize_castle_handoff",
        combo_steps=["首攻者在备战交易取得暗码迷", "暗码迷置顶城堡与PP", "第二交易兑现", "PP预存给接班索罗亚克", "城堡让莱希拉姆零撤退", "首攻120取双奖", "首攻者被反杀", "奖赏区能量转移把愿增猿恶能送给自动晋升者", "第二次力量愤怒120"],
        keys={CIPHER: "冻结城堡与PP", N_CASTLE: "让莱希拉姆零撤退完成第一次交棒", PP_UP: "给接班攻击手预存第一恶", ENERGY_SWITCH: "首杀后从奖赏区取得并补足第二恶"},
        checkpoints=[
            checkpoint(1, "active Zoroark Trade", "ability_draw", [CIPHER, "CSV1C_111"], "Ciphermaniac", "取得控制器"),
            checkpoint(2, "Ciphermaniac selection", "effect_reveal", [N_CASTLE, PP_UP], "bench Trade", "指定城堡和预存牌"),
            checkpoint(3, "bench Zoroark Trade", "ability_draw", [N_CASTLE, PP_UP], "first attack", "兑现第一阶段"),
            checkpoint(4, "first knockout Prize pickup", "prize_pickup", [ENERGY_SWITCH, "implicit-second-prize"], "second attack", "取得隐藏的能量所有权修正牌"),
        ],
        win_sequence=["PP给接班人预存第一恶", "城堡让莱希拉姆交出首攻位", "首杀拿能量转移", "接受首攻者倒下", "从愿增猿移动第二恶", "接班索罗亚克完成攻击"],
        order_pair=["PP提升剂预存", "奖赏区能量转移补足"],
        baits=[
            bait(sid, "pp_to_active", "第一张PP也贴给首攻索罗亚克", "当前攻击手最缺能量", [PP_UP, DARK], "备战预存", "首攻者倒下时三张恶能全部进弃牌区，第二攻击手仍0能", "第二攻击手0D<2D"),
            bait(sid, "skip_prize_castle", "首杀后不拿城堡奖赏位", "另一奖赏牌可能提供更多手牌", [PP_UP, "other prize"], "零撤退交棒", "莱希拉姆前场没有能量且撤退费无法支付", "合法换入次数0"),
        ],
        damage_math=[
            damage_row("first Bloodmoon Ursaluna ex", 260, 140, 120, "6 counters x20"),
            damage_row("opponent N's Zoroark ex", 280, 160, 120, "6 counters x20"),
        ],
        energy_math=[
            energy_row("first Night Joker", 2, 0, 0, 2),
            energy_row("backup after first PP pre-bank", 0, 1, 0, 1),
            energy_row("backup after Energy Switch", 1, 1, 0, 2),
        ],
        board_roles=roles(
            ["1恶60伤首攻者等待手贴", "莱希拉姆承接昏厥并提供力量愤怒", "0恶60伤备战攻击手接受两段PP", "达摩狒狒是错误复制路线", "吉雉鸡是大抽诱饵", "愿增猿会诱导把恶能留在辅助位"],
            ["剩120HP月月熊是第一双奖", "剩120HP高伤索罗亚克是反击手与第二双奖", "莱希拉姆支撑AI反击", "火红不倒翁是一奖诱饵", "吉雉鸡是错误目标", "愿增猿无恶能不能改线"],
        ),
        proof_steps=proof,
        validation=["首攻交易", "暗码迷置顶恶能与PP", "备战交易", "恶能手贴首攻", "PP贴备战", "力量愤怒120首杀", "从奖区取得PP与城堡", "接受首攻者被反杀", "第二PP贴备战", "城堡零撤退", "第二攻120"],
        decisions=[
            {"choice": "第一张PP附给谁", "failure": "必须预存给备战而非当前主攻"},
            {"choice": "首杀取哪两张奖赏", "failure": "第二PP与城堡缺一不可"},
            {"choice": "城堡何时使用", "failure": "必须等莱希拉姆承接昏厥后完成交棒"},
        ],
        tactic_ids=["n_castle_pp_booster_handoff"],
        finisher_card=ENERGY_SWITCH,
    ))

    # 10 — Reignite 120 + Defiance Band 30 + Black Belt 40 = exact 190.
    sid = "n_zoroark_10"
    first_targets = copied_attack(2, DARMANITAN, 1, IMMOLATING)
    first_targets.append({"opponent_bench_damage_targets": [{"$slot": {"player": 1, "zone": "bench", "index": 0}}]})
    proof = [
        {"id": "first_split", "kind": "attack", "label": "焚身加农炮90+90先取两个一奖并弃双恶", "attack_index": 0, "targets": first_targets},
        {"id": "ns_reply", "kind": "fixed_rules_ai_turn", "label": "对手索罗亚克反杀首攻者，使我方重新落后", "require_attack": True},
        {"id": "fez_draw", "kind": "use_ability", "label": "化危为吉取得不服输头带、反击捕捉器与杂牌", "source": {"zone": "bench", "index": 2}, "targets": []},
        {"id": "trade_black_belt", "kind": "use_ability", "label": "自动晋升的第二索罗亚克交易抽到空手道王", "source": {"zone": "active"}, "targets": [{"discard_card": [{"$card": {"player": 0, "zone": "hand", "uid": ZORUA, "occurrence": 0}}]}]},
        {"id": "attach_band", "kind": "attach_tool", "label": "给战斗场第二索罗亚克附不服输头带", "card_uid": DEFIANCE, "target": {"zone": "active"}},
        {"id": "black_belt", "kind": "play_trainer", "label": "使用空手道王的修炼，对ex再加40", "card_uid": BLACK_BELT, "targets": []},
        {"id": "counter_bloodmoon", "kind": "play_trainer", "label": "反击捕捉器抓出剩190HP月月熊", "card_uid": COUNTER, "targets": [{"opponent_bench_target": [{"$slot": {"player": 1, "zone": "bench_remaining_hp", "remaining_hp": 190}}]}]},
        {"id": "reignite_190", "kind": "attack", "label": "复燃120+头带30+空手道王40=190精确终结", "attack_index": 0, "targets": copied_attack(1, DARMANITAN, 0, REIGNITE)},
    ]
    player = base_player(
        {"stack": [ZORUA, ZOROARK], "energy": [DARK, DARK], "damage": 80},
        [
            {"stack": [RESHIRAM]},
            {"stack": [ZORUA, ZOROARK], "energy": [DARK, DARK]},
            {"stack": [DARUMAKA, DARMANITAN]},
            {"stack": [FEZ]},
            {"stack": [MUNK]},
        ],
    )
    player["deck_top"] = ["CSV1C_111", DEFIANCE, COUNTER, N_CASTLE, BLACK_BELT, "CSV8C_176"]
    opponent = base_opponent(
        {"stack": [ZORUA]},
        [
            {"stack": [DARUMAKA]},
            {"stack": [ZORUA, ZOROARK], "energy": [DARK, DARK], "damage": 100},
            {"stack": ["CSV8C_172"], "damage": 70},
            {"stack": [RESHIRAM]},
            {"stack": [FEZ]},
        ],
        prize_count=5,
        hand=["CSV7C_177", "CSV7C_177", "CSV7C_177", "CSV7C_177", "CSV2C_114", "CSV2C_114"],
        discard=[DARK, DARK, DARK, DARK],
        deck_top=["CSV1C_111", "CSV2C_127", N_CASTLE, NIGHT],
    )
    scenarios.append(puzzle(
        order=10,
        title="三个加数缺一不可：120+30+40=190",
        focus="第一回合焚身加农炮双杀后，对手反杀双奖索罗亚克，使我方再次落后。不服输头带因此重新生效；第二回合先用化危为吉拿到头带与捕捉器，再用自动晋升索罗亚克的交易抽到空手道王。复燃120、头带30、空手道王40合计190精确击倒月月熊。",
        objective="主动经营奖差并叠加复燃、头带和空手道王三个伤害层，累计取得4奖。",
        player=player,
        opponent=opponent,
        opponent_deck_id=800018502,
        opponent_name="N的索罗亚克",
        goal_count=4,
        learning_axis="karate_defiance_stack",
        combo_id="reignite_defiance_black_belt_exact_190",
        combo_steps=["焚身加农炮先取2奖", "对手反杀2奖使我方落后", "化危为吉取得头带与捕捉器", "交易取得空手道王", "附头带", "使用空手道王", "捕捉190HP宝可梦ex", "复燃120+30+40"],
        keys={BLACK_BELT: "交易第三节点取得、对前场宝可梦ex加40", DEFIANCE: "落后时加30", COUNTER: "抓出190HP终结目标"},
        checkpoints=[
            checkpoint(1, "second-turn natural draw", "natural_draw", ["CSV1C_111"], "Fezandipiti", "清走牌顶杂牌"),
            checkpoint(2, "Fezandipiti ex draw 3", "ability_draw", [DEFIANCE, COUNTER, N_CASTLE], "Trade", "取得头带与捕捉器"),
            checkpoint(3, "active N's Zoroark ex Trade", "ability_draw", [BLACK_BELT, "CSV8C_176"], "final attack", "取得隐藏空手道王"),
        ],
        win_sequence=["先让对手反杀恢复落后", "化危为吉取得头带与捕捉器", "交易取得空手道王", "三层伤害相加", "复燃190"],
        order_pair=["对手反杀恢复奖差", "附不服输头带"],
        baits=[
            bait(sid, "band_while_ahead", "第一回合就把不服输头带当作30伤", "头带文字提供固定伤害印象", [DEFIANCE], "奖差条件", "我方首攻取2奖后暂时领先，头带直到被反杀才重新生效", "领先时加成0"),
            bait(sid, "skip_black_belt", "只用复燃与不服输头带", "120+30已经达到常见150档", [DARK, DEFIANCE], "空手道王40", "目标剩190HP，150会残40", "190-(120+30)=40"),
        ],
        damage_math=[
            damage_row("first N's Zorua", 70, 0, 90, "Immolating Cannon active"),
            damage_row("first N's Darumaka", 80, 0, 90, "Immolating Cannon bench"),
            damage_row("final Bloodmoon Ursaluna ex", 260, 70, 190, "Reignite120 + Defiance Band30 + Black Belt40"),
        ],
        energy_math=[
            energy_row("first Immolating Cannon", 2, 0, 2, 2),
            energy_row("second Reignite", 2, 0, 0, 2),
        ],
        board_roles=roles(
            ["双恶首攻者先用90+90并送出2奖", "莱希拉姆承接反杀并通过城堡撤退", "双恶第二索罗亚克叠加三层伤害", "达摩狒狒提供两回合招式", "吉雉鸡提供暗码迷与空手道王", "愿增猿是错误搬伤捷径"],
            ["70HP索罗亚是首个一奖", "80HP火红不倒翁是后场一奖", "100伤索罗亚克反杀双奖主攻", "剩190HP月月熊是三层精确目标", "莱希拉姆支撑AI反击", "吉雉鸡是错误捕捉目标"],
        ),
        proof_steps=proof,
        validation=["焚身加农炮90+90", "首攻双恶弃置", "对手反杀双奖", "确认我方重新落后", "化危为吉抽3", "暗码迷置顶", "交易抽头带与捕捉器", "附不服输头带", "使用空手道王", "捕捉月月熊", "城堡零撤退", "复燃120+30+40"],
        decisions=[
            {"choice": "何时判断头带生效", "failure": "必须在对手反杀后重新检查奖差"},
            {"choice": "支援者使用谁", "failure": "空手道王是不可替代的40伤层"},
            {"choice": "捕捉哪个目标", "failure": "只有剩190HP宝可梦ex同时吃到三层并被击倒"},
        ],
        tactic_ids=["n_zoroark_karate_defiance_ex_counter"],
        finisher_card=BLACK_BELT,
    ))

    return scenarios


def build_probes(scenarios: list[dict[str, Any]]) -> dict[str, Any]:
    result: dict[str, list[dict[str, Any]]] = {}
    for scenario in scenarios:
        sid = scenario["id"]
        proof = scenario["proof_steps"]
        # Two clean refutations: stop after a legal but strategically losing
        # Supporter line. These are intentionally short; the detailed lure
        # equations remain in design_contract.bait_lines.
        first_attack_index = next(
            (index for index, step in enumerate(proof) if step["kind"] == "attack"),
            -1,
        )
        fixed_index = next(
            (index for index, step in enumerate(proof) if step["kind"] == "fixed_rules_ai_turn"),
            -1,
        )
        if first_attack_index > 0:
            prefix_a = proof[:first_attack_index]
            prefix_b = proof[:first_attack_index]
        elif fixed_index > 0:
            prefix_a = proof[: fixed_index + 1]
            prefix_b = proof[: fixed_index + 1]
        else:
            prefix_a = []
            prefix_b = []
        hand = scenario["player"]["hand"]
        iono_uid = "CSV3C_123"
        turo_uid = "CSV6C_125"
        # Ensure the detour is legal in the exact state: when a Supporter was
        # already used in the prefix, fall back to ending before the goal.
        supporter_used = any(
            step["kind"] == "play_trainer" and step.get("card_uid") in {CIPHER, BLACK_BELT}
            for step in prefix_a
        )
        if not supporter_used and iono_uid in hand:
            steps_a = [*prefix_a, {"id": "lure_iono", "kind": "play_trainer", "label": "诱导线：奇树重置冻结资源", "card_uid": iono_uid, "targets": []}, {"id": "deadline", "kind": "end_turn", "label": "期限内未达到目标"}]
        else:
            steps_a = [*prefix_a, {"id": "deadline", "kind": "end_turn", "label": "诱导线提前结束，冻结组件无法兑现"}]
        if not supporter_used and turo_uid in hand:
            steps_b = [*prefix_b, {"id": "lure_turo", "kind": "play_trainer", "label": "诱导线：弗图博士移走当前场位", "card_uid": turo_uid, "targets": [{"self_pokemon": [{"$slot": {"player": 0, "zone": "active"}}]}]}, {"id": "deadline", "kind": "end_turn", "label": "复制源或攻击手已丢失"}]
        else:
            steps_b = [*prefix_b, {"id": "deadline", "kind": "end_turn", "label": "诱导线保留牌却错过本回合攻击"}]
        lure_ids = [
            entry["negative_probe_id"]
            for entry in scenario["design_contract"]["bait_lines"]
        ]
        result[sid] = [
            {
                "id": lure_ids[0],
                "category": scenario["design_contract"]["bait_lines"][0]["id"],
                "description": scenario["design_contract"]["bait_lines"][0]["fails_because"],
                "proof_steps": steps_a,
            },
            {
                "id": lure_ids[1],
                "category": scenario["design_contract"]["bait_lines"][1]["id"],
                "description": scenario["design_contract"]["bait_lines"][1]["fails_because"],
                "proof_steps": steps_b,
            },
        ]
    return {"format_version": 1, "scenarios": result}


def main() -> None:
    scenarios = build_puzzles()
    PUZZLE_PATH.write_text(
        json.dumps(
            {"format_version": 1, "scenario_revision": 3, "scenarios": scenarios},
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )
    PROBE_PATH.write_text(
        json.dumps(build_probes(scenarios), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {len(scenarios)} puzzles to {PUZZLE_PATH}")
    print(f"wrote shortcut probes to {PROBE_PATH}")


if __name__ == "__main__":
    main()
