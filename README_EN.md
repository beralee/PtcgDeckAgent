# PTCG Deck Agent

<p align="center">
  <a href="https://ptcg.skillserver.cn/">
    <img src="https://ptcg.skillserver.cn/dist/assets/dojo-home-design.png" alt="PTCG Deck Agent - Open PTCG Agent Arena" width="100%" />
  </a>
</p>

<p align="center">
  <strong>Build a PTCG AI. Battle other AIs. Benchmark every decision. Share it with players.</strong>
</p>

<p align="center">
  An open PTCG Agent arena and local practice client: <strong>build → battle → benchmark → publish → improve</strong>.
</p>

<p align="center">
  <a href="https://ptcg.skillserver.cn/">Player Client</a>
  ·
  <a href="https://ptcg.skillserver.cn/dist/competition.html">AI Ladder</a>
  ·
  <a href="https://github.com/beralee/ptcg-strategy-forge">Strategy Forge</a>
  ·
  <a href="https://ptcg.skillserver.cn/dist/developers.html">Developer Center</a>
  ·
  <a href="README.md">中文</a>
  ·
  <a href="docs/README.md">Docs</a>
</p>

## Build. Battle. Benchmark. Share.

`PTCG Deck Agent` started as a local PTCG practice client. It is now evolving into an **Open PTCG Agent Arena** for developers, researchers, and players.

This is not just “a game with an LLM attached.” The project is trying to solve a harder systems problem:

> **How can independently built PTCG agents compete under the same public-information boundary, the same legal-action contract, and reproducible battle conditions—and then be distributed safely to real players?**

