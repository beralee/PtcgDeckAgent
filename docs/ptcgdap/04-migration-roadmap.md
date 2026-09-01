# 04 — Public migration roadmap

## Gate order

1. Freeze official source hashes, enum snapshots and raw wire fixtures.
2. Prove identity and hidden-information firewall behavior.
3. Introduce immutable select windows and host-owned execution tickets.
4. Add deterministic public-only fallback and incremental decision traces.
5. Establish Python/GDScript conformance on shared vectors.
6. Run the first deck vertical slice in shadow, then canary, then active mode.
7. Package the complete local runtime and pass pinned Windows acceptance.
8. Complete the separately approved Android offline/resource gate.
9. Expand deck coverage only after the earlier gates remain green.

## Promotion rules

- Contract tests precede match benchmarks.
- Shadow output precedes canary execution; canary precedes active rollout.
- Invalid action, stale binding, hidden information, dirty-game, schema or
  packaging failures block promotion regardless of win rate.
- Runtime, policy, catalog and contract identities remain pinned for a match.
- Every promotion retains the last known-good local package and feature flag.

## Current boundary

The public roadmap covers the device-local policy and clients only. Hosted
Control/Battle Bot rollout, database migration and cloud release gates are
maintained in the confidential sibling worktree.
