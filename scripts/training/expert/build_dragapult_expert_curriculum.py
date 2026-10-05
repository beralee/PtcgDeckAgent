"""Author open teaching positions; never manufacture reference action labels."""
from __future__ import annotations

import copy
import hashlib
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
DREEPY, DRAK, PULT = "CSV8C_157", "CSV8C_158", "CSV8C_159"
BUD, MUNK, HAWK, FEZ = "CSV9.5C_004", "CSV8C_094", "CSV1C_079", "CSV8C_135"
DUSK, CLOPS, NOIR = "CSV8C_081", "CSV8C_082", "CSV8C_083"
LATIAS, BEAR = "CSV9C_078", "CSV8C_172"
FIRE, PSY, LUM, NEO = "CSVE1C_FIR", "CSVE1C_PSY", "CSV1C_127", "CSV7C_203"
PAD, BALL, POFFIN = "30thC_102", "30thC_101", "CSV7C_177"
STRETCHER, CANDY = "CSV8C_183", "CSVH1C_045"
LILLIE, BOSS, IONO = "30thDC_040", "30thDC_039", "CSV3C_123"
CATCHER, TURO, TOWER = "CSV6C_114", "CSV6C_125", "CSV8C_203"


def slot(card, energy=(), damage=0, **extra):
    stack = {PULT: [DREEPY, DRAK, PULT], DRAK: [DREEPY, DRAK],
             CLOPS: [DUSK, CLOPS], NOIR: [DUSK, CLOPS, NOIR]}.get(card, [card])
    return dict(stack=stack, energy=list(energy), damage=damage, **extra)


def player(active, bench=(), hand=(), discard=(), prizes=4):
    return dict(active=active, bench=list(bench), hand=list(hand), discard=list(discard), prize_count=prizes)


def opponent():
    return player(slot(PULT, [NEO]), [slot(DREEPY), slot(FEZ)],
                  [LILLIE, DRAK, PSY], prizes=3)


