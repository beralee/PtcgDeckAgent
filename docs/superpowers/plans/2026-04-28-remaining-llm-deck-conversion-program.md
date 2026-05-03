# Remaining Selectable AI Deck LLM Conversion Program

Date: 2026-04-28
Status: M3 delivered; release decision package ready
Program owner: Architect/PM

## Purpose

Convert the remaining AI-selectable deck strategies into LLM-enabled variants, then iterate them until selected LLM queues are actually executed and deck-specific engineering issues are resolved.

This program is scoped to the AI deck shortlist exposed by `CardDatabase` and `BattleSetup`, not to every rules strategy, benchmark fixture, training deck, or deck-discussion alias in the repository.

Required playbooks:

- `$llm-deck-strategy-conversion`: build thin LLM wrappers, preserve rules fallback, wire registry/UI/tooling, validate payload, route, interaction, and audit behavior.
- `$llm-deck-strategy-iteration`: run headless duels, inspect audit logs, and fix route/fact/materialization/interaction/runtime issues before prompt tuning.

## Executive Delivery Summary

Delivery model:

- Four deck workers run in parallel, one worker per remaining deck.
- The architect/PM owns shared runtime, registry, UI, integration gates, and final release decision package.
- Workers own only wrapper files and deck-specific focused tests unless explicitly assigned shared files.
- Rule-based strategies remain the production fallback and default behavior until an LLM variant passes release gates.

Agent model policy:

- Default worker model: `gpt-5.5` with `xhigh` reasoning, because the four decks require architecture reading, wrapper implementation, test design, and audit triage.
- Fallback worker model: `gpt-5.4` with `high` reasoning only if the user explicitly approves a lower-cost/lower-availability substitute.
- Model choice is a kickoff decision, not a worker-local decision.

Milestones:

- M0, kickoff baseline: source-of-truth confirmed, dirty worktree recorded, workers assigned.
- M1, conversion ready: all four wrappers load, registry ids work, focused script-load tests pass.
- M2, smoke ready: each deck completes a 3-game LLM smoke with usable audit evidence.
- M3, stabilization ready: each deck completes a 10-game batch with no repeated first-two-turn major blunder.
- M4, release decision: user approves which LLM variants become visible in BattleSetup.

Timebox:

- Day 0.5: source-of-truth alignment, baseline, scope freeze, worker kickoff.
- Day 1-2: parallel wrapper conversion and focused architecture tests.
- Day 2-3: interaction, route, and selection-policy hardening.
- Day 3-4: 3-game smoke runs and audit-driven fixes.
- Day 4-5: 10-game stabilization, release/rollback package, and final handoff.

Daily checkpoint:

- Worker status: done, blocked, or at-risk.
- Changed files and ownership conflicts.
- Latest focused tests run and result.
- Latest smoke/audit result if available.
- Repeated failure layer: prompt, tactical facts, candidate route, interaction bridge, route compiler, queue runtime, provider reliability, or rules fallback.
- Next 24-hour target and escalation needs.

Delay handling:

- If a worker is blocked for more than one checkpoint, the architect either supplies missing shared infrastructure or narrows that deck to a hidden experimental variant.
- If Gate 1 fails, the deck cannot be merged into registry/UI exposure work.
- If Gate 2 fails, the deck remains hidden and cannot enter 10-game stabilization.
- If the provider/API is unavailable, reliability evidence is marked inconclusive; strategy quality is not judged from provider failures, but release remains blocked.

## Source Of Truth And Scope

Source-of-truth hierarchy:

- `scripts/autoload/CardDatabase.gd`: `SUPPORTED_AI_DECK_IDS` and `get_supported_ai_deck_ids()` define the AI-selectable deck id set.
- `data/bundled_user/decks/<deck_id>.json`: deck list contents and card pool for each selectable deck.
- `scripts/ai/DeckStrategyRegistry.gd`: strategy id to script resolution.
- `scenes/battle_setup/BattleSetup.gd`: user-visible AI deck and strategy variant selection.
- `scripts/engine/DeckDiscussionContextBuilder.gd` and `scripts/engine/DeckDiscussionService.gd`: must not contradict the selectable deck identity/prompt chain, but are not authoritative for the target set.
- `tests/test_card_database_seed.gd` and `tests/test_battle_setup_ai_versions.gd`: regression coverage for selectable decks.
- Training, benchmark, and deck-discussion maps are secondary references only; if their labels conflict with the files above, update or ignore them for this program.

AI-selectable deck matrix:

| Deck id | Rules strategy | LLM status | Program status |
| --- | --- | --- | --- |
| `575716` | `charizard_ex` | implemented | target delivered: `charizard_ex_llm` |
| `575720` | `miraidon` | implemented | out of scope |
| `569061` | `arceus_giratina` | implemented | target delivered: `arceus_giratina_llm` |
| `575657` | `lugia_archeops` | implemented | out of scope |
| `578647` | `gardevoir` | implemented | target delivered: `gardevoir_llm` |
| `575718` | `raging_bolt_ogerpon` | implemented | out of scope |
| `579502` | `dragapult_charizard` | implemented | out of scope |
| `575723` | `dragapult_dusknoir` | implemented | target delivered: `dragapult_dusknoir_llm` |

