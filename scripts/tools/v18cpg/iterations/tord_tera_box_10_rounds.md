# Tord Tera Box V18CPG — 10-round acceptance ledger

Deck: `800015934` (`v18cpg_800015934_tord_tera_box`)
Anchor: rules-only Miraidon `575720`
Model: `deepseek-v4-flash`
Runner: `scripts/tools/v18cpg/run_pilot_benchmark.tscn`
Architecture boundary: V18CPG only; no legacy LLM or Agent imports.

## Frozen baseline

- Round-0 seeds: `181820`, `181821` with alternating tracked seat.
- Rule: `0/2`; V18CPG: `0/2`; clean: `2/2`; calls: `7`; old runner wait p95: `6491ms`.
- Earliest replay gap: no strength difference and the policy payload lacked typed Tera/toolbox guidance. The one action difference was a model-owned Nest Ball; it did not change the result.
- Artifact: `tmp/v18cpg/tord_round0_baseline.json`.

## Rounds

| Round | Earliest triage | Deterministic fixture / minimal accepted change | Paired evidence | Decision |
| ---: | --- | --- | --- | --- |
| 1 | `semantic_gap` | Added bounded profile, protected roles, route margins, safety, and Noctowl pair-role priorities. `test_tord_tera_box_round01_profile.gd`. | `181820-21`: rule `0/2`, CPG `0/2`, 4 calls, old p95 `6830ms`. | Keep: strength non-regressive and calls fell 7→4; latency change treated as network noise, not a pass. |
| 2 | `fact_or_solver_error` | Added visibility-safe Tera/Fan Call, typed-energy, bench, quota, and deck-risk route annotations. `test_tord_tera_box_round02_tera_gate.gd`. | `181820-21`: `0/2` vs `0/2`, 4 calls, old p95 `6692ms`. | Keep: exact Tera gate closed a missing solver fact without changing the rule floor. |
| 3 | `semantic_gap` | Replaced free text with registered typed priorities; removed localized/fuzzy Noctowl matching and accepted only registered step IDs / stable source UIDs. `test_tord_tera_box_round03_stable_step_identity.gd`. | `181820-21`: `0/2` vs `0/2`, 4 calls, old p95 `6276ms`. | Keep: isolation/identity contract improved, strength non-regressive. |
| 4 | `interaction_error` | Changed Fan Call from one global preference list to route-bound typed pair roles. `test_tord_tera_box_round04_route_bound_pairs.gd`. | `181820-21`: `0/2` vs `0/2`, 4 calls, old p95 `6700ms`. | Keep: energy route selects access+mover; develop route selects stadium+Pokemon search. |
| 5 | `fact_or_solver_error` | Added public typed-energy counts, distinct-symbol gain, and attachment priority annotations. `test_tord_tera_box_round05_typed_energy_frontier.gd`. | `181820-21`: `0/2` vs `0/2`, 4 calls, old p95 `5680ms`. | Keep: typed-energy continuity became model-visible; no paired regression. |
| 6 | `interaction_error` | Added typed supporter-quota handling so a spent supporter cannot win the pair search. `test_tord_tera_box_round06_supporter_quota_pair.gd`. | `181822-23`: rule `1/2`, CPG `1/2`, 3 calls, old p95 `5966ms`. | Keep: new seeds non-regressive; dead supporter pair removed. |
| 7 | `interaction_error` | Once a KO is secured, penalize energy/search churn and preserve gust/recovery/pivot roles. `test_tord_tera_box_round07_minimum_resource_after_ko.gd`. | `181824-25`: rule `1/2`, CPG `2/2`, 6 calls, old p95 `6561ms`. | Keep: seed `181825` flipped from rule loss to CPG win. Acceptance run was delayed until a shared module parse gate was repaired and therefore used the cumulative candidate; the fixture isolates this round's delta. |
| 8 | `interaction_error` | On a full bench, reject dead Pokemon search unless paired with the typed stadium expansion role. `test_tord_tera_box_round08_full_bench_pair.gd`. | `181826-27`: `0/2` vs `0/2`, 8 calls, old p95 `9077ms`. | Keep for correctness/strength non-regression; latency gate not passed. |
| 9 | `interaction_error` | Added legal explicit-empty Fan Call at critical deck count plus low-deck role penalties. `test_tord_tera_box_round09_critical_deck_whiff.gd`. | `181828-29`: `0/2` vs `0/2`, 4 calls, old p95 `7061ms`. | Keep: deckout safety is exact and no paired loss was introduced. |
| 10 | `interaction_error` | Energy mover now requires visible board energy; otherwise prefer a live acceleration/access pair. `test_tord_tera_box_round10_energy_mover_liveness.gd`. | `181830-31`: `0/2` vs `0/2`, 8 calls, old p95 `7525ms`. | Keep: dead Energy Switch pair removed; strength non-regressive on fresh seeds. |

