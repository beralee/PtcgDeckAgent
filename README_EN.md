# PTCG Deck Agent

<p align="center">
  <a href="https://ptcg.skillserver.cn/">
    <img src="https://ptcg.skillserver.cn/dist/assets/dojo-home-design.png" alt="PTCG Deck Agent - PTCG AI Agent Strategy Platform" width="100%" />
  </a>
</p>

<p align="center">
  <strong>An open PTCG AI Agent strategy platform: build strategies, validate battles, compete on the AI ladder, and bring great opponents to every player's local client.</strong>
</p>

<p align="center">
  <a href="https://ptcg.skillserver.cn/">Website</a>
  ·
  <a href="https://ptcg.skillserver.cn/dist/competition.html">AI Strategy Ladder</a>
  ·
  <a href="https://ptcg.skillserver.cn/dist/developers.html">Developer Center</a>
  ·
  <a href="https://github.com/beralee/ptcg-strategy-forge">PTCG Strategy Forge</a>
  ·
  <a href="README.md">中文</a>
  ·
  <a href="docs/README.md">Project Docs</a>
</p>

## A PTCG AI Agent Strategy Platform

`PTCG Deck Agent` has grown from a local practice client into a PTCG AI Agent strategy platform for developers and players.

- **For developers**: use [PTCG Strategy Forge](https://github.com/beralee/ptcg-strategy-forge) to create rule-based strategies or import frozen models, test them against public-information scenarios, build and validate them deterministically, then sign and upload them through the [Developer Center](https://ptcg.skillserver.cn/dist/developers.html) to enter the continuously running AI strategy ladder.
- **For players**: download the client and compatible `.ptcgai` packages, choose built-in or community strategies from one AI-opponent picker, battle them locally, review games, and use the [strategy rankings](https://ptcg.skillserver.cn/dist/competition.html) to find the strongest or most useful practice opponent.
- **For researchers and contributors**: study rule policies, imitation learning, reinforcement learning, bounded search, and multi-turn planning against one public policy contract with reproducible battles, decision traces, and regression tests.

The public strategy boundary stays deliberately small:

```text
agent(raw_observation) -> list[int]
```

A strategy may return only indexes into the current legal selection window. Every accepted selection requires a fresh observation and a fresh binding. Hidden opponent cards, deck order, face-down prizes, private RNG state, and mutable engine objects never enter policy input.

## From an Idea to the AI Ladder

```text
Register and receive a developer ID
  -> Create a workspace with PTCG Strategy Forge
  -> Author rules or import a frozen model
  -> Run scenarios, strict validation, and deterministic builds
  -> Sign the .ptcgai package locally with your private key
  -> Upload it to the Developer Center for qualification
  -> Enter the AI ladder against built-in and community strategies
  -> Let players download, challenge, review, and improve it
```

Development validation, platform qualification, ladder performance, and player execution are separate gates. Passing local development checks does not by itself prove platform qualification, official CABT engine parity, or release approval for every device.

## Developers: Build Your PTCG AI

### Why participate

- **One strategy contract**: every strategy sees a public observation and the current legal options; none can directly manipulate the rules engine.
- **A complete Forge toolchain**: workspace scaffolding, rule/model modes, a supported-card snapshot, scenario checks, deterministic builds, strict validation, and public-window simulation.
- **Reproducible evidence**: decision traces, replays, fixed scenarios, and benchmarks help locate the first bad decision instead of reporting only final win rate.
- **A continuous AI ladder**: releases compete against built-in and developer-authored strategies under stable identities, with strategy and author rankings.
- **Real player feedback**: players can load compatible strategies and battle them locally, so successful ideas do not remain isolated experiments.
- **A safe data-only package**: `.ptcgai` cannot contain arbitrary Python, GDScript, native libraries, or network-capable executable code.

### Quick start

The current author toolchain targets Windows, PowerShell 7, and Python 3.13. First register in the [Developer Center](https://ptcg.skillserver.cn/dist/developers.html) and copy your complete developer ID, then install Forge:

```powershell
git clone https://github.com/beralee/ptcg-strategy-forge.git
cd ptcg-strategy-forge
.\setup.ps1
.\forge.ps1 doctor
```

Then follow the public guide to create a workspace, author a strategy, check supported cards, run scenarios, build, register a public key, sign locally, and upload:

- [From registration to upload: complete developer guide](https://ptcg.skillserver.cn/dist/developer-guide.html)
- [Developer Center: accounts, signing keys, and uploads](https://ptcg.skillserver.cn/dist/developers.html)
- [PTCG Strategy Forge source and documentation](https://github.com/beralee/ptcg-strategy-forge)
- [Repository author-strategy developer guide](docs/ptcgdap/10-author-strategy-developer-guide.md)

Your private key must remain on your own computer; the Developer Center registers only the public key. Never commit private keys, API keys, or other credentials to Git, paste them into the website, or place them in a strategy package.

## Players: Challenge Community AI

1. Get the client from the [download page](https://ptcg.skillserver.cn/dist/index.html#download).
2. Compare rankings, recent performance, and authors on the [AI Strategy Ladder](https://ptcg.skillserver.cn/dist/competition.html).
3. Choose a built-in AI or load a compatible `.ptcgai` package through the in-game AI Strategy Center.
4. Pick the opponent from the unified AI deck selector and start a device-local battle.
5. Use battle logs, replays, and reviews to find the strongest strategy and help authors improve it.

The aligned strategy-battle decision path runs on the player's device and does not require an operator-hosted inference service. Optional LLM features such as deck coaching and in-battle Q&A are isolated from local strategy execution and may require a separately configured online model service.

## Platform Capabilities

- **Author strategy packages**: discover, validate, install, and load `.ptcgai` under stable release identities that bind author, strategy, deck, version, and content hash.
- **AI strategy ladder**: continuous rankings for built-in and developer strategies, including match counts, recent performance, and author standings.
- **Device-local execution**: restricted strategy IR and a local executor run inside the Godot client; packages cannot call engine methods directly.
- **Public-information firewall**: policy input is allow-listed; hidden cards, private RNG, search credentials, and mutable engine objects remain isolated.
- **Current-window safety**: output is only current `select.option` indexes; old windows, indexes, and authority expire immediately after selection.
- **Base Graph protection**: legality, mandatory and terminal handling, transaction safety, veto, and deterministic fallback remain platform-owned.
- **Cross-runtime conformance**: Python is used for development and reference validation, while GDScript is the portable player-runtime baseline; shared contracts and vectors keep them aligned.
- **Replay-driven iteration**: battle logs, public replays, decision traces, scenario snapshots, and benchmarks support first-divergence diagnosis and regression tests.
- **Practice and tournament tools**: regular AI battles, local two-player play, deck management, AI deck coaching, Swiss tournaments, and review workflows remain available.

## Preview

<p align="center">
  <img src="https://ptcg.skillserver.cn/dist/assets/demo_menu.png" alt="Main menu" width="49%" />
  <img src="https://ptcg.skillserver.cn/dist/assets/demo_ai_card.webp" alt="AI deck discussion" width="49%" />
</p>

<p align="center">
  <img src="https://ptcg.skillserver.cn/dist/assets/demo4.webp" alt="Battle scene" width="49%" />
  <img src="https://ptcg.skillserver.cn/dist/assets/demo3.webp" alt="Battle overview" width="49%" />
</p>

## Technical Layout

```text
contracts/   CABT, public-observation, package, executor, and conformance contracts
data/        Bundled decks, cards, images, and author strategy packages
docs/        Architecture, developer guides, strategy iteration, and validation records
scenes/      Godot scenes, Strategy Center, battle setup, and replay UI
scripts/     Rules engine, Hosts, AI policies, local executors, and tournament logic
tests/       Contract, card-effect, strategy, scenario, UI, and regression tests
tools/       Strategy-package, validation, evidence, and developer utilities
```

Key boundaries:

1. `scripts/engine/` owns rules, select windows, state transitions, and effect scheduling.
2. `scripts/ai/ptcgdap/` owns public observations, strategy packages, Hosts, local execution, conformance, and traces.
3. `scripts/effects/` implements card, attack, ability, Trainer, Tool, and Stadium effects.
4. `scenes/battle_setup/` and the Strategy Center let players choose classic AI or author strategies while keeping their runtime owners separate.
5. `scripts/tournament/` implements local Swiss tournament flow.

## Running Locally

### Requirements

- Godot `4.6.x`
- Windows is the primary validated platform
- Android device acceptance is still in progress
- Strategy battles do not require system Python or remote inference
- Optional LLM chat features require a separately configured compatible service

### Start

1. Open `project.godot` with Godot.
2. Run `res://scenes/main_menu/MainMenu.tscn`.
3. Open AI Battle to choose a built-in or loaded strategy, or start from deck management or tournament mode.

### Common tests

```powershell
# Run from the repository root; replace the Godot path for your machine
& 'C:\path\to\Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s res://tests/FunctionalTestRunner.gd
& 'C:\path\to\Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s res://tests/AITrainingTestRunner.gd
```

## Status and Boundaries

This is a fast-moving open-source PTCG AI Agent strategy platform, not a complete official judge and not an endorsement by Pokemon, PTCG, or any related rights holder.

- The current version includes author strategy packages, a Forge development workflow, a public policy contract, local Godot execution, a unified AI-opponent picker, strategy rankings, and continuous validation infrastructure.
- Windows is the primary product and development target; complete Android device acceptance remains open work.
- Interface alignment, Python/GDScript conformance, Godot rules behavior, official CABT engine parity, and product release qualification are separate evidence levels. The project claims only explicitly verified scopes.
- Third-party strategies pass package integrity, compatibility, signature, qualification, and device gates. “Valid locally” does not automatically mean “on the ladder” or “executable by every player.”

See the [PtcgDAP status record](docs/ptcgdap/STATUS.md) and [implementation checklist](docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md) for current evidence and remaining work.

## Contributing

The most direct contribution is to build a strategy, put it on the ladder, and improve it from real failed games.

Issues and pull requests are also welcome, especially for:

- New rule-based or model-based strategies, public scenarios, and `.ptcgai` packages
- Card-effect, rules, and identity-mapping fixes
- Reproducible bad AI decisions and battle replays
- Strategy evaluation, benchmark, replay, and visualization tooling
- Strategy Center, battle UI, accessibility, and multi-platform improvements
- Windows and Android packaging or device-compatibility feedback

Please read:

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [DEVELOPMENT_SPEC.md](DEVELOPMENT_SPEC.md)
- [docs/README.md](docs/README.md)
- [PtcgDAP public architecture record](docs/ptcgdap/README.md)

## Disclaimer

This is an unofficial, non-commercial learning and research project. Pokemon, Pokemon TCG, card names, images, rules text, and related intellectual property belong to their respective owners. This project is not endorsed by or affiliated with the official rights holders and is not a substitute for an official product.

If you fork the project, publish a strategy, or build on it, please preserve this boundary.

## License

[Apache License 2.0](LICENSE)