Known alignment issue closed during delivery:

- `575657` is Lugia / Archeops in the selectable deck set and already has `lugia_archeops_llm`.
- `575723` is the remaining Dragapult / Dusknoir target.
- `DeckDiscussionContextBuilder.gd` and `DeckDiscussionService.gd` mappings now align `575657` to Lugia / Archeops and `575723` to Dragapult / Dusknoir.

Source-of-truth alignment checks:

- `CardDatabase.SUPPORTED_AI_DECK_IDS` contains exactly the eight deck ids in the matrix.
- Each `data/bundled_user/decks/<deck_id>.json` file exists and its `id` matches the filename.
- `DeckStrategyRegistry.resolve_strategy_id_for_deck()` resolves all eight rules strategy ids.
- `BattleSetup._selected_ai_strategy_id()` covers all AI-selectable decks, including `575723`.
- `BattleSetup._detect_ai_strategy_variants()` exposes all approved LLM variants behind the API-config gate.
- DeckDiscussion aliases and display names do not contradict the source-of-truth matrix.

Out of scope for this wave:

- Regidrago, Dialga, Palkia, Lost Box, Future Box, Iron Thorns, Blissey, Gouging Fire, and other bundled/training decks that are not currently in `SUPPORTED_AI_DECK_IDS`.
- Full win-rate optimization beyond removing repeated audit-classified major tactical and runtime failures.
- Replacing the rules strategy system.

## Architecture Rules

Each target gets a thin wrapper:

- `scripts/ai/DeckStrategyCharizardExLLM.gd`
- `scripts/ai/DeckStrategyArceusGiratinaLLM.gd`
- `scripts/ai/DeckStrategyGardevoirLLM.gd`
- `scripts/ai/DeckStrategyDragapultDusknoirLLM.gd`

Every wrapper must:

- Extend `DeckStrategyLLMRuntimeBase.gd`.
- Compose the existing rules strategy as `_rules`.
- Preserve the rules strategy id and behavior.
- Delegate ordinary scoring, setup, retreat, send-out, search/discard priority, and interaction fallback to rules.
- Use `get_deck_strategy_text()` from the deck editor when available.
- Add only deck-specific prompt text and hook behavior.

Wrappers must not:

- Duplicate ZenMux request lifecycle.
- Build private action catalogs.
- Execute a private LLM queue.
- Copy hardcoded card text instead of using card JSON/rules payload.
- Add deck-specific logic to shared runtime unless the concept is truly generic.

Shared integration stays architect-owned:

- `scripts/ai/DeckStrategyRegistry.gd`
- `scenes/battle_setup/BattleSetup.gd`
- `tests/test_script_load_regressions.gd`
- `tests/test_llm_interaction_bridge.gd`
- `tests/test_ai_action_scorer_runtime.gd`
- `scripts/ai/LLMRouteCandidateBuilder.gd`
- `scripts/ai/LLMRouteCompiler.gd`
- `scripts/ai/LLMInteractionIntentBridge.gd`
- `scripts/ai/LLMTurnPlanPromptBuilder.gd`

## RACI

| Workstream | Responsible | Accountable | Consulted |
| --- | --- | --- | --- |
| Source-of-truth alignment | Architect/PM | Architect/PM | Workers before kickoff |
| Deck wrapper implementation | Assigned worker | Architect/PM | User if deck plan is ambiguous |
| Deck-specific focused tests | Assigned worker | Architect/PM | Other workers for reusable patterns |
| Shared LLM runtime/compiler/bridge | Architect/PM | Architect/PM | Workers with failing audit evidence |
| Registry, strategy resolver, and BattleSetup exposure | Architect/PM | Architect/PM | User for release visibility |
| Shared-fix triage | Architect/PM | Architect/PM | Worker that produced evidence |
| 3-game smoke and audit triage | Architect/PM | Architect/PM | Assigned worker |
| 10-game stabilization | Architect/PM | Architect/PM | Assigned worker |
| Release/rollback decision | User | User | Architect/PM |

## Delivery Dashboard

| Deck | Worker | Source map | Wrapper | Focused tests | UI/resolver | 3-game smoke | 10-game batch | Release state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `charizard_ex_llm` | Agent 1 | passed | passed | passed | passed | passed | passed | experimental-ready |
| `arceus_giratina_llm` | Agent 2 | passed | passed | passed | passed | passed | passed | experimental-ready |
| `gardevoir_llm` | Agent 3 | passed | passed | passed | passed | execution-stable, quality hold | execution-stable, quality hold | experimental-only |
| `dragapult_dusknoir_llm` | Agent 4 | passed | passed | passed | passed | passed | passed | experimental-ready |

Dashboard update rules:

