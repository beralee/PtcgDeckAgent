# V18CPG 800017643 Flareon Noctowl: 10-round acceptance ledger

Scope: isolated V18CPG profile/module work only. The comparison anchor is rules-only Miraidon `575720`; paired runs use alternating tracked seats, `max_steps=220`, and model `deepseek-v4-flash`.

## Baseline and evidence rules

Round 0 on the shared runtime before this deck override used seeds `181820-181821`: rule `0/2`, V18CPG `0/2`, clean `2/2`, model calls `2`, graph branch hits `1`, uncovered events `1`. The old runner reported visible-wait p95 `6995ms`. The earliest divergence on seed `181820` was an optional draw-engine bench commitment before the rule line's typed-Energy attachment.

Artifacts from the first UID refactor attempt are deliberately excluded from strength evidence:

- `flareon_round1.json` still depended on a rejected card-name implementation and was not retained.
- `flareon_round1_uid.json` ran while an unrelated shared Noctowl script had a parse error, so V18CPG was not instantiated and its zero-call result is invalid.
- Rounds 1-3 therefore have deterministic fixture evidence only. They are not presented as win-rate evidence.
- Per-round latency came from concurrent exploratory runs. It is diagnostic only. Formal latency acceptance belongs to the final sequential run on the revised shared audit/runner.

## Ten retained rounds

| Round | Failure category and smallest retained change | Deterministic acceptance | Paired evidence | Result / disposition |
|---:|---|---|---|---|
| 1 | `model_selection_error`: optional draw engine could consume a bench slot before open typed-Energy continuity. Added stable-UID/semantic-role annotation plus the optional-engine guard. | UID `CSV8C_135` is annotated as optional and rejected behind `route:energy_commit`. | No valid strength run; shared parse blocker. | Retained as a safety contract only. |
| 2 | `semantic_gap`: the line failed to preserve the attacker's R-W-L typed-energy set. Added missing-type ranking and an off-color penalty. | Missing `L` after `[R,W]` outranks `P` by at least `1500`. | No valid strength run; shared parse blocker. | Retained. |
| 3 | `interaction_error`: Fan Call development order did not build both attacker and search lanes first. Added semantic role order: attacker root, Noctowl root, then optional opening engine. | Role ranks are strictly ordered without card-name inspection. | No valid strength run; shared parse blocker. | Retained. |
| 4 | `interaction_error`: Jewel Seeker could select two locally useful but non-complementary roles. Added typed role-pair preferences, beginning with supporter acceleration + Pokemon search. | Pair contract returns the complementary pair first. | Seeds `181820-181821`: rule `0/2`, CPG `0/2`, clean `2/2`, calls `5`, accepted `5`, branches `2`, uncovered `4`. | No strength regression. Former premature optional bench divergence disappeared. Retained. |
| 5 | `model_selection_error`: information/search churn could continue after a ready KO existed. Added ready-KO terminal discipline and route rejection. | `route:information` is rejected when `route:attack_ko` is ready. | Seeds `181820-181821`: rule `0/2`, CPG `0/2`, clean `2/2`, calls `5`, accepted `5`, branches `2`, uncovered `4`. | Outcome-neutral safety improvement. Retained. |
| 6 | `outcome_or_threat_error`: a locked, attackless primary could remain active over a live higher-damage bench attacker. Added a pure locked-active pivot predicate. | Locked/attackless active with `280 > 0` bench damage must pivot. | Fresh seeds `181822-181823`: rule `0/2`, CPG `0/2`, clean `2/2`, calls `3`, accepted `3`, branches `0`, uncovered `1`. | No regression. Retained. A same-seed `181820-181821` regression run also stayed `0/2` vs `0/2`. |
| 7 | `resource_or_solver_error`: optional bench padding could consume the last two functional development lanes. Reserved two bench slots. | A `4/5` bench fails the two-slot-reserve predicate. | Seeds `181824-181825`: rule `0/2`, CPG `1/2`, clean `2/2`, calls `5`, accepted `5`, branches `1`, uncovered `2`. | Exploratory `+50pp`. On seed `181824`, CPG attached typed Energy after Kieran instead of ending turn, then established repeated attacks and won. Retained, but not statistically conclusive and not reproduced by the final shared runtime. |
| 8 | `outcome_or_threat_error`: the fallback chip attacker could steal typed Energy from a live evolution root. Added stable-UID fallback-chip eligibility gated by absence of a live attacker root. | Fallback chip is blocked with a live root and allowed without one. | Seeds `181826-181827`: rule `0/2`, CPG `0/2`, clean `2/2`, calls `2`, accepted `2`, branches `0`, uncovered `1`. | No regression. Retained. |
| 9 | `resource_or_solver_error`: rebuild lines could spend recovery, next-attacker, or R-W-L resources. Added those semantic roles to protected resources. | All three roles are present in `protected_roles`. | Seeds `181828-181829`: rule `1/2`, CPG `1/2`, clean `2/2`, calls `6`, accepted `6`, branches `1`, uncovered `2`. | Preserved the rule win. Retained. |
| 10 | `model_selection_error`: optional draw/search churn remained legal in low-deck states. Added low/critical deck thresholds and low-deck route rejection. | Low deck rejects optional `route:information` behind an attack route. | Seeds `181830-181831`: rule `1/2`, CPG `1/2`, clean `2/2`, calls `1`, accepted `1`, branches `1`, uncovered `1`. | No regression. Retained. |

## Final continuous paired acceptance

Final profile (`profile_version=11`) was tested on ten continuous seeds `181820-181829`:

| Metric | Rules-only | Final V18CPG |
|---|---:|---:|
| Wins | `1/10` | `1/10` |
| Win rate | `10.0%` | `10.0%` |
| Paired delta | - | `+0.0pp` |
| Paired bootstrap 95% | - | `[0.0pp, 0.0pp]` |
| Clean normal completions | `10/10` | `10/10` |
| Model calls | - | `2` (`0.2/game`) |
| Accepted / rejected model decisions | - | `2 / 0` |
| Uncovered events | - | `0` at report aggregate; one model-request game recorded one uncovered event |

Nine games followed the deterministic local path with no model call and exactly matched the rule action sequence. Seed `181829` made both accepted model calls: its first meaningful difference moved the Lightning Energy attachment before Iono, but both variants still lost. The round-7 exploratory win did not reproduce after later shared runtime changes reduced model entry.

The model-enabled and `--no-model` runs on the same ten seeds both finished at `1/10`, confirming exact safe fallback at this sample size. The old final report's aggregate `visible_wait_p95_ms=0` is invalid for latency acceptance because eight no-call game values diluted the two real wait samples. Do not use it as a speed conclusion; the parent orchestration run must use the revised audit/runner that aggregates real wait samples, turn-visible wait, and payload size.

## Verification and verdict

- Godot editor parse: PASS.
- Deck iteration fixtures: PASS, rounds 1-10.
- Shared V18CPG contract fixture: PASS, 8 groups.
- Forbidden legacy/Agent imports in owned files: `0`.
- Card-name or `action_summary` branching in module/profile: `0`.
- Final model A/B and no-model fallback: `10/10` clean in both modes.

Verdict: the ten changes are safe, typed, isolated, and preserve the rules baseline, but this deck is **not promotion-ready**. The final ten-game point estimate is non-inferior rather than stronger, model participation is only `2` calls in `10` games, and the design gate still requires at least 100 paired games with a `+5pp` point improvement before a pilot may be promoted. The next iteration should target route-search/local-gate coverage so that high-regret typed-energy, Fan Call, Jewel Seeker, and locked-pivot states can actually reach the CPG without increasing calls on routine states.
