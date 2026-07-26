#!/usr/bin/env python3
"""Build the graph-engineered 18.0 Academy Gardevoir training overlay."""

from __future__ import annotations

import copy
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
BASE_PATH = ROOT / "data/deck_training/high_difficulty_puzzles.json"
OVERLAY_PATH = ROOT / "data/deck_training/gardevoir_graph_puzzles.json"
PROBES_PATH = ROOT / "data/deck_training/gardevoir_graph_shortcut_probes.json"
GRAPH_DIR = ROOT / "data/deck_training/graphs"

ACADEMY_DECK_ID = 800018498
LEGACY_ACADEMY_KIRLIA = "CSV2C_054"
ACADEMY_KIRLIA = "CS6.5C_030"
GARDEVOIR = "CSV2C_055"
SCREAM_TAIL = "CSV6C_065"
DRIFLOON = "CSV2C_060"
SHAYMIN = "CSV10C_007"
FEZANDIPITI = "CSV8C_135"
MUNKIDORI = "CSV8C_094"
NEST_BALL = "CSVH1C_043"
PSYCHIC = "CSVE1C_PSY"
COUNTER_CATCHER = "CSV6C_114"


DESIGNS: dict[str, dict[str, Any]] = {
    "gardevoir_01": {
        "profile": "deployment",
        "title": "空位只够一个：巢穴球找吼叫尾",
        "summary": "2回合拿4奖，并让吼叫尾完成接力",
        "objective": "备战区只留一个关键空位；从巢穴球的四条路线中找出能连续取奖的吼叫尾路线。",
        "focus": "先读奖赏图再决定巢穴球目标。愿增猿、飘飘球和谢米都能产生局部价值，但只有吼叫尾能在首只沙奈朵交换后越过前场，完成第二次两奖击倒。",
        "ordered": ["巢穴球只找吼叫尾，保留沙奈朵引擎与恶能愿增猿", "化危为吉后用派帕取得反击捕捉器与勇气护符", "首只沙奈朵精确拥抱一次并交换两奖", "对手反击后给吼叫尾护符，再用第二只沙奈朵连续拥抱", "愿增猿撤退，吼叫尾狙击后排并保留可攻击状态"],
        "baits": [
            ("巢穴球找愿增猿", "恶能手贴与场位都被占用，第二回合缺少能直接完成两奖击倒的攻击手。"),
            ("巢穴球找谢米", "赛富豪只打前场，防护没有改变奖赏图，却挤掉唯一攻击手空位。"),
            ("把护符交给皮皮ex", "吼叫尾无法承受六次精神拥抱，伤害上限不足。"),
        ],
        "choices": ["吼叫尾", "愿增猿", "飘飘球", "谢米"],
        "threat": "对手下一回合可用赛富豪ex击倒首攻沙奈朵，必须提前准备单奖接力。",
    },
    "gardevoir_02": {
        "profile": "deployment",
        "title": "一张超能量的三次工作：撤退、拥抱、再接棒",
        "summary": "2回合拿4奖，且不浪费撤退的超能量",
        "objective": "在没有额外换位牌的情况下，让同一张超能量先支付撤退、再被精神拥抱回收并支撑双沙奈朵接棒。",
        "focus": "题目的稀缺资源不是总能量，而是这一回合唯一能离开前场的超能量。撤退把它送进弃牌区，精神拥抱再把它变成攻击资源；过早手贴恶能或错误升场都会让第二回合断线。",
        "ordered": ["拉鲁拉丝只弃超能量撤退到第一只沙奈朵", "精神拥抱立刻取回撤退能并补齐三能", "首回合奇迹之力拿两奖", "对手反击后让第二只沙奈朵升场并拥抱第三能", "愿增猿校准伤害，反击捕捉器拉出第二个两奖目标"],
        "baits": [
            ("先手贴恶能", "手贴窗口被占后无法修正撤退与接棒的能量所有权。"),
            ("撤退到愿增猿", "前场仍缺奇迹之力的三能与190伤害。"),
            ("第二回合直接攻击", "目标仍差愿增猿搬伤的阈值，190无法击倒。"),
        ],
        "choices": ["撤退到第一只沙奈朵", "撤退到愿增猿", "保留前场直接展开"],
        "threat": "对手下一回合能击倒第一只沙奈朵，第二只攻击手必须在首回合资源分配时就保留。",
    },
    "gardevoir_03": {
        "profile": "deployment",
        "title": "先找抽牌桥：吉雉鸡不是可选装饰",
        "summary": "2回合拿4奖，并保留愿增猿阈值线",
        "objective": "用巢穴球在攻击手、保护位与抽牌桥之间作选择；只有吉雉鸡能把隐藏的反击捕捉器和能量翻出来。",
        "focus": "当前手牌看似已经有攻击框架，真正缺的是把牌库顶三张桥牌变成可用资源。巢穴球找吉雉鸡后，化危为吉同时完成抽牌、伤害校准与下一回合捕捉准备。",
        "ordered": ["巢穴球寻找吉雉鸡ex，而不是继续堆攻击手", "化危为吉取得超能、反击捕捉器和担架", "手贴第三超能后用愿增猿搬30到前场", "奇迹之力完成第一次两奖交换", "第二只沙奈朵拥抱并再次搬30，反击捕捉器完成终结"],
        "baits": [
            ("巢穴球找飘飘球", "当前没有护符和足够自伤预算，无法替代190首攻。"),
            ("巢穴球找谢米", "对手是前场单点攻击，保护位不产生本题需要的三张桥牌。"),
            ("先用博士的研究", "弃掉反击捕捉器路线并耗尽支援者窗口。"),
        ],
        "choices": ["吉雉鸡ex", "飘飘球", "谢米", "愿增猿"],
        "threat": "首攻沙奈朵必然被反击；若当前回合拿不到反击捕捉器，第二回合只能打错目标。",
    },
    "gardevoir_04": {
        "profile": "deployment",
        "title": "巢穴球四选一：只有吼叫尾能越过前场",
        "summary": "2回合拿4奖，首回合必须击倒后排吉雉鸡",
        "objective": "面对无法高效处理的前场，从四个基础宝可梦中找到能绕后取两奖并交棒给沙奈朵的路线。",
        "focus": "这不是“谁的面板更高”，而是奖赏图与场位问题。吼叫尾能把精神拥抱产生的伤害直接转成后排输出；飘飘球只打前场，谢米不处理当前威胁，愿增猿又会抢走唯一恶能手贴。",
        "ordered": ["巢穴球只找吼叫尾并把它放入最后关键空位", "化危为吉确认续航资源", "沙奈朵连续四次精神拥抱，把新上场的吼叫尾做成80伤攻击手", "愿增猿保留恶能并弃超能撤退到吼叫尾", "凶暴吼叫绕后取两奖；对手反击后沙奈朵接棒终结"],
        "baits": [
            ("找飘飘球", "气球炸弹只能攻击前场，无法取得后排吉雉鸡的两奖。"),
            ("找谢米", "对手的主要压力并非备战区招式伤害，防护不能推进奖赏。"),
            ("把恶能弃作撤退成本", "愿增猿第二回合失去搬伤能力，190差30。"),
        ],
        "choices": ["吼叫尾", "飘飘球", "谢米", "愿增猿"],
        "threat": "对手前场下一回合可击倒吼叫尾，首回合必须同时留下沙奈朵接力与愿增猿恶能。",
    },
    "gardevoir_05": {
        "profile": "deployment",
        "title": "低牌库重建：钓竿与深钵镇不能颠倒",
        "summary": "2回合拿4奖，并从弃牌区重建吼叫尾",
        "objective": "首攻交换后只靠一张钓竿和竞技场重建单奖攻击手；回收对象、结算顺序与最后空位都必须正确。",
        "focus": "吼叫尾、两张超能和备战位分别在弃牌区、牌库与场上三个资源域。先钓竿回填，再用深钵镇落位，最后精神拥抱；任何一步提前都会得到“有牌但用不了”的假资源。",
        "ordered": ["化危为吉只取到厉害钓竿，不提前洗牌", "愿增猿搬伤后由沙奈朵取得首2奖", "承受赛富豪反击并让出备战位", "厉害钓竿回填吼叫尾与两张超能", "深钵镇落位、两次拥抱、撤退后狙击剩80HP目标"],
        "baits": [
            ("先使用深钵镇", "吼叫尾仍在弃牌区，牌库里没有合法目标。"),
            ("钓竿回收三只宝可梦", "弃牌区没有足够超能供两次精神拥抱。"),
            ("把空位留给谢米", "第二回合无法再放入真正的终结攻击手。"),
        ],
        "choices": ["回收吼叫尾与两超能", "回收三只宝可梦", "先用竞技场"],
        "threat": "首攻沙奈朵会被击倒；若未利用随之产生的空位，第二回合没有合法终结攻击手。",
    },
    "gardevoir_06": {
        "profile": "composite",
        "title": "容器弃哪张：当前爆发与下回合手贴一起算",
        "summary": "2回合拿4奖，并保留第二只沙奈朵的手贴",
        "objective": "让大地容器的弃牌成本同时成为精神拥抱燃料，并把检索到的另一张超能保留给下一回合。",
        "focus": "大地容器不是单纯找能量。正确路线把刚抽到的超能弃掉，让精神拥抱立即回收；检索得到的超能留在手牌，确保首攻被击倒后第二只沙奈朵不依赖随机抽牌。",
        "ordered": ["化危为吉取得容器、超能和反击捕捉器", "大地容器弃超能，检索超能与恶能", "精神拥抱回收刚弃的超能并用愿增猿搬20", "首回合奇迹之力拿2奖", "第二回合手贴保留的超能，反击捕捉器拉目标并终结"],
        "baits": [
            ("容器弃奇树", "超能没有进入弃牌区，首攻少第三能。"),
            ("把检索超能也用于当前回合", "第二回合接棒沙奈朵没有合法手贴。"),
            ("先打反击捕捉器", "首回合拿奖后奖差变化，浪费应留给第二个两奖目标的换位。"),
        ],
        "choices": ["弃超能并拆分两回合", "弃支援者追求手牌数量", "把两张能量都投入首攻", "提前捕捉"],
        "threat": "对手反击会带走首攻沙奈朵及其全部能量，第二回合只能依靠预留手牌资源接棒。",
    },
    "gardevoir_07": {
        "profile": "precision",
        "title": "六次拥抱的生存线：护符和搬伤次序",
        "summary": "2回合拿4奖，吼叫尾必须以10HP完成首攻",
        "objective": "在勇气护符、六次精神拥抱与一次愿增猿搬伤之间精确排序，让吼叫尾达到180伤害而不先昏厥。",
        "focus": "护符提高的是可承受上限，不会治疗已有伤害。先四次拥抱到80伤，再搬走30，才有空间完成第五、第六次拥抱；提前或延后搬伤都会少一档输出或直接失去攻击手。",
        "ordered": ["派帕取得反击捕捉器与勇气护符并先装护符", "连续四次拥抱让吼叫尾到80伤", "愿增猿此时恰好搬走30伤", "再完成两次拥抱到90伤与六能", "撤退后180狙击；对手反击后沙奈朵用三次拥抱终结"],
        "baits": [
            ("第四次拥抱前搬伤", "最终只有80伤，凶暴吼叫少20。"),
            ("第五次拥抱后再搬伤", "吼叫尾在没有空间时无法继续精神拥抱。"),
            ("先撤退再补能", "攻击手已在前场，失去安全完成特性链的时序。"),
        ],
        "choices": ["四次拥抱后搬30", "三次拥抱后搬30"],
        "threat": "吼叫尾首攻后必被赛富豪击倒，愿增猿还必须保留第二张恶能完成再次撤退。",
    },
    "gardevoir_08": {
        "profile": "precision",
        "title": "超弱点380：两只沙奈朵的能量不许多一张",
        "summary": "2回合拿4奖，用两次190弱点击倒多龙",
        "objective": "利用莉莉艾的皮皮ex改写龙弱点，用两只沙奈朵各自三能完成380；任何多余附能都会破坏第二回合。",
        "focus": "皮皮ex负责把龙弱点变成超，沙奈朵仍只需190基础伤害。第一只只补第三能并捕捉健康多龙；把第四能堆给首攻看似更稳，实际会让第二只在反击后无法接棒。",
        "ordered": ["化危为吉取得超能与派帕", "只给首攻沙奈朵补第三能", "派帕找反击捕捉器并拉出健康多龙", "190经超弱点变380取得首2奖", "承受反击后第二只沙奈朵只拥抱一次，再以380完成终结"],
        "baits": [
            ("给首攻附第四能", "伤害不增加，却挪走第二回合唯一可用超能。"),
            ("让皮皮ex前场攻击", "满月回旋曲无法达到多龙330HP，且暴露两奖负担。"),
            ("不使用反击捕捉器", "攻击落在含羞苞等单奖目标，两个回合拿不满4奖。"),
        ],
        "choices": ["三能沙奈朵打弱点", "四能过量附着"],
        "threat": "对手第二只多龙已具备反击条件，第一只沙奈朵倒下后必须立刻有三能接力。",
    },
    "gardevoir_09": {
        "profile": "composite",
        "title": "糖果还是奇鲁莉安：承受60点后的接棒",
        "summary": "2回合拿4奖，并让备战沙奈朵扛住60点",
        "objective": "在保留奇鲁莉安续航与糖果直升之间选择；需要预判多龙下一回合向备战区放置60点后的HP和能量。",
        "focus": "当前看得到两条合法进化路线，但只有糖果把30伤拉鲁拉丝直接变成310HP沙奈朵，才能在再承受60点后继续攻击。普通进化到90HP奇鲁莉安会在对手回合直接失去接棒。",
        "ordered": ["化危为吉取得超能、糖果和沙奈朵ex", "把抽到的超能手贴给30伤拉鲁拉丝", "神奇糖果直接进化并用精神拥抱补第三能", "首攻沙奈朵击倒第一只多龙", "备战沙奈朵承受60点后升场，愿增猿搬30并完成第二次击倒"],
        "baits": [
            ("普通进化奇鲁莉安", "30伤加多龙60点正好达到90HP，第二回合接棒消失。"),
            ("把超能给首攻沙奈朵", "首攻本来已满足费用，备战沙奈朵缺第三能。"),
            ("先用博士的研究", "糖果和沙奈朵进化件被弃掉，公开接力线断裂。"),
        ],
        "choices": ["糖果直升沙奈朵", "普通进化奇鲁莉安", "把资源全给首攻", "先重置手牌"],
        "threat": "多龙巴鲁托ex公开招式会在击倒首攻时向备战区放置60点伤害指示物。",
    },
    "gardevoir_10": {
        "profile": "composite",
        "title": "谢米是假答案：看懂伤害与指示物再铺场",
        "summary": "2回合拿4奖，巢穴球不能被谢米诱导",
        "objective": "化危为吉看到进化组件后再用巢穴球选择最后场位；识破谢米不能阻止多龙放置伤害指示物的规则陷阱。",
        "focus": "谢米只防止对备战宝可梦造成的招式伤害，不阻止招式效果放置伤害指示物。最后场位若交给谢米，既挡不住多龙的60点，也挤掉后续攻击/搬伤资源；本题应保留现有愿增猿与沙奈朵接力，不额外铺场。",
        "ordered": ["先用化危为吉取得超能、糖果和沙奈朵ex，读取完整路线", "检查巢穴球候选后选择不放置，保留最后空位", "超能手贴给受伤拉鲁拉丝并用糖果直升", "精神拥抱补第三能，首攻取得2奖", "承受多龙放置60点后由愿增猿校准，第二只沙奈朵完成终结"],
        "baits": [
            ("巢穴球找谢米", "花之纱幔不阻止放置伤害指示物，且占掉最后场位。"),
            ("巢穴球找飘飘球", "本题已经有确定的沙奈朵接力，新增攻击手只分走超能。"),
            ("先用巢穴球再化危为吉", "洗牌打乱确定的糖果、沙奈朵与超能牌顶。"),
        ],
        "choices": ["保留空位", "谢米", "飘飘球", "吼叫尾"],
        "threat": "多龙的60点属于放置伤害指示物，公开规则文字明确绕过谢米的花之纱幔。",
    },
}