- `pending`: not started or no evidence.
- `in progress`: code exists but gate evidence incomplete.
- `blocked`: owner cannot proceed without shared fix or user decision.
- `passed`: gate evidence exists and is linked in the worker report.
- `API-gated`: LLM variant is selectable only when an LLM API configuration is available.
- `hidden`: LLM variant is not user-visible by default.
- `released`: user approved exposure after Gate 3 or explicit exception.

## Delivery Evidence 2026-04-28

Delivered code:

- Added thin LLM wrappers for `charizard_ex_llm`, `arceus_giratina_llm`, `gardevoir_llm`, and `dragapult_dusknoir_llm`.
- Added worker-owned focused tests under `tests/llm_decks/`.
- Wired shared registry creation in `DeckStrategyRegistry.gd`.
- Wired BattleSetup AI-version exposure for all eight selectable LLM-capable decks behind the API-config gate.
- Corrected DeckDiscussion deck id/name mappings for `575657` and `575723`.
- Added shared script-load and BattleSetup regression coverage for the four new variants.

Focused verification:

- `tests/test_script_load_regressions.gd`: 13 passed, 0 failed.
- `tests/llm_decks/test_charizard_ex_llm.gd`: 7 passed, 0 failed.
- `tests/llm_decks/test_arceus_giratina_llm.gd`: 7 passed, 0 failed.
- `tests/llm_decks/test_gardevoir_llm.gd`: 7 passed, 0 failed.
- `tests/llm_decks/test_dragapult_dusknoir_llm.gd`: 7 passed, 0 failed.
- `tests/test_battle_setup_ai_versions.gd`: 22 passed, 0 failed.
- `tests/test_llm_interaction_bridge.gd`: 144 passed, 0 failed.
- `tests/test_ai_action_scorer_runtime.gd`: 3 passed, 0 failed.
- `tests/test_card_database_seed.gd`: 3 passed, 0 failed.
- `tests/test_deck_discussion_context_builder.gd`: 5 passed, 0 failed.
- `tests/test_deck_discussion_service.gd`: 9 passed, 0 failed.
- `tests/test_deck_discussion_dialog.gd`: 2 passed, 0 failed.
- `tests/test_deck_strategy_contract.gd`: 5 passed, 0 failed.
- `tests/test_deck_strategy_registry_expansion.gd`: 3 passed, 0 failed.
- `tests/test_llm_raging_bolt_duel_tool.gd`: 3 passed, 0 failed.

M2 smoke evidence:

- `charizard_ex_llm` vs Miraidon rules: 3 games, `25/25` requests succeeded, takeover rate `1.0`, LLM result `1-2`, no action-cap/no-progress.
- `arceus_giratina_llm` vs Miraidon rules: 3 games, `37/37` requests succeeded, takeover rate `1.0`, LLM result `2-1`, no action-cap/no-progress.
- `gardevoir_llm` vs Miraidon rules: 3 games, `29/29` requests succeeded, takeover rate `1.0`, LLM result `0-3`, no action-cap/no-progress.
- `dragapult_dusknoir_llm` vs Miraidon rules: 3 games, `44/44` requests succeeded, takeover rate `1.0`, LLM result `1-2`, no action-cap/no-progress.

M2 fixes from smoke:

- Gardevoir: fixed a typed-array runtime hook error in `_is_bad_gardevoir_retreat()` and added a focused regression.
- Arceus/Giratina: tightened deck-local `end_turn` replacement to avoid low-value escape actions such as off-plan Boss, retreat, Lost City, low-deck Bibarel, and Lost Vacuum.

M3 stabilization evidence:

- `charizard_ex_llm`: 10-game batch `charizard_ex_llm_m3_20260429_summary.json`, `117/117` LLM successes, takeover `1.0`, result `6-4`, no action-cap/no-progress. Post-fix 3-game `charizard_ex_llm_m3_20260429_fix3_summary.json`, `24/24` successes, takeover `1.0`; fixed Forest Seal Stone attaching to non-V targets.
- `arceus_giratina_llm`: 10-game batch `arceus_giratina_llm_m3_20260429_summary.json`, `167/167` LLM successes, takeover `1.0`, result `5-5`, no action-cap/no-progress. Route-aware post-fix 3-game `arceus_giratina_llm_m3_20260429_routeaware_3b_summary.json`, `54/54` successes, takeover `1.0`, result `3-0`; fixed overblocking/overchurn around Judge/Iono/Boss and low-value Abyss Seeking under deck-out pressure.
- `dragapult_dusknoir_llm`: initial 10-game `dragapult_dusknoir_llm_m3_20260429_summary.json`, `122/122` successes, takeover `1.0`, result `1-9`. Post-fix 10-game `dragapult_dusknoir_llm_postfix10_20260429_summary.json`, `140/140` successes, takeover `1.0`, result `6-4`; fixed Dusknoir self-KO gating, bad tool targets, Rare Candy/evolution priority, and escape-action guards.
- `gardevoir_llm`: 10-game `gardevoir_llm_postfix2_20260429_summary.json`, `161/161` successes, takeover `1.0`, result `0-10`; final 3-game `gardevoir_llm_final3_20260429_summary.json`, `47/47` successes, takeover `1.0`, result `0-3`. Execution is stable, but strategy quality remains below release threshold because the deck repeatedly fails to convert Gardevoir ex/Kirlia setup into Drifloon/Scream Tail prize pressure and still loses to Miraidon tempo.

