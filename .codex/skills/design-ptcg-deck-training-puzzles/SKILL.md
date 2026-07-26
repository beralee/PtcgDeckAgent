---
name: design-ptcg-deck-training-puzzles
description: Deep-read a fixed PTCG deck and design, implement, or review challenging deck-training endgame puzzles in this Godot repository. Use when creating or replacing 卡组训练/残局题, mining deck-specific combos and tech-card applications, authoring deterministic draw-order traps and comeback lines, constructing complex two-turn boards, validating exact HP/Energy/prize math, or promoting puzzle candidates through the production rules engine and proof pipeline.
---

# Design PTCG Deck Training Puzzles

Build puzzles that teach the deck's real decisions. Do not start from a generic board and swap card names.

Before acting, read:

- [references/deck-first-scenario-inference.md](references/deck-first-scenario-inference.md) for the mandatory card-by-card deck reading and scenario-derivation method.
- [references/puzzle-quality-contract.md](references/puzzle-quality-contract.md) for mandatory difficulty, hand, draw-order, board, combo, and proof gates.
- [references/repository-workflow.md](references/repository-workflow.md) for project files, authoring schema, runtime limits, and validation commands.

## Non-Negotiable Outcome

Require a deck-owned combo whose order matters. Target this player experience:

```text
apparent dead end -> read the whole board -> identify the correct draw engine
-> reject at least two tempting draw lines -> reveal the bridge card
-> assemble a deck-specific combo in exact order -> find the gust/finisher
-> exact knockout and prize swing
```

Treat authored luck as hidden but deterministic information. Never make acceptance depend on an uncontrolled coin flip, shuffle, or AI whim. Require the player to manufacture that luck by preserving the right information epochs: repeated filtering should finally expose the one gust, recovery card, attacker, or damage enabler that changes the game.

Use three strict phases:

```text
deck comprehension -> scenario inference -> production proof
```

Do not author board JSON during deck comprehension. Do not promote a candidate
from scenario inference until its payoff, hidden route, lure routes, and
shortcut attacks are written down. Do not call a puzzle solved until the
production engine replays the positive route and rejects the lures.

Do not infer puzzles directly from card names. First build a deck model that
explains how the frozen 60 cards turn hidden information into setup, damage,
target access, and prizes. Then derive scenes backwards from deck-owned payoffs.
For every candidate, preserve a short reasoning record:

```text
deck lesson -> exact payoff -> reverse resource graph -> hidden draw checkpoints
-> two tempting losing routes -> credible full board -> shortest witness
-> action-deletion and shortcut attacks
```

Reject a candidate when the lesson was invented before the deck model, when the
same lesson survives card-name substitution, or when removing an intended combo
step does not change the result.

The initial hand must look random without being random: mix at least three card
categories, useful-looking redundancy, awkward resources, and at least two
decoys. Every hand card and multiplicity must be legal in the frozen list. Put
every card required by the shortest winning line outside the initial hand. Root
the solution in a hidden draw or reveal: the first bridge card must come from an
ability draw, natural draw, prize pickup, or another production effect that
reveals previously hidden information. Downstream key cards may then be searched
or recovered only because that reveal unlocked them. A visible search card that
can fetch the whole combo before any hidden reveal is a failed puzzle, as is a
hand that already contains the combo.

Treat `key_cards` as a complete manifest, not a curated highlight list. Include
every card absent from the opening hand that the shortest witness must draw,
search, recover, take as a Prize, or otherwise reveal: bridge Supporters, search
Items, recovery pieces, gust effects, Energy, attackers, and damage enablers.
Reject a candidate if the author can make it pass merely by omitting a required
card from this manifest.

Record the actual result of every draw/reveal route. The winning route and both
lures must start from one shared hand, deck order, Prize layout, board, and AI
policy. Do not write only “Research misses”; list what Research actually reaches,
which bridge it passes or destroys, and the exact later deficit.

## Workflow

### 1. Establish Card And Runtime Truth

