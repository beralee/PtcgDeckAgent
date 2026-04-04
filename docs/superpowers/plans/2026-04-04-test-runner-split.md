# Test Runner Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split functional tests and AI/training tests into separate fast entrypoints while restoring full functional coverage.

**Architecture:** Replace the monolithic hard-coded runner registration with a shared suite catalog plus a shared headless runner implementation. Dedicated entry scripts select either the `functional` or `ai_training` catalog group and still support targeted `--suite=` filters.

**Tech Stack:** Godot 4.6, GDScript, existing headless test runners, PowerShell wrappers

---

### Task 1: Define the Suite Catalog and Runner Boundaries

**Files:**
- Create: `tests/TestSuiteCatalog.gd`
- Modify: `tests/TestRunner.gd`
- Modify: `scripts/tools/TestSuiteFilter.gd`
- Test: `tests/test_test_runner_filter.gd`

- [ ] **Step 1: Write failing tests for group parsing and required suite coverage**
- [ ] **Step 2: Run the targeted test file and confirm the new expectations fail**
- [ ] **Step 3: Add a suite catalog and group-aware filter support**
- [ ] **Step 4: Refactor the legacy runner to use the catalog instead of hard-coded suite registration**
- [ ] **Step 5: Re-run targeted runner/filter tests and confirm they pass**

### Task 2: Add Dedicated Functional and AI/Training Entry Points

**Files:**
- Create: `tests/SharedSuiteRunner.gd`
- Create: `tests/FunctionalTestRunner.gd`
- Create: `tests/AITrainingTestRunner.gd`
- Modify: `tests/test_parser_regressions.gd`
- Test: `tests/test_parser_regressions.gd`

- [ ] **Step 1: Add parser/load regression coverage for the new runner scripts**
- [ ] **Step 2: Run the parser regression suite and confirm it fails before implementation**
- [ ] **Step 3: Implement the shared headless runner and dedicated entry scripts**
- [ ] **Step 4: Re-run parser regressions and confirm the new entrypoints load cleanly**
- [ ] **Step 5: Keep the old runner usable for compatibility, but no longer as the fast functional default**

### Task 3: Restore Full Functional Coverage

**Files:**
- Modify: `tests/TestSuiteCatalog.gd`
- Modify: `tests/TestRunner.gd`
- Test: targeted functional runs via the new runner

- [ ] **Step 1: Add the omitted functional suites to the `functional` group**
- [ ] **Step 2: Run the functional entrypoint and confirm the added suites execute**
- [ ] **Step 3: Check that the functional test count exceeds the old `627` baseline**
- [ ] **Step 4: Verify no AI/training suites are loaded through the dedicated functional entrypoint**
- [ ] **Step 5: Keep suite names stable for existing `--suite=` usage**

### Task 4: Update Command Entrypoints and Verify Timing

**Files:**
- Modify: `scripts/run_card_audit.ps1`
- Modify: `tests/FocusedSuiteRunner.gd` if needed for consistency only
- Test: headless Godot commands

- [ ] **Step 1: Point the main functional workflow at the dedicated fast runner**
- [ ] **Step 2: Run focused functional smoke suites through the new entrypoint**
- [ ] **Step 3: Run the full functional group through the new entrypoint**
- [ ] **Step 4: Run the AI/training group through its dedicated entrypoint**
- [ ] **Step 5: Record timing and coverage deltas for the final handoff**
