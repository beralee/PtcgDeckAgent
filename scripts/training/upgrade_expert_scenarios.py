"""Upgrade the deck-training catalog to the expert two-turn admission contract.

This is intentionally deterministic and idempotent.  It keeps the 70 stable
scenario ids while replacing low-value five-click exercises with two-turn
payoff puzzles and explicit authoring evidence.
"""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CATALOG_PATH = ROOT / "data" / "deck_training" / "scenarios.json"

DECK_NAMES = {
    "dragapult": "自爆多龙",
    "gardevoir": "沙奈朵",
    "gholdengo": "赛富豪",
    "raging_bolt": "猛雷鼓",
    "marnie": "玛俐的长毛巨魔",
    "n_zoroark": "N的索罗亚克",
    "charizard_dragapult": "自爆恶喷",
}

LESSONS = [
    ("双击倒资源线", "第一回合拿下前场，同时为第二个双奖目标保留攻击资源"),
    ("奖差反击窗口", "主动经营奖差，保留捕捉手段完成第二次指定击倒"),
    ("精确伤害分配", "用搬伤或附加伤害把第二回合的斩杀档位降低一档"),
    ("检索与抽牌次序", "先固定牌库顶与公开信息，再消耗一次性抽牌能力"),
    ("不可逆弃牌成本", "两次攻击共享同一批资源，第一回合多花一张就会断档"),
    ("攻击手交接", "首攻后预留第二攻击手，跨过规则 AI 回合继续收奖"),
    ("两回合四奖", "连续击倒两只双奖宝可梦；首回合必须为次回合调伤与蓄能"),
    ("先送后取", "接受对手中间回合改变奖差，再把劣势转成反击牌的合法窗口"),
    ("错误路线排除", "手牌中存在看似有收益的支援者，使用后会破坏最终斩杀"),
    ("终局精算", "在资源、牌库与攻击次数都封顶的场面完成唯一的高奖赏路线"),
]

OPERATIONS = {
    "dragapult": [
        "用愿增猿把30伤害移到第二个双奖目标", "进化黑夜魔灵并选择是否自爆",
        "处理自爆送奖产生的反击捕捉器窗口", "进化多龙巴鲁托ex", "补齐火与超能量",
        "第一次幻影潜袭击倒前场并把60伤害精确放到下一个目标", "跨过规则AI回合保住第二攻击手",
        "再次调整伤害后使用第二次幻影潜袭完成四奖",
    ],
    "gardevoir": [
        "给吼叫尾附着勇气护符", "进化沙奈朵ex建立精神拥抱引擎", "第一次精神拥抱",
        "第二次精神拥抱并核对剩余HP", "只附着达到第一条斩杀线所需的能量", "完成第一次双奖击倒",
        "跨过规则AI回合后重建能量", "用愿增猿修正第二目标阈值", "完成第二次双奖击倒",
    ],
    "gholdengo": [
        "先发动两只赛富豪ex的嘉奖硬币", "用愿增猿把30伤害搬到第二个猛雷鼓ex", "第一次超级能量回收只弃两张非能量",
        "保留第二张超级能量回收", "第一次淘金潮精确弃5能击倒满血目标", "跨过规则AI回合再次发动嘉奖硬币",
        "第二次超级能量回收取回4能", "第二次淘金潮只弃4能击倒已调伤目标", "两回合合计拿4奖",
    ],
    "raging_bolt": [
        "大地容器先把斗能量送入弃牌区", "碧草之舞附草能并抽牌", "奥琳博士把斗能量附给猛雷鼓",
        "手贴保留给第二攻击手", "第一次雷鸣蹴击只弃精确数量能量", "跨过规则AI回合保住草能引擎",
        "再次碧草之舞并补齐第二条攻击线", "第二次雷鸣蹴击完成四奖",
    ],
    "marnie": [
        "进化玛俐的长毛巨魔ex", "庞克泵感给当前攻击手与后续玛俐轴分配恶能量", "把手贴恶能保留给不能吃特性的愿增猿",
        "愿增猿先搬30到前场斩杀点", "长毛巨魔暗影子弹击倒前场并给第二目标30", "跨过规则AI回合保护能量分配",
        "第二次愿增猿校正伤害", "第二次暗影子弹击倒双奖目标并完成四奖",
    ],
    "n_zoroark": [
        "暗码迷先把PP提升剂与恶能量置顶", "交易抽到固定的两张牌", "PP提升剂给备战N的宝可梦附能",
        "补齐N的索罗亚克ex的双恶费用", "暗夜王牌选择正确的N宝可梦招式", "第一次复制攻击拿2奖",
        "跨过规则AI回合后用夜间担架恢复复制源", "再次交易但保留攻击资源", "第二次暗夜王牌完成四奖",
    ],
    "charizard_dragapult": [
        "第一回合保留白蕾雅与反击捕捉器", "让低价值前场承受对手规则AI的击倒", "对手拿奖后确认其剩余2奖",
        "用神奇糖果进化喷火龙ex", "炼狱支配只给最终攻击手附能", "附着不服输头带",
        "反击捕捉器拉出330HP双奖目标", "使用白蕾雅", "恶喷以330伤害击倒并一次拿3奖",
    ],
}

