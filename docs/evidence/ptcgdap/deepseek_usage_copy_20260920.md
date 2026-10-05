# DeepSeek usage and ability notice — 2026-09-20

The AI Strategy Center's embedded Settings form now presents two wrapping
notices before the API configuration fields. They explain that DeepSeek serves
supported LLM opponents, battle reviews and suggestions; ordinary rules AI and
local developer strategies do not need this API. The warm-colored ability
notice explains that model access does not guarantee stronger play, mistakes
remain possible, and the AI may not be competitive against human players.

Owner: `scenes/settings/Settings.gd`. This is UI copy only; it makes no change
to API requests, strategy decisions, credentials or package eligibility.

## Validation

- The responsive suite first failed because the notices were absent, then
  passed 4/4 after the change. It checks visibility, complete wrapping,
  narrow-screen bounds and placement before API key entry.
- Strategy-hub embedded-settings integration: 1/1 passed.
- Existing AI-settings tests in `test_non_battle_portrait_layout.gd`: 17/17
  passed. Godot emitted an ObjectDB leak warning on this suite's exit; this
  is not a clean resource-lifetime acceptance claim.
- Rendered the actual 390 × 844 hub with the compatibility renderer and
  visually checked both notices. The visual test passed 1/1.
- Tests used isolated user data at `.godot_test_user/deepseek_copy`.
  Logs and the screenshot are local under `.godot_test_user/logs` and
  `.godot_test_user/ui-captures/strategy-hub-390-settings.png`.

Scope: local UI and layout validation only; no AI-strength, engine-parity,
Android-device or release claim.

## Rollback

Remove the two notice constants and their form insertion in `Settings.gd`,
restore its label styling lists, and remove the corresponding notice checks
from `test_strategy_hub_responsive.gd`. Preserve other working-tree changes.
