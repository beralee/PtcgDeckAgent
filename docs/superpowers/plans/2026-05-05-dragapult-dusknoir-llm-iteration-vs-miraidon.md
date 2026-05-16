# Dragapult Dusknoir LLM Strong-Mode Iteration vs Miraidon

Date: 2026-05-05

## Scope

Target deck:

- LLM deck id: `575723`
- LLM strategy id: `dragapult_dusknoir_llm`
- Opening mode: `-LlmStrongFixedOpening`

Benchmark opponent:

- Rules deck id: `575720`
- Rules strategy id: `miraidon`
- Opening mode: `-RuleStrongFixedOpening`

Goal:

- Improve the Dragapult Dusknoir LLM strong-mode line against rules Miraidon through replay-driven iteration.
- Keep the LLM runtime stable: no invalid JSON, no action cap, no stalled games, no route materialization failures.
- Prefer reusable execution-layer improvements over prompt-only fixes when a mistake is deterministic from visible state.

## Design Principles

- The LLM wrapper remains thin. Rules fallback stays available through `DeckStrategyDragapultDusknoir.gd`.
- Prompt text expresses deck preference, but deck hooks enforce tactical invariants that must not depend on the model repeating them perfectly.
- Route execution and interaction choices are part of the decision system. Search, discard, send-out, spread-target, tool-target, and energy-target choices need deck-specific scoring.
- Fixes are trace-derived. Every non-trivial strategic patch must have a focused test that reproduces the observed failure shape.

## Current Strategy Model

Primary plan:

- Build `Dreepy -> Drakloak -> Dragapult ex`.
- Use `Phantom Dive` as the main prize-pressure attack.
- Use `Duskull -> Dusclops -> Dusknoir` only when self-KO damage creates a clear prize conversion or prevents losing the prize race.

Resource policy:

- Fire/Psychic Energy and `Sparkling Crystal` belong on the same Dragapult line.
- Do not invest route-critical Energy or `Sparkling Crystal` into an exposed active `Dreepy` or `Drakloak` when a benched Dragapult line can become the real attacker.
- Preserve Fire/Psychic Energy in discard interactions when it fills the active or next Dragapult attack cost.

Miraidon-specific pressure policy:

- Miraidon can repeatedly KO low-HP Dreepy lines early.
- After the first Dreepy is KO'd, use `Rotom V` as a send-out buffer when no ready Dragapult attacker exists, preserving benched Dreepy/Drakloak lines for Rare Candy or evolution.
- `Phantom Dive` spread should pre-mark a loaded 230 HP follow-up attacker, such as `Iron Hands ex`, so the next 200 damage attack can take the KO.

## Implemented Changes

Deck hook and runtime behavior:

- Added route-resource guards for exposed active `Dreepy` and `Drakloak`.
- Added queue redirection so an LLM action targeting exposed active seed resources can execute on an equivalent benched Dragapult line instead of falling through to low-value fallback.
- Added resource-unification guards so Fire/Psychic Energy and `Sparkling Crystal` stay on the same Dragapult line.
- Added send-out scoring that promotes `Rotom V` over unready Dreepy/Drakloak after a KO when it can protect the Dragapult line.
- Added spread scoring for loaded follow-up multi-prize attackers with 201-260 HP, enabling `Phantom Dive` two-turn prize maps.
- Preserved existing low-value `Jet Head`, terminal draw, bad gust, bad pivot, bad support target, energy search, Forest Seal, and discard guards.

Shared runtime:

- `DeckStrategyLLMRuntimeBase.gd` now allows a deck hook to accept an equivalent runtime action when the queued action id matches but metadata differs. This supports safe same-turn redirects from an exposed active seed to a benched line.
- Forest Seal Stone granted abilities now preserve the source Tool metadata in the legal-action and prompt payloads, so `Star Alchemy` is exposed as Tool-based deck search rather than being confused with the host Pokemon's native ability.
- Candidate routes that make a primary attack live through manual attach or visible engine setup now include the corresponding future attack goal before the terminal `end_turn`, keeping the route executable while making the intended attack conversion explicit.

Prompt:

- Strengthened the Dragapult energy policy: against fast attackers, avoid route-critical Energy or `Sparkling Crystal` on exposed active Dreepy when a benched line can carry the attack.

## Tests Added Or Updated

Focused suite:

- `test_opening_resource_investment_avoids_exposed_active_dreepy_when_backup_exists`
- `test_midgame_resource_investment_avoids_exposed_active_drakloak_when_backup_exists`
- `test_dragapult_resource_investment_keeps_energy_and_crystal_on_same_line`
- `test_send_out_uses_rotom_to_cover_unready_dragapult_seeds`
- `test_spread_target_policy_marks_loaded_followup_attacker_for_next_phantom_dive_ko`