DECISIONS = {
    "dragapult": [
        {"choice": "自爆现在使用还是留到下一回合", "failure": "错误送奖时机会关闭反击捕捉器或让第二攻击手断层"},
        {"choice": "幻影潜袭的60伤害如何分到下一目标", "failure": "分散伤害会让第二回合差一个斩杀档位"},
    ],
    "gardevoir": [
        {"choice": "精神拥抱附几次以及先给谁附能", "failure": "过量伤害会让攻击手昏厥，少一次则无法完成斩杀"},
        {"choice": "愿增猿搬走多少伤害", "failure": "吼叫尾伤害会随自身伤害下降，搬错会同时丢失两个击倒点"},
    ],
    "gholdengo": [
        {"choice": "第一回合淘金潮弃4能还是5能", "failure": "少1能拿不到首个双奖，多弃则第二回合没有4能可回收"},
        {"choice": "愿增猿的30伤害放在哪只宝可梦", "failure": "不预先把第二目标压到200HP，第二次淘金潮会差1张能量"},
    ],
    "raging_bolt": [
        {"choice": "大地容器弃哪种能量", "failure": "斗能没有先进入弃牌区时奥琳博士无法形成加速"},
        {"choice": "每次雷鸣蹴击弃几张能量", "failure": "首回合过量弃能会直接切断第二次攻击"},
    ],
    "marnie": [
        {"choice": "庞克泵感的5张恶能如何分给当前与后续攻击手", "failure": "全给当前会让第二回合没有可接力的攻击线"},
        {"choice": "手贴给长毛巨魔还是愿增猿", "failure": "愿增猿不是玛俐的宝可梦，错留手贴会失去搬伤能力"},
    ],
    "n_zoroark": [
        {"choice": "暗码迷与交易的发动顺序", "failure": "先交易会抽走未知牌，置顶资源无法在本回合兑现"},
        {"choice": "暗夜王牌复制哪个N的宝可梦招式", "failure": "复制单体低伤招式会错过双目标或精确击倒窗口"},
    ],
    "charizard_dragapult": [
        {"choice": "第一回合是否贪图无关动作或提前消耗支援者", "failure": "白蕾雅被弃掉后第二回合最多只能拿2奖"},
        {"choice": "是否允许对手先拿1奖", "failure": "不制造对手剩2奖的状态，白蕾雅与恶喷增伤都不会同时成立"},
    ],
}


def _gholdengo_setup() -> dict:
    return {
        "active": {"stack": ["CSV9C_096", "CSV4C_089"], "energy": ["CSVE1C_MET"], "damage": 30},
        "bench": [
            {"stack": ["CSV9C_096", "CSV4C_089"], "energy": ["CSVE1C_MET"]},
            {"stack": ["CSV8C_094"], "energy": ["CSVE1C_DAR"]},
        ],
        "hand": [
            "CSV3C_115", "CSV3C_115", "CSVE1C_MET", "CSV7C_177", "CSV7C_177",
            "CSV7C_177", "CSV7C_177", "CSV7C_191", "CSV6C_114",
        ],
        "discard": ["CSVE1C_LIG", "CSVE1C_GRA", "CSVE1C_FIR", "CSVE1C_WAT"],
        "lost_zone": [],
        "deck_top": ["CSVE1C_FIG", "CSVE1C_PSY", "CSV3C_115", "CSV3C_115"],
        "prize_count": 6,
    }


def _gholdengo_opponent() -> dict:
    return {
        "prize_count": 3,
        "active": {"stack": ["CSV7C_154"], "damage": 0},
        "bench": [{"stack": ["CSV7C_154"], "damage": 10}],
        "hand": [], "discard": [], "lost_zone": [],
        "deck_top": ["CSV6C_115", "CSV9C_207"],
    }


def _charizard_setup() -> dict:
    return {
        "active": {"stack": ["CSV8C_081"]},
        "bench": [
            {"stack": ["151C_004"]},
            {"stack": ["151C_016"]},
            {"stack": ["CSV8C_081"]},
        ],
        "hand": [
            "CSVH1C_045", "CSV5C_075", "CSV6C_114", "CSV9C_202", "CSV1C_117",
            "CSV1C_121", "CSV3C_123", "CSV1C_112",
        ],
        "discard": ["CSVE1C_FIR"], "lost_zone": [],
        "deck_top": ["CSVE1C_FIR", "CSV7C_177", "CSV1C_109"],
        "prize_count": 6,
    }


