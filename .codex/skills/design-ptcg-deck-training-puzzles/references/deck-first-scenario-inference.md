# Deck-First Scenario Inference

Use this method before authoring scenario JSON. The quality of the puzzle is
bounded by the quality of the deck model.

## 1. Read The Frozen Deck Card By Card

Confirm the exact 60-card list and production strategy. For every unique card,
record:

- normal role and matchup-specific role
- zone transitions it enables
- information revealed or hidden
- once-per-turn, Supporter, attachment, Bench-space, or attack quota consumed
- cards it searches, recovers, discards, moves, evolves, or protects
- exact damage, Energy, HP, prize, retreat, and timing implications
- attractive misuse that a real player might choose

Read card JSON, effect registration, implementation, interaction schema,
legality checks, and focused tests together. Fix runtime defects before using
the card as a lesson.

Do not begin scenario JSON while this pass is incomplete. Card familiarity is
not a substitute for reading the frozen list: the list determines which draw
lures, search bridges, tech counters, Energy routes, and finishers can legally
appear.

## 2. Build The Deck Model

Produce four compact artifacts:

1. **Resource graph:** draw/reveal -> search -> recovery -> attachment/discard ->
   attack -> prize.
2. **Turn skeletons:** normal setup, rebuild after a knockout, comeback turn,
   and low-resource/low-deck turn.
3. **Combo and tech inventory:** at least eight ordered combos plus every
   matchup-specific counter card and its exact target trait.
4. **Failure catalog:** locally attractive actions that lose a quota, hidden
   order, Bench slot, damage breakpoint, Energy budget, or second-turn resource.

Also produce a **solution-key census** from the proposed shortest witness.
Starting at the final attack and walking backwards, list every card the witness
must draw, reveal, search, recover, or take as a Prize. None may appear in the
opening hand. This reverse census defines `key_cards`; do not hand-pick only the
most interesting cards.

Do not continue until the model explains the deck's real Supporter bottleneck,
manual versus accelerated attachment ownership, gust routes, switching routes,
recovery loop, and prize plan.

For a ten-puzzle batch, create the lesson coverage matrix before selecting final
candidates. Require different deck claims, resource graphs, target patterns, and
winning action sequences; do not create ten variants of the same combo.

## 3. Infer Candidates Backwards

Start from an exciting exact payoff, not an opening hand:

```text
final prizes and target HP
<- required attack and damage modifiers
<- required gust, spread, movement, or weakness
<- required Energy and attacker state
<- required recovery/search cards
<- first hidden draw or reveal that unlocks the chain
```

For each candidate, write a reasoning row:

| Field | Required evidence |
| --- | --- |
| lesson | One deck-specific claim the player will learn |
| payoff | Exact damage, knockouts, prizes, and deadline |
| ordered combo | At least three consequential steps |
| hidden bridge | First key card revealed from hidden information |
| winning route | Why this draw source preserves the necessary quotas/order |
| winning draw trace | Actual cards/information revealed at every checkpoint |
| lure A | Legal line, exact cards seen, and one exact later deficit |
| lure B | Different legal line, exact cards seen, and a different exact deficit |
| late finisher | Hidden key card revealed after at least two earlier checkpoints |
| board history | Plausible origin of damage, Energy, prizes, and discard |
| shortcut attack | Simplest raw attack/draw line attempted and why it fails |

Reject duplicates by lesson, resource graph, target pattern, and winning action
sequence—not just by board fingerprint.

## 4. Author The Hand And Luck

Make the hand look shuffled:

- use at least five cards and three functional categories
- include awkward, redundant, and situational cards
- expose at least three plausible openings
- keep every shortest-line key card out of the opening hand

Root the solution in a hidden production reveal. A strong pattern is:

```text
draw ability reveals bridge Supporter
-> bridge searches recovery or setup piece
-> ordered filtering preserves the next checkpoint
-> final draw/reveal finds gust or finisher
```

Build a shared-state route lattice before authoring JSON:

| Route | Opening | Actual reveal trace | Information barrier | Exact failure/payoff |
| --- | --- | --- | --- | --- |
| correct | deck-owned draw engine | list every revealed card | preserved shuffle/Supporter window | exact lethal |
| lure A | large draw Supporter | list every card actually reached | consumed Supporter or crossed shuffle | exact deficit |
| lure B | early search/ability | list every card actually reached | destroyed top order or Bench space | different exact deficit |

All rows use the same opening hand, deck order, Prize layout, board, seed, and
AI policy. If a route cannot be replayed from that identical state, it is not a
valid comparison.

When the list permits, make Professor's Research, Iono, an early draw ability,
or a visible search a credible lure. A larger draw must be capable of losing
because it crosses the wrong information epoch, consumes the Supporter window,
discards protected costs, draws past a prepared top deck, or misses the
deadline. “Bad luck” is not a failure proof.

The emotional “luck” moment must be authored and deterministic. Positive and
negative routes start from the same hand, deck order, prizes, board, and AI
policy.

Never insert Professor's Research, Boss's Orders, or another familiar puzzle
device unless it belongs to the frozen list. When Research or an equivalent
draw-seven is present, make it a strong lure when possible: state exactly which
cards it draws, why the bridge remains inaccessible, and which later quota,
discard cost, shuffle boundary, damage number, or deadline fails.

## 5. Construct The Board From The Math

Fill both Benches whenever legal. Give each slot a role: attacker, engine,
pivot, protected resource, gust liability, damage-clock participant, matchup
counter, or lure.

Calculate lethal before entering state data:

```text
effective HP - existing damage - moved/spread counters = remaining HP
attack damage after modifiers = knockout payment
starting Energy + acquired - spent/discarded = remaining Energy
starting prizes - earned prizes = deadline state
```

Use plausible prior-game history for attached Energy and damage. Prefer exact
or near-exact lines. Large avoidable overkill, unused engines, free Bench slots,
or an attack that wins without filtering are rejection signals.

Write a compact board-history ledger before implementation:

- elapsed turns and legal attachment opportunities
- source of every accelerated or moved Energy
- source of every existing damage counter
- Prize sequence that created the current comeback window
- discard contents required by recovery or damage math

Reject a board whose numbers work only as JSON but could not plausibly have
occurred in a real game.

## 6. Attack The Candidate

Before implementation, try to break the puzzle:

- raw attack immediately
- draw the most cards first
- use visible search before hidden reveal
- shuffle before a prepared top deck
- spend Boss instead of Counter Catcher, or vice versa
- overpay the first knockout
- ignore the intended ability, recovery, or tech card
- finish in one turn
- finish with fewer than five meaningful actions

Remove each intended action once. If the same payoff remains reachable, the
action was decoration. Only implement candidates that survive this adversarial
pass, then prove the positive witness and at least two negative lure probes
through production rules.
