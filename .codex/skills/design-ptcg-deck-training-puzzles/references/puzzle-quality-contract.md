# Puzzle Quality Contract

## Hard Admission Gates

Reject before implementation unless the candidate has:

- an exact frozen 60-card player deck and production rules strategy
- one deck-specific learning axis
- a two-turn dependency, except an approved one-turn mating pattern
- at least 5 meaningful player actions on the shortest winning line
- at least 3 irreversible decisions
- at least 2 legal, attractive lure lines
- an exact goal tracked by prize count or opening Pokémon instance
- a deterministic positive route through production rules
- no one-turn or lower-action shortcut

Count an action only when it changes information, state, resource ownership, targeting, or timing. Do not inflate counts with confirmations, prize clicks, or animations. Count a decision as irreversible only when the alternative changes later legality or payoff.

## Deck Comprehension And Scenario-Inference Gate

Reject before scenario authoring unless the deck theory:

- classifies every unique card in the frozen 60-card list
- maps draw, search, shuffle, recovery, attachment, gust, and attack dependencies
- identifies the Supporter, attachment, Bench-space, and attack bottlenecks
- includes every low-count tech card and the exact opponent trait it counters
- contains at least eight ordered deck-specific combos
- compares one winning draw route with at least two legal lure routes
- explains the exact payoff first and derives the opening state backwards

For a batch of ten, require distinct lesson/resource/target/action-sequence
fingerprints. Cosmetic board changes do not create a new puzzle.

## Hand And Key-Card Rules

The initial hand must:

- contain at least 5 cards
- contain at least 3 functional categories among Pokémon, Supporter, Item, Tool, Stadium, Energy
- contain at least 2 legal/plausible cards outside the winning suffix
- present at least 3 legal opening actions when possible
- resemble a shuffled midgame hand, not a curated combo display
- respect frozen-list copy counts for every card
- declare a `random_hand_profile` containing at least 3 plausible openings and
  at least one awkward card and one redundant card that create the
  shuffled-hand appearance

Every `design_contract.key_cards` entry must:

- belong to the frozen deck
- be absent from the initial hand
- be acquired through a declared draw/search/recovery/prize checkpoint
- have a stated reason it cannot be replaced by a visible card

The acquisition graph must be draw-rooted. `winning_draw_route.hidden_reveal`
must name at least one key card that is absent from the initial hand and appears
in a declared checkpoint. That checkpoint must reveal previously hidden
information through an ability draw, natural draw, prize pickup, or equivalent
production effect. A later search or recovery is valid only when this hidden
reveal supplies the Supporter, Item, timing fact, discard resource, or other
bridge that makes it possible. Reject a route where a visible opening-hand
search card can obtain every required component before the hidden reveal.

The correct opening must not be “use the action with the largest draw count.”
When Professor's Research or an equivalent draw-seven belongs to the frozen
list, normally include it as one lure. Prove the exact later quota, discard,
deck-order, damage, Energy, or deadline failure. If the comparison is
inapplicable, document the deck- or scene-specific reason.

Cards in play may be engine prerequisites, but do not call them hidden key cards.
Treat every bridge, search target, gust effect, recovery piece, and final damage
enabler on the shortest witness as a key card. Omitting a required card from
`key_cards` to bypass this rule is a contract violation.

Require `solution_key_inventory_complete: true` and a `key_card_roles` entry for
every key card. For the positive witness, trace every referenced card that was
not initially visible to exactly one `draw_checkpoints` acquisition. Review the
trace manually after the static audit; the assertion does not replace the
production replay.

## Ordered Draw And Lure Routes

Require one explicit `winning_draw_route`, at least one draw-order constraint,
and two lure routes. All three routes must start from the same frozen hand, deck,
prizes, board, and AI policy. Good constraints include:

- ability reveals the Supporter that unlocks a search
- search/shuffle must precede top-deck placement
- placement must precede an Active draw-two ability
- prize pickup must precede the second search
- a second-turn natural draw must remain, so another ability must not be used

Each lure must name its opening action, attraction, gained information, consumed quota/resource, exact later failed equation, and negative-probe ID. Lure
openings, failure equations, and probe IDs must be distinct. If the frozen list
contains Professor's Research or an equivalent draw-seven Supporter, normally
include the tempting "draw seven first" branch and prove the exact Supporter,
discard, deck-order, damage, or Energy deficit it creates.

Require `winning_draw_route.draw_trace` and `bait_lines[].draw_trace`. These
arrays record the actual card UIDs or public information reached at each
checkpoint. A route description without a trace is inadmissible, because it
cannot prove that the larger draw or early search truly misses the later key.

The lure description is not proof. Replay it from the same authored hidden state
and record the actual cards or information reached before the exact failure.
Never add a lure card that is absent from the frozen list.

Deck order is valid evidence only until the next production shuffle. Audit the
route as a sequence of information epochs:

- cards drawn before a shuffle may be relied on
- cards left in the deck lose authored top-deck guarantees when the shuffle resolves
- a later deterministic draw requires a new placement, search, prize, recovery,
  or explicitly seeded production contract
