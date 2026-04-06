# Retreat Energy Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add explicit retreat Energy selection before bench selection when the player has more attached Energy than the retreat cost requires.

**Architecture:** Extend the BattleScene retreat interaction into a two-step UI flow. Use the existing card-selection dialog for attached Energy choice, store the selected discard set in dialog state, then reuse the existing `retreat_bench` field-slot flow to finish the retreat.

**Tech Stack:** Godot 4.6, GDScript, BattleScene UI flow, existing headless UI regression tests

---

### Task 1: Add Failing UI Regressions

**Files:**
- Modify: `tests/test_battle_ui_features.gd`
- Test: `tests/test_battle_ui_features.gd`

- [ ] **Step 1: Write a failing regression for retreat with extra attached Energy**
- [ ] **Step 2: Run the focused suite and confirm the new retreat-selection test fails**
- [ ] **Step 3: Add a regression for passing the selected Energy cards into retreat resolution**
- [ ] **Step 4: Run the focused suite again and confirm both new tests fail for the expected reason**
- [ ] **Step 5: Keep the existing zero-cost retreat regression unchanged**

### Task 2: Implement Two-Step Retreat UI

**Files:**
- Modify: `scenes/battle/BattleScene.gd`
- Test: `tests/test_battle_ui_features.gd`

- [ ] **Step 1: Add retreat selection state helpers in BattleScene**
- [ ] **Step 2: Route retreat into card selection when discard choice is needed**
- [ ] **Step 3: Transition the confirmed Energy selection into the existing bench-choice flow**
- [ ] **Step 4: Ensure zero-cost and exact-cost cases still skip directly to bench choice**
- [ ] **Step 5: Re-run the focused UI suite and confirm the retreat tests pass**

### Task 3: Verify No Engine Regression

**Files:**
- Test: `tests/test_game_state_machine.gd`
- Test: `tests/test_battle_ui_features.gd`

- [ ] **Step 1: Re-run the retreat-focused GameStateMachine tests**
- [ ] **Step 2: Re-run the BattleScene retreat-focused UI tests**
- [ ] **Step 3: Confirm the selected Energy cards are what `GameStateMachine.retreat()` receives**
- [ ] **Step 4: Confirm zero-cost retreat still discards nothing**
- [ ] **Step 5: Record verification output for handoff**