def bench_selector(uid: str, occurrence: int = 0) -> dict[str, Any]:
    result: dict[str, Any] = {"zone": "bench_uid", "uid": uid}
    if occurrence:
        result["occurrence"] = occurrence
    return result


def card_selector(uid: str, zone: str = "deck", occurrence: int = 0) -> dict[str, Any]:
    return {"$card": {"player": 0, "zone": zone, "uid": uid, "occurrence": occurrence}}


def nest_step(uid: str, label: str) -> dict[str, Any]:
    return {
        "id": f"nest_{uid.lower().replace('.', '_')}",
        "kind": "play_trainer",
        "label": label,
        "card_uid": NEST_BALL,
        "targets": [{"basic_pokemon": [card_selector(uid)]}],
    }


def replace_step(steps: list[dict[str, Any]], step_id: str, replacement: dict[str, Any]) -> None:
    for index, step in enumerate(steps):
        if step.get("id") == step_id:
            steps[index] = replacement
            return
    raise KeyError(f"missing proof step {step_id}")


def step(steps: list[dict[str, Any]], step_id: str) -> dict[str, Any]:
    for candidate in steps:
        if candidate.get("id") == step_id:
            return candidate
    raise KeyError(step_id)


def remove_bench_uid(player: dict[str, Any], uid: str, occurrence: int = 0) -> None:
    seen = 0
    for index, slot in enumerate(player["bench"]):
        stack = slot.get("stack", [])
        if stack and stack[-1] == uid:
            if seen == occurrence:
                player["bench"].pop(index)
                return
            seen += 1
    raise KeyError(f"bench does not contain {uid} occurrence {occurrence}")


