# Repository Workflow

## Source Map

Read:

```text
data/bundled_user/decks/<deck_id>.json
data/bundled_user/cards/<uid>.json
scripts/engine/EffectRegistry.gd
scripts/effects/**
scripts/ai/DeckStrategyV18ProfileCatalog.gd
scripts/ai/DeckStrategyV18<Deck>.gd
data/deck_training/scenarios.json
data/deck_training/*_puzzles.json
data/deck_training/tactic_recipes.json
data/deck_training/pipeline_targets.json
scripts/training/DeckTrainingCatalog.gd
scripts/training/DeckTrainingStateFactory.gd
scripts/training/DeckTrainingGoalEvaluator.gd
scripts/training/DeckTrainingSession.gd
scripts/training/DeckTrainingAdmissionVerifier.gd
scripts/training/proof/**
scripts/training/pipeline/DeckTrainingPuzzlePipeline.gd
tests/test_deck_training_poc.gd
tests/test_deck_training_puzzle_pipeline.gd
```

Use `rg` to locate exact effect classes/tests. Read card text and implementation together.

## Runtime Limits

- Goals currently support `prizes` and `target_knockouts`.
- Target knockouts follow opening instance IDs through switching.
- State consumes only frozen 60-card-list cards.
- `deck_top` is ordered before remaining pool.
- `deck_size` supports thin/empty decks.
- `last_knockout_turn_against` seeds comeback facts.
- Two-turn results judge after the second player turn.
- Replaced content must increment `revision`.
- Rules AI owns the middle turn; do not assume slot layout remains fixed.

## Authoring Contract

Add to every scenario:

