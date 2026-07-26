import json
from copy import deepcopy
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "data" / "deck_training" / "scenarios.json"

DECKS = {
    "dragapult": (800018506, "自爆多龙", "CSV8C_157"),
    "gardevoir": (800018497, "沙奈朵", "CSV2C_053"),
    "gholdengo": (800016834, "赛富豪", "CSV9C_096"),
    "raging_bolt": (800018509, "猛雷鼓", "CSV9C_154"),
    "marnie": (800018501, "玛俐", "CSV10C_146"),
    "n_zoroark": (800018502, "N", "CSV10C_144"),
    "charizard_dragapult": (800025404, "自爆恶喷", "151C_004"),
}

OPPONENTS = {
    800018506: {"name": "自爆多龙", "active": {"stack": ["CSV8C_157", "CSV8C_158", "CSV8C_159"]}, "bench": [{"stack": ["CSV8C_157", "CSV8C_158", "CSV8C_159"]}]},
    800018497: {"name": "沙奈朵", "active": {"stack": ["CSV2C_053", "CSV2C_054", "CSV2C_055"]}, "bench": [{"stack": ["CSV2C_053", "CSV2C_054", "CSV2C_055"]}]},
    800016834: {"name": "赛富豪", "active": {"stack": ["CSV9C_096", "CSV4C_089"]}, "bench": [{"stack": ["CSV9C_096", "CSV4C_089"]}]},
    800018509: {"name": "猛雷鼓", "active": {"stack": ["CSV7C_154"], "energy": ["CSVE1C_FIG", "CSVE1C_LIG"]}, "bench": [{"stack": ["CSV7C_154"]}]},
    800018501: {"name": "玛俐", "active": {"stack": ["CSV10C_146", "CSV10C_147", "CSV10C_148"]}, "bench": [{"stack": ["CSV10C_146", "CSV10C_147", "CSV10C_148"]}]},
    800018502: {"name": "N", "active": {"stack": ["CSV10C_144", "CSV10C_145"]}, "bench": [{"stack": ["CSV10C_144", "CSV10C_145"]}]},
    18000230: {"name": "恶喷", "active": {"stack": ["151C_004", "CSV5C_075"]}, "bench": [{"stack": ["151C_004", "CSV5C_075"]}]},
}

