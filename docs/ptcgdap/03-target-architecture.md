# 03 — Public target architecture

## Boundary

The public product has one policy contract:

```text
agent(raw_observation) -> list[int]
```

The host preserves the official raw observation, builds typed public-only
views, materializes one immutable select window, asks the policy for indexes,
validates the result against that exact window, and executes only through a
single host-owned ticket.

## Layers

1. Raw envelope: exact host payload plus pinned runtime identity.
2. Public projection: allow-listed values with provenance and unknown-field
   preservation.
3. Select window: ordered legal options, fingerprints and observation/window
   identities.
4. Policy core: device-local goals, scoring, bounded search and deterministic
   fallback with no engine authority.
5. Host adapter: validation, ticket issuance, execution and immediate window
   invalidation.
6. Evidence: incremental public decision traces kept separate from private
   engine recordings.
7. Package: signed, versioned local artifacts with pinned catalogs, policies,
   resource profiles and rollback identities.

## Host separation

The official Python environment is authoritative for Kaggle packaging. Godot
uses a constrained language-neutral artifact and GDScript portable baseline.
Neither host exposes mutable engine objects or hidden state to policy code.

## Device rule

PC and Android gameplay must complete offline. Optional native scoring backends
are bounded numeric leaves; they never own decisions and must fall back to the
local GDScript path.

## Confidential infrastructure

Hosted competition services and cloud/database operations are intentionally
outside this public architecture record and live in the adjacent private
worktree. Public clients interact only through documented wire behavior.
