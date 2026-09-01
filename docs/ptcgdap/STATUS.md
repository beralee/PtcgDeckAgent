# PtcgDAP public status

Updated: 2026-09-01

## Current state

- The public repository owns the CABT-compatible policy boundary, Godot host
  adapters, author `.ptcgai` package format, local strategy execution,
  conformance contracts, and public client integrations.
- The aligned player path remains device-local and does not require a hosted
  inference service.
- Confidential Control/Battle Bot implementation, MySQL operations, cloud
  deployment tooling, private tests, release archives and operational evidence
  were separated into `D:\ai\code\PtcgDAP-private-cloud`.
- The public tree contains no `services/ptcgdap_replay` or Alipay Cloudrun
  deployment implementation. A boundary test guards against reintroduction.

## Claims and limits

- Public interface and conformance evidence remains available in this tree.
- Official CABT engine parity is claimed only for explicitly recorded scopes.
- Cloud production status, database state and deployment verification belong to
  the private operations record and are not asserted by this public status.

## Rollback

The pre-split private migration manifest and all moved local artifacts remain
in the adjacent private worktree. The public Git history before the merge is
unchanged and can be used to revert the public checkpoint if needed.
