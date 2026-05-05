# Special Status Rules Fix

Date: 2026-05-05

## Scope

This change aligns the battle engine with official Pokemon TCG special-condition timing for:

- Confused
- Paralyzed
- Asleep
- Burned
- Poisoned

The immediate fixes are engine-level rule correctness, not UI restyling.

## Current Gaps

1. `Paralyzed` is cleared during every Pokemon Check.
   - This is wrong when an opponent's attack applies Paralysis. The defender should remain Paralyzed through their next turn and recover only during their own end-of-turn Pokemon Check.

2. Tool-granted attacks do not consistently use the same status gate as native attacks.
   - Native attacks are blocked by `Asleep` and `Paralyzed`.
   - Granted attacks are checked by duplicated UI, AI, MCTS, and execution helpers that only inspect phase, active slot, tool, and Energy.

3. Tool-granted attacks handle `Confused` after executing the granted effect.
   - Official flow is: choose attack, flip for Confusion, and on tails the attack fails before damage or effects.

4. Pokemon Check currently iterates every Pokemon in play.
   - Special conditions should only affect Active Pokemon. Bench slots should normally have no special conditions, but the processor should still avoid applying status damage/recovery to bench states restored from tests or replays.

## Target Semantics

### Confused

- Does not block retreat.
- Does not block declaring an attack.
- After attack declaration, flip a coin.
- Heads: attack proceeds normally.
- Tails: attack fails and the attacker receives 30 damage.
- This applies to native attacks and tool-granted attacks.

### Paralyzed

- Blocks attack and retreat while present.
- Clears only during the Paralyzed Pokemon owner's own end-of-turn Pokemon Check.
- Does not clear during the opponent's Pokemon Check immediately after the attack that applied Paralysis.
- Mutually exclusive with `Asleep` and `Confused`.

### Asleep

- Blocks attack and retreat while present.
- During each Pokemon Check for the Asleep Pokemon while Active, flip a coin.
- Heads: recover.
- Tails: remains Asleep.
- Mutually exclusive with `Paralyzed` and `Confused`.

### Burned

- Does not block attack or retreat.
- During each Pokemon Check for the Burned Pokemon while Active, place 20 damage, then flip.
- Heads: recover.
- Tails: remains Burned.

### Poisoned

- Does not block attack or retreat.
- During each Pokemon Check for the Poisoned Pokemon while Active, place 10 damage.
- Can stack with all other special conditions.

## Design

### Centralize granted-attack legality

Add a `RuleValidator.get_granted_attack_unusable_reason(...)` helper and route all granted-attack checks through it:

- `GameStateMachine.use_granted_attack`
- `BattleScene._can_use_granted_attack`
- `BattleScene._get_granted_attack_unusable_reason`
- `AILegalActionBuilder._build_granted_attack_actions`
- `MCTSPlanner._can_use_granted_attack`

This prevents drift between player UI, AI enumeration, simulations, and execution.

### Move Confusion before granted effects

In `GameStateMachine.use_granted_attack`, run the same Confusion flip logic before `effect_processor.execute_granted_attack(...)`.

On tails:

- apply 30 damage to attacker
- log coin flip and self-damage
- enter normal after-attack Pokemon Check
- do not execute granted attack effects

### Correct Pokemon Check target set

Change `EffectProcessor.process_pokemon_check(state)` to process only each player's Active Pokemon.

For `Paralyzed`, clear only if the slot belongs to `state.current_player_index`, because Pokemon Check is performed before the active player is advanced to the next turn.

### Keep existing status clearing rules

No change to:

- status clearing on leaving Active
- status clearing on evolution
- status mutual exclusion in `PokemonSlot.set_status`

## Test Plan

Add a focused status-rule suite covering:

1. Paralysis applied before opponent Pokemon Check is not cleared immediately.
2. Paralysis clears during its owner's own end-of-turn Pokemon Check.
3. Bench Poison/Burn/Asleep/Paralyzed are ignored by Pokemon Check.
4. Granted attacks are blocked by `Asleep`.
5. Granted attacks are blocked by `Paralyzed`.
6. Granted attacks under `Confused` tails do not execute the granted effect and only deal 30 self-damage.
7. Granted attacks under `Confused` heads execute normally.

Run at minimum:

- `tests/test_special_status_rules.gd`
- `tests/test_rule_validator.gd`
- `tests/test_effect_interaction_flow.gd`
- `tests/test_headless_match_bridge.gd`
- `tests/test_mcts_action_resolution.gd`
