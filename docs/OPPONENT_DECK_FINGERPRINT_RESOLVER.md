# Opponent deck fingerprint resolver

`OpponentDeckFingerprintResolver` identifies an opponent among the exact 24
built-in V18 decks using the smallest public card witness available in the
current game state.

It reads only public zones:

- Active and Bench Pokemon, including evolution stacks
- attached Energy and Tools
- discard pile and Lost Zone
- the opponent-owned Stadium

It never reads the opponent's hand, deck, or Prize cards. Card identity uses
`effect_id` first, so cosmetic reprints of the same effect do not create a
fragile false fingerprint.

Every `DeckStrategyBase` strategy can call:

```gdscript
var opponent := resolve_opponent_deck(game_state, player_index)
if opponent.get("status", "") == "unique":
	match str(opponent.get("strategy_id", "")):
		"v18_800017097_no_balloon_gardevoir":
			# Apply the matchup-specific route.
			pass
```

For a concise exact predicate:

```gdscript
if opponent_is_deck(game_state, player_index, 800017097):
	# Exact built-in deck variant.
	pass

if opponent_uses_strategy(game_state, player_index, "v18_18000230_dragapult_charizard"):
	# Strategy-family matchup route.
	pass
```

The result status is one of `unique`, `ambiguous`, `unknown`, `no_match`, or
`catalog_error`. A unique result includes the exact `deck_id`, `deck_name`,
`strategy_id`, `archetype`, all remaining candidates, and the minimal evidence
that made the result unique.

This resolver must not be used to choose the local player's own production
strategy. Own-deck strategy wiring continues to resolve the exact deck ID
through `DeckStrategyRegistry`.
