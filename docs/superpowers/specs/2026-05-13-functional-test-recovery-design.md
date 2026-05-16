# 2026-05-13 Functional Test Recovery Design

## Goal

Bring the functional test suite back to green after the BattleScene portrait work, CSV9C card import, app version bump, and macOS window sizing changes.

The target is not to blindly rewrite assertions. The change separates:

- Real product bugs that must be fixed in runtime code.
- Tests that are leaking local `user://` preferences and must isolate their layout state.
- Tests whose expectations are stale after an intentional product decision.

## Current Failures

The latest functional run reported:

`Total: 1911 | Passed: 1893 | Failed: 18`

The failures group into seven buckets.

1. Layout state leakage

Local `user://battle_setup.json` contains `battle_layout_mode: portrait`. Several headless tests instantiate `BattleSetup` or `BattleScene` without forcing their layout state, so landscape assertions run through portrait branches.

Affected areas:

- Battle setup default selector.
- Batch draw reveal scale and centering.
- Landscape match-end AI panel visibility.
- HUD card scrollbar height.

2. Portrait field interaction metrics

`BattleInteractionController.update_field_interaction_panel_metrics()` can ignore the explicit viewport argument when the scene reports portrait popup mode. Detached test scenes can therefore use the default portrait popup size instead of the provided phone viewport.

3. CSV9C_175 attack effect scope

`AttackBenchCountDamage` does not expose `applies_to_attack_index`, so the first attack's bench-count damage is visible on both attacks of Terapagos ex.

4. Bench-enter ability contract

The game now avoids automatically resolving bench-enter abilities that require a player choice. This matches the Squawkabilly fix direction. The old Lumineon test still expects an automatic Supporter search.

5. macOS launch contract

The current runtime intentionally keeps macOS windowed and uses a large windowed size. One older GameManager test still expects maximize.

6. Gardevoir strategy contract

Current Gardevoir scoring permits active Drifloon manual Psychic attachment in attack-gap scenarios. Older tests assert Psychic Energy is never manually attached. The suite needs a contract that matches the chosen strategy behavior.

7. App version contract

The app version is now `0.2.3`. UpdateChecker tests still assert `0.2.2` as current and `0.2.3` as available.

## Design

### Layout Isolation

Tests that assert a landscape-specific behavior must force the scene or GameManager into landscape within the test fixture. They must not depend on the developer's local battle setup preference.

Implementation choices:

- Set `_active_battle_layout_mode = "landscape"` in `test_battle_ui_features.gd`'s battle scene stub.
- In setup selector tests, set `GameManager.battle_layout_mode = auto` after scene `_ready()` has loaded local settings and before rerunning `_setup_battle_layout_options()`.
- In HUD scrollbar tests, save and restore `GameManager.battle_layout_mode`, then force landscape for desktop scrollbar contracts.

### Portrait Metrics

When `update_field_interaction_panel_metrics(viewport_size)` receives an explicit non-zero viewport, that viewport is authoritative. Portrait popup content size should only be used when no explicit viewport is passed.

This keeps production portrait layout intact while making direct metrics calls deterministic.

### Attack Effect Scoping

`AttackBenchCountDamage` should support attack-index binding like other multi-attack effects. `EffectRegistry._bind_attack_index_if_supported()` already binds either the property `attack_index_to_match` or `bind_default_attack_index()`. Add the property and `applies_to_attack_index()`.

For CSV9C_175, bind:

- `AttackBenchCountDamage` to attack 0.
- `AttackPreventDamageNextTurn` to attack 1.

### Bench-Enter Ability Contract

Interactive bench-enter abilities should not auto-resolve when a choice is required. The test should assert:

- Benching succeeds.
- No Supporter is added automatically.
- `get_bench_enter_ability_interaction_steps()` exposes the choice.
- Explicit `use_ability()` with a selected Supporter resolves.

If a future non-interactive bench-enter ability exists, it can keep auto resolution.

### macOS Contract

Keep the newer product behavior:

- `_should_maximize_desktop_window("macOS") == false`.
- `_should_use_large_windowed_desktop_launch("macOS") == true`.

Update the stale GameManager test to match this split.

### Gardevoir Contract

Keep the current strategic direction:

- Psychic Embrace with discard fuel should be better than empty discard, but can still be negative if no valid target exists.
- Manual Psychic attachment is generally bad for shell pieces and Gardevoir ex.
- Active Drifloon with a one-energy attack gap may be allowed as a tactical emergency line.

The tests should stop asserting "never attach Psychic to Drifloon" globally, and instead assert the narrower intended behavior.

### Version Contract

Update version tests to use `0.2.3` as current and compare a future version, such as `0.2.4`, as available.

## Verification

Run in this order:

1. Focused suites:
   - `BattlePortraitLayout`
   - `BattleUIFeatures`
   - `HudScrollbarTheme`
   - `CardSemanticMatrix`
   - `GameStateMachine`
   - `GardevoirStrategy`
   - `GameManager`
   - `UpdateChecker`

2. Full functional suite:

```powershell
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:/ai/code/ptcgtrain' -s 'res://tests/FunctionalTestRunner.gd'
```

