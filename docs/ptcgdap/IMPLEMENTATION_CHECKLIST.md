# PtcgDAP public implementation checklist

## Contract boundary

- [x] Policy accepts only raw/public observation data.
- [x] Policy returns indexes into the current immutable select window.
- [x] Accepted selections invalidate stale bindings.
- [x] Hidden information is excluded by allow-list projection.
- [x] Deterministic legal fallback remains local.

## Host and packaging

- [x] Python is retained for development/reference work.
- [x] GDScript is the portable player-runtime baseline.
- [x] Author `.ptcgai` packages have explicit identity and signature contracts.
- [x] PC/Android execution has no hosted inference prerequisite.

## Validation

- [x] Interface and cross-runtime conformance are reported separately.
- [x] Engine parity claims are scoped and evidence-backed.
- [x] Rollback paths remain explicit.
- [ ] Complete the remaining product-approved Android device acceptance gate.

## Confidential infrastructure split

- [x] Control, Battle Bot and database implementations moved out of the public
  worktree.
- [x] Cloud deployment tools, operational documents and release artifacts moved
  with their owner.
- [x] Public/private dependency direction is one-way: private may consume the
  public runtime; public may not import private implementation.
- [x] Automated boundary checks prevent accidental reintroduction.
