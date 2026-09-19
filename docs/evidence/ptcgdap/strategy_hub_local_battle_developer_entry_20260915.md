# Local strategy battle action and developer onboarding — 2026-09-15

## Change

PC leaderboard actions now recognize installed strategies even when the leaderboard omits the archive hash and installable-release metadata. Matching uses package ID, preferring a unique matching version; when only one other local version exists, the action uses that local version instead of downloading a different version to play. Names never establish identity. Ambiguous archives fail closed; an explicit hash for an existing same-version archive must match. The action tooltip identifies the local version, and battle setup still re-resolves its complete package ID/version/SHA reference and checks platform admission. This is a local opponent choice, not evidence that local bytes equal the ranked release.

The installed action reads `对战` and performs no profile/download request. Catalogue changes update existing rows, including late startup scans and removals. This also handles the observed public ranking at version 5.13.0 while the isolated local catalogue already contains 5.21.0 of the same package.

The shared `ReplayTab` now reads `开发者` and is accessible on PC, Android and Web. A concise introduction above the PC replay library explains registration, Forge development/local testing, signing/uploading and qualification. The primary button opens exactly `https://ptcg.skillserver.cn/dist/developers.html` using the existing platform browser mechanism; failure displays the URL. The supplied public page was fetched read-only to verify the workflow. Mobile users see the same entry plus a suggestion to create/test on a computer; unsupported replay playback remains hidden and uninitialized. The developer workspace uses one outer scroll.

## Validation

All suites use `scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/ptcgdap/godot/<suite>.gd` with isolated APPDATA.

| Suite | Passed | Log under `.godot_test_user/logs/` |
| --- | ---: | --- |
| test_strategy_hub_developer_entry | 4 | focused-20260915-002430.log |
| test_strategy_hub_desktop_flow | 4 | focused-20260915-002503.log |
| test_strategy_hub_scene | 22 | focused-20260915-002506.log |
| test_strategy_hub_responsive | 4 | focused-20260915-002254.log |

The first focused run failed before implementation (`focused-20260915-001901.log`). Coverage includes offline installed-action routing, exact selected local reference, later scans/removal, different local versions, ambiguous identity, explicit hash mismatch, portal URL/error handling, mobile navigation and existing PC replay behavior. Portal tests use a fake opener and perform no registration or publication.

Actual Godot OpenGL screenshots were inspected at 1600×900, 900×1800 and 390×844. The mobile portal button fits in the first viewport. PC discovery shows `对战` on the already-installed top strategy. Probes: `tmp/strategy_developer_probe.gd`, `tmp/strategy_discovery_probe.gd`; images `tmp/strategy-developer-1600.png`, `tmp/strategy-developer-390.png`, `tmp/strategy-developer-900.png`, `tmp/strategy-discovery-1600.png`. Existing Unicode startup warnings remain. Scoped diff whitespace checks pass.

## Boundary and rollback

This validates the shared Godot UI and local action routing, not a new engine-conformance level or an exported Android/Web build. No package was downloaded/deleted for the visual review, no account was created, no private service changed, and no commit/push/export occurred.

Rollback this task's listing-to-local matching, catalogue row refresh extension and `对战` label; remove the developer intro/portal handler and restore the replay-only platform tab gating with the corresponding tests. Preserve the preceding discovery redesign, DeepSeek label, deck previews, HUD deletion fix and unrelated workspace edits.