def curriculum():
    cases = []

    def add(family, topic, title, own, opp=None, turns=1, turn=7, **flags):
        order = len(cases) + 1
        flags.setdefault("last_knockout_turn_against", [-999, -999])
        flags.setdefault("last_knockout_during_opponent_turn_against", [-999, -999])
        flags.setdefault("knockout_provenance_tracked_against", [True, True])
        cases.append(dict(
            id=f"expert-dragapult185-{order:02d}", revision=1, order=order,
            training_mode="expert_play_v1", deck_key="dragapult185_expert",
            player_deck_id=675701, opponent_deck_id=675701, opponent_name="18.5 多龙",
            family_id=family, topic=topic, title=title,
            split_group="dragapult185-expert-v1", origin="authored_open_position",
            prompt="按你的实战判断打完这段牌。你可以选择拿奖、培养、控场或保留资源；无需凑操作数。",
            turn_limit=turns, turn_number=turn, first_player_index=0 if turn % 2 else 1,
            player=own, opponent=opp or opponent(), **flags))

    # Each family has three materially different resource/board conditions.
    own = player(slot(PULT, [FIRE, PSY], 30), [slot(DREEPY)], [PAD, LUM, LILLIE])
    opp = opponent(); opp["bench"][0]["damage"] = 40
    add("transfer", "转伤与能量", "局面里的第三十点", own, opp)
    clean = copy.deepcopy(own); clean["active"]["damage"] = 0
    add("transfer", "转伤与能量", "相似场面，重新判断", clean, copy.deepcopy(opp))
    scarce = copy.deepcopy(own); scarce["active"]["energy"] = [PSY]
    add("transfer", "转伤与能量", "唯一夜光给谁", scarce, copy.deepcopy(opp))

    own = player(slot(PULT, [FIRE, PSY]), [slot(DRAK)], [BOSS, LILLIE, LUM, PULT], prizes=2)
    opp = opponent(); opp["bench"][1]["damage"] = 20
    add("supporter", "支援者取舍", "最后两奖之前", own, opp)
    unready = copy.deepcopy(own); unready["active"]["energy"] = [PSY]
    unready["hand"] = [BOSS, LILLIE, STRETCHER]; unready["discard"] = [FIRE]
    add("supporter", "支援者取舍", "手里有路，先走哪条", unready, copy.deepcopy(opp))
    free_gust = copy.deepcopy(own); free_gust["prize_count"] = 4; free_gust["hand"].append(CATCHER)
    add("supporter", "支援者取舍", "落后时的调度", free_gust, copy.deepcopy(opp))

    own = player(slot(PULT, [PSY]), [slot(DRAK)], [STRETCHER, BOSS], [FIRE, PULT], prizes=2)
    opp = opponent(); opp["bench"][1]["damage"] = 20
    add("recovery", "担架回收", "弃牌区的那张牌", own, opp)
    evolve = copy.deepcopy(own); evolve["active"] = slot(DRAK, [FIRE, PSY]); evolve["discard"] = [PULT, DUSK]
    add("recovery", "担架回收", "缺的是能量还是身体", evolve, copy.deepcopy(opp))
    chain = player(slot(PULT, [PSY]), [slot(DRAK)], [STRETCHER, STRETCHER, LILLIE], [FIRE, PULT])
    add("recovery", "担架回收", "两张担架的次序", chain)

    own = player(slot(DRAK, [FIRE, PSY]), [slot(DREEPY)], [PULT, BALL, LILLIE, DUSK])
    add("information", "信息与进化", "进化之前还有什么", own)
    second = copy.deepcopy(own); second["bench"] = [slot(DRAK)]
    add("information", "信息与进化", "两个引擎怎么用", second)
    fresh = copy.deepcopy(own); fresh["bench"] = [slot(DREEPY, turn_played=7)]; fresh["hand"].append(CANDY)
    add("information", "信息与进化", "新上场的一只", fresh)

    own = player(slot(BUD, turn_played=2), [slot(DREEPY, turn_played=2)], [POFFIN, PAD, PSY, LILLIE], prizes=6)
    opp = player(slot(BUD), [slot(DREEPY), slot(DUSK)], [POFFIN, LILLIE, PSY], prizes=6)
    add("budew", "开局与控场", "开局的小花", own, opp, turn=2, turns=2)
    own2 = player(slot(BUD), [slot(DRAK, [PSY])], [PULT, FIRE, LILLIE, LATIAS], prizes=5)
    add("budew", "开局与控场", "控场后的交接", own2, turns=2)
    own3 = copy.deepcopy(own2); own3["hand"] = [PULT, PAD, LILLIE, TOWER]
    add("budew", "开局与控场", "还差一个回合", own3, turns=2)

    own = player(slot(BUD), [slot(DRAK, [PSY]), slot(DUSK), slot(DREEPY)], [PULT, LUM, LILLIE], prizes=4)
    add("handoff", "保护与交棒", "前场之后谁接班", own, turns=2)
    with_monkey = copy.deepcopy(own); with_monkey["bench"].append(slot(MUNK))
    add("handoff", "保护与交棒", "多一个承伤选择", with_monkey, turns=2)
    ready = copy.deepcopy(own); ready["bench"][0] = slot(PULT, [FIRE, PSY]); ready["hand"] = [LUM, LILLIE, DRAK]
    add("handoff", "保护与交棒", "主力已经就绪", ready, turns=2)

    own = player(slot(PULT, [FIRE, PSY]), [slot(DRAK)], [HAWK, BOSS, LUM, LILLIE])
    opp = player(slot(PULT, [NEO]), [slot(DREEPY), slot(LATIAS), slot(FEZ)], [LILLIE], prizes=3)
    add("hawlucha", "十点与多奖", "两个十点落在哪里", own, opp)
    squeezed = copy.deepcopy(own)
    squeezed["bench"] = [slot(DRAK), slot(DUSK), slot(BUD), slot(MUNK), slot(FEZ)]
    squeezed["hand"].append(TURO)
    add("hawlucha", "十点与多奖", "满后场的选择", squeezed, copy.deepcopy(opp))
    no_boss = copy.deepcopy(own); no_boss["hand"].remove(BOSS)
    add("hawlucha", "十点与多奖", "这一轮与下一轮", no_boss, copy.deepcopy(opp))

    own = player(slot(PULT, [FIRE, PSY]), [slot(DRAK, [LUM])], [PULT, BOSS, LILLIE])
    opp = opponent(); opp["bench"] = [slot(DREEPY, damage=10), slot(DUSK, damage=10), slot(FEZ)]
    add("spread", "伤害分配", "六个指示物的去处", own, opp)
    wounded = copy.deepcopy(opp); wounded["bench"][0]["damage"] = 40; wounded["bench"][1]["damage"] = 30
    add("spread", "伤害分配", "两条收奖线", copy.deepcopy(own), wounded)
    finish = copy.deepcopy(own); finish["prize_count"] = 1
    add("spread", "伤害分配", "只剩一张奖赏", finish, copy.deepcopy(opp))

    own = player(slot(DRAK, [PSY]), [slot(DRAK)], [PULT, LUM, NEO, LILLIE])
    add("energy", "稀缺能量", "双线的能源预算", own)
    special = copy.deepcopy(own); special["active"]["energy"] = [LUM]
    add("energy", "稀缺能量", "特殊能量的相处", special)
    reset = player(slot(PULT, [FIRE, PSY], 280), [slot(DRAK)], [TURO, PULT, LUM, STRETCHER])
    add("energy", "稀缺能量", "撤回主力的代价", reset)

    own = player(slot(PULT, [FIRE, PSY], 30), [slot(CLOPS), slot(DRAK)], [NOIR, CATCHER, IONO, LILLIE], prizes=3)
    opp = opponent(); opp["active"]["damage"] = 70; opp["prize_count"] = 2
    add("dusknoir", "自爆与奖赏", "一张奖赏的交换", own, opp)
    danger = copy.deepcopy(opp); danger["prize_count"] = 1
    add("dusknoir", "自爆与奖赏", "危险的最后一奖", copy.deepcopy(own), danger)
    equal = copy.deepcopy(opp); equal["prize_count"] = 3
    add("dusknoir", "自爆与奖赏", "同奖时的顺序", copy.deepcopy(own), equal)

    own = player(slot(BUD), [slot(DRAK, [PSY]), slot(FEZ)], [PULT, LUM, LILLIE, BALL], [DREEPY], prizes=4)
    add("fezandipiti", "吉雉鸡与补牌", "失去一只之后", own,
        last_knockout_turn_against=[6, -999], last_knockout_during_opponent_turn_against=[6, -999], knockout_provenance_tracked_against=[True, True])
    add("fezandipiti", "吉雉鸡与补牌", "同样手牌的新回合", copy.deepcopy(own),
        last_knockout_turn_against=[4, -999], last_knockout_during_opponent_turn_against=[4, -999], knockout_provenance_tracked_against=[True, True])
    deploy = copy.deepcopy(own); deploy["bench"].pop(); deploy["hand"] = [BALL, PULT, LUM, LILLIE, DUSK]
    add("fezandipiti", "吉雉鸡与补牌", "从手牌开始搭桥", deploy,
        last_knockout_turn_against=[6, -999], last_knockout_during_opponent_turn_against=[6, -999], knockout_provenance_tracked_against=[True, True])

    own = player(slot(BUD), [slot(DREEPY, [PSY]), slot(BEAR)], [CANDY, PULT, FIRE, LATIAS, LILLIE], prizes=2)
    opp = opponent(); opp["prize_count"] = 1; opp["active"]["damage"] = 80
    add("endgame", "跳阶与终结", "终局的两个攻击手", own, opp)
    expensive = copy.deepcopy(opp); expensive["prize_count"] = 4
    add("endgame", "跳阶与终结", "终局还没有到", copy.deepcopy(own), expensive)
    recent = copy.deepcopy(own); recent["bench"][0]["turn_played"] = 7
    add("endgame", "跳阶与终结", "刚刚铺下的后继", recent, copy.deepcopy(opp))
    return cases


