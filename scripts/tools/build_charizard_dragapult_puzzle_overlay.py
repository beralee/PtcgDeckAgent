#!/usr/bin/env python3
"""Build the authored 18.0 Bomb Charizard expert-puzzle overlays."""

from __future__ import annotations

import copy
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
PUZZLE_PATH = ROOT / "data/deck_training/charizard_dragapult_high_difficulty_puzzles.json"
PROBE_PATH = ROOT / "data/deck_training/charizard_dragapult_shortcut_probes.json"
TEMPLATE_PATH = ROOT / "data/deck_training/n_zoroark_high_difficulty_puzzles.json"

FIRE = "CSVE1C_FIR"
CHARMANDER = "151C_004"
CHARIZARD = "CSV5C_075"
DUSKULL = "CSV8C_081"
DUSCLOPS = "CSV8C_082"
DUSKNOIR = "CSV8C_083"
PIDGEY = "151C_016"
PIDGEOT = "CSV4C_101"
FEZ = "CSV8C_135"
TATSUGIRI = "CSV8C_160"
CHIYU = "CSV5C_022"
KLEFKI = "CSV1C_060"
RESEARCH = "CSV1C_121"
ARVEN = "CSV1C_123"
IONO = "CSV3C_123"
BOSS = "CSVH1aC_023"
TURO = "CSV6C_125"
BRIAR = "CSV9C_202"
ULTRA = "CSV1C_112"
POFFIN = "CSV7C_177"
CANDY = "CSVH1C_045"
COUNTER = "CSV6C_114"
ROD = "CSV1C_109"
TM_EVO = "CSV5C_119"
BAND = "CSV1C_117"
MESAGOZA = "CSV1C_126"
ARTAZON = "CSV2C_127"
JET = "CSV4C_129"

DRAGAPULT = "CSV8C_159"
DRakloak = "CSV8C_158"
DREEPY = "CSV8C_157"
BUDEW = "CSV9.5C_004"
MUNK = "CSV8C_094"
PSY = "CSVE1C_PSY"
DARK = "CSVE1C_DAR"
ZORUA = "CSV10C_144"
ZOROARK = "CSV10C_145"
RESHIRAM = "CSV10C_166"
DARUMAKA = "CSV10C_040"
DARMANITAN = "CSV10C_041"
CLEFFA = "CSV4C_044"
HARD_BELT = "CSV2C_114"

COMMON_HAND = [RESEARCH, IONO, POFFIN, ULTRA, TURO, TM_EVO, MESAGOZA]


def card(player: int, zone: str, uid: str, occurrence: int = 0, index: int | None = None) -> dict[str, Any]:
    selector: dict[str, Any] = {"player": player, "zone": zone, "uid": uid, "occurrence": occurrence}
    if index is not None:
        selector["index"] = index
    return {"$card": selector}


def slot(player: int, zone: str, index: int | None = None, remaining_hp: int | None = None) -> dict[str, Any]:
    selector: dict[str, Any] = {"player": player, "zone": zone}
    if index is not None:
        selector["index"] = index
    if remaining_hp is not None:
        selector["remaining_hp"] = remaining_hp
    return {"$slot": selector}


def checkpoint(order: int, source: str, kind: str, reveals: list[str], before: str, reason: str) -> dict[str, Any]:
    return {
        "order": order,
        "source": source,
        "acquisition_kind": kind,
        "reveals": reveals,
        "must_precede": before,
        "reason": reason,
    }


def damage(target: str, hp: int, existing: int, planned: int, final: int, payment: str) -> dict[str, Any]:
    remaining = hp - existing - planned
    return {
        "target": target,
        "printed_hp": hp,
        "hp_modifiers": 0,
        "existing_damage": existing,
        "planned_counter_damage": planned,
        "remaining_hp": remaining,
        "final_damage": final,
        "payment": payment,
        "overkill": final - remaining,
    }


def energy(checkpoint_name: str, starting: int, acquired: int, spent: int, requirement: int) -> dict[str, Any]:
    return {
        "checkpoint": checkpoint_name,
        "starting_attached": starting,
        "acquired": acquired,
        "spent_or_discarded": spent,
        "attack_requirement": requirement,
        "remaining_for_next_turn": starting + acquired - spent,
    }


