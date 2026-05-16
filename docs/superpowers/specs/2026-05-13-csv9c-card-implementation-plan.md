# CSV9C Card Implementation Plan

Date: 2026-05-13

Scope:

- Implement and audit the 58 imported CSV9C key cards.
- Exclude CSV9C_207 Zero Area, because it needs the bench-limit and UI discard workflow redesign.
- Card JSON under `data/bundled_user/cards` is the source of truth.

Baseline From Card Audit:

- CSV9C imported cards: 59 JSON and 59 images.
- Excluded: CSV9C_207 Zero Area.
- Pure numeric cards already treated as implemented by the status layer: CSV9C_011, CSV9C_033, CSV9C_073.
- Remaining registry failures after excluding Zero Area: 55.
- Implementation strategy: prefer effect_id overrides for all CSV9C scripted Pokemon, because imported localized names may not be stable enough for dynamic name mapping.

Architecture Rules:

- EffectRegistry remains the single static registration point.
- Pokemon cards use effect_id overrides for CSV9C, with attack-index binding for multi-attack cards.
- Trainer, Tool, Stadium, and Special Energy cards use fixed effect_id registration in their existing category functions.
- Full own-deck searches must expose `visible_scope = BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK`, with all deck cards visible and only legal cards selectable.
- Top-N or opponent hidden deck effects must not expose the full deck.
- UI, AI, and Headless entries must all consume the same interaction steps and `can_execute` logic.
- Zero Area is intentionally not registered in this pass.

Implementation Batches:

Batch A, Pokemon simple and reusable attacks:

- CSV9C_001, 012, 021, 034, 038, 063, 071, 074, 096, 097, 098, 106, 112, 117, 118, 136, 148, 154.
- Focus: early evolution, prevention markers, damage by counters or energy, mill, heal, discard energy, coin damage, search to hand, search and attach.

Batch B, Pokemon advanced abilities and attacks:

- CSV9C_006, 013, 023, 039, 053, 054, 064, 072, 075, 078, 090, 099, 119, 127, 133, 138, 142, 144, 147, 153, 155, 161, 162, 175.
- Focus: on-bench and on-evolve triggers, damage prevention, prize modifiers, item lock, return-to-deck effects, active-only abilities, cost reduction, board-wide modifiers.

Batch C, Trainer, Tool, Stadium, and Special Energy:

- CSV9C_176, 178, 181, 183, 186, 190, 196, 198, 202, 204, 205, 206, 208.
- Focus: search and assignment UI, ACE SPEC effects, supporter gates, stadium action, HP modifier, energy attach trigger.

Shared Engine Risks:

- Special Energy attach effects must fire through `GameStateMachine.attach_energy`.
- Knockout bonus effects must only apply to attack-damage knockouts.
- Stadium per-turn actions must be exposed through existing stadium action flow.
- "Cannot play ACE SPEC" requires trainer playability checks to consult opponent field effects.
- "Cannot return opponent Pokemon/cards to hand" requires return-to-hand effects to consult prevention before moving cards.
- Evolution overrides for CSV9C_001 and CSV9C_153 must be checked against first-turn and just-played evolution rules.

Verification Plan:

- Add focused tests for CSV9C registration and CardImplementationStatus.
- Add behavior tests for each non-vanilla effect group.
- Run focused CSV9C tests after implementation.
- Run `scripts/run_card_audit.ps1` and confirm CSV9C_207 is the only expected CSV9C registry failure.
- Run broader functional tests if EffectRegistry, RuleValidator, GameStateMachine, EffectProcessor, or BattleScene behavior changes.

Definition Of Done:

- All 58 in-scope CSV9C cards either pass as vanilla or have registered, tested effects.
- CSV9C_207 remains documented as intentionally deferred.
- Card audit reports no CSV9C failures except CSV9C_207.
- Focused and relevant functional tests pass.
