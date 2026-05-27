# Battle Invalid Action HUD Design

## Background

New players often do not understand why a card or action cannot be used. Typical cases:

- A Supporter card cannot be played because one Supporter has already been used this turn.
- An Energy card cannot be manually attached because one Energy has already been attached this turn.
- Nest Ball or Buddy-Buddy Poffin cannot be used because the Bench is full.
- A Basic Pokemon cannot be put onto the Bench because there is no Bench space.
- A Pokemon cannot evolve because it was just played, it is the player's first turn, or the target does not match.
- A Pokemon Tool cannot be attached because the target already has a Tool.
- A Stadium cannot be played because the same Stadium is already in play.

The current battle UI mostly records these failures as a short log line in the right-side operation log, such as "cannot use this card". This is technically correct but weak as player feedback, especially on mobile where the log is less visible.

## Goals

- Show a clear HUD popup when a player attempts an invalid card or action.
- Explain the primary reason in plain Chinese.
- Keep the right-side log as a secondary record.
- Reuse the same reason model across hand cards, target selection, Pokemon action dialogs, and Stadium actions.
- Preserve all existing rule behavior. The feature only explains why an action is invalid.
- Keep AI behavior unchanged unless an AI-driven invalid action already routes through the same UI path.

## Non-Goals

- Do not redesign the entire battle dialog system.
- Do not change card effect execution semantics.
- Do not make every card script perfectly explanatory in the first pass.
- Do not replace the battle log.
- Do not add LLM explanations for invalid actions.

## Current Architecture

### Rule Layer

`scripts/engine/RuleValidator.gd` contains general rule gates:

- `can_attach_energy`
- `can_play_supporter`
- `can_play_item`
- `can_play_stadium`
- `can_play_basic_to_bench`
- `can_evolve`
- `can_attach_tool`
- `can_retreat`
- `get_attack_unusable_reason`
- `get_granted_attack_unusable_reason`

Most gates return only `bool`. Attack already has the desired shape: `get_attack_unusable_reason()` returns a readable reason and `can_use_attack()` delegates to that reason being empty.

### Effect Layer

`scripts/effects/BaseEffect.gd` defines:

- `can_execute(card, state)`
- `get_interaction_steps(card, state)`
- `can_use_as_stadium_action(card, state)`
- `can_use_ability(pokemon, state)` in many concrete effect scripts

These are also mostly boolean. Card-specific failures such as "Bench is full" for Nest Ball are currently hidden inside `can_execute()`.

### UI Layer

Hand-card click flow:

- `scripts/ui/battle/BattleActionController.gd`
- `scenes/battle/runtime/BattleSceneDialogInteractionReviewRuntime.gd`
- `scenes/battle/runtime/BattleSceneBoardActionRuntime.gd`

Dialog flow:

- `scripts/ui/battle/BattleDialogController.gd`

The Pokemon action dialog already carries an `enabled` and `reason` field per action item, but many reasons are generic.

## Proposed Model

Introduce a shared invalid-action reason payload:

```gdscript
{
  "usable": false,
  "title": "巢穴球现在不能使用",
  "reason": "你的备战区已经满了。",
  "detail": "巢穴球需要从牌库选择 1 只基础宝可梦放到备战区。",
  "hint": "先让备战区空出位置，或改用其他操作。",
  "kind": "trainer",
  "severity": "blocked"
}
```

The payload is intentionally small and deterministic. The first release should not depend on network or LLM services.

## Rule Reason APIs

Add reason-returning methods and make existing `can_*` methods delegate to them where practical:

- `get_attach_energy_unusable_reason(state, player_index, card, effect_processor)`
- `get_play_supporter_unusable_reason(state, player_index, card, effect_processor)`
- `get_play_item_unusable_reason(state, player_index, card, effect_processor)`
- `get_play_stadium_unusable_reason(state, player_index, card, effect_processor)`
- `get_play_basic_to_bench_unusable_reason(state, player_index, card)`
- `get_evolve_unusable_reason(state, player_index, slot, evolution, effect_processor)`
- `get_attach_tool_unusable_reason(state, player_index, slot, effect_processor, tool_card)`
- `get_retreat_unusable_reason(state, player_index, effect_processor)`

The methods should return `""` when the action is legal.

Reason priority matters. The most useful reason should be returned first:

1. Wrong player or wrong phase.
2. Global once-per-turn or first-turn rule.
3. Effects that prevent playing from hand.
4. Target invalidity.
5. Card-specific target/resource shortages.

## Effect Reason APIs

Add optional methods to `BaseEffect`:

- `get_unusable_reason(card, state) -> String`
- `get_ability_unusable_reason(pokemon, state) -> String`
- `get_stadium_action_unusable_reason(card, state) -> String`

Default implementations return `""`, preserving existing scripts.

Concrete high-frequency cards should override `get_unusable_reason()` in the first pass:

- Nest Ball: Bench full.
- Buddy-Buddy Poffin: Bench full.
- Ultra Ball: not enough other hand cards to discard, or deck empty.
- Rare Candy: first turn, no matching Stage 2 plus Basic target.

Future cards can add more precise reasons incrementally without changing the UI layer.

## EffectProcessor Reason APIs

Add bridge methods:

- `get_card_from_hand_block_reason(player_index, card, state)`
- `get_effect_unusable_reason(card, state)`
- `get_ability_unusable_reason(pokemon, state, ability_index)`