def base_player(*, active: dict[str, Any], bench: list[dict[str, Any]], hand: list[str] | None = None,
                deck_top: list[str] | None = None, discard: list[str] | None = None,
                prize_count: int = 5) -> dict[str, Any]:
    return {
        "prize_count": prize_count,
        "active": active,
        "bench": bench,
        "hand": list(hand or COMMON_HAND),
        "discard": list(discard or []),
        "lost_zone": [],
        "deck_top": list(deck_top or []),
    }


def base_opponent(*, active_damage: int = 70, active: dict[str, Any] | None = None,
                  bench: list[dict[str, Any]] | None = None, prize_count: int = 4) -> dict[str, Any]:
    return {
        "prize_count": prize_count,
        "active": active or {"stack": [FEZ], "damage": active_damage},
        "bench": bench or [
            {"stack": [ZORUA, ZOROARK], "energy": [DARK, DARK], "damage": 60},
            {"stack": [ZORUA, ZOROARK], "tool": HARD_BELT},
            {"stack": [RESHIRAM]},
            {"stack": [MUNK]},
            {"stack": [CLEFFA]},
        ],
        "hand": ["CSV9C_198", IONO, BOSS, TURO, "CSV7C_191", POFFIN],
        "discard": [],
        "lost_zone": [],
        "deck_top": ["CSV10C_190", COUNTER, "CSV8C_183", "CSV10C_215"],
    }


def common_roles(player_active: str, self_ko: str, special: str) -> dict[str, str]:
    return {
        "player.active": player_active,
        "player.bench.0": "小火龙是首攻者倒下后的自动晋升位，随后用糖果进化为第二攻击手。",
        "player.bench.1": "大比鸟ex提供每回合唯一一次任意牌检索，错误检索会洗掉牌序。",
        "player.bench.2": self_ko,
        "player.bench.3": "吉雉鸡ex在前一回合我方宝可梦昏厥后提供第一层隐藏三抽。",
        "player.bench.4": special,
        "opponent.active": "剩140HP的吉雉鸡ex要求古玉鱼满足复仇条件才能精确击倒。",
        "opponent.bench.0": "60伤索罗亚克ex会自动晋升，复制力量愤怒120反杀古玉鱼。",
        "opponent.bench.1": "满血坚硬束带索罗亚克是第二回合必须捕捉的300伤阈值目标。",
        "opponent.bench.2": "莱希拉姆提供AI反杀所需的力量愤怒。",
        "opponent.bench.3": "愿增猿是错误单奖目标。",
        "opponent.bench.4": "皮宝宝是错误零撤退目标。",
    }