1. Inspect `git status`; preserve unrelated changes.
2. Resolve the exact frozen deck ID and require 60 cards.
3. Read the complete deck JSON.
4. Read every card used by a proposed route or lure: card JSON, effect registration, effect script, interaction steps, legality checks, and relevant tests.
5. Read the production rules strategy/profile to understand intended sequencing.
6. Read the training catalog, state factory, goal evaluator, session, admission verifier, proof adapter, and pipeline before changing scenario data.
7. Fix a card/runtime defect before designing around it. Never encode a workaround as puzzle difficulty.
8. Play the deck's resource graph on paper before authoring: identify what each
   draw engine can reveal, which searches shuffle, which Supporter window is
   scarce, and which cards must remain hidden until the climax.
9. Classify every card in the frozen list as engine, bridge, payoff, recovery,
   pivot, gust, tech, cost, or lure. Do not ignore low-count tech cards; their
   matchup-specific use is a first-class source of puzzle lessons.
10. Do not add a familiar lure such as Professor's Research unless that exact
    card is in the frozen list. Use the deck's real competing draw route instead.

### 2. Produce A Deck Theory Sheet

Do not author scenarios until the sheet covers:

- primary/secondary attackers, damage equations, and prize plans
- setup engine, draw engine, search graph, recovery loop, and Supporter bottleneck
- manual/accelerated Energy routes and discard ownership
- switch, gust, pivot, Bench-space, and retreat routes
- comeback windows, low-deck plan, and rebuild after a knockout
- tech cards and the exact opponent traits they counter
- at least eight deck-specific combos or sequencing lessons
- common attractive mistakes and why they fail
- a draw-route matrix comparing the correct route with at least two tempting
  legal routes from the identical hidden state
- a coverage matrix showing that the ten proposed scenes teach distinct
  resource, sequencing, matchup, or comeback claims

A combo must have prerequisites, an order constraint, a measurable payoff, and a failure consequence.
Do not proceed until the theory sheet explains why this deck, specifically, can
produce the intended puzzle. Card-name substitution must not preserve the lesson.

### 3. Design Backwards From The Payoff

1. Choose one learning axis and one exact final payoff.
2. Write the final damage/prize equation first.
3. Reverse the route to identify every required resource and timing window.
4. Enumerate every solution key card, including bridge cards, search targets, gust cards, recovery pieces, and the final damage enabler. Move all of them out of the initial hand.
5. Place key cards behind abilities, top-deck sequencing, searches, recovery, prize pickup, or a controlled shuffle. Require at least one hidden key-card reveal before any visible search line can assemble the combo.
6. Create at least three plausible draw routes: one winning route and at least two legal, attractive lure routes. Each lure must fail for a different exact mathematical or quota reason.
7. Fill both Benches to their current legal capacity wherever the frozen lists
   permit. Give every slot a tactical role; if a slot must remain empty, record
   the exact Bench-space rule or combo that requires it.
8. Add plausible attached Energy, damage, prize counts, used quotas, and prior-turn facts.
9. Require two player turns unless a one-turn mating pattern is itself the lesson.
10. Require at least five meaningful player actions and three irreversible decisions.
11. Put the final finisher outside the opening hand and reveal it only after at
    least two earlier information/filtering checkpoints. Use Boss's Orders when
    it belongs to the frozen list and the matchup calls for it; otherwise use
    the deck's own gust, recovery, attacker, or exact damage enabler.

The initial hand must look like a real shuffled midgame hand: at least five
cards, at least three functional categories, redundant or awkward cards, and at
least three plausible opening actions. Do not place a clean bundle of solution
components in hand.

The correct route must not be identifiable merely by choosing the action that
draws the most cards. When Professor's Research or an equivalent draw-seven is
available, normally make it a serious lure and prove why it misses the later
bridge, destroys protected discard fodder, consumes the Supporter window, or
crosses the wrong shuffle boundary. If it is not a lure, record why the frozen
deck or scene makes that comparison inapplicable.