| If you are a... | You can... |
| --- | --- |
| **Agent developer** | Use [PTCG Strategy Forge](https://github.com/beralee/ptcg-strategy-forge) to author rule policies or import frozen models, validate them, build `.ptcgai`, and publish qualified releases |
| **Game AI / RL researcher** | Compare rules, BC, RL, bounded search, and planning over shared public observations, decision traces, fixed scenarios, and paired benchmarks |
| **PTCG player** | Challenge built-in and community AIs locally, review failures, and feed useful games back to strategy authors |
| **Rules / engine contributor** | Improve rules correctness, card effects, cross-runtime conformance, regression coverage, and platform compatibility |

## A deliberately small Agent interface

The public strategy boundary stays simple:

```text
agent(raw_observation) -> list[int]
```

An Agent may return only indexes into the **current legal selection window**. Once a selection is accepted, that window expires; the Agent must observe and bind again before its next decision.

That small API sits behind a stricter execution model:

- **Public information only** — hidden opponent cards, deck order, face-down prizes, private RNG, and mutable engine objects do not enter policy input.
- **Fresh-window decisions** — a policy never keeps long-lived engine handles or stale option indexes across accepted selections.
- **Data-only distribution** — `.ptcgai` packages cannot ship arbitrary Python, GDScript, native libraries, or network-capable executable code.
- **Device-local execution** — community strategy battles can run directly inside the Godot client without an operator-hosted inference service.
- **Reproducible evidence** — fixed scenarios, decision traces, replays, cross-runtime conformance, and benchmarks are used to find the first bad decision, not just the final win rate.

That lets rule systems, imitation learning, reinforcement learning, bounded search, and multi-turn planning compete inside one shared arena instead of living in isolated demos.

## From a deck idea to the AI ladder

```text
Understand the deck and its win routes
  → create a Strategy Forge workspace
  → author rules or import a frozen model
  → iterate RED → GREEN on public-window scenarios
  → check / build a deterministic .ptcgai
  → sign locally and upload to the Developer Center
  → pass independent qualification and enter the AI ladder
  → improve from real battles, replays, traces, and player feedback
```

Development validation, platform qualification, ladder performance, Godot rules witnessing, official CABT engine parity, and release approval are separate evidence levels. The project claims only scopes that have explicit evidence.

## Build your first PTCG Agent

Agent authoring happens in the separate [PTCG Strategy Forge](https://github.com/beralee/ptcg-strategy-forge) repository, so you do not need to become a Godot or rules-engine contributor first.

The currently validated authoring environment is **Windows + PowerShell 7 + Python 3.13**:

```powershell
git clone https://github.com/beralee/ptcg-strategy-forge.git
cd ptcg-strategy-forge
.\setup.ps1
.\forge.ps1 doctor
```

Creating a publishable author workspace still requires a stable developer identity from the [Developer Center](https://ptcg.skillserver.cn/dist/developers.html). Private signing keys remain on the developer's machine; the platform records only the public key.

The day-to-day loop is intentionally short:

```text
inspect → scenario → check → build → local battle → trace → improve
```

Most authors work with three artifacts:

1. **Strategy Blueprint** — how the deck wins, attack tempo, resource ownership, and replanning conditions;
2. **Data-only policy / frozen actor** — the executable part of the strategy under the current public contract;
3. **Scenarios & traces** — positive cases, negative cases, option reordering, and real failed games that lock expected behavior.

Start here:

- [PTCG Strategy Forge](https://github.com/beralee/ptcg-strategy-forge)
- [Forge Quickstart](https://github.com/beralee/ptcg-strategy-forge/blob/main/docs/01-QUICKSTART.md)
- [Registration-to-upload guide](https://ptcg.skillserver.cn/dist/developer-guide.html)
- [Repository author-strategy guide](docs/ptcgdap/10-author-strategy-developer-guide.md)

## Why this is more than another PTCG simulator

### 1. Agents do not own the rules engine

Policies do not manipulate BattleScene nodes, mutable engine objects, or hidden state. The engine owns legality and state progression; the Agent proposes selections only inside the current public window.

### 2. A Base layer protects the safety floor

Legality, mandatory / terminal handling, cardinality, veto, transaction safety, fresh rebinding, and deterministic fallback remain platform-owned. A strategy may become smarter, but it does not become more privileged.

### 3. Python development and the GDScript player runtime must agree

Python is used for Forge and reference validation. GDScript is the portable device-local execution baseline. Shared contracts, vectors, and differential tests are used to catch semantic drift.

### 4. A benchmark should explain more than a win rate

The project encourages evidence such as:

- fixed seeds and seat swaps
- first-divergence decision traces
- scenario regression and option reorder
- policy success / rejection / fallback audit
- known gaps and rollback identity

A strategy improvement should be able to answer: **which public fact changed which decision, why, and whether the new version actually improved the game outcome.**

Public implementation status and evidence:

- [PtcgDAP public status](docs/ptcgdap/STATUS.md)
- [Competitive Author Policy v2](docs/ptcgdap/30-competitive-author-policy-v2.md)
- [Validation / promotion / rollback](docs/ptcgdap/05-validation-promotion-and-rollback.md)

## Players: challenge community AI

1. Get the client from the [download page](https://ptcg.skillserver.cn/dist/index.html#download).
2. Browse strategy rankings, recent performance, and authors on the [AI Ladder](https://ptcg.skillserver.cn/dist/competition.html).
3. Choose a built-in AI or load a compatible `.ptcgai` through the in-game Strategy Center.
4. Start a device-local battle from the unified AI opponent picker.
5. Use logs, replays, and reviews to find useful practice opponents and feed valuable failures back to strategy authors.

Optional LLM features such as deck coaching and battle Q&A are isolated from local strategy execution and may require a separately configured online model service.

## Preview

<p align="center">
  <img src="https://ptcg.skillserver.cn/dist/assets/demo_menu.png" alt="Main menu" width="49%" />
  <img src="https://ptcg.skillserver.cn/dist/assets/demo_ai_card.webp" alt="AI deck discussion" width="49%" />
</p>

<p align="center">
  <img src="https://ptcg.skillserver.cn/dist/assets/demo4.webp" alt="Battle scene" width="49%" />
  <img src="https://ptcg.skillserver.cn/dist/assets/demo3.webp" alt="Battle overview" width="49%" />
</p>

## Technical layout

```text
contracts/   CABT, public-observation, strategy-package, executor, and conformance contracts
data/        Bundled decks, cards, images, and author strategy packages
docs/        Architecture, developer guides, strategy iteration, and validation records
scenes/      Godot scenes, Strategy Center, battle setup, and replay UI
scripts/     Rules engine, Hosts, AI policies, local executors, and tournament logic
tests/       Contract, card-effect, strategy, scenario, UI, and regression tests
tools/       Strategy-package, validation, evidence, and developer utilities
```

Key boundaries:

1. `scripts/engine/` owns rules, legal selection windows, state transitions, and effect scheduling.
2. `scripts/ai/ptcgdap/` owns public observations, strategy packages, Hosts, local execution, conformance, and traces.
3. `scripts/effects/` implements card, attack, ability, Trainer, Tool, and Stadium effects.
4. `scenes/battle_setup/` and the Strategy Center provide one player-facing entry while keeping classic-AI and author-strategy runtime owners separate.
5. `scripts/tournament/` implements local Swiss tournament flow.

## Run the local client

### Requirements

- Godot `4.6.x`
- Windows is the primary validated platform
- Full Android device acceptance is still in progress
- Local strategy battles do not require system Python or remote inference

### Start

1. Open `project.godot` with Godot.
2. Run `res://scenes/main_menu/MainMenu.tscn`.
3. Open AI Battle to choose a built-in or loaded strategy, or enter deck-management and tournament modes.

### Common tests

```powershell
# Run from the repository root; replace the Godot path for your machine
& 'C:\path\to\Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s res://tests/FunctionalTestRunner.gd
& 'C:\path\to\Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s res://tests/AITrainingTestRunner.gd
```

## Status and boundaries

This is a fast-moving open-source PTCG Agent platform that also retains full local practice and rules-simulation capabilities.

- The public project includes author strategy packages, the Forge workflow, the public policy contract, local Godot execution, a unified AI opponent picker, strategy rankings, and validation infrastructure.
- Windows is the primary product and development target; complete Android acceptance remains open work.
- This repository is not a complete official judge. Official CABT engine parity is claimed only for explicitly recorded scopes.
- Third-party strategies pass independent integrity, compatibility, signature, qualification, and device gates; “valid locally” does not automatically mean “on the ladder” or “approved for every device.”

See [STATUS.md](docs/ptcgdap/STATUS.md) and [IMPLEMENTATION_CHECKLIST.md](docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md) for current evidence and remaining work.

## Contributing

The fastest way to contribute is not necessarily to change the engine first. **Build an Agent and make it fight.**

We especially welcome:

- new rule policies, frozen models, public scenarios, and `.ptcgai` packages
- reproducible bad decisions, benchmarks, traces, and visualization tools
- card-effect, rules, identity-mapping, and interaction fixes
- Python ↔ GDScript conformance and deterministic-build improvements
- Strategy Center, battle UI, accessibility, and multi-platform work
- documentation, Quickstart, test-entrypoint, and developer-experience improvements

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR.

## Disclaimer

This is an unofficial, non-commercial learning and research project. Pokémon, Pokémon TCG, card names, images, rules text, and related intellectual property belong to their respective owners. The project is not endorsed by or affiliated with the official rights holders and is not a substitute for an official product.

If you fork the project, publish a strategy, or build on it, please preserve this boundary.

## License

[Apache License 2.0](LICENSE)
