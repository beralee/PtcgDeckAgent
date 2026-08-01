# Dragapult corpus-model iteration protocol

## Required order

```text
one hypothesis
-> corpus audit and hash freeze
-> run-scoped training
-> offline gate
-> isolated candidate
-> deterministic contracts
-> native validation
-> targeted exact-seed replay
-> diagnostic paired A/B
-> first-divergence audit
-> independent paired A/B
-> promote / hold / reject
```

Do not skip directly from offline metrics to a Kaggle submission.

## Model/Graph ownership

| Decision domain | Owner | Learned control |
| --- | --- | --- |
| Legal actions | CABT engine | Never |
| Mandatory Drakloak Recon | Graph contract | Never |
| Terminal prize route | Exact calculator | Never |
| Cursed Blast, Phantom spread, Munkidori transfer | Exact calculators | Shadow only |
| Discard sets and energy payments | Atomic interaction Graph | Shadow only |
| Deckout, immunity, and wall-bypass clocks | Matchup exact Overlay | Shadow only |
| Safe main-phase sibling route | Route Q behind confidence gates | Allowed |
| Search/target prompt | Interaction Q | Shadow until causal coverage |
| Out-of-distribution or low support | Champion fallback | Mandatory |

## First-divergence record

For each paired flip, record:

```json
{
  "pair_id": "opponent:seatN:gameN",
  "run_seed": 0,
  "candidate_reward": -1,
  "baseline_reward": 1,
  "ordinal": 0,
  "turn": 0,
  "observation_step": 0,
  "baseline_node": "",
  "candidate_node": "",
  "baseline_action": [],
  "candidate_action": [],
  "baseline_q": null,
  "selected_q": null,
  "advantage": null,
  "support": [],
  "overlays": [],
  "owner": "feature|label|graph|calculator|interaction|gate|overlay",
  "correction": ""
}
```

The correction must address this divergence or add data that makes it
decidable. A later tactical symptom is not sufficient evidence.

## Promotion interpretation

- Strong offline AUC with neutral paired outcomes means **hold**, not promote.
- A changed action sequence with no paired flips is not an exact no-op, but it
  still has no demonstrated win-rate value.
- A diagnostic improvement on seeds used for tuning must be repeated on fresh
  seeds.
- Never claim `+10pp` from fewer than 2,000 independent paired games.
- Never lower confidence/support gates to manufacture more takeovers after a
  neutral result; collect causal labels for the uncertain edge family instead.

## Next-data priority

Select counterfactual rollouts in this order:

1. baseline-only flips caused by a learned takeover;
2. shared losses with a high-Q sibling action;
3. model takeovers with neutral outcomes but different route completion;
4. high-disagreement search/energy/evolution states;
5. OOD public topologies with abstention.

Keep every derivative dataset immutable and linked to its parent corpus and
candidate hashes.