Freeze the exact result of every lure draw. “Research does not find the key
card” is valid only when the shared authored order proves what it does draw,
what quota or resource it consumes, and the exact later deficit. Never change
the seed, hidden order, opening hand, Prize cards, or AI policy between the
winning route and a lure route.

### 4. Author Ordered Draw Drama

Design multiple legal openings:

- one correct information/draw line
- at least two lure lines such as Professor's Research, Iono, an early ability, an unnecessary search, or a premature shuffle

Make the lure openings and their failure causes distinct. If the frozen list
contains Professor's Research or an equivalent draw-seven Supporter, prefer one
lure that uses it first and prove why its larger immediate draw still loses.

Make the correct line depend on timing. Example:

```text
Active Gholdengo ex uses Coin Bonus -> reveals Arven
-> Arven searches the required Item/Tool bridge
-> later draw or recovery completes Superior Energy Retrieval
```

A Research-first lure may draw many cards yet fail because it consumes the
Supporter quota, discards protected costs, passes the required card, or shuffles
away a prepared top deck. Freeze enough of the deck order to make both results
deterministic. State the exact failed damage, Energy, prize, hand-size, or
Supporter equation; “bad luck” is not evidence.

The winning route must not be the route that simply draws the most cards. Make
the player infer which draw source preserves deck order, Supporter quota,
discard fodder, Bench space, or the next-turn natural draw. For example:

```text
Coin Bonus reveals Arven -> Arven gets Superior Energy Retrieval
-> recovery creates exact first knockout -> Prize or next draw reveals Boss's Orders
-> gust the pre-calculated liability for the final prizes
```

Place Professor's Research, Iono, another ability, or a visible search card in
the opening hand/board as credible temptations when the frozen list permits.
The negative proofs must show why each apparently stronger draw line misses a
specific later card, quota, discard cost, damage number, or deadline.

Prefer a late hidden finisher when the frozen list supports it: sustained
filtering reveals Boss's Orders, Counter Catcher, a recovery piece, or the
deck's own equivalent only after the player preserves the correct information
and resource epochs. The emotional “top-deck” is authored luck, not uncontrolled
chance.

Require an explicit route transcript:

```text
checkpoint -> effect used -> cards/information actually revealed
-> quota or shuffle boundary crossed -> next checkpoint
```

Write this transcript for the correct route and every lure. The negative
transcript must end in a numerical or legal failure, not an opinion.

Treat every search, recovery, or effect that shuffles the deck as an information
barrier. Any authored card below the top card is no longer a deterministic
future draw after that shuffle unless the route explicitly places it again,
draws it before shuffling, obtains it from another zone, or the production
engine exposes a deterministic seeded-shuffle contract. Never claim “leave
Boss's Orders second from the top for next turn” if an intervening search or
Energy Search PRO shuffles the deck.

Prefer one or more of:

- ability before Supporter
- Supporter before ability
- search before top-deck placement
- recovery before discard payment
- knockout/prize pickup before the second search
- deliberate refusal to use an available draw ability

### 5. Construct A Credible Complex Board

Use every legal Bench slot per side unless a documented combo requires space.
Normally this means five occupied slots; use the actual expanded capacity when
a Stadium or rule changes it. Avoid decorative filler:

- attackers threaten prizes
- support Pokémon expose abilities
- pivots affect switching
- liabilities create gust decisions
- damaged targets define breakpoints

For every target, record:

```text
printed HP + Tool/Stadium modifiers - existing damage
- planned moved/spread damage = remaining HP

attack base/modifier x weakness/resistance = final damage
```

Require exact or near-exact payment. Reject any board where the player can ignore the intended engine, skip filtering, or win with a plainly available attack.

Design the emotional turn as carefully as the arithmetic. The board should first
read as nearly lost, then expose new information one checkpoint at a time.
Prefer a final hidden gust or finisher—often Boss's Orders, Counter Catcher, or
the deck's equivalent—that converts sustained filtering into an exact prize
win. Record the apparent dead end, comeback chain, and final payoff in
`climax_contract`.