PLAYER_SETUPS = {
    "gardevoir": {
        "active": {"stack": ["151C_151"], "energy": ["CSVE1C_PSY"]},
        "bench": [{"stack": ["CSV2C_053", "CSV2C_054"], "energy": ["CSVE1C_PSY", "CSVE1C_PSY"]}, {"stack": ["CSV8C_094"], "energy": ["CSVE1C_DAR"]}],
        "hand": ["CSV2C_055", "CSVE1C_PSY", "CSV6C_114", "CSV1C_123", "CSV1C_112", "CSVE1C_DAR"],
        "discard": ["CSVE1C_PSY"], "lost_zone": [], "deck_top": ["CSV3C_123", "CSV8C_183"], "prize_count": 5,
    },
    "gholdengo": {
        "active": {"stack": ["CSV6C_042"]},
        "bench": [{"stack": ["CSV9C_096"]}, {"stack": ["CSV8C_094"], "energy": ["CSVE1C_DAR"]}],
        "hand": ["CSV4C_089", "CSVE1C_MET", "CSV6C_114", "CSV1C_113", "CSV3C_115", "CSVE1C_LIG", "CSVE1C_GRA", "CSVE1C_FIR", "CSVE1C_WAT", "CSVE1C_FIG", "CSVE1C_PSY"],
        "discard": ["CSVE1C_MET", "CSVE1C_DAR"], "lost_zone": [], "deck_top": ["CSV9C_176", "CSV6C_115"], "prize_count": 5,
    },
    "raging_bolt": {
        "active": {"stack": ["151C_151"]},
        "bench": [{"stack": ["CSV7C_154"], "energy": ["CSVE1C_LIG"]}, {"stack": ["CSV8C_028"]}],
        "hand": ["CSV6C_121", "CSV7C_180", "CSVE1C_GRA", "CSVE1C_GRA", "CSV6C_115", "CSVH1aC_008", "CSV9C_196", "CSVE1C_LIG"],
        "discard": ["CSVE1C_GRA", "CSVE1C_FIG"], "lost_zone": [], "deck_top": ["CSV9C_207", "CSV8C_183"], "prize_count": 5,
    },
    "marnie": {
        "active": {"stack": ["CSV9.5C_004"]},
        "bench": [{"stack": ["CSV10C_146", "CSV10C_147"], "energy": ["CSVE1C_DAR"]}, {"stack": ["CSV8C_094"], "energy": ["CSVE1C_DAR"]}],
        "hand": ["CSV10C_148", "CSVE1C_DAR", "CSV6C_114", "CSV1C_123", "CSV10C_216", "CSV8C_183"],
        "discard": ["CSVE1C_DAR", "CSV9.5C_043"], "lost_zone": [], "deck_top": ["CSV3C_123", "CSV1C_112"], "prize_count": 5,
    },
    "n_zoroark": {
        "active": {"stack": ["CSV4C_044"]},
        "bench": [{"stack": ["CSV10C_144"], "energy": ["CSVE1C_DAR"]}, {"stack": ["CSV10C_166"]}, {"stack": ["CSV8C_094"], "energy": ["CSVE1C_DAR"]}],
        "hand": ["CSV10C_145", "CSVE1C_DAR", "CSV6C_114", "CSV10C_190", "CSV7C_191", "CSV2C_114"],
        "discard": ["CSVE1C_DAR"], "lost_zone": [], "deck_top": ["CSV9C_198", "CSV8C_183"], "prize_count": 5,
    },
    "charizard_dragapult": {
        "active": {"stack": ["CSV9.5C_004"]},
        "bench": [{"stack": ["CSV8C_157", "CSV8C_158"], "energy": ["CSV1C_127"]}, {"stack": ["CSV8C_094"], "energy": ["CSV1C_127"]}],
        "hand": ["CSV8C_159", "CSVE1C_FIR", "CSV6C_114", "CSV1C_123", "CSV1C_112", "CSV8C_183"],
        "discard": ["CSVE1C_FIR", "151C_004"], "lost_zone": [], "deck_top": ["CSV3C_123", "CSV10C_207"], "prize_count": 5,
    },
}

PATTERNS = [
    ("斩杀线精算", "把检索、能量与攻击伤害连成一次确定击倒", 1, "prizes", 1),
    ("捕捉器与奖差", "先判断奖赏领先关系，再决定拉谁到前场", 1, "target_knockouts", 1),
    ("能量顺序", "在手贴、特性加速与换位之间保留攻击资源", 1, "prizes", 1),
    ("弃牌区回收", "计算弃牌成本、回收对象与最后的攻击资源", 1, "prizes", 1),
    ("愿增猿搬伤", "用愿增猿改变两个击倒阈值，再完成收奖", 1, "target_knockouts", 1),
    ("多目标取舍", "比较前场与后场价值，选择正确的指定击倒", 1, "target_knockouts", 1),
    ("两回合逆转", "首回合保存关键牌，承受规则 AI 回合后反攻", 2, "prizes", 1),
    ("先攻铺场", "从第一回合开始建立下回合可攻击的完整引擎", 2, "prizes", 1),
    ("错奖修正", "关键组件在奖赏区时识别替代路线并继续展开", 2, "prizes", 1),
    ("终局精算", "跨过规则 AI 的中间回合，在最后期限完成指定击倒", 2, "target_knockouts", 1),
]

