# Functional Test Recovery Plan

## Scope

Recover the 18 failing functional tests reported on 2026-05-13 without reverting the portrait UI work, the macOS large-windowed launch decision, or the explicit bench-enter ability behavior.

## Steps

- [x] Add recovery design and plan documents.
- [x] Make landscape-specific UI tests independent of local `user://battle_setup.json`.
- [x] Make field-interaction metrics honor explicit viewport arguments.
- [x] Add attack-index scoping to `AttackBenchCountDamage` and bind CSV9C_175 effects to their intended attacks.
- [x] Update bench-enter ability test to validate explicit choice flow instead of automatic search.
- [x] Update macOS window tests to the large-windowed, non-maximized contract.
- [x] Update Gardevoir strategy tests to the current tactical attachment and Psychic Embrace contract.
- [x] Update app version tests to `0.2.3`.
- [x] Run focused suites and fix remaining failures.
- [x] Run the full functional suite and record the result.

## Acceptance Criteria

- Full functional suite exits cleanly.
- No test relies on the current machine's saved battle layout preference.
- Terapagos ex bench-count damage only appears on attack 0.
- Interactive bench-enter abilities require explicit player choice.
- App version tests assert `0.2.3`.

## Verification Result

- Focused suites: `436 | Passed: 436 | Failed: 0`
- Full functional suite: `1913 | Passed: 1913 | Failed: 0`
