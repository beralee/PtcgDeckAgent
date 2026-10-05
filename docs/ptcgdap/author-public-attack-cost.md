# Author Host public attack-cost projection

2026-09-25 — user-authorized local source repair; focused engine acceptance passed.

`PtcgDAPAuthorDevelopmentBattleOwner._slot_attack_profile` previously derived
`minimum_attack_energy_count`, `energy_debt` and `attack_ready` from printed
costs. Real attack validation already applied public cost modifiers. As a
result, Sparkling Crystal's Tera attackers and Bloodmoon Ursaluna ex could have
a legal current attack while the author's public view said energy was missing.

The Host now uses the engine's current any-color and colorless cost modifiers,
including their existing ability/Tool suppression rules, and the same payment
validator. Modifier queries retain the real board entity and its owner/zone.
Pending assignments contribute only to the matching entity's temporary payment
view; projecting a window does not attach energies to the actual board.

The public schema and current-option index boundary are unchanged. No card
effect, RuleValidator legality rule, author package or Base authority changes.
`attack_ready` still means energy-payment readiness, not full attack legality:
turn restrictions, attack locks and a hypothetical future pivot require fresh
legal options. Flexible-energy debt matching and author-defined static goal
costs remain outside this repair's scope.

## Evidence and regression entrypoint

The exact original Host (SHA-256
`A6A34320EED446D92E8407648171F1AF9AFC7A8E30476B37CB984DD90EC68AFB`)
passed 12/45 focused engine cases; the reviewed proposal passed 45/45.
The applied Host bytes are
`91AE3434576347FE3CA92870085467FC104DCBD90E0422080F8F7A0BDF18CCA7`.

The applied Host passed the original 45/45 engine probe again in a newly isolated
runtime, plus 7/7 maintained cost tests, 19/19 Competitive Policy tests and 5/5
public-observation firewall tests. The seven maintained cost tests contain the
same 45 situations; those are not 90 independent situations.

The maintained suite is
`tests/ptcgdap/godot/test_author_public_attack_cost.gd`: seven discovered tests
containing the same 45 checked situations. These cover both player seats,
prize-count changes, Crystal color choices, insufficient/wrong energy, disabled
ability/Tool, increased costs, pending target identity, Bench payment, first-turn
attack restriction and hidden-identity invariance. Run through the focused
suite runner in an isolated user directory.

The original RED, proposal GREEN and option-reordered public-window simulation
are kept in Forge `work/eevee-box-20260925/host-cost-proposal/` and `evidence/`.
Applied-source regression receipts and same-runtime developer-only matches are
under Forge `work/eevee-box-20260925/phase2/`. The 44 complete match executions
are clean, with 4,881/4,881 successful policy calls and zero invalid output,
fallback, policy error, engine rejection or trace-drop counters. The 40
development executions contain no legal-current-attack/readiness-false mismatch.
The existing 0.8.1 and 0.9.2 packages score 3/20 and 4/20 respectively; smoke
scores are 2/2 and 1/2. These small reused groups do not establish a strength
gain. No strategy is promoted, and independent confirmation seeds remain unused.
Official CABT parity, device acceptance and cloud deployment remain separate.

## Rollback

Reverse only the reviewed `_slot_attack_profile` hunk and remove its new
`_effective_attack_cost_candidates` helper. Preserve pre-existing and subsequent
working-tree changes. Forge retains the exact before bytes and reviewed patch;
the original frozen runtime and SDK remain unchanged. This repair does not
deploy online or replace z's active 0.8.1 strategy.