def main():
    source = ROOT / "data/bundled_user/decks/675701.json"
    raw = source.read_bytes()
    deck = json.loads(raw)
    pool = Counter({f"{c['set_code']}_{c['card_index']}": c["count"] for c in deck["cards"]})
    cases = curriculum()
    assert len(cases) == 36 and sum(pool.values()) == 60
    for case in cases:
        for side in ("player", "opponent"):
            setup = case[side]
            used = Counter(setup.get("hand", []) + setup.get("discard", []) + setup.get("prizes", []))
            for pokemon in [setup["active"]] + setup["bench"]:
                used.update(pokemon["stack"] + pokemon["energy"])
            assert not used - pool, (case["id"], side, used - pool)
            assert len(setup["bench"]) <= 5
    destination = ROOT / "data/deck_training/decks/675701.json"
    destination.write_bytes(raw)
    payload = dict(schema_version=1, curriculum_id="dragapult185-expert-v1", title="多龙 18.5 · 专家共创",
                   deck_id=675701, deck_sha256=hashlib.sha256(raw).hexdigest(),
                   question_count=len(cases), scenarios=cases)
    path = ROOT / "data/deck_training/dragapult185_expert.json"
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"questions": len(cases), "families": 12, "deck_sha256": payload["deck_sha256"]}))


if __name__ == "__main__":
    main()