M3 focused verification:

- `tests/llm_decks/test_charizard_ex_llm.gd`: 8 passed, 0 failed.
- `tests/llm_decks/test_arceus_giratina_llm.gd`: 15 passed, 0 failed.
- `tests/llm_decks/test_gardevoir_llm.gd`: 16 passed, 0 failed.
- `tests/llm_decks/test_dragapult_dusknoir_llm.gd`: 11 passed, 0 failed.
- `tests/test_script_load_regressions.gd`: 13 passed, 0 failed.
- `tests/test_battle_setup_ai_versions.gd`: 22 passed, 0 failed.
- `tests/test_llm_interaction_bridge.gd`: 144 passed, 0 failed.
- `tests/test_ai_action_scorer_runtime.gd`: 3 passed, 0 failed.
- `tests/test_llm_raging_bolt_duel_tool.gd`: 3 passed, 0 failed.
- `tests/test_deck_strategy_registry_expansion.gd`: 3 passed, 0 failed.

Open release risk:

- `gardevoir_llm` should stay experimental-only. The LLM request pipeline, queue execution, interaction bridge, and local guards are stable, but the deck-specific route quality needs another iteration focused on earlier Drifloon/Scream Tail attacker conversion, TM Evolution target discipline, and avoiding Kirlia/Gardevoir ex chip attacks when prize attackers are available or searchable.

## Test Ownership

Worker-owned focused tests must be in separate files to avoid four agents editing the same large shared test surface:

- Agent 1 owns `tests/llm_decks/test_charizard_ex_llm.gd`.
- Agent 2 owns `tests/llm_decks/test_arceus_giratina_llm.gd`.
- Agent 3 owns `tests/llm_decks/test_gardevoir_llm.gd`.
- Agent 4 owns `tests/llm_decks/test_dragapult_dusknoir_llm.gd`.

Architect-owned shared tests:

- `tests/test_script_load_regressions.gd`
- `tests/test_llm_interaction_bridge.gd`
- `tests/test_ai_action_scorer_runtime.gd`
- `tests/test_battle_setup_ai_versions.gd`

Workers may propose shared test changes in their report, but should not directly edit shared tests unless assigned by the architect.

## Worker Work Packages

### Agent 1: Charizard ex / Pidgeot LLM

Target:

- Deck id `575716`
- Rules strategy `charizard_ex`
- LLM strategy `charizard_ex_llm`

Owned files:

- `scripts/ai/DeckStrategyCharizardExLLM.gd`
- `tests/llm_decks/test_charizard_ex_llm.gd`

Core plan:

- Build Charmander -> Charizard ex through Rare Candy or legal evolution routes.
- Build Pidgey -> Pidgeot ex as the search engine when available.
- Use Charizard-style energy acceleration to fill real attack costs before padding support Pokemon.
- Convert into prize pressure while avoiding premature Dusknoir/self-damage throws.

High-risk areas:

- Rare Candy vs normal evolution sequencing.
- Pidgeot search target selection.
- Energy assignment from Charizard ability.
- Duskull/Dusclops/Dusknoir timing if present in the list.
- Tool/gust routes for KO math.

Required deliverables:

- Wrapper file and registry-ready strategy id.
- Focused tests for script load, prompt payload, Rare Candy route, Pidgeot search target, and energy assignment.
- 3-game smoke summary with audit file path.
- 10-game stabilization summary or explicit blocked reason.
- Known risks and unresolved issues list.

### Agent 2: Arceus / Giratina LLM

Target:

- Deck id `569061`
- Rules strategy `arceus_giratina`
- LLM strategy `arceus_giratina_llm`

Owned files:

- `scripts/ai/DeckStrategyArceusGiratinaLLM.gd`
- `tests/llm_decks/test_arceus_giratina_llm.gd`

Core plan:

- Build Arceus V -> Arceus VSTAR.
- Use Starbirth for exact shell-finish pieces.
- Use Trinity Nova to power the next attacker while preserving backup Arceus/Giratina lanes.
- Stop padding basics once formation is complete.

High-risk areas:

- Starbirth exact two-card search.
- Trinity Nova source and assignment choices.
- Double Turbo / typed energy routing.
- Maximum Belt / Choice Belt target selection.
- Judge/Iono redraw timing versus nonlethal attacks.

Required deliverables:

