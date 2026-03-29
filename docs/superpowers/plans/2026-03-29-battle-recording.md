# Battle Recording Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-match recording for local human-vs-human battles, producing `summary.log`, `detail.jsonl`, and `match.json` with full-information detailed events and lightweight summary output.

**Architecture:** Introduce a dedicated recording layer that consumes existing gameplay and UI events instead of owning battle flow. Keep summary logging close to the current right-side log, but make `detail.jsonl` the authoritative append-only event stream and generate `match.json` from it at match end.

**Tech Stack:** GDScript, Godot file APIs, existing `GameAction` / `action_logged` event flow, Godot targeted test runner

---

## File Structure

### New files

- `D:/ai/code/ptcgtrain/scripts/engine/BattleRecorder.gd`
  - Per-match lifecycle, directory creation, append-only writes, event indexing, graceful failure handling.
- `D:/ai/code/ptcgtrain/scripts/engine/BattleEventBuilder.gd`
  - Builds normalized event dictionaries for `match_started`, `state_snapshot`, `choice_context`, `action_selected`, `action_resolved`, and `match_ended`.
- `D:/ai/code/ptcgtrain/scripts/engine/BattleSummaryFormatter.gd`
  - Converts structured events or `GameAction` data into short human-readable lines for `summary.log` and future UI reuse.
- `D:/ai/code/ptcgtrain/scripts/engine/BattleRecordExporter.gd`
  - Reads in-memory or line-based event data and writes final `match.json`.
- `D:/ai/code/ptcgtrain/tests/test_battle_recorder.gd`
  - Focused tests for file creation, append ordering, failure handling, and end-of-match export.
- `D:/ai/code/ptcgtrain/tests/test_battle_summary_formatter.gd`
  - Focused tests for summary line generation and damage/result enrichment.

### Existing files to modify

- `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.gd`
  - Owns recorder lifecycle for local human-vs-human matches, captures prompt context, forwards selected actions and action results.
- `D:/ai/code/ptcgtrain/scripts/engine/GameStateMachine.gd`
  - Supplies richer action payloads where current `GameAction.data` is too thin for meaningful `action_resolved` events.
- `D:/ai/code/ptcgtrain/scripts/engine/GameAction.gd`
  - Only if needed to keep serialized action metadata stable and explicit.
- `D:/ai/code/ptcgtrain/tests/TestRunner.gd`
  - Registers the new targeted suites.
- `D:/ai/code/ptcgtrain/tests/test_game_state_machine.gd`
  - Adds small regression coverage for richer logged action payloads if `GameStateMachine` data shape changes.
- `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`
  - Adds integration-level checks that `BattleScene` produces recording artifacts without changing visible battle flow.

---

### Task 1: Add summary formatter tests and register suites

**Files:**
- Create: `D:/ai/code/ptcgtrain/tests/test_battle_summary_formatter.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/TestRunner.gd`

- [ ] **Step 1: Write failing tests for summary line generation**
  - Cover at least:
    - attack line includes attack name and damage
    - knockout line includes knocked out Pokemon name
    - prize-taking line includes prize count
    - send-out line includes replacement Pokemon name

- [ ] **Step 2: Register the `BattleSummaryFormatter` suite in `TestRunner.gd`**

- [ ] **Step 3: Run the targeted suite to confirm failure is expected**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain res://tests/TestRunner.tscn -- --suite=BattleSummaryFormatter
```

Expected:

- the new suite runs
- tests fail because the formatter does not exist yet

- [ ] **Step 4: Commit**

```powershell
git add tests/test_battle_summary_formatter.gd tests/TestRunner.gd
git commit -m "test: add battle summary formatter coverage"
```

### Task 2: Implement summary formatter

**Files:**
- Create: `D:/ai/code/ptcgtrain/scripts/engine/BattleSummaryFormatter.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_battle_summary_formatter.gd`

- [ ] **Step 1: Implement a minimal formatter for representative gameplay actions**
  - Support short lines for:
    - attack
    - damage dealt
    - knockout
    - take prize
    - send out
    - evolve
    - attach energy
    - play trainer

- [ ] **Step 2: Keep the formatter independent from `BattleScene`**
  - Input should be normalized dictionaries or `GameAction`-derived data
  - Output should be plain strings

- [ ] **Step 3: Run the targeted suite until it passes**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain res://tests/TestRunner.tscn -- --suite=BattleSummaryFormatter
```

Expected:

- PASS for the formatter suite

- [ ] **Step 4: Commit**

```powershell
git add scripts/engine/BattleSummaryFormatter.gd tests/test_battle_summary_formatter.gd
git commit -m "feat: add battle summary formatter"
```

### Task 3: Add recorder core tests

**Files:**
- Create: `D:/ai/code/ptcgtrain/tests/test_battle_recorder.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/TestRunner.gd`

- [ ] **Step 1: Write failing tests for recorder lifecycle**
  - Cover at least:
    - creates per-match directory
    - writes `summary.log`
    - appends `detail.jsonl` in stable event order
    - writes `match.json` on finalize
    - survives write failure without raising gameplay-breaking errors

- [ ] **Step 2: Register the `BattleRecorder` suite in `TestRunner.gd`**

