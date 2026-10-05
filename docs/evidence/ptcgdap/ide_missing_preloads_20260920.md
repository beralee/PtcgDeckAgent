# IDE missing script preloads — 2026-09-20

## Cause and repair

- The unused public `GodotV18CompetitionCliEntrypoint.gd` still preloaded
  `GodotV18CompetitionEntrypoint.gd`, which is absent after the public/private
  split. Removed the orphan CLI wrapper and its UID. No private implementation
  was restored, and no private worktree was changed.
- `tools/update_lab/Main.gd` used `res://lab/LabServer.gd`, a path that exists
  only after the lab builder copies its sources to a standalone project.
  It now preloads the sibling `LabServer.gd`, resolving in both locations.
- Added `tests/test_godot_preload_paths.py` to detect missing literal GDScript
  preload targets in public source directories, respecting `.gdignore` roots.

## Validation

The preload regression failed before the repair with exactly the two reported
missing references. It passes after the repair:

```powershell
python -m unittest tests.test_godot_preload_paths -v
.\scripts\tools\run_godot_tests.ps1 -Runner functional -Suite 'ParserRegressions,CompileCheck,ProjectScanBoundaries' -UserDataRoot .godot_test_user\ide_parse_regressions_20260920
```

- Python preload regression: 1/1 passed.
- Godot 4.6.1 functional regressions: 18/18 passed. Log:
  `.godot_test_user/logs/functional-20260920-234324.log`.
- Godot `--check-only --script res://tools/update_lab/Main.gd`: exit 0,
  no parse errors.
- Copied the actual lab scripts and shared updater dependencies into an isolated
  `.tmp/ide-update-lab-parse-20260920` project using the builder's `lab/` layout.
  Godot `--check-only` passed for both `res://lab/Main.gd` and
  `res://lab/LabUpdater.gd`, without changing or exporting the existing lab.
- A headless editor import reported no script parse errors, but its additional
  editor process could not copy/open the native extension's temporary DLL while
  the user's editor was running. This is not claimed as a clean native-extension
  startup check. The direct script checks and functional tests above were clean.

Scope is local source-reference and parser regression validation only. No
policy-alignment, engine-parity, APK/device, or release claim is made.

## Rollback

Restore only the removed CLI wrapper and UID from the prior revision, restore
the old Server preload in `tools/update_lab/Main.gd`, and remove the added
preload regression and this note. That also restores the reported parse errors;
do not revert unrelated in-progress updater or strategy changes.
