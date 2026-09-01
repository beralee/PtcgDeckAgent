# PtcgDAP public architecture record

This directory documents the open-source, device-local CABT/Kaggle policy
boundary, Godot host integration, author strategy package format, conformance
gates, and rollback model.

The operator-hosted Control service, Battle Bot, production database,
administrator/scheduler implementation, Alipay Cloudrun deployment material,
and production evidence are intentionally not part of this repository. They
are maintained in the adjacent confidential worktree
`D:\ai\code\PtcgDAP-private-cloud`.

Public code must remain useful without that private worktree. It may call a
configured remote API through documented wire behavior, but it may not import
or package private service implementation.

## Public reading order

Read documents 01–10 first, followed by 25, 30 (competitive author policy),
50, 52, 55, 66, `STATUS.md`, `IMPLEMENTATION_CHECKLIST.md`, and
`SOURCE_LOCK.json`.

## Validation levels

- Interface alignment: public observation and action-window contracts match.
- Cross-runtime conformance: Python and GDScript produce matching decisions for
  pinned vectors.
- Engine parity: explicitly scoped behavior is proven against the official
  oracle. It is never inferred from interface tests alone.
- Device acceptance: the pinned PC/Android package operates offline within its
  approved resource profile.
