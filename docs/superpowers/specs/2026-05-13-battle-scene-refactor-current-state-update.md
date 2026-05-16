# BattleScene Refactor Current-State Design Update

**Date:** 2026-05-13  
**Updates:** `2026-05-11-battle-scene-full-refactor-design.md`  
**Scope:** Current-state update after the staged entry/runtime split.

## Summary

The original BattleScene refactor design remains directionally correct, but it has not been fully implemented. The current codebase has completed an important foundation pass: context/state objects and several coordinators exist, and some recent UI and flow fixes have been moved behind focused helper modules. As a recovery step, `BattleScene.gd` has now been reduced to a thin scene entry that extends `BattleSceneRuntime.gd`, and the runtime implementation has been split into business-named runtime files under `scenes/battle/runtime/`.

The runtime business chain is temporary compatibility scaffolding, not the final architecture. It preserves the existing battle behavior while the entry and runtime files meet the immediate 3000-line target. The remaining work is to move logic from those business runtime files into domain owners and then retire the compatibility files.

The refactor should now be treated as an **in-progress staged migration**, not a completed rewrite.

## Current Measured State

Current local measurements after the latest fixes:

| Metric | Current | Original Final Target | Status |
| --- | ---: | ---: | --- |
| `BattleScene.gd` lines | 3 | 1200-1800 | Entry target met |
| `BattleScene.gd` functions | 0 | scene shell only | Entry target met |
| `BattleSceneRuntime.gd` lines | ~1890 | under 3000 during migration | Recovery met |
| Business runtime files | ~543-1871 each | under 3000 during migration | Recovery met |
| Runtime `@onready` refs | 99, now in foundation | mostly moved to `BattleSceneRefs` | Not met |
| Private scene reflection in `scripts/ui/battle` | ~1206 | near zero for migrated modules | Not met |
| Architecture files exist | yes | yes | Met |
| New architecture files avoid `scene.get/set/call("_")` | yes for audited files | yes | Met |
| Architecture audit | passing for entry shell and architecture files | passing | Met for recovery |

The current architecture audit now distinguishes the thin entry script from the business runtime files. The entry and every runtime implementation file are under the 3000-line target; scene-owned state, refs, and domain ownership remain the next measurable migration targets.

## What Has Been Implemented

The following foundations from the original design are present:

- `BattleSceneContext`
- `BattleSceneRefs`
- `BattleLayoutState`
- `BattleDialogState`
- `BattleInteractionState`
- `BattleReplayState`
- `BattleOverlayState`
- `BattleAiState`
- `BattleAdviceState`
- `BattleRecordingState`
- `BattleEffectState`
- `BattleDisplayCoordinator`
- `BattleInteractionCoordinator`
- `BattleOverlayCoordinator`
- `BattleRecordingCoordinator`
- `BattleAdviceCoordinator`
- `BattleDiscussionContextBuilder`
- `BattleMatchEndQuickReviewBuilder`
- `BattleAiOpponentFactory`
- Several focused display, layout, interaction, and advice helpers

These are useful migration targets, but many of them are still adapters or partial owners rather than complete owners of their domain.

## What Is Still Not Complete

The following original objectives remain incomplete:

- The business runtime file chain still contains the old scene-owned implementation.
- Most UI node references have not moved fully into `BattleSceneRefs`.
- Most scene-owned runtime state has not moved fully into `Battle*State` objects.
- Older controllers still rely heavily on `scene.get("_...")`, `scene.set("_...")`, and `scene.call("_...")`.
- `BattleDialogController.gd`, `BattleInteractionController.gd`, `BattleDisplayController.gd`, and `BattleOverlayController.gd` remain large and highly coupled.
- Layout extraction exists, but full removal of scene-private layout implementation is not complete.
- Prompt routing exists as a skeleton, but `_handle_dialog_choice` style scene-owned branching is not fully retired.
- Headless/AI execution still needs explicit synchronization with player UI flows when interaction behavior changes.

## Revised Design Position

The original final architecture remains the long-term target, but the next implementation should use a more explicit maturity model for each module:

| Maturity | Meaning | Acceptable Use |
| --- | --- | --- |
| Skeleton | File exists, minimal data or API only | May be referenced, not counted as migrated |
| Adapter | Wraps old scene/controller behavior | Temporary compatibility layer |
| Partial Owner | Owns a focused sub-flow or helper concern | Acceptable if tested and no new reflection is added |
| Domain Owner | Owns state, refs, public API, and tests for its domain | Target state for each refactor phase |
| Retired Wrapper | Old scene method reduced to a tiny delegating wrapper or deleted | Required before phase completion |