- positive and negative routes must cross the same shuffle boundaries

Reject a route that silently carries a second or third authored top card across
an Energy Search PRO, Ball search, recovery shuffle, Iono, Research, or similar
effect.

Common lure families:

- Research first consumes Supporter quota or discards protected recovery costs
- ability too early draws past an unprepared top deck
- shuffle after placement destroys deterministic order
- excessive filtering causes deck-out
- premature search spends the only discard fodder
- overpaying the first knockout leaves insufficient Energy for turn two

“Might not draw it” is insufficient. Freeze the order or seed and demonstrate failure.

The winning route must include at least three consequential steps and at least
one hidden reveal. Record what becomes known at each checkpoint and why the next
action is now correct. At least one pair of adjacent major steps must be
order-sensitive.

## Board Credibility

Default targets:

- player Bench: all currently legal slots occupied
- opponent Bench: all currently legal slots occupied
- at least 2 meaningful abilities/attack threats visible
- at least 1 gust liability or switching decision
- attached Energy consistent with elapsed turns
- damage consistent with attacks, abilities, or stated history

Declare `board_capacity.player_bench` and `board_capacity.opponent_bench`.
Normally each is 5; use the actual expanded capacity when a Stadium/rule changes
it. Allow fewer occupied slots only when Bench space is scarce or an ability
needs an empty slot. Record the exemption and the exact reason.

For every Pokémon:

- stack and attached cards must be legal and deck-owned
- damage must be below effective maximum HP
- Energy count must be plausible
- role must be attacker, engine, pivot, target, liability, bait, or future lane

Declare a non-empty `board_roles` entry for both Active slots and every occupied
Bench slot. A decorative role such as “filler” is not acceptable.

Declare `board_history` with:

- `elapsed_turns`
- `energy_origins`
- `damage_origins`
- `prize_history`

Each field must explain a plausible production-game origin rather than repeat a
number. Include discard origins in the prose whenever recovery or discard-count
math matters.

For every knockout, calculate Tool, Stadium, weakness, resistance, moved counters, modifiers, and overkill.

Declare `overkill` as `final_damage - remaining_hp`. Large overkill is allowed
only when the deck's fixed damage increments or matchup math makes it
unavoidable; otherwise revise the target or route.

Also record Energy arithmetic: Energy already attached, acquired from each
source, discarded/moved/attached as costs, required attack payment, and
remaining Energy after the first knockout. Reject unexplained Energy or damage.

## Combo And Excitement Tests

Require:

- **Identity:** another deck cannot teach the same route by renaming cards.
- **Order:** swapping a major adjacent action makes the route fail.
- **Discovery:** the opening hand does not expose the full answer.
- **Temptation:** two inferior routes look locally strong.
- **Recovery:** the line converts new information or a prior loss into a resource.
- **Precision:** the last knockout needs exact Energy, damage, prize, or deck-count math.
- **Emotion:** the route visibly reverses apparent failure into exact lethal.

Prefer combos joining three systems:

```text
draw sequencing + Supporter quota + Energy recovery
damage movement + gust + exact discard count
intentional prize loss + comeback ability + Counter Catcher
low deck + recovery shuffle + refusal to draw
```

Require a `climax_contract`:

- `apparent_dead_end`: why the initial public state looks losing
- `comeback_chain`: at least three information/resource conversions
- `finisher`: the final hidden gust, recovery, attacker, or damage enabler
- `finisher_card`: the frozen-list card UID, included in `key_cards`
- `finisher_checkpoint_order`: the draw checkpoint that first reveals it
- `filtering_checkpoints_before_finisher`: at least 2
- `finisher_was_hidden`: `true`; it may not begin in hand
- `exact_payoff`: exact prizes/knockouts/damage achieved

Boss's Orders is a strong climax when it belongs to the list, but do not force
it into every puzzle. Use the deck's real equivalent and preserve deck identity.
The finisher must remain hidden through at least two earlier filtering or
information checkpoints so the payoff feels discovered rather than dealt.

The desired emotional curve is:

```text
apparently dead position
-> small hidden reveal
-> repeated filtering/recovery in the only viable order
-> apparently lucky but authored final gust/finisher
-> exact lethal and prize payoff
```

The “luck” must be deterministic and shared by positive and lure routes. The
player should feel they found an out, while the proof system must know precisely
why that out existed.

## Proof And Shortcut Gates

Positive witness:

- replay actions through production legality/effects
- cross every AI turn
- resolve choices explicitly
- reach the exact deadline goal
- record shortest meaningful actions

Negative probes should cover Research first, obvious ability first, overpayment, wrong gust, premature shuffle/recovery, and one-turn attack-only shortcuts.
Only require a named lure family when the frozen list and opening state make it
legal; replace unavailable generic lures with the deck's real competing route.

Statuses:

- `rejected_authoring`: design gates missing
- `rejected_state`: frozen-deck state fails
- `rejected_playability`: no legal opening
- `playable`: production state and manual witness work
- `proven`: positive proof certificate valid
- `release_ready`: proven plus clean shortcut probes

Never claim unique/proven/release-ready from intuition.
