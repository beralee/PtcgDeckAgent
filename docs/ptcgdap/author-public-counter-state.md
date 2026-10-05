# Public counter-assignment progress

## Windows worker selection fingerprint repair (2026-10-04)

The local match `match_20261003_233720_565551` opened Phantom Dive's six-counter
interaction on turns 6 and 8, but the Windows policy worker rejected nine
responses as `stale_policy_response`. Both interactions then hit the 12-second
UI watchdog, so neither attack settled. This was a Host execution defect.

Scheduling enriched `decision.selection` with the current counter/energy budget
and assignment limits, while polling fingerprinted the unenriched state. Both
paths now use `_build_selection_public_state`; polling does not advance the
window sequence. The current options and public state are still rebuilt, so
real budget, target-order or turn changes continue to reject old responses.
No option, policy output, privacy allow-list or strategy package changed.

`tests/ptcgdap/godot/test_author_worker_selection_context.gd` covers six fresh
counter windows with reordered targets, shared assignment/energy limits and
actual stale-result rejection. The original two private snapshots were also
restored locally into the packed Godot battle scene: exact 0.29.0 package,
actual worker, resolver and engine, 200 attack damage plus 60 counter damage
before Pokemon Check, six successful choices each, then the prize prompt.
Private restore input is not policy input or a public fixture. This is attack
continuation evidence, not an exact full-match rerun or a new win-rate result.

Receipts, RED/GREEN results, source hashes and before-bytes:
Forge `work/dragapult-missed-attacks-20261003/`. Local source remains the
unreleased Windows 0.6.3 / build 63; restart a source-launched client to load
the repair. No EXE, production package, SDK snapshot or online release changed.

## Counter-state projection

The user authorized this local DAP repair and the corresponding Forge SDK port
on 2026-09-30, explicitly withholding online deployment.

The sequential resolver passes accepted assignments and the current remaining
budget to the local author owner. `_make_option` projects counts only, joined
to the current target slot's stable entity identity. It never exposes target
objects or assignment records. Actual remaining HP and energy-assignment
counts retain their existing meaning.

Competitive v2 accepts optional `target_pending_damage_counters` and
`remaining_damage_counters` on CARD/context 13 or 14 target windows. If either
is present, both are required on every option, in integer range 0–100; each
target needs a positive entity serial, and the remaining budget must agree
across options. Legacy frames may omit both. Munkidori's context 40 amount
selection stays separate; context 13 reports the available budget, not its
previously selected partial transfer amount.

The Python and GDScript readers enforce the same boundary. Authored vectors
exercise presence, bounds, identity, privacy, reorder and decision flips after
one public fact changes. Base mandatory / terminal / tier / veto authority is
unchanged. Option fingerprints already cover the entire option and therefore
bind the new counters as well.

`tools/ptcgdap/build_competitive_policy_v2_contract.py` generates the schema,
profile, vectors, bundle and the corresponding fixed consumer pins. Its
`--check` mode rejects drift without changing files. Contract contents still
cannot rebaseline a running loader's trust anchor.

Forge retains its prior evaluator and ports only this extension plus the
existing public `appeared_this_turn` boolean shape. This is not a wholesale
SDK refresh or a claim that every newer Turn Program feature is distributed.
Both repositories use byte-identical counter extension code and a mechanically
generated provenance manifest.

The maintained engine test is `tests/test_author_public_counter_state.gd`;
Python boundary tests are `tests/ptcgdap/test_public_counter_state.py` and the
shared vectors are replayed by `tests/ptcgdap/godot/test_competitive_policy_v2.gd`.
Exact receipts and before-bytes are retained in the Forge workspace at
`work/dragapult-counter-sdk-20260930/`. That result distinguishes component
engine tests, current-window simulations, full-match benchmarks and online
approval. No online deployment or new strength result is part of this repair.
