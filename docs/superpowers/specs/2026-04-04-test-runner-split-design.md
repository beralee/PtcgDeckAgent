# Test Runner Split Design

**Goal:** Split functional tests from AI/training tests, remove unnecessary runner startup overhead, and restore fast functional regression runs without reducing coverage.

**Problem Summary**

- `tests/TestRunner.gd` currently mixes functional, AI/training, benchmark, and audit suites in one runner.
- Even when callers use `--suite=...`, the current runner still pays for the monolithic script load path.
- The current functional path is also incomplete: 83 functional tests are not registered in the main runner.
- Measured behavior on 2026-04-04:
  - `FocusedSuiteRunner` for a 2-test suite: about `0.32s`
  - `TestRunner.tscn --suite=...` for the same suite: about `2.55s`
  - Main runner functional subset: about `5.09s / 627 tests`
  - Main runner AI/training subset: about `37.31s / 254 tests`

**Design**

- Replace hard-coded suite registration with a manifest/catalog that stores:
  - suite name
  - test script path
  - suite groups
- Introduce dedicated headless entrypoints:
  - `tests/FunctionalTestRunner.gd`
  - `tests/AITrainingTestRunner.gd`
- Keep a shared runner implementation so summary/output/filter behavior stays consistent.
- Extend suite filtering so callers can select both suites and groups, while the dedicated entrypoints pin their default group.
- Define `functional` as rule/effect/state-machine/UI regression coverage.
- Define `ai_training` as AI, training, benchmark, MCTS, self-play, rollout, inference, and related support suites.
- Move the 10 currently omitted functional test files into the functional manifest so the fast path gains coverage rather than losing it.

**Testing Strategy**

- Add regression tests for:
  - group parsing
  - suite catalog coverage for required functional suites
  - dedicated runner script loadability
- Verify with targeted functional and AI/training runs using the new entrypoints.
- Compare timing before/after for a tiny suite and for the functional aggregate.

**Non-Goals**

- No gameplay logic changes.
- No attempt to parallelize tests in this pass.
- No reclassification of replay/audit/service tests beyond the approved `functional` vs `ai_training` split.