Current implementation is mostly between **Skeleton**, **Adapter**, and **Partial Owner**. The next work should move one domain at a time to **Domain Owner**.

## Updated Architectural Rules

These rules supersede ambiguous parts of the original plan:

1. A phase is not complete just because the target files exist.
2. A migrated module is only complete when it owns its state and has focused tests.
3. New battle UI code must not add private scene reflection.
4. Existing private scene reflection should only decrease within each phase.
5. Player UI and headless/AI bridge paths must be updated together for interaction behavior changes.
6. Structural refactors should not include unrelated gameplay rule changes.
7. Bug fixes found during refactor need their own focused regression tests.
8. `BattleScene.gd` size and wrapper count are hard gates, not advisory metrics.

## Updated Acceptance Gates

Use staged gates rather than jumping directly from ~8127 lines to 1800 lines:

| Gate | Target |
| --- | --- |
| Recovery Gate | `BattleScene.gd` back under 8000 lines and under current function threshold |
| Gate A | `BattleScene.gd` under 7000 lines; private scene reflection reduced by at least 15% |
| Gate B | `BattleScene.gd` under 6000 lines; one major controller domain becomes a domain owner |
| Gate C | `BattleScene.gd` under 4500 lines; dialog/prompt flow no longer lives in the scene |
| Gate D | `BattleScene.gd` under 3000 lines; display and interaction state mostly externalized |
| Final Gate | `BattleScene.gd` 1200-1800 lines; scene shell owns only lifecycle and orchestration |

The line-count part of **Gate D** is now met for the entry script and runtime implementation files. The ownership part of Gate D is not complete because display, dialog, interaction, and AI/runtime logic still live in the runtime compatibility file chain.

## Priority Domains

The next refactor work should be prioritized in this order:

1. **Architecture gate recovery**
   - Remove recent small scene-side growth or migrate equivalent logic into existing helper modules.
   - Restore `test_battle_scene_architecture_audit.gd` to passing.

2. **Dialog and prompt flow**
   - Highest payoff because it keeps large branching and state inside `BattleScene`.
   - Move prompt request, selection, and route execution into `BattlePromptRouter` and related prompt controllers.

3. **Interaction/effect flow**
   - Move `_field_interaction_*`, assignment, and counter distribution state into `BattleInteractionState`.
   - Keep player UI and headless bridge behavior aligned.

4. **Display refresh**
   - Move card view creation and refresh routing out of `BattleScene`.
   - Keep recent portrait, draw reveal, stadium HUD, and detail popup fixes covered.

5. **Overlay/prize/handover/match-end**
   - Consolidate prize choice, double-prize edge cases, handover prompts, and match-end overlays.

6. **Layout**
   - Continue reducing scene-owned layout implementation.
   - Preserve mobile portrait and macOS large-window behavior.

7. **AI/advice/replay/recording**
   - Move remaining lifecycle and state glue after the interaction and prompt flows stabilize.

## Known Risks

- Moving prompt and interaction code can easily break setup, retreat, prize choice, Heavy Baton, Exp Share, and card-specific follow-up choices.
- UI and headless/AI execution can diverge if only one path is updated.
- Portrait layout regressions are likely unless tests stay focused on actual viewport constraints.
- `BattleScene` line-count gates can regress quickly if bug fixes are added directly to the scene.
- Some existing documentation appears to render with encoding issues in PowerShell output; new documentation should stay UTF-8 and prefer ASCII file names.

## Required Test Coverage For Future Phases

Every future migration phase should run at minimum:

- `test_script_load_regressions.gd`
- `test_battle_scene_architecture_audit.gd`
- `test_battle_portrait_layout.gd`
- `test_battle_ui_features.gd`

Domain-specific migrations should additionally run their focused suite, for example:

- Prompt/dialog: `test_battle_prompt_router.gd`, `test_battle_dialog_controller.gd`
- Interaction/effects: `test_battle_interaction_coordinator.gd`, `test_headless_match_bridge.gd`
- Display: `test_battle_display_coordinator.gd`, `test_battle_display_controller.gd`
- Overlay/prize: `test_battle_overlay_coordinator.gd`
- Recording/replay: `test_battle_recording_coordinator.gd`, replay-focused tests

## Decision

The refactor is **not complete**. Continue with a recovery-first plan:

1. Restore architecture gate.
2. Pick one high-coupling domain.
3. Move it to domain ownership with tests.
4. Reduce scene size and private reflection in measurable increments.
5. Repeat until final gate is realistic.