VALIDATION_ROUTES = {
    "gardevoir": ["进化沙奈朵ex", "给沙奈朵手贴超能量", "使用反击捕捉器指定目标", "弃能撤退梦幻ex", "沙奈朵ex攻击"],
    "gholdengo": ["进化赛富豪ex", "给赛富豪手贴钢能量", "使用反击捕捉器指定目标", "使用宝可梦交替换入赛富豪", "淘金潮弃能攻击"],
    "raging_bolt": ["使用碧草引擎附能", "使用奥琳博士的气魄附能", "手贴第二张草能量", "使用顶尖捕捉器完成双方换位", "雷鸣蹴击弃能攻击"],
    "marnie": ["进化玛俐的长毛巨魔ex", "给长毛巨魔手贴恶能量", "使用反击捕捉器指定目标", "含羞苞免费撤退", "长毛巨魔ex攻击"],
    "n_zoroark": ["进化N的索罗亚克ex", "给索罗亚克手贴恶能量", "使用反击捕捉器指定目标", "皮宝宝免费撤退", "暗夜小丑选择正确招式攻击"],
    "charizard_dragapult": ["进化多龙巴鲁托ex", "给多龙巴鲁托手贴火能量", "使用反击捕捉器指定目标", "含羞苞免费撤退", "幻影潜袭分配伤害并攻击"],
}

DRAGAPULT_ROUTES = [
    ["放置摔角鹰人", "使用飞身入场", "使用咒怨炸弹", "进化多龙巴鲁托ex", "贴基本火能量", "使用幻影潜袭"],
    ["使用派帕", "贴紧急滑板", "使用宝可梦交替", "进化多龙巴鲁托ex", "贴基本火能量", "使用幻影潜袭"],
    ["使用反击捕捉器", "放置摔角鹰人", "使用飞身入场", "使用咒怨炸弹", "进化多龙巴鲁托ex", "贴基本火能量", "使用幻影潜袭"],
    ["放置摔角鹰人", "使用飞身入场", "进化多龙巴鲁托ex", "贴基本火能量", "使用幻影潜袭"],
    ["使用夜间担架", "使用高级球", "进化黑夜魔灵", "进化多龙巴鲁托ex", "使用咒怨炸弹", "贴基本火能量", "使用幻影潜袭"],
    ["使用咒怨炸弹", "贴豪华斗篷", "放置摔角鹰人", "使用飞身入场", "使用幻影潜袭"],
    ["贴夜光能量", "使用亢奋脑力", "进化黑夜魔灵", "使用咒怨炸弹", "放置摔角鹰人", "使用飞身入场", "使用幻影潜袭"],
    ["第一回合使用吉尼亚准备双二阶", "结束回合", "规则AI中间回合", "使用反击捕捉器", "进化多龙巴鲁托ex", "进化黑夜魔灵", "使用咒怨炸弹", "使用幻影潜袭"],
    ["使用咒怨炸弹", "放置月月熊 赫月ex", "贴夜光能量", "使用宝可梦交替", "月月熊攻击"],
    ["使用吉尼亚", "使用反击捕捉器", "使用夜间担架", "进化多龙巴鲁托ex", "进化黑夜魔灵", "贴夜光能量", "使用亢奋脑力", "使用咒怨炸弹", "放置摔角鹰人", "使用飞身入场", "使用宝可梦交替", "使用幻影潜袭"],
]


def convert_dragapult(raw):
    result = []
    for i, source in enumerate(raw[:10], 1):
        scenario = deepcopy(source)
        scenario["deck_key"] = "dragapult"
        scenario["turn_limit"] = 2 if i >= 7 else 1
        if i == 8:
            scenario["title"] = "首回合铺场与次回合进化"
            scenario["focus"] = "先攻不能攻击时规划完整的第二回合"
        elif i == 9:
            scenario["title"] = "错奖后的月月熊反攻"
            scenario["focus"] = "关键进化件落奖时切换备用攻击轴"
        elif i == 10:
            scenario["title"] = "两回合终局：愿增猿与自爆多龙"
            scenario["focus"] = "承受规则 AI 回合后重新计算伤害落点"
        count = 1
        objective = str(scenario.get("objective", ""))
        for n in (3, 2):
            if str(n) in objective:
                count = n
                break
        scenario["goal"] = {"type": "prizes", "count": count}
        scenario["objective"] = f"在 {scenario['turn_limit']} 个我方回合内拿 {count} 张奖赏。"
        scenario["validation_operations"] = list(DRAGAPULT_ROUTES[i - 1])
        if i == 9:
            scenario["player"]["prizes"] = ["CSV8C_159"]
        for key in ("minimum_meaningful_actions", "par_actions", "hints", "canonical_steps", "proof_graph"):
            scenario.pop(key, None)
        scenario["opponent_name"] = "沙奈朵"
        result.append(scenario)
    return result