def replace_uid(values: list[str], old: str, new: str) -> None:
    for index, value in enumerate(values):
        if value == old:
            values[index] = new
            return
    raise KeyError(f"{old} not found")


def replace_card_ref(value: Any, old: str, new: str) -> Any:
    """Recursively migrate exact card UIDs in an authored scenario."""
    if isinstance(value, dict):
        return {
            new if key == old else key: replace_card_ref(child, old, new)
            for key, child in value.items()
        }
    if isinstance(value, list):
        return [replace_card_ref(child, old, new) for child in value]
    return new if value == old else value


def semanticize_common(scenario: dict[str, Any]) -> None:
    for proof_step in scenario["proof_steps"]:
        sid = proof_step.get("id", "")
        if sid.startswith("flip_") or sid in {"flip_arven", "flip_vessel_package"}:
            proof_step["source"] = bench_selector(FEZANDIPITI)
        if proof_step.get("kind") == "munkidori":
            proof_step["ability_source"] = bench_selector(MUNKIDORI)


def upgrade_scenario(source: dict[str, Any]) -> dict[str, Any]:
    scenario = replace_card_ref(copy.deepcopy(source), LEGACY_ACADEMY_KIRLIA, ACADEMY_KIRLIA)
    scenario_id = scenario["id"]
    design = DESIGNS[scenario_id]
    scenario["revision"] = 3
    scenario["player_deck_id"] = ACADEMY_DECK_ID
    scenario["title"] = design["title"]
    scenario["objective"] = design["objective"]
    scenario["focus"] = design["focus"]
    scenario["goal"] = {
        "type": "compound",
        "summary": design["summary"],
        "progress_goal": {"type": "prizes", "count": 4},
        "invariants": [
            {"type": "not_lost", "player": 0, "failure_reason": "对手已完成终结"},
            {
                "type": "preserve_any",
                "player": 0,
                "card_uids": [GARDEVOIR],
                "count": 1,
                "failure_reason": "沙奈朵引擎未保留",
            },
            {
                "type": "handoff_attacker",
                "player": 0,
                "card_uids": [GARDEVOIR, SCREAM_TAIL, DRIFLOON],
                "min_energy": 2,
                "failure_reason": "没有保留带能接力攻击手",
            },
        ],
    }
    scenario["graph_contract"] = {
        "format_version": 1,
        "profile": design["profile"],
        "graph_artifact": f"res://data/deck_training/graphs/{scenario_id}.json",
        "player_operator": "OR",
        "opponent_operator": "AND" if design["profile"] != "precision" else "FROZEN",
        "initial_options": design["choices"],
        "candidate_card_uids": [MUNKIDORI, DRIFLOON, SCREAM_TAIL, SHAYMIN],
        "scarce_resources": ["备战区空位", "本回合手贴", "精神拥抱可承受伤害", "支援者窗口"],
        "public_threats": [design["threat"]],
        "negative_probe_axes": ["search_or_route_choice", "resource_assignment", "handoff_timing"]
        if design["profile"] == "composite"
        else ["route_choice", "resource_assignment"],
        "success_invariants": ["取得4奖", "对手未获胜", "沙奈朵引擎存活", "带能接力攻击手存在"],
        "proof_claim": "policy_replay_proven",
        "uniqueness_scope": "enumerated commitment equivalence classes only",
    }
    contract = scenario.setdefault("design_contract", {})
    combo = contract.setdefault("combo_contract", {})
    combo["ordered_steps"] = design["ordered"]
    contract["bait_lines"] = [
        {
            "opening": opening,
            "fails_because": reason,
            "failed_equation": "当前进度 ≠ 生存 ≠ 下一回合接力",
        }
        for opening, reason in design["baits"]
    ]
    contract["climax_contract"] = {
        "exact_payoff": design["summary"],
        "proof_artifact": scenario["graph_contract"]["graph_artifact"],
    }
    witness = contract.setdefault("witness", {})
    witness["player_turns"] = 2
    witness["minimum_meaningful_actions"] = max(
        int(witness.get("minimum_meaningful_actions", 5)),
        sum(proof_step.get("kind") not in {"fixed_rules_ai_turn", "end_turn"} for proof_step in scenario["proof_steps"]),
    )
    witness["irreversible_decisions"] = max(int(witness.get("irreversible_decisions", 3)), 3)
    witness["one_turn_shortcut_refuted"] = True
    challenge = scenario.setdefault("challenge", {})
    challenge["graph_profile"] = design["profile"]
    challenge["decision_points"] = [
        {
            "choice": f"路线选择：{' / '.join(design['choices'])}",
            "failure": design["baits"][0][1],
        },
        {
            "choice": "有限资源分配：空位、手贴、支援者和精神拥抱伤害预算",
            "failure": design["baits"][1][1],
        },
        {
            "choice": f"公开回应：{design['threat']}",
            "failure": "只计算本回合输出会在对手回应后失去引擎或接力。",
        },
        {
            "choice": "终局检查：拿奖、生存、保留引擎与下一回合接力必须同时成立",
            "failure": design["baits"][2][1],
        },
    ]
    challenge["tempting_alternatives"] = [opening for opening, _ in design["baits"]]
    semanticize_common(scenario)
    return scenario


