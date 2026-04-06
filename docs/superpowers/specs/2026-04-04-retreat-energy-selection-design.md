# Retreat Energy Selection Design

**Goal:** Make retreat require explicit energy selection when the retreat cost is lower than the number of attached Energy cards, while preserving the existing retreat flow for zero-cost and forced-cost cases.

**Current Problem**

- `BattleScene._show_retreat_dialog()` computes a default discard list by taking the first attached Energy cards until the retreat cost is paid.
- That skips player choice whenever the Active Pokemon has more attached Energy than required.
- Engine-side validation already supports explicit discard selections through `GameStateMachine.retreat(player_index, energy_to_discard, bench_slot)`.

**Approved Interaction**

- Retreat flow becomes two-step when choice is needed:
  1. choose attached Energy to discard
  2. choose the Benched Pokemon to switch into
- If retreat cost is `0`, skip energy selection and go directly to bench selection.
- If the retreat cost exactly consumes all attached Energy, auto-select those cards and go directly to bench selection.
- If attached Energy count is greater than what must be discarded, prompt the player to choose the discard set first.

**Architecture**

- Keep retreat as a BattleScene-owned interaction rather than moving it into the effect-interaction system.
- Reuse the existing card-selection dialog for attached Energy selection, then transition into the existing field-slot selection for bench choice.
- Keep `GameStateMachine` and `RuleValidator` as the final authority for legal discard payment.

**Testing**

- Add a UI regression that proves retreat first opens an Energy selection step when extra attached Energy exists.
- Keep the existing zero-cost retreat regression green.
- Add a follow-up UI regression that confirms the chosen Energy cards are the ones passed into retreat resolution.