def build_generic(deck_key, deck_id, deck_name, ordinal):
    scenarios = []
    opponents = list(OPPONENTS)
    for i, (title, focus, turns, goal_type, required) in enumerate(PATTERNS, 1):
        opponent_id = opponents[(ordinal + i) % len(opponents)]
        if opponent_id == deck_id:
            opponent_id = opponents[(ordinal + i + 1) % len(opponents)]
        opponent = deepcopy(OPPONENTS[opponent_id])
        player = deepcopy(PLAYER_SETUPS[deck_key])
        if i == 8:
            # This is the dedicated first-turn setup exercise. The visible board
            # remains stable, but turn-played locks prevent free same-turn evolution.
            player["active"]["turn_played"] = 1
            player["bench"][0]["turn_played"] = 1
        if i == 9:
            # Put a real deck card face-down in prizes. It is not duplicated in any
            # public zone, so the state compiler still proves exact 60-card conservation.
            prize_card = player["deck_top"].pop()
            player["prizes"] = [prize_card]
        if i in (5, 10) and deck_key != "raging_bolt":
            player["bench"][0]["damage"] = 30
        opponent_setup = {
            "prize_count": 3,
            "active": opponent.pop("active"),
            "bench": opponent.pop("bench"),
            "hand": [], "discard": [], "lost_zone": [], "deck_top": [],
        }
        if turns == 2:
            opponent_setup["active"].pop("energy", None)
        if deck_key != "raging_bolt":
            opponent_setup["bench"][0]["damage"] = 200
        else:
            opponent_setup["bench"][0]["damage"] = 50
        required = 2 if goal_type == "prizes" else required
        goal = {"type": "prizes", "count": required}
        if goal_type == "target_knockouts":
            goal = {"type": "target_knockouts", "required": required, "targets": [{"player": 1, "zone": "bench", "index": 0}]}
        operations = list(VALIDATION_ROUTES[deck_key])
        if i in (5, 10) and deck_key != "raging_bolt":
            operations.insert(3, "使用愿增猿搬运伤害指示物")
        scenario = {
            "id": f"{deck_key}_{i:02d}", "deck_key": deck_key, "order": i,
            "title": title, "focus": f"{deck_name}：{focus}",
            "objective": (f"在 {turns} 个我方回合内拿 {required} 张奖赏。" if goal_type == "prizes" else f"在 {turns} 个我方回合内击倒开局指定的对手备战宝可梦。"),
            "player_deck_id": deck_id, "opponent_deck_id": opponent_id,
            "opponent_name": OPPONENTS[opponent_id]["name"], "turn_number": 1 if i == 8 else 8,
            "first_player_index": 0, "turn_limit": turns,
            "player": player, "opponent": opponent_setup, "goal": goal,
            "validation_operations": operations,
        }
        scenarios.append(scenario)
    return scenarios


def main():
    original = json.loads(SOURCE.read_text(encoding="utf-8"))
    scenarios = convert_dragapult(original["scenarios"])
    for ordinal, (deck_key, (deck_id, deck_name, _)) in enumerate(list(DECKS.items())[1:], 1):
        scenarios.extend(build_generic(deck_key, deck_id, deck_name, ordinal))
    catalog = {
        "format_version": 2,
        "module": "18.0 七套卡组定向残局训练",
        "grading": "仅在回合预算耗尽时按奖赏或指定击倒进度评为 S/A/B/C",
        "scenarios": scenarios,
    }
    SOURCE.write_text(json.dumps(catalog, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")

    # Keep this legacy base generator as the source of the stable 70 ids, then
    # apply the expert authoring contract and the two curated payoff boards.
    from upgrade_expert_scenarios import main as upgrade_expert_scenarios
    upgrade_expert_scenarios()


if __name__ == "__main__":
    main()
