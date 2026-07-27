# V18CPG transport and execution-ownership hardening

Date: 2026-07-26

Scope: clean-room V18CPG only. The semantic policy graph remains schema v2 and the compact transport remains wire contract v3. This change does not modify legacy LLM/Agent strategy code or default feature flags.

## Problem statement

The first real V3 paired sample exposed three reliability defects:

1. Every complex request used a flat 512-token completion ceiling. Nineteen of 81 calls ended at exactly 512 tokens with `finish_reason=length`, so otherwise useful multi-checkpoint graphs were rejected as truncated.
2. Runtime action ownership was read after synchronous engine execution. An interaction, forced send-out, checkpoint advance, or route clear could mutate the live owner before `action_result` was recorded.
3. Request-start failure, live timeout/rejection, and verified-local no-response did not enter the same turn-judgment lifecycle. This allowed deterministic continuation logic to diverge even when no model-owned action executed.

Successful provider token usage was also missing from audit, which made concise accepted output indistinguishable from unmeasured output.

## Implemented contracts

### Node-aware completion ceiling

The completion ceiling is derived from `limits.max_policy_nodes`:

```text
1..4 nodes -> at least 512 tokens
5 nodes    -> at least 640 tokens
6 nodes    -> at least 768 tokens
7 nodes    -> at least 896 tokens
8 nodes    -> at least 1024 tokens
global cap -> 1024 tokens
```

The configured profile budget may raise a smaller tier, but cannot exceed the global cap. This is only a ceiling. Short decisions may stop normally at any smaller completion length.

The prompt now permits the final useful route to end without a redundant terminal node. A truncated response is still rejected atomically; no partial-JSON recovery or retry was added.

### Provider metrics are not semantic policy

The DeepSeek adapter extracts `finish_reason`, `prompt_tokens`, and `completion_tokens` for both successful and failed responses. `V18CPGDecisionClient` copies them into request metrics, removes them from the response passed to `V18CPGPolicyValidator`, and then emits the strict semantic payload.

This preserves audit evidence without widening semantic schema v2 or compact wire v3.

### Selection-time ownership ticket

`AIOpponent` now calls the V18-only `capture_runtime_action_ownership(action)` seam after choosing the action and before `_execute_action`.

The ticket freezes:

- stable action ID;
- turn, policy, revision, and node;
- route and candidate;
- action owner;
- module certificate;
- observation hash/version;
- exact-binding mismatch evidence.

`log_runtime_action_result` consumes the matching ticket exactly once. The audit record also stores `owner_at_capture`, `owner_at_result`, and `ownership_ticket_status`. A model/verified route that does not match the selected stable action ID is conservatively attributed to `rules_fallback`.

### Equivalent failed-judgment lifecycle

A required model request that cannot start now resolves as a failed judgment. It remains rejected in audit, but subsequent deterministic completion logic sees the same lifecycle state as a live timeout or rejected response.

Request-start failure, schema/binding rejection, deadline fallback, and verified-local no-response all use the same deterministic verified-certificate/completion fallback path. They must not leave a model graph/cursor or silently enable a different interaction owner.

## TDD and regression evidence

New or expanded tests cover:

- successful DeepSeek token metadata;
- node-aware 512/768/1024 ceilings and global cap;
- provider-metric removal before semantic validation;
- execution-time owner mutation after a captured model selection;
- exact-action mismatch failing ownership closed;
- request-start failure resolving the required judgment.

Passing validation:

- transport reliability: 5 groups;
- live runtime regressions: 8/8;
- core V18CPG contracts: 18 groups;
- shared blockers: 15 groups;
- released turn-judgment contract;
- Raging Bolt turn completion: 28/28;
- 24-deck coverage: 24/24 profiles and 12/12 capability modules;
- 24-deck no-model smoke: 26 exact Rule-floor games;
- 24-deck enabled fake smoke: 604 accepted calls;
- Route Value Graph local p95 remained approximately 5.2 ms.

Final real DeepSeek V4 Pro paired smoke:

```text
seeds:                     183410..183412
clean games:               3/3
Rule wins:                 2/3
V18CPG wins:               2/3
model calls:               28
accepted/rejected:         14/14
response_truncated:        0
schema metadata pollution: 0
responses over 512 tokens: 2
completion max:            637 tokens
model-owned actions:       1
zero-model-action checks:  2
reference mismatches:      0
visible-wait p50/p95:      3977/6261 ms
```

The one real model-owned action was an executed `model_selected_local_route` attack with a consumed ownership ticket. The other two games had no model-owned action and matched their verified-local decision logs exactly.