All round 1–10 fixture processes passed independently. The round 7–10 acceptance runs were resumed only after the shared capability registry and CyclePivot scripts parsed cleanly.

## Final continuous paired diagnostic (before module-set correction)

Artifact: `tmp/v18cpg/tord_final_10seeds.json`.

Architecture review immediately after this run found that the pilot catalog had activated all three shared modules for every pilot. This Tord run therefore also received `energy_burst` and `cycle_pivot` annotations that do not belong to its exact capability set. The catalog is now corrected to Tord=`tera_noctowl_search` only and guarded by an exact-set core fixture. The numbers below are retained as a positive diagnostic, not the formal post-correction acceptance result; the root acceptance runner must overwrite/supersede them with a module-correct rerun.

- Seeds: `181820..181829`, alternating tracked seat.
- Rule: `2/10` (`20%`).
- V18CPG: `3/10` (`30%`).
- Paired improvement: `+10pp`.
- Paired bootstrap 95% interval: `[0pp, +30pp]`.
- Clean games: rule `10/10`, V18CPG `10/10`; no draw, crash, timeout, stall, or action cap.
- Per-seed deltas: nine ties and one `+1` (`181825`); no negative paired seed.
- Model calls: `25` (`2.5/game`); accepted `25`, rejected `0`; no schema, deadline, route-validation, or rules fallback.
- Existing-graph branch-hit records: `7`; graph-branch events: `25`; uncovered events: `16`.
- Action-owner audit records: `local_gate=586`, `model_selected_local_route=50`, `policy_graph_branch=14`.
- Request visible-wait samples: `25`, p50 `6175ms`, p95 `7113ms`.
- Turn-visible-wait samples: `22`, p50 `6175ms`, p95 `12903ms`.
- Payload p50/p95: `30367/39230` bytes.

This is a positive pilot signal, not promotion evidence: the n=10 confidence interval still includes zero, and turn-visible p95 is too high.

## Rule-floor and shared-module gates

- No-model artifact: `tmp/v18cpg/tord_final_10seeds_no_model.json`.
- Same 10 seeds with model disabled: rule `2/10`, V18CPG `2/10`, every paired outcome identical, calls `0`, clean `10/10`.
- `test_v18cpg_contracts.gd`: PASS (8 groups).
- `test_flareon_noctowl_iteration_fixtures.gd`: PASS (rounds 1–10).
- `raging_bolt_10_rounds.gd`: PASS (10/10).
- Tord round 1–10 fixtures: PASS individually.
- Stable-ID gate: exact `csv9c_noctowl_trainers` / `jewel_seeker_cards` step ID or `CSV9C_155` / `LEN_SCR_115` source UID only; localized title/name changes do not affect ownership.

## Remaining gaps

1. `model_selection_error`: only one of ten seeds improved, so route-quality uplift is not yet statistically established.
2. `event_or_version_error`: uncovered-event count is `16`; more useful branch coverage should reduce full requests.
3. `outcome_or_threat_error`: typed annotations expose public resource continuity, but the local outcome vector still does not calculate attacker-specific multi-type attack costs from attack metadata.
4. `interaction_error`: explicit-empty and pair liveness are covered, but live multi-step Energy Switch source/target assignment still needs an end-to-end interaction fixture.
5. Latency: 30–39KB payloads and `12903ms` turn-visible p95 fail the feedback-speed promotion gate. The deck stays experimental.
6. Statistical gate: run at least 100 paired games for pilot strength, followed by independent 300-game promotion batches; do not extrapolate the current `+10pp` point estimate.