These centralize suppression reasons from opponent abilities, Tools, and Stadiums. The initial implementation can return a generic but clear reason for complex locks, then become more specific over time.

## UI Design

Create a lightweight HUD popup controller, separate from the effect/card-selection dialog state machine.

Why not reuse `_show_dialog()`:

- `_show_dialog()` mutates `_pending_choice`, `_dialog_data`, selection arrays, and card gallery state.
- Invalid-action feedback should not start a choice flow.
- The popup may appear while a hand card is selected or after an invalid target click. It must not disturb the selected hand card unless the existing action flow already does.

Suggested file:

- `scripts/ui/battle/BattleInvalidActionHintController.gd`

Suggested scene-owned nodes can be created dynamically:

- `InvalidActionOverlay`
- `InvalidActionCenter`
- `InvalidActionBox`
- `InvalidActionTitle`
- `InvalidActionReason`
- `InvalidActionDetail`
- `InvalidActionHint`
- `InvalidActionCloseButton`

HUD style:

- Dark translucent battlefield overlay.
- Cyan frame for normal blocked feedback.
- Warm amber highlight for the primary reason.
- One large touch-friendly close button.
- Portrait layout uses near-full screen width and larger text.
- Landscape layout uses compact centered popup.

## UI Integration Points

### Hand Cards

`BattleActionController.on_hand_card_clicked()` should ask for a reason before logging generic failure:

- Supporter blocked -> show HUD.
- Item blocked -> show HUD.
- Stadium blocked -> show HUD.
- Effect `can_execute()` false -> show card-specific HUD.

### Hand Detail Use Button

`BattleCardDetailCoordinator.on_detail_use_pressed()` currently hides detail and calls `_on_hand_card_clicked()`. If the card becomes unusable while detail is open, the action path should show the same invalid HUD.

### Field Target Clicks

`BattleSceneBoardActionRuntime._on_slot_clicked()` should show reason HUD when a selected hand card fails:

- Evolution target invalid.
- Energy target invalid or already attached this turn.
- Tool target invalid or already has a Tool.
- Basic Pokemon selected but no Bench space.

### Pokemon Action Dialog

When a disabled action is selected:

- Keep the action dialog visible.
- Do not show the full-screen invalid HUD for Pokemon action rows.
- Keep the stored `reason` inline on the disabled action row.
- Continue writing the short reason to the log only if a defensive fallback path is reached.

Rationale:

The Pokemon action HUD is already the card/action detail surface. It shows the card preview, full ability or attack text, Energy cost icons, and an inline `不可用：...` reason for disabled rows. Opening `InvalidActionOverlay` from this surface creates a second modal above the original detail surface and hides the information the player was trying to inspect. This differs from hand-card invalid attempts, where no equivalent action detail surface is already open.

Implementation contract:

- `BattleDialogController` must not confirm disabled `action_hud` rows.
- `BattleSceneDialogInteractionReviewRuntime` must treat disabled `pokemon_action` choices as non-modal fallbacks, not as invalid HUD requests.
- Disabled rows remain visible and readable for battle Active and Bench Pokemon.
- Enabled rows keep the existing confirmation and execution flow.

### Stadium Action Dialog

Stadium action dialogs also use the action HUD surface. Disabled Stadium action rows should follow the same inline rule as Pokemon action rows: show the reason in the row and do not open `InvalidActionOverlay`. Hand cards remain the only source that opens the invalid HUD in this refinement.

## Logging

The popup is the primary user feedback. The battle log remains secondary:

- Log the short reason text.
- Do not log multi-line detail/hint text unless a later replay UX needs it.

## Testing Strategy

Use TDD in three layers:

### Unit: RuleValidator Reasons

Add tests for:

- Supporter already used this turn.
- First player's first turn Supporter restriction.
- Energy already attached this turn.
- Bench full blocks Basic Pokemon from hand.
- Same Stadium already in play.
- Tool target already has a Tool.

### Unit: Effect-Specific Reasons

Add tests for:

- Nest Ball Bench full reason.
- Buddy-Buddy Poffin Bench full reason.
- Ultra Ball insufficient discard cost reason.
- Rare Candy first-turn/no-target reason.

### UI Controller Tests

Add tests that instantiate the invalid hint controller with a lightweight host:

- It creates overlay nodes.
- It writes title/reason/detail/hint.
- It can hide without touching dialog state.
- It uses portrait sizing when the scene reports portrait layout.

### Integration Tests

Extend battle action controller tests:

- Clicking blocked Supporter calls `_show_invalid_action_hint`.
- Clicking blocked Item calls `_show_invalid_action_hint`.
- Clicking blocked Stadium calls `_show_invalid_action_hint`.
- Clicking disabled Pokemon action uses the action reason instead of only logging.

## Rollout

Phase 1:

- Add reason APIs.
- Add invalid HUD controller.
- Wire high-frequency hand-card and target failures.
- Add focused tests.

Phase 2:

- Expand card-specific `get_unusable_reason()` implementations for more Trainer cards.
- Improve ability lock wording.
- Add visual polish if needed after mobile testing.

## Risks

- Some existing source files contain historical mojibake strings. New user-facing strings should be written in valid UTF-8 Chinese and tested on Android.
- The popup must not mutate `_pending_choice`, or it can break card-selection flows.
- Disabled action selection inside existing dialogs must not consume the parent dialog selection accidentally.
- Effects with complex `can_execute()` conditions may initially still show generic card-specific text until their scripts implement `get_unusable_reason()`.