def standard_proof(*, dusk_kind: str = "dusknoir", counter: bool = False,
                   unlock_klefki: bool = False, infernal_split: bool = False,
                   tatsugiri_scan: bool = False, rod_rebuild: bool = False) -> list[dict[str, Any]]:
    steps: list[dict[str, Any]] = []
    if unlock_klefki:
        steps.append({
            "id": "unlock_klefki", "kind": "retreat", "label": "先让钥圈儿退回备战区，解除己方基础特性封锁",
            "target": {"zone": "bench", "index": 0},
            "energy_to_discard": [card(0, "active_energy", JET)],
        })
    if tatsugiri_scan:
        steps.append({
            "id": "fez_hidden_three", "kind": "use_ability", "label": "化危为吉先抽走糖果、喷火龙与头带",
            "source": {"zone": "bench", "index": 4},
            "targets": [],
        })
        steps.append({
            "id": "tatsugiri_briar", "kind": "use_ability", "label": "揽客从顶6的三张支援者中保留白蕾雅",
            "source": {"zone": "active"},
            "targets": [{"look_top_pick": [card(0, "deck", BRIAR)]}],
        })
        steps.append({
            "id": "retreat_tatsugiri", "kind": "retreat", "label": "弃火能撤退米立龙，换入复仇古玉鱼",
            "target": {"zone": "bench", "index": 0},
            "energy_to_discard": [card(0, "active_energy", JET)],
        })
    if not tatsugiri_scan:
        steps.append({
            "id": "fez_hidden_three", "kind": "use_ability", "label": "化危为吉抽出隐藏的糖果、喷火龙与第三组件",
            "source": {"zone": "bench", "index": 3},
            "targets": [],
        })
    if not tatsugiri_scan:
        steps.append({
            "id": "quick_search_finisher", "kind": "use_ability", "label": "音速搜索取得仍藏在牌库里的终结组件",
            "source": {"zone": "bench", "index": 1},
            "targets": [{"search_cards": [card(0, "deck", BAND if infernal_split else BRIAR)]}],
        })
    if infernal_split:
        steps.extend([
            {
                "id": "candy_first_charizard", "kind": "play_trainer", "label": "糖果进化备战小火龙，开启烈炎支配",
                "card_uid": CANDY,
                "targets": [{"stage2_card": [card(0, "hand", CHARIZARD)], "target_pokemon": [slot(0, "bench", 0)]}],
            },
            {
                "id": "split_infernal_reign", "kind": "use_ability", "label": "烈炎支配把2火给古玉鱼、1火给喷火龙",
                "source": {"zone": "bench", "index": 0},
                "targets": [{"energy_assignments": [
                    {"source": card(0, "deck", FIRE, 0), "target": slot(0, "active")},
                    {"source": card(0, "deck", FIRE, 1), "target": slot(0, "active")},
                    {"source": card(0, "deck", FIRE, 2), "target": slot(0, "bench", 0)},
                ]}],
            },
        ])
    if counter:
        steps.append({
            "id": "offer_prize", "kind": "self_ko", "label": "咒怨炸弹主动送1奖并把黑夜魔灵调到30HP",
            "ability_source": {"zone": "bench", "index": 2},
            "damage_target": {"zone": "bench", "index": 0},
        })
    if counter:
        steps.append({
            "id": "counter_bloodmoon", "kind": "play_trainer", "label": "送奖后反击捕捉器才合法，抓出剩140HP月月熊",
            "card_uid": COUNTER, "target_player": 1, "target": {"zone": "bench_remaining_hp", "remaining_hp": 50},
            "context_key": "opponent_bench_target",
        })
    steps.extend([
        {"id": "chi_yu_revenge", "kind": "attack", "label": "嫉妒业火140击倒首只双奖目标", "attack_index": 1, "targets": []},
        {"id": "zoroark_reply", "kind": "fixed_rules_ai_turn", "label": "60伤索罗亚克晋升并复制力量愤怒120反杀古玉鱼", "require_attack": True},
    ])
    if not counter:
        if not rod_rebuild:
            steps.append({
                "id": "second_quick_counter", "kind": "use_ability", "label": "第二回合音速搜索取得反击捕捉器",
                "source": {"zone": "bench", "index": 0},
                "targets": [{"search_cards": [card(0, "deck", COUNTER)]}],
            })
        steps.append({
            "id": "offer_prize", "kind": "self_ko", "label": "对手拿到第3奖后再咒怨炸弹，把现役索罗亚克调到90HP并推进白蕾雅2奖窗口",
            "ability_source": {"zone": "bench", "index": 1},
            "damage_target": {"zone": "active"},
        })
        if not rod_rebuild:
            steps.append({
                "id": "counter_fresh_zoroark", "kind": "play_trainer", "label": "反击捕捉器避开90HP诱饵，抓出满血坚硬束带索罗亚克",
                "card_uid": COUNTER, "target_player": 1,
                "target": {"zone": "bench_remaining_hp", "remaining_hp": 280},
                "context_key": "opponent_bench_target",
            })
    if rod_rebuild:
        steps.extend([
            {
                "id": "quick_search_rod", "kind": "use_ability", "label": "第二回合音速搜索取得厉害钓竿",
                "source": {"zone": "bench", "index": 0},
                "targets": [{"search_cards": [card(0, "deck", ROD)]}],
            },
            {
                "id": "rod_charizard_fire", "kind": "play_trainer", "label": "钓竿把喷火龙与两张火能放回牌库",
                "card_uid": ROD,
                "targets": [{"cards_to_return": [
                    card(0, "discard", CHARIZARD), card(0, "discard", FIRE, 0), card(0, "discard", FIRE, 1),
                ]}],
            },
            {
                "id": "ultra_recovered_charizard", "kind": "play_trainer", "label": "高级球弃两张诱饵，检索刚回填的喷火龙",
                "card_uid": ULTRA,
                "targets": [{"discard_cards": [card(0, "hand", RESEARCH), card(0, "hand", IONO)],
                             "search_pokemon": [card(0, "deck", CHARIZARD)]}],
            },
        ])
    if not infernal_split:
        steps.extend([
            {
                "id": "candy_second_charizard", "kind": "play_trainer", "label": "糖果把自动晋升的小火龙进化成喷火龙ex",
                "card_uid": CANDY,
                "targets": [{"stage2_card": [card(0, "hand", CHARIZARD)], "target_pokemon": [slot(0, "active")]}],
            },
            {
                "id": "infernal_reign_two", "kind": "use_ability", "label": "烈炎支配从牌库精确附着2张火能",
                "source": {"zone": "active"},
                "targets": [{"energy_assignments": [
                    {"source": card(0, "deck", FIRE, 0), "target": slot(0, "active")},
                    {"source": card(0, "deck", FIRE, 1), "target": slot(0, "active")},
                ]}],
            },
        ])
    if not counter:
        steps.append({"id": "attach_defiance", "kind": "attach_tool", "label": "奖差落后时给喷火龙装不服输头带", "card_uid": BAND, "target": {"zone": "active"}})
    steps.extend([
        {"id": "play_briar", "kind": "play_trainer", "label": "确认对手恰好剩2奖后使用白蕾雅", "card_uid": BRIAR, "targets": []},
        {"id": "burning_darkness", "kind": "attack", "label": "燃烧黑暗完成坚硬束带目标并取得3奖", "attack_index": 0, "targets": []},
    ])
    return steps