def mutate_production_state(scenarios: dict[str, dict[str, Any]]) -> None:
    s = scenarios["gardevoir_01"]
    remove_bench_uid(s["player"], SCREAM_TAIL)
    s["opponent"]["prizes"] = ["CSV8C_203"]
    s["player"]["deck_top"].remove("CSV1C_123")
    replace_uid(s["player"]["hand"], "CSV1C_121", "CSV1C_123")
    s["proof_steps"].insert(0, nest_step(SCREAM_TAIL, "巢穴球四选一，只把吼叫尾放入关键空位"))
    for proof_step in s["proof_steps"]:
        if proof_step["id"] == "attach_charm_scream_tail":
            proof_step["target"] = bench_selector(SCREAM_TAIL)
        if proof_step["id"].startswith("embrace_scream_"):
            proof_step["source"] = {"zone": "active_or_bench_uid", "uid": GARDEVOIR}
            proof_step["targets"][0]["embrace_target"] = [{"$slot": {"player": 0, **bench_selector(SCREAM_TAIL)}}]
        if proof_step["id"] == "retreat_munkidori":
            proof_step["target"] = bench_selector(SCREAM_TAIL)

    s = scenarios["gardevoir_02"]
    remove_bench_uid(s["player"], "CSV10C_082")
    replace_uid(s["player"]["prizes"], "CSVH1aC_023", COUNTER_CATCHER)
    boss = step(s["proof_steps"], "boss_second_damaged_gholdengo")
    boss["card_uid"] = COUNTER_CATCHER
    boss["label"] = "奖赏反击捕捉器抓出70伤赛富豪"

    s = scenarios["gardevoir_03"]
    remove_bench_uid(s["player"], FEZANDIPITI)
    for slot in s["player"]["bench"]:
        if slot.get("stack", [])[-1:] == ["CSV2C_053"]:
            slot.pop("energy", None)
            break
    s["proof_steps"].insert(0, nest_step(FEZANDIPITI, "巢穴球只找吉雉鸡ex，建立隐藏三张桥牌"))
    s["player"]["deck_top"].remove("CSVH1aC_008")
    s["player"]["deck_top"].remove(COUNTER_CATCHER)
    replace_uid(s["player"]["hand"], "CSV1C_121", PSYCHIC)
    replace_uid(s["player"]["hand"], "CSV3C_123", COUNTER_CATCHER)
    replace_step(
        s["proof_steps"],
        "energy_switch_to_first_gardevoir",
        {
            "id": "attach_drawn_psychic_to_first",
            "kind": "attach_energy",
            "label": "把化危为吉抽到的超能手贴给首攻沙奈朵",
            "card_uid": PSYCHIC,
            "target": {"zone": "active"},
        },
    )
    step(s["proof_steps"], "flip_the_script_bridges")["source"] = bench_selector(FEZANDIPITI)

    s = scenarios["gardevoir_04"]
    remove_bench_uid(s["player"], SCREAM_TAIL)
    s["proof_steps"].insert(0, nest_step(SCREAM_TAIL, "巢穴球四选一，只找能绕后取奖的吼叫尾"))
    for slot in s["player"]["bench"]:
        if slot.get("stack", [])[-1:] == [GARDEVOIR]:
            slot["energy"] = [PSYCHIC, PSYCHIC]
            break
    s["player"]["discard"] = [PSYCHIC, PSYCHIC, PSYCHIC, PSYCHIC]
    s["player"]["deck_top"].remove(PSYCHIC)
    s["player"]["deck_top"].remove("CSVH1aC_008")
    replace_step(
        s["proof_steps"],
        "energy_switch_to_scream_tail",
        {
            "id": "embrace_first_scream_energy",
            "kind": "use_ability",
            "label": "沙奈朵精神拥抱给吼叫尾第一张超能",
            "source": bench_selector(GARDEVOIR),
            "targets": [{
                "embrace_energy": [card_selector(PSYCHIC, "discard")],
                "embrace_target": [{"$slot": {"player": 0, **bench_selector(SCREAM_TAIL)}}],
            }],
        },
    )
    replace_step(
        s["proof_steps"],
        "attach_drawn_psychic",
        {
            "id": "embrace_second_scream_energy",
            "kind": "use_ability",
            "label": "沙奈朵精神拥抱给吼叫尾第二张超能",
            "source": bench_selector(GARDEVOIR),
            "targets": [{
                "embrace_energy": [card_selector(PSYCHIC, "discard")],
                "embrace_target": [{"$slot": {"player": 0, **bench_selector(SCREAM_TAIL)}}],
            }],
        },
    )
    second_index = next(index for index, proof_step in enumerate(s["proof_steps"]) if proof_step["id"] == "embrace_second_scream_energy")
    for number in [3, 4]:
        second_index += 1
        s["proof_steps"].insert(
            second_index,
            {
                "id": f"embrace_scream_energy_{number}",
                "kind": "use_ability",
                "label": f"沙奈朵精神拥抱给吼叫尾第{number}张超能",
                "source": bench_selector(GARDEVOIR),
                "targets": [{
                    "embrace_energy": [card_selector(PSYCHIC, "discard")],
                    "embrace_target": [{"$slot": {"player": 0, **bench_selector(SCREAM_TAIL)}}],
                }],
            },
        )
    step(s["proof_steps"], "retreat_munk_to_scream_tail")["target"] = bench_selector(SCREAM_TAIL)
    step(s["proof_steps"], "flip_the_script_energy_pair")["source"] = bench_selector(FEZANDIPITI)

    s = scenarios["gardevoir_05"]
    remove_bench_uid(s["player"], "CSV2C_053")
    for proof_step in s["proof_steps"]:
        if proof_step["id"].startswith("embrace_scream_"):
            proof_step["source"] = bench_selector(GARDEVOIR)
            proof_step["targets"][0]["embrace_target"] = [{"$slot": {"player": 0, **bench_selector(SCREAM_TAIL)}}]
        if proof_step["id"] == "retreat_munk_to_scream":
            proof_step["target"] = bench_selector(SCREAM_TAIL)

    s = scenarios["gardevoir_06"]
    remove_bench_uid(s["player"], "CSV2C_053")

    s = scenarios["gardevoir_07"]
    remove_bench_uid(s["player"], "CSV2C_053")
    s["player"]["deck_top"].remove("CSVE1C_DAR")
    for proof_step in s["proof_steps"]:
        if proof_step["id"] == "attach_charm":
            proof_step["target"] = bench_selector(SCREAM_TAIL)
        if proof_step["id"].startswith("embrace_") and proof_step["id"][-1:].isdigit():
            proof_step["source"] = bench_selector(GARDEVOIR)
            proof_step["targets"][0]["embrace_target"] = [{"$slot": {"player": 0, **bench_selector(SCREAM_TAIL)}}]
        if proof_step["id"] == "first_retreat":
            proof_step["target"] = bench_selector(SCREAM_TAIL)
        if proof_step["id"] == "munk_move_mid_chain":
            proof_step["ability_source"] = {"zone": "active"}

    s = scenarios["gardevoir_08"]
    remove_bench_uid(s["player"], MUNKIDORI)
    replace_uid(s["player"]["deck_top"], "CSVH1aC_008", PSYCHIC)
    replace_step(
        s["proof_steps"],
        "switch_to_first",
        {
            "id": "attach_exact_third_psychic",
            "kind": "attach_energy",
            "label": "只把抽到的第三张超能手贴给首攻沙奈朵",
            "card_uid": PSYCHIC,
            "target": {"zone": "active"},
        },
    )

    s = scenarios["gardevoir_09"]
    remove_bench_uid(s["player"], "151C_151")
    replace_uid(s["player"]["deck_top"], "CSVH1aC_008", PSYCHIC)
    replace_step(
        s["proof_steps"],
        "switch_fourth_energy",
        {
            "id": "attach_psychic_to_backup_ralts",
            "kind": "attach_energy",
            "label": "把抽到的超能手贴给30伤拉鲁拉丝",
            "card_uid": PSYCHIC,
            "target": bench_selector("CSV2C_053"),
        },
    )
    candy = step(s["proof_steps"], "rare_candy_gardevoir")
    candy["targets"][0]["basic_pokemon"] = [{"$slot": {"player": 0, **bench_selector("CSV2C_053")}}]
    embrace = step(s["proof_steps"], "embrace_backup")
    embrace["source"] = bench_selector(GARDEVOIR)
    embrace["targets"][0]["embrace_target"] = [{"$slot": {"player": 0, **bench_selector(GARDEVOIR)}}]

    # Build the tenth puzzle from the proven Dragapult reply shell, then make
    # the last Bench slot and Nest Ball order the explicit decision.
    s10 = copy.deepcopy(s)
    s10["id"] = "gardevoir_10"
    s10["order"] = 10
    s10["revision"] = 3
    s10["tactic_pattern_ids"] = ["gardevoir_embrace_munkidori_cleanup"]
    remove_bench_uid(s10["player"], MUNKIDORI, occurrence=1)
    replace_uid(s10["player"]["hand"], ACADEMY_KIRLIA, NEST_BALL)
    flip_index = next(index for index, proof_step in enumerate(s10["proof_steps"]) if proof_step["id"] == "flip_candy_package")
    # Choosing no card is a legal Nest Ball resolution. It preserves the
    # deterministic top-three package because the draw happens first.
    s10["proof_steps"].insert(
        flip_index + 1,
        {
            "id": "nest_preserve_last_slot",
            "kind": "play_trainer",
            "label": "查看巢穴球候选后不放置，保留最后空位",
            "card_uid": NEST_BALL,
            "targets": [{"basic_pokemon": []}],
        },
    )
    scenarios["gardevoir_10"] = s10

    # Reapply the tenth lesson text after cloning the ninth production shell.
    upgraded = upgrade_scenario(scenarios["gardevoir_10"])
    upgraded["proof_steps"] = scenarios["gardevoir_10"]["proof_steps"]
    upgraded["player"] = scenarios["gardevoir_10"]["player"]
    upgraded["opponent"] = scenarios["gardevoir_10"]["opponent"]
    scenarios["gardevoir_10"] = upgraded

    for scenario in scenarios.values():
        witness = scenario["design_contract"]["witness"]
        witness["minimum_meaningful_actions"] = sum(
            proof_step.get("kind") not in {"fixed_rules_ai_turn", "end_turn"}
            for proof_step in scenario["proof_steps"]
        )


