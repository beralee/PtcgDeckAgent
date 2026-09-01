# 66. State-conditioned transaction value v2 and paired branch credit

## Outcome

This work package added a full-public-state transaction value layer and a stricter credit-assignment lane without changing the public policy boundary or Base Graph authority. The resulting 5.36.0 package is a development candidate, not a promoted replacement.

The architecture now evaluates each Base-admitted program from the complete fresh public input: board, own hand, public opponent hand count, both public discard piles, prizes, deck counts, turn resource ledger, current options, and the program's public action context. It has no deck-number feature and never receives hidden cards, private RNG, engine objects, or stale option indexes.

## Single scoring owner

The generator materializes the exact program and public action context before scoring. The final shadow planner scores that same object. Canary utility and margin are read from the final shadow audit, so generation and execution can no longer use two different conditioned utilities.

Base Graph still owns legality, mandatory and terminal protection, final-prize protection, transaction safety, rebinding, and final veto. The learned layer only ranks admitted current-window programs. Every accepted selection invalidates the old plan and forces reobservation.

## Training labels

The training pipeline distinguishes four evidence strengths:

1. Authored public exams.
2. Deterministic paired-branch first-divergence preferences.
3. Exact authoritative host-executed canary actions from winning traces.
4. Group-held-out generic validation.

The paired-branch extractor accepts two traces only when opponent identity, seed, candidate seat, public observation hashes, and exact host commits match through the first differing main transaction. One branch must win and the other lose. Only the first differing transaction receives a preference; later actions inherit no terminal credit. Ambiguous program binding, prior public-state divergence, non-terminal games, dirty traces, and hidden/non-public evidence fail closed.

This corrected two opposite failures at once:

- seed 2919018, seat 1: play `CSV2C_127` before ending the turn;
- seed 2919001, seat 0: preserve the attack instead of allowing a marginal `CSVH1C_035` override.

## Evidence

Run `marnie_state_value_v2_20260901_r16` selected the fresh refit. It passed 13/13 authored exams, 2/2 paired-branch locks, 6/6 executed-canary locks, 100% training preference accuracy, and 97.27% validation preference accuracy. Validation state-sign accuracy remained 63.64%, so the model was never eligible on offline metrics alone.

Python related tests passed 47/47. Godot package suites passed 4/4, covering package-local model hash/load, 103 replay-locked decisions, two preservation windows, and two exact state-conditioned transaction windows. Invalid output, policy error, fallback, and engine rejection stayed zero in all reported benches.

The exact paired target run was 3/4 and verified both intended current-window commits. The training-seed regression screen recovered from 5.35.0's 10/20 to 11/20. A predeclared independent continuation gate then used paired seeds 3910000–3910009; the result was 9/20, below the required 12/20. No 100-game promotion benchmark was started.

## Promotion and rollback

5.36.0 remains `execution_trusted=false` and development-only. It does not replace the retained 5.21.0/default rollback line. No claim of a 10-percentage-point win-rate lift is made.

The package archive is `E836EDE176E084946FBAF785F7F6B4DF98265EBE47FF7AAE6C4EC6AEADE620E6`; the package-local integer model is `1960D67C67DC947E146B72F555E07F6FFF4D3C8860C70276E82C26144F5C6B99`. The machine-readable receipt is `evidence/ptcgdap/godot_v18_marnie_state_value_v2_paired_credit_20260901.json`.

## R18 sparse holdout follow-up

Run `marnie_state_value_v2_20260901_r18_sparse_holdout` closes two leakage and complexity gaps. Paired first-divergence rows are now split by the complete opponent-package, seed, and candidate-seat match identity before fitting. Validation branches are selection-only. The interaction head is chosen only from fit rows by normalized orthogonal residual ranking across fixed 16, 32, and 64 feature budgets; benchmark rows never participate in feature selection.

The selected `sparse_16` model passed 13/13 authored exams, its one fit branch and one disjoint validation branch, and reached 98.25% generic validation preference accuracy with 74.60% validation state-sign accuracy. The interaction head fell from 460 terms to 16 without changing Base authority or the device-local integer runtime.

On fresh paired seeds 4710000–4710009, 5.37.0 scored 9/20 versus the 5.21.0 benchmark champion's 8/20 under identical deck, opponent, seat, seed, and runtime inputs. Nineteen outcomes were unchanged; seed 4710007 seat 0 was the only candidate-only win, with no reverse flip. Both reports were clean with zero policy errors, invalid outputs, fallbacks, and engine rejections. Because 9/20 remained below the predeclared 12/20 continuation gate, the result is a screening lead only: no 100-game promotion confirmation was started and 5.21.0 remains the benchmark champion.

The 5.37.0 archive is `20C669C87A07A00589654FD559DCB1704696F38E1E1398243B9A138E21B2CC8B`; its embedded integer model is `D0D9DBCF348FE70A6ACDBD62CDF6AA10AC86831748FBECC11FB39B51D19B29D5`. The machine-readable receipt is `evidence/ptcgdap/godot_v18_marnie_state_value_v2_sparse_holdout_20260901.json`.

## Remaining work

The next value step is not another hand-written card exception. It is broader deterministic branch collection or bounded public rollouts that produce first-divergence advantage labels across multiple unseen match groups; two branch groups are enough to verify isolation but not enough for stable promotion. The 16-term sparse head still needs an Android/A5 performance gate. Official CABT engine parity remains unsupported.
