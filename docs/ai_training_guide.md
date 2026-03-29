# AI Training Guide

This document records the current training workflow for the PTCG practice AI.
It covers the existing Phase 5.1 and Phase 5.2 pipeline, the benchmark gate,
and the first completed training run on 2026-03-28.

## Scope

Short term goal:

- Make the AI stronger inside the fixed three-deck environment.
- Keep the training loop repeatable and benchmark-gated.
- Publish only validated versions for in-game play.

Fixed deck pool:

- Miraidon
- Gardevoir
- Charizard ex

## Prerequisites

- Godot 4.6 or newer, console build preferred for headless runs.
- Python 3.10 or newer.
- PyTorch dependencies for value-net training.

Install Python dependencies:

```bash
pip install -r scripts/training/requirements.txt
```

User data folders:

- AI agents: `%APPDATA%/Godot/app_userdata/PTCG Train/ai_agents/`
- Training data: `%APPDATA%/Godot/app_userdata/PTCG Train/training_data/`
- AI version registry: `user://ai_versions`
- Training run registry: `user://training_runs`

## Phase 5.1: Evolution Tuning

Purpose:

- Search for stronger heuristic and MCTS parameters.
- Produce self-play data for the next value-net stage.

Current runner:

- Scene: `res://scenes/tuner/TunerRunner.tscn`
- Script: `scenes/tuner/TunerRunner.gd`

Core loop:

1. Start from the current baseline or a provided agent config.
2. Mutate heuristic weights and MCTS parameters.
3. Run candidate vs baseline inside the fixed three-deck pool.
4. Accept the candidate only if it beats the baseline.
5. Export self-play data when `--export-data` is enabled.

Common command:

```bash
"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --quit-after 3600 --path . res://scenes/tuner/TunerRunner.tscn -- --generations=50 --export-data
```

Continue from the latest stored agent:

```bash
"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --quit-after 3600 --path . res://scenes/tuner/TunerRunner.tscn -- --generations=50 --from-latest --export-data
```

Start from a specific promoted agent and value net:

```bash
"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --quit-after 3600 --path . res://scenes/tuner/TunerRunner.tscn -- --generations=20 --agent-config=user://ai_agents/agent_v015.json --value-net=D:/models/value_net_v3.json --export-data
```

Supported arguments:

| Argument | Default | Meaning |
| --- | --- | --- |
| `--generations=N` | `50` | Number of generations |
| `--sigma-w=F` | `0.15` | Heuristic weight mutation scale |
| `--sigma-m=F` | `0.10` | MCTS config mutation scale |
| `--max-steps=N` | `200` | Per-game hard cap |
| `--from-latest` | off | Load latest agent from `AgentVersionStore` |
| `--agent-config=PATH` | empty | Start from a specific agent config |
| `--value-net=PATH` | empty | Attach a value net during search |
| `--export-data` | off | Export self-play samples |

Practical notes:

- A short improvement cycle is usually `20-30` generations.
- Use `50` generations when you want a fuller tuning pass.
- The three-deck environment is intentionally narrow. Do not use it as a
  general ladder benchmark.

## Phase 5.2: Value Net Training

Purpose:

- Train a value network from exported self-play samples.
- Reinject the network into MCTS for the next tuning round.

Data generation:

```bash
"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --quit-after 3600 --path . res://scenes/tuner/TunerRunner.tscn -- --generations=20 --export-data --from-latest
```

Training command:

```bash
python scripts/training/train_value_net.py --data-dir "%APPDATA%/Godot/app_userdata/PTCG Train/training_data" --output "./models/value_net_v1.json" --epochs 100 --batch-size 256 --lr 0.001
```

Current encoder / network assumptions:

- `StateEncoder` input dimension is 44.
- The exported records are JSON game samples.
- Validation loss is useful, but it is not the promotion gate.

Healthy signals:

- Validation loss keeps trending down.
- The model beats the previous promoted baseline in benchmark.
- In-game play shows fewer obviously bad sequencing mistakes.

Weak signals:

- Train loss drops but validation loss stalls.
- Benchmark does not clear the fixed gate.
- The new model looks different but not stronger during manual play.

## Benchmark Gate

Promotion is not based on loss alone.

Current benchmark runner:

- Scene: `res://scenes/tuner/BenchmarkRunner.tscn`
- Script: `scenes/tuner/BenchmarkRunner.gd`

The benchmark gate compares:

- candidate agent config + candidate value net
- against current best agent config + current best value net

The benchmark is fixed to the same three-deck environment.

Default promotion rule:

- Candidate total win rate vs current best must be at least `0.55`.
- Pairing-level regression gates must also pass.
- Only benchmark-passed artifacts become playable AI versions.

Example command:

```bash
"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path . res://scenes/tuner/BenchmarkRunner.tscn -- --agent-a-config=user://ai_agents/agent_candidate.json --agent-b-config=user://ai_agents/agent_v015.json --value-net-a=D:/models/value_net_candidate.json --value-net-b=D:/models/value_net_v3.json --summary-output=user://benchmark_summary.json --run-id=run_20260328_01 --pipeline-name=fixed_three_deck_training --run-dir=user://training_runs/run_20260328_01 --run-registry-dir=user://training_runs --version-registry-dir=user://ai_versions --publish-display-name=iter-01-candidate
```