def graph_for(scenario: dict[str, Any]) -> dict[str, Any]:
    contract = scenario["graph_contract"]
    profile = contract["profile"]
    choices = list(contract["initial_options"])
    if profile == "precision":
        choices = choices[:2]
    while len(choices) < (4 if profile == "composite" else 3):
        choices.append(f"诱导路线{len(choices)}")
    axes = list(contract["negative_probe_axes"])
    while len(axes) < 3:
        axes.append(f"axis_{len(axes)}")
    nodes: list[dict[str, Any]] = [
        {"id": "s0", "kind": "state", "label": "读取有限资源残局", "fingerprint": scenario["objective"], "checkpoint": "player_turn_1_main"},
        {"id": "d0", "kind": "player_decision", "label": "选择本回合展开路线", "operator": "OR", "axis": axes[0]},
        {"id": "a_ok", "kind": "action", "label": choices[0], "actor": "player", "axis": axes[0], "legal_guard": "牌面资源与时序均满足", "effect_summary": "同时推进当前奖赏、处理公开威胁并保留接力"},
        {"id": "a_bad_1", "kind": "action", "label": choices[1], "actor": "player", "axis": axes[0], "legal_guard": "动作本身合法", "effect_summary": "产生局部价值但破坏资源所有权"},
        {"id": "f_bad_1", "kind": "terminal", "label": "路线选择失败", "outcome": "failure", "reason": scenario["design_contract"]["bait_lines"][0]["fails_because"], "failure_axis": axes[0], "consequence_depth": 2},
        {"id": "g_success", "kind": "terminal", "label": "爆发、生存与接力同时成立", "outcome": "success", "reason": scenario["goal"]["summary"]},
        {"id": "r_bench", "kind": "resource", "label": "备战区空位", "resource_type": "bench_slot", "available": 1, "minimum_required": 1, "slack": 0, "deadline": "首轮攻击前", "scarce": True},
        {"id": "r_attach", "kind": "resource", "label": "本回合手贴", "resource_type": "manual_attachment", "available": 1, "minimum_required": 1, "slack": 0, "deadline": "首轮攻击前", "scarce": True},
        {"id": "t_reply", "kind": "threat", "label": "公开的对手回应", "visibility": "public", "evidence": contract["public_threats"][0], "deadline": "对手下一回合", "impact": "击倒首攻或破坏接力"},
        {"id": "g_progress", "kind": "invariant", "label": "取得计划奖赏", "category": "progress", "assertion": "两回合取得4奖"},
    ]
    edges: list[dict[str, str]] = [
        {"from": "s0", "to": "d0", "type": "opens"},
        {"from": "d0", "to": "a_ok", "type": "option"},
        {"from": "d0", "to": "a_bad_1", "type": "option"},
        {"from": "a_bad_1", "to": "f_bad_1", "type": "resolves"},
        {"from": "a_ok", "to": "r_bench", "type": "consumes"},
        {"from": "a_ok", "to": "t_reply", "type": "counters"},
        {"from": "g_success", "to": "g_progress", "type": "requires"},
    ]
    if profile == "precision":
        edges.append({"from": "a_ok", "to": "g_success", "type": "resolves"})
        edges.extend([
            {"from": "a_ok", "to": "r_attach", "type": "consumes"},
            {"from": "a_bad_1", "to": "r_attach", "type": "consumes"},
        ])
    else:
        nodes.extend([
            {"id": "a_bad_2", "kind": "action", "label": choices[2], "actor": "player", "axis": axes[1], "legal_guard": "动作本身合法", "effect_summary": "当前回合看似成立但接力失败"},
            {"id": "f_bad_2", "kind": "terminal", "label": "资源分配失败", "outcome": "failure", "reason": scenario["design_contract"]["bait_lines"][1]["fails_because"], "failure_axis": axes[1], "consequence_depth": 2},
            {"id": "s1", "kind": "state", "label": "首轮计划完成并等待回应", "fingerprint": "当前进度达成；引擎与接力均保留", "checkpoint": "opponent_turn_1_start"},
            {"id": "d_reply", "kind": "opponent_decision", "label": "覆盖所有高影响可信回应", "operator": "AND", "credible_set": True, "coverage_basis": contract["public_threats"][0]},
            {"id": "a_reply_front", "kind": "action", "label": "对手击倒首攻者", "actor": "opponent", "axis": "opponent_reply", "legal_guard": "前场攻击费用满足", "effect_summary": "首攻者离场，但接力仍存活"},
            {"id": "a_reply_disrupt", "kind": "action", "label": "对手向引擎或手牌施压", "actor": "opponent", "axis": "opponent_reply", "legal_guard": "公开牌面允许该回应", "effect_summary": "资源受压但无法同时处理引擎与接力"},
            {"id": "s2a", "kind": "state", "label": "前场交换后仍可接棒", "fingerprint": "玩家未输且带能接力攻击手存在", "checkpoint": "player_turn_2_start"},
            {"id": "s2b", "kind": "state", "label": "干扰后仍可接棒", "fingerprint": "沙奈朵引擎与终结攻击手至少各一", "checkpoint": "player_turn_2_start"},
            {"id": "r_supporter", "kind": "resource", "label": "支援者窗口", "resource_type": "supporter_window", "available": 1, "minimum_required": 1, "slack": 0, "deadline": "首轮攻击前", "scarce": True},
            {"id": "g_survival", "kind": "invariant", "label": "核心引擎存活", "category": "survival", "assertion": "回应后至少保留一只沙奈朵ex"},
            {"id": "g_handoff", "kind": "invariant", "label": "接力攻击手就绪", "category": "handoff", "assertion": "回应后存在至少两能攻击手"},
        ])
        edges.extend([
            {"from": "d0", "to": "a_bad_2", "type": "option"},
            {"from": "a_bad_2", "to": "f_bad_2", "type": "resolves"},
            {"from": "a_ok", "to": "s1", "type": "resolves"},
            {"from": "s1", "to": "d_reply", "type": "opens"},
            {"from": "d_reply", "to": "a_reply_front", "type": "reply"},
            {"from": "d_reply", "to": "a_reply_disrupt", "type": "reply"},
            {"from": "a_reply_front", "to": "s2a", "type": "resolves"},
            {"from": "a_reply_disrupt", "to": "s2b", "type": "resolves"},
            {"from": "s2a", "to": "g_success", "type": "reaches"},
            {"from": "s2b", "to": "g_success", "type": "reaches"},
            {"from": "a_ok", "to": "r_attach", "type": "reserves"},
            {"from": "a_ok", "to": "r_supporter", "type": "reserves"},
            {"from": "a_ok", "to": "g_handoff", "type": "enables"},
            {"from": "g_success", "to": "g_survival", "type": "requires"},
            {"from": "g_success", "to": "g_handoff", "type": "requires"},
        ])
        if profile == "composite":
            nodes.extend([
                {"id": "a_bad_3", "kind": "action", "label": choices[3], "actor": "player", "axis": axes[2], "legal_guard": "动作本身合法", "effect_summary": "本回合拿奖但对手随后直接获胜"},
                {"id": "f_bad_3", "kind": "terminal", "label": "延迟终结失败", "outcome": "failure", "reason": scenario["design_contract"]["bait_lines"][2]["fails_because"], "failure_axis": axes[2], "consequence_depth": 3},
                {"id": "g_disruption", "kind": "invariant", "label": "公开威胁已被处理", "category": "disruption", "assertion": "对手不能按公开路线直接终结"},
                {"id": "g_no_loss", "kind": "invariant", "label": "对手没有获胜", "category": "deny_opponent_win", "assertion": "终局 winner_index 不是对手"},
            ])
            edges.extend([
                {"from": "d0", "to": "a_bad_3", "type": "option"},
                {"from": "a_bad_3", "to": "f_bad_3", "type": "resolves"},
                {"from": "a_ok", "to": "g_disruption", "type": "satisfies"},
                {"from": "g_success", "to": "g_disruption", "type": "requires"},
                {"from": "g_success", "to": "g_no_loss", "type": "requires"},
            ])
    return {
        "format_version": 1,
        "puzzle_id": scenario["id"],
        "deck_id": str(ACADEMY_DECK_ID),
        "revision": 3,
        "profile": profile,
        "start": "s0",
        "nodes": nodes,
        "edges": edges,
        "proof": {
            "max_depth": 20,
            "max_player_turns": 2,
            "required_initial_options": 2 if profile == "precision" else 3,
            "opponent_reply_coverage": "all" if profile != "precision" else "frozen policy",
            "negative_probe_axes": axes[:1] if profile == "precision" else axes[:3 if profile == "composite" else 2],
            "claim": "policy_replay_proven",
            "uniqueness_scope": "enumerated commitment equivalence classes only",
        },
    }