- Wrapper file and registry-ready strategy id.
- Focused tests for script load, prompt payload, Starbirth selection, Trinity Nova assignment, and strong-mode queue ownership.
- 3-game smoke summary with audit file path.
- 10-game stabilization summary or explicit blocked reason.
- Known risks and unresolved issues list.

### Agent 3: Gardevoir LLM

Target:

- Deck id `578647`
- Rules strategy `gardevoir`
- LLM strategy `gardevoir_llm`

Owned files:

- `scripts/ai/DeckStrategyGardevoirLLM.gd`
- `tests/llm_decks/test_gardevoir_llm.gd`

Core plan:

- Build Ralts -> Kirlia -> Gardevoir ex.
- Prioritize Kirlia draw/evolution engine and Psychic Energy discard setup.
- Use Psychic Embrace-style acceleration without over-damaging the wrong attacker.
- Convert into the correct attacker based on prize map and HP thresholds.

High-risk areas:

- Multi-stage evolution and Rare Candy/TM Evolution timing.
- Kirlia draw/discard choices.
- Psychic Embrace source/target/quantity choices.
- Attacker selection after acceleration.
- Deck-out and hand preservation in long games.

Required deliverables:

- Wrapper file and registry-ready strategy id.
- Focused tests for script load, prompt payload, evolution setup route, discard protection, Psychic Embrace assignment, and replan after draw/search.
- 3-game smoke summary with audit file path.
- 10-game stabilization summary or explicit blocked reason.
- Known risks and unresolved issues list.

### Agent 4: Dragapult / Dusknoir LLM

Target:

- Deck id `575723`
- Rules strategy `dragapult_dusknoir`
- LLM strategy `dragapult_dusknoir_llm`

Owned files:

- `scripts/ai/DeckStrategyDragapultDusknoirLLM.gd`
- `tests/llm_decks/test_dragapult_dusknoir_llm.gd`

Core plan:

- Build Dreepy -> Drakloak -> Dragapult ex.
- Use draw/search engine pieces to complete Stage 2 setup.
- Use Dragapult spread damage to set prize maps.
- Use Dusknoir damage abilities only when they create or protect a prize conversion.

High-risk areas:

- Stage 2 setup and Rare Candy route visibility.
- Drakloak draw/search timing.
- Spread target selection from Dragapult attack.
- Dusknoir self-KO / damage-counter ability timing.
- Avoiding retreat/pivot into support-only Pokemon.

Required deliverables:

- Wrapper file and registry-ready strategy id.
- Focused tests for script load, prompt payload, Stage 2 setup route, spread target selection, Dusknoir conversion gating, and strong-mode queue ownership.
- 3-game smoke summary with audit file path.
- 10-game stabilization summary or explicit blocked reason.
- Known risks and unresolved issues list.

## Execution Plan

### Phase 0: Source-Of-Truth Alignment And Freeze

Owner: Architect/PM
Timebox: Day 0.5
Dependency: user confirms this scope

Actions:

- Record current dirty worktree and avoid reverting unrelated edits.
- Confirm the four target deck ids and LLM strategy ids.
- Verify `CardDatabase.SUPPORTED_AI_DECK_IDS`, bundled deck json ids, `DeckStrategyRegistry`, and `BattleSetup` agree on the eight selectable decks.
- Fix or quarantine `DeckDiscussionContextBuilder` / `DeckDiscussionService` deck-name and alias mismatches before relying on player-authored strategy text in LLM prompts.
- Confirm `BattleSetup._selected_ai_strategy_id()` resolves every selectable deck, including `575723`.
- Confirm `BattleSetup._detect_ai_strategy_variants()` has a concrete implementation task for each new LLM id and keeps the existing API-config gate.
- Run focused script-load, interaction bridge, AI runtime, Charizard, VSTAR, and Gardevoir/evolution suites.
- Confirm whether all four LLM variants should be hidden until Gate 3 or exposed after Gate 2 as experimental.

Deliverables:

- Source-of-truth alignment report.
- Baseline test summary.
- Worker assignment list.
- Frozen target matrix.

Exit criteria:

- Baseline failures are known.
- Four targets are final.
- Deck id, rules strategy id, LLM strategy id, display name, and prompt strategy-text source do not conflict.
- Workers receive disjoint ownership.

### Phase 1: Parallel Thin Wrapper Conversion

Owner: each worker
Timebox: Day 1-2
Dependency: Phase 0 complete

Actions:

- Create thin LLM wrapper.
- Preserve full rules fallback delegation.
- Add deck strategy prompt and setup role hints.
- Add minimal deck-specific hooks.
- Add focused tests for payload and architecture boundary.

Deliverables per deck:

- Wrapper file.
- Script-load and prompt-payload tests.
- Worker report with changed files and open risks.

Exit criteria per deck:

- Wrapper loads.
- LLM strategy id is stable.
- Rules strategy id is unchanged.
- No duplicated runtime lifecycle code.

### Phase 2: Interaction And Route Hardening

Owner: worker for deck-specific behavior, architect for shared fixes
Timebox: Day 2-3
Dependency: Phase 1 deck wrapper loads

