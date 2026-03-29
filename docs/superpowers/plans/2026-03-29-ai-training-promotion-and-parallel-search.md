# AI Training Promotion And Parallel Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix serial training promotion semantics first, then prepare the codebase for safe large-scale parallel qualification search.

**Architecture:** Phase A hardens the current `train_loop.sh -> TunerRunner -> EvolutionEngine -> BenchmarkRunner` pipeline so benchmark-approved versions are the only official baselines. Phase B adds lane-safe isolation and a future heterogeneous launcher on top of those corrected semantics.

**Tech Stack:** Godot 4.6 / GDScript, Git Bash shell automation, PowerShell for local ops, JSON run registries under `user://`.

---

## File Map

| File | Responsibility |
| --- | --- |
| `scenes/tuner/TunerRunner.gd` | Parse explicit start-point args and pass them to evolution correctly |
| `scripts/ai/EvolutionEngine.gd` | Respect explicit initial config and stop leaking implicit latest-agent behavior |
| `scripts/training/train_loop.sh` | Use approved baselines only, write stronger run metadata, stop using raw latest-agent lookup as authority |
| `scripts/ai/AIVersionRegistry.gd` | Provide canonical approved/latest playable lookup helpers if needed |
| `scripts/ai/TrainingRunRegistry.gd` | Persist parent baseline, candidate artifacts, and promotion result clearly |
| `scenes/tuner/BenchmarkRunner.gd` | Record benchmark inputs/outputs needed for promotion tracing |
| `tests/test_ai_phase2_benchmark.gd` | Benchmark-runner regression checks where needed |
| `tests/test_training_run_registry.gd` | Run metadata persistence tests |
| `tests/test_ai_version_registry.gd` | Approved-version lookup tests |
| `tests/test_tuner_runner_args.gd` | New tests for explicit `--agent-config` / baseline injection |
| `scripts/training/parallel_training_launcher.ps1` | Phase B lane-isolated launcher skeleton |
| `scripts/training/test_parallel_training_launcher.ps1` | Phase B script-level tests for lane config generation |

---

### Task 1: Make `TunerRunner` Respect Explicit Baselines

**Files:**
- Create: `tests/test_tuner_runner_args.gd`
- Modify: `scenes/tuner/TunerRunner.gd`
- Modify: `tests/TestRunner.gd`

- [ ] **Step 1: Write failing tests**

Add tests that verify:
- `--agent-config=<path>` is parsed and loaded
- explicit `--agent-config` wins over implicit latest behavior
- `--from-latest` only applies when no explicit config is provided

- [ ] **Step 2: Run the targeted tests and verify they fail**

Run:

```powershell
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:/ai/code/ptcgtrain' 'res://tests/TestRunner.tscn'
```

Expected:
- new tuner-runner tests fail because explicit config is not honored yet

- [ ] **Step 3: Implement minimal parsing and load behavior**

Update `scenes/tuner/TunerRunner.gd` so it:
- parses `--agent-config=<path>`
- loads that config into `initial_config`
- uses `--from-latest` only when explicit config is absent
- keeps existing `--value-net` and `--export-data` behavior intact

- [ ] **Step 4: Re-run targeted tests**

Expected:
- new tuner-runner tests pass

### Task 2: Stop `EvolutionEngine` From Implicitly Promoting Failed Candidates

**Files:**
- Modify: `scripts/ai/EvolutionEngine.gd`
- Modify: `tests/test_tuner_runner_args.gd`

- [ ] **Step 1: Extend the failing tests**

Add coverage for:
- explicit `initial_config` bypasses `load_latest()`
- empty config fallback is still allowed in manual/default mode only

- [ ] **Step 2: Run tests and confirm failure**

- [ ] **Step 3: Implement the fix**

Update `scripts/ai/EvolutionEngine.gd` so:
- explicit initial config is authoritative
- fallback to store lookup happens only when no explicit config exists
- logs clearly print whether the run started from explicit baseline, approved latest baseline, or default config

- [ ] **Step 4: Re-run targeted tests**

Expected:
- explicit baseline tests pass

### Task 3: Make Approved Versions The Only Official Baseline Source

**Files:**
- Modify: `scripts/training/train_loop.sh`
- Modify: `scripts/ai/AIVersionRegistry.gd`
- Modify: `tests/test_ai_version_registry.gd`

- [ ] **Step 1: Write failing registry tests**

Add tests that verify:
- latest approved/playable version can be resolved directly
- failed runs do not affect the approved baseline lookup

- [ ] **Step 2: Run the registry tests and confirm failure**

