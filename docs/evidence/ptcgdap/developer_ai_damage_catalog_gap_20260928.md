# Developer AI stops playing against uncatalogued cards — 2026-09-28

## Follow-up: newer forecast profile regressed the guard — 2026-10-04

The original repair remained enabled only for `legacy-v1` after the local
`reviewed-gust-v1` compatibility integration. Exact Dragapult 0.29.0 therefore
again rejected the entire decision when Onix/Steelix was in the public board.
The reproduced packed-scene RED is precise: one policy call, one
`unknown_damage_card_uid`, one fallback, no play or attack, then `end_turn`.

Both game Python and Godot now treat that specific optional-catalog error
consistently across supported forecast profiles. The damage planner still
rejects unknown capabilities. Missing damage predicates, negative comparisons
and scores remain unavailable; prior damage transactions are cleared. Other
planner errors, unknown profile validation, privacy guards and Base authority
remain unchanged. No card names or UIDs are special-cased and no capability is
invented to make a card eligible.

The full Python availability suite now runs against both profiles. Its native
equivalent adds `ReviewedDamagePlanningAvailability`, explicitly discoverable
by the regular catalog, and covers both sides' Active and Bench, Onix, Steelix,
an arbitrary unknown UID, semantic reorder, hard tiers, mandatory/terminal/veto,
negative facts, transaction revocation/recovery and private-input rejection.

The exact 0.29.0 archive was also loaded through the actual development gate,
worker and packed battle scene in eight regression positions: opening/ready
Dragapult versus Onix/Steelix, in 2D and 3D. Positions combine local recorded
deck states to isolate this fault; they are explicitly constructed tests, not
purported exact historical replays. Private restore input remains on the host.
All eight completed meaningful play and an attack without policy errors,
fallbacks or engine rejections. Ready Dragapult used Phantom Dive, took a prize
and handed the opponent replacement prompt to the human. The opening position
completed search, attachment, bench development, draw, retreat and attack.

Evidence and exact rollback bytes are in Forge
`work/steelix-ai-stall-20261004/RESULTS.md`. The initial probe incorrectly waited
for the turn counter while human replacement was pending; its failed log is
retained separately from the corrected harness. A concurrent addition of
`151C_084`/`151C_085` caused a separate catalog-coverage check failure, recorded
in the receipt without overwriting those unrelated edits. This repair changes
local game runtime only; no Forge SDK refresh, package replacement, EXE export,
online release or strength claim. Restart the source-launched Windows client.

## Observed failure and owning layer

Six recent local matches using the installed Dragapult and Marnie developer
strategies repeatedly reported `unknown_damage_card_uid`. The latest match
recorded 13 policy calls: 6 successful decisions and 7 policy errors followed
by 7 same-window fallbacks, with no invalid output or engine rejection.

The public board contained legitimate imported Onix (`CSV6C_067`) or Steelix
(`CSV6C_097`). These printings are absent from the generated public damage
capability registry, which covers 1,011 bundled printings. The damage planner
correctly rejects an unknown capability, but `CompetitivePolicyV2` propagated
that optional planning failure as failure of the entire policy. The existing
development battle owner's deterministic main-window fallback chooses
`end_turn`, producing the observed empty turns. This shared path affects both
2D and 3D scenes; the six inspected records have the same cause.

## Repair

Python and Godot `CompetitivePolicyV2` now continue independent policy rules
only for the specific `unknown_damage_card_uid` planning error. The unavailable
damage advice is recorded in the decision audit. Damage-dependent predicates
(including negative comparisons) and scoring rules cannot use missing facts.
Any active semantic damage transaction is aborted and its old state cleared;
a later known board can start a fresh transaction.

The planner still rejects unknown capabilities. Other planner errors still
reject the policy, public-input checks remain active, and Base mandatory,
terminal and veto authority still constrain current-window indexes. No card
capability was guessed or added to make these two opponents pass.

The generated registry also needed its two EffectRegistry source hashes and
overall registry hash synchronized with existing workspace card-effect edits.
Its card entries and generation settings were unchanged by this refresh.

## Validation

The new synthetic public fixture is
`tests/fixtures/author_damage_catalog_gap.json`, SHA-256
`AE28E8BE8E4ABC56985A88B6E157155F9F9BB8F4AB7BFE2061DAAEA352941C50`.
Before the repair, three Python regression methods failed with the observed
catalog error; the private-input guard already passed. After the repair:

| Check | Result |
| --- | --- |
| Python damage planning, competitive policy and availability suites | 41 passed |
| Godot PublicDamagePlanning | 9 passed |
| Godot CompetitivePolicyV2, including pinned cross-runtime vectors | 19 passed |
| Godot DamagePlanningAvailability | 3 passed |
| Godot WorkerInteractionLifecycle | 4 passed |
| Godot AIWatchdog | 17 passed |
| Godot BattleVisualSequenceController | 14 passed |
| Six recorded problem turns resumed in each actual 2D/3D battle scene | 12 passed |
| Latest problem turn in Windows OpenGL with effects enabled, both layouts | 2 passed |

Commands for the persistent regression suites:

```powershell
python -m unittest tests.ptcgdap.test_public_damage_planning tests.ptcgdap.test_competitive_policy_v2 tests.ptcgdap.test_damage_planning_availability -q
.\scripts\tools\run_godot_tests.ps1 -Runner all -Suite 'PublicDamagePlanning,CompetitivePolicyV2,DamagePlanningAvailability,WorkerInteractionLifecycle,AIWatchdog,BattleVisualSequenceController' -ReportDirectory .tmp/author_damage_gap/regressions
```

The scene probes restore a recorded engine snapshot on the host, load the
exact installed package and run the normal worker, owner, legal option builder,
interaction handling and engine execution. The owner constructs fresh public
observations; private replay state is never passed to the policy. The 12 runs
produced 95 successful policy calls, zero policy errors, zero fallbacks and zero
engine rejections. They stop when the turn transfers or player input is needed.

The Windows runs additionally wait for player action availability after the
animations. Both attach an Energy, evolve Duskull and attack with Budew, then
return control to the player (4.7 seconds in 2D; 4.2 seconds in 3D). Both use the
Windows display server, and the 3D run confirms the arena presenter is installed.
The rendered output was inspected locally.

Local diagnostic scripts, replay inputs, logs and screenshots remain under
ignored `.tmp/author_damage_gap/`; no private snapshots or installed package
contents are included in this engineering record. Godot regression results are
in `regressions/report.json`; scene results are in `scene-results.json` and
`scene-results-native.json` under that directory.

## Scope and rollback

This establishes a focused runtime repair, cross-runtime regression coverage,
and live source-tree Windows scene execution. It is not a full-match replay
parity, strategy-strength, Android export or new engine-alignment promotion.
Scene randomness after shuffles was not pinned for a trajectory comparison.
Unknown cards still have no damage capability model, so derived damage advice
remains unavailable while they are on the board. Restart a running source-tree
game to load the changed scripts. No commit, push or release export was made.

Rollback only this task's hunks in `competitive_policy_v2.py`,
`public/CompetitivePolicyV2.gd`, `public_damage_planning.py` and
`public/SemanticTransactionJournal.gd`, plus the new availability tests and
fixture. Preserve all pre-existing workspace edits. The pre-refresh registry
copy is `.tmp/author_damage_gap/registry-before-refresh.json`; restoring it is
appropriate only if the associated EffectRegistry changes are also rolled
back, otherwise source-integrity validation will fail again.