```json
{
  "revision": 3,
  "design_contract": {
    "learning_axis": "supporter_quota_draw_order",
    "combo_id": "gholdengo_coin_arven_retrieval",
    "deck_identity": "赛富豪通过嘉奖硬币保留支援者窗口，再把手牌能量转换为精确伤害",
    "solution_key_inventory_complete": true,
    "combo_contract": {
      "prerequisites": ["场上赛富豪ex", "牌库顶已冻结", "本回合尚未使用支援者"],
      "ordered_steps": ["嘉奖硬币抽派帕", "派帕检索超级能量回收", "回收能量后攻击"],
      "payoff": "两回合取得4张奖赏卡",
      "reordered_failure": "先用博士的研究会消耗支援者次数，无法取得回收组件"
    },
    "engine_cards_in_play": ["CSV4C_089"],
    "key_cards": ["CSV1C_123", "CSV3C_115", "CSVH1aC_023"],
    "key_card_roles": {
      "CSV1C_123": "hidden bridge Supporter",
      "CSV3C_115": "searched Energy recovery payoff",
      "CSVH1aC_023": "late hidden gust finisher"
    },
    "initial_hand_decoys": ["CSV3C_123", "CSVH1C_043"],
    "random_hand_profile": {
      "functional_categories": ["Pokemon", "Supporter", "Item", "Energy"],
      "awkward_cards": ["CSV7C_177"],
      "redundant_cards": ["CSVH1C_043"],
      "plausible_openings": ["嘉奖硬币", "奇树", "先使用巢穴球"]
    },
    "hand_roles": {
      "CSV3C_123": "tempting_draw_and_shuffle_lure",
      "CSVH1C_043": "tempting_visible_search_lure",
      "CSV7C_177": "awkward_full_bench_item"
    },
    "draw_checkpoints": [
      {
        "order": 1,
        "source": "CSV4C_089::嘉奖硬币",
        "acquisition_kind": "ability_draw",
        "reveals": ["CSV1C_123"],
        "must_precede": "CSV3C_123",
        "reason": "先取得派帕，保留正确支援者窗口"
      },
      {
        "order": 2,
        "source": "CSV1C_123::派帕",
        "acquisition_kind": "search",
        "reveals": ["CSV3C_115"],
        "must_precede": "first_attack",
        "reason": "由隐藏抽到的派帕桥接到能量回收组件"
      },
      {
        "order": 3,
        "source": "first_knockout::Prize pickup",
        "acquisition_kind": "prize_pickup",
        "reveals": ["CSVH1aC_023"],
        "must_precede": "second_turn_gust",
        "reason": "精确首杀后才取得最终老大，绕开派帕检索产生的洗牌边界"
      }
    ],
    "winning_draw_route": {
      "opening": "CSV4C_089::嘉奖硬币",
      "sequence": ["抽到派帕", "派帕取得超级能量回收", "首杀奖赏取得老大的指令"],
      "draw_trace": ["CSV1C_123", "CSV3C_115", "CSVH1aC_023"],
      "hidden_reveal": "CSV1C_123",
      "order_sensitive_pair": ["嘉奖硬币", "派帕"],
      "exact_reason": "只有这条线同时保留支援者窗口和第二回合攻击资源"
    },
    "bait_lines": [
      {
        "id": "iono_first",
        "opening": "CSV3C_123",
        "looks_good_because": "手牌杂乱且奇树可以刷新手牌",
        "gained_information": "按当前奖赏数取得一组新手牌",
        "draw_trace": ["CSV7C_177", "CSVH1C_043", "basic_energy"],
        "consumed_resource": "本回合唯一支援者次数",
        "fails_because": "奇树将冻结的派帕洗回牌库且占用支援者次数，无法取得回收组件",
        "failed_equation": "回收能量少4张，攻击伤害少200",
        "negative_probe_id": "iono_first_loses_bridge_and_supporter_window"
      },
      {
        "id": "visible_search_first",
        "opening": "CSVH1C_043",
        "looks_good_because": "立即压缩牌库并寻找展开组件",
        "gained_information": "确认牌库中的宝可梦资源",
        "draw_trace": ["CSV4C_089"],
        "consumed_resource": "冻结的顶牌顺序",
        "fails_because": "洗牌后嘉奖硬币不再确定抽到派帕",
        "failed_equation": "缺少超级能量回收，第二回合少4能量与200伤害",
        "negative_probe_id": "visible_search_first_breaks_topdeck"
      }
    ],
    "board_capacity": {
      "player_bench": 5,
      "opponent_bench": 5
    },
    "board_roles": {
      "player.active": "primary_attacker_and_draw_engine",
      "player.bench.0": "second_turn_attacker",
      "opponent.active": "first_exact_target"
    },
    "board_exemptions": [],
    "damage_math": [
      {
        "target": "opponent.active",
        "printed_hp": 240,
        "hp_modifiers": 0,
        "existing_damage": 40,
        "planned_counter_damage": 0,
        "remaining_hp": 200,
        "final_damage": 200,
        "payment": "discard 4 Basic Energy",
        "overkill": 0
      }
    ],
    "luck_contract": {
      "kind": "ordered_hidden_topdeck",
      "deterministic": true,
      "shuffle_points": ["Arven search"],
      "reveal_sequence": ["CSV1C_123", "CSV3C_115", "CSVH1aC_023"],
      "same_state_for_all_routes": true
    },
    "energy_math": [
      {
        "checkpoint": "first_attack",
        "starting_attached": 1,
        "acquired": 4,
        "spent_or_discarded": 4,
        "attack_requirement": 1,
        "remaining_for_next_turn": 1
      }
    ],
    "climax_contract": {
      "apparent_dead_end": "手牌能量不足且对手下一回合将取胜",
      "comeback_chain": ["嘉奖硬币抽派帕", "派帕取得回收组件", "持续滤抽找到老大的指令"],
      "finisher": "老大的指令抓出两奖目标",
      "finisher_card": "CSVH1aC_023",
      "finisher_checkpoint_order": 3,
      "filtering_checkpoints_before_finisher": 2,
      "finisher_was_hidden": true,
      "exact_payoff": "第二回合精确击倒并累计取得4奖"
    },
    "board_history": {
      "elapsed_turns": 5,
      "energy_origins": ["三次手贴", "一次超级能量回收后的合法支付"],
      "damage_origins": ["前回合对手攻击留下40点伤害"],
      "prize_history": ["双方均已取得2奖，首杀后从冻结奖赏取得老大"]
    },
    "witness": {
      "player_turns": 2,
      "minimum_meaningful_actions": 7,
      "irreversible_decisions": 3,
      "one_turn_shortcut_refuted": true
    }
  }
}
```

Require a complete key-card inventory outside `player.hand`, every key in a draw
checkpoint, one three-step winning draw route rooted in a hidden key-card reveal,
actual draw traces for the winning and lure routes, two distinct lure lines with
different exact failures, deterministic same-state luck, damage and Energy rows
for intended knockouts, a plausible board history, a hidden finisher after at
least two earlier checkpoints, every legal Bench slot occupied or explicitly
exempted, five hand cards, three card categories, and three plausible openings.

## Validation

```powershell
python .codex/skills/design-ptcg-deck-training-puzzles/scripts/audit_puzzle_contract.py --project-root . --scenario-file data/deck_training/<overlay>.json --deck-key <key>
python .codex/skills/design-ptcg-deck-training-puzzles/scripts/audit_puzzle_contract.py --project-root . --scenario-file data/deck_training/<overlay>.json --scenario-id <scenario_id>
python .codex/skills/design-ptcg-deck-training-puzzles/scripts/audit_puzzle_contract.py --self-test

& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s res://tests/FocusedSuiteRunner.gd -- '--suite-script=res://tests/test_deck_training_poc.gd'
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s res://tests/FocusedSuiteRunner.gd -- '--suite-script=res://tests/test_deck_training_puzzle_pipeline.gd'
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s res://tests/FocusedSuiteRunner.gd -- '--suite-script=res://tests/test_source_encoding_audit.gd'
```

Also run focused suites for every touched effect, interaction, strategy, and UI path.
