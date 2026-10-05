# PtcgDAP public architecture record

2026-09-30：卡牌内容增量更新的客户端、公开协议和维护者发布工具已实现并完成本地验收；见 [设计与操作说明](card-content-updates.md)。需要一次底座客户端发行，生产部署另行执行。

2026-09-19: Complete 1,011-card developer catalog refresh and source-delivery checks; see [71](71-developer-card-catalog-refresh.md). Server deployment remains a separate acceptance claim.

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

Game UI, functional and AI test discovery, quality gates, isolation, multiversion
selectors and regression commands are documented in
[the testing architecture guide](testing-architecture.md).
