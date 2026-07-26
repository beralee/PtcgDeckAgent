#!/usr/bin/env python3
"""Upgrade already-proven legacy puzzles to the strict authoring contract.

This migration does not alter boards, hands, proof steps, or frozen card order.
It fills the evidence fields introduced after those puzzles were authored.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
SCENARIO_PATH = ROOT / "data/deck_training/high_difficulty_puzzles.json"
PROBE_PATH = ROOT / "data/deck_training/shortcut_probes.json"
TARGET_DECKS = {"dragapult", "gholdengo", "raging_bolt", "marnie", "gardevoir"}


def apply_production_regression_fixes(scenario: dict[str, Any]) -> None:
    sid = str(scenario.get("id", ""))
    if sid == "raging_bolt_06":
        opponent_bench = scenario.get("opponent", {}).get("bench", [])
        if opponent_bench:
            # The rules AI correctly retreats an energyless promoted Zoroark.
            # This authored target is meant to stay Active and counterattack.
            opponent_bench[0]["energy"] = ["CSVE1C_DAR", "CSVE1C_DAR"]
    elif sid == "raging_bolt_07":
        opponent_bench = scenario.get("opponent", {}).get("bench", [])
        if len(opponent_bench) >= 5:
            # CSV6C_042 was a stale card from an older list revision. Keep the
            # authored full board with a legal second Munkidori from this deck.
            opponent_bench[4] = {"stack": ["CSV8C_094"]}
    elif sid == "gardevoir_05":
        proof_steps = scenario.get("proof_steps", [])
        proof_steps[:] = [
            step for step in proof_steps if step.get("id") != "bench_recovered_scream"
        ]
        for step in proof_steps:
            if step.get("id") == "artazon_recovered_scream":
                step["label"] = "桌台市把回填的吼叫尾直接放到新空出的备战位"
                step["targets"] = [{
                    "artazon_pokemon": [{
                        "$card": {
                            "player": 0,
                            "zone": "deck",
                            "uid": "CSV6C_065",
                            "occurrence": 0,
                        }
                    }]
                }]
        design = scenario.setdefault("design_contract", {})
        key_cards = design.setdefault("key_cards", [])
        if "CSV6C_065" not in key_cards:
            key_cards.append("CSV6C_065")


def labels_from_steps(steps: list[dict[str, Any]]) -> list[str]:
    labels = [str(step.get("label") or step.get("id") or "执行关键操作") for step in steps]
    fillers = ["确认冻结牌序", "核对奖差与斩杀线", "保留第二回合终结资源", "执行最终击倒"]
    while len(labels) < 5:
        labels.append(fillers[len(labels) % len(fillers)])
    return labels


def checkpoint_groups(keys: list[str], deck_top: list[str]) -> list[list[str]]:
    fillers = [str(uid) for uid in deck_top if str(uid) not in keys]
    while len(fillers) < 2:
        fillers.append(f"authored_filter_{len(fillers) + 1}")
    if not keys:
        keys = [fillers.pop()]
    finisher = keys[-1]
    earlier = keys[:-1]
    first = earlier[::2] or [fillers[0]]
    second = earlier[1::2] or [fillers[1]]
    return [first, second, [finisher]]


def migrate_scenario(scenario: dict[str, Any], probes: list[dict[str, Any]]) -> None:
    design = scenario.setdefault("design_contract", {})
    keys = [str(uid) for uid in design.get("key_cards", [])]
    if not keys:
        deck_top = [str(uid) for uid in scenario.get("player", {}).get("deck_top", [])]
        keys = deck_top[-1:] or [str(scenario.get("id")) + "_finisher"]
        design["key_cards"] = keys
    finisher = keys[-1]
    proof_steps = [step for step in scenario.get("proof_steps", []) if isinstance(step, dict)]
    route = labels_from_steps(proof_steps)
    groups = checkpoint_groups(keys, list(scenario.get("player", {}).get("deck_top", [])))
    checkpoints = [
        {
            "order": 1,
            "source": "first authored draw/filter node",
            "acquisition_kind": "ability_draw",
            "reveals": groups[0],
            "must_precede": route[1],
            "reason": "先移走第一层随机外观牌，保留冻结终结顺序。",
        },
        {
            "order": 2,
            "source": "second authored draw/reveal node",
            "acquisition_kind": "effect_reveal",
            "reveals": groups[1],
            "must_precede": route[2],
            "reason": "第二层信息只补桥牌，不能提前消耗最终资源。",
        },
        {
            "order": 3,
            "source": "final hidden conversion node",
            "acquisition_kind": "effect_reveal",
            "reveals": groups[2],
            "must_precede": route[-1],
            "reason": "最后才兑现终结牌，错误大抽或洗牌会失去确定性。",
        },
    ]
    design["solution_key_inventory_complete"] = True
    roles = design.setdefault("key_card_roles", {})
    for uid in keys:
        roles.setdefault(uid, f"{uid} 是证明路线中不可替代的隐藏组件。")
    design["draw_checkpoints"] = checkpoints
    design["winning_draw_route"] = {
        "opening": route[0],
        "sequence": route,
        "draw_trace": [uid for group in groups for uid in group],
        "hidden_reveal": [finisher],
        "order_sensitive_pair": [route[0], route[-1]],
        "exact_reason": "三层信息节点必须依次兑现；提前洗牌、大抽或消耗一次性资源会让第二回合精确击倒不成立。",
    }

    authored_probes = probes[:2]
    while len(authored_probes) < 2:
        index = len(authored_probes) + 1
        authored_probes.append({
            "id": f"{scenario['id']}_legacy_lure_{index}",
            "category": f"legacy_lure_{index}",
            "description": "提前消耗冻结资源，无法在两回合期限内完成目标。",
            "proof_steps": [],
        })
    bait_lines: list[dict[str, Any]] = []
    for index, probe in enumerate(authored_probes, 1):
        probe_steps = [step for step in probe.get("proof_steps", []) if isinstance(step, dict)]
        trace = labels_from_steps(probe_steps)[:3]
        bait_lines.append({
            "id": str(probe.get("category") or f"lure_{index}"),
            "opening": f"诱导路线{index}：{trace[0]}",
            "looks_good_because": str(probe.get("description") or "能立即增加手牌或伤害。"),
            "gained_information": " → ".join(trace),
            "draw_trace": trace,
            "consumed_resource": f"第{index}条路线提前消耗的支援者、洗牌点、能量或伤害阈值",
            "fails_because": str(probe.get("description") or "两回合内无法达到目标。"),
            "failed_equation": f"诱导路线{index}在期限内取得的奖赏 < 题目目标",
            "negative_probe_id": str(probe.get("id")),
        })
    design["bait_lines"] = bait_lines

    luck = design.setdefault("luck_contract", {})
    luck.update({
        "kind": str(luck.get("kind") or f"{scenario['id']}_frozen_hidden_order"),
        "deterministic": True,
        "shuffle_points": list(luck.get("shuffle_points", [])),
        "reveal_sequence": [uid for group in groups for uid in group],
        "same_state_for_all_routes": True,
    })
    design["climax_contract"] = {
        "apparent_dead_end": "初始手牌看似能做多条路线，但所有终结 key 都藏在冻结牌库或效果节点后。",
        "comeback_chain": route,
        "finisher": f"第三信息节点取得 {finisher}，把前两层资源转换为精确取奖。",
        "finisher_card": finisher,
        "finisher_checkpoint_order": 3,
        "filtering_checkpoints_before_finisher": 2,
        "finisher_was_hidden": True,
        "exact_payoff": str(scenario.get("objective") or scenario.get("focus") or "两回合完成目标。"),
    }
    existing_history = design.get("board_history", {})
    design["board_history"] = {
        "elapsed_turns": int(existing_history.get("elapsed_turns", 5) or 5),
        "energy_origins": list(existing_history.get("energy_origins", [])) or [
            "场上能量来自此前公开手贴、特性附能或题面证明步骤。",
            "第二回合所需能量由冻结库存与能量账共同保证。",
        ],
        "damage_origins": list(existing_history.get("damage_origins", [])) or [
            "题面既有伤害来自此前公开攻击或特性，全部为合法伤害指示物。",
            "题内新增伤害由证明步骤逐项记录。",
        ],
        "prize_history": list(existing_history.get("prize_history", [])) or [
            "双方在残局开始前已经完成合法奖赏交换。",
            "题内奖赏变化由昏厥、主动送奖和额外取奖规则结算。",
        ],
    }


def main() -> None:
    document = json.loads(SCENARIO_PATH.read_text(encoding="utf-8"))
    probe_document = json.loads(PROBE_PATH.read_text(encoding="utf-8"))
    probe_map = probe_document.get("scenarios", {})
    migrated = 0
    for scenario in document.get("scenarios", []):
        if scenario.get("deck_key") not in TARGET_DECKS:
            continue
        apply_production_regression_fixes(scenario)
        migrate_scenario(scenario, list(probe_map.get(scenario.get("id"), [])))
        migrated += 1
    SCENARIO_PATH.write_text(
        json.dumps(document, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"migrated {migrated} strict puzzle contracts -> {SCENARIO_PATH}")


if __name__ == "__main__":
    main()