This smoke proves the reliability fixes and restores same-seed parity with the Rule result. It is not a statistical claim that V18CPG is stronger than Rule; promotion still requires the larger paired confidence gate.

## Accepted-policy execution hardening

The first audit split showed that response acceptance was still a poor proxy
for strategic effect: 28 model calls produced 14 accepted responses, but only
one executed action was model-owned. The remaining accepted responses were
mostly exact Rule-root shadows. Investigation found four separate engineering
causes:

1. request facts, validator facts, delta facts, and graph-execution facts had
   drifted into different catalogs;
2. a shadow root carried model graph provenance into a Rule-owned nested
   interaction, allowing the same search card to choose a different target;
3. duplicate host `prepare` calls could relabel an already selected model
   branch as local;
4. deterministic local upgrades ran before an accepted model checkpoint was
   resolved, so the graph was erased before its successor participated in
   arbitration.

### Single request-scoped fact contract

`facts` is now the only guard namespace. The exact public scalar leaves sent
in a request become that request's allowed fact paths and drive all four
consumers: response validation, guard execution, material delta, and audit.
Safe wire-only canonicalization removes an accidental `facts.` prefix and maps
the unambiguous legacy energized-engine alias; arbitrary frontier,
`conditional_suffix`, capability, and hidden paths remain invalid.

The engine also publishes `route.available.<route suffix>` for every
registered macro route after rebuilding the current frontier. Every
`follow_route` checkpoint branch must prove its target with the matching
availability boolean. A checkpoint may contain up to four bounded alternatives
while the graph remains subject to its profile node limit.

### Root transaction and graph provenance

Root action ownership and graph provenance are independent:

```text
exact Rule root action owner = deadline_fallback
accepted future graph origin = model_shadow_rule_root
validated successor owner    = policy_graph_branch
```

The Rule root transaction includes the card/action, every nested interaction,
resource payment, target, and ownership ticket. A shadow graph cannot enable a
`local_gate`-only search override. It survives the root only when the current
route declares a real successor. Re-entry on the same observation preserves
`deadline_fallback` at the root and `policy_graph_branch` after the graph has
advanced.

This is checked by a deterministic fake client: five games, 142 accepted Rule
root responses, zero model-owned actions, and `5/5` exact decision-log equality
with the verified-local reference. Outcome equality alone is not sufficient.

### Checkpoint-first certified arbitration

On a new public observation, an accepted model checkpoint is resolved before
an optional local verified upgrade. The result is then arbitrated:

- if model branch and public certificate bind the same exact candidate, the
  action remains `policy_graph_branch` and carries the certificate into its
  interaction;
- if they disagree, the stronger deterministic certificate preempts the model;
- if the model branch is unavailable or unsafe, it fails closed to the
  verified/local path;
- completion barriers and Hard Guards remain unconditional Base constraints.

This ordering increases real graph use without weakening deterministic safety.

### Bounded overflow pruning

The wire limit remains eight nodes; the local defensive hard limit remains
twelve. A fully shaped acyclic response between those limits is no longer
discarded wholesale. The validator keeps the root and earliest declared nodes,
removes only overflow tails, erases edges to removed nodes, and converts a
removed checkpoint `otherwise` target to `replan`. It never invents an edge,
candidate, route, or action. Audit records
`canonicalized_overflow_nodes`.

### Scheduler and audit semantics

A required judgment may be skipped only when the full legal candidate pool
proves a terminal Rule action has no admissible switch. Skips are resolved
turn judgments and are audited separately from requests.

Report these independently:

- `model_accepted` and `model_shadow_accepted`;
- `model_root_takeovers`;
- `model_branch_action_results`;
- `model_owned_action_results`;
- `model_execution_per_call`;
- model/local graph branch hits;
- retained shadow information epochs;
- terminal judgment skips;
- zero-model-action verified-reference equality.

### Final focused evidence

Final real DeepSeek V4 Pro smoke on seeds `183410..183412`:

```text
clean games:                       3/3
Rule / V18CPG wins:                2/3 / 2/3
model calls:                       20
accepted / rejected:               15 / 5
model root takeovers:              1
model branch action results:       4
model-owned action results:        5
model execution per call:          25%
visible-wait p50 / p95:            5061 / 8142 ms
turn visible-wait p95:             8361 ms
```

The earlier sample executed one model action in 21-28 calls depending on the
intermediate build; the final architecture executed five in 20 calls while
preserving the same paired results. This is evidence that acceptance now
reaches the engine more often, not a statistical claim of superiority.
Route Value Graph v3 remains production shadow and still requires its separate
real-model promotion gate.