Actions:

- Identify high-impact search choices, discard choices, ability assignments, attack targets, and deferred/revealed option pools.
- Add tests and fixes for `selection_policy` materialization.
- Convert repeated deck-agnostic failures into shared bridge/compiler/prompt-builder fixes.

Shared files that require architect review:

- `LLMInteractionIntentBridge.gd`
- `LLMRouteCandidateBuilder.gd`
- `LLMRouteCompiler.gd`
- `LLMTurnPlanPromptBuilder.gd`

Exit criteria:

- Human-visible high-value lines appear as `candidate_routes` or tactical facts.
- LLM `selection_policy` can materialize into concrete legal choices.
- Rules fallback remains competent if LLM intent misses the actual option pool.

### Phase 3: Registry, UI, Tooling

Owner: Architect/PM
Timebox: Day 3
Dependency: at least one deck passes Phase 1, ideally all four

Actions:

- Add registry preloads and ids.
- Add `BattleSetup._detect_ai_strategy_variants()` entries for `charizard_ex`, `arceus_giratina`, `gardevoir`, and `dragapult_dusknoir` behind the existing API-config gate.
- Add or verify `BattleSetup._selected_ai_strategy_id()` mapping for all eight selectable deck ids, especially `575723`.
- Keep rules strategies as default selections.
- Add headless BattleSetup selection verification for each new LLM id.
- Ensure duel tooling accepts explicit deck and strategy ids for all four targets.
- Add script-load regression tests.

Exit criteria:

- All four LLM ids instantiate from registry.
- UI can select rules or LLM variant when API config exists.
- UI hides or disables LLM variants when API config is absent.
- Headless selection tests prove selected deck id and selected strategy id match the target.
- Rules strategies remain default unless the LLM variant is selected.

### Phase 4: 3-Game Smoke And Audit Iteration

Owner: Architect/PM with worker consultation
Timebox: Day 3-4
Dependency: Gate 1 passed for the deck

Actions:

- Run 3-game headless smoke with explicit deck/strategy ids.
- Check `llm_stats.requests`, `successes`, `failures`, and takeover rate.
- Inspect `llm_decisions_YYYYMMDD.jsonl`.
- Compare `plan_selected.action_queue` to `runtime_action_result` and `queue_consumed`.
- Fix engineering failures before prompt text.

Exit criteria per deck:

- Three games complete without action cap or no-progress termination.
- LLM success rate is at least 80% of requests, excluding provider outage.
- LLM takeover rate and planned-route executable rate meet Gate 2 thresholds.
- Selected queues execute in order or are rejected with explicit legal/audit reasons.
- No repeated invalid JSON, soft timeout, stale queue, MCTS override, or no-progress loop.

### Phase 5: 10-Game Stabilization

Owner: Architect/PM with worker consultation
Timebox: Day 4-5
Dependency: Gate 2 passed for the deck

Actions:

- Run 10-game deck-vs-anchor batches.
- Summarize wins/losses/action caps/no-progress/takeover rate/failure layer.
- Fix only from audit evidence.
- Add regression tests for every repeated failure.

Exit criteria per deck:

- Ten games complete without action cap or no-progress termination.
- LLM success rate is at least 80% of requests, excluding provider outage.
- Queue execution fidelity is at least 90% for legal nonterminal queue heads.
- First-two-turn major deck-plan miss count is at most one for that deck, with failure-layer classification and linked fix/test if observed.
- Shared focused tests stay green.

## Quantitative Acceptance Gates

Metric definitions:

- Eligible nontrivial LLM turn: a turn where LLM is configured, local rules do not intentionally skip the request, and at least one productive legal action or candidate route exists.
- LLM takeover rate: eligible successful LLM planning turns where the selected queue head is consumed in order or explicitly rejected by legality, divided by eligible successful LLM planning turns with a non-empty queue.
- Planned-route executable rate: selected route actions that materialize to executable current/future action refs, divided by selected nonterminal route actions.
- Queue execution fidelity: legal nonterminal queue heads consumed in order, divided by legal nonterminal queue heads selected.
- Major first-turn or first-two-turn miss: an audit-classified failure that skips a legal deck-engine setup route, chooses an off-plan search target, uses a route-critical resource as expendable discard, attaches to a non-attacker when the attacker cost is visible, or ends while a non-conflicting productive setup action remains.

Gate 1, conversion complete:

- Wrapper loads from script and registry.
- Strategy id is stable and reports the LLM id.
- Prompt payload includes deck prompt, player-authored strategy text path, legal actions, tactical facts, and candidate routes when present.
- Rules fallback delegates ordinary scoring and interactions.
- At least one deck-specific focused interaction test exists.
- Source-of-truth alignment report has no unresolved deck id/name/strategy-text conflict for the target.
- BattleSetup resolver and API-gated variant task is complete or explicitly assigned to architect integration.
- Worker provides one prompt payload sample path or pasted audit event id showing the target LLM strategy id.
- Shared script-load suite passes.

