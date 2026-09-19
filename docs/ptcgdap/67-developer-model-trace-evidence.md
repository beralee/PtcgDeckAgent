# Developer model input evidence

Updated: 2026-09-09

The development battle owner now includes `host.model_input_evidence` in newly
captured decision-window records. This is diagnostic evidence, not production
authority or automatic training eligibility. Existing recordings are unchanged.

For an accepted, non-fallback Host response, capture calls the existing
`PtcgDAPModelActor._tensorize_development_frame` and the same
`_model_frontier_from_response` used by execution. The record contains the
24-column frame, flattened 16-column option rows and presence arrays, live mask,
semantic keys, row/index mapping, frontier indexes and rows, projector source
SHA-256, and profile `ptcgdap-development-model-input-v1`. Zero padding beyond
the live option count is omitted. Captured arrays do not authorize any action.

An unavailable actor, invalid rule indexes, unsupported UID, hidden input, or
projection failure produces a stable unavailable reason. Rejected or fallback
Host records never capture usable model inputs. If Base has no audited veto
frontier, the runtime helper retains only its rule fallback indexes; ranked
preferences must never be substituted as a larger legal frontier.

## Verification and limits

`test_developer_model_trace.gd` first failed two tests for the missing capture
method, then passed three focused Godot tests covering exact runtime projection,
semantic option reorder, hidden/unknown UID/index gates, actual trace queue
attachment, rejected windows and unchanged inputs. The stock Godot 4.6.1 run
also printed existing Unicode NUL parsing warnings; this change does not claim
to resolve them or establish Python/Godot semantic-hash parity.

The existing `test_author_strategy_developer_decision_trace.gd` suite was also
run: three writer/manifest checks passed; two exact-package integration checks
failed with `package_integrity_invalid` for the pinned legacy package. No gate
was relaxed. This is an unresolved integration prerequisite, not a passing
whole-battle acceptance result.

TODO: verify a complete newly recorded real battle, freeze cross-language
projection vectors, validate engine-commit evidence and training labels, and
only then enable native trace to BC dataset conversion. Source hashes alone do
not authenticate a trace producer. CABT parity and production remain separate.

## Rollback

Remove the additive capture method and `host.model_input_evidence` field and the
new focused suite. Preserve pre-existing owner changes. The pre-change owner
bytes are retained in the Forge workspace at
`work/upgrade-validation/engine-backup-20260909/PtcgDAPAuthorDevelopmentBattleOwner.gd`.

## Changelog

- 2026-09-09: additive diagnostic capture and three focused Godot tests; no
  decision algorithm, model, package, gate, or production installation changed.