- [ ] **Step 3: Implement approved-baseline lookup**

Add a helper in `AIVersionRegistry.gd` for:
- latest approved playable version
- returning both agent config path and value-net path

Update `train_loop.sh` to:
- seed `CURRENT_AGENT_CONFIG` and `CURRENT_WEIGHTS` from approved version registry first
- fall back to old defaults only when no approved version exists
- stop treating raw `ai_agents` newest file as official authority

- [ ] **Step 4: Re-run registry tests**

Expected:
- approved baseline lookup works

### Task 4: Strengthen Run Metadata And Promotion Logs

**Files:**
- Modify: `scripts/ai/TrainingRunRegistry.gd`
- Modify: `scenes/tuner/BenchmarkRunner.gd`
- Modify: `scripts/training/train_loop.sh`
- Modify: `tests/test_training_run_registry.gd`

- [ ] **Step 1: Write failing metadata tests**

Add tests that require:
- baseline paths are persisted in run records
- candidate paths are persisted in run records
- promotion result clearly distinguishes `benchmark_failed` vs `published`

- [ ] **Step 2: Run metadata tests and confirm failure**

- [ ] **Step 3: Implement metadata persistence**

Persist for every run:
- parent baseline id
- parent baseline artifact paths
- candidate artifact paths
- benchmark summary path
- benchmark decision
- published version id if any

Improve shell logs so each round prints:
- baseline source
- candidate paths
- benchmark decision

- [ ] **Step 4: Re-run metadata tests**

Expected:
- run records are self-explanatory

### Task 5: Verify Serial Promotion Chain Semantics

**Files:**
- Modify: `tests/test_ai_phase2_benchmark.gd`
- Modify: `tests/test_training_run_registry.gd`

- [ ] **Step 1: Add regression coverage**

Write tests that simulate:
- round N fails benchmark and does not become next baseline
- round N+1 still points to the last approved baseline
- round M passes benchmark and becomes the next approved baseline

- [ ] **Step 2: Run the targeted suite and confirm it fails before the final glue changes**

- [ ] **Step 3: Make any minimal glue changes needed**

Only add code if the prior tasks did not already satisfy the behavior.

- [ ] **Step 4: Re-run targeted tests**

Expected:
- serial promotion chain is enforced

### Task 6: Run Full Verification For Phase A

**Files:**
- No new files required

- [ ] **Step 1: Run focused AI tests**

Run:

```powershell
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:/ai/code/ptcgtrain' 'res://tests/TestRunner.tscn'
```

Expected:
- AI promotion and registry tests pass

- [ ] **Step 2: Run one smoke training loop**

Run:

```powershell
& 'D:\Program Files\Git\bin\bash.exe' 'scripts/training/train_loop.sh' --godot 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --iterations 1 --generations 2 --epochs 5 --model-dir './models/phase_a_smoke'
```

Expected:
- logs clearly identify baseline source and candidate artifacts
- failed benchmark does not mutate official baseline

### Task 7: Prepare Phase B Lane Isolation Skeleton

**Files:**
- Create: `scripts/training/parallel_training_launcher.ps1`
- Create: `scripts/training/test_parallel_training_launcher.ps1`

- [ ] **Step 1: Write failing script tests**

Cover:
- lane-local directory generation
- heterogeneous recipe assignment across 20 lanes
- shared approved baseline snapshot reference
- no shared mutable lane output paths

- [ ] **Step 2: Run the script tests and confirm failure**

- [ ] **Step 3: Implement launcher skeleton**

The launcher does not need to execute all 20 lanes yet. It must:
- build 20 lane configs
- assign them to conservative / standard / aggressive / deep-search groups
- materialize isolated output roots per lane
- emit a machine-readable launch plan

- [ ] **Step 4: Re-run the script tests**

Expected:
- lane-isolation config generation passes

### Task 8: Document Qualified Pool Inputs For Phase B

**Files:**
- Modify: `scripts/ai/TrainingRunRegistry.gd`
- Modify: `scripts/ai/AIVersionRegistry.gd`
- Modify: `tests/test_ai_version_registry.gd`

- [ ] **Step 1: Add failing tests for qualified-pool metadata fields**

Require placeholders for:
- lane recipe id
- parent approved baseline id
- benchmark quality summary

- [ ] **Step 2: Run tests and confirm failure**

- [ ] **Step 3: Add the metadata fields without enabling full pool orchestration yet**

- [ ] **Step 4: Re-run tests**

Expected:
- the data needed for a future qualified pool is already available