## Versioned Training Loop

Preferred automation entry point:

- `scripts/training/train_loop.sh`

The loop does this per iteration:

1. Run a short self-play evolution phase.
2. Move exported samples into a run-specific folder.
3. Train a new value net.
4. Benchmark candidate vs current best.
5. Publish a playable AI version only if the gate passes.

Typical command:

```bash
bash scripts/training/train_loop.sh --godot "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --iterations 5 --generations 20 --epochs 100 --model-dir "./models"
```

Recommended operating rhythm:

- Use `20-30` generations per iteration.
- Keep only recent, relevant self-play data in active focus.
- Review both benchmark summaries and in-game behavior.
- Publish only versions you are willing to expose in the UI.

## In-Game Validation

Do not rely on reports only.

The game should let you choose:

- built-in default AI
- latest promoted training AI
- a specific promoted AI version

Manual review checklist:

- Opening attachment choices are less wasteful.
- Trainer timing is more coherent.
- Attack vs setup decisions are less random.
- Evolution and bench development are smoother.
- Obviously bad turns happen less often.

When giving feedback, refer to the exact version id, for example:

- `AI-20260328-01 is too passive`
- `AI-20260328-02 sequences trainers better`

## Run Report: 2026-03-28 Phase 5.1

This was the first completed parallel tuning report that produced a usable
baseline for the current design.

Configuration:

- 50 generations x 10 parallel lanes
- fresh starting points, no `--from-latest`

Summary:

| Metric | Value |
| --- | --- |
| Run time | 12:54 to 16:46, about 4 hours |
| Total mutation attempts | 500 |
| Accepted versions | 10 |
| Overall acceptance rate | about 2 percent |
| Best observed win rate | 58.3 percent, version `v015`, generation 15 |
| Peak memory after leak fix | about 125 MB per process |

Observed accepted version chain:

```text
12:54 | v008 | gen  8 | 54.2% | independent start, lane A
12:59 | v009 | gen  9 | 54.2% | from v008
13:15 | v009 | gen  9 | 54.2% | independent start, lane B
13:15 | v012 | gen 12 | 54.2% | from lane A v009
13:21 | v013 | gen 13 | 54.2% | from v012
13:34 | v015 | gen 15 | 58.3% | from v013, best result
13:47 | v017 | gen 17 | 58.3% | from v015
14:36 | v029 | gen 29 | 58.3% | independent start, lane C
15:42 | v040 | gen 40 | 54.2% | from v017
16:46 | v045 | gen 45 | 54.2% | independent start, lane D
```

Main takeaways:

- Acceptance rate was low, which means the baseline was already decent.
- Search still found useful improvements late in the run.
- Pure heuristic tuning improved strength, but the ceiling looked limited.
- Multiple independent lanes were useful and found different local optima.
- Fixing the `HeadlessMatchBridge` leak was required for stable long runs.

Best `v015` directional changes vs defaults:

| Parameter | Default | `v015` | Change | Interpretation |
| --- | --- | --- | --- | --- |
| `attack_knockout` | 1000 | 1085 | `+8.5%` | higher priority on finishing knockouts |
| `play_trainer` | 110 | 167 | `+52%` | more willing to use trainer cards |
| `attack_base` | 500 | 138 | `-72%` | less eager to attack before setup |
| `evolve` | 170 | 49 | `-71%` | evolution priority shifted downward |
| `play_basic` | 180 | 67 | `-63%` | lower immediate benching pressure |
| `use_ability` | 160 | 75 | `-53%` | more selective ability usage |
| `miraidon_l_attach` | 35 | 68 | `+94%` | stronger Miraidon energy attachment bias |
| `bench_dev_bonus` | 70 | 97 | `+38%` | more value on backline development |

Best `v015` MCTS direction:

| Parameter | Default | `v015` | Interpretation |
| --- | --- | --- | --- |
| `branch_factor` | 3 | 2 | narrower branch selection |
| `rollouts_per_sequence` | 20 | 9 | fewer rollouts |
| `rollout_max_steps` | 80 | 137 | deeper simulation |
| `time_budget_ms` | 3000 | 3049 | roughly unchanged |

Interpretation:

- The best search config preferred less width and more depth.
- Heuristic tuning alone was not enough for a major jump.
- Phase 5.2 was the correct next step after this report.

## FAQ

How many generations should I run?

- Start with 20 to 30 for quick improvement cycles.
- Use 50 when you want a fuller search pass.
- Stop increasing blindly once benchmark gains flatten.

How much training data is enough for a value net?

- Use at least 1000 self-play games as a practical floor.
- More data is better only if it comes from reasonably strong agents.

How do I know the AI is actually stronger?

- Benchmark candidate vs current best.
- Then play it in the game and review concrete decision quality.

What should become the next baseline?

- Only the latest benchmark-passed playable version.
- Do not promote raw intermediate outputs just because they are newer.
