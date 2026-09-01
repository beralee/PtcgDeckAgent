# PtcgDAP public repository charter

## Mission

This public worktree owns the CABT/Kaggle-compatible, device-local strategy
runtime and its Godot integration. The public policy boundary remains:

```text
agent(raw_observation) -> list[int]
```

The aligned Godot path must remain local to the player's PC or Android device.
It must not depend on an operator-hosted inference service, network access, or
an externally installed Python runtime.

## Required reading order

Before planning or editing PtcgDAP code, read:

1. `docs/ptcgdap/README.md`
2. `docs/ptcgdap/01-official-cabt-contract.md`
3. `docs/ptcgdap/02-current-state-and-gap-analysis.md`
4. `docs/ptcgdap/03-target-architecture.md`
5. `docs/ptcgdap/04-migration-roadmap.md`
6. `docs/ptcgdap/05-validation-promotion-and-rollback.md`
7. `docs/ptcgdap/06-first-vertical-slice.md`
8. `docs/ptcgdap/07-decisions-risks-and-open-questions.md`
9. `docs/ptcgdap/08-author-strategy-package-mode.md`
10. `docs/ptcgdap/09-author-strategy-package-engineering-handoff.md`
11. `docs/ptcgdap/10-author-strategy-developer-guide.md`
12. `docs/ptcgdap/25-kaggle-official-replay-information-upgrade-analysis.md`
13. `docs/ptcgdap/30-competitive-author-policy-v2.md`
14. `docs/ptcgdap/50-turn-program-v1-shadow-architecture.md`
15. `docs/ptcgdap/52-turn-program-automatic-generation-and-shadow-differential.md`
16. `docs/ptcgdap/55-turn-program-public-transition-canary-and-10-round-evaluation.md`
17. `docs/ptcgdap/66-state-conditioned-transaction-value-v2-and-paired-branch-credit.md`
18. `docs/ptcgdap/STATUS.md`
19. `docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md`
20. `docs/ptcgdap/SOURCE_LOCK.json`

The read-only external oracle is `D:\ai\code\ptcgabc`. Do not modify it
unless the user explicitly expands the task.

## Repository boundary

The confidential Control service, Battle Bot, MySQL schema/migrations,
administrator and scheduler implementation, Alipay Cloudrun deployment tools,
operational documents, local databases, and release evidence are owned by the
adjacent private worktree `D:\ai\code\PtcgDAP-private-cloud`.

Do not copy private service code, deployment configuration, credentials,
production receipts, database snapshots, or private documentation into this
repository. Public clients may depend only on documented HTTP/wire behavior;
they may not import a private server module.

## Non-negotiable architecture invariants

1. The current `select.option` list is the sole legal action frontier.
2. Policy output is only indexes into the current window and never executes an
   engine method directly.
3. Every accepted selection invalidates the old window; reobserve and rebind.
4. Old option indexes are never persisted.
5. Policy input contains no mutable Godot engine or scene object.
6. Public observations are built with an allow-list and provenance.
7. Hidden opponent cards, deck order, prizes, private RNG and private replay
   state never enter policy input, public traces, or fallbacks.
8. CABT official identity and Godot-local printing identity remain separate.
9. Option fingerprints cover populated official fields and remain scoped to an
   observation/window.
10. Every prompt uses the same select-window lifecycle.
11. Public decision traces and private engine replays remain separate.
12. Policy failure falls back deterministically from the same public input.
13. Kaggle mode performs no network ingress or egress.
14. `search_begin_input` remains opaque, ephemeral and unlogged.
15. Unknown additive fields fail closed without crashing parsing.
16. Base Graph owns legality, terminal protection, transaction safety and veto.
17. Persistent plans retain no stale authority after observation change.
18. Interface, cross-runtime conformance and engine parity are separate gates.
19. The shipped Godot path remains completely device-local.
20. Python/PyTorch are development tools, not player-runtime dependencies.

## Implementation workflow

For implementation tasks: inspect status, preserve unrelated changes, identify
the earliest owning layer, add a focused failing test, make the smallest owner
change, run targeted and integration tests, record evidence and rollback, and
state the achieved alignment level without overclaiming.

Do not commit, push, publish, modify `ptcgabc`, or change private cloud services
unless the user explicitly authorizes that action.

## Process safety

- Do not run high-memory Python pools in parallel.
- For `D:\ai\code\ptcgabc`, use at most `--workers 4` and obey its safeguards.
- Before a heavy run, verify no other heavy Python job is active, available RAM
  is at least 12 GiB, and system commit is below 70%.
- Never override `PTCGABC_MAX_*` or `PTCGABC_MIN_*` without explicit approval.
