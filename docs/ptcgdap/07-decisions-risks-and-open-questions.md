# 07 — Public decisions, risks and open questions

## Accepted decisions

- The sole public action boundary is the current select-window index list.
- Public observations are allow-listed; hidden information never reaches
  policies, traces or fallbacks.
- CABT official identity and Godot-local printing identity remain separate.
- Base Graph owns legality, transaction safety, terminal protection and veto.
- Author strategies are immutable `.ptcgai` packages with explicit identity,
  trust roots, catalogs and rollback metadata.
- Python is authoritative for development/Kaggle reference behavior; GDScript
  is the portable device baseline.
- The player runtime performs no hosted inference and remains operational in
  airplane mode.
- Interface alignment, cross-runtime conformance and engine parity are
  independent claims.
- Public replay/display artifacts never gain engine or ticket authority.
- Public clients may use a configured service API but may not import its
  confidential implementation.

## Active risks

- Official schemas can add fields or enum values; parsing must preserve raw
  values and fail closed when semantics are unknown.
- Plans can accidentally retain stale scores or bindings after state change.
- Local and official card identities can be incorrectly merged by display
  name.
- Optional native inference can drift numerically or fail on a device ABI.
- Diagnostic output can leak hidden information unless provenance remains
  enforced at the producer.
- Passing win-rate evidence can obscure invalid-action or packaging failures.
- Android resource and offline acceptance remains a separate product gate.

## Open questions

- Which Android ABI/device matrix becomes the product-approved acceptance
  profile?
- Which bounded native scoring backend, if any, is worth shipping after exact
  cross-runtime conformance and resource qualification?
- Which additional deck becomes the next vertical slice after the first slice
  remains green across interface, conformance and package gates?

## Confidential record split

Historical hosted-service, scheduler, database, administrator and cloud release
decisions were moved intact to `D:\ai\code\PtcgDAP-private-cloud`. They are not
authority for changes in this public repository.
