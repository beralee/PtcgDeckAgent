# Local-author counter-distribution windows

On 2026-09-20 the user approved the specific Munkidori Host repair and necessary
regressions proposed by the Forge Gardevoir 18.5 research task.

`AIStepResolver._resolve_counter_distribution_step` previously checked only
`uses_external_decision_port()`. Local author packages declare sequential
interaction support without using an external decision port, so the shared
allocator completed their counter suffix without asking their policy for a
number or target. The resolver now uses the existing
`_uses_sequential_interaction_windows()` capability helper, as the assignment
path already does. Classic adapters that opt out retain their allocator.

Munkidori publishes source CARD/context 16, NUMBER/context 40, then target
CARD/context 13. The accepted semantic count is retained until the next target
window; old option indexes are not retained. A pending policy decision cannot
be replaced by a generic choice. Amount and target legality are rechecked
before the effect commits.

The focused real-effect test first failed because the accepted count was -1
instead of 2. The repaired test moves exactly 1, 2 or 3 counters to the selected
Pokemon with reordered source/target boards. Validation then passed:

- Local counter boundary and inherited interaction-contract suite: 18 tests.
- Full headless match-bridge suite: 40 tests.
- Worker interaction lifecycle, including all three local author adapters: 4 tests.
- Munkidori/Luminous Energy effects: 6 tests.

Receipts are retained by the Forge task under
`work/gardevoir185-20260920/host-iteration/local-counter-red-corrected` and
`host-green`. An earlier fixture Array-typing failure is retained separately
and is not counted as the behavioral RED. Headless fixture exit diagnostics
include unreleased objects; the suite assertions pass, and full-game resource
supervision remains an independent check.

Resolver SHA-256 before:
`B64A46A2DBF17F70117ADA95DA1C3FF92B3545B2CF97529E575A502CAB2160B7`.
Resolver SHA-256 after:
`8248CF64E5859D3F521DC719ADA3BC91AE98F132EA6D3E217CE8EA65B13289E1`.
Rollback is the one capability-condition change; the original bytes are also
retained in the Forge task. No card effect, deck list, Base authority, package
schema or vendored Python SDK contract changed.

The first two clean full-game canary matches produced five complete
source/count/target triplets through a real author package. Derived count and
target steps retain `AssignOrDistribute` metadata, so their coarse public
`prompt_kind` is `assignment_source`, while the source window is `effect_target`.
Policy rules must use the typed select context/type rather than assume that
all three coarse aliases are identical. This is now covered by Forge's
recorded-window adaptation and reorder tests.

A constructed engine fixture subsequently bound the exact real package with
60 cards in each seat and enabled `worker_v1`. Three real worker schedules
completed contexts 16, 40 and 13, with 20 pending polls, no policy errors,
invalid outputs, stale results, engine rejections or fallback, and one exact
10-damage transfer. The receipt is in Forge's
`host-iteration/worker-counter-probe-4`. Earlier launch and incomplete-inventory
fixture failures are retained separately. Exit resource-release warnings
remain documented; this fixture does not establish long-running memory stability.
The same exit warning also appears in all four completed 20-game development
batches; the two short canaries do not emit it. The independent log scan found
no running SCRIPT ERROR or other engine error, while explicitly retaining
strict_exit_log_clean=false. Zero policy error counters do not establish a
clean resource-release exit.

The repaired runtime also completed 84 independently audited full games,
including four separately counted canaries, with 11,771 successful policy
calls and zero error counters. Forge candidate 0.5.2 includes matching typed
NUMBER and target rules; its larger-legal-count preference is a heuristic.
Full-game strength, CABT differential behavior, device acceptance and
production installation remain separate claims. Routing does not itself
provide exact damage-threshold planning.

The separate 240-game frozen confirmation is now complete in Forge: 0.5.2 won 41/120, compared with 26/120 for 0.3.1 on this same repaired Host; seed-cluster p=0.01953125. The prespecified relative-strength gate passed=True. This comparison does not estimate the win-rate effect of the Host repair itself. Across canaries, development and confirmation, 324 games passed the game and trace audits. Ladder rank and long-running resource-release stability remain unproven.


## 2026-09-30 public progress extension

The local sequential path now exposes accepted, unsettled per-target counters and the current remaining budget. This additive change preserves actual HP and energy-assignment semantics. See [the new contract and verification](author-public-counter-state.md); earlier hashes above describe the historical repair.