Existing regression coverage retained:

- Prompt/setup hooks.
- Exact `Phantom Dive` readiness.
- `Sparkling Crystal` cost readiness.
- Rotom terminal draw blocking.
- Iono/Roxanne draw blocking when visible attach/tool routes exist.
- Earthen Vessel missing-energy search.
- Forest Seal search and carrier search.
- Forest Seal source-card prompt metadata.
- Serialized active-position resource redirects.
- Manual attach route closure through future primary attack goals.
- Ultra Ball discard protection.
- Switch/gust guards.
- Dusknoir self-KO conversion gating.

## Validation Commands

Focused Dragapult suite:

```powershell
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --disable-crash-handler --log-file 'D:/ai/code/ptcgtrain/tmp/dragapult_dusknoir_llm_focus.log' --path 'D:/ai/code/ptcgtrain' -s 'res://tests/FocusedSuiteRunner.gd' -- --suite-script=res://tests/llm_decks/test_dragapult_dusknoir_llm.gd
```

Intent planner suite:

```powershell
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --disable-crash-handler --log-file 'D:/ai/code/ptcgtrain/tmp/intent_planners_dragapult.log' --path 'D:/ai/code/ptcgtrain' -s 'res://tests/FocusedSuiteRunner.gd' -- --suite-script=res://tests/test_ai_intent_planners.gd
```

Script-load regression:

```powershell
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --disable-crash-handler --log-file 'D:/ai/code/ptcgtrain/tmp/script_load_dragapult.log' --path 'D:/ai/code/ptcgtrain' -s 'res://tests/FocusedSuiteRunner.gd' -- --suite-script=res://tests/test_script_load_regressions.gd --test-filter=dragapult_dusknoir
```

Parallel duel validation:

```powershell
& 'D:/ai/code/ptcgtrain/scripts/tools/run_llm_duel_parallel.ps1' -Games 10 -Concurrency 3 -Seed 2026050711 -MaxSteps 260 -MaxGameSeconds 420 -LlmWaitTimeoutSeconds 75 -LlmMaxFailures 1 -ProcessTimeoutSeconds 560 -RuleDeckId 575720 -RuleStrategyId miraidon -LlmDeckId 575723 -LlmStrategyId dragapult_dusknoir_llm -RuleStrongFixedOpening -LlmStrongFixedOpening -OutputRoot 'res://tmp/llm_duels/dragapult_dusknoir_llm_vs_miraidon_validation_final_10g' -JsonOutput 'res://tmp/llm_duels/dragapult_dusknoir_llm_vs_miraidon_validation_final_10g_summary.json'
```

## Iteration Log

Baseline:

- Earlier 10-game window before exposed-active and send-out fixes: LLM 2, rules Miraidon 8.
- Requests were healthy, so the issue was strategy/execution, not API reliability.

Iteration 1: exposed active seed resources.

- Failure: Fire/Psychic Energy and `Sparkling Crystal` were sometimes attached to active Dreepy/Drakloak that Miraidon could KO immediately.
- Fix: block active seed investment when a benched Dragapult line exists; allow queue redirect to a safe benched target.
- Result: focused tests passed, short smoke improved, but another failure showed resource split between two benched Dreepy lines.

Iteration 2: resource unification.

- Failure: Fire Energy could land on one Dreepy while `Sparkling Crystal` landed on another, producing no complete attack line.
- Fix: block Energy/Crystal splits across Dragapult lines.
- Result: focused tests passed; short replay still exposed repeated Dreepy send-out losses.

Iteration 3: KO send-out buffer.

- Failure: after the first Dreepy KO, the AI promoted another Dreepy, feeding prizes and losing the evolution line.
- Fix: send-out scoring now prefers Rotom V as a pressure buffer when no ready Dragapult exists and a benched Dragapult line can be protected.
- Result: same 3-game seed set changed from LLM 0-3 to LLM 3-0.

Iteration 4: Phantom Dive future-prize spread.

- Failure: `Phantom Dive` spread chose low-impact support ex targets while a loaded `Iron Hands ex` could be pre-marked for the next 200 damage KO.
- Fix: score loaded 201-260 HP multi-prize follow-up attackers higher for spread counters.
- Result: the previous single losing seed `2026050700` changed from rules win to LLM win.

Iteration 5: Forest Seal Stone action-surface repair.