def make_scenario(order: int, *, title: str, focus: str, axis: str, combo_id: str,
                  mode: str = "standard") -> dict[str, Any]:
    template_doc = json.loads(TEMPLATE_PATH.read_text(encoding="utf-8"))
    template = copy.deepcopy(template_doc["scenarios"][0])
    sid = f"charizard_dragapult_{order:02d}"
    turn = 20 + order
    dusk_kind = "dusclops" if mode == "dusclops" else "dusknoir"
    counter = mode == "counter"
    unlock = mode == "klefki"
    split = mode == "infernal_split"
    tatsu = mode == "tatsugiri"
    rod = mode == "rod"

    if tatsu:
        player = base_player(
            active={"stack": [TATSUGIRI], "energy": [JET]},
            bench=[
                {"stack": [CHIYU], "energy": [FIRE, FIRE]},
                {"stack": [CHARMANDER]},
                {"stack": [PIDGEY, PIDGEOT]},
                {"stack": [DUSKULL, DUSCLOPS, DUSKNOIR]},
                {"stack": [FEZ]},
            ],
            deck_top=[CANDY, CHARIZARD, BAND, RESEARCH, BRIAR, IONO],
        )
    elif unlock:
        player = base_player(
            active={"stack": [KLEFKI], "energy": [JET]},
            bench=[
                {"stack": [CHIYU], "energy": [FIRE, FIRE]},
                {"stack": [CHARMANDER]},
                {"stack": [PIDGEY, PIDGEOT]},
                {"stack": [DUSKULL, DUSCLOPS, DUSKNOIR]},
                {"stack": [FEZ]},
            ],
            deck_top=[CANDY, CHARIZARD, BAND, BRIAR],
        )
    else:
        dusk_stack = [DUSKULL, DUSCLOPS] if dusk_kind == "dusclops" else [DUSKULL, DUSCLOPS, DUSKNOIR]
        player = base_player(
            active={"stack": [CHIYU], "energy": [] if split else [FIRE, FIRE]},
            bench=[
                {"stack": [CHARMANDER], "energy": [FIRE] if split else []},
                {"stack": [PIDGEY, PIDGEOT]},
                {"stack": dusk_stack},
                {"stack": [FEZ]},
                {"stack": [KLEFKI]},
            ],
            deck_top=[CANDY, CHARIZARD, (BRIAR if split else (COUNTER if counter else BAND)), (BAND if split else BRIAR), FIRE],
            discard=[CHARIZARD, FIRE, FIRE] if rod else [],
        )
    if rod:
        player["deck_top"] = [CANDY, BAND, ULTRA, BRIAR]
        player["hand"] = [RESEARCH, IONO, POFFIN, TURO, TM_EVO, MESAGOZA, CHARMANDER]
    else:
        required_fire_in_deck = 4 if split else 3
        player["deck_top"].extend([FIRE] * (required_fire_in_deck - player["deck_top"].count(FIRE)))
    if counter:
        opponent = base_opponent(
            active={"stack": [CLEFFA], "damage": 0},
            bench=[
                {"stack": [ZORUA, ZOROARK], "energy": [DARK, DARK], "damage": 60},
                {"stack": [FEZ], "damage": 160},
                {"stack": [ZORUA, ZOROARK], "tool": HARD_BELT},
                {"stack": [RESHIRAM]},
                {"stack": [MUNK]},
            ],
        )
    else:
        opponent = base_opponent()
    rotation = order % len(opponent["hand"])
    opponent["hand"] = opponent["hand"][rotation:] + opponent["hand"][:rotation]
    deck_rotation = order % len(opponent["deck_top"])
    opponent["deck_top"] = opponent["deck_top"][deck_rotation:] + opponent["deck_top"][:deck_rotation]

    proof = standard_proof(
        dusk_kind=dusk_kind, counter=counter, unlock_klefki=unlock,
        infernal_split=split, tatsugiri_scan=tatsu, rod_rebuild=rod,
    )
    keys = [CANDY, CHARIZARD, BRIAR]
    if not counter:
        keys.append(BAND)
    if counter or not rod:
        keys.append(COUNTER)
    if rod:
        keys.extend([ROD, ULTRA])
    checkpoints = [
        checkpoint(1, "化危为吉 draw 3", "ability_draw", [CANDY, CHARIZARD, COUNTER if counter else BAND], "咒怨炸弹", "先拿到跨回合保留的进化与阈值组件。"),
        checkpoint(2, "中间公开信息节点", "effect_reveal", [FIRE, FIRE] if counter else [COUNTER, FIRE, FIRE], "第二回合进化", "补齐捕捉牌或确认牌库仍有火能。"),
        checkpoint(3, "终结组件公开兑现", "effect_reveal", [BRIAR], "白蕾雅窗口", "最后确认终结支援者，不能初始握在手中。"),
    ]
    if rod:
        checkpoints = [
            checkpoint(1, "化危为吉 draw 3", "ability_draw", [CANDY, BAND], "首回合攻击", "先保留糖果与阈值组件。"),
            checkpoint(2, "第一回合音速搜索", "effect_reveal", [BRIAR], "白蕾雅窗口", "先把终结支援者从牌库取出并跨回合保留。"),
            checkpoint(3, "化危为吉第三张", "ability_draw", [ULTRA], "厉害钓竿", "高级球初始隐藏，必须由小抽牌节点取得。"),
            checkpoint(4, "音速搜索→钓竿回填", "recovery", [ROD, CHARIZARD, FIRE, FIRE], "神奇糖果", "回填、再检索、再进化，顺序不可交换。"),
        ]
    if tatsu:
        checkpoints = [
            checkpoint(1, "化危为吉 draw 3", "ability_draw", [CANDY, CHARIZARD, BAND], "揽客", "先移走顶3非支援者。"),
            checkpoint(2, "揽客 top 6与次回合比雕", "effect_reveal", [RESEARCH, IONO, COUNTER], "支援者选择", "看见两张高诱惑抽牌支援者，同时保留次回合捕捉节点。"),
            checkpoint(3, "揽客正确选择", "effect_reveal", [BRIAR], "任何洗牌", "最后从三张支援者中拿白蕾雅。"),
        ]

    template.update({
        "id": sid,
        "deck_key": "charizard_dragapult",
        "order": order,
        "revision": 3,
        "title": title,
        "focus": focus,
        "objective": "两回合完成首回合双奖交换，并在第二回合以白蕾雅取得3奖，共拿5奖。",
        "player_deck_id": 800025404,
        "opponent_deck_id": 800018502,
        "opponent_name": "18.0 N的索罗亚克",
        "turn_number": turn,
        "first_player_index": 0,
        "turn_limit": 2,
        "last_knockout_turn_against": [turn - 1, -999],
        "tactic_pattern_ids": [
            "charizard_dusknoir_briar_window",
            "charizard_defiance_damage_threshold" if order > 5 else "charizard_klefki_basic_ability_counter",
        ] if order in (5, 10) else [],
        "player": player,
        "opponent": opponent,
        "goal": {"type": "prizes", "count": 5},
        "proof_steps": proof,
        "validation_operations": [step["label"] for step in proof if step["kind"] != "fixed_rules_ai_turn"],
    })
    template["challenge"] = {
        "difficulty": "expert",
        "payoff_value": 5,
        "decision_points": [
            {"choice": "是否先使用博士的研究", "failure": "会弃掉跨回合组件并让隐藏牌序失效。"},
            {"choice": "50/130自爆、捕捉与支援者的先后", "failure": "奖差或白蕾雅恰好2奖的窗口被永久错过。"},
            {"choice": "第二回合能量与头带的归属", "failure": "燃烧黑暗只有300，无法击倒320HP多龙。"},
        ],
        "cross_turn_dependencies": [
            "第一回合自爆送奖和古玉鱼双奖击倒共同建立第二回合白蕾雅窗口。",
            "首攻古玉鱼被反杀后，小火龙才能自动晋升并把对手推进恰好剩2奖。",
        ],
        "resource_tensions": [
            "博士研究看似能看到更多牌，实际会丢失糖果、喷火龙或白蕾雅。",
            "音速搜索会洗牌，必须在需要固定顶牌的特性之后使用。",
        ],
        "learning_outcome": focus,
    }
    dc = template["design_contract"]
    dc.update({
        "learning_axis": axis,
        "combo_id": combo_id,
        "deck_identity": "自爆恶喷通过主动送奖改变燃烧黑暗、反击捕捉器、不服输头带与白蕾雅四个条件，再用大比鸟精确检索闭合两回合五奖。",
        "solution_key_inventory_complete": True,
        "engine_cards_in_play": [CHIYU, PIDGEOT, DUSKNOIR if dusk_kind == "dusknoir" else DUSCLOPS, FEZ, CHARMANDER],
        "key_cards": keys,
        "key_card_roles": {
            CANDY: "把自动晋升的小火龙直接进化",
            CHARIZARD: "第二回合太晶终结攻击手",
            BRIAR: "对手剩2奖时把双奖击倒改成三奖",
            **({BAND: "把300补到330并穿过坚硬束带"} if not counter else {}),
            **({COUNTER: "送奖后抓出首回合双奖目标" if counter else "避开90HP诱饵，抓满血坚硬束带目标"} if (counter or not rod) else {}),
            **({ROD: "回填弃牌区喷火龙与火能", ULTRA: "检索回填后的喷火龙"} if rod else {}),
        },
        "initial_hand_decoys": player["hand"][:4],
        "random_hand_profile": {
            "functional_categories": (["Pokemon", "Supporter", "Item", "Tool", "Stadium"] if rod else ["Supporter", "Item", "Tool", "Stadium"]),
            "awkward_cards": [RESEARCH, TURO],
            "redundant_cards": [POFFIN, TM_EVO],
            "plausible_openings": ["直接博士研究", "先奇树", "先高级球", "先音速搜索", "先自爆", "先撤退钥圈儿"],
        },
        "draw_checkpoints": checkpoints,
        "winning_draw_route": {
            "opening": proof[0]["label"],
            "sequence": [s["label"] for s in proof],
            "draw_trace": [uid for cp in checkpoints for uid in cp["reveals"]],
            "hidden_reveal": [ULTRA] if rod else [BRIAR],
            "order_sensitive_pair": ["送奖/取奖", "白蕾雅"],
            "exact_reason": "只有先把对手推进恰好剩2奖、同时保留支援者次数和头带，330伤三奖终结才成立。",
        },
        "bait_lines": [
            {
                "id": "research_now", "opening": "立即使用博士的研究", "looks_good_because": "手牌有7张且能一次看7张新牌",
                "gained_information": "随机七抽", "draw_trace": [RESEARCH, "seven random cards"],
                "consumed_resource": "唯一支援者次数与当前跨回合手牌",
                "fails_because": "白蕾雅不能在终结回合使用，或糖果/头带被弃掉。",
                "failed_equation": "330伤但只取2奖，5奖目标少1奖",
                "negative_probe_id": f"{sid}_research_now",
            },
            {
                "id": "skip_offer", "opening": "不使用咒怨炸弹直接攻击", "looks_good_because": "避免主动送奖",
                "gained_information": "保留一只进化宝可梦", "draw_trace": ["no prize offer"],
                "consumed_resource": "燃烧黑暗30伤、反击窗口和白蕾雅条件",
                "fails_because": "对手第二回合不会恰好剩2奖，喷火龙也少30伤。",
                "failed_equation": "270/300 < 320 且白蕾雅不可用",
                "negative_probe_id": f"{sid}_skip_offer",
            },
        ],
        "board_capacity": {"player_bench": 5, "opponent_bench": 5},
        "board_roles": common_roles(
            "古玉鱼承担首回合复仇140并故意被反杀。" if not (unlock or tatsu) else ("钥圈儿先封锁双方基础特性，撤退后才允许化危为吉。" if unlock else "米立龙必须先看顶6支援者再撤退。"),
            "彷徨夜灵50送奖并避免过量。" if dusk_kind == "dusclops" else "黑夜魔灵130送奖并为后续目标预置伤害。",
            "钥圈儿/米立龙是合法场位与诱导路线，不是装饰。",
        ),
        "board_exemptions": [],
        "board_exemption_reasons": {},
        "damage_math": [
            damage(
                "first Fezandipiti ex",
                210,
                160 if counter else 70,
                0,
                50 if counter else 140,
                "送奖会覆盖复仇标记，因此反击捕捉题只按基础50；其他题按50+复仇90",
            ),
            damage(
                "second N's Zoroark ex",
                280,
                190 if counter else 0,
                0,
                300,
                "反击题攻击90HP现役目标；其他题以330穿过坚硬束带减伤30",
            ),
        ],
        "energy_math": [
            energy("Chi-Yu Jealousy Burn", 0 if split else 2, 2 if split else 0, 0, 2),
            energy("Charizard Burning Darkness", 1 if split else 0, 1 if split else 2, 0, 2),
        ],
        "luck_contract": {
            "kind": f"{combo_id}_frozen_hidden_order",
            "deterministic": True,
            "shuffle_points": ["Pidgeot Quick Search", "Tatsugiri remaining cards", "Super Rod and Ultra Ball where authored"],
            "reveal_sequence": [uid for cp in checkpoints for uid in cp["reveals"]],
            "same_state_for_all_routes": True,
        },
        "climax_contract": {
            "apparent_dead_end": "关键进化、头带和白蕾雅都不在初始手牌，对手还拥有满血320HP多龙。",
            "comeback_chain": [s["label"] for s in proof],
            "finisher": "最后取得重建钥匙或白蕾雅，以330伤精确跨过320HP并一次拿3奖。",
            "finisher_card": ULTRA if rod else BRIAR,
            "finisher_checkpoint_order": 3,
            "filtering_checkpoints_before_finisher": 2,
            "finisher_was_hidden": True,
            "exact_payoff": "两回合合计5奖。",
        },
        "board_history": {
            "elapsed_turns": 6,
            "energy_origins": ["古玉鱼双火来自此前两次手贴，或题面烈炎支配明确分配。", "多龙的火超能来自前两回合设置。"],
            "damage_origins": ["吉雉鸡ex的70伤来自上回合公开攻击，剩140符合古玉鱼复仇线。", "索罗亚克的130伤由题内咒怨炸弹产生。"],
            "prize_history": ["双方此前完成一次奖赏交换。", "题内每次送奖、击倒和额外取奖均由生产规则结算。"],
        },
        "witness": {
            "player_turns": 2,
            "minimum_meaningful_actions": len([s for s in proof if s["kind"] != "fixed_rules_ai_turn"]),
            "irreversible_decisions": 4,
            "one_turn_shortcut_refuted": True,
        },
    })
    dc["combo_contract"] = {
        "prerequisites": ["双方备战区满场", "所有解题关键牌初始不在手牌", "古玉鱼满足上回合己方被招式击倒条件"],
        "ordered_steps": [s["label"] for s in proof],
        "payoff": "两回合5奖，其中第二回合白蕾雅三奖。",
        "reordered_failure": "洗牌、送奖、支援者、进化或头带任一步骤交换都会关闭奖差或330伤害式。",
    }
    return template