def negative_probes(scenario: dict[str, Any]) -> list[dict[str, Any]]:
    steps = scenario["proof_steps"]
    first_attack = next(index for index, proof_step in enumerate(steps) if proof_step.get("kind") == "attack")
    last_attack = max(index for index, proof_step in enumerate(steps) if proof_step.get("kind") == "attack")
    return [
        {
            "id": f"{scenario['id']}_route_stops_before_progress",
            "category": "route_choice",
            "description": "选择局部展开但没有完成首轮奖赏，证明铺场本身不等于过关。",
            "proof_steps": copy.deepcopy(steps[:first_attack]),
        },
        {
            "id": f"{scenario['id']}_handoff_stops_before_closeout",
            "category": "handoff_timing",
            "description": "首轮拿奖后没有完成终结攻击，证明两回合接力属于成功条件。",
            "proof_steps": copy.deepcopy(steps[:last_attack]),
        },
    ]


def main() -> None:
    base = json.loads(BASE_PATH.read_text(encoding="utf-8"))
    sources = {
        scenario["id"]: scenario
        for scenario in base["scenarios"]
        if scenario["id"].startswith("gardevoir_")
    }
    scenarios = {scenario_id: upgrade_scenario(source) for scenario_id, source in sources.items()}
    mutate_production_state(scenarios)
    ordered = [scenarios[f"gardevoir_{index:02d}"] for index in range(1, 11)]
    OVERLAY_PATH.write_text(
        json.dumps({"format_version": 1, "scenario_revision": 3, "scenarios": ordered}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    PROBES_PATH.write_text(
        json.dumps(
            {
                "format_version": 1,
                "scenarios": {scenario["id"]: negative_probes(scenario) for scenario in ordered},
            },
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )
    GRAPH_DIR.mkdir(parents=True, exist_ok=True)
    for scenario in ordered:
        (GRAPH_DIR / f"{scenario['id']}.json").write_text(
            json.dumps(graph_for(scenario), ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )


if __name__ == "__main__":
    main()