- Failure: replay audits showed `Forest Seal Stone` attached correctly but `Star Alchemy` was not reliably used, because the granted ability inherited Rotom V-like metadata and could be blocked as terminal draw.
- Fix: legal-action metadata now carries `ability_source_card`, `ability_name`, and `ability_text`; the prompt builder summarizes the source Tool card and search schema; the Dragapult hook only blocks native Rotom Quick Search as terminal draw.
- Result: 3-game anchor `2026050811` improved to LLM 2, rules 1 with 50/50 LLM successes and visible T2 `星星炼金术` usage in all games.

Iteration 6: attach-to-primary route closure.

- Failure: a loss audit found `future:attack_after_attach:active:1:幻影潜袭` visible, but `manual_attach_to_attack` exposed only `attach + end_turn`, allowing shallow low-pressure lines.
- Fix: `LLMRouteCandidateBuilder` now puts the resulting future primary attack into manual-attach and primary-visible-engine routes before terminal `end_turn`; focused route tests assert this shape.
- Result: 3-game anchor `2026050911` was LLM 3, rules 0 with 48/48 LLM successes; 10-game window `2026051060` after the serialized-resource redirect finished LLM 10, rules 0 with 156/156 LLM successes.

Iteration 7: serialized resource redirect.

- Failure: route-resource redirection only recognized queued `target_slot` object references, while real LLM queues often contain serialized `position: "active"` actions.
- Fix: active-seed resource redirection now resolves queued and runtime targets through `_action_target_slot(...)`, so serialized active Energy/Tool refs can redirect to a safe benched Dragapult line.
- Result: serialized Energy and `Sparkling Crystal` redirect regressions pass; final 3-game smoke `2026051111` finished LLM 3, rules 0 with 41/41 LLM successes.

## Final Validation

Focused tests:

- Dragapult Dusknoir LLM focused suite: 50 passed, 0 failed.
- Shared route-candidate focused subset: 15 passed, 0 failed.
- Forest Seal legal-action metadata focused test: 1 passed, 0 failed.
- Script-load regression filtered to Dragapult Dusknoir: 1 passed, 0 failed.

Duel windows:

- Replay window after send-out buffer, seed `2026050681`, 3 games: LLM 3, rules 0; requests 34, successes 34, failures 0, takeover 1.0.
- Validation after send-out buffer, seed `2026050691`, 10 games: LLM 9, rules 1; requests 138, successes 138, failures 0, skipped 1, takeover 1.0.
- Single replay of prior loss seed `2026050700`: LLM 1, rules 0; requests 20, successes 20, failures 0, takeover 1.0.
- Final validation, seed `2026050711`, 10 games: LLM 7, rules 3; requests 168, successes 168, failures 0, skipped 0, takeover 1.0.
- Forest Seal source fix anchor, seed `2026050811`, 3 games: LLM 2, rules 1; requests 50, successes 50, failures 0, takeover 1.0.
- Forest Seal source fix validation, seed `2026050860`, 10 games: LLM 8, rules 2; requests 174, successes 174, failures 0, takeover 1.0.
- Manual-attach future-route anchor, seed `2026050911`, 3 games: LLM 3, rules 0; requests 48, successes 48, failures 0, takeover 1.0.
- Manual-attach future-route validation, seed `2026050960`, 10 games: LLM 7, rules 3; requests 158, successes 158, failures 0, takeover 1.0.
- Serialized-resource redirect anchor, seed `2026051011`, 3 games: LLM 3, rules 0; requests 43, successes 43, failures 0, skipped 1, takeover 1.0.
- Serialized-resource redirect validation, seed `2026051060`, 10 games: LLM 10, rules 0; requests 156, successes 156, failures 0, skipped 0, takeover 1.0.
- Final route-terminal smoke, seed `2026051111`, 3 games: LLM 3, rules 0; requests 41, successes 41, failures 0, skipped 0, takeover 1.0.

## Remaining Risks

- Some openings still invest resources into active Dreepy when no safe benched Dragapult line is available yet; this is a strategic risk against perfect Miraidon pressure, but the latest validation did not show it causing match instability.
- Late-game support Pokemon exposure remains possible when the board is already degraded.
- Further improvement should focus on second-attacker continuity facts and post-first-Dragapult prize-map recovery only if future samples show repeated losses; current execution-layer gates are clean.

## Acceptance Status

Accepted for this iteration:

- API/runtime stability gate passed.
- Focused regression gate passed.
- Duel validation gate passed with clean LLM health, including a 10-0 final 10-game window against rules Miraidon strong fixed opening.
- Remaining risks are strategic edge cases rather than current execution-layer instability.