SPECS = [
    ("复仇不是过渡：古玉鱼倒下才开启三奖终结", "古玉鱼140拿双奖、主动送奖、再以恶喷330和白蕾雅拿3奖。", "charizard_damage_scaling", "chiyu_revenge_briar", "standard"),
    ("顶6只有一个答案：米立龙先拿白蕾雅", "在三张支援者诱饵中选择白蕾雅，撤退后完成两攻击手交接。", "tatsugiri_supporter_scan", "tatsugiri_briar_scan", "tatsugiri"),
    ("三张火能不能全给恶喷：烈炎支配分流", "第一回合烈炎支配2火给古玉鱼、1火给喷火龙，跨回合保留第二攻击费用。", "infernal_reign_split", "infernal_split_handoff", "infernal_split"),
    ("50比130更难：彷徨夜灵的最小送奖", "只用50档改变奖差，保留黑夜魔灵130的机会成本并完成五奖。", "dusknoir_damage_choice", "dusclops_fifty_window", "dusclops"),
    ("捕捉器必须等自爆：送奖后的首杀窗口", "先主动送奖使反击捕捉器合法，再抓出剩140HP双奖目标。", "counter_catcher_closeout", "offer_then_counter", "counter"),
    ("钥圈儿也锁自己：先封后解再爆发", "钥圈儿撤退前化危为吉非法，必须先解除封锁再进入抽牌与复仇链。", "klefki_lock_unlock", "klefki_unlock_combo", "klefki"),
    ("博士研究是陷阱：七抽反而丢掉唯一解", "随机大抽会毁掉跨回合组件；正确线用吉雉鸡与比雕逐层取得。", "quick_search_order", "research_lure_hold", "standard"),
    ("差的正是30：不服输头带精确跨320", "燃烧黑暗在对手已拿4奖时只有300，必须保留落后奖差与头带补30。", "charizard_damage_scaling", "defiance_exact_thirty", "standard"),
    ("先送、再死、最后三奖：白蕾雅时点题", "自爆与古玉鱼被反杀共同把对手从4奖推进2奖，早一拍或晚一拍都不能用白蕾雅。", "briar_three_prize", "briar_exact_window", "standard"),
    ("弃牌区才是第二副手牌：钓竿回填重建", "第二回合按音速搜索钓竿、回填喷火龙、再用高级球检索和糖果进化。", "rod_jet_rebuild", "rod_ultra_candy_rebuild", "rod"),
]