def _charizard_opponent() -> dict:
    return {
        "prize_count": 3,
        "active": {
            "stack": ["CSV4C_099", "151C_017", "CSV4C_101"],
            "energy": ["CSVE1C_FIR", "CSVE1C_FIR"],
        },
        "bench": [{"stack": ["151C_004", "CSV5C_015", "CSV5C_075"]}],
        "hand": [], "discard": [], "lost_zone": [],
        "deck_top": ["CSVE1C_FIR", "CSV7C_177"],
    }


def _challenge(deck_key: str, order: int, payoff: int = 4) -> dict:
    return {
        "difficulty": "expert",
        "payoff_value": payoff,
        "decision_points": DECISIONS[deck_key],
        "cross_turn_dependencies": [
            "第一回合的伤害、奖差或资源余量必须直接降低第二回合的斩杀成本",
            "规则AI中间回合后重新检查公开场面，不能把作者路线当成固定脚本",
        ],
        "resource_tensions": [
            "两次攻击共享同一批一次性检索、能量与换位资源",
            f"第{order}题设置了可立即使用但会破坏最终结果的诱饵牌",
        ],
        "learning_outcome": LESSONS[order - 1][1],
    }


def _set_damage_for_two_hit_route(scenario: dict, deck_key: str) -> None:
    player_thresholds = {
        "dragapult": (200, 260),
        "gardevoir": (190, 190),
        "raging_bolt": (280, 280),
        "marnie": (210, 210),
        "n_zoroark": (170, 170),
    }
    if deck_key not in player_thresholds:
        return
    active_remaining, bench_remaining = player_thresholds[deck_key]
    opponent = scenario.get("opponent", {})
    slots = [(opponent.get("active", {}), active_remaining)]
    bench = opponent.get("bench", [])
    if bench:
        slots.append((bench[0], bench_remaining))
    for slot, remaining in slots:
        stack = slot.get("stack", [])
        if not stack:
            continue
        card_path = ROOT / "data" / "bundled_user" / "cards" / f"{stack[-1]}.json"
        if not card_path.exists():
            continue
        hp = int(json.loads(card_path.read_text(encoding="utf-8")).get("hp", 0))
        slot["damage"] = max(0, hp - remaining)


def main() -> None:
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    for scenario in catalog["scenarios"]:
        deck_key = scenario["deck_key"]
        order = int(scenario["order"])
        lesson_title, lesson_focus = LESSONS[order - 1]
        scenario["title"] = lesson_title
        scenario["focus"] = f"{DECK_NAMES[deck_key]}：{lesson_focus}"
        scenario["turn_limit"] = 2
        scenario["turn_number"] = max(8, int(scenario.get("turn_number", 8)))
        scenario["player"]["prize_count"] = 6
        # Legacy "wrong prize" exercises pinned a public deck reference into the
        # hidden prize zone. Expert scenarios use a fresh deterministic prize fill.
        scenario["player"].pop("prizes", None)
        scenario["goal"] = {"type": "prizes", "count": 4}
        scenario["objective"] = "在2个我方回合内连续击倒2只双奖宝可梦，拿4张奖赏。"
        scenario["validation_operations"] = OPERATIONS[deck_key]
        scenario["challenge"] = _challenge(deck_key, order)
        # Ordinary expert boards test the player's two-turn resource continuity;
        # the opponent may still develop with the production AI, but must not start
        # with a pre-paid knockout that invalidates the authored second attack.
        scenario["opponent"].get("active", {}).pop("energy", None)
        _set_damage_for_two_hit_route(scenario, deck_key)

        if deck_key == "marnie":
            # Reserve all five remaining Darkness Energy in the actual deck.
            # Leaving the generic attachment on Morgrem caused the state factory
            # to fill face-down prizes from the tail of the pool and prize out
            # every legal Punk Up source.
            scenario["player"]["bench"][0].pop("energy", None)
            scenario["player"]["deck_top"] = ["CSVE1C_DAR"] * 5 + ["CSV3C_123", "CSV1C_112"]

        if deck_key == "gholdengo":
            scenario["player"] = _gholdengo_setup()
            scenario["opponent_deck_id"] = 800018509
            scenario["opponent_name"] = "猛雷鼓"
            scenario["opponent"] = _gholdengo_opponent()

        if deck_key == "charizard_dragapult":
            scenario["player_deck_id"] = 800025404
            scenario["opponent_deck_id"] = 800025404
            scenario["opponent_name"] = "自爆恶喷"
            scenario["player"] = _charizard_setup()
            scenario["opponent"] = _charizard_opponent()
            scenario["goal"] = {"type": "prizes", "count": 3}
            scenario["objective"] = "第一回合允许对手拿1奖；第二回合用反击捕捉器＋白蕾雅一次拿3奖。"
            scenario["challenge"] = _challenge(deck_key, order, 4)

    catalog["format_version"] = 3
    catalog["module"] = "18.0 七套卡组专家级两回合残局训练"
    catalog["grading"] = "只按最终奖赏进度评分；题目发布前必须通过专家难度作者合约与生产状态机构筑验证"
    CATALOG_PATH.write_text(json.dumps(catalog, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