Gate 2, runtime smoke complete:

- Exactly three smoke games finish for the deck.
- Zero action-cap terminations.
- Zero no-progress terminations.
- `llm_stats.requests > 0` and `llm_stats.successes / requests >= 0.80`, excluding provider outages.
- Invalid JSON response count is `0` for counted smoke games.
- LLM takeover rate is at least `0.70` on eligible nontrivial LLM turns.
- Planned-route executable rate is at least `0.80` for selected nonterminal route heads.
- Audit proves at least one meaningful selected queue per game was consumed or explicitly rejected by legality.
- No repeated contract/materialization failures.
- Every fallback reason in the audit is classified as provider, JSON/contract, legality, materialization, interaction, runtime arbitration, local skip, or rules fallback.
- First-turn major mistake count is `0` for the same opening family.

Gate 3, stabilization complete:

- Exactly ten stabilization games finish for the deck.
- Zero action-cap terminations.
- Zero no-progress terminations.
- LLM success rate remains at least 80%.
- Invalid JSON response count is `0` for counted stabilization games.
- LLM takeover rate is at least `0.75` on eligible nontrivial LLM turns.
- Queue execution fidelity is at least 90% for legal nonterminal queue heads.
- Planned-route executable rate is at least `0.90` for selected nonterminal route heads.
- Fallback reasons are `100%` classified by failure layer.
- First-two-turn major deck-plan miss appears at most once per deck and must have a linked follow-up fix/test if observed.
- Prompt changes are backed by audit evidence, not intuition.
- Shared focused suites stay green.

## Shared Runtime Issue Escalation

When a worker finds a problem that may belong to the shared runtime, they must not patch shared files directly unless assigned by the architect.

Worker evidence package:

- Deck id, rules strategy id, LLM strategy id, seed, game number, turn number, and player index.
- Audit event ids or snippets for `request_fired`, `response_received`, `plan_selected`, `runtime_action_result`, `queue_consumed`, `queue_action_failed`, `replan_requested`, and `fallback` when present.
- Expected route/action and actual executed route/action.
- Failure-layer hypothesis using the iteration taxonomy: payload, tactical facts, candidate routes, JSON contract, materialization, interaction bridge, runtime hook, runtime arbitration, card effect, deck prompt, or rules fallback.
- Minimal focused test proposal or exact bad payload fixture if available.

Architect triage:

- Classify within the next checkpoint as `shared`, `deck-specific`, `card-effect`, `provider`, or `not reproducible`.
- If `shared`, assign the shared file owner, pause worker-local workarounds that would hide the shared bug, and run affected LLM deck tests after the fix.
- If `deck-specific`, return ownership to the worker with the expected hook/test scope.
- If `card-effect`, switch to card audit workflow before continuing LLM tuning.
- If `provider`, mark smoke evidence inconclusive and do not count it against strategy quality.

Regression rule:

- Every accepted shared fix must add or update one architect-owned shared test plus any affected worker-owned deck test.
- After a shared fix lands, rerun at least the triggering deck test, `test_llm_interaction_bridge.gd`, and `test_ai_action_scorer_runtime.gd`.

## Validation Commands

Shared focused tests:

```powershell
./scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_card_database_seed.gd
./scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_setup_ai_versions.gd
./scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_script_load_regressions.gd
./scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_llm_interaction_bridge.gd
./scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_ai_action_scorer_runtime.gd
./scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_charizard_strategy.gd
./scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_vstar_engine_strategies.gd
./scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_gardevoir_fast_evolution_t1.gd
```

Worker-owned focused tests:

```powershell
./scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/llm_decks/test_charizard_ex_llm.gd
./scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/llm_decks/test_arceus_giratina_llm.gd
./scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/llm_decks/test_gardevoir_llm.gd
./scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/llm_decks/test_dragapult_dusknoir_llm.gd
```

Per-deck smoke template:

```powershell
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --disable-crash-handler --log-file 'D:/ai/code/ptcgtrain/tmp/<deck>_llm_smoke.log' --path 'D:/ai/code/ptcgtrain' -s 'res://scripts/tools/run_llm_raging_bolt_duel.gd' -- --mode=miraidon --games=3 --seed=202604280 --max-steps=260 --llm-wait-timeout-seconds=75 --llm-max-failures=1 --rule-deck-id=575720 --rule-strategy-id=miraidon --llm-deck-id=<target_deck_id> --llm-strategy-id=<target_llm_strategy_id> --output-root=res://tmp/llm_duels/<target_llm_strategy_id>_smoke --json-output=res://tmp/llm_duels/<target_llm_strategy_id>_smoke_summary.json
```

Deck ids:

- `charizard_ex_llm`: `575716`
- `arceus_giratina_llm`: `569061`
- `gardevoir_llm`: `578647`
- `dragapult_dusknoir_llm`: `575723`

## Release And Rollback Strategy

Default release policy:

