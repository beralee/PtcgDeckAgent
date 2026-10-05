# Team Rocket's Arbok hand-entry restriction — 2026-09-27

## Card and cause

The audited printing is `data/bundled_user/cards/CSV10C_121.json`, effect ID
`9e832b50de492aef54f2a9d3c4e588f0`, imported from
<https://tcg.mik.moe/cards/CSV10C/121>. The default local Godot user cache also
contains the same Glare wording. The source page was unavailable to the web
reader; the equivalent official English card confirms the restriction:
<https://asia.pokemon-card.com/sg/card-search/detail/19659/>.

While Arbok is Active, the opponent cannot put Pokemon with Abilities into
play from hand, except Team Rocket's Pokemon. This includes hand evolution.
Its existing CSV10C registry entry and `blocks_card_from_hand` implementation
were correct. `EffectProcessor` already aggregates the restriction and checks
ability suppression, but the basic-bench and normal-evolution validators never
consulted it. The old test called the effect directly and missed those consumers.
Rare Candy's candidate and execution predicate had the same omission.

## Change

- `RuleValidator` now checks the existing hand restriction for direct bench
  entry and normal evolution, returning the existing source-specific reason.
- `EffectRareCandy` checks it in the common target predicate, used for
  availability, UCIS candidate generation and execution revalidation. It uses
  the existing processor supplied by the live effect pipeline.
- No card data, registration, deck list, strategy, public contract, or network
  behavior changes are required.

## Validation

Godot `4.6.1.stable.official.14d19694e`; serial suites with isolated user data.

Clean RED: `.godot_test_user/arbok_red_clean/report.json` — 5 passed, 3 failed.
Failures demonstrate illegal bench placement/evolution, missing UI rejection,
and Rare Candy accepting a blocked evolution. No script errors in this run.

GREEN: `.godot_test_user/arbok_final/report.json` — 8/8. Covers both seats,
real Arbok registration, live commands with unchanged hand/board on rejection,
player UI, the author's legality builder, Rocket/plain exceptions, moving
Arbok out of and back into Active, suppression, Rare Candy candidate filtering,
stale selection rejection and registered Candy execution after suppression.

Shared regression: `.godot_test_user/arbok_regression/report.json` — 79/79:
Csv10c121125 8, EffectInteractionFlow 27, InvalidActionReasons 10,
RuleValidator 25, UcisInteractionCompiler 9.

Host regression: `.godot_test_user/arbok_host/report.json` —
A3ExternalDecisionPort 19/19, including the existing Rare Candy evolution-trigger
recovery case. Combined unique suite coverage: 98 passing tests.

Commands:

```powershell
.\scripts\tools\run_godot_tests.ps1 -Runner functional -Suite 'Csv10c121125,RuleValidator,EffectInteractionFlow,InvalidActionReasons,UcisInteractionCompiler' -UserDataRoot .godot_test_user/arbok -ReportDirectory .godot_test_user/arbok_regression
.\scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_csv10c_121_125.gd -UserDataRoot .godot_test_user/arbok -ReportDirectory .godot_test_user/arbok_final
.\scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/ptcgdap/godot/test_a3_external_decision_port.gd -UserDataRoot .godot_test_user/arbok_host -ReportDirectory .godot_test_user/arbok_host
```

Scope is local Godot rules/UI/action-frontier and effect integration. This is
not official-engine parity, a packaged release, or Android device acceptance.

## Rollback

Remove the two added hand-restriction checks in `RuleValidator`, the added
processor restriction check in `EffectRareCandy`, and the three new Arbok
regression tests/helpers. Preserve all unrelated pre-existing workspace edits.
No migration or seed regeneration is needed. Nothing was committed or published.