- [ ] **Step 3: Run the targeted suite to confirm expected failure**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain res://tests/TestRunner.tscn -- --suite=BattleRecorder
```

Expected:

- the new suite runs
- tests fail because recorder/exporter files do not exist yet

- [ ] **Step 4: Commit**

```powershell
git add tests/test_battle_recorder.gd tests/TestRunner.gd
git commit -m "test: add battle recorder lifecycle coverage"
```

### Task 4: Implement recorder, event builder, and exporter

**Files:**
- Create: `D:/ai/code/ptcgtrain/scripts/engine/BattleRecorder.gd`
- Create: `D:/ai/code/ptcgtrain/scripts/engine/BattleEventBuilder.gd`
- Create: `D:/ai/code/ptcgtrain/scripts/engine/BattleRecordExporter.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_battle_recorder.gd`

- [ ] **Step 1: Implement append-only recorder session management**
  - create `match_id`
  - create directory
  - append events to `detail.jsonl`
  - append summary lines to `summary.log`

- [ ] **Step 2: Implement stable event building**
  - normalize common fields:
    - `match_id`
    - `event_index`
    - `timestamp`
    - `turn_number`
    - `phase`
    - `player_index`
    - `event_type`

- [ ] **Step 3: Implement final export to `match.json`**
  - final shape should contain:
    - `meta`
    - `initial_state`
    - `events`
    - `result`

- [ ] **Step 4: Implement graceful failure handling**
  - file write failures should only degrade recording
  - recorder APIs should return status or warning-friendly results instead of throwing

- [ ] **Step 5: Run the targeted suite until it passes**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain res://tests/TestRunner.tscn -- --suite=BattleRecorder
```

Expected:

- PASS for the recorder suite

- [ ] **Step 6: Commit**

```powershell
git add scripts/engine/BattleRecorder.gd scripts/engine/BattleEventBuilder.gd scripts/engine/BattleRecordExporter.gd tests/test_battle_recorder.gd
git commit -m "feat: add battle recording core"
```

### Task 5: Enrich engine action payloads for meaningful resolved events

**Files:**
- Modify: `D:/ai/code/ptcgtrain/scripts/engine/GameStateMachine.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/engine/GameAction.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/test_game_state_machine.gd`

- [ ] **Step 1: Write failing tests for richer logged action data**
  - Prefer representative cases:
    - attack logs include attack name plus damage or target result information
    - prize-taking logs include count or prize card identity if already known
    - send-out logs include replacement Pokemon name

- [ ] **Step 2: Extend `GameStateMachine` logging data only where current payloads are too thin**
  - do not redesign the whole action model
  - add just enough structured fields to support `action_resolved`

- [ ] **Step 3: Keep `GameAction` serialization backward-compatible where possible**

- [ ] **Step 4: Run targeted suites**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain res://tests/TestRunner.tscn -- --suite=GameStateMachine,BattleSummaryFormatter
```

Expected:

- PASS for the new payload regression tests

- [ ] **Step 5: Commit**

```powershell
git add scripts/engine/GameStateMachine.gd scripts/engine/GameAction.gd tests/test_game_state_machine.gd
git commit -m "feat: enrich battle action payloads for recording"
```

### Task 6: Wire BattleScene recorder lifecycle and prompt capture

**Files:**
- Modify: `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`

- [ ] **Step 1: Write failing integration tests for human-vs-human recording**
  - Cover at least:
    - local human-vs-human battle creates recording artifacts
    - `match_started` is written
    - a prompt-driven interaction records `choice_context`
    - a chosen action records `action_selected`
    - engine completion records `action_resolved`

- [ ] **Step 2: Add recorder lifecycle to `BattleScene`**
  - initialize recorder only for local human-vs-human matches
  - start recording after battle setup is known
  - finalize recording at game over

- [ ] **Step 3: Capture prompt and selection context in `BattleScene`**
  - hook dialog/prompt boundaries for `choice_context`
  - record selected option details without changing gameplay behavior

- [ ] **Step 4: Keep the visible right-side log logic intact**
  - only route summary lines through the formatter where helpful
  - do not redesign the log panel

- [ ] **Step 5: Run targeted suites**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain res://tests/TestRunner.tscn -- --suite=BattleUIFeatures,BattleRecorder
```

Expected:

- PASS for recording integration coverage

- [ ] **Step 6: Commit**

```powershell
git add scenes/battle/BattleScene.gd tests/test_battle_ui_features.gd
git commit -m "feat: wire battle recording into local battle scene"
```

### Task 7: Verify end to end and document residual risk

**Files:**
- Test: `D:/ai/code/ptcgtrain/tests/test_battle_summary_formatter.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_battle_recorder.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_game_state_machine.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`
- Test: `D:/ai/code/ptcgtrain/tests/TestRunner.gd`

- [ ] **Step 1: Run focused suites for the recording stack**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain res://tests/TestRunner.tscn -- --suite=BattleSummaryFormatter,BattleRecorder,GameStateMachine,BattleUIFeatures
```

Expected:

- PASS for the focused recording suites

- [ ] **Step 2: Run a compile/smoke suite before broader validation**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain res://tests/TestRunner.tscn -- --suite=CompileCheck
```

Expected:

- PASS

- [ ] **Step 3: Launch a manual local human-vs-human smoke**
  - start a local match
  - perform a few representative actions
  - confirm all three files appear under `user://match_records/<match_id>/`

- [ ] **Step 4: Run `git diff --check`**

- [ ] **Step 5: Summarize remaining limitations**
  - first release is local human-vs-human only
  - no replay UI yet
  - AI-specific decision payloads are still future work
