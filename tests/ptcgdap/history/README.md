# Historical work-package audits

These modules preserve the executable audit logic for the completed P1-P5 and
AS-WP0-AS-WP6 development work packages. They intentionally use the
`history_*.py` prefix so the current main-branch test gate does not execute
assertions such as "no live consumer exists" or require today's worktree to be
byte-identical to an intermediate rollback snapshot.

The sealed evidence and rollback payloads remain under `artifacts/ptcgdap`.
Current behavior is tested by the active contract, runtime, package, device,
and public/private boundary suites in the parent directory. Historical audits
may be run only against their sealed source revision, not against current
`main`.