Complexity must come from interlocking obligations, not arbitrary clutter.
Damage, attached Energy, prizes, discard contents, and Bench occupants must all
be explainable by a plausible prior game. Pre-calculate the lethal line before
placing the board, then attempt to remove every intended action; if the puzzle
still wins, the removed action was decoration and the candidate must be revised.
Give every occupied Active/Bench slot an explicit role in `board_roles`. A slot
that does not affect legality, information, resource ownership, targeting,
damage, prize mapping, or an attractive false line is decorative and must be
replaced.

Add `board_history` evidence for elapsed turns, Energy origins, damage origins,
and Prize history. Reject a superficially legal state when its attachments,
damage, discard, or Prize count could not plausibly arise from the declared
game history.

### 6. Implement Static Scenario Data

Keep the state deterministic and replayable. Preserve stable scenario IDs only when progress is revisioned; increment `revision` when replacing content.

Add the `design_contract` from the repository reference. It must name deck
identity, combo order, random-looking hand roles, every key card, the winning
draw route, lure routes, deterministic luck, damage/Energy math, board roles,
board history, late hidden climax, and witness budget. Keep author-only solution details out of the
player-facing objective.

Set `solution_key_inventory_complete` only after tracing every card consumed by
the positive witness back to its initial zone and acquisition checkpoint. Set
`board_capacity` to the actual Bench capacity on both sides. These are assertions
that the static auditor and production proof must challenge, not prose labels.

### 7. Validate In Layers

1. Run:

```powershell
python .codex/skills/design-ptcg-deck-training-puzzles/scripts/audit_puzzle_contract.py --project-root . --scenario-file PATH --deck-key DECK_KEY
```

2. Build every scenario through `DeckTrainingStateFactory`.
3. Require 60-card conservation, legal Main-phase start, and defining opening actions.
4. Replay the positive witness through production `GameStateMachine`.
5. Replay every lure from the identical hidden state as a negative probe; record
   the full draw/reveal transcript, cards it actually sees, and its exact failed
   equation.
6. Cross the fixed rules-AI middle turn and re-evaluate the public board.
7. Prove no one-turn shortcut and no lower-action shortcut.
8. Generate a proof certificate when the adapter covers every interaction. Otherwise label it `playable`, never `proven`.
9. Run the deck-training POC, puzzle-pipeline, affected card-effect, and source-encoding suites.

The positive witness and lure probes must begin from the identical state and
hidden order. A purported solution is invalid if it needs a different shuffle,
seed, AI choice, or opening hand.

### 8. Review The Player Experience

Reject if any answer is yes:

- Are the ten puzzles mostly the same state?
- Are key cards already in hand?
- Does the hand expose one obvious route?
- Can a generic draw-seven or raw attack solve it?
- Are Bench Pokémon decorative?
- Is damage arbitrary rather than derived?
- Can turn one finish a stated two-turn puzzle?
- Does the intended line need fewer than five meaningful actions?
- Is success controlled by unresolved random luck?
- Does the player learn only “use the cards provided”?
- Does a key card appear in the initial hand, or was a required key omitted from
  the manifest?
- Does any authored top-deck claim cross an unaccounted shuffle?
- Could one remove a Bench occupant, draw checkpoint, or combo step without
  changing the solution?
- Is the finisher visible before at least two prior filtering/information
  checkpoints?
- Does any route describe an outcome without recording what it actually
  revealed from the shared hidden state?

## Deliverables

- deck theory sheet with source evidence
- combo/tech inventory and curriculum axes
- ten distinct scenario fingerprints and `design_contract` blocks
- player-facing text without solution leakage
- positive production witness and at least two negative lure probes per puzzle
- exact damage, Energy, prize, deck-count, and turn-budget tables
- honest proof/admission status
- focused and pipeline test results