def build() -> tuple[list[dict[str, Any]], dict[str, list[dict[str, Any]]]]:
    scenarios: list[dict[str, Any]] = []
    probes: dict[str, list[dict[str, Any]]] = {}
    for order, spec in enumerate(SPECS, 1):
        scenario = make_scenario(
            order,
            title=spec[0],
            focus=spec[1],
            axis=spec[2],
            combo_id=spec[3],
            mode=spec[4],
        )
        scenarios.append(scenario)
        proof = scenario["proof_steps"]
        prefix = copy.deepcopy(proof[: max(2, min(4, len(proof) // 2))])
        probes[scenario["id"]] = [
            {
                "id": f"{scenario['id']}_research_now",
                "category": "research_now",
                "description": "大抽占用支援者并破坏白蕾雅终结窗口。",
                "proof_steps": prefix + [{"id": "deadline", "kind": "end_turn", "label": "诱导线未在期限内完成五奖"}],
            },
            {
                "id": f"{scenario['id']}_skip_offer",
                "category": "skip_offer",
                "description": "没有完成送奖、增伤与白蕾雅条件的联动。",
                "proof_steps": copy.deepcopy(proof[:2]) + [{"id": "deadline", "kind": "end_turn", "label": "错误次序在期限前结束"}],
            },
        ]
    return scenarios, probes


def main() -> None:
    scenarios, probes = build()
    PUZZLE_PATH.write_text(json.dumps({"format_version": 1, "scenarios": scenarios}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    PROBE_PATH.write_text(json.dumps({"format_version": 1, "scenarios": probes}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {len(scenarios)} puzzles -> {PUZZLE_PATH}")
    print(f"wrote {sum(len(v) for v in probes.values())} probes -> {PROBE_PATH}")


if __name__ == "__main__":
    main()
