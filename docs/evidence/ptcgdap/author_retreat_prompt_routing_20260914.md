# Author retreat prompt routing regression

Date: 2026-09-14

## Root cause

`AuthorStrategyEngineActionExecutor` correctly treats RETREAT as a declaration
and calls the real BattleScene retreat entrypoint. Its two subsequent windows,
`retreat_energy` and `retreat_bench`, were unconditionally displayed through
the human dialog / field selection controls. Neither was recognized by
`_is_ui_blocking_ai`, so displaying the prompt also prevented the author owner
from running its existing payment and switch handlers. This is shared Godot
UI routing code, with no Android-specific branch in the failing path.

The earliest owning layer is the BattleScene prompt publisher and scheduler.
The policy, card effects, and retreat engine rule do not require changes.

## Repair

- Publish the complete retreat prompt data before routing it. For the runtime
  author seat, schedule the owner without opening human controls.
- Recognize author-owned retreat windows in scheduler readiness and modal
  blocking checks. Keep animation and other independent modal blockers.
- Use the prompt's player field, including in development dual-seat routing;
  current turn alone cannot grant authority over another player's prompt.
- Keep the existing author policy windows, validation, and engine commit.
  Human retreat still uses the existing touch / mouse interface.

Runtime changes are limited to `BattleSceneBoardActionRuntime.gd` and
`BattleSceneSharedHudAiRuntime.gd`.

## Validation

Windows Godot 4.6.1, headless, isolated test user data. No Python pools or
external inference services were used.

1. The four new routing tests failed before the fix: human field choice
   exposed, human energy dialog exposed, wrong-seat readiness after a modal
   disappeared, and scheduler blocked by the author retreat overlay.
2. Final dedicated suite: **6/6**. Includes a real reviewed local package,
   production owner factory, BattleScene retreat declaration, scheduler, and
   real engine commit. Main-thread and worker policy profiles each accept
   exactly two distinct windows (`energy_payment`, `self_switch`), pay only
   the required energy, change Active Pokemon, and set the retreat-used flag.
   Policy errors, engine rejections and same-window fallbacks are zero.
   Worker tests explicitly wait for the result before scheduler consumption;
   they do not constitute on-device render-loop acceptance.
3. Existing `test_battle_ui_features_part2.gd`, filter `retreat`: **14/14**,
   including the Android portrait touch profile, energy choice / overpayment,
   real bench clicks, touch echo protection and Rescue Board.
4. Existing `test_battle_ui_features_part4.gd`, filter `retreat`: **5/5**.
5. Runtime diff whitespace check passes.

The final dedicated fixture disposes its detached controls and emits no
resource-leak messages. Existing broader UI suites retain their test teardown
resource warnings; startup logs also contain existing Unicode NUL warnings.
These runs are functional evidence, not a clean packaged-device log gate.

Local log identities (under `.godot_test_user/logs`):

| Log | SHA-256 |
| --- | --- |
| `focused-20260914-232422.log` (RED) | `138C3DC75E965A529749D65F23632B0D2164F533CB1698D7849736F3A41193BB` |
| `focused-20260914-232911.log` (6/6) | `696CC0A6031B947CC87EB8A920DDD0A2CFA0C1F8B7FC6C70651373630D57C64A` |
| `focused-20260914-232542.log` (14/14) | `99DF4CE10F75BB947C83A9B2D070AC80F1F040F33701AE25B8BD3D3D9ED80C76` |
| `focused-20260914-232836.log` (5/5) | `1D83352EA17CEB5670B2DD68994EC969E393142F3D7B10EADD15E917B3145118` |

Reproduce the dedicated suite with `scripts/tools/run_godot_tests.ps1 -Runner
focused -SuiteScript res://tests/test_author_retreat_prompt_routing.gd`.

## Scope and rollback

Achieved: local shared-UI ownership regression coverage and actual local
package / engine retreat integration. No claim of official CABT engine parity,
Android physical-device acceptance, or a newly installed APK. No package,
release, private service, or external oracle repository was changed.

Rollback only the retreat routing hunks in the two runtime files. Keep the
regression tests and this record. Apply rollback between matches; do not
replace the owner of an active match. Existing unrelated worktree changes
must be preserved.