- Rules strategies remain default.
- LLM variants remain hidden unless API configuration is present and user-visible selection is explicitly enabled.
- Missing API endpoint/key hides or disables LLM choices; it must not change rules AI behavior.
- A failed LLM request, invalid JSON, schema violation, timeout, empty decision tree, or illegal queue falls back to the rules strategy for that turn.

Exposure options:

- Conservative: expose each LLM variant only after Gate 3 passes.
- Experimental: expose a deck after Gate 2 with an "LLM experimental" label and keep rules as default.
- Deferred: keep a failed deck hidden while the other passed decks ship.

Rollback triggers:

- Any released LLM deck causes repeated action-cap/no-progress games.
- Repeated illegal queue execution or stale queue ownership appears after release.
- A user-visible opening blunder repeats in the same deck after a regression fix.
- Provider reliability causes poor UX and fallback is not transparent enough.

Rollback action:

- Remove the LLM variant from BattleSetup exposure or gate it behind debug/API-only config.
- Keep the wrapper and tests in code if they are useful for continued iteration.
- File an audit-backed follow-up with failure layer, seed, deck id, strategy id, and log path.

## Risk Register

- Shared-file conflicts: four agents may touch registry/UI/bridge tests. Mitigation: workers own wrappers and deck-specific tests; architect integrates shared files.
- Source-of-truth drift: some secondary maps have historical labels. Mitigation: use `CardDatabase.SUPPORTED_AI_DECK_IDS`, bundled deck json, registry, and BattleSetup as the authority.
- Gardevoir special loading: registry treats `gardevoir` through a script path. Mitigation completed for M1: `gardevoir_llm` uses the same path-instantiation pattern and has registry script-load coverage.
- Stage 2 route visibility: Charizard, Gardevoir, and Dragapult/Dusknoir all depend on Stage 2 setup. Mitigation: route candidates must expose Rare Candy/evolution/search setup lines structurally.
- Search target quality: generic search prompts can choose low-impact Pokemon such as off-plan Ogerpon. Mitigation: candidate routes and selection policies must express role-fit, current bottleneck, and missing-piece value.
- Deferred option pools: search/reveal effects can expose targets after action resolution. Mitigation: deck-specific `pick_interaction_items()` and scoring must choose from actual revealed items.
- Runtime ownership: strong mode may bypass a valid LLM queue. Mitigation: keep `test_ai_action_scorer_runtime.gd` and audit queue-consumption checks in every iteration.
- Provider instability: timeout/invalid JSON can look like bad strategy. Mitigation: separate reliability evidence from strategy evidence and use `--llm-max-failures=1` during smokes.
- Encoding: Chinese deck strategy text can corrupt if edited incorrectly. Mitigation: keep UTF-8 and run script-load tests after prompt changes.

## Decision Log

Approved scope executed in this delivery:

- Converted exactly `charizard_ex_llm`, `arceus_giratina_llm`, `gardevoir_llm`, and `dragapult_dusknoir_llm`.
- Keep rules strategies as default.
- Kept shared runtime/registry/UI/test changes under architect integration.
- Added API-gated BattleSetup exposure and registry creation coverage.

Open decisions:

- Whether API-gated BattleSetup exposure is sufficient for users now after M2, or whether Gardevoir should remain hidden until quality improves.
- Whether 10-game stabilization should use only Miraidon anchor or include deck-specific bad-matchup anchors.
- Whether M3 should first target shared repair-rate reduction or deck-specific win-rate/strategy quality.

## Worker Final Delivery Package

Each worker must return one compact package:

- Changed files, grouped by wrapper, tests, and any proposed shared changes.
- Test commands run and pass/fail result.
- Prompt payload sample path or audit event id proving the LLM strategy id, legal actions, tactical facts, candidate routes, and player-authored strategy text path are present.
- Interaction coverage summary for search, discard, attach/assignment, target/gust, spread, and deferred option pools relevant to the deck.
- 3-game smoke summary with log path, JSON summary path, LLM requests, successes, failures, takeover rate, planned-route executable rate, action-cap count, and no-progress count.
- 10-game stabilization summary if Gate 2 passed, with the same metrics plus repeated-blunder review.
- Fallback reason breakdown by failure layer.
- Known risks, unresolved issues, and explicit release recommendation: `release`, `experimental`, `hidden`, or `blocked`.

## Agent Start Prompt

Use one worker per deck after approval:

```text
You are Worker <N> for <rules_strategy_id> -> <llm_strategy_id>. Use $llm-deck-strategy-conversion first, then $llm-deck-strategy-iteration for focused fixes. You are not alone in the codebase. Do not revert edits made by others. Own only <wrapper file> and tests/llm_decks/test_<strategy>_llm.gd unless assigned shared files by the architect. Build a thin LLM wrapper over the rules strategy, preserve rules fallback, add deck prompt/hooks, add focused tests for prompt payload and key interactions, run targeted tests, and return the Worker Final Delivery Package from this plan.
```
